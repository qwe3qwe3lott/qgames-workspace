#!/bin/sh
# Выкатка одной стороны qgames на VPS: /opt/qgames/bin/deploy.sh <backend|frontend> <sha коммита>.
# Вызывается только через SSH-ключ пользователя deploy (forced command в authorized_keys): аргументы приходят
# в SSH_ORIGINAL_COMMAND. Скачивает deploy/compose.yml репозитория на этом коммите (репозитории публичные),
# ставит образ :<sha> и ждёт healthcheck. Не поднялось — возвращает прежние compose и тег.
set -eu

# shellcheck disable=SC2086 # аргументы разделяются пробелами намеренно
set -- ${SSH_ORIGINAL_COMMAND:-$*}
[ $# -eq 2 ] || { echo "usage: deploy.sh <backend|frontend> <sha>" >&2; exit 2; }
side=$1
sha=$2
case "$side" in
    backend) repo=qgames-backend-monorepo ;;
    frontend) repo=qgames-frontend-monorepo ;;
    *) echo "unknown side: $side" >&2; exit 2 ;;
esac
echo "$sha" | grep -Eq '^[0-9a-f]{40}$' || { echo "bad sha: $sha" >&2; exit 2; }

dir=/opt/qgames/$side
project=qgames-$side

# Деплои бэкенда и фронта не идут одновременно.
exec 9>/opt/qgames/deploy.lock
flock 9

cd "$dir"
curl -fsSL --retry 3 "https://raw.githubusercontent.com/qwe3qwe3lott/$repo/$sha/deploy/compose.yml" -o compose.yml.new
cp -p compose.yml compose.yml.prev 2>/dev/null || true
cp -p .env .env.prev
{ grep -v '^IMAGE_TAG=' .env.prev || true; echo "IMAGE_TAG=$sha"; } > .env.new
chmod 600 .env.new
mv compose.yml.new compose.yml
mv .env.new .env

compose() { docker compose -p "$project" -f compose.yml "$@"; }

if compose pull && compose up -d --wait --remove-orphans; then
    echo "deployed $side $sha"
    # Диск 7 ГБ: образы, не используемые контейнерами, удаляются.
    docker image prune -af >/dev/null || true
    exit 0
fi

echo "deploy $side $sha failed, rolling back" >&2
compose logs --tail 100 >&2 || true
if [ -f compose.yml.prev ] && grep -q '^IMAGE_TAG=' .env.prev; then
    mv compose.yml.prev compose.yml
    mv .env.prev .env
    compose up -d --wait --remove-orphans || echo "rollback failed" >&2
fi
exit 1
