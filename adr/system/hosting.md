# Хостинг, сборка образов и деплой

Область: система · Диаграммы: [c4/deployment](../c4/deployment.md) · Код: `backend/deploy/compose.yml`, `backend/.github/workflows/deploy.yml`, `frontend/deploy/compose.yml`, `frontend/.github/workflows/deploy.yml`, `server/` воркспейса

## Контекст

Бюджет минимальный, нагрузка на старте небольшая, разработчик один. Инфраструктура должна быть простой и укладываться в один дешёвый сервер. Бэкенд и фронтенд — разные репозитории, выкатываться они должны независимо.

## Решение

- **Один VPS** (Ubuntu 24.04, 1 ГБ RAM, 2 vCPU, 7 ГБ диска, `212.119.43.160`), docker compose, без k8s. Лимиты памяти на каждый контейнер без свопа ([memory-budget](memory-budget.md)), swap 1 ГБ — только для хоста. Настройка сервера — [server-hardening](../security/server-hardening.md).
- **Два compose-проекта**, каждый в своём репозитории (`deploy/compose.yml`): `qgames-backend` (postgres + app) и `qgames-frontend` (web). Общая внешняя docker-сеть `qgames`; web ходит в `app:8080`. Наружу опубликован только web (80, 443).
- **CI — GitHub Actions** (`deploy.yml`): push в ветку `deploy` или ручной запуск → проверки (бэкенд `./gradlew build`; фронт typecheck, lint, unit, без e2e) → образ в **GHCR** (`qgames-app`, `qgames-web`, тег — sha коммита) → SSH на VPS. Секреты — окружение `production` репозитория (`DEPLOY_HOST`, `DEPLOY_PORT`, `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS`), `PUBLIC_*` фронта — переменные окружения. При изменении контракта бэкенд выкатывается первым.
- **`deploy.sh <backend|frontend> <sha>`** (`server/deploy.sh` → `/opt/qgames/bin/`) — forced command ключа пользователя `deploy`: CI может только запустить его. Скачивает `deploy/compose.yml` репозитория на этом коммите (репозитории публичные), `pull` + `up --wait`; не поднялось — откат на прежние compose и тег. Деплои под общей блокировкой, после успеха — `docker image prune -af` (диск 7 ГБ).
- **Секреты на сервере:** `/opt/qgames/backend/.env` (пароль БД, key id, `GOOGLE_CLIENT_IDS`, первый админ), JWT-ключи ES256 — `/opt/qgames/keys` (сгенерированы на сервере). В репозиториях их нет.
- **Spring-профиль `prod`:** OpenAPI и Swagger выключены жёстко, actuator — только `health` без деталей, у БД и JWT-ключей нет значений по умолчанию.
- **Домен — DuckDNS:** портал `qgames.duckdns.org`, админка `admin.qgames.duckdns.org` (поддомены DuckDNS резолвятся в тот же IP). IP статический, обновлять его не нужно. TLS — [reverse-proxy](reverse-proxy.md).

## Рассмотренные варианты

| Вариант | Почему нет |
|---|---|
| Сборка образов на VPS | Gradle съедает 2–3 ГБ RAM рабочего сервера |
| Jib / bootBuildImage | Отдельный шаг перед compose / медленно и громоздко |
| Один общий прод-compose в бэкенде | Конфиг web живёт не рядом с ним; решение пользователя — каждый репозиторий владеет своим compose |
| Pull со стороны сервера (таймер проверяет новые образы) | Деплой с задержкой и без статуса в Actions |
| Копирование compose на сервер через scp | Forced command не пускает scp; публичные репозитории отдают файл по sha |

## Последствия

- Нет отказоустойчивости: VPS упал — портал недоступен. Бэкапов БД пока нет (BACKLOG).
- Пользователь `deploy` в группе docker — фактически root, если ключ CI утечёт; forced command сужает его до `deploy.sh`.
- Пакеты GHCR должны быть публичными: сервер скачивает образы без токена.
