-- =========================================================================
-- E22 · COMPROBAR e17 → e21 DE UNA SOLA PEGADA (solo lee, no cambia nada)
--
-- Por qué existe: los updates de e21 llevan guarda con el valor exacto que
-- debía tener la fila («and precio = 0.542»). Si ese valor no era exacto,
-- el update NO HIZO NADA y no dio error. Esto lo caza.
--
-- Devuelve una tabla corta: bloque | qué | esperado | real | estado.
-- Mándame las filas que digan ✗ REVISAR.
-- =========================================================================

with esperado(bloque, que, item, val) as (values
  -- e21 · tubería y fittings
  ('e21 tubo',   '1/2" EMT',                  '1/2"     EMT CONDUIT',                          0.6124),
  ('e21 tubo',   '3/4" EMT',                  '3/4"     EMT CONDUIT',                          1.0903),
  ('e21 tubo',   '1" EMT',                    '1"         EMT CONDUIT',                        1.8776),
  ('e21 fitting','1/2" conector',             '1/2"       EMT S.S. D/C CONNECTOR',             1.1679),
  ('e21 fitting','3/4" conector',             '3/4"       EMT S.S. D/C CONNECTOR',             1.8074),
  ('e21 fitting','1" conector',               '1"         EMT S.S. D/C CONNECTOR',             3.2247),
  ('e21 fitting','1/2" acople',               '1/2"       EMT S.S. D/C COUPLING',              0.4529),
  ('e21 fitting','3/4" acople',               '3/4"       EMT S.S. D/C COUPLING',              0.4336),
  ('e21 fitting','1" acople',                 '1"           EMT S.S.D/C  COUPLING',            0.8007),
  ('e21 fitting','1/2" grapa',                '1/2"      EMT STRAP 1 HOLE STRAP',              0.1459),
  ('e21 fitting','3/4" grapa',                '3/4"      EMT STRAP 1 HOLE STRAP',              0.2045),
  ('e21 fitting','3/8" flex (whips)',         '3/8"      FLEX. METAL CONDUIT',                 0.904),
  ('e21 fitting','1" bushing con lug',        '1"         GROUNDING BUSHING',                  4.35),
  -- e21 · cajas y anillos
  ('e21 caja',   'caja 4S 2-1/8',             '4"X 4" X 1 1/2"   1900 COMBO BOX',              1.8261),
  ('e21 caja',   'JB 1900 DEEP (las recetas)','JB 1900 DEEP BOX',                              1.8261),
  ('e21 caja',   'anillo 2G',                 '2  GANG PLASTER RING 1/2"',                     1.2495),
  ('e21 caja',   'tapa ciega 4S',             '4"X4" BLANK COVER',                             0.804),
  -- e21 · conductor y dispositivos
  ('e21 cable',  '#12 THHN por MLF',          '# 12      THHN STRANDED CU.',                 272.60),
  ('e21 disp',   'GFCI HG ivory',             '20A GFCI HOSPITAL GRADE TR/WR',                56.99),
  ('e21 disp',   'GFCI HG rojo',              '20A GFCI HOSPITAL GRADE RED',                  56.99),
  ('e21 disp',   'rele UL 924 (¡BLOQUE 0!)',  'UL 924 EMERGENCY LIGHTING CONTROL RELAY',     832.86),
  ('e21 disp',   'can 4" → LDN4',             '4" RECESSED CAN LIGHT',                       172.00),
  ('e21 disp',   'switch comercial (alta)',   '20A SINGLE POLE SWITCH COMMERCIAL SPEC GRADE',  11.80),
  ('e21 disp',   'time clock T7401B',         'TIME CLOCK 4PST 40A W/ OVERRIDE (INTERMATIC T7401B)', 270.22),
  -- e21 bloque 2 · los que NO se debían tocar
  ('e21 NO tocar','1" grapa (manda CED)',     '1"          EMT STRAP 1 HOLE STARP',            0.2087),
  ('e21 NO tocar','4-11/16 (manda el tuyo)',  '4-11/16 BOX',                                   6.75),
  ('e21 NO tocar','anillo 1G (manda CED)',    '1  GANG PLASTER RING 1/2"',                     0.8617),
  ('e21 NO tocar','putty pad (manda CED)',    'PUTTY PAD SEAL',                                6.49),
  ('e21 NO tocar','fire caulk (manda CED)',   'RED FIRE CAULK 10.3 OZ TUBE',                  14.63),
  ('e21 NO tocar','#10 THHN (manda CED)',     '# 10      THHN STRANDED CU.',                 450.83),
  ('e21 NO tocar','HG duplex (manda CED)',    '20A HOSPITAL GRADE TR RECEPTACLE',             16.90),
  ('e21 NO tocar','HG duplex rojo',           '20A HOSPITAL GRADE TR RECEPTACLE RED',         16.90),
  ('e21 NO tocar','isolating bushing (stubs)','1" ISOLATING BUSHING',                          0.189),
  ('e21 NO tocar','3/8" flex connector',      '3/8"      FLEX. METAL ST. CONNECT.',            0.588),
  -- e19 · precios de referencia
  ('e19 ref',    'exit sign (era $0)',        'EXIT SIGN BACK/TOP MTD',                       80.00),
  ('e19 ref',    'combo 0-10V + sensor',      '0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH',  120.00),
  ('e19 ref',    'par 0-10V 18/2 CMP por MLF','18/2 CMP 0-10V DIMMING CABLE (PURPLE/GRAY)',  330.00),
  ('e19 ref',    'placa inox 1G duplex',      '1G DUPLEX WALLPLATE STAINLESS STEEL',           4.50),
  ('e19 ref',    'placa inox 2G duplex',      '2G DUPLEX WALLPLATE STAINLESS STEEL',           8.00),
  ('e19 ref',    'placa inox 1G decora',      '1G DECORA WALLPLATE STAINLESS STEEL',           6.69),
  ('e19 ref',    'placa inox 2G decora',      '2G DECORA WALLPLATE STAINLESS STEEL',          10.49),
  -- e16/e18 · las altas que usan las recetas
  ('e18 alta',   'HG duplex ivory',           '20A HOSPITAL GRADE TR RECEPTACLE',             16.90),
  ('e18 alta',   'HG duplex ROJO',            '20A HOSPITAL GRADE TR RECEPTACLE RED',         16.90),
  ('e18 alta',   'placa roja 1G',             '1G DUPLEX WALLPLATE RED',                       0.27),
  ('e18 alta',   'grabado por gang',          'PLATE ENGRAVING (per gang)',                   10.00),
  ('e18 alta',   'enclosure TV Hubbell',      'NEMA 1 ENCLOSURE 12x12x4',                    211.43),
  ('e18 alta',   'tapa del enclosure',        'NEMA 1 ENCLOSURE COVER 12x12',                 69.72)
)
select e.bloque, e.que,
       to_char(e.val, 'FM999990.9999') as esperado,
       coalesce(to_char(c.precio, 'FM999990.9999'), '(no existe la fila)') as real,
       case when c.id is null then '✗ REVISAR — falta la fila'
            when abs(coalesce(c.precio,0) - e.val) < 0.0001 then 'ok'
            else '✗ REVISAR — el update no entro' end as estado
  from esperado e
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = upper(btrim(regexp_replace(e.item,'\s+',' ','g')))
 order by case when c.id is null or abs(coalesce(c.precio,0) - e.val) >= 0.0001 then 0 else 1 end,
          e.bloque, e.que;

-- ── 2. Las 17 recetas del hospital: componentes y huérfanos ──────────────
--    huerfanos tiene que ser 0 en las 17. Si alguna trae 1, ese componente
--    entra al bid a $0 y 0 horas EN SILENCIO.
select e.orden, e.nombre,
       count(ei.id)                                     as componentes,
       count(*) filter (where c.id is null)             as huerfanos,
       round(sum(ei.cantidad * coalesce(c.horas_unidad,0))::numeric, 2) as horas,
       round(sum(ei.cantidad * coalesce(c.precio,0))::numeric, 2)       as material
  from ensambles e
  join ensamble_items ei on ei.ensamble_id = e.id
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
          = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
 where e.orden between 200 and 216
 group by e.orden, e.nombre
 order by e.orden;

-- ── 3. Que el switch del hospital quedó en el COMERCIAL (1 fila, $11.80) ──
select e.nombre as receta, ei.item, c.precio, c.horas_unidad
  from ensamble_items ei
  join ensambles e on e.id = ei.ensamble_id
  left join catalogo_items c
         on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
          = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
 where e.nombre = 'SWITCH SENCILLO 20A — EMT' and ei.item ilike '%SWITCH%';

-- ── 4. Que la columna de e17 está (sin ella el takeoff cobra doble) ───────
select column_name, data_type, column_default
  from information_schema.columns
 where table_name = 'estimado_ensambles' and column_name = 'sin_lineales';

-- ── 5. Recuento: 97 recetas en total, 17 del hospital ────────────────────
select count(*) filter (where orden between 200 and 216) as recetas_hospital,
       count(*)                                          as recetas_totales
  from ensambles;
