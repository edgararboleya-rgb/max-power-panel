# La contabilidad dentro de la app — el plan

**Para qué existe este archivo:** para que cualquier sesión que trabaje la
contabilidad lea **este archivo solo** y ya sepa todo: qué se decidió, en qué
fase vamos, qué archivos toca y qué archivos no. Sin volver a explorar el
repositorio entero. Eso es lo que hace que esto salga barato en crédito.

**El verde y el azul — qué modelo trabaja cada fase:**

| | Modelo | Precio por millón de tokens |
|---|---|---|
| 🟢 **VERDE** | Claude Opus 5 (`claude-opus-5`) | $5 entrada / $25 salida |
| 🔵 **AZUL** | Claude Fable 5.1 (`claude-fable-5-1`) | $10 entrada / $50 salida |

**El azul cuesta el doble que el verde.** El ahorro está en no vivir en azul:
verde por defecto, azul solo donde un error se paga caro y no se ve de
inmediato (los invariantes del libro, el estimado contra real, la facturación
de avance, el diseño de la IA). Salen **4 fases azules de 17** — un cuarto
del proyecto en el modelo caro, tres cuartos en el barato.

Al empezar cada fase la sesión dice **«esta va en verde»** o **«esta va en
azul»**, y Edgar cambia el modelo antes de arrancar.

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

Aquí no manda el azul y el verde — eso es para la sesión. Dentro de la app se
elige por tarea, y es donde de verdad se ahorra:

| Tarea | Modelo | Por qué |
|---|---|---|
| Categorizar movimientos, casar recibos | `claude-haiku-4-5` ($1/$5) | Volumen alto, trabajo mecánico |
| Leer un recibo, resumir un mes | `claude-sonnet-5` ($2/$10) | Punto medio |
| El auditor nocturno, explicar el descuadre, conversar | `claude-opus-5` ($5/$25) | Es el que razona sobre los libros |

El plan de cuentas y las reglas se mandan como prefijo fijo con
`cache_control`, que es lo que hace barata la llamada repetida. Toda
categorización del mes entra por **Batches** (mitad de precio) cuando no corre
apurada.

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

🟢 **verde = Opus 5** · 🔵 **azul = Fable 5.1, el doble de caro**.
La sesión avisa el color al empezar la fase. Dentro de cada fase, lo que
**necesita a Edgar** va marcado con ▶.

Arranque: semana del lunes 21 de septiembre de 2026. Dos sesiones por semana.

| # | Semana | Fase | Color |
|---|---|---|---|
| 1 | 21–27 sep | **Plan de cuentas.** ▶ Edgar dicta las cuentas y decide si los cost codes (`01-DEMO…20-MISC`) son subcuentas o dimensión — **eso amarra la Fase 9**. ▶ Pegar el SQL. | 🟢 |
| 2 | 28 sep–4 oct | **El libro.** `cuentas`, `asientos`, `asiento_lineas`, `periodos`. Posteo por función, cuadre obligatorio, bloqueo, y el candado de que no se edita ni se borra (punto 3). ▶ Pegar. | 🔵 |
| 3 | 5–11 oct | **Puentes automáticos.** `facturas`→CxC, `recibos`/`gastos_generales`→gasto, `horas`→mano de obra. ▶ Edgar define el mapeo y el criterio de reconocimiento. | 🟢 |
| 4 | 12–18 oct | **Estados financieros** como vistas. ▶ **Edgar audita contra QuickBooks.** Si no amarra, no se sigue. | 🟢 |
| 5 | 19–25 oct | **Primera pantalla** (`js/conta.js`): balanza y P&L con clic hasta el asiento y del asiento al recibo con foto. | 🟢 |
| 6 | 26 oct–1 nov | **Banco y tarjetas.** Importador CSV/OFX, idempotencia, conciliación. ▶ Edgar manda un archivo de cada cuenta. | 🟢 |
| 7 | 2–8 nov | **Categorización.** Reglas + la IA que aprende (Haiku para el volumen). ▶ Edgar dicta sus reglas y categoriza un mes. | 🟢 |
| 8 | 9–15 nov | **Cierre mensual y las alarmas.** Bloqueo, amarre, export a Drive, **la ronda nocturna de controles y la IA que la narra**. ▶ Cerrar octubre de prueba. | 🟢 |
| 9 | 16–22 nov | **Costo por obra + estimado contra real.** La fase que justifica el proyecto. ▶ Edgar valida contra una obra que se sepa de memoria. | 🔵 |
| 10 | 23–29 nov | **Facturación, WIP y retención.** Catálogo de servicios desde `catalogo_items`, facturación por hito y por avance, schedule of values estilo AIA, retención, y el paquete que pide el GC (seguros y licencia desde `documentos_empresa`, lien waivers). ▶ Edgar define el método de avance. | 🔵 |
| 11 | 30 nov–6 dic | **Puente de nómina.** ▶ **Gusto o Check ya contratado.** Burden real por obra desde `benefits_detalle`. | 🟢 |
| 12 | 7–13 dic | **Apertura y 1099.** ▶ Saldos de QuickBooks y los W-9 de los subs. | 🟢 |
| 13–14 | 14–27 dic | **Marcha en paralelo.** ▶ Casi todo de Edgar: diciembre en los dos sistemas. La sesión arregla cada diferencia. | 🟢 |
| 15 | 28 dic–3 ene | **Amarre.** ▶ Saldos al 31-dic y visto bueno. → **1 de enero de 2027: en vivo.** | 🟢 |

### Después del corte — lo que no cabe antes, y está bien que no quepa

Al 1 de enero cruza **el libro**, que es lo que no puede esperar. Estas dos
llegan después a propósito: la IA necesita libros con datos reales encima
para tener algo que auditar.

| # | Cuándo | Fase | Color |
|---|---|---|---|
| 16 | enero 2027 | **El contador de guardia.** La IA completa: conversación sobre los libros, conciliación propuesta, detección de lo raro, nota del cierre. Sobre la bandeja de aprobación del punto 4. | 🔵 |
| 17 | febrero 2027 | **Paquete fiscal** para el CPA y pulido de lo que salga del primer cierre real. | 🟢 |

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
7. **El color es plata.** Fable cuesta el doble que Opus. 13 de las 17 fases
   van en verde. La sesión avisa el color al empezar; si no avisa, es verde.
8. **Dentro de la app, el modelo se elige por tarea** (punto 4): Haiku para el
   volumen, Opus solo para razonar sobre los libros. Con prefijo cacheado y
   Batches a mitad de precio donde no corre prisa.

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

🟢 verde = Opus 5 · 🔵 azul = Fable 5.1 · ▶ necesita a Edgar antes de arrancar

- [ ] 🟢 Fase 1 · Plan de cuentas — ▶ lo dictas tú
- [ ] 🔵 Fase 2 · El libro
- [ ] 🟢 Fase 3 · Puentes automáticos — ▶ el mapeo es tuyo
- [ ] 🟢 Fase 4 · Estados financieros — ▶ auditas contra QuickBooks
- [ ] 🟢 Fase 5 · Primera pantalla
- [ ] 🟢 Fase 6 · Banco y tarjetas — ▶ mandas los archivos
- [ ] 🟢 Fase 7 · Categorización — ▶ dictas las reglas
- [ ] 🟢 Fase 8 · Cierre mensual y alarmas
- [ ] 🔵 Fase 9 · Costo por obra + estimado vs. real — ▶ validas
- [ ] 🔵 Fase 10 · Facturación, WIP y retención — ▶ método de avance
- [ ] 🟢 Fase 11 · Puente de nómina — ▶ **Gusto/Check: tramitar en noviembre temprano**
- [ ] 🟢 Fase 12 · Apertura y 1099 — ▶ saldos y W-9
- [ ] 🟢 Fases 13–14 · Marcha en paralelo — ▶ casi todo tuyo
- [ ] 🟢 Fase 15 · Amarre → **1 de enero en vivo**
- [ ] 🔵 Fase 16 · El contador de guardia (enero)
- [ ] 🟢 Fase 17 · Paquete fiscal (febrero)
