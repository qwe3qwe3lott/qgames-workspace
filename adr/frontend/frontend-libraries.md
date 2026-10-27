# Библиотеки фронта

Область: frontend · Диаграммы: [c4/3-frontend](../c4/3-frontend.md) · Код: `frontend/pnpm-workspace.yaml` (catalog)

## Контекст

Нужны формы с валидацией по контракту, строгая типизация и минимум runtime-зависимостей при зрелом тулинге.

## Решение

- React 19, TypeScript 6 (строгий конфиг, без `any`, `enum`, `!`), TanStack Query 5 + Router 1, zustand 5 (только клиентский стейт).
- **Формы — react-hook-form + Zod 4** по сгенерированным схемам, сообщения на русском. Zod настроен в режиме `jitless`: CSP без `unsafe-eval`.
- Google-вход — скрипт GIS и `@types/google.accounts`, без обёрток.

## Рассмотренные варианты

| Вариант | Почему нет |
|---|---|
| TanStack Form | Моложе, обёртку под shadcn пришлось бы писать самим |
| TypeScript 7 | Нет поддержки в typescript-eslint и тулинге |

## Последствия

- Данные извне (env, search params, SSE, `localStorage`) проходят Zod-валидацию, а не приводятся через `as`.

## Открытые вопросы

- Решить при поддержке TS 7 в typescript-eslint: переход на TypeScript 7.
