# La contabilidad dentro de la app — el plan

**Para qué existe este archivo:** para que cualquier sesión que trabaje la
contabilidad lea **este archivo solo** y ya sepa todo: qué se decidió, en qué
fase vamos, qué archivos toca y qué archivos no. Sin volver a explorar el
repositorio entero. Eso es lo que hace que esto salga barato en crédito.

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

## 4. El calendario

Arranque: semana del lunes 21 de septiembre de 2026.
Ritmo: **dos sesiones por semana** (sugerido: martes y viernes), una fase por
semana. Diario no — se explica en el punto 5.

| # | Semana | Fase | Entrega |
|---|---|---|---|
| 1 | 21–27 sep | **Plan de cuentas y decisiones** | `docs/conta/c1-plan-de-cuentas.sql`. Edgar dicta las cuentas; la sesión las estructura. |
| 2 | 28 sep – 4 oct | **El libro** | `c2-libro.sql`: `cuentas`, `asientos`, `asiento_lineas`, `periodos`. Posteo por función, con cuadre obligatorio y bloqueo de período. |
| 3 | 5–11 oct | **Puentes automáticos** | `c3-puentes.sql`: `facturas` → CxC, `recibos`/`gastos_generales` → gasto, `horas` → mano de obra. Lo que ya capturas se vuelve asiento. |
| 4 | 12–18 oct | **Estados financieros** | `c4-estados.sql`: balanza, estado de resultados, balance general, como vistas. Postgres hace la matemática. |
| 5 | 19–25 oct | **Primera pantalla** | `js/conta.js`: balanza y P&L con clic hasta el asiento y del asiento al recibo con foto. |
| 6 | 26 oct – 1 nov | **Banco y tarjetas** | Importador CSV/OFX, tabla de movimientos, conciliación. Sin Plaid todavía. |
| 7 | 2–8 nov | **Categorización** | Reglas que aprenden del proveedor y del monto. Es el «Banking» de QuickBooks, hecho a tu medida. |
| 8 | 9–15 nov | **Cierre mensual** | Bloqueo de período, reporte de amarre, export automático a Drive. |
| 9 | 16–22 nov | **Costo por obra + estimado vs. real** | **La fase que justifica todo esto.** Ver punto 6. |
| 10 | 23–29 nov | **WIP y retainage** | Sobre y sub-facturación, retención. Semana corta por Thanksgiving. |
| 11 | 30 nov – 6 dic | **Puente de nómina** | Gusto o Check. Burden real por obra desde `benefits_detalle`. |
| 12 | 7–13 dic | **Apertura y 1099** | Saldos iniciales y preparación de los 1099-NEC de subcontratistas. |
| 13–14 | 14–27 dic | **Marcha en paralelo** | Diciembre real se lleva en los dos sistemas. Se comparan. Se corrigen diferencias. |
| 15 | 28 dic – 3 ene | **Amarre y arranque** | Saldos al 31-dic. **1 de enero de 2027: en vivo.** |

Después del arranque:

- **Ene–mar 2027:** QuickBooks se deja vivo y en solo lectura. El CPA cierra
  2026 desde QuickBooks, como siempre. Son unos $300 de seguro barato.
- **~Abril 2027:** se cancela QuickBooks.
- **Principios de 2028:** el CPA recibe el paquete fiscal desde la app por
  primera vez — con un año completo ya probado detrás.

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

- [ ] Fase 1 — Plan de cuentas
- [ ] Fase 2 — El libro
- [ ] Fase 3 — Puentes automáticos
- [ ] Fase 4 — Estados financieros
- [ ] Fase 5 — Primera pantalla
- [ ] Fase 6 — Banco y tarjetas
- [ ] Fase 7 — Categorización
- [ ] Fase 8 — Cierre mensual
- [ ] Fase 9 — Costo por obra + estimado vs. real
- [ ] Fase 10 — WIP y retainage
- [ ] Fase 11 — Puente de nómina
- [ ] Fase 12 — Apertura y 1099
- [ ] Fases 13–14 — Marcha en paralelo
- [ ] Fase 15 — Amarre y arranque
