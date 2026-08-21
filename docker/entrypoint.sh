#!/usr/bin/env bash
# Entrypoint do Redmine Motriz.
# Monta config/database.yml a partir do ambiente, garante o SECRET_KEY_BASE,
# espera o banco responder, aplica migrações e sobe o servidor.
set -Eeo pipefail

cd "${REDMINE_HOME:-/redmine}"

log() { echo "[entrypoint] $*" >&2; }

# ---------------------------------------------------------------- banco de dados
# Aceita DATABASE_URL (formato que a maioria dos PaaS entrega) ou as variáveis
# discretas REDMINE_DB_*. Sem nenhuma das duas, cai para SQLite — serve para
# subir e olhar, não para produção.
montar_database_yml() {
  local adapter host port user pass name enc url=""

  if [ -n "${DATABASE_URL:-}" ]; then
    url="$DATABASE_URL"
    case "$url" in
      postgres://*|postgresql://*) adapter='postgresql' ;;
      mysql2://*|mysql://*)        adapter='mysql2' ;;
      sqlite3://*)                 adapter='sqlite3' ;;
      *) log "ERRO: não reconheço o esquema de DATABASE_URL: ${url%%:*}"; exit 1 ;;
    esac
    log "usando DATABASE_URL (adaptador: $adapter)"
  elif [ -n "${REDMINE_DB_POSTGRES:-}" ]; then
    adapter='postgresql'; host="$REDMINE_DB_POSTGRES"
    port="${REDMINE_DB_PORT:-5432}"; user="${REDMINE_DB_USERNAME:-postgres}"
    pass="${REDMINE_DB_PASSWORD:-}"; name="${REDMINE_DB_DATABASE:-redmine}"
    enc="${REDMINE_DB_ENCODING:-utf8}"
  elif [ -n "${REDMINE_DB_MYSQL:-}" ]; then
    adapter='mysql2'; host="$REDMINE_DB_MYSQL"
    port="${REDMINE_DB_PORT:-3306}"; user="${REDMINE_DB_USERNAME:-root}"
    pass="${REDMINE_DB_PASSWORD:-}"; name="${REDMINE_DB_DATABASE:-redmine}"
    enc="${REDMINE_DB_ENCODING:-utf8mb4}"
  else
    log "AVISO: nenhum banco configurado (DATABASE_URL ou REDMINE_DB_POSTGRES/MYSQL)."
    log "AVISO: caindo para SQLite em sqlite/redmine.db — não use assim em produção."
    adapter='sqlite3'; name='sqlite/redmine.db'; enc='utf8'
    mkdir -p sqlite
  fi

  {
    echo "# Gerado pelo entrypoint a cada boot. Não editar dentro do container."
    echo "production:"
    echo "  adapter: $adapter"
    if [ -n "$url" ]; then
      echo "  url: \"$url\""
    else
      [ -n "${host:-}" ] && echo "  host: \"$host\""
      [ -n "${port:-}" ] && echo "  port: $port"
      [ -n "${user:-}" ] && echo "  username: \"$user\""
      [ -n "${pass:-}" ] && echo "  password: \"$pass\""
      [ -n "${name:-}" ] && echo "  database: \"$name\""
      [ -n "${enc:-}"  ] && echo "  encoding: \"$enc\""
    fi
    echo "  pool: ${REDMINE_DB_POOL:-10}"
    # O Gemfile do Redmine varre este arquivo atrás de `adapter:` para decidir
    # quais gems carregar. As três declarações abaixo mantêm a lista idêntica à
    # do build — sem elas o bundler acusa Gemfile alterado a cada `bundle exec`.
    echo "_adapter_postgresql:"
    echo "  adapter: postgresql"
    echo "_adapter_mysql2:"
    echo "  adapter: mysql2"
    echo "_adapter_sqlite3:"
    echo "  adapter: sqlite3"
  } > config/database.yml
}

# ------------------------------------------------------------------ chave secreta
configurar_secret() {
  if [ -n "${SECRET_KEY_BASE:-}" ]; then
    export SECRET_KEY_BASE
    return
  fi
  unset SECRET_KEY_BASE
  if [ ! -f config/initializers/secret_token.rb ]; then
    log "AVISO: SECRET_KEY_BASE não definido — gerando um token local."
    log "AVISO: defina SECRET_KEY_BASE no painel, senão toda sessão cai a cada redeploy."
    bundle exec rake generate_secret_token
  fi
}

# -------------------------------------------------------------- espera do banco
esperar_banco() {
  local tentativas="${REDMINE_DB_WAIT_RETRIES:-30}" i=1
  while [ "$i" -le "$tentativas" ]; do
    if bundle exec rake db:version >/dev/null 2>&1; then
      log "banco respondeu (tentativa $i)"; return 0
    fi
    log "aguardando o banco... ($i/$tentativas)"
    sleep 2; i=$((i+1))
  done
  log "ERRO: o banco não respondeu depois de $tentativas tentativas."
  bundle exec rake db:version || true
  return 1
}

ajustar_permissoes() {
  [ "$(id -u)" = '0' ] || return 0
  mkdir -p files log tmp/pids tmp/cache tmp/sessions public/assets public/plugin_assets
  chown -R redmine:redmine files log tmp public/assets public/plugin_assets config sqlite 2>/dev/null || true
}

# ------------------------------------------------------------------------- boot
primeiro_argumento="${1:-}"
if [ "$primeiro_argumento" = 'bundle' ] || [ "$primeiro_argumento" = 'rake' ] || [ "$primeiro_argumento" = 'rails' ]; then
  ajustar_permissoes
  if [ "$(id -u)" = '0' ]; then
    exec gosu redmine "$0" "$@"
  fi

  montar_database_yml
  configurar_secret

  if [ -z "${REDMINE_NO_DB_MIGRATE:-}" ]; then
    esperar_banco
    log "aplicando migrações"
    bundle exec rake db:migrate
    if [ -n "${REDMINE_PLUGINS_MIGRATE:-}" ]; then
      log "aplicando migrações de plugins"
      bundle exec rake redmine:plugins:migrate
    fi
  fi

  if [ -n "${REDMINE_DEFAULT_DATA:-}" ]; then
    log "carregando dados padrão (idioma: ${REDMINE_LANG:-en})"
    REDMINE_LANG="${REDMINE_LANG:-en}" bundle exec rake redmine:load_default_data || true
  fi

  rm -f tmp/pids/server.pid
  log "subindo: $*"
fi

exec "$@"
