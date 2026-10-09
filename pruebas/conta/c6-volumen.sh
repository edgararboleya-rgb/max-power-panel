#!/usr/bin/env bash
# =====================================================================
# c6-volumen.sh — lo que c6-pruebas.sql no puede medir porque pasa con
# MUCHOS movimientos: el banco usado como lo usa conta.js (authenticated,
# el dueño, con la policy de sus tablas y el tope de la API:
# statement_timeout de 8 s) con un año de estados de cuenta encima de un
# libro de verdad.
#
#   ./c6-volumen.sh [nombre_bd] [por_mes]     (por defecto c6_volumen 666)
#   AL_DIA=9 ./c6-volumen.sh …               (los meses que Edgar lleva al día)
#   MOVS=2500 ./c6-volumen.sh … 200          (cuántos movimientos, unos; por
#       defecto 10.000. Con 200 por mes y 2.500, el año de Edgar: ronda 4)
#   PLANTILLA=<bd> ./c6-volumen.sh …         (el libro copiado de una base
#       que dejó «CONSERVAR=1 SOLO_MEDIR=1 ./c4-volumen.sh <bd> 666»: sin
#       rehacerlo, segundos en vez de 4 minutos)
#
# EL LIBRO es el de c4-volumen.sh (se corre con SOLO_MEDIR=1 y CONSERVAR=1:
# la apertura por su balanza y 15 meses por los puentes, ≈ 10.000
# asientos con 666 por mes; y mide de paso las vistas de c4 sobre él).
# Encima se pega c6-banco.sql y se arman 12 MESES DE ESTADOS DE CUENTA de
# tres cuentas (Chase 1010, Amex Gold ····2013 y Amex Blue ····2009), uno
# por cuenta y por mes (36 archivos QFX, OFX 1.x): un movimiento por cada
# línea del libro en esas cuentas (el banco la trae de 0 a 2 días
# después, con la descripción del asiento), más cargos del banco que el
# libro no tiene (a la bandeja), hasta unos 10.000 movimientos. Cada
# archivo con su saldo final (LEDGERBAL). Y mes por mes, como Edgar:
# importa los tres archivos y casa; los primeros AL_DIA meses (9 por
# defecto) además RESUELVE LA BANDEJA (una llamada por movimiento, como la
# app: lo que casa con varios, su primera opción; un cargo sin ticket, a
# 6130) y CONCILIA Y CONFIRMA las tres cuentas a fin de mes; los últimos
# meses se atrasa y la bandeja crece (con AL_DIA=0, un año entero sin
# resolver nada: unos 5.000 pendientes).
#
# LO QUE MIDE, cada cosa como la app, con su tope:
#   · importar cada archivo (fn_banco_importar_ofx): no más de 8 s;
#   · casar el mes (fn_banco_casar_todo, todo lo pendiente): cada llamada
#     no más de 8 s; si el motor dice «completo»: false (paró antes del
#     tope con la bandeja atrasada), se llama otra vez, como conta.js;
#   · cada llamada de la bandeja (fn_banco_casar_con, fn_banco_clasificar)
#     y la conciliación y su confirmación de cada cuenta a fin de mes: no
#     más de 8 s, y las de los meses al día, confirmadas (diferencia 0.00);
#   · cada vista del banco leída como la lee PostgREST (json_agg de
#     «select *», con los ajustes del rol authenticated —el jit = off de
#     c4— y el tope de 8 s), con el filtro de su pantalla: no más de 2 s
#     cada una; y v_asiento_papel (c4, que ahora lee v_papel_fases) de un
#     mes;
#   · fn_banco_control como la pide cada pantalla: no más de 8 s y nada en
#     rojo (salvo lo que el escenario no tiene: préstamos y prepagados sin
#     registrar dan verde igual);
#   · (ronda 4 de c6) las pantallas de cifras de c4 CON EL BANCO EN USO,
#     como en producción (unas diez veces más lenta que este banco):
#     fn_estados_control con su tope por reloj a la velocidad del banco
#     (los 3 s de la API, en 300 ms), pidiendo otra vez lo que sale
#     «Sigue», como conta.js: cada llamada no más de 0,8 s (los 8 s de la
#     API), la pantalla entera en seis llamadas o menos, y nada en rojo.
#     Con el volumen de Edgar (por_mes 250 o menos) falla si no; con más,
#     el tiempo solo se informa (lo rojo falla siempre);
#   · conciliar la cuenta del banco a fin del último mes con la bandeja
#     atrasada (fn_conciliar): no más de 8 s, y otra vez (lo que no cambió
#     no se reescribe);
#   · casar OTRA VEZ con la bandeja atrasada (como conta.js al abrir la
#     bandeja): la primera llamada rehace las propuestas viejas que el
#     reloj dejó para después; la segunda, sin nada nuevo, no rehace
#     ninguna y tarda 2 s o menos;
#   · VOLVER A PEGAR c6-banco.sql sobre todo eso;
#   · fn_banco_verificar (desde el SQL Editor, sin tope de la API), otra
#     vez sin nada nuevo (las confirmadas que no cambiaron no se
#     recalculan), y el libro sano (fn_verificar_cadena);
#   · c6-pruebas.sql entero sobre este banco MIENTRAS cuatro teléfonos
#     suben un ticket cada 0,25 s (como c4-volumen.sh con c3- y
#     c4-pruebas): nada en rojo y ninguna subida cortada ni de 8 s o más
#     (las pruebas tienen los candados de los recibos mientras corren: no
#     pueden crecer con los datos de verdad); y otra vez, sola y con la
#     base caliente: nada en rojo y en menos de 40 s;
#   · al final, los meses 13 y 14 (oct y nov de 2027) importados SIN
#     casar, encima de la bandeja que haya: «Cuadrar» (fn_conciliar de
#     Chase) con un mes y con dos, no más de 4 s cada una; y casar con
#     ellos, como conta.js: cada llamada no más de 8 s y «completo» en
#     tres llamadas o menos (con AL_DIA=0, la bandeja de un año entero).
# Y guarda el EXPLAIN ANALYZE de cada vista en $TMP/explain.txt (lo
# imprime al final con EXPLICAR=1).
# Imprime la tabla de tiempos (la de la cabecera de c6-banco.sql).
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja; se borra con ./correr.sh --borrar).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c6_volumen}"
K="${2:-666}"
# Los meses que Edgar lleva al día (resuelve la bandeja y confirma la
# conciliación); después se atrasa (con AL_DIA=0, un año entero sin
# resolver nada: miles de pendientes).
AL_DIA="${AL_DIA:-9}"
# Cuántos movimientos, más o menos (los del libro y, hasta llegar, cargos
# que el libro no tiene).
MOVS="${MOVS:-10000}"
[[ "$MOVS" =~ ^[0-9]+$ ]] || { echo "MOVS va en dígitos (llegó «$MOVS»)." >&2; exit 64; }
[[ "$K" =~ ^[0-9]+$ ]] && [ "$K" -ge 20 ] || { echo "por_mes va en dígitos, 20 o más (llegó «$K»)." >&2; exit 64; }
TMP="$(mktemp -d)"
chmod 755 "$TMP"
CONSERVAR_BD="${CONSERVAR:-0}"
if [ "$CONSERVAR_BD" = "1" ]; then
  trap 'rm -rf "$TMP"; echo "(La base $BD queda creada: ./correr.sh --borrar $BD)"' EXIT
else
  trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }
# ultima <salida>: lo que respondió la última sentencia, o el ERROR si lo
# hubo. (Con VERBOSITY=verbose la última línea de un error es «LOCATION:
# …»: mirando solo esa, un error —el MX008 de una conciliación ya
# confirmada, el 57014 del tope— pasaba por una respuesta. Ronda 4 de c6,
# grupo 4.)
ultima() {
  if grep -qE '^(ERROR|FATAL):' <<< "$1"; then grep -E '^(ERROR|FATAL):' <<< "$1" | head -n 1
  else grep -vE '^LOCATION:|^[0-9]*$' <<< "$1" | tail -n 1; fi
}

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

if [ -n "${PLANTILLA:-}" ]; then
  # El libro ya hecho: una copia de la base que dejó
  # «CONSERVAR=1 SOLO_MEDIR=1 ./c4-volumen.sh <plantilla> 666» (sin c6).
  echo "== El libro: copia de la base $PLANTILLA (c4-volumen.sh con CONSERVAR=1 SOLO_MEDIR=1)"
  if [ "$(id -u)" = "0" ]; then SU=(env -u PGHOST runuser -u postgres -- psql); else SU=(psql -U postgres); fi
  PGOPTIONS='-c client_min_messages=warning' "${SU[@]}" -X -q -v ON_ERROR_STOP=1 -d postgres \
    -c "drop database if exists \"$BD\" with (force)" -c "create database \"$BD\" template \"$PLANTILLA\" owner editor_sql" || { echo "FALLÓ la copia" >&2; exit 2; }
  [ -z "$(ed -c "select 1 from pg_class where relname = 'movimientos_banco'")" ] || { echo "La plantilla ya tiene c6: tiene que ser el libro solo." >&2; exit 2; }
else
  echo "== El libro de c4-volumen.sh ($K por mes; mide de paso las vistas de c4)"
  t0=$(date +%s.%N)
  CONSERVAR=1 SOLO_MEDIR=1 "$DIR/c4-volumen.sh" "$BD" "$K" > "$TMP/c4vol.out" 2>&1
  rc=$?
  t1=$(date +%s.%N)
  grep -E '^(ok|FALLA|VOLUMEN)|NO TERMINÓ|asientos=' "$TMP/c4vol.out" | sed 's/^/     /' | head -n 60
  [ -n "$(ed -c "select 1 from pg_class where relname = 'asientos'" 2>/dev/null)" ] || { tail -n 30 "$TMP/c4vol.out"; echo "FALLÓ el libro" >&2; exit 2; }
  revisa "c4-volumen.sh sobre el libro (con los cambios para c6)" "0" "$rc"
  echo "     ($(python3 -c "print(round($t1 - $t0, 1))") s)"
fi

echo "== c6-banco.sql encima del libro"
t0=$(date +%s%N)
ed -1 -v ON_ERROR_STOP=1 -f "$DOCS/c6-banco.sql" > "$TMP/c6.out" 2>&1 || { grep -v NOTICE "$TMP/c6.out" | tail -n 20; echo "FALLÓ c6" >&2; exit 2; }
t1=$(date +%s%N)
printf '  %-52s %6d ms\n' "pegar c6-banco.sql (la primera vez)" $(( (t1 - t0) / 1000000 ))

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' order by creado limit 1")"
APP="select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\"}', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"

echo "== Los estados de cuenta: 12 meses de tres cuentas, desde las líneas del libro y con cargos que el libro no tiene"
ed -v ON_ERROR_STOP=1 -v movs="$MOVS" > "$TMP/gen.out" 2>&1 <<'SQL' || { tail -n 20 "$TMP/gen.out"; echo "FALLÓ la generación" >&2; exit 2; }
drop schema if exists vol_banco cascade;
create schema vol_banco;
grant usage on schema vol_banco to authenticated;
create table vol_banco.movs (cuenta text, fecha date, monto numeric(14,2), tipo text, fitid text, nombre text, cheque text);
-- Un movimiento por cada línea viva del libro en las tres cuentas (el
-- banco la trae de 0 a 2 días después), de oct-2026 a sep-2027. (El
-- número de cheque no se repite nunca, como en una chequera de verdad: la
-- secuencia del asiento empieza de nuevo cada año, y con ella sola el
-- cheque 2500 de diciembre y el de febrero se parecían «posible
-- duplicado»: el mismo número a menos de 60 días.)
insert into vol_banco.movs
select l.cuenta, a.fecha_contable + (abs(hashtext(a.numero || '-' || l.orden)) % 3), l.monto,
       case when l.monto < 0 then (case when l.cuenta = '1010' and a.descripcion like 'vol: pago a %' then 'CHECK' else 'DEBIT' end)
            else 'CREDIT' end,
       'V' || a.numero || '-' || l.orden, upper(left(a.descripcion, 60)),
       case when l.cuenta = '1010' and a.descripcion like 'vol: pago a %' then ((a.anio - 2026) * 20000 + 1000 + a.secuencia)::text end
  from public.asiento_lineas l
  join public.asientos a on a.id = l.asiento_id
 where l.cuenta in ('1010', '2100-2013', '2100-2009') and a.fecha_contable between date '2026-10-01' and date '2027-09-27'
   and a.tipo <> 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
   and not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino = 'reverso');
-- Cargos que el libro no tiene (a la bandeja), hasta unos 10.000
-- movimientos (MOVS: con 200 por mes y 2.500, el año de Edgar).
insert into vol_banco.movs
select x.c, d0::date + (g % 27), -round((3 + (g * 37 % 5000) / 100.0)::numeric, 2), 'POS',
       'N' || x.c || '-' || to_char(d0, 'YYMM') || '-' || g, 'VOL POS ' || x.c || ' ' || g, null
  from (values ('1010'), ('2100-2013'), ('2100-2009')) x(c),
       generate_series(date '2026-10-01', date '2027-09-01', interval '1 month') d0,
       generate_series(1, greatest(0, (:movs - (select count(*) from vol_banco.movs)) / 36)::int) g;
create index on vol_banco.movs (cuenta, fecha);
analyze vol_banco.movs;
-- El estado de cuenta de una cuenta y un mes, en OFX 1.x, con su saldo
-- final (lo que dice el libro a esa fecha: la apertura más lo del banco).
create or replace function vol_banco.qfx(p_cuenta text, p_desde date, p_hasta date) returns text
language sql stable as $f$
  select concat_ws(E'\r\n', 'OFXHEADER:100', 'DATA:OFXSGML', 'VERSION:102', '', '<OFX>',
    case when p_cuenta = '1010'
         then '<BANKMSGSRSV1><STMTTRNRS><TRNUID>1<STMTRS><CURDEF>USD<BANKACCTFROM><BANKID>267084131<ACCTID>000000004392<ACCTTYPE>CHECKING</BANKACCTFROM>'
         else '<CREDITCARDMSGSRSV1><CCSTMTTRNRS><TRNUID>1<CCSTMTRS><CURDEF>USD<CCACCTFROM><ACCTID>3727000000' || right(p_cuenta, 4) || '</CCACCTFROM>' end,
    '<BANKTRANLIST><DTSTART>' || to_char(p_desde, 'YYYYMMDD') || '<DTEND>' || to_char(p_hasta, 'YYYYMMDD'),
    (select string_agg(concat('<STMTTRN><TRNTYPE>', m.tipo, '<DTPOSTED>', to_char(m.fecha, 'YYYYMMDD'), '120000[0:GMT]<TRNAMT>', m.monto,
                              '<FITID>', m.fitid, coalesce('<CHECKNUM>' || m.cheque, ''), '<NAME>', replace(m.nombre, '&', '&amp;'),
                              '</STMTTRN>'), E'\r\n' order by m.fecha, m.fitid)
       from vol_banco.movs m where m.cuenta = p_cuenta and m.fecha between p_desde and p_hasta),
    '</BANKTRANLIST><LEDGERBAL><BALAMT>'
      || ((case when p_cuenta = '1010' then 500000.00 else 0 end)
          + coalesce((select sum(m.monto) from vol_banco.movs m where m.cuenta = p_cuenta and m.fecha <= p_hasta), 0))::text
      || '<DTASOF>' || to_char(p_hasta, 'YYYYMMDD') || '</LEDGERBAL>',
    case when p_cuenta = '1010' then '</STMTRS></STMTTRNRS></BANKMSGSRSV1>' else '</CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1>' end,
    '</OFX>')
$f$;
grant select on vol_banco.movs to authenticated;
grant execute on function vol_banco.qfx(text, date, date) to authenticated;
select 'movimientos a generar: ' || count(*) from vol_banco.movs;
SQL
grep 'movimientos a generar' "$TMP/gen.out" | sed 's/^/     /'

# mide <nombre> <tope_ms> <sql> [commit]: como la app, con el tope de la API (8 s).
mide() {
  local t0 t1 ms r out fin="${4:-rollback}"
  t0=$(date +%s%N)
  out="$(ed -c "begin; $APP $3; $fin;" 2>&1)"
  t1=$(date +%s%N)
  r="$(ultima "$out")"
  ms=$(( (t1 - t0) / 1000000 ))
  echo "$ms" > "$TMP/ultimo.ms"
  if grep -qiE 'error|cancel' <<< "$r"; then
    printf '  %-52s NO TERMINÓ: %s\n' "$1" "$(cut -c1-140 <<< "$r")"; malos=1
  elif [ "$ms" -gt "$2" ]; then
    printf '  %-52s %6d ms  (tope %d ms: FALLA)  %s\n' "$1" "$ms" "$2" "$r"; malos=1
  else
    printf '  %-52s %6d ms  %s\n' "$1" "$ms" "$r"
  fi
}

echo "== Mes por mes, como Edgar: importar los tres archivos, casar (como la app, tope 8 s), resolver la bandeja y conciliar"
echo "     (los meses 1 a $AL_DIA: Edgar al día, resuelve y confirma; los demás: se atrasa y la bandeja crece)"
max_imp=0; max_casar=0; llamadas_max=1; max_clas=0; max_conc=0; max_conf=0; confirmadas=0; n_mes=0
for d0 in $(ed -c "select to_char(g, 'YYYY-MM-DD') from generate_series(date '2026-10-01', date '2027-09-01', interval '1 month') g"); do
  n_mes=$((n_mes + 1))
  d1="$(ed -c "select ((date '$d0' + interval '1 month')::date - 1)::text")"
  for c in 1010 2100-2013 2100-2009; do
    arg="null"; [ "$c" = "1010" ] && arg="'1010'"
    mide "importar $c ${d0:0:7}" 8000 \
      "select 'nuevas=' || (fn_banco_importar_ofx(vol_banco.qfx('$c', '$d0', '$d1'), $arg, 'vol-$c-${d0:0:7}.qfx')->>'filas_nuevas')" commit \
      > "$TMP/linea.txt"
    grep -q 'FALLA\|NO TERMINÓ' "$TMP/linea.txt" && cat "$TMP/linea.txt"
    ms=$(cat "$TMP/ultimo.ms"); [ "$ms" -gt "$max_imp" ] && max_imp=$ms
  done
  # Casar como conta.js: fn_banco_casar_todo, y otra vez mientras diga
  # «completo»: false (el motor para antes del tope y sigue donde quedó).
  llamadas=0
  while :; do
    llamadas=$((llamadas + 1))
    mide "casar ${d0:0:7} (llamada $llamadas)" 8000 \
      "select x->>'casados' || ' casados, pendientes ' || (x->>'pendientes') || ', completo ' || (x->>'completo') from (select fn_banco_casar_todo(null, null) as x) y" commit \
      > "$TMP/linea.txt"
    ms=$(cat "$TMP/ultimo.ms"); [ "$ms" -gt "$max_casar" ] && max_casar=$ms
    cat "$TMP/linea.txt"
    if grep -q 'FALLA\|NO TERMINÓ' "$TMP/linea.txt" || [ "$llamadas" -ge 6 ]; then malos=1; break; fi
    grep -q 'completo true' "$TMP/linea.txt" && break
  done
  [ "$llamadas" -gt "$llamadas_max" ] && llamadas_max=$llamadas
  if [ "$n_mes" -le "$AL_DIA" ]; then
    # EDGAR RESUELVE LA BANDEJA: cada movimiento pendiente hasta fin de mes,
    # una llamada por movimiento como las de la app (lo que casa con varios,
    # su primera opción después de rehacer su propuesta; un cargo sin
    # ticket, a 6130). Mide cada llamada.
    ed -v ON_ERROR_STOP=1 > "$TMP/resolver.out" 2>&1 <<SQL || { tail -n 5 "$TMP/resolver.out"; malos=1; }
begin;
select set_config('request.jwt.claims', '{"sub":"$DUENO","role":"authenticated"}', true);
set local role authenticated;
set local jit = off;
do \$\$
declare
  r     record;
  t0    timestamptz;
  v_ms  numeric;
  v_max numeric := 0;
  v_tot numeric := 0;
  v_n   int := 0;
  v_m   movimientos_banco;
begin
  for r in select id from movimientos_banco where estado = 'pendiente' and fecha <= date '$d1' order by fecha, id loop
    t0 := clock_timestamp();
    select * into v_m from movimientos_banco where id = r.id;
    if v_m.estado = 'pendiente' and v_m.posible_duplicado_de is not null and v_m.duplicado is null then
      -- (Lo que entró «posible duplicado»: Edgar mira y dice si es el mismo.)
      perform fn_banco_duplicado(r.id, false, 'c6-volumen: no es el mismo');
      select * into v_m from movimientos_banco where id = r.id;
    end if;
    if v_m.estado = 'pendiente' then
      if v_m.estado_motivo = 'varios_candidatos' then
        perform fn_banco_casar(r.id);
        select * into v_m from movimientos_banco where id = r.id;
      end if;
      if v_m.estado = 'pendiente' and v_m.estado_motivo = 'varios_candidatos' then
        perform fn_banco_casar_con(r.id, jsonb_build_object('lineas', v_m.propuesta->'candidatos'->0->'lineas'), 'c6-volumen: la primera opción');
      elsif v_m.estado = 'pendiente' and v_m.monto < 0 then
        perform fn_banco_clasificar(r.id, '[{"cuenta": "6130"}]'::jsonb, 'c6-volumen: cargo sin ticket');
      elsif v_m.estado = 'pendiente' then
        perform fn_banco_ignorar(r.id, 'c6-volumen: abono sin papel');
      end if;
    end if;
    v_ms := extract(epoch from clock_timestamp() - t0) * 1000;
    v_max := greatest(v_max, v_ms); v_tot := v_tot + v_ms; v_n := v_n + 1;
  end loop;
  raise notice 'RESUELTOS % % %', v_n, round(case when v_n > 0 then v_tot / v_n else 0 end, 1), round(v_max);
end \$\$;
commit;
SQL
    read -r _ n_res media_res max_res <<< "$(grep -o 'RESUELTOS.*' "$TMP/resolver.out" | tail -n 1)"
    max_res=${max_res:-0}; [ "${max_res%.*}" -gt "$max_clas" ] && max_clas=${max_res%.*}
    printf '  %-52s %6s ms  (%s llamadas, media %s ms)\n' "resolver la bandeja ${d0:0:7} (la llamada más lenta)" "$max_res" "${n_res:-0}" "${media_res:-0}"
    # CONCILIAR y CONFIRMAR cada cuenta a fin de mes, como la app.
    for c in 1010 2100-2013 2100-2009; do
      mide "conciliar $c ${d1}" 8000 \
        "select 'diferencia ' || (x->>'diferencia') || ', sin casar ' || (x->>'n_sin_casar') || ', en tránsito ' || (x->>'n_transito') || ', lista ' || (x->>'lista_para_confirmar') from (select fn_conciliar('$c', '$d1') as x) y" commit \
        > "$TMP/linea.txt"
      ms=$(cat "$TMP/ultimo.ms"); [ "$ms" -gt "$max_conc" ] && max_conc=$ms
      grep -q 'FALLA\|NO TERMINÓ' "$TMP/linea.txt" && cat "$TMP/linea.txt"
      if grep -q 'lista true' "$TMP/linea.txt"; then
        mide "confirmar $c ${d1}" 8000 \
          "select fn_conciliacion_confirmar((select id from conciliaciones where cuenta = '$c' and fecha_corte = '$d1'))->>'estado'" commit \
          > "$TMP/linea2.txt"
        ms=$(cat "$TMP/ultimo.ms"); [ "$ms" -gt "$max_conf" ] && max_conf=$ms
        grep -q 'confirmada' "$TMP/linea2.txt" && confirmadas=$((confirmadas + 1)) || { cat "$TMP/linea2.txt"; malos=1; }
      else
        echo "  FALLA: la conciliación de $c al $d1 no quedó lista para confirmar: $(cut -c 60-220 "$TMP/linea.txt")"; malos=1
      fi
    done
  fi
done
printf '  %-52s %6d ms\n' "el archivo que más tardó en importarse" "$max_imp"
printf '  %-52s %6d ms  (hasta %d llamadas en un mes)\n' "la llamada a casar que más tardó" "$max_casar" "$llamadas_max"
printf '  %-52s %6d ms\n' "la llamada de la bandeja que más tardó" "$max_clas"
printf '  %-52s %6d ms\n' "la conciliación que más tardó" "$max_conc"
printf '  %-52s %6d ms  (%d confirmadas)\n' "la confirmación que más tardó" "$max_conf" "$confirmadas"
echo "     movimientos=$(ed -c "select count(*) from movimientos_banco") casados=$(ed -c "select count(*) from movimientos_banco where estado in ('casado', 'en_transito')") pendientes=$(ed -c "select count(*) from movimientos_banco where estado = 'pendiente'") ignorados=$(ed -c "select count(*) from movimientos_banco where estado = 'ignorado'") archivos=$(ed -c "select count(*) from archivos_banco") asientos=$(ed -c "select count(*) from asientos")"
revisa "las conciliaciones de los meses al día, confirmadas" "$((AL_DIA * 3))" "$confirmadas"
revisa "ningún movimiento dos veces (llave única por cuenta)" "0" "$(ed -c "select count(*) from (select cuenta, id_externo from movimientos_banco group by 1, 2 having count(*) > 1) x")"
revisa "ninguna línea del libro casada dos veces" "0" "$(ed -c "select count(*) from (select asiento_id, orden from banco_casado_lineas where vigente group by 1, 2 having count(*) > 1) x")"
ed -c "analyze public.movimientos_banco, public.banco_casados, public.banco_casado_lineas, public.conciliaciones, public.conciliacion_partidas, public.archivos_banco, public.asientos, public.asiento_lineas" > /dev/null

echo "== Casar otra vez con la bandeja atrasada (como conta.js al abrir la bandeja): la primera se pone al día; la segunda, sin nada nuevo, no rehace nada (tope 2 s)"
mide "casar otra vez (rehace las propuestas viejas)" 8000 \
  "select x->>'casados' || ' casados, ' || coalesce(x->>'propuestas', '-') || ' propuestas rehechas, pendientes ' || (x->>'pendientes') || ', completo ' || (x->>'completo') from (select fn_banco_casar_todo(null, null) as x) y" commit
mide "y otra vez, sin nada nuevo" 2000 \
  "select x->>'casados' || ' casados, ' || coalesce(x->>'propuestas', '-') || ' propuestas rehechas, pendientes ' || (x->>'pendientes') || ', completo ' || (x->>'completo') from (select fn_banco_casar_todo(null, null) as x) y" commit \
  > "$TMP/linea.txt"
cat "$TMP/linea.txt"
revisa "casar sin nada nuevo no rehace ninguna propuesta" "0" "$(grep -o '[0-9]* propuestas rehechas' "$TMP/linea.txt" | cut -d' ' -f1)"

P="2027-09"
echo "== Cada vista del banco como la lee la app por PostgREST (json_agg de select *, dueño, 8 s; tope 2 s)"
vista() { mide "$1" 2000 "select coalesce(json_array_length(json_agg(t)), 0) || ' filas' from (select * from $2) t"; }
vista "v_banco_movimientos (1010, $P)" "v_banco_movimientos where cuenta = '1010' and periodo = '$P'"
vista "v_banco_movimientos (todas las cuentas, $P)" "v_banco_movimientos where periodo = '$P'"
vista "v_banco_bandeja (todo lo pendiente)" "v_banco_bandeja"
vista "v_banco_saldos" "v_banco_saldos"
vista "v_prestamos" "v_prestamos"
vista "v_prepagados" "v_prepagados"
vista "v_asiento_papel (c4, $P)" "v_asiento_papel where periodo = '$P'"

echo "== Conciliar a fin del último mes, con la bandeja atrasada (como la app, tope 8 s), y sus vistas"
if [ "$AL_DIA" -ge 12 ]; then
  # (Con los 12 meses al día, la del último mes ya está confirmada: no se
  # recalcula —MX008, la regla—; su tiempo es el de «la conciliación que
  # más tardó», arriba. Antes se medía igual y el error salía como un
  # resultado.)
  echo "     (los 12 meses al día: la conciliación del último mes ya está confirmada y no se recalcula; ver arriba)"
else
  mide "fn_conciliar(1010, 2027-09-30), con la bandeja atrasada" 8000 "select 'diferencia ' || (x->>'diferencia') || ', sin casar ' || (x->>'n_sin_casar') || ', en tránsito ' || (x->>'n_transito') from (select fn_conciliar('1010', '2027-09-30') as x) y" commit
  mide "otra vez (lo igual no se reescribe)" 8000 "select 'diferencia ' || (x->>'diferencia') || ', sin casar ' || (x->>'n_sin_casar') from (select fn_conciliar('1010', '2027-09-30') as x) y" commit
  mide "fn_conciliar(2100-2013, 2027-09-30)" 8000 "select 'diferencia ' || (x->>'diferencia') || ', sin casar ' || (x->>'n_sin_casar') from (select fn_conciliar('2100-2013', '2027-09-30') as x) y" commit
fi
vista "v_conciliacion" "v_conciliacion"
vista "v_conciliacion_partidas (1010, 2027-09-30)" "v_conciliacion_partidas where cuenta = '1010' and fecha_corte = '2027-09-30'"

echo "== fn_banco_control como la pide cada pantalla (tope 8 s, nada en rojo)"
ctl() {  # ctl <nombre> <periodo> <vistas o null>
  mide "$1" 8000 "select count(*) || ' filas, en rojo: ' || coalesce(string_agg(vista || coalesce(' (' || left(detalle, 100) || ')', ''), '; ') filter (where not ok), 'ninguna') from fn_banco_control('$2', $3)"
}
ctl "la bandeja ($P)" "$P" "array['v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos']"
ctl "la conciliación ($P)" "$P" "array['v_conciliacion', 'v_conciliacion_partidas']"
ctl "todo ($P)" "$P" "null"
ctl "hoy" "hoy" "null"
revisa "fn_banco_control($P): nada en rojo" "ninguna" \
  "$(ultima "$(ed -c "begin; $APP select coalesce(string_agg(vista, ', ') filter (where not ok), 'ninguna') from fn_banco_control('$P', null); rollback;" 2>&1)")"

# (Ronda 4 de c6) COMO EN PRODUCCIÓN: la instancia de Supabase es unas diez
# veces más lenta que este banco y la API corta cada llamada a los 8 s. A
# la velocidad del banco: 0,8 s por llamada, y el tope por reloj de
# fn_estados_control (3 s desde la API) en 300 ms. Con el volumen de Edgar
# (unos 200 papeles por mes) se exige; con más, se informa.
PROD_LLAMADA_MS=800
PROD_RELOJ_MS=300
if [ "$K" -le 250 ]; then EXIGE=1; else EXIGE=0; fi
echo "== Las pantallas de cifras de c4 con el banco en uso, como en producción: el tope por reloj en $PROD_RELOJ_MS ms y la API en $PROD_LLAMADA_MS ms; conta.js pide otra vez lo que sale «Sigue»"
[ "$EXIGE" = "1" ] || echo "     (con $K por mes, más que el volumen de Edgar: el tiempo solo se informa; lo rojo falla igual)"
# pantalla <nombre> <periodo> <vistas>: como en c4-volumen.sh. Pide el
# control de su lista y, mientras salga algo «Sigue», otra vez con lo que
# falta. Cada llamada no más de 0,8 s, la pantalla en 6 llamadas o menos y
# nada en rojo (ok falso, o nulo sin ser «Sigue»).
pantalla() {
  local lista="$3" n=0 max=0 tot=0 t0 t1 ms r sigue rojo="" falla=""
  while [ -n "$lista" ] && [ $n -lt 9 ]; do
    n=$((n + 1))
    t0=$(date +%s%N)
    r="$(ultima "$(ed -c "begin; $APP set local c4.control_tope = '$PROD_RELOJ_MS'; select coalesce(string_agg(quote_literal(vista), ', ' order by orden) filter (where ok is null and detalle like 'Sigue:%'), '') || '|' || coalesce(string_agg(vista, '; ') filter (where ok is not true and not (ok is null and coalesce(detalle, '') like 'Sigue:%')), '') from fn_estados_control('$2', $lista); rollback;" 2>&1)")"
    t1=$(date +%s%N)
    ms=$(( (t1 - t0) / 1000000 ))
    if grep -qiE 'error|cancel' <<< "$r"; then
      printf '  %-52s NO TERMINÓ (llamada %d): %s\n' "$1" "$n" "$(cut -c1-120 <<< "$r")"; malos=1; return
    fi
    tot=$((tot + ms)); [ "$ms" -gt "$max" ] && max=$ms
    sigue="${r%%|*}"
    [ -n "${r#*|}" ] && rojo="${rojo:+$rojo; }${r#*|}"
    if [ -n "$sigue" ]; then lista="array[$sigue]"; else lista=""; fi
  done
  [ "$max" -gt "$PROD_LLAMADA_MS" ] && falla="${falla} una llamada de $max ms (tope $PROD_LLAMADA_MS)"
  [ -n "$lista" ] || [ "$n" -gt 6 ] && falla="${falla} $n llamadas$( [ -n "$lista" ] && echo ' y todavía «Sigue»')"
  printf '  %-52s %6d ms  la más lenta de %d llamadas (en total %d ms), en rojo: %s' "$1" "$max" "$n" "$tot" "${rojo:-ninguna}"
  if [ -n "$rojo" ]; then malos=1; fi
  if [ -n "$falla" ]; then
    if [ "$EXIGE" = "1" ]; then printf '  (FALLA:%s)' "$falla"; malos=1; else printf '  (se informa:%s)' "$falla"; fi
  fi
  printf '\n'
}
pantalla "el Panel ($P, 9 vistas)" "$P" "array['v_saldos_dinero', 'v_flujo_real_por_mes', 'v_cxc_antiguedad', 'v_cxp_antiguedad', 'v_resultados', 'v_comparacion_resumen', 'v_gasto_por_categoria', 'v_gasto_por_proveedor', 'v_obras_dinero']"
pantalla "el Panel a hoy" "hoy" "null"
pantalla "los estados ($P, 4 vistas)" "$P" "array['v_balanza', 'v_balance_general', 'v_resultados', 'v_flujo_caja']"

echo "== EXPLAIN ANALYZE de cada vista (como la app) → $TMP/explain.txt"
: > "$TMP/explain.txt"
for q in "v_banco_movimientos where periodo = '$P'" "v_banco_bandeja" "v_banco_saldos" "v_conciliacion" \
         "v_conciliacion_partidas where cuenta = '1010' and fecha_corte = '2027-09-30'" "v_asiento_papel where periodo = '$P'"; do
  echo "--- $q" >> "$TMP/explain.txt"
  ed -c "begin; $APP explain (analyze, timing on) select * from $q; rollback;" 2>&1 | grep -v '^[0-9]*$' >> "$TMP/explain.txt"
  printf '  %-52s %s\n' "${q:0:52}" "$(grep -E 'Execution Time' "$TMP/explain.txt" | tail -n 1 | sed 's/^ *//')"
done
[ "${EXPLICAR:-0}" = "1" ] && cat "$TMP/explain.txt"

echo "== Volver a pegar c6-banco.sql sobre todo esto"
t0=$(date +%s%N)
ed -1 -v ON_ERROR_STOP=1 -f "$DOCS/c6-banco.sql" > "$TMP/c6b.out" 2>&1; rc=$?
t1=$(date +%s%N)
revisa "el pegado entra" "0" "$rc"
printf '  %-52s %6d ms\n' "volver a pegar c6-banco.sql" $(( (t1 - t0) / 1000000 ))
revisa "su resumen del final: todo en true" "0" "$(grep -c '| f  |' "$TMP/c6b.out")"

echo "== La revisión entera y el libro sano"
t0=$(date +%s%N)
revisa "fn_banco_verificar: nada en rojo" "ninguno" "$(ed -c "select coalesce(string_agg(control, ', '), 'ninguno') from fn_banco_verificar() where not ok")"
t1=$(date +%s%N)
printf '  %-52s %6d ms\n' "fn_banco_verificar (SQL Editor)" $(( (t1 - t0) / 1000000 ))
t0=$(date +%s%N)
revisa "fn_banco_verificar otra vez, sin nada nuevo: nada en rojo" "ninguno" "$(ed -c "select coalesce(string_agg(control, ', '), 'ninguno') from fn_banco_verificar() where not ok")"
t1=$(date +%s%N)
printf '  %-52s %6d ms\n' "fn_banco_verificar otra vez (nada nuevo)" $(( (t1 - t0) / 1000000 ))
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
echo "== c6-pruebas.sql sobre este banco mientras la app se usa (cuatro teléfonos, un ticket cada 0,25 s cada uno)"
rm -f "$TMP/fin"; : > "$TMP/telefono.log"; pids=""
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
            select 'asientos=' || count(*) from asientos where origen_tabla = 'recibos' and origen_id = '-$n'; rollback;" 2>&1 \
           | grep -v '^{"sub' | tr '\n' ' ')"
      t1=$(date +%s.%N)
      echo "$(python3 -c "print(round($t1 - $t0, 2))") s teléfono $tel subida $i → $r" >> "$TMP/telefono.log"
      sleep 0.25
    done
  ) &
  pids="$pids $!"
done
t0=$(date +%s.%N)
ed -1 -v ON_ERROR_STOP=1 -c '\o /dev/null' -f "$DOCS/c6-pruebas.sql" -f "$TMP/resumen.sql" > "$TMP/pruebas.out" 2>&1; rc=$?
t1=$(date +%s.%N)
touch "$TMP/fin"; wait $pids
seg="$(python3 -c "print(round($t1 - $t0, 1))")"
echo "     c6-pruebas: $seg s · $(grep '^PRUEBAS' "$TMP/pruebas.out")"
echo "     los teléfonos: $(wc -l < "$TMP/telefono.log") subidas, la más lenta $(sort -rn "$TMP/telefono.log" | head -n 1 | cut -d' ' -f1) s"
revisa "c6-pruebas corrió entero" "0" "$rc"
revisa "c6-pruebas: nada en rojo" "0" "$(grep -o 'fallan=[0-9]*' "$TMP/pruebas.out" | cut -d= -f2)"
grep -E '^ *[0-9]+ *\| *FALLA' "$TMP/pruebas.out" | cut -c1-400
revisa "c6-pruebas: ninguna subida cortada por el tope de 8 s" "0" "$(grep -ciE 'error|cancel' "$TMP/telefono.log")"
revisa "c6-pruebas: ninguna subida esperó 8 s o más" "0" "$(awk '$1 >= 8' "$TMP/telefono.log" | wc -l)"
revisa "c6-pruebas: cada subida con su asiento" "0" "$(grep -vc 'asientos=1' "$TMP/telefono.log")"
grep -iE 'error|cancel' "$TMP/telefono.log" | head -n 3 | cut -c1-250

echo "== c6-pruebas.sql otra vez, sola, con la base caliente y asentada (como en producción): nada en rojo y en menos de 40 s"
# (La vez de arriba es la primera sobre una base recién hecha: lee del disco
# lo que en producción ya está en memoria, y el autovacuum todavía pasa por
# lo que se acaba de escribir. Por eso la medida va aquí, con las tablas
# asentadas y sin los teléfonos.)
ed -c "vacuum (analyze) public.asientos, public.asiento_lineas, public.recibos, public.movimientos_banco, public.movimientos_banco_ids, public.banco_casados, public.banco_casado_lineas, public.banco_historial, public.conciliaciones, public.conciliacion_partidas, public.archivos_banco" > /dev/null 2>&1
t0=$(date +%s.%N)
ed -1 -v ON_ERROR_STOP=1 -c '\o /dev/null' -f "$DOCS/c6-pruebas.sql" -f "$TMP/resumen.sql" > "$TMP/pruebas0.out" 2>&1; rc=$?
t1=$(date +%s.%N)
seg="$(python3 -c "print(round($t1 - $t0, 1))")"
echo "     c6-pruebas: $seg s · $(grep '^PRUEBAS' "$TMP/pruebas0.out")"
revisa "c6-pruebas (sola) corrió entero" "0" "$rc"
revisa "c6-pruebas (sola): nada en rojo" "0" "$(grep -o 'fallan=[0-9]*' "$TMP/pruebas0.out" | cut -d= -f2)"
grep -E '^ *[0-9]+ *\| *FALLA' "$TMP/pruebas0.out" | cut -c1-400
# (9-oct: el tope de 40 s se calibró el 3-oct con 36,8 s en 17.6; el 9-oct la
# misma máquina daba de 46 a 56 s, igual con el c6 de producción que con el
# nuevo. De 40 a 60 s se avisa sin fallar; de 60 s en adelante, falla.)
if python3 -c "import sys; sys.exit(0 if $seg < 40 else 1)"; then
  revisa "c6-pruebas: menos de 40 s con un año de banco" "si" "si"
elif python3 -c "import sys; sys.exit(0 if $seg < 60 else 1)"; then
  echo "  aviso  c6-pruebas tardó $seg s con un año de banco (el tope de 40 s se calibró el 3-oct; hasta 60 s se avisa: la máquina del banco varía)"
else
  revisa "c6-pruebas: menos de 60 s con un año de banco" "si" "no ($seg s)"
fi

echo "== Los meses 13 y 14 (oct y nov de 2027) recién importados y SIN casar: «Cuadrar» antes de «Casar» (tope 4 s), y casar con ellos (tope 8 s)"
# (Lo que pasa si Edgar abre «Cuadrar» antes de casar, o vuelve de unas
# semanas fuera con dos meses por importar, encima de la bandeja que ya
# traía. Antes de la ronda 2 de c6: la pareja de fn_conciliacion_items
# juntaba cada movimiento con cada línea y cada día —de 3 a 7 s con un mes
# y 57014 con dos—, y con la bandeja atrasada un año casar se cortaba a
# los 8 s en cada llamada, por el cruce de transferencias. Va al final:
# no cambia lo medido arriba.)
ed -v ON_ERROR_STOP=1 > "$TMP/mes13.out" 2>&1 <<'SQL' || { tail -n 5 "$TMP/mes13.out"; malos=1; }
-- Los dos meses como los otros doce: una línea del banco por cada línea
-- del libro (del 28-sep, lo que el archivo de septiembre ya no trajo) y
-- los cargos que el libro no tiene.
insert into vol_banco.movs
select l.cuenta, a.fecha_contable + (abs(hashtext(a.numero || '-' || l.orden)) % 3), l.monto,
       case when l.monto < 0 then (case when l.cuenta = '1010' and a.descripcion like 'vol: pago a %' then 'CHECK' else 'DEBIT' end)
            else 'CREDIT' end,
       'V' || a.numero || '-' || l.orden, upper(left(a.descripcion, 60)),
       case when l.cuenta = '1010' and a.descripcion like 'vol: pago a %' then ((a.anio - 2026) * 20000 + 1000 + a.secuencia)::text end
  from public.asiento_lineas l
  join public.asientos a on a.id = l.asiento_id
 where l.cuenta in ('1010', '2100-2013', '2100-2009') and a.fecha_contable between date '2027-09-28' and date '2027-11-30'
   and a.tipo <> 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
   and coalesce(a.origen_tabla, '') <> 'movimientos_banco'
   and not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino = 'reverso')
   and not exists (select 1 from vol_banco.movs v where v.fitid = 'V' || a.numero || '-' || l.orden);
insert into vol_banco.movs
select x.c, d0::date + (g % 27), -round((3 + (g * 37 % 5000) / 100.0)::numeric, 2), 'POS',
       'N' || x.c || '-' || to_char(d0, 'YYMM') || '-' || g, 'VOL POS ' || x.c || ' ' || g, null
  from (values ('1010'), ('2100-2013'), ('2100-2009')) x(c),
       generate_series(date '2027-10-01', date '2027-11-01', interval '1 month') d0,
       generate_series(1, 83) g;
insert into vol_banco.movs
select '1010', d0::date + (g % 30), -round((7 + (g * 53 % 4000) / 100.0)::numeric, 2), 'POS',
       'X1010-' || to_char(d0, 'YYMM') || '-' || g, 'VOL POS EXTRA ' || g, null
  from generate_series(date '2027-10-01', date '2027-11-01', interval '1 month') d0, generate_series(1, 125) g;
analyze vol_banco.movs;
SQL
importa_mes() {  # importa_mes <d0> <d1>
  for c in 1010 2100-2013 2100-2009; do
    arg="null"; [ "$c" = "1010" ] && arg="'1010'"
    mide "importar $c ${1:0:7}" 8000 \
      "select 'nuevas=' || (fn_banco_importar_ofx(vol_banco.qfx('$c', '$1', '$2'), $arg, 'vol-$c-${1:0:7}.qfx')->>'filas_nuevas')" commit \
      > "$TMP/linea.txt"
    grep -q 'FALLA\|NO TERMINÓ' "$TMP/linea.txt" && cat "$TMP/linea.txt"
  done
}
CONC="select 'diferencia ' || (x->>'diferencia') || ', sin casar ' || (x->>'n_sin_casar') || ', en tránsito ' || (x->>'n_transito') from (select fn_conciliar('1010', '%s') as x) y"
importa_mes 2027-10-01 2027-10-31
echo "     pendientes: $(ed -c "select count(*) from movimientos_banco where estado = 'pendiente'") (Chase: $(ed -c "select count(*) from movimientos_banco where estado = 'pendiente' and cuenta = '1010'"))"
mide "fn_conciliar(1010, 2027-10-31), el mes 13 sin casar" 4000 "$(printf "$CONC" 2027-10-31)"
importa_mes 2027-11-01 2027-11-30
mide "fn_conciliar(1010, 2027-11-30), dos meses sin casar" 4000 "$(printf "$CONC" 2027-11-30)"
llamadas=0
while :; do
  llamadas=$((llamadas + 1))
  mide "casar con los meses 13 y 14 (llamada $llamadas)" 8000 \
    "select x->>'casados' || ' casados, pendientes ' || (x->>'pendientes') || ', completo ' || (x->>'completo') from (select fn_banco_casar_todo(null, null) as x) y" commit \
    > "$TMP/linea.txt"
  cat "$TMP/linea.txt"
  if grep -q 'FALLA\|NO TERMINÓ' "$TMP/linea.txt" || [ "$llamadas" -ge 3 ]; then
    grep -q 'completo true' "$TMP/linea.txt" || { echo "FALLA: casar con los meses 13 y 14 no terminó en 3 llamadas"; malos=1; }
    break
  fi
  grep -q 'completo true' "$TMP/linea.txt" && break
done
mide "fn_conciliar(1010, 2027-11-30), ya casados" 4000 "$(printf "$CONC" 2027-11-30)"
revisa "ninguna línea del libro casada dos veces (con los meses 13 y 14)" "0" \
  "$(ed -c "select count(*) from (select asiento_id, orden from banco_casado_lineas where vigente group by 1, 2 having count(*) > 1) x")"

[ $malos -eq 0 ] && echo "VOLUMEN c6 ok" || echo "VOLUMEN c6 FALLA"
exit $malos
