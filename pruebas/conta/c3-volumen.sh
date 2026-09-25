#!/usr/bin/env bash
# =====================================================================
# c3-volumen.sh — lo que c3-pruebas.sql no puede probar porque pasa con
# MUCHOS papeles: un año largo de tickets de la cuadrilla (3.000 recibos
# por defecto), y con ellos facturas, cobros y trabajos externos (1.200,
# 1.100 y 600, como el libro de c4-volumen.sh), ya en el libro, y la app
# pidiendo «reintentar puente» (fn_puentes_correr) y los controles
# (fn_puentes_verificar) como authenticated, con el tope de Supabase para
# la API: statement_timeout de 8 s. Antes el backfill volvía a planear cada
# recibo contabilizado, y cada plan recorría todos los recibos buscando
# duplicados (sin índice): crecía al cuadrado y a los 3.000 se cortaba
# (57014). Y después, aunque ya se saltaba los recibos que no cambiaron,
# volvía a planear cada factura, cobro y trabajo externo: con el libro de
# 10.000 asientos tardaba de 10 a 12 s y la API lo cortaba (la ronda 3 de
# c4); esta prueba solo metía recibos y no lo veía.
#
#   ./c3-volumen.sh [nombre_bd] [recibos]     (por defecto c3_volumen 3000)
#
# Crea su base con c1 + c2 + c3, da de alta una tarjeta y confirma las
# reglas que usa, mete los recibos (leídos, con tarjeta, cada uno con su
# foto y su ticket; entran al libro al confirmar, cada uno por su puente),
# las facturas, sus cobros y los trabajos externos (cada uno por su
# puente), y comprueba:
#   · todos entraron al libro, sin errores en la bandeja;
#   · «reintentar puente» como la app (authenticated, 8 s): termina, y
#     cuenta los recibos, las facturas, los cobros y los trabajos externos
#     que no cambiaron como «sin_cambios» de su tabla (no los vuelve a
#     planear);
#   · fn_puentes_verificar como la app (authenticated, 8 s): termina;
#   · un recibo corregido después (el ✎ de un total) sí se vuelve a pasar.
# Imprime cuánto tardó cada cosa.
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c3_volumen}"
N="${2:-3000}"
[[ "$N" =~ ^[0-9]+$ ]] || { echo "El número de recibos va en dígitos (llegó «$N»)." >&2; exit 64; }
TMP="$(mktemp -d)"
chmod 755 "$TMP"
trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

# Como la app: el dueño, con el rol authenticated y el tope de la API.
APP="select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-4000-a000-000000000001\",\"role\":\"authenticated\"}', true); set local role authenticated; set local statement_timeout = '8s';"

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}
cronometro() { date +%s.%N; }
ms() { python3 -c "print(int(($2 - $1) * 1000))"; }

cat > "$TMP/reglas.sql" <<'SQL'
-- La tarjeta de la cuadrilla y las reglas que usan estos recibos, confirmadas.
do $$
begin
  if not exists (select 1 from cuentas where codigo = '2100-9998') then
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('2100-9998', 'Tarjeta de prueba (banco)', 'Test card (bench)', 'pasivo', 'haber', true, 'prohibida', 'prohibida');
  end if;
  perform fn_tarjeta_alta('9998', '2100-9998', 'banco de pruebas');
  perform fn_mapeo_confirmar('categoria', 'material');
  perform fn_mapeo_confirmar('metodo_pago', 'credito');
end $$;
-- Y las de las facturas (el ingreso de cada tipo de obra) y los ayudantes
-- de los trabajos externos (cada uno con su proveedor).
do $$
declare
  v_t text;
  e   bigint;
  g   int;
begin
  for v_t in select distinct fn_puente_normalizar(p.tipo) from proyectos p
              where p.id in ('casa-perez-k3m9', 'oficina-nch-7xq2') and nullif(btrim(p.tipo), '') is not null loop
    perform fn_mapeo_tipo_proyecto(v_t, coalesce((select m.cuenta from mapeo_tipo_proyecto m where m.tipo = v_t),
                                                 case v_t when 'comercial' then '4020' when 'servicio' then '4030' else '4010' end));
  end loop;
  for g in 1..10 loop
    insert into externos_equipo (nombre, costo_hora, activo) values ('vol ayudante ' || g, 20, true) returning id into e;
    perform fn_proveedor_alta('VOL AYUDANTE ' || g, 'Net 15', '{}', e);
  end loop;
end $$;
SQL

echo "== Base $BD: c1 + c2 + c3 + las reglas"
"$DIR/correr.sh" "$BD" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" "$TMP/reglas.sql" > "$TMP/carga.out" 2>&1 \
  || { cat "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

echo "== $N recibos leídos, con tarjeta (entran al libro al confirmar; en tandas de 500, cada una su transacción)"
t0=$(cronometro)
desde=1
while [ "$desde" -le "$N" ]; do
  hasta=$(( desde + 499 )); [ "$hasta" -gt "$N" ] && hasta=$N
  ed -v ON_ERROR_STOP=1 > "$TMP/meter.out" 2>&1 <<SQL || { cat "$TMP/meter.out"; echo "FALLÓ meter los recibos" >&2; exit 2; }
insert into recibos (id, proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago, ultimos4, num_recibo)
overriding system value
select -100000 - g, case when g % 2 = 0 then 'casa-perez-k3m9' else 'oficina-nch-7xq2' end, 'recibos/vol/' || g || '.jpg',
       round((10 + (g * 37 % 900) + (g % 100) / 100.0)::numeric, 2),
       case g % 3 when 0 then 'CED' when 1 then 'Home Depot' else 'Platt' end,
       'leido', '00000000-0000-4000-a000-000000000001', timestamptz '2026-10-01 12:00-04' + ((g % 60) || ' days')::interval,
       date '2026-10-01' + (g % 60), 'material', 'credito', '9998', 'V-' || g
  from generate_series($desde, $hasta) g;
SQL
  desde=$(( hasta + 1 ))
done
t1=$(cronometro)
echo "     (tardó $(ms "$t0" "$t1") ms)"
revisa "todos en el libro" "$N" "$(ed -c "select count(*) from recibos where id <= -100001 and contabilizado_en is not null")"

echo "== 1.200 facturas, 1.100 cobros y 600 trabajos externos (cada uno por su puente)"
t0=$(cronometro)
ed -v ON_ERROR_STOP=1 > "$TMP/papeles.out" 2>&1 <<'SQL' || { tail -n 20 "$TMP/papeles.out"; echo "FALLÓ meter los papeles" >&2; exit 2; }
set constraints trg_puente_facturas_despues, trg_puente_externos_despues immediate;
insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
select -200000 - g, case when g % 2 = 0 then 'casa-perez-k3m9' else 'oficina-nch-7xq2' end, 'VF-' || g, date '2026-10-01' + (g % 60),
       round((2000 + (g * 137 % 18000))::numeric, 2), 0
  from generate_series(1, 1200) g;
insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, horas, costo, externo_id, creado) overriding system value
select -300000 - g, case when g % 2 = 0 then 'casa-perez-k3m9' else 'oficina-nch-7xq2' end, 'vol ayudante ' || g,
       date '2026-10-01' + (g % 60), 'horas', 40, round((800 + (g * 13 % 800))::numeric, 2),
       (select e.id from externos_equipo e where e.nombre = 'vol ayudante ' || (1 + g % 10)),
       (date '2026-10-01' + (g % 60) + time '12:00') at time zone 'America/New_York'
  from generate_series(1, 600) g;
do $$
declare
  r record;
begin
  for r in select f.id, f.monto, f.fecha from facturas f where f.num like 'VF-%' order by f.id desc limit 1100 loop
    -- (a más tardar el 30-nov: c2 no deja postear más allá del mes
    -- siguiente al abierto más antiguo)
    perform fn_cobro_registrar(jsonb_build_object('fecha', least(r.fecha + 20, date '2026-11-30')::text, 'monto', r.monto::text,
              'medio', 'cheque',
              'referencia', 'VCB-' || r.id,
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', r.id, 'monto', r.monto::text))));
  end loop;
end $$;
analyze;
SQL
t1=$(cronometro)
echo "     (tardó $(ms "$t0" "$t1") ms)"
revisa "facturas, cobros y trabajos externos en el libro" "1200/1100/600" \
  "$(ed -c "select (select count(*) from facturas where num like 'VF-%' and contabilizado_en is not null) || '/' ||
                   (select count(*) from cobros where contabilizado_en is not null) || '/' ||
                   (select count(*) from trabajos_externos where descripcion like 'vol ayudante %' and contabilizado_en is not null)")"
revisa "ninguno en error en la bandeja" "0" "$(ed -c "select count(*) from puente_documentos where estado = 'error'")"

echo "== «Reintentar puente» desde la app (authenticated, 8 s)"
t0=$(cronometro)
r="$(ed -c "begin; $APP select format('%s/%s/%s/%s', (x->'sin_cambios_por_tabla'->>'recibos')::int >= $N,
                                      (x->'sin_cambios_por_tabla'->>'facturas')::int >= 1200,
                                      (x->'sin_cambios_por_tabla'->>'cobros')::int >= 1100,
                                      (x->'sin_cambios_por_tabla'->>'trabajos_externos')::int >= 600)
                     from (select fn_puentes_correr() as x) z; commit;" 2>&1)"
t1=$(cronometro)
echo "     (tardó $(ms "$t0" "$t1") ms)"
revisa "terminó sin cortarse, y lo que no cambió (recibos/facturas/cobros/externos) no se volvió a planear" "t/t/t/t" "$(tail -n 1 <<< "$r")"

echo "== Los controles de los puentes desde la app (authenticated, 8 s)"
t0=$(cronometro)
r="$(ed -c "begin; $APP select '[' || coalesce(string_agg(control, ', '), '') || ']' from fn_puentes_verificar() where not ok and control <> 'sin_evaluar'; commit;" 2>&1)"
t1=$(cronometro)
echo "     (tardó $(ms "$t0" "$t1") ms)"
if grep -qi "error" <<< "$r"; then echo "FALLA: fn_puentes_verificar: $r"; malos=1; else revisa "terminó sin cortarse, con los controles en verde" "[]" "$(tail -n 1 <<< "$r")"; fi

echo "== Un recibo corregido después sí se vuelve a pasar"
ed -c "update recibos set total = 999.99 where id = -100001" > /dev/null 2>&1
r="$(ed -c "select count(*) || '/' || count(*) filter (where camino = 'reverso') from asientos where origen_tabla = 'recibos' and origen_id = '-100001'")"
revisa "su puente puso reverso y asiento nuevo" "3/1" "$r"
r="$(ed -c "begin; $APP select (fn_puentes_correr()->>'errores')::int; commit;" 2>&1)"
revisa "otro «reintentar»: sin errores" "0" "$(tail -n 1 <<< "$r")"

[ $malos -eq 0 ] && echo "VOLUMEN c3 ok" || echo "VOLUMEN c3 FALLA"
exit $malos
