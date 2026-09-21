# Fase 18 · Facturación de obra, flujo de caja y el camino de vuelta al estimador
**marzo 2027 · 🔵 AZUL el camino de vuelta · 🟢 VERDE catálogo, SOV, paquete del GC y flujo de caja · ▶ apruebas cada recalibración**

> Lo que le gana a QuickBooks y que el 1 de enero no necesitaba. Llega con dos
> meses de libros reales encima, que es lo que le da sentido. **Sacar esto del
> camino crítico es lo que dio el colchón de la semana 12.**

## Tú
1. Aprobar, **una por una**, las recalibraciones que la Fase 9 propone al
   estimador (precio de receta, horas por unidad, overhead por hora, benefits).
   Nada entra al catálogo sin tu toque.
2. Decidir si quieres el export a Google Drive además del correo y el Storage
   (v2 opcional, con OAuth). Si sí, dar el acceso una semana antes.

## 🔵 Fable

- **El camino de vuelta al estimador.** Qué aprende `catalogo_items` y qué
  aprenden los `ensambles` de una obra cerrada: el real por cost code (Fase 9)
  contra el estimado de esa obra, con el sello de aprobación de la bandeja.
  `overheadReal()` deja de leer `gastos_generales.monto_mensual` y lee el
  **saldo real de 6000–7000** del mes cerrado; `escenarios.benefits` se propone
  desde el **burden real de 5010**. Mismo botón con `confirm` que ya existe en
  el estimador; solo cambia la fuente.
- **El contrato del flujo de caja proyectado:** facturas abiertas con los días
  típicos de cobro por cliente calculados en SQL desde `cobros`; líneas
  abiertas de 2010 por proveedor con su vencimiento; saldo de tarjetas y su
  fecha de corte; calendario de nómina; hitos pendientes **sin fecha
  inventada** — se proyectan solo si el hito tiene `fecha_esperada` que Edgar
  puso; si no, no aparecen.

## 🟢 Opus

- **Catálogo de servicios** desde `catalogo_items` y `ensambles`, no de una
  lista tecleada aparte.
- **Schedule of values** AIA G702/G703 por renglón de `alcances`, con el CO
  aprobado como partida aparte y la retención descontada sola.
- **El paquete que el GC siempre exige**: certificado de seguro y licencia
  desde `documentos_empresa`.
- Vista `flujo_caja_proyectado` sobre el contrato de arriba, y su pantalla.
- Opcionales, **solo si el gasto lo justifica**: Batches para la
  categorización del mes (con su máquina de estados: `batch_id`, sondeo por
  pg_cron, recogida por `custom_id`, gasto contabilizado al recoger) y el
  export a Drive por OAuth.

## Entregable
`docs/conta/c18-obra.sql` · pantalla de SOV y de flujo de caja · las
recalibraciones en la bandeja

## Terminó cuando
Una obra cerrada en febrero **le propone al estimador su corrección** y tú la
apruebas desde la bandeja; el GC recibe una factura de avance con SOV,
retención y el paquete de seguros sin que busques nada; y el flujo de caja de
abril sale de cobros, pagos y nómina reales, no del histórico.

## Desbloquea
El circuito cerrado estimador ↔ libro, que es el premio de todo el proyecto.
