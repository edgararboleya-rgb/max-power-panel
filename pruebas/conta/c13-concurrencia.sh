#!/usr/bin/env bash
# =====================================================================
# c13-concurrencia.sh — lo que c13-pruebas.sql no puede probar: dos
# sesiones A LA VEZ con la cédula de corte. c13-pruebas corre en una sola
# sesión; aquí se abren varias de verdad, y cada una confirma.
#
#   ./c13-concurrencia.sh [nombre_bd]      (por defecto c13_concurrencia)
#
# Crea su base con c1 + c2 + c3 + c13 (la cédula no necesita más), un banco
# con saldo y un renglón a mano que no lo cubre, y:
#   1. EXPLICAR LA MISMA CUENTA Y FECHA desde dos pestañas a la vez (con
#      textos distintos): entran las dos, una detrás de otra (el candado de
#      esa cuenta y esa fecha); queda UNA explicación viva —la última en
#      entrar, que nombra a la que sustituye— y la otra como rastro.
#   2. CORREGIR EL MISMO RENGLÓN desde dos pestañas a la vez: una entra (su
#      versión nueva); la otra, MX008 (ese renglón ya se corrigió). Un
#      renglón vigente, nunca dos versiones del mismo.
#   3. ANULAR EL MISMO RENGLÓN desde dos pestañas a la vez: una lo anula; la
#      otra, MX008.
#   4. CORREGIR Y ANULAR el mismo renglón a la vez: gana una; la otra, MX008.
#      Nunca un renglón corregido Y anulado.
#   5. RETIRAR LA MISMA EXPLICACIÓN desde dos pestañas a la vez: una la
#      retira; la otra, MX008 (ya no hay ninguna viva).
#   6. CAMBIAR LA CONFIGURACIÓN desde dos pestañas a la vez: entran las dos,
#      en orden; el historial guarda los dos valores anteriores.
#   7. EXPLICAR MIENTRAS ENTRA UN ASIENTO A ESA CUENTA (cinco veces, con el
#      asiento llegando antes, durante y después): la explicación guarda los
#      números con que se escribió; si el asiento entró después, la base LO
#      DICE (la explicación se quedó vieja). Nunca una cuenta «explicada» con
#      números que no son los de hoy; nadie muere por un bloqueo mortal.
# Y comprueba al final: una sola explicación viva por cuenta y fecha, ningún
# renglón con dos versiones vigentes, la cadena del libro en verde y el
# control de la cédula (el 10 y el 90) en verde.
#
# Cada sesión va como la app por PostgREST: el dueño, con el rol
# authenticated, los ajustes de ese rol y el tope de la API (8 s).
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c13_concurrencia}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'echo "(La base $BD y $TMP quedan: ./correr.sh --borrar $BD; rm -rf $TMP)"' EXIT
else
  trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

echo "== Base $BD: c1 + c2 + c3 + c13"
"$DIR/correr.sh" "$BD" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" "$DOCS/c13-cedula.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
HOY="$(ed -c "select fn_fecha_miami(now())")"
CTA="$(ed -c "select coalesce((select cuenta from puente_cuentas where rol = 'banco'), '1010')")"

# Como la app por PostgREST: con el rol authenticated, los ajustes de ese
# rol y el tope de la API (8 s). app <quién>.
app() {
  echo "select set_config('request.jwt.claims', '{\"sub\":\"$1\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"
}
# dueno <salida> <sql que devuelve un texto> [pausa con la transacción abierta]
dueno() {
  ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO ' || ($2); select pg_sleep(${3:-0}); commit;" > "$1" 2>&1
}
# un asiento a mano a la cuenta, como el dueño (Dr la cuenta / Cr 3100), con la fecha de hoy
asiento() {  # asiento <salida> <monto> [pausa]
  dueno "$1" "fn_postear('{\"fecha\": \"$HOY\", \"descripcion\": \"C13 CONC: un depósito\", \"lineas\": [{\"cuenta\": \"$CTA\", \"monto\": \"$2\"}, {\"cuenta\": \"3100\", \"monto\": \"-$2\"}]}')->>'numero'" "${3:-0}"
}
renglon() { ed -c "select id from cedula_manual where cuenta = '$CTA' and sustituido_el is null and anulado_el is null order by creado_el desc limit 1"; }
fila()    { ed -c "select x.saldo_libro || '|' || coalesce(x.saldo_auxiliar::text, '-') || '|' || x.estado || '|' || case when x.explicacion_vieja then 'vieja' else 'al día' end from fn_cedula('$HOY') x where x.cuenta = '$CTA'"; }

# La escena: 1,000 en el banco (hoy) y un renglón a mano de 900: no cuadra por 100.
asiento "$TMP/0a.out" "1000.00"
dueno "$TMP/0b.out" "fn_cedula_renglon('{\"cuenta\": \"$CTA\", \"concepto\": \"C13 CONC: lo que dice el statement\", \"monto\": \"900.00\", \"desde\": \"$HOY\", \"documento\": \"C13 CONC statement\"}')->>'id'"
revisa "al empezar: el banco con 1,000 en el libro, 900 en su renglón a mano, sin cuadrar" "1000.00|900.00|no_cuadra|al día" "$(fila)"

echo
echo "== 1. Explicar la misma cuenta y fecha desde dos pestañas a la vez"
dueno "$TMP/1a.out" "fn_cedula_explicar('$CTA', '$HOY', 'C13 CONC: pestaña A: los 100 son un cheque en tránsito')->>'id'" 0.6 &
sleep 0.15
dueno "$TMP/1b.out" "fn_cedula_explicar('$CTA', '$HOY', 'C13 CONC: pestaña B: los 100 son un depósito de mañana')->>'sustituye_a'" 0 &
wait
revisa "entran las dos, una detrás de otra" "2|0" "$(cat "$TMP"/1a.out "$TMP"/1b.out | grep -c 'RESULTADO')|$(cat "$TMP"/1a.out "$TMP"/1b.out | grep -c 'ERROR')"
revisa "la segunda esperó a la primera y la sustituye (la nombra)" "sí" \
  "$([ "$(sed -n 's/^RESULTADO //p' "$TMP/1a.out")" = "$(sed -n 's/^RESULTADO //p' "$TMP/1b.out")" ] && echo sí || echo no)"
revisa "una explicación viva (la de la pestaña B) y la otra como rastro" "1|1|pestaña B" \
  "$(ed -c "select count(*) filter (where sustituida_el is null and retirada_el is null) || '|' || count(*) filter (where sustituida_el is not null)
                   || '|' || max(substring(texto from 'pestaña [AB]')) filter (where sustituida_el is null and retirada_el is null)
              from cedula_explicaciones where cuenta = '$CTA' and fecha = '$HOY'")"
revisa "la cuenta queda explicada, al día" "1000.00|900.00|explicada|al día" "$(fila)"

echo
echo "== 2. Corregir el mismo renglón desde dos pestañas a la vez"
R="$(renglon)"
dueno "$TMP/2a.out" "fn_cedula_renglon('{\"id\": \"$R\", \"monto\": \"950.00\"}')->>'monto'" 0.6 &
sleep 0.15
dueno "$TMP/2b.out" "fn_cedula_renglon('{\"id\": \"$R\", \"monto\": \"960.00\"}')->>'monto'" 0 &
wait
revisa "una entra; la otra, MX008 (ese renglón ya se corrigió)" "1|1" \
  "$(cat "$TMP"/2a.out "$TMP"/2b.out | grep -c 'RESULTADO')|$(cat "$TMP"/2a.out "$TMP"/2b.out | grep -c 'MX008')"
revisa "un renglón vigente (el de 950) y el anterior, sustituido una sola vez" "1|950.00|1|1" \
  "$(ed -c "select count(*) filter (where sustituido_el is null and anulado_el is null) || '|' || max(monto) filter (where sustituido_el is null and anulado_el is null)
                   || '|' || count(*) filter (where sustituido_el is not null) || '|' || count(*) filter (where sustituye_a = '$R')
              from cedula_manual where cuenta = '$CTA'")"
revisa "y la explicación de antes se quedó vieja (el auxiliar cambió): lo dice" "1000.00|950.00|no_cuadra|vieja" "$(fila)"

echo
echo "== 3. Anular el mismo renglón desde dos pestañas a la vez"
R="$(renglon)"
dueno "$TMP/3a.out" "fn_cedula_renglon_anular('$R', 'C13 CONC: pestaña A')->>'anulado_motivo'" 0.6 &
sleep 0.15
dueno "$TMP/3b.out" "fn_cedula_renglon_anular('$R', 'C13 CONC: pestaña B')->>'anulado_motivo'" 0 &
wait
revisa "una lo anula; la otra, MX008" "1|1" "$(cat "$TMP"/3a.out "$TMP"/3b.out | grep -c 'RESULTADO')|$(cat "$TMP"/3a.out "$TMP"/3b.out | grep -c 'MX008')"
revisa "anulado una vez, con el motivo de quien entró" "1|C13 CONC: pestaña A|0" \
  "$(ed -c "select count(*) filter (where anulado_el is not null) || '|' || max(anulado_motivo) || '|' || count(*) filter (where sustituido_el is null and anulado_el is null)
              from cedula_manual where cuenta = '$CTA'")"

echo
echo "== 4. Corregir y anular el mismo renglón a la vez"
dueno "$TMP/4x.out" "fn_cedula_renglon('{\"cuenta\": \"$CTA\", \"concepto\": \"C13 CONC: otro renglón\", \"monto\": \"900.00\", \"desde\": \"$HOY\", \"documento\": \"C13 CONC statement\"}')->>'id'"
R="$(renglon)"
dueno "$TMP/4a.out" "fn_cedula_renglon('{\"id\": \"$R\", \"monto\": \"910.00\"}')->>'monto'" 0.6 &
sleep 0.15
dueno "$TMP/4b.out" "fn_cedula_renglon_anular('$R', 'C13 CONC: fuera')->>'anulado_motivo'" 0 &
wait
revisa "gana una; la otra, MX008" "1|1" "$(cat "$TMP"/4a.out "$TMP"/4b.out | grep -c 'RESULTADO')|$(cat "$TMP"/4a.out "$TMP"/4b.out | grep -c 'MX008')"
revisa "nunca un renglón corregido Y anulado; el vigente es el corregido (910)" "0|1|910.00" \
  "$(ed -c "select count(*) filter (where sustituido_el is not null and anulado_el is not null) || '|' || count(*) filter (where sustituido_el is null and anulado_el is null)
                   || '|' || max(monto) filter (where sustituido_el is null and anulado_el is null)
              from cedula_manual where cuenta = '$CTA'")"

echo
echo "== 5. Retirar la misma explicación desde dos pestañas a la vez"
dueno "$TMP/5a.out" "fn_cedula_explicacion_retirar('$CTA', '$HOY', 'C13 CONC: pestaña A')->>'retirada_motivo'" 0.6 &
sleep 0.15
dueno "$TMP/5b.out" "fn_cedula_explicacion_retirar('$CTA', '$HOY', 'C13 CONC: pestaña B')->>'retirada_motivo'" 0 &
wait
revisa "una la retira; la otra, MX008 (ya no hay ninguna viva)" "1|1" "$(cat "$TMP"/5a.out "$TMP"/5b.out | grep -c 'RESULTADO')|$(cat "$TMP"/5a.out "$TMP"/5b.out | grep -c 'MX008')"
revisa "ninguna viva, una retirada (una vez) y la sustituida de antes" "0|1|1" \
  "$(ed -c "select count(*) filter (where sustituida_el is null and retirada_el is null) || '|' || count(*) filter (where retirada_el is not null)
                   || '|' || count(*) filter (where sustituida_el is not null)
              from cedula_explicaciones where cuenta = '$CTA' and fecha = '$HOY'")"

echo
echo "== 6. Cambiar la configuración desde dos pestañas a la vez"
H0="$(ed -c "select jsonb_array_length(historial) from cedula_config where id = 1")"
dueno "$TMP/6a.out" "fn_cedula_config('{\"avisar_desde\": \"2027-02\"}')->>'avisar_desde'" 0.6 &
sleep 0.15
dueno "$TMP/6b.out" "fn_cedula_config('{\"patrimonio\": \"manual\"}')->>'patrimonio'" 0 &
wait
revisa "entran las dos, en orden" "2|0" "$(cat "$TMP"/6a.out "$TMP"/6b.out | grep -c 'RESULTADO')|$(cat "$TMP"/6a.out "$TMP"/6b.out | grep -c 'ERROR')"
revisa "quedan los dos cambios, y el historial guarda los dos valores de antes" "2027-02|manual|2" \
  "$(ed -c "select avisar_desde || '|' || patrimonio || '|' || (jsonb_array_length(historial) - $H0) from cedula_config where id = 1")"

echo
echo "== 7. Explicar mientras entra un asiento a esa cuenta (cinco veces)"
coherentes=0; mortales=0; errores=0
for i in 1 2 3 4 5; do
  pausa=$(echo "0.05 * ($i - 1)" | bc)
  dueno "$TMP/7e$i.out" "fn_cedula_explicar('$CTA', '$HOY', 'C13 CONC: vuelta $i: la diferencia es un cheque en tránsito')->>'saldo_libro'" 0.3 &
  sleep "$pausa"
  asiento "$TMP/7p$i.out" "10.00" 0 &
  wait
  mortales=$((mortales + $(cat "$TMP/7e$i.out" "$TMP/7p$i.out" | grep -c '40P01\|deadlock')))
  errores=$((errores + $(cat "$TMP/7e$i.out" "$TMP/7p$i.out" | grep -c 'ERROR')))
  # coherente: o está explicada con los números de hoy, o dice que se quedó vieja (el asiento entró después)
  ok="$(ed -c "select case when (x.estado = 'explicada' and not x.explicacion_vieja
                                 and (select e.saldo_libro from cedula_explicaciones e where e.id = x.explicacion_id) = x.saldo_libro)
                              or (x.estado = 'no_cuadra' and x.explicacion_vieja
                                 and (select e.saldo_libro from cedula_explicaciones e where e.id = x.explicacion_id) <> x.saldo_libro)
                         then 1 else 0 end from fn_cedula('$HOY') x where x.cuenta = '$CTA'")"
  coherentes=$((coherentes + ${ok:-0}))
done
revisa "las cinco veces la base dice la verdad: explicada con los números de hoy, o «se quedó vieja»" "5" "$coherentes"
revisa "entran las dos cada vez, y nadie muere por un bloqueo mortal (40P01)" "0|0" "$errores|$mortales"
revisa "los cinco asientos están en el libro (la cédula no frena a nadie)" "1050.00" "$(ed -c "select x.saldo_libro from fn_cedula('$HOY') x where x.cuenta = '$CTA'")"

echo
echo "== Al final"
revisa "una sola explicación viva por cuenta y fecha" "0" \
  "$(ed -c "select count(*) from (select 1 from cedula_explicaciones where sustituida_el is null and retirada_el is null group by cuenta, fecha having count(*) > 1) z")"
revisa "ningún renglón sustituido dos veces, ni corregido y anulado" "0|0" \
  "$(ed -c "select (select count(*) from (select 1 from cedula_manual where sustituye_a is not null group by sustituye_a having count(*) > 1) z)
                   || '|' || (select count(*) from cedula_manual where sustituido_el is not null and anulado_el is not null)")"
revisa "la cadena del libro, sin rojos (los permisos también)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"
revisa "el control de la cédula: el 10 y el 90, en verde" "0" "$(ed -c "select count(*) from fn_cedula_control(null) where nivel = 'cuadre' and not ok")"

echo
if [ $malos -eq 0 ]; then echo "c13-concurrencia: todo bien"; else echo "c13-concurrencia: ALGO FALLA"; fi
exit $malos
