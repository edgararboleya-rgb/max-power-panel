#!/usr/bin/env python3
# =====================================================================
# partir-c6.py — c6-banco.sql en DOS partes para pegar en el SQL Editor
# de Supabase, cuando el archivo entero no entra (el editor protesta por
# su tamaño: pasa del 1,2 MB).
#
#   python3 pruebas/conta/partir-c6.py              escribe las dos partes
#   python3 pruebas/conta/partir-c6.py --comprobar  no escribe nada: dice
#                                                   si las partes que hay
#                                                   son las de c6-banco.sql
#                                                   de hoy (sale 1 si no)
#
# LA FUENTE SIGUE SIENDO docs/conta/c6-banco.sql (con su historia y sus
# explicaciones). Las partes se GENERAN con este script, no se editan a
# mano: docs/conta/c6-banco-parte1.sql y docs/conta/c6-banco-parte2.sql.
#
# Cómo corta:
#   · en una frontera de sentencia de nivel superior: fuera de un cuerpo
#     $$…$$ (o $f$…$f$), de una cadena '…' o "…" y de un comentario; y
#     justo al empezar una sección numerada del archivo («-- 5 · …»), la que
#     deja las dos partes más parejas. Ninguna sentencia se parte;
#   · cada parte, menos de 650.000 bytes (si no se puede, no escribe nada y
#     lo dice).
# Qué lleva cada una:
#   · la parte 1: una cabecera corta, y del «set local lock_timeout» del
#     principio (con las precondiciones: MX000 si faltan c2, c3 o c4 o son
#     viejas) hasta el corte. La historia de las rondas (la cabecera larga,
#     solo comentarios) se queda en c6-banco.sql. Termina con un select que
#     dice que ahora va la parte 2;
#   · la parte 2: una cabecera corta, su «set local lock_timeout», LA GUARDA
#     —si fn_banco_version() no es la marca de esta versión (la parte 1 de
#     esta misma versión no se pegó), para con MX000 y no toca nada—, y del
#     corte al final: los sellos (las huellas del banco y las de c2) y el
#     resumen corto de siempre.
# Las dos juntas, pegadas en orden, dejan la base IGUAL que el archivo
# entero (lo comprueba pruebas/conta/c6-partes.sh con la foto del
# catálogo), y cada una se puede pegar dos veces.
# =====================================================================
import os
import re
import sys

TOPE = 650_000
AQUI = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.normpath(os.path.join(AQUI, '..', '..', 'docs', 'conta'))
FUENTE = os.path.join(DOCS, 'c6-banco.sql')
PARTE1 = os.path.join(DOCS, 'c6-banco-parte1.sql')
PARTE2 = os.path.join(DOCS, 'c6-banco-parte2.sql')


def sentencias(s):
    """Las sentencias de nivel superior de s: (inicio, fin) de cada una,
    con su «;». Salta comentarios (-- y /* */, anidados) y no corta dentro
    de una cadena, de un identificador entre comillas ni de un cuerpo con
    dólares ($$, $f$, $b$…)."""
    i, n, inicio = 0, len(s), None
    while i < n:
        c = s[i]
        if s.startswith('--', i):
            j = s.find('\n', i)
            i = n if j < 0 else j + 1
            continue
        if s.startswith('/*', i):
            prof, i = 1, i + 2
            while i < n and prof:
                if s.startswith('/*', i):
                    prof, i = prof + 1, i + 2
                elif s.startswith('*/', i):
                    prof, i = prof - 1, i + 2
                else:
                    i += 1
            continue
        if c.isspace():
            i += 1
            continue
        if inicio is None:
            inicio = i
        if c == "'":
            i += 1
            while i < n:
                if s[i] == "'":
                    if i + 1 < n and s[i + 1] == "'":
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
            continue
        if c == '"':
            j = s.find('"', i + 1)
            if j < 0:
                raise SystemExit('partir-c6: un identificador entre comillas sin cerrar')
            i = j + 1
            continue
        if c == '$':
            m = re.match(r'\$([A-Za-z_][A-Za-z0-9_]*)?\$', s[i:i + 80])
            if m:
                tag = m.group(0)
                j = s.find(tag, i + len(tag))
                if j < 0:
                    raise SystemExit('partir-c6: un cuerpo %s sin cerrar' % tag)
                i = j + len(tag)
                continue
        if c == ';':
            yield inicio, i + 1
            inicio = None
        i += 1
    if inicio is not None:
        raise SystemExit('partir-c6: el archivo termina con una sentencia sin su «;»')


def marca_de(s):
    m = re.search(r'create or replace function public\.fn_banco_version\(\)[\s\S]*?select (\d{10})::bigint', s)
    if not m:
        raise SystemExit('partir-c6: no encuentro la marca de la versión (fn_banco_version) en c6-banco.sql')
    return m.group(1)


def partes():
    s = open(FUENTE, encoding='utf-8').read()
    marca = marca_de(s)
    sts = list(sentencias(s))
    # Dónde empieza lo que se pega: el comentario del «set local
    # lock_timeout» del principio (la cabecera larga, antes, es historia).
    k = s.find('set local lock_timeout')
    if k < 0 or not any(a == k for a, _ in sts):
        raise SystemExit('partir-c6: no encuentro el «set local lock_timeout» del principio como sentencia')
    ini = s.rfind('\n-- (Lo primero', 0, k)
    ini = k if ini < 0 else ini + 1
    # Las fronteras posibles: entre dos sentencias, donde empieza el bloque
    # de comentario de una sección numerada («-- ====» y «-- N · …»).
    fins = [b for _, b in sts]
    cortes = []
    for m in re.finditer(r'(?m)^-- =+\n-- (\d+) · ', s):
        p = m.start()
        if p <= ini:
            continue
        # (fuera de toda sentencia: la anterior ya terminó y la siguiente
        # empieza después)
        prev = max((b for b in fins if b <= p), default=None)
        dentro = any(a < p < b for a, b in sts)
        if prev is not None and not dentro:
            cortes.append((p, m.group(1)))
    if not cortes:
        raise SystemExit('partir-c6: no hay ninguna sección donde cortar')
    cab1 = cabecera(1, marca)
    cab2 = cabecera(2, marca) + guarda(marca)
    fin1 = final1(marca)
    mejor = None
    for p, sec in cortes:
        t1 = cab1 + s[ini:p] + fin1
        t2 = cab2 + s[p:]
        b1, b2 = len(t1.encode('utf-8')), len(t2.encode('utf-8'))
        if b1 < TOPE and b2 < TOPE and (mejor is None or max(b1, b2) < mejor[0]):
            mejor = (max(b1, b2), t1, t2, sec, b1, b2)
    if mejor is None:
        tam = len(s[ini:].encode('utf-8'))
        raise SystemExit('partir-c6: ninguna sección deja las dos partes por debajo de %d bytes (lo que se pega mide %d)'
                         % (TOPE, tam))
    return marca, mejor


def cabecera(n, marca):
    return f"""-- =====================================================================
-- C6 · EL BANCO — c6-banco.sql, PARTE {n} DE 2 (marca {marca}).
-- GENERADA por pruebas/conta/partir-c6.py desde docs/conta/c6-banco.sql:
-- no se edita a mano. Es lo mismo que el archivo entero, en dos pegados,
-- para cuando el SQL Editor de Supabase no deja pegarlo de una vez. La
-- historia y el porqué de cada cosa están en c6-banco.sql.
--   1. Pega c6-banco-parte1.sql y ejecuta (dice «ahora la parte 2»).
--   2. Pega c6-banco-parte2.sql y ejecuta: termina con el resumen corto de
--      siempre, todo en true.
-- La parte 2 sin la parte 1 de esta misma marca para con MX000 y no toca
-- nada. Cada una se puede pegar otra vez. Entre las dos el banco queda a
-- medias (sus huellas sin sellar: el control lo dice en rojo): no uses la
-- app del banco hasta pegar la 2.
-- =====================================================================
"""


def guarda(marca):
    return f"""set local lock_timeout = '500ms';

-- LA GUARDA de la parte 2: la parte 1 de ESTA versión tiene que estar
-- pegada (su fn_banco_version() dice {marca}). Si no, para aquí y no toca
-- nada (MX000).
do $$
declare
  v_ver bigint;
begin
  if to_regprocedure('public.fn_banco_version()') is not null then
    execute 'select public.fn_banco_version()' into v_ver;
  end if;
  if v_ver is distinct from {marca} then
    raise exception using
      errcode = 'MX000',
      message = format('c6-banco (parte 2 de 2) NO se aplicó, no se tocó nada: antes va la parte 1 de esta misma versión '
                       '(marca {marca}), y la base tiene %s. Pega c6-banco-parte1.sql y después esta; o el archivo '
                       'entero, c6-banco.sql.',
                       case when v_ver is null then 'el banco sin pegar' else 'el banco de la marca ' || v_ver end);
  end if;
end $$;

"""


def final1(marca):
    return f"""

-- (Fin de la parte 1 de 2.)
select 'c6 · parte 1 de 2' as control, public.fn_banco_version() = {marca} as ok,
       to_jsonb('Pegada la parte 1 de c6-banco.sql (marca {marca}). Ahora pega c6-banco-parte2.sql: hasta entonces el banco '
                'está a medias y su control lo dice en rojo.'::text) as detalle;
"""


def main():
    comprobar = '--comprobar' in sys.argv[1:]
    marca, (_, t1, t2, sec, b1, b2) = partes()
    if comprobar:
        hoy1 = open(PARTE1, encoding='utf-8').read() if os.path.exists(PARTE1) else None
        hoy2 = open(PARTE2, encoding='utf-8').read() if os.path.exists(PARTE2) else None
        if hoy1 == t1 and hoy2 == t2:
            print(f'partir-c6: las partes son las de c6-banco.sql de hoy (marca {marca}; corte en la sección {sec}; '
                  f'{b1} y {b2} bytes)')
            return 0
        print('partir-c6: las partes NO son las de c6-banco.sql de hoy: vuelve a correr python3 pruebas/conta/partir-c6.py')
        return 1
    with open(PARTE1, 'w', encoding='utf-8', newline='\n') as f:
        f.write(t1)
    with open(PARTE2, 'w', encoding='utf-8', newline='\n') as f:
        f.write(t2)
    print(f'partir-c6: marca {marca}; corte al empezar la sección {sec}; parte 1 {b1} bytes, parte 2 {b2} bytes '
          f'(tope {TOPE})')
    return 0


if __name__ == '__main__':
    sys.exit(main())
