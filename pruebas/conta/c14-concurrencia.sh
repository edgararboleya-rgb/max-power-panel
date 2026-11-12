#!/usr/bin/env bash
# =====================================================================
# c14-concurrencia.sh — lo que c14-pruebas.sql no puede probar: dos
# sesiones A LA VEZ con los subs (W-9, COI y 1099). c14-pruebas corre en una
# sola sesión; aquí se abren varias de verdad, y cada una confirma.
#
#   ./c14-concurrencia.sh [nombre_bd]      (por defecto c14_concurrencia)
#
# Crea su base con c1 + c2 + c3 + c14 (los subs no necesitan más), dos
# proveedores, dos fichas y un pago sin nombre, y:
#   1. DECIR DE QUIÉN ES EL MISMO PAGO desde dos pestañas a la vez (con notas
#      distintas): entran las dos, una detrás de otra (el candado de esa
#      línea); queda UNA marca viva —la última en entrar— y la otra como
#      rastro. Antes la segunda recibía un 23505 en crudo («duplicate key …
#      subs_marcas_viva»).
#   2. ENLAZAR EL MISMO TERCERO A DOS FICHAS a la vez: una entra; la otra,
#      MX008 en llano («ya está en la ficha de …: un tercero, una ficha»).
#      Antes, 23505 en crudo («subs_terceros_pk»).
#   3. DOS ALTAS DE FICHA CON EL MISMO TERCERO a la vez: una ficha; la otra,
#      MX008, y de ella no queda nada a medias.
#   4. EL MISMO TIN (de mentira) EN DOS FICHAS a la vez: una lo guarda; la
#      otra, MX008 («ese TIN ya está en la ficha de …»). El TIN no sale en
#      ninguno de los dos mensajes.
#   5. CAMBIAR «SE LE REPORTA» DE LA MISMA FICHA desde dos pestañas a la vez
#      (con pagos ya hechos y el mismo «desde»): entran las dos, en orden;
#      queda UN tramo (el estatus de antes, hasta la víspera), no dos.
#   6. MARCAR Y QUITAR LA MARCA de la misma línea a la vez: gana una y la
#      otra entra después o dice MX008; nunca dos marcas vivas.
# Y comprueba al final: una marca viva por línea, un tercero en una sola
# ficha, un TIN en una sola ficha, un tramo vivo por ficha y fecha, ningún
# 23505 ni 40P01 en ninguna salida, la cadena del libro en verde y los
# cuadres del control de los subs en verde.
#
# Cada sesión va como la app por PostgREST: el dueño, con el rol
# authenticated, en aal2, los ajustes de ese rol y el tope de la API (8 s).
# Nombres y TIN inventados («ZZ C14 CONC», 000-00-0001): nada de producción.
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c14_concurrencia}"
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

echo "== Base $BD: c1 + c2 + c3 + c14"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c14-subs.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
HOY="$(ed -c "select fn_fecha_miami(now())")"
# (el día de los pagos de prueba: el primero del mes abierto más viejo que ya empezó; «desde» será el día siguiente)
DIA="$(ed -c "select p.desde from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.desde < fn_fecha_miami(now()) order by p.desde limit 1")"
OBRA="$(ed -c "select id from proyectos order by id limit 1")"
[ -n "$DIA" ] && [ -n "$OBRA" ] || { echo "No hay un mes abierto ya empezado, o no hay obras: no hay dónde postear" >&2; exit 2; }
DESDE="$(ed -c "select (date '$DIA' + 1)::text")"

# Como la app por PostgREST: con el rol authenticated, los ajustes de ese
# rol y el tope de la API (8 s). app <quién>.
app() {
  echo "select set_config('request.jwt.claims', '{\"sub\":\"$1\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"
}
# dueno <salida> <sql que devuelve un texto> [pausa con la transacción abierta]
dueno() {
  ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO ' || ($2); select pg_sleep(${3:-0}); commit;" > "$1" 2>&1
}
# dos <nombre> <sql de la pestaña A (se queda 0,6 s con la transacción abierta)> <sql de la pestaña B (entra 0,15 s después)>
dos() {
  dueno "$TMP/$1a.out" "$2" 0.6 &
  sleep 0.15
  dueno "$TMP/$1b.out" "$3" 0 &
  wait
}
entran()  { cat "$TMP/$1a.out" "$TMP/$1b.out" | grep -c 'RESULTADO'; }
con()     { cat "$TMP/$1a.out" "$TMP/$1b.out" | grep -c "$2"; }

# La escena (confirmada): dos proveedores, dos fichas, un pago sin nombre y un pago a un sub con ficha.
PA="$(ed -c "select fn_proveedor_alta('ZZ C14 CONC A', 'Net 30', array['zz c14 conc a'])")"
PB="$(ed -c "select fn_proveedor_alta('ZZ C14 CONC B', 'Net 30', array['zz c14 conc b'])")"
PC="$(ed -c "select fn_proveedor_alta('ZZ C14 CONC C', 'Net 30', array['zz c14 conc c'])")"
dueno "$TMP/0f1.out" "fn_subs_ficha('{\"nombre_legal\": \"ZZ C14 Conc Uno\", \"tipo_entidad\": \"individual\"}')->>'ficha_id'"
dueno "$TMP/0f2.out" "fn_subs_ficha('{\"nombre_legal\": \"ZZ C14 Conc Dos\", \"tipo_entidad\": \"individual\"}')->>'ficha_id'"
dueno "$TMP/0f3.out" "fn_subs_ficha('{\"nombre_legal\": \"ZZ C14 Conc Tres\", \"tipo_entidad\": \"individual\", \"reporta\": \"si\", \"tercero\": {\"tipo\": \"proveedor\", \"id\": \"$PC\"}}')->>'ficha_id'"
F1="$(sed -n 's/^RESULTADO //p' "$TMP/0f1.out")"; F2="$(sed -n 's/^RESULTADO //p' "$TMP/0f2.out")"; F3="$(sed -n 's/^RESULTADO //p' "$TMP/0f3.out")"
dueno "$TMP/0a.out" "fn_postear('{\"fecha\": \"$DIA\", \"descripcion\": \"ZZ C14 CONC: un Zelle sin nombre\", \"lineas\": [{\"cuenta\": \"5200\", \"monto\": \"700.00\", \"proyecto_id\": \"$OBRA\"}, {\"cuenta\": \"1010\", \"monto\": \"-700.00\"}]}')->>'id'"
AS="$(sed -n 's/^RESULTADO //p' "$TMP/0a.out")"
dueno "$TMP/0b.out" "fn_postear('{\"fecha\": \"$DIA\", \"descripcion\": \"ZZ C14 CONC: un pago al sub Tres\", \"lineas\": [{\"cuenta\": \"5200\", \"monto\": \"900.00\", \"proyecto_id\": \"$OBRA\", \"tercero_tipo\": \"proveedor\", \"tercero_id\": \"$PC\"}, {\"cuenta\": \"1010\", \"monto\": \"-900.00\"}]}')->>'id'"
revisa "la escena: tres fichas, un pago sin nombre y un pago a un sub con ficha" "3|2" \
  "$(ed -c "select (select count(*) from subs_fichas where nombre_legal like 'ZZ C14 Conc%') || '|' || (select count(*) from asientos where descripcion like 'ZZ C14 CONC:%')")"
[ -n "$F1" ] && [ -n "$F2" ] && [ -n "$F3" ] && [ -n "$AS" ] || { cat "$TMP"/0*.out | grep ERROR | head -5; echo "FALLÓ la escena" >&2; exit 2; }

echo
echo "== 1. Decir de quién es el mismo pago desde dos pestañas a la vez"
dos 1 "fn_subs_marcar('$AS', 1, '{\"ficha\": \"$F1\", \"nota\": \"ZZ C14 CONC: pestaña A\"}')->'marca'->>'id'" \
      "fn_subs_marcar('$AS', 1, '{\"ficha\": \"$F1\", \"nota\": \"ZZ C14 CONC: pestaña B\"}')->'marca'->>'id'"
revisa "entran las dos, una detrás de otra, sin ningún 23505" "2|0|0" "$(entran 1)|$(con 1 'ERROR')|$(con 1 '23505')"
revisa "una marca viva (la de la pestaña B) y la otra como rastro" "1|1|pestaña B" \
  "$(ed -c "select count(*) filter (where retirada_el is null) || '|' || count(*) filter (where retirada_el is not null)
                   || '|' || max(substring(nota from 'pestaña [AB]')) filter (where retirada_el is null)
              from subs_marcas where asiento_id = '$AS' and orden = 1")"

echo
echo "== 2. Enlazar el mismo tercero a dos fichas a la vez"
dos 2 "fn_subs_tercero('$F1', 'proveedor', '$PA')->>'ficha'" "fn_subs_tercero('$F2', 'proveedor', '$PA')->>'ficha'"
revisa "una entra; la otra, MX008 en llano («un tercero, una ficha»), sin 23505" "1|1|1|0" \
  "$(entran 2)|$(con 2 'MX008')|$(con 2 'un tercero, una ficha')|$(con 2 '23505')"
revisa "ese tercero, en una sola ficha (la de quien entró primero)" "1|ZZ C14 Conc Uno" \
  "$(ed -c "select count(*) || '|' || max(f.nombre_legal) from subs_terceros t join subs_fichas f on f.id = t.ficha_id where t.tercero_id = '$PA'")"

echo
echo "== 3. Dos altas de ficha con el mismo tercero a la vez"
dos 3 "fn_subs_ficha('{\"nombre_legal\": \"ZZ C14 Conc Alta A\", \"tercero\": {\"tipo\": \"proveedor\", \"id\": \"$PB\"}}')->>'ficha_id'" \
      "fn_subs_ficha('{\"nombre_legal\": \"ZZ C14 Conc Alta B\", \"tercero\": {\"tipo\": \"proveedor\", \"id\": \"$PB\"}}')->>'ficha_id'"
revisa "una ficha; la otra, MX008 en llano, sin 23505" "1|1|0" "$(entran 3)|$(con 3 'MX008')|$(con 3 '23505')"
revisa "de la que no entró no queda nada a medias: una ficha «Alta», con su tercero" "1|1" \
  "$(ed -c "select (select count(*) from subs_fichas where nombre_legal like 'ZZ C14 Conc Alta%') || '|' || (select count(*) from subs_terceros where tercero_id = '$PB')")"

echo
echo "== 4. El mismo TIN (de mentira) en dos fichas a la vez"
dos 4 "fn_subs_tin_guardar('$F1', '{\"tin\": \"000-00-0001\"}')->>'guardado'" "fn_subs_tin_guardar('$F2', '{\"tin\": \"000-00-0001\"}')->>'guardado'"
revisa "una lo guarda; la otra, MX008 («ese TIN ya está en la ficha de …»), sin 23505" "1|1|1|0" \
  "$(entran 4)|$(con 4 'MX008')|$(con 4 'Ese TIN ya está en la ficha de')|$(con 4 '23505')"
revisa "ese TIN, en una sola ficha; y no sale en ninguno de los dos mensajes" "1|0" \
  "$(ed -c "select count(*) from subs_fichas where tin_ultimos4 = '0001' and nombre_legal like 'ZZ C14 Conc%'")|$(con 4 '000-00-0001')"

echo
echo "== 5. Cambiar «se le reporta» de la misma ficha desde dos pestañas a la vez (con pagos ya hechos)"
dueno "$TMP/5x.out" "fn_subs_ficha('{\"id\": \"$F3\", \"reporta\": \"no\", \"reporta_nota\": \"ZZ C14 CONC: sin decir desde cuándo\"}')->>'ficha_id'"
revisa "sin decir desde cuándo, la base lo pide (MX008, con lo pagado y el día mínimo)" "1|1" \
  "$(grep -c 'MX008' "$TMP/5x.out")|$(grep -c 'ya tiene pagos con lo de antes' "$TMP/5x.out")"
dos 5 "fn_subs_ficha('{\"id\": \"$F3\", \"reporta\": \"no\", \"reporta_nota\": \"ZZ C14 CONC: pestaña A\", \"desde\": \"$DESDE\"}')->>'ficha_id'" \
      "fn_subs_ficha('{\"id\": \"$F3\", \"reporta\": \"no\", \"reporta_nota\": \"ZZ C14 CONC: pestaña B\", \"desde\": \"$DESDE\"}')->>'ficha_id'"
revisa "entran las dos, en orden, sin 23505" "2|0|0" "$(entran 5)|$(con 5 'ERROR')|$(con 5 '23505')"
revisa "queda UN tramo (lo de antes, «sí», hasta la víspera), y la ficha en «no» con la nota de la última" "1|si|$DIA|no|pestaña B" \
  "$(ed -c "select (select count(*) from subs_tramos t where t.ficha_id = '$F3' and t.retirado_el is null)
                   || '|' || (select max(t.reporta) from subs_tramos t where t.ficha_id = '$F3' and t.retirado_el is null)
                   || '|' || (select max(t.hasta)::text from subs_tramos t where t.ficha_id = '$F3' and t.retirado_el is null)
                   || '|' || (select f.reporta || '|' || substring(f.reporta_nota from 'pestaña [AB]') from subs_fichas f where f.id = '$F3')")"
revisa "y su pago de antes del cambio sigue contando con el estatus de entonces (900 reportables)" "900.00" \
  "$(ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'R ' || coalesce((select r.reportable::text from fn_subs_1099(extract(year from date '$DIA')::int) r where r.ficha_id = '$F3'), 'no sale'); commit;" 2>&1 | sed -n 's/^R //p')"

echo
echo "== 6. Marcar y quitar la marca de la misma línea a la vez"
dos 6 "fn_subs_marcar('$AS', 1, '{\"ficha\": \"$F2\", \"nota\": \"ZZ C14 CONC: ahora es del Dos\"}')->'marca'->>'id'" \
      "coalesce(fn_subs_marcar('$AS', 1, '{\"quitar\": true}')->>'quitada', 'no había')"
revisa "ninguna muere por un 23505 ni por un bloqueo mortal" "0|0" "$(con 6 '23505')|$(con 6 '40P01\|deadlock')"
revisa "nunca dos marcas vivas de esa línea" "sí" \
  "$(ed -c "select case when count(*) filter (where retirada_el is null) <= 1 then 'sí' else 'NO: ' || count(*) filter (where retirada_el is null) end
              from subs_marcas where asiento_id = '$AS' and orden = 1")"

echo
echo "== Al final"
revisa "una marca viva por línea, un tercero en una sola ficha, un TIN en una sola ficha, un tramo vivo por ficha y fecha" "0|0|0|0" \
  "$(ed -c "select (select count(*) from (select 1 from subs_marcas where retirada_el is null group by asiento_id, orden having count(*) > 1) z)
                   || '|' || (select count(*) from (select 1 from subs_terceros group by tercero_tipo, tercero_id having count(*) > 1) z)
                   || '|' || (select count(*) from (select 1 from subs_tin group by tin having count(*) > 1) z)
                   || '|' || (select count(*) from (select 1 from subs_tramos where retirado_el is null group by ficha_id, hasta having count(*) > 1) z)")"
revisa "ningún 23505 ni 40P01 en ninguna salida" "0" "$(cat "$TMP"/[1-6]*.out | grep -c '23505\|40P01\|deadlock')"
revisa "la cadena del libro, sin rojos (los permisos también)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"
revisa "los cuadres del control de los subs, en verde" "0" \
  "$(ed -c "select count(*) from fn_subs_control(extract(year from date '$DIA')::int) where nivel = 'cuadre' and not ok")"

echo
if [ $malos -eq 0 ]; then echo "c14-concurrencia: todo bien"; else echo "c14-concurrencia: ALGO FALLA"; fi
exit $malos
