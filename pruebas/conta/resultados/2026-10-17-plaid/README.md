# 17-oct-2026 · la conexión con Plaid (c7) entra en producción

Lo que Edgar pegó y lo que salió (sin cifras del negocio: son las pruebas de c7).

| Hora (UTC) | Qué | Resultado |
|---|---|---|
| ~02:05 | `c7-plaid.sql` v1 | 4 filas. Revisado solo leyendo desde aquí: tablas, config, secreto en Vault, cron `0 11 * * *`, 14 funciones, la vista, RLS. |
| ~02:15 | `c7-pruebas.sql` v1 (`c7-pruebas-produccion.csv`) | 19 filas: 18 `true`, la 15 «omitida». Nada quedó (0 conexiones, 0 tokens, 0 archivos, 0 movimientos de prueba). |
| ~02:20 | **Hallazgo**: `fn_banco_control('hoy')` con 1 en rojo de 18 (`cuadre: protecciones del banco`) y `fn_verificar_cadena()` con `permisos` en rojo: la v1 tenía `fn_plaid_*` SECURITY DEFINER ejecutables por `service_role` (y dos por el dueño). El banco de pruebas no lo había visto: c7-pruebas no corría los controles. | → v2 (commit 5034825) |
| ~02:28 | Edgar desplegó la función `plaid` con el **nombre** del archivo en vez de su contenido (`ReferenceError: plaid is not defined`). «Verify JWT» apagado, bien. | → repegar con el contenido |
| ~02:45 | `c7-plaid.sql` v2, `c7-pruebas.sql` v2 (`c7-pruebas-produccion-v2.csv`), la función v2 | 21 filas: 20 `true`, la 15 «omitida»; la **21** dice `c2 verde | c6 verde | en la API: ninguna`. `?paso=salud`: `ok, llaves, rutina, redirect, base, sesion` en `true`. Desde aquí, solo leyendo: c6 18/18, c2 y c3 sin rojos, ninguna `fn_plaid_*` en la API ni SECURITY DEFINER, 0 rastro de las pruebas. |

Pendiente: la redirect URI en el panel de Plaid (paso 5), «publica» de la pantalla, la aprobación de producción de Plaid (`PLAID_SECRET` y `PLAID_ENV`), MFA (TOTP) en la entrada del dueño antes de conectar un banco real.
