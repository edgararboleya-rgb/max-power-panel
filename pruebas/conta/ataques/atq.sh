#!/usr/bin/env bash
# atq.sh <puerto> <escenario> [conservar]: crea f4d_atq_<esc>_<v> desde la plantilla atq_t<v>n (la hace tpl.sh; otra con TPL=), corre <esc>-montaje.sql por pestañas (cada una en
# su transacción, como el SQL Editor) y después <esc>-mirar.sql con harness.sql y auditor.sql delante (sin parar en los errores),
# y al final el auditor (EL CRITERIO sobre lo guardado). Salida en atq/out/<esc>_<v>.out.
P="$1"; E="$2"; V=$([ "$P" = 5433 ] && echo 17 || echo 16)
A="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BD="f4d_atq_$(echo $E | tr 'A-Z-' 'a-z_')_$V"; TPL="${TPL:-atq_t${V}n}"
mkdir -p "$A/out" "$A/tabs"
su() { runuser -u postgres -- psql -X -q -p "$P" -d postgres "$@"; }
su -c "drop database if exists $BD with (force)" >/dev/null 2>&1
for i in 1 2 3 4 5; do su -c "create database $BD template $TPL" 2>/dev/null && break; sleep 1; done
su -c "alter database $BD owner to editor_sql" -c "alter database $BD set search_path = \"\$user\", public, extensions" >/dev/null
ed() { PGPASSWORD=editor_sql psql -X -h 127.0.0.1 -p "$P" -U editor_sql -d "$BD" "$@"; }
{
  rm -f "$A/tabs/${E}_${V}_"*
  awk -v pre="$A/tabs/${E}_${V}_" '/^-- \[Pestaña [0-9]+\]/ { n++ } n { print > (pre n ".sql") }' "$A/$E-montaje.sql"
  nt=$(ls "$A/tabs/${E}_${V}_"*.sql 2>/dev/null | wc -l)
  for n in $(seq 1 $nt); do t="$A/tabs/${E}_${V}_$n.sql"
    echo "=== $(head -1 "$t")"
    ed -v ON_ERROR_STOP=1 -1 -f "$t" 2>&1
    echo "=== (rc=$?)"
  done
  if [ -f "$A/$E-mirar.sql" ]; then
    echo "=== mirar"
    ed -v ON_ERROR_STOP=0 -f "$A/harness.sql" -f "$A/auditor.sql" -f "$A/$E-mirar.sql" 2>&1
  fi
  echo "=== auditor (lo guardado al final)"
  ed -v ON_ERROR_STOP=0 -f "$A/auditor.sql" -c '\pset pager off' -c 'select * from pg_temp.atq_auditar()' -c 'select * from pg_temp.atq_patrimonio()' \
     -c "select orden, vista, left(detalle, 200) as detalle from fn_banco_control(to_char((select max(fecha) from movimientos_banco), 'YYYY-MM')) where not ok" \
     -c "select 'REF' as k, cuenta, fecha, monto, descripcion, clase, regla, left(contradice, 400) from fn_banco_criterio_casados() order by cuenta, fecha" \
     -c "select 'C59' as k, filas, ok, left(detalle, 2500) from fn_banco_control('hoy', array['cuadre: el otro lado de cada casado'])" \
     -c "select 'VER' as k, control, ok, left(detalle::text, 600) from fn_banco_verificar() where control ~ 'otro lado' or not ok" 2>&1
} > "$A/out/${E}_${V}.out" 2>&1
[ "${3:-}" = "conservar" ] || su -c "drop database if exists $BD with (force)" >/dev/null 2>&1
echo "$E PG$V listo"
