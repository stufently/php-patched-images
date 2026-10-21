<?php
// Minimal FastCGI client: performs one GET against php-fpm and prints the body.
// Usage: php fcgi_get.php <host> <port> <script_filename>
[$_, $host, $port, $script] = $argv + [null, '127.0.0.1', '9000', '/var/www/html/index.php'];

function rec(int $type, string $content, int $id = 1): string {
    $len = strlen($content);
    $pad = (8 - ($len % 8)) % 8;
    return pack('CCnnCC', 1, $type, $id, $len, $pad, 0) . $content . str_repeat("\0", $pad);
}
function nv(string $k, string $v): string {
    $enc = fn(int $l) => $l < 128 ? chr($l) : pack('N', $l | 0x80000000);
    return $enc(strlen($k)) . $enc(strlen($v)) . $k . $v;
}

$params = [
    'GATEWAY_INTERFACE' => 'FastCGI/1.0',
    'REQUEST_METHOD'    => 'GET',
    'SCRIPT_FILENAME'   => $script,
    'SCRIPT_NAME'       => '/' . basename($script),
    'REQUEST_URI'       => '/' . basename($script),
    'QUERY_STRING'      => '',
    'SERVER_SOFTWARE'   => 'smoke',
    'SERVER_PROTOCOL'   => 'HTTP/1.1',
    'REMOTE_ADDR'       => '127.0.0.1',
    'SERVER_NAME'       => 'localhost',
    'SERVER_PORT'       => '80',
];
$body = '';
foreach ($params as $k => $v) { $body .= nv($k, (string)$v); }

$s = @stream_socket_client("tcp://$host:$port", $errno, $errstr, 5);
if (!$s) { fwrite(STDERR, "connect failed: $errstr\n"); exit(2); }
stream_set_timeout($s, 10);
fwrite($s, rec(1, pack('nCx5', 1, 0)) . rec(4, $body) . rec(4, '') . rec(5, ''));

$out = '';
while (!feof($s)) {
    $h = fread($s, 8);
    if (strlen($h) < 8) break;
    $r = unpack('Cver/Ctype/nid/nlen/Cpad/Cres', $h);
    $c = $r['len'] ? fread($s, $r['len']) : '';
    if ($r['pad']) fread($s, $r['pad']);
    if ($r['type'] === 6) $out .= $c;       // FCGI_STDOUT
    if ($r['type'] === 7) fwrite(STDERR, $c); // FCGI_STDERR
    if ($r['type'] === 3) break;            // FCGI_END_REQUEST
}
$parts = explode("\r\n\r\n", $out, 2);
echo $parts[1] ?? $out;
