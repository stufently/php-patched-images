# php-patched-images

Ready-to-use Docker images of PHP **8.2 / 8.3 / 8.4 / 8.5** built from source
with the fixes for **CVE-2026-109618** and **CVE-2026-109619** ("php2shell",
critical unauthenticated RCE, PHP security release of 21 Oct 2026), in
`cli`, `fpm` and `apache` variants with common extension sets.
Multi-arch: `linux/amd64` + `linux/arm64`. Rebuilt weekly.

[Русский](#по-русски) | [English](#english)

```bash
docker pull ghcr.io/stufently/php-patched-images:8.5-fpm-web
docker run --rm ghcr.io/stufently/php-patched-images:8.5-cli php -v   # PHP 8.5.12 ...
```

## По-русски

### Что за уязвимость

21.10.2026 PHP выпустил внеплановые релизы **8.5.12, 8.4.27, 8.3.36, 8.2.35**,
закрывающие две критические уязвимости (CVSS 4.0: **9.2**), позволяющие
удалённое выполнение кода без аутентификации:

| CVE | Advisory | Суть |
|---|---|---|
| CVE-2026-109618 | [GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) | RCE через порчу состояния при out-of-memory: OOM прерывает PHP, когда данные запроса инициализированы частично, а завершение запроса принимает их за валидные |
| CVE-2026-109619 | [GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp) | RCE через «протухшее» глобальное состояние (use-after-free): состояние одного запроса переживает освобождение памяти и используется следующим запросом того же воркера |

Затронуты все веб-SAPI: PHP-FPM, Apache mod_php, php-cgi, FrankenPHP, LiteSpeed.
Самый высокий риск, по оценке PHP, у **mod_php** — продемонстрирован эксплойт,
срабатывающий до выполнения кода приложения. Уязвимые версии: всё ниже
8.2.35 / 8.3.36 / 8.4.27 / 8.5.12. PHP 8.1 и старше проектом не обновляются —
для 7.4/8.0/8.1 опубликованы только минимальные source-бэкпорты.

Первоисточники: [php.net security advisory](https://www.php.net/archive/2026.php#2026-10-21-5),
[ChangeLog](https://www.php.net/ChangeLog-8.php), GHSA выше,
[NVD CVE-2026-109618](https://nvd.nist.gov/vuln/detail/CVE-2026-109618),
[NVD CVE-2026-109619](https://nvd.nist.gov/vuln/detail/CVE-2026-109619),
[CERT-EU 2026-018](https://cert.europa.eu/publications/security-advisories/2026-018).

### Зачем эти образы

Официальные `php:*` на Docker Hub выходят с задержкой после релиза. Здесь
PHP собирается из исходников по тем же Dockerfile, что у docker-library/php
(коммит с исправленными версиями — `core/UPSTREAM_COMMIT`): тарбол с php.net
проверяется по SHA256 и GPG-подписи релиз-менеджеров, база —
`debian:trixie-slim` по дайджесту. На момент выхода (21.10.2026, 15:00 UTC)
официальные `php:8.x.y` с исправленными версиями на Docker Hub ещё не
появились (были только `*RC1`), поэтому образы НЕ строятся `FROM php:*`.
Debian 11 bullseye не собирается (официальные `php:*-bullseye` заморожены на
старых версиях, напр. 8.2.29). Плюс готовые наборы расширений, чтобы не
собирать их у себя.

### Теги

`ghcr.io/stufently/php-patched-images:<ветка>-<вариант>[-<профиль>]`

* ветка: `8.5`, `8.4`, `8.3`, `8.2` (или точная версия: `8.5.12-fpm-web`,
  неизменяемый снимок: `8.5.12-fpm-web-YYYYMMDD`)
* вариант: `cli`, `fpm`, `apache` (Debian 13 trixie)
* теги с суффиксом `-amd64`/`-arm64` — служебные, используйте мульти-арх теги без него
* профиль:

| Профиль | Для чего | Расширения сверх стандартных | Варианты |
|---|---|---|---|
| *(без суффикса)* `base` | любой PHP-код, свой набор поверх | opcache включён, `php.ini-production`, `expose_php=Off` | cli, fpm, apache |
| `web` | WordPress, OpenCart, Joomla, Drupal | bcmath exif gd intl mysqli pdo_mysql zip imagick | fpm, apache |
| `app` | Laravel, Symfony, воркеры очередей | bcmath exif gd intl pcntl pdo_mysql pdo_pgsql pgsql sockets zip redis apcu + composer | cli, fpm, apache |
| `dev` | локальная разработка (НЕ прод) | app + xdebug, `php.ini-development` | cli, fpm |

Стандартные расширения официального образа (curl, mbstring, openssl, sodium,
PDO, pdo_sqlite, xml, dom, fileinfo, …) есть во всех.

Нужно своё расширение — в базовых есть
[install-php-extensions](https://github.com/mlocati/docker-php-extension-installer):

```dockerfile
FROM ghcr.io/stufently/php-patched-images:8.5-fpm
RUN install-php-extensions soap memcached
```

### Как проверить свою версию

```bash
php -v                                   # на хосте
docker exec <контейнер> php -v           # в контейнере
php -r 'var_dump(version_compare(PHP_VERSION, "8.4.27", ">="));'   # для своей ветки
```

Безопасно, если версия не ниже **8.5.12 / 8.4.27 / 8.3.36 / 8.2.35** для своей
ветки. Внимание: `php -v` CLI и FPM/Apache на одном хосте могут быть разными
сборками — проверяйте ту, что обслуживает веб (`phpinfo()` или `php-fpm -v`).

### Как перейти

Замените `FROM php:8.x-fpm` (или `-apache`, `-cli`) на
`FROM ghcr.io/stufently/php-patched-images:8.x-fpm` — раскладка совпадает с
официальным образом (`/usr/local/etc/php`, `docker-php-ext-*`, entrypoint),
пересоберите и перезапустите **все** воркеры. Когда выйдут официальные
`php:8.5.12-*`, можно вернуться на них.

Не можете обновиться прямо сейчас — временные меры из
[advisory php.net](https://www.php.net/archive/2026.php#2026-10-21-5) только
снижают риск, решение — обновление:

* `session.upload_progress.enabled=0` — в `php.ini` или в пуле FPM
  (`php_admin_value[session.upload_progress.enabled] = 0`), НЕ через
  `ini_set()`/`.user.ini`, затем рестарт всех воркеров;
* `memory_limit=-1` через `php_admin_value`, низкий `post_max_size`
  (8M без загрузок файлов, 32M с ними), лимиты на размер/число полей и частей
  запроса на прокси;
* на 8.5 — `fatal_error_backtraces=0`.

Дополнительно (общая гигиена, не из advisory): `session.use_strict_mode=1`.
WAF перед сайтом не спасает, если origin доступен напрямую по IP — закройте
прямой доступ.

### Сборка у себя

```bash
scripts/build.sh 8.5 fpm             # core + все профили варианта
tests/smoke.sh local/php-patched:8.5-fpm-web fpm web
```

## English

PHP 8.5.12 / 8.4.27 / 8.3.36 / 8.2.35 (released 2026-10-21) fix
**CVE-2026-109618** (RCE via OOM corruption,
[GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w))
and **CVE-2026-109619** (RCE via stale global state,
[GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)),
both critical, CVSS 4.0 9.2, affecting PHP-FPM, Apache mod_php, php-cgi,
FrankenPHP and LiteSpeed. See the
[php.net advisory](https://www.php.net/archive/2026.php#2026-10-21-5).

These images are built from source using the docker-library/php Dockerfiles
at the commit that bumped to the fixed versions (`core/UPSTREAM_COMMIT`), with
the Debian base pinned by digest (tarballs verified by SHA256 + GPG; official
`php:*` images with the fixed versions were not yet on Docker Hub at release
time, so nothing is built `FROM php:*`; no bullseye), and extension profiles on top:

* tags: `<branch>-<variant>[-<profile>]`, e.g. `8.4-apache-web`, `8.5-cli-app`,
  `8.3-fpm-dev`; exact version tags `8.5.12-fpm-app` and dated snapshots
  `8.5.12-fpm-app-YYYYMMDD`;
* profiles: `base` (no suffix), `web` (WordPress/OpenCart), `app`
  (Laravel/Symfony + composer), `dev` (app + Xdebug) — see table above;
* check: `php -v` must report at least the fixed version for your branch;
* migrate: replace `FROM php:8.x-<variant>` with
  `FROM ghcr.io/stufently/php-patched-images:8.x-<variant>`, rebuild and
  restart all workers.

CI builds every image natively on amd64 and arm64, runs `tests/smoke.sh`
(version >= fixed, extension list, a real request through php-fpm / Apache)
and only then publishes to GHCR. Weekly scheduled rebuilds pick up Debian
security updates.

License: MIT. `core/` is derived from
[docker-library/php](https://github.com/docker-library/php) (MIT).
