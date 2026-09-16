-- =====================================================================
-- E15 · Las herramientas de Bluebeam que no apuntaban a nada
--
-- Al mandar el takeoff de tu E-2.2 salieron 3 renglones «SIN MAPEAR» y no
-- se enviaron. Fui a mirar la lista entera: de las 455 herramientas de tu
-- biblioteca, 127 no tenían destino en el catálogo — 110 de ellas son el
-- «Electrical Tool Set» que Bluebeam trae de fábrica, con los símbolos
-- corrientes: Duplex Outlet, Switch, Exit Light, Junction Box…
--
-- Lo que sale sin mapear NO se envía. No llega en cero: no llega.
--
-- Dos estimadores revisaron las 127 contra tus 1.081 filas. 51 tienen
-- pareja clara; las otras 75 se quedan fuera A PROPÓSITO, casi todas
-- porque el símbolo genérico no dice tamaño («Transformer», «Panel»,
-- «Circuit Breaker») y meterle un default escondería el error. Para esas,
-- la solución está en Bluebeam: duplicar la herramienta por tamaño con el
-- nombre exacto de la fila (BREAKER 1P 20A, BREAKER 2P 30A…).
--
-- Cada nombre de item se comprobó carácter por carácter contra tu
-- catálogo DE HOY, con los cambios de la auditoría ya aplicados.
-- =====================================================================

-- ---------------------------------------------------------------------
-- BLOQUE 1 · LOS DISPOSITIVOS. Corre esto.  (31)
-- ---------------------------------------------------------------------
-- El símbolo ES esa pieza y no hay otra lectura. Aquí está el volumen de
-- cualquier plano: los tomacorrientes, los switches, los exit, los strobes.
insert into alias_takeoff (alias, item, factor, nota) values
  ('1600 A BUS DUCT', '1600A BUS DUCT', 1, 'alta · Mismo ítem (solo cambia el espacio antes de la A, como en los accesorios ''1600 A BUS DUCT ...'' ya mapeados). Herramienta por largo, fila en LF: unidad'),
  ('4000 A BUS DUCT', '4000A BUS DUCT', 1, 'alta · Mismo ítem; largo en LF contra fila en LF.'),
  ('CAT V', 'DATA OUTLET (1 PORT)', 1, 'media · Símbolo de salida Cat 5 (tipo conteo), misma fila a la que ya apunta ''Data Outlet'' del mismo set. Si la herramienta en realidad traza cable, la fila s'),
  ('Ceiling Mounted Light Fixture, Pull Chain', 'INCANDESCENT SURFACE', 1, 'media · Un portalámparas de techo con cadena es una luminaria incandescente de superficie (keyless); es la fila propia de Edgar más cercana ($0 / 1 h).'),
  ('Ceiling Mounted Strobe', 'STROBE LIGHT W/BACKBOX', 1, 'alta · Estrobo solo, con caja; Edgar no separa por montaje. Comparte fila con ''Wall Mounted Strobe'' y con el alias existente del set Fire Alarm.'),
  ('Combination Phone/Data Outlet', 'COMBO PH/DATA', 1, 'alta · Fila propia de Edgar para la salida combinada voz+datos (EA $65 · 0,75 h).'),
  ('Combination Power/Data/Voice Poke-Thru Device', 'POKE-THRU FIRE-RATED', 1, 'media · El poke-thru multiservicio (fuego-resistente, EA $185 · 1,75 h) es el conjunto; la fila 1 GANG POKE-THRU FLOOR BOX ($136,50) es monoservicio. Receptác'),
  ('Combination Strobe/Horn', 'HORN/STROBE LIGHT W/BACKBOX', 1, 'alta · Bocina/estrobo combinado con caja, nombre casi idéntico (el alias existente del set Fire Alarm ''HORN / STROBE LIGHT W/BACKBOX'' apunta a la misma fila)'),
  ('Dimming Switch', 'DIMMER SWITCH 600W', 1, 'alta · Dimmer genérico = el 600W estándar (E $61,77 · 0,3 h), no el 1000W ni los Caseta/Wi-Fi de marca.'),
  ('Duplex Outlet', '20A DUPLEX RECEPTACLE', 1, 'alta · El dúplex genérico del plano es el 20A corriente (E $1,44 · 0,4 h); caja, anillo y tapa van por receta.'),
  ('Duplex Outlet, GFI', '20A GFCI DUPLEX RECEPTACLE', 1, 'alta · GFI = GFCI dúplex 20A (E $16,39 · 0,5 h).'),
  ('Duplex Outlet, WP', '20A GFCI WR (Weather Resistant)', 1, 'media · Un tomacorriente WP (exterior/húmedo) exige GFCI + WR por NEC 210.8/406.9; es la única fila WR del catálogo. La tapa in-use/bell box NO va incluida en'),
  ('Emergency Battery Pack Light Fixture', 'BATTERY LIGHT SURFACE', 1, 'alta · Luminaria de emergencia con batería (bug-eye) = BATTERY LIGHT SURFACE, única fila de emergencia con batería.'),
  ('Exit Light', 'EXIT SIGN BACK/TOP MTD', 1, 'alta · Único letrero de salida del catálogo; la fila cubre montaje pared/techo. Comparte fila con ''Exit Light Wall Mounted'' y ''Exit Light Ceiling Mounted''.'),
  ('Exit Light Ceiling Mounted', 'EXIT SIGN BACK/TOP MTD', 1, 'alta · TOP MTD = montaje a techo; misma fila que ''Exit Light''.'),
  ('Exit Light Wall Mounted', 'EXIT SIGN BACK/TOP MTD', 1, 'alta · BACK MTD = montaje a pared; misma fila que ''Exit Light'' (Edgar no separa por montaje).'),
  ('Ground Rod', '5/8" X 10'' COPPER GROUND ROD', 1, 'media · El símbolo no dice diámetro; 5/8" x 10'' cobre es la varilla estándar en obra comercial de Florida y la diferencia con las otras filas es pequeña ($8,5'),
  ('Heat Detector', 'HEAT DETECTOR W/BASE', 1, 'alta · Detector de calor con base, única fila de detector térmico.'),
  ('Isolated Ground Receptacle', '15A DUPLEX ISOLATED GROUND', 1, 'media · Única fila IG del catálogo (E $33,50 · 0,5 h). Es 15A; en comercial el IG suele ser 20A — Edgar decide si da de alta un 20A IG.'),
  ('LED STRIP', 'LED STRIP', 1, 'alta · Mismo nombre exacto; herramienta por largo y fila en FT, unidades coherentes.'),
  ('Lighting Switch', 'SINGLE POLE SWITCH', 1, 'alta · Interruptor de luz genérico = unipolar (E $2,97 · 0,2 h); misma fila que el alias existente Single Pole Switch.'),
  ('MAIN CONDUCTOR', 'MAIN CONDUCTOR', 1, 'alta · Mismo nombre exacto; es cable de pararrayos, va por largo (fila en LF, herramienta tipo largo).'),
  ('Non-Fused Disconnect Switch', 'MOTOR DISCONNECT (Local)', 1, 'media · El disconnect no fusible del plano es el desconectador local de equipo (A/C, extractor, bomba); fila propia $0 (por cotización) · 1 h. Si el plano da '),
  ('Power Pole', '12 FT  TELE-POWER POLE', 1, 'media · En el set eléctrico de Bluebeam ''Power Pole'' es el poste de oficina techo-a-mueble (tele-power pole); la fila lleva DOBLE espacio entre ''FT'' y ''TELE''.'),
  ('RG6 TV CABLE', 'RG6 TV CABLE', 1, 'alta · Mismo nombre exacto. OJO unidad: ver avisos (fila en MLF, herramienta mide pies).'),
  ('SECUNDARY CONDUCTOR', 'SECONDARY CONDUCTOR', 1, 'alta · Misma pieza con typo en la herramienta (SECUNDARY). Cable por largo. OJO unidad: fila en MLF, ver avisos.'),
  ('Single Plex Receptacle', '20A SINGLE RECEPTACLE', 1, 'alta · Simplex = receptáculo sencillo; la fila 20A es la corriente de Edgar (E $2,85 · 0,4 h).'),
  ('Switch', 'SINGLE POLE SWITCH', 1, 'alta · El símbolo S sin sufijo es el interruptor unipolar; misma fila que Lighting Switch y Single Pole Switch.'),
  ('Telephone Outlet', 'TELEPHONE OUTLET (2 JACKS)', 1, 'alta · Fila propia de Edgar para salida telefónica (E $2,85 · 0,2 h). Partida 13-LV aunque la herramienta venga con 20-MISC.'),
  ('Wall Mounted Strobe', 'STROBE LIGHT W/BACKBOX', 1, 'alta · Misma fila que ''Ceiling Mounted Strobe''; si el plano lo marca WP usar WP STROBE LIGHT W/BACKBOX.'),
  ('Weather Proof Switch', 'SINGLE POLE SWITCH', 1, 'media · El dispositivo es un interruptor sencillo; lo WP es la bell box + tapa WP (2"x 4" BELL BOX-DEVICE COVER), que no vienen en esta fila ni en la receta i')
on conflict do nothing;

-- ---------------------------------------------------------------------
-- BLOQUE 2 · LAS CAJAS. Corre esto también, pero sabiendo una cosa.  (9)
-- ---------------------------------------------------------------------
-- Son símbolos de salida SIN dispositivo: la pieza es la caja. Está bien
-- contarlas. El único riesgo es doble conteo: si en el mismo punto cuentas
-- además la luminaria y usas una receta que YA trae su caja, la caja entra
-- dos veces. En un plano de ingeniero eso no suele pasar, porque el
-- símbolo de caja y el de luminaria son distintos.
insert into alias_takeoff (alias, item, factor, nota) values
  ('Blanked Ceiling Outlet', 'JB 1900 BOX', 1, 'media · Salida ciega de techo: misma lógica y misma fila que la de pared.'),
  ('Blanked Wall Outlet', 'JB 1900 BOX', 1, 'media · Salida ciega = caja + tapa ciega; la pieza es la caja (JB 1900). La tapa 4"X4" BLANK COVER debería venir por receta o Edgar la añade.'),
  ('Ceiling Outlet', 'JB 1900 BOX', 1, 'media · Salida genérica de techo (sin dispositivo) = caja de salida; misma fila que Wall Outlet. Alternativa residencial: CEILING PLASTIC BOX. Riesgo de doble'),
  ('Fan Ceiling Outlet', '4"X 2" X 1 1/2"      FAN  BOX', 1, 'alta · Salida para ventilador de techo = caja de ventilador; fila propia con espacios múltiples (E $5,85 · 0,25 h). El ventilador va aparte (alias Ceiling Fa'),
  ('Fan Wall Outlet', '4"X 2" X 1 1/2"      FAN  BOX', 1, 'media · Misma caja de ventilador que la de techo; en pared es raro (extractor). Misma fila que Fan Ceiling Outlet.'),
  ('Floor Mounted Junction Box', '1 GANG ADJUSTABLE FLOOR BOX', 1, 'media · El símbolo es la caja de piso sin dispositivo; la caja ajustable 1G (E $86 · 0,5 h) es la pieza. Si el plano pide 2G, existe 2 GANG FLOOR BOX.'),
  ('Junction Box Ceiling Outlet', 'JB 1900 BOX', 1, 'alta · Caja de paso en techo: misma fila JB 1900 BOX (dos herramientas → una fila, legítimo).'),
  ('Junction Box Wall Outlet', 'JB 1900 BOX', 1, 'alta · Es literalmente una caja de paso en pared: JB 1900 BOX.'),
  ('Wall Outlet', 'JB 1900 BOX', 1, 'media · Símbolo ANSI de salida genérica en pared (sin dispositivo): la pieza es la caja de salida; JB 1900 (E $1,04 · 0,25 h) es la caja corriente de Edgar. S')
on conflict do nothing;

-- ---------------------------------------------------------------------
-- BLOQUE 3 · ONCE QUE DECIDES TÚ. Descomenta las que aceptes.  (11)
-- ---------------------------------------------------------------------

-- CCTV VIDEO RECORDER  ->  NVR 8-channel   [EA · $385 · 1.5 h]
--   El único grabador del catálogo es el NVR de 8 canales, y es una fila importada.
--   Con más de 8 cámaras se queda corto.
-- insert into alias_takeoff (alias, item, factor, nota) values ('CCTV VIDEO RECORDER', 'NVR 8-channel', 1, 'decidido por Edgar') on conflict do nothing;

-- Combination Light & Fan  ->  BATH EXHAUST FAN   [EA · $95 · 1.5 h]
--   Lo mandaría al extractor de baño con luz.
--   Si tu símbolo es un ventilador de techo con luminaria, no es esa fila.
-- insert into alias_takeoff (alias, item, factor, nota) values ('Combination Light & Fan', 'BATH EXHAUST FAN', 1, 'decidido por Edgar') on conflict do nothing;

-- Floor Combination Power/Data/Voice Outlet  ->  MULTI-SERVICE FLOOR BOX (Power+Data)   [EA · $285 · 2 h]
--   La caja multiservicio de piso ($285) probablemente ya trae los jacks.
--   Mira qué incluye.
-- insert into alias_takeoff (alias, item, factor, nota) values ('Floor Combination Power/Data/Voice Outlet', 'MULTI-SERVICE FLOOR BOX (Power+Data)', 1, 'decidido por Edgar') on conflict do nothing;

-- Floor Mounted Receptacle  ->  20A FLOOR RECEPTACLE   [EA · $145 · 1.5 h]
--   El 20A FLOOR RECEPTACLE cuesta $145 y 1,5 h: parece incluir caja y tapa.
--   Si es así y además cuentas la caja de piso, la pagas dos veces.
-- insert into alias_takeoff (alias, item, factor, nota) values ('Floor Mounted Receptacle', '20A FLOOR RECEPTACLE', 1, 'decidido por Edgar') on conflict do nothing;

-- Floor Outlet  ->  20A FLOOR RECEPTACLE   [EA · $145 · 1.5 h]
--   Lo mismo que el anterior.
-- insert into alias_takeoff (alias, item, factor, nota) values ('Floor Outlet', '20A FLOOR RECEPTACLE', 1, 'decidido por Edgar') on conflict do nothing;

-- Homerun, Panel Board Circuit as noted  ->  Panel Termination (per circuit)   [EA · $25 · 0.5 h]
--   Cada flecha de homerun del plano contaría UNA terminación en el panel.
--   Si tus flechas llevan 2 ó 3 circuitos, el factor tiene que ser 2 ó 3.
-- insert into alias_takeoff (alias, item, factor, nota) values ('Homerun, Panel Board Circuit as noted', 'Panel Termination (per circuit)', 1, 'decidido por Edgar') on conflict do nothing;

-- Key Operated Switch  ->  KEY SWITCH   [E · $0 · 0.6 h]
--   La fila KEY SWITCH está a $0 y vive en 13-LV (control de acceso), no en dispositivos.
--   Puede no ser el switch de llave de una luz.
-- insert into alias_takeoff (alias, item, factor, nota) values ('Key Operated Switch', 'KEY SWITCH', 1, 'decidido por Edgar') on conflict do nothing;

-- Quadplex Outlet  ->  20A DUPLEX RECEPTACLE   [E · $1.44 · 0.4 h]
--   Un quad son 2 dúplex (factor 2).
--   Confírmalo: si tú pones 1 GFCI + 1 dúplex en el quad, el factor no vale.
-- insert into alias_takeoff (alias, item, factor, nota) values ('Quadplex Outlet', '20A DUPLEX RECEPTACLE', 2, 'decidido por Edgar') on conflict do nothing;

-- Quadplex Outlet, GFI  ->  20A GFCI DUPLEX RECEPTACLE   [E · $16.39 · 0.5 h]
--   Igual: 2 GFCI en la misma caja de 2 gang.
-- insert into alias_takeoff (alias, item, factor, nota) values ('Quadplex Outlet, GFI', '20A GFCI DUPLEX RECEPTACLE', 2, 'decidido por Edgar') on conflict do nothing;

-- Quadplex Outlet, WP  ->  20A GFCI WR (Weather Resistant)   [EA · $35 · 0.5 h]
--   Igual, exterior.
--   Ojo: la bell box y la tapa in-use van aparte.
-- insert into alias_takeoff (alias, item, factor, nota) values ('Quadplex Outlet, WP', '20A GFCI WR (Weather Resistant)', 2, 'decidido por Edgar') on conflict do nothing;

-- Recessed Light Fixture  ->  DOWN LIGHT   [E · $55 · 0.75 h]
--   Apunta al DOWN LIGHT de $55.
--   Si en tus obras la luminaria la pone el dueño, cámbialo a DOWN LIGHT - INSTALL ONLY.
-- insert into alias_takeoff (alias, item, factor, nota) values ('Recessed Light Fixture', 'DOWN LIGHT', 1, 'decidido por Edgar') on conflict do nothing;

-- ---------------------------------------------------------------------
-- COMPROBAR
-- ---------------------------------------------------------------------
-- 1. Ningún alias apunta a una fila que no existe (tiene que dar 0 filas):
-- select a.alias, a.item from alias_takeoff a left join catalogo_items c
--        on upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = upper(btrim(regexp_replace(a.item,'\s+',' ','g')))
--  where c.id is null;
-- 2. Cuántos alias hay ahora:
-- select count(*) from alias_takeoff;

-- ---------------------------------------------------------------------
-- LAS 75 QUE SE QUEDAN FUERA, Y POR QUE
-- ---------------------------------------------------------------------
-- No es pereza: es que el simbolo generico no dice tamaño. «Transformer»,
-- «Panel», «Circuit Breaker», «Fused Disconnect Switch» — tu catalogo los
-- tiene por kVA, por amperaje y por SIZE, y meterle un default escondería
-- el error en vez de enseñarlo. La solucion es en Bluebeam: duplica la
-- herramienta por tamaño y ponle de nombre la fila exacta («BREAKER 1P 20A»,
-- «BREAKER 2P 30A», «100A/3P MAIN C / BREAKER»). Asi casa por nombre sola,
-- sin alias.
--
-- De esas 75, 41 apuntan a una pieza que NO EXISTE en tu catalogo:
--   10/100 DATA HUB                              NETWORK SWITCH (non-PoE, 24-port) · EA · $180 · 0,75 h
--   Adjustable Remote Head Powered by Emergency  EMERGENCY REMOTE HEAD (single/double) · EA · $38 · 0,5 h
--   CCTV PAN / TILT                              CCTV PAN/TILT UNIT · E · $0 (cotización) · 1,5 h
--   CCTV SELECTOR SWITCH                         CCTV SELECTOR SWITCH — 13-LV · E · $0 (cotización) · 1,0 h
--   Clock Ceiling Outlet                         CLOCK HANGER RECEPTACLE — misma fila que la de pared
--   Clock Wall Outlet                            CLOCK HANGER RECEPTACLE — 10-DEV · E · ~$12 · 0,4 h
--   Control Power Transformer                    CONTROL POWER TRANSFORMER (≤1 kVA) · E · $185 · 1,5 h
--   Control Transformer                          CONTROL POWER TRANSFORMER (≤1 kVA) · E · $185 · 1,5 h (solo si se instala suelto)
--   Doorbell Pushbutton                          DOORBELL PUSHBUTTON — 13-LV · E · ~$8 · 0,25 h (y chime + transformador 16V aparte)
--   Drop Cord Ceiling Outlet                     DROP CORD OUTLET — misma fila que la de pared
--   Drop Cord Wall Outlet                        DROP CORD OUTLET (caja + 10' cordón SO + conector) — 10-DEV · E · ~$45 · 1,0 h
--   Electrolier Switch                           ELECTROLIER (2-CIRCUIT) SWITCH — 10-DEV · E · ~$15 · 0,3 h
--   Floor Mounted Data Outlet                    FLOOR DATA OUTLET (1 PORT) (caja de piso 1G + tapa latón + jack Cat6) — 13-LV · EA · ~$160 · 1,25 h
--   Floor Mounted Phone Outlet                   FLOOR TELEPHONE OUTLET (caja de piso 1G + tapa latón + jack) — 13-LV · EA · ~$125 · 1,0 h
--   Ground Rod Test Well                         GROUND ROD TEST WELL · EA · $85 · 1 h
--   Horn                                         HORN W/BACKBOX · E · $48 · 0,5 h
--   Indicating Lamp                              PILOT LIGHT / INDICATING LAMP 22mm · E · $18 · 0,25 h
--   Indicating Lamp-Blue                         PILOT LIGHT / INDICATING LAMP 22mm · E · $18 · 0,25 h
--   Indicating Lamp-Green                        PILOT LIGHT / INDICATING LAMP 22mm · E · $18 · 0,25 h
--   Indicating Lamp-PTT                          PILOT LIGHT / INDICATING LAMP 22mm · E · $18 · 0,25 h (solo si Edgar instala luces piloto sueltas)
--   Indicating Lamp-Red                          PILOT LIGHT / INDICATING LAMP 22mm · E · $18 · 0,25 h
--   Indicating Lamp-White                        PILOT LIGHT / INDICATING LAMP 22mm · E · $18 · 0,25 h
--   Lamp Holder Ceiling Outlet                   KEYLESS LAMPHOLDER — misma fila que la de pared
--   Lamp Holder Wall Outlet                      KEYLESS LAMPHOLDER (porcelana) — 11-LIGHT · E · ~$4 · 0,3 h
--   Lamp Holder with Pull Switch, Ceiling Outlet PULL-CHAIN LAMPHOLDER — misma fila que la de pared
--   Lamp Holder with Pull Switch, Wall Outlet    PULL-CHAIN LAMPHOLDER — 11-LIGHT · E · ~$6 · 0,3 h
--   Manual Motor Starter                         MANUAL MOTOR STARTER W/OL · E · $65 · 0,75 h
--   Momentary Contact Switch                     MOMENTARY CONTACT SWITCH — 10-DEV · E · ~$18 · 0,3 h
--   Power Vent Fan                               POWER VENT FAN (roof/attic) · EA · $0 (por otros) · 1 h
--   Pull Switch Ceiling Outlet                   PULL CHAIN SWITCH — misma fila que la de pared
--   Pull Switch Wall Outlet                      PULL CHAIN SWITCH — 10-DEV · E · ~$8 · 0,3 h
--   RG -11 TV CABLE                              RG-11 TV CABLE · MLF · $380 · 10 h
--   RG -11 TV CABLE WET LOCATION                 RG-11 TV CABLE WET LOC. · MLF · $450 · 11 h
--   Remote Control Switch                        LOW VOLTAGE REMOTE CONTROL SWITCH — 10-DEV · E · ~$20 · 0,4 h
--   Switch and Convenience Outlet                COMBO SWITCH/RECEPTACLE 15A — 10-DEV · E · ~$12 · 0,45 h
--   Switch and Pilot Lamp                        SINGLE POLE SWITCH W/ PILOT LIGHT — 10-DEV · E · ~$14 · 0,3 h
--   TV HEAD-END                                  TV HEAD-END EQUIPMENT · E · $0 (cotización) · 8 h
--   TV TOWER                                     TV TOWER / MAST · E · $0 (cotización) · 8 h
--   Vapor Discharge Switch Ceiling Outlet        HID/VAPOR DISCHARGE LAMP OUTLET — misma fila que la de pared
--   Vapor Discharge Switch Wall Outlet           HID/VAPOR DISCHARGE LAMP OUTLET — 11-LIGHT · E · $0 (cotización) · 1,0 h
