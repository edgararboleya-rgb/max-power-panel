#!/usr/bin/env bash
# repro-m.sh <puerto> <M…> [conservar]: los escenarios M del ataque a EL CONTROL (prueba final de la 4d), DE CERO:
#   1) la carga de §0b sin suites (03-storage-simulacro, c1, c2, c3, c4, c6, 05-puentes-correr) en f4d_rn<v>;
#   2) base-m.sql por pestañas (la apertura de QuickBooks con Chase 50,000 y el préstamo en 2530, su conciliación de apertura
#      confirmada, la débito ····9420, la reserva ····1097 y la cuenta personal ····7781 dadas de alta) en f4d_rm<v>;
#   3) atq.sh con esa base de plantilla para cada escenario (salida en atq/out/<M>_<v>.out);
#   4) borra f4d_rn<v> y f4d_rm<v> (con «conservar», las deja).
# Ej.: ./repro-m.sh 5433 M02 M01 M05
set -uo pipefail
P="$1"; shift; V=$([ "$P" = 5433 ] && echo 17 || echo 16)
CONS=0; ESC=()
for a in "$@"; do if [ "$a" = conservar ]; then CONS=1; else ESC+=("$a"); fi; done
A="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="$A/../../../docs/conta"
su() { runuser -u postgres -- psql -X -q -p "$P" -d postgres "$@"; }
mkdir -p "$A/out"; cd "$A/.." || exit 2
PGPORT=$P ./correr.sh f4d_rn$V 03-storage-simulacro.sql $D/c1-plan-de-cuentas.sql $D/c2-libro.sql $D/c3-puentes.sql \
  $D/c4-estados.sql $D/c6-banco.sql 05-puentes-correr.sql > "$A/out/repro-m_carga_$V.log" 2>&1 || { echo "FALLÓ la carga (out/repro-m_carga_$V.log)"; exit 2; }
su -c "drop database if exists f4d_rm$V with (force)" -c "create database f4d_rm$V template f4d_rn$V" \
   -c "alter database f4d_rm$V owner to editor_sql" -c "alter database f4d_rm$V set search_path = \"\$user\", public, extensions" >/dev/null || exit 2
T=$(mktemp -d); awk -v pre="$T/b_" '/^-- \[Pestaña [0-9]+\]/ { n++ } n { print > (pre n ".sql") }' "$A/base-m.sql"
for n in $(seq 1 "$(ls "$T"/b_*.sql | wc -l)"); do
  PGPASSWORD=editor_sql psql -X -q -At -h 127.0.0.1 -p "$P" -U editor_sql -d f4d_rm$V -v ON_ERROR_STOP=1 -1 -f "$T/b_$n.sql" \
    >> "$A/out/repro-m_base_$V.log" 2>&1 || { echo "FALLÓ base-m.sql pestaña $n (out/repro-m_base_$V.log)"; rm -rf "$T"; exit 2; }
done
rm -rf "$T"
for e in "${ESC[@]}"; do TPL=f4d_rm$V "$A/atq.sh" "$P" "$e"; done
[ "$CONS" = 1 ] || su -c "drop database if exists f4d_rm$V with (force)" -c "drop database if exists f4d_rn$V with (force)" >/dev/null
