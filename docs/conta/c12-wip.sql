-- =====================================================================
-- c12-wip.sql — EL WIP POR COSTO A COSTO (el trabajo en curso: sobre o
-- sub-facturado por obra, y la pérdida provisionada) · c12 (la mitad de la
-- Fase 10; f10 llama al entregable «c10-facturacion-wip.sql» por un nombre
-- viejo: c10 ya es el costo por obra, y la factura de la app es c11).
-- 12-nov-2026, v2 (con lo que encontraron los dos revisores). Se pega en el SQL Editor DESPUÉS de c1, c2 y c3 (y de
-- c4, c6, c7, s1, p1, c8, c9 y c10 si se usan: la cadena de siempre; c11
-- puede faltar, esta capa no la mira). Idempotente: se puede volver a pegar
-- entero (no pisa la configuración, ni una revisión, ni lo confirmado de
-- antes del libro, ni un ajuste). Después se pega c12-pruebas.sql.
--
-- Qué hace. QuickBooks reconoce el ingreso cuando se factura. Max Power
-- factura por hitos, y un hito no es el avance: una obra con el depósito
-- cobrado y sin empezar «ganó» en QuickBooks lo que todavía debe en
-- trabajo; otra a medio hacer y sin facturar parece que no ganó nada. Edgar
-- decidió (11-nov) medir el avance por COSTO A COSTO:
--
--     % de avance = costo incurrido a la fecha ÷ costo total estimado REVISADO
--     ingreso ganado = precio del contrato × % de avance
--     ganado − facturado  > 0 → SUB-facturado  (1200, un activo: trabajo
--                               hecho y todavía no facturado)
--                         < 0 → SOBRE-facturado (2400, un pasivo: facturado
--                               por encima del trabajo hecho)
--
-- Sigue facturando por hitos como hoy; esta capa dice, obra por obra y mes
-- por mes, cuánto va por delante o por detrás, y lo lleva al libro con UN
-- asiento de cierre que se deshace solo el día 1 del mes siguiente. Es el
-- reporte que pide el banco y la afianzadora (v_wip_schedule).
--
-- LAS PIEZAS:
--   (1) QUÉ OBRAS LLEVAN WIP. Las de PRECIO FIJO: tipo residencial o
--       comercial con contrato en su ficha (finanzas_proyecto.contrato).
--       Las de SERVICIO (proyectos.tipo = 'servicio', las que facturan a
--       4030 «Servicio y T&M») y las que no tienen contrato NO llevan WIP:
--       su ingreso es lo facturado, y no hay un precio contra el que medir
--       avance. La regla sale de lo que la app ya tiene; cuando no acierta,
--       Edgar marca la obra una vez (fn_wip_obra: «contrato» = lleva WIP
--       aunque sea de servicio; «tm» = no lo lleva aunque tenga contrato),
--       con su nota, y queda quién y cuándo. v_wip_obras las enseña todas
--       con su porqué.
--       En un mes ENTRAN: las activas (aprobado, en ejecución, en pausa);
--       las que tienen una revisión en el mes; las terminadas que venían en
--       el WIP (para cerrarlas: 100 %) o con fecha de término en el mes (si
--       la app la guarda); y TODA obra que traía sub, sobre o provisión en
--       el último ajuste, esté como esté hoy en la app (cancelada, devuelta
--       a «enviado», terminada y sin facturar entera, marcada T&M, sin
--       contrato): su saldo se deshizo solo el día 1 y, si no entrara, no
--       volvería y nadie lo habría decidido. NINGUNA OBRA CON SALDO SALE
--       SOLA: o se revisa (sigue midiéndose; la terminada, hasta que lo
--       facturado sea su precio) o Edgar la EXCLUYE ese mes con su nota
--       (queda quién, cuándo y por qué; su ingreso vuelve a ser lo
--       facturado). Una obra sin costo ni facturas todavía no pide nada
--       («sin movimiento»).
--       LA QUE LA APP TODAVÍA NO TIENE EN OBRA (en estimación, con la
--       propuesta enviada, no aprobada) no entra aunque tenga contrato: no
--       hay obra que medir. Pero si YA TIENE FACTURAS EN EL LIBRO (el
--       depósito que se factura al firmar, antes de pasarla a «aprobado»),
--       ese ingreso cuenta entero de una vez y nada lo difiere: el aviso 160
--       la nombra, con lo facturado, hasta que pase a aprobada (entra, y se
--       revisa como las demás) o Edgar la marque como que no lleva WIP, con
--       su nota.
--   (2) LO QUE NO SE DERIVA, y por eso se guarda (lo demás se calcula):
--       · wip_revisiones — por obra y mes: EL COSTO TOTAL ESTIMADO REVISADO
--         (desde el inicio de la obra hasta terminarla), con quién, cuándo
--         y su nota, y EL PRECIO DEL CONTRATO que se usó ese mes (copiado de
--         finanzas_proyecto.contrato al revisar: la ficha cambia sin
--         historia). Revisar es UN TOQUE cuando no cambió nada (confirmar lo
--         del mes anterior; la primera vez, lo que dice el estimado de la
--         obra, c10), u otro número con su nota. Una obra terminada se
--         revisa como «terminada»: su costo final es el que lleva, 100 %.
--         La que este mes NO se mide se revisa como «excluida», con su
--         porqué (se canceló, pasó a T&M, falta lo de antes y este mes no
--         se puede): una decisión escrita, del mes; al siguiente, si la
--         obra sigue activa, se vuelve a preguntar. Si el contrato de la
--         ficha cambia DESPUÉS de revisar, la obra vuelve a «por revisar»
--         hasta que Edgar diga si el cambio es del mes (se revisa otra vez)
--         o de después (un toque: se queda como estaba, y queda escrito).
--         Una revisión no se edita ni se borra: otra la sustituye y la
--         anterior queda.
--       · wip_antes — por obra: LO DE ANTES DEL LIBRO. El libro empieza el
--         1-oct-2026; el costo a costo necesita el costo y lo facturado
--         DESDE EL INICIO de la obra, y lo de antes está en QuickBooks. La
--         base PROPONE desde los papeles de la app (tickets, trabajos
--         externos, horas × la tarifa de hoy, facturas; fn_wip_antes_
--         propuesta lo desglosa y dice qué le falta) y Edgar CONFIRMA esos
--         números o pone los de QuickBooks con su nota (fn_wip_antes). Sin
--         inventar: mientras una obra que ya andaba no tenga lo de antes
--         confirmado, NO ENTRA en el ajuste, y se dice en su fila, en el
--         control y en el cierre.
--       · wip_obras — la marca «contrato» / «tm» de (1).
--       · wip_ajustes y wip_ajuste_obras — cada ajuste posteado, con la
--         FOTO de cada obra como se calculó ese día (precio, costo estimado,
--         costo a la fecha, %, ganado, facturado, sobre, sub, pérdida): el
--         WIP de un mes cerrado se lee de ahí, igual que se posteó.
--       · wip_config — desde qué mes se exige el WIP para cerrar.
--   (3) EL CÁLCULO (fn_wip_calcular; v_wip_schedule lo enseña, una fila por
--       obra y mes). Todo a la fecha del último día del mes:
--         precio_contrato      el de la revisión del mes
--         costo_estimado       el costo total estimado revisado (terminada:
--                              el costo que lleva)
--         utilidad_estimada    precio − costo estimado
--         costo_libro          el costo de la obra en el libro hasta ese día:
--                              las cuentas de tipo costo (5xxx) con esa obra
--                              —la misma regla que el costo por obra (c10) y
--                              que «Estados» (c4)—, SIN los asientos del
--                              propio ajuste de WIP (la 5950 de una pérdida
--                              no es costo incurrido)
--         costo_antes          lo de antes del libro, confirmado
--         costo_fecha          costo_libro + costo_antes
--         pct_real             100 × costo_fecha ÷ costo_estimado, sin tope
--         pct_avance           el que se usa: pct_real entre 0 y 100. Con
--                              más costo que el estimado (pasa_de_100) el
--                              avance SE TOPA en 100 % —nunca se gana más
--                              que el precio—, pero esa obra NO ENTRA en el
--                              ajuste: más costo que el estimado sin estar
--                              terminada es un estimado viejo. Se sube (el
--                              costo total no puede ser menos de lo que ya
--                              lleva: la revisión no lo admite) o la obra
--                              se marca terminada; sin excepción por nota
--         ingreso_ganado       precio × costo topado ÷ costo estimado
--         facturado_libro      lo facturado de verdad en el libro hasta ese
--                              día: el ingreso (40xx con esa obra) de los
--                              asientos del puente de facturas y de sus
--                              notas de crédito (c3). SIN los ajustes de
--                              WIP, y sin lo que no es factura (un descuento
--                              al cobrar, un asiento a mano: ingreso_otro,
--                              que se enseña aparte)
--         facturado_antes      lo facturado antes del libro, confirmado
--         facturado_fecha      facturado_libro + facturado_antes
--         sub_facturado        ganado − facturado, si es positivo (→ 1200)
--         sobre_facturado      facturado − ganado, si es positivo (→ 2400)
--         costo_para_terminar  costo estimado − costo a la fecha (≥ 0)
--         utilidad_fecha       ganado − costo a la fecha
--         perdida_total        costo estimado − precio, si es positivo
--         perdida_provision    lo que va a 2410 (abajo)
--       EL DEPÓSITO NO ES AVANCE, y no hace falta tratarlo aparte: una
--       factura de depósito (hitos.es_deposito) sin costo en la obra da 0 %
--       de avance, 0 ganado, y lo facturado entero sale SOBRE-facturado
--       (2400) hasta que haya costo.
--   (4) LA REGLA DE REDONDEO (determinista, en numeric exacto, sin
--       flotantes). El dinero va en centavos, numeric(14,2). El ingreso
--       ganado se calcula de una vez: precio × costo topado ÷ costo
--       estimado —primero el producto, después la división— y se redondea
--       UNA vez a centavos (medio centavo hacia arriba en valor absoluto, el
--       round de Postgres). Nunca sale del porcentaje ya redondeado:
--       pct_avance y pct_real son para leer (dos decimales). Sobre, sub,
--       utilidad, costo para terminar y la provisión son sumas y restas de
--       centavos: exactas. Con el avance en 100 % el ganado es el precio, al
--       centavo.
--   (5) LA PÉRDIDA (Dr 5950 / Cr 2410). Si el costo estimado supera el
--       precio, la obra pierde (costo estimado − precio) y esa pérdida se
--       reconoce COMPLETA el mes en que se ve, no poco a poco. Cuidado con
--       contarla dos veces: una obra con pérdida y a medias YA lleva parte
--       de esa pérdida en su resultado (ganó precio × % y costó estimado ×
--       %). La provisión es LO QUE FALTA POR RECONOCER:
--           provisión = pérdida total − (costo topado − ingreso ganado)
--                     = (costo estimado − precio) × (1 − % de avance)
--       Así el resultado acumulado de la obra es, ese mes y los siguientes,
--       la pérdida completa, UNA vez: con 0 % de avance la provisión es la
--       pérdida entera (lo que dice el plan), a medio hacer es la parte que
--       queda, y con la obra terminada es cero (la pérdida ya está en el
--       costo real). Postear la pérdida entera a mitad de obra la contaría
--       una vez y media. ▶ Pregunta para el CPA (al final).
--   (6) EL AJUSTE DEL MES (fn_wip_postear). UN asiento, fechado el último
--       día del mes, con las obras listas, cada una con su obra en la
--       línea:
--           sub-facturada    Dr 1200            / Cr su ingreso (40xx)
--           sobre-facturada  Dr su ingreso      / Cr 2400
--           con pérdida      Dr 5950            / Cr 2410
--       «Su ingreso» es la cuenta que el puente de facturas de c3 usa para
--       esa obra (mapeo_tipo_proyecto por proyectos.tipo, confirmada): el
--       ajuste corrige el mismo renglón que la factura llenó. Entra por el
--       camino que c2 da al dueño, fn_postear (camino «mano»), con
--       reversible = true: c2 lo hace nacer con su reverso automático del
--       día 1 del mes siguiente, en la misma transacción, como el devengo de
--       horas de c3. Nada se rodea, y ninguna función de aquí es SECURITY
--       DEFINER.
--         · IDEMPOTENTE. fn_postear no admite origen en el primer asiento
--           de un papel (eso es de los puentes de c3, que son DEFINER): la
--           idempotencia la lleva esta capa, como c9 con la depreciación.
--           wip_ajustes guarda el asiento de cada mes; un mes, un ajuste
--           vivo (índice único), con un candado por mes. Postear dos veces
--           seguidas deja UN asiento: la segunda devuelve el que estaba.
--           Mientras postea tiene también el candado de la cadena del libro
--           (el de c2, como el cierre de c9): entre el cálculo y el asiento
--           no entra un costo ni una factura; lo que llegue después deja el
--           ajuste «desfasado», y se dice.
--         · SI ALGO CAMBIA DESPUÉS DE POSTEAR (una revisión, lo de antes,
--           un ticket que llega al mes, una factura, la marca de una obra),
--           la base NO rehace nada sola: cada cambio serían cuatro asientos
--           más en un libro que no se borra. El control lo pone en rojo
--           («el ajuste posteado ya no es el de hoy», y dice qué cambió), el
--           cierre no pasa, y volver a tocar «Postear» lo REHACE: reversa el
--           viejo dentro de su mes (fn_reversar de c2, que anula también su
--           reverso del día 1) y postea el nuevo con el suyo. Si no cambió
--           nada, no hace nada. fn_wip_deshacer lo quita sin poner otro.
--         · UN MES CERRADO NO SE TOCA (c2): ni revisar, ni postear, ni
--           deshacer (MX002). Su ajuste ya se deshizo solo el día 1.
--         · NO SE POSTEA ANTES DE QUE TERMINE EL MES (MX002): hasta el
--           último día siguen entrando costos y facturas.
--         · Las obras que NO están listas (sin revisar, sin lo de antes
--           confirmado, sin cuenta de ingreso, con el contrato de la ficha
--           cambiado después de revisarlas, con más costo que su estimado)
--           y las excluidas a propósito no entran; la respuesta, la foto, el
--           control del ajuste y la fila 176 del cierre dicen cuáles y por
--           qué. Las que no están listas DETIENEN el cierre del mes.
--   (7) DESDE QUÉ MES SE EXIGE (wip_config.exigir_desde). El cierre (c9)
--       pide, para cerrar un mes, cada obra con movimiento revisada y el
--       ajuste posteado y al día. Se exige desde el mes en que se pega este
--       archivo por primera vez (en producción, noviembre de 2026): los
--       meses que terminaron ANTES de que la capa existiera no se frenan por
--       ella. Octubre de 2026 ya terminó y sigue abierto: se puede ver su
--       WIP, revisar sus obras y postear su ajuste si Edgar quiere la serie
--       completa, pero no detiene su cierre, que ya tiene su lista. Se
--       cambia con fn_wip_config('{"exigir_desde": "2026-10"}') (o null: no
--       se exige). En un mes que todavía no termina tampoco se exige: se
--       dice cuánto falta.
--   (8) LOS CONTROLES (fn_wip_control / v_wip_control; orden, cuadre, nivel
--       «cuadre» | «aviso», ok, detalle en llano):
--         10 en 1200, 2400, 2410 y 5950 solo está el ajuste del WIP
--         20 cada ajuste vivo es su asiento, y el saldo de 1200, 2400 y 2410
--            por obra al cierre del mes es el del ajuste vivo
--         30 lo facturado a la fecha = las facturas del libro (sus notas de
--            crédito restando), obra por obra
--         40 cada obra que entra en el mes, decidida: revisada (con lo de
--            antes confirmado, su cuenta de ingreso y el contrato de la ficha
--            sin cambiar desde entonces) o excluida con su nota; y ninguna
--            obra que traía saldo del ajuste anterior fuera del mes
--         50 el ajuste del mes posteado y al día (dice quién quedó fuera)
--         60 ninguna obra con más costo que su estimado revisado (sin
--            excepción por nota)
--         90 las protecciones de la capa
--        110 (aviso) obras que ya andaban sin lo de antes confirmado
--        120 (aviso) obras con pérdida
--        125 (aviso) obras al 100 % sin estar terminadas
--        130 (aviso) revisadas con un precio que no es el de la ficha
--        140 (aviso) facturado por encima del contrato
--        150 (aviso) ingreso de la obra que no es factura ni ajuste
--        160 (aviso) obras con dinero fuera del WIP: las terminadas con
--            movimiento en el mes, y las que la app todavía no tiene en obra
--            (en estimación, enviada, no aprobada) con facturas en el libro
--        165 (aviso) obras activas sin contrato que no son de servicio
--        170 (aviso) horas sin costo en el libro (a estándar, c10)
--        180 (aviso) la suma de los hitos no es el contrato
--       fn_wip_cierre(periodo) los resume en las cuatro filas que el cierre
--       (c9) enseña: 174 los cuadres (detiene), 175 las revisiones del mes
--       (detiene), 176 el ajuste posteado (detiene) y 177 los avisos. El
--       nombre de la 174 y de la 177 dice cuáles están en rojo (la ronda de
--       c9 avisa de cada rojo nuevo por el nombre de la fila), y su detalle
--       lleva el principio de todos.
--
-- Decisiones de diseño (lo que f10 y el encargo dejaban abierto):
--   · EL PRECIO ES finanzas_proyecto.contrato, no «la suma de alcances
--     aprobados» que proponía f10. En producción (11-nov) el contrato de la
--     ficha ES la suma de los hitos en todas las obras con hitos, con sus
--     órdenes de cambio ya dentro; alcances existe en pocas obras y su
--     estado es texto libre para personas: hoy no sirve como fuente única.
--     Como la ficha cambia sin historia, cada revisión guarda el precio que
--     usó, el de la ficha ese día, y se avisa si la ficha cambió después
--     (130) o si ya no es la suma de sus hitos (180). Si un mes necesita
--     otro precio (un CO firmado que todavía no está en la ficha), la
--     revisión lo admite con su nota.
--   · EL PRIMER AJUSTE lleva al resultado de su mes todo lo sobre o
--     sub-facturado ACUMULADO desde el inicio de cada obra, también lo de
--     antes del libro: la apertura del 30-sep vino de QuickBooks sin WIP.
--     En el paralelo de 2026 es una diferencia explicada contra QuickBooks
--     (f08: categoría «WIP»). ▶ CPA: si lo quiere contra utilidades
--     retenidas (3900) es un ajuste a la apertura, a mano, y entonces el
--     control 10 hay que enseñarle ese saldo (se avisa antes de hacerlo).
--   · LOS AJUSTES NO MUEVEN «COSTO POR OBRA» (c10) NI SU CONTROL: el ajuste
--     nace con su reverso, y v_margen_obra suma el libro sin corte de fecha:
--     los dos se anulan en ingreso_libro y en costo_real, siempre, y los
--     cuadres de v_margen_control siguen en verde. En «Estados» (c4), que va
--     por fechas, el ingreso de fin de mes es el GANADO, y el día 1 vuelve a
--     ser lo facturado: eso es el WIP.
--   · «FACTURADO» ES LO DEL PUENTE DE FACTURAS. Un descuento al cobrar o un
--     ingreso a mano con esa obra no es facturación: se enseña aparte
--     (ingreso_otro) y se avisa (150). El WIP no lo absorbe: ajustaría un
--     activo por algo que nunca se va a facturar.
--   · LA MANO DE OBRA QUE NO ESTÁ EN EL LIBRO no está en el costo a la
--     fecha: las horas sin pago repartido salen «a estándar» en c10 y nunca
--     se postean. Con horas así el avance va corto. Se avisa (170); se
--     arregla repartiendo los pagos (c10) o, desde enero, con la nómina.
--   · UNA OBRA TERMINADA se cierra en el WIP el mes en que Edgar la revisa
--     como terminada (100 %: ganado = precio; lo que falte por facturar
--     queda sub-facturado ese mes). Si quedó algo por facturar (o facturado
--     de más), SIGUE ENTRANDO cada mes —un toque: «sigue terminada»— hasta
--     que lo facturado sea su precio; con el saldo en cero, ya no entra. La
--     app no guarda la fecha de término (se lee si existe:
--     proyectos.completado_el); por eso la termina Edgar, no una fecha
--     adivinada.
--   · UNA APERTURA CON SALDO EN LAS CUENTAS DEL WIP (si la balanza del CPA
--     al 30-sep trae 1200, 2400 o 2410) NO se continúa sola: esta capa
--     postea cada mes el sobre y sub-facturado ACUMULADO desde el inicio de
--     cada obra, y ese saldo de apertura quedaría dos veces. El cuadre 10
--     lo dice en rojo, con ese porqué. Se decide con el CPA ANTES de postear
--     la apertura: que entre sin WIP (contra 3900), o una versión de esta
--     capa cuyo ajuste descuente lo que la apertura ya trae.
--
-- LA SEGURIDAD (la regla de c2, B.20, y lo que c4, c6, c8, c9 y c10 sellan):
--   · NINGUNA función de aquí es SECURITY DEFINER. Las que llama la
--     pantalla son SECURITY INVOKER, sin EXECUTE para public, anon ni
--     service_role, con EXECUTE para authenticated y es_dueno() por dentro
--     (fn_wip_exigir_dueno): leen con la policy de cada tabla (solo el
--     dueño) y escriben con la policy de escritura del dueño de las tablas
--     de c12; al libro entran por fn_postear y fn_reversar, que c2 da al
--     dueño. Así «permisos» de c2 sigue en verde. Las auxiliares de las
--     vistas no frenan a nadie con un error: a quien no es el dueño no le
--     devuelven nada (el equipo no ve nada de c12: son los márgenes de cada
--     obra).
--   · fn_wip_pegado y fn_wip_precondiciones: sin API (solo el SQL Editor).
--   · Las tablas nacen con RLS y policies solo-dueño, y con la guarda de
--     c6, c9 y c10: un trigger (fn_wip_guarda) que solo deja escribir con la
--     marca de la transacción (mx_wip.escribe = la tabla) que ponen las
--     funciones de aquí; a mano, aunque sea el dueño por la API, MX003. Una
--     revisión, lo confirmado de antes y un ajuste son rastro: no se editan
--     ni se borran; lo único que les pasa es quedar sustituidos o deshechos,
--     una vez.
--   · Las vistas son security_invoker y leen solo funciones de aquí (nunca
--     una vista de otra capa, que se rehace al volver a pegar su archivo);
--     de periodos y de cuentas no fijan estado, cadena_al_cerrar, activa ni
--     saldo_normal (c2-pruebas las reescribe a propósito).
--   · Nada lleva un prefijo que otra capa sella ni de la otra sesión que
--     escribe esta base: aquí todo es fn_wip_* / wip_* / v_wip_*. es_dueno()
--     no se toca. c10 se lee al vuelo y solo para proponer (si falta, o si
--     cambia de forma, no hay propuesta de fábrica y lo demás sigue).
--   · Lo que la pantalla escribe pasa por PostgREST con la sesión del
--     dueño: s1 (el código del teléfono) exige aal2 en cada petición. Esta
--     capa no añade nada a eso.
--
-- LOS ERRORES CON NOMBRE (conta.js los traduce mirando el código; ninguno
-- nuevo):
--   MX000  falta algo que este archivo da por hecho: no se aplica nada
--          (fn_wip_precondiciones dice qué)
--   MX002  el período: no existe, no es un mes, está cerrado, todavía no
--          empezó (revisar) o todavía no terminó (postear), o falta abrir el
--          mes siguiente para el reverso del día 1
--   MX003  las tablas de c12 solo las escriben sus funciones (la guarda); lo
--          que es rastro no se edita ni se borra
--   MX004  una cuenta que no sirve: la de ingreso de la obra, o 1200, 2400,
--          2410, 5950 (no existe, inactiva, de grupo)
--   MX005  un monto mal: nulo, cero o negativo donde no cabe, con más de dos
--          decimales, o fuera de rango
--   MX008  no procede: la obra no existe o no lleva WIP, no tiene contrato,
--          no hay propuesta que confirmar o ya no es la que se vio, la obra
--          no está terminada en la app, no hay ajuste que deshacer
--   22023  entrada mal formada: falta un dato (el costo estimado, la nota
--          que el cambio pide), una clave desconocida, un mes mal escrito
--   42501  permiso: solo el dueño; anon y service_role, nada
--   55P03  (de Postgres, «lock timeout») la app estaba usando las tablas de
--          c12 mientras se pegaba: no se aplicó nada, se vuelve a pegar
--   Y los de c2 que salen tal cual al postear o reversar (MX001, MX002,
--   MX004, MX006, MX007), con su mensaje en llano.
--
-- Lo que este archivo NO toca: c1..c11, s1, p1, es_dueno(), docs/sql, el
-- libro (solo entra por fn_postear y fn_reversar, como el dueño), las
-- tablas de la app (lee proyectos, finanzas_proyecto, hitos, facturas,
-- notas_credito, recibos, trabajos_externos, horas, costos_equipo,
-- perfiles y mapeo_tipo_proyecto). No pone índices, triggers ni llaves en
-- tablas ajenas, ni escribe en finanzas_proyecto ni en alcances. La
-- factura y la retención POR COBRAR (1120) son de c11 y de c3. La retención
-- POR PAGAR a los subcontratistas (2020) no la lleva todavía ninguna capa
-- (cabecera de c11, «Lo que NO hace»): el costo de un sub entra entero por
-- su papel, que es lo que este WIP cuenta como costo.
--
-- Cómo se instala (Edgar, en este orden):
--   1. SQL Editor → pegar ESTE archivo entero → Run. Al final sale una
--      tabla: la configuración (desde qué mes se exige), las tablas y las
--      vistas, cuántas obras llevan WIP y cuántas ya andaban antes del
--      libro, el mes que toca y cómo va, el control y el paso siguiente. Si
--      algo de lo que da por hecho falta, para con MX000 y no queda nada.
--      Con la pantalla de Contabilidad cerrada (si alguien la está leyendo,
--      55P03: se vuelve a pegar).
--   2. SQL Editor → volver a pegar docs/conta/c9-cierre.sql (el que trae
--      las filas 174 a 177: el cierre mira el WIP). Sin este paso el cierre
--      no lo mira, y la prueba 39 sale «omitida» diciéndolo.
--   3. SQL Editor → pegar docs/conta/c12-pruebas.sql → sus filas, todas en
--      true (las «omitida» dicen por qué; no es un fallo).
--   4. En la app: Contabilidad → WIP. Por cada obra: confirmar lo de antes
--      del libro (una vez) y el costo estimado del mes (un toque); después
--      «Postear el ajuste».
--
-- Lo que llama la pantalla (RPC, como el dueño; las que escriben, con POST):
--   fn_wip_revisar(p_proyecto text, p_periodo text, p jsonb)   la revisión del mes
--        p: {"confirmar": true} | {"costo_estimado": "12345.00", "nota": "…"} |
--           {"terminada": true} | {"excluir": true, "nota": "…"} |
--           {"precio_de_despues": true}; y, si hace falta, "precio_contrato"
--   fn_wip_antes_propuesta(p_proyecto text)                    solo lee: lo de antes, propuesto
--   fn_wip_antes(p_proyecto text, p jsonb)                     confirma lo de antes: {"costo", "facturado", "nota"}
--   fn_wip_obra(p_proyecto text, p jsonb)                      la marca: {"modo": "contrato" | "tm" | "auto", "nota"}
--   fn_wip_postear(p_periodo text, p_motivo text)              postea (o rehace) el ajuste del mes
--   fn_wip_deshacer(p_periodo text, p_motivo text)             lo quita, con su motivo
--   fn_wip_config(p jsonb)                                     {"exigir_desde": "2026-11" | null}
--   fn_wip_resumen(p_periodo text)                             solo lee: los totales, el ajuste y lo que falta
--   fn_wip_schedule(p_periodo text) / fn_wip_control(p_periodo text) / fn_wip_cierre(p_periodo text)
-- Y lee: v_wip_schedule (filtrada por periodo), v_wip_obras, v_wip_control,
-- v_wip_ajustes, v_wip_revisiones, wip_config. Montos en dólares,
-- numeric(14,2); porcentajes de 0 a 100 con dos decimales. La pantalla no
-- suma nada: los totales vienen en fn_wip_resumen.
--
-- ▶ PARA EL CPA (no frena nada; se dice):
--   · ¿Los libros llevan el ingreso por avance (costo a costo) también en lo
--     que se presenta, o solo para la gestión y la afianzadora?
--   · El primer ajuste y el corte de año: el ajuste de diciembre se deshace
--     el 1 de enero; si 2026 se cierra en QuickBooks sin WIP, 2027 arranca
--     con ese reverso. ¿Va contra 3900, o el ajuste de diciembre entra
--     también en el 2026 oficial?
--   · La provisión por pérdida como «lo que falta por reconocer» (arriba).
-- =====================================================================
-- (Lo primero, como en c4, c6 y c10: el pegado espera un candado como mucho
-- medio segundo. Con la app leyendo, para con 55P03 («lock timeout»), no se
-- aplica nada y se vuelve a pegar. Dura lo que dura el pegado.)
set local lock_timeout = '500ms';


-- ---------------------------------------------------------------------
-- 0. Las guardas, y lo que este archivo da por hecho (MX000 sin tocar nada)
-- ---------------------------------------------------------------------
-- Lo que falta para pegar c12, en llano (nulo = nada). La usan la
-- precondición de abajo y las pruebas.
create or replace function public.fn_wip_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
  v_v     bigint;
  c_tablas constant text[] := array['wip_config', 'wip_obras', 'wip_antes', 'wip_revisiones', 'wip_ajustes', 'wip_ajuste_obras'];
  c_vistas constant text[] := array['v_wip_obras', 'v_wip_schedule', 'v_wip_control', 'v_wip_ajustes', 'v_wip_revisiones'];
  c_fn     constant text[] := array['fn_wip_precondiciones', 'fn_wip_exigir_dueno', 'fn_wip_ve', 'fn_wip_guarda', 'fn_wip_usd',
                                    'fn_wip_mes', 'fn_wip_dia', 'fn_wip_monto', 'fn_wip_libro_desde', 'fn_wip_toca', 'fn_wip_meses',
                                    'fn_wip_asientos', 'fn_wip_obras', 'fn_wip_libro', 'fn_wip_calcular', 'fn_wip_schedule',
                                    'fn_wip_plan', 'fn_wip_ajuste_estado', 'fn_wip_resumen', 'fn_wip_antes_propuesta',
                                    'fn_wip_antes', 'fn_wip_obra', 'fn_wip_config', 'fn_wip_revisar', 'fn_wip_postear',
                                    'fn_wip_deshacer', 'fn_wip_control', 'fn_wip_cierre', 'fn_wip_pegado'];
begin
  foreach v_x in array array['es_dueno()', 'fn_desde_editor()', 'fn_fecha_miami(timestamptz)', 'fn_libro_version()',
                             'fn_postear(jsonb)', 'fn_reversar(uuid,text)'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'periodos', 'asientos', 'asiento_lineas', 'perfiles', 'proyectos', 'finanzas_proyecto',
                             'hitos', 'facturas', 'notas_credito', 'mapeo_tipo_proyecto', 'recibos', 'trabajos_externos',
                             'horas', 'costos_equipo'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if cardinality(v_falta) > 0 then
    return format('c12 se pega después de c1, c2 y c3 (y de c4, c6, c7, s1, p1, c8, c9 y c10 si se usan), con las tablas de la app: '
                  'falta %s.', array_to_string(v_falta, ', '));
  end if;
  -- La versión de c2 que va con esta capa (la del tiempo en producción).
  execute 'select public.fn_libro_version()' into v_v;
  if coalesce(v_v, 0) < 2026100201 then
    return format('el c2-libro.sql pegado es anterior (marca %s; esta capa pide 2026100201): vuelve a pegar c2-libro.sql.', v_v);
  end if;
  -- Las columnas que esta capa lee por su nombre.
  select string_agg(x.t || '.' || x.c, ', ' order by x.t, x.c) into v_x
    from (values ('proyectos', 'nombre'), ('proyectos', 'tipo'), ('proyectos', 'estado'), ('proyectos', 'cliente'),
                 ('proyectos', 'horas_reales_base'), ('finanzas_proyecto', 'contrato'), ('finanzas_proyecto', 'proyecto_id'),
                 ('hitos', 'proyecto_id'), ('hitos', 'monto'),
                 ('facturas', 'proyecto_id'), ('facturas', 'fecha'), ('facturas', 'monto'), ('facturas', 'estado'),
                 ('facturas', 'contabilizado_en'), ('notas_credito', 'anula_a'), ('notas_credito', 'contabilizado_en'),
                 ('mapeo_tipo_proyecto', 'tipo'), ('mapeo_tipo_proyecto', 'cuenta'), ('mapeo_tipo_proyecto', 'confirmado_el'),
                 ('recibos', 'proyecto_id'), ('recibos', 'fecha'), ('recibos', 'total'), ('recibos', 'estado'),
                 ('trabajos_externos', 'proyecto_id'), ('trabajos_externos', 'fecha'), ('trabajos_externos', 'costo'),
                 ('horas', 'proyecto_id'), ('horas', 'fecha'), ('horas', 'horas'), ('horas', 'usuario_id'),
                 ('costos_equipo', 'usuario_id'), ('costos_equipo', 'costo_hora'), ('perfiles', 'nombre'), ('perfiles', 'rol'),
                 ('asientos', 'reversa_a'), ('asientos', 'reversible'), ('asientos', 'origen_tabla'), ('asientos', 'camino'),
                 ('asiento_lineas', 'proyecto_id'), ('asiento_lineas', 'partida_tabla'),
                 ('cuentas', 'tipo'), ('cuentas', 'regla_obra'), ('cuentas', 'regla_cost_code'), ('cuentas', 'imputable'),
                 ('periodos', 'desde'), ('periodos', 'hasta'), ('periodos', 'tipo')) as x(t, c)
   where not exists (select 1 from information_schema.columns k
                      where k.table_schema = 'public' and k.table_name = x.t and k.column_name = x.c);
  if v_x is not null then
    return format('faltan columnas que esta capa lee: %s. ¿Es la base de la app, con c3 pegado?', v_x);
  end if;
  -- Las cuatro cuentas del WIP (c1): existen, reciben asientos, van por obra
  -- y sin cost code, y son de la clase que toca.
  select string_agg(format('%s (%s)', x.codigo, x.que), ', ' order by x.codigo) into v_x
    from (select w.codigo,
                 case when k.codigo is null then 'no existe'
                      when not coalesce(k.imputable, false) then 'es de grupo'
                      when not coalesce((to_jsonb(k)->>'activa')::boolean, true) then 'está inactiva'
                      when k.tipo <> w.tipo then 'es de tipo ' || k.tipo || ' y se esperaba ' || w.tipo
                      when k.regla_obra <> 'obligatoria' then 'no exige obra'
                      when k.regla_cost_code <> 'prohibida' then 'admite cost code' end as que
            from (values ('1200', 'activo'), ('2400', 'pasivo'), ('2410', 'pasivo'), ('5950', 'costo')) w(codigo, tipo)
            left join cuentas k on k.codigo = w.codigo) x
   where x.que is not null;
  if v_x is not null then
    return format('las cuentas del WIP no están como esta capa las usa: %s. Vuelve a pegar c1-plan-de-cuentas.sql (1200 y 2400 '
                  'sobre y sub-facturado, 2410 y 5950 la pérdida: por obra, sin cost code).', v_x);
  end if;
  -- Una tabla con el nombre de las de c12 que no sea de c12: se para antes de
  -- tocar nada (la lección de c8 con ia_propuestas).
  foreach v_x in array array['wip_config:exigir_desde', 'wip_obras:modo', 'wip_antes:facturado', 'wip_revisiones:costo_estimado',
                             'wip_ajustes:huella', 'wip_ajuste_obras:ingreso_ganado'] loop
    if to_regclass('public.' || split_part(v_x, ':', 1)) is not null
       and not exists (select 1 from information_schema.columns
                        where table_schema = 'public' and table_name = split_part(v_x, ':', 1) and column_name = split_part(v_x, ':', 2)) then
      return format('la tabla %s ya existe en esta base y no es la de c12 (no tiene la columna %s): otra cosa usa ese nombre. No la '
                    'toco; avisa antes de seguir.', split_part(v_x, ':', 1), split_part(v_x, ':', 2));
    end if;
  end loop;
  -- Una vista o una función con nombre de c12 que no sea de c12 (otra sesión
  -- escribe esta misma base): «create or replace» la pisaría sin avisar.
  select string_agg(x.que, ', ' order by x.que) into v_x
    from (select 'la vista ' || c.relname as que
            from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind in ('v', 'm', 'r') and c.relname = any (c_vistas)
             and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c12: %'
          union all
          select 'la función ' || p.oid::regprocedure::text
            from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.proname = any (c_fn)
             and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c12: %') x;
  if v_x is not null then
    return format('ya hay en esta base, con nombre de c12 y sin ser de c12: %s. No lo piso; avisa antes de seguir.', v_x);
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: el WIP lo revisa el dueño.';
  end if;
  -- Nada ajeno colgado de las vistas de c12 (se borran y se rehacen).
  select string_agg(distinct format('la vista %s', dc.oid::regclass), ', ') into v_x
    from pg_depend d
    join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
    join pg_class dc on dc.oid = rw.ev_class
    join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
   where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname = any (c_vistas)
     and dc.oid <> cv.oid
     and not (dc.relnamespace = 'public'::regnamespace and dc.relname = any (c_vistas));
  if v_x is not null then
    return format('%s depende(n) de las vistas de c12, que al pegarlo se borran y se rehacen: guarda su definición, bórralas, '
                  'pega c12 y vuelve a crearlas.', v_x);
  end if;
  return null;
end $$;
revoke execute on function public.fn_wip_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_wip_precondiciones() is 'c12: lo que falta para pegar c12-wip.sql (nulo = nada): c1, c2 (marca 2026100201) y c3, las tablas y columnas de la app que lee, las cuentas 1200, 2400, 2410 y 5950 por obra y sin cost code, el SQL Editor, un dueño activo, nada ajeno con nombre de c12 y nada ajeno sobre sus vistas.';

do $$
declare
  v text;
begin
  v := public.fn_wip_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c12-wip NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1, c2, c3, c4, c6, c7, s1, p1, c8, c9, c10 (c11) y después este archivo (pruebas/conta/README.md, §0).';
  end if;
end $$;

-- ¿Quién llama por la API? Solo el dueño. Desde el SQL Editor o pg_cron
-- (current_user no es un rol de la API) pasa. Solo es_dueno(), como c4, c6,
-- c9 y c10: fn_desde_editor no es ejecutable por authenticated.
create or replace function public.fn_wip_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if current_user in ('authenticated', 'anon') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501',
      message = 'El WIP (lo ganado, lo facturado y el margen de cada obra) lo ve y lo toca solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_wip_exigir_dueno() from public, anon, service_role;
grant  execute on function public.fn_wip_exigir_dueno() to authenticated;
comment on function public.fn_wip_exigir_dueno() is 'c12: la guarda de lo que llama la pantalla: por la API solo el dueño (es_dueno); el SQL Editor y pg_cron pasan.';

-- ¿Ve quien mira? Lo mismo, sin error: las auxiliares de las vistas no
-- frenan a nadie; a quien no es el dueño no le devuelven nada.
create or replace function public.fn_wip_ve() returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select current_user not in ('authenticated', 'anon', 'service_role') or coalesce(es_dueno(), false)
$$;
revoke execute on function public.fn_wip_ve() from public, anon, service_role;
grant  execute on function public.fn_wip_ve() to authenticated;
comment on function public.fn_wip_ve() is 'c12: verdadero para el dueño por la API y para el SQL Editor; las auxiliares de las vistas no devuelven nada a los demás.';


-- ---------------------------------------------------------------------
-- 1. Las tablas (nacen cerradas: solo el dueño lee; escribe solo el dueño
--    por las funciones de aquí, con la marca de la transacción). Montos en
--    dólares, numeric(14,2). Llaves foráneas a periodos, asientos, cuentas
--    y entre tablas de c12; a proyectos NO (es de la app: no se le cuelga
--    nada que cambie cómo se borra; c2 ya impide borrar una obra con
--    asientos). Para crecer, «add column if not exists».
-- ---------------------------------------------------------------------
-- La configuración: una sola fila. exigir_desde: el primer mes (AAAA-MM) en
-- que el cierre exige el WIP; vacío = no se exige todavía.
create table if not exists public.wip_config (
  id               int         primary key,
  exigir_desde     text,
  actualizado      timestamptz not null default now(),
  actualizado_por  uuid,
  constraint wip_config_una   check (id = 1),
  constraint wip_config_desde check (exigir_desde is null or exigir_desde ~ '^[0-9]{4}-(0[1-9]|1[0-2])$')
);
comment on table public.wip_config is 'c12: la configuración del WIP (una fila): exigir_desde, el primer mes (AAAA-MM) cuyo cierre exige cada obra revisada y el ajuste posteado (vacío = no se exige todavía; nace con el mes en que se pegó c12 por primera vez). Se cambia con fn_wip_config.';

-- La marca de una obra, cuando la regla (precio fijo = residencial o
-- comercial con contrato) no acierta: «contrato» = lleva WIP; «tm» = no.
create table if not exists public.wip_obras (
  proyecto_id   text        primary key,
  modo          text,
  nota          text,
  marcado_el    timestamptz not null default now(),
  marcado_por   uuid,
  historial     jsonb       not null default '[]'::jsonb,
  constraint wip_obras_modo      check (modo is null or modo in ('contrato', 'tm')),
  constraint wip_obras_historial check (jsonb_typeof(historial) = 'array')
);
comment on table public.wip_obras is 'c12: la marca de una obra para el WIP cuando la regla no acierta (la regla: lleva WIP la obra residencial o comercial con contrato en su ficha): modo «contrato» = es de precio fijo y lleva WIP; «tm» = es de servicio o por tiempo y material y no lo lleva (su ingreso es lo facturado); vacío = vuelve a la regla. Con su nota, quién y cuándo, y cada cambio anterior en historial. Se escribe con fn_wip_obra.';

-- Lo de antes del libro, por obra: el costo y lo facturado hasta el día
-- anterior al libro (30-sep-2026), confirmados por Edgar. Solo se añade; una
-- confirmación nueva sustituye a la anterior, que queda.
create table if not exists public.wip_antes (
  id              uuid          primary key default gen_random_uuid(),
  proyecto_id     text          not null,
  costo           numeric(14,2) not null,
  facturado       numeric(14,2) not null,
  propuesta       jsonb         not null default '{}'::jsonb,
  nota            text,
  confirmado_el   timestamptz   not null default now(),
  confirmado_por  uuid,
  sustituida_el   timestamptz,
  sustituida_por  uuid,
  constraint wip_antes_montos    check (costo >= 0 and facturado >= 0),
  constraint wip_antes_propuesta check (jsonb_typeof(propuesta) = 'object')
);
create unique index if not exists wip_antes_vigente on public.wip_antes (proyecto_id) where sustituida_el is null;
create index if not exists wip_antes_obra_idx on public.wip_antes (proyecto_id);
comment on table public.wip_antes is 'c12: lo de antes del libro de cada obra que ya andaba: el costo y lo facturado desde su inicio hasta el día anterior al libro (30-sep-2026), CONFIRMADOS por Edgar (confirmado_el, confirmado_por, nota), y lo que la base proponía ese día desde los papeles de la app (propuesta: tickets, trabajos externos, horas × tarifa, facturas). La vigente es la que no tiene sustituida_el; las anteriores quedan. Sin una vigente, una obra que ya andaba no entra en el ajuste. Se escribe con fn_wip_antes.';

-- La revisión de una obra en un mes: el costo total estimado revisado y el
-- precio del contrato que se usó; o «terminada»; o «excluida» (ese mes queda
-- fuera del WIP a propósito, con su nota). Solo se añade; otra la sustituye.
create table if not exists public.wip_revisiones (
  id                uuid          primary key default gen_random_uuid(),
  proyecto_id       text          not null,
  periodo           text          not null references public.periodos (periodo),
  precio_contrato   numeric(14,2),
  precio_ficha      numeric(14,2),
  costo_estimado    numeric(14,2),
  terminada         boolean       not null default false,
  excluida          boolean       not null default false,
  origen            text          not null,
  propuesta         numeric(14,2),
  propuesta_origen  text,
  nota              text,
  revisado_el       timestamptz   not null default now(),
  revisado_por      uuid,
  sustituida_el     timestamptz,
  sustituida_por    uuid
);
-- (la columna y las reglas de hoy, también sobre una tabla de una versión
-- anterior de este archivo; al volver a pegar quedan igual)
alter table public.wip_revisiones add column if not exists excluida boolean not null default false;
alter table public.wip_revisiones alter column precio_contrato drop not null;
alter table public.wip_revisiones drop constraint if exists wip_revisiones_precio;
alter table public.wip_revisiones add constraint wip_revisiones_precio
  check (case when excluida then precio_contrato is null or precio_contrato > 0 else coalesce(precio_contrato > 0, false) end);
alter table public.wip_revisiones drop constraint if exists wip_revisiones_costo;
alter table public.wip_revisiones add constraint wip_revisiones_costo
  check (case when terminada or excluida then costo_estimado is null else coalesce(costo_estimado > 0, false) end);
alter table public.wip_revisiones drop constraint if exists wip_revisiones_origen;
alter table public.wip_revisiones add constraint wip_revisiones_origen
  check (origen in ('estimado', 'mes_anterior', 'a_mano', 'terminada', 'excluida')
         and (origen = 'terminada') = terminada and (origen = 'excluida') = excluida and not (terminada and excluida)
         and (not excluida or coalesce(btrim(nota), '') <> ''));
create unique index if not exists wip_revisiones_vigente on public.wip_revisiones (proyecto_id, periodo) where sustituida_el is null;
create index if not exists wip_revisiones_periodo_idx on public.wip_revisiones (periodo);
comment on table public.wip_revisiones is 'c12: la revisión de cada obra en cada mes: el costo total estimado REVISADO (costo_estimado: desde el inicio de la obra hasta terminarla; vacío si terminada, que usa el costo que lleva, y si excluida), el precio del contrato que se usó ese mes (precio_contrato) y el de la ficha ese día (precio_ficha: finanzas_proyecto.contrato, que cambia sin historia), de dónde salió el número (origen: mes_anterior = se confirmó lo del mes anterior; estimado = se confirmó el estimado de la obra; a_mano = otro número; terminada; excluida = ese mes la obra queda fuera del WIP a propósito, con su porqué en la nota), lo que la base proponía (propuesta, propuesta_origen), la nota, quién y cuándo. La vigente es la que no tiene sustituida_el; las anteriores quedan. No se edita ni se borra. Se escribe con fn_wip_revisar.';

-- Cada ajuste posteado: el asiento de cierre de un mes. Solo se añade; lo
-- único que le pasa es quedar deshecho (una vez), con su motivo y su reverso.
create table if not exists public.wip_ajustes (
  id               uuid          primary key default gen_random_uuid(),
  periodo          text          not null references public.periodos (periodo),
  asiento_id       uuid          not null references public.asientos (id),
  numero           text          not null,
  fecha            date          not null,
  reverso_auto_id  uuid          references public.asientos (id),
  obras            int           not null,
  lineas           int           not null,
  sub_facturado    numeric(14,2) not null,
  sobre_facturado  numeric(14,2) not null,
  perdida          numeric(14,2) not null,
  huella           text          not null,
  sustituye_a      uuid          references public.wip_ajustes (id),
  motivo           text,
  creado_el        timestamptz   not null default now(),
  creado_por       uuid,
  deshecho_el      timestamptz,
  deshecho_por     uuid,
  deshecho_motivo  text,
  reverso_id       uuid          references public.asientos (id),
  por_fuera        boolean       not null default false,
  constraint wip_ajustes_montos   check (sub_facturado >= 0 and sobre_facturado >= 0 and perdida >= 0 and obras >= 1 and lineas >= 2),
  constraint wip_ajustes_deshecho check ((deshecho_el is not null) = (coalesce(btrim(deshecho_motivo), '') <> ''))
);
create unique index if not exists wip_ajustes_asiento_unico on public.wip_ajustes (asiento_id);
-- (un mes, un ajuste VIVO; los deshechos quedan como rastro)
create unique index if not exists wip_ajustes_vivo on public.wip_ajustes (periodo) where deshecho_el is null;
comment on table public.wip_ajustes is 'c12: cada ajuste de WIP posteado: el mes (periodo), su asiento (asiento_id, numero, fecha: el último día del mes) y el reverso automático del día 1 con que nació (reverso_auto_id), cuántas obras y líneas, lo sub-facturado (1200), lo sobre-facturado (2400) y la pérdida provisionada (2410) que llevó, la huella de lo calculado (para saber si sigue al día), a cuál sustituye si rehízo otro (sustituye_a, motivo), quién y cuándo; y, deshecho, por quién, cuándo, por qué, el reverso que lo quitó (reverso_id) y si se había reversado por fuera de aquí (por_fuera). Un mes, un ajuste vivo (sin deshecho_el). Solo se añade; lo único que cambia es el paso a deshecho.';
comment on column public.wip_ajustes.huella is 'md5 de las obras que entraron, cada una con su precio, costo estimado, si está terminada, costo a la fecha, facturado a la fecha, ganado, sub, sobre, provisión y cuenta de ingreso: si lo que da el WIP hoy tiene otra huella, el ajuste ya no está al día.';

-- La foto de cada obra en cada ajuste: lo que se calculó al postear (las que
-- entraron y las que se quedaron fuera, con su porqué).
create table if not exists public.wip_ajuste_obras (
  ajuste_id            uuid          not null references public.wip_ajustes (id),
  proyecto_id          text          not null,
  n                    int           not null,
  obra                 text,
  cliente              text,
  tipo                 text,
  obra_estado          text,
  estado               text          not null,
  falta                text[]        not null default '{}',
  falta_texto          text,
  en_ajuste            boolean       not null,
  terminada            boolean       not null default false,
  revision_id          uuid          references public.wip_revisiones (id),
  antes_id             uuid          references public.wip_antes (id),
  de_antes             boolean       not null default false,
  precio_contrato      numeric(14,2),
  costo_estimado       numeric(14,2),
  utilidad_estimada    numeric(14,2),
  costo_libro          numeric(14,2),
  costo_antes          numeric(14,2),
  costo_fecha          numeric(14,2),
  pct_avance           numeric(7,2),
  pct_real             numeric,
  pasa_de_100          boolean,
  ingreso_ganado       numeric(14,2),
  facturado_libro      numeric(14,2),
  facturado_antes      numeric(14,2),
  facturado_fecha      numeric(14,2),
  sub_facturado        numeric(14,2),
  sobre_facturado      numeric(14,2),
  costo_para_terminar  numeric(14,2),
  utilidad_fecha       numeric(14,2),
  perdida_total        numeric(14,2),
  perdida_provision    numeric(14,2),
  cuenta_ingreso       text          references public.cuentas (codigo),
  ingreso_otro         numeric(14,2),
  avisos               text[]        not null default '{}',
  constraint wip_ajuste_obras_pk     primary key (ajuste_id, proyecto_id),
  constraint wip_ajuste_obras_estado check (estado in ('lista', 'pendiente', 'excluida', 'sin_movimiento') and en_ajuste = (estado = 'lista'))
);
create index if not exists wip_ajuste_obras_obra_idx on public.wip_ajuste_obras (proyecto_id);
-- (el estado «excluida», también sobre una tabla de una versión anterior de este archivo)
alter table public.wip_ajuste_obras drop constraint if exists wip_ajuste_obras_estado;
alter table public.wip_ajuste_obras add constraint wip_ajuste_obras_estado
  check (estado in ('lista', 'pendiente', 'excluida', 'sin_movimiento') and en_ajuste = (estado = 'lista'));
comment on table public.wip_ajuste_obras is 'c12: la foto de cada obra en cada ajuste de WIP, como se calculó al postear (las columnas de v_wip_schedule): las que entraron (en_ajuste, estado lista) con su precio, costo estimado, costo a la fecha, % de avance, ingreso ganado, facturado, sub y sobre-facturado, costo para terminar, utilidad y pérdida, su revisión (revision_id) y lo de antes que se usó (antes_id); y las que se quedaron fuera (pendiente, con lo que les faltaba; excluida, a propósito con su nota; sin_movimiento). El WIP de un mes cerrado se lee de aquí. No se edita ni se borra.';


-- ---------------------------------------------------------------------
-- 2. La guarda de las tablas de c12 (la de c6, c9 y c10, en su forma): solo
--    se escriben con la marca de la transacción (mx_wip.escribe = el nombre
--    de la tabla), que ponen las funciones de aquí justo antes de escribir
--    y quitan después. A mano —desde PostgREST, aunque sea el dueño, o
--    desde el SQL Editor sin la marca— da MX003. Y lo que es rastro no se
--    edita ni se borra. SECURITY INVOKER, sin grant a nadie (la dispara la
--    tabla).
-- ---------------------------------------------------------------------
create or replace function public.fn_wip_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_marca text := coalesce(current_setting('mx_wip.escribe', true), '');
  v_libres text[];
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003',
      message = format('%s no se trunca: es el rastro del WIP.', tg_table_name);
  end if;
  if tg_op = 'DELETE' then
    raise exception using errcode = 'MX003',
      message = format('%s no se borra: %s', tg_table_name,
                       case tg_table_name
                         when 'wip_config' then 'es la configuración (una fila); se cambia con fn_wip_config.'
                         when 'wip_obras' then 'la marca de una obra se cambia con fn_wip_obra (modo «auto» la quita) y su historia queda.'
                         when 'wip_antes' then 'lo confirmado de antes del libro se sustituye con otra confirmación (fn_wip_antes) y queda.'
                         when 'wip_revisiones' then 'una revisión se sustituye con otra (fn_wip_revisar) y queda.'
                         when 'wip_ajustes' then 'un ajuste se deshace con su motivo (fn_wip_deshacer) o se rehace (fn_wip_postear) y queda.'
                         else 'es la foto de un ajuste.' end);
  end if;
  if v_marca <> tg_table_name then
    raise exception using errcode = 'MX003',
      message = format('%s se escribe solo desde las funciones del WIP (%s), no a mano.', tg_table_name,
                       case tg_table_name
                         when 'wip_config' then 'fn_wip_config'
                         when 'wip_obras' then 'fn_wip_obra'
                         when 'wip_antes' then 'fn_wip_antes'
                         when 'wip_revisiones' then 'fn_wip_revisar'
                         else 'fn_wip_postear y fn_wip_deshacer' end);
  end if;
  if tg_op = 'UPDATE' then
    -- Lo único que le pasa a una fila de rastro: quedar sustituida (una
    -- confirmación, una revisión) o deshecha (un ajuste), una vez. Se compara
    -- la fila entera sin esas columnas: la guarda es de las seis tablas.
    v_libres := case tg_table_name
                  when 'wip_antes' then array['sustituida_el', 'sustituida_por']
                  when 'wip_revisiones' then array['sustituida_el', 'sustituida_por']
                  when 'wip_ajustes' then array['deshecho_el', 'deshecho_por', 'deshecho_motivo', 'reverso_id', 'por_fuera']
                  else null end;
    if tg_table_name = 'wip_ajuste_obras' then
      raise exception using errcode = 'MX003', message = 'wip_ajuste_obras no se edita: es la foto de un ajuste.';
    elsif v_libres is not null then
      if (to_jsonb(new) - v_libres) is distinct from (to_jsonb(old) - v_libres)
         or coalesce(to_jsonb(old)->>'sustituida_el', to_jsonb(old)->>'deshecho_el') is not null
         or coalesce(to_jsonb(new)->>'sustituida_el', to_jsonb(new)->>'deshecho_el') is null then
        raise exception using errcode = 'MX003',
          message = format('%s no se edita: %s', tg_table_name,
                           case tg_table_name
                             when 'wip_ajustes' then 'un ajuste solo pasa a deshecho, una vez, con su motivo.'
                             else 'solo queda sustituida, una vez, por la siguiente.' end);
      end if;
    elsif tg_table_name = 'wip_obras' and (to_jsonb(new)->>'proyecto_id') is distinct from (to_jsonb(old)->>'proyecto_id') then
      raise exception using errcode = 'MX003', message = 'La marca de una obra no cambia de obra.';
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.fn_wip_guarda() from public, anon, authenticated, service_role;
comment on function public.fn_wip_guarda() is 'c12: la guarda de las tablas de c12: se escriben solo con la marca de la transacción (mx_wip.escribe) que ponen sus funciones; una revisión y lo confirmado de antes solo quedan sustituidos (una vez), un ajuste solo pasa a deshecho (una vez), su foto no se edita, y nada se borra.';

do $$
declare
  t text;
begin
  foreach t in array array['wip_config', 'wip_obras', 'wip_antes', 'wip_revisiones', 'wip_ajustes', 'wip_ajuste_obras'] loop
    execute format('create or replace trigger trg_%s_guarda before insert or update or delete on public.%I '
                   'for each row execute function public.fn_wip_guarda()', t, t);
    execute format('create or replace trigger trg_%s_sin_truncate before truncate on public.%I '
                   'for each statement execute function public.fn_wip_guarda()', t, t);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 3. Los permisos: RLS, «solo el dueño lee», y en las tablas que escribe
--    una función INVOKER, la policy de escritura del dueño (con la guarda
--    de arriba delante: la policy dice quién, la marca dice por dónde).
--    anon y service_role, nada. Nadie borra por la API.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array['wip_config', 'wip_obras', 'wip_antes', 'wip_revisiones', 'wip_ajustes', 'wip_ajuste_obras'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
  -- Lo que escriben las funciones de la pantalla (como el dueño).
  foreach t in array array['wip_config', 'wip_obras', 'wip_antes', 'wip_revisiones', 'wip_ajustes'] loop
    execute format('create policy %I on public.%I for update to authenticated using ((select es_dueno())) with check ((select es_dueno()))',
                   t || '_dueno_edita', t);
    execute format('grant update on public.%I to authenticated', t);
  end loop;
  foreach t in array array['wip_obras', 'wip_antes', 'wip_revisiones', 'wip_ajustes', 'wip_ajuste_obras'] loop
    execute format('create policy %I on public.%I for insert to authenticated with check ((select es_dueno()))',
                   t || '_dueno_anade', t);
    execute format('grant insert on public.%I to authenticated', t);
  end loop;
end $$;

-- La fila de la configuración (con la marca de la guarda): al volver a pegar
-- no se pisa nada. Nace exigiendo el WIP desde el mes en curso (hora de
-- Miami): los meses que terminaron antes de que la capa existiera no se
-- frenan por ella (cabecera, punto 7).
do $$
begin
  if not exists (select 1 from public.wip_config where id = 1) then
    perform set_config('mx_wip.escribe', 'wip_config', true);
    insert into public.wip_config (id, exigir_desde) values (1, to_char(public.fn_fecha_miami(now()), 'YYYY-MM'));
    perform set_config('mx_wip.escribe', '', true);
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 4. Lo común: dinero, meses y días en llano, un monto que llega como
--    texto, desde cuándo hay libro, el mes que toca. Todo SECURITY INVOKER;
--    lo que usan las funciones de la pantalla y las vistas lleva EXECUTE
--    para authenticated.
-- ---------------------------------------------------------------------
-- Las vistas de c12 se borran aquí y se rehacen al final (en este mismo
-- pegado): así una función que cambie lo que devuelve puede volver a
-- crearse.
drop view if exists public.v_wip_obras, public.v_wip_schedule, public.v_wip_control, public.v_wip_ajustes, public.v_wip_revisiones;

-- Dólares como se leen: $1,234.56 (negativo con su signo).
create or replace function public.fn_wip_usd(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null then '—'
              when p < 0 then '-$' || to_char(-p, 'FM999,999,999,990.00')
              else '$' || to_char(p, 'FM999,999,999,990.00') end
$$;
revoke execute on function public.fn_wip_usd(numeric) from public, anon, service_role;
grant  execute on function public.fn_wip_usd(numeric) to authenticated;
comment on function public.fn_wip_usd(numeric) is 'c12: un monto en dólares como se lee ($1,234.56).';

-- Un mes como se dice: «octubre de 2026» (de un período AAAA-MM).
create or replace function public.fn_wip_mes(p_periodo text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p_periodo ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
              then (array['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre',
                          'noviembre', 'diciembre'])[substr(p_periodo, 6, 2)::int] || ' de ' || left(p_periodo, 4)
              else coalesce(p_periodo, '(sin mes)') end
$$;
revoke execute on function public.fn_wip_mes(text) from public, anon, service_role;
grant  execute on function public.fn_wip_mes(text) to authenticated;
comment on function public.fn_wip_mes(text) is 'c12: un mes como se dice («octubre de 2026») a partir de su período (2026-10).';

-- Un día en corto, con su año: 31-oct-2026.
create or replace function public.fn_wip_dia(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select extract(day from p)::int || '-'
         || (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int]
         || '-' || extract(year from p)::int
$$;
revoke execute on function public.fn_wip_dia(date) from public, anon, service_role;
grant  execute on function public.fn_wip_dia(date) to authenticated;
comment on function public.fn_wip_dia(date) is 'c12: un día en corto con su año (31-oct-2026).';

-- Un monto que llega de la pantalla como texto o número («12345.67»): se
-- mira su escala ANTES de convertirlo, como c2 (numeric(14,2) redondearía
-- callado). p_cero: si admite el cero. MX005 con lo que está mal.
create or replace function public.fn_wip_monto(p_texto text, p_que text, p_cero boolean default false) returns numeric
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
  if v < 0 or (v = 0 and not p_cero) then
    raise exception using errcode = 'MX005',
      message = format('%s: %s. Va en positivo%s.', initcap(left(p_que, 1)) || substr(p_que, 2), p_texto,
                       case when p_cero then ' (o cero)' else ', mayor que cero' end);
  end if;
  if v >= 1000000000000 then
    raise exception using errcode = 'MX005', message = format('%s: %s está fuera de rango.', initcap(left(p_que, 1)) || substr(p_que, 2), p_texto);
  end if;
  return round(v, 2);
end $$;
revoke execute on function public.fn_wip_monto(text, text, boolean) from public, anon, service_role;
grant  execute on function public.fn_wip_monto(text, text, boolean) to authenticated;
comment on function public.fn_wip_monto(text, text, boolean) is 'c12: un monto que llega como texto, validado antes de convertirlo (numérico, hasta dos decimales, positivo —o cero si se admite—, en rango): MX005 con lo que está mal.';

-- Desde cuándo hay libro: el día después de la apertura (30-sep-2026 → el 1
-- de octubre); lo de antes está en QuickBooks. La misma regla que c4 y c10.
create or replace function public.fn_wip_libro_desde() returns date
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce((select pa.hasta + 1 from public.periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1),
                  (select min(pm.desde) from public.periodos pm where pm.tipo = 'mes'))
$$;
revoke execute on function public.fn_wip_libro_desde() from public, anon, service_role;
grant  execute on function public.fn_wip_libro_desde() to authenticated;
comment on function public.fn_wip_libro_desde() is 'c12: el primer día del libro (el día después de la apertura; sin ella, el primer mes): lo de antes está en QuickBooks. La misma regla que c4 y c10.';

-- EL MES QUE TOCA: el mes abierto más viejo que ya terminó (el que se cierra
-- ahora); si ninguno terminó, el mes en curso. Hora de Miami.
create or replace function public.fn_wip_toca() returns text
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(
    (select p.periodo from public.periodos p
      where p.tipo = 'mes' and p.estado = 'abierto' and p.hasta < public.fn_fecha_miami(now())
      order by p.desde limit 1),
    (select p.periodo from public.periodos p
      where p.tipo = 'mes' and public.fn_fecha_miami(now()) between p.desde and p.hasta))
$$;
revoke execute on function public.fn_wip_toca() from public, anon, service_role;
grant  execute on function public.fn_wip_toca() to authenticated;
comment on function public.fn_wip_toca() is 'c12: el mes que toca: el mes abierto más viejo que ya terminó (el que se cierra ahora) o, si ninguno terminó, el mes en curso (hora de Miami).';

-- Los meses que enseña v_wip_schedule: desde que hay libro hasta el mes en
-- curso.
create or replace function public.fn_wip_meses() returns table (periodo text, desde date, hasta date)
language sql stable
set search_path = public, pg_temp
as $$
  select p.periodo, p.desde, p.hasta
    from public.periodos p
   where p.tipo = 'mes' and p.desde >= public.fn_wip_libro_desde() and p.desde <= public.fn_fecha_miami(now())
     and (select public.fn_wip_ve())
$$;
revoke execute on function public.fn_wip_meses() from public, anon, service_role;
grant  execute on function public.fn_wip_meses() to authenticated;
comment on function public.fn_wip_meses() is 'c12: los meses del libro hasta el mes en curso (los que enseña v_wip_schedule). A quien no es el dueño, nada.';


-- ---------------------------------------------------------------------
-- 5. LO QUE SE LEE: los asientos del propio WIP, las obras y si llevan WIP,
--    el libro por obra a una fecha, el cálculo (una fila por obra), el plan
--    del ajuste y cómo está el ajuste del mes. Todo SECURITY INVOKER y solo
--    lectura: lee con la policy de quien llama, y a quien no es el dueño no
--    le devuelve nada (fn_wip_ve). Las que devuelven una tabla se borran y
--    se rehacen: «create or replace» no cambia las columnas de lo que
--    devuelve (las vistas que las leen se borraron arriba).
-- ---------------------------------------------------------------------
-- LOS ASIENTOS DEL WIP: cada ajuste, su reverso (el automático del día 1 o
-- el de corrección) y la anulación del reverso automático de un ajuste
-- corregido en su mes. Son los que el costo y lo facturado NO cuentan, y los
-- únicos que deben mover 1200, 2400, 2410 y 5950.
drop function if exists public.fn_wip_asientos();
create function public.fn_wip_asientos()
returns table (asiento_id uuid, ajuste_id uuid, papel text)
language sql stable
set search_path = public, pg_temp
as $$
  with w as materialized (select a.asiento_id, a.id as ajuste_id from public.wip_ajustes a),
       r1 as materialized (select x.id as asiento_id, w.ajuste_id from public.asientos x join w on x.reversa_a = w.asiento_id),
       r2 as (select x.id as asiento_id, r1.ajuste_id from public.asientos x join r1 on x.reversa_a = r1.asiento_id)
  select w.asiento_id, w.ajuste_id, 'ajuste'::text from w
  union all
  select r1.asiento_id, r1.ajuste_id, 'reverso' from r1
  union all
  select r2.asiento_id, r2.ajuste_id, 'anulacion' from r2
$$;
revoke execute on function public.fn_wip_asientos() from public, anon, service_role;
grant  execute on function public.fn_wip_asientos() to authenticated;
comment on function public.fn_wip_asientos() is 'c12: los asientos del propio WIP: cada ajuste (wip_ajustes), sus reversos (el automático del día 1 y el de corrección) y la anulación del reverso automático de un ajuste corregido en su mes. El costo y lo facturado de una obra no los cuentan. Solo lectura (con la policy del dueño).';

-- LAS OBRAS Y SI LLEVAN WIP (v_wip_obras las enseña todas). La regla: lleva
-- WIP la obra de PRECIO FIJO, que es la residencial o comercial con
-- contrato en su ficha; la de servicio y la que no tiene contrato, no. La
-- marca de Edgar (wip_obras) manda sobre la regla. Con ella: si está activa
-- o terminada, la cuenta de ingreso que el puente de facturas de c3 usa
-- para su tipo (confirmada), si ya andaba antes del libro (la regla de c10:
-- saldo en la apertura; facturas, tickets, trabajos externos u horas de
-- antes; horas de antes de la app) y lo de antes confirmado, si lo hay.
drop function if exists public.fn_wip_obras(text);
create function public.fn_wip_obras(p_proyecto text default null)
returns table (proyecto_id text, obra text, cliente text, tipo text, obra_estado text, activa boolean, terminada boolean,
               completado_el date, contrato numeric(14,2), marca text, marca_nota text, lleva_wip boolean, motivo text,
               cuenta_ingreso text, de_antes boolean, de_antes_por text,
               antes_id uuid, antes_costo numeric(14,2), antes_facturado numeric(14,2), antes_confirmado_el timestamptz,
               antes_confirmado_por uuid, antes_nota text)
language sql stable
set search_path = public, pg_temp
as $$
  with lb as materialized (select public.fn_wip_libro_desde() as d),
       pre as materialized (
         -- Las obras que ya andaban antes del libro, y qué tenían.
         select y.proyecto_id, string_agg(distinct y.que, ', ' order by y.que) as que
           from (select l.proyecto_id, 'saldo en la apertura' as que
                   from public.asiento_lineas l join public.asientos a on a.id = l.asiento_id
                  where a.tipo = 'apertura' and l.proyecto_id is not null
                 union all
                 select f.proyecto_id, 'facturas' from public.facturas f cross join lb where f.fecha < lb.d
                 union all
                 select r.proyecto_id, 'tickets' from public.recibos r cross join lb where r.fecha < lb.d
                 union all
                 select te.proyecto_id, 'trabajos externos' from public.trabajos_externos te cross join lb where te.fecha < lb.d
                 union all
                 select h.proyecto_id, 'horas' from public.horas h cross join lb where h.fecha < lb.d
                 union all
                 select p.id, 'horas de antes de la app' from public.proyectos p where coalesce(p.horas_reales_base, 0) > 0) y
          where y.proyecto_id is not null and (p_proyecto is null or y.proyecto_id = p_proyecto)
          group by y.proyecto_id)
  select p.id, p.nombre, p.cliente, p.tipo, p.estado,
         coalesce(p.estado in ('aprobado', 'ejecucion', 'pausa'), false), coalesce(p.estado = 'completado', false),
         (case when to_jsonb(p)->>'completado_el' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then left(to_jsonb(p)->>'completado_el', 10)::date end),
         k.contrato::numeric(14,2), o.modo, o.nota,
         (case when o.modo = 'tm' then false when o.modo = 'contrato' then true
               when k.tipo = 'servicio' then false
               else k.contrato is not null end),
         (case when o.modo = 'tm' then 'Marcada como de servicio o por tiempo y material: no lleva WIP; su ingreso es lo facturado.'
               when o.modo = 'contrato' and k.contrato is null
                 then 'Marcada como de precio fijo, pero su ficha no tiene contrato: ponlo para poder revisarla.'
               when o.modo = 'contrato' then 'Marcada como de precio fijo: lleva WIP.'
               when k.tipo = 'servicio' then 'Es de servicio: no lleva WIP; su ingreso es lo facturado.'
               when k.contrato is null then 'No tiene contrato en su ficha: sin precio fijo no hay avance que medir; su ingreso es lo facturado.'
               else 'De precio fijo (residencial o comercial con contrato en su ficha): lleva WIP.' end),
         mt.cuenta, pre.proyecto_id is not null, pre.que,
         an.id, an.costo, an.facturado, an.confirmado_el, an.confirmado_por, an.nota
    from public.proyectos p
    left join public.finanzas_proyecto fp on fp.proyecto_id = p.id
    left join public.wip_obras o on o.proyecto_id = p.id
    cross join lateral (select round(nullif(fp.contrato, 0), 2) as contrato,
                               nullif(lower(btrim(regexp_replace(coalesce(p.tipo, ''), '[[:space:]]+', ' ', 'g'))), '') as tipo) k
    left join public.mapeo_tipo_proyecto mt on mt.tipo = k.tipo and mt.confirmado_el is not null
    left join pre on pre.proyecto_id = p.id
    left join public.wip_antes an on an.proyecto_id = p.id and an.sustituida_el is null
   where (p_proyecto is null or p.id = p_proyecto)
     and (select public.fn_wip_ve())
$$;
revoke execute on function public.fn_wip_obras(text) from public, anon, service_role;
grant  execute on function public.fn_wip_obras(text) to authenticated;
comment on function public.fn_wip_obras(text) is 'c12: cada obra (o una) y si lleva WIP: su tipo, estado (activa: aprobado, ejecución o pausa; terminada: completado), el contrato de su ficha, la marca de Edgar si la tiene, lleva_wip y su porqué en llano (la regla: residencial o comercial con contrato; la marca manda), la cuenta de ingreso de su tipo (la del puente de facturas de c3, confirmada), si ya andaba antes del libro y por qué, y lo de antes confirmado (wip_antes vigente). Solo lectura.';

-- EL LIBRO POR OBRA A UNA FECHA: el costo (cuentas de tipo costo con esa
-- obra, la regla de c10 y de c4), lo facturado (el ingreso de los asientos
-- del puente de facturas y de sus notas de crédito) y el otro ingreso (lo
-- que no es factura: un descuento al cobrar, un asiento a mano), hasta ese
-- día inclusive, SIN los asientos del propio WIP.
drop function if exists public.fn_wip_libro(date, text);
create function public.fn_wip_libro(p_hasta date, p_proyecto text default null)
returns table (proyecto_id text, costo numeric(14,2), facturado numeric(14,2), ingreso_otro numeric(14,2))
language sql stable
set search_path = public, pg_temp
as $$
  with wa as materialized (select w.asiento_id from public.fn_wip_asientos() w)
  select l.proyecto_id,
         coalesce(sum(l.monto) filter (where cu.tipo = 'costo'), 0)::numeric(14,2),
         coalesce(-sum(l.monto) filter (where cu.tipo = 'ingreso' and a.origen_tabla in ('facturas', 'notas_credito')), 0)::numeric(14,2),
         coalesce(-sum(l.monto) filter (where cu.tipo = 'ingreso'
                                          and coalesce(a.origen_tabla, '') not in ('facturas', 'notas_credito')), 0)::numeric(14,2)
    from public.asiento_lineas l
    join public.asientos a on a.id = l.asiento_id
    join public.cuentas cu on cu.codigo = l.cuenta
   where l.proyecto_id is not null and cu.tipo in ('costo', 'ingreso')
     and a.fecha_contable <= p_hasta
     and (p_proyecto is null or l.proyecto_id = p_proyecto)
     and not exists (select 1 from wa where wa.asiento_id = l.asiento_id)
     and (select public.fn_wip_ve())
   group by l.proyecto_id
$$;
revoke execute on function public.fn_wip_libro(date, text) from public, anon, service_role;
grant  execute on function public.fn_wip_libro(date, text) to authenticated;
comment on function public.fn_wip_libro(date, text) is 'c12: por obra y hasta una fecha (inclusive), del libro y sin los asientos del propio WIP: costo (cuentas de tipo costo con esa obra), facturado (el ingreso de los asientos del puente de facturas y de sus notas de crédito) e ingreso_otro (el ingreso con esa obra que no viene de una factura). Todas las obras, o una. Solo lectura.';

-- EL CÁLCULO: una fila por obra que entra en el mes (cabecera, puntos 1, 3,
-- 4 y 5). Las columnas son las de v_wip_schedule:
--   periodo, proyecto_id, obra, cliente, tipo, obra_estado
--   fuente               'calculado' (un mes abierto: lo de hoy) | 'posteado'
--                        (un mes cerrado: la foto de su ajuste)
--   estado               'lista' (entra en el ajuste) | 'pendiente' (le falta
--                        algo: falta y falta_texto) | 'excluida' (Edgar la
--                        dejó fuera este mes, con su nota) | 'sin_movimiento'
--   falta                {revision, antes, cuenta_ingreso, precio, estimado};
--                        falta_texto en llano
--   en_ajuste            estado = 'lista'
--   terminada            se revisó como terminada (100 %)
--   precio_contrato      el de la revisión; precio_ficha, el de la ficha hoy
--   costo_estimado, utilidad_estimada
--   costo_libro, costo_antes, costo_fecha
--   pct_avance (0 a 100), pct_real (sin tope), pasa_de_100
--   ingreso_ganado
--   facturado_libro, facturado_antes, facturado_fecha
--   sub_facturado (1200), sobre_facturado (2400)
--   costo_para_terminar, utilidad_fecha
--   perdida_total, perdida_provision (2410)
--   cuenta_ingreso       el 40xx de la obra; ingreso_otro, lo que no es factura
--   de_antes, antes_confirmado, antes_id
--   revision_id, revisado_el, revisado_por, revision_origen, revision_nota
--   propuesta_costo_estimado, propuesta_origen ('mes_anterior' | 'estimado'),
--   propuesta_nota, propuesta_terminada (la app la tiene como terminada)
--   avisos               text[], en llano
-- Las cifras derivadas salen vacías mientras falte la revisión o lo de antes
-- (no se enseña un avance a medias), y en una obra excluida. p_propuestas =
-- false no pide el estimado a c10 (el plan y el control no lo necesitan).
--
-- QUÉ OBRAS ENTRAN (cabecera, punto 1). Ninguna obra que traía saldo sale
-- sola: la que llevaba sub, sobre o provisión en el último ajuste vivo de un
-- mes anterior ENTRA en este mes, esté como esté en la app (cancelada,
-- terminada, devuelta a «enviado», marcada T&M, sin contrato), hasta que
-- Edgar decida: revisarla (sigue midiéndose) o excluirla con su nota.
drop function if exists public.fn_wip_calcular(text, text, boolean);
create function public.fn_wip_calcular(p_periodo text, p_proyecto text default null, p_propuestas boolean default true)
returns table (periodo text, proyecto_id text, obra text, cliente text, tipo text, obra_estado text, fuente text,
               estado text, falta text[], falta_texto text, en_ajuste boolean, terminada boolean,
               precio_contrato numeric(14,2), precio_ficha numeric(14,2), costo_estimado numeric(14,2),
               utilidad_estimada numeric(14,2), costo_libro numeric(14,2), costo_antes numeric(14,2),
               costo_fecha numeric(14,2), pct_avance numeric(7,2), pct_real numeric, pasa_de_100 boolean,
               ingreso_ganado numeric(14,2), facturado_libro numeric(14,2), facturado_antes numeric(14,2),
               facturado_fecha numeric(14,2), sub_facturado numeric(14,2), sobre_facturado numeric(14,2),
               costo_para_terminar numeric(14,2), utilidad_fecha numeric(14,2), perdida_total numeric(14,2),
               perdida_provision numeric(14,2), cuenta_ingreso text, ingreso_otro numeric(14,2),
               de_antes boolean, antes_confirmado boolean, antes_id uuid,
               revision_id uuid, revisado_el timestamptz, revisado_por uuid, revision_origen text, revision_nota text,
               propuesta_costo_estimado numeric(14,2), propuesta_origen text, propuesta_nota text,
               propuesta_terminada boolean, avisos text[])
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  p      periodos;
  v_nom  text;
  v_c10  jsonb := '{}'::jsonb;
begin
  if not fn_wip_ve() then
    return;
  end if;
  select * into p from periodos q where q.periodo = p_periodo and q.tipo = 'mes';
  if not found then
    return;
  end if;
  v_nom := fn_wip_mes(p.periodo);
  -- LA PROPUESTA DE FÁBRICA: el estimado de la obra (c10), solo si hace falta
  -- (alguna obra que todavía no tiene ninguna revisión que la midiera) y si
  -- c10 está. Se lee al vuelo: c12 no cuelga de c10, y si c10 cambia de forma
  -- no hay propuesta de fábrica y lo demás sigue.
  if p_propuestas and to_regprocedure('public.fn_margen_obras(text)') is not null
     and exists (select 1 from fn_wip_obras(p_proyecto) o
                  where o.lleva_wip and (o.activa or o.terminada)
                    and not exists (select 1 from wip_revisiones r
                                     where r.proyecto_id = o.proyecto_id and r.sustituida_el is null and not r.excluida)) then
    begin
      execute 'select coalesce(jsonb_object_agg(o.proyecto_id, jsonb_build_object(''costo'', o.costo_estimado, '
           || '''completo'', o.estimado_completo, ''falta'', o.estimado_falta)), ''{}''::jsonb) '
           || 'from public.fn_margen_obras($1) o'
         into v_c10 using p_proyecto;
    exception when others then
      v_c10 := '{}'::jsonb;
    end;
  end if;
  return query
  with ult as materialized (
         -- el último ajuste vivo de un mes ANTERIOR (el más reciente)
         select a.id, a.periodo, q.desde
           from wip_ajustes a
           join periodos q on q.periodo = a.periodo
          where a.deshecho_el is null and q.desde < p.desde
          order by q.desde desc
          limit 1),
       arr as materialized (
         -- LO QUE VIENE CON SALDO: las obras que ese ajuste dejó con sub,
         -- sobre o provisión (se deshizo solo el día 1: si este mes no entran,
         -- ese saldo no vuelve y nadie lo decidió)
         select w.proyecto_id, ult.periodo, ult.desde, w.sub_facturado, w.sobre_facturado, w.perdida_provision
           from ult
           join wip_ajuste_obras w on w.ajuste_id = ult.id
          where w.en_ajuste and (w.sub_facturado <> 0 or w.sobre_facturado <> 0 or w.perdida_provision <> 0)
            and (p_proyecto is null or w.proyecto_id = p_proyecto)),
       ob as materialized (
         select o.* from fn_wip_obras(p_proyecto) o),
       rv as materialized (
         select r.* from wip_revisiones r
          where r.periodo = p.periodo and r.sustituida_el is null and (p_proyecto is null or r.proyecto_id = p_proyecto)),
       antx as materialized (
         -- la última revisión viva de un mes anterior, por obra (la que sea:
         -- dice si la obra salió a propósito o si ya se cerró como terminada)
         select distinct on (r.proyecto_id) r.proyecto_id, r.periodo, q.desde, r.excluida, r.terminada, r.precio_contrato
           from wip_revisiones r
           join periodos q on q.periodo = r.periodo
          where r.sustituida_el is null and q.desde < p.desde and (p_proyecto is null or r.proyecto_id = p_proyecto)
          order by r.proyecto_id, q.desde desc),
       ant as materialized (
         -- la última revisión viva de un mes anterior que MIDIÓ la obra (no
         -- una exclusión): de ahí sale la propuesta de un toque
         select distinct on (r.proyecto_id) r.proyecto_id, r.periodo, r.costo_estimado, r.terminada
           from wip_revisiones r
           join periodos q on q.periodo = r.periodo
          where r.sustituida_el is null and not r.excluida and q.desde < p.desde
            and (p_proyecto is null or r.proyecto_id = p_proyecto)
          order by r.proyecto_id, q.desde desc),
       lb as materialized (select * from fn_wip_libro(p.hasta, p_proyecto)),
       b as (
         -- QUÉ OBRAS ENTRAN. De las que llevan WIP: las activas; las que tienen
         -- revisión en el mes; las terminadas que venían en el WIP y siguen sin
         -- cerrar (su última revisión anterior no es «terminada» ni una
         -- exclusión); y las terminadas con fecha de término en el mes, si la
         -- app la guarda. Y, lleven WIP hoy o no: las que tienen una revisión
         -- en el mes; LAS QUE TRAÍAN SALDO del último ajuste (si su última
         -- decisión no fue excluirlas); y LAS TERMINADAS QUE SIGUEN SIN
         -- FACTURARSE ENTERAS (su última revisión fue «terminada» y lo
         -- facturado a la fecha no es su precio), se haya posteado o no su mes.
         select ob.proyecto_id, ob.obra, ob.cliente, ob.tipo, ob.obra_estado, ob.terminada as obra_terminada, ob.activa,
                ob.lleva_wip, ob.motivo, ob.contrato, ob.cuenta_ingreso, ob.de_antes, ob.de_antes_por, ob.antes_id, ob.antes_costo,
                ob.antes_facturado,
                rv.id as rev_id, rv.precio_contrato as rev_precio, rv.precio_ficha as rev_ficha, rv.costo_estimado as rev_costo,
                coalesce(rv.terminada, false) as rev_terminada, coalesce(rv.excluida, false) as rev_excluida,
                rv.origen as rev_origen, rv.nota as rev_nota,
                rv.revisado_el as rev_el, rv.revisado_por as rev_por, rv.propuesta as rev_propuesta,
                rv.propuesta_origen as rev_propuesta_origen,
                ant.periodo as ant_periodo, ant.costo_estimado as ant_costo, coalesce(ant.terminada, false) as ant_terminada,
                coalesce(lb.costo, 0) as c_libro, coalesce(lb.facturado, 0) as f_libro, coalesce(lb.ingreso_otro, 0) as i_otro,
                (arr.proyecto_id is not null and not coalesce(antx.excluida and antx.desde >= arr.desde, false)) as arrastra,
                (coalesce(antx.terminada and not antx.excluida, false)
                 and coalesce(lb.facturado, 0) + coalesce(ob.antes_facturado, 0) is distinct from antx.precio_contrato) as sigue_terminada,
                antx.periodo as antx_periodo, antx.precio_contrato as antx_precio,
                arr.periodo as arr_periodo,
                concat_ws(' y ', case when arr.sub_facturado <> 0 then fn_wip_usd(arr.sub_facturado) || ' sub-facturados' end,
                                 case when arr.sobre_facturado <> 0 then fn_wip_usd(arr.sobre_facturado) || ' sobre-facturados' end,
                                 case when arr.perdida_provision <> 0 then fn_wip_usd(arr.perdida_provision) || ' de pérdida provisionada' end)
                  as arr_txt
           from ob
           left join rv on rv.proyecto_id = ob.proyecto_id
           left join ant on ant.proyecto_id = ob.proyecto_id
           left join antx on antx.proyecto_id = ob.proyecto_id
           left join arr on arr.proyecto_id = ob.proyecto_id
           left join lb on lb.proyecto_id = ob.proyecto_id
          where (ob.lleva_wip
                 and (ob.activa
                      or (ob.terminada and antx.proyecto_id is not null and not antx.terminada and not antx.excluida)
                      or (ob.terminada and ob.completado_el between p.desde and p.hasta)))
             or rv.id is not null
             or (arr.proyecto_id is not null and not coalesce(antx.excluida and antx.desde >= arr.desde, false))
             or (coalesce(antx.terminada and not antx.excluida, false)
                 and coalesce(lb.facturado, 0) + coalesce(ob.antes_facturado, 0) is distinct from antx.precio_contrato)),
       c as (
         select b.*,
                -- se mide: lleva WIP, tiene su revisión (que no es una exclusión) y lo de antes confirmado si ya andaba
                (b.lleva_wip and b.rev_id is not null and not b.rev_excluida and not (b.de_antes and b.antes_id is null)) as calc,
                (b.c_libro <> 0 or b.f_libro <> 0 or b.i_otro <> 0 or b.de_antes or b.antes_id is not null
                 or b.rev_id is not null or b.arrastra or b.sigue_terminada) as mov
           from b),
       d as (
         select c.*,
                case when c.calc then c.c_libro + coalesce(c.antes_costo, 0) end as c_fecha,
                case when c.calc then c.f_libro + coalesce(c.antes_facturado, 0) end as f_fecha
           from c),
       e as (
         -- el costo estimado: el revisado; terminada, el que lleva
         select d.*, case when not d.calc then null when d.rev_terminada then d.c_fecha else d.rev_costo end as est
           from d),
       f as (
         -- el costo topado: entre 0 y el estimado (terminada: el que lleva)
         select e.*, case when not e.calc then null when e.rev_terminada then e.c_fecha
                          else greatest(least(e.c_fecha, e.est), 0) end as c_tope
           from e),
       g as (
         -- EL INGRESO GANADO: precio × costo topado ÷ costo estimado, de una
         -- vez y redondeado una vez (terminada: el precio)
         select f.*, case when not f.calc then null when f.rev_terminada then f.rev_precio
                          else round(f.rev_precio * f.c_tope / f.est, 2) end as ganado
           from f),
       h as (
         select g.*,
                case when not g.calc or g.rev_terminada then null else greatest(g.est - g.rev_precio, 0) end as perdida,
                -- LO QUE LE FALTA para entrar en el ajuste (una excluida no pide nada: ya se decidió)
                array_remove(array[
                  case when g.rev_id is null or (not g.lleva_wip and not g.rev_excluida) then 'revision' end,
                  case when g.lleva_wip and not g.rev_excluida and g.de_antes and g.antes_id is null then 'antes' end,
                  case when g.lleva_wip and not g.rev_excluida and g.cuenta_ingreso is null then 'cuenta_ingreso' end,
                  -- el contrato de la ficha cambió DESPUÉS de revisarla (no es el que se usó ni el que la ficha decía entonces)
                  case when g.lleva_wip and g.rev_id is not null and not g.rev_excluida
                            and g.contrato is distinct from g.rev_precio and g.contrato is distinct from g.rev_ficha then 'precio' end,
                  -- lleva más costo que su estimado sin estar terminada: el estimado quedó viejo
                  case when g.calc and not g.rev_terminada and g.c_fecha > g.est then 'estimado' end], null) as falta,
                case when not g.lleva_wip then null
                     when g.rev_id is not null then g.rev_propuesta
                     when g.ant_periodo is not null and not g.ant_terminada then g.ant_costo
                     when coalesce((v_c10->g.proyecto_id->>'completo')::boolean, false)
                          and (v_c10->g.proyecto_id->>'costo')::numeric > 0 then round((v_c10->g.proyecto_id->>'costo')::numeric, 2)
                end as prop,
                case when not g.lleva_wip then null
                     when g.rev_id is not null then g.rev_propuesta_origen
                     when g.ant_periodo is not null and not g.ant_terminada then 'mes_anterior'
                     when coalesce((v_c10->g.proyecto_id->>'completo')::boolean, false)
                          and (v_c10->g.proyecto_id->>'costo')::numeric > 0 then 'estimado' end as prop_origen,
                -- de dónde viene con saldo, en llano (vacío si no trae)
                case when g.arrastra then format('Traía %s en el ajuste de %s', g.arr_txt, fn_wip_mes(g.arr_periodo)) end as arr_frase
           from g)
  select p.periodo, h.proyecto_id, h.obra, h.cliente, h.tipo, h.obra_estado, 'calculado'::text,
         (case when not h.mov then 'sin_movimiento' when h.rev_excluida then 'excluida'
               when cardinality(h.falta) > 0 then 'pendiente' else 'lista' end),
         (case when not h.mov or h.rev_excluida then '{}'::text[] else h.falta end),
         (case when not h.mov then 'Sin costo ni facturas todavía: no hay nada que medir.'
               when h.rev_excluida or cardinality(h.falta) = 0 then null
               else concat_ws(' ',
                      case when not h.lleva_wip
                             then format('%s y hoy ya no lleva WIP (%s) Nada sale del WIP solo: exclúyela este mes con su nota (su ingreso vuelve a '
                                         'ser lo facturado), o, si sigue siendo de precio fijo, arregla su ficha o su marca y revísala.',
                                         coalesce(h.arr_frase, format('Se revisó en %s', v_nom)), h.motivo)
                           when h.rev_id is null and h.contrato is null
                             then concat_ws(' ', h.arr_frase || '.', 'Su ficha no tiene contrato: ponlo (o dilo al revisar) para poder revisarla.')
                           when h.rev_id is null and h.sigue_terminada
                             then format('Ya estaba terminada (se revisó así en %s) y sigue sin facturarse entera: lleva facturado %s de %s. '
                                         'Se queda en el WIP hasta que lo facturado sea su precio: revísala como terminada otra vez (un '
                                         'toque)%s, o exclúyela con su nota.', fn_wip_mes(h.antx_periodo),
                                         fn_wip_usd(h.f_libro + coalesce(h.antes_facturado, 0)), fn_wip_usd(h.antx_precio),
                                         case when h.obra_terminada then '' else '; si volvió a abrirse, revisa su costo estimado' end)
                           when h.rev_id is null and h.arrastra and not h.activa and not h.obra_terminada
                             then format('%s y la app la tiene ahora como «%s». Nada sale del WIP solo: si sigue en pie, revisa su costo '
                                         'estimado; si se canceló, exclúyela con su nota (su ingreso vuelve a ser lo facturado).',
                                         h.arr_frase, coalesce(h.obra_estado, 'sin estado'))
                           when h.rev_id is null then format('Falta revisar su costo estimado en %s.', v_nom) end,
                      case when h.falta @> array['antes']
                             then format('Ya andaba antes del libro (tiene de antes: %s): falta confirmar su costo y lo facturado de antes; '
                                         'hasta entonces no entra en el ajuste. Si este mes no se puede, exclúyela con su nota.', h.de_antes_por) end,
                      case when h.falta @> array['cuenta_ingreso']
                             then format('Su tipo de obra (%s) no tiene cuenta de ingreso confirmada: sin ella no se sabe contra qué '
                                         'renglón va el ajuste.', coalesce(h.tipo, 'sin tipo')) end,
                      case when h.falta @> array['precio']
                             then format('El contrato de su ficha cambió después de revisarla (se revisó con %s y la ficha dice ahora %s): si el '
                                         'cambio es de %s, revísala otra vez con el precio nuevo; si es de después, dilo (un toque) y este '
                                         'mes se queda con el que tenía.', fn_wip_usd(h.rev_precio),
                                         case when h.contrato is null then 'nada' else fn_wip_usd(h.contrato) end, v_nom) end,
                      case when h.falta @> array['estimado']
                             then format('Lleva %s de costo y su costo estimado revisado es %s (%s %%): ese estimado quedó viejo. Súbelo (el '
                                         'costo total no puede ser menos de lo que ya lleva) o, si terminó, márcala terminada; hasta '
                                         'entonces no entra en el ajuste.', fn_wip_usd(h.c_fecha), fn_wip_usd(h.est),
                                         trim_scale(round(100 * h.c_fecha / h.est, 2))) end) end),
         (h.mov and not h.rev_excluida and cardinality(h.falta) = 0), h.rev_terminada,
         h.rev_precio::numeric(14,2), h.contrato::numeric(14,2), h.est::numeric(14,2),
         (h.rev_precio - h.est)::numeric(14,2),
         h.c_libro::numeric(14,2),
         (case when h.calc then coalesce(h.antes_costo, 0) else h.antes_costo end)::numeric(14,2),
         h.c_fecha::numeric(14,2),
         (case when not h.calc then null when h.rev_terminada then 100 else round(100 * h.c_tope / h.est, 2) end)::numeric(7,2),
         (case when not h.calc then null when h.rev_terminada then 100 else round(100 * h.c_fecha / h.est, 2) end),
         (h.calc and not h.rev_terminada and h.c_fecha > h.est),
         h.ganado::numeric(14,2),
         h.f_libro::numeric(14,2),
         (case when h.calc then coalesce(h.antes_facturado, 0) else h.antes_facturado end)::numeric(14,2),
         h.f_fecha::numeric(14,2),
         (case when h.calc then greatest(h.ganado - h.f_fecha, 0) end)::numeric(14,2),
         (case when h.calc then greatest(h.f_fecha - h.ganado, 0) end)::numeric(14,2),
         (case when h.calc then greatest(h.est - h.c_fecha, 0) end)::numeric(14,2),
         (h.ganado - h.c_fecha)::numeric(14,2),
         (case when not h.calc then null when h.rev_terminada then greatest(h.c_fecha - h.rev_precio, 0) else h.perdida end)::numeric(14,2),
         -- LA PROVISIÓN: lo que falta por reconocer de la pérdida (cabecera, 5)
         (case when not h.calc then null
               when h.rev_terminada or h.perdida = 0 then 0
               else greatest(h.perdida - (h.c_tope - h.ganado), 0) end)::numeric(14,2),
         h.cuenta_ingreso, h.i_otro::numeric(14,2),
         h.de_antes, h.antes_id is not null, h.antes_id,
         h.rev_id, h.rev_el, h.rev_por, h.rev_origen, h.rev_nota,
         h.prop::numeric(14,2), h.prop_origen,
         (case when h.rev_id is not null or not h.lleva_wip then null
               when h.obra_terminada and h.sigue_terminada
                 then format('Ya estaba terminada en %s: sigue terminada (100 %%) hasta que se facture entera.', fn_wip_mes(h.antx_periodo))
               when h.obra_terminada
                 then 'La app la tiene como terminada: si terminó en este mes, revísala como terminada (100 %); si seguía en obra '
                      'al cierre del mes, revisa su costo estimado.'
               when h.prop_origen = 'mes_anterior' then format('Lo que revisaste en %s.', fn_wip_mes(h.ant_periodo))
               when h.prop_origen = 'estimado'
                 then 'Lo que dice el estimado de la obra: sus horas estimadas por su tarifa, más el presupuesto de material.'
               else coalesce('Sin propuesta. ' || nullif(v_c10->h.proyecto_id->>'falta', ''),
                             'Sin propuesta: no hay una revisión anterior ni un estimado completo de la obra. Escribe el costo '
                             'total estimado, desde el inicio hasta terminarla.') end),
         (h.rev_id is null and h.lleva_wip and h.obra_terminada),
         (case when not h.calc then '{}'::text[] else array_remove(array[
            case when not h.rev_terminada and h.c_fecha > h.est
                 then format('Lleva %s de costo y su costo estimado revisado es %s (%s %%): no entra en el ajuste hasta que subas el costo '
                             'estimado (o la marques terminada).', fn_wip_usd(h.c_fecha), fn_wip_usd(h.est),
                             trim_scale(round(100 * h.c_fecha / h.est, 2))) end,
            case when not h.rev_terminada and h.c_fecha = h.est
                 then format('Va al 100 %%: lleva justo su costo estimado (%s) y con eso se gana el precio entero. Si todavía le falta '
                             'trabajo, su costo total estimado tiene que ser mayor.', fn_wip_usd(h.est)) end,
            case when not h.rev_terminada and h.perdida > 0
                 then format('Va con pérdida: el costo estimado (%s) pasa del precio (%s) por %s. De esa pérdida, %s ya está en su '
                             'resultado por el avance y %s se provisiona este mes: la pérdida completa queda reconocida.',
                             fn_wip_usd(h.est), fn_wip_usd(h.rev_precio), fn_wip_usd(h.perdida),
                             fn_wip_usd(least(h.c_tope - h.ganado, h.perdida)),
                             fn_wip_usd(greatest(h.perdida - (h.c_tope - h.ganado), 0))) end,
            case when h.rev_terminada and h.c_fecha > h.rev_precio
                 then format('Terminó con pérdida: costó %s y su precio es %s.', fn_wip_usd(h.c_fecha), fn_wip_usd(h.rev_precio)) end,
            case when h.rev_terminada and h.f_fecha <> h.rev_precio
                 then format('Terminada y sin facturar entera: lleva facturado %s de %s. Sigue en el WIP cada mes hasta que lo facturado sea '
                             'su precio.', fn_wip_usd(h.f_fecha), fn_wip_usd(h.rev_precio)) end,
            case when h.f_fecha > h.rev_precio
                 then format('Lo facturado (%s) pasa del contrato (%s): ¿falta una orden de cambio en el contrato de la ficha?',
                             fn_wip_usd(h.f_fecha), fn_wip_usd(h.rev_precio)) end,
            case when h.contrato is distinct from h.rev_precio
                 then format('El contrato de la ficha (%s) no es el que se usó al revisar (%s).',
                             case when h.contrato is null then 'vacío' else fn_wip_usd(h.contrato) end, fn_wip_usd(h.rev_precio)) end,
            case when h.i_otro <> 0
                 then format('Tiene %s de ingreso en el libro que no viene de una factura ni del WIP (un descuento al cobrar o un '
                             'asiento a mano): no cuenta como facturado.', fn_wip_usd(h.i_otro)) end
          ], null) end)
    from h
   order by h.obra, h.proyecto_id;
end $$;
revoke execute on function public.fn_wip_calcular(text, text, boolean) from public, anon, service_role;
grant  execute on function public.fn_wip_calcular(text, text, boolean) to authenticated;
comment on function public.fn_wip_calcular(text, text, boolean) is 'c12: el WIP de un mes, calculado hoy a la fecha de su último día: una fila por obra que entra (las de precio fijo activas; las que tienen revisión en el mes; las terminadas que venían en el WIP o con fecha de término en el mes; y TODA obra que traía sub, sobre o provisión en el último ajuste vivo de un mes anterior, esté como esté hoy en la app: ninguna sale sola), con su estado (lista; pendiente con lo que falta: revision, antes, cuenta_ingreso, precio = el contrato de la ficha cambió después de revisarla, estimado = lleva más costo que su estimado; excluida = Edgar la dejó fuera este mes con su nota; sin_movimiento), el precio y el costo estimado de su revisión, el costo y lo facturado a la fecha (libro + lo de antes confirmado), el % de avance (topado en 100), el ingreso ganado (precio × costo ÷ costo estimado, redondeado una vez), sub y sobre-facturado, costo para terminar, utilidad, la pérdida y su provisión (lo que falta por reconocer), la cuenta de ingreso, la propuesta del costo estimado (lo del mes anterior o el estimado de la obra) y los avisos en llano. Solo lectura; a quien no es el dueño, nada.';

-- EL SCHEDULE DE UN MES (lo que enseña v_wip_schedule): un mes abierto, lo
-- calculado hoy; un mes CERRADO, la foto de su ajuste (lo que se posteó: un
-- mes cerrado no cambia). Sin período, el mes que toca.
drop function if exists public.fn_wip_schedule(text);
create function public.fn_wip_schedule(p_periodo text default null)
returns table (periodo text, proyecto_id text, obra text, cliente text, tipo text, obra_estado text, fuente text,
               estado text, falta text[], falta_texto text, en_ajuste boolean, terminada boolean,
               precio_contrato numeric(14,2), precio_ficha numeric(14,2), costo_estimado numeric(14,2),
               utilidad_estimada numeric(14,2), costo_libro numeric(14,2), costo_antes numeric(14,2),
               costo_fecha numeric(14,2), pct_avance numeric(7,2), pct_real numeric, pasa_de_100 boolean,
               ingreso_ganado numeric(14,2), facturado_libro numeric(14,2), facturado_antes numeric(14,2),
               facturado_fecha numeric(14,2), sub_facturado numeric(14,2), sobre_facturado numeric(14,2),
               costo_para_terminar numeric(14,2), utilidad_fecha numeric(14,2), perdida_total numeric(14,2),
               perdida_provision numeric(14,2), cuenta_ingreso text, ingreso_otro numeric(14,2),
               de_antes boolean, antes_confirmado boolean, antes_id uuid,
               revision_id uuid, revisado_el timestamptz, revisado_por uuid, revision_origen text, revision_nota text,
               propuesta_costo_estimado numeric(14,2), propuesta_origen text, propuesta_nota text,
               propuesta_terminada boolean, avisos text[])
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  p     periodos;
  v_per text;
begin
  if not fn_wip_ve() then
    return;
  end if;
  v_per := coalesce(p_periodo, fn_wip_toca());
  select * into p from periodos q where q.periodo = v_per and q.tipo = 'mes';
  if not found then
    return;
  end if;
  if p.estado = 'cerrado' then
    return query
    select p.periodo, s.proyecto_id, s.obra, s.cliente, s.tipo, s.obra_estado, 'posteado'::text,
           s.estado, s.falta, s.falta_texto, s.en_ajuste, s.terminada,
           s.precio_contrato, null::numeric(14,2), s.costo_estimado, s.utilidad_estimada, s.costo_libro, s.costo_antes,
           s.costo_fecha, s.pct_avance, s.pct_real, s.pasa_de_100, s.ingreso_ganado, s.facturado_libro, s.facturado_antes,
           s.facturado_fecha, s.sub_facturado, s.sobre_facturado, s.costo_para_terminar, s.utilidad_fecha, s.perdida_total,
           s.perdida_provision, s.cuenta_ingreso, s.ingreso_otro, s.de_antes, s.antes_id is not null, s.antes_id,
           s.revision_id, r.revisado_el, r.revisado_por, r.origen, r.nota,
           null::numeric(14,2), null::text, null::text, false, s.avisos
      from wip_ajustes a
      join wip_ajuste_obras s on s.ajuste_id = a.id
      left join wip_revisiones r on r.id = s.revision_id
     where a.periodo = p.periodo and a.deshecho_el is null
     order by s.n;
  else
    return query select * from fn_wip_calcular(p.periodo, null, true);
  end if;
end $$;
revoke execute on function public.fn_wip_schedule(text) from public, anon, service_role;
grant  execute on function public.fn_wip_schedule(text) to authenticated;
comment on function public.fn_wip_schedule(text) is 'c12: el WIP de un mes, el formato que pide la afianzadora (las columnas de fn_wip_calcular): un mes abierto, lo calculado hoy (fuente calculado); un mes cerrado, la foto de su ajuste tal como se posteó (fuente posteado; sin ajuste, ninguna fila). Sin período, el mes que toca. Solo lectura; a quien no es el dueño, nada.';

-- EL PLAN DEL AJUSTE: lo que el WIP de hoy postearía en ese mes. Las filas
-- del cálculo, las líneas del asiento (de las obras listas, en orden de
-- obra: la de 1200 o 2400 con la de su ingreso, y la de 5950 con la de
-- 2410), su huella y los totales. No escribe nada.
create or replace function public.fn_wip_plan(p_periodo text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_filas   jsonb;
  v_lineas  jsonb;
  v_huella  text;
  v_tot     jsonb;
  v_nom     text := fn_wip_mes(p_periodo);
begin
  if not fn_wip_ve() then
    return null;
  end if;
  select coalesce(jsonb_agg(to_jsonb(s) order by s.obra, s.proyecto_id), '[]'::jsonb) into v_filas
    from fn_wip_calcular(p_periodo, null, false) s;
  select coalesce(jsonb_agg(z.linea order by z.obra, z.proyecto_id, z.k), '[]'::jsonb) into v_lineas
    from (select x.obra, x.proyecto_id, y.k,
                 jsonb_build_object('cuenta', y.cuenta, 'monto', y.monto::numeric(14,2)::text, 'proyecto_id', x.proyecto_id,
                                    'memo', left(y.memo, 200)) as linea
            from jsonb_to_recordset(v_filas)
                 as x(proyecto_id text, obra text, en_ajuste boolean, terminada boolean, precio_contrato numeric,
                      costo_estimado numeric, pct_avance numeric, ingreso_ganado numeric, facturado_fecha numeric,
                      sub_facturado numeric, sobre_facturado numeric, perdida_total numeric, perdida_provision numeric,
                      cuenta_ingreso text)
            cross join lateral (values
              (1, '1200', x.sub_facturado,
                  format('WIP de %s: sub-facturado · ganado %s (%s %%) − facturado %s', v_nom, fn_wip_usd(x.ingreso_ganado),
                         trim_scale(x.pct_avance), fn_wip_usd(x.facturado_fecha))),
              (2, x.cuenta_ingreso, -x.sub_facturado,
                  format('WIP de %s: ingreso ganado y todavía no facturado', v_nom)),
              (3, x.cuenta_ingreso, x.sobre_facturado,
                  format('WIP de %s: facturado por encima de lo ganado', v_nom)),
              (4, '2400', -x.sobre_facturado,
                  format('WIP de %s: sobre-facturado · facturado %s − ganado %s (%s %%)', v_nom, fn_wip_usd(x.facturado_fecha),
                         fn_wip_usd(x.ingreso_ganado), trim_scale(x.pct_avance))),
              (5, '5950', x.perdida_provision,
                  format('WIP de %s: pérdida de la obra %s (costo estimado %s − precio %s); falta por reconocer %s', v_nom,
                         fn_wip_usd(x.perdida_total), fn_wip_usd(x.costo_estimado), fn_wip_usd(x.precio_contrato),
                         fn_wip_usd(x.perdida_provision))),
              (6, '2410', -x.perdida_provision,
                  format('WIP de %s: provisión por la pérdida que falta por reconocer', v_nom))
              ) y(k, cuenta, monto, memo)
           where x.en_ajuste and coalesce(y.monto, 0) <> 0) z;
  select md5(coalesce(string_agg(concat_ws('|', x.proyecto_id, x.precio_contrato::numeric(14,2), x.costo_estimado::numeric(14,2),
                                           x.terminada, x.costo_fecha::numeric(14,2), x.facturado_fecha::numeric(14,2),
                                           x.ingreso_ganado::numeric(14,2), x.sub_facturado::numeric(14,2),
                                           x.sobre_facturado::numeric(14,2), x.perdida_provision::numeric(14,2), x.cuenta_ingreso),
                                 E'\n' order by x.proyecto_id), '')),
         jsonb_build_object(
           'obras', count(*),
           'precio_contrato', coalesce(sum(x.precio_contrato), 0)::numeric(14,2),
           'costo_estimado', coalesce(sum(x.costo_estimado), 0)::numeric(14,2),
           'utilidad_estimada', coalesce(sum(x.utilidad_estimada), 0)::numeric(14,2),
           'costo_fecha', coalesce(sum(x.costo_fecha), 0)::numeric(14,2),
           'ingreso_ganado', coalesce(sum(x.ingreso_ganado), 0)::numeric(14,2),
           'facturado_fecha', coalesce(sum(x.facturado_fecha), 0)::numeric(14,2),
           'sub_facturado', coalesce(sum(x.sub_facturado), 0)::numeric(14,2),
           'sobre_facturado', coalesce(sum(x.sobre_facturado), 0)::numeric(14,2),
           'costo_para_terminar', coalesce(sum(x.costo_para_terminar), 0)::numeric(14,2),
           'utilidad_fecha', coalesce(sum(x.utilidad_fecha), 0)::numeric(14,2),
           'perdida_total', coalesce(sum(x.perdida_total), 0)::numeric(14,2),
           'perdida_provision', coalesce(sum(x.perdida_provision), 0)::numeric(14,2),
           'obras_sub', count(*) filter (where x.sub_facturado > 0),
           'obras_sobre', count(*) filter (where x.sobre_facturado > 0),
           'obras_perdida', count(*) filter (where x.perdida_provision > 0))
    into v_huella, v_tot
    from jsonb_to_recordset(v_filas)
         as x(proyecto_id text, en_ajuste boolean, terminada boolean, precio_contrato numeric, costo_estimado numeric,
              utilidad_estimada numeric, costo_fecha numeric, ingreso_ganado numeric, facturado_fecha numeric,
              sub_facturado numeric, sobre_facturado numeric, costo_para_terminar numeric, utilidad_fecha numeric,
              perdida_total numeric, perdida_provision numeric, cuenta_ingreso text)
   where x.en_ajuste;
  return jsonb_build_object('periodo', p_periodo, 'filas', v_filas, 'lineas', v_lineas, 'huella', v_huella, 'totales', v_tot);
end $$;
revoke execute on function public.fn_wip_plan(text) from public, anon, service_role;
grant  execute on function public.fn_wip_plan(text) to authenticated;
comment on function public.fn_wip_plan(text) is 'c12: lo que el WIP de hoy postearía en un mes: las filas del cálculo (filas), las líneas del asiento de las obras listas en orden de obra (lineas: cuenta, monto con signo, obra y memo; sub-facturado Dr 1200 / Cr su ingreso, sobre-facturado Dr su ingreso / Cr 2400, pérdida Dr 5950 / Cr 2410), la huella de lo calculado y los totales de las obras listas. Solo lectura.';

-- CÓMO ESTÁ EL AJUSTE DE UN MES contra el WIP de hoy: si hay uno vivo, si
-- su asiento sigue vivo en el libro (o se reversó por fuera de aquí), si
-- está al día (su huella es la de hoy) y, si no, qué cambió, obra por obra.
create or replace function public.fn_wip_ajuste_estado(p_periodo text, p_plan jsonb default null) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_plan    jsonb := coalesce(p_plan, fn_wip_plan(p_periodo));
  a         wip_ajustes;
  v_rev     asientos;
  v_auto    asientos;
  v_cambios text;
  v_nlin    int := jsonb_array_length(coalesce(v_plan->'lineas', '[]'::jsonb));
begin
  if not fn_wip_ve() then
    return null;
  end if;
  select * into a from wip_ajustes x where x.periodo = p_periodo and x.deshecho_el is null;
  if not found then
    return jsonb_build_object('vivo', false, 'al_dia', v_nlin = 0, 'lineas_hoy', v_nlin, 'por_fuera', false);
  end if;
  select * into v_rev from asientos r where r.reversa_a = a.asiento_id and r.camino = 'reverso' order by r.cadena_pos limit 1;
  select * into v_auto from asientos r where r.reversa_a = a.asiento_id and r.camino = 'reverso_automatico' limit 1;
  if v_rev.id is null and a.huella is distinct from (v_plan->>'huella') then
    select left(string_agg(t.txt, '; ' order by t.obra), 900) into v_cambios
      from (select coalesce(n.obra, o.obra) as obra,
                   case when o.proyecto_id is null then format('entra %s (%s)', n.obra, n.pos)
                        when n.proyecto_id is null then format('sale %s (estaba %s)', o.obra, o.pos)
                        when o.pos <> n.pos then format('%s pasa de %s a %s', n.obra, o.pos, n.pos)
                        else format('%s cambia su cálculo (%s)', n.obra, n.pos) end as txt
              from (select s.proyecto_id, s.obra, s.firma,
                           concat_ws(' y ', case when s.sub_facturado > 0 then 'sub-facturado ' || fn_wip_usd(s.sub_facturado)
                                                 when s.sobre_facturado > 0 then 'sobre-facturado ' || fn_wip_usd(s.sobre_facturado)
                                                 else 'sin diferencia' end,
                                     case when s.perdida_provision > 0 then 'pérdida ' || fn_wip_usd(s.perdida_provision) end) as pos
                      from (select w.proyecto_id, w.obra, w.sub_facturado, w.sobre_facturado, w.perdida_provision,
                                   concat_ws('|', w.precio_contrato, w.costo_estimado, w.terminada, w.costo_fecha, w.facturado_fecha,
                                             w.ingreso_ganado, w.sub_facturado, w.sobre_facturado, w.perdida_provision,
                                             w.cuenta_ingreso) as firma
                              from wip_ajuste_obras w where w.ajuste_id = a.id and w.en_ajuste) s) o
              full join
                   (select s.proyecto_id, s.obra, s.firma,
                           concat_ws(' y ', case when s.sub_facturado > 0 then 'sub-facturado ' || fn_wip_usd(s.sub_facturado)
                                                 when s.sobre_facturado > 0 then 'sobre-facturado ' || fn_wip_usd(s.sobre_facturado)
                                                 else 'sin diferencia' end,
                                     case when s.perdida_provision > 0 then 'pérdida ' || fn_wip_usd(s.perdida_provision) end) as pos
                      from (select x.proyecto_id, x.obra, x.sub_facturado, x.sobre_facturado, x.perdida_provision,
                                   concat_ws('|', x.precio_contrato::numeric(14,2), x.costo_estimado::numeric(14,2), x.terminada,
                                             x.costo_fecha::numeric(14,2), x.facturado_fecha::numeric(14,2),
                                             x.ingreso_ganado::numeric(14,2), x.sub_facturado::numeric(14,2),
                                             x.sobre_facturado::numeric(14,2), x.perdida_provision::numeric(14,2),
                                             x.cuenta_ingreso) as firma
                              from jsonb_to_recordset(v_plan->'filas')
                                   as x(proyecto_id text, obra text, en_ajuste boolean, terminada boolean, precio_contrato numeric,
                                        costo_estimado numeric, costo_fecha numeric, ingreso_ganado numeric, facturado_fecha numeric,
                                        sub_facturado numeric, sobre_facturado numeric, perdida_provision numeric, cuenta_ingreso text)
                             where x.en_ajuste) s) n
                on n.proyecto_id = o.proyecto_id
             where o.proyecto_id is null or n.proyecto_id is null or o.firma is distinct from n.firma) t;
  end if;
  return jsonb_build_object(
    'vivo', true, 'id', a.id, 'asiento_id', a.asiento_id, 'numero', a.numero, 'fecha', a.fecha,
    'reverso_auto', case when v_auto.id is not null
                         then jsonb_build_object('id', v_auto.id, 'numero', v_auto.numero, 'fecha', v_auto.fecha_contable) end,
    'obras', a.obras, 'sub_facturado', a.sub_facturado, 'sobre_facturado', a.sobre_facturado, 'perdida', a.perdida,
    'creado_el', a.creado_el, 'creado_por', a.creado_por,
    'por_fuera', v_rev.id is not null,
    'reverso', case when v_rev.id is not null
                    then jsonb_build_object('id', v_rev.id, 'numero', v_rev.numero, 'fecha', v_rev.fecha_contable, 'motivo', v_rev.motivo) end,
    'al_dia', v_rev.id is null and a.huella is not distinct from (v_plan->>'huella'),
    'cambios', v_cambios,
    'lineas_hoy', v_nlin);
end $$;
revoke execute on function public.fn_wip_ajuste_estado(text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_wip_ajuste_estado(text, jsonb) to authenticated;
comment on function public.fn_wip_ajuste_estado(text, jsonb) is 'c12: cómo está el ajuste de WIP de un mes contra lo que el WIP da hoy: vivo (hay uno sin deshacer), su asiento y su reverso del día 1, por_fuera (su asiento se reversó en el libro sin pasar por aquí), al_dia (su huella es la de hoy; sin ajuste, que hoy no haya nada que postear) y cambios (qué obra entra, sale o cambia, en llano). Solo lectura.';

-- LO DE ANTES DEL LIBRO, PROPUESTO desde los papeles de la app (cabecera,
-- punto 2): el costo (tickets no anulados, trabajos externos, y las horas de
-- la cuadrilla × su tarifa de HOY: costos_equipo no guarda historia) y lo
-- facturado (facturas no anuladas de antes del libro, y las que la apertura
-- ya traía por cobrar), con lo que NO se puede valorar dicho aparte (las
-- horas del dueño, que no cobra por hora; las de quien no tiene tarifa; las
-- horas de antes de la app). No inventa: propone, y Edgar confirma o pone
-- lo de QuickBooks (fn_wip_antes).
create or replace function public.fn_wip_antes_propuesta(p_proyecto text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  o        record;
  v_ld     date := fn_wip_libro_desde();
  v_rec    record;
  v_ext    record;
  v_hor    record;
  v_fac    record;
  v_base   numeric;
  v_costo  numeric;
  v_notas  text[] := '{}';
begin
  perform fn_wip_exigir_dueno();
  select * into o from fn_wip_obras(p_proyecto) x;
  if not found then
    raise exception using errcode = 'MX008', message = format('No existe la obra «%s».', coalesce(p_proyecto, ''));
  end if;
  select count(*) as n, coalesce(sum(round(r.total, 2)), 0) as monto, count(*) filter (where r.total is null) as sin_total
    into v_rec
    from recibos r
   where r.proyecto_id = p_proyecto and r.fecha < v_ld and coalesce(r.estado, '') <> 'anulado';
  select count(*) as n, coalesce(sum(round(te.costo, 2)), 0) as monto
    into v_ext
    from trabajos_externos te
   where te.proyecto_id = p_proyecto and te.fecha < v_ld;
  select coalesce(sum(h.horas) filter (where pf.rol is distinct from 'dueno'), 0) as horas,
         coalesce(sum(round(h.horas * ce.costo_hora, 2)) filter (where pf.rol is distinct from 'dueno' and ce.costo_hora is not null), 0) as monto,
         coalesce(sum(h.horas) filter (where pf.rol is distinct from 'dueno' and ce.costo_hora is null), 0) as sin_tarifa,
         coalesce(sum(h.horas) filter (where pf.rol = 'dueno'), 0) as dueno
    into v_hor
    from horas h
    left join perfiles pf on pf.id = h.usuario_id
    left join costos_equipo ce on ce.usuario_id = h.usuario_id
   where h.proyecto_id = p_proyecto and h.fecha < v_ld and h.horas > 0 and h.horas < 100000;
  select count(*) as n, coalesce(sum(round(f.monto, 2)), 0) as monto
    into v_fac
    from facturas f
   where f.proyecto_id = p_proyecto and f.monto is not null
     and coalesce(f.estado, 'emitida') not in ('anulada', 'borrador')
     and (f.fecha < v_ld
          or exists (select 1 from asiento_lineas l
                       join asientos a on a.id = l.asiento_id
                      where l.partida_tabla = 'facturas' and l.partida_id = f.id::text
                        and (a.tipo = 'apertura'
                             or a.afecta_periodo in (select q.periodo from periodos q where q.tipo = 'apertura'))));
  select nullif(p.horas_reales_base, 0) into v_base from proyectos p where p.id = p_proyecto;
  v_costo := v_rec.monto + v_ext.monto + v_hor.monto;
  if v_rec.sin_total > 0 then
    v_notas := v_notas || format('%s ticket(s) de antes no tienen total: no suman.', v_rec.sin_total);
  end if;
  if v_hor.horas > 0 then
    v_notas := v_notas || format('Las %s h de la cuadrilla de antes van a la tarifa de HOY de «Costos del equipo» (no guarda historia), '
                                 'sin carga encima.', trim_scale(v_hor.horas));
  end if;
  if v_hor.sin_tarifa > 0 then
    v_notas := v_notas || format('%s h son de alguien sin tarifa en «Costos del equipo»: no suman.', trim_scale(v_hor.sin_tarifa));
  end if;
  if v_hor.dueno > 0 then
    v_notas := v_notas || format('%s h son del dueño, que no cobra por hora: no suman.', trim_scale(v_hor.dueno));
  end if;
  if v_base is not null then
    v_notas := v_notas || format('La ficha trae %s h de antes de la app, sin persona ni tarifa: no suman.', trim_scale(v_base));
  end if;
  v_notas := v_notas || 'Lo que no pasó por la app (un pago sin ticket, la tarjeta, un sub pagado por fuera) no está aquí: compáralo con '
                        'el costo y lo facturado de esa obra en QuickBooks al 30 de septiembre, y si no coincide pon lo de QuickBooks '
                        'con su nota.'::text;
  return jsonb_build_object(
    'proyecto_id', o.proyecto_id, 'obra', o.obra, 'libro_desde', v_ld, 'hasta', v_ld - 1,
    'de_antes', o.de_antes, 'de_antes_por', o.de_antes_por,
    'costo', jsonb_build_object(
      'tickets', jsonb_build_object('n', v_rec.n, 'monto', v_rec.monto::numeric(14,2)),
      'trabajos_externos', jsonb_build_object('n', v_ext.n, 'monto', v_ext.monto::numeric(14,2)),
      'horas', jsonb_build_object('horas', v_hor.horas, 'monto', v_hor.monto::numeric(14,2), 'sin_tarifa', v_hor.sin_tarifa,
                                  'del_dueno', v_hor.dueno, 'de_antes_de_la_app', v_base),
      'total', v_costo::numeric(14,2)),
    'facturado', jsonb_build_object(
      'facturas', jsonb_build_object('n', v_fac.n, 'monto', v_fac.monto::numeric(14,2)),
      'total', v_fac.monto::numeric(14,2)),
    'notas', to_jsonb(v_notas),
    'confirmado', case when o.antes_id is not null
                       then jsonb_build_object('id', o.antes_id, 'costo', o.antes_costo, 'facturado', o.antes_facturado,
                                               'nota', o.antes_nota, 'confirmado_el', o.antes_confirmado_el,
                                               'confirmado_por', o.antes_confirmado_por) end);
end $$;
revoke execute on function public.fn_wip_antes_propuesta(text) from public, anon, service_role;
grant  execute on function public.fn_wip_antes_propuesta(text) to authenticated;
comment on function public.fn_wip_antes_propuesta(text) is 'c12: lo de antes del libro de una obra, PROPUESTO desde los papeles de la app: costo (tickets no anulados, trabajos externos y las horas de la cuadrilla × su tarifa de hoy, cada uno con cuántos y cuánto, y el total) y facturado (las facturas no anuladas de antes del libro y las que la apertura ya traía), las notas de lo que no se puede valorar (horas del dueño, sin tarifa, de antes de la app; lo que no pasó por la app) y lo ya confirmado, si lo hay. No escribe nada. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 6. LO QUE ESCRIBE LA PANTALLA (como el dueño): la configuración, la marca
--    de una obra, lo de antes del libro y la revisión del mes. Todo
--    SECURITY INVOKER con es_dueno() por dentro; cada una pone la marca de
--    la guarda justo antes de escribir y la quita después.
-- ---------------------------------------------------------------------
-- La configuración: desde qué mes exige el cierre el WIP (cabecera, 7).
-- Sin claves, solo la devuelve.
create or replace function public.fn_wip_config(p jsonb default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c       wip_config;
  v_sobra text;
  v_d     text;
begin
  perform fn_wip_exigir_dueno();
  if p is not null and jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'La configuración llega como un objeto JSON: {"exigir_desde": "2026-11"}.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(coalesce(p, '{}'::jsonb)) k where k <> 'exigir_desde';
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en la configuración del WIP: %s. La única es exigir_desde.', v_sobra);
  end if;
  if p ? 'exigir_desde' then
    v_d := nullif(btrim(p->>'exigir_desde'), '');
    if v_d is not null and not exists (select 1 from periodos q where q.periodo = v_d and q.tipo = 'mes') then
      raise exception using errcode = '22023',
        message = format('«%s» no es un mes del libro: va como AAAA-MM (por ejemplo 2026-11), o vacío para no exigir el WIP todavía.', v_d);
    end if;
    perform set_config('mx_wip.escribe', 'wip_config', true);
    update wip_config set exigir_desde = v_d, actualizado = now(), actualizado_por = auth.uid() where id = 1;
    perform set_config('mx_wip.escribe', '', true);
  end if;
  select * into c from wip_config where id = 1;
  return jsonb_build_object(
    'exigir_desde', c.exigir_desde,
    'exigir_desde_nombre', case when c.exigir_desde is not null then fn_wip_mes(c.exigir_desde) end,
    'actualizado', c.actualizado, 'actualizado_por', c.actualizado_por,
    'nota', case when c.exigir_desde is null
                 then 'El cierre todavía no exige el WIP en ningún mes: se puede revisar y postear, pero no detiene.'
                 else format('El cierre exige el WIP (cada obra revisada y el ajuste posteado) desde %s; los meses anteriores no se '
                             'frenan por él.', fn_wip_mes(c.exigir_desde)) end);
end $$;
revoke execute on function public.fn_wip_config(jsonb) from public, anon, service_role;
grant  execute on function public.fn_wip_config(jsonb) to authenticated;
comment on function public.fn_wip_config(jsonb) is 'c12: lee o cambia la configuración del WIP: {"exigir_desde": "AAAA-MM"} es el primer mes cuyo cierre exige el WIP (vacío o null = no se exige). Devuelve la configuración con su nota en llano. Solo el dueño.';

-- La marca de una obra cuando la regla no acierta: «contrato» (es de precio
-- fijo: lleva WIP), «tm» (de servicio o por tiempo y material: no lo lleva)
-- o «auto» (vuelve a la regla). Con su nota; cada cambio queda en historial.
create or replace function public.fn_wip_obra(p_proyecto text, p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_sobra text;
  v_modo  text;
  v_nota  text;
  v_fila  jsonb;
begin
  perform fn_wip_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'La marca llega como un objeto JSON: {"modo": "contrato" | "tm" | "auto", "nota": "…"}.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(p) k where k not in ('modo', 'nota');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en la marca de la obra: %s.', v_sobra);
  end if;
  v_modo := lower(btrim(coalesce(p->>'modo', '')));
  v_nota := nullif(btrim(p->>'nota'), '');
  if v_modo not in ('contrato', 'tm', 'auto') then
    raise exception using errcode = '22023',
      message = 'El modo es «contrato» (de precio fijo: lleva WIP), «tm» (de servicio o por tiempo y material: no lo lleva) o «auto» (la regla).';
  end if;
  if not exists (select 1 from proyectos pr where pr.id = p_proyecto) then
    raise exception using errcode = 'MX008', message = format('No existe la obra «%s».', coalesce(p_proyecto, ''));
  end if;
  if v_modo <> 'auto' and v_nota is null then
    raise exception using errcode = '22023',
      message = 'Di por qué en la nota (por ejemplo, «servicio con precio cerrado» o «se factura por horas»): queda escrito con la marca.';
  end if;
  perform set_config('mx_wip.escribe', 'wip_obras', true);
  insert into wip_obras as o (proyecto_id, modo, nota, marcado_el, marcado_por)
  values (p_proyecto, nullif(v_modo, 'auto'), v_nota, now(), auth.uid())
  on conflict (proyecto_id) do update
     set historial = o.historial || jsonb_build_array(jsonb_build_object('modo', o.modo, 'nota', o.nota, 'marcado_el', o.marcado_el,
                                                                         'marcado_por', o.marcado_por)),
         modo = excluded.modo, nota = excluded.nota, marcado_el = excluded.marcado_el, marcado_por = excluded.marcado_por;
  perform set_config('mx_wip.escribe', '', true);
  select to_jsonb(x) into v_fila from fn_wip_obras(p_proyecto) x;
  return jsonb_build_object('proyecto_id', p_proyecto, 'obra', v_fila,
                            'nota', format('%s Si el ajuste de un mes abierto ya estaba posteado, vuelve a postearlo.', v_fila->>'motivo'));
end $$;
revoke execute on function public.fn_wip_obra(text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_wip_obra(text, jsonb) to authenticated;
comment on function public.fn_wip_obra(text, jsonb) is 'c12: marca una obra para el WIP cuando la regla no acierta: {"modo": "contrato"} (de precio fijo: lleva WIP), {"modo": "tm"} (de servicio o por tiempo y material: no lo lleva) o {"modo": "auto"} (vuelve a la regla), con su nota (obligatoria salvo en auto). Guarda quién y cuándo, y el cambio anterior en historial. Devuelve la obra como queda. Solo el dueño.';

-- LO DE ANTES DEL LIBRO, CONFIRMADO: el costo y lo facturado de la obra
-- hasta el día anterior al libro. Si los números no son los que proponen
-- los papeles de la app, pide la nota (de dónde salen). Una confirmación
-- nueva sustituye a la anterior, que queda.
create or replace function public.fn_wip_antes(p_proyecto text, p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_sobra text;
  v_costo numeric;
  v_fact  numeric;
  v_nota  text;
  v_prop  jsonb;
  v_viva  wip_antes;
  v_id    uuid;
  v_abiertos text;
begin
  perform fn_wip_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'Lo de antes llega como un objeto JSON: {"costo": "…", "facturado": "…", "nota": "…"}.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(p) k where k not in ('costo', 'facturado', 'nota');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en lo de antes del libro: %s.', v_sobra);
  end if;
  -- (la propuesta comprueba que la obra existe: MX008 si no)
  v_prop  := fn_wip_antes_propuesta(p_proyecto);
  v_costo := fn_wip_monto(p->>'costo', 'el costo de antes del libro', true);
  v_fact  := fn_wip_monto(p->>'facturado', 'lo facturado antes del libro', true);
  v_nota  := nullif(btrim(p->>'nota'), '');
  if (v_costo <> (v_prop->'costo'->>'total')::numeric or v_fact <> (v_prop->'facturado'->>'total')::numeric) and v_nota is null then
    raise exception using errcode = '22023',
      message = format('Estos números (costo %s, facturado %s) no son los que salen de los papeles de la app (costo %s, facturado %s): '
                       'di de dónde salen en la nota (por ejemplo, «costo por obra de QuickBooks al 30 de septiembre»).',
                       fn_wip_usd(v_costo), fn_wip_usd(v_fact), fn_wip_usd((v_prop->'costo'->>'total')::numeric),
                       fn_wip_usd((v_prop->'facturado'->>'total')::numeric));
  end if;
  perform pg_advisory_xact_lock(820261112, hashtext('antes:' || p_proyecto));
  select * into v_viva from wip_antes a where a.proyecto_id = p_proyecto and a.sustituida_el is null;
  if found and v_viva.costo = v_costo and v_viva.facturado = v_fact and v_viva.nota is not distinct from v_nota then
    return jsonb_build_object('proyecto_id', p_proyecto, 'antes_id', v_viva.id, 'costo', v_viva.costo, 'facturado', v_viva.facturado,
                              'ya_estaba', true, 'nota', 'Lo de antes del libro ya estaba confirmado con esos mismos números.');
  end if;
  perform set_config('mx_wip.escribe', 'wip_antes', true);
  update wip_antes set sustituida_el = clock_timestamp(), sustituida_por = auth.uid()
   where proyecto_id = p_proyecto and sustituida_el is null;
  insert into wip_antes (proyecto_id, costo, facturado, propuesta, nota, confirmado_por)
  values (p_proyecto, v_costo, v_fact, v_prop - 'confirmado', v_nota, auth.uid())
  returning id into v_id;
  perform set_config('mx_wip.escribe', '', true);
  -- los meses abiertos cuyo ajuste ya estaba posteado: hay que volver a postearlos
  select string_agg(fn_wip_mes(a.periodo), ', ' order by a.periodo) into v_abiertos
    from wip_ajustes a
    join periodos q on q.periodo = a.periodo
   where a.deshecho_el is null and q.estado = 'abierto';
  return jsonb_build_object(
    'proyecto_id', p_proyecto, 'antes_id', v_id, 'costo', v_costo, 'facturado', v_fact, 'ya_estaba', false,
    'sustituye', v_viva.id, 'propuesta', v_prop - 'confirmado',
    'nota', format('Confirmado lo de antes del libro de «%s»: costo %s y facturado %s.%s', v_prop->>'obra', fn_wip_usd(v_costo),
                   fn_wip_usd(v_fact),
                   case when v_abiertos is null then ''
                        else format(' El ajuste de %s ya estaba posteado: mira si sigue al día y, si no, vuelve a postearlo.', v_abiertos) end));
end $$;
revoke execute on function public.fn_wip_antes(text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_wip_antes(text, jsonb) to authenticated;
comment on function public.fn_wip_antes(text, jsonb) is 'c12: confirma lo de antes del libro de una obra: {"costo": "…", "facturado": "…", "nota": "…"} (montos hasta el día anterior al libro; el cero vale). Si no son los que proponen los papeles de la app (fn_wip_antes_propuesta) pide la nota. Guarda la propuesta de ese día, quién y cuándo; sustituye a la confirmación anterior, que queda. Solo el dueño.';

-- LA REVISIÓN DE UNA OBRA EN UN MES (cabecera, punto 2). Cinco formas:
--   {"confirmar": true}                         un toque: lo propuesto (lo del
--                                               mes anterior o, la primera
--                                               vez, el estimado de la obra)
--   {"costo_estimado": "12345.00", "nota": "…"} otro número, con su nota
--   {"terminada": true}                         la obra terminó: 100 %
--   {"excluir": true, "nota": "…"}              este mes queda FUERA del WIP,
--                                               a propósito y con su porqué
--                                               (se canceló, pasó a T&M, este
--                                               mes no se puede medir): su
--                                               ingreso vuelve a ser lo
--                                               facturado. Es la única forma
--                                               de que salga una obra que
--                                               traía saldo
--   {"precio_de_despues": true}                 un toque: el contrato de la
--                                               ficha cambió DESPUÉS de este
--                                               mes; la revisión se queda con
--                                               el precio que tenía, y queda
--                                               escrito
-- y, si el mes necesita otro precio que el de la ficha, "precio_contrato"
-- con su nota. El precio se copia de la ficha (cambia sin historia). Pide la
-- nota cuando el número no es el propuesto y cuando el precio no es el de la
-- ficha. El costo total estimado NO puede ser menor que lo que la obra ya
-- lleva (MX005): daría más de 100 % y se ganaría el precio entero sin haber
-- terminado; se sube, o la obra se marca terminada. Un mes cerrado no se
-- toca. No rehace el ajuste: si ya estaba posteado, lo dice (y el control lo
-- pone en rojo hasta que se vuelva a postear).
create or replace function public.fn_wip_revisar(p_proyecto text, p_periodo text, p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  per       periodos;
  o         record;
  f         record;
  v_hay_f   boolean;
  v_hoy     date := fn_fecha_miami(now());
  v_nom     text;
  v_sobra   text;
  v_term    boolean;
  v_conf    boolean;
  v_excl    boolean;
  v_pdd     boolean;
  v_nota    text;
  v_ficha   numeric;
  v_precio  numeric;
  v_costo   numeric;
  v_dado    numeric;
  v_origen  text;
  v_cfecha  numeric;
  v_prop    numeric;
  v_prop_o  text;
  v_viva    wip_revisiones;
  v_id      uuid;
  v_fila    jsonb;
  v_est     jsonb;
begin
  perform fn_wip_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023',
      message = 'La revisión llega como un objeto JSON: {"confirmar": true}, {"costo_estimado": "…", "nota": "…"}, {"terminada": true}, '
                '{"excluir": true, "nota": "…"} o {"precio_de_despues": true}.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p) k
   where k not in ('confirmar', 'costo_estimado', 'nota', 'terminada', 'precio_contrato', 'excluir', 'precio_de_despues');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en la revisión: %s.', v_sobra);
  end if;
  select * into per from periodos q where q.periodo = p_periodo;
  if not found or per.tipo <> 'mes' then
    raise exception using errcode = 'MX002', message = format('No existe el mes «%s» (va como AAAA-MM).', coalesce(p_periodo, ''));
  end if;
  v_nom := fn_wip_mes(per.periodo);
  if per.estado <> 'abierto' then
    raise exception using errcode = 'MX002',
      message = format('%s ya está cerrado: su WIP no se toca. Lo que haya cambiado se revisa en el mes abierto.',
                       initcap(left(v_nom, 1)) || substr(v_nom, 2));
  end if;
  if per.desde > v_hoy then
    raise exception using errcode = 'MX002',
      message = format('%s todavía no empieza (hoy es %s en Miami): una obra se revisa en el mes que se está cerrando.',
                       initcap(left(v_nom, 1)) || substr(v_nom, 2), fn_wip_dia(v_hoy));
  end if;
  select * into o from fn_wip_obras(p_proyecto) x;
  if not found then
    raise exception using errcode = 'MX008', message = format('No existe la obra «%s».', coalesce(p_proyecto, ''));
  end if;
  begin
    v_term := coalesce((p->>'terminada')::boolean, false);
    v_conf := coalesce((p->>'confirmar')::boolean, false);
    v_excl := coalesce((p->>'excluir')::boolean, false);
    v_pdd  := coalesce((p->>'precio_de_despues')::boolean, false);
  exception when others then
    raise exception using errcode = '22023', message = 'terminada, confirmar, excluir y precio_de_despues son true o false.';
  end;
  v_nota := nullif(btrim(p->>'nota'), '');
  if not o.lleva_wip and not v_excl then
    raise exception using errcode = 'MX008',
      message = format('«%s» no lleva WIP. %s Si de verdad es de precio fijo, márcala antes (modo «contrato»); si traía saldo del WIP y '
                       'ya no va, exclúyela con su nota.', o.obra, o.motivo);
  end if;
  if coalesce(btrim(p->>'costo_estimado'), '') <> '' then
    v_dado := fn_wip_monto(p->>'costo_estimado', 'el costo total estimado');
  end if;
  if v_term and (v_conf or v_dado is not null) then
    raise exception using errcode = '22023',
      message = 'Una obra terminada no lleva costo estimado ni propuesta que confirmar: su costo final es el que lleva. Manda solo {"terminada": true}.';
  end if;
  if (v_excl or v_pdd) and (v_term or v_conf or v_dado is not null or coalesce(btrim(p->>'precio_contrato'), '') <> '' or (v_excl and v_pdd)) then
    raise exception using errcode = '22023',
      message = 'Excluir una obra del WIP del mes, o decir que el cambio de su contrato es de después, va solo: {"excluir": true, "nota": "…"} '
                'o {"precio_de_despues": true}.';
  end if;
  if v_excl and v_nota is null then
    raise exception using errcode = '22023',
      message = format('Dejar «%s» fuera del WIP de %s pide su porqué en la nota (por ejemplo, «el cliente canceló el contrato» o «falta '
                       'el costo de antes: lo pasa el contador en diciembre»): queda escrito con quién y cuándo.', o.obra, v_nom);
  end if;

  -- Dos revisiones a la vez de la misma obra y mes: una detrás de otra.
  -- (primero el candado del ajuste del mes: una revisión no entra a mitad de un «postear» de ese mes; después el suyo)
  perform pg_advisory_xact_lock(820261112, hashtext('ajuste:' || per.periodo));
  perform pg_advisory_xact_lock(820261112, hashtext('rev:' || p_proyecto || ':' || per.periodo));

  -- La fila de hoy, con su propuesta (si la obra entra en el mes), y la revisión viva del mes.
  select * into f from fn_wip_calcular(per.periodo, p_proyecto, true) s;
  v_hay_f := found;
  if v_hay_f then
    v_prop := f.propuesta_costo_estimado; v_prop_o := f.propuesta_origen;
  end if;
  select * into v_viva from wip_revisiones r where r.proyecto_id = p_proyecto and r.periodo = per.periodo and r.sustituida_el is null;
  v_ficha := o.contrato;

  if v_excl then
    -- FUERA ESTE MES, a propósito. Solo una obra que está en el WIP del mes
    -- (activa, con revisión, o que traía saldo): lo demás no tiene de dónde salir.
    if not v_hay_f then
      raise exception using errcode = 'MX008',
        message = format('«%s» no está en el WIP de %s (no lleva WIP ni traía saldo del ajuste anterior): no hay nada que excluir.',
                         o.obra, v_nom);
    end if;
    v_precio := v_ficha; v_costo := null; v_origen := 'excluida';
  elsif v_pdd then
    -- EL CAMBIO DEL CONTRATO ES DE DESPUÉS: la revisión del mes se queda como
    -- está (su costo estimado, su precio), y apunta el contrato que la ficha
    -- dice hoy: deja de pedir que se revise otra vez. Queda escrito en su nota.
    if v_viva.id is null or v_viva.excluida then
      raise exception using errcode = 'MX008',
        message = format('«%s» no tiene una revisión en %s que conservar: revísala primero.', o.obra, v_nom);
    end if;
    if v_ficha is not distinct from v_viva.precio_contrato or v_ficha is not distinct from v_viva.precio_ficha then
      raise exception using errcode = 'MX008',
        message = format('El contrato de la ficha de «%s» no cambió desde que se revisó en %s: no hay nada que decir.', o.obra, v_nom);
    end if;
    v_precio := v_viva.precio_contrato; v_costo := v_viva.costo_estimado; v_term := v_viva.terminada; v_origen := v_viva.origen;
    v_prop := v_viva.propuesta; v_prop_o := v_viva.propuesta_origen;
    v_nota := left(concat_ws(' · ', v_viva.nota,
                format('El contrato de la ficha pasó de %s a %s después de %s: este mes se queda con %s.',
                       case when v_viva.precio_ficha is null then 'vacío' else fn_wip_usd(v_viva.precio_ficha) end,
                       case when v_ficha is null then 'vacío' else fn_wip_usd(v_ficha) end, v_nom, fn_wip_usd(v_viva.precio_contrato))), 1000);
  else
    -- El precio: el de la ficha hoy, o el que se diga (con su nota).
    if coalesce(btrim(p->>'precio_contrato'), '') <> '' then
      v_precio := fn_wip_monto(p->>'precio_contrato', 'el precio del contrato');
    else
      v_precio := v_ficha;
    end if;
    if v_precio is null then
      raise exception using errcode = 'MX008',
        message = format('«%s» no tiene contrato en su ficha: ponlo en la obra, o dilo en la revisión (precio_contrato) con su nota.', o.obra);
    end if;
    if v_ficha is distinct from v_precio and v_nota is null then
      raise exception using errcode = '22023',
        message = format('El precio que pones (%s) no es el contrato de la ficha (%s): deja escrito por qué en la nota (por ejemplo, '
                         '«orden de cambio 2 firmada, falta en la ficha»).', fn_wip_usd(v_precio),
                         case when v_ficha is null then 'vacío' else fn_wip_usd(v_ficha) end);
    end if;

    if v_term then
      if not o.terminada then
        raise exception using errcode = 'MX008',
          message = format('La app tiene «%s» como «%s», no como terminada: márcala completada en su ficha y revísala como terminada, o '
                           'revisa su costo estimado.', o.obra, o.obra_estado);
      end if;
      v_costo := null;
      v_origen := 'terminada';
    elsif v_conf then
      if not v_hay_f or f.propuesta_costo_estimado is null then
        raise exception using errcode = 'MX008',
          message = format('No hay una propuesta que confirmar para «%s» en %s (ni revisión anterior ni un estimado completo): escribe '
                           'su costo total estimado.', o.obra, v_nom);
      end if;
      if v_dado is not null and v_dado <> f.propuesta_costo_estimado then
        raise exception using errcode = 'MX008',
          message = format('La propuesta de «%s» ya no es la que viste (%s; ahora es %s): vuelve a mirar antes de confirmar.', o.obra,
                           fn_wip_usd(v_dado), fn_wip_usd(f.propuesta_costo_estimado));
      end if;
      v_costo := f.propuesta_costo_estimado;
      v_origen := coalesce(f.propuesta_origen, 'a_mano');
    else
      if v_dado is null then
        raise exception using errcode = '22023',
          message = 'Falta el costo total estimado (costo_estimado), o confirmar lo propuesto (confirmar), o decir que la obra terminó '
                    '(terminada), o dejarla fuera este mes con su nota (excluir).';
      end if;
      v_costo := v_dado;
      v_origen := case when v_hay_f and f.propuesta_costo_estimado = v_costo then coalesce(f.propuesta_origen, 'a_mano') else 'a_mano' end;
      if v_origen = 'a_mano' and v_hay_f and f.propuesta_costo_estimado is not null and v_nota is null then
        raise exception using errcode = '22023',
          message = format('Cambias el costo estimado de «%s» de %s (%s) a %s: deja escrito por qué en la nota.', o.obra,
                           fn_wip_usd(f.propuesta_costo_estimado),
                           case f.propuesta_origen when 'mes_anterior' then 'lo del mes anterior' when 'estimado' then 'su estimado'
                                else 'lo propuesto' end, fn_wip_usd(v_costo));
      end if;
    end if;

    -- EL COSTO TOTAL ESTIMADO NO PUEDE SER MENOR QUE LO QUE LA OBRA YA LLEVA
    -- (con nota o sin ella): daría más de 100 %, el avance se toparía y el
    -- libro ganaría el precio entero de una obra sin terminar.
    if not v_term then
      select coalesce(l.costo, 0) into v_cfecha from fn_wip_libro(per.hasta, p_proyecto) l;
      v_cfecha := coalesce(v_cfecha, 0) + coalesce(o.antes_costo, 0);
      if v_cfecha > v_costo then
        raise exception using errcode = 'MX005',
          message = format('El costo total estimado (%s) es menor que lo que «%s» ya lleva al %s (%s): daría %s %% de avance. El costo '
                           'total no puede ser menos de lo gastado: súbelo (por lo menos a %s, más lo que falte por gastar) o, si la '
                           'obra terminó, márcala terminada.', fn_wip_usd(v_costo), o.obra, fn_wip_dia(per.hasta), fn_wip_usd(v_cfecha),
                           trim_scale(round(100 * v_cfecha / v_costo, 2)), fn_wip_usd(v_cfecha));
      end if;
    end if;
  end if;

  if v_viva.id is not null and v_viva.precio_contrato is not distinct from v_precio and v_viva.costo_estimado is not distinct from v_costo
     and v_viva.terminada = v_term and v_viva.excluida = v_excl and v_viva.precio_ficha is not distinct from v_ficha
     and v_viva.nota is not distinct from v_nota then
    v_id := v_viva.id;
  else
    perform set_config('mx_wip.escribe', 'wip_revisiones', true);
    update wip_revisiones set sustituida_el = clock_timestamp(), sustituida_por = auth.uid()
     where proyecto_id = p_proyecto and periodo = per.periodo and sustituida_el is null;
    insert into wip_revisiones (proyecto_id, periodo, precio_contrato, precio_ficha, costo_estimado, terminada, excluida, origen, propuesta,
                                propuesta_origen, nota, revisado_por)
    values (p_proyecto, per.periodo, v_precio, v_ficha, v_costo, v_term, v_excl, v_origen, v_prop, v_prop_o, v_nota, auth.uid())
    returning id into v_id;
    perform set_config('mx_wip.escribe', '', true);
  end if;

  select to_jsonb(s) into v_fila from fn_wip_calcular(per.periodo, p_proyecto, false) s;
  v_est := fn_wip_ajuste_estado(per.periodo);
  return jsonb_build_object(
    'revision_id', v_id, 'periodo', per.periodo, 'proyecto_id', p_proyecto, 'ya_estaba', v_viva.id is not distinct from v_id,
    'origen', v_origen, 'fila', v_fila,
    'ajuste', jsonb_build_object('vivo', v_est->'vivo', 'al_dia', v_est->'al_dia', 'numero', v_est->'numero', 'cambios', v_est->'cambios'),
    'nota', case when v_excl then format('«%s» queda fuera del WIP de %s: su ingreso de ese mes es lo facturado.', o.obra, v_nom)
                 else 'Revisada.' end
            || case when (v_est->>'vivo')::boolean and not (v_est->>'al_dia')::boolean
                    then format(' El ajuste de %s ya estaba posteado (asiento %s) y con esto ya no está al día: vuelve a postearlo '
                                '(se reversa y entra el nuevo).', v_nom, v_est->>'numero')
                    when v_fila->>'estado' = 'pendiente' then ' ' || coalesce(v_fila->>'falta_texto', '')
                    else '' end);
end $$;
revoke execute on function public.fn_wip_revisar(text, text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_wip_revisar(text, text, jsonb) to authenticated;
comment on function public.fn_wip_revisar(text, text, jsonb) is 'c12: la revisión de una obra en un mes abierto: {"confirmar": true} (un toque: lo propuesto, que es lo del mes anterior o, la primera vez, el estimado de la obra), {"costo_estimado": "…", "nota": "…"} (otro número: el costo TOTAL estimado, desde el inicio hasta terminar), {"terminada": true} (100 %; la obra tiene que estar completada en la app), {"excluir": true, "nota": "…"} (este mes queda fuera del WIP a propósito, con su porqué: la única forma de que salga una obra que traía saldo) o {"precio_de_despues": true} (un toque: el contrato de la ficha cambió después de este mes y la revisión se queda con el precio que tenía). Copia el precio de la ficha (o el de "precio_contrato", con su nota). Pide la nota si el número no es el propuesto o si el precio no es el de la ficha; el costo estimado no puede ser menor que lo que la obra ya lleva (MX005). Sustituye a la revisión anterior del mes, que queda. Devuelve la fila del WIP como queda y si el ajuste ya posteado dejó de estar al día. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 7. EL AJUSTE DEL MES: postear (o rehacer) y deshacer (cabecera, punto 6).
--    Al libro entra por fn_postear y sale por fn_reversar, las dos de c2 y
--    para el dueño: nada se rodea.
-- ---------------------------------------------------------------------
create or replace function public.fn_wip_postear(p_periodo text, p_motivo text default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  per       periodos;
  v_hoy     date := fn_fecha_miami(now());
  v_nom     text;
  v_plan    jsonb;
  v_est     jsonb;
  v_tot     jsonb;
  v_nlin    int;
  v_fuera   jsonb;
  v_excl    jsonb;
  a         wip_ajustes;
  v_motivo  text;
  v_rev     jsonb;
  v_res     jsonb;
  v_id      uuid;
  v_aj      uuid := gen_random_uuid();
  v_sust    uuid;
  v_rehecho jsonb;
begin
  perform fn_wip_exigir_dueno();
  select * into per from periodos q where q.periodo = p_periodo;
  if not found or per.tipo <> 'mes' then
    raise exception using errcode = 'MX002', message = format('No existe el mes «%s» (va como AAAA-MM).', coalesce(p_periodo, ''));
  end if;
  v_nom := fn_wip_mes(per.periodo);
  if per.estado <> 'abierto' then
    raise exception using errcode = 'MX002',
      message = format('%s ya está cerrado: su ajuste de WIP no se toca (si lo tuvo, ya se deshizo solo el día 1). Lo que haya cambiado '
                       'entra en el ajuste del mes abierto.', initcap(left(v_nom, 1)) || substr(v_nom, 2));
  end if;
  if per.hasta >= v_hoy then
    raise exception using errcode = 'MX002',
      message = format('%s todavía no termina (su último día es el %s; hoy es %s en Miami): el ajuste del WIP se postea con el mes '
                       'terminado, desde el %s. Hasta entonces siguen entrando costos y facturas.',
                       initcap(left(v_nom, 1)) || substr(v_nom, 2), fn_wip_dia(per.hasta), fn_wip_dia(v_hoy), fn_wip_dia(per.hasta + 1));
  end if;
  -- Dos a la vez no postean dos (el candado de aquí). Y el candado de la
  -- cadena del libro (c2), tomado ya, como hace el cierre de c9: entre el
  -- cálculo y el asiento no entra ningún otro asiento (un costo o una factura
  -- que llega en ese instante espera a que esto termine: el ajuste sale con
  -- lo que el libro dice al confirmar). fn_postear lo vuelve a tomar: es el
  -- mismo de esta transacción.
  perform pg_advisory_xact_lock(820261112, hashtext('ajuste:' || per.periodo));
  perform pg_advisory_xact_lock(820260923);

  v_plan := fn_wip_plan(per.periodo);
  v_est  := fn_wip_ajuste_estado(per.periodo, v_plan);
  v_tot  := v_plan->'totales';
  v_nlin := jsonb_array_length(v_plan->'lineas');
  select coalesce(jsonb_agg(jsonb_build_object('proyecto_id', x.proyecto_id, 'obra', x.obra, 'falta', x.falta, 'falta_texto', x.falta_texto)
                            order by x.obra), '[]'::jsonb)
    into v_fuera
    from jsonb_to_recordset(v_plan->'filas') as x(proyecto_id text, obra text, estado text, falta jsonb, falta_texto text)
   where x.estado = 'pendiente';
  -- (las que Edgar dejó fuera este mes a propósito, con su nota)
  select coalesce(jsonb_agg(jsonb_build_object('proyecto_id', x.proyecto_id, 'obra', x.obra, 'nota', x.revision_nota) order by x.obra), '[]'::jsonb)
    into v_excl
    from jsonb_to_recordset(v_plan->'filas') as x(proyecto_id text, obra text, estado text, revision_nota text)
   where x.estado = 'excluida';

  if (v_est->>'vivo')::boolean then
    select * into a from wip_ajustes x where x.id = (v_est->>'id')::uuid;
    if (v_est->>'por_fuera')::boolean then
      -- Su asiento se reversó en el libro sin pasar por aquí (fn_reversar a
      -- mano): se anota como deshecho por fuera, y sigue.
      v_motivo := left('Su asiento se reversó en el libro por fuera del WIP: ' || coalesce(v_est->'reverso'->>'motivo', '(sin motivo)'), 1000);
      perform set_config('mx_wip.escribe', 'wip_ajustes', true);
      update wip_ajustes set deshecho_el = clock_timestamp(), deshecho_por = auth.uid(), deshecho_motivo = v_motivo,
                             reverso_id = (v_est->'reverso'->>'id')::uuid, por_fuera = true
       where id = a.id;
      perform set_config('mx_wip.escribe', '', true);
      v_sust := a.id;
      v_rehecho := jsonb_build_object('ajuste_id', a.id, 'numero', a.numero, 'por_fuera', true, 'motivo', v_motivo);
    elsif (v_est->>'al_dia')::boolean then
      -- Dos veces = uno: el que estaba.
      return jsonb_build_object(
        'periodo', per.periodo, 'posteado', true, 'ya_estaba', true, 'ajuste_id', a.id,
        'asiento', jsonb_build_object('id', a.asiento_id, 'numero', a.numero, 'fecha', a.fecha),
        'reverso', v_est->'reverso_auto',
        'obras', a.obras, 'lineas', a.lineas, 'sub_facturado', a.sub_facturado, 'sobre_facturado', a.sobre_facturado, 'perdida', a.perdida,
        'fuera', v_fuera, 'excluidas', v_excl,
        'nota', format('El ajuste de WIP de %s ya estaba posteado y sigue al día (asiento %s): no se duplica.', v_nom, a.numero));
    else
      -- Cambió después de postear: se reversa dentro de su mes (c2 anula
      -- también su reverso del día 1) y entra el nuevo.
      v_motivo := left(format('El WIP de %s cambió después de postear su ajuste (%s): %s.%s', v_nom, a.numero,
                              coalesce(v_est->>'cambios', 'cambió su cálculo'), coalesce(' ' || nullif(btrim(p_motivo), ''), '')), 1000);
      v_rev := fn_reversar(a.asiento_id, v_motivo);
      perform set_config('mx_wip.escribe', 'wip_ajustes', true);
      update wip_ajustes set deshecho_el = clock_timestamp(), deshecho_por = auth.uid(), deshecho_motivo = v_motivo,
                             reverso_id = (v_rev->>'id')::uuid
       where id = a.id;
      perform set_config('mx_wip.escribe', '', true);
      v_sust := a.id;
      v_rehecho := jsonb_build_object('ajuste_id', a.id, 'numero', a.numero, 'por_fuera', false, 'motivo', v_motivo,
                                      'reverso', jsonb_build_object('id', v_rev->>'id', 'numero', v_rev->>'numero'),
                                      'anula_reverso_automatico', v_rev->'anula'->>'numero');
    end if;
  end if;

  if v_nlin = 0 then
    return jsonb_build_object(
      'periodo', per.periodo, 'posteado', false, 'ya_estaba', false, 'rehecho', v_rehecho, 'obras', coalesce((v_tot->>'obras')::int, 0),
      'fuera', v_fuera, 'excluidas', v_excl,
      'nota', case when v_rehecho is not null
                   then format('El ajuste anterior de %s (asiento %s) se deshizo, y hoy no hay nada que ajustar.', v_nom, v_rehecho->>'numero')
                   when coalesce((v_tot->>'obras')::int, 0) = 0
                   then format('En %s ninguna obra está lista para el ajuste%s.', v_nom,
                               case when jsonb_array_length(v_fuera) > 0
                                    then format(' (%s pendiente(s): les falta su revisión o lo de antes del libro)', jsonb_array_length(v_fuera))
                                    else '' end)
                   else format('En %s no hay nada que ajustar: en las %s obra(s) listas lo ganado es lo facturado, al centavo.', v_nom,
                               v_tot->>'obras') end
              || case when jsonb_array_length(v_excl) > 0
                      then format(' %s obra(s) quedaron fuera a propósito, con su nota.', jsonb_array_length(v_excl)) else '' end);
  end if;

  -- El reverso del día 1 cae en el mes siguiente: tiene que existir.
  if not exists (select 1 from periodos q where q.tipo = 'mes' and (per.hasta + 1) between q.desde and q.hasta) then
    raise exception using errcode = 'MX002',
      message = format('Falta abrir %s: el ajuste de %s se deshace solo el %s y ese mes todavía no existe en el libro. Ábrelo (select '
                       'fn_abrir_periodo(%L);) y vuelve a postear.', fn_wip_mes(to_char(per.hasta + 1, 'YYYY-MM')), v_nom,
                       fn_wip_dia(per.hasta + 1), to_char(per.hasta + 1, 'YYYY-MM'));
  end if;

  -- EL ASIENTO: por el camino de c2 para el dueño, reversible (nace con su
  -- reverso automático del día 1 del mes siguiente).
  v_res := fn_postear(jsonb_build_object(
    'fecha', to_char(per.hasta, 'YYYY-MM-DD'),
    'descripcion', format('Ajuste de WIP de %s por costo a costo (c12: %s obra(s): sub-facturado %s, sobre-facturado %s, pérdida %s; se '
                          'deshace solo el %s)', v_nom, v_tot->>'obras', fn_wip_usd((v_tot->>'sub_facturado')::numeric),
                          fn_wip_usd((v_tot->>'sobre_facturado')::numeric), fn_wip_usd((v_tot->>'perdida_provision')::numeric),
                          fn_wip_dia(per.hasta + 1)),
    'reversible', true,
    'lineas', v_plan->'lineas'));
  v_id := (v_res->>'id')::uuid;

  perform set_config('mx_wip.escribe', 'wip_ajustes', true);
  insert into wip_ajustes (id, periodo, asiento_id, numero, fecha, reverso_auto_id, obras, lineas, sub_facturado, sobre_facturado, perdida,
                           huella, sustituye_a, motivo, creado_por)
  values (v_aj, per.periodo, v_id, v_res->>'numero', per.hasta, (v_res->'reverso'->>'id')::uuid, (v_tot->>'obras')::int, v_nlin,
          (v_tot->>'sub_facturado')::numeric, (v_tot->>'sobre_facturado')::numeric, (v_tot->>'perdida_provision')::numeric,
          v_plan->>'huella', v_sust, nullif(btrim(p_motivo), ''), auth.uid());
  perform set_config('mx_wip.escribe', 'wip_ajuste_obras', true);
  insert into wip_ajuste_obras (ajuste_id, proyecto_id, n, obra, cliente, tipo, obra_estado, estado, falta, falta_texto, en_ajuste, terminada,
                                revision_id, antes_id, de_antes, precio_contrato, costo_estimado, utilidad_estimada, costo_libro,
                                costo_antes, costo_fecha, pct_avance, pct_real, pasa_de_100, ingreso_ganado, facturado_libro,
                                facturado_antes, facturado_fecha, sub_facturado, sobre_facturado, costo_para_terminar, utilidad_fecha,
                                perdida_total, perdida_provision, cuenta_ingreso, ingreso_otro, avisos)
  select v_aj, x.proyecto_id, t.n::int, x.obra, x.cliente, x.tipo, x.obra_estado, x.estado,
         coalesce((select array_agg(e) from jsonb_array_elements_text(x.falta) e), '{}'), x.falta_texto, x.en_ajuste, coalesce(x.terminada, false),
         x.revision_id, x.antes_id, coalesce(x.de_antes, false), x.precio_contrato, x.costo_estimado, x.utilidad_estimada, x.costo_libro,
         x.costo_antes, x.costo_fecha, x.pct_avance, x.pct_real, x.pasa_de_100, x.ingreso_ganado, x.facturado_libro,
         x.facturado_antes, x.facturado_fecha, x.sub_facturado, x.sobre_facturado, x.costo_para_terminar, x.utilidad_fecha,
         x.perdida_total, x.perdida_provision, x.cuenta_ingreso, x.ingreso_otro,
         coalesce((select array_agg(e) from jsonb_array_elements_text(x.avisos) e), '{}')
    from jsonb_array_elements(v_plan->'filas') with ordinality t(fila, n)
    cross join lateral jsonb_to_record(t.fila)
         as x(proyecto_id text, obra text, cliente text, tipo text, obra_estado text, estado text, falta jsonb, falta_texto text,
              en_ajuste boolean, terminada boolean, revision_id uuid, antes_id uuid, de_antes boolean, precio_contrato numeric,
              costo_estimado numeric, utilidad_estimada numeric, costo_libro numeric, costo_antes numeric, costo_fecha numeric,
              pct_avance numeric, pct_real numeric, pasa_de_100 boolean, ingreso_ganado numeric, facturado_libro numeric,
              facturado_antes numeric, facturado_fecha numeric, sub_facturado numeric, sobre_facturado numeric,
              costo_para_terminar numeric, utilidad_fecha numeric, perdida_total numeric, perdida_provision numeric,
              cuenta_ingreso text, ingreso_otro numeric, avisos jsonb);
  perform set_config('mx_wip.escribe', '', true);

  return jsonb_build_object(
    'periodo', per.periodo, 'posteado', true, 'ya_estaba', false, 'ajuste_id', v_aj, 'rehecho', v_rehecho,
    'asiento', jsonb_build_object('id', v_id, 'numero', v_res->>'numero', 'fecha', per.hasta),
    'reverso', jsonb_build_object('id', v_res->'reverso'->>'id', 'numero', v_res->'reverso'->>'numero',
                                  'fecha', v_res->'reverso'->>'fecha_contable'),
    'obras', (v_tot->>'obras')::int, 'lineas', v_nlin,
    'sub_facturado', (v_tot->>'sub_facturado')::numeric, 'sobre_facturado', (v_tot->>'sobre_facturado')::numeric,
    'perdida', (v_tot->>'perdida_provision')::numeric,
    'fuera', v_fuera, 'excluidas', v_excl,
    'nota', format('%s el ajuste de WIP de %s: asiento %s, con %s obra(s) (sub-facturado %s, sobre-facturado %s, pérdida %s). Se deshace '
                   'solo el %s (asiento %s).%s%s',
                   case when v_rehecho is not null then 'Rehecho' else 'Posteado' end, v_nom, v_res->>'numero', v_tot->>'obras',
                   fn_wip_usd((v_tot->>'sub_facturado')::numeric), fn_wip_usd((v_tot->>'sobre_facturado')::numeric),
                   fn_wip_usd((v_tot->>'perdida_provision')::numeric), fn_wip_dia(per.hasta + 1), v_res->'reverso'->>'numero',
                   case when jsonb_array_length(v_fuera) > 0
                        then format(' %s obra(s) no entraron: les falta su revisión o lo de antes del libro.', jsonb_array_length(v_fuera))
                        else '' end,
                   case when jsonb_array_length(v_excl) > 0
                        then format(' %s obra(s) quedaron fuera a propósito, con su nota.', jsonb_array_length(v_excl))
                        else '' end));
end $$;
revoke execute on function public.fn_wip_postear(text, text) from public, anon, service_role;
grant  execute on function public.fn_wip_postear(text, text) to authenticated;
comment on function public.fn_wip_postear(text, text) is 'c12: postea el ajuste de WIP de un mes abierto y ya terminado: UN asiento fechado su último día, por fn_postear como el dueño y reversible (nace con su reverso automático del día 1 del mes siguiente), con las obras listas: sub-facturada Dr 1200 / Cr su ingreso, sobre-facturada Dr su ingreso / Cr 2400, pérdida Dr 5950 / Cr 2410, cada línea con su obra. Idempotente: si el mes ya tiene su ajuste y sigue al día, lo devuelve (ya_estaba); si el WIP cambió después, lo rehace (reversa el anterior dentro de su mes con fn_reversar, que anula también su reverso del día 1, y postea el nuevo); si no hay nada que ajustar, no postea. Guarda el ajuste y la foto de cada obra. Devuelve el asiento, su reverso, los totales las obras que no entraron con su porqué (fuera) y las que Edgar dejó fuera ese mes a propósito (excluidas). Solo el dueño.';

-- DESHACER el ajuste de un mes abierto, sin poner otro: se reversa en su
-- fecha (c2 anula también su reverso del día 1) y queda marcado, con su
-- motivo. Si su asiento ya se había reversado por fuera, solo se anota.
create or replace function public.fn_wip_deshacer(p_periodo text, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  per      periodos;
  v_nom    text;
  a        wip_ajustes;
  v_ya     asientos;
  v_rev    jsonb;
  v_motivo text := nullif(btrim(p_motivo), '');
begin
  perform fn_wip_exigir_dueno();
  select * into per from periodos q where q.periodo = p_periodo;
  if not found or per.tipo <> 'mes' then
    raise exception using errcode = 'MX002', message = format('No existe el mes «%s» (va como AAAA-MM).', coalesce(p_periodo, ''));
  end if;
  v_nom := fn_wip_mes(per.periodo);
  if v_motivo is null then
    raise exception using errcode = '22023', message = 'Deshacer un ajuste de WIP pide su motivo: queda escrito en el reverso.';
  end if;
  if per.estado <> 'abierto' then
    raise exception using errcode = 'MX002',
      message = format('%s ya está cerrado: su ajuste de WIP ya se deshizo solo el día 1 y no hay nada que deshacer.',
                       initcap(left(v_nom, 1)) || substr(v_nom, 2));
  end if;
  perform pg_advisory_xact_lock(820261112, hashtext('ajuste:' || per.periodo));
  select * into a from wip_ajustes x where x.periodo = per.periodo and x.deshecho_el is null;
  if not found then
    raise exception using errcode = 'MX008', message = format('%s no tiene un ajuste de WIP vivo que deshacer.', initcap(left(v_nom, 1)) || substr(v_nom, 2));
  end if;
  select * into v_ya from asientos r where r.reversa_a = a.asiento_id and r.camino = 'reverso' order by r.cadena_pos limit 1;
  if v_ya.id is null then
    v_rev := fn_reversar(a.asiento_id, format('Ajuste de WIP de %s deshecho: %s', v_nom, v_motivo));
  end if;
  perform set_config('mx_wip.escribe', 'wip_ajustes', true);
  update wip_ajustes set deshecho_el = clock_timestamp(), deshecho_por = auth.uid(), deshecho_motivo = v_motivo,
                         reverso_id = coalesce(v_ya.id, (v_rev->>'id')::uuid), por_fuera = v_ya.id is not null
   where id = a.id;
  perform set_config('mx_wip.escribe', '', true);
  return jsonb_build_object(
    'periodo', per.periodo, 'ajuste_id', a.id, 'asiento', jsonb_build_object('id', a.asiento_id, 'numero', a.numero),
    'reverso', jsonb_build_object('id', coalesce(v_ya.id::text, v_rev->>'id'), 'numero', coalesce(v_ya.numero, v_rev->>'numero')),
    'anula_reverso_automatico', v_rev->'anula'->>'numero', 'por_fuera', v_ya.id is not null,
    'nota', case when v_ya.id is not null
                 then format('El asiento %s ya se había reversado en el libro (%s): el ajuste de %s queda anotado como deshecho.', a.numero,
                             v_ya.numero, v_nom)
                 else format('Deshecho el ajuste de WIP de %s: el asiento %s se reversó con %s, y su reverso del día 1 quedó anulado. El '
                             'libro vuelve a lo facturado.', v_nom, a.numero, v_rev->>'numero') end);
end $$;
revoke execute on function public.fn_wip_deshacer(text, text) from public, anon, service_role;
grant  execute on function public.fn_wip_deshacer(text, text) to authenticated;
comment on function public.fn_wip_deshacer(text, text) is 'c12: deshace el ajuste de WIP vivo de un mes abierto, con su motivo: lo reversa en su fecha por fn_reversar (c2 anula también su reverso automático del día 1) y lo marca deshecho. Si su asiento ya se había reversado por fuera, solo lo anota. No postea otro. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 8. EL RESUMEN DE UN MES para la pantalla: los totales (la pantalla no
--    suma dinero), cómo está el ajuste, las líneas que se postearían y qué
--    se puede hacer. Solo lee.
-- ---------------------------------------------------------------------
create or replace function public.fn_wip_resumen(p_periodo text default null) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  per      periodos;
  cfg      wip_config;
  a        wip_ajustes;
  v_per    text := coalesce(p_periodo, fn_wip_toca());
  v_hoy    date := fn_fecha_miami(now());
  v_nom    text;
  v_cerr   boolean;
  v_term   boolean;
  v_exig   boolean;
  v_plan   jsonb;
  v_est    jsonb;
  v_filas  jsonb;
  v_tot    jsonb;
  v_obras  jsonb;
  v_lin    jsonb;
  v_puede  boolean := false;
  v_porq   text;
begin
  perform fn_wip_exigir_dueno();
  select * into per from periodos q where q.periodo = v_per;
  if not found or per.tipo <> 'mes' then
    raise exception using errcode = 'MX002', message = format('No existe el mes «%s» (va como AAAA-MM).', coalesce(v_per, ''));
  end if;
  select * into cfg from wip_config where id = 1;
  v_nom  := fn_wip_mes(per.periodo);
  v_cerr := per.estado <> 'abierto';
  v_term := per.hasta < v_hoy;
  v_exig := cfg.exigir_desde is not null and per.periodo >= cfg.exigir_desde;
  if v_cerr then
    -- Un mes cerrado: la foto de su ajuste y las líneas de su asiento.
    select coalesce(jsonb_agg(to_jsonb(s) order by s.obra, s.proyecto_id), '[]'::jsonb) into v_filas from fn_wip_schedule(per.periodo) s;
    select * into a from wip_ajustes x where x.periodo = per.periodo and x.deshecho_el is null;
    if found then
      v_est := jsonb_build_object('vivo', true, 'id', a.id, 'asiento_id', a.asiento_id, 'numero', a.numero, 'fecha', a.fecha,
                                  'obras', a.obras, 'sub_facturado', a.sub_facturado, 'sobre_facturado', a.sobre_facturado,
                                  'perdida', a.perdida, 'creado_el', a.creado_el, 'creado_por', a.creado_por, 'al_dia', true,
                                  'por_fuera', false,
                                  'reverso_auto', (select jsonb_build_object('id', r.id, 'numero', r.numero, 'fecha', r.fecha_contable)
                                                     from asientos r where r.id = a.reverso_auto_id));
      select coalesce(jsonb_agg(jsonb_build_object('cuenta', l.cuenta, 'cuenta_nombre', cu.nombre, 'monto', l.monto,
                                                   'proyecto_id', l.proyecto_id, 'obra', pr.nombre, 'memo', l.memo) order by l.orden), '[]'::jsonb)
        into v_lin
        from asiento_lineas l
        left join cuentas cu on cu.codigo = l.cuenta
        left join proyectos pr on pr.id = l.proyecto_id
       where l.asiento_id = a.asiento_id;
    else
      v_est := jsonb_build_object('vivo', false, 'al_dia', true, 'por_fuera', false, 'lineas_hoy', 0);
      v_lin := '[]'::jsonb;
    end if;
    v_porq := format('%s ya está cerrado: su WIP es el que se posteó.', initcap(left(v_nom, 1)) || substr(v_nom, 2));
  else
    v_plan  := fn_wip_plan(per.periodo);
    v_est   := fn_wip_ajuste_estado(per.periodo, v_plan);
    v_filas := v_plan->'filas';
    select coalesce(jsonb_agg(jsonb_build_object('cuenta', x.cuenta, 'cuenta_nombre', cu.nombre, 'monto', x.monto::numeric,
                                                 'proyecto_id', x.proyecto_id, 'obra', pr.nombre, 'memo', x.memo) order by t.n), '[]'::jsonb)
      into v_lin
      from jsonb_array_elements(v_plan->'lineas') with ordinality t(l, n)
      cross join lateral jsonb_to_record(t.l) as x(cuenta text, monto text, proyecto_id text, memo text)
      left join cuentas cu on cu.codigo = x.cuenta
      left join proyectos pr on pr.id = x.proyecto_id;
    if not v_term then
      v_porq := format('%s todavía no termina (su último día es el %s): el ajuste se postea con el mes terminado.',
                       initcap(left(v_nom, 1)) || substr(v_nom, 2), fn_wip_dia(per.hasta));
    elsif (v_est->>'vivo')::boolean and (v_est->>'al_dia')::boolean then
      v_porq := format('El ajuste de %s ya está posteado y al día (asiento %s).', v_nom, v_est->>'numero');
    elsif not (v_est->>'vivo')::boolean and (v_est->>'lineas_hoy')::int = 0 then
      v_porq := format('En %s hoy no hay nada que ajustar.', v_nom);
    else
      v_puede := true;
    end if;
  end if;
  select jsonb_build_object(
           'total', count(*),
           'listas', count(*) filter (where x.estado = 'lista'),
           'pendientes', count(*) filter (where x.estado = 'pendiente'),
           'excluidas', count(*) filter (where x.estado = 'excluida'),
           'sin_movimiento', count(*) filter (where x.estado = 'sin_movimiento'),
           'por_revisar', count(*) filter (where x.estado = 'pendiente' and x.falta ? 'revision'),
           'por_confirmar_antes', count(*) filter (where x.estado = 'pendiente' and x.falta ? 'antes'),
           'sin_cuenta_ingreso', count(*) filter (where x.estado = 'pendiente' and x.falta ? 'cuenta_ingreso'),
           'por_precio', count(*) filter (where x.estado = 'pendiente' and x.falta ? 'precio'),
           'por_estimado', count(*) filter (where x.estado = 'pendiente' and x.falta ? 'estimado')),
         jsonb_build_object(
           'obras', count(*) filter (where x.en_ajuste),
           'precio_contrato', coalesce(sum(x.precio_contrato) filter (where x.en_ajuste), 0)::numeric(14,2),
           'costo_estimado', coalesce(sum(x.costo_estimado) filter (where x.en_ajuste), 0)::numeric(14,2),
           'utilidad_estimada', coalesce(sum(x.utilidad_estimada) filter (where x.en_ajuste), 0)::numeric(14,2),
           'costo_fecha', coalesce(sum(x.costo_fecha) filter (where x.en_ajuste), 0)::numeric(14,2),
           'ingreso_ganado', coalesce(sum(x.ingreso_ganado) filter (where x.en_ajuste), 0)::numeric(14,2),
           'facturado_fecha', coalesce(sum(x.facturado_fecha) filter (where x.en_ajuste), 0)::numeric(14,2),
           'sub_facturado', coalesce(sum(x.sub_facturado) filter (where x.en_ajuste), 0)::numeric(14,2),
           'sobre_facturado', coalesce(sum(x.sobre_facturado) filter (where x.en_ajuste), 0)::numeric(14,2),
           'costo_para_terminar', coalesce(sum(x.costo_para_terminar) filter (where x.en_ajuste), 0)::numeric(14,2),
           'utilidad_fecha', coalesce(sum(x.utilidad_fecha) filter (where x.en_ajuste), 0)::numeric(14,2),
           'perdida_total', coalesce(sum(x.perdida_total) filter (where x.en_ajuste), 0)::numeric(14,2),
           'perdida_provision', coalesce(sum(x.perdida_provision) filter (where x.en_ajuste), 0)::numeric(14,2),
           'pct_avance', case when coalesce(sum(x.precio_contrato) filter (where x.en_ajuste), 0) > 0
                              then round(100 * sum(x.ingreso_ganado) filter (where x.en_ajuste)
                                         / sum(x.precio_contrato) filter (where x.en_ajuste), 2) end)
    into v_obras, v_tot
    from jsonb_to_recordset(v_filas)
         as x(estado text, falta jsonb, en_ajuste boolean, precio_contrato numeric, costo_estimado numeric, utilidad_estimada numeric,
              costo_fecha numeric, ingreso_ganado numeric, facturado_fecha numeric, sub_facturado numeric, sobre_facturado numeric,
              costo_para_terminar numeric, utilidad_fecha numeric, perdida_total numeric, perdida_provision numeric);
  return jsonb_build_object(
    'periodo', per.periodo, 'nombre', v_nom, 'desde', per.desde, 'hasta', per.hasta,
    'cerrado', v_cerr, 'terminado', v_term, 'exigir_desde', cfg.exigir_desde, 'exigido', v_exig,
    'fuente', case when v_cerr then 'posteado' else 'calculado' end,
    'obras', v_obras, 'totales', v_tot, 'ajuste', v_est, 'lineas', v_lin,
    'reverso_fecha', per.hasta + 1,
    'puede_postear', v_puede, 'por_que_no', v_porq,
    'puede_deshacer', not v_cerr and coalesce((v_est->>'vivo')::boolean, false),
    'nota', case when v_cerr then v_porq
                 when (v_est->>'vivo')::boolean and coalesce((v_est->>'por_fuera')::boolean, false)
                   then format('El asiento del ajuste de %s (%s) se reversó en el libro por fuera de aquí: vuelve a postearlo (o deshazlo).',
                               v_nom, v_est->>'numero')
                 when (v_est->>'vivo')::boolean and not (v_est->>'al_dia')::boolean
                   then format('El ajuste posteado de %s (asiento %s) ya no es el de hoy: %s. Vuelve a postearlo: se reversa y entra el '
                               'nuevo.', v_nom, v_est->>'numero', coalesce(v_est->>'cambios', 'cambió su cálculo'))
                 when (v_obras->>'pendientes')::int > 0
                   then format('%s obra(s) no entran todavía: %s.%s', v_obras->>'pendientes',
                               concat_ws(', ',
                                 case when (v_obras->>'por_revisar')::int > 0 then (v_obras->>'por_revisar') || ' por revisar' end,
                                 case when (v_obras->>'por_confirmar_antes')::int > 0
                                      then (v_obras->>'por_confirmar_antes') || ' sin lo de antes del libro confirmado' end,
                                 case when (v_obras->>'sin_cuenta_ingreso')::int > 0
                                      then (v_obras->>'sin_cuenta_ingreso') || ' sin cuenta de ingreso' end,
                                 case when (v_obras->>'por_precio')::int > 0
                                      then (v_obras->>'por_precio') || ' con el contrato de la ficha cambiado después de revisarla' end,
                                 case when (v_obras->>'por_estimado')::int > 0
                                      then (v_obras->>'por_estimado') || ' con más costo que su estimado' end),
                               case when (v_obras->>'excluidas')::int > 0
                                    then format(' Y %s fuera a propósito, con su nota.', v_obras->>'excluidas') else '' end)
                 when (v_obras->>'excluidas')::int > 0 and v_porq is null
                   then format('%s obra(s) quedan fuera del WIP de %s a propósito, con su nota.', v_obras->>'excluidas', v_nom)
                 else v_porq end);
end $$;
revoke execute on function public.fn_wip_resumen(text) from public, anon, service_role;
grant  execute on function public.fn_wip_resumen(text) to authenticated;
comment on function public.fn_wip_resumen(text) is 'c12: el resumen del WIP de un mes para la pantalla (sin período, el mes que toca): si está cerrado, terminado y exigido; cuántas obras (listas, pendientes, excluidas a propósito, por revisar, sin lo de antes confirmado, con el contrato cambiado, con más costo que su estimado, sin movimiento); los totales de las obras listas (contrato, costo estimado, utilidad, costo a la fecha, ganado, facturado, sub y sobre-facturado, costo para terminar, pérdida y provisión; la pantalla no suma); cómo está el ajuste (posteado, al día, qué cambió); las líneas que se postearían hoy (o las posteadas, en un mes cerrado), con el nombre de la cuenta y de la obra; y si se puede postear o deshacer, con el porqué. Solo lee. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 9. EL CONTROL DEL WIP (cabecera, punto 8) y sus cuatro filas para el
--    cierre. fn_wip_control(periodo): siempre las mismas filas (orden,
--    cuadre, nivel, ok, detalle en llano); sin período, el mes que toca. Lo
--    que solo tiene sentido en un mes abierto dice «no aplica» en verde en
--    un mes cerrado, en la apertura o en un año. Lo «exigible» (40 y 50)
--    está en verde, diciendo cuánto falta, mientras el mes no se exija
--    (wip_config.exigir_desde) o no haya terminado; un ajuste ya posteado
--    que dejó de estar al día está en rojo siempre. Solo lectura; a quien no
--    es el dueño, nada.
-- ---------------------------------------------------------------------
drop function if exists public.fn_wip_control(text);
create function public.fn_wip_control(p_periodo text default null)
returns table (orden int, cuadre text, nivel text, ok boolean, detalle text)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  per        periodos;
  cfg        wip_config;
  v_per      text := coalesce(p_periodo, fn_wip_toca());
  v_hoy      date := fn_fecha_miami(now());
  v_mes      boolean := false;   -- es un mes
  v_vivo     boolean := false;   -- es un mes abierto: se calcula
  v_nom      text;
  v_mnom     text;
  v_exige    boolean := false;
  v_termino  boolean := false;
  v_cuando   text;
  v_plan     jsonb;
  v_est      jsonb := '{}'::jsonb;
  v_filas    jsonb := '[]'::jsonb;
  v_tot      jsonb := '{}'::jsonb;
  v_noaplica text;
  v_n        bigint;
  v_n2       bigint;
  v_n3       bigint;
  v_t        text;
  v_t2       text;
  v_t3       text;
  v_j        jsonb;
  v_pend_n   bigint := 0;
  v_pend_t   text;
  v_excl_n   bigint := 0;
  v_excl_t   text;
  v_horas_n  bigint := 0;
  v_horas_ok boolean := true;
  v_horas_det text;
  v_suf      text;
begin
  if not fn_wip_ve() then
    return;
  end if;
  select * into cfg from wip_config where id = 1;
  select * into per from periodos q where q.periodo = v_per;
  if found then
    v_mes  := per.tipo = 'mes';
    v_vivo := v_mes and per.estado = 'abierto';
  end if;
  v_nom  := case when v_mes then fn_wip_mes(per.periodo) else coalesce(v_per, 'ese período') end;
  v_mnom := initcap(left(v_nom, 1)) || substr(v_nom, 2);
  v_noaplica := case when per.periodo is null then 'No aplica: ese período no existe.'
                     when not v_mes then 'No aplica: el WIP va por mes (esto es ' || case per.tipo when 'apertura' then 'la apertura' else 'un año' end || ').'
                     else format('No aplica: %s ya está cerrado; su WIP es el que se posteó.', v_nom) end;
  if v_vivo then
    v_exige   := cfg.exigir_desde is not null and per.periodo >= cfg.exigir_desde;
    v_termino := per.hasta < v_hoy;
    v_cuando  := case when not v_exige and cfg.exigir_desde is null
                        then format('En %s el WIP todavía no se exige para cerrar (no se ha dicho desde qué mes).', v_nom)
                      when not v_exige
                        then format('En %s el WIP todavía no se exige para cerrar (se exige desde %s).', v_nom, fn_wip_mes(cfg.exigir_desde))
                      when not v_termino
                        then format('%s termina el %s: se hace al cerrar el mes.', v_mnom, fn_wip_dia(per.hasta)) end;
    v_plan  := fn_wip_plan(per.periodo);
    v_est   := fn_wip_ajuste_estado(per.periodo, v_plan);
    v_filas := v_plan->'filas';
    v_tot   := v_plan->'totales';
    -- LO QUE QUEDA FUERA DEL AJUSTE, para decirlo donde se postea y donde se
    -- cierra (la fila 176): las pendientes (les falta algo), las excluidas a
    -- propósito (con su nota) y las que tienen horas sin costo en el libro
    -- (su avance va corto).
    select count(*) filter (where s.estado = 'pendiente'),
           left(string_agg(s.obra, ', ' order by s.obra) filter (where s.estado = 'pendiente'), 400),
           count(*) filter (where s.estado = 'excluida'),
           left(string_agg(format('%s («%s»)', s.obra, left(coalesce(s.revision_nota, 'sin nota'), 120)), '; ' order by s.obra)
                  filter (where s.estado = 'excluida'), 500)
      into v_pend_n, v_pend_t, v_excl_n, v_excl_t
      from jsonb_to_recordset(v_filas) as s(obra text, estado text, revision_nota text);
    if to_regprocedure('public.fn_margen_obras(text)') is null then
      v_horas_ok := true;
      v_horas_det := 'El costo por obra (c10) no está en esta base: no se sabe qué horas siguen sin costo en el libro.';
    else
      begin
        execute 'select coalesce(jsonb_object_agg(o.proyecto_id, jsonb_build_object(''h'', o.horas_estandar, ''m'', o.mano_obra_estandar)), '
             || '''{}''::jsonb) from public.fn_margen_obras(null) o where o.horas_estandar > 0'
           into v_j;
        select count(*), left(string_agg(format('%s (%s h%s)', s.obra, trim_scale((v_j->s.proyecto_id->>'h')::numeric),
                                                case when (v_j->s.proyecto_id->>'m') is null then ''
                                                     else ', ' || fn_wip_usd((v_j->s.proyecto_id->>'m')::numeric) || ' a estándar' end),
                                         '; ' order by s.obra), 900)
          into v_horas_n, v_t
          from jsonb_to_recordset(v_filas) as s(proyecto_id text, obra text, estado text)
         where s.estado <> 'sin_movimiento' and v_j ? s.proyecto_id;
        v_horas_ok := v_horas_n = 0;
        v_horas_det := case when v_horas_n = 0 then 'Ninguna obra del WIP tiene hoy horas sin costo en el libro.'
                            else format('%s obra(s) del WIP tienen hoy horas reportadas que no están en el libro (sin pago repartido): %s. Su '
                                        'costo a la fecha va corto y su avance también. Reparte los pagos de mano de obra pendientes.',
                                        v_horas_n, v_t) end;
      exception when others then
        v_horas_ok := true; v_horas_n := 0;
        v_horas_det := format('No se pudo leer el costo por obra (c10) para ver las horas sin costo: %s.', sqlerrm);
      end;
    end if;
    -- (lo que se añade al texto del ajuste del mes: quién quedó fuera y por qué)
    v_suf := concat_ws(' ',
               case when v_pend_n > 0
                    then format('OJO: %s obra(s) NO entran en el ajuste porque les falta algo (%s): su ingreso de %s se queda en lo '
                                'facturado hasta que se arregle.', v_pend_n, v_pend_t, v_nom) end,
               case when v_excl_n > 0
                    then format('Fuera del ajuste a propósito, %s obra(s): %s.', v_excl_n, v_excl_t) end,
               case when v_horas_n > 0
                    then format('Y %s obra(s) tienen horas sin costo en el libro: su avance va corto.', v_horas_n) end);
  end if;

  -- 10. En 1200, 2400, 2410 y 5950 solo están los ajustes del WIP: lo que no
  --     es de un ajuste (ni su reverso) no deja saldo, cuenta por cuenta y
  --     obra por obra. Todo el libro. Si el saldo viene de la APERTURA (el WIP
  --     que traía QuickBooks al 30-sep), se dice con su porqué: esta capa no
  --     lo continúa sola (cabecera, «Una apertura con saldo…»).
  select count(*), left(string_agg(format('%s en la %s%s%s', fn_wip_usd(x.saldo), x.cuenta, coalesce(' de ' || x.obra, ' sin obra'),
                                          case when x.de_apertura then ' (viene de la apertura)' else '' end),
                                   '; ' order by x.cuenta, x.obra), 900),
         count(*) filter (where x.de_apertura)
    into v_n, v_t, v_n2
    from (select l.cuenta, pr.nombre as obra, sum(l.monto) as saldo, bool_or(a.tipo = 'apertura') as de_apertura
            from asiento_lineas l
            join asientos a on a.id = l.asiento_id
            left join proyectos pr on pr.id = l.proyecto_id
           where l.cuenta in ('1200', '2400', '2410', '5950')
             and not exists (select 1 from fn_wip_asientos() w where w.asiento_id = l.asiento_id)
           group by l.cuenta, l.proyecto_id, pr.nombre
          having sum(l.monto) <> 0) x;
  orden := 10; cuadre := 'wip: en las cuentas del WIP solo está el ajuste del mes'; nivel := 'cuadre'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'En las cuentas del WIP (sub-facturado, sobre-facturado, la provisión por pérdida y su gasto) no hay '
                                    'más saldo que el de los ajustes del WIP.'
                  else format('Hay saldo en las cuentas del WIP que no viene de un ajuste: %s. Esas cuentas las lleva el ajuste del mes: '
                              'si es un asiento a mano, revérsalo; si lo pidió el contador (un saldo inicial), avisa antes de cerrar.%s', v_t,
                              case when v_n2 > 0
                                   then ' Lo que viene de la apertura es el WIP que traía QuickBooks al 30 de septiembre: el ajuste de cada '
                                        'mes ya lleva el sobre y sub-facturado acumulado desde el inicio de cada obra, y con ese saldo '
                                        'quedaría dos veces. Se decide con el contador: que la apertura entre sin WIP (contra utilidades '
                                        'retenidas), o que el ajuste descuente lo que la apertura ya trae (avisa: es un cambio de esta capa).'
                                   else '' end) end;
  return next;

  -- 20. Cada ajuste vivo es su asiento (no se reversó por fuera; sus líneas
  --     son las de su foto, cuenta por cuenta y obra por obra), y el saldo de
  --     1200, 2400 y 2410 por obra al último día del mes es el del ajuste
  --     vivo de ese mes (cero si no hay).
  select count(*), string_agg(format('el de %s (asiento %s)', fn_wip_mes(a.periodo), a.numero), ', ' order by a.periodo)
    into v_n, v_t
    from wip_ajustes a
   where a.deshecho_el is null
     and exists (select 1 from asientos r where r.reversa_a = a.asiento_id and r.camino = 'reverso');
  select count(*), left(string_agg(format('%s, %s%s: en el libro %s y en el ajuste %s', fn_wip_mes(d.periodo), d.cuenta,
                                          coalesce(' de ' || pr.nombre, ''), fn_wip_usd(d.libro), fn_wip_usd(d.foto)),
                                   '; ' order by d.periodo, d.cuenta), 700)
    into v_n2, v_t2
    from (select coalesce(e.periodo, s.periodo) as periodo, coalesce(e.cuenta, s.cuenta) as cuenta,
                 coalesce(e.proyecto_id, s.proyecto_id) as proyecto_id, coalesce(e.monto, 0) as libro, coalesce(s.monto, 0) as foto
            from (select a.id, a.periodo, l.cuenta, l.proyecto_id, sum(l.monto) as monto
                    from wip_ajustes a join asiento_lineas l on l.asiento_id = a.asiento_id
                   where a.deshecho_el is null
                   group by a.id, a.periodo, l.cuenta, l.proyecto_id) e
            full join
                 (select a.id, a.periodo, y.cuenta, w.proyecto_id, sum(y.monto) as monto
                    from wip_ajustes a
                    join wip_ajuste_obras w on w.ajuste_id = a.id and w.en_ajuste
                    cross join lateral (values ('1200', w.sub_facturado), (w.cuenta_ingreso, w.sobre_facturado - w.sub_facturado),
                                               ('2400', -w.sobre_facturado), ('5950', w.perdida_provision),
                                               ('2410', -w.perdida_provision)) y(cuenta, monto)
                   where a.deshecho_el is null and y.monto <> 0
                   group by a.id, a.periodo, y.cuenta, w.proyecto_id) s
              on s.id = e.id and s.cuenta = e.cuenta and s.proyecto_id is not distinct from e.proyecto_id
           where coalesce(e.monto, 0) <> coalesce(s.monto, 0)) d
    left join proyectos pr on pr.id = d.proyecto_id;
  v_n3 := 0; v_t3 := null;
  if v_mes then
    select count(*), left(string_agg(format('%s%s: saldo %s al %s y el ajuste dice %s', d.cuenta, coalesce(' de ' || pr.nombre, ''),
                                            fn_wip_usd(d.libro), fn_wip_dia(per.hasta), fn_wip_usd(d.esperado)), '; ' order by d.cuenta), 700)
      into v_n3, v_t3
      from (select coalesce(m.cuenta, s.cuenta) as cuenta, coalesce(m.proyecto_id, s.proyecto_id) as proyecto_id,
                   coalesce(m.saldo, 0) as libro, coalesce(s.monto, 0) as esperado
              from (select l.cuenta, l.proyecto_id, sum(l.monto) as saldo
                      from asiento_lineas l join asientos x on x.id = l.asiento_id
                     where l.cuenta in ('1200', '2400', '2410') and x.fecha_contable <= per.hasta
                     group by l.cuenta, l.proyecto_id
                    having sum(l.monto) <> 0) m
              full join
                   (select y.cuenta, w.proyecto_id, sum(y.monto) as monto
                      from wip_ajustes a
                      join wip_ajuste_obras w on w.ajuste_id = a.id and w.en_ajuste
                      cross join lateral (values ('1200', w.sub_facturado), ('2400', -w.sobre_facturado),
                                                 ('2410', -w.perdida_provision)) y(cuenta, monto)
                     where a.periodo = per.periodo and a.deshecho_el is null and y.monto <> 0
                     group by y.cuenta, w.proyecto_id) s
                on s.cuenta = m.cuenta and s.proyecto_id is not distinct from m.proyecto_id
             where coalesce(m.saldo, 0) <> coalesce(s.monto, 0)) d
      left join proyectos pr on pr.id = d.proyecto_id;
  end if;
  orden := 20; cuadre := 'wip: cada ajuste es su asiento, y el saldo por obra es el del ajuste'; nivel := 'cuadre';
  ok := v_n = 0 and v_n2 = 0 and v_n3 = 0;
  detalle := case when v_n = 0 and v_n2 = 0 and v_n3 = 0
                  then format('%s ajuste(s) vivo(s), cada uno con su asiento vivo y sus líneas iguales a su foto%s.',
                              (select count(*) from wip_ajustes a where a.deshecho_el is null),
                              case when v_mes then format('; y al %s el saldo por obra de sub-facturado, sobre-facturado y provisión es el '
                                                          'de su ajuste', fn_wip_dia(per.hasta)) else '' end)
                  else concat_ws(' ',
                         case when v_n > 0 then format('El asiento de un ajuste que figura vivo se reversó en el libro por fuera de aquí: '
                                                       '%s. Vuelve a postear el ajuste de ese mes (o deshazlo).', v_t) end,
                         case when v_n2 > 0 then format('Un ajuste no es su asiento: %s. Avisa: no toques el libro.', v_t2) end,
                         case when v_n3 > 0 then format('El saldo por obra no es el del ajuste de %s: %s.', v_nom, v_t3) end) end;
  return next;

  -- 30. Lo facturado a la fecha = las facturas del libro: por obra del WIP,
  --     el ingreso de los asientos del puente de facturas y de sus notas de
  --     crédito hasta el último día del mes, contra las facturas
  --     contabilizadas menos las anuladas con su nota de crédito (por la
  --     fecha de su asiento).
  orden := 30; cuadre := 'wip: lo facturado a la fecha = las facturas del libro'; nivel := 'cuadre';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*), left(string_agg(format('%s: el libro dice %s y sus facturas %s', s.obra, fn_wip_usd(s.facturado_libro),
                                            fn_wip_usd(coalesce(dc.monto, 0) - coalesce(nc.monto, 0))), '; ' order by s.obra), 900)
      into v_n, v_t
      from jsonb_to_recordset(v_filas) as s(proyecto_id text, obra text, facturado_libro numeric)
      left join (select f.proyecto_id, sum(round(f.monto, 2)) as monto
                   from facturas f join asientos x on x.id = f.contabilizado_en
                  where x.fecha_contable <= per.hasta
                  group by f.proyecto_id) dc on dc.proyecto_id = s.proyecto_id
      left join (select f.proyecto_id, sum(round(f.monto, 2)) as monto
                   from notas_credito n
                   join facturas f on f.id = n.anula_a
                   join asientos x on x.id = n.contabilizado_en
                  where x.fecha_contable <= per.hasta
                  group by f.proyecto_id) nc on nc.proyecto_id = s.proyecto_id
     where s.facturado_libro <> coalesce(dc.monto, 0) - coalesce(nc.monto, 0);
    ok := v_n = 0;
    detalle := case when v_n = 0
                    then format('En las %s obra(s) del WIP de %s, lo facturado que usa el WIP es lo que dicen sus facturas en el libro '
                                '(las anuladas, con su nota de crédito restando), sin los ajustes.', jsonb_array_length(v_filas), v_nom)
                    else format('En %s obra(s) lo facturado del libro no es lo que dicen sus facturas: %s. Mira los puentes: una factura '
                                'cuyo asiento se reversó o cambió.', v_n, v_t) end;
  end if;
  return next;

  -- 40. Cada obra que entra en el mes, DECIDIDA: con su costo estimado
  --     revisado (y lo de antes del libro confirmado si ya andaba, su tipo
  --     con cuenta de ingreso, y el contrato de su ficha sin cambiar desde
  --     que se revisó), o excluida a propósito con su nota. Aquí cae también
  --     la obra que traía saldo del ajuste anterior: entra aunque la app ya
  --     no la tenga activa, y no sale sin esa decisión. Exigible. (La que
  --     lleva más costo que su estimado tiene su cuadre, el 60.)
  orden := 40; cuadre := 'wip: cada obra con su costo estimado revisado en el mes'; nivel := 'cuadre';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*) filter (where s.estado <> 'sin_movimiento'),
           count(*) filter (where s.estado = 'pendiente' and s.falta ?| array['revision', 'antes', 'cuenta_ingreso', 'precio']),
           left(string_agg(s.obra || coalesce(' (' || nullif(concat_ws(', ',
                             case when s.falta ? 'antes' then 'falta confirmar lo de antes del libro' end,
                             case when s.falta ? 'cuenta_ingreso' then 'su tipo no tiene cuenta de ingreso confirmada' end,
                             case when s.falta ? 'precio' then 'el contrato de su ficha cambió después de revisarla' end), '') || ')', ''),
                           ', ' order by s.obra)
                  filter (where s.estado = 'pendiente' and s.falta ?| array['revision', 'antes', 'cuenta_ingreso', 'precio']), 900)
      into v_n, v_n2, v_t
      from jsonb_to_recordset(v_filas) as s(obra text, estado text, falta jsonb);
    -- LA RED: una obra que traía sub, sobre o provisión en el último ajuste
    -- vivo de un mes anterior, que no se excluyó después, y que hoy no está
    -- entre las filas del mes. No debe pasar (entra sola); si pasa, detiene.
    select count(*), left(string_agg(coalesce(w.obra, w.proyecto_id), ', ' order by w.obra), 400)
      into v_n3, v_t3
      from (select a.id, q.desde from wip_ajustes a join periodos q on q.periodo = a.periodo
             where a.deshecho_el is null and q.desde < per.desde order by q.desde desc limit 1) u
      join wip_ajuste_obras w on w.ajuste_id = u.id
     where w.en_ajuste and (w.sub_facturado <> 0 or w.sobre_facturado <> 0 or w.perdida_provision <> 0)
       and not exists (select 1 from jsonb_to_recordset(v_filas) as s(proyecto_id text) where s.proyecto_id = w.proyecto_id)
       and not exists (select 1 from wip_revisiones r join periodos q on q.periodo = r.periodo
                        where r.proyecto_id = w.proyecto_id and r.sustituida_el is null and r.excluida
                          and q.desde >= u.desde and q.desde < per.desde);
    ok := (v_n2 = 0 or v_cuando is not null) and v_n3 = 0;
    detalle := case when v_n3 > 0
                    then format('%s obra(s) traían saldo del WIP en el ajuste anterior y no están en el WIP de %s: %s. Ninguna obra con '
                                'saldo sale sola: avisa antes de cerrar.', v_n3, v_nom, v_t3)
                    when v_n = 0 then format('En %s no hay obras de precio fijo con movimiento.', v_nom)
                    when v_n2 = 0 then format('Las %s obra(s) de precio fijo con movimiento tienen su costo estimado revisado en %s%s.', v_n,
                                              v_nom, case when v_excl_n > 0
                                                          then format(' (%s de ellas, fuera a propósito con su nota)', v_excl_n) else '' end)
                    when v_cuando is not null then format('%s Hoy faltan por revisar %s de %s: %s.', v_cuando, v_n2, v_n, v_t)
                    else format('Faltan por revisar %s de las %s obra(s) de precio fijo con movimiento en %s: %s.', v_n2, v_n, v_nom, v_t) end;
  end if;
  return next;

  -- 50. El ajuste del mes, posteado y al día. Exigible; pero un ajuste ya
  --     posteado que dejó de estar al día está en rojo siempre. El texto dice
  --     SIEMPRE quién quedó fuera del ajuste y por qué (las que no entran
  --     porque les falta algo, las excluidas a propósito con su nota, y las
  --     que tienen horas sin costo en el libro).
  orden := 50; cuadre := 'wip: el ajuste del mes posteado y al día'; nivel := 'cuadre';
  if not v_vivo then
    ok := true;
    detalle := case when v_mes and per.estado <> 'abierto'
                    then coalesce((select format('%s está cerrado con su ajuste de WIP (asiento %s): sub-facturado %s, sobre-facturado %s, '
                                                 'pérdida %s.', v_mnom, a.numero, fn_wip_usd(a.sub_facturado),
                                                 fn_wip_usd(a.sobre_facturado), fn_wip_usd(a.perdida))
                                     from wip_ajustes a where a.periodo = per.periodo and a.deshecho_el is null),
                                  format('%s está cerrado sin ajuste de WIP.', v_mnom))
                    else v_noaplica end;
  elsif (v_est->>'vivo')::boolean and (v_est->>'por_fuera')::boolean then
    ok := false;
    detalle := format('El asiento del ajuste de %s (%s) se reversó en el libro por fuera de aquí: el mes quedó sin su ajuste. Vuelve a '
                      'postearlo.', v_nom, v_est->>'numero');
  elsif (v_est->>'vivo')::boolean and (v_est->>'al_dia')::boolean then
    ok := true;
    detalle := concat_ws(' ',
                 format('El ajuste de %s está posteado y al día (asiento %s, del %s; se deshace solo el %s): sub-facturado %s, '
                        'sobre-facturado %s y pérdida %s, en %s obra(s).', v_nom, v_est->>'numero', fn_wip_dia(per.hasta),
                        fn_wip_dia(per.hasta + 1), fn_wip_usd((v_est->>'sub_facturado')::numeric),
                        fn_wip_usd((v_est->>'sobre_facturado')::numeric), fn_wip_usd((v_est->>'perdida')::numeric), v_est->>'obras'),
                 nullif(v_suf, ''));
  elsif (v_est->>'vivo')::boolean then
    ok := false;
    detalle := format('El ajuste posteado de %s (asiento %s) ya no es el que da el WIP de hoy: %s. Vuelve a postearlo: se reversa y '
                      'entra el nuevo.', v_nom, v_est->>'numero', coalesce(v_est->>'cambios', 'cambió su cálculo'));
  elsif (v_est->>'lineas_hoy')::int = 0 then
    ok := true;
    detalle := concat_ws(' ',
                 case when coalesce((v_tot->>'obras')::int, 0) = 0
                      then format('En %s no hay ninguna obra lista para el ajuste: nada que postear.', v_nom)
                      else format('En %s no hay nada que ajustar: en las %s obra(s) listas lo ganado es lo facturado.', v_nom, v_tot->>'obras') end,
                 nullif(v_suf, ''));
  else
    ok := v_cuando is not null;
    detalle := concat_ws(' ',
                 format('%s el ajuste de WIP de %s: sub-facturado %s en %s obra(s), sobre-facturado %s en %s, y pérdida por reconocer %s.',
                        case when v_cuando is not null then v_cuando || ' Hoy daría' else 'Falta postear' end, v_nom,
                        fn_wip_usd((v_tot->>'sub_facturado')::numeric), v_tot->>'obras_sub',
                        fn_wip_usd((v_tot->>'sobre_facturado')::numeric), v_tot->>'obras_sobre',
                        fn_wip_usd((v_tot->>'perdida_provision')::numeric)),
                 nullif(v_suf, ''));
  end if;
  return next;

  -- 60. Ninguna obra con más costo que su costo estimado revisado sin estar
  --     terminada. Sin excepción por nota: más costo que el estimado es un
  --     estimado viejo (esa obra no entra en el ajuste hasta subirlo o
  --     marcarla terminada: con el avance topado en 100 % ganaría el precio
  --     entero sin haber terminado).
  orden := 60; cuadre := 'wip: ninguna obra con más costo que su estimado revisado'; nivel := 'cuadre';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*), left(string_agg(format('%s (lleva %s y su estimado es %s: %s %%)', s.obra, fn_wip_usd(s.costo_fecha),
                                            fn_wip_usd(s.costo_estimado), trim_scale(s.pct_real)), '; ' order by s.obra), 900)
      into v_n, v_t
      from jsonb_to_recordset(v_filas)
           as s(obra text, pasa_de_100 boolean, costo_fecha numeric, costo_estimado numeric, pct_real numeric)
     where s.pasa_de_100;
    ok := v_n = 0;
    detalle := case when v_n = 0 then format('En %s ninguna obra lleva más costo que su costo estimado revisado.', v_nom)
                    else format('%s obra(s) llevan más costo que su costo estimado revisado y no están terminadas: %s. Ese estimado '
                                'quedó viejo: no entran en el ajuste hasta que lo subas (el costo total no puede ser menos de lo que ya '
                                'llevan) o las marques terminadas.', v_n, v_t) end;
  end if;
  return next;

  -- 90. Las protecciones de la capa: nada SECURITY DEFINER, nada para anon
  --     ni service_role, las internas sin API, RLS con su policy del dueño,
  --     nadie borra, las vistas security_invoker y las guardas encendidas.
  select count(*), left(string_agg(y.que, '; ' order by y.que), 900)
    into v_n, v_t
    from (with fx as (select p.oid, p.proname as nombre, p.prosecdef
                        from pg_catalog.pg_proc p
                       where p.pronamespace = 'public'::regnamespace
                         and p.proname in ('fn_wip_precondiciones', 'fn_wip_exigir_dueno', 'fn_wip_ve', 'fn_wip_guarda', 'fn_wip_usd',
                                           'fn_wip_mes', 'fn_wip_dia', 'fn_wip_monto', 'fn_wip_libro_desde', 'fn_wip_toca', 'fn_wip_meses',
                                           'fn_wip_asientos', 'fn_wip_obras', 'fn_wip_libro', 'fn_wip_calcular', 'fn_wip_schedule',
                                           'fn_wip_plan', 'fn_wip_ajuste_estado', 'fn_wip_resumen', 'fn_wip_antes_propuesta',
                                           'fn_wip_antes', 'fn_wip_obra', 'fn_wip_config', 'fn_wip_revisar', 'fn_wip_postear',
                                           'fn_wip_deshacer', 'fn_wip_control', 'fn_wip_cierre', 'fn_wip_pegado')),
               tb as (select c.oid, c.relname, c.relkind, c.relrowsecurity, c.reloptions
                        from pg_catalog.pg_class c
                       where c.relnamespace = 'public'::regnamespace
                         and c.relname in ('wip_config', 'wip_obras', 'wip_antes', 'wip_revisiones', 'wip_ajustes', 'wip_ajuste_obras',
                                           'v_wip_obras', 'v_wip_schedule', 'v_wip_control', 'v_wip_ajustes', 'v_wip_revisiones'))
          select fx.nombre || ' es SECURITY DEFINER' as que from fx where fx.prosecdef
          union all
          select format('%s la puede ejecutar %s', fx.nombre, g.r)
            from fx cross join (values ('anon'), ('service_role')) g(r)
           where has_function_privilege(g.r, fx.oid, 'execute')
          union all
          select fx.nombre || ' la puede ejecutar authenticated'
            from fx
           where fx.nombre in ('fn_wip_precondiciones', 'fn_wip_guarda', 'fn_wip_pegado')
             and has_function_privilege('authenticated', fx.oid, 'execute')
          union all
          select tb.relname || case when not tb.relrowsecurity then ' sin RLS' else ' sin su policy de lectura del dueño' end
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
          select format('authenticated puede %s en %s', q.q, tb.relname)
            from tb cross join (values ('DELETE'), ('TRUNCATE')) q(q)
           where tb.relkind = 'r' and has_table_privilege('authenticated', tb.oid, q.q)
          union all
          select tb.relname || ' sin security_invoker'
            from tb
           where tb.relkind = 'v'
             and not coalesce((select o.option_value::boolean from pg_options_to_table(tb.reloptions) o
                                where o.option_name = 'security_invoker'), false)
          union all
          select format('la guarda %s de %s %s', x.tg, x.t,
                        case when tg.oid is null then 'no está' when tg.tgenabled not in ('O', 'A') then 'está apagada'
                             else 'tiene otra función' end)
            from (select t.t, 'trg_' || t.t || s.s as tg
                    from (values ('wip_config'), ('wip_obras'), ('wip_antes'), ('wip_revisiones'), ('wip_ajustes'),
                                 ('wip_ajuste_obras')) t(t)
                    cross join (values ('_guarda'), ('_sin_truncate')) s(s)) x
            left join pg_catalog.pg_trigger tg on tg.tgrelid = to_regclass('public.' || x.t) and tg.tgname = x.tg
           where tg.oid is null or tg.tgenabled not in ('O', 'A')
              or tg.tgfoid is distinct from to_regprocedure('public.fn_wip_guarda()')) y;
  orden := 90; cuadre := 'wip: las protecciones de la capa'; nivel := 'cuadre'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Nada del WIP corre con permisos de más, nada es para la llave pública ni la de servicio, las tablas '
                                    'tienen su candado de solo-dueño y sus guardas encendidas, y las vistas leen con los permisos de quien mira.'
                  else format('Las protecciones del WIP no están como se pegaron: %s. Vuelve a pegar el archivo del WIP (c12).', v_t) end;
  return next;

  -- ------------------------------ LOS AVISOS ------------------------------
  -- 110. Obras que ya andaban antes del libro, sin lo de antes confirmado:
  --      no entran en el ajuste (y el cuadre 40 detiene el cierre del mes
  --      hasta que se confirme, o se excluyan ese mes con su nota).
  orden := 110; cuadre := 'wip: obras que ya andaban sin lo de antes confirmado'; nivel := 'aviso';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*), left(string_agg(s.obra || case when s.estado = 'excluida' then ' (fuera este mes, con su nota)' else '' end,
                                     ', ' order by s.obra), 900)
      into v_n, v_t
      from jsonb_to_recordset(v_filas) as s(obra text, estado text, falta jsonb, de_antes boolean, antes_confirmado boolean)
     where (s.estado = 'pendiente' and s.falta ? 'antes') or (s.estado = 'excluida' and s.de_antes and not s.antes_confirmado);
    ok := v_n = 0;
    detalle := case when v_n = 0 then format('En %s ninguna obra del WIP espera que se confirme lo de antes del libro.', v_nom)
                    else format('%s obra(s) ya andaban antes del libro y no tienen confirmado su costo y lo facturado de antes: %s. Mientras '
                                'tanto NO entran en el ajuste de %s (su ingreso sigue siendo lo facturado), y un mes que exige el WIP no '
                                'cierra hasta que se confirme (una vez por obra) o se deje fuera ese mes con su nota.',
                                v_n, v_t, v_nom) end;
  end if;
  return next;

  -- 120. Obras con pérdida (el costo estimado pasa del precio).
  orden := 120; cuadre := 'wip: obras con pérdida'; nivel := 'aviso';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*), left(string_agg(format('%s (pérdida %s; provisionado %s)', s.obra, fn_wip_usd(s.perdida_total),
                                            fn_wip_usd(s.perdida_provision)), '; ' order by s.obra), 900)
      into v_n, v_t
      from jsonb_to_recordset(v_filas) as s(obra text, en_ajuste boolean, perdida_total numeric, perdida_provision numeric)
     where s.en_ajuste and s.perdida_total > 0;
    ok := v_n = 0;
    detalle := case when v_n = 0 then format('En %s ninguna obra del WIP va con pérdida.', v_nom)
                    else format('%s obra(s) van con pérdida en %s: %s. La pérdida completa queda reconocida este mes.', v_n, v_nom, v_t) end;
  end if;
  return next;

  -- 125. Obras al 100 % sin estar terminadas: llevan justo su costo estimado
  --      (las que lo pasan están en el cuadre 60). Con eso se gana el precio
  --      entero: si les falta trabajo, el estimado tiene que ser mayor.
  orden := 125; cuadre := 'wip: obras al 100 % sin estar terminadas'; nivel := 'aviso';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*), left(string_agg(format('%s (lleva %s, justo su estimado)', s.obra, fn_wip_usd(s.costo_fecha)), '; ' order by s.obra), 900)
      into v_n, v_t
      from jsonb_to_recordset(v_filas) as s(obra text, en_ajuste boolean, terminada boolean, pct_real numeric, costo_fecha numeric)
     where s.en_ajuste and not s.terminada and s.pct_real >= 100;
    ok := v_n = 0;
    detalle := case when v_n = 0 then format('En %s ninguna obra va al 100 %% sin estar terminada.', v_nom)
                    else format('%s obra(s) van al 100 %% sin estar terminadas: %s. Con el costo igual a su estimado se gana el precio '
                                'entero: si todavía les falta trabajo, su costo total estimado tiene que ser mayor; si terminaron, '
                                'márcalas terminadas.', v_n, v_t) end;
  end if;
  return next;

  -- 130. Revisadas con un precio que no es el contrato que hoy dice la ficha
  --      (a propósito, con su nota: otro precio, o «el cambio es de después»).
  --      La que cambió DESPUÉS de revisarla y todavía no se decidió no está
  --      aquí: está «por revisar» y la detiene el cuadre 40.
  orden := 130; cuadre := 'wip: el contrato de la ficha cambió después de revisar'; nivel := 'aviso';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*), left(string_agg(format('%s (revisada con %s; la ficha dice %s%s)', s.obra, fn_wip_usd(s.precio_contrato),
                                            case when s.precio_ficha is null then 'nada' else fn_wip_usd(s.precio_ficha) end,
                                            case when s.falta ? 'precio' then '; falta decir si el cambio es de este mes' else '' end),
                                     '; ' order by s.obra), 900)
      into v_n, v_t
      from jsonb_to_recordset(v_filas) as s(obra text, estado text, falta jsonb, revision_id uuid, precio_contrato numeric, precio_ficha numeric)
     where s.revision_id is not null and s.estado <> 'excluida' and s.precio_ficha is distinct from s.precio_contrato;
    ok := v_n = 0;
    detalle := case when v_n = 0 then format('En %s cada obra revisada usa el contrato que hoy dice su ficha.', v_nom)
                    else format('En %s obra(s) el precio con que se revisó no es el contrato que hoy dice la ficha: %s. Si el cambio es de '
                                '%s, revísala otra vez con el precio nuevo; si es de después, dilo (un toque) y se queda como está.',
                                v_n, v_t, v_nom) end;
  end if;
  return next;

  -- 140. Facturado por encima del contrato.
  orden := 140; cuadre := 'wip: facturado por encima del contrato'; nivel := 'aviso';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*), left(string_agg(format('%s (facturado %s, contrato %s)', s.obra, fn_wip_usd(s.facturado_fecha),
                                            fn_wip_usd(s.precio_contrato)), '; ' order by s.obra), 900)
      into v_n, v_t
      from jsonb_to_recordset(v_filas) as s(obra text, facturado_fecha numeric, precio_contrato numeric)
     where s.facturado_fecha > s.precio_contrato;
    ok := v_n = 0;
    detalle := case when v_n = 0 then format('En %s ninguna obra del WIP tiene facturado más que su contrato.', v_nom)
                    else format('%s obra(s) tienen facturado más que su contrato: %s. ¿Falta una orden de cambio en el contrato de la '
                                'ficha? Lo que pasa del precio sale sobre-facturado.', v_n, v_t) end;
  end if;
  return next;

  -- 150. Ingreso de una obra del WIP que no es factura ni ajuste.
  orden := 150; cuadre := 'wip: ingreso de una obra que no es factura ni ajuste'; nivel := 'aviso';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*), left(string_agg(format('%s (%s)', s.obra, fn_wip_usd(s.ingreso_otro)), '; ' order by s.obra), 900)
      into v_n, v_t
      from jsonb_to_recordset(v_filas) as s(obra text, ingreso_otro numeric)
     where coalesce(s.ingreso_otro, 0) <> 0;
    ok := v_n = 0;
    detalle := case when v_n = 0 then format('En %s todo el ingreso de las obras del WIP viene de sus facturas.', v_nom)
                    else format('%s obra(s) tienen ingreso en el libro que no viene de una factura ni del WIP (un descuento al cobrar, un '
                                'asiento a mano): %s. El WIP no lo cuenta como facturado; si es una rebaja del precio, baja el contrato.',
                                v_n, v_t) end;
  end if;
  return next;

  -- 160. Obras de precio fijo con dinero FUERA del WIP del mes:
  --      (a) las terminadas, con costo o facturas en el mes, que no están en
  --      el WIP del mes (si terminó este mes con parte por facturar, hay que
  --      revisarla como terminada para que entre);
  --      (b) las que la app todavía NO tiene en obra (en estimación, con la
  --      propuesta enviada, no aprobada) y ya tienen facturas en el libro
  --      hasta el fin del mes: no entran (no hay obra que medir), y lo que
  --      se les facturó —el depósito al firmar— cuenta entero como ingreso.
  --      Se dice hasta que la obra pase a aprobada (entra en el WIP) o Edgar
  --      la marque como que no lleva WIP, con su nota.
  orden := 160; cuadre := 'wip: obras terminadas o sin aprobar, con dinero fuera del WIP'; nivel := 'aviso';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*), left(string_agg(format('%s (la app la tiene %s; facturado %s)', o.obra,
                                            case o.obra_estado when 'estimando' then 'en estimación' when 'enviado' then 'con la propuesta enviada'
                                                               when 'no_aprobado' then 'como no aprobada'
                                                               else 'como «' || coalesce(o.obra_estado, 'sin estado') || '»' end,
                                            fn_wip_usd(lb.facturado)), '; ' order by o.obra), 600)
      into v_n2, v_t2
      from fn_wip_obras(null) o
      join fn_wip_libro(per.hasta, null) lb on lb.proyecto_id = o.proyecto_id
     where o.lleva_wip and not o.activa and not o.terminada and lb.facturado <> 0
       and not exists (select 1 from jsonb_to_recordset(v_filas) as s(proyecto_id text) where s.proyecto_id = o.proyecto_id);
    select count(*), left(string_agg(o.obra, ', ' order by o.obra), 600) into v_n, v_t
      from fn_wip_obras(null) o
     where o.lleva_wip and o.terminada
       and not exists (select 1 from jsonb_to_recordset(v_filas) as s(proyecto_id text) where s.proyecto_id = o.proyecto_id)
       and exists (select 1 from asiento_lineas l
                     join asientos x on x.id = l.asiento_id
                     join cuentas cu on cu.codigo = l.cuenta
                    where l.proyecto_id = o.proyecto_id and cu.tipo in ('costo', 'ingreso')
                      and x.fecha_contable between per.desde and per.hasta
                      and not exists (select 1 from fn_wip_asientos() w where w.asiento_id = l.asiento_id));
    ok := v_n = 0 and v_n2 = 0;
    detalle := case when v_n = 0 and v_n2 = 0
                    then format('En %s ninguna obra de precio fijo terminada o sin aprobar tiene costo o facturas fuera del WIP.', v_nom)
                    else concat_ws(' ',
                           case when v_n > 0
                                then format('%s obra(s) terminadas de precio fijo tienen costo o facturas en %s y no están en su WIP: %s. Si '
                                            'alguna terminó este mes y le falta facturar, revísala como terminada para que entre.',
                                            v_n, v_nom, v_t) end,
                           case when v_n2 > 0
                                then format('%s obra(s) de precio fijo ya tienen facturas en el libro y la app todavía no las tiene en obra: '
                                            '%s. No están en el WIP: lo que se les facturó (un depósito, por ejemplo) cuenta entero como '
                                            'ingreso, de una vez. Si ya se aprobó, pásala a aprobada o en ejecución en su ficha: entra al '
                                            'WIP y se revisa como las demás. Si no va a ser obra, márcala como que no lleva WIP, con su '
                                            'nota, y deja de salir aquí.', v_n2, v_t2) end) end;
  end if;
  return next;

  -- 165. Obras activas, que no son de servicio, sin contrato en la ficha y
  --      con movimiento: no llevan WIP porque no hay precio.
  orden := 165; cuadre := 'wip: obras activas sin contrato que no son de servicio'; nivel := 'aviso';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*), left(string_agg(o.obra, ', ' order by o.obra), 900) into v_n, v_t
      from fn_wip_obras(null) o
      join fn_wip_libro(per.hasta, null) lb on lb.proyecto_id = o.proyecto_id
     where not o.lleva_wip and o.activa and o.marca is null and o.contrato is null
       and lower(btrim(coalesce(o.tipo, ''))) <> 'servicio'
       and (lb.costo <> 0 or lb.facturado <> 0);
    ok := v_n = 0;
    detalle := case when v_n = 0 then 'Toda obra activa con movimiento que no es de servicio tiene su contrato en la ficha (o su marca).'
                    else format('%s obra(s) activas que no son de servicio no tienen contrato en su ficha y por eso no llevan WIP: %s. Si '
                                'son de precio fijo, pon el contrato; si se cobran por tiempo y material, márcalas así.', v_n, v_t) end;
  end if;
  return next;

  -- 170. Horas de obras del WIP que no tienen costo en el libro (c10: «a
  --      estándar»): su costo a la fecha va corto, y su avance también. (Se
  --      leyó arriba: el texto del ajuste del mes también lo dice.)
  orden := 170; cuadre := 'wip: horas sin costo en el libro'; nivel := 'aviso';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    ok := v_horas_ok; detalle := v_horas_det;
  end if;
  return next;

  -- 180. La suma de los hitos no es el contrato de la ficha (obras del WIP
  --      con hitos): el precio puede estar sin poner al día.
  orden := 180; cuadre := 'wip: la suma de los hitos no es el contrato'; nivel := 'aviso';
  if not v_vivo then
    ok := true; detalle := v_noaplica;
  else
    select count(*), left(string_agg(format('%s (hitos %s, contrato %s)', s.obra, fn_wip_usd(h.monto),
                                            case when s.precio_ficha is null then 'nada' else fn_wip_usd(s.precio_ficha) end),
                                     '; ' order by s.obra), 900)
      into v_n, v_t
      from jsonb_to_recordset(v_filas) as s(proyecto_id text, obra text, precio_ficha numeric)
      join (select hi.proyecto_id, sum(round(coalesce(hi.monto, 0), 2)) as monto from hitos hi group by hi.proyecto_id) h
        on h.proyecto_id = s.proyecto_id
     where h.monto is distinct from s.precio_ficha;
    ok := v_n = 0;
    detalle := case when v_n = 0 then 'En cada obra del WIP con hitos, sus hitos suman el contrato de la ficha.'
                    else format('En %s obra(s) los hitos no suman el contrato de la ficha: %s. El precio del WIP es el contrato: mira '
                                'cuál de los dos está al día.', v_n, v_t) end;
  end if;
  return next;
end $$;
revoke execute on function public.fn_wip_control(text) from public, anon, service_role;
grant  execute on function public.fn_wip_control(text) to authenticated;
comment on function public.fn_wip_control(text) is 'c12: el control del WIP de un mes (sin período, el mes que toca): 10 en las cuentas del WIP solo está el ajuste; 20 cada ajuste vivo es su asiento y el saldo por obra al cierre del mes es el del ajuste; 30 lo facturado a la fecha = las facturas del libro; 40 cada obra que entra en el mes, decidida (revisada, con lo de antes confirmado y el contrato de la ficha sin cambiar desde entonces, o excluida con su nota; y ninguna que traía saldo del ajuste anterior fuera del mes); 50 el ajuste posteado y al día (dice quién quedó fuera y por qué); 60 ninguna obra con más costo que su estimado revisado (sin excepción por nota); 90 las protecciones; y los avisos 110 a 180. Las filas 40 y 50 no se ponen en rojo mientras el mes no se exija o no haya terminado. Solo lectura; a quien no es el dueño, nada.';

-- LAS CUATRO FILAS DEL CIERRE (c9: fn_cierre_revisar las pide si esta capa
-- está): 174 los cuadres del WIP (detiene), 175 cada obra con su costo
-- estimado revisado (detiene), 176 el ajuste del mes posteado y al día
-- (detiene) y 177 sus avisos. Con qué hacer y a qué página ir.
--   · La 174 y la 177 juntan varios controles. Su NOMBRE dice cuántos y
--     cuáles están en rojo («… — 2 en rojo: 120, 170»): la ronda de c9 avisa
--     al teléfono de cada rojo NUEVO mirando el nombre de la fila, y así uno
--     que se enciende detrás de otro que ya estaba no pasa callado.
--   · Su detalle lleva TODOS los que están en rojo, cada uno recortado a su
--     parte (c9 guarda 1500 letras por fila): ninguno se queda fuera porque
--     el primero sea largo. El texto entero de cada uno está en el control
--     del WIP (Contabilidad → WIP).
--   · La 176 dice siempre quién quedó fuera del ajuste y por qué.
drop function if exists public.fn_wip_cierre(text);
create function public.fn_wip_cierre(p_periodo text)
returns table (orden int, control text, nivel text, ok boolean, detalle text, que_hacer text, ir_a text)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_c jsonb;
  v_n bigint;
  v_r bigint;
  v_t text;
  v_q text;
  f   record;
begin
  if not fn_wip_ve() then
    return;
  end if;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.orden), '[]'::jsonb) into v_c from fn_wip_control(p_periodo) c;
  ir_a := 'wip';

  select count(*), count(*) filter (where not x.ok), string_agg(x.orden::text, ', ' order by x.orden) filter (where not x.ok)
    into v_n, v_r, v_q
    from jsonb_to_recordset(v_c) as x(orden int, nivel text, ok boolean)
   where x.nivel = 'cuadre' and x.orden not in (40, 50);
  select string_agg(case when length(x.detalle) > greatest(160, 1380 / greatest(v_r, 1)::int)
                         then left(x.detalle, greatest(160, 1380 / greatest(v_r, 1)::int) - 1) || '…' else x.detalle end,
                    ' · ' order by x.orden)
    into v_t
    from jsonb_to_recordset(v_c) as x(orden int, nivel text, ok boolean, detalle text)
   where x.nivel = 'cuadre' and x.orden not in (40, 50) and not x.ok;
  orden := 174; control := 'wip: los cuadres del WIP (c12)' || case when v_r > 0 then format(' — %s en rojo: %s', v_r, v_q) else '' end;
  nivel := 'detiene'; ok := v_r = 0;
  detalle := case when v_r = 0 then format('Los %s, en verde.', v_n) else coalesce(v_t, 'en rojo, sin detalle') end;
  que_hacer := case when v_r = 0 then null
                    else 'El detalle dice qué: Contabilidad → WIP. Un asiento a mano en las cuentas del WIP se reversa; un ajuste que no '
                         'cuadra se vuelve a postear; a una obra con más costo que su estimado se le sube el estimado (o se marca terminada).' end;
  return next;

  select x.ok, x.detalle into f from jsonb_to_recordset(v_c) as x(orden int, ok boolean, detalle text) where x.orden = 40;
  orden := 175; control := 'wip: cada obra con su costo estimado revisado'; nivel := 'detiene'; ok := coalesce(f.ok, false);
  detalle := coalesce(f.detalle, 'sin detalle');
  que_hacer := case when coalesce(f.ok, false) then null
                    else 'En Contabilidad → WIP, decide cada obra de la lista: confirma lo propuesto con un toque, pon su costo total '
                         'estimado con su nota, confirma lo de antes del libro, o déjala fuera este mes con su nota.' end;
  return next;

  select x.ok, x.detalle into f from jsonb_to_recordset(v_c) as x(orden int, ok boolean, detalle text) where x.orden = 50;
  orden := 176; control := 'wip: el ajuste del mes posteado y al día'; nivel := 'detiene'; ok := coalesce(f.ok, false);
  detalle := coalesce(f.detalle, 'sin detalle');
  que_hacer := case when coalesce(f.ok, false) then null
                    else 'En Contabilidad → WIP, toca «Postear el ajuste» (si ya estaba posteado, lo rehace con lo de hoy).' end;
  return next;

  select count(*), count(*) filter (where not x.ok), string_agg(x.orden::text, ', ' order by x.orden) filter (where not x.ok)
    into v_n, v_r, v_q
    from jsonb_to_recordset(v_c) as x(orden int, nivel text, ok boolean)
   where x.nivel = 'aviso';
  select string_agg(case when length(x.detalle) > greatest(120, 1380 / greatest(v_r, 1)::int)
                         then left(x.detalle, greatest(120, 1380 / greatest(v_r, 1)::int) - 1) || '…' else x.detalle end,
                    ' · ' order by x.orden)
    into v_t
    from jsonb_to_recordset(v_c) as x(orden int, nivel text, ok boolean, detalle text)
   where x.nivel = 'aviso' and not x.ok;
  orden := 177; control := 'wip: sus avisos (c12)' || case when v_r > 0 then format(' — %s en rojo: %s', v_r, v_q) else '' end;
  nivel := 'aviso'; ok := v_r = 0;
  detalle := case when v_r = 0 then format('Los %s, en verde.', v_n) else coalesce(v_t, 'en rojo, sin detalle') end;
  que_hacer := case when v_r = 0 then null
                    else 'No detienen el cierre. Aquí va el principio de cada uno; entero, en Contabilidad → WIP.' end;
  return next;
end $$;
revoke execute on function public.fn_wip_cierre(text) from public, anon, service_role;
grant  execute on function public.fn_wip_cierre(text) to authenticated;
comment on function public.fn_wip_cierre(text) is 'c12: las cuatro filas del WIP para la revisión del cierre (c9) de un período: 174 los cuadres del WIP (detiene), 175 cada obra con su costo estimado revisado en el mes (detiene), 176 el ajuste del mes posteado y al día (detiene; dice quién quedó fuera del ajuste y por qué) y 177 sus avisos (aviso); cada una con ok, el detalle en llano, qué hacer e ir_a = wip. El nombre de la 174 y de la 177 dice cuántos y cuáles de sus controles están en rojo (así la ronda avisa de cada rojo nuevo), y su detalle lleva el principio de todos. La 175 y la 176 no se ponen en rojo mientras el mes no se exija o no haya terminado. Solo lectura; a quien no es el dueño, nada.';


-- ---------------------------------------------------------------------
-- 10. Las vistas de la pantalla (security_invoker; leen funciones de aquí
--     y tablas; de periodos y de cuentas no nombran las columnas que
--     c2-pruebas reescribe). Solo authenticated; el equipo, cero filas.
-- ---------------------------------------------------------------------
-- LAS OBRAS Y SI LLEVAN WIP (fn_wip_obras; sus columnas, allí).
create view public.v_wip_obras with (security_invoker = true) as
select o.* from public.fn_wip_obras(null) o;
revoke all on public.v_wip_obras from public, anon, authenticated, service_role;
grant select on public.v_wip_obras to authenticated;
comment on view public.v_wip_obras is 'c12: cada obra y si lleva WIP: tipo, estado (activa, terminada), el contrato de su ficha, la marca de Edgar (contrato | tm) con su nota, lleva_wip y su porqué en llano, la cuenta de ingreso de su tipo, si ya andaba antes del libro (de_antes, de_antes_por) y lo de antes confirmado (antes_costo, antes_facturado, cuándo y quién).';

-- EL WIP SCHEDULE: una fila por obra y mes, desde que hay libro hasta el mes
-- en curso (fn_wip_schedule; las columnas, en fn_wip_calcular). La pantalla
-- lo pide filtrado por periodo: así solo se calcula ese mes.
create view public.v_wip_schedule with (security_invoker = true) as
select m.periodo, s.proyecto_id, s.obra, s.cliente, s.tipo, s.obra_estado, s.fuente, s.estado, s.falta, s.falta_texto, s.en_ajuste,
       s.terminada, s.precio_contrato, s.precio_ficha, s.costo_estimado, s.utilidad_estimada, s.costo_libro, s.costo_antes,
       s.costo_fecha, s.pct_avance, s.pct_real, s.pasa_de_100, s.ingreso_ganado, s.facturado_libro, s.facturado_antes,
       s.facturado_fecha, s.sub_facturado, s.sobre_facturado, s.costo_para_terminar, s.utilidad_fecha, s.perdida_total,
       s.perdida_provision, s.cuenta_ingreso, s.ingreso_otro, s.de_antes, s.antes_confirmado, s.antes_id, s.revision_id,
       s.revisado_el, s.revisado_por, s.revision_origen, s.revision_nota, s.propuesta_costo_estimado, s.propuesta_origen,
       s.propuesta_nota, s.propuesta_terminada, s.avisos
  from public.fn_wip_meses() m
  cross join lateral public.fn_wip_schedule(m.periodo) s;
revoke all on public.v_wip_schedule from public, anon, authenticated, service_role;
grant select on public.v_wip_schedule to authenticated;
comment on view public.v_wip_schedule is 'c12: el WIP por costo a costo, una fila por obra y mes (el formato que pide la afianzadora): precio_contrato, costo_estimado (el revisado), utilidad_estimada, costo_fecha (costo_libro + costo_antes), pct_avance (topado en 100; pct_real sin tope y pasa_de_100), ingreso_ganado (precio × costo ÷ costo estimado), facturado_fecha (facturado_libro + facturado_antes, sin los ajustes de WIP), sub_facturado (1200), sobre_facturado (2400), costo_para_terminar, utilidad_fecha, perdida_total y perdida_provision (2410: lo que falta por reconocer); con su estado (lista | pendiente y qué falta | excluida a propósito con su nota | sin_movimiento), la revisión del mes, la propuesta del costo estimado y los avisos. fuente: calculado (un mes abierto, lo de hoy) o posteado (un mes cerrado, la foto de su ajuste). Se lee filtrada por periodo.';

-- EL CONTROL del mes que toca (fn_wip_control sin período).
create view public.v_wip_control with (security_invoker = true) as
select c.orden, c.cuadre, c.nivel, c.ok, c.detalle from public.fn_wip_control(null) c;
revoke all on public.v_wip_control from public, anon, authenticated, service_role;
grant select on public.v_wip_control to authenticated;
comment on view public.v_wip_control is 'c12: el control del WIP del mes que toca (orden, cuadre, nivel, ok, detalle en llano): 10 en las cuentas del WIP solo está el ajuste; 20 cada ajuste es su asiento y el saldo por obra es el del ajuste; 30 lo facturado a la fecha = las facturas del libro; 40 cada obra con su costo estimado revisado (o excluida con su nota); 50 el ajuste del mes posteado y al día; 60 ninguna obra con más costo que su estimado revisado; 90 las protecciones; y los avisos: 110 lo de antes sin confirmar, 120 obras con pérdida, 125 al 100 % sin estar terminadas, 130 revisadas con un precio que no es el de la ficha, 140 facturado sobre el contrato, 150 ingreso que no es factura, 160 terminadas (o sin aprobar en la app y con facturas) fuera del WIP, 165 activas sin contrato, 170 horas sin costo en el libro, 180 los hitos no suman el contrato. nivel: cuadre (detiene el cierre) o aviso. Para otro mes, fn_wip_control(periodo).';

-- LOS AJUSTES: cada uno con su asiento, su reverso y quién.
create view public.v_wip_ajustes with (security_invoker = true) as
select a.id as ajuste_id, a.periodo, public.fn_wip_mes(a.periodo) as periodo_nombre, a.asiento_id, a.numero, a.fecha,
       a.reverso_auto_id, ra.numero as reverso_auto_numero, ra.fecha_contable as reverso_auto_fecha,
       a.obras, a.lineas, a.sub_facturado, a.sobre_facturado, a.perdida,
       a.deshecho_el is null as vivo, a.sustituye_a, a.motivo,
       a.creado_el, a.creado_por, pc.nombre as creado_por_nombre,
       a.deshecho_el, a.deshecho_por, pd.nombre as deshecho_por_nombre, a.deshecho_motivo,
       a.reverso_id, rr.numero as reverso_numero, a.por_fuera
  from public.wip_ajustes a
  left join public.asientos ra on ra.id = a.reverso_auto_id
  left join public.asientos rr on rr.id = a.reverso_id
  left join public.perfiles pc on pc.id = a.creado_por
  left join public.perfiles pd on pd.id = a.deshecho_por;
revoke all on public.v_wip_ajustes from public, anon, authenticated, service_role;
grant select on public.v_wip_ajustes to authenticated;
comment on view public.v_wip_ajustes is 'c12: cada ajuste de WIP posteado, vivo o deshecho: el mes, su asiento (numero, fecha) y el reverso automático del día 1 con que nació, cuántas obras y líneas, lo sub-facturado, lo sobre-facturado y la pérdida que llevó, si sigue vivo, a cuál sustituyó y por qué, quién y cuándo; y deshecho: por quién, cuándo, el motivo, el reverso que lo quitó y si se había reversado por fuera.';

-- LAS REVISIONES: la historia de cada obra, mes por mes.
create view public.v_wip_revisiones with (security_invoker = true) as
select r.id as revision_id, r.proyecto_id, pr.nombre as obra, r.periodo, public.fn_wip_mes(r.periodo) as periodo_nombre,
       r.precio_contrato, r.precio_ficha, r.costo_estimado, r.terminada, r.origen, r.propuesta, r.propuesta_origen, r.nota,
       r.revisado_el, r.revisado_por, pf.nombre as revisado_por_nombre,
       r.sustituida_el is null as vigente, r.sustituida_el
  from public.wip_revisiones r
  left join public.proyectos pr on pr.id = r.proyecto_id
  left join public.perfiles pf on pf.id = r.revisado_por;
revoke all on public.v_wip_revisiones from public, anon, authenticated, service_role;
grant select on public.v_wip_revisiones to authenticated;
comment on view public.v_wip_revisiones is 'c12: cada revisión de cada obra y mes, la vigente y las que sustituyó: el precio del contrato que se usó y el de la ficha ese día, el costo total estimado revisado (o terminada), de dónde salió (mes_anterior, estimado, a_mano, terminada), lo que se proponía, la nota, quién y cuándo.';


-- ---------------------------------------------------------------------
-- 11. Lo que debe verse al pegar: fn_wip_pegado().
-- ---------------------------------------------------------------------
create or replace function public.fn_wip_pegado() returns table (que text, detalle text)
language plpgsql
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  c       wip_config;
  v_per   text;
  v_txt   text;
  v_r     record;
  v_j     jsonb;
  v_falta text[] := '{}';
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  select * into c from wip_config where id = 1;
  return query select 'wip_config'::text,
                      case when c.exigir_desde is null then 'el cierre todavía no exige el WIP en ningún mes'
                           else format('el cierre exige el WIP desde %s (%s); los meses anteriores no se frenan por él', fn_wip_mes(c.exigir_desde),
                                       c.exigir_desde) end;
  return query select 'tablas'::text,
                      format('wip_config, wip_obras (%s marcadas), wip_antes (%s confirmadas), wip_revisiones (%s vigentes), wip_ajustes (%s '
                             'vivos, %s deshechos), wip_ajuste_obras (%s)',
                             (select count(*) from wip_obras o where o.modo is not null),
                             (select count(*) from wip_antes a where a.sustituida_el is null),
                             (select count(*) from wip_revisiones r where r.sustituida_el is null),
                             (select count(*) from wip_ajustes a where a.deshecho_el is null),
                             (select count(*) from wip_ajustes a where a.deshecho_el is not null),
                             (select count(*) from wip_ajuste_obras));
  return query select 'vistas'::text, 'v_wip_obras, v_wip_schedule, v_wip_control, v_wip_ajustes, v_wip_revisiones'::text;
  select count(*) as obras, count(*) filter (where o.lleva_wip) as wip,
         count(*) filter (where o.lleva_wip and o.activa) as activas,
         count(*) filter (where not o.lleva_wip and o.activa) as fuera,
         count(*) filter (where o.lleva_wip and o.activa and o.de_antes) as de_antes,
         count(*) filter (where o.lleva_wip and o.activa and o.de_antes and o.antes_id is null) as sin_confirmar,
         count(*) filter (where o.lleva_wip and o.activa and o.cuenta_ingreso is null) as sin_cuenta
    into v_r
    from fn_wip_obras(null) o;
  return query select 'obras'::text,
                      format('%s obras · %s de precio fijo (llevan WIP), %s de ellas activas · %s activas que no lo llevan (de servicio o sin '
                             'contrato) · de las activas con WIP, %s ya andaban antes del libro (%s sin lo de antes confirmado)',
                             v_r.obras, v_r.wip, v_r.activas, v_r.fuera, v_r.de_antes, v_r.sin_confirmar);
  if v_r.sin_confirmar > 0 then
    v_falta := v_falta || format('confirmar lo de antes del libro en %s obra(s) que ya andaban (hasta entonces no entran en el ajuste)',
                                 v_r.sin_confirmar);
  end if;
  if v_r.sin_cuenta > 0 then
    v_falta := v_falta || format('confirmar la cuenta de ingreso del tipo de %s obra(s) (select fn_mapeo_confirmar(''tipo_proyecto'');)',
                                 v_r.sin_cuenta);
  end if;
  v_per := fn_wip_toca();
  begin
    v_j := fn_wip_resumen(v_per);
    v_txt := format('%s%s: %s obra(s) en el WIP (%s listas, %s por revisar, %s sin lo de antes confirmado, %s sin movimiento) · sub-facturado '
                    '%s, sobre-facturado %s, pérdida por reconocer %s · %s', fn_wip_mes(v_per),
                    case when (v_j->>'exigido')::boolean then '' else ' (todavía no se exige)' end,
                    v_j->'obras'->>'total', v_j->'obras'->>'listas', v_j->'obras'->>'por_revisar', v_j->'obras'->>'por_confirmar_antes',
                    v_j->'obras'->>'sin_movimiento', fn_wip_usd((v_j->'totales'->>'sub_facturado')::numeric),
                    fn_wip_usd((v_j->'totales'->>'sobre_facturado')::numeric), fn_wip_usd((v_j->'totales'->>'perdida_provision')::numeric),
                    case when (v_j->'ajuste'->>'vivo')::boolean then 'ajuste posteado (asiento ' || (v_j->'ajuste'->>'numero') || ')'
                         else 'sin ajuste posteado' end);
    if (v_j->'obras'->>'por_revisar')::int > 0 then
      v_falta := v_falta || format('revisar el costo estimado de %s obra(s) en %s', v_j->'obras'->>'por_revisar', fn_wip_mes(v_per));
    end if;
  exception when others then
    v_txt := format('el resumen de %s falló: %s %s', coalesce(v_per, '(ningún mes)'), sqlstate, sqlerrm);
  end;
  return query select 'el mes que toca'::text, v_txt;
  begin
    select format('%s de %s cuadres en rojo%s · %s de %s avisos%s',
                  count(*) filter (where k.nivel = 'cuadre' and k.ok is distinct from true), count(*) filter (where k.nivel = 'cuadre'),
                  coalesce(' (' || string_agg(k.cuadre, '; ' order by k.orden) filter (where k.nivel = 'cuadre' and k.ok is distinct from true) || ')', ''),
                  count(*) filter (where k.nivel = 'aviso' and k.ok is distinct from true), count(*) filter (where k.nivel = 'aviso'),
                  coalesce(' (' || string_agg(k.cuadre, '; ' order by k.orden) filter (where k.nivel = 'aviso' and k.ok is distinct from true) || ')', ''))
      into v_txt
      from fn_wip_control(null) k;
  exception when others then
    v_txt := format('el control falló: %s %s', sqlstate, sqlerrm);
  end;
  return query select 'control'::text, v_txt;
  return query select 'qué falta'::text,
                      case when cardinality(v_falta) = 0 then 'nada: todo listo' else array_to_string(v_falta, ' · ') end;
  -- (¿el cierre de esta base ya mira el WIP? El c9 con las filas 174 a 177 lo
  -- pide a esta capa; el de antes no, y hay que volver a pegarlo.)
  return query select 'siguiente paso'::text,
                      case when to_regprocedure('public.fn_cierre_revisar(text)') is not null
                                and not exists (select 1 from pg_proc p
                                                 where p.oid = to_regprocedure('public.fn_cierre_revisar(text)')
                                                   and p.prosrc like '%fn_wip_cierre%')
                           then 'PRIMERO vuelve a pegar docs/conta/c9-cierre.sql: el cierre de esta base todavía no mira el WIP (sus filas '
                                '174 a 177). Después, '
                           else '' end ||
                      'pega docs/conta/c12-pruebas.sql; en la app, Contabilidad → WIP: por cada obra, confirma lo de antes del libro (una '
                      'vez) y su costo estimado del mes (un toque), y «Postear el ajuste» lo lleva al libro (se deshace solo el día 1).'::text;
end $$;
revoke execute on function public.fn_wip_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_wip_pegado() is 'c12: lo que enseña el final del pegado: la configuración (desde qué mes se exige), las tablas y las vistas, cuántas obras llevan WIP y cuántas ya andaban antes del libro, el mes que toca en una línea (obras, sobre y sub-facturado, el ajuste), el control, qué falta y el paso siguiente.';

select * from public.fn_wip_pegado();
