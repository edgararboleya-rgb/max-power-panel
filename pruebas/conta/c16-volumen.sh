#!/usr/bin/env bash
# =====================================================================
# c16-volumen.sh — lo que c16-pruebas.sql no puede ver con los pocos
# asientos de una base de pruebas: que el tablero entero (fn_tablero, sus
# 16 tarjetas) contesta en MENOS DE UN SEGUNDO con un libro grande, y que
# con miles de asientos sus cuadres con el libro siguen al centavo.
# (14-nov, Fase 11c: con la tarjeta de la nómina. Sobre una plantilla con la
# nómina de c15, la semilla trae dos nóminas de Gusto y sus cargos, y la
# tarjeta se mide con ellas; sobre una sin c15 —g12a—, la tarjeta dice que
# c15 no está y lo demás se mide igual.)
#
#   ./c16-volumen.sh <plantilla> [nombre_bd]   (por defecto c16_volumen)
#
# <plantilla>: una base del banco con la cadena ya pegada (c1 … c14, la de
# la fase 12a en el banco de la casa; o con c15, la de la nómina). Se CLONA
# (la plantilla no se toca) y
# a la copia se le pega:
#   · la semilla de la fase 16 (f16-semilla.sql: un libro en uso, de la
#     apertura al 30-sep a hoy);
#   · N vueltas (de fábrica 760; N=… para otro) de: una factura (la mitad,
#     cobradas con un cheque diez días después), un ticket de tarjeta, un
#     recibo a cuenta de un proveedor (la mitad, pagados) y un gasto a mano,
#     del 1-oct a hoy: unos 3,600 asientos y 7,300 líneas, más de lo que Max
#     Power asienta en un año;
#   · c16-tablero.sql, y las estadísticas de la base (analyze), como las
#     tiene una base en uso.
# Y comprueba, como el dueño por la API (su rol y el tope de 8 s):
#   1. LAS TARJETAS: las 16 contestan (la de la nómina, o dice que c15 no
#      está), nada queda en «sigue», y los cuadres
#      con el libro (el embudo de cobro, lo por cobrar, lo por pagar y la
#      caja) en verde, al centavo;
#   2. LOS TIEMPOS: siete pasadas de fn_tablero con el tope de fábrica; la
#      mediana de las seis últimas, por debajo de 1 s (la meta), y ninguna
#      por encima de 2 s. Dice además la tarjeta más lenta.
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja). Nombres inventados («ZZ…»); nada
# de producción.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
[ $# -ge 1 ] || { sed -n '6,8p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }
PLANTILLA="$1"
BD="${2:-c16_volumen}"
N="${N:-760}"
for x in "$PLANTILLA" "$BD"; do
  [[ "$x" =~ ^[a-z][a-z0-9_]{0,62}$ ]] || { echo "Nombre de base inválido: '$x'" >&2; exit 64; }
done
case "$BD" in postgres|template0|template1|"$PLANTILLA") echo "No se toca la base '$BD'." >&2; exit 64;; esac
[[ "$N" =~ ^[0-9]{1,5}$ ]] || { echo "N es un número" >&2; exit 64; }

if [ -n "${BANCO_SU:-}" ]; then
  read -r -a PSQL_SU <<< "$BANCO_SU"
elif [ "$(id -u)" = "0" ]; then
  PSQL_SU=(runuser -u postgres -- psql)
else
  PSQL_SU=(psql -U postgres)
fi
su_psql() { env -u PGHOST "${PSQL_SU[@]}" -X -q -v ON_ERROR_STOP=1 -p "${PGPORT:-5432}" "$@"; }
ed() { PGPASSWORD=editor_sql psql -X -q -At -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }

TMP="$(mktemp -d)"
chmod 755 "$TMP"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'echo "(La base $BD y $TMP quedan: borrarlas a mano)"' EXIT
else
  trap 'su_psql -d postgres -c "drop database if exists \"$BD\" with (force)" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

echo "== La copia de $PLANTILLA: $BD"
su_psql -d postgres -c "drop database if exists \"$BD\" with (force)" > "$TMP/clon.out" 2>&1 \
  && su_psql -d postgres -c "create database \"$BD\" template \"$PLANTILLA\" owner editor_sql" >> "$TMP/clon.out" 2>&1 \
  && su_psql -d postgres -c "grant create on database \"$BD\" to editor_sql" >> "$TMP/clon.out" 2>&1 \
  || { tail -n 5 "$TMP/clon.out"; echo "FALLÓ la copia (¿alguien está conectado a $PLANTILLA?)" >&2; exit 2; }

echo "== La semilla de la fase 16"
ed -v ON_ERROR_STOP=1 -f "$DIR/f16-semilla.sql" > "$TMP/semilla.out" 2>&1 \
  || { tail -n 12 "$TMP/semilla.out"; echo "FALLÓ la semilla" >&2; exit 2; }

echo "== El volumen: $N vueltas de factura, cobro, ticket, recibo, pago y gasto"
cat > "$TMP/volumen.sql" <<'SQL'
\set ON_ERROR_STOP 1
select set_config('vol.n', :'n', false) \gset
do $$
declare
  n     int := current_setting('vol.n')::int;
  hoy   date := fn_fecha_miami(now());
  dias  int := fn_fecha_miami(now()) - date '2026-10-01';
  dueno uuid := (select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1);
  obras text[] := (select array_agg(id order by id) from proyectos);
  sup   uuid := (select id from proveedores where nombre = 'ZZ SUPPLY DOS');
  i int; f date; m numeric; fid bigint; rid bigint;
begin
  if dueno is null or obras is null or sup is null or dias < 0 then
    raise exception 'c16-volumen: falta el dueño, una obra o el proveedor de la semilla (¿se pegó f16-semilla.sql?)';
  end if;
  execute 'set constraints trg_puente_recibos_despues, trg_puente_externos_despues, trg_puente_facturas_despues immediate';
  for i in 1..n loop
    f := date '2026-10-01' + (i * 7 % (dias + 1));
    m := round((300 + (i * 137 % 9000) + (i % 100) / 100.0)::numeric, 2);
    insert into facturas (proyecto_id, num, fecha, monto, retencion)
    values (obras[1 + i % array_length(obras, 1)], 'ZZV-' || i, f, m, 0) returning id into fid;
    if i % 2 = 0 and f + 10 <= hoy then
      perform fn_cobro_registrar(jsonb_build_object('fecha', (f + 10)::text, 'monto', m::text, 'cuenta', '1010', 'medio', 'cheque',
        'referencia', 'ZZV-C-' || i, 'duplicado_confirmado', 'volumen',
        'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', fid, 'monto', m::text))));
    end if;
    m := round((20 + (i * 37 % 900) + (i % 100) / 100.0)::numeric, 2);
    insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago, ultimos4, num_recibo)
    values (obras[1 + i % array_length(obras, 1)], 'recibos/zzv/t' || i || '.jpg', m, 'ZZ Depot', 'leido', dueno,
            (f + time '12:00') at time zone 'America/New_York', f, (array['material', 'material', 'renta_equipo', 'permiso'])[1 + i % 4],
            'credito', case when i % 2 = 0 then '2009' else '1007' end, 'ZZV-T-' || i);
    m := round((100 + (i * 53 % 3000) + (i % 100) / 100.0)::numeric, 2);
    insert into recibos (proyecto_id, ruta, total, proveedor, estado, autor_id, creado, fecha, categoria, metodo_pago, num_recibo)
    values (obras[1 + i % array_length(obras, 1)], 'recibos/zzv/c' || i || '.jpg', m, 'ZZ Supply Dos', 'leido', dueno,
            (f + time '12:00') at time zone 'America/New_York', f, 'material', 'cuenta_proveedor', 'ZZV-S-' || i)
    returning id into rid;
    if i % 2 = 1 and f + 15 <= hoy then
      perform fn_postear(jsonb_build_object('fecha', (f + 15)::text, 'descripcion', 'ZZV: pago al supply ' || i,
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2010', 'monto', m::text, 'tercero_tipo', 'proveedor', 'tercero_id', sup::text,
                                                       'partida_tabla', 'recibos', 'partida_id', rid::text),
                                    jsonb_build_object('cuenta', '1010', 'monto', (-m)::text))));
    end if;
    m := round((15 + (i * 43 % 600) + (i % 100) / 100.0)::numeric, 2);
    perform fn_postear(jsonb_build_object('fecha', f::text, 'descripcion', 'ZZV: gasto ' || i,
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', (array['6100', '6130', '6300', '6500', '6600', '6200', '6120', '6700'])[1 + i % 8],
                                                     'monto', m::text),
                                  jsonb_build_object('cuenta', '1010', 'monto', (-m)::text))));
  end loop;
end $$;
select 'CARGA ' || (select count(*) from asientos) || ' asientos, ' || (select count(*) from asiento_lineas) || ' líneas';
SQL
ed -v n="$N" -f "$TMP/volumen.sql" > "$TMP/volumen.out" 2>&1 \
  || { tail -n 12 "$TMP/volumen.out"; echo "FALLÓ la carga del volumen" >&2; exit 2; }
grep -o 'CARGA .*' "$TMP/volumen.out" | sed 's/^CARGA /     (/; s/$/)/'

echo "== c16-tablero.sql"
PGPASSWORD=editor_sql psql -X -q -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" \
  -f "$DOCS/c16-tablero.sql" > "$TMP/pegado.out" 2>&1 \
  || { tail -n 12 "$TMP/pegado.out"; echo "FALLÓ el pegado de c16" >&2; exit 2; }

# (las estadísticas, como las tiene una base en uso: autovacuum las saca solo al rato de una carga grande; recién
#  cargada y sin ellas, el tablero tarda casi el doble —0.9 s en el banco— hasta que autovacuum pasa)
ed -c "analyze" > "$TMP/analyze.out" 2>&1

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1")"
# Como el dueño por la API: su rol, los ajustes de ese rol y el tope de 8 s. (Cada consulta lee el
# tablero UNA vez: «offset 0» para que Postgres no repita la llamada en cada columna que la usa.)
api() {  # api <archivo de salida> <sql>
  ed -v ON_ERROR_STOP=1 \
     -c "begin; select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated; set local statement_timeout = '8s';" \
     -c "$2" -c "commit;" > "$1" 2>&1
}

echo "== 1. Las tarjetas"
api "$TMP/tarjetas.out" "select 'R ' || (select count(*) from jsonb_array_elements_text(t -> 'tarjetas') k where (t -> k ->> 'ok')::boolean or t -> k ->> 'falta' is not null)
          || ' contestan | sigue ' || jsonb_array_length(t -> 'sigue')
          || ' | cuadres ' || concat_ws(' ', 'embudo=' || (t -> 'cobros' -> 'cuadre' ->> 'ok'), 'cobrar=' || (t -> 'por_cobrar' -> 'cuadre' ->> 'ok'),
                                        'pagar=' || (t -> 'por_pagar' -> 'cuadre' ->> 'ok'), 'caja=' || (t -> 'caja' -> 'cuadre' ->> 'ok'))
          from (select fn_tablero('{\"tope_ms\": 0}') as t offset 0) x"
revisa "las 16 tarjetas contestan (la de la nómina, o dice que c15 no está), nada en «sigue» y los cuadres con el libro en verde" \
  "16 contestan | sigue 0 | cuadres embudo=true cobrar=true pagar=true caja=true" "$(sed -n 's/^R //p' "$TMP/tarjetas.out")"

echo "== 2. Los tiempos (siete pasadas, cada una su llamada, con el tope de fábrica)"
TODAS=""; SIGUE=0
for i in 1 2 3 4 5 6 7; do
  api "$TMP/pasada$i.out" "select 'R ' || (t ->> 'ms') || ' ' || jsonb_array_length(t -> 'sigue') from (select fn_tablero('{}') as t offset 0) x"
  read -r MS SG <<< "$(sed -n 's/^R //p' "$TMP/pasada$i.out")"
  if [ -z "${MS:-}" ]; then echo "FALLA: la pasada $i no salió: $(grep -m1 ERROR "$TMP/pasada$i.out")"; malos=1; continue; fi
  [ "$i" -gt 1 ] && { TODAS="$TODAS $MS"; SIGUE=$((SIGUE + SG)); }
done
if [ -n "$TODAS" ]; then
  MEDIANA="$(printf '%s\n' $TODAS | sort -n | sed -n '3p')"
  PEOR="$(printf '%s\n' $TODAS | sort -n | tail -n 1)"
  echo "     (pasadas 2 a 7:$TODAS ms)"
  [ "$MEDIANA" -lt 1000 ] && echo "ok   la mediana, ${MEDIANA} ms (la meta, 1 s)" || { echo "FALLA: la mediana, ${MEDIANA} ms (la meta es 1 s)"; malos=1; }
  [ "$PEOR" -lt 2000 ] && echo "ok   la peor, ${PEOR} ms (tope 2 s)" || { echo "FALLA: la peor, ${PEOR} ms (tope 2 s)"; malos=1; }
  revisa "con el tope de fábrica, nada quedó en «sigue»" "0" "$SIGUE"
fi
api "$TMP/lenta.out" "select 'R ' || string_agg(k || ' ' || (t -> k ->> 'ms') || ' ms', ', ' order by (t -> k ->> 'ms')::int desc)
          from (select fn_tablero('{}') as t offset 0) x, jsonb_array_elements_text(t -> 'tarjetas') k"
echo "     (por tarjeta, una pasada: $(sed -n 's/^R //p' "$TMP/lenta.out" | cut -c1-200) …)"

[ "$malos" = 0 ] && echo "TODO BIEN" || echo "ALGO FALLA"
exit "$malos"
