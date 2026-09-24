# Fase 3 · Los puentes, los cobros y las cuentas por pagar
**5 – 11 oct · 🔵 AZUL el contrato, `facturas`, cobros y CxP · 🟢 VERDE `recibos`, `trabajos_externos`, `horas` y la apertura · ▶ el mapeo es tuyo**

> Aquí lo que ya capturas en la obra se vuelve asiento solo. Y aquí se decide
> **de dónde sale cada dólar**: si esto queda torcido, f09 y f11 lo heredan.

## Tú — y esto sí es criterio tuyo

1. **Mapeo de gasto a cuenta** (para el viernes 2-oct): qué cuenta recibe cada
   tipo de `recibo`, `material` y `trabajo_externo`. **`gastos_generales` NO se
   mapea**: es el presupuesto mensual del estimador (`monto_mensual`), no un
   gasto. Los gastos generales reales entran por banco y tarjeta (f06) y se
   categorizan en f07.
2. **Reconocimiento de ingreso**: a la factura (con ajuste de WIP al cierre
   desde f10) o por hitos. El hito de depósito nunca es avance.
3. **Forma de pago de los recibos**: confirmar si CED/Platt son a cuenta
   abierta (statement mensual, pago único que junta tickets) o se pagan al
   mostrador con tarjeta.
4. **Regla del documento tardío**: un recibo del 30 que llega el 3 con el mes
   cerrado se postea el día 1 del mes abierto con nota. Confírmalo o cámbialo.
5. Revisar una muestra de asientos generados contra lo que tú habrías hecho a
   mano.

## 🔵 Azul — se crea (`/effort max`)

- **El contrato** que siguen todos: idempotencia (un origen, un asiento;
  correr dos veces no duplica); **el papel no se toca** — columna
  `contabilizado_en` (asiento_id) en `recibos`, `facturas`, `horas`,
  `materiales` y `trabajos_externos`, y trigger que rechaza `update` de
  monto/fecha/obra y todo `delete` cuando no es nulo (el cambio es reverso +
  documento nuevo); un `proyecto` con documentos contabilizados no se borra, se
  archiva; policy de Storage **sin `delete`** para `authenticated` en
  `recibos/` y `docs/`; `recibos.llave_cliente text unique`; el documento
  tardío según la regla de Edgar; **guardarraíl de apertura**: nada fechado
  antes del 1-oct-2026 postea por puente.
- **`facturas` → Dr 1110 (y 1120 la retención) / Cr 4010/4020/4030/4040** al
  pasar a `emitida`. Ciclo de vida: `estado` borrador→emitida, número propio
  asignado por Postgres (serie por año; las de QuickBooks conservan su `num`),
  **una factura emitida no se edita ni se borra**: se anula con nota de crédito
  enlazada (`anula_a`). f10 pone las plantillas encima.
- **El quinto puente — los cobros.** `cobros` / `aplicaciones_cobro`
  (movimiento_id, factura_id, fecha contable, monto, medio, referencia, cuenta
  bancaria, `es_retencion`, `descuento`) → Dr 1010 / Cr 1110 (o 1120) por lo
  aplicado. Parciales, un cobro a varias facturas, cobro de retención,
  anticipo aplicado. `facturas.pagada` y `finanzas_proyecto.cobrado` se
  mantienen **por trigger** desde `cobros`; la casilla manual se retira en f15.
  El casado con el depósito del banco es de f06.
- **Cuentas por pagar.** `recibos.forma_pago` CHECK (`'cuenta_proveedor'`,
  `'tarjeta'`, `'banco'`, `'efectivo'`, `'reembolso'`) **sin default** — un
  recibo sin forma de pago no postea: queda en bandeja — o derivada de
  `proveedores.terminos` y escrita en la procedencia. Tabla `proveedores`
  (nombre, términos; en f12 TIN, dirección, tipo, W-9, COI). Cada recibo a
  cuenta es una **línea abierta de 2010 por proveedor**; el pago se aplica a
  líneas abiertas (f06); el statement del supply es la conciliación (f08). Lo
  que paga Edgar de su bolsillo va a 2900; lo de un empleado, a reembolsos por
  pagar.
- **Horas.** `horas.aprobado_por`, `aprobado_el` (Edgar aprueba por período de
  nómina desde `conta.js`, un toque por empleado). **`horas` no postea
  dólares**: es la clave de reparto (vista
  `horas_aprobadas_por_obra_periodo`). Único asiento opcional: devengo de
  cierre Dr 5000 / Cr 2210 por horas × `costos_equipo.costo_hora`,
  `reversible = true`, reversado el día 1 y etiquetado «estándar».
  **La única fuente de dólares de 5000/5010 es el journal del proveedor (f11).**
- **La apertura como puente más**: origen = balanza de QuickBooks al 30-sep en
  PDF, procedencia `apertura`, período `2026-09-APERTURA` marcado `paralelo`;
  qué cuentas llevan dimensión (CxC por factura y retención por obra, CxP por
  proveedor, 1200/2400 por obra cuando exista WIP) y de dónde sale el desglose
  (QuickBooks no lo trae por obra: Edgar lo aporta o valida). La carga es 🟢 de
  f04.

## 🟢 Verde — se trabaja encima (`/effort auto`)

- `recibos` → Dr 5100 (obra, cost code, **total con impuesto incluido**; nunca
  una línea a 2300 desde un recibo) / Cr 2010-proveedor, 2100-x, 1010 o 2900
  según `forma_pago`; con `impuesto_pagado` desconocido postea el total y no
  toca 2300.
- `trabajos_externos` → Dr 5200 (obra) / Cr 2010 (devengado; el pago lo cancela
  el banco en f06).
- La vista de horas aprobadas; el devengo reversible si Edgar lo quiere.
- Backfill idempotente de las filas desde el 1-oct. Parche de ~5 líneas a
  `formMano`/`formRecibo` (`llave_cliente: llaveUnica()`, 409 = «ya estaba»),
  copiando el fallback de `db.js` para cuando la columna no exista. Botón
  «reintentar puente».
- Prueba con el molde de f02: borrar un recibo contabilizado → rechazado;
  editar su monto → rechazado.

## Entregable
`docs/conta/c3-puentes.sql`

## Terminó cuando
Un recibo nuevo desde el teléfono aparece como asiento con su proveedor y su
forma de pago; una factura emitida no se puede borrar; correr el puente dos
veces no duplica nada; y **un asiento de mano de obra en el libro solo puede
haber nacido de un journal o de un devengo reversible**.

## Lo construido (24-sep) — versión candidata, sin pegar
- `docs/conta/c3-puentes.sql` y `docs/conta/c3-pruebas.sql` (**112 pruebas**;
  2 necesitan Storage). Recibos, trabajos externos, facturas, cobros (con
  devolución de cheque rebotado) y horas (solo reparto y devengo reversible).
  Lo que falta va a `puentes_bandeja` con el motivo en llano; «reintentar» es
  `fn_puentes_correr()`; `fn_puentes_verificar()` da 13 controles.
- Guardarraíl: nada fechado antes del 1-oct-2026 postea.
- Tres rondas de ataque (regresión de la app, contable, robustez, seguridad):
  30, 20 y 22 hallazgos, todos corregidos con su prueba. **La última ronda no
  se ha vuelto a atacar.**
- Cambios a propósito en la app de obra (el pegado los trae): un papel ya
  contabilizado no se borra (se anula, MX003); una factura emitida no se
  edita (nota de crédito); un recibo anulado no vuelve con un ✎
  (`fn_recibo_desanular`); en Storage no se borra ni se mueve nada de
  `recibos/` ni `docs/`; `trg_recibo_marca_material` corre solo si cambian
  obra, notas o estado; aprobar horas no dispara la guarda de correcciones.
