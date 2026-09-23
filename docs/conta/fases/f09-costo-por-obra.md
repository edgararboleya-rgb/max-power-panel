# Fase 9 · Costo por obra y estimado contra real
**9 – 15 nov · 🔵 AZUL el motor y el reparto · 🟢 VERDE pantallas y reportes · ▶ decides cómo se compara y validas**

> **La fase que justifica todo el proyecto.** Ninguna de las otras diecisiete
> hace algo que no puedas comprar hecho. Esta sí.

## Por qué es el premio
Ningún programa del mercado puede hacer esto porque ninguno tiene tu
estimador. Tú puedes comparar lo que **de verdad costó** instalar un
receptáculo contra lo que tu estimador dijo que costaba — por receta, por cost
code, por obra. El camino de vuelta (que la obra corrija al estimador) se
**diseña aquí** y se construye en la Fase 18.

## Tú
1. Decidir cómo se compara: por cost code, por receta, o por los dos.
2. **Validar contra una obra cerrada que te sepas de memoria.** Si el número no
   coincide con lo que tú sabes que pasó, el cálculo está mal.
3. Fijar `conta_config.burden_estandar_pct` — **una sola tasa**, no por
   escenario — para el costo estándar mientras no exista el journal.

## 🔵 Azul — se crea (`/effort max`)

Casar el gasto real con el cost code y la receta.

**El reparto de mano de obra y burden sobre las horas aprobadas de cada obra y
período — diseñado aquí, una sola vez. f11 solo lo alimenta con el journal
real.** *(Antes estaba diseñado en f03, f09 y f11, en orden invertido: Opus lo
construía en octubre lo que el azul diseñaba en noviembre.)*

Mientras no exista f11: **costo estándar** de mano de obra (tarifa de
`costos_equipo` × `burden_estandar_pct`) etiquetado **«estándar, no real»**, y
el paralelo de f13-14 entra la nómina del proveedor viejo con procedencia
`mano`.

Si Edgar quiere costo por hora estable: tasa de **burden aplicado**
Dr 5010-obra / Cr 5011, y el cierre de f08 compara real contra aplicado y lleva
la diferencia a 5019.

La columna «estimado» sale de `coalesce(estimados.benefits_pct,
escenarios.benefits)` del escenario con que se cotizó (`estimados.escenario`).
**`benefits_detalle` nunca es costo real**: es lo que le cotizas al cliente.

Base contra base y CO contra su estimado (el CO vive en `alcances`, f10).
Margen por obra, por fase y por código.

## 🟢 Verde — se trabaja encima (`/effort auto`)
Las pantallas y los reportes. **El alcance de la primera versión, dicho con
honestidad:** por obra y por cuenta con todo el histórico; **por cost code solo
desde octubre** (lo capturado con código); la obra cerrada que Edgar valida se
compara por obra y cuenta.

## Entregable
`docs/conta/c9-costo-obra.sql` · pantalla de estimado contra real

## Terminó cuando
Abres una obra terminada y ves, por obra y por cuenta, dónde ganaste y dónde
perdiste contra lo que estimaste, y coincide con lo que recuerdas; y **la mano
de obra dice si es estándar o real**.
