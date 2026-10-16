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

Pendiente en producción: c6-pruebas otra vez con el archivo corregido
(163), c4-pruebas (opcional) y los bloques 2 a 5 de la apertura del 30-sep
(con la balanza de arreglos-5).
