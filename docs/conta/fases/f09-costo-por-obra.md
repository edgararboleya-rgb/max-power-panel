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

## La cuadrilla, sola (15-nov)

Lo decidiste tú: «Necesitamos algo más práctico para categorizar los gastos.
No tendría que tocar ningún botón de repartir horas ni nada, sino que eso lo
hiciera automático. Lo más simple que podamos, pero funcional y efectivo.»

Es la versión 5 de `docs/conta/c10-costo-obra.sql` (su marca: 2026111501), con
`c10-pruebas.sql` (ahora 82 pruebas: las 18 nuevas, de la 65 a la 82) y una
parte nueva en `pruebas/conta/c10-concurrencia.sh` (dos teléfonos a la vez).
No se tocó ninguna otra capa: ni el banco (c6), ni la IA (c8), ni el cierre
(c9), ni los puentes (c3).

- **Los Zelle a la cuadrilla entran solos.** Ya no hay que dar de alta a
  nadie: la base reconoce el pago de cada persona con horas por **su nombre,
  como palabra entera, en la descripción del banco** (el nombre que tiene en
  la app). Lo reparte entre las obras por las horas que esa persona reportó
  en la semana que paga, lo registra como mano de obra de la cuadrilla (la
  cuenta del jornal, 5200, con su obra) y deja esas horas aprobadas. Es
  exactamente lo que entraba con tu «Así es»: la misma cuenta, el mismo
  asiento, por la misma puerta del banco.
- **No es salario.** Sueldo es solo la nómina de Gusto (desde enero). Esto
  sigue siendo mano de obra de la cuadrilla por obra. No toca 5000, 5001,
  6000 ni 6005.
- **«Registrado solo».** En la Bandeja, arriba, sale la lista de lo que entró
  solo en los últimos 14 días: la persona, cómo escribió el banco ese pago
  («El banco: «Zelle payment to …»»: nadie vio su tarjeta antes de que
  entrara, y un pago a otro que se llama igual se tiene que poder ver ahí),
  la semana, cuánto a cada obra, y **«Deshacer»** (pide el motivo; el asiento
  se reversa, no se borra).
- **Lo que deshaces no vuelve a entrar solo.** El pago vuelve a la Bandeja y
  su tarjeta dice «No entró solo. Lo deshiciste el… (tu motivo)». Se queda
  así hasta que tú lo aceptes con «Así es» o toques «Que vuelva a entrar
  solo». No hay una lista aparte que se pueda perder: sale de la historia del
  propio pago, que no se borra.
- **Los cheques preguntan.** Un cheque llega como «CHECK 1043», sin nombre.
  En la Bandeja, arriba: «¿De quién es el cheque 1043 de $240.00?», con la
  cuadrilla en botones y «No es de la cuadrilla». Un toque en la persona y
  la base lo reparte por sus horas y lo registra en ese momento, con las
  mismas reglas. Queda escrito de quién era y que lo dijiste tú (para el 1099
  y el costo por obra). El cheque no cambia cómo reconoce la base a esa
  persona.
- **No adivina, y lo dice.** No reconoce sola a alguien si su nombre casa con
  el de otra persona, si es demasiado corto o demasiado común, si el banco ya
  lo escribe en pagos a dos destinatarios, o si ya cobra por nómina. Sale en
  «Costo por obra → Personas» con su porqué; ahí se le pone a mano cómo lo
  escribe el banco, o se dice «No cobra por horas» y no se pregunta más.
- **Qué NO entra solo.** Todo lo que pide que decidas tú. Se queda en la
  Bandeja con **una sola frase** arriba de su tarjeta, y su «Así es» de
  siempre:
  - no hay horas en la semana que paga, o esas horas ya las cubrió otro pago;
  - el banco lo trajo dos veces (posible duplicado);
  - el mes del pago está cerrado;
  - lo que sale por hora se aleja de su tarifa (o no tiene tarifa);
  - esa persona ya cobra por nómina, o una nómina ya pagó esas horas;
  - hay horas con fecha **posterior** al día en que su obra se dio por
    terminada: ¿fue una vuelta de garantía o se apuntaron en la obra
    equivocada? (abajo, «La obra terminada no frena»);
  - falta decir a qué cuenta va lo sin obra, o una cuenta ya no sirve;
  - el cargo no parece un pago a una persona (una compra en un comercio con
    su nombre);
  - puede ser otra cosa que ya está en el libro (un cheque del mismo monto
    apuntado antes, un débito que el banco toma por nómina): eso lo decide el
    banco al registrar, y si lo frena queda apuntado por qué;
  - el pago, por su día, pagaría la semana en curso y la anterior tiene horas
    sin pago: ¿de cuál es?;
  - cualquier aviso nuevo que la propuesta dé mañana: la lista es de lo que
    NO frena (solo el corte de mes, el de año, el devengo cuando se pone al
    día solo y la obra terminada, no aprobada o sin aprobar), no de lo que
    frena.
- **La obra terminada no frena.** Se decidió con la Bandeja de verdad
  delante: las obras se terminan *después* del trabajo, así que casi todo pago de una
  semana ya pasada tiene horas en una obra que hoy está terminada, o cuya
  propuesta sigue enviada o sin aprobar. Eso no pide adivinar nada: las
  horas dicen en qué obra se hizo el trabajo, y su parte va a esa obra
  igual. El pago entra solo y el aviso queda como **nota**: en «Registrado
  solo» y en el reparto (Costo por obra → Repartos). Lo que sí pregunta: unas
  horas con fecha *posterior* al día en que la obra se dio por terminada (el
  día que la app apunta al terminarla, para el año de garantía). La app no
  deja reportar horas en una obra terminada, así que esas horas son una
  vuelta de garantía (y van a esa obra) o se apuntaron en la obra
  equivocada: no se puede saber, y un costo en la obra equivocada no lo
  arregla nadie solo. Con «Así es» entra como está; si era otra obra, se
  corrige en Horas. No pregunta por una obra que se volvió a abrir (está en
  ejecución, aunque conserve su día de término), ni por una terminada sin
  ese día (no se sabe si las horas son de antes).
- **Lo que solo espera.** Un pago hecho de jueves a domingo paga la semana en
  curso: no pregunta nada; entra solo el lunes, con todas sus horas. (De
  lunes a miércoles paga la semana anterior, que ya terminó: entra enseguida.)
- **Cuándo corre.** Al abrir Contabilidad; después de subir un archivo del
  banco, de «Casar otra vez» o de sincronizar con el banco; y sin que abras
  nada, dos veces al día (a las 6:12 de la mañana y a las 3:50 de la tarde,
  hora de Miami en invierno; una hora más en verano), después de lo que el
  banco trae solo de madrugada. Lo que quede esperando lo dice la ronda de
  cada mañana.
- **Dos teléfonos a la vez no doblan nada.** Corre una sola vez a la vez (la
  segunda no espera: no hace nada), y cada pago entra por la puerta de
  siempre: un pago, un reparto.
- **Avanza siempre.** La rutina no se queda más de 3 segundos por llamada: si
  no le da tiempo, dice por dónde iba y la app la vuelve a llamar para que
  siga *después* de ahí. (Antes de la revisión cada llamada volvía a empezar
  por el pago más viejo: con bastantes pagos esperando tu respuesta, los
  nuevos no llegaban a entrar desde la pantalla.)
- **La IA.** Sigue sin registrar nada nunca. Su propuesta para un pago a la
  cuadrilla lleva una sola obra y no sirve: no se enseña en esos pagos ni en
  un cheque que aún pregunta, y la de un pago que entró solo queda cerrada
  con su porqué («es mano de obra de la cuadrilla: se registró sola»).
- **Apagarlo.** Costo por obra → Ajustes → «Registrar solos los pagos a la
  cuadrilla». De fábrica está encendido. Apagado, todo vuelve a ser como
  antes: cada pago espera tu «Así es».
- **Quién y por qué, escrito.** Cada reparto dice si entró solo o a mano, si
  la persona se reconoció por su nombre o la dijiste tú, y la regla (cuál,
  desde dónde corrió y en nombre de quién). Cada línea del asiento dice
  «registrado solo (la regla de Edgar)».

- **Los controles.** Ahora son 12 del reparto (7 cuadres y 5 avisos). El aviso
  nuevo: un pago a la cuadrilla que sigue en la Bandeja con su semana ya
  terminada (pide tu respuesta, lo deshiciste, o lo automático está apagado).
  El cierre del mes ya lo lleva a su fila de avisos (la 171), sin tocar c9.

### Cómo se probó
- **`c10-pruebas.sql`: 82 pruebas** (las 64 de antes y 18 nuevas), unos 35
  segundos. Las nuevas: el alta sola y lo ambiguo; el registro solo (y que
  nada toca 5000, 5001, 6000 ni 6005); cada aviso que lo frena —todos, leídos
  del código de la base: un aviso que se añada mañana frena sin tocar nada—;
  el deshacer que no vuelve; el cheque y «no es de la cuadrilla»; dos
  teléfonos; la IA; la tarea sin pantalla; el 1099; el devengo; lo apagado;
  la obra terminada, no aprobada o sin aprobar que no frena (un pago con
  horas en una obra terminada y en otra enviada entra solo y lleva la nota;
  con horas de después de terminada, pregunta); lo que encontró la revisión
  (la rutina avanza siempre, y registra en nombre de alguien); y que no
  queda nada.
- **Dos teléfonos de verdad a la vez** (`pruebas/conta/c10-concurrencia.sh`,
  31 comprobaciones): la rutina desde dos sesiones (una registra; la otra
  contesta «ocupado» y no hace nada), tu «Así es» y la rutina sobre el mismo
  pago, y un cheque «es de…» desde dos teléfonos. Un pago, un reparto.
- **Con años de horas** (`pruebas/conta/c10-volumen.sh`, 49 comprobaciones):
  con 40,000 reportes de horas, la rutina registra doce pagos sin pasar nunca
  del tope de la app (corta a los 3 segundos y la app la vuelve a llamar). Y
  con veinte pagos que preguntan delante de uno que entra: llamada sin
  decirle por dónde seguir (como antes de la revisión) vuelve a empezar cada
  vez y el pago no entra; como la llama la app ahora, cada llamada avanza y
  el pago entra.
- **Las demás capas** (c2, c3, c4, c6, c7, s1, p1, c8, c9, c11 a c16): sus
  suites dan lo mismo que antes del cambio, y sus guiones también.
- **La pantalla** (`pruebas/conta/pantalla.js`): una escena nueva con 60
  comprobaciones, en el teléfono, el iPad y la computadora (el pago con horas
  en una obra terminada entra solo y «Registrado solo» y Repartos enseñan su
  nota y cómo lo escribió el banco; cuando la base corta por reloj, la
  llamada siguiente sigue después);
  y con la base de antes de este cambio, todo sigue como estaba.
- **Lo que no se pudo probar desde aquí:** cómo escribe el banco de verdad el
  nombre de cada persona (producción no se toca). Al pegar, la fila «la
  cuadrilla, sola» dice a quién va a reconocer la base y a quién no.

### La revisión (15-nov, antes de pegarla)
Un revisor aparte la miró entera antes de que la pegaras. Lo que cambió:
1. **La obra terminada, no aprobada o sin aprobar ya no frena** (arriba). La
   tarifa lejos, la semana anterior sin pago y todo lo demás siguen
   frenando.
2. **Las horas de después de terminada la obra preguntan** (un aviso nuevo de
   la propuesta). Es poco frecuente y no se puede saber sola: garantía, o la
   obra equivocada.
3. **La rutina avanza siempre** (arriba). Con muchos pagos esperando una
   respuesta, cada llamada gastaba su tiempo en los mismos, los más viejos, y
   los nuevos no entraban desde la pantalla; y la pantalla esperaba todas sus
   rondas cada vez que abrías la portada o la Bandeja.
4. **Siempre en nombre de alguien.** La rutina y lo que se dice de un pago ya
   no corren desde el SQL Editor sin sesión (registraban sin decir quién).
   Sin pantalla está la tarea de la madrugada, que registra en tu nombre.
5. **«Registrado solo» y Repartos enseñan cómo lo escribió el banco.** La
   base reconoce a cada persona por su nombre como palabra entera. Si el
   nombre en la app es una sola palabra y el banco trae un pago a otro que
   empieza igual (un proveedor, por ejemplo), y el monto se parece a lo que
   valen sus horas de esa semana, ese pago entraría como suyo. Con dos
   destinatarios distintos en el banco la base ya pregunta; con uno solo no
   tiene cómo saberlo. Por eso el texto del banco va a la vista donde se
   deshace.

### Lo que queda dicho y no hecho
- **La IA sigue proponiendo por dentro** para un pago a la cuadrilla que
  espera tu respuesta (no se enseña, y se cierra cuando el pago entra).
  Quitarlo pide tocar la capa de la IA, y aquí no se tocó. La tarea de las
  6:12 corre antes que la de la IA, así que lo que entra solo no llega a
  gastar.
- **Los pagos de antes que clasificaste a mano.** Al reconocer sola a una
  persona, sus Zelle de antes que ya clasificaste en la Bandeja salen en un
  aviso («un pago de la cuadrilla resuelto por fuera»). Es verdad —sus horas
  de esas semanas siguen a estándar— y no frena nada. Se arregla des-casando
  ese pago en la Bandeja (entra solo, repartido) o se deja como está.
- **Las horas que se reportan tarde.** Si alguien reporta horas de una semana
  después de que su pago entró, esas horas no recibieron nada: lo dice el
  aviso de siempre (horas tardías). Se arregla deshaciendo y dejando que
  entre otra vez.
- **Sin el código del teléfono** la app no registra nada sola (registrar
  toca el libro): lo hace la tarea de la madrugada.
- **Un nombre de una sola palabra.** Arriba, en «La revisión», el punto 5:
  la base no adivina más de lo que el banco le deja ver. Lo más seguro es
  que cada perfil de la cuadrilla lleve nombre y apellido como los escribe
  el banco (o corregir su patrón en Costo por obra → Personas).
- **Un cheque cobrado tarde.** La semana que paga un cheque sale del día en
  que el banco lo cobra, como un Zelle. Cobrado una o dos semanas después,
  puede caer en otra semana: la tarjeta de «Registrado solo» dice cuál, y se
  deshace si no era.

### Tú
1. Pegar `c10-costo-obra.sql` (10 filas) y `c10-pruebas.sql` (82 filas), con
   la app cerrada. Nada más: ninguna otra capa cambia.
2. Abrir Contabilidad: la primera vez la base da de alta sola a la cuadrilla
   y registra lo que nada frena. Mira «Registrado solo» en la Bandeja.
3. Contestar lo que quedó preguntando (cada tarjeta dice qué) y los cheques.
4. Si alguien con horas no cobra por horas: Costo por obra → Personas → «No
   cobra por horas».
