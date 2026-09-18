-- ============================================================================
-- E27 · PASO 7: las HORAS que el estimador propone solo, y las LUMINARIAS
--       que espera cuota (18/09/2026)
-- ============================================================================
-- Edgar, 17/09: «lo que yo queria que arreglaras era lo de las horas» y «el
-- precio de referencia por familia, para que la cotizacion pendiente no salga
-- en $0 ni en $75».
--
-- Esto es lo que la app NO puede inventarse sola: los items de catalogo que
-- faltaban y la columna donde se guarda si un estimado usa precios de
-- referencia. El resto (proponer las cantidades, leer la cuota del supply)
-- ya va en el codigo, panel v190.
--
-- Idempotente: se puede correr dos veces sin duplicar nada.
-- ============================================================================

-- 1) LOS ITEMS QUE FALTABAN (los otros cinco ya los creo el e23d)
--
-- OJO: LAS HORAS SON NUMEROS DE ARRANQUE, NO MEDICIONES. Las escribi yo para
-- que el renglon exista; cambialas en el catalogo con tus tiempos de verdad.
--   · ICRA: una barrera con antesala en un hospital, montarla y quitarla.
--   · LIFT: mover y armar el elevador, por dia que este en la obra.
--   · PERMISO: sacarlo, la cita con el inspector, las correcciones.
--   · MOVILIZACION: cargar, llevar y descargar, por viaje.
-- El $0 de ICRA, LIFT y PERMISO es a proposito: el plastico, el alquiler y la
-- tasa son una TARIFA que tecleas por trabajo (sale con su chip TARIFA, sin
-- alarma). La mano si va en las horas.
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo, cero_motivo, cero_revisado)
select v.item, 'LABOR', 'E', 0, v.h, v.codigo, v.motivo, current_date
  from (values
    ('BARRERA ICRA / CONTENCIÓN DE POLVO (por barrera)',    4.00, '01-DEMO',  'tarifa'),
    ('LIFT O ANDAMIO — MONTAJE Y MOVIMIENTO (por día)',     1.00, '20-MISC',  'tarifa'),
    ('PERMISO E INSPECCIONES (por proyecto)',               6.00, '20-MISC',  'tarifa'),
    ('MOVILIZACIÓN Y ACARREO (por viaje)',                  4.00, '20-MISC',  'solo_labor')
  ) as v(item, h, codigo, motivo)
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = upper(v.item));

-- 2) LA COLUMNA DEL PRECIO DE REFERENCIA
-- Por estimado, y apagada por defecto: ningun bid de ayer se mueve un centavo.
alter table estimados add column if not exists usa_luz_ref boolean default false;

-- 3) LOS PRECIOS DE REFERENCIA POR FAMILIA
-- Son TUS numeros del bid de Nicklaus (e23c), no precios de internet. Se
-- editan desde la app (Estimador → la tarjeta de luminarias → «Precios de
-- referencia por familia»), o aqui.
insert into config_estimador (clave, valor)
values ('luz_ref', '{"cleanroom":550,"exit":110,"emergencia":130,"downlight":220,"highbay":280,"strip":120,"undercab":90,"troffer24":180,"troffer22":150}')
on conflict (clave) do nothing;

-- 4) (opcional) CAMBIAR LAS CANTIDADES QUE PROPONE
-- La app propone: terminacion y rotulado = nº de breakers · puesta en marcha =
-- nº de dimmers y sensores · demolicion = dispositivos + luminarias nuevas
-- (SUPUESTO) · ICRA, lift, permiso, movilizacion, cierre = 1.
-- Para cambiar un multiplicador (ej: dos viajes por trabajo, y media pieza
-- demolida por pieza nueva):
--   insert into config_estimador (clave, valor)
--   values ('horas_proyecto', '{"movilizacion":2,"demo":0.5}')
--   on conflict (clave) do update set valor = excluded.valor;
-- Los ids son: terminacion · rotulado · demo · arranque · icra · lift ·
-- permiso · movilizacion · cierre

-- Comprobar: 9 items de horas de proyecto en el catalogo
select count(*) as items_de_horas
  from catalogo_items
 where item in (
   'TERMINACIÓN DE CIRCUITO EN PANEL (por ckt)',
   'ROTULADO DE CIRCUITO Y DIRECTORIO DE PANEL (por ckt)',
   'DEMOLICIÓN DE DISPOSITIVO O LUMINARIA EXISTENTE (por unidad)',
   'PUESTA EN MARCHA DIMMER 0-10V / SENSOR (por unidad)',
   'AS-BUILT, PRUEBAS Y CIERRE (por proyecto)',
   'BARRERA ICRA / CONTENCIÓN DE POLVO (por barrera)',
   'LIFT O ANDAMIO — MONTAJE Y MOVIMIENTO (por día)',
   'PERMISO E INSPECCIONES (por proyecto)',
   'MOVILIZACIÓN Y ACARREO (por viaje)');
