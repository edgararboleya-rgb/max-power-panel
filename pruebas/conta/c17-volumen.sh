#!/usr/bin/env bash
# =====================================================================
# c17-volumen.sh — lo que c17-pruebas.sql no puede ver con los pocos
# movimientos de una prueba: que la Bandeja nueva CONTESTA con la Bandeja
# LLENA, como la de Edgar el día que la estrene (unos 380 pendientes de
# unos 110 comercios) y con más del doble (unos 1,000), sin que ninguna
# llamada se acerque al corte de la API.
# (21-nov-2026, tercera vuelta de c17: la segunda revisión midió que leer
# la Bandeja tardaba 1.7 s en el banco con 377 pendientes —el doble del
# tope de la casa— y que los relojes de leer, decidir un grupo, deshacer
# una tanda y la rutina eran iguales o mayores que el corte de 8 s.)
#
#   ./c17-volumen.sh <plantilla> [nombre_bd]   (por defecto c17_volumen)
#
# <plantilla>: una base del banco con la cadena ya pegada (c1 … c16; la de
# la casa, g16a con las capas del árbol encima). Se CLONA (la plantilla no
# se toca) y a la copia se le pega c17-bandeja.sql, la semilla de la fase
# 19 (f19-semilla.sql: una Bandeja con treinta movimientos) y, encima, EL
# VOLUMEN: cargos de 27 comercios corrientes (uno con 34 cargos, otro con
# 22…), 80 comercios de un solo cargo, Zelle a personas, depósitos de
# clientes, de un procesador de tarjetas, cheques y cajero. Primero hasta
# unos 400 pendientes; después, hasta unos 1,000.
#
# COMO EN PRODUCCIÓN. La instancia de Supabase va unas diez veces más
# despacio que este banco y la API corta cada llamada a los 8 s. A la
# velocidad del banco eso es 0,8 s por llamada, y los relojes de c17 a la
# décima parte: el de leer (2.5 s) en 250 ms y los de decidir un grupo,
# deshacer una tanda y la rutina (3 s) en 300 ms. Cada cosa se pide como el
# dueño por la API (su rol, los ajustes de ese rol, el corte de 8 s), y
# como la pide la pantalla: otra vez lo que «falta» o «sigue».
#
# LO QUE COMPRUEBA, con 400 y con 1,000 pendientes:
#   1. LEER POR PARTES: la primera llamada (el reloj de producción) trae
#      TODAS las tarjetas (las que no dio tiempo, «pensando») y lo que
#      falta; se pide con {ids} hasta que no falte nada. Cada llamada, no
#      más de 0,8 s; cada tarjeta se recomienda UNA vez; con 400, en cuatro
#      llamadas o menos (con 1,000, en diez).
#   2. LEER CON EL RELOJ DE FÁBRICA (como lo llama la pantalla): se informa
#      lo que tarda y cuánto recomienda; nunca más de 4 s en el banco.
#   3. DECIDIR EL GRUPO MÁS GRANDE («es mío» para todos sus cargos) con su
#      reloj de producción: cada llamada no más de 0,8 s, «sigue» hasta
#      terminar, todo en UNA tanda; y DESHACER esa tanda igual.
#   4. LA RUTINA QUE REGISTRA SOLA con una regla «que entre solo» en el
#      comercio de gasolina con más cargos: los que ya esperaban cuando se
#      puso la regla NO entran solos (cuarta vuelta); los 25 que llegan
#      después, sí: cada llamada no más de 0,8 s hasta que dice «completo».
#   5. EL CONTROL de la capa: no más de 0,8 s y ningún cuadre en rojo.
# Lo de 3 y 4 se deshace (cada medición va en una transacción que no se
# confirma): la Bandeja sigue llena para la medición siguiente.
#   6. Al final, c17-pruebas.sql ENTERO sobre esa Bandeja de 1,000: nada en
#      rojo (las pruebas valen en una base en uso).
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja). Marcas de comercios corrientes y
# nombres inventados («ZZ …»); nada de producción.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
[ $# -ge 1 ] || { sed -n '13,13p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }
PLANTILLA="$1"
BD="${2:-c17_volumen}"
for x in "$PLANTILLA" "$BD"; do
  [[ "$x" =~ ^[a-z][a-z0-9_]{0,62}$ ]] || { echo "Nombre de base inválido: '$x'" >&2; exit 64; }
done
case "$BD" in postgres|template0|template1|"$PLANTILLA") echo "No se toca la base '$BD'." >&2; exit 64;; esac

# Como en producción, a la velocidad del banco
PROD_LLAMADA_MS=800
PROD_RELOJ_LEER=250
PROD_RELOJ_HACER=300

if [ -n "${BANCO_SU:-}" ]; then
  read -r -a PSQL_SU <<< "$BANCO_SU"
elif [ "$(id -u)" = "0" ]; then
  PSQL_SU=(runuser -u postgres -- psql)
else
  PSQL_SU=(psql -U postgres)
fi
su_psql() { env -u PGHOST "${PSQL_SU[@]}" -X -q -v ON_ERROR_STOP=1 -p "${PGPORT:-5432}" "$@"; }
ed() { PGPASSWORD=editor_sql psql -X -q -At -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'echo "(La base $BD y $TMP quedan: borrarlas a mano)"' EXIT
else
  trap 'su_psql -d postgres -c "drop database if exists \"$BD\" with (force)" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

echo "== La copia de $PLANTILLA: $BD"
su_psql -d postgres -c "drop database if exists \"$BD\" with (force)" > "$TMP/clon.out" 2>&1 \
  && su_psql -d postgres -c "create database \"$BD\" template \"$PLANTILLA\" owner editor_sql" >> "$TMP/clon.out" 2>&1 \
  && su_psql -d postgres -c "grant create on database \"$BD\" to editor_sql" >> "$TMP/clon.out" 2>&1 \
  || { tail -n 5 "$TMP/clon.out"; echo "FALLÓ la copia (¿alguien está conectado a $PLANTILLA?)" >&2; exit 2; }

echo "== c17-bandeja.sql y la semilla de la fase 19"
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" \
  -f "$DOCS/c17-bandeja.sql" > "$TMP/pegado.out" 2>&1 \
  || { tail -n 12 "$TMP/pegado.out"; echo "FALLÓ el pegado de c17" >&2; exit 2; }
ed -v ON_ERROR_STOP=1 -f "$DIR/f19-semilla.sql" > "$TMP/semilla.out" 2>&1 \
  || { tail -n 12 "$TMP/semilla.out"; echo "FALLÓ la semilla" >&2; exit 2; }

# EL VOLUMEN. volumen <ronda> <veces>: los comercios grandes con «veces» por
# sus cargos de fábrica (1 = la Bandeja de Edgar; después, más), los de un
# solo cargo, y lo demás. Cada movimiento entra como lo trae Plaid, en
# nombre del dueño, y pasa por «Casar» (queda pendiente en la Bandeja).
cat > "$TMP/volumen.sql" <<'SQL'
\set ON_ERROR_STOP 1
select set_config('vol.ronda', :'ronda', false) is not null as ronda;
select set_config('vol.veces', :'veces', false) is not null as veces;
do $$
declare
  c_ronda text := current_setting('vol.ronda');
  c_veces numeric := current_setting('vol.veces')::numeric;
  v_d     text := (select id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1);
  v_tarj  text := coalesce((select t.cuenta from tarjetas t where coalesce(t.activa, true) order by t.cuenta limit 1), '1010');
  v_hoy   date := fn_fecha_miami(now());
  v_ini   date := date_trunc('month', fn_fecha_miami(now()))::date;
  r record; k int := 0; v_mov uuid; v_f date;
begin
  create temp table if not exists _com (n serial, texto text, cuantos int, base numeric, tarjeta boolean) on commit drop;
  truncate _com;
  insert into _com (texto, cuantos, base, tarjeta) values
    ('THE HOME DEPOT #6341 OCALA FL', 34, 180, true), ('LOWES #00907 OCALA FL', 22, 95, true), ('CITY ELECTRIC SUPPLY OCALA', 18, 410, true),
    ('WAWA 5234 OCALA FL', 16, 58, true), ('SHELL OIL 57444 OCALA FL', 12, 61, true), ('RACETRAC 2399 OCALA FL', 9, 47, true),
    ('AMAZON MKTPLACE PMTS AMZN.COM/BILL WA', 14, 73, true), ('SUNPASS*ACC12345678 888-865-5352 FL', 10, 20, true), ('DOORDASH*ZZ TACOS', 11, 29, false),
    ('PUBLIX #1234 OCALA FL', 9, 64, false), ('MCDONALDS F10293 OCALA FL', 8, 13, false), ('CHICK-FIL-A #03321 OCALA FL', 6, 17, false),
    ('KLARNA 8J2 PAYMENT', 6, 45, false), ('AFFIRM INC AFFIRM PAY', 5, 88, false), ('AFTERPAY US INC', 4, 31, false), ('NETFLIX.COM', 3, 15.49, false),
    ('GOOGLE *YOUTUBEPREMIUM', 3, 13.99, false), ('MICROSOFT*XBOX GAME PASS', 3, 16.99, false), ('APPLE.COM/BILL 866-712-7753 CA', 5, 9.99, false),
    ('VERIZON WIRELESS AUTOPAY', 3, 212, false), ('GEICO *AUTO 800-841-3000', 3, 388, false), ('ZZ COUNTY BOCC PERMITS', 6, 250, false),
    ('CITY OF ZZ BLDG PERMIT', 4, 125, false), ('ZZ ELECTRIC WHOLESALE SUPPLY OF CENTRAL FLORIDA LLC 0042', 8, 322, true),
    ('SQ *ZZ FERRETERIA Y SUMINISTROS DEL CENTRO', 7, 54, true), ('TST* ZZ RESTAURANTE LA ESQUINA DEL SABOR OCALA', 5, 41, false),
    ('WALMART SUPERCENTER #0697 OCALA FL', 6, 77, false);
  perform set_config('request.jwt.claims', json_build_object('sub', v_d, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  perform set_config('request.jwt.claim.sub', v_d, true);
  -- (un movimiento: la fecha, dentro del mes abierto; montos distintos, para que ninguno parezca el duplicado de otro)
  for r in
    select row_number() over () as k, x.texto, x.monto, x.cuenta from (
      select c.texto, -round((c.base * (0.6 + ((c.n * 31 + g * 13) % 90) / 100.0) + g * 0.01 + c_ronda::int * 0.03)::numeric, 2) as monto,
             case when c.tarjeta then v_tarj else '1010' end as cuenta
        from _com c cross join lateral generate_series(1, ceil(c.cuantos * c_veces)::int) g
      union all
      select 'ZZ COMERCIO ' || (array['TALLER', 'PINTURAS', 'ALQUILER DE EQUIPO', 'CAFETERIA', 'PAPELERIA', 'NEUMATICOS', 'SEGUROS', 'SOFTWARE'])[1 + g % 8]
             || ' ' || c_ronda || lpad(g::text, 3, '0') || ' OCALA FL',
             -round((20 + (g * 17) % 400 + ((g * 31) % 100) / 100.0 + c_ronda::int * 0.03)::numeric, 2), case when g % 3 = 0 then '1010' else v_tarj end
        from generate_series(1, ceil(80 * c_veces)::int) g
      union all
      select 'ZELLE PAYMENT TO ZZ PERSONA ' || (array['UNO', 'DOS', 'TRES', 'CUATRO'])[1 + g % 4] || ' JPM' || c_ronda || g, -(300 + g * 50 + g * 0.07)::numeric(14,2), '1010'
        from generate_series(1, ceil(12 * c_veces)::int) g
      union all
      select 'ZELLE PAYMENT FROM ZZ CLIENTE ' || (array['ALFA', 'BETA', 'GAMMA', 'DELTA', 'OMEGA'])[1 + g % 5] || ' LLC ' || c_ronda || g, (900 + g * 137.25)::numeric(14,2), '1010'
        from generate_series(1, ceil(10 * c_veces)::int) g
      union all
      select 'INTUIT 77788899 DEPOSIT', (2100 + g * 311.4 + c_ronda::int * 0.13)::numeric(14,2), '1010' from generate_series(1, ceil(6 * c_veces)::int) g
      union all
      select 'REMOTE ONLINE DEPOSIT # ' || c_ronda || g, (1500 + g * 420 + c_ronda::int * 0.17)::numeric(14,2), '1010' from generate_series(1, ceil(4 * c_veces)::int) g
      union all
      select 'ATM CASH DEPOSIT 1234 ZZ MAIN ST', (400 * g + c_ronda::int * 0.19)::numeric(14,2), '1010' from generate_series(1, ceil(3 * c_veces)::int) g) x
  loop
    v_f := greatest(v_hoy - 2 - ((r.k * 7) % 25)::int, v_ini);
    perform fn_banco_importar_filas(jsonb_build_object(
      'origen', 'plaid', 'cuenta', r.cuenta, 'nombre', 'Plaid · c17-volumen · ' || c_ronda || '-' || r.k,
      'filas', jsonb_build_array(jsonb_build_object(
                 'id', 'ZZV17-' || c_ronda || '-' || r.k, 'fecha', v_f::text, 'plaid_monto', (-r.monto)::text, 'descripcion', r.texto,
                 'tipo', case when r.monto > 0 then 'CREDIT' else 'DEBIT' end, 'pendiente', false))));
    select m.id into v_mov from movimientos_banco m where m.id_externo = 'ZZV17-' || c_ronda || '-' || r.k order by m.importado_el desc limit 1;
    perform fn_banco_casar(v_mov);
    k := k + 1;
  end loop;
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  raise notice 'CARGA % movimientos más', k;
end $$;
select 'PENDIENTES ' || count(*) from movimientos_banco where estado = 'pendiente';
SQL
carga() {  # carga <ronda> <veces>
  ed -v ON_ERROR_STOP=1 -v ronda="$1" -v veces="$2" -f "$TMP/volumen.sql" > "$TMP/volumen$1.out" 2>&1 \
    || { tail -n 12 "$TMP/volumen$1.out"; echo "FALLÓ la carga del volumen" >&2; exit 2; }
  ed -c "analyze" > /dev/null 2>&1
  PEND="$(sed -n 's/^PENDIENTES //p' "$TMP/volumen$1.out")"
  echo "     ($PEND pendientes en la Bandeja)"
}

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
# Como el dueño por la API: su rol, los ajustes de ese rol (jit = off) y el corte de 8 s.
APP="select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true) is null; select set_config('request.jwt.claim.sub', '$DUENO', true) is null; select count(set_config(k.k, k.v, true)) is null from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"

# pide <archivo de salida> <sql>: una transacción como el dueño por la API, que NO se confirma; deja las líneas «R …» y los avisos.
pide() { ed -c "begin; $APP" -c "$2" -c "rollback;" > "$1" 2>&1; }
dato() { sed -n "s/^.*R $2=\([^ ]*\).*$/\1/p" "$1" | head -n 1; }

# LEER POR PARTES, como la pantalla: una llamada tras otra con lo que «falta». Cada llamada se mide en la base (el bucle entero va
# sin corte: lo que se exige es que NINGUNA llamada pase de 0,8 s, la décima parte del corte de la API).
cat > "$TMP/leer.sql" <<'SQL'
do $$
declare
  c_ms constant int := current_setting('vol.ms')::int;
  l jsonb; v_ids jsonb; v_vistas jsonb := '{}'::jsonb; t0 timestamptz; v_ms int; v_peor int := 0; v_tot int := 0; v_k int := 0; v_dobles int := 0;
  v_todas int; v_prim int; v_pens int; v_grupos int; v_bytes int;
begin
  t0 := clock_timestamp();
  l := fn_bandeja_leer(jsonb_build_object('ms', c_ms));
  v_ms := (extract(epoch from clock_timestamp() - t0) * 1000)::int;
  v_peor := v_ms; v_tot := v_ms; v_k := 1;
  select count(*), count(*) filter (where not (t.value ? 'pensando')), count(*) filter (where t.value ? 'pensando') into v_todas, v_prim, v_pens
    from jsonb_each(l->'tarjetas') t;
  v_grupos := jsonb_array_length(l->'grupos');
  v_bytes := length(l::text);
  select coalesce(jsonb_object_agg(t.key, 1), '{}'::jsonb) into v_vistas from jsonb_each(l->'tarjetas') t where not (t.value ? 'pensando');
  v_ids := l->'faltan';
  while jsonb_array_length(v_ids) > 0 and v_k < 40 loop
    t0 := clock_timestamp();
    l := fn_bandeja_leer(jsonb_build_object('ids', v_ids, 'ms', c_ms));
    v_ms := (extract(epoch from clock_timestamp() - t0) * 1000)::int;
    v_k := v_k + 1; v_tot := v_tot + v_ms; v_peor := greatest(v_peor, v_ms);
    select v_dobles + count(*) into v_dobles from jsonb_each(l->'tarjetas') t where v_vistas ? t.key;
    select v_vistas || coalesce(jsonb_object_agg(t.key, 1), '{}'::jsonb) into v_vistas from jsonb_each(l->'tarjetas') t;
    v_ids := l->'faltan';
  end loop;
  raise notice 'R llamadas=% R peor=% R total=% R tarjetas=% R primera=% R pensando=% R recomendadas=% R dobles=% R faltan=% R grupos=% R bytes=%',
    v_k, v_peor, v_tot, v_todas, v_prim, v_pens, (select count(*) from jsonb_object_keys(v_vistas)), v_dobles, jsonb_array_length(v_ids), v_grupos, v_bytes;
end $$;
SQL

# DECIDIR EL GRUPO MÁS GRANDE y DESHACER su tanda, con su reloj de producción.
cat > "$TMP/grupo.sql" <<'SQL'
do $$
declare
  c_ms constant int := current_setting('vol.ms')::int;
  l jsonb; g jsonb; r jsonb; d jsonb; v_movs jsonb; v_tanda text; t0 timestamptz; v_ms int; v_peor int := 0; v_k int := 0; v_reg int := 0;
  v_peor2 int := 0; v_k2 int := 0; v_des int := 0; v_n int; v_qd int := 0;
begin
  l := fn_bandeja_leer('{"ms": 4000}');
  select y into g from jsonb_array_elements(l->'grupos') y where y->>'clase' = 'comercio' order by (y->>'n')::int desc limit 1;
  v_movs := g->'movimientos'; v_n := (g->>'n')::int;
  loop
    t0 := clock_timestamp();
    r := fn_bandeja_grupo(g->>'clave', 'personal', '{}', jsonb_strip_nulls(jsonb_build_object('recordar', false, 'ms', c_ms, 'movimientos', v_movs, 'tanda', v_tanda)));
    v_ms := (extract(epoch from clock_timestamp() - t0) * 1000)::int;
    v_k := v_k + 1; v_peor := greatest(v_peor, v_ms); v_reg := v_reg + (r->>'hechos')::int; v_tanda := r->>'tanda';
    v_qd := v_qd + jsonb_array_length(coalesce(r->'quedan', '[]'::jsonb));
    -- (como la pantalla: de lo que enseñó, quita lo ya contestado)
    select coalesce(jsonb_agg(e), '[]'::jsonb) into v_movs from jsonb_array_elements_text(v_movs) e
     where not exists (select 1 from jsonb_array_elements(coalesce(r->'registrados', '[]'::jsonb) || coalesce(r->'quedan', '[]'::jsonb)) x where x->>'movimiento_id' = e);
    exit when not coalesce((r->>'sigue')::boolean, false) or v_k >= 60;
  end loop;
  loop
    t0 := clock_timestamp();
    d := fn_bandeja_deshacer_tanda(v_tanda::uuid, 'c17-volumen: se deshace', jsonb_build_object('ms', c_ms));
    v_ms := (extract(epoch from clock_timestamp() - t0) * 1000)::int;
    v_k2 := v_k2 + 1; v_peor2 := greatest(v_peor2, v_ms); v_des := v_des + (d->>'deshechos')::int;
    exit when not coalesce((d->>'sigue')::boolean, false) or v_k2 >= 60;
  end loop;
  raise notice 'R grupo=% R n=% R llamadas=% R peor=% R registrados=% R quedan=% R contestados=% R tandas=% R llamadas2=% R peor2=% R deshechos=%',
    replace(g->>'clave', ' ', '_'), v_n, v_k, v_peor, v_reg, v_qd, v_reg + v_qd,
    (select count(distinct h.tanda) from bandeja_hechos h where h.tanda = v_tanda::uuid), v_k2, v_peor2, v_des;
end $$;
SQL

# LA RUTINA QUE REGISTRA SOLA: una regla «que entre solo» en el comercio de gasolina con más cargos.
# (Cuarta vuelta) «Que lo SIGUIENTE entre solo» es lo que el banco trae DESPUÉS de poner la regla: los demás cargos de ese
# comercio que ya esperaban en la Bandeja NO entran solos (se mide: 0); después llegan 25 cargos más de ese comercio, como los
# trae Plaid, y esos sí: la rutina se mide con ellos, con la Bandeja llena.
cat > "$TMP/solo.sql" <<'SQL'
do $$
declare
  c_ms constant int := current_setting('vol.ms')::int;
  l jsonb; g jsonb; r jsonb; s jsonb; t0 timestamptz; v_ms int; v_peor int := 0; v_k int := 0; v_reg int := 0; v_uno uuid;
  v_antes int; v_desc text; v_cta text; v_mov uuid; i int;
begin
  l := fn_bandeja_leer('{"ms": 4000}');
  select y into g from jsonb_array_elements(l->'grupos') y
   where y->>'clase' = 'comercio' and y->'rec'->>'accion' = 'gasto' and y->'rec'->'datos'->>'cuenta' = '6300' order by (y->>'n')::int desc limit 1;
  v_uno := (g->'movimientos'->>0)::uuid;
  r := fn_bandeja_hacer(v_uno, 'gasto', '{"cuenta": "6300"}', '{"recordar": true, "solo": true, "fuente": "mas"}');
  -- los que ya esperaban: ninguno entra solo
  s := fn_bandeja_solo(jsonb_build_object('ms', 4000));
  v_antes := jsonb_array_length(s->'registrados');
  -- y llegan 25 más de ese comercio
  select mb.descripcion, mb.cuenta into v_desc, v_cta from movimientos_banco mb where mb.id = v_uno;
  for i in 1 .. 25 loop
    perform fn_banco_importar_filas(jsonb_build_object(
      'origen', 'plaid', 'cuenta', v_cta, 'nombre', 'Plaid · c17-volumen · solo-' || i,
      'filas', jsonb_build_array(jsonb_build_object(
                 'id', 'ZZV17-SOLO-' || i, 'fecha', greatest(fn_fecha_miami(now()) - 1, date_trunc('month', fn_fecha_miami(now()))::date)::text,
                 'plaid_monto', (20 + i * 1.37)::numeric(14,2)::text, 'descripcion', v_desc, 'tipo', 'DEBIT', 'pendiente', false))));
    select m.id into v_mov from movimientos_banco m where m.id_externo = 'ZZV17-SOLO-' || i order by m.importado_el desc limit 1;
    perform fn_banco_casar(v_mov);
  end loop;
  loop
    t0 := clock_timestamp();
    s := fn_bandeja_solo(jsonb_build_object('ms', c_ms));
    v_ms := (extract(epoch from clock_timestamp() - t0) * 1000)::int;
    v_k := v_k + 1; v_peor := greatest(v_peor, v_ms); v_reg := v_reg + jsonb_array_length(s->'registrados');
    exit when coalesce((s->>'completo')::boolean, true) or v_k >= 60;
  end loop;
  raise notice 'R grupo=% R n=% R llamadas=% R peor=% R registrados=% R completo=% R antes=%', replace(g->>'clave', ' ', '_'), (g->>'n')::int, v_k, v_peor, v_reg,
               s->>'completo', v_antes;
end $$;
SQL

mide_todo() {  # mide_todo <cuántos, para decirlo> <llamadas de leer que se admiten>
  local f="$TMP/m$1"
  echo "== $1. Leer por partes, con el reloj de producción ($PROD_RELOJ_LEER ms; cada llamada, no más de $PROD_LLAMADA_MS ms)"
  pide "$f-leer.out" "set local vol.ms = '$PROD_RELOJ_LEER'; set local statement_timeout = 0; $(cat "$TMP/leer.sql")"
  if [ -z "$(dato "$f-leer.out" llamadas)" ]; then echo "FALLA: leer no terminó: $(grep -m1 -iE 'error|cancel' "$f-leer.out" | cut -c1-200)"; malos=1; else
    echo "     ($(dato "$f-leer.out" tarjetas) tarjetas y $(dato "$f-leer.out" grupos) grupos; la primera llamada recomienda $(dato "$f-leer.out" primera) y deja $(dato "$f-leer.out" pensando) «pensando»; $(dato "$f-leer.out" llamadas) llamadas, la peor de $(dato "$f-leer.out" peor) ms, $(dato "$f-leer.out" total) ms entre todas; $(dato "$f-leer.out" bytes) letras la primera respuesta)"
    [ "$(dato "$f-leer.out" peor)" -le "$PROD_LLAMADA_MS" ] && echo "ok   ninguna llamada de leer pasa de $PROD_LLAMADA_MS ms ($(dato "$f-leer.out" peor))" \
      || { echo "FALLA: una llamada de leer tardó $(dato "$f-leer.out" peor) ms (tope $PROD_LLAMADA_MS)"; malos=1; }
    [ "$(dato "$f-leer.out" llamadas)" -le "$2" ] && echo "ok   la Bandeja entera, en $2 llamadas o menos ($(dato "$f-leer.out" llamadas))" \
      || { echo "FALLA: la Bandeja entera pidió $(dato "$f-leer.out" llamadas) llamadas (se admiten $2)"; malos=1; }
    revisa "cada tarjeta se recomienda una vez: todas, ninguna dos veces, nada queda por pedir" \
      "$(dato "$f-leer.out" tarjetas) recomendadas, 0 dos veces, faltan 0" \
      "$(dato "$f-leer.out" recomendadas) recomendadas, $(dato "$f-leer.out" dobles) dos veces, faltan $(dato "$f-leer.out" faltan)"
  fi
  echo "== $1. Leer con el reloj de fábrica, como lo llama la pantalla (se informa; nunca más de 4 s en el banco)"
  local t0 t1 ms
  t0=$(date +%s%N)
  pide "$f-fabrica.out" "select 'R recomendadas=' || (select count(*) from jsonb_each(l->'tarjetas') t where not (t.value ? 'pensando')) || ' R faltan=' || jsonb_array_length(l->'faltan') from (select fn_bandeja_leer('{}') as l offset 0) x"
  t1=$(date +%s%N); ms=$(( (t1 - t0) / 1000000 ))
  echo "     ($ms ms: recomienda $(dato "$f-fabrica.out" recomendadas) y deja $(dato "$f-fabrica.out" faltan) para la llamada siguiente)"
  [ -n "$(dato "$f-fabrica.out" recomendadas)" ] && [ "$ms" -le 4000 ] && echo "ok   leer con el reloj de fábrica contesta ($ms ms)" \
    || { echo "FALLA: leer con el reloj de fábrica: $ms ms $(grep -m1 -iE 'error|cancel' "$f-fabrica.out" | cut -c1-160)"; malos=1; }

  echo "== $1. Decidir el grupo más grande y deshacer su tanda, con su reloj de producción ($PROD_RELOJ_HACER ms)"
  pide "$f-grupo.out" "set local vol.ms = '$PROD_RELOJ_HACER'; set local statement_timeout = 0; $(cat "$TMP/grupo.sql")"
  if [ -z "$(dato "$f-grupo.out" llamadas)" ]; then echo "FALLA: el grupo no terminó: $(grep -m1 -iE 'error|cancel' "$f-grupo.out" | cut -c1-200)"; malos=1; else
    echo "     ($(dato "$f-grupo.out" grupo | tr '_' ' '), $(dato "$f-grupo.out" n) cargos: $(dato "$f-grupo.out" llamadas) llamadas para decidirlo, la peor de $(dato "$f-grupo.out" peor) ms; $(dato "$f-grupo.out" llamadas2) para deshacerlo, la peor de $(dato "$f-grupo.out" peor2) ms)"
    revisa "el grupo entero queda contestado (registrado, o dicho por qué no) en una sola tanda, y lo registrado se deshace entero" \
      "$(dato "$f-grupo.out" n) contestados, 1 tanda, $(dato "$f-grupo.out" registrados) deshechos" \
      "$(dato "$f-grupo.out" contestados) contestados, $(dato "$f-grupo.out" tandas) tanda, $(dato "$f-grupo.out" deshechos) deshechos"
    [ "$(dato "$f-grupo.out" registrados)" -ge 20 ] && echo "ok   se registraron $(dato "$f-grupo.out" registrados) de $(dato "$f-grupo.out" n) (los demás: $(dato "$f-grupo.out" quedan), con su porqué)" \
      || { echo "FALLA: del grupo de $(dato "$f-grupo.out" n) solo se registraron $(dato "$f-grupo.out" registrados)"; malos=1; }
    [ "$(dato "$f-grupo.out" peor)" -le "$PROD_LLAMADA_MS" ] && [ "$(dato "$f-grupo.out" peor2)" -le "$PROD_LLAMADA_MS" ] \
      && echo "ok   ninguna llamada de decidir ni de deshacer pasa de $PROD_LLAMADA_MS ms ($(dato "$f-grupo.out" peor) y $(dato "$f-grupo.out" peor2))" \
      || { echo "FALLA: decidir o deshacer el grupo: una llamada de $(dato "$f-grupo.out" peor) / $(dato "$f-grupo.out" peor2) ms (tope $PROD_LLAMADA_MS)"; malos=1; }
  fi

  echo "== $1. La rutina que registra sola, con una regla en el comercio de gasolina con más cargos ($PROD_RELOJ_HACER ms)"
  pide "$f-solo.out" "set local vol.ms = '$PROD_RELOJ_HACER'; set local statement_timeout = 0; $(cat "$TMP/solo.sql")"
  if [ -z "$(dato "$f-solo.out" llamadas)" ]; then echo "FALLA: la rutina no terminó: $(grep -m1 -iE 'error|cancel' "$f-solo.out" | cut -c1-200)"; malos=1; else
    echo "     ($(dato "$f-solo.out" grupo | tr '_' ' '), $(dato "$f-solo.out" n) cargos que ya esperaban y 25 que llegan después: $(dato "$f-solo.out" llamadas) llamadas, la peor de $(dato "$f-solo.out" peor) ms; entraron solos $(dato "$f-solo.out" registrados))"
    revisa "los cargos de ese comercio que ya esperaban cuando se puso la regla NO entran solos" "0" "$(dato "$f-solo.out" antes)"
    revisa "la rutina termina («completo»)" "true" "$(dato "$f-solo.out" completo)"
    revisa "y registra los 25 que llegaron después" "25" "$(dato "$f-solo.out" registrados)"
    [ "$(dato "$f-solo.out" registrados)" -ge 1 ] && [ "$(dato "$f-solo.out" peor)" -le "$PROD_LLAMADA_MS" ] \
      && echo "ok   ninguna llamada de la rutina pasa de $PROD_LLAMADA_MS ms ($(dato "$f-solo.out" peor))" \
      || { echo "FALLA: la rutina: $(dato "$f-solo.out" registrados) registrados, una llamada de $(dato "$f-solo.out" peor) ms (tope $PROD_LLAMADA_MS)"; malos=1; }
  fi

  echo "== $1. El control de la capa"
  t0=$(date +%s%N)
  pide "$f-control.out" "select 'R rojos=' || count(*) filter (where not ok and nivel = 'cuadre') || ' R filas=' || count(*) from fn_bandeja_control()"
  t1=$(date +%s%N); ms=$(( (t1 - t0) / 1000000 ))
  revisa "ningún cuadre de la Bandeja en rojo" "0" "$(dato "$f-control.out" rojos)"
  [ "$ms" -le "$PROD_LLAMADA_MS" ] && echo "ok   el control contesta en $ms ms" || { echo "FALLA: el control tardó $ms ms (tope $PROD_LLAMADA_MS)"; malos=1; }
}

echo "== El volumen: la Bandeja de Edgar (unos 400 pendientes)"
carga 1 1
mide_todo "Con $PEND" 4

echo "== El volumen: más del doble (unos 1,000 pendientes)"
carga 2 1.7
mide_todo "Con $PEND" 10

echo "== c17-pruebas.sql entero sobre esa Bandeja"
t0=$(date +%s)
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" \
  -c '\o /dev/null' -f "$DOCS/c17-pruebas.sql" -c '\o' \
  -c "select 'R total=' || count(*) || ' R ok=' || count(*) filter (where ok) || ' R fallan=' || count(*) filter (where not ok) || ' R omitidas=' || count(*) filter (where ok is null) || ' R cuales=' || coalesce(string_agg(n::text, ',' order by n) filter (where ok is not true), '-') from _pruebas" \
  > "$TMP/pruebas.out" 2>&1 || { tail -n 8 "$TMP/pruebas.out"; echo "FALLA: c17-pruebas.sql no corrió entero"; malos=1; }
t1=$(date +%s)
echo "     ($(dato "$TMP/pruebas.out" total) pruebas en $((t1 - t0)) s: $(dato "$TMP/pruebas.out" ok) bien, $(dato "$TMP/pruebas.out" fallan) fallan, $(dato "$TMP/pruebas.out" omitidas) omitidas: $(dato "$TMP/pruebas.out" cuales))"
revisa "c17-pruebas.sql sobre la Bandeja llena: nada en rojo" "0" "$(dato "$TMP/pruebas.out" fallan)"

[ "$malos" = 0 ] && echo "TODO BIEN" || echo "ALGO FALLA"
exit "$malos"
