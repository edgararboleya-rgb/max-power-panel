# La Bandeja nueva (c17) y las cuentas en inglés (c18)

**No es una fase del calendario.** Es lo que quedó pendiente de la Fase 7 el
16-nov («Dímelo con tus palabras» y sus dos añadidos) más la decisión de Edgar
del 21-nov («Cuentas y reportes» en inglés). Las capas se llaman c17 y c18
porque son la 17 y la 18 de la base; sus archivos de prueba llevan «f19».

## Lo que pidió Edgar

- 16-nov: «era mucho más fácil en QuickBooks». En cada tarjeta de la Bandeja,
  UNA recomendación con su botón; debajo, una caja para decirlo con sus
  palabras; la lista larga, detrás de «Más opciones».
- 16-nov: «la contabilidad y la parte operativa no trabajan como una sola».
  Una factura marcada cobrada en Proyectos es la respuesta del depósito que
  la paga. Las categorías, en dos niveles, como en un programa de contabilidad.
  Decidir por grupo de comercio, y que lo decidido entre solo después.
- 21-nov: los nombres de las cuentas, los estados y el paquete del año (lo que
  ve el contador), en inglés; la pantalla le sigue hablando en español.

## Lo construido (21 y 22-nov)

El 21 hubo tres vueltas. La primera construyó las dos capas y la
pantalla. La segunda (marca `2026112102`) arregló lo que encontró una revisión
de tres lentes (el dinero y el libro, la IA y la seguridad, la pantalla y
Edgar): está contado al final, en «La segunda vuelta». La tercera (marca
`2026112103`) arregló lo que encontró la segunda revisión, sobre todo que con
la Bandeja llena la lectura no cabía en el corte de la API: «La tercera
vuelta». La cuarta (22-nov, marca `2026112201`) arregló lo que encontró la
tercera revisión: «La cuarta vuelta». La quinta (22-nov, marca `2026112202`
en c17; c18 no cambió), lo que encontró la cuarta: «La quinta vuelta». La
sexta (22-nov, marca `2026112203` en c17; c18 no cambió), lo que salió al
estrenarla con la base de verdad: «La sexta vuelta».

### `docs/conta/c17-bandeja.sql` (marca 2026112203)

Se pega después de c1…c16. Necesita c1, c2, c3, c6 y c8; c10 es opcional (sin
él no hay «pago a la cuadrilla»). No cambia ninguna tabla ni función de otra
capa. Ninguna función es SECURITY DEFINER.

- **Cuatro tablas** (con RLS; solo el dueño lee; se escriben solo por las
  funciones de la capa): `bandeja_config` (lo de «entra solo» y su tope, el
  «Dímelo»), `bandeja_memoria` (lo que Edgar dijo de cada comercio o persona),
  `bandeja_dimelo` (cada frase y lo que se propuso) y `bandeja_hechos` (cada
  cosa que la Bandeja registró: con qué, por quién, si entró sola, si se
  deshizo).
- **La lista cerrada.** Todo lo que la Bandeja registra es UNA de estas
  acciones, y cada una entra por una puerta que el banco (c6) ya tenía, con sus
  guardas:

  | Acción | Qué es | Puerta |
  |---|---|---|
  | `gasto` | un gasto o un costo (con su obra si la cuenta la pide); en un depósito, la devolución de una compra | `fn_banco_clasificar` |
  | `personal` | es del dueño, no de la empresa (retiro del accionista) | `fn_banco_clasificar` |
  | `cobro` | el pago de una o varias facturas, con la comisión del procesador aparte | `fn_banco_cobrar` |
  | `anticipo` | un anticipo de una obra, todavía sin factura | `fn_banco_cobrar` |
  | `prestamo` | dinero de un préstamo (una deuda, no un cobro) | `fn_banco_clasificar` |
  | `aporte` | dinero del dueño que presta o aporta a la empresa | `fn_banco_clasificar` |
  | `traspaso` | entre cuentas propias, o el pago de una tarjeta | `fn_banco_transferencia` |
  | `cuadrilla` | el pago a alguien de la cuadrilla (se reparte por sus horas) | `fn_jornal_pago` (c10) |
  | `contratista` | el pago a un subcontratista por una obra | `fn_banco_clasificar` |
  | `otro_ingreso` | otro ingreso, o intereses que paga el banco | `fn_banco_clasificar` |
  | `banco` | una opción que el banco ya propone para ese movimiento, tal como la guardó | la que diga esa opción, de una lista fija de ocho |

  Para la IA hay una más, que no registra nada: `falta` (dice qué le falta).
- **`fn_bandeja_validar`** comprueba una acción contra la base (la cuenta
  existe y se puede usar, la obra existe, las facturas tienen ese saldo, el
  monto cuadra al centavo) y devuelve el texto llano que ve Edgar. Lo que
  recomienda la app, lo que contesta la IA y lo que elige Edgar pasan todos por
  ahí.
- **`fn_bandeja_hacer`** es «Así es»: valida y llama a la puerta, **siempre
  primero sin motivo**. Para el banco (c6) un motivo escrito quiere decir «lo
  leí y aun así»: por eso, si la puerta frena (su recibo ya está subido, una
  factura explica ese depósito, es la nómina, puede estar ya en el libro…),
  devuelve lo que dijo la puerta en llano (`por_que`), `pide_motivo` y la
  **huella de ese freno** (`freno`); y un porqué solo lo levanta si llega con
  esa huella (`visto`), o sea, escrito después de leerlo. Lo que el banco
  siempre pide por escrito (dinero del dueño, otro ingreso, «es mío» en algo
  que no es un cargo corriente) se **ensaya** antes sin motivo
  (`fn_bandeja_ensayo`, en una subtransacción que se deshace): la línea
  escrita no apaga los demás frenos. Al cobrar una factura la deja cobrada
  también en Proyectos (la factura, o su abono si es un pago a cuenta, y
  «Cobrado» de la obra).
- **`fn_bandeja_recomendar`** da UNA recomendación o ninguna, por este orden:
  un prestamista que el banco nombra por su nombre entero o su descriptor
  (antes que cualquier factura); dinero del propio dueño (nunca el cobro de un
  cliente); lo que el banco ya reconoce (un traspaso, los intereses, la cuota
  de un préstamo), dicho en llano y con su monto; lo que cobra el procesador
  de tarjetas; lo que Edgar ya dijo de esa contraparte; las facturas que
  explican el depósito; la propuesta pendiente de la IA (c8); y lo que sugiere
  la descripción entera del banco. Un gasto de obra propone la obra en la que
  estuvo la cuadrilla ese día, si fue una sola. (Cuarta vuelta) La primera
  opción del banco solo se da por buena si es la ÚNICA de su puerta que no
  pide un porqué (`fn_bandeja_opcion_cero`); con dos o más igual de válidas
  (el pago de una tarjeta, con dos tarjetas del mismo banco) **pregunta
  cuál** (`fn_bandeja_elige`: `{aviso, elige, pill}`), y una opción que el
  banco marca «con su motivo» no se recomienda nunca. Lo que **sale hacia un
  prestamista** se avisa (es su cuota) antes que lo recordado o el nombre. Y
  lo que Edgar **deshizo** de ese movimiento no se le propone otra vez
  (`{aviso, deshecha}`): se pregunta.
- **¿Qué facturas paga este depósito?** (`fn_bandeja_cobro_de`) busca entre
  TODAS las que tienen saldo, no entre las doce más cercanas; solo contesta si
  la respuesta es única; y un depósito de un procesador de tarjetas se casa
  con SU tarifa, factura a factura (las que trae `bandeja_config.tarifas`; las
  que Edgar confirma con un lote se quedan como las suyas), no con «lo que
  quepa hasta un 3.5 %».
- **`fn_bandeja_grupo`** aplica una respuesta a los CARGOS de una contraparte
  que la pantalla enseñó (o a un lote que el banco ya reconoce). Los depósitos
  no se deciden por grupo (MX008): cada uno paga sus facturas. Nunca lleva un
  porqué: el que algo frena se queda, con su porqué, y se contesta en su
  tarjeta. Deja su **tanda**, para deshacer la decisión entera
  (`fn_bandeja_deshacer_tanda`).
- **`fn_bandeja_solo`** registra solo lo que cumple todo esto: es un cargo, de
  un comercio, con una regla de Edgar que dice «que entre solo», de algo
  personal o de un gasto que **no lleva obra**, hasta el tope (500 de
  fábrica), sin otra explicación del banco, sin sospecha de duplicado, nunca
  deshecho, y sin que la puerta, hoy, lo frene. (Cuarta vuelta) Solo toma lo
  que el banco trajo DESPUÉS de que Edgar pusiera la regla
  (`bandeja_memoria.solo_desde`): los cargos de ese comercio que ya esperaban
  siguen esperando su «Así es». Antes de registrar, mira los recibos que
  llegaron después (`fn_bandeja_recibos`, abajo: no cambia nada). La pantalla
  la llama al abrir la Bandeja; pg_cron, dos veces al día
  (`mxp-bandeja-solo-manana` y `mxp-bandeja-solo-tarde`).
- **`fn_bandeja_recibos`**: el recibo que llega DESPUÉS de registrar su cargo
  deja el gasto dos veces. **No cambia nada sola** (tercera vuelta: el banco
  no deja volver atrás un cambio así): le da cada uno de esos cargos a c6 para
  que lo mire otra vez, y cuenta los que esperan. Cada uno sale arriba de la
  Bandeja con sus dos respuestas, «Es su recibo: cámbialo» y «Es otra compra»
  (lo que Edgar contestó solo lo cambia él). Si el cargo de verdad de ese
  recibo llega y casa con él, o si de dos cargos iguales el otro ya dijo «es
  su recibo» (cuarta vuelta: `fn_bandeja_hacer` lo mira en esa misma
  llamada), el que ya no tiene un recibo libre deja de esperar.
- **`fn_bandeja_deshacer`** deshace con su motivo lo que la Bandeja registró:
  lo des-casa por la puerta del banco (el pago a la cuadrilla, por la de
  c10), el asiento se reversa, el movimiento vuelve a la Bandeja y ya no
  entra solo. Si ese registro CREÓ un cobro, lo anula; un cobro que ya estaba
  anotado y con el que el depósito solo se casó, se queda (y «Cobrado» de su
  obra no baja: cuarta vuelta). **Proyectos queda como dice el libro** en ese
  momento, no como estaba antes de ese registro (con dos pagos a cuenta de
  una factura, deshacer el primero no la deja en cero). «Que lo siguiente
  entre solo» de esa contraparte se apaga, salvo `{deja_solo: false}`; y con
  `{olvida: true}` (cuarta vuelta) lo recordado de ella se da de baja en la
  misma llamada. La tarifa del procesador que ese cobro confirmó pierde esa
  vez.
- **`fn_bandeja_anotar`** no toca el libro: deja en el rastro de la Bandeja
  lo que quedó registrado por otro camino, para que salga en «Lo que
  contestaste estos días», se pueda deshacer y se recuerde. Lo que la IA de
  antes (c8) registró al aprobar su propuesta desde la tarjeta nueva (tercera
  vuelta) y, con `{fuente: "mas"}` (cuarta), lo que Edgar registra por el
  camino de antes dentro de «Más opciones»: «Según yo», «Otra cosa…» y las
  opciones del banco cuya puerta no es de las ocho de la lista.
- **El «Dímelo»**: `fn_bandeja_dimelo_contexto` y `fn_bandeja_dimelo_guardar`
  las llama solo la función de borde (no están en la API). La primera arma lo
  que se le da a la IA, ya tapado por la máscara (`fn_bandeja_sin_datos`: la
  de c8 más tarjetas, SSN, ITIN, EIN y teléfonos de siete cifras): el
  movimiento con las opciones del banco y su huella, las cuarenta facturas que
  le sirven a ESE movimiento (no las cuarenta más recientes), lo parecido ya
  resuelto y lo que Edgar ya enseñó. La segunda valida lo que contestó, anota
  su gasto contra el tope del contador y lo deja pendiente o «sin propuesta».
  `fn_bandeja_aprobar` y `fn_bandeja_rechazar` son de Edgar: aprobar registra
  lo que la base guardó ya validado. **La frase de Edgar no viaja como
  motivo**: la escribió antes de saber si el banco frenaba algo. Y una opción
  del banco se registra por su huella: si el banco la rehízo entre guardar y
  aprobar, la propuesta caduca.
- **`fn_bandeja_leer`**: lo que la pantalla lee. Recomendar cuesta unos 3 ms
  por movimiento en el banco de pruebas (diez veces más en producción), así que
  va POR RELOJ y por unidades (tercera vuelta): lo que no da tiempo vuelve en
  `faltan`, con su tarjeta «pensando», y la pantalla lo pide con `{ids}`. Trae
  las tarjetas (cuarta vuelta: cada una con la huella de cada opción del
  banco —`ops`: con ella los botones de «Más opciones» registran por esta
  capa lo que Edgar leyó—, lo que la app sabe de ese dinero —`sabe`: lo manda
  un prestamista, o el propio Edgar— y la obra del día de esa compra,
  `obra_dia`), los grupos de cargos (con la
  recomendación de sus tarjetas si coinciden; «mezclado» si no), los depósitos
  de un mismo pagador (uno a uno), lo registrado cuyo recibo llegó después, lo
  que entró solo, lo contestado en catorce días con sus tandas, lo recordado y
  lo del control que Edgar tiene que saber, en llano.
- **`fn_bandeja_control`**: cinco cuadres y cinco avisos.

### `supabase/functions/contador` — la acción `dimelo`

Una llamada por frase, con el esfuerzo «medium» (la ráfaga de c8 sigue en
«low») y su propio tope de salida (16 000: el pensamiento cuenta contra el
tope, y con 4 096 una respuesta difícil se cortaba). Las instrucciones son
fijas y van en la parte que se guarda en caché; el movimiento, las facturas,
lo parecido ya resuelto, **lo que Edgar ya enseñó** y la frase van aparte,
como datos (lo ya enseñado lleva nombres que escribió el banco: no es parte de
las instrucciones). La salida es un JSON con esquema: la acción sale de la
lista. La función no registra nada: guarda lo que la IA contestó y devuelve lo
que la base validó.

### `docs/conta/c18-fiscal.sql` (marca 2026112201)

Se pega después de c4. No renombra nada: el inglés va al lado.

- `fiscal_cuentas`: cada cuenta con su nombre en inglés, su sección, su grupo
  y su línea del Form 1120, del 1120-S y del 1125-A. Las 90 del plan vienen
  sembradas; una cuenta nueva sale con la línea de su tipo y marcada «sin
  mapear» hasta que se le dé la suya.
- `fiscal_lineas`: las líneas de los tres formularios (36, 36 y 5).
- `fiscal_config`: la forma de la entidad. De fábrica, 1120 y **sin
  confirmar**. Se cambia con `fn_fiscal_forma`; cambiarla quita la
  confirmación.
- `fn_fiscal_leer` (lo que lee la pantalla) y `fn_fiscal_paquete(año)`: la
  balanza con la línea de cada cuenta, el estado de resultados, el balance, el
  resumen por línea, el 1125-A, las utilidades retenidas según libros (los
  renglones del Schedule M-2) y el catálogo, todo en inglés y con sus avisos.
  Las líneas del Schedule L cuadran (activo = pasivo y capital: la línea de
  utilidades retenidas sale del balance de c4) y el 1125-A suma el costo de
  ventas de los libros. **Un año que la app lleva a medias lo dice**
  (`partial_year`, el período desde el arranque del libro, el título sin
  «Year-End» y el primer aviso: en 2026 el libro empieza el 1 de octubre; lo
  de antes está en QuickBooks), y **uno que no lleva sale vacío y lo dice**
  (`in_books` en falso). (Cuarta vuelta) **La balanza es la de los libros
  también desde el segundo ejercicio**: el libro no postea asientos de
  cierre, así que el resultado de los años anteriores va en un renglón aparte
  (`level: "component"`, sin `account`, con su línea y su nota), y
  `trial_balance_totals` trae sus totales, que suman 0. **El Schedule L es el
  balance**: las reclasificaciones de presentación del balance (los anticipos
  y saldos a favor de clientes, un banco en rojo…) van en sus líneas L
  (`schedule_l.reclassifications`) y el activo de las líneas L es el del
  balance general. Y el paquete lee cada vista de los estados UNA vez (antes
  la balanza, unas siete): con el año entero y el volumen de Edgar pasaba de
  0.8 s en el banco; ahora, 0.3.
- `fn_fiscal_control`: cinco cuadres (el 36, nuevo: la balanza del paquete
  suma 0 y es la de los libros) y tres avisos (el 37, nuevo: el activo del
  Schedule L es el del balance general).

### La pantalla (`js/conta.js`, `css/conta.css`)

- **La tarjeta** dice UNA cosa con su «Así es». Debajo, «¿Qué es? Dímelo con
  tus palabras». Lo de antes (el texto del banco, sus botones, «Según la IA /
  Según yo», «Otra cosa…») queda detrás de «Más opciones», con las categorías
  en dos niveles. (Cuarta vuelta) Si el banco lo reconoce de varias formas
  igual de válidas, la tarjeta **pregunta cuál**: un botón por opción, y la
  tocada se enseña entera con su «Así es». Y dentro de «Más opciones» los
  botones de «Lo que dice el banco» ya no registran de un toque ni llaman a
  la puerta del banco: el toque enseña en llano lo que se va a registrar
  (`fn_bandeja_validar`) y «Así es» lo registra por `fn_bandeja_hacer`, con la
  huella de lo leído (el freno de la capa, Proyectos al día, su rastro y su
  «Deshacer»); ninguno es el botón principal, y de un dinero que la app sabe
  que viene de un prestamista o del propio Edgar no se ofrece cobrarlo. Lo
  que siga por el camino de antes («Otra cosa…», «Según yo», el «Así es» de
  la IA de antes) queda anotado después (`fn_bandeja_anotar`).
  Después de «Así es», la tarjeta siguiente de la lista queda abierta: se
  contesta una detrás de otra. (Tercera vuelta) El cuerpo de una tarjeta se
  pinta al abrirla, y la Bandeja no se relee ni se repinta después de cada
  respuesta: sale la tarjeta contestada y, por detrás, se leen las tarjetas de
  ese comercio y lo demás. Lo que la base todavía no ha recomendado dice
  «Mirándolo…» y llega solo. (Cuarta vuelta) Si la respuesta dejó algo
  recordado, las demás tarjetas de ese comercio dicen «Mirándolo…» en ese
  momento y se piden solo ellas, sin esperar a lo demás; en la que Edgar ya
  tiene a medias sale una nota («Ya sé qué es lo de X… Ver lo que te propongo
  ahora») en vez de repintarla. Un fallo de la relectura de detrás que no sea
  un cuadre en rojo no tapa la página: se dice en la franja y se intenta otra
  vez.
- **Cuando el banco frena**, la tarjeta lo dice arriba del campo del porqué
  (con las palabras de la base) y el siguiente «Así es» manda el porqué con la
  huella de ese freno. Si la base contesta que la tarjeta ya no es la que se
  ve (casó sola con lo que ya estaba en el libro, lo que el banco proponía
  cambió, c10 apuntó de quién es el pago, o ya estaba contestado), la Bandeja
  se lee otra vez con esa tarjeta abierta.
- **Si la señal se corta después de mandar un «Así es»**, no dice «no se
  guardó»: dice que no sabe, vuelve a leer la Bandeja y dice lo que pasó.
- **«Decide por grupo»**, arriba: los comercios con varios CARGOS (cada grupo
  enseña sus movimientos; si sus tarjetas no dicen lo mismo, no propone nada)
  y los lotes que el banco ya reconoce. Los depósitos de un mismo pagador van
  juntos a la vista, sin una respuesta para todos. (Cuarta vuelta) Con «la del
  día de cada uno», la lista dice junto a cada compra a qué obra va (o que se
  queda); el titular del grupo sigue a lo elegido en la lista; el aviso dice
  como qué se registraron; y después de decidir un grupo la pantalla se queda
  en los grupos. Con la Bandeja nueva, la franja de la IA de antes va debajo,
  en una línea discreta y sin botón principal.
- **La franja**: lo del control de la Bandeja que Edgar tiene que saber;
  «Llegó el recibo de un cargo que ya habías registrado» (con «Es su recibo:
  cámbialo» y «Es otra compra»: nada se cambia solo); «Registrado solo» y
  «Lo que contestaste estos días» (con «Deshacer», y «Deshacer los N» para una
  decisión por grupo; si ese comercio tiene «que entre solo», la forma lo dice
  con su casilla marcada y la base lo apaga al deshacer) y «Lo que recuerdo»
  (olvidar, que entre solo o no —lo de una obra, nunca—, el interruptor
  general y su tope, y las tarifas de los procesadores con su «Olvidar»).
- **El rojo del banco por un recibo que llegó después** (el cuadre «ningún
  ticket después de clasificar») ya no tapa la Bandeja ni el Resumen: esos
  cargos salen arriba con sus dos respuestas.
- **El aviso** (el de toda la app): tocarlo lo quita y nada más; el toque no
  pasa a lo que tapa (en la tercera vuelta pasaba, y podía pulsar un «Así es»
  que no se veía). En el teléfono, dentro de Contabilidad, va arriba, sobre
  el membrete; en la computadora, de ancho un párrafo como mucho.
- **Estados**: con c18 los nombres van en inglés (un enlace los pone en
  español para esa sesión) y hay un apartado más, «Para el contador», que pasa
  el control de los estados como las demás pestañas y dice arriba, en español,
  si el año es parcial o si la app no lo lleva. (Cuarta vuelta) La balanza
  del paquete trae el renglón que no es una cuenta y sus totales, y los dos
  CSV llevan arriba los avisos del paquete. En el teléfono los apartados van
  en dos renglones.
- **Sin c17 o sin c18** nada de esto se pinta: la pantalla lo pregunta una vez
  por sesión y sigue como antes.
- La tarjeta de la mano de obra (c10), el cheque que pregunta de quién es, el
  depósito de Stripe y el cargo de Gusto que la nómina reconoce conservan la
  suya.

## Lo que entra solo y lo que nunca

- **Entra solo**: el cargo de un comercio para el que Edgar marcó «que lo
  siguiente entre solo», si es algo personal o un gasto que NO va a una obra
  (la gasolina, el software, el teléfono), no pasa del tope y la puerta del
  banco, hoy, no lo frena.
- **Nunca entra solo** (solo se propone): un depósito, un cobro, un Zelle a
  una persona o de una persona, un cheque, el cajero, la nómina, un traspaso,
  un préstamo, lo que el banco señala como posible duplicado, lo que pasa del
  tope, lo que ya se deshizo una vez, y **todo costo de obra**: a qué obra fue
  no lo sabe una regla (la cuadrilla en una sola obra ese día es una pista
  para proponerla, no para darla por hecha), y de esas compras suele llegar el
  recibo, que es quien dice la obra.
- La tabla lo impide (una regla «que entre solo» solo puede ser de un comercio,
  de un gasto o algo personal, y sin obra), `fn_bandeja_hacer` lo vuelve a
  comprobar y los cuadres 20 y 50 del control lo vigilan.
- La cuadrilla sola (c10) no se tocó: sigue igual.

## La IA propone y no registra

- La función de borde no tiene ninguna llamada que postee. Lo que guarda es
  una propuesta ya validada por la base.
- «Así es» manda a la base solo el id de la propuesta: lo que se registra es
  lo que la base guardó, no algo que viaje de vuelta desde el teléfono. Una
  opción del banco se guarda con su huella: si el banco la cambió después, no
  se registra otra cosa en su lugar; la propuesta caduca.
- La frase de Edgar no es un motivo: la propuesta pasa por la puerta del banco
  sin él, y si la puerta frena, Edgar lo ve y contesta, como en cualquier otra
  respuesta.
- La memoria la escribe Edgar: la IA puede sugerir «recordarlo», pero la base
  no recuerda nada que él no mande con su «Así es».
- El texto del banco, lo ya enseñado y la frase de Edgar van a la IA como
  datos, tapados por la máscara. Si la IA contesta una cuenta que la Bandeja
  no deja usar, una acción fuera de la lista, una comisión que no es de un
  procesador o pasa de su tope, o un cobro que no cuadra, la base lo deja «sin
  propuesta» y dice por qué.
- **Lo que sale hacia la IA**: la descripción y la nota del banco, la frase,
  los números y los montos de las facturas, y los nombres de las obras, de sus
  clientes, de la cuadrilla y de los subcontratistas (sin eso no puede decir
  de quién es un pago). No salen correos, teléfonos, números de cuenta, de
  tarjeta ni de identificación fiscal cuando van escritos como tales (con su
  palabra delante —«cel», «tlf», «cuenta»…— o con su forma: diez cifras de
  teléfono, un internacional con su «+», una tarjeta en grupos, un SSN): la
  máscara los tapa. Lo que no se distingue de un número cualquiera NO se
  tapa: siete cifras sueltas sin «tel» o «cel» delante, o un número de cuenta
  sin la palabra «cuenta». (Quinta vuelta) Las sumas que Edgar escribe —«la
  1103+1104», «2640.80+1450.75»— van enteras: antes la regla del teléfono
  internacional se comía la segunda mitad.

## El mapeo en inglés

| Cuentas | Form 1120 | Form 1120-S | Form 1125-A |
|---|---|---|---|
| 4010–4040 ingresos por contrato | 1a | 1a | |
| 4900 otros ingresos | 10 | 5 | |
| 4910 intereses ganados | 5 | Schedule K, 4 | |
| 4920 ganancia en venta de activos | 9 | 4 | |
| 5000 y 5001 mano de obra directa | 2 | 2 | 3 |
| 5100 material | 2 | 2 | 2 |
| 5010–5019, 5200–5950 los demás costos de obra | 2 | 2 | 5 |
| 1300 material en bodega | Schedule L, 3 | Schedule L, 3 | 7 |
| 6000 sueldos de oficina | 13 | 8 | |
| 6005 sueldo del oficial | 12 | 7 | |
| 6006 beneficios | 24 | 7 | |
| 6010, 6800 y 9000 impuestos y licencias | 17 | 12 | |
| 6100 renta | 16 | 11 | |
| 6700 publicidad | 22 | 16 | |
| 6950 depreciación | 20 | 14 | |
| 6980 cuentas incobrables | 15 | 10 | |
| 7100 intereses pagados | 18 | 13 | |
| 7910 donaciones | 19 | Schedule K, 12a | |
| 7920 multas (no deducibles) | Schedule M-1 | Schedule K, 16c | |
| los demás gastos (61xx, 62xx, 63xx, 64xx, 65xx, 66xx, 6900, 7900) | 26 | 20 | |
| 3200 retiros del accionista | Schedule M-2, 5a | Schedule K, 16d | |
| el balance (activo, pasivo, capital) | Schedule L | Schedule L | |

El detalle, cuenta por cuenta, está en `fiscal_cuentas` y sale en el paquete
(«Chart of accounts and tax-line mapping»). Los números de línea son los de
los formularios de 2025; el paquete lo avisa.

**La forma de la entidad no está confirmada.** La corporación figura en el IRS
como C-corp (su carta le asigna el 1120). Por eso el paquete sale con el 1120
y avisa en su primera línea de que falta confirmarlo. Si el contador dice que
es S-corp, se cambia en «Para el contador»: los números no cambian, solo la
línea de cada cuenta.

## La segunda vuelta (21-nov, marca 2026112102)

Lo que encontró la revisión y cómo quedó. Cada cosa tiene su prueba.

- **El freno del banco se saltaba.** El «Así es» de una propuesta del «Dímelo»
  mandaba la frase como motivo, y «es mío» ponía uno de la capa: para el banco
  eso es «lo leí y aun así», y sus frenos se apagaban (el gasto de un recibo
  ya subido entraba dos veces; la nómina, a un gasto). Ahora la puerta se
  llama siempre primero sin motivo y un porqué solo vale con la huella del
  freno que se leyó.
- **Una opción del banco se registraba por su número**, y el banco rehace sus
  opciones en cada «Casar». Ahora, por su huella.
- **El recibo que llegaba después** de registrar su cargo dejaba el gasto dos
  veces y la Bandeja y el Resumen en rojo, sin nada que tocar. Ahora se cambia
  solo si no hay duda; si la hay, sale arriba con sus dos botones.
- **Lo de una obra ya no entra solo**, y la casilla no se ofrece ahí ni en un
  cargo que pasa del tope.
- **Las facturas de un depósito** se buscan entre todas, con la tarifa del
  procesador; un prestamista no se reconoce por una palabra; dinero del dueño
  nunca es el cobro de un cliente; un pago a cuenta deja su abono en
  Proyectos; la retención se cobra; y deshacer devuelve Proyectos a como
  estaba.
- **Los grupos** son de cargos, dicen lo que sus tarjetas, enseñan lo que
  llevan dentro y se deshacen enteros. Los depósitos, de uno en uno.
- **La máscara** tapa además tarjetas, SSN, ITIN, EIN y teléfonos de siete
  cifras; la memoria la escribe Edgar; el contexto de la IA trae las facturas
  que le sirven a ese movimiento.
- **El paquete del año** cuadra su Schedule L, trae las utilidades retenidas,
  dice el año parcial y no presenta en ceros un año que la app no lleva.
- **La pantalla** dice en llano lo que el banco ya reconoce («Pago de la
  tarjeta», con su monto y sin códigos), no se atasca cuando c10 apunta un
  pago, no dice «no se guardó» si no lo sabe, y enseña lo del control.

## La tercera vuelta (21-nov, marca 2026112103)

Lo que encontró la segunda revisión y cómo quedó. Cada cosa tiene su prueba.

- **Con la Bandeja llena no cabía.** Con unos cuatrocientos pendientes,
  `fn_bandeja_leer` tardaba 1.3–1.5 s en el banco (trece o quince en
  producción) y la API corta a los 8: la Bandeja nueva no salía, y la de
  antes esperaba ese corte en cada apertura y después de cada respuesta. Ahora
  la lectura va por reloj (2.5 s) y por unidades (un grupo de cargos, entero;
  lo demás, de uno en uno; primero los grupos más grandes) y devuelve en
  `faltan` lo que no le dio tiempo; la pantalla pinta lo que hay y pide el
  resto por partes (`{ids}`). Decidir un grupo, deshacer una tanda y la rutina
  cortan a los 3 s y dicen `sigue`. En la pantalla, cada tarjeta pinta su
  cuerpo al abrirla (cerrada es solo su fila) y un «Así es» ya no relee ni
  repinta la Bandeja: sale esa tarjeta, se abre la siguiente y por detrás se
  leen las tarjetas de ese comercio y lo demás. Lo mide
  `pruebas/conta/c17-volumen.sh` con 400 y con 1,000 pendientes (cada llamada,
  por debajo de 0.8 s en el banco).
- **Nada se cambia solo por su recibo.** La segunda vuelta cambiaba sola por
  su recibo la compra «sin duda». Pero el banco (c6) no deja volver a
  clasificar un cargo pendiente que tiene un recibo libre de su monto («Esto
  ya está en el libro… clasificarlo lo metería dos veces»), con motivo o sin
  él: lo cambiado solo no se podía deshacer para volver a lo que Edgar había
  contestado. Ahora la rutina solo mira, y los cargos cuyo recibo llegó
  después esperan arriba, cada uno con «Es su recibo: cámbialo» (un toque) y
  «Es otra compra» (con su porqué). Lo que Edgar contestó solo lo cambia él.
  Y si, antes de que conteste, el cargo de verdad de ese recibo llega al banco
  y casa con él, el de antes deja de esperar solo: la rutina se lo da a c6
  otra vez y c6 quita la marca (antes seguía arriba hasta el siguiente «Casar»
  de su cuenta, con un «Es su recibo» que el banco ya no podía cumplir).
- **Lo que propone la IA de antes (c8)** es lo que dirá buena parte de las
  tarjetas, y salía distinto: «Es un gasto de «Es mío…»», el motivo crudo de
  c8 con sus códigos, sin «Recordarlo», y su «Así es» no dejaba rastro en la
  Bandeja. Ahora se dice como las demás (un gasto de su categoría, «es tuyo»,
  o un gasto de obra con la obra que ella propone solo si es firme y sigue en
  marcha; si no, se pide), se aprueba por su función de siempre y la Bandeja
  lo anota (`fn_bandeja_anotar`): queda en «Lo que contestaste estos días»,
  se recuerda y se deshace (la propuesta aprobada se caduca por su función).
- **Deshacer no apagaba «que entre solo».** Deshacer la respuesta que había
  puesto la regla la dejaba encendida, y el siguiente cargo de ese comercio
  entraba solo con lo que Edgar acababa de decir que estaba mal. Ahora la base
  la apaga al deshacer (un hecho o una tanda entera) y dice de quién; la forma
  lo enseña con una casilla marcada, que se puede desmarcar.
- **Deshacer, además:** el pago a la cuadrilla se deshace por la puerta de c10
  (su reparto queda deshecho, no «aplicado» con el asiento reversado);
  Proyectos queda como dice el libro (con dos pagos a cuenta, deshacer el
  primero ya no deja la factura en cero); y la tarifa que ese cobro confirmó
  pierde esa vez.
- **Un prestamista o el propio Edgar.** Si el banco mismo dice que el depósito
  lo manda un prestamista, o Edgar, registrarlo como el cobro de un cliente (o
  un anticipo) frena en esta capa y pide su porqué leído; y a la IA se le dice
  como dato. El texto de un freno por facturas por cobrar dice la verdad
  («podría ser una parte de una de ellas»), y la caja del porqué sale con lo
  que Edgar ya había escrito en el «Dímelo».
- **Lo que escribe la IA**: sin enlaces, corto, y dicho que es suyo («La IA
  dice: …»). Una respuesta con un carácter nulo, o que la base no puede
  guardar, ya no pierde su gasto ni su rastro. La máscara no deja pasar un
  correo ni un número partidos por un salto de línea (tampoco una tarjeta
  escrita en renglones), ni un teléfono de siete cifras seguidas detrás de
  «tel».
- **Lo que la IA de antes proponía y Edgar registra por otro camino** (su
  grupo, «Más opciones»): esa propuesta pendiente la cierra la pantalla por la
  función de c8, que solo sabe «rechazarla». Si proponía LO MISMO que se
  registró, la base lo dice (`propuestas_ia_iguales`) y el motivo que queda
  escrito es ese («…con la misma categoría que proponía la IA»), no «lo
  contestó de otra forma». Sigue contando entre las «rechazadas» de c8 (mira
  «Lo que queda pendiente»).
- **Contrapartes y memoria**: un ayuntamiento que cobra cosas distintas con el
  mismo nombre son contrapartes distintas; lo recordado de un comercio no se
  aplica cuando la descripción de ahora sugiere otra cosa; un pagador
  recordado sin factura que cuadre se pregunta (nunca se supone un anticipo);
  un cobro ya anotado que espera su depósito va antes que cualquier factura.
- **Las tarifas de los procesadores**: las de fábrica se siguen probando
  aunque haya una confirmada, y se ven y se olvidan en «Lo que recuerdo».
- **La pantalla**, además: el «Dímelo» ocupa su tarjeta y no la Bandeja
  (mientras la IA piensa se contestan las demás); lo que espera, se dice; con
  la IA apagada no dice «llegó a su tope»; un grupo que no entra entero sigue,
  con lo que se quedó escrito dentro y pidiendo la obra en vez de «la del
  día»; «Ver los N grupos» añade los que no se veían sin tocar el grupo en el
  que Edgar ya está eligiendo (los grupos no se repintan debajo de su dedo, y
  ese botón los repintaba: con un grupo a medio elegir no hacía nada); lo de
  una obra no ofrece «entra solo» en «Lo que recuerdo»; la nota
  del recibo sale solo en un comercio; los botones del banco de «Más opciones»
  ya no traen códigos de cuenta; el aviso de abajo, en el teléfono, sale a
  todo el ancho, no se come los toques y dura lo que tarda en leerse.
- **El paquete del año (c18)**: las comidas (6350) van en su línea al 100 %
  de libros con la mitad no deducible dicha y a qué línea del formulario va
  (en un aviso y en el renglón de la cuenta: en la pantalla, en la hoja de
  imprimir y en el CSV del resumen por línea, columna «Note»);
  y en el año parcial las utilidades retenidas dicen que el saldo de apertura
  no está en este sistema.
- **Las pruebas de c17 valen con la base en uso**: cada una mira solo sus
  movimientos, así que se pueden correr en producción con la Bandeja llena.

## La cuarta vuelta (22-nov, marca 2026112201)

Lo que encontró la tercera revisión y cómo quedó. Cada cosa tiene su prueba.

- **La primera opción del banco ya no se da por hecha.** Con dos tarjetas del
  mismo banco dadas de alta, el pago de una desde el banco salía afirmado con
  la primera que el banco ordena («Es el pago de tu tarjeta … Blue»), y
  cuando después llegaba el abono a la otra, «Es el pago de esta tarjeta»:
  dos «Así es» a dos frases seguras dejaban el pago dos veces en el banco del
  libro, con todos los controles en verde. Ahora la primera opción se
  recomienda solo si es la única de su puerta que no pide un porqué; con
  varias, la tarjeta pregunta cuál; el abono en la tarjeta que no dice que es
  un pago se propone como la devolución de una compra (o se pregunta); y el
  abono que sí lo es no se recomienda si hay un pago por ese monto,
  registrado hace poco como el de OTRA tarjeta, que sigue sin llegar a ella.
- **«Más opciones» se saltaba la capa.** Los botones de «Lo que dice el
  banco», «Según yo» y «Otra cosa…» llamaban directo a las puertas de antes:
  sin el freno del prestamista, sin dejar Proyectos al día, sin rastro ni
  «Deshacer». Ahora las opciones del banco entran por `fn_bandeja_hacer` (con
  su huella) después de enseñar qué se registra; lo demás queda anotado con
  `fn_bandeja_anotar`; y del depósito de un prestamista (o de Edgar) no se
  ofrece cobrarlo.
- **Lo que sale hacia un prestamista** es la cuota de un préstamo: la tarjeta
  lo avisa, registrarlo como un gasto, algo personal o un pago por trabajo
  frena (el freno es de esta capa y pide su porqué leído), no se recuerda ni
  entra solo, y a la IA se le dice qué hacer con ello (regla 7 de sus
  instrucciones). El desembolso de un préstamo tampoco entra como dinero del
  dueño ni como un traspaso sin su porqué.
- **La caja del porqué ya no sale escrita** con lo que Edgar dijo en el
  «Dímelo» antes de leer el freno (un segundo toque levantaba cualquier
  freno): la base lo devuelve como `ejemplo` y la pantalla lo deja en gris.
  Solo va escrito (`sugerido`) lo que el banco mismo dice: el nombre del
  prestamista.
- **La máscara** tapa además un correo partido por un espacio o un salto de
  línea alrededor de la arroba.
- **«Que entre solo» no barre lo que ya esperaba**: la rutina solo toma lo
  importado después de poner la regla (`solo_desde`), y «dudosa» ya no es un
  motivo que entre solo.
- **Deshacer**: el cobro que ya estaba anotado se queda y «Cobrado» de su
  obra no baja; lo deshecho no se recomienda otra vez en la tarjeta que
  vuelve; la forma ofrece «y olvida lo que te dije de X»; y la pantalla va a
  la tarjeta que volvió.
- **El recibo que llega después, en el otro orden**: de dos cargos iguales
  con un recibo, «es su recibo» en el primero ya no deja al segundo arriba
  diciendo que su gasto está dos veces, con dos botones que fallaban.
- **Lo que explico se ve en la siguiente del mismo comercio**: mirándolo en
  el momento, sin esperar a la relectura entera y sin tirarla por otra
  respuesta.
- **Después de decidir un grupo, la pantalla se queda en los grupos**; el
  titular sigue a la lista, el aviso dice como qué, la obra de cada compra se
  ve antes de confirmar, y lo que falta se dice una vez.
- **El aviso no deja pasar los toques** ni tapa las acciones en el teléfono.
- **La balanza del paquete cuadra desde el segundo ejercicio**, el Schedule L
  da el mismo activo que el balance, el paquete cabe en el tope de la casa
  con el año entero (lo mide `pruebas/conta/c18-volumen.sh`) y sus avisos
  viajan en los dos CSV.
- **Textos**: sin el tipo del banco ni «entró por plaid» en la tarjeta, sin
  el número del asiento en los avisos, «se anula (queda escrito que se
  anuló)» en vez de «se reversa», los montos con su formato, el texto del
  cargo sin recibo sin «puente» ni «casa sola», y un corte de la API dice que
  no se guardó nada. El aviso del préstamo sin dar de alta dice qué hacer de
  verdad; el depósito del procesador sin facturas que cuadren dice de quién
  es; el Resumen cuenta los cargos cuyo recibo llegó después.

## La quinta vuelta (22-nov, marca 2026112202)

Lo que encontró la cuarta revisión y cómo quedó. Tres de sus hallazgos eran
cosas que la cuarta vuelta había roto al arreglar otras. Cada cosa tiene su
prueba; `c18-fiscal.sql` no cambió (sigue con la marca `2026112201`).

- **El botón del banco que se toca es lo que se registra.** En «Más opciones
  → Lo que dice el banco» la pantalla esconde las opciones que nombran la
  cuenta de paso de Stripe y numeraba los botones sobre la lista ya recortada;
  desde que esos botones van por la Bandeja, ese número viajaba a la base, que
  lo cuenta sobre su lista entera: cada botón quedaba corrido un puesto (tocar
  «Para Edgar…: distribución» enseñaba y registraba «A Reserva de impuestos»).
  Ahora cada opción lleva su número de la base desde que se lee
  (`prepararMov`), y hay un segundo candado: `fn_bandeja_validar` devuelve la
  opción que validó (`opcion_banco`: su puerta y sus argumentos) y la pantalla
  no enseña ninguna caja si no es la del botón tocado.
- **El cobro anotado «depositado neto de su comisión» es una suposición del
  banco.** Le vale con que a un depósito le falte hasta un 3.5 % respecto de
  un cobro anotado sin depositar: no mira quién deposita. La cuarta vuelta lo
  recomendaba arriba con su «Así es»: con un cheque anotado a mano y el Zelle
  de otra persona por un poco menos, un toque casaba el Zelle con el cobro del
  cheque y mandaba la diferencia a comisiones. Ahora se recomienda solo si lo
  deposita un procesador de tarjetas y lo que falta es una de sus tarifas; si
  no, la tarjeta sigue su orden de siempre y, si nada lo explica, pregunta
  diciendo el cobro que podría ser y cuánto le falta. Los dos botones del
  banco («depositado neto» y «anotado por otro monto: corrígelo») dicen cada
  uno lo suyo con sus montos (decían la misma frase), y lo deshecho de este
  tipo no se propone otra vez.
- **«Es otro movimiento»** (el posible duplicado que no lo es) dejaba la
  respuesta guardada, pero la Bandeja contestaba «No se registró: sigue en la
  Bandeja.» y la tarjeta seguía preguntando lo mismo. Ahora lo dice
  («Anotado: es otro movimiento… Ahora dime qué es.») y la tarjeta se pone al
  día.
- **La IA de antes ya no está dentro de la tarjeta cuando la app sabe de
  quién es el dinero.** El freno del prestamista cubría la lista, el «Dímelo»,
  los grupos, la rutina y los botones del banco, pero en «Más opciones»
  seguían «Según la IA» (su «✓ Así es» registraba la cuota entera como gasto
  por la puerta de c8, que además aprendía la regla para las siguientes),
  «Según yo» y «Otra cosa… → clasificarlo a una cuenta». En un movimiento que
  el banco dice de un prestamista (o de Edgar) ya no se pintan: se contesta
  en la lista, que frena y pide el porqué después de leerlo. La propuesta de
  c8 de ese cargo NO se cierra: c8 vuelve a proponer todo cargo sin propuesta
  pendiente, así que cerrarla solo haría que la IA la propusiera (y la
  cobrara) otra vez en cada ráfaga; queda pendiente y sin pintar.
- **Después de decidir un grupo, la pantalla se queda donde estaba sin
  depender del navegador.** La relectura por detrás repinta la franja de
  arriba («Lo que contestaste estos días» crece, o se abre sola) y todo lo de
  debajo bajaba; que no se notara era cosa del «anclaje» de Chromium, que no
  actúa con la página arriba del todo y que el Safari del iPhone no trae.
  Ahora la pantalla mide dónde estaba lo que Edgar mira (la tarjeta abierta,
  o los grupos) y se desplaza lo que creció lo de arriba (`bnQuieto`).
- **Menores**: la máscara del «Dímelo» ya no se come las sumas que Edgar
  escribe («la 1103+1104») ni un monto detrás de «cel», y tapa un teléfono
  pegado de WhatsApp (espacios de ancho cero, cifras anchas) y el que lleva
  «tlf»; al aprobar una propuesta del «Dímelo», la huella de un freno ya no
  trae como porqué la frase de antes; la opción del banco que se quedó vieja
  (su factura ya se cobró por otro lado) se dice en llano en vez de dar por
  buena la caja; los botones del abono en la tarjeta dicen la cuenta por su
  nombre («desde Banco operativo»); y «Ya sé qué es lo de X» ya no deja debajo
  «estoy mirando…».
- **Al integrar (lo que encontró la revisión de la quinta vuelta)**: el
  arreglo de la máscara convertía en cifras lo que no se ve (`translate`
  empareja por puesto: «1103» con un espacio de ancho cero detrás llegaba a
  la IA como «11030», y así quedaba en la frase guardada y en la descripción
  del asiento). Ahora lo que no se ve se borra, las cifras anchas pasan a las
  suyas y un emoji compuesto queda entero; la prueba 80 compara el texto
  exacto. La máscara vuelve a tapar el teléfono escrito de dos en dos con
  puntos detrás de «cel» o «tel» y el internacional cuyo «+» va pegado a una
  letra o a una coma. Los botones del pago de la tarjeta dicen «Desde Banco
  operativo», sin el código. Y el aviso con «Deshacer» de la app de siempre
  ya no se quita por tocar su texto.

## La sexta vuelta (22-nov, marca 2026112203)

Lo que salió el día que la Bandeja nueva se estrenó con la base de verdad.
`c18-fiscal.sql` no cambió; `c6` tampoco (no hay que volver a pegarlo). La
pantalla (`js/conta.js`) no cambió en la sexta vuelta, pero SÍ en su segunda
pasada (la 6b, más abajo): hay que publicar la app. La función `contador` no
se toca.

- **Una línea de crédito no es un préstamo a plazo.** Un mismo prestamista
  puede tener las dos cosas, y el banco las escribe casi igual (el nombre del
  prestamista con dos cifras detrás, distintas para la cuota del préstamo,
  para el pago de la línea y para sus desembolsos) y sin ningún número de
  cuenta. Con el préstamo dado de alta por un descriptor ancho (solo el nombre
  del prestamista), todo era «del préstamo»: el pago de la línea salía como
  su cuota con un abono a capital, y el desembolso de la línea como dinero de
  ese préstamo, a su cuenta. c6 solo reconoce una deuda propia por su número
  (que aquí el banco no escribe) y su tabla `prestamos` es para lo que tiene
  cuotas: una línea ahí rompería el saldo que llevan las cuotas.
  Ahora la línea se da de alta en la Bandeja, desde el SQL Editor, con
  `fn_bandeja_linea({nombre, descriptor, cuenta, cuenta_interes})` (queda en
  `bandeja_config.lineas`; no es de la API). Desde entonces:
  - lo que el banco escribe como lo de la línea es de la línea, antes que
    cualquier préstamo (`fn_bandeja_prestamista`: `por: 'linea'`), también
    si en la lista se elige a mano el préstamo a plazo del mismo prestamista
    (es el único que sale en «¿De qué préstamo?»);
  - su **desembolso** se recomienda como «Es dinero de tu línea de crédito de
    …» y sube la deuda de la línea (2510);
  - su **pago** se recomienda como «Es un pago a tu línea de crédito de …» y
    pide una cosa: cuánto de ese pago fueron intereses (lo dice el estado de
    cuenta de la línea; 0 si no hubo). Lo demás baja la deuda (2510) y los
    intereses van a su gasto (7100), en un solo asiento, por la puerta de c6
    (`fn_banco_clasificar` con dos líneas). Sin ese dato no se registra. Así
    el saldo de la línea en el libro es, después de cada pago, lo que el
    prestamista dice que se debe;
  - con facturas por cobrar mayores que el desembolso, c6 frena (como con
    cualquier depósito de un prestamista): la tarjeta lo dice sin mandar a
    cobrar la factura y deja la respuesta escrita; se confirma y entra;
  - registrar ese pago como un gasto entero frena (como la cuota de un
    préstamo); nada de ello se «recuerda» (ya se reconoce, y la clave de su
    contraparte puede ser la de las cuotas del préstamo); lo deshecho SÍ se
    propone otra vez (se deshace para corregir los intereses); y el control
    no manda a dar de alta ningún préstamo por ello.
  La línea **no se da de alta** si el banco ya escribió algún movimiento que
  casa a la vez con ella y con el descriptor de un préstamo dado de alta: lo
  dice, y se estrecha antes el del préstamo por su puerta de c6
  (`fn_prestamo_guardar` con su `id` y el `descriptor` nuevo), para que solo
  case con sus cuotas. Y lo que el banco escriba de una tercera forma no se
  le supone ni al préstamo ni a la línea: se avisa (desde la 6b, también si
  es un depósito, y sin decir «todavía no está dado de alta»).
- **La pregunta con botones iguales.** Un pago a un préstamo por más que su
  cuota trae de c6 dos respuestas igual de válidas del MISMO préstamo («la
  cuota y lo demás a capital» y «con el capital y el interés de su estado de
  cuenta»). La tarjeta preguntaba «puede ser de más de uno. ¿De cuál es?» con
  dos botones iguales (el nombre del préstamo, dos veces). Ahora dice «Es un
  pago a … : su cuota de … y … más… ¿Cómo lo registro?» y cada botón dice lo
  que lo distingue («La cuota y $700.00 más a la deuda», «Con lo que dice su
  estado de cuenta»).
- **Dos opciones distintas no comparten huella.** La huella de una opción del
  banco miraba su puerta y sus argumentos; esas dos opciones llaman a la
  misma puerta con los mismos argumentos (lo que cambia es lo que la opción
  PIDE), así que tenían la misma: la del primer botón valía para el segundo.
  Ahora la huella cuenta también los datos que la opción pide. La de una
  opción que no pide ningún dato es la de siempre (lo ya registrado y lo
  deshecho siguen valiendo).
- **Las pruebas no dependen de los préstamos que tenga la base.**
  `c17-pruebas.sql` usaba un prestamista de verdad como «el que no está dado
  de alta»: en una base que sí lo tenía, seis pruebas daban rojo; y otra
  esperaba el capital de una cuota en la cuenta de largo plazo, que es donde
  cae solo si la corriente no tiene saldo en el libro. Ahora el prestamista de
  las pruebas (y el de la semilla y el de la pantalla) es inventado
  («Zzlend»: c17 lo trae en su lista de marcas solo para eso) y la cuota se
  mira en la deuda del préstamo, sea cual sea de sus dos cuentas. Se corren
  también sobre un clon «como producción»: con un préstamo de ese prestamista
  dado de alta con descriptor ancho, y con él ya estrechado y la línea dada
  de alta. La semilla da de alta la tarjeta de la empresa si la plantilla no
  la trae.

### La segunda pasada (6b, 22-nov; la marca sigue siendo 2026112203)

La sexta vuelta se revisó antes de publicarla. La revisión la aprobó y dejó
nueve cosas menores; esta pasada las cierra para que se pegue una sola vez.
Cambian `c17-bandeja.sql` (una función más: 60), sus pruebas y, esta vez sí,
la pantalla (`js/conta.js`).

- **La coma decimal.** Un monto que Edgar escribe en una casilla de la
  Bandeja (los intereses de un pago de la línea; el capital y el interés de
  una cuota «con lo que dice su estado de cuenta») se leía quitándole las
  comas sin mirar: «6,50» entraba como $650.00 de intereses y «61,37» se
  rechazaba sin decir por qué. Ahora una coma que no es de miles no se lee:
  «Escribe los centavos con punto, como 61.37.» «61.37», «$61.37» y
  «1,000.00» siguen valiendo. Lo comprueba la pantalla (`montoEscrito`, antes
  de llamar) y otra vez la base (`fn_bandeja_monto_escrito`, en
  `fn_bandeja_validar`): la pantalla publicada de antes quita las comas antes
  de mandar, así que hasta publicar la app la comprobación de la base no ve
  la coma.
- **El pago de la línea por «Dímelo».** Lo que la IA entendía («es el pago de
  la línea») quedaba como una propuesta que no se podía aprobar: ni la caja
  pintaba la casilla de los intereses ni la base los pasaba. Ahora
  `fn_bandeja_dimelo_guardar` dice qué pide (`pide`) también para el pago de
  una línea, `fn_bandeja_leer` lo sigue diciendo cuando la propuesta viene en
  su tarjeta, y `fn_bandeja_aprobar` pasa los intereses (`campos`). La frase
  de la tarjeta dice «Pon abajo cuánto de este pago fueron intereses…» (antes
  «Dime cuánto…», que invitaba a contestarlo en esa caja). **Queda para
  cuando se vuelva a desplegar la función `contador`:** la regla 7 de sus
  instrucciones le manda a la IA contestar «falta: ese préstamo hay que darlo
  de alta» a todo cargo hacia un prestamista sin una opción de cuota; para el
  pago de una línea ya dada de alta eso no es verdad (el dato que recibe sí
  lo dice bien). La recomendación de la tarjeta, con su casilla, no depende
  de la IA.
- **Lo que el banco escribe de una tercera forma.** Si ese prestamista ya
  tiene algo dado de alta (un préstamo y una línea, dos préstamos, o solo una
  línea) y el texto no casa con ninguno, `fn_bandeja_prestamista` lo dice
  (`otra_forma`, y `tiene`: lo que tiene, en llano). Ni el cargo ni —esto es
  lo nuevo— el depósito se recomiendan: sale un aviso sin «Así es» («… tiene
  un préstamo y una línea de crédito dados de alta y el banco escribe este
  depósito de otra forma: no lo contestes y avisa a quien te lleva la app»).
  Antes el depósito salía como «dinero de un préstamo de … (todavía no está
  dado de alta)» con su «Así es», e iba a la cuenta de los préstamos sin alta,
  que puede ser la de un préstamo que sí lo está (y el cuadre de préstamos del
  banco se ponía rojo). Como dinero de un préstamo ya no se registra desde la
  Bandeja: tampoco eligiendo el préstamo en la lista, ni si lo propone la IA.
  El control ya no manda a «dar de alta» nada por ello. Con UN solo préstamo
  de ese prestamista y ninguna línea, todo sigue como antes (es ese préstamo).
- **Los cargos de una línea, de uno en uno.** Con dos pagos de la línea
  esperando salía un grupo «una respuesta vale para todos», que no podía
  registrar ninguno (cada pago lleva sus intereses). Ya no entran en ningún
  grupo. Y la tarjeta de un movimiento de la línea lo dice (`linea`) y dice
  que no se recuerda (`no_recordar`): la pantalla no ofrece «Recordarlo»
  (salía marcada y no guardaba nada), y la base no recuerda nada de un
  movimiento de la línea, sea cual sea la respuesta.
- **Las frases fijas de la pantalla** («Más opciones») ya no dicen «es la
  cuota de un préstamo» de lo de una línea: «es un pago de tu línea de
  crédito» o «es dinero de tu línea de crédito», según el signo. La fila dice
  «Línea de crédito».
- **«Con lo que dice su estado de cuenta».** Lo que quedaba escrito al
  registrar con ese botón («Registrado: …», «Lo que contestaste estos días»)
  era la pregunta. Ahora dice lo que entró: «Es un pago a …: $… ($… bajan la
  deuda y $… son intereses, según su estado de cuenta).»
- **No se sabe todavía con qué texto deposita ese prestamista un préstamo a
  plazo.** Los tres textos vistos son nombres de 16 letras del emisor del
  pago: uno para la cuota del préstamo, otro para el pago de la línea y otro
  para lo que ENTRA. Puede que este último sea el de todo lo que ese
  prestamista deposita, no solo el de la línea: si fuera así, el dinero de un
  préstamo nuevo (o de una renovación) saldría como «dinero de tu línea de
  crédito», y desde la Bandeja no hay forma de mandarlo a un préstamo (la
  línea manda aunque en la lista se elija el préstamo): solo desde el SQL
  Editor. No se cambió nada: los movimientos del banco no llegan tan atrás
  como para verlo, y se le pregunta a Edgar cómo llegó el dinero de su
  préstamo a plazo. Si llegó con ese mismo texto, en otra ronda: que elegir un
  préstamo en la lista valga con un porqué escrito.
- **El volumen.** El criterio «la Bandeja entera en N llamadas o menos» de
  `c17-volumen.sh` dependía de la carga de la máquina (cada llamada recomienda
  lo que le cabe en su reloj): con el mismo código, 1,000 pendientes pedían de
  8 a 13 llamadas según la corrida. El margen pasa de 4 y 10 a 6 y 14, y queda
  escrito; lo que se exige de verdad (ninguna llamada pasa de 0.8 s, cada
  tarjeta una vez, nada queda por pedir) no cambia.
- **El SQL de datos de la línea** (fuera del repositorio) para también si
  algún movimiento de la línea ya se contestó de otra forma (como dinero o
  como la cuota del préstamo a plazo, como un gasto, o se ignoró): antes daba
  «ok» y dejaba la deuda de la línea corta y la del préstamo larga.

## Las pruebas

- `docs/conta/c17-pruebas.sql`: 85 filas (sobre la base limpia, con la semilla
  f19, con mil pendientes y —sexta vuelta— sobre un clon «como producción»:
  con un préstamo del prestamista de verdad dado de alta con descriptor ancho
  y saldo en su cuenta, y con él estrechado y la línea dada de alta). La 82 es
  la línea de crédito de punta a punta; la 83, la pregunta con botones
  iguales y las huellas; (6b) la 84, la segunda pasada de la línea (la coma
  decimal, el «Dímelo», de uno en uno y sin recordar, y lo que el banco
  escribe de otra forma); la 85, «con lo que dice su estado de cuenta». La 81
  («nada queda») corre la última.
- `docs/conta/c18-pruebas.sql`: 15 filas.
- `pruebas/conta/c17-volumen.sh`: la Bandeja con 400 y con 1,000 pendientes,
  como el dueño por la API, cada llamada por debajo de 0.8 s (el número de
  llamadas para leerla entera depende de la carga de la máquina: va con
  margen, 6 y 14, y lo dice).
- `pruebas/conta/c18-volumen.sh` (cuarta vuelta): el paquete del año sobre el
  libro de volumen de c4 (quince meses, 250 por mes), como el dueño por la
  API, por debajo de 0.8 s; la balanza de los dos ejercicios suma 0 y es la
  de c4, y el Schedule L es el balance.
- `pruebas/conta/bandeja-e2e.mjs`: la función de borde de verdad contra el
  banco de pruebas y el simulador de la IA, 43 comprobaciones (la frase tapada,
  la lista cerrada, la inyección en la frase y en la descripción del banco con
  una acción válida —queda como propuesta: ni en el libro ni en la memoria sin
  el toque de Edgar—, el freno por un recibo ya subido, la opción que cambia,
  el tope, el esquema; tercera vuelta, el prestamista dicho a la IA, la
  máscara con saltos de línea, el carácter nulo, los enlaces y la frase como
  ejemplo del porqué; cuarta, el cargo hacia un prestamista; y, 6b, el pago de
  una línea de crédito por el «Dímelo»: la propuesta dice qué pide y se
  aprueba con sus intereses, nunca con coma decimal).
- `pruebas/conta/pantalla.js`: 242 comprobaciones de esta escena (6b: seis
  más, las de la línea de crédito, con un guion nuevo de la base simulada:
  la casilla de los intereses y la coma decimal, sin «Recordarlo» y sin
  grupo, el «Dímelo» con su casilla, y las frases fijas), con la base
  simulada sacada del banco (`f19-capturar.js` → `pantalla-f19.json`, semilla
  `f19-semilla.sql`; las lecturas por partes, con `f19-parte.js`, que el
  capturador comprueba contra la base). Solo esa escena:
  `SOLO=f19 node pruebas/conta/pantalla.js`.

## Lo que queda pendiente

- **(6b) La regla 7 de las instrucciones de la IA** (`supabase/functions/contador`,
  que no se tocó): a todo cargo hacia un prestamista sin una opción de cuota le
  manda contestar «falta: ese préstamo hay que darlo de alta». Para el pago de
  una línea de crédito ya dada de alta eso no es verdad (el dato que recibe sí
  dice que es un pago de la línea y que se registra con la recomendación de su
  tarjeta). Hay que cambiarla la próxima vez que se despliegue la función: si
  el movimiento trae `prestamista.linea`, la respuesta es `prestamo` (la base
  pide entonces los intereses). Mientras tanto, si la IA contesta eso, la
  tarjeta lo enseña como suyo («La IA dice…») debajo de la recomendación, que
  es la que vale.
- **(6b) Con qué texto deposita ese prestamista un préstamo a plazo**: no se
  sabe (está en «La segunda pasada»). Si es el mismo que el de los desembolsos
  de la línea, hace falta que elegir un préstamo en la lista valga con un
  porqué escrito.
- **(6b) Lo que el banco escribe de otra forma de un prestamista con algo dado
  de alta** no se puede registrar como dinero de un préstamo desde la Bandeja:
  se avisa, y se arregla desde el SQL Editor (ensanchar el descriptor de la
  línea o del préstamo, o dar de alta lo nuevo). Lo demás (un gasto, un
  ingreso…) frena y pide su porqué, como siempre.
- **Confirmar con el contador** si la empresa presenta el 1120 o el 1120-S.
- **Dar de alta un préstamo** sigue siendo por el SQL Editor
  (`fn_prestamo_guardar`, con su contrato). La Bandeja registra el dinero que
  entra como deuda y el control avisa (70) hasta que se dé de alta; sin eso
  sus cuotas no se reparten entre capital e intereses (esperan en la Bandeja,
  y se dice: aviso 75). El aviso ya dice qué hacer («pídeselo a quien te
  lleva la app»), pero sigue fijo y no se puede esconder: lo que lo quita es
  construir el alta en la pantalla.
- **Una factura de antes del corte que no está en el libro** no se puede
  cobrar desde la Bandeja: la IA la ve en su contexto y contesta «falta» con
  lo que hay que hacer.
- **El export mensual del cierre (c9)** sigue en español. Lo que va al
  contador en inglés es el paquete del año de c18.
- **El paquete completo de la Fase 17** (los doce hashes, las conciliaciones,
  la cédula de activos, el READ ME) no es esto: esto es su primera pieza, la
  balanza con sus líneas.
- **El cierre (c9) no lee todavía** los controles de c17 ni de c18. Lo del
  control de c17 que Edgar tiene que saber ya sale en la Bandeja, y el paquete
  de c18 dice él mismo si algo suyo no cuadra.
- **Los precios del «Dímelo»** siguen copiados de c8 dentro de c17 (sacarlos a
  una función común obliga a volver a pegar c8): si cambia el modelo o cambia
  c8, hay que cambiarlos en los dos sitios.
- **Dentro de «Más opciones» sigue la Bandeja de antes** con su lenguaje: el
  bloque «Según la IA / Según yo» (con los códigos de cuenta y el nombre del
  modelo) y la lista entera de cuentas de «Otra cosa…». Es la misma pieza que
  usa quien no tiene c17, con sus comprobaciones. Desde la cuarta vuelta lo
  que se registra por ahí queda anotado en la Bandeja, y los botones de lo
  que propone el banco van por la capa. Pero esas dos piezas registran por
  las puertas de c8 y de c6, SIN el freno de la Bandeja (solo se anotan
  después): por eso, desde la quinta vuelta, no se pintan en un movimiento
  del que la app sabe de quién es (un prestamista, o Edgar). En los demás
  movimientos siguen ahí, con su lenguaje, y lo que registren no pasa por
  ningún freno de esta capa (los de c6 y c8 sí). Del texto del banco solo se dijo en llano el más frecuente (el
  del cargo sin recibo): los demás salen sin nombres de funciones, pero con
  sus palabras.
- **(Quinta vuelta) Lo que la cuarta revisión encontró y no se tocó**: el
  cheque devuelto contestado por la Bandeja deja el libro bien, pero en
  Proyectos la factura sigue marcada cobrada (pide diseñar cómo se deshace);
  el pago que llega a la tarjeta antes que su cargo del banco pregunta entre
  todas las cuentas propias, también la de paso de Stripe; con un préstamo
  dado de alta, otro cargo que lleve el nombre entero del prestamista (su
  seguro, una comisión) recibe el aviso de «cuota» cada mes y lo que Edgar
  conteste no se recuerda; si la IA propone «un gasto» para la cuota de un
  prestamista, esa propuesta queda pendiente debajo del aviso (cada «Así es»
  frena); y en el teléfono el renglón nuevo de la
  balanza del paquete cae en la primera columna. Y de las pruebas: la base
  simulada de la escena depende del día de la semana en que se captura (el
  Zelle de la cuadrilla), y la comprobación ya vale con las dos respuestas.
- **(Revisión de la quinta vuelta) Lo que quedó como menor**:
  - La cuota de un prestamista sin alta deja su propuesta de la IA de antes
    pendiente y sin pintar; a los 7 días «Qué atender» pide contestarla en
    la Bandeja (alarma 71), donde ya no hay botón para eso.
  - El freno de la IA de antes en la cuota de un prestamista vive en la
    pantalla y cuelga de `sabe`: si la lectura de la Bandeja nueva falla (la
    página lo avisa y vuelve a las tarjetas de antes), si falla el filtro
    previo de prestamistas, o en la tarjeta provisional de un movimiento
    recién llegado, vuelven «Según la IA · ✓ Así es» y «Según yo». Es la
    pantalla de hoy en producción; el candado de verdad iría en la función
    `contador` o en c8.
  - Con un préstamo dado de alta, otro cargo con el nombre entero del
    prestamista pierde también «Según yo» y «Otra cosa… → clasificar».
  - Deshacer un «Anotado por otro monto: corrígelo» solo des-casa el
    depósito: la corrección se queda (el libro cuadra) y el aviso no lo dice.
  - Una factura cobrada en parte en la misma sesión: la opción vieja del
    banco que la cobraba entera se sigue validando (no entra nada al libro,
    pero «Así es» suelta el texto crudo de la puerta).
  - En el pago de la tarjeta, la pregunta «¿Desde cuál de tus cuentas?»
    sigue ofreciendo la cuenta de paso de Stripe, y los botones de «¿Cobro
    que anotaste?» llevan la fecha como la escribe el banco (2026-11-18).
- **La IA de antes sigue proponiendo sola** (su cadena, al abrir la Bandeja,
  si su interruptor está encendido) cargos que la Bandeja nueva ya recomienda
  por el nombre o por lo recordado. La cuarta vuelta solo la dejó discreta y
  debajo de los grupos.
- **El gasto de una llamada a la IA que la función corta por tiempo** (los 60
  o 90 s) no se apunta contra el tope: no hay respuesta con su uso. Apuntar
  una estimación mezclaría gasto real y supuesto en el tope; lo que lo
  arregla es leer la respuesta por partes (streaming), que cambia la llamada
  que comparte la ráfaga de c8 y su simulador.
- **El grupo no tiene caja de «Dímelo»**: se elige de su lista.
- **Un anticipo no suma en «Cobrado» de Proyectos**: Proyectos no lleva
  anticipos, y sumarlo ahí lo contaría dos veces cuando se marque cobrada la
  factura que lo absorba.
- **La propuesta de la IA de antes que Edgar registra por otro camino queda
  «rechazada» en c8**, aunque propusiera lo mismo (su motivo ya lo dice). c8
  no tiene una puerta para cerrar una pendiente como acertada sin registrarla
  ella, y dársela obliga a volver a pegar c8. Su marcador del mes («cuenta N de
  M acertadas») no cambia por esto: solo cuenta lo que entró por su puerta. Lo
  que sube es el total de «rechazadas» de Conexiones.
- **Lo recordado en la Bandeja no da de alta la regla en la IA de antes**: la
  rutina de c8 puede seguir proponiendo (y cobrando) un cargo que la Bandeja
  ya resuelve con lo recordado. Tocarlo obliga a volver a pegar c8.
- **Las tarjetas de la Bandeja de antes** (la mano de obra, un cheque, Stripe,
  la nómina, y todas cuando no está c17) siguen pintando su cuerpo de entrada.
