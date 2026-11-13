#!/usr/bin/env bash
# =====================================================================
# c6-nomina.sh — lo que c6-pruebas.sql solo puede fingir: el banco (c6) y
# los papeles de los estados (c4) con UNA NÓMINA DE VERDAD de c15 dentro,
# por la puerta del dueño, y con la app leyendo A LA VEZ que se pega
# (13-nov-2026, Fase 11b: la costura de c6 con la nómina de Gusto).
#
#   ./c6-nomina.sh [nombre_bd]      (por defecto c6_nomina)
#
# Crea su base con c1 + c2 + c3 + c4 + c6 (dos veces) + c10, SIN la nómina;
# después pega c15 encima, sin volver a pegar c6 (el banco se pega antes y
# la nómina es opcional: la vista de los papeles la lee al vuelo, llegue
# cuando llegue). Tres personas, dos obras y sus horas aprobadas, y el
# «Payroll journal» sintético de pruebas/conta/nomina/zz-payroll-journal.csv
# con las fechas movidas a hoy (día de pago: hoy; Gusto cobró hace tres días).
#   1. SIN LA NÓMINA: fn_banco_papel_nomina() no devuelve nada, las
#      protecciones del banco en verde, y un cargo de Gusto en la Bandeja
#      dice el camino de hoy (Contabilidad → Nómina → Cargos de Gusto), no
#      «espera el journal (f11)».
#   2. LLEGA c15 (encima, dos veces, sin tocar c6): las protecciones del
#      banco siguen en verde (la vista sellada de los papeles no cambió) y,
#      sin ninguna nómina, la función sigue sin devolver nada.
#   3. UNA NÓMINA DE VERDAD: importada, su gente enlazada, posteada, y sus
#      cargos de Gusto casados. Sus dos asientos (el journal y el reparto de
#      su burden) tienen SU PAPEL en v_asiento_papel (c4), el de c15, tal
#      cual: desde el SQL Editor y el dueño por la API con su código.
#   4. SIN EL CÓDIGO DEL TELÉFONO (el dueño con la sesión en aal1): el papel
#      dice que está y que se ve con el código —no «el papel ya no está»—,
#      sin una cifra; la vista de c15 leída directo sigue dando cero filas
#      (la puerta de c15 no se abre); al equipo, nada; anon no la ejecuta.
#   5. LA BANDEJA Y LA CONCILIACIÓN: el cargo de Gusto suelto y una
#      DEVOLUCIÓN de Gusto (un depósito) salen los dos con el motivo
#      «nomina» (R6) y la nómina los tiene en su lista; clasificarlos a mano
#      sin motivo, o registrarle a la devolución el cobro de un cliente sin
#      su porqué, MX008 con su camino; a la conciliación le faltan «2
#      movimiento(s) de nómina (Gusto) sin casar»; y resuelto el cargo desde
#      la nómina (la cuota de Gusto), queda casado.
#   6. ANULAR LA NÓMINA (des-casando sus cargos) Y VOLVER A SUBIRLA: sus
#      seis asientos (los dos de antes, sus dos reversos y los dos nuevos)
#      tienen su papel.
#   7. c4-pruebas.sql y c6-pruebas.sql con la nómina de verdad dentro:
#      ninguna falla (la 25 de c4, «toda cifra baja a su asiento y a su
#      papel», fallaba con una nómina en el libro).
#   8. A LA VEZ (lo que una sola sesión no puede probar): un lector como la
#      app lee sin parar el papel de un asiento de la nómina MIENTRAS se
#      pega c15-nomina.sql (que borra y rehace sus vistas) y MIENTRAS se
#      pega c6-banco.sql (que rehace la vista de los papeles), con el código
#      y sin él: ninguna lectura falla ni trae un papel a medias. Y con un
#      lector dentro de su transacción, el pegado para con 55P03 (medio
#      segundo) sin cambiar nada, y entra cuando el lector termina.
#   9. VOLVER A PEGAR c6 (dos veces) con todo dentro: sus 7 filas en true,
#      las huellas selladas son las de hoy y nada de sus tablas cambia.
# Y comprueba al final: la cadena del libro en verde (los permisos
# también), los puentes (c3) sin nada nuevo en rojo, la revisión entera del
# banco (fn_banco_verificar) y los cuadres de la nómina sin rojos.
#
# Cada sesión de «la app» va como por PostgREST: con el rol authenticated,
# los ajustes de ese rol y el tope de la API (8 s); el dueño con su código
# (aal2) o sin él (aal1), o alguien del equipo. Nombres y montos inventados
# («ZZ…», «ZZ C6 NOM»): nada de producción.
#
# Variables: PGHOST (127.0.0.1) y PGPORT (5432), como correr.sh.
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c6_nomina}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'touch "$TMP/alto" 2>/dev/null; echo "(La base $BD y $TMP quedan: ./correr.sh --borrar $BD; rm -rf $TMP)"' EXIT
else
  trap 'touch "$TMP/alto" 2>/dev/null; "$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }
# (pegar un archivo como el SQL Editor: una transacción, para al primer error)
pegar() { PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$1"; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

# La escena, como el SQL Editor: dos obras, tres personas (su usuario, su
# perfil de campo; dos con su tarifa) y sus horas APROBADAS del período de
# pago (los 14 días que terminan 6 días antes de hoy; el día de pago, hoy).
cat > "$TMP/montar.sql" <<'SQL'
insert into proyectos (id, tipo, nombre, estado) values
  ('c6-nom-a', 'comercial', 'ZZ C6 NOM Obra A', 'ejecucion'),
  ('c6-nom-b', 'servicio',  'ZZ C6 NOM Obra B', 'ejecucion');
do $$
declare
  r record;
  v_d uuid := (select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1);
  v_0 date := fn_fecha_miami(now()) - 19;
begin
  for r in select * from (values ('00000000-0000-4000-a000-0000000c6001'::uuid, 'ZZ Ayudante Uno'),
                                 ('00000000-0000-4000-a000-0000000c6002'::uuid, 'ZZ Ayudante Dos'),
                                 ('00000000-0000-4000-a000-0000000c6003'::uuid, 'ZZ Oficial Tres')) as x(id, nombre) loop
    insert into auth.users (id, email) values (r.id, 'c6-nom-' || right(r.id::text, 2) || '@c6-pruebas.invalid') on conflict (id) do nothing;
    insert into perfiles (id, nombre, rol, activo) values (r.id, r.nombre, 'campo', true)
    on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
  end loop;
  insert into costos_equipo (usuario_id, costo_hora) values
    ('00000000-0000-4000-a000-0000000c6001', 25), ('00000000-0000-4000-a000-0000000c6002', 30)
  on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
  insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el) values
    (v_0 + 1, '00000000-0000-4000-a000-0000000c6001', 'c6-nom-a', 8,  null,    'ZZ C6 NOM', v_d, now()),
    (v_0 + 2, '00000000-0000-4000-a000-0000000c6001', 'c6-nom-a', 8,  null,    'ZZ C6 NOM', v_d, now()),
    (v_0 + 3, '00000000-0000-4000-a000-0000000c6001', 'c6-nom-b', 10, 'CO #1', 'ZZ C6 NOM', v_d, now()),
    (v_0 + 4, '00000000-0000-4000-a000-0000000c6001', null,       4,  null,    'ZZ C6 NOM', v_d, now()),
    (v_0 + 1, '00000000-0000-4000-a000-0000000c6002', 'c6-nom-b', 8,  null,    'ZZ C6 NOM', v_d, now()),
    (v_0 + 5, '00000000-0000-4000-a000-0000000c6003', 'c6-nom-a', 10, null,    'ZZ C6 NOM', v_d, now()),
    (v_0 + 6, '00000000-0000-4000-a000-0000000c6003', 'c6-nom-a', 10, null,    'ZZ C6 NOM', v_d, now());
end $$;
SQL

echo "== Base $BD: c1 + c2 + c3 + c4 + c6 (dos veces) + c10, SIN la nómina, y lo de este script"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$DOCS/c6-banco.sql" "$DOCS/c10-costo-obra.sql" "$TMP/montar.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
EQUIPO="$(ed -c "select id from perfiles where rol <> 'dueno' and coalesce(activo, true) and nombre not like 'ZZ %' order by creado limit 1")"
HOY="$(ed -c "select fn_fecha_miami(now())")"
MES="$(ed -c "select p.periodo from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and fn_fecha_miami(now()) between p.desde and p.hasta")"
[ -n "$DUENO" ] && [ -n "$EQUIPO" ] && [ -n "$MES" ] || { echo "No hay un dueño, o nadie del equipo, o el mes de hoy no está abierto: no hay dónde postear" >&2; exit 2; }
dia() { ed -c "select date '$HOY' - $1"; }                       # el día de hace N días
us()  { ed -c "select to_char(date '$HOY' - $1, 'MM/DD/YYYY')"; }
D1="$(dia 1)"; D3="$(dia 3)"; D4="$(dia 4)"
ROJOS_C3="$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_puentes_verificar() where not ok")"

# Como la app por PostgREST: con el rol authenticated, los ajustes de ese
# rol y el tope de la API (8 s). app <usuario> <aal1|aal2>.
app() {
  echo "select set_config('request.jwt.claims', '{\"sub\":\"$1\",\"role\":\"authenticated\",\"aal\":\"$2\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"
}
# como <usuario> <aal1|aal2> <sql que devuelve un texto>: lo que devuelve, o su error (:'arch' = el journal)
como() {
  ed -v ON_ERROR_STOP=1 -v arch="${ARCH:-{\}}" 2>&1 <<SQL | sed -n 's/^RESULTADO //p; s/^.*ERROR: *//p'
begin; $(app "$1" "$2")
select 'RESULTADO ' || coalesce(($3)::text, '(nulo)');
commit;
SQL
}
dueno() { como "$DUENO" aal2 "$1"; }
# un movimiento de Gusto en el banco, como lo trae Plaid, y «Casar» solo para él (c6 lo deja en la Bandeja); devuelve su id.
# movimiento <id> <monto de Plaid: + sale, − entra> <descripción> <fecha>
movimiento() {
  dueno "(select 'x' from (select fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c6-nom · $1', 'filas', jsonb_build_array(jsonb_build_object('id', '$1', 'fecha', '$4', 'plaid_monto', '$2', 'descripcion', '$3', 'tipo', case when '$2'::numeric > 0 then 'DEBIT' else 'CREDIT' end, 'pendiente', false))))) z)" > /dev/null
  local m; m="$(ed -c "select id from movimientos_banco where id_externo = '$1' order by importado_el desc limit 1")"
  dueno "(select 'x' from (select fn_banco_casar('$m')) z)" > /dev/null
  echo "$m"
}
# las protecciones del banco (su cuadre): t, o lo que dice
protecciones() { ed -c "select case when c.ok then 't' else left(c.detalle, 300) end from fn_banco_control('hoy', array['v_banco_saldos']) c where c.vista = 'cuadre: protecciones del banco'"; }
# el papel de los asientos de la nómina, en una línea: origen:existe:qué dice
PAPEL="(select coalesce(string_agg(p.origen_tabla || ':' || p.papel_existe::text || ':' || case when p.papel = n.papel then 'el de c15' else left(p.papel, 60) end, ' · ' order by p.numero), 'ninguno')
          from v_asiento_papel p left join v_nomina_papel n on n.origen_tabla = p.origen_tabla and n.origen_id = p.origen_id
         where p.origen_tabla in ('nomina_corridas', 'nomina_burden'))"
SINCOD="(select coalesce(string_agg(p.origen_tabla || ':' || p.papel_existe::text || ':' || case when p.papel like '%código del teléfono%' and p.papel !~ '[\$0-9]' then 'con el código, sin cifras' else left(p.papel, 60) end, ' · ' order by p.numero), 'ninguno')
           from v_asiento_papel p where p.origen_tabla in ('nomina_corridas', 'nomina_burden'))"

echo
echo "== 1. Sin la nómina (c15 todavía no está)"
revisa "la función de los papeles no devuelve nada, y la vista de los papeles tampoco tiene nada de nómina" "0|0" \
  "$(ed -c "select (select count(*) from fn_banco_papel_nomina()) || '|' || (select count(*) from v_papel_fases f where f.origen_tabla in ('nomina_corridas', 'nomina_burden'))")"
revisa "las protecciones del banco, en verde" "t" "$(protecciones)"
M0="$(movimiento "c6-nom-fee" 49.00 'GUSTO FEE 5c6 ZZ C6 NOM' "$D4")"
revisa "un cargo de Gusto en la Bandeja: motivo nomina (R6), y dice el camino de hoy (no «espera el journal»)" "nomina|R6|sí" \
  "$(ed -c "select b.motivo || '|' || (b.propuesta->>'regla') || '|' || case when b.texto like 'Débito de nómina (Gusto): se casa desde Contabilidad → Nómina → Cargos de Gusto, con lo que su nómina dejó por pagar%' and b.texto not like '%f11%' and b.texto not like '%espera el journal%' then 'sí' else 'no: ' || left(b.texto, 90) end from v_banco_bandeja b where b.movimiento_id = '$M0'")"
revisa "y su descriptor dice lo mismo" "sí" \
  "$(ed -c "select case when d.para like 'Débito de nómina (Gusto): se casa desde Contabilidad → Nómina → Cargos de Gusto%' then 'sí' else left(d.para, 90) end from banco_descriptores d where d.clave = 'nomina'")"

echo
echo "== 2. Llega c15 (encima, dos veces, sin volver a pegar c6)"
pegar "$DOCS/c15-nomina.sql" > "$TMP/2a.out" 2>&1; revisa "c15 entra con este c6 ya pegado" "0" "$?"
pegar "$DOCS/c15-nomina.sql" > "$TMP/2b.out" 2>&1; revisa "y otra vez" "0" "$?"
grep -h 'ERROR' "$TMP/2a.out" "$TMP/2b.out" | head -n 4
revisa "las protecciones del banco siguen en verde: la vista sellada de los papeles no cambió" "t" "$(protecciones)"
revisa "sin ninguna nómina en el libro, la función sigue sin devolver nada" "0" "$(ed -c "select count(*) from fn_banco_papel_nomina()")"

echo
echo "== 3. Una nómina de verdad: importada, posteada (día de pago: hoy) y sus cargos de Gusto de hace tres días, casados"
csv="$(sed -e "s#01/03/2027#$(us 19)#g" -e "s#01/16/2027#$(us 6)#g" -e "s#01/22/2027#$(us 0)#g" "$DIR/nomina/zz-payroll-journal.csv")"
ARCH="$(ed -v csv="$csv" -v nombre="zz-payroll-journal.csv" <<'SQL'
select jsonb_build_object('nombre', :'nombre', 'sha256', encode(sha256(convert_to(:'csv', 'UTF8')), 'hex'), 'bytes', octet_length(:'csv'),
                          'filas', (select jsonb_agg(to_jsonb(string_to_array(t.l, ',')) order by t.n)
                                      from unnest(string_to_array(:'csv', E'\n')) with ordinality as t(l, n)))::text;
SQL
)"
[ -n "$ARCH" ] || { echo "No se pudo armar el archivo de prueba" >&2; exit 2; }
# la nómina entera, por la puerta del dueño: importar, (enlazar a su gente), postear y casar sus dos cargos
nomina() {
  local r; r="$(dueno "fn_nomina_importar(:'arch'::jsonb)->'corridas'->0->>'resultado'")"
  K="$(ed -c "select id from nomina_corridas where estado = 'importada' order by importada_el desc limit 1")"
  for p in "ZZ Ayudante Uno|0c6001|campo" "ZZ Ayudante Dos|0c6002|campo" "ZZ Oficial Tres|0c6003|oficial"; do
    IFS='|' read -r nom suf cla <<< "$p"
    dueno "fn_nomina_persona(jsonb_build_object('id', (select id from nomina_personas where clave = fn_nomina_clave('$nom')), 'usuario_id', '00000000-0000-4000-a000-000000$suf', 'clase', '$cla', 'confirmar', true))->>'confirmada'" > /dev/null
  done
  dueno "fn_nomina_config('{\"cuenta_sin_obra\": \"6000\"}')->>'cuenta_sin_obra'" > /dev/null
  r="$r|$(dueno "(select case when z.r->'asiento'->>'numero' is not null then 'posteada' else z.r::text end from (select fn_nomina_postear('$K', fn_nomina_propuesta('$K')->>'visto') as r) z)")"
  if [ -z "${M1:-}" ]; then
    M1="$(movimiento "c6-nom-net" 4874.93 'GUSTO NET 7c6 ZZ C6 NOM' "$D3")"
    M2="$(movimiento "c6-nom-tax" 1583.31 'GUSTO TAX 7c6 ZZ C6 NOM' "$D3")"
  fi
  r="$r|$(dueno "(select case when z.r->>'asiento' is not null then 'el neto casado' else z.r::text end from (select fn_nomina_cargo_casar('$M1', fn_nomina_cargo_propuesta('$M1')->'opciones'->0->'partes') as r) z)")"
  r="$r|$(dueno "(select case when z.r->>'asiento' is not null then 'los impuestos casados' else z.r::text end from (select fn_nomina_cargo_casar('$M2', fn_nomina_cargo_propuesta('$M2')->'opciones'->0->'partes') as r) z)")"
  echo "$r"
}
M1=""; M2=""; K=""
revisa "la nómina entra por la puerta del dueño: importada, posteada, y sus dos cargos casados" "nueva|posteada|el neto casado|los impuestos casados" "$(nomina)"
K="$(ed -c "select id from nomina_corridas where estado = 'posteada' order by posteada_el desc limit 1")"
M1="$(ed -c "select id from movimientos_banco where id_externo = 'c6-nom-net'")"; M2="$(ed -c "select id from movimientos_banco where id_externo = 'c6-nom-tax'")"
ASI="$(ed -c "select asiento_id from nomina_corridas where id = '$K'")"
revisa "sus dos asientos tienen su papel en v_asiento_papel (c4): el de c15, tal cual (desde el SQL Editor)" \
  "nomina_corridas:true:el de c15 · nomina_burden:true:el de c15" "$(ed -c "select $PAPEL")"
revisa "el papel del journal dice su nómina: el día de pago, el período, sus personas, su bruto y su neto" "sí" \
  "$(ed -c "select case when p.papel like 'Nómina de Gusto del % · período del % al % · 3 persona(s) · bruto \$% · neto \$% · posteada' then 'sí' else left(p.papel, 120) end from v_asiento_papel p where p.asiento_id = '$ASI'")"
revisa "el dueño por la API, con su código, ve lo mismo que el SQL Editor" "$(ed -c "select $PAPEL")" "$(como "$DUENO" aal2 "$PAPEL")"
revisa "y la función devuelve lo mismo que la vista de c15" "0" \
  "$(ed -c "select count(*) from ((select f.origen_tabla, f.origen_id, f.papel, f.ruta from fn_banco_papel_nomina() f except select n.origen_tabla, n.origen_id, n.papel, n.ruta from v_nomina_papel n)
                                 union all (select n.origen_tabla, n.origen_id, n.papel, n.ruta from v_nomina_papel n except select f.origen_tabla, f.origen_id, f.papel, f.ruta from fn_banco_papel_nomina() f)) x")"
revisa "las protecciones del banco, en verde con la nómina dentro" "t" "$(protecciones)"

echo
echo "== 4. Sin el código del teléfono (el dueño con la sesión en aal1), el equipo y anon"
revisa "sin el código, el papel dice que está y que se ve con él: papel_existe = sí, sin una cifra (no «el papel ya no está»)" \
  "nomina_corridas:true:con el código, sin cifras · nomina_burden:true:con el código, sin cifras" "$(como "$DUENO" aal1 "$SINCOD")"
revisa "la puerta de c15 no se abre: su vista, leída directo sin el código, da cero filas; y la función, lo mismo que la vista de c4" "0|2|0" \
  "$(como "$DUENO" aal1 "(select (select count(*) from v_nomina_papel) || '|' || (select count(*) from fn_banco_papel_nomina()) || '|' || (select count(*) from fn_banco_papel_nomina() f where f.papel ~ '[\$0-9]' or f.papel not like '%código del teléfono%'))")"
revisa "al equipo, nada: ni asientos, ni papeles de nómina por la vista, ni por la función" "0|0|0" \
  "$(como "$EQUIPO" aal2 "(select (select count(*) from v_asiento_papel) || '|' || (select count(*) from v_papel_fases f where f.origen_tabla in ('nomina_corridas', 'nomina_burden')) || '|' || (select count(*) from fn_banco_papel_nomina()))")"
revisa "anon no ejecuta la función ni abre la vista (42501)" "42501|42501" \
  "$(ed 2>&1 <<'SQL' | grep -o 'ERROR:  [0-9A-Z]*' | sed 's/ERROR:  //' | tr '\n' '|' | sed 's/|$//'
begin; set local role anon; select count(*) from public.fn_banco_papel_nomina(); rollback;
begin; set local role anon; select count(*) from public.v_papel_fases; rollback;
SQL
)"
revisa "y es la única del banco que no es de conta.js con permiso para la API; no es SECURITY DEFINER" "authenticated|f" \
  "$(ed -c "select (select string_agg(g, ',' order by g) from unnest(array['anon', 'authenticated', 'service_role']) g where has_function_privilege(g, p.oid, 'execute')) || '|' || case when p.prosecdef then 't' else 'f' end from pg_proc p where p.oid = 'public.fn_banco_papel_nomina()'::regprocedure")"

echo
echo "== 5. La Bandeja y la conciliación: un cargo de Gusto suelto y una devolución de Gusto"
M5="$(movimiento "c6-nom-dev" -33.33 'GUSTO REFUND 8c6 ZZ C6 NOM' "$D1")"
revisa "el cargo suelto y la devolución (un depósito), los dos con el motivo nomina (R6)" "-49.00:nomina:R6 · 33.33:nomina:R6" \
  "$(ed -c "select string_agg(b.monto || ':' || b.motivo || ':' || (b.propuesta->>'regla'), ' · ' order by b.monto) from v_banco_bandeja b where b.movimiento_id in ('$M0', '$M5')")"
revisa "la devolución dice que se casa desde Nómina → Cargos de Gusto, contra lo que quedó a favor (antes: «un depósito sin factura que lo explique»)" "sí" \
  "$(ed -c "select case when b.texto like 'Depósito que dice nómina (Gusto)%Contabilidad → Nómina → Cargos de Gusto, contra lo que su nómina dejó a favor%' then 'sí' else left(b.texto, 100) end from v_banco_bandeja b where b.movimiento_id = '$M5'")"
revisa "y la nómina los tiene a los dos en su lista de pendientes (la pantalla les pone «Casar con la nómina»)" "2" \
  "$(dueno "(select count(*) from fn_nomina_cargos() g where g.estado = 'pendiente' and g.movimiento_id in ('$M0', '$M5'))")"
x="$(dueno "(select 'x' from (select fn_banco_clasificar('$M0', '[{\"cuenta\": \"6130\"}]'::jsonb, null)) z)")"
revisa "clasificar el cargo a mano sin motivo: MX008, con su camino" "sí" \
  "$([[ "$x" == "MX008: Es un débito de nómina (Gusto): se casa desde Contabilidad → Nómina → Cargos de Gusto"*"dilo en el motivo." ]] && echo sí || echo "no: $x")"
x="$(dueno "(select 'x' from (select fn_banco_clasificar('$M5', '[{\"cuenta\": \"4010\"}]'::jsonb, null)) z)")"
revisa "clasificar la devolución a mano sin motivo: MX008, con su camino" "sí" \
  "$([[ "$x" == "MX008: Es un depósito de nómina (una devolución de Gusto): se casa desde Contabilidad → Nómina → Cargos de Gusto"*"dilo en el motivo." ]] && echo sí || echo "no: $x")"
x="$(dueno "(select 'x' from (select fn_banco_cobrar('$M5', jsonb_build_array(jsonb_build_object('proyecto_id', 'c6-nom-a', 'monto', '33.33')), null)) z)")"
revisa "registrarle a la devolución el cobro de un cliente (un anticipo de su obra) sin su porqué: MX008" "sí" \
  "$([[ "$x" == "MX008: Es un depósito de nómina (una devolución de Gusto): se casa desde Contabilidad → Nómina → Cargos de Gusto"*"di por qué en las notas (p_notas)." ]] && echo sí || echo "no: $x")"
revisa "los dos siguen pendientes (nada entró)" "pendiente,pendiente" "$(ed -c "select string_agg(m.estado, ',') from movimientos_banco m where m.id in ('$M0', '$M5')")"
FALTA="$(ed 2>&1 <<SQL | grep -v '^$' | tail -n 1
begin;
select fn_conciliar('1010', date '$HOY', '0.00')->>'falta';
rollback;
SQL
)"
revisa "a la conciliación de hoy le faltan «2 movimiento(s) de nómina (Gusto) sin casar», con su camino (no «espera el journal (f11)»)" "sí" \
  "$([[ "$FALTA" == "2 movimiento(s) de nómina (Gusto) sin casar: se casan desde Contabilidad → Nómina → Cargos de Gusto, con lo que su nómina dejó por pagar; o, si es del proveedor anterior, regístralo desde el SQL Editor con fn_banco_nomina (no se clasifica a mano)" ]] && echo sí || echo "no: $FALTA")"
CUOTA="$(dueno "fn_nomina_cargo_cuota('$M0')->>'asiento'")"
revisa "el cargo suelto se resuelve desde la nómina (es la cuota mensual de Gusto: a su gasto, con su asiento) y queda casado" "sí|casado" \
  "$([[ "$CUOTA" =~ ^[0-9]{4}-[0-9]+$ ]] && echo sí || echo "no: $CUOTA")|$(ed -c "select m.estado from movimientos_banco m where m.id = '$M0'")"

echo
echo "== 6. Anular la nómina (des-casando sus cargos) y volver a subirla"
for m in "$M1" "$M2"; do
  P="$(ed -c "select id from nomina_pagos where movimiento_id = '$m' and estado = 'aplicado'")"
  dueno "(select 'x' from (select fn_nomina_cargo_deshacer('$P', 'ZZ C6 NOM: para anular la nómina')) z)" > /dev/null
done
dueno "(select 'x' from (select fn_nomina_anular('$K', 'ZZ C6 NOM: prueba de anular')) z)" > /dev/null
revisa "anulada (sus dos asientos, reversados) y vuelta a subir, postear y casar" "anulada|nueva|posteada|el neto casado|los impuestos casados" \
  "$(ed -c "select estado from nomina_corridas where id = '$K'")|$(nomina)"
revisa "sus seis asientos (los dos de antes, sus dos reversos y los dos nuevos) tienen su papel, el de c15" "6|6|6" \
  "$(ed -c "select count(*) || '|' || count(*) filter (where p.papel_existe) || '|' || count(*) filter (where p.papel = n.papel)
              from v_asiento_papel p left join v_nomina_papel n on n.origen_tabla = p.origen_tabla and n.origen_id = p.origen_id
             where p.origen_tabla in ('nomina_corridas', 'nomina_burden')")"
revisa "y sin el código, los seis dicen que se ven con él" "6|6" \
  "$(como "$DUENO" aal1 "(select count(*) || '|' || count(*) filter (where p.papel_existe and p.papel like '%código del teléfono%') from v_asiento_papel p where p.origen_tabla in ('nomina_corridas', 'nomina_burden'))")"
K="$(ed -c "select id from nomina_corridas where estado = 'posteada' order by posteada_el desc limit 1")"
ASI="$(ed -c "select asiento_id from nomina_corridas where id = '$K'")"

echo
echo "== 7. c4-pruebas.sql y c6-pruebas.sql con la nómina de verdad dentro"
cat > "$TMP/resumen.sql" <<'SQL'
\o
\pset tuples_only on
\pset format unaligned
select format('PRUEBAS total=%s ok=%s fallan=%s omitidas=%s', count(*), count(*) filter (where ok), count(*) filter (where not ok),
              count(*) filter (where ok is null)) from _pruebas;
select 'FALLA ' || n || ': ' || left(obtenido, 400) from _pruebas where ok is false order by n;
select 'LA ' || n || ' ' || case when ok then 'ok' when ok is null then 'omitida' else 'FALLA' end || ' · ' || left(prueba, 200) from _pruebas where n in (25, 164, 165);
SQL
for s in c4 c6; do
  PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" \
    -c '\o /dev/null' -f "$DOCS/$s-pruebas.sql" -f "$TMP/resumen.sql" > "$TMP/p7-$s.out" 2>&1
  echo "     $s-pruebas: $(grep '^PRUEBAS' "$TMP/p7-$s.out")"
  grep '^FALLA \|ERROR' "$TMP/p7-$s.out" | head -n 8
done
revisa "c4-pruebas.sql: 113 filas, ninguna falla; la 25 («toda cifra baja a su asiento y a su papel»), en verde con la nómina" "113|0|ok" \
  "$(sed -n 's/^PRUEBAS total=\([0-9]*\) .* fallan=\([0-9]*\) .*/\1|\2/p' "$TMP/p7-c4.out")|$(sed -n 's/^LA 25 \([a-zA-Z]*\) .*/\1/p' "$TMP/p7-c4.out")"
revisa "c6-pruebas.sql: 167 filas, ninguna falla; la 164 y la 165 miran también los asientos de la nómina de verdad" "167|0|ok ok|sí" \
  "$(sed -n 's/^PRUEBAS total=\([0-9]*\) .* fallan=\([0-9]*\) .*/\1|\2/p' "$TMP/p7-c6.out")|$(sed -n 's/^LA 16[45] \([a-zA-Z]*\) .*/\1/p' "$TMP/p7-c6.out" | tr '\n' ' ' | sed 's/ $//')|$(grep -q '^LA 164 ok .*(con c15: 6 asiento(s) de nómina de verdad en el libro, 6 con su corrida)' "$TMP/p7-c6.out" && echo sí || echo no)"
revisa "las pruebas no dejaron nada: los asientos de la nómina y sus papeles, los mismos" "6|6" \
  "$(ed -c "select count(*) || '|' || count(*) filter (where p.papel_existe) from v_asiento_papel p where p.origen_tabla in ('nomina_corridas', 'nomina_burden')")"

echo
echo "== 8. A la vez: la app leyendo el papel mientras se pega c15 y mientras se pega c6"
# lee <aal>: una lectura como la app → «true|<principio del papel>», o su error
lee() {
  ed 2>&1 <<SQL | grep -v '^$' | grep -v '^{' | grep -v '^[0-9]*$' | tail -n 1
begin; $(app "$DUENO" "$1")
select papel_existe::text || '|' || left(papel, 60) from v_asiento_papel where asiento_id = '$ASI';
commit;
SQL
}
lector() { while [ ! -e "$TMP/alto" ]; do lee "$1" >> "$2"; done; }   # lector <aal> <archivo>: lee sin parar hasta $TMP/alto
pegar_rc() { pegar "$1" > "$2" 2>&1; echo $?; }
# ronda <n> <archivo que se pega> <aal del lector> <cómo empieza un papel bueno>
ronda() {
  local n=$1 f=$2 aal=$3 bueno=$4 rcs="" i rc
  rm -f "$TMP/alto"; : > "$TMP/lect$n.txt"
  lector "$aal" "$TMP/lect$n.txt" & local L1=$!
  lector "$aal" "$TMP/lect$n.txt" & local L2=$!
  sleep 0.5
  for i in 1 2 3 4 5 6 7 8; do
    rc="$(pegar_rc "$f" "$TMP/pegar$n-$i.log")"; rcs="$rcs$rc"
    [ "$(echo -n "$rcs" | tr -cd 0 | wc -c)" -ge 2 ] && break
    sleep 0.3
  done
  sleep 0.5; touch "$TMP/alto"; wait "$L1" "$L2" 2>/dev/null
  local tot buenas err
  tot="$(wc -l < "$TMP/lect$n.txt")"; buenas="$(grep -c "^true|$bueno" "$TMP/lect$n.txt")"; err="$(grep -ci 'error' "$TMP/lect$n.txt")"
  echo "     (intentos del pegado: $rcs —0 entró, 3 paró—; lecturas: $tot; paradas por candado: $(cat "$TMP"/pegar$n-*.log 2>/dev/null | grep -c 'lock timeout'))"
  revisa "$n: mientras se pega $(basename "$f"), ninguna lectura falla y todas traen su papel (más de 5 lecturas)" "0|todas|sí" \
    "$err|$([ "$tot" = "$buenas" ] && echo todas || echo "$buenas de $tot")|$([ "$tot" -gt 5 ] && echo sí || echo "no ($tot)")"
  revisa "$n: el pegado entró dos veces (o paró con 55P03 sin tocar nada, y se volvió a pegar)" "sí|0" \
    "$([ "$(echo -n "$rcs" | tr -cd 0 | wc -c)" -ge 2 ] && echo sí || echo "no ($rcs)")|$(cat "$TMP"/pegar$n-*.log 2>/dev/null | grep 'ERROR' | grep -vc 'lock timeout\|55P03')"
  grep -v "^true|$bueno" "$TMP/lect$n.txt" | sort | uniq -c | head -n 3
}
ronda 1 "$DOCS/c15-nomina.sql" aal2 "Nómina de Gusto del"
ronda 2 "$DOCS/c6-banco.sql" aal2 "Nómina de Gusto del"
ronda 3 "$DOCS/c15-nomina.sql" aal1 "Nómina de Gusto: el papel de este asiento es su nómina"
# un lector con su transacción abierta después de leer el papel: el pegado para (55P03) y no cambia nada
abierto() {  # abierto <archivo de salida>: lee el papel y se queda 4 s dentro de su transacción
  ed > "$1" 2>&1 <<SQL
begin; $(app "$DUENO" aal2)
select 'LEYO ' || papel_existe::text from v_asiento_papel where asiento_id = '$ASI';
reset role;
select pg_sleep(4);
commit;
SQL
}
sello() { ed -c "select fn_banco_version() || ':' || (select md5(string_agg(h.tipo || h.objeto || h.md5, '|' order by h.tipo, h.objeto)) from fn_banco_huellas() h) || ':' || md5(pg_get_viewdef('public.v_nomina_papel'::regclass)) || ':' || 'public.v_nomina_papel'::regclass::oid"; }
for par in "4|c15-nomina.sql" "5|c6-banco.sql"; do
  n="${par%%|*}"; f="${par##*|}"
  S0="$(sello)"
  abierto "$TMP/abierto$n.txt" & AB=$!
  sleep 1
  rc="$(pegar_rc "$DOCS/$f" "$TMP/pegar$n.log")"
  revisa "$n: con un lector dentro de su transacción, el pegado de $f para con 55P03 y no cambia nada (ni la marca, ni las huellas, ni la vista de c15)" "3|1|igual" \
    "$rc|$(grep -c 'lock timeout' "$TMP/pegar$n.log")|$([ "$(sello)" = "$S0" ] && echo igual || echo CAMBIÓ)"
  wait "$AB"
  revisa "$n: el lector terminó bien, y con él fuera el pegado entra" "LEYO true|0" "$(grep '^LEYO' "$TMP/abierto$n.txt")|$(pegar_rc "$DOCS/$f" "$TMP/pegar${n}b.log")"
done

echo
echo "== 9. Volver a pegar c6 (dos veces) con todo dentro"
# (la huella de TODAS las tablas de public: para ver que volver a pegar no cambia ni un dato)
tablas() {
  ed <<'SQL' | tail -n 1
create function pg_temp.huella() returns text language plpgsql as $f$
declare r record; v text := ''; h text;
begin
  for r in select c.relname from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' order by c.relname loop
    execute format('select md5(coalesce(string_agg(x::text, %L order by x::text), %L)) from public.%I x', '|', '', r.relname) into h;
    v := v || r.relname || '=' || h || ';';
  end loop;
  return md5(v);
end $f$;
select pg_temp.huella();
SQL
}
T0="$(tablas)"
pegar "$DOCS/c6-banco.sql" > "$TMP/9a.out" 2>&1; revisa "entra" "0" "$?"
pegar "$DOCS/c6-banco.sql" > "$TMP/9b.out" 2>&1; revisa "y otra vez" "0" "$?"
revisa "su resumen: 7 filas, todas en true; «funciones de la app» cuenta las 21 de conta.js y la de los papeles" "7|0|1" \
  "$(grep -cE '^ *(c6|banco) · .*\| t +\|' "$TMP/9b.out")|$(grep -cE '^ *(c6|banco) · .*\| f +\|' "$TMP/9b.out")|$(grep -cE 'c6 · funciones de la app +\| t +\| "21 funciones que llama conta.js y fn_banco_papel_nomina' "$TMP/9b.out")"
revisa "las huellas selladas son las de hoy, y las protecciones del banco en verde" "0|t" \
  "$(ed -c "select count(*) from (select h.tipo, h.objeto, h.md5 from fn_banco_huellas() h except select a.tipo, a.objeto, a.md5 from fn_banco_huellas_calcular() a) x")|$(protecciones)"
revisa "ninguna tabla cambió al volver a pegarlo (ni un dato)" "igual" "$([ "$(tablas)" = "$T0" ] && echo igual || echo CAMBIÓ)"
revisa "el papel de la nómina, el de c15, con el código; y sin él, que se ve con el código" "6|6" \
  "$(como "$DUENO" aal2 "(select count(*) filter (where p.papel = n.papel) from v_asiento_papel p join v_nomina_papel n on n.origen_tabla = p.origen_tabla and n.origen_id = p.origen_id)")|$(como "$DUENO" aal1 "(select count(*) filter (where p.papel_existe and p.papel like '%código del teléfono%') from v_asiento_papel p where p.origen_tabla in ('nomina_corridas', 'nomina_burden'))")"

echo
echo "== Al final"
revisa "la cadena del libro, sin rojos (los permisos también, con la función de los papeles y c15 puestos)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"
revisa "los puentes (c3): nada nuevo en rojo" "$ROJOS_C3" "$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_puentes_verificar() where not ok")"
revisa "la revisión entera del banco (fn_banco_verificar): nada en rojo" "ninguno" "$(ed -c "select coalesce(string_agg(control, '; ') filter (where not ok), 'ninguno') from fn_banco_verificar()")"
revisa "los cuadres de la nómina, sin rojos" "0" "$(ed -c "select count(*) from fn_nomina_control() where nivel = 'cuadre' and not ok")"

echo
if [ $malos -eq 0 ]; then echo "c6-nomina: todo bien"; else echo "c6-nomina: ALGO FALLA"; fi
exit $malos
