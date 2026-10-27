# C4 · Уровень 2 — контейнеры

```mermaid
C4Container
  title qgames — контейнеры

  Person(player, "Игрок")
  Person(admin, "Администратор")
  System_Ext(google, "Google Identity Services")

  System_Boundary(qgames, "qgames") {
    Container(portal, "Портал", "React SPA, Rsbuild, TanStack", "Комнаты, партии, профиль; apps/portal")
    Container(web, "web", "nginx", "Статика обоих SPA и reverse proxy /api в app")
    Container(adminApp, "Админка", "React SPA, Rsbuild, TanStack", "Список администраторов; apps/admin")
    Container(app, "app", "Kotlin, Spring Boot 4, Spring Modulith", "REST API групп portal и admin, SSE-потоки")
    ContainerDb(db, "PostgreSQL", "PostgreSQL 18", "Аккаунты, комнаты, журналы партий; LISTEN/NOTIFY")
  }

  Rel(player, portal, "Открывает", "HTTPS")
  Rel(admin, adminApp, "Открывает", "HTTPS")
  Rel(portal, web, "/api/** кроме /api/admin", "JSON, SSE, куки")
  Rel(adminApp, web, "Только /api/admin/**", "JSON, куки")
  Rel(web, app, "Проксирует", "HTTP/1.1, без буферизации")
  Rel(app, db, "SQL; LISTEN/NOTIFY room_events, session_events", "JDBC, Exposed")
  Rel(portal, google, "ID token", "GIS")
  Rel(app, google, "JWKS", "HTTPS")

  UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

| Контейнер | Ответственность | Код | Решения |
|---|---|---|---|
| Портал | CSR SPA игрока: вход, профиль, каталог, комнаты, доска партии. Правил игр не знает | `frontend/apps/portal`, `packages/*` | [frontend-apps](../frontend/frontend-apps.md), [frontend-game-logic](../frontend/frontend-game-logic.md) |
| Админка | CSR SPA администратора, ходит только в группу `admin` | `frontend/apps/admin` | [admin-separation](../security/admin-separation.md) |
| web | Один образ nginx: по server-блоку на приложение, статика и proxy в app того же origin | `frontend/docker/nginx` | [reverse-proxy](../system/reverse-proxy.md) |
| app | Модульный монолит, один процесс на порту 8080, один инстанс | `backend/*` | [backend-architecture](../backend/backend-architecture.md), [scaling](../backend/scaling.md) |
| PostgreSQL | Одна БД `qgames`, одна роль; рассылка событий потокам | миграции в `backend/<m>/<m>` | [data-access](../backend/data-access.md), [realtime-transport](../game/realtime-transport.md) |

## Связи

- **Same-origin.** Каждый SPA ходит в API своего хоста: портал (`<домен>`) — в `/api/**`, админка (`admin.<домен>`) — только в `/api/admin/**`. Чужая группа на хосте отвечает 404. CORS нет. Локально вместо nginx — dev-proxy Rsbuild (`pnpm dev`) → [session-tokens](../security/session-tokens.md).
- **REST + SSE.** Действия — REST/JSON, события комнаты и партии — SSE. Ошибки — `ProblemDetail` с машиночитаемым `code` → [api-contract](../contract/api-contract.md), [realtime-transport](../game/realtime-transport.md).
- **Контракт — OpenAPI** двух групп (`/v3/api-docs/portal`, `/v3/api-docs/admin`). Фронт генерирует по ним клиент Orval → [api-client-generation](../contract/api-client-generation.md).
- **Сессия — HttpOnly-куки**, их ставит app. Фронт токенов не видит → [jwt-and-refresh](../security/jwt-and-refresh.md).

Дальше: компоненты [app](3-backend.md) и [фронта](3-frontend.md), [развёртывание](deployment.md).
