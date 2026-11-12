# Fase 10 · Facturación, WIP y retención
**16 – 22 nov · 🔵 AZUL el WIP y el retiro de `qb` · 🟢 VERDE la plantilla básica y el desvío · ▶ el método es tuyo**

> QuickBooks factura como si vendieras cajas. Tú vendes avance de obra. Y desde
> el 1 de enero facturas aquí: **la función `qb` se apaga**.

## Tú
1. **Definir el método de avance**: costo incurrido sobre **costo total
   estimado revisado**, o por hitos. Coherente con tu respuesta de la Fase 3.
   El hito de depósito nunca es avance: el WIP lo lleva a 2400 hasta que haya
   costo.
2. En cada cierre (▶), revisar el **costo estimado a terminar** de cada obra
   abierta. Sin eso el % de avance se calcula contra el bid y una obra pasada
   de costo enseña 110 %.
3. Elegir la serie de factura (recomendado: serie propia por año; las de
   QuickBooks conservan su número) y subir la acción de factura por email en
   `correo`.

## 🔵 Azul — se crea (`/effort max`)

- **Dónde vive el WIP.** `alcances` extendida (tipo `'CO'`, `estado`
  propuesto/aprobado/rechazado, `aprobado_el`, `documento_id`); el precio del
  contrato para el WIP es la suma de alcances aprobados y
  `finanzas_proyecto.contrato` se declara base o pasa a vista (una sola
  fuente). Tabla por (obra, mes) solo para lo que **no** se deriva:
  `costo_estimado_total_revisado` con quién y cuándo lo revisó. Costo a la
  fecha y facturado a la fecha son vistas sobre `asiento_lineas`. Vista
  `wip_schedule`: % de avance, ingreso devengado, sobre (2400) y
  sub-facturación (1200), utilidad estimada — **el formato que pide la
  afianzadora**. El ajuste de WIP es asiento de cierre `reversible`.
  **Provisión por pérdida:** si costo estimado > precio, Dr 5950 / Cr 2410 por
  la pérdida completa ese mes.
- **Retención:** 1120 por cobrar y 2020 por pagar a subs, descontada sola en
  cada factura y liberada al cierre.
- **El retiro de `qb`.** El contrato del documento factura (PDF, envío,
  reenvío, anulación = nota de crédito, **nunca borrado**), la numeración
  asignada por Postgres desde `contadores`, y la fecha de corte configurable
  desde la que 🧾 y los enlaces «Nueva factura/estimado en QuickBooks»
  (`app.js` 1621-1622 y 3484-3540) van por el camino nuevo. `qb` **sigue viva
  hasta el 31-dic** porque diciembre se lleva en los dos sistemas; se apaga en
  f15.

## 🟢 Verde — se trabaja encima (`/effort auto`)
- **Plantilla básica de factura**: por hito (`hitos`), por porcentaje simple y
  T&M — sin línea de impuesto mientras no se venda material suelto. **Es
  requisito del corte: el 2 de enero hay que poder facturar.** **En inglés**
  (todo lo que ve el cliente; CONTA-PLAN §1 «Idioma»), con el bloque «How to
  pay» y, si Edgar lo pide, el enlace de pago de Stripe (p1).
- `crearAlcance` (hoy `alcances` solo se lee); ligar el `co` de texto de
  `horas`/`recibos` al renglón de `alcances`; la factura de avance lista los
  COs aprobados por renglón.
- PDF y envío por la función `correo`; el parche chico en `app.js` para el
  desvío de 🧾.
- **Catálogo de servicios, SOV AIA G702/G703 y paquete del GC: Fase 18.** No
  son requisito del 1 de enero, y sacarlos de aquí es lo que libera el colchón.

## Entregable
`docs/conta/c11-emision.sql` (la factura) y `docs/conta/c12-wip.sql` (el WIP) ·
la función de borde `supabase/functions/facturas/` (el PDF y el envío) ·
las páginas «Facturas» y «WIP» de Contabilidad · el desvío de 🧾 en `js/app.js`.
(El nombre `c10` lo tomó la Fase 9: `c10-costo-obra.sql`.)

## Terminó cuando
Emites una factura de avance desde la app, numerada, con su retención
descontada y su PDF enviado; el WIP del mes te dice si estás sobre o
sub-facturado por obra **contra el estimado revisado**; y una obra con costo
estimado mayor que el precio muestra su pérdida provisionada.

## Lo construido (12-nov)

Decisiones de Edgar del 11 y 12-nov: avance **costo a costo** (costo a la fecha
÷ costo total estimado revisado en cada cierre); numeración **MXP-2027-0001**,
una serie por año, sin huecos; pago en línea **solo por cuenta de banco
(ACH)** por ahora.

### La factura (c11, `fn_emision_*`)
- **El borrador es de c11**, no de `facturas`: una fila de `facturas` la leen
  el portal, la función `qb` y la ficha, y un borrador ahí saldría como
  factura abierta. La fila de `facturas` nace al **emitir**, ya emitida, como
  nacen hoy las de QuickBooks; desde ahí el ciclo de c3 se usa entero (su
  puente la contabiliza, su guarda la congela, su anulación hace la nota de
  crédito).
- **Tres formas**: por hito, por porcentaje del contrato y T&M (líneas de
  horas, material y otro). Sin línea de impuesto. Todo lo que ve el cliente,
  en inglés (si un texto parece español, frena hasta que se confirme).
- **Emitir es todo o nada**: el número, la fila de `facturas` y su asiento
  (Dr 1110 lo que se paga + Dr 1120 la retención / Cr ingreso) en la misma
  transacción, comprobados al centavo. Si el libro no la acepta, no queda
  nada, tampoco el número. Si lo que se ve cambió entre mirar y emitir (otra
  pestaña, los ajustes, otra factura de la obra, otro día), no emite y pide
  mirarlo otra vez (MX011).
- **El número** lo da Postgres desde `contadores` (serie «facturas-AAAA»),
  por un trigger: la única función SECURITY DEFINER de c10 a c12, y nadie la
  puede llamar. Si una factura hecha fuera de la app ya tiene un número de la
  serie, ese número se salta y se dice.
- **Retención en dólares**: `round(monto × % × 0.01, 2)`, una vez por
  factura. El % lo pone Edgar por obra (o sale del estimado). La **factura de
  la retención** lleva su propia serie (MXP-R-AAAA-NNNN), no tiene asiento (el
  ingreso ya entró) y lista lo retenido en cada factura que reclama; una
  factura cuya retención está reclamada no se anula.
- **Solo se factura un hito pendiente.** Uno que la ficha ya tiene como
  facturado o cobrado (por ejemplo, facturado en QuickBooks a mano) no se
  factura otra vez.
- **Anular** = nota de crédito de c3, nunca borrado; el hito vuelve a
  pendiente. No se anula con un pago por cuenta de banco en camino.
- **El corte**: desde el 1-ene-2027 (configurable) el 🧾 de cada hito abre la
  factura aquí; antes, va a QuickBooks como siempre. Ante la duda (la base no
  contesta claro) no factura nada y lo dice. El corte no se pone después de
  una factura emitida por la app sin anular.
- **El pago en línea**: el enlace lo pide la función «facturas» a p1 (función
  `stripe`, por lo que el libro dice que se debe) y lo deja **solo por cuenta
  de banco** en Stripe antes de imprimirlo; si Stripe no deja, el PDF sale sin
  enlace. **La tarjeta está apagada**: p1 (sellado) registraría el recargo
  como un anticipo de la obra, no como un ingreso; se enciende cuando p1 lo
  sepa asentar.
- **El PDF y el envío** (función `facturas`): el PDF desde el contenido
  congelado de la factura, guardado en el bucket privado «facturas» con su
  sha256; el correo por Resend con el remitente de la casa, copia a Edgar y el
  PDF adjunto. El envío queda apuntado en la factura (`emision_envios`). La
  función no escribe en la tabla `correos` (es del cartero de la otra sesión
  y el dueño solo la lee).
- **El bucket «facturas»** solo lo lee y sube el dueño **con el código del
  teléfono** (aal2): la contraseña sola no abre los PDF.
- **16 controles** (`v_emision_control`). El cierre los mira: un cuadre en
  rojo detiene (fila 172) y los avisos avisan (fila 173); el nombre de la fila
  dice cuáles están en rojo.

### El WIP (c12, `fn_wip_*`)
- **Por obra de precio fijo y por mes**: % de avance = costo a la fecha ÷
  costo total estimado revisado; ingreso ganado = precio × %; contra lo
  facturado sale sub-facturado (1200) o sobre-facturado (2400). El precio es
  `finanzas_proyecto.contrato` (los hitos lo reparten en todas las obras).
- **La revisión del mes**: Edgar pone el costo total estimado de cada obra.
  No puede ser menos que lo ya gastado. Una obra que pasa de su estimado no
  entra en el ajuste hasta subirlo.
- **El ajuste** es un asiento de cierre reversible: el último día del mes, y
  su reverso solo el día 1 del siguiente.
- **La pérdida**: si el costo estimado pasa del precio, la pérdida entera ese
  mes (Dr 5950 / Cr 2410).
- **Lo de antes del libro**: en las obras que ya andaban el 30-sep, su costo
  y lo facturado hasta esa fecha (de QuickBooks o del contador). Sin eso la
  obra no entra, y el cierre lo dice y se detiene.
- **Nadie sale solo del WIP**: una obra que traía saldo sigue hasta que lo
  facturado sea su precio, o hasta que Edgar la deje fuera ese mes con una
  nota. Una obra con facturas en el libro que la app no tiene «en obra»
  (por ejemplo, el depósito de una propuesta todavía «enviada») sale en un
  aviso.
- **El formato de la afianzadora** (`v_wip_schedule`): contrato, costo a la
  fecha, estimado, %, ganado, facturado, sobre y sub, utilidad estimada.
- **17 controles** (7 cuadres y 10 avisos). El cierre los mira en las filas
  174 (cuadres), 175 (cada obra revisada), 176 (el ajuste posteado y al día),
  que detienen, y 177 (avisos). Se exige desde el mes en que se pega c12
  (`wip_config.exigir_desde`, se cambia en WIP → Ajustes).

### Quién lo hizo y cómo se probó
Fable en las dos bases, en la revisión contra el dinero, en sus arreglos y en
la revisión final; Opus 5.5 en las pantallas, la función de borde y la
verificación desde cero. Tres revisiones independientes (desde cero, contra
el dinero y la final). Lo más serio que encontraron: una obra que salía sola
del WIP con su saldo, un hito que se podía facturar dos veces (de dos
maneras), los PDF que se abrían sin el código del teléfono, el mes que
cerraba en verde con obras fuera del ajuste y una nota cualquiera que
saltaba el estimado. Todo corregido, cada arreglo con su prueba que falla con
la capa de antes y pasa con la de ahora. Desde cero: c11-pruebas 51 y c12-pruebas 48 en verde, las suites de
c2 a c10 en verde, la concurrencia de c10, c11 y c12, la función de punta a
punta (también en Deno), y la pantalla a 390, 820 y 1280 px.

### Lo que queda dicho y no hecho
- **La tarjeta**: hace falta una versión de p1 que asiente el recargo como
  ingreso, y confirmar con Stripe y el CPA las reglas del recargo en Florida.
- **La 2020** (retención por pagar a subcontratistas): necesita un campo en
  la app y otra versión del puente de gastos de c3. Hasta entonces lo
  retenido a un sub entra al costo el día que se paga.
- **La nota de crédito parcial** no existe: se anula entera y se hace otra.
- **Quién marca «pagada» en la ficha después del corte**: hoy lo hace la
  rutina de `qb` desde QuickBooks; las facturas de la app no están ahí. El
  aviso 64 dice cuál ya está cobrada en el libro; mientras, a mano.
- **Una apertura con saldo en 1200/2400** no se continúa sola: el CPA decide
  si la apertura entra sin WIP.
- **Del verde que se movió**: `crearAlcance`, ligar el CO de texto de
  horas y recibos a `alcances`, y la factura de avance por renglón de CO
  quedan para la Fase 18 con el SOV.

### Tú (lo que falta de tu lado)
1. Pegar `c11-emision.sql`, `c12-wip.sql` y **otra vez** `c9-cierre.sql`
   (trae las filas 172 a 177 y el código del teléfono en el bucket
   «cierres»); después `c9-pruebas.sql`, `c11-pruebas.sql` y
   `c12-pruebas.sql`, sin ninguna en falso.
2. Desplegar la función «facturas» (Verify JWT apagado; los secretos ya
   están) y comprobar «salud».
3. Facturas → Ajustes: los datos de la empresa, el «How to pay» en inglés y
   los términos; la retención de cada obra que la lleve.
4. WIP: lo de antes del libro de cada obra que ya andaba; cada mes, el costo
   estimado de cada obra y «Postear el ajuste» antes de cerrar.
5. Decidir desde qué mes lo exige el cierre (de fábrica, el mes en que se
   pega) y confirmar el método con el CPA.
6. Probar la emisión antes del corte **solo con una obra de prueba**.
