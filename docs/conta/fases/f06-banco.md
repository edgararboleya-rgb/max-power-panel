# Fase 6 · Banco, tarjetas, cobros y pagos
**19 – 25 oct · 🔵 AZUL idempotencia, conciliación, cobros y pagos · 🟢 VERDE los lectores y la aplicación · ▶ archivos para el viernes 16-oct; arranca Gusto**

## Tú

1. **Para el viernes 16-oct:** un CSV u OFX de **cada cuenta y cada tarjeta**
   (septiembre y lo que haya de octubre). Sin eso no se puede escribir el
   lector — cada banco exporta distinto.
2. **Esta semana, aparte del banco: abrir la cuenta de Gusto.** Confirmar
   antes que Check no vende a empleadores directos (solo embebido en
   plataformas), y solicitar el acceso de **API de producción**: las llaves
   demo son inmediatas, las de producción pasan por aprobación. Meta:
   empleados dados de alta (W-4, depósito directo) **antes del 11-dic**. Ver f11.
3. Los statements de préstamo y la póliza de cada seguro pagado por adelantado.

## Las cuentas (Edgar, 24-sep)
- **Chase**: la operativa es 1010. Falta confirmar si hay más cuentas (nómina
  1020, reserva 1030) o alguna tarjeta Chase.
- **American Express Business, 2 cuentas**: una subcuenta `2100-XXXX` por cada
  una (los últimos 4). Si el equipo tiene tarjetas adicionales, sus últimos 4
  casan con `recibos.ultimos4` del ticket.
- Archivo preferido: **QFX/OFX**, porque cada movimiento trae su propio id
  (FITID) y eso ayuda a la idempotencia. CSV solo si no hay otro.
- **Conector automático (decide Edgar):** Plaid. Chase comparte datos con
  Plaid por API oficial (acuerdo de 2020) y Amex también está en Plaid. La API
  directa de Chase es solo para clientes de tesorería de J.P. Morgan. El
  archivo sigue siendo el respaldo permanente (§5.5 del plan).

## 🔵 Azul — se crea (`/effort max`)

- **Idempotencia** por movimiento **y entre archivos**: la salida del banco y
  el abono en la tarjeta son el mismo dinero.
- **Conciliación de verdad, no igualdad.** Saldo del estado + depósitos en
  tránsito − cheques y cargos en circulación = saldo en libros. Tabla
  `conciliaciones` (cuenta, mes, saldo_banco, fecha_confirmada) y
  `conciliacion_partidas` con FK a la línea del asiento o al movimiento
  importado (cada partida tiene clic hasta su asiento). Las partidas en
  tránsito al 30-sep de la era QuickBooks entran como conciliación de
  apertura. Tarjetas contra su statement a su fecha de corte.
  *«Saldo en libros = saldo del banco» a secas impedía cerrar cualquier mes.*
- Tipo de movimiento **`transferencia`**: casa la salida del banco con el abono
  de la tarjeta, o entre 1010/1020/1030, por monto y fecha ±3 días, y postea
  un solo asiento Dr 2100-x / Cr 1010 **sin gasto**.
- **Casado determinista de cobros**: un depósito se casa con facturas abiertas
  y alimenta `cobros` (f03); nunca se categoriza a ingreso.
- **Casado de pagos a proveedor**: el pago (banco o tarjeta) se aplica a las
  líneas abiertas de 2010 de ese proveedor; **nunca se recategoriza a 5100**
  (el gasto ya entró con el ticket).
- Tabla `prestamos` (prestamista, principal, tasa, cuota, inicio, cuenta 25xx)
  y función SQL que propone la partición capital/interés de cada cuota; el
  statement del prestamista manda sobre la función.

## 🟢 Verde — se trabaja encima (`/effort auto`)
Un lector por banco y por tarjeta. El importador de archivo **se queda para
siempre**. La pantalla de aplicación de cobros y de pagos, y el botón que
sustituye a `cambiarFactura({pagada:true})`.

## Entregable
`docs/conta/c6-banco.sql` · el importador y la aplicación en `js/conta.js`

## Terminó cuando
Importas el mismo archivo dos veces y no entra nada la segunda vez; **el pago
de la tarjeta del mes no aparece en ninguna cuenta de gasto**; cada depósito
casa con una fila de `cobros`; y septiembre concilia con sus partidas en
tránsito, sin tocar 1010.
