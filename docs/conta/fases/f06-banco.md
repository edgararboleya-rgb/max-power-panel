# Fase 6 · Banco, tarjetas, cobros y pagos
**19 – 25 oct · 🔵 AZUL idempotencia, conciliación, cobros y pagos · 🟢 VERDE los lectores y la aplicación · ▶ archivos para el viernes 16-oct; arranca Gusto**

## Tú

1. **Para el viernes 16-oct:** un CSV u OFX de **cada cuenta y cada tarjeta**
   (septiembre y lo que haya de octubre). Sin eso no se puede escribir el
   lector — cada banco exporta distinto.
2. **Esta semana, aparte del banco: abrir la cuenta de Gusto.** Confirmar
   antes que Check no vende a empleadores directos (solo embebido en
   plataformas), y solicitar el acceso de **API de producción**: las llaves
   demo son inmediatas, las de producción pasan por aprobación. Meta:
   empleados dados de alta (W-4, depósito directo) **antes del 11-dic**. Ver f11.
3. Los statements de préstamo y la póliza de cada seguro pagado por adelantado.
4. **Abrir la cuenta de reserva de impuestos** y programar la transferencia
   semanal (el monto, con el CPA). Pedirle también el % de la utilidad para
   2027 y cuánto pagar el 15-ene-2027.

## Las cuentas (Edgar, 24-sep)
- **Chase, una sola cuenta**: la operativa del negocio, donde se mueve todo →
  **1010**. No hay cuenta de nómina ni tarjeta Chase: Gusto también cobra
  desde 1010. **1020 sale de c1** cuando termine el workflow (se añade el día
  que se abra).
- **Reserva de impuestos → 1030, se queda** (Edgar, 24-sep). Cuenta de ahorro
  de empresa, por abrir; banco por decidir (ver abajo). Entra por
  `transferencia` 1010 → 1030 sin tocar resultados; sus intereses van a 4910;
  lo que sale para el impuesto sobre la renta de Edgar va a **3200** (f07,
  regla a); se concilia contra su statement como cualquier banco.
- **American Express Business Gold** → `2100-2013` (la tarjeta acaba en 2013;
  en QuickBooks la Gold figura como 1007: si es otra tarjeta o la anterior,
  se da de alta también en `tarjetas`, a la misma subcuenta).
- **American Express Business Blue** → `2100-2009`.
- **Chase débito** acaba en **9420** → `1010` (la cuenta operativa; en
  QuickBooks la cuenta es «Chase Chk 4392»: 4392 es el número de la cuenta,
  9420 el de la tarjeta, que es el que sale en los tickets).
- Las tres están dadas de alta en producción (tabla `tarjetas`, 24-sep).
- **Efectivo → 1050 Efectivo (caja chica)** (Edgar, 24-sep: el efectivo sale
  de Chase; casi nadie le paga en efectivo). El retiro de Chase entra como
  Dr 1050 / Cr 1010 (el lector del banco lo propone así, sin gasto); cada
  compra en efectivo sale de 1050 por su puente. Un retiro para Edgar no es
  caja chica: va a 3200. Cuando el banco traiga un retiro de cajero, la app
  pregunta «¿caja chica o para ti?».
  Amex en su web muestra los últimos **5** dígitos; la subcuenta y
  `recibos.ultimos4` usan los últimos 4.
- Pago de cada Amex desde Chase = `transferencia`: Dr 2100-XXXX / Cr 1010,
  sin gasto.
- **Dónde abrir la reserva (recomendación del 24-sep):** ahorro de empresa de
  alto rendimiento en otro banco (FDIC, sin cuota mensual, con export QFX/CSV
  y presente en Plaid) — rinde ~3,8–4 % (sep-2026) contra casi 0 % en Chase, y
  fuera de la vista no se toca. Alternativa simple: Chase Business Total
  Savings (misma conexión de Plaid, transferencia al instante; $10/mes salvo
  saldo ≥ $1.000 o vinculada a Business Complete Checking).
- **Cómo se llena:** transferencia **semanal automática fija** (programada en
  el banco; el monto lo fija el CPA) + **ajuste mensual al cierre** que
  calcula la app (f08).
- Archivo preferido: **QFX/OFX**, porque cada movimiento trae su propio id
  (FITID) y eso ayuda a la idempotencia. CSV solo si no hay otro.
- **Conector automático: Plaid, plan Trial** (Edgar lo pide, 24-sep). Gratis,
  hasta 10 conexiones reales, incluye Chase, Amex y Transactions, sin
  cuestionario de seguridad. Max Power usa **2 conexiones**: Chase y Amex (Gold
  y Blue entran juntas con el mismo usuario de Amex). No pedir Production de
  pago: el Trial solo existe para cuentas que nunca lo pidieron, y fuera del
  Trial Chase tardaba 3–4 meses en aprobar (julio 2025). Chase comparte datos
  con Plaid por API oficial; la API directa de Chase es solo para clientes de
  tesorería de J.P. Morgan. El archivo sigue siendo el respaldo permanente
  (§5.5 del plan).
- **Plaid en la Fase 6 (🔵 azul):** función `plaid` en Supabase (link token,
  canje del token, `/transactions/sync` diario + webhook). El access token vive
  en **Vault**, nunca en una tabla. Los movimientos entran a la misma tabla
  que los del archivo, y **el mismo cargo por Plaid y por archivo entra una
  sola vez**. Solo se contabiliza lo posteado, nunca lo pendiente. Edgar pone
  `PLAID_CLIENT_ID` y `PLAID_SECRET` en los secretos de Supabase y la URL de
  la app en las redirect URIs de Plaid; el secreto nunca pasa por el chat.

## 🔵 Azul — se crea (`/effort max`)

- **Idempotencia** por movimiento **y entre archivos**: la salida del banco y
  el abono en la tarjeta son el mismo dinero.
- **Conciliación de verdad, no igualdad.** Saldo del estado + depósitos en
  tránsito − cheques y cargos en circulación = saldo en libros. Tabla
  `conciliaciones` (cuenta, mes, saldo_banco, fecha_confirmada) y
  `conciliacion_partidas` con FK a la línea del asiento o al movimiento
  importado (cada partida tiene clic hasta su asiento). Las partidas en
  tránsito al 30-sep de la era QuickBooks entran como conciliación de
  apertura. Tarjetas contra su statement a su fecha de corte.
  *«Saldo en libros = saldo del banco» a secas impedía cerrar cualquier mes.*
- Tipo de movimiento **`transferencia`**: casa la salida del banco con el abono
  de la tarjeta (o entre cuentas de banco, si algún día hay más de una), por
  monto y fecha ±3 días, y postea un solo asiento Dr 2100-x / Cr 1010 **sin gasto**.
- **Casado determinista de cobros**: un depósito se casa con facturas abiertas
  y alimenta `cobros` (f03); nunca se categoriza a ingreso.
- **Casado de pagos a proveedor**: el pago (banco o tarjeta) se aplica a las
  líneas abiertas de 2010 de ese proveedor; **nunca se recategoriza a 5100**
  (el gasto ya entró con el ticket).
- Tabla `prestamos` (prestamista, principal, tasa, cuota, inicio, cuenta 25xx)
  y función SQL que propone la partición capital/interés de cada cuota; el
  statement del prestamista manda sobre la función.

## 🟢 Verde — se trabaja encima (`/effort auto`)
Un lector por banco y por tarjeta. El importador de archivo **se queda para
siempre**. La pantalla de aplicación de cobros y de pagos, y el botón que
sustituye a `cambiarFactura({pagada:true})`.

## Entregable
`docs/conta/c6-banco.sql` · el importador y la aplicación en `js/conta.js`

## Terminó cuando
Importas el mismo archivo dos veces y no entra nada la segunda vez; **el pago
de la tarjeta del mes no aparece en ninguna cuenta de gasto**; cada depósito
casa con una fila de `cobros`; y septiembre concilia con sus partidas en
tránsito, sin tocar 1010.

## Lo construido (27-sep) — versión candidata, sin pegar
- `docs/conta/c6-banco.sql` (marca 2026092704) y `docs/conta/c6-pruebas.sql`
  (**100 pruebas**, resultado también en `pruebas.c6_resultado`). Trece
  tablas, ocho vistas y veintiuna funciones para la app: los archivos del
  banco enteros (texto y sha256) y cada movimiento como fila inmutable;
  el lector de OFX/QFX 1.x (SGML) y 2.x (XML) de banco y de tarjeta, con
  su saldo final; `fn_banco_importar_filas` para Plaid (solo lo posteado,
  el signo volteado al entrar); el casado (`fn_banco_casar_todo`):
  automático solo el cruce exacto y mutuo con lo que ya está en el libro
  (ticket de c3, cobro, la otra mitad de una transferencia, cuota, partida
  de la apertura) y dos reglas fijas (intereses 4910, cargos 6130); todo lo
  demás con su propuesta y sus botones en `v_banco_bandeja`
  (`fn_banco_casar_con`, `fn_banco_cobrar`, `fn_banco_pagar_proveedor`,
  `fn_banco_transferencia`, `fn_banco_clasificar`, `fn_banco_ignorar`,
  `fn_banco_duplicado`, `fn_banco_devolver`, `fn_banco_descasar`, todas con
  rastro); la conciliación de verdad a la fecha de corte (`fn_conciliar`,
  partidas en tránsito con motivo, se confirma solo con 0.00 y nada sin
  casar, se reabre con motivo, la de apertura al 30-sep con
  `fn_conciliacion_apertura`); préstamos (`prestamos`, `fn_prestamo_cuota`:
  capital e interés, el statement manda sobre la fórmula) y prepagados
  (`prepagados`, `fn_prepagados_amortizar`: seguros y fianzas al gasto día
  por día, la prima de WC aparte); `fn_banco_control(periodo, p_vistas)` con
  el contrato de c4 y `fn_banco_verificar()` desde el SQL Editor.
- Bloque B del §6b: diseño + 3 rondas de ataque (33, 26 y 26 hallazgos; 79
  confirmados, 74 corregidos, 8 partes rechazadas con motivo escrito en las
  cabeceras y el README). Prueba final de cero en Postgres 16 y 17.6: c2
  82/82, c3 120/120, c4 111/111 (110 + 1 omitida en 16), c6 100/100;
  idempotente; sin rastro; pegado, concurrencia, volumen (10.000
  movimientos en 36 archivos sobre 10.000 asientos: importar 0,7 s, casar
  un mes 1,8 s, cada vista 0,13 s) y «en uso» (las cuatro suites con el
  banco ya trabajando y con noviembre abierto encima de octubre) en verde.
  Repetido a mano el 27-sep con el mismo resultado. La ronda 3 todavía
  encontró 21 defectos reales (ninguno bloqueante): una cuarta ronda antes
  del pegado es razonable si hay crédito.
- **c2, c3 y c4 cambian (mínimo) y se vuelven a pegar antes de c6:** c2
  reparte y sella las funciones del banco y solo él fija el candado de
  `es_dueno()` (marca 2026092701); c3 deja soltar `cobros.movimiento_id` al
  des-casar, con marca (2026092601); c4 aprende el papel de las fases de
  después (`v_papel_fases`) y gana `fn_estados_version` (2026092601). Sus
  suites suben a 82, 120 y 111. c6 para con MX000 si alguno es viejo.
- Para conta.js: si `fn_banco_casar_todo` devuelve `completo: false`, la
  pantalla vuelve a llamar (pasa solo con meses sin resolver); préstamos y
  pólizas se registran desde el SQL Editor (`fn_prestamo_guardar`,
  `fn_prepagado_guardar`) hasta que haya pantalla.
- Dudas para Edgar (del diseñador): si Plaid entrará con la sesión de Edgar
  o por una función del servidor (hoy `fn_banco_importar_filas` exige al
  dueño); los statements al 30-sep de cada préstamo y las pólizas vigentes
  (GL, WC, auto, fianzas) para registrarlos con su saldo; su nombre tal
  como sale en Chase para el descriptor `zelle_edgar`; un QFX real de cada
  Amex para confirmar el signo del saldo; cada cuánto cuenta la caja chica;
  si la comisión de Gusto sale en un cargo aparte; si deposita varios
  cheques juntos; qué día cierra cada Amex; y la conciliación de QuickBooks
  de Chase al 30-sep (saldo del statement y partidas en tránsito) para la
  conciliación de apertura.
- **En producción (27-sep):** c2, c3 y c4 nuevos y c6 pegados por Edgar
  (23:2x–23:3x UTC), todos en `true`; c2-pruebas 82/82, c3-pruebas 119 +
  la 45 omitida, c6-pruebas **100/100** y c4-pruebas **111/111** (las dos
  últimas repetidas una a la vez: lanzadas juntas se cruzaron candados y
  salieron tres en rojo por deadlock o lock timeout, no por defecto).
  Sin rastro; cadena, puentes, banco y estados en verde. Evidencia en
  `pruebas/conta/resultados/2026-09-27-produccion/`. Queda pendiente la
  cuarta ronda de ataque si Edgar la aprueba, y lo suyo: préstamos y pólizas
  con su saldo al 30-sep, la conciliación de QuickBooks de Chase al 30-sep,
  el patrón de su Zelle, un QFX real de cada Amex, y el aviso de cuota de
  Supabase (restricción desde el 26-oct).

- **Cuarta ronda (2 al 4-oct), en Opus azul.** Seis lentes (contable,
  seguridad, operación, rendimiento y dos nuevas: el importador con lo que
  mandan de verdad Chase, Amex y Plaid, y el primer mes real sobre una copia
  de producción): 41 hallazgos, **37 confirmados** (17 importantes, 20
  menores, ninguno bloqueante), corregidos por cuatro correctores con una
  prueba por hallazgo. Cada prueba final atacó lo nuevo y abrió una vuelta
  más, todas sobre lo mismo (el dinero entre las cuentas de la empresa, la
  personal de Edgar y la reserva):
  - **4b**: EL PRINCIPIO — el dinero del banco a 2900, 3100 o 3200 nunca
    entra sin motivo ni se casa solo, salvo desde una cuenta personal que
    Edgar dio de alta (`banco_cuentas_personales`, `fn_banco_cuenta_personal`).
  - **4c**: EL CRITERIO DEL OTRO LADO — una sola respuesta a «¿quién es el
    otro lado?» (cuenta propia por número o sin él, personal dada de alta,
    desconocida o tercero) para R3, «Desde/A», transferencias, cobros y la
    bandeja; la línea de crédito y los préstamos se dan de alta por número.
  - **4d**: EL CONTROL — el cuadre 59 («el otro lado de cada casado») pone en
    rojo cualquier casado que contradiga el criterio y frena la conciliación
    hasta des-casarlo o escribir su motivo; R1 con asientos a mano y el cobro
    de c3 miran el criterio; y c6 se entrega también en dos partes
    (`c6-banco-parte1.sql` y `-parte2.sql`, por si el SQL Editor no aguanta
    los 1,2 MB del entero), probadas iguales al entero.
  Resultado en el banco de pruebas, en 16 y 17.6: c2-pruebas 83, c3-pruebas
  120, c4-pruebas 113 y c6-pruebas **161**, todas en verde; idempotente;
  pegado encima de producción (d80c9de) con el banco en uso sin cambiar una
  cifra. Marcas: c2 y c4 2026100201, c3 2026092601, c6 2026100303. Se pegan
  c2, c4 y c6 (o sus dos partes), en ese orden, y las cuatro suites, una a
  la vez. El ataque de la 4d dejó anotados caminos que el control todavía no
  mira (la cuota registrada antes que el banco, el cheque devuelto registrado
  desde cobros, R1 de la débito con un pase por número, el motivo automático
  de rehacer una transferencia) con su remedio en el README del banco de
  pruebas (§0); sus escenarios quedan en `pruebas/conta/ataques/`. El banco
  se da por cerrado hasta que lleguen los archivos reales de Edgar.
- **En producción (5-oct):** c2, c4 y c6 (en sus dos partes) pegados por
  Edgar entre las 16:04 y las 16:07 de Miami, todos en `true`; c2-pruebas
  83/83, c3-pruebas 119 + la 45 omitida, c6-pruebas **161/161** y
  c4-pruebas **113/113** (sola; el editor dio su error de red y la corrida
  siguió en el servidor). Marcas: c2 y c4 2026100201, c3 2026092601, c6
  2026100303. Sin rastro; cadena, puentes y banco en verde, y en los estados
  solo el rojo esperado de la apertura. Evidencia en
  `pruebas/conta/resultados/2026-10-05-produccion/`.

## La ronda 5 (9-oct): préstamos de cuota semanal
- El préstamo de negocio (2540/2550) se paga cada semana, y todo préstamo de
  c6 era mensual. Ahora cada préstamo dice cuántas cuotas tiene el año
  (`cuotas_al_anio`; `"frecuencia": "semanal"` en `fn_prestamo_guardar`): la
  fórmula parte el interés por período (lo del portal del prestamista al
  centavo), la porción corriente es el capital de un año de cuotas y la regla
  de «a días de la cuota anterior» se mide con el período. Marca 2026100901;
  prueba 162. Los pasos y la verificación, en `pruebas/conta/README.md`, «La
  ronda 5 de c6 (9-oct)».
- Lo que encontró su verificación (seis agentes sobre el banco, 9-oct tarde) y
  se corrigió en la misma entrega (prueba 163): varias cuotas semanales
  registradas antes que el banco no casaban solas (cada cargo mira ahora su
  cuota más cercana en fecha, y la bandeja va a R8 «ya registrada»); la cuota
  registrada antes y casada después no tomaba su cargo (`movimiento_id`); el
  recargo del banco sobre una cuota con otra registrada después no entraba y
  la posterior no se podía anular (a interés entra; `fn_prestamo_cuota_anular`,
  SQL Editor, de la última hacia atrás); la partición propuesta de la cuota
  siguiente se quedaba vieja hasta el siguiente «Casar» (se rehace al
  registrar o anular); un pago que no cubre el interés del período entraba
  entero a interés (pide el statement); un extra chico (< 10 %) se ofrece
  primero como recargo con su motivo; «quincenal» es dos al mes (24) y «cada
  dos semanas» 26, con sus textos. Las cifras del préstamo real salieron del
  repo (es público): la prueba usa un préstamo inventado.
