# Линтинг и форматирование фронта

Область: frontend · Код: `frontend/packages/config`

## Контекст

Код пишет в основном ИИ, поэтому стиль и типобезопасность должны проверяться автоматически и строго.

## Решение

- **ESLint 9 (flat)**: база gts (Google TypeScript Style) + `typescript-eslint` `strictTypeChecked` и `stylisticTypeChecked` + react-hooks + query + boundaries (FSD).
- **Prettier** — конфиг gts. **Stylelint** — `stylelint-config-standard` с at-rules Tailwind 4.
- Изменение правил — по согласованию. `eslint-disable` допустим только для строки и с причиной.

## Рассмотренные варианты

| Вариант | Почему нет |
|---|---|
| `eslint-config-google` | Не обновлялся с 2019 года, только JS, без flat config, часть правил удалена из ESLint |
| `stylelint-config-recommended` | Ловит только ошибки, стиль не проверяет |

## Открытые вопросы

- Решить при выходе gts с поддержкой ESLint 10: переход на ESLint 10.
