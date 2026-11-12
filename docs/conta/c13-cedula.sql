-- =====================================================================
-- c13-cedula.sql — LA CÉDULA DE CORTE (qué auxiliar sostiene cada saldo del
-- balance, de dónde sale, y si cuadra) · c13 (la mitad de la Fase 12a; f12
-- llama al entregable «c12-cedula.sql» por un nombre viejo: c12 ya es el
-- WIP. La otra mitad, W-9, COI y 1099, es c14-subs.sql: no dependen una de
-- la otra). 12-nov-2026. Se pega en el SQL Editor DESPUÉS de c1, c2 y c3 (en
-- producción, al final de la cadena: c1, c2, c3, c4, c6, c7, s1, p1, c8,
-- c9, c10, c11, c12 y esta; c4, c6, c9, c12 y p1 pueden faltar: lo que no
-- está no se mira, y la fila de esa cuenta lo dice). Idempotente: se puede
-- volver a pegar entero (no pisa la configuración, ni un renglón escrito a
-- mano, ni una explicación). Después se pega c13-pruebas.sql.
--
-- Qué hace. Max Power deja QuickBooks el 1-ene-2027. Para cortar con
-- confianza hace falta saber, cuenta por cuenta del balance, QUÉ HAY DEBAJO
-- de cada saldo: las facturas que suman las cuentas por cobrar, lo que se
-- le debe a cada supply, el statement de cada tarjeta, la carta de cada
-- préstamo, cada póliza, cada activo. Eso es un «auxiliar». La cédula es
-- UNA FILA POR CUENTA DE BALANCE (activo, pasivo y patrimonio) a una fecha:
--
--     saldo en el libro  |  su auxiliar (qué es y de dónde sale)  |
--     lo que suma el auxiliar  |  la diferencia  |  el estado
--
-- y el estado es uno de cinco:
--     cuadra        el auxiliar suma lo mismo que la cuenta, al centavo, Y
--                   ese auxiliar vale para ese día (un banco con la
--                   conciliación de otro día no cuadra aunque la resta dé
--                   cero) Y nada queda suelto que se compense (dos obras con
--                   saldos sin factura de signo contrario no cuadran)
--     del_libro     el «auxiliar» es el propio libro, ordenado (el
--                   patrimonio por su mayor, el use tax por mes), o es un
--                   papel de otro día llevado a la fecha con lo que el
--                   propio libro movió (una conciliación posterior, lo que
--                   Stripe debe hoy): por construcción no puede no sumar,
--                   así que NO se llama «cuadra». No pide nada, se cuenta
--                   aparte, y la fila dice cómo comprobarla de verdad
--     explicada     no cuadra (o no tiene auxiliar), pero Edgar escribió por
--                   qué: queda quién, cuándo y para qué fecha
--     no_cuadra     hay diferencia y nadie la ha explicado (o la explicación
--                   se quedó vieja: el saldo cambió después)
--     sin_auxiliar  la base todavía no tiene con qué sostener esa cuenta, y
--                   dice por qué: «llega con la nómina (f11)», «se escribe a
--                   mano», «todavía no hay activos cargados», «esa capa no
--                   está en esta base»
-- Y cada fila dice QUÉ HAY DEBAJO (sosten), para no confundir «cuadra con
-- un papel» con «sale del libro»:
--     papel      algo que no es el libro: el statement conciliado ese día,
--                la carta del préstamo, la póliza, el activo, el ajuste del
--                WIP, lo que Stripe debe, o renglones escritos a mano
--     partidas   las partidas abiertas del propio libro (cada factura, cada
--                proveedor, cada devengo): dice que cada línea tiene su
--                papel y que nada queda suelto, no que case con el statement
--                del supply ni con QuickBooks
--     libro      el propio libro, ordenado (patrimonio, use tax)
--     llevado    un papel de otro día, llevado a la fecha con el libro
-- LA CÉDULA SOLO MIRA. No postea nada, no corrige nada, no toca el libro ni
-- ninguna tabla de otra capa. Lo único que escribe son sus tres tablas: su
-- configuración, los renglones que Edgar escribe a mano y sus
-- explicaciones.
--
-- DE DÓNDE SALE EL AUXILIAR DE CADA CUENTA (fn_cedula_cuentas lo decide por
-- lo que la cuenta ES, no por una lista fija: una tarjeta o un banco nuevo
-- entran solos). Los auxiliares que YA existen en las capas se LEEN; no se
-- rehace ninguno:
--   · BANCOS Y TARJETAS (1010, 1030, cada 2100-XXXX): la conciliación
--     CONFIRMADA de c6. Su auxiliar es lo que dice el statement más los
--     depósitos en tránsito menos los cheques y cargos en circulación,
--     partida por partida. SOLO CUADRA CON LA DE ESE DÍA. Si la que hay es
--     POSTERIOR (se mira una fecha de antes), se llega al día quitándole lo
--     que el propio libro movió hasta su corte: da cero por construcción y
--     la fila dice «del libro» (no comprueba ese día). Si la última
--     confirmada es ANTERIOR al día, NO CUADRA aunque la resta dé cero (que
--     el libro no haya movido la cuenta no dice lo que hizo el banco: una
--     comisión, un cargo sin asentar): LO QUE HA PASADO DESPUÉS (cuántas
--     líneas y cuánto) sale aparte, y se arregla conciliando hasta el día.
--     Si después de confirmarla entró un asiento con fecha anterior a su
--     corte, esa parte de la diferencia se dice aparte (c6 también lo pone
--     en rojo: se reabre y se concilia otra vez).
--     Una subcuenta de tarjetas (2100-XXXX) que nadie dio de alta como
--     tarjeta de la empresa no la concilia c6: sale «sin auxiliar» diciendo
--     que le falta su alta, y mientras su statement se escribe a mano.
--   · CUENTAS POR COBRAR (1110) y RETENCIÓN POR COBRAR (1120): las partidas
--     abiertas del libro (c2 y c3): cada factura con lo que le falta por
--     cobrar —una cobrada a medias sale por la diferencia—, cada anticipo, y
--     en la retención cada factura en su obra. Lo que la cuenta tiene SIN
--     decir de qué factura es (un asiento a mano, el saldo de la apertura,
--     que llega de QuickBooks por obra y sin sus facturas) no está en el
--     auxiliar: es la diferencia, y sale aparte, obra por obra. Se sostiene
--     escribiéndole sus renglones (las facturas del A/R Aging de QuickBooks
--     al 30-sep) o explicándolo. LO SUELTO QUE SE COMPENSA TAMPOCO CUADRA:
--     700 sin factura en una obra y −700 en otra no cambian la cuenta ni la
--     resta, pero cada obra tiene un saldo que no es de ninguna factura (la
--     misma regla que el WIP); la fila pide, y lo dice.
--   · CUENTAS POR PAGAR (2010), la retención por pagar a subcontratistas
--     (2020) y los reembolsos a empleados (2250): por proveedor (o
--     empleado), el neto de sus papeles abiertos. Lo que no dice a quién se
--     le debe es la diferencia. OJO: son las partidas del PROPIO LIBRO. El
--     statement de cada supply se compara A MANO con ese renglón; la cédula
--     no lo hace, y lo dice (sosten = partidas).
--   · EL PRÉSTAMO DEL ACCIONISTA (2900): los recibos que Edgar pagó de su
--     bolsillo y siguen sin reembolsar (las partidas de c3); lo demás (el
--     saldo que venía de QuickBooks, una nota firmada) se escribe a mano.
--   · PRÉSTAMOS (2510 a 2550): cada préstamo de c6, con lo que se debía al
--     empezar menos el capital de cada cuota pagada hasta el día, PARTIDO
--     en lo que vence en un año (la parte corriente, en su cuenta: 2520 o
--     2540) y el resto (a largo plazo: 2530 o 2550), con la misma fórmula
--     que c6 enseña. El libro no reparte solo entre las dos cuentas (nadie
--     postea esa reclasificación): cuando las dos juntas cuadran y cada una
--     no, la fila lo dice, con el asiento que lo arregla.
--   · SEGUROS Y FIANZAS PAGADOS POR ADELANTADO (1410, 1420): las pólizas de
--     c6 (prepagados): de cada una, su inicio, su fin, sus meses y LO QUE
--     LE FALTA por pasar al gasto. Eso es «hoy»; a una fecha anterior se
--     llega quitándole SOLO lo que es de una póliza: su amortización (el
--     asiento de c6) y su compra, si la póliza dice con qué papel se compró
--     (papel_tabla y papel_id al registrarla: el papel del asiento, el
--     propio asiento por su id o su número, o el movimiento del banco). Lo
--     demás que el libro movió después en la cuenta (un cargo que no era
--     póliza y se corrigió) NO se le quita: sale aparte y es la diferencia
--     de aquel día. Una póliza comprada después del día y sin su papel no
--     se puede saber que no existía: no cuadra, y la fila dice qué hacer.
--   · ACTIVOS FIJOS (15xx) y su DEPRECIACIÓN ACUMULADA (1590): cada activo
--     de c9 por su costo, y de cada uno lo depreciado antes del libro más la
--     depreciación posteada de cada mes (la misma regla que la fila 90 del
--     cierre).
--   · EL WIP (1200, 2400, 2410): POR OBRA, contra el ajuste vivo de c12 que
--     esté en vigor ese día (el del último día del mes; el día 1 se deshizo
--     solo y la cuenta y el auxiliar valen cero). Aquí se compara obra por
--     obra: dos obras que se compensan no «cuadran».
--   · STRIPE (1020, 1140): lo cobrado en línea que falta depositar según p1
--     (la misma cuenta que su cuadre 21) y la cuenta de paso en cero. Es
--     «hoy»: mientras el libro no haya movido la cuenta después del día, se
--     compara tal cual; si la movió, se lleva a la fecha con esas líneas y
--     la fila dice «del libro» (no comprueba aquel día).
--   · USE TAX (2300): lo devengado y lo pagado cada mes, como lo enseña el
--     DR-15 de c9 (y lo que traía la apertura). Sale del propio libro: dice
--     de qué mes es cada saldo y NO lo compara con nada («del libro»). Si
--     se escribe a mano lo que dice cada DR-15 presentado (con su número de
--     confirmación), la cuenta pasa a compararse con eso.
--   · LO DEVENGADO (2050) y LOS SUELDOS ACUMULADOS (2210): cada asiento de
--     devengo que sigue vivo ese día (los que c2 deshace solos el día 1: el
--     devengo de cierre, el estándar de horas de c3). La nómina devengada de
--     verdad, partida en dos años, llega con f11.
--   · EL RESTO DE LA NÓMINA (2215, 2220, 2225, 2230, 2240): sin auxiliar
--     todavía: llega con la nómina (f11, el diario de Gusto).
--   · LA RESERVA DE IMPUESTOS (1030): es un banco: su auxiliar es su
--     conciliación. Lo que c9 calcula (cuánto DEBERÍA haber: la utilidad
--     por el % del contador menos los estimados pagados) es una meta, no lo
--     que sostiene el saldo: al pedir los renglones de esa cuenta sale como
--     un dato (clase «dato»), sin sumarlo ni compararlo.
--   · EL PATRIMONIO (3xxx): su propio mayor: lo que trajo la apertura (la
--     balanza de QuickBooks) más cada asiento posterior, mes por mes. No
--     hay otro auxiliar que un contador le pida al patrimonio; es el propio
--     libro («del libro», no «cuadra»), y lo que lo amarra de verdad es la
--     comparación con QuickBooks (abajo). Se puede cambiar a «a mano» (el
--     acta, la declaración) en la configuración; y si se le escriben
--     renglones a mano, se compara con ellos.
--   · LO QUE LA BASE NO SABE (la caja chica 1050, la cuenta por cobrar al
--     accionista 1130, la provisión de incobrables 1190, el material en
--     bodega 1300, los depósitos 1600, y cualquier cuenta nueva que no sea
--     nada de lo anterior): RENGLONES ESCRITOS A MANO (cedula_manual): qué
--     es, cuánto, con qué documento, una nota y desde qué día vale (y hasta
--     cuál, cuando deja de estar). Su suma se compara con la cuenta.
--     LA CAJA CHICA es la cuenta de la forma de pago «efectivo» de c3 (la
--     misma que el banco, c6, toma por caja y no deja conciliar), SALVO que
--     el banco la traiga (un estado de cuenta importado, movimientos o una
--     conciliación): entonces sigue siendo un banco, la fila lo avisa, y la
--     caja es la 1050 de siempre.
-- LOS RENGLONES A MANO SUMAN AL AUXILIAR de su cuenta, tenga o no uno
-- automático: así se sostiene lo que una capa no cubre (una línea de
-- crédito que c6 no lleva como préstamo, una fianza que no es póliza, el
-- 941 por depositar mientras no llega f11) sin tocar esa capa. La excepción
-- es lo que sale del propio libro (el patrimonio por su mayor, el use tax
-- por mes): ahí los renglones a mano no suman, SUSTITUYEN: la cuenta pasa a
-- compararse con lo escrito (el mayor queda debajo, de referencia), que es
-- la única manera de que esas cuentas se comparen con algo. Nada de lo que
-- aquí se escribe postea.
--
-- LA FECHA. La cédula se pide a un día (fn_cedula('2026-11-30')); todo se
-- toma con lo fechado hasta ese día inclusive. Los auxiliares que tienen
-- fecha (partidas, cuotas, activos, ajustes de WIP, devengos, renglones a
-- mano) se cortan a ese día. Una conciliación es de SU día (arriba). Dos no
-- tienen fecha —lo que Stripe dice que falta depositar y lo que les falta a
-- las pólizas son «hoy», como en los cuadres de p1 y de c6—: la fila dice
-- que su auxiliar es el de hoy (auxiliar_al), y a una fecha anterior NO se
-- dan por cuadradas a ciegas: lo de Stripe llevado con el libro es «del
-- libro», y a las pólizas solo se les quita lo que es de una póliza (lo
-- demás es la diferencia de aquel día). Sin fecha, la cédula es la del
-- último día del mes que toca: el mes (o la apertura) abierto más viejo que
-- ya terminó —el que se está cerrando—; si no hay, el último cerrado; si
-- tampoco, hoy.
--
-- LOS TOTALES (fn_cedula_resumen) CIERRAN A LA VISTA: además del activo, el
-- pasivo y el patrimonio (las cuentas 3xxx) traen el RESULTADO que todavía
-- no está en el patrimonio (ingresos menos costos y gastos hasta ese día):
-- activo = pasivo + patrimonio + resultado, siempre. Cuentan aparte lo que
-- cuadra contra un papel, lo que cuadra por las partidas del libro y lo que
-- sale del propio libro. Y el reparto de un préstamo entre corriente y
-- largo plazo, cuando su total cuadra, va aparte y una sola vez
-- (reparto_pendiente): no infla la diferencia pendiente.
--
-- EXPLICAR UNA DIFERENCIA (fn_cedula_explicar: cuenta, fecha, texto). Queda
-- quién y cuándo, y con qué saldo en el libro y en el auxiliar se explicó
-- (y cuánto tenía la cuenta suelto, sin decir de qué es). VALE PARA ESA
-- FECHA Y PARA ESOS NÚMEROS: si después el saldo del libro, el del auxiliar
-- o lo suelto a esa fecha cambian, la explicación se queda vieja, la fila
-- vuelve a «no cuadra» y lo dice (con los números de antes y los de
-- ahora); se explica otra vez y la anterior queda. No se edita ni se borra:
-- se sustituye o se retira con su motivo. Una cuenta que cuadra, o que sale
-- del propio libro, no se explica (MX008): no hay diferencia que explicar.
--
-- LA COMPARACIÓN CON QUICKBOOKS (para la 12b: la cédula al 30-nov contra la
-- balanza de QuickBooks al 30-nov). c4 ya tiene todo: la balanza cargada
-- por período, la comparación cuenta por cuenta y las diferencias anotadas.
-- Esta capa NO carga nada de QuickBooks: fn_cedula_qb(período) (y la vista
-- v_cedula_qb) pone al lado de cada fila de la cédula —calculada a la fecha
-- de esa balanza— lo que c4 dice de esa cuenta: lo que tiene QuickBooks, la
-- diferencia con el libro, lo explicado y lo que queda sin explicar. Una
-- cuenta «amarra» cuando las dos cosas están bien: QuickBooks contra el
-- libro (igual o explicado en c4) y el libro no pide nada aquí (cuadra,
-- está explicado, o sale del propio libro: al patrimonio lo amarra justo
-- esta comparación). Sin balanza cargada, las columnas de QuickBooks salen
-- vacías y lo dice.
--
-- EL CONTROL (fn_cedula_control / v_cedula_control; orden, control, nivel
-- «cuadre» | «aviso», ok, detalle en llano), al último día del período que
-- se pide (sin período, el que toca):
--     10 (cuadre) la cédula trae todas las cuentas de balance y su saldo es
--                 el del libro (no pinta ceros callada)
--     20 (aviso)  cada saldo con su auxiliar cuadrado o explicado (lo que
--                 sale del propio libro no pide nada: se cuenta aparte)
--     30 (aviso)  ninguna cuenta con saldo sin auxiliar ni explicación
--     40 (aviso)  ninguna explicación se quedó vieja
--     50 (aviso)  cada renglón escrito a mano dice su documento
--     90 (cuadre) las protecciones de la capa
-- y fn_cedula_cierre(período) los resume en LA fila que el cierre (c9)
-- enseña: la 178, un AVISO. No detiene nada: es de corte de año. Los
-- avisos (20, 30, 40 y 50) no se ponen en rojo mientras el período no
-- termine ni antes del mes desde el que se avisa (dicen cuántas cuentas
-- saldrían hoy; cedula_config.avisar_desde: nace en noviembre de 2026 —el
-- corte de la 12b es el 30-nov-2026—, se pegue cuando se pegue; la
-- apertura y octubre, que tenían ya su lista de cierre, no ganan un rojo
-- por ella). El nombre de la fila 178 es FIJO, sin la lista de
-- cuentas: la ronda de c9 avisa al teléfono de cada rojo nuevo por el
-- nombre de la fila, y una lista que se va acortando mientras Edgar la
-- trabaja sería un aviso cada mañana. El detalle sí la trae.
--
-- Decisiones de diseño (lo que f12 y el encargo dejaban abierto):
--   · «PATRIMONIO» EN EL PLAN ES EL TIPO «capital» (3000, 3100, 3200,
--     3900). Su auxiliar es su mayor (arriba); con patrimonio = «manual» en
--     la configuración pasa a renglones a mano. ▶ CPA.
--   · LOS SEGUROS (1410) Y LAS FIANZAS (1420) NO SON «A MANO»: c6 ya lleva
--     las pólizas (prepagados) y las amortiza. Se leen de ahí. Una fianza o
--     un depósito que no sea póliza se añade como renglón a mano.
--   · LA RESERVA (1030) contra su statement, no contra la meta de c9 (una
--     meta que se mueve con la utilidad de cada día nunca «cuadra» y no
--     sostiene nada).
--   · EL USE TAX (2300) y el patrimonio salen del propio libro, ordenados
--     (por mes; apertura más movimientos): por construcción suman la
--     cuenta. No fingen ser un papel de fuera, y por eso NO SE LLAMAN
--     «cuadra»: su estado es «del_libro», se cuentan aparte, y con
--     renglones a mano pasan a compararse con ellos.
--   · «CUADRA» PIDE UN AUXILIAR QUE VALGA PARA ESE DÍA. Una conciliación de
--     otro día no vale: anterior, no cuadra (prudente: el banco pudo hacer
--     algo que el libro no sabe; es un minuto conciliar un mes sin
--     movimientos); posterior, o lo de Stripe llevado con el libro, «del
--     libro» (da cero por construcción). Y a las pólizas solo se les quita
--     lo que es de una póliza: el precio es que una póliza comprada después
--     y registrada SIN su papel no cuadra a una fecha anterior a su compra
--     (se arregla diciéndole su papel, o explicándolo).
--   · LO SUELTO QUE SE COMPENSA NO CUADRA (cobrar, pagar, devengos), como ya
--     pasaba en el WIP: la cuenta entera puede sumar lo mismo que su
--     auxiliar con saldos sin papel en dos obras.
--   · EL REPARTO DE UN PRÉSTAMO entre corriente y largo plazo, cuando el
--     total cuadra, no es «diferencia sin explicar»: en los totales va
--     aparte, una vez (reparto_pendiente).
--   · UNA CUENTA SIN SALDO Y SIN AUXILIAR no pide nada (no está pendiente).
--     Una con saldo y sin auxiliar sí: o se le escriben sus renglones, o se
--     explica.
--   · AL CENTAVO, sin tolerancia: una diferencia de un centavo es una
--     diferencia.
--   · LAS CAPAS OPCIONALES SE LEEN AL VUELO (fn_cedula_capas dice cuáles
--     están): esta capa no cuelga de ninguna; si una falta, o si cambia de
--     forma y no se puede leer, sus cuentas salen «sin auxiliar» con ese
--     porqué y lo demás sigue.
--
-- LA SEGURIDAD (la regla de c2, B.20, y lo que c4, c6, c8, c9, c10 y c12
-- sellan):
--   · NINGUNA función de aquí es SECURITY DEFINER. Las que llama la pantalla
--     son SECURITY INVOKER, sin EXECUTE para public, anon ni service_role,
--     con EXECUTE para authenticated y es_dueno() por dentro
--     (fn_cedula_exigir_dueno): leen con la policy de cada tabla (solo el
--     dueño) y escriben con la policy de escritura del dueño de las tablas
--     de c13. Así «permisos» de c2 sigue en verde. Las de lectura no frenan
--     a nadie con un error: a quien no es el dueño no le devuelven nada (el
--     equipo no ve nada de c13: son los saldos del balance; tampoco qué
--     partes de la contabilidad hay instaladas: fn_cedula_capas le da {}).
--   · fn_cedula_pegado y fn_cedula_precondiciones: sin API (solo el SQL
--     Editor).
--   · Las tablas nacen con RLS y policies solo-dueño, y con la guarda de c6,
--     c9, c10 y c12: un trigger (fn_cedula_guarda) que solo deja escribir
--     con la marca de la transacción (mx_cedula.escribe = la tabla) que
--     ponen las funciones de aquí; a mano, aunque sea el dueño por la API,
--     MX003. Un renglón y una explicación son rastro: no se editan ni se
--     borran; lo único que les pasa es quedar sustituidos, anulados o
--     retirados, una vez.
--   · Las vistas son security_invoker y leen solo funciones y tablas de
--     aquí (nunca una vista de otra capa, que se borra y se rehace al
--     volver a pegar su archivo); no nombran ninguna columna de periodos ni
--     de cuentas (c2-pruebas las reescribe a propósito).
--   · Nada lleva un prefijo que otra capa sella ni de la otra sesión que
--     escribe esta base: aquí todo es fn_cedula* / cedula_* / v_cedula*.
--     es_dueno() no se toca.
--   · Lo que la pantalla escribe pasa por PostgREST con la sesión del
--     dueño: s1 (el código del teléfono) exige aal2 en cada petición. Esta
--     capa no añade nada a eso.
--
-- LOS ERRORES CON NOMBRE (conta.js los traduce mirando el código; ninguno
-- nuevo):
--   MX000  falta algo que este archivo da por hecho: no se aplica nada
--          (fn_cedula_precondiciones dice qué)
--   MX003  las tablas de c13 solo las escriben sus funciones (la guarda); lo
--          que es rastro no se edita ni se borra
--   MX004  la cuenta no sirve: no existe, no es de balance (activo, pasivo o
--          patrimonio) o es de grupo
--   MX005  un monto mal: no es un número, cero, o con más de dos decimales
--   MX008  no procede: la cuenta cuadra a esa fecha o sale del propio
--          libro (no hay nada que explicar), no hay explicación que retirar,
--          el renglón ya estaba anulado o sustituido
--   22023  entrada mal formada: falta un dato (qué es, desde cuándo, el
--          texto), una clave desconocida, una fecha o un mes mal escritos,
--          un texto demasiado corto, una fecha que todavía no llega, un
--          período que no existe
--   42501  permiso: solo el dueño; anon y service_role, nada
--   55P03  (de Postgres, «lock timeout») la app estaba usando las tablas de
--          c13 mientras se pegaba: no se aplicó nada, se vuelve a pegar
--
-- Lo que este archivo NO toca: c1..c12, s1, p1, es_dueno(), docs/sql, el
-- libro (ni postea ni reversa: solo lee), el banco, las tablas de la app
-- (lee proyectos, facturas, cobros, recibos, trabajos_externos, proveedores
-- y perfiles). No pone índices, triggers ni policies en tablas ajenas (sus
-- tres tablas apuntan a cuentas con una llave foránea, como las de c9 y
-- c12). No carga nada de QuickBooks (eso es de c4). No lleva W-9, COI ni
-- 1099 (c14).
--
-- Cómo se instala (Edgar, en este orden):
--   1. SQL Editor → pegar ESTE archivo entero → Run. Al final sale una
--      tabla: la configuración, las tablas y las vistas, qué capas
--      opcionales encontró, la cédula del día que toca en una línea (cuántas
--      cuentas cuadran, cuántas están explicadas, cuántas no cuadran y
--      cuántas no tienen auxiliar), el control y el paso siguiente. Si algo
--      de lo que da por hecho falta, para con MX000 y no queda nada. Con la
--      pantalla de Contabilidad cerrada (si alguien la está leyendo, 55P03:
--      se vuelve a pegar).
--   2. LA FILA 178 DEL CIERRE la pone c9-cierre.sql, no este archivo: el
--      c9 que la trae la nombra en su cabecera («178 la cédula de corte»).
--      La tabla del final del paso 1 dice cuál es tu caso: si el cierre de
--      esta base ya mira la cédula, no hay nada que hacer; si todavía no,
--      se vuelve a pegar el docs/conta/c9-cierre.sql QUE LA NOMBRE (si el
--      que tienes no la nombra, volver a pegarlo no cambia nada: la cédula
--      funciona entera sin él, y solo falta su aviso en la lista del
--      cierre; la prueba que lo comprueba sale «omitida» diciéndolo).
--   3. SQL Editor → pegar docs/conta/c13-pruebas.sql → sus 41 filas, todas
--      en true (las «omitida» dicen por qué; no es un fallo). Corre también
--      con todos los meses terminados ya cerrados: entonces prueba en el
--      mes que corre, con el reloj fingido dentro de cada prueba.
--   4. En la app: Contabilidad → Cédula.
--
-- Lo que llama la pantalla (RPC, como el dueño; las que escriben, con POST):
--   fn_cedula(p_fecha date)                       solo lee: la cédula, una fila por cuenta (estado: cuadra | del_libro |
--                                                 explicada | no_cuadra | sin_auxiliar; sosten: papel | partidas | libro |
--                                                 llevado; par y solo_reparto en un préstamo)
--   fn_cedula_partidas(p_fecha date, p_cuenta text)   solo lee: los renglones del auxiliar de una cuenta (o de todas); clase:
--                                                 auxiliar | libro (sale del propio libro) | suelto | despues | dato | error
--   fn_cedula_resumen(p_fecha date)               solo lee: los totales (la pantalla no suma), con resultado,
--                                                 patrimonio_total, balance_cuadra, del_libro, cuadran_papel,
--                                                 cuadran_partidas, reparto_pendiente y reparto_cuentas
--   fn_cedula_qb(p_periodo text)                  solo lee: la cédula al lado de QuickBooks (c4)
--   fn_cedula_explicar(p_cuenta text, p_fecha date, p_texto text)
--   fn_cedula_explicacion_retirar(p_cuenta text, p_fecha date, p_motivo text)
--   fn_cedula_renglon(p jsonb)                    un renglón a mano: {"cuenta", "concepto", "monto", "desde", "hasta"?,
--                                                 "documento"?, "nota"?}; con "id", corrige ese (el anterior queda)
--   fn_cedula_renglon_anular(p_id uuid, p_motivo text)
--   fn_cedula_config(p jsonb)                     {"avisar_desde": "2026-11" | null (o vacío: todavía no avisa),
--                                                 "patrimonio": "mayor" | "manual"}; sin argumentos, la devuelve
--   fn_cedula_control(p_periodo text) / fn_cedula_cierre(p_periodo text)
-- Y lee: v_cedula (la del día que toca), v_cedula_control, v_cedula_manual,
-- v_cedula_explicaciones, v_cedula_qb (filtrada por periodo), cedula_config.
-- Montos en dólares, numeric(14,2), CADA UNO EN EL LADO NATURAL DE SU
-- CUENTA: positivo = lo normal (un activo, lo que hay; un pasivo, lo que se
-- debe; la depreciación acumulada, lo depreciado). «signo» (1 o −1) lo pasa
-- a debe − haber.
--
-- ▶ PARA EDGAR Y EL CPA (no frena nada; se dice):
--   · ¿El patrimonio se sostiene con su mayor (como nace: «del libro», lo
--     amarra QuickBooks) o con papel aparte (el acta, la declaración de
--     2025: renglones a mano, y entonces se compara con ellos)?
--   · ¿El use tax se compara con cada DR-15 presentado? Entonces se escribe
--     a mano lo que dice cada uno (con su número de confirmación).
--   · El reparto de cada préstamo entre corriente y largo plazo no lo postea
--     nadie: la cédula dice cuánto; el asiento es a mano. ¿Cada mes, o solo
--     al corte del año?
--   · Un banco o una tarjeta sin movimientos en el mes también se concilia
--     (el saldo del statement de ese día): sin eso, la cédula de ese día no
--     cuadra aunque la resta dé cero. Si el CPA prefiere darlo por bueno,
--     se explica.
--   · Las pólizas se registran en el SQL Editor (c6): conviene decirles con
--     qué papel se compraron (papel_tabla, papel_id), para que la cédula de
--     una fecha anterior a su compra no las cuente.
--   · Desde qué mes avisa el cierre de lo que no cuadra (nace en noviembre
--     de 2026: el 30-nov es el corte de la 12b; se cambia en la
--     configuración, o se deja en «todavía no»).
-- =====================================================================
-- (Lo primero, como en c4, c6, c10 y c12: el pegado espera un candado como
-- mucho medio segundo. Con la app leyendo, para con 55P03 («lock timeout»),
-- no se aplica nada y se vuelve a pegar. Dura lo que dura el pegado.)
set local lock_timeout = '500ms';


-- ---------------------------------------------------------------------
-- 0. Las guardas, y lo que este archivo da por hecho (MX000 sin tocar nada)
-- ---------------------------------------------------------------------
-- Lo que falta para pegar c13, en llano (nulo = nada). La usan la
-- precondición de abajo y las pruebas.
create or replace function public.fn_cedula_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
  v_v     bigint;
  c_tablas constant text[] := array['cedula_config', 'cedula_manual', 'cedula_explicaciones'];
  c_vistas constant text[] := array['v_cedula', 'v_cedula_control', 'v_cedula_manual', 'v_cedula_explicaciones', 'v_cedula_qb'];
  c_fn     constant text[] := array['fn_cedula_precondiciones', 'fn_cedula_exigir_dueno', 'fn_cedula_ve', 'fn_cedula_guarda',
                                    'fn_cedula_usd', 'fn_cedula_dia', 'fn_cedula_mes', 'fn_cedula_monto', 'fn_cedula_capas',
                                    'fn_cedula_toca', 'fn_cedula_cuentas', 'fn_cedula_partidas', 'fn_cedula', 'fn_cedula_resumen',
                                    'fn_cedula_qb', 'fn_cedula_qb_periodos', 'fn_cedula_config', 'fn_cedula_renglon',
                                    'fn_cedula_renglon_anular', 'fn_cedula_explicar', 'fn_cedula_explicacion_retirar',
                                    'fn_cedula_control', 'fn_cedula_cierre', 'fn_cedula_pegado'];
begin
  foreach v_x in array array['es_dueno()', 'fn_desde_editor()', 'fn_fecha_miami(timestamptz)', 'fn_libro_version()'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'periodos', 'asientos', 'asiento_lineas', 'perfiles', 'proyectos', 'facturas', 'cobros',
                             'recibos', 'trabajos_externos', 'proveedores', 'puente_cuentas', 'mapeo_metodo_pago', 'tarjetas'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if cardinality(v_falta) > 0 then
    return format('c13 se pega después de c1, c2 y c3 (y de c4, c6, c7, s1, p1, c8, c9, c10, c11 y c12 si se usan), con las tablas de '
                  'la app: falta %s.', array_to_string(v_falta, ', '));
  end if;
  -- La versión de c2 que va con esta capa (la del tiempo en producción).
  execute 'select public.fn_libro_version()' into v_v;
  if coalesce(v_v, 0) < 2026100201 then
    return format('el c2-libro.sql pegado es anterior (marca %s; esta capa pide 2026100201): vuelve a pegar c2-libro.sql.', v_v);
  end if;
  -- Las columnas que esta capa lee por su nombre.
  select string_agg(x.t || '.' || x.c, ', ' order by x.t, x.c) into v_x
    from (values ('cuentas', 'codigo'), ('cuentas', 'nombre'), ('cuentas', 'tipo'), ('cuentas', 'imputable'),
                 ('cuentas', 'saldo_normal'), ('cuentas', 'regla_obra'),
                 ('periodos', 'periodo'), ('periodos', 'tipo'), ('periodos', 'desde'), ('periodos', 'hasta'), ('periodos', 'estado'),
                 ('asientos', 'numero'), ('asientos', 'fecha_contable'), ('asientos', 'periodo'), ('asientos', 'tipo'),
                 ('asientos', 'reversa_a'), ('asientos', 'reversible'), ('asientos', 'descripcion'),
                 ('asiento_lineas', 'cuenta'), ('asiento_lineas', 'monto'), ('asiento_lineas', 'proyecto_id'),
                 ('asiento_lineas', 'tercero_tipo'), ('asiento_lineas', 'tercero_id'), ('asiento_lineas', 'partida_tabla'),
                 ('asiento_lineas', 'partida_id'),
                 ('perfiles', 'nombre'), ('perfiles', 'rol'), ('proyectos', 'nombre'),
                 ('facturas', 'num'), ('facturas', 'fecha'), ('facturas', 'proyecto_id'),
                 ('cobros', 'fecha'), ('cobros', 'referencia'), ('recibos', 'proveedor'), ('recibos', 'fecha'),
                 ('trabajos_externos', 'descripcion'), ('trabajos_externos', 'fecha'), ('proveedores', 'nombre'),
                 ('puente_cuentas', 'rol'), ('puente_cuentas', 'cuenta'),
                 ('mapeo_metodo_pago', 'forma'), ('mapeo_metodo_pago', 'cuenta'), ('mapeo_metodo_pago', 'confirmado_el'),
                 ('tarjetas', 'cuenta')) as x(t, c)
   where not exists (select 1 from information_schema.columns k
                      where k.table_schema = 'public' and k.table_name = x.t and k.column_name = x.c);
  if v_x is not null then
    return format('faltan columnas que esta capa lee: %s. ¿Es la base de la app, con c3 pegado?', v_x);
  end if;
  -- Una tabla con el nombre de las de c13 que no sea de c13: se para antes de
  -- tocar nada (la lección de c8 con ia_propuestas).
  foreach v_x in array array['cedula_config:avisar_desde', 'cedula_manual:concepto', 'cedula_explicaciones:saldo_libro'] loop
    if to_regclass('public.' || split_part(v_x, ':', 1)) is not null
       and not exists (select 1 from information_schema.columns
                        where table_schema = 'public' and table_name = split_part(v_x, ':', 1) and column_name = split_part(v_x, ':', 2)) then
      return format('la tabla %s ya existe en esta base y no es la de c13 (no tiene la columna %s): otra cosa usa ese nombre. No la '
                    'toco; avisa antes de seguir.', split_part(v_x, ':', 1), split_part(v_x, ':', 2));
    end if;
  end loop;
  -- Una vista o una función con nombre de c13 que no sea de c13 (otra sesión
  -- escribe esta misma base): «create or replace» la pisaría sin avisar.
  select string_agg(x.que, ', ' order by x.que) into v_x
    from (select 'la vista ' || c.relname as que
            from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind in ('v', 'm', 'r') and c.relname = any (c_vistas)
             and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c13: %'
          union all
          select 'la función ' || p.oid::regprocedure::text
            from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.proname = any (c_fn)
             and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c13: %') x;
  if v_x is not null then
    return format('ya hay en esta base, con nombre de c13 y sin ser de c13: %s. No lo piso; avisa antes de seguir.', v_x);
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: la cédula la mira y la explica el dueño.';
  end if;
  -- Nada ajeno colgado de las vistas de c13 (se borran y se rehacen).
  select string_agg(distinct format('la vista %s', dc.oid::regclass), ', ') into v_x
    from pg_depend d
    join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
    join pg_class dc on dc.oid = rw.ev_class
    join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
   where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname = any (c_vistas)
     and dc.oid <> cv.oid
     and not (dc.relnamespace = 'public'::regnamespace and dc.relname = any (c_vistas));
  if v_x is not null then
    return format('%s depende(n) de las vistas de c13, que al pegarlo se borran y se rehacen: guarda su definición, bórralas, '
                  'pega c13 y vuelve a crearlas.', v_x);
  end if;
  return null;
end $$;
revoke execute on function public.fn_cedula_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_cedula_precondiciones() is 'c13: lo que falta para pegar c13-cedula.sql (nulo = nada): c1, c2 (marca 2026100201) y c3, las tablas y columnas de la app que lee, el SQL Editor, un dueño activo, nada ajeno con nombre de c13 y nada ajeno sobre sus vistas.';

do $$
declare
  v text;
begin
  v := public.fn_cedula_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c13-cedula NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1, c2, c3, c4, c6, c7, s1, p1, c8, c9, c10, c11, c12 y después este archivo (pruebas/conta/README.md, §0).';
  end if;
end $$;

-- ¿Quién llama por la API? Solo el dueño. Desde el SQL Editor o pg_cron
-- (current_user no es un rol de la API) pasa. Solo es_dueno(), como c4, c6,
-- c9, c10 y c12: fn_desde_editor no es ejecutable por authenticated.
create or replace function public.fn_cedula_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if current_user in ('authenticated', 'anon') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501',
      message = 'La cédula (cada saldo del balance y lo que lo sostiene) la ve y la toca solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_cedula_exigir_dueno() from public, anon, service_role;
grant  execute on function public.fn_cedula_exigir_dueno() to authenticated;
comment on function public.fn_cedula_exigir_dueno() is 'c13: la guarda de lo que llama la pantalla: por la API solo el dueño (es_dueno); el SQL Editor y pg_cron pasan.';

-- ¿Ve quien mira? Lo mismo, sin error: las de lectura no frenan a nadie; a
-- quien no es el dueño no le devuelven nada.
create or replace function public.fn_cedula_ve() returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select current_user not in ('authenticated', 'anon', 'service_role') or coalesce(es_dueno(), false)
$$;
revoke execute on function public.fn_cedula_ve() from public, anon, service_role;
grant  execute on function public.fn_cedula_ve() to authenticated;
comment on function public.fn_cedula_ve() is 'c13: verdadero para el dueño por la API y para el SQL Editor; las funciones de lectura no devuelven nada a los demás.';


-- ---------------------------------------------------------------------
-- 1. Las tablas (nacen cerradas: solo el dueño lee; escribe solo el dueño
--    por las funciones de aquí, con la marca de la transacción). Montos en
--    dólares, numeric(14,2), en el lado natural de su cuenta. Llaves
--    foráneas a cuentas y entre tablas de c13. Para crecer, «add column if
--    not exists».
-- ---------------------------------------------------------------------
-- La configuración: una sola fila.
--   avisar_desde  el primer mes (AAAA-MM) en que el cierre avisa de lo que
--                 no cuadra ni está explicado; vacío = no avisa todavía
--   patrimonio    cómo se sostienen las cuentas de patrimonio: «mayor» (su
--                 propio mayor: apertura más movimientos) o «manual»
--                 (renglones escritos a mano)
create table if not exists public.cedula_config (
  id               int         primary key,
  avisar_desde     text,
  patrimonio       text        not null default 'mayor',
  actualizado      timestamptz not null default now(),
  actualizado_por  uuid,
  historial        jsonb       not null default '[]'::jsonb,
  constraint cedula_config_una        check (id = 1),
  constraint cedula_config_desde      check (avisar_desde is null or avisar_desde ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  constraint cedula_config_patrimonio check (patrimonio in ('mayor', 'manual')),
  constraint cedula_config_historial  check (jsonb_typeof(historial) = 'array')
);
comment on table public.cedula_config is 'c13: la configuración de la cédula (una fila): avisar_desde, el primer mes (AAAA-MM) en que el cierre avisa de los saldos que no cuadran con su auxiliar ni están explicados (vacío = no avisa todavía; nace en 2026-11, el mes del corte de la 12b); patrimonio, cómo se sostienen las cuentas de patrimonio (mayor = su propio mayor, apertura más movimientos; manual = renglones escritos a mano); quién la cambió y cuándo, y cada valor anterior en historial. Se cambia con fn_cedula_config.';

-- Los renglones escritos a mano: lo que sostiene una cuenta cuando la base
-- no lo sabe (un depósito en garantía, el material en bodega, el arqueo de
-- caja, la nota del accionista). Solo se añade; uno corregido queda
-- sustituido por su versión nueva, y uno que estaba mal, anulado con su
-- motivo. desde y hasta dicen entre qué días ESTUVO en el saldo: la cédula
-- de una fecha lo cuenta si ese día cae dentro.
create table if not exists public.cedula_manual (
  id              uuid          primary key default gen_random_uuid(),
  cuenta          text          not null references public.cuentas (codigo),
  concepto        text          not null,
  monto           numeric(14,2) not null,
  documento       text,
  nota            text,
  desde           date          not null,
  hasta           date,
  sustituye_a     uuid          references public.cedula_manual (id),
  creado_el       timestamptz   not null default now(),
  creado_por      uuid,
  sustituido_el   timestamptz,
  anulado_el      timestamptz,
  anulado_por     uuid,
  anulado_motivo  text,
  constraint cedula_manual_concepto check (btrim(concepto) <> ''),
  constraint cedula_manual_monto    check (monto <> 0),
  constraint cedula_manual_fechas   check (hasta is null or hasta >= desde),
  constraint cedula_manual_anulado  check ((anulado_el is null) = (coalesce(btrim(anulado_motivo), '') = '')),
  constraint cedula_manual_un_fin   check (sustituido_el is null or anulado_el is null)
);
create index if not exists cedula_manual_cuenta_idx on public.cedula_manual (cuenta) where sustituido_el is null and anulado_el is null;
create unique index if not exists cedula_manual_sustituye_unico on public.cedula_manual (sustituye_a) where sustituye_a is not null;
comment on table public.cedula_manual is 'c13: los renglones escritos a mano que sostienen una cuenta de balance cuando la base no lo sabe: la cuenta, qué es (concepto), cuánto (monto, en el lado natural de la cuenta: positivo = lo normal), con qué documento, una nota, desde qué día vale y hasta cuál (vacío = sigue); quién lo escribió y cuándo. El vigente es el que no está sustituido (sustituido_el: lo reemplazó su versión corregida, que lo nombra en sustituye_a) ni anulado (anulado_el, por quién y por qué). Suman al auxiliar de su cuenta en las fechas entre desde y hasta. No postean nada. No se editan ni se borran. Se escriben con fn_cedula_renglon y fn_cedula_renglon_anular.';

-- Las explicaciones: por qué una cuenta no cuadra con su auxiliar (o no lo
-- tiene) a una fecha, con los números con que se explicó. Solo se añade;
-- otra la sustituye, o se retira con su motivo.
create table if not exists public.cedula_explicaciones (
  id               uuid          primary key default gen_random_uuid(),
  cuenta           text          not null references public.cuentas (codigo),
  fecha            date          not null,
  texto            text          not null,
  estado           text          not null,
  saldo_libro      numeric(14,2) not null,
  saldo_auxiliar   numeric(14,2),
  diferencia       numeric(14,2),
  explicado_el     timestamptz   not null default now(),
  explicado_por    uuid,
  sustituida_el    timestamptz,
  retirada_el      timestamptz,
  retirada_por     uuid,
  retirada_motivo  text,
  constraint cedula_explicaciones_texto  check (btrim(texto) <> ''),
  constraint cedula_explicaciones_estado check (estado in ('no_cuadra', 'sin_auxiliar')),
  constraint cedula_explicaciones_retiro check ((retirada_el is null) = (coalesce(btrim(retirada_motivo), '') = '')),
  constraint cedula_explicaciones_un_fin check (sustituida_el is null or retirada_el is null)
);
-- (lo que la cuenta tenía SUELTO —sin decir de qué es— al explicarla, en valor absoluto: dos renglones sueltos que se
-- compensan no cambian ni el saldo ni el auxiliar, y una explicación escrita antes no los cubre)
alter table public.cedula_explicaciones add column if not exists sueltas_abs numeric(14,2);
-- (una cuenta y una fecha, una explicación VIVA; las anteriores quedan)
create unique index if not exists cedula_explicaciones_viva on public.cedula_explicaciones (cuenta, fecha)
  where sustituida_el is null and retirada_el is null;
create index if not exists cedula_explicaciones_cuenta_idx on public.cedula_explicaciones (cuenta, fecha);
comment on table public.cedula_explicaciones is 'c13: por qué una cuenta de balance no cuadra con su auxiliar (o no lo tiene) a una fecha: la cuenta, la fecha, el texto, cómo estaba (estado: no_cuadra o sin_auxiliar) y con qué números se explicó (saldo_libro, saldo_auxiliar, diferencia, en el lado natural de la cuenta; y sueltas_abs, lo que la cuenta tenía sin decir de qué es, en valor absoluto), quién y cuándo. Vale para esa fecha y esos números: si el saldo del libro, el del auxiliar o lo suelto a esa fecha cambian después, la explicación se queda vieja y la cédula lo dice. La viva es la que no está sustituida (otra la reemplazó) ni retirada (con su motivo); las demás quedan. No se edita ni se borra. Se escribe con fn_cedula_explicar y fn_cedula_explicacion_retirar.';


-- ---------------------------------------------------------------------
-- 2. La guarda de las tablas de c13 (la de c6, c9, c10 y c12, en su forma):
--    solo se escriben con la marca de la transacción (mx_cedula.escribe = el
--    nombre de la tabla), que ponen las funciones de aquí justo antes de
--    escribir y quitan después. A mano —desde PostgREST, aunque sea el
--    dueño, o desde el SQL Editor sin la marca— da MX003. Y lo que es rastro
--    no se edita ni se borra. SECURITY INVOKER, sin grant a nadie (la
--    dispara la tabla).
-- ---------------------------------------------------------------------
create or replace function public.fn_cedula_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_marca  text := coalesce(current_setting('mx_cedula.escribe', true), '');
  v_libres text[];
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003',
      message = format('%s no se trunca: es el rastro de la cédula.', tg_table_name);
  end if;
  if tg_op = 'DELETE' then
    raise exception using errcode = 'MX003',
      message = format('%s no se borra: %s', tg_table_name,
                       case tg_table_name
                         when 'cedula_config' then 'es la configuración (una fila); se cambia desde la cédula.'
                         when 'cedula_manual' then 'un renglón se corrige (queda el anterior) o se anula con su motivo.'
                         else 'una explicación se sustituye con otra o se retira con su motivo, y queda.' end);
  end if;
  if v_marca <> tg_table_name then
    raise exception using errcode = 'MX003',
      message = format('%s se escribe solo desde las funciones de la cédula (%s), no a mano.', tg_table_name,
                       case tg_table_name
                         when 'cedula_config' then 'fn_cedula_config'
                         when 'cedula_manual' then 'fn_cedula_renglon y fn_cedula_renglon_anular'
                         else 'fn_cedula_explicar y fn_cedula_explicacion_retirar' end);
  end if;
  if tg_op = 'UPDATE' then
    -- Lo único que le pasa a una fila de rastro: quedar sustituida, anulada o
    -- retirada, una vez. Se compara la fila entera sin esas columnas.
    v_libres := case tg_table_name
                  when 'cedula_manual' then array['sustituido_el', 'anulado_el', 'anulado_por', 'anulado_motivo']
                  when 'cedula_explicaciones' then array['sustituida_el', 'retirada_el', 'retirada_por', 'retirada_motivo']
                  else null end;
    if v_libres is not null then
      if (to_jsonb(new) - v_libres) is distinct from (to_jsonb(old) - v_libres)
         or coalesce(to_jsonb(old)->>v_libres[1], to_jsonb(old)->>v_libres[2]) is not null
         or coalesce(to_jsonb(new)->>v_libres[1], to_jsonb(new)->>v_libres[2]) is null then
        raise exception using errcode = 'MX003',
          message = format('%s no se edita: %s', tg_table_name,
                           case tg_table_name
                             when 'cedula_manual' then 'un renglón solo queda sustituido por su corrección o anulado con su motivo, una vez.'
                             else 'una explicación solo queda sustituida por otra o retirada con su motivo, una vez.' end);
      end if;
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.fn_cedula_guarda() from public, anon, authenticated, service_role;
comment on function public.fn_cedula_guarda() is 'c13: la guarda de las tablas de c13: se escriben solo con la marca de la transacción (mx_cedula.escribe) que ponen sus funciones; un renglón a mano solo queda sustituido o anulado (una vez), una explicación solo queda sustituida o retirada (una vez), y nada se borra.';

do $$
declare
  t text;
begin
  foreach t in array array['cedula_config', 'cedula_manual', 'cedula_explicaciones'] loop
    execute format('create or replace trigger trg_%s_guarda before insert or update or delete on public.%I '
                   'for each row execute function public.fn_cedula_guarda()', t, t);
    execute format('create or replace trigger trg_%s_sin_truncate before truncate on public.%I '
                   'for each statement execute function public.fn_cedula_guarda()', t, t);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 3. Los permisos: RLS, «solo el dueño lee», y la policy de escritura del
--    dueño (con la guarda de arriba delante: la policy dice quién, la marca
--    dice por dónde). anon y service_role, nada. Nadie borra por la API.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array['cedula_config', 'cedula_manual', 'cedula_explicaciones'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('create policy %I on public.%I for update to authenticated using ((select es_dueno())) with check ((select es_dueno()))',
                   t || '_dueno_edita', t);
    execute format('grant update on public.%I to authenticated', t);
  end loop;
  foreach t in array array['cedula_manual', 'cedula_explicaciones'] loop
    execute format('create policy %I on public.%I for insert to authenticated with check ((select es_dueno()))',
                   t || '_dueno_anade', t);
    execute format('grant insert on public.%I to authenticated', t);
  end loop;
end $$;

-- La fila de la configuración (con la marca de la guarda): al volver a pegar
-- no se pisa nada. Nace avisando desde noviembre de 2026 (el corte de la 12b
-- es el 30-nov-2026; si se pegara antes de ese mes, desde el mes en curso):
-- la apertura y octubre no ganan un rojo por ella, y noviembre sí aunque el
-- archivo se pegue en diciembre. El patrimonio, con su mayor.
do $$
begin
  if not exists (select 1 from public.cedula_config where id = 1) then
    perform set_config('mx_cedula.escribe', 'cedula_config', true);
    insert into public.cedula_config (id, avisar_desde, patrimonio)
    values (1, least(to_char(public.fn_fecha_miami(now()), 'YYYY-MM'), '2026-11'), 'mayor');
    perform set_config('mx_cedula.escribe', '', true);
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 4. Lo común: dinero, días y períodos en llano, un monto que llega como
--    texto, qué capas opcionales están, el período que toca. Todo SECURITY
--    INVOKER; lo que usan las funciones de la pantalla y las vistas lleva
--    EXECUTE para authenticated.
-- ---------------------------------------------------------------------
-- Las vistas de c13 se borran aquí y se rehacen al final (en este mismo
-- pegado): así una función que cambie lo que devuelve puede volver a
-- crearse.
drop view if exists public.v_cedula, public.v_cedula_control, public.v_cedula_manual, public.v_cedula_explicaciones, public.v_cedula_qb;

-- Dólares como se leen: $1,234.56 (negativo con su signo).
create or replace function public.fn_cedula_usd(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null then '—'
              when p < 0 then '-$' || to_char(-p, 'FM999,999,999,990.00')
              else '$' || to_char(p, 'FM999,999,999,990.00') end
$$;
revoke execute on function public.fn_cedula_usd(numeric) from public, anon, service_role;
grant  execute on function public.fn_cedula_usd(numeric) to authenticated;
comment on function public.fn_cedula_usd(numeric) is 'c13: un monto en dólares como se lee ($1,234.56).';

-- Un día en corto, con su año: 30-nov-2026.
create or replace function public.fn_cedula_dia(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select extract(day from p)::int || '-'
         || (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int]
         || '-' || extract(year from p)::int
$$;
revoke execute on function public.fn_cedula_dia(date) from public, anon, service_role;
grant  execute on function public.fn_cedula_dia(date) to authenticated;
comment on function public.fn_cedula_dia(date) is 'c13: un día en corto con su año (30-nov-2026).';

-- Un período como se dice: «octubre de 2026», «la apertura», «el año 2026».
create or replace function public.fn_cedula_mes(p_periodo text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p_periodo ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
              then (array['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre',
                          'noviembre', 'diciembre'])[substr(p_periodo, 6, 2)::int] || ' de ' || left(p_periodo, 4)
              when p_periodo ~ '-APERTURA$' then 'la apertura'
              when p_periodo ~ '^[0-9]{4}$' then 'el año ' || p_periodo
              else coalesce(p_periodo, '(sin período)') end
$$;
revoke execute on function public.fn_cedula_mes(text) from public, anon, service_role;
grant  execute on function public.fn_cedula_mes(text) to authenticated;
comment on function public.fn_cedula_mes(text) is 'c13: un período como se dice («octubre de 2026», «la apertura», «el año 2026») a partir de su nombre (2026-10, 2026-09-APERTURA, 2026).';

-- Un monto que llega de la pantalla como texto o número («1250.00»): se mira
-- su escala ANTES de convertirlo, como c2 (numeric(14,2) redondearía
-- callado). El de un renglón a mano puede ir en negativo (lo contrario de lo
-- normal en su cuenta); nunca cero. MX005 con lo que está mal.
create or replace function public.fn_cedula_monto(p_texto text, p_que text) returns numeric
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  v numeric;
begin
  if coalesce(btrim(p_texto), '') = '' then
    raise exception using errcode = 'MX005', message = format('Falta %s.', p_que);
  end if;
  begin
    v := btrim(p_texto)::numeric;
  exception when others then
    raise exception using errcode = 'MX005', message = format('%s: «%s» no es un monto.', initcap(left(p_que, 1)) || substr(p_que, 2), p_texto);
  end;
  if scale(v) is null then  -- NaN o infinito
    raise exception using errcode = 'MX005', message = format('%s: «%s» no es un monto.', initcap(left(p_que, 1)) || substr(p_que, 2), p_texto);
  end if;
  if scale(trim_scale(v)) > 2 then
    raise exception using errcode = 'MX005',
      message = format('%s: %s trae más de dos decimales; el libro va en centavos.', initcap(left(p_que, 1)) || substr(p_que, 2), p_texto);
  end if;
  if v = 0 then
    raise exception using errcode = 'MX005',
      message = format('%s: cero no sostiene nada. Si el renglón ya no está en el saldo, ciérralo con su fecha (hasta) o anúlalo.',
                       initcap(left(p_que, 1)) || substr(p_que, 2));
  end if;
  if abs(v) >= 1000000000000 then
    raise exception using errcode = 'MX005', message = format('%s: %s está fuera de rango.', initcap(left(p_que, 1)) || substr(p_que, 2), p_texto);
  end if;
  return round(v, 2);
end $$;
revoke execute on function public.fn_cedula_monto(text, text) from public, anon, service_role;
grant  execute on function public.fn_cedula_monto(text, text) to authenticated;
comment on function public.fn_cedula_monto(text, text) is 'c13: un monto que llega como texto, validado antes de convertirlo (numérico, hasta dos decimales, distinto de cero, en rango; admite negativo): MX005 con lo que está mal.';

-- QUÉ CAPAS OPCIONALES ESTÁN en esta base, por sus tablas (to_regclass: no
-- lee nada). Todo lo que lee una capa opcional pregunta aquí primero, y la
-- lee al vuelo: c13 no cuelga de ninguna.
--   c4   la comparación con QuickBooks (v_comparacion, v_qb_balanzas)
--   c6   el banco: conciliaciones, préstamos y pólizas
--   c9   el cierre: los activos fijos y su depreciación
--   c12  el WIP: sus ajustes
--   p1   los cobros en línea (Stripe)
create or replace function public.fn_cedula_capas() returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select case when not public.fn_cedula_ve() then '{}'::jsonb else jsonb_build_object(
    'c4',  to_regclass('public.v_comparacion') is not null and to_regclass('public.v_qb_balanzas') is not null,
    'c6',  to_regclass('public.conciliaciones') is not null and to_regclass('public.conciliacion_partidas') is not null
           and to_regclass('public.prestamos') is not null and to_regclass('public.prestamo_cuotas') is not null
           and to_regclass('public.prepagados') is not null and to_regclass('public.prepagados_amortizaciones') is not null,
    'c9',  to_regclass('public.activos_fijos') is not null and to_regclass('public.activos_depreciaciones') is not null,
    'c12', to_regclass('public.wip_ajustes') is not null and to_regclass('public.wip_ajuste_obras') is not null,
    'p1',  to_regclass('public.stripe_config') is not null and to_regclass('public.stripe_pagos') is not null
           and to_regclass('public.stripe_payouts') is not null and to_regclass('public.stripe_payout_lineas') is not null
           and to_regclass('public.v_stripe_pagos') is not null) end
$$;
revoke execute on function public.fn_cedula_capas() from public, anon, service_role;
grant  execute on function public.fn_cedula_capas() to authenticated;
comment on function public.fn_cedula_capas() is 'c13: qué capas opcionales están en esta base ({"c4", "c6", "c9", "c12", "p1"}: verdadero o falso), por sus tablas y vistas. La cédula las lee al vuelo solo si están; si una falta, sus cuentas salen sin auxiliar con ese porqué. A quien no es el dueño, nada ({}).';

-- EL PERÍODO QUE TOCA: el mes (o la apertura) abierto más viejo que ya
-- terminó —el que se está cerrando—; si no hay ninguno, el último cerrado;
-- si tampoco, nada (y la cédula sin fecha es la de hoy). Hora de Miami.
create or replace function public.fn_cedula_toca() returns text
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(
    (select p.periodo from public.periodos p
      where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.hasta < public.fn_fecha_miami(now())
      order by p.desde limit 1),
    (select p.periodo from public.periodos p
      where p.tipo in ('mes', 'apertura') and p.estado = 'cerrado'
      order by p.desde desc limit 1))
$$;
revoke execute on function public.fn_cedula_toca() from public, anon, service_role;
grant  execute on function public.fn_cedula_toca() to authenticated;
comment on function public.fn_cedula_toca() is 'c13: el período que toca: el mes (o la apertura) abierto más viejo que ya terminó (el que se está cerrando); si no hay, el último cerrado; si tampoco, nulo (hora de Miami). La cédula sin fecha es la de su último día.';


-- ---------------------------------------------------------------------
-- 5. LO QUE SE LEE: de dónde sale el auxiliar de cada cuenta, sus renglones
--    a una fecha, la cédula (una fila por cuenta), sus totales y la cédula
--    al lado de QuickBooks. Todo SECURITY INVOKER y solo lectura: lee con la
--    policy de quien llama, y a quien no es el dueño no le devuelve nada
--    (fn_cedula_ve). Las que devuelven una tabla se borran y se rehacen:
--    «create or replace» no cambia las columnas de lo que devuelve (las
--    vistas que las leen se borraron arriba).
-- ---------------------------------------------------------------------
-- DE DÓNDE SALE EL AUXILIAR DE CADA CUENTA DE BALANCE (cabecera). Una fila
-- por cuenta imputable de activo, pasivo o patrimonio (la de grupo, 2100,
-- no tiene saldo propio y no sale):
--   cuenta, nombre, tipo, activa
--   signo        1 si su saldo normal es deudor, −1 si es acreedor: pasa del
--                lado natural a debe − haber
--   fuente       de dónde sale su auxiliar automático: conciliacion |
--                partidas | prestamos | prepagados | activos | depreciacion |
--                wip | stripe | stripe_paso | dr15 | devengos | mayor |
--                nomina | manual (los dos últimos no tienen automático)
--   forma        dentro de «partidas»: cobrar (por factura) o pagar (por
--                proveedor o empleado)
--   auxiliar     su nombre en llano; origen, de dónde sale, en llano
--   capa         la capa que lo lleva (c6, c9, c12, p1) o nulo; capa_esta
--   hay          su auxiliar automático tiene con qué: una conciliación
--                confirmada, un préstamo, una póliza, un activo… (los que
--                salen del libro, siempre); vacio dice qué falta si no
--   par          en un préstamo, la otra cuenta del mismo (corriente ↔ largo
--                plazo)
-- La regla, en orden: Stripe (las cuentas de su configuración); el WIP
-- (1200, 2400, 2410); 1590; las demás 15xx; las cuentas de los préstamos y
-- toda 25xx; las de las pólizas y 1410, 1420; la caja chica (la del
-- efectivo de c3: a mano, su arqueo); un banco (10xx de activo, deudora,
-- sin obra) o una tarjeta (2100-XXXX de la tabla tarjetas); las cuentas de
-- los puentes de c3 (cobrar, retención, pagar, reembolsos) y 2020; el use
-- tax; 2050 y los sueldos devengados; el resto de 22xx (la nómina); el
-- patrimonio; y lo demás, a mano.
drop function if exists public.fn_cedula_cuentas();
create function public.fn_cedula_cuentas()
returns table (cuenta text, nombre text, tipo text, activa boolean, signo int, fuente text, forma text, auxiliar text, origen text,
               capa text, capa_esta boolean, hay boolean, vacio text, par text)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_capas   jsonb := fn_cedula_capas();
  v_c6      boolean;
  v_c9      boolean;
  v_c12     boolean;
  v_p1      boolean;
  v_patr    text;
  v_caja    text;
  v_efe     text;               -- la cuenta del método «efectivo» de c3, tal cual (la que el banco, c6, toma por la caja chica)
  v_cxc     text;
  v_ret     text;
  v_cxp     text;
  v_remp    text;
  v_rdue    text;
  v_utax    text;
  v_sdev    text;
  v_puente  text := '1020';
  v_paso    text := '1140';
  v_prest   text[] := '{}';     -- cuentas con un préstamo vivo
  v_pares   jsonb  := '{}'::jsonb;
  v_prep    text[] := '{}';     -- cuentas con una póliza
  v_conc    text[] := '{}';     -- cuentas con una conciliación confirmada
  v_act     text[] := '{}';     -- cuentas con un activo
  v_banco   text[] := '{}';     -- cuentas que el banco trae (con movimientos importados)
  v_err     jsonb  := '{}'::jsonb;  -- {capa: por qué no se pudo leer}
begin
  if not fn_cedula_ve() then
    return;
  end if;
  v_c6  := coalesce((v_capas->>'c6')::boolean, false);
  v_c9  := coalesce((v_capas->>'c9')::boolean, false);
  v_c12 := coalesce((v_capas->>'c12')::boolean, false);
  v_p1  := coalesce((v_capas->>'p1')::boolean, false);
  select coalesce((select c.patrimonio from cedula_config c where c.id = 1), 'mayor') into v_patr;
  -- Lo de c3: la caja chica y las cuentas de sus puentes (con las de c1 si
  -- una regla falta).
  v_caja := coalesce((select m.cuenta from mapeo_metodo_pago m where m.forma = 'efectivo' and m.cuenta is not null
                       order by m.confirmado_el desc nulls last limit 1), '1050');
  select coalesce(max(pc.cuenta) filter (where pc.rol = 'cxc'), '1110'),
         coalesce(max(pc.cuenta) filter (where pc.rol = 'retencion_cxc'), '1120'),
         coalesce(max(pc.cuenta) filter (where pc.rol = 'cxp'), '2010'),
         coalesce(max(pc.cuenta) filter (where pc.rol = 'reembolso_empleado'), '2250'),
         coalesce(max(pc.cuenta) filter (where pc.rol = 'reembolso_dueno'), '2900'),
         coalesce(max(pc.cuenta) filter (where pc.rol = 'use_tax'), '2300'),
         coalesce(max(pc.cuenta) filter (where pc.rol = 'sueldos_devengados'), '2210')
    into v_cxc, v_ret, v_cxp, v_remp, v_rdue, v_utax, v_sdev
    from puente_cuentas pc;
  -- Lo de las capas opcionales, al vuelo. Si una no se puede leer (cambió de
  -- forma), sus cuentas salen sin auxiliar con ese porqué y lo demás sigue.
  if v_p1 then
    begin
      execute 'select c.cuenta_puente, c.cuenta_paso from public.stripe_config c where c.id = 1' into v_puente, v_paso;
      v_puente := coalesce(v_puente, '1020');
      v_paso   := coalesce(v_paso, '1140');
    exception when others then
      v_err := v_err || jsonb_build_object('p1', sqlerrm);
    end;
  end if;
  if v_c6 then
    begin
      execute 'select coalesce(array_agg(distinct x.c), ''{}''), '
           || 'coalesce(jsonb_object_agg(x.c, x.o) filter (where x.o is not null and x.o <> x.c), ''{}''::jsonb) '
           || 'from public.prestamos p cross join lateral (values (p.cuenta, p.cuenta_largo), (p.cuenta_largo, p.cuenta)) x(c, o) '
           || 'where p.estado <> ''cancelado'' and x.c is not null'
         into v_prest, v_pares;
      execute 'select coalesce(array_agg(distinct p.cuenta), ''{}'') from public.prepagados p' into v_prep;
      execute 'select coalesce(array_agg(distinct c.cuenta), ''{}'') from public.conciliaciones c where c.estado = ''confirmada''' into v_conc;
    exception when others then
      v_err := v_err || jsonb_build_object('c6', sqlerrm);
    end;
  end if;
  if v_c9 then
    begin
      execute 'select coalesce(array_agg(distinct a.cuenta), ''{}'') from public.activos_fijos a' into v_act;
    exception when others then
      v_err := v_err || jsonb_build_object('c9', sqlerrm);
    end;
  end if;
  -- LA CAJA es la cuenta del efectivo de c3 SOLO SI EL BANCO NO LA TRAE: una cuenta con un estado de cuenta importado,
  -- con movimientos del banco o con una conciliación se concilia con su statement, diga lo que diga el método «efectivo»
  -- (si alguien lo apuntó al banco operativo, el banco sigue siendo un banco, y la fila lo avisa). Entonces la caja es la
  -- caja chica de siempre (1050), si esa tampoco la trae el banco; y si también, no hay caja: las dos se concilian.
  -- (Mientras el banco no traiga nada de esa cuenta, la cédula sigue a c6: la del método «efectivo» es la caja, porque
  -- Conciliar no deja conciliarla —«no tiene estado de cuenta»— y la cédula no manda a hacer lo que el banco rechaza.)
  v_efe := v_caja;
  if v_c6 and not (v_err ? 'c6') then
    begin
      execute 'select coalesce(array_agg(distinct x.cuenta), ''{}'') '
           || 'from (select m.cuenta from public.movimientos_banco m union select a.cuenta from public.archivos_banco a) x '
           || 'where x.cuenta is not null' into v_banco;
    exception when others then
      v_banco := '{}';
    end;
    if v_caja = any (v_banco || v_conc) then
      v_caja := case when '1050' = any (v_banco || v_conc) then null else '1050' end;
    end if;
  end if;

  return query
  with k as (
    select c.codigo, c.nombre, c.tipo, coalesce((to_jsonb(c)->>'activa')::boolean, true) as activa,
           case when c.saldo_normal = 'debe' then 1 else -1 end as signo,
           (left(c.codigo, 2) = '10' and c.tipo = 'activo' and c.saldo_normal = 'debe' and c.regla_obra = 'prohibida') as es_banco,
           (c.tipo = 'pasivo' and c.saldo_normal = 'haber' and left(c.codigo, 5) = '2100-'
            and exists (select 1 from tarjetas t where t.cuenta = c.codigo)) as es_tarjeta,
           -- (una subcuenta de tarjetas que nadie dio de alta como tarjeta de la empresa: c6 no la concilia)
           (c.tipo = 'pasivo' and c.saldo_normal = 'haber' and left(c.codigo, 5) = '2100-'
            and not exists (select 1 from tarjetas t where t.cuenta = c.codigo)) as tarjeta_sin_alta
      from cuentas c
     where c.tipo in ('activo', 'pasivo', 'capital') and c.imputable),
  f as (
    select k.*,
           case when k.codigo = v_puente then 'stripe'
                when k.codigo = v_paso then 'stripe_paso'
                when k.codigo in ('1200', '2400', '2410') then 'wip'
                when k.codigo = '1590' then 'depreciacion'
                when k.codigo ~ '^15[0-9]{2}' then 'activos'
                when k.codigo = any (v_prest) or (k.tipo = 'pasivo' and k.codigo ~ '^25[0-9]{2}') then 'prestamos'
                when k.codigo = any (v_prep) or k.codigo in ('1410', '1420') then 'prepagados'
                when k.codigo is not distinct from v_caja then 'manual'
                when k.es_banco or k.es_tarjeta then 'conciliacion'
                when k.codigo in (v_cxc, v_ret, v_cxp, v_remp, v_rdue, '2020') then 'partidas'
                when k.codigo = v_utax then 'dr15'
                when k.codigo in ('2050', v_sdev) then 'devengos'
                when k.tipo = 'pasivo' and k.codigo ~ '^22[0-9]{2}' then 'nomina'
                when k.tipo = 'capital' and v_patr = 'mayor' then 'mayor'
                else 'manual' end as fuente
      from k),
  g as (
    select f.*,
           case f.fuente when 'conciliacion' then 'c6' when 'prestamos' then 'c6' when 'prepagados' then 'c6'
                         when 'activos' then 'c9' when 'depreciacion' then 'c9' when 'wip' then 'c12'
                         when 'stripe' then 'p1' when 'stripe_paso' then 'p1' end as capa
      from f)
  select g.codigo, g.nombre, g.tipo, g.activa, g.signo, g.fuente,
         (case when g.fuente <> 'partidas' then null when g.codigo in (v_cxc, v_ret) then 'cobrar' else 'pagar' end),
         -- el nombre del auxiliar, en llano
         (case g.fuente
            when 'conciliacion' then case when g.es_tarjeta then 'El statement de la tarjeta, conciliado' else 'El estado de cuenta, conciliado' end
            when 'partidas' then case when g.codigo = v_cxc then 'Las facturas por cobrar, una por una'
                                      when g.codigo = v_ret then 'La retención por cobrar, por obra y factura'
                                      when g.codigo = v_cxp then 'Lo que se le debe a cada proveedor'
                                      when g.codigo = v_remp then 'Lo que se le debe a cada empleado'
                                      when g.codigo = v_rdue then 'Los recibos que Edgar pagó de su bolsillo'
                                      else 'La retención por pagar a cada subcontratista' end
            when 'prestamos' then 'Los préstamos, uno por uno'
            when 'prepagados' then 'Las pólizas pagadas por adelantado'
            when 'activos' then 'Los activos fijos, uno por uno'
            when 'depreciacion' then 'La depreciación acumulada de cada activo'
            when 'wip' then 'El WIP por obra'
            when 'stripe' then 'Lo cobrado en línea que falta depositar'
            when 'stripe_paso' then 'Los depósitos de Stripe en camino'
            when 'dr15' then 'El use tax por mes'
            when 'devengos' then case when g.codigo = v_sdev then 'El devengo de las horas aprobadas' else 'Los devengos del cierre, uno por uno' end
            when 'mayor' then 'Su propio mayor'
            when 'nomina' then 'El diario de la nómina'
            else case when g.codigo is not distinct from v_caja then 'El arqueo de caja' else 'Renglones escritos a mano' end end),
         -- de dónde sale, en llano
         (case g.fuente
            when 'conciliacion' then 'La conciliación confirmada en Conciliar: lo que dice el statement, más los depósitos en tránsito, menos los cheques y cargos en circulación.'
                 || case when g.codigo = v_efe and v_efe is distinct from v_caja
                         then ' OJO: la forma de pago «efectivo» de los recibos apunta a esta cuenta, y el banco la trae: aquí sigue siendo un banco, pero Conciliar la toma por la caja chica y no deja conciliarla hasta que el efectivo vuelva a su cuenta (la caja chica, 1050).'
                         else '' end
            when 'partidas' then case when g.codigo = v_cxc then 'Las partidas abiertas del libro: cada factura con lo que le falta por cobrar, y cada anticipo de un cliente.'
                                      when g.codigo = v_ret then 'Las partidas abiertas del libro: lo retenido de cada factura, en su obra.'
                                      when g.codigo = v_cxp then 'Las partidas abiertas del libro por proveedor (tickets a cuenta y trabajos sin pagar). Es lo que se compara A MANO con el statement de cada supply: la cédula no lo hace.'
                                      when g.codigo = v_remp then 'Las partidas abiertas del libro por empleado: lo que pagó de su bolsillo y no se le ha devuelto.'
                                      when g.codigo = v_rdue then 'Las partidas abiertas del libro: cada recibo que Edgar pagó de su bolsillo y sigue sin reembolsar. Lo demás (lo que venía de QuickBooks, una nota firmada) se escribe a mano.'
                                      else 'Las partidas del libro por subcontratista. Lo que se retenga sin decir a quién se escribe a mano.' end
            when 'prestamos' then 'Cada préstamo registrado en Bancos: lo que se debía al empezar menos el capital de cada cuota, partido en lo que vence en un año (corriente) y el resto (largo plazo).'
            when 'prepagados' then 'Cada póliza o fianza registrada como pagada por adelantado: lo que le falta por pasar al gasto.'
            when 'activos' then 'Cada activo dado de alta en Cierre, por su costo.'
            when 'depreciacion' then 'De cada activo: lo depreciado antes del libro más la depreciación posteada cada mes.'
            when 'wip' then 'El ajuste de WIP posteado que está en vigor ese día, obra por obra.'
            when 'stripe' then 'Cada cobro en línea que Stripe todavía no ha depositado en el banco (Cobros en línea).'
            when 'stripe_paso' then 'Es una cuenta de paso entre Stripe y el banco: debe estar en cero.'
            when 'dr15' then 'Lo devengado y lo pagado de use tax cada mes, del propio libro (y lo que trajo la apertura): dice de qué mes es cada saldo, no lo compara con nada. Para compararlo, escribe a mano lo que dice cada DR-15 presentado (con su número de confirmación): entonces la cuenta se compara con eso.'
            when 'devengos' then case when g.codigo = v_sdev then 'El asiento de devengo de las horas aprobadas que sigue vivo (se deshace solo el día 1). La nómina devengada de verdad llega con la nómina (f11).'
                                      else 'Cada asiento de devengo que sigue vivo (se deshace solo el día 1 del mes siguiente). Lo demás se escribe a mano.' end
            when 'mayor' then 'Lo que trajo la apertura (la balanza de QuickBooks) más cada asiento posterior, mes por mes: es el propio libro, ordenado; no lo compara con nada. Lo amarra la comparación con QuickBooks; y si se escriben a mano sus renglones (el acta, la declaración), se compara con eso.'
            when 'nomina' then 'Llega con la nómina (f11): el diario de Gusto. Mientras, lo que tenga se escribe a mano.'
            else case when g.codigo is not distinct from v_caja then 'El efectivo contado, escrito a mano con su fecha.'
                      when g.tarjeta_sin_alta then 'Es una subcuenta de tarjetas que todavía no está dada de alta como tarjeta de la empresa: sin su alta no se concilia en Conciliar. Mientras, lo que dice su statement se escribe a mano.'
                      else 'La base no lo sabe: lo que Edgar escribe (qué es, cuánto, con qué documento).' end end),
         g.capa,
         (case g.capa when 'c6' then v_c6 when 'c9' then v_c9 when 'c12' then v_c12 when 'p1' then v_p1 else true end),
         -- ¿su auxiliar automático tiene con qué?
         (case when g.capa is not null and v_err ? g.capa then false
               when g.fuente = 'conciliacion' then v_c6 and g.codigo = any (v_conc)
               when g.fuente = 'prestamos' then v_c6 and g.codigo = any (v_prest)
               when g.fuente = 'prepagados' then v_c6 and g.codigo = any (v_prep)
               when g.fuente = 'activos' then v_c9 and g.codigo = any (v_act)
               when g.fuente = 'depreciacion' then v_c9 and cardinality(v_act) > 0
               when g.fuente = 'wip' then v_c12
               when g.fuente in ('stripe', 'stripe_paso') then v_p1
               when g.fuente in ('manual', 'nomina') then false
               else true end),
         -- por qué no, en llano (nulo si lo tiene)
         (case when g.capa = 'c6' and not v_c6 then 'la parte del banco (c6) no está en esta base'
               when g.capa = 'c9' and not v_c9 then 'la parte del cierre y los activos (c9) no está en esta base'
               when g.capa = 'c12' and not v_c12 then 'la parte del WIP (c12) no está en esta base'
               when g.capa = 'p1' and not v_p1 then 'la parte de los cobros en línea (p1) no está en esta base'
               when g.capa is not null and v_err ? g.capa then 'no se pudo leer su auxiliar (' || left(v_err->>g.capa, 160) || ')'
               when g.fuente = 'conciliacion' and not g.codigo = any (v_conc) then 'todavía no tiene ninguna conciliación confirmada'
               when g.fuente = 'prestamos' and not g.codigo = any (v_prest) then 'no hay ningún préstamo registrado en esta cuenta'
               when g.fuente = 'prepagados' and not g.codigo = any (v_prep) then 'no hay ninguna póliza registrada en esta cuenta'
               when g.fuente = 'activos' and not g.codigo = any (v_act) then 'todavía no hay activos fijos cargados en esta cuenta (llegan con la cédula del contador)'
               when g.fuente = 'depreciacion' and cardinality(v_act) = 0 then 'todavía no hay activos fijos cargados (llegan con la cédula del contador)'
               when g.fuente = 'nomina' then 'llega con la nómina (f11)'
               when g.fuente = 'manual' then case when g.codigo is not distinct from v_caja then 'se cuenta el efectivo y se escribe a mano'
                                                  when g.tarjeta_sin_alta then 'es una tarjeta que no está dada de alta (sin su alta no se concilia); mientras, su statement se escribe a mano'
                                                  else 'la base no lo sabe: se escribe a mano' end
          end),
         (case when g.fuente = 'prestamos' then v_pares->>g.codigo end)
    from g
   order by g.codigo;
end $$;
revoke execute on function public.fn_cedula_cuentas() from public, anon, service_role;
grant  execute on function public.fn_cedula_cuentas() to authenticated;
comment on function public.fn_cedula_cuentas() is 'c13: de dónde sale el auxiliar de cada cuenta de balance (activo, pasivo y patrimonio, imputable): su signo (1 deudora, −1 acreedora), la fuente de su auxiliar automático (conciliacion, partidas, prestamos, prepagados, activos, depreciacion, wip, stripe, stripe_paso, dr15, devengos, mayor; nomina y manual no lo tienen), su nombre y su origen en llano, la capa que lo lleva y si está, si tiene con qué (hay) y, si no, por qué (vacio), y en un préstamo la otra cuenta del par. La regla sale de lo que la cuenta es (un banco, una tarjeta, la cuenta de un puente de c3, de un préstamo, de una póliza), no de una lista fija. La caja chica es la cuenta de la forma de pago «efectivo» de c3, salvo que el banco la traiga (un estado de cuenta importado, movimientos o una conciliación): entonces sigue siendo un banco, su origen lo avisa, y la caja es la 1050. Solo lectura; a quien no es el dueño, nada.';

-- LOS RENGLONES DEL AUXILIAR de cada cuenta (o de una) a una fecha: lo que
-- hay DEBAJO de cada saldo. Es de donde la cédula saca lo que suma el
-- auxiliar, y lo que la pantalla enseña al tocar una cuenta. Las columnas:
--   cuenta, n        la cuenta y el orden del renglón dentro de ella
--   clase            'auxiliar'  un renglón del auxiliar (su monto suma)
--                    'libro'     un renglón que sale del PROPIO LIBRO,
--                                ordenado (el patrimonio: la apertura y cada
--                                mes; el use tax por mes). Es el auxiliar de
--                                su cuenta solo mientras nadie le escriba
--                                renglones a mano: con ellos, se compara con
--                                ellos y estos quedan como detalle
--                    'suelto'    lo que el libro tiene en la cuenta sin decir
--                                de qué es (sin factura, sin proveedor, o
--                                que no es un devengo vivo): no es auxiliar;
--                                va en «libro» y es parte de la diferencia
--                    'despues'   (bancos y tarjetas) lo que el libro movió
--                                después de la última conciliación
--                                confirmada, hasta la fecha; (pólizas) lo
--                                que movió después del día sin ser de una
--                                póliza: va en «libro»
--                    'error'     su auxiliar no se pudo leer (concepto dice
--                                por qué)
--                    'dato'      algo que se enseña al lado y no suma ni se
--                                compara: en la reserva de impuestos (1030),
--                                lo que el cierre dice que debería haber.
--                                Solo sale al pedir esa cuenta
--   fuente           de dónde sale: la de fn_cedula_cuentas, o 'manual'
--   clave            lo que identifica el renglón (el id de la factura, del
--                    préstamo, del activo, del renglón a mano…)
--   grupo            la obra (de la factura; de lo suelto en las cuentas por
--                    cobrar), o «proveedor» / «empleado»
--   concepto, referencia, fecha, nota   lo que es, en llano
--   monto            lo que el auxiliar dice, en el lado natural de la cuenta
--   libro            lo que el libro tiene para ESE renglón, cuando se puede
--                    comparar uno a uno (el WIP por obra) y en las clases
--                    'suelto' y 'despues'; si no, nulo
--   ok               solo donde hay «libro» uno a uno: si coinciden
--   ref_tabla, ref_id  el papel o la fila que hay detrás (para bajar a él)
-- Sin fecha, la del período que toca. Cada capa opcional se lee en su
-- bloque, entera o nada: si una falla, sus cuentas llevan un renglón 'error'
-- y lo demás sigue.
drop function if exists public.fn_cedula_partidas(date, text);
create function public.fn_cedula_partidas(p_fecha date default null, p_cuenta text default null)
returns table (cuenta text, n int, clase text, fuente text, clave text, grupo text, concepto text, referencia text, fecha date,
               monto numeric(14,2), libro numeric(14,2), ok boolean, nota text, ref_tabla text, ref_id text)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  c_uuid  constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
  c_int   constant text := '^-?[0-9]{1,18}$';
  v_f     date;
  v_hoy   date := fn_fecha_miami(now());
  v_cat   jsonb;                  -- {cuenta: {f: fuente, m: forma, s: signo, ok: su capa está}}
  v_all   jsonb := '[]'::jsonb;
  v_j     jsonb;
  v_ctas  text[];
begin
  if not fn_cedula_ve() then
    return;
  end if;
  v_f := coalesce(p_fecha, (select q.hasta from periodos q where q.periodo = fn_cedula_toca()), v_hoy);
  select coalesce(jsonb_object_agg(c.cuenta, jsonb_build_object('f', c.fuente, 'm', c.forma, 's', c.signo, 'ok', c.capa_esta)), '{}'::jsonb)
    into v_cat
    from fn_cedula_cuentas() c
   where p_cuenta is null or c.cuenta = p_cuenta;
  if v_cat = '{}'::jsonb then
    return;
  end if;

  -- (A) LAS PARTIDAS ABIERTAS DEL LIBRO (c2 y c3): por cobrar, por factura o
  --     anticipo; por pagar, por proveedor o empleado (y, sin él, por papel).
  --     Lo que la cuenta tiene sin decir de qué es va suelto: en las de
  --     cobrar, POR OBRA (así llega de QuickBooks el saldo de la apertura:
  --     por Customer:Job, sin sus facturas; es como lo enseña la antigüedad
  --     de c4); en las de pagar, en un renglón.
  v_ctas := array(select e.key from jsonb_each(v_cat) e where e.value->>'f' = 'partidas');
  if cardinality(v_ctas) > 0 then
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_j
      from (
        with g as materialized (
               select l.cuenta, l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id,
                      case when v_cat->l.cuenta->>'m' = 'cobrar' and l.partida_tabla is null then coalesce(l.proyecto_id, '') end as obra,
                      sum(l.monto) as s, min(a.fecha_contable) as desde, count(*) as lineas
                 from asiento_lineas l
                 join asientos a on a.id = l.asiento_id
                where l.cuenta = any (v_ctas) and a.fecha_contable <= v_f
                group by 1, 2, 3, 4, 5, 6),
             h as (
               -- la llave del renglón: en las de cobrar, la partida (la factura, el anticipo); en las de pagar, a quién
               -- (el proveedor o el empleado) y, sin él, el papel; lo que no dice ni lo uno ni lo otro va suelto
               -- (en las de cobrar, con su obra)
               select g.cuenta, m.modo,
                      case m.modo when 't' then g.tercero_tipo when 'p' then g.partida_tabla else case when g.obra is not null then 'obra' end end as k1,
                      case m.modo when 't' then g.tercero_id when 'p' then g.partida_id else g.obra end as k2,
                      sum(g.s) as s, min(g.desde) as desde, sum(g.lineas) as lineas,
                      count(*) filter (where g.partida_tabla is not null and g.s <> 0) as papeles
                 from g
                cross join lateral (select case when v_cat->g.cuenta->>'m' = 'cobrar'
                                                then case when g.partida_tabla is not null then 'p' end
                                                else case when g.tercero_tipo is not null then 't'
                                                          when g.partida_tabla is not null then 'p' end end as modo) m
                group by 1, 2, 3, 4)
        select h.cuenta,
               case when h.modo is null then 9 else 1 end as o,
               case when h.modo is null then 'suelto' else 'auxiliar' end as clase,
               'partidas'::text as fuente,
               case when h.modo is null then 'suelto' || coalesce(':' || nullif(h.k2, ''), '') else h.k1 || ':' || h.k2 end as clave,
               case when h.modo = 't' then h.k1
                    when h.modo is null and h.k1 = 'obra' then coalesce(so.nombre, nullif(h.k2, ''), 'Sin obra')
                    when h.k1 = 'facturas' then fo.nombre end as grupo,
               case when h.modo is null and v_cat->h.cuenta->>'m' = 'cobrar'
                      then 'Sin factura ni anticipo: lo que el libro tiene en esta cuenta sin decir de qué factura es'
                    when h.modo is null
                      then 'Sin proveedor ni papel: lo que el libro tiene en esta cuenta sin decir a quién se le debe'
                    when h.k1 = 'facturas' then coalesce('Factura #' || f.num, 'La factura ' || h.k2 || ' (ya no está en la app)')
                    when h.k1 = 'cobros' then 'Anticipo: el cobro' || coalesce(' del ' || fn_cedula_dia(cb.fecha), ' ' || h.k2)
                                              || coalesce(' (' || nullif(btrim(cb.referencia), '') || ')', '')
                    when h.k1 = 'proveedor' then coalesce(pr.nombre, 'El proveedor ' || h.k2 || ' (ya no está)')
                    when h.k1 = 'empleado' then coalesce(pf.nombre, 'El empleado ' || h.k2 || ' (ya no está)')
                    when h.k1 = 'recibos' then 'Recibo ' || h.k2 || coalesce(' · ' || nullif(btrim(rc.proveedor), ''), '')
                    when h.k1 = 'trabajos_externos' then coalesce(nullif(btrim(te.descripcion), ''), 'Trabajo externo ' || h.k2)
                    else h.k1 || ' ' || h.k2 end as concepto,
               case when h.k1 = 'facturas' then f.num end as referencia,
               coalesce(f.fecha, cb.fecha, rc.fecha, te.fecha, h.desde) as fecha,
               case when h.modo is not null then ((v_cat->h.cuenta->>'s')::int * h.s)::numeric(14,2) end as monto,
               case when h.modo is null then ((v_cat->h.cuenta->>'s')::int * h.s)::numeric(14,2) end as libro,
               null::boolean as ok,
               case when h.modo is null then format('%s línea(s)', h.lineas)
                    when h.modo = 't' and h.papeles > 0 then format('%s papel(es) abierto(s)', h.papeles) end as nota,
               case when h.modo = 't' then case h.k1 when 'proveedor' then 'proveedores' else 'perfiles' end
                    when h.modo = 'p' then h.k1
                    when h.k1 = 'obra' and nullif(h.k2, '') is not null then 'proyectos' end as ref_tabla,
               case when h.modo is null then nullif(h.k2, '') else h.k2 end as ref_id
          from h
          left join proyectos so on so.id = (case when h.modo is null and h.k1 = 'obra' then nullif(h.k2, '') end)
          left join facturas f
                 on f.id = (case when h.modo = 'p' and h.k1 = 'facturas' and h.k2 ~ c_int then h.k2::bigint end)
          left join proyectos fo on fo.id = f.proyecto_id
          left join cobros cb
                 on cb.id = (case when h.modo = 'p' and h.k1 = 'cobros' and h.k2 ~ c_uuid then h.k2::uuid end)
          left join recibos rc
                 on rc.id = (case when h.modo = 'p' and h.k1 = 'recibos' and h.k2 ~ c_int then h.k2::bigint end)
          left join trabajos_externos te
                 on te.id = (case when h.modo = 'p' and h.k1 = 'trabajos_externos' and h.k2 ~ c_int then h.k2::bigint end)
          left join proveedores pr
                 on pr.id = (case when h.modo = 't' and h.k1 = 'proveedor' and h.k2 ~ c_uuid then h.k2::uuid end)
          left join perfiles pf
                 on pf.id = (case when h.modo = 't' and h.k1 = 'empleado' and h.k2 ~ c_uuid then h.k2::uuid end)
         where h.s <> 0) x;
    v_all := v_all || v_j;
  end if;

  -- (B) LO QUE SALE DEL PROPIO LIBRO, ORDENADO: el patrimonio (lo que trajo
  --     la apertura, los ajustes del contador y los movimientos de cada mes)
  --     y el use tax (lo devengado y lo pagado de cada mes).
  v_ctas := array(select e.key from jsonb_each(v_cat) e where e.value->>'f' in ('mayor', 'dr15'));
  if cardinality(v_ctas) > 0 then
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_j
      from (
        select m.cuenta, m.o, 'libro'::text as clase, (v_cat->m.cuenta->>'f') as fuente, m.k as clave, null::text as grupo,
               case when m.k = 'apertura' then 'Lo que trajo la apertura (la balanza de QuickBooks)'
                    when m.k = 'ajuste_cpa' then 'Ajustes del contador'
                    when v_cat->m.cuenta->>'f' = 'dr15'
                      then format('Use tax de %s: devengado %s, pagado %s', fn_cedula_mes(m.k), fn_cedula_usd(m.haber), fn_cedula_usd(m.debe))
                    else 'Movimientos de ' || fn_cedula_mes(m.k) end as concepto,
               null::text as referencia, m.hasta as fecha,
               ((v_cat->m.cuenta->>'s')::int * m.s)::numeric(14,2) as monto, null::numeric as libro, null::boolean as ok,
               format('%s asiento(s)', m.asientos) as nota, null::text as ref_tabla, null::text as ref_id
          from (select l.cuenta,
                       case a.tipo when 'apertura' then 'apertura' when 'ajuste_cpa' then 'ajuste_cpa' else a.periodo end as k,
                       case a.tipo when 'apertura' then 1 when 'ajuste_cpa' then 3 else 2 end as o,
                       sum(l.monto) as s, coalesce(sum(l.monto) filter (where l.monto > 0), 0) as debe,
                       coalesce(-sum(l.monto) filter (where l.monto < 0), 0) as haber,
                       max(a.fecha_contable) as hasta, count(distinct a.id) as asientos
                  from asiento_lineas l
                  join asientos a on a.id = l.asiento_id
                 where l.cuenta = any (v_ctas) and a.fecha_contable <= v_f
                 group by 1, 2, 3) m
         where m.s <> 0 or v_cat->m.cuenta->>'f' = 'dr15') x;
    v_all := v_all || v_j;
  end if;

  -- (C) LOS DEVENGOS VIVOS (c2): cada asiento reversible que a esa fecha
  --     todavía no se ha deshecho (ni por su reverso del día 1 ni por una
  --     corrección). Lo demás de la cuenta va suelto.
  v_ctas := array(select e.key from jsonb_each(v_cat) e where e.value->>'f' = 'devengos');
  if cardinality(v_ctas) > 0 then
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_j
      from (
        with vivos as materialized (
               select l.cuenta, a.id, a.numero, a.descripcion, a.fecha_contable, sum(l.monto) as s
                 from asiento_lineas l
                 join asientos a on a.id = l.asiento_id
                where l.cuenta = any (v_ctas) and a.reversible and a.fecha_contable <= v_f
                  and not exists (select 1 from asientos r where r.reversa_a = a.id and r.fecha_contable <= v_f)
                group by l.cuenta, a.id, a.numero, a.descripcion, a.fecha_contable
               having sum(l.monto) <> 0),
             tot as (
               select l.cuenta, sum(l.monto) as s
                 from asiento_lineas l
                 join asientos a on a.id = l.asiento_id
                where l.cuenta = any (v_ctas) and a.fecha_contable <= v_f
                group by l.cuenta)
        select v.cuenta, 1 as o, 'auxiliar'::text as clase, 'devengos'::text as fuente, v.id::text as clave, null::text as grupo,
               left(v.descripcion, 200) as concepto, v.numero as referencia, v.fecha_contable as fecha,
               ((v_cat->v.cuenta->>'s')::int * v.s)::numeric(14,2) as monto, null::numeric as libro, null::boolean as ok,
               'Se deshace solo el día 1 del mes siguiente'::text as nota, 'asientos'::text as ref_tabla, v.id::text as ref_id
          from vivos v
        union all
        select t.cuenta, 9, 'suelto', 'devengos', 'suelto', null,
               'Lo demás de la cuenta: no es un devengo que se deshaga solo', null, null, null,
               ((v_cat->t.cuenta->>'s')::int * (t.s - coalesce((select sum(v.s) from vivos v where v.cuenta = t.cuenta), 0)))::numeric(14,2),
               null, null, null, null
          from tot t
         where t.s - coalesce((select sum(v.s) from vivos v where v.cuenta = t.cuenta), 0) <> 0) x;
    v_all := v_all || v_j;
  end if;

  -- (D) BANCOS Y TARJETAS (c6): la conciliación confirmada que cubre el día
  --     (la de ese día o la primera posterior; lo que el libro movió entre el
  --     día y su corte se le quita) o, si no hay, la última anterior (y lo de
  --     después va aparte, clase 'despues'). Sus renglones: lo que dice el
  --     statement y cada partida de la conciliación.
  v_ctas := array(select e.key from jsonb_each(v_cat) e where e.value->>'f' = 'conciliacion' and (e.value->>'ok')::boolean);
  if cardinality(v_ctas) > 0 then
    begin
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_j
        from (
          with el as materialized (
                 select c0.cuenta, (v_cat->c0.cuenta->>'s')::int as sg,
                        coalesce((select k.id from conciliaciones k
                                   where k.cuenta = c0.cuenta and k.estado = 'confirmada' and k.fecha_corte >= v_f
                                   order by k.fecha_corte limit 1),
                                 (select k.id from conciliaciones k
                                   where k.cuenta = c0.cuenta and k.estado = 'confirmada' and k.fecha_corte < v_f
                                   order by k.fecha_corte desc limit 1)) as id
                   from unnest(v_ctas) c0(cuenta)),
               c as materialized (
                 select el.cuenta, el.sg, k.id, k.fecha_corte, k.tipo, coalesce(k.saldo_banco, 0) as saldo_banco, k.confirmada_el
                   from el join conciliaciones k on k.id = el.id),
               mv as (
                 -- lo que el libro movió entre el día y el corte de la conciliación (hacia delante o hacia atrás)
                 select c.cuenta, coalesce(sum(l.monto), 0) as s, count(*) as lineas
                   from c
                   join asiento_lineas l on l.cuenta = c.cuenta
                   join asientos a on a.id = l.asiento_id
                  where (c.fecha_corte > v_f and a.fecha_contable > v_f and a.fecha_contable <= c.fecha_corte)
                     or (c.fecha_corte < v_f and a.fecha_contable > c.fecha_corte and a.fecha_contable <= v_f)
                  group by c.cuenta)
          select c.cuenta, 1 as o, 'auxiliar'::text as clase, 'conciliacion'::text as fuente, 'statement'::text as clave, null::text as grupo,
                 format('Lo que dice el statement al %s', fn_cedula_dia(c.fecha_corte)) as concepto, null::text as referencia,
                 c.fecha_corte as fecha, (c.sg * c.saldo_banco)::numeric(14,2) as monto, null::numeric as libro, null::boolean as ok,
                 concat_ws(' · ', case when c.tipo = 'apertura' then 'La conciliación de la apertura' end,
                           'Confirmada el ' || fn_cedula_dia(fn_fecha_miami(c.confirmada_el))) as nota,
                 'conciliaciones'::text as ref_tabla, c.id::text as ref_id
            from c
          union all
          select c.cuenta, case when p.lado = 'libro' then 2 else 3 end, 'auxiliar', 'conciliacion', p.id::text, null,
                 case when p.lado = 'banco' then 'Del banco, todavía sin su asiento a esa fecha'
                      else case p.clase when 'deposito_en_transito' then 'Depósito en tránsito'
                                        when 'cargo_en_circulacion' then 'Cheque o cargo en circulación'
                                        when 'error' then 'Un error por corregir'
                                        when 'posible_duplicado' then 'Un posible duplicado'
                                        else p.clase end end
                   || coalesce(': ' || nullif(btrim(p.descripcion), ''), ''),
                 p.cheque, p.fecha,
                 (c.sg * case when p.lado = 'libro' then p.monto else -p.monto end)::numeric(14,2),
                 null, null, nullif(btrim(coalesce(p.motivo, '')), ''), 'conciliacion_partidas', p.id::text
            from c
            join conciliacion_partidas p on p.conciliacion_id = c.id
          union all
          select c.cuenta, 4, 'auxiliar', 'conciliacion', 'hasta_el_corte', null,
                 format('Lo que el libro movió del %s al %s, que esa conciliación ya cubre (se quita para llegar al %s)',
                        fn_cedula_dia(v_f + 1), fn_cedula_dia(c.fecha_corte), fn_cedula_dia(v_f)),
                 null, c.fecha_corte, (-c.sg * mv.s)::numeric(14,2), null, null, format('%s línea(s)', mv.lineas), null, null
            from c join mv on mv.cuenta = c.cuenta
           where c.fecha_corte > v_f and mv.lineas > 0
          union all
          select c.cuenta, 8, 'despues', 'conciliacion', 'despues', null,
                 format('Lo que el libro movió después de esa conciliación (del %s al %s): sin conciliar todavía',
                        fn_cedula_dia(c.fecha_corte + 1), fn_cedula_dia(v_f)),
                 null, v_f, null, (c.sg * mv.s)::numeric(14,2), null, format('%s línea(s)', mv.lineas), null, null
            from c join mv on mv.cuenta = c.cuenta
           where c.fecha_corte < v_f) x;
      v_all := v_all || v_j;
    exception when others then
      v_all := v_all || coalesce((select jsonb_agg(jsonb_build_object('cuenta', u, 'o', 0, 'clase', 'error', 'fuente', 'conciliacion',
                                                                     'clave', 'error', 'concepto', left(sqlerrm, 300)))
                                    from unnest(v_ctas) u), '[]'::jsonb);
    end;
  end if;

  -- (E) LOS PRÉSTAMOS (c6): de cada uno, lo que se debía al empezar menos el
  --     capital de las cuotas asentadas hasta el día, partido en lo que vence
  --     en un año (el capital de sus próximas cuotas de un año, con la
  --     fórmula que c6 enseña: va en su cuenta) y el resto (en su cuenta de
  --     largo plazo, si la tiene).
  v_ctas := array(select e.key from jsonb_each(v_cat) e where e.value->>'f' = 'prestamos' and (e.value->>'ok')::boolean);
  if cardinality(v_ctas) > 0 then
    begin
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_j
        from (
          with p as materialized (
                 select pr.id, pr.prestamista, pr.descripcion, pr.cuenta, pr.cuenta_largo, pr.cuota, pr.tasa_anual, pr.cuotas_al_anio,
                        pr.saldo_inicial_al,
                        (pr.saldo_inicial
                         - coalesce((select sum(q.capital)
                                       from prestamo_cuotas q
                                       left join asientos qa on qa.id = q.asiento_id
                                      where q.prestamo_id = pr.id
                                        and coalesce(qa.fecha_contable, q.fecha) <= v_f
                                        and case when q.asiento_id is null then q.anulada_el is null
                                                 else not exists (select 1 from asientos r
                                                                   where r.reversa_a = q.asiento_id and r.fecha_contable <= v_f) end), 0)
                        )::numeric(14,2) as saldo
                   from prestamos pr
                  where pr.estado <> 'cancelado' and pr.saldo_inicial_al <= v_f
                    and (pr.cuenta = any (v_ctas) or pr.cuenta_largo = any (v_ctas))),
               q as (
                 select p.*, (p.cuenta_largo is not null and p.cuenta_largo <> p.cuenta) as partido,
                        least(f.corriente, p.saldo)::numeric(14,2) as corriente
                   from p
                   left join lateral (
                     with recursive s(n, saldo, cap) as (
                       select 0, p.saldo::numeric, 0::numeric
                       union all
                       select s.n + 1,
                              s.saldo - least(s.saldo, greatest(p.cuota - round(s.saldo * p.tasa_anual / 100 / p.cuotas_al_anio, 2), 0)),
                              least(s.saldo, greatest(p.cuota - round(s.saldo * p.tasa_anual / 100 / p.cuotas_al_anio, 2), 0))
                         from s where s.n < p.cuotas_al_anio and s.saldo > 0)
                     select coalesce(sum(s.cap), 0) as corriente from s) f on true)
          select q.cuenta, 1 as o, 'auxiliar'::text as clase, 'prestamos'::text as fuente, q.id::text || ':corriente' as clave,
                 null::text as grupo,
                 q.prestamista || coalesce(' · ' || nullif(btrim(q.descripcion), ''), '')
                   || case when q.partido then ': lo que vence en un año' else '' end as concepto,
                 null::text as referencia, q.saldo_inicial_al as fecha,
                 (case when q.partido then q.corriente else q.saldo end)::numeric(14,2) as monto, null::numeric as libro,
                 null::boolean as ok, format('Se deben %s en total', fn_cedula_usd(q.saldo)) as nota,
                 'prestamos'::text as ref_tabla, q.id::text as ref_id
            from q
           where q.cuenta = any (v_ctas)
          union all
          select q.cuenta_largo, 1, 'auxiliar', 'prestamos', q.id::text || ':largo', null,
                 q.prestamista || coalesce(' · ' || nullif(btrim(q.descripcion), ''), '') || ': a largo plazo',
                 null, q.saldo_inicial_al, (q.saldo - q.corriente)::numeric(14,2), null, null,
                 format('Se deben %s en total', fn_cedula_usd(q.saldo)), 'prestamos', q.id::text
            from q
           where q.partido and q.cuenta_largo = any (v_ctas)) x;
      v_all := v_all || v_j;
    exception when others then
      v_all := v_all || coalesce((select jsonb_agg(jsonb_build_object('cuenta', u, 'o', 0, 'clase', 'error', 'fuente', 'prestamos',
                                                                     'clave', 'error', 'concepto', left(sqlerrm, 300)))
                                    from unnest(v_ctas) u), '[]'::jsonb);
    end;
  end if;

  -- (F) LAS PÓLIZAS PAGADAS POR ADELANTADO (c6): lo que le falta a cada una
  --     por pasar al gasto, con la cuenta de su cuadre de prepagados. Eso es
  --     «hoy»: se lleva a la fecha quitando lo que el libro movió en la
  --     cuenta después del día.
  v_ctas := array(select e.key from jsonb_each(v_cat) e where e.value->>'f' = 'prepagados' and (e.value->>'ok')::boolean);
  if cardinality(v_ctas) > 0 then
    begin
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_j
        from (
          with k as (select coalesce((select max(p.hasta) + 1 from periodos p where p.tipo = 'apertura'), date '2026-10-01') as corte),
               pp as materialized (
                 select p.id, p.cuenta, p.descripcion, p.tipo, p.desde, p.hasta, p.sustituida_por, p.cancelado_al,
                        (case when p.estado = 'vigente' or p.sustituida_por is not null or p.cancelado_al is not null
                              then (case when p.sustituida_por is not null then 0
                                         else (case when p.desde < k.corte
                                                    then coalesce(p.saldo_corte,
                                                                  p.monto - round(p.monto * (least(k.corte - 1, p.hasta) - p.desde + 1)
                                                                                  / (p.hasta - p.desde + 1), 2))
                                                    else p.monto end)
                                              - coalesce(p.devuelto, 0) end)
                                   - coalesce((select sum(a.monto) from prepagados_amortizaciones a
                                                where a.prepagado_id = p.id and a.vigente), 0)
                              else 0 end)::numeric(14,2) as falta
                   from prepagados p cross join k
                  where p.cuenta = any (v_ctas)),
               dp as (
                 -- lo que el libro movió en la cuenta después del día. Lo que ES DE UNA PÓLIZA (su amortización —un asiento
                 -- de c6—, o el papel con que se compró una registrada; y sus reversos) se le quita al auxiliar de hoy para
                 -- llegar a la fecha. Lo demás (un cargo que no es póliza, su corrección) NO se le quita: es justo lo que a
                 -- esa fecha la cuenta tenía de más o de menos, y sale como diferencia.
                 select l.cuenta,
                        coalesce(sum(l.monto) filter (where ev.es), 0) as s, count(*) filter (where ev.es) as lineas,
                        coalesce(sum(l.monto) filter (where not ev.es), 0) as s_otro, count(*) filter (where not ev.es) as lineas_otro
                   from asiento_lineas l
                   join asientos a on a.id = l.asiento_id
                   left join asientos o on o.id = a.reversa_a
                   cross join lateral (
                     -- (el papel de una póliza se escribe a mano al registrarla: vale el papel del asiento que la compró
                     -- —su recibo, su factura—, el propio asiento por su id o su número, o el movimiento del banco que lo trajo)
                     select coalesce(coalesce(o.origen_tabla, a.origen_tabla) = 'prepagados', false)
                            or exists (select 1 from prepagados p2
                                        where p2.cuenta = l.cuenta and p2.papel_id is not null
                                          and ((p2.papel_tabla = coalesce(o.origen_tabla, a.origen_tabla)
                                                and p2.papel_id = coalesce(o.origen_id, a.origen_id))
                                               or (lower(p2.papel_tabla) in ('asientos', 'asiento')
                                                   and p2.papel_id in (coalesce(o.id, a.id)::text, coalesce(o.numero, a.numero)))
                                               or (p2.papel_tabla = 'movimientos_banco'
                                                   and exists (select 1 from movimientos_banco mb
                                                                where mb.id::text = p2.papel_id
                                                                  and mb.asiento_id = coalesce(o.id, a.id))))) as es) ev
                  where l.cuenta = any (v_ctas) and a.fecha_contable > v_f
                  group by l.cuenta)
          select pp.cuenta, 1 as o, 'auxiliar'::text as clase, 'prepagados'::text as fuente, pp.id::text as clave, pp.tipo as grupo,
                 format('%s · del %s al %s (%s)', pp.descripcion, fn_cedula_dia(pp.desde), fn_cedula_dia(pp.hasta),
                        case when m.meses >= 1 then m.meses || ' mes(es)' else (pp.hasta - pp.desde + 1) || ' día(s)' end) as concepto,
                 null::text as referencia, pp.hasta as fecha, pp.falta as monto, null::numeric as libro, null::boolean as ok,
                 concat_ws(' · ',
                           case when pp.sustituida_por is not null then 'Sustituida por otra póliza'
                                when pp.cancelado_al is not null then 'Cancelada el ' || fn_cedula_dia(pp.cancelado_al)
                                when v_hoy > pp.hasta then 'Ya venció'
                                when m.faltan >= 1 then format('Le quedan %s mes(es) hoy', m.faltan)
                                else format('Le quedan %s día(s) hoy', greatest(pp.hasta - greatest(v_hoy, pp.desde - 1), 0)) end,
                           'Lo que falta es lo de hoy') as nota,
                 'prepagados'::text as ref_tabla, pp.id::text as ref_id
            from pp
            cross join lateral (
              select (extract(year from age(pp.hasta + 1, pp.desde)) * 12 + extract(month from age(pp.hasta + 1, pp.desde)))::int as meses,
                     case when v_hoy >= pp.hasta then 0
                          else (extract(year from age(pp.hasta + 1, greatest(v_hoy + 1, pp.desde))) * 12
                                + extract(month from age(pp.hasta + 1, greatest(v_hoy + 1, pp.desde))))::int end as faltan) m
           where pp.falta <> 0
          union all
          select dp.cuenta, 5, 'auxiliar', 'prepagados', 'despues_del_dia', null,
                 format('Lo que las pólizas movieron después del %s (lo amortizado y lo comprado: se quita para llegar a esa fecha)', fn_cedula_dia(v_f)),
                 null, v_f, (-(v_cat->dp.cuenta->>'s')::int * dp.s)::numeric(14,2), null, null, format('%s línea(s)', dp.lineas), null, null
            from dp
           where dp.s <> 0
          union all
          select dp.cuenta, 8, 'despues', 'prepagados', 'despues_ajeno', null,
                 format('Lo que el libro movió en la cuenta después del %s sin ser de una póliza registrada (ni su compra ni su amortización)',
                        fn_cedula_dia(v_f)),
                 null, v_f, null, ((v_cat->dp.cuenta->>'s')::int * dp.s_otro)::numeric(14,2), null,
                 format('%s línea(s) · No se le quita al auxiliar: a esa fecha la cuenta lo tenía de más o de menos', dp.lineas_otro), null, null
            from dp
           where dp.lineas_otro > 0) x;
      v_all := v_all || v_j;
    exception when others then
      v_all := v_all || coalesce((select jsonb_agg(jsonb_build_object('cuenta', u, 'o', 0, 'clase', 'error', 'fuente', 'prepagados',
                                                                     'clave', 'error', 'concepto', left(sqlerrm, 300)))
                                    from unnest(v_ctas) u), '[]'::jsonb);
    end;
  end if;

  -- (G) LOS ACTIVOS FIJOS Y SU DEPRECIACIÓN ACUMULADA (c9). Un activo cuenta
  --     desde que está en el libro (la fecha del asiento de su alta; sin él,
  --     su fecha en servicio: lo que venía de QuickBooks) y hasta el asiento
  --     de su baja (uno dado de baja sin asiento sigue en el libro: cuenta, y
  --     se dice). La acumulada de cada uno: lo depreciado antes del libro
  --     más cada depreciación posteada y viva hasta el día (la regla de la
  --     fila 90 del cierre).
  v_ctas := array(select e.key from jsonb_each(v_cat) e where e.value->>'f' in ('activos', 'depreciacion') and (e.value->>'ok')::boolean);
  if cardinality(v_ctas) > 0 then
    begin
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_j
        from (
          with af as (
                 select a.id, a.descripcion, a.placa_serie, a.cuenta, a.fecha_servicio, a.costo, a.dep_acumulada_inicial, a.estado,
                        a.baja_asiento_id,
                        coalesce((select y.fecha_contable from asientos y where y.id = a.asiento_alta_id), a.fecha_servicio) as en_libro,
                        (select y.fecha_contable from asientos y where y.id = a.baja_asiento_id) as baja_libro
                   from activos_fijos a),
               v as materialized (
                 select af.*,
                        (case when af.fecha_servicio <= v_f then af.dep_acumulada_inicial else 0 end
                         + coalesce((select sum(ad.monto)
                                       from activos_depreciaciones ad
                                       join asientos y on y.id = ad.asiento_id
                                      where ad.activo_id = af.id and y.fecha_contable <= v_f
                                        and not exists (select 1 from asientos r
                                                         where r.reversa_a = y.id and r.camino = 'reverso' and r.fecha_contable <= v_f)), 0)
                        )::numeric(14,2) as acumulada
                   from af
                  where af.en_libro <= v_f and (af.baja_libro is null or af.baja_libro > v_f))
          select v.cuenta, 1 as o, 'auxiliar'::text as clase, 'activos'::text as fuente, v.id::text as clave, null::text as grupo,
                 v.descripcion || coalesce(' · ' || nullif(btrim(v.placa_serie), ''), '') as concepto, null::text as referencia,
                 v.fecha_servicio as fecha, v.costo::numeric(14,2) as monto, null::numeric as libro, null::boolean as ok,
                 case when v.estado = 'baja' and v.baja_asiento_id is null then 'Dado de baja sin su asiento: su costo sigue en el libro' end as nota,
                 'activos_fijos'::text as ref_tabla, v.id::text as ref_id
            from v
           where v.cuenta = any (v_ctas) and v_cat->v.cuenta->>'f' = 'activos'
          union all
          select d.cuenta, 1, 'auxiliar', 'depreciacion', v.id::text, null,
                 v.descripcion || coalesce(' · ' || nullif(btrim(v.placa_serie), ''), ''), null, v.fecha_servicio, v.acumulada, null, null,
                 format('De un costo de %s', fn_cedula_usd(v.costo)), 'activos_fijos', v.id::text
            from v
           cross join (select u as cuenta from unnest(v_ctas) u where v_cat->u->>'f' = 'depreciacion') d
           where v.acumulada <> 0) x;
      v_all := v_all || v_j;
    exception when others then
      v_all := v_all || coalesce((select jsonb_agg(jsonb_build_object('cuenta', u, 'o', 0, 'clase', 'error', 'fuente', v_cat->u->>'f',
                                                                     'clave', 'error', 'concepto', left(sqlerrm, 300)))
                                    from unnest(v_ctas) u), '[]'::jsonb);
    end;
  end if;

  -- (H) EL WIP (c12), OBRA POR OBRA: el ajuste vivo que está en vigor ese día
  --     (fechado el día o antes, y con su reverso del día 1 todavía por
  --     llegar) contra lo que el libro tiene en cada obra. Aquí se compara
  --     uno a uno: «libro» y «ok» van en cada renglón.
  v_ctas := array(select e.key from jsonb_each(v_cat) e where e.value->>'f' = 'wip' and (e.value->>'ok')::boolean);
  if cardinality(v_ctas) > 0 then
    begin
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_j
        from (
          with aj as materialized (
                 select a.id, a.periodo, a.numero
                   from wip_ajustes a
                   left join asientos ra on ra.id = a.reverso_auto_id
                  where a.deshecho_el is null and a.fecha <= v_f and (a.reverso_auto_id is null or ra.fecha_contable > v_f)),
               au as (
                 select y.cuenta, w.proyecto_id, sum(y.monto) as monto, min(aj.periodo) as periodo, min(aj.numero) as numero
                   from aj
                   join wip_ajuste_obras w on w.ajuste_id = aj.id and w.en_ajuste
                   cross join lateral (values ('1200', w.sub_facturado), ('2400', w.sobre_facturado), ('2410', w.perdida_provision)) y(cuenta, monto)
                  where y.monto <> 0 and y.cuenta = any (v_ctas)
                  group by y.cuenta, w.proyecto_id),
               lb as (
                 select l.cuenta, l.proyecto_id, sum(l.monto) as s
                   from asiento_lineas l
                   join asientos a on a.id = l.asiento_id
                  where l.cuenta = any (v_ctas) and a.fecha_contable <= v_f
                  group by l.cuenta, l.proyecto_id
                 having sum(l.monto) <> 0),
               j as (
                 select coalesce(au.cuenta, lb.cuenta) as cuenta, coalesce(au.proyecto_id, lb.proyecto_id) as proyecto_id,
                        coalesce(au.monto, 0)::numeric(14,2) as monto, lb.s, au.periodo, au.numero
                   from au
                   full join lb on lb.cuenta = au.cuenta and lb.proyecto_id is not distinct from au.proyecto_id)
          select j.cuenta, 1 as o, 'auxiliar'::text as clase, 'wip'::text as fuente, coalesce(j.proyecto_id, 'sin_obra') as clave,
                 pr.nombre as grupo, coalesce(pr.nombre, j.proyecto_id, 'Sin obra') as concepto, j.numero as referencia, null::date as fecha,
                 j.monto, ((v_cat->j.cuenta->>'s')::int * coalesce(j.s, 0))::numeric(14,2) as libro,
                 (j.monto = ((v_cat->j.cuenta->>'s')::int * coalesce(j.s, 0))::numeric(14,2)) as ok,
                 case when j.periodo is not null then 'Del ajuste de ' || fn_cedula_mes(j.periodo)
                      else 'En el libro, y ningún ajuste de WIP en vigor lo trae' end as nota,
                 'proyectos'::text as ref_tabla, j.proyecto_id as ref_id
            from j
            left join proyectos pr on pr.id = j.proyecto_id) x;
      v_all := v_all || v_j;
    exception when others then
      v_all := v_all || coalesce((select jsonb_agg(jsonb_build_object('cuenta', u, 'o', 0, 'clase', 'error', 'fuente', 'wip',
                                                                     'clave', 'error', 'concepto', left(sqlerrm, 300)))
                                    from unnest(v_ctas) u), '[]'::jsonb);
    end;
  end if;

  -- (I) STRIPE (p1): lo cobrado en línea que falta depositar (cada pago, y lo
  --     que volvió de un depósito fallido sin liquidar: la cuenta del cuadre
  --     21 de p1). Es «hoy»: se lleva a la fecha quitando lo que el libro
  --     movió en la cuenta después del día. La cuenta de paso no tiene
  --     renglones: debe estar en cero.
  v_ctas := array(select e.key from jsonb_each(v_cat) e where e.value->>'f' = 'stripe' and (e.value->>'ok')::boolean);
  if cardinality(v_ctas) > 0 then
    begin
      select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_j
        from (
          with ct as (select u as cuenta from unnest(v_ctas) u),
               vu as (
                 select q.po, q.llegada,
                        (q.monto - coalesce((select sum(l2.monto)
                                               from stripe_payout_lineas l2
                                               join stripe_payouts q2 on q2.id = l2.payout_id
                                              where l2.clase = 'vuelve' and l2.fuente = q.po and q2.asiento_salida is not null
                                                and not exists (select 1 from asientos r
                                                                 where r.reversa_a = q2.asiento_salida
                                                                   and r.camino in ('reverso', 'reverso_automatico'))), 0))::numeric(14,2) as queda
                   from stripe_payouts q
                  where q.estado = 'fallido' and q.asiento_vuelta is not null
                    and not exists (select 1 from asientos r
                                     where r.reversa_a = q.asiento_vuelta and r.camino in ('reverso', 'reverso_automatico'))),
               dp as (
                 select l.cuenta, sum(l.monto) as s, count(*) as lineas
                   from asiento_lineas l
                   join asientos a on a.id = l.asiento_id
                  where l.cuenta = any (v_ctas) and a.fecha_contable > v_f
                  group by l.cuenta)
          select ct.cuenta, 1 as o, 'auxiliar'::text as clase, 'stripe'::text as fuente, v.id::text as clave, v.obra as grupo,
                 'Cobro en línea' || coalesce(' de la factura #' || v.factura_num, ' ' || v.pi) as concepto, v.pi as referencia,
                 v.cobrado_el as fecha, v.falta_depositar::numeric(14,2) as monto, null::numeric as libro, null::boolean as ok,
                 'Falta que Stripe lo deposite (lo de hoy)'::text as nota, 'stripe_pagos'::text as ref_tabla, v.id::text as ref_id
            from ct
            cross join v_stripe_pagos v
           where v.falta_depositar <> 0
          union all
          select ct.cuenta, 2, 'auxiliar', 'stripe', vu.po, null,
                 'Un depósito de Stripe que falló y volvió a Stripe: ' || vu.po, vu.po, vu.llegada, vu.queda, null, null,
                 'Sigue en Stripe hasta que otro depósito lo traiga', 'stripe_payouts', vu.po
            from ct cross join vu
           where vu.queda <> 0
          union all
          select dp.cuenta, 5, 'auxiliar', 'stripe', 'despues_del_dia', null,
                 format('Lo que el libro movió en la cuenta después del %s (se quita para llegar a esa fecha)', fn_cedula_dia(v_f)),
                 null, v_f, (-(v_cat->dp.cuenta->>'s')::int * dp.s)::numeric(14,2), null, null, format('%s línea(s)', dp.lineas), null, null
            from dp
           where dp.lineas > 0) x;
      v_all := v_all || v_j;
    exception when others then
      v_all := v_all || coalesce((select jsonb_agg(jsonb_build_object('cuenta', u, 'o', 0, 'clase', 'error', 'fuente', 'stripe',
                                                                     'clave', 'error', 'concepto', left(sqlerrm, 300)))
                                    from unnest(v_ctas) u), '[]'::jsonb);
    end;
  end if;

  -- (J) LOS RENGLONES ESCRITOS A MANO, de cualquier cuenta: los vigentes cuyo
  --     «desde … hasta» contiene el día.
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_j
    from (
      select m.cuenta, 6 as o, 'auxiliar'::text as clase, 'manual'::text as fuente, m.id::text as clave, null::text as grupo,
             m.concepto, nullif(btrim(coalesce(m.documento, '')), '') as referencia, m.desde as fecha, m.monto, null::numeric as libro,
             null::boolean as ok,
             concat_ws(' · ', nullif(btrim(coalesce(m.nota, '')), ''),
                       case when m.hasta is not null then 'Hasta el ' || fn_cedula_dia(m.hasta) end,
                       'Escrito a mano') as nota,
             'cedula_manual'::text as ref_tabla, m.id::text as ref_id
        from cedula_manual m
       where m.sustituido_el is null and m.anulado_el is null
         and m.desde <= v_f and (m.hasta is null or m.hasta >= v_f)
         and v_cat ? m.cuenta) x;
  v_all := v_all || v_j;

  -- (K) UN DATO, solo al pedir esa cuenta: en la reserva de impuestos, lo que
  --     el cierre (c9) dice que debería haber. No es su auxiliar (es una meta
  --     que se mueve con la utilidad de cada día): no suma ni se compara.
  if p_cuenta = '1030' and v_cat ? '1030' and to_regclass('public.v_reserva_impuestos') is not null then
    begin
      execute 'select jsonb_build_array(jsonb_build_object(''cuenta'', ''1030'', ''o'', 20, ''clase'', ''dato'', ''fuente'', ''reserva'', '
           || '''clave'', ''meta'', ''concepto'', ''Lo que debería haber en la reserva, según el cierre (hoy): '' || r.mensaje, '
           || '''fecha'', r.hoy, ''nota'', ''Es una meta, no lo que sostiene el saldo: no suma ni se compara'')) '
           || 'from public.v_reserva_impuestos r'
         into v_j;
      v_all := v_all || coalesce(v_j, '[]'::jsonb);
    exception when others then
      null;   -- (un dato de más: si el cierre no lo da, la cédula sigue)
    end;
  end if;

  return query
  select x.cuenta, (row_number() over (partition by x.cuenta order by x.o, x.fecha nulls last, x.concepto, x.clave))::int,
         x.clase, x.fuente, x.clave, x.grupo, x.concepto, x.referencia, x.fecha, x.monto::numeric(14,2), x.libro::numeric(14,2), x.ok,
         x.nota, x.ref_tabla, x.ref_id
    from jsonb_to_recordset(v_all) as x(cuenta text, o int, clase text, fuente text, clave text, grupo text, concepto text,
                                        referencia text, fecha date, monto numeric, libro numeric, ok boolean, nota text,
                                        ref_tabla text, ref_id text)
   order by 1, 2;
end $$;
revoke execute on function public.fn_cedula_partidas(date, text) from public, anon, service_role;
grant  execute on function public.fn_cedula_partidas(date, text) to authenticated;
comment on function public.fn_cedula_partidas(date, text) is 'c13: los renglones del auxiliar de cada cuenta de balance (o de una) a una fecha (sin fecha, el último día del período que toca): cuenta, n, clase (auxiliar: su monto suma al auxiliar; libro: sale del propio libro, ordenado —el patrimonio y el use tax—, y es el auxiliar de su cuenta solo mientras no tenga renglones a mano; suelto: lo que el libro tiene en la cuenta sin decir de qué es; despues: en un banco o una tarjeta, lo que el libro movió después de su última conciliación confirmada, y en las pólizas lo que movió después del día sin ser de una póliza; error: no se pudo leer; dato: algo que se enseña al lado sin sumar, como la meta de la reserva de impuestos al pedir la 1030), fuente, clave, grupo, concepto, referencia, fecha, monto (lo que dice el auxiliar, en el lado natural de la cuenta), libro y ok (donde se compara renglón a renglón: el WIP por obra), nota, y el papel que hay detrás (ref_tabla, ref_id). Lee las partidas abiertas del libro, las conciliaciones, los préstamos y las pólizas de c6, los activos de c9, el ajuste de WIP de c12, lo de Stripe de p1 y los renglones escritos a mano. Solo lectura; a quien no es el dueño, nada.';

-- LA CÉDULA: una fila por cuenta de balance a una fecha (sin fecha, el último
-- día del período que toca). Las columnas:
--   fecha            el día de la cédula
--   orden, cuenta, nombre, tipo (activo | pasivo | capital), signo
--   saldo_libro      el saldo de la cuenta en el libro a ese día, en su lado
--                    natural (positivo = lo normal). signo × saldo_libro es
--                    debe − haber
--   fuente           de dónde sale su auxiliar (fn_cedula_cuentas)
--   auxiliar, origen su nombre y de dónde sale, en llano
--   auxiliar_al      la fecha del auxiliar cuando no es la de la cédula: el
--                    corte de la conciliación; hoy, en Stripe y las pólizas
--   saldo_auxiliar   lo que suma el auxiliar (nulo si no lo tiene)
--   diferencia       saldo_libro − saldo_auxiliar (nulo si no lo tiene)
--   renglones        cuántos renglones tiene el auxiliar; descuadres, los
--                    que no casan uno a uno con el libro (el WIP por obra)
--   manual           cuánto del auxiliar son renglones escritos a mano
--   despues          lo que el libro movió después: en un banco o una
--                    tarjeta, después de su última conciliación confirmada;
--                    en las pólizas, después del día sin ser de una póliza
--   sueltas          lo que el libro tiene en la cuenta sin decir de qué es
--   estado           cuadra | explicada | no_cuadra | sin_auxiliar | del_libro
--   pendiente        pide algo: no cuadra, o no tiene auxiliar y sí saldo, y
--                    nadie lo ha explicado (o la explicación se quedó vieja)
--   por_que          sin auxiliar: 'capa' (esa capa no está) | 'vacio'
--                    (todavía no hay con qué: ni conciliación, ni préstamo,
--                    ni póliza, ni activo) | 'manual' (la base no lo sabe) |
--                    'f11' (llega con la nómina) | 'error' (no se pudo leer)
--   detalle, que_hacer   en llano
--   explicacion, explicada_el, explicada_por, explicada_por_nombre,
--   explicacion_id   la explicación viva de esa cuenta y ese día
--   explicacion_vieja    la explicación ya no vale: el saldo del libro o el
--                    del auxiliar cambiaron después
--   sosten           QUÉ HAY DEBAJO de un «cuadra» (o de un «del libro»):
--                    'papel'    algo que no es el libro y vale para ESE día:
--                               la conciliación de ese día, la carta del
--                               préstamo, las pólizas, los activos, el WIP,
--                               un renglón escrito a mano con su documento
--                    'partidas' las partidas del propio libro: dice que cada
--                               línea tiene su factura o su proveedor (y que
--                               no hay nada suelto), NO que case con un
--                               papel de fuera (el statement del supply se
--                               compara a mano)
--                    'libro'    el propio libro, ordenado (el patrimonio por
--                               su mayor, el use tax por mes): no hay con qué
--                               compararlo aquí
--                    'llevado'  su papel es de OTRO día y a este se llega con
--                               los movimientos del propio libro: no
--                               comprueba el saldo de este día
--                    (nulo si no tiene auxiliar)
--   par, solo_reparto  en un préstamo, la otra cuenta del mismo; y si su
--                    diferencia es solo el reparto entre corriente y largo
--                    plazo (con su par, el total cuadra)
-- EL ESTADO. «cuadra» = el saldo es, al centavo, lo que suma un auxiliar que
-- VALE PARA ESE DÍA y nada queda suelto. No basta con que la resta dé cero:
--   · un banco o una tarjeta cuya última conciliación confirmada es ANTERIOR
--     al día NO cuadra aunque la diferencia sea cero (falta conciliar hasta
--     el día: que el libro no se haya movido no dice lo que hizo el banco);
--   · unas cuentas por cobrar con renglones sin factura que se compensan
--     entre dos obras (lo que una tiene de más lo tiene otra de menos) NO
--     cuadran aunque la resta dé cero;
--   · lo que sale del propio libro (el patrimonio por su mayor, el use tax
--     por mes) y lo que se lleva a la fecha con los movimientos del libro
--     (una conciliación posterior; lo que Stripe debe hoy) no es «cuadra»:
--     es «del_libro». No pide nada, y se cuenta aparte.
-- Salen las cuentas activas y las que tienen movimiento o renglones.
drop function if exists public.fn_cedula(date);
create function public.fn_cedula(p_fecha date default null)
returns table (fecha date, orden int, cuenta text, nombre text, tipo text, signo int, saldo_libro numeric(14,2),
               fuente text, auxiliar text, origen text, auxiliar_al date, saldo_auxiliar numeric(14,2), diferencia numeric(14,2),
               renglones int, descuadres int, manual numeric(14,2), despues numeric(14,2), sueltas numeric(14,2),
               estado text, pendiente boolean, por_que text, detalle text, que_hacer text,
               explicacion text, explicada_el timestamptz, explicada_por uuid, explicada_por_nombre text, explicacion_id uuid,
               explicacion_vieja boolean, sosten text, par text, solo_reparto boolean)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_f    date;
  v_hoy  date := fn_fecha_miami(now());
begin
  if not fn_cedula_ve() then
    return;
  end if;
  v_f := coalesce(p_fecha, (select q.hasta from periodos q where q.periodo = fn_cedula_toca()), v_hoy);
  return query
  with cu as materialized (select c.* from fn_cedula_cuentas() c),
       sl as materialized (
         select l.cuenta, sum(l.monto) as s
           from asiento_lineas l
           join asientos a on a.id = l.asiento_id
          where a.fecha_contable <= v_f and l.cuenta in (select cu.cuenta from cu)
          group by l.cuenta),
       it as materialized (select i.* from fn_cedula_partidas(v_f, null) i),
       ag as (
         select i.cuenta,
                coalesce(sum(i.monto) filter (where i.clase = 'auxiliar'), 0)::numeric(14,2) as aux,
                (count(*) filter (where i.clase = 'auxiliar'))::int as renglones,
                -- (lo que sale del propio libro, ordenado: el patrimonio por su mayor, el use tax por mes)
                coalesce(sum(i.monto) filter (where i.clase = 'libro'), 0)::numeric(14,2) as libro_aux,
                (count(*) filter (where i.clase = 'libro'))::int as libro_n,
                (count(*) filter (where i.clase = 'auxiliar' and i.ok is false))::int as descuadres,
                coalesce(sum(i.monto) filter (where i.clase = 'auxiliar' and i.fuente = 'manual'), 0)::numeric(14,2) as manual,
                (count(*) filter (where i.clase = 'auxiliar' and i.fuente = 'manual'))::int as manual_n,
                (sum(i.libro) filter (where i.clase = 'despues'))::numeric(14,2) as despues,
                max(i.nota) filter (where i.clase = 'despues') as despues_nota,
                (sum(i.libro) filter (where i.clase = 'suelto'))::numeric(14,2) as sueltas,
                (count(*) filter (where i.clase = 'suelto' and i.libro <> 0))::int as sueltas_n,
                (sum(abs(i.libro)) filter (where i.clase = 'suelto'))::numeric(14,2) as sueltas_abs,
                format('%s línea(s)', coalesce(sum(substring(i.nota from '^([0-9]+) línea')::int) filter (where i.clase = 'suelto'), 0)) as sueltas_nota,
                min(i.fecha) filter (where i.clave = 'statement') as conc_al,
                -- (lo que se le quitó al auxiliar con movimientos del propio libro para llegar a la fecha: una conciliación
                -- posterior; lo que Stripe debe hoy)
                max(i.nota) filter (where i.clave = 'hasta_el_corte' or (i.clave = 'despues_del_dia' and i.fuente = 'stripe')) as llevado_nota,
                max(i.concepto) filter (where i.clase = 'error') as error
           from it i
          group by i.cuenta),
       b as (
         select cu.cuenta, cu.nombre, cu.tipo, cu.signo, cu.fuente, cu.forma, cu.auxiliar, cu.origen, cu.capa_esta, cu.vacio, cu.par,
                (cu.signo * coalesce(sl.s, 0))::numeric(14,2) as saldo,
                -- (lo que sale del propio libro solo es el auxiliar mientras nadie haya escrito a mano con qué compararlo)
                (coalesce(ag.aux, 0) + case when cu.fuente in ('mayor', 'dr15') and coalesce(ag.manual_n, 0) = 0
                                            then coalesce(ag.libro_aux, 0) else 0 end)::numeric(14,2) as aux,
                (coalesce(ag.renglones, 0) + case when cu.fuente in ('mayor', 'dr15') and coalesce(ag.manual_n, 0) = 0
                                                  then coalesce(ag.libro_n, 0) else 0 end) as renglones,
                coalesce(ag.descuadres, 0) as descuadres,
                coalesce(ag.manual, 0)::numeric(14,2) as manual, coalesce(ag.manual_n, 0) as manual_n, ag.despues, ag.despues_nota,
                ag.sueltas, coalesce(ag.sueltas_n, 0) as sueltas_n, ag.sueltas_nota, ag.conc_al, ag.llevado_nota, ag.error,
                -- (renglones sueltos de signo contrario: lo que una obra tiene de más lo tiene otra de menos. Su suma no lo
                -- enseña —se compensan—, y la resta contra el auxiliar tampoco)
                (coalesce(ag.sueltas_abs, 0) <> abs(coalesce(ag.sueltas, 0))) as se_compensan,
                coalesce(ag.sueltas_abs, 0)::numeric(14,2) as sueltas_abs,
                -- ¿tiene auxiliar? El automático (su capa está, tiene con qué y se pudo leer) o algún renglón a mano
                ((cu.capa_esta and cu.hay and ag.error is null) or coalesce(ag.manual_n, 0) > 0) as tiene
           from cu
           left join sl on sl.cuenta = cu.cuenta
           left join ag on ag.cuenta = cu.cuenta
          where cu.activa or sl.cuenta is not null or ag.cuenta is not null),
       d as (
         select b.*,
                case when b.tiene then b.aux end as saldo_aux,
                case when b.tiene then (b.saldo - b.aux)::numeric(14,2) end as dif,
                -- (un banco o una tarjeta cuya última conciliación confirmada es anterior al día: no vale para ese día)
                (b.fuente = 'conciliacion' and b.conc_al is not null and b.conc_al < v_f) as conc_antes,
                case when not b.tiene then null
                     when b.fuente in ('mayor', 'dr15') and b.manual_n = 0 then 'libro'
                     when b.llevado_nota is not null then 'llevado'
                     when b.fuente in ('partidas', 'devengos') and not (b.manual_n > 0 and b.renglones = b.manual_n) then 'partidas'
                     else 'papel' end as sosten
           from b),
       d2 as (
         select d.*,
                case when not d.tiene then 'sin_auxiliar'
                     when d.sosten = 'libro' then 'del_libro'
                     when d.saldo - d.aux <> 0 or d.descuadres > 0 then 'no_cuadra'
                     when d.se_compensan then 'no_cuadra'
                     when d.conc_antes then 'no_cuadra'
                     when d.sosten = 'llevado' then 'del_libro'
                     else 'cuadra' end as base
           from d),
       e as (
         select d2.*, x.id as ex_id, x.texto as ex_texto, x.explicado_el as ex_el, x.explicado_por as ex_por,
                x.saldo_libro as ex_saldo, x.saldo_auxiliar as ex_aux, pf.nombre as ex_nombre,
                -- pide algo: no cuadra, o no tiene auxiliar y sí saldo
                (d2.base = 'no_cuadra' or (d2.base = 'sin_auxiliar' and d2.saldo <> 0)) as falta,
                -- la explicación vale mientras el saldo del libro, el del auxiliar y lo que la cuenta tiene suelto sean los de
                -- cuando se explicó
                (x.id is not null and x.saldo_libro = d2.saldo and x.saldo_auxiliar is not distinct from (case when d2.tiene then d2.aux end)
                 and coalesce(x.sueltas_abs, d2.sueltas_abs) = d2.sueltas_abs) as ex_vale,
                (x.id is not null and x.saldo_libro = d2.saldo and x.saldo_auxiliar is not distinct from (case when d2.tiene then d2.aux end)
                 and coalesce(x.sueltas_abs, d2.sueltas_abs) <> d2.sueltas_abs) as ex_solo_sueltas
           from d2
           left join cedula_explicaciones x
                  on x.cuenta = d2.cuenta and x.fecha = v_f and x.sustituida_el is null and x.retirada_el is null
           left join perfiles pf on pf.id = x.explicado_por),
       g as (
         select e.*, o.dif as par_dif, o.nombre as par_nombre,
                -- (con renglones a mano, lo que sale del propio libro deja de hacer de auxiliar: se compara con lo escrito)
                case when e.fuente in ('mayor', 'dr15') and e.manual_n > 0 then 'sus renglones escritos a mano'
                     else lower(left(e.auxiliar, 1)) || substr(e.auxiliar, 2) end as aux_llano,
                (e.fuente = 'prestamos' and e.par is not null and o.dif is not null and e.dif is not null and e.dif <> 0
                 and e.dif + o.dif = 0) as solo_reparto,
                case when e.base in ('cuadra', 'del_libro') then e.base
                     when e.falta and e.ex_vale then 'explicada'
                     else e.base end as estado_final
           from e
           left join e o on o.cuenta = e.par)
  select v_f,
         (row_number() over (order by g.cuenta))::int,
         g.cuenta, g.nombre, g.tipo, g.signo, g.saldo,
         g.fuente, g.auxiliar, g.origen,
         (case when not g.tiene then null
               when g.fuente = 'conciliacion' and g.conc_al is not null then g.conc_al
               when g.fuente in ('stripe', 'stripe_paso', 'prepagados') and g.renglones > g.manual_n then v_hoy
               else v_f end),
         g.saldo_aux, g.dif, g.renglones, g.descuadres, g.manual, g.despues, g.sueltas,
         g.estado_final,
         (g.falta and not g.ex_vale),
         (case when g.tiene then null
               when g.error is not null then 'error'
               when not g.capa_esta then 'capa'
               when g.fuente = 'nomina' then 'f11'
               when g.fuente = 'manual' then 'manual'
               else 'vacio' end),
         -- EL DETALLE, en llano
         (case
            when g.base = 'cuadra' and g.saldo = 0 and g.renglones = 0 then
              format('Sin saldo al %s, y nada abierto en %s.', fn_cedula_dia(v_f), g.aux_llano)
            when g.base = 'cuadra' then
              format('%s en el libro al %s = %s en %s%s.', fn_cedula_usd(g.saldo), fn_cedula_dia(v_f), fn_cedula_usd(g.aux), g.aux_llano,
                     case when g.renglones > 0 then format(' (%s renglón(es))', g.renglones) else '' end)
              || case when g.fuente = 'conciliacion' and g.conc_al is distinct from v_f and g.conc_al is not null
                      then format(' Su conciliación es la del %s; entre ese día y este el libro no movió la cuenta.', fn_cedula_dia(g.conc_al)) else '' end
              || case when g.fuente in ('stripe', 'prepagados') and v_f < v_hoy and g.renglones > g.manual_n
                      then case when g.fuente = 'prepagados'
                                then ' Su auxiliar es el de hoy, llevado a esa fecha con lo que las pólizas movieron después (lo amortizado y lo comprado).'
                                else ' Su auxiliar es el de hoy; desde ese día el libro no ha movido la cuenta.' end else '' end
              || case when g.fuente in ('mayor', 'dr15') and g.manual_n > 0
                      then ' Se compara con lo que está escrito a mano; lo que sale del propio libro queda abajo, de referencia.' else '' end
              || case when g.sosten = 'partidas'
                      then format(' Sale de las partidas del propio libro: dice que cada línea tiene %s y que nada queda suelto, no que case con un papel de fuera.',
                                  case g.forma when 'cobrar' then 'su factura' when 'pagar' then 'su proveedor o su papel' else 'su asiento de devengo' end)
                      else '' end
            when g.base = 'del_libro' and g.sosten = 'libro' then
              format('%s en el libro al %s. Sale del propio libro, ordenado (%s%s): aquí no se compara con ningún papel de fuera.',
                     fn_cedula_usd(g.saldo), fn_cedula_dia(v_f), g.aux_llano,
                     case when g.renglones > 0 then format(', %s renglón(es)', g.renglones) else '' end)
              || case when g.fuente = 'dr15' then ' Si escribes a mano lo que dice cada DR-15 presentado, se compara con eso.'
                      else ' Lo amarra la comparación con QuickBooks; si escribes a mano sus renglones (el acta, la declaración), se compara con eso.' end
            when g.base = 'del_libro' and g.fuente = 'conciliacion' then
              format('%s en el libro al %s. Su conciliación confirmada es la del %s: a este día se llega quitándole lo que el libro movió después '
                     '(%s), así que no comprueba el saldo de ESTE día.', fn_cedula_usd(g.saldo), fn_cedula_dia(v_f), fn_cedula_dia(g.conc_al),
                     g.llevado_nota)
            when g.base = 'del_libro' then
              format('%s en el libro al %s. Su auxiliar es el de HOY: a esa fecha se llega con lo que el libro movió después (%s), así que no '
                     'comprueba el saldo de ese día.', fn_cedula_usd(g.saldo), fn_cedula_dia(v_f), g.llevado_nota)
            when g.base = 'sin_auxiliar' then
              format('Sin auxiliar: %s.', coalesce('no se pudo leer (' || g.error || ')', g.vacio, 'no tiene'))
              || case when g.saldo <> 0 then format(' Tiene %s en el libro al %s.', fn_cedula_usd(g.saldo), fn_cedula_dia(v_f))
                      else ' No tiene saldo: no pide nada.' end
            when g.dif = 0 and g.descuadres = 0 and g.se_compensan then
              format('%s en el libro al %s y lo mismo en %s, pero NO cuadra: la cuenta tiene %s renglón(es) sin decir %s que se compensan entre '
                     'sí (%s). Cada uno está abajo, con su obra.', fn_cedula_usd(g.saldo), fn_cedula_dia(v_f), g.aux_llano, g.sueltas_n,
                     case g.forma when 'cobrar' then 'de qué factura son' else 'de qué son' end, g.sueltas_nota)
            when g.dif = 0 and g.descuadres = 0 and g.conc_antes then
              format('%s en el libro al %s. La última conciliación confirmada es la del %s: falta la de este día. ', fn_cedula_usd(g.saldo),
                     fn_cedula_dia(v_f), fn_cedula_dia(g.conc_al))
              || case when g.despues_nota is not null
                      then format('Después de ella el libro movió %s (%s), sin conciliar. ', fn_cedula_usd(coalesce(g.despues, 0)), g.despues_nota)
                      else 'Desde entonces el libro no ha movido la cuenta, pero eso no dice lo que hizo el banco. ' end
              || 'Por eso no cuadra aunque la resta dé cero.'
            else
              format('%s en el libro al %s y %s en %s: %s de diferencia.', fn_cedula_usd(g.saldo), fn_cedula_dia(v_f), fn_cedula_usd(g.aux),
                     g.aux_llano, fn_cedula_usd(g.dif))
              || case
                   when g.fuente = 'conciliacion' and g.despues is not null
                     then format(' La última conciliación confirmada es la del %s; después el libro movió %s (%s): falta conciliar hasta el %s.',
                                 fn_cedula_dia(g.conc_al), fn_cedula_usd(g.despues), g.despues_nota, fn_cedula_dia(v_f))
                          || case when g.dif - g.despues <> 0 and g.manual_n = 0
                                  then format(' Además, %s entraron al libro con fecha anterior a esa conciliación después de confirmarla.',
                                              fn_cedula_usd(g.dif - g.despues)) else '' end
                   when g.fuente = 'conciliacion' and g.conc_al is not null and g.manual_n = 0
                     then format(' La conciliación del %s se confirmó con otro saldo en el libro: después entró algo con fecha anterior a su corte.',
                                 fn_cedula_dia(g.conc_al))
                   when g.fuente = 'partidas' and g.sueltas is not null
                     then format(' %s están en el libro sin decir %s (%s).', fn_cedula_usd(g.sueltas),
                                 case g.forma when 'cobrar' then 'de qué factura son' else 'a quién se le deben' end, g.sueltas_nota)
                   when g.fuente = 'devengos' and g.sueltas is not null
                     then format(' %s no son un devengo de los que se deshacen solos.', fn_cedula_usd(g.sueltas))
                   when g.fuente = 'prestamos' and g.par is not null and g.par_dif is not null and g.dif + g.par_dif = 0
                     then format(' Con la %s (%s) el total sí cuadra: es solo el reparto entre lo que vence en un año y lo de largo plazo. '
                                 'Un asiento a mano lo arregla: pasar %s de la %s a la %s.', g.par, g.par_nombre, fn_cedula_usd(abs(g.dif)),
                                 case when g.dif > 0 then g.cuenta else g.par end, case when g.dif > 0 then g.par else g.cuenta end)
                   when g.fuente = 'prepagados' and g.despues is not null
                     then format(' Después de ese día el libro movió %s en esta cuenta sin ser de una póliza registrada (%s): eso no se le '
                                 'quita al auxiliar, porque a esa fecha la cuenta lo tenía de más o de menos (un cargo que no era póliza y '
                                 'se corrigió después; o una póliza comprada después que no está enlazada con su papel).',
                                 fn_cedula_usd(g.despues), split_part(g.despues_nota, ' · ', 1))
                   when g.fuente = 'wip' and g.descuadres > 0
                     then format(' En %s obra(s) el libro no tiene lo que dice el ajuste del WIP.', g.descuadres)
                   when g.fuente = 'stripe_paso' then ' Es una cuenta de paso: debería estar en cero.'
                   else '' end
              || case when g.manual_n > 0 and g.renglones > g.manual_n
                      then format(' (De su auxiliar, %s son renglones escritos a mano.)', fn_cedula_usd(g.manual)) else '' end
          end)
         || case when g.falta and g.ex_vale
                 then format(' Explicada por %s el %s: «%s»', coalesce(g.ex_nombre, 'el SQL Editor'), fn_cedula_dia(fn_fecha_miami(g.ex_el)),
                             left(g.ex_texto, 400))
                 when g.falta and g.ex_id is not null and g.ex_solo_sueltas
                 then format(' La explicación del %s se escribió con otros renglones sueltos en la cuenta (sin decir de qué son); eso cambió '
                             'después, aunque el saldo sea el mismo: vuelve a explicarla.', fn_cedula_dia(fn_fecha_miami(g.ex_el)))
                 when g.falta and g.ex_id is not null
                 then format(' La explicación del %s valía con %s en el libro y %s en el auxiliar; eso cambió después: vuelve a explicarla.',
                             fn_cedula_dia(fn_fecha_miami(g.ex_el)), fn_cedula_usd(g.ex_saldo),
                             coalesce(fn_cedula_usd(g.ex_aux), 'nada'))
                 else '' end,
         -- QUÉ HACER (si pide algo; y, sin pedir nada, cómo comprobar de verdad lo que solo sale del libro)
         (case when g.base = 'del_libro' and g.fuente = 'conciliacion'
                 then format('No pide nada. Para comprobar el saldo de este día, concilia la cuenta al %s en Conciliar y confirma.', fn_cedula_dia(v_f))
               when g.base = 'del_libro' and g.sosten = 'llevado'
                 then 'No pide nada. Para comprobarla, mírala el mismo día del corte, o compara a mano con lo que Stripe decía ese día.'
               when not (g.falta and not g.ex_vale) then null
               when g.base = 'sin_auxiliar' and g.error is not null then 'Avisa: esa parte de la contabilidad cambió y la cédula no la pudo leer.'
               when g.base = 'sin_auxiliar' and not g.capa_esta
                 then 'Esa parte de la contabilidad no está instalada aquí: escríbele sus renglones a mano (qué es, cuánto, con qué documento) o explícalo.'
               when g.base = 'sin_auxiliar' and g.fuente = 'conciliacion'
                 then 'Concilia la cuenta en Conciliar (el saldo del statement) y confirma; o escribe a mano el saldo del statement con su documento.'
               when g.base = 'sin_auxiliar' and g.fuente = 'prestamos'
                 then 'Registra el préstamo (con su carta: lo que se debía, la tasa y la cuota); si no es un préstamo de cuotas (una línea de crédito), escribe a mano lo que dice su statement.'
               when g.base = 'sin_auxiliar' and g.fuente = 'prepagados'
                 then 'Registra la póliza (su monto, desde cuándo y hasta cuándo cubre); lo que no sea una póliza se escribe a mano.'
               when g.base = 'sin_auxiliar' and g.fuente in ('activos', 'depreciacion')
                 then 'Carga los activos fijos en Cierre, con la cédula del contador (costo, fecha y lo depreciado antes del libro).'
               when g.base = 'sin_auxiliar' and g.fuente = 'nomina'
                 then 'Su auxiliar llega con la nómina (f11). Mientras, escribe a mano de qué es el saldo (un renglón con su documento) o explícalo.'
               when g.base = 'sin_auxiliar'
                 then 'Escribe sus renglones a mano (qué es, cuánto, con qué documento y desde cuándo) hasta que sumen el saldo, o explícalo.'
               when g.fuente = 'conciliacion' and (g.despues is not null or g.conc_antes)
                 then format('Concilia la cuenta hasta el %s en Conciliar y confirma (si de verdad no se movió, es un minuto: el saldo del statement de ese día).', fn_cedula_dia(v_f))
               when g.fuente = 'conciliacion'
                 then 'Reabre esa conciliación en Conciliar y concíliala otra vez con lo que entró después.'
               when g.fuente = 'partidas' and g.forma = 'cobrar'
                 then 'Mira en Movimientos las líneas de esta cuenta que no dicen de qué factura son: si son un error, revérsalas y asiéntalas con su factura; si es un saldo que venía de QuickBooks, explícalo.'
               when g.fuente = 'partidas'
                 then 'Mira en Movimientos las líneas de esta cuenta que no dicen a quién se le deben: si son un error, revérsalas y asiéntalas con su proveedor; si no, escribe a mano lo que sostiene ese saldo o explícalo.'
               when g.fuente = 'prestamos' and g.par is not null and g.par_dif is not null and g.dif + g.par_dif = 0
                 then 'Haz el asiento de reclasificación entre las dos cuentas del préstamo (o explícalo si el contador lo deja para el corte del año).'
               when g.fuente = 'prestamos'
                 then 'Mira en Bancos qué falta: un préstamo sin registrar, su desembolso o una cuota. Lo que no sea un préstamo de cuotas se escribe a mano.'
               when g.fuente = 'prepagados' and g.despues is not null
                 then 'Mira la cédula de HOY: si hoy cuadra, lo de esa fecha fue un cargo que no era póliza y ya se corrigió (explícalo); si era la compra de una póliza, enlázala con su papel al registrarla.'
               when g.fuente = 'prepagados'
                 then 'Mira las pólizas: falta registrar una, amortizar un mes, o algo entró a esta cuenta que no es una póliza (eso se escribe a mano).'
               when g.fuente in ('activos', 'depreciacion')
                 then 'Mira los activos en Cierre: falta dar de alta uno (con lo depreciado antes del libro), registrar una baja, o postear la depreciación de un mes.'
               when g.fuente = 'wip'
                 then 'Vuelve a postear el ajuste del WIP de ese mes; un asiento a mano en estas cuentas se reversa.'
               when g.fuente in ('stripe', 'stripe_paso')
                 then 'Mira Cobros en línea; un asiento a mano en esta cuenta se reversa.'
               when g.fuente = 'devengos'
                 then 'Lo que no es un devengo que se deshace solo se escribe a mano (qué es y con qué documento) o se explica.'
               else 'Corrige sus renglones a mano hasta que sumen el saldo, o explica la diferencia.' end),
         (case when g.falta and g.ex_id is not null then g.ex_texto end),
         (case when g.falta and g.ex_id is not null then g.ex_el end),
         (case when g.falta and g.ex_id is not null then g.ex_por end),
         (case when g.falta and g.ex_id is not null then g.ex_nombre end),
         (case when g.falta and g.ex_id is not null then g.ex_id end),
         (g.falta and g.ex_id is not null and not g.ex_vale),
         g.sosten, g.par, coalesce(g.solo_reparto, false)
    from g
   order by g.cuenta;
end $$;
revoke execute on function public.fn_cedula(date) from public, anon, service_role;
grant  execute on function public.fn_cedula(date) to authenticated;
comment on function public.fn_cedula(date) is 'c13: LA CÉDULA DE CORTE a una fecha (sin fecha, el último día del período que toca): una fila por cuenta de balance (activo, pasivo y patrimonio) con su saldo en el libro (saldo_libro, en su lado natural; signo lo pasa a debe − haber), de dónde sale su auxiliar (fuente, auxiliar, origen, auxiliar_al), lo que suma el auxiliar (saldo_auxiliar), la diferencia, cuántos renglones tiene y cuántos no casan uno a uno (descuadres), lo que es a mano (manual), lo que el libro movió después de la última conciliación (despues) y lo que tiene sin decir de qué es (sueltas); su estado (cuadra | explicada | no_cuadra | sin_auxiliar | del_libro: sale del propio libro, o su papel es de otro día y se lleva a la fecha con el libro; no pide nada y no cuenta como «cuadra»), si pide algo (pendiente), por qué no tiene auxiliar (por_que: capa | vacio | manual | f11 | error), el detalle y qué hacer en llano, la explicación viva de esa fecha (texto, quién, cuándo) con explicacion_vieja si el saldo cambió después, qué hay debajo (sosten: papel | partidas | libro | llevado), y en un préstamo su otra cuenta (par) y si su diferencia es solo el reparto entre corriente y largo plazo (solo_reparto). «cuadra» pide que el auxiliar valga para ese día (un banco con su última conciliación anterior al día no cuadra aunque la resta dé cero) y que nada quede suelto (dos obras que se compensan no cuadran). Solo lectura; a quien no es el dueño, nada.';

-- LOS TOTALES de la cédula de un día, para la pantalla (que no suma):
--   {fecha, hoy, periodo (el mes de esa fecha, si es su último día),
--    cuentas, con_saldo, cuadran (de ellas: cuadran_papel, contra algo que
--    no es el libro; cuadran_partidas, por las partidas del propio libro),
--    del_libro (salen del propio libro o se llevan a la fecha con él: no se
--    cuentan entre las que cuadran), explicadas, no_cuadran, sin_auxiliar
--    (con saldo), pendientes, explicaciones_viejas, listo (nada pendiente),
--    activo, pasivo, capital (cada total como sale en el balance: lo
--    contrario resta), resultado (el resultado acumulado que todavía no
--    está en el patrimonio: ingresos menos costos y gastos hasta ese día,
--    de las cuentas de resultados del libro) y patrimonio_total (capital +
--    resultado): ACTIVO = PASIVO + CAPITAL + RESULTADO, siempre
--    (balance_cuadra lo dice),
--    diferencia_pendiente (la suma de las diferencias de lo que no cuadra,
--    en valor absoluto, SIN contar el reparto de un préstamo entre corriente
--    y largo plazo cuando su total cuadra), reparto_pendiente (lo que hay
--    que pasar de una cuenta a la otra en esos préstamos) y reparto_cuentas
--    (cuántas cuentas son), y sin_respaldo (la suma de los saldos sin
--    auxiliar ni explicación, en valor absoluto)}
create or replace function public.fn_cedula_resumen(p_fecha date default null) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_f   date;
  v_hoy date := fn_fecha_miami(now());
  v     jsonb;
  v_res numeric;
begin
  perform fn_cedula_exigir_dueno();
  v_f := coalesce(p_fecha, (select q.hasta from periodos q where q.periodo = fn_cedula_toca()), v_hoy);
  -- El resultado acumulado que todavía no está en el patrimonio: lo que suman las cuentas de resultados (ingresos, costos y
  -- gastos) hasta ese día, como utilidad (positivo) o pérdida (negativo). Con él el balance cierra a la vista.
  select coalesce(-sum(l.monto), 0)::numeric(14,2) into v_res
    from asiento_lineas l
    join asientos a on a.id = l.asiento_id
    join cuentas k on k.codigo = l.cuenta
   where a.fecha_contable <= v_f and k.tipo not in ('activo', 'pasivo', 'capital');
  select jsonb_build_object(
           'fecha', v_f, 'hoy', v_hoy,
           'periodo', (select q.periodo from periodos q where q.tipo in ('mes', 'apertura') and q.hasta = v_f order by q.desde limit 1),
           'cuentas', count(*),
           'con_saldo', count(*) filter (where c.saldo_libro <> 0),
           'cuadran', count(*) filter (where c.estado = 'cuadra'),
           'cuadran_papel', count(*) filter (where c.estado = 'cuadra' and c.sosten is distinct from 'partidas'),
           'cuadran_partidas', count(*) filter (where c.estado = 'cuadra' and c.sosten = 'partidas'),
           'del_libro', count(*) filter (where c.estado = 'del_libro'),
           'explicadas', count(*) filter (where c.estado = 'explicada'),
           'no_cuadran', count(*) filter (where c.estado = 'no_cuadra'),
           'sin_auxiliar', count(*) filter (where c.estado = 'sin_auxiliar' and c.saldo_libro <> 0),
           'pendientes', count(*) filter (where c.pendiente),
           'explicaciones_viejas', count(*) filter (where c.explicacion_vieja),
           'listo', count(*) filter (where c.pendiente) = 0,
           'activo', coalesce(sum(c.signo * c.saldo_libro) filter (where c.tipo = 'activo'), 0)::numeric(14,2),
           'pasivo', coalesce(-sum(c.signo * c.saldo_libro) filter (where c.tipo = 'pasivo'), 0)::numeric(14,2),
           'capital', coalesce(-sum(c.signo * c.saldo_libro) filter (where c.tipo = 'capital'), 0)::numeric(14,2),
           'resultado', v_res,
           'patrimonio_total', (coalesce(-sum(c.signo * c.saldo_libro) filter (where c.tipo = 'capital'), 0) + v_res)::numeric(14,2),
           'balance_cuadra', coalesce(sum(c.signo * c.saldo_libro), 0) = v_res,
           'diferencia_pendiente', coalesce(sum(abs(c.diferencia)) filter (where c.pendiente and c.estado = 'no_cuadra' and not c.solo_reparto), 0)::numeric(14,2),
           'reparto_pendiente', (coalesce(sum(abs(c.diferencia)) filter (where c.pendiente and c.estado = 'no_cuadra' and c.solo_reparto), 0) / 2)::numeric(14,2),
           'reparto_cuentas', count(*) filter (where c.pendiente and c.estado = 'no_cuadra' and c.solo_reparto),
           'sin_respaldo', coalesce(sum(abs(c.saldo_libro)) filter (where c.pendiente and c.estado = 'sin_auxiliar'), 0)::numeric(14,2))
    into v
    from fn_cedula(v_f) c;
  return v;
end $$;
revoke execute on function public.fn_cedula_resumen(date) from public, anon, service_role;
grant  execute on function public.fn_cedula_resumen(date) to authenticated;
comment on function public.fn_cedula_resumen(date) is 'c13: los totales de la cédula de un día (sin fecha, el último día del período que toca), para la pantalla, que no suma: {fecha, hoy, periodo, cuentas, con_saldo, cuadran (cuadran_papel, cuadran_partidas), del_libro, explicadas, no_cuadran, sin_auxiliar (con saldo), pendientes, explicaciones_viejas, listo, activo, pasivo, capital, resultado (el resultado acumulado sin cerrar: activo = pasivo + capital + resultado), patrimonio_total, balance_cuadra, diferencia_pendiente (sin el reparto de un préstamo cuyo total cuadra), reparto_pendiente, reparto_cuentas, sin_respaldo}. Solo el dueño.';

-- LOS PERÍODOS QUE TIENEN UNA BALANZA DE QUICKBOOKS con que comparar (c4): la
-- de la apertura y las que Edgar haya cargado. Sin c4, ninguno.
create or replace function public.fn_cedula_qb_periodos() returns table (periodo text)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
begin
  if not fn_cedula_ve() or not coalesce((fn_cedula_capas()->>'c4')::boolean, false) then
    return;
  end if;
  begin
    return query execute 'select distinct b.periodo::text from public.v_qb_balanzas b where b.vigente and b.tipo = ''balanza''';
  exception when others then
    return;
  end;
end $$;
revoke execute on function public.fn_cedula_qb_periodos() from public, anon, service_role;
grant  execute on function public.fn_cedula_qb_periodos() to authenticated;
comment on function public.fn_cedula_qb_periodos() is 'c13: los períodos que tienen una balanza de QuickBooks vigente con que comparar (c4: la de la apertura y las cargadas). Sin c4, ninguno. Solo lectura; a quien no es el dueño, nada.';

-- LA CÉDULA AL LADO DE QUICKBOOKS (para la 12b). De un período: la cédula a
-- la fecha de su balanza de QuickBooks (la que c4 usa: el último día del
-- período, o la fecha que dijo su carga), y de cada cuenta lo que c4 dice de
-- ella (v_comparacion): lo que tiene QuickBooks, la diferencia con el libro,
-- lo explicado en c4 y lo que queda sin explicar. Todo en el lado natural de
-- la cuenta. Sin balanza cargada (o sin c4), las columnas de QuickBooks
-- salen vacías y qb_cargada lo dice.
--   periodo, al, documento, qb_cargada
--   orden, cuenta, nombre, tipo
--   saldo_libro, auxiliar, saldo_auxiliar, diferencia, estado, pendiente   (de la cédula)
--   libro_comparable   el libro como c4 lo compara (con el arrastre de la
--                      apertura en 3900 y los ajustes posteriores del
--                      contador si la balanza es la final)
--   saldo_qb           lo que dice QuickBooks
--   diferencia_qb      libro_comparable − saldo_qb
--   explicada_qb       lo anotado en c4 (sus diferencias explicadas)
--   sin_explicar_qb    lo que queda; qb_ok = sin_explicar_qb en cero
--   libro_igual        el saldo de c4 a esa fecha es el de la cédula
--   amarra             QuickBooks contra el libro (igual o explicado en c4)
--                      Y el libro contra su auxiliar (cuadra o explicado
--                      aquí, o sin saldo)
drop function if exists public.fn_cedula_qb(text);
create function public.fn_cedula_qb(p_periodo text default null)
returns table (periodo text, al date, documento text, qb_cargada boolean, orden int, cuenta text, nombre text, tipo text,
               saldo_libro numeric(14,2), auxiliar text, saldo_auxiliar numeric(14,2), diferencia numeric(14,2), estado text,
               pendiente boolean, libro_comparable numeric(14,2), saldo_qb numeric(14,2), diferencia_qb numeric(14,2),
               explicada_qb numeric(14,2), sin_explicar_qb numeric(14,2), qb_ok boolean, libro_igual boolean, amarra boolean)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_per   text := coalesce(p_periodo, fn_cedula_toca());
  per     periodos;
  v_al    date;
  v_doc   text;
  v_n     bigint := 0;
  v_qb    jsonb := '{}'::jsonb;
begin
  if not fn_cedula_ve() then
    return;
  end if;
  select * into per from periodos q where q.periodo = v_per;
  if not found then
    raise exception using errcode = '22023',
      message = format('No existe el período %s.', coalesce(v_per, '(ninguno)'));
  end if;
  if coalesce((fn_cedula_capas()->>'c4')::boolean, false) then
    begin
      execute 'select max(v.al), min(v.documento), count(*), '
           || 'coalesce(jsonb_object_agg(v.cuenta, jsonb_build_object(''libro'', v.libro, ''comparable'', v.comparable, ''qb'', v.qb, '
           || '''diferencia'', v.diferencia, ''explicada'', v.explicada, ''sin_explicar'', v.sin_explicar, ''ok'', v.ok)) '
           || 'filter (where v.cuenta is not null), ''{}''::jsonb) '
           || 'from public.v_comparacion v where v.periodo = $1 and v.nivel = ''cuenta'''
         into v_al, v_doc, v_n, v_qb using per.periodo;
    exception when others then
      v_n := 0; v_qb := '{}'::jsonb; v_al := null; v_doc := null;
    end;
  end if;
  v_al := coalesce(v_al, per.hasta);
  return query
  select per.periodo, v_al, v_doc, v_n > 0, c.orden, c.cuenta, c.nombre, c.tipo,
         c.saldo_libro, c.auxiliar, c.saldo_auxiliar, c.diferencia, c.estado, c.pendiente,
         (case when v_n > 0 then c.signo * coalesce((v_qb->c.cuenta->>'comparable')::numeric, 0) end)::numeric(14,2),
         (case when v_n > 0 then c.signo * coalesce((v_qb->c.cuenta->>'qb')::numeric, 0) end)::numeric(14,2),
         (case when v_n > 0 then c.signo * coalesce((v_qb->c.cuenta->>'diferencia')::numeric, 0) end)::numeric(14,2),
         (case when v_n > 0 then c.signo * coalesce((v_qb->c.cuenta->>'explicada')::numeric, 0) end)::numeric(14,2),
         (case when v_n > 0 then c.signo * coalesce((v_qb->c.cuenta->>'sin_explicar')::numeric, 0) end)::numeric(14,2),
         (case when v_n > 0 then coalesce((v_qb->c.cuenta->>'ok')::boolean, true) end),
         (case when v_n > 0 then c.signo * coalesce((v_qb->c.cuenta->>'libro')::numeric, 0) = c.saldo_libro end),
         (case when v_n > 0 then coalesce((v_qb->c.cuenta->>'ok')::boolean, true) and not c.pendiente end)
    from fn_cedula(v_al) c
   order by c.orden;
end $$;
revoke execute on function public.fn_cedula_qb(text) from public, anon, service_role;
grant  execute on function public.fn_cedula_qb(text) to authenticated;
comment on function public.fn_cedula_qb(text) is 'c13: la cédula de un período al lado de QuickBooks (para el cuadre de la 12b): la cédula a la fecha de la balanza de QuickBooks de ese período (al, documento; qb_cargada dice si hay balanza) y, de cada cuenta, lo que la comparación de c4 dice de ella, en el lado natural de la cuenta: libro_comparable, saldo_qb, diferencia_qb, explicada_qb (lo anotado en c4), sin_explicar_qb y qb_ok; libro_igual (el saldo de c4 es el de la cédula) y amarra (QuickBooks contra el libro y el libro contra su auxiliar, los dos bien). No carga nada de QuickBooks: eso es de c4. Sin período, el que toca. Solo lectura; a quien no es el dueño, nada.';


-- ---------------------------------------------------------------------
-- 6. LO QUE ESCRIBE LA PANTALLA (como el dueño): la configuración, los
--    renglones a mano y las explicaciones. SECURITY INVOKER, con es_dueno()
--    por dentro; escriben con la marca de la guarda. Nada de aquí postea.
-- ---------------------------------------------------------------------
-- LA CONFIGURACIÓN. Sin argumentos (o con {}) la devuelve; con
-- {"avisar_desde": "2026-11" | null, "patrimonio": "mayor" | "manual"}
-- cambia lo que traiga, y el valor anterior queda en su historial.
create or replace function public.fn_cedula_config(p jsonb default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c       cedula_config;
  v_sobra text;
  v_desde text;
  v_patr  text;
begin
  perform fn_cedula_exigir_dueno();
  if p is not null and jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'La configuración llega como un objeto JSON.';
  end if;
  if p is null or p = '{}'::jsonb then
    select * into c from cedula_config where id = 1;
    return to_jsonb(c);
  end if;
  select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(p) k where k not in ('avisar_desde', 'patrimonio');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en la configuración de la cédula: %s.', v_sobra);
  end if;
  if p ? 'avisar_desde' and jsonb_typeof(p->'avisar_desde') <> 'null' and btrim(p->>'avisar_desde') <> '' then
    v_desde := btrim(p->>'avisar_desde');
    if v_desde !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
      raise exception using errcode = '22023',
        message = format('«%s» no es un mes: va como AAAA-MM (2026-11), o vacío para que el cierre no avise todavía.', p->>'avisar_desde');
    end if;
  end if;
  if p ? 'patrimonio' then
    v_patr := lower(btrim(coalesce(p->>'patrimonio', '')));
    if v_patr not in ('mayor', 'manual') then
      raise exception using errcode = '22023',
        message = 'El patrimonio se sostiene con su «mayor» (lo que trajo la apertura más sus movimientos) o «manual» (renglones escritos a mano).';
    end if;
  end if;
  select * into c from cedula_config where id = 1 for update;
  perform set_config('mx_cedula.escribe', 'cedula_config', true);
  update cedula_config
     set avisar_desde    = case when p ? 'avisar_desde' then v_desde else avisar_desde end,
         patrimonio      = coalesce(v_patr, patrimonio),
         actualizado     = now(),
         actualizado_por = auth.uid(),
         historial       = (select coalesce(jsonb_agg(h.x order by h.n), '[]'::jsonb)
                              from (select y.x, y.n
                                      from jsonb_array_elements(c.historial
                                             || jsonb_build_object('el', now(), 'por', auth.uid(), 'avisar_desde', c.avisar_desde,
                                                                   'patrimonio', c.patrimonio)) with ordinality as y(x, n)
                                     order by y.n desc limit 50) h)
   where id = 1
  returning * into c;
  perform set_config('mx_cedula.escribe', '', true);
  return to_jsonb(c);
end $$;
revoke execute on function public.fn_cedula_config(jsonb) from public, anon, service_role;
grant  execute on function public.fn_cedula_config(jsonb) to authenticated;
comment on function public.fn_cedula_config(jsonb) is 'c13: la configuración de la cédula. Sin argumentos (o {}) la devuelve; con {"avisar_desde": "AAAA-MM" | null (o vacío: el cierre todavía no avisa), "patrimonio": "mayor" | "manual"} cambia lo que traiga (22023 si viene mal) y deja el valor anterior en su historial. Solo el dueño.';

-- UN RENGLÓN A MANO. p: {"cuenta": "1600", "concepto": "Depósito en garantía
-- de la bodega", "monto": "1500.00", "desde": "2026-09-30", "hasta"?:
-- "2027-03-31", "documento"?: "Contrato de renta, cláusula 4", "nota"?: "…"}.
-- El monto va como texto, en el lado natural de la cuenta (positivo = lo
-- normal; negativo, lo contrario). «desde» es el día desde el que está en el
-- saldo (el del documento; el 30-sep-2026 si venía de QuickBooks); «hasta»,
-- el último día que estuvo (vacío = sigue). Con "id" CORRIGE ese renglón: lo
-- que no se diga se queda como estaba, el anterior queda sustituido (no se
-- pierde) y la cuenta no cambia (para pasarlo a otra cuenta: anularlo y
-- escribir otro). Devuelve el renglón como quedó.
create or replace function public.fn_cedula_renglon(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c_fecha constant text := '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';
  v_sobra text;
  v_id    uuid;
  o       cedula_manual;
  n       cedula_manual;
  k       cuentas;
  v_t     text;
begin
  perform fn_cedula_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'El renglón llega como un objeto JSON.';
  end if;
  select string_agg(x, ', ' order by x) into v_sobra
    from jsonb_object_keys(p) x where x not in ('id', 'cuenta', 'concepto', 'monto', 'documento', 'nota', 'desde', 'hasta');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en el renglón: %s.', v_sobra);
  end if;
  if p ? 'id' and jsonb_typeof(p->'id') <> 'null' then
    begin
      v_id := (p->>'id')::uuid;
    exception when others then
      raise exception using errcode = '22023', message = format('«%s» no es el id de un renglón.', p->>'id');
    end;
    select * into o from cedula_manual m where m.id = v_id for update;
    if not found then
      raise exception using errcode = '22023', message = 'No existe ese renglón.';
    end if;
    if o.anulado_el is not null or o.sustituido_el is not null then
      raise exception using errcode = 'MX008',
        message = case when o.anulado_el is not null then 'Ese renglón ya está anulado: escribe uno nuevo.'
                       else 'Ese renglón ya se corrigió: corrige su versión vigente.' end;
    end if;
    if p ? 'cuenta' and btrim(coalesce(p->>'cuenta', '')) is distinct from o.cuenta then
      raise exception using errcode = '22023',
        message = format('Un renglón no cambia de cuenta (es de la %s): anúlalo y escribe otro en la cuenta buena.', o.cuenta);
    end if;
  end if;
  n.cuenta := coalesce(o.cuenta, nullif(btrim(coalesce(p->>'cuenta', '')), ''));
  if n.cuenta is null then
    raise exception using errcode = '22023', message = 'Falta la cuenta del renglón.';
  end if;
  select * into k from cuentas q where q.codigo = n.cuenta;
  if not found or k.tipo not in ('activo', 'pasivo', 'capital') or not k.imputable then
    raise exception using errcode = 'MX004',
      message = format('La cuenta %s no sirve para la cédula: %s.', n.cuenta,
                       case when k.codigo is null then 'no existe'
                            when not k.imputable then 'es de grupo (no tiene saldo propio)'
                            else 'no es de balance (la cédula es de activo, pasivo y patrimonio)' end);
  end if;
  n.concepto := coalesce(nullif(btrim(coalesce(p->>'concepto', '')), ''), o.concepto);
  if n.concepto is null or length(n.concepto) < 3 then
    raise exception using errcode = '22023', message = 'Falta decir qué es (el concepto del renglón, con sus palabras).';
  end if;
  if p ? 'monto' then
    n.monto := fn_cedula_monto(p->>'monto', 'el monto');
  else
    n.monto := o.monto;
  end if;
  if n.monto is null then
    raise exception using errcode = 'MX005', message = 'Falta el monto.';
  end if;
  -- desde y hasta, como texto AAAA-MM-DD
  if p ? 'desde' then
    v_t := btrim(coalesce(p->>'desde', ''));
    if v_t !~ c_fecha then
      raise exception using errcode = '22023', message = format('«%s» no es una fecha: «desde» va como AAAA-MM-DD.', p->>'desde');
    end if;
    begin
      n.desde := v_t::date;
    exception when others then
      raise exception using errcode = '22023', message = format('«%s» no es una fecha que exista.', v_t);
    end;
  else
    n.desde := o.desde;
  end if;
  if n.desde is null then
    raise exception using errcode = '22023',
      message = 'Falta desde qué día vale (desde, AAAA-MM-DD): la fecha de su documento, o el 30 de septiembre de 2026 si venía de QuickBooks.';
  end if;
  if p ? 'hasta' then
    if jsonb_typeof(p->'hasta') = 'null' or btrim(coalesce(p->>'hasta', '')) = '' then
      n.hasta := null;
    else
      v_t := btrim(p->>'hasta');
      if v_t !~ c_fecha then
        raise exception using errcode = '22023', message = format('«%s» no es una fecha: «hasta» va como AAAA-MM-DD.', p->>'hasta');
      end if;
      begin
        n.hasta := v_t::date;
      exception when others then
        raise exception using errcode = '22023', message = format('«%s» no es una fecha que exista.', v_t);
      end;
    end if;
  else
    n.hasta := o.hasta;
  end if;
  if n.hasta is not null and n.hasta < n.desde then
    raise exception using errcode = '22023',
      message = format('El renglón no puede acabar (%s) antes de empezar (%s).', n.hasta, n.desde);
  end if;
  n.documento := case when p ? 'documento' then nullif(btrim(coalesce(p->>'documento', '')), '') else o.documento end;
  n.nota      := case when p ? 'nota' then nullif(btrim(coalesce(p->>'nota', '')), '') else o.nota end;

  perform set_config('mx_cedula.escribe', 'cedula_manual', true);
  insert into cedula_manual (cuenta, concepto, monto, documento, nota, desde, hasta, sustituye_a, creado_por)
  values (n.cuenta, n.concepto, n.monto, n.documento, n.nota, n.desde, n.hasta, o.id, auth.uid())
  returning * into n;
  if o.id is not null then
    update cedula_manual set sustituido_el = now() where id = o.id;
  end if;
  perform set_config('mx_cedula.escribe', '', true);
  return to_jsonb(n);
end $$;
revoke execute on function public.fn_cedula_renglon(jsonb) from public, anon, service_role;
grant  execute on function public.fn_cedula_renglon(jsonb) to authenticated;
comment on function public.fn_cedula_renglon(jsonb) is 'c13: escribe un renglón a mano en el auxiliar de una cuenta de balance: {"cuenta", "concepto", "monto" (texto, en el lado natural de la cuenta), "desde" (AAAA-MM-DD), "hasta"?, "documento"?, "nota"?}; con "id" corrige ese (lo no dicho se queda; el anterior queda sustituido; la cuenta no cambia). MX004 si la cuenta no es de balance o es de grupo, MX005 si el monto está mal, MX008 si el renglón ya estaba anulado o corregido, 22023 si falta algo. No postea nada. Devuelve el renglón. Solo el dueño.';

-- ANULAR UN RENGLÓN que estaba mal (nunca debió contar), con su motivo. El
-- que dejó de estar en el saldo no se anula: se le pone su «hasta».
create or replace function public.fn_cedula_renglon_anular(p_id uuid, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  o cedula_manual;
begin
  perform fn_cedula_exigir_dueno();
  select * into o from cedula_manual m where m.id = p_id for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese renglón.';
  end if;
  if o.anulado_el is not null or o.sustituido_el is not null then
    raise exception using errcode = 'MX008',
      message = case when o.anulado_el is not null then 'Ese renglón ya estaba anulado.'
                     else 'Ese renglón ya se corrigió: anula su versión vigente.' end;
  end if;
  if coalesce(length(btrim(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'Anular un renglón dice por qué (el motivo).';
  end if;
  perform set_config('mx_cedula.escribe', 'cedula_manual', true);
  update cedula_manual set anulado_el = now(), anulado_por = auth.uid(), anulado_motivo = btrim(p_motivo) where id = o.id
  returning * into o;
  perform set_config('mx_cedula.escribe', '', true);
  return to_jsonb(o);
end $$;
revoke execute on function public.fn_cedula_renglon_anular(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_cedula_renglon_anular(uuid, text) to authenticated;
comment on function public.fn_cedula_renglon_anular(uuid, text) is 'c13: anula, con su motivo, un renglón a mano que estaba mal (deja de contar en todas las fechas; queda como rastro). MX008 si ya estaba anulado o corregido. El que dejó de estar en el saldo no se anula: se corrige poniéndole su «hasta». Solo el dueño.';

-- EXPLICAR UNA DIFERENCIA: por qué esa cuenta no cuadra con su auxiliar (o no
-- lo tiene) a esa fecha. Guarda el texto, quién, cuándo y los números con
-- que se explicó; si ya había una explicación viva de esa cuenta y esa
-- fecha, la sustituye (la anterior queda). Vale para esa fecha y esos
-- números: si después cambian, la cédula dice que se quedó vieja.
create or replace function public.fn_cedula_explicar(p_cuenta text, p_fecha date, p_texto text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_cta   text := nullif(btrim(coalesce(p_cuenta, '')), '');
  v_txt   text := btrim(coalesce(p_texto, ''));
  v_hoy   date := fn_fecha_miami(now());
  k       cuentas;
  r       record;
  v_base  text;
  v_ant   uuid;
  e       cedula_explicaciones;
  v_sue   numeric(14,2);
begin
  perform fn_cedula_exigir_dueno();
  if v_cta is null then
    raise exception using errcode = '22023', message = 'Falta la cuenta que se explica.';
  end if;
  if p_fecha is null then
    raise exception using errcode = '22023', message = 'Falta la fecha de la cédula que se explica.';
  end if;
  if p_fecha > v_hoy then
    raise exception using errcode = '22023',
      message = format('El %s todavía no llega: se explica lo que ya pasó.', fn_cedula_dia(p_fecha));
  end if;
  if length(v_txt) < 10 then
    raise exception using errcode = '22023',
      message = 'La explicación dice por qué, con tus palabras (una frase, no una letra): qué es esa diferencia y con qué papel se sostiene.';
  end if;
  select * into k from cuentas q where q.codigo = v_cta;
  if not found or k.tipo not in ('activo', 'pasivo', 'capital') or not k.imputable then
    raise exception using errcode = 'MX004',
      message = format('La cuenta %s no está en la cédula: %s.', v_cta,
                       case when k.codigo is null then 'no existe'
                            when not k.imputable then 'es de grupo (no tiene saldo propio)'
                            else 'no es de balance (la cédula es de activo, pasivo y patrimonio)' end);
  end if;
  -- Una explicación a la vez por cuenta y fecha.
  perform pg_advisory_xact_lock(820261113, hashtext('cedula:' || v_cta || ':' || p_fecha::text));
  select c.estado, c.saldo_libro, c.saldo_auxiliar, c.diferencia into r from fn_cedula(p_fecha) c where c.cuenta = v_cta;
  if not found then
    raise exception using errcode = 'MX008',
      message = format('La %s no tiene saldo ni movimiento al %s: no hay nada que explicar.', v_cta, fn_cedula_dia(p_fecha));
  end if;
  v_base := case when r.estado <> 'explicada' then r.estado
                 when r.saldo_auxiliar is null then 'sin_auxiliar' else 'no_cuadra' end;
  if v_base = 'cuadra' then
    raise exception using errcode = 'MX008',
      message = format('La %s (%s) cuadra con su auxiliar al %s: no hay nada que explicar.', v_cta, k.nombre, fn_cedula_dia(p_fecha));
  end if;
  if v_base = 'del_libro' then
    raise exception using errcode = 'MX008',
      message = format('La %s (%s) no pide nada al %s: sale del propio libro, o su papel es de otro día. No hay una diferencia que '
                       'explicar; si quieres compararla con un papel, escríbele sus renglones a mano.', v_cta, k.nombre, fn_cedula_dia(p_fecha));
  end if;
  if v_base = 'sin_auxiliar' and r.saldo_libro = 0 then
    raise exception using errcode = 'MX008',
      message = format('La %s (%s) no tiene saldo al %s: no hay nada que explicar.', v_cta, k.nombre, fn_cedula_dia(p_fecha));
  end if;
  perform set_config('mx_cedula.escribe', 'cedula_explicaciones', true);
  update cedula_explicaciones x set sustituida_el = now()
   where x.cuenta = v_cta and x.fecha = p_fecha and x.sustituida_el is null and x.retirada_el is null
  returning x.id into v_ant;
  select coalesce(sum(abs(i.libro)), 0) into v_sue from fn_cedula_partidas(p_fecha, v_cta) i where i.clase = 'suelto';
  insert into cedula_explicaciones (cuenta, fecha, texto, estado, saldo_libro, saldo_auxiliar, diferencia, explicado_por, sueltas_abs)
  values (v_cta, p_fecha, v_txt, v_base, r.saldo_libro, r.saldo_auxiliar, r.diferencia, auth.uid(), v_sue)
  returning * into e;
  perform set_config('mx_cedula.escribe', '', true);
  return to_jsonb(e) || jsonb_build_object('sustituye_a', v_ant);
end $$;
revoke execute on function public.fn_cedula_explicar(text, date, text) from public, anon, service_role;
grant  execute on function public.fn_cedula_explicar(text, date, text) to authenticated;
comment on function public.fn_cedula_explicar(text, date, text) is 'c13: explica por qué una cuenta de balance no cuadra con su auxiliar (o no lo tiene) a una fecha: guarda el texto, quién, cuándo y los números con que se explicó (saldo del libro, del auxiliar, la diferencia y lo que la cuenta tenía suelto, sin decir de qué es); si ya había una explicación viva de esa cuenta y esa fecha, la sustituye (queda). Vale para esa fecha y esos números. MX004 si la cuenta no es de balance, MX008 si la cuenta cuadra, sale del propio libro o no tiene saldo (nada que explicar), 22023 si falta la fecha, todavía no llega o el texto es demasiado corto. Devuelve la explicación y «sustituye_a». Solo el dueño.';

-- RETIRAR UNA EXPLICACIÓN que ya no vale, con su motivo (queda como rastro;
-- la cuenta vuelve a como esté).
create or replace function public.fn_cedula_explicacion_retirar(p_cuenta text, p_fecha date, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  e cedula_explicaciones;
begin
  perform fn_cedula_exigir_dueno();
  if coalesce(length(btrim(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'Retirar una explicación dice por qué (el motivo).';
  end if;
  select * into e from cedula_explicaciones x
   where x.cuenta = btrim(coalesce(p_cuenta, '')) and x.fecha = p_fecha and x.sustituida_el is null and x.retirada_el is null
     for update;
  if not found then
    raise exception using errcode = 'MX008',
      message = format('La %s no tiene una explicación viva al %s: no hay nada que retirar.', coalesce(p_cuenta, '(sin cuenta)'),
                       coalesce(fn_cedula_dia(p_fecha), '(sin fecha)'));
  end if;
  perform set_config('mx_cedula.escribe', 'cedula_explicaciones', true);
  update cedula_explicaciones set retirada_el = now(), retirada_por = auth.uid(), retirada_motivo = btrim(p_motivo) where id = e.id
  returning * into e;
  perform set_config('mx_cedula.escribe', '', true);
  return to_jsonb(e);
end $$;
revoke execute on function public.fn_cedula_explicacion_retirar(text, date, text) from public, anon, service_role;
grant  execute on function public.fn_cedula_explicacion_retirar(text, date, text) to authenticated;
comment on function public.fn_cedula_explicacion_retirar(text, date, text) is 'c13: retira, con su motivo, la explicación viva de una cuenta a una fecha (queda como rastro; la cuenta vuelve a como esté). MX008 si no hay ninguna viva. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 7. EL CONTROL DE LA CÉDULA (cabecera) y su fila para el cierre (c9).
--    Solo lectura; a quien no es el dueño, nada. El texto, en llano.
-- ---------------------------------------------------------------------
drop function if exists public.fn_cedula_control(text);
create function public.fn_cedula_control(p_periodo text default null)
returns table (orden int, control text, nivel text, ok boolean, detalle text)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  cfg       cedula_config;
  per       periodos;
  v_per     text := coalesce(p_periodo, fn_cedula_toca());
  v_hoy     date := fn_fecha_miami(now());
  v_f       date;
  v_nom     text;
  v_mnom    text;
  v_mira    boolean := true;   -- se mira ya (el período terminó y el cierre avisa desde antes o desde él)
  v_cuando  text;
  v_filas   jsonb := '[]'::jsonb;
  v_n       bigint;
  v_n2      bigint;
  v_t       text;
  v_s       numeric;
  v_s2      numeric;
begin
  if not fn_cedula_ve() then
    return;
  end if;
  select * into cfg from cedula_config c where c.id = 1;
  select * into per from periodos q where q.periodo = v_per;
  if found then
    v_f    := per.hasta;
    v_nom  := fn_cedula_mes(per.periodo);
    v_mnom := initcap(left(v_nom, 1)) || substr(v_nom, 2);
    v_cuando := case when cfg.avisar_desde is null
                       then 'El cierre todavía no avisa de la cédula en ningún mes (no se ha dicho desde cuál).'
                     when per.hasta < to_date(cfg.avisar_desde || '-01', 'YYYY-MM-DD')
                       then format('El cierre avisa de la cédula desde %s; %s es anterior.', fn_cedula_mes(cfg.avisar_desde), v_nom)
                     when per.hasta >= v_hoy
                       then format('%s termina el %s: la cédula se mira al cerrar.', v_mnom, fn_cedula_dia(per.hasta)) end;
    v_mira := v_cuando is null;
  else
    -- sin período (el libro todavía no tiene ninguno terminado, o ese no existe): la de hoy, sin avisar
    v_f := v_hoy;
    v_nom := 'hoy';
    v_mira := false;
    v_cuando := case when p_periodo is not null then format('El período %s no existe: esta es la cédula de hoy.', p_periodo)
                     else 'Todavía no hay ningún mes terminado: esta es la cédula de hoy.' end;
  end if;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.orden), '[]'::jsonb) into v_filas from fn_cedula(v_f) c;

  -- 10. La cédula trae todas las cuentas de balance (las activas y las que
  --     tienen movimiento) y sus saldos suman lo que el libro tiene en las
  --     cuentas de balance a esa fecha. No pinta ceros callada.
  select count(*), left(string_agg(k.codigo, ', ' order by k.codigo), 300) into v_n, v_t
    from cuentas k
   where k.tipo in ('activo', 'pasivo', 'capital') and k.imputable
     and (coalesce((to_jsonb(k)->>'activa')::boolean, true)
          or exists (select 1 from asiento_lineas l join asientos a on a.id = l.asiento_id
                      where l.cuenta = k.codigo and a.fecha_contable <= v_f))
     and not exists (select 1 from jsonb_to_recordset(v_filas) as c(cuenta text) where c.cuenta = k.codigo);
  select coalesce(sum(l.monto), 0) into v_s
    from asiento_lineas l
    join asientos a on a.id = l.asiento_id
    join cuentas k on k.codigo = l.cuenta
   where k.tipo in ('activo', 'pasivo', 'capital') and a.fecha_contable <= v_f;
  select coalesce(sum(c.signo * c.saldo_libro), 0), count(*) into v_s2, v_n2
    from jsonb_to_recordset(v_filas) as c(signo int, saldo_libro numeric);
  orden := 10; control := 'cédula: trae todas las cuentas de balance y su saldo es el del libro'; nivel := 'cuadre';
  ok := v_n = 0 and v_s = v_s2;
  detalle := case when v_n = 0 and v_s = v_s2
                  then format('La cédula al %s trae las %s cuentas de balance, y sus saldos suman lo mismo que el libro.',
                              fn_cedula_dia(v_f), v_n2)
                  else concat_ws(' ',
                         case when v_n > 0 then format('A la cédula al %s le faltan %s cuenta(s) de balance: %s.', fn_cedula_dia(v_f), v_n, v_t) end,
                         case when v_s <> v_s2
                              then format('Los saldos de la cédula suman %s y el libro tiene %s en las cuentas de balance a esa fecha.',
                                          fn_cedula_usd(v_s2), fn_cedula_usd(v_s)) end,
                         'No te fíes de la cédula hasta arreglarlo: avisa.') end;
  return next;

  -- 20. Cada saldo con su auxiliar cuadrado o explicado.
  select count(*),
         left(string_agg(format('%s %s (%s)', c.cuenta, c.nombre,
                                case when c.diferencia = 0 then 'su auxiliar no vale para ese día, o tiene renglones sueltos'
                                     else fn_cedula_usd(c.diferencia) || ' de diferencia' end), '; ' order by c.cuenta), 900)
    into v_n, v_t
    from jsonb_to_recordset(v_filas)
         as c(cuenta text, nombre text, estado text, pendiente boolean, diferencia numeric, explicacion_vieja boolean)
   where c.pendiente and c.estado = 'no_cuadra' and not c.explicacion_vieja;
  select count(*) filter (where c.estado = 'cuadra'), count(*) filter (where c.estado = 'explicada'),
         count(*) filter (where c.estado = 'del_libro') into v_n2, v_s, v_s2
    from jsonb_to_recordset(v_filas) as c(estado text);
  orden := 20; control := 'cédula: cada saldo con su auxiliar cuadrado o explicado'; nivel := 'aviso';
  ok := v_n = 0 or not v_mira;
  detalle := case when not v_mira
                  then v_cuando || case when v_n > 0 then format(' Hoy saldrían %s cuenta(s) sin cuadrar ni explicar.', v_n) else '' end
                  when v_n = 0
                  then format('Al %s ninguna cuenta está sin cuadrar: %s cuadran con su auxiliar, %s están explicadas y %s salen del '
                              'propio libro (no se comparan con un papel).', fn_cedula_dia(v_f), v_n2, v_s::int, v_s2::int)
                  else format('%s cuenta(s) no cuadran con su auxiliar al %s y nadie lo ha explicado: %s. Cada una dice en la cédula '
                              'qué le falta; lo que no se pueda arreglar se explica con sus palabras.', v_n, fn_cedula_dia(v_f), v_t) end;
  return next;

  -- 30. Ninguna cuenta con saldo sin auxiliar ni explicación.
  select count(*), left(string_agg(format('%s %s (%s)', c.cuenta, c.nombre, fn_cedula_usd(c.saldo_libro)), '; ' order by c.cuenta), 900)
    into v_n, v_t
    from jsonb_to_recordset(v_filas)
         as c(cuenta text, nombre text, estado text, pendiente boolean, saldo_libro numeric, explicacion_vieja boolean)
   where c.pendiente and c.estado = 'sin_auxiliar' and not c.explicacion_vieja;
  orden := 30; control := 'cédula: ninguna cuenta con saldo sin auxiliar ni explicación'; nivel := 'aviso';
  ok := v_n = 0 or not v_mira;
  detalle := case when not v_mira
                  then v_cuando || case when v_n > 0 then format(' Hoy saldrían %s cuenta(s) con saldo y sin auxiliar.', v_n) else '' end
                  when v_n = 0 then format('Al %s toda cuenta con saldo tiene algo debajo que la sostiene, o su explicación.', fn_cedula_dia(v_f))
                  else format('%s cuenta(s) tienen saldo al %s y nada debajo que lo sostenga: %s. A cada una se le escriben sus '
                              'renglones (qué es, cuánto, con qué documento) o se explica.', v_n, fn_cedula_dia(v_f), v_t) end;
  return next;

  -- 40. Ninguna explicación se quedó vieja.
  select count(*), left(string_agg(format('%s %s', c.cuenta, c.nombre), '; ' order by c.cuenta), 900)
    into v_n, v_t
    from jsonb_to_recordset(v_filas) as c(cuenta text, nombre text, explicacion_vieja boolean)
   where c.explicacion_vieja;
  orden := 40; control := 'cédula: ninguna explicación se quedó vieja'; nivel := 'aviso';
  ok := v_n = 0 or not v_mira;
  detalle := case when not v_mira
                  then v_cuando || case when v_n > 0 then format(' Hoy saldrían %s explicación(es) viejas.', v_n) else '' end
                  when v_n = 0 then format('Las explicaciones al %s siguen valiendo: nada cambió después de escribirlas.', fn_cedula_dia(v_f))
                  else format('%s cuenta(s) se explicaron al %s y después cambió su saldo o su auxiliar: %s. Esa explicación ya no '
                              'vale: se vuelve a explicar con los números de ahora.', v_n, fn_cedula_dia(v_f), v_t) end;
  return next;

  -- 50. Cada renglón escrito a mano que cuenta ese día dice su documento.
  select count(*), left(string_agg(format('%s: «%s» (%s)', m.cuenta, left(m.concepto, 60), fn_cedula_usd(m.monto)), '; ' order by m.cuenta, m.creado_el), 900)
    into v_n, v_t
    from cedula_manual m
   where m.sustituido_el is null and m.anulado_el is null and m.desde <= v_f and (m.hasta is null or m.hasta >= v_f)
     and nullif(btrim(coalesce(m.documento, '')), '') is null;
  orden := 50; control := 'cédula: cada renglón escrito a mano dice su documento'; nivel := 'aviso';
  ok := v_n = 0 or not v_mira;
  detalle := case when not v_mira
                  then v_cuando || case when v_n > 0 then format(' Hoy saldrían %s renglón(es) a mano sin documento.', v_n) else '' end
                  when v_n = 0 then format('Todo renglón escrito a mano que cuenta al %s dice con qué documento se sostiene.', fn_cedula_dia(v_f))
                  else format('%s renglón(es) escritos a mano no dicen su documento: %s. Corrige cada uno y ponle el papel que lo '
                              'sostiene (la póliza, el contrato, el statement, el conteo).', v_n, v_t) end;
  return next;

  -- 90. Las protecciones de la capa: nada SECURITY DEFINER, nada para anon ni
  --     service_role, las internas sin API, RLS con su policy del dueño,
  --     nadie borra, las vistas security_invoker y las guardas encendidas.
  select count(*), left(string_agg(y.que, '; ' order by y.que), 900)
    into v_n, v_t
    from (with fx as (select p.oid, p.proname as nombre, p.prosecdef
                        from pg_catalog.pg_proc p
                       where p.pronamespace = 'public'::regnamespace
                         and p.proname in ('fn_cedula_precondiciones', 'fn_cedula_exigir_dueno', 'fn_cedula_ve', 'fn_cedula_guarda',
                                           'fn_cedula_usd', 'fn_cedula_dia', 'fn_cedula_mes', 'fn_cedula_monto', 'fn_cedula_capas',
                                           'fn_cedula_toca', 'fn_cedula_cuentas', 'fn_cedula_partidas', 'fn_cedula', 'fn_cedula_resumen',
                                           'fn_cedula_qb', 'fn_cedula_qb_periodos', 'fn_cedula_config', 'fn_cedula_renglon',
                                           'fn_cedula_renglon_anular', 'fn_cedula_explicar', 'fn_cedula_explicacion_retirar',
                                           'fn_cedula_control', 'fn_cedula_cierre', 'fn_cedula_pegado')),
               tb as (select c.oid, c.relname, c.relkind, c.relrowsecurity, c.reloptions
                        from pg_catalog.pg_class c
                       where c.relnamespace = 'public'::regnamespace
                         and c.relname in ('cedula_config', 'cedula_manual', 'cedula_explicaciones',
                                           'v_cedula', 'v_cedula_control', 'v_cedula_manual', 'v_cedula_explicaciones', 'v_cedula_qb'))
          select fx.nombre || ' corre con permisos de más' as que from fx where fx.prosecdef
          union all
          select format('%s la puede ejecutar %s', fx.nombre, g.r)
            from fx cross join (values ('anon'), ('service_role')) g(r)
           where has_function_privilege(g.r, fx.oid, 'execute')
          union all
          select fx.nombre || ' la puede ejecutar la app'
            from fx
           where fx.nombre in ('fn_cedula_precondiciones', 'fn_cedula_guarda', 'fn_cedula_pegado')
             and has_function_privilege('authenticated', fx.oid, 'execute')
          union all
          select tb.relname || case when not tb.relrowsecurity then ' sin su candado de filas' else ' sin su candado de solo-dueño' end
            from tb
           where tb.relkind = 'r'
             and (not tb.relrowsecurity
                  or not exists (select 1 from pg_catalog.pg_policy pl
                                  where pl.polrelid = tb.oid and pl.polname = tb.relname || '_dueno' and pl.polcmd = 'r'))
          union all
          select format('%s puede %s en %s', g.r, q.q, tb.relname)
            from tb
            cross join (values ('anon'), ('service_role')) g(r)
            cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) q(q)
           where has_table_privilege(g.r, tb.oid, q.q)
          union all
          select format('la app puede %s en %s', q.q, tb.relname)
            from tb cross join (values ('DELETE'), ('TRUNCATE')) q(q)
           where tb.relkind = 'r' and has_table_privilege('authenticated', tb.oid, q.q)
          union all
          select tb.relname || ' no lee con los permisos de quien mira'
            from tb
           where tb.relkind = 'v'
             and not coalesce((select o.option_value::boolean from pg_options_to_table(tb.reloptions) o
                                where o.option_name = 'security_invoker'), false)
          union all
          select format('la guarda de %s %s', x.t,
                        case when tg.oid is null then 'no está' when tg.tgenabled not in ('O', 'A') then 'está apagada'
                             else 'no es la suya' end)
            from (select t.t, 'trg_' || t.t || s.s as tg
                    from (values ('cedula_config'), ('cedula_manual'), ('cedula_explicaciones')) t(t)
                    cross join (values ('_guarda'), ('_sin_truncate')) s(s)) x
            left join pg_catalog.pg_trigger tg on tg.tgrelid = to_regclass('public.' || x.t) and tg.tgname = x.tg
           where tg.oid is null or tg.tgenabled not in ('O', 'A')
              or tg.tgfoid is distinct from to_regprocedure('public.fn_cedula_guarda()')) y;
  orden := 90; control := 'cédula: las protecciones de la capa'; nivel := 'cuadre'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Nada de la cédula corre con permisos de más, nada es para la llave pública ni la de servicio, sus tablas '
                                    'tienen su candado de solo-dueño y sus guardas encendidas, y sus vistas leen con los permisos de quien mira.'
                  else format('Las protecciones de la cédula no están como se pegaron: %s. Vuelve a pegar el archivo de la cédula (c13).', v_t) end;
  return next;
end $$;
revoke execute on function public.fn_cedula_control(text) from public, anon, service_role;
grant  execute on function public.fn_cedula_control(text) to authenticated;
comment on function public.fn_cedula_control(text) is 'c13: el control de la cédula al último día de un período (sin período, el que toca): 10 (cuadre) la cédula trae todas las cuentas de balance y su saldo es el del libro; 20 (aviso) cada saldo con su auxiliar cuadrado o explicado; 30 (aviso) ninguna cuenta con saldo sin auxiliar ni explicación; 40 (aviso) ninguna explicación se quedó vieja; 50 (aviso) cada renglón escrito a mano dice su documento; 90 (cuadre) las protecciones de la capa. Los avisos no se ponen en rojo mientras el período no termine ni antes del mes desde el que se avisa (cedula_config.avisar_desde): dicen cuánto falta. Solo lectura; a quien no es el dueño, nada.';

-- LA FILA DEL CIERRE (c9: fn_cierre_revisar la pide si esta capa está): la
-- 178, un AVISO que resume el control de la cédula. No detiene nada. Su
-- nombre es fijo (la ronda de c9 avisa al teléfono de cada rojo nuevo por el
-- nombre de la fila: una lista de cuentas que se va acortando sería un aviso
-- cada mañana); el detalle lleva lo que está en rojo, cada parte recortada a
-- lo suyo (c9 guarda 1500 letras por fila).
drop function if exists public.fn_cedula_cierre(text);
create function public.fn_cedula_cierre(p_periodo text)
returns table (orden int, control text, nivel text, ok boolean, detalle text, que_hacer text, ir_a text)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_c jsonb;
  v_r bigint;
  v_t text;
begin
  if not fn_cedula_ve() then
    return;
  end if;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.orden), '[]'::jsonb) into v_c from fn_cedula_control(p_periodo) c;
  select count(*) filter (where not x.ok) into v_r from jsonb_to_recordset(v_c) as x(ok boolean);
  select string_agg(case when length(x.detalle) > greatest(160, 1380 / greatest(v_r, 1)::int)
                         then left(x.detalle, greatest(160, 1380 / greatest(v_r, 1)::int) - 1) || '…' else x.detalle end,
                    ' · ' order by x.orden)
    into v_t
    from jsonb_to_recordset(v_c) as x(orden int, ok boolean, detalle text)
   where not x.ok;
  orden := 178; control := 'cédula: cada saldo del balance con su auxiliar cuadrado o explicado (c13)'; nivel := 'aviso';
  ok := v_r = 0;
  detalle := case when v_r = 0
                  then coalesce((select x.detalle from jsonb_to_recordset(v_c) as x(orden int, detalle text) where x.orden = 20), 'En verde.')
                  else coalesce(v_t, 'en rojo, sin detalle') end;
  que_hacer := case when v_r = 0 then null
                    else 'No detiene el cierre. En Contabilidad → Cédula: lo que no cuadra se arregla donde dice cada cuenta o se explica '
                         'con sus palabras; a lo que no tiene nada debajo se le escriben sus renglones.' end;
  ir_a := 'cedula';
  return next;
end $$;
revoke execute on function public.fn_cedula_cierre(text) from public, anon, service_role;
grant  execute on function public.fn_cedula_cierre(text) to authenticated;
comment on function public.fn_cedula_cierre(text) is 'c13: la fila de la cédula para la revisión del cierre (c9) de un período: la 178, un aviso (no detiene) que resume su control al último día de ese período, con ok, el detalle en llano, qué hacer e ir_a = cedula. Su nombre es fijo (la ronda avisa de un rojo nuevo por el nombre de la fila). No se pone en rojo mientras el período no termine ni antes del mes desde el que se avisa. Solo lectura; a quien no es el dueño, nada.';


-- ---------------------------------------------------------------------
-- 8. Las vistas de la pantalla (security_invoker; leen funciones y tablas de
--    aquí; no nombran ninguna columna de periodos ni de cuentas). Solo
--    authenticated; el equipo, cero filas.
-- ---------------------------------------------------------------------
-- LA CÉDULA del día que toca (fn_cedula sin fecha; sus columnas, allí). Para
-- otro día, fn_cedula(fecha).
create view public.v_cedula with (security_invoker = true) as
select c.fecha, c.orden, c.cuenta, c.nombre, c.tipo, c.signo, c.saldo_libro, c.fuente, c.auxiliar, c.origen, c.auxiliar_al,
       c.saldo_auxiliar, c.diferencia, c.renglones, c.descuadres, c.manual, c.despues, c.sueltas, c.estado, c.pendiente, c.por_que,
       c.detalle, c.que_hacer, c.explicacion, c.explicada_el, c.explicada_por, c.explicada_por_nombre, c.explicacion_id,
       c.explicacion_vieja, c.sosten, c.par, c.solo_reparto
  from public.fn_cedula(null) c;
revoke all on public.v_cedula from public, anon, authenticated, service_role;
grant select on public.v_cedula to authenticated;
comment on view public.v_cedula is 'c13: la cédula de corte al último día del período que toca: una fila por cuenta de balance con su saldo en el libro (saldo_libro, en su lado natural), de dónde sale su auxiliar (fuente, auxiliar, origen, auxiliar_al), lo que suma (saldo_auxiliar), la diferencia, su estado (cuadra | explicada | no_cuadra | sin_auxiliar | del_libro), si pide algo (pendiente), por qué no tiene auxiliar (por_que), el detalle y qué hacer en llano, su explicación (quién, cuándo, y si se quedó vieja), qué hay debajo (sosten: papel | partidas | libro | llevado) y, en un préstamo, su par y si su diferencia es solo el reparto (solo_reparto). Para otro día, fn_cedula(fecha).';

-- EL CONTROL del período que toca (fn_cedula_control sin período).
create view public.v_cedula_control with (security_invoker = true) as
select c.orden, c.control, c.nivel, c.ok, c.detalle from public.fn_cedula_control(null) c;
revoke all on public.v_cedula_control from public, anon, authenticated, service_role;
grant select on public.v_cedula_control to authenticated;
comment on view public.v_cedula_control is 'c13: el control de la cédula al último día del período que toca (orden, control, nivel, ok, detalle en llano): 10 la cédula trae todas las cuentas de balance y su saldo es el del libro; 20 cada saldo con su auxiliar cuadrado o explicado; 30 ninguna cuenta con saldo sin auxiliar ni explicación; 40 ninguna explicación se quedó vieja; 50 cada renglón a mano dice su documento; 90 las protecciones. nivel: cuadre o aviso (ninguno detiene el cierre: es de corte de año). Para otro período, fn_cedula_control(periodo).';

-- LOS RENGLONES A MANO, los vigentes y los que quedaron (corregidos, anulados).
create view public.v_cedula_manual with (security_invoker = true) as
select m.id as renglon_id, m.cuenta, k.nombre as cuenta_nombre, m.concepto, m.monto, m.documento, m.nota, m.desde, m.hasta,
       (m.sustituido_el is null and m.anulado_el is null) as vigente, m.sustituye_a,
       m.creado_el, m.creado_por, pc.nombre as creado_por_nombre, m.sustituido_el,
       m.anulado_el, m.anulado_por, pa.nombre as anulado_por_nombre, m.anulado_motivo
  from public.cedula_manual m
  left join public.fn_cedula_cuentas() k on k.cuenta = m.cuenta
  left join public.perfiles pc on pc.id = m.creado_por
  left join public.perfiles pa on pa.id = m.anulado_por;
revoke all on public.v_cedula_manual from public, anon, authenticated, service_role;
grant select on public.v_cedula_manual to authenticated;
comment on view public.v_cedula_manual is 'c13: cada renglón escrito a mano en el auxiliar de una cuenta: la cuenta y su nombre, qué es, cuánto (en el lado natural de la cuenta), el documento, la nota, desde y hasta qué día vale, si está vigente, a cuál corrigió, quién lo escribió y cuándo; y si quedó sustituido (corregido) o anulado, por quién y por qué.';

-- LAS EXPLICACIONES, la viva de cada cuenta y fecha y las que quedaron.
create view public.v_cedula_explicaciones with (security_invoker = true) as
select e.id as explicacion_id, e.cuenta, k.nombre as cuenta_nombre, e.fecha, e.texto, e.estado, e.saldo_libro, e.saldo_auxiliar,
       e.diferencia, e.explicado_el, e.explicado_por, pe.nombre as explicado_por_nombre,
       (e.sustituida_el is null and e.retirada_el is null) as viva, e.sustituida_el,
       e.retirada_el, e.retirada_por, pr.nombre as retirada_por_nombre, e.retirada_motivo
  from public.cedula_explicaciones e
  left join public.fn_cedula_cuentas() k on k.cuenta = e.cuenta
  left join public.perfiles pe on pe.id = e.explicado_por
  left join public.perfiles pr on pr.id = e.retirada_por;
revoke all on public.v_cedula_explicaciones from public, anon, authenticated, service_role;
grant select on public.v_cedula_explicaciones to authenticated;
comment on view public.v_cedula_explicaciones is 'c13: cada explicación de una cuenta a una fecha: el texto, cómo estaba (no_cuadra o sin_auxiliar), con qué números se explicó (saldo del libro, del auxiliar y la diferencia), quién y cuándo, si sigue viva, y si quedó sustituida por otra o retirada (por quién y por qué). Si vale todavía lo dice la cédula de esa fecha (explicacion_vieja).';

-- LA CÉDULA AL LADO DE QUICKBOOKS, por período con balanza cargada
-- (fn_cedula_qb; sus columnas, allí). La pantalla la pide filtrada por
-- periodo: así solo se calcula ese.
create view public.v_cedula_qb with (security_invoker = true) as
select p.periodo, q.al, q.documento, q.qb_cargada, q.orden, q.cuenta, q.nombre, q.tipo, q.saldo_libro, q.auxiliar, q.saldo_auxiliar,
       q.diferencia, q.estado, q.pendiente, q.libro_comparable, q.saldo_qb, q.diferencia_qb, q.explicada_qb, q.sin_explicar_qb,
       q.qb_ok, q.libro_igual, q.amarra
  from public.fn_cedula_qb_periodos() p
  cross join lateral public.fn_cedula_qb(p.periodo) q;
revoke all on public.v_cedula_qb from public, anon, authenticated, service_role;
grant select on public.v_cedula_qb to authenticated;
comment on view public.v_cedula_qb is 'c13: la cédula al lado de QuickBooks, una fila por cuenta de balance y período que tiene balanza de QuickBooks (la de la apertura y las cargadas en la comparación de c4): la cédula a la fecha de esa balanza (saldo_libro, auxiliar, saldo_auxiliar, diferencia, estado, pendiente) y lo que la comparación dice de la cuenta, en su lado natural (libro_comparable, saldo_qb, diferencia_qb, explicada_qb, sin_explicar_qb, qb_ok), con libro_igual y amarra (QuickBooks contra el libro y el libro contra su auxiliar, los dos bien). Se lee filtrada por periodo. Para un período sin balanza, fn_cedula_qb(periodo) (qb_cargada = false).';


-- ---------------------------------------------------------------------
-- 9. Lo que debe verse al pegar: fn_cedula_pegado().
-- ---------------------------------------------------------------------
create or replace function public.fn_cedula_pegado() returns table (que text, detalle text)
language plpgsql
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  c       cedula_config;
  v_capas jsonb;
  v_per   text;
  v_j     jsonb;
  v_txt   text;
  v_falta text[] := '{}';
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  select * into c from cedula_config where id = 1;
  return query select 'cedula_config'::text,
                      format('%s · el patrimonio se sostiene con %s',
                             case when c.avisar_desde is null then 'el cierre todavía no avisa de la cédula en ningún mes'
                                  else format('el cierre avisa de la cédula desde %s (%s); los meses anteriores no ganan un rojo por ella',
                                              fn_cedula_mes(c.avisar_desde), c.avisar_desde) end,
                             case c.patrimonio when 'mayor' then 'su propio mayor (la apertura más sus movimientos)'
                                               else 'renglones escritos a mano' end);
  return query select 'tablas'::text,
                      format('cedula_config, cedula_manual (%s renglones vigentes, %s corregidos o anulados), cedula_explicaciones (%s vivas, '
                             '%s sustituidas o retiradas)',
                             (select count(*) from cedula_manual m where m.sustituido_el is null and m.anulado_el is null),
                             (select count(*) from cedula_manual m where m.sustituido_el is not null or m.anulado_el is not null),
                             (select count(*) from cedula_explicaciones e where e.sustituida_el is null and e.retirada_el is null),
                             (select count(*) from cedula_explicaciones e where e.sustituida_el is not null or e.retirada_el is not null));
  return query select 'vistas'::text, 'v_cedula, v_cedula_control, v_cedula_manual, v_cedula_explicaciones, v_cedula_qb'::text;
  v_capas := fn_cedula_capas();
  return query select 'capas que lee'::text,
                      (select string_agg(format('%s: %s', x.que, case when (v_capas->>x.k)::boolean then 'está' else 'NO está (sus cuentas salen sin auxiliar)' end),
                                         ' · ' order by x.n)
                         from (values (1, 'c4', 'la comparación con QuickBooks (c4)'), (2, 'c6', 'el banco, los préstamos y las pólizas (c6)'),
                                      (3, 'c9', 'los activos fijos (c9)'), (4, 'c12', 'el WIP (c12)'),
                                      (5, 'p1', 'los cobros en línea (p1)')) x(n, k, que));
  v_per := fn_cedula_toca();
  begin
    v_j := fn_cedula_resumen(null);
    v_txt := format('al %s%s: %s cuentas de balance, %s con saldo · %s cuadran con su auxiliar · %s salen del propio libro · %s explicadas · '
                    '%s no cuadran · %s con saldo y sin auxiliar · activo %s = pasivo %s + patrimonio %s + resultado sin cerrar %s',
                    fn_cedula_dia((v_j->>'fecha')::date), coalesce(' (' || fn_cedula_mes(v_per) || ')', ''), v_j->>'cuentas', v_j->>'con_saldo',
                    v_j->>'cuadran', v_j->>'del_libro', v_j->>'explicadas', v_j->>'no_cuadran', v_j->>'sin_auxiliar',
                    fn_cedula_usd((v_j->>'activo')::numeric), fn_cedula_usd((v_j->>'pasivo')::numeric),
                    fn_cedula_usd((v_j->>'capital')::numeric), fn_cedula_usd((v_j->>'resultado')::numeric));
    if (v_j->>'pendientes')::int > 0 then
      v_falta := v_falta || format('%s cuenta(s) piden algo al %s: lo que no cuadra se arregla o se explica, y a lo que no tiene auxiliar se '
                                   'le escriben sus renglones', v_j->>'pendientes', fn_cedula_dia((v_j->>'fecha')::date));
    end if;
  exception when others then
    v_txt := format('la cédula falló: %s %s', sqlstate, sqlerrm);
  end;
  return query select 'la cédula'::text, v_txt;
  begin
    select format('%s de %s cuadres en rojo%s · %s de %s avisos%s',
                  count(*) filter (where k.nivel = 'cuadre' and k.ok is distinct from true), count(*) filter (where k.nivel = 'cuadre'),
                  coalesce(' (' || string_agg(k.control, '; ' order by k.orden) filter (where k.nivel = 'cuadre' and k.ok is distinct from true) || ')', ''),
                  count(*) filter (where k.nivel = 'aviso' and k.ok is distinct from true), count(*) filter (where k.nivel = 'aviso'),
                  coalesce(' (' || string_agg(k.control, '; ' order by k.orden) filter (where k.nivel = 'aviso' and k.ok is distinct from true) || ')', ''))
      into v_txt
      from fn_cedula_control(null) k;
  exception when others then
    v_txt := format('el control falló: %s %s', sqlstate, sqlerrm);
  end;
  return query select 'control'::text, v_txt;
  return query select 'qué falta'::text,
                      case when cardinality(v_falta) = 0 then 'nada: todo listo' else array_to_string(v_falta, ' · ') end;
  -- (¿el cierre de esta base ya mira la cédula? El c9 con la fila 178 la
  -- pide a esta capa; el de antes no, y hay que volver a pegarlo.)
  return query select 'siguiente paso'::text,
                      case when to_regprocedure('public.fn_cierre_revisar(text)') is not null
                                and not exists (select 1 from pg_proc p
                                                 where p.oid = to_regprocedure('public.fn_cierre_revisar(text)')
                                                   and p.prosrc like '%fn_cedula_cierre%')
                           then 'El cierre de esta base todavía no mira la cédula (su fila 178): eso llega con el docs/conta/c9-cierre.sql '
                                'que nombra la fila 178 en su cabecera. Si el que tienes la nombra, vuelve a pegarlo; si no, no pasa nada: '
                                'la cédula funciona sin él, y solo falta su aviso en la lista del cierre. Ahora, '
                           else '' end ||
                      'pega docs/conta/c13-pruebas.sql; en la app, Contabilidad → Cédula: cada cuenta dice qué la sostiene y si cuadra; lo '
                      'que la base no sabe se escribe a mano (qué es, cuánto, con qué documento) y lo que no cuadra se explica.'::text;
end $$;
revoke execute on function public.fn_cedula_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_cedula_pegado() is 'c13: lo que enseña el final del pegado: la configuración (desde qué mes avisa el cierre, cómo se sostiene el patrimonio), las tablas y las vistas, qué capas opcionales encontró, la cédula del día que toca en una línea (cuántas cuentas cuadran, cuántas están explicadas, cuántas no cuadran y cuántas no tienen auxiliar), el control, qué falta y el paso siguiente.';

select * from public.fn_cedula_pegado();
