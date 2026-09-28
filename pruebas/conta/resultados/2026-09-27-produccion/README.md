# Producción · 27-sep-2026 · pegado del bloque B (c2, c3, c4 nuevos + c6) y sus pruebas

Exportados por Edgar desde el SQL Editor de Supabase (Postgres 17.6), en el
orden de pegado del §0 del README del banco (commit 92d4033: la versión
candidata del bloque B). Evidencia de que c2, c3 y c4 con sus «CAMBIOS PARA
c6» y c6-banco quedaron en producción y pasaron sus pruebas allí.

| Archivo | Qué es | Resultado |
|---|---|---|
| `01-c2-libro.csv` | El pegado de `c2-libro.sql` (marca 2026092701) | 10 de 10 en `true`; 88 cuentas |
| `02-c3-puentes.csv` | El pegado de `c3-puentes.sql` (marca 2026092601) | 23 de 23 en `true` (`sin_evaluar` ya en `true`: los puentes corrieron el 26-sep) |
| `03-c4-estados.csv` | El pegado de `c4-estados.sql` (marca 2026092601) | 7 en `true`; `c4 · apertura` y «apertura en el libro» en `false`, lo esperado hasta la apertura real |
| `04-c6-banco.csv` | El pegado de `c6-banco.sql` (marca 2026092704) | 7 de 7 en `true`: 13 tablas, 8 vistas, 21 funciones, `v_banco_saldos` 4 filas (1010, 1030 y las dos Amex) |
| `07-c2-pruebas.csv` | `c2-pruebas.sql` (23:32 UTC) | 82 de 82 en `true` |
| `08-c3-pruebas.csv` | `c3-pruebas.sql` (23:33 UTC) | 120 filas: 119 en `true`, la 45 «omitida» (Storage) |
| `pruebas.c4_resultado` y `pruebas.c6_resultado` (primera corrida) | `c4-pruebas.sql` y `c6-pruebas.sql` lanzadas A LA VEZ (23:33 y 23:36 UTC); el editor enseñó «Failed to fetch» en las dos | Se cruzaron sus candados: c4 111 filas, 108 `true`, 2 omitidas (89 «el libro estaba en uso», 103 a medias) y la 92 en rojo por 40P01 (deadlock); c6 100 filas, 98 `true`, la 33 (55P03 en su TRUNCATE) y la 49 (40P01) en rojo. Ninguna es un defecto: son las dos suites pisándose. Sin rastro después (0 asientos, 0 movimientos), cadena, puentes y banco en verde. Se repiten una a la vez (abajo). |
| `11-c6-pruebas.csv` | `c6-pruebas.sql` repetida SOLA (segunda corrida) | **100 de 100 en `true`**, la 33 y la 49 incluidas |
| `pruebas.c4_resultado` (segunda corrida) | `c4-pruebas.sql` repetida SOLA (23:57 UTC, unos 8 minutos; leída de la tabla por el conector) | **111 de 111 en `true`**, sin omitidas |

Después de todo: 0 asientos, 0 movimientos del banco, 0 conciliaciones,
ningún periodo cerrado, 88 cuentas, 3 tarjetas; cadena 10/10, puentes 13/13,
`fn_banco_verificar` en verde, `fn_banco_control('2026-10')` sin rojo y
`fn_estados_control('2026-10')` con el único rojo esperado («apertura en el
libro»). El bloque B queda en producción y certificado.

