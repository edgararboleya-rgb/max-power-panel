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
#   4. LA CUADRILLA, SOLA (c10 v5, 15-nov-2026), con esas 40,000 horas
#      delante y sin la marca (las doce personas cobran por horas): doce
#      Zelle de los lunes a tres personas que nadie dio de alta, cada uno por
#      lo que valen sus horas de la semana anterior. La rutina que registra
#      sola (fn_jornal_solo), llamada como la app al abrir Contabilidad (el
#      dueño por la API, con el tope de 8 s) hasta que dice «completo»: da de
#      alta sola a las once personas que faltan, registra los doce pagos y
#      NINGUNA llamada pasa del tope (su presupuesto son 3 s: corta y dice
#      cuántos quedan). Después: en la Bandeja queda solo el pago de antes
#      (pregunta: lo que sale por hora se aleja de su tarifa), los doce
#      repartos son «solos» y suman los doce pagos al centavo, los dos
#      controles sin cuadres en rojo, llamarla otra vez no hace nada, y lo
#      que la pantalla lee de más (los pendientes con su porqué, los cheques,
#      las personas) contesta por debajo de su tope.
#   5. LA RUTINA AVANZA SIEMPRE (la revisión de la v5, 15-nov-2026): veinte
#      pagos que PREGUNTAN (lo que sale por hora se aleja de su tarifa), más
#      viejos que uno que ENTRA. Cada pago que pregunta cuesta su cálculo
#      aunque no entre, y con miles de horas delante ese cálculo pesa: una
#      llamada no llega a mirarlos todos. Llamada sin decirle por dónde
#      seguir (como antes de la revisión) vuelve a empezar cada vez por el
#      más viejo: tres llamadas, y el pago que entra sigue en la Bandeja.
#      Llamada como la app ahora (cada llamada manda en «despues_de» el
#      «sigue» de la anterior): cada una avanza, termina («completo») y el
#      pago que entra queda registrado. (Con un presupuesto de 0.2 s por
#      llamada: así corta en cualquier máquina.)
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
# (Con AAL=aal2, con el código: así llama la app a la rutina que registra sola.)
api() {  # api <nombre> <sql que devuelve un texto>
  ed -v ON_ERROR_STOP=1 \
     -c "begin; select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\",\"aal\":\"${AAL:-aal1}\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';" \
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
  tope "jornal$1"   "el control del jornal (sus 12 filas)" 6000
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
revisa "el control del jornal: ningún cuadre en rojo" "12 filas, 0 cuadres en rojo" "$(res jornal)"
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

echo "== 4. La cuadrilla, sola (v5), con las 40,000 horas delante: la rutina no se cuelga de la API"
# Doce Zelle de los lunes 12, 19 y 26-oct y 2-nov-2026 a las personas 1, 5 y 9 (nadie las dio de alta: la base las reconoce por
# su nombre, como lo tiene la app), cada uno por las horas de su semana anterior a su tarifa: nada pide decidir.
cat > "$TMP/solo.sql" <<'SQL'
\set ON_ERROR_STOP 1
select set_config('request.jwt.claims', json_build_object('sub', (select id from perfiles where rol = 'dueno' order by creado limit 1), 'role', 'authenticated')::text, false);
select fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c10-volumen · la cuadrilla sola',
  'filas', (select jsonb_agg(jsonb_build_object('id', 'c10-vol-s-' || i || '-' || w, 'fecha', (date '2026-10-05' + 7 * w)::text,
              'plaid_monto', (select round(sum(h.horas) * (20 + i), 2)::text from horas h
                               where h.usuario_id = ('00000000-0000-4000-a000-0000000cb' || lpad(i::text, 3, '0'))::uuid
                                 and h.fecha between date '2026-10-05' + 7 * (w - 1) and date '2026-10-05' + 7 * (w - 1) + 6),
              'descripcion', 'Zelle payment to ZZ C10 VOL ' || lpad(i::text, 2, '0') || ' ' || (9000 + 10 * i + w), 'tipo', 'DEBIT', 'pendiente', false))
              from unnest(array[1, 5, 9]) i cross join generate_series(1, 4) w)));
select count(fn_banco_casar(m.id)) from movimientos_banco m where m.id_externo like 'c10-vol-s-%';
select set_config('request.jwt.claims', '', false);
SQL
ed -f "$TMP/solo.sql" > "$TMP/solo.out" 2>&1 || { tail -n 12 "$TMP/solo.out"; echo "FALLÓ la carga de los pagos de la cuadrilla" >&2; exit 2; }
TOTAL="$(ed -c "select count(*) || ' pagos por ' || sum(-m.monto) from movimientos_banco m where m.id_externo like 'c10-vol-s-%'")"
echo "     ($TOTAL)"
# La rutina, como la app al abrir Contabilidad: se la llama hasta que dice «completo» (como mucho 12 veces, como la pantalla),
# y cada llamada manda en «despues_de» el «sigue» de la anterior (sigue después del último pago que la base miró)
n=0; reg=0; altas=0; peor=0; completo=false; sigue=""
while [ "$completo" != "true" ] && [ $n -lt 12 ]; do
  n=$((n + 1))
  P="{\"corrio\": \"pantalla\"$([ -n "$sigue" ] && echo ", \"despues_de\": \"$sigue\"")}"
  AAL=aal2 api "solo$n" "select format('%s|%s|%s|%s', r->>'completo', jsonb_array_length(r->'registrados'), (select count(*) from jsonb_array_elements(r->'altas') a where a->>'nombre' like 'ZZ C10 VOL %'), coalesce(r->>'sigue', '')) from (select fn_jornal_solo('$P'::jsonb) r) x"
  if grep -q 'ERROR' "$TMP/solo$n.out"; then echo "FALLA: la rutina, llamada $n: $(grep -m1 ERROR "$TMP/solo$n.out" | cut -c1-200)"; malos=1; break; fi
  IFS='|' read -r completo r a sigue <<< "$(res "solo$n")"
  reg=$((reg + ${r:-0})); altas=$((altas + ${a:-0}))
  t="$(ms "solo$n")"; [ "${t:-0}" -gt "$peor" ] && peor="${t:-0}"
done
revisa "la base da de alta sola a las 11 personas de la carga que faltan y registra los 12 pagos (llamándola hasta «completo»)" "12 registrados | 11 altas | completo true" "$reg registrados | $altas altas | completo $completo"
if [ "$peor" -lt 8000 ]; then echo "ok   ninguna llamada a la rutina pasa del tope de la API: $n llamada(s), la más lenta ${peor} ms (tope 8000 ms; su presupuesto, 3000)"
else echo "FALLA: una llamada a la rutina tardó ${peor} ms (tope 8000 ms)"; malos=1; fi
AAL=aal2 api "solo_otra" "select format('%s|%s|%s', r->>'completo', jsonb_array_length(r->'registrados'), jsonb_array_length(r->'altas')) from (select fn_jornal_solo('{\"corrio\": \"pantalla\"}'::jsonb) r) x"
revisa "llamarla otra vez no hace nada" "true|0|0" "$(res solo_otra)"
tope "solo_otra" "la rutina, cuando no hay nada que registrar" 5000
api "solos"     "select count(*) || ' repartos solos por ' || sum(r.monto) || ' | en 5200: ' || (select count(*) from jornal_reparto_lineas l join jornal_repartos x on x.id = l.reparto_id where x.origen = 'solo' and l.cuenta <> '5200') || ' líneas fuera'
                   from v_jornal_repartos r where r.origen = 'solo' and r.estado = 'aplicado'"
revisa "los doce repartos son «solos», suman los doce pagos al centavo y todo va a 5200" "$(echo "$TOTAL" | sed 's/ pagos por / repartos solos por /') | en 5200: 0 líneas fuera" "$(res solos)"
tope "solos" "los repartos (lo «Registrado solo» de la Bandeja)" 5000
api "pend"      "select count(*) || ' pago | ' || string_agg(v.solo || ': ' || (select string_agg(f->>'codigo', ',') from jsonb_array_elements(v.solo_frenos) f), ' ') from v_jornal_pendientes v"
revisa "en la Bandeja queda solo el pago de antes, y dice por qué no entró (lo que sale por hora se aleja de su tarifa)" "1 pago | pregunta: tarifa_lejos" "$(res pend)"
tope "pend" "los pagos pendientes, cada uno con lo que lo frena" 5000
api "cheques"   "select count(*)::text from v_jornal_cheques"
tope "cheques" "los cheques que preguntan de quién son" 4000
api "personas4" "select count(*) || ' personas | dadas de alta solas ' || count(*) filter (where v.alta = 'sola') || ' | por Edgar ' || count(*) filter (where v.alta = 'edgar') from v_jornal_personas v where v.nombre like 'ZZ C10 VOL %'"
revisa "las personas: once dadas de alta solas y la que dio de alta Edgar" "12 personas | dadas de alta solas 11 | por Edgar 1" "$(res personas4)"
tope "personas4" "las personas del jornal (con quién se dio de alta sola)" 5000
api "jornal4"   "select count(*) || ' filas, ' || count(*) filter (where not k.ok and k.nivel = 'cuadre') || ' cuadres en rojo | 85: ' || (select case when x.ok then 'verde' else 'avisa' end from v_jornal_control x where x.orden = 85) from v_jornal_control k"
revisa "el control del jornal: ningún cuadre en rojo, y el aviso 85 dice que un pago espera" "12 filas, 0 cuadres en rojo | 85: avisa" "$(res jornal4)"
tope "jornal4" "el control del jornal (sus 12 filas), con doce repartos" 6000
api "margen4"   "select count(*) || ' filas, ' || count(*) filter (where not k.ok) || ' en rojo' from v_margen_control k"
revisa "el control del margen: sin rojos con los doce repartos" "7 filas, 0 en rojo" "$(res margen4)"
tope "margen4" "el control del margen (sus 7 filas), con doce repartos" 8000

echo "== 5. La rutina AVANZA SIEMPRE: veinte pagos que preguntan, más viejos que uno que entra"
# Veinte Zelle del lunes 12-oct-2026 a la persona 3 (ya dada de alta sola), cada uno por EL TRIPLE de lo que valen sus horas de la
# semana anterior: lo que sale por hora se aleja de su tarifa, PREGUNTAN. Y uno del lunes 9-nov-2026 a la persona 7, por lo que
# valen sus horas de la semana anterior a su tarifa: ENTRA. La rutina mira del más viejo al más nuevo: los veinte van delante.
cat > "$TMP/avanza.sql" <<'SQL'
\set ON_ERROR_STOP 1
select set_config('request.jwt.claims', json_build_object('sub', (select id from perfiles where rol = 'dueno' order by creado limit 1), 'role', 'authenticated')::text, false);
select fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c10-volumen · la rutina avanza',
  'filas', (select jsonb_agg(jsonb_build_object('id', 'c10-vol-p-' || k, 'fecha', '2026-10-12',
              'plaid_monto', (select round(sum(h.horas) * 23 * 3 + k, 2)::text from horas h
                               where h.usuario_id = '00000000-0000-4000-a000-0000000cb003' and h.fecha between date '2026-10-05' and date '2026-10-11'),
              'descripcion', 'Zelle payment to ZZ C10 VOL 03 ' || (9500 + k), 'tipo', 'DEBIT', 'pendiente', false))
              from generate_series(1, 20) k)
           || jsonb_build_array(jsonb_build_object('id', 'c10-vol-e-1', 'fecha', '2026-11-09',
              'plaid_monto', (select round(sum(h.horas) * 27, 2)::text from horas h
                               where h.usuario_id = '00000000-0000-4000-a000-0000000cb007' and h.fecha between date '2026-11-02' and date '2026-11-08'),
              'descripcion', 'Zelle payment to ZZ C10 VOL 07 9601', 'tipo', 'DEBIT', 'pendiente', false))));
select count(fn_banco_casar(m.id)) from movimientos_banco m where m.id_externo like 'c10-vol-p-%' or m.id_externo = 'c10-vol-e-1';
select set_config('request.jwt.claims', '', false);
SQL
ed -f "$TMP/avanza.sql" > "$TMP/avanza.out" 2>&1 || { tail -n 12 "$TMP/avanza.out"; echo "FALLÓ la carga de los pagos de la parte 5" >&2; exit 2; }
ENTRA="$(ed -c "select id from movimientos_banco where id_externo = 'c10-vol-e-1'")"
AAL=aal2 api "av_antes" "select string_agg(q.e || ' × ' || q.n, ' | ' order by q.e)
                           from (select v.solo || coalesce(' [' || (select string_agg(f->>'codigo', ',') from jsonb_array_elements(v.solo_frenos) f) || ']', '') as e, count(*) as n
                                   from v_jornal_pendientes v
                                  where v.movimiento_id in (select m.id from movimientos_banco m where m.id_externo like 'c10-vol-p-%' or m.id_externo = 'c10-vol-e-1') group by 1) q"
revisa "los veinte preguntan (la tarifa lejos) y el más nuevo entra" "entra × 1 | pregunta [tarifa_lejos] × 20" "$(res av_antes)"
# rutina5 <nombre> <despues_de o nada>: una llamada con 0.2 s de presupuesto → completo|registrados|los que miró y no entraron|sigue
rutina5() {
  local P="{\"corrio\": \"pantalla\", \"segundos\": 0.2$([ -n "$2" ] && echo ", \"despues_de\": \"$2\"")}"
  AAL=aal2 api "$1" "select format('%s|%s|%s|%s', r->>'completo', jsonb_array_length(r->'registrados'), jsonb_array_length(r->'no_entraron'), coalesce(r->>'sigue', '')) from (select fn_jornal_solo('$P'::jsonb) r) x"
}
# (a) SIN decirle por dónde seguir, como antes de la revisión: cada llamada vuelve a empezar por el más viejo
sin=""; mirados=0
for i in 1 2 3; do
  rutina5 "sin$i" ""
  IFS='|' read -r c r m s <<< "$(res "sin$i")"
  sin="$sin$c/$r "; [ "${m:-0}" -gt "$mirados" ] && mirados="${m:-0}"
done
revisa "sin decirle por dónde seguir (como antes): tres llamadas vuelven a empezar por el más viejo, ninguna termina ni registra nada, y el pago que entra sigue en la Bandeja" \
  "false/0 false/0 false/0 | pendiente" "$sin| $(ed -c "select estado from movimientos_banco where id = '$ENTRA'")"
echo "     (en 0.2 s una llamada llega a mirar, como mucho, $mirados de los $(ed -c "select count(*) from movimientos_banco m where m.estado = 'pendiente' and m.id_externo like 'c10-vol-%'") pagos que esperan en la Bandeja)"
# (b) como la app ahora: cada llamada manda en «despues_de» el «sigue» de la anterior
n=0; reg=0; completo=false; sigue=""; atascada=0; peor=0
while [ "$completo" != "true" ] && [ $n -lt 60 ]; do
  n=$((n + 1))
  antes="$sigue"
  rutina5 "con$n" "$sigue"
  if grep -q 'ERROR' "$TMP/con$n.out"; then echo "FALLA: la rutina, llamada $n: $(grep -m1 ERROR "$TMP/con$n.out" | cut -c1-200)"; malos=1; break; fi
  IFS='|' read -r completo r m sigue <<< "$(res "con$n")"
  reg=$((reg + ${r:-0}))
  [ "$completo" != "true" ] && [ "$sigue" = "$antes" ] && atascada=$((atascada + 1))
  t="$(ms "con$n")"; [ "${t:-0}" -gt "$peor" ] && peor="${t:-0}"
done
revisa "diciéndole por dónde seguir (como la app): cada llamada avanza, termina («completo») y registra el pago que entra" \
  "1 registrado | completo true | llamadas que no avanzaron: 0 | casado, solo" \
  "$reg registrado | completo $completo | llamadas que no avanzaron: $atascada | $(ed -c "select m.estado || ', ' || coalesce((select r.origen from jornal_repartos r where r.movimiento_id = m.id and r.estado = 'aplicado'), 'sin reparto') from movimientos_banco m where m.id = '$ENTRA'")"
echo "     ($n llamadas de 0.2 s; la más lenta, ${peor} ms)"
revisa "los veinte que preguntan siguen en la Bandeja, sin tocar" "20|0" \
  "$(ed -c "select format('%s|%s', count(*) filter (where m.estado = 'pendiente'), (select count(*) from jornal_repartos r join movimientos_banco x on x.id = r.movimiento_id where x.id_externo like 'c10-vol-p-%')) from movimientos_banco m where m.id_externo like 'c10-vol-p-%'")"

echo "== Al final"
revisa "la cadena del libro, sin rojos (los permisos también)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"

echo
if [ $malos -eq 0 ]; then echo "c10-volumen: todo bien"; else echo "c10-volumen: ALGO FALLA"; fi
exit $malos
