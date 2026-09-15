-- =====================================================================
-- E9g · Lo que encontró la auditoría del catálogo (16/09)
--
-- 1.084 filas revisadas por 17 auditores, cada hallazgo atacado por un
-- escéptico, y el conjunto pasado por tres lentes (dinero, coherencia y
-- riesgo). Aquí solo está lo que sobrevivió. Los nombres se comprobaron
-- carácter por carácter contra tu export: cada UPDATE encuentra su fila.
--
-- TRES BLOQUES. No corras el archivo entero de una.
--   A · antes de usar las recetas nuevas: unidades rotas, duplicados que
--       el motor resuelve al azar, horas copiadas de otra fila, precios de
--       tus propias facturas. Confianza alta.
--   B · cuando lo mires: errores claros pero de menos dinero, o números
--       derivados de la escalera de la familia (dicen «provisional»).
--   C · solo mirar: dependen de un dato que solo tú tienes (albarán,
--       cotización) o los verificadores no se pusieron de acuerdo.
--
-- Cada UPDATE lleva el valor ACTUAL como condición: si tú ya lo cambiaste
-- a mano, la sentencia no hace nada. Nunca pisa lo tuyo.
--
-- LA REGLA QUE MANDA: tus números del Excel «Standart Estimating» son la verdad.
-- Las filas importadas el 14/09 (el bloque en minúsculas: CATV, RJ45, Cat6 cable,
-- EV chargers) son las sospechosas. Donde un hallazgo quería pisar un número TUYO
-- con uno derivado, se quitó de A: va en C como pregunta, o se restauró el tuyo.
--
-- LO QUE NO ESTÁ AQUÍ, a propósito: los $0 de equipo grande (trafos, main
-- breakers, disconnects, distribution panels, ATS, UPS, bus duct). Esa es tu
-- regla de la casa —«va por cotización»— y el estimador ya lo avisa. Un $0
-- grita; un número de internet se queda callado y lo firmas.
-- =====================================================================

-- Antes de nada: una foto del catálogo, por si hay que volver atrás.
create table if not exists catalogo_items_respaldo_20260916 as select * from catalogo_items;

-- ---------------------------------------------------------------------
-- BLOQUE 0 · YA CORRIDO el 16/09 (queda aquí de registro; si lo vuelves a correr no pasa nada)
-- ---------------------------------------------------------------------
-- alter table estimados add column if not exists notas text;
-- delete from catalogo_items where upper(btrim(regexp_replace(item,'\\s+',' ','g'))) = '1G PLASTIC COVER RECEPTACLE' and coalesce(precio,0) < 0.30;
-- update catalogo_items set item = 'DOWN LIGHT - INSTALL ONLY' where coalesce(precio,0) = 0 and btrim(item) = 'DOWN LIGHT';
-- update alias_takeoff set item = 'LIGHTING RELAY' where item = 'LIGHTING  RELAY';  delete from catalogo_items where item = 'LIGHTING  RELAY';
-- update alias_takeoff set item = '10A FUSES' where item = '10A  FUSES';  delete from catalogo_items where item = '10A  FUSES';

-- ---------------------------------------------------------------------
-- BLOQUE 0b · LO QUE LE FALTÓ AL BLOQUE 0 (lo vieron los verificadores)
-- ---------------------------------------------------------------------
-- (a) Copia de los estimados. Los verificadores comprobaron una cosa que yo te
--     había dicho al revés: un estimado CONGELADO no guarda copia de sus líneas.
--     El número que congelaste (bid_final) sí se queda fijo, pero el detalle se
--     recalcula con el catálogo de hoy cada vez que lo abres. O sea: el bloque A
--     mueve el detalle de TODOS tus estimados, viejos y nuevos. El total que
--     firmaste no cambia; lo que hay debajo, sí. Por eso la copia.
create table if not exists estimados_respaldo_20260916 as select * from estimados;
create table if not exists estimado_items_respaldo_20260916 as select * from estimado_items;

-- (b) El DOWN LIGHT del plano. Al renombrar la fila de $0 (que ERA LA TUYA: en
--     tu Excel DOWN LIGHT es $0 / 0,8 h, la luminaria la pone el dueño, como en
--     Stuart y UM), el alias 'DOWN LIGHT' de Bluebeam se quedó apuntando a un
--     nombre que ya no existe y cae en la fila importada de $55 / 0,75 h. Desde
--     hoy cada down light contado en el plano entra a $55. Si quieres seguir
--     como siempre ($0, la pone el dueño), corre esto:
update alias_takeoff set item = 'DOWN LIGHT - INSTALL ONLY' where btrim(item) = 'DOWN LIGHT';
--     Si prefieres que el plano cobre la luminaria a $55, en vez de eso:
--     update alias_takeoff set item = 'DOWN LIGHT' where btrim(item) = 'DOWN LIGHT';
--     (Las dos recetas DOWN LIGHT — MC / EMT usan la de $55; si va a $0, dímelo y las cambio.)

-- (c) Higiene de la tabla de alias: la unidad que dice el alias tiene que ser la
--     del catálogo. No mueve dinero (la ruta lee alias, item y factor), pero es
--     lo que se exporta después y confunde.
update alias_takeoff set unidad = 'MLF' where item = '14/4 FPL WET LOC. AQ-246' and unidad = 'EA';
update alias_takeoff set unidad = 'E'   where item = '2" CABLE TO STRUT SUPPORT' and unidad = 'FT';

-- Comprobar duplicados: tiene que salir 0 filas.
-- select upper(btrim(regexp_replace(item,'\\s+',' ','g'))) n, count(*) from catalogo_items group by 1 having count(*) > 1;

-- ---------------------------------------------------------------------
-- BLOQUE A · CORRER ANTES DE USAR LAS RECETAS NUEVAS (primera tanda)  (31)
-- ---------------------------------------------------------------------

-- 6" GRS CONDUIT   [hoy: LF · $0 · 0.09 h]
--   Las horas están arrastradas del PVC de 6" (0,09): la escalera GRS va 4"=0,15 y 5"=0,20, así que el 6" sigue con +0,05.
--   El precio $0 se queda: es la regla de la casa (GRS va por cotización) y el E0 ya lo marca falta_precio.
update catalogo_items set horas_unidad = 0.25
   where item = '6" GRS CONDUIT' and coalesce(horas_unidad,0) = 0.09;

-- 1/2"       LOCKNUT   [hoy: E · $0.053 · 0.05 h]
--   Único peldaño al revés de la escalera de locknuts (el de 3/4" pide 0,02 y este 0,05).
--   Se pone el valor real del de 3/4", que es la misma pieza a 2 céntimos de diferencia.
--   Vive en una receta.
--   AFECTA: recetas (1): PANEL BOOSTER 24VDC — EMT
update catalogo_items set horas_unidad = 0.02
   where item = '1/2"       LOCKNUT' and coalesce(horas_unidad,0) = 0.05;

-- 1 1/2"  LIQUIDTIGHT CONDUIT   [hoy: LF · $2.205 · 0.1 h]
--   Horas por pie rotas: restaura el 1,3× sobre el flex metálico que la familia respeta hasta 1-1/4" (flex 1-1/2" = 0,05).
--   La lente de riesgo la da por segura para correr hoy (sin receta ni alias).
update catalogo_items set horas_unidad = 0.065
   where item = '1 1/2"  LIQUIDTIGHT CONDUIT' and coalesce(horas_unidad,0) = 0.1;

-- 2"        LIQUIDTIGHT CONDUIT   [hoy: LF · $2.499 · 0.25 h]
--   Horas por pie rotas: el 0,25 es exactamente la hora del CONECTOR de flex de 2" (por pieza) pegada en la fila del tubo (por pie); flex 2" = 0,06/ft.
--   La lente de riesgo la da por segura para correr hoy (sin receta ni alias).
update catalogo_items set horas_unidad = 0.08
   where item = '2"        LIQUIDTIGHT CONDUIT' and coalesce(horas_unidad,0) = 0.25;

-- 2 1/2"  LIQUIDTIGHT CONDUIT   [hoy: LF · $4.74 · 0.3 h]
--   Horas por pie rotas: el 0,30 es la hora del CONECTOR de flex de 2-1/2" copiada en el tubo; flex 2-1/2" = 0,08/ft.
--   La lente de riesgo la da por segura para correr hoy (sin receta ni alias).
update catalogo_items set horas_unidad = 0.1
   where item = '2 1/2"  LIQUIDTIGHT CONDUIT' and coalesce(horas_unidad,0) = 0.3;

-- 3"        LIQUIDTIGHT CONDUIT   [hoy: LF · $6.07 · 0.35 h]
--   Horas por pie rotas: el 0,35 es la hora del CONECTOR de flex de 3" copiada en el tubo; flex 3" = 0,10/ft.
--   La lente de riesgo la da por segura para correr hoy (sin receta ni alias).
update catalogo_items set horas_unidad = 0.13
   where item = '3"        LIQUIDTIGHT CONDUIT' and coalesce(horas_unidad,0) = 0.35;

-- 3 1/2"  LIQUIDTIGHT CONDUIT   [hoy: LF · $9.14 · 0.5 h]
--   Horas por pie rotas: 0,5 h por pie es más que instalar un pie de cualquier cosa del catálogo; 0,16 continúa la curva 0,065 / 0,08 / 0,10 / 0,13.
--   La lente de riesgo la da por segura para correr hoy (sin receta ni alias).
update catalogo_items set horas_unidad = 0.16
   where item = '3 1/2"  LIQUIDTIGHT CONDUIT' and coalesce(horas_unidad,0) = 0.5;

-- 4"x 4"    BELL BOX-BOX AND DEVICE COVER   [hoy: E · $0 · 0.15 h]
--   Fila combo (caja + tapa de dispositivo, dos piezas de fundición) a $0.
--   Precio = suma exacta de sus dos piezas del catálogo: $10,66 + $16,79.
--   Las horas (0,15) no se tocan hasta que Edgar dé su número para la pareja de 4x4.
--   AFECTA: alias línea 12 '4"x 4" BELL BOX-BOX AND DEVICE COVER' (factor 1, unidad E)
update catalogo_items set precio = 27.45
   where item = '4"x 4"    BELL BOX-BOX AND DEVICE COVER' and coalesce(precio,0) = 0;

-- 2"x 4"    BELL BOX-BOX AND DEVICE COVER   [hoy: E · $0 · 0.2 h]
--   Combo a $0 cuando sus piezas suman $7,088 + $6,51 = $13,598, y ese precio exacto está en la obra de Stuart (GUIA-3-PROYECTOS línea 125).
--   Las 0,2 h coinciden con el número a mano de Edgar y no se tocan.
--   AFECTA: alias línea 8 '2"x 4" BELL BOX-BOX AND DEVICE COVER' (factor 1, unidad E)
update catalogo_items set precio = 13.598
   where item = '2"x 4"    BELL BOX-BOX AND DEVICE COVER' and coalesce(precio,0) = 0;

-- 6"x6"x10' WIREWAY NEMA-3R   [hoy: E · $110.25 · 1 h]
--   Typo de una celda: NEMA-1 y NEMA-3R llevan horas idénticas en las cinco medidas (1,2 / 1,4 / 1,8 / 2,0 / 2,5) salvo esta, que perdió el 4.
--   Un 3R de 6" no puede ir más rápido que el de 4" ni que su gemelo de interior.
--   Tiene alias.
--   AFECTA: alias línea 43 '6" X 6" X 10' WIREWAY.NEMA-3R' (factor 1, unidad E)
update catalogo_items set horas_unidad = 1.4
   where item = '6"x6"x10'' WIREWAY NEMA-3R' and coalesce(horas_unidad,0) = 1;

-- G 4000  WIREMOLD COVER   [hoy: E · $1.932 · 0.03 h]
--   La tapa del G4000 es lineal como su base (que está en LF): el precio $1,932 y las 0,03 h ya están por pie (58% de la base, proporción normal).
--   Solo está mal la etiqueta E, que deja la tapa fuera del takeoff medido.
--   Sin alias ni receta.
update catalogo_items set unidad = 'LF'
   where item = 'G 4000  WIREMOLD COVER' and unidad = 'E';

-- G 4000  WIREMOLD DIVIDER   [hoy: E · $0.84 · 0.01 h]
--   Mismo caso que la tapa: el separador va la misma longitud que la base y su precio ($0,84) es por pie.
--   Pasa a LF con la base y la tapa.
--   Sin alias ni receta.
update catalogo_items set unidad = 'LF'
   where item = 'G 4000  WIREMOLD DIVIDER' and unidad = 'E';

-- START/STOP PUSH BUTTON   [hoy: EA · $0 · 0.5 h]
--   El Excel original de Edgar traía 'PUSH BUTTON Start/Stop' a 2 h; al recargar se renombró y quedó a 0,5 h (solo colgar la caja).
--   Se recupera el número propio de Edgar.
--   El precio $0 no se toca aquí.
--   Tiene alias.
--   AFECTA: alias línea 173 'PUSH BUTTON Start/Stop' (factor 1, unidad EA)
update catalogo_items set horas_unidad = 2
   where item = 'START/STOP PUSH BUTTON' and coalesce(horas_unidad,0) = 0.5;

-- # 500   MCM THW CU.   [hoy: MLF · $9222.05 · 36 h]
--   TU COTIZACIÓN UM (oct-2025).
--   Hay otra propuesta del 15/09 a precio de mercado ($18.080 el 500 y $21.700 el 600): elige una; cuando Mike conteste, su número manda.
--   A $9.222/MLF el 500 MCM sale más barato que el 300 y apenas más que el 250: 18,4 $/MCM contra la meseta de 36 de toda la familia.
--   El precio bueno es el que Edgar pagó en UM ($15.804,70, GUIA-3-PROYECTOS).
--   Horas no cambian.
update catalogo_items set precio = 15804.7
   where item = '# 500   MCM THW CU.' and coalesce(precio,0) = 9222.05;

-- # 600   MCM THW CU.   [hoy: MLF · $11839.44 · 38 h]
--   TU COTIZACIÓN UM (oct-2025).
--   Hay otra propuesta del 15/09 a precio de mercado ($18.080 el 500 y $21.700 el 600): elige una; cuando Mike conteste, su número manda.
--   Mismo corte que el 500: a $11.839 el 600 MCM queda por debajo del 350.
--   Precio de UM: $19.957,70 (33 $/MCM, dentro de banda).
--   Horas no cambian.
update catalogo_items set precio = 19957.7
   where item = '# 600   MCM THW CU.' and coalesce(precio,0) = 11839.44;

-- 14/4 FPL WET LOC. AQ-246   [hoy: EA · $225 · 8 h]
--   TU EXCEL: MLF.
--   Con Planos ≥ v32.W la ruta de alias ya divide pies entre mil cuando el factor es 1, así que este UPDATE basta; el alias se deja con factor 1.
--   (Tu Excel decía $375/MLF; el catálogo tiene $225: pregunta aparte.).
--   AFECTA: alias línea 242 (factor 1). Después: update alias_takeoff set unidad = MLF (higiene).
update catalogo_items set unidad = 'MLF'
   where item = '14/4 FPL WET LOC. AQ-246' and unidad = 'EA';

-- STROBE LIGHT W/BACKBOX   [hoy: E · $59 · 0.5 h]
--   Edgar pagó $99,99 la unidad en Stuart (8 unidades, GUIA-3-PROYECTOS línea 167) y el catálogo dice $59: precio de hace años.
--   Está en dos recetas y en el toolchest.
--   Aviso: la WP STROBE ($74) queda por debajo de la normal; revisarla.
--   AFECTA: recetas (2): SPEAKER/STROBE F/A (EVAC DE VOZ); STROBE F/A | alias línea 216 'STROBE LIGHT W/BACKBOX' (factor 1, unidad E)
update catalogo_items set precio = 99.99
   where item = 'STROBE LIGHT W/BACKBOX' and coalesce(precio,0) = 59;

-- HORN/STROBE LIGHT W/BACKBOX   [hoy: E · $88 · 0.5 h]
--   Edgar pagó $137,99 en Stuart y el catálogo dice $88.
--   Mismo nombre exacto, mismas horas, precio viejo.
--   En receta y toolchest.
--   Aviso: la WP HORN/STROBE ($102) queda por debajo de la normal; Edgar debe revisar su precio.
--   AFECTA: recetas (1): HORN/STROBE F/A | alias línea 218 'HORN / STROBE LIGHT W/BACKBOX' (factor 1, unidad E)
update catalogo_items set precio = 137.99
   where item = 'HORN/STROBE LIGHT W/BACKBOX' and coalesce(precio,0) = 88;

-- WP DEVICES COVERS   [hoy: E · $65 · 0.008 h]
--   0,008 h son 29 segundos por tapa: decimal corrido.
--   0,08 es lo que Edgar cobra a mano por una tapa y ninguna tapa del catálogo baja de 0,03.
--   La lente de riesgo la da por segura para hoy.
--   AFECTA: alias línea 210 'WP DEVICES COVERS' (factor 1, unidad E)
update catalogo_items set horas_unidad = 0.08
   where item = 'WP DEVICES COVERS' and coalesce(horas_unidad,0) = 0.008;

-- DEVICES COVERS   [hoy: E · $40 · 0.008 h]
--   Misma tapa sin WP, mismo 0,008 arrastrado.
--   A 0,08 con su gemela.
--   Tiene alias.
--   AFECTA: alias línea 211 'DEVICES COVERS' (factor 1, unidad E)
update catalogo_items set horas_unidad = 0.08
   where item = 'DEVICES COVERS' and coalesce(horas_unidad,0) = 0.008;

-- THREE POLE SWITCH   [hoy: E · $20 · 1.3 h]
--   1,3 h por un switch es el doble del punto completo de receptáculo.
--   Patrón: 1,30 = 0,30 + 1,00, igual que el FOUR WAY (1,25 = 0,25 + 1,00), pegados en orden.
--   Restando el +1,00 queda 0,30, clavado el DOUBLE POLE SWITCH.
--   Tiene alias.
--   AFECTA: alias línea 62 'THREE POLE SWITCH' (factor 1, unidad E)
update catalogo_items set horas_unidad = 0.3
   where item = 'THREE POLE SWITCH' and coalesce(horas_unidad,0) = 1.3;

-- FOUR WAY SWITCH   [hoy: E · $3.25 · 1.25 h]
--   Va con el THREE POLE: mismo +1,00 h de contaminación (1,25 = 0,25 + 1,00).
--   Restándolo queda 0,25, igual que el THREE WAY SWITCH.
--   Está en dos recetas (la de cuatro vías EMT ya avisa de que caerá a ~1,95 h) y en dos alias.
--   AFECTA: recetas (2): SWITCH CUATRO VÍAS — EMT; SWITCH CUATRO VÍAS — ROMEX | alias línea 64 'FOUR WAY SWITCH' (factor 1, unidad E) | alias línea 307 'Four Way Switch' (factor 1, unidad E)
update catalogo_items set horas_unidad = 0.25
   where item = 'FOUR WAY SWITCH' and coalesce(horas_unidad,0) = 1.25;

-- 15A DUPLEX TAMPER RESISTANT   [hoy: E · $2.5 · 0.5 h]
--   Un TR se instala igual que el dúplex normal (0,3 h): mismos tornillos, mismos hilos, el obturador va dentro.
--   Hasta el TR con Wi-Fi del catálogo está a 0,4.
--   Es el estándar residencial y entra por decenas; está en receta y toolchest.
--   AFECTA: recetas (1): RECEPTÁCULO 15A TAMPER RESISTANT — ROMEX | alias línea 57 '15A DUPLEX TAMPER PROOF RECEPT' (factor 1, unidad E)
update catalogo_items set horas_unidad = 0.3
   where item = '15A DUPLEX TAMPER RESISTANT' and coalesce(horas_unidad,0) = 0.5;

-- 20A SINGLE RECEPTACLE USB   [hoy: E · $16.39 · 0.3 h]
--   Horas: 0,5 como el resto de USB.
--   El precio ($16,39, copiado del GFCI) va al bloque B como provisional: hay que cotizar el single con el proveedor.
--   Lleva clavado el $16,39 del GFCI dúplex (copia hecha dos veces; la del dúplex USB ya se arregló) y es el único USB a 0,3 h cuando los otros tres van a 0,5.
--   Las horas son firmes.
--   El $42 es TOPE PROVISIONAL (es el precio del dúplex Leviton): marcarlo con fecha y cotizar el single con el proveedor.
--   Tiene alias.
--   AFECTA: alias línea 54 '20A SINGLE RECEPTACLE USB' (factor 1, unidad E)
update catalogo_items set horas_unidad = 0.5
   where item = '20A SINGLE RECEPTACLE USB' and coalesce(horas_unidad,0) = 0.3;

-- 3" CONDUIT GROUNDING CLAMP   [hoy: EA · $24 · 0.4 h]
--   TU EXCEL: E · $32,06 · 0,6 h; al cargar quedó EA · $24 · 0,4.
--   Se restaura lo tuyo, no una extrapolación.
--   La curva de horas sube 3/4" 0,35 → 1-1/2" 0,45 y se da la vuelta en 3" (0,4).
--   El precio sí escala bien, solo fallan las horas.
--   0,55 conservador y coherente con el escalón interno.
--   Tiene alias.
--   AFECTA: alias línea 295 '3" CONDUIT GROUNDING CLAMP' (factor 1, unidad EA)
update catalogo_items set precio = 32.06, horas_unidad = 0.6
   where item = '3" CONDUIT GROUNDING CLAMP' and coalesce(precio,0) = 24 and coalesce(horas_unidad,0) = 0.4;

-- RG6 TV CABLE   [hoy: MLF · $0.15 · 0.15 h]
--   Etiqueta MLF con precio y horas por pie ($0,15 / 0,15 h): las únicas dos MLF sub-dólar del catálogo son esta y CAT6.
--   La unidad NO se toca (la receta de TV ya le pasa 0,075 MLF = 75 ft): se multiplican precio y horas por mil y las horas van a las 8 h/MLF de todos los cables de baja tensión.
--   AFECTA: recetas (1): SALIDA DE TV / COAX — EMT
update catalogo_items set precio = 150, horas_unidad = 8
   where item = 'RG6 TV CABLE' and coalesce(precio,0) = 0.15 and coalesce(horas_unidad,0) = 0.15;

-- CAT6 CABLE   [hoy: MLF · $0.18 · 0.02 h]
--   TU EXCEL: CAT6 CABLE · FT · $0,45 · 0,025 h/ft = $450 y 25 h por MLF.
--   Eso es lo que se pone (la unidad MLF no se toca: las 8 recetas ya le pasan millares).
--   Alternativa de mercado si prefieres: $180 y 20 h.
--   MLF con precio y horas por pie ($0,18 / 0,02): una corrida medida entra a la milésima parte.
--   La unidad NO se cambia a FT: las 8 recetas ya le pasan millares (0,09 / 0,18 / 0,15 MLF) y con FT pasarían a ser una pulgada de cable.
--   Se ponen $180 y 12 h por MLF con la unidad como está.
--   AFECTA: recetas (8): CÁMARA IP (PoE) EN TECHO — EMT; PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — EMT; PUNTO DE ACCESO INALÁMBRICO (WAP) EN TECHO — MC; SALIDA DE DATOS CAT6 1 PUERTO — EMT; SALIDA DE DATOS CAT6 1 PUERTO — MC; SALIDA DE DATOS CAT6 2 PUERTOS — EMT; SALIDA DE DATOS CAT6 2 PUERTOS — MC; SALIDA DE TELÉFONO — EMT
update catalogo_items set precio = 450, horas_unidad = 25
   where item = 'CAT6 CABLE' and coalesce(precio,0) = 0.18 and coalesce(horas_unidad,0) = 0.02;

-- CAT6A CABLE   [hoy: FT · $0.85 · 0.05 h]
--   0,05 h/ft son 50 h por mil pies, casi el doble del MC armado.
--   0,02 h/ft (20 h/MLF) queda por encima del CAT6 (12 h/MLF), que es más fino.
--   Precio $0,85/ft es de mercado y no se toca.
--   Se queda en FT: el alias 'CAT5E CABLE' (línea 270) entra por aquí con factor 1 y unidad FT, y un cambio a MLF obligaría a tocar ese factor.
--   AFECTA: alias línea 270 'CAT5E CABLE' (factor 1, unidad FT)
update catalogo_items set horas_unidad = 0.02
   where item = 'CAT6A CABLE' and coalesce(horas_unidad,0) = 0.05;

-- 2" CABLE TO STRUT SUPPORT   [hoy: FT · $4.5 · 0.25 h]
--   TU EXCEL: E · 0,2 h.
--   Se restaura tu hora, no 0,15.
--   Abrazadera (el strut por pie ya existe como UNISTRUT en RACEWAY) etiquetada FT cuando sus dos hermanas (ROD, BEAM) son E; y 0,25 h es 67% más que la de viga por la misma operación.
--   A E y 0,15 h.
--   Los dos alias tienen factor 1 (conteo), así que no hay explosión de 100×, pero hay que actualizar la columna unidad del CSV.
--   AFECTA: alias línea 262 '2" CABLE TO STRUT SUPPORT' (factor 1, unidad FT) | alias línea 275 '2" CABLE TO STRUT SUPPORT' (factor 1, unidad FT) | poner unidad E en las líneas 262 y 275 del CSV (factor 1 se queda)
update catalogo_items set unidad = 'E', horas_unidad = 0.2
   where item = '2" CABLE TO STRUT SUPPORT' and unidad = 'FT' and coalesce(horas_unidad,0) = 0.25;

-- DEMO - Wire Removal (per LF)   [hoy: LF · $0 · 0.03 h]
--   Arrancar cable a 0,03 h/ft son 30 h/MLF, cinco veces lo que cuesta instalarlo.
--   Edgar facturó REMOVE WIRING a 4 h/MLF en Stuart y en UM (3.000 ft): 0,004 h/ft.
--   Está en la receta de demolición.
--   AFECTA: recetas (1): DEMOLICION — RETIRAR CABLEADO
update catalogo_items set horas_unidad = 0.004
   where item = 'DEMO - Wire Removal (per LF)' and coalesce(horas_unidad,0) = 0.03;

-- DEMO - Conduit Run (per LF)   [hoy: LF · $0 · 0.05 h]
--   Demoler tubo a 0,05 h/ft cuesta más que instalar EMT de 1-1/4" nuevo.
--   Edgar facturó REMOVE CONDUIT a 2 h/CLF en Stuart y UM (2.500 ft): 0,02 h/ft.
--   En receta y en dos alias (Conduits EMT / PVC).
--   AFECTA: recetas (1): DEMOLICION — RETIRAR CONDUIT | alias línea 301 'Conduits EMT' (factor 1, unidad LF) | alias línea 302 'Conduits PVC' (factor 1, unidad LF)
update catalogo_items set horas_unidad = 0.02
   where item = 'DEMO - Conduit Run (per LF)' and coalesce(horas_unidad,0) = 0.05;

-- ---------------------------------------------------------------------
-- BLOQUE A2 · DOS MÁS, DE LA SEGUNDA TANDA (si ya corriste el A, corre solo esto)
-- ---------------------------------------------------------------------
-- Salieron de los 179 hallazgos de los críticos de completitud, después de que
-- sus escépticos tumbaran 110. Las dos restauran TUS números del Excel.

-- MAIN CONDUCTOR   [hoy: LF · $8.5 · 0.1 h]
--   Tu Excel lo tiene en MLF a 20 h por mil pies, o sea 0,02 h/ft.
--   Al pasar la fila a LF se puso el precio por pie pero las horas se quedaron en 0,1: cinco veces tu número.
--   Se restaura tu hora en la unidad actual (LF); el precio $8,50/LF no se toca.
--   Ojo: la primera tanda usó ese 0,1 como ancla para SECONDARY CONDUCTOR, que se corrige en esta misma lista.
--   AFECTA: alias-supabase 'MAIN CONDUCTOR' (factor 1, auto-match toolchest)
update catalogo_items set horas_unidad = 0.02
   where item = 'MAIN CONDUCTOR' and coalesce(horas_unidad,0) = 0.1;

-- JB 1900 DEEP BOX   [hoy: E · $4.5 · 0.3 h]
--   Es tu número: en Stuart cotizaste 100 cajas '4"X 4" X 2 1/8" DEEP COMBO BOX' (la misma pieza) a $1,04 y 0,25 h, y a mano cobras 0,25 h por la caja 4x4 deep.
--   El $4,50 es un arrastre (solo lo comparte con '2" CABLE TO STRUT SUPPORT') y las 0,3 h no tienen motivo: se instala igual que la 1900 normal.
--   AFECTA: recetas (1): PENDANT — EMT | alias-supabase 'JB 1900 DEEP BOX' (factor 1) | biblioteca de takeoff (herramienta de conteo, apunta por nombre)
update catalogo_items set precio = 1.04, horas_unidad = 0.25
   where item = 'JB 1900 DEEP BOX' and coalesce(precio,0) = 4.5 and coalesce(horas_unidad,0) = 0.3;

-- ---------------------------------------------------------------------
-- BLOQUE B · CUANDO LO MIRES — descomenta lo que aceptes (las dos tandas; lo marcado «sustituye» corrige la primera)  (80)
-- ---------------------------------------------------------------------

-- 5"           LB  ALUMINUM  FITTING   [hoy: E · $194.46 · 2 h]
--   Tiene clavado el precio del LB de hierro de 5" ($194,46, que solo aparece en esas dos filas).
--   En 4" el aluminio es exactamente hierro/1,3; aplicado al 5" sale $149,60.
-- update catalogo_items set precio = 149.6
--    where item = '5"           LB  ALUMINUM  FITTING' and coalesce(precio,0) = 194.46;

-- 3"           EMT ELBOW   [hoy: E · $43.27 · 0.25 h]
--   Va con los codos de 3-1/2" y 4": la tabla se arregla entera o no se arregla.
--   El 2-1/2" del catálogo ($27,70) está a +8% de tienda; con ese mismo +8% el 3" queda en ~$31, no en $43,27 (que es precio de codo de 3-1/2").
--   Si Edgar prefiere no bajarlo, los otros dos siguen valiendo pero la tabla queda pegada.
-- update catalogo_items set precio = 31
--    where item = '3"           EMT ELBOW' and coalesce(precio,0) = 43.27;

-- 3 1/2"    EMT ELBOW   [hoy: E · $22.1 · 0.26 h]
--   A $22,10 vale la mitad que el de 3" y menos que el de 2-1/2": imposible en la misma línea.
--   Con el ancla del 2-1/2" (+8% sobre tienda) sale ~$46.
--   Correr junto con el 3" y el 4".
-- update catalogo_items set precio = 46
--    where item = '3 1/2"    EMT ELBOW' and coalesce(precio,0) = 22.1;

-- 4"           EMT ELBOW   [hoy: E · $26 · 0.29 h]
--   A $26 está por debajo del 3" y casi igual que el 2-1/2".
--   Con el mismo ancla que sus hermanos sale ~$50, y queda casi pegado al 3-1/2" como pasa en todas las familias sanas de EMT.
--   Correr las tres filas de una vez.
-- update catalogo_items set precio = 50
--    where item = '4"           EMT ELBOW' and coalesce(precio,0) = 26;

-- 4"           EMT S.S. D/C  CONNECTOR   [hoy: E · $4.19 · 0.3 h]
--   Vale menos que el de 2-1/2" de su familia y la mitad que el de acero de 4": celda reteclada (2 decimales en una familia de 4).
--   Se aplica el ratio die-cast/acero 1,23 de los dos calibres vecinos: 8,75 × 1,23.
-- update catalogo_items set precio = 10.76
--    where item = '4"           EMT S.S. D/C  CONNECTOR' and coalesce(precio,0) = 4.19;

-- 3 1/2"    EMT S.S. D/C CONNECTOR   [hoy: E · $3.31 · 0.25 h]
--   Misma avería que el de 4": por debajo del 2-1/2" y del 3" de su familia.
--   8,08 × 1,23 = 9,94, y el paso 9,94 → 10,76 calca el de la familia de acero.
-- update catalogo_items set precio = 9.94
--    where item = '3 1/2"    EMT S.S. D/C CONNECTOR' and coalesce(precio,0) = 3.31;

-- 4"           EMT S.S.  D/C COUPLING   [hoy: E · $3.08 · 0.2 h]
--   Acople de 4" más barato que el de 2-1/2" y la mitad que su hermano de acero.
--   5,90 × 1,085 = 6,40 deja la escalera monótona (4,06 / 4,79 / 5,45 / 6,40).
-- update catalogo_items set precio = 6.4
--    where item = '4"           EMT S.S.  D/C COUPLING' and coalesce(precio,0) = 3.08;

-- 3 1/2"    EMT S.S. D/C  COUPLING   [hoy: E · $2.67 · 0.15 h]
--   Cuarta fila del mismo par roto 3-1/2"/4".
--   5,06 × 1,077 = 5,45; los pasos resultantes (1,14 y 1,17) son los de la familia de acero.
-- update catalogo_items set precio = 5.45
--    where item = '3 1/2"    EMT S.S. D/C  COUPLING' and coalesce(precio,0) = 2.67;

-- 1 1/4"    EMT S.S. D/C CONNECTOR   [hoy: E · $0.53 · 0.085 h]
--   El conector de 1-1/4" vale menos que el de 1" (0,5452).
--   Aplicando al die-cast la misma subida que da el acero de 1" a 1-1/4" (×1,60) sale 0,87; el 1,05 del auditor inflaba un 20% sin base.
-- update catalogo_items set precio = 0.87
--    where item = '1 1/4"    EMT S.S. D/C CONNECTOR' and coalesce(precio,0) = 0.53;

-- 1 1/4"    EMT S.S. D/C COUPLING   [hoy: E · $0.5 · 0.055 h]
--   Acople de 1-1/4" a 0,50 por debajo del de 1" (0,5454).
--   Los tres caminos de cálculo dan 0,99-1,23; 1,10 cae en medio y deja la escalera limpia.
-- update catalogo_items set precio = 1.1
--    where item = '1 1/4"    EMT S.S. D/C COUPLING' and coalesce(precio,0) = 0.5;

-- 1 1/2"    ENT  COUPLING   [hoy: E · $1.6 · 0.035 h]
--   Único acople ENT que pide menos horas que el calibre anterior (0,035 contra 0,04).
--   En ENT acople = conector en todos los calibres sanos, y el conector de 1-1/2" está a 0,045.
-- update catalogo_items set horas_unidad = 0.045
--    where item = '1 1/2"    ENT  COUPLING' and coalesce(horas_unidad,0) = 0.035;

-- TAPCOM 1/4"   [hoy: E · $0.88 · 0.1 h]
--   0,1 h por tornillo (6 minutos) es 12,5 veces lo que la propia casa pone al mismo tornillo en 'TAPCON 1/4" x 1-1/4"' (0,008).
--   0,03 h es prudente para taladro en concreto.
--   Además son dos filas del mismo tornillo a dos precios: unificar después (ver C).
-- update catalogo_items set horas_unidad = 0.03
--    where item = 'TAPCOM 1/4"' and coalesce(horas_unidad,0) = 0.1;

-- NUTS 1/4"   [hoy: E · $0.609 · 0.02 h]
--   Una tuerca de 1/4" a $0,609 cuesta más que una contratuerca de acero de 3" ($0,525) de su propio catálogo.
--   $0,08 la deja en su sitio.
--   Calderilla, pero sale por cientos.
-- update catalogo_items set precio = 0.08
--    where item = 'NUTS 1/4"' and coalesce(precio,0) = 0.609;

-- 3/4"             EXPLOSION PROOF  SEAL-OFF   [hoy: E · $10.364 · 0.65 h]
--   El trío 3/4" está invertido: caja $25,94, sello $10,36, unión $55,40, cuando el sello (EYS) es igual o más caro que la unión.
--   La unión ya está a mercado; el sello va justo por debajo, en $50 (no los $40 del auditor).
--   Horas 0,65 se dejan.
-- update catalogo_items set precio = 50
--    where item = '3/4"             EXPLOSION PROOF  SEAL-OFF' and coalesce(precio,0) = 10.364;

-- 1 GANG ADJUSTABLE FLOOR BOX   [hoy: E · $86 · 0.5 h]
--   El auditor apuntó al 2 GANG FLOOR BOX (1,5 h), pero la fila rota es esta: 0,5 h por un floor box colado en concreto es menos de la mitad que el POKE-THRU de 1 gang (1,15 h), que solo es taladro y encajar.
--   Está en una receta y en el toolchest: mueve presupuestos abiertos.
--   AFECTA: recetas (1): FLOOR BOX 1 GANG AJUSTABLE — EMT | alias línea 47 '1 GANG ADJUSTABLE FLOOR BOX' (factor 1, unidad E)
-- update catalogo_items set horas_unidad = 1
--    where item = '1 GANG ADJUSTABLE FLOOR BOX' and coalesce(horas_unidad,0) = 0.5;

-- 2  GANG PLASTER RING 1/2"   [hoy: E · $0.357 · 0.05 h]
--   Interpolación entre 1G y 3G; el $0,357 es copia evidente del 1G.
--   Tiene el precio del anillo de 1 gang copiado con todos los decimales (0,357 = 0,34 × 1,05).
--   La serie 1G / 3G / 4G / 5G pide ~0,65 para el 2G.
--   Horas 0,05 correctas.
--   Está en tres recetas.
--   AFECTA: recetas (3): CONDUIT VACÍO 1" PARA BAJO VOLTAJE — EMT; RECEPTÁCULO 50A ESTUFA (NEMA 14-50) — ROMEX; RECEPTÁCULO DOBLE DUPLEX (QUAD) — EMT
-- update catalogo_items set precio = 0.65
--    where item = '2  GANG PLASTER RING 1/2"' and coalesce(precio,0) = 0.357;

-- 6"         PVC CONDUIT .SCH 40   [hoy: LF · $0 · 0.09 h]
--   Cero escrito en la hoja origen, con horas puestas y toda la familia de 6" valorada: el tubo se usa y se regala.
--   $9,50/ft sale de lista × el factor de Edgar; el escéptico lo ve algo alto ($8,50-9,00).
--   Provisional hasta cotización; corregir junto con el 5".
-- update catalogo_items set precio = 9.5
--    where item = '6"         PVC CONDUIT .SCH 40' and coalesce(precio,0) = 0;

-- 5"         PVC CONDUIT .SCH 40   [hoy: LF · $0 · 0.09 h]
--   Igual que el 6": $0 escrito, horas puestas, resto de la familia de 5" con precio.
--   $7,20/ft queda del lado seguro (el factor de Edgar daría $6,30-6,50).
--   Provisional hasta cotización.
-- update catalogo_items set precio = 7.2
--    where item = '5"         PVC CONDUIT .SCH 40' and coalesce(precio,0) = 0;

-- 5"        PVC CONDUIT.SCH 80   [hoy: LF · $0 · 0.075 h]
--   El SCH 80 de 5" a $0.
--   Relación SCH 80 / SCH 40 del propio catálogo muy estable (1,5-1,65): 7,20 × 1,65 = 11,90.
--   Si el 5" SCH 40 se cierra en otro número, esta baja en la misma proporción.
-- update catalogo_items set precio = 11.9
--    where item = '5"        PVC CONDUIT.SCH 80' and coalesce(precio,0) = 0;

-- PVC  GLUE 1/4   [hoy: E · $15 · 1 h]
--   Único consumible de UNDERGROUND con horas: cada bote mete 1 h que nadie trabaja.
--   Las horas de pegar ya van en cada pie de tubo y cada accesorio; los 39 consumibles de 20-MISC están a 0 h.
-- update catalogo_items set horas_unidad = 0
--    where item = 'PVC  GLUE 1/4' and coalesce(horas_unidad,0) = 1;

-- 3"         PVC-LB-FITTING   [hoy: E · $0.242 · 0.55 h]
--   De $28,96 en 2-1/2" cae a $0,24 en 3": 120 veces menos al subir de tamaño.
--   $45 sale por dos caminos que se cruzan (mercado × 0,7 y el escalón 3"/4" de la familia de aluminio).
--   Los cuatro LB rotos (3", 3-1/2", 4", 5") se corren juntos.
-- update catalogo_items set precio = 45
--    where item = '3"         PVC-LB-FITTING' and coalesce(precio,0) = 0.242;

-- 3 1/2"  PVC-LB-FITTING   [hoy: E · $0.263 · 0.55 h]
--   Segundo LB de la serie rota a céntimos.
--   $60 queda entre el 3" ($45) y el 4" ($80).
--   Las horas (0,55, iguales al 3") están bien: los tamaños contiguos repiten horas en todo el catálogo.
-- update catalogo_items set precio = 60
--    where item = '3 1/2"  PVC-LB-FITTING' and coalesce(precio,0) = 0.263;

-- 4"         PVC-LB-FITTING   [hoy: E · $0.305 · 0.6 h]
--   Cuerpo LB de PVC de 4" a 30 céntimos.
--   Mercado × 0,7, y el 0,7 está calibrado con el LB de 3/4" de este mismo catálogo (Edgar = 0,67 de Home Depot).
--   Verificar con proveedor; rango razonable $70-95.
-- update catalogo_items set precio = 80
--    where item = '4"         PVC-LB-FITTING' and coalesce(precio,0) = 0.305;

-- 5"         PVC-LB-FITTING   [hoy: E · $0.368 · 0.65 h]
--   El LB más grande a 37 céntimos.
--   Se deriva del 4": 1,3 × $80 = $105 (el escalón 4"→5" real va de 1,08 a 1,54 según familia).
--   NO usar el LB de aluminio de 5" ($194,46) como referencia: es copia del de hierro.
-- update catalogo_items set precio = 105
--    where item = '5"         PVC-LB-FITTING' and coalesce(precio,0) = 0.368;

-- # 6  BARE COPPER  WIRE   [hoy: LF · $0.16 · 0.009 h]
--   PROVISIONAL (estimado de mercado, no factura): $0,16/ft está por debajo del metal.
--   A $0,16/ft el desnudo #6 cuesta la séptima parte del THHN #6 del propio catálogo ($1,168/ft) y una sexta parte del detalle ($0,94/ft).
--   $0,85 es coherente con ambos.
--   Está en la receta del rack IDF.
--   (Aviso: no está "por debajo del metal", eso era falso.).
--   AFECTA: recetas (1): RACK DE COMUNICACIONES (IDF) 24 PUERTOS
-- update catalogo_items set precio = 0.85
--    where item = '# 6  BARE COPPER  WIRE' and coalesce(precio,0) = 0.16;

-- 1-1/4"   PVC CONDUIT. SCH 40   [hoy: LF · $1.398 · 0.045 h]
--   El tubo de 1-1/4" cuesta más que el de 1-1/2" ($1,398 contra $1,372).
--   La relación SCH 80 / SCH 40 se hunde solo en este calibre (1,26 contra 1,5-1,65 del resto).
--   Con la relación 1-1/4"/1-1/2" de la columna SCH 80 sale $1,15.
-- update catalogo_items set precio = 1.15
--    where item = '1-1/4"   PVC CONDUIT. SCH 40' and coalesce(precio,0) = 1.398;

-- 1 1/4"  PVC  ELBOW   [hoy: E · $4.88 · 0.225 h]
--   Codo de 1-1/4" a $4,88, casi el precio del de 3" y 4 veces el de 1-1/2" ($1,26): precio de metal arrastrado (el codo GRS de 1-1/4" está a $5,38).
--   $1,10 lo deja en su escalón.
-- update catalogo_items set precio = 1.1
--    where item = '1 1/4"  PVC  ELBOW' and coalesce(precio,0) = 4.88;

-- 6"         PVC COUPLING   [hoy: E · $4.7 · 0.055 h]
--   Coupling de 6" con el precio del de 5" copiado ($4,70 los dos).
--   El 4" ($2,10) está a ~0,20 del detalle; un coupling de 6" al detalle ronda $35-45 → $7-9 al nivel de Edgar.
--   $8,50.
-- update catalogo_items set precio = 8.5
--    where item = '6"         PVC COUPLING' and coalesce(precio,0) = 4.7;

-- 4"         PVC END BELL   [hoy: E · $4.358 · 0.5 h]
--   La campana de 4" pide 0,5 h, más que la de 5" (0,4) y casi el doble que la de 3-1/2" (0,28): inversión, no empate.
--   0,30 continúa la serie (0,28 → 0,30 → 0,40).
-- update catalogo_items set horas_unidad = 0.3
--    where item = '4"         PVC END BELL' and coalesce(horas_unidad,0) = 0.5;

-- 1"         PVC PLASTIC BUSHING   [hoy: E · $0.73 · 0.025 h]
--   Bushing de 1" a $0,73, seis veces el de 1-1/4" ($0,126): es $0,073 con el decimal corrido.
--   $0,09 deja la serie limpia (0,06 / 0,09 / 0,126).
--   Calderilla, arreglo de un minuto.
-- update catalogo_items set precio = 0.09
--    where item = '1"         PVC PLASTIC BUSHING' and coalesce(precio,0) = 0.73;

-- BREAKER CAFCI 20A 1P   [hoy: EA · $50 · 0.15 h]
--   Es el mismo aparato que 'BREAKER AFCI 1P 20A' ($45 / 0,3 h) con otro nombre y otros números; 0,15 h es el mínimo de las 24 filas BREAKER.
--   Se alinea al AFCI para que no importe cuál se pique.
--   Ni AFCI ni CAFCI tienen alias (el escéptico se equivocó en eso).
--   Riesgo pide que Edgar confirme una sola tabla de horas de breaker.
-- update catalogo_items set precio = 45, horas_unidad = 0.3
--    where item = 'BREAKER CAFCI 20A 1P' and coalesce(precio,0) = 50 and coalesce(horas_unidad,0) = 0.15;

-- BREAKER CAFCI 15A 1P   [hoy: EA · $50 · 0.15 h]
--   Gemela del CAFCI 20A: se alinea a 'BREAKER AFCI 1P 15A' ($45 / 0,3 h).
--   Todo lo electrónico de 1P del catálogo (AFCI, GFCI, dual) está a 0,3 h.
-- update catalogo_items set precio = 45, horas_unidad = 0.3
--    where item = 'BREAKER CAFCI 15A 1P' and coalesce(precio,0) = 50 and coalesce(horas_unidad,0) = 0.15;

-- BREAKER 2P 60A   [hoy: EA · $30 · 0.2 h]
--   Cobra menos horas (0,2) que el 2P de 20A (0,3): sin defensa.
--   0,35 = carcasa compartida con el 70A y coincide con la tabla única propuesta (2P 60-100A: 0,35).
--   El precio $30 encaja y no se toca.
-- update catalogo_items set horas_unidad = 0.35
--    where item = 'BREAKER 2P 60A' and coalesce(horas_unidad,0) = 0.2;

-- BREAKER 2P 25A   [hoy: EA · $25 · 0.2 h]
--   La otra fila 2P que se quedó en 0,2 cuando todos sus vecinos hasta 50A están a 0,3.
--   El precio $25 no se toca (un 2P de 25A es rareza y se cobra por encima del de 30A).
-- update catalogo_items set horas_unidad = 0.3
--    where item = 'BREAKER 2P 25A' and coalesce(horas_unidad,0) = 0.2;

-- # 400   MCM THW CU.   [hoy: MLF · $7425.91 · 34 h]
--   OJO: hasta que corras esto, la escalera queda rota justo en medio (400 < 350 < 500): no cotices un feeder de 400 MCM antes.
--   A $7.426 el 400 MCM cuesta menos que el 4/0, con el doble de cobre.
--   No hay compra real de 400; $13.700 es la interpolación entre los precios reales de UM del 350 ($12.647) y del 500 ($15.805).
--   Por eso va en B y no en A.
-- update catalogo_items set precio = 13700
--    where item = '# 400   MCM THW CU.' and coalesce(precio,0) = 7425.91;

-- # 2/0   LUGS   [hoy: E · $36.75 · 0.2 h]
--   Un lug de 2/0 a $36,75 cuesta más que el de 500 MCM ($22,89).
--   Interpolando la propia familia LUGS entre 1/0 ($3,49) y 250 MCM ($9,66) salen $4,67.
-- update catalogo_items set precio = 4.67
--    where item = '# 2/0   LUGS' and coalesce(precio,0) = 36.75;

-- # 250   MCM POLARIS CONNECTORS   [hoy: E · $92.4 · 0.5 h]
--   El conector de 250 pide 0,5 h, el doble que el de 350 (0,25) y más que el de 500 (0,3).
--   0,25 restaura la monotonía.
--   Precio no cambia.
-- update catalogo_items set horas_unidad = 0.25
--    where item = '# 250   MCM POLARIS CONNECTORS' and coalesce(horas_unidad,0) = 0.5;

-- # 250   MCM LUGS   [hoy: E · $9.66 · 0.5 h]
--   Misma columna de horas copiada de POLARIS (0,2 / 0,2 / 0,5 / 0,25 / 0,3) con el mismo pico en 250.
--   A 0,25 como su hermano.
--   Precio no cambia.
-- update catalogo_items set horas_unidad = 0.25
--    where item = '# 250   MCM LUGS' and coalesce(horas_unidad,0) = 0.5;

-- 45' ALUMINUM POLE + FIXT+ BASE+ CABLE DIST.   [hoy: E · $2250 · 6 h]
--   El paquete (poste + luminaria + base + cable) cuesta $700 menos y 2 h menos que solo el poste con luminaria ($2.950 / 8 h).
--   Paquete = suma de sus piezas del catálogo: $2.950 + $285 base + ~$165 cable/empalmes = $3.400 y 8 + 4 = 12 h.
--   Alternativa que recomienda el escéptico: borrar el paquete y picar las tres filas.
--   Tiene alias.
--   AFECTA: alias línea 98 '45' ALUMINUM POLE + FIXT+ BASE+ CABLE DIST.' (factor 1, unidad E)
-- update catalogo_items set precio = 3400, horas_unidad = 12
--    where item = '45'' ALUMINUM POLE + FIXT+ BASE+ CABLE DIST.' and coalesce(precio,0) = 2250 and coalesce(horas_unidad,0) = 6;

-- WP HORN/STROBE LIGHT W/BACKBOX   [hoy: E · $102 · 1.5 h]
--   Las otras tres van a 0,5 h pero no hay factura de un WP en tus obras (Stuart no tuvo ninguno) y un exterior con caja estanca puede llevar prima.
--   PREGUNTA: ¿1,5 h es prima de exterior o error? Pide 1,5 h cuando STROBE, WP STROBE y HORN/STROBE piden 0,5: la pareja de estrobos no lleva prima por estanca, y la única prima WP del catálogo es +0,2 h (GFCI WR).
--   A 0,5 como sus hermanas.
--   El precio ($102) queda por debajo del horn/strobe normal tras subirlo a $137,99: revisar.
--   AFECTA: recetas (1): HORN/STROBE F/A INTEMPERIE (WP) | alias línea 219 'WP HORN / STROBE LIGHT W/BACKBOX' (factor 1, unidad E)
-- update catalogo_items set horas_unidad = 0.5
--    where item = 'WP HORN/STROBE LIGHT W/BACKBOX' and coalesce(horas_unidad,0) = 1.5;

-- REMOTE POWER PACK   [hoy: E · $20 · 0.5 h]
--   No existe power pack de marca a $20 (el BZ-150 que describe la fila va a $103 al público).
--   $45 es SUELO PROVISIONAL para que el bid no salga con agujero; marcar con fecha y pedir la línea del proveedor (si compra BZ-150 estará en $55-70).
--   Está en la receta de sensor de techo.
--   AFECTA: recetas (1): SENSOR DE OCUPACIÓN DE TECHO — MC | alias línea 77 'REMOTE POWER PACK' (factor 1, unidad E)
-- update catalogo_items set precio = 45
--    where item = 'REMOTE POWER PACK' and coalesce(precio,0) = 20;

-- Plant Shutdown Coordination   [hoy: EA · $385 · 0 h]
--   Única fila de coordinación con 0 h: la parada de planta es trabajo de gente y hoy no aporta ni una hora (ni overhead por hora-hombre).
--   4 h como 'Temporary Power Setup', su gemela estructural ($385 / 4 h).
--   Precio se deja.
--   La lente de coherencia pregunta si una fila debe cobrar precio Y horas; eso lo decide Edgar.
-- update catalogo_items set horas_unidad = 4
--    where item = 'Plant Shutdown Coordination' and coalesce(horas_unidad,0) = 0;

-- CABLE HOLDER   [hoy: E · $0 · 0.3 h]
--   Pieza física a $0 y 0,3 h por grapa (18 minutos).
--   Horas ancladas en el propio catálogo: '2" CABLE TO ROD SUPPORT' 0,12 h (un soporte de cubierta lleva taladro, anclaje y sellado; no es el clip de 0,05).
--   Precio $2 es mitad de la horquilla de mercado: provisional.
--   AFECTA: alias línea 280 'CABLE HOLDER' (factor 1, unidad E)
-- update catalogo_items set precio = 2, horas_unidad = 0.12
--    where item = 'CABLE HOLDER' and coalesce(precio,0) = 0 and coalesce(horas_unidad,0) = 0.3;

-- TEE CABLE SPLICE   [hoy: E · $0 · 0.6 h]
--   Empalme en T de bronce a $0 con su versión recta al lado a $12: más material y más horas reconocidas (0,6).
--   $18 queda por encima del recto y en la franja de mercado ($15-30).
--   Si hay factura, manda la factura.
--   AFECTA: alias línea 282 'TEE CABLE SPLICE' (factor 1, unidad E)
-- update catalogo_items set precio = 18
--    where item = 'TEE CABLE SPLICE' and coalesce(precio,0) = 0;

-- BONDING PLATE   [hoy: E · $0 · 0.6 h]
--   Pletina de cobre/aluminio con tornillería a $0 en una sección donde el $0 no es convención (solo 7 de 26 filas).
--   Comparables con precio: CABLE SPLICE $12, CADWELD MOLD $82.
--   $20 razonable; factura manda.
--   AFECTA: alias línea 279 'BONDING PLATE' (factor 1, unidad E)
-- update catalogo_items set precio = 20
--    where item = 'BONDING PLATE' and coalesce(precio,0) = 0;

-- BONDING LUG   [hoy: E · $0 · 0.4 h]
--   Terminal de bronce a $0.
--   $10 queda entre la abrazadera de conduit de 3/4" ($10,25) y el splice ($12), sin inventar nada de fuera.
--   Factura manda.
--   AFECTA: alias línea 283 'BONDING LUG' (factor 1, unidad E)
-- update catalogo_items set precio = 10
--    where item = 'BONDING LUG' and coalesce(precio,0) = 0;

-- TV COUPLER   [hoy: E · $0 · 0.6 h]
--   0,6 h es el máximo del material menudo de CATV para la pieza más simple (barrilete).
--   Un coupler son dos remates y BNC paga 0,1 por uno: 0,2 h, en la escalera 0,1 / 0,2 / 0,3.
--   El precio $0 NO se fija a ciegas: si es F-81 ~$1, si es acoplador direccional $15-25.
--   Pregunta para Edgar.
--   AFECTA: alias línea 249 'TV COUPLER' (factor 1, unidad E)
-- update catalogo_items set horas_unidad = 0.2
--    where item = 'TV COUPLER' and coalesce(horas_unidad,0) = 0.6;

-- 2" CABLE TO ROD SUPPORT   [hoy: E · $0 · 0.12 h]
--   Herraje comprado a $0 en TELECOM, donde el $0 no es convención (solo 2 filas de 22).
--   El $4,50 es PROVISIONAL: viene de la fila del strut, que otra ficha señala como arrastre de JB 1900 DEEP BOX.
--   Marcar con fecha y confirmar con proveedor antes del próximo bid.
--   Horas 0,12 bien.
--   AFECTA: alias línea 261 '2" CABLE TO ROD SUPPORT' (factor 1, unidad E) | alias línea 274 '2" CABLE TO ROD SUPPORT' (factor 1, unidad E)
-- update catalogo_items set precio = 4.5
--    where item = '2" CABLE TO ROD SUPPORT' and coalesce(precio,0) = 0;

-- 2" CABLE TO BEAM SUPPORT   [hoy: E · $0 · 0.15 h]
--   Igual que el de varilla: grapa de viga a $0.
--   $4,50 PROVISIONAL (mismo origen dudoso); rango de mercado $3-6 sin verificar en fichero.
--   Horas 0,15 se dejan.
--   AFECTA: alias línea 263 '2" CABLE TO BEAM SUPPORT' (factor 1, unidad E) | alias línea 276 '2" CABLE TO BEAM SUPPORT' (factor 1, unidad E)
-- update catalogo_items set precio = 4.5
--    where item = '2" CABLE TO BEAM SUPPORT' and coalesce(precio,0) = 0;

-- 2/P #18 PLENUM  SOUND CABLE   [hoy: MLF · $0 · 8 h]
--   De las 59 filas MLF solo seis están por debajo de $5, y tres son estos cables de sonido: el resto de cables de baja tensión sí está tarifado ($60-$225).
--   El plenum 18/2 es el caro del trío; $170 es de mercado, sin fila propia de apoyo.
--   Horas 8 ya coinciden con la familia LV.
-- update catalogo_items set precio = 170
--    where item = '2/P #18 PLENUM  SOUND CABLE' and coalesce(precio,0) = 0;

-- WP # 373 DRY  SOUND CABLE   [hoy: MLF · $0 · 8 h]
--   Cable de sonido a $0.
--   Se copia '2/P #18 SECURITY CABLE' (MLF $85 / 8 h): 18 AWG de 2 conductores con las mismas 8 h; el WP 373 es sin pantalla, así que $85 es el techo, no el suelo ($60-85).
--   Los $95 del auditor quedaban por encima de los dos testigos que citaba.
-- update catalogo_items set precio = 85
--    where item = 'WP # 373 DRY  SOUND CABLE' and coalesce(precio,0) = 0;

-- WP # 373 WET  SOUND CABLE   [hoy: MLF · $0 · 8 h]
--   Versión húmeda a $0.
--   $175 no es estimación: es lo que el catálogo ya cobra al mismo cable Aquaseal 18/2 en '18- 2 TWISTED WET LOC.
--   WP.
--   AQC 293' (MLF $175).
--   Aviso: quedan tres filas del mismo Aquaseal ($175, $175, $196); dedupe para otra sentada.
-- update catalogo_items set precio = 175
--    where item = 'WP # 373 WET  SOUND CABLE' and coalesce(precio,0) = 0;

-- DOUBLE ELECTRIC DOOR STRIKE   [hoy: E · $645 · 0.6 h]
--   El cerradero doble pide la mitad de horas (0,6) que el simple (1,2).
--   Una puerta doble lleva dos cerraderos: 2 × 1,2 = 2,4 h (no las 2 h del auditor, que salían de escalar precios).
--   Precio $645 se deja.
-- update catalogo_items set horas_unidad = 2.4
--    where item = 'DOUBLE ELECTRIC DOOR STRIKE' and coalesce(horas_unidad,0) = 0.6;

-- 18- 2 TWISTED WET LOC. WP. AQC 293   [hoy: MLF · $175 · 9 h]
--   Los nueve cables de baja tensión de 13-LV van a 8 h/MLF sin excepción y este solo a 9: tirar un 18/2 es tirar un 18/2.
--   Solo horas; el precio ($175) NO se toca.
--   Que sea o no el mismo carrete que '18/2 FPL WET LOC.
--   AQ-293' ($196) lo decide Edgar, no se igualan precios a ciegas.
-- update catalogo_items set horas_unidad = 8
--    where item = '18- 2 TWISTED WET LOC. WP. AQC 293' and coalesce(horas_unidad,0) = 9;

-- Extra LF Romex 6/3 NM   [hoy: LF · $5.15 · 0.025 h]
--   Las seis 'Extra LF Romex' llevan 0,025 h/ft planas del 14/2 al 6/3.
--   En obra nueva tu WIRING ya cobra el 6/3 a 31 h/MLF (0,031/ft) y el pie extra en remodel no puede costar menos: 0,04 h/ft (31 h/MLF con ~30% de remodel), coherente con tus REWIRE 50A RANGE (3 h) frente a 30A DRYER (2,5 h).
--   El 14/2 y el 12/2 no se tocan.
--   Fila importada, no está en tu Excel.
--   AFECTA: nadie (ni recetas ni alias)
-- update catalogo_items set horas_unidad = 0.04
--    where item = 'Extra LF Romex 6/3 NM' and coalesce(horas_unidad,0) = 0.025;

-- Panel Termination (per circuit)   [hoy: EA · $25 · 0.5 h]
--   Los $25 de material no tienen pieza detrás: el breaker va aparte (BREAKER 1P 20A, $8) y las dos recetas HOMERUN que la usan ya lo llevan como componente, así que dentro de la receta es material fantasma.
--   Terminar un circuito (fase, neutro, tierra, etiqueta) son 0,25 h, no 0,5.
--   Al ponerla a $0 marcar cero_motivo='solo_labor' para que no salte falta_precio.
--   AFECTA: recetas (2): HOMERUN 20A AL PANEL — EMT; HOMERUN 20A AL PANEL — MC
-- update catalogo_items set precio = 0, horas_unidad = 0.25
--    where item = 'Panel Termination (per circuit)' and coalesce(precio,0) = 25 and coalesce(horas_unidad,0) = 0.5;

-- FIRE ALARM ANNUNCIATOR PANEL   [hoy: E · $0 · 8 h]
--   Pide 8 h, las mismas del FIRE ALARM CONTROL PANEL, y tu propio Excel tasa el SECURITY ANNUNCIATOR PANEL en 2 h.
--   Un anunciador LCD de F/A (caja empotrada en lobby, SLC más 24V, direccionamiento) va en 3 h; el TERMINAL CABINET de 2 h es solo una caja con regletas.
--   Es una hora tuya que se baja por coherencia.
--   El $0 se queda (suministro).
--   AFECTA: alias_takeoff.csv línea 208 'FIRE ALARM ANNUNCIATOR PANEL' (factor 1, unidad E) | alias-supabase 'FIRE ALARM ANNUNCIATOR PANEL' (factor 1, auto-match toolchest)
-- update catalogo_items set horas_unidad = 3
--    where item = 'FIRE ALARM ANNUNCIATOR PANEL' and coalesce(horas_unidad,0) = 8;

-- VOICE EVAC SPEAKER   [hoy: EA · $145 · 0.75 h]
--   Los $145 son los de FIRE ALARM MODULE, pegados en la misma pasada de relleno (en tu Excel el MODULE era $0 y esta fila no existía).
--   La receta la usa como bocina sola, el estrobo va aparte: bocina de techo de evac (SPCWL/E70) a precio de casa de suministro ~$75, PROVISIONAL.
--   Horas 0,5 como FIRE ALARM SPEAKER, mismo montaje y mismo 18/2.
--   AFECTA: recetas (1): SPEAKER/STROBE F/A (EVAC DE VOZ) | alias-supabase 'VOICE EVAC SPEAKER' (factor 1, auto-match toolchest)
-- update catalogo_items set precio = 75, horas_unidad = 0.5
--    where item = 'VOICE EVAC SPEAKER' and coalesce(precio,0) = 145 and coalesce(horas_unidad,0) = 0.75;

-- 14/4 FPL FIRE ALARM CABLE   [hoy: MLF · $184 · 8 h]
--   Tu Excel dice $184/MLF, pero en el bid Stuart (ene-2026) tú mismo cotizaste 500 ft de 14/4 FPL a $0,28/ft = $280/MLF.
--   Se pone tu número más reciente (escalando por cobre desde el 12/2 ROMEX saldría ~$335, así que va en la dirección correcta).
--   La unidad MLF NO se toca: 5 recetas le pasan 0,025-0,05 MLF.
--   Las 8 h se quedan.
--   AFECTA: recetas (5): STROBE F/A; HORN/STROBE F/A; HORN/STROBE F/A INTEMPERIE (WP); SPEAKER/STROBE F/A (EVAC DE VOZ); PANEL BOOSTER 24VDC — EMT | alias_takeoff.csv línea 240 '14/4 FPL FIRE ALARM CABLE' (factor 1, unidad MLF) | alias-supabase '14/4 FPL FIRE ALARM CABLE' (factor 1, auto-match toolchest)
-- update catalogo_items set precio = 280
--    where item = '14/4 FPL FIRE ALARM CABLE' and coalesce(precio,0) = 184;

-- AUTOMATIC TRANSFER SWITCH 400A   [hoy: E · $0 · 8 h]
--   Esta fila entró el 14/09 con las 8 h de tu Excel, donde la escalera era 200A 7 / 400A 8 / 600A 10; pero en Supabase la familia ya está reescalada y con precio (200A 8 h, 600A 16 h), así que el 400A quedó igual que el 200A.
--   Interpolando tu escalera viva salen 12 h.
--   El $0 NO se toca: ATS va por cotización (falta_precio).
--   Si prefieres la escalera del Excel, lo alto son las hermanas, no esta.
--   AFECTA: alias_takeoff.csv línea 200 'AUTO. TRANS. SW. 400A' (factor 1, unidad E) | alias-supabase 'AUTO. TRANS. SW. 400A' (factor 1, MXP Planos E2g — item creado 14/09)
-- update catalogo_items set horas_unidad = 12
--    where item = 'AUTOMATIC TRANSFER SWITCH 400A' and coalesce(horas_unidad,0) = 8;

-- LED HIGH-BAY   [hoy: EA · $145 · 1 h]
--   Un high-bay se cuelga a 25-30 ft desde tijera y tiene las mismas 1 h que un troffer 2x4 en rejilla.
--   El propio lote da 1,5 h al vapor-tight y al track de 8', y el script que dio de alta esta fila (venía de Bluebeam, no de tu Excel) la estimó en 1,5 h antes de que alguien la bajara a 1.
--   Las 2 h del auditor no salen de ningún sitio.
--   AFECTA: alias-supabase 'LED High-Bay' (factor 1, MXP Planos v3 — Bluebeam LGT-039) | alias-supabase 'LED HIGH-BAY' (factor 1, auto-match toolchest) | lista de genera-takeoff-lib.js (apunta por nombre, no se toca)
-- update catalogo_items set horas_unidad = 1.5
--    where item = 'LED HIGH-BAY' and coalesce(horas_unidad,0) = 1;

-- LED PENDANT   [hoy: EA · $145 · 1 h]
--   Es la misma luminaria que PENDANT (E, $185, 1,25 h) cargada otra vez en el bloque EA de Bluebeam con $40 y 0,25 h menos, y todos los alias de plano (Pendant Light, Island Pendants, Linear Pendant, Mini Pendant) caen en esta.
--   Se igualan los números para que el mismo pendant no salga a dos precios.
--   Ojo: los $185 de PENDANT tampoco vienen de tu Excel (ahí estaba a $0 / 1 h): confirma que ese precio es tuyo.
--   AFECTA: alias-supabase 'LED PENDANT' (factor 1) | alias-supabase 'Pendant Light' (factor 1, MXP Planos v4) | alias-supabase 'Island Pendants (3)' (factor 3, MXP Planos v3 — el símbolo trae 3) | alias-supabase 'Linear Pendant 48"' (factor 1, MXP Planos v3) | alias-supabase 'Mini Pendant' (factor 1, MXP Planos v3 — Bluebeam LGT-044) | lista de genera-takeoff-lib.js (por nombre)
-- update catalogo_items set precio = 185, horas_unidad = 1.25
--    where item = 'LED PENDANT' and coalesce(precio,0) = 145 and coalesce(horas_unidad,0) = 1;

-- Lutron Pico Remote (wall mount)   [hoy: EA · $48 · 0.4 h]
--   Es el mismo mando a pilas que 'Caseta Pico Remote (4-button)' (0,25 h) más un soporte de pared: no lleva cable ni caja.
--   0,4 h es el doble de lo que cobras por un interruptor cableado (0,2 h).
--   El precio $48 se queda (placa Satin, criterio del bloque RA3); el $34 del auditor se descartó.
--   AFECTA: alias-supabase 'Lutron Pico Remote (wall mount' (factor 1, auto-match toolchest)
-- update catalogo_items set horas_unidad = 0.25
--    where item = 'Lutron Pico Remote (wall mount)' and coalesce(horas_unidad,0) = 0.4;

-- FIRE -STOPPING  SEAL CAULKING   [hoy: E · $16 · 0 h]
--   En tu Excel las horas de esta fila son NULL y el porte lo convirtió en 0: nunca decidiste que sellar una penetración fuese gratis.
--   Contando un tubo por penetración, limpiar, empacar, sellar y dejarla visible al inspector son 0,25 h, tu escala de caja 4x4 deep.
--   Mismo defecto en DUCT SEAL, CORE DRILLING y FIRE-STOPPING PAINT (fuera de este lote).
--   AFECTA: nadie (ni recetas ni alias)
-- update catalogo_items set horas_unidad = 0.25
--    where item = 'FIRE -STOPPING  SEAL CAULKING' and coalesce(horas_unidad,0) = 0;

-- PUTTY PAD SEAL   [hoy: E · $2.8 · 0 h]
--   Misma raíz: horas NULL en tu Excel, 0 en el porte.
--   Un pad ($2,80) es una caja forrada por detrás: 0,1 h por caja, la escala que usas para tapa (0,08) y demoler caja (0,10).
--   AFECTA: nadie (ni recetas ni alias)
-- update catalogo_items set horas_unidad = 0.1
--    where item = 'PUTTY PAD SEAL' and coalesce(horas_unidad,0) = 0;

-- 1"           EMT D/C COMPR. COUPLING   [hoy: E · $0.58 · 0.2 h]
--   0,2 h por un acople de compresión de 1" cuando el de tornillo de la misma medida ('1" EMT S.S.D/C COUPLING') pide 0,05 h y tu escalera de tornillo coincide con NECA.
--   La escalera de compresión (.10/.15/.20/.25...) es una rampa redonda copiada en D/C y STEEL, no una medición; compresión = tornillo x1,2 = 0,06 h.
--   Hora tuya que se baja por coherencia.
--   AFECTA: nadie (ni recetas ni alias)
-- update catalogo_items set horas_unidad = 0.06
--    where item = '1"           EMT D/C COMPR. COUPLING' and coalesce(horas_unidad,0) = 0.2;

-- 1"           EMT STEEL COMPR. COUPLING   [hoy: E · $0.75 · 0.2 h]
--   Gemelo en acero del anterior: 0,2 h contra 0,05 h de '1" EMT S.S.
--   STEEL COUPLING'.
--   Las dos escaleras de compresión son la misma lista copiada fila por fila.
--   0,06 h.
--   AFECTA: nadie (ni recetas ni alias)
-- update catalogo_items set horas_unidad = 0.06
--    where item = '1"           EMT STEEL COMPR. COUPLING' and coalesce(horas_unidad,0) = 0.2;

-- 2"           EMT D/CCOMPR. CONNECT.   [hoy: E · $1.75 · 0.3 h]
--   0,3 h contra 0,10 h de '2" EMT S.S.
--   D/C CONNECTOR': tres veces el de tornillo cuando NECA da +20%.
--   0,12 h.
--   El nombre roto (D/CCOMPR sin espacio) se deja: nadie lo referencia y renombrar no arregla cantidades.
--   AFECTA: nadie (ni recetas ni alias)
-- update catalogo_items set horas_unidad = 0.12
--    where item = '2"           EMT D/CCOMPR. CONNECT.' and coalesce(horas_unidad,0) = 0.3;

-- 2"           EMT STEEL COMPR. CONNECT.   [hoy: E · $2.6 · 0.3 h]
--   Gemelo en acero: 0,3 h contra 0,10 h de '2" EMT S.S.
--   STEEL CONNECTOR'.
--   0,12 h (tornillo x1,2).
--   AFECTA: nadie (ni recetas ni alias)
-- update catalogo_items set horas_unidad = 0.12
--    where item = '2"           EMT STEEL COMPR. CONNECT.' and coalesce(horas_unidad,0) = 0.3;

-- 2"           EMT  STEEL COMP. COUPLING   [hoy: E · $2.48 · 0.35 h]
--   0,35 h contra 0,08 h de '2" EMT S.S.
--   STEEL COUPLING': más de cuatro veces, y más de la mitad de tu punto completo de receptáculo (0,63 h).
--   Compresión +20% = 0,096, redondeado 0,10 h.
--   El nombre 'COMP.' se deja (nadie lo referencia).
--   AFECTA: nadie (ni recetas ni alias)
-- update catalogo_items set horas_unidad = 0.1
--    where item = '2"           EMT  STEEL COMP. COUPLING' and coalesce(horas_unidad,0) = 0.35;

-- 2"           EMT D/C  COMPR. COUPLING   [hoy: E · $1.94 · 0.35 h]
--   Gemelo die-cast del anterior, no venía como hallazgo propio pero el escéptico lo pidió: también está en 0,35 h contra 0,08 del tornillo.
--   Mismo arreglo, 0,10 h, para no dejar la pareja desparejada.
--   AFECTA: nadie (ni recetas ni alias)
-- update catalogo_items set horas_unidad = 0.1
--    where item = '2"           EMT D/C  COMPR. COUPLING' and coalesce(horas_unidad,0) = 0.35;

-- 4"           EMT D/C COMPR. CONNECT.   [hoy: E · $7 · 0.7 h]
--   0,7 h (42 minutos) por un conector: más que tu punto completo de receptáculo (0,63 h).
--   El de tornillo de 4" está en 0,30 h; un 4" de compresión pide dos llaves grandes pero NECA lo pone 20-30% arriba, no x2,3.
--   0,35 h.
--   AFECTA: nadie (ni recetas ni alias)
-- update catalogo_items set horas_unidad = 0.35
--    where item = '4"           EMT D/C COMPR. CONNECT.' and coalesce(horas_unidad,0) = 0.7;

-- 4"           EMT STEEL COMPR. CONNECT.   [hoy: E · $14.92 · 0.7 h]
--   Gemelo en acero: 0,7 h contra 0,30 h de '4" EMT S.S.
--   STEEL CONNECTOR'.
--   Misma rampa copiada.
--   0,35 h.
--   Conviene aplicar el mismo criterio (tornillo x1,2) a las 10 medidas de las cuatro familias de compresión, que no vienen en este lote.
--   AFECTA: nadie (ni recetas ni alias)
-- update catalogo_items set horas_unidad = 0.35
--    where item = '4"           EMT STEEL COMPR. CONNECT.' and coalesce(horas_unidad,0) = 0.7;

-- EV CHARGER OUTLET (NEMA 14-50)   [hoy: EA · $48 · 1.5 h]
--   Es el mismo receptáculo NEMA 14-50 que '240V RANGE OUTLET (NEMA 14-50)' (1 h) y tu DRYER 14-30 también va a 1 h: 1 h es el valor de la casa para receptáculo de 240V, 1,5 h es el único fuera de línea.
--   Ninguna de las dos viene de tu Excel (son EA, del toolchest).
--   El precio $48 se queda (grado industrial).
--   AFECTA: alias-supabase 'EV CHARGER OUTLET (NEMA 14-50' (factor 1, auto-match toolchest)
-- update catalogo_items set horas_unidad = 1
--    where item = 'EV CHARGER OUTLET (NEMA 14-50)' and coalesce(horas_unidad,0) = 1.5;

-- SECONDARY CONDUCTOR   [hoy: MLF · $0 · 15 h]
--   La primera tanda la pasó a LF con 0,08 h/ft tomando como ancla el 0,1 h/ft de MAIN CONDUCTOR, y ese 0,1 resultó ser un error del porte (tu Excel: 20 h/MLF).
--   Tu número para el secundario ('SECUNDARY CONDUCTOR' en el Excel) es 15 h/MLF = 0,015 h/ft, por debajo del principal (0,02) como siempre estuvo.
--   LF y el $5/ft provisional se mantienen de la primera tanda.
--   AFECTA: alias-supabase 'SECONDARY CONDUCTOR' (factor 1, auto-match toolchest)
-- update catalogo_items set unidad = 'LF', precio = 5, horas_unidad = 0.015
--    where item = 'SECONDARY CONDUCTOR' and unidad = 'MLF' and coalesce(precio,0) = 0 and coalesce(horas_unidad,0) = 15;

-- 20A , 12 POLES LIGHTING CONTACTOR   [hoy: E · $450 · 3 h]
--   Solo existe con coma y en el bloque sin sección: si se purga ese bloque, Edgar pierde el contactor de 12 polos ($450 / 3 h), que no tiene gemela.
--   Se rescata renombrándolo sin coma y poniéndolo en LIGHTING FIXTURES junto a su hermano de 4 polos (orden 737).
--   La coma no se normaliza: el alias hay que repuntarlo a mano.
--   AFECTA: alias línea 111 '20A , 12 POLES LIGHTING CONTACTOR' (factor 1, unidad E) | repuntar el alias de la línea 111 al nuevo nombre ANTES o en el mismo commit; poner seccion='LIGHTING FIXTURES' y orden junto a 737
--   ⚠ PRIMERO repuntar lo que apunta a este nombre (ver AFECTA); si no, se queda huérfano.
-- update catalogo_items set item = '20A 12 POLES LIGHTING CONTACTOR' where item = '20A , 12 POLES LIGHTING CONTACTOR';

-- LIGHTING  RELAY   [hoy: E · $85 · 0.5 h]
--   Duplicado exacto de 'LIGHTING RELAY' (doble espacio; misma pieza, mismos $85 / 0,5 h).
--   En el diccionario del estimador una pisa a la otra.
--   Se borra la del doble espacio (sección null, orden 0).
--   Hoy no mueve dinero; evita dos verdades mañana.
--   AFECTA: alias línea 108 'LIGHTING RELAY' (factor 1, unidad E) | repuntar el alias de la línea 108 a 'LIGHTING RELAY' en el mismo commit (la resolución normaliza espacios, así que no rompe, pero el CSV no debe apuntar a una fila borrada)
--   ⚠ PRIMERO repuntar lo que apunta a este nombre (ver AFECTA); si no, se queda huérfano.
-- delete from catalogo_items where item = 'LIGHTING  RELAY' and coalesce(precio,0) = 85;

-- 10A  FUSES   [hoy: E · $8 · 0.08 h]
--   Duplicado exacto de '10A FUSES' (doble espacio, código 20-MISC, sección null).
--   Se queda la de 11-LIGHT / LIGHTING FIXTURES, donde vive el FUSE HOLDER.
--   Según cuál sobreviva el fusible cae en un capítulo u otro del presupuesto.
--   AFECTA: alias línea 103 '10A FUSES' (factor 1, unidad E) | repuntar el alias de la línea 103 a '10A FUSES' en el mismo commit
--   ⚠ PRIMERO repuntar lo que apunta a este nombre (ver AFECTA); si no, se queda huérfano.
-- delete from catalogo_items where item = '10A  FUSES' and coalesce(precio,0) = 8;

-- 20A , 4 POLES LIGHTING CONTACTOR   [hoy: E · $200 · 2 h]
--   Gemela con coma de '20A 4 POLES LIGHTING CONTACTOR' (mismos $200 / 2 h).
--   La coma no se colapsa al normalizar, así que ningún dedupe automático la pilla y el alias de la línea 110 dejaría de encontrar pareja: primero repuntar el alias, después borrar.
--   AFECTA: alias línea 110 '20A , 4 POLES LIGHTING CONTACTOR' (factor 1, unidad E) | PRIMERO repuntar el alias de la línea 110 a '20A 4 POLES LIGHTING CONTACTOR'; DESPUÉS borrar
--   ⚠ PRIMERO repuntar lo que apunta a este nombre (ver AFECTA); si no, se queda huérfano.
-- delete from catalogo_items where item = '20A , 4 POLES LIGHTING CONTACTOR' and coalesce(precio,0) = 200;

-- Patch panel 24-port Cat6   [hoy: EA · $85 · 1 h]
--   Gemela de '24-PORT PATCH PANEL' sin alias.
--   OJO, el escéptico no lo vio: SÍ está en la receta del rack IDF.
--   Antes de borrar, cambiar ese componente de la receta a '24-PORT PATCH PANEL' (que tras el arreglo lleva los mismos $85 / 1 h).
--   AFECTA: recetas (1): RACK DE COMUNICACIONES (IDF) 24 PUERTOS | repuntar el componente de la receta 'RACK DE COMUNICACIONES (IDF) 24 PUERTOS' a '24-PORT PATCH PANEL' ANTES de borrar
--   ⚠ PRIMERO repuntar lo que apunta a este nombre (ver AFECTA); si no, se queda huérfano.
-- delete from catalogo_items where item = 'Patch panel 24-port Cat6' and coalesce(precio,0) = 85;

-- ---------------------------------------------------------------------
-- BLOQUE C · SOLO MIRAR — hace falta un dato tuyo (las dos tandas)  (42)
-- ---------------------------------------------------------------------

-- 2"x 4"    BELL BOX-BOX   [hoy: E · $7.088 · 0.35 h]
--   TU EXCEL: caja 0,35 h y tapa 0,2 h son TUYOS.
--   El único ancla es que en Stuart cotizaste la combo a 0,2 h; el reparto 0,12 + 0,08 es inventado.
--   PREGUNTA: ¿la caja sola son 0,35 h, o el punto entero caja+tapa son tus 0,2 h de Stuart? Por piezas sueltas el punto sale a 0,55 h (caja 0,35 + tapa 0,2) cuando la combo y el número de Edgar dicen 0,2.
--   Se arregla la pareja a la vez: caja 0,12 + tapa 0,08 = 0,20.
--   Está en una receta y en el toolchest.
--   AFECTA: recetas (1): RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX | alias línea 7 '2"x 4" BELL BOX-BOX' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- 2"x 4"    BELL BOX-DEVICE COVER   [hoy: E · $6.51 · 0.2 h]
--   Va con la caja 2x4: misma pregunta.
--   La otra mitad de la pareja 2x4: tapa 0,2 → 0,08 (la tapa de Edgar) para que caja + tapa sumen los 0,20 h que él cobra.
--   No correr una sin la otra.
--   AFECTA: recetas (1): RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX | alias línea 9 '2"x 4" BELL BOX-DEVICE COVER' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- 4"x 4"    BELL BOX-BOX   [hoy: E · $10.66 · 0.4 h]
--   La pareja de 4x4 tiene el mismo problema (caja 0,4 + tapa 0,15 = 0,55 h contra combo 0,15 h) pero NO se copia de la 2x4: su combo está a 0,15, no a 0,2.
--   Hace falta el número de Edgar y luego tocar las tres filas de 4x4 a la vez.
--   AFECTA: recetas (1): WALL PACK EXTERIOR — EMT | alias línea 10 '4"x 4" BELL BOX-BOX' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- 4"x 4"    BELL BOX-DEVICE COVER   [hoy: E · $16.79 · 0.15 h]
--   Va con la caja de 4x4: caja + tapa deben sumar lo que Edgar cobra por el punto 4x4 (hoy la combo dice 0,15).
--   Sin su número no se toca.
--   AFECTA: alias línea 11 '4"x 4" BELL BOX-DEVICE COVER' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- TAPCON 1/4" x 1-1/4"   [hoy: E · $0.35 · 0.008 h]
--   Gemela de 'TAPCOM 1/4"' ($0,88 / 0,03 h tras el arreglo) con $0,35 / 0,008 h: mismo tornillo, dos precios, dos horas.
--   Edgar decide cuál sobrevive y con qué números; ninguna de las dos tiene alias ni receta.
--   (solo mirar: sin sentencia)

-- POKE-THRU FIRE-RATED   [hoy: EA · $185 · 1.75 h]
--   Convive con '1 GANG POKE-THRU FLOOR BOX' ($136,50 / 1,15 h) sin diámetro ni servicios que las separen: el mismo punto sale ~$70 distinto según cuál se pique.
--   No se tocan números; Edgar dice qué aparato es cada una y se renombran (o se borra esta, la de $185, que no tiene alias).
--   La heredada sí tiene alias (línea 48).
--   (solo mirar: sin sentencia)

-- FIRE PUMP ATS   [hoy: E · $0 · 4 h]
--   Pide 4 h, lo mismo que el ATS de 30A, cuando la escalera de ATS dice 8 h para 200-400A y un ATS vale el doble que el disconnect de su calibre.
--   Pero el 4 está literal en el Excel de Edgar: que él confirme el amperaje típico y ponga 8 si procede.
--   Precio $0 va por cotización.
--   AFECTA: alias línea 174 'FIRE PUMP ATS' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- OCCUPANCY SENSOR   [hoy: EA · $55 · 0.5 h]
--   Fila genérica a $55 / 0,5 h que compite con las de WIRING DEVICES que llevan los números reales de Stuart (techo $114 / 1 h, PIR $66,16 / 1,26 h) y siempre gana por barata.
--   Recomendación: borrarla (no tiene alias ni receta) o ponerla a 1 h con precio real.
--   La lente de riesgo pide no mover ningún sensor hasta que Edgar cierre las horas de Stuart.
--   (solo mirar: sin sentencia)

-- CHANDELLIER LIGHT FIXTURE   [hoy: E · $0 · 1 h]
--   OJO: la fila con doble L ES LA TUYA (Excel: $0 / 1 h, la lámpara la pone el dueño, como todas tus luminarias).
--   La de una L ($385 / 2 h) es importada.
--   NO se le pone $385 a la tuya.
--   PREGUNTA: ¿la lámpara lleva precio o va por cotización? Si va a $0, la que se borra es la importada.
--   Gemela mal escrita (doble L) de 'CHANDELIER LIGHT FIXTURE' ($385 / 2 h), a $0 / 1 h.
--   El alias de la línea 112 del plano apunta a ESTA, así que midiendo del Bluebeam la lámpara entra gratis.
--   Arreglo seguro: ponerle los números de la buena.
--   Borrarla solo después de repuntar el alias a 'CHANDELIER LIGHT FIXTURE'.
--   AFECTA: alias línea 112 'CHANDELLIER LIGHT FIXTURE' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- ULTRASONIC OCCUPANCY SENSOR WT-1105   [hoy: EA · $105 · 0.5 h]
--   Dentro de su serie WT es el único a 0,5 h (WT-605 1,05, WT-2205 1,0) siendo el segundo más caro.
--   Propuesta 1,0 h, pero la lente de riesgo pide no subir ni bajar ningún sensor hasta que Edgar cierre las horas de cuadrilla de los 15 sensores de Stuart.
--   Tiene alias.
--   AFECTA: alias línea 74 'ULTRASONIC O.S WT-1105' (factor 1, unidad EA)
--   (solo mirar: sin sentencia)

-- UPS SYSTEM 10KVA   [hoy: E · $0 · 10 h]
--   Mismo hueco que el ATS 400A: sus dos hermanas (50KVA $18.500, 100KVA $42.000) tienen precio y esta $0.
--   Pendiente de cotización: el catálogo extrapola $2.800-3.700 y el mercado $5.000-5.500, así que cualquier número sería inventado.
--   Las 10 h se dejan (posible 8 h, a criterio de Edgar).
--   AFECTA: alias línea 204 'UPS SYSTEM 10KVA' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- AIR TERMINAL BASE   [hoy: E · $0 · 0.5 h]
--   Punta $45 / 0,5 h + base $0 / 0,5 h: una de las dos miente.
--   Si los $45 de AIR TERMINAL son solo la punta → base $16 y bajar sus horas a 0,25.
--   Si los $45 incluyen la base → dejar $0 y poner 0 h.
--   La propuesta tal cual (solo precio) es la única que puede cobrar la base dos veces.
--   Pregunta para Edgar.
--   AFECTA: alias línea 278 'AIR TERMINAL BASE' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- 5/8" X 10' COPPER GROUND ROD   [hoy: E · $9.5 · 1 h]
--   Por debajo de coste hoy, pero el auditor usó precio al público ($25); a coste de contratista ronda $19.
--   Solo dentro del reprecio conjunto de las cuatro varillas y con el albarán de Edgar por delante.
--   AFECTA: alias línea 287 '5/8' X 10 COPPER GROUND ROD' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- 3/4" X 10' COPPER GROUND ROD   [hoy: E · $16 · 1.5 h]
--   $16 por una 3/4" x 10' cobreada no se compra en 2026, pero tocar solo esta ($45 del auditor, retail) deja la de 5/8" a $9,50 al lado: lista vieja pero ordenada → lista desordenada.
--   A coste de contratista ~$38, y solo con las otras tres a la vez.
--   AFECTA: alias línea 288 '3/4" X 10' COPPER GROUND ROD' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- 5/8" X 8' GALVANIZED GROUND ROD   [hoy: E · $4.95 · 1 h]
--   Cuarta varilla de la misma lista vieja ($4,95).
--   A coste de contratista ~$12, manteniéndola como la más barata de las cuatro.
--   Se corre con la familia o no se corre.
--   AFECTA: alias línea 289 '5/8" X 8' GALVAN GROUND ROD' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- 24-PORT PATCH PANEL   [hoy: E · $150 · 4 h]
--   TU EXCEL: $150 / 4 h.
--   Los $85 / 1 h son de la fila importada en minúsculas (CATV), no tuyos.
--   PREGUNTA: ¿tus 4 h incluyen ponchar los 24 puertos? Si sí, se queda como está y la que sobra es la importada (bloque B).
--   Tres números para la misma pieza: $150 / 4 h aquí, $185 / 2 h el de 48 puertos y $85 / 1 h en 'Patch panel 24-port Cat6'.
--   Las 4 h no pueden incluir las 24 terminaciones porque 'RJ45 termination' ya se cobra aparte (0,15 h).
--   Se conserva esta fila (tiene el alias) con los números de la gemela: $85 / 1 h.
--   AFECTA: alias línea 268 '24 PORT PATCH PANEL' (factor 1, unidad E)
--   (solo mirar: sin sentencia)

-- WP STROBE LIGHT W/BACKBOX   [hoy: E · $74 · 0.5 h]
--   Tu Excel trae $74 (base $59 + $15 de caja WP).
--   Pero la base ya se corrigió en la primera tanda a $99,99 (tu factura de Stuart) y la WP no puede quedar por debajo de la interior.
--   Base real + prima outdoor ($30-40 a coste de suministro) = ~$135, número derivado sobre un precio tuyo, por eso pregunta.
--   Misma pregunta para WP HORN/STROBE LIGHT W/BACKBOX ($102 frente a los $137,99 reales del HORN/STROBE).
--   AFECTA: alias_takeoff.csv línea 217 'WP STROBE LIGHT W/BACKBOX' (factor 1, unidad E) | alias-supabase 'WP STROBE LIGHT W/BACKBOX' (factor 1, auto-match toolchest)
--   (solo mirar: sin sentencia)

-- 2" SHUT-OFF GAS VALVE   [hoy: E · $285 · 1.3 h]
--   Tu Excel: 3/4" $165 / 1" $225 / 2" $285, +$60 por escalón.
--   El 3/4" cuadra con un solenoide de gas 120V, pero un cuerpo de 2" de esa clase (ASCO 8214, Ansul MGV) no baja de $650-900.
--   $750 es orden de magnitud con confianza baja: pide cotización; si no la cotizas, mejor $0 (salta falta_precio) que $285.
--   Las 1,3 h se quedan (la tubería la rosca el plomero).
--   AFECTA: alias_takeoff.csv línea 238 '2" SHUT-OFF GAS VALVE' (factor 1, unidad E) | alias-supabase '2" SHUT-OFF GAS VALVE' (factor 1, auto-match toolchest)
--   (solo mirar: sin sentencia)

-- CONCRETE PULL BOX .BROOK #36   [hoy: E · $65 · 2 h]
--   La misma pieza está dos veces con dos precios tuyos: 'BROOK # 36 PULL BOX' (UNDERGROUND) a $85 y esta a $65, ambos en tu Excel.
--   El alias del toolchest apunta a esta.
--   PREGUNTA: ¿cuál vale? Si es $85, igualar; si quieres precio 2026, es cotización de prefabricado con flete, no un número de internet (Ferguson/Jensen dan 'call for price').
--   AFECTA: alias_takeoff.csv línea 101 'CONCRETE PULL BOX .BROOK #36' (factor 1, unidad E) | alias-supabase 'CONCRETE PULL BOX .BROOK #36' (factor 1, auto-match toolchest)
--   (solo mirar: sin sentencia)

-- 1/2" X 10' COPPER GROUND ROD   [hoy: EA · $8.5 · 1 h]
--   Estaba en 'mirar' sin número.
--   $17 (coste de contratista; Erico $27,49 al público) encaja en la escalera ya propuesta para la familia: galvanizada 8' $12 < 1/2" 10' $17 < 5/8" 10' $19 < 3/4" 10' $38; el $22 que se sugirió de pasada NO sirve (invertiría la escala).
--   El $8,50 / 1 h de hoy ya no es el de tu Excel ($8 / 0,5 h).
--   Las cuatro varillas se reprecian juntas con tu albarán.
--   AFECTA: alias_takeoff.csv línea 286 '1/2" X 10' COPPER GROUND ROD' (factor 1, unidad EA) | alias-supabase '1/2" X 10' COPPER GROUND ROD' (factor 1, auto-match toolchest)
--   (solo mirar: sin sentencia)

-- 5/8" GROUND ROD CLAMP   [hoy: E · $0.75 · 0.3 h]
--   Tu Excel trae la escala invertida (1/2" $0,85 / 5/8" $0,75 / 3/4" $1,25) como plantilla sin usar (cantidad 0 en los tres presupuestos).
--   Una acorn de bronce de 5/8" vale $2,25-3,50 en suministro, y 0,3 h por apretarla es más que tu single pole switch (0,2).
--   PREGUNTA: ¿$2,75 y 0,15 h? Si sí, corregir la familia a la vez: 1/2" ~$2,40 y 3/4" ~$3,40, las tres a 0,15 h.
--   AFECTA: alias_takeoff.csv línea 291 '5/8" GROUND ROD CLAMP' (factor 1, unidad E) | alias-supabase '5/8" GROUND ROD CLAMP' (factor 1, auto-match toolchest)
--   (solo mirar: sin sentencia)

-- 1/2"       EMT S.S.  STEEL CONNECTOR   [hoy: E · $0.15 · 0.06 h]
--   Tu Excel trae el de acero a $0,15, más barato que su gemelo die-cast ($0,266), y el acero siempre es el caro (tu propio bloque de compresión lo respeta: D/C $0,174 vs STEEL $0,28).
--   Los STEEL de tornillo son lista vieja redonda.
--   $0,43 = D/C x1,6 es derivado, por eso pregunta.
--   Ninguna receta usa la familia STEEL (las 28 de 1/2" usan D/C): solo afecta a lo que se elige a mano.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- 1/2"       EMT S.S.  STEEL  COUPLING   [hoy: E · $0.16 · 0.04 h]
--   Mismo vuelco: acero $0,16 vs die-cast $0,306 en tu Excel, y se repite en 3/4" y 1".
--   $0,39 = D/C x1,26 (la razón que ya guarda tu bloque de compresión).
--   Derivado, sin cotización: pregunta.
--   Sin recetas encima.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- 3/4"       EMT ELBOW   [hoy: E · $1.27 · 0.09 h]
--   El codo de 3/4" ($1,27, redondo, lista vieja) cuesta menos que el de 1/2" ($1,313): único escalón invertido de la familia por abajo.
--   $1,55 es conservador (suministro $1,50-2,00).
--   Es tu número del Excel y el nuevo es derivado, por eso pregunta; lo usan 2 recetas (1 y 2 unidades), poco dinero.
--   AFECTA: recetas (2): CONDUIT VACÍO 3/4" PARA BAJO VOLTAJE — EMT; HOMERUN 20A AL PANEL — EMT
--   (solo mirar: sin sentencia)

-- 3-1/2"    EMT POWER STRAP   [hoy: E · $1.2 · 0.07 h]
--   En una serie de 10 filas a cuatro decimales, $1,20 y $1,50 (3-1/2" y 4") son los únicos redondos y quedan por debajo del 3" ($2,1378).
--   UM cotizó 50 unidades a $1,20.
--   $2,60 (3" x1,2, el paso medio de la serie) es provisional: como mínimo no puede quedar por debajo del 3".
--   Confirmar con proveedor.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- 4"           EMT POWER STRAP   [hoy: E · $1.5 · 0.08 h]
--   Mismo caso: $1,50 redondo por debajo del 3" ($2,1378).
--   UM cotizó 6 unidades.
--   $3,20 (un paso x1,23 sobre el 3-1/2" corregido), provisional; confirmar con proveedor.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- 24"x24"x24" PULL BOX NEMA-3R   [hoy: E · $80.787 · 3 h]
--   $80,79 es 1/5 de la '18"x18"x18" PULL BOX NEMA-3R' ($385) y 1/8 de la misma caja en 4R ($674): el número de tu Excel casi seguro es de una caja 24x24 de fondo bajo, no un cubo.
--   Entra desde el plano (alias + toolchest Pull Boxes).
--   Piso $385, techo $674: $400 provisional; el $210 del auditor la dejaría por debajo de la 18".
--   AFECTA: alias_takeoff.csv línea 27 '24"x24"x24" PULL BOX NEMA-3R' (factor 1, unidad E) | alias-supabase '24"x24"x24" PULL BOX NEMA-3R' (factor 1, auto-match toolchest) | toolchest grupo Pull Boxes
--   (solo mirar: sin sentencia)

-- 36"x36"x36" PULL BOX NEMA-3R   [hoy: E · $102.9 · 4 h]
--   La caja más grande de la familia a $102,90, por debajo de la 18" 3R ($385) y a 1/8 de la 36" 4R ($834).
--   Con la 24" en $400 y el paso 24→36 de tu propia serie 4R (x1,24) salen ~$500, provisional; confirmar con proveedor.
--   Las 4 h se quedan.
--   AFECTA: alias_takeoff.csv línea 28 '36"x36"x36" PULL BOX NEMA-3R' (factor 1, unidad E) | alias-supabase '36"x36"x36" PULL BOX NEMA-3R' (factor 1, auto-match toolchest) | toolchest grupo Pull Boxes
--   (solo mirar: sin sentencia)

-- 4" X 3½"D    CONCRETE RING   [hoy: E · $0.683 · 0.03 h]
--   Tu Excel le da 0,03 h (1,8 min) a alinear y atornillar la extensión de 3½" sobre el CONCRETE BOX ASSEMBLIE, menos que un plaster ring de pared (0,05) y que una tapa (0,08); sus primas de hormigón llevan 0,08 h.
--   Es subir una hora tuya, por eso pregunta.
--   No es duplicado del '4" ADAPTER RING CONCRETE BOX': son piezas distintas.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- 6"         PVC FEMALE ADAPTER   [hoy: E · $2.468 · 0.055 h]
--   Copia exacta del 5" ($2,468 a tres decimales), también en tu Excel.
--   El 6" COUPLING ya quedó en la primera tanda a $8,50 (1,8x su 5"); el mismo 1,8x da $4,45 y deja los tres 6" con un solo criterio (adaptador PVC 5" ~$14-16 vs 6" ~$25-28 al detalle, relación 1,7-1,8).
--   Estaba en 'mirar' sin número; horas 0,055 se quedan.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- 6"         PVC CONNECTOR   [hoy: E · $3.15 · 0.055 h]
--   Tercer par 5"/6" idéntico ($3,15 = $3,15) de tu Excel; la escalera sube sin parar hasta el 5" y se aplana solo en el 6".
--   3,15 x 1,8 = $5,65, el mismo factor del COUPLING ya sellado.
--   Estaba en 'mirar' sin número.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- # 6 RE-BAR   [hoy: LF · $0.37 · 0.03 h]
--   $0,37/ft es precio de barra #3; la #6 pesa 2,04 lb/ft y a $0,37 saldría a $0,18/lb, por debajo del acero en acería de cualquier año.
--   Tienda 2026 ~$1,14/ft y tu bloque civil va un 10-15% por debajo del detalle: ~$1,00.
--   Provisional hasta que mires tu última factura de varilla.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- 1 1/4"  PVC COUPLING   [hoy: E · $1.28 · 0.03 h]
--   Las columnas de 3/4" y 1-1/4" de tu Excel entraron a precio de TIENDA (coupling 1-1/4" ~$1,10-1,30 al detalle) mientras el resto de la familia está al 0,25-0,30 del detalle.
--   Con ese factor sale $0,28-0,35; la media geométrica entre 1" ($0,17) y 1-1/2" ($0,37) da $0,25.
--   Estaba en 'mirar' sin número.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- 1 1/4"  PVC CONNECTOR   [hoy: E · $1.45 · 0.03 h]
--   Misma columna de 1-1/4" a detalle: $1,45 entre el 1" ($0,32) y el 1-1/2" ($0,48).
--   Detalle ~$1,40 x 0,3 = $0,42; media geométrica $0,40.
--   Estaba en 'mirar' sin número.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- 3/4"     PVC ELBOW   [hoy: E · $1.47 · 0.18 h]
--   El codo de 3/4" ($1,47, precio de detalle) cuesta más que el de 1" ($0,92) y casi lo mismo que el de 2" ($1,70).
--   La familia sana está al ~0,40 del detalle: 1,45 x 0,42 = $0,61; la media geométrica 1/2"-1" da $0,60.
--   Es tu número del Excel, por eso pregunta.
--   El 5" ELBOW a $10 NO es hallazgo (el paso 4"→5" de 1,08 se repite en toda la familia).
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- 3/4"     PVC COUPLING   [hoy: E · $0.46 · 0.02 h]
--   $0,46 con el 1/2" a $0,08 y el 1" a $0,17: precio de tienda del coupling de 3/4".
--   Al factor 0,25-0,30 de la familia salen $0,11-0,14.
--   De paso mira el '3/4" PVC CONNECTOR' ($0,61): misma cura, le tocaría ~$0,20.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- CUT, REMOVE & PATCHING CONCRETE   [hoy: LF · $4 · 0.02 h]
--   0,02 h/LF (72 segundos) para dos cortes de sierra, romper, sacar escombro, encofrar, vaciar y acabar un pie de losa: solo el vaciado ya se lleva 0,004 h con tu CONCRETE # 3000.
--   Es tu número del Excel y la hermana ASPHALT va igual (0,02), por eso pregunta.
--   0,15 h/LF con tu base magra (7-8 min por pie); el 0,25 del auditor es RSMeans con cuadrilla completa.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- # 4/0   XHHW STRANDED ALUMINUM COMPACT   [hoy: MLF · $646.09 · 26 h]
--   La familia XHHW de aluminio entera está a mitad de mercado: 3,05 $/kcmil-ft frente a 36 del cobre (que sí está verificado con lo que pagaste en UM), ratio 12x cuando lo real es ~6x.
--   4/0 AL publicado sep-2026 $2,18/ft; tu $0,646 es el 30%.
--   $1.100/MLF (~50% del publicado) es piso provisional: no hay factura tuya de aluminio (UM/Stuart/DTCC solo compraron cobre).
--   Es el alimentador de 200A: pide cotización.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- # 500    MCM XHHW STRANDED ALUMINUM COMPACT   [hoy: MLF · $1428.35 · 36 h]
--   Misma familia: $1,43/ft es el 37% del publicado ($3,85/ft).
--   $2.500/MLF es ~65% del publicado, coherente con neto de distribuidor.
--   PROVISIONAL hasta cotización; unidad MLF y 36 h no cambian.
--   Es el que más dinero mueve de la tanda (alimentador de 400-600A, 4 hilos).
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- # 1/0    XHHW STRANDED ALUMINUM COMPACT   [hoy: MLF · $396.16 · 20 h]
--   Publicado sep-2026 $1,36/ft; tu $0,396 es el 29%.
--   Contra tu '# 1/0 THHN STRANDED CU.' (pagado tal cual en UM) el ratio Cu:Al es 9,7x.
--   $600/MLF (44%) es piso conservador.
--   Provisional; misma cotización que el 4/0.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- # 2/0   XHHW STRANDED ALUMINUM COMPACT   [hoy: MLF · $468.19 · 22 h]
--   Publicado $1,38-1,73/ft; tu $0,468 es el 29-34%.
--   $730/MLF (45-53%).
--   Provisional.
--   El resto de la familia XHHW AL tiene el mismo defecto y va en la misma cotización.
--   AFECTA: nadie (ni recetas ni alias)
--   (solo mirar: sin sentencia)

-- 18/2 SHIELDED FIRE ALARM CABLE   [hoy: MLF · $60 · 8 h]
--   PREGUNTA.
--   El catálogo lo tiene a $60 el millar; en el bid de Stuart lo pusiste a $0,26 el pie, que son $260 el millar.
--   Cuatro veces.
--   Lo llevan 8 recetas de fire alarm (0,025 MLF cada una: $1,50 contra $6,50 por punto).
--   ¿Cuál es el bueno?.
--   AFECTA: recetas (8): las de fire alarm
--   (solo mirar: sin sentencia)

-- ---------------------------------------------------------------------
-- ALTAS · 22 FILAS QUE FALTAN EN EL CATÁLOGO (comentadas: dalas tú con tu precio)
-- ---------------------------------------------------------------------
-- Ninguna existe hoy (se buscaron en las 1.084 filas, con espacios y mayúsculas
-- colapsados). Sin ellas hay puntos que se cotizan incompletos. El origen del
-- precio va en cada una: «edgar» sale de tu Excel o de Stuart; «mercado» es
-- referencia de proveedor, no factura; «cotizacion($0)» sigue tu regla de la
-- casa para equipo grande; «derivado» es la escalera de la familia.

-- DEMO - Boxes  · origen del precio: edgar
--   Tu Excel (fila 1024) trae 'REMOVE BOXES' | DEMOLITION | E | 0,1 h junto a REMOVE DEVICES 0,15 (que sí pasó como DEMO - Receptacles / DEMO - Switches); el porte perdió la fila.
--   No hay demolición de cajas en ninguna sección ('Demo Old Wiring/Splice' es otra cosa).
--   Alta con el patrón de sus 8 hermanas DEMO, $0 de mano de obra pura.
--   Tu Excel también perdió 'REMOVE LIGHTING FIXTURE POLE' (2 h): ver nota en resumen.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo, cero_motivo) values ('DEMO - Boxes', 'DEMOLITION', 'EA', 0, 0.1, '01-DEMO', 'solo_labor');

-- G 3000 WIREMOLD INSTALATION 3 STATION  · origen del precio: edgar
--   Tu Excel (fila 538) trae 'G 3000 WIREMOLD INSTALATION 3 STATION' | U | $159,60 | 6,4 h y docs/takeoff/catalogo_codigos.csv sigue listándola (09-COND); el porte a Supabase la perdió y hoy solo queda la de 6 STATION.
--   Se recupera con tus números.
--   Lo que NO se hace es crear base/tapa/codo G 3000 sueltos: tu Excel tampoco los tuvo y sería una familia de precio inventado.
--   (Tu Excel también tenía 'G 4000 WIREMOLD INSTALATION 3 STATION', ver nota en resumen.).
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('G 3000 WIREMOLD INSTALATION 3 STATION', 'RACEWAY', 'U', 159.6, 6.4, '09-COND');

-- POWER SUPPLY (ACCESS CONTROL)  · origen del precio: edgar
--   Tu Excel (fila 913) trae 'POWER SUPPLY' | SECURITY & ACCESS CONTROL | E | $0 | 2 h.
--   El porte guardó las otras tres POWER SUPPLY con paréntesis (FIRE ALARM $385, INTERCOM $145, CCTV $95) y perdió esta por nombre duplicado.
--   Una puerta de acceso no se cotiza entera sin su fuente con batería.
--   $0 con horas en esta sección es tu regla de 'suministro' (chip con ?); los $320 / 1,5 h del auditor eran de internet y apagarían ese aviso.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo, cero_motivo) values ('POWER SUPPLY (ACCESS CONTROL)', 'SECURITY & ACCESS CONTROL', 'E', 0, 2, '13-LV', 'suministro');

-- 2"           PVC  SLEEVE  · origen del precio: edgar
--   Tu Excel (fila 133) trae '2" PVC SLEEVE' | E | $1,943 | 0,095 h entre el 1" y el 3", y el porte a Supabase la perdió (hoy hay 1", 3" y 4").
--   Alta con tus números tal cual.
--   El nombre lleva el mismo relleno de espacios que sus hermanas ('1" PVC SLEEVE') para que agrupe con ellas; la app normaliza espacios.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('2"           PVC  SLEEVE', 'UNDERGROUND', 'E', 1.943, 0.095, '03-UG');

-- 2G PLASTIC COVER SWITCH  · origen del precio: edgar
--   No hay ninguna tapa de 2 posiciones en Supabase (hay caja y anillo hasta 5 gang, tapa solo 1G), pero la fila SÍ existe en tu Excel (fila 803: E, $0,63, 0,1 h) y se perdió al importar.
--   Alta con tus números, no con los $0,45 escalados del auditor.
--   No hace falta inventar 3G/4G: no las tienes y ninguna receta ni alias las pide.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('2G PLASTIC COVER SWITCH', 'WIRING DEVICES', 'E', 0.63, 0.1, '10-DEV');

-- 2G STEEL COVER  · origen del precio: edgar
--   Tu Excel (fila 807) trae '2G STEEL COVER' | E | $1,50 | 0,15 h y también se perdió en el porte (hoy solo hay '1G STEEL COVER').
--   Se recupera en el mismo movimiento que la tapa de plástico 2G.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('2G STEEL COVER', 'WIRING DEVICES', 'E', 1.5, 0.15, '10-DEV');

-- CABLE TESTING / CERTIFICATION (per point)  · origen del precio: solo_labor($0)
--   Solo hay FIRE ALARM TESTING (8 h), F/A INSPECTION & CERTIFICATION (4 h), SOUND SETUP & TESTING (8 h) y GROUND TESTING (2 h); nada para certificar cableado estructurado ni coaxial, aunque el lote tiene toda la cadena (RJ45, patch panel, PoE, racks).
--   Mano de obra pura: $0 con horas es tu convención solo_labor (como FIRE ALARM TESTING).
--   0,1 h por punto (autotest, etiqueta, guardar), coherente con RJ45 termination 0,15 h.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo, cero_motivo) values ('CABLE TESTING / CERTIFICATION (per point)', 'CATV', 'E', 0, 0.1, '13-LV', 'solo_labor');

-- AUTOMATIC TRANSFER SWITCH 1200A  · origen del precio: cotizacion($0)
--   El ATS más grande es 1000A y el generador de 800KW (1.000 kVA a 480V = 1.203 A) necesita 1200A: no hay ATS por encima de 1000A en ninguna sección.
--   Los $25.000 del auditor eran proyección: ATS va por cotización (el 400A del 14/09 entró igual a $0).
--   28 h siguen tu escalera viva (600A 16, 800A 20, 1000A 24).
--   Confianza baja: un 800KW suele alimentar varios ATS y hoy el alias 'AUTO.
--   TRANS.
--   SW.
--   1200A' caería en sin-pareja, que la app ya avisa.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo, cero_motivo) values ('AUTOMATIC TRANSFER SWITCH 1200A', 'GENERATOR + ATS + UPS', 'E', 0, 28, '15-GEN', 'falta_precio');

-- GENERATOR STARTUP & LOAD BANK TEST  · origen del precio: cotizacion($0)
--   Ocho generadores y ocho ATS y ninguna línea de puesta en marcha ni prueba de banco de carga (NFPA 110 exige prueba presenciada).
--   El patrón de labor puro a $0 ya existe (FIRE ALARM TESTING, GROUND TESTING).
--   16 h = atención de tu cuadrilla (cableado temporal del banco, dos hombres el día); el $0 dispara falta_precio para el alquiler del banco, que va a cotización.
--   El startup del fabricante va dentro de la cotización del generador.
--   En el 22KW residencial la cantidad sería 0.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo, cero_motivo) values ('GENERATOR STARTUP & LOAD BANK TEST', 'GENERATOR + ATS + UPS', 'E', 0, 16, '15-GEN', 'falta_precio');

-- RA3 Sunnata Keypad  · origen del precio: cotizacion($0)
--   No hay ningún keypad de ninguna marca en el catálogo (el 'KEY PAD' de security del Excel tampoco pasó el porte) y symbols.js define lut_kp2/kp4/kp5/kp6 para dibujarlos.
--   El auditor no separó su precio del del dimmer y no hay número verificado: $0 con falta_precio hasta que pongas tu tarifa; 0,5 h como el dimmer.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo, cero_motivo) values ('RA3 Sunnata Keypad', 'LUTRON', 'EA', 0, 0.5, '11-LIGHT', 'falta_precio');

-- Bond & Insurance (per job)  · origen del precio: cotizacion($0)
--   El bloque JOB EXPENSES de tu Excel de bids (Stuart fila 1040) lleva 'BOND & INSURANCE' junto a PERMIT & FEES, TRAVEL, DUMPSTERS y TEMPORARY POWER, y el porte trajo todas como filas de PROJECT GENERAL menos esta.
--   Un % del contrato no cabe en el catálogo (cantidad x precio necesita el total, que no existe hasta el final: eso va en escenarios, como tax y overhead).
--   Lo que cabe es lo que hacía tu Excel: un placeholder que se teclea por obra.
--   Confianza baja.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo, cero_motivo) values ('Bond & Insurance (per job)', 'PROJECT GENERAL', 'EA', 0, 0, '20-MISC', 'falta_precio');

-- BREAKER 3P 20A  · origen del precio: cotizacion($0)
--   No hay ni un breaker de 3 polos de ramal en las 1.084 filas (solo 1P, 2P, tandem, GFCI/AFCI y los 3P MAIN CB), aunque el catálogo cotiza PANELBOARD 277/480V 3-PHASE.
--   Los $95 del auditor eran de internet: en obra trifásica los breakers de ramal vienen dentro de la cotización del tablero, por eso va a $0 junto a los 3P MAIN CB (regla de la casa).
--   Si lo quieres, conviene la escalerita 3P 20/30/50/100A.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo, cero_motivo) values ('BREAKER 3P 20A', 'SWITCHGEAR', 'E', 0, 0.4, '05-PANEL', 'suministro');

-- F CONNECTOR RG6  · origen del precio: mercado
--   El único conector coaxial del catálogo es 'BNC CONNECTORS' (cámara analógica); no hay F para TV/satélite en ninguna sección.
--   Mercado 2026: IDEAL OmniConn compresión RG6 $1,04-1,16 la pieza.
--   0,05 h en la escala de 'RJ45 termination' (0,15 h).
--   La receta 'SALIDA DE TV / COAX — EMT' ya dice que le falta y mete 2 BNC como parche.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('F CONNECTOR RG6', 'CATV', 'E', 1.1, 0.05, '13-LV');

-- Cat6 patch cord 3 ft  · origen del precio: mercado
--   PATCH|CORD|JUMPER en todo el catálogo solo devuelve los patch panels: no hay latiguillo en ninguna sección, y la receta 'RACK DE COMUNICACIONES (IDF) 24 PUERTOS' monta patch panel + switch sin nada que los una.
--   $2,50 es precio de contratista y la escala de 'RJ45 termination' ($2,50).
--   Si IT lo suministra, se pone a $0 en ese bid como ya hace la receta con el switch.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('Cat6 patch cord 3 ft', 'CATV', 'EA', 2.5, 0.02, '13-LV');

-- GENERATOR INLET BOX + INTERLOCK KIT 50A  · origen del precio: mercado
--   No hay INLET, INTERLOCK ni MANUAL TRANSFER en ninguna sección; lo más cercano son receptáculos hembra (NEMA 14-50R, 50A RECEPTACLE).
--   Es el trabajo residencial post-huracán más corriente de Tampa.
--   Inlet 50A tipo Reliance/Generac ~$130 + kit de enclavamiento de marca $60-90 = $250 (los $320 del auditor iban altos).
--   3 h como el cargador EV enchufable del mismo lote.
--   El BREAKER 2P 50A ($26 / 0,3 h) ya existe y se cuenta aparte.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('GENERATOR INLET BOX + INTERLOCK KIT 50A', 'GENERATOR + ATS + UPS', 'EA', 250, 3, '15-GEN');

-- 5/8" X 8' COPPER GROUND ROD  · origen del precio: mercado
--   Buscado 'ROD' en las 1.084 filas: NO existe ninguna varilla cobreada de 8', el electrodo estándar de toda acometida en Florida (solo 1/2", 5/8" y 3/4" en 10' y la 8' galvanizada).
--   Y el alias de plano 'Ground Rods (2)' (factor 2) apunta HOY a la galvanizada de $4,95: cada par de varillas de acometida entra como galvanizada barata.
--   ~$18 a coste de contratista, 1 h como sus hermanas; queda entre la 1/2" 10' ($17) y la 5/8" 10' ($19) propuestas.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('5/8" X 8'' COPPER GROUND ROD', 'LIGHTNING PROTECTION & GROUNDING', 'E', 18, 1, '07-GND');

-- GROUND ENHANCEMENT MATERIAL (BAG)  · origen del precio: mercado
--   GEM|BENTON|ENHANCE|BACKFILL no devuelve nada útil en las 1.084 filas: no hay relleno conductivo, y el CHEM-ROD GROUND ROD ($485) no se clava, va en barreno de 6" x 10' que hay que rellenar (~110 lb ≈ 5 sacos de 25 lb; contar 4-8 por varilla).
--   nVent ERICO GEM25A desde $48,24 en casa de suministro: ~$55.
--   Sin esta fila el relleno sale de tu bolsillo.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('GROUND ENHANCEMENT MATERIAL (BAG)', 'LIGHTNING PROTECTION & GROUNDING', 'EA', 55, 0.2, '07-GND');

-- RA3 Sunnata RF Dimmer  · origen del precio: mercado
--   La sección tiene el encabezado RadioRA 3 y el procesador ($850) pero ni un dimmer ni keypad RA3: hoy un plano RA3 solo puede cotizarse con Caseta ($58), que no funciona en RA3, y js/symbols.js ya define lut_dim sin fila a la que llegar.
--   RRST-PRO-N-WH $150-201 en web (sept 2026): $195 es placeholder honesto hasta que pongas tu tarifa de Blue Star.
--   0,5 h como el Caseta dimmer.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('RA3 Sunnata RF Dimmer', 'LUTRON', 'EA', 195, 0.5, '11-LIGHT');

-- WP IN-USE COVER 1G  · origen del precio: mercado
--   No existe en ninguna sección ni en tu Excel: las únicas 'WP .
--   COVERS' son de FIRE ALARM (tapas de dispositivo de alarma).
--   El código (NEC 406.9(B)) la obliga en toda toma exterior en Florida y el proyecto ya lo sabe: la receta 'RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX' avisa 'no es la tapa in-use de burbuja' y los alias 'Weatherproof Receptacle' y 'Weatherproof Switch SWP' llevan la nota 'agregar WP cover'.
--   Tapa in-use 1G $10-18 retail ($14 en medio); 0,15 h como las tapas de bell box (0,15-0,2).
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('WP IN-USE COVER 1G', 'WIRING DEVICES', 'EA', 14, 0.15, '10-DEV');

-- 6"         PVC ELBOW  · origen del precio: derivado
--   De 6" existen tubo SCH 40, COUPLING, CONNECTOR y FEMALE ADAPTER pero no hay codo, end bell ni spacer en ninguna sección: un banco de ductos de 6" no se cotiza entero.
--   El escéptico confirmó el hueco pero no dio números; estos son derivados: 5" ELBOW $10 x 1,8 (el factor 5"→6" con que se selló el 6" COUPLING) = $18, horas +0,1 sobre el 5" (0,6) como el paso 4"→5".
--   PROVISIONAL: confirmar con proveedor.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('6"         PVC ELBOW', 'UNDERGROUND', 'E', 18, 0.7, '03-UG');

-- 6"         PVC END BELL  · origen del precio: derivado
--   Mismo hueco: la familia END BELL para en 5" ($4,725 / 0,4 h).
--   4,725 x 1,8 = $8,50; horas 0,5 (la escalera de horas de la familia va 4" 0,5 / 5" 0,4, irregular; se toma el mayor).
--   PROVISIONAL: confirmar con proveedor.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('6"         PVC END BELL', 'UNDERGROUND', 'E', 8.5, 0.5, '03-UG');

-- 6"         PVC SPACER  · origen del precio: derivado
--   La familia SPACER para en 5" ($1,323 / 0,18 h) y sube x1,25 por escalón (4" $1,061 → 5" $1,323): 6" ~$1,65 y 0,22 h.
--   PROVISIONAL, derivado de la escalera; confirmar con proveedor.
-- insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo) values ('6"         PVC SPACER', 'UNDERGROUND', 'E', 1.65, 0.22, '03-UG');

-- ---------------------------------------------------------------------
-- COMPROBAR (después del bloque A)
-- ---------------------------------------------------------------------
-- select item, unidad, precio, horas_unidad from catalogo_items
--  where item in ('6" GRS CONDUIT', '1/2"       LOCKNUT', '1 1/2"  LIQUIDTIGHT CONDUIT', '2"        LIQUIDTIGHT CONDUIT', '2 1/2"  LIQUIDTIGHT CONDUIT', '3"        LIQUIDTIGHT CONDUIT', '3 1/2"  LIQUIDTIGHT CONDUIT', '4"x 4"    BELL BOX-BOX AND DEVICE COVER', '2"x 4"    BELL BOX-BOX AND DEVICE COVER', '6"x6"x10'' WIREWAY NEMA-3R', 'G 4000  WIREMOLD COVER', 'G 4000  WIREMOLD DIVIDER', 'START/STOP PUSH BUTTON', '# 500   MCM THW CU.', '# 600   MCM THW CU.', '14/4 FPL WET LOC. AQ-246', 'STROBE LIGHT W/BACKBOX', 'HORN/STROBE LIGHT W/BACKBOX', 'WP DEVICES COVERS', 'DEVICES COVERS', 'THREE POLE SWITCH', 'FOUR WAY SWITCH', '15A DUPLEX TAMPER RESISTANT', '20A SINGLE RECEPTACLE USB', '3" CONDUIT GROUNDING CLAMP', 'RG6 TV CABLE', 'CAT6 CABLE', 'CAT6A CABLE', '2" CABLE TO STRUT SUPPORT', 'DEMO - Wire Removal (per LF)', 'DEMO - Conduit Run (per LF)', 'MAIN CONDUCTOR', 'JB 1900 DEEP BOX')
--  (incluye el A y el A2)
--  order by item;
