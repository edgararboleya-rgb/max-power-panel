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
`docs/conta/c10-costo-obra.sql` (c9 ya era el cierre) · pantalla de estimado contra real

## Terminó cuando
Abres una obra terminada y ves, por obra y por cuenta, dónde ganaste y dónde
perdiste contra lo que estimaste, y coincide con lo que recuerdas; y **la mano
de obra dice si es estándar o real**.

## Lo construido (10-nov)

El entregable se llama `docs/conta/c10-costo-obra.sql`, con `c10-pruebas.sql`
(61 pruebas) y `pruebas/conta/c10-concurrencia.sh` (dos sesiones a la vez).
Dos piezas: el pago de mano de obra repartido por horas, y el costo por obra.

- **El pago a una persona, repartido entre sus obras.** A quien se le paga por
  horas se le da de alta una vez (con el texto con que el banco describe su
  pago). Desde entonces su Zelle sale en la Bandeja como una tarjeta «Mano de
  obra · {persona}»: la semana, las horas, y cuánto le toca a cada obra y a
  cada CO, al centavo. «Así es» aprueba las horas que se vieron y postea el
  asiento, todo o nada. Si las horas cambiaron entre que se miró y que se
  tocó, no entra nada y se vuelve a mirar (MX011).
- **La semana.** Pagado de lunes a miércoles: la semana anterior (lunes a
  domingo). De jueves a domingo: la semana en curso. Siempre se puede cambiar,
  de un toque (la otra semana) o a mano (hasta 62 días).
- **Las horas son solo la clave del reparto.** El monto es el del banco. Si lo
  que sale por hora se aleja de la tarifa de «Costos del equipo», avisa y no
  frena.
- **Una hora, un pago.** Las horas que ya cubrió otro reparto no entran otra
  vez, salvo que se diga que es otro pago de las mismas horas.
- **Las horas sin obra** van a la cuenta que se fije una vez en los ajustes
  (la de subcontratos exige obra). Mientras no se fije, ese pago no se puede
  repartir y lo dice.
- **Deshacer** un reparto pide el motivo: el asiento se reversa (no se borra) y
  el pago vuelve a la Bandeja. La aprobación de las horas se queda.
- **La página «Costo por obra».** Por obra: ingreso, costo real (material,
  subcontratos, equipo, mano de obra), margen, y el estimado al lado. Se entra
  a cada obra para verlo por concepto, por CO y por código donde lo haya, y
  cada cifra del real baja hasta sus asientos.
- **La mano de obra dice si es real o estándar.** Real: lo pagado y repartido.
  Estándar: las horas sin pago real × la tarifa × (1 + el % de carga). El
  estándar se rotula «estándar, no real» y nunca entra al libro.
- **El estimado** sale de las mismas fuentes que la app (horas estimadas,
  presupuesto de material, el escenario con que se cotizó). Un estimado al que
  le falta una parte no se compara contra un real completo: dice «estimado
  incompleto» y qué falta.
- **Parcial.** Una obra que ya andaba antes del libro (30-sep) lo dice: su
  real empieza el 1-oct.
- **Los controles.** 11 del reparto (7 cuadres y 4 avisos) y 6 del costo por
  obra. El cierre del mes (c9) los mira: un cuadre en rojo detiene (fila 170)
  y los avisos avisan (fila 171). Avisan, entre otros: horas reportadas tarde
  para una semana ya repartida, un pago a una persona dada de alta que se
  clasificó a mano, y una propuesta de la IA que quedó abierta en un pago ya
  repartido (la pantalla la cierra sola al abrir la Bandeja).
- **El camino al libro** es el del banco (c6, `fn_banco_clasificar`), llamado
  por el dueño. Ninguna función de c10 es SECURITY DEFINER.
- **Lo que f11 usará.** `fn_jornal_repartir(persona, desde, hasta, monto,
  solo_aprobadas)` no sabe nada del banco: la nómina de Gusto lo alimenta con
  el bruto de cada persona y no hay que rehacerlo.

### Quién lo hizo
Fable con esfuerzo máximo en la base, en la revisión contra el dinero y en sus
arreglos; Opus 5.5 en la pantalla y en la verificación desde cero. Los dos
revisores no encontraron nada que dejara mal el libro; sí siete cosas que
podían confundir, todas corregidas.

### Lo que queda dicho y no hecho
- **Un Zelle que lleva además un reembolso** va entero por horas o entero por
  la Bandeja; todavía no se puede apartar una parte. Mientras, el reembolso en
  otro Zelle.
- **El estándar usa la tarifa de hoy**: «Costos del equipo» no guarda
  historia.
- **El costo cae en el mes del pago** (la fecha del banco, como QuickBooks).
  Las horas de diciembre pagadas en enero quedan en el año siguiente y la
  tarjeta lo avisa. Pregunta para el CPA.
- **El CO es texto libre** hasta la Fase 10: «co #1» y «CO #1» salen como dos
  líneas, con aviso.
- **Alguien con horas en la app que no está dado de alta** no se reconoce: su
  pago se clasifica a mano y sus horas quedan a estándar. La salida es darlo
  de alta.
- **f12a (1099)** debe sumar por los repartos (persona y año) o por el tercero
  «empleado», no solo por la etiqueta 1099 de la cuenta.
- **c3**: el devengo estándar del mes (`fn_horas_devengar`, que hoy nadie usa)
  no aparta las horas ya pagadas; si se empieza a usar, el control 50 lo
  pone en rojo cuando duplica.
- **El camino de vuelta al estimador** (que la obra corrija la receta) queda
  diseñado en la cabecera de c10 y se construye en la Fase 18.

### Tú (lo que falta de tu lado)
1. Pegar `c10-costo-obra.sql`, volver a pegar `c9-cierre.sql` (trae las filas
   170 y 171), pegar `c10-pruebas.sql` y `c9-pruebas.sql`.
2. Decir el % de carga estándar (`burden_estandar_pct`) y la cuenta de las
   horas sin obra. Se ponen en la pantalla, en los ajustes de mano de obra.
3. Dar de alta a quien pagas por horas y repartir sus pagos pendientes.
4. Validar una obra terminada que te sepas de memoria.
