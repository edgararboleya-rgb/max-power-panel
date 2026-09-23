#!/usr/bin/env bash
# =====================================================================
# correr.sh — prueba E37 en el banco local.
#   ./correr.sh [nombre_bd]
# Monta la base con el banco de la contabilidad (pruebas/conta), le añade
# Vault y un pg_net que apunta lo que manda (00), y las funciones, vistas y
# permisos EXACTOS de producción con un secreto falso (01). Luego:
#   ROJO   · e37-pruebas antes de E37: tiene que fallar donde E37 arregla
#   E37 dos veces (idempotente)
#   VERDE  · e37-pruebas después: 20/20
#   ROTACIÓN · E37b dos veces, E37c dos veces, y qué secreto sale en cada paso
# Nunca toca Supabase. Borra la base al terminar.
# =====================================================================
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"
BD="${1:-seg_e37}"
export PGHOST="${PGHOST:-127.0.0.1}" PGPORT="${PGPORT:-5432}"
SU=(runuser -u postgres -- psql -h /var/run/postgresql -X -q -v ON_ERROR_STOP=1 -d "$BD")
ED=(env PGPASSWORD=editor_sql psql -X -q -v ON_ERROR_STOP=1 -h "$PGHOST" -p "$PGPORT" -U editor_sql -d "$BD")
FALLOS=0
comprobar() { local que="$1"; shift; if "$@"; then echo "  ✓ $que"; else echo "  ✗ $que"; FALLOS=$((FALLOS+1)); fi; }

"$REPO/pruebas/conta/correr.sh" "$BD" >/dev/null 2>&1 || { echo "no se pudo montar la base"; exit 2; }
"${SU[@]}" -f "$DIR/00-vault-shim.sql" >/dev/null || exit 2
"${ED[@]}" -1 -f "$DIR/01-replica-extra.sql" >/dev/null || exit 2

pruebas() {
  "${ED[@]}" -P pager=off -f "$DIR/e37-pruebas.sql" \
    -c "select 'PRUEBAS total='||count(*)||' ok='||count(*) filter (where ok)||' fallan='||count(*) filter (where ok is false)||' omitidas='||count(*) filter (where ok is null) as resumen from _pruebas;"
}

echo "=================== ROJO · antes de E37"; pruebas
echo "=================== E37 (primera vez)"
"${ED[@]}" -1 -P pager=off -f "$REPO/docs/sql/e37-seguridad.sql" || { echo "E37 abortó"; exit 2; }
echo "=================== E37 (segunda vez: idempotente)"
"${ED[@]}" -1 -P pager=off -f "$REPO/docs/sql/e37-seguridad.sql" | tail -12 || { echo "E37 abortó la segunda vez"; exit 2; }
comprobar "un solo secreto del cartero en Vault tras pegar E37 dos veces" \
  [ "$("${ED[@]}" -At -c "select count(*) from vault.secrets where name = 'mxp_secreto_cartero'")" = "1" ]
echo "=================== VERDE · después de E37"; SALIDA=$(pruebas); echo "$SALIDA"
echo "$SALIDA" | grep -q "PRUEBAS total=20 ok=20 fallan=0" || FALLOS=$((FALLOS+1))

echo "=================== ROTACIÓN"
secreto() { "${ED[@]}" -At -c "select coalesce((select decrypted_secret from vault.decrypted_secrets where name = '$1'), '')"; }
ultimo()  { "${ED[@]}" -At -c "select headers->>'x-mxp-secreto' from net._llamadas order by id desc limit 1"; }
HOY=$(secreto mxp_secreto_cartero)
"${ED[@]}" -1 -f "$REPO/docs/sql/e37b-cartero-rotar-preparar.sql" >/dev/null || { echo "E37b abortó"; exit 2; }
NUEVO1=$(secreto mxp_secreto_cartero_siguiente)
"${ED[@]}" -1 -f "$REPO/docs/sql/e37b-cartero-rotar-preparar.sql" >/dev/null
NUEVO2=$(secreto mxp_secreto_cartero_siguiente)
comprobar "E37b pegado dos veces enseña el mismo secreto nuevo" [ -n "$NUEVO1" -a "$NUEVO1" = "$NUEVO2" ]
comprobar "el nuevo es distinto del de hoy" [ "$NUEVO1" != "$HOY" ]
comprobar "el nuevo mide 68 (mxp_ + 64 hex)" [ "${#NUEVO1}" -eq 68 ]
"${ED[@]}" -c "select fn_cartero('{\"titulo\":\"prueba\"}')" >/dev/null
comprobar "tras E37b el cartero SIGUE mandando el de hoy" [ "$(ultimo)" = "$HOY" ]
"${ED[@]}" -1 -f "$REPO/docs/sql/e37c-cartero-rotar-activar.sql" >/dev/null || { echo "E37c abortó"; exit 2; }
comprobar "tras E37c el cartero manda el nuevo (y salió el aviso de prueba)" [ "$(ultimo)" = "$NUEVO1" ]
comprobar "el «siguiente» ya no está en Vault" [ -z "$(secreto mxp_secreto_cartero_siguiente)" ]
comprobar "mxp_secreto_cartero es ahora el nuevo" [ "$(secreto mxp_secreto_cartero)" = "$NUEVO1" ]
"${ED[@]}" -1 -f "$REPO/docs/sql/e37c-cartero-rotar-activar.sql" >/dev/null 2>&1 || { echo "E37c abortó la segunda vez"; FALLOS=$((FALLOS+1)); }
comprobar "E37c pegado otra vez no cambia nada" [ "$(secreto mxp_secreto_cartero)" = "$NUEVO1" ]

"$REPO/pruebas/conta/correr.sh" --borrar "$BD" >/dev/null 2>&1
echo "==================="; [ "$FALLOS" -eq 0 ] && echo "TODO BIEN" || echo "FALLOS: $FALLOS"
exit $([ "$FALLOS" -eq 0 ] && echo 0 || echo 1)
