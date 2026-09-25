#!/usr/bin/env bash
# =====================================================================
# c4-concurrencia.sh — lo que c4-pruebas.sql no puede probar: dos
# sesiones A LA VEZ con la apertura. c4-pruebas corre en una sola sesión
# (su prueba 60 solo ve que la carga de la balanza y fn_apertura toman el
# mismo candado); aquí se abren dos de verdad, y cada una confirma.
#
#   ./c4-concurrencia.sh [nombre_bd]      (por defecto c4_concurrencia)
#
# Crea su base con c1 + c2 + c3 + c4, mapea las cuentas de QuickBooks de
# sus balanzas, y:
#   1. Una carga de la balanza está en curso (todavía sin confirmar) y
#      Edgar postea la apertura con ella: fn_apertura espera a que la carga
#      confirme y postea lo cargado. El asiento es su papel.
#   2. LA CARRERA: Edgar postea la apertura con otra balanza (la sustituye,
#      con su motivo) y, mientras se postea, otra sesión vuelve a cargar esa
#      balanza con otras cifras. La carga espera a que la apertura confirme
#      (el candado 820260930) y entonces su guarda la para (MX003: esa
#      balanza ya es el papel de un asiento). El asiento y su papel dicen lo
#      mismo (su huella), y el control de las protecciones sigue en verde.
#      (Antes, la carga borraba y reponía la balanza mientras se posteaba:
#      el asiento quedaba con unas cifras y su papel con otras.)
#   3. Dos fn_apertura a la vez con la misma balanza nueva: la segunda
#      espera a la primera y la ve (sin_cambios): una sola apertura viva.
# Y comprueba: fn_verificar_cadena en true, una sola apertura viva, y la
# comparación de la apertura contra su balanza sin nada sin explicar.
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c4_concurrencia}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

cat > "$TMP/mapeo.sql" <<'SQL'
-- El mapeo de las cuentas de QuickBooks de las balanzas de este script.
do $$
begin
  perform fn_apertura_mapeo_qb('Chase Chk 4392', '1010');
  perform fn_apertura_mapeo_qb('Opening Balance Equity', '3900');
end $$;
SQL

echo "== Base $BD: c1 + c2 + c3 + c4 y el mapeo"
"$DIR/correr.sh" "$BD" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" "$DOCS/c4-estados.sql" \
  "$TMP/mapeo.sql" > "$TMP/carga.out" 2>&1 || { cat "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

AP="$(ed -c "select periodo || '|' || desde from periodos where tipo = 'apertura' order by desde limit 1")"
PER="${AP%%|*}"; FECHA="${AP#*|}"
[ -n "$PER" ] || { echo "No hay período de apertura en el calendario" >&2; exit 2; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}
balanza() {  # balanza <documento> <monto>: las filas de una balanza que cuadra, con su control de QuickBooks
  echo "[{\"cuenta_qb\": \"Chase Chk 4392\", \"debe\": \"$2\"}, {\"cuenta_qb\": \"Opening Balance Equity\", \"haber\": \"$2\"}," \
       "{\"cuenta_qb\": \"Net Income\", \"debe\": \"0.00\"}, {\"cuenta_qb\": \"TOTAL ASSETS\", \"debe\": \"$2\"}]"
}
viva() {  # el 1010 de la apertura viva y su documento
  ed -c "select coalesce(string_agg(format('%s:%s', a.documento_ruta, l.monto), ','), '-')
           from asientos a join asiento_lineas l on l.asiento_id = a.id and l.cuenta = '1010'
          where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
            and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')"
}
protecciones() {
  ed -c "select case when ok then 't' else 'f: ' || detalle end from fn_estados_control('$PER', array['v_cortes'])
          where vista = 'cuadre: protecciones de c4'"
}

echo "== 1. Una carga en curso y la apertura con ella: fn_apertura espera y postea lo cargado"
ed -c "begin; select fn_apertura_balanza_cargar('docs/apertura/c4c-1.csv', '$(balanza x 25000.00)'); select pg_sleep(3); commit;" \
  > "$TMP/1a.out" 2>&1 &
sleep 0.7
inicio=$(date +%s.%N)
ed -c "select fn_apertura('$FECHA', 'docs/apertura/c4c-1.csv')->>'accion'" > "$TMP/1b.out" 2>&1
fin=$(date +%s.%N)
wait
revisa "la apertura esperó a la carga" "t" "$(python3 -c "print('t' if $fin - $inicio > 1.5 else 'f')")"
revisa "posteó lo cargado" "posteada" "$(tail -n 1 "$TMP/1b.out")"
revisa "la apertura viva es la de la balanza, con sus cifras" "docs/apertura/c4c-1.csv:25000.00" "$(viva)"

echo "== 2. La carrera: una recarga de la balanza mientras la apertura la postea"
ed -c "select fn_apertura_balanza_cargar('docs/apertura/c4c-2.csv', '$(balanza x 30000.00)') is not null" > /dev/null 2>&1
ed -c "begin; select fn_apertura('$FECHA', 'docs/apertura/c4c-2.csv', 'c4-concurrencia: QuickBooks corrigió el banco')->>'accion';
       select pg_sleep(3); commit;" > "$TMP/2a.out" 2>&1 &
sleep 0.7
ed -c "select fn_apertura_balanza_cargar('docs/apertura/c4c-2.csv', '$(balanza x 99999.00)') is not null" > "$TMP/2b.out" 2>&1
wait
revisa "la apertura sustituyó a la anterior" "sustituida" "$(grep -E '^[a-z_]+$' "$TMP/2a.out" | head -n 1)"
revisa "la recarga esperó y su guarda la paró (MX003)" "MX003" "$(grep -o 'MX003' "$TMP/2b.out" | head -n 1)"
revisa "la balanza sigue siendo la que se posteó" "30000.00" \
  "$(ed -c "select sum(debe) from apertura_balanza_qb where documento = 'docs/apertura/c4c-2.csv' and control is null")"
revisa "el asiento y su papel dicen lo mismo" "docs/apertura/c4c-2.csv:30000.00" "$(viva)"
revisa "el control de las protecciones (la huella del papel) en verde" "t" "$(protecciones)"

echo "== 3. Dos fn_apertura a la vez con la misma balanza nueva"
ed -c "select fn_apertura_balanza_cargar('docs/apertura/c4c-3.csv', '$(balanza x 31000.00)') is not null" > /dev/null 2>&1
ed -c "begin; select fn_apertura('$FECHA', 'docs/apertura/c4c-3.csv', 'c4-concurrencia: la de hoy')->>'accion'; select pg_sleep(2); commit;" \
  > "$TMP/3a.out" 2>&1 &
sleep 0.5
ed -c "select fn_apertura('$FECHA', 'docs/apertura/c4c-3.csv', 'c4-concurrencia: la de hoy')->>'accion'" > "$TMP/3b.out" 2>&1
wait
revisa "la primera la sustituyó y la segunda la vio (sin cambios)" "sustituida/sin_cambios" \
  "$(grep -E '^[a-z_]+$' "$TMP/3a.out" | head -n 1)/$(tail -n 1 "$TMP/3b.out")"
revisa "una sola apertura viva, con la balanza nueva" "docs/apertura/c4c-3.csv:31000.00" "$(viva)"

if grep -i error "$TMP"/1a.out "$TMP"/1b.out "$TMP"/2a.out "$TMP"/3a.out "$TMP"/3b.out; then
  echo "FALLA: una sesión dio error (arriba)"
  malos=1
fi
revisa "la comparación de la apertura, sin nada sin explicar" "t" \
  "$(ed -c "select case when bool_and(ok) then 't' else 'f' end from v_comparacion where periodo = '$PER'")"
revisa "el libro sigue sano (fn_verificar_cadena)" "ninguno" \
  "$(ed -c "select coalesce(string_agg(control, ', '), 'ninguno') from fn_verificar_cadena() where not ok")"

[ $malos -eq 0 ] && echo "CONCURRENCIA c4 ok" || echo "CONCURRENCIA c4 FALLA"
exit $malos
