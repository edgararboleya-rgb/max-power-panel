#!/usr/bin/env bash
# =====================================================================
# c4-volumen.sh — lo que c4-pruebas.sql no puede medir porque pasa con
# MUCHOS asientos: los estados y el tablero leídos como los lee conta.js
# (authenticated, el dueño, con la policy del libro y el tope de la API:
# statement_timeout de 8 s) con un libro de N asientos (3.000 por defecto;
# 10.000 para ver el techo).
#
#   ./c4-volumen.sh [nombre_bd] [asientos]     (por defecto c4_volumen 3000)
#
# Crea su base con c1 + c2 + c3 + c4, mete una apertura y N asientos a mano
# entre el 1-oct y el 30-nov de 2026 (ventas y cobros por obra, material a
# cuenta de un proveedor y su pago, subcontratos con tarjeta, gastos del
# banco: dos líneas cada uno), y para el período 2026-11:
#   · cada vista del tablero y de los estados: el tiempo de ejecución
#     (EXPLAIN ANALYZE) y sus filas, como la app, sin pasar de 8 s;
#   · fn_estados_control con las vistas de una pantalla (la de estados:
#     balanza, balance, resultados y flujo) y con todas;
#   · los cuadres en verde (balanza en cero, activo = pasivo + capital,
#     directo = indirecto, antigüedad = mayor, auxiliar = mayor).
# Imprime la tabla de tiempos (la de la cabecera de c4-estados.sql).
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c4_volumen}"
N="${2:-3000}"
[[ "$N" =~ ^[0-9]+$ ]] || { echo "El número de asientos va en dígitos (llegó «$N»)." >&2; exit 64; }
TMP="$(mktemp -d)"
chmod 755 "$TMP"
trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

echo "== Base $BD: c1 + c2 + c3 + c4"
"$DIR/correr.sh" "$BD" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" "$DOCS/c4-estados.sql" \
  > "$TMP/carga.out" 2>&1 || { cat "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' order by creado limit 1")"
[ -n "$DUENO" ] || { echo "No hay dueño en la semilla" >&2; exit 2; }
# Como la app: el dueño, con el rol authenticated y el tope de la API.
APP="select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\"}', true); set local role authenticated; set local statement_timeout = '8s';"

echo "== Una apertura y $N asientos (en tandas de 1.000, cada una su transacción)"
t0=$(date +%s.%N)
ed -v ON_ERROR_STOP=1 > "$TMP/apertura.out" 2>&1 <<'SQL' || { cat "$TMP/apertura.out"; echo "FALLÓ la apertura" >&2; exit 2; }
do $$
declare
  v_prov uuid := fn_proveedor_alta('VOLUMEN SUPPLY', 'Net 30', array['volumen supply inc']);
begin
  perform fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', '2026-09-30', 'descripcion', 'c4-volumen: apertura',
    'lineas', jsonb_build_array(
      jsonb_build_object('cuenta', '1010', 'monto', '500000.00'),
      jsonb_build_object('cuenta', '1510', 'monto', '80000.00'),
      jsonb_build_object('cuenta', '1590', 'monto', '-20000.00'),
      jsonb_build_object('cuenta', '2010', 'monto', '-30000.00', 'tercero_tipo', 'proveedor', 'tercero_id', v_prov::text),
      jsonb_build_object('cuenta', '3000', 'monto', '-1000.00'),
      jsonb_build_object('cuenta', '3900', 'monto', '-529000.00'))));
end $$;
SQL
desde=1
while [ "$desde" -le "$N" ]; do
  hasta=$(( desde + 999 )); [ "$hasta" -gt "$N" ] && hasta=$N
  ed -v ON_ERROR_STOP=1 > "$TMP/meter.out" 2>&1 <<SQL || { cat "$TMP/meter.out"; echo "FALLÓ meter los asientos" >&2; exit 2; }
do \$\$
declare
  obras text[] := array['casa-perez-k3m9', 'oficina-nch-7xq2', 'taller-ruiz-5b2n'];
  cc    text[] := array['01-DEMO', '02-TEMP', '03-UG', '04-SERV', '05-PANEL'];
  v_prov text := (select id::text from proveedores where nombre = 'VOLUMEN SUPPLY');
  i int; f date; m numeric; o text;
begin
  for i in $desde..$hasta loop
    f := date '2026-10-01' + (i % 61);
    m := round((50 + (i * 37 % 4000) + (i % 100) / 100.0)::numeric, 2);
    o := obras[1 + i % 3];
    case i % 6
      when 0 then perform fn_postear(jsonb_build_object('fecha', f::text, 'descripcion', 'c4-volumen: venta ' || i,
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1110', 'monto', (m * 3)::text, 'proyecto_id', o),
                                    jsonb_build_object('cuenta', case o when 'oficina-nch-7xq2' then '4020'
                                                                        when 'taller-ruiz-5b2n' then '4030' else '4010' end,
                                                       'monto', (-m * 3)::text, 'proyecto_id', o))));
      when 1 then perform fn_postear(jsonb_build_object('fecha', f::text, 'descripcion', 'c4-volumen: cobro ' || i,
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1010', 'monto', (m * 2)::text),
                                    jsonb_build_object('cuenta', '1110', 'monto', (-m * 2)::text, 'proyecto_id', o))));
      when 2 then perform fn_postear(jsonb_build_object('fecha', f::text, 'descripcion', 'c4-volumen: material ' || i,
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5100', 'monto', m::text, 'proyecto_id', o, 'cost_code', cc[1 + i % 5]),
                                    jsonb_build_object('cuenta', '2010', 'monto', (-m)::text, 'tercero_tipo', 'proveedor',
                                                       'tercero_id', v_prov))));
      when 3 then perform fn_postear(jsonb_build_object('fecha', f::text, 'descripcion', 'c4-volumen: pago ' || i,
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2010', 'monto', m::text, 'tercero_tipo', 'proveedor', 'tercero_id', v_prov),
                                    jsonb_build_object('cuenta', '1010', 'monto', (-m)::text))));
      when 4 then perform fn_postear(jsonb_build_object('fecha', f::text, 'descripcion', 'c4-volumen: subcontrato ' || i,
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5200', 'monto', m::text, 'proyecto_id', o, 'cost_code', cc[1 + i % 5]),
                                    jsonb_build_object('cuenta', '2100-2009', 'monto', (-m)::text))));
      else perform fn_postear(jsonb_build_object('fecha', f::text, 'descripcion', 'c4-volumen: gasto ' || i,
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', case i % 4 when 0 then '6100' when 1 then '6300' when 2 then '6500'
                                                                        else '6130' end,
                                                       'monto', (m / 10)::numeric(14,2)::text),
                                    jsonb_build_object('cuenta', '1010', 'monto', (-(m / 10)::numeric(14,2))::text))));
    end case;
  end loop;
end \$\$;
SQL
  desde=$(( hasta + 1 ))
done
ed -c "analyze" > /dev/null 2>&1
t1=$(date +%s.%N)
echo "     ($(python3 -c "print(int(($t1 - $t0) * 1000))") ms)"
revisa "asientos en el libro" "$(( N + 1 ))" "$(ed -c "select count(*) from asientos")"

echo "== Cada vista, período 2026-11, como la app (authenticated, 8 s): tiempo de ejecución y filas"
P="2026-11"
for q in \
  "v_balanza|select * from v_balanza where periodo = '$P'" \
  "v_balanza_obra|select * from v_balanza_obra where periodo = '$P'" \
  "v_balance_general|select * from v_balance_general where periodo = '$P'" \
  "v_resultados|select * from v_resultados where periodo = '$P'" \
  "v_flujo_caja|select * from v_flujo_caja where periodo = '$P'" \
  "v_flujo_real_por_mes|select * from v_flujo_real_por_mes where periodo = '$P'" \
  "v_saldos_dinero|select * from v_saldos_dinero where periodo = '$P'" \
  "v_cxc_antiguedad|select * from v_cxc_antiguedad where periodo = '$P'" \
  "v_cxp_antiguedad|select * from v_cxp_antiguedad where periodo = '$P'" \
  "v_gasto_por_categoria|select * from v_gasto_por_categoria where periodo = '$P'" \
  "v_gasto_por_proveedor|select * from v_gasto_por_proveedor where periodo = '$P'" \
  "v_costo_por_obra|select * from v_costo_por_obra where periodo = '$P'" \
  "v_obras_dinero|select * from v_obras_dinero where periodo = '$P'" \
  "v_libro (el mes)|select * from v_libro where periodo = '$P'" \
  "v_mayor (1010, el mes)|select * from v_mayor where cuenta = '1010' and periodo = '$P'" \
  "v_asiento_papel (el mes)|select * from v_asiento_papel where periodo = '$P'" \
  "fn_estados_control (pantalla de estados)|select * from fn_estados_control('$P', array['v_balanza', 'v_balance_general', 'v_resultados', 'v_flujo_caja'])" \
  "fn_estados_control (todas)|select * from fn_estados_control('$P')" ; do
  nombre="${q%%|*}"; sql="${q#*|}"
  r="$(ed -c "begin; $APP explain (analyze, format json) $sql; rollback;" 2>&1)"
  t="$(grep -o '"Execution Time": [0-9.]*' <<< "$r" | awk '{print $3}')"
  n="$(ed -c "begin; $APP select count(*) from ($sql) x; rollback;" 2>&1 | grep -E '^[0-9]+$' | tail -1)"
  if [ -z "$t" ]; then
    printf '  %-42s %s\n' "$nombre" "NO TERMINÓ: $(grep -m1 -i 'error' <<< "$r")"
    # (Todas las vistas juntas pueden pasar del tope con muchos asientos: se
    # dice, pero no falla; conta.js pide solo las de su pantalla.)
    [ "$nombre" = "fn_estados_control (todas)" ] || malos=1
  else
    printf '  %-42s %9.1f ms  %6s filas\n' "$nombre" "$t" "$n"
  fi
done

echo "== Los cuadres, como la app"
r="$(ed -c "begin; $APP select coalesce(string_agg(vista, ', '), 'ninguno') from fn_estados_control('$P', array['v_balanza', 'v_balance_general', 'v_resultados', 'v_flujo_caja', 'v_cxc_antiguedad', 'v_cxp_antiguedad', 'v_costo_por_obra']) where not ok; rollback;" 2>&1 | tail -n 1)"
revisa "fn_estados_control: nada en rojo" "ninguno" "$r"
revisa "el libro sigue sano (fn_verificar_cadena)" "ninguno" "$(ed -c "select coalesce(string_agg(control, ', '), 'ninguno') from fn_verificar_cadena() where not ok")"

[ $malos -eq 0 ] && echo "VOLUMEN c4 ok" || echo "VOLUMEN c4 FALLA"
exit $malos
