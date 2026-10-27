# ERD · game

Источник правды — `backend/game/game/src/main/resources/db/changelog/game/DDL/`. Решения: [game-catalog](../game/game-catalog.md), [room-lifecycle](../game/room-lifecycle.md), [room-presence](../game/room-presence.md), [session-state](../game/session-state.md).

```mermaid
erDiagram
  game {
    uuid id PK "фиксированные UUID в DML"
    varchar code UK "32, nothing, checkers…"
    text title
    text description
    integer sort_order
    varchar publish_status "32, PUBLISHED, HIDDEN, NOT_PUBLISHED"
  }
  room {
    uuid id PK
    varchar game_code FK "room_game_code_idx"
    uuid owner_id "nullable, без FK"
    varchar status "16, WAITING, IN_GAME"
    uuid current_session_id "nullable, без FK"
    timestamptz empty_since "nullable, room_empty_since_idx"
    json game_settings "часы и настройки игры"
    timestamptz created_at
  }
  room_member {
    uuid room_id PK, FK
    uuid user_id PK "room_member_user_idx"
    varchar role "16, PLAYER, SPECTATOR"
    timestamptz joined_at
    timestamptz left_at "nullable, отсутствующий игрок партии"
  }
  room_connection {
    uuid id PK
    uuid room_id FK
    uuid user_id
    timestamptz expires_at "аренда 20 с"
  }
  room_session {
    uuid id PK
    uuid room_id FK
    varchar game_code FK
    varchar status "16, IN_PROGRESS, FINISHED, CANCELLED"
    bigint seed
    bigint last_seq "default 0"
    json game_settings "снапшот настроек"
    timestamptz move_deadline "nullable, проекция для MoveTimeoutJob"
    timestamptz created_at
    timestamptz finished_at "nullable"
  }
  room_session_player {
    uuid session_id PK, FK
    integer seat PK
    uuid user_id "уникален в партии"
  }
  room_session_event {
    uuid session_id PK, FK
    bigint seq PK
    varchar method "8, PUT, PATCH, DELETE, INFO"
    varchar code "64"
    json data "форма кадра"
    timestamptz created_at "для повтора"
  }
  user {
    uuid id PK "user-auth, только чтение"
    varchar nickname
    varchar avatar
  }

  game ||--o{ room : "game_code"
  game ||--o{ room_session : "game_code"
  room ||--o{ room_member : "cascade"
  room ||--o{ room_connection : "cascade"
  room ||--o{ room_session : "cascade"
  room_session ||--o{ room_session_player : "cascade"
  room_session ||--o{ room_session_event : "журнал, cascade"
  user ||..o{ room_member : "user_id, без FK"
```

| Таблица | Назначение |
|---|---|
| `game` | Каталог игр, строки вставляются DML-миграциями |
| `room` | Комната под игру. Блокировка строки (`FOR UPDATE`) сериализует все её мутации |
| `room_member` | Участники и их роли |
| `room_connection` | Присутствие: одно открытое SSE-подключение — одна строка с арендой |
| `room_session` | Партия. Состояние не хранится, только `last_seq` и проекция дедлайна |
| `room_session_player` | Места игроков партии (`room_session_player_user_uq (session_id, user_id)`) |
| `room_session_event` | Журнал событий-патчей, только дописывается. Состояние — его свёртка |
| `user` | Таблица user-auth, читается через `UserProfileTable` (join за ником и аватаром) |

**Индексы:** `room_session_room_idx (room_id, created_at)`, `room_session_move_deadline_idx`, `room_connection_room_user_idx`, `room_connection_expires_at_idx`. FK на `user` нет намеренно: модуль пишет только в свои таблицы, связь с чужой таблицей существует только в коде ([module-communication](../backend/module-communication.md)).
