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
#      backfill no lo espera ni lo toca (lo salta: «en uso», o «sin
#      cambios» si lo que ve confirmado es lo de su asiento vivo: el
#      backfill ya no vuelve a planear lo que no cambió), y al confirmar
#      Edgar, su propio puente lo contabiliza.
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
#   8. Dos cobros a la vez a la misma factura con su número escrito de
#      otra forma (« 951», «+951», «951 »): el candado y la búsqueda leen
#      el mismo número, así que el segundo espera igual y ya no cabe
#      (MX008). (Antes el candado se saltaba esos y la factura se cobraba
#      dos veces.)
#   9. Dos lecturas del MISMO ticket a la vez (dos fotos del mismo papel,
#      leídas por cerebro en dos peticiones que confirman juntas, con otro
#      posteo en vuelo que tiene el candado de la cadena): la segunda
#      espera el candado del ticket de la primera, mira después de que
#      confirmó y la ve: una en el libro y la otra pendiente
#      (duplicado). (Antes miraban las dos antes de que la otra confirmara
#      y entraban las dos: la deuda doble.)
#  10. (13-nov-2026, la Fase 11b; 14-nov, la 11c) UNA NÓMINA POSTEA MIENTRAS
#      EDGAR DEVENGA SU MES, la nómina primero: el devengo espera su turno
#      (el candado de la cadena) ANTES de mirar las horas, y entra ya sin la
#      que ella pagó: solo la hora que nadie pagó, el control en verde, y
#      devengar otra vez no hace nada. (Hasta el 13-nov pedía el candado al
#      postear: entraba con las horas que había visto ANTES de que la nómina
#      confirmara —también la que ella pagó—, el control devengo lo decía y
#      había que devengar otra vez.)
#  11. Lo mismo, el devengo primero: la nómina espera, ve el devengo y lo
#      pone al día en su misma transacción (lo que hace c15 al postear):
#      queda solo la hora que nadie pagó, y el control en verde. Nadie se
#      queda esperando a nadie (ningún interbloqueo).
#      (La nómina es de prueba: c15 no está en esta base. Su journal entra
#      por la puerta de los puentes con el origen de una corrida, y su marca
#      sin dinero —fn_nomina_horas_con_pago, la que c3 lee— es una función
#      de este script que lee de una tabla lo que cada «nómina» paga: se ve
#      al confirmar, como el lote de c15. Con una nómina de verdad:
#      c3-nomina.sh. Y UN JORNAL a la vez que el devengo, con Zelle de
#      verdad y en los dos órdenes: la escena 11 de c3-jornal.sh.)
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
  perform fn_mapeo_confirmar('metodo_pago', 'credito');
  perform fn_mapeo_confirmar('tipo_proyecto');
  -- La forma de pago del escenario 4 empieza SIN regla: producción solo
  -- admite 5 (su CHECK), así que la «nueva» es debito sin su regla.
  delete from mapeo_metodo_pago where metodo_pago = 'debito';
end $$;
-- Dos recibos ya contabilizados (escenarios 1 y 2) y seis que esperan una
-- regla que todavía no existe (escenario 4). Subidos el día de su fecha
-- (creado): el reloj del banco puede ser de antes del corte, y un recibo
-- subido antes del corte es de antes del corte (c3, punto 6).
insert into recibos (id, proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago, ultimos4)
overriding system value
select v.id, 'casa-perez-k3m9', 'recibos/banco/' || v.id || '.jpg', v.total, 'CED', 'leido',
       '00000000-0000-4000-a000-000000000001', timestamptz '2026-10-06 12:00-04', date '2026-10-06', 'material', v.metodo, '9998'
  from (values (-900, 245.37, 'credito'), (-901, 100.00, 'credito'),
               (-920, 11.00, 'debito'), (-921, 12.00, 'debito'), (-922, 13.00, 'debito'),
               (-923, 14.00, 'debito'), (-924, 15.00, 'debito'), (-925, 16.00, 'debito'))
       as v(id, total, metodo);
-- Dos fotos del mismo ticket, subidas por Gustavo y todavía por leer
-- (escenario 9).
insert into recibos (id, proyecto_id, ruta, notas, estado, autor_id, creado, categoria) overriding system value
values (-930, 'casa-perez-k3m9', 'recibos/banco/930.jpg', 'breakers 20A', 'por_leer', '00000000-0000-4000-a000-000000000002',
        timestamptz '2026-10-14 09:00-04', 'material'),
       (-931, 'casa-perez-k3m9', 'recibos/banco/931.jpg', 'breakers 20A', 'por_leer', '00000000-0000-4000-a000-000000000002',
        timestamptz '2026-10-14 09:05-04', 'material');
-- La factura de los anticipos (escenario 7) y la del número escrito de
-- otra forma (escenario 8): entran al libro al confirmar.
insert into facturas (id, proyecto_id, num, fecha, monto, pagada, retencion) overriding system value
values (-950, 'casa-perez-k3m9', 'C3-950', date '2026-10-10', 1000.00, false, 0),
       (951, 'casa-perez-k3m9', 'C3-951', date '2026-10-10', 700.00, false, 0);
-- (Escenarios 10 y 11) El devengo estándar y una nómina a la vez: las horas
-- aprobadas de Gustavo (30 la hora) en noviembre y en octubre, con su CO, y
-- la marca sin dinero de la nómina (c15), DE PRUEBA: lee de una tabla lo que
-- la «nómina» de cada escenario paga.
insert into costos_equipo (usuario_id, costo_hora) values ('00000000-0000-4000-a000-000000000002', 30.00)
on conflict (usuario_id) do update set costo_hora = 30.00;
insert into horas (id, fecha, usuario_id, proyecto_id, horas, notas, co, aprobado_por, aprobado_el) overriding system value
values (-940, date '2026-11-03', '00000000-0000-4000-a000-000000000002', 'casa-perez-k3m9', 8, 'c3-concurrencia', 'C3-CONC', '00000000-0000-4000-a000-000000000001', now()),
       (-941, date '2026-11-10', '00000000-0000-4000-a000-000000000002', 'casa-perez-k3m9', 4, 'c3-concurrencia', 'C3-CONC', '00000000-0000-4000-a000-000000000001', now()),
       (-942, date '2026-10-06', '00000000-0000-4000-a000-000000000002', 'casa-perez-k3m9', 8, 'c3-concurrencia', 'C3-CONC', '00000000-0000-4000-a000-000000000001', now()),
       (-943, date '2026-10-20', '00000000-0000-4000-a000-000000000002', 'casa-perez-k3m9', 4, 'c3-concurrencia', 'C3-CONC', '00000000-0000-4000-a000-000000000001', now());
create table public.c3c_pagadas (horas_id bigint primary key, corrida_id uuid not null, dia_pago date not null);
alter table public.c3c_pagadas enable row level security;
revoke all on public.c3c_pagadas from public, anon, authenticated, service_role;
create function public.fn_nomina_horas_con_pago() returns table (horas_id bigint, corrida_id uuid, dia_pago date)
language sql stable
set search_path = public, pg_temp
as $f$ select p.horas_id, p.corrida_id, p.dia_pago from public.c3c_pagadas p $f$;
revoke execute on function public.fn_nomina_horas_con_pago() from public, anon, service_role;
grant  execute on function public.fn_nomina_horas_con_pago() to authenticated;
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
ed -c "select fn_puentes_correr() is not null" > "$TMP/2b.out" 2>&1
fin=$(date +%s.%N)
# (Edgar todavía no confirmó: lo que el backfill hizo ya está confirmado.)
ed -c "select count(*) from asientos where origen_tabla = 'recibos' and origen_id = '-901'" > "$TMP/2c.out" 2>&1
wait
revisa "el backfill no tocó el recibo en uso (su único asiento sigue siendo el de antes)" "1" "$(tail -n 1 "$TMP/2c.out")"
revisa "el backfill no esperó a Edgar" "t" "$(python3 -c "print('t' if $fin - $inicio < 2 else 'f')")"
revisa "al confirmar, el puente de Edgar lo contabilizó: asiento, reverso, sustituto" "3/1" \
  "$(ed -c "select count(*) || '/' || count(*) filter (where camino = 'reverso') from asientos where origen_tabla = 'recibos' and origen_id = '-901'")"

echo "== 3. Diez recibos subidos a la vez, como la app"
for i in $(seq 910 919); do
  ed -c "begin; $APP
         insert into recibos (id, proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago, ultimos4)
         overriding system value
         values (-$i, 'oficina-nch-7xq2', 'recibos/banco/$i.jpg', 10.00, 'Home Depot', 'leido',
                 '00000000-0000-4000-a000-000000000001', timestamptz '2026-10-15 12:00-04', date '2026-10-15', 'material',
                 'credito', '9998');
         commit;" > "$TMP/3-$i.out" 2>&1 &
done
wait
revisa "diez recibos, diez asientos, confirmados como la app" "10/10" \
  "$(ed -c "select count(*) || '/' || count(*) filter (where rol_bd = 'authenticated') from asientos
             where origen_tabla = 'recibos' and origen_id::bigint between -919 and -910")"

echo "== 4. Dos backfills a la vez, sobre seis recibos que esperaban una regla"
ed -c "select fn_mapeo_metodo_pago('debito', 'tarjeta')" > /dev/null 2>&1
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
revisa "las facturas de los cobros están en el libro" "4" \
  "$(ed -c "select count(*) from facturas where id in (1, 3, -950, 951) and contabilizado_en is not null")"

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
echo "== 8. Dos cobros a la vez a la misma factura, con su número escrito de otra forma"
# Cada par: A toma la factura y duerme; B llega con el número escrito
# distinto. B tiene que esperar a A (la misma fila) y ya no caber.
for par in " 951|+951" "951|+951" "+951|951 "; do
  a="${par%%|*}"; b="${par##*|}"
  ed -c "begin; $APP select fn_cobro_registrar('{\"fecha\":\"2026-10-21\",\"monto\":\"700.00\",\"medio\":\"ach\",\"referencia\":\"A8\",\"aplicaciones\":[{\"factura_id\":\"$a\",\"monto\":\"700.00\"}]}'); select pg_sleep(2); commit;" > "$TMP/8a.out" 2>&1 &
  sleep 0.5
  ed -c "begin; $APP select fn_cobro_registrar('{\"fecha\":\"2026-10-21\",\"monto\":\"700.00\",\"medio\":\"ach\",\"referencia\":\"B8\",\"aplicaciones\":[{\"factura_id\":\"$b\",\"monto\":\"700.00\"}]}'); commit;" > "$TMP/8b.out" 2>&1 &
  wait
  revisa "«$a» entró" "0" "$(grep -ci error "$TMP/8a.out")"
  revisa "«$b» esperó y ya no cupo (MX008)" "MX008" "$(grep -o 'MX008' "$TMP/8b.out" | head -n 1)"
  revisa "un solo cobro vigente a la C3-951, y en cero (no en negativo)" "1/0.00" \
    "$(ed -c "select (select count(*) from aplicaciones_cobro a join cobros c on c.id = a.cobro_id
                       where a.factura_id = 951 and c.estado = 'vigente') || '/' ||
                      (select coalesce(sum(l.monto), 0) from asiento_lineas l
                        where l.partida_tabla = 'facturas' and l.partida_id = '951' and l.cuenta = '1110')")"
  # Se anula el cobro que entró, para el par siguiente.
  ed -c "begin; $APP select fn_cobro_anular(c.id, 'c3-concurrencia: otro par') from cobros c
          join aplicaciones_cobro a on a.cobro_id = c.id where a.factura_id = 951 and c.estado = 'vigente'; commit;" > /dev/null 2>&1
done

echo "== 9. Dos lecturas del mismo ticket a la vez"
# H: un posteo en vuelo, con el candado de la cadena de c2 hasta confirmar.
# A y B: la lectura de cada foto (cerebro, service_role); sus puentes
# corren al confirmar, mientras H sigue ahí.
CER="select set_config('request.jwt.claims', '{\"role\":\"service_role\"}', true); set local role service_role;"
LEE="set estado = 'leido', total = 245.37, subtotal = 229.32, tax = 16.05, fecha = '2026-10-14', proveedor = 'CED', num_recibo = 'CED-7777', metodo_pago = 'credito', ultimos4 = '9998'"
ed -c "begin; select pg_advisory_xact_lock(820260923); select pg_sleep(3); commit;" > "$TMP/9h.out" 2>&1 &
sleep 0.5
ed -c "begin; $CER update recibos $LEE where id = -930; commit;" > "$TMP/9a.out" 2>&1 &
sleep 0.5
ed -c "begin; $CER update recibos $LEE where id = -931; commit;" > "$TMP/9b.out" 2>&1 &
wait
revisa "las dos lecturas confirmaron sin error" "0" "$(cat "$TMP/9a.out" "$TMP/9b.out" | grep -ci error)"
revisa "el ticket entró UNA vez: una foto en el libro y la otra pendiente (duplicado)" "1/pendiente:duplicado" \
  "$(ed -c "select (select count(*) from recibos r where r.id in (-930, -931) and r.contabilizado_en is not null) || '/' ||
                    (select string_agg(d.estado || ':' || d.codigo, ',') from puente_documentos d
                      where d.tabla = 'recibos' and d.documento_id in ('-930', '-931') and d.estado <> 'contabilizado')")"

# El devengo vivo de un mes: su línea de 5000 con el CO de estas escenas, y el control devengo mirando ese mes.
dev_linea() { ed -c "select coalesce((select l.monto::text from asientos a join asiento_lineas l on l.asiento_id = a.id where a.origen_tabla = 'horas_devengo' and a.origen_id = '$1' and a.camino not in ('reverso', 'reverso_automatico') and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso') and l.cuenta = '5000' and l.co = 'C3-CONC'), '-')"; }
dev_control() { ed -c "select coalesce((select 'f/' || coalesce(substring(f.v from 'cuenta ([0-9.]+) h que la nómina ya pagó dentro del mes'), 'otro') from fn_puentes_verificar() c cross join lateral jsonb_array_elements_text(c.detalle->'fallan') f(v) where c.control = 'devengo' and f.v like 'el devengo de $1 (%' limit 1), 't')"; }
# El journal de una nómina de prueba (por la puerta de los puentes, con el origen de una corrida): journal <corrida> <fecha>
journal() { echo "select fn_postear_interno(jsonb_build_object('camino', 'puente', 'fecha', '$2', 'origen_tabla', 'nomina_corridas', 'origen_id', '$1', 'descripcion', 'c3-concurrencia: el journal de una nómina de prueba', 'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5000', 'monto', '250.00', 'proyecto_id', 'casa-perez-k3m9', 'co', 'C3-CONC'), jsonb_build_object('cuenta', '2210', 'monto', '-250.00')))) is not null;"; }

echo "== 10. Una nómina postea mientras Edgar devenga su mes (la nómina, primero)"
K10=00000000-0000-4000-a000-00000c3c0010
ed -c "begin; insert into c3c_pagadas values (-940, '$K10', date '2026-11-13'); $(journal $K10 2026-11-13) select pg_sleep(2); commit;" > "$TMP/10a.out" 2>&1 &
sleep 0.5
ed -c "begin; $APP select fn_horas_devengar('2026-11')->>'accion'; commit;" > "$TMP/10b.out" 2>&1 &
wait
revisa "las dos confirmaron sin error" "0" "$(cat "$TMP/10a.out" "$TMP/10b.out" | grep -ci error)"
revisa "el devengo esperó a la nómina ANTES de mirar las horas, y entró ya sin la que ella pagó: solo la que nadie pagó (4 h × 30), y el control en verde" "posteado/120.00/t" \
  "$(tail -n 1 "$TMP/10b.out")/$(dev_linea 2026-11)/$(dev_control 2026-11)"
revisa "devengar otra vez no hace nada: ya estaba al día" "sin_cambios/120.00/t" \
  "$(ed -c "begin; $APP select fn_horas_devengar('2026-11')->>'accion'; commit;" 2>&1 | tail -n 1)/$(dev_linea 2026-11)/$(dev_control 2026-11)"

echo "== 11. Lo mismo, el devengo primero: la nómina espera, lo ve y lo pone al día"
K11=00000000-0000-4000-a000-00000c3c0011
ed -c "begin; $APP select fn_horas_devengar('2026-10')->>'accion'; select pg_sleep(2); commit;" > "$TMP/11a.out" 2>&1 &
sleep 0.5
ed -c "begin; insert into c3c_pagadas values (-942, '$K11', date '2026-10-16'); $(journal $K11 2026-10-16)
       select case when exists (select 1 from asientos a where a.origen_tabla = 'horas_devengo' and a.origen_id = '2026-10'
                                  and a.camino not in ('reverso', 'reverso_automatico')
                                  and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso'))
                   then fn_horas_devengar('2026-10')->>'accion' else 'no vio el devengo' end; commit;" > "$TMP/11b.out" 2>&1 &
wait
revisa "las dos confirmaron sin error (nadie se quedó esperando a nadie)" "0" "$(cat "$TMP/11a.out" "$TMP/11b.out" | grep -ci error)"
revisa "la nómina esperó al devengo, lo vio y lo puso al día en su misma transacción" "sustituido" "$(tail -n 1 "$TMP/11b.out")"
revisa "queda devengada solo la hora que nadie pagó, y el control en verde" "120.00/t" "$(dev_linea 2026-10)/$(dev_control 2026-10)"
revisa "en el libro, el 5000 de esas horas: en cada mes, el journal y el devengo de la que nadie pagó; nada dos veces" "2026-10 370.00 · 2026-11 250.00 · 2026-12 -120.00" \
  "$(ed -c "select string_agg(q.periodo || ' ' || q.s, ' · ' order by q.periodo) from (select a.periodo, sum(l.monto) as s from asiento_lineas l join asientos a on a.id = l.asiento_id where l.cuenta = '5000' and l.co = 'C3-CONC' group by a.periodo having sum(l.monto) <> 0) q")"

revisa "ningún papel quedó en error en la bandeja" "0" "$(ed -c "select count(*) from puente_documentos where estado = 'error'")"
revisa "fn_verificar_cadena: todos los controles en true" "" "$(ed -c "select coalesce(string_agg(control, ', '), '') from fn_verificar_cadena() where not ok")"
revisa "los controles de los puentes (triggers, documentos, bandeja, use_tax, mano_de_obra, partidas, devengo) en true" "" \
  "$(ed -c "select coalesce(string_agg(control, ', '), '') from fn_puentes_verificar()
             where not ok and control in ('triggers', 'documentos', 'bandeja', 'use_tax', 'mano_de_obra', 'partidas', 'devengo')")"
sin_hueco="$(ed -c "select count(*) = max(secuencia) and count(distinct secuencia) = count(*) and min(secuencia) = 1 from asientos where anio = 2026")"
revisa "numeración de 2026 sin huecos ni repetidos" "t" "$sin_hueco"

[ $malos -eq 0 ] && echo "CONCURRENCIA c3 ok" || echo "CONCURRENCIA c3 FALLA"
exit $malos
