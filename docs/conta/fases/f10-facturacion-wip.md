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

## 🔵 Fable

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

## 🟢 Opus
- **Plantilla básica de factura**: por hito (`hitos`), por porcentaje simple y
  T&M — sin línea de impuesto mientras no se venda material suelto. **Es
  requisito del corte: el 2 de enero hay que poder facturar.**
- `crearAlcance` (hoy `alcances` solo se lee); ligar el `co` de texto de
  `horas`/`recibos` al renglón de `alcances`; la factura de avance lista los
  COs aprobados por renglón.
- PDF y envío por la función `correo`; el parche chico en `app.js` para el
  desvío de 🧾.
- **Catálogo de servicios, SOV AIA G702/G703 y paquete del GC: Fase 18.** No
  son requisito del 1 de enero, y sacarlos de aquí es lo que libera el colchón.

## Entregable
`docs/conta/c10-facturacion-wip.sql` · pantalla de facturación básica

## Terminó cuando
Emites una factura de avance desde la app, numerada, con su retención
descontada y su PDF enviado; el WIP del mes te dice si estás sobre o
sub-facturado por obra **contra el estimado revisado**; y una obra con costo
estimado mayor que el precio muestra su pérdida provisionada.
