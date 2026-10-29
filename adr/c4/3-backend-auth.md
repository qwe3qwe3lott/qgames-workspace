# C4 · Уровень 3 — аутентификация (user-auth, admin-auth, Security)

Решения: [session-tokens](../security/session-tokens.md), [jwt-and-refresh](../security/jwt-and-refresh.md), [admin-separation](../security/admin-separation.md), [player-accounts](../security/player-accounts.md). Потоки — [dynamic/auth](dynamic/auth.md). Таблицы — [erd/user-auth](../erd/user-auth.md), [erd/admin-auth](../erd/admin-auth.md).

## Две цепочки Security (`SecurityConfig`, app)

| Цепочка | Пути | Токен | permitAll |
|---|---|---|---|
| Админка, `@Order(1)` | `/api/admin/**` | кука `admin_access_token` или Bearer, issuer `qgames-admin-auth` | `/api/admin/auth/**` |
| Портал, `@Order(2)` | всё остальное | кука `access_token` или Bearer, issuer `qgames-user-auth` | `/api/auth/**`, `GET /api/games`, `GET /api/games/*`, Swagger, `/actuator/health/**` |

- Первым в обеих цепочках стоит `FetchMetadataFilter`: межсайтовый запрос к `/api/**` (`Sec-Fetch-Site` `cross-site`/`same-site` или `Sec-Fetch-Mode: navigate`) получает 403 `CROSS_SITE_REQUEST` ещё до проверки токена.
- Токен игрока не проходит в админку, токен админа — на портал: у них разные ключи и issuer. Без токена или с недействительным — 401 `UNAUTHENTICATED`.
- JWT проверяется локально по публичному ключу из конфигурации (`NimbusJwtDecoder` + `SingleKeyJWSKeySelector`, JWKS-эндпоинта нет): подпись ES256, срок, issuer. `kid` не сверяется.
- На ручках аутентификации access-токен не читается (`CookieBearerTokenResolver`), поэтому протухшая кука не ломает refresh. На permitAll-ручках каталога протухшая кука даёт 401 — принято осознанно.
- Пользователь запроса — `RequestUserContext.userId()` (`sub` токена). В сигнатурах контракта userId нет.

## Куки

| Приложение | access | refresh |
|---|---|---|
| Портал | `access_token`, `Path=/`, 15 мин | `refresh_token`, `Path=/api/auth`, 30 дней |
| Админка | `admin_access_token`, `Path=/api/admin`, 5 мин | `admin_refresh_token`, `Path=/api/admin/auth`, 15 мин скользящий |

Все куки `HttpOnly; Secure; SameSite=Lax`, host-only. Имена — константы `AuthCookieNames` в `<m>-api`. Имена разные, потому что оба фронта ходят в одно приложение. Refresh, отклонённый с 401, удаляет обе куки. Logout отзывает сессию и всегда удаляет обе куки. Смена пароля выдаёт новую сессию.

## Refresh-токены

Случайная строка, в БД хранится только SHA-256. Ротация при каждом обновлении, семья — `family_id`, ротацию от отзыва отличает `rotated_at`. Повтор ротированного токена в окне терпимости 10 с (если в семье есть активный) выдаёт ещё одну пару той же сессии. Позже окна, после logout или при краже вся семья отзывается с `REFRESH_TOKEN_REUSED`.

## Аккаунты игроков (user-auth)

- **Регистрация только через внешнего провайдера** (сейчас Google): `POST /api/auth/google/register {idToken, login, password?}`. Ошибки: 409 `ACCOUNT_ALREADY_EXISTS`, 409 `LOGIN_TAKEN`. Гонка двух регистраций упирается в уникальные индексы, и `UniqueViolations` переводит их в те же коды.
- **Вход:** `POST /api/auth/google/login` (непривязанный Google — 404 `REGISTRATION_REQUIRED`) или `POST /api/auth/login {login, password}`. Логин при входе обрезается и приводится к нижнему регистру. Сброса пароля нет: игрок входит через Google и меняет пароль.
- **Google:** подпись ID token проверяется по JWKS Google, также `iss` и `aud` (`GOOGLE_CLIENT_IDS`). Из claims берётся только `sub`.
- **Профиль:** логин `^[a-z0-9_-]{3,32}$` уникален и неизменяем. Ник 3–32 символа, неуникален, при регистрации равен логину. Аватар — `CAT`/`DOG`. Меняется через `PATCH /api/users/me/profile`, каждое изменение публикует `UserProfileChanged`.
- **Способы входа:** `user_identity(provider, subject)`, у PASSWORD субъект — логин. Привязка только явная, из профиля (`/api/users/me/login-methods/*`). Пароли — Argon2id.
- **Тестовые игроки** (только профиль `local`): `DevUsersBootstrapService` создаёт недостающих игроков из `qgames.auth.dev-users`.

## Администраторы (admin-auth)

- Регистрации и ролей нет. Первого админа создаёт `AdminBootstrapService` из `ADMIN_BOOTSTRAP_LOGIN`/`ADMIN_BOOTSTRAP_PASSWORD`, только если таблица `admin` пуста. Проверка и вставка идут в одной транзакции, при создании пишется WARN. Если задана только одна из двух переменных, приложение не стартует.
- Логин сравнивается точно. При неизвестном логине проверяется dummy-хеш, чтобы время ответа не выдавало существующие логины.
- Текущий админ — `GET /api/admin/admins/me`, список — `GET /api/admin/admins`.

## Ключи

Ключи подписи берутся из конфигурации или секретов и при старте не генерируются. `backend/docker/dev-keys` — только для локальной разработки: `jwt-*.pem` (user-auth, env `JWT_*`), `admin-jwt-*.pem` (admin-auth, env `ADMIN_JWT_*`).
