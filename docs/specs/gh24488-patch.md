# Веха: патч php-src GH-24488 в образах 8.4 и 8.5

- Репозиторий: `~/github/php-patched-images` (GitHub `stufently/php-patched-images`,
  ветка по умолчанию `master`; публикация `ghcr.io/stufently/php-patched-images`
  через `.github/workflows/build.yml` → `images.yml`).
- Дата: 23.10.2026.
- BASE_SHA: `cbc09736f81aa75c90a00f19b841e9da20b47f66` (заголовок: `Retry registry pushes on transient errors`).
- Исполнитель: `auto` (новая спека, требований к backend нет). Мутации по
  новым проверкам — противоположный исполнитель после приёмки, вне этой вехи.
- Постановщик и координатор: Claude-субагент бот-сессии владельца. Владелец
  одобрил «вариант A»: вендорить upstream-фикс и накладывать его при сборке.

## Где работать

Только в этом одноразовом клоне (`/home/deploy/exec-clones/php-gh24488`),
новая ветка `gh24488-patch` от BASE_SHA. Живое дерево `~/github/php-patched-images`
не трогать. **push в origin запрещён**, работу заберёт постановщик через
`git fetch` из клона. Никаких `docker push`, `gh workflow run`, логина в ghcr.

Постановщик уже положил в клон (untracked):

| Файл | sha256 | байт | Что делать |
|---|---|---|---|
| `patches/8.4/gh24488.patch` | `3d2ae7f1edaea9a792184d35d5e1121043f86537e1cf4f847512b52a09e7a146` | 1112 | закоммитить БЕЗ изменений |
| `patches/8.5/gh24488.patch` | `229eaf67e137d8592006c531c45cb8757351fcdc5d43a3f40b65d3b43fee444d` | 1112 | закоммитить БЕЗ изменений |
| `tests/gh24488-repro.php` | `d90935a1428ddd5f02ab836fbf942636d4cacc54605857406404bbb0f31b6c9c` | 296 | закоммитить БЕЗ изменений |
| `tests/gh24488-repro-json.php` | `d81f574b79e0fed89622ef1c8450af522ade985b41baaaa5fdc9801709dae16c` | 296 | закоммитить БЕЗ изменений |
| `probes/gh24488-check.sh` | `3fa47994358dd2bad89b9069da36be8fc0b65fa3e1de7cd97b3c8f0ed9e12be6` | 7408 | НЕ коммитить, НЕ править (пробник приёмки) |
| `probes/gh24488-tags.expected` | `0233f46ac2ac99b041b5984a4e26f505bf53ef5b730cde224c65cfe3dc0554d0` | 16192 | НЕ коммитить, НЕ править |

Пробник читать можно и нужно: он — точное описание контракта.

## Задача и почему

Регрессия php-src GH-24488: в PHP 8.4.27 и 8.5.12 сборщик мусора дважды
освобождает таблицу свойств `SimpleXMLElement`, процесс падает с
`zend_mm_heap corrupted` (rc=139). Наши опубликованные образы `8.4-*` и `8.5-*`
этим болеют; 8.2, 8.3 и бэкпорты 7.4/8.1 — нет. Upstream-фикс — коммит
`f9634847258a8c3ed6c12bb79104eba60bb631ea` (`zend_hash_release(sxe->properties)` →
`zend_array_release(...)` в `sxe_object_free_storage`, плюс тест `gh24488.phpt`);
он в ветках PHP-8.4 и PHP-8.5, релиза с ним ещё нет (ожидается 8.4.28 / 8.5.13).

Сейчас `core/8.x/<os>/<variant>/` — вендорные Dockerfile docker-library,
`scripts/sync-upstream.sh` перезаписывает их целиком и только потом правит
sed'ом (`gpg_cleanup`). Механизма патчей нет. Правка руками в `core/` будет
стёрта следующей синхронизацией — поэтому всё вносится ЧЕРЕЗ `sync-upstream.sh`.

## Что проверено вживую 23.10.2026 (а что предположение)

| Утверждение | Как проверено | Результат |
|---|---|---|
| Опубликованные 8.4/8.5 падают на репро, остальные нет | `docker run … ghcr.io/stufently/php-patched-images:<тег> php repro.php` для `8.2-cli 8.3-cli 8.4-cli 8.5-cli 8.1-backport-cli 7.4-backport-cli 8.4-cli-alpine 8.5-cli-bookworm` | 8.4/8.5 (trixie, alpine, bookworm): rc=139 `zend_mm_heap corrupted` на обоих репро; остальные rc=0 `done` |
| Неизменяемые снимки до патча существуют | `docker manifest inspect …:8.4.27-cli-20261022`, `…:8.5.12-cli-20261022` | есть (их использует AC-008 как контроль «без патча красно») |
| `simplexml.c` релизов совпадает с тем, к чему сделаны патчи | `curl raw.githubusercontent.com/php/php-src/php-8.4.27/ext/simplexml/simplexml.c` (и 8.5.12) | строка `zend_hash_release(sxe->properties);` — 2205 в 8.4.27, 2209 в 8.5.12; хунки патчей стоят ровно на них (без смещения) |
| Содержимое патчей = upstream f9634847 без хунка NEWS | `gh api repos/php/php-src/commits/f9634847` + `.diff` | NEWS выкинут (в tarball-е он другой); simplexml.c и новый phpt — побайтно upstream |
| В Debian-сборке `patch` есть | `apt-cache depends dpkg-dev` в `debian:trixie-slim` → `Depends: patch`; `dpkg-dev` входит в `$PHPIZE_DEPS`, ставится в первом `RUN` и не удаляется | есть |
| В Alpine `patch` НЕТ ни в busybox, ни в `$PHPIZE_DEPS` | `docker run alpine:3.24 sh -c 'which patch'` → not found; то же после `apk add dpkg-dev dpkg` | нужен пакет `patch` в `.build-deps` (GNU patch 2.8) |
| Во всех 16 Dockerfile 8.4/8.5 ровно одна пара строк `\tdocker-php-source extract; \` + `\tcd /usr/src/php; \` | `grep -c` по `core/8.[45]/*/*/Dockerfile` | по 1 разу везде |
| `scripts/build.sh` строит теги так: primary, pinned, затем алиасы | чтение `scripts/build.sh` (`tags=(…)`, строка `echo "$local_tag $VARIANT $p $commit ${tags[*]}"`) | `pinned` = значение `ENV PHP_VERSION` (`envval`), CI делает из него снимок `<pinned>-YYYYMMDD`; `tests/verify-published.sh` проверяет все теги строки и `want="PHP ${pinned%%-*} "` |
| `tests/smoke.sh` гоняет `php` через `docker run --rm --entrypoint php "$IMAGE"` для всех вариантов, каталог `tests/` монтирует как `/smoke` только для fpm | чтение `tests/smoke.sh` | — |
| Опорная реализация правки Dockerfile (строки ниже) собирается и чинит репро | постановщик собрал `core/8.4/trixie/cli`, `core/8.5/trixie/cli`, `core/8.4/alpine/cli` с этими строками | см. раздел «Опорная проверка» в конце |

Проверено 23.10.2026 прогоном на чистом клоне (затем откачено): синхронизация перепинивает
`FROM alpine:3.24@sha256:…` в 8 alpine-каталогах 8.2–8.5 (дайджест обновился), остальное
побайтно как в BASE. Общее правило: `scripts/sync-upstream.sh` с тем же
`core/UPSTREAM_COMMIT` (`e3eaff845f7a9f7259c31da54dce0320b47a3bbd`) может
перепинить дайджесты `FROM` базовых образов, если они обновились с прошлой
синхронизации. Это допустимо (критерии разрешают менять строки `FROM …@sha256:`
в `core/8.2`…`core/8.5`), больше ничего в 8.2/8.3 меняться не должно.

## Что сделать

### 1. `scripts/sync-upstream.sh` — функция наложения патчей

По образцу `gpg_cleanup`: новая функция (например `add_patches <branch> <dst>`),
вызывается в `sync_os` для каждого `dst` ПОСЛЕ `gpg_cleanup`. Если в
`$ROOT/patches/<branch>/` есть `*.patch` (сейчас только 8.4 и 8.5):

1. скопировать их в `<dst>/patches/` (каталог контекста сборки);
2. в `<dst>/Dockerfile` вставить ДОСЛОВНО (табы — настоящие `\t`):
   - строкой сразу ПОСЛЕ `COPY docker-php-source /usr/local/bin/`:
     `COPY patches/ /usr/src/php-patches/`
   - строкой сразу ПОСЛЕ `\tcd /usr/src/php; \`, которая идёт сразу за
     `\tdocker-php-source extract; \`:
     `\tfor p in /usr/src/php-patches/*.patch; do patch -p1 --forward --batch --fuzz=0 -i "$p"; done; \`
   - двумя строками сразу ПОСЛЕ `ENV PHP_VERSION <x>`:
     `ENV PHP_PATCHES="gh24488"` и
     `LABEL org.opencontainers.image.php-src.patches="gh24488"`
     (значение — имена файлов патчей без `.patch`, через пробел, по
     сортировке; сейчас это один `gh24488`);
   - только для alpine: строкой сразу ПОСЛЕ `\t\t$PHPIZE_DEPS \` в блоке
     `\tapk add --no-cache --virtual .build-deps \`: `\t\tpatch \`
     (пакет уходит вместе с `.build-deps`; в Debian ничего не добавлять);
3. после каждой вставки проверить, что она легла РОВНО один раз, иначе
   `echo "… did not apply to $1" >&2; return 1` — как у `gpg_cleanup`.
   Синхронизация обязана падать, если upstream поменял опорные строки.

`/usr/src/php-patches/` остаётся в образе: это видимое доказательство,
какой патч наложен. Строка с `for … patch …` под `set -eux` роняет `RUN`
(и сборку), если патч не лёг или уже наложен (`--forward`), или если
каталог пуст (литерал `*.patch`).

Комментарий над функцией: что и зачем, и **«убрать patches/8.4 при переходе
на 8.4.28, patches/8.5 — на 8.5.13 (фикс войдёт в релиз)»**.

### 2. Прогнать синхронизацию

`scripts/sync-upstream.sh "$(cat core/UPSTREAM_COMMIT)"` (нужны сеть, `jq`,
`docker buildx imagetools`). Результат — 16 каталогов `core/8.4|8.5/{trixie,bookworm}/{cli,fpm,apache}`
и `core/8.4|8.5/alpine/{cli,fpm}` с `patches/gh24488.patch` и строками выше.
Руками в `core/` ничего не править. `core/UPSTREAM_COMMIT` не меняется.

### 3. `scripts/build.sh` — теги с уровнем патчей

Если в Dockerfile ядра есть `ENV PHP_PATCHES="<ids>"` с непустым значением
(читать отдельным разбором: `envval` берёт `$3` и для формы `KEY="v"` не
годится), N = число id. Для каждой пары тегов с pinned-версией ДОБАВИТЬ в
конец строки алиас с `-pN` сразу после версии: `8.4.27-cli` → `8.4.27-p1-cli`,
`8.4.27-cli-alpine3.24` → `8.4.27-p1-cli-alpine3.24`. Primary и pinned НЕ
меняются (совместимость: `8.4-cli`, `8.4.27-cli` и снимки `8.4.27-cli-YYYYMMDD`
остаются как были, `verify-published.sh` продолжает работать). Порядок и
полный ожидаемый вывод `LIST_ONLY=1` по всем целям `build.yml` —
`probes/gh24488-tags.expected`. Ветки без патчей (8.2, 8.3, бэкпорты) — вывод
побайтно как на BASE. Обоснование схемы (впиши коротко в README): pinned-тег
обязан оставаться голой версией — от него зависят снимки и проверка
`verify-published.sh`; `-p1` даёт честное имя без поломки старых тегов, а
`LABEL`/`ENV` перечисляют, ЧТО именно в p1.

### 4. `tests/smoke.sh` — проверка GH-24488

Для КАЖДОГО образа (все ветки и варианты): запустить в образе
`tests/gh24488-repro.php` и `tests/gh24488-repro-json.php` (`php` из образа,
каталог `tests/` смонтирован read-only); каждый обязан вывести ровно `done` и
выйти с rc=0. Иначе `fail` с сообщением, содержащим `gh24488`, имя файла и
`rc=<код>` (пример: `FAIL [img]: gh24488 repro gh24488-repro.php: rc=139 …`).
Дополнительно: если версия 8.4.27 или 8.5.12 — `PHP_PATCHES` в окружении
образа обязан содержать `gh24488` (защита от синхронизации, потерявшей патч);
для прочих версий не требовать. Печатать строку-итог (например
`gh24488: ok (patches: gh24488)`).

### 5. `README.md` (и русский, и английский разделы)

- В разделах тегов: схема `-p1` (пример `8.4.27-p1-fpm-web`), что значит p1,
  что `8.4.27-*`/`8.4-*` теперь тоже с патчем, как посмотреть
  (`docker inspect … org.opencontainers.image.php-src.patches`, `PHP_PATCHES`,
  `/usr/src/php-patches/`).
- Абзац про GH-24488: в 8.4.27/8.5.12 SimpleXML падает
  (`zend_mm_heap corrupted`) при сборке мусора; у нас наложен upstream-коммит
  f9634847 (ссылка), он войдёт в 8.4.28/8.5.13 — тогда патч будет убран.
- Абзац про unserialize UAF php-src#24481: в PHP НЕ исправлен, PR
  php/php-src#24551 открыт, в наших образах исправления нет. Без обещаний и
  сроков.
- ОДНА строка про сторонний модуль
  https://github.com/HOSTED-POWER/php_uploadprogress_guard: временный вариант
  для хостов, где PHP пересобрать нельзя (Sury, cPanel, DirectAdmin); сторонний
  код молодого проекта; пинить на проверенный коммит; в наши образы не встроен.
- Ничего не придумывать сверх этого: дат релизов 8.4.28/8.5.13, оценок
  безопасности модуля, числа затронутых сайтов писать ЗАПРЕЩЕНО.

## Не трогать

- `.github/workflows/*`, `Dockerfile` (профили), `profile/`, `tests/verify-published.sh`,
  `tests/fcgi_get.php`, `tests/www/`, `core/7.4-backport/`, `core/8.1-backport/`,
  `core/UPSTREAM_COMMIT`, `LICENSE*`, `tmp/` (игнорируется гитом).
- Руками — ничего в `core/` (только через `sync-upstream.sh`).
- Вендорные файлы из таблицы выше — коммитить без изменений; `probes/` — не
  коммитить и не править.
- Исключение: эта спека `docs/specs/gh24488-patch.md` приезжает untracked и
  коммитится вместе с работой.
- Разрешённые пути (проверяет AC-012): `scripts/sync-upstream.sh`,
  `scripts/build.sh`, `tests/smoke.sh`, `tests/gh24488-repro.php`,
  `tests/gh24488-repro-json.php`, `patches/8.4/gh24488.patch`,
  `patches/8.5/gh24488.patch`, `README.md`, `docs/specs/gh24488-patch.md`,
  `core/8.2…8.5/*/*/Dockerfile`, `core/8.4|8.5/*/*/patches/gh24488.patch`.
- push/`docker push`/публикация — запрещены.

## Критерии приёмки

Все команды — из корня клона. Сборки — обычный `docker build` на хосте
(кэш слоёв ускоряет повтор). Пробник — `probes/gh24488-check.sh`, его sha256
вшит в команду.

**AC-001** — Вендорные патчи и репро закоммичены без изменений.
`bash -c 'printf "%s\n" "3d2ae7f1edaea9a792184d35d5e1121043f86537e1cf4f847512b52a09e7a146  patches/8.4/gh24488.patch" "229eaf67e137d8592006c531c45cb8757351fcdc5d43a3f40b65d3b43fee444d  patches/8.5/gh24488.patch" "d90935a1428ddd5f02ab836fbf942636d4cacc54605857406404bbb0f31b6c9c  tests/gh24488-repro.php" "d81f574b79e0fed89622ef1c8450af522ade985b41baaaa5fdc9801709dae16c  tests/gh24488-repro-json.php" | sha256sum -c - && git ls-files --error-unmatch patches/8.4/gh24488.patch patches/8.5/gh24488.patch tests/gh24488-repro.php tests/gh24488-repro-json.php'`

**AC-002** — Все 16 контекстов 8.4/8.5 несут патч и строки на своих местах, остальные ветки — нет, прочие изменения в core только перепин FROM.
`bash -c 'echo "3fa47994358dd2bad89b9069da36be8fc0b65fa3e1de7cd97b3c8f0ed9e12be6  probes/gh24488-check.sh" | sha256sum -c - && probes/gh24488-check.sh core'`

**AC-003** — Повторная синхронизация ничего не меняет (правки живут в sync-upstream.sh).
`bash -c 'scripts/sync-upstream.sh "$(cat core/UPSTREAM_COMMIT)" > /var/tmp/gh24488-ac003.log 2>&1 && git diff --quiet HEAD -- core && test -z "$(git ls-files --others --exclude-standard -- core)"'`

**AC-004** — Ядро 8.4 trixie cli собирается с патчем, оба репро дают done, метаданные на месте.
`bash -c 'echo "3fa47994358dd2bad89b9069da36be8fc0b65fa3e1de7cd97b3c8f0ed9e12be6  probes/gh24488-check.sh" | sha256sum -c - && probes/gh24488-check.sh image 8.4 trixie'`

**AC-005** — Ядро 8.5 trixie cli собирается с патчем, оба репро дают done, метаданные на месте.
`bash -c 'echo "3fa47994358dd2bad89b9069da36be8fc0b65fa3e1de7cd97b3c8f0ed9e12be6  probes/gh24488-check.sh" | sha256sum -c - && probes/gh24488-check.sh image 8.5 trixie'`

**AC-006** — Ядро 8.4 alpine cli собирается с патчем, оба репро дают done, метаданные на месте.
`bash -c 'echo "3fa47994358dd2bad89b9069da36be8fc0b65fa3e1de7cd97b3c8f0ed9e12be6  probes/gh24488-check.sh" | sha256sum -c - && probes/gh24488-check.sh image 8.4 alpine'`

**AC-007** — Неналожившийся патч роняет сборку именно на патче.
`bash -c 'echo "3fa47994358dd2bad89b9069da36be8fc0b65fa3e1de7cd97b3c8f0ed9e12be6  probes/gh24488-check.sh" | sha256sum -c - && probes/gh24488-check.sh patchfail'`

**AC-008** — Smoke зелёный на собранном ядре и красный по причине gh24488 на опубликованном снимке без патча.
`bash -c 'docker build -q -t local/gh24488-check:8.4-trixie-cli core/8.4/trixie/cli > /dev/null && tests/smoke.sh local/gh24488-check:8.4-trixie-cli cli base > /var/tmp/gh24488-ac008-ok.log 2>&1 && ! tests/smoke.sh ghcr.io/stufently/php-patched-images:8.4.27-cli-20261022 cli base > /var/tmp/gh24488-ac008-bad.log 2>&1 && grep -q "gh24488.*rc=139" /var/tmp/gh24488-ac008-bad.log && ! tests/smoke.sh ghcr.io/stufently/php-patched-images:8.5.12-cli-20261022 cli base > /var/tmp/gh24488-ac008-bad85.log 2>&1 && grep -q "gh24488.*rc=139" /var/tmp/gh24488-ac008-bad85.log'`

**AC-009** — Smoke на непострадавшей ветке 8.3 и на бэкпорте зелёный (новая проверка не ломает чужие образы).
`bash -c 'tests/smoke.sh ghcr.io/stufently/php-patched-images:8.3-cli cli base > /var/tmp/gh24488-ac009-83.log 2>&1 && grep -q "gh24488" /var/tmp/gh24488-ac009-83.log && tests/smoke.sh ghcr.io/stufently/php-patched-images:8.1-backport-cli cli base 1d7dec178a094e6e75b229ce22754045f8c6070a > /var/tmp/gh24488-ac009-81.log 2>&1 && grep -q "gh24488" /var/tmp/gh24488-ac009-81.log'`

**AC-010** — Список тегов по всем целям build.yml совпадает с ожидаемым (старые теги целы, p1-алиасы только у 8.4/8.5).
`bash -c 'echo "3fa47994358dd2bad89b9069da36be8fc0b65fa3e1de7cd97b3c8f0ed9e12be6  probes/gh24488-check.sh" | sha256sum -c - && echo "0233f46ac2ac99b041b5984a4e26f505bf53ef5b730cde224c65cfe3dc0554d0  probes/gh24488-tags.expected" | sha256sum -c - && probes/gh24488-check.sh tags'`

**AC-011** — README (RU и EN) содержит обязательные пункты.
`bash -c 'echo "3fa47994358dd2bad89b9069da36be8fc0b65fa3e1de7cd97b3c8f0ed9e12be6  probes/gh24488-check.sh" | sha256sum -c - && probes/gh24488-check.sh readme'`

**AC-012** — Изменения только в разрешённых путях, дерево чистое, скрипты синтаксически целы.
`bash -c 'echo "3fa47994358dd2bad89b9069da36be8fc0b65fa3e1de7cd97b3c8f0ed9e12be6  probes/gh24488-check.sh" | sha256sum -c - && probes/gh24488-check.sh paths'`

## Контракт отчёта

`report.json` в КОРНЕ клона, untracked, схема v2. Записей в `criteria` ровно
двенадцать: AC-001…AC-012. `blocked` — штатный исход, когда среда не даёт
выполнить критерий (нет сети, Docker Hub отдаёт 5xx после повтора):
`"rc": null` и дословная ошибка в `note`. Обходить несовместимость запрещено.

```json
{
  "schema_version": 2,
  "policy_id": "cross-review-v1",
  "spec_sha256": "<sha256 файла docs/specs/gh24488-patch.md>",
  "base_sha": "cbc09736f81aa75c90a00f19b841e9da20b47f66",
  "reviewed_sha": "<коммит, отданный на ревью>",
  "final_sha": "<HEAD после единственного захода фиксов>",
  "executor": {"backend": "grok|spark|codex", "model": "<точная модель>"},
  "review": {
    "initial_receipts": ["<квитанции review_run.sh>"],
    "verification_receipts": [],
    "resolutions": []
  },
  "handoff_status": "ready",
  "criteria": [
    {"id": "AC-001", "status": "pass|fail|blocked",
     "command": "<команда ИЗ ЭТОЙ СПЕКИ, посимвольно>", "rc": 0, "note": "…"}
  ]
}
```

После сборки отчёта: `python3 /home/deploy/.claude/skills/executor-milestone/scripts/accept_run.py /home/deploy/exec-clones/php-gh24488 --spec docs/specs/gh24488-patch.md --dry-run` обязан дать код 2 (`validation_only`).

## Авторевью cross-review-v1

По `/home/deploy/.claude/skills/executor-milestone/docs/spec-template.md`,
раздел «Автономное перекрёстное ревью (авторевью)». Пара по backend
исполнителя: Codex/Spark → `agy` + `grok`; Grok → `codex` + `agy`. Оба ревью
— параллельно, на диапазоне `cbc09736f81aa75c90a00f19b841e9da20b47f66..<REVIEW_SHA>`,
обёрткой по абсолютному пути:
`bash /home/deploy/.claude/skills/executor-milestone/scripts/review_run.sh initial <ревьюер> --clone /home/deploy/exec-clones/php-gh24488 --base cbc09736f81aa75c90a00f19b841e9da20b47f66 --range cbc09736f81aa75c90a00f19b841e9da20b47f66..<REVIEW_SHA> --context "Веха GH-24488: вендорный патч php-src в образах 8.4/8.5 через sync-upstream.sh, теги -p1, smoke, README; только чтение" --exclude "core/**/Dockerfile"`.
Сгенерированные синхронизацией Dockerfile исключены из диапазона ревью
(их форму проверяет AC-002), логика — в `scripts/sync-upstream.sh`:

```text
REVIEW_EXCLUDE: core/**/Dockerfile
```

Один заход исправлений; затем один verify той же парой. Ревьюер недоступен
(квота, сбой после одного технического повтора) — запиши это в
`report-blocked.md`, отметь в отчёте и сдай: недостающее ревью делает
координатор. Не подменять ревьюера самостоятельно.

## Контракт на невыполнимое

Остановись и запиши `report-blocked.md` с дословным фактом, если: патч не
ложится на исходники релиза; `sync-upstream.sh` не может склонировать
docker-library или разрешить дайджест; Docker Hub/ghcr недоступны после
повтора; опорные строки в Dockerfile не такие, как в разделе «Что сделать»;
критерий невыполним без нарушения «Не трогать». Пробник и ожидаемый список
тегов не править — расхождение с ними докладывать.

## Стыки

После приёмки координатор сам: мерж в `master`, push, ожидание GitHub Actions,
прогон репро на опубликованных `8.4-cli`/`8.5-cli`; мутационный прогон
противоположным исполнителем. Следующая веха (когда выйдут 8.4.28/8.5.13):
снять `patches/8.4`, `patches/8.5`, обновить `UPSTREAM_COMMIT` и README.

## Опорная проверка постановщика

Ядра `core/8.4/trixie/cli`, `core/8.5/trixie/cli`, `core/8.4/alpine/cli`,
собранные с ровно этими строками (копии контекстов вне клона), дали:
`patching file ext/simplexml/simplexml.c`, `patching file ext/simplexml/tests/gh24488.phpt`,
оба репро — `done`, rc=0. Сломанный патч (хунк не совпадает) — сборка
падает на `Hunk #1 FAILED`.
