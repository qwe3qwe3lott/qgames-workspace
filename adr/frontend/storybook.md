# Витрина UI-компонентов (Storybook)

Область: frontend · Диаграммы: [c4/3-frontend](../c4/3-frontend.md), [c4/deployment](../c4/deployment.md) · Код: `frontend/apps/storybook`, `frontend/packages/**/src/**/*.stories.tsx`, `frontend/docker/storybook.Dockerfile`

## Контекст

У игровых компонентов (тайлы «Круассана») много состояний: тип, поворот, фишки игроков, шаг выбора кондитера. В партии их не перебрать, а unit-тесты UI не пишем ([unit-testing](unit-testing.md)). Нужна витрина, где компонент рисуется отдельно и его состояния переключаются руками.

## Решение

- **Storybook 10** — отдельное приложение `apps/storybook` (`@qgames/storybook`) с конфигом `.storybook/`. Собирает истории `packages/**/src/**/*.stories.tsx`.
- **Истории лежат рядом с компонентом** (`CroissantTile.stories.tsx`) и в публичный `index.ts` пакета не входят.
- **Только UI на пропсах:** без бэкенда, запросов и моков сервера. Данные игры — снимок `GET /api/games/croissant` → `assets` в `packages/games/croissant/src/lib/assets.fixture.json`: снимает скрипт `pnpm --filter @qgames/game-croissant assets:fetch` с поднятого бэкенда, файл коммитится, истории и тесты читают его сгенерированной схемой `CroissantAssetsDto`.
- **Истории «Круассана»:** «Tile» собирает тайл из элементов (пекарни, тропы и их цели, центр, фишки), луга выводит `pastureHalves`, по умолчанию пустой тайл; «Tile collection» — сетка типов включённых модулей с численностью, ссылка на «Tile» несёт args типа в URL (`tileStoryHref`). Общие хелперы — `CroissantTile.storyArgs.ts`, args из URL проверяются Zod (непрошедшее — пустой слот).
- **Сборщик — Rsbuild** через `storybook-react-rsbuild`, как у приложений. Tailwind подключается тем же `@tailwindcss/postcss` и `@qgames/ui/globals.css`.
- **Состояния переключаются Controls** (args истории). Действия компонента (клик по участку) меняют args через `useArgs`.
- **Линтер:** общий `createConfig` + `eslint-plugin-storybook` (`flat/recommended`). Типы историй берутся из фреймворка `storybook-react-rsbuild`, не из `@storybook/react`. Папка `.storybook/` исключена из `check-file`.
- **Только локально:** `pnpm --filter @qgames/storybook dev` (:6006; корневой `pnpm dev` его не запускает) или сервис `storybook` корневого `docker-compose.yml` (статика на nginx, http://localhost:6006). В образ `web` и `deploy/compose.yml` не входит.

## Рассмотренные варианты

| Вариант | Почему нет |
|---|---|
| Истории внутри `apps/storybook` | Оторваны от компонента; пакетам пришлось бы экспортировать всё, что показываем |
| Storybook в пакете игры | Свой Storybook на каждый пакет; общий UI (`ui`, `game-ui`) показать негде |
| Vite (`@storybook/react-vite`) | Второй сборщик в репозитории; Rsbuild 2 поддержан `storybook-react-rsbuild` |
| Своя панель управления в истории | Дублирует Controls |
| Выбор тайла из каталога в «Croissant / Tile» | Проверяет только типы каталога; история должна рисовать любую комбинацию элементов |
| Фикстура каталога руками или тестом бэкенда | Руками — тихо расходится с колодой; тест бэкенда писал бы в чужой репозиторий |
| Луга задавать руками | Легко рассогласовать с тропами; вывод из граней совпадает с каталогом |
| Storybook на хосте портала в проде | Витрина нужна только разработке |
| В Docker по `https://storybook.<LOCAL_DOMAIN>` | Новое имя в mkcert и hosts, server-блок только для локального стенда; бэкенд и куки Storybook не нужны |
| Storybook в корневом `pnpm dev` | Витрина нужна не при каждой разработке: лишний процесс и порт |
| Dev-сервер Storybook в Docker | Медленный polling файлов на Windows; для разработки есть `pnpm dev` |

## Последствия

- `storybook-react-rsbuild` поддерживает сообщество (rspack-contrib), а не команда Storybook. Обновления Rsbuild и Storybook сверяются с его peer-зависимостями.
- Фикстура каталога может разойтись с реальной колодой, если её не обновлять вместе с `CroissantCatalog` бэкенда.
