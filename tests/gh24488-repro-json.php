<?php
for ($i = 0; $i < 50; $i++) {
    $xml = simplexml_load_string('<r><a x="1">t</a><b/></r>');
    $arr = json_decode(json_encode($xml), true);
    $h = new stdClass; $h->x = $xml; $h->s = $h;
    unset($xml, $h);
    gc_collect_cycles();
    $junk[] = str_repeat('y', 100);
}
echo "done\n";
