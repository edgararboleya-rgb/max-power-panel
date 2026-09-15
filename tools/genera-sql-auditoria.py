#!/usr/bin/env python3
"""Auditoría del catálogo → SQL en tres bloques (A: antes de las recetas,
B: cuando Edgar lo mire, C: solo mirar). Entrada: uno o más JSON de acciones
{acciones:[{item, accion, unidad, precio, horas, nuevo_nombre, bloque, razon,
afecta, fuente}]}. Cada nombre se valida contra el export del catálogo: lo que
no exista exacto se lista y NO sale al SQL. Los UPDATE llevan la condición del
valor actual, así que si Edgar ya corrigió algo a mano, la sentencia no hace
nada en vez de pisarlo.
Uso: python3 tools/genera-sql-auditoria.py acciones1.json [acciones2.json ...] > e9g.sql
"""
import json, re, sys, collections

CAT = json.load(open('/home/user/max-power-app/docs/takeoff/fuente/catalogo-supabase.json'))
def norm(s): return re.sub(r'\s+', ' ', str(s or '')).strip().upper()
EXACT = {c['item']: c for c in CAT}
POR_NORM = collections.defaultdict(list)
for c in CAT: POR_NORM[norm(c['item'])].append(c)
def q(s): return "'" + str(s).replace("'", "''") + "'"
def n(x): return ('%.6f' % float(x)).rstrip('0').rstrip('.') if x is not None else None

acciones = []
for f in sys.argv[1:]:
    d = json.load(open(f))
    acciones += d['acciones'] if isinstance(d, dict) else d

fuera, vistos, limpias = [], set(), []
for a in acciones:
    it = a.get('item', '')
    if a.get('accion') != 'alta' and it not in EXACT:
        fuera.append((it, [c['item'] for c in POR_NORM.get(norm(it), [])])); continue
    k = (it, a.get('accion'))
    if k in vistos: continue
    vistos.add(k); limpias.append(a)

por_bloque = collections.defaultdict(list)
for a in limpias: por_bloque[a.get('bloque', 'C')].append(a)

O = []; A = O.append
A('-- ' + '=' * 69)
A('-- E9g · Lo que encontró la auditoría del catálogo (16/09)')
A('--')
A('-- 1.084 filas revisadas por 17 auditores, cada hallazgo atacado por un')
A('-- escéptico, y el conjunto pasado por tres lentes (dinero, coherencia y')
A('-- riesgo). Aquí solo está lo que sobrevivió. Los nombres se comprobaron')
A('-- carácter por carácter contra tu export: cada UPDATE encuentra su fila.')
A('--')
A('-- TRES BLOQUES. No corras el archivo entero de una.')
A('--   A · antes de usar las recetas nuevas: unidades rotas, duplicados que')
A('--       el motor resuelve al azar, horas copiadas de otra fila, precios de')
A('--       tus propias facturas. Confianza alta.')
A('--   B · cuando lo mires: errores claros pero de menos dinero, o números')
A('--       derivados de la escalera de la familia (dicen «provisional»).')
A('--   C · solo mirar: dependen de un dato que solo tú tienes (albarán,')
A('--       cotización) o los verificadores no se pusieron de acuerdo.')
A('--')
A('-- Cada UPDATE lleva el valor ACTUAL como condición: si tú ya lo cambiaste')
A('-- a mano, la sentencia no hace nada. Nunca pisa lo tuyo.')
A('--')
A('-- LA REGLA QUE MANDA: tus números del Excel «Standart Estimating» son la verdad.')
A('-- Las filas importadas el 14/09 (el bloque en minúsculas: CATV, RJ45, Cat6 cable,')
A('-- EV chargers) son las sospechosas. Donde un hallazgo quería pisar un número TUYO')
A('-- con uno derivado, se quitó de A: va en C como pregunta, o se restauró el tuyo.')
A('--')
A('-- LO QUE NO ESTÁ AQUÍ, a propósito: los $0 de equipo grande (trafos, main')
A('-- breakers, disconnects, distribution panels, ATS, UPS, bus duct). Esa es tu')
A('-- regla de la casa —«va por cotización»— y el estimador ya lo avisa. Un $0')
A('-- grita; un número de internet se queda callado y lo firmas.')
A('-- ' + '=' * 69)
A('')
A('-- Antes de nada: una foto del catálogo, por si hay que volver atrás.')
A('create table if not exists catalogo_items_respaldo_20260916 as select * from catalogo_items;')
A('')
A('-- ' + '-' * 69)
A('-- BLOQUE 0 · YA CORRIDO el 16/09 (queda aquí de registro; si lo vuelves a correr no pasa nada)')
A('-- ' + '-' * 69)
A('-- alter table estimados add column if not exists notas text;')
A("-- delete from catalogo_items where upper(btrim(regexp_replace(item,'\\\\s+',' ','g'))) = '1G PLASTIC COVER RECEPTACLE' and coalesce(precio,0) < 0.30;")
A("-- update catalogo_items set item = 'DOWN LIGHT - INSTALL ONLY' where coalesce(precio,0) = 0 and btrim(item) = 'DOWN LIGHT';")
A("-- update alias_takeoff set item = 'LIGHTING RELAY' where item = 'LIGHTING  RELAY';  delete from catalogo_items where item = 'LIGHTING  RELAY';")
A("-- update alias_takeoff set item = '10A FUSES' where item = '10A  FUSES';  delete from catalogo_items where item = '10A  FUSES';")
A('')
A('-- ' + '-' * 69)
A('-- BLOQUE 0b · LO QUE LE FALTÓ AL BLOQUE 0 (lo vieron los verificadores)')
A('-- ' + '-' * 69)
A('-- (a) Copia de los estimados. Los verificadores comprobaron una cosa que yo te')
A('--     había dicho al revés: un estimado CONGELADO no guarda copia de sus líneas.')
A('--     El número que congelaste (bid_final) sí se queda fijo, pero el detalle se')
A('--     recalcula con el catálogo de hoy cada vez que lo abres. O sea: el bloque A')
A('--     mueve el detalle de TODOS tus estimados, viejos y nuevos. El total que')
A('--     firmaste no cambia; lo que hay debajo, sí. Por eso la copia.')
A('create table if not exists estimados_respaldo_20260916 as select * from estimados;')
A('create table if not exists estimado_items_respaldo_20260916 as select * from estimado_items;')
A('')
A("-- (b) El DOWN LIGHT del plano. Al renombrar la fila de $0 (que ERA LA TUYA: en")
A("--     tu Excel DOWN LIGHT es $0 / 0,8 h, la luminaria la pone el dueño, como en")
A("--     Stuart y UM), el alias 'DOWN LIGHT' de Bluebeam se quedó apuntando a un")
A("--     nombre que ya no existe y cae en la fila importada de $55 / 0,75 h. Desde")
A("--     hoy cada down light contado en el plano entra a $55. Si quieres seguir")
A("--     como siempre ($0, la pone el dueño), corre esto:")
A("update alias_takeoff set item = 'DOWN LIGHT - INSTALL ONLY' where btrim(item) = 'DOWN LIGHT';")
A("--     Si prefieres que el plano cobre la luminaria a $55, en vez de eso:")
A("--     update alias_takeoff set item = 'DOWN LIGHT' where btrim(item) = 'DOWN LIGHT';")
A("--     (Las dos recetas DOWN LIGHT — MC / EMT usan la de $55; si va a $0, dímelo y las cambio.)")
A('')
A("-- (c) Higiene de la tabla de alias: la unidad que dice el alias tiene que ser la")
A("--     del catálogo. No mueve dinero (la ruta lee alias, item y factor), pero es")
A("--     lo que se exporta después y confunde.")
A("update alias_takeoff set unidad = 'MLF' where item = '14/4 FPL WET LOC. AQ-246' and unidad = 'EA';")
A("update alias_takeoff set unidad = 'E'   where item = '2\" CABLE TO STRUT SUPPORT' and unidad = 'FT';")
A('')
A("-- Comprobar duplicados: tiene que salir 0 filas.")
A("-- select upper(btrim(regexp_replace(item,'\\\\s+',' ','g'))) n, count(*) from catalogo_items group by 1 having count(*) > 1;")
A('')

def sentencia(a):
    it, acc = a['item'], a.get('accion')
    cat = EXACT.get(it) or {}
    sets, conds = [], []
    if acc == 'update':
        if a.get('unidad'): sets.append('unidad = ' + q(a['unidad'])); conds.append('unidad = ' + q(cat.get('unidad', '')))
        if a.get('precio') is not None: sets.append('precio = ' + n(a['precio'])); conds.append('coalesce(precio,0) = ' + n(cat.get('precio') or 0))
        if a.get('horas') is not None: sets.append('horas_unidad = ' + n(a['horas'])); conds.append('coalesce(horas_unidad,0) = ' + n(cat.get('horas_unidad') or 0))
        if not sets: return None
        return 'update catalogo_items set ' + ', '.join(sets) + '\n   where item = ' + q(it) + ' and ' + ' and '.join(conds) + ';'
    if acc == 'renombrar':
        return 'update catalogo_items set item = ' + q(a['nuevo_nombre']) + ' where item = ' + q(it) + ';'
    if acc == 'borrar':
        return 'delete from catalogo_items where item = ' + q(it) + ' and coalesce(precio,0) = ' + n(cat.get('precio') or 0) + ';'
    return None

def actual(a):
    c = EXACT.get(a['item']) or {}
    return '%s · $%s · %s h' % (c.get('unidad', '?'), c.get('precio'), c.get('horas_unidad'))

def bloque(letra, titulo, comentar):
    lst = por_bloque.get(letra, [])
    A('-- ' + '-' * 69)
    A('-- BLOQUE %s · %s  (%d)' % (letra, titulo, len(lst)))
    A('-- ' + '-' * 69)
    # primero updates/altas, despues renombres, al final borrados (con su repunte antes)
    orden = {'update': 0, 'alta': 1, 'renombrar': 2, 'borrar': 3, 'mirar': 4}
    for a in sorted(lst, key=lambda x: orden.get(x.get('accion'), 9)):
        A('')
        A('-- %s   [hoy: %s]' % (a['item'], actual(a)))
        for linea in re.sub(r'\s+', ' ', a.get('razon', '')).strip().split('. '):
            if linea.strip(): A('--   ' + linea.strip().rstrip('.') + '.')
        if a.get('afecta'): A('--   AFECTA: ' + re.sub(r'\s+', ' ', a['afecta']).strip())
        if a.get('accion') == 'mirar':
            A('--   (solo mirar: sin sentencia)')
            continue
        if a.get('accion') == 'alta':
            A('--   (alta pendiente: dala tú con tu precio; sin sentencia)')
            continue
        s = sentencia(a)
        if not s: continue
        if a.get('accion') in ('borrar', 'renombrar') and a.get('afecta'):
            A('--   ⚠ PRIMERO repuntar lo que apunta a este nombre (ver AFECTA); si no, se queda huérfano.')
        for l in s.split('\n'): A(('-- ' if comentar else '') + l)
    A('')

bloque('A', 'CORRER ANTES DE USAR LAS RECETAS NUEVAS', comentar=False)
bloque('B', 'CUANDO LO MIRES — descomenta lo que aceptes', comentar=True)
bloque('C', 'SOLO MIRAR — hace falta un dato tuyo', comentar=True)

A('-- ' + '-' * 69)
A('-- COMPROBAR (después del bloque A)')
A('-- ' + '-' * 69)
A("-- select item, unidad, precio, horas_unidad from catalogo_items")
A("--  where item in (" + ', '.join(q(a['item']) for a in por_bloque.get('A', []) if a.get('accion') == 'update') + ")")
A("--  order by item;")
sys.stdout.write('\n'.join(O) + '\n')
sys.stderr.write('%d acciones → A %d · B %d · C %d · fuera %d\n' % (len(limpias), len(por_bloque.get('A', [])), len(por_bloque.get('B', [])), len(por_bloque.get('C', [])), len(fuera)))
for it, sug in fuera: sys.stderr.write('  FUERA (no existe exacto): %r  ¿será? %s\n' % (it, sug))
