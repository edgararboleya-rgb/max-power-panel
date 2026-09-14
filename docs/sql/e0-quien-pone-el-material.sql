-- =====================================================================
-- E0 · «Quién pone el material» — Max Power Electrical Solutions
-- Supabase → SQL Editor. Idempotente: se puede correr dos veces.
-- NO toca ningún precio. NO toca ninguna hora. NO mueve ningún bid.
-- Se pega POR BLOQUES, en orden, mirando el bloque 3 entre medias.
--
-- Todos los conteos de aquí abajo están COMPROBADOS contra el catálogo
-- real (1072 items exportados el 14/09): 186 a $0, de ellos 176 con horas.
-- =====================================================================


-- =====================================================================
-- BLOQUE 0 — ANTES DE NADA. Dos consultas que no cambian nada.
-- =====================================================================

-- D0 · ¿La app va a poder ESCRIBIR en catalogo_items?
--      Hasta hoy solo ha hecho INSERT ahí (crearItemCatalogo). Si no sale
--      una policy con cmd = 'UPDATE', el selector del renglón no podrá
--      guardar: la app lo dirá en rojo, pero mejor saberlo antes.
select policyname, cmd, roles, qual, with_check
  from pg_policies
 where schemaname = 'public' and tablename = 'catalogo_items'
 order by cmd, policyname;
-- Si falta la de UPDATE, créala con EL MISMO candado que ya usen las otras
-- (normalmente es_dueno()). No inventes una policy más abierta que las vecinas.

-- D3 · LA PRUEBA DE SEGURIDAD RETROACTIVA.
--      Los renglones de ENSAMBLE leen el precio VIVO del catálogo en cada
--      recálculo (js/app.js:5372 y 5381), también en estimados congelados y
--      convertidos. Los renglones manuales y de takeoff NO: llevan su propio
--      precio copiado. Así que esta consulta dice si poner un precio desde
--      el selector podría mover un bid ya emitido.
select es.nombre as estimado, es.estado, e.nombre as ensamble, ei.item
  from estimado_ensambles ee
  join estimados      es on es.id = ee.estimado_id
  join ensambles       e on e.id  = ee.ensamble_id
  join ensamble_items ei on ei.ensamble_id = e.id
  join catalogo_items  c on upper(btrim(regexp_replace(c.item,'\s+',' ','g')))
                          = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
 where coalesce(c.precio,0) = 0
   and coalesce(ee.cantidad,0) > 0
   and es.estado in ('congelado','convertido');
-- 0 filas  = corregir precios desde el selector es demostrablemente seguro.
-- >0 filas = esos ítems concretos no se tocan hasta que ese estimado cierre.


-- =====================================================================
-- BLOQUE 1 — ESQUEMA. Instantáneo: en PG11+ un add column con default
-- constante es solo metadatos, no reescribe la tabla ni bloquea el
-- catálogo de 1072 filas que la app consulta a diario.
-- =====================================================================

-- POR QUÉ un ítem del catálogo vale $0. NULL = sin clasificar = la app pregunta.
-- OJO: esto NO es una categoría de coste. E13 (markup por categoría) añadirá
-- `categoria_costo` aparte.
alter table catalogo_items add column if not exists cero_motivo   text;
-- null = lo puso la regla de la siembra (el chip sale con «?»)
-- con fecha = lo confirmó Edgar. Un by_owner SIN confirmar NO se imprime
-- en la propuesta del cliente.
alter table catalogo_items add column if not exists cero_revisado date;
-- Coletilla opcional que sale en la línea del contrato ("lo cotiza Graybar").
alter table catalogo_items add column if not exists cero_nota     text;

alter table catalogo_items drop constraint if exists catalogo_items_cero_motivo_chk;
alter table catalogo_items add  constraint catalogo_items_cero_motivo_chk
  check (cero_motivo is null or cero_motivo in
        ('suministro','by_owner','solo_labor','falta_precio','tarifa'));

-- Lo que Edgar decidió en ESTE trabajo. Hoy solo guarda una cosa:
-- qué secciones ya tienen su cotización dentro del precio.
--   { "S:SWITCHGEAR": { "d": "cotizado", "f": "2026-09-14" } }
-- Clave por NOMBRE (no por id) porque los renglones de ensamble y los
-- automáticos no tienen id y nunca lo tendrán sin una tabla nueva.
alter table estimados add column if not exists cero_notas jsonb not null default '{}'::jsonb;

-- Exclusiones a mano, una por línea, en inglés. Es el ÚNICO camino en
-- modo rápido, donde calcularEstimado ignora los ítems por completo.
alter table estimados add column if not exists no_incluye_extra text;

-- El interruptor. cargarEstimador ya convierte config_estimador a
-- {clave: Number(valor)} (js/db.js:665), así que se lee solo.
--   2 = chips + banner + aviso de salida   (por defecto)
--   1 = solo los chips, sin avisos          (si el aviso cansa)
--   0 = la app se comporta EXACTAMENTE como ayer
insert into config_estimador (clave, valor) values ('cero_aviso', 2)
  on conflict (clave) do nothing;

comment on column catalogo_items.cero_motivo is
  'E0 · Por que este item vale $0. NULL = la app pregunta. Solo by_owner CONFIRMADO produce exclusion de contrato. No es una categoria de coste: eso es E13.';
comment on column catalogo_items.cero_revisado is
  'E0 · NULL = lo puso la regla de la siembra (el chip sale con ?). Con fecha = lo dijo Edgar.';
comment on column estimados.cero_notas is
  'E0 · Decisiones de ESTE trabajo. Hoy solo S:<SECCION> => {d:"cotizado"}.';


-- =====================================================================
-- BLOQUE 3 — COMPROBAR. Correr AHORA, antes de sembrar nada.
-- (Va antes del 2 a propósito: mirar primero, tocar después.)
-- =====================================================================

-- Tiene que dar 186 en «(sin clasificar)».
select coalesce(cero_motivo,'(sin clasificar → la app pregunta)') as motivo,
       count(*) as items,
       count(*) filter (where coalesce(horas_unidad,0) > 0) as con_horas
  from catalogo_items
 where coalesce(precio,0) = 0
 group by 1 order by 2 desc;

-- D1 · El reparto por sección, para revisarlo de un vistazo.
select coalesce(seccion,'(sin sección)') as seccion,
       coalesce(cero_motivo,'(sin clasificar)') as motivo,
       count(*) as n,
       left(string_agg(item, ' · ' order by item), 160) as ejemplos
  from catalogo_items
 where coalesce(precio,0) = 0
 group by 1,2 order by 1, 3 desc;


-- =====================================================================
-- BLOQUE 2 — SIEMBRA. EL ORDEN IMPORTA: cada paso solo toca lo que
-- sigue NULL. Nada de esto escribe un precio, ni una hora, ni una sección.
-- Los nombres de sección son los REALES de la base, comprobados uno a uno.
-- =====================================================================

-- (a) SOLO INSTALACIÓN, EL MATERIAL LO PONE EL CLIENTE. 3 filas.
--     Se sella CONFIRMADO porque el nombre es la evidencia y lo escribió
--     Edgar. Es el único estado que llega al papel del cliente, así que
--     entra solo por nombre literal: nada de secciones enteras.
update catalogo_items
   set cero_motivo = 'by_owner', cero_revisado = current_date
 where cero_motivo is null and coalesce(precio,0) = 0
   and item ilike '%INSTALL ONLY%';
-- Esperado: 3 (CEILING FAN, VANITY LIGHT BAR, WALL SCONCE)

-- (b) NO LLEVA MATERIAL NUNCA. 2 filas, también por nombre literal.
--     DEMOLITION NO entra aquí a propósito: un solo_labor falso es el único
--     error irreversible del diseño (pasa de callar a AFIRMAR y no se
--     descubre jamás). Los 8 de DEMOLITION los contesta Edgar.
update catalogo_items
   set cero_motivo = 'solo_labor', cero_revisado = current_date
 where cero_motivo is null and coalesce(precio,0) = 0
   and (item ilike 'SERVICE LABOR%' or item ilike 'SERVICE CALL%'
        or item ilike '%DIAGNOSTIC%');
-- Esperado: 2

-- (c) TARIFAS Y ALLOWANCES QUE SE TECLEAN POR TRABAJO: 0 precio Y 0 horas.
--     Los 9 de PROJECT GENERAL + RADIORA 3 (cabecera de sistema, no es un
--     producto). Sin horas no puede esconder un switchgear: se calla.
update catalogo_items
   set cero_motivo = 'tarifa', cero_revisado = current_date
 where cero_motivo is null
   and coalesce(precio,0) = 0 and coalesce(horas_unidad,0) = 0;
-- Esperado: 10

-- (d) PRECIO QUE FALTA DE VERDAD. Error de dato, no decisión de negocio.
--     El criterio cabe en una frase: una mercancía de almacén nunca llega
--     por cotización del supply house, y un tubo tampoco. Entran los tubos
--     GRS y PVC grandes sin precio, dos bell box, dos soportes de cable y
--     las 16 luminarias viejas que el porte dejó sin sección.
update catalogo_items
   set cero_motivo = 'falta_precio', cero_revisado = current_date
 where cero_motivo is null
   and coalesce(precio,0) = 0 and coalesce(horas_unidad,0) > 0
   and (seccion is null or btrim(seccion) = ''
        or item ilike '%GRS CONDUIT%'
        or item ilike '%PVC CONDUIT%'
        or item ilike '%BELL BOX%'
        or item ilike '%CABLE TO ROD%'
        or item ilike '%BEAM SUPPORT%');
-- Esperado: 25 (16 luminarias sin sección + 2 GRS + 3 PVC + 2 bell box + 2 soportes)

-- (e) MATERIAL POR COTIZACIÓN DEL SUPPLY HOUSE. El $0 es a propósito
--     PERO el dinero sigue siendo de Edgar. Se deja SIN confirmar
--     (cero_revisado null): el chip sale con «?» porque esto lo supuso una
--     regla por sección, no Edgar.
--     OJO: los nombres van EXACTOS como están en la base. 'SECURITY &
--     ACCESS CONTROL' y 'CLOCK + INTERCOM + SOUND' llevan las palabras y
--     los espacios completos; escribirlos de memoria deja 26 ítems fuera.
update catalogo_items
   set cero_motivo = 'suministro'
 where cero_motivo is null
   and coalesce(precio,0) = 0 and coalesce(horas_unidad,0) > 0
   and seccion in ('SWITCHGEAR','FIRE ALARM','SECURITY & ACCESS CONTROL',
                   'CLOCK + INTERCOM + SOUND','CATV');
-- Esperado: 124 (SWITCHGEAR 78, CLOCK+INTERCOM 17, FIRE ALARM 13,
--                SECURITY 9, CATV 7)

-- (f) Coletilla opcional para la línea del contrato. Vacía por defecto:
--     una frase torpe dentro de un documento firmado es peor que ninguna.
--     update catalogo_items set cero_nota = 'lo cotiza Graybar'
--      where seccion = 'SWITCHGEAR' and cero_motivo = 'suministro';

-- LO QUE QUEDA EN NULL ES EL DISEÑO FUNCIONANDO, NO UN FALLO DE LA SIEMBRA.
-- Esperado: 22 — UNDERGROUND 4 (backhoe, trenching, backfilling, compacting),
-- LIGHTNING & GROUNDING 7, DEMOLITION 8, PROJECT GENERAL 3. Salen en ámbar
-- con «¿QUIÉN LO PONE?» y los contesta Edgar, una vez cada uno, cuando le
-- toquen de verdad en un trabajo.
-- Suma de control: 3 + 2 + 10 + 25 + 124 + 22 = 186. ✓


-- =====================================================================
-- BLOQUE 4 — DIAGNÓSTICO. Otra pestaña, no cambian nada.
-- =====================================================================

-- D2 · LA COLA DE VERDAD: solo importan los que Edgar de verdad usa.
--      De los 186, los que nunca han salido en un estimado no merecen su
--      tiempo. Contesta primero lo de arriba.
select c.seccion, c.item, coalesce(c.cero_motivo,'(sin clasificar)') as motivo,
       c.horas_unidad, count(ei.id) as veces_usado
  from catalogo_items c
  left join estimado_items ei
         on upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
          = upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
 where coalesce(c.precio,0) = 0
 group by 1,2,3,4
 order by veces_usado desc, 1 nulls first, 2;

-- D4 · LOS HUÉRFANOS DE ENSAMBLE. Cada fila es un componente que entra al
--      bid a $0.00 *Y a 0 horas* por el agujero de js/app.js:5372/5381
--      (catalogoExacto(cmp.item) || {}): ni material ni labor, en silencio.
--      Esto no se había contado nunca. Se arregla corrigiendo el nombre en
--      ensamble_items o dando de alta el ítem. NUNCA inventando un precio.
select e.nombre as ensamble, ei.item as escrito_en_el_ensamble, ei.cantidad
  from ensamble_items ei
  join ensambles e on e.id = ei.ensamble_id
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
          = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
 where c.id is null
 order by 1, 2;

-- D5 · Para teclear el 5" y el 6" sin inventar: la curva del propio
--      catálogo (1/2" … 4") y Edgar sigue la escala.
select item, unidad, precio, horas_unidad, cero_motivo
  from catalogo_items
 where item ilike '%GRS%' or item ilike '%PVC CONDUIT%'
 order by precio nulls last, item;

-- D6 · ¿Se acabó E0? Dos números, no una sensación.
select count(*) filter (where cero_motivo is null)                               as ceros_sin_motivo,
       count(*) filter (where cero_motivo is not null and cero_revisado is null)  as ceros_sin_confirmar
  from catalogo_items where coalesce(precio,0) = 0;

-- Los que van a salir en el CONTRATO, con lo que leerá el cliente:
select seccion, item, cero_nota
  from catalogo_items
 where cero_motivo = 'by_owner' and cero_revisado is not null
 order by seccion, item;


-- =====================================================================
-- APAGAR Y DESHACER
-- =====================================================================
-- APAGAR LOS AVISOS dejando los chips (el 80 % del valor, 0 % de fricción):
--   update config_estimador set valor = 1 where clave = 'cero_aviso';
-- APAGAR DEL TODO — la app vuelve a ser la de ayer, sin publicar nada:
--   update config_estimador set valor = 0 where clave = 'cero_aviso';
--
-- OJO: `update catalogo_items set cero_motivo = null` NO es un apagado.
-- NULL significa «revisar», así que eso pondría los 186 en ámbar
-- preguntando: MÁS ruido que antes. El apagado es la fila de config.
-- Desmontaje completo:
--   alter table catalogo_items drop constraint if exists catalogo_items_cero_motivo_chk;
--   alter table catalogo_items drop column if exists cero_motivo,
--                              drop column if exists cero_revisado,
--                              drop column if exists cero_nota;
--   alter table estimados      drop column if exists cero_notas,
--                              drop column if exists no_incluye_extra;
--   delete from config_estimador where clave = 'cero_aviso';
