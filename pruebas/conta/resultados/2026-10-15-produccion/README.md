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

Pendiente en producción: las suites (opcionales: c4-pruebas 113, c6-pruebas
163) y los cinco bloques de la apertura del 30-sep (el 1 ya se puede; del 2
al 5, con la balanza de arreglos-5).
