#!/usr/bin/env bash
# Prepara o banco de teste e roda a suíte do plugin redmine_google_sso.
# Usado como CMD da imagem docker/Dockerfile.test.
set -Eeo pipefail

cd "${REDMINE_HOME:-/redmine}"
export RAILS_ENV=test

log() { echo "[testes] $*" >&2; }

PLUGIN="${PLUGIN:-redmine_google_sso}"

log "preparando o banco de teste"
rm -f db/test.sqlite3
bundle exec rake db:create db:migrate > /tmp/migrate.log 2>&1 || { cat /tmp/migrate.log; exit 1; }
bundle exec rake redmine:plugins:migrate > /tmp/plugin-migrate.log 2>&1 || { cat /tmp/plugin-migrate.log; exit 1; }
log "banco pronto"

# Sem NAME, as tasks rodariam os testes de todos os plugins.
if [ "$#" -gt 0 ]; then
  exec bundle exec rake "$@" NAME="$PLUGIN"
fi

log "rodando unit + functional de $PLUGIN"
bundle exec rake redmine:plugins:test NAME="$PLUGIN"
