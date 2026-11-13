#!/usr/bin/env bash
# =====================================================================
# c15-concurrencia.sh — lo que c15-pruebas.sql no puede probar: dos
# sesiones A LA VEZ con la nómina. c15-pruebas corre en una sola sesión;
# aquí se abren varias de verdad, y cada una confirma.
#
#   ./c15-concurrencia.sh [nombre_bd]      (por defecto c15_concurrencia)
#
# Crea su base con c1 + c2 + c3 + c4 + c6 + c10 + c15 (lo que la nómina
# pide; así se ve también que pega sin c7…c14), tres personas, dos obras y
# sus horas aprobadas, y con el «Payroll journal» sintético de
# pruebas/conta/nomina/zz-payroll-journal.csv (con las fechas movidas a hoy):
#   1. IMPORTAR EL MISMO ARCHIVO desde dos pestañas a la vez: una entra
#      («nueva»); la otra espera y contesta «ya_estaba». Una corrida, una
#      fila de archivo.
#   2. POSTEAR LA MISMA CORRIDA desde dos pestañas a la vez (cada una con lo
#      que vio): una la postea; la otra recibe «ya estaba». Un journal y un
#      reparto de su burden, y cada hora en el lote una sola vez.
#   3. CASAR EL MISMO CARGO DE GUSTO desde dos pestañas a la vez: una lo
#      casa; la otra recibe «ya estaba». Un pago, un asiento del banco.
#   4. DOS CARGOS DISTINTOS QUE QUIEREN PAGAR LO MISMO a la vez (el cargo de
#      los impuestos, dos veces en el banco): uno entra; el otro, MX008 en
#      llano («… de más. No se casó nada.»). Nada queda pagado de más.
#   5. DESHACER Y CASAR el mismo cargo a la vez: nunca dos pagos vivos del
#      mismo movimiento.
#   6. DOS NÓMINAS QUE QUIEREN LAS MISMAS HORAS a la vez (anulada la primera,
#      su archivo otra vez y, además, un bono fuera de ciclo del mismo día
#      del que se dice que es el que paga esas horas): una se queda con las
#      horas; la otra para en llano (MX008 o MX011), sin un 23505 en crudo.
#      Una hora, una nómina viva.
#   7. PEGAR c15-nomina.sql CON LA PANTALLA LEYENDO: o para con 55P03 (medio
#      segundo, sin aplicar nada) o entra; después, sin nadie leyendo, entra
#      seguro y todo sigue en su sitio.
#   8. UN CARGO CASADO AQUÍ Y DES-CASADO EN LA BANDEJA DEL BANCO (su pago de
#      la nómina se queda apuntado, pero lo que pagaba vuelve a estar por
#      pagar), CASADO OTRA VEZ desde dos pestañas a la vez: una lo casa y
#      apunta deshecho el pago de antes; la otra recibe «ya estaba». Un pago
#      vivo.
#   9. LA MISMA NÓMINA BAJADA DE DOS FORMAS, subidas a la vez (una corrección
#      de Gusto en negativo: con su columna del tipo y sin ella, las dos
#      diciendo «es otra nómina»): entra una; la otra contesta «ya_estaba»
#      (son las mismas personas con las mismas cifras). Una sola en la base.
#  10. REPARTIR LO QUE QUEDA EN LA BOLSA DEL BURDEN REAL (la prima de WC)
#      desde dos pestañas a la vez, cada una con lo que vio: una la reparte;
#      la otra para en llano (MX008: ya no queda nada, o MX011). Un asiento,
#      la bolsa en cero. (El reparto es de un mes TERMINADO: para esta escena
#      el reloj de la base se pone en el día 1 del mes siguiente y al acabar
#      se deja el de verdad.)
# Y comprueba al final: ningún 23505 ni 40P01 en ninguna salida, la cadena
# del libro en verde (los permisos también), c3 «mano de obra» en verde y los
# cuadres del control de la nómina en verde.
#
# Cada sesión va como la app por PostgREST: el dueño, con el rol
# authenticated, en aal2, los ajustes de ese rol y el tope de la API (8 s).
# Nombres y montos inventados («ZZ…», «ZZ C15 CONC»): nada de producción.
#
# Variables: PGHOST (127.0.0.1) y PGPORT (5432), como correr.sh.
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c15_concurrencia}"
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
revisa_en() {  # revisa_en <descripción> <obtenido> <valor que vale> [otro que vale …]
  local d="$1" o="$2"; shift 2
  for v in "$@"; do if [ "$o" = "$v" ]; then echo "ok   $d ($o)"; return; fi; done
  echo "FALLA: $d: salió «$o» (valía: $*)"; malos=1
}

# La escena, como el SQL Editor: dos obras, tres personas (su usuario, su
# perfil de campo; dos con su tarifa) y sus horas APROBADAS del período de
# pago (los 14 días que terminan 6 días antes de hoy; el día de pago, hoy).
cat > "$TMP/montar.sql" <<'SQL'
insert into proyectos (id, tipo, nombre, estado) values
  ('c15-conc-a', 'comercial', 'ZZ C15 CONC Obra A', 'ejecucion'),
  ('c15-conc-b', 'servicio',  'ZZ C15 CONC Obra B', 'ejecucion');
do $$
declare
  r record;
  v_d uuid := (select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1);
  v_0 date := fn_fecha_miami(now()) - 19;
begin
  for r in select * from (values ('00000000-0000-4000-a000-0000000c1501'::uuid, 'ZZ Ayudante Uno'),
                                 ('00000000-0000-4000-a000-0000000c1502'::uuid, 'ZZ Ayudante Dos'),
                                 ('00000000-0000-4000-a000-0000000c1503'::uuid, 'ZZ Oficial Tres')) as x(id, nombre) loop
    insert into auth.users (id, email) values (r.id, 'c15-conc-' || right(r.id::text, 2) || '@c15-pruebas.invalid') on conflict (id) do nothing;
    insert into perfiles (id, nombre, rol, activo) values (r.id, r.nombre, 'campo', true)
    on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
  end loop;
  insert into costos_equipo (usuario_id, costo_hora) values
    ('00000000-0000-4000-a000-0000000c1501', 25), ('00000000-0000-4000-a000-0000000c1502', 30)
  on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
  insert into horas (fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el) values
    (v_0 + 1, '00000000-0000-4000-a000-0000000c1501', 'c15-conc-a', 8,  null,    'ZZ C15 CONC', v_d, now()),
    (v_0 + 2, '00000000-0000-4000-a000-0000000c1501', 'c15-conc-a', 8,  null,    'ZZ C15 CONC', v_d, now()),
    (v_0 + 3, '00000000-0000-4000-a000-0000000c1501', 'c15-conc-b', 10, 'CO #1', 'ZZ C15 CONC', v_d, now()),
    (v_0 + 4, '00000000-0000-4000-a000-0000000c1501', null,         4,  null,    'ZZ C15 CONC', v_d, now()),
    (v_0 + 1, '00000000-0000-4000-a000-0000000c1502', 'c15-conc-b', 8,  null,    'ZZ C15 CONC', v_d, now()),
    (v_0 + 5, '00000000-0000-4000-a000-0000000c1503', 'c15-conc-a', 10, null,    'ZZ C15 CONC', v_d, now()),
    (v_0 + 6, '00000000-0000-4000-a000-0000000c1503', 'c15-conc-a', 10, null,    'ZZ C15 CONC', v_d, now());
end $$;
SQL

echo "== Base $BD: c1 + c2 + c3 + c4 + c6 + c10 + c15 y lo de este script"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$DOCS/c10-costo-obra.sql" "$DOCS/c15-nomina.sql" "$TMP/montar.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
HOY="$(ed -c "select fn_fecha_miami(now())")"
MES="$(ed -c "select p.periodo from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and fn_fecha_miami(now()) between p.desde and p.hasta")"
[ -n "$DUENO" ] && [ -n "$MES" ] || { echo "No hay un dueño, o el mes de hoy no está abierto: no hay dónde postear" >&2; exit 2; }
us() { ed -c "select to_char(date '$HOY' - $1, 'MM/DD/YYYY')"; }
D0="$(us 19)"; D13="$(us 6)"; DP="$(us 0)"

# El archivo, como lo manda la pantalla: {nombre, sha256, bytes, filas: [[celda, …], …]} (el journal sintético no trae
# comas dentro de una celda: se parte por comas).
archivo() {  # archivo <nombre del CSV en nomina/> [otra ruta de donde leerlo]
  local csv; csv="$(sed -e "s#01/03/2027#$D0#g" -e "s#01/16/2027#$D13#g" -e "s#01/22/2027#$DP#g" "${2:-$DIR/nomina/$1}")"
  ed -v csv="$csv" -v nombre="$1" <<'SQL'
select jsonb_build_object('nombre', :'nombre', 'sha256', encode(sha256(convert_to(:'csv', 'UTF8')), 'hex'),
                          'bytes', octet_length(:'csv'),
                          'filas', (select jsonb_agg(to_jsonb(string_to_array(t.l, ',')) order by t.n)
                                      from unnest(string_to_array(:'csv', E'\n')) with ordinality as t(l, n)))::text;
SQL
}
ARCH="$(archivo zz-payroll-journal.csv)"
BONO="$(archivo zz-payroll-journal-bono.csv)"
# (una corrección de Gusto en negativo, en dos formas: como la baja Gusto con su columna del tipo, y sin esa columna)
CORR="$(archivo zz-payroll-journal-correccion.csv)"
sed -e '1s/Payroll type,//' -e 's/,Correction,/,/' "$DIR/nomina/zz-payroll-journal-correccion.csv" > "$TMP/zz-correccion-sin-tipo.csv"
CORR2="$(archivo zz-correccion-sin-tipo.csv "$TMP/zz-correccion-sin-tipo.csv")"
[ -n "$ARCH" ] && [ -n "$BONO" ] && [ -n "$CORR" ] && [ -n "$CORR2" ] || { echo "No se pudieron armar los archivos de prueba" >&2; exit 2; }

# Como la app por PostgREST: con el rol authenticated, los ajustes de ese
# rol y el tope de la API (8 s). app <quién>.
app() {
  echo "select set_config('request.jwt.claims', '{\"sub\":\"$1\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"
}
# dueno <salida> <sql que devuelve un texto> [pausa con la transacción abierta]
# (:'arch' = el journal; :'bono' = el bono fuera de ciclo; :'corr' y :'corr2' = la corrección, en sus dos formas;
# :'partes' = las partes de un cargo)
dueno() {
  ed -v ON_ERROR_STOP=1 -v arch="$ARCH" -v bono="$BONO" -v corr="$CORR" -v corr2="$CORR2" -v partes="${PARTES:-[]}" > "$1" 2>&1 <<SQL
begin; $(app "$DUENO")
select 'RESULTADO ' || ($2);
select pg_sleep(${3:-0});
commit;
SQL
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
res()     { sed -n 's/^RESULTADO //p' "$1"; }
# un cargo de Gusto en el banco, como lo trae Plaid, y «Casar» solo para él (c6 lo deja en la Bandeja esperando su journal)
cargo() {  # cargo <id> <monto> <descripción>
  dueno "$TMP/cargo-$1.out" "(select 'x' from (select fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c15-conc · $1', 'filas', jsonb_build_array(jsonb_build_object('id', '$1', 'fecha', '$HOY', 'plaid_monto', '$2', 'descripcion', '$3', 'tipo', 'DEBIT', 'pendiente', false))))) z)"
  local m; m="$(ed -c "select id from movimientos_banco where id_externo = '$1' order by importado_el desc limit 1")"
  dueno "$TMP/cargo-$1-casar.out" "(select 'x' from (select fn_banco_casar('$m')) z)"
  echo "$m"
}

echo
echo "== 1. Importar el mismo archivo desde dos pestañas a la vez"
dos 1 "fn_nomina_importar(:'arch'::jsonb)->'corridas'->0->>'resultado'" "fn_nomina_importar(:'arch'::jsonb)->'corridas'->0->>'resultado'"
revisa "entran las dos, sin error: una «nueva» y la otra «ya_estaba»" "2|0|1|1" "$(entran 1)|$(con 1 'ERROR')|$(con 1 'RESULTADO nueva')|$(con 1 'RESULTADO ya_estaba')"
revisa "una corrida viva y una fila de archivo, con sus 3 personas" "1|1|3" \
  "$(ed -c "select (select count(*) from nomina_corridas where estado = 'importada') || '|' || (select count(*) from nomina_archivos) || '|' || (select count(*) from nomina_corrida_personas)")"
K1="$(ed -c "select id from nomina_corridas where estado = 'importada' limit 1")"

# (la gente, enlazada y confirmada; y la cuenta de lo sin obra, dicha)
for p in "ZZ Ayudante Uno|0c1501|campo" "ZZ Ayudante Dos|0c1502|campo" "ZZ Oficial Tres|0c1503|oficial"; do
  IFS='|' read -r nom suf cla <<< "$p"
  dueno "$TMP/0p-$suf.out" "fn_nomina_persona(jsonb_build_object('id', (select id from nomina_personas where clave = fn_nomina_clave('$nom')), 'usuario_id', '00000000-0000-4000-a000-000000$suf', 'clase', '$cla', 'confirmar', true))->>'confirmada'"
done
dueno "$TMP/0cfg.out" "fn_nomina_config('{\"cuenta_sin_obra\": \"6000\"}')->>'cuenta_sin_obra'"
revisa "la escena: tres personas enlazadas y confirmadas, y la propuesta sin frenos" "3|0" \
  "$(ed -c "select count(*) from nomina_personas where confirmado_el is not null")|$(dueno "$TMP/0prop.out" "jsonb_array_length(fn_nomina_propuesta('$K1')->'frenos')"; res "$TMP/0prop.out")"

echo
echo "== 2. Postear la misma corrida desde dos pestañas a la vez (cada una con lo que vio)"
P="case when (z.r->>'ya_estaba')::boolean then 'ya estaba ' else 'posteada ' end || (z.r->'asiento'->>'numero') from (select fn_nomina_postear('$K1', fn_nomina_propuesta('$K1')->>'visto') as r) z"
dos 2 "(select $P)" "(select $P)"
revisa "una la postea y la otra recibe la que ya estaba (el mismo asiento), sin error" "1|1|1|0" \
  "$(con 2 'RESULTADO posteada')|$(con 2 'RESULTADO ya estaba')|$(cat "$TMP"/2a.out "$TMP"/2b.out | grep 'RESULTADO' | awk '{print $NF}' | sort -u | wc -l | tr -d ' ')|$(con 2 'ERROR')"
revisa "un journal y un reparto de su burden, y cada hora en el lote una sola vez (7 reportes)" "1|1|7|0" \
  "$(ed -c "select (select count(*) from asientos where origen_tabla = 'nomina_corridas') || '|' || (select count(*) from asientos where origen_tabla = 'nomina_burden')
                   || '|' || (select count(*) from nomina_reparto_horas where titular and vivo)
                   || '|' || (select count(*) from (select 1 from nomina_reparto_horas where titular and vivo group by horas_id having count(*) > 1) q)")"

echo
echo "== 3. Casar el mismo cargo de Gusto desde dos pestañas a la vez"
M1="$(cargo c15-conc-net 4874.93 'GUSTO NET 7conc ZZ C15 CONC')"
PARTES="[{\"corrida\": \"$K1\", \"cuenta\": \"2210\", \"monto\": \"4874.93\"}]"
C="case when (z.r->>'ya_estaba')::boolean then 'ya estaba ' else 'casado ' end || (z.r->>'asiento') from (select fn_nomina_cargo_casar('$M1', :'partes'::jsonb) as r) z"
dos 3 "(select $C)" "(select $C)"
revisa "una lo casa y la otra recibe el que ya estaba (el mismo asiento), sin error" "1|1|1|0" \
  "$(con 3 'RESULTADO casado')|$(con 3 'RESULTADO ya estaba')|$(cat "$TMP"/3a.out "$TMP"/3b.out | grep 'RESULTADO' | awk '{print $NF}' | sort -u | wc -l | tr -d ' ')|$(con 3 'ERROR')"
revisa "un pago vivo, el movimiento casado y el neto pagado entero (queda 0.00)" "1|casado|0.00" \
  "$(ed -c "select (select count(*) from nomina_pagos where movimiento_id = '$M1' and estado = 'aplicado') || '|' || (select estado from movimientos_banco where id = '$M1')
                   || '|' || (select pendiente from fn_nomina_pendiente('$K1') where cuenta = '2210')")"

echo
echo "== 4. Dos cargos distintos que quieren pagar lo mismo, a la vez"
M2="$(cargo c15-conc-tax-1 1391.64 'GUSTO TAX 7conc ZZ C15 CONC')"
M3="$(cargo c15-conc-tax-2 1391.64 'GUSTO TAX 7conc ZZ C15 CONC (otra vez)')"
PARTES="[{\"corrida\": \"$K1\", \"cuenta\": \"2220\", \"monto\": \"1391.64\"}]"
dos 4 "fn_nomina_cargo_casar('$M2', :'partes'::jsonb)->>'asiento'" "fn_nomina_cargo_casar('$M3', :'partes'::jsonb)->>'asiento'"
revisa "uno entra; el otro, MX008 en llano («de más. No se casó nada»), sin 23505" "1|1|1|0" \
  "$(entran 4)|$(con 4 'MX008')|$(con 4 'de más. No se casó nada')|$(con 4 '23505')"
revisa "los impuestos, pagados una vez (queda 0.00), y el otro cargo sigue en la Bandeja" "0.00|1" \
  "$(ed -c "select (select pendiente from fn_nomina_pendiente('$K1') where cuenta = '2220') || '|' || (select count(*) from movimientos_banco where id in ('$M2', '$M3') and estado = 'pendiente')")"

echo
echo "== 5. Deshacer y casar el mismo cargo a la vez"
PG1="$(ed -c "select id from nomina_pagos where movimiento_id = '$M1' and estado = 'aplicado'")"
PARTES="[{\"corrida\": \"$K1\", \"cuenta\": \"2210\", \"monto\": \"4874.93\"}]"
dos 5 "fn_nomina_cargo_deshacer('$PG1', 'ZZ C15 CONC: se deshace')->>'deshecho'" \
      "case when (z.r->>'ya_estaba')::boolean then 'ya estaba' else 'casado otra vez' end from (select fn_nomina_cargo_casar('$M1', :'partes'::jsonb) as r) z"
revisa "ninguna muere por un 23505 ni por un bloqueo mortal" "0|0" "$(con 5 '23505')|$(con 5 '40P01\|deadlock')"
revisa "nunca dos pagos vivos del mismo movimiento, y el neto nunca pagado de más" "sí|sí" \
  "$(ed -c "select case when (select count(*) from nomina_pagos where movimiento_id = '$M1' and estado = 'aplicado') <= 1 then 'sí' else 'NO' end || '|'
                   || case when (select pendiente from fn_nomina_pendiente('$K1') where cuenta = '2210') >= 0 then 'sí' else 'NO' end")"

echo
echo "== 6. Dos nóminas que quieren las mismas horas, a la vez"
# (se deshacen los cargos casados que queden y se anula la primera: sus horas quedan libres)
for g in $(ed -c "select id from nomina_pagos where estado = 'aplicado'"); do
  dueno "$TMP/6d-$g.out" "fn_nomina_cargo_deshacer('$g', 'ZZ C15 CONC: para anular la nómina')->>'deshecho'"
done
dueno "$TMP/6an.out" "fn_nomina_anular('$K1', 'ZZ C15 CONC: se anula para volver a subirla')->>'anulada'"
dueno "$TMP/6i1.out" "fn_nomina_importar(:'arch'::jsonb)->'corridas'->0->>'corrida'"
dueno "$TMP/6i2.out" "fn_nomina_importar(:'bono'::jsonb)->'corridas'->0->>'corrida'"
K3="$(res "$TMP/6i1.out")"; K4="$(res "$TMP/6i2.out")"
dueno "$TMP/6th.out" "fn_nomina_corrida('$K4', '{\"toma_horas\": true}')->>'toma_horas'"
revisa "anulada la primera, su archivo entra otra vez; y un bono del mismo día, dicho que paga esas horas: dos corridas importadas" "true|2|true" \
  "$(res "$TMP/6an.out")|$(ed -c "select count(*) from nomina_corridas where estado = 'importada'")|$(res "$TMP/6th.out")"
dos 6 "(select 'posteada ' || (r->'asiento'->>'numero') from fn_nomina_postear('$K3', fn_nomina_propuesta('$K3')->>'visto') r)" \
      "(select 'posteada ' || (r->'asiento'->>'numero') from fn_nomina_postear('$K4', fn_nomina_propuesta('$K4')->>'visto') r)"
revisa "una se queda con las horas; la otra para en llano (MX008 o MX011), sin 23505 ni bloqueo mortal" "1|1|0|0" \
  "$(entran 6)|$(con 6 'MX008\|MX011')|$(con 6 '23505')|$(con 6 '40P01\|deadlock')"
revisa "una nómina posteada, la otra sigue importada, y ninguna hora en dos nóminas vivas" "1|1|0" \
  "$(ed -c "select (select count(*) from nomina_corridas where estado = 'posteada') || '|' || (select count(*) from nomina_corridas where estado = 'importada')
                   || '|' || (select count(*) from (select 1 from nomina_reparto_horas where titular and vivo group by horas_id having count(*) > 1) q)")"
revisa "en el libro, vivos: un journal y un reparto de su burden" "1|1" \
  "$(ed -c "select string_agg(n::text, '|' order by t) from (select a.origen_tabla as t, count(*) as n from asientos a
              where a.origen_tabla in ('nomina_corridas', 'nomina_burden') and a.camino not in ('reverso', 'reverso_automatico')
                and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso') group by 1) q")"

echo
echo "== 7. Pegar c15-nomina.sql con la pantalla leyendo"
# (una pestaña con la lista de nóminas abierta 2 s; el pegado espera medio segundo como mucho)
ed -c "begin; select count(*) from v_nomina_corridas; select count(*) from nomina_corridas; select pg_sleep(2); commit;" > "$TMP/7lee.out" 2>&1 &
sleep 0.3
PGPASSWORD=editor_sql psql -X -q -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -1 -f "$DOCS/c15-nomina.sql" > "$TMP/7pega.out" 2>&1
RC7=$?
wait
if [ $RC7 -eq 0 ]; then P7="entró"; elif grep -q '55P03\|lock timeout\|tiempo de espera' "$TMP/7pega.out"; then P7="paró con 55P03"; else P7="otro error: $(grep -m1 ERROR "$TMP/7pega.out" | cut -c1-200)"; fi
revisa_en "con la pantalla leyendo, el pegado o entra o para con 55P03 (sin aplicar nada)" "$P7" "entró" "paró con 55P03"
PGPASSWORD=editor_sql psql -X -q -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -1 -f "$DOCS/c15-nomina.sql" > "$TMP/7pega2.out" 2>&1
revisa "sin nadie leyendo, entra; y todo sigue en su sitio (9 filas del pegado, la nómina posteada, la configuración dicha)" "0|9|1|6000" \
  "$?|$(ed -c "select count(*) from fn_nomina_pegado()")|$(ed -c "select count(*) from nomina_corridas where estado = 'posteada'")|$(ed -c "select cuenta_sin_obra from nomina_config")"

echo
echo "== 8. Un cargo casado aquí y des-casado en la Bandeja del banco, casado otra vez desde dos pestañas a la vez"
KP="$(ed -c "select id from nomina_corridas where estado = 'posteada' limit 1")"
NETO="$(ed -c "select pendiente from fn_nomina_pendiente('$KP') where cuenta = '2210'")"
M8="$(cargo c15-conc-net-8 "$NETO" 'GUSTO NET 8conc ZZ C15 CONC')"
PARTES="[{\"corrida\": \"$KP\", \"cuenta\": \"2210\", \"monto\": \"$NETO\"}]"
dueno "$TMP/8c.out" "fn_nomina_cargo_casar('$M8', :'partes'::jsonb)->>'asiento'"
dueno "$TMP/8d.out" "(select 'des-casado' from (select fn_banco_descasar('$M8', 'ZZ C15 CONC: des-casado en la Bandeja')) z)"
revisa "des-casado en la Bandeja: su pago de la nómina sigue apuntado, pero el neto vuelve a estar por pagar entero" "des-casado|1|pendiente|$NETO" \
  "$(res "$TMP/8d.out")|$(ed -c "select (select count(*) from nomina_pagos where movimiento_id = '$M8' and estado = 'aplicado') || '|' || (select estado from movimientos_banco where id = '$M8')
                   || '|' || (select pendiente from fn_nomina_pendiente('$KP') where cuenta = '2210')")"
C="case when (z.r->>'ya_estaba')::boolean then 'ya estaba ' else 'casado ' end || (z.r->>'asiento') from (select fn_nomina_cargo_casar('$M8', :'partes'::jsonb) as r) z"
dos 8 "(select $C)" "(select $C)"
revisa "una lo casa otra vez y la otra recibe el que ya estaba (el mismo asiento), sin error" "1|1|1|0" \
  "$(con 8 'RESULTADO casado')|$(con 8 'RESULTADO ya estaba')|$(cat "$TMP"/8a.out "$TMP"/8b.out | grep 'RESULTADO' | awk '{print $NF}' | sort -u | wc -l | tr -d ' ')|$(con 8 'ERROR')"
revisa "un pago vivo y el de antes apuntado deshecho solo; el movimiento casado y el neto pagado (queda 0.00)" "1|1|casado|0.00" \
  "$(ed -c "select (select count(*) from nomina_pagos where movimiento_id = '$M8' and estado = 'aplicado') || '|' || (select count(*) from nomina_pagos where movimiento_id = '$M8' and estado = 'deshecho')
                   || '|' || (select estado from movimientos_banco where id = '$M8') || '|' || (select pendiente from fn_nomina_pendiente('$KP') where cuenta = '2210')")"

echo
echo "== 9. La misma nómina bajada de dos formas, subidas a la vez (una corrección en negativo, con su columna del tipo y sin ella)"
dos 9 "fn_nomina_importar(:'corr'::jsonb, '{\"otra_nomina\": true}')->'corridas'->0->>'resultado'" \
      "fn_nomina_importar(:'corr2'::jsonb, '{\"otra_nomina\": true}')->'corridas'->0->>'resultado'"
revisa "entran las dos, sin error: una «nueva» y la otra «ya_estaba» (las mismas personas con las mismas cifras)" "2|0|1|1" \
  "$(entran 9)|$(con 9 'ERROR')|$(con 9 'RESULTADO nueva')|$(con 9 'RESULTADO ya_estaba')"
revisa "una sola corrección viva en la base (bruto -100.00)" "1" \
  "$(ed -c "select count(*) from nomina_corridas where estado in ('importada', 'posteada') and bruto = -100.00")"

echo
echo "== 10. Repartir lo que queda en la bolsa del burden real desde dos pestañas a la vez"
# (la prima de WC del mes entra a la bolsa por la puerta del dueño; el reparto es de un mes TERMINADO: el reloj de esta base
# se pone en el día 1 del mes siguiente, y al acabar se deja el de verdad)
dueno "$TMP/10wc.out" "fn_postear(jsonb_build_object('tipo', 'normal', 'fecha', '$HOY', 'descripcion', 'ZZ C15 CONC: la prima de WC del mes', 'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5015', 'monto', '300.00'), jsonb_build_object('cuenta', '1410', 'monto', '-300.00'))))->>'numero'"
RELOJ="$(ed -c "select pg_get_functiondef('public.fn_fecha_miami(timestamptz)'::regprocedure)")"
ed -c "create or replace function public.fn_fecha_miami(t timestamptz) returns date language sql stable set search_path = public, pg_temp as \$b\$ select (date_trunc('month', (t at time zone 'America/New_York')::date) + interval '1 month')::date \$b\$" > "$TMP/10reloj.out" 2>&1
dueno "$TMP/10ve.out" "fn_nomina_bolsa('$MES')->>'visto'"
VISTO="$(res "$TMP/10ve.out")"
dueno "$TMP/10sa.out" "(select (v->>'saldo') || '|' || (v->>'horas') || '|' || (v->>'puede') from fn_nomina_bolsa('$MES') v)"
revisa "terminado el mes, la bolsa tiene los 300.00, hay 54 h pagadas en obra y se puede repartir" "300.00|54|true" "$(res "$TMP/10sa.out")"
dos 10 "fn_nomina_bolsa_repartir('$MES', '$VISTO')->>'asiento'" "fn_nomina_bolsa_repartir('$MES', '$VISTO')->>'asiento'"
revisa "una la reparte; la otra para en llano (MX008 o MX011), sin 23505 ni bloqueo mortal" "1|1|0|0" \
  "$(entran 10)|$(con 10 'MX008\|MX011')|$(con 10 '23505')|$(con 10 '40P01\|deadlock')"
revisa "un solo asiento del reparto, y la bolsa en cero" "1|0.00" \
  "$(ed -c "select (select count(*) from asientos a where a.descripcion like 'Reparto a las obras de lo que quedó en la bolsa%') || '|'
                   || (select coalesce(sum(l.monto), 0)::numeric(14,2) from asiento_lineas l where l.cuenta = '5015')")"
ed -c "$RELOJ" > "$TMP/10reloj2.out" 2>&1
revisa "el reloj de la base, el de verdad otra vez" "$HOY" "$(ed -c "select fn_fecha_miami(now())")"

echo
echo "== Al final"
revisa "ningún 23505 ni 40P01 en ninguna salida" "0" "$(cat "$TMP"/[1-9]*.out | grep -c '23505\|40P01\|deadlock')"
revisa "la cadena del libro, sin rojos (los permisos también)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"
revisa "c3 «mano de obra», en verde (5000 y 5001 vienen de un journal de nómina; el 5010, de su reparto)" "0" "$(ed -c "select count(*) from fn_puentes_verificar() where control = 'mano_de_obra' and not ok")"
revisa "los cuadres del control de la nómina, en verde" "0" "$(ed -c "select count(*) from fn_nomina_control() where nivel = 'cuadre' and not ok")"

echo
if [ $malos -eq 0 ]; then echo "c15-concurrencia: todo bien"; else echo "c15-concurrencia: ALGO FALLA"; fi
exit $malos
