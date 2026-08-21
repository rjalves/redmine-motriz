#!/usr/bin/env bash
# Sobe o Redmine 7.0.0 oficial com o tema Motriz montado, popula dados de demonstração
# e deixa em http://localhost:3001 (admin / motriz123456).
# O Ruby do sistema é 2.6 e o Redmine 7 exige >= 3.2 — por isso container, não host.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"

docker rm -f redmine-motriz >/dev/null 2>&1 || true
docker run -d --name redmine-motriz -p 3001:3000 \
  -v "$RAIZ/redmine-7/themes/motriz:/usr/src/redmine/themes/motriz:ro" \
  redmine:7.0.0 >/dev/null

echo "aguardando boot..."
until curl -sf -o /dev/null http://localhost:3001/; do sleep 2; done

docker exec -e REDMINE_LANG=pt-BR redmine-motriz bundle exec rake redmine:load_default_data >/dev/null
docker cp "$RAIZ/tools/dev/seed-demo.rb" redmine-motriz:/tmp/seed.rb >/dev/null
docker exec redmine-motriz bundle exec rails runner -e production /tmp/seed.rb 2>&1 | tail -3
docker exec redmine-motriz bundle exec rails runner -e production \
  "u=User.find_by_login('admin'); u.password='motriz123456'; u.password_confirmation='motriz123456'; u.must_change_passwd=false; u.save!" >/dev/null

echo
echo "pronto: http://localhost:3001   (admin / motriz123456)"
echo "depois de editar o CSS do tema:  docker restart redmine-motriz"
echo "para derrubar:                   docker rm -f redmine-motriz"
