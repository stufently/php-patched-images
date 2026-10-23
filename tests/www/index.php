<?php
// Values are read by the SAPI under test (fpm/apache), not by the CLI ini.
printf("SMOKE-OK %s %s opcache=%s expose_php=%s upload_progress=%s\n",
    PHP_VERSION, PHP_SAPI,
    (int) ini_get('opcache.enable'), (int) ini_get('expose_php'),
    (int) ini_get('session.upload_progress.enabled'));
