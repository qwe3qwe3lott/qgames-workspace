# Reverse proxy, TLS и заголовки безопасности

Область: frontend, система · Диаграммы: [c4/2-containers](../c4/2-containers.md), [c4/deployment](../c4/deployment.md) · Код: `frontend/docker/nginx/web.conf.template`, `frontend/docker/app.Dockerfile`, `frontend/packages/config/local-https`

## Контекст

Нужен один процесс, который раздаёт статику двух SPA, проксирует API того же origin (без CORS), держит SSE, завершает TLS и ставит заголовки безопасности. Памяти на него — десятки мегабайт. Куки, same-site и CSRF-модель ([session-tokens](../security/session-tokens.md)) должны локально работать так же, как в проде.

## Решение

- **nginx** (`nginx-unprivileged`, не от root), один образ `web`: server-блок на каждое приложение. Портал проксирует `/api/` кроме `/api/admin/`, админка — только `/api/admin/`. Конфиг — шаблон с envsubst (`HTTPS_LISTEN`, `HTTP_LISTEN`, `*_SERVER_NAME`, `API_UPSTREAM`, `API_UPSTREAM_RESOLVE`, `HSTS`). `worker_connections 4096` (SSE-поток — два соединения воркера).
- **Upstream в проде** — `server app:8080 resolve` с `resolver 127.0.0.11 valid=10s ipv4=on`: пересоздание app меняет его IP без 502, web стартует и без app. Локально — один IPv4-адрес `host.docker.internal` (его знает только `/etc/hosts`, не DNS Docker; по IPv6 подключение падает).
- **TLS в nginx:** оба сайта на одном HTTPS-порту, различаются `server_name`. Один сертификат на оба имени — том `/etc/nginx/certs` (`cert.pem`, `key.pem`), в образ не входит. В проде — Let's Encrypt (certbot на хосте, HTTP-01 через webroot `/var/www/acme` на :80, [server-hardening](../security/server-hardening.md)). `http2 on` к браузеру: потоки SSE не упираются в лимит 6 соединений HTTP/1.1 на хост. Чужое имя — `ssl_reject_handshake`. HTTP — только редирект на HTTPS, `/healthz` и ACME.
- **HSTS** только в проде, `max-age=86400` (увеличить, когда прод устоится), без `includeSubDomains`: `local.qgames.duckdns.org` — поддомен прода.
- **Локально — как в проде:** портал `<LOCAL_DOMAIN>`, админка `admin.<LOCAL_DOMAIN>` (`.env` фронта, по умолчанию `local.qgames.duckdns.org`, имена в `hosts`), сертификат mkcert. `pnpm dev` — HTTPS в dev-сервере Rsbuild на тех же именах с портами :3000/:3001 (куки от порта не зависят). `http://localhost` для фронта не используется.
- SSE: `proxy_buffering off`, `proxy_read_timeout 60s`, HTTP/1.1 до app.
- Заголовки на всех ответах: `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options` и **CSP** `default-src 'self'` со строгим `script-src`. У портала добавлены Google GIS и `style-src 'unsafe-inline'`, у админки нет ни Google, ни `unsafe-inline`.
- `/static/*` — `immutable`, страницы — `no-cache`. `mem_limit 48m`.
- `PUBLIC_*` вшиваются при сборке из `apps/<app>/.env`.

## Рассмотренные варианты

| Вариант | Почему нет |
|---|---|
| Caddy (статика, прокси, автоматический TLS) | Решение пользователя; на замере под нагрузкой (360 SSE) ~4 ядра CPU и память у самого `GOMEMLIMIT` |
| Строгий `style-src` у портала (без `'unsafe-inline'`) | Ломает кнопку Google (inline-стили GIS) и блокировку прокрутки модалок Radix; nonce style-атрибуты GIS не покрывает |
| Build args для `PUBLIC_*` в compose | Решение пользователя |
| Локально `http://localhost:3000/3001` | Secure-куки работают только из-за особого статуса localhost, сайты различаются портом, а не хостом: same-site и прокси не как в проде |
| Локальный домен `.local`, `.test`, `.localhost` | Google OAuth не принимает origin без публичного суффикса — вход через Google локально невозможен |
| nginx-шлюз на 443 перед dev-серверами | Лишний контейнер и конфиг (HMR-websocket); HTTPS в Rsbuild с портами достаточно — решение пользователя |
| `proxy_pass` через переменную вместо `resolve` в upstream | Теряется keep-alive upstream и меняется обработка URI; `resolve` есть в nginx ≥ 1.27.3 |
| HSTS с `includeSubDomains` | Задел бы локальный стенд на поддомене прода |

## Последствия

- Sonner в админке подключён файлом в `globals.css`, потому что CSP блокирует его `<style>` (ошибки в консоли безвредны).
- Изредка случаются 504 под высокой нагрузкой (BACKLOG «Редкие 504»).
- Локальная настройка — разовая: mkcert, записи в `hosts`, свободные порты 80 и 443 (README фронтенда).
- Бюджет памяти nginx (`mem_limit 48m`) замерялся без TLS и HTTP/2. С ними в простое ~13 MiB, под нагрузкой не перемерялся: принято, что пик заметно не меняется (решение пользователя).
