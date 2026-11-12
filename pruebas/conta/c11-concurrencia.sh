#!/usr/bin/env bash
# =====================================================================
# c11-concurrencia.sh — lo que c11-pruebas.sql no puede probar: dos
# sesiones A LA VEZ con la emisión de facturas. c11-pruebas corre en una
# sola sesión; aquí se abren varias de verdad, y cada una confirma.
#
#   ./c11-concurrencia.sh [nombre_bd]      (por defecto c11_concurrencia)
#
# Crea su base con c1 + c2 + c3 + c11 (lo mínimo que c11 pide: sin c4, c6,
# p1, c9 ni c10), dos obras de prueba con sus hitos, los ajustes de la
# factura (el corte, hoy) y:
#   1. EL MISMO BORRADOR, «EMITIR» DESDE DOS PESTAÑAS a la vez (o dos
#      toques): la segunda espera a la primera (el candado del documento) y,
#      cuando le toca, el borrador ya es una factura: MX008, limpio. Una
#      factura, un número, un asiento, el hito facturado.
#   2. EL BORRADOR DEL MISMO HITO, ABIERTO DESDE DOS PESTAÑAS a la vez: una
#      lo crea; la otra lo encuentra (o para con MX008 «ya hay un borrador de
#      ese hito»). Un solo borrador.
#   3. OCHO EMISIONES A LA VEZ (ocho hitos) Y UNA QUE FALLA DESPUÉS DE TOMAR
#      SU NÚMERO (su obra ya tiene, en facturas que no salieron de la app,
#      todos los números que le podrían tocar): las ocho emiten con ocho
#      números SEGUIDOS, sin huecos ni repetidos, el contador queda en el
#      último, y la que falla da MX008 y no gasta número. Nadie muere por un
#      bloqueo mortal (40P01).
#   4. ANULAR LA MISMA FACTURA desde dos pestañas a la vez: una la anula
#      (su nota de crédito); la otra, MX008. Una sola nota, y el hito otra
#      vez pendiente.
#   5. VOLVER A PEGAR c11 CON LA PANTALLA LEYENDO (una lectura larga de las
#      obras por facturar, el pegado medio segundo después): el pegado se
#      rinde con 55P03 («lock timeout») en menos de 3 s, o entra; nadie
#      muere por 40P01; sin nadie leyendo, entra.
#   6. VOLVER A PEGAR c11 CON UNA EMISIÓN A MEDIAS (la emisión ya tiene su
#      número y su asiento y tarda 2 s en confirmar): el pegado se rinde o
#      entra, y la emisión termina con su número.
# Y comprueba: ningún cuadre de v_emision_control en rojo, la serie del año
# seguida desde el 1 con su contador en el último, y fn_verificar_cadena en
# verde.
#
# Cada sesión va como la app por PostgREST: el dueño, con el rol
# authenticated, los ajustes de ese rol y el tope de la API (8 s). El
# puente de c3 va diferido, como en producción: la emisión lo adelanta.
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c11_concurrencia}"
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

# Dos obras de prueba: la A, con catorce hitos (montos que no dividen) y
# retención del 10 %; la X, con uno. Las reglas de ingreso confirmadas, el
# corte hoy, y una empresa y un «How to pay» de mentira.
cat > "$TMP/montar.sql" <<'SQL'
insert into proyectos (id, tipo, nombre, estado, cliente) values
  ('c11-conc-a', 'servicio', 'C11 CONC Obra A', 'ejecucion', 'ZZ Cliente CONC A'),
  ('c11-conc-x', 'servicio', 'C11 CONC Obra X', 'ejecucion', 'ZZ Cliente CONC X');
insert into finanzas_proyecto (proyecto_id, contrato) values ('c11-conc-a', 24000.00), ('c11-conc-x', 1000.00);
insert into hitos (proyecto_id, titulo, monto, estado, orden)
select 'c11-conc-a', 'C11 CONC Milestone ' || g, 1000.00 + g * 0.37, 'pendiente', g from generate_series(1, 14) g;
insert into hitos (proyecto_id, titulo, monto, estado, orden) values ('c11-conc-x', 'C11 CONC Milestone X', 500.00, 'pendiente', 1);
select count(fn_mapeo_confirmar('tipo_proyecto', null));
select fn_emision_config(jsonb_build_object('corte', fn_fecha_miami(now())::text,
         'empresa', jsonb_build_object('nombre', 'ZZ Electric C11 CONCURRENCIA, Inc.'),
         'como_pagar', 'Check payable to ZZ Electric C11 CONCURRENCIA, Inc.'))->>'corte';
select fn_emision_obra('{"proyecto_id": "c11-conc-a", "retencion_pct": 10}')->'retencion'->>'pct';
SQL

echo "== Base $BD: c1 + c2 + c3 + c11 y lo de este script"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c11-emision.sql" "$TMP/montar.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' order by creado limit 1")"
ANIO="$(ed -c "select extract(year from fn_fecha_miami(now()))::int")"
# Como la app por PostgREST: con el rol authenticated, los ajustes de ese
# rol y el tope de la API (8 s). app <quién>.
app() {
  echo "select set_config('request.jwt.claims', '{\"sub\":\"$1\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"
}
hito()     { ed -c "select id from hitos where titulo = 'C11 CONC Milestone $1'"; }
borrador() { ed -c "select fn_emision_borrador(jsonb_build_object('forma', 'hito', 'hito_id', $1))->'documento'->>'id'"; }   # borrador <hito>
visto()    { ed -c "select fn_emision_documento('$1')->>'visto'"; }                                                          # visto <documento>
contador() { ed -c "select coalesce((select ultimo from contadores where serie = 'facturas-$ANIO'), 0)"; }
# emitir <salida> <documento> <visto> [pausa con los candados tomados]
emitir() {
  ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO ' || (fn_emision_emitir('$2', '$3')->>'numero'); select pg_sleep(${4:-0}); commit;" > "$1" 2>&1
}

echo
echo "== 1. El mismo borrador, «Emitir» desde dos pestañas a la vez"
H1="$(hito 1)"; D1="$(borrador "$H1")"; V1="$(visto "$D1")"
emitir "$TMP/1a.out" "$D1" "$V1" 0.6 &
sleep 0.15
emitir "$TMP/1b.out" "$D1" "$V1" 0 &
wait
revisa "una emite" "1" "$(cat "$TMP"/1a.out "$TMP"/1b.out | grep -c 'RESULTADO [A-Z0-9]*-[0-9]*-[0-9]*')"
revisa "la otra, MX008 (ese borrador ya se emitió)" "1" "$(cat "$TMP"/1a.out "$TMP"/1b.out | grep -c 'MX008: Ese borrador ya se emitió')"
revisa "una factura, un número, un asiento, el hito facturado" "1|1|1|facturado" \
  "$(ed -c "select format('%s|%s|%s|%s', (select count(*) from facturas where hito_id = $H1),
                          (select count(*) from emision_serie where documento_id = '$D1'),
                          (select count(*) from asientos a join facturas f on a.origen_tabla = 'facturas' and a.origen_id = f.id::text where f.hito_id = $H1),
                          (select estado from hitos where id = $H1))")"

echo
echo "== 2. El borrador del mismo hito, abierto desde dos pestañas a la vez"
H2="$(hito 2)"
for i in a b; do
  ( ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO nuevo=' || (fn_emision_borrador('{\"forma\": \"hito\", \"hito_id\": $H2}')->>'nuevo'); select pg_sleep(0.4); commit;" > "$TMP/2$i.out" 2>&1 ) &
  sleep 0.1
done
wait
revisa "una lo crea" "1" "$(cat "$TMP"/2a.out "$TMP"/2b.out | grep -c 'RESULTADO nuevo=true')"
revisa "la otra lo encuentra, o para limpio (MX008: ya hay un borrador de ese hito)" "1" \
  "$(cat "$TMP"/2a.out "$TMP"/2b.out | grep -c 'RESULTADO nuevo=false\|MX008: Ya hay un borrador de ese hito')"
revisa "un solo borrador de ese hito" "1" "$(ed -c "select count(*) from emision_documentos where hito_id = $H2")"

echo
echo "== 3. Ocho emisiones a la vez, y una que falla después de tomar su número"
declare -a DOC=() VIS=()
for g in 3 4 5 6 7 8 9 10; do
  DOC[$g]="$(borrador "$(hito "$g")")"; VIS[$g]="$(visto "${DOC[$g]}")"
done
HX="$(ed -c "select id from hitos where titulo = 'C11 CONC Milestone X'")"; DX="$(borrador "$HX")"; VX="$(visto "$DX")"
# la obra X ya tiene, en facturas que no salieron de la app (borradores: no entran al libro), todos los números que le podrían tocar
ed -c "insert into facturas (proyecto_id, num, fecha, monto, estado)
       select 'c11-conc-x', fn_emision_numero((select serie_formato from emision_config where id = 1), $ANIO, n), fn_fecha_miami(now()), 1, 'borrador'
         from generate_series(1, 60) n" > /dev/null
N0="$(contador)"
for g in 3 4 5 6 7 8 9 10; do
  emitir "$TMP/3-$g.out" "${DOC[$g]}" "${VIS[$g]}" 0.2 &
  [ "$g" = "6" ] && { emitir "$TMP/3-x.out" "$DX" "$VX" 0.2 & }
done
wait
revisa "las ocho emiten" "8" "$(cat "$TMP"/3-[0-9]*.out | grep -c 'RESULTADO [A-Z0-9]*-[0-9]*-[0-9]*')"
revisa "la que choca con un número ya usado en su obra: MX008, y sigue en borrador" "1|borrador" \
  "$(grep -c 'MX008: Esa obra ya tiene una factura con el número' "$TMP/3-x.out")|$(ed -c "select estado from emision_documentos where id = '$DX'")"
revisa "ocho números seguidos, sin huecos ni repetidos, y el contador en el último" "8|$((N0 + 1))|$((N0 + 8))|$((N0 + 8))|8" \
  "$(ed -c "select format('%s|%s|%s|%s|%s', count(*), min(s.secuencia), max(s.secuencia), (select ultimo from contadores where serie = 'facturas-$ANIO'), count(distinct s.numero))
              from emision_serie s where s.anio = $ANIO and s.secuencia > $N0")"
revisa "ocho facturas, cada una con su asiento al centavo (lo que se paga + lo retenido = su monto)" "8|8" \
  "$(ed -c "select format('%s|%s', count(*), count(*) filter (where s.cxc = d.a_pagar and s.retencion = d.retencion and d.a_pagar + d.retencion = d.monto))
              from emision_documentos d cross join lateral fn_emision_saldo(d.factura_id) s
             where d.estado = 'emitida' and d.secuencia > $N0 and d.factura_id is not null")"
revisa "nadie murió por un bloqueo mortal (40P01) ni por el tope de la API" "0" "$(cat "$TMP"/3-*.out | grep -c '40P01\|deadlock\|57014')"

echo
echo "== 4. Anular la misma factura desde dos pestañas a la vez"
for i in a b; do
  ( ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO ' || (fn_emision_anular('$D1', 'c11-concurrencia: desde la pestaña $i')->>'nota_credito'); select pg_sleep(0.4); commit;" > "$TMP/4$i.out" 2>&1 ) &
  sleep 0.1
done
wait
revisa "una la anula, con su nota de crédito" "1" "$(cat "$TMP"/4a.out "$TMP"/4b.out | grep -c 'RESULTADO NC-')"
revisa "la otra, MX008 (ya estaba anulada)" "1" "$(cat "$TMP"/4a.out "$TMP"/4b.out | grep -c 'MX008: La factura .* ya estaba anulada')"
revisa "una sola nota de crédito, la factura anulada y el hito otra vez pendiente" "1|anulada|pendiente" \
  "$(ed -c "select format('%s|%s|%s', (select count(*) from notas_credito n join facturas f on f.id = n.anula_a where f.hito_id = $H1),
                          (select estado from facturas where hito_id = $H1), (select estado from hitos where id = $H1))")"

echo
echo "== 5. Volver a pegar c11 con la pantalla leyendo"
# una lectura larga del dueño (las obras por facturar y los documentos, y la transacción abierta 3 s), y el pegado medio segundo después
( ed -c "begin; $(app "$DUENO") select count(*) from v_emision_obras; select count(*) from v_emision_documentos; select pg_sleep(3); commit;" > "$TMP/5l.out" 2>&1 ) &
sleep 0.5
t0=$(date +%s.%N)
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$DOCS/c11-emision.sql" > "$TMP/5p.out" 2>&1
rc=$?
t1=$(date +%s.%N)
wait
seg="$(echo "$t1 - $t0" | bc)"
if grep -q '55P03\|lock timeout\|canceling statement due to lock timeout' "$TMP/5p.out"; then como="se rindió con 55P03"; elif [ $rc -eq 0 ]; then como="entró"; else como="OTRO error"; tail -n 3 "$TMP/5p.out"; fi
echo "     (el pegado $como en $seg s)"
revisa "el pegado se rinde (55P03) o entra, en menos de 3 s" "1" "$( { [ "$como" != "OTRO error" ] && [ "$(echo "$seg < 3" | bc)" = "1" ]; } && echo 1 || echo 0)"
revisa "nadie muere por un bloqueo mortal (40P01), y la lectura termina" "0|0" "$(cat "$TMP"/5p.out "$TMP"/5l.out | grep -c '40P01\|deadlock')|$(grep -c 'ERROR' "$TMP/5l.out")"
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$DOCS/c11-emision.sql" > "$TMP/5p2.out" 2>&1
revisa "sin nadie leyendo, entra (y no pisa nada: las mismas facturas y la misma serie)" "0|8" \
  "$?|$(ed -c "select count(*) from emision_serie s where s.anio = $ANIO and s.secuencia > $N0")"

echo
echo "== 6. Volver a pegar c11 con una emisión a medias"
H11="$(hito 11)"; D11="$(borrador "$H11")"; V11="$(visto "$D11")"
emitir "$TMP/6e.out" "$D11" "$V11" 2 &
sleep 0.5
t0=$(date +%s.%N)
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$DOCS/c11-emision.sql" > "$TMP/6p.out" 2>&1
rc=$?
t1=$(date +%s.%N)
wait
seg="$(echo "$t1 - $t0" | bc)"
if grep -q '55P03\|lock timeout\|canceling statement due to lock timeout' "$TMP/6p.out"; then como="se rindió con 55P03"; elif [ $rc -eq 0 ]; then como="entró"; else como="OTRO error"; tail -n 3 "$TMP/6p.out"; fi
echo "     (el pegado $como en $seg s)"
revisa "el pegado se rinde (55P03) o entra, en menos de 3 s" "1" "$( { [ "$como" != "OTRO error" ] && [ "$(echo "$seg < 3" | bc)" = "1" ]; } && echo 1 || echo 0)"
revisa "la emisión termina con su número, y nadie muere por 40P01" "1|0" \
  "$(grep -c 'RESULTADO [A-Z0-9]*-[0-9]*-[0-9]*' "$TMP/6e.out")|$(cat "$TMP"/6p.out "$TMP"/6e.out | grep -c '40P01\|deadlock')"
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$DOCS/c11-emision.sql" > "$TMP/6p2.out" 2>&1
revisa "después, el pegado entra" "0" "$?"

echo
echo "== Al final"
revisa "v_emision_control: ningún cuadre en rojo" "0" "$(ed -c "select count(*) from v_emision_control where not ok and nivel = 'cuadre'")"
revisa "la serie del año, seguida desde el 1, sin repetidos, y el contador en el último" "1" \
  "$(ed -c "select (min(s.secuencia) = 1 and max(s.secuencia) = count(*) and count(distinct s.numero) = count(*)
                    and max(s.secuencia) = (select ultimo from contadores where serie = 'facturas-$ANIO'))::int
              from emision_serie s where s.anio = $ANIO")"
revisa "cada número, de una factura emitida; y diez facturas emitidas por la app (una, anulada)" "0|10|1" \
  "$(ed -c "select format('%s|%s|%s', (select count(*) from emision_serie s where not exists (select 1 from emision_documentos d where d.id = s.documento_id and d.estado = 'emitida' and d.numero = s.numero)),
                          (select count(*) from emision_documentos where estado = 'emitida'), (select count(*) from emision_documentos where anulado_el is not null))")"
revisa "la cadena del libro, sin rojos (los permisos también)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"

echo
if [ $malos -eq 0 ]; then echo "c11-concurrencia: todo bien"; else echo "c11-concurrencia: ALGO FALLA"; fi
exit $malos
