# C4 · Уровень 3 — компоненты app (бэкенд)

Модульный монолит на Spring Modulith: модули с явными границами в одном процессе ([backend-architecture](../backend/backend-architecture.md)).

```mermaid
C4Component
  title app — модули

  Container(web, "web", "nginx")
  ContainerDb(db, "PostgreSQL")
  System_Ext(google, "Google JWKS")

  Container_Boundary(app, "app (Spring Boot)") {
    Component(sec, "Security", "Spring Security, app", "Две цепочки: /api/admin/** и остальное; JWT из куки")
    Component(oapi, "OpenAPI", "springdoc, app", "Группы portal и admin")
    Component(ua, "user-auth", "модуль", "Аккаунты игроков, вход, JWT игроков, профиль")
    Component(aa, "admin-auth", "модуль", "Администраторы, вход, JWT админов")
    Component(game, "game", "модуль", "Каталог игр, комнаты, партии, SSE-потоки, джобы")
    Component(rules, "games/*", "чистый Kotlin", "Правила игр: game-core, nothing, checkers")
    Component(libs, "libs/common-*", "библиотеки", "Ошибки, RequestUserContext, OpenAPI-кастомайзеры")
  }

  Rel(web, sec, "HTTP")
  Rel(sec, ua, "/api/auth, /api/users")
  Rel(sec, aa, "/api/admin/**")
  Rel(sec, game, "/api/games, /api/rooms")
  Rel(game, ua, "Читает профиль, слушает UserProfileChanged", "user-auth-api")
  Rel(game, rules, "GameRules, SessionEngine")
  Rel(ua, google, "JWKS", "HTTPS")
  Rel(ua, db, "user*")
  Rel(aa, db, "admin*")
  Rel(game, db, "game, room*", "+ LISTEN/NOTIFY")

  UpdateLayoutConfig($c4ShapeInRow="4", $c4BoundaryInRow="1")
```

| Компонент | Ответственность | Пути API | Код |
|---|---|---|---|
| `user-auth` | Аккаунты игроков (неизменяемый логин, ник, аватар), регистрация через Google, вход по Google и паролю, JWT и куки портала | `/api/auth/*`, `/api/users/me/*` | `backend/user-auth/{user-auth,user-auth-api}` |
| `admin-auth` | Администраторы: логин и пароль, без регистрации, JWT и куки админки. Упрощённая копия user-auth | `/api/admin/auth/*`, `/api/admin/admins/*` | `backend/admin-auth/…` |
| `game` | Каталог игр, комнаты, участники, присутствие, партии и их журнал, SSE, таймеры | `/api/games/*`, `/api/rooms/*` | `backend/game/{game,game-api}` → [3-backend-game](3-backend-game.md) |
| `games/*` | Правила игр без Spring и IO: `game-core` (модель и общие блоки), `nothing-game`, `checkers-game` | — | `backend/games/*` → [3-backend-games](3-backend-games.md) |
| `app` | `@SpringBootApplication`, Security, группы OpenAPI, `application.yml`, сводный Liquibase-master, все интеграционные тесты | — | `backend/app` |
| `libs/*` | Инфраструктура без бизнес-логики: `common-exception`, `common-web`, `common-test`, `doc-patch` (применитель событий-патчей) | — | `backend/libs` |

## Границы и связи модулей

- Модуль = `<m>/<m>` (реализация) + `<m>/<m>-api` (публичный контракт: REST-интерфейсы, DTO, события, публичные описания таблиц). Модуль зависит только от `libs/*`, `games/*` и чужих `-api`. Границы проверяет `ModularityTest` → [module-communication](../backend/module-communication.md).
- Сейчас межмодульная связь одна: **game → user-auth-api**. game читает ник и аватар через `UserProfileTable` (join, только чтение) и слушает `UserProfileChanged`, после чего публикует `profile-changed` в комнаты пользователя.
- Слои внутри модуля: контроллер → сервис → фасад-репозиторий → `…ExposedRepository`. DTO только в контроллерах → [backend-layers](../backend/backend-layers.md).

## Security и аутентификация

Устройство цепочек, кук, refresh, бутстрапа админа и профиля игрока — в [3-backend-auth](3-backend-auth.md), потоки входа и refresh — в [dynamic/auth](dynamic/auth.md).

## Фоновые джобы (модуль game)

| Джоб | Интервал | Что делает |
|---|---|---|
| `RoomConnectionHeartbeatJob` | 5 с | ping в SSE-потоки комнат, продление аренды подключений |
| `RoomConnectionCleanupJob` | — | удаляет протухшие подключения, уводит пользователей без подключений |
| `EmptyRoomCleanupJob` | — | удаляет комнаты, пустые дольше `empty-ttl` (30m) |
| `MoveTimeoutJob` | 1 с | обрабатывает истёкшие дедлайны хода по `room_session.move_deadline` |
| `NotPublishedGameCleanupJob` | 1m | отменяет партии и удаляет комнаты игр `NOT_PUBLISHED` |

Все джобы выбирают id без блокировки, затем обрабатывают каждую комнату в своей транзакции под блокировкой комнаты с перепроверкой. У каждого джоба свой флаг `…-enabled` ([scaling](../backend/scaling.md)).

## Состояние в памяти процесса

`RoomStreamRegistry` и `SessionStreamRegistry` (открытые SSE-потоки), `SessionStateCache` (Caffeine, кеш свёрток партий). Больше ничего: счётчики, блокировки и присутствие хранятся в БД → [scaling](../backend/scaling.md).
