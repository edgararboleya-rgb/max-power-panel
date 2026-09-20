# La contabilidad dentro de la app — el plan

**Para qué existe este archivo:** para que cualquier sesión que trabaje la
contabilidad lea **este archivo solo** y ya sepa todo: qué se decidió, en qué
fase vamos, qué archivos toca y qué archivos no. Sin volver a explorar el
repositorio entero. Eso es lo que hace que esto salga barato en crédito.

**El verde y el azul — qué modelo trabaja cada paso:**

| | Modelo | Para qué |
|---|---|---|
| 🔵 **AZUL** | Claude Fable 5.1 (`claude-fable-5-1`) | **Crea lo delicado.** El diseño, la estructura, el criterio, lo que si sale torcido contamina todo lo que venga después. |
| 🟢 **VERDE** | Claude Opus 5 (`claude-opus-5`) | **Trabaja encima de lo que el azul ya dejó hecho.** Repetir el patrón, extender, pulir, probar, pegar. |

Casi toda fase lleva los dos: **el azul crea el primero, el verde hace los
otros nueve**. Ahí está el ahorro de verdad — no en escatimar azul donde hace
falta, sino en que lo que el azul diseña una vez, el verde lo multiplica
barato. Fable cuesta el doble ($10/$50 contra $5/$25 por millón), así que
pagarlo en el diseño rinde y pagarlo en el relleno no.

La sesión avisa **«esta parte va en azul»** o **«ahora cámbiate a verde»**
antes de cada bloque, y espera a que Edgar cambie el modelo.

**Las órdenes de trabajo están en `docs/conta/fases/`**, una por fase. La
sesión que va a trabajar la Fase N lee **este archivo y `fNN-*.md`**, nada
más. Ahí está qué trae Edgar, qué crea el azul, qué trabaja el verde, cuál
es el entregable y cómo se sabe que terminó.

| | | | |
|---|---|---|---|
| [f01 Plan de cuentas](conta/fases/f01-plan-de-cuentas.md) | [f02 El libro](conta/fases/f02-el-libro.md) | [f03 Puentes](conta/fases/f03-puentes.md) | [f04 Estados](conta/fases/f04-estados.md) |
| [f05 Pantalla](conta/fases/f05-pantalla.md) | [f06 Banco](conta/fases/f06-banco.md) | [f07 Categorización](conta/fases/f07-categorizacion.md) | [f08 Cierre](conta/fases/f08-cierre.md) |
| [f09 Costo por obra](conta/fases/f09-costo-por-obra.md) | [f10 Facturación y WIP](conta/fases/f10-facturacion-wip.md) | [f11 Nómina](conta/fases/f11-nomina.md) | [f12 Apertura y 1099](conta/fases/f12-apertura-1099.md) |
| [f13–14 Paralelo](conta/fases/f13-14-paralelo.md) | [f15 Amarre](conta/fases/f15-amarre.md) | [f16 Contador de guardia](conta/fases/f16-contador-de-guardia.md) | [f17 Paquete fiscal](conta/fases/f17-paquete-fiscal.md) |

**Regla número uno de este plan:** si vas a empezar una sesión, di
*«hagamos la Fase N»*. No digas *«sigue con la contabilidad»*. La diferencia
en crédito entre una cosa y la otra es de tres a cinco veces.

Escrito el 20 de septiembre de 2026.

---

## 1. Qué se decidió (esto no se vuelve a discutir)

| Decisión | Qué se resolvió |
|---|---|
| **Empresa** | Una sola: Max Power Electrical Solutions, Inc. MXP MEP queda fuera. |
| **Día del cambio** | **1 de enero de 2027.** Los libros nuevos arrancan con el año fiscal nuevo. |
| **Nómina** | Gusto o Check. La app **no** calcula ni presenta impuestos de nómina. La app pone el puente: horas → nómina, y nómina → repartida por obra. |
| **Impuestos** | El CPA una vez al año. La app le entrega el paquete: balanza, mayor, activos y depreciación, 1099-NEC de subs. |
| **Contador de día a día** | Se elimina. Edgar hace el cierre mensual. |
| **Base** | Devengado para los libros; el CPA decide qué presenta. |
| **Moneda** | Todo en `numeric` de Postgres. **Nunca** se suma dinero en JavaScript. |
| **Auditabilidad** | **100 %.** Ante contador, IRS, banco y seguro. Ver punto 3. |
| **La IA dentro de la app** | Sí, con límite claro: **propone, nunca postea.** Ver punto 4. |

---

## 2. Dónde vive el código nuevo

En `PUBLICAR.md` hay dos sesiones escribiendo el mismo repositorio, con dueños
por archivo. La contabilidad **no pelea con nadie** porque va en archivos
nuevos:

| Archivo | Quién |
|---|---|
| `js/conta.js` | **Nuevo. Solo contabilidad.** Nadie más lo toca. |
| `docs/conta/*.sql` | **Nuevo.** No se mete en `docs/sql/`, que es de MXP Planos. |
| `docs/CONTA-PLAN.md` | Este archivo. La memoria del proyecto. |
| `js/app.js`, `js/db.js`, `index.html`, `sw.js` | **Compartidos.** Solo parches chicos: una línea que carga `conta.js`, un botón en el menú. Nunca se reescriben. |

Motivo técnico además del social: `js/app.js` pesa 783 KB. Una sesión que lo
abre gasta crédito solo en leerlo. Con la contabilidad aparte, no hay que
abrirlo nunca.

---

## 3. Auditabilidad — la regla que manda sobre todas las demás

Estos libros los tiene que poder abrir un contador, el IRS, el banco o la
aseguradora y **entenderlos sin que nadie se los explique**. Eso no es un
adorno: es el requisito que decide cómo se escribe todo lo demás.

1. **El asiento no se borra ni se edita.** Se corrige con un asiento de
   reverso. La tabla `asiento_lineas` no acepta `update` ni `delete`; la base
   lo impide, no la pantalla.
2. **Todo número llega a su papel.** Del estado financiero al asiento, del
   asiento al recibo con su foto, o a la factura, o al reporte de horas
   firmado. Sin saltos.
3. **Cada asiento dice de dónde salió**: quién, cuándo, desde qué documento y
   por qué camino (a mano, puente automático, o propuesta de la IA aprobada).
4. **Lo que tocó la IA se ve que lo tocó la IA.** Cada asiento nacido de una
   sugerencia lleva el sello: qué modelo, qué propuso, quién lo aprobó y
   cuándo. Un auditor jamás debe encontrar una línea cuyo origen no esté
   claro. **Esto es lo que hace compatible «IA en todo» con «100 % auditable».**
5. **El período cerrado se cierra de verdad.** Después del cierre nadie
   escribe ahí — ni Edgar, ni un puente, ni la IA.

---

## 4. El cerebro contable — qué hace el código y qué hace la IA

Sí va IA dentro de la app, igual que en Planos y en la operativa, sobre la
misma edge function `cerebro`. Pero con una frontera que no se cruza:

> **Lo que se puede contestar con una resta, lo contesta la base de datos.
> Nunca la IA.**

Un modelo de lenguaje es un analista excelente y un sumador mediocre. Si le
preguntas «¿cuadra el balance?» te va a contestar, y alguna vez se va a
equivocar. Esa pregunta tiene respuesta exacta y la da Postgres.

### Lo determinista — código, corre siempre, no opina

| Control | Qué vigila |
|---|---|
| Cuadre | Debe = haber. Restricción de base. Un asiento descuadrado **no entra**. |
| Amarre bancario | Saldo en libros = saldo del estado de cuenta. Si no, el mes no cierra. |
| Lectura vacía | Toda consulta financiera declara cuántas filas esperaba. Cero donde debería haber datos **no dibuja la pantalla**, la detiene. Ese es el arreglo del problema del estado financiero en cero — es código, no IA. |
| Período | Nadie escribe en un mes cerrado. |
| Ronda nocturna | Cada noche se corren todos los controles de arriba. |

### La IA — el analista de guardia

Lo que un contador con experiencia hace y una resta no puede:

- **Explica el descuadre.** El código dice *«faltan $1.240»*. La IA dice *«el
  recibo de CED del 12 entró dos veces, el segundo con otro número de
  transacción»*, y **propone** el asiento de reverso.
- **Concilia.** Cruza movimiento del banco contra recibo, factura o nómina, y
  deja en la bandeja solo lo que no casó.
- **Categoriza** lo que la regla no alcanza, y aprende de las correcciones.
- **Huele lo raro.** *«El material de esta obra va 40 % arriba de lo que da tu
  estimador, y el 80 % entró en tres días».* Esto no lo pide nadie: sale solo.
- **Contesta en llano.** «¿Por qué bajó el margen en la obra de Stuart?»
- **Redacta** la nota del cierre y el resumen para el CPA.

### Las tres reglas de la IA

1. **Propone, nunca postea.** Todo lo que la IA sugiere entra a una bandeja de
   pendientes. Edgar aprueba. Sin aprobación no hay asiento. Un toque para
   aprobar, pero el toque existe.
2. **Cita o se calla.** Toda afirmación viene con el asiento, el recibo o el
   movimiento que la sostiene. Sin fuente, no se muestra.
3. **Tiene tope de gasto.** Se cuelga del `asistente_costo_mes` y del
   `tope_mes_centavos` que la app **ya tiene montados**, con su propia fila por
   acción. Se ve lo que gastó y se corta solo.

### Qué modelo usa la app por dentro

**Solo Opus y Fable. Ni Haiku ni Sonnet, en ninguna parte.** Decisión de
Edgar: prefiere pagar más y que sea de verdad inteligente. No se vuelve a
proponer un modelo chico «para lo mecánico» — lo mecánico mal hecho es
justamente lo que ensucia un libro.

| Tarea | Modelo | Esfuerzo |
|---|---|---|
| Categorizar movimientos, casar recibo con gasto | `claude-opus-5` | `low` |
| Leer un recibo, resumir el mes, redactar la nota del cierre | `claude-opus-5` | `high` |
| **El auditor nocturno**, explicar un descuadre, proponer el reverso, oler lo raro, conversar sobre los libros | `claude-fable-5-1` | `high` / `xhigh` |

### Cómo se paga eso sin que se dispare

El esfuerzo es el lever, **no el modelo**. Bajar a `low` no es cambiar de
cerebro: es el mismo Opus pensando menos en algo que no lo necesita. Para
clasificar un movimiento de banco es lo correcto; para entender por qué no
cuadra el mes, no.

1. **`output_config: {effort: "low"}`** en lo repetitivo. Mismo modelo, mucho
   menos gasto. El `effort` va **dentro** de `output_config`, no arriba.
2. **Prefijo cacheado.** El plan de cuentas y las reglas van primero y fijos,
   con `cache_control`; lo que cambia (el movimiento que se está mirando) va
   al final. La lectura cacheada cuesta una fracción de la entrada nueva. Si
   `usage.cache_read_input_tokens` sale en cero, algo lo está invalidando y
   hay que buscarlo.
3. **Batches a mitad de precio** para la categorización del mes, que no corre
   prisa. Solo lo que Edgar mira en el momento va en vivo.
4. **La frontera del punto 4 es el ahorro más grande de todos.** Cada pregunta
   que contesta Postgres es una llamada que no se paga. La ronda nocturna
   corre en SQL; el modelo entra solo cuando hay algo que explicar.
5. **Tope duro** en `asistente_costo_mes` / `tope_mes_centavos`, que la app ya
   tiene montados, con fila propia por acción. Se ve lo que gastó y se corta.

---

## 5. Lo que se puede romper, y con qué se tapa

### 3.1 El peligro real: la app falla callada

`js/db.js` tiene **48 veces** el patrón `.catch(() => [])`. Para la app de obra
está bien pensado: si una tabla no carga, el equipo ve el resto y sigue
reportando. Para contabilidad **eso es veneno**: una lectura que falla devuelve
lista vacía, y el estado de resultados enseña una cuenta en cero sin avisar.
Un número equivocado que se ve bien es peor que una pantalla rota.

**Tapa:** `js/conta.js` nunca usa ese patrón. Si una lectura falla, la pantalla
se niega a dibujar y dice cuál falló.

### 3.2 Doble posteo desde el banco

El banco manda el movimiento pendiente y después el confirmado, y en varios
bancos **cambia el identificador**. Sin defensa entran dos veces.

**Tapa:** llave de idempotencia por movimiento y amarre obligatorio contra el
saldo del estado de cuenta. Si no amarra, el mes no cierra.

### 3.3 Asiento descuadrado por fallo a media escritura

Tres llamadas PostgREST no son una transacción: la segunda puede entrar y la
tercera no.

**Tapa:** el posteo va por función de Postgres (una transacción), con
restricción que rechaza el lote si debe ≠ haber. Nunca desde el navegador con
llamadas sueltas.

### 3.4 Fecha de frontera

Un cargo del 31 de diciembre a las 7 pm de Miami es 1 de enero en UTC.
Diciembre cierra mal.

**Tapa:** la fecha contable se guarda como `date` en hora de Miami, decidida al
entrar el movimiento. Nunca se deriva de un timestamp en la pantalla.

### 3.5 Dependencias que no controlas

Supabase, el conector del banco (Plaid/Teller), y las sesiones que escriben
este código. El banco rota autenticación y tumba la conexión cada tanto — eso
**va a pasar**, no es hipotético.

**Tapa:** el importador de CSV/OFX se queda para siempre como camino de
respaldo, aunque el conector automático funcione. Y el export mensual
(punto 5.6) hace que ningún proveedor sea dueño de tus libros.

### 3.6 La defensa que vale por todas: el export mensual

Cada cierre se exporta a Google Drive: balanza de comprobación, mayor completo,
y los estados de cuenta del mes. En CSV y en PDF.

Si mañana desaparecen Supabase, la app y quien la escribió, **tus libros
siguen siendo tuyos y son legibles**. Esto cuesta casi nada y elimina la mitad
del miedo de «ser tu propio proveedor».

---

## 6. El calendario

🔵 **azul = Fable 5.1, crea** · 🟢 **verde = Opus 5, trabaja encima**
· ▶ **necesita a Edgar**

Arranque: semana del lunes 21 de septiembre de 2026. Dos sesiones por semana.

| # | Semana | 🔵 Lo que crea Fable | 🟢 Lo que trabaja Opus |
|---|---|---|---|
| 1 | 21–27 sep | **Plan de cuentas entero.** Es el cimiento: la estructura y la decisión de si los cost codes (`01-DEMO…20-MISC`) son subcuentas o dimensión — **eso amarra la Fase 9**. ▶ Edgar dicta. | El SQL numerado y comentado para pegar. ▶ Pegar. |
| 2 | 28 sep–4 oct | **El libro.** `cuentas`, `asientos`, `asiento_lineas`, `periodos`; la función de posteo, el cuadre obligatorio, la inmutabilidad y el bloqueo de período. Todo lo demás se apoya aquí. | Las pruebas que lo atacan: asiento descuadrado, escritura en mes cerrado, intento de borrado. ▶ Pegar. |
| 3 | 5–11 oct | **El primer puente** (`facturas`→CxC) y el contrato que siguen todos. ▶ Edgar define el mapeo y el reconocimiento de ingreso. | Los otros tres con el mismo molde: `recibos`, `gastos_generales`, `horas`. |
| 4 | 12–18 oct | **El mapeo del mayor a los estados.** Dónde cae cada cuenta en balance y en resultados, con sus signos. | Balanza, comparativos, y el clic hasta el asiento. ▶ **Edgar audita contra QuickBooks.** |
| 5 | 19–25 oct | **El esqueleto de `js/conta.js`** y el patrón de falla ruidosa (punto 5.1) que obedece toda pantalla. | Las pantallas sobre ese esqueleto, y el clic del asiento al recibo con foto. |
| 6 | 26 oct–1 nov | **Idempotencia y conciliación.** El pendiente que se vuelve confirmado cambiando de ID es donde se corrompen los libros callados. | Los lectores de CSV/OFX, uno por banco. ▶ Edgar manda un archivo de cada cuenta. |
| 7 | 2–8 nov | **El motor de reglas y el contrato de la IA** — qué se le pregunta, qué puede contestar, cómo se sella lo que propone. | La pantalla, el editor de reglas, y el Opus a `effort: low` para el volumen. ▶ Edgar dicta sus reglas. |
| 8 | 9–15 nov | **El cierre y la ronda nocturna de controles.** Qué se vigila, en qué orden, qué detiene el cierre. | Export a Drive, avisos, historial. ▶ Cerrar octubre de prueba. |
| 9 | 16–22 nov | **Costo por obra y estimado contra real, entero.** La fase más difícil y la que justifica el proyecto: casar gasto real con receta y cost code, y devolverle la corrección al estimador. | Las pantallas y los reportes. ▶ Edgar valida contra una obra que se sepa de memoria. |
| 10 | 23–29 nov | **WIP, avance y retención.** Porcentaje de avance, sobre y sub-facturación, schedule of values. ▶ Edgar define el método. | Catálogo de servicios desde `catalogo_items`, plantillas de factura, y el paquete del GC (seguros y licencia desde `documentos_empresa`). |
| 11 | 30 nov–6 dic | **El reparto del burden a la obra.** Cómo aterriza cada parte de `benefits_detalle` sobre las horas de un proyecto. | La plomería contra la API de Gusto o Check. ▶ **Contratado ya.** |
| 12 | 7–13 dic | — | Carga de apertura y preparación de los 1099-NEC. ▶ Saldos de QuickBooks y W-9 de los subs. |
| 13–14 | 14–27 dic | Solo la diferencia que se resista: una que no cede es fallo de diseño, y el diseño es suyo. | Las diferencias de rutina, una por una. ▶ Casi todo de Edgar: diciembre en los dos sistemas. |
| 15 | 28 dic–3 ene | — | Saldos al 31-dic y verificación. ▶ Visto bueno → **1 de enero de 2027: en vivo.** |

### Después del corte — lo que no cabe antes, y está bien que no quepa

Al 1 de enero cruza **el libro**, que es lo que no puede esperar. Estas dos
llegan después a propósito: la IA necesita libros con datos reales encima
para tener algo que auditar.

| # | Cuándo | Fase | Color |
|---|---|---|---|
| 16 | enero 2027 | **El contador de guardia.** 🔵 Fable diseña la IA entera: qué vigila, cómo explica el descuadre, cómo propone el reverso, cómo huele lo raro. 🟢 Opus arma la bandeja de aprobación y la conversación. |
| 17 | febrero 2027 | 🟢 **Paquete fiscal** para el CPA y pulido del primer cierre real. |

- 🔵 **Ene–mar 2027:** QuickBooks vivo en solo lectura; el CPA cierra 2026 desde ahí. ~$300 de seguro barato.
- **~Abril 2027:** se cancela QuickBooks.

### Las cinco semanas donde de verdad te necesito

| Semana | Qué tienes que traer |
|---|---|
| **1** · 21–27 sep | El plan de cuentas dictado por ti |
| **3** · 5–11 oct | Mapeo de gasto a cuenta y criterio de reconocimiento |
| **11** · 30 nov–6 dic | Gusto/Check contratado — **el trámite empieza a primeros de noviembre** |
| **12** · 7–13 dic | Saldos de QuickBooks y los W-9 de los subs |
| **13–14** · 14–27 dic | Diciembre llevado en los dos sistemas |

---

## 7. Cómo gastar poco crédito

1. **Una fase por sesión, dicha por número.** «Hagamos la Fase 4.»
2. **Archivos nuevos**, para no abrir `app.js` nunca.
3. **SQL primero.** Si lo puede hacer una vista de Postgres, no se escribe en
   JavaScript. Menos código que leer y que arreglar.
4. **Este archivo es la memoria.** Al terminar cada fase se marca aquí. La
   sesión siguiente lee esto, no el repositorio.
5. **Dos sesiones por semana, no cinco.** Cada sesión paga un costo fijo de
   orientarse. Cinco sesiones chicas pagan ese costo cinco veces por el mismo
   trabajo. Dos sesiones largas rinden lo mismo por menos de la mitad.
6. **No pidas «revisa todo».** Pide el paso que sigue.
7. **El azul se paga en el diseño, no en el relleno.** Fable crea el primer
   puente; Opus hace los otros tres con el mismo molde. Fable escribe el
   esqueleto de la pantalla; Opus cuelga las demás. Lo caro se compra una vez
   y se multiplica barato.
8. **Dentro de la app también: solo Opus y Fable** (punto 4). Lo que se
   regula es el **esfuerzo**, no el modelo — `effort: low` en lo repetitivo,
   prefijo cacheado y Batches a mitad de precio.

---

## 8. Dónde le ganamos a QuickBooks

QuickBooks es bueno llevando un libro. Es malo entendiendo una obra. Esa es la
grieta, y tus datos ya están del lado bueno.

1. **Costo por obra en vivo, no al cierre.** Las horas y los recibos ya entran
   marcados por proyecto desde la obra. El margen se sabe hoy, no el día 10 del
   mes que viene.
2. **Estimado contra real, al nivel de la receta.** Esto no lo hace ningún
   programa comprado, porque ninguno tiene tu estimador. Tú puedes comparar lo
   que de verdad costó instalar un receptáculo contra lo que el estimador dijo
   que costaba, y **devolverle esa corrección al estimador**. Ese circuito
   cerrado es el premio de todo el proyecto.
3. **WIP y sobre/sub-facturación.** QuickBooks no lo trae. Es lo primero que
   pide un banco o una afianzadora.
4. **Burden real.** Ya tienes `benefits_detalle` desglosado (FICA, FUTA, paro de
   Florida, workers comp, GL, vacaciones, seguro médico). QuickBooks aplica una
   tasa sola y pareja.
5. **Flujo de caja desde el cronograma, no desde el histórico.** Tienes `hitos`,
   `facturas` y `cobros_pendientes`: se puede proyectar cuándo factura cada hito
   y cuándo entra ese dinero. QuickBooks adivina mirando el pasado.
6. **Retención bien modelada.** En QuickBooks es un parche.
7. **Facturación que sabe de obra.** QuickBooks factura como si vendieras
   cajas. Tú vendes avance de obra. Con `hitos`, `catalogo_items` y
   `ensambles` ya puestos: catálogo de servicios que sale de tu propio
   estimador, facturación por hito y por porcentaje de avance, schedule of
   values estilo AIA, retención descontada sola, y el paquete que el GC exige
   — certificado de seguro y licencia desde `documentos_empresa`, sin
   buscarlos cada vez.
8. **Sin costo por usuario.** Tu cuadrilla ya usa la app.

---

## 9. Dónde vamos

🔵 azul = Fable crea · 🟢 verde = Opus trabaja encima · ▶ necesita a Edgar

- [ ] Fase 1 · Plan de cuentas — 🔵 ▶ lo dictas tú
- [ ] Fase 2 · El libro — 🔵🟢
- [ ] Fase 3 · Puentes automáticos — 🔵🟢 ▶ el mapeo es tuyo
- [ ] Fase 4 · Estados financieros — 🔵🟢 ▶ auditas contra QuickBooks
- [ ] Fase 5 · Primera pantalla — 🔵🟢
- [ ] Fase 6 · Banco y tarjetas — 🔵🟢 ▶ mandas los archivos
- [ ] Fase 7 · Categorización — 🔵🟢 ▶ dictas las reglas
- [ ] Fase 8 · Cierre y alarmas — 🔵🟢
- [ ] Fase 9 · Costo por obra + estimado vs. real — 🔵 ▶ validas
- [ ] Fase 10 · Facturación, WIP y retención — 🔵🟢 ▶ método de avance
- [ ] Fase 11 · Puente de nómina — 🔵🟢 ▶ **Gusto/Check: tramitar en noviembre temprano**
- [ ] Fase 12 · Apertura y 1099 — 🟢 ▶ saldos y W-9
- [ ] Fases 13–14 · Marcha en paralelo — 🟢 ▶ casi todo tuyo
- [ ] Fase 15 · Amarre — 🟢 ▶ → **1 de enero en vivo**
- [ ] Fase 16 · El contador de guardia — 🔵🟢 (enero)
- [ ] Fase 17 · Paquete fiscal — 🟢 (febrero)
