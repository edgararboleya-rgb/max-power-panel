#!/usr/bin/env bash
# =====================================================================
# c13-nomina.sh — lo que c13-pruebas.sql solo puede fingir: la cédula de
# corte (c13) con UNA NÓMINA DE VERDAD de c15 dentro, por la puerta del
# dueño (13-nov-2026, Fase 11b).
#
#   ./c13-nomina.sh [nombre_bd]      (por defecto c13_nomina)
#
# Crea su base con c1 + c2 + c3 + c4 + c6 + c10 y c13 (dos veces), SIN la
# nómina; después pega c15 encima, sin volver a pegar c13 (el orden de
# producción al revés: la cédula lee la nómina al vuelo, llegue cuando
# llegue). Tres personas, dos obras y sus horas aprobadas, y el «Payroll
# journal» sintético de pruebas/conta/nomina/zz-payroll-journal.csv con las
# fechas movidas a hoy: su día de pago es HOY, y Gusto cobró el neto y los
# impuestos HACE TRES DÍAS (Gusto cobra antes del día de pago).
#   1. SIN LA NÓMINA: sus cuentas (2220, 2225, 2230, 2240) salen «sin
#      auxiliar: llega con la nómina (f11)», y 2210 con su devengo.
#   2. LLEGA c15 (encima, sin tocar c13): la cédula la ve sola. Sin ninguna
#      nómina en el libro, sus cuentas cuadran en cero, con el código del
#      teléfono y sin él.
#   3. UNA NÓMINA DE VERDAD: importada, su gente enlazada, posteada, y sus
#      cargos de Gusto casados. Antes del cargo, todo en cero; ENTRE EL
#      CARGO Y EL DÍA DE PAGO, 2210 (−4,874.93), 2220, 2225 y 2230 están al
#      revés y CUADRAN (lo adelantado a Gusto, y lo dice); el día de pago
#      quedan las deducciones (2240: 50.00) y cuadran con su nómina. Y en
#      cada cuenta y cada día, lo de la nómina en la cédula es lo que dice
#      la nómina.
#   4. SIN EL CÓDIGO DEL TELÉFONO (el dueño con la sesión en aal1): esas
#      cuentas salen «con_codigo» —ni «no cuadra» ni «sin auxiliar»—, sin un
#      renglón de ninguna nómina, y piden entrar con el código tengan saldo
#      o no; el control las nombra todas y no se pone en rojo por eso; no
#      se explica (MX008). Con el código, cuadran.
#   5. ALGO ENTRA POR OTRO LADO (las deducciones, pagadas con un asiento a
#      mano que no pasó por la nómina): 2240 no cuadra por −50.00 y la fila
#      lo dice con lo que la nómina sí explica; el control de la nómina dice
#      qué asiento es. Reversado, vuelve a cuadrar.
#   6. EL DEVENGO Y LA NÓMINA EN 2210: con un devengo vivo de 300.00 y lo
#      adelantado a Gusto, la cuenta cuadra con sus dos renglones (dentro de
#      una transacción que se deshace).
#   7. ANULAR LA NÓMINA (des-casando sus cargos) Y VOLVER A SUBIRLA: la
#      cédula de cada día dice lo mismo que antes.
#   8. EL FIN DE MES (el reloj de la base en el día 12 del mes siguiente,
#      dentro de una transacción que se deshace): el control de la cédula no
#      cuenta ninguna cuenta de la nómina; con lo que entró por otro lado,
#      el 20 nombra la 2240 con su diferencia (no el 30: sí tiene auxiliar);
#      y sin el código —con la 2240 en cero en el libro y 50.00 abiertos en
#      su nómina—, ni el 20 ni el 30 la cuentan como descuadre, y el 20 y la
#      fila del cierre dicen que se ve con el código (no un verde falso).
#   9. VOLVER A PEGAR c13 (dos veces) con la nómina dentro: la cédula de
#      cada día es la misma, renglón por renglón; y c13-pruebas.sql corre
#      con la nómina de verdad dentro: 48 filas, ninguna falla.
# Y comprueba al final: la cadena del libro en verde (los permisos
# también), los puentes (c3) sin nada nuevo en rojo, el control de la cédula
# (el 10 y el 90) en verde y los cuadres de la nómina sin rojos.
#
# Cada sesión de «la app» va como por PostgREST: el dueño, con el rol
# authenticated, los ajustes de ese rol y el tope de la API (8 s); con su
# código (aal2) o sin él (aal1). Nombres y montos inventados («ZZ…», «ZZ
# C13 NOM»): nada de producción.
#
# Variables: PGHOST (127.0.0.1) y PGPORT (5432), como correr.sh.
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c13_nomina}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'echo "(La base $BD y $TMP quedan: ./correr.sh --borrar $BD; rm -rf $TMP)"' EXIT
else
  trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
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
  ('c13-nom-a', 'comercial', 'ZZ C13 NOM Obra A', 'ejecucion'),
  ('c13-nom-b', 'servicio',  'ZZ C13 NOM Obra B', 'ejecucion');
do $$
declare
  r record;
  v_d uuid := (select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1);
  v_0 date := fn_fecha_miami(now()) - 19;
begin
  for r in select * from (values ('00000000-0000-4000-a000-0000000d1301'::uuid, 'ZZ Ayudante Uno'),
                                 ('00000000-0000-4000-a000-0000000d1302'::uuid, 'ZZ Ayudante Dos'),
                                 ('00000000-0000-4000-a000-0000000d1303'::uuid, 'ZZ Oficial Tres')) as x(id, nombre) loop
    insert into auth.users (id, email) values (r.id, 'c13-nom-' || right(r.id::text, 2) || '@c13-pruebas.invalid') on conflict (id) do nothing;
    insert into perfiles (id, nombre, rol, activo) values (r.id, r.nombre, 'campo', true)
    on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
  end loop;
  insert into costos_equipo (usuario_id, costo_hora) values
    ('00000000-0000-4000-a000-0000000d1301', 25), ('00000000-0000-4000-a000-0000000d1302', 30)
  on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
  insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el) values
    (v_0 + 1, '00000000-0000-4000-a000-0000000d1301', 'c13-nom-a', 8,  null,    'ZZ C13 NOM', v_d, now()),
    (v_0 + 2, '00000000-0000-4000-a000-0000000d1301', 'c13-nom-a', 8,  null,    'ZZ C13 NOM', v_d, now()),
    (v_0 + 3, '00000000-0000-4000-a000-0000000d1301', 'c13-nom-b', 10, 'CO #1', 'ZZ C13 NOM', v_d, now()),
    (v_0 + 4, '00000000-0000-4000-a000-0000000d1301', null,        4,  null,    'ZZ C13 NOM', v_d, now()),
    (v_0 + 1, '00000000-0000-4000-a000-0000000d1302', 'c13-nom-b', 8,  null,    'ZZ C13 NOM', v_d, now()),
    (v_0 + 5, '00000000-0000-4000-a000-0000000d1303', 'c13-nom-a', 10, null,    'ZZ C13 NOM', v_d, now()),
    (v_0 + 6, '00000000-0000-4000-a000-0000000d1303', 'c13-nom-a', 10, null,    'ZZ C13 NOM', v_d, now());
end $$;
SQL

echo "== Base $BD: c1 + c2 + c3 + c4 + c6 + c10 + c13 (dos veces), SIN la nómina, y lo de este script"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$DOCS/c10-costo-obra.sql" "$DOCS/c13-cedula.sql" "$DOCS/c13-cedula.sql" "$TMP/montar.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
HOY="$(ed -c "select fn_fecha_miami(now())")"
MES="$(ed -c "select p.periodo from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and fn_fecha_miami(now()) between p.desde and p.hasta")"
[ -n "$DUENO" ] && [ -n "$MES" ] || { echo "No hay un dueño, o el mes de hoy no está abierto: no hay dónde postear" >&2; exit 2; }
dia() { ed -c "select date '$HOY' - $1"; }                       # el día de hace N días
us()  { ed -c "select to_char(date '$HOY' - $1, 'MM/DD/YYYY')"; }
D1="$(dia 1)"; D2="$(dia 2)"; D3="$(dia 3)"; D4="$(dia 4)"
FIN="$(ed -c "select hasta from periodos where periodo = '$MES'")"
ROJOS_C3="$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_puentes_verificar() where not ok")"
NOMINAS="'2210', '2220', '2225', '2230', '2240'"

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
# Una fila de la cédula en una línea: fuente | libro | aux | dif | estado. fila <cuenta> <fecha> [aal: como el dueño por la API]
FILA="format('%s | libro %s | aux %s | dif %s | %s%s', c.fuente, c.saldo_libro, coalesce(c.saldo_auxiliar::text, '-'), coalesce(c.diferencia::text, '-'), c.estado, case when c.pendiente then ' (pide)' else '' end)"
fila() {
  if [ -n "${3:-}" ]; then como "$3" "(select $FILA from fn_cedula('$2') c where c.cuenta = '$1')"
  else ed -c "select coalesce((select $FILA from fn_cedula('$2') c where c.cuenta = '$1'), 'no sale')"; fi
}
# las cinco cuentas de la nómina a una fecha: «cuenta libro aux estado», separadas por « · »
cinco() {
  local q="(select string_agg(c.cuenta || ' ' || c.saldo_libro || ' ' || coalesce(c.saldo_auxiliar::text, '-') || ' ' || c.estado, ' · ' order by c.cuenta) from fn_cedula('$1') c where c.cuenta in ($NOMINAS))"
  if [ -n "${2:-}" ]; then como "$2" "$q"; else ed -c "select $q"; fi
}
detalle() { ed -c "select c.detalle from fn_cedula('$2') c where c.cuenta = '$1'"; }
# ¿lo de la nómina en la cédula es lo que dice la nómina? (por cuenta y nómina, en los días que se digan)
igual() {
  ed -c "select case when count(*) = 0 then 'sí' else 'no: ' || string_agg(coalesce(n.cuenta, p.cuenta) || ' al ' || coalesce(n.f, p.f), ', ') end
           from (select u.f, x.cuenta, x.corrida_id::text as corrida, x.saldo::numeric(14,2) as monto
                   from unnest(array[$1]::date[]) u(f) cross join lateral fn_nomina_auxiliar(u.f) x) n
           full join (select u.f, i.cuenta, i.ref_id as corrida, i.monto
                        from unnest(array[$1]::date[]) u(f) cross join lateral fn_cedula_partidas(u.f, null) i
                       where i.clase = 'auxiliar' and i.fuente = 'nomina') p on p.f = n.f and p.cuenta = n.cuenta and p.corrida = n.corrida
          where n.cuenta is null or p.cuenta is null or n.monto <> p.monto"
}
# la cédula de varios días, renglón por renglón, en una huella (para ver que algo no la cambia)
huella() {
  ed -c "select md5(coalesce((select string_agg(concat_ws('|', c.fecha, c.cuenta, c.saldo_libro, c.saldo_auxiliar, c.diferencia, c.estado, c.pendiente, c.detalle), '~' order by c.fecha, c.cuenta)
                                from unnest(array['$D4', '$D3', '$D1', '$HOY']::date[]) u(f) cross join lateral fn_cedula(u.f) c), ''))
             || md5(coalesce((select string_agg(concat_ws('|', u.f, i.cuenta, i.n, i.clase, i.concepto, i.monto, i.libro, i.nota), '~' order by u.f, i.cuenta, i.n)
                                from unnest(array['$D4', '$D3', '$D1', '$HOY']::date[]) u(f) cross join lateral fn_cedula_partidas(u.f, null) i), ''))"
}
# lo que c13 guarda, en una línea (para ver que volver a pegar no lo pisa)
guardado() {
  ed -c "select concat_ws('|', (select md5(string_agg(to_jsonb(c)::text, ',')) from cedula_config c),
                           (select count(*) from cedula_manual), (select count(*) from cedula_explicaciones))"
}

echo
echo "== 1. Sin la nómina (c15 todavía no está)"
revisa "la cédula dice que la nómina no está" "false|no_esta" "$(ed -c "select (fn_cedula_capas()->>'c15') || '|' || (fn_cedula_nomina('$HOY')->>'estado')")"
revisa "2220: sin auxiliar, «llega con la nómina (f11)», y sin saldo no pide nada" \
  "nomina | libro 0.00 | aux - | dif - | sin_auxiliar|Sin auxiliar: llega con la nómina (f11). No tiene saldo: no pide nada." "$(fila 2220 "$HOY")|$(detalle 2220 "$HOY")"
revisa "2210: su devengo de las horas (nada de la nómina todavía)" "devengos | libro 0.00 | aux 0.00 | dif 0.00 | cuadra|El devengo de las horas aprobadas" \
  "$(fila 2210 "$HOY")|$(ed -c "select c.auxiliar from fn_cedula('$HOY') c where c.cuenta = '2210'")"

echo
echo "== 2. Llega c15 (encima, sin volver a pegar c13)"
pegar "$DOCS/c15-nomina.sql" > "$TMP/2c15.out" 2>&1 || { tail -n 20 "$TMP/2c15.out"; echo "FALLÓ pegar c15 encima de c13" >&2; exit 2; }
revisa "la cédula la ve sin que nadie la toque, y todavía no hay ninguna nómina en el libro" "true|ok|false" \
  "$(ed -c "select (fn_cedula_capas()->>'c15') || '|' || (fn_cedula_nomina('$HOY')->>'estado') || '|' || (fn_cedula_nomina('$HOY')->>'nominas')")"
revisa "sus cuentas ya no dicen «llega con la nómina»: cuadran en cero con lo que cada nómina dejó por pagar" \
  "2210 0.00 0.00 cuadra · 2220 0.00 0.00 cuadra · 2225 0.00 0.00 cuadra · 2230 0.00 0.00 cuadra · 2240 0.00 0.00 cuadra|Lo que cada nómina dejó por pagar" \
  "$(cinco "$HOY")|$(ed -c "select c.auxiliar from fn_cedula('$HOY') c where c.cuenta = '2220'")"
revisa "sin ninguna nómina en el libro no hay nada que tapar: sin el código del teléfono sale lo mismo" "$(cinco "$HOY")" "$(cinco "$HOY" aal1)"
revisa "y el pegado de la cédula lo dice (sin volver a pegarla)" "sí" \
  "$(ed -c "select case when g.detalle like '%la nómina (c15): está%' then 'sí' else 'no' end from fn_cedula_pegado() g where g.que = 'capas que lee'")"

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
# un cargo de Gusto en el banco, como lo trae Plaid, y «Casar» solo para él (c6 lo deja en la Bandeja); devuelve su id
cargo() {  # cargo <id> <monto> <descripción> <fecha>
  dueno "(select 'x' from (select fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c13-nom · $1', 'filas', jsonb_build_array(jsonb_build_object('id', '$1', 'fecha', '$4', 'plaid_monto', '$2', 'descripcion', '$3', 'tipo', 'DEBIT', 'pendiente', false))))) z)" > /dev/null
  local m; m="$(ed -c "select id from movimientos_banco where id_externo = '$1' order by importado_el desc limit 1")"
  dueno "(select 'x' from (select fn_banco_casar('$m')) z)" > /dev/null
  echo "$m"
}
# la nómina entera, por la puerta del dueño: importar, (enlazar a su gente), postear y casar sus dos cargos. nomina <sufijo de los cargos>
nomina() {
  local r; r="$(dueno "fn_nomina_importar(:'arch'::jsonb)->'corridas'->0->>'resultado'")"
  K="$(ed -c "select id from nomina_corridas where estado = 'importada' order by importada_el desc limit 1")"
  for p in "ZZ Ayudante Uno|0d1301|campo" "ZZ Ayudante Dos|0d1302|campo" "ZZ Oficial Tres|0d1303|oficial"; do
    IFS='|' read -r nom suf cla <<< "$p"
    dueno "fn_nomina_persona(jsonb_build_object('id', (select id from nomina_personas where clave = fn_nomina_clave('$nom')), 'usuario_id', '00000000-0000-4000-a000-000000$suf', 'clase', '$cla', 'confirmar', true))->>'confirmada'" > /dev/null
  done
  dueno "fn_nomina_config('{\"cuenta_sin_obra\": \"6000\"}')->>'cuenta_sin_obra'" > /dev/null
  r="$r|$(dueno "(select case when z.r->'asiento'->>'numero' is not null then 'posteada' else z.r::text end from (select fn_nomina_postear('$K', fn_nomina_propuesta('$K')->>'visto') as r) z)")"
  if [ -z "${M1:-}" ]; then
    M1="$(cargo "c13-nom-net" 4874.93 'GUSTO NET 7c13 ZZ C13 NOM' "$D3")"
    M2="$(cargo "c13-nom-tax" 1583.31 'GUSTO TAX 7c13 ZZ C13 NOM' "$D3")"
  fi
  r="$r|$(dueno "(select case when z.r->>'asiento' is not null then 'el neto casado' else z.r::text end from (select fn_nomina_cargo_casar('$M1', fn_nomina_cargo_propuesta('$M1')->'opciones'->0->'partes') as r) z)")"
  r="$r|$(dueno "(select case when z.r->>'asiento' is not null then 'los impuestos casados' else z.r::text end from (select fn_nomina_cargo_casar('$M2', fn_nomina_cargo_propuesta('$M2')->'opciones'->0->'partes') as r) z)")"
  echo "$r"
}
M1=""; M2=""; K=""
revisa "la nómina entra por la puerta del dueño: importada, posteada, y sus dos cargos casados" "nueva|posteada|el neto casado|los impuestos casados" "$(nomina)"
K="$(ed -c "select id from nomina_corridas where estado = 'posteada' order by posteada_el desc limit 1")"
M1="$(ed -c "select id from movimientos_banco where id_externo = 'c13-nom-net'")"; M2="$(ed -c "select id from movimientos_banco where id_externo = 'c13-nom-tax'")"
NJ="$(ed -c "select asiento_numero from nomina_corridas where id = '$K'")"
revisa "antes del cargo de Gusto (hace 4 días): todo en cero, y cuadra" \
  "2210 0.00 0.00 cuadra · 2220 0.00 0.00 cuadra · 2225 0.00 0.00 cuadra · 2230 0.00 0.00 cuadra · 2240 0.00 0.00 cuadra" "$(cinco "$D4")"
revisa "ENTRE EL CARGO DE GUSTO Y EL DÍA DE PAGO (hace 3 días y ayer): las cuentas están al revés y CUADRAN (lo adelantado a Gusto)" \
  "2210 -4874.93 -4874.93 cuadra · 2220 -1391.64 -1391.64 cuadra · 2225 -34.85 -34.85 cuadra · 2230 -156.82 -156.82 cuadra · 2240 0.00 0.00 cuadra|igual ayer" \
  "$(cinco "$D3")|$([ "$(cinco "$D3")" = "$(cinco "$D1")" ] && echo "igual ayer" || echo "ayer: $(cinco "$D1")")"
revisa "y la 2210 lo dice en llano, con su cargo y con un papel debajo (no «partidas»)" "sí|papel|1 renglón de la nómina por -4874.93, con su journal" \
  "$(ed -c "select case when c.detalle like '-\$4,874.93 en el libro al % = -\$4,874.93 en el devengo de las horas aprobadas y lo que cada nómina dejó por pagar (1 renglón(es)). De la nómina del % ya se pagaron \$4,874.93 (% por \$4,874.93) y su journal todavía no está en el libro ese día (Gusto cobra antes del día de pago): hasta que entre, es lo adelantado a Gusto.' then 'sí' else 'no: ' || c.detalle end || '|' || c.sosten from fn_cedula('$D3') c where c.cuenta = '2210'")|$(ed -c "select count(*) || ' renglón de la nómina por ' || min(i.monto) || case when min(i.referencia) = '$NJ' then ', con su journal' else ', SIN su journal' end from fn_cedula_partidas('$D3', '2210') i where i.clase = 'auxiliar' and i.fuente = 'nomina'")"
revisa "EL DÍA DE PAGO: el neto y los impuestos, pagados; quedan las deducciones (50.00), y cuadran con su nómina" \
  "2210 0.00 0.00 cuadra · 2220 0.00 0.00 cuadra · 2225 0.00 0.00 cuadra · 2230 0.00 0.00 cuadra · 2240 50.00 50.00 cuadra|sí" \
  "$(cinco "$HOY")|$(ed -c "select case when c.detalle like '\$50.00 en el libro al % = \$50.00 en lo que cada nómina dejó por pagar (1 renglón(es)). De la nómina del % quedan \$50.00 por pagar: es lo que dejó su journal ($NJ), y ningún cargo casado lo ha pagado todavía.' and c.sosten = 'papel' then 'sí' else 'no: ' || c.detalle end from fn_cedula('$HOY') c where c.cuenta = '2240'")"
# (13-nov, los arreglos de la verificación de la Fase 11b: el reembolso que pagó la nómina sigue a nombre de su empleado, en sus
# partidas; pero su gasto no está registrado y la cuenta por pagar queda AL REVÉS —saldo deudor—: ya no «cuadra», y lo dice)
revisa "los reembolsos (2250): el reembolso que pagó la nómina está a nombre de su empleado, en sus partidas; sin su gasto registrado la cuenta queda al revés, y no se da por buena" \
  "partidas | libro -64.25 | aux -64.25 | dif 0.00 | no_cuadra (pide)|sí" \
  "$(fila 2250 "$HOY")|$(ed -c "select case when c.detalle like '%pero está AL REVÉS: es una cuenta por pagar y su saldo es deudor (\$64.25 a favor de la empresa)%la nómina le pagó a alguien un reembolso%' and c.que_hacer like '%regístralo a nombre de quien es%' then 'sí' else 'no: ' || left(c.detalle, 200) end from fn_cedula('$HOY') c where c.cuenta = '2250'")"
revisa "en cada cuenta y cada día, lo de la nómina en la cédula es lo que dice la nómina" "sí" "$(igual "'$D4', '$D3', '$D1', '$HOY', '$FIN'")"
revisa "el dueño por la API, con su código, ve lo mismo que el SQL Editor" "$(cinco "$D3") / $(cinco "$HOY")" "$(cinco "$D3" aal2) / $(cinco "$HOY" aal2)"

echo
echo "== 4. Sin el código del teléfono (el dueño con la sesión en aal1)"
revisa "la cédula sabe que hay nóminas y que esta sesión no las puede leer (y no trae ni un renglón)" "codigo|sin renglones" \
  "$(como aal1 "(fn_cedula_nomina('$HOY')->>'estado') || '|' || case when fn_cedula_nomina('$HOY') ? 'filas' then 'CON renglones' else 'sin renglones' end")"
revisa "entre el cargo y el día de pago: «con_codigo», sin compararse (ni «no cuadra» ni «sin auxiliar»)" \
  "2210 -4874.93 - con_codigo · 2220 -1391.64 - con_codigo · 2225 -34.85 - con_codigo · 2230 -156.82 - con_codigo · 2240 0.00 - con_codigo" "$(cinco "$D3" aal1)"
revisa "la 2240 el día de pago: pide entrar con el código, y lo dice" "nomina | libro 50.00 | aux - | dif - | con_codigo (pide)|codigo|sí" \
  "$(fila 2240 "$HOY" aal1)|$(como aal1 "(select c.por_que || '|' || case when c.detalle like '%solo se ve con el código del teléfono%No es que no cuadre: falta mirarla con el código.' and c.que_hacer like 'Entra con el código del teléfono y vuelve a mirar%' then 'sí' else 'no: ' || c.detalle end from fn_cedula('$HOY') c where c.cuenta = '2240')")"
revisa "y una sin saldo en el libro lo pide igual (en cero puede tener algo abierto en su nómina): la 2240 de hace 3 días" \
  "nomina | libro 0.00 | aux - | dif - | con_codigo (pide)|sí" \
  "$(fila 2240 "$D3" aal1)|$(como aal1 "(select case when c.detalle like 'Sin saldo en el libro al %solo se ve con el código del teléfono%No es que no cuadre: falta mirarla con el código.' and c.que_hacer like 'Entra con el código del teléfono y vuelve a mirar%' then 'sí' else 'no: ' || c.detalle end from fn_cedula('$D3') c where c.cuenta = '2240')")"
revisa "ni un renglón de ninguna nómina; al pedir la cuenta, un dato que lo dice; y los totales las cuentan aparte y entre las pendientes" "0|1 dato|sí" \
  "$(como aal1 "(select count(*) from fn_cedula_partidas('$D3', null) i where i.fuente = 'nomina' and i.clase <> 'dato')")|$(como aal1 "(select count(*) || ' ' || min(i.clase) from fn_cedula_partidas('$D3', '2210') i)")|$(como aal1 "(select case when (r->>'con_codigo')::int = (select count(*) from fn_cedula_cuentas() k where k.nomina = 'codigo') and (r->>'con_codigo')::int >= 5 and (r->>'pendientes')::int >= (r->>'con_codigo')::int and not (r->>'listo')::boolean then 'sí' else 'no: ' || r::text end from (select fn_cedula_resumen('$HOY') as r) z)")"
revisa "el control no se pone en rojo por eso, y el 20 las nombra todas (con saldo o sin él)" "sí" \
  "$(como aal1 "(select case when k.ok and k.detalle like '% Con el código del teléfono se ven 6 cuenta(s) de la nómina que aquí no se comprobaron (2210, 2215, 2220, 2225, 2230, 2240): entra con él.' then 'sí' else 'no: ' || k.detalle end from fn_cedula_control('$MES') k where k.orden = 20)")"
revisa "no se explica lo que no se ve (MX008)" "MX008" "$(como aal1 "fn_cedula_explicar('2240', '$HOY', 'ZZ C13 NOM: no se puede explicar lo que no se ve')" | grep -o 'MX008' | head -n 1)"

echo
echo "== 5. Algo entra por otro lado: las deducciones, pagadas con un asiento a mano que no pasó por la nómina"
AM="$(dueno "fn_postear(jsonb_build_object('fecha', '$HOY', 'descripcion', 'ZZ C13 NOM: las deducciones, pagadas a mano', 'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2240', 'monto', '50.00'), jsonb_build_object('cuenta', '6500', 'monto', '-50.00'))))->>'numero'")"
AMID="$(ed -c "select id from asientos where numero = '$AM'")"
revisa "la 2240 ya no cuadra: la diferencia, al centavo, y lo que entró por otro lado va aparte" "nomina | libro 0.00 | aux 50.00 | dif -50.00 | no_cuadra (pide)|-50.00" \
  "$(fila 2240 "$HOY")|$(ed -c "select c.sueltas from fn_cedula('$HOY') c where c.cuenta = '2240'")"
revisa "la fila lo dice en llano: qué entró por otro lado, lo que la nómina sí explica, y dónde mirarlo" "sí" \
  "$(ed -c "select case when c.detalle like '\$0.00 en el libro al % y \$50.00 en lo que cada nómina dejó por pagar: -\$50.00 de diferencia. -\$50.00 están en el libro sin ser lo que una nómina dejó por pagar ni un cargo casado con ella: entraron por otro lado. Lo que la nómina sí explica: de la nómina del % quedan \$50.00 por pagar: es lo que dejó su journal ($NJ), y ningún cargo casado lo ha pagado todavía.' and c.que_hacer like 'Lo que entró por otro lado lo dice, asiento por asiento, el control de la nómina%Nómina → Cargos de Gusto%' then 'sí' else 'no: ' || c.detalle || ' / ' || c.que_hacer end from fn_cedula('$HOY') c where c.cuenta = '2240'")"
revisa "y el control de la nómina (su aviso «lo que entró por otro lado») dice qué asiento es" "sí" \
  "$(ed -c "select case when not k.ok and k.detalle like '%2240%$AM%' then 'sí' else 'no: ' || k.detalle end from fn_nomina_control() k where k.orden = 62")"
revisa "reversado ese asiento, la 2240 vuelve a cuadrar con su nómina" "nomina | libro 50.00 | aux 50.00 | dif 0.00 | cuadra" \
  "$(dueno "fn_reversar('$AMID', 'ZZ C13 NOM: no debía estar')->>'numero'" > /dev/null; fila 2240 "$HOY")"

echo
echo "== 6. El devengo de las horas y la nómina, juntos en la 2210 (dentro de una transacción que se deshace)"
ed -v ON_ERROR_STOP=1 > "$TMP/6.out" 2>&1 <<SQL
begin;
$(app aal2)
select 'DEVENGO ' || (fn_postear(jsonb_build_object('fecha', '$D2', 'descripcion', 'ZZ C13 NOM: un devengo de horas, de prueba', 'reversible', true,
         'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6000', 'monto', '300.00'), jsonb_build_object('cuenta', '2210', 'monto', '-300.00'))))->>'numero');
select 'FILA ' || $FILA || ' | ' || c.sosten || ' | ' || c.renglones from fn_cedula('$D2') c where c.cuenta = '2210';
select 'RENGLONES ' || string_agg(i.fuente || ' ' || i.monto, ' + ' order by i.n) from fn_cedula_partidas('$D2', '2210') i where i.clase = 'auxiliar';
select 'DICE ' || case when c.detalle like '%ya se pagaron \$4,874.93%Lo del devengo sale del propio libro (su asiento, que se deshace solo el día 1); lo de la nómina, de su journal y de sus cargos casados.' then 'sí' else 'no: ' || c.detalle end
  from fn_cedula('$D2') c where c.cuenta = '2210';
rollback;
SQL
revisa "un devengo vivo de 300.00 y lo adelantado a Gusto (-4,874.93): la 2210 cuadra con sus dos renglones, cada uno una vez" \
  "devengos | libro -4574.93 | aux -4574.93 | dif 0.00 | cuadra | partidas | 2|devengos 300.00 + nomina -4874.93|sí" \
  "$(sed -n 's/^FILA //p' "$TMP/6.out")|$(sed -n 's/^RENGLONES //p' "$TMP/6.out")|$(sed -n 's/^DICE //p' "$TMP/6.out")"
revisa "y al deshacer, la 2210 de ese día sigue como estaba" "devengos | libro -4874.93 | aux -4874.93 | dif 0.00 | cuadra|0" "$(fila 2210 "$D2")|$(grep -c 'ERROR' "$TMP/6.out")"

echo
echo "== 7. Anular la nómina (des-casando sus cargos) y volver a subirla"
H7="$(huella)"
for m in "$M1" "$M2"; do
  P="$(ed -c "select id from nomina_pagos where movimiento_id = '$m' and estado = 'aplicado'")"
  dueno "(select 'x' from (select fn_nomina_cargo_deshacer('$P', 'ZZ C13 NOM: para anular la nómina')) z)" > /dev/null
done
revisa "des-casados los dos cargos: lo que la nómina dejó por pagar vuelve entero, y cuadra (el día de pago)" \
  "2210 4874.93 4874.93 cuadra · 2220 1391.64 1391.64 cuadra · 2225 34.85 34.85 cuadra · 2230 156.82 156.82 cuadra · 2240 50.00 50.00 cuadra" "$(cinco "$HOY")"
dueno "(select 'x' from (select fn_nomina_anular('$K', 'ZZ C13 NOM: prueba de anular')) z)" > /dev/null
revisa "anulada: nada por pagar en ninguna cuenta, y cuadra (el día de pago y hace 3 días)" \
  "2210 0.00 0.00 cuadra · 2220 0.00 0.00 cuadra · 2225 0.00 0.00 cuadra · 2230 0.00 0.00 cuadra · 2240 0.00 0.00 cuadra|igual" \
  "$(cinco "$HOY")|$([ "$(cinco "$HOY")" = "$(cinco "$D3")" ] && echo igual || echo "hace 3 días: $(cinco "$D3")")"
revisa "el mismo archivo otra vez: importada, posteada y sus cargos casados de nuevo" "nueva|posteada|el neto casado|los impuestos casados" "$(nomina)"
K="$(ed -c "select id from nomina_corridas where estado = 'posteada' order by posteada_el desc limit 1")"
revisa "y la cédula vuelve a decir lo de antes: entre el cargo y el día de pago, al revés y cuadra; el día de pago, las deducciones" \
  "2210 -4874.93 -4874.93 cuadra · 2220 -1391.64 -1391.64 cuadra · 2225 -34.85 -34.85 cuadra · 2230 -156.82 -156.82 cuadra · 2240 0.00 0.00 cuadra / 2210 0.00 0.00 cuadra · 2220 0.00 0.00 cuadra · 2225 0.00 0.00 cuadra · 2230 0.00 0.00 cuadra · 2240 50.00 50.00 cuadra|sí" \
  "$(cinco "$D3") / $(cinco "$HOY")|$(igual "'$D4', '$D3', '$D1', '$HOY', '$FIN'")"

echo
echo "== 8. El fin de mes (el reloj de la base en el día 12 del mes siguiente, dentro de una transacción que se deshace)"
ed -v ON_ERROR_STOP=1 > "$TMP/8.out" 2>&1 <<SQL
begin;
create or replace function public.fn_fecha_miami(t timestamptz) returns date language sql stable set search_path = public, pg_temp
as \$b\$ select greatest((t at time zone 'America/New_York')::date, date '$FIN' + 12) \$b\$;
select 'A ' || (select count(*) from fn_cedula('$FIN') c where c.cuenta in ($NOMINAS) and c.estado <> 'cuadra')
       || '|' || (select case when k.detalle like '%2240 %' or k.detalle like '%2210 %' then 'el 20 las nombra' else 'el 20 no las nombra' end from fn_cedula_control('$MES') k where k.orden = 20)
       || '|' || (select case when k.detalle like '%2240 %' or k.detalle like '%2220 %' then 'el 30 las nombra' else 'el 30 no las nombra' end from fn_cedula_control('$MES') k where k.orden = 30);
-- lo que entró por otro lado, otra vez (como el dueño)
$(app aal2)
select 'ASIENTO ' || (fn_postear(jsonb_build_object('fecha', '$HOY', 'descripcion', 'ZZ C13 NOM: las deducciones, pagadas a mano', 'lineas',
         jsonb_build_array(jsonb_build_object('cuenta', '2240', 'monto', '50.00'), jsonb_build_object('cuenta', '6500', 'monto', '-50.00'))))->>'numero');
select 'B ' || (select case when not k.ok and k.detalle like '%2240 Deducciones a empleados (-\$50.00 de diferencia)%' then 'el 20 en rojo y la nombra' else 'no: ' || k.detalle end
                  from fn_cedula_control('$MES') k where k.orden = 20)
       || '|' || (select case when k.detalle like '%2240 %' then 'el 30 la nombra' else 'el 30 no' end from fn_cedula_control('$MES') k where k.orden = 30)
       || '|' || (select case when not k.ok and k.orden = 178 and k.nivel = 'aviso' and k.detalle like '%2240 Deducciones a empleados (-\$50.00 de diferencia)%' and length(k.detalle) <= 1500
                              then 'la fila del cierre en rojo y la nombra' else 'no: ' || k.detalle end from fn_cedula_cierre('$MES') k);
-- y sin el código del teléfono
select set_config('request.jwt.claims', '{"sub":"$DUENO","role":"authenticated","aal":"aal1"}', true);
select 'C ' || (select case when k.detalle not like '%2240 Deducciones%' and k.detalle like '% Con el código del teléfono se ven % cuenta(s) de la nómina que aquí no se comprobaron (%): entra con él.'
                            then 'el 20 no la cuenta y lo dice' else 'no: ' || k.detalle end from fn_cedula_control('$MES') k where k.orden = 20)
       || '|' || (select case when k.detalle like '%2240 %' then 'el 30 la nombra' else 'el 30 tampoco' end from fn_cedula_control('$MES') k where k.orden = 30)
       || '|' || (select case when k.detalle like '% Con el código del teléfono se ven % cuenta(s) de la nómina que aquí no se comprobaron (%): entra con él.' and k.detalle not like '%2240 Deducciones%'
                              then 'la fila del cierre lo dice' else 'no: ' || k.detalle end from fn_cedula_cierre('$MES') k);
rollback;
SQL
revisa "con la nómina cuadrada, el control del mes no cuenta ninguna cuenta de la nómina" "0|el 20 no las nombra|el 30 no las nombra" "$(sed -n 's/^A //p' "$TMP/8.out")"
revisa "con lo que entró por otro lado: el 20 nombra la 2240 con su diferencia (no el 30: sí tiene auxiliar), y la fila del cierre también" \
  "el 20 en rojo y la nombra|el 30 no|la fila del cierre en rojo y la nombra" "$(sed -n 's/^B //p' "$TMP/8.out")"
revisa "y sin el código del teléfono, ni el 20 ni el 30 la cuentan: el 20 y la fila del cierre dicen que se ve con él" \
  "el 20 no la cuenta y lo dice|el 30 tampoco|la fila del cierre lo dice" "$(sed -n 's/^C //p' "$TMP/8.out")"
revisa "nada de eso quedó (ni el asiento, ni el reloj)" "0|0|el de verdad" \
  "$(grep -c 'ERROR' "$TMP/8.out")|$(ed -c "select count(*) from asientos where descripcion like 'ZZ C13 NOM: las deducciones%' and not exists (select 1 from asientos r where r.reversa_a = asientos.id)")|$(ed -c "select case when pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure) like '%greatest%' then 'FINGIDO' else 'el de verdad' end")"

echo
echo "== 9. Volver a pegar c13 (dos veces) con la nómina dentro, y sus pruebas"
H9="$(huella)"; G9="$(guardado)"
pegar "$DOCS/c13-cedula.sql" > "$TMP/9a.out" 2>&1; revisa "entra" "0" "$?"
pegar "$DOCS/c13-cedula.sql" > "$TMP/9b.out" 2>&1; revisa "y otra vez" "0" "$?"
revisa "la cédula de cada día es la misma, renglón por renglón, y lo guardado también" "igual|igual" \
  "$([ "$(huella)" = "$H9" ] && echo igual || echo CAMBIÓ)|$([ "$(guardado)" = "$G9" ] && echo igual || echo CAMBIÓ)"
revisa "y es la de antes de anular y volver a subir la nómina, salvo por los números de sus asientos" "sí" \
  "$(ed -c "select case when (select string_agg(c.cuenta || c.saldo_libro || c.saldo_auxiliar || c.estado, ',' order by c.cuenta) from fn_cedula('$D3') c where c.cuenta in ($NOMINAS))
                              = '2210-4874.93-4874.93cuadra,2220-1391.64-1391.64cuadra,2225-34.85-34.85cuadra,2230-156.82-156.82cuadra,22400.000.00cuadra' then 'sí' else 'no' end")"
cat > "$TMP/resumen.sql" <<'SQL'
\o
\pset tuples_only on
\pset format unaligned
select format('PRUEBAS total=%s ok=%s fallan=%s omitidas=%s', count(*), count(*) filter (where ok), count(*) filter (where not ok),
              count(*) filter (where ok is null)) from _pruebas;
select 'OMITIDAS ' || coalesce(string_agg(n::text, ' ' order by n), 'ninguna') from _pruebas where ok is null;
select 'POR CAPA ' || coalesce(string_agg(n::text, ' ' order by n), 'ninguna') from _pruebas
 where ok is null and obtenido like 'omitida: esa parte de la contabilidad (%) no está en esta base';
select 'FALLA ' || n || ': ' || left(obtenido, 400) from _pruebas where ok is false order by n;
select 'LA 47 ' || left(obtenido, 400) from _pruebas where n = 47;
SQL
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" \
  -c '\o /dev/null' -f "$DOCS/c13-pruebas.sql" -f "$TMP/resumen.sql" > "$TMP/p9.out" 2>&1
revisa "c13-pruebas.sql con la nómina de verdad dentro: 48 filas, ninguna falla" "48|0" \
  "$(sed -n 's/^PRUEBAS total=\([0-9]*\) .* fallan=\([0-9]*\) .*/\1|\2/p' "$TMP/p9.out")"
revisa "solo se omite lo de las capas que esta base no tiene (c12: 14; c9: 15 y 30; p1: 19); la 47 corre con la nómina de verdad" \
  "14 15 19 30|14 15 19 30|sí" \
  "$(sed -n 's/^OMITIDAS //p' "$TMP/p9.out")|$(sed -n 's/^POR CAPA //p' "$TMP/p9.out")|$(grep -q '^LA 47 lo de la nómina en la cédula es lo que dice la nómina, cuenta por cuenta y día por día: sí .*con nóminas en el libro' "$TMP/p9.out" && echo sí || echo no)"
grep '^FALLA \|ERROR' "$TMP/p9.out" | head -n 12
revisa "las pruebas no dejaron nada: la cédula de cada día y lo guardado, tal cual" "igual|igual" \
  "$([ "$(huella)" = "$H9" ] && echo igual || echo CAMBIÓ)|$([ "$(guardado)" = "$G9" ] && echo igual || echo CAMBIÓ)"

echo
echo "== Al final"
revisa "la cadena del libro, sin rojos (los permisos también, con c13 y c15 puestos)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"
revisa "los puentes (c3): nada nuevo en rojo" "$ROJOS_C3" "$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_puentes_verificar() where not ok")"
revisa "el control de la cédula: el 10 (trae todas las cuentas y su saldo es el del libro) y el 90 (las protecciones), en verde" "0" \
  "$(ed -c "select count(*) from fn_cedula_control(null) where nivel = 'cuadre' and not ok")"
revisa "los cuadres de la nómina, sin rojos" "0" "$(ed -c "select count(*) from fn_nomina_control() where nivel = 'cuadre' and not ok")"

echo
if [ $malos -eq 0 ]; then echo "c13-nomina: todo bien"; else echo "c13-nomina: ALGO FALLA"; fi
exit $malos
