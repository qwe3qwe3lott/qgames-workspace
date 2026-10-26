# qgames-workspace

Рабочее место Claude Code для фич qgames, которые затрагивают бэкенд и фронтенд. Основная сессия (фулстек) задаёт вопросы пользователю и реализует обе стороны, агент `reviewer` проверяет. Подробности — в [CLAUDE.md](CLAUDE.md).

## Раскладка

Три репозитория клонируются рядом, в одну папку, с этими именами — пути в настройках относительные:

```
<любая папка>/
  qgames-workspace/
  qgames-backend-monorepo/
  qgames-frontend-monorepo/
```

```bash
git clone https://github.com/qwe3qwe3lott/qgames-workspace.git
git clone https://github.com/qwe3qwe3lott/qgames-backend-monorepo.git
git clone https://github.com/qwe3qwe3lott/qgames-frontend-monorepo.git
```

## Запуск

```bash
cd qgames-workspace
claude
> <описание задачи>
```

Коммиты в репозиториях Claude не делает — коммитит разработчик.
