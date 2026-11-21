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

## Lo construido (21-nov)

El mismo día hubo tres vueltas. La primera construyó las dos capas y la
pantalla. La segunda (marca `2026112102`) arregló lo que encontró una revisión
de tres lentes (el dinero y el libro, la IA y la seguridad, la pantalla y
Edgar): está contado al final, en «La segunda vuelta». La tercera (marca
`2026112103`) arregló lo que encontró la segunda revisión, sobre todo que con
la Bandeja llena la lectura no cabía en el corte de la API: «La tercera
vuelta».

### `docs/conta/c17-bandeja.sql` (marca 2026112103)

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
  estuvo la cuadrilla ese día, si fue una sola.
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
  deshecho, y sin que la puerta, hoy, lo frene. Antes de eso arregla lo que
  ya está dos veces (`fn_bandeja_recibos`, abajo). La pantalla la llama al
  abrir la Bandeja; pg_cron, dos veces al día (`mxp-bandeja-solo-manana` y
  `mxp-bandeja-solo-tarde`).
- **`fn_bandeja_recibos`**: el recibo que llega DESPUÉS de registrar su cargo
  deja el gasto dos veces. Si es uno solo, del mismo monto y sin otro cargo
  que pueda ser el suyo, cambia lo registrado por el recibo por la puerta del
  banco (el gasto queda una vez, en la obra del recibo). Si no, lo deja a la
  vista para que Edgar diga «es su recibo» o «es otra compra».
- **`fn_bandeja_deshacer`** deshace con su motivo lo que la Bandeja registró:
  el asiento se reversa, el movimiento vuelve a la Bandeja y ya no entra solo;
  si registró un cobro, lo anula y deja Proyectos como estaba.
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
  las tarjetas, los grupos de cargos (con la
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

### `docs/conta/c18-fiscal.sql` (marca 2026112103)

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
  (`in_books` en falso).
- `fn_fiscal_control`: cuatro cuadres y dos avisos.

### La pantalla (`js/conta.js`, `css/conta.css`)

- **La tarjeta** dice UNA cosa con su «Así es». Debajo, «¿Qué es? Dímelo con
  tus palabras». Lo de antes (el texto del banco, sus botones, «Según la IA /
  Según yo», «Otra cosa…») queda detrás de «Más opciones», con las categorías
  en dos niveles.
  Después de «Así es», la tarjeta siguiente de la lista queda abierta: se
  contesta una detrás de otra. (Tercera vuelta) El cuerpo de una tarjeta se
  pinta al abrirla, y la Bandeja no se relee ni se repinta después de cada
  respuesta: sale la tarjeta contestada y, por detrás, se leen las tarjetas de
  ese comercio y lo demás. Lo que la base todavía no ha recomendado dice
  «Mirándolo…» y llega solo.
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
  juntos a la vista, sin una respuesta para todos.
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
- **Estados**: con c18 los nombres van en inglés (un enlace los pone en
  español para esa sesión) y hay un apartado más, «Para el contador», que pasa
  el control de los estados como las demás pestañas y dice arriba, en español,
  si el año es parcial o si la app no lo lleva.
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
  tarjeta ni de identificación fiscal: la máscara los tapa.

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
  día»; lo de una obra no ofrece «entra solo» en «Lo que recuerdo»; la nota
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

## Las pruebas

- `docs/conta/c17-pruebas.sql`: 68 filas (sobre la base limpia, con la semilla
  f19 y con cuatrocientos pendientes).
- `docs/conta/c18-pruebas.sql`: 13 filas.
- `pruebas/conta/c17-volumen.sh`: la Bandeja con 400 y con 1,000 pendientes,
  como el dueño por la API, cada llamada por debajo de 0.8 s.
- `pruebas/conta/bandeja-e2e.mjs`: la función de borde de verdad contra el
  banco de pruebas y el simulador de la IA, 38 comprobaciones (la frase tapada,
  la lista cerrada, la inyección en la frase y en la descripción del banco con
  una acción válida —queda como propuesta: ni en el libro ni en la memoria sin
  el toque de Edgar—, el freno por un recibo ya subido, la opción que cambia,
  el tope, el esquema; y, tercera vuelta, el prestamista dicho a la IA, la
  máscara con saltos de línea, el carácter nulo, los enlaces y la frase como
  sugerencia del porqué).
- `pruebas/conta/pantalla.js`: 185 comprobaciones de esta escena, con la base
  simulada sacada del banco (`f19-capturar.js` → `pantalla-f19.json`, semilla
  `f19-semilla.sql`; las lecturas por partes, con `f19-parte.js`, que el
  capturador comprueba contra la base). Solo esa escena:
  `SOLO=f19 node pruebas/conta/pantalla.js`.

## Lo que queda pendiente

- **Confirmar con el contador** si la empresa presenta el 1120 o el 1120-S.
- **Dar de alta un préstamo** sigue siendo por el SQL Editor
  (`fn_prestamo_guardar`, con su contrato). La Bandeja registra el dinero que
  entra como deuda y el control avisa (70) hasta que se dé de alta; sin eso
  sus cuotas no se reparten entre capital e intereses.
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
  usa quien no tiene c17, con sus comprobaciones; la tercera vuelta solo quitó
  los códigos de los botones de lo que propone el banco. La tarjeta nueva ya
  dice arriba, en llano, lo que propone la IA de antes.
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
