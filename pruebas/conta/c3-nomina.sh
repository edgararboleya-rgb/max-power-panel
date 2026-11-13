#!/usr/bin/env bash
# =====================================================================
# c3-nomina.sh — lo que c3-pruebas.sql solo puede fingir: EL DEVENGO
# ESTÁNDAR DE c3 CON NÓMINAS DE VERDAD de c15 dentro, por la puerta del
# dueño (13-nov-2026, Fase 11b).
#
#   ./c3-nomina.sh [nombre_bd]      (por defecto c3_nomina)
#
# Crea su base con c1 + c2 + c3 + c4 + c6 + c10, SIN la nómina; después pega
# c15 encima, sin volver a pegar c3 (el orden de producción al revés: c3 lee
# la nómina al vuelo, llegue cuando llegue). Dos obras, dos personas por
# horas (25 y 30 la hora) y el oficial, con sus horas aprobadas de diciembre
# de 2026 y de enero de 2027, y TRES NÓMINAS de Gusto (el journal sintético
# de pruebas/conta/nomina/zz-payroll-journal.csv, con sus fechas):
#     la del 8-ene   (período 20-dic a 2-ene: paga horas de DICIEMBRE)
#     la del 22-ene  (período 3 a 16-ene)
#     la del 5-feb   (período 17 a 30-ene: paga LA COLA de enero)
# El reloj de la base va por delante (fn_fecha_miami, fingida: el 4-ene, el
# 8-ene, el 21-ene, el 22-ene, el 5-feb), para que las fechas sean siempre
# las mismas; al final se deja como estaba.
#   1. SIN LA NÓMINA (c15 no está): diciembre se devenga como siempre, con
#      todas sus horas aprobadas con obra y con costo.
#   2. LLEGA c15 (encima, sin tocar c3): el devengo de diciembre sigue al
#      día (su firma no cambia), y el corte ya se lee.
#   3. EL CIERRE DE AÑO. La nómina del 8-ene paga las horas de diciembre: su
#      journal es de ENERO. Diciembre devengado NO se mueve (el control en
#      verde, devengar no hace nada); el día 1 se deshizo solo y la nómina
#      las paga una vez: diciembre lleva su costo a estándar; enero, el
#      reverso y el journal.
#   4. UN MES CON NÓMINA SE DEVENGA. Enero devengado ANTES de su nómina
#      (todas sus horas); al postear la del 22-ene, la nómina lo pone al día
#      sola: queda solo LA COLA (lo trabajado después del período y sin
#      pagar: 445.00), al centavo lo mismo que dice la cola de la nómina.
#   5. LA MISMA RESPUESTA EN TODA SESIÓN: el dueño con el código del
#      teléfono, sin él, y el SQL Editor ven el mismo control y el mismo
#      devengo. (La cola de la nómina, sin el código, dice «nada»: por eso
#      c3 no la lee.)
#   6. LA NÓMINA DEL MES SIGUIENTE (5-feb) paga la cola: enero no se mueve;
#      febrero lleva el reverso y el journal. Entre diciembre, enero y
#      febrero el 5000 de las obras es el de los tres journals: nada dos
#      veces. Y el control «mano de obra», en verde.
#   7. ANULAR Y VOLVER A SUBIR la del 22-ene: al anular, la nómina pone al
#      día el devengo de enero ella misma (vuelven sus horas) y lo dice; el
#      control «devengo» sigue en verde y devengar otra vez no cambia nada;
#      subida y posteada otra vez, queda otra vez solo la cola. (13-nov, los
#      arreglos de la verificación de la Fase 11b: antes anular dejaba el
#      devengo desfasado —el control en rojo, y con él el cierre— hasta que
#      Edgar lo corriera en el SQL Editor.)
#   8. EL CIERRE DEL MES (dentro de una transacción que se deshace): enero,
#      con su nómina y su devengo al día, SE CIERRA; con el devengo
#      desfasado (una hora más aprobada), no (MX008, y dice cómo).
#   9. SI LA NÓMINA NO DICE QUÉ HORAS PAGÓ (su marca quitada, como un c15 de
#      antes del 13-nov; dentro de una transacción que se deshace): el
#      devengo de enero convive con el journal (rojo), devengar lo deshace,
#      y devengar otra vez se niega y manda a pegar c15.
#  9b. UN MES GRANDE (dentro de una transacción que se deshace): con 1,500
#      reportes de horas devengados en un mes, el control «devengo» contesta
#      al dueño por la API dentro de su tope (8 s) y sigue en verde. (13-nov,
#      la revisión final de la Fase 11b: el control volvía a calcular el plan
#      del mes una vez por cada reporte devengado —38 s con dos meses de 1,440
#      reportes; 0.1 s con el c3 de antes del corte de la nómina—, y con él se
#      caían la fila del cierre que lo mira y la ronda.)
#  10. VOLVER A PEGAR c3 (dos veces) con todo dentro: los devengos son los
#      mismos asientos; y c3-pruebas.sql corre con las nóminas de verdad
#      dentro: ninguna falla.
# Y comprueba al final: la cadena del libro en verde (los permisos y las
# huellas también, con el reloj de vuelta), los puentes (c3) sin nada nuevo
# en rojo y los cuadres de la nómina sin rojos.
#
# Cada sesión de «la app» va como por PostgREST: el dueño, con el rol
# authenticated, los ajustes de ese rol y el tope de la API (8 s); con su
# código (aal2) o sin él (aal1). Nombres y montos inventados («ZZ…», «ZZ C3
# NOM»): nada de producción.
#
# Variables: PGHOST (127.0.0.1) y PGPORT (5432), como correr.sh.
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c3_nomina}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'echo "(La base $BD y $TMP quedan: ./correr.sh --borrar $BD; rm -rf $TMP)"' EXIT
else
  trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=terse -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }
# (pegar un archivo como el SQL Editor: una transacción, para al primer error)
pegar() { PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$1"; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

# La escena, como el SQL Editor: dos obras, tres personas (su usuario, su
# perfil de campo; dos con su tarifa) y sus horas APROBADAS.
cat > "$TMP/montar.sql" <<'SQL'
insert into proyectos (id, tipo, nombre, estado) values
  ('c3-nom-a', 'comercial', 'ZZ C3 NOM Obra A', 'ejecucion'),
  ('c3-nom-b', 'servicio',  'ZZ C3 NOM Obra B', 'ejecucion');
do $$
declare
  r record;
  v_d uuid := (select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1);
begin
  for r in select * from (values ('00000000-0000-4000-a000-0000000c3101'::uuid, 'ZZ Ayudante Uno'),
                                 ('00000000-0000-4000-a000-0000000c3102'::uuid, 'ZZ Ayudante Dos'),
                                 ('00000000-0000-4000-a000-0000000c3103'::uuid, 'ZZ Oficial Tres')) as x(id, nombre) loop
    insert into auth.users (id, email) values (r.id, 'c3-nom-' || right(r.id::text, 2) || '@c3-pruebas.invalid') on conflict (id) do nothing;
    insert into perfiles (id, nombre, rol, activo) values (r.id, r.nombre, 'campo', true)
    on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
  end loop;
  insert into costos_equipo (usuario_id, costo_hora) values
    ('00000000-0000-4000-a000-0000000c3101', 25), ('00000000-0000-4000-a000-0000000c3102', 30)
  on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
  insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el) values
    -- DICIEMBRE de 2026 (el período de la nómina del 8-ene: 20-dic a 2-ene)
    ('2026-12-21', '00000000-0000-4000-a000-0000000c3101', 'c3-nom-a', 8,  null,    'ZZ C3 NOM', v_d, now()),
    ('2026-12-22', '00000000-0000-4000-a000-0000000c3101', 'c3-nom-a', 8,  null,    'ZZ C3 NOM', v_d, now()),
    ('2026-12-28', '00000000-0000-4000-a000-0000000c3101', 'c3-nom-b', 8,  null,    'ZZ C3 NOM', v_d, now()),
    ('2026-12-29', '00000000-0000-4000-a000-0000000c3101', 'c3-nom-b', 8,  'CO #1', 'ZZ C3 NOM', v_d, now()),
    ('2026-12-30', '00000000-0000-4000-a000-0000000c3101', null,       4,  null,    'ZZ C3 NOM', v_d, now()),
    ('2026-12-22', '00000000-0000-4000-a000-0000000c3102', 'c3-nom-b', 8,  null,    'ZZ C3 NOM', v_d, now()),
    ('2026-12-30', '00000000-0000-4000-a000-0000000c3102', 'c3-nom-a', 6,  null,    'ZZ C3 NOM', v_d, now()),
    ('2026-12-23', '00000000-0000-4000-a000-0000000c3103', 'c3-nom-a', 10, null,    'ZZ C3 NOM', v_d, now()),
    -- ENERO de 2027, dentro del período de la nómina del 22-ene (3 a 16-ene)
    ('2027-01-04', '00000000-0000-4000-a000-0000000c3101', 'c3-nom-a', 8,  null,    'ZZ C3 NOM', v_d, now()),
    ('2027-01-05', '00000000-0000-4000-a000-0000000c3101', 'c3-nom-a', 8,  null,    'ZZ C3 NOM', v_d, now()),
    ('2027-01-11', '00000000-0000-4000-a000-0000000c3101', 'c3-nom-b', 8,  null,    'ZZ C3 NOM', v_d, now()),
    ('2027-01-06', '00000000-0000-4000-a000-0000000c3102', 'c3-nom-b', 8,  null,    'ZZ C3 NOM', v_d, now()),
    ('2027-01-12', '00000000-0000-4000-a000-0000000c3102', 'c3-nom-b', 8,  null,    'ZZ C3 NOM', v_d, now()),
    ('2027-01-07', '00000000-0000-4000-a000-0000000c3103', 'c3-nom-a', 10, null,    'ZZ C3 NOM', v_d, now()),
    -- ENERO, LA COLA: después de ese período (17 a 30-ene: los paga la nómina del 5-feb)
    ('2027-01-19', '00000000-0000-4000-a000-0000000c3101', 'c3-nom-a', 8,  null,    'ZZ C3 NOM', v_d, now()),
    ('2027-01-20', '00000000-0000-4000-a000-0000000c3101', 'c3-nom-b', 5,  'CO #1', 'ZZ C3 NOM', v_d, now()),
    ('2027-01-21', '00000000-0000-4000-a000-0000000c3102', 'c3-nom-a', 4,  null,    'ZZ C3 NOM', v_d, now()),
    ('2027-01-21', '00000000-0000-4000-a000-0000000c3103', 'c3-nom-a', 10, null,    'ZZ C3 NOM', v_d, now());
end $$;
SQL

echo "== Base $BD: c1 + c2 + c3 + c4 + c6 + c10, SIN la nómina, y lo de este script"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$DOCS/c10-costo-obra.sql" "$TMP/montar.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
[ -n "$DUENO" ] || { echo "No hay un dueño en la base" >&2; exit 2; }
[ "$(ed -c "select count(*) from periodos where periodo in ('2026-12', '2027-01', '2027-02') and estado = 'abierto'")" = "3" ] \
  || { echo "Diciembre de 2026, enero y febrero de 2027 tienen que estar abiertos en una base nueva" >&2; exit 2; }
# (lo que la base recién cargada ya trae en rojo en los puentes —los papeles de la semilla sin evaluar—: no es de aquí)
ROJOS_C3="$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_puentes_verificar() where not ok")"

# EL RELOJ DE LA BASE, por delante (como el de c2-pruebas: nunca por detrás
# del de verdad). Al final se deja como estaba.
ed -c "select pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure)" > "$TMP/reloj-de-verdad.sql"
reloj() {
  ed -v ON_ERROR_STOP=1 -c "create or replace function public.fn_fecha_miami(t timestamptz) returns date language sql stable set search_path = public, pg_temp as \$b\$ select greatest((t at time zone 'America/New_York')::date, date '$1') \$b\$" \
    || { echo "No se pudo mover el reloj de la base" >&2; exit 2; }
}
reloj_de_verdad() { ed -v ON_ERROR_STOP=1 -f "$TMP/reloj-de-verdad.sql" || { echo "No se pudo devolver el reloj" >&2; exit 2; }; }

# Como la app por PostgREST: el dueño, con el rol authenticated, los ajustes
# de ese rol y el tope de la API (8 s). app <aal1|aal2>.
app() {
  echo "select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\",\"aal\":\"$1\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"
}
# como <aal1|aal2> <sql que devuelve un texto>: lo que devuelve, o su error (:'arch' = el journal)
como() {
  ed -v ON_ERROR_STOP=1 -v arch="${ARCH:-{\}}" 2>&1 <<SQL | sed -n 's/^RESULTADO //p; s/^.*ERROR: *//p'
begin; $(app "$1")
select 'RESULTADO ' || coalesce(($2)::text, '(nulo)');
commit;
SQL
}
dueno() { como aal2 "$1"; }
# El devengo vivo de un mes: sus líneas de 5000 por obra y CO, y su total.
VIVO="a.origen_tabla = 'horas_devengo' and a.camino not in ('reverso', 'reverso_automatico') and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')"
devengo() {
  ed -c "select coalesce((select string_agg(concat_ws(' ', replace(l.proyecto_id, 'c3-nom-', ''), l.co, l.monto::text), ' · ' order by l.proyecto_id, l.co nulls first) || ' = ' || sum(l.monto)
                            from asientos a join asiento_lineas l on l.asiento_id = a.id and l.cuenta = '5000'
                           where $VIVO and a.origen_id = '$1'), 'sin devengo')"
}
numero() { ed -c "select coalesce((select a.numero from asientos a where $VIVO and a.origen_id = '$1'), '-')"; }
# El control devengo de c3 (t/f y cuántos fallan), como el SQL Editor o, con <aal>, como el dueño por la API.
CTL="(select c.ok::text || '/' || jsonb_array_length(c.detalle->'fallan') from fn_puentes_verificar() c where c.control = 'devengo')"
control() { if [ -n "${1:-}" ]; then como "$1" "$CTL"; else ed -c "select $CTL"; fi; }
# Volver a devengar un mes: qué hace (o su error), como el SQL Editor o, con <aal>, como el dueño por la API.
devengar() {
  if [ -n "${2:-}" ]; then como "$2" "fn_horas_devengar('$1')->>'accion'"
  else ed -c "select fn_horas_devengar('$1')->>'accion'" 2>&1 | sed 's/^.*ERROR: *//'; fi
}
# El 5000 de las obras de la escena en un mes, por obra y CO.
libro() {
  ed -c "select coalesce(string_agg(q.obra || ' ' || q.s, ' · ' order by q.obra), 'nada')
           from (select concat_ws(' ', replace(l.proyecto_id, 'c3-nom-', ''), l.co) as obra, sum(l.monto) as s
                   from asiento_lineas l join asientos a on a.id = l.asiento_id
                  where l.proyecto_id like 'c3-nom-%' and l.cuenta = '5000' and a.periodo = '$1'
                  group by 1 having sum(l.monto) <> 0) q"
}

# Una nómina de Gusto: el journal sintético del repositorio con sus fechas.
# archivo <inicio del período> <fin> <día de pago>  (MM/DD/AAAA) → el JSON que manda la pantalla
archivo() {
  local csv; csv="$(sed -e "s#01/03/2027#$1#g" -e "s#01/16/2027#$2#g" -e "s#01/22/2027#$3#g" "$DIR/nomina/zz-payroll-journal.csv")"
  ed -v csv="$csv" -v nombre="zz-payroll-journal-$(echo "$3" | tr -d /).csv" <<'SQL'
select jsonb_build_object('nombre', :'nombre', 'sha256', encode(sha256(convert_to(:'csv', 'UTF8')), 'hex'), 'bytes', octet_length(:'csv'),
                          'filas', (select jsonb_agg(to_jsonb(string_to_array(t.l, ',')) order by t.n)
                                      from unnest(string_to_array(:'csv', E'\n')) with ordinality as t(l, n)))::text;
SQL
}
# la nómina entera, por la puerta del dueño: importar, enlazar a su gente (la primera vez) y postear. Deja K (la corrida) y POST (lo que dijo postear).
nomina() {
  ARCH="$(archivo "$1" "$2" "$3")"
  [ -n "$ARCH" ] || { echo "No se pudo armar el archivo de la nómina" >&2; exit 2; }
  IMP="$(dueno "fn_nomina_importar(:'arch'::jsonb)->'corridas'->0->>'resultado'")"
  K="$(ed -c "select id from nomina_corridas where estado = 'importada' order by importada_el desc limit 1")"
  for p in "ZZ Ayudante Uno|0c3101|campo" "ZZ Ayudante Dos|0c3102|campo" "ZZ Oficial Tres|0c3103|oficial"; do
    IFS='|' read -r nom suf cla <<< "$p"
    dueno "fn_nomina_persona(jsonb_build_object('id', (select id from nomina_personas where clave = fn_nomina_clave('$nom')), 'usuario_id', '00000000-0000-4000-a000-000000$suf', 'clase', '$cla', 'confirmar', true))->>'confirmada'" > /dev/null
  done
  dueno "fn_nomina_config('{\"cuenta_sin_obra\": \"6000\"}')->>'cuenta_sin_obra'" > /dev/null
  POST="$(dueno "(select (r->'asiento'->>'fecha') || ' · ' || (r->>'horas') || ' horas' from fn_nomina_postear('$K', fn_nomina_propuesta('$K')->>'visto') r)")"
}

echo
echo "== 1. Sin la nómina (c15 todavía no está): diciembre se devenga como siempre"
reloj 2027-01-04
revisa "c3 es el de la Fase 11b, y la nómina no está" "2026111301|no_esta" \
  "$(ed -c "select (select substring(p.prosrc from '([0-9]{10})') from pg_proc p where p.oid = 'public.fn_puente_version()'::regprocedure) || '|' || (fn_puente_devengo_plan('2026-12')->'corte'->>'marca')")"
revisa "devengar diciembre (el dueño, sin el código del teléfono)" "posteado" "$(devengar 2026-12 aal1)"
D12="$(numero 2026-12)"
revisa "diciembre: todas sus horas aprobadas con obra y con costo, a su tarifa" "a 580.00 · b 440.00 · b CO #1 200.00 = 1220.00" "$(devengo 2026-12)"

echo
echo "== 2. Llega c15 (encima, sin volver a pegar c3)"
pegar "$DOCS/c15-nomina.sql" > "$TMP/2c15.out" 2>&1 || { tail -n 20 "$TMP/2c15.out"; echo "FALLÓ pegar c15 encima de c3" >&2; exit 2; }
revisa "c3 ya lee el corte de la nómina (su marca sin dinero), sin que nadie lo toque" "ok|0" \
  "$(ed -c "select (pl->'corte'->>'marca') || '|' || (pl->'corte'->>'reportes') from (select fn_puente_devengo_plan('2026-12') as pl) x")"
revisa "el devengo de diciembre sigue al día: el control en verde y devengar no hace nada" "true/0|sin_cambios|$D12" "$(control)|$(devengar 2026-12 aal1)|$(numero 2026-12)"

echo
echo "== 3. El cierre de año: la nómina del 8-ene paga las horas de diciembre, y su journal es de enero"
reloj 2027-01-08
nomina 12/20/2026 01/02/2027 01/08/2027; K1="$K"
revisa "la nómina del 8-ene: importada y posteada en su día de pago, con las horas de diciembre de su período" "nueva|2027-01-08 · 8 horas" "$IMP|$POST"
revisa "la marca de la nómina dice que las pagó (el dueño, sin el código)" "8 reportes, del 2026-12-21 al 2026-12-30" \
  "$(como aal1 "(select count(*) || ' reportes, del ' || min(h.fecha) || ' al ' || max(h.fecha) from fn_nomina_horas_con_pago() n join horas h on h.id = n.horas_id)")"
revisa "diciembre devengado NO se mueve: sus horas se pagaron DESPUÉS del fin de diciembre" "true/0|sin_cambios|$D12|a 580.00 · b 440.00 · b CO #1 200.00 = 1220.00" \
  "$(control)|$(devengar 2026-12 aal1)|$(numero 2026-12)|$(devengo 2026-12)"
revisa "en el libro, diciembre lleva su costo a estándar (el devengo)" "a 580.00 · b 440.00 · b CO #1 200.00" "$(libro 2026-12)"
J1="$(ed -c "select string_agg(concat_ws(' ', replace(l.proyecto_id, 'c3-nom-', ''), l.co) || ' ' || l.monto, ' · ' order by l.proyecto_id, l.co nulls first) from (select m.proyecto_id, m.co, sum(m.monto) as monto from asiento_lineas m join nomina_corridas c on c.asiento_id = m.asiento_id where c.id = '$K1' and m.cuenta = '5000' group by 1, 2) l")"
revisa "y enero, el reverso del día 1 y el journal de la nómina: cada hora, pagada una vez" "sí" \
  "$(ed -c "select case when count(*) = 0 then 'sí' else 'no: ' || string_agg(q.obra || ' ' || q.libro || ' <> ' || q.debe, ', ') end
              from (select coalesce(x.obra, y.obra) as obra, coalesce(x.s, 0) as libro, coalesce(y.s, 0) as debe
                      from (select concat_ws(' ', l.proyecto_id, l.co) as obra, sum(l.monto) as s from asiento_lineas l join asientos a on a.id = l.asiento_id
                             where l.proyecto_id like 'c3-nom-%' and l.cuenta = '5000' and a.periodo = '2027-01' group by 1) x
                      full join (select concat_ws(' ', l.proyecto_id, l.co) as obra, sum(l.monto) as s
                                   from (select m.proyecto_id, m.co, m.monto from asiento_lineas m join nomina_corridas c on c.asiento_id = m.asiento_id
                                          where c.id = '$K1' and m.cuenta = '5000'
                                         union all
                                         select m.proyecto_id, m.co, -m.monto from asiento_lineas m join asientos a on a.id = m.asiento_id
                                          where a.numero = '$D12' and m.cuenta = '5000') l group by 1) y on y.obra = x.obra) q
             where q.libro <> q.debe")"
echo "     (el journal del 8-ene en 5000: $J1 · enero en el libro: $(libro 2027-01))"

echo
echo "== 4. Un mes con nómina se devenga: enero, antes y después de su nómina"
reloj 2027-01-21
revisa "enero ya tiene el journal de una nómina (la del 8-ene) y SE DEVENGA: todas sus horas siguen sin pagar" "posteado|a 720.00 · b 680.00 · b CO #1 125.00 = 1525.00" \
  "$(devengar 2027-01 aal1)|$(devengo 2027-01)"
reloj 2027-01-22
nomina 01/03/2027 01/16/2027 01/22/2027; K2="$K"
revisa "la nómina del 22-ene, posteada con las horas de su período" "nueva|2027-01-22 · 6 horas" "$IMP|$POST"
revisa "al postearla, el devengo de enero se puso al día solo: queda LA COLA (lo de después del período, sin pagar)" \
  "true/0|a 320.00 · b CO #1 125.00 = 445.00" "$(control)|$(devengo 2027-01)"
D01="$(numero 2027-01)"
revisa "y el asiento dice lo que dejó fuera y qué journal lo pagó" "5 reportes, 40 h, sí" \
  "$(ed -c "select (a.procedencia->'documento'->'pagadas'->>'reportes') || ' reportes, ' || trim_scale((a.procedencia->'documento'->'pagadas'->>'horas')::numeric) || ' h, ' || case when a.procedencia->'documento'->'pagadas'->'journals' = jsonb_build_array((select c.asiento_numero from nomina_corridas c where c.id = '$K2')) and a.procedencia->>'corte_nomina' like '%que la nómina ya había pagado%' then 'sí' else 'no' end from asientos a where a.numero = '$D01'")"
revisa "al centavo, lo que dice la cola de la nómina (con el código del teléfono)" "445.00" \
  "$(dueno "(select sum(q.estandar) from fn_nomina_cola('2027-01') q where q.proyecto_id like 'c3-nom-%')")"

echo
echo "== 5. La misma respuesta en toda sesión"
revisa "el control devengo: el SQL Editor, el dueño sin el código y con él" "true/0|true/0|true/0" "$(control)|$(control aal1)|$(control aal2)"
revisa "volver a devengar enero no hace nada: el SQL Editor, sin el código y con él" "sin_cambios|sin_cambios|sin_cambios" \
  "$(devengar 2027-01)|$(devengar 2027-01 aal1)|$(devengar 2027-01 aal2)"
revisa "la cola de la nómina, SIN el código, dice «nada» (por eso c3 no la lee: daría por pagado lo que no lo está)" "0 filas" \
  "$(como aal1 "(select count(*) || ' filas' from fn_nomina_cola('2027-01') q)")"
revisa "y la marca sin dinero dice lo mismo con el código que sin él" "sí" \
  "$(a="$(como aal1 "(select count(*) || ':' || md5(string_agg(n.horas_id::text, ',' order by n.horas_id)) from fn_nomina_horas_con_pago() n)")"; b="$(como aal2 "(select count(*) || ':' || md5(string_agg(n.horas_id::text, ',' order by n.horas_id)) from fn_nomina_horas_con_pago() n)")"; [ -n "$a" ] && [ "$a" = "$b" ] && echo sí || echo "no: $a / $b")"

echo
echo "== 6. La nómina del mes siguiente (5-feb) paga la cola"
reloj 2027-02-05
nomina 01/17/2027 01/30/2027 02/05/2027; K3="$K"
revisa "la nómina del 5-feb, posteada con la cola de enero" "nueva|2027-02-05 · 4 horas" "$IMP|$POST"
revisa "enero NO se mueve (su cola se pagó después del fin de enero)" "true/0|sin_cambios|$D01|a 320.00 · b CO #1 125.00 = 445.00" \
  "$(control)|$(devengar 2027-01 aal1)|$(numero 2027-01)|$(devengo 2027-01)"
revisa "entre diciembre, enero y febrero, el 5000 de las obras es el de los tres journals: nada dos veces" "sí" \
  "$(ed -c "select case when l.s = j.s and l.s > 0 then 'sí' else 'no: el libro ' || l.s || ', los journals ' || j.s end
              from (select sum(m.monto) as s from asiento_lineas m join asientos a on a.id = m.asiento_id
                     where m.proyecto_id like 'c3-nom-%' and m.cuenta = '5000' and a.periodo in ('2026-12', '2027-01', '2027-02')) l,
                   (select sum(m.monto) as s from asiento_lineas m join nomina_corridas c on c.asiento_id = m.asiento_id
                     where c.estado = 'posteada' and m.proyecto_id like 'c3-nom-%' and m.cuenta = '5000') j")"
revisa "el control «mano de obra» sigue en verde con nómina y devengo en el mismo mes (también sin el código)" "true|true" \
  "$(ed -c "select c.ok::text from fn_puentes_verificar() c where c.control = 'mano_de_obra'")|$(como aal1 "(select c.ok::text from fn_puentes_verificar() c where c.control = 'mano_de_obra')")"
echo "     (diciembre: $(libro 2026-12) · enero: $(libro 2027-01) · febrero: $(libro 2027-02))"

echo
echo "== 7. Anular la nómina del 22-ene y volver a subirla"
revisa "anulada: suelta sus horas, y dice que puso al día el devengo de enero" "anulada|sí" \
  "$(dueno "(select 'anulada|' || case when r->>'devengo' like 'El mes 2027-01 tenía un devengo estándar de horas: se puso al día aquí mismo (asiento %' then 'sí' else coalesce(r->>'devengo', 'no lo dice') end from fn_nomina_anular('$K2', 'ZZ C3 NOM: se anula para ver el devengo') r where r->>'reverso' is not null)")"
revisa "el devengo de enero ya es el de hoy (lo puso al día la nómina al anular: vuelven sus horas; la cola sigue: la del 5-feb la pagó después del fin de enero), y el control sigue en verde" \
  "a 720.00 · b 680.00 · b CO #1 125.00 = 1525.00|true/0" "$(devengo 2027-01)|$(control)"
revisa "devengar otra vez no cambia nada" "sin_cambios|a 720.00 · b 680.00 · b CO #1 125.00 = 1525.00|true/0" "$(devengar 2027-01 aal1)|$(devengo 2027-01)|$(control)"
nomina 01/03/2027 01/16/2027 01/22/2027; K2="$K"
revisa "subida y posteada otra vez, queda otra vez solo la cola" "nueva|2027-01-22 · 6 horas|a 320.00 · b CO #1 125.00 = 445.00|true/0" \
  "$IMP|$POST|$(devengo 2027-01)|$(control)"
D01="$(numero 2027-01)"

echo
echo "== 8. El cierre del mes, con su nómina y su devengo dentro (se deshace)"
revisa "enero se cierra con su devengo al día; desfasado (una hora más aprobada), no, y dice cómo" "cerrado|MX008/dice_como" \
  "$(ed -v ON_ERROR_STOP=1 <<'SQL' 2>&1 | sed -n 's/^.*RESULTADO //p; /ERROR/p'
begin;
do $$
declare
  v_a text; v_b text; v_q text;
  v_d uuid := (select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1);
begin
  lock table public.periodos in exclusive mode;
  -- (la apertura, de prueba, si la base no la trae; y los meses de antes, en orden)
  if not exists (select 1 from asientos a where a.tipo = 'apertura') then
    perform fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', (select to_char(p.desde, 'YYYY-MM-DD') from periodos p where p.tipo = 'apertura' order by p.desde limit 1),
      'descripcion', 'ZZ C3 NOM: apertura de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1010', 'monto', '1000.00'), jsonb_build_object('cuenta', '3900', 'monto', '-1000.00'))));
  end if;
  begin
    for v_q in select p.periodo from periodos p where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= date '2027-01-01' order by p.desde loop
      perform fn_cerrar_periodo(v_q);
    end loop;
    select p.estado into v_a from periodos p where p.periodo = '2027-01';
    raise exception using errcode = 'MXT01';
  exception when sqlstate 'MXT01' then null;
  end;
  insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el)
  values ('2027-01-26', '00000000-0000-4000-a000-0000000c3101', 'c3-nom-a', 3, null, 'ZZ C3 NOM', v_d, now());
  begin
    for v_q in select p.periodo from periodos p where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= date '2027-01-01' order by p.desde loop
      perform fn_cerrar_periodo(v_q);
    end loop;
    v_b := 'cerrado';
  exception when others then
    v_b := sqlstate || case when sqlerrm like '%desfasado%' and sqlerrm like '%fn_horas_devengar(''2027-01'')%' then '/dice_como' else ': ' || sqlerrm end;
  end;
  raise notice 'RESULTADO %|%', v_a, v_b;
end $$;
rollback;
SQL
)"

echo
echo "== 9. Si la nómina no dice qué horas pagó (su marca, quitada: como un c15 de antes del 13-nov; se deshace)"
revisa "el devengo de enero convive con el journal (rojo); devengar lo deshace; otra vez se niega y manda a pegar c15" "f/convive|reversado|MX008/pegar_c15" \
  "$(ed -v ON_ERROR_STOP=1 <<'SQL' 2>&1 | sed -n 's/^.*RESULTADO //p; /ERROR/p'
begin;
set local lock_timeout = '2s';
drop function public.fn_nomina_horas_con_pago();
do $$
declare
  v_a text; v_b text; v_c text;
begin
  select case when c.ok then 't' else 'f' end || case when c.detalle::text like '%el devengo de 2027-01 (%convive con el journal de nómina%' then '/convive' else '' end
    into v_a from fn_puentes_verificar() c where c.control = 'devengo';
  v_b := fn_horas_devengar('2027-01')->>'accion';
  begin
    perform fn_horas_devengar('2027-01');
    v_c := 'entró';
  exception when others then
    v_c := sqlstate || case when sqlerrm like '%todavía no lo dice%' and sqlerrm like '%Vuelve a pegar c15-nomina.sql%' then '/pegar_c15' else ': ' || sqlerrm end;
  end;
  raise notice 'RESULTADO %|%|%', v_a, v_b, v_c;
end $$;
rollback;
SQL
)"
revisa "deshecho eso, todo como estaba: la marca, el devengo de enero y el control" "fn_nomina_horas_con_pago()|$D01|true/0" \
  "$(ed -c "select to_regprocedure('public.fn_nomina_horas_con_pago()')")|$(numero 2027-01)|$(control)"

echo
echo "== 9b. Un mes grande: el control «devengo» contesta dentro del tope de la API (se deshace)"
# (1,500 reportes de un cuarto de hora de una persona por horas, aprobados, en febrero de 2027; devengado el mes, el control
# de los puentes se pide como la app: el dueño, sin el código, con los ajustes de su rol y el tope de 8 s)
revisa "con 1,500 reportes devengados en un mes, el control de los puentes contesta al dueño por la API (tope de 8 s) y sigue en verde" "posteado true/0" \
  "$(ed -v ON_ERROR_STOP=1 2>&1 <<SQL | sed -n 's/^RESULTADO //p; s/^.*ERROR: *//p' | tr '\n' ' ' | sed 's/ *$//'
begin;
insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el)
select date '2027-02-08' + (g % 19), '00000000-0000-4000-a000-0000000c3101', 'c3-nom-a', 0.25, null, 'ZZ C3 NOM: mes grande', '$DUENO', now()
  from generate_series(1, 1500) g;
select 'RESULTADO ' || (fn_horas_devengar('2027-02')->>'accion');
$(app aal1)
select 'RESULTADO ' || $CTL;
rollback;
SQL
)"
revisa "y deshecho, febrero queda sin devengo y sin esas horas" "-|0" "$(numero 2027-02)|$(ed -c "select count(*) from horas where notas = 'ZZ C3 NOM: mes grande'")"

echo
echo "== 10. Volver a pegar c3 (dos veces) con todo dentro, y sus pruebas"
reloj_de_verdad
for i in 1 2; do
  pegar "$DOCS/c3-puentes.sql" > "$TMP/10c3-$i.out" 2>&1 || { tail -n 20 "$TMP/10c3-$i.out"; echo "FALLÓ volver a pegar c3 (vez $i)" >&2; exit 2; }
done
revisa "los devengos son los mismos asientos, y el control sigue en verde" "$D12|$D01|true/0" "$(numero 2026-12)|$(numero 2027-01)|$(control)"
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" \
  -c '\o /dev/null' -f "$DOCS/c3-pruebas.sql" -c '\o' \
  -c "select format('PRUEBAS total=%s ok=%s fallan=%s omitidas=%s', count(*), count(*) filter (where ok), count(*) filter (where not ok), count(*) filter (where ok is null)) from _pruebas" \
  -c "select n || ' ' || case when ok is null then 'omitida' else 'FALLA' end || ': ' || left(coalesce(obtenido, ''), 300) from _pruebas where ok is not true order by n" \
  -At > "$TMP/10pruebas.out" 2>&1 || { tail -n 20 "$TMP/10pruebas.out"; echo "FALLÓ c3-pruebas.sql" >&2; exit 2; }
grep -E '^PRUEBAS|^[0-9]+ (FALLA|omitida)' "$TMP/10pruebas.out" | sed 's/^/     /'
revisa "c3-pruebas.sql con las nóminas de verdad dentro: ninguna falla" "0" "$(sed -n 's/^PRUEBAS .* fallan=\([0-9]*\) .*/\1/p' "$TMP/10pruebas.out")"
revisa "y las del corte de la nómina (de la 121 a la 126) corrieron: ninguna omitida" "0" \
  "$(grep -cE '^12[1-6] omitida' "$TMP/10pruebas.out")"

echo
echo "== Al final"
revisa "la cadena del libro, en verde (los permisos y las huellas también, con el reloj de vuelta)" "" \
  "$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_verificar_cadena() where not ok")"
revisa "los puentes (c3), sin nada nuevo en rojo" "$ROJOS_C3" "$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_puentes_verificar() where not ok")"
revisa "los cuadres de la nómina, sin rojos" "" \
  "$(ed -c "select coalesce(string_agg(orden::text, ', ' order by orden), '') from fn_nomina_control() where not ok and nivel = 'cuadre'")"

echo
if [ $malos -eq 0 ]; then echo "c3-nomina: todo en orden"; else echo "c3-nomina: ALGO FALLA (arriba)"; fi
exit $malos
