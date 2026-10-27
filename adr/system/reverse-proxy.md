# Reverse proxy и заголовки безопасности

Область: frontend, система · Диаграммы: [c4/2-containers](../c4/2-containers.md), [c4/deployment](../c4/deployment.md) · Код: `frontend/docker/nginx/web.conf.template`, `frontend/docker/app.Dockerfile`

## Контекст

Нужен один процесс, который раздаёт статику двух SPA, проксирует API того же origin (без CORS), держит SSE и ставит заголовки безопасности. Памяти на него — десятки мегабайт.

## Решение

- **nginx** (`nginx-unprivileged`, не от root), один образ `web`: server-блок на каждое приложение. Портал проксирует `/api/` кроме `/api/admin/`, админка — только `/api/admin/`. Конфиг — шаблон с envsubst (`*_LISTEN`, `*_SERVER_NAME`, `API_UPSTREAM`).
- SSE: `proxy_buffering off`, `proxy_read_timeout 60s`, HTTP/1.1.
- Заголовки на всех ответах: `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options` и **CSP** `default-src 'self'` со строгим `script-src`. У портала добавлены Google GIS и `style-src 'unsafe-inline'`, у админки нет ни Google, ни `unsafe-inline`.
- `/static/*` — `immutable`, страницы — `no-cache`. `mem_limit 48m`.
- `PUBLIC_*` вшиваются при сборке из `apps/<app>/.env`.

## Рассмотренные варианты

| Вариант | Почему нет |
|---|---|
| Caddy (статика, прокси, автоматический TLS) | Решение пользователя; на замере под нагрузкой (360 SSE) ~4 ядра CPU и память у самого `GOMEMLIMIT` |
| Строгий `style-src` у портала (без `'unsafe-inline'`) | Ломает кнопку Google (inline-стили GIS) и блокировку прокрутки модалок Radix; nonce style-атрибуты GIS не покрывает |
| Build args для `PUBLIC_*` в compose | Решение пользователя |

## Последствия

- Sonner в админке подключён файлом в `globals.css`, потому что CSP блокирует его `<style>` (ошибки в консоли безвредны).
- Изредка случаются 504 под высокой нагрузкой (BACKLOG «Редкие 504»).

## Открытые вопросы

- Решить при деплое: TLS.
