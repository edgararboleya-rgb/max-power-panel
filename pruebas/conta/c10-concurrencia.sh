#!/usr/bin/env bash
# =====================================================================
# c10-concurrencia.sh — lo que c10-pruebas.sql no puede probar: dos
# sesiones A LA VEZ con el jornal. c10-pruebas corre en una sola sesión;
# aquí se abren varias de verdad, y cada una confirma.
#
#   ./c10-concurrencia.sh [nombre_bd]      (por defecto c10_concurrencia)
#
# Crea su base con c1 + c2 + c3 + c4 + c6 + c10, una persona de prueba con
# sus horas en ocho semanas y sus pagos (Zelle) en la Bandeja, y:
#   1. EL MISMO PAGO, «ASÍ ES» DESDE DOS PESTAÑAS a la vez (o dos toques):
#      la segunda espera a la primera (el candado de la persona) y, cuando
#      le toca, el pago ya está repartido: MX008, limpio. Un reparto, un
#      asiento, las horas aprobadas una vez.
#   2. DOS PAGOS DE LA MISMA SEMANA a la vez (sin decir «es otro pago de las
#      mismas horas»): entra uno; el otro, cuando le toca, ya no tiene horas
#      sin cubrir: MX008. Ninguna hora en dos repartos.
#   3. «ASÍ ES» MIENTRAS EL AYUDANTE REPORTA UNA HORA de esa semana (cinco
#      semanas, con el reporte llegando antes, durante y después): o el
#      reparto entra con exactamente las horas que Edgar vio (y la nueva
#      queda fuera, sin aprobar, para el siguiente pago), o para con MX011 y
#      no cambia nada. Nunca una hora que Edgar no vio aprobada o repartida.
#      Y la que quedó fuera no pasa callada: es una hora que llegó tarde a
#      una semana ya repartida, y el aviso 35 del jornal la nombra (v2).
#   4. DESHACER EL MISMO REPARTO desde dos pestañas a la vez: uno lo deshace;
#      el otro, MX008. Un solo reverso.
#   5. DAR DE ALTA A LA MISMA PERSONA desde dos pestañas a la vez (una fila;
#      la segunda la ve ya dada de alta), y a DOS personas con el MISMO
#      patrón a la vez (entra una; la otra, MX008).
#   6. VOLVER A PEGAR c10 CON LA PANTALLA LEYENDO (una lectura larga del
#      costo por obra, el pegado medio segundo después): el pegado se rinde
#      con 55P03 («lock timeout») en menos de 3 s, o entra; nadie muere por
#      40P01; sin nadie leyendo, entra.
# Y comprueba: ningún cuadre de v_jornal_control en rojo y, de sus avisos,
# solo el 35 con las horas que llegaron tarde en la parte 3 (una por semana
# que entró); v_margen_control sin rojos, y fn_verificar_cadena en verde.
#
# Cada sesión va como la app por PostgREST: el dueño (o el ayudante), con el
# rol authenticated, los ajustes de ese rol y el tope de la API (8 s).
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c10_concurrencia}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'echo "(La base $BD y $TMP quedan: ./correr.sh --borrar $BD; rm -rf $TMP)"' EXIT
else
  trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

# La persona de prueba, otra para el patrón repetido, cuatro obras, ocho
# semanas de horas (dos reportes por semana, lunes y martes) a partir del
# lunes 5-oct-2026, y un pago por semana (más uno repetido para la 2).
cat > "$TMP/montar.sql" <<'SQL'
insert into auth.users (id, email) values
  ('00000000-0000-4000-a000-0000000cc001', 'c10-conc-1@c10-pruebas.invalid'),
  ('00000000-0000-4000-a000-0000000cc002', 'c10-conc-2@c10-pruebas.invalid'),
  ('00000000-0000-4000-a000-0000000cc003', 'c10-conc-3@c10-pruebas.invalid');
insert into perfiles (id, nombre, rol, activo) values
  ('00000000-0000-4000-a000-0000000cc001', 'Zzana C10 CONCURRENCIA', 'campo', true),
  ('00000000-0000-4000-a000-0000000cc002', 'Zzbeto C10 CONCURRENCIA', 'campo', true),
  ('00000000-0000-4000-a000-0000000cc003', 'Zzcaro C10 CONCURRENCIA', 'campo', true);
insert into costos_equipo (usuario_id, costo_hora) values ('00000000-0000-4000-a000-0000000cc001', 25);
insert into proyectos (id, tipo, nombre, estado) values
  ('c10-conc-a', 'comercial', 'C10 CONC Obra A', 'ejecucion'), ('c10-conc-b', 'residencial', 'C10 CONC Obra B', 'ejecucion'),
  ('c10-conc-c', 'servicio', 'C10 CONC Obra C', 'ejecucion'), ('c10-conc-d', 'servicio', 'C10 CONC Obra D', 'completado');
insert into horas (fecha, usuario_id, proyecto_id, horas, notas)
select date '2026-10-05' + 7 * (w - 1) + d, '00000000-0000-4000-a000-0000000cc001',
       (array['c10-conc-a', 'c10-conc-b', 'c10-conc-c', 'c10-conc-d'])[1 + (w + d) % 4], 8 - d * 2.5, 'c10-concurrencia'
  from generate_series(1, 8) w cross join generate_series(0, 1) d;
select set_config('request.jwt.claims', json_build_object('sub', (select id from perfiles where rol = 'dueno' order by creado limit 1), 'role', 'authenticated')::text, false);
select fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c10-concurrencia',
  'filas', (select jsonb_agg(jsonb_build_object('id', 'c10-conc-' || w, 'fecha', (date '2026-10-12' + 7 * (w - 1))::text,
                                                'plaid_monto', (330 + w)::text || '.25',
                                                'descripcion', 'Zelle payment to C10 CONC ZZANA ' || (7000 + w), 'tipo', 'DEBIT', 'pendiente', false))
              from generate_series(1, 4) w)
           || jsonb_build_array(jsonb_build_object('id', 'c10-conc-2b', 'fecha', '2026-10-20', 'plaid_monto', '120.75',
                                                   'descripcion', 'Zelle payment to C10 CONC ZZANA 7902', 'tipo', 'DEBIT', 'pendiente', false))));
select count(fn_banco_casar(m.id)) from movimientos_banco m where m.id_externo like 'c10-conc-%';
select fn_jornal_persona('{"usuario_id": "00000000-0000-4000-a000-0000000cc001", "patron": "\\mCONC ZZANA\\M"}')->>'nota_alta';
select set_config('request.jwt.claims', '', false);
SQL

echo "== Base $BD: c1 + c2 + c3 + c4 + c6 + c10 y lo de este script"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$DOCS/c10-costo-obra.sql" "$TMP/montar.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' order by creado limit 1")"
P1='00000000-0000-4000-a000-0000000cc001'
# Como la app por PostgREST: con el rol authenticated, los ajustes de ese
# rol (el jit = off de c4) y el tope de la API (8 s). app <quién>.
app() {
  echo "select set_config('request.jwt.claims', '{\"sub\":\"$1\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"
}
mov()   { ed -c "select id from movimientos_banco where id_externo = 'c10-conc-$1'"; }
lunes() { ed -c "select (date '2026-10-05' + 7 * ($1 - 1))::text"; }
visto() { ed -c "select fn_jornal_propuesta('$1', '$2', ('$2'::date + 6))->>'visto'"; }   # visto <movimiento> <lunes>
# aplicar <salida> <movimiento> <lunes> <visto> [pausa con el candado tomado]
aplicar() {
  ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO ' || (fn_jornal_aplicar('$2', '$3', ('$3'::date + 6), '$4')->>'estado'); select pg_sleep(${5:-0}); commit;" > "$1" 2>&1
}

echo
echo "== 1. El mismo pago, «Así es» desde dos pestañas a la vez"
M1="$(mov 1)"; L1="$(lunes 1)"; V1="$(visto "$M1" "$L1")"
aplicar "$TMP/1a.out" "$M1" "$L1" "$V1" 0.6 &
sleep 0.15
aplicar "$TMP/1b.out" "$M1" "$L1" "$V1" 0 &
wait
revisa "una entra" "1" "$(cat "$TMP"/1a.out "$TMP"/1b.out | grep -c 'RESULTADO aplicado')"
revisa "la otra, MX008 (ya está repartido)" "1" "$(cat "$TMP"/1a.out "$TMP"/1b.out | grep -c 'MX008: Este pago ya está repartido')"
revisa "un reparto, un asiento, el pago casado, 2 horas aprobadas una vez" "1|1|casado|2|2" \
  "$(ed -c "select format('%s|%s|%s|%s|%s', (select count(*) from jornal_repartos where movimiento_id = '$M1'),
                          (select count(*) from asientos where origen_tabla = 'movimientos_banco' and origen_id = '$M1'),
                          (select estado from movimientos_banco where id = '$M1'),
                          (select count(*) from horas where usuario_id = '$P1' and fecha between '$L1'::date and '$L1'::date + 6 and aprobado_el is not null),
                          (select count(*) from horas_aprobaciones a join horas h on h.id = a.horas_id where h.usuario_id = '$P1' and h.fecha between '$L1'::date and '$L1'::date + 6 and a.accion = 'aprobada'))")"

echo
echo "== 2. Dos pagos de la misma semana a la vez"
M2="$(mov 2)"; M2B="$(mov 2b)"; L2="$(lunes 2)"; V2="$(visto "$M2" "$L2")"; V2B="$(visto "$M2B" "$L2")"
aplicar "$TMP/2a.out" "$M2" "$L2" "$V2" 0.6 &
sleep 0.15
aplicar "$TMP/2b.out" "$M2B" "$L2" "$V2B" 0 &
wait
revisa "entra uno" "1" "$(cat "$TMP"/2a.out "$TMP"/2b.out | grep -c 'RESULTADO aplicado')"
revisa "el otro, MX008 (sus horas ya entraron en otro reparto)" "1" "$(cat "$TMP"/2a.out "$TMP"/2b.out | grep -c 'MX008: .*ya entraron en otro reparto')"
revisa "ninguna hora en dos repartos" "0" "$(ed -c "select count(*) from (select horas_id from jornal_reparto_horas rh join jornal_repartos r on r.id = rh.reparto_id where r.estado = 'aplicado' group by 1 having count(*) > 1) x")"

echo
echo "== 3. «Así es» mientras el ayudante reporta una hora de esa semana (5 semanas)"
ed -c "select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\"}', false); select fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c10-concurrencia · 3', 'filas', (select jsonb_agg(jsonb_build_object('id', 'c10-conc-3-' || w, 'fecha', (date '2026-10-12' + 7 * (w - 1))::text, 'plaid_monto', (410 + w)::text || '.00', 'descripcion', 'Zelle payment to C10 CONC ZZANA ' || (7300 + w), 'tipo', 'DEBIT', 'pendiente', false)) from generate_series(4, 8) w))); select count(fn_banco_casar(m.id)) from movimientos_banco m where m.id_externo like 'c10-conc-3-%';" > /dev/null
entro=0; paro=0; raro=0
for w in 4 5 6 7 8; do
  M="$(mov "3-$w")"; L="$(lunes "$w")"; V="$(visto "$M" "$L")"
  # el reporte del ayudante llega antes (0 s), a la vez (0,02 a 0,06 s) o después de que Edgar toque
  ( sleep "0.0$(( (w - 4) * 2 ))"; ed -c "begin; $(app "$P1") insert into horas (fecha, usuario_id, proyecto_id, horas, notas) values ('$L'::date + 3, '$P1', 'c10-conc-a', 1.5, 'c10-concurrencia: llega tarde'); commit;" > "$TMP/3h-$w.out" 2>&1 ) &
  aplicar "$TMP/3a-$w.out" "$M" "$L" "$V" 0 &
  wait
  if grep -q 'RESULTADO aplicado' "$TMP/3a-$w.out"; then
    entro=$((entro + 1))
    # entró: con las DOS horas que Edgar vio, aprobadas; la nueva, fuera y sin aprobar
    r="$(ed -c "select format('%s|%s|%s', (select count(*) from jornal_reparto_horas rh join jornal_repartos r on r.id = rh.reparto_id where r.movimiento_id = '$M'),
                              (select count(*) from horas where usuario_id = '$P1' and fecha between '$L'::date and '$L'::date + 6 and aprobado_el is not null),
                              (select count(*) from horas h where h.usuario_id = '$P1' and h.fecha = '$L'::date + 3 and h.aprobado_el is null
                                  and not exists (select 1 from jornal_reparto_horas rh where rh.horas_id = h.id)))")"
    [ "$r" = "2|2|1" ] || { raro=$((raro + 1)); echo "     semana $w: entró, pero quedó $r (se esperaba 2|2|1)"; }
  elif grep -q 'MX011' "$TMP/3a-$w.out"; then
    paro=$((paro + 1))
    # paró: nada cambió (el pago sigue en la Bandeja, ninguna hora aprobada, ningún reparto)
    r="$(ed -c "select format('%s|%s|%s', (select estado from movimientos_banco where id = '$M'), (select count(*) from jornal_repartos where movimiento_id = '$M'),
                              (select count(*) from horas where usuario_id = '$P1' and fecha between '$L'::date and '$L'::date + 6 and aprobado_el is not null))")"
    [ "$r" = "pendiente|0|0" ] || { raro=$((raro + 1)); echo "     semana $w: paró con MX011, pero quedó $r (se esperaba pendiente|0|0)"; }
  else
    raro=$((raro + 1)); echo "     semana $w: ni entró ni MX011:"; tail -n 3 "$TMP/3a-$w.out"
  fi
  grep -q 'ERROR' "$TMP/3h-$w.out" && { raro=$((raro + 1)); echo "     semana $w: el reporte del ayudante falló:"; tail -n 2 "$TMP/3h-$w.out"; }
done
echo "     ($entro entraron con lo que Edgar vio, $paro pararon con MX011)"
revisa "cinco semanas: o entra con lo que vio, o MX011 y nada cambia" "5|0" "$((entro + paro))|$raro"

echo
echo "== 4. Deshacer el mismo reparto desde dos pestañas a la vez"
R1="$(ed -c "select id from jornal_repartos where movimiento_id = '$M1'")"
for i in a b; do
  ( ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO ' || (fn_jornal_deshacer('$R1', 'c10-concurrencia: desde la pestaña $i')->>'estado'); select pg_sleep(0.4); commit;" > "$TMP/4$i.out" 2>&1 ) &
  sleep 0.1
done
wait
revisa "uno lo deshace" "1" "$(cat "$TMP"/4a.out "$TMP"/4b.out | grep -c 'RESULTADO deshecho')"
revisa "el otro, MX008 (ya estaba deshecho)" "1" "$(cat "$TMP"/4a.out "$TMP"/4b.out | grep -c 'MX008: Ese reparto ya estaba deshecho')"
revisa "un solo reverso, y el pago otra vez en la Bandeja" "1|pendiente" \
  "$(ed -c "select format('%s|%s', (select count(*) from asientos x join jornal_repartos r on x.reversa_a = r.asiento_id where r.id = '$R1'), (select estado from movimientos_banco where id = '$M1'))")"

echo
echo "== 5. Dar de alta a la vez: la misma persona desde dos pestañas, y dos personas con el mismo patrón"
for i in a b; do
  ( ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO nueva=' || (fn_jornal_persona('{\"usuario_id\": \"00000000-0000-4000-a000-0000000cc002\", \"patron\": \"\\\\mCONC ZZBETO\\\\M\"}')->>'nueva'); select pg_sleep(0.4); commit;" > "$TMP/5$i.out" 2>&1 ) &
  sleep 0.1
done
wait
revisa "la misma persona: una la da de alta y la otra la ve ya dada de alta" "1|1|1" \
  "$(cat "$TMP"/5a.out "$TMP"/5b.out | grep -c 'RESULTADO nueva=true')|$(cat "$TMP"/5a.out "$TMP"/5b.out | grep -c 'RESULTADO nueva=false')|$(ed -c "select count(*) from jornal_personas where usuario_id = '00000000-0000-4000-a000-0000000cc002'")"
ed -c "select set_config('mx_jornal.escribe', 'jornal_personas', false); delete from jornal_personas where usuario_id = '00000000-0000-4000-a000-0000000cc002';" > /dev/null
for u in 2 3; do
  ( ed -v ON_ERROR_STOP=1 -c "begin; $(app "$DUENO") select 'RESULTADO alta ' || (fn_jornal_persona('{\"usuario_id\": \"00000000-0000-4000-a000-0000000cc00$u\", \"patron\": \"\\\\mCONC ZZMISMO\\\\M\"}')->>'nombre'); select pg_sleep(0.4); commit;" > "$TMP/5p$u.out" 2>&1 ) &
  sleep 0.1
done
wait
revisa "dos personas con el mismo patrón: entra una; la otra, MX008" "1|1|1" \
  "$(cat "$TMP"/5p2.out "$TMP"/5p3.out | grep -c 'RESULTADO alta')|$(cat "$TMP"/5p2.out "$TMP"/5p3.out | grep -c 'MX008: Ese patrón')|$(ed -c "select count(*) from jornal_personas where patron = '\mCONC ZZMISMO\M'")"

echo
echo "== 6. Volver a pegar c10 con la pantalla leyendo"
# una lectura larga del dueño (el costo por obra, y la transacción abierta 3 s), y el pegado medio segundo después
( ed -c "begin; $(app "$DUENO") select count(*) from v_margen_obra; select count(*) from v_jornal_repartos; select pg_sleep(3); commit;" > "$TMP/6l.out" 2>&1 ) &
sleep 0.5
t0=$(date +%s.%N)
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$DOCS/c10-costo-obra.sql" > "$TMP/6p.out" 2>&1
rc=$?
t1=$(date +%s.%N)
wait
seg="$(echo "$t1 - $t0" | bc)"
if grep -q '55P03\|lock timeout\|canceling statement due to lock timeout' "$TMP/6p.out"; then como="se rindió con 55P03"; elif [ $rc -eq 0 ]; then como="entró"; else como="OTRO error"; tail -n 3 "$TMP/6p.out"; fi
echo "     (el pegado $como en $seg s)"
revisa "el pegado se rinde (55P03) o entra, en menos de 3 s" "1" "$( { [ "$como" != "OTRO error" ] && [ "$(echo "$seg < 3" | bc)" = "1" ]; } && echo 1 || echo 0)"
revisa "nadie muere por un bloqueo mortal (40P01), y la lectura termina" "0|0" "$(cat "$TMP"/6p.out "$TMP"/6l.out | grep -c '40P01\|deadlock')|$(grep -c 'ERROR' "$TMP/6l.out")"
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" -f "$DOCS/c10-costo-obra.sql" > "$TMP/6p2.out" 2>&1
revisa "sin nadie leyendo, entra" "0" "$?"

echo
echo "== Al final"
revisa "v_jornal_control: ningún cuadre en rojo" "0" "$(ed -c "select count(*) from v_jornal_control where not ok and nivel = 'cuadre'")"
# La hora que el ayudante reportó mientras Edgar aceptaba (parte 3) quedó
# fuera de su reparto, dentro de sus fechas: llegó tarde a una semana ya
# repartida. El aviso 35 las nombra —una por cada semana que entró— y es el
# único en rojo (se arregla deshaciendo y repitiendo ese reparto, o
# repartiéndolas con el pago que las pague).
revisa "de los avisos, solo el 35, con las horas que llegaron tarde: una por cada semana que entró en la parte 3" \
  "$([ "$entro" -gt 0 ] && echo 35)|$entro" \
  "$(ed -c "select format('%s|%s', coalesce((select string_agg(orden::text, ',' order by orden) from v_jornal_control where not ok), ''), (select count(*) from fn_jornal_tardias()))")"
revisa "v_margen_control sin rojos" "0" "$(ed -c "select count(*) from v_margen_control where not ok")"
revisa "la cadena del libro, sin rojos (los permisos también)" "0" "$(ed -c "select count(*) from fn_verificar_cadena() where not ok")"
revisa "cada reparto aplicado, con las horas que tenía su huella" "0" \
  "$(ed -c "select count(*) from jornal_repartos r where r.estado = 'aplicado' and (select count(*) from jornal_reparto_horas rh where rh.reparto_id = r.id) <> 2")"

echo
if [ $malos -eq 0 ]; then echo "c10-concurrencia: todo bien"; else echo "c10-concurrencia: ALGO FALLA"; fi
exit $malos
