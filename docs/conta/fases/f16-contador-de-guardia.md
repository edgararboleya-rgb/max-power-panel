# Fase 16 · El contador de guardia
**febrero 2027 · 🔵 AZUL el analista · 🟢 VERDE extiende la bandeja y arma la conversación**

> La bandeja, el sello y el contrato de la IA **existen desde la Fase 7**
> (`ia_propuestas`, la función `contador`): aquí se diseña el analista encima,
> no de cero. Pasa a febrero porque enero ya trae el arranque en vivo, el
> cierre de diciembre, el 1099 de 2026 y los W-2 del proveedor viejo.

> Cae **después** del corte a propósito: un auditor necesita libros con datos
> reales encima para tener algo que auditar. Las alarmas deterministas ya
> entraron en la Fase 8; esto es el analista que las interpreta.

## La frontera que no se cruza
**Lo que se contesta con una resta, lo contesta Postgres. Nunca el modelo.**
Un modelo de lenguaje es un analista excelente y un sumador mediocre.

## 🔵 Azul — se crea (`/effort max`)
- **Explicar el descuadre.** El código dice *«faltan $1.240»*. La IA dice
  *«el recibo de CED del 12 entró dos veces, el segundo con otro número de
  transacción»* y **propone** el reverso.
- **Conciliar:** cruzar movimiento contra recibo, factura o nómina, y dejar
  en la bandeja solo lo que no casó.
- **Oler lo raro, sin que nadie se lo pida:** *«el material de esta obra va
  40 % arriba de tu estimador, y el 80 % entró en tres días.»*
- **Redactar** la nota del cierre y el resumen para el CPA.

## 🟢 Verde — se trabaja encima (`/effort auto`)
**Extiende** la bandeja de f07 a los tipos nuevos de propuesta (reverso,
conciliación, alerta) y arma la conversación sobre los libros. Acciones nuevas
en `contador`, con el mismo esqueleto.

## Las tres reglas
1. **Propone, nunca postea.** Todo pasa por tu aprobación, y cada asiento
   nacido de una sugerencia lleva sello: qué modelo, qué propuso, quién
   aprobó, cuándo — **y además la versión del prompt, la entrada que vio y la
   salida literal** (f07). **Eso es lo que hace compatible «IA en todo» con
   «100 % auditable».**
2. **Cita o se calla.** Sin asiento, recibo o movimiento que lo sostenga, no
   se muestra.
3. **Tope duro** en `asistente_costo_mes` / `tope_mes_centavos`.

## Modelos dentro de la app (no es el color de la sesión)
Opus 5.5 a `xhigh`/`max` para el auditor y para explicar (si en casos reales se queda corto, esa acción sube a Fable 5.1). Opus 5.5 a `medium`
para leer y redactar, a `low` para lo repetitivo. **Ni Haiku ni Sonnet.**
