#!/usr/bin/env bash
# =====================================================================
# c11-concurrencia.sh — lo que c11-pruebas.sql no puede probar: dos
# sesiones A LA VEZ con la emisión de facturas. c11-pruebas corre en una
# sola sesión; aquí se abren varias de verdad, y cada una confirma.
#
#   ./c11-concurrencia.sh [nombre_bd]      (por defecto c11_concurrencia)
#
# Crea su base con c1 + c2 + c3 + c11 (lo mínimo que c11 pide: sin c4, c6,
# p1, c9 ni c10) y, COMO PRODUCCIÓN, los índices únicos de facturas por hito
# y el candado de borrado de Storage (06-produccion-facturas.sql; con
# SIN_REPLICA=1 no se cargan y la 4c no corre: sin esos índices nada para a
# la segunda factura de un hito); diez obras de prueba con sus hitos, los
# ajustes de la factura (el corte, hoy) y:
#   1. EL MISMO BORRADOR, «EMITIR» DESDE DOS PESTAÑAS a la vez (o dos
#      toques): la segunda espera a la primera (el candado del documento) y,
#      cuando le toca, el borrador ya es una factura: MX008, limpio. Una
#      factura, un número, un asiento, el hito facturado.
#   2. EL BORRADOR DEL MISMO HITO, ABIERTO DESDE DOS PESTAÑAS a la vez: una
#      lo crea; la otra lo encuentra (o para con MX008 «ya hay un borrador de
#      ese hito»). Un solo borrador.
#   3. OCHO EMISIONES A LA VEZ (ocho obras, un hito cada una) Y UNA QUE
#      FALLA DESPUÉS DE TOMAR SU NÚMERO (el libro no la acepta: la cuenta de
#      ingreso del tipo de su obra está inactiva): las ocho emiten con ocho
#      números SEGUIDOS, sin huecos ni repetidos, el contador queda en el
#      último, y la que falla da MX008 y no gasta número. Nadie muere por un
#      bloqueo mortal (40P01).
#   3b. DOS EMISIONES A LA VEZ EN LA MISMA OBRA (dos hitos): van de una en
#      una (el candado de la obra). La segunda, cuando le toca, ya no es lo
#      que la pantalla enseñó —entró otra factura de esa obra: cambiaron su
#      ordinal y lo facturado antes—: MX011, limpio, sin número. Refrescada,
#      emite con el número siguiente.
#   4. ANULAR LA MISMA FACTURA desde dos pestañas a la vez: una la anula
#      (su nota de crédito); la otra, MX008. Una sola nota, y el hito otra
#      vez pendiente.
#   4b. VOLVER A FACTURAR ESE HITO, «EMITIR» DESDE DOS PESTAÑAS a la vez,
#      con la anulada todavía apuntando al hito (la base admite una sola
#      fila de facturas por hito, también contando las anuladas): una emite
#      —la anulada suelta el hito y queda apuntado, una vez—; la otra, MX008.
#      Una sola factura viva de ese hito; la anulada sigue anulada, con su
#      nota de crédito; nadie muere por 40P01 ni choca con el índice.
#   4c. LA APP Y QUICKBOOKS A LA VEZ, EL MISMO HITO (solo con los índices):
#      por fuera entra una factura de un hito (sin confirmar todavía) y la
#      app emite ese mismo hito: la emisión ESPERA a la otra (la fila de
#      fuera sujeta su hito por la llave de facturas) y, cuando confirma,
#      para en llano —MX011: ya no es lo que viste, entró otra factura de la
#      obra—, sin gastar número y sin llegar a chocar con el índice. Queda
#      una sola factura de ese hito, y el borrador, frenado (ya se facturó).
#   5. VOLVER A PEGAR c11 CON LA PANTALLA LEYENDO (una lectura larga de las
#      obras por facturar, el pegado medio segundo después): el pegado se
#      rinde con 55P03 («lock timeout») en menos de 3 s, o entra; nadie
#      muere por 40P01; sin nadie leyendo, entra.
#   6. VOLVER A PEGAR c11 CON UNA EMISIÓN A MEDIAS (la emisión ya tiene su
#      número y su asiento y tarda 2 s en confirmar): el pegado se rinde o
#      entra, y la emisión termina con su número.
#   7. c11-pruebas.sql CON LA APP USANDO STORAGE. Las pruebas de la capa
#      también se pegan en producción, con la app encendida. La 46 pone y
#      quita policies de prueba en storage.objects (la tabla de TODOS los
#      archivos de la app): con una transacción de otra sesión que leyó esa
#      tabla y sigue abierta (un respaldo, una sesión colgada), la corrida
#      NO se queda esperándola —detrás de quien espera ese candado se quedan
#      todas las lecturas de archivos que lleguen—: espera medio segundo
#      (su lock_timeout), prueba solo la primera mitad de la 46 y lo dice.
#      Mientras corre, ninguna lectura de Storage «de la app» espera más de
#      2 s; la corrida termina sola, y ninguna prueba sale en falso. (Sin
#      el tope: la corrida colgada hasta que la otra sesión termina y las
#      lecturas de la app, con ella.)
#   8. c11-pruebas.sql CON LA APP ESCRIBIENDO EN facturas, EN UNA BASE SIN
#      EL ÍNDICE QUE CUENTA LAS ANULADAS (producción, el día que la otra
#      sesión quite ux_facturas_hito: aquí se quita de esta base de prueba y
#      queda el de las vivas). Las pruebas no crean ningún índice en
#      facturas ni toman ningún candado que pare sus escrituras: con una
#      transacción de otra sesión que escribió en una factura y sigue
#      abierta, la corrida termina sola; mientras corre, una escritura
#      inocua en OTRA factura («marcar cobrada», la rutina de pagadas) nunca
#      espera más de 2 s; la 52, la 53 y la 54 corren con el índice que hay,
#      ninguna sale en falso, y a facturas no le queda ningún índice de más.
#      (Antes, esas tres ponían un índice igual dentro de sí mismas: crear
#      un índice espera a quien esté escribiendo y para a todo el que llegue
#      después. En una base como la de producción se midió «marcar cobrada»
#      esperando casi 8 s, el tope de la API; aquí, la corrida colgada y las
#      escrituras con ella.)
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
# C11_PRUEBAS=<archivo>: el c11-pruebas.sql que corren la 7 y la 8 (por
# defecto, el de docs/conta; sirve para comparar con una versión anterior).
# SIN_PRUEBAS=1 se salta la 7 y la 8 (cada una corre la suite entera).
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

# Diez obras de prueba: la A, con catorce hitos (montos que no dividen) y
# retención del 10 %; las B1 a B8, con uno cada una y retención del 10 %; y
# la X (de otro tipo: «comercial»), con uno. Las reglas de ingreso
# confirmadas, el corte hoy, y una empresa y un «How to pay» de mentira.
cat > "$TMP/montar.sql" <<'SQL'
insert into proyectos (id, tipo, nombre, estado, cliente) values
  ('c11-conc-a', 'servicio', 'C11 CONC Obra A', 'ejecucion', 'ZZ Cliente CONC A'),
  ('c11-conc-x', 'comercial', 'C11 CONC Obra X', 'ejecucion', 'ZZ Cliente CONC X');
insert into proyectos (id, tipo, nombre, estado, cliente)
select 'c11-conc-b' || g, 'servicio', 'C11 CONC Obra B' || g, 'ejecucion', 'ZZ Cliente CONC B' || g from generate_series(1, 8) g;
insert into finanzas_proyecto (proyecto_id, contrato) values ('c11-conc-a', 24000.00), ('c11-conc-x', 1000.00);
insert into finanzas_proyecto (proyecto_id, contrato) select 'c11-conc-b' || g, 2000.00 from generate_series(1, 8) g;
insert into hitos (proyecto_id, titulo, monto, estado, orden)
select 'c11-conc-a', 'C11 CONC Milestone ' || g, 1000.00 + g * 0.37, 'pendiente', g from generate_series(1, 14) g;
insert into hitos (proyecto_id, titulo, monto, estado, orden)
select 'c11-conc-b' || g, 'C11 CONC Milestone B' || g, 1000.00 + g * 0.37, 'pendiente', 1 from generate_series(1, 8) g;
insert into hitos (proyecto_id, titulo, monto, estado, orden) values ('c11-conc-x', 'C11 CONC Milestone X', 500.00, 'pendiente', 1);
select count(fn_mapeo_confirmar('tipo_proyecto', null));
select fn_emision_config(jsonb_build_object('corte', fn_fecha_miami(now())::text,
         'empresa', jsonb_build_object('nombre', 'ZZ Electric C11 CONCURRENCIA, Inc.'),
         'como_pagar', 'Check payable to ZZ Electric C11 CONCURRENCIA, Inc.'))->>'corte';
select fn_emision_obra('{"proyecto_id": "c11-conc-a", "retencion_pct": 10}')->'retencion'->>'pct';
select count(fn_emision_obra(jsonb_build_object('proyecto_id', 'c11-conc-b' || g, 'retencion_pct', 10))) from generate_series(1, 8) g;
SQL

# Como producción: los índices únicos de facturas por hito y el candado de
# borrado de Storage (son de la app y de Supabase: 06-produccion-facturas.sql).
REPLICA=("$DIR/06-produccion-facturas.sql"); con_replica=1
if [ "${SIN_REPLICA:-0}" = "1" ]; then REPLICA=(); con_replica=0; fi

echo "== Base $BD: c1 + c2 + c3 $([ $con_replica = 1 ] && echo "+ lo de producción en facturas y Storage (06) ")+ c11 y lo de este script"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  ${REPLICA[@]+"${REPLICA[@]}"} "$DOCS/c11-emision.sql" "$TMP/montar.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }
revisa "la base tiene los índices únicos de facturas por hito de producción (o se pidió sin ellos)" "$([ $con_replica = 1 ] && echo 2 || echo 0)" \
  "$(ed -c "select count(*) from pg_indexes where schemaname = 'public' and tablename = 'facturas' and indexname in ('ux_facturas_hito', 'ux_facturas_hito_viva')")"

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
echo "== 3. Ocho emisiones a la vez (ocho obras), y una que falla después de tomar su número"
declare -a DOC=() VIS=()
for g in 1 2 3 4 5 6 7 8; do
  DOC[$g]="$(borrador "$(hito "B$g")")"; VIS[$g]="$(visto "${DOC[$g]}")"
done
HX="$(ed -c "select id from hitos where titulo = 'C11 CONC Milestone X'")"; DX="$(borrador "$HX")"; VX="$(visto "$DX")"
# el libro no va a aceptar la factura de la obra X: la cuenta de ingreso de su tipo (comercial), inactiva. El borrador no lo
# sabe (su regla de ingreso está confirmada): la emisión toma su número, el puente de c3 no la asienta, y todo se deshace.
ed -c "update cuentas set activa = false where codigo = (select cuenta from mapeo_tipo_proyecto where tipo = 'comercial')" > /dev/null
N0="$(contador)"
for g in 1 2 3 4 5 6 7 8; do
  emitir "$TMP/3-$g.out" "${DOC[$g]}" "${VIS[$g]}" 0.2 &
  [ "$g" = "4" ] && { emitir "$TMP/3-x.out" "$DX" "$VX" 0.2 & }
done
wait
revisa "las ocho emiten" "8" "$(cat "$TMP"/3-[0-9]*.out | grep -c 'RESULTADO [A-Z0-9]*-[0-9]*-[0-9]*')"
revisa "la que el libro no acepta: MX008 (dice por qué), sin gastar número, y sigue en borrador" "1|borrador|0" \
  "$(grep -c 'MX008: No se emitió nada (ni se gastó el número .*): el libro no aceptó la factura.*inactiva' "$TMP/3-x.out")|$(ed -c "select estado from emision_documentos where id = '$DX'")|$(ed -c "select count(*) from facturas where proyecto_id = 'c11-conc-x'")"
revisa "ocho números seguidos, sin huecos ni repetidos, y el contador en el último" "8|$((N0 + 1))|$((N0 + 8))|$((N0 + 8))|8" \
  "$(ed -c "select format('%s|%s|%s|%s|%s', count(*), min(s.secuencia), max(s.secuencia), (select ultimo from contadores where serie = 'facturas-$ANIO'), count(distinct s.numero))
              from emision_serie s where s.anio = $ANIO and s.secuencia > $N0")"
revisa "ocho facturas, cada una con su asiento al centavo (lo que se paga + lo retenido = su monto)" "8|8" \
  "$(ed -c "select format('%s|%s', count(*), count(*) filter (where s.cxc = d.a_pagar and s.retencion = d.retencion and d.a_pagar + d.retencion = d.monto and d.retencion > 0))
              from emision_documentos d cross join lateral fn_emision_saldo(d.factura_id) s
             where d.estado = 'emitida' and d.secuencia > $N0 and d.factura_id is not null")"
revisa "nadie murió por un bloqueo mortal (40P01) ni por el tope de la API" "0" "$(cat "$TMP"/3-*.out | grep -c '40P01\|deadlock\|57014')"
ed -c "update cuentas set activa = true where codigo = (select cuenta from mapeo_tipo_proyecto where tipo = 'comercial')" > /dev/null

echo
echo "== 3b. Dos emisiones a la vez en la MISMA obra (dos hitos)"
H12="$(hito 12)"; D12="$(borrador "$H12")"; V12="$(visto "$D12")"
H13="$(hito 13)"; D13="$(borrador "$H13")"; V13="$(visto "$D13")"
N1="$(contador)"
emitir "$TMP/3b-1.out" "$D12" "$V12" 0.6 &
sleep 0.15
emitir "$TMP/3b-2.out" "$D13" "$V13" 0 &
wait
revisa "la primera emite" "1" "$(grep -c 'RESULTADO [A-Z0-9]*-[0-9]*-[0-9]*' "$TMP/3b-1.out")"
revisa "la segunda espera y, cuando le toca, ya no es lo que se vio: MX011, sin número y en borrador" "1|borrador|$((N1 + 1))" \
  "$(grep -c 'MX011: El borrador ya no es el que viste' "$TMP/3b-2.out")|$(ed -c "select estado from emision_documentos where id = '$D13'")|$(contador)"
V13="$(visto "$D13")"
emitir "$TMP/3b-3.out" "$D13" "$V13" 0
revisa "refrescada (con lo que se ve ahora), emite con el número siguiente, como la tercera factura de la obra" "1|$((N1 + 2))|3" \
  "$(grep -c 'RESULTADO [A-Z0-9]*-[0-9]*-[0-9]*' "$TMP/3b-3.out")|$(contador)|$(ed -c "select contenido->>'ordinal' from emision_documentos where id = '$D13'")"
revisa "nadie murió por un bloqueo mortal (40P01) ni por el tope de la API" "0" "$(cat "$TMP"/3b-*.out | grep -c '40P01\|deadlock\|57014')"

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
echo "== 4b. Volver a facturar ese hito, «Emitir» desde dos pestañas a la vez (hay una anulada que soltar)"
F1="$(ed -c "select factura_id from emision_documentos where id = '$D1'")"
NA="$(ed -c "select count(*) from asientos")"
D1B="$(borrador "$H1")"; V1B="$(visto "$D1B")"
revisa "el borrador de la buena avisa de la anulada, sin frenar, y se puede emitir" "1|true" \
  "$(ed -c "select format('%s|%s', (select count(*) from jsonb_array_elements(x.d->'avisos') a where a->>'codigo' = 'hito_factura_anulada' and not (a->>'frena')::boolean), x.d->>'puede_emitir')
              from (select fn_emision_documento('$D1B') as d) x")"
emitir "$TMP/4b-a.out" "$D1B" "$V1B" 0.6 &
sleep 0.15
emitir "$TMP/4b-b.out" "$D1B" "$V1B" 0 &
wait
revisa "una emite" "1" "$(cat "$TMP"/4b-a.out "$TMP"/4b-b.out | grep -c 'RESULTADO [A-Z0-9]*-[0-9]*-[0-9]*')"
revisa "la otra, MX008 (ese borrador ya se emitió)" "1" "$(cat "$TMP"/4b-a.out "$TMP"/4b-b.out | grep -c 'MX008: Ese borrador ya se emitió')"
revisa "la anulada soltó el hito y sigue anulada, con su nota de crédito" "anulada|sin hito|1" \
  "$(ed -c "select format('%s|%s|%s', f.estado, case when f.hito_id is null then 'sin hito' else 'CON hito' end,
                          (select count(*) from notas_credito n where n.anula_a = f.id)) from facturas f where f.id = $F1")"
revisa "una sola fila de facturas con ese hito, la viva, del borrador nuevo; el hito facturado" "1|emitida|t|facturado" \
  "$(ed -c "select format('%s|%s|%s|%s', count(*), min(f.estado), bool_and(f.id = (select factura_id from emision_documentos where id = '$D1B')),
                          (select estado from hitos where id = $H1)) from facturas f where f.hito_id = $H1")"
revisa "lo soltado, apuntado una sola vez: la anulada, su hito y el documento que la soltó" "1|1" \
  "$(ed -c "select format('%s|%s', count(*), count(*) filter (where s.factura_id = $F1 and s.hito_id = $H1 and s.documento_id = '$D1B' and s.de_la_app))
              from emision_soltados s")"
revisa "el libro solo ganó el asiento de la nueva (la anulada no se asentó otra vez)" "$((NA + 1))" "$(ed -c "select count(*) from asientos")"
revisa "nadie murió por un bloqueo mortal (40P01), ni chocó con el índice, ni por el tope de la API" "0" \
  "$(cat "$TMP"/4b-*.out | grep -c '40P01\|deadlock\|23505\|57014')"

if [ $con_replica = 1 ]; then
echo
echo "== 4c. La app y QuickBooks a la vez, el mismo hito (con los índices únicos de producción)"
H14="$(hito 14)"; D14="$(borrador "$H14")"; V14="$(visto "$D14")"
N4="$(contador)"
# por fuera (como la función de QuickBooks: su fila de facturas con el hito), sin confirmar durante un segundo
( ed -v ON_ERROR_STOP=1 -c "begin; insert into facturas (proyecto_id, num, fecha, monto, pagada, hito_id, qb_id) values ('c11-conc-a', 'ZZ-QB-CONC-14', fn_fecha_miami(now()), 1005.18, false, $H14, 'ZZ-QBID-CONC-14'); select 'RESULTADO fuera'; select pg_sleep(1); commit;" > "$TMP/4c-q.out" 2>&1 ) &
sleep 0.3
t0=$(date +%s.%N)
emitir "$TMP/4c-a.out" "$D14" "$V14" 0
t1=$(date +%s.%N)
wait
revisa "la de fuera entra" "1" "$(grep -c 'RESULTADO fuera' "$TMP/4c-q.out")"
revisa "la app esperó a la otra (más de medio segundo) y paró en llano (MX011: ya no es lo que viste), sin chocar con el índice" "1|1|0" \
  "$(echo "$t1 - $t0 > 0.5" | bc)|$(grep -c 'MX011: El borrador ya no es el que viste' "$TMP/4c-a.out")|$(grep -c '23505\|duplicate key\|ux_facturas\|40P01\|deadlock\|57014' "$TMP/4c-a.out")"
revisa "sin gastar número, el borrador sigue en borrador y hay una sola factura de ese hito (la de fuera)" "$N4|borrador|1|ZZ-QB-CONC-14" \
  "$(contador)|$(ed -c "select estado from emision_documentos where id = '$D14'")|$(ed -c "select count(*) || '|' || min(num) from facturas where hito_id = $H14")"
revisa "y el borrador, al mirarlo otra vez, ya lo frena (el hito ya se facturó)" "1|false" \
  "$(ed -c "select format('%s|%s', (select count(*) from jsonb_array_elements(x.d->'avisos') a where a->>'codigo' = 'hito_facturado' and (a->>'frena')::boolean), x.d->>'puede_emitir')
              from (select fn_emision_documento('$D14') as d) x")"
fi

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
revisa "sin nadie leyendo, entra (y no pisa nada: las mismas facturas y la misma serie)" "0|11" \
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

if [ "${SIN_PRUEBAS:-0}" != "1" ]; then
PRUEBAS="${C11_PRUEBAS:-$DOCS/c11-pruebas.sql}"
# (lo que correr.sh corre, en la misma sesión, después de un c*-pruebas.sql)
cat > "$TMP/resumen.sql" <<'SQL'
\o
\pset footer off
\pset null '-'
\echo
select n, case ok when true then 'ok' when false then 'FALLA' else 'omitida' end as resultado, prueba, esperado, obtenido
  from _pruebas order by n;
\pset tuples_only on
\pset format unaligned
select format('PRUEBAS total=%s ok=%s fallan=%s omitidas=%s', count(*), count(*) filter (where ok), count(*) filter (where not ok),
              count(*) filter (where ok is null))
  from _pruebas;
SQL
# suite <salida>: el archivo de pruebas entero, como el SQL Editor (una transacción)
suite() {
  PGPASSWORD=editor_sql psql -X -q -U editor_sql -v ON_ERROR_STOP=1 -1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -d "$BD" \
    -c '\o /dev/null' -f "$PRUEBAS" -f "$TMP/resumen.sql" > "$1" 2>&1
}
ahora() { date +%s.%N; }
fallan() { sed -n 's/^PRUEBAS .* fallan=\([0-9]*\) .*/\1/p' "$1" | tail -n 1; }

echo
echo "== 7. c11-pruebas.sql con la app usando Storage (una lectura de sus archivos, abierta en otra sesión mientras corre)"
# la «app»: una transacción que leyó storage.objects y sigue abierta hasta que se la corta (un respaldo, una sesión colgada)
( ed -c "begin; select count(*) from storage.objects; select pg_sleep(300); commit;" > "$TMP/7-larga.out" 2>&1 ) &
sleep 1
t0=$(ahora)
( suite "$TMP/7-suite.out" ) &
SUITE=$!
# mientras corre: cada segundo, una lectura de Storage como las de la app (con tope de 5 s); se guarda la que más tardó
max=0
while kill -0 $SUITE 2>/dev/null; do
  a=$(ahora)
  ed -c "set statement_timeout = '5s'; select count(*) from storage.objects" > /dev/null 2>&1
  d=$(echo "$(ahora) - $a" | bc)
  [ "$(echo "$d > $max" | bc)" = "1" ] && max=$d
  [ "$(echo "$(ahora) - $t0 > 90" | bc)" = "1" ] && break
  sleep 1
done
sola=1; kill -0 $SUITE 2>/dev/null && sola=0
# se corta la lectura larga (si la corrida la estaba esperando, sigue desde aquí)
ed -c "select count(pg_terminate_backend(pid)) from pg_stat_activity where datname = current_database() and pid <> pg_backend_pid() and query like '%pg_sleep(300)%'" > /dev/null 2>&1
wait
echo "     (la corrida tardó $(echo "$(ahora) - $t0" | bc | cut -c1-5) s; la lectura de Storage que más esperó, $(echo "$max" | cut -c1-5) s; $(grep '^PRUEBAS' "$TMP/7-suite.out" | tail -n 1))"
revisa "la corrida terminó sola, sin esperar a que la otra sesión soltara los archivos" "1" "$sola"
revisa "mientras corría, ninguna lectura de archivos de la app esperó más de 2 s" "1" "$(echo "$max < 2" | bc)"
revisa "ninguna prueba en falso" "0" "$(fallan "$TMP/7-suite.out")"
revisa "la 46 probó su primera mitad y dice por qué no la segunda (la app tenía tomada la tabla de los archivos)" "1" \
  "$(grep -c '^ *46 | ok .*(aquí, solo lo primero: la app (u otra sesión) estaba usando los archivos de Storage y no soltó la tabla en medio segundo' "$TMP/7-suite.out")"

echo
echo "== 8. c11-pruebas.sql con la app escribiendo en facturas, en una base sin el índice que cuenta las anuladas"
# (el día que la otra sesión quite ux_facturas_hito: se quita de ESTA base de prueba; el de las vivas, si estaba, queda)
ed -c "drop index if exists public.ux_facturas_hito" > /dev/null 2>&1
FX="$(ed -c "select min(id) from facturas")"; FY="$(ed -c "select max(id) from facturas")"
IDX0="$(ed -c "select count(*) from pg_index where indrelid = 'public.facturas'::regclass")"
revisa "esta base no tiene ningún índice único de facturas por hito que cuente las anuladas" "0" \
  "$(ed -c "select count(*) from pg_index i where i.indrelid = 'public.facturas'::regclass and i.indisunique and i.indnkeyatts = 1
              and i.indkey[0] = (select attnum from pg_attribute where attrelid = i.indrelid and attname = 'hito_id')
              and coalesce(pg_get_expr(i.indpred, i.indrelid), '') !~* '\\mestado\\M'")"
# la «app»: una transacción que escribió en una factura (la más vieja) y sigue abierta hasta que se la corta
( ed -c "begin; update facturas set pagada = pagada where id = $FX; select pg_sleep(301); commit;" > "$TMP/8-larga.out" 2>&1 ) &
sleep 1
t0=$(ahora)
( suite "$TMP/8-suite.out" ) &
SUITE=$!
# mientras corre: cada medio segundo, una escritura inocua en OTRA factura que no es de las pruebas (con tope de 5 s); se
# guarda la que más tardó
max=0
while kill -0 $SUITE 2>/dev/null; do
  a=$(ahora)
  ed -c "set statement_timeout = '5s'; update facturas set pagada = pagada where id = $FY" > "$TMP/8-w.out" 2>&1
  d=$(echo "$(ahora) - $a" | bc)
  [ "$(echo "$d > $max" | bc)" = "1" ] && max=$d
  [ "$(echo "$(ahora) - $t0 > 90" | bc)" = "1" ] && break
  sleep 0.5
done
sola=1; kill -0 $SUITE 2>/dev/null && sola=0
ed -c "select count(pg_terminate_backend(pid)) from pg_stat_activity where datname = current_database() and pid <> pg_backend_pid() and query like '%pg_sleep(301)%'" > /dev/null 2>&1
wait
echo "     (la corrida tardó $(echo "$(ahora) - $t0" | bc | cut -c1-5) s; la escritura en facturas que más esperó, $(echo "$max" | cut -c1-5) s; $(grep '^PRUEBAS' "$TMP/8-suite.out" | tail -n 1))"
revisa "la corrida terminó sola, sin esperar a que la otra sesión soltara facturas" "1" "$sola"
revisa "mientras corría, ninguna escritura de la app en otra factura esperó más de 2 s" "1" "$(echo "$max < 2" | bc)"
revisa "ninguna prueba en falso; y la 52, la 53 y la 54 corrieron con el índice que la base tiene (ninguna omitida)" "0|3" \
  "$(fallan "$TMP/8-suite.out")|$(grep -c '^ *5[234] | ok ' "$TMP/8-suite.out")"
revisa "a facturas no le quedó ningún índice de más" "$IDX0" "$(ed -c "select count(*) from pg_index where indrelid = 'public.facturas'::regclass")"
# (de vuelta, como producción hoy)
[ $con_replica = 1 ] && ed -c "create unique index if not exists ux_facturas_hito on public.facturas (hito_id) where hito_id is not null" > /dev/null 2>&1
fi

echo
echo "== Al final"
revisa "v_emision_control: ningún cuadre en rojo" "0" "$(ed -c "select count(*) from v_emision_control where not ok and nivel = 'cuadre'")"
revisa "cada número de la serie de las facturas es una fila de facturas (ninguno dos veces)" "0|0" \
  "$(ed -c "select format('%s|%s', (select count(*) from emision_serie s where s.serie = 'facturas' and not exists (select 1 from facturas f where f.num = s.numero)),
                          (select count(*) from (select num from facturas group by num having count(*) > 1) x))")"
revisa "la serie del año, seguida desde el 1, sin repetidos, y el contador en el último" "1" \
  "$(ed -c "select (min(s.secuencia) = 1 and max(s.secuencia) = count(*) and count(distinct s.numero) = count(*)
                    and max(s.secuencia) = (select ultimo from contadores where serie = 'facturas-$ANIO'))::int
              from emision_serie s where s.anio = $ANIO")"
revisa "cada número, de una factura emitida; y trece facturas emitidas por la app (una, anulada)" "0|13|1" \
  "$(ed -c "select format('%s|%s|%s', (select count(*) from emision_serie s where not exists (select 1 from emision_documentos d where d.id = s.documento_id and d.estado = 'emitida' and d.numero = s.numero)),
                          (select count(*) from emision_documentos where estado = 'emitida'), (select count(*) from emision_documentos where anulado_el is not null))")"
revisa "ningún hito con dos filas de facturas, y lo soltado sigue siendo un apunte (volver a pegar no lo toca)" "0|1" \
  "$(ed -c "select format('%s|%s', (select count(*) from (select hito_id from facturas where hito_id is not null group by hito_id having count(*) > 1) x),
                          (select count(*) from emision_soltados))")"
revisa "la cadena del libro, sin rojos (los permisos también)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"

echo
if [ $malos -eq 0 ]; then echo "c11-concurrencia: todo bien"; else echo "c11-concurrencia: ALGO FALLA"; fi
exit $malos
