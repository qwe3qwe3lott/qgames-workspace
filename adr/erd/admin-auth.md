# ERD · admin-auth

Источник правды — `backend/admin-auth/admin-auth/src/main/resources/db/changelog/admin-auth/DDL/`. Решения: [admin-separation](../security/admin-separation.md), [jwt-and-refresh](../security/jwt-and-refresh.md).

```mermaid
erDiagram
  admin {
    uuid id PK
    varchar login UK "64, точное сравнение, admin_login_uq"
    varchar password_hash "255, Argon2id"
    timestamptz created_at
  }
  admin_refresh_token {
    uuid id PK
    uuid admin_id FK
    uuid family_id "admin_refresh_token_family_idx"
    varchar token_hash UK "64, SHA-256"
    timestamptz expires_at
    timestamptz revoked_at "nullable"
    timestamptz rotated_at "nullable"
    timestamptz created_at
  }

  admin ||--o{ admin_refresh_token : "сессии, cascade"
```

| Таблица | Назначение | Ограничения |
|---|---|---|
| `admin` | Администратор. Ролей нет, первого админа создаёт бутстрап, если таблица пуста | `admin_login_uq` |
| `admin_refresh_token` | Refresh-токены админки, устроены как у игроков | `admin_refresh_token_hash_uq` |

Имена таблиц уникальны в приложении, поэтому `admin_refresh_token`, а не `refresh_token` ([migrations](../backend/migrations.md)).
