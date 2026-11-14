# Fase 11 · El puente de nómina
**30 nov – 6 dic · 🔵 AZUL el asiento real de la corrida · 🟢 VERDE la plomería · ▶ CONTRATADO YA (trámite desde la semana 5)**

> ⚠️ **El trámite arrancó en la semana 5** (ver f06). Última nómina en el
> proveedor viejo con **fecha de pago ≤ 31-dic**; primera en Gusto con **fecha
> de pago ≥ 4-ene** (el 1 de enero es viernes festivo y no corre ACH). Los W-2
> y el 941 del Q4 de 2026 los emite quien llevó la nómina en 2026: **no cortar
> ese acceso hasta tenerlos.**

## Tú
1. **Gusto contratado**, llaves y el **export del diario de nómina (CSV)**.
2. Resumen o empleado por empleado.
3. Aprobar las horas del período desde la app: **el lote aprobado es el que va
   a Gusto y al libro**.

## Lo que la app NO hace, y no se discute
No calcula retenciones, no deposita en EFTPS, no presenta 941, 940, W-2 ni
RT-6. Eso lo hace el proveedor. Si retienes y no depositas a tiempo existe la
Trust Fund Recovery Penalty, que atraviesa la corporación y te la cobran a ti
personalmente. Ningún ahorro de software vale eso.

## 🔵 Azul — se crea (`/effort max`)
El modelo de la corrida —`nomina_corridas`, `nomina_reparto`— y **el asiento
real**: Dr 5000 bruto por obra según horas aprobadas del período (el reparto se
diseñó en f09), Dr 5010 impuestos patronales **reales del journal**
prorrateados por horas, Cr 2220/2230/1010 (y 2215 si se devenga PTO). La prima
de WC: Dr 1410 al pagar, amortización mensual Dr 5010 / Cr 1410, ajuste de
auditoría anual a 5010. **GL solo en 6200.** Nunca una lectura de `escenarios`.

**Este journal es la ÚNICA fuente de dólares de 5000/5010**; el devengo de
horas de f03, si existe, ya se reversó el día 1.

## 🟢 Verde — se trabaja encima (`/effort auto`)
La plomería: lector del export del diario del proveedor, igual que el
importador de banco (**la API es opcional: el archivo nunca falla**); el
reparto por horas aprobadas; el cierre de la variación de burden a 5019 en f08;
corrida de prueba con las llaves demo.

## Entregable
`docs/conta/c15-nomina.sql` + `docs/conta/c15-pruebas.sql` (el nombre
`c11` ya lo usaba la facturación) · la página «Nómina» de Contabilidad · el
cierre (c9) con las filas 180 a 183 · `pruebas/conta/c15-concurrencia.sh` y
los archivos de muestra de `pruebas/conta/nomina/` (todo «ZZ…», de mentira).

## Terminó cuando
Una corrida de prueba entra sola al libro desde el diario, repartida sobre las
obras correctas con su burden real, y **el journal, el 941 y el RT-6 amarran
contra 5000/5010/2220/2230**.

## Decisión del 26-oct
Gusto contratado (plan Simple, cada dos semanas, primera nómina el viernes
8-ene-2027). Gusto no da su API a una app privada de un solo cliente: el
puente de esta fase es **por archivo** (el «Payroll journal» en CSV que Edgar
descarga después de cada nómina y sube a la app), con las horas por obra que
ya lleva la app para repartir el costo y Plaid para casar el cargo de Gusto en
Chase. En primavera de 2027, con la nómina estable, se pide a Gusto el acceso
de socio para que el asiento entre solo; correr la nómina dentro de la app
(Check u otro proveedor embebido) queda descartado para el arranque.

## Lo que cambió al construirla (manda sobre lo de arriba)
- **Las cuentas del asiento.** Cr 2210 (el neto), 2220 (lo retenido y lo del
  patrón para el 941), 2225 (el FUTA, 940), 2230 (el reempleo de Florida,
  RT-6) y 2240 (las deducciones); 2250 los reembolsos. **No hay «Cr 1010» el
  día de pago**: Gusto saca el dinero antes y en varios cargos (NET, TAX, REM,
  CSD; la cuota mensual, FEE, aparte), y cada cargo se casa después con lo que
  su nómina dejó por pagar.
- **5010 nunca directo del journal ni de 1410** (lo manda c1/c3): los
  impuestos patronales y la prima de WC van a la bolsa 5015, y la bolsa se
  reparte a las obras (5010 por obra) por las horas que la nómina pagó. La
  prima de WC sigue entrando por los prepagados del banco (c6), no a mano.
- **El amarre** con 941, 940 y RT-6 es por los créditos a 2220, 2225 y 2230,
  por día de pago, con tolerancia de centavos: esas declaraciones cuentan a
  todos los empleados (5000, 5001, 6000, 6005), no solo a la obra.
- **El formato del CSV de Gusto no está comprobado con un archivo real.** El
  lector va por nombre de columna con un mapeo que Edgar amplía desde la
  pantalla; una columna con cifras que no conoce frena la nómina en vez de
  perderse. Se confirma con el primer archivo (enero de 2027).
- La frase de arriba sobre los W-2 y el 941 del Q4 de 2026 no aplica (lo dice
  CONTA-PLAN): en 2026 no hubo nómina con proveedor.

## Lo construido (13-nov)
- **c15-nomina.sql** (15 tablas, 7 vistas, 63 funciones `fn_nomina_*`; se
  pega dos veces sin daño; sale una tabla de 9 filas):
  - **El archivo.** La pantalla lee el CSV en el teléfono y manda solo las
    celdas como texto; lo delicado (SSN, banco, dirección, teléfono, correo,
    nacimiento) se quita antes de salir y la base lo vuelve a quitar. El
    archivo no se guarda: solo su nombre, su sha256 y su tamaño. Antes de
    guardar hay un ensayo que dice qué entendió.
  - **Cuadra al centavo o no se postea**: por persona (bruto − retenido −
    deducciones = neto; neto + reembolsos = cheque) y contra la fila de
    totales, que es control y nunca se suma.
  - **No entra dos veces**: por su llave de Gusto o, sin ella, por sus
    personas y sus cifras (la misma nómina bajada de otra forma, sin fechas
    o con otro día). Dos nóminas iguales de verdad entran solo con su porqué
    escrito.
  - **El asiento** en el día de pago (la fecha fiscal), el sueldo de cada
    persona repartido por obra según sus horas aprobadas del período (campo
    5000, oficial 5001 en obra y 6005 lo demás, oficina 6000); un bono o una
    corrección no se quedan con las horas.
  - **Los cargos de Gusto** del banco se casan con lo que la nómina dejó por
    pagar (también lo que quedó a favor tras una corrección, y lo pagado por
    fuera de Gusto con su nota). Des-casar en la Bandeja se refleja aquí.
  - **La bolsa del burden** se reparte al terminar el mes a las obras, por las
    horas que la nómina pagó ese mes.
  - **El amarre** 941 / 940 / RT-6 por trimestre, con lo que Edgar teclea de
    lo que presentó Gusto.
  - **Las horas para Gusto**: el lote aprobado en CSV, con las extra por
    semana laboral (más de 40, cada semana sola).
  - **Seguridad**: solo el dueño; lo de cada persona (corridas, pagos,
    personas) solo con el código del teléfono. Sin el código la página dice
    «entra con tu código», no «no hay nóminas». El cierre y su ronda al
    teléfono no llevan nombres ni sueldos.
- **c15-pruebas.sql**: 52 pruebas (la 35 sale «omitida» si c9 no trae el
  bloque). No dejan nada. Con una nómina de muestra «ZZ…» viva, casi todas
  salen «omitida» y lo dicen: no se suben los archivos de muestra a
  producción.
- **El cierre (c9)**: filas 180 (cada cargo de Gusto del mes casado; detiene),
  181 (cada nómina con día de pago en el mes, posteada; detiene), 182 (sus
  cuadres; detiene) y 183 (sus avisos; avisa).
- **La página «Nómina»**: Nóminas, Cargos de Gusto, Personas, Horas para
  Gusto, 941 · 940 · RT-6 y Ajustes (el mapeo de columnas, la cuenta de las
  horas sin obra, la semana laboral y la bolsa del burden).
- **Cómo se probó** (en el banco de pruebas, nunca en producción): Fable en la
  base, en la revisión contra el dinero y la seguridad, sus arreglos y la
  revisión final; Opus 5.5 en la pantalla y en la verificación desde cero.
  Encontraron y quedó arreglado, entre otras cosas: un archivo con el resumen
  y el detalle con la misma cabecera que se sumaba dos veces; el mismo
  archivo sin fechas subido con otro día que entraba como otra nómina; un
  cargo des-casado en la Bandeja que dejaba su pago «aplicado»; lo de cada
  persona visible sin el código; nombres y sueldos en la ronda del cierre;
  la prima de WC que se quedaba en la bolsa. Todas las suites (c2 a c15) en
  verde desde cero y sobre la plantilla, dos veces; la concurrencia (10
  escenas) en verde; con una nómina de verdad dentro, c15 52 de 52.

## La Fase 11b (13-nov, hecha)
Las capas selladas ya conocen la nómina. Las costuras, la segunda revisión de
c15 contra el dinero y la seguridad, los arreglos y la revisión final fueron
en Fable 5.2; la pantalla y la verificación desde cero, en Opus 5.5. Todo en
verde en los tres órdenes de pegado (sin c15, el de producción y desde cero),
con una nómina de verdad dentro (también anulada y vuelta a postear) y en la
lista única desde el estado del 12-nov (`docs/conta/PEGAR-13NOV.md`).
- **c3 · el devengo** (marca 2026111301): un mes con nómina devenga solo las
  horas aprobadas que ninguna nómina pagó; al postear o anular una nómina el
  devengo del mes se pone al día solo. Su control ya no se cuelga con meses
  grandes (de 38 s a 0.1 s). Pruebas 121 a 126; `c3-nomina.sh`.
- **c6 · los papeles y los textos** (marca 2026111301; c4 no cambia): la vista
  de los papeles lee el papel de la nómina por `fn_banco_papel_nomina()`
  (sin el código del teléfono, un texto sin cifras); el débito de Gusto «se
  casa desde Contabilidad → Nómina → Cargos de Gusto»; la devolución de Gusto
  sale con el motivo «nomina». Pruebas 164 a 167; `c6-nomina.sh`.
- **c10 · Costo por obra** (v3) **y c12 · WIP**: la hora que pagó una nómina
  es «con pago real» (lee la marca sin dinero `fn_nomina_horas_con_pago()`):
  ya no va además a estándar. **Ya se puede fijar el burden estándar.**
- **c13 · la cédula**: 2210 a 2240 leen el auxiliar de la nómina; sin el
  código del teléfono dicen «con el código», nunca un rojo falso.
- **c15 · los arreglos de su segunda revisión** (66 funciones, 66 pruebas):
  - la misma nómina por partes (un journal «por empleado») ya no entra dos
    veces;
  - la bolsa del burden no se reparte dos veces;
  - «Total employer contributions» se ignora de fábrica y, sin las columnas
    de lo patronal, la nómina no cuadra;
  - el freno «resumen» (dos nóminas sumadas en un archivo);
  - el traspaso al casar un cargo que dejaría una cuenta al revés;
  - la cuota de Gusto con su guarda;
  - la devolución de Gusto por palabra entera, como en c6 (un Zelle de un
    «Augusto» ya no cuenta).
- **La pantalla**: Costo por obra dice «en Nómina» y lista las nóminas que
  pagaron horas de la obra; Personas, «cobra por nómina»; la cédula, «con el
  código»; el papel de un asiento de nómina, desde c6; la 2250 con nombre solo
  con el código; «Importar» apagado si ya está todo.

### ▶ Lo que quedó abierto de la 11b
(Las dos primeras se cerraron el 14-nov: «La Fase 11c», abajo.)
- **El corte de los Zelle en c3**: c3 no aparta del devengo las horas que un
  jornal pagó dentro del mes. Con un mes devengado, aplicar un Zelle de ese
  mes pone en rojo el «devengo» de c3. Hoy la salida es reversar el devengo
  de ese mes. ▶ CPA y una vuelta más con Fable.
- **El débito de Gusto dentro de otra palabra**: en los DÉBITOS, «GUSTO»
  casa dentro de «AUGUSTO»: un Zelle a alguien con ese nombre saldría como
  cargo de nómina y pondría en rojo la fila 180 hasta clasificarlo a mano. Es
  así desde octubre, en la regla R6 de c6. Se arregla con palabra entera
  (como ya hacen los depósitos), con su prueba en c6 y c15, en una vuelta con
  Fable.
- **c10 y c12 dan por pagadas las horas en cuanto se postea la nómina**, sin
  mirar la fecha de su journal (en c15 sí se corta al fin de mes). ▶ CPA.
- La pantalla suma dinero en JavaScript en dos sitios (el subtítulo de Costo
  por obra y el total de la Bandeja): pide un total de c10 y otro de c6.
- Sin comprobación en `pantalla.js` (no hay escena en la base simulada): la
  columna sin cuenta en el ensayo, el botón del freno «resumen», la cuota con
  su nota, el texto del traspaso y los de devengo y bolsa al anular.
- El traspaso está probado con un cargo; falta un depósito de Gusto que
  mezcle cuentas a favor y por pagar.
- La IA contable (c8) no sabe de la nómina: aprobar su propuesta para un
  cargo de Gusto se salta la página de Nómina (el aviso 62 de c15 lo dice).
- `c6-banco-parte1.sql` quedó a 3,805 bytes del tope del partidor: el
  próximo cambio en las secciones 0 a 4 de c6 puede mover el corte. (Tras la
  11c: a 2,115 bytes; el corte sigue en la sección 5.)

## La Fase 11c (14-nov)
Cierra lo que la 11b dejó abierto de los Zelle y de «GUSTO», y lleva la
nómina a la portada. Probada en los tres órdenes de pegado (sin c15, el de
producción sobre la v305 y desde cero) y en la lista única desde el estado
del 12-nov (`docs/conta/PEGAR-13NOV.md`, con el camino de quien ya pegó la
v305).
- **c3 · el devengo** (marca 2026111402; 139 pruebas): el devengo estándar
  aparta también las horas que pagó un jornal dentro del mes y se pone al
  día solo. Aplicar un Zelle de un mes devengado ya no deja el «devengo» en
  rojo. No toca ningún asiento. **Segunda vuelta (el mismo 14-nov; la marca
  pasa de …401 a …402):** el devengo que el puente deshizo y que vuelve a
  tener horas aprobadas y sin pagar ya no queda callado (abajo, en «Lo que
  queda», su punto ya hecho). Solo cambia c3: se pega encima de la v306 sin
  volver a pegar nada más (probado).
- **c6 · «GUSTO» como palabra entera** (marca 2026111401; 169 pruebas): un
  solo sitio dice si un movimiento nombra la nómina,
  `fn_banco_dice_nomina(descripción, memo)`, para los débitos y los
  depósitos: «GUSTO», no «AUGUSTO». El patrón de fábrica gana ZENPAYROLL (si
  Edgar lo había ajustado, no se toca y el pegado lo dice). **Un Zelle nunca
  es de nómina**, diga lo que diga su nota («con gusto, gracias», «payroll
  semana 3»): lo escribe una persona, y Gusto no paga por Zelle. Sale como
  un Zelle a una persona y, si es un jornal, entra por Costo por obra sin
  motivo.
- **c10 · Costo por obra** (v4: dos textos; 64 pruebas): sus avisos dicen lo
  que hace el c3 nuevo. Va con c3.
- **c15 · la nómina** (68 funciones, 70 pruebas; pide el c6 del 14-nov): sus
  cinco puertas de los cargos de Gusto preguntan al banco
  (`fn_banco_dice_nomina`), así que el banco y la nómina dicen lo mismo de
  cada movimiento. Dos lecturas ligeras para la portada:
  `fn_nomina_cargos_esperan()` (los movimientos de Gusto que esperan, sin
  armar su propuesta) y `fn_nomina_control_filas(solo cuadres)`.
- **c16 · la nómina en el tablero** (marca 2026111403; 65 pruebas): en
  `fases/tablero-c16.md`.
- **c9** no cambia.

### ▶ Lo que queda de la 11c
- **Decide Edgar:** qué enseña la portada de la nómina sin el código del
  teléfono. De fábrica, «libro» (lo que Estados ya enseña sin el código).
  Con «codigo», sin el código no se escribe ningún dinero de la nómina y la
  tarjeta de gastos esconde ENTERAS las cuentas de la nómina (también lo
  que tengan que no sea de Gusto). Se cambia en
  `fn_tablero_nomina_criterio()` y se vuelve a pegar c16.
- La palabra «gusto» o «payroll», entera, en la descripción o en la nota de
  un movimiento que NO es un Zelle sigue saliendo «de nómina»: un cheque
  con «payroll» en su nota, un ACH a una persona, o una compra con la
  tarjeta o la débito en un comercio que se llame «… Gusto …» («El Buen
  Gusto», «Al Gusto») cuyo ticket no esté en el libro (con su ticket, casa
  con él antes). Ya pasaba en la v305. Sale en Nómina → Cargos de Gusto y
  lo cuenta la fila 180 del cierre hasta que se resuelve. La salida:
  clasificarlo en la Bandeja con su motivo escrito (probado: sale de los
  cargos de Gusto). Gusto nunca cobra a una tarjeta de crédito: si
  molesta, se puede dejar fuera la cuenta de tarjeta, pero cambia la firma
  de `fn_banco_dice_nomina` (c6 y c15 a la vez).
- **HECHO (14-nov, segunda vuelta; c3, marca 2026111402): el devengo y una
  nómina ANULADA, o unas horas aprobadas después.** Si el puente deshizo el
  devengo de un mes y ese mes vuelve a tener horas aprobadas y sin pagar,
  ahora lo dice el control «devengo» de c3 (y con él la fila «puentes:
  devengo» del cierre, la 131 si es el único en rojo) y el mes no se cierra
  (MX008). Lo resuelve `select fn_horas_devengar('AAAA-MM');`. El mes que
  Edgar nunca devengó no sale. La red va solo en c3 (c15 no cambia; el
  porqué, en la cabecera de `c3-puentes.sql`). Pruebas 137 a 139 de c3.
  La revisión independiente (Fable) no encontró ningún hueco ni rojo falso
  en el control ni en la guarda, ni nada cambiado en los permisos, y pegarlo
  dos veces no mueve nada. Arregló, cada cosa probada antes y después:
  - la 139 salía en rojo falso en una base sana con un Zelle de verdad
    repartido en el mes de las pruebas;
  - la 137 no vigilaba que un mes ya CERRADO no salte (su tramo «g»);
  - la 138 sale «omitida», no en rojo, con un c15 de antes del 13-nov;
  - el mensaje dice «aprobadas y sin pagar al terminar el mes» en vez de
    «hoy … sin pagar»: son las que nadie había pagado al acabar el mes, y
    hoy pueden estar ya pagadas por la nómina del mes siguiente (por eso
    se devengan).
- Cuándo sale de la caja lo que se debe de la nómina se lee de la nota que
  c15 escribe en el asiento de cada cargo casado («…la nómina del <día de
  pago>»). Si c15 cambia ese texto, la prueba 62 de c16 sale en rojo.
- La primera vez que se pega el c3 del 14-nov crea un trigger sobre los
  asientos: es el único archivo que espera si la app está abierta (por eso
  PEGAR dice que se cierre).
- **De la revisión del c3 de la segunda vuelta, para más adelante (ninguna
  pasa hoy: no hay ningún devengo en la base):**
  - Con c3 en rojo por un mes así, el aviso 80 de c15 dice del mismo mes
    «si quieres ese costo en su mes, devéngalo… no es un error». La orden
    es la misma; choca el «si quieres». Se arregla con el próximo pegado
    de c15.
  - Si la marca de la nómina (c15) no contesta o no está, c3 toma el
    journal de c15 como uno que no dice qué pagó y ese mes deshecho se
    cierra callado. Hace falta romper c15 (se arregla volviéndolo a
    pegar). La salida, si se quiere: que el plan diga si el journal es de
    otro proveedor y tratar «marca rota, sin journals ajenos y con horas»
    como los jornales sin leer (probado en el banco: 138 en verde).
  - Unas horas pagadas por un Zelle clasificado A MANO en la Bandeja (no
    repartido como jornal en Costo por obra) c3 no las ve pagadas: con el
    devengo deshecho, ahora pide devengarlas, y hacerlo dejaría el costo
    dos veces en el mes. La regla de siempre: el Zelle de una persona por
    sus horas se reparte como jornal.
  - Con tres meses así a la vez, el mensaje de «Cerrar» (400 letras por
    fila) corta la orden del segundo mes; la fila del cierre (700) las trae
    enteras. Ya pasaba.
  - El tramo «b» de la 137 tiene el libro tomado durante una revisión
    entera del cierre: con un libro de un año, unos 3 s. Cabe en la regla
    de unos 5 s, pero crece con el libro.

## ▶ Pendientes
- **Edgar, antes del 4-ene**: bajar de Gusto un «Payroll journal» en CSV
  (aunque salga vacío) y la plantilla de «Import payroll data», para fijar
  las columnas; decir qué día empieza la semana laboral en Gusto; cada
  empleado con el mismo nombre que en la app; la cuenta de las horas sin
  obra (Nómina → Ajustes). La primera nómina se corre a más tardar el lunes
  4-ene a las 7 pm.
- **Gusto (soporte)**: si el plan Simple deja elegir columnas del journal;
  cuándo se retira el journal viejo; cómo sale el reempleo de Florida; cómo
  cobra una corrección (descuenta del siguiente cargo o devuelve).
- **CPA**: la cuenta de las horas sin obra; la regla del oficial (80 h por
  período; 5001 en obra, 6005 lo demás) y su sueldo razonable; si lo del
  patrón por oficina y oficial va a 6010; lo trabajado y no pagado al cierre
  del año; la clave y la frecuencia del reparto de la bolsa y si se cierra la
  variación a 5019; sección 125 y 401(k) en el 940 y el RT-6; horas extra y
  Fla. Stat. 448.01; 2553 / S-corp y el seguro médico del accionista (6006);
  reembolsos por nómina (plan con rendición de cuentas); quien pasa de 1099 a
  W-2 en 2027.

