#!/usr/bin/env bash
# =====================================================================
# c2-concurrencia.sh — lo que c2-pruebas.sql no puede probar: varias
# sesiones A LA VEZ contra el libro. c2-pruebas corre en una sola sesión;
# aquí se abren varias de verdad.
#
#   ./c2-concurrencia.sh [nombre_bd]      (por defecto c2_concurrencia)
#
# Crea su base con c1 + c2 y un libro con vida (asientos, un reversible,
# un reverso, y la apertura, con su asiento de apertura, y octubre
# cerrados: la apertura va primero), y entonces:
#   1. A postea en noviembre y deja su transacción abierta 3 segundos;
#      B postea en noviembre y C cierra noviembre mientras tanto. B tiene
#      que esperar a A (el candado de la cadena) y C a los dos (el «for
#      share» del período): el cierre no puede dejar fuera un asiento que
#      ya estaba entrando, ni dejar entrar uno después.
#   2. Diez posteos lanzados a la vez en diciembre.
#   3. Una línea que llega TARDE, de otra sesión, a un asiento ya sellado:
#      la sesión A mete a mano (SQL Editor) líneas y cabecera y espera; la
#      B cuelga otra línea del mismo asiento. El trigger de la línea de B
#      no ve la cabecera de A; la guarda que se mira al confirmar (el
#      sello) tiene que tumbar a B con MX003, y el asiento se queda con
#      sus dos líneas, cuadrado.
#   4. Un cierre en REPEATABLE READ (y otro en SERIALIZABLE): la sesión C
#      abre su transacción y lee (toma su foto); la P postea en diciembre
#      y confirma; C intenta cerrar diciembre. Su foto sería la del
#      principio y dejaría fuera el asiento de P: el cierre se rechaza
#      (MX002). Después, en read committed, diciembre cierra con el
#      asiento de P dentro.
# Y comprueba: fn_verificar_cadena todo en true, números del año sin
# huecos ni repetidos, y el hash del cierre de noviembre (y el de
# diciembre) = el hash del último asiento de su mes.
# Así se encontró (23-sep-2026) que las horas del sello y del cierre
# tenían que ser clock_timestamp() con el candado puesto, no now().
#
# La mitad de los posteos entra como la app (el dueño, con el rol
# authenticated, y CONFIRMA con ese rol): las comprobaciones diferidas
# corren al confirmar con el rol de la sesión (así se encontró, el 24-sep,
# que el sello abortaba todo posteo de la app con 42501).
#
# EL RELOJ: un período se cierra cuando ya terminó, y aquí se cierran
# octubre, noviembre y diciembre de 2026. Esta base es de usar y tirar:
# se carga una COPIA de c2-libro.sql en la que «hoy» es, como pronto, el
# 15-ene-2027 (fn_fecha_miami, con greatest), y sus huellas se sellan con
# esa copia. docs/conta/c2-libro.sql no se toca.
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c2_concurrencia}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

cat > "$TMP/vivo.sql" <<'SQL'
do $$
begin
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000001","role":"authenticated"}', true);
  execute 'set local role authenticated';
  perform fn_postear('{"fecha":"2026-10-05","descripcion":"CED, THHN para Pérez","lineas":[{"cuenta":"5100","monto":"245.37","proyecto_id":"casa-perez-k3m9","cost_code":"08-ROUGH"},{"cuenta":"1010","monto":"-245.37"}]}');
  perform fn_postear('{"fecha":"2026-10-12","descripcion":"Factura 1102 NCH","lineas":[{"cuenta":"1110","monto":"3200.50","proyecto_id":"oficina-nch-7xq2"},{"cuenta":"4020","monto":"-3200.50","proyecto_id":"oficina-nch-7xq2","co":"CO-1"}]}');
  perform fn_postear('{"fecha":"2026-10-31","descripcion":"Devengo de horas de octubre (estándar)","reversible":true,"lineas":[{"cuenta":"5000","monto":"228.00","proyecto_id":"casa-perez-k3m9","cost_code":"08-ROUGH"},{"cuenta":"2210","monto":"-228.00"}]}');
  perform fn_postear('{"fecha":"2026-11-03","descripcion":"Renta de noviembre","lineas":[{"cuenta":"6100","monto":"1800.00"},{"cuenta":"1010","monto":"-1800.00"}]}');
  perform fn_reversar((select id from asientos where numero = '2026-000001'), 'Duplicado del ticket CED-88121');
  perform fn_postear('{"tipo":"apertura","fecha":"2026-09-30","descripcion":"Apertura desde la balanza de QuickBooks","documento_ruta":"docs/apertura/balanza-2026-09-30.pdf","lineas":[{"cuenta":"1010","monto":"50000.00"},{"cuenta":"1110","monto":"8000.00"},{"cuenta":"2010","monto":"-6000.00"},{"cuenta":"3900","monto":"-52000.00"}]}');
  perform fn_cerrar_periodo('2026-09-APERTURA');
  perform fn_cerrar_periodo('2026-10');
  -- Sin «reset role»: la transacción CONFIRMA con el rol de la app, como
  -- por la API, y las comprobaciones diferidas corren con él.
end $$;
SQL

# La copia de c2-libro.sql con el reloj en el 15-ene-2027 como pronto.
python3 - "$DOCS/c2-libro.sql" "$TMP/c2-libro.sql" <<'PY2'
import sys
fuente, destino = sys.argv[1], sys.argv[2]
s = open(fuente, encoding='utf-8').read()
viejo = "as $$ select (t at time zone 'America/New_York')::date $$;"
nuevo = "as $$ select greatest((t at time zone 'America/New_York')::date, date '2027-01-15') $$;"
if s.count(viejo) != 1:
    sys.exit("No encontré (una vez) el cuerpo de fn_fecha_miami en c2-libro.sql: revisa este script.")
open(destino, 'w', encoding='utf-8').write(s.replace(viejo, nuevo))
PY2
[ -s "$TMP/c2-libro.sql" ] || { echo "FALLÓ preparar la copia de c2 con el reloj fingido" >&2; exit 2; }

echo "== Base $BD: c1 + c2 + un libro con vida"
"$DIR/correr.sh" "$BD" "$DOCS/c1-plan-de-cuentas.sql" "$TMP/c2-libro.sql" "$TMP/vivo.sql" > "$TMP/carga.out" 2>&1 \
  || { cat "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

POSTEO='{"fecha":"%s","descripcion":"%s","lineas":[{"cuenta":"6100","monto":"%s"},{"cuenta":"1010","monto":"-%s"}]}'
# Como la app: el dueño, con el rol authenticated, y la transacción confirma con él.
APP="select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-4000-a000-000000000001\",\"role\":\"authenticated\"}', true); set local role authenticated;"

echo "== 1. A postea y espera; C cierra noviembre y B postea en noviembre mientras tanto"
# C arranca un poco ANTES que B: si alguien volviera a sellar con now() (la
# hora de inicio de la transacción), el asiento de B parecería posterior al
# cierre aunque entró antes, y el último control lo cantaría.
# Según cómo conceda Postgres los candados, B entra antes del cierre o se
# encuentra noviembre ya cerrado (MX002). Las dos cosas son correctas; lo
# incorrecto sería que B entrara DESPUÉS del cierre.
ed -c "begin; $APP select fn_postear('$(printf "$POSTEO" 2026-11-10 'sesión A (la app)' 10.00 10.00)'); select pg_sleep(3); commit;" > "$TMP/a.out" 2>&1 &
sleep 1
ed -c "select fn_cerrar_periodo('2026-11')->>'estado'" > "$TMP/c.out" 2>&1 &
sleep 0.3
ed -c "select fn_postear('$(printf "$POSTEO" 2026-11-11 'sesión B' 20.00 20.00)')->>'numero'" > "$TMP/b.out" 2>&1 &
wait

echo "== 2. Diez posteos a la vez en diciembre (la mitad, como la app)"
for i in $(seq 1 10); do
  if [ $((i % 2)) -eq 0 ]; then
    ed -c "begin; $APP select fn_postear('$(printf "$POSTEO" 2026-12-10 "ráfaga $i (la app)" 1.00 1.00)')->>'numero'; commit;" > "$TMP/r$i.out" 2>&1 &
  else
    ed -c "select fn_postear('$(printf "$POSTEO" 2026-12-10 "ráfaga $i" 1.00 1.00)')->>'numero'" > "$TMP/r$i.out" 2>&1 &
  fi
done
wait

echo "== 3. Una línea que llega tarde, de otra sesión, a un asiento ya sellado"
LID='00000000-0000-4000-b000-0000000000c1'
ed -c "begin;
       insert into asiento_lineas (asiento_id, orden, cuenta, monto)
       values ('$LID', 1, '6100', 100.00), ('$LID', 2, '1010', -100.00);
       insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                             hash_anterior, hash)
       values ('$LID', '-', 0, 0, 0, '2026-12-05', '-', 'mano', 'Renta de diciembre (a mano)', repeat('0', 64), repeat('0', 64));
       select pg_sleep(3);
       commit;" > "$TMP/l_a.out" 2>&1 &
sleep 1
ed -c "begin;
       insert into asiento_lineas (asiento_id, orden, cuenta, monto) values ('$LID', 3, '6100', 10.00);
       select pg_sleep(4);
       commit;" > "$TMP/l_b.out" 2>&1 &
wait

echo "== 4. Cerrar diciembre en repeatable read y en serializable: se rechaza; en read committed, cierra"
# C toma su foto (lee) y espera; P postea en diciembre y confirma; C intenta
# cerrar. Con la foto del principio, el cierre dejaría fuera el asiento de P.
for nivel in "repeatable read" "serializable"; do
  f="$TMP/cierre-${nivel// /_}.out"
  ed -c "begin isolation level $nivel; select count(*) from asientos; select pg_sleep(2);
         select fn_cerrar_periodo('2026-12')->>'estado'; commit;" > "$f" 2>&1 &
  sleep 0.7
  ed -c "select fn_postear('$(printf "$POSTEO" 2026-12-20 "entra mientras ($nivel)" 5.00 5.00)')->>'numero'" > "$TMP/p-${nivel// /_}.out" 2>&1
  wait
done
ed -c "select fn_cerrar_periodo('2026-12')->>'estado'" > "$TMP/cierre-rc.out" 2>&1

malos=0
if grep -qi error "$TMP"/a.out "$TMP"/c.out "$TMP"/r*.out "$TMP"/p-*.out; then
  echo "FALLA: una sesión dio error:"; grep -i error "$TMP"/a.out "$TMP"/c.out "$TMP"/r*.out "$TMP"/p-*.out; malos=1
fi
for nivel in repeatable_read serializable; do
  if grep -q "MX002" "$TMP/cierre-$nivel.out" && grep -q "read committed" "$TMP/cierre-$nivel.out"; then
    echo "ok   el cierre en ${nivel//_/ } se rechazó (MX002): su foto sería la del principio de la transacción"
  else
    echo "FALLA: el cierre en ${nivel//_/ } no se rechazó:"; cat "$TMP/cierre-$nivel.out"; malos=1
  fi
done
if [ "$(tail -n 1 "$TMP/cierre-rc.out")" = "cerrado" ]; then
  echo "ok   en read committed, diciembre cerró"
else
  echo "FALLA: diciembre no cerró en read committed:"; cat "$TMP/cierre-rc.out"; malos=1
fi
if grep -qi error "$TMP/b.out"; then
  if grep -q "MX002" "$TMP/b.out"; then
    echo "ok   B llegó con noviembre ya cerrado: MX002, no entró"
  else
    echo "FALLA: B dio un error que no es MX002:"; cat "$TMP/b.out"; malos=1
  fi
else
  echo "ok   B entró antes del cierre ($(cat "$TMP/b.out"))"
fi

if grep -qi error "$TMP/l_a.out"; then
  echo "FALLA: la sesión A (líneas y cabecera a mano) dio error:"; cat "$TMP/l_a.out"; malos=1
fi
if grep -q "MX003" "$TMP/l_b.out"; then
  echo "ok   la línea tardía de la sesión B no confirmó: MX003 al confirmar"
else
  echo "FALLA: la línea tardía de la sesión B no dio MX003:"; cat "$TMP/l_b.out"; malos=1
fi
tardia="$(ed -c "select format('lineas=%s suma=%s', count(*), coalesce(sum(monto), 0)) from asiento_lineas where asiento_id = '$LID'")"
if [ "$tardia" = "lineas=2 suma=0.00" ]; then echo "ok   el asiento sellado se quedó con sus dos líneas, cuadrado ($tardia)"; else echo "FALLA: el asiento sellado quedó con $tardia"; malos=1; fi

fallan="$(ed -c "select coalesce(string_agg(control, ', '), '') from fn_verificar_cadena() where not ok")"
if [ -n "$fallan" ]; then echo "FALLA: fn_verificar_cadena en false: $fallan"; malos=1; else echo "ok   fn_verificar_cadena: todos los controles en true"; fi

numeros="$(ed -c "select format('asientos=%s ultimo=%s distintos=%s', count(*), max(secuencia), count(distinct secuencia)) from asientos where anio = 2026")"
sin_hueco="$(ed -c "select count(*) = max(secuencia) and count(distinct secuencia) = count(*) and min(secuencia) = 1 from asientos where anio = 2026")"
if [ "$sin_hueco" = "t" ]; then echo "ok   numeración sin huecos ni repetidos: $numeros"; else echo "FALLA: numeración $numeros"; malos=1; fi

for mes in 2026-11 2026-12; do
  cierre="$(ed -c "select (select cadena_al_cerrar from periodos where periodo = '$mes') = (select hash from asientos where periodo = '$mes' order by cadena_pos desc limit 1)")"
  if [ "$cierre" = "t" ]; then echo "ok   el cierre de $mes guardó el hash de su último asiento"; else echo "FALLA: el hash del cierre de $mes no es el de su último asiento"; malos=1; fi
done
app="$(ed -c "select count(*) from asientos where rol_bd = 'authenticated'")"
if [ "${app:-0}" -ge 10 ]; then echo "ok   $app asientos entraron y confirmaron como la app (rol authenticated)"; else echo "FALLA: solo $app asientos confirmaron como la app"; malos=1; fi

tarde="$(ed -c "select count(*) from asientos a join periodos p on p.periodo = a.periodo where p.estado = 'cerrado' and a.creado_el > p.cerrado_el")"
if [ "$tarde" = "0" ]; then echo "ok   ningún asiento de un período cerrado tiene hora posterior al cierre"; else echo "FALLA: $tarde asientos con hora posterior al cierre de su período"; malos=1; fi

[ $malos -eq 0 ] && echo "CONCURRENCIA ok" || echo "CONCURRENCIA FALLA"
exit $malos
