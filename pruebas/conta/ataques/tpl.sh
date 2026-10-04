#!/usr/bin/env bash
# tpl.sh <puerto>: la plantilla atq_t<v>n que usa atq.sh (la carga de §0b del README sin suites:
# 03-storage-simulacro, c1, c2, c3, c4, c6 y 05-puentes-correr, con los archivos de docs/conta de hoy).
P="$1"; V=$([ "$P" = 5433 ] && echo 17 || echo 16)
A="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="$A/../../../docs/conta"
mkdir -p "$A/out"
cd "$A/.." || exit 2
PGPORT=$P ./correr.sh atq_t${V}n 03-storage-simulacro.sql $D/c1-plan-de-cuentas.sql $D/c2-libro.sql $D/c3-puentes.sql $D/c4-estados.sql \
  $D/c6-banco.sql 05-puentes-correr.sql > "$A/out/tpl${V}n.log" 2>&1; echo "plantilla atq_t${V}n rc=$?"
