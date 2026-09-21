# Fase 7 · Categorización y la bandeja
**26 oct – 1 nov · 🔵 AZUL el motor, la bandeja y el esqueleto de `contador` · 🟢 VERDE la pantalla y el cliente · ▶ reglas para el viernes 23-oct; despliegas `contador`**

> Es el «Banking» de QuickBooks, hecho a tu medida. Y es donde nace la IA
> contable: aquí se implementa **propone y nunca postea**.

## Tú
1. Dictar las reglas que ya tienes en la cabeza, **para el viernes 23-oct**:
   este proveedor siempre va a esta cuenta, este rango de monto es esto otro.
2. Categorizar un mes real a mano para que agarre patrón.
3. ▶ **Una semana antes:** `supabase functions deploy contador`, con una llave
   **NUEVA** de Anthropic como secreto (separa el gasto contable del del
   estimador). El `effort`, el caché y el sello viven en esa función, no en el
   navegador.

## 🔵 Fable

- **El motor de reglas determinista**, con reglas que **parten un movimiento en
  varias líneas** (la cuota del vehículo: Dr 2520 + Dr 7100 / Cr 1010, con la
  función de f06).
- **La bandeja.** `ia_propuestas` (`id, accion, modelo, effort, prompt_version`
  —hash del texto del prompt que la función calcula al arrancar—, `entrada`
  jsonb con solo lo variable congelado + `prefijo_hash`/`reglas_version`,
  `salida` cruda, `estado` pendiente|aprobada|editada|rechazada,
  `aprobado_por, aprobado_el, asiento_id, lote_id`) e `ia_lotes` (`usage`,
  centavos, modelo, effort por petición). **La función inserta la fila ANTES de
  devolver la sugerencia**: si no se pudo guardar, no se muestra. `fn_aprobar`
  postea vía `fn_postear` y añade la FK `asientos.propuesta_id`.
- **El esqueleto de `supabase/functions/contador/index.ts`**: valida el JWT,
  comprueba `es_dueno()` por RPC **antes de gastar un token**, registra `usage`
  en `asistente_costo_mes` con `accion='contador_*'`, devuelve `prompt_version`
  y `usage` en cada respuesta.
- **Tres reglas fijas de S-corp que la IA no reinterpreta:** (a) todo pago al
  IRS por el impuesto sobre la renta de Edgar → **3200** (no incluye al DOR:
  sales tax y RT-6 sí son de la empresa); (b) todo cargo marcado personal →
  3200, o 1130 si lo devuelve; (c) el sueldo de Edgar solo entra por nómina
  (6000), nunca como transferencia.
- **Regla de capitalización:** compra ≥ $2.500 por unidad y vida > 1 año →
  propone alta en 15xx, Edgar aprueba.
- **Criterio de use tax:** compra sin impuesto visible → propone Dr 5100 /
  Cr 2300 por el 7,5 %, respetando el tope del surtax que `e13b` ya advierte.

## 🟢 Opus
La pantalla, el editor de reglas, y el cliente en `conta.js` (copiando el
manejo de 401 y «Sin señal» de `pedirAlCerebro`, contra
`/functions/v1/contador`). Las llamadas a `claude-opus-5` con
`output_config: {effort: "low"}` **en ráfaga al abrir la bandeja** — esperando
la primera respuesta antes de disparar el resto, para que el caché exista. El
prefijo (plan de cuentas + reglas, ordenado y sin fechas) con `cache_control`,
y la comprobación de `cache_creation_input_tokens` /
`cache_read_input_tokens` guardada por lote. `stop_reason: "refusal"` —que
también ocurre en Opus— se trata como «sin respuesta»: **nunca un fallback a
otro modelo**. **Sin Batches en la v1.** Y el flag `impuesto_pagado`
(sí/no/desconocido) en `recibos`, leído en la lectura del recibo que ya existe.

## Entregable
`docs/conta/c7-reglas.sql` · `supabase/functions/contador/index.ts` · la pantalla

## Terminó cuando
Un mes de movimientos queda categorizado con menos de diez correcciones tuyas;
cada sugerencia que aceptaste dejó su sello en el asiento; y **abres un asiento
de origen IA y ves qué vio, qué contestó tal cual y con qué versión del prompt**.
