# Lo que hay que pegar (23-nov)

## La línea de crédito, aparte del préstamo

El 22-nov estrenaste la Bandeja nueva. Dos cosas salieron ese día:

1. **La app tomaba por «el préstamo» todo lo que el banco escribe de ese
   prestamista**: también el pago de la línea de crédito (lo proponía como la
   cuota del préstamo «más un abono a capital», con dos botones iguales) y
   los desembolsos de la línea (los proponía como dinero de ese préstamo, a su
   cuenta). Una línea de crédito no es un préstamo a plazo: no tiene cuota
   fija, se saca y se devuelve.
2. **Siete de las 81 pruebas salieron en `false`.** No era un fallo de la
   Bandeja: las pruebas daban por hecho una base sin préstamos. Seis usaban
   como «prestamista sin dar de alta» uno que tú sí tienes dado de alta, y la
   otra esperaba el capital de una cuota en la cuenta donde cae cuando el
   libro no tiene ningún préstamo. Ya usan un prestamista inventado y no
   dependen de lo que tu libro tenga.

Antes de dártelo se revisó otra vez, y de esa revisión salieron unos retoques
que ya van dentro (están abajo, en «Lo que vas a ver»). El 27-nov entró uno
más: un monto escrito con un espacio dentro, como «6 50», ya no se toma por
650. Por eso la marca de abajo es la `2026112204` y las pruebas son 86.

No se toca nada de lo que ya contestaste. **No hay que volver a pegar c6 ni
c18, ni desplegar la función `contador`.** Cambian `c17-bandeja.sql` y la
pantalla: **la app la publico yo** (se actualiza sola al abrirla).

Hazlo en este orden. Cada cosa se pega entera en el SQL Editor de Supabase y
se le da a «Run». Todo se puede pegar dos veces.

| # | Qué | Filas que salen |
|---|---|---|
| 1 | `docs/conta/c17-bandeja.sql` | **8**, todas empiezan por «ok:» |
| 2 | `docs/conta/c17-pruebas.sql` | **86**, todas en `true` (u «omitida» con su porqué) |
| 3 | El SQL de tu línea de crédito (**te lo paso por el chat**: nombra cosas tuyas y no va en el repositorio) | **7**, todas empiezan por «ok:» |

**Hasta pegar el paso 3 y hasta que yo te diga que la app ya está publicada,
no contestes las tarjetas de ese prestamista** (el pago de la línea y sus
desembolsos): todavía dicen lo de antes.

### 1. `c17-bandeja.sql`: lo que tiene que decir

Lo mismo que el 22-nov, con dos cambios:

- **`version`:** «ok: 2026112204».
- **`funciones`:** «ok: 60 funciones fn_bandeja_*, ninguna SECURITY DEFINER».

La fila **`siguiente`** sigue diciendo «vuelve a desplegar la función
«contador» y publica la app»: es la de siempre. **Esta vez la función no hay
que desplegarla, y la app la publico yo.**

### 2. `c17-pruebas.sql`

Salen 86 filas; la última columna tiene que ser `true` en todas. Las nuevas
son la 82 (la línea de crédito, de punta a punta), la 83 (la pregunta con
botones iguales), la 84 (los retoques de la línea), la 85 (el pago
registrado «con lo que dice su estado de cuenta») y la 86 (un monto escrito
con un espacio dentro). Como siempre, montan lo suyo («BDIECISIETE…», un
prestamista inventado que se llama «Zzlend») y lo deshacen: no queda nada
(lo comprueba la fila 81). Si el SQL Editor deja de esperar:

```sql
select * from pruebas.c17_resultado order by n;
```

### 3. El SQL de tu línea de crédito

Hace tres cosas, y **no registra nada en el libro**:

1. El préstamo a plazo deja de reconocer «todo lo de ese prestamista»: desde
   ahora, solo sus cuotas (por cómo las escribe el banco). Lo demás del
   préstamo no cambia.
2. Da de alta la línea de crédito en la Bandeja, con su cuenta («Línea de
   crédito») y con cómo escribe el banco su pago y sus desembolsos.
3. Le pide a la app que mire otra vez los movimientos de ese prestamista que
   esperan, para que sus tarjetas se pongan al día en el momento.

Si algo no está como se espera, **para sin tocar nada** y sale un error que
empieza por «NO se aplicó, no se tocó nada»: cópiamelo tal cual. Para, por
ejemplo, si el pago de la línea o alguno de sus desembolsos ya se contestó de
otra forma (como dinero o como la cuota del préstamo, o como un gasto): eso
se deshace antes en la Bandeja («Lo que contestaste estos días» → «Deshacer»)
y se pega otra vez. Las 7 filas dicen qué hizo y cuántas tarjetas esperan de
cada clase (cuotas del préstamo, pagos de la línea, desembolsos de la línea).
Si alguna fila empieza por «OJO:», cópiamela y no contestes esas tarjetas.

## Lo que vas a ver en la Bandeja

- **La cuota del préstamo** (la de siempre): «Es la cuota de …: $… ($… bajan
  la deuda y $… son intereses)». «Así es», como hasta ahora. La reparte la
  app con la tabla del préstamo.
- **Un desembolso de la línea** (dinero que entra): «Es dinero de tu línea de
  crédito de …: $…. Sube lo que debes en la línea; no es el pago de un
  cliente.» «Así es». Si en ese momento tienes facturas por cobrar más
  grandes que ese depósito, la app frena una vez («…el banco frena por si
  este depósito fuera el pago de una. Pero él mismo lo escribe como lo de tu
  línea de crédito…»), con la respuesta ya escrita debajo: tocas «Así es»
  otra vez y entra.
- **Un pago de la línea** (dinero que sale): «Es un pago a tu línea de crédito
  de …: $…. Pon abajo cuánto de este pago fueron intereses…», con una casilla
  («Interés, según el statement»). Pones lo que diga el prestamista de ese
  pago (en su página, cada pago trae cuánto fue a la deuda y cuánto de
  intereses) y tocas «Así es». Lo demás baja lo que debes. **Si ese pago no
  tuvo intereses, pon 0.** Sin ese número no se registra.
- **Los centavos, con punto.** En esa casilla escribe «61.37», no «61,37». Si
  pones coma, la app no lo toma y te lo dice («Escribe los centavos con punto,
  como 61.37»). «1,000.00» y «$61.37» sí valen.
- **Y sin espacios dentro del número.** Si se cuela un espacio en medio
  («6 50»), la app no lo toma por 650: no lo registra y te lo dice («Eso no
  es un monto: escríbelo con números, como 61.37»). Un espacio delante o
  detrás, o entre el «$» y el número, no molesta.
- **Cada pago de la línea se contesta por separado**, aunque haya varios
  esperando: cada uno lleva sus intereses. No salen juntos en «Decide por
  grupo», y su tarjeta no trae la casilla «Recordarlo» (la app ya los
  reconoce sola).
- **Los desembolsos de la línea sí se ven juntos** en «Decide por grupo»
  (por ejemplo «… · 2 depósitos · se contestan de uno en uno»). La frase de
  ese bloque habla de facturas porque es la de cualquier depósito repetido;
  no le hagas caso: cada renglón dice «Es dinero de tu línea de crédito…» y
  se contesta uno a uno con «Así es».
- **Si lo dices con tus palabras** («es el pago de la línea»), lo que la app
  entiende trae la misma casilla de los intereses: se ponen ahí y «Así es».
  Si en vez de eso te contesta que «ese préstamo hay que darlo de alta», no
  le hagas caso: la línea ya está dada de alta; contéstalo arriba, en la
  tarjeta, con su casilla.
- **Si te equivocas con los intereses**: «Lo que contestaste estos días» →
  «Deshacer», y la tarjeta vuelve con la misma pregunta.
- **Un pago a un préstamo que no es su cuota de siempre** (la cuota y algo
  más): ya no pregunta «¿De cuál es?» con dos botones iguales. Dice «su cuota
  de $… y $… más. ¿Cómo lo registro?» y los botones dicen cada uno lo suyo:
  «La cuota y $… más a la deuda» o «Con lo que dice su estado de cuenta». Con
  este último pones tú cuánto bajó la deuda y cuánto fueron intereses, y lo
  que queda escrito dice justo eso («Es un pago a …: $… ($… bajan la deuda y
  $… son intereses, según su estado de cuenta)»).

## Cómo saber que quedó bien

Después de contestar las tarjetas de la línea, **«Línea de crédito» en el
libro tiene que decir lo mismo que el prestamista dice que debes de la línea**
(el saldo, sin intereses por venir). Si no coincide, dime los dos números:
lo más probable es un pago con los intereses mal puestos, o que la línea ya
debía algo antes del 1 de octubre (eso estaría en QuickBooks, y se arregla en
la apertura, no en la Bandeja).

## Una cosa que necesito que me digas

Cuando te depositaron el dinero del préstamo a plazo, **¿con qué nombre salió
en el banco?** Lo dice el estado de cuenta del banco de ese mes, en el
depósito. Hoy la app toma por «dinero de la línea» todo lo que ese prestamista
deposita con el nombre que usa para los desembolsos de la línea. Si el dinero
del préstamo llegó con ese mismo nombre, el día que te den otro préstamo (o
te lo renueven) la app lo propondría como dinero de la línea, y habría que
arreglarlo antes. No hay nada que hacer hoy: solo dímelo.

## Si algo sale mal

- **Un rojo en `control`**, una fila en `false` o un «OJO:»: cópiamelo. No
  toques nada más.
- **Cualquier error en rojo al pegar** (empiece o no por «PEGAR-ondeck NO se
  aplicó»): cópiamelo tal cual. Ese pegado es de una pieza: si sale un error,
  no se cambió nada.
- **Una tarjeta de ese prestamista que diga «… tiene un préstamo y una línea
  de crédito dados de alta y el banco escribe este depósito (o este cargo) de
  otra forma: no lo contestes y avisa a quien te lleva la app»**: el banco
  escribió ese movimiento de una forma nueva, y la app no sabe si es del
  préstamo o de la línea. No trae «Así es», y tampoco se deja registrar como
  dinero de un préstamo eligiéndolo en la lista. No la contestes de ninguna
  otra forma; dímelo y lo dejo reconocido.
- **Cualquier otra tarjeta de ese prestamista que no diga lo de arriba**:
  tampoco la contestes; dímelo.
