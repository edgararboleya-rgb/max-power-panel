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

### `docs/conta/c17-bandeja.sql` (marca 2026112101)

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
- **`fn_bandeja_hacer`** es «Así es»: valida y llama a la puerta. Nunca
  inventa un motivo para saltarse un freno del banco: si la puerta pide que
  Edgar escriba por qué, devuelve `pide_motivo` con lo que dijo la puerta.
  Al cobrar una factura la deja cobrada también en Proyectos.
- **`fn_bandeja_recomendar`** da UNA recomendación o ninguna, por este orden:
  un prestamista que el banco nombra (antes que cualquier factura); lo que el
  banco ya reconoce (un traspaso, los intereses, la cuota de un préstamo); lo
  que Edgar ya dijo de esa contraparte; las facturas que explican el depósito
  (primero las marcadas cobradas en Proyectos; de un procesador de tarjetas,
  con su comisión); la propuesta pendiente de la IA (c8); y el nombre del
  comercio. Un gasto de obra propone la obra en la que estuvo la cuadrilla ese
  día, si fue una sola.
- **`fn_bandeja_grupo`** aplica una respuesta a los movimientos de un comercio
  que la pantalla enseñó (o a un lote que el banco ya reconoce). El que algo
  frena se queda, con su porqué.
- **`fn_bandeja_solo`** registra solo lo que cumple todo esto: es un cargo, de
  un comercio, con una regla de Edgar que dice «que entre solo», hasta el tope
  (500 de fábrica), sin otra explicación del banco, sin sospecha de duplicado,
  nunca deshecho, con la obra del día si la cuenta pide obra, y sin que la
  puerta pida un motivo. La pantalla la llama al abrir la Bandeja; pg_cron, dos
  veces al día (`mxp-bandeja-solo-manana` y `mxp-bandeja-solo-tarde`).
- **`fn_bandeja_deshacer`** deshace con su motivo lo que la Bandeja registró:
  el asiento se reversa, el movimiento vuelve a la Bandeja y ya no entra solo.
- **El «Dímelo»**: `fn_bandeja_dimelo_contexto` y `fn_bandeja_dimelo_guardar`
  las llama solo la función de borde (no están en la API). La primera arma lo
  que se le da a la IA, ya tapado por la máscara de c8. La segunda valida lo
  que contestó, anota su gasto contra el tope del contador y lo deja pendiente
  o «sin propuesta». `fn_bandeja_aprobar` y `fn_bandeja_rechazar` son de
  Edgar: aprobar registra lo que la base guardó ya validado, con su frase como
  motivo escrito.
- **`fn_bandeja_leer`**: lo que la pantalla lee de una vez (unos 2 ms por
  movimiento pendiente).
- **`fn_bandeja_control`**: cinco cuadres y cuatro avisos.

### `supabase/functions/contador` — la acción `dimelo`

Una llamada por frase, con el esfuerzo «medium» (la ráfaga de c8 sigue en
«low»). Las instrucciones son fijas y van en la parte que se guarda en caché;
el movimiento, las facturas, lo parecido ya resuelto y la frase van aparte,
como datos. La salida es un JSON con esquema: la acción sale de la lista. La
función no registra nada: guarda lo que la IA contestó y devuelve lo que la
base validó.

### `docs/conta/c18-fiscal.sql` (marca 2026112101)

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
  resumen por línea, el 1125-A y el catálogo, todo en inglés y con sus avisos.
- `fn_fiscal_control`: tres cuadres y dos avisos.

### La pantalla (`js/conta.js`, `css/conta.css`)

- **La tarjeta** dice UNA cosa con su «Así es». Debajo, «¿Qué es? Dímelo con
  tus palabras». Lo de antes (el texto del banco, sus botones, «Según la IA /
  Según yo», «Otra cosa…») queda detrás de «Más opciones», con las categorías
  en dos niveles.
  Después de «Así es», la tarjeta siguiente de la lista queda abierta: se
  contesta una detrás de otra.
- **«Decide por grupo»**, arriba: los comercios con varios movimientos y los
  lotes que el banco ya reconoce.
- **La franja**: «Registrado solo» (con «Deshacer»), «Lo que contestaste estos
  días» (con «Deshacer») y «Lo que recuerdo» (olvidar, que entre solo o no, el
  interruptor general y su tope).
- **Estados**: con c18 los nombres van en inglés (un enlace los pone en
  español para esa sesión) y hay un apartado más, «Para el contador».
- **Sin c17 o sin c18** nada de esto se pinta: la pantalla lo pregunta una vez
  por sesión y sigue como antes.
- La tarjeta de la mano de obra (c10), el cheque que pregunta de quién es, el
  depósito de Stripe y el cargo de Gusto que la nómina reconoce conservan la
  suya.

## Lo que entra solo y lo que nunca

- **Entra solo**: el cargo de un comercio para el que Edgar marcó «que lo
  siguiente entre solo», si es un gasto o algo personal, no pasa del tope y
  nada lo frena.
- **Nunca entra solo** (solo se propone): un depósito, un cobro, un Zelle a
  una persona o de una persona, un cheque, el cajero, la nómina, un traspaso,
  un préstamo, lo que el banco señala como posible duplicado, lo que pasa del
  tope, lo que ya se deshizo una vez, y un gasto de obra el día en que la
  cuadrilla estuvo en dos obras o en ninguna.
- La tabla lo impide (una regla «que entre solo» solo puede ser de un comercio
  y de un gasto o algo personal), `fn_bandeja_hacer` lo vuelve a comprobar y
  el cuadre 20 del control lo vigila.
- La cuadrilla sola (c10) no se tocó: sigue igual.

## La IA propone y no registra

- La función de borde no tiene ninguna llamada que postee. Lo que guarda es
  una propuesta ya validada por la base.
- «Así es» manda a la base solo el id de la propuesta: lo que se registra es
  lo que la base guardó, no algo que viaje de vuelta desde el teléfono.
- El texto del banco y la frase de Edgar van a la IA como datos, tapados por
  la máscara de c8. Si la IA contesta una cuenta que la Bandeja no deja usar,
  una acción fuera de la lista o un cobro que no cuadra, la base lo deja «sin
  propuesta» y dice por qué.

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

## Las pruebas

- `docs/conta/c17-pruebas.sql`: 30 filas.
- `docs/conta/c18-pruebas.sql`: 10 filas.
- `pruebas/conta/bandeja-e2e.mjs`: la función de borde de verdad contra el
  banco de pruebas y el simulador de la IA, 25 comprobaciones (la frase tapada,
  la lista cerrada, la inyección en el texto del banco y en la frase, el tope,
  el esquema).
- `pruebas/conta/pantalla.js`: 85 comprobaciones nuevas, con la base simulada
  sacada del banco (`f19-capturar.js` → `pantalla-f19.json`, semilla
  `f19-semilla.sql`). Solo esa escena: `SOLO=f19 node pruebas/conta/pantalla.js`.

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
- **El cierre (c9) no lee todavía** los controles de c17 ni de c18.
