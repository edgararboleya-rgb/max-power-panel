# Cómo se publica la app — con DOS sesiones trabajando

Desde el 14 de septiembre hay **dos sesiones** que escriben en el mismo sitio público
`edgararboleya-rgb/max-power-panel` (rama `main`, que es lo que abren los teléfonos):

| Sesión | Rama de desarrollo | De qué se ocupa |
|---|---|---|
| App Operativa | `claude/max-power-integrated-system-984wum` | el lector de alcance, los portales, las obras, el dinero del día a día |
| MXP Planos | `claude/electrical-diagram-app-rogcev` | el catálogo, el estimador, el takeoff |

El 14-sep casi se pierde trabajo: una sesión iba por la versión 167 y el panel ya estaba en
la 176. Copiar los archivos a ciegas le borra a la otra lo que acababa de publicar.

## Las cinco reglas

1. **Antes de publicar, siempre:** `git fetch origin main` y `git pull --rebase origin main`
   dentro de `max-power-panel`. Si vinieron commits nuevos, se mezcla; nunca se fuerza.
2. **Los archivos del otro no se copian.** Cada sesión copia **solo los archivos que tocó**.
   Nunca `cp js/*.js` a ciegas: eso pisa el trabajo ajeno.
3. **La versión se sube por encima de la que haya el panel**, no por encima de la que uno
   recuerde. Se mira `index.html` (`?v=NN`, 8 sitios) y `sw.js` (`mxp-casco-vNN`) del panel
   YA actualizado, y se suma uno.
4. **Las pruebas del otro también se corren** antes de publicar, porque un cambio en
   `js/app.js` las puede romper:
   `NODE_PATH=/opt/node22/lib/node_modules node pruebas/e0.js` y `pruebas/e13.js` (panel),
   `node pruebas/probar-alcance.mjs` (repositorio de desarrollo).
5. **Si hay conflicto en `index.html` o `sw.js`** (siempre son los números de versión): se
   toma el del panel y se sube uno por encima. Nunca se descarta el del otro.

## Quién manda sobre cada archivo

| Archivo | De quién |
|---|---|
| `js/alcance.js`, `cliente.html`, `gc.html`, `css/portal.css`, `js/portal-frases.js` | App Operativa |
| `docs/sql/`, `pruebas/e0.js`, `pruebas/e13.js` | MXP Planos |
| `js/app.js`, `js/db.js`, `css/styles.css`, `index.html`, `sw.js` | **compartidos** — mezclar, nunca reemplazar |

En los compartidos: hacer el cambio como un **parche pequeño** (editar las líneas que tocan)
y dejar que git lo mezcle. Si uno reescribe el archivo entero, git no puede ayudar.
