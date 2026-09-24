#!/usr/bin/env bash
# =====================================================================
# c2-pegado.sh — lo que c2-pruebas.sql no puede probar porque pasa ANTES
# o AL PEGAR los archivos, no con el libro ya puesto:
#   1. El bloque A pegado SOLO (por error, en Supabase) nace cerrado: anon
#      no lee ni escribe las tablas del libro, y un trabajador no postea
#      ni cierra por las funciones mínimas.
#   2. Si en esa ventana entró algo sin controles (el dueño, con las
#      funciones mínimas: un asiento sin sellar, un período cerrado sin la
#      foto de la cadena), el bloque B se niega con MX000 y no deja nada
#      puesto. Se borra a mano (con el bloque A solo todavía se puede) y
#      entonces el bloque B entra, con los nueve controles en true.
#   3. c2-pruebas.sql pegado antes que c2-libro.sql para con MX000 y un
#      mensaje en español, no con un error de Postgres en inglés.
#   4. Volver a pegar c1 y c2 borra las policies ajenas de las tablas del
#      libro (p. ej. una «Enable read access for all users» del dashboard)
#      y deja todo en true. Pegar c1 otra vez con el libro ya puesto no
#      mueve las huellas de c2.
#
#   ./c2-pegado.sh [prefijo_bd]      (por defecto c2_pegado)
#
# Usa tres bases (<prefijo>_a, <prefijo>_p, <prefijo>_r) y las borra al
# terminar. Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar.
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
PRE="${1:-c2_pegado}"
BA="${PRE}_a"; BP="${PRE}_p"; BR="${PRE}_r"
MARCA='-- ==== BLOQUE B ===='
TMP="$(mktemp -d)"
chmod 755 "$TMP"
trap 'for b in "$BA" "$BP" "$BR"; do "$DIR/correr.sh" --borrar "$b" >/dev/null 2>&1; done; rm -rf "$TMP"' EXIT

ed() { PGPASSWORD=editor_sql psql -X -q -At -v VERBOSITY=verbose -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql "$@"; }

malos=0
bien()  { echo "ok   $*"; }
falla() { echo "FALLA: $*"; malos=1; }

# El bloque B solo, como lo recorta correr.sh.
awk -v m="$MARCA" 'hay || $0 == m { hay = 1; print }' "$DOCS/c2-libro.sql" > "$TMP/c2-B.sql"

# ---------------------------------------------------------------------
echo "== 1. El bloque A solo nace cerrado"
"$DIR/correr.sh" "$BA" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql:A" > "$TMP/a.out" 2>&1 \
  || { cat "$TMP/a.out"; echo "FALLÓ la carga del bloque A" >&2; exit 2; }

GUS='{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}'
POSTEO='{"fecha":"2026-10-05","descripcion":"lo que sea","lineas":[{"cuenta":"6100","monto":"1.00"},{"cuenta":"1010","monto":"-1.00"}]}'

r="$(ed -d "$BA" -c "begin; select set_config('request.jwt.claims', '{\"role\":\"anon\"}', true); set local role anon; select count(*) from asientos; rollback;" 2>&1)"
if grep -q "42501" <<< "$r"; then bien "anon no lee asientos (42501)"; else falla "anon lee asientos: $r"; fi

r="$(ed -d "$BA" -c "begin; select set_config('request.jwt.claims', '{\"role\":\"anon\"}', true); set local role anon; insert into contadores values ('asientos-2027', 7); rollback;" 2>&1)"
if grep -q "42501" <<< "$r"; then bien "anon no escribe en contadores (42501)"; else falla "anon escribe en contadores: $r"; fi

r="$(ed -d "$BA" -c "begin; select set_config('request.jwt.claims', '$GUS', true); set local role authenticated; select fn_postear('$POSTEO'); rollback;" 2>&1)"
if grep -q "42501" <<< "$r"; then bien "un trabajador no postea por la fn_postear mínima (42501)"; else falla "un trabajador posteó con el bloque A solo: $r"; fi

r="$(ed -d "$BA" -c "begin; select set_config('request.jwt.claims', '$GUS', true); set local role authenticated; select fn_cerrar_periodo('2026-10'); rollback;" 2>&1)"
if grep -q "42501" <<< "$r"; then bien "un trabajador no cierra por la fn_cerrar_periodo mínima (42501)"; else falla "un trabajador cerró un período con el bloque A solo: $r"; fi

# ---------------------------------------------------------------------
echo "== 2. El bloque B no se pone encima de datos escritos sin controles"
ed -d "$BA" -c "select fn_postear('$POSTEO'); select fn_cerrar_periodo('2026-10');" > "$TMP/sucio.out" 2>&1 \
  || { cat "$TMP/sucio.out"; echo "FALLÓ escribir los datos sucios" >&2; exit 2; }
r="$(ed -d "$BA" -1 -v ON_ERROR_STOP=1 -f "$TMP/c2-B.sql" 2>&1)"; rc=$?
if [ $rc -ne 0 ] && grep -q "MX000" <<< "$r"; then bien "el bloque B se negó con MX000"; else falla "el bloque B no se negó con MX000 (rc=$rc): $(grep -m1 -i error <<< "$r")"; fi
r="$(ed -d "$BA" -c "select to_regprocedure('public.fn_postear_interno(jsonb)') is null")"
if [ "$r" = "t" ]; then bien "y no dejó nada del bloque B puesto"; else falla "quedó algo del bloque B puesto"; fi

ed -d "$BA" -c "delete from asiento_lineas; delete from asientos; delete from contadores;
                update periodos set estado = 'abierto', cerrado_el = null where estado = 'cerrado';" > "$TMP/limpio.out" 2>&1 \
  || { cat "$TMP/limpio.out"; echo "FALLÓ borrar los datos sucios" >&2; exit 2; }
r="$(ed -d "$BA" -1 -v ON_ERROR_STOP=1 -f "$TMP/c2-B.sql" 2>&1)"; rc=$?
if [ $rc -eq 0 ]; then bien "borrado lo sucio, el bloque B entró"; else falla "el bloque B no entró tras limpiar: $(grep -m1 -i error <<< "$r")"; fi
r="$(ed -d "$BA" -c "select coalesce(string_agg(control, ', '), '') from fn_verificar_cadena() where not ok")"
if [ -z "$r" ]; then bien "fn_verificar_cadena: los nueve controles en true"; else falla "fn_verificar_cadena en false: $r"; fi

# ---------------------------------------------------------------------
echo "== 3. c2-pruebas.sql antes que c2-libro.sql"
r="$("$DIR/correr.sh" "$BP" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-pruebas.sql" 2>&1)"; rc=$?
if [ $rc -eq 2 ] && grep -q "c2-pruebas NO se corrió" <<< "$r"; then
  bien "c2-pruebas paró con su precondición (MX000): $(grep -m1 -o 'c2-pruebas NO se corrió[^·]*' <<< "$r")"
else
  falla "c2-pruebas sin c2-libro no paró con su precondición (rc=$rc): $(grep -m1 -i error <<< "$r")"
fi

# ---------------------------------------------------------------------
echo "== 4. Volver a pegar borra las policies ajenas y no mueve las huellas"
"$DIR/correr.sh" "$BR" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" > "$TMP/r.out" 2>&1 \
  || { cat "$TMP/r.out"; echo "FALLÓ la carga de c1 + c2" >&2; exit 2; }
ed -d "$BR" -c "create policy \"Enable read access for all users\" on public.asiento_lineas for select using (true);
                create policy \"Enable read access for all users\" on public.cuentas for select using (true);" > "$TMP/pol.out" 2>&1 \
  || { cat "$TMP/pol.out"; echo "FALLÓ crear las policies ajenas" >&2; exit 2; }
r="$(ed -d "$BR" -c "select ok from fn_verificar_cadena() where control = 'permisos'")"
if [ "$r" = "f" ]; then bien "con las policies ajenas, permisos en false"; else falla "permisos no vio las policies ajenas ($r)"; fi
ed -d "$BR" -1 -v ON_ERROR_STOP=1 -f "$DOCS/c1-plan-de-cuentas.sql" > "$TMP/c1b.out" 2>&1 \
  || { cat "$TMP/c1b.out"; echo "FALLÓ volver a pegar c1" >&2; exit 2; }
r="$(ed -d "$BR" -c "select coalesce(string_agg(control, ', '), '') from fn_verificar_cadena() where not ok and control <> 'permisos'")"
if [ -z "$r" ]; then bien "pegar c1 otra vez no movió las huellas ni rompió nada"; else falla "tras volver a pegar c1: $r en false"; fi
ed -d "$BR" -1 -v ON_ERROR_STOP=1 -f "$DOCS/c2-libro.sql" > "$TMP/c2b.out" 2>&1 \
  || { cat "$TMP/c2b.out"; echo "FALLÓ volver a pegar c2" >&2; exit 2; }
r="$(ed -d "$BR" -c "select count(*) from pg_policies where schemaname = 'public' and tablename in ('asiento_lineas','cuentas') and policyname = 'Enable read access for all users'")"
if [ "$r" = "0" ]; then bien "volver a pegar c1 y c2 borró las policies ajenas"; else falla "quedan $r policies ajenas"; fi
r="$(ed -d "$BR" -c "select coalesce(string_agg(control, ', '), '') from fn_verificar_cadena() where not ok")"
if [ -z "$r" ]; then bien "fn_verificar_cadena: los nueve controles en true"; else falla "fn_verificar_cadena en false: $r"; fi

[ $malos -eq 0 ] && echo "PEGADO ok" || echo "PEGADO FALLA"
exit $malos
