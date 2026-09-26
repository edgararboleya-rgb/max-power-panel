# Producción · 26-sep-2026 · pegado de c2, c3 y c4 y sus pruebas

Exportados por Edgar desde el SQL Editor de Supabase (proyecto de Max Power,
Postgres 17.6), en el orden de pegado del §0 del README del banco. Son la
evidencia de que la versión candidata del bloque A (commit a4603de) quedó
en producción y pasó sus pruebas ahí, no solo en el banco.

| Archivo | Qué es | Resultado |
|---|---|---|
| `01-c2-libro.csv` | El pegado de `c2-libro.sql` (13:50 UTC): los 10 controles de `fn_verificar_cadena` | 10 de 10 en `true`; 88 cuentas |
| `02-c3-puentes.csv` | El pegado de `c3-puentes.sql` (13:51): los 10 del libro + los 13 de `fn_puentes_verificar` | 23 de 23 en `true` |
| `03-c4-estados.csv` | El pegado de `c4-estados.sql` (13:51): las 9 filas del resumen | 7 en `true`; `c4 · apertura` y `apertura en el libro` en `false`, lo esperado hasta la apertura real |
| `04-c2-pruebas.csv` | `c2-pruebas.sql` (13:52) | 80 de 80 en `true` |
| `05-c3-pruebas.csv` | `c3-pruebas.sql` (13:52) | 118 filas: 117 en `true`, la 45 «omitida» (Storage no se borra por SQL; se prueba en el banco) |
| `pruebas.c4_resultado` (en producción) | `c4-pruebas.sql`, corrida de las 14:40 UTC, 7 minutos; el SQL Editor enseñó «Error: Failed to fetch (api.supabase.com)» antes de que terminara y el resultado se leyó de la tabla | 110 de 110 en `true`, 0 omitidas (la 109, MAINTAIN, corre en 17.6) |

Después de las corridas: 0 asientos, contadores en 0, ningún periodo cerrado,
ninguna cuenta, proveedor ni balanza de prueba; cadena 10/10, puentes 13/13,
`fn_estados_control('2026-10')` con el único rojo esperado. Las 6 reglas de
categoría, 5 de forma de pago y 3 de tipo de obra confirmadas el 24-sep cubren
todo el vocabulario real de la app (`recibos.categoria`, `recibos.metodo_pago`,
`proyectos.tipo`); las 56 en borrador son alias en inglés y español para el
lector de tickets, que solo cuentan si un recibo llega con esa palabra (espera
en la bandeja hasta que Edgar confirma el alias).
