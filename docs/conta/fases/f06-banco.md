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
4. **Abrir la cuenta de reserva de impuestos** y programar la transferencia
   semanal (el monto, con el CPA). Pedirle también el % de la utilidad para
   2027 y cuánto pagar el 15-ene-2027.

## Las cuentas (Edgar, 24-sep)
- **Chase, una sola cuenta**: la operativa del negocio, donde se mueve todo →
  **1010**. No hay cuenta de nómina ni tarjeta Chase: Gusto también cobra
  desde 1010. **1020 sale de c1** cuando termine el workflow (se añade el día
  que se abra).
- **Reserva de impuestos → 1030, se queda** (Edgar, 24-sep). Cuenta de ahorro
  de empresa, por abrir; banco por decidir (ver abajo). Entra por
  `transferencia` 1010 → 1030 sin tocar resultados; sus intereses van a 4910;
  lo que sale para el impuesto sobre la renta de Edgar va a **3200** (f07,
  regla a); se concilia contra su statement como cualquier banco.
- **American Express Business Gold** → `2100-XXXX` (sus últimos 4).
- **American Express Business Blue** → `2100-XXXX` (sus últimos 4).
  Amex en su web muestra los últimos **5** dígitos; la subcuenta y
  `recibos.ultimos4` usan los últimos 4.
- Pago de cada Amex desde Chase = `transferencia`: Dr 2100-XXXX / Cr 1010,
  sin gasto.
- **Dónde abrir la reserva (recomendación del 24-sep):** ahorro de empresa de
  alto rendimiento en otro banco (FDIC, sin cuota mensual, con export QFX/CSV
  y presente en Plaid) — rinde ~3,8–4 % (sep-2026) contra casi 0 % en Chase, y
  fuera de la vista no se toca. Alternativa simple: Chase Business Total
  Savings (misma conexión de Plaid, transferencia al instante; $10/mes salvo
  saldo ≥ $1.000 o vinculada a Business Complete Checking).
- **Cómo se llena:** transferencia **semanal automática fija** (programada en
  el banco; el monto lo fija el CPA) + **ajuste mensual al cierre** que
  calcula la app (f08).
- Archivo preferido: **QFX/OFX**, porque cada movimiento trae su propio id
  (FITID) y eso ayuda a la idempotencia. CSV solo si no hay otro.
- **Conector automático: Plaid, plan Trial** (Edgar lo pide, 24-sep). Gratis,
  hasta 10 conexiones reales, incluye Chase, Amex y Transactions, sin
  cuestionario de seguridad. Max Power usa **2 conexiones**: Chase y Amex (Gold
  y Blue entran juntas con el mismo usuario de Amex). No pedir Production de
  pago: el Trial solo existe para cuentas que nunca lo pidieron, y fuera del
  Trial Chase tardaba 3–4 meses en aprobar (julio 2025). Chase comparte datos
  con Plaid por API oficial; la API directa de Chase es solo para clientes de
  tesorería de J.P. Morgan. El archivo sigue siendo el respaldo permanente
  (§5.5 del plan).
- **Plaid en la Fase 6 (🔵 azul):** función `plaid` en Supabase (link token,
  canje del token, `/transactions/sync` diario + webhook). El access token vive
  en **Vault**, nunca en una tabla. Los movimientos entran a la misma tabla
  que los del archivo, y **el mismo cargo por Plaid y por archivo entra una
  sola vez**. Solo se contabiliza lo posteado, nunca lo pendiente. Edgar pone
  `PLAID_CLIENT_ID` y `PLAID_SECRET` en los secretos de Supabase y la URL de
  la app en las redirect URIs de Plaid; el secreto nunca pasa por el chat.

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
  de la tarjeta (o entre cuentas de banco, si algún día hay más de una), por
  monto y fecha ±3 días, y postea un solo asiento Dr 2100-x / Cr 1010 **sin gasto**.
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
