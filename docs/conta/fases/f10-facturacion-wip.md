# Fase 10 · Facturación, WIP y retención
**23 – 29 nov · 🔵 AZUL el WIP · 🟢 VERDE la facturación · ▶ el método es tuyo**
*(semana corta por Thanksgiving)*

> QuickBooks factura como si vendieras cajas. Tú vendes avance de obra.

## Tú
Definir el método de avance: **costo incurrido sobre costo total estimado**,
o **por hitos**. Tu respuesta de la Fase 3 sobre reconocimiento de ingreso
tiene que ser coherente con esta.

## 🔵 Fable
- **WIP:** porcentaje de avance, sobre-facturación (2400) y sub-facturación
  (1200). Es lo primero que te pide un banco o una afianzadora, y QuickBooks
  no lo trae.
- **Retención:** 1120 por cobrar y 2020 por pagar a subs, descontada sola en
  cada factura y liberada al cierre.
- **Schedule of values** estilo AIA G702/G703.

## 🟢 Opus
- **Catálogo de servicios** que sale de tu propio `catalogo_items` y
  `ensambles` — no de una lista tecleada aparte.
- Plantillas de factura: por hito (`hitos`), por porcentaje, y T&M.
- **El paquete que el GC siempre exige**: certificado de seguro y licencia
  desde `documentos_empresa`, sin buscarlos cada vez.

## Entregable
`docs/conta/c10-facturacion-wip.sql` · pantalla de facturación

## Terminó cuando
Emites una factura de avance con su retención descontada y su schedule of
values, y el WIP del mes te dice si estás sobre o sub-facturado por obra.
