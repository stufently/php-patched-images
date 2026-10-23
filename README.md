# php-patched-images

Ready-to-use Docker images of PHP **8.2 / 8.3 / 8.4 / 8.5** built from source
with the fixes for **CVE-2026-109618** and **CVE-2026-109619** ("php2shell",
critical unauthenticated RCE, PHP security release of 21 Oct 2026), in
`cli`, `fpm` and `apache` variants with common extension sets, on Debian 13
trixie (default), Debian 12 bookworm and Alpine 3.24 — plus **best-effort**
builds of the official source backports for end-of-life **PHP 7.4 and 8.1**.
Multi-arch: `linux/amd64` + `linux/arm64`. Rebuilt weekly.

[Русский](#по-русски) | [English](#english)

### Нужна помощь с обновлением PHP или переносом сайта?

Предлагаю платную помощь с обновлением PHP в Docker и на обычных Linux-серверах,
а также адаптацией старого PHP-сайта к поддерживаемой версии. Сначала проверяем
версии, зависимости и объём; затем согласуем работу на тестовой копии, проверки
основных функций, резервную копию и план отката перед боевым переносом.
Установка исправления в текущей ветке и миграция приложения — разные работы;
стоимость и срок определяются после оценки. Бэкпорт не заменяет поддержку PHP.

Для оценки напишите текущую версию PHP, CMS/фреймворк, ОС или Docker-образ,
количество сайтов и желаемый результат. Пароли и ключи присылать не нужно.
Контакт: [Telegram @stufently](https://t.me/stufently).
Подробнее об исправлениях: [моя статья на Хабре](https://habr.com/ru/articles/1097456/).
Использование открытых образов не требует заказа услуги.

**Need paid PHP upgrade help?** I also help migrate legacy PHP applications and
update PHP on Docker or Linux servers. Scope, price and schedule follow an
assessment; staging checks, backups and a rollback plan come before production
rollout. Send your PHP version, framework/CMS and deployment details via
[Telegram @stufently](https://t.me/stufently), without passwords or keys.

### Quick start

```bash
docker pull ghcr.io/stufently/php-patched-images:8.5-fpm-web
docker run --rm ghcr.io/stufently/php-patched-images:8.5-cli php -v   # PHP 8.5.12 ...
docker pull ghcr.io/stufently/php-patched-images:8.4-fpm-web-bookworm
docker pull ghcr.io/stufently/php-patched-images:8.3-fpm-alpine
docker pull ghcr.io/stufently/php-patched-images:7.4-backport-fpm-web   # best-effort, see below
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
Самый высокий риск, по оценке PHP, у **mod_php**. Уязвимые версии: всё ниже
8.2.35 / 8.3.36 / 8.4.27 / 8.5.12. PHP 8.1 и старше проектом не обновляются —
для 7.4/8.0/8.1 опубликованы только минимальные source-бэкпорты (ветки
`PHP-7.4-CVE-2026-109618-109619`, `PHP-8.0-…`, `PHP-8.1-…` в php/php-src),
без релизов и тарболов. Для 7.4 и 8.1 здесь есть их сборки — см.
[Бэкпорты 7.4 и 8.1](#бэкпорты-74-и-81-best-effort).

Первоисточники: [php.net security advisory](https://www.php.net/archive/2026.php#2026-10-21-5),
[ChangeLog](https://www.php.net/ChangeLog-8.php), GHSA выше,
[NVD CVE-2026-109618](https://nvd.nist.gov/vuln/detail/CVE-2026-109618),
[NVD CVE-2026-109619](https://nvd.nist.gov/vuln/detail/CVE-2026-109619),
[CERT-EU 2026-018](https://cert.europa.eu/publications/security-advisories/2026-018).

### Зачем эти образы

Официальные `php:*` на Docker Hub выходят с задержкой после релиза. Здесь
PHP 8.2–8.5 собирается из исходников по тем же Dockerfile, что у
docker-library/php (коммит с исправленными версиями — `core/UPSTREAM_COMMIT`):
тарбол с php.net проверяется по SHA256 и GPG-подписи релиз-менеджеров, базы —
`debian:trixie-slim`, `debian:bookworm-slim`, `alpine:3.24` по дайджесту. На
момент выхода (21.10.2026, 15:00 UTC) официальные `php:8.x.y` с исправленными
версиями на Docker Hub ещё не появились (были только `*RC1`), поэтому образы
НЕ строятся `FROM php:*`. Debian 11 bullseye не собирается (официальные
`php:*-bullseye` заморожены на старых версиях, напр. 8.2.29, сам bullseye
вне поддержки с 31.08.2026). Плюс готовые наборы расширений, чтобы не
собирать их у себя.

### Теги

`ghcr.io/stufently/php-patched-images:<ветка>-<вариант>[-<профиль>][-<ОС>]`

* ветка: `8.5`, `8.4`, `8.3`, `8.2` (или точная версия: `8.5.12-fpm-web`,
  неизменяемый снимок: `8.5.12-fpm-web-YYYYMMDD`); бэкпорты — `7.4-backport`,
  `8.1-backport` (см. ниже);
* вариант: `cli`, `fpm`, `apache` (на Alpine — только `cli` и `fpm`, как у
  docker-library);
* ОС (суффикс в конце):

| Суффикс | База | Варианты | Профили |
|---|---|---|---|
| *(нет)* | Debian 13 trixie | cli, fpm, apache | все |
| `-bookworm` | Debian 12 bookworm | cli, fpm, apache | все |
| `-alpine` или `-alpine3.24` | Alpine 3.24 (musl) | cli, fpm | все |

  Пример: `8.4-fpm-web` (trixie), `8.4-fpm-web-bookworm`,
  `8.4-fpm-web-alpine`, `8.4.27-fpm-web-alpine3.24`,
  снимок `8.4.27-fpm-web-bookworm-YYYYMMDD`.
* для 8.4 и 8.5 к тегу с точной версией есть алиас уровня патчей, например
  `8.4.27-p1-fpm-web` (то же с `-bookworm`, `-alpine`, `-alpine3.24`).
  `p1` — один патч php-src поверх релиза. Голые теги `8.4.27-*` и `8.4-*`
  (и такие же у 8.5) тоже собраны с этим патчем: pinned-тег остаётся голой
  версией, от него CI делает снимок `…-YYYYMMDD`, и его проверяет
  `tests/verify-published.sh`. Список патчей — метка
  `org.opencontainers.image.php-src.patches`
  (`docker inspect --format '{{index .Config.Labels "org.opencontainers.image.php-src.patches"}}' IMAGE`),
  переменная `PHP_PATCHES` и каталог `/usr/src/php-patches/`.
* теги с суффиксом `-amd64`/`-arm64` — служебные, используйте мульти-арх теги без него;
* профиль:

| Профиль | Для чего | Расширения сверх стандартных | Варианты |
|---|---|---|---|
| *(без суффикса)* `base` | любой PHP-код, свой набор поверх | opcache включён, `php.ini-production`, `expose_php=Off` | cli, fpm, apache |
| `web` | WordPress, OpenCart, Joomla, Drupal (и их CLI: wp-cli, cron) | bcmath exif gd intl ldap mysqli pdo_mysql soap zip imagick memcached | cli, fpm, apache |
| `app` | Laravel, Symfony, воркеры очередей | bcmath exif gd intl ldap pcntl pdo_mysql pdo_pgsql pgsql soap sockets zip redis apcu memcached + composer | cli, fpm, apache |
| `dev` | локальная разработка (НЕ прод) | app + xdebug, `php.ini-development` | cli, fpm |

`cli-web` — тот же набор, что у `fpm-web`, для CLI-задач CMS (wp-cli, cron,
воркеры) в отдельном контейнере. Профили одинаковы на всех базах (trixie,
bookworm, Alpine) и на бэкпортах 7.4/8.1. Стандартные расширения
официального образа (curl, mbstring, openssl, sodium, PDO, pdo_sqlite, xml,
dom, fileinfo, …) есть во всех.

Нужно своё расширение — в базовых есть
[install-php-extensions](https://github.com/mlocati/docker-php-extension-installer):

```dockerfile
FROM ghcr.io/stufently/php-patched-images:8.5-fpm
RUN install-php-extensions mongodb
```

### Полный список мульти-арх тегов

Для каждого тега ниже есть ещё тег с точной версией (`8.4.27-…`) и снимок
`…-YYYYMMDD`; для Alpine — дубль с `-alpine3.24`.

| Ветка (PHP внутри) | trixie | bookworm | alpine |
|---|---|---|---|
| 8.5 (8.5.12) | `8.5-cli` `8.5-cli-web` `8.5-cli-app` `8.5-cli-dev` `8.5-fpm` `8.5-fpm-web` `8.5-fpm-app` `8.5-fpm-dev` `8.5-apache` `8.5-apache-web` `8.5-apache-app` | те же с `-bookworm` | `8.5-cli-alpine` `8.5-cli-web-alpine` `8.5-cli-app-alpine` `8.5-cli-dev-alpine` `8.5-fpm-alpine` `8.5-fpm-web-alpine` `8.5-fpm-app-alpine` `8.5-fpm-dev-alpine` |
| 8.4 (8.4.27) | то же для `8.4` | то же | то же |
| 8.3 (8.3.36) | то же для `8.3` | то же | то же |
| 8.2 (8.2.35) | то же для `8.2` | то же | то же |
| 8.1 бэкпорт (8.1.34 + коммит `1d7dec1`) | — | `8.1-backport-cli` `8.1-backport-cli-web` `8.1-backport-cli-app` `8.1-backport-cli-dev` `8.1-backport-fpm` `8.1-backport-fpm-web` `8.1-backport-fpm-app` `8.1-backport-fpm-dev` `8.1-backport-apache` `8.1-backport-apache-web` `8.1-backport-apache-app` | — |
| 7.4 бэкпорт (7.4.34-dev, коммит `712e60f`) | — | `7.4-backport-cli` `7.4-backport-cli-web` `7.4-backport-cli-app` `7.4-backport-cli-dev` `7.4-backport-fpm` `7.4-backport-fpm-web` `7.4-backport-fpm-app` `7.4-backport-fpm-dev` `7.4-backport-apache` `7.4-backport-apache-web` `7.4-backport-apache-app` | — |

### GH-24488: SimpleXML и сборщик мусора

В PHP 8.4.27 и 8.5.12 сборщик мусора дважды освобождает таблицу свойств
`SimpleXMLElement`, и процесс падает с `zend_mm_heap corrupted`. На образы
8.4 и 8.5 наложен upstream-коммит
[f9634847](https://github.com/php/php-src/commit/f9634847258a8c3ed6c12bb79104eba60bb631ea);
он войдёт в 8.4.28 и 8.5.13, после этого патч будет убран.

Use-after-free в `unserialize` ([php-src#24481](https://github.com/php/php-src/issues/24481))
в PHP не исправлен, PR [php/php-src#24551](https://github.com/php/php-src/pull/24551)
открыт, в наших образах исправления нет.

Для хостов, где PHP пересобрать нельзя (Sury, cPanel, DirectAdmin), временный вариант — сторонний модуль https://github.com/HOSTED-POWER/php_uploadprogress_guard: сторонний код молодого проекта, пинить на проверенный коммит; в наши образы не встроен.

### Бэкпорты 7.4 и 8.1 (best-effort)

⚠️ **Это НЕ официальный релиз PHP.** PHP 7.4 и 8.1 сняты с поддержки; для
этих CVE команда безопасности PHP выложила только минимальные исправления в
ветках php-src, без тарбола, подписи релиза и тестового цикла релиза. Образы
`*-backport-*` собраны из этих веток как есть, поэтому в имени тега стоит
`backport`. Используйте их как временную меру до перехода на 8.2+.

| Тег | Ветка php-src | Коммит (закреплён) | `php -v` |
|---|---|---|---|
| `8.1-backport-*` | `PHP-8.1-CVE-2026-109618-109619` | `1d7dec178a094e6e75b229ce22754045f8c6070a` | `8.1.34` |
| `7.4-backport-*` | `PHP-7.4-CVE-2026-109618-109619` | `712e60f9edfd03f0960fc4fc3c2c375f42b90aa2` | `7.4.34-dev` |

* **Версия не отличает исправленную сборку.** Ветка 8.1 сообщает `8.1.34` —
  ту же версию, что у последнего официального (уязвимого) релиза; 7.4 —
  `7.4.34-dev`. Проверяйте коммит: он вшит в бинарник при сборке и виден в
  `phpinfo()` → «Configure Command» (`PHP_BACKPORT_COMMIT=<sha>`) и в метке
  образа `org.opencontainers.image.revision.php-src`:

  ```bash
  docker run --rm ghcr.io/stufently/php-patched-images:8.1-backport-cli php -i | grep -o 'PHP_BACKPORT_COMMIT=[0-9a-f]*'
  ```

  Smoke-тест CI проверяет этот коммит и в CLI, и в самом SAPI (запросом через
  php-fpm / mod_php), а не только номер версии.
* **Источник.** Исходники берутся `git fetch` по полному SHA коммита из
  github.com/php/php-src, после checkout SHA сверяется (`git rev-parse`);
  оба коммита подписаны (GitHub: verified). `configure` генерируется
  `buildconf` из этого дерева; PEAR-установщик (в git его нет) — закреплённая
  по SHA256 копия с pear.php.net.
* **База — Debian 12 bookworm** для обеих веток. Это последняя поддерживаемая
  Debian, на которой обе ветки собираются штатным компилятором (GCC 12) и
  библиотеками; последние официальные образы `php:8.1` тоже были на bookworm.
  trixie (GCC 14, libxml2/ICU новее) для этих веток официально никогда не
  поддерживался, а bullseye снят с поддержки 31.08.2026.
* **OpenSSL для 7.4.** Расширение `openssl` PHP 7.4 не собирается с
  OpenSSL 3 (поддержка появилась в 8.0/8.1). Поэтому в образах 7.4 собран
  **OpenSSL 1.1.1w** (последний выпуск 1.1.1, SHA256 + GPG-подпись OpenSSL) в
  отдельный префикс `/usr/local/openssl-1.1` с rpath — его использует только
  расширение `openssl` PHP; curl, Apache и пакеты Debian работают с
  системным OpenSSL 3 с обновлениями безопасности. **OpenSSL 1.1.1 сам снят
  с поддержки (EOL с 11.09.2023)** — это ещё одна причина считать 7.4-образы
  временной мерой. Корневые сертификаты берутся из системного
  `ca-certificates`.
* Варианты: `cli`, `fpm`, `apache`; профили те же, что у 8.2+: `base`, `web`,
  `app` (cli/fpm/apache), `dev` (cli/fpm). У каждого тега есть тег с
  коммитом (`7.4-backport-712e60f-fpm-app`) и снимок `…-YYYYMMDD`.
* **Версии расширений для 7.4.** Composer 2.10.3, redis 6.3.0, apcu 5.1.28,
  memcached 3.4.0 и imagick 3.8.1 поддерживают PHP 7.4 (по `package.xml`
  PECL: redis — от 7.4.0, apcu — от 7.0, memcached — от 7.0; Composer 2.x —
  от 7.2.5) и стоят в тех же версиях, что на 8.2+. **Xdebug 3.2+ требует
  PHP 8.0**, поэтому в `7.4-backport-*-dev` закреплён **Xdebug 3.1.6** —
  последний выпуск ветки 3.1 (PHP 7.2–8.1, 08.11.2022), с SHA256 тарбола
  PECL и архива тега GitHub. Ветка 3.1 больше не обновляется — ещё одна
  причина держать `dev` 7.4 только для локальной отладки. 8.1 получает тот
  же Xdebug 3.5.3, что и 8.2+ (поддерживает PHP 8.0–8.5).

### Как проверить свою версию

```bash
php -v                                   # на хосте
docker exec <контейнер> php -v           # в контейнере
php -r 'var_dump(version_compare(PHP_VERSION, "8.4.27", ">="));'   # для своей ветки
```

Безопасно, если версия не ниже **8.5.12 / 8.4.27 / 8.3.36 / 8.2.35** для своей
ветки. Внимание: `php -v` CLI и FPM/Apache на одном хосте могут быть разными
сборками — проверяйте ту, что обслуживает веб (`phpinfo()` или `php-fpm -v`).
Для 7.4/8.1 версия ничего не говорит — проверяйте коммит бэкпорта (см. выше).

### Как перейти

Замените `FROM php:8.x-fpm` (или `-apache`, `-cli`, `-fpm-bookworm`,
`-fpm-alpine`) на `FROM ghcr.io/stufently/php-patched-images:8.x-fpm` (или
`…:8.x-fpm-bookworm`, `…:8.x-fpm-alpine`) — раскладка совпадает с
официальным образом (`/usr/local/etc/php`, `docker-php-ext-*`, entrypoint),
пересоберите и перезапустите **все** воркеры. Когда выйдут официальные
`php:8.5.12-*`, можно вернуться на них. Для 7.4/8.1:
`FROM php:7.4-fpm` → `FROM ghcr.io/stufently/php-patched-images:7.4-backport-fpm`.

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
scripts/build.sh 8.5 trixie fpm             # core + все профили варианта
scripts/build.sh 8.4 alpine cli
scripts/build.sh 7.4-backport bookworm fpm
tests/smoke.sh local/php-patched:8.5-fpm-web fpm web
tests/smoke.sh local/php-patched:7.4-backport-fpm-web fpm web 712e60f9edfd03f0960fc4fc3c2c375f42b90aa2
```

Проверка опубликованных тегов без логина (пустой `DOCKER_CONFIG`,
`docker manifest inspect` + `docker run php -v`): `tests/verify-published.sh
<amd64|arm64> [YYYYMMDD]`; в CI — workflow `verify-published` (ручной запуск,
нативные amd64- и arm64-раннеры).

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
the base image pinned by digest (tarballs verified by SHA256 + GPG; official
`php:*` images with the fixed versions were not yet on Docker Hub at release
time, so nothing is built `FROM php:*`; no bullseye), and extension profiles on top:

* tags: `<branch>-<variant>[-<profile>][-<os>]`, e.g. `8.4-apache-web`,
  `8.5-cli-app`, `8.5-cli-web`, `8.3-fpm-dev`, `8.4-fpm-web-bookworm`,
  `8.2-fpm-dev-alpine`;
  exact version tags `8.5.12-fpm-app` and dated snapshots
  `8.5.12-fpm-app-YYYYMMDD`;
* patch level: on 8.4 and 8.5 the exact-version tag also has a `-pN` alias,
  for example `8.4.27-p1-fpm-web` (same with `-bookworm`, `-alpine`,
  `-alpine3.24`). `p1` means one php-src patch on top of the release.
  The bare tags `8.4.27-*` and `8.4-*` (and the 8.5 equivalents) carry that
  patch too: the pinned tag stays a bare version because CI derives the
  dated snapshot from it and `tests/verify-published.sh` checks that name.
  See which patches are included via the label
  `org.opencontainers.image.php-src.patches`
  (`docker inspect --format '{{index .Config.Labels "org.opencontainers.image.php-src.patches"}}' IMAGE`),
  the `PHP_PATCHES` environment variable, and `/usr/src/php-patches/`;
* OS: no suffix = Debian 13 trixie (cli/fpm/apache, all profiles);
  `-bookworm` = Debian 12 (same variants and profiles); `-alpine` /
  `-alpine3.24` = Alpine 3.24 (cli/fpm, all profiles);
* profiles: `base` (no suffix), `web` (WordPress/OpenCart; cli/fpm/apache —
  `cli-web` is for CMS CLI jobs such as wp-cli or cron), `app`
  (Laravel/Symfony + composer; cli/fpm/apache), `dev` (app + Xdebug; cli/fpm)
  — see the table above; the same profiles on every base and on the 7.4/8.1
  backports; `web` and `app` include **memcached, soap and ldap** everywhere;
* check: `php -v` must report at least the fixed version for your branch;
* migrate: replace `FROM php:8.x-<variant>[-bookworm|-alpine]` with
  `FROM ghcr.io/stufently/php-patched-images:8.x-<variant>[-bookworm|-alpine]`,
  rebuild and restart all workers.

### GH-24488: SimpleXML and garbage collection

In PHP 8.4.27 and 8.5.12 the garbage collector frees the `SimpleXMLElement`
properties table twice and the process dies with `zend_mm_heap corrupted`.
The 8.4 and 8.5 images apply upstream commit
[f9634847](https://github.com/php/php-src/commit/f9634847258a8c3ed6c12bb79104eba60bb631ea);
it will be in 8.4.28 and 8.5.13, and the patch will be removed then.

The `unserialize` use-after-free ([php-src#24481](https://github.com/php/php-src/issues/24481))
is not fixed in PHP. PR [php/php-src#24551](https://github.com/php/php-src/pull/24551)
is open. These images do not include a fix.

Where PHP cannot be rebuilt (Sury, cPanel, DirectAdmin), a temporary option is the third-party module https://github.com/HOSTED-POWER/php_uploadprogress_guard: third-party code of a young project, pin a commit you have checked; it is not built into these images.

### PHP 7.4 and 8.1 backports (best-effort)

**Not an official PHP release.** PHP 7.4 and 8.1 are end-of-life; for these
CVEs the PHP security team only published minimal fixes on php-src branches
(no tarball, no release signature, no release test cycle). The
`7.4-backport-*` / `8.1-backport-*` images build those branches as-is, pinned
to a commit — treat them as a stopgap until you move to 8.2+.

| Tag | php-src branch | Pinned commit | `php -v` |
|---|---|---|---|
| `8.1-backport-{cli,fpm,apache}[-web,-app]`, `8.1-backport-{cli,fpm}-dev` | `PHP-8.1-CVE-2026-109618-109619` | `1d7dec178a094e6e75b229ce22754045f8c6070a` | `8.1.34` |
| `7.4-backport-{cli,fpm,apache}[-web,-app]`, `7.4-backport-{cli,fpm}-dev` | `PHP-7.4-CVE-2026-109618-109619` | `712e60f9edfd03f0960fc4fc3c2c375f42b90aa2` | `7.4.34-dev` |

Each also has a commit-pinned tag (`8.1-backport-1d7dec1-fpm-web`) and a
dated snapshot (`…-YYYYMMDD`).

* The version string does not tell a fixed build apart: the 8.1 branch
  reports `8.1.34`, the same as the last (vulnerable) official release. Check
  the commit instead: it is compiled in (`phpinfo()` → "Configure Command"
  contains `PHP_BACKPORT_COMMIT=<sha>`) and set as the image label
  `org.opencontainers.image.revision.php-src`. CI smoke tests check it in the
  CLI and through the SAPI itself (a request via php-fpm / mod_php).
* Source: `git fetch` of the full commit SHA from github.com/php/php-src,
  re-checked with `git rev-parse`; both commits are signed (GitHub: verified).
  `configure` is generated by `buildconf`; the PEAR installer (not in git) is
  a SHA256-pinned copy from pear.php.net.
* Base: Debian 12 bookworm for both — the newest supported Debian where both
  branches build with the stock toolchain (GCC 12); the last official
  `php:8.1` images were bookworm too. trixie was never supported for these
  branches, bullseye is out of support since 2026-08-31.
* OpenSSL for 7.4: PHP 7.4's `openssl` extension does not build against
  OpenSSL 3, so the 7.4 images ship **OpenSSL 1.1.1w** (last 1.1.1 release,
  SHA256 + OpenSSL GPG signature) in `/usr/local/openssl-1.1` with an rpath,
  used only by PHP's `openssl` extension; curl, Apache and Debian packages
  keep the system OpenSSL 3 with security updates. **OpenSSL 1.1.1 itself is
  EOL (since 2023-09-11)** — one more reason to treat 7.4 as a stopgap. CA
  certificates come from the system `ca-certificates`.
* Variants `cli`, `fpm`, `apache`; profiles as on 8.2+: `base`, `web`, `app`
  (cli/fpm/apache) and `dev` (cli/fpm).
* Extension versions on 7.4: Composer 2.10.3, redis 6.3.0, apcu 5.1.28,
  memcached 3.4.0 and imagick 3.8.1 support PHP 7.4 (PECL `package.xml`:
  redis from 7.4.0, apcu and memcached from 7.0; Composer 2.x from 7.2.5) and
  are the same versions as on 8.2+. **Xdebug 3.2+ needs PHP 8.0**, so
  `7.4-backport-*-dev` pins **Xdebug 3.1.6**, the last 3.1 release (PHP
  7.2-8.1, 2022-11-08), by SHA256 of the PECL tarball and of the GitHub tag
  archive. The 3.1 line gets no more updates: keep the 7.4 `dev` images for
  local debugging only. 8.1 gets the same Xdebug 3.5.3 as 8.2+ (PHP 8.0-8.5).

CI builds every image natively on amd64 and arm64, runs `tests/smoke.sh`
(version >= fixed or the backport commit, extension list, a real request
through php-fpm / Apache) and only then publishes to GHCR. Weekly scheduled
rebuilds pick up OS security updates. `tests/verify-published.sh
<amd64|arm64> [YYYYMMDD]` (and the manual `verify-published` workflow on
native amd64/arm64 runners) checks every published tag anonymously: empty
`DOCKER_CONFIG`, `docker manifest inspect`, `docker run php -v`.

License: MIT. `core/` is derived from
[docker-library/php](https://github.com/docker-library/php) (MIT).
