#!/usr/bin/env bash
# =====================================================================
# c6-partes.sh — c6-banco.sql en sus DOS PARTES (c6-banco-parte1.sql y
# c6-banco-parte2.sql, que genera partir-c6.py) deja la base IGUAL que el
# archivo entero: lo prueba con la foto del catálogo.
#
#   ./c6-partes.sh [prefijo]          (por defecto c6_partes)
#   PLANTILLA=<bd> ./c6-partes.sh …   (empezar de una base que ya tiene el
#                                       banco: la de producción simulada,
#                                       con una versión anterior y datos)
#
# Hace, cada pegado en su transacción como el SQL Editor (editor_sql):
#   1. Las partes son las de c6-banco.sql de hoy (partir-c6.py --comprobar)
#      y cada una mide menos de 650.000 bytes.
#   2. Base A: c1, c2, c3, c4 (o la PLANTILLA) + c6-banco.sql ENTERO.
#      Base B: lo mismo + la parte 1 + la parte 2.
#      La foto del catálogo de las dos es la misma: cada función (su
#      definición entera, con su SECURITY DEFINER, su search_path y sus
#      permisos), cada vista (su definición, sus opciones y permisos), cada
#      tabla (columnas, restricciones, RLS, permisos), índices, policies,
#      triggers, comentarios, las huellas del banco y las de c2 (sin la hora
#      del sello), y los descriptores sembrados.
#   3. La parte 2 SIN la parte 1 (en una base C con lo de antes): para con
#      MX000 y no toca nada (la foto de C, igual que antes de pegarla).
#   4. Otra vez la parte 1 y la parte 2 en B (las dos se pueden pegar dos
#      veces): la foto sigue igual que la de A.
#   5. c6-pruebas.sql en B: nada en rojo.
# Salida: 0 todo bien · 1 algo falla · 2 no se pudo cargar. Borra sus
# bases al terminar (con CONSERVAR=1 las deja).
# =====================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$DIR/../../docs/conta"
PRE="${1:-c6_partes}"
A="${PRE}_a"; B="${PRE}_b"; C="${PRE}_c"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
borrar() { for x in "$A" "$B" "$C"; do "$DIR/correr.sh" --borrar "$x" >/dev/null 2>&1; done; }
if [ "${CONSERVAR:-0}" = "1" ]; then
  trap 'echo "(Las bases $A, $B y $C quedan creadas: ./correr.sh --borrar …)"; rm -rf "$TMP"' EXIT
else
  trap 'borrar; rm -rf "$TMP"' EXIT
fi

if [ -n "${BANCO_SU:-}" ]; then read -r -a PSQL_SU <<< "$BANCO_SU"
elif [ "$(id -u)" = "0" ]; then PSQL_SU=(runuser -u postgres -- psql)
else PSQL_SU=(psql -U postgres); fi
su_psql() { env -u PGHOST "${PSQL_SU[@]}" -X -q -v ON_ERROR_STOP=1 -p "${PGPORT:-5432}" "$@"; }
ed() { PGPASSWORD=editor_sql psql -X -q -h "${PGHOST:-127.0.0.1}" -p "${PGPORT:-5432}" -U editor_sql -v ON_ERROR_STOP=1 "$@"; }

malos=0
revisa() {  # revisa <descripción> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FALLA: $1: esperaba «$2», salió «$3»"; malos=1; fi
}

# La foto del catálogo: una fila por objeto, con el md5 de lo que lo define.
cat > "$TMP/foto.sql" <<'SQL'
\pset tuples_only on
\pset format unaligned
with f as (
  -- funciones: su definición entera (cuerpo, SECURITY DEFINER, SET), sus
  -- permisos y su comentario (el de las huellas, sin la hora del sello)
  select 'funcion' as tipo, p.oid::regprocedure::text as objeto,
         md5(concat_ws('|', pg_get_functiondef(p.oid), array_to_string(p.proacl, ','),
                       regexp_replace(coalesce(obj_description(p.oid, 'pg_proc'), ''), '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}',
                                      '<sello>', 'g'))) as md5
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind in ('f', 'p')
     -- (las de las huellas selladas, que llevan oid —distintos en cada
     -- base—: abajo, fila por fila)
     and p.oid not in (to_regprocedure('public.fn_banco_huellas()'), to_regprocedure('public.fn_estados_huellas()'),
                       to_regprocedure('public.fn_libro_huellas()'))
  union all
  select 'relacion', c.relname,
         md5(concat_ws('|', c.relkind, c.relrowsecurity, c.relforcerowsecurity, array_to_string(c.relacl, ','),
                       array_to_string(c.reloptions, ','), case when c.relkind = 'v' then pg_get_viewdef(c.oid) end,
                       coalesce(obj_description(c.oid, 'pg_class'), ''),
                       (select string_agg(concat_ws(':', a.attnum, a.attname, format_type(a.atttypid, a.atttypmod), a.attnotnull,
                                                    pg_get_expr(d.adbin, d.adrelid), array_to_string(a.attacl, ','),
                                                    col_description(c.oid, a.attnum)), ';' order by a.attnum)
                          from pg_attribute a left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
                         where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped),
                       (select string_agg(con.conname || '=' || pg_get_constraintdef(con.oid), ';' order by con.conname)
                          from pg_constraint con where con.conrelid = c.oid)))
    from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v', 'm', 'S')
  union all
  select 'indice', i.indexname, md5(i.indexdef) from pg_indexes i where i.schemaname = 'public'
  union all
  select 'policy', pl.tablename || '.' || pl.policyname,
         md5(concat_ws('|', pl.permissive, array_to_string(pl.roles, ','), pl.cmd, pl.qual, pl.with_check))
    from pg_policies pl where pl.schemaname = 'public'
  union all
  select 'trigger', t.tgrelid::regclass::text || '.' || t.tgname, md5(pg_get_triggerdef(t.oid) || '|' || t.tgenabled::text)
    from pg_trigger t join pg_class c on c.oid = t.tgrelid
   where c.relnamespace = 'public'::regnamespace and not t.tgisinternal
)
select tipo || ' ' || objeto || ' ' || md5 from f order by 1;
-- (las huellas selladas de c2, c4 y el banco, fila por fila, sin las de las
-- tablas de c2 ni las de las vistas —llevan oid, distintos en cada base: las
-- tablas y las vistas se comparan arriba por su definición—; y los
-- descriptores sembrados, si ya hay banco)
select to_regclass('public.banco_descriptores') is not null as hay_banco \gset
\if :hay_banco
select 'descriptor ' || d.clave || ' ' || md5(concat_ws('|', d.patron, d.cuenta)) from public.banco_descriptores d order by 1;
select 'huella_banco ' || h.tipo || ':' || h.objeto || ' ' || h.md5 from public.fn_banco_huellas() h where h.tipo <> 'vista' order by 1;
\endif
select 'huella_c2 ' || h.tipo || ':' || h.objeto || ' ' || h.md5 from public.fn_libro_huellas() h where h.tipo <> 'tabla' order by 1;
select to_regprocedure('public.fn_estados_huellas()') is not null as hay_c4 \gset
\if :hay_c4
select 'huella_c4 ' || h.tipo || ':' || h.objeto || ' ' || h.md5 from public.fn_estados_huellas() h where h.tipo <> 'vista' order by 1;
\endif
SQL

# Lo que hay antes de c6 (o la plantilla).
base() {  # base <bd>
  if [ -n "${PLANTILLA:-}" ]; then
    su_psql -d postgres -c "drop database if exists \"$1\" with (force)" -c "create database \"$1\" template \"$PLANTILLA\" owner editor_sql" \
      >/dev/null || return 2
    su_psql -d postgres -c "alter database \"$1\" set search_path = \"\$user\", public, extensions" >/dev/null || return 2
  else
    "$DIR/correr.sh" "$1" "$DIR/03-storage-simulacro.sql" "$DOCS/c1-plan-de-cuentas.sql" "$DOCS/c2-libro.sql" "$DOCS/c3-puentes.sql" \
      "$DOCS/c4-estados.sql" > "$TMP/base_$1.log" 2>&1 \
      || { echo "   (la causa, el final de lo que dijo correr.sh:)" >&2; tail -n 8 "$TMP/base_$1.log" >&2; return 2; }
  fi
}
pegar() {  # pegar <bd> <archivo> → su salida en $TMP/<bd>.<n>.log; rc de psql
  ed -1 -d "$1" -f "$2" > "$TMP/pegar.log" 2>&1
}
foto() {  # la foto de <bd>; si la consulta falla, lo dice (una foto rota no se compara)
  if ! ed -d "$1" -f "$TMP/foto.sql" > "$TMP/foto1.txt" 2>&1; then
    echo "FALLA: la foto de $1 no se pudo sacar: $(head -3 "$TMP/foto1.txt")" >&2; malos=1
  fi
  cat "$TMP/foto1.txt"
}

echo "== 1. Las partes, las de hoy y de su tamaño"
python3 "$DIR/partir-c6.py" --comprobar; revisa "las partes son las de c6-banco.sql de hoy" "0" "$?"
for p in 1 2; do
  t=$(wc -c < "$DOCS/c6-banco-parte$p.sql")
  revisa "la parte $p mide menos de 650.000 bytes" "si" "$([ "$t" -lt 650000 ] && echo si || echo "no ($t)")"
done

echo "== 2. A: c6-banco.sql entero; B: la parte 1 y la parte 2"
base "$A" || { echo "FALLÓ la base $A" >&2; exit 2; }
base "$B" || { echo "FALLÓ la base $B" >&2; exit 2; }
base "$C" || { echo "FALLÓ la base $C" >&2; exit 2; }
foto "$C" > "$TMP/foto_c0.txt"
pegar "$A" "$DOCS/c6-banco.sql"; revisa "A: el archivo entero entra" "0" "$?"
pegar "$B" "$DOCS/c6-banco-parte1.sql"; revisa "B: la parte 1 entra" "0" "$?"
revisa "B: la parte 1 dice que ahora va la 2" "1" "$(grep -cE 'c6 · parte 1 de 2 +\| t +\|' "$TMP/pegar.log")"
pegar "$B" "$DOCS/c6-banco-parte2.sql"; revisa "B: la parte 2 entra" "0" "$?"
revisa "B: el resumen corto de la parte 2, todo en true" "0" "$(grep -cE '^ *(c6|banco) · .*\| f +\|' "$TMP/pegar.log")"
revisa "B: el resumen corto tiene sus 7 filas" "7" "$(grep -cE '^ *(c6|banco) · .*\| t +\|' "$TMP/pegar.log")"
foto "$A" > "$TMP/foto_a.txt"; foto "$B" > "$TMP/foto_b.txt"
n=$(wc -l < "$TMP/foto_a.txt")
revisa "la foto tiene sus objetos (más de 1.000: funciones, tablas, vistas, índices, policies, triggers, huellas)" "si" \
  "$([ "$n" -gt 1000 ] && echo si || echo "no ($n)")"
revisa "la foto del catálogo de B es la de A ($n objetos)" "0" "$(diff "$TMP/foto_a.txt" "$TMP/foto_b.txt" | grep -c '^[<>]')"
diff "$TMP/foto_a.txt" "$TMP/foto_b.txt" | head -10

echo "== 3. La parte 2 sin la parte 1"
pegar "$C" "$DOCS/c6-banco-parte2.sql"; rc=$?
revisa "C: la parte 2 sola no entra" "3" "$rc"
revisa "C: dice MX000 y que antes va la parte 1" "1" "$(grep -c 'parte 2 de 2) NO se aplicó, no se tocó nada' "$TMP/pegar.log")"
foto "$C" > "$TMP/foto_c1.txt"
revisa "C: la foto, igual que antes" "0" "$(diff "$TMP/foto_c0.txt" "$TMP/foto_c1.txt" | grep -c '^[<>]')"

echo "== 4. Otra vez la parte 1 y la parte 2 en B"
pegar "$B" "$DOCS/c6-banco-parte1.sql"; revisa "B: la parte 1 otra vez" "0" "$?"
pegar "$B" "$DOCS/c6-banco-parte2.sql"; revisa "B: la parte 2 otra vez" "0" "$?"
foto "$B" > "$TMP/foto_b2.txt"
revisa "la foto de B sigue siendo la de A" "0" "$(diff "$TMP/foto_a.txt" "$TMP/foto_b2.txt" | grep -c '^[<>]')"

echo "== 5. c6-pruebas.sql en B"
cat > "$TMP/resumen.sql" <<'SQL'
\o
\pset tuples_only on
\pset format unaligned
select format('PRUEBAS total=%s ok=%s fallan=%s omitidas=%s', count(*), count(*) filter (where ok), count(*) filter (where not ok),
              count(*) filter (where ok is null)) from _pruebas;
SQL
ed -1 -d "$B" -c '\o /dev/null' -f "$DOCS/c6-pruebas.sql" -f "$TMP/resumen.sql" > "$TMP/pruebas.out" 2>&1; rc=$?
echo "     $(grep '^PRUEBAS' "$TMP/pruebas.out")"
revisa "c6-pruebas corrió entero" "0" "$rc"
revisa "c6-pruebas: nada en rojo" "0" "$(grep -o 'fallan=[0-9]*' "$TMP/pruebas.out" | cut -d= -f2)"

if [ "$malos" = "0" ]; then echo "PARTES c6 ok"; exit 0; else echo "PARTES c6 FALLA"; exit 1; fi
