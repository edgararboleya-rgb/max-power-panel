#!/usr/bin/env bash
# =====================================================================
# c6-concurrencia.sh — lo que c6-pruebas.sql no puede probar: dos
# sesiones A LA VEZ con el banco. c6-pruebas corre en una sola sesión;
# aquí se abren varias de verdad, y cada una confirma.
#
#   ./c6-concurrencia.sh [nombre_bd]      (por defecto c6_concurrencia)
#
# Crea su base con c1 + c2 + c3 + c4 + c6, la tarjeta ····2013 y las
# reglas de los tickets, y:
#   1. EL MISMO ARCHIVO EN DOS SESIONES a la vez (Edgar lo sube dos veces,
#      o desde dos pantallas): la segunda espera a la primera (el candado
#      del archivo, su sha256) y la ve: «ya estaba». Un archivo, sus
#      movimientos una vez.
#   2. DOS ARCHIVOS QUE SE SOLAPAN a la vez (el de la semana y el del
#      mes): el candado de la cuenta los pone en fila; lo repetido entra
#      una vez y el segundo lo cuenta.
#   3. EL MISMO MOVIMIENTO RESUELTO EN DOS SESIONES a la vez (dos
#      pestañas): la segunda espera (el candado del casado) y ya lo
#      encuentra casado (MX008). Un casado vivo, un asiento.
#   4. DOS «CASAR» A LA VEZ: se ponen en fila; ninguna línea del libro
#      queda casada dos veces.
#   5. IMPORTAR Y CASAR MIENTRAS LA APP SUBE TICKETS: cuatro «teléfonos»
#      suben un ticket cada 0,25 s (el dueño, como la app, con la tarjeta
#      ····2013; el puente en immediate y rollback: sin rastro; subidos el
#      15-oct, como en c3-concurrencia: el reloj del banco es de antes del
#      corte, y un recibo subido antes del corte no entra al libro)
#      mientras se importa un estado de cuenta de 400 movimientos y se casa
#      dos veces: ninguna subida cortada ni esperando 8 s, cada ticket con
#      su asiento, nadie muerto por un bloqueo mortal (40P01).
#   6. VOLVER A PEGAR c6 CON LA BANDEJA LEYENDO: el pegado se rinde pronto
#      (55P03, su lock_timeout de medio segundo) en vez de hacer esperar a
#      la app; nadie muere por 40P01; sin nadie leyendo, entra.
# Y comprueba: fn_banco_verificar y fn_verificar_cadena en verde.
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja, y sus archivos de salida).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c6_concurrencia}"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'touch "$TMP/fin" 2>/dev/null; echo "(La base $BD y $TMP quedan: ./correr.sh --borrar $BD; rm -rf $TMP)"' EXIT
else
  trap 'touch "$TMP/fin" 2>/dev/null; "$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

cat > "$TMP/montar.sql" <<'SQL'
-- La tarjeta, las reglas de los tickets y los estados de cuenta de este
-- script (conc.qfx(desde, hasta): los movimientos C<n> de ese tramo).
do $$
begin
  perform fn_tarjeta_alta('2013', '2100-2013', 'Amex Gold');
  perform fn_mapeo_categoria('material', '5100');
  perform fn_mapeo_metodo_pago('credito', 'tarjeta');
  perform fn_mapeo_tipo_proyecto('residencial', '4010');
  perform fn_mapeo_tipo_proyecto('comercial', '4020');
  perform fn_mapeo_tipo_proyecto('servicio', '4030');
end $$;
create schema if not exists conc;
grant usage on schema conc to authenticated;
create or replace function conc.qfx(p_cuenta text, p_desde int, p_hasta int) returns text
language sql immutable as $f$
  select concat_ws(E'\r\n', 'OFXHEADER:100', 'DATA:OFXSGML', 'VERSION:102', '', '<OFX>',
    case when p_cuenta = '1010'
         then '<BANKMSGSRSV1><STMTTRNRS><STMTRS><CURDEF>USD<BANKACCTFROM><BANKID>267084131<ACCTID>000000004392<ACCTTYPE>CHECKING</BANKACCTFROM>'
         else '<CREDITCARDMSGSRSV1><CCSTMTTRNRS><CCSTMTRS><CURDEF>USD<CCACCTFROM><ACCTID>372700000002013</CCACCTFROM>' end,
    '<BANKTRANLIST><DTSTART>20261001<DTEND>20261031',
    (select string_agg(format('<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>%s<TRNAMT>-%s<FITID>C%s<NAME>CONC %s</STMTTRN>',
                              to_char(date '2026-10-01' + (g % 28), 'YYYYMMDD'), (10 + g) || '.' || lpad((g % 100)::text, 2, '0'), g, g),
                       E'\r\n' order by g)
       from generate_series(p_desde, p_hasta) g),
    '</BANKTRANLIST>',
    case when p_cuenta = '1010' then '</STMTRS></STMTTRNRS></BANKMSGSRSV1>' else '</CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1>' end,
    '</OFX>')
$f$;
grant execute on function conc.qfx(text, int, int) to authenticated;
SQL

echo "== Base $BD: c1 + c2 + c3 + c4 + c6 y lo de este script"
"$DIR/correr.sh" "$BD" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
  "$DOCS/c4-estados.sql" "$DOCS/c6-banco.sql" "$TMP/montar.sql" > "$TMP/carga.out" 2>&1 \
  || { tail -n 30 "$TMP/carga.out"; echo "FALLÓ la carga" >&2; exit 2; }

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' order by creado limit 1")"
OBRA="$(ed -c "select id from proyectos order by id limit 1")"
# Como la app por PostgREST: el dueño, con el rol authenticated, los ajustes
# de ese rol (el jit = off de c4) y el tope de la API (8 s).
APP="select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"

echo "== 1. El mismo archivo en dos sesiones a la vez"
ed -c "begin; $APP select 'nuevas=' || (fn_banco_importar_ofx(conc.qfx('1010', 1, 20), '1010', 'a.qfx')->>'filas_nuevas'); select pg_sleep(2); commit;" \
  > "$TMP/1a.out" 2>&1 &
sleep 0.5
inicio=$(date +%s.%N)
ed -c "begin; $APP select 'ya_estaba=' || (fn_banco_importar_ofx(conc.qfx('1010', 1, 20), '1010', 'b.qfx')->>'ya_estaba'); commit;" > "$TMP/1b.out" 2>&1
fin=$(date +%s.%N)
wait
revisa "la primera metió los 20" "nuevas=20" "$(grep '^nuevas=' "$TMP/1a.out")"
revisa "la segunda esperó a la primera" "t" "$(python3 -c "print('t' if $fin - $inicio > 1.0 else 'f')")"
revisa "y la vio: ya estaba" "ya_estaba=true" "$(grep '^ya_estaba=' "$TMP/1b.out")"
revisa "un archivo, 20 movimientos" "1/20" "$(ed -c "select count(*) from archivos_banco")/$(ed -c "select count(*) from movimientos_banco")"

echo "== 2. Dos archivos que se solapan, a la vez"
ed -c "begin; $APP select 'nuevas=' || (fn_banco_importar_ofx(conc.qfx('1010', 21, 40), '1010', 'semana.qfx')->>'filas_nuevas'); select pg_sleep(2); commit;" \
  > "$TMP/2a.out" 2>&1 &
sleep 0.5
ed -c "begin; $APP select 'nuevas=' || (x->>'filas_nuevas') || ' repetidas=' || (x->>'filas_repetidas') from (select fn_banco_importar_ofx(conc.qfx('1010', 31, 50), '1010', 'mes.qfx') as x) y; commit;" \
  > "$TMP/2b.out" 2>&1
wait
revisa "el primero metió los 20 suyos" "nuevas=20" "$(grep '^nuevas=' "$TMP/2a.out")"
revisa "el segundo esperó y contó los 10 repetidos" "nuevas=10 repetidas=10" "$(grep '^nuevas=' "$TMP/2b.out")"
revisa "cada movimiento una vez" "50" "$(ed -c "select count(*) from movimientos_banco")"

echo "== 3. El mismo movimiento resuelto en dos sesiones a la vez"
M="$(ed -c "select id from movimientos_banco where id_externo = 'C7'")"
ed -c "begin; $APP select 'primera=' || (fn_banco_clasificar('$M', '[{\"cuenta\": \"6130\"}]', 'c6-concurrencia')->>'estado'); select pg_sleep(2); commit;" \
  > "$TMP/3a.out" 2>&1 &
sleep 0.5
ed -c "begin; $APP select 'segunda=' || (fn_banco_clasificar('$M', '[{\"cuenta\": \"6130\"}]', 'c6-concurrencia')->>'estado'); commit;" \
  > "$TMP/3b.out" 2>&1
wait
revisa "la primera lo casó" "primera=casado" "$(grep '^primera=' "$TMP/3a.out")"
revisa "la segunda esperó y lo encontró casado (MX008)" "MX008" "$(grep -o 'MX008' "$TMP/3b.out" | head -n 1)"
revisa "un casado vivo y un asiento de ese movimiento" "1/1" \
  "$(ed -c "select count(*) from banco_casados where movimiento_id = '$M' and deshecho_el is null")/$(ed -c "select count(*) from asientos where origen_tabla = 'movimientos_banco' and origen_id = '$M'")"

echo "== 4. Dos «casar» a la vez (con líneas del libro que casan con los movimientos)"
ed -v ON_ERROR_STOP=1 -c "select count(fn_postear(jsonb_build_object('fecha', (date '2026-10-01' + (g % 28))::text,
                            'descripcion', 'c6-concurrencia: gasto ' || g,
                            'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6130', 'monto', ((10 + g) || '.' || lpad((g % 100)::text, 2, '0'))),
                                                        jsonb_build_object('cuenta', '1010', 'monto', '-' || ((10 + g) || '.' || lpad((g % 100)::text, 2, '0')))))))
                          from generate_series(1, 50) g where g <> 7" > /dev/null 2>&1
ed -c "begin; $APP select 'a=' || (fn_banco_casar_todo('1010', null)->>'casados'); commit;" > "$TMP/4a.out" 2>&1 &
ed -c "begin; $APP select 'b=' || (fn_banco_casar_todo(null, null)->>'casados'); commit;" > "$TMP/4b.out" 2>&1 &
wait
revisa "entre los dos casaron los 49 (en fila)" "49" \
  "$(( $(grep -o '^a=[0-9]*' "$TMP/4a.out" | cut -d= -f2) + $(grep -o '^b=[0-9]*' "$TMP/4b.out" | cut -d= -f2) ))"
revisa "ninguna línea del libro casada dos veces" "0" \
  "$(ed -c "select count(*) from (select asiento_id, orden from banco_casado_lineas where vigente group by 1, 2 having count(*) > 1) x")"
revisa "ningún movimiento con dos casados vivos" "0" \
  "$(ed -c "select count(*) from (select movimiento_id from banco_casados where deshecho_el is null group by 1 having count(*) > 1) x")"

echo "== 5. Importar y casar mientras cuatro teléfonos suben tickets (uno cada 0,25 s cada uno)"
rm -f "$TMP/fin"; : > "$TMP/telefono.log"
pids=""
for tel in 1 2 3 4; do
  (
    i=0
    while [ ! -f "$TMP/fin" ]; do
      i=$((i + 1)); t0=$(date +%s.%N); n=$((9000000 + tel * 100000 + i))
      r="$(ed -c "begin; $APP set constraints trg_puente_recibos_despues immediate;
            insert into recibos (id, proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago,
                                 ultimos4, num_recibo) overriding system value
            values (-$n, '$OBRA', 'recibos/telefono/$n.jpg', 12.34, 'Home Depot', 'leido', '$DUENO',
                    timestamptz '2026-10-15 12:00-04', date '2026-10-15', 'material', 'credito', '2013', 'TEL-$n');
            select 'asientos=' || count(*) from asientos where origen_tabla = 'recibos' and origen_id = '-$n'; rollback;" 2>&1 \
           | grep -v '^{"sub' | tr '\n' ' ')"
      t1=$(date +%s.%N)
      echo "$(python3 -c "print(round($t1 - $t0, 2))") s teléfono $tel subida $i → $r" >> "$TMP/telefono.log"
      sleep 0.25
    done
  ) &
  pids="$pids $!"
done
sleep 1
t0=$(date +%s.%N)
ed -c "begin; $APP select 'nuevas=' || (fn_banco_importar_ofx(conc.qfx('2100-2013', 1, 400), null, 'amex-grande.qfx')->>'filas_nuevas'); commit;" > "$TMP/5a.out" 2>&1
ed -c "begin; $APP select 'casados=' || (fn_banco_casar_todo(null, null)->>'casados'); commit;" > "$TMP/5b.out" 2>&1
ed -c "begin; $APP select 'casados=' || (fn_banco_casar_todo('2100-2013', null)->>'casados'); commit;" > "$TMP/5c.out" 2>&1
t1=$(date +%s.%N)
sleep 1
touch "$TMP/fin"; wait $pids
echo "     importar y casar dos veces: $(python3 -c "print(round($t1 - $t0, 1))") s · $(wc -l < "$TMP/telefono.log") subidas, la más lenta $(sort -rn "$TMP/telefono.log" | head -n 1 | cut -d' ' -f1) s"
revisa "el estado de cuenta entró entero" "nuevas=400" "$(grep '^nuevas=' "$TMP/5a.out")"
revisa "ningún error al importar ni al casar" "0" "$(cat "$TMP/5a.out" "$TMP/5b.out" "$TMP/5c.out" | grep -ciE 'error|40P01')"
revisa "ninguna subida cortada ni muerta (error, 40P01)" "0" "$(grep -ciE 'error|cancel|40P01' "$TMP/telefono.log")"
revisa "ninguna subida esperó 8 s o más" "0" "$(awk '$1 >= 8' "$TMP/telefono.log" | wc -l)"
revisa "cada subida con su asiento" "0" "$(grep -vc 'asientos=1' "$TMP/telefono.log")"

echo "== 6. Volver a pegar c6 con la bandeja leyendo"
ed -c "begin; $APP select 'bandeja=' || count(*) from v_banco_bandeja; select pg_sleep(4); commit;" > "$TMP/6a.out" 2>&1 &
sleep 0.5
( i=$(date +%s.%N); ed -1 -v ON_ERROR_STOP=1 -f "$DOCS/c6-banco.sql" > "$TMP/6b.out" 2>&1; rc=$?
  f=$(date +%s.%N); echo "$rc $(python3 -c "print('t' if $f - $i < 3 else 'f')")" > "$TMP/6b.rc" ) &
sleep 0.5
ed -c "begin; $APP select 'movimientos=' || count(*) from v_banco_movimientos where cuenta = '1010'; commit;" > "$TMP/6c.out" 2>&1
wait
read rc6 pronto < "$TMP/6b.rc"
revisa "el pegado se rindió pronto (55P03) o entró sin hacer esperar" "t" \
  "$( { [ "$rc6" -ne 0 ] && grep -q '55P03' "$TMP/6b.out" && [ "$pronto" = "t" ]; } || [ "$rc6" -eq 0 ] && echo t || echo f)"
revisa "nadie murió por un bloqueo mortal (40P01)" "0" "$(cat "$TMP/6a.out" "$TMP/6b.out" "$TMP/6c.out" | grep -c '40P01')"
revisa "las dos lecturas terminaron bien" "t:t" \
  "$(grep -q '^bandeja=' "$TMP/6a.out" && echo t || echo f):$(grep -q '^movimientos=' "$TMP/6c.out" && echo t || echo f)"
ed -1 -v ON_ERROR_STOP=1 -f "$DOCS/c6-banco.sql" > "$TMP/6d.out" 2>&1
revisa "sin nadie leyendo, el pegado entra (y su resumen, todo en true)" "0:0" "$?:$(grep -c '| f  |' "$TMP/6d.out")"

revisa "fn_banco_verificar: nada en rojo" "ninguno" "$(ed -c "select coalesce(string_agg(control, ', '), 'ninguno') from fn_banco_verificar() where not ok")"
revisa "el libro sigue sano (fn_verificar_cadena)" "ninguno" "$(ed -c "select coalesce(string_agg(control, ', '), 'ninguno') from fn_verificar_cadena() where not ok")"

[ $malos -eq 0 ] && echo "CONCURRENCIA c6 ok" || echo "CONCURRENCIA c6 FALLA"
exit $malos
