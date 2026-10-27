# Бюджет памяти: JVM и PostgreSQL

Область: backend · Диаграммы: [c4/deployment](../c4/deployment.md) · Код: `backend/docker/app.Dockerfile`, `backend/docker-compose.yml` (`command: -c …`)

## Контекст

На VPS 1 ГБ app получает 512m, PostgreSQL — 128m. С флагами по умолчанию JVM под нагрузкой (360 SSE, ~190 ходов/с) убивалась OOM-kill. Решения подбирались замерами (`docker stats`, NMT).

## Решение

**JVM app** — всё считается от лимита контейнера:
- `-XX:+UseSerialGC`: один инстанс и heap в сотни МБ, у G1 лишние нативные структуры и потоки;
- `-XX:MaxRAMPercentage=50` (heap 256 МБ). Вне heap ~200 МБ: metaspace ~75, code cache ~45, malloc ~45, символы ~19, CDS ~13;
- `-XX:TieredStopAtLevel=1` (только C1): C2 брал до 160 МБ нативных арен;
- `-XX:ReservedCodeCacheSize=64m`, `-XX:MaxMetaspaceSize=128m`: рост даёт понятную ошибку JVM, а не OOM-kill;
- `-XX:TrimNativeHeapInterval=5000` и `MALLOC_ARENA_MAX=2`: glibc сам не отдаёт malloc-память и плодит арены;
- `-XX:+ExitOnOutOfMemoryError`; `-Xss` не задан; AOT-кеш не используется (обучающему запуску нужна БД).

**Кеш состояний партий:** 2000 записей и `expire-after-access` 5m (~60 МБ, ~500 партий на двоих).

**PostgreSQL** (`mem_limit 128m`): `max_connections=20`, `shared_buffers=16MB`, `effective_cache_size=64MB`, `work_mem=2MB`, `maintenance_work_mem=16MB`, `wal_buffers=1MB`, `max_wal_size=64MB`, `jit=off`, `huge_pages=off`, без параллельных воркеров, `autovacuum_max_workers=1`.

## Рассмотренные варианты

| Вариант | Почему нет |
|---|---|
| JVM с флагами по умолчанию (C2, heap 75%) при `mem_limit 512m` | Под нагрузкой OOM-kill: heap 384 МБ + ~180 МБ вне heap, C2 берёт до 160 МБ арен |
| Кеш состояний на 10000 записей и 30m | Живой heap рос до ~185 МБ из 247, шли подряд полные сборки — дальше был бы OOM |

## Последствия

- Только C1 стоит CPU: ~1,95 ядра против ~1,3 у C2 на нагрузке замера (+45%). Пересмотреть, если упрёмся в CPU (BACKLOG «CPU только с C1»).
- app выходит на плато ~430–455 МБ и дальше не растёт.
