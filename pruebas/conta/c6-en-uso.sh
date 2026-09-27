#!/usr/bin/env bash
# =====================================================================
# c6-en-uso.sh — las cuatro suites con el banco YA EN USO, como en
# producción después de «Después de c6» (README): lo que c2-, c3-, c4- y
# c6-pruebas no pueden probar en una base limpia, porque pasa con datos
# de verdad que ellas no ponen.
#
#   ./c6-en-uso.sh [nombre_bd]      (por defecto c6_en_uso)
#
# Crea su base con c1 + c2 + c3 + c4 + c6 y los puentes corridos (como el
# paso 6), y hace lo que Edgar hará en octubre, cada cosa en su
# transacción (una pestaña del SQL Editor, como editor_sql):
#   1. La póliza que venía de QuickBooks, con lo que dejó en 1410 al
#      30-sep (fn_prepagado_guardar con su saldo_corte; «Después de c6»,
#      paso 1).
#   2. La nómina de octubre del proveedor anterior, con su journal
#      (importar el movimiento, casar y fn_banco_nomina; paso 3).
#   3. Un ticket de verdad de CED, a cuenta, de la segunda obra, subido en
#      octubre, con la apertura todavía sin postear (la balanza de
#      QuickBooks al 30-sep suele cerrarse ya entrado octubre).
# Y después las cuatro suites, en ese orden y cada una en su sesión (los
# pasos 8 a 11): ninguna en rojo. Antes de la ronda 2 de c6: c3-pruebas
# 113/119 (las seis del devengo, MX008 por el journal de octubre),
# c6-pruebas con la 46 en rojo (sumaba la amortización de la póliza de
# verdad) y c4-pruebas con la 53 en rojo (el 5100 de la segunda obra).
# Y NOVIEMBRE EN USO con octubre abierto (la marcha en paralelo; la ronda 3
# de c6): la primera nómina semanal de noviembre con su journal, y octubre
# y noviembre amortizados. c3-pruebas y c6-pruebas otra vez: ninguna en
# rojo. Antes, c3-pruebas 113/120 (el mes del devengo pasaba del tope de
# fecha de c2: MX002) y c6-pruebas con la 22 y la 46 en rojo (amortizar
# octubre con noviembre ya amortizado: MX008); ahora salen «omitida» y
# dicen por qué.
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c6_en_uso}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'echo "(La base $BD queda creada: ./correr.sh --borrar $BD)"; rm -rf "$TMP"' EXIT
else
  trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

ed() { PGPASSWORD=editor_sql psql -X -q -At -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

# Pestaña 1: la póliza de QuickBooks, con su saldo al 30-sep.
cat > "$TMP/p1-poliza.sql" <<'SQL'
select fn_prepagado_guardar('{"descripcion": "GL 2026-2027 (Progressive)", "tipo": "seguro", "cuenta_gasto": "6200",
                              "monto": "4800.00", "desde": "2026-08-01", "hasta": "2027-07-31", "saldo_corte": "4000.00"}') ->> 'id';
SQL
# Pestaña 2: la nómina de octubre del proveedor anterior, con su journal.
cat > "$TMP/p2-nomina.sql" <<'SQL'
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nomina-oct.csv", "filas": [
  {"fecha": "2026-10-09", "monto": "-4212.50", "descripcion": "GUSTO PAYROLL", "tipo": "DEBIT"}]}') ->> 'filas_nuevas';
select fn_banco_casar_todo('1010') -> 'por_motivo';
select fn_banco_nomina(movimiento_id, '[{"cuenta": "5000", "monto": "3900.00", "proyecto_id": "casa-perez-k3m9", "memo": "Sueldos 28-sep a 4-oct"},
                                        {"cuenta": "5015", "monto": "312.50", "memo": "Impuestos patronales"}]') ->> 'estado'
  from v_banco_bandeja where monto = -4212.50;
SQL
# Pestaña 3: las reglas de los tickets y un ticket de verdad de CED, a
# cuenta, de la segunda obra (la Oficina NCH), subido en octubre.
cat > "$TMP/p3-ticket.sql" <<'SQL'
select fn_mapeo_categoria('material', '5100') ->> 'cuenta';
select fn_mapeo_metodo_pago('cuenta_proveedor', 'cuenta_proveedor') ->> 'forma';
select fn_mapeo_tipo_proyecto('comercial', '4020') ->> 'cuenta';
select fn_proveedor_alta('CED', 'Net 30', array['Consolidated Electrical Distributors']);
insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, num_recibo, metodo_pago)
values ('oficina-nch-7xq2', 'recibos/ced-1007.jpg', 1245.60, 'CED', 'leido', '00000000-0000-4000-a000-000000000002',
        '2026-10-07 09:00-04', '2026-10-07', 'material', 'S123456', 'cuenta_proveedor');
SQL

echo "== Base $BD: c1 + c2 + c3 + c4 + c6, los puentes corridos y octubre en uso (la póliza, la nómina, un ticket de CED)"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$DIR/05-puentes-correr.sql" \
  "$TMP/p1-poliza.sql" "$TMP/p2-nomina.sql" "$TMP/p3-ticket.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

revisa "la póliza de QuickBooks, guardada con su saldo al 30-sep" "1" \
  "$(ed -c "select count(*) from prepagados where descripcion = 'GL 2026-2027 (Progressive)' and saldo_corte = 4000.00")"
revisa "la nómina de octubre, en el libro con su journal (casado)" "1:casado" \
  "$(ed -c "select count(*) || ':' || min(m.estado) from movimientos_banco m join asientos a on a.origen_tabla = 'nomina_proveedor' and a.origen_id = m.id::text where m.monto = -4212.50")"
revisa "el ticket de CED de la segunda obra, en el libro (5100 de oficina-nch-7xq2)" "1245.60" \
  "$(ed -c "select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id where a.origen_tabla = 'recibos' and l.cuenta = '5100' and l.proyecto_id = 'oficina-nch-7xq2'")"
revisa "la apertura, todavía sin postear" "0" "$(ed -c "select count(*) from asientos where tipo = 'apertura'")"

echo "== Las cuatro suites encima (pasos 8 a 11), cada una en su sesión"
for s in c2 c3 c4 c6; do
  i=$(date +%s.%N)
  PGOPTIONS='-c client_min_messages=warning' PGPASSWORD=editor_sql psql -X -q -1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" \
    -U editor_sql -d "$BD" -v ON_ERROR_STOP=1 -c '\o /dev/null' -f "$DOCS/$s-pruebas.sql" -c '\o' \
    -At -c "select format('PRUEBAS total=%s ok=%s fallan=%s omitidas=%s', count(*), count(*) filter (where ok),
                          count(*) filter (where not ok), count(*) filter (where ok is null)) from _pruebas" \
    -c "select n || '|' || case when ok then 'ok' when not ok then 'FALLA' else 'omitida' end || '|' || prueba || '|' || left(obtenido, 200)
          from _pruebas where ok is distinct from true order by n" > "$TMP/$s.out" 2>&1
  rc=$?
  f=$(date +%s.%N)
  echo "     $s-pruebas: $(python3 -c "print(round($f - $i, 1))") s · $(grep '^PRUEBAS' "$TMP/$s.out" || echo "no terminó (psql $rc)")"
  grep -E '^[0-9]+\|' "$TMP/$s.out" | sed 's/^/     /'
  [ $rc -eq 0 ] || { tail -n 5 "$TMP/$s.out"; }
  revisa "$s-pruebas corrió entero" "0" "$rc"
  revisa "$s-pruebas: nada en rojo con el banco en uso" "0" "$(sed -n 's/^PRUEBAS .* fallan=\([0-9]*\) .*/\1/p' "$TMP/$s.out")"
done
# Las omitidas por el mes del devengo: con la nómina solo en octubre, las
# seis del devengo de c3 corren en noviembre (no salen omitidas).
revisa "c3-pruebas: las seis del devengo corren (en el primer mes sin journal)" "ninguna" \
  "$(grep -E '^(28|57|67|74|77|99)\|omitida' "$TMP/c3.out" | cut -d'|' -f1 | paste -sd, - | sed 's/^$/ninguna/')"

# NOVIEMBRE EN USO, con octubre abierto: la primera nómina semanal de
# noviembre (el viernes 6) con su journal, y la amortización de octubre y
# de noviembre (Edgar amortiza cada mes antes de cerrarlo).
cat > "$TMP/p4-noviembre.sql" <<'SQL'
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nomina-nov.csv", "filas": [
  {"fecha": "2026-11-06", "monto": "-4212.50", "descripcion": "GUSTO PAYROLL", "tipo": "DEBIT"}]}') ->> 'filas_nuevas';
select fn_banco_casar_todo('1010') -> 'por_motivo';
select fn_banco_nomina(movimiento_id, '[{"cuenta": "5000", "monto": "3900.00", "proyecto_id": "casa-perez-k3m9", "memo": "Sueldos 26-oct a 1-nov"},
                                        {"cuenta": "5015", "monto": "312.50", "memo": "Impuestos patronales"}]') ->> 'estado'
  from v_banco_bandeja where monto = -4212.50 and fecha = '2026-11-06';
select fn_prepagados_amortizar('2026-10') -> 'asientos';
select fn_prepagados_amortizar('2026-11') -> 'asientos';
SQL
echo "== Noviembre en uso con octubre abierto: la primera nómina semanal de noviembre y octubre y noviembre amortizados"
PGPASSWORD=editor_sql psql -X -q -1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -v ON_ERROR_STOP=1 \
  -f "$TMP/p4-noviembre.sql" > "$TMP/p4.out" 2>&1 || { tail -n 20 "$TMP/p4.out"; echo "FALLÓ noviembre" >&2; exit 2; }
revisa "las nóminas de octubre y noviembre, en el libro con su journal" "2" \
  "$(ed -c "select count(*) from asientos where origen_tabla = 'nomina_proveedor'")"
revisa "octubre y noviembre amortizados, con octubre abierto" "2026-10,2026-11:abierto" \
  "$(ed -c "select string_agg(distinct a.periodo, ',' order by a.periodo) || ':' || (select estado from periodos where periodo = '2026-10') from prepagados_amortizaciones a where a.vigente")"
for s in c3 c6; do
  i=$(date +%s.%N)
  PGOPTIONS='-c client_min_messages=warning' PGPASSWORD=editor_sql psql -X -q -1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" \
    -U editor_sql -d "$BD" -v ON_ERROR_STOP=1 -c '\o /dev/null' -f "$DOCS/$s-pruebas.sql" -c '\o' \
    -At -c "select format('PRUEBAS total=%s ok=%s fallan=%s omitidas=%s', count(*), count(*) filter (where ok),
                          count(*) filter (where not ok), count(*) filter (where ok is null)) from _pruebas" \
    -c "select n || '|' || case when ok then 'ok' when not ok then 'FALLA' else 'omitida' end || '|' || prueba || '|' || left(obtenido, 200)
          from _pruebas where ok is distinct from true order by n" > "$TMP/$s-nov.out" 2>&1
  rc=$?
  f=$(date +%s.%N)
  echo "     $s-pruebas (noviembre): $(python3 -c "print(round($f - $i, 1))") s · $(grep '^PRUEBAS' "$TMP/$s-nov.out" || echo "no terminó (psql $rc)")"
  grep -E '^[0-9]+\|' "$TMP/$s-nov.out" | sed 's/^/     /'
  [ $rc -eq 0 ] || { tail -n 5 "$TMP/$s-nov.out"; }
  revisa "$s-pruebas corrió entero (noviembre)" "0" "$rc"
  revisa "$s-pruebas: nada en rojo con noviembre en uso y octubre abierto" "0" \
    "$(sed -n 's/^PRUEBAS .* fallan=\([0-9]*\) .*/\1/p' "$TMP/$s-nov.out")"
done
# Las del devengo, omitidas por el tope de fecha (el primer mes sin journal
# es diciembre, y su último día pasa del tope de c2); las de amortizar
# octubre, omitidas por noviembre ya amortizado.
revisa "c3-pruebas: las del devengo salen «omitida» por el tope de fecha" "28,57,67,74,77,99,120" \
  "$(grep -E '^[0-9]+\|omitida\|.*tope de fecha' "$TMP/c3-nov.out" | cut -d'|' -f1 | paste -sd, -)"
revisa "c6-pruebas: las que amortizan octubre salen «omitida» (noviembre ya amortizado)" "22,46,88" \
  "$(grep -E '^[0-9]+\|omitida\|.*ya está amortizado' "$TMP/c6-nov.out" | cut -d'|' -f1 | paste -sd, -)"

[ $malos -eq 0 ] && echo "EN USO c6 ok" || echo "EN USO c6 FALLA"
exit $malos
