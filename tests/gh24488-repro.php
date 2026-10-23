<?php
for ($i = 0; $i < 2; $i++) {
    $xml = new SimpleXMLElement('<a><b/></a>');
    get_object_vars($xml);
    $holder = new stdClass;
    $holder->xml = $xml;
    $holder->self = $holder;
    unset($xml, $holder);
    gc_collect_cycles();
    $junk[] = str_repeat('x', 100);
}
echo "done\n";
