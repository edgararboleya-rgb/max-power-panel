#!/usr/bin/env bash
# =====================================================================
# c3-pegado.sh — lo que c3-pruebas.sql no puede probar porque pasa AL
# PEGAR c3-puentes.sql otra vez, con el libro ya puesto y las reglas ya
# tocadas por Edgar:
#   1. c3 pegado dos veces seguidas: sin error, y los controles del libro
#      y de los puentes en true.
#   2. Edgar retiró una cuenta que un valor de arranque usaba (la 5600
#      Flete: apuntó flete, freight y envio a la 5500 y la inactivó, como
#      dice c1: sin saldo) y le dio a un papel la cuenta que otro tenía de
#      arranque (reembolso_dueno a una 2905 nueva y reembolso_empleado a
#      la 2900). Volver a pegar c3 no se cae (antes la guarda de las
#      reglas juzgaba los valores de arranque ANTES de que el «on conflict
#      do nothing» los saltara: MX004 y no se pegaba nada) y lo que Edgar
#      puso se queda.
#   3. Una base que ya tenía dos recibos con la MISMA foto antes de c3
#      (como pudo dejarlos la app de antes): el primer pegado no crea
#      recibos_ruta_unica (lo dice y el control duplicados los enseña);
#      Edgar anula el repetido, vuelve a pegar, y el índice YA existe
#      (los anulados no cuentan: antes no se creaba nunca). Con él, dos
#      subidas a la vez con la misma foto: entra una, la otra no.
#
#   ./c3-pegado.sh [nombre_bd]      (por defecto c3_pegado)
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c3_pegado}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

malos=0
bien()  { echo "ok   $*"; }
falla() { echo "FALLA: $*"; malos=1; }

controles() {  # los controles en false (fuera de sin_evaluar: los papeles sembrados esperan su backfill)
  ed -c "select coalesce(string_agg(control, ', '), '') from (
           select 'libro · ' || control as control from fn_verificar_cadena() where not ok
           union all
           select 'puentes · ' || control from fn_puentes_verificar() where not ok and control <> 'sin_evaluar') x"
}

# ---------------------------------------------------------------------
echo "== 1. c3 pegado dos veces seguidas"
"$DIR/correr.sh" "$BD" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" > "$TMP/carga.out" 2>&1 \
  || { cat "$TMP/carga.out"; echo "FALLÓ la carga de c1 + c2 + c3" >&2; exit 2; }
r="$(ed -1 -v ON_ERROR_STOP=1 -f "$DOCS/c3-puentes.sql" 2>&1)"; rc=$?
if [ $rc -eq 0 ]; then bien "el segundo pegado entró"; else falla "el segundo pegado se cayó (rc=$rc): $(grep -m1 -i error <<< "$r")"; fi
r="$(controles)"
if [ -z "$r" ]; then bien "los controles del libro y de los puentes en true"; else falla "en false: $r"; fi

# ---------------------------------------------------------------------
echo "== 2. Con una cuenta de arranque retirada y dos papeles que cambiaron de cuenta"
ed -v ON_ERROR_STOP=1 > "$TMP/edgar.out" 2>&1 <<'SQL' || { cat "$TMP/edgar.out"; echo "FALLÓ preparar lo que hizo Edgar" >&2; exit 2; }
-- La 5600 no se usa: sus categorías van a la 5500 y se retira (sin saldo).
select fn_mapeo_categoria('flete', '5500'), fn_mapeo_categoria('freight', '5500'), fn_mapeo_categoria('envio', '5500');
update cuentas set activa = false where codigo = '5600';
-- Lo que Edgar pagó de su bolsillo va a una cuenta nueva, y la 2900 pasa a
-- los reembolsos de los empleados.
insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
values ('2905', 'Préstamo del accionista (gastos pagados)', 'Shareholder loan (paid expenses)', 'pasivo', 'haber', true,
        'prohibida', 'prohibida');
select fn_puentes_cuenta('reembolso_dueno', '2905');
select fn_puentes_cuenta('reembolso_empleado', '2900');
SQL
r="$(ed -1 -v ON_ERROR_STOP=1 -f "$DOCS/c3-puentes.sql" 2>&1)"; rc=$?
if [ $rc -eq 0 ]; then bien "volver a pegar c3 entró"; else falla "volver a pegar c3 se cayó (rc=$rc): $(grep -m1 -i error <<< "$r")"; fi
r="$(ed -c "select string_agg(categoria || '=' || cuenta, ' ' order by categoria) from mapeo_categoria_recibo
             where categoria in ('flete', 'freight', 'envio')")"
if [ "$r" = "envio=5500 flete=5500 freight=5500" ]; then bien "las categorías siguen en la 5500 ($r)"; else falla "las categorías cambiaron: $r"; fi
r="$(ed -c "select string_agg(rol || '=' || cuenta, ' ' order by rol) from puente_cuentas
             where rol in ('reembolso_dueno', 'reembolso_empleado')")"
if [ "$r" = "reembolso_dueno=2905 reembolso_empleado=2900" ]; then bien "los papeles siguen con su cuenta ($r)"; else falla "los papeles cambiaron: $r"; fi
r="$(ed -c "select activa from cuentas where codigo = '5600'")"
if [ "$r" = "f" ]; then bien "la 5600 sigue retirada"; else falla "la 5600 volvió a estar activa ($r)"; fi
r="$(controles)"
if [ -z "$r" ]; then bien "los controles del libro y de los puentes en true"; else falla "en false: $r"; fi

# ---------------------------------------------------------------------
echo "== 3. Dos recibos con la misma foto de antes de c3: anular el repetido y volver a pegar"
cat > "$TMP/ruta_doble.sql" <<'SQL'
-- Dos recibos con la misma foto, como pudo dejarlos la app antes de c3.
insert into recibos (id, proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago)
overriding system value values
 (-1101, 'casa-perez-k3m9', 'recibos/g/misma.jpg', 90.00, 'CED', 'leido', '00000000-0000-4000-a000-000000000002',
  timestamptz '2026-10-12 10:00-04', date '2026-10-12', 'material', 'Account'),
 (-1102, 'casa-perez-k3m9', 'recibos/g/misma.jpg', 90.00, 'CED', 'leido', '00000000-0000-4000-a000-000000000002',
  timestamptz '2026-10-12 10:05-04', date '2026-10-12', 'material', 'Account');
SQL
"$DIR/correr.sh" "$BD" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$TMP/ruta_doble.sql" "$DOCS/c3-puentes.sql" \
  > "$TMP/carga3.out" 2>&1 || { cat "$TMP/carga3.out"; echo "FALLÓ la carga del escenario 3" >&2; exit 2; }
if grep -q "no se crea recibos_ruta_unica" "$TMP/carga3.out"; then bien "el primer pegado avisa que no crea el índice"; else falla "el primer pegado no avisó"; fi
r="$(ed -c "select to_regclass('public.recibos_ruta_unica') is null")"
if [ "$r" = "t" ]; then bien "sin el índice mientras haya dos vivos con la misma foto"; else falla "el índice existe con dos vivos ($r)"; fi
ed -c "select fn_recibo_anular(-1102, 'repetido del recibo -1101')" > /dev/null 2>&1 || falla "no se pudo anular el repetido"
r="$(ed -1 -v ON_ERROR_STOP=1 -f "$DOCS/c3-puentes.sql" 2>&1)"; rc=$?
if [ $rc -eq 0 ]; then bien "volver a pegar c3 entró"; else falla "volver a pegar c3 se cayó (rc=$rc): $(grep -m1 -i error <<< "$r")"; fi
r="$(ed -c "select to_regclass('public.recibos_ruta_unica') is not null")"
if [ "$r" = "t" ]; then bien "anulado el repetido, el segundo pegado crea recibos_ruta_unica"; else falla "el índice sigue sin crearse ($r)"; fi
GUS="select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-4000-a000-000000000002\",\"role\":\"authenticated\"}', true); set local role authenticated;"
ed -c "begin; $GUS insert into recibos (proyecto_id, ruta, notas, autor_id) values ('casa-perez-k3m9', 'recibos/casa-perez-k3m9/doble.jpg', 'c3-pegado A', '00000000-0000-4000-a000-000000000002'); select pg_sleep(1.5); commit;" > "$TMP/3a.out" 2>&1 &
sleep 0.4
ed -c "begin; $GUS insert into recibos (proyecto_id, ruta, notas, autor_id) values ('casa-perez-k3m9', 'recibos/casa-perez-k3m9/doble.jpg', 'c3-pegado B', '00000000-0000-4000-a000-000000000002'); commit;" > "$TMP/3b.out" 2>&1 &
wait
r="$(ed -c "select count(*) from recibos where btrim(ruta) = 'recibos/casa-perez-k3m9/doble.jpg'")"
if [ "$r" = "1" ]; then bien "dos subidas a la vez con la misma foto: entró una"; else falla "entraron $r con la misma foto"; fi
if grep -qi "error" "$TMP/3b.out"; then bien "la segunda subida recibió su error ($(grep -o -m1 '23505\|MX003\|42501' "$TMP/3b.out"))"; else falla "la segunda subida no dio error"; fi
r="$(controles)"
if [ -z "$r" ]; then bien "los controles del libro y de los puentes en true"; else falla "en false: $r"; fi

[ $malos -eq 0 ] && echo "PEGADO c3 ok" || echo "PEGADO c3 FALLA"
exit $malos
