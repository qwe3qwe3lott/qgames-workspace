# ERD · user-auth

Источник правды — `backend/user-auth/user-auth/src/main/resources/db/changelog/user-auth/DDL/`. Решения: [player-accounts](../security/player-accounts.md), [jwt-and-refresh](../security/jwt-and-refresh.md), [data-access](../backend/data-access.md).

```mermaid
erDiagram
  user {
    uuid id PK
    varchar login UK "32, неизменяем, user_login_uq"
    varchar nickname "32, неуникален"
    varchar avatar "16, enum CAT, DOG"
    timestamptz created_at
  }
  user_identity {
    uuid id PK
    uuid user_id FK
    varchar provider "32, GOOGLE, PASSWORD"
    varchar subject "320, sub Google или логин"
    varchar password_hash "255, nullable, Argon2id"
    timestamptz created_at
  }
  user_refresh_token {
    uuid id PK
    uuid user_id FK
    uuid family_id "user_refresh_token_family_idx"
    varchar token_hash UK "64, SHA-256"
    timestamptz expires_at
    timestamptz revoked_at "nullable"
    timestamptz rotated_at "nullable"
    timestamptz created_at
  }

  user ||--o{ user_identity : "способы входа, cascade"
  user ||--o{ user_refresh_token : "сессии, cascade"
```

| Таблица | Назначение | Ограничения |
|---|---|---|
| `user` | Аккаунт игрока | `user_login_uq` |
| `user_identity` | Способ входа. К аккаунту можно привязать несколько, но не больше одного на провайдера | `user_identity_provider_subject_uq (provider, subject)`, `user_identity_user_provider_uq (user_id, provider)` |
| `user_refresh_token` | Refresh-токены с ротацией по семье (`family_id`) | `user_refresh_token_hash_uq` |

**Чтение другими модулями:** `UserProfileTable` в `user-auth-api` — публичное описание колонок `id`, `nickname`, `avatar` таблицы `user`. Модуль game делает по нему join (только чтение), см. [erd/game](game.md).
