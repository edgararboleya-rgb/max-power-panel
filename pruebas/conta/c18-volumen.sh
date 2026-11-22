#!/usr/bin/env bash
# =====================================================================
# c18-volumen.sh — lo que c18-pruebas.sql no puede ver con los pocos
# asientos de una prueba: que EL PAQUETE PARA EL CONTADOR contesta con el
# AÑO ENTERO y el volumen de Edgar sin acercarse al corte de la API, y que
# su balanza CUADRA también en el SEGUNDO ejercicio del libro.
# (22-nov-2026, cuarta vuelta de c18: la tercera revisión midió que
# fn_fiscal_paquete del año entero tardaba de 0.8 a 1.0 s en el banco —el
# tope de la casa, que son los 8 s de la API en producción— porque releía
# las vistas de c4 unas once veces; y que la «Trial Balance» del segundo
# ejercicio sumaba distinto de cero por todo el resultado del año anterior,
# que el libro no cierra con un asiento.)
#
#   ./c18-volumen.sh [nombre_bd] [por_mes]    (por defecto c18_volumen 250)
#
# EL LIBRO es el de c4-volumen.sh (se le pide a él, con CONSERVAR=1 y
# SOLO_MEDIR=1: la apertura por su balanza y 15 meses por los puentes,
# oct-2026 a dic-2027, con «hoy» fingido al 20-dic-2027; 250 por mes ≈ el
# volumen de Edgar, unos 4,000 asientos), y encima se pega c18-fiscal.sql.
#
# COMO EN PRODUCCIÓN: la instancia de Supabase va unas diez veces más
# despacio que este banco y la API corta cada llamada a los 8 s; a la
# velocidad del banco, 0.8 s por llamada. Cada cosa se pide como el dueño
# por la API (su rol, los ajustes de ese rol, el corte de 8 s).
#
# LO QUE COMPRUEBA
#   1. fn_fiscal_paquete del año entero (2027) con las dos formas, el del
#      primer año (2026, parcial) y fn_fiscal_leer: cada llamada, no más de
#      0.8 s (con por_mes de 250 o menos se exige; con más, se informa). El
#      paquete de 2027, tres veces: se mira la más lenta.
#   2. LA BALANZA DEL PAQUETE en los dos ejercicios: suma 0 al inicio y al
#      final, debe = haber, y sus totales son los de la balanza de c4; el
#      de 2027 trae el renglón de los resultados de 2026 (el libro no los
#      cierra con un asiento) con la línea de las utilidades retenidas.
#   3. EL SCHEDULE L de los dos ejercicios cuadra y su activo es el del
#      balance general del mismo paquete; las líneas del 1125-A dan el
#      costo de ventas de los libros.
#   4. EL CONTROL de la capa: ningún cuadre en rojo.
#   5. c18-pruebas.sql ENTERO sobre ese libro: nada en rojo.
#
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra su base
# al terminar (con CONSERVAR=1 la deja; se borra con ./correr.sh --borrar
# <nombre_bd>). Todo inventado; nada de producción.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
BD="${1:-c18_volumen}"
K="${2:-250}"
[[ "$BD" =~ ^[a-z][a-z0-9_]{0,62}$ ]] || { echo "Nombre de base inválido: '$BD'" >&2; exit 64; }
[[ "$K" =~ ^[0-9]+$ ]] && [ "$K" -ge 20 ] || { echo "por_mes va en dígitos, 20 o más (llegó «$K»)." >&2; exit 64; }
case "$BD" in postgres|template0|template1) echo "No se toca la base '$BD'." >&2; exit 64;; esac
TMP="$(mktemp -d)"
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'rm -rf "$TMP"; echo "(La base $BD queda creada: ./correr.sh --borrar $BD)"' EXIT
else
  trap '"$DIR/correr.sh" --borrar "$BD" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
fi

PROD_LLAMADA_MS=800
if [ "$K" -le 250 ]; then EXIGE=1; else EXIGE=0; fi

ed() { PGPASSWORD=editor_sql psql -X -q -At -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" "$@"; }
malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

echo "== El libro de volumen de c4 ($K por mes: oct-2026 a dic-2027), sin sus suites"
t0=$(date +%s)
CONSERVAR=1 SOLO_MEDIR=1 bash "$DIR/c4-volumen.sh" "$BD" "$K" > "$TMP/c4vol.out" 2>&1
rc=$?
t1=$(date +%s)
if [ "$rc" -ne 0 ] || ! grep -q '^VOLUMEN c4 ok' "$TMP/c4vol.out"; then
  # (rc 1: alguna medida de c4 pasó de su tope en esta máquina; el libro está hecho igual, y aquí se mide lo de c18)
  if [ "$rc" -eq 2 ] || ! grep -q 'asientos=' "$TMP/c4vol.out"; then
    tail -n 15 "$TMP/c4vol.out"; echo "FALLÓ el libro de volumen" >&2; exit 2
  fi
  echo "     (aviso: c4-volumen.sh no salió limpio en esta máquina —rc $rc—; el libro está hecho: $(grep -c 'FALLA' "$TMP/c4vol.out") de sus medidas fallan)"
fi
echo "     ($((t1 - t0)) s) $(grep 'asientos=' "$TMP/c4vol.out" | sed 's/^ *//')"

echo "== c18-fiscal.sql sobre ese libro"
ed -1 -v ON_ERROR_STOP=1 -f "$DOCS/c18-fiscal.sql" > "$TMP/c18.out" 2>&1 || { tail -n 12 "$TMP/c18.out"; echo "FALLÓ el pegado de c18" >&2; exit 2; }
revisa "el pegado de c18: todas sus filas «ok»" "0" "$(grep -c 'ROJO' "$TMP/c18.out")"

DUENO="$(ed -c "select id from perfiles where rol = 'dueno' order by creado limit 1")"
[ -n "$DUENO" ] || { echo "No hay dueño en la semilla" >&2; exit 2; }
A2="$(ed -c "select extract(year from fn_fecha_miami(now()))::int")"
A1=$((A2 - 1))
# Como la app: el dueño, con el rol authenticated, los ajustes de ese rol que PostgREST aplica en cada consulta y el tope de la API
APP="select set_config('request.jwt.claims', '{\"sub\":\"$DUENO\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); select set_config('request.jwt.claim.sub', '$DUENO', true); select count(set_config(k.k, k.v, true)) from (select split_part(c, '=', 1) as k, lower(substr(c, strpos(c, '=') + 1)) as v from pg_roles r, unnest(r.rolconfig) c where r.rolname = 'authenticated') k join pg_settings ps on ps.name = k.k and ps.context = 'user'; set local role authenticated; set local statement_timeout = '8s';"

# mide <nombre> <sql que devuelve un texto> [veces]: como la app; se queda con la más lenta
mide() {
  local n="${3:-1}" i t0 t1 ms max=0 r=""
  for i in $(seq 1 "$n"); do
    t0=$(date +%s%N)
    r="$(ed -c "begin; $APP select 'R ' || ($2); rollback;" 2>&1 | grep -E '^R |ERROR|cancel' | tail -n 1)"
    t1=$(date +%s%N)
    ms=$(( (t1 - t0) / 1000000 )); [ "$ms" -gt "$max" ] && max=$ms
    if ! grep -q '^R ' <<< "$r"; then printf '  %-52s NO TERMINÓ: %s\n' "$1" "$(cut -c1-120 <<< "$r")"; malos=1; return; fi
  done
  if [ "$max" -gt "$PROD_LLAMADA_MS" ]; then
    if [ "$EXIGE" = "1" ]; then printf '  %-52s %6d ms  (tope %d ms: FALLA)  %s\n' "$1" "$max" "$PROD_LLAMADA_MS" "${r#R }"; malos=1
    else printf '  %-52s %6d ms  (se informa: más de %d ms con %s por mes)  %s\n' "$1" "$max" "$PROD_LLAMADA_MS" "$K" "${r#R }"; fi
  else
    printf '  %-52s %6d ms  %s\n' "$1" "$max" "${r#R }"
  fi
}

echo "== 1. Cada llamada como la app (el dueño, su rol, 8 s): no más de $PROD_LLAMADA_MS ms"
mide "el paquete de $A2 (el año entero), Form 1120" "(select jsonb_array_length(p->'trial_balance') || ' renglones de balanza, ' || jsonb_array_length(p->'tax_lines') || ' líneas' from fn_fiscal_paquete($A2, null) p)" 3
mide "el paquete de $A2, Form 1120-S" "(select jsonb_array_length(p->'tax_lines') || ' líneas' from fn_fiscal_paquete($A2, '1120-S') p)"
mide "el paquete de $A1 (el primer año, parcial)" "(select jsonb_array_length(p->'trial_balance') || ' renglones de balanza' from fn_fiscal_paquete($A1, null) p)"
mide "fn_fiscal_leer" "(select count(*) || ' cuentas' from jsonb_object_keys(fn_fiscal_leer()->'cuentas'))"

echo "== 2. La balanza del paquete en los dos ejercicios: suma 0 y es la de c4"
for a in "$A1" "$A2"; do
  r="$(ed -c "begin; $APP
    select format('%s|%s|%s|%s|%s|%s',
             ((p->'trial_balance_totals'->>'beginning')::numeric = 0 and (p->'trial_balance_totals'->>'ending')::numeric = 0)::text,
             ((p->'trial_balance_totals'->>'debits')::numeric = (p->'trial_balance_totals'->>'credits')::numeric)::text,
             p->'trial_balance_totals'->>'balanced',
             (select (b.cuadra and b.saldo_inicial = (p->'trial_balance_totals'->>'beginning')::numeric and b.saldo_final = (p->'trial_balance_totals'->>'ending')::numeric
                      and b.debe = (p->'trial_balance_totals'->>'debits')::numeric and b.haber = (p->'trial_balance_totals'->>'credits')::numeric)::text
                from v_balanza b where b.periodo = '$a' and b.nivel = 'total'),
             (select count(*) from jsonb_array_elements(p->'trial_balance') x where x->>'level' = 'component'),
             (select coalesce(sum((x->>'ending')::numeric), 0) from jsonb_array_elements(p->'trial_balance') x where x ? 'account'))
      from fn_fiscal_paquete($a, null) p; rollback;" 2>&1 | tail -n 1)"
  IFS='|' read -r cero dh bal c4 comp solas <<< "$r"
  revisa "$a: la balanza suma 0 al inicio y al final" "true" "$cero"
  revisa "$a: debe = haber" "true" "$dh"
  revisa "$a: el paquete dice que cuadra" "true" "$bal"
  revisa "$a: sus totales son los de la balanza de c4" "true" "$c4"
  echo "     ($a: $comp renglón(es) de resultados de años anteriores; las cuentas solas suman $solas)"
done
revisa "$A2: trae el renglón de los resultados de $A1 (sin él no sumaría 0), con la línea de las utilidades retenidas" "true" \
  "$(ed -c "begin; $APP select (count(*) >= 1 and bool_and(x->>'tax_line' = 'L25' and not (x ? 'account'))
                               and (select coalesce(sum((y->>'ending')::numeric), 0) from jsonb_array_elements(p->'trial_balance') y where y ? 'account') <> 0)::text
                         from fn_fiscal_paquete($A2, null) p, jsonb_array_elements(p->'trial_balance') x where x->>'level' = 'component' group by p; rollback;" 2>&1 | tail -n 1)"

echo "== 3. El Schedule L (cuadra y es el balance) y el 1125-A, en los dos ejercicios y con las dos formas"
for a in "$A1" "$A2"; do
  for f in "null" "'1120-S'"; do
    revisa "$a, $f: el Schedule L cuadra, su activo es el del balance general, y el 1125-A da el costo de ventas de los libros" "true|true|true" \
      "$(ed -c "begin; $APP select concat_ws('|', p->'schedule_l'->>'balanced', p->'schedule_l'->>'matches_balance_sheet', p->'form_1125a_check'->>'matches') from fn_fiscal_paquete($a, $f) p; rollback;" 2>&1 | tail -n 1)"
  done
done

echo "== 4. El control de la capa"
revisa "ningún cuadre de c18 en rojo" "ninguno" "$(ed -c "select coalesce(string_agg(orden::text, ', ' order by orden) filter (where nivel = 'cuadre' and not ok), 'ninguno') from fn_fiscal_control()")"
echo "     (avisos: $(ed -c "select coalesce(string_agg(orden::text, ', ' order by orden) filter (where nivel = 'aviso' and not ok), 'ninguno') from fn_fiscal_control()"))"

echo "== 5. c18-pruebas.sql entero sobre ese libro"
PGPASSWORD=editor_sql psql -X -q -At -1 -v ON_ERROR_STOP=1 -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -d "$BD" \
  -c '\o /dev/null' -f "$DOCS/c18-pruebas.sql" -c '\o' \
  -c "select 'R ' || count(*) || ' pruebas: ' || count(*) filter (where ok) || ' bien, ' || count(*) filter (where not ok) || ' fallan, ' || count(*) filter (where ok is null) || ' omitidas (' || coalesce(string_agg(n::text, ',' order by n) filter (where ok is not true), '-') || ')' from _pruebas" \
  > "$TMP/pruebas.out" 2>&1 || { tail -n 8 "$TMP/pruebas.out"; echo "FALLA: c18-pruebas.sql no corrió entero"; malos=1; }
echo "     $(grep '^R ' "$TMP/pruebas.out" | tail -n 1 | cut -c3-)"
revisa "c18-pruebas.sql sobre el libro de volumen: nada en rojo" "0" "$(ed -c "select count(*) from pruebas.c18_resultado where ok is false")"

[ "$malos" = 0 ] && echo "TODO BIEN" || echo "ALGO FALLA"
exit "$malos"
