# qgames-workspace

Рабочее место оркестратора Claude Code: одна фича делается сразу в бэкенде и фронтенде qgames. Оркестратор (основная сессия) пишет спецификацию и задаёт вопросы пользователю, агенты `backend-dev` и `frontend-dev` реализуют, `reviewer` проверяет. Подробности — в [CLAUDE.md](CLAUDE.md).

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
> /agents                       # backend-dev, frontend-dev, reviewer
> /feature <описание фичи>
```

Коммиты в репозиториях агенты не делают — коммитит разработчик.
