#!/usr/bin/env bash
# =====================================================================
# pg17.sh — un segundo cluster con Postgres 17.6, la versión de
# producción, al lado del 16 del banco (que sigue en 5432).
#
#   ./pg17.sh            instala (si falta) y arranca en el puerto 5433
#   ./pg17.sh --parar    lo detiene
#
# Después, cualquier script del banco corre contra el 17 con PGPORT:
#   PGPORT=5433 ./correr.sh mi_bd ../../docs/conta/c1-plan-de-cuentas.sql ...
#   PGPORT=5433 ./c3-pegado.sh mi_bd
#
# apt.postgresql.org no está al alcance de la sesión en la nube; los
# binarios salen del paquete de npm @embedded-postgres/linux-x64 (el mismo
# Postgres, compilado; registry.npmjs.org sí está permitido). Se instalan en
# /opt/pg17 y los datos en /var/lib/postgresql/17/bench. Hay que correrlo
# como root (crea archivos del usuario postgres).
# =====================================================================
set -euo pipefail
VERSION="17.6.0-beta.15"            # Postgres 17.6, como producción (23-sep)
BIN=/opt/pg17
DATOS=/var/lib/postgresql/17/bench
LOG=/var/lib/postgresql/17/bench.log

if [ "${1:-}" = "--parar" ]; then
  runuser -u postgres -- "$BIN/bin/pg_ctl" -D "$DATOS" -m fast stop
  exit 0
fi

if [ ! -x "$BIN/bin/postgres" ]; then
  tmp="$(mktemp -d)"
  (cd "$tmp" && npm pack "@embedded-postgres/linux-x64@$VERSION" >/dev/null && tar xzf ./*.tgz)
  rm -rf "$BIN" && cp -a "$tmp/package/native" "$BIN"
  # El paquete trae los enlaces de las bibliotecas en una lista aparte.
  python3 - "$BIN" <<'EOF'
import json, os, sys
base = sys.argv[1]
for l in json.load(open(os.path.join(base, 'pg-symlinks.json'))):
    src = l['source'].replace('native/', base + '/', 1)
    tgt = l['target'].replace('native/', base + '/', 1)
    if os.path.lexists(tgt):
        os.remove(tgt)
    os.symlink(os.path.basename(src), tgt)
EOF
  chown -R postgres:postgres "$BIN"
  rm -rf "$tmp"
fi

if [ ! -f "$DATOS/PG_VERSION" ]; then
  mkdir -p "$(dirname "$DATOS")" && chown postgres:postgres "$(dirname "$DATOS")"
  runuser -u postgres -- "$BIN/bin/initdb" -D "$DATOS" --auth-local=peer --auth-host=scram-sha-256 \
    -E UTF8 --locale=C.UTF-8 -U postgres >/dev/null
  cat >> "$DATOS/postgresql.conf" <<'EOF'
port = 5433
unix_socket_directories = '/var/run/postgresql'
listen_addresses = '127.0.0.1'
EOF
fi

if ! runuser -u postgres -- "$BIN/bin/pg_ctl" -D "$DATOS" status >/dev/null 2>&1; then
  runuser -u postgres -- "$BIN/bin/pg_ctl" -D "$DATOS" -l "$LOG" -w start >/dev/null
fi
runuser -u postgres -- psql -h /var/run/postgresql -p 5433 -Atc "select version()"
