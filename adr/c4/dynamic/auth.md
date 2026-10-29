# C4 · Dynamic — вход и обновление сессии

Устройство — [3-backend-auth](../3-backend-auth.md). Решения: [session-tokens](../../security/session-tokens.md), [jwt-and-refresh](../../security/jwt-and-refresh.md), [player-accounts](../../security/player-accounts.md).

## Регистрация и вход через Google

```mermaid
sequenceDiagram
  autonumber
  actor P as Игрок
  participant SPA as Портал
  participant G as Google GIS
  participant API as app (user-auth)
  participant DB as PostgreSQL

  P->>SPA: «Войти через Google»
  SPA->>G: GIS-кнопка
  G-->>SPA: ID token (держится только в памяти)
  SPA->>API: POST /api/auth/google/login {idToken}
  API->>G: JWKS (подпись, iss, aud)
  API->>DB: user_identity по (GOOGLE, sub)
  alt Google-аккаунт не привязан
    API-->>SPA: 404 REGISTRATION_REQUIRED
    P->>SPA: логин и необязательный пароль
    SPA->>API: POST /api/auth/google/register {idToken, login, password?}
    API->>DB: INSERT user, user_identity (уникальные индексы против гонки)
    Note over API: UserProfileChanged → слушатели после коммита
  end
  API->>DB: INSERT user_refresh_token (SHA-256)
  API-->>SPA: 200/201 UserResponse + Set-Cookie access_token, refresh_token
```

Ошибки регистрации: 409 `LOGIN_TAKEN`, 409 `ACCOUNT_ALREADY_EXISTS`, 401 `INVALID_GOOGLE_TOKEN`. Вход по паролю — `POST /api/auth/login {login, password}`, ответ такой же.

## Протухший access-токен → single-flight refresh

```mermaid
sequenceDiagram
  autonumber
  participant Q as TanStack Query (2 запроса)
  participant M as fetch-mutator (@qgames/api)
  participant API as app

  Q->>M: GET /api/rooms/{id}
  Q->>M: GET /api/users/me
  M->>API: оба запроса с кукой access_token
  API-->>M: 401 UNAUTHENTICATED (оба)
  M->>API: один POST /api/auth/refresh (кука refresh_token, Path=/api/auth)
  alt токен действителен или повтор в окне 10 с
    API-->>M: 200 + новые куки (ротация)
    M->>API: повтор исходных запросов, по одному разу
    API-->>Q: 200
  else отозван или повтор позже окна
    API-->>M: 401 REFRESH_TOKEN_REUSED / UNAUTHENTICATED, куки удалены
    M-->>Q: ApiError 401, пользователь — гость
  else сервер недоступен (сеть, 5xx)
    M-->>Q: ApiError NETWORK_ERROR, сессия не тронута
  end
```

- Обновление общее на все запросы вкладки (single-flight). Параллельные вкладки обновляются одной кукой — их спасает окно терпимости 10 с на сервере.
- Другие 401 (например, `INVALID_GOOGLE_TOKEN`) сессию не трогают. Запросы `{authPath}/*` не повторяются.
- Админка устроена так же, отличается префикс: `/api/admin/auth/*`, куки `admin_*`, access 5 мин, refresh 15 мин скользящий.
- SSE-обёртка не знает статуса ответа `EventSource`, поэтому вызывает `refreshSession()` перед каждой попыткой переподключения. Окончательно поток закрывается только при исходе `guest`, а при `unavailable` переподключение продолжается.
