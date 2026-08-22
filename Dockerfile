# syntax=docker/dockerfile:1
#
# Redmine 7.0.0 + tema Motriz Digital.
# Construído a partir da árvore versionada em redmine-7/, não da imagem oficial,
# para que qualquer customização futura (plugins, patches) entre no build.
#
# Contexto de build: a RAIZ do repositório.
# Porta: 3000.

FROM ruby:3.4-slim-bookworm

ENV RAILS_ENV=production \
    RACK_ENV=production \
    RAILS_SERVE_STATIC_FILES=1 \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_BUILD__NOKOGIRI="--use-system-libraries" \
    REDMINE_HOME=/redmine \
    LANG=C.UTF-8 \
    TZ=America/Sao_Paulo

# Dependências de execução. A lista espelha a da imagem oficial do Redmine:
# imagemagick e ghostscript para miniaturas, git/subversion/mercurial para os
# navegadores de repositório, e as libs cliente dos três bancos suportados.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates tzdata gosu curl \
      imagemagick ghostscript fonts-urw-base35 \
      git subversion mercurial \
      libpq5 libmariadb3 libsqlite3-0 \
      libxml2 libxslt1.1 libyaml-0-2 zlib1g; \
    rm -rf /var/lib/apt/lists/*; \
    gosu nobody true

RUN groupadd -r redmine && useradd -r -g redmine -d "$REDMINE_HOME" redmine

WORKDIR $REDMINE_HOME

# ORDEM DAS CAMADAS: só o Gemfile primeiro, depois `bundle install`, e só então o
# resto da aplicação. Copiar a árvore inteira antes fazia qualquer mudança no
# tema invalidar o cache do bundle e custar ~12 min de recompilação de gems
# nativas. Assim, mexer no CSS reconstrói em segundos.
COPY redmine-7/Gemfile $REDMINE_HOME/Gemfile

# Nota para quem for adicionar plugin com Gemfile próprio: o Gemfile do Redmine
# faz `Dir.glob plugins/*/{Gemfile,PluginGemfile}` (linha 133) e avalia o que
# encontrar. Como o `bundle install` acontece ANTES do COPY da árvore, o glob não
# enxerga plugin nenhum no build; se a árvore copiada depois trouxer um Gemfile de
# plugin, todo `bundle exec` passa a morrer com gem faltando. As saídas são
# declarar as gems no Gemfile.local abaixo, ou copiar o Gemfile do plugin para cá
# antes desta camada.
COPY redmine-7/plugins/motriz_2/Gemfile $REDMINE_HOME/plugins/motriz_2/Gemfile
COPY plugins/redmine_google_sso/Gemfile $REDMINE_HOME/plugins/redmine_google_sso/Gemfile
COPY plugins/redmine_mcp_server/Gemfile $REDMINE_HOME/plugins/redmine_mcp_server/Gemfile

# O Gemfile do Redmine LÊ config/database.yml para decidir quais gems de banco
# instalar (linha 54 do Gemfile). Sem este arquivo, nenhum adaptador é instalado.
# Declaramos os três para que a escolha do banco seja feita em runtime, sem
# rebuild — e o entrypoint mantém essas mesmas três declarações no arquivo final,
# senão o bundler acusa "Gemfile changed" a cada `bundle exec`.
RUN mkdir -p config && printf '%s\n' \
      'production:'        '  adapter: postgresql' \
      '_adapter_mysql2:'   '  adapter: mysql2' \
      '_adapter_sqlite3:'  '  adapter: sqlite3' \
      > config/database.yml

# O Redmine só declara `gem 'puma'` dentro de `group :test`, e este build usa
# BUNDLE_WITHOUT="development:test" — sem isto o container sobe sem servidor web
# e morre com "bundler: command not found: puma".
# Gemfile.local é o ponto de extensão previsto pelo próprio Gemfile (eval_gemfile),
# então o Puma entra por ali em vez de alterar o Gemfile do upstream.
# Sem restrição de versão de propósito: o bundler recusa a mesma gem declarada
# duas vezes com requisitos diferentes, e o `group :test` já a declara solta.
RUN printf "%s\n" "gem 'puma'" > Gemfile.local

RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      build-essential pkg-config \
      libpq-dev libmariadb-dev libsqlite3-dev \
      libxml2-dev libxslt1-dev zlib1g-dev libyaml-dev; \
    bundle install --jobs "$(nproc)" --retry 3; \
    \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark > /dev/null; \
    find /usr/local/bundle -type f -name '*.so' -exec sh -c 'ldd "$1" 2>/dev/null | awk "/=> \//{print \$3}"' _ {} \; \
      | sort -u | xargs -r dpkg-query -S 2>/dev/null | cut -d: -f1 | sort -u \
      | xargs -r apt-mark manual > /dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/* /usr/local/bundle/cache/*.gem

# Agora sim o resto da aplicação. Nem config/database.yml nem Gemfile.local
# existem em redmine-7/ (ambos são gitignored pelo Redmine), então esta cópia
# não sobrescreve o que foi gerado acima.
COPY redmine-7/ $REDMINE_HOME/

# O plugin de SSO vive fora de redmine-7/ para não se misturar com a árvore do
# upstream.
COPY plugins/redmine_google_sso/ $REDMINE_HOME/plugins/redmine_google_sso/
COPY plugins/redmine_mcp_server/ $REDMINE_HOME/plugins/redmine_mcp_server/

# O middleware OmniAuth precisa entrar em tempo de config, e o único gancho para
# isso é config/additional_environment.rb. Ele vem versionado dentro do plugin
# porque o .gitignore do próprio Redmine ignora esse caminho em config/ — deixá-lo
# lá significaria perdê-lo num clone limpo, e o SSO falharia em silêncio.
# Sobrescreve qualquer additional_environment.rb do upstream: hoje só existe o
# .example. Se um dia houver outras configurações locais, junte-as neste arquivo.
COPY plugins/redmine_google_sso/config/additional_environment.rb $REDMINE_HOME/config/additional_environment.rb

# Envio de e-mail. O arquivo não guarda segredo: o Redmine passa configuration.yml
# por ERB, então tudo vem do ambiente. Fica em docker/ porque o .gitignore do
# próprio Redmine ignora config/configuration.yml — versionar lá seria perdê-lo
# num clone limpo, e o envio falharia em silêncio.
COPY docker/configuration.yml $REDMINE_HOME/config/configuration.yml

# Diretórios que o Redmine escreve em runtime.
# public/assets é populado no boot: production.rb traz
# `config.assets.redmine_detect_update = true`, então o Propshaft recompila
# sozinho quando detecta mudança — inclusive nos assets do tema.
RUN set -eux; \
    mkdir -p files log tmp/pids tmp/cache tmp/sessions public/assets public/plugin_assets sqlite; \
    chown -R redmine:redmine "$REDMINE_HOME"

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/redmine/files"]
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD curl -fsS http://127.0.0.1:3000/login > /dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:3000"]
