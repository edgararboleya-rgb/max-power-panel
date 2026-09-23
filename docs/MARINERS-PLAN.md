# Mariners Hospital (Baptist Health) — qué le falta al estimador

Revisión del 22/09: 9 agentes revisaron los 33 puntos del documento de Mariners
contra el código, y 25 verificadores intentaron tumbar cada veredicto. El paso
final (escribir el plan) se cortó; este documento lo arma con los resultados
verificados (`subagents/workflows/wf_01b18eb1-326/journal.jsonl`).

**Resultado honesto:** de 33 puntos, **ninguno está completo**. Los dos «sí»
que dio la revisión los tumbó la verificación a «parcial». 10 de los «parcial»
cayeron a «no».

## Ya arreglado

| Hallazgo | Dónde |
|---|---|
| Un deduct «-$12,500» de la hoja de alcance entraba como CARGO | v211 (23/09), prueba `pruebas/e34.js` |
| El takeoff contaba dos veces las luminarias de referencia | v210 |
| `on conflict do nothing` duplicaba el catálogo (sin índice único) | e30/e31 |
| **Tanda 1**: tipos de línea (logística / allowance / sub) sin tax ni escalación y fuera de la hora cargada; takeoff que cuadra; allowances en la propuesta; validez por estimado; lápiz de precio por renglón; flete e importe único de la cuota; permiso sin marcar con contratista o MEP; ICRA en planos para salud | v212, `pruebas/e35.js` |
| **Tanda 3**: datos del trabajo (contratante, dueño, dirección, retención); retención como hito aparte al cierre; convertir en proyecto con el número CONGELADO y también desde MXP MEP; adjuntos del estimado que pasan al proyecto; las líneas a mano se reparten entre las opciones A/B/C | v216, `pruebas/e37.js`, `docs/sql/e36` |
| **Tanda 2**: merma automática solo en planos (decisión de Edgar 23/09); MXP MEP se congela y guarda resultado; propuesta lump sum de MXP MEP para el cliente (Integrated Systems) sin margen; la lista enseña el número congelado | v213, `pruebas/e36.js` |

## Lo que mueve dinero en Mariners HOY (orden de gravedad)

1. **Un estimado de MXP MEP no se puede congelar.** Sin foto (`bid_final`), el
   número que se le manda a MX MEP no queda guardado. Tocar ⚙ Escenarios movió
   un estimado de prueba un 10,4 %. Tampoco entra al historial (`bloqueResultado`
   devuelve vacío para MEP, app.js:6732).
2. **El resumen de MXP MEP imprime Overhead, Profit y Hora cargada**
   (app.js:7577-7598). Si ese papel llega a quien negocia, el margen queda por
   escrito sobre la mesa.
3. **El escenario MEP puede no tener superintendent.** Nació copiando el A
   (e13e:22-36). Sin él, la tarifa mezclada baja de $33,75 a $27,75 (−18 %).
4. **La merma automática corre en planos, remodelación y servicio**, no solo en
   planos como dice el comentario (app.js:6201-6203). En Nicklaus además se
   metieron 3 renglones de merma a mano (e23:97-99): se cobró dos veces. En
   Mariners, **no** poner merma a mano.
5. **Logística, per diem, PPE y allowances solo caben como «material a mano»**:
   pagan sales tax y escalación, envenenan la hora cargada ($412/h en la
   prueba), no salen en el takeoff y salen en español en la propuesta.
6. **6 h de permiso salen pre-marcadas** (app.js:5752, 8249) aunque el permiso
   lo saque el GC; e **ICRA y demolición no se proponen en modo planos**
   (app.js:5748-5750).
7. **Sales tax del escenario MEP = 6,5 % (Orange).** Mariners es Monroe: se
   pone con el ✏ de Sales tax **del estimado**, nunca en el escenario.
8. **La lectura de cuotas tira las líneas de flete** (regex TOTALES,
   app.js:6038) y toma el precio extendido como unitario cuando la línea solo
   trae uno (app.js:6048).

## Plan

**Tanda 1 — horas, sin decisiones de Edgar**
- Permiso no pre-marcado (que sea `supuesto`); ICRA disponible en modo planos.
- Las líneas a mano salen como renglón en el takeoff (que cuadre).
- Tipo de línea a mano: logística / allowance / sub → sin sales tax, sin
  escalación, fuera de la hora cargada.
- La línea de flete de una cuota entra como renglón.
- Lápiz de precio en la fila del estimado; validez de la propuesta editable
  (hoy «15 días» fijo, app.js:7705).

**Tanda 2 — un día**
- Congelar (y marcar resultado) un estimado de MXP MEP.
- Salida lump sum para MEP sin overhead/profit/hora cargada.

**Tanda 3 — más de un día**
- Alternates con líneas a mano, retención del contratante, contratante vs dueño
  en campos separados, adjuntos al estimado, calibración contra el estimado de
  Claude.

**Decidido (23/09)**
- Merma automática solo en modo planos.
- El papel de Mariners lo recibe Integrated Systems: va la propuesta lump sum.

## Siguiente: las cuotas del supply leídas con INTELIGENCIA (Edgar, 23/09)

Edgar: «que la inteligencia lo haga, no que sea algo automático que cree
conflictos después». La cuota de José o de Mike se sube al estimado y la IA la
lee renglón por renglón contra el estimado:

- Material que ya está (cable, tubo): el PRECIO UNITARIO de la cuota (por pie,
  por MLF, por rollo) aplicado a NUESTRA cantidad medida — 1.600 ft cotizados
  no son los 1.400 que hacen falta.
- Equipo cotizado entero (desconectivo de $20.000, gear): nuestro renglón se
  queda SOLO con las horas de montaje ($0, «suministro») y el monto entra como
  línea de Cotización. Nada se cobra dos veces.
- Lo que la cuota trae y el estimado no, y al revés: se señala, no se decide.
- Dos cuotas: la más cara manda, renglón por renglón.

EL PRINCIPIO: la IA PROPONE con su razón en cada renglón y Edgar APRUEBA antes
de que se toque nada. Las reglas fijas quedan solo como COMPROBACIÓN después
(que el total cuadre, que nada salga dos veces), nunca como quien decide:
las reglas rígidas son las que ya crearon conflictos (leeCuota tomando el menor
importe como unitario, el flete tirado como pie de cuota).
