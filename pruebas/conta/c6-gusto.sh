#!/usr/bin/env bash
# =====================================================================
# c6-gusto.sh — «GUSTO» COMO PALABRA ENTERA (14-nov-2026, Fase 11c): lo que
# c6-pruebas.sql y c15-pruebas.sql no pueden probar, porque lo hace EL
# PEGADO y con lo que YA ESTABA en la Bandeja del banco.
#
#   ./c6-gusto.sh [nombre_bd]          (por defecto c6_gusto)
#   PLANTILLA=<bd> ./c6-gusto.sh …     empezar de una base que ya tiene el
#                                       banco DE ANTES (la producción
#                                       simulada: c6 con una marca anterior
#                                       a la de hoy, con c15 o sin ella). Es
#                                       el paso de verdad: lo que el banco
#                                       de antes dejó propuesto, y lo que
#                                       pasa al pegar encima.
# Sin PLANTILLA arma su base con c1 + c2 + c3 + c4 + c6 (el de hoy) + c10 +
# c15, y pone el patrón de fábrica DE ANTES con fn_banco_descriptor (como
# está una base que nadie ajustó, antes de este pegado): el paso del patrón
# se prueba igual; lo que proponía la regla de antes, no (se dice).
#
# LA TABLA es pruebas/conta/nomina/zz-cargos-de-gusto-en-el-banco.csv: 16
# descripciones del banco que SÍ son de nómina y 8 que NO (todo inventado).
# Cada una entra como débito y como depósito.
#   1. ANTES DEL PEGADO. Llegan los 48 movimientos y se «casan» con el banco
#      que haya. Con el banco de antes (PLANTILLA): el débito de 7 de las 8
#      que no son salía «nomina» (el Zelle a un Augusto), y el depósito de
#      ZENPAYROLL no salía (con un banco anterior a la Fase 11b, ningún
#      depósito salía de nómina). Tres se resuelven a propósito, como estarían en
#      producción: el Zelle a un Augusto, clasificado a mano con su motivo
#      (era la única salida); otro, ignorado con su motivo; y la cuota de
#      Gusto, desde la nómina (si c15 está). Eso NO puede cambiar.
#   2. LA NÓMINA DE HOY SOBRE EL BANCO DE ANTES (solo con PLANTILLA y c15):
#      c15-nomina.sql para con MX000, dice que se vuelva a pegar c6 y no
#      toca nada.
#   3. EL PEGADO DEL BANCO (parte 1 y parte 2): el patrón de fábrica de
#      antes pasa al de hoy —gana ZENPAYROLL— con UNA fila en
#      banco_historial (quién, cuándo, antes y después); su resumen, 7 filas
#      en true. Nada de lo resuelto cambia. Lo pendiente conserva su
#      propuesta hasta «Casar» (con la marca nueva, la Bandeja no enseña sus
#      botones hasta entonces). Y con el c15 de antes todavía puesto, su
#      lista de cargos sigue contestando.
#   4. LA NÓMINA DE HOY (c15, si está): entra, 9 filas, sus cuadres en verde.
#   5. «CASAR»: cada descripción de la tabla sale como dice su columna, con
#      los dos signos; el Zelle a un Augusto que seguía pendiente, por lo
#      que es (un cargo sin ticket); lo resuelto, igual que estaba; y la
#      función que lo decide dice de cada pendiente lo mismo que la Bandeja.
#      La nómina (si está): en sus cargos de Gusto, los que son y ninguno
#      de los que no; la cuota resuelta sigue siendo la cuota.
#   6. OTRA VEZ EL PEGADO (el banco entero y la nómina): ni una fila más en
#      el historial del descriptor, y ninguna tabla cambia (ni un dato).
#   7. UN PATRÓN AJUSTADO POR EDGAR NO SE TOCA: se pone uno con
#      fn_banco_descriptor y se pega otra vez: sigue igual, sin rastro
#      nuevo, y el resumen trae una fila más, «c6 · el descriptor de la
#      nómina», en true, con su patrón, el de fábrica y qué hacer. Devuelto
#      el de fábrica, el resumen vuelve a sus 7 filas.
# Y al final: la cadena del libro, la revisión entera del banco y los
# cuadres de la nómina, sin rojos.
#
# PARA MIRAR ANTES DE PEGAR EN PRODUCCIÓN (solo lee; vale con el banco de
# antes, que todavía no tiene la función): los movimientos PENDIENTES cuya
# propuesta va a cambiar con el primer «Casar» después del pegado. Ninguna
# fila = no cambia la propuesta de nada. (Un DEPÓSITO que «será de nómina»
# lo será solo si nada más lo explica —un cobro anotado, una factura por
# ese monto—; si no, sigue como está y su texto avisa.)
#   with d as (select '\m(' || case when patron = '(GUSTO|PAYROLL|\mADP\M|PAYCHEX)'
#                                   then '(GUSTO|ZENPAYROLL|PAYROLL|\mADP\M|PAYCHEX)' else patron end || ')\M' as p
#                from banco_descriptores where clave = 'nomina')
#   select m.cuenta, m.fecha, m.monto, m.descripcion, coalesce(m.estado_motivo, '(sin propuesta)') as hoy,
#          case when x.dice then 'será de nómina' else 'dejará de ser de nómina: saldrá por lo que es' end as despues
#     from movimientos_banco m cross join d
#    cross join lateral (select coalesce(btrim(m.desc_norm || ' ' || coalesce(regexp_replace(upper(m.memo), '[^[:alnum:]#&]+', ' ', 'g'), ''))
#                                        ~* d.p, false) as dice) x
#    where m.estado = 'pendiente' and (m.estado_motivo is not distinct from 'nomina') <> x.dice
#    order by m.fecha, m.monto;
# Y el patrón, por si se ajustó a mano (si no es el de fábrica, el pegado no
# lo toca y lo dice en una fila más de su resumen):
#   select patron from banco_descriptores where clave = 'nomina';
#
# Nombres y montos inventados («ZZ…»): nada de producción. Variables: PGHOST
# (127.0.0.1) y PGPORT (5432), como correr.sh.
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c6_gusto}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'echo "(La base $BD y $TMP quedan: ./correr.sh --borrar $BD; rm -rf $TMP)"' EXIT
else
  trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

if [ -n "${BANCO_SU:-}" ]; then read -r -a PSQL_SU <<< "$BANCO_SU"
elif [ "$(id -u)" = "0" ]; then PSQL_SU=(runuser -u postgres -- psql)
else PSQL_SU=(psql -U postgres); fi
su_psql() { env -u PGHOST "${PSQL_SU[@]}" -X -q -v ON_ERROR_STOP=1 -p "${PGPORT:-5432}" "$@"; }
ed() { PGPASSWORD=editor_sql psql -X -q -At -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }
# (pegar un archivo como el SQL Editor: una transacción, para al primer error; su salida, a un archivo; devuelve el rc de psql)
pegar() { PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$1" > "$2" 2>&1; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}
nota() { echo "     ($1)"; }

FAB_HOY='(GUSTO|ZENPAYROLL|PAYROLL|\mADP\M|PAYCHEX)'
FAB_ANTES='(GUSTO|PAYROLL|\mADP\M|PAYCHEX)'
MARCA_HOY="$(sed -n 's/^as \$\$ select \([0-9]\{10\}\)::bigint \$\$;$/\1/p' "$DOCS/c6-banco.sql" | head -n 1)"
[ -n "$MARCA_HOY" ] || { echo "No encuentro la marca de c6-banco.sql" >&2; exit 2; }
python3 -B "$DIR/partir-c6.py" --comprobar > "$TMP/partes.txt" 2>&1 \
  || { cat "$TMP/partes.txt"; echo "Las partes de c6 no son las de hoy: python3 pruebas/conta/partir-c6.py" >&2; exit 2; }

if [ -n "${PLANTILLA:-}" ]; then
  echo "== Base $BD: copia de $PLANTILLA (el banco que ya estaba)"
  su_psql -d postgres -c "drop database if exists \"$BD\" with (force)" >/dev/null 2>&1
  su_psql -d postgres -c "create database \"$BD\" template \"$PLANTILLA\" owner editor_sql" \
    >/dev/null || { echo "FALLÓ la copia de $PLANTILLA" >&2; exit 2; }
  su_psql -d postgres -c "alter database \"$BD\" set search_path = \"\$user\", public, extensions" -c "grant create on database \"$BD\" to editor_sql" \
    >/dev/null || exit 2
else
  echo "== Base $BD: c1 + c2 + c3 + c4 + c6 (el de hoy) + c10 + c15"
  "$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
    "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$DOCS/c10-costo-obra.sql" "$DOCS/c15-nomina.sql" > "$TMP/carga.out" 2>&1 \
    || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }
fi

MARCA_BD="$(ed -c "select fn_banco_version()")"
HAY_C15="$(ed -c "select (to_regprocedure('public.fn_nomina_cargos()') is not null)::text")"
DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
HOY="$(ed -c "select fn_fecha_miami(now())")"
MES="$(ed -c "select p.periodo from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and fn_fecha_miami(now()) between p.desde and p.hasta")"
[ -n "$DUENO" ] && [ -n "$MES" ] || { echo "No hay un dueño, o el mes de hoy no está abierto: no hay dónde clasificar" >&2; exit 2; }
if [ "$MARCA_BD" -lt "$MARCA_HOY" ]; then ANTES=si; else ANTES=no; fi
echo "     el banco de la base: marca $MARCA_BD (la de hoy: $MARCA_HOY) · la nómina (c15): $HAY_C15 · patrón de «nomina»: $(ed -c "select patron from banco_descriptores where clave = 'nomina'")"
if [ "$ANTES" = "no" ]; then
  # (la base nació con el banco de hoy: se pone el patrón de fábrica de antes, como está una base que nadie ajustó)
  ed -c "select fn_banco_descriptor('nomina', '$FAB_ANTES')" > /dev/null
  nota "la base nació con el banco de hoy: se pone el patrón de fábrica de antes; lo que proponía la REGLA de antes no se prueba aquí (para eso, PLANTILLA=<una base con el banco anterior>)"
fi
revisa "el patrón de «nomina» antes del pegado es el de fábrica de antes" "$FAB_ANTES" "$(ed -c "select patron from banco_descriptores where clave = 'nomina'")"

# Como la app por PostgREST (el dueño con su código): rol authenticated, sus ajustes y el tope de la API.
app() {
  echo "select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"
}
dueno() {  # dueno <sql que devuelve un texto>: lo que devuelve, o su error
  ed -v ON_ERROR_STOP=1 2>&1 <<SQL | sed -n 's/^RESULTADO //p; s/^.*ERROR: *//p'
begin; $(app)
select 'RESULTADO ' || coalesce(($1)::text, '(nulo)');
commit;
SQL
}
# «Casar» lo pendiente del banco hasta que termine (como la pantalla, que vuelve a llamar si no acabó)
casar() { local i; for i in 1 2 3 4 5 6; do [ "$(ed -c "select fn_banco_casar_todo('1010')->>'completo'")" = "true" ] && return 0; done; return 1; }
# la huella de TODAS las tablas de public (para ver que volver a pegar no cambia ni un dato)
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
# lo ya resuelto de la tabla (lo que no puede cambiar): cada movimiento que no está pendiente, con su estado, su motivo, su
# casado y su asiento; y los pagos de la nómina
resuelto() {
  ed -c "select md5(coalesce(string_agg(m.id_externo || '|' || m.estado || '|' || coalesce(m.estado_motivo, '') || '|' || coalesce(m.casado_id::text, '') || '|' || coalesce(m.casado_clase, '') || '|' || coalesce(m.asiento_id::text, ''), ';' order by m.id_externo), '')) || ':' || count(*) from movimientos_banco m where m.id_externo like 'c6g-_-%' and m.estado <> 'pendiente'"
}
historial() { ed -c "select count(*) from banco_historial where tabla = 'banco_descriptores' and clave = 'nomina'"; }
# la tabla, con lo que dice la Bandeja: <débitos que son y salen nomina>|<débitos que no son y salen nomina>|<depósitos que son y salen>|<depósitos que no y salen>
#   (de los pendientes; lo resuelto a propósito se mira aparte)
bandeja() {
  ed -c "select count(*) filter (where t.es_de_nomina = 'si' and m.monto < 0 and m.estado_motivo = 'nomina') || '|' || count(*) filter (where t.es_de_nomina = 'no' and m.monto < 0 and m.estado_motivo = 'nomina') || '|' || count(*) filter (where t.es_de_nomina = 'si' and m.monto > 0 and m.estado_motivo = 'nomina') || '|' || count(*) filter (where t.es_de_nomina = 'no' and m.monto > 0 and m.estado_motivo = 'nomina') from pruebas.c6_gusto_tabla t join movimientos_banco m on m.id_externo in ('c6g-d-' || t.clave, 'c6g-c-' || t.clave) where m.estado = 'pendiente'"
}
mov() { ed -c "select id from movimientos_banco where id_externo = '$1' order by importado_el desc limit 1"; }

# (lo que la fila 180 del cierre ya contaba en esta base, antes de la tabla)
C180_0=0
[ "$HAY_C15" = "true" ] && C180_0="$(ed -c "select coalesce(substring(k.detalle from '^([0-9]+) cargo'), '0') from fn_nomina_cierre('$MES') k where k.orden = 180")"

echo
echo "== 1. Antes del pegado: llegan los 48 movimientos de la tabla y se «casan» con el banco que hay"
ed -v ON_ERROR_STOP=1 > "$TMP/tabla.out" 2>&1 <<SQL || { cat "$TMP/tabla.out"; echo "FALLÓ la tabla" >&2; exit 2; }
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
drop table if exists pruebas.c6_gusto_tabla;
create table pruebas.c6_gusto_tabla (n serial, clave text, es_de_nomina text, descripcion text, memo text, por_que text);
revoke all on pruebas.c6_gusto_tabla from public, anon, authenticated, service_role;
\copy pruebas.c6_gusto_tabla (clave, es_de_nomina, descripcion, memo, por_que) from '$DIR/nomina/zz-cargos-de-gusto-en-el-banco.csv' csv header
SQL
revisa "la tabla: 16 que son de nómina y 8 que no" "16|8" "$(ed -c "select count(*) filter (where es_de_nomina = 'si') || '|' || count(*) filter (where es_de_nomina = 'no') from pruebas.c6_gusto_tabla")"
revisa "entran los 24 débitos y los 24 depósitos (como los trae Plaid)" "24|24" \
  "$(ed -c "select (fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c6-gusto · débitos', 'filas', (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object('id', 'c6g-d-' || t.clave, 'fecha', '$HOY', 'plaid_monto', (310.37 + 7 * t.n)::numeric(12,2)::text, 'descripcion', t.descripcion, 'memo', t.memo, 'tipo', 'DEBIT', 'pendiente', false)) order by t.n) from pruebas.c6_gusto_tabla t)))->>'filas_nuevas') || '|' || (fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c6-gusto · depósitos', 'filas', (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object('id', 'c6g-c-' || t.clave, 'fecha', '$HOY', 'plaid_monto', (-(51.17 + 3 * t.n))::numeric(12,2)::text, 'descripcion', t.descripcion, 'memo', t.memo, 'tipo', 'CREDIT', 'pendiente', false)) order by t.n) from pruebas.c6_gusto_tabla t)))->>'filas_nuevas')")"
casar; revisa "«Casar» termina" "0" "$?"
revisa "ninguno casó solo con algo del libro: los 48 esperan en la Bandeja" "48" "$(ed -c "select count(*) from movimientos_banco where id_externo like 'c6g-_-%' and estado = 'pendiente'")"
if [ "$ANTES" = "si" ] && [ "$MARCA_BD" -ge 2026111301 ]; then
  revisa "CON EL BANCO DE ANTES (la Fase 11b): el débito de 7 de las 8 que NO son salía «nomina» (el Zelle a un Augusto), y el depósito de ZENPAYROLL (2 de 16) no salía" "16|7|14|0" "$(bandeja)"
elif [ "$ANTES" = "si" ]; then
  revisa "CON EL BANCO DE ANTES (anterior a la Fase 11b): el débito de 7 de las 8 que NO son salía «nomina» (el Zelle a un Augusto), y un depósito de Gusto todavía no salía de nómina" "16|7|0|0" "$(bandeja)"
else
  revisa "con el banco de hoy y el patrón de antes: palabra entera, pero ZENPAYROLL (2 débitos y 2 depósitos) no sale" "14|0|14|0" "$(bandeja)"
fi
# Tres se resuelven a propósito (lo que NO puede cambiar con el pegado)
M_AUG="$(mov c6g-d-n02)"; M_IGN="$(mov c6g-d-n03)"; M_FEE="$(mov c6g-d-s03)"
ed -c "select fn_banco_clasificar('$M_AUG', '[{\"cuenta\": \"6130\"}]'::jsonb, 'ZZ c6-gusto: no es nómina, es un Zelle a un Augusto')" > /dev/null 2>"$TMP/clas.err"
revisa "el Zelle a un Augusto, clasificado a mano con su motivo (la salida de antes)" "casado:clasificado" "$(ed -c "select estado || ':' || coalesce(casado_clase, '-') from movimientos_banco where id = '$M_AUG'")"
ed -c "select fn_banco_ignorar('$M_IGN', 'ZZ c6-gusto: no es de la empresa')" > /dev/null 2>&1
revisa "otro, ignorado con su motivo" "ignorado" "$(ed -c "select estado from movimientos_banco where id = '$M_IGN'")"
if [ "$HAY_C15" = "true" ]; then
  revisa "la cuota de Gusto (GUSTO FEE), resuelta desde la nómina" "cuota" "$(dueno "fn_nomina_cargo_cuota('$M_FEE')->>'clase'")"
fi
R0="$(resuelto)"; H0="$(historial)"
PENDN="$(ed -c "select count(*) from movimientos_banco where id_externo like 'c6g-_-%' and estado = 'pendiente'")"
PEND0="$(ed -c "select md5(string_agg(m.id_externo || '|' || coalesce(m.estado_motivo, '-'), ';' order by m.id_externo)) from movimientos_banco m where m.id_externo like 'c6g-_-%' and m.estado = 'pendiente'")"

echo
echo "== 2. La nómina de hoy sobre el banco de antes"
if [ "$ANTES" = "si" ] && [ "$HAY_C15" = "true" ]; then
  T0="$(tablas)"
  pegar "$DOCS/c15-nomina.sql" "$TMP/2.out"
  revisa "c15-nomina.sql no entra: para con MX000 y dice que se vuelva a pegar c6" "3|1" "$?|$(grep -c 'c15-nomina NO se aplicó, no se tocó nada: el c6-banco.sql pegado es anterior al 14-nov-2026.*vuelve a pegar c6-banco.sql' "$TMP/2.out")"
  revisa "y no tocó nada (ni un dato, ni la función de los cargos)" "igual|la de antes" \
    "$([ "$(tablas)" = "$T0" ] && echo igual || echo CAMBIÓ)|$(ed -c "select case when p.prosrc like '%fn_banco_dice_nomina%' then 'LA DE HOY' else 'la de antes' end from pg_proc p where p.oid = to_regprocedure('public.fn_nomina_cargos()')")"
else
  nota "omitida: hace falta una base con el banco de antes y con la nómina (PLANTILLA=<bd>)"
fi

echo
echo "== 3. El pegado del banco: la parte 1 y la parte 2"
pegar "$DOCS/c6-banco-parte1.sql" "$TMP/3a.out"; revisa "la parte 1 entra" "0" "$?"
pegar "$DOCS/c6-banco-parte2.sql" "$TMP/3b.out"; revisa "la parte 2 entra" "0" "$?"
grep -h 'ERROR' "$TMP/3a.out" "$TMP/3b.out" | head -n 4
revisa "su resumen: 7 filas, todas en true (con el patrón de fábrica no sale la fila del descriptor)" "7|0|0" \
  "$(grep -cE '^ *(c6|banco) · .*\| t +\|' "$TMP/3b.out")|$(grep -cE '^ *(c6|banco) · .*\| f +\|' "$TMP/3b.out")|$(grep -c 'c6 · el descriptor de la nómina' "$TMP/3b.out")"
revisa "la marca del banco es la de hoy" "$MARCA_HOY" "$(ed -c "select fn_banco_version()")"
revisa "el patrón de fábrica de antes pasó al de hoy (gana ZENPAYROLL)" "$FAB_HOY" "$(ed -c "select patron from banco_descriptores where clave = 'nomina'")"
revisa "con UNA fila en el historial: un cambio, de antes a hoy" "1|UPDATE|$FAB_ANTES|$FAB_HOY" \
  "$(( $(historial) - H0 ))|$(ed -c "select h.operacion || '|' || (h.antes->>'patron') || '|' || (h.despues->>'patron') from banco_historial h where h.tabla = 'banco_descriptores' and h.clave = 'nomina' order by h.cambiado_el desc limit 1")"
revisa "la revisión del banco da por bueno el descriptor (es el de su último cambio en el historial)" "t" "$(ed -c "select ok from fn_banco_verificar() where control = 'descriptores'")"
revisa "nada de lo resuelto cambió (el clasificado, el ignorado, la cuota)" "igual" "$([ "$(resuelto)" = "$R0" ] && echo igual || echo CAMBIÓ)"
revisa "lo pendiente conserva su propuesta de antes hasta «Casar»" "igual" \
  "$([ "$(ed -c "select md5(string_agg(m.id_externo || '|' || coalesce(m.estado_motivo, '-'), ';' order by m.id_externo)) from movimientos_banco m where m.id_externo like 'c6g-_-%' and m.estado = 'pendiente'")" = "$PEND0" ] && echo igual || echo CAMBIÓ)"
if [ "$ANTES" = "si" ]; then
  revisa "y la Bandeja dice de cada uno que su propuesta es de antes del pegado, sin botones, hasta «Casar»" "$PENDN|0" \
    "$(ed -c "select count(*) filter (where b.texto like 'Esta propuesta es de antes del último pegado del banco%') || '|' || count(*) filter (where b.opciones is not null) from v_banco_bandeja b join movimientos_banco m on m.id = b.movimiento_id where m.id_externo like 'c6g-_-%'")"
fi
revisa "las protecciones del banco, en verde (conocen la función nueva)" "t" \
  "$(ed -c "select case when c.ok then 't' else left(c.detalle, 300) end from fn_banco_control('hoy', array['v_banco_saldos']) c where c.vista = 'cuadre: protecciones del banco'")"
if [ "$ANTES" = "si" ] && [ "$HAY_C15" = "true" ]; then
  revisa "con el banco de hoy y la nómina de antes todavía puesta, su lista de cargos sigue contestando" "sí" \
    "$(ed -c "select case when count(*) >= 0 then 'sí' end from fn_nomina_cargos()" 2>&1 | tail -n 1)"
fi

echo
echo "== 4. La nómina de hoy (c15)"
if [ "$HAY_C15" = "true" ]; then
  pegar "$DOCS/c15-nomina.sql" "$TMP/4.out"; revisa "c15-nomina.sql entra con el banco de hoy" "0" "$?"
  grep -h 'ERROR' "$TMP/4.out" | head -n 4
  revisa "sus nueve filas, y su control sin cuadres en rojo" "9|0 de 5 cuadres en rojo" \
    "$(ed -c "select count(*) from fn_nomina_pegado()")|$(ed -c "select substring(detalle from '^[0-9]+ de [0-9]+ cuadres en rojo') from fn_nomina_pegado() where que = 'control'")"
  revisa "la función de los cargos es la de hoy (pregunta al banco)" "la de hoy" \
    "$(ed -c "select case when p.prosrc like '%fn_banco_dice_nomina%' then 'la de hoy' else 'LA DE ANTES' end from pg_proc p where p.oid = to_regprocedure('public.fn_nomina_cargos()')")"
else
  nota "omitida: esta base no tiene la nómina (c15 es opcional para el banco)"
fi

echo
echo "== 5. «Casar»: la marca nueva rehace lo pendiente"
casar; revisa "«Casar» termina" "0" "$?"
# (de los 48: tres resueltos —dos débitos que no son y la cuota, que sí es, si c15 está—; el resto, pendiente)
if [ "$HAY_C15" = "true" ]; then ESP="15|0|16|0"; else ESP="16|0|16|0"; fi
revisa "cada descripción sale como dice su columna, con los dos signos: de nómina las que son (débitos|…|depósitos|…) y ninguna de las que no" "$ESP" "$(bandeja)"
revisa "el Zelle a un Augusto que seguía pendiente sale por lo que es: un cargo sin ticket (R10), con el aviso de «un Zelle a una persona»" "sin_ticket|R10|sí" \
  "$(ed -c "select m.estado_motivo || '|' || (m.propuesta->>'regla') || '|' || case when m.propuesta->>'texto' like 'Sin ticket ni asiento que lo explique%Un Zelle a una persona%' then 'sí' else left(m.propuesta->>'texto', 80) end from movimientos_banco m where m.id_externo = 'c6g-d-n01'")"
revisa "el depósito de ZENPAYROLL sale de nómina (una devolución de Gusto): antes no" "nomina|nomina" \
  "$(ed -c "select string_agg(m.estado_motivo, '|' order by m.id_externo) from movimientos_banco m where m.id_externo in ('c6g-c-s11', 'c6g-c-s12')")"
revisa "nada de lo resuelto cambió (el clasificado, el ignorado, la cuota)" "igual" "$([ "$(resuelto)" = "$R0" ] && echo igual || echo CAMBIÓ)"
revisa "la función que lo decide dice de cada pendiente lo mismo que la Bandeja" "0" \
  "$(ed -c "select count(*) from movimientos_banco m where m.id_externo like 'c6g-_-%' and m.estado = 'pendiente' and fn_banco_dice_nomina(case when m.memo is null then m.desc_norm else btrim(m.desc_norm || ' ' || fn_banco_norm(m.memo)) end) is distinct from (m.estado_motivo is not distinct from 'nomina')")"
if [ "$HAY_C15" = "true" ]; then
  revisa "la nómina: en sus cargos de Gusto, los pendientes que son (15 débitos y 16 depósitos) y ninguno de los que no" "31|0" \
    "$(ed -c "select count(*) filter (where t.es_de_nomina = 'si') || '|' || count(*) filter (where t.es_de_nomina = 'no') from fn_nomina_cargos() g join movimientos_banco m on m.id = g.movimiento_id join pruebas.c6_gusto_tabla t on m.id_externo in ('c6g-d-' || t.clave, 'c6g-c-' || t.clave) where g.estado = 'pendiente'")"
  revisa "y la cuota que se resolvió antes del pegado sigue siendo la cuota" "cuota" "$(ed -c "select g.estado from fn_nomina_cargos() g where g.movimiento_id = '$M_FEE'")"
  revisa "la fila 180 del cierre cuenta 31 más: los de Gusto, no los Zelle" "31" "$(( $(ed -c "select coalesce(substring(k.detalle from '^([0-9]+) cargo'), '0') from fn_nomina_cierre('$MES') k where k.orden = 180") - C180_0 ))"
fi

echo
echo "== 6. Otra vez el pegado (el banco entero y la nómina): nada cambia"
H1="$(historial)"; T1="$(tablas)"
pegar "$DOCS/c6-banco.sql" "$TMP/6a.out"; revisa "c6-banco.sql entero, otra vez" "0" "$?"
if [ "$HAY_C15" = "true" ]; then pegar "$DOCS/c15-nomina.sql" "$TMP/6b.out"; revisa "c15-nomina.sql, otra vez" "0" "$?"; fi
revisa "ni una fila más en el historial del descriptor" "0" "$(( $(historial) - H1 ))"
revisa "ninguna tabla cambió (ni un dato)" "igual" "$([ "$(tablas)" = "$T1" ] && echo igual || echo CAMBIÓ)"

echo
echo "== 7. Un patrón ajustado por Edgar no se toca, y el pegado lo dice"
ed -c "select fn_banco_descriptor('nomina', '(GUSTO|ZZNOMINA)')" > /dev/null
H2="$(historial)"
pegar "$DOCS/c6-banco.sql" "$TMP/7a.out"; revisa "c6-banco.sql entra" "0" "$?"
revisa "el patrón sigue siendo el de Edgar, sin rastro nuevo" "(GUSTO|ZZNOMINA)|0" "$(ed -c "select patron from banco_descriptores where clave = 'nomina'")|$(( $(historial) - H2 ))"
revisa "el resumen trae una fila más, en true: «c6 · el descriptor de la nómina», con su patrón, el de fábrica y qué hacer" "8|0|1" \
  "$(grep -cE '^ *(c6|banco) · .*\| t +\|' "$TMP/7a.out")|$(grep -cE '^ *(c6|banco) · .*\| f +\|' "$TMP/7a.out")|$(grep -cE 'c6 · el descriptor de la nómina +\| t +\| "OJO: el patrón del descriptor «nomina» de esta base no es el de fábrica.*\(GUSTO\|ZZNOMINA\).*\(GUSTO\|ZENPAYROLL\|PAYROLL.*PALABRA ENTERA.*fn_banco_descriptor' "$TMP/7a.out")"
ed -c "select fn_banco_descriptor('nomina', '$FAB_HOY')" > /dev/null
pegar "$DOCS/c6-banco.sql" "$TMP/7b.out"; revisa "devuelto el de fábrica, c6-banco.sql entra" "0" "$?"
revisa "y el resumen vuelve a sus 7 filas" "7|0" "$(grep -cE '^ *(c6|banco) · .*\| t +\|' "$TMP/7b.out")|$(grep -c 'c6 · el descriptor de la nómina' "$TMP/7b.out")"

echo
echo "== Al final"
revisa "la cadena del libro, sin rojos (los permisos también)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"
revisa "la revisión entera del banco (fn_banco_verificar): nada en rojo" "ninguno" "$(ed -c "select coalesce(string_agg(control, '; ') filter (where not ok), 'ninguno') from fn_banco_verificar()")"
if [ "$HAY_C15" = "true" ]; then
  revisa "los cuadres de la nómina, sin rojos" "0" "$(ed -c "select count(*) from fn_nomina_control() where nivel = 'cuadre' and not ok")"
fi

echo
if [ $malos -eq 0 ]; then echo "c6-gusto: todo bien"; else echo "c6-gusto: ALGO FALLA"; fi
exit $malos
