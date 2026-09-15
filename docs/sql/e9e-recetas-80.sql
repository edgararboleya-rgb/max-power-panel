-- =====================================================================
-- E9e · Las 80 recetas que te faltaban, por método de cableado
-- Supabase → SQL Editor. Un solo pegado. Idempotente: no duplica nada.
--
-- Cada componente de aquí EXISTE en tu catálogo con ese nombre exacto:
-- se comprobó uno por uno contra el export (docs/takeoff/fuente).
-- Las horas y el precio NO se escriben aquí: los pone el catálogo.
-- =====================================================================

-- que el modo «comercial» esté permitido (por si este SQL va suelto)
alter table ensambles drop constraint if exists ensambles_modo_check;
alter table ensambles add  constraint ensambles_modo_check
  check (modo in ('remodelacion','servicio','comercial','planos','rapido'));

-- ---------------------------------------------------------------
-- 1) Las recetas
-- ---------------------------------------------------------------
insert into ensambles (nombre, modo, pies_editable, orden)
select v.nombre, v.modo, v.pies, v.orden
  from (values
    ('RECEPTÁCULO 20A — ROMEX', 'remodelacion', true, 100),
    ('RECEPTÁCULO 15A TAMPER RESISTANT — ROMEX', 'remodelacion', true, 101),
    ('RECEPTÁCULO GFCI 20A — ROMEX', 'remodelacion', true, 102),
    ('RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX', 'remodelacion', true, 103),
    ('RECEPTÁCULO USB 20A — ROMEX', 'remodelacion', true, 104),
    ('SWITCH SENCILLO — ROMEX', 'remodelacion', true, 105),
    ('SWITCH TRES VÍAS — ROMEX', 'remodelacion', true, 106),
    ('SWITCH CUATRO VÍAS — ROMEX', 'remodelacion', true, 107),
    ('DIMMER 600W — ROMEX', 'remodelacion', true, 108),
    ('RECEPTÁCULO 50A ESTUFA (NEMA 14-50) — ROMEX', 'remodelacion', true, 109),
    ('RECEPTÁCULO 30A SECADORA (NEMA 14-30) — ROMEX', 'remodelacion', true, 110),
    ('RECEPTÁCULO GFCI 20A — EMT', 'comercial', true, 111),
    ('RECEPTÁCULO GFCI 20A — MC', 'comercial', true, 112),
    ('RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT', 'comercial', true, 113),
    ('RECEPTÁCULO USB 20A — EMT', 'comercial', true, 114),
    ('SWITCH TRES VÍAS — EMT', 'comercial', true, 115),
    ('SWITCH TRES VÍAS — MC', 'comercial', true, 116),
    ('SWITCH CUATRO VÍAS — EMT', 'comercial', true, 117),
    ('DIMMER DE PARED 600W — EMT', 'comercial', true, 118),
    ('SENSOR DE OCUPACIÓN DE PARED — MC', 'comercial', true, 119),
    ('SENSOR DE OCUPACIÓN DE TECHO — MC', 'comercial', true, 120),
    ('RECEPTÁCULO SENCILLO 20A — MC', 'comercial', true, 121),
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', 'comercial', true, 122),
    ('DISCONNECT 30A/3P EQUIPO MECÁNICO — EMT', 'comercial', true, 123),
    ('FURNITURE FEED — EMT', 'comercial', true, 124),
    ('LUMINARIA 2X2 — EMT', 'comercial', true, 125),
    ('LUMINARIA 2X2 — MC', 'comercial', true, 126),
    ('RECESSED CAN 4" — EMT', 'comercial', true, 127),
    ('RECESSED CAN 4" — MC', 'comercial', true, 128),
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', 'comercial', true, 129),
    ('DOWN LIGHT — MC', 'comercial', true, 130),
    ('PENDANT — EMT', 'comercial', true, 131),
    ('LED LINEAR — EMT', 'comercial', true, 132),
    ('WALL PACK EXTERIOR — EMT', 'comercial', true, 133),
    ('EXIT SIGN — EMT', 'comercial', true, 134),
    ('LUZ DE EMERGENCIA BATERÍA — EMT', 'comercial', true, 135),
    ('LUMINARIA 2X4 — SOLO INSTALACIÓN', 'comercial', true, 136),
    ('LUMINARIA 2X2 — SOLO INSTALACIÓN', 'comercial', true, 137),
    ('ESTACIÓN MANUAL (PULL STATION)', 'comercial', true, 138),
    ('DETECTOR DE HUMO CON BASE', 'comercial', true, 139),
    ('DETECTOR DE CALOR CON BASE', 'comercial', true, 140),
    ('DETECTOR DE HUMO DE DUCTO', 'comercial', true, 141),
    ('STROBE F/A', 'comercial', true, 142),
    ('HORN/STROBE F/A', 'comercial', true, 143),
    ('HORN/STROBE F/A INTEMPERIE (WP)', 'comercial', true, 144),
    ('BOCINA F/A (SPEAKER)', 'comercial', true, 145),
    ('SPEAKER/STROBE F/A (EVAC DE VOZ)', 'comercial', true, 146),
    ('MÓDULO DE MONITOREO F/A', 'comercial', true, 147),
    ('PANEL BOOSTER 24VDC — EMT', 'comercial', true, 148),
    ('PUESTA EN MARCHA F/A (POR PROYECTO)', 'comercial', false, 149),
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', 'comercial', true, 150),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', 'comercial', true, 151),
    ('SALIDA DE DATOS CAT6 1 PUERTO — MC', 'comercial', true, 152),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — MC', 'comercial', true, 153),
    ('SALIDA DE TELÉFONO — EMT', 'comercial', true, 154),
    ('SALIDA DE TV / COAX — EMT', 'comercial', true, 155),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', 'comercial', true, 156),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — MC', 'comercial', true, 157),
    ('CÁMARA IP (PoE) EN TECHO — EMT', 'comercial', true, 158),
    ('LECTOR DE TARJETA (CARD READER) — EMT', 'comercial', true, 159),
    ('CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT', 'comercial', true, 160),
    ('CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT', 'comercial', true, 161),
    ('RACK DE COMUNICACIONES (IDF) 24 PUERTOS', 'comercial', false, 162),
    ('CIRCUITO 20A DERIVADO — MC', 'comercial', true, 163),
    ('CIRCUITO 20A DERIVADO — ROMEX', 'remodelacion', true, 164),
    ('HOMERUN 20A AL PANEL — EMT', 'comercial', true, 165),
    ('HOMERUN 20A AL PANEL — MC', 'comercial', true, 166),
    ('CAJA DE DERIVACION 4-11/16 EN PARED — EMT', 'comercial', false, 167),
    ('CAJA DE DERIVACION 4-11/16 EN TECHO — EMT', 'comercial', false, 168),
    ('CAJA DE DERIVACION 1900 EN TECHO — MC', 'comercial', false, 169),
    ('PLASTER RING 1 GANG SUELTO', 'comercial', false, 170),
    ('PULL BOX 12X12X12 — EMT 3/4"', 'comercial', false, 171),
    ('DEMOLICION — RETIRAR CONDUIT', 'comercial', true, 172),
    ('DEMOLICION — RETIRAR CABLEADO', 'comercial', true, 173),
    ('DEMOLICION — RETIRAR DISPOSITIVOS', 'comercial', false, 174),
    ('DEMOLICION — RETIRAR LUMINARIAS', 'comercial', false, 175),
    ('DEMOLICION — RETIRAR PANEL', 'comercial', false, 176),
    ('EXIT SIGN — MC', 'comercial', true, 177),
    ('LUZ DE EMERGENCIA BATERÍA — MC', 'comercial', true, 178),
    ('DOWN LIGHT — EMT', 'comercial', true, 179)
  ) as v(nombre, modo, pies, orden)
 where not exists (select 1 from ensambles e where e.nombre = v.nombre);

-- ---------------------------------------------------------------
-- 2) Los componentes
-- ---------------------------------------------------------------
insert into ensamble_items (ensamble_id, item, cantidad)
select e.id, v.item, v.cantidad
  from (values
    -- RECEPTÁCULO 20A — ROMEX · 1.24 h · $14.78 de material · El punto de fuerza corriente de toda casa: dúplex 20A en caja de plástico con 25 ft de 12/2 hasta el punto. Es la receta que Edgar multiplicará por 20 o 30 en cualquier remodelación.
    ('RECEPTÁCULO 20A — ROMEX', '20A DUPLEX RECEPTACLE', 1),
    ('RECEPTÁCULO 20A — ROMEX', '1 GANG PLASTIC BOX', 1),
    ('RECEPTÁCULO 20A — ROMEX', '1G PLASTIC COVER RECEPTACLE', 1),
    ('RECEPTÁCULO 20A — ROMEX', '12/2   ROMEX', 0.025),
    ('RECEPTÁCULO 20A — ROMEX', 'ROMEX STAPLES', 4),
    ('RECEPTÁCULO 20A — ROMEX', 'YELLOW WIRENUTS', 3),
    ('RECEPTÁCULO 20A — ROMEX', '#12     GROUND PIGTAIL', 1),

    -- RECEPTÁCULO 15A TAMPER RESISTANT — ROMEX · 1.24 h · $12.46 de material · El receptáculo de dormitorio y sala: 15A tamper-resistant en 14/2, que es lo que pide el código en vivienda y lo que de verdad se instala fuera de cocina y baño.
    ('RECEPTÁCULO 15A TAMPER RESISTANT — ROMEX', '15A DUPLEX TAMPER RESISTANT', 1),
    ('RECEPTÁCULO 15A TAMPER RESISTANT — ROMEX', '1 GANG PLASTIC BOX', 1),
    ('RECEPTÁCULO 15A TAMPER RESISTANT — ROMEX', '1G PLASTIC COVER RECEPTACLE', 1),
    ('RECEPTÁCULO 15A TAMPER RESISTANT — ROMEX', '14/2   ROMEX', 0.025),
    ('RECEPTÁCULO 15A TAMPER RESISTANT — ROMEX', 'ROMEX STAPLES', 4),
    ('RECEPTÁCULO 15A TAMPER RESISTANT — ROMEX', 'YELLOW WIRENUTS', 3),
    ('RECEPTÁCULO 15A TAMPER RESISTANT — ROMEX', '#12     GROUND PIGTAIL', 1),

    -- RECEPTÁCULO GFCI 20A — ROMEX · 1.34 h · $29.73 de material · El punto de cocina, baño, garaje y lavandería. Mismo armado que el dúplex pero con la pieza GFCI, que es donde está el dinero ($16,39 contra $1,44).
    ('RECEPTÁCULO GFCI 20A — ROMEX', '20A GFCI DUPLEX RECEPTACLE', 1),
    ('RECEPTÁCULO GFCI 20A — ROMEX', '1 GANG PLASTIC BOX', 1),
    ('RECEPTÁCULO GFCI 20A — ROMEX', '1G PLASTIC COVER RECEPTACLE', 1),
    ('RECEPTÁCULO GFCI 20A — ROMEX', '12/2   ROMEX', 0.025),
    ('RECEPTÁCULO GFCI 20A — ROMEX', 'ROMEX STAPLES', 4),
    ('RECEPTÁCULO GFCI 20A — ROMEX', 'YELLOW WIRENUTS', 3),
    ('RECEPTÁCULO GFCI 20A — ROMEX', '#12     GROUND PIGTAIL', 1),

    -- RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX · 1.68 h · $60.53 de material · El tomacorriente de patio, porche o pared exterior: pieza weather-resistant en bell box de fundición con tapa, que es lo único que pasa inspección afuera.
    ('RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX', '20A GFCI WR (Weather Resistant)', 1),
    ('RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX', '2"x 4"    BELL BOX-BOX', 1),
    ('RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX', '2"x 4"    BELL BOX-DEVICE COVER', 1),
    ('RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX', '12/2   ROMEX', 0.025),
    ('RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX', 'NM CABLE CONNECTOR 1/2"', 1),
    ('RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX', 'ROMEX STAPLES', 4),
    ('RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX', 'YELLOW WIRENUTS', 3),
    ('RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX', '#12     GROUND PIGTAIL', 1),

    -- RECEPTÁCULO USB 20A — ROMEX · 1.34 h · $55.34 de material · El upgrade que más pide el cliente residencial (mesa de noche, cocina, escritorio): dúplex con USB integrado. Mismo trabajo que un dúplex normal, once veces el material.
    ('RECEPTÁCULO USB 20A — ROMEX', '20A USB-C/USB-A DUPLEX (Leviton T5836)', 1),
    ('RECEPTÁCULO USB 20A — ROMEX', '1 GANG PLASTIC BOX', 1),
    ('RECEPTÁCULO USB 20A — ROMEX', '1G PLASTIC COVER RECEPTACLE', 1),
    ('RECEPTÁCULO USB 20A — ROMEX', '12/2   ROMEX', 0.025),
    ('RECEPTÁCULO USB 20A — ROMEX', 'ROMEX STAPLES', 4),
    ('RECEPTÁCULO USB 20A — ROMEX', 'YELLOW WIRENUTS', 3),
    ('RECEPTÁCULO USB 20A — ROMEX', '#12     GROUND PIGTAIL', 1),

    -- SWITCH SENCILLO — ROMEX · 1.06 h · $16.35 de material · El apagador de toda la vida con su tramo de cable hasta la luminaria. Es la versión en Romex con el método en el nombre, que complementa a NEW SINGLE POLE SWITCH (esa es de servicio, sin cable).
    ('SWITCH SENCILLO — ROMEX', 'SINGLE POLE SWITCH', 1),
    ('SWITCH SENCILLO — ROMEX', '1 GANG PLASTIC BOX', 1),
    ('SWITCH SENCILLO — ROMEX', '1G PLASTIC COVER SWITCH', 1),
    ('SWITCH SENCILLO — ROMEX', '12/2   ROMEX', 0.025),
    ('SWITCH SENCILLO — ROMEX', 'ROMEX STAPLES', 4),
    ('SWITCH SENCILLO — ROMEX', 'YELLOW WIRENUTS', 3),
    ('SWITCH SENCILLO — ROMEX', '#12     GROUND PIGTAIL', 1),

    -- SWITCH TRES VÍAS — ROMEX · 1.14 h · $19.41 de material · Pasillo o escalera: encender desde dos puntos. La receta es POR CADA cabeza de tres vías — Edgar pone cantidad 2 cuando cotiza un par.
    ('SWITCH TRES VÍAS — ROMEX', 'THREE WAY SWITCH', 1),
    ('SWITCH TRES VÍAS — ROMEX', '1 GANG PLASTIC BOX', 1),
    ('SWITCH TRES VÍAS — ROMEX', '1G PLASTIC COVER SWITCH', 1),
    ('SWITCH TRES VÍAS — ROMEX', '12/3   ROMEX', 0.025),
    ('SWITCH TRES VÍAS — ROMEX', 'ROMEX STAPLES', 4),
    ('SWITCH TRES VÍAS — ROMEX', 'YELLOW WIRENUTS', 4),
    ('SWITCH TRES VÍAS — ROMEX', '#12     GROUND PIGTAIL', 1),

    -- SWITCH CUATRO VÍAS — ROMEX · 2.13 h · $20.41 de material · La cabeza del medio cuando se enciende desde tres puntos (pasillo largo, escalera de dos tramos). Va siempre entre dos recetas de tres vías.
    ('SWITCH CUATRO VÍAS — ROMEX', 'FOUR WAY SWITCH', 1),
    ('SWITCH CUATRO VÍAS — ROMEX', '1 GANG PLASTIC BOX', 1),
    ('SWITCH CUATRO VÍAS — ROMEX', '1G PLASTIC COVER SWITCH', 1),
    ('SWITCH CUATRO VÍAS — ROMEX', '12/3   ROMEX', 0.025),
    ('SWITCH CUATRO VÍAS — ROMEX', 'ROMEX STAPLES', 4),
    ('SWITCH CUATRO VÍAS — ROMEX', 'YELLOW WIRENUTS', 4),
    ('SWITCH CUATRO VÍAS — ROMEX', '#12     GROUND PIGTAIL', 1),

    -- DIMMER 600W — ROMEX · 1.16 h · $75.15 de material · Comedor, sala, recámara principal: el dimmer de 600W. El trabajo es el de un switch sencillo, pero la pieza son $61,77 y ahí se va el precio.
    ('DIMMER 600W — ROMEX', 'DIMMER SWITCH 600W', 1),
    ('DIMMER 600W — ROMEX', '1 GANG PLASTIC BOX', 1),
    ('DIMMER 600W — ROMEX', '1G PLASTIC COVER SWITCH', 1),
    ('DIMMER 600W — ROMEX', '12/2   ROMEX', 0.025),
    ('DIMMER 600W — ROMEX', 'ROMEX STAPLES', 4),
    ('DIMMER 600W — ROMEX', 'YELLOW WIRENUTS', 3),
    ('DIMMER 600W — ROMEX', '#12     GROUND PIGTAIL', 1),

    -- RECEPTÁCULO 50A ESTUFA (NEMA 14-50) — ROMEX · 2.49 h · $116.35 de material · La salida de 240V de la estufa: pieza 14-50, 6/3 Romex y su breaker de 50A. Complementa a EV CHARGER OUTLET (NEMA 14-50), que es la misma salida pero para el cargador.
    ('RECEPTÁCULO 50A ESTUFA (NEMA 14-50) — ROMEX', '240V RANGE OUTLET (NEMA 14-50)', 1),
    ('RECEPTÁCULO 50A ESTUFA (NEMA 14-50) — ROMEX', '4-11/16 BOX', 1),
    ('RECEPTÁCULO 50A ESTUFA (NEMA 14-50) — ROMEX', '6/3     ROMEX', 0.025),
    ('RECEPTÁCULO 50A ESTUFA (NEMA 14-50) — ROMEX', 'ROMEX STAPLES', 4),
    ('RECEPTÁCULO 50A ESTUFA (NEMA 14-50) — ROMEX', 'BREAKER 2P 50A', 1),
    ('RECEPTÁCULO 50A ESTUFA (NEMA 14-50) — ROMEX', 'YELLOW WIRENUTS', 3),
    ('RECEPTÁCULO 50A ESTUFA (NEMA 14-50) — ROMEX', '2  GANG PLASTER RING 1/2"', 1),

    -- RECEPTÁCULO 30A SECADORA (NEMA 14-30) — ROMEX · 2.17 h · $70.84 de material · La otra salida de 240V que sale en toda remodelación de lavandería. Va junto a la de estufa y no existía ninguna receta de secadora.
    ('RECEPTÁCULO 30A SECADORA (NEMA 14-30) — ROMEX', '120/240V DRYER OUTLET (NEMA 14-30)', 1),
    ('RECEPTÁCULO 30A SECADORA (NEMA 14-30) — ROMEX', '2   GANG PLASTIC BOX', 1),
    ('RECEPTÁCULO 30A SECADORA (NEMA 14-30) — ROMEX', '10/3   ROMEX', 0.025),
    ('RECEPTÁCULO 30A SECADORA (NEMA 14-30) — ROMEX', 'ROMEX STAPLES', 4),
    ('RECEPTÁCULO 30A SECADORA (NEMA 14-30) — ROMEX', 'BREAKER 2P 30A', 1),
    ('RECEPTÁCULO 30A SECADORA (NEMA 14-30) — ROMEX', 'YELLOW WIRENUTS', 3),

    -- RECEPTÁCULO GFCI 20A — EMT · 2.45 h · $55.84 de material · El punto GFCI de cocineta, baño o cuarto de aseo en obra con tubo: es el segundo dispositivo más contado de Edgar (15 en Stuart, 4 en DTCC) y hasta hoy había que armarlo a mano.
    ('RECEPTÁCULO GFCI 20A — EMT', '20A GFCI DUPLEX RECEPTACLE', 1),
    ('RECEPTÁCULO GFCI 20A — EMT', '4-11/16 BOX', 1),
    ('RECEPTÁCULO GFCI 20A — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('RECEPTÁCULO GFCI 20A — EMT', '1/2"     EMT CONDUIT', 25),
    ('RECEPTÁCULO GFCI 20A — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('RECEPTÁCULO GFCI 20A — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('RECEPTÁCULO GFCI 20A — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('RECEPTÁCULO GFCI 20A — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('RECEPTÁCULO GFCI 20A — EMT', '#12     GROUND PIGTAIL', 1),
    ('RECEPTÁCULO GFCI 20A — EMT', 'YELLOW WIRENUTS', 3),
    ('RECEPTÁCULO GFCI 20A — EMT', '1G PLASTIC COVER RECEPTACLE', 1),

    -- RECEPTÁCULO GFCI 20A — MC · 1.92 h · $45.61 de material · El mismo GFCI pero en la obra ligera de MC (tienda, oficina, remodelación en edificio ocupado), que es como Edgar hizo Stuart entero.
    ('RECEPTÁCULO GFCI 20A — MC', '20A GFCI DUPLEX RECEPTACLE', 1),
    ('RECEPTÁCULO GFCI 20A — MC', '4-11/16 BOX', 1),
    ('RECEPTÁCULO GFCI 20A — MC', '1  GANG PLASTER RING 1/2"', 1),
    ('RECEPTÁCULO GFCI 20A — MC', '12/2   MC', 0.025),
    ('RECEPTÁCULO GFCI 20A — MC', 'MC SNAP-IN CONNECTOR 3/8"', 2),
    ('RECEPTÁCULO GFCI 20A — MC', 'MC CONDUIT STRAP', 3),
    ('RECEPTÁCULO GFCI 20A — MC', '#12     GROUND PIGTAIL', 1),
    ('RECEPTÁCULO GFCI 20A — MC', 'YELLOW WIRENUTS', 3),
    ('RECEPTÁCULO GFCI 20A — MC', '1G PLASTIC COVER RECEPTACLE', 1),

    -- RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT · 2.70 h · $42.56 de material · El quad de puesto de trabajo en oficina: dos duplex en una sola caja de 2 gang. Es lo que va debajo de cada escritorio y hoy Edgar tenía que meter dos recetas de receptáculo y luego restar la caja de más.
    ('RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT', '20A DUPLEX RECEPTACLE', 2),
    ('RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT', '4-11/16 BOX', 1),
    ('RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT', '2  GANG PLASTER RING 1/2"', 1),
    ('RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT', '1/2"     EMT CONDUIT', 25),
    ('RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT', '#12     GROUND PIGTAIL', 2),
    ('RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT', 'YELLOW WIRENUTS', 4),

    -- RECEPTÁCULO USB 20A — EMT · 2.45 h · $81.45 de material · El receptáculo con carga USB de sala de juntas, lobby o conference center: mismo punto de siempre, la pieza es lo único que cambia. DTCC llevaba 4.
    ('RECEPTÁCULO USB 20A — EMT', '20A USB-C/USB-A DUPLEX (Leviton T5836)', 1),
    ('RECEPTÁCULO USB 20A — EMT', '4-11/16 BOX', 1),
    ('RECEPTÁCULO USB 20A — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('RECEPTÁCULO USB 20A — EMT', '1/2"     EMT CONDUIT', 25),
    ('RECEPTÁCULO USB 20A — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('RECEPTÁCULO USB 20A — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('RECEPTÁCULO USB 20A — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('RECEPTÁCULO USB 20A — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('RECEPTÁCULO USB 20A — EMT', '#12     GROUND PIGTAIL', 1),
    ('RECEPTÁCULO USB 20A — EMT', 'YELLOW WIRENUTS', 3),
    ('RECEPTÁCULO USB 20A — EMT', '1G PLASTIC COVER RECEPTACLE', 1),

    -- SWITCH TRES VÍAS — EMT · 2.08 h · $40.33 de material · Pasillo, sala de juntas o cualquier luz mandada desde dos puntos. Stuart llevaba 6 y Edgar no tenía receta: los metía como switch sencillo y perdía el viajero.
    ('SWITCH TRES VÍAS — EMT', 'THREE WAY SWITCH', 1),
    ('SWITCH TRES VÍAS — EMT', '4-11/16 BOX', 1),
    ('SWITCH TRES VÍAS — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('SWITCH TRES VÍAS — EMT', '1/2"     EMT CONDUIT', 20),
    ('SWITCH TRES VÍAS — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SWITCH TRES VÍAS — EMT', '1/2"       EMT S.S. D/C COUPLING', 2),
    ('SWITCH TRES VÍAS — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('SWITCH TRES VÍAS — EMT', '# 12      THHN STRANDED CU.', 0.08),
    ('SWITCH TRES VÍAS — EMT', 'YELLOW WIRENUTS', 4),
    ('SWITCH TRES VÍAS — EMT', '1G PLASTIC COVER SWITCH', 1),
    ('SWITCH TRES VÍAS — EMT', '#12     GROUND PIGTAIL', 1),

    -- SWITCH TRES VÍAS — MC · 1.54 h · $30.24 de material · El tres vías en obra de MC, que es como Edgar hizo Stuart. Lo importante aquí es que la receta trae 12/3 MC, no 12/2: sin el tercer conductor no hay viajero.
    ('SWITCH TRES VÍAS — MC', 'THREE WAY SWITCH', 1),
    ('SWITCH TRES VÍAS — MC', '4-11/16 BOX', 1),
    ('SWITCH TRES VÍAS — MC', '1  GANG PLASTER RING 1/2"', 1),
    ('SWITCH TRES VÍAS — MC', '12/3   MC', 0.02),
    ('SWITCH TRES VÍAS — MC', 'MC SNAP-IN CONNECTOR 3/8"', 2),
    ('SWITCH TRES VÍAS — MC', 'MC CONDUIT STRAP', 2),
    ('SWITCH TRES VÍAS — MC', 'YELLOW WIRENUTS', 4),
    ('SWITCH TRES VÍAS — MC', '1G PLASTIC COVER SWITCH', 1),
    ('SWITCH TRES VÍAS — MC', '#12     GROUND PIGTAIL', 1),

    -- SWITCH CUATRO VÍAS — EMT · 2.96 h · $36.91 de material · El punto intermedio cuando una luz se manda desde tres sitios o más (pasillo largo, sala grande con puertas en los dos extremos). Va siempre entre dos tres vías.
    ('SWITCH CUATRO VÍAS — EMT', 'FOUR WAY SWITCH', 1),
    ('SWITCH CUATRO VÍAS — EMT', '4-11/16 BOX', 1),
    ('SWITCH CUATRO VÍAS — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('SWITCH CUATRO VÍAS — EMT', '1/2"     EMT CONDUIT', 20),
    ('SWITCH CUATRO VÍAS — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SWITCH CUATRO VÍAS — EMT', '1/2"       EMT S.S. D/C COUPLING', 2),
    ('SWITCH CUATRO VÍAS — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('SWITCH CUATRO VÍAS — EMT', '# 12      THHN STRANDED CU.', 0.06),
    ('SWITCH CUATRO VÍAS — EMT', 'YELLOW WIRENUTS', 4),
    ('SWITCH CUATRO VÍAS — EMT', '1G PLASTIC COVER SWITCH', 1),
    ('SWITCH CUATRO VÍAS — EMT', '#12     GROUND PIGTAIL', 1),

    -- DIMMER DE PARED 600W — EMT · 2.01 h · $95.17 de material · La luz regulable de sala de juntas, lobby o restaurante. Es el mismo punto de switch, pero la pieza cuesta $61,77 en vez de $2,97 y sin receta Edgar se comía la diferencia de material.
    ('DIMMER DE PARED 600W — EMT', 'DIMMER SWITCH 600W', 1),
    ('DIMMER DE PARED 600W — EMT', '4-11/16 BOX', 1),
    ('DIMMER DE PARED 600W — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('DIMMER DE PARED 600W — EMT', '1/2"     EMT CONDUIT', 20),
    ('DIMMER DE PARED 600W — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('DIMMER DE PARED 600W — EMT', '1/2"       EMT S.S. D/C COUPLING', 2),
    ('DIMMER DE PARED 600W — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('DIMMER DE PARED 600W — EMT', '# 12      THHN STRANDED CU.', 0.06),
    ('DIMMER DE PARED 600W — EMT', 'YELLOW WIRENUTS', 3),
    ('DIMMER DE PARED 600W — EMT', '1G PLASTIC COVER SWITCH', 1),
    ('DIMMER DE PARED 600W — EMT', '#12     GROUND PIGTAIL', 1),

    -- SENSOR DE OCUPACIÓN DE PARED — MC · 2.47 h · $93.91 de material · El sensor que sustituye al switch en oficina, baño o almacén y que hoy exige el código de energía. Stuart llevaba 15 sensores entre pared y techo.
    ('SENSOR DE OCUPACIÓN DE PARED — MC', 'PIR OCCUPANCY SENSOR', 1),
    ('SENSOR DE OCUPACIÓN DE PARED — MC', '4-11/16 BOX', 1),
    ('SENSOR DE OCUPACIÓN DE PARED — MC', '1  GANG PLASTER RING 1/2"', 1),
    ('SENSOR DE OCUPACIÓN DE PARED — MC', '12/3   MC', 0.02),
    ('SENSOR DE OCUPACIÓN DE PARED — MC', 'MC SNAP-IN CONNECTOR 3/8"', 2),
    ('SENSOR DE OCUPACIÓN DE PARED — MC', 'MC CONDUIT STRAP', 2),
    ('SENSOR DE OCUPACIÓN DE PARED — MC', 'YELLOW WIRENUTS', 4),
    ('SENSOR DE OCUPACIÓN DE PARED — MC', '#12     GROUND PIGTAIL', 1),

    -- SENSOR DE OCUPACIÓN DE TECHO — MC · 2.67 h · $155.07 de material · El sensor de techo de oficina abierta, pasillo o sala grande, donde uno de pared no ve. Stuart llevaba 9.
    ('SENSOR DE OCUPACIÓN DE TECHO — MC', 'CEILING OCCUPANCY SENSOR', 1),
    ('SENSOR DE OCUPACIÓN DE TECHO — MC', 'JB 1900 BOX', 1),
    ('SENSOR DE OCUPACIÓN DE TECHO — MC', 'CEILING RING  1/2"', 1),
    ('SENSOR DE OCUPACIÓN DE TECHO — MC', 'REMOTE POWER PACK', 1),
    ('SENSOR DE OCUPACIÓN DE TECHO — MC', '12/2   MC', 0.02),
    ('SENSOR DE OCUPACIÓN DE TECHO — MC', 'MC SNAP-IN CONNECTOR 3/8"', 2),
    ('SENSOR DE OCUPACIÓN DE TECHO — MC', 'MC CONDUIT STRAP', 2),
    ('SENSOR DE OCUPACIÓN DE TECHO — MC', 'YELLOW WIRENUTS', 4),
    ('SENSOR DE OCUPACIÓN DE TECHO — MC', '#12     GROUND PIGTAIL', 1),
    ('SENSOR DE OCUPACIÓN DE TECHO — MC', 'T-BAR BOX HANGER', 1),

    -- RECEPTÁCULO SENCILLO 20A — MC · 1.82 h · $32.07 de material · La salida individual dedicada: nevera, microondas, copiadora, cualquier equipo que no comparte circuito. Stuart llevaba 4. Es el receptáculo SINGLE, no el duplex: un solo enchufe.
    ('RECEPTÁCULO SENCILLO 20A — MC', '20A SINGLE RECEPTACLE', 1),
    ('RECEPTÁCULO SENCILLO 20A — MC', '4-11/16 BOX', 1),
    ('RECEPTÁCULO SENCILLO 20A — MC', '1  GANG PLASTER RING 1/2"', 1),
    ('RECEPTÁCULO SENCILLO 20A — MC', '12/2   MC', 0.025),
    ('RECEPTÁCULO SENCILLO 20A — MC', 'MC SNAP-IN CONNECTOR 3/8"', 2),
    ('RECEPTÁCULO SENCILLO 20A — MC', 'MC CONDUIT STRAP', 3),
    ('RECEPTÁCULO SENCILLO 20A — MC', '#12     GROUND PIGTAIL', 1),
    ('RECEPTÁCULO SENCILLO 20A — MC', 'YELLOW WIRENUTS', 3),
    ('RECEPTÁCULO SENCILLO 20A — MC', '1G PLASTIC COVER RECEPTACLE', 1),

    -- FLOOR BOX 1 GANG AJUSTABLE — EMT · 2.72 h · $155.90 de material · La caja de piso de sala de juntas o conference center, donde el mueble está en medio y no hay pared cerca. DTCC llevaba 5.
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', '1 GANG ADJUSTABLE FLOOR BOX', 1),
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', '20A DUPLEX RECEPTACLE', 1),
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', '1 GANG BRASS DEVICE COVER', 1),
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', '1/2"     EMT CONDUIT', 25),
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', '1/2"       EMT ELBOW', 1),
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', '#12     GROUND PIGTAIL', 1),
    ('FLOOR BOX 1 GANG AJUSTABLE — EMT', 'YELLOW WIRENUTS', 3),

    -- DISCONNECT 30A/3P EQUIPO MECÁNICO — EMT · 4.54 h · $69.55 de material · La desconexión local junto a la unidad mecánica (RTU, extractor, AHU): el tubo del panel, el disconnect en la pared y el latiguillo flexible hasta el equipo. DTCC lo llevaba en todas las conexiones mecánicas.
    ('DISCONNECT 30A/3P EQUIPO MECÁNICO — EMT', '30A/3P DISCONNECT SWITCH', 1),
    ('DISCONNECT 30A/3P EQUIPO MECÁNICO — EMT', '3/4"     EMT CONDUIT', 25),
    ('DISCONNECT 30A/3P EQUIPO MECÁNICO — EMT', '3/4"       EMT S.S. D/C CONNECTOR', 2),
    ('DISCONNECT 30A/3P EQUIPO MECÁNICO — EMT', '3/4"       EMT S.S. D/C COUPLING', 2.5),
    ('DISCONNECT 30A/3P EQUIPO MECÁNICO — EMT', '3/4"      EMT STRAP 1 HOLE STRAP', 3),
    ('DISCONNECT 30A/3P EQUIPO MECÁNICO — EMT', '# 10      THHN STRANDED CU.', 0.124),
    ('DISCONNECT 30A/3P EQUIPO MECÁNICO — EMT', '1/2"      FLEX. METAL CONDUIT', 6),
    ('DISCONNECT 30A/3P EQUIPO MECÁNICO — EMT', '1/2"      FLEX. METAL ST. CONNECT.', 2),
    ('DISCONNECT 30A/3P EQUIPO MECÁNICO — EMT', 'YELLOW WIRENUTS', 3),

    -- FURNITURE FEED — EMT · 3.35 h · $256.50 de material · La alimentación a mobiliario modular: el tubo llega a la pared o al piso y de ahí sale el latiguillo que entra al canal del mueble. DTCC llevaba 2.
    ('FURNITURE FEED — EMT', 'FURNITURE FEED', 1),
    ('FURNITURE FEED — EMT', '4-11/16 BOX', 1),
    ('FURNITURE FEED — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('FURNITURE FEED — EMT', '1/2"     EMT CONDUIT', 25),
    ('FURNITURE FEED — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('FURNITURE FEED — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('FURNITURE FEED — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('FURNITURE FEED — EMT', '1/2"       EMT ELBOW', 1),
    ('FURNITURE FEED — EMT', '# 12      THHN STRANDED CU.', 0.125),
    ('FURNITURE FEED — EMT', 'YELLOW WIRENUTS', 6),
    ('FURNITURE FEED — EMT', '4"X4" BLANK COVER', 1),

    -- LUMINARIA 2X2 — EMT · 2.81 h · $99.12 de material · La 2x2 empotrada en retícula alimentada en fila con EMT y whip de 6 ft. Es la hermana que le faltaba a la 2X4 que ya existe; Stuart llevaba 7 y DTCC 2.
    ('LUMINARIA 2X2 — EMT', '24"X24" LED TROFFER (RECESSED)', 1),
    ('LUMINARIA 2X2 — EMT', 'JB 1900 BOX', 1),
    ('LUMINARIA 2X2 — EMT', 'T-BAR BOX HANGER', 1),
    ('LUMINARIA 2X2 — EMT', '1/2"     EMT CONDUIT', 10),
    ('LUMINARIA 2X2 — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('LUMINARIA 2X2 — EMT', '1/2"       EMT S.S. D/C COUPLING', 1),
    ('LUMINARIA 2X2 — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('LUMINARIA 2X2 — EMT', '# 12      THHN STRANDED CU.', 0.048),
    ('LUMINARIA 2X2 — EMT', '3/8"      FLEX. METAL CONDUIT', 6),
    ('LUMINARIA 2X2 — EMT', '3/8"      FLEX. METAL ST. CONNECT.', 2),
    ('LUMINARIA 2X2 — EMT', 'YELLOW WIRENUTS', 3),
    ('LUMINARIA 2X2 — EMT', '#12     GROUND PIGTAIL', 1),
    ('LUMINARIA 2X2 — EMT', 'FIXTURES HOLDER CLIPS', 4),

    -- LUMINARIA 2X2 — MC · 2.38 h · $94.44 de material · La misma 2x2 en obra ligera de MC (tienda, oficina), que es el método con el que Edgar hizo Stuart: el MC entra directo a la luminaria, sin whip.
    ('LUMINARIA 2X2 — MC', '24"X24" LED TROFFER (RECESSED)', 1),
    ('LUMINARIA 2X2 — MC', 'JB 1900 BOX', 1),
    ('LUMINARIA 2X2 — MC', 'T-BAR BOX HANGER', 1),
    ('LUMINARIA 2X2 — MC', '12/2   MC', 0.015),
    ('LUMINARIA 2X2 — MC', 'MC SNAP-IN CONNECTOR 3/8"', 3),
    ('LUMINARIA 2X2 — MC', 'MC CONDUIT STRAP', 2),
    ('LUMINARIA 2X2 — MC', 'YELLOW WIRENUTS', 3),
    ('LUMINARIA 2X2 — MC', '#12     GROUND PIGTAIL', 1),
    ('LUMINARIA 2X2 — MC', 'FIXTURES HOLDER CLIPS', 4),

    -- RECESSED CAN 4" — EMT · 2.04 h · $54.87 de material · Can de 4" empotrado en cielo duro o de retícula en obra de EMT. Stuart contó 14 cans de 4" y DTCC 3+3.
    ('RECESSED CAN 4" — EMT', '4" RECESSED CAN LIGHT', 1),
    ('RECESSED CAN 4" — EMT', 'JB 1900 BOX', 1),
    ('RECESSED CAN 4" — EMT', '1/2"     EMT CONDUIT', 8),
    ('RECESSED CAN 4" — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('RECESSED CAN 4" — EMT', '1/2"       EMT S.S. D/C COUPLING', 1),
    ('RECESSED CAN 4" — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 1),
    ('RECESSED CAN 4" — EMT', '# 12      THHN STRANDED CU.', 0.042),
    ('RECESSED CAN 4" — EMT', '3/8"      FLEX. METAL CONDUIT', 6),
    ('RECESSED CAN 4" — EMT', '3/8"      FLEX. METAL ST. CONNECT.', 2),
    ('RECESSED CAN 4" — EMT', 'YELLOW WIRENUTS', 3),
    ('RECESSED CAN 4" — EMT', '#12     GROUND PIGTAIL', 1),
    ('RECESSED CAN 4" — EMT', 'T-BAR BOX HANGER', 1),

    -- RECESSED CAN 4" — MC · 1.65 h · $50.44 de material · El mismo can de 4" cuando la obra va en MC, que es como Edgar hizo Stuart (3.000 ft de 12/2 MC).
    ('RECESSED CAN 4" — MC', '4" RECESSED CAN LIGHT', 1),
    ('RECESSED CAN 4" — MC', 'JB 1900 BOX', 1),
    ('RECESSED CAN 4" — MC', '12/2   MC', 0.012),
    ('RECESSED CAN 4" — MC', 'MC SNAP-IN CONNECTOR 3/8"', 3),
    ('RECESSED CAN 4" — MC', 'MC CONDUIT STRAP', 2),
    ('RECESSED CAN 4" — MC', 'YELLOW WIRENUTS', 3),
    ('RECESSED CAN 4" — MC', '#12     GROUND PIGTAIL', 1),
    ('RECESSED CAN 4" — MC', 'T-BAR BOX HANGER', 1),

    -- ROUGH-IN CAN 6" — EMT (SIN LUMINARIA) · 1.29 h · $19.87 de material · El rough-in del can de 6": caja, tubo, whip y cable, SIN la luminaria (el can de 6" no existe en el catálogo). El nombre lo dice para que no se confunda con un punto completo.
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', 'JB 1900 BOX', 1),
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', '1/2"     EMT CONDUIT', 8),
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', '1/2"       EMT S.S. D/C COUPLING', 1),
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', '1/2"      EMT STRAP 1 HOLE STRAP', 1),
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', '# 12      THHN STRANDED CU.', 0.042),
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', '3/8"      FLEX. METAL CONDUIT', 6),
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', '3/8"      FLEX. METAL ST. CONNECT.', 2),
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', 'YELLOW WIRENUTS', 3),
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', '#12     GROUND PIGTAIL', 1),
    ('ROUGH-IN CAN 6" — EMT (SIN LUMINARIA)', 'T-BAR BOX HANGER', 1),

    -- DOWN LIGHT — MC · 1.70 h · $15.44 de material · Down light en build-out de MC. Stuart llevaba 4 y UM 9.
    ('DOWN LIGHT — MC', 'DOWN LIGHT ', 1),
    ('DOWN LIGHT — MC', 'JB 1900 BOX', 1),
    ('DOWN LIGHT — MC', '12/2   MC', 0.012),
    ('DOWN LIGHT — MC', 'MC SNAP-IN CONNECTOR 3/8"', 3),
    ('DOWN LIGHT — MC', 'MC CONDUIT STRAP', 2),
    ('DOWN LIGHT — MC', 'YELLOW WIRENUTS', 3),
    ('DOWN LIGHT — MC', '#12     GROUND PIGTAIL', 1),
    ('DOWN LIGHT — MC', 'T-BAR BOX HANGER', 1),

    -- PENDANT — EMT · 2.49 h · $207.34 de material · Pendant colgado de caja a la vista, el de DTCC (15 unidades). Sin whip a propósito: el canopy del pendant monta directo sobre la caja.
    ('PENDANT — EMT', 'PENDANT', 1),
    ('PENDANT — EMT', 'JB 1900 DEEP BOX', 1),
    ('PENDANT — EMT', 'CEILING RING  1/2"', 1),
    ('PENDANT — EMT', '1/2"     EMT CONDUIT', 12),
    ('PENDANT — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('PENDANT — EMT', '1/2"       EMT S.S. D/C COUPLING', 1),
    ('PENDANT — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('PENDANT — EMT', '# 12      THHN STRANDED CU.', 0.036),
    ('PENDANT — EMT', 'YELLOW WIRENUTS', 3),
    ('PENDANT — EMT', '#12     GROUND PIGTAIL', 1),
    ('PENDANT — EMT', 'T-BAR BOX HANGER', 1),

    -- LED LINEAR — EMT · 2.20 h · $152.50 de material · Tira lineal LED (strip) por unidad de fila, suspendida o de superficie. Se multiplica por cuántas unidades tenga la corrida: el tubo solo llega a la primera, las demás se empalman entre sí.
    ('LED LINEAR — EMT', 'LED LINEAR', 1),
    ('LED LINEAR — EMT', 'JB 1900 BOX', 1),
    ('LED LINEAR — EMT', '1/2"     EMT CONDUIT', 6),
    ('LED LINEAR — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('LED LINEAR — EMT', '1/2"       EMT S.S. D/C COUPLING', 1),
    ('LED LINEAR — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 1),
    ('LED LINEAR — EMT', '# 12      THHN STRANDED CU.', 0.036),
    ('LED LINEAR — EMT', '3/8"      FLEX. METAL CONDUIT', 6),
    ('LED LINEAR — EMT', '3/8"      FLEX. METAL ST. CONNECT.', 2),
    ('LED LINEAR — EMT', 'YELLOW WIRENUTS', 3),
    ('LED LINEAR — EMT', '#12     GROUND PIGTAIL', 1),
    ('LED LINEAR — EMT', 'T-BAR BOX HANGER', 1),

    -- WALL PACK EXTERIOR — EMT · 2.54 h · $29.68 de material · Wall pack de exterior sobre muro, alimentado con EMT y bell box: fachadas, muelles de carga, puertas traseras.
    ('WALL PACK EXTERIOR — EMT', 'LED WALL PACK', 1),
    ('WALL PACK EXTERIOR — EMT', '4"x 4"    BELL BOX-BOX', 1),
    ('WALL PACK EXTERIOR — EMT', '1/2"     EMT CONDUIT', 10),
    ('WALL PACK EXTERIOR — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('WALL PACK EXTERIOR — EMT', '1/2"       EMT S.S. D/C COUPLING', 1),
    ('WALL PACK EXTERIOR — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('WALL PACK EXTERIOR — EMT', '# 12      THHN STRANDED CU.', 0.03),
    ('WALL PACK EXTERIOR — EMT', 'W.P SPLICES', 3),
    ('WALL PACK EXTERIOR — EMT', '#12     GROUND PIGTAIL', 1),

    -- EXIT SIGN — EMT · 1.89 h · $17.82 de material · Exit sign de pared o techo en circuito no conmutado. Stuart llevaba 9 y DTCC 4. Como el letrero está a $0 en el catálogo, esta receta ya es de hecho 'solo instalación': cobra la mano de obra y el rough-in, no el letrero.
    ('EXIT SIGN — EMT', 'EXIT SIGN BACK/TOP MTD', 1),
    ('EXIT SIGN — EMT', 'JB 1900 BOX', 1),
    ('EXIT SIGN — EMT', '1/2"     EMT CONDUIT', 12),
    ('EXIT SIGN — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('EXIT SIGN — EMT', '1/2"       EMT S.S. D/C COUPLING', 1),
    ('EXIT SIGN — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('EXIT SIGN — EMT', '# 12      THHN STRANDED CU.', 0.036),
    ('EXIT SIGN — EMT', 'YELLOW WIRENUTS', 3),
    ('EXIT SIGN — EMT', '#12     GROUND PIGTAIL', 1),
    ('EXIT SIGN — EMT', 'CEILING RING  1/2"', 1),

    -- LUZ DE EMERGENCIA BATERÍA — EMT · 2.14 h · $162.82 de material · Luz de emergencia con batería (bug eye) de superficie. Stuart llevaba 7. Va colgada de la misma caja, sin whip.
    ('LUZ DE EMERGENCIA BATERÍA — EMT', 'BATTERY LIGHT SURFACE', 1),
    ('LUZ DE EMERGENCIA BATERÍA — EMT', 'JB 1900 BOX', 1),
    ('LUZ DE EMERGENCIA BATERÍA — EMT', '1/2"     EMT CONDUIT', 12),
    ('LUZ DE EMERGENCIA BATERÍA — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('LUZ DE EMERGENCIA BATERÍA — EMT', '1/2"       EMT S.S. D/C COUPLING', 1),
    ('LUZ DE EMERGENCIA BATERÍA — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('LUZ DE EMERGENCIA BATERÍA — EMT', '# 12      THHN STRANDED CU.', 0.036),
    ('LUZ DE EMERGENCIA BATERÍA — EMT', 'YELLOW WIRENUTS', 3),
    ('LUZ DE EMERGENCIA BATERÍA — EMT', '#12     GROUND PIGTAIL', 1),
    ('LUZ DE EMERGENCIA BATERÍA — EMT', 'CEILING RING  1/2"', 1),

    -- LUMINARIA 2X4 — SOLO INSTALACIÓN · 2.03 h · $11.26 de material · Cuando la luminaria la pone el dueño (Stuart y DTCC): mano de obra + caja + whip flexible + conectores, sin material de luminaria. No lleva tramo de tubo a propósito: el ramal se cotiza aparte con CIRCUITO 20A DERIVADO — EMT o va por rutas.
    ('LUMINARIA 2X4 — SOLO INSTALACIÓN', '2''X4'' RECE. FLUORESCENT', 1),
    ('LUMINARIA 2X4 — SOLO INSTALACIÓN', 'JB 1900 BOX', 1),
    ('LUMINARIA 2X4 — SOLO INSTALACIÓN', 'T-BAR BOX HANGER', 1),
    ('LUMINARIA 2X4 — SOLO INSTALACIÓN', '3/8"      FLEX. METAL CONDUIT', 6),
    ('LUMINARIA 2X4 — SOLO INSTALACIÓN', '3/8"      FLEX. METAL ST. CONNECT.', 2),
    ('LUMINARIA 2X4 — SOLO INSTALACIÓN', '# 12      THHN STRANDED CU.', 0.018),
    ('LUMINARIA 2X4 — SOLO INSTALACIÓN', 'YELLOW WIRENUTS', 3),
    ('LUMINARIA 2X4 — SOLO INSTALACIÓN', '#12     GROUND PIGTAIL', 1),
    ('LUMINARIA 2X4 — SOLO INSTALACIÓN', 'FIXTURES HOLDER CLIPS', 4),

    -- LUMINARIA 2X2 — SOLO INSTALACIÓN · 1.78 h · $11.26 de material · La 2x2 del dueño, mismo caso que la 2x4 de solo instalación: cobra la mano y los accesorios del punto, no la luminaria.
    ('LUMINARIA 2X2 — SOLO INSTALACIÓN', '2''X2'' RECE. FLUORESCENT', 1),
    ('LUMINARIA 2X2 — SOLO INSTALACIÓN', 'JB 1900 BOX', 1),
    ('LUMINARIA 2X2 — SOLO INSTALACIÓN', 'T-BAR BOX HANGER', 1),
    ('LUMINARIA 2X2 — SOLO INSTALACIÓN', '3/8"      FLEX. METAL CONDUIT', 6),
    ('LUMINARIA 2X2 — SOLO INSTALACIÓN', '3/8"      FLEX. METAL ST. CONNECT.', 2),
    ('LUMINARIA 2X2 — SOLO INSTALACIÓN', '# 12      THHN STRANDED CU.', 0.018),
    ('LUMINARIA 2X2 — SOLO INSTALACIÓN', 'YELLOW WIRENUTS', 3),
    ('LUMINARIA 2X2 — SOLO INSTALACIÓN', '#12     GROUND PIGTAIL', 1),
    ('LUMINARIA 2X2 — SOLO INSTALACIÓN', 'FIXTURES HOLDER CLIPS', 4),

    -- ESTACIÓN MANUAL (PULL STATION) · 1.06 h · $5.13 de material · El punto de pull station terminado: pieza, su caja de fondo con anillo, 25 ft de 18/2 shielded y los dos conectores del lazo SLC.
    ('ESTACIÓN MANUAL (PULL STATION)', 'MANUAL PULL STATION', 1),
    ('ESTACIÓN MANUAL (PULL STATION)', 'JB 1900 BOX', 1),
    ('ESTACIÓN MANUAL (PULL STATION)', '1  GANG PLASTER RING 1/2"', 1),
    ('ESTACIÓN MANUAL (PULL STATION)', '18/2 SHIELDED FIRE ALARM CABLE', 0.025),
    ('ESTACIÓN MANUAL (PULL STATION)', 'NM CABLE CONNECTOR 1/2"', 2),
    ('ESTACIÓN MANUAL (PULL STATION)', 'CABLE STRAP', 3),
    ('ESTACIÓN MANUAL (PULL STATION)', 'YELLOW WIRENUTS', 3),

    -- DETECTOR DE HUMO CON BASE · 1.21 h · $123.37 de material · El detector de techo terminado, para los 6 smokes que contó en Stuart y para cualquier obra comercial.
    ('DETECTOR DE HUMO CON BASE', 'SMOKE DETECTOR W/BASE', 1),
    ('DETECTOR DE HUMO CON BASE', 'JB 1900 BOX', 1),
    ('DETECTOR DE HUMO CON BASE', 'CEILING RING  1/2"', 1),
    ('DETECTOR DE HUMO CON BASE', '18/2 SHIELDED FIRE ALARM CABLE', 0.025),
    ('DETECTOR DE HUMO CON BASE', 'NM CABLE CONNECTOR 1/2"', 2),
    ('DETECTOR DE HUMO CON BASE', 'CABLE STRAP', 3),
    ('DETECTOR DE HUMO CON BASE', 'YELLOW WIRENUTS', 3),

    -- DETECTOR DE CALOR CON BASE · 1.31 h · $107.37 de material · El mismo punto pero para cocina, cuarto mecánico o eléctrico, donde el código no deja poner detector de humo.
    ('DETECTOR DE CALOR CON BASE', 'HEAT DETECTOR W/BASE', 1),
    ('DETECTOR DE CALOR CON BASE', 'JB 1900 BOX', 1),
    ('DETECTOR DE CALOR CON BASE', 'CEILING RING  1/2"', 1),
    ('DETECTOR DE CALOR CON BASE', '18/2 SHIELDED FIRE ALARM CABLE', 0.025),
    ('DETECTOR DE CALOR CON BASE', 'NM CABLE CONNECTOR 1/2"', 2),
    ('DETECTOR DE CALOR CON BASE', 'CABLE STRAP', 3),
    ('DETECTOR DE CALOR CON BASE', 'YELLOW WIRENUTS', 3),

    -- DETECTOR DE HUMO DE DUCTO · 3.76 h · $5.64 de material · El detector en el ducto de la unidad de aire, el que pide el mecánico para el paro del ventilador.
    ('DETECTOR DE HUMO DE DUCTO', 'DUCT SMOKE DETECTOR', 1),
    ('DETECTOR DE HUMO DE DUCTO', 'JB 1900 BOX', 1),
    ('DETECTOR DE HUMO DE DUCTO', '4"X4" BLANK COVER', 1),
    ('DETECTOR DE HUMO DE DUCTO', '18/2 SHIELDED FIRE ALARM CABLE', 0.035),
    ('DETECTOR DE HUMO DE DUCTO', 'NM CABLE CONNECTOR 1/2"', 2),
    ('DETECTOR DE HUMO DE DUCTO', 'CABLE STRAP', 3),
    ('DETECTOR DE HUMO DE DUCTO', 'YELLOW WIRENUTS', 3),
    ('DETECTOR DE HUMO DE DUCTO', 'FIRE ALARM RELAY', 1),

    -- STROBE F/A · 0.86 h · $65.83 de material · El strobe de pasillo o baño; la pieza del catálogo ya trae su backbox, por eso la receta no lleva caja aparte.
    ('STROBE F/A', 'STROBE LIGHT W/BACKBOX', 1),
    ('STROBE F/A', '14/4 FPL FIRE ALARM CABLE', 0.025),
    ('STROBE F/A', 'NM CABLE CONNECTOR 1/2"', 2),
    ('STROBE F/A', 'CABLE STRAP', 3),
    ('STROBE F/A', 'YELLOW WIRENUTS', 3),

    -- HORN/STROBE F/A · 0.86 h · $94.83 de material · El horn/strobe de salida o de área común, con backbox incluido en la pieza.
    ('HORN/STROBE F/A', 'HORN/STROBE LIGHT W/BACKBOX', 1),
    ('HORN/STROBE F/A', '14/4 FPL FIRE ALARM CABLE', 0.025),
    ('HORN/STROBE F/A', 'NM CABLE CONNECTOR 1/2"', 2),
    ('HORN/STROBE F/A', 'CABLE STRAP', 3),
    ('HORN/STROBE F/A', 'YELLOW WIRENUTS', 3),

    -- HORN/STROBE F/A INTEMPERIE (WP) · 2.32 h · $114.75 de material · El horn/strobe exterior de fachada o entrada, el que pide el bombero.
    ('HORN/STROBE F/A INTEMPERIE (WP)', 'WP HORN/STROBE LIGHT W/BACKBOX', 1),
    ('HORN/STROBE F/A INTEMPERIE (WP)', '14/4 FPL FIRE ALARM CABLE', 0.025),
    ('HORN/STROBE F/A INTEMPERIE (WP)', 'NM CABLE CONNECTOR 1/2"', 2),
    ('HORN/STROBE F/A INTEMPERIE (WP)', 'CABLE STRAP', 3),
    ('HORN/STROBE F/A INTEMPERIE (WP)', 'YELLOW WIRENUTS', 3),
    ('HORN/STROBE F/A INTEMPERIE (WP)', '1/2"     EMT CONDUIT', 10),
    ('HORN/STROBE F/A INTEMPERIE (WP)', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('HORN/STROBE F/A INTEMPERIE (WP)', '1/2"      EMT STRAP 1 HOLE STRAP', 2),

    -- BOCINA F/A (SPEAKER) · 1.16 h · $5.13 de material · La bocina sola de evacuación por voz, en pared o techo, sobre circuito de audio 18/2 apantallado.
    ('BOCINA F/A (SPEAKER)', 'FIRE ALARM SPEAKER', 1),
    ('BOCINA F/A (SPEAKER)', 'JB 1900 BOX', 1),
    ('BOCINA F/A (SPEAKER)', '1  GANG PLASTER RING 1/2"', 1),
    ('BOCINA F/A (SPEAKER)', '18/2 SHIELDED FIRE ALARM CABLE', 0.025),
    ('BOCINA F/A (SPEAKER)', 'NM CABLE CONNECTOR 1/2"', 2),
    ('BOCINA F/A (SPEAKER)', 'CABLE STRAP', 3),
    ('BOCINA F/A (SPEAKER)', 'YELLOW WIRENUTS', 3),

    -- SPEAKER/STROBE F/A (EVAC DE VOZ) · 2.27 h · $215.44 de material · El punto de evacuación por voz de edificio alto: bocina y estrobo juntos, cada uno en su circuito.
    ('SPEAKER/STROBE F/A (EVAC DE VOZ)', 'VOICE EVAC SPEAKER', 1),
    ('SPEAKER/STROBE F/A (EVAC DE VOZ)', 'STROBE LIGHT W/BACKBOX', 1),
    ('SPEAKER/STROBE F/A (EVAC DE VOZ)', '18/2 SHIELDED FIRE ALARM CABLE', 0.025),
    ('SPEAKER/STROBE F/A (EVAC DE VOZ)', '14/4 FPL FIRE ALARM CABLE', 0.025),
    ('SPEAKER/STROBE F/A (EVAC DE VOZ)', 'NM CABLE CONNECTOR 1/2"', 4),
    ('SPEAKER/STROBE F/A (EVAC DE VOZ)', 'CABLE STRAP', 6),
    ('SPEAKER/STROBE F/A (EVAC DE VOZ)', 'YELLOW WIRENUTS', 4),
    ('SPEAKER/STROBE F/A (EVAC DE VOZ)', 'JB 1900 BOX', 1),
    ('SPEAKER/STROBE F/A (EVAC DE VOZ)', '1  GANG PLASTER RING 1/2"', 1),

    -- MÓDULO DE MONITOREO F/A · 1.43 h · $150.95 de material · El módulo que vigila el flujo de agua, la tamper o un contacto seco, o que dispara un relé de control; lleva su resistencia de fin de línea.
    ('MÓDULO DE MONITOREO F/A', 'FIRE ALARM MODULE', 1),
    ('MÓDULO DE MONITOREO F/A', 'JB 1900 BOX', 1),
    ('MÓDULO DE MONITOREO F/A', '4"X4" BLANK COVER', 1),
    ('MÓDULO DE MONITOREO F/A', '18/2 SHIELDED FIRE ALARM CABLE', 0.025),
    ('MÓDULO DE MONITOREO F/A', 'FIRE ALARM EOL RESISTOR', 1),
    ('MÓDULO DE MONITOREO F/A', 'NM CABLE CONNECTOR 1/2"', 3),
    ('MÓDULO DE MONITOREO F/A', 'CABLE STRAP', 3),
    ('MÓDULO DE MONITOREO F/A', 'YELLOW WIRENUTS', 4),

    -- PANEL BOOSTER 24VDC — EMT · 4.60 h · $438.81 de material · Cuando los strobes no alcanzan con la fuente del panel: el booster con su ramal dedicado de 120 V y su salida NAC.
    ('PANEL BOOSTER 24VDC — EMT', 'POWER SUPPLY 24VDC (FIRE ALARM)', 1),
    ('PANEL BOOSTER 24VDC — EMT', 'BREAKER 1P 20A', 1),
    ('PANEL BOOSTER 24VDC — EMT', '1/2"     EMT CONDUIT', 25),
    ('PANEL BOOSTER 24VDC — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('PANEL BOOSTER 24VDC — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('PANEL BOOSTER 24VDC — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('PANEL BOOSTER 24VDC — EMT', '# 12      THHN STRANDED CU.', 0.075),
    ('PANEL BOOSTER 24VDC — EMT', '14/4 FPL FIRE ALARM CABLE', 0.05),
    ('PANEL BOOSTER 24VDC — EMT', '18/2 SHIELDED FIRE ALARM CABLE', 0.025),
    ('PANEL BOOSTER 24VDC — EMT', 'NM CABLE CONNECTOR 1/2"', 3),
    ('PANEL BOOSTER 24VDC — EMT', 'CABLE STRAP', 6),
    ('PANEL BOOSTER 24VDC — EMT', 'YELLOW WIRENUTS', 6),
    ('PANEL BOOSTER 24VDC — EMT', 'FIRE ALARM EOL RESISTOR', 2),
    ('PANEL BOOSTER 24VDC — EMT', '1/2"       LOCKNUT', 2),

    -- PUESTA EN MARCHA F/A (POR PROYECTO) · 20.00 h · $0.00 de material · La línea que Edgar siempre se deja fuera: programar el panel, probar dispositivo por dispositivo y sacar la certificación con el inspector.
    ('PUESTA EN MARCHA F/A (POR PROYECTO)', 'FIRE ALARM PROGRAMMING', 1),
    ('PUESTA EN MARCHA F/A (POR PROYECTO)', 'FIRE ALARM TESTING', 1),
    ('PUESTA EN MARCHA F/A (POR PROYECTO)', 'F/A INSPECTION & CERTIFICATION', 1),

    -- SALIDA DE DATOS CAT6 1 PUERTO — EMT · 2.34 h · $60.92 de material · El data drop completo cuando Max Power SÍ jala y termina el CAT6 — el caso Stuart (6 data drops CAT6 dentro del scope); la receta que ya existe es el caso contrario, tubo vacío para el de low voltage.
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', 'DATA OUTLET (1 PORT)', 1),
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', '4-11/16 BOX', 1),
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', '1/2"     EMT CONDUIT', 25),
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', '1/2" ISOLATING BUSHING', 1),
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', 'CAT6 CABLE', 0.09),
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', 'CABLE STRAP (Telecom)', 8),
    ('SALIDA DE DATOS CAT6 1 PUERTO — EMT', 'RJ45 termination', 1),

    -- SALIDA DE DATOS CAT6 2 PUERTOS — EMT · 2.74 h · $86.44 de material · El drop estándar de escritorio de oficina: un puerto para la PC y otro para el teléfono IP o la impresora. Es el que más se repite en un build-out.
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', 'DATA OUTLET (2 PORTS)', 1),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', '4-11/16 BOX', 1),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', '1/2"     EMT CONDUIT', 25),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', '1/2" ISOLATING BUSHING', 1),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', 'CAT6 CABLE', 0.18),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', 'CABLE STRAP (Telecom)', 8),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — EMT', 'RJ45 termination', 2),

    -- SALIDA DE DATOS CAT6 1 PUERTO — MC · 1.48 h · $44.29 de material · La salida de datos en obra ligera cableada en MC (tienda, oficina, remodelación tipo Stuart): no hay tubo corrido, solo mud ring en el drywall, un stub de 8 ft al plenum y el CAT6 abierto sobre soportes. Si en tu obra el dato SÍ va en tubo aunque la fuerza sea MC, usa la de EMT.
    ('SALIDA DE DATOS CAT6 1 PUERTO — MC', 'DATA OUTLET (1 PORT)', 1),
    ('SALIDA DE DATOS CAT6 1 PUERTO — MC', 'DRYWALL MUD RING', 1),
    ('SALIDA DE DATOS CAT6 1 PUERTO — MC', '1/2"     EMT CONDUIT', 8),
    ('SALIDA DE DATOS CAT6 1 PUERTO — MC', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('SALIDA DE DATOS CAT6 1 PUERTO — MC', '1/2" ISOLATING BUSHING', 2),
    ('SALIDA DE DATOS CAT6 1 PUERTO — MC', 'CAT6 CABLE', 0.09),
    ('SALIDA DE DATOS CAT6 1 PUERTO — MC', 'CABLE STRAP (Telecom)', 10),
    ('SALIDA DE DATOS CAT6 1 PUERTO — MC', 'RJ45 termination', 1),

    -- SALIDA DE DATOS CAT6 2 PUERTOS — MC · 1.88 h · $69.81 de material · El drop de escritorio en obra de MC: dos puertos, sin tubo corrido. Es el que usarías en un build-out de oficina pequeña o una remodelación en edificio ocupado.
    ('SALIDA DE DATOS CAT6 2 PUERTOS — MC', 'DATA OUTLET (2 PORTS)', 1),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — MC', 'DRYWALL MUD RING', 1),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — MC', '1/2"     EMT CONDUIT', 8),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — MC', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — MC', '1/2" ISOLATING BUSHING', 2),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — MC', 'CAT6 CABLE', 0.18),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — MC', 'CABLE STRAP (Telecom)', 10),
    ('SALIDA DE DATOS CAT6 2 PUERTOS — MC', 'RJ45 termination', 2),

    -- SALIDA DE TELÉFONO — EMT · 2.19 h · $31.29 de material · El punto de teléfono analógico o de fax que todavía piden en recepción, cuarto de máquinas y ascensor. El takeoff de DTCC trae 2 tel: son estas.
    ('SALIDA DE TELÉFONO — EMT', 'TELEPHONE OUTLET (2 JACKS)', 1),
    ('SALIDA DE TELÉFONO — EMT', '4-11/16 BOX', 1),
    ('SALIDA DE TELÉFONO — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('SALIDA DE TELÉFONO — EMT', '1/2"     EMT CONDUIT', 25),
    ('SALIDA DE TELÉFONO — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SALIDA DE TELÉFONO — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('SALIDA DE TELÉFONO — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('SALIDA DE TELÉFONO — EMT', '1/2" ISOLATING BUSHING', 1),
    ('SALIDA DE TELÉFONO — EMT', 'CAT6 CABLE', 0.18),
    ('SALIDA DE TELÉFONO — EMT', 'CABLE STRAP (Telecom)', 8),
    ('SALIDA DE TELÉFONO — EMT', 'RJ45 termination', 2),

    -- SALIDA DE TV / COAX — EMT · 2.06 h · $25.76 de material · El punto de TV de sala de espera, lobby o conference room, con su RG6 hasta el head-end. Ojo: le falta el conector F, ver faltan_en_catalogo.
    ('SALIDA DE TV / COAX — EMT', 'TV OUTLET', 1),
    ('SALIDA DE TV / COAX — EMT', '4-11/16 BOX', 1),
    ('SALIDA DE TV / COAX — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('SALIDA DE TV / COAX — EMT', '1/2"     EMT CONDUIT', 25),
    ('SALIDA DE TV / COAX — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('SALIDA DE TV / COAX — EMT', '1/2"       EMT S.S. D/C COUPLING', 2.5),
    ('SALIDA DE TV / COAX — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 3),
    ('SALIDA DE TV / COAX — EMT', '1/2" ISOLATING BUSHING', 1),
    ('SALIDA DE TV / COAX — EMT', 'RG6 TV CABLE', 0.075),
    ('SALIDA DE TV / COAX — EMT', 'CABLE STRAP (Telecom)', 6),
    ('SALIDA DE TV / COAX — EMT', 'BNC  CONNECTORS', 2),

    -- PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT · 2.97 h · $300.78 de material · El access point de techo en oficina o conference center: caja en el T-bar, stub corto y CAT6 al IDF. Si el dueño suministra el WAP, pon el precio en $0 y quedan las 1.4 h de instalación.
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', 'WIRELESS ACCESS POINT (WAP)', 1),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', 'JB 1900 BOX', 1),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', 'T-BAR BOX HANGER', 1),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', '1/2"     EMT CONDUIT', 10),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', '1/2" ISOLATING BUSHING', 1),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', 'CAT6 CABLE', 0.12),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', 'CABLE STRAP (Telecom)', 12),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', 'RJ45 termination', 2),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT', '4"X4" BLANK COVER', 1),

    -- PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — MC · 2.50 h · $295.84 de material · El mismo AP pero en obra ligera cableada en MC: no hay stub de tubo, el CAT6 llega abierto sobre soportes hasta la caja del T-bar. Es la versión de remodelación en edificio ocupado.
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — MC', 'WIRELESS ACCESS POINT (WAP)', 1),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — MC', 'JB 1900 BOX', 1),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — MC', 'T-BAR BOX HANGER', 1),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — MC', 'CAT6 CABLE', 0.12),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — MC', 'CABLE STRAP (Telecom)', 14),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — MC', 'RJ45 termination', 2),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — MC', 'NM CABLE CONNECTOR 1/2"', 1),
    ('PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — MC', '4"X4" BLANK COVER', 1),

    -- CÁMARA IP (PoE) EN TECHO — EMT · 2.99 h · $264.47 de material · La cámara de seguridad de pasillo, lobby o parqueo cubierto, alimentada por PoE con un solo CAT6. Si van cámaras analógicas usa DOME CAMERA o ANALOG/HD CAMERA en lugar de la IP y cambia el CAT6 por RG6.
    ('CÁMARA IP (PoE) EN TECHO — EMT', 'IP CAMERA (PoE) - 4K AI', 1),
    ('CÁMARA IP (PoE) EN TECHO — EMT', 'JB 1900 BOX', 1),
    ('CÁMARA IP (PoE) EN TECHO — EMT', 'T-BAR BOX HANGER', 1),
    ('CÁMARA IP (PoE) EN TECHO — EMT', '1/2"     EMT CONDUIT', 15),
    ('CÁMARA IP (PoE) EN TECHO — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('CÁMARA IP (PoE) EN TECHO — EMT', '1/2"       EMT S.S. D/C COUPLING', 1.5),
    ('CÁMARA IP (PoE) EN TECHO — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('CÁMARA IP (PoE) EN TECHO — EMT', '1/2" ISOLATING BUSHING', 1),
    ('CÁMARA IP (PoE) EN TECHO — EMT', 'CAT6 CABLE', 0.15),
    ('CÁMARA IP (PoE) EN TECHO — EMT', 'CABLE STRAP (Telecom)', 15),
    ('CÁMARA IP (PoE) EN TECHO — EMT', 'RJ45 termination', 2),
    ('CÁMARA IP (PoE) EN TECHO — EMT', '4"X4" BLANK COVER', 1),

    -- LECTOR DE TARJETA (CARD READER) — EMT · 7.71 h · $407.53 de material · La PUERTA completa de control de acceso: el lector, su cerradura eléctrica, el contacto magnético y el cable al panel. El READER CONTROLLER (2 h) y CARD ACCESS PROGRAMING (8 h) van aparte como ítem suelto, son uno por edificio, no por puerta.
    ('LECTOR DE TARJETA (CARD READER) — EMT', 'CARD READER', 1),
    ('LECTOR DE TARJETA (CARD READER) — EMT', 'JB 1900 BOX', 2),
    ('LECTOR DE TARJETA (CARD READER) — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('LECTOR DE TARJETA (CARD READER) — EMT', '1/2"     EMT CONDUIT', 12),
    ('LECTOR DE TARJETA (CARD READER) — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('LECTOR DE TARJETA (CARD READER) — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 2),
    ('LECTOR DE TARJETA (CARD READER) — EMT', '1/2" ISOLATING BUSHING', 1),
    ('LECTOR DE TARJETA (CARD READER) — EMT', '2/P #18  SECURITY CABLE', 0.45),
    ('LECTOR DE TARJETA (CARD READER) — EMT', 'SINGLE ELECTRIC DOOR STRIKE', 1),
    ('LECTOR DE TARJETA (CARD READER) — EMT', 'MAGNETIC DOOR SWITCH', 1),
    ('LECTOR DE TARJETA (CARD READER) — EMT', 'CABLE STRAP (Telecom)', 15),
    ('LECTOR DE TARJETA (CARD READER) — EMT', '3/8"      FLEX. METAL CONDUIT', 3),
    ('LECTOR DE TARJETA (CARD READER) — EMT', '3/8"      FLEX. METAL ST. CONNECT.', 2),

    -- CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT · 2.03 h · $32.10 de material · El caso DTCC: Max Power pone el tubo y la cuerda para FA / data / AV / security, el cable lo pone otro. En ese scope los conduits vacíos eran partida propia, así que esta receta se cotiza sola y NO lleva cable ni dispositivo.
    ('CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT', '4-11/16 BOX', 1),
    ('CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT', '1  GANG PLASTER RING 1/2"', 1),
    ('CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT', '3/4"     EMT CONDUIT', 25),
    ('CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT', '3/4"       EMT S.S. D/C CONNECTOR', 2),
    ('CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT', '3/4"       EMT S.S. D/C COUPLING', 2.5),
    ('CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT', '3/4"      EMT STRAP 1 HOLE STRAP', 3),
    ('CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT', '3/4"       EMT ELBOW', 1),
    ('CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT', '3/4" ISOLATING BUSHING', 1),
    ('CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT', 'PULL STRING', 0.03),

    -- CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT · 2.27 h · $47.00 de material · El mismo conduit vacío del DTCC pero cuando el tramo es de AV, de un bundle de varios CAT6 o de un riser: 1" con anillo de 2 gang. Si el scope pide 1-1/2" o 2", clona esta y cambia tubo, conector, acople, grapa, codo y bushing.
    ('CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT', '4-11/16 BOX', 1),
    ('CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT', '2  GANG PLASTER RING 1/2"', 1),
    ('CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT', '1"         EMT CONDUIT', 25),
    ('CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT', '1"           EMT S.S.D/C CONNECTOR', 2),
    ('CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT', '1"           EMT S.S.D/C  COUPLING', 2.5),
    ('CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT', '1"          EMT STRAP 1 HOLE STARP', 3),
    ('CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT', '1"           EMTELBOW', 1),
    ('CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT', '1" ISOLATING BUSHING', 1),
    ('CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT', 'PULL STRING', 0.03),

    -- RACK DE COMUNICACIONES (IDF) 24 PUERTOS · 12.73 h · $986.75 de material · Es el otro extremo de todos los drops: sin él los CAT6 no rematan en ninguna parte y se te queda fuera del bid. Va UNO por piso o por edificio, no por punto; por eso pies_editable = false. Si el switch lo pone el dueño, déjalo en la receta pero con el precio en $0.
    ('RACK DE COMUNICACIONES (IDF) 24 PUERTOS', '4''x8'' PLYWOOD PH BACKBOARD', 1),
    ('RACK DE COMUNICACIONES (IDF) 24 PUERTOS', 'Network rack 12U wall-mount', 1),
    ('RACK DE COMUNICACIONES (IDF) 24 PUERTOS', '24-PORT PATCH PANEL', 1),
    ('RACK DE COMUNICACIONES (IDF) 24 PUERTOS', 'PoE+ SWITCH 24-port (rack)', 1),
    ('RACK DE COMUNICACIONES (IDF) 24 PUERTOS', 'CABLE STRAP (Telecom)', 25),
    ('RACK DE COMUNICACIONES (IDF) 24 PUERTOS', '20A DUPLEX RECEPTACLE', 1),
    ('RACK DE COMUNICACIONES (IDF) 24 PUERTOS', '4-11/16 BOX', 1),
    ('RACK DE COMUNICACIONES (IDF) 24 PUERTOS', '1  GANG PLASTER RING 1/2"', 1),
    ('RACK DE COMUNICACIONES (IDF) 24 PUERTOS', 'GROUNDING BAR', 1),
    ('RACK DE COMUNICACIONES (IDF) 24 PUERTOS', '# 6  BARE COPPER  WIRE', 20),

    -- CIRCUITO 20A DERIVADO — MC · 2.44 h · $56.30 de material · El gemelo en MC de la receta que ya existe en EMT: el tramo del panel a la primera caja en obra ligera tipo Stuart, donde Edgar cablea todo en MC.
    ('CIRCUITO 20A DERIVADO — MC', 'BREAKER 1P 20A', 1),
    ('CIRCUITO 20A DERIVADO — MC', '12/2   MC', 0.06),
    ('CIRCUITO 20A DERIVADO — MC', 'MC SNAP-IN CONNECTOR 3/8"', 2),
    ('CIRCUITO 20A DERIVADO — MC', 'MC CONDUIT STRAP', 8),
    ('CIRCUITO 20A DERIVADO — MC', '#12     GROUND PIGTAIL', 1),
    ('CIRCUITO 20A DERIVADO — MC', 'YELLOW WIRENUTS', 3),

    -- CIRCUITO 20A DERIVADO — ROMEX · 1.69 h · $34.68 de material · Va en modo remodelacion, no comercial: el romex no entra en obra comercial. Es el circuito derivado de casa o de remodelacion residencial, con los pies editables porque ahi la medida real manda.
    ('CIRCUITO 20A DERIVADO — ROMEX', 'BREAKER 1P 20A', 1),
    ('CIRCUITO 20A DERIVADO — ROMEX', '12/2   ROMEX', 0.06),
    ('CIRCUITO 20A DERIVADO — ROMEX', 'ROMEX STAPLES', 13),
    ('CIRCUITO 20A DERIVADO — ROMEX', 'NM CABLE CONNECTOR 1/2"', 1),
    ('CIRCUITO 20A DERIVADO — ROMEX', '#12     GROUND PIGTAIL', 1),
    ('CIRCUITO 20A DERIVADO — ROMEX', 'YELLOW WIRENUTS', 3),

    -- HOMERUN 20A AL PANEL — EMT · 6.20 h · $156.88 de material · El tramo del panel a la primera caja de un circuito nuevo, con el trabajo de panel dentro. Se diferencia de CIRCUITO 20A DERIVADO — EMT, que ya existe, en que ese va en 1/2" a 60 ft sin tocar el panel, y este en 3/4" a 75 ft con breaker, terminacion y bushing de tierra.
    ('HOMERUN 20A AL PANEL — EMT', 'BREAKER 1P 20A', 1),
    ('HOMERUN 20A AL PANEL — EMT', 'Panel Termination (per circuit)', 1),
    ('HOMERUN 20A AL PANEL — EMT', '3/4"     EMT CONDUIT', 75),
    ('HOMERUN 20A AL PANEL — EMT', '# 12      THHN STRANDED CU.', 0.225),
    ('HOMERUN 20A AL PANEL — EMT', '3/4"       EMT S.S. D/C CONNECTOR', 2),
    ('HOMERUN 20A AL PANEL — EMT', '3/4"       EMT S.S. D/C COUPLING', 7),
    ('HOMERUN 20A AL PANEL — EMT', '3/4"      EMT STRAP 1 HOLE STRAP', 10),
    ('HOMERUN 20A AL PANEL — EMT', '3/4"       EMT ELBOW', 2),
    ('HOMERUN 20A AL PANEL — EMT', '3/4"       LOCKNUT', 2),
    ('HOMERUN 20A AL PANEL — EMT', '3/4"     GROUNDING BUSHING', 1),
    ('HOMERUN 20A AL PANEL — EMT', 'YELLOW WIRENUTS', 3),
    ('HOMERUN 20A AL PANEL — EMT', '#12     GROUND PIGTAIL', 1),

    -- HOMERUN 20A AL PANEL — MC · 3.46 h · $92.59 de material · El homerun de obra ligera — tienda, oficina, remodelacion en edificio ocupado como Stuart —, donde no se monta tubo y el MC va grapado al techo hasta el panel.
    ('HOMERUN 20A AL PANEL — MC', 'BREAKER 1P 20A', 1),
    ('HOMERUN 20A AL PANEL — MC', 'Panel Termination (per circuit)', 1),
    ('HOMERUN 20A AL PANEL — MC', '12/2   MC', 0.075),
    ('HOMERUN 20A AL PANEL — MC', 'MC SNAP-IN CONNECTOR 3/8"', 2),
    ('HOMERUN 20A AL PANEL — MC', 'MC CONDUIT STRAP', 10),
    ('HOMERUN 20A AL PANEL — MC', '#12     GROUND PIGTAIL', 1),
    ('HOMERUN 20A AL PANEL — MC', 'YELLOW WIRENUTS', 3),

    -- CAJA DE DERIVACION 4-11/16 EN PARED — EMT · 0.60 h · $9.54 de material · La caja de paso que se pone en pared cuando un circuito se reparte o cuando el tramo pasa de 360 grados de curvas. No lleva cable: los pies van en la receta del circuito, por eso pies_editable es false.
    ('CAJA DE DERIVACION 4-11/16 EN PARED — EMT', '4-11/16 BOX', 1),
    ('CAJA DE DERIVACION 4-11/16 EN PARED — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 4),
    ('CAJA DE DERIVACION 4-11/16 EN PARED — EMT', '#12     GROUND PIGTAIL', 1),
    ('CAJA DE DERIVACION 4-11/16 EN PARED — EMT', 'YELLOW WIRENUTS', 6),

    -- CAJA DE DERIVACION 4-11/16 EN TECHO — EMT · 0.65 h · $10.60 de material · La misma caja de paso pero colgada del cielo raso registrable. Es la que sale a docenas en un build-out — el takeoff del DTCC conto 41 JB en techo.
    ('CAJA DE DERIVACION 4-11/16 EN TECHO — EMT', '4-11/16 BOX', 1),
    ('CAJA DE DERIVACION 4-11/16 EN TECHO — EMT', 'T-BAR BOX HANGER', 1),
    ('CAJA DE DERIVACION 4-11/16 EN TECHO — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 4),
    ('CAJA DE DERIVACION 4-11/16 EN TECHO — EMT', '#12     GROUND PIGTAIL', 1),
    ('CAJA DE DERIVACION 4-11/16 EN TECHO — EMT', 'YELLOW WIRENUTS', 6),

    -- CAJA DE DERIVACION 1900 EN TECHO — MC · 0.53 h · $7.40 de material · La caja donde se reparte el MC en un techo registrable — el JB 1900 que el takeoff del DTCC conto 41 veces. Es la que Edgar pone cuando el circuito se abre en dos ramas.
    ('CAJA DE DERIVACION 1900 EN TECHO — MC', 'JB 1900 BOX', 1),
    ('CAJA DE DERIVACION 1900 EN TECHO — MC', '4"X4" BLANK COVER', 1),
    ('CAJA DE DERIVACION 1900 EN TECHO — MC', 'T-BAR BOX HANGER', 1),
    ('CAJA DE DERIVACION 1900 EN TECHO — MC', 'MC SNAP-IN CONNECTOR 3/8"', 3),
    ('CAJA DE DERIVACION 1900 EN TECHO — MC', '#12     GROUND PIGTAIL', 1),
    ('CAJA DE DERIVACION 1900 EN TECHO — MC', 'YELLOW WIRENUTS', 6),

    -- PLASTER RING 1 GANG SUELTO · 0.05 h · $0.36 de material · Linea de ajuste: la caja ya esta puesta y hay que cambiar o anadir el anillo porque el drywall cambio de espesor, o porque el anillo de la receta de punto no sirve. Se anade a mano, por docenas, sin duplicar la caja.
    ('PLASTER RING 1 GANG SUELTO', '1  GANG PLASTER RING 1/2"', 1),

    -- PULL BOX 12X12X12 — EMT 3/4" · 1.65 h · $16.94 de material · La caja de jalado que rompe un tramo largo de EMT cuando ya no se puede halar mas cable. No lleva empalmes ni tapa aparte (la trae puesta): es tubo que entra y cable que pasa.
    ('PULL BOX 12X12X12 — EMT 3/4"', '12"x12"x12" PULL BOX NEMA-1', 1),
    ('PULL BOX 12X12X12 — EMT 3/4"', '3/4"       EMT S.S. D/C CONNECTOR', 4),
    ('PULL BOX 12X12X12 — EMT 3/4"', '3/4"       LOCKNUT', 4),
    ('PULL BOX 12X12X12 — EMT 3/4"', 'NAIL-ING ANCHORS 1/4"', 4),

    -- DEMOLICION — RETIRAR CONDUIT · 5.00 h · $0.00 de material · Retirar tubo existente en una remodelacion en edificio ocupado, como Stuart o UM. Va con pies editables porque la demolicion se mide en el sitio, nunca en el plano.
    ('DEMOLICION — RETIRAR CONDUIT', 'DEMO - Conduit Run (per LF)', 100),

    -- DEMOLICION — RETIRAR CABLEADO · 3.00 h · $0.00 de material · Sacar el cable muerto de los tubos que se quedan. En UM fueron 2.000 ft. Pies editables por la misma razon: se mide jalando.
    ('DEMOLICION — RETIRAR CABLEADO', 'DEMO - Wire Removal (per LF)', 100),

    -- DEMOLICION — RETIRAR DISPOSITIVOS · 0.15 h · $0.00 de material · Cada receptaculo o dispositivo que sale de la pared en la demolicion. Para los apagadores existe el gemelo DEMO - Switches al mismo h/u (0,15): va como item suelto para no crear una receta clon.
    ('DEMOLICION — RETIRAR DISPOSITIVOS', 'DEMO - Receptacles', 1),

    -- DEMOLICION — RETIRAR LUMINARIAS · 0.55 h · $0.00 de material · Bajar las luminarias existentes en un build-out. En Stuart eran 10 y en UM 15, y siempre traen el viaje al contenedor detras.
    ('DEMOLICION — RETIRAR LUMINARIAS', 'DEMO - Light Fixtures', 1),
    ('DEMOLICION — RETIRAR LUMINARIAS', 'DEMO - Garbage/Disposal', 0.25),

    -- DEMOLICION — RETIRAR PANEL · 5.00 h · $0.00 de material · Sacar un panel existente, que en UM fueron 9 y es lo primero que pasa en un upgrade de switchgear. El transformador tiene su gemelo, DEMO - Transformers, con el mismo problema de h/u (6,0 contra los 1,5 de Edgar).
    ('DEMOLICION — RETIRAR PANEL', 'DEMO - Panels', 1),
    ('DEMOLICION — RETIRAR PANEL', 'DEMO - Garbage/Disposal', 1),

    -- EXIT SIGN — MC · 1.70 h · $14.98 de material · El mismo exit sign pero en obra de MC. Stuart fue obra de MC (3.000 ft de 12/2) con 9 exit: alli la version EMT no sirve.
    ('EXIT SIGN — MC', 'EXIT SIGN BACK/TOP MTD', 1),
    ('EXIT SIGN — MC', 'JB 1900 BOX', 1),
    ('EXIT SIGN — MC', 'YELLOW WIRENUTS', 3),
    ('EXIT SIGN — MC', '#12     GROUND PIGTAIL', 1),
    ('EXIT SIGN — MC', 'CEILING RING  1/2"', 1),
    ('EXIT SIGN — MC', '12/2   MC', 0.012),
    ('EXIT SIGN — MC', 'MC SNAP-IN CONNECTOR 3/8"', 3),
    ('EXIT SIGN — MC', 'MC CONDUIT STRAP', 2),

    -- LUZ DE EMERGENCIA BATERÍA — MC · 1.95 h · $159.98 de material · La unidad de emergencia de bateria en obra de MC. Stuart llevaba 7 y era obra de MC.
    ('LUZ DE EMERGENCIA BATERÍA — MC', 'BATTERY LIGHT SURFACE', 1),
    ('LUZ DE EMERGENCIA BATERÍA — MC', 'JB 1900 BOX', 1),
    ('LUZ DE EMERGENCIA BATERÍA — MC', 'YELLOW WIRENUTS', 3),
    ('LUZ DE EMERGENCIA BATERÍA — MC', '#12     GROUND PIGTAIL', 1),
    ('LUZ DE EMERGENCIA BATERÍA — MC', 'CEILING RING  1/2"', 1),
    ('LUZ DE EMERGENCIA BATERÍA — MC', '12/2   MC', 0.012),
    ('LUZ DE EMERGENCIA BATERÍA — MC', 'MC SNAP-IN CONNECTOR 3/8"', 3),
    ('LUZ DE EMERGENCIA BATERÍA — MC', 'MC CONDUIT STRAP', 2),

    -- DOWN LIGHT — EMT · 2.09 h · $19.87 de material · El down light en obra de EMT: hasta ahora solo existia en MC, y la mitad de las obras de Edgar van en tubo.
    ('DOWN LIGHT — EMT', 'JB 1900 BOX', 1),
    ('DOWN LIGHT — EMT', '1/2"     EMT CONDUIT', 8),
    ('DOWN LIGHT — EMT', '1/2"       EMT S.S. D/C CONNECTOR', 2),
    ('DOWN LIGHT — EMT', '1/2"       EMT S.S. D/C COUPLING', 1),
    ('DOWN LIGHT — EMT', '1/2"      EMT STRAP 1 HOLE STRAP', 1),
    ('DOWN LIGHT — EMT', '# 12      THHN STRANDED CU.', 0.042),
    ('DOWN LIGHT — EMT', '3/8"      FLEX. METAL CONDUIT', 6),
    ('DOWN LIGHT — EMT', '3/8"      FLEX. METAL ST. CONNECT.', 2),
    ('DOWN LIGHT — EMT', 'YELLOW WIRENUTS', 3),
    ('DOWN LIGHT — EMT', '#12     GROUND PIGTAIL', 1),
    ('DOWN LIGHT — EMT', 'T-BAR BOX HANGER', 1),
    ('DOWN LIGHT — EMT', 'DOWN LIGHT ', 1)
  ) as v(receta, item, cantidad)
  join ensambles e on e.nombre = v.receta
 where not exists (select 1 from ensamble_items x where x.ensamble_id = e.id and x.item = v.item);

-- ---------------------------------------------------------------
-- 3) Comprobar (esto se corre APARTE, en un segundo pegado)
-- ---------------------------------------------------------------
-- select e.nombre, e.modo, count(ei.id) as componentes,
--        round(sum(ei.cantidad * coalesce(c.horas_unidad,0))::numeric, 2) as horas,
--        round(sum(ei.cantidad * coalesce(c.precio,0))::numeric, 2) as material,
--        count(*) filter (where c.id is null) as huerfanos
--   from ensambles e
--   join ensamble_items ei on ei.ensamble_id = e.id
--   left join catalogo_items c
--          on upper(btrim(regexp_replace(c.item ,'\s+',' ','g')))
--           = upper(btrim(regexp_replace(ei.item,'\s+',' ','g')))
--  group by e.nombre, e.modo, e.orden order by e.modo, e.orden;