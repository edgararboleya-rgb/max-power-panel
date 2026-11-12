#!/usr/bin/env bash
# =====================================================================
# c14-volumen.sh — lo que c14-pruebas.sql no puede ver con sus pocos
# asientos: que el criterio del 1099 (c14) aguanta un libro GRANDE dentro
# del tope de la API (8 s), y que con miles de partidas sigue sumando al
# centavo.
#
#   ./c14-volumen.sh [nombre_bd]      (por defecto c14_volumen)
#
# Crea su base con c1 + c2 + c3 + c14 y le carga, en el mes abierto:
#   · 50 subs (30 con ficha) y 1,500 trabajos externos por el puente de c3
#     (5200 contra 2010, cada uno con su partida), de 1,001 a 2,500 dólares;
#   · el pago de cada uno desde el banco; y en 300 de ellos, 100 dólares de
#     retención pasados antes a la 2020 (un traspaso entre cuentas por pagar)
#     y pagados aparte.
# Son 3,600 asientos y 3,900 líneas de cuentas por pagar: varias veces lo
# que Max Power paga a subs en un año. Y comprueba:
#   1. LAS SUMAS, al centavo: todo lo pagado es servicio (2,625,750.00: lo
#      de las 300 retenciones también, que HEREDAN lo que eran al pasar de
#      una cuenta por pagar a otra); nada «no servicio» ni «sin clasificar»;
#      los dos cuadres del control en verde.
#   2. LOS TIEMPOS, como el dueño por la API (con sus candados de filas):
#      el cálculo, el 1099 del año, los pagos, el control, las filas del
#      cierre y el COI, cada uno por debajo de su tope (holgado: el cálculo
#      tarda menos de un segundo; el tope es para que no vuelva a pasar que
#      la base cruce las partidas línea por línea: medio minuto).
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida). Nombres
# inventados («ZZ VOL Sub NN»); nada de producción.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c14_volumen}"
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

echo "== Base $BD: c1 + c2 + c3 + c14"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c14-subs.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

echo "== La carga: 50 subs, 1,500 trabajos externos, sus pagos y 300 retenciones"
cat > "$TMP/datos.sql" <<'SQL'
\set ON_ERROR_STOP 1
do $$ begin for i in 1..50 loop perform fn_proveedor_alta(format('ZZ VOL Sub %s', lpad(i::text, 2, '0')), 'Net 30'); end loop; end $$;
do $$
declare
  v_obra  text := (select id from proyectos order by id limit 1);
  v_dia   date := (select p.desde from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.desde <= fn_fecha_miami(now()) order by p.desde limit 1);
  v_dueno uuid := (select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1);
  v_ps uuid[]; v_p uuid; v_d text; v_k text; i int;
begin
  if v_obra is null or v_dia is null or v_dueno is null then
    raise exception 'c14-volumen: falta una obra, un mes abierto ya empezado o el dueño';
  end if;
  select array_agg(id order by nombre) into v_ps from proveedores where nombre like 'ZZ VOL Sub %';
  perform fn_mapeo_confirmar('tipo_proyecto');
  -- (el puente de c3 contabiliza cada trabajo al insertarlo, como en sus pruebas)
  set constraints trg_puente_externos_despues immediate;
  for i in 1..1500 loop
    insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, costo, proveedor_id) overriding system value
    values (-(2000000 + i), v_obra, 'ZZ VOL trabajo ' || i, v_dia, 'ajuste', 1000 + i, v_ps[1 + (i % 50)]);
  end loop;
  -- (lo demás, como el dueño por la API)
  perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  for i in 1..30 loop
    perform fn_subs_ficha(jsonb_build_object('nombre_legal', format('ZZ VOL Sub %s LLC', lpad(i::text, 2, '0')), 'tipo_entidad', 'llc_un_socio',
              'reporta', 'si', 'tercero', jsonb_build_object('tipo', 'proveedor', 'id', v_ps[i])));
  end loop;
  v_d := v_dia::text;
  for i in 1..1500 loop
    v_p := v_ps[1 + (i % 50)]; v_k := (-(2000000 + i))::text;
    if i % 5 = 0 then
      perform fn_postear(jsonb_build_object('fecha', v_d, 'descripcion', 'ZZ VOL: retención ' || i, 'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', '2010', 'monto', '100.00', 'tercero_tipo', 'proveedor', 'tercero_id', v_p, 'partida_tabla', 'trabajos_externos', 'partida_id', v_k),
        jsonb_build_object('cuenta', '2020', 'monto', '-100.00', 'proyecto_id', v_obra, 'tercero_tipo', 'proveedor', 'tercero_id', v_p, 'partida_tabla', 'trabajos_externos', 'partida_id', v_k))));
      perform fn_postear(jsonb_build_object('fecha', v_d, 'descripcion', 'ZZ VOL: pago de la retención ' || i, 'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', '2020', 'monto', '100.00', 'proyecto_id', v_obra, 'tercero_tipo', 'proveedor', 'tercero_id', v_p, 'partida_tabla', 'trabajos_externos', 'partida_id', v_k),
        jsonb_build_object('cuenta', '1010', 'monto', '-100.00'))));
    end if;
    perform fn_postear(jsonb_build_object('fecha', v_d, 'descripcion', 'ZZ VOL: pago ' || i, 'lineas', jsonb_build_array(
      jsonb_build_object('cuenta', '2010', 'monto', (1000 + i - case when i % 5 = 0 then 100 else 0 end)::text, 'tercero_tipo', 'proveedor', 'tercero_id', v_p,
                         'partida_tabla', 'trabajos_externos', 'partida_id', v_k),
      jsonb_build_object('cuenta', '1010', 'monto', (-(1000 + i - case when i % 5 = 0 then 100 else 0 end))::text))));
  end loop;
  reset role;
end $$;
select 'CARGA ' || (select count(*) from asientos where descripcion like 'ZZ VOL%' or origen_tabla = 'trabajos_externos') || ' asientos, '
       || (select count(*) from asiento_lineas l where l.cuenta in ('2010', '2020')) || ' líneas por pagar, '
       || (select count(*) from trabajos_externos where id < -2000000 and contabilizado_en is not null) || ' trabajos contabilizados';
SQL
ed -1 -f "$TMP/datos.sql" > "$TMP/datos.out" 2>&1 || { tail -n 12 "$TMP/datos.out"; echo "FALLÓ la carga de los datos" >&2; exit 2; }
grep -o 'CARGA .*' "$TMP/datos.out" | sed 's/^CARGA /     (/; s/$/)/'
revisa "los 1,500 trabajos están contabilizados" "1500" "$(ed -c "select count(*) from trabajos_externos where id < -2000000 and contabilizado_en is not null")"

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
ANIO="$(ed -c "select extract(year from p.desde)::int from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.desde <= fn_fecha_miami(now()) order by p.desde limit 1")"
MES="$(ed -c "select p.periodo from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.desde <= fn_fecha_miami(now()) order by p.desde limit 1")"
# Una orden como el dueño por la API (su rol, sus ajustes, el tope de 8 s): lo que contesta, y los milisegundos que tardó.
api() {  # api <nombre> <sql que devuelve un texto>
  ed -v ON_ERROR_STOP=1 -c "begin; select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated; set local statement_timeout = '8s';" \
     -c "\\timing on" -c "select 'R ' || ($2);" -c "\\timing off" -c "commit;" > "$TMP/$1.out" 2>&1
}
res() { sed -n 's/^R //p' "$TMP/$1.out"; }
ms()  { sed -n 's/^Time: \([0-9]*\)[.,].*/\1/p' "$TMP/$1.out" | head -n 1; }
tope() {  # tope <nombre> <descripción> <milisegundos>
  local t; t="$(ms "$1")"
  if grep -q 'ERROR' "$TMP/$1.out"; then echo "FALLA: $2: $(grep -m1 ERROR "$TMP/$1.out" | cut -c1-200)"; malos=1
  elif [ -n "$t" ] && [ "$t" -lt "$3" ]; then echo "ok   $2: ${t} ms (tope ${3} ms)"
  else echo "FALLA: $2: tardó ${t:-?} ms (tope ${3} ms)"; malos=1; fi
}

echo "== 1. Las sumas, al centavo"
api calculo "select count(*) || ' partes | servicio pagado ' || coalesce(sum(c.monto) filter (where c.medio = 'efectivo' and c.clase = 'servicio'), 0)
                    || ' | no servicio ' || coalesce(sum(c.monto) filter (where c.clase = 'no_servicio'), 0)
                    || ' | sin clasificar ' || coalesce(sum(c.monto) filter (where c.clase = 'sin_clasificar'), 0)
                    || ' | por pagar ' || coalesce(sum(c.monto) filter (where c.medio = 'por_pagar'), 0) from fn_subs_calculo() c"
revisa "todo lo pagado es servicio, también lo de las 300 retenciones (heredan lo que eran)" \
  "3300 partes | servicio pagado 2625750.00 | no servicio 0 | sin clasificar 0 | por pagar 2625750.00" "$(res calculo)"
api f1099 "select count(*) || ' filas | pagado ' || sum(r.pagado_servicio) || ' | reportable ' || sum(r.reportable) || ' | con ficha ' || count(*) filter (where r.ficha_id is not null)
                  || ' | sin ficha ' || count(*) filter (where r.ficha_id is null) from fn_subs_1099($ANIO) r"
revisa "el 1099 del año: los 50, cada uno con lo suyo" "50 filas | pagado 2625750.00 | reportable 2625750.00 | con ficha 30 | sin ficha 20" "$(res f1099)"
api control "select count(*) || ' filas, ' || count(*) filter (where k.nivel = 'cuadre' and not k.ok) || ' cuadres en rojo' from fn_subs_control($ANIO) k"
revisa "el control: sus 18 filas, y ningún cuadre en rojo" "18 filas, 0 cuadres en rojo" "$(res control)"

echo "== 2. Los tiempos, como el dueño por la API"
api pagos  "select count(*)::text from fn_subs_pagos($ANIO)"
api cierre "select count(*)::text from fn_subs_cierre('$MES')"
api coi    "select count(*)::text from fn_subs_coi(null, null, null)"
tope calculo "el cálculo (todas las partes de todos los pagos)" 4000
tope f1099   "el 1099 del año" 6000
tope pagos   "los pagos del año, uno por uno" 6000
tope control "el control (sus 18 filas)" 8000
tope cierre  "las dos filas del cierre" 6000
tope coi     "el COI de cada uno" 6000

echo
if [ $malos -eq 0 ]; then echo "c14-volumen: todo bien"; else echo "c14-volumen: ALGO FALLA"; fi
exit $malos
