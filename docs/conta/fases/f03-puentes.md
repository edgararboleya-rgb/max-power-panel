# Fase 3 · Los puentes automáticos
**5 – 11 oct · 🔵 AZUL el primero · 🟢 VERDE los otros tres · ▶ el mapeo es tuyo**

> Aquí lo que ya capturas en la obra se vuelve asiento solo. Es lo que mata
> la doble captura de QuickBooks.

## Tú — y esto sí es criterio tuyo
1. **Mapeo de gasto a cuenta:** qué cuenta recibe cada tipo de `recibo`,
   `material` y `gasto_general`.
2. **Reconocimiento de ingreso:** ¿a la factura, al hito, o por avance? La
   respuesta cambia la Fase 10, así que piénsala aquí.
3. Revisar una muestra de asientos generados contra lo que tú habrías hecho
   a mano. Si no coinciden, el mapeo está mal, no el código.

## 🔵 Fable
El primer puente — `facturas` → CxC / ingreso — **y el contrato** que siguen
todos los demás: idempotencia (un origen genera un asiento, no dos), qué pasa
si el documento origen cambia, cómo se reversa.

## 🟢 Opus
Los otros tres con el mismo molde: `recibos` y `gastos_generales` → gasto,
`horas` → mano de obra directa + burden.

## Entregable
`docs/conta/c3-puentes.sql`

## Terminó cuando
Un recibo nuevo desde el teléfono aparece como asiento sin que nadie lo
teclee, y correr el puente dos veces no duplica nada.
