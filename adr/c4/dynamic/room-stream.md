# C4 · Dynamic — поток комнаты и присутствие

Решения: [room-presence](../../game/room-presence.md), [realtime-transport](../../game/realtime-transport.md), [room-lifecycle](../../game/room-lifecycle.md). Таблицы — [erd/game](../../erd/game.md).

```mermaid
sequenceDiagram
  autonumber
  participant SPA as Портал (useRoomEvents)
  participant N as nginx
  participant C as game: контроллер потока
  participant R as RoomStreamRegistry
  participant DB as PostgreSQL
  participant L as RoomEventListener

  SPA->>N: GET /api/rooms/{id}/events (EventSource, куки)
  N->>C: proxy, без буферизации
  Note over C: JWT проверяется только при подписке
  C->>R: регистрирует подписчика (до транзакции)
  C->>DB: BEGIN, lock(room), INSERT room_connection (аренда 20 с)
  C->>DB: вход: room_member (PLAYER или SPECTATOR в пределах лимита), владение
  C->>DB: читает снапшот, pg_notify(маркер подписчика, users-changed)
  C->>DB: COMMIT
  C-->>SPA: event: snapshot (как GET комнаты)
  DB-->>L: NOTIFY room_events (после коммита, в порядке коммитов)
  L->>R: раздать подписчикам комнаты
  R-->>SPA: события до маркера отброшены, затем users-changed
  loop каждые 5 с
    Note over C,DB: RoomConnectionHeartbeatJob: ping в поток и продление аренды
  end
  SPA--xN: вкладка закрыта
  Note over C: обрыв замечается по неудачной записи ping (10–30 с)
  C->>DB: lock(room), DELETE room_connection
  C->>DB: последнее подключение: выход, передача владения, users-changed
```

## События потока комнаты

| Событие | Данные | Реакция фронта |
|---|---|---|
| `snapshot` | комната целиком | заменить кеш `GET /api/rooms/{id}` |
| `users-changed` | `ownerId` + полный список участников | заменить поля |
| `settings-changed` | настройки | заменить поле |
| `session-changed` | — (старт, конец, отмена партии) | перечитать комнату |
| `room-deleted` | — | закрыть поток, перечитать (покажется `ROOM_NOT_FOUND`) |

- У событий комнаты нет seq: каждое несёт полное значение, повтор безопасен. Гонку снапшота с событиями закрывает маркер подписчика.
- Подключений у пользователя может быть несколько (вкладки, устройства), выход наступает с закрытием последнего.
- Процесс упал или не смог удалить подключение — `RoomConnectionCleanupJob` удалит его по истечении аренды. Поток, чьё подключение исчезло, закрывается, и клиент входит заново.
- Обрыв соединения LISTEN: `RoomEventListener` переподключается и закрывает все потоки. Клиенты переподключаются и получают свежий снапшот.
- Нет мест: новичку не досталось места игрока, а наблюдателей уже не меньше `settings.room.maxSpectators` — вход откатывается, поток отвечает 409 `NO_SPECTATOR_SEAT`. `EventSource` кода не видит, поэтому портал перечитывает комнату. Если пользователь не участник и мест нет, показывается окончательный отказ без переподключения.
