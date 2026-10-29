# Хостинг и сборка образов

Область: система · Диаграммы: [c4/deployment](../c4/deployment.md) · Код: `backend/docker/app.Dockerfile`, `backend/docker-compose.yml`, `frontend/docker/`

## Контекст

Бюджет минимальный, нагрузка на старте небольшая, разработчик один. Инфраструктура должна быть простой и укладываться в один дешёвый сервер.

## Решение

- **Один VPS на 1 ГБ RAM, docker compose, без k8s:** `web` (nginx) + `app` + PostgreSQL. Лимиты памяти заданы на каждый контейнер без свопа ([memory-budget](memory-budget.md)).
- **Образы собираются в CI** и пушатся в registry, на VPS выполняется только `docker compose pull`.
- Образ app собирается multi-stage Dockerfile (`:app:bootJar`). Образ `web` — nginx со статикой обоих SPA ([reverse-proxy](reverse-proxy.md)).
- Swagger и OpenAPI в проде выключены (`API_DOCS_ENABLED=false`).
- **Домен — DuckDNS:** портал `qgames.duckdns.org`, админка `admin.qgames.duckdns.org`. Локальный стенд — те же правила на `LOCAL_DOMAIN` (`local.qgames.duckdns.org` в `hosts`), [reverse-proxy](reverse-proxy.md).

## Рассмотренные варианты

| Вариант | Почему нет |
|---|---|
| Сборка образов на VPS | Gradle съедает 2–3 ГБ RAM рабочего сервера |
| Jib | Нужен отдельный шаг `jibDockerBuild` перед compose |
| bootBuildImage | Медленно и громоздко |

## Последствия

- Нет отказоустойчивости: VPS упал — портал недоступен.
- Деплой пока не выполнялся (BACKLOG «Прод-деплой»).

## Открытые вопросы

- Решить при деплое: CI (GitHub Actions или GitLab CI), registry, секреты, обновление IP в DuckDNS, источник TLS-сертификатов ([reverse-proxy](reverse-proxy.md)), бэкапы PostgreSQL (`pg_dump` по расписанию с копиями вне VPS), профиль `prod`.
