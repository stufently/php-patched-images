<?php
// Which php-src commit the SAPI under test was configured from (backport images).
ob_start();
phpinfo(INFO_GENERAL);
$info = ob_get_clean();
printf("BUILD %s %s %s\n", PHP_VERSION, PHP_SAPI,
    preg_match('/PHP_BACKPORT_COMMIT=([0-9a-f]{40})/', $info, $m) ? $m[1] : 'none');
