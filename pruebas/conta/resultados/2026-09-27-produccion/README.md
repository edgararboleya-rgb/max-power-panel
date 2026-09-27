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
| `pruebas.c4_resultado` y `pruebas.c6_resultado` | `c4-pruebas.sql` y `c6-pruebas.sql`, corridas a la vez desde las 23:33 y 23:36 UTC; el editor enseñó «Failed to fetch» en las dos | (se anota abajo al leerlas) |
