# Cómo se publica la app — con DOS sesiones trabajando

> **28-nov-2026 — LEE ESTO ANTES DE PUBLICAR (orden de Edgar, O-S1).** Este repositorio es público y la dirección de la app
> entrega cualquier archivo de `main`. Por eso en `main` **solo va la app** (`index.html`, `cliente.html`, `gc.html`,
> `verificar.html`, `manifest.webmanifest`, `sw.js`, `styles.css`, `css/`, `js/`, `assets/`), más `README.md` y estas cuatro
> páginas de `docs/` (las tres políticas y esta). El 28-nov se quitaron de `main` 383 archivos (`docs/` de trabajo, `pruebas/`,
> `supabase/`, `tools/` y `PENDIENTES.md`): **no se perdió nada**, siguen en el historial, en vuestras ramas y en una copia
> privada. Lo que eso pide a cada sesión:
> - Los papeles, las pruebas y las listas de pendientes se guardan en TU rama de desarrollo, nunca en `main`. Al publicar,
>   copia a `main` solo los archivos de la app que tocaste.
> - Al traer `main` a tu rama, git va a querer borrar esos archivos también en tu rama (o te dará un conflicto): **no los
>   borres en tu rama**. Si se borraron, recupéralos de tu último commit de antes de traer `main`
>   (`git checkout <ese commit> -- docs pruebas supabase tools PENDIENTES.md`) y guárdalos.
> - Las pruebas del panel (`pruebas/e0.js`, `pruebas/e13.js`, `pruebas/conta/…`) ya no están en `main`: córrelas desde tu rama
>   o desde tu copia, contra la app de `main`.

Desde el 14 de septiembre hay **dos sesiones** que escriben en el mismo sitio público
`edgararboleya-rgb/max-power-panel` (rama `main`, que es lo que abren los teléfonos):

| Sesión | Rama de desarrollo | De qué se ocupa |
|---|---|---|
| App Operativa | `claude/max-power-integrated-system-984wum` | el lector de alcance, los portales, las obras, el dinero del día a día |
| MXP Planos | `claude/electrical-diagram-app-rogcev` | el catálogo, el estimador, el takeoff |
| Contabilidad | `claude/quickbooks-accounting-app-u6ha83` | los libros (c1–c6), el banco y la pantalla de Contabilidad (`js/conta.js`) |

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
   `node pruebas/probar-alcance.mjs` (repositorio de desarrollo) y
   `node pruebas/conta/pantalla.js` (la entrada de Contabilidad en `js/app.js`).
5. **Si hay conflicto en `index.html` o `sw.js`** (siempre son los números de versión): se
   toma el del panel y se sube uno por encima. Nunca se descarta el del otro.

## Quién manda sobre cada archivo

| Archivo | De quién |
|---|---|
| `js/alcance.js`, `cliente.html`, `gc.html`, `css/portal.css`, `js/portal-frases.js` | App Operativa |
| `docs/sql/`, `pruebas/e0.js`, `pruebas/e13.js` | MXP Planos |
| `js/conta.js`, `css/conta.css`, `docs/conta/`, `pruebas/conta/`, `supabase/functions/plaid/` | Contabilidad |
| `js/app.js`, `js/db.js`, `css/styles.css`, `index.html`, `sw.js` | **compartidos** — mezclar, nunca reemplazar |

En los compartidos: hacer el cambio como un **parche pequeño** (editar las líneas que tocan)
y dejar que git lo mezcle. Si uno reescribe el archivo entero, git no puede ayudar.
