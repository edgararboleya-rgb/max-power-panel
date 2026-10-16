# Producción, 15-oct-2026: la ronda 5 de c6 (y el c1 de 90 cuentas, el c4 de la 2540 corriente) pegada

Lo pegado por Edgar en el SQL Editor (registros de Postgres de Supabase,
hora de Miami): `c1-plan-de-cuentas.sql` 19:36, `c4-estados.sql` 19:37 (y
otra vez a las 19:38: el portapapeles seguía con c4 cuando creyó pegar la
parte 1 de c6; c4 es idempotente y no pasó nada), `c6-banco-parte2.sql`
19:39 (paró sola con su guarda, MX000: «antes va la parte 1 de esta misma
versión… la base tiene el banco de la marca 2026100303»; no tocó nada),
`c6-banco-parte1.sql` 19:44 («c6 · parte 1 de 2» en `true`) y
`c6-banco-parte2.sql` 19:45 (sus 7 filas en `true`). Los archivos son los
del commit 06e9e0c (la ronda 5 corregida tras sus dos verificaciones).

Marcas después del pegado: c1 90 cuentas, c2 2026100201, c3 2026092601, c4
**2026100901**, c6 **2026100901**. `prestamos.cuotas_al_anio` existe;
`fn_prestamo_cuota_anular` existe y sin grant a la API (SQL Editor).

Lo que enseñó cada pegado: c1, la tabla de 90 filas (de la 1010 a la 9000,
con 2540 y 2550); c4, sus 9 filas («c4 · mapeo»: «90 cuentas con su fila;
sin fila: ninguna; guardadas distintas de lo que c4 propone (manda lo
guardado): ninguna»; «c4 · jit» en `true`; en `false` solo «c4 · apertura» y
«cuadre: apertura en el libro», lo esperado sin apertura); la parte 1 de c6,
su fila en `true`; la parte 2, las 7 de siempre: 14 tablas, 8 vistas, 21
funciones de la app, en el reparto de c2, `v_banco_saldos` 4 filas,
protecciones del banco «bien», c2, c3 y c4 al día «bien».

Leído después en producción (solo lectura): `fn_verificar_cadena` 10 de 10,
`fn_banco_control('hoy')` todo en verde, `fn_estados_control('hoy')` con su
único rojo esperado («cuadre: apertura en el libro»). La base sin uso del
banco todavía: 0 movimientos, 0 préstamos. En los registros de Postgres,
ningún error aparte del MX000 de la guarda de la parte 2 (la parte 2 antes
que la 1) y un 42703 de una consulta de lectura mía.

La guarda de la parte 2 hizo exactamente lo que debía: con la parte 1 sin
pegar, paró sin tocar nada y dijo qué pegar.

Las suites, esa misma noche (hora de Miami): `c6-pruebas.sql` a las 19:51,
**160 de 163** en `true` (`pruebas.c6_resultado`): en rojo la 83, la 84 y la
106, las tres por lo mismo y no por c6: un ticket DE VERDAD de Edgar (el
recibo 55, Home Depot, 114.47 del 2-oct, con su tarjeta ····7930 sin dar de
alta) esperaba en la bandeja de los puentes, y la regla del banco se lo
proponía a los cargos de prueba de THE HOME DEPOT por 107.00 («su ticket ya
está subido y espera en la bandeja de los puentes»: a menos del 12 % y con el
mismo nombre). La regla está bien; las pruebas no medían lo suyo. Se
reprodujo en el banco de pruebas con un ticket igual (160/163, las mismas
tres) y se corrigió en `c6-pruebas.sql`: los comercios de las pruebas son
inventados («C6 PRUEBAS FERRETERIA») y, por el monto exacto del cargo
(107.00), las tres salen «omitida» y lo dicen; con la corrección, sobre esa
misma base 163/163, y de cero en 16 y 17.6 163/163. `c4-pruebas.sql` a las
19:52: a los 3 min 35 s el SQL Editor enseñó «Failed to fetch» y, esta vez,
Postgres anotó «FATAL: connection to client lost» y deshizo la corrida
entera (`pruebas.c4_resultado` siguió con la del 5-oct); el 5-oct la misma
corrida había sobrevivido al mismo error del editor. Queda anotado en el
README §0 (paso 10). El bloque 1 de la apertura (`apertura-1-mapeo.sql`),
a las 20:0x: 65 filas de mapeo, la 2540 en pasivo circulante y la 2550 a
largo plazo, el proveedor de la cuenta por pagar dado de alta, «cuadre:
mapeo completo» en `true`.

En la bandeja de los puentes de producción, ese día, dos papeles de verdad
esperando a Edgar (no son de esta entrega): el recibo 55 (su tarjeta ····7930
no está dada de alta: `fn_tarjeta_alta`) y la factura #MXP-METRONPR-M1 a un
contratista (sin decir cuánto retiene el cliente: `update facturas set
retencion = … where id = 67`).

`c6-pruebas.sql` otra vez, con el archivo corregido, a las 21:41: **162 de
163**, con la 83, la 84 y la 106 ya en `true`; en rojo la **157** (L15), y
otra vez por un dato de verdad, no por c6: el bloque 1 de la apertura
(20:0x) mapeó «Business Gold Card (1007)» a la Gold (2100-2013), y desde
entonces ····1007 SÍ se conoce (la regla de la 4c: el número entre
paréntesis del nombre de QuickBooks), así que `fn_banco_numero_de('1007')`
da la Gold y darla de alta como personal es MX004, con razón. La prueba
suponía que ····1007 no se conocía; usa desde hoy «1066» (y sale «omitida»
si alguna cuenta real lo tuviera). A las 19:51 la 157 había salido en
`true`: el bloque 1 aún no estaba.

## 16-oct: la apertura posteada

Con la balanza de arreglos-5 (Cowork, 15-oct por la noche; sus cifras y los
reportes quedan en el Drive de Edgar, no aquí), los bloques 2 a 5 y las dos
líneas pendientes se probaron de cero en el banco (16 y 17.6, también con
papeles de octubre ya en el libro antes de la apertura, como en producción)
y Edgar los pegó el 16-oct, en orden. Lo que salió, de los resultados que
mandó y de una lectura de producción después:

- **Bloque 2** (`fn_apertura_balanza_cargar`): `"cuadra": true`, 67 filas,
  `"sin_mapeo": []`, `"trabajos_sin_mapeo": []`, la fila TOTAL coincide y el
  control del Balance Sheet coincide en sus cinco cifras.
- **Bloque 3** (`fn_apertura_revisar`): 88 filas (67 de la balanza, 5 de
  control, 16 del asiento), las cinco de control en «coincide»; la única sin
  mapeo, «Account Receivable Contra», viene en 0.00 y a propósito no se mapea.
- **Bloque 4** (`fn_apertura`): posteada, 16 líneas, asiento **2026-000005**
  (los cuatro primeros del libro son las dos facturas y los dos recibos de
  octubre que ya habían entrado por los puentes); `v_comparacion` **14 de 14**
  en `ok`; `fn_estados_control('2026-09-APERTURA')` **40 de 40** (también
  «apertura en el libro»); `fn_verificar_cadena()` **10 de 10** (`"asientos": 5`).
- **Bloque 5**: `v_prestamos` 2 filas (12 y 52 cuotas al año) y «cuadre:
  préstamos» en `true` («lo mismo que dice el libro»).
- **Pendientes** (`pendientes-16-oct.sql`): la tarjeta ····7930 del recibo 55
  dada de alta como personal (2900: no es ninguna de las cuatro de las dos
  Amex del negocio en los statements de septiembre), la factura
  #MXP-METRONPR-M1 con retención 0 (en QuickBooks está cobrada entera) y
  `fn_puentes_correr()`: `"pasados": 2`, `"errores": 0`; los dos papeles
  entraron como 2026-000006 y 2026-000007.
- Después: `fn_puentes_verificar()` 13 de 13, `fn_banco_control('hoy')` 18 de
  18, `fn_estados_control('hoy')` 15 de 15, la bandeja de los puentes vacía.

## 16-oct, 10:19 de Miami: el banco arranca

`banco-1-aperturas.sql` (privado, con las cifras): la tarjeta básica de la
Gold (····1007, la del número que trae el archivo de Amex) dada de alta en
2100-2013, y las tres **conciliaciones de apertura al 30-sep**
(`fn_conciliacion_apertura` + `fn_conciliacion_confirmar`), con el saldo del
último statement de cada cuenta y lo que QuickBooks tenía en tránsito según
sus reportes de conciliación del 7-oct: Chase (1 cargo en circulación), la
Gold (23 cargos y 4 pagos del 7 al 30-sep: 27 partidas) y la Blue (10 cargos
y 2 pagos del 21 al 30-sep: 12 partidas). Las tres **confirmadas con
diferencia 0.00** a la primera, igual que en el banco de pruebas (16 y 17.6,
donde además se volvió a pegar sin daño). Después: `fn_banco_control('hoy')`
18 de 18, `fn_banco_verificar()` 15 de 15, `v_banco_saldos` con la última
conciliación de las tres al 30-sep, `fn_estados_control('hoy')` 15 de 15.

Pendiente en producción: los archivos del banco de octubre (el QFX de la
Gold al 8-oct, la Blue al 21, Chase al 31: `qfx2sql.py` los envuelve en el
SQL que se pega), y c6-pruebas otra vez (163) y c4-pruebas, los dos
opcionales.
