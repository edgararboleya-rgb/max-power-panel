#!/usr/bin/env bash
# =====================================================================
# c4-volumen.sh — lo que c4-pruebas.sql no puede medir porque pasa con
# MUCHOS asientos: los estados y el tablero leídos como los lee conta.js
# (authenticated, el dueño, con la policy del libro y el tope de la API:
# statement_timeout de 8 s) con un libro de verdad, y c4-pruebas corriendo
# sobre ese libro mientras la app se usa.
#
#   ./c4-volumen.sh [nombre_bd] [por_mes]     (por defecto c4_volumen 666)
#
# EL LIBRO se hace como lo hace la app, por los PUENTES (no a mano, dos
# líneas por asiento: así se ejercen los caminos caros de cada vista):
# una apertura por su balanza de QuickBooks (fn_apertura, con la CxP de un
# proveedor), y 15 meses (oct-2026 a dic-2027) de 30 obras de tres tipos
# con, cada mes y por cada «por_mes» (666 ≈ 10.000 asientos, un año largo
# de la empresa): facturas (algunas con retención) y sus cobros (parciales,
# con su partida); tickets de Home Depot con dos tarjetas (material,
# permisos, renta de equipo); recibos a cuenta de 40 proveedores y su pago
# con su partida; trabajos externos de 10 ayudantes y su pago; la nómina de
# cada semana (mano de obra por obra y cost code, y sueldo de oficina, con
# retenciones); statements de material repartidos entre obras; gastos del
# banco; y el pago de cada tarjeta. Con «hoy» fingido al 20-dic-2027 (el
# reloj del banco; sus huellas se vuelven a sellar para que c2 lo sepa).
#
# LO QUE MIDE, cada consulta como la app, con su tope:
#   · cada vista de las pantallas (Panel, estados, tablero), en el último
#     mes y en 'hoy', leída como la lee PostgREST (json_agg de «select *»,
#     con los ajustes del rol authenticated que PostgREST aplica en cada
#     consulta: el tope de 8 s y el jit = off que pone c4; el JIT del
#     servidor, encendido de fábrica): no más de 2 s cada una;
#   · fn_estados_control como la pide cada pantalla (el Panel, los
#     estados, 'hoy', el año, y todas las vistas juntas): no más de 8 s (el
#     tope de la API), y nada en rojo;
#   · el libro sano (fn_verificar_cadena);
#   · c4-pruebas.sql entero sobre ese libro MIENTRAS cuatro «teléfonos»
#     suben un ticket cada 0,25 s (el dueño, como la app: el puente en
#     immediate y rollback, sin rastro) y el Panel lee los bancos cada
#     segundo: ninguna subida ni lectura cortada por el tope de 8 s (ni
#     esperando 8 s o más), y c4-pruebas sin nada en rojo (las pruebas de
#     la apertura salen «omitidas»: el libro ya tiene la suya). Dos
#     veces: con 2026 abierto, y con sus meses ya cerrados (el estado de
#     2027: enero es el mes abierto más antiguo).
#   · c3-pruebas.sql entero sobre ese libro, con los mismos teléfonos: lo
#     mismo (y lo que tarda, para el README).
# Imprime la tabla de tiempos (la de la cabecera de c4-estados.sql).
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, para mirarla; se borra con
# ./correr.sh --borrar <nombre_bd>).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c4_volumen}"
K="${2:-666}"
[[ "$K" =~ ^[0-9]+$ ]] && [ "$K" -ge 20 ] || { echo "por_mes va en dígitos, 20 o más (llegó «$K»)." >&2; exit 64; }
TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'touch "$TMP/fin" 2>/dev/null; rm -rf "$TMP"; echo "(La base $BD queda creada: ./correr.sh --borrar $BD)"' EXIT
else
  trap 'touch "$TMP/fin" 2>/dev/null; "$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

echo "== Base $BD: c1 + c2 + c3 + c4"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" > "$TMP/carga.out" 2>&1 || { cat "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' order by creado limit 1")"
[ -n "$DUENO" ] || { echo "No hay dueño en la semilla" >&2; exit 2; }
# Como la app: el dueño, con el rol authenticated, los ajustes de ese rol
# en esta base (PostgREST los aplica en cada consulta: jit = off, de c4) y
# el tope de la API.
APP="select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\"}', true); select count(set_config(split_part(c, '=', 1), substr(c, strpos(c, '=') + 1), true)) from pg_db_role_setting s, unnest(s.setconfig) c where s.setrole = 'authenticated'::regrole and s.setdatabase in (0, (select d.oid from pg_database d where d.datname = current_database())); set local role authenticated; set local statement_timeout = '8s';"

echo "== El libro: la apertura por su balanza y 15 meses por los puentes ($K por mes)"
t0=$(date +%s.%N)
ed -v ON_ERROR_STOP=1 -v k="$K" -v dueno="$DUENO" > "$TMP/libro.out" 2>&1 <<'SQL' || { tail -n 20 "$TMP/libro.out"; echo "FALLÓ el libro" >&2; exit 2; }
-- «Hoy» en el banco: el 20-dic-2027 (el libro llega hasta ahí).
create or replace function public.fn_fecha_miami(t timestamptz) returns date language sql stable
set search_path = public, pg_temp as $$ select greatest((t at time zone 'America/New_York')::date, date '2027-12-20') $$;
select set_config('vol.k', :'k', false), set_config('vol.dueno', :'dueno', false);
insert into proyectos (id, tipo, nombre, cliente, estado)
select 'vol-obra-' || lpad(g::text, 2, '0'), (array['residencial', 'comercial', 'servicio'])[1 + g % 3], 'Obra ' || g, 'Cliente ' || g,
       'ejecucion'
  from generate_series(1, 30) g
on conflict (id) do nothing;
do $$
declare
  g int;
  e bigint;
begin
  perform fn_mapeo_categoria('material', '5100');
  perform fn_mapeo_categoria('permiso', '5400');
  perform fn_mapeo_categoria('renta_equipo', '5300');
  perform fn_mapeo_metodo_pago('credito', 'tarjeta');
  perform fn_mapeo_metodo_pago('cuenta_proveedor', 'cuenta_proveedor');
  perform fn_mapeo_tipo_proyecto('residencial', '4010');
  perform fn_mapeo_tipo_proyecto('comercial', '4020');
  perform fn_mapeo_tipo_proyecto('servicio', '4030');
  perform fn_tarjeta_alta('2009', '2100-2009', 'Amex Blue');
  perform fn_tarjeta_alta('2013', '2100-2013', 'Amex Gold');
  for g in 1..40 loop
    perform fn_proveedor_alta('VOL SUPPLY ' || g, 'Net 30', array['vol supply ' || g || ' inc']);
  end loop;
  for g in 1..10 loop
    insert into externos_equipo (nombre, costo_hora, activo) values ('vol ayudante ' || g, 20, true) returning id into e;
    perform fn_proveedor_alta('VOL AYUDANTE ' || g, 'Net 15', '{}', e);
  end loop;
  perform fn_apertura_balanza_cargar('docs/apertura/vol.csv', jsonb_build_array(
    jsonb_build_object('cuenta_qb', 'Chase Chk 4392', 'debe', '500000.00'),
    jsonb_build_object('cuenta_qb', 'Vehicles', 'debe', '80000.00'),
    jsonb_build_object('cuenta_qb', 'Accumulated Depreciation', 'haber', '20000.00'),
    jsonb_build_object('cuenta_qb', 'Accounts Payable', 'haber', '30000.00', 'proveedor_qb', 'Vol Supply 1 Inc'),
    jsonb_build_object('cuenta_qb', 'Common Stock', 'haber', '1000.00'),
    jsonb_build_object('cuenta_qb', 'Opening Balance Equity', 'haber', '149000.00'),
    jsonb_build_object('cuenta_qb', 'Construction Income', 'haber', '900000.00'),
    jsonb_build_object('cuenta_qb', 'Job Materials', 'debe', '400000.00'),
    jsonb_build_object('cuenta_qb', 'Rent Expense', 'debe', '120000.00'),
    -- su control de QuickBooks (el Balance Sheet al 30-sep)
    jsonb_build_object('cuenta_qb', 'Net Income', 'haber', '380000.00'),
    jsonb_build_object('cuenta_qb', 'TOTAL ASSETS', 'debe', '560000.00')));
  perform fn_apertura_mapeo_qb(x.n, x.c)
     from (values ('Chase Chk 4392', '1010'), ('Vehicles', '1510'), ('Accumulated Depreciation', '1590'), ('Accounts Payable', '2010'),
                  ('Common Stock', '3000'), ('Opening Balance Equity', '3900'), ('Construction Income', '4010'),
                  ('Job Materials', '5100'), ('Rent Expense', '6100')) x(n, c);
  perform fn_apertura((select p.desde from periodos p where p.tipo = 'apertura' order by p.desde limit 1), 'docs/apertura/vol.csv');
end $$;
do $$
declare
  k     int := current_setting('vol.k')::int;
  dueno uuid := current_setting('vol.dueno')::uuid;
  d0 date; d1 date; dias int; tag text; r record; i int; j int; f date; lin jsonb; tot numeric; m numeric;
  obras text[] := (select array_agg(id order by id) from proyectos where id like 'vol-obra-%');
  exts  bigint[] := (select array_agg(id order by id) from externos_equipo where nombre like 'vol ayudante %');
  ccs   text[] := (select array_agg(codigo order by codigo) from codigos_partida);
begin
  execute 'set constraints trg_puente_recibos_despues, trg_puente_externos_despues, trg_puente_facturas_despues immediate';
  for d0 in select generate_series(date '2026-10-01', date '2027-12-01', interval '1 month')::date loop
    d1 := least((d0 + interval '1 month')::date - 1, date '2027-12-20'); dias := d1 - d0 + 1; tag := to_char(d0, 'YYMM');
    -- Facturas (las de las obras comerciales, con retención).
    insert into facturas (proyecto_id, num, fecha, monto, retencion)
    select obras[1 + (g * 7) % 30], 'V' || tag || '-' || g, d0 + (g % dias), round((2000 + (g * 137 % 18000))::numeric, 2),
           case when (1 + (g * 7) % 30) % 3 = 2 then round((2000 + (g * 137 % 18000))::numeric * 0.10, 2) else 0 end
      from generate_series(1, round(k * 0.12)::int) g;
    -- Tickets con tarjeta (Home Depot) y recibos a cuenta de un proveedor.
    insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago, ultimos4, num_recibo)
    select obras[1 + (g * 11) % 30], 'recibos/vol/' || tag || '/t' || g || '.jpg',
           round((20 + (g * 37 % 900) + (g % 100) / 100.0)::numeric, 2), 'Home Depot', 'leido', dueno,
           ((d0 + (g % dias)) + time '12:00') at time zone 'America/New_York', d0 + (g % dias),
           (array['material', 'material', 'material', 'permiso', 'renta_equipo'])[1 + g % 5], 'credito',
           case when g % 2 = 0 then '2009' else '2013' end, 'VT' || tag || '-' || g
      from generate_series(1, round(k * 0.25)::int) g;
    insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago, ultimos4, num_recibo)
    select obras[1 + (g * 13) % 30], 'recibos/vol/' || tag || '/c' || g || '.jpg',
           round((100 + (g * 53 % 3000) + (g % 100) / 100.0)::numeric, 2), 'Vol Supply ' || (1 + g % 40) || ' Inc', 'leido', dueno,
           ((d0 + (g % dias)) + time '12:00') at time zone 'America/New_York', d0 + (g % dias), 'material', 'cuenta_proveedor', null,
           'VC' || tag || '-' || g
      from generate_series(1, round(k * 0.15)::int) g;
    -- Trabajos externos de los ayudantes.
    insert into trabajos_externos (proyecto_id, descripcion, fecha, tipo, horas, costo, externo_id, creado)
    select obras[1 + (g * 17) % 30], 'vol ayudante ' || tag || '-' || g, d0 + (g % dias), 'horas', 40,
           round((800 + (g * 13 % 800))::numeric, 2), exts[1 + g % 10],
           ((d0 + (g % dias)) + time '12:00') at time zone 'America/New_York'
      from generate_series(1, round(k * 0.06)::int) g;
    -- Los cobros de las facturas del mes anterior (uno de cada cinco, a la mitad).
    for r in select fa.id, fa.monto, coalesce(fa.retencion, 0) as ret, fa.fecha from facturas fa
              where fa.num like 'V%' and fa.fecha >= (d0 - interval '1 month')::date and fa.fecha < d0 order by fa.id loop
      m := case when r.id % 5 = 0 then round((r.monto - r.ret) / 2, 2) else r.monto - r.ret end;
      perform fn_cobro_registrar(jsonb_build_object('fecha', least(r.fecha + 25, d1)::text, 'monto', m::text, 'medio', 'cheque',
        'referencia', 'VCB-' || r.id, 'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', r.id, 'monto', m::text))));
    end loop;
    -- El pago de los recibos a cuenta y de los ayudantes del mes anterior, con su partida.
    for r in select rc.id, rc.total, rc.fecha, pa.proveedor_id from recibos rc
               join proveedores_alias pa on pa.alias = lower(btrim(rc.proveedor))
              where rc.metodo_pago = 'cuenta_proveedor' and rc.fecha >= (d0 - interval '1 month')::date and rc.fecha < d0
              order by rc.id loop
      perform fn_postear(jsonb_build_object('fecha', least(r.fecha + 30, d1)::text, 'descripcion', 'vol: pago a proveedor ' || r.id,
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2010', 'monto', r.total::text, 'tercero_tipo', 'proveedor',
                                                       'tercero_id', r.proveedor_id::text, 'partida_tabla', 'recibos',
                                                       'partida_id', r.id::text),
                                    jsonb_build_object('cuenta', '1010', 'monto', (-r.total)::text))));
    end loop;
    for r in select te.id, te.costo, te.fecha, p.id as proveedor_id from trabajos_externos te
               join proveedores p on p.externo_id = te.externo_id
              where te.descripcion like 'vol ayudante %' and te.fecha >= (d0 - interval '1 month')::date and te.fecha < d0
              order by te.id loop
      perform fn_postear(jsonb_build_object('fecha', least(r.fecha + 15, d1)::text, 'descripcion', 'vol: pago a ayudante ' || r.id,
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2010', 'monto', round(r.costo, 2)::text, 'tercero_tipo', 'proveedor',
                                                       'tercero_id', r.proveedor_id::text, 'partida_tabla', 'trabajos_externos',
                                                       'partida_id', r.id::text),
                                    jsonb_build_object('cuenta', '1010', 'monto', (-round(r.costo, 2))::text))));
    end loop;
    -- La nómina de cada semana: mano de obra por obra y cost code, sueldo de oficina, retenciones.
    for i in 0..3 loop
      f := least(d0 + 6 + i * 7, d1); lin := '[]'::jsonb; tot := 0;
      for j in 1..12 loop
        m := round((300 + (i * 97 + j * 131) % 900)::numeric, 2); tot := tot + m;
        lin := lin || jsonb_build_object('cuenta', case when j % 4 = 0 then '5010' else '5000' end, 'monto', m::text,
                                         'proyecto_id', obras[1 + (i * 12 + j + extract(month from d0)::int) % 30],
                                         'cost_code', ccs[1 + (i * 5 + j) % array_length(ccs, 1)]);
      end loop;
      lin := lin || jsonb_build_object('cuenta', '6000', 'monto', '1500.00'); tot := tot + 1500;
      lin := lin || jsonb_build_object('cuenta', '2210', 'monto', (-round(tot * 0.2, 2))::text)
                 || jsonb_build_object('cuenta', '1010', 'monto', (-(tot - round(tot * 0.2, 2)))::text);
      perform fn_postear(jsonb_build_object('fecha', f::text, 'descripcion', 'vol: nómina semana ' || i, 'lineas', lin));
    end loop;
    -- Statements de material repartidos entre obras.
    for i in 1..round(k * 0.045)::int loop
      lin := '[]'::jsonb; tot := 0;
      for j in 1..4 loop
        m := round((50 + (i * 71 + j * 29) % 700)::numeric, 2); tot := tot + m;
        lin := lin || jsonb_build_object('cuenta', '5100', 'monto', m::text, 'proyecto_id', obras[1 + (i + j * 7) % 30],
                                         'cost_code', ccs[1 + (i * 3 + j) % array_length(ccs, 1)]);
      end loop;
      lin := lin || jsonb_build_object('cuenta', '2010', 'monto', (-tot)::text, 'tercero_tipo', 'proveedor',
                                       'tercero_id', (select id::text from proveedores where nombre = 'VOL SUPPLY ' || (1 + i % 40)));
      perform fn_postear(jsonb_build_object('fecha', (d0 + (i % dias))::text, 'descripcion', 'vol: statement repartido ' || i,
                                            'lineas', lin));
    end loop;
    -- Gastos del banco.
    for i in 1..round(k * 0.09)::int loop
      m := round((20 + (i * 43 % 600) + (i % 100) / 100.0)::numeric, 2);
      perform fn_postear(jsonb_build_object('fecha', (d0 + (i % dias))::text, 'descripcion', 'vol: gasto ' || i,
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', (array['6100', '6130', '6300', '6500', '6600', '6200'])[1 + i % 6],
                                                       'monto', m::text),
                                    jsonb_build_object('cuenta', '1010', 'monto', (-m)::text))));
    end loop;
    -- El pago de cada tarjeta (lo cargado hasta el mes anterior).
    for r in select x.c from (values ('2100-2009'), ('2100-2013')) x(c) loop
      m := (select coalesce(-sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
             where l.cuenta = r.c and a.fecha_contable < d0);
      if m > 0 then
        perform fn_postear(jsonb_build_object('fecha', least(d0 + 20, d1)::text, 'descripcion', 'vol: pago tarjeta ' || r.c,
          'lineas', jsonb_build_array(jsonb_build_object('cuenta', r.c, 'monto', m::text),
                                      jsonb_build_object('cuenta', '1010', 'monto', (-m)::text))));
      end if;
    end loop;
  end loop;
end $$;
-- El reloj fingido cambió fn_fecha_miami: se vuelven a sellar las huellas
-- de c2 (en producción nadie la cambia).
select fn_libro_huellas_sellar('c4-volumen.sh: el reloj del banco en 2027-12-20') is not null;
analyze;
SQL
t1=$(date +%s.%N)
echo "     ($(python3 -c "print(round($t1 - $t0, 1))") s)"
echo "     asientos=$(ed -c "select count(*) from asientos") líneas=$(ed -c "select count(*) from asiento_lineas") papeles_sin_contabilizar=$(ed -c "select count(*) from puente_documentos where estado <> 'contabilizado' and estado <> 'no_aplica'")"

P="$(ed -c "select periodo from periodos where tipo = 'mes' and desde <= fn_fecha_miami(now()) order by desde desc limit 1")"
A="$(ed -c "select periodo from periodos where tipo = 'anio' and anio = extract(year from fn_fecha_miami(now()))::int")"
[ -n "$P" ] && [ -n "$A" ] || { echo "No encontré el último mes o su año en el calendario" >&2; exit 2; }

# mide <nombre> <tope_ms> <sql>: como la app, con el tope de la API (8 s).
mide() {
  local t0 t1 ms r
  t0=$(date +%s%N)
  r="$(ed -c "begin; $APP $3; rollback;" 2>&1 | tail -n 1)"
  t1=$(date +%s%N)
  ms=$(( (t1 - t0) / 1000000 ))
  if grep -qiE 'error|cancel' <<< "$r"; then
    printf '  %-44s NO TERMINÓ: %s\n' "$1" "$(cut -c1-120 <<< "$r")"; malos=1
  elif [ "$ms" -gt "$2" ]; then
    printf '  %-44s %6d ms  (tope %d ms: FALLA)  %s\n' "$1" "$ms" "$2" "$r"; malos=1
  else
    printf '  %-44s %6d ms  %s\n' "$1" "$ms" "$r"
  fi
}

echo "== Cada vista como la lee la app por PostgREST (json_agg de select *, dueño, ajustes del rol, 8 s), en $P y en 'hoy' (tope 2 s)"
# vista <nombre> <filtro>: como PostgREST, todas las columnas en JSON.
vista() { mide "$1" 2000 "select coalesce(json_array_length(json_agg(t)), 0) || ' filas' from (select * from $2) t"; }
for v in v_balanza v_balanza_obra v_balance_general v_resultados v_flujo_caja v_gasto_por_categoria v_gasto_por_proveedor \
         v_costo_por_obra v_comparacion v_comparacion_obra; do
  vista "$v ($P)" "$v where periodo = '$P'"
done
for v in v_balance_general v_saldos_dinero v_cxc_antiguedad v_cxp_antiguedad v_obras_dinero; do
  vista "$v (hoy)" "$v where periodo = 'hoy'"
done
vista "v_flujo_real_por_mes (todos los meses)" "v_flujo_real_por_mes"
vista "v_comparacion_resumen" "v_comparacion_resumen"
vista "v_libro ($P)" "v_libro where periodo = '$P'"
vista "v_mayor (1010, $P)" "v_mayor where cuenta = '1010' and periodo = '$P'"
vista "v_asiento_papel ($P)" "v_asiento_papel where periodo = '$P'"

echo "== fn_estados_control como la pide cada pantalla (tope 8 s, nada en rojo)"
ctl() {  # ctl <nombre> <periodo> <vistas o null>
  mide "$1" 8000 "select count(*) || ' filas, en rojo: ' || coalesce(string_agg(vista || coalesce(' (' || left(detalle, 80) || ')', ''), '; ') filter (where not ok), 'ninguna') from fn_estados_control('$2', $3)"
}
ctl "el Panel ($P, 9 vistas)" "$P" "array['v_saldos_dinero', 'v_flujo_real_por_mes', 'v_cxc_antiguedad', 'v_cxp_antiguedad', 'v_resultados', 'v_comparacion_resumen', 'v_gasto_por_categoria', 'v_gasto_por_proveedor', 'v_obras_dinero']"
ctl "el Panel a hoy" "hoy" "null"
ctl "los estados ($P, 4 vistas)" "$P" "array['v_balanza', 'v_balance_general', 'v_resultados', 'v_flujo_caja']"
ctl "el año ($A, estados)" "$A" "array['v_balanza', 'v_balance_general', 'v_resultados', 'v_flujo_caja']"
ctl "todas las vistas ($P)" "$P" "null"
for x in "$P|null" "hoy|null" "$A|array['v_balanza', 'v_balance_general', 'v_resultados', 'v_flujo_caja']"; do
  revisa "fn_estados_control(${x%%|*}): nada en rojo" "ninguna" \
    "$(ed -c "begin; $APP select coalesce(string_agg(vista, ', ') filter (where not ok), 'ninguna') from fn_estados_control('${x%%|*}', ${x#*|}); rollback;" 2>&1 | tail -n 1)"
done
revisa "el libro sigue sano (fn_verificar_cadena)" "ninguno" "$(ed -c "select coalesce(string_agg(control, ', '), 'ninguno') from fn_verificar_cadena() where not ok")"

cat > "$TMP/resumen.sql" <<'SQL'
\o
\pset footer off
\pset null '-'
select n, case ok when true then 'ok' when false then 'FALLA' else 'omitida' end as resultado, prueba, esperado, obtenido
  from _pruebas where ok is distinct from true order by n;
\pset tuples_only on
\pset format unaligned
select format('PRUEBAS total=%s ok=%s fallan=%s omitidas=%s', count(*), count(*) filter (where ok),
              count(*) filter (where not ok), count(*) filter (where ok is null)) from _pruebas;
SQL

# con_telefonos <archivo> <etiqueta>: corre el archivo de pruebas entero
# (una transacción, como el SQL Editor) MIENTRAS cuatro teléfonos suben un
# ticket cada 0,25 s y el Panel lee los bancos cada segundo. Cada subida,
# como la app (el dueño, el puente en immediate, el tope de 8 s) y con
# rollback: no deja rastro.
con_telefonos() {
  local f="$1" et="$2" rc t0 t1 pids="" tel
  rm -f "$TMP/fin"; : > "$TMP/telefono.log"; : > "$TMP/panel.log"
  for tel in 1 2 3 4; do
    (
      i=0
      while [ ! -f "$TMP/fin" ]; do
        i=$((i + 1)); t0=$(date +%s.%N); n=$((9000000 + tel * 100000 + i))
        r="$(ed -c "begin; $APP set constraints trg_puente_recibos_despues immediate;
              insert into recibos (id, proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago,
                                   ultimos4, num_recibo) overriding system value
              values (-$n, 'vol-obra-01', 'recibos/telefono/$n.jpg', 12.34, 'Home Depot', 'leido', '$DUENO',
                      (fn_fecha_miami(now()) + time '12:00') at time zone 'America/New_York', fn_fecha_miami(now()), 'material',
                      'credito', '2009', 'TEL-$n');
              select count(*) from asientos where origen_tabla = 'recibos' and origen_id = '-$n'; rollback;" 2>&1 \
             | grep -v '^{"sub' | tr '\n' ' ')"
        t1=$(date +%s.%N)
        echo "$(python3 -c "print(round($t1 - $t0, 2))") s teléfono $tel subida $i → $r" >> "$TMP/telefono.log"
        sleep 0.25
      done
    ) &
    pids="$pids $!"
  done
  (
    i=0
    while [ ! -f "$TMP/fin" ]; do
      i=$((i + 1)); t0=$(date +%s.%N)
      r="$(ed -c "begin; $APP select count(*) from v_saldos_dinero where periodo = 'hoy'; rollback;" 2>&1 | grep -v '^{"sub' | tr '\n' ' ')"
      t1=$(date +%s.%N)
      echo "$(python3 -c "print(round($t1 - $t0, 2))") s lectura $i → $r" >> "$TMP/panel.log"
      sleep 1
    done
  ) &
  pids="$pids $!"
  t0=$(date +%s.%N)
  ed -1 -v ON_ERROR_STOP=1 -c '\o /dev/null' -f "$f" -f "$TMP/resumen.sql" > "$TMP/pruebas.out" 2>&1; rc=$?
  t1=$(date +%s.%N)
  touch "$TMP/fin"; wait $pids
  echo "     $et: $(python3 -c "print(round($t1 - $t0, 1))") s · $(grep '^PRUEBAS' "$TMP/pruebas.out")"
  echo "     los teléfonos: $(wc -l < "$TMP/telefono.log") subidas, la más lenta $(sort -rn "$TMP/telefono.log" | head -n 1 | cut -d' ' -f1) s;" \
       "el Panel: $(wc -l < "$TMP/panel.log") lecturas, la más lenta $(sort -rn "$TMP/panel.log" | head -n 1 | cut -d' ' -f1) s"
  revisa "$et corrió entero" "0" "$rc"
  revisa "$et: nada en rojo" "0" "$(grep -o 'fallan=[0-9]*' "$TMP/pruebas.out" | cut -d= -f2)"
  grep -E '^ +[0-9]+ \| FALLA' "$TMP/pruebas.out" | cut -c1-300
  revisa "$et: ninguna subida cortada por el tope de 8 s" "0" "$(grep -ciE 'error|cancel' "$TMP/telefono.log")"
  revisa "$et: ninguna subida esperó 8 s o más" "0" "$(awk '$1 >= 8' "$TMP/telefono.log" | wc -l)"
  revisa "$et: ninguna lectura del Panel cortada" "0" "$(grep -ciE 'error|cancel' "$TMP/panel.log")"
  grep -iE 'error|cancel' "$TMP/telefono.log" "$TMP/panel.log" | head -n 3 | cut -c1-250
}

echo "== c4-pruebas sobre este libro mientras la app se usa (cuatro teléfonos, un ticket cada 0,25 s cada uno; el Panel cada segundo)"
con_telefonos "$DOCS/c4-pruebas.sql" "c4-pruebas (2026 abierto)"
echo "== c3-pruebas sobre este libro, igual"
con_telefonos "$DOCS/c3-pruebas.sql" "c3-pruebas"
echo "== Con los meses de 2026 ya cerrados (el estado de 2027: enero es el mes abierto más antiguo)"
ed -v ON_ERROR_STOP=1 -c "select count(fn_cerrar_periodo(p)) from unnest(array['2026-09-APERTURA', '2026-10', '2026-11', '2026-12']) p" \
  > "$TMP/cierre.out" 2>&1 || { cat "$TMP/cierre.out"; echo "FALLÓ el cierre de 2026" >&2; malos=1; }
con_telefonos "$DOCS/c4-pruebas.sql" "c4-pruebas (2026 cerrado)"
revisa "fn_estados_control(hoy) con 2026 cerrado: nada en rojo" "ninguna" \
  "$(ed -c "begin; $APP select coalesce(string_agg(vista, ', ') filter (where not ok), 'ninguna') from fn_estados_control('hoy', null); rollback;" 2>&1 | tail -n 1)"

[ $malos -eq 0 ] && echo "VOLUMEN c4 ok" || echo "VOLUMEN c4 FALLA"
exit $malos
