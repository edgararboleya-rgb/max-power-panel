# El estimador de Max Power — qué se hizo y en qué está
### Para la conversación de la App Operativa · solo informativo · 14/09/2026

Este archivo existe para que la sesión que atiende la **App Operativa**
(`max-power-panel`) sepa de un tirón qué le pasó al estimador entre el 13 y el
14 de septiembre, sin que Edgar tenga que contarlo otra vez. No pide nada.
No hay que ejecutar nada. Es el mapa de lo que ya está hecho y de lo que viene.

Quién escribió esto: la sesión de **MXP Planos** (`max-power-app`), que en
esas fechas trabajó también dentro de `max-power-panel` con permiso de Edgar,
publicando directo a `main` (la app que él abre todos los días).

---

## 1. La idea en dos líneas

Edgar quiere **un solo estimador con inteligencia integrada** para sus dos
negocios: **Max Power** (residencial y comercial chico, el suyo) y **MXP MEP**
(la sociedad con Roger, obra comercial grande). Planos hace el **takeoff**
(cuenta y mide sobre el plano del ingeniero); el estimador de la app operativa
pone el **dinero**. El takeoff entrega cantidades; el estimador las cotiza.
Esa frontera no se movió y no se va a mover.

---

## 2. Lo que YA está hecho (todo en `main`, todo publicado)

### E0 · «Quién pone el material» — el $0 dejó de ser mudo

El catálogo tenía **192 items a $0** y nadie sabía si era un error o si era a
propósito. Ahora cada $0 tiene motivo:

| `catalogo_items.cero_motivo` | Qué quiere decir | Ejemplos |
|---|---|---|
| `suministro` | Lo cotiza el proveedor por obra: switchgear, luminarias, fire alarm, Lutron, generador + ATS + UPS | 130 items |
| `by_owner` | Lo pone el dueño; Max Power solo instala | 25 |
| `solo_labor` | Solo mano de obra, sin material | 22 |
| `tarifa` | Es una tarifa, no una pieza (service call, permit…) | 10 |
| `falta_precio` | Se quedó sin precio y hay que ponérselo | 3 |
| *(null)* | Sin revisar | 2 |

En la app: cada línea a $0 del estimado sale con su **estado** (ocho posibles,
incluido *cotizado* cuando el proveedor ya mandó número, y *huérfano* cuando
el item ya no existe en el catálogo). Al cerrar un estimado se piden las
**preguntas por sección** («¿la switchgear va cotizada o by owner?») y las
respuestas viven en `estimados.cero_notas` (jsonb). Al **cliente** solo llega
lo confirmado como *by owner* en el bloque «No incluye» de la propuesta
(`cliente.html`); lo demás no sale. Hay un guardia en las cuatro salidas
(propuesta, PDF, congelar, convertir) que **avisa, no bloquea** — regla de
Edgar: «que me señales, no que me obligues».

Columnas nuevas: `catalogo_items.cero_motivo / cero_revisado / cero_nota`,
`estimados.cero_notas`, `estimados.no_incluye_extra`.

### E0c · MXP MEP — los estimados de Roger, identificados y aislados

Edgar **no** quiere manejar dos empresas todavía. Se conforma con esto:
`estimados.empresa` (`'mxp'` por defecto, `'mep'` para los de Roger). Un
estimado MEP se cotiza igual, pero:

- sale en **modo lectura** (solo para «que me dé un número»),
- su resumen interno **nunca lleva el membrete ni la licencia de Max Power**
  (`textoResumenMEP`), porque esa licencia no cubre esa sociedad,
- usa el **escenario MEP** (ver E13e), no A/B/C.

E8 (empresas completas con RLS y perfiles) queda **aplazado por Edgar**.

### E13 · Auditoría de la fórmula — siete hallazgos, dos eran reales

La fórmula GFL de Edgar **no se tocó** donde no hacía falta. Se auditó entera;
5 de 7 hallazgos ya los había resuelto el porte de Excel a la app. Los dos
reales, y lo que salió después, quedó así:

| Paso | Qué cambió | Dónde |
|---|---|---|
| **E13a** | Una línea **cotizada por el proveedor** ya no paga misceláneas (3 %); paga un markup propio `markup_cot_pct` (por estimado; default en `config_estimador`). | `estimados.markup_cot_pct` |
| **E13b** | Sales tax por condado con la regla real de Florida: el *discretionary surtax* solo aplica a los primeros **$5.000 por item**. Edgar decidió **Hillsborough 7,5 %** en A, B y C. | `escenarios.tax_material` |
| **E13c** | Los *benefits* dejan de ser un número mágico: desglose **FICA 7,65 · FUTA 0,1 · SUTA 0,3 · WC 2,97 (clase 5190, FL 2026) · GL 1,0 · PTO 4,2 · salud 0 · otros 0** ≈ 16 %. Sin seguro de salud, ~16 %, no el 28–38 % que se dice por ahí. | `escenarios.benefits_detalle` (jsonb) |
| **E13d** | **Escalación** para obras largas: `factor = 1 + escalacion_anual × (meses_obra/12) / 2` (sube a mitad de obra en promedio). `escalacion_anual = 0,04` en config. | `estimados.meses_obra`, `config_estimador.escalacion_anual` |
| **E13e** | Escenario **`MEP`** propio, con `mezcla` (jsonb: lista de cuadrilla) que admite **superintendent al 10 % de las horas a $60/h**, como el Excel de Edgar reparte horas por helper/journeyman/foreman. | `escenarios` fila `'MEP'` |
| **E13f** | Salarios reales: **helper $20 · journeyman $35 · foreman $45 · superintendent $60**. Y **overhead por porcentaje del costo directo** (`overhead_pct`) para el MEP, porque el overhead por hora de Max Power no aplica en esa obra. | `escenarios.overhead_pct`, `estimados.overhead_pct` |
| **Blindaje** | Un `overhead_pct = 0` ya **no** puede dejar un bid sin overhead: 0 o null caen al método por hora. | motor |
| **Cotizado sin overhead** | El overhead por porcentaje **no se cobra sobre lo que llega cotizado** (una switchgear de $600K cargaba $95.850 de overhead que no existe). | motor |

**La regla que manda sobre todo esto:** ningún estimado que ya existía se
mueve ni un centavo. Una línea sin marcar da el bid **idéntico** al de la
fórmula vieja. Está probado (ver §4).

### E9 · Ensambles comerciales

A las recetas residenciales (Romex) se sumaron **8 recetas comerciales en EMT
y en MC** (receptáculo 20A, switch, luminaria 2×4, junction box, branch
circuit…), con `ensambles.modo = 'comercial'`. Cada modo del estimado ve solo
sus recetas. El `CHECK` de `ensambles.modo` se amplió para admitirlo (rompió
la primera vez: Edgar mandó la captura).

Edgar aclaró algo que cambia cómo pensar las recetas: **él no usa pies
promedio por receptáculo; él MIDE sobre el plano escalado.** Las recetas con
pies fijos sirven para remodelaciones comerciales chicas de Max Power; para el
MEP lo que vale es lo medido (ver E5 en §3). Las recetas se dejaron, con esa
nota.

### Arreglos sueltos que salieron en el camino

- `id="btn-est-propuesta"` estaba **duplicado**: el segundo botón (armar) no
  hacía nada. Renombrado a `btn-est-armar`.
- El toast de **congelar** decía «los precios quedan fijos» y **era falso**:
  `calcularEstimado` recalcula siempre desde el catálogo vivo, también en
  estimados congelados y convertidos. Lo que sí queda fijo es el contrato del
  proyecto al convertir. El texto ahora dice la verdad.
- `db.js`: nueva `cambiarItemCatalogo(id, cambios)` que **lanza error si
  PostgREST devuelve `[]`** — un PATCH bloqueado por RLS responde 200 con
  lista vacía, no con error. Antes eso pasaba en silencio.
- `catPorNombre(nombre)`: índice memoizado del catálogo, O(1) en vez de
  recorrer 1.084 items por cada línea.

---

## 3. Lo que se hizo del lado de Planos y toca al estimador

Informativo — la app operativa no tiene que hacer nada con esto, pero le va a
**llegar** por `alias_takeoff` y por el código de partida.

- **E1 · Biblioteca de takeoff.** Los 17 tool sets de Bluebeam de Edgar (455
  tools) viven en Planos. **311 tienen item en el catálogo**, y los 311 llegan
  **por un alias que YA existe en Supabase** (619 alias, export del 14/09
  noche). No hay alias pendientes de cargar. 109 tools de conteo siguen sin
  pareja (casi todos lo que el porte del Excel dejó fuera); la lista está en
  `max-power-app/docs/takeoff/sin-pareja.md`, y es decisión de Edgar.
- **E2 · Código de partida.** Cada renglón del takeoff viaja con su cost code
  (`01-DEMO … 20-MISC`; los 20 están en `catalogo_items.codigo` y en
  `alias_takeoff.codigo`). Es la llave para comparar estimado contra gasto
  real más adelante (E11).
- **E5 · Rutas de conduit.** Lo que Edgar hacía en Bluebeam con CircuitOps:
  traza el recorrido sobre el plano calibrado y el largo se suma **por tipo de
  tubo** (23 tipos: 6 Feeder, 11 Branch Circuit, más cable LV y bus duct),
  con zona/piso, drop y unidades — `(largo + drop) × unidades`, la cuenta de
  su Excel. Llega al estimador en **FT** con `06-FEED` (feeders), `08-ROUGH`
  (branch), `13-LV` (low voltage), `05-PANEL` (bus duct).
- **E5b · Homerun y feeders con el NEC delante** (15/09). Antes de trazar se
  elige tubo (EMT · PVC 40/80 · GRS · IMC), calibre, cuántos circuitos o fases
  van dentro, neutro y tierra; la app ofrece **solo los tamaños en que caben**
  (Cap. 9 Tabla 1 al 40 %) y no deja pasar de **6 portadores** (310.15(C)(1),
  el «80 %» de Edgar; la tierra no cuenta). Al estimador llegan el tubo con
  su **nombre exacto de `catalogo_items`** (`1/2" EMT CONDUIT`, `3/4" PVC
  CONDUIT. SCH 40`…) y el hilo con **su nombre exacto** (`# 12 THHN STRANDED
  CU.`, `# 4/0 THHN STRANDED CU.`, `# 250 MCM THW CU.`, `# 1/0 XHHW STRANDED
  ALUMINUM COMPACT`), en FT. Tubos y cables son los de su catálogo (15/09):
  EMT, PVC 40/80, GRS, ENT, flex metálico e IMC; cobre THHN/THW y aluminio
  compacto XHHW para feeders. Ya no hace falta alias para ninguno. La
  **tierra va aparte** con su calibre (250.122) y llega como su propio renglón.
- **E10 · Estimado desde el scope** (15/09, Planos v32.L, en azul). En Planos,
  Materiales → **Scope**: se pega el scope of work, el cerebro propone
  recetas (`ensambles`) e ítems del catálogo **con nombres exactos** y
  cantidades, más preguntas y lo que queda fuera; lo contado en la hoja viaja
  con el scope y manda. Edgar aprueba fila a fila y sale un **estimado
  borrador** con `estimado_ensambles` + `estimado_items` (código, origen
  `scope`) y el `modo` que pidan las recetas. La IA no toca un precio. Vive
  en Planos porque el panel habla con la edge function `cerebro` cuyo código
  no está en el repo. Calibrado con los 3 proyectos reales de Drive (Stuart
  $53.928 · UM $371.425 · DTCC): `docs/e10/GUIA-3-PROYECTOS.md` en
  max-power-app. **Falta `wrangler deploy` del worker.**
- **E14 · Pies contra MLF** (15/09, panel v182). El catálogo vende el cable
  por MIL pies (MLF) y una fila del takeoff casada **por nombre** entraba con
  factor 1: 500 ft de 4/0 → 500 MLF → $3,8 millones. Corregido en los dos
  caminos (Planos al mandar, panel al pegar CSV): lo medido en pies se divide
  por 1000 solo si el ítem es MLF; el alias sigue mandando con su factor; el
  alias que se aprende al aplicar guarda el factor bueno. `pruebas/e14.js`.
- **E3 · Búsqueda visual** con lista de revisión: cuenta símbolos iguales del
  plano del ingeniero y deja descartar los falsos antes de que entren al
  Count. Medido contra un plano real (Epic ED-1.3): 80 % de umbral encuentra
  las 13 tiras LED con 18 falsos en 1,9 s; los falsos se quitan de un toque.

**Lo que Edgar quiere automatizar de verdad son los conteos de piezas**, no
los recorridos: «los cables son los que te cambian los proyectos» y esos los
mide él.

---

## 4. Las pruebas — el panel no tenía ninguna; ahora tiene dos

`max-power-panel/pruebas/` (Playwright con el Chromium ya instalado, sin nube,
sin sesión; la lógica pura se alcanza por `window.MXP_PRUEBA.e0.*`):

| Archivo | Pasos | Qué protege |
|---|---|---|
| `e0.js` | 30/30 | Los ocho estados del $0, que la cotización apague la sección, que al cliente solo llegue lo confirmado, que el dinero **no se mueva**, que el resumen MEP no lleve membrete. |
| `e13.js` | 42/42 | Lo primero, siempre: **un estimado existente da el bid idéntico**. Luego E13a, E13d, E13e, E13f y el blindaje del overhead. |

```
NODE_PATH=/opt/node22/lib/node_modules node pruebas/e0.js
```

**Regla acordada con Edgar:** una prueba nueva por cada función que toque
dinero o que escriba algo que el cliente vaya a firmar.

---

## 5. Los SQL — todos corridos por Edgar, todos idempotentes

En `max-power-panel/docs/sql/` (copia en `max-power-app/docs/takeoff/sql/`):

| Archivo | Estado |
|---|---|
| `e0-quien-pone-el-material.sql`, `e0b-cierre.sql`, `e0c-mxp-mep.sql` | ✔ corridos |
| `e13b-sales-tax.sql` → `e13b2-tax-75.sql` (7,5 % decidido) | ✔ |
| `e13cd-benefits-y-escalacion.sql`, `e13e-escenario-mep.sql`, `e13f-tarifas-y-overhead.sql` | ✔ |
| `e13g-comprobar-overhead.sql` (solo lectura, distingue NULL de 0) | ✔ |
| `e9a`, `e9b` (lectura), `e9c-ensambles-comerciales.sql` | ✔ |
| `e2d-exporta-catalogo.sql` (lectura: catálogo + alias a CSV) | ✔ — es lo que alimenta la biblioteca de Planos |
| `e13-cotizaciones.sql` (columna opcional `markup_cot_pct`) | **pendiente, opcional** — sin ella el motor usa el default de config |

Nada de esto escribe permisos, tokens ni secretos. Los secretos del cerebro
(`ANTHROPIC_API_KEY`, `MXP_TOKEN`) viven solo en Cloudflare, los pone Edgar
con `wrangler secret put`, y **no van en ningún `.md`**.

---

## 6. Cosas que conviene saber antes de tocar el motor

1. **`calcularEstimado(est, itemsOverride)` es una función pura** y recalcula
   **siempre** desde el catálogo vivo, también en congelados y convertidos. Lo
   que no se mueve es el monto del contrato guardado al convertir. Si alguna
   vez se quiere congelar precios de verdad, hay que guardar una copia de las
   líneas — no está hecho, y Edgar lo sabe.
2. **Cadena de la fórmula** (sin cambios de orden): material → misc (solo
   sobre material propio, no cotizado) → sales tax → markup → total material;
   horas × tarifa mezclada → benefits → total labor; prime = labor + material
   + escalación; overhead (por hora **o** por %, y el % **excluye lo
   cotizado**); profit = (prime + overhead) × profit; bid = prime + overhead +
   profit.
3. **`cargarEstimador` usa `select=*`**: cualquier columna nueva en
   `estimados`/`escenarios` llega sola al front. No hay que tocar `db.js`
   para leerla.
4. **PostgREST + RLS**: un PATCH que RLS bloquea devuelve `200 []`. Comprobar
   la representación devuelta, no el status. `cambiarItemCatalogo` ya lo hace;
   cualquier escritura nueva debería copiar ese patrón.
5. **UI en español, oficio en inglés.** En el panel **sí** se usan emojis en
   botones (📄 🔒 🚀) — es su estilo y se respeta. En MXP Planos, cero emojis
   (iconos SVG de línea).
6. Edgar prefiere **la verdad incómoda** al consuelo, y que **no se le pida**
   que mande archivos ni explique bugs para facilitarnos el diagnóstico. Se
   busca en el código primero.

---

## 7. Lo que viene (para saber dónde va a aparecer trabajo)

| Paso | Qué | Dónde toca |
|---|---|---|
| **E4** 🔵 | Lector de leyenda con visión: de la hoja de símbolos del ingeniero salen las categorías de Count ya nombradas. Añade una tercera herramienta forzada al cerebro (`leyenda_leida`) → requiere `wrangler deploy` de Edgar. | Cerebro + Planos. **En curso.** |
| **E10** 🔵 | Estimado desde scope: el cerebro **propone** ensambles × cantidad + código; **el código calcula**; Edgar aprueba fila a fila. Mismo patrón que `alcance.js`: la IA escribe la propuesta, el dinero lo decide el código. | Cerebro + estimador. Necesita 3 scopes reales de Edgar. |
| **E11 ✔** | **Hecho 15/09.** Ganado/perdido con motivo y, si se sabe, lo que ofertó el que ganó. Benchmarks $/SF y h/SF por tramo de tamaño y por modo, con tasa de acierto. Clave: al cerrar un estimado se guarda la **foto** del número (`bid_final`, `horas_final`, `material_final`) — sin ella el historial mentiría, porque `calcularEstimado` recalcula siempre con los precios de hoy. `pruebas/e11.js` 33/33. **SQL: `docs/sql/e11-resultado.sql`.** | Estimador. |
| **E12 ✔** | **Hecho 15/09.** Importar el CSV del supply: se casa contra el catálogo (exacto, alias o código — nunca por parecido), se propone fila a fila y **nada se escribe sin aprobarlo**. Dos destinos: tus precios, o `precio_ref` para bases compradas (uso interno, no salen en propuestas). Pantalla «tuyo vs referencia». Avisa antes de pisar un $0 puesto a propósito (E0). `pruebas/e12.js` 29/29. **SQL: `docs/sql/e12-referencia.sql`.** | Estimador. |
| **E7** | Planos: páginas rotadas, aviso «texto en curvas». | Planos. |
| **E8** | Empresas completas con RLS y perfiles. | **Aplazado por Edgar.** |

~~Un defecto conocido y **no** arreglado~~ → **v202 (20/09):** ya no hace falta
acordarse. El estimador comprueba TODAS las recetas y señala aquellas cuyo
conector NM se queda corto para el cable que llevan (½" aguanta hasta 12/3; de
10 para arriba pide ¾", y un 6/3 pide 1"). Dice cuál hace falta y, si esa pieza
no está en el catálogo —que es justo el caso del `EV CHARGER OUTLET`— lo avisa,
porque de nada sirve pedir que se cambie la receta por algo que no se puede
elegir. `pruebas/e27.js` cubre los tres casos.

---

## 8. Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Plan completo y estado por paso | `max-power-app/docs/PLAN-ESTIMADOR.md`, `docs/PLAN-FASES.md` |
| Contrato de datos entre apps (tablas, `estimate_id`, `project_id`) | `max-power-app/docs/CONTRATO-DATOS.md` |
| El mapa del cerebro compartido (worker, token, cómo engancha una tercera app) | `max-power-app/docs/CEREBROS.md` |
| Biblioteca de takeoff, alias y sin-pareja | `max-power-app/docs/takeoff/` |
| SQL del estimador | `max-power-panel/docs/sql/` |
| Pruebas del panel | `max-power-panel/pruebas/` |
| Motor del estimador | `max-power-panel/js/app.js` → `calcularEstimado`, `ceroDe`, `escenariosDe`, `benefDetalle` |
| Propuesta al cliente | `max-power-panel/cliente.html` |
