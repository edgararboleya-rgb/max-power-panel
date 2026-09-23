# Fase 15 · El amarre y el arranque
**28 dic – 3 ene · 🟢 VERDE · ▶ tu visto bueno**

## Tú
Dar el visto bueno **sobre la tabla de diferencias del paralelo**. Confirmar
las fechas de pago de la última nómina vieja (≤ 31-dic) y la primera en Gusto
(≥ 4-ene).

## 🟢 Verde — se trabaja encima (`/effort auto`)
- **Apagar la función `qb`** y activar el camino nuevo de 🧾 desde el 1-ene;
  retirar la casilla manual `pagada`/`cobrado` (desde ahora las mantiene
  `cobros`).
- Verificar que corren `pg_cron`, `contador` y el correo de cierre.
- Publicar **`docs/conta/OPERACION.md`** con el criterio de f08 y las listas:
  calendario del mes (qué día importas el banco, qué día corre la ronda, qué
  día cierras, qué día pagas), «si el puente no corrió → cómo se reintenta y
  cómo se ve que no duplicó», «si el archivo del banco no entra», «si el cierre
  no amarra», «si Supabase no responde mientras la cuadrilla sube recibos», y
  la frase exacta para abrir una sesión de soporte.
- **Prueba de restauración:** `pg_restore` del respaldo en un proyecto Supabase
  vacío; balanza y conteo de filas por tabla iguales.

## → 1 de enero de 2027: en vivo

**Los saldos al 31-dic no se cargan aquí:** los statements de diciembre y la
balanza preliminar de QuickBooks llegan en enero. El cuadre al 31-dic, el
asiento de ajuste de errores y el cierre de diciembre en la app van en la
**semana del 18-ene**.

## Y después
- ▶ **Ene – mar 2027:** QuickBooks vivo **en solo lectura**. El CPA cierra 2026
  desde ahí. Unos $300 de seguro barato; no lo canceles antes. Antes de
  cancelarlo, exporta P&L y balance por mes de 2025–2026.
- ▶ **Enero:** 1099 de 2026 desde QuickBooks **antes del 1-feb**; W-2 y 941 del
  Q4 del proveedor viejo; cierre de diciembre en la app.
- ▶ **~Abril 2027:** el CPA entrega 2026 → sus ajustes entran como
  `ajuste_cpa` → **entonces se cancela QuickBooks**.
- **Principios de 2028:** el CPA recibe el paquete fiscal desde la app por
  primera vez, con un año completo ya probado detrás.
