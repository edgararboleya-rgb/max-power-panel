#!/usr/bin/env bash
# =====================================================================
# c10-volumen.sh — lo que c10-pruebas.sql no puede ver con sus pocas
# horas: que «Costo por obra» (c10) aguanta AÑOS de horas —y de horas
# pagadas por una nómina— dentro del tope de la API (8 s), y que con
# decenas de miles de reportes sigue contando igual.
#
#   ./c10-volumen.sh [nombre_bd]      (por defecto c10_volumen)
#
# Crea su base con c1 + c2 + c3 + c4 + c6 + c10 y le carga 12 personas, 40
# obras y 40,000 reportes de horas desde el 1-oct-2026 (dos por persona y
# día: más de cuatro años), todos con obra; 30,000 de ellos —los de 9 de
# las 12 personas— pagados por una nómina. La nómina (c15) no hace falta
# aquí: lo único que c10 lee de ella es su marca sin dinero (qué reporte de
# horas pagó qué corrida, y su día de pago), y este script pone una con la
# misma forma (c15-nomina.sql, fn_nomina_horas_con_pago) que contesta esos
# 30,000. Y un pago por Zelle, en la Bandeja, a una de las personas que ya
# cobra por nómina. Comprueba:
#   1. LAS SUMAS: 180,000 h en esas obras; 150,000 con pago real (las que
#      pagó la nómina) y 30,000 a estándar; reporte por reporte, 30,000 con
#      pago real y sin importe; el detalle de una obra, con sus 2,000 h de
#      nómina y las 119 nóminas que las pagaron; las personas, 30,000 h sin
#      pago; el control del margen sin rojos, y su renglón 70 con esas
#      150,000 h en 30,000 reportes; la propuesta del Zelle avisa de que sus
#      56 h de la semana ya las pagó una nómina, y ese Zelle no cuenta como
#      «pago sin repartir» en ninguna obra.
#   2. LOS TIEMPOS, como el dueño por la API (su rol, los ajustes de ese rol
#      y el tope de 8 s): el costo por obra, el reporte por reporte, el
#      detalle de una obra, las personas, las horas tardías, los pagos
#      resueltos por fuera, los dos controles y la propuesta de un pago,
#      cada uno por debajo de su tope. El tope está para que no vuelva a
#      pasar lo que se midió el 13-nov-2026 al escribir la v3 de c10: con la
#      lista de la nómina CRUZADA con las horas, la base —que con las
#      policies de horas cree que sale un solo reporte— recorría la lista
#      entera por cada reporte: 63 s para lo que así tarda 2.
#   3. SIN LA MARCA (como en una base sin nómina): todo sigue contestando,
#      las 180,000 h van a estándar, el Zelle sale sin repartir en las obras
#      de esa persona y el renglón 70 dice que la nómina no está.
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida). Nombres
# inventados («ZZ C10 VOL …»); nada de producción.
# Variables: PGHOST (127.0.0.1) y PGPORT (5432), como correr.sh.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c10_volumen}"
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

echo "== Base $BD: c1 + c2 + c3 + c4 + c6 + c10"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$DOCS/c10-costo-obra.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

echo "== La carga: 12 personas, 40 obras, 40,000 reportes de horas (30,000 pagados por una nómina) y un pago por Zelle"
cat > "$TMP/datos.sql" <<'SQL'
\set ON_ERROR_STOP 1
insert into auth.users (id, email)
select ('00000000-0000-4000-a000-0000000cb' || lpad(i::text, 3, '0'))::uuid, 'c10-vol-' || i || '@c10-pruebas.invalid' from generate_series(1, 12) i;
insert into perfiles (id, nombre, rol, activo)
select ('00000000-0000-4000-a000-0000000cb' || lpad(i::text, 3, '0'))::uuid, 'ZZ C10 VOL ' || lpad(i::text, 2, '0'), 'campo', true from generate_series(1, 12) i;
insert into costos_equipo (usuario_id, costo_hora)
select ('00000000-0000-4000-a000-0000000cb' || lpad(i::text, 3, '0'))::uuid, 20 + i from generate_series(1, 12) i;
insert into proyectos (id, tipo, nombre, estado)
select 'c10-vol-' || lpad(i::text, 2, '0'), 'comercial', 'ZZ C10 VOL Obra ' || lpad(i::text, 2, '0'), 'ejecucion' from generate_series(1, 40) i;
-- El reporte g (1 a 40,000): 24 por día desde el 1-oct-2026 (dos por persona: 2 h y 6 h), la persona 1 + g % 12, la obra
-- 1 + g % 40, uno de cada tres con fase y uno de cada siete con CO.
insert into horas (id, fecha, usuario_id, proyecto_id, fase, co, horas, notas) overriding system value
select -2000000000 + g, date '2026-10-01' + ((g - 1) / 24),
       ('00000000-0000-4000-a000-0000000cb' || lpad((1 + g % 12)::text, 3, '0'))::uuid, 'c10-vol-' || lpad((1 + g % 40)::text, 2, '0'),
       case when g % 3 = 0 then 'rough' end, case when g % 7 = 0 then 'CO #1' end, 1 + (g % 8), 'c10-volumen'
  from generate_series(1, 40000) g;
-- LA MARCA DE LA NÓMINA, con la forma de la de c15 (fn_nomina_horas_con_pago: el reporte de horas, su corrida y su día de
-- pago; SECURITY DEFINER, solo para authenticated), contestando desde aquí: tres de cada cuatro reportes (g % 4 <> 0: los de
-- 9 de las 12 personas y 30 de las 40 obras), cada uno pagado por la nómina de su quincena (120 nóminas, una cada 14 días).
create function public.fn_nomina_horas_con_pago()
returns table (horas_id bigint, corrida_id uuid, dia_pago date)
language sql stable
security definer
set search_path = public, pg_temp
as $f$
  select (-2000000000 + g)::bigint, ('00000000-0000-4000-a000-0000000cf' || lpad(((g - 1) / (24 * 14))::text, 3, '0'))::uuid,
         date '2026-10-16' + 14 * ((g - 1) / (24 * 14))
    from generate_series(1, 40000) g
   where g % 4 <> 0
$f$;
revoke execute on function public.fn_nomina_horas_con_pago() from public, anon, service_role;
grant  execute on function public.fn_nomina_horas_con_pago() to authenticated;
-- El Zelle a la persona 2 (todas sus horas las pagó la nómina), el miércoles 21-oct-2026: se reconoce por su patrón.
select set_config('request.jwt.claims', json_build_object('sub', (select id from perfiles where rol = 'dueno' order by creado limit 1), 'role', 'authenticated')::text, false);
select fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c10-volumen',
  'filas', jsonb_build_array(jsonb_build_object('id', 'c10-vol-1', 'fecha', '2026-10-21', 'plaid_monto', '640.25',
                                                'descripcion', 'Zelle payment to C10 VOL ZZDOS 7001', 'tipo', 'DEBIT', 'pendiente', false))));
select count(fn_banco_casar(m.id)) from movimientos_banco m where m.id_externo like 'c10-vol-%';
select fn_jornal_persona('{"usuario_id": "00000000-0000-4000-a000-0000000cb002", "patron": "\\mVOL ZZDOS\\M"}')->>'nota_alta';
select set_config('request.jwt.claims', '', false);
analyze;
select 'CARGA ' || (select count(*) from horas where notas = 'c10-volumen') || ' reportes de horas, '
       || (select count(*) from fn_nomina_horas_con_pago()) || ' pagados por la nómina, '
       || (select count(*) from movimientos_banco where id_externo like 'c10-vol-%') || ' pago en la Bandeja';
SQL
ed -f "$TMP/datos.sql" > "$TMP/datos.out" 2>&1 || { tail -n 12 "$TMP/datos.out"; echo "FALLÓ la carga de los datos" >&2; exit 2; }
grep -o 'CARGA .*' "$TMP/datos.out" | sed 's/^CARGA /     (/; s/$/)/'
revisa "los 40,000 reportes, 30,000 pagados por la nómina, y el pago" "40000|30000|1" \
  "$(ed -c "select format('%s|%s|%s', (select count(*) from horas where notas = 'c10-volumen'), (select count(*) from fn_nomina_horas_con_pago()), (select count(*) from movimientos_banco where id_externo like 'c10-vol-%'))")"

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
MOV="$(ed -c "select id from movimientos_banco where id_externo = 'c10-vol-1'")"
# Una orden como el dueño por la API: con el rol authenticated, los ajustes de ese rol (el jit = off de c4) y el tope de la
# API (8 s). Sin el código del teléfono (aal1): «Costo por obra» se lee así. Lo que contesta, y los milisegundos que tardó.
api() {  # api <nombre> <sql que devuelve un texto>
  ed -v ON_ERROR_STOP=1 \
     -c "begin; select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\",\"aal\":\"aal1\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';" \
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
# Todas las lecturas de la pantalla, con el sufijo que se diga (para repetirlas sin la marca).
lecturas() {  # lecturas <sufijo>
  api "obras$1"    "select count(*) || ' obras | ' || trim_scale(sum(o.horas_reales)) || ' h | con pago real ' || trim_scale(sum(o.horas_con_pago_real))
                           || ' | a estándar ' || trim_scale(sum(o.horas_estandar)) || ' | obras con un pago sin repartir: '
                           || count(*) filter (where o.pagos_sin_repartir > 0)
                      from v_margen_obra o where o.proyecto_id like 'c10-vol-%'"
  api "horas$1"    "select count(*) || ' reportes | con pago real ' || count(*) filter (where h.clase = 'pago_real')
                           || ' (con importe: ' || count(*) filter (where h.clase = 'pago_real' and (h.monto_real <> 0 or h.repartos <> 0)) || ') | a estándar '
                           || count(*) filter (where h.clase = 'estandar')
                      from fn_margen_horas(null) h where h.proyecto_id like 'c10-vol-%'"
  api "obra$1"     "select jsonb_array_length(j->'cobertura') || ' personas | ' || jsonb_array_length(j->'por_fase') || ' fases | de nómina '
                           || (select trim_scale(sum((c->>'horas_nomina')::numeric)) from jsonb_array_elements(j->'cobertura') c) || ' h en '
                           || jsonb_array_length(j->'nominas') || ' nóminas'
                      from fn_margen_obra('c10-vol-02') j"
  api "personas$1" "select count(*) || ' personas | sin pago ' || trim_scale(sum(v.horas_sin_pago)) from v_jornal_personas v where v.nombre like 'ZZ C10 VOL %'"
  api "tardias$1"  "select count(*)::text from fn_jornal_tardias(null)"
  api "fuera$1"    "select count(*)::text from fn_jornal_fuera()"
  api "margen$1"   "select count(*) || ' filas, ' || count(*) filter (where not k.ok) || ' en rojo | 70: ' || max(k.detalle) filter (where k.orden = 70) from v_margen_control k"
  api "jornal$1"   "select count(*) || ' filas, ' || count(*) filter (where not k.ok and k.nivel = 'cuadre') || ' cuadres en rojo' from v_jornal_control k"
  api "pago$1"     "select (j->>'puede_aplicar') || ' | ' || coalesce((select (a->>'horas') || ' h en ' || (a->>'reportes') || ' reportes'
                                                                         from jsonb_array_elements(j->'avisos') a where a->>'codigo' = 'pagadas_por_nomina'), 'sin ese aviso')
                      from fn_jornal_propuesta('$MOV') j"
}
topes() {  # topes <sufijo>
  tope "obras$1"    "el costo por obra (todas las obras)" 5000
  tope "horas$1"    "reporte por reporte (los 40,000)" 5000
  tope "obra$1"     "el detalle de una obra" 4000
  tope "personas$1" "las personas del jornal, con sus horas sin pago" 5000
  tope "tardias$1"  "las horas tardías" 4000
  tope "fuera$1"    "los pagos resueltos por fuera" 4000
  tope "margen$1"   "el control del margen (sus 7 filas)" 8000
  tope "jornal$1"   "el control del jornal (sus 11 filas)" 6000
  tope "pago$1"     "la propuesta de un pago (a quien tiene miles de horas pagadas por nómina)" 4000
}

echo "== 1. Las sumas, con 30,000 reportes pagados por una nómina"
lecturas ""
revisa "el costo por obra: 150,000 h con pago real (las de la nómina) y 30,000 a estándar; el Zelle a quien ya cobró por nómina no deja pagos sin repartir" \
  "40 obras | 180000 h | con pago real 150000 | a estándar 30000 | obras con un pago sin repartir: 0" "$(res obras)"
revisa "reporte por reporte: los 30,000 de la nómina con pago real y sin importe; los otros 10,000, a estándar" \
  "40000 reportes | con pago real 30000 (con importe: 0) | a estándar 10000" "$(res horas)"
revisa "el detalle de una obra: sus horas de nómina y las nóminas que las pagaron, sin importes" \
  "3 personas | 2 fases | de nómina 2000 h en 119 nóminas" "$(res obra)"
revisa "las personas: sin pago, solo las 30,000 h que no pagó la nómina" "12 personas | sin pago 30000" "$(res personas)"
revisa "el control del margen: sin rojos, y el renglón 70 con las horas de la nómina" \
  "7 filas, 0 en rojo | 70: 150000 h con obra, en 30000 reporte(s), las pagó una nómina posteada: cuentan como pago real y no van, además, a estándar." "$(res margen)"
revisa "el control del jornal: ningún cuadre en rojo" "11 filas, 0 cuadres en rojo" "$(res jornal)"
revisa "la propuesta del Zelle: deja, y avisa de que esas horas ya las pagó una nómina" "true | 56 h en 14 reportes" "$(res pago)"

echo "== 2. Los tiempos, como el dueño por la API"
topes ""

echo "== 3. Sin la marca (como en una base sin nómina): todo contesta, y las horas van a estándar"
ed -c "drop function public.fn_nomina_horas_con_pago()" > /dev/null 2>&1
lecturas "0"
revisa "el costo por obra: las 180,000 h a estándar, y el Zelle sin repartir sale en las 10 obras de esa persona en esas semanas" \
  "40 obras | 180000 h | con pago real 0 | a estándar 180000 | obras con un pago sin repartir: 10" "$(res obras0)"
revisa "el control del margen: sin rojos, y el renglón 70 dice que la nómina no está" \
  "7 filas, 0 en rojo | 70: La nómina no está en esta base: el pago real de unas horas es el reparto de su pago por horas." "$(res margen0)"
revisa "la propuesta del Zelle: deja, sin ese aviso" "true | sin ese aviso" "$(res pago0)"
topes "0"

echo "== Al final"
revisa "la cadena del libro, sin rojos (los permisos también)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"

echo
if [ $malos -eq 0 ]; then echo "c10-volumen: todo bien"; else echo "c10-volumen: ALGO FALLA"; fi
exit $malos
