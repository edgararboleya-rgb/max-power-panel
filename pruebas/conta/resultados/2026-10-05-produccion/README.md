# Producción, 5-oct-2026: el banco de la ronda 4d pegado

Lo pegado (registros de Postgres de Supabase, hora de Miami): `c2-libro.sql`
16:04, `c4-estados.sql` 16:05, `c6-banco-parte1.sql` 16:06 y
`c6-banco-parte2.sql` 16:07 (el banco en sus dos partes: entró sin problema
de tamaño). Marcas después del pegado: c2 2026100201, c3 2026092601, c4
2026100201, c6 2026100303.

| Archivo | Resultado en producción |
|---|---|
| `c2-pruebas.sql` (16:07) | 83 de 83 en `true` (leído de `pruebas.c2_resultado`) |
| `c3-pruebas.sql` (16:08) | 119 en `true` y la 45 «omitida» (Storage), como siempre — `08-c3-pruebas.csv` |
| `c6-pruebas.sql` (16:08) | **161 de 161** en `true` — `09-c6-pruebas.csv` |
| `c4-pruebas.sql` (16:14, sola) | **113 de 113** en `true`, sin omitidas (también la 109, MAINTAIN, que es de Postgres 17, y la 110, «no deja rastro»). El SQL Editor dio su error de red de siempre; la corrida siguió en el servidor y se leyó de `pruebas.c4_resultado` (corrida 16:14:21). Antes se había pegado c3-pruebas dos veces (16:08:02 y 16:08:30) en vez de c4-pruebas. |

Después del pegado, leído en producción (solo lectura): `fn_verificar_cadena`
10 de 10 en verde, `fn_puentes_verificar` 13 de 13, `fn_banco_verificar` 15
de 15, `fn_banco_control('hoy')` todo en verde y `fn_estados_control('hoy')`
con su único rojo esperado, «cuadre: apertura en el libro» (la apertura no
está posteada). Sin rastro de las pruebas: 2 asientos (los de antes), 0
movimientos del banco, 0 archivos, 0 conciliaciones, 0 cuentas personales,
ningún período cerrado. Ningún error en los registros de Postgres. Después de c4-pruebas, lo mismo: los
mismos conteos y el único rojo, la apertura.

**El banco de la ronda 4d queda certificado en producción**: c2-pruebas 83/83,
c3-pruebas 119 + la 45 omitida, c4-pruebas 113/113 y c6-pruebas 161/161.
