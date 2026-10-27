# C4 · Уровень 1 — контекст системы

qgames — игровой портал пошаговых настольных игр (сейчас «игра в ничто» для проверки движка и шашки, далее Каркассон). Игроки создают комнаты под игру, заходят в них по ссылке и играют партии в реальном времени. Администраторы управляют порталом через отдельную админку.

```mermaid
C4Context
  title qgames — контекст системы

  Person(player, "Игрок", "Регистрируется через Google, создаёт комнаты, играет и наблюдает партии")
  Person(admin, "Администратор", "Управляет порталом; аккаунт создаёт другой админ или бутстрап")

  System(qgames, "qgames", "Игровой портал и админка: комнаты, партии, аккаунты")

  System_Ext(google, "Google Identity Services", "Выдаёт ID token игрока; JWKS для проверки подписи")

  Rel(player, qgames, "Играет", "HTTPS, браузер")
  Rel(admin, qgames, "Администрирует", "HTTPS, браузер")
  Rel(player, google, "Выбирает аккаунт Google", "GIS-скрипт в браузере")
  Rel(qgames, google, "Проверяет подпись ID token", "HTTPS, JWKS")

  UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")
```

| Элемент | Роль | Подробнее |
|---|---|---|
| Игрок | Пользователь портала (`<домен>`) | [player-accounts](../security/player-accounts.md) |
| Администратор | Пользователь админки (`admin.<домен>`), ролей нет — все админы равны | [admin-separation](../security/admin-separation.md) |
| qgames | Три контейнера за одним nginx — см. [уровень 2](2-containers.md) | [backend-architecture](../backend/backend-architecture.md) |
| Google Identity Services | Единственный внешний провайдер личности (позже VK и др.) | [player-accounts](../security/player-accounts.md) |

Других внешних систем нет: почту портал не шлёт, платежей нет.
