#!/usr/bin/env bash
# =====================================================================
# c12-concurrencia.sh — lo que c12-pruebas.sql no puede probar: dos
# sesiones A LA VEZ con el WIP. c12-pruebas corre en una sola sesión; aquí
# se abren varias de verdad, y cada una confirma.
#
#   ./c12-concurrencia.sh [nombre_bd]      (por defecto c12_concurrencia)
#
# Crea su base con c1 + c2 + c3 + c4 + c6 + c10 + c12, tres obras de prueba
# de precio fijo con su costo de octubre de 2026, sus facturas y su revisión
# (A sub-facturada 3,000; B sobre-facturada 4,000; C con pérdida), y:
#   1. «POSTEAR EL AJUSTE» DESDE DOS PESTAÑAS a la vez (o dos toques): la
#      segunda espera a la primera (el candado del mes) y, cuando le toca,
#      el ajuste ya está: se lo devuelve (ya_estaba). Un ajuste, un asiento,
#      un reverso del día 1.
#   2. REVISAR LA MISMA OBRA desde dos pestañas a la vez, con números
#      distintos: entran las dos, una detrás de otra (el candado de la obra
#      y el mes); queda UNA revisión vigente y las demás como rastro.
#   3. CONFIRMAR LO DE ANTES DEL LIBRO de la misma obra desde dos pestañas
#      a la vez: una confirmación vigente; la otra queda como rastro.
#   4. REHACER (la revisión cambió después de postear) desde dos pestañas a
#      la vez: una lo rehace (un reverso del viejo, la anulación de su
#      reverso del día 1 y el nuevo); la otra recibe el nuevo. Nunca dos
#      ajustes vivos ni dos reversos del mismo asiento.
#   5. DESHACER desde dos pestañas a la vez: una lo deshace; la otra, MX008
#      (ya no hay ajuste vivo). Un solo reverso.
#   6. POSTEAR MIENTRAS ENTRA UN COSTO AL MES (cinco veces, con el costo
#      llegando antes, durante y después). «Postear» toma el candado de la
#      cadena del libro antes de calcular: o el costo entró antes y el ajuste
#      lo lleva dentro (al día), o espera a que el ajuste termine y entra
#      después, y entonces la base LO DICE (el ajuste ya no es el de hoy: el
#      control en rojo hasta volver a postear). Nunca un ajuste «al día» con
#      un cálculo que no es el de hoy; nadie muere por un bloqueo mortal.
#   7. VOLVER A PEGAR c12 CON LA PANTALLA LEYENDO (una lectura larga del
#      WIP, el pegado medio segundo después): el pegado se rinde con 55P03
#      («lock timeout») en menos de 3 s, o entra; nadie muere por 40P01; sin
#      nadie leyendo, entra, y lo guardado sigue ahí.
# Y comprueba al final: ningún cuadre de fn_wip_control en rojo, cada ajuste
# vivo al día, fn_verificar_cadena en verde y el control de «Estados» (c4)
# al cierre de octubre sin nada nuevo en rojo.
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
BD="${1:-c12_concurrencia}"
MES='2026-10'
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

# Tres obras de precio fijo, su costo de octubre (a mano, como el dueño: Dr
# 5100 con su obra / Cr 3100), sus facturas (por el puente de c3) y su
# revisión de octubre. La regla del tipo de obra, confirmada (en producción
# ya lo está).
cat > "$TMP/montar.sql" <<'SQL'
select fn_mapeo_confirmar('tipo_proyecto');
insert into proyectos (id, tipo, nombre, estado) values
  ('c12-conc-a', 'comercial', 'C12 CONC Obra A', 'ejecucion'), ('c12-conc-b', 'residencial', 'C12 CONC Obra B', 'ejecucion'),
  ('c12-conc-c', 'comercial', 'C12 CONC Obra C', 'ejecucion');
insert into finanzas_proyecto (proyecto_id, contrato) values ('c12-conc-a', 10000), ('c12-conc-b', 20000), ('c12-conc-c', 10000);
select fn_postear(jsonb_build_object('fecha', '2026-10-10', 'descripcion', 'C12 CONC: costo de ' || o.id,
         'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', o.costo::text, 'proyecto_id', o.id),
                                     jsonb_build_object('cuenta', '3100', 'monto', (-o.costo)::text))))->>'numero'
  from (values ('c12-conc-a', 3000.00), ('c12-conc-b', 4000.00), ('c12-conc-c', 6000.00)) o(id, costo);
insert into facturas (proyecto_id, num, fecha, monto, retencion) values
  ('c12-conc-a', 'C12C-1', '2026-10-12', 2000, 0), ('c12-conc-b', 'C12C-2', '2026-10-12', 9000, 0);
select fn_wip_revisar('c12-conc-a', '2026-10', '{"costo_estimado": "6000"}')->>'nota';
select fn_wip_revisar('c12-conc-b', '2026-10', '{"costo_estimado": "16000"}')->>'nota';
select fn_wip_revisar('c12-conc-c', '2026-10', '{"costo_estimado": "12000"}')->>'nota';
SQL

echo "== Base $BD: c1 + c2 + c3 + c4 + c6 + c10 + c12 y lo de este script"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$DOCS/c10-costo-obra.sql" "$DOCS/c12-wip.sql" "$TMP/montar.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' order by creado limit 1")"
ROJOS_C4="$(ed -c "select coalesce(string_agg(vista, '; ' order by vista), '') from fn_estados_control('$MES') where not ok")"
revisa "al empezar: las tres obras listas, con sus cifras" "c12-conc-a sub 3000.00|c12-conc-b sobre 4000.00|c12-conc-c sub 5000.00 prov 1000.00" \
  "$(ed -c "select string_agg(proyecto_id || case when sub_facturado > 0 then ' sub ' || sub_facturado else ' sobre ' || sobre_facturado end
                              || case when perdida_provision > 0 then ' prov ' || perdida_provision else '' end, '|' order by proyecto_id)
              from fn_wip_schedule('$MES') where proyecto_id like 'c12-conc-%' and en_ajuste")"

# Como la app por PostgREST: con el rol authenticated, los ajustes de ese
# rol (el jit = off de c4) y el tope de la API (8 s). app <quién>.
app() {
  echo "select set_config('request.jwt.claims', '{\"sub\":\"$1\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"
}
# postear <salida> [pausa con el candado tomado]: «posteado», «rehecho» o «ya estaba», y su asiento
postear() {
  ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO ' || case when (z.r->>'ya_estaba')::boolean then 'ya estaba' when z.r->'rehecho' <> 'null'::jsonb then 'rehecho' when (z.r->>'posteado')::boolean then 'posteado' else 'nada' end || ' ' || coalesce(z.r->'asiento'->>'numero', '') from (select fn_wip_postear('$MES') as r) z; select pg_sleep(${2:-0}); commit;" > "$1" 2>&1
}
vivos()  { ed -c "select count(*) from wip_ajustes where periodo = '$MES' and deshecho_el is null"; }
al_dia() { ed -c "select fn_wip_ajuste_estado('$MES')->>'al_dia'"; }

echo
echo "== 1. «Postear el ajuste» desde dos pestañas a la vez"
postear "$TMP/1a.out" 0.6 &
sleep 0.15
postear "$TMP/1b.out" 0 &
wait
revisa "una lo postea" "1" "$(cat "$TMP"/1a.out "$TMP"/1b.out | grep -c 'RESULTADO posteado')"
revisa "la otra recibe el que ya estaba (el mismo asiento)" "1|1" \
  "$(cat "$TMP"/1a.out "$TMP"/1b.out | grep -c 'RESULTADO ya estaba')|$(cat "$TMP"/1a.out "$TMP"/1b.out | grep 'RESULTADO' | awk '{print $NF}' | sort -u | wc -l | tr -d ' ')"
revisa "un ajuste vivo, un asiento reversible y un reverso del día 1" "1|1|1" \
  "$(ed -c "select format('%s|%s|%s', (select count(*) from wip_ajustes where periodo = '$MES' and deshecho_el is null),
                          (select count(*) from asientos where reversible),
                          (select count(*) from asientos where camino = 'reverso_automatico' and fecha_contable = '2026-11-01'))")"

echo
echo "== 2. Revisar la misma obra desde dos pestañas a la vez, con números distintos"
for i in a b; do
  n=$([ "$i" = a ] && echo 7000 || echo 8000)
  ( ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO ' || (fn_wip_revisar('c12-conc-a', '$MES', '{\"costo_estimado\": \"$n\", \"nota\": \"c12-concurrencia: pestaña $i\"}')->>'revision_id'); select pg_sleep(0.4); commit;" > "$TMP/2$i.out" 2>&1 ) &
  sleep 0.1
done
wait
revisa "entran las dos, una detrás de otra" "2|0" "$(cat "$TMP"/2a.out "$TMP"/2b.out | grep -c 'RESULTADO')|$(cat "$TMP"/2a.out "$TMP"/2b.out | grep -c 'ERROR')"
revisa "una revisión vigente (la última en entrar), y las otras dos como rastro" "1|3|8000.00" \
  "$(ed -c "select format('%s|%s|%s', count(*) filter (where sustituida_el is null), count(*), max(costo_estimado) filter (where sustituida_el is null))
              from wip_revisiones where proyecto_id = 'c12-conc-a' and periodo = '$MES'")"

echo
echo "== 3. Confirmar lo de antes del libro de la misma obra desde dos pestañas a la vez"
for i in a b; do
  n=$([ "$i" = a ] && echo 100 || echo 200)
  ( ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO ' || (fn_wip_antes('c12-conc-b', '{\"costo\": \"$n\", \"facturado\": \"0\", \"nota\": \"c12-concurrencia: pestaña $i\"}')->>'antes_id'); select pg_sleep(0.4); commit;" > "$TMP/3$i.out" 2>&1 ) &
  sleep 0.1
done
wait
revisa "entran las dos, una detrás de otra" "2|0" "$(cat "$TMP"/3a.out "$TMP"/3b.out | grep -c 'RESULTADO')|$(cat "$TMP"/3a.out "$TMP"/3b.out | grep -c 'ERROR')"
revisa "una confirmación vigente (la última en entrar), y la otra como rastro" "1|2|200.00" \
  "$(ed -c "select format('%s|%s|%s', count(*) filter (where sustituida_el is null), count(*), max(costo) filter (where sustituida_el is null))
              from wip_antes where proyecto_id = 'c12-conc-b'")"

echo
echo "== 4. Rehacer (la revisión y lo de antes cambiaron) desde dos pestañas a la vez"
revisa "antes: el ajuste posteado ya no está al día, y lo dice" "false|rojo" \
  "$(al_dia)|$(ed -c "select case when ok then 'verde' else 'rojo' end from fn_wip_control('$MES') where orden = 50")"
VIEJO="$(ed -c "select asiento_id from wip_ajustes where periodo = '$MES' and deshecho_el is null")"
postear "$TMP/4a.out" 0.6 &
sleep 0.15
postear "$TMP/4b.out" 0 &
wait
revisa "una lo rehace y la otra recibe el nuevo" "1|1" \
  "$(cat "$TMP"/4a.out "$TMP"/4b.out | grep -c 'RESULTADO rehecho')|$(cat "$TMP"/4a.out "$TMP"/4b.out | grep -c 'RESULTADO ya estaba')"
revisa "un ajuste vivo y al día; el viejo, deshecho con UN reverso y su reverso del día 1 anulado una vez" "1|true|1|1" \
  "$(vivos)|$(al_dia)|$(ed -c "select count(*) from asientos where reversa_a = '$VIEJO' and camino = 'reverso'")|$(ed -c "select count(*) from asientos x join asientos r on r.id = x.reversa_a where r.reversa_a = '$VIEJO' and r.camino = 'reverso_automatico' and x.camino = 'reverso'")"

echo
echo "== 5. Deshacer desde dos pestañas a la vez"
VIVO="$(ed -c "select asiento_id from wip_ajustes where periodo = '$MES' and deshecho_el is null")"
for i in a b; do
  ( ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO deshecho ' || (fn_wip_deshacer('$MES', 'c12-concurrencia: desde la pestaña $i')->'reverso'->>'numero'); select pg_sleep(0.4); commit;" > "$TMP/5$i.out" 2>&1 ) &
  sleep 0.1
done
wait
revisa "una lo deshace" "1" "$(cat "$TMP"/5a.out "$TMP"/5b.out | grep -c 'RESULTADO deshecho')"
revisa "la otra, MX008 (ya no hay un ajuste vivo)" "1" "$(cat "$TMP"/5a.out "$TMP"/5b.out | grep -c 'MX008: .*no tiene un ajuste de WIP vivo')"
revisa "un solo reverso, ningún ajuste vivo, y el saldo de sub-facturado a cero" "1|0|0.00" \
  "$(ed -c "select count(*) from asientos where reversa_a = '$VIVO' and camino = 'reverso'")|$(vivos)|$(ed -c "select coalesce(sum(l.monto), 0)::numeric(14,2) from asiento_lineas l where l.cuenta = '1200'")"

echo
echo "== 6. Postear mientras entra un costo al mes (5 veces)"
dentro=0; dicho=0; raro=0
for w in 1 2 3 4 5; do
  # el costo llega antes de que Edgar toque «Postear» (veces 1 y 3), después (2 y 4) o a la vez (5)
  case $w in 1) dc=0; dp=0.08 ;; 2) dc=0.05; dp=0 ;; 3) dc=0; dp=0.03 ;; 4) dc=0.02; dp=0 ;; *) dc=0; dp=0 ;; esac
  ( sleep "$dc"; ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'COSTO ' || (fn_postear(jsonb_build_object('fecha', '2026-10-2$w', 'descripcion', 'C12 CONC: un costo que llega mientras se postea ($w)', 'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', '10$w.00', 'proyecto_id', 'c12-conc-b'), jsonb_build_object('cuenta', '3100', 'monto', '-10$w.00'))))->>'numero'); commit;" > "$TMP/6c-$w.out" 2>&1 ) &
  ( sleep "$dp"; postear "$TMP/6p-$w.out" 0 ) &
  wait
  grep -q 'COSTO ' "$TMP/6c-$w.out" || { raro=$((raro + 1)); echo "     vez $w: el costo no entró:"; tail -n 2 "$TMP/6c-$w.out"; }
  # («ya estaba»: Edgar tocó antes de que el costo llegara; el ajuste que había seguía al día en ese momento)
  grep -q 'RESULTADO \(posteado\|rehecho\|ya estaba\)' "$TMP/6p-$w.out" || { raro=$((raro + 1)); echo "     vez $w: postear no respondió:"; tail -n 2 "$TMP/6p-$w.out"; }
  # o está al día (y su foto lleva el costo de hoy), o no lo está y el control lo dice
  r="$(ed -c "select format('%s|%s|%s', fn_wip_ajuste_estado('$MES')->>'al_dia',
                            (select (w.costo_fecha = (select s.costo_fecha from fn_wip_schedule('$MES') s where s.proyecto_id = 'c12-conc-b'))::text
                               from wip_ajuste_obras w join wip_ajustes a on a.id = w.ajuste_id
                              where a.periodo = '$MES' and a.deshecho_el is null and w.proyecto_id = 'c12-conc-b'),
                            (select case when ok then 'verde' else 'rojo' end from fn_wip_control('$MES') where orden = 50))")"
  case "$r" in
    "true|true|verde")  dentro=$((dentro + 1)) ;;
    "false|false|rojo") dicho=$((dicho + 1)); postear "$TMP/6r-$w.out" 0
                        [ "$(al_dia)" = "true" ] || { raro=$((raro + 1)); echo "     vez $w: después de rehacer no quedó al día"; } ;;
    *) raro=$((raro + 1)); echo "     vez $w: quedó $r (se esperaba true|true|verde o false|false|rojo)" ;;
  esac
done
echo "     ($dentro veces el ajuste entró con el costo dentro; $dicho veces sin él, y la base lo dijo)"
revisa "cinco veces: o al día con el costo dentro, o desfasado y dicho; nunca «al día» con otro cálculo" "5|0" "$((dentro + dicho))|$raro"
revisa "nadie murió por un bloqueo mortal ni por el tope de la API" "0" "$(cat "$TMP"/6c-*.out "$TMP"/6p-*.out | grep -c '40P01\|deadlock\|57014')"

echo
echo "== 7. Volver a pegar c12 con la pantalla leyendo"
ANTES="$(ed -c "select format('%s|%s|%s|%s', (select count(*) from wip_revisiones), (select count(*) from wip_antes), (select count(*) from wip_ajustes), (select exigir_desde from wip_config))")"
# una lectura larga del dueño (el WIP del mes y su control, y la transacción abierta 3 s), y el pegado medio segundo después
( ed -c "begin; $(app "$DUENO") select count(*) from v_wip_schedule where periodo = '$MES'; select count(*) from v_wip_control; select count(*) from v_wip_ajustes; select pg_sleep(3); commit;" > "$TMP/7l.out" 2>&1 ) &
sleep 0.5
t0=$(date +%s.%N)
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$DOCS/c12-wip.sql" > "$TMP/7p.out" 2>&1
rc=$?
t1=$(date +%s.%N)
wait
seg="$(echo "$t1 - $t0" | bc)"
if grep -q '55P03\|lock timeout\|canceling statement due to lock timeout' "$TMP/7p.out"; then como="se rindió con 55P03"; elif [ $rc -eq 0 ]; then como="entró"; else como="OTRO error"; tail -n 3 "$TMP/7p.out"; fi
echo "     (el pegado $como en $seg s)"
revisa "el pegado se rinde (55P03) o entra, en menos de 3 s" "1" "$( { [ "$como" != "OTRO error" ] && [ "$(echo "$seg < 3" | bc)" = "1" ]; } && echo 1 || echo 0)"
revisa "nadie muere por un bloqueo mortal (40P01), y la lectura termina" "0|0" "$(cat "$TMP"/7p.out "$TMP"/7l.out | grep -c '40P01\|deadlock')|$(grep -c 'ERROR' "$TMP/7l.out")"
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$DOCS/c12-wip.sql" > "$TMP/7p2.out" 2>&1
revisa "sin nadie leyendo, entra" "0" "$?"
revisa "y lo guardado sigue ahí (las revisiones, lo de antes, los ajustes y la configuración)" "$ANTES" \
  "$(ed -c "select format('%s|%s|%s|%s', (select count(*) from wip_revisiones), (select count(*) from wip_antes), (select count(*) from wip_ajustes), (select exigir_desde from wip_config))")"

echo
echo "== Al final"
revisa "el control del WIP: ningún cuadre en rojo" "0" "$(ed -c "select count(*) from fn_wip_control('$MES') where not ok and nivel = 'cuadre'")"
revisa "un ajuste vivo, al día, y es su asiento (el saldo por obra es el del ajuste)" "1|true|verde" \
  "$(vivos)|$(al_dia)|$(ed -c "select case when ok then 'verde' else 'rojo' end from fn_wip_control('$MES') where orden = 20")"
revisa "la cadena del libro, sin rojos (los permisos también)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"
revisa "el control de «Estados» (c4) al cierre de octubre: nada nuevo en rojo" "$ROJOS_C4" \
  "$(ed -c "select coalesce(string_agg(vista, '; ' order by vista), '') from fn_estados_control('$MES') where not ok")"
revisa "«Costo por obra» (c10): sus cuadres, sin rojos" "0" "$(ed -c "select count(*) from v_margen_control where not ok and nivel = 'cuadre'")"

echo
if [ $malos -eq 0 ]; then echo "c12-concurrencia: todo bien"; else echo "c12-concurrencia: ALGO FALLA"; fi
exit $malos
