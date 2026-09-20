# La contabilidad dentro de la app — el plan

**Para qué existe este archivo:** para que cualquier sesión que trabaje la
contabilidad lea **este archivo solo** y ya sepa todo: qué se decidió, en qué
fase vamos, qué archivos toca y qué archivos no. Sin volver a explorar el
repositorio entero. Eso es lo que hace que esto salga barato en crédito.

**El verde y el azul:** cada paso del plan va etiquetado. 🟢 **verde** lo
hace la sesión sola; 🔵 **azul** necesita a Edgar. Un azul pendiente
**detiene la fase** — no se adivina. La tabla completa está en el punto 4.

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

## 3. Lo que se puede romper, y con qué se tapa

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
(punto 3.6) hace que ningún proveedor sea dueño de tus libros.

### 3.6 La defensa que vale por todas: el export mensual

Cada cierre se exporta a Google Drive: balanza de comprobación, mayor completo,
y los estados de cuenta del mes. En CSV y en PDF.

Si mañana desaparecen Supabase, la app y quien la escribió, **tus libros
siguen siendo tuyos y son legibles**. Esto cuesta casi nada y elimina la mitad
del miedo de «ser tu propio proveedor».

---

## 4. El calendario — cada paso en verde o en azul

**La convención, para que no se pierda:**

| | Qué quiere decir |
|---|---|
| 🟢 **VERDE** | Lo hace la sesión sola. Código, SQL, vistas, pruebas. Edgar no tiene que estar. |
| 🔵 **AZUL** | Necesita a Edgar. Pegar el SQL en Supabase, decidir criterio contable, contratar algo, auditar contra QuickBooks, dar el visto bueno. |

Ningún paso va sin etiqueta. Si un paso es azul, **no arranca la fase** hasta
que Edgar lo hizo: la sesión que llega y encuentra un azul pendiente lo dice y
se detiene, no lo adivina.

Arranque: semana del lunes 21 de septiembre de 2026.
Ritmo: **dos sesiones por semana** (sugerido martes y viernes), una fase por
semana.

### Fase 1 · Plan de cuentas — 21 al 27 de septiembre
- 🔵 Edgar dicta las cuentas: gastos, ingresos, cómo quiere agrupar.
- 🔵 Edgar decide si los cost codes (`01-DEMO … 20-MISC`, que ya viajan en el takeoff) son subcuentas o son dimensión aparte. **Esta decisión amarra la Fase 9**, así que se piensa aquí.
- 🟢 Estructurarlo y numerarlo en `docs/conta/c1-plan-de-cuentas.sql`.
- 🔵 Pegarlo en Supabase.

### Fase 2 · El libro — 28 de septiembre al 4 de octubre
- 🟢 `c2-libro.sql`: `cuentas`, `asientos`, `asiento_lineas`, `periodos`; posteo por función de Postgres, restricción de cuadre, bloqueo de período.
- 🟢 Pruebas: que rechace un asiento descuadrado y que rechace escribir en período cerrado.
- 🔵 Pegarlo en Supabase y confirmar que corrió.

### Fase 3 · Puentes automáticos — 5 al 11 de octubre
- 🔵 Edgar define el mapeo: qué cuenta recibe cada tipo de gasto, y cuándo se reconoce el ingreso (a la factura, al hito, por avance).
- 🟢 `c3-puentes.sql`: `facturas` → CxC, `recibos`/`gastos_generales` → gasto, `horas` → mano de obra.
- 🔵 Revisar una muestra de asientos generados contra lo que él habría hecho a mano.

### Fase 4 · Estados financieros — 12 al 18 de octubre
- 🟢 `c4-estados.sql`: balanza, estado de resultados, balance general, como vistas.
- 🔵 Pegarlo.
- 🔵 **Edgar audita contra QuickBooks del mismo período.** Primera prueba de verdad. Si esto no amarra, no se sigue a la Fase 5.

### Fase 5 · Primera pantalla — 19 al 25 de octubre
- 🟢 `js/conta.js`: balanza y P&L con clic hasta el asiento, y del asiento al recibo con su foto.
- 🟢 Parche chico a `index.html` y `sw.js` (versión) y una línea en `app.js`.
- 🔵 Edgar la abre y dice qué falta.

### Fase 6 · Banco y tarjetas — 26 de octubre al 1 de noviembre
- 🔵 Edgar baja un CSV/OFX de cada cuenta y cada tarjeta y los manda. **Sin eso no se puede escribir el importador.**
- 🟢 Importador, tabla de movimientos, llave de idempotencia, conciliación.
- 🔵 Primera importación real.

### Fase 7 · Categorización — 2 al 8 de noviembre
- 🔵 Edgar dicta las reglas que ya tiene en la cabeza (este proveedor siempre va a esta cuenta).
- 🟢 Motor de reglas que aprende, y la pantalla.
- 🔵 Categorizar un mes real a mano para que agarre patrón.

### Fase 8 · Cierre mensual — 9 al 15 de noviembre
- 🟢 Bloqueo de período, reporte de amarre, export automático a Drive.
- 🔵 Dar el permiso de Drive.
- 🔵 Cerrar octubre de prueba, de principio a fin.

### Fase 9 · Costo por obra + estimado vs. real — 16 al 22 de noviembre
- 🔵 Edgar decide cómo se compara: por cost code, por receta, o por los dos.
- 🟢 Todo el cálculo y la pantalla.
- 🔵 **Validar contra una obra cerrada que él se sepa de memoria.** Si el número no coincide con lo que él sabe que pasó, el cálculo está mal.

### Fase 10 · WIP y retainage — 23 al 29 de noviembre
- 🔵 Edgar define el método de avance (costo incurrido sobre costo total estimado, o por hitos).
- 🟢 Implementar, con retención bien modelada.
- Semana corta por Thanksgiving.

### Fase 11 · Puente de nómina — 30 de noviembre al 6 de diciembre
- 🔵 **Edgar contrata Gusto o Check y saca las llaves.** Esto es de él, no de la sesión.
- 🔵 Edgar decide si la nómina entra como resumen o empleado por empleado.
- 🟢 El puente: `horas` → proveedor, y nómina → repartida por obra con el burden real de `benefits_detalle`.

> ⚠️ **Este azul tiene plazo y hay que empezarlo antes.** Dar de alta una
> nómina con el estado toma semanas, no días. Y cambiar de proveedor a mitad
> de trimestre parte los 941 en dos. **Arranca el trámite a principios de
> noviembre** para que la primera nómina en Gusto caiga el **1 de enero**,
> junto con el corte de los libros. Trimestre limpio, año limpio.

### Fase 12 · Apertura y 1099 — 7 al 13 de diciembre
- 🔵 Edgar saca de QuickBooks los saldos al 30 de noviembre.
- 🔵 Edgar junta los W-9 de los subcontratistas (TIN y dirección). Casi siempre falta alguno; por eso se pide en diciembre y no en enero.
- 🟢 Carga de apertura y preparación de los 1099-NEC.

### Fases 13 y 14 · Marcha en paralelo — 14 al 27 de diciembre
- 🔵 **Casi todo azul.** Edgar lleva diciembre en los dos sistemas y los compara.
- 🟢 La sesión arregla cada diferencia que aparezca.
- Es la fase que quita el miedo. No se acorta.

### Fase 15 · Amarre y arranque — 28 de diciembre al 3 de enero
- 🔵 Saldos finales al 31 de diciembre, cuadrados.
- 🟢 Carga y verificación.
- 🔵 **Edgar da el visto bueno.** → **1 de enero de 2027: en vivo.**

### Después del arranque
- 🔵 **Ene–mar 2027:** QuickBooks se deja vivo en solo lectura. El CPA cierra 2026 desde ahí, como siempre. Unos $300 de seguro barato.
- 🔵 **~Abril 2027:** se cancela QuickBooks.
- 🔵 **Principios de 2028:** el CPA recibe el paquete fiscal desde la app por primera vez, con un año completo ya probado detrás.

### Las cinco semanas donde de verdad te necesito

El resto de los azules son pegar un SQL y mirar una pantalla. Estas cinco
llevan trabajo tuyo y criterio tuyo, y si llegan sin preparar, la fase se cae:

| Semana | Qué tienes que traer |
|---|---|
| **1** (21–27 sep) | El plan de cuentas dictado por ti |
| **3** (5–11 oct) | El mapeo de gasto a cuenta y el criterio de reconocimiento de ingreso |
| **11** (30 nov–6 dic) | Gusto o Check ya contratado — **el trámite empieza a principios de noviembre** |
| **12** (7–13 dic) | Saldos de QuickBooks y los W-9 de los subs |
| **13–14** (14–27 dic) | Diciembre llevado en los dos sistemas |

---

## 5. Cómo gastar poco crédito

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

---

## 6. Dónde le ganamos a QuickBooks

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
7. **Sin costo por usuario.** Tu cuadrilla ya usa la app.

---

## 7. Dónde vamos

`🔵` = esa fase necesita algo tuyo antes de arrancar.

- [ ] Fase 1 · Plan de cuentas — 🔵 lo dictas tú
- [ ] Fase 2 · El libro — 🟢 (solo pegar el SQL al final)
- [ ] Fase 3 · Puentes automáticos — 🔵 el mapeo es tuyo
- [ ] Fase 4 · Estados financieros — 🔵 tú auditas contra QuickBooks
- [ ] Fase 5 · Primera pantalla — 🟢
- [ ] Fase 6 · Banco y tarjetas — 🔵 mandas los CSV primero
- [ ] Fase 7 · Categorización — 🔵 dictas las reglas
- [ ] Fase 8 · Cierre mensual — 🟢 (cierras octubre de prueba)
- [ ] Fase 9 · Costo por obra + estimado vs. real — 🔵 validas contra una obra que te sepas
- [ ] Fase 10 · WIP y retainage — 🔵 defines el método de avance
- [ ] Fase 11 · Puente de nómina — 🔵 **trámite de Gusto/Check: empezarlo en noviembre temprano**
- [ ] Fase 12 · Apertura y 1099 — 🔵 saldos y W-9
- [ ] Fases 13–14 · Marcha en paralelo — 🔵 casi todo tuyo
- [ ] Fase 15 · Amarre y arranque — 🔵 das el visto bueno
