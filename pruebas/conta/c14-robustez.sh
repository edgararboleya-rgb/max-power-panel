#!/usr/bin/env bash
# =====================================================================
# c14-robustez.sh — lo que c14-pruebas.sql no puede ver corriendo sobre una
# base limpia y completa: que la capa de los subs (c14: W-9, COI y 1099) y su
# suite VALEN SOBRE BASES DISTINTAS de la del banco de pruebas. Cada caso es
# uno que rompió algo mientras se escribía la capa.
#
#   ./c14-robustez.sh [nombre_bd]      (por defecto c14_robustez)
#
# 1. LA CADENA MÍNIMA: c1 + c2 + c3 y nada más (ni banco, ni jornal, ni
#    cierre, ni Stripe). c14 se pega (dos veces): no pide ninguna de ellas, y
#    su configuración nace solo con cuentas que existen en ese plan. La suite
#    corre: lo que necesita el banco (c6), el jornal (c10) o el cierre (c9)
#    sale «omitida» diciéndolo, y nada falla.
# 2. CON EL BANCO Y EL JORNAL (c4, c6 y c10): la suite dos veces, sin fallos.
# 3. DATOS «COMO PRODUCCIÓN» YA CONFIRMADOS: fichas, un TIN, una marca, una
#    hoja exportada, el umbral del año confirmado en OTRO monto y la
#    configuración cambiada («al exento de WC le basta», otra regla de a quién
#    no se le reporta, otros días). Y MUCHOS: 45 subs, 40 pagos sin nombre y
#    40 pagados por otro camino, para que las listas de los controles no
#    quepan en su detalle («… y N más») y lo de las pruebas quede fuera de
#    ellas. La suite no supone una base vacía ni en verde: sin fallos. Y con
#    «al exento le basta» puesto, quien no tiene COI sigue saliendo.
# 4. EL DÍA 1 DEL MES: el reloj de la base se finge en el primer día del mes
#    de las pruebas (todas sus fechas se juntan en ese día): sin fallos.
# 5. UN AÑO DESPUÉS: el reloj en marzo del año siguiente, con todo lo
#    anterior cerrado (el año en que empezó el libro incluido): sin fallos (lo
#    que necesita un diciembre abierto con su enero sale «omitida»).
# 6. EL PEGADO CON STORAGE OCUPADO: una base nueva (c1 + c2 + c3) y c14
#    pegado MIENTRAS otra sesión lee storage.objects (la app listando o
#    subiendo fotos): el pegado se rinde con 55P03 y NO QUEDA NADA (ni las
#    tablas, ni el bucket con sus candados a medias); sin nadie leyendo,
#    entra entero, con los siete candados del bucket «subs». (Antes entraba
#    con rc=0 y CERO candados: tragaba el 55P03 y dejaba un aviso.)
# 7. EL TIN NO VA AL REGISTRO DEL SERVIDOR: desde el SQL Editor un TIN no se
#    guarda, y la base lo dice SIN un error (un error de Postgres deja la
#    sentencia entera, con el TIN tecleado, en el registro del servidor): la
#    función contesta «no se guardó», el mensaje no lo repite y en el
#    registro no queda ninguna línea con ese TIN. Lo mismo si se teclea en
#    otro campo de la ficha, como una clave de más o en «quitar». (El registro
#    se lee solo si se puede: PGLOG, por
#    defecto el del banco de pruebas; si no, esa comprobación se salta y lo
#    dice.)
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base al
# terminar (con CONSERVAR=1 la deja, y sus archivos de salida). Nombres y
# montos inventados; nada de producción.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c14_robustez}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'echo "(La base $BD y $TMP quedan: ./correr.sh --borrar $BD; rm -rf $TMP)"' EXIT
else
  trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

ed() { PGPASSWORD=editor_sql psql -X -q -At -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

# c14-pruebas.sql sobre la base: «fallan=N omitidas=<sus números>» (la tabla
# _pruebas es temporal: se lee en la misma sesión, como correr.sh).
cat > "$TMP/resumen.sql" <<'SQL'
\o
\pset tuples_only on
\pset format unaligned
select format('RESUMEN fallan=%s omitidas=%s', count(*) filter (where ok is false),
              coalesce(string_agg(n::text, ' ' order by n) filter (where ok is null), 'ninguna')) from _pruebas;
select 'FALLA ' || n || ': ' || left(obtenido, 500) from _pruebas where ok is false order by n;
SQL
suite() {  # suite <salida> → la línea RESUMEN
  PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" \
    -c '\o /dev/null' -f "$DOCS/c14-pruebas.sql" -f "$TMP/resumen.sql" > "$1" 2>&1
  grep '^FALLA ' "$1" | cut -c1-600 >&2
  grep -o 'RESUMEN .*' "$1" | sed 's/^RESUMEN //' || echo "no corrió: $(grep -m1 ERROR "$1")"
}

echo "== 1. La cadena mínima: c1 + c2 + c3, y c14 (dos veces)"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c14-subs.sql" "$DOCS/c14-subs.sql" > "$TMP/carga1.out" 2>&1 \
  || { tail -n 30 "$TMP/carga1.out"; echo "FALLÓ la carga" >&2; exit 2; }
revisa "la configuración nace solo con cuentas que existen en ese plan" "0" \
  "$(ed -c "select count(*) from subs_config g, unnest(g.cuentas_por_pagar || g.cuentas_no_pago) c where not exists (select 1 from cuentas k where k.codigo = c)")"
revisa "el control de los subs responde, sin ningún cuadre en rojo" "18 filas, 0 cuadres en rojo" \
  "$(ed -c "select count(*) || ' filas, ' || count(*) filter (where nivel = 'cuadre' and not ok) || ' cuadres en rojo' from fn_subs_control(null)")"
revisa "la suite: nada falla; lo del banco (c6), el jornal (c10) y el cierre (c9) sale omitido" "fallan=0 omitidas=15 16 17 20 23 24 26 28 35 45" "$(suite "$TMP/p1.out")"
revisa "cada omitida dice por qué (la capa que no está)" "10" \
  "$(ed -c "select count(*) from pruebas.c14_resultado where ok is null and obtenido ~ 'omitida: (el banco \(c6\)|el jornal \(c10\)|el cierre \(c9\)) no está en esta base'")"

echo "== 2. Con el banco y el jornal: c4, c6, c10, y c14 (dos veces)"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$DOCS/c10-costo-obra.sql" "$DOCS/c14-subs.sql" "$DOCS/c14-subs.sql" > "$TMP/carga2.out" 2>&1 \
  || { tail -n 30 "$TMP/carga2.out"; echo "FALLÓ la carga" >&2; exit 2; }
revisa "la suite (1ª): nada falla; solo se omite el cierre (c9)" "fallan=0 omitidas=35" "$(suite "$TMP/p2a.out")"
revisa "la suite (2ª): igual" "fallan=0 omitidas=35" "$(suite "$TMP/p2b.out")"

echo "== 3. Datos «como producción», ya confirmados, y muchos"
DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
cat > "$TMP/datos.sql" <<'SQL'
\set ON_ERROR_STOP 1
-- (como el SQL Editor: los proveedores)
select fn_proveedor_alta('ZZ Real Electric Sub', 'Net 30');
do $$ begin for i in 1..45 loop perform fn_proveedor_alta(format('AA Vol Sub %s', lpad(i::text, 2, '0')), 'Net 30'); end loop; end $$;
-- (como el dueño por la API, con su código)
select set_config('request.jwt.claims', json_build_object('sub', :'dueno', 'role', 'authenticated', 'aal', 'aal2')::text, false);
select set_config('request.jwt.claim.sub', :'dueno', false);
select set_config('c14r.obra', (select id from proyectos order by id limit 1), false);
select set_config('c14r.dia', (select least(p.desde + 1, greatest(fn_fecha_miami(now()), p.desde))::text from periodos p
                                where p.tipo = 'mes' and p.estado = 'abierto' and p.desde <= fn_fecha_miami(now()) order by p.desde limit 1), false);
set role authenticated;
do $$
declare
  v_obra text := current_setting('c14r.obra'); v_dia text := current_setting('c14r.dia'); v_anio int := left(current_setting('c14r.dia'), 4)::int;
  v_p uuid; v_f uuid; v_a uuid; i int;
begin
  -- una ficha con su TIN (de mentira), el umbral del año en otro monto y la configuración tocada
  select id into v_p from proveedores where nombre = 'ZZ Real Electric Sub';
  v_f := (fn_subs_ficha(jsonb_build_object('nombre_legal', 'ZZ Real Electric Sub LLC', 'tipo_entidad', 'llc_sociedad', 'reporta', 'si',
            'direccion', '9 Real St', 'ciudad', 'Ocala', 'estado', 'FL', 'zip', '34470',
            'tercero', jsonb_build_object('tipo', 'proveedor', 'id', v_p))) ->> 'ficha_id')::uuid;
  perform fn_subs_tin_guardar(v_f, '{"tin": "00-0000077"}');
  perform fn_subs_umbral_confirmar(v_anio, '600', 'ZZ real: lo dijo el CPA');
  perform fn_subs_config('{"coi_aviso_dias": 21, "coi_exento_basta": true, "entidades_no_reporta": ["c_corp"]}');
  -- sus pagos: al sub (pasa del umbral), uno sin nombre, uno por otro camino
  v_a := (fn_postear(jsonb_build_object('fecha', v_dia, 'descripcion', 'ZZ real: pago al sub', 'lineas', jsonb_build_array(
    jsonb_build_object('cuenta', '5200', 'monto', '1500.00', 'proyecto_id', v_obra, 'tercero_tipo', 'proveedor', 'tercero_id', v_p),
    jsonb_build_object('cuenta', '1010', 'monto', '-1500.00')))) ->> 'id')::uuid;
  perform fn_subs_marcar(v_a, 1, '{"trato": "servicio", "nota": "ZZ real: confirmado"}');
  perform fn_subs_1099_export(v_anio, '{"bajo_umbral": true}');
  -- MUCHOS: 45 subs con un pago (20 sin ficha, 15 con ficha incompleta, 10 por decidir), 40 sin nombre, 40 por otro camino
  for i in 1..45 loop
    select id into v_p from proveedores where nombre = format('AA Vol Sub %s', lpad(i::text, 2, '0'));
    if i > 20 then
      perform fn_subs_ficha(jsonb_build_object('nombre_legal', format('AA Vol Sub %s LLC', lpad(i::text, 2, '0')), 'tipo_entidad', 'llc_un_socio',
                'reporta', case when i > 35 then 'por_decidir' else 'si' end, 'tercero', jsonb_build_object('tipo', 'proveedor', 'id', v_p)));
    end if;
    perform fn_postear(jsonb_build_object('fecha', v_dia, 'descripcion', 'AA vol: pago al sub ' || i, 'lineas', jsonb_build_array(
      jsonb_build_object('cuenta', '5200', 'monto', (700 + i)::text, 'proyecto_id', v_obra, 'tercero_tipo', 'proveedor', 'tercero_id', v_p),
      jsonb_build_object('cuenta', '1010', 'monto', (-(700 + i))::text))));
  end loop;
  for i in 1..40 loop
    perform fn_postear(jsonb_build_object('fecha', v_dia, 'descripcion', 'AA vol: Zelle sin nombre ' || i, 'lineas', jsonb_build_array(
      jsonb_build_object('cuenta', '5200', 'monto', (100 + i)::text, 'proyecto_id', v_obra), jsonb_build_object('cuenta', '1010', 'monto', (-(100 + i))::text))));
    perform fn_postear(jsonb_build_object('fecha', v_dia, 'descripcion', 'AA vol: de su bolsillo ' || i, 'lineas', jsonb_build_array(
      jsonb_build_object('cuenta', '5200', 'monto', (50 + i)::text, 'proyecto_id', v_obra), jsonb_build_object('cuenta', '3100', 'monto', (-(50 + i))::text))));
  end loop;
end $$;
reset role;
SQL
ed -v ON_ERROR_STOP=1 -v dueno="$DUENO" -f "$TMP/datos.sql" > "$TMP/datos.out" 2>&1 \
  || { tail -n 20 "$TMP/datos.out"; echo "FALLÓ la carga de los datos" >&2; exit 2; }
MES="$(ed -c "select p.periodo from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.desde <= fn_fecha_miami(now()) order by p.desde limit 1")"
revisa "las listas de los controles no caben y lo dicen («… y N más»): el 40, el 45 y el 50, y la 160 y la 179 del cierre" "3|2" \
  "$(ed -c "select (select count(*) from fn_subs_control(left('$MES', 4)::int) k where k.orden in (40, 45, 50) and not k.ok and k.detalle ~ '; … y [0-9]+ más')
                   || '|' || (select count(*) from fn_subs_cierre('$MES') k where not k.ok and k.detalle ~ '; … y [0-9]+ más')")"
revisa "con «al exento de WC le basta» puesto, quien no tiene COI sigue saliendo (sí o no, nunca nulo)" "0 nulos, 0 cubiertos" \
  "$(ed -c "select count(*) filter (where k.cubierto is null) || ' nulos, ' || count(*) filter (where k.cubierto) || ' cubiertos' from fn_subs_coi(null, null, null) k")"
revisa "ningún cuadre de los subs en rojo con todo eso" "0" "$(ed -c "select count(*) from fn_subs_control(left('$MES', 4)::int) where nivel = 'cuadre' and not ok")"
G0="$(ed -c "select md5(to_jsonb(g)::text) || '|' || (select count(*) from subs_fichas) || '|' || (select count(*) from subs_historial) || '|' || (select count(*) from asientos) from subs_config g")"
revisa "la suite sobre esos datos (1ª): nada falla" "fallan=0 omitidas=35" "$(suite "$TMP/p3a.out")"
revisa "la suite sobre esos datos (2ª): igual" "fallan=0 omitidas=35" "$(suite "$TMP/p3b.out")"
revisa "y no tocó nada de lo que había (la configuración, las fichas, el historial, los asientos)" "$G0" \
  "$(ed -c "select md5(to_jsonb(g)::text) || '|' || (select count(*) from subs_fichas) || '|' || (select count(*) from subs_historial) || '|' || (select count(*) from asientos) from subs_config g")"

echo "== 4. El día 1 del mes (el reloj de la base, fingido)"
D1="$(ed -c "select p.desde from periodos p where p.periodo = '$MES'")"
ed -v ON_ERROR_STOP=1 -c "create or replace function public.fn_fecha_miami(t timestamptz) returns date language sql stable set search_path = public, pg_temp
                          as \$f\$ select least((t at time zone 'America/New_York')::date, date '$D1') \$f\$" > "$TMP/reloj1.out" 2>&1
revisa "hoy es el día 1 del mes de las pruebas" "$D1" "$(ed -c "select fn_subs_hoy()")"
revisa "la suite el día 1: nada falla (la de los tramos necesita un día anterior a hoy en el mes, y lo dice)" "fallan=0 omitidas=35 39" "$(suite "$TMP/p4.out")"
revisa "y la 39 dice por qué" "1" "$(ed -c "select count(*) from pruebas.c14_resultado where n = 39 and ok is null and obtenido like 'omitida:%'")"

echo "== 5. Un año después: marzo del año siguiente, con todo lo anterior cerrado"
SIG="$(( ${MES%%-*} + 1 ))"
ed -v ON_ERROR_STOP=1 -c "create or replace function public.fn_fecha_miami(t timestamptz) returns date language sql stable set search_path = public, pg_temp
                          as \$f\$ select greatest((t at time zone 'America/New_York')::date, date '$SIG-03-15') \$f\$" \
   -c "alter table public.periodos disable trigger user" \
   -c "update public.periodos set estado = 'cerrado', cerrado_el = now() where hasta < date '$SIG-03-01'" \
   -c "alter table public.periodos enable trigger user" > "$TMP/reloj2.out" 2>&1
revisa "hoy es marzo de $SIG, y el mes de las pruebas es $SIG-03" "$SIG-03-15|$SIG-03" \
  "$(ed -c "select fn_subs_hoy() || '|' || (select p.periodo from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.desde <= fn_subs_hoy() order by p.desde limit 1)")"
R5="$(suite "$TMP/p5.out")"
revisa "la suite un año después: nada falla" "fallan=0" "${R5%% *}"
echo "     (omitidas entonces: ${R5#* omitidas=})"

echo "== 6. El pegado con Storage ocupado (otra sesión leyendo storage.objects)"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" > "$TMP/carga6.out" 2>&1 \
  || { tail -n 30 "$TMP/carga6.out"; echo "FALLÓ la carga" >&2; exit 2; }
pegar() { PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$1"; }
( ed -c "begin; select count(*) from storage.objects; select pg_sleep(4); commit;" > "$TMP/6l.out" 2>&1 ) &
sleep 1
pegar "$DOCS/c14-subs.sql" > "$TMP/6p.out" 2>&1
rc6=$?
revisa "el pegado NO entra: se rinde con 55P03 («lock timeout»)" "no entra|1" \
  "$([ $rc6 -ne 0 ] && echo 'no entra' || echo 'ENTRÓ')|$(grep -c '55P03' "$TMP/6p.out" | sed 's/^[1-9][0-9]*$/1/')"
revisa "y no queda nada: ni las tablas de los subs, ni el bucket, ni un candado suyo en Storage" "0|0|0" \
  "$(ed -c "select (select count(*) from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname like 'subs\\_%' escape '\\')
                   || '|' || (select count(*) from storage.buckets where id = 'subs')
                   || '|' || (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'subs: %')")"
wait
pegar "$DOCS/c14-subs.sql" > "$TMP/6p2.out" 2>&1
revisa "sin nadie leyendo, entra entero" "0" "$?"
revisa "con los siete candados del bucket «subs», y las protecciones (el 90) en verde" "7|verde" \
  "$(ed -c "select (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'subs: %')
                   || '|' || (select case when ok then 'verde' else 'rojo: ' || left(detalle, 200) end from fn_subs_control(null) where orden = 90)")"

echo "== 7. El TIN no va al registro del servidor"
DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
F7="$(ed -c "begin; select set_config('request.jwt.claims', json_build_object('sub', '$DUENO', 'role', 'authenticated', 'aal', 'aal2')::text, true); set local role authenticated; select fn_subs_ficha('{\"nombre_legal\": \"ZZ C14 Robustez Siete\", \"tipo_entidad\": \"individual\"}')->>'ficha_id'; commit;" | tail -n 1)"
LOG="${PGLOG:-/var/lib/postgresql/17/bench.log}"
T7='00-0000088'
if [ -r "$LOG" ]; then N0="$(grep -c -- "$T7" "$LOG" || true)"; else N0=x; fi
# (como el SQL Editor: la orden entera va en el texto, con el TIN tecleado)
ed -c "select fn_subs_tin_guardar('$F7', '{\"tin\": \"$T7\"}')" > "$TMP/7a.out" 2>&1
ed -c "select fn_subs_ficha('{\"id\": \"$F7\", \"direccion\": \"$T7\"}')" > "$TMP/7b.out" 2>&1
ed -c "select fn_subs_ficha('{\"id\": \"$F7\", \"tin\": \"$T7\"}')" > "$TMP/7c.out" 2>&1
ed -c "select fn_subs_ficha('{\"id\": \"$F7\", \"zip\": \"$T7\"}')" > "$TMP/7d.out" 2>&1
ed -c "select fn_subs_ficha('{\"id\": \"$F7\", \"$T7\": \"x\"}')" > "$TMP/7e.out" 2>&1
ed -c "select fn_subs_tin_guardar('$F7', '{\"quitar\": \"$T7\"}')" > "$TMP/7f.out" 2>&1
revisa "desde el SQL Editor no se guarda, y lo dice sin un error (las seis maneras de teclearlo: en su sitio, en la dirección, entre los datos de la ficha, en el código postal, como una clave de más y en «quitar»)" "0 errores|6 «no se guardó»|sin TIN" \
  "$(cat "$TMP"/7[a-f].out | grep -c 'ERROR') errores|$(cat "$TMP"/7[a-f].out | grep -c '"guardado": false') «no se guardó»|$(ed -c "select case when tin_ultimos4 is null then 'sin TIN' else 'CON TIN' end from subs_fichas where id = '$F7'")"
revisa "y la respuesta no repite lo tecleado" "0" "$(cat "$TMP"/7[a-f].out | grep -c -- "$T7")"
if [ "$N0" = "x" ]; then
  echo "     (no se puede leer el registro del servidor, $LOG: esa comprobación se salta)"
else
  sleep 1
  revisa "en el registro del servidor no queda ninguna línea nueva con ese TIN" "0" "$(( $(grep -c -- "$T7" "$LOG" || true) - N0 ))"
fi

if [ "$malos" = "0" ]; then echo "TODO BIEN"; else echo "ALGO FALLA"; fi
exit "$malos"
