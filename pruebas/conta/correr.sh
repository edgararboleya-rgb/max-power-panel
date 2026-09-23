#!/usr/bin/env bash
# =====================================================================
# correr.sh — banco de pruebas local que imita a Supabase.
#
#   ./correr.sh <nombre_bd> [archivo.sql[:A|:B] ...]
#   ./correr.sh --borrar <nombre_bd>
#
# Borra y crea la base <nombre_bd>, carga 00 (como superusuario), 01 y 02
# (como editor_sql) y luego cada archivo que se le pase, en orden, como
# editor_sql con ON_ERROR_STOP=1. La base QUEDA creada al terminar para que
# puedas mirarla; bórrala con --borrar cuando acabes.
#
# Sufijos: si un archivo tiene la línea "-- ==== BLOQUE B ====",
#   archivo.sql:A  carga solo hasta la marca (sin incluirla)
#   archivo.sql:B  carga desde la marca (incluida) hasta el final
#
# Archivos c*-pruebas.sql: la salida propia del archivo se calla y, en la
# MISMA sesión (la tabla _pruebas es temporal), se imprime la tabla de
# resultados legible y la línea
#   PRUEBAS total=N ok=N fallan=N omitidas=N
# Código de salida: 0 si todo corrió y nada falla; 1 si alguna prueba
# falla; 2 si un archivo aborta con error de SQL; 64 uso incorrecto.
#
# Variables de entorno opcionales:
#   PGHOST (127.0.0.1)  PGPORT (5432)  — dónde está el cluster
#   BANCO_SU  — comando para psql de superusuario. Por defecto, si corres
#               como root: "runuser -u postgres -- psql"; si no, "psql -U postgres".
#   BANCO_SIN_TRANSACCION=1 — carga cada archivo sentencia a sentencia
#               (autocommit). Por defecto cada archivo va en UNA transacción
#               (psql -1), como el SQL Editor de Supabase, que manda todo lo
#               pegado en una sola petición: si una sentencia falla, no queda
#               nada, y now() vale lo mismo en todo el archivo.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-5432}"
MARCA='-- ==== BLOQUE B ===='

if [ -n "${BANCO_SU:-}" ]; then
  read -r -a PSQL_SU <<< "$BANCO_SU"
elif [ "$(id -u)" = "0" ]; then
  PSQL_SU=(runuser -u postgres -- psql)
else
  PSQL_SU=(psql -U postgres)
fi

uso() { sed -n '4,8p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }

# El superusuario entra por el socket local (peer); editor_sql por TCP con
# su contraseña, como un cliente cualquiera.
su_psql() { env -u PGHOST "${PSQL_SU[@]}" -X -q -v ON_ERROR_STOP=1 "$@"; }
ed_psql() { PGPASSWORD=editor_sql psql -X -q -U editor_sql -v ON_ERROR_STOP=1 "$@"; }

validar_nombre() {
  [[ "$1" =~ ^[a-z][a-z0-9_]{0,62}$ ]] || { echo "Nombre de base inválido: '$1' (minúsculas, dígitos y _)" >&2; exit 64; }
  case "$1" in postgres|template0|template1) echo "No se toca la base '$1'." >&2; exit 64;; esac
}

[ $# -ge 1 ] || uso

if [ "$1" = "--borrar" ]; then
  [ $# -eq 2 ] || uso
  validar_nombre "$2"
  su_psql -d postgres -c "drop database if exists \"$2\" with (force)"
  echo "Base $2 borrada."
  exit 0
fi

BD="$1"; shift
validar_nombre "$BD"

# Resuelve rutas ANTES de hacer nada, para fallar pronto si falta un archivo.
declare -a ARCH=() PARTE=()
for arg in "$@"; do
  parte=""
  ruta="$arg"
  if [[ "$arg" =~ ^(.*):([AB])$ ]]; then ruta="${BASH_REMATCH[1]}"; parte="${BASH_REMATCH[2]}"; fi
  [ -f "$ruta" ] || { echo "No existe el archivo: $ruta" >&2; exit 64; }
  if [ -n "$parte" ] && ! grep -qxF -- "$MARCA" "$ruta"; then
    echo "El archivo $ruta no tiene la marca '$MARCA'; no se puede pedir :$parte" >&2; exit 64
  fi
  ARCH+=("$(cd "$(dirname "$ruta")" && pwd)/$(basename "$ruta")")
  PARTE+=("$parte")
done

TMP="$(mktemp -d)"
chmod 755 "$TMP"
trap 'rm -rf "$TMP"' EXIT

echo "== Base $BD: borrar y crear"
PGOPTIONS='-c client_min_messages=warning' su_psql -d postgres -c "drop database if exists \"$BD\" with (force)" || exit 2
su_psql -d postgres -c "create database \"$BD\"" || exit 2

echo "== 00-shim-supabase.sql (superusuario)"
PGOPTIONS='-c client_min_messages=warning' su_psql -d "$BD" -f "$DIR/00-shim-supabase.sql" || { echo "FALLÓ 00-shim-supabase.sql" >&2; exit 2; }
echo "== 01-replica-esquema.sql (editor_sql)"
PGOPTIONS='-c client_min_messages=warning' ed_psql -d "$BD" -f "$DIR/01-replica-esquema.sql" || { echo "FALLÓ 01-replica-esquema.sql" >&2; exit 2; }
echo "== 02-semilla.sql (editor_sql)"
PGOPTIONS='-c client_min_messages=warning' ed_psql -d "$BD" -f "$DIR/02-semilla.sql" || { echo "FALLÓ 02-semilla.sql" >&2; exit 2; }

# Lo que se corre, en la misma sesión, después de un c*-pruebas.sql.
cat > "$TMP/resumen.sql" <<'SQL'
\o
\pset footer off
\pset null '-'
\echo
select n,
       case ok when true then 'ok' when false then 'FALLA' else 'omitida' end as resultado,
       prueba, esperado, obtenido
  from _pruebas order by n;
\pset tuples_only on
\pset format unaligned
select format('PRUEBAS total=%s ok=%s fallan=%s omitidas=%s',
              count(*), count(*) filter (where ok), count(*) filter (where not ok),
              count(*) filter (where ok is null))
  from _pruebas;
SQL

UNA=(-1)
[ "${BANCO_SIN_TRANSACCION:-0}" = "1" ] && UNA=()

salida=0
for i in "${!ARCH[@]}"; do
  f="${ARCH[$i]}"; p="${PARTE[$i]}"; nombre="$(basename "$f")"
  cargar="$f"
  if [ "$p" = "A" ]; then
    cargar="$TMP/$i-A-$nombre"
    awk -v m="$MARCA" '$0 == m { exit } { print }' "$f" > "$cargar"
  elif [ "$p" = "B" ]; then
    cargar="$TMP/$i-B-$nombre"
    awk -v m="$MARCA" 'hay || $0 == m { hay = 1; print }' "$f" > "$cargar"
  fi
  etiqueta="$nombre${p:+:$p}"

  # Regla del entregable: nada de metacomandos de psql en docs/conta/*.sql.
  if grep -nE '^[[:space:]]*\\' "$cargar" >/dev/null; then
    echo "AVISO: $etiqueta tiene metacomandos de psql (\\...). En el SQL Editor de Supabase no funcionan:" >&2
    grep -nE '^[[:space:]]*\\' "$cargar" | head -5 >&2
  fi

  if [[ "$nombre" == c*-pruebas.sql ]]; then
    echo "== $etiqueta (editor_sql, pruebas)"
    ultima="$(grep -vE '^[[:space:]]*(--.*)?$' "$cargar" | tail -n 1)"
    if ! [[ "$ultima" =~ ^[[:space:]]*select[[:space:]]+\*[[:space:]]+from[[:space:]]+_pruebas[[:space:]]+order[[:space:]]+by[[:space:]]+n[[:space:]]*\;[[:space:]]*$ ]]; then
      echo "AVISO: la última sentencia de $etiqueta no es 'select * from _pruebas order by n;' (es lo que enseña el SQL Editor)." >&2
    fi
    out="$(ed_psql "${UNA[@]}" -d "$BD" -c '\o /dev/null' -f "$cargar" -f "$TMP/resumen.sql" 2>&1)"
    rc=$?
    echo "$out"
    if [ $rc -ne 0 ]; then echo "FALLÓ $etiqueta (psql salió con $rc)" >&2; exit 2; fi
    fallan="$(printf '%s\n' "$out" | sed -n 's/^PRUEBAS .* fallan=\([0-9]*\) .*/\1/p' | tail -n 1)"
    [ "${fallan:-0}" != "0" ] && salida=1
  else
    echo "== $etiqueta (editor_sql)"
    ed_psql "${UNA[@]}" -d "$BD" -f "$cargar" || { echo "FALLÓ $etiqueta" >&2; exit 2; }
  fi
done

echo "== Listo. La base $BD queda creada (bórrala con: $0 --borrar $BD)"
exit $salida
