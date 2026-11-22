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

No se toca nada de lo que ya contestaste. **No hay que volver a pegar c6 ni
c18, ni desplegar la función `contador`, ni publicar la app**: solo cambia
`c17-bandeja.sql`.

Hazlo en este orden. Cada cosa se pega entera en el SQL Editor de Supabase y
se le da a «Run». Todo se puede pegar dos veces.

| # | Qué | Filas que salen |
|---|---|---|
| 1 | `docs/conta/c17-bandeja.sql` | **8**, todas empiezan por «ok:» |
| 2 | `docs/conta/c17-pruebas.sql` | **83**, todas en `true` (u «omitida» con su porqué) |
| 3 | El SQL de tu línea de crédito (**te lo paso por el chat**: nombra cosas tuyas y no va en el repositorio) | **7**, todas empiezan por «ok:» |

**Hasta pegar el paso 3, no contestes las tarjetas de ese prestamista** (el
pago de la línea y sus desembolsos): todavía dicen lo de antes.

### 1. `c17-bandeja.sql`: lo que tiene que decir

Lo mismo que el 22-nov, con dos cambios:

- **`version`:** «ok: 2026112203».
- **`funciones`:** «ok: 59 funciones fn_bandeja_*, ninguna SECURITY DEFINER».

La fila **`siguiente`** sigue diciendo «vuelve a desplegar la función
«contador» y publica la app»: es la de siempre. **Esta vez no hace falta
ninguna de las dos cosas.**

### 2. `c17-pruebas.sql`

Salen 83 filas; la última columna tiene que ser `true` en todas. Las nuevas
son la 82 (la línea de crédito, de punta a punta) y la 83 (la pregunta con
botones iguales). Como siempre, montan lo suyo («BDIECISIETE…», un
prestamista inventado que se llama «Zzlend») y lo deshacen: no queda nada (lo
comprueba la fila 81). Si el SQL Editor deja de esperar:

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
empieza por «NO se aplicó, no se tocó nada»: cópiamelo tal cual. Las 7 filas
dicen qué hizo y cuántas tarjetas esperan de cada clase (cuotas del préstamo,
pagos de la línea, desembolsos de la línea). Si alguna fila empieza por
«OJO:», cópiamela y no contestes esas tarjetas.

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
  de …: $…. Dime cuánto de este pago fueron intereses…», con una casilla
  («Interés, según el statement»). Pones lo que diga el prestamista de ese
  pago (en su página, cada pago trae cuánto fue a la deuda y cuánto de
  intereses) y tocas «Así es». Lo demás baja lo que debes. **Si ese pago no
  tuvo intereses, pon 0.** Sin ese número no se registra.
- **Si te equivocas con los intereses**: «Lo que contestaste estos días» →
  «Deshacer», y la tarjeta vuelve con la misma pregunta.
- **Un pago a un préstamo que no es su cuota de siempre** (la cuota y algo
  más): ya no pregunta «¿De cuál es?» con dos botones iguales. Dice «su cuota
  de $… y $… más. ¿Cómo lo registro?» y los botones dicen cada uno lo suyo:
  «La cuota y $… más a la deuda» o «Con lo que dice su estado de cuenta».

## Cómo saber que quedó bien

Después de contestar las tarjetas de la línea, **«Línea de crédito» en el
libro tiene que decir lo mismo que el prestamista dice que debes de la línea**
(el saldo, sin intereses por venir). Si no coincide, dime los dos números:
lo más probable es un pago con los intereses mal puestos, o que la línea ya
debía algo antes del 1 de octubre (eso estaría en QuickBooks, y se arregla en
la apertura, no en la Bandeja).

## Si algo sale mal

- **Un rojo en `control`**, una fila en `false` o un «OJO:»: cópiamelo. No
  toques nada más.
- **Una tarjeta de ese prestamista que diga otra cosa** («Parece la cuota de
  un préstamo de … que todavía no está dado de alta», «…el banco lo escribe
  distinto de como quedó apuntado»): el banco escribió ese movimiento de una
  forma nueva. No la contestes; dímelo.
