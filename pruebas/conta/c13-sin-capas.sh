#!/usr/bin/env bash
# =====================================================================
# c13-sin-capas.sh — lo que c13-pruebas.sql solo puede fingir: la cédula
# de corte (c13) sobre bases DE VERDAD a las que les faltan las capas
# opcionales, la capa que llega después, y volver a pegar c13 con lo
# guardado dentro y con la pantalla leyendo.
#
#   ./c13-sin-capas.sh [nombre_bd]      (por defecto c13_sin_capas)
#
# 1. LA CADENA MÍNIMA: c1 + c2 + c3 y nada más (ni c4, ni c6, ni c9, ni
#    c12, ni p1). c13 se pega (dos veces): no pide ninguna de ellas. Su
#    pegado dice que no encontró ninguna; la cédula sale completa; cada
#    cuenta de una capa que falta dice «sin auxiliar: esa parte no está en
#    esta base»; lo que sale del propio libro (por cobrar, por pagar, el use
#    tax, el patrimonio) sigue teniendo su auxiliar, y la fila dice qué hay
#    debajo (las partidas del libro, o el propio libro); QuickBooks sale vacío;
#    el dueño, por la API, escribe un renglón a mano y una explicación; y
#    c13-pruebas.sql corre: lo que necesita una capa sale «omitida»
#    diciéndolo y nada falla.
# 2. LLEGAN c4 Y c6 DESPUÉS (se pegan encima, con c13 ya puesto): SIN volver
#    a pegar c13 la cédula ya los lee (un banco deja de decir «esa parte no
#    está» y pasa a «todavía no tiene ninguna conciliación confirmada»), y lo
#    escrito sigue ahí. Los activos, el WIP y Stripe siguen sin su capa.
# 3. VOLVER A PEGAR c13 (dos veces) con un renglón, una explicación y la
#    configuración cambiada dentro: no pisa nada (las mismas filas, tal
#    cual). Y c13-pruebas.sql otra vez: ahora solo se omite lo de c9, c12 y
#    p1.
# 4. VOLVER A PEGAR c13 CON LA PANTALLA LEYENDO (una lectura larga de la
#    cédula; el pegado medio segundo después): el pegado se rinde con 55P03
#    («lock timeout») en menos de 3 s, o entra; nadie muere por 40P01; sin
#    nadie leyendo, entra, y lo guardado sigue ahí.
# Y comprueba al final: la cadena del libro y sus permisos (c2) en verde, los
# puentes (c3) sin nada nuevo en rojo, y el control de la cédula (el 10 y el
# 90) en verde.
#
# Cada sesión de «la app» va como por PostgREST: el dueño, con el rol
# authenticated, los ajustes de ese rol y el tope de la API (8 s).
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c13_sin_capas}"
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

# Como la app por PostgREST: con el rol authenticated, los ajustes de ese
# rol y el tope de la API (8 s). app <quién>.
app() {
  echo "select set_config('request.jwt.claims', '{\"sub\":\"$1\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"
}

# c13-pruebas.sql sobre la base: la línea PRUEBAS y qué pruebas salen omitidas
# (como correr.sh: la tabla _pruebas es temporal, se lee en la misma sesión).
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
SQL
pruebas() {  # pruebas <salida>
  PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" \
    -c '\o /dev/null' -f "$DOCS/c13-pruebas.sql" -f "$TMP/resumen.sql" > "$1" 2>&1
}
# lo que c13 guarda, en una línea (para ver que volver a pegar no lo pisa)
guardado() {
  ed -c "select concat_ws('|', (select md5(string_agg(to_jsonb(c)::text, ',')) from cedula_config c),
                           (select count(*) || ':' || coalesce(md5(string_agg(to_jsonb(m)::text, ',' order by m.creado_el, m.id)), '-') from cedula_manual m),
                           (select count(*) || ':' || coalesce(md5(string_agg(to_jsonb(e)::text, ',' order by e.explicado_el, e.id)), '-') from cedula_explicaciones e))"
}
capas() { ed -c "select string_agg(t.k || '=' || t.v, ' ' order by t.k) from jsonb_each_text(fn_cedula_capas()) as t(k, v)"; }

echo "== 1. La cadena mínima: c1 + c2 + c3, y c13 (dos veces)"
"$DIR/correr.sh" "$BD" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c13-cedula.sql" "$DOCS/c13-cedula.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
HOY="$(ed -c "select fn_fecha_miami(now())")"
ROJOS_C3="$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_puentes_verificar() where not ok")"
# un banco de la base (la cuenta del puente «banco» de c3) para escribirle a mano
BANCO="$(ed -c "select coalesce((select cuenta from puente_cuentas where rol = 'banco'), '1010')")"

revisa "c13 no encontró ninguna capa opcional" "c12=false c4=false c6=false c9=false p1=false" "$(capas)"
revisa "su pegado lo dice (las cinco, «NO está»), y no habla del cierre (aquí no hay cierre)" "5|no" \
  "$(ed -c "select (select (length(g.detalle) - length(replace(g.detalle, 'NO está', ''))) / length('NO está') from fn_cedula_pegado() g where g.que = 'capas que lee')
                   || '|' || (select case when g.detalle like '%cierre%' then 'sí' else 'no' end from fn_cedula_pegado() g where g.que = 'siguiente paso')")"
revisa "la cédula sale completa: una fila por cuenta de balance, y su control 10 y 90 en verde" "sí|verde|verde" \
  "$(ed -c "select case when (select count(*) from fn_cedula('$HOY')) = (select count(*) from cuentas k where k.tipo in ('activo', 'pasivo', 'capital') and k.imputable
                                                                           and (k.activa or exists (select 1 from asiento_lineas l where l.cuenta = k.codigo)))
                            and (select count(*) from fn_cedula('$HOY')) > 20 then 'sí' else 'no' end
                   || '|' || (select case when ok then 'verde' else 'rojo' end from fn_cedula_control(null) where orden = 10)
                   || '|' || (select case when ok then 'verde' else 'rojo' end from fn_cedula_control(null) where orden = 90)")"
revisa "cada cuenta de una capa que falta: sin auxiliar, y dice que esa parte no está (bancos y tarjetas, préstamos, pólizas, activos, WIP, Stripe)" "0 mal de más de 10" \
  "$(ed -c "select count(*) filter (where not (x.estado = 'sin_auxiliar' and x.por_que = 'capa' and x.saldo_auxiliar is null
                                                and x.detalle like 'Sin auxiliar: la parte de% no está en esta base.%'))
                   || ' mal de ' || case when count(*) > 10 then 'más de 10' else count(*)::text end
              from fn_cedula('$HOY') x
             where x.fuente in ('conciliacion', 'prestamos', 'prepagados', 'activos', 'depreciacion', 'wip', 'stripe', 'stripe_paso')")"
revisa "lo que sale del propio libro sigue con su auxiliar (por cobrar, la retención, por pagar, el use tax y el patrimonio)" "0" \
  "$(ed -c "select count(*) from fn_cedula('$HOY') x where x.fuente in ('partidas', 'dr15', 'devengos', 'mayor') and (x.estado = 'sin_auxiliar' or x.saldo_auxiliar is null)")"
revisa "y la fila dice qué hay debajo: las partidas del propio libro, o el propio libro (que no se llama «cuadra»: «del libro»)" "0|0|sí" \
  "$(ed -c "select (select count(*) from fn_cedula('$HOY') x where x.fuente in ('partidas', 'devengos') and x.sosten is distinct from 'partidas')
                   || '|' || (select count(*) from fn_cedula('$HOY') x where x.fuente in ('dr15', 'mayor') and (x.sosten is distinct from 'libro' or x.estado <> 'del_libro' or x.pendiente))
                   || '|' || (select case when (r->>'del_libro')::int = (select count(*) from fn_cedula('$HOY') x where x.fuente in ('dr15', 'mayor'))
                                              and (r->>'balance_cuadra')::boolean then 'sí' else 'no' end
                                from (select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true)) z,
                                     lateral (select fn_cedula_resumen('$HOY') as r) y)")"
revisa "QuickBooks sale vacío: ningún período con balanza, y la cédula de un mes sin las columnas de QuickBooks" "0|sin QuickBooks" \
  "$(ed -c "select (select count(*) from fn_cedula_qb_periodos()) || '|' ||
                   (select case when count(*) > 20 and not bool_or(q.qb_cargada) and count(q.saldo_qb) = 0 then 'sin QuickBooks' else 'CON' end
                      from fn_cedula_qb((select p.periodo from periodos p where p.tipo = 'mes' order by p.desde limit 1)) q)")"

# El dueño, por la API: un renglón a mano en un banco (su capa no está) y su explicación; y la configuración.
ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO")
  select 'RENGLON ' || (fn_cedula_renglon('{\"cuenta\": \"$BANCO\", \"concepto\": \"C13 SIN CAPAS: lo que dice el statement\", \"monto\": \"100.00\", \"desde\": \"$HOY\", \"documento\": \"C13 SIN CAPAS statement\"}')->>'cuenta');
  select 'EXPLICADA ' || (fn_cedula_explicar('$BANCO', '$HOY', 'C13 SIN CAPAS: el depósito de apertura todavía no está en el libro')->>'estado');
  select 'CONFIG ' || (fn_cedula_config('{\"avisar_desde\": \"2027-01\", \"patrimonio\": \"manual\"}')->>'avisar_desde');
  commit;" > "$TMP/1app.out" 2>&1
revisa "el dueño, por la API, escribe un renglón a mano, lo explica y cambia la configuración" "RENGLON $BANCO|EXPLICADA no_cuadra|CONFIG 2027-01|0" \
  "$(grep -o 'RENGLON .*' "$TMP/1app.out")|$(grep -o 'EXPLICADA .*' "$TMP/1app.out")|$(grep -o 'CONFIG .*' "$TMP/1app.out")|$(grep -c 'ERROR' "$TMP/1app.out")"
revisa "ese banco, sin su capa y con su renglón: tiene auxiliar (el renglón) y queda explicado" "conciliacion|100.00|explicada" \
  "$(ed -c "select x.fuente || '|' || x.saldo_auxiliar || '|' || x.estado from fn_cedula('$HOY') x where x.cuenta = '$BANCO'")"
G1="$(guardado)"

pruebas "$TMP/p1.out"
revisa "c13-pruebas.sql sobre c1 + c2 + c3: 41 filas, ninguna falla" "41|0" \
  "$(sed -n 's/^PRUEBAS total=\([0-9]*\) .* fallan=\([0-9]*\) .*/\1|\2/p' "$TMP/p1.out")"
revisa "y lo que necesita una capa sale «omitida» diciéndolo (c6: 11, 12, 13, 16, 33, 35 y 37; c12: 14; c9: 15 y 30; p1: 19; c4: 26), y nada más" \
  "11 12 13 14 15 16 19 26 30 33 35 37|11 12 13 14 15 16 19 26 30 33 35 37" \
  "$(sed -n 's/^OMITIDAS //p' "$TMP/p1.out")|$(sed -n 's/^POR CAPA //p' "$TMP/p1.out")"
grep '^FALLA \|ERROR' "$TMP/p1.out" | head -n 12
revisa "las pruebas no dejaron nada (lo guardado, tal cual)" "$G1" "$(guardado)"

echo
echo "== 2. Llegan c4 y c6 después (encima, con c13 ya puesto), sin volver a pegar c13"
pegar "$DOCS/c4-estados.sql" > "$TMP/2c4.out" 2>&1 || { tail -n 20 "$TMP/2c4.out"; echo "FALLÓ pegar c4 encima de c13" >&2; exit 2; }
pegar "$DOCS/c6-banco.sql"   > "$TMP/2c6.out" 2>&1 || { tail -n 20 "$TMP/2c6.out"; echo "FALLÓ pegar c6 encima de c13" >&2; exit 2; }
revisa "c13 las ve sin que nadie la toque" "c12=false c4=true c6=true c9=false p1=false" "$(capas)"
revisa "un banco sin renglones ya no dice «esa parte no está»: dice que todavía no tiene ninguna conciliación confirmada" "0|sí" \
  "$(ed -c "select (select count(*) from fn_cedula('$HOY') x where x.fuente in ('conciliacion', 'prestamos', 'prepagados') and x.por_que = 'capa')
                   || '|' || (select case when count(*) > 0 and bool_and(x.por_que = 'vacio' and x.detalle like 'Sin auxiliar: todavía no tiene ninguna conciliación confirmada.%')
                                          then 'sí' else 'no' end
                                from fn_cedula('$HOY') x where x.fuente = 'conciliacion' and x.renglones = 0)")"
revisa "los activos, el WIP y Stripe siguen sin su capa" "sí" \
  "$(ed -c "select case when count(*) > 0 and bool_and(x.estado = 'sin_auxiliar' and x.por_que = 'capa') then 'sí' else 'no' end
              from fn_cedula('$HOY') x where x.fuente in ('activos', 'depreciacion', 'wip', 'stripe', 'stripe_paso')")"
revisa "y lo escrito sigue ahí: el banco con su renglón, explicado; lo guardado, tal cual" "100.00|explicada|igual" \
  "$(ed -c "select x.saldo_auxiliar || '|' || x.estado from fn_cedula('$HOY') x where x.cuenta = '$BANCO'")|$([ "$(guardado)" = "$G1" ] && echo igual || echo CAMBIÓ)"
revisa "QuickBooks (c4) ya responde: la apertura, si la hay, y ningún error" "0" \
  "$(ed -c "select count(*) from v_cedula_qb where periodo = 'no-existe'" 2>&1 | grep -c 'ERROR')"

echo
echo "== 3. Volver a pegar c13 (dos veces) con lo guardado dentro"
pegar "$DOCS/c13-cedula.sql" > "$TMP/3a.out" 2>&1; revisa "entra" "0" "$?"
pegar "$DOCS/c13-cedula.sql" > "$TMP/3b.out" 2>&1; revisa "y otra vez" "0" "$?"
revisa "no pisa nada: la configuración, el renglón y la explicación, tal cual" "$G1" "$(guardado)"
revisa "la configuración sigue siendo la que puso el dueño (no vuelve a la de fábrica)" "2027-01|manual|1" \
  "$(ed -c "select avisar_desde || '|' || patrimonio || '|' || (select count(*) from cedula_config) from cedula_config where id = 1")"
pruebas "$TMP/p3.out"
revisa "c13-pruebas.sql con c4 y c6: 41 filas, ninguna falla" "41|0" \
  "$(sed -n 's/^PRUEBAS total=\([0-9]*\) .* fallan=\([0-9]*\) .*/\1|\2/p' "$TMP/p3.out")"
revisa "ahora solo se omite lo de c12 (14), c9 (15 y 30) y p1 (19)" "14 15 19 30|14 15 19 30" \
  "$(sed -n 's/^OMITIDAS //p' "$TMP/p3.out")|$(sed -n 's/^POR CAPA //p' "$TMP/p3.out")"
grep '^FALLA \|ERROR' "$TMP/p3.out" | head -n 12
revisa "las pruebas no dejaron nada" "$G1" "$(guardado)"

echo
echo "== 4. Volver a pegar c13 con la pantalla leyendo la cédula"
( ed -c "begin; $(app "$DUENO") select count(*) from v_cedula; select count(*) from v_cedula_control; select count(*) from v_cedula_manual; select count(*) from v_cedula_explicaciones; select pg_sleep(3); commit;" > "$TMP/4l.out" 2>&1 ) &
sleep 0.5
t0=$(date +%s.%N)
pegar "$DOCS/c13-cedula.sql" > "$TMP/4p.out" 2>&1
rc=$?
t1=$(date +%s.%N)
wait
seg="$(echo "$t1 - $t0" | bc)"
if grep -q '55P03\|lock timeout\|canceling statement due to lock timeout' "$TMP/4p.out"; then como="se rindió con 55P03"; elif [ $rc -eq 0 ]; then como="entró"; else como="OTRO error"; tail -n 3 "$TMP/4p.out"; fi
echo "     (el pegado $como en $seg s)"
revisa "el pegado se rinde (55P03) o entra, en menos de 3 s" "1" "$( { [ "$como" != "OTRO error" ] && [ "$(echo "$seg < 3" | bc)" = "1" ]; } && echo 1 || echo 0)"
revisa "nadie muere por un bloqueo mortal (40P01), y la lectura termina" "0|0" "$(cat "$TMP"/4p.out "$TMP"/4l.out | grep -c '40P01\|deadlock')|$(grep -c 'ERROR' "$TMP/4l.out")"
pegar "$DOCS/c13-cedula.sql" > "$TMP/4p2.out" 2>&1
revisa "sin nadie leyendo, entra" "0" "$?"
revisa "y lo guardado sigue ahí" "$G1" "$(guardado)"

echo
echo "== Al final"
revisa "la cadena del libro, sin rojos (los permisos también, con c13 puesto)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"
revisa "los puentes (c3): nada nuevo en rojo" "$ROJOS_C3" "$(ed -c "select coalesce(string_agg(control, '; ' order by control), '') from fn_puentes_verificar() where not ok")"
revisa "las protecciones del banco (c6) y de «Estados» (c4), en verde con c13 puesto" "0" \
  "$(ed -c "select (select count(*) from fn_banco_control('hoy', array['cuadre: el otro lado de cada casado']) x where x.vista = 'cuadre: protecciones del banco' and not x.ok)
                 + (select count(*) from fn_estados_control('hoy', array['v_saldos_dinero']) y where y.vista = 'cuadre: protecciones de c4' and not y.ok)")"
revisa "el control de la cédula: el 10 (trae todas las cuentas y su saldo es el del libro) y el 90 (las protecciones), en verde" "0" \
  "$(ed -c "select count(*) from fn_cedula_control(null) where nivel = 'cuadre' and not ok")"

echo
if [ $malos -eq 0 ]; then echo "c13-sin-capas: todo bien"; else echo "c13-sin-capas: ALGO FALLA"; fi
exit $malos
