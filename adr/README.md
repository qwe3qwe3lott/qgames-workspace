# Архитектура qgames

Единое описание системы: **почему** она так устроена (ADR), **из чего** состоит (C4) и **как хранит данные** (ERD). Правила написания кода — в `CLAUDE.md` репозиториев.

В путях к коду `backend/` — репозиторий `qgames-backend-monorepo`, `frontend/` — `qgames-frontend-monorepo`. Все три репозитория лежат рядом в одной папке. Диаграммы — Mermaid, их показывают GitHub и IDE.

## Как читать

1. Общая картина — [контекст](c4/1-context.md), затем [контейнеры](c4/2-containers.md).
2. Нужная часть — компоненты уровня 3 и динамика.
3. Почему так — ADR из индекса ниже: в каждом контекст, решение, отвергнутые варианты и последствия.

## Диаграммы

| Файл | Что показывает |
|---|---|
| [c4/1-context](c4/1-context.md) | Пользователи, система, Google |
| [c4/2-containers](c4/2-containers.md) | SPA, nginx, app, PostgreSQL и связи между ними |
| [c4/3-backend](c4/3-backend.md) | Модули app, джобы, состояние в памяти |
| [c4/3-backend-auth](c4/3-backend-auth.md) | Security, куки, refresh, аккаунты, админы |
| [c4/3-backend-game](c4/3-backend-game.md) | Каталог игр, комнаты, партии |
| [c4/3-backend-games](c4/3-backend-games.md) | Модель игры: патчи, `GameRules`, блоки core |
| [c4/3-frontend](c4/3-frontend.md) | Приложения и пакеты фронта, данные, SSE |
| [c4/3-frontend-portal](c4/3-frontend-portal.md) | Маршруты и страницы портала и админки |
| [c4/deployment](c4/deployment.md) | VPS, compose, бюджет памяти, локальный стенд |
| [dynamic/auth](c4/dynamic/auth.md) · [dynamic/room-stream](c4/dynamic/room-stream.md) · [dynamic/move](c4/dynamic/move.md) | Вход и refresh · поток комнаты и присутствие · ход и поток партии |
| [erd/user-auth](erd/user-auth.md) · [erd/admin-auth](erd/admin-auth.md) · [erd/game](erd/game.md) | Схема БД по модулям |

## Решения (ADR)

**Система** (`system/`): [repositories-layout](system/repositories-layout.md) — три репозитория и воркспейс · [game-data-compatibility](system/game-data-compatibility.md) — игры не версионируются · [hosting](system/hosting.md) — один VPS 1 ГБ, compose, образы из CI · [memory-budget](system/memory-budget.md) — флаги JVM и PostgreSQL · [reverse-proxy](system/reverse-proxy.md) — nginx, same-origin, CSP

**Бэкенд** (`backend/`): [backend-architecture](backend/backend-architecture.md) — модульный монолит Spring Modulith · [game-rules-modules](backend/game-rules-modules.md) — правила игр в чистых Kotlin-модулях · [backend-stack](backend/backend-stack.md) — Spring MVC + virtual threads · [data-access](backend/data-access.md) — PostgreSQL, Exposed DSL, без сырого SQL · [backend-layers](backend/backend-layers.md) — модели, мапперы, двухслойный репозиторий, ошибки · [migrations](backend/migrations.md) — абстрактный Liquibase · [module-communication](backend/module-communication.md) — `-api`, события AFTER_COMMIT, join чужой таблицы · [scaling](backend/scaling.md) — один инстанс · [backend-testing](backend/backend-testing.md) — интеграционные тесты

**Игры, комнаты, real-time** (`game/`): [session-state](game/session-state.md) — партия = свёртка журнала · [session-events-format](game/session-events-format.md) — события-патчи, общий применитель · [game-catalog](game/game-catalog.md) — три статуса публикации · [room-lifecycle](game/room-lifecycle.md) — вход, лимит наблюдателей, мгновенный выход, владение, автоудаление · [room-settings](game/room-settings.md) — настройки room/simple/advanced · [room-presence](game/room-presence.md) — присутствие = SSE-поток с арендой · [realtime-transport](game/realtime-transport.md) — REST + SSE, LISTEN/NOTIFY

**Контракт** (`contract/`): [api-contract](contract/api-contract.md) — REST, две группы OpenAPI, `ProblemDetail.code` · [game-code-in-path](contract/game-code-in-path.md) — код игры в пути, полиморфные настройки · [api-client-generation](contract/api-client-generation.md) — Orval, коммит сгенерированного кода

**Безопасность** (`security/`): [session-tokens](security/session-tokens.md) — HttpOnly-куки, без CORS и CSRF-токенов · [jwt-and-refresh](security/jwt-and-refresh.md) — ES256, ротация с окном терпимости · [admin-separation](security/admin-separation.md) — отдельная админка · [player-accounts](security/player-accounts.md) — регистрация через Google, неизменяемый логин

**Фронтенд** (`frontend/`): [frontend-monorepo](frontend/frontend-monorepo.md) — pnpm + Turborepo, один каталог версий · [frontend-apps](frontend/frontend-apps.md) — CSR SPA на Rsbuild · [frontend-architecture](frontend/frontend-architecture.md) — FSD · [frontend-libraries](frontend/frontend-libraries.md) — RHF + Zod, TS 6 · [server-state](frontend/server-state.md) — только TanStack Query, SSE в кеш · [frontend-game-logic](frontend/frontend-game-logic.md) — фронт не знает правил игр · [ui-kit](frontend/ui-kit.md) — Tailwind + shadcn · [room-ui](frontend/room-ui.md) — UX комнаты · [linting](frontend/linting.md) — gts + typescript-eslint strict

## Как вести

- **Живые ADR:** один файл — одно действующее решение, имя — slug предмета решения (без номеров и дат). Если решение меняется, ADR переписывается на месте, прежний вариант уходит в «Рассмотренные варианты» с причиной. Если от решения отказались совсем, ADR удаляется. Отложенное записывается в «Открытые вопросы» пометкой «решить при …». Новый ADR пишется по [шаблону](template.md), кладётся в папку своей группы (папка = группа в индексе выше) и добавляется в индекс. Новая группа — новая папка и новый раздел индекса.
- **Актуальность:** изменение кода, затрагивающее элемент или связь диаграммы, таблицу или колонку (ERD) или решение, обновляет `adr/` в той же задаче. Решения записываются только после согласования с пользователем.
- **Размер:** ADR ≤ ~60 строк, файл C4 ≤ ~120, ERD ≤ ~100. Если файл растёт, он делится.
- **Диаграмма + текст:** рядом с диаграммой — таблица элементов или разделы с кратким устройством, чтобы файл читался без рендера.
- **Без дублирования:** ADR отвечает «почему», C4/ERD — «что и как связано», `CLAUDE.md` — «как писать код» (со ссылкой на ADR).
