# C4 · Развёртывание

Прод — один VPS на 1 ГБ RAM под docker compose, без k8s. Прод-деплой пока не делался. CI, registry, DuckDNS, TLS и бэкапы решаются при деплое ([hosting](../system/hosting.md)).

```mermaid
C4Deployment
  title qgames — прод (план) и локальный стенд

  Deployment_Node(browser, "Браузер", "Chrome, Firefox…") {
    Container(spa, "Портал / Админка", "SPA", "Статика с web")
  }

  Deployment_Node(vps, "VPS 1 ГБ", "Linux, Docker") {
    Deployment_Node(compose, "docker compose", "mem_limit = memswap_limit") {
      Container(web, "web", "nginx-unprivileged, 48m", "TLS, статика, proxy /api")
      Container(app, "app", "JDK 25, 512m", "Spring Boot, порт 8080")
      ContainerDb(db, "postgres", "PostgreSQL 18, 128m", "Том с данными")
    }
  }

  Deployment_Node(ci, "CI", "решить при деплое") {
    Container(registry, "registry", "Docker images", "Образы app и web")
  }

  Rel(spa, web, "HTTPS", "<домен>, admin.<домен>")
  Rel(web, app, "HTTP/1.1", "proxy_buffering off")
  Rel(app, db, "JDBC", "пул 5 + LISTEN")
  Rel(registry, app, "Образы app и web", "docker compose pull")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="2")
```

## Узлы и бюджет памяти

Лимит каждого контейнера — `mem_limit` = `memswap_limit` без свопа: при нехватке памяти контейнер убивается OOM-kill, тихой деградации нет. Настройки JVM и PostgreSQL и их обоснование — в [memory-budget](../system/memory-budget.md).

| Что | Лимит | Простой | Пик под нагрузкой |
|---|---|---|---|
| ОС, Docker, sshd | — | ~200 МБ | ~200 МБ |
| nginx (`web`) | 48m | ~15 МБ | ~29 МБ, CPU ~10–13% |
| app | 512m | ~290 МБ | ~430–455 МБ |
| PostgreSQL | 128m | ~30–35 МБ | ~85–95 МБ (часть — вытесняемый кеш страниц) |
| Запас | ~135 МБ | | |
| Итого | 888 МБ по лимитам | ~540 МБ | ~780 МБ |

Нагрузка замера (локальный стенд, через nginx портала, 5 минут): 45 комнат по 2 игрока и 2 наблюдателя, у каждого потоки комнаты и партии (360 SSE), ходы без остановки — ~190 ходов/с, ~4400 SSE-кадров/с. OOM-kill не было. Было 2 ответа 504 от nginx (BACKLOG «Редкие 504»).

## Сеть и proxy

- Наружу открыт только `web` с TLS. Один образ nginx обслуживает два server-блока: портал (`:3000` локально) и админку (`:3001`). Портал проксирует `/api/` кроме `/api/admin/` (на него 404), админка — только `/api/admin/`. В upstream попадает только IPv4-адрес `API_UPSTREAM`: по IPv6 `host.docker.internal` подключение падает с 502.
- **SSE через proxy:** app отдаёт `X-Accel-Buffering: no`, у nginx `proxy_buffering off`, `proxy_read_timeout 60s` (длиннее ping потоков в 5 с), HTTP/1.1 с пустым `Connection`.
- Заголовки безопасности и CSP ставит nginx на всех ответах, включая API → [reverse-proxy](../system/reverse-proxy.md).
- Swagger и OpenAPI в проде выключены (`API_DOCS_ENABLED=false`, ручки отвечают 404). Проверяется вручную на стенде: `API_DOCS_ENABLED=false docker compose up -d --wait app`.

## Локальный стенд

| Что | Где | Как поднять |
|---|---|---|
| app + postgres | `backend/docker-compose.yml`, профиль `local` | `docker compose up --build -d --wait` |
| web (оба SPA) | `frontend/docker-compose.yml`, `API_UPSTREAM` = `host.docker.internal:8080` | `docker compose up --build -d --wait` |
| dev-режим фронта | Rsbuild dev-server + `server.proxy` | `pnpm dev` (portal :3000, admin :3001) |

Профиль `local` добавляет первого админа `admin`/`admin` и тестовых игроков `qwe3qwe1…10` с паролем `qwe3qwe3`. Переменные `PUBLIC_*` фронта вшиваются в сборку из `apps/<app>/.env`.
