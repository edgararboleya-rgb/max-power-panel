#!/usr/bin/env bash
# =====================================================================
# c3-concurrencia.sh — lo que c3-pruebas.sql no puede probar: varias
# sesiones A LA VEZ contra los puentes. c3-pruebas corre en una sola
# sesión; aquí se abren varias de verdad, y cada una CONFIRMA (los puentes
# son diferidos: corren al confirmar, con el rol de la sesión).
#
#   ./c3-concurrencia.sh [nombre_bd]      (por defecto c3_concurrencia)
#
# Crea su base con c1 + c2 + c3, confirma las reglas que usa (material,
# tarjeta, el tipo de las obras) y da de alta una tarjeta de prueba, y:
#   1. Edgar corrige el total del MISMO recibo desde dos teléfonos a la
#      vez: A cambia y espera; B cambia mientras tanto. B espera a A (la
#      fila del recibo), y al final hay dos correcciones enlazadas: el
#      asiento vivo es el del último total, sin asientos de más.
#   2. El backfill corre mientras Edgar está guardando un recibo: el
#      backfill no lo espera ni lo toca (lo salta: «en uso»), y al
#      confirmar Edgar, su propio puente lo contabiliza.
#   3. Diez recibos subidos a la vez (como la app): diez asientos, sin
#      huecos ni repetidos en la numeración.
#   4. Dos backfills a la vez sobre seis recibos que esperaban una regla:
#      cada recibo entra UNA vez; ninguno queda en error.
#   5. Dos cobros a la vez por el total de la MISMA factura (un doble toque
#      con la red lenta): el segundo espera al primero (la fila de la
#      factura) y ya no cabe (MX008). Un cobro, no dos.
#   6. Un cobro a una factura mientras Edgar la anula con su nota de
#      crédito: el cobro espera y ve la factura anulada (MX008).
#   7. Dos anticipos distintos aplicados a la vez a la misma factura: el
#      segundo espera y ya no cabe (MX008).
# Y comprueba: fn_verificar_cadena y los controles de los puentes en true
# (también partidas: ninguna factura en negativo ni anulada con cobro).
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c3_concurrencia}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

# Como la app: el dueño, con el rol authenticated, y la transacción confirma con él.
APP="select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-4000-a000-000000000001\",\"role\":\"authenticated\"}', true); set local role authenticated;"

cat > "$TMP/reglas.sql" <<'SQL'
-- Lo que Edgar haría antes del 2-oct: su tarjeta y las reglas que usa este
-- script, confirmadas.
do $$
begin
  if not exists (select 1 from cuentas where codigo = '2100-9998') then
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('2100-9998', 'Tarjeta de prueba (banco)', 'Test card (bench)', 'pasivo', 'haber', true, 'prohibida', 'prohibida');
  end if;
  perform fn_tarjeta_alta('9998', '2100-9998', 'banco de pruebas');
  perform fn_mapeo_confirmar('categoria', 'material');
  perform fn_mapeo_confirmar('metodo_pago', 'tarjeta');
  perform fn_mapeo_confirmar('tipo_proyecto');
end $$;
-- Dos recibos ya contabilizados (escenarios 1 y 2) y seis que esperan una
-- regla que todavía no existe (escenario 4).
insert into recibos (id, proyecto_id, ruta, total, proveedor, estado, autor_id, fecha, categoria, metodo_pago, ultimos4)
overriding system value
select v.id, 'casa-perez-k3m9', 'recibos/banco/' || v.id || '.jpg', v.total, 'CED', 'leido',
       '00000000-0000-4000-a000-000000000001', date '2026-10-06', 'material', v.metodo, '9998'
  from (values (-900, 245.37, 'tarjeta'), (-901, 100.00, 'tarjeta'),
               (-920, 11.00, 'c3 metodo nuevo'), (-921, 12.00, 'c3 metodo nuevo'), (-922, 13.00, 'c3 metodo nuevo'),
               (-923, 14.00, 'c3 metodo nuevo'), (-924, 15.00, 'c3 metodo nuevo'), (-925, 16.00, 'c3 metodo nuevo'))
       as v(id, total, metodo);
-- La factura de los anticipos (escenario 7): entra al libro al confirmar.
insert into facturas (id, proyecto_id, num, fecha, monto, pagada, retencion) overriding system value
values (-950, 'casa-perez-k3m9', 'C3-950', date '2026-10-10', 1000.00, false, 0);
SQL

echo "== Base $BD: c1 + c2 + c3 + las reglas"
"$DIR/correr.sh" "$BD" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" "$TMP/reglas.sql" > "$TMP/carga.out" 2>&1 \
  || { cat "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

echo "== 1. El mismo recibo, corregido desde dos teléfonos a la vez"
ed -c "begin; $APP update recibos set total = 300.00 where id = -900; select pg_sleep(2); commit;" > "$TMP/1a.out" 2>&1 &
sleep 0.5
ed -c "begin; $APP update recibos set total = 350.00 where id = -900; commit;" > "$TMP/1b.out" 2>&1 &
wait
revisa "dos correcciones enlazadas: asiento, reverso, sustituto, reverso, sustituto" "5/2" \
  "$(ed -c "select count(*) || '/' || count(*) filter (where camino = 'reverso') from asientos where origen_tabla = 'recibos' and origen_id = '-900'")"
revisa "el asiento vivo es el del último total" "350.00" \
  "$(ed -c "select l.monto from asientos a join asiento_lineas l on l.asiento_id = a.id
             where a.origen_tabla = 'recibos' and a.origen_id = '-900' and a.camino = 'puente' and l.monto > 0
               and not exists (select 1 from asientos r where r.reversa_a = a.id)")"
revisa "cada sustituto dice a cuál sustituye" "2" \
  "$(ed -c "select count(*) from asientos where origen_tabla = 'recibos' and origen_id = '-900' and sustituye_a is not null")"

echo "== 2. El backfill mientras Edgar guarda un recibo"
ed -c "begin; $APP update recibos set total = 111.00 where id = -901; select pg_sleep(3); commit;" > "$TMP/2a.out" 2>&1 &
sleep 0.7
inicio=$(date +%s.%N)
ed -c "select (fn_puentes_correr()->>'en_uso_saltados')::int >= 1" > "$TMP/2b.out" 2>&1
fin=$(date +%s.%N)
wait
revisa "el backfill saltó el recibo en uso" "t" "$(tail -n 1 "$TMP/2b.out")"
revisa "el backfill no esperó a Edgar" "t" "$(python3 -c "print('t' if $fin - $inicio < 2 else 'f')")"
revisa "al confirmar, el puente de Edgar lo contabilizó: asiento, reverso, sustituto" "3/1" \
  "$(ed -c "select count(*) || '/' || count(*) filter (where camino = 'reverso') from asientos where origen_tabla = 'recibos' and origen_id = '-901'")"

echo "== 3. Diez recibos subidos a la vez, como la app"
for i in $(seq 910 919); do
  ed -c "begin; $APP
         insert into recibos (id, proyecto_id, ruta, total, proveedor, estado, autor_id, fecha, categoria, metodo_pago, ultimos4)
         overriding system value
         values (-$i, 'oficina-nch-7xq2', 'recibos/banco/$i.jpg', 10.00, 'Home Depot', 'leido',
                 '00000000-0000-4000-a000-000000000001', date '2026-10-15', 'material', 'tarjeta', '9998');
         commit;" > "$TMP/3-$i.out" 2>&1 &
done
wait
revisa "diez recibos, diez asientos, confirmados como la app" "10/10" \
  "$(ed -c "select count(*) || '/' || count(*) filter (where rol_bd = 'authenticated') from asientos
             where origen_tabla = 'recibos' and origen_id::bigint between -919 and -910")"

echo "== 4. Dos backfills a la vez, sobre seis recibos que esperaban una regla"
ed -c "select fn_mapeo_metodo_pago('c3 metodo nuevo', 'tarjeta')" > /dev/null 2>&1
ed -c "select fn_puentes_correr()->>'errores'" > "$TMP/4a.out" 2>&1 &
ed -c "select fn_puentes_correr()->>'errores'" > "$TMP/4b.out" 2>&1 &
wait
revisa "cada recibo entró una vez" "6/6" \
  "$(ed -c "select count(*) || '/' || count(distinct origen_id) from asientos
             where origen_tabla = 'recibos' and origen_id::bigint between -925 and -920")"
revisa "ningún backfill dejó errores" "0 0" "$(tail -n 1 "$TMP/4a.out") $(tail -n 1 "$TMP/4b.out")"

if grep -qi error "$TMP"/1a.out "$TMP"/1b.out "$TMP"/2a.out "$TMP"/2b.out "$TMP"/3-*.out "$TMP"/4a.out "$TMP"/4b.out; then
  echo "FALLA: una sesión dio error:"
  grep -i error "$TMP"/1a.out "$TMP"/1b.out "$TMP"/2a.out "$TMP"/2b.out "$TMP"/3-*.out "$TMP"/4a.out "$TMP"/4b.out
  malos=1
fi

# Las facturas 1101 (id 1) y 1103 (id 3) ya entraron con los backfills de arriba.
revisa "las facturas de los cobros están en el libro" "3" \
  "$(ed -c "select count(*) from facturas where id in (1, 3, -950) and contabilizado_en is not null")"

echo "== 5. Dos cobros a la vez por el total de la misma factura"
ed -c "begin; $APP select fn_cobro_registrar('{\"fecha\":\"2026-10-21\",\"monto\":\"8000.00\",\"medio\":\"ach\",\"referencia\":\"A\",\"aplicaciones\":[{\"factura_id\":3,\"monto\":\"8000.00\"}]}'); select pg_sleep(2); commit;" > "$TMP/5a.out" 2>&1 &
sleep 0.5
ed -c "begin; $APP select fn_cobro_registrar('{\"fecha\":\"2026-10-21\",\"monto\":\"8000.00\",\"medio\":\"zelle\",\"referencia\":\"B\",\"aplicaciones\":[{\"factura_id\":3,\"monto\":\"8000.00\"}]}'); commit;" > "$TMP/5b.out" 2>&1 &
wait
revisa "el primero entró" "0" "$(grep -ci error "$TMP/5a.out")"
revisa "el segundo esperó y ya no cupo (MX008)" "MX008" "$(grep -o 'MX008' "$TMP/5b.out" | head -n 1)"
revisa "un solo cobro vigente, y la factura en cero (no en negativo)" "1/0.00" \
  "$(ed -c "select (select count(*) from aplicaciones_cobro a join cobros c on c.id = a.cobro_id
                     where a.factura_id = 3 and c.estado = 'vigente') || '/' ||
                    (select coalesce(sum(l.monto), 0) from asiento_lineas l
                      where l.partida_tabla = 'facturas' and l.partida_id = '3' and l.cuenta = '1110')")"

echo "== 6. Un cobro a una factura mientras Edgar la anula"
ed -c "begin; $APP select fn_factura_anular(1, 'c3: se facturó a otro cliente', date '2026-10-15'); select pg_sleep(2); commit;" > "$TMP/6a.out" 2>&1 &
sleep 0.5
ed -c "begin; $APP select fn_cobro_registrar('{\"fecha\":\"2026-10-15\",\"monto\":\"5000.00\",\"medio\":\"cheque\",\"referencia\":\"9001\",\"aplicaciones\":[{\"factura_id\":1,\"monto\":\"5000.00\"}]}'); commit;" > "$TMP/6b.out" 2>&1 &
wait
revisa "la anulación entró" "0" "$(grep -ci error "$TMP/6a.out")"
revisa "el cobro esperó y vio la factura anulada (MX008)" "MX008" "$(grep -o 'MX008' "$TMP/6b.out" | head -n 1)"
revisa "la factura anulada sin cobros y en cero" "anulada/0/0.00" \
  "$(ed -c "select f.estado || '/' ||
                    (select count(*) from aplicaciones_cobro a join cobros c on c.id = a.cobro_id
                      where a.factura_id = 1 and c.estado = 'vigente') || '/' ||
                    (select coalesce(sum(l.monto), 0) from asiento_lineas l
                      where l.partida_tabla = 'facturas' and l.partida_id = '1' and l.cuenta = '1110')
               from facturas f where f.id = 1")"

echo "== 7. Dos anticipos distintos aplicados a la vez a la misma factura"
ed -c "begin; $APP select fn_cobro_registrar('{\"fecha\":\"2026-10-05\",\"monto\":\"1000.00\",\"referencia\":\"ANT-1\",\"aplicaciones\":[{\"proyecto_id\":\"casa-perez-k3m9\",\"monto\":\"1000.00\"}]}'); commit;" > /dev/null 2>&1
ed -c "begin; $APP select fn_cobro_registrar('{\"fecha\":\"2026-10-05\",\"monto\":\"1000.00\",\"referencia\":\"ANT-2\",\"aplicaciones\":[{\"proyecto_id\":\"casa-perez-k3m9\",\"monto\":\"1000.00\"}]}'); commit;" > /dev/null 2>&1
ed -c "begin; $APP select fn_anticipo_aplicar((select id from cobros where referencia = 'ANT-1'), -950, '1000.00', date '2026-10-12'); select pg_sleep(2); commit;" > "$TMP/7a.out" 2>&1 &
sleep 0.5
ed -c "begin; $APP select fn_anticipo_aplicar((select id from cobros where referencia = 'ANT-2'), -950, '1000.00', date '2026-10-12'); commit;" > "$TMP/7b.out" 2>&1 &
wait
revisa "el primer anticipo entró" "0" "$(grep -ci error "$TMP/7a.out")"
revisa "el segundo esperó y ya no cupo (MX008)" "MX008" "$(grep -o 'MX008' "$TMP/7b.out" | head -n 1)"
revisa "la factura en cero, con un anticipo aplicado" "1/0.00" \
  "$(ed -c "select (select count(*) from aplicaciones_cobro a where a.factura_id = -950 and a.desde_anticipo) || '/' ||
                    (select coalesce(sum(l.monto), 0) from asiento_lineas l
                      where l.partida_tabla = 'facturas' and l.partida_id = '-950' and l.cuenta = '1110')")"
revisa "ningún papel quedó en error en la bandeja" "0" "$(ed -c "select count(*) from puente_documentos where estado = 'error'")"
revisa "fn_verificar_cadena: todos los controles en true" "" "$(ed -c "select coalesce(string_agg(control, ', '), '') from fn_verificar_cadena() where not ok")"
revisa "los controles de los puentes (triggers, documentos, bandeja, use_tax, mano_de_obra, partidas) en true" "" \
  "$(ed -c "select coalesce(string_agg(control, ', '), '') from fn_puentes_verificar()
             where not ok and control in ('triggers', 'documentos', 'bandeja', 'use_tax', 'mano_de_obra', 'partidas')")"
sin_hueco="$(ed -c "select count(*) = max(secuencia) and count(distinct secuencia) = count(*) and min(secuencia) = 1 from asientos where anio = 2026")"
revisa "numeración de 2026 sin huecos ni repetidos" "t" "$sin_hueco"

[ $malos -eq 0 ] && echo "CONCURRENCIA c3 ok" || echo "CONCURRENCIA c3 FALLA"
exit $malos
