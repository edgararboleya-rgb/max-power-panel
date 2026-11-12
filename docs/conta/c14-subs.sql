-- =====================================================================
-- c14-subs.sql — W-9, COI Y EL 1099 DE QUIEN COBRA COMO CONTRATISTA
-- (los subcontratistas y los ayudantes por hora pagados por Zelle hasta que
-- entren a Gusto) · c14 (la mitad de la Fase 12a; la otra mitad, la cédula
-- de corte, es c13 y no depende de esta).
-- 12-nov-2026. Se pega en el SQL Editor DESPUÉS de c1, c2 y c3 (y de c4, c6,
-- c7, s1, p1, c8, c9, c10, c11 y c12 si se usan: la cadena de siempre; c13
-- puede faltar o estar, esta capa no la mira). Idempotente: se puede volver
-- a pegar entero (no pisa la configuración, ni una ficha, ni un TIN, ni un
-- archivo, ni una marca). Después se pega c14-pruebas.sql.
--
-- Qué hace. A quien se le paga por servicios sin ser empleado hay que
-- pedirle su W-9 (nombre legal, tipo de entidad, dirección y TIN) y su
-- certificado de seguro (COI), y en enero mandarle su 1099-NEC si lo pagado
-- en el año pasa del umbral. Siempre falta alguno, y en enero ya no
-- contestan el teléfono. Esta capa guarda la ficha fiscal de cada uno, sus
-- papeles (en un bucket privado), saca del LIBRO lo que se le pagó de verdad
-- (base caja), dice a quién le falta qué, y arma la hoja del 1099.
--
-- LO QUE ESTÁ DECIDIDO (docs/CONTA-PLAN.md y f12; no se rediscute):
--   · El 1099 de 2026 SALE DE QUICKBOOKS (es el libro de ese año) y se
--     presenta antes del 1-feb-2027. La app produce el de 2027 en enero de
--     2028. Lo que la app enseña de 2026 es PARCIAL (el libro empieza el
--     1-oct-2026) y sirve para cruzar, no para presentar: cada fila de 2026
--     lo dice.
--   · W-9 y COI NUNCA en «contratistas», que son los GC clientes: aquí no
--     hay nada colgado de esa tabla.
--   · El TIN solo lo ve el dueño, y ni la pantalla lo enseña entero.
--
-- LAS PIEZAS:
--   (1) LA FICHA FISCAL (subs_fichas): una por persona o empresa a la que se
--       le paga como contratista. Lleva lo del W-9 (nombre legal, nombre
--       comercial, tipo de entidad, dirección), si se le reporta el 1099
--       («si» | «no» | «por_decidir», con su nota), si está exento de WC, y
--       del TIN solo su tipo (SSN o EIN) y sus 4 últimos.
--       · A QUIÉN SE REFIERE EL LIBRO. Una línea del libro dice con quién es
--         con tercero_tipo + tercero_id: «proveedor» (proveedores.id: el sub,
--         el supply) o «empleado» (perfiles.id: el ayudante con horas en la
--         app, que c10 pone en cada línea de su jornal). La misma persona
--         puede estar de las dos formas (un ayudante con perfil para sus
--         horas y con proveedor para sus trabajos externos): por eso una
--         ficha tiene UNO O VARIOS terceros (subs_terceros), y un tercero
--         está en una sola ficha. Un 1099 por ficha, no por tercero. No se
--         toca proveedores, perfiles, externos_equipo ni contratistas: son
--         de otras capas o de la app; aquí solo se enlaza por su id (sin
--         llave foránea: nada cambia cómo se borran allí; si el tercero
--         desaparece, el control lo dice).
--       · Una ficha puede existir ANTES del primer pago (el W-9 se pide al
--         contratar) y sin tercero todavía.
--       · QUÉ ES «CORPORACIÓN». tipo_entidad: individual, sole_proprietor,
--         llc_un_socio, llc_sociedad, sociedad (partnership), s_corp, c_corp
--         u otro. Una LLC que tributa como corporación (su W-9 dice C o S)
--         se anota como c_corp o s_corp. A las de subs_config.entidades_no_
--         reporta (de fábrica s_corp y c_corp) no se les reporta, SALVO que
--         la ficha diga reporta = «si» con su nota: es la excepción por
--         tercero (un abogado, lo que diga el CPA).
--       · SI SE LE REPORTA. «si»: se le reporta (si pasa del umbral). «no»:
--         no se le reporta, con su porqué (es empleado por Gusto, lo dijo el
--         CPA…). «por_decidir» (así nace): si es corporación vale la regla
--         (no); si no lo es, su fila sale con lo pagado y «falta decidir»,
--         y NO entra en la hoja hasta que alguien decida.
--       · EL ESTATUS TIENE FECHA (subs_tramos). «Se le reporta» y el tipo de
--         entidad no son verdades de siempre: una persona física se hace
--         S-corp en julio; un ayudante entra a Gusto en enero. Si la ficha
--         YA TIENE PAGOS y se le cambia lo que decide si se reporta, la base
--         no reescribe sola todos los años: pide que se diga DESDE CUÁNDO
--         vale lo nuevo (MX008, con lo pagado, entre qué fechas y el primer
--         día posible). Con «desde», lo de antes queda guardado como un
--         TRAMO (hasta la víspera) y cada pago cuenta con el estatus que
--         valía EL DÍA DE ESE PAGO: 3,000 en marzo como persona física y
--         3,000 en septiembre como S-corp dan 3,000 reportables, no 0. Si lo
--         de antes estaba MAL desde el principio (se tecleó mal el tipo), se
--         dice «corrige»: entonces sí vale para todo, y queda en el
--         historial. Decidir por primera vez (de «por decidir» a «sí») no
--         pide nada. Un tramo mal puesto se retira (fn_subs_tramo_retirar,
--         con su motivo; queda como rastro). Las fechas son pasadas: no se
--         programa un cambio para el futuro.
--       · OJO CON EL TIN AL CAMBIAR DE ENTIDAD: el TIN es UNO por ficha (el
--         de hoy). Quien pasa de persona física (SSN) a S-corp (EIN) es,
--         para el IRS, OTRO contribuyente: lo limpio es otra ficha (y otro
--         proveedor) para la empresa nueva, y la vieja se queda con su SSN y
--         sus pagos. Por eso cambiar un TIN por otro distinto en una ficha
--         con pagos pide confirmarlo («corrige»: era un error de dedo).
--   (2) EL TIN (subs_tin), lo más delicado de la capa. Está en una TABLA
--       APARTE de una sola cosa (ficha → TIN), y no en la ficha:
--       · QUIÉN LO LEE. Nadie por la API salvo el dueño, con el código del
--         teléfono (aal2), y solo DENTRO de las dos funciones de aquí que lo
--         necesitan (guardar y exportar): sus policies piden las tres cosas
--         (es_dueno(), aal2 y la marca de la transacción mx_subs.tin, que
--         solo ponen esas dos funciones), en permisiva y otra vez en
--         «restrictive» (aunque otra policy permisiva dejara pasar, no
--         pasa). El equipo no pasa de es_dueno(); anon y service_role no
--         tienen NINGÚN privilegio sobre la tabla (service_role se salta las
--         policies: lo que lo para es no tener grant). El dueño que la lee a
--         mano por la API —aunque sea con su código— ve cero filas.
--       · LA PANTALLA NO LO ENSEÑA ENTERO: la ficha guarda el tipo y los 4
--         últimos (***-**-1234), y ninguna vista ni función de lectura toca
--         subs_tin. Entero sale SOLO de fn_subs_1099_export, que se llama a
--         propósito para la hoja del 1099, pide el código del teléfono y
--         deja apuntado quién, cuándo, de qué año y cuántas filas (sin TIN).
--       · NUNCA VA A UN REGISTRO NI A UN MENSAJE: ningún error, aviso, nota
--         del historial ni fila de exportación lo lleva (ni entero ni en
--         parte, salvo los 4 últimos). Por eso la tabla no tiene CHECK ni
--         índice único sobre el TIN (Postgres escribe la fila o la llave que
--         falla en el DETAIL del error, y eso va al log): la forma y el
--         repetido los mira la función antes de escribir, y la guarda de la
--         tabla otra vez, con mensajes que no lo repiten. Se guarda con POST
--         (la función es volátil: PostgREST no la deja por GET, que lo
--         pondría en la dirección). NO se escribe en el SQL Editor (guarda
--         historial de lo que se pega): se teclea en la app. Y no es un
--         consejo: desde el SQL Editor (o desde una tarea programada) un TIN
--         no se guarda y la hoja no sale. Pero ahí la función NO contesta
--         con un error: contesta «no se guardó» (guardado = false) y dónde
--         se hace. Un error de Postgres deja la sentencia ENTERA —con el TIN
--         tecleado— en el registro del servidor; una orden que termina
--         bien, no. (La hoja, que no lleva ningún TIN en su orden, sí
--         contesta 42501.)
--       · LO QUE QUEDA A LOS LADOS (nada de esto lo enseña por la API; se
--         dice para que nadie lo dé por cerrado):
--           – OTRO CAMPO. Ningún mensaje repite lo tecleado en otro campo
--             (una clave desconocida, un tipo de entidad que no existe, un
--             «quitar» que no es verdadero o falso): si alguien pega el TIN
--             donde no es, no vuelve en el error. Y un campo de texto de la
--             ficha que es ENTERO un TIN (###-##-####, ##-####### o nueve
--             dígitos) no se guarda: «parece un TIN» (22023 por la app).
--             Desde el SQL Editor, cualquier clave o valor de la ficha con
--             esa forma —en el campo que sea— se contesta SIN error.
--           – EL REGISTRO DEL SERVIDOR. Por la API las órdenes llegan con
--             parámetros, y Postgres no los escribe en un error (el control
--             92 vigila que siga así). Lo que sí escribiría es una orden
--             pegada a mano con el TIN dentro que FALLE: por eso el camino
--             del SQL Editor no falla.
--           – LAS ESTADÍSTICAS. La columna del TIN no guarda estadísticas
--             (statistics 0): sus valores no quedan en pg_stats tras un
--             ANALYZE. El control 90 lo comprueba.
--           – LA LLAVE DE SERVICIO (service_role). No tiene ningún
--             privilegio sobre subs_tin ni EXECUTE en las funciones. En el
--             bucket «subs» es distinto: Storage le deja saltarse las
--             policies, así que QUIEN TENGA ESA LLAVE puede leer, mover o
--             borrar los archivos (el W-9 escaneado lleva el TIN). No tiene
--             arreglo desde la base: esa llave no sale de las funciones de
--             Supabase, y ninguna de las de aquí toca este bucket. El
--             control 95 dice si un archivo registrado ya no está o cambió.
--           – EL SQL EDITOR lee la tabla (es el dueño de la base): quien
--             entra al panel de Supabase lo ve todo. Su candado es la
--             cuenta de Supabase con su segundo factor.
--       · POR QUÉ ASÍ Y NO DE OTRA FORMA. (a) Privilegios por columna en la
--         ficha: la columna sin grant no la lee ni el dueño por la API, así
--         que haría falta una función SECURITY DEFINER para sacarla, y
--         «select *» sobre la ficha dejaría de funcionar. (b) Vault: cifra
--         en reposo, pero solo lo lee el rol postgres: otra vez una función
--         SECURITY DEFINER ejecutable por la API, justo lo que c2 vigila
--         («permisos») y lo que ninguna capa desde c10 tiene; y el TIN
--         viajaría por vault.decrypted_secrets, que el SQL Editor lee igual
--         que esta tabla. (c) La tabla aparte con sus policies da todo lo
--         que se pide con funciones SECURITY INVOKER: la base aplica la
--         regla a quien llama, no a un atajo con permisos de dueño. Supabase
--         ya cifra el disco y los respaldos. Si un día hiciera falta cifrar
--         la columna, cambian dos funciones y no la pantalla.
--       · LA FORMA: 9 dígitos, tecleado con sus guiones o sin ellos (SSN
--         ###-##-####, EIN ##-#######); no nueve dígitos iguales ni
--         123456789. No se comprueba contra el IRS (eso es su «TIN
--         Matching», fuera de aquí). Un TIN, una ficha.
--   (3) LOS ARCHIVOS (subs_archivos y el bucket privado «subs»): el W-9, el
--       COI y el certificado de exención de WC, en PDF o foto. El bucket es
--       como «facturas» de c11: solo el dueño CON EL CÓDIGO DEL TELÉFONO
--       (aal2) sube y lee; la llave pública nunca; nadie borra ni pisa (un
--       archivo nuevo va con otro nombre). La app lo sube a
--       <ficha>/<clase>/<archivo> y lo registra aquí (fn_subs_archivo: ruta,
--       sha256, bytes; la base comprueba que está en Storage y mide lo que
--       se declara). Cada COI es una fila con su «vence»: el que vale es el
--       de vencimiento más lejano, y los anteriores quedan (el seguro
--       pregunta por el COI de cuando el sub trabajó). Uno mal subido se
--       RETIRA con su motivo (no se borra).
--   (4) EL CRITERIO DEL PAGO REPORTABLE (fn_subs_calculo; lo AZUL de la
--       fase). Para una ficha y un año: lo PAGADO EN EFECTIVO POR SERVICIOS,
--       con la fecha del asiento del pago (base caja), no la del gasto.
--       · «EN EFECTIVO» = sale de una cuenta de banco o de la caja: las 10xx
--         de activo sin obra (1010 el banco, 1030 la reserva, 1050 la caja
--         chica; la regla de c3 para «banco») MENOS las de subs_config.
--         cuentas_no_pago (1020: los cobros de Stripe en tránsito no pagan a
--         nadie). Lo pagado con TARJETA (una subcuenta 2100-XXXX, o un
--         recibo cuyo papel dice que se pagó con tarjeta, aunque sea la de
--         débito que sale de 1010) NO se reporta: lo reporta el procesador
--         de la tarjeta. Se enseña aparte, con su porqué.
--       · «POR SERVICIOS» = (a) las líneas de una cuenta con etiqueta_fiscal
--         = '1099' en el plan (hoy 5200 Subcontratos; si el CPA añade otra,
--         se etiqueta en el plan y entra sola); (b) TODAS las líneas del
--         asiento de un jornal de c10 (su parte sin obra va a otra cuenta y
--         es el mismo pago a la misma persona); (c) lo que Edgar marque como
--         servicio. Un reembolso de material a un ayudante NO es servicio:
--         va a 5100 (o salda su 2250), que no lleva la etiqueta.
--         Y LO QUE NO SE SABE, SE PREGUNTA: un pago desde el banco a alguien
--         CON FICHA por una cuenta de gasto SIN la etiqueta (el abogado por
--         6600 Profesionales; el material que factura un sub por 5100) no
--         se da por «no servicio» callado: sale «sin clasificar» en su
--         fila, el control lo avisa, y Edgar dice qué es con una marca
--         (servicio o no). Para no preguntar siempre lo mismo, las cuentas
--         de subs_config.cuentas_no_servicio (de fábrica, ninguna) se dan
--         por «no servicio» sin preguntar (p. ej. 5100, si el CPA confirma
--         que el material no se reporta).
--       · DOS CAMINOS llegan del gasto al banco, y se siguen los dos:
--           DIRECTO  el asiento que saca el dinero lleva el gasto (el Zelle
--                    clasificado a 5200, el jornal repartido, el recibo
--                    pagado por Zelle): cuenta en la fecha de ese asiento.
--           A CUENTA el gasto entró contra una cuenta por pagar (2010, y
--                    2020 la retención a subs: subs_config.cuentas_por_pagar)
--                    con su partida, y OTRO asiento la paga después desde el
--                    banco: cuenta en la fecha del PAGO, y solo la parte de
--                    servicio de esa partida. Si la partida mezcla material
--                    y servicio (una factura del sub con las dos cosas,
--                    posteada a 5200 y 5100 contra una sola deuda), cada pago
--                    lleva su parte PROPORCIONAL, repartida al centavo.
--           DE UNA CUENTA POR PAGAR A OTRA  la deuda que PASA de una partida
--                    a otra (la retención de un sub, de 2010 a 2020; un
--                    anticipo que se cruza con su papel cuando llega) se
--                    lleva su composición: lo que era servicio sigue siendo
--                    servicio en la partida nueva, en proporción (hasta
--                    cuatro saltos; lo que no se pueda seguir queda «sin
--                    clasificar», NUNCA «no servicio»). Un trabajo de 1,000
--                    con 100 retenidos y pagados después son 1,000 de
--                    servicio, no 900.
--           OTRO CAMINO  el servicio que no sale del banco ni de la tarjeta
--                    (lo paga Edgar de su bolsillo: 5200 o la partida del
--                    sub contra 2900; un empleado, contra 2250): la base no
--                    lo cuenta sola (no salió de una cuenta de la empresa),
--                    pero tampoco lo calla: sale en su fila («por otro
--                    camino»), el control 45 lo nombra, y si el CPA dice que
--                    cuenta (el pagador es la empresa, que lo reembolsa),
--                    Edgar lo marca «pagado»: entonces es un pago más, en la
--                    fecha de ese asiento.
--       · EL REPARTO, AL CENTAVO (determinista, en numeric exacto):
--           – Dentro de un asiento, cada línea de servicio (o de pago a una
--             cuenta por pagar) se reparte entre lo que la financia, en
--             proporción: efectivo, tarjeta, cuenta por pagar, otro. Para
--             un asiento normal (un origen, un destino) no hay nada que
--             repartir. Con varias líneas se reparte por ACUMULADO: la parte
--             de la línea n es redondear(acumulado hasta n × fracción) −
--             redondear(acumulado hasta n−1 × fracción). La suma de las
--             partes es el total redondeado UNA vez.
--           – Una partida por pagar tiene su COMPOSICIÓN: de lo devengado en
--             ella, cuánto fue servicio (toda su historia, con sus reversos
--             y sustitutos restando). Sus pagos se ordenan (fecha, asiento,
--             línea) y se reparten otra vez por acumulado: servicio hasta el
--             pago n = redondear(pagado hasta n × servicio ÷ devengado). El
--             pago de diciembre y el de enero de una misma factura suman, al
--             centavo, el servicio de la factura, cada uno en su año.
--           – Lo pagado a una partida SIN PAPEL (lo que traía QuickBooks en
--             la apertura; lo pagado de más, que queda a favor) no se sabe
--             si fue servicio: sale aparte, «sin clasificar», hasta que
--             Edgar lo marque (servicio o no). No se adivina.
--       · UN REVERSO RESTA EN EL AÑO DEL REVERSO (su fecha contable): es el
--         espejo del asiento, con sus mismos terceros y partidas, y aquí se
--         suma con su signo. Si el mes del pago sigue abierto, c2 lo fecha
--         el mismo día; si era de un año ya cerrado, cae en el año nuevo
--         (c2 lo postea como ajuste de un ejercicio anterior) y el control
--         lo avisa: el 1099 de aquel año quizá ya se presentó.
--       · DE QUIÉN ES CADA PAGO: del tercero de la línea (en el camino a
--         cuenta, el de la línea de la cuenta por pagar; y lo devengado
--         contra una cuenta por pagar, de quien nombra esa cuenta en su
--         asiento, que es como postea c3 un trabajo externo). Si la línea
--         de una cuenta por pagar no trae tercero pero SU PARTIDA sí dice
--         de quién es (las demás líneas de esa partida son todas de uno
--         solo), se toma ese: el pago a mano de la factura de un sub sin
--         poner su nombre es de ese sub. Y si Edgar la marcó con una ficha,
--         es del tercero de esa ficha (el único que tiene líneas en esa
--         cuenta, o el único que tiene). Si aun así no se sabe —lo normal
--         cuando el pago se clasifica en la Bandeja o por una propuesta de
--         la IA, que no ponen tercero—, no se puede saber a quién reportar:
--         sale en la fila «sin tercero», el control lo dice, y Edgar lo
--         ATRIBUYE a una ficha (fn_subs_marcar) sin tocar el libro.
--       · LA FECHA DEL PAGO (subs_config.fecha_pago). De fábrica «contable»:
--         la del asiento. Con «banco», la del movimiento del banco cuando
--         el asiento la trae (lo clasificado en la Bandeja): un Zelle del 30
--         de diciembre asentado en enero, con diciembre ya cerrado, cuenta
--         en diciembre. El control 82 dice, con cualquiera de los dos
--         criterios, qué pagos cambiarían de año con el otro. ▶ CPA.
--       · LAS MARCAS (subs_marcas): lo que el libro no dice de una línea y
--         Edgar sí sabe. De quién es (si la línea no trae tercero); que SÍ
--         es servicio (lo pagado a una partida de la apertura; un servicio
--         que entró a una cuenta sin la etiqueta); que NO lo es; o que se
--         pagó con TARJETA aunque saliera del banco (la de débito); o que
--         está PAGADO aunque no saliera del banco (otro camino, arriba). Con
--         su nota, quién y cuándo; una marca se sustituye o se retira, y la
--         anterior queda. El reverso de una línea marcada sigue su marca.
--       · EL UMBRAL (fn_subs_umbral): se reporta a quien se le pagó EL
--         UMBRAL O MÁS en el año. De fábrica 2000 (subs_config.umbral_1099),
--         y cada año puede llevar el suyo con su nota (subs_umbrales:
--         «confirmado con el CPA el …»). ▶ A CONFIRMAR CON EL CPA CADA
--         DICIEMBRE: ni la cifra ni si es «o más» se dan aquí por sabidos.
--       · QUÉ SALE (fn_subs_1099(año), una fila por ficha; y por tercero
--         sin ficha, y una por lo pagado sin tercero): pagado_servicio (en
--         efectivo), pagado_tarjeta, sin_clasificar, no_servicio, lo que
--         fue por OTRO CAMINO y lo DEVENGADO sin pagar; lo reportable y lo
--         excluido con su porqué (tarjeta, corporación, no se reporta); si
--         pasa del umbral; qué le falta (ficha, nombre legal, tipo de
--         entidad, dirección, TIN, W-9, decidir); si su estatus cambió en
--         el año (cambios); y cada pago que lo forma, con su asiento y su
--         línea (bajar al asiento). NADIE SE QUEDA FUERA CALLADO: quien
--         tiene algo sin clasificar, por otro camino, o servicio devengado
--         a su nombre, sale aunque su «pagado» sea cero.
--   (5) EL COI (fn_subs_coi / v_subs_coi): cada ficha (o tercero sin ficha)
--       con servicio pagado o devengado en el mes en curso o en los últimos
--       N días (subs_config.coi_ventana_dias, 90), con su COI: vigente,
--       «vence en N días» (subs_config.coi_aviso_dias, 30: la misma cuenta
--       que el chip de los documentos de la empresa: días = vence − hoy),
--       vencido o sin COI; y si el COI cubría el día de su último trabajo o
--       pago. El exento de WC con su documento se enseña, y cuenta como
--       cubierto solo si subs_config.coi_exento_basta (de fábrica, no: ▶ lo
--       decide Edgar con su aseguradora).
--   (6) LA HOJA DEL 1099 (fn_subs_1099_export(año)): una fila por ficha que
--       se reporta, pasa del umbral y está completa, con el TIN ENTERO, en
--       un CSV de columnas genéricas de la 1099-NEC, en inglés. Pide el
--       código del teléfono. Lo que pasa del umbral y NO está completo sale
--       aparte («pendientes»), con lo que le falta; ahí va también lo
--       pagado SIN NOMBRE (sea cuanto sea: puede ser de alguien que con eso
--       pasa del umbral) y quien pasaría del umbral contando lo que tiene
--       sin clasificar o por otro camino. Y la hoja trae los AVISOS del año
--       que la pueden dejar corta (los controles 30, 40, 45, 55, 60 y 82 en
--       rojo) y «completa» (verdadero solo sin pendientes ni avisos): no
--       frena —la decisión es de Edgar y del CPA—, pero quien la baja lo
--       lee. NADA SE MANDA A NINGÚN SITIO desde la base: la app baja el
--       archivo y Edgar lo sube al servicio de e-file que elija. Cada
--       exportación queda apuntada (subs_exportaciones, sin TIN, con sus
--       avisos), y el control avisa si el libro de ese año cambió después.
--   (7) LOS CONTROLES (fn_subs_control / v_subs_control: orden, control,
--       nivel «cuadre» | «aviso», ok, detalle en llano):
--         10 cada línea de servicio del año, repartida entera (cuadre)
--         12 cada pago a una cuenta por pagar, repartido entero (cuadre)
--         20 las fichas, coherentes: cada tercero existe, cada TIN anotado
--            tiene su fila y al revés, ninguno con mala forma (cuadre)
--         30 un tercero sin ficha con servicio pagado, sin clasificar, por
--            otro camino o devengado
--         40 servicio pagado (o un pago sin clasificar a una cuenta por
--            pagar) sin tercero: no se sabe a quién reportar
--         45 servicio (o sin clasificar) que no se pagó desde el banco ni
--            la tarjeta: otro camino. Dice de quién, y que se marca «pagado»
--            si el CPA dice que cuenta
--         50 una ficha que se reporta y pasa del umbral, incompleta (sin
--            W-9, sin TIN, sin dirección, sin tipo o sin nombre legal)
--         55 fichas por decidir con pagos en el año
--         60 pagos sin clasificar (de la apertura, a favor, por una cuenta
--            sin etiqueta), tengan o no ficha, salvo a quien no se le reporta
--            (y a ese, lo que se le pagó en los días en que SÍ se le
--            reportaba —su ficha cambió después—: eso sí se pregunta)
--         70 alguien con servicio este mes sin COI vigente
--         75 un COI que vence pronto de alguien con servicio reciente
--         80 un reverso de este año que resta un pago de un año anterior
--         82 pagos que el banco fecha en otro año que el libro (qué cambia
--            con el otro criterio de fecha)
--         85 lo exportado de un año ya no es lo que el libro dice
--         88 el umbral del año, sin confirmar
--         90 las protecciones de la capa, los candados del bucket y que el
--            TIN no deja estadísticas (cuadre)
--         92 el registro del servidor no guarda los parámetros de las órdenes
--            (si los guardara, un TIN tecleado iría a su log)
--         95 cada archivo registrado sigue en Storage y mide lo mismo
--       Cuando un control nombra lo suyo (quién, qué asiento) y la lista no
--       cabe en el detalle, enseña los que caben, enteros, y acaba en «… y N
--       más»: la lista entera está en la página (fn_subs_1099, fn_subs_pagos,
--       fn_subs_coi).
--       fn_subs_cierre(período) da las dos filas que el cierre (c9) enseña:
--       160 «subs: COI vigente de cada sub pagado en el mes» (la de siempre,
--       con los datos de aquí: cuenta a quien tiene NOMBRE; el servicio que
--       el libro no dice de quién es se dice aparte, por su monto, sin
--       contarlo como un sub) y 179 «subs: W-9 y TIN de cada sub con pago
--       en el mes». Las dos son AVISOS: no detienen el cierre.
--       LAS FECHAS que escribe esta capa van como las de la cédula
--       (1-oct-2026): ni 01/10/2026 —que en un teléfono de aquí se lee 10 de
--       enero— ni 2026-10-01.
--
-- Decisiones de diseño (lo que el encargo dejaba abierto):
--   · LA FICHA ES DE LA PERSONA, NO DEL TERCERO (arriba, 1).
--   · LA MARCA Y NO UN ASIENTO NUEVO. Poner el tercero que falta rehaciendo
--     el asiento (reversar y volver a clasificar) son dos asientos más por
--     cada pago en un libro que no se borra, y c3 no admite tercero en la
--     línea de gasto de un recibo. La marca dice lo mismo sin tocar el
--     libro, con quién y cuándo, y se ve en cada pago.
--   · LO DEVENGADO NO CUENTA; LO PAGADO SÍ. Un trabajo externo sin pagar no
--     está en el 1099 (base caja), pero sí en el COI (el sub trabajó).
--   · EL MATERIAL QUE FACTURA UN SUB junto con su servicio, si entró a una
--     cuenta sin la etiqueta 1099 (5100), no se da por fuera callado: se
--     PREGUNTA (sale «sin clasificar» hasta que se marque). ▶ CPA: las
--     instrucciones del 1099-NEC hablan de piezas y materiales del propio
--     servicio; si dice que cuentan, se marca «servicio» (o la factura del
--     sub entra entera a 5200); si dice que no, 5100 se pone en
--     cuentas_no_servicio y deja de preguntar.
--   · LO DUDOSO NUNCA ES «NO SERVICIO». Lo que pasa de una cuenta por pagar
--     a otra hereda lo que era; lo que no se puede seguir, lo de la
--     apertura, lo pagado de más y lo que va por una cuenta sin etiqueta a
--     alguien con ficha quedan «sin clasificar», a la vista, con su aviso.
--     «No servicio» es solo lo que el libro dice que no lo es (una cuenta
--     de material contra su propia partida) o lo que Edgar marca.
--   · EL ESTATUS CON FECHA, Y DICHO POR EDGAR. La base no adivina desde
--     cuándo vale un cambio (no hay forma: el W-9 nuevo llega cuando llega):
--     lo pide. Y no deja reescribir años enteros sin que alguien lo diga.
--   · «PAGADO POR OTRO CAMINO» ES UNA MARCA, no una regla: la base no sigue
--     el reembolso de la 2900 hasta el banco (mezcla recibos de todo tipo,
--     y el día del reembolso no es el del pago al sub). ▶ CPA: ¿cuenta lo
--     que Edgar paga de su bolsillo y la empresa le devuelve?
--   · EL COI SE MIRA EL DÍA DEL TRABAJO O DEL PAGO, no el último día del
--     mes: un COI que venció el día 20 cubría el pago del día 5. La fila 160
--     de antes comparaba con el fin del mes.
--   · LA HOJA NO LLEVA AL PAGADOR (el nombre y el EIN de la empresa): el
--     servicio de e-file ya tiene su perfil. Y no lleva lo retenido (caja 4:
--     0.00): la app no retiene a nadie.
--
-- LA SEGURIDAD (la regla de c2, B.20, y lo que c4, c6, c8, c9, c10, c11 y
-- c12 sellan):
--   · NINGUNA función de aquí es SECURITY DEFINER. Las que llama la
--     pantalla son SECURITY INVOKER, sin EXECUTE para public, anon ni
--     service_role, con EXECUTE para authenticated y es_dueno() por dentro
--     (fn_subs_exigir_dueno): leen el libro con la policy de cada tabla
--     (solo el dueño) y escriben las tablas de c14 con la policy de
--     escritura del dueño. No escriben el libro ni ninguna tabla ajena. Así
--     «permisos» de c2 sigue en verde. Las auxiliares de las vistas no
--     frenan a nadie con un error: a quien no es el dueño no le devuelven
--     nada (el equipo no ve nada de c14: es lo que cobra cada compañero).
--   · «POR LA API» se decide por el rol con que entró la petición (el
--     ajuste «role» de la sesión, que PostgREST fija), no solo por
--     current_user: llamada desde dentro de otra función con permisos de
--     dueño, una función de aquí sigue pidiendo al dueño y su código.
--   · EL CÓDIGO DEL TELÉFONO (aal2) se pide SIEMPRE para guardar un TIN,
--     para exportar y para subir o leer un archivo, tenga o no factor la
--     cuenta (s1 lo pide en toda la API solo a quien tiene factor): sin el
--     código activo no hay TIN ni archivos. La función contesta como s1
--     (403, código «MFA»): la app ya sabe pedirlo.
--   · fn_subs_pegado y fn_subs_precondiciones: sin API (solo el SQL Editor).
--     Al revés, fn_subs_tin_guardar (con un TIN) y fn_subs_1099_export: solo
--     por la API (el dueño con su código). Desde el SQL Editor la hoja
--     contesta 42501; guardar un TIN contesta «no se guardó» SIN error (un
--     error dejaría el TIN tecleado en el registro del servidor).
--   · Las tablas nacen con RLS y policies solo-dueño, y con la guarda de
--     c6, c9, c10 y c12: un trigger (fn_subs_guarda) que solo deja escribir
--     con la marca de la transacción (mx_subs.escribe = la tabla) que ponen
--     las funciones de aquí; a mano, aunque sea el dueño por la API, MX003.
--     Un archivo, una marca, el historial y una exportación son rastro: no
--     se editan ni se borran; lo único que les pasa es quedar retirados, una
--     vez.
--   · Las vistas son security_invoker y leen solo funciones y tablas de
--     aquí; ninguna toca subs_tin; de periodos y de cuentas no fijan estado,
--     cadena_al_cerrar, activa ni saldo_normal (c2-pruebas las reescribe).
--   · Nada lleva un prefijo que otra capa sella ni de la otra sesión que
--     escribe esta base: aquí todo es fn_subs_* / subs_* / v_subs_*.
--     es_dueno() no se toca. c10 se lee al vuelo (jornal_repartos, si está)
--     y solo para saber qué asientos son un jornal.
--
-- LOS ERRORES CON NOMBRE (conta.js los enseña tal cual; ninguno nuevo):
--   MX000  falta algo que este archivo da por hecho: no se aplica nada
--          (fn_subs_precondiciones dice qué)
--   MX003  las tablas de c14 solo las escriben sus funciones (la guarda); lo
--          que es rastro no se edita ni se borra
--   MX004  una cuenta de la configuración que no existe en el plan
--   MX005  un valor mal: el umbral, los días, la forma del TIN (el mensaje
--          NO repite el TIN), los bytes de un archivo
--   MX008  no procede: el tercero ya está en otra ficha, ese TIN ya está en
--          otra ficha, la línea ya dice de quién es, es un reverso (se marca
--          el original), la línea es del banco o de la tarjeta, el archivo
--          ya está registrado con otros datos o ya estaba retirado. Y DOS
--          QUE PIDEN ALGO (la pantalla lo lee en el HINT del error):
--            hint «desde»   la ficha ya tiene pagos con el estatus de antes:
--                           di desde cuándo vale lo nuevo ("desde") o que
--                           era un error ("corrige": true). El DETAIL trae,
--                           en JSON, {pide, pagado, primer_pago,
--                           ultimo_pago, desde_minimo}
--            hint «corrige» se cambia un TIN por otro distinto en una ficha
--                           con pagos: confirma ("corrige": true)
--   22023  entrada mal formada: falta un dato, una clave desconocida, un
--          tipo de entidad o un estado que no existe, una ruta que no es la
--          de la ficha, el archivo no está en Storage, un campo de texto
--          que es entero un TIN. Ninguno repite lo tecleado
--   42501  permiso: solo el dueño; anon y service_role, nada; y sacar la
--          hoja desde el SQL Editor (se hace en la app)
--   PGRST  (403, código «MFA», como s1) falta el código del teléfono para
--          guardar un TIN o exportar
--   55P03  (de Postgres, «lock timeout») la app estaba usando las tablas de
--          c14 mientras se pegaba: no se aplicó nada, se vuelve a pegar
--
-- Lo que este archivo NO toca: c1..c13, s1, p1, es_dueno(), docs/sql, el
-- libro (solo lo LEE: asientos, asiento_lineas, cuentas, periodos), las
-- tablas de la app y de otras capas (lee proveedores, perfiles,
-- puente_cuentas, trabajos_externos, externos_equipo y, si está,
-- jornal_repartos). No pone índices, triggers ni columnas en tablas ajenas;
-- solo una llave foránea DESDE subs_marcas hacia la línea del libro que
-- marca (como banco_casado_lineas de c6). No manda nada a ningún sitio.
--
-- Cómo se instala (Edgar, en este orden):
--   1. SQL Editor → pegar ESTE archivo entero → Run. Al final sale una
--      tabla: la configuración (el umbral), las tablas y las vistas, el
--      bucket y sus candados, las fichas, el 1099 del año en una línea, el
--      control, qué falta y el paso siguiente. Si algo de lo que da por
--      hecho falta, para con MX000 y no queda nada. Con la pantalla de
--      Contabilidad cerrada (si alguien la está leyendo, 55P03: se vuelve a
--      pegar).
--      Si justo entonces la app está leyendo o subiendo fotos (Storage
--      ocupado), también para con 55P03 y no queda nada a medias: los
--      candados del bucket entran con todo lo demás o no entra nada.
--   2. LAS FILAS 160 Y 179 DEL CIERRE las pone c9-cierre.sql, no este
--      archivo: el c9 que las trae nombra la 179 en su cabecera («179 subs
--      (c14, si está)»). La tabla del final del paso 1 dice cuál es tu
--      caso: si el cierre de esta base ya mira los subs, no hay nada que
--      hacer; si todavía no, se vuelve a pegar el docs/conta/c9-cierre.sql
--      QUE LA NOMBRE (si el que tienes no la nombra, volver a pegarlo no
--      cambia nada: el cierre sigue con la 160 de antes, lo demás funciona
--      entero, y la prueba del cierre sale «omitida» diciéndolo).
--   3. SQL Editor → pegar docs/conta/c14-pruebas.sql → sus 48 filas, todas
--      en true (las «omitida» dicen por qué; no es un fallo).
--   4. En la app: Contabilidad → Subs y 1099. Una ficha por cada sub y cada
--      ayudante, con su W-9, su TIN y su COI.
--
-- Lo que llama la pantalla (RPC, como el dueño; las que escriben, con POST):
--   fn_subs_ficha(p jsonb)                          alta o cambio de una ficha
--        p: {id?, nombre_legal, nombre_comercial, tipo_entidad, reporta,
--            reporta_nota, direccion, direccion2, ciudad, estado, zip,
--            wc_exento, notas, activa, tercero?: {tipo, id},
--            desde?: "AAAA-MM-DD" (desde cuándo vale el estatus nuevo),
--            corrige?: true (lo de antes estaba mal: vale para todo)}
--        MX008 con HINT «desde» si la ficha ya tiene pagos y cambia su
--        estatus sin decir ninguna de las dos (el DETAIL trae los datos)
--   fn_subs_tramo_retirar(p_tramo, p_motivo)        retira un tramo mal puesto
--   fn_subs_tercero(p_ficha, p_tipo, p_id, p_quitar)  enlaza (o suelta) un tercero del libro
--   fn_subs_tin_guardar(p_ficha, p jsonb)           {tin, tipo: "ssn"|"ein", corrige?: true} | {quitar: true}   (aal2)
--        devuelve {ficha, guardado, quitado, tin: {tipo, mascara, ultimos4}};
--        MX008 con HINT «corrige» si cambia un TIN por otro con pagos ya hechos
--   fn_subs_archivo(p_ficha, p jsonb)               {clase: "w9"|"coi"|"wc_exento", ruta, sha256, bytes, fecha?, vence?, nota?}
--   fn_subs_archivo_retirar(p_archivo, p_motivo)
--   fn_subs_marcar(p_asiento, p_orden, p jsonb)     {ficha?, trato?: "servicio"|"no_servicio"|"tarjeta"|"pagado", nota} | {quitar: true, nota}
--   fn_subs_config(p jsonb)                         {umbral_1099, entidades_no_reporta, cuentas_por_pagar, cuentas_no_pago,
--                                                    coi_aviso_dias, coi_ventana_dias, coi_exento_basta,
--                                                    fecha_pago: "contable"|"banco", cuentas_no_servicio}
--   fn_subs_umbral_confirmar(p_anio, p_umbral, p_nota)
--   fn_subs_1099(p_anio) / fn_subs_pagos(p_anio) / fn_subs_antes(p_anio)   solo leen
--   fn_subs_1099_export(p_anio, p_opciones)         la hoja, con el TIN entero   (aal2); trae además «pendientes»,
--                                                   «avisos» [{orden, control, detalle}] y «completa»
--   fn_subs_coi(p_desde, p_hasta, p_al) / fn_subs_control(p_anio) / fn_subs_cierre(p_periodo)
-- Y lee: v_subs_fichas, v_subs_archivos, v_subs_1099 y v_subs_pagos
-- (filtradas por anio), v_subs_coi, v_subs_control; y las tablas
-- subs_config, subs_umbrales, subs_historial, subs_exportaciones y
-- subs_tramos. Montos en dólares, numeric(14,2). La pantalla no suma nada.
--
-- ▶ PARA EL CPA Y PARA EDGAR (no frena nada; se dice):
--   · El umbral del año y si es «el umbral o más» (cada diciembre).
--   · ¿A qué entidades no se les reporta (S-corp y C-corp), y qué
--     excepciones hay (abogados…)?
--   · ¿El material que factura un sub con su servicio se reporta? (Mientras
--     no se diga, se pregunta pago por pago; con «no», 5100 va a
--     cuentas_no_servicio.)
--   · Los honorarios legales y contables (6600): ¿se reportan? Hoy la cuenta
--     no lleva la etiqueta 1099; lo pagado por ella a alguien con ficha se
--     pregunta. Si es que sí siempre, se etiqueta la cuenta en el plan.
--   · Lo que Edgar (o un empleado) paga de su bolsillo a un sub y la empresa
--     le devuelve: ¿cuenta para el 1099? Si sí, se marca «pagado».
--   · La fecha del pago: ¿la del libro o la del banco? (Un Zelle del 30 de
--     diciembre asentado en enero.) De fábrica, la del libro; el control 82
--     dice qué cambiaría.
--   · Quien cambia de persona física a S-corp a mitad de año: ¿dos 1099 (uno
--     por contribuyente) o uno? Aquí, lo limpio son dos fichas.
--   · Los ayudantes por hora de 2026: ¿1099 o empleados (F.S. 440.10)? Y el
--     qualifier: ¿W-2 o 1099? (su ficha nace «por decidir»).
--   · ¿Al exento de WC le basta su exención, o hace falta además su COI de
--     responsabilidad?
--   · El formato exacto de la hoja del servicio de e-file que se elija
--     (IRIS, Track1099…): las columnas de aquí son las genéricas.
-- =====================================================================
-- (Lo primero, como en c4, c6, c10 y c12: el pegado espera un candado como
-- mucho medio segundo. Con la app leyendo, para con 55P03 («lock timeout»),
-- no se aplica nada y se vuelve a pegar. Dura lo que dura el pegado.)
set local lock_timeout = '500ms';


-- ---------------------------------------------------------------------
-- 0. Las guardas, y lo que este archivo da por hecho (MX000 sin tocar nada)
-- ---------------------------------------------------------------------
-- Lo que falta para pegar c14, en llano (nulo = nada). La usan la
-- precondición de abajo y las pruebas.
create or replace function public.fn_subs_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
  v_v     bigint;
  c_tablas constant text[] := array['subs_config', 'subs_umbrales', 'subs_fichas', 'subs_terceros', 'subs_tin', 'subs_archivos',
                                    'subs_marcas', 'subs_historial', 'subs_exportaciones', 'subs_tramos'];
  c_vistas constant text[] := array['v_subs_fichas', 'v_subs_archivos', 'v_subs_1099', 'v_subs_pagos', 'v_subs_coi', 'v_subs_control'];
  c_fn     constant text[] := array['fn_subs_precondiciones', 'fn_subs_por_api', 'fn_subs_exigir_dueno', 'fn_subs_ve',
                                    'fn_subs_exigir_codigo', 'fn_subs_guarda', 'fn_subs_tin_forma', 'fn_subs_usd', 'fn_subs_lista', 'fn_subs_hoy',
                                    'fn_subs_dia', 'fn_subs_libro_desde', 'fn_subs_anios', 'fn_subs_umbral', 'fn_subs_mascara',
                                    'fn_subs_tercero_nombre', 'fn_subs_cuenta_clase', 'fn_subs_storage', 'fn_subs_mes', 'fn_subs_fichas',
                                    'fn_subs_ficha', 'fn_subs_tramo_retirar', 'fn_subs_tercero', 'fn_subs_tin_guardar', 'fn_subs_archivo',
                                    'fn_subs_archivo_retirar', 'fn_subs_marcar', 'fn_subs_calculo', 'fn_subs_pagos', 'fn_subs_antes',
                                    'fn_subs_estado_al', 'fn_subs_1099', 'fn_subs_1099_export', 'fn_subs_config',
                                    'fn_subs_umbral_confirmar', 'fn_subs_coi', 'fn_subs_control', 'fn_subs_cierre', 'fn_subs_pegado'];
begin
  foreach v_x in array array['es_dueno()', 'fn_desde_editor()', 'fn_fecha_miami(timestamptz)', 'fn_libro_version()'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'periodos', 'asientos', 'asiento_lineas', 'perfiles', 'proveedores', 'puente_cuentas',
                             'trabajos_externos', 'externos_equipo'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if to_regprocedure('auth.uid()') is null or to_regprocedure('auth.jwt()') is null then
    v_falta := v_falta || 'auth.uid() y auth.jwt() (Supabase Auth)'::text;
  end if;
  if cardinality(v_falta) > 0 then
    return format('c14 se pega después de c1, c2 y c3 (y de c4, c6, c7, s1, p1, c8, c9, c10, c11 y c12 si se usan), con las tablas '
                  'de la app: falta %s.', array_to_string(v_falta, ', '));
  end if;
  -- La versión de c2 que va con esta capa (la del tiempo en producción).
  execute 'select public.fn_libro_version()' into v_v;
  if coalesce(v_v, 0) < 2026100201 then
    return format('el c2-libro.sql pegado es anterior (marca %s; esta capa pide 2026100201): vuelve a pegar c2-libro.sql.', v_v);
  end if;
  -- Las columnas que esta capa lee por su nombre.
  select string_agg(x.t || '.' || x.c, ', ' order by x.t, x.c) into v_x
    from (values ('asientos', 'numero'), ('asientos', 'cadena_pos'), ('asientos', 'fecha_contable'), ('asientos', 'anio'),
                 ('asientos', 'periodo'), ('asientos', 'tipo'), ('asientos', 'reversa_a'), ('asientos', 'descripcion'),
                 ('asientos', 'origen_tabla'), ('asientos', 'origen_id'), ('asientos', 'procedencia'), ('asientos', 'reversible'),
                 ('asientos', 'camino'),
                 ('asiento_lineas', 'asiento_id'), ('asiento_lineas', 'orden'), ('asiento_lineas', 'cuenta'),
                 ('asiento_lineas', 'monto'), ('asiento_lineas', 'proyecto_id'), ('asiento_lineas', 'memo'),
                 ('asiento_lineas', 'tercero_tipo'), ('asiento_lineas', 'tercero_id'), ('asiento_lineas', 'partida_tabla'),
                 ('asiento_lineas', 'partida_id'),
                 ('cuentas', 'codigo'), ('cuentas', 'nombre'), ('cuentas', 'tipo'), ('cuentas', 'etiqueta_fiscal'),
                 ('cuentas', 'regla_obra'), ('cuentas', 'imputable'),
                 ('periodos', 'periodo'), ('periodos', 'tipo'), ('periodos', 'desde'), ('periodos', 'hasta'),
                 ('proveedores', 'id'), ('proveedores', 'nombre'), ('proveedores', 'externo_id'),
                 ('perfiles', 'id'), ('perfiles', 'nombre'), ('perfiles', 'rol'),
                 ('puente_cuentas', 'rol'), ('puente_cuentas', 'cuenta'),
                 ('trabajos_externos', 'fecha'), ('trabajos_externos', 'costo'), ('trabajos_externos', 'externo_id'),
                 ('trabajos_externos', 'proveedor_id'), ('trabajos_externos', 'descripcion'),
                 ('externos_equipo', 'id'), ('externos_equipo', 'nombre')) as x(t, c)
   where not exists (select 1 from information_schema.columns k
                      where k.table_schema = 'public' and k.table_name = x.t and k.column_name = x.c);
  if v_x is not null then
    return format('faltan columnas que esta capa lee: %s. ¿Es la base de la app, con c3 pegado?', v_x);
  end if;
  -- La llave de la línea del libro (la marca de un pago cuelga de ella).
  if not exists (select 1 from pg_constraint k
                  where k.conrelid = 'public.asiento_lineas'::regclass and k.contype = 'p'
                    and (select array_agg(a.attname::text order by u.n)
                           from unnest(k.conkey) with ordinality u(att, n)
                           join pg_attribute a on a.attrelid = k.conrelid and a.attnum = u.att) = array['asiento_id', 'orden']) then
    return 'la línea del libro no tiene la llave (asiento_id, orden) que esta capa usa: vuelve a pegar c2-libro.sql.';
  end if;
  -- Una tabla con el nombre de las de c14 que no sea de c14: se para antes de
  -- tocar nada (la lección de c8 con ia_propuestas).
  foreach v_x in array array['subs_config:umbral_1099', 'subs_umbrales:umbral', 'subs_fichas:tin_ultimos4', 'subs_terceros:ficha_id',
                             'subs_tin:ficha_id', 'subs_archivos:sha256', 'subs_marcas:trato', 'subs_historial:ficha_id',
                             'subs_exportaciones:huella', 'subs_tramos:hasta'] loop
    if to_regclass('public.' || split_part(v_x, ':', 1)) is not null
       and not exists (select 1 from information_schema.columns
                        where table_schema = 'public' and table_name = split_part(v_x, ':', 1) and column_name = split_part(v_x, ':', 2)) then
      return format('la tabla %s ya existe en esta base y no es la de c14 (no tiene la columna %s): otra cosa usa ese nombre. No la '
                    'toco; avisa antes de seguir.', split_part(v_x, ':', 1), split_part(v_x, ':', 2));
    end if;
  end loop;
  -- Una vista o una función con nombre de c14 que no sea de c14 (otra sesión
  -- escribe esta misma base): «create or replace» la pisaría sin avisar.
  select string_agg(x.que, ', ' order by x.que) into v_x
    from (select 'la vista ' || c.relname as que
            from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind in ('v', 'm', 'r') and c.relname = any (c_vistas)
             and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c14: %'
          union all
          select 'la función ' || p.oid::regprocedure::text
            from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.proname = any (c_fn)
             and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c14: %') x;
  if v_x is not null then
    return format('ya hay en esta base, con nombre de c14 y sin ser de c14: %s. No lo piso; avisa antes de seguir.', v_x);
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: las fichas y el 1099 son del dueño.';
  end if;
  -- Nada ajeno colgado de las vistas de c14 (se borran y se rehacen).
  select string_agg(distinct format('la vista %s', dc.oid::regclass), ', ') into v_x
    from pg_depend d
    join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
    join pg_class dc on dc.oid = rw.ev_class
    join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
   where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname = any (c_vistas)
     and dc.oid <> cv.oid
     and not (dc.relnamespace = 'public'::regnamespace and dc.relname = any (c_vistas));
  if v_x is not null then
    return format('%s depende(n) de las vistas de c14, que al pegarlo se borran y se rehacen: guarda su definición, bórralas, '
                  'pega c14 y vuelve a crearlas.', v_x);
  end if;
  return null;
end $$;
revoke execute on function public.fn_subs_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_subs_precondiciones() is 'c14: lo que falta para pegar c14-subs.sql (nulo = nada): c1, c2 (marca 2026100201) y c3, las tablas y columnas del libro y de la app que lee, la llave de la línea del libro, Supabase Auth, el SQL Editor, un dueño activo, nada ajeno con nombre de c14 y nada ajeno sobre sus vistas.';

do $$
declare
  v text;
begin
  v := public.fn_subs_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c14-subs NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1, c2, c3, c4, c6, c7, s1, p1, c8, c9, c10, c11, c12 y después este archivo (pruebas/conta/README.md, §0).';
  end if;
end $$;

-- ¿Entró la petición por la API? Por el rol con que entró (el ajuste «role»
-- de la sesión, que PostgREST fija a authenticated, anon o service_role) o
-- por el rol de ahora: dentro de una función con permisos de dueño
-- current_user cambia, y el ajuste no. El SQL Editor y pg_cron entran sin
-- «set role» (none) como el dueño de la base.
create or replace function public.fn_subs_por_api() returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select current_user in ('authenticated', 'anon', 'service_role')
      or coalesce(nullif(current_setting('role', true), 'none'), session_user::text) in ('authenticated', 'anon', 'service_role', 'authenticator')
$$;
revoke execute on function public.fn_subs_por_api() from public, anon, service_role;
grant  execute on function public.fn_subs_por_api() to authenticated;
comment on function public.fn_subs_por_api() is 'c14: verdadero si la petición entró por la API (el rol con que entró o el de ahora es authenticated, anon o service_role); falso en el SQL Editor y en pg_cron.';

-- ¿Quién llama por la API? Solo el dueño. Desde el SQL Editor o pg_cron pasa.
create or replace function public.fn_subs_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if fn_subs_por_api() and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501',
      message = 'Las fichas de los subs, sus papeles y el 1099 los ve y los toca solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_subs_exigir_dueno() from public, anon, service_role;
grant  execute on function public.fn_subs_exigir_dueno() to authenticated;
comment on function public.fn_subs_exigir_dueno() is 'c14: la guarda de lo que llama la pantalla: por la API solo el dueño (es_dueno); el SQL Editor y pg_cron pasan.';

-- ¿Ve quien mira? Lo mismo, sin error: las auxiliares de las vistas no
-- frenan a nadie; a quien no es el dueño no le devuelven nada.
create or replace function public.fn_subs_ve() returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select not public.fn_subs_por_api() or coalesce(es_dueno(), false)
$$;
revoke execute on function public.fn_subs_ve() from public, anon, service_role;
grant  execute on function public.fn_subs_ve() to authenticated;
comment on function public.fn_subs_ve() is 'c14: verdadero para el dueño por la API y para el SQL Editor; las auxiliares de las vistas no devuelven nada a los demás.';

-- EL CÓDIGO DEL TELÉFONO. Por la API, la sesión tiene que haber pasado el
-- segundo factor (su token dice aal2), tenga o no factor la cuenta. Contesta
-- como la guarda de s1 (403, código «MFA»): la app ya sabe pedirlo.
create or replace function public.fn_subs_exigir_codigo() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if fn_subs_por_api() and coalesce((select auth.jwt() ->> 'aal'), '') <> 'aal2' then
    raise sqlstate 'PGRST' using
      message = json_build_object(
        'code',    'MFA',
        'message', 'Falta el código del teléfono: el TIN y la hoja del 1099 solo se tocan con él. Actívalo en Contabilidad → '
                   'Conexiones y seguridad (si no lo tienes) y entra otra vez escribiéndolo.',
        'details', 'Esta sesión no pasó el segundo factor (aal1).',
        'hint',    'mfa')::text,
      detail = json_build_object('status', 403)::text;
  end if;
end $$;
revoke execute on function public.fn_subs_exigir_codigo() from public, anon, service_role;
grant  execute on function public.fn_subs_exigir_codigo() to authenticated;
comment on function public.fn_subs_exigir_codigo() is 'c14: por la API, la sesión tiene que haber pasado el código del teléfono (aal2); si no, 403 con el código MFA, como la guarda de s1. El SQL Editor pasa.';


-- ---------------------------------------------------------------------
-- 1. Las tablas (nacen cerradas: solo el dueño lee; escribe solo el dueño
--    por las funciones de aquí, con la marca de la transacción). Montos en
--    dólares, numeric(14,2). Llaves foráneas entre tablas de c14 y hacia la
--    línea del libro que una marca nombra; a proveedores y a perfiles NO
--    (son de c3 y de la app: no se les cuelga nada que cambie cómo se
--    borran). Para crecer, «add column if not exists».
-- ---------------------------------------------------------------------
-- La configuración: una sola fila.
create table if not exists public.subs_config (
  id                    int           primary key,
  umbral_1099           numeric(14,2) not null default 2000,
  entidades_no_reporta  text[]        not null default array['c_corp', 's_corp'],
  cuentas_por_pagar     text[]        not null default array['2010', '2020'],
  cuentas_no_pago       text[]        not null default '{}',
  coi_aviso_dias        int           not null default 30,
  coi_ventana_dias      int           not null default 90,
  coi_exento_basta      boolean       not null default false,
  fecha_pago            text          not null default 'contable',
  cuentas_no_servicio   text[]        not null default '{}',
  actualizado           timestamptz   not null default now(),
  actualizado_por       uuid,
  constraint subs_config_una       check (id = 1),
  constraint subs_config_umbral    check (umbral_1099 >= 0 and umbral_1099 < 1000000000),
  constraint subs_config_dias      check (coi_aviso_dias between 0 and 365 and coi_ventana_dias between 1 and 730),
  constraint subs_config_entidades check (entidades_no_reporta <@ array['individual', 'sole_proprietor', 'llc_un_socio', 'llc_sociedad',
                                                                        'sociedad', 's_corp', 'c_corp', 'otro'])
);
-- (para crecer: lo que una base con la primera versión de esta capa todavía no tiene)
alter table public.subs_config add column if not exists fecha_pago text not null default 'contable';
alter table public.subs_config add column if not exists cuentas_no_servicio text[] not null default '{}';
alter table public.subs_config drop constraint if exists subs_config_fecha_pago;
alter table public.subs_config add constraint subs_config_fecha_pago check (fecha_pago in ('contable', 'banco'));
comment on table public.subs_config is 'c14: la configuración de los subs y del 1099 (una fila): umbral_1099 (de fábrica 2000: se reporta a quien se le pagó eso o más en el año; ▶ se confirma con el CPA cada diciembre, y cada año puede llevar el suyo en subs_umbrales), entidades_no_reporta (los tipos de entidad a los que no se les reporta salvo excepción en su ficha: s_corp y c_corp), cuentas_por_pagar (las cuentas cuya deuda se sigue hasta su pago: 2010 y 2020), cuentas_no_pago (cuentas 10xx que no pagan a nadie: 1020, los cobros de Stripe en tránsito), coi_aviso_dias (con cuántos días se avisa de un COI que vence: 30), coi_ventana_dias (cuánto atrás se mira quién tuvo servicio: 90) coi_exento_basta (si al exento de WC con su documento le basta, sin COI: de fábrica no) y fecha_pago (con qué fecha cuenta un pago para el 1099: contable = la del asiento, de fábrica; banco = la que dijo el banco, cuando el asiento nació de un movimiento suyo. ▶ Lo decide el CPA) y cuentas_no_servicio (cuentas de gasto que NUNCA son servicio aunque se le paguen a alguien con ficha —el material que revende un sub, si el CPA dice que no cuenta—: de fábrica ninguna; lo pagado a alguien con ficha por cualquier otra cuenta de gasto sin la etiqueta 1099 se pregunta). Se cambia con fn_subs_config.';

-- El umbral de un año, cuando Edgar lo confirma con el CPA (o es otro).
create table if not exists public.subs_umbrales (
  anio            int           primary key,
  umbral          numeric(14,2) not null,
  nota            text          not null,
  confirmado_el   timestamptz   not null default now(),
  confirmado_por  uuid,
  historial       jsonb         not null default '[]'::jsonb,
  constraint subs_umbrales_forma check (anio between 2020 and 2100 and umbral >= 0 and umbral < 1000000000 and btrim(nota) <> ''
                                        and jsonb_typeof(historial) = 'array')
);
comment on table public.subs_umbrales is 'c14: el umbral del 1099 de un año concreto, confirmado (con el CPA): el año, el umbral, la nota (quién lo dijo y cuándo), quién lo anotó y cuándo, y lo que decía antes (historial). Un año sin fila usa subs_config.umbral_1099 y sale «sin confirmar» en el control. Se escribe con fn_subs_umbral_confirmar.';

-- La ficha fiscal: una por persona o empresa a la que se le paga como
-- contratista. Del TIN, solo su tipo y sus 4 últimos (entero, en subs_tin).
create table if not exists public.subs_fichas (
  id                uuid        primary key default gen_random_uuid(),
  nombre_legal      text,
  nombre_comercial  text,
  tipo_entidad      text,
  reporta           text        not null default 'por_decidir',
  reporta_nota      text,
  direccion         text,
  direccion2        text,
  ciudad            text,
  estado            text,
  zip               text,
  tin_tipo          text,
  tin_ultimos4      text,
  tin_guardado_el   timestamptz,
  tin_guardado_por  uuid,
  wc_exento         boolean     not null default false,
  notas             text,
  activa            boolean     not null default true,
  creado_el         timestamptz not null default now(),
  creado_por        uuid,
  actualizado_el    timestamptz not null default now(),
  actualizado_por   uuid,
  constraint subs_fichas_nombre  check (nombre_legal is null or btrim(nombre_legal) <> ''),
  constraint subs_fichas_entidad check (tipo_entidad is null or tipo_entidad in ('individual', 'sole_proprietor', 'llc_un_socio',
                                                                                 'llc_sociedad', 'sociedad', 's_corp', 'c_corp', 'otro')),
  constraint subs_fichas_reporta check (reporta in ('si', 'no', 'por_decidir')),
  constraint subs_fichas_estado  check (estado is null or estado ~ '^[A-Z]{2}$'),
  constraint subs_fichas_zip     check (zip is null or zip ~ '^[0-9]{5}(-[0-9]{4})?$'),
  constraint subs_fichas_tin     check ((tin_tipo is null) = (tin_ultimos4 is null) and (tin_tipo is null or tin_tipo in ('ssn', 'ein'))
                                        and (tin_ultimos4 is null or tin_ultimos4 ~ '^[0-9]{4}$'))
);
comment on table public.subs_fichas is 'c14: la ficha fiscal de cada persona o empresa a la que se le paga como contratista (un sub, un ayudante por hora): lo de su W-9 (nombre_legal, nombre_comercial, tipo_entidad: individual, sole_proprietor, llc_un_socio, llc_sociedad, sociedad, s_corp, c_corp u otro; direccion, direccion2, ciudad, estado de dos letras, zip), si se le reporta el 1099 (reporta: si | no | por_decidir, con reporta_nota), del TIN solo su tipo (ssn | ein) y sus 4 últimos (tin_tipo, tin_ultimos4, cuándo y quién lo guardó: el TIN entero está en subs_tin y no sale por ninguna vista), si está exento de WC (wc_exento; su documento, en subs_archivos), notas, si está activa, y quién y cuándo. Sus terceros del libro, en subs_terceros; sus papeles, en subs_archivos; cada cambio, en subs_historial. Se escribe con fn_subs_ficha. NUNCA es un contratista de la app (esos son los clientes).';

-- A quién del libro corresponde cada ficha: uno o varios terceros
-- (proveedor = proveedores.id; empleado = perfiles.id). Un tercero, una ficha.
create table if not exists public.subs_terceros (
  tercero_tipo  text        not null,
  tercero_id    uuid        not null,
  ficha_id      uuid        not null references public.subs_fichas (id),
  enlazado_el   timestamptz not null default now(),
  enlazado_por  uuid,
  constraint subs_terceros_pk   primary key (tercero_tipo, tercero_id),
  constraint subs_terceros_tipo check (tercero_tipo in ('proveedor', 'empleado'))
);
create index if not exists subs_terceros_ficha_idx on public.subs_terceros (ficha_id);
comment on table public.subs_terceros is 'c14: los terceros del libro de cada ficha: tercero_tipo (proveedor = proveedores.id; empleado = perfiles.id, el ayudante con horas en la app) y tercero_id, como los lleva cada línea del libro. Una ficha puede tener varios (la misma persona como proveedor y como perfil) y un tercero está en una sola ficha. Sin llave foránea a proveedores ni a perfiles (no son de esta capa): si el tercero desaparece, el control lo dice. Se escribe con fn_subs_tercero (y al dar de alta la ficha).';

-- EL TIN ENTERO. Una fila por ficha. Sin CHECK ni índice sobre el TIN (un
-- error de Postgres escribiría la fila en su detalle): la forma y el
-- repetido los miran la función y la guarda.
create table if not exists public.subs_tin (
  ficha_id      uuid        primary key references public.subs_fichas (id),
  tin           text        not null,
  guardado_el   timestamptz not null default now(),
  guardado_por  uuid
);
comment on table public.subs_tin is 'c14: EL TIN ENTERO de cada ficha (9 dígitos, sin guiones), en una tabla aparte. No lo lee nadie por la API salvo el dueño con el código del teléfono (aal2) y dentro de las funciones que lo guardan y lo exportan (sus policies piden es_dueno(), aal2 y la marca mx_subs.tin); anon y service_role no tienen ningún privilegio; ninguna vista la toca; no va en ninguna publicación. No tiene CHECK ni índice sobre el TIN a propósito (Postgres pondría el valor en el detalle de su error). Se escribe con fn_subs_tin_guardar y se lee entero solo en fn_subs_1099_export.';
comment on column public.subs_tin.tin is 'El TIN (SSN o EIN), 9 dígitos sin guiones. No se copia a ninguna otra tabla, ni a un mensaje, ni a un registro.';
-- (ni a las estadísticas del planificador: ANALYZE guardaría valores de la columna en el catálogo —pg_statistic—, que es
-- otra copia del TIN fuera de esta tabla. Con el objetivo en 0 no guarda ninguno.)
alter table public.subs_tin alter column tin set statistics 0;

-- Los papeles: el W-9, cada COI y el certificado de exención de WC, en el
-- bucket privado «subs». Solo se añaden; uno mal subido se retira (una vez).
create table if not exists public.subs_archivos (
  id               uuid        primary key default gen_random_uuid(),
  ficha_id         uuid        not null references public.subs_fichas (id),
  clase            text        not null,
  ruta             text        not null,
  sha256           text        not null,
  bytes            bigint      not null,
  fecha            date,
  vence            date,
  nota             text,
  registrado_el    timestamptz not null default clock_timestamp(),
  registrado_por   uuid,
  retirado_el      timestamptz,
  retirado_por     uuid,
  retirado_motivo  text,
  constraint subs_archivos_clase   check (clase in ('w9', 'coi', 'wc_exento')),
  constraint subs_archivos_forma   check (sha256 ~ '^[0-9a-f]{64}$' and bytes > 0 and btrim(ruta) <> ''),
  constraint subs_archivos_vence   check (case clase when 'coi' then vence is not null when 'w9' then vence is null else true end),
  constraint subs_archivos_fechas  check (fecha is null or vence is null or fecha <= vence),
  constraint subs_archivos_retiro  check ((retirado_el is not null) = (coalesce(btrim(retirado_motivo), '') <> ''))
);
create unique index if not exists subs_archivos_ruta_unica on public.subs_archivos (ruta);
create index if not exists subs_archivos_ficha_idx on public.subs_archivos (ficha_id, clase);
comment on table public.subs_archivos is 'c14: cada papel de una ficha, en el bucket privado «subs»: su clase (w9 = el formulario W-9; coi = un certificado de seguro; wc_exento = el certificado de exención de workers'' comp), su ruta (<ficha>/<clase>/<archivo>), su sha256 y su tamaño, su fecha (w9: recibido el; coi: vigente desde; wc_exento: emitido el) y cuándo vence (coi: obligatorio; wc_exento: si vence), una nota, quién y cuándo lo registró; y, retirado (mal subido): cuándo, quién y por qué. El W-9 que vale es el último; el COI, el de vencimiento más lejano (los anteriores quedan: es la historia). Solo se añade; lo único que cambia es el paso a retirado. Se escribe con fn_subs_archivo y fn_subs_archivo_retirar.';

-- Las marcas: lo que el libro no dice de una línea y Edgar sí sabe.
create table if not exists public.subs_marcas (
  id            uuid        primary key default gen_random_uuid(),
  asiento_id    uuid        not null,
  orden         int         not null,
  ficha_id      uuid        references public.subs_fichas (id),
  trato         text,
  nota          text        not null,
  marcado_el    timestamptz not null default now(),
  marcado_por   uuid,
  retirada_el   timestamptz,
  retirada_por  uuid,
  retirada_motivo text,
  constraint subs_marcas_linea foreign key (asiento_id, orden) references public.asiento_lineas (asiento_id, orden),
  constraint subs_marcas_trato check (trato is null or trato in ('servicio', 'no_servicio', 'tarjeta', 'pagado')),
  constraint subs_marcas_algo  check ((ficha_id is not null or trato is not null) and btrim(nota) <> '')
);
-- (para crecer: el trato «pagado» llegó después)
alter table public.subs_marcas drop constraint if exists subs_marcas_trato;
alter table public.subs_marcas add constraint subs_marcas_trato check (trato is null or trato in ('servicio', 'no_servicio', 'tarjeta', 'pagado'));
create unique index if not exists subs_marcas_viva on public.subs_marcas (asiento_id, orden) where retirada_el is null;
create index if not exists subs_marcas_ficha_idx on public.subs_marcas (ficha_id) where ficha_id is not null;
comment on table public.subs_marcas is 'c14: la marca de una línea del libro (asiento_id, orden) para el 1099: de qué ficha es (ficha_id: solo si la línea no trae tercero) y cómo se trata (trato: servicio = cuenta como pago por servicios aunque su cuenta no lleve la etiqueta 1099 o su partida no tenga papel; no_servicio = no cuenta; tarjeta = se pagó con tarjeta aunque saliera del banco; pagado = lo pagó la empresa por otro camino —Edgar de su bolsillo y se le devolvió— y cuenta como pagado en efectivo ese día), con su nota, quién y cuándo. Una línea, una marca viva; al sustituirla o quitarla la anterior queda retirada (retirada_el, retirada_por, retirada_motivo). El reverso de una línea marcada sigue su marca. No toca el libro. Se escribe con fn_subs_marcar.';

-- LOS TRAMOS de una ficha: lo que valía ANTES de un cambio, y hasta qué día.
-- Cuando «se le reporta» o el tipo de entidad cambian DESDE un día (pasa a
-- ser empleado por Gusto el 1 de enero; se hizo corporación en julio), lo de
-- antes se guarda aquí con su último día: cada pago cuenta como estaba la
-- ficha el día del pago. Un tramo mal puesto se retira (una vez) y queda.
create table if not exists public.subs_tramos (
  id               uuid        primary key default gen_random_uuid(),
  ficha_id         uuid        not null references public.subs_fichas (id),
  hasta            date        not null,
  tipo_entidad     text,
  reporta          text        not null,
  reporta_nota     text,
  anotado_el       timestamptz not null default clock_timestamp(),
  anotado_por      uuid,
  retirado_el      timestamptz,
  retirado_por     uuid,
  retirado_motivo  text,
  constraint subs_tramos_reporta check (reporta in ('si', 'no', 'por_decidir')),
  constraint subs_tramos_entidad check (tipo_entidad is null or tipo_entidad in ('individual', 'sole_proprietor', 'llc_un_socio',
                                                                                 'llc_sociedad', 'sociedad', 's_corp', 'c_corp', 'otro')),
  constraint subs_tramos_retiro  check ((retirado_el is not null) = (coalesce(btrim(retirado_motivo), '') <> ''))
);
create unique index if not exists subs_tramos_vivo on public.subs_tramos (ficha_id, hasta) where retirado_el is null;
comment on table public.subs_tramos is 'c14: los tramos de una ficha: lo que valía ANTES de un cambio de «se le reporta» o de tipo de entidad, y hasta qué día (hasta, inclusive): su tipo_entidad, su reporta (si | no | por_decidir) y su nota, quién lo anotó y cuándo; y, retirado (mal puesto): cuándo, quién y por qué. Un pago cuenta como estaba la ficha ese día: el tramo vivo de menor «hasta» que lo cubre o, si no hay, lo que la ficha dice hoy. Así cambiar una ficha «desde el 1 de enero» no reescribe el 1099 del año anterior. Solo se añade; lo único que cambia es el paso a retirado. Se escribe con fn_subs_ficha (con «desde») y fn_subs_tramo_retirar.';

-- El historial de las fichas y de la configuración: quién cambió qué.
create table if not exists public.subs_historial (
  id         uuid        primary key default gen_random_uuid(),
  ficha_id   uuid        references public.subs_fichas (id),
  que        text        not null,
  antes      jsonb,
  despues    jsonb,
  hecho_el   timestamptz not null default clock_timestamp(),
  hecho_por  uuid,
  constraint subs_historial_que check (que in ('alta', 'cambio', 'tercero', 'tercero_fuera', 'tin', 'tin_fuera', 'config', 'umbral'))
);
create index if not exists subs_historial_ficha_idx on public.subs_historial (ficha_id, hecho_el);
comment on table public.subs_historial is 'c14: cada cambio a una ficha (alta, cambio de sus datos, un tercero enlazado o soltado, el TIN guardado o quitado —solo su tipo y sus 4 últimos, nunca el TIN—) y a la configuración (config, umbral): qué decía antes y qué dice después, quién y cuándo. Solo se añade.';

-- Cada vez que se pidió la hoja del 1099 (con el TIN entero): rastro, sin TIN.
create table if not exists public.subs_exportaciones (
  id            uuid          primary key default gen_random_uuid(),
  anio          int           not null,
  umbral        numeric(14,2) not null,
  filas         int           not null,
  total         numeric(14,2) not null,
  pendientes    int           not null,
  huella        text          not null,
  detalle       jsonb         not null,
  opciones      jsonb         not null default '{}'::jsonb,
  generado_el   timestamptz   not null default clock_timestamp(),
  generado_por  uuid,
  constraint subs_exportaciones_forma check (filas >= 0 and pendientes >= 0 and jsonb_typeof(detalle) = 'object'
                                             and jsonb_typeof(opciones) = 'object')
);
create index if not exists subs_exportaciones_anio_idx on public.subs_exportaciones (anio, generado_el);
comment on table public.subs_exportaciones is 'c14: cada vez que se pidió la hoja del 1099 de un año (la única salida del TIN entero): el año, el umbral que se usó, cuántas filas y cuánto sumaban, cuántos quedaron pendientes, la huella de lo exportado (md5 de cada ficha con su monto) y su detalle (filas: ficha, nombre, los 4 últimos del TIN y el monto; pendientes: quién y qué le faltaba), las opciones, quién y cuándo. SIN el TIN. Solo se añade.';
comment on column public.subs_exportaciones.huella is 'md5 de las filas exportadas (ficha y monto, en orden): si lo que da el 1099 de ese año hoy tiene otra huella, el libro cambió después de exportar.';


-- ---------------------------------------------------------------------
-- 2. La guarda de las tablas de c14 (la de c6, c9, c10 y c12, en su forma):
--    solo se escriben con la marca de la transacción (mx_subs.escribe = el
--    nombre de la tabla), que ponen las funciones de aquí justo antes de
--    escribir y quitan después. A mano —desde PostgREST, aunque sea el
--    dueño, o desde el SQL Editor sin la marca— da MX003. Lo que es rastro
--    no se edita ni se borra. Y el TIN se vuelve a mirar aquí (su forma),
--    con un mensaje que no lo repite. SECURITY INVOKER, sin grant a nadie
--    (la dispara la tabla).
-- ---------------------------------------------------------------------
-- La forma de un TIN ya limpio (9 dígitos): nulo = vale; si no, por qué (el
-- texto NO lleva el TIN).
create or replace function public.fn_subs_tin_forma(p_tin text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p_tin is null or p_tin !~ '^[0-9]{9}$' then 'no son 9 dígitos'
              when p_tin ~ '^([0-9])\1{8}$' then 'son nueve dígitos iguales'
              when p_tin = '123456789' then 'es la secuencia 123456789'
         end
$$;
revoke execute on function public.fn_subs_tin_forma(text) from public, anon, service_role;
grant  execute on function public.fn_subs_tin_forma(text) to authenticated;
comment on function public.fn_subs_tin_forma(text) is 'c14: la forma de un TIN ya limpio: nulo si vale (9 dígitos, no nueve iguales ni 123456789); si no, por qué, en un texto que no lleva el TIN. No lo comprueba contra el IRS.';

create or replace function public.fn_subs_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_marca  text := coalesce(current_setting('mx_subs.escribe', true), '');
  v_libres text[];
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003',
      message = format('%s no se trunca: son las fichas de los subs y su rastro.', tg_table_name);
  end if;
  if tg_op = 'DELETE' and tg_table_name not in ('subs_terceros', 'subs_tin') then
    raise exception using errcode = 'MX003',
      message = format('%s no se borra: %s', tg_table_name,
                       case tg_table_name
                         when 'subs_config' then 'es la configuración (una fila); se cambia desde Contabilidad → Subs y 1099.'
                         when 'subs_umbrales' then 'el umbral de un año se cambia confirmándolo otra vez, y lo anterior queda.'
                         when 'subs_fichas' then 'una ficha se da de baja (activa = no) y su historia queda.'
                         when 'subs_archivos' then 'un papel mal subido se retira con su motivo y queda.'
                         when 'subs_marcas' then 'una marca se quita con su nota y queda retirada.'
                         when 'subs_tramos' then 'un tramo mal puesto se retira con su motivo y queda.'
                         else 'es rastro.' end);
  end if;
  if v_marca <> tg_table_name then
    raise exception using errcode = 'MX003',
      message = format('%s se escribe solo desde la pantalla de Subs y 1099 (sus funciones), no a mano.', tg_table_name);
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  if tg_table_name = 'subs_tin' then
    if public.fn_subs_tin_forma(to_jsonb(new)->>'tin') is not null then
      raise exception using errcode = 'MX005',
        message = 'Ese TIN no tiene la forma de un TIN (' || public.fn_subs_tin_forma(to_jsonb(new)->>'tin') || '): no se guardó. '
                  '(No se repite aquí a propósito.)';
    end if;
    if tg_op = 'UPDATE' and (to_jsonb(new)->>'ficha_id') is distinct from (to_jsonb(old)->>'ficha_id') then
      raise exception using errcode = 'MX003', message = 'El TIN de una ficha no se pasa a otra: se quita de una y se guarda en la otra.';
    end if;
  end if;
  if tg_op = 'UPDATE' then
    -- Lo único que le pasa a una fila de rastro: quedar retirada, una vez.
    v_libres := case tg_table_name
                  when 'subs_archivos' then array['retirado_el', 'retirado_por', 'retirado_motivo']
                  when 'subs_marcas' then array['retirada_el', 'retirada_por', 'retirada_motivo']
                  when 'subs_tramos' then array['retirado_el', 'retirado_por', 'retirado_motivo']
                  else null end;
    if tg_table_name in ('subs_historial', 'subs_exportaciones') then
      raise exception using errcode = 'MX003', message = format('%s no se edita: es rastro.', tg_table_name);
    elsif v_libres is not null then
      if (to_jsonb(new) - v_libres) is distinct from (to_jsonb(old) - v_libres)
         or coalesce(to_jsonb(old)->>'retirado_el', to_jsonb(old)->>'retirada_el') is not null
         or coalesce(to_jsonb(new)->>'retirado_el', to_jsonb(new)->>'retirada_el') is null then
        raise exception using errcode = 'MX003',
          message = format('%s no se edita: solo queda retirado, una vez.', tg_table_name);
      end if;
    elsif tg_table_name in ('subs_fichas', 'subs_terceros')
          and (to_jsonb(new)->>(case tg_table_name when 'subs_fichas' then 'id' else 'tercero_id' end))
              is distinct from (to_jsonb(old)->>(case tg_table_name when 'subs_fichas' then 'id' else 'tercero_id' end)) then
      raise exception using errcode = 'MX003', message = format('%s: su llave no cambia.', tg_table_name);
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.fn_subs_guarda() from public, anon, authenticated, service_role;
comment on function public.fn_subs_guarda() is 'c14: la guarda de las tablas de c14: se escriben solo con la marca de la transacción (mx_subs.escribe) que ponen sus funciones; un archivo y una marca solo quedan retirados (una vez), el historial y las exportaciones no se editan, y nada se borra (salvo el enlace de un tercero y un TIN, por su función). Vuelve a mirar la forma del TIN, con un mensaje que no lo repite.';

do $$
declare
  t text;
begin
  foreach t in array array['subs_config', 'subs_umbrales', 'subs_fichas', 'subs_terceros', 'subs_tin', 'subs_archivos', 'subs_marcas',
                           'subs_historial', 'subs_exportaciones', 'subs_tramos'] loop
    execute format('create or replace trigger trg_%s_guarda before insert or update or delete on public.%I '
                   'for each row execute function public.fn_subs_guarda()', t, t);
    execute format('create or replace trigger trg_%s_sin_truncate before truncate on public.%I '
                   'for each statement execute function public.fn_subs_guarda()', t, t);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 3. Los permisos: RLS, «solo el dueño lee», y en las tablas que escribe
--    una función INVOKER, la policy de escritura del dueño (con la guarda
--    de arriba delante: la policy dice quién, la marca dice por dónde).
--    anon y service_role, nada. Y subs_tin, aparte: sus policies piden al
--    dueño, su código del teléfono y la marca mx_subs.tin.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array['subs_config', 'subs_umbrales', 'subs_fichas', 'subs_terceros', 'subs_tin', 'subs_archivos', 'subs_marcas',
                           'subs_historial', 'subs_exportaciones', 'subs_tramos'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
  end loop;
  -- Todas menos el TIN: el dueño lee.
  foreach t in array array['subs_config', 'subs_umbrales', 'subs_fichas', 'subs_terceros', 'subs_archivos', 'subs_marcas',
                           'subs_historial', 'subs_exportaciones', 'subs_tramos'] loop
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
  -- Lo que escriben las funciones de la pantalla (como el dueño).
  foreach t in array array['subs_config', 'subs_umbrales', 'subs_fichas', 'subs_archivos', 'subs_marcas', 'subs_tramos'] loop
    execute format('create policy %I on public.%I for update to authenticated using ((select es_dueno())) with check ((select es_dueno()))',
                   t || '_dueno_edita', t);
    execute format('grant update on public.%I to authenticated', t);
  end loop;
  foreach t in array array['subs_umbrales', 'subs_fichas', 'subs_terceros', 'subs_archivos', 'subs_marcas', 'subs_historial',
                           'subs_exportaciones', 'subs_tramos'] loop
    execute format('create policy %I on public.%I for insert to authenticated with check ((select es_dueno()))',
                   t || '_dueno_anade', t);
    execute format('grant insert on public.%I to authenticated', t);
  end loop;
  create policy subs_terceros_dueno_suelta on public.subs_terceros for delete to authenticated using ((select es_dueno()));
  grant delete on public.subs_terceros to authenticated;
end $$;

-- EL TIN: el dueño, con su código del teléfono, y solo con la marca de la
-- transacción que ponen fn_subs_tin_guardar y fn_subs_1099_export. Una
-- policy permisiva (sin ella nadie pasa) y la misma condición en
-- «restrictive» (aunque otra permisiva dejara pasar, no pasa).
create policy subs_tin_dueno_codigo_marca on public.subs_tin for all to authenticated
  using ((select es_dueno()) and (select auth.jwt() ->> 'aal') = 'aal2' and (select current_setting('mx_subs.tin', true)) = '1')
  with check ((select es_dueno()) and (select auth.jwt() ->> 'aal') = 'aal2' and (select current_setting('mx_subs.tin', true)) = '1');
create policy subs_tin_solo_asi on public.subs_tin as restrictive for all to authenticated
  using ((select es_dueno()) and (select auth.jwt() ->> 'aal') = 'aal2' and (select current_setting('mx_subs.tin', true)) = '1')
  with check ((select es_dueno()) and (select auth.jwt() ->> 'aal') = 'aal2' and (select current_setting('mx_subs.tin', true)) = '1');
grant select, insert, update, delete on public.subs_tin to authenticated;

-- La fila de la configuración (con la marca de la guarda): al volver a pegar
-- no se pisa nada. Las cuentas de fábrica son las que EXISTEN en el plan de
-- esta base (fn_subs_config no admite una que no exista): las por pagar que
-- se siguen, 2010 y 2020; y «las que no pagan a nadie», la cuenta de paso de
-- los cobros de Stripe (la que diga p1 si está —stripe_config.cuenta_puente—,
-- de fábrica 1020). Sin p1 esa cuenta no existe y la lista nace vacía; si p1
-- se pega DESPUÉS de esta capa, su cuenta de paso se añade a mano
-- (fn_subs_config: {"cuentas_no_pago": ["1020"]}).
do $$
declare
  v_puente text;
begin
  if not exists (select 1 from public.subs_config where id = 1) then
    if to_regclass('public.stripe_config') is not null then
      begin
        execute 'select c.cuenta_puente from public.stripe_config c order by c.id limit 1' into v_puente;
      exception when others then
        v_puente := null;
      end;
    end if;
    perform set_config('mx_subs.escribe', 'subs_config', true);
    insert into public.subs_config (id, cuentas_por_pagar, cuentas_no_pago)
    values (1,
            coalesce((select array_agg(k.codigo order by k.codigo) from public.cuentas k where k.codigo = any (array['2010', '2020'])), '{}'),
            coalesce((select array_agg(k.codigo order by k.codigo) from public.cuentas k
                       where k.codigo = coalesce(v_puente, '1020')), '{}'));
    perform set_config('mx_subs.escribe', '', true);
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 4. Lo común: dinero y fechas en llano, desde cuándo hay libro, el umbral
--    de un año, la máscara del TIN, el nombre de un tercero, la clase de
--    una cuenta, lo que hay en el bucket. Todo SECURITY INVOKER; lo que
--    usan las funciones de la pantalla y las vistas lleva EXECUTE para
--    authenticated.
-- ---------------------------------------------------------------------
-- Las vistas de c14 se borran aquí y se rehacen al final (en este mismo
-- pegado): así una función que cambie lo que devuelve puede volver a
-- crearse.
drop view if exists public.v_subs_fichas, public.v_subs_archivos, public.v_subs_1099, public.v_subs_pagos, public.v_subs_coi,
                    public.v_subs_control;

-- Dólares como se leen: $1,234.56 (negativo con su signo).
create or replace function public.fn_subs_usd(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null then '—'
              when p < 0 then '-$' || to_char(-p, 'FM999,999,999,990.00')
              else '$' || to_char(p, 'FM999,999,999,990.00') end
$$;
revoke execute on function public.fn_subs_usd(numeric) from public, anon, service_role;
grant  execute on function public.fn_subs_usd(numeric) to authenticated;
comment on function public.fn_subs_usd(numeric) is 'c14: un monto en dólares como se lee ($1,234.56).';

-- Una lista larga para el detalle de un control: sus elementos unidos con «; » mientras quepan en p_max caracteres (el
-- primero, siempre) y, si no caben todos, «… y N más»: quien la lee sabe que no está completa y cuántos faltan (la lista
-- entera está en la página de los subs), y ningún elemento queda cortado a medias.
create or replace function public.fn_subs_lista(p_items text[], p_max int default 900) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  with e as (
    select t.x, row_number() over (order by t.n) as n, sum(length(t.x) + 2) over (order by t.n) as hasta
      from unnest(p_items) with ordinality as t(x, n)
     where t.x is not null),
  k as (
    select count(*) as todos, count(*) filter (where e.n = 1 or e.hasta <= greatest(coalesce(p_max, 900), 50)) as caben from e)
  select case when k.todos = 0 then null
              else (select string_agg(e.x, '; ' order by e.n) from e where e.n = 1 or e.hasta <= greatest(coalesce(p_max, 900), 50))
                   || case when k.caben < k.todos then format('; … y %s más', k.todos - k.caben) else '' end end
    from k
$$;
revoke execute on function public.fn_subs_lista(text[], int) from public, anon, service_role;
grant  execute on function public.fn_subs_lista(text[], int) to authenticated;
comment on function public.fn_subs_lista(text[], int) is 'c14: una lista larga para el detalle de un control: sus elementos mientras quepan en p_max caracteres y, si no caben todos, «… y N más» (ninguno queda cortado a medias).';

-- Hoy, en Miami (nunca la fecha de la pantalla).
create or replace function public.fn_subs_hoy() returns date
language sql stable
set search_path = public, pg_temp
as $$ select public.fn_fecha_miami(now()) $$;
revoke execute on function public.fn_subs_hoy() from public, anon, service_role;
grant  execute on function public.fn_subs_hoy() to authenticated;
comment on function public.fn_subs_hoy() is 'c14: hoy en Miami.';

-- Un día como se lee, sin que se pueda confundir el mes con el día (en un
-- teléfono de aquí 01/10/2026 se lee «10 de enero»): 1-oct-2026. La misma
-- forma que la cédula (c13).
create or replace function public.fn_subs_dia(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select extract(day from p)::int || '-'
         || (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int]
         || '-' || extract(year from p)::int
$$;
revoke execute on function public.fn_subs_dia(date) from public, anon, service_role;
grant  execute on function public.fn_subs_dia(date) to authenticated;
comment on function public.fn_subs_dia(date) is 'c14: un día en corto con su año (1-oct-2026): no se confunde el mes con el día.';

-- Desde cuándo hay libro: el día después de la apertura (30-sep-2026 → el 1
-- de octubre); lo de antes está en QuickBooks. La misma regla que c4, c10 y
-- c12.
create or replace function public.fn_subs_libro_desde() returns date
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce((select pa.hasta + 1 from public.periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1),
                  (select min(pm.desde) from public.periodos pm where pm.tipo = 'mes'))
$$;
revoke execute on function public.fn_subs_libro_desde() from public, anon, service_role;
grant  execute on function public.fn_subs_libro_desde() to authenticated;
comment on function public.fn_subs_libro_desde() is 'c14: el primer día del libro (el día después de la apertura; sin ella, el primer mes): lo de antes está en QuickBooks. La misma regla que c4, c10 y c12.';

-- Los años que tienen 1099 en la app: desde el año en que empieza el libro
-- hasta el año en curso (o el del último asiento, si va por delante).
create or replace function public.fn_subs_anios() returns table (anio int)
language sql stable
set search_path = public, pg_temp
as $$
  select g::int
    from generate_series(extract(year from public.fn_subs_libro_desde())::int,
                         greatest(extract(year from public.fn_subs_hoy())::int,
                                  coalesce((select max(a.anio) from public.asientos a), 0))) g
   where public.fn_subs_ve()
$$;
revoke execute on function public.fn_subs_anios() from public, anon, service_role;
grant  execute on function public.fn_subs_anios() to authenticated;
comment on function public.fn_subs_anios() is 'c14: los años con 1099 en la app, desde el año en que empieza el libro hasta el año en curso (o el del último asiento). A quien no es el dueño, nada.';

-- El umbral de un año: el suyo si está confirmado; si no, el de fábrica.
create or replace function public.fn_subs_umbral(p_anio int) returns numeric
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce((select u.umbral from public.subs_umbrales u where u.anio = p_anio),
                  (select c.umbral_1099 from public.subs_config c where c.id = 1))
$$;
revoke execute on function public.fn_subs_umbral(int) from public, anon, service_role;
grant  execute on function public.fn_subs_umbral(int) to authenticated;
comment on function public.fn_subs_umbral(int) is 'c14: el umbral del 1099 de un año: el confirmado para ese año (subs_umbrales) o, si no hay, el de la configuración (subs_config.umbral_1099). Se reporta a quien se le pagó eso o más.';

-- El TIN como se enseña: su tipo y sus 4 últimos.
create or replace function public.fn_subs_mascara(p_tipo text, p_ultimos4 text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p_ultimos4 is null then null
              when p_tipo = 'ein' then '**-***' || p_ultimos4
              else '***-**-' || p_ultimos4 end
$$;
revoke execute on function public.fn_subs_mascara(text, text) from public, anon, service_role;
grant  execute on function public.fn_subs_mascara(text, text) to authenticated;
comment on function public.fn_subs_mascara(text, text) is 'c14: el TIN como se enseña en la pantalla: ***-**-1234 (SSN) o **-***1234 (EIN), con sus 4 últimos.';

-- El nombre de un tercero del libro (el de la app: proveedores o perfiles).
create or replace function public.fn_subs_tercero_nombre(p_tipo text, p_id text) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select case p_tipo
           when 'proveedor' then (select pr.nombre from public.proveedores pr where pr.id::text = p_id)
           when 'empleado'  then (select pe.nombre from public.perfiles pe where pe.id::text = p_id) end
$$;
revoke execute on function public.fn_subs_tercero_nombre(text, text) from public, anon, service_role;
grant  execute on function public.fn_subs_tercero_nombre(text, text) to authenticated;
comment on function public.fn_subs_tercero_nombre(text, text) is 'c14: el nombre de un tercero del libro: el del proveedor (proveedores) o el del perfil (perfiles), con la policy de quien pregunta.';

-- LA CLASE DE UNA CUENTA para el 1099:
--   por_pagar  una cuenta cuya deuda se sigue hasta su pago
--              (subs_config.cuentas_por_pagar: 2010 y 2020)
--   tarjeta    una tarjeta de la empresa (una subcuenta 2100-XXXX)
--   efectivo   un banco o la caja: 10xx de activo sin obra (la regla de c3
--              para «banco»), menos subs_config.cuentas_no_pago (1020)
--   servicio   una cuenta con la etiqueta fiscal 1099 (hoy 5200)
--   otra       las demás
create or replace function public.fn_subs_cuenta_clase(p_cuenta text) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select case when c.codigo = any (g.cuentas_por_pagar) then 'por_pagar'
              when left(c.codigo, 5) = '2100-' and c.tipo = 'pasivo' then 'tarjeta'
              when left(c.codigo, 2) = '10' and c.tipo = 'activo' and c.regla_obra = 'prohibida'
                   and not (c.codigo = any (g.cuentas_no_pago)) then 'efectivo'
              when c.etiqueta_fiscal = '1099' then 'servicio'
              else 'otra' end
    from public.cuentas c
    cross join (select x.cuentas_por_pagar, x.cuentas_no_pago from public.subs_config x where x.id = 1) g
   where c.codigo = p_cuenta
$$;
revoke execute on function public.fn_subs_cuenta_clase(text) from public, anon, service_role;
grant  execute on function public.fn_subs_cuenta_clase(text) to authenticated;
comment on function public.fn_subs_cuenta_clase(text) is 'c14: la clase de una cuenta para el 1099: por_pagar (las de subs_config.cuentas_por_pagar), tarjeta (una subcuenta 2100-XXXX), efectivo (un banco o la caja: 10xx de activo sin obra, menos subs_config.cuentas_no_pago), servicio (las de etiqueta fiscal 1099) u otra.';

-- Lo que hay en el bucket «subs» de Storage (su ruta y su tamaño, si
-- Storage lo apunta). Sin Storage en la base, o a quien no es el dueño,
-- nada. (Con la sesión sin el código del teléfono, Storage tampoco enseña
-- nada: sus policies lo piden.)
create or replace function public.fn_subs_storage() returns table (ruta text, bytes bigint)
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if to_regclass('storage.objects') is null or not fn_subs_ve() then
    return;
  end if;
  return query execute 'select o.name::text, case when o.metadata->>''size'' ~ ''^[0-9]+$'' then (o.metadata->>''size'')::bigint end '
                    || 'from storage.objects o where o.bucket_id = ''subs''';
end $$;
revoke execute on function public.fn_subs_storage() from public, anon, service_role;
grant  execute on function public.fn_subs_storage() to authenticated;
comment on function public.fn_subs_storage() is 'c14: los archivos del bucket privado «subs» (ruta y tamaño), si esta base tiene Storage; si no, ninguno.';


-- ---------------------------------------------------------------------
-- 5. LAS FICHAS. fn_subs_fichas las lee (lo que la pantalla pinta); la
--    ficha se da de alta o se cambia con fn_subs_ficha; sus terceros del
--    libro, con fn_subs_tercero.
-- ---------------------------------------------------------------------
-- CADA FICHA, con lo que la pantalla necesita (una, o todas):
--   nombre             el legal; si falta, el comercial o el del tercero
--   es_corporacion     su tipo de entidad está en entidades_no_reporta
--   reporta_efectivo   si | no | por_decidir (por_decidir + corporación = no)
--   reporta_texto      lo mismo, en llano, con su porqué
--   tin_mascara        ***-**-1234 (nunca el TIN)
--   w9_*, coi_*, wc_*  su papel vigente de cada clase; coi_dias = vence − hoy
--                      y coi_estado: sin_coi | vencido | por_vencer | vigente
--                      (coi_chip, como el chip de los documentos de la empresa)
--   terceros           [{tipo, id, nombre, existe}]
--   falta, falta_texto lo que le falta para su 1099 (nombre_legal,
--                      tipo_entidad, direccion, tin, w9, decidir); vacío si
--                      no se le reporta
drop function if exists public.fn_subs_fichas(uuid);
create function public.fn_subs_fichas(p_ficha uuid default null)
returns table (ficha_id uuid, nombre text, nombre_legal text, nombre_comercial text, tipo_entidad text, es_corporacion boolean,
               reporta text, reporta_nota text, reporta_efectivo text, reporta_texto text,
               direccion text, direccion2 text, ciudad text, estado text, zip text, direccion_completa boolean,
               tin_tipo text, tin_ultimos4 text, tin_mascara text, tin_guardado_el timestamptz,
               w9_archivo_id uuid, w9_ruta text, w9_recibido_el date,
               coi_archivo_id uuid, coi_ruta text, coi_vence date, coi_dias int, coi_estado text, coi_chip text,
               wc_exento boolean, wc_archivo_id uuid, wc_ruta text, wc_vence date, wc_estado text,
               terceros jsonb, falta text[], falta_texto text, activa boolean, notas text,
               creado_el timestamptz, actualizado_el timestamptz)
language sql stable
set search_path = public, pg_temp
as $$
  with g as (select c.*, public.fn_subs_hoy() as hoy from public.subs_config c where c.id = 1),
  b as (
    select f.*, g.hoy, g.coi_aviso_dias,
           coalesce(f.tipo_entidad = any (g.entidades_no_reporta), false) as corp,
           w.id as w9_id, w.ruta as w9_ruta, coalesce(w.fecha, (w.registrado_el at time zone 'America/New_York')::date) as w9_el,
           k.id as coi_id, k.ruta as coi_ruta, k.vence as coi_vence,
           x.id as wc_id, x.ruta as wc_ruta, x.vence as wc_vence,
           (select coalesce(jsonb_agg(jsonb_build_object('tipo', t.tercero_tipo, 'id', t.tercero_id,
                                                         'nombre', public.fn_subs_tercero_nombre(t.tercero_tipo, t.tercero_id::text),
                                                         'existe', public.fn_subs_tercero_nombre(t.tercero_tipo, t.tercero_id::text) is not null)
                                      order by t.tercero_tipo, t.enlazado_el), '[]'::jsonb)
              from public.subs_terceros t where t.ficha_id = f.id) as ters
      from public.subs_fichas f
      cross join g
      left join lateral (select a.* from public.subs_archivos a
                          where a.ficha_id = f.id and a.clase = 'w9' and a.retirado_el is null
                          order by coalesce(a.fecha, (a.registrado_el at time zone 'America/New_York')::date) desc, a.registrado_el desc
                          limit 1) w on true
      left join lateral (select a.* from public.subs_archivos a
                          where a.ficha_id = f.id and a.clase = 'coi' and a.retirado_el is null
                          order by a.vence desc, a.registrado_el desc limit 1) k on true
      left join lateral (select a.* from public.subs_archivos a
                          where a.ficha_id = f.id and a.clase = 'wc_exento' and a.retirado_el is null
                          order by a.registrado_el desc limit 1) x on true
     where public.fn_subs_ve() and (p_ficha is null or f.id = p_ficha)),
  c as (
    select b.*,
           case when b.reporta = 'por_decidir' and b.corp then 'no' else b.reporta end as rep,
           (b.direccion is not null and b.ciudad is not null and b.estado is not null and b.zip is not null) as dir_ok
      from b),
  d as (
    select c.*,
           case when c.rep = 'no' then '{}'::text[]
                else array_remove(array[case when c.nombre_legal is null then 'nombre_legal' end,
                                        case when c.tipo_entidad is null then 'tipo_entidad' end,
                                        case when not c.dir_ok then 'direccion' end,
                                        case when c.tin_ultimos4 is null then 'tin' end,
                                        case when c.w9_id is null then 'w9' end,
                                        case when c.rep = 'por_decidir' then 'decidir' end], null) end as falta
      from c)
  select d.id,
         coalesce(d.nombre_legal, d.nombre_comercial, d.ters->0->>'nombre', '(sin nombre)'),
         d.nombre_legal, d.nombre_comercial, d.tipo_entidad, d.corp,
         d.reporta, d.reporta_nota, d.rep,
         case when d.reporta = 'si' and d.corp then 'Se le reporta aunque es una corporación (la excepción): ' || coalesce(d.reporta_nota, '')
              when d.reporta = 'si' then 'Se le reporta el 1099 si pasa del umbral.'
              when d.reporta = 'no' then 'No se le reporta: ' || coalesce(d.reporta_nota, 'es una corporación.')
              when d.corp then 'No se le reporta: es una corporación (la regla; si a esta sí, márcala «sí» con su nota).'
              else 'Por decidir con el CPA: mientras tanto sale con lo pagado, y no entra en la hoja del 1099.' end,
         d.direccion, d.direccion2, d.ciudad, d.estado, d.zip, d.dir_ok,
         d.tin_tipo, d.tin_ultimos4, public.fn_subs_mascara(d.tin_tipo, d.tin_ultimos4), d.tin_guardado_el,
         d.w9_id, d.w9_ruta, d.w9_el,
         d.coi_id, d.coi_ruta, d.coi_vence, (d.coi_vence - d.hoy)::int,
         case when d.coi_id is null then 'sin_coi'
              when d.coi_vence < d.hoy then 'vencido'
              when d.coi_vence - d.hoy <= d.coi_aviso_dias then 'por_vencer'
              else 'vigente' end,
         case when d.coi_id is null then 'sin COI'
              when d.coi_vence < d.hoy then 'Vencido el ' || public.fn_subs_dia(d.coi_vence)
              when d.coi_vence - d.hoy <= d.coi_aviso_dias then format('vence en %s días', d.coi_vence - d.hoy)
              else 'vence el ' || public.fn_subs_dia(d.coi_vence) end,
         d.wc_exento, d.wc_id, d.wc_ruta, d.wc_vence,
         case when not d.wc_exento then null
              when d.wc_id is null then 'exento_sin_documento'
              when d.wc_vence is not null and d.wc_vence < d.hoy then 'exento_vencido'
              else 'exento' end,
         d.ters, d.falta,
         case when cardinality(d.falta) = 0 then null
              else (select string_agg(case x.f when 'nombre_legal' then 'su nombre legal (el del W-9)'
                                               when 'tipo_entidad' then 'su tipo de entidad'
                                               when 'direccion' then 'su dirección completa'
                                               when 'tin' then 'su TIN'
                                               when 'w9' then 'su W-9 (el archivo)'
                                               when 'decidir' then 'decidir con el CPA si se le reporta' end, ', ' order by x.n)
                      from unnest(d.falta) with ordinality x(f, n)) end,
         d.activa, d.notas, d.creado_el, d.actualizado_el
    from d
$$;
revoke execute on function public.fn_subs_fichas(uuid) from public, anon, service_role;
grant  execute on function public.fn_subs_fichas(uuid) to authenticated;
comment on function public.fn_subs_fichas(uuid) is 'c14: cada ficha (una, o todas) con lo que la pantalla pinta: su nombre, lo del W-9, si es corporación, si se le reporta (reporta, y reporta_efectivo: por decidir + corporación = no) con su porqué en llano, su dirección y si está completa, el TIN con máscara (nunca entero), su W-9, su COI (coi_vence, coi_dias = vence − hoy, coi_estado: sin_coi | vencido | por_vencer | vigente, y coi_chip) y su exención de WC vigentes, sus terceros del libro y lo que le falta para su 1099 (falta, falta_texto). Solo lectura; no toca subs_tin; a quien no es el dueño, nada.';

-- ALTA O CAMBIO DE UNA FICHA. p: {id? (sin id = alta), nombre_legal,
-- nombre_comercial, tipo_entidad, reporta, reporta_nota, direccion,
-- direccion2, ciudad, estado, zip, wc_exento, notas, activa, tercero?:
-- {tipo, id}, desde?: "AAAA-MM-DD", corrige?: true}. Lo que no viene no
-- cambia; lo que viene vacío se quita. EL TIN NO VA AQUÍ (22023, sin
-- repetirlo; y un campo que sea, entero, un TIN, tampoco se guarda). Ningún
-- mensaje de aquí repite lo tecleado. Devuelve la ficha (fn_subs_fichas).
-- CUANDO CAMBIA CÓMO SE LE REPORTA (de «sí» a «no», o deja de ser o pasa a
-- ser corporación) y la ficha YA TIENE PAGOS con lo de antes, hay que decir
-- una de dos cosas (si no, MX008 pidiéndolo, con «desde» en su pista):
--   desde    el día desde el que vale el cambio: lo pagado antes se queda
--            como estaba (queda un tramo en subs_tramos con lo de antes y su
--            último día). Es lo normal: «desde el 1 de enero va por Gusto».
--   corrige  true: es una corrección, siempre debió ser así: vale para todo
--            lo pagado, también lo de años anteriores.
-- Decidir a quien estaba «por decidir» que SÍ se le reporta no lo pide: no
-- quita nada de ningún 1099.
create or replace function public.fn_subs_ficha(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c_claves constant text[] := array['id', 'nombre_legal', 'nombre_comercial', 'tipo_entidad', 'reporta', 'reporta_nota', 'direccion',
                                    'direccion2', 'ciudad', 'estado', 'zip', 'wc_exento', 'notas', 'activa', 'tercero', 'desde', 'corrige'];
  c_ent    constant text[] := array['individual', 'sole_proprietor', 'llc_un_socio', 'llc_sociedad', 'sociedad', 's_corp', 'c_corp', 'otro'];
  v_sobra  int;
  f        subs_fichas;
  n        subs_fichas;
  v_nueva  boolean := false;
  v_cfg    subs_config;
  v_k      text;
  v_antes  jsonb;
  v_desp   jsonb;
  v_cambio jsonb;
  v_tt     text;
  v_ti     uuid;
  v_txt    text;
  v_desde  date;
  v_corr   boolean := false;
  v_rep0   text;
  v_rep1   text;
  v_ult    date;
  v_pagado numeric;
  v_p1     date;
  v_p2     date;
  v_np     bigint;
  v_hoy    date := fn_subs_hoy();
begin
  perform fn_subs_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'La ficha llega como un objeto ({nombre_legal, tipo_entidad, …}).';
  end if;
  if p ?| array['tin', 'ssn', 'ein', 'tin_tipo', 'tin_ultimos4'] then
    -- (desde el SQL Editor NO se contesta con un error: Postgres apunta en su registro la orden entera que falla, y la
    -- orden lleva lo tecleado. Se contesta sin guardar nada, diciendo dónde va.)
    if not fn_subs_por_api() then
      return jsonb_build_object('guardado', false,
               'mensaje', 'El TIN no va con los datos de la ficha ni se teclea en el SQL Editor: se guarda en la app, en su ficha, con '
                          'el código del teléfono. (Aquí no se guardó nada.)');
    end if;
    raise exception using errcode = '22023',
      message = 'El TIN no va con los datos de la ficha: se guarda aparte, con el código del teléfono. (Aquí no se guardó ni se repite.)';
  end if;
  -- DESDE EL SQL EDITOR, NADA QUE PAREZCA UN TIN LLEGA A UN ERROR (una orden que falla queda entera, con lo tecleado, en
  -- el registro del servidor): si una clave o un valor de lo que llega es, entero, un TIN —esté en el campo que esté: una
  -- clave de más, el código postal, el tipo de entidad—, se contesta sin guardar nada y sin error.
  if not fn_subs_por_api() and exists (
       select 1
         from (select k as t from jsonb_object_keys(p) k
               union all
               select x.value #>> '{}' from jsonb_each(p) x where jsonb_typeof(x.value) in ('string', 'number')
               union all
               select x.value #>> '{}'
                 from jsonb_each(case when jsonb_typeof(p->'tercero') = 'object' then p->'tercero' else '{}'::jsonb end) x
                where jsonb_typeof(x.value) in ('string', 'number')) z
        where btrim(z.t) ~ '^[0-9]{3}-[0-9]{2}-[0-9]{4}$' or btrim(z.t) ~ '^[0-9]{2}-[0-9]{7}$' or btrim(z.t) ~ '^[0-9]{9}$') then
    return jsonb_build_object('guardado', false,
             'mensaje', 'Algo de lo escrito parece un TIN: ahí no va, ni se teclea en el SQL Editor (lo que se pega ahí queda en su '
                        'historial). Se guarda en la app, en su ficha, con el código del teléfono. (Aquí no se guardó nada.)');
  end if;
  select count(*) into v_sobra from jsonb_object_keys(p) k where k <> all (c_claves);
  if v_sobra > 0 then
    raise exception using errcode = '22023',
      message = format('La ficha trae %s clave(s) que no existen (no se repiten aquí). Las que hay: %s.', v_sobra, array_to_string(c_claves, ', '));
  end if;
  if nullif(btrim(p->>'id'), '') is not null then
    begin
      select * into f from subs_fichas where id = (p->>'id')::uuid for update;
    exception when invalid_text_representation then
      raise exception using errcode = '22023', message = 'El id de la ficha no es un id.';
    end;
    if f.id is null then
      raise exception using errcode = '22023', message = 'No existe esa ficha.';
    end if;
  else
    v_nueva := true;
    f.id := gen_random_uuid();
    f.reporta := 'por_decidir';
    f.wc_exento := false;
    f.activa := true;
  end if;
  n := f;
  -- Los textos: lo que viene se pone, limpio; vacío = se quita.
  foreach v_k in array array['nombre_legal', 'nombre_comercial', 'reporta_nota', 'direccion', 'direccion2', 'ciudad', 'notas'] loop
    if p ? v_k then
      if jsonb_typeof(p->v_k) not in ('string', 'null') then
        raise exception using errcode = '22023', message = format('%s va como un texto.', v_k);
      end if;
      v_txt := nullif(btrim(regexp_replace(left(p->>v_k, 500), '[[:space:]]+', ' ', 'g')), '');
      -- (un campo que es, entero, un TIN: alguien lo pegó donde no va. No se guarda ni se repite. Desde el SQL Editor ya
      -- se contestó arriba, sin error.)
      if v_txt ~ '^[0-9]{3}-[0-9]{2}-[0-9]{4}$' or v_txt ~ '^[0-9]{2}-[0-9]{7}$' or v_txt ~ '^[0-9]{9}$' then
        raise exception using errcode = '22023',
          message = format('Lo escrito en «%s» parece un TIN: ahí no va. El TIN se guarda aparte, con el código del teléfono. (No se guardó '
                           'ni se repite aquí.)', v_k);
      end if;
      n := jsonb_populate_record(n, jsonb_build_object(v_k, v_txt));
    end if;
  end loop;
  if p ? 'tipo_entidad' then
    n.tipo_entidad := nullif(lower(btrim(p->>'tipo_entidad')), '');
    if n.tipo_entidad is not null and n.tipo_entidad <> all (c_ent) then
      n.tipo_entidad := null;
      raise exception using errcode = '22023',
        message = format('Ese tipo de entidad no existe (no se repite aquí). Los que hay: %s.', array_to_string(c_ent, ', '));
    end if;
  end if;
  if p ? 'reporta' then
    n.reporta := coalesce(nullif(lower(btrim(p->>'reporta')), ''), 'por_decidir');
    if n.reporta not in ('si', 'no', 'por_decidir') then
      raise exception using errcode = '22023', message = '«Se le reporta» es si, no o por_decidir.';
    end if;
  end if;
  if p ? 'estado' then
    n.estado := nullif(upper(btrim(p->>'estado')), '');
    if n.estado is not null and n.estado !~ '^[A-Z]{2}$' then
      raise exception using errcode = '22023', message = 'El estado va con sus dos letras (FL).';
    end if;
  end if;
  if p ? 'zip' then
    n.zip := nullif(btrim(p->>'zip'), '');
    if n.zip is not null and n.zip !~ '^[0-9]{5}(-[0-9]{4})?$' then
      raise exception using errcode = '22023', message = 'El código postal va como 34470 o 34470-1234.';
    end if;
  end if;
  foreach v_k in array array['wc_exento', 'activa'] loop
    if p ? v_k then
      if jsonb_typeof(p->v_k) <> 'boolean' then
        raise exception using errcode = '22023', message = format('%s es true o false.', v_k);
      end if;
      n := jsonb_populate_record(n, jsonb_build_object(v_k, p->v_k));
    end if;
  end loop;
  -- «Se le reporta», con su porqué cuando va contra la regla.
  select * into v_cfg from subs_config where id = 1;
  if n.reporta = 'si' and coalesce(n.tipo_entidad = any (v_cfg.entidades_no_reporta), false) and n.reporta_nota is null then
    raise exception using errcode = '22023',
      message = 'A una corporación no se le reporta el 1099. Si a esta sí (la excepción: un abogado, lo que diga el CPA), escribe por '
                'qué en la nota.';
  end if;
  if n.reporta = 'no' and not coalesce(n.tipo_entidad = any (v_cfg.entidades_no_reporta), false) and n.reporta_nota is null then
    raise exception using errcode = '22023',
      message = 'Para dejar a alguien sin 1099 hace falta el porqué en la nota (es empleado por Gusto, lo dijo el CPA…).';
  end if;
  -- El tercero del libro (si viene): se enlaza abajo, por su función.
  if p ? 'tercero' and jsonb_typeof(p->'tercero') <> 'null' then
    if jsonb_typeof(p->'tercero') <> 'object' or (select count(*) from jsonb_object_keys(p->'tercero') k where k not in ('tipo', 'id')) > 0 then
      raise exception using errcode = '22023', message = 'tercero es un objeto {tipo: "proveedor" | "empleado", id}.';
    end if;
    v_tt := lower(btrim(p->'tercero'->>'tipo'));
    begin
      v_ti := (p->'tercero'->>'id')::uuid;
    exception when invalid_text_representation then
      raise exception using errcode = '22023', message = 'El id del tercero no es un id.';
    end;
    if v_ti is null or v_tt is null then
      raise exception using errcode = '22023', message = 'tercero es un objeto {tipo: "proveedor" | "empleado", id}.';
    end if;
  end if;
  if v_nueva and n.nombre_legal is null and n.nombre_comercial is null and v_ti is null then
    raise exception using errcode = '22023',
      message = 'Una ficha nueva lleva al menos su nombre legal (el del W-9) o el tercero del libro al que corresponde.';
  end if;
  -- «desde» y «corrige»: desde cuándo vale un cambio de cómo se le reporta
  if p ? 'corrige' and jsonb_typeof(p->'corrige') <> 'null' then
    if jsonb_typeof(p->'corrige') <> 'boolean' then
      raise exception using errcode = '22023', message = 'corrige es true o false.';
    end if;
    v_corr := (p->>'corrige')::boolean;
  end if;
  if p ? 'desde' and jsonb_typeof(p->'desde') <> 'null' and btrim(coalesce(p->>'desde', '')) <> '' then
    if jsonb_typeof(p->'desde') <> 'string' or btrim(p->>'desde') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
      raise exception using errcode = '22023', message = 'desde va como AAAA-MM-DD: el día desde el que vale el cambio.';
    end if;
    begin
      v_desde := btrim(p->>'desde')::date;
    exception when others then
      raise exception using errcode = '22023', message = 'Ese día de «desde» no existe en el calendario.';
    end;
    if v_desde > v_hoy then
      raise exception using errcode = '22023',
        message = format('El %s todavía no llega: anota el cambio ese día (o con la fecha de hoy).', fn_subs_dia(v_desde));
    end if;
    if v_corr then
      raise exception using errcode = '22023',
        message = 'O el cambio vale desde un día (desde) o es una corrección de siempre (corrige): las dos cosas a la vez, no.';
    end if;
  end if;
  -- ¿CAMBIA CÓMO SE LE REPORTA? (lo que decide si un pago entra en su 1099: «se le reporta», y si es corporación)
  if not v_nueva then
    v_rep0 := case when f.reporta = 'por_decidir' and coalesce(f.tipo_entidad = any (v_cfg.entidades_no_reporta), false) then 'no' else f.reporta end;
    v_rep1 := case when n.reporta = 'por_decidir' and coalesce(n.tipo_entidad = any (v_cfg.entidades_no_reporta), false) then 'no' else n.reporta end;
    if v_rep0 is distinct from v_rep1 and not (v_rep0 = 'por_decidir' and v_rep1 = 'si') then
      select max(t.hasta) into v_ult from subs_tramos t where t.ficha_id = f.id and t.retirado_el is null;
      -- lo pagado con lo de antes (en efectivo o por otro camino: servicio o sin clasificar), desde su último tramo
      select count(*), coalesce(sum(c.monto), 0), min(c.fecha), max(c.fecha) into v_np, v_pagado, v_p1, v_p2
        from fn_subs_calculo() c
       where c.ficha_id = f.id and c.medio in ('efectivo', 'otro') and c.clase in ('servicio', 'sin_clasificar')
         and (v_ult is null or c.fecha > v_ult);
      if v_np > 0 and v_desde is null and not v_corr then
        raise exception using errcode = 'MX008',
          message = format('Esta ficha ya tiene pagos con lo de antes: %s entre el %s y el %s. Di desde qué día vale el cambio (lo pagado '
                           'antes se queda como estaba), o que es una corrección y siempre debió ser así (entonces vale para todo, '
                           'también lo de años anteriores).', fn_subs_usd(v_pagado), fn_subs_dia(v_p1), fn_subs_dia(v_p2)),
          detail = jsonb_build_object('pide', 'desde', 'pagado', v_pagado, 'primer_pago', v_p1, 'ultimo_pago', v_p2,
                                      'desde_minimo', v_ult + 2)::text,
          hint = 'desde';
      end if;
      if v_desde is not null then
        if v_ult is not null and v_desde - 1 <= v_ult then
          raise exception using errcode = '22023',
            message = format('Esta ficha ya tiene anotado un cambio hasta el %s: el nuevo tiene que empezar después del %s.',
                             fn_subs_dia(v_ult), fn_subs_dia(v_ult + 1));
        end if;
        perform set_config('mx_subs.escribe', 'subs_tramos', true);
        insert into subs_tramos (ficha_id, hasta, tipo_entidad, reporta, reporta_nota, anotado_por)
        values (f.id, v_desde - 1, f.tipo_entidad, f.reporta, f.reporta_nota, auth.uid());
        perform set_config('mx_subs.escribe', '', true);
      else
        v_desde := null;
      end if;
    else
      -- (sin cambio de cómo se le reporta, «desde» no hace falta: no se anota ningún tramo)
      v_desde := null; v_corr := false;
    end if;
  else
    v_desde := null; v_corr := false;
  end if;
  v_antes := to_jsonb(f);
  v_desp  := to_jsonb(n);
  select jsonb_object_agg(e.key, e.value) into v_cambio
    from jsonb_each(v_desp) e
   where e.value is distinct from v_antes->e.key and e.key not in ('actualizado_el', 'actualizado_por', 'creado_el', 'creado_por');
  if v_nueva then
    perform set_config('mx_subs.escribe', 'subs_fichas', true);
    insert into subs_fichas (id, nombre_legal, nombre_comercial, tipo_entidad, reporta, reporta_nota, direccion, direccion2, ciudad,
                             estado, zip, wc_exento, notas, activa, creado_por, actualizado_por)
    values (n.id, n.nombre_legal, n.nombre_comercial, n.tipo_entidad, n.reporta, n.reporta_nota, n.direccion, n.direccion2, n.ciudad,
            n.estado, n.zip, n.wc_exento, n.notas, n.activa, auth.uid(), auth.uid());
    perform set_config('mx_subs.escribe', 'subs_historial', true);
    insert into subs_historial (ficha_id, que, despues, hecho_por)
    values (n.id, 'alta', (select to_jsonb(x) from subs_fichas x where x.id = n.id), auth.uid());
    perform set_config('mx_subs.escribe', '', true);
  elsif v_cambio is not null then
    perform set_config('mx_subs.escribe', 'subs_fichas', true);
    update subs_fichas
       set nombre_legal = n.nombre_legal, nombre_comercial = n.nombre_comercial, tipo_entidad = n.tipo_entidad, reporta = n.reporta,
           reporta_nota = n.reporta_nota, direccion = n.direccion, direccion2 = n.direccion2, ciudad = n.ciudad, estado = n.estado,
           zip = n.zip, wc_exento = n.wc_exento, notas = n.notas, activa = n.activa, actualizado_el = now(), actualizado_por = auth.uid()
     where id = n.id;
    perform set_config('mx_subs.escribe', 'subs_historial', true);
    insert into subs_historial (ficha_id, que, antes, despues, hecho_por)
    values (n.id, 'cambio', (select jsonb_object_agg(k, v_antes->k) from jsonb_object_keys(v_cambio) k),
            v_cambio || case when v_desde is not null then jsonb_build_object('vale_desde', v_desde)
                             when v_corr and v_np > 0 then jsonb_build_object('corrige_lo_pagado', v_pagado) else '{}'::jsonb end,
            auth.uid());
    perform set_config('mx_subs.escribe', '', true);
  end if;
  if v_ti is not null then
    perform fn_subs_tercero(n.id, v_tt, v_ti, false);
  end if;
  return (select to_jsonb(x) from fn_subs_fichas(n.id) x);
end $$;
revoke execute on function public.fn_subs_ficha(jsonb) from public, anon, service_role;
grant  execute on function public.fn_subs_ficha(jsonb) to authenticated;
comment on function public.fn_subs_ficha(jsonb) is 'c14: da de alta (sin id) o cambia una ficha: {id?, nombre_legal, nombre_comercial, tipo_entidad, reporta (si | no | por_decidir), reporta_nota, direccion, direccion2, ciudad, estado, zip, wc_exento, notas, activa, tercero?: {tipo, id}, desde?: AAAA-MM-DD, corrige?: true}. Lo que no viene no cambia; lo vacío se quita. A una corporación marcada «si» y a quien no lo es marcado «no» se les pide el porqué en la nota. Si cambia cómo se le reporta y la ficha ya tiene pagos con lo de antes, pide «desde» (el día desde el que vale: lo de antes queda en subs_tramos) o «corrige» (siempre debió ser así): sin ninguno, MX008 con «desde» en su pista. El TIN no va aquí (22023), ni un campo que sea entero un TIN; ningún mensaje repite lo tecleado. Cada cambio queda en subs_historial. Devuelve la ficha como la da fn_subs_fichas. Solo el dueño.';

-- RETIRAR UN TRAMO mal puesto (la fecha estaba mal; no era un cambio): queda,
-- marcado, con su motivo; los pagos de esos días vuelven a contar como diga
-- el tramo siguiente o la ficha.
create or replace function public.fn_subs_tramo_retirar(p_tramo uuid, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  t subs_tramos;
begin
  perform fn_subs_exigir_dueno();
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Retirar un tramo pide su motivo.';
  end if;
  select * into t from subs_tramos where id = p_tramo for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese tramo.';
  end if;
  if t.retirado_el is not null then
    raise exception using errcode = 'MX008', message = 'Ese tramo ya estaba retirado.';
  end if;
  perform set_config('mx_subs.escribe', 'subs_tramos', true);
  update subs_tramos set retirado_el = now(), retirado_por = auth.uid(), retirado_motivo = left(btrim(p_motivo), 500)
   where id = p_tramo returning * into t;
  perform set_config('mx_subs.escribe', 'subs_historial', true);
  insert into subs_historial (ficha_id, que, antes, hecho_por)
  values (t.ficha_id, 'cambio', jsonb_build_object('tramo_retirado', t.id, 'hasta', t.hasta, 'tipo_entidad', t.tipo_entidad,
                                                   'reporta', t.reporta, 'motivo', t.retirado_motivo), auth.uid());
  perform set_config('mx_subs.escribe', '', true);
  return jsonb_build_object('ficha', t.ficha_id, 'tramo', to_jsonb(t));
end $$;
revoke execute on function public.fn_subs_tramo_retirar(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_subs_tramo_retirar(uuid, text) to authenticated;
comment on function public.fn_subs_tramo_retirar(uuid, text) is 'c14: retira, con su motivo, un tramo mal puesto de una ficha (queda en la tabla, marcado): los pagos de esos días vuelven a contar como diga el tramo siguiente o la ficha. Una vez (MX008 si ya lo estaba). Queda en subs_historial. Devuelve {ficha, tramo}. Solo el dueño.';

-- ENLAZAR (O SOLTAR) UN TERCERO DEL LIBRO. p_tipo: proveedor (proveedores)
-- o empleado (perfiles). Un tercero, una ficha. Los contratistas de la app
-- (los clientes) no entran: 22023.
create or replace function public.fn_subs_tercero(p_ficha uuid, p_tipo text, p_id uuid, p_quitar boolean default false) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  f       subs_fichas;
  v_tipo  text := lower(btrim(coalesce(p_tipo, '')));
  v_nom   text;
  v_otra  uuid;
begin
  perform fn_subs_exigir_dueno();
  select * into f from subs_fichas where id = p_ficha for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa ficha.';
  end if;
  if v_tipo in ('contratista', 'contratistas', 'cliente', 'gc') then
    raise exception using errcode = '22023',
      message = 'Los contratistas de la app son los clientes (los GC): no llevan W-9, COI ni 1099 aquí. Un tercero es un proveedor o un '
                'ayudante con perfil.';
  end if;
  if v_tipo not in ('proveedor', 'empleado') or p_id is null then
    raise exception using errcode = '22023', message = 'El tercero es un proveedor o un empleado (su perfil), con su id.';
  end if;
  -- Un tercero, una ficha: de uno en uno por tercero (dos pestañas a la vez: la segunda espera y ve lo que hizo la primera).
  perform pg_advisory_xact_lock(hashtextextended('mx_subs.tercero:' || v_tipo || ':' || p_id::text, 0));
  v_nom := fn_subs_tercero_nombre(v_tipo, p_id::text);
  if coalesce(p_quitar, false) then
    perform set_config('mx_subs.escribe', 'subs_terceros', true);
    delete from subs_terceros t where t.tercero_tipo = v_tipo and t.tercero_id = p_id and t.ficha_id = p_ficha;
    if not found then
      perform set_config('mx_subs.escribe', '', true);
      raise exception using errcode = 'MX008', message = 'Ese tercero no está enlazado a esta ficha.';
    end if;
    perform set_config('mx_subs.escribe', 'subs_historial', true);
    insert into subs_historial (ficha_id, que, antes, hecho_por)
    values (p_ficha, 'tercero_fuera', jsonb_build_object('tipo', v_tipo, 'id', p_id, 'nombre', v_nom), auth.uid());
    perform set_config('mx_subs.escribe', '', true);
    return jsonb_build_object('ficha', p_ficha, 'tercero', jsonb_build_object('tipo', v_tipo, 'id', p_id, 'nombre', v_nom), 'quitado', true);
  end if;
  if v_nom is null then
    raise exception using errcode = '22023',
      message = format('No existe ese %s.', case v_tipo when 'proveedor' then 'proveedor' else 'perfil' end);
  end if;
  if v_tipo = 'empleado' and exists (select 1 from perfiles pe where pe.id = p_id and pe.rol = 'dueno') then
    raise exception using errcode = 'MX008', message = 'El dueño no cobra como contratista: no lleva ficha.';
  end if;
  select t.ficha_id into v_otra from subs_terceros t where t.tercero_tipo = v_tipo and t.tercero_id = p_id;
  if v_otra = p_ficha then
    return jsonb_build_object('ficha', p_ficha, 'tercero', jsonb_build_object('tipo', v_tipo, 'id', p_id, 'nombre', v_nom), 'ya_estaba', true);
  elsif v_otra is not null then
    raise exception using errcode = 'MX008',
      message = format('%s ya está en la ficha de «%s»: un tercero, una ficha. Suéltalo de allí primero.', v_nom,
                       (select x.nombre from fn_subs_fichas(v_otra) x));
  end if;
  perform set_config('mx_subs.escribe', 'subs_terceros', true);
  insert into subs_terceros (tercero_tipo, tercero_id, ficha_id, enlazado_por) values (v_tipo, p_id, p_ficha, auth.uid());
  perform set_config('mx_subs.escribe', 'subs_historial', true);
  insert into subs_historial (ficha_id, que, despues, hecho_por)
  values (p_ficha, 'tercero', jsonb_build_object('tipo', v_tipo, 'id', p_id, 'nombre', v_nom), auth.uid());
  perform set_config('mx_subs.escribe', '', true);
  return jsonb_build_object('ficha', p_ficha, 'tercero', jsonb_build_object('tipo', v_tipo, 'id', p_id, 'nombre', v_nom), 'ya_estaba', false);
end $$;
revoke execute on function public.fn_subs_tercero(uuid, text, uuid, boolean) from public, anon, service_role;
grant  execute on function public.fn_subs_tercero(uuid, text, uuid, boolean) to authenticated;
comment on function public.fn_subs_tercero(uuid, text, uuid, boolean) is 'c14: enlaza una ficha con un tercero del libro (proveedor = proveedores.id; empleado = perfiles.id), o lo suelta (p_quitar). Un tercero está en una sola ficha (MX008 si ya está en otra); el dueño no lleva ficha; un contratista de la app (un cliente) no es un tercero (22023). Queda en subs_historial. Devuelve {ficha, tercero: {tipo, id, nombre}, ya_estaba | quitado}. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 6. EL TIN. Se guarda (o se quita) con fn_subs_tin_guardar: el dueño, por
--    la API con su código del teléfono (aal2), con POST. La ficha se queda
--    con su tipo y sus 4 últimos; el TIN entero, en subs_tin. NINGÚN
--    mensaje de aquí repite el TIN.
-- ---------------------------------------------------------------------
create or replace function public.fn_subs_tin_guardar(p_ficha uuid, p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  f        subs_fichas;
  v_crudo  text;
  v_tin    text;
  v_tipo   text;
  v_forma  text;
  v_mal    text;
  v_otra   text;
  v_quitar boolean := false;
  v_corr   boolean := false;
  v_igual  boolean;
  v_np     bigint;
begin
  perform fn_subs_exigir_dueno();
  perform fn_subs_exigir_codigo();
  -- Un TIN no se teclea en el SQL Editor (ni en una tarea programada): lo que se pega ahí queda en su historial. Se
  -- guarda desde la app, que lo manda con POST y con el código del teléfono. Y AQUÍ NO SE CONTESTA CON UN ERROR: cuando
  -- una orden falla, Postgres apunta en su registro la orden entera, y la orden lleva el TIN tecleado. Se contesta sin
  -- guardar nada, diciendo dónde se hace. (Quitar uno sí se puede desde aquí: no lleva el TIN.)
  if not fn_subs_por_api()
     and not (p is not null and jsonb_typeof(p) = 'object' and jsonb_typeof(p->'quitar') = 'boolean' and (p->>'quitar')::boolean
              and not p ? 'tin') then
    return jsonb_build_object('ficha', p_ficha, 'guardado', false, 'quitado', false, 'tin', null,
             'mensaje', 'El TIN no se guarda desde el SQL Editor: lo que se pega ahí queda en su historial. Tecléalo en la app, en la '
                        'ficha (Contabilidad → Subs y 1099), con el código del teléfono. (No se guardó.)');
  end if;
  if p is null or jsonb_typeof(p) <> 'object'
     or (select count(*) from jsonb_object_keys(p) k where k not in ('tin', 'tipo', 'quitar', 'corrige')) > 0 then
    raise exception using errcode = '22023',
      message = 'El TIN llega como {tin, tipo: "ssn" | "ein"}, o {quitar: true}. (No se guardó, y aquí no se repite lo que llegó.)';
  end if;
  -- (lo que llega en «quitar», «corrige» y «tipo» se mira por su clase antes de usarlo: convertirlo a ciegas haría que
  -- Postgres repitiera en su error lo que alguien tecleó ahí —quizá el TIN, en el campo equivocado—)
  if (p ? 'quitar' and jsonb_typeof(p->'quitar') not in ('boolean', 'null'))
     or (p ? 'corrige' and jsonb_typeof(p->'corrige') not in ('boolean', 'null'))
     or (p ? 'tipo' and jsonb_typeof(p->'tipo') not in ('string', 'null'))
     or (p ? 'tin' and jsonb_typeof(p->'tin') not in ('string', 'null')) then
    raise exception using errcode = '22023',
      message = '«quitar» y «corrige» son true o false, y «tin» y «tipo» van como texto. (No se guardó, y aquí no se repite lo que llegó.)';
  end if;
  v_quitar := coalesce((p->>'quitar')::boolean, false);
  v_corr   := coalesce((p->>'corrige')::boolean, false);
  select * into f from subs_fichas where id = p_ficha for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa ficha.';
  end if;
  -- Un TIN, una ficha: de uno en uno.
  perform pg_advisory_xact_lock(hashtextextended('mx_subs.tin', 0));
  if v_quitar then
    if f.tin_ultimos4 is null then
      raise exception using errcode = 'MX008', message = 'Esa ficha no tiene TIN guardado.';
    end if;
    perform set_config('mx_subs.tin', '1', true);
    perform set_config('mx_subs.escribe', 'subs_tin', true);
    delete from subs_tin where ficha_id = p_ficha;
    perform set_config('mx_subs.tin', '', true);
    perform set_config('mx_subs.escribe', 'subs_fichas', true);
    update subs_fichas set tin_tipo = null, tin_ultimos4 = null, tin_guardado_el = null, tin_guardado_por = null,
                           actualizado_el = now(), actualizado_por = auth.uid()
     where id = p_ficha;
    perform set_config('mx_subs.escribe', 'subs_historial', true);
    insert into subs_historial (ficha_id, que, antes, hecho_por)
    values (p_ficha, 'tin_fuera', jsonb_build_object('tipo', f.tin_tipo, 'ultimos4', f.tin_ultimos4), auth.uid());
    perform set_config('mx_subs.escribe', '', true);
    return jsonb_build_object('ficha', p_ficha, 'tin', null, 'quitado', true, 'guardado', false);
  end if;
  v_crudo := btrim(coalesce(p->>'tin', ''));
  v_tipo  := nullif(lower(btrim(coalesce(p->>'tipo', ''))), '');
  if v_tipo is not null and v_tipo not in ('ssn', 'ein') then
    raise exception using errcode = '22023', message = 'El tipo del TIN es ssn (de una persona) o ein (de una empresa). (No se guardó.)';
  end if;
  -- La forma, sin repetir nunca lo tecleado.
  v_forma := case when v_crudo ~ '^[0-9]{3}-[0-9]{2}-[0-9]{4}$' then 'ssn'
                  when v_crudo ~ '^[0-9]{2}-[0-9]{7}$' then 'ein'
                  when v_crudo ~ '^[0-9]{9}$' then 'sin_guiones' end;
  v_mal := case when v_crudo = '' then 'falta el TIN'
                when v_crudo !~ '^[0-9 -]+$' then 'lleva algo que no es un dígito ni un guion'
                when v_forma is null then 'no está escrito como un SSN (###-##-####) ni como un EIN (##-#######), ni son 9 dígitos seguidos'
                when v_forma in ('ssn', 'ein') and v_tipo is not null and v_tipo <> v_forma
                  then format('dijiste que es un %s y está escrito como un %s', upper(v_tipo), upper(v_forma))
                when v_forma = 'sin_guiones' and v_tipo is null then 'sin guiones no se sabe si es un SSN o un EIN: di cuál' end;
  if v_mal is null then
    v_tin  := regexp_replace(v_crudo, '[^0-9]', '', 'g');
    v_tipo := coalesce(v_tipo, v_forma);
    v_mal  := fn_subs_tin_forma(v_tin);
  end if;
  if v_mal is not null then
    raise exception using errcode = 'MX005',
      message = format('Ese TIN no vale: %s. Revísalo contra el W-9. (No se guardó, y aquí no se repite a propósito.)', v_mal);
  end if;
  perform set_config('mx_subs.tin', '1', true);
  select x.nombre into v_otra
    from subs_tin t cross join lateral fn_subs_fichas(t.ficha_id) x
   where t.tin = v_tin and t.ficha_id <> p_ficha
   limit 1;
  if v_otra is not null then
    perform set_config('mx_subs.tin', '', true);
    raise exception using errcode = 'MX008',
      message = format('Ese TIN ya está en la ficha de «%s»: una persona o una empresa, una ficha (y un 1099). Si es la misma, enlaza '
                       'su otro tercero a aquella ficha; si te equivocaste de ficha, quítalo de allí. (No se guardó.)', v_otra);
  end if;
  -- CAMBIAR UN TIN POR OTRO en una ficha que ya tiene pagos: el 1099 de esos pagos iría al TIN nuevo. Si la persona
  -- cambió de TIN de verdad (se hizo empresa: de su SSN a un EIN) es OTRO contribuyente: otra ficha, con su proveedor
  -- nuevo; esta se queda con lo pagado hasta entonces. Si el TIN estaba mal tecleado, se corrige diciéndolo.
  if f.tin_ultimos4 is not null and not v_corr then
    select exists (select 1 from subs_tin t where t.ficha_id = p_ficha and t.tin = v_tin) into v_igual;
    if not v_igual then
      select count(*) into v_np
        from fn_subs_calculo() c
       where c.ficha_id = p_ficha and c.medio in ('efectivo', 'otro') and c.clase in ('servicio', 'sin_clasificar');
      if v_np > 0 then
        perform set_config('mx_subs.tin', '', true);
        raise exception using errcode = 'MX008',
          message = 'Esta ficha ya tiene un TIN y pagos a su nombre: cambiarlo mandaría el 1099 de esos pagos al TIN nuevo. Si el de '
                    'antes estaba mal tecleado, corrígelo diciéndolo. Si la persona cambió de TIN de verdad (se hizo empresa), es otro '
                    'contribuyente: dale de alta como proveedor nuevo con su ficha nueva; esta se queda con lo pagado hasta entonces. '
                    '(No se guardó.)',
          detail = jsonb_build_object('pide', 'corrige')::text,
          hint = 'corrige';
      end if;
    end if;
  end if;
  perform set_config('mx_subs.escribe', 'subs_tin', true);
  insert into subs_tin (ficha_id, tin, guardado_por) values (p_ficha, v_tin, auth.uid())
  on conflict (ficha_id) do update set tin = excluded.tin, guardado_el = now(), guardado_por = excluded.guardado_por;
  perform set_config('mx_subs.tin', '', true);
  perform set_config('mx_subs.escribe', 'subs_fichas', true);
  update subs_fichas set tin_tipo = v_tipo, tin_ultimos4 = right(v_tin, 4), tin_guardado_el = now(), tin_guardado_por = auth.uid(),
                         actualizado_el = now(), actualizado_por = auth.uid()
   where id = p_ficha;
  perform set_config('mx_subs.escribe', 'subs_historial', true);
  insert into subs_historial (ficha_id, que, antes, despues, hecho_por)
  values (p_ficha, 'tin', case when f.tin_ultimos4 is not null then jsonb_build_object('tipo', f.tin_tipo, 'ultimos4', f.tin_ultimos4) end,
          jsonb_build_object('tipo', v_tipo, 'ultimos4', right(v_tin, 4)), auth.uid());
  perform set_config('mx_subs.escribe', '', true);
  return jsonb_build_object('ficha', p_ficha, 'quitado', false, 'guardado', true,
                            'tin', jsonb_build_object('tipo', v_tipo, 'ultimos4', right(v_tin, 4),
                                                      'mascara', fn_subs_mascara(v_tipo, right(v_tin, 4))));
end $$;
revoke execute on function public.fn_subs_tin_guardar(uuid, jsonb) from public, anon, service_role;
grant  execute on function public.fn_subs_tin_guardar(uuid, jsonb) to authenticated;
comment on function public.fn_subs_tin_guardar(uuid, jsonb) is 'c14: guarda el TIN de una ficha ({tin, tipo: ssn | ein}; con sus guiones o sin ellos) o lo quita ({quitar: true}). Pide el código del teléfono (aal2; si no, 403 MFA). Mira su forma (MX005) y que no esté en otra ficha (MX008), con mensajes que NO repiten el TIN ni nada de lo que llegó. Cambiar un TIN por otro en una ficha que ya tiene pagos pide {corrige: true} (estaba mal tecleado); si no, MX008 con «corrige» en su pista: un TIN nuevo de verdad es otro contribuyente, con otra ficha. El TIN entero queda en subs_tin; la ficha, con su tipo y sus 4 últimos; el historial, con eso mismo. Devuelve {ficha, guardado, quitado, tin: {tipo, ultimos4, mascara}} — nunca el TIN. Se llama con POST. Solo el dueño, y solo desde la app: desde el SQL Editor un TIN no se guarda, y se dice SIN error ({guardado: false, mensaje}: un error dejaría la orden entera, con el TIN, en el registro del servidor); quitarlo sí.';


-- ---------------------------------------------------------------------
-- 7. LOS ARCHIVOS. El bucket privado «subs» (como «facturas» de c11): solo
--    el dueño sube y lee, Y SOLO CON EL CÓDIGO DEL TELÉFONO (aal2); nadie
--    borra ni pisa por la API (un archivo nuevo va con otro nombre). Storage
--    no pasa por la guarda de s1: por eso el código se pide aquí, en sus
--    policies, y con dos candados «restrictive» de lectura y de subida.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'c14: esta base no tiene Storage (storage.buckets): el bucket «subs» no se crea aquí; en Supabase sí.';
    return;
  end if;
  -- (Si la app está usando Storage mientras se pega —alguien sube o mira una foto—, el candado no llega en medio
  -- segundo: ese «lock timeout» (55P03) NO se traga: para el pegado entero, como dice la cabecera, y se vuelve a pegar.
  -- Tragarlo dejaría la capa puesta SIN los candados del bucket.)
  begin
    insert into storage.buckets (id, name, public) values ('subs', 'subs', false) on conflict (id) do nothing;
  exception
    when lock_not_available or deadlock_detected or query_canceled then
      raise;
    when others then
      raise notice 'c14: no se pudo crear el bucket «subs» (%): créalo en Storage (privado) y vuelve a pegar.', sqlerrm;
  end;
  begin
    drop policy if exists "subs: el dueno sube" on storage.objects;
    create policy "subs: el dueno sube" on storage.objects for insert to authenticated
      with check (bucket_id = 'subs' and public.es_dueno() and (select auth.jwt() ->> 'aal') = 'aal2');
    drop policy if exists "subs: el dueno lee" on storage.objects;
    create policy "subs: el dueno lee" on storage.objects for select to authenticated
      using (bucket_id = 'subs' and public.es_dueno() and (select auth.jwt() ->> 'aal') = 'aal2');
    drop policy if exists "subs: solo el dueno con su codigo lee" on storage.objects;
    create policy "subs: solo el dueno con su codigo lee" on storage.objects as restrictive for select to authenticated
      using (bucket_id is distinct from 'subs' or (public.es_dueno() and (select auth.jwt() ->> 'aal') = 'aal2'));
    drop policy if exists "subs: solo el dueno con su codigo sube" on storage.objects;
    create policy "subs: solo el dueno con su codigo sube" on storage.objects as restrictive for insert to authenticated
      with check (bucket_id is distinct from 'subs' or (public.es_dueno() and (select auth.jwt() ->> 'aal') = 'aal2'));
    drop policy if exists "subs: la llave publica no entra" on storage.objects;
    create policy "subs: la llave publica no entra" on storage.objects as restrictive for all to anon
      using (bucket_id is distinct from 'subs') with check (bucket_id is distinct from 'subs');
    drop policy if exists "subs: no se borra" on storage.objects;
    create policy "subs: no se borra" on storage.objects as restrictive for delete to anon, authenticated
      using (bucket_id is distinct from 'subs');
    drop policy if exists "subs: no se pisa" on storage.objects;
    create policy "subs: no se pisa" on storage.objects as restrictive for update to anon, authenticated
      using (bucket_id is distinct from 'subs') with check (bucket_id is distinct from 'subs');
  exception
    when lock_not_available or deadlock_detected or query_canceled then
      raise;
    when others then
      raise notice 'c14: no se pudieron poner las policies del bucket «subs» (%): vuelve a pegar este archivo; si sigue igual, ponlas en Storage → Policies (solo el dueño, con su código del teléfono, sube y lee; nadie borra). El control de los subs lo dirá en rojo.', sqlerrm;
  end;
end $$;

-- REGISTRAR UN ARCHIVO de una ficha. p:
--   clase   w9 | coi | wc_exento
--   ruta    dentro del bucket «subs»: <ficha>/<clase>/<archivo>, acabada en
--           .pdf, .jpg, .jpeg, .png, .heic o .webp (una ruta nueva por
--           archivo: no se pisa)
--   sha256  del archivo (64 hexadecimales en minúsculas)
--   bytes   su tamaño
--   fecha   AAAA-MM-DD: w9 = recibido el (si falta, hoy); coi = vigente
--           desde; wc_exento = emitido el
--   vence   AAAA-MM-DD: coi, obligatorio; wc_exento, si vence; w9, no lleva
--   nota
-- La base comprueba que el archivo está en Storage (si esta base lo tiene)
-- y, si Storage apunta su tamaño, que mide lo que se declara. Devuelve
-- {archivo, ya_estaba}.
create or replace function public.fn_subs_archivo(p_ficha uuid, p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  f        subs_fichas;
  v_sobra  text;
  v_clase  text;
  v_ruta   text;
  v_sha    text;
  v_bytes  bigint;
  v_fecha  date;
  v_vence  date;
  v_k      text;
  v_txt    text;
  v_carp   text;
  v_hay    boolean;
  v_tam    bigint;
  v_fila   subs_archivos;
begin
  perform fn_subs_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'El archivo llega como un objeto {clase, ruta, sha256, bytes, fecha?, vence?, nota?}.';
  end if;
  select count(*)::text into v_sobra
    from jsonb_object_keys(p) k where k not in ('clase', 'ruta', 'sha256', 'bytes', 'fecha', 'vence', 'nota');
  if v_sobra <> '0' then
    raise exception using errcode = '22023',
      message = format('El archivo trae %s clave(s) que no existen (no se repiten aquí). Las que hay: clase, ruta, sha256, bytes, fecha, '
                       'vence y nota.', v_sobra);
  end if;
  select * into f from subs_fichas where id = p_ficha for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa ficha.';
  end if;
  v_clase := lower(btrim(coalesce(p->>'clase', '')));
  if v_clase not in ('w9', 'coi', 'wc_exento') then
    raise exception using errcode = '22023', message = 'La clase del archivo es w9, coi o wc_exento.';
  end if;
  v_ruta := p->>'ruta';
  v_sha  := p->>'sha256';
  v_carp := p_ficha::text || '/' || v_clase || '/';
  if v_ruta is null or left(v_ruta, length(v_carp)) <> v_carp
     or substr(v_ruta, length(v_carp) + 1) !~* '^[A-Za-z0-9._-]+\.(pdf|jpg|jpeg|png|heic|webp)$'
     or v_ruta ~ '(^|/)\.\.(/|$)' or length(v_ruta) > 300 then
    raise exception using errcode = '22023',
      message = format('La ruta del archivo tiene que ser un PDF o una foto (.pdf, .jpg, .jpeg, .png, .heic, .webp) dentro de la '
                       'carpeta de esta ficha en el bucket subs (%s…), con un nombre de letras, números, puntos y guiones.', v_carp);
  end if;
  if coalesce(v_sha, '') !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'El sha256 del archivo va en 64 caracteres hexadecimales en minúsculas.';
  end if;
  begin
    v_bytes := (p->>'bytes')::bigint;
  exception when others then
    v_bytes := -1;
  end;
  if v_bytes is null or v_bytes <= 0 then
    raise exception using errcode = 'MX005', message = 'bytes es el tamaño del archivo, un entero de más de 0.';
  end if;
  foreach v_k in array array['fecha', 'vence'] loop
    v_txt := nullif(btrim(coalesce(p->>v_k, '')), '');
    if v_txt is not null then
      if v_txt !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
        raise exception using errcode = '22023', message = format('%s va como AAAA-MM-DD.', v_k);
      end if;
      begin
        if v_k = 'fecha' then v_fecha := v_txt::date; else v_vence := v_txt::date; end if;
      exception when others then
        raise exception using errcode = '22023', message = format('La fecha de «%s» no existe en el calendario.', v_k);
      end;
    end if;
  end loop;
  if v_clase = 'w9' then
    if v_vence is not null then
      raise exception using errcode = '22023', message = 'Un W-9 no lleva fecha de vencimiento: lleva el día en que se recibió (fecha).';
    end if;
    v_fecha := coalesce(v_fecha, fn_subs_hoy());
  elsif v_clase = 'coi' and v_vence is null then
    raise exception using errcode = '22023', message = 'Un COI lleva el día en que vence (vence): está en el certificado.';
  end if;
  if v_fecha is not null and v_vence is not null and v_fecha > v_vence then
    raise exception using errcode = '22023',
      message = format('Vence el %s, antes de su fecha (%s): revisa las dos.', fn_subs_dia(v_vence), fn_subs_dia(v_fecha));
  end if;
  -- el mismo archivo otra vez: ya estaba
  select * into v_fila from subs_archivos x where x.ruta = v_ruta;
  if found then
    if v_fila.ficha_id <> p_ficha or v_fila.clase <> v_clase or v_fila.sha256 <> v_sha or v_fila.bytes <> v_bytes then
      raise exception using errcode = 'MX008',
        message = format('Ya hay otro archivo registrado en «%s»: uno nuevo va con otro nombre (no se pisa).', v_ruta);
    end if;
    return jsonb_build_object('ficha', p_ficha, 'ya_estaba', true, 'archivo', to_jsonb(v_fila));
  end if;
  -- que esté en Storage (si esta base lo tiene; el banco de pruebas lo simula)
  if to_regclass('storage.objects') is not null then
    execute 'select true, case when o.metadata->>''size'' ~ ''^[0-9]+$'' then (o.metadata->>''size'')::bigint end '
            'from storage.objects o where o.bucket_id = ''subs'' and o.name = $1' into v_hay, v_tam using v_ruta;
    if v_hay is null then
      raise exception using errcode = '22023',
        message = format('«%s» no está en el bucket subs: sube el archivo primero (con el código del teléfono) y regístralo después.', v_ruta);
    elsif v_tam is not null and v_tam <> v_bytes then
      raise exception using errcode = '22023',
        message = format('«%s» mide %s bytes en el bucket subs y aquí dice %s: no se registró.', v_ruta, v_tam, v_bytes);
    end if;
  end if;
  perform set_config('mx_subs.escribe', 'subs_archivos', true);
  insert into subs_archivos (ficha_id, clase, ruta, sha256, bytes, fecha, vence, nota, registrado_por)
  values (p_ficha, v_clase, v_ruta, v_sha, v_bytes, v_fecha, v_vence,
          nullif(btrim(regexp_replace(left(coalesce(p->>'nota', ''), 500), '[[:space:]]+', ' ', 'g')), ''), auth.uid())
  returning * into v_fila;
  perform set_config('mx_subs.escribe', '', true);
  return jsonb_build_object('ficha', p_ficha, 'ya_estaba', false, 'archivo', to_jsonb(v_fila));
end $$;
revoke execute on function public.fn_subs_archivo(uuid, jsonb) from public, anon, service_role;
grant  execute on function public.fn_subs_archivo(uuid, jsonb) to authenticated;
comment on function public.fn_subs_archivo(uuid, jsonb) is 'c14: registra un papel de una ficha: {clase: w9 | coi | wc_exento, ruta (<ficha>/<clase>/<archivo>, un PDF o una foto, en el bucket subs), sha256, bytes, fecha? (w9: recibido el, hoy si falta; coi: vigente desde; wc_exento: emitido el), vence? (coi: obligatorio; wc_exento: si vence), nota?}. Comprueba que el archivo está en Storage y mide lo declarado. El mismo archivo otra vez: ya estaba; otra cosa en la misma ruta: MX008. Devuelve {archivo, ya_estaba}. Solo el dueño.';

-- RETIRAR UN ARCHIVO mal subido (otra persona, otro papel): queda, marcado,
-- con su motivo; el que vale pasa a ser el anterior de su clase.
create or replace function public.fn_subs_archivo_retirar(p_archivo uuid, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  a subs_archivos;
begin
  perform fn_subs_exigir_dueno();
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Retirar un archivo pide su motivo.';
  end if;
  select * into a from subs_archivos where id = p_archivo for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese archivo.';
  end if;
  if a.retirado_el is not null then
    raise exception using errcode = 'MX008', message = 'Ese archivo ya estaba retirado.';
  end if;
  perform set_config('mx_subs.escribe', 'subs_archivos', true);
  update subs_archivos set retirado_el = now(), retirado_por = auth.uid(), retirado_motivo = left(btrim(p_motivo), 500)
   where id = p_archivo returning * into a;
  perform set_config('mx_subs.escribe', '', true);
  return jsonb_build_object('ficha', a.ficha_id, 'archivo', to_jsonb(a));
end $$;
revoke execute on function public.fn_subs_archivo_retirar(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_subs_archivo_retirar(uuid, text) to authenticated;
comment on function public.fn_subs_archivo_retirar(uuid, text) is 'c14: retira un archivo mal subido, con su motivo: queda en la tabla (y en Storage) marcado como retirado, y el que vale de su clase pasa a ser el anterior. Una vez (MX008 si ya lo estaba). Devuelve {ficha, archivo}. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 8. LAS MARCAS: lo que el libro no dice de una línea. p:
--      {ficha?: uuid, trato?: "servicio" | "no_servicio" | "tarjeta" | "pagado", nota}
--      {quitar: true, nota?}
--    ficha: de quién es el pago (solo si la línea no trae tercero).
--    trato: servicio = cuenta como pago por servicios; no_servicio = no
--    cuenta; tarjeta = se pagó con tarjeta aunque saliera del banco; pagado
--    = lo pagó la empresa por otro camino (Edgar de su bolsillo, y la
--    empresa se lo devolvió): lo que de esa línea no salió del banco ni de
--    una tarjeta cuenta como pagado en efectivo ese día. ▶ CPA.
--    Se marca la línea del GASTO (o la de la cuenta por pagar que se paga),
--    nunca la del banco ni la de la tarjeta; y nunca un reverso (se marca
--    el original, y su reverso lo sigue). No toca el libro.
-- ---------------------------------------------------------------------
create or replace function public.fn_subs_marcar(p_asiento uuid, p_orden int, p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_l      record;
  v_sobra  text;
  v_clase  text;
  v_ficha  uuid;
  v_trato  text;
  v_nota   text;
  v_vieja  subs_marcas;
  v_nueva  subs_marcas;
begin
  perform fn_subs_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'La marca llega como {ficha?, trato?, nota} o {quitar: true}.';
  end if;
  select count(*)::text into v_sobra from jsonb_object_keys(p) k where k not in ('ficha', 'trato', 'nota', 'quitar');
  if v_sobra <> '0' then
    raise exception using errcode = '22023',
      message = format('La marca trae %s clave(s) que no existen (no se repiten aquí). Las que hay: ficha, trato, nota y quitar.', v_sobra);
  end if;
  if p ? 'quitar' and jsonb_typeof(p->'quitar') not in ('boolean', 'null') then
    raise exception using errcode = '22023', message = '«quitar» es true o false.';
  end if;
  -- Una línea, una marca viva: de una en una por línea (dos pestañas a la vez: la segunda espera y sustituye a la primera).
  perform pg_advisory_xact_lock(hashtextextended('mx_subs.marca:' || p_asiento::text || ':' || p_orden::text, 0));
  select l.cuenta, l.tercero_tipo, l.tercero_id, a.numero, a.reversa_a,
         (select o.numero from asientos o where o.id = a.reversa_a) as original
    into v_l
    from asiento_lineas l join asientos a on a.id = l.asiento_id
   where l.asiento_id = p_asiento and l.orden = p_orden;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa línea del libro.';
  end if;
  v_nota := nullif(btrim(regexp_replace(left(coalesce(p->>'nota', ''), 500), '[[:space:]]+', ' ', 'g')), '');
  select * into v_vieja from subs_marcas m where m.asiento_id = p_asiento and m.orden = p_orden and m.retirada_el is null for update;
  if coalesce((p->>'quitar')::boolean, false) then
    if v_vieja.id is null then
      raise exception using errcode = 'MX008', message = 'Esa línea no tiene marca que quitar.';
    end if;
    perform set_config('mx_subs.escribe', 'subs_marcas', true);
    update subs_marcas set retirada_el = now(), retirada_por = auth.uid(), retirada_motivo = coalesce(v_nota, 'quitada')
     where id = v_vieja.id;
    perform set_config('mx_subs.escribe', '', true);
    return jsonb_build_object('asiento', p_asiento, 'orden', p_orden, 'quitada', v_vieja.id, 'marca', null);
  end if;
  if v_l.reversa_a is not null then
    raise exception using errcode = 'MX008',
      message = format('%s es un reverso: se marca la línea del asiento original (%s) y su reverso la sigue.', v_l.numero, v_l.original);
  end if;
  v_clase := fn_subs_cuenta_clase(v_l.cuenta);
  if v_clase in ('efectivo', 'tarjeta') then
    raise exception using errcode = 'MX008',
      message = 'Esa es la línea del banco (o de la tarjeta): se marca la línea del gasto, o la de la cuenta por pagar que ese dinero pagó.';
  end if;
  v_trato := nullif(lower(btrim(coalesce(p->>'trato', ''))), '');
  if v_trato is not null and v_trato not in ('servicio', 'no_servicio', 'tarjeta', 'pagado') then
    raise exception using errcode = '22023', message = 'El trato es servicio, no_servicio, tarjeta o pagado.';
  end if;
  if nullif(btrim(coalesce(p->>'ficha', '')), '') is not null then
    begin
      v_ficha := (p->>'ficha')::uuid;
    exception when invalid_text_representation then
      raise exception using errcode = '22023', message = 'La ficha no es un id.';
    end;
    if not exists (select 1 from subs_fichas f where f.id = v_ficha) then
      raise exception using errcode = '22023', message = 'No existe esa ficha.';
    end if;
    if v_l.tercero_id is not null then
      raise exception using errcode = 'MX008',
        message = format('Esa línea ya dice de quién es (en el libro: %s): no se atribuye a otra ficha. Si ese tercero no tiene ficha, '
                         'dásela.', coalesce(fn_subs_tercero_nombre(v_l.tercero_tipo, v_l.tercero_id), v_l.tercero_tipo));
    end if;
  end if;
  if v_ficha is null and v_trato is null then
    raise exception using errcode = '22023', message = 'Una marca dice de quién es el pago (ficha), cómo se trata (trato), o las dos cosas.';
  end if;
  if v_nota is null then
    raise exception using errcode = '22023', message = 'Una marca lleva su nota: por qué (quién te lo dijo, qué papel lo dice).';
  end if;
  perform set_config('mx_subs.escribe', 'subs_marcas', true);
  if v_vieja.id is not null then
    update subs_marcas set retirada_el = now(), retirada_por = auth.uid(), retirada_motivo = 'sustituida' where id = v_vieja.id;
  end if;
  insert into subs_marcas (asiento_id, orden, ficha_id, trato, nota, marcado_por)
  values (p_asiento, p_orden, v_ficha, v_trato, v_nota, auth.uid())
  returning * into v_nueva;
  perform set_config('mx_subs.escribe', '', true);
  return jsonb_build_object('asiento', p_asiento, 'orden', p_orden, 'sustituye', v_vieja.id, 'marca', to_jsonb(v_nueva));
end $$;
revoke execute on function public.fn_subs_marcar(uuid, int, jsonb) from public, anon, service_role;
grant  execute on function public.fn_subs_marcar(uuid, int, jsonb) to authenticated;
comment on function public.fn_subs_marcar(uuid, int, jsonb) is 'c14: marca una línea del libro para el 1099: {ficha? (de quién es, solo si la línea no trae tercero), trato? (servicio | no_servicio | tarjeta | pagado: lo pagó la empresa por otro camino y cuenta como pagado en efectivo), nota}, o la quita ({quitar: true}). Se marca la línea del gasto o la de la cuenta por pagar, no la del banco ni la de la tarjeta, y nunca un reverso (MX008: se marca el original). Una línea, una marca viva: otra la sustituye y la anterior queda retirada. No toca el libro. Devuelve {asiento, orden, marca, sustituye | quitada}. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 9. EL CRITERIO DEL PAGO REPORTABLE (cabecera, punto 4). fn_subs_calculo
--    lee el libro entero y devuelve, de cada línea de servicio y de cada
--    línea de una cuenta por pagar que se paga, sus PARTES: con qué se pagó
--    (medio) y qué es (clase), al centavo. Lo demás (fn_subs_pagos,
--    fn_subs_1099, el COI, el control) sale de aquí: un solo cálculo.
--      via    directo | jornal | cxp (el pago de una partida por pagar)
--      medio  efectivo | tarjeta | por_pagar (devengado contra una cuenta
--             por pagar: no es un pago; cada pago suyo es otra parte, con
--             via «cxp») | otro (ni banco, ni tarjeta, ni cuenta por pagar:
--             lo pagó alguien de su bolsillo, o se saldó contra otra cuenta)
--      clase  servicio | no_servicio | sin_clasificar (no se sabe si es
--             servicio: lo pagado a una partida sin papel —la apertura, o de
--             más—, lo que viene de otra deuda que no se pudo seguir, y lo
--             pagado a alguien CON FICHA por una cuenta de gasto sin la
--             etiqueta 1099)
--    LAS CUENTAS POR PAGAR, POR PARTIDA (cuenta + de quién + papel). Cada
--    partida tiene su COMPOSICIÓN: de todo lo que entró en ella, cuánto fue
--    servicio, cuánto no se sabe y cuánto no lo es. Entra por tres sitios:
--      · un gasto (5200 contra 2010): servicio si la línea lo es;
--      · la apertura (lo que traía QuickBooks): no se sabe;
--      · OTRA partida por pagar (la retención que se separa de la cuenta
--        del sub a la 2020; el anticipo que se cruza con su papel): HEREDA
--        la composición de la partida de la que viene, en proporción. Se
--        sigue hasta cuatro saltos; lo que no se alcance a seguir queda como
--        «no se sabe» (nunca como «no es servicio»).
--    Y sale por cuatro: un pago desde el banco o la caja, uno con tarjeta,
--    un traspaso a otra partida, o «por otro camino» (se saldó contra una
--    cuenta que no es banco, tarjeta ni por pagar: lo pagó Edgar de su
--    bolsillo). Cada salida se lleva SU PARTE PROPORCIONAL de la composición
--    (servicio = lo que sale × servicio ÷ lo que entró), repartida por
--    acumulado en el orden de los pagos: la suma es exacta. Lo pagado de más
--    (por encima de lo que entró) queda «sin clasificar».
--    Solo lee. SECURITY INVOKER: con la policy del dueño.
--    (EL TIEMPO. Es una sola consulta con muchas piezas intermedias, y de una
--    pieza intermedia la base no sabe cuántas filas trae: sin ayuda cruza
--    línea por línea —con 1,500 trabajos y sus pagos, medio minuto—. Por eso
--    cada cruce entre partidas va por una sola llave de texto, las piezas se
--    calculan una vez, y la función corre con «enable_nestloop = off», que
--    solo vale DENTRO de ella: los cruza con tablas de dispersión. Con esos
--    mismos 1,500 trabajos, menos de un segundo.)
-- ---------------------------------------------------------------------
drop function if exists public.fn_subs_calculo();
create function public.fn_subs_calculo()
returns table (fecha date, anio int, asiento_id uuid, numero text, cadena_pos bigint, orden int, cuenta text, via text,
               tercero_tipo text, tercero_id text, ficha_id uuid, medio text, clase text, monto numeric,
               partida_tabla text, partida_id text, descripcion text, banco text, memo text, proyecto_id text,
               origen_tabla text, origen_id text, reverso boolean, anio_original int,
               marca_id uuid, marca_trato text, marca_nota text,
               fecha_libro date, anio_libro int, fecha_banco date)
language plpgsql stable
set search_path = public, pg_temp
set enable_nestloop = off
as $$
#variable_conflict use_column
declare
  v_jornal uuid[] := '{}';
  v_banco  boolean := false;
  v_nunca  text[] := '{}';
begin
  if not fn_subs_ve() then
    return;
  end if;
  -- Los asientos que son un jornal de c10 (si c10 está): todas sus líneas
  -- menos la del banco son el pago a esa persona, vayan a la cuenta que vayan.
  if to_regclass('public.jornal_repartos') is not null then
    begin
      execute 'select coalesce(array_agg(distinct r.asiento_id), ''{}'') from public.jornal_repartos r' into v_jornal;
    exception when others then
      v_jornal := '{}';
    end;
  end if;
  -- ¿Con qué fecha cuenta un pago? La del asiento (de fábrica) o la del banco (subs_config.fecha_pago: ▶ CPA).
  -- Y las cuentas de gasto que nunca son servicio (subs_config.cuentas_no_servicio): por ellas no se pregunta.
  select coalesce(c.fecha_pago = 'banco', false), coalesce(c.cuentas_no_servicio, '{}') into v_banco, v_nunca from subs_config c where c.id = 1;
  return query
  with kc as (
    select c.codigo, public.fn_subs_cuenta_clase(c.codigo) as k,
           (c.tipo not in ('activo', 'pasivo', 'capital')) as res,
           -- (una cuenta de gasto sin la etiqueta por la que se PREGUNTA si lo pagado a alguien con ficha es servicio)
           (c.tipo in ('costo', 'gasto', 'otro_gasto') and not (c.codigo = any (v_nunca))) as duda
      from public.cuentas c),
  cand as (
    select l.asiento_id as id
      from public.asiento_lineas l join kc on kc.codigo = l.cuenta
     where kc.k in ('servicio', 'por_pagar')
    union
    select unnest(v_jornal)
    union
    select m.asiento_id from public.subs_marcas m where m.retirada_el is null
    union
    -- (lo que se le paga a alguien CON FICHA por una cuenta de gasto sin la etiqueta 1099 —el abogado a «profesionales»—:
    -- no se sabe si es servicio; sale «sin clasificar» hasta que Edgar lo diga)
    select l.asiento_id
      from public.subs_terceros st
      join public.asiento_lineas l on l.tercero_tipo = st.tercero_tipo and l.tercero_id = st.tercero_id::text
      join kc on kc.codigo = l.cuenta
     where kc.k = 'otra' and kc.duda),
  cand2 as (
    select c.id from cand c
    union
    select x.id from public.asientos x join cand c on c.id = x.reversa_a),
  a as (
    select x.id, x.numero, x.cadena_pos, x.fecha_contable as fecha_l, x.anio as anio_l, x.tipo, x.reversa_a, x.descripcion,
           x.origen_tabla, x.origen_id, o.anio as anio_o,
           coalesce(x.reversa_a, x.id) as raiz,
           (coalesce(x.reversa_a, x.id) = any (v_jornal)) as es_jornal,
           coalesce(o.procedencia, x.procedencia) as proc,
           -- (el día que dijo el banco, si el asiento nació de un movimiento suyo; un reverso no tiene día del banco)
           case when x.reversa_a is null and (x.procedencia->'movimiento'->>'fecha') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                then (x.procedencia->'movimiento'->>'fecha')::date end as fecha_b
      from public.asientos x
      join cand2 on cand2.id = x.id
      left join public.asientos o on o.id = x.reversa_a),
  l as (
    select a.id, a.numero, a.cadena_pos, a.fecha_l, a.anio_l, a.fecha_b, a.tipo, a.reversa_a, a.descripcion, a.origen_tabla, a.origen_id,
           a.anio_o, a.es_jornal, a.proc,
           case when v_banco and a.fecha_b is not null then a.fecha_b else a.fecha_l end as fecha,
           li.orden, li.cuenta, li.monto, li.proyecto_id, li.memo, li.tercero_tipo, li.tercero_id, li.partida_tabla, li.partida_id,
           -- (el papel dice que se pagó con tarjeta —la regla de la tarjeta de un recibo, c3—: su línea de pago cuenta como
           -- tarjeta aunque su cuenta sea el banco, la de débito, o la tarjeta personal de alguien)
           case when (a.proc->'reglas') ? 'tarjeta'
                     and (kc.k = 'efectivo' or (kc.k = 'otra' and li.cuenta = a.proc->'reglas'->'tarjeta'->>'cuenta')) then 'tarjeta'
                else kc.k end as k,
           kc.res, kc.duda,
           (li.tercero_id is not null
            and exists (select 1 from public.subs_terceros st
                         where st.tercero_tipo = li.tercero_tipo and st.tercero_id::text = li.tercero_id)) as con_ficha,
           mk.id as marca_id, mk.ficha_id as marca_ficha, mk.trato as marca_trato, mk.nota as marca_nota
      from a
      join public.asiento_lineas li on li.asiento_id = a.id
      join kc on kc.codigo = li.cuenta
      left join lateral (select m.id, m.ficha_id, m.trato, m.nota
                           from public.subs_marcas m
                          where m.retirada_el is null and m.orden = li.orden and m.asiento_id in (a.id, a.raiz)
                          order by (m.asiento_id = a.id) desc
                          limit 1) mk on true),
  g as (
    select l.*,
           case when l.k = 'por_pagar' then 'P'
                when l.k in ('efectivo', 'tarjeta') then null
                when l.k = 'servicio' or l.es_jornal or l.marca_id is not null or (l.duda and l.con_ficha) then 'S' end as grupo,
           -- QUÉ ES una línea que no es de banco, de tarjeta ni por pagar: s = servicio; u = no se sabe (a alguien con ficha,
           -- por una cuenta de gasto sin la etiqueta: se pregunta); r = otra cuenta de resultados; b = otra cuenta de balance
           case when l.k in ('efectivo', 'tarjeta', 'por_pagar') then null
                when l.marca_trato = 'no_servicio' then case when l.res then 'r' else 'b' end
                when l.marca_trato = 'servicio' or l.k = 'servicio' or l.es_jornal then 's'
                when l.duda and (l.con_ficha or l.marca_ficha is not null) then 'u'
                when l.res then 'r'
                else 'b' end as q
      from l),
  t as (
    select g.id,
           sum(g.monto) filter (where g.monto > 0) as tt,
           coalesce(-sum(g.monto) filter (where g.k = 'efectivo' and g.monto < 0), 0) as ef_out,
           coalesce( sum(g.monto) filter (where g.k = 'efectivo' and g.monto > 0), 0) as ef_in,
           coalesce(-sum(g.monto) filter (where g.k = 'tarjeta' and g.monto < 0), 0) as tj_out,
           coalesce( sum(g.monto) filter (where g.k = 'tarjeta' and g.monto > 0), 0) as tj_in,
           coalesce(-sum(g.monto) filter (where g.k = 'por_pagar' and g.monto < 0), 0) as pp_out,
           coalesce( sum(g.monto) filter (where g.k = 'por_pagar' and g.monto > 0), 0) as pp_in,
           coalesce( sum(g.monto) filter (where g.q = 's' and g.monto > 0), 0) as sv_pos,
           coalesce(-sum(g.monto) filter (where g.q = 's' and g.monto < 0), 0) as sv_neg,
           coalesce( sum(g.monto) filter (where g.q = 'u' and g.monto > 0), 0) as du_pos,
           coalesce(-sum(g.monto) filter (where g.q = 'u' and g.monto < 0), 0) as du_neg,
           coalesce( sum(g.monto) filter (where g.q = 'r' and g.monto > 0), 0) as rs_pos,
           coalesce(-sum(g.monto) filter (where g.q = 'r' and g.monto < 0), 0) as rs_neg,
           coalesce( sum(g.monto) filter (where g.q = 'b' and g.monto > 0), 0) as ob_pos,
           coalesce(-sum(g.monto) filter (where g.q = 'b' and g.monto < 0), 0) as ob_neg,
           -- (a quién se le debe, si la cuenta por pagar de este asiento nombra a UNO: lo devengado es suyo aunque la línea
           -- del gasto no lo diga —así postea c3 un trabajo externo—)
           count(distinct g.tercero_tipo || ':' || g.tercero_id) filter (where g.k = 'por_pagar' and g.tercero_id is not null) as pp_n,
           min(g.tercero_tipo) filter (where g.k = 'por_pagar' and g.tercero_id is not null) as pp_tt,
           min(g.tercero_id) filter (where g.k = 'por_pagar' and g.tercero_id is not null) as pp_ti
      from g
     group by g.id),
  i as (
    -- cada línea que interesa, con lo que hay al otro lado de su asiento (lo que la financia) y su acumulado dentro del
    -- asiento (por grupo y signo): el reparto por acumulado suma al centavo
    select g.*, t.tt,
           case when g.monto > 0 then t.ef_out else t.ef_in end as q_ef,
           case when g.monto > 0 then t.tj_out else t.tj_in end as q_tj,
           case when g.monto > 0 then t.pp_out else t.pp_in end as q_pp,
           case when g.monto > 0 then t.ob_neg else t.ob_pos end as q_ob,
           case when g.monto > 0 then t.sv_neg else t.sv_pos end as q_sv,
           case when g.monto > 0 then t.du_neg else t.du_pos end as q_du,
           case when g.monto > 0 then t.rs_neg else t.rs_pos end as q_rs,
           sum(g.monto) over (partition by g.id, g.grupo, sign(g.monto) order by g.orden) as cum
      from g join t on t.id = g.id
     where g.grupo is not null and t.tt > 0),
  r as (
    select i.*,
           round(i.cum * i.q_ef / i.tt, 2) - round((i.cum - i.monto) * i.q_ef / i.tt, 2) as p_ef,
           round(i.cum * i.q_tj / i.tt, 2) - round((i.cum - i.monto) * i.q_tj / i.tt, 2) as p_tj,
           round(i.cum * i.q_pp / i.tt, 2) - round((i.cum - i.monto) * i.q_pp / i.tt, 2) as p_pp,
           round(i.cum * i.q_ob / i.tt, 2) - round((i.cum - i.monto) * i.q_ob / i.tt, 2) as p_ob
      from i),
  -- LAS LÍNEAS DE SERVICIO (directo y jornal): sus partes por medio. (La marca «pagado»: lo que no salió del banco ni de
  -- una tarjeta lo pagó la empresa por otro camino, y cuenta como pagado en efectivo ese día.)
  s_items as (
    select r.id, r.orden, m.medio,
           case r.q when 's' then 'servicio' when 'u' then 'sin_clasificar' else 'no_servicio' end as clase,
           m.parte::numeric as parte
      from r
      cross join lateral (values ('efectivo',  case when r.marca_trato = 'tarjeta' then 0 else r.p_ef end
                                               + case when r.marca_trato = 'pagado' then r.monto - r.p_ef - r.p_tj - r.p_pp else 0 end),
                                 ('tarjeta',   r.p_tj + case when r.marca_trato = 'tarjeta' then r.p_ef else 0 end),
                                 ('por_pagar', r.p_pp),
                                 ('otro',      case when r.marca_trato = 'pagado' then 0 else r.monto - r.p_ef - r.p_tj - r.p_pp end)
                         ) m(medio, parte)
     where r.grupo = 'S' and m.parte <> 0),
  -- LAS LÍNEAS DE LAS CUENTAS POR PAGAR. De quién es cada una: del tercero que nombra; si no nombra a nadie y lleva su
  -- partida, del ÚNICO tercero que esa partida nombra en sus otras líneas; y si Edgar la atribuyó a una ficha, del tercero
  -- de esa ficha que tiene líneas en esa cuenta (o de su único tercero).
  pt1 as materialized (
    select r.cuenta || chr(31) || r.partida_tabla || chr(31) || r.partida_id as k1, min(r.tercero_tipo) as tt, min(r.tercero_id) as ti
      from r
     where r.grupo = 'P' and r.tercero_id is not null and r.partida_tabla is not null and r.partida_id is not null
     group by 1
    having count(distinct r.tercero_tipo || ':' || r.tercero_id) = 1),
  pt2 as materialized (
    select st.ficha_id::text || chr(31) || r.cuenta as k2, min(r.tercero_tipo) as tt, min(r.tercero_id) as ti
      from r
      join public.subs_terceros st on st.tercero_tipo = r.tercero_tipo and st.tercero_id::text = r.tercero_id
     where r.grupo = 'P' and r.tercero_id is not null
     group by 1
    having count(distinct r.tercero_tipo || ':' || r.tercero_id) = 1),
  pt3 as materialized (
    select st.ficha_id, min(st.tercero_tipo) as tt, min(st.tercero_id::text) as ti
      from public.subs_terceros st
     group by 1
    having count(*) = 1),
  -- (cada cruce de aquí abajo va por UNA llave de texto —la de la partida, kp— y con sus piezas ya calculadas una vez:
  -- así la base los resuelve con tablas de dispersión y no línea por línea; con miles de partidas la diferencia es de
  -- medio minuto a menos de un segundo)
  pl0 as materialized (
    select r.*,
           case when r.tercero_id is null and r.partida_tabla is not null and r.partida_id is not null
                then r.cuenta || chr(31) || r.partida_tabla || chr(31) || r.partida_id end as j1,
           case when r.tercero_id is null and r.marca_ficha is not null then r.marca_ficha::text || chr(31) || r.cuenta end as j2,
           case when r.tercero_id is null then r.marca_ficha end as j3
      from r
     where r.grupo = 'P'),
  pl as materialized (
    select r.*, e.ett, e.eti,
           -- LA LLAVE DE LA PARTIDA: su cuenta, de quién es y su papel
           r.cuenta || chr(31) || coalesce(e.ett, '') || chr(31) || coalesce(e.eti, '') || chr(31)
             || coalesce(r.partida_tabla, '') || chr(31) || coalesce(r.partida_id, '') as kp,
           -- lo que financia la línea desde cuentas de resultados (el gasto que la devenga, o su reverso)
           (r.monto - r.p_ef - r.p_tj - r.p_pp - r.p_ob) as x_res,
           (r.tt - r.q_ef - r.q_tj - r.q_pp - r.q_ob) as q_res
      from pl0 r
      left join pt1 a1 on a1.k1 = r.j1
      left join pt2 a2 on a2.k2 = r.j2
      left join pt3 a3 on a3.ficha_id = r.j3
      cross join lateral (select case when r.tercero_id is not null then r.tercero_tipo else coalesce(a1.tt, a2.tt, a3.tt) end as ett,
                                 case when r.tercero_id is not null then r.tercero_id else coalesce(a1.ti, a2.ti, a3.ti) end as eti) e),
  -- lo que ENTRA a cada partida sin venir de otra (servicio, no se sabe, no es servicio), con sus reversos restando
  pd as materialized (
    select pl.kp,
           sum(case when pl.tipo = 'apertura' or pl.q_res <= 0 then 0 else -pl.x_res * pl.q_sv / pl.q_res end) as sd,
           sum(case when pl.tipo = 'apertura' then -pl.x_res - pl.p_ob
                    when pl.q_res <= 0 then 0 else -pl.x_res * pl.q_du / pl.q_res end) as ud,
           sum(case when pl.tipo = 'apertura' then 0
                    else (case when pl.q_res <= 0 then -pl.x_res else -pl.x_res * (pl.q_res - pl.q_sv - pl.q_du) / pl.q_res end)
                         + (case when pl.monto < 0 then -pl.p_ob else 0 end) end) as nd
      from pl
     group by 1),
  -- los traspasos entre partidas dentro de un asiento (de la que se carga a la que se abona), en proporción
  -- (de una partida a sí misma no pasa nada: no es un traspaso)
  tr as materialized (
    select d.kp as o_kp, c.kp as d_kp, sum(d.monto * (-c.monto) / d.tt) as flujo
      from (select pl.id, pl.kp, pl.monto, pl.tt from pl where pl.monto > 0) d
      join (select pl.id, pl.kp, pl.monto from pl where pl.monto < 0) c on c.id = d.id
     where c.kp <> d.kp
     group by 1, 2),
  t_in as materialized (select x.d_kp as kp, sum(x.flujo) as f from tr x group by 1),
  t_out as materialized (select x.o_kp as kp, sum(x.flujo) as f from tr x group by 1),
  pa as materialized (
    -- lo que entró a cada partida en total, lo que salió hacia otra (t_out) y lo que le llegó de otra (t_in)
    select pd.kp, pd.sd, pd.ud, pd.nd, coalesce(ti.f, 0) as t_in, coalesce(tu.f, 0) as t_out
      from pd
      left join t_in ti on ti.kp = pd.kp
      left join t_out tu on tu.kp = pd.kp),
  -- LA COMPOSICIÓN, salto a salto: lo que llega de otra partida empieza como «no se sabe» (c0) y en cada salto toma la
  -- composición de la partida de la que viene (c1, c2, c3 y la final, pc). Lo que cuatro saltos no alcancen a seguir se
  -- queda en «no se sabe».
  c0 as materialized (
    select pa.*, (pa.sd + pa.ud + pa.nd + pa.t_in) as a,
           case when pa.sd + pa.ud + pa.nd + pa.t_in > 0
                then least(greatest(pa.sd / (pa.sd + pa.ud + pa.nd + pa.t_in), 0), 1) else 0 end as fs,
           case when pa.sd + pa.ud + pa.nd + pa.t_in > 0
                then least(greatest((pa.ud + pa.t_in) / (pa.sd + pa.ud + pa.nd + pa.t_in), 0), 1) else 1 end as fu
      from pa),
  h0 as materialized (
    select x.d_kp as kp, sum(x.flujo * o.fs) as s, sum(x.flujo * o.fu) as u from tr x join c0 o on o.kp = x.o_kp group by 1),
  c1 as materialized (
    select k.kp, k.sd, k.ud, k.nd, k.t_in, k.t_out, k.a,
           case when k.a > 0 then least(greatest((k.sd + coalesce(h.s, 0)) / k.a, 0), 1) else 0 end as fs,
           case when k.a > 0 then least(greatest((k.ud + coalesce(h.u, 0)) / k.a, 0), 1) else 1 end as fu
      from c0 k
      left join h0 h on h.kp = k.kp),
  h1 as materialized (
    select x.d_kp as kp, sum(x.flujo * o.fs) as s, sum(x.flujo * o.fu) as u from tr x join c1 o on o.kp = x.o_kp group by 1),
  c2 as materialized (
    select k.kp, k.sd, k.ud, k.nd, k.t_in, k.t_out, k.a,
           case when k.a > 0 then least(greatest((k.sd + coalesce(h.s, 0)) / k.a, 0), 1) else 0 end as fs,
           case when k.a > 0 then least(greatest((k.ud + coalesce(h.u, 0)) / k.a, 0), 1) else 1 end as fu
      from c1 k
      left join h1 h on h.kp = k.kp),
  h2 as materialized (
    select x.d_kp as kp, sum(x.flujo * o.fs) as s, sum(x.flujo * o.fu) as u from tr x join c2 o on o.kp = x.o_kp group by 1),
  c3 as materialized (
    select k.kp, k.sd, k.ud, k.nd, k.t_in, k.t_out, k.a,
           case when k.a > 0 then least(greatest((k.sd + coalesce(h.s, 0)) / k.a, 0), 1) else 0 end as fs,
           case when k.a > 0 then least(greatest((k.ud + coalesce(h.u, 0)) / k.a, 0), 1) else 1 end as fu
      from c2 k
      left join h2 h on h.kp = k.kp),
  h3 as materialized (
    select x.d_kp as kp, sum(x.flujo * o.fs) as s, sum(x.flujo * o.fu) as u from tr x join c3 o on o.kp = x.o_kp group by 1),
  pc as materialized (
    select k.kp,
           greatest(round(k.a - k.t_out, 2), 0) as tot,
           case when k.a > 0 then least(greatest((k.sd + coalesce(h.s, 0)) / k.a, 0), 1) else 0 end as fs,
           case when k.a > 0 then least(greatest((k.ud + coalesce(h.u, 0)) / k.a, 0), 1) else 1 end as fu
      from c3 k
      left join h3 h on h.kp = k.kp),
  -- cada SALIDA de una partida que no va a otra partida (un pago en efectivo o con tarjeta, o su devolución; o lo que
  -- se saldó por otro camino), en su orden, con lo salido hasta ella
  pe as materialized (
    select pl.id, pl.orden, pl.fecha_l, pl.cadena_pos, pl.cuenta, pl.marca_trato, pl.ett, pl.eti, pl.kp,
           m.medio, m.x::numeric as x
      from pl
      cross join lateral (values ('efectivo', pl.p_ef), ('tarjeta', pl.p_tj),
                                 ('otro', case when pl.monto > 0 and pl.tipo <> 'apertura' then pl.p_ob else 0 end)) m(medio, x)
     where m.x <> 0),
  ps as (
    select pe.*, pc.tot, least(pc.fs, 1) as fs, least(pc.fu, 1 - least(pc.fs, 1)) as fu,
           sum(pe.x) over (partition by pe.kp order by pe.fecha_l, pe.cadena_pos, pe.orden, pe.medio) as c1
      from pe
      join pc on pc.kp = pe.kp),
  pk as (
    select ps.*, least(greatest(ps.c1, 0), ps.tot) as k1, least(greatest(ps.c1 - ps.x, 0), ps.tot) as k0
      from ps),
  pf as (
    select pk.*,
           round(pk.k1 * pk.fs, 2) - round(pk.k0 * pk.fs, 2) as e_serv,
           round(pk.k1 * pk.fu, 2) - round(pk.k0 * pk.fu, 2) as e_desc
      from pk),
  p_items as (
    select pf.id, pf.orden, pf.ett, pf.eti,
           case when pf.marca_trato = 'tarjeta' and pf.medio = 'efectivo' then 'tarjeta'
                when pf.marca_trato = 'pagado' and pf.medio = 'otro' then 'efectivo'
                else pf.medio end as medio,
           m.clase, m.parte::numeric as parte
      from pf
      cross join lateral (values
        ('servicio',       case pf.marca_trato when 'servicio' then pf.x when 'no_servicio' then 0 else pf.e_serv end),
        ('sin_clasificar', case when pf.marca_trato in ('servicio', 'no_servicio') then 0
                                else pf.e_desc + (pf.x - (pf.k1 - pf.k0)) end),
        ('no_servicio',    case pf.marca_trato when 'servicio' then 0 when 'no_servicio' then pf.x
                                else (pf.k1 - pf.k0) - pf.e_serv - pf.e_desc end)) m(clase, parte)
     where m.parte <> 0),
  todo as (
    select s.id, s.orden, s.medio, s.clase, sum(s.parte) as parte, 'S' as grupo, null::text as ett, null::text as eti
      from s_items s group by 1, 2, 3, 4
    union all
    select p.id, p.orden, p.medio, p.clase, sum(p.parte), 'P', min(p.ett), min(p.eti)
      from p_items p group by 1, 2, 3, 4)
  select g.fecha, extract(year from g.fecha)::int, g.id, g.numero, g.cadena_pos, g.orden, g.cuenta,
         case when z.grupo = 'P' then 'cxp' when g.es_jornal then 'jornal' else 'directo' end,
         q.tt, q.ti,
         coalesce(st.ficha_id, case when q.ti is null then g.marca_ficha end),
         z.medio, z.clase, z.parte,
         g.partida_tabla, g.partida_id, g.descripcion, g.proc->'movimiento'->>'descripcion', g.memo, g.proyecto_id,
         g.origen_tabla, g.origen_id, g.reversa_a is not null, g.anio_o,
         g.marca_id, g.marca_trato, g.marca_nota,
         g.fecha_l, g.anio_l, g.fecha_b
    from todo z
    join g on g.id = z.id and g.orden = z.orden
    join t on t.id = z.id
    cross join lateral (
      select case when z.grupo = 'P' then z.ett
                  when g.tercero_id is null and z.medio = 'por_pagar' and t.pp_n = 1 then t.pp_tt else g.tercero_tipo end as tt,
             case when z.grupo = 'P' then z.eti
                  when g.tercero_id is null and z.medio = 'por_pagar' and t.pp_n = 1 then t.pp_ti else g.tercero_id end as ti) q
    left join public.subs_terceros st on st.tercero_tipo = q.tt and st.tercero_id::text = q.ti
   where z.parte <> 0;
end $$;
revoke execute on function public.fn_subs_calculo() from public, anon, service_role;
grant  execute on function public.fn_subs_calculo() to authenticated;
comment on function public.fn_subs_calculo() is 'c14: el criterio del pago reportable, sobre el libro entero: de cada línea de servicio (cuentas con etiqueta 1099, las líneas de un jornal de c10, lo marcado, y lo pagado a alguien con ficha por una cuenta de gasto sin la etiqueta) y de cada línea de una cuenta por pagar que se paga, sus partes al centavo: via (directo | jornal | cxp), medio (efectivo | tarjeta | por_pagar | otro) y clase (servicio | no_servicio | sin_clasificar), con su fecha (la del asiento; o la del banco si subs_config.fecha_pago = banco) y su año, su tercero y su ficha, su partida, su marca y si es un reverso (y de qué año era el original); y fecha_libro, anio_libro (los del asiento) y fecha_banco (lo que dijo el banco, si lo hay). Cada partida por pagar lleva su composición (servicio, no se sabe, no es servicio), que HEREDA de la partida de la que viene cuando una deuda pasa de una cuenta por pagar a otra (la retención, el anticipo cruzado), y cada salida se lleva su parte proporcional. El reparto dentro del asiento y entre los pagos de una partida es por acumulado (suma exacta). Solo lectura; a quien no es el dueño, nada.';

-- CADA PARTE DE CADA PAGO, como la pinta la pantalla (un año, o todos):
--   estado  cuenta        servicio pagado en efectivo: suma al 1099
--           tarjeta       servicio pagado con tarjeta: lo reporta el procesador
--           sin_clasificar  no se sabe si es servicio (pagado a una partida
--                         sin papel, o a alguien con ficha por una cuenta sin
--                         la etiqueta): por decidir
--           no_servicio   no es servicio (material, o marcado)
--           por_pagar     servicio devengado contra una cuenta por pagar:
--                         no suma; cuenta el día de cada pago (su parte
--                         «cxp», que sale aparte)
--           otro_camino   servicio (o sin clasificar) que no se pagó desde
--                         el banco ni con tarjeta: lo pagó alguien de su
--                         bolsillo, o su deuda se saldó contra otra cuenta.
--                         No suma hasta que Edgar lo marque «pagado»
--   fecha, anio           con los que cuenta (subs_config.fecha_pago: el
--                         asiento, o el banco); fecha_libro, anio_libro y
--                         fecha_banco, los dos por separado
--   sugerencia_ficha_id, sugerencia_ficha   para un pago SIN tercero: la
--           ÚNICA ficha activa cuyo nombre (el legal, el comercial o el de
--           uno de sus terceros, de 4 letras o más) aparece en lo que dijo
--           el banco, en la descripción del asiento o en la nota de la
--           línea. Es una propuesta para atribuirlo de un toque: no cuenta
--           hasta que Edgar lo atribuye.
drop function if exists public.fn_subs_pagos(int);
create function public.fn_subs_pagos(p_anio int default null)
returns table (anio int, fecha date, asiento_id uuid, numero text, orden int, cuenta text, cuenta_nombre text, via text,
               medio text, clase text, estado text, monto numeric, ficha_id uuid, ficha text,
               tercero_tipo text, tercero_id text, tercero text, partida_tabla text, partida_id text,
               descripcion text, banco text, memo text, proyecto_id text, origen_tabla text, origen_id text,
               reverso boolean, anio_original int, marca_id uuid, marca_trato text, marca_nota text,
               sugerencia_ficha_id uuid, sugerencia_ficha text,
               fecha_libro date, anio_libro int, fecha_banco date)
language sql stable
set search_path = public, pg_temp
as $$
  select c.anio, c.fecha, c.asiento_id, c.numero, c.orden, c.cuenta, k.nombre, c.via, c.medio, c.clase,
         case when c.medio = 'por_pagar' then 'por_pagar'
              when c.clase = 'no_servicio' then 'no_servicio'
              when c.medio = 'otro' then 'otro_camino'
              when c.clase = 'sin_clasificar' then 'sin_clasificar'
              when c.medio = 'tarjeta' then 'tarjeta'
              else 'cuenta' end,
         c.monto, c.ficha_id,
         (select coalesce(f.nombre_legal, f.nombre_comercial) from public.subs_fichas f where f.id = c.ficha_id),
         c.tercero_tipo, c.tercero_id, public.fn_subs_tercero_nombre(c.tercero_tipo, c.tercero_id),
         c.partida_tabla, c.partida_id, c.descripcion, c.banco, c.memo, c.proyecto_id, c.origen_tabla, c.origen_id,
         c.reverso, c.anio_original, c.marca_id, c.marca_trato, c.marca_nota,
         case when sg.n = 1 then sg.id end, case when sg.n = 1 then sg.nombre end,
         c.fecha_libro, c.anio_libro, c.fecha_banco
    from public.fn_subs_calculo() c
    left join public.cuentas k on k.codigo = c.cuenta
    left join lateral (
      select count(*) as n, min(f.id::text)::uuid as id, min(coalesce(f.nombre_legal, f.nombre_comercial)) as nombre
        from public.subs_fichas f
       where c.ficha_id is null and c.tercero_id is null and c.medio in ('efectivo', 'tarjeta', 'otro') and f.activa
         and exists (select 1
                       from unnest(array[f.nombre_legal, f.nombre_comercial]
                                   || array(select public.fn_subs_tercero_nombre(t.tercero_tipo, t.tercero_id::text)
                                              from public.subs_terceros t where t.ficha_id = f.id)) nm
                      where length(btrim(nm)) >= 4
                        and position(lower(btrim(nm)) in lower(concat_ws(' ', c.banco, c.descripcion, c.memo))) > 0)) sg on true
   where p_anio is null or c.anio = p_anio
$$;
revoke execute on function public.fn_subs_pagos(int) from public, anon, service_role;
grant  execute on function public.fn_subs_pagos(int) to authenticated;
comment on function public.fn_subs_pagos(int) is 'c14: cada parte de cada pago de un año (o de todos), para bajar al asiento: su fecha (con la que cuenta) y su año, su asiento y su línea, la cuenta, por dónde llegó (via), con qué se pagó (medio), qué es (clase) y cómo cuenta (estado: cuenta | tarjeta | sin_clasificar | no_servicio | por_pagar | otro_camino), el monto, de quién es (ficha y tercero), su partida, la descripción del asiento y la del banco, su marca y si es un reverso; para un pago sin tercero, la ficha sugerida (la única cuyo nombre aparece en lo que dijo el banco o el asiento); y fecha_libro, anio_libro (los del asiento) y fecha_banco (lo que dijo el banco). Solo lectura; a quien no es el dueño, nada.';

-- LO DE ANTES DEL LIBRO de un año: los trabajos externos (papeles, no
-- pagos) fechados antes del primer día del libro, por quién. Su pago está
-- en QuickBooks: esto sirve para CRUZAR el 1099 de 2026 que sale de allí.
drop function if exists public.fn_subs_antes(int);
create function public.fn_subs_antes(p_anio int)
returns table (clave text, ficha_id uuid, proveedor_id uuid, externo_id bigint, nombre text, papeles int, costo numeric,
               desde date, hasta date)
language sql stable
set search_path = public, pg_temp
as $$
  with x as (
    select t.fecha, round(t.costo, 2) as costo, t.externo_id, t.descripcion,
           coalesce(t.proveedor_id, (select pr.id from public.proveedores pr where pr.externo_id = t.externo_id)) as prov
      from public.trabajos_externos t
     where public.fn_subs_ve() and t.fecha < public.fn_subs_libro_desde()
       and extract(year from t.fecha)::int = p_anio and round(t.costo, 2) <> 0),
  y as (
    select x.fecha, x.costo, x.prov, case when x.prov is null then x.externo_id end as ext,
           (select st.ficha_id from public.subs_terceros st where st.tercero_tipo = 'proveedor' and st.tercero_id = x.prov) as ficha
      from x)
  select coalesce('ficha:' || y.ficha::text, 'proveedor:' || y.prov::text, 'externo:' || y.ext::text, 'sin nombre'),
         y.ficha, y.prov, y.ext,
         coalesce((select coalesce(f.nombre_legal, f.nombre_comercial) from public.subs_fichas f where f.id = y.ficha),
                  (select pr.nombre from public.proveedores pr where pr.id = y.prov),
                  (select e.nombre from public.externos_equipo e where e.id = y.ext) || ' (ayudante de la app, sin proveedor)',
                  'sin nombre (escrito libre)'),
         count(*)::int, sum(y.costo), min(y.fecha), max(y.fecha)
    from y
   group by y.ficha, y.prov, y.ext
   order by 7 desc
$$;
revoke execute on function public.fn_subs_antes(int) from public, anon, service_role;
grant  execute on function public.fn_subs_antes(int) to authenticated;
comment on function public.fn_subs_antes(int) is 'c14: lo de antes del libro de un año, por quién: los trabajos externos (papeles, no pagos) fechados antes del primer día del libro, con cuántos son, cuánto suman y entre qué fechas. Su pago está en QuickBooks: sirve para cruzar el 1099 de 2026 que sale de allí. Solo lectura; a quien no es el dueño, nada.';

-- CÓMO ESTABA UNA FICHA UN DÍA: su tipo de entidad y si se le reportaba. Lo
-- que dice hoy, salvo que un TRAMO (subs_tramos) diga que hasta ese día (o
-- uno posterior) valía otra cosa. Es lo que hace que cambiar una ficha «desde
-- el 1 de enero» no reescriba el 1099 del año anterior.
drop function if exists public.fn_subs_estado_al(uuid, date);
create function public.fn_subs_estado_al(p_ficha uuid, p_fecha date)
returns table (tipo_entidad text, reporta text, reporta_nota text, es_corporacion boolean, reporta_efectivo text, hasta date)
language sql stable
set search_path = public, pg_temp
as $$
  with g as (select c.entidades_no_reporta from public.subs_config c where c.id = 1),
  x as (
    select t.tipo_entidad, t.reporta, t.reporta_nota, t.hasta
      from public.subs_tramos t
     where t.ficha_id = p_ficha and t.retirado_el is null and t.hasta >= p_fecha
     order by t.hasta
     limit 1),
  y as (
    select x.tipo_entidad, x.reporta, x.reporta_nota, x.hasta from x
    union all
    select f.tipo_entidad, f.reporta, f.reporta_nota, null::date
      from public.subs_fichas f
     where f.id = p_ficha and not exists (select 1 from x))
  select y.tipo_entidad, y.reporta, y.reporta_nota,
         coalesce(y.tipo_entidad = any (g.entidades_no_reporta), false),
         case when y.reporta = 'por_decidir' and coalesce(y.tipo_entidad = any (g.entidades_no_reporta), false) then 'no' else y.reporta end,
         y.hasta
    from y cross join g
   where public.fn_subs_ve()
$$;
revoke execute on function public.fn_subs_estado_al(uuid, date) from public, anon, service_role;
grant  execute on function public.fn_subs_estado_al(uuid, date) to authenticated;
comment on function public.fn_subs_estado_al(uuid, date) is 'c14: cómo estaba una ficha un día: su tipo de entidad, si se le reportaba (reporta, y reporta_efectivo: por decidir + corporación = no), su nota, si era corporación y hasta qué día valió eso (nulo = es lo de hoy). Sale del tramo vivo de esa ficha que cubre el día (subs_tramos) o, si no hay, de la ficha. Solo lectura; a quien no es el dueño, nada.';

-- EL 1099 DE UN AÑO: una fila por ficha con pagos o con servicio devengado
-- (y por tercero del libro sin ficha, y una por lo pagado sin tercero).
--   clave             ficha:<id> | <tipo>:<id del tercero> | sin_tercero
--   pagado_servicio   lo pagado en efectivo por servicios (base caja)
--   pagado_tarjeta    servicio pagado con tarjeta (no se reporta)
--   sin_clasificar    en efectivo y no se sabe si es servicio (por decidir)
--   no_servicio       en efectivo, y no es servicio (material…): informa
--   reporta_efectivo  si | no | por_decidir | sin_ficha | sin_tercero, como
--                     está la ficha al final de ese año (o hoy, si el año
--                     no ha terminado)
--   reportable        lo de pagado_servicio que se le reporta: CADA PAGO
--                     CUENTA COMO ESTABA LA FICHA EL DÍA DEL PAGO (sus
--                     tramos): lo pagado mientras «no se le reportaba» o era
--                     corporación no entra; lo de antes o después, sí
--   excluido, excluido_por   lo que no se reporta y por qué: [{motivo:
--                     tarjeta | corporacion | no_se_reporta, monto, texto}]
--   umbral, pasa_umbral   reportable > 0 y ≥ el umbral del año
--   falta, falta_texto    ficha | tercero | nombre_legal | tipo_entidad |
--                     direccion | tin | w9 | decidir
--   listo             pasa del umbral y no le falta nada: entra en la hoja
--   parcial, parcial_texto   el año en que empieza el libro: lo de antes
--                     está en QuickBooks; antes_del_libro, sus papeles
--   pagos             cada parte en efectivo, con tarjeta o por otro camino
--                     que lo forma: [{fecha, asiento_id, numero, orden,
--                     cuenta, via, medio, clase, estado, monto,
--                     partida_tabla, partida_id, descripcion, banco, reverso,
--                     marca_trato, sugerencia_ficha_id, sugerencia_ficha}]
--   otro_camino       servicio (o sin clasificar) que no salió del banco ni
--                     de una tarjeta: no está en reportable hasta que se
--                     marque «pagado»
--   devengado         servicio que entró a una cuenta por pagar en el año
--                     (el trabajo, se haya pagado o no): informa
--   cambios           si la ficha cambió (sus tramos): qué valía hasta qué día
drop function if exists public.fn_subs_1099(int);
create function public.fn_subs_1099(p_anio int)
returns table (anio int, clave text, ficha_id uuid, tercero_tipo text, tercero_id text, nombre text, tipo_entidad text,
               reporta text, reporta_efectivo text, pagado_servicio numeric, pagado_tarjeta numeric, sin_clasificar numeric,
               no_servicio numeric, reportable numeric, excluido numeric, excluido_por jsonb, umbral numeric, pasa_umbral boolean,
               falta text[], falta_texto text, listo boolean, tin_tipo text, tin_ultimos4 text, tin_mascara text,
               parcial boolean, parcial_texto text, antes_del_libro numeric, n_pagos int, pagos jsonb,
               otro_camino numeric, devengado numeric, cambios text)
language sql stable
set search_path = public, pg_temp
as $$
  with pg0 as (
    select p.*, coalesce('ficha:' || p.ficha_id::text, p.tercero_tipo || ':' || p.tercero_id, 'sin_tercero') as clave
      from public.fn_subs_pagos(p_anio) p),
  -- (cómo estaba la ficha el día de cada pago)
  est as (
    select d.ficha_id, d.fecha, e.reporta_efectivo as rep, e.reporta as dicho, e.reporta_nota as nota
      from (select distinct pg0.ficha_id, pg0.fecha from pg0 where pg0.ficha_id is not null) d
      cross join lateral public.fn_subs_estado_al(d.ficha_id, d.fecha) e),
  pg as (
    select pg0.*, est.rep, est.dicho, est.nota as rep_nota
      from pg0 left join est on est.ficha_id = pg0.ficha_id and est.fecha = pg0.fecha),
  s as (
    select pg.clave, min(pg.ficha_id::text)::uuid as ficha_id,
           min(pg.tercero_tipo) filter (where pg.ficha_id is null) as tercero_tipo,
           min(pg.tercero_id) filter (where pg.ficha_id is null) as tercero_id,
           coalesce(sum(pg.monto) filter (where pg.estado = 'cuenta'), 0) as serv,
           coalesce(sum(pg.monto) filter (where pg.estado = 'cuenta' and pg.rep = 'no' and pg.dicho = 'no'), 0) as serv_no,
           coalesce(sum(pg.monto) filter (where pg.estado = 'cuenta' and pg.rep = 'no' and pg.dicho <> 'no'), 0) as serv_corp,
           coalesce(sum(pg.monto) filter (where pg.estado = 'cuenta' and pg.rep = 'por_decidir'), 0) as serv_pd,
           coalesce(sum(pg.monto) filter (where pg.estado = 'tarjeta'), 0) as tarj,
           coalesce(sum(pg.monto) filter (where pg.estado = 'sin_clasificar' and pg.medio = 'efectivo'), 0) as sinc,
           coalesce(sum(pg.monto) filter (where pg.estado = 'no_servicio' and pg.medio = 'efectivo'), 0) as nose,
           coalesce(sum(pg.monto) filter (where pg.estado = 'otro_camino'), 0) as otro,
           coalesce(sum(pg.monto) filter (where pg.estado = 'por_pagar' and pg.clase = 'servicio'), 0) as dev,
           count(*) filter (where pg.clase = 'servicio' and pg.medio in ('efectivo', 'tarjeta')) as n_serv,
           (count(*) filter (where pg.medio in ('efectivo', 'tarjeta', 'otro')))::int as n,
           max(pg.rep_nota) filter (where pg.estado = 'cuenta' and pg.dicho = 'no') as nota_no,
           coalesce(jsonb_agg(jsonb_build_object('fecha', pg.fecha, 'asiento_id', pg.asiento_id, 'numero', pg.numero, 'orden', pg.orden,
                                        'cuenta', pg.cuenta, 'via', pg.via, 'medio', pg.medio, 'clase', pg.clase, 'estado', pg.estado,
                                        'monto', pg.monto, 'partida_tabla', pg.partida_tabla, 'partida_id', pg.partida_id,
                                        'descripcion', pg.descripcion, 'banco', pg.banco, 'reverso', pg.reverso,
                                        'marca_trato', pg.marca_trato, 'sugerencia_ficha_id', pg.sugerencia_ficha_id,
                                        'sugerencia_ficha', pg.sugerencia_ficha)
                              order by pg.fecha, pg.numero, pg.orden, pg.medio, pg.clase)
                      filter (where pg.medio in ('efectivo', 'tarjeta', 'otro')), '[]'::jsonb) as pagos
      from pg
     group by pg.clave),
  u as (
    select s.*, f.nombre as f_nombre, f.tipo_entidad as f_tipo, f.nombre_legal as f_legal, f.direccion_completa as f_dir,
           f.w9_archivo_id as f_w9, f.tin_tipo, f.tin_ultimos4, f.tin_mascara,
           e.reporta as e_dicho, e.reporta_efectivo as e_rep, e.reporta_nota as e_nota, e.tipo_entidad as e_tipo,
           public.fn_subs_umbral(p_anio) as umbral,
           (extract(year from public.fn_subs_libro_desde())::int = p_anio
            and public.fn_subs_libro_desde() > make_date(p_anio, 1, 1)) as parcial
      from s
      left join public.fn_subs_fichas(null) f on f.ficha_id = s.ficha_id
      -- (la ficha como estaba al final de ese año; o como está hoy, si el año no ha terminado)
      left join lateral public.fn_subs_estado_al(s.ficha_id, least(make_date(p_anio, 12, 31), public.fn_subs_hoy())) e
             on s.ficha_id is not null
     -- (sale quien tiene servicio pagado, algo sin clasificar, algo por otro camino, o —con nombre— servicio devengado.
     --  El proveedor de solo material, sin nada de eso, no es un sub: no sale)
     where s.n_serv > 0 or s.sinc <> 0 or s.otro <> 0
        or (s.dev <> 0 and (s.ficha_id is not null or s.tercero_id is not null))),
  v as (
    select u.*,
           case when u.ficha_id is not null then u.e_rep when u.tercero_id is not null then 'sin_ficha' else 'sin_tercero' end as rep,
           (u.serv - u.serv_no - u.serv_corp) as reportable,
           (select coalesce(sum(x.costo), 0) from public.fn_subs_antes(p_anio) x
             where (u.ficha_id is not null and x.ficha_id = u.ficha_id)
                or (u.ficha_id is null and u.tercero_tipo = 'proveedor' and x.proveedor_id::text = u.tercero_id)) as antes
      from u),
  w as (
    select v.*,
           case when v.ficha_id is null then null
                when v.rep = 'no' and v.reportable = 0 then '{}'::text[]
                else array_remove(array[case when v.f_legal is null then 'nombre_legal' end,
                                        case when coalesce(v.e_tipo, v.f_tipo) is null then 'tipo_entidad' end,
                                        case when not v.f_dir then 'direccion' end,
                                        case when v.tin_ultimos4 is null then 'tin' end,
                                        case when v.f_w9 is null then 'w9' end,
                                        case when v.rep = 'por_decidir' or v.serv_pd <> 0 then 'decidir' end], null) end as f_falta
      from v)
  select p_anio, w.clave, w.ficha_id, w.tercero_tipo, w.tercero_id,
         case when w.ficha_id is not null then w.f_nombre
              when w.tercero_id is not null then coalesce(public.fn_subs_tercero_nombre(w.tercero_tipo, w.tercero_id), '(ya no existe)')
              else 'Sin tercero: pagos que el libro no dice de quién son' end,
         coalesce(w.e_tipo, w.f_tipo), w.e_dicho, w.rep,
         w.serv, w.tarj, w.sinc, w.nose, w.reportable,
         w.tarj + (w.serv - w.reportable),
         (select coalesce(jsonb_agg(e.j order by e.n), '[]'::jsonb)
            from (values (1, case when w.tarj <> 0
                                  then jsonb_build_object('motivo', 'tarjeta', 'monto', w.tarj,
                                                          'texto', 'Pagado con tarjeta: lo reporta el procesador de la tarjeta.') end),
                         (2, case when w.serv_corp <> 0
                                  then jsonb_build_object('motivo', 'corporacion', 'monto', w.serv_corp,
                                                          'texto', 'Pagado cuando era una corporación: no se le reporta (salvo que su ficha diga «sí» con su nota).') end),
                         (3, case when w.serv_no <> 0
                                  then jsonb_build_object('motivo', 'no_se_reporta', 'monto', w.serv_no,
                                                          'texto', 'Pagado cuando su ficha decía que no se le reporta: ' || coalesce(w.nota_no, 'es una corporación.')) end)
                 ) e(n, j)
           where e.j is not null),
         w.umbral, (w.reportable > 0 and w.reportable >= w.umbral),
         case w.rep when 'sin_ficha' then array['ficha'] when 'sin_tercero' then array['tercero'] else w.f_falta end,
         case w.rep when 'sin_ficha' then 'su ficha (con su W-9 y su TIN)'
                    when 'sin_tercero' then 'decir de quién es cada pago (atribuirlo a una ficha)'
                    else (select string_agg(case x.f when 'nombre_legal' then 'su nombre legal (el del W-9)'
                                                      when 'tipo_entidad' then 'su tipo de entidad'
                                                      when 'direccion' then 'su dirección completa'
                                                      when 'tin' then 'su TIN'
                                                      when 'w9' then 'su W-9 (el archivo)'
                                                      when 'decidir' then 'decidir con el CPA si se le reporta' end, ', ' order by x.n)
                            from unnest(w.f_falta) with ordinality x(f, n)) end,
         (w.ficha_id is not null and cardinality(w.f_falta) = 0 and w.reportable > 0 and w.reportable >= w.umbral),
         w.tin_tipo, w.tin_ultimos4, w.tin_mascara,
         w.parcial,
         case when w.parcial
              then format('PARCIAL: el libro de la app empieza el %s. Lo pagado antes está en QuickBooks, y el 1099 de %s sale de allí.',
                          public.fn_subs_dia(public.fn_subs_libro_desde()), p_anio) end,
         w.antes, w.n, w.pagos,
         w.otro, w.dev,
         (select string_agg(format('hasta el %s: %s%s', public.fn_subs_dia(t.hasta),
                                   case when t.reporta = 'no' then 'no se le reportaba' || coalesce(' («' || left(t.reporta_nota, 80) || '»)', '')
                                        when t.reporta = 'si' then 'se le reportaba' else 'estaba por decidir' end,
                                   coalesce(', como ' || t.tipo_entidad, '')), '; ' order by t.hasta)
            from public.subs_tramos t
           where t.ficha_id = w.ficha_id and t.retirado_el is null and t.hasta >= make_date(p_anio, 1, 1) - 1)
    from w
   order by w.reportable desc, 6
$$;
revoke execute on function public.fn_subs_1099(int) from public, anon, service_role;
grant  execute on function public.fn_subs_1099(int) to authenticated;
comment on function public.fn_subs_1099(int) is 'c14: el 1099 de un año, una fila por ficha con pagos o con servicio devengado (y por tercero del libro sin ficha, y una por lo pagado sin tercero): pagado_servicio (en efectivo: base caja), pagado_tarjeta, sin_clasificar y no_servicio; reporta y reporta_efectivo (si | no | por_decidir | sin_ficha | sin_tercero: la ficha al final de ese año); reportable (cada pago cuenta como estaba la ficha el día del pago: sus tramos); excluido y excluido_por ([{motivo: tarjeta | corporacion | no_se_reporta, monto, texto}]); umbral y pasa_umbral (reportable > 0 y ≥ el umbral del año); falta y falta_texto (ficha, tercero, nombre_legal, tipo_entidad, direccion, tin, w9, decidir); listo (entra en la hoja); el TIN con máscara; parcial (el año en que empieza el libro) y antes_del_libro (sus papeles de antes); pagos: cada parte que lo forma, con su asiento y su línea; otro_camino (servicio que no salió del banco ni de una tarjeta: no cuenta hasta marcarlo «pagado»), devengado (servicio que entró a una cuenta por pagar en el año) y cambios (qué valía la ficha hasta qué día). Un proveedor de solo material, sin nada sin clasificar, no sale. Solo lectura; no toca subs_tin; a quien no es el dueño, nada.';

-- LA HOJA DEL 1099 (la ÚNICA salida del TIN entero). Una fila por ficha que
-- se reporta, pasa del umbral y está completa. Pide el código del teléfono.
-- p_opciones: {"bajo_umbral": true} incluye también a quien no llega al
-- umbral (para repasarlo con el CPA). Devuelve:
--   {anio, umbral, generado_el, exportacion (su id), nombre_archivo,
--    columnas: […], filas: [{…, "Recipient TIN": el TIN entero, …}],
--    csv (el texto del archivo: todas las celdas entre comillas, CRLF),
--    cuantos, total,
--    pendientes: [{clave, ficha_id, nombre, monto, sin_clasificar,
--    otro_camino, falta, falta_texto, por_que}]: lo que pasa del umbral (o
--    lo pasaría con lo que tiene sin clasificar o por otro camino) y NO
--    entra; y los pagos SIN NOMBRE, sean del monto que sean (no son de una
--    persona: cualquiera de ellos puede ser de alguien de la hoja),
--    avisos: [{orden, control, detalle}]: lo que el control de ese año tiene
--    en rojo y cambia la hoja (servicio a alguien sin ficha, pagos sin
--    nombre, por otro camino, por decidir, sin clasificar); completa: no hay
--    pendientes ni avisos,
--    parcial, parcial_texto}
-- LA HOJA NO SE CALLA LO QUE LE FALTA: si «completa» es falso, la pantalla lo
-- enseña antes de bajar el archivo. Queda apuntada en subs_exportaciones
-- (sin TIN). Nada se manda a ningún sitio: la app baja el archivo. Con POST.
create or replace function public.fn_subs_1099_export(p_anio int, p_opciones jsonb default '{}'::jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c_cols constant text[] := array['Form', 'Tax Year', 'Recipient TIN Type', 'Recipient TIN', 'Recipient Name', 'Recipient Name Line 2',
                                  'Address Line 1', 'Address Line 2', 'City', 'State', 'ZIP', 'Country',
                                  'Box 1 Nonemployee Compensation', 'Box 4 Federal Income Tax Withheld', 'Account Number'];
  v_op     jsonb := coalesce(p_opciones, '{}'::jsonb);
  v_bajo   boolean;
  v_umbral numeric;
  v_r      jsonb;
  v_x      jsonb;
  v_filas  jsonb;
  v_pend   jsonb;
  v_avisos jsonb;
  v_csv    text;
  v_n      int;
  v_total  numeric;
  v_falta  int;
  v_huella text;
  v_det    jsonb;
  v_id     uuid;
  v_cuando timestamptz;
  v_parc   text;
begin
  perform fn_subs_exigir_dueno();
  perform fn_subs_exigir_codigo();
  -- La hoja lleva el TIN entero: sale solo por la app (el dueño, con su código). En el SQL Editor se quedaría en su
  -- pantalla y en su historial, y desde ahí no hay código del teléfono que pedir.
  if not fn_subs_por_api() then
    raise exception using errcode = '42501',
      message = 'La hoja del 1099 lleva el TIN entero y no se saca desde el SQL Editor: bájala en la app (Contabilidad → Subs y '
                '1099), con el código del teléfono. Aquí puedes mirar lo mismo sin el TIN: select * from fn_subs_1099(año).';
  end if;
  if p_anio is null or not exists (select 1 from fn_subs_anios() a where a.anio = p_anio) then
    raise exception using errcode = '22023',
      message = format('No hay 1099 de %s en la app: el libro va de %s a %s.', coalesce(p_anio::text, '(sin año)'),
                       (select min(a.anio) from fn_subs_anios() a), (select max(a.anio) from fn_subs_anios() a));
  end if;
  if jsonb_typeof(v_op) <> 'object' or (select count(*) from jsonb_object_keys(v_op) k where k not in ('bajo_umbral')) > 0
     or (v_op ? 'bajo_umbral' and jsonb_typeof(v_op->'bajo_umbral') <> 'boolean') then
    raise exception using errcode = '22023', message = 'Las opciones de la hoja: {"bajo_umbral": true | false}.';
  end if;
  v_bajo   := coalesce((v_op->>'bajo_umbral')::boolean, false);
  v_umbral := fn_subs_umbral(p_anio);
  -- el 1099 del año, una vez (sin el detalle de sus pagos)
  select coalesce(jsonb_agg(to_jsonb(r) - 'pagos'), '[]'::jsonb) into v_r from fn_subs_1099(p_anio) r;

  -- LAS FILAS, con la marca del TIN puesta SOLO mientras se leen. No pasan por ninguna tabla.
  perform set_config('mx_subs.tin', '1', true);
  select coalesce(jsonb_agg(jsonb_build_object('n', q.n, 'ficha_id', q.ficha_id, 'monto', q.monto, 'fila', q.fila) order by q.n), '[]'::jsonb)
    into v_x
    from (select row_number() over (order by f.nombre_legal, r.ficha_id) as n, r.ficha_id, r.reportable as monto,
                 jsonb_build_object(
                   'Form', '1099-NEC', 'Tax Year', p_anio::text,
                   'Recipient TIN Type', upper(f.tin_tipo),
                   'Recipient TIN', case f.tin_tipo when 'ein' then substr(t.tin, 1, 2) || '-' || substr(t.tin, 3)
                                                    else substr(t.tin, 1, 3) || '-' || substr(t.tin, 4, 2) || '-' || substr(t.tin, 6) end,
                   'Recipient Name', f.nombre_legal, 'Recipient Name Line 2', coalesce(f.nombre_comercial, ''),
                   'Address Line 1', f.direccion, 'Address Line 2', coalesce(f.direccion2, ''), 'City', f.ciudad, 'State', f.estado,
                   'ZIP', f.zip, 'Country', 'US',
                   'Box 1 Nonemployee Compensation', to_char(r.reportable, 'FM999999999990.00'),
                   'Box 4 Federal Income Tax Withheld', '0.00',
                   'Account Number', left(r.ficha_id::text, 8)) as fila
            from jsonb_to_recordset(v_r) as r(ficha_id uuid, falta text[], reportable numeric, pasa_umbral boolean)
            join subs_fichas f on f.id = r.ficha_id
            join subs_tin t on t.ficha_id = r.ficha_id
           where r.ficha_id is not null and cardinality(r.falta) = 0 and r.reportable > 0 and (r.pasa_umbral or v_bajo)) q;
  perform set_config('mx_subs.tin', '', true);

  select coalesce(jsonb_agg(x.fila order by x.n), '[]'::jsonb), count(*)::int, coalesce(sum(x.monto), 0),
         md5(coalesce(string_agg(x.ficha_id::text || ':' || x.monto::text, '|' order by x.ficha_id), '')),
         coalesce(jsonb_agg(jsonb_build_object('ficha_id', x.ficha_id, 'nombre', x.fila->>'Recipient Name',
                                               'tin_ultimos4', right(x.fila->>'Recipient TIN', 4), 'monto', x.monto) order by x.n), '[]'::jsonb)
    into v_filas, v_n, v_total, v_huella, v_det
    from jsonb_to_recordset(v_x) as x(n int, ficha_id uuid, monto numeric, fila jsonb);
  -- el archivo: cabecera y una línea por fila; cada celda entre comillas (las suyas, dobladas); CRLF
  select string_agg(l.linea, E'\r\n' order by l.n) || E'\r\n' into v_csv
    from (select 0 as n, (select string_agg('"' || replace(u.c, '"', '""') || '"', ',' order by u.o)
                            from unnest(c_cols) with ordinality u(c, o)) as linea
          union all
          select x.n, (select string_agg('"' || replace(coalesce(x.fila->>u.c, ''), '"', '""') || '"', ',' order by u.o)
                         from unnest(c_cols) with ordinality u(c, o))
            from jsonb_to_recordset(v_x) as x(n int, fila jsonb)) l;
  -- lo que pasa del umbral (o lo pasaría con lo que tiene sin clasificar o por otro camino) y NO entra, con su porqué; y
  -- los pagos sin nombre, sean del monto que sean
  select coalesce(jsonb_agg(jsonb_build_object('clave', r.clave, 'ficha_id', r.ficha_id, 'nombre', r.nombre, 'monto', r.reportable,
                                               'sin_clasificar', r.sin_clasificar, 'otro_camino', r.otro_camino,
                                               'falta', to_jsonb(r.falta), 'falta_texto', r.falta_texto,
                                               'por_que', case when r.reporta_efectivo = 'sin_ficha' then 'no tiene ficha'
                                                               when r.reporta_efectivo = 'sin_tercero' then 'el libro no dice de quién son esos pagos'
                                                               when 'decidir' = any (r.falta) then 'falta decidir si se le reporta'
                                                               when cardinality(r.falta) > 0 then 'le falta ' || r.falta_texto
                                                               when r.sin_clasificar > 0 then 'tiene pagos sin clasificar'
                                                               else 'tiene servicio pagado por otro camino, sin decidir si cuenta' end)
                            order by r.reportable desc, r.nombre), '[]'::jsonb), count(*)::int
    into v_pend, v_falta
    from jsonb_to_recordset(v_r) as r(clave text, ficha_id uuid, nombre text, reporta_efectivo text, falta text[], falta_texto text,
                                      reportable numeric, sin_clasificar numeric, otro_camino numeric, pasa_umbral boolean)
   where not exists (select 1 from jsonb_to_recordset(v_x) as x(ficha_id uuid) where x.ficha_id = r.ficha_id)
     and ((r.reportable > 0 and (r.pasa_umbral or v_bajo))
          or ((r.sin_clasificar > 0 or r.otro_camino > 0)
              and (r.reporta_efectivo = 'sin_tercero'
                   or (r.reporta_efectivo <> 'no' and r.reportable + greatest(r.sin_clasificar, 0) + greatest(r.otro_camino, 0) >= v_umbral)))
          or (r.reporta_efectivo = 'sin_tercero' and r.reportable > 0));
  -- lo que el control de ese año tiene en rojo y cambia la hoja
  select coalesce(jsonb_agg(jsonb_build_object('orden', k.orden, 'control', k.control, 'detalle', k.detalle) order by k.orden), '[]'::jsonb)
    into v_avisos
    from fn_subs_control(p_anio) k
   where k.ok is not true and k.orden in (30, 40, 45, 55, 60, 82);
  if extract(year from fn_subs_libro_desde())::int = p_anio and fn_subs_libro_desde() > make_date(p_anio, 1, 1) then
    v_parc := format('PARCIAL: el libro de la app empieza el %s. Lo pagado antes está en QuickBooks, y el 1099 de %s sale de allí: esta '
                     'hoja sirve para cruzar, no para presentar.', fn_subs_dia(fn_subs_libro_desde()), p_anio);
  end if;

  perform set_config('mx_subs.escribe', 'subs_exportaciones', true);
  insert into subs_exportaciones (anio, umbral, filas, total, pendientes, huella, detalle, opciones, generado_por)
  values (p_anio, v_umbral, v_n, v_total, v_falta, v_huella,
          jsonb_build_object('filas', v_det, 'pendientes', v_pend, 'avisos', v_avisos), v_op, auth.uid())
  returning id, generado_el into v_id, v_cuando;
  perform set_config('mx_subs.escribe', '', true);
  return jsonb_build_object(
    'anio', p_anio, 'umbral', v_umbral, 'generado_el', v_cuando, 'exportacion', v_id,
    'nombre_archivo', format('1099-NEC-%s.csv', p_anio),
    'columnas', to_jsonb(c_cols), 'filas', v_filas, 'csv', v_csv, 'cuantos', v_n, 'total', v_total,
    'pendientes', v_pend, 'avisos', v_avisos, 'completa', (v_falta = 0 and jsonb_array_length(v_avisos) = 0),
    'parcial', v_parc is not null, 'parcial_texto', v_parc);
end $$;
revoke execute on function public.fn_subs_1099_export(int, jsonb) from public, anon, service_role;
grant  execute on function public.fn_subs_1099_export(int, jsonb) to authenticated;
comment on function public.fn_subs_1099_export(int, jsonb) is 'c14: la hoja del 1099 de un año, con el TIN ENTERO (su única salida): una fila por ficha que se reporta, pasa del umbral (o todas con {"bajo_umbral": true}) y está completa, en las columnas genéricas de la 1099-NEC en inglés. Pide el código del teléfono (aal2; si no, 403 MFA). Devuelve {anio, umbral, nombre_archivo, columnas, filas, csv (cada celda entre comillas, CRLF), cuantos, total, pendientes (lo que pasa del umbral —o lo pasaría con lo sin clasificar o por otro camino— y no entra, y los pagos sin nombre, con su porqué), avisos (lo que el control de ese año tiene en rojo y cambia la hoja), completa (sin pendientes ni avisos), parcial}. Queda apuntada en subs_exportaciones, sin el TIN. No manda nada a ningún sitio. Con POST. Solo el dueño, y solo desde la app: desde el SQL Editor no se saca (42501).';


-- ---------------------------------------------------------------------
-- 10. LA CONFIGURACIÓN y el umbral de cada año.
-- ---------------------------------------------------------------------
-- {umbral_1099?, entidades_no_reporta?, cuentas_por_pagar?, cuentas_no_pago?,
--  cuentas_no_servicio?, coi_aviso_dias?, coi_ventana_dias?,
--  coi_exento_basta?, fecha_pago?: "contable" | "banco"}: lo que no viene no
-- cambia. Devuelve la configuración.
create or replace function public.fn_subs_config(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c        subs_config;
  n        subs_config;
  v_sobra  text;
  v_k      text;
  v_x      text;
  v_num    numeric;
  v_arr    text[];
  v_cambio jsonb;
begin
  perform fn_subs_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'La configuración llega como un objeto ({umbral_1099, …}).';
  end if;
  select count(*)::text into v_sobra
    from jsonb_object_keys(p) k
   where k not in ('umbral_1099', 'entidades_no_reporta', 'cuentas_por_pagar', 'cuentas_no_pago', 'coi_aviso_dias', 'coi_ventana_dias',
                   'coi_exento_basta', 'fecha_pago', 'cuentas_no_servicio');
  if v_sobra <> '0' then
    raise exception using errcode = '22023',
      message = format('La configuración trae %s clave(s) que no existen (no se repiten aquí). Las que hay: umbral_1099, '
                       'entidades_no_reporta, cuentas_por_pagar, cuentas_no_pago, cuentas_no_servicio, coi_aviso_dias, '
                       'coi_ventana_dias, coi_exento_basta y fecha_pago.', v_sobra);
  end if;
  select * into c from subs_config where id = 1 for update;
  n := c;
  if p ? 'umbral_1099' then
    begin
      v_num := btrim(p->>'umbral_1099')::numeric;
    exception when others then
      v_num := null;
    end;
    if v_num is null or scale(v_num) is null or v_num < 0 or v_num >= 1000000000 or scale(trim_scale(v_num)) > 2 then
      raise exception using errcode = 'MX005', message = 'El umbral es un monto en dólares, de cero para arriba y con hasta dos decimales.';
    end if;
    n.umbral_1099 := round(v_num, 2);
  end if;
  foreach v_k in array array['entidades_no_reporta', 'cuentas_por_pagar', 'cuentas_no_pago', 'cuentas_no_servicio'] loop
    if p ? v_k then
      if jsonb_typeof(p->v_k) <> 'array'
         or exists (select 1 from jsonb_array_elements(p->v_k) e where jsonb_typeof(e) <> 'string') then
        raise exception using errcode = '22023', message = format('%s es una lista de textos.', v_k);
      end if;
      select coalesce(array_agg(distinct btrim(e) order by btrim(e)), '{}') into v_arr from jsonb_array_elements_text(p->v_k) e;
      if v_k = 'entidades_no_reporta' then
        select string_agg(e, ', ') into v_x from unnest(v_arr) e
         where e <> all (array['individual', 'sole_proprietor', 'llc_un_socio', 'llc_sociedad', 'sociedad', 's_corp', 'c_corp', 'otro']);
        if v_x is not null then
          raise exception using errcode = '22023',
            message = 'En entidades_no_reporta hay un tipo de entidad que no existe (no se repite aquí). Los que hay: individual, '
                      'sole_proprietor, llc_un_socio, llc_sociedad, sociedad, s_corp, c_corp y otro.';
        end if;
        n.entidades_no_reporta := v_arr;
      else
        select string_agg(e, ', ') into v_x from unnest(v_arr) e where not exists (select 1 from cuentas k where k.codigo = e);
        if v_x is not null then
          raise exception using errcode = 'MX004',
            message = format('En %s hay una cuenta que no existe en el plan de cuentas (no se repite aquí): revisa sus códigos.', v_k);
        end if;
        if v_k = 'cuentas_por_pagar' then n.cuentas_por_pagar := v_arr;
        elsif v_k = 'cuentas_no_pago' then n.cuentas_no_pago := v_arr;
        else n.cuentas_no_servicio := v_arr; end if;
      end if;
    end if;
  end loop;
  foreach v_k in array array['coi_aviso_dias', 'coi_ventana_dias'] loop
    if p ? v_k then
      if coalesce(p->>v_k, '') !~ '^[0-9]{1,3}$'
         or (v_k = 'coi_aviso_dias' and (p->>v_k)::int > 365) or (v_k = 'coi_ventana_dias' and (p->>v_k)::int not between 1 and 730) then
        raise exception using errcode = 'MX005',
          message = format('%s son días enteros: %s.', v_k, case v_k when 'coi_aviso_dias' then 'de 0 a 365' else 'de 1 a 730' end);
      end if;
      if v_k = 'coi_aviso_dias' then n.coi_aviso_dias := (p->>v_k)::int; else n.coi_ventana_dias := (p->>v_k)::int; end if;
    end if;
  end loop;
  if p ? 'coi_exento_basta' then
    if jsonb_typeof(p->'coi_exento_basta') <> 'boolean' then
      raise exception using errcode = '22023', message = 'coi_exento_basta es true o false.';
    end if;
    n.coi_exento_basta := (p->>'coi_exento_basta')::boolean;
  end if;
  if p ? 'fecha_pago' then
    if jsonb_typeof(p->'fecha_pago') <> 'string' or lower(btrim(p->>'fecha_pago')) not in ('contable', 'banco') then
      raise exception using errcode = '22023',
        message = 'fecha_pago es «contable» (un pago cuenta con la fecha de su asiento) o «banco» (con la que dijo el banco).';
    end if;
    n.fecha_pago := lower(btrim(p->>'fecha_pago'));
  end if;
  select jsonb_object_agg(e.key, e.value) into v_cambio
    from jsonb_each(to_jsonb(n)) e
   where e.value is distinct from to_jsonb(c)->e.key and e.key not in ('actualizado', 'actualizado_por');
  if v_cambio is not null then
    perform set_config('mx_subs.escribe', 'subs_config', true);
    update subs_config
       set umbral_1099 = n.umbral_1099, entidades_no_reporta = n.entidades_no_reporta, cuentas_por_pagar = n.cuentas_por_pagar,
           cuentas_no_pago = n.cuentas_no_pago, coi_aviso_dias = n.coi_aviso_dias, coi_ventana_dias = n.coi_ventana_dias,
           coi_exento_basta = n.coi_exento_basta, fecha_pago = n.fecha_pago, cuentas_no_servicio = n.cuentas_no_servicio,
           actualizado = now(), actualizado_por = auth.uid()
     where id = 1;
    perform set_config('mx_subs.escribe', 'subs_historial', true);
    insert into subs_historial (que, antes, despues, hecho_por)
    values ('config', (select jsonb_object_agg(k, to_jsonb(c)->k) from jsonb_object_keys(v_cambio) k), v_cambio, auth.uid());
    perform set_config('mx_subs.escribe', '', true);
  end if;
  return (select to_jsonb(x) from subs_config x where x.id = 1);
end $$;
revoke execute on function public.fn_subs_config(jsonb) from public, anon, service_role;
grant  execute on function public.fn_subs_config(jsonb) to authenticated;
comment on function public.fn_subs_config(jsonb) is 'c14: cambia la configuración de los subs y del 1099 ({umbral_1099?, entidades_no_reporta?, cuentas_por_pagar?, cuentas_no_pago?, cuentas_no_servicio?, coi_aviso_dias?, coi_ventana_dias?, coi_exento_basta?, fecha_pago?: contable | banco}) y la devuelve. MX005 si un monto o unos días están mal, MX004 si una cuenta no existe en el plan. Lo que cambia queda en subs_historial. Solo el dueño.';

-- EL UMBRAL DE UN AÑO, confirmado (con el CPA): el año, el umbral y la nota
-- (quién lo dijo y cuándo). Otro umbral para el mismo año sustituye al
-- anterior, que queda en su historial.
create or replace function public.fn_subs_umbral_confirmar(p_anio int, p_umbral text, p_nota text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_num  numeric;
  v_nota text := nullif(btrim(regexp_replace(left(coalesce(p_nota, ''), 500), '[[:space:]]+', ' ', 'g')), '');
  u      subs_umbrales;
  v_min  int := extract(year from fn_subs_libro_desde())::int;
  v_max  int := extract(year from fn_subs_hoy())::int + 1;
begin
  perform fn_subs_exigir_dueno();
  if p_anio is null or p_anio not between v_min and v_max then
    raise exception using errcode = '22023', message = format('El año va de %s a %s.', v_min, v_max);
  end if;
  begin
    v_num := btrim(p_umbral)::numeric;
  exception when others then
    v_num := null;
  end;
  if v_num is null or scale(v_num) is null or v_num < 0 or v_num >= 1000000000 or scale(trim_scale(v_num)) > 2 then
    raise exception using errcode = 'MX005', message = 'El umbral es un monto en dólares, de cero para arriba y con hasta dos decimales.';
  end if;
  if v_nota is null then
    raise exception using errcode = '22023', message = 'Confirmar el umbral pide su nota: quién lo dijo y cuándo (el CPA, el 15 de diciembre…).';
  end if;
  select * into u from subs_umbrales where anio = p_anio for update;
  perform set_config('mx_subs.escribe', 'subs_umbrales', true);
  if u.anio is not null then
    update subs_umbrales
       set umbral = round(v_num, 2), nota = v_nota, confirmado_el = now(), confirmado_por = auth.uid(),
           historial = u.historial || jsonb_build_object('umbral', u.umbral, 'nota', u.nota, 'confirmado_el', u.confirmado_el,
                                                         'confirmado_por', u.confirmado_por)
     where anio = p_anio;
  else
    insert into subs_umbrales (anio, umbral, nota, confirmado_por) values (p_anio, round(v_num, 2), v_nota, auth.uid());
  end if;
  perform set_config('mx_subs.escribe', 'subs_historial', true);
  insert into subs_historial (que, antes, despues, hecho_por)
  values ('umbral', case when u.anio is not null then jsonb_build_object('anio', p_anio, 'umbral', u.umbral, 'nota', u.nota) end,
          jsonb_build_object('anio', p_anio, 'umbral', round(v_num, 2), 'nota', v_nota), auth.uid());
  perform set_config('mx_subs.escribe', '', true);
  return (select to_jsonb(x) from subs_umbrales x where x.anio = p_anio);
end $$;
revoke execute on function public.fn_subs_umbral_confirmar(int, text, text) from public, anon, service_role;
grant  execute on function public.fn_subs_umbral_confirmar(int, text, text) to authenticated;
comment on function public.fn_subs_umbral_confirmar(int, text, text) is 'c14: anota el umbral del 1099 de un año, confirmado, con su nota (quién lo dijo y cuándo). Otro umbral para el mismo año sustituye al anterior, que queda en su historial. MX005 si el monto está mal. Devuelve la fila. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 11. EL COI. fn_subs_coi(desde, hasta, al): cada ficha (o tercero sin
--     ficha) con servicio pagado o devengado entre dos días, y su COI a un
--     día. Sin fechas: el mes en curso o los últimos N días (lo que quede
--     más atrás), a hoy.
--       pagado, devengado     el servicio pagado (efectivo o tarjeta) y el
--                             que entró a una cuenta por pagar (el trabajo,
--                             se haya pagado después o no), en esos días
--       coi_estado            sin_coi | vencido | por_vencer | vigente, al
--                             día p_al; coi_dias = vence − ese día; coi_chip
--       cubria                cada día con servicio tenía un COI vigente
--       wc_exento, wc_estado  exento | exento_vencido | exento_sin_documento
--       cubierto              cubria, o exento con su documento si la
--                             configuración dice que basta
--       que_falta             en llano, si no está cubierto
-- ---------------------------------------------------------------------
-- Un mes como se dice: «octubre de 2026» (de un período AAAA-MM o de un día).
create or replace function public.fn_subs_mes(p_dia date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select (array['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre',
                'diciembre'])[extract(month from p_dia)::int] || ' de ' || extract(year from p_dia)::int
$$;
revoke execute on function public.fn_subs_mes(date) from public, anon, service_role;
grant  execute on function public.fn_subs_mes(date) to authenticated;
comment on function public.fn_subs_mes(date) is 'c14: el mes de un día como se dice: «octubre de 2026».';

drop function if exists public.fn_subs_coi(date, date, date);
create function public.fn_subs_coi(p_desde date default null, p_hasta date default null, p_al date default null)
returns table (clave text, ficha_id uuid, tercero_tipo text, tercero_id text, nombre text, pagado numeric, devengado numeric,
               primer_dia date, ultimo_dia date, coi_archivo_id uuid, coi_ruta text, coi_vence date, coi_dias int,
               coi_estado text, coi_chip text, cubria boolean, wc_exento boolean, wc_estado text, wc_vence date,
               cubierto boolean, que_falta text)
language sql stable
set search_path = public, pg_temp
as $$
  with g as (
    select c.coi_aviso_dias, c.coi_exento_basta,
           coalesce(p_al, public.fn_subs_hoy()) as al,
           coalesce(p_hasta, public.fn_subs_hoy()) as hasta,
           coalesce(p_desde, least(date_trunc('month', public.fn_subs_hoy())::date, public.fn_subs_hoy() - c.coi_ventana_dias)) as desde
      from public.subs_config c where c.id = 1),
  it as (
    select coalesce('ficha:' || c.ficha_id::text, c.tercero_tipo || ':' || c.tercero_id, 'sin_tercero') as clave,
           c.ficha_id, c.tercero_tipo, c.tercero_id, c.fecha,
           -- (lo que salda una cuenta por pagar por otro camino es un pago: lo pagó alguien de su bolsillo)
           case when c.medio = 'otro' and c.via = 'cxp' then 'efectivo' else c.medio end as medio, c.monto
      from public.fn_subs_calculo() c cross join g
     where c.clase = 'servicio' and c.fecha between g.desde and g.hasta),
  s as (
    select it.clave, min(it.ficha_id::text)::uuid as ficha_id,
           min(it.tercero_tipo) filter (where it.ficha_id is null) as tercero_tipo,
           min(it.tercero_id) filter (where it.ficha_id is null) as tercero_id,
           coalesce(sum(it.monto) filter (where it.medio in ('efectivo', 'tarjeta')), 0) as pagado,
           coalesce(sum(it.monto) filter (where it.medio in ('por_pagar', 'otro')), 0) as devengado,
           min(it.fecha) as primer_dia, max(it.fecha) as ultimo_dia,
           array_agg(distinct it.fecha) as dias
      from it
     group by it.clave),
  b as (
    select s.*, g.al, g.coi_aviso_dias, g.coi_exento_basta, f.id as f_id, f.wc_exento,
           coalesce(f.nombre_legal, f.nombre_comercial) as f_nombre,
           k.id as coi_id, k.ruta as coi_ruta, k.vence as coi_vence,
           x.id as wc_id, x.vence as wc_vence,
           (s.ficha_id is not null
            and not exists (select 1 from unnest(s.dias) d(dia)
                             where not exists (select 1 from public.subs_archivos a
                                                where a.ficha_id = s.ficha_id and a.clase = 'coi' and a.retirado_el is null
                                                  and a.vence >= d.dia and (a.fecha is null or a.fecha <= d.dia)))) as cubria
      from s
      cross join g
      left join public.subs_fichas f on f.id = s.ficha_id
      left join lateral (select a.* from public.subs_archivos a
                          where a.ficha_id = s.ficha_id and a.clase = 'coi' and a.retirado_el is null
                          order by a.vence desc, a.registrado_el desc limit 1) k on true
      left join lateral (select a.* from public.subs_archivos a
                          where a.ficha_id = s.ficha_id and a.clase = 'wc_exento' and a.retirado_el is null
                          order by a.registrado_el desc limit 1) x on true),
  c as (
    select b.*,
           case when not coalesce(b.wc_exento, false) then null
                when b.wc_id is null then 'exento_sin_documento'
                when b.wc_vence is not null and b.wc_vence < b.ultimo_dia then 'exento_vencido'
                else 'exento' end as wc_estado
      from b)
  select c.clave, c.ficha_id, c.tercero_tipo, c.tercero_id,
         case when c.ficha_id is not null then coalesce(c.f_nombre, '(sin nombre)')
              when c.tercero_id is not null then coalesce(public.fn_subs_tercero_nombre(c.tercero_tipo, c.tercero_id), '(ya no existe)')
              else 'Sin tercero: servicio que el libro no dice de quién es' end,
         c.pagado, c.devengado, c.primer_dia, c.ultimo_dia,
         c.coi_id, c.coi_ruta, c.coi_vence, (c.coi_vence - c.al)::int,
         case when c.coi_id is null then 'sin_coi'
              when c.coi_vence < c.al then 'vencido'
              when c.coi_vence - c.al <= c.coi_aviso_dias then 'por_vencer'
              else 'vigente' end,
         case when c.coi_id is null then 'sin COI'
              when c.coi_vence < c.al then 'Vencido el ' || public.fn_subs_dia(c.coi_vence)
              when c.coi_vence - c.al <= c.coi_aviso_dias then format('vence en %s días', c.coi_vence - c.al)
              else 'vence el ' || public.fn_subs_dia(c.coi_vence) end,
         c.cubria, coalesce(c.wc_exento, false), c.wc_estado, c.wc_vence,
         -- (wc_estado es nulo en quien no es exento: «is not distinct from», para que «cubierto» sea siempre sí o no y
         --  nunca nulo —con «al exento le basta» puesto, un nulo aquí callaría a quien no tiene COI en el control y en el cierre)
         (c.cubria or (c.coi_exento_basta and c.wc_estado is not distinct from 'exento')),
         case when c.cubria or (c.coi_exento_basta and c.wc_estado is not distinct from 'exento') then null
              when c.ficha_id is null and c.tercero_id is null then 'no se sabe de quién es: atribúyelo a su ficha'
              when c.ficha_id is null then 'sin ficha (y sin COI)'
              when c.coi_id is null then 'sin COI' || case when c.wc_estado = 'exento' then ' (exento de WC con su documento)' else '' end
              when c.coi_vence < c.ultimo_dia
                then format('su COI venció el %s y su último trabajo o pago fue el %s', public.fn_subs_dia(c.coi_vence),
                            public.fn_subs_dia(c.ultimo_dia))
              else 'su COI no cubría todos los días con trabajo o pago (mira desde cuándo vale)' end
    from c
   where public.fn_subs_ve()
   order by 5
$$;
revoke execute on function public.fn_subs_coi(date, date, date) from public, anon, service_role;
grant  execute on function public.fn_subs_coi(date, date, date) to authenticated;
comment on function public.fn_subs_coi(date, date, date) is 'c14: cada ficha (o tercero sin ficha) con servicio pagado o devengado entre dos días, y su COI a un día (sin fechas: el mes en curso o los últimos subs_config.coi_ventana_dias días, a hoy): pagado, devengado, primer_dia y ultimo_dia con servicio; su COI vigente (coi_vence, coi_dias = vence − el día, coi_estado: sin_coi | vencido | por_vencer | vigente, coi_chip); cubria (cada día con servicio tenía un COI vigente); wc_exento y wc_estado; cubierto (cubria, o exento con su documento si subs_config.coi_exento_basta); y que_falta en llano. Solo lectura; a quien no es el dueño, nada.';


-- ---------------------------------------------------------------------
-- 12. EL CONTROL (cabecera, punto 7) y las dos filas del cierre.
-- ---------------------------------------------------------------------
drop function if exists public.fn_subs_control(int);
create function public.fn_subs_control(p_anio int default null)
returns table (orden int, control text, nivel text, ok boolean, detalle text)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_anio   int;
  v_hoy    date := fn_subs_hoy();
  v_it     jsonb;
  v_il     jsonb;
  v_r      jsonb;
  v_n      bigint;
  v_a      numeric;
  v_b      numeric;
  v_t      text;
  v_t2     text;
  v_malo   text[] := '{}';
  v_x      text;
  v_storage boolean := to_regclass('storage.objects') is not null;
  v_umbral numeric;
  v_serv   text[];
  v_pp     text[];
  v_pago   text[];
  e        record;
  c_tablas constant text[] := array['subs_config', 'subs_umbrales', 'subs_fichas', 'subs_terceros', 'subs_tin', 'subs_archivos',
                                    'subs_marcas', 'subs_historial', 'subs_exportaciones', 'subs_tramos'];
  c_vistas constant text[] := array['v_subs_fichas', 'v_subs_archivos', 'v_subs_1099', 'v_subs_pagos', 'v_subs_coi', 'v_subs_control'];
  c_fn     constant text[] := array['fn_subs_precondiciones', 'fn_subs_por_api', 'fn_subs_exigir_dueno', 'fn_subs_ve',
                                    'fn_subs_exigir_codigo', 'fn_subs_guarda', 'fn_subs_tin_forma', 'fn_subs_usd', 'fn_subs_lista', 'fn_subs_hoy',
                                    'fn_subs_dia', 'fn_subs_libro_desde', 'fn_subs_anios', 'fn_subs_umbral', 'fn_subs_mascara',
                                    'fn_subs_tercero_nombre', 'fn_subs_cuenta_clase', 'fn_subs_storage', 'fn_subs_mes', 'fn_subs_fichas',
                                    'fn_subs_ficha', 'fn_subs_tramo_retirar', 'fn_subs_tercero', 'fn_subs_tin_guardar', 'fn_subs_archivo',
                                    'fn_subs_archivo_retirar', 'fn_subs_marcar', 'fn_subs_calculo', 'fn_subs_pagos', 'fn_subs_antes',
                                    'fn_subs_estado_al', 'fn_subs_1099', 'fn_subs_1099_export', 'fn_subs_config',
                                    'fn_subs_umbral_confirmar', 'fn_subs_coi', 'fn_subs_control', 'fn_subs_cierre', 'fn_subs_pegado'];
  c_bucket_aal    constant text[] := array['subs: el dueno sube', 'subs: el dueno lee', 'subs: solo el dueno con su codigo lee',
                                           'subs: solo el dueno con su codigo sube'];
  c_bucket_cierra constant text[] := array['subs: solo el dueno con su codigo lee', 'subs: solo el dueno con su codigo sube',
                                           'subs: la llave publica no entra', 'subs: no se borra', 'subs: no se pisa'];
begin
  if not fn_subs_ve() then
    return;
  end if;
  v_anio := coalesce(p_anio, extract(year from v_hoy)::int);
  v_umbral := fn_subs_umbral(v_anio);
  -- (las cuentas de cada clase, una vez: preguntarlo línea por línea del libro costaría una consulta por línea)
  select coalesce(array_agg(k.codigo) filter (where k.c = 'servicio'), '{}'), coalesce(array_agg(k.codigo) filter (where k.c = 'por_pagar'), '{}'),
         coalesce(array_agg(k.codigo) filter (where k.c in ('por_pagar', 'efectivo', 'tarjeta')), '{}')
    into v_serv, v_pp, v_pago
    from (select c.codigo, fn_subs_cuenta_clase(c.codigo) as c from cuentas c) k;
  -- (las partes del año con que CUENTAN —el de su fecha— y las del año del LIBRO —el de su asiento—: son las mismas
  -- salvo que la configuración diga que un pago cuenta con la fecha del banco)
  select coalesce(jsonb_agg(to_jsonb(c)) filter (where c.anio = v_anio), '[]'::jsonb),
         coalesce(jsonb_agg(to_jsonb(c)) filter (where c.anio_libro = v_anio), '[]'::jsonb)
    into v_it, v_il
    from fn_subs_calculo() c where c.anio = v_anio or c.anio_libro = v_anio;
  select coalesce(jsonb_agg(to_jsonb(r) - 'pagos'), '[]'::jsonb) into v_r from fn_subs_1099(v_anio) r;

  -- 10. Cada línea de servicio del año, repartida entera: lo que el libro tiene en las cuentas de servicio = la suma de sus
  --     partes (pagado en efectivo, con tarjeta, por pagar y por otro camino).
  orden := 10; control := 'subs: cada línea de servicio del año, repartida entera'; nivel := 'cuadre';
  select coalesce(sum(l.monto), 0) into v_a
    from asiento_lineas l join asientos a on a.id = l.asiento_id
   where a.anio = v_anio and l.cuenta = any (v_serv);
  select coalesce(sum(x.monto), 0), count(*) into v_b, v_n
    from jsonb_to_recordset(v_il) as x(cuenta text, via text, monto numeric)
   where x.via in ('directo', 'jornal') and x.cuenta = any (v_serv);
  ok := v_a = v_b;
  detalle := case when ok then format('Las cuentas de servicio de %s suman %s en el libro, y sus %s partes (en efectivo, con tarjeta, por '
                                      'pagar y por otro camino) suman lo mismo.', v_anio, fn_subs_usd(v_a), v_n)
                  else format('Las cuentas de servicio de %s suman %s en el libro y sus partes %s: hay %s sin repartir. Avisa: el '
                              'cálculo del 1099 no cuadra.', v_anio, fn_subs_usd(v_a), fn_subs_usd(v_b), fn_subs_usd(v_a - v_b)) end;
  return next;

  -- 12. Cada pago a una cuenta por pagar, repartido entero: en los asientos que solo pagan (la cuenta por pagar contra el
  --     banco o la tarjeta), lo pagado = la suma de sus partes (servicio, no servicio y sin clasificar). (Un traspaso de
  --     una cuenta por pagar a otra —la retención— no paga nada: suma cero y no deja partes.)
  orden := 12; control := 'subs: cada pago a una cuenta por pagar, repartido entero'; nivel := 'cuadre';
  with solo as (
    select a.id
      from asientos a join asiento_lineas l on l.asiento_id = a.id
     where a.anio = v_anio
     group by a.id
    having bool_or(l.cuenta = any (v_pp)) and bool_and(l.cuenta = any (v_pago)))
  select coalesce((select sum(l.monto) from asiento_lineas l join solo s on s.id = l.asiento_id
                    where l.cuenta = any (v_pp)), 0),
         coalesce((select sum(x.monto) from jsonb_to_recordset(v_il) as x(asiento_id uuid, via text, monto numeric)
                    join solo s on s.id = x.asiento_id where x.via = 'cxp'), 0),
         (select count(*) from solo)
    into v_a, v_b, v_n;
  ok := v_a = v_b;
  detalle := case when ok then format('Los %s asientos de %s que solo pagan una cuenta por pagar suman %s, y sus partes lo mismo.',
                                      v_n, v_anio, fn_subs_usd(v_a))
                  else format('Los asientos de %s que solo pagan una cuenta por pagar suman %s y sus partes %s: hay %s sin repartir. '
                              'Avisa: el cálculo del 1099 no cuadra.', v_anio, fn_subs_usd(v_a), fn_subs_usd(v_b), fn_subs_usd(v_a - v_b)) end;
  return next;

  -- 20. Las fichas, coherentes: cada tercero enlazado existe; y (desde el SQL Editor o la ronda, que ya leen todo) cada TIN
  --     anotado en una ficha tiene su fila, con sus 4 últimos y con buena forma, y al revés.
  orden := 20; control := 'subs: las fichas, coherentes'; nivel := 'cuadre';
  select coalesce(array_agg(format('la ficha de %s tiene enlazado un %s que ya no existe', x.nombre, t->>'tipo')), '{}') into v_malo
    from fn_subs_fichas(null) x, jsonb_array_elements(x.terceros) t
   where not (t->>'existe')::boolean;
  if not fn_subs_por_api() then
    select v_malo || coalesce(array_agg(z.que), '{}') into v_malo
      from (select format('la ficha de %s dice que tiene TIN y no lo tiene guardado', coalesce(f.nombre_legal, f.nombre_comercial, '(sin nombre)')) as que
              from subs_fichas f where f.tin_ultimos4 is not null and not exists (select 1 from subs_tin t where t.ficha_id = f.id)
            union all
            select format('hay un TIN guardado para la ficha de %s y su ficha no lo dice (o dice otros 4 últimos)',
                          coalesce(f.nombre_legal, f.nombre_comercial, '(sin nombre)'))
              from subs_tin t join subs_fichas f on f.id = t.ficha_id where f.tin_ultimos4 is distinct from right(t.tin, 4)
            union all
            select format('el TIN de la ficha de %s tiene mala forma (%s)', coalesce(f.nombre_legal, f.nombre_comercial, '(sin nombre)'),
                          fn_subs_tin_forma(t.tin))
              from subs_tin t join subs_fichas f on f.id = t.ficha_id where fn_subs_tin_forma(t.tin) is not null
            union all
            select format('el mismo TIN está en dos fichas (%s)', string_agg(coalesce(f.nombre_legal, f.nombre_comercial, '(sin nombre)'), ' y '))
              from subs_tin t join subs_fichas f on f.id = t.ficha_id group by t.tin having count(*) > 1) z;
  end if;
  ok := cardinality(v_malo) = 0;
  detalle := case when ok then format('%s ficha(s): cada tercero enlazado existe%s.', (select count(*) from subs_fichas),
                                      case when fn_subs_por_api() then ' (el TIN guardado contra su ficha se compara desde el SQL Editor)'
                                           else ', y cada TIN anotado tiene su fila, con sus 4 últimos y buena forma' end)
                  else fn_subs_lista(v_malo, 1200) || '.' end;
  return next;

  -- 30. Servicio pagado (o devengado, o un pago sin clasificar a su cuenta por pagar) a un tercero del libro que no
  --     tiene ficha.
  orden := 30; control := 'subs: servicio pagado a alguien sin ficha'; nivel := 'aviso';
  select count(*),
         fn_subs_lista(array_agg(format('%s (%s)', r.nombre,
                                        concat_ws(', ',
                                          case when r.pagado_servicio + r.pagado_tarjeta <> 0
                                               then 'servicio pagado ' || fn_subs_usd(r.pagado_servicio + r.pagado_tarjeta) end,
                                          case when r.sin_clasificar <> 0 then 'sin clasificar ' || fn_subs_usd(r.sin_clasificar) end,
                                          case when r.otro_camino <> 0 then 'por otro camino ' || fn_subs_usd(r.otro_camino) end,
                                          case when r.devengado <> 0 then 'servicio devengado ' || fn_subs_usd(r.devengado) end))
                                 order by r.pagado_servicio + r.pagado_tarjeta + r.sin_clasificar + r.otro_camino + r.devengado desc, r.nombre), 900)
    into v_n, v_t
    from jsonb_to_recordset(v_r) as r(nombre text, reporta_efectivo text, pagado_servicio numeric, pagado_tarjeta numeric,
                                      sin_clasificar numeric, otro_camino numeric, devengado numeric)
   where r.reporta_efectivo = 'sin_ficha';
  ok := v_n = 0;
  detalle := case when ok then format('En %s, todo el servicio pagado a un tercero del libro es de alguien con ficha.', v_anio)
                  else format('En %s hay %s tercero(s) sin ficha con servicio pagado o devengado, o con pagos sin clasificar: %s. Si es un '
                              'sub o un ayudante, dale su ficha (con su W-9 y su TIN); si es un proveedor de solo material, di en cada '
                              'pago que no es servicio.', v_anio, v_n, v_t) end;
  return next;

  -- 40. Pagos que el libro no dice de quién son (la línea no trae tercero): de servicio, o a una cuenta por pagar sin
  --     saber de qué (la retención de un sub devuelta desde la Bandeja, que no pide proveedor). No se puede saber a quién
  --     reportar.
  orden := 40; control := 'subs: servicio pagado sin tercero'; nivel := 'aviso';
  select count(*), coalesce(sum(x.monto), 0),
         fn_subs_lista(array_agg(format('%s del %s por %s%s%s', x.numero, fn_subs_dia(x.fecha), fn_subs_usd(x.monto),
                                case when x.clase = 'sin_clasificar' then format(' a la %s, sin clasificar', x.cuenta) else '' end,
                                coalesce(' («' || left(coalesce(x.banco, x.descripcion), 60) || '»)', ''))
                         order by x.fecha, x.numero, x.orden), 900)
    into v_n, v_a, v_t
    from jsonb_to_recordset(v_it) as x(numero text, fecha date, orden int, cuenta text, medio text, clase text, monto numeric, ficha_id uuid,
                                       tercero_id text, banco text, descripcion text)
   where x.medio in ('efectivo', 'tarjeta') and x.clase in ('servicio', 'sin_clasificar') and x.ficha_id is null and x.tercero_id is null;
  ok := v_n = 0;
  detalle := case when ok then format('En %s, cada pago de servicio (y cada pago a una cuenta por pagar) dice de quién es.', v_anio)
                  else format('En %s hay %s pago(s) por %s, de servicio o a una cuenta por pagar, que el libro no dice de quién son: %s. '
                              'Di de quién es cada uno (se atribuye a su ficha, sin tocar el libro): hasta entonces no están en el 1099 '
                              'de nadie.', v_anio, v_n, fn_subs_usd(v_a), v_t) end;
  return next;

  -- 45. Servicio que no se pagó desde el banco, la tarjeta ni una cuenta por pagar (lo pagó alguien de su bolsillo, un
  --     asiento a mano contra otra cuenta…): no entra en el 1099 solo; se mira a mano. (Un devengo de cierre que se deshace
  --     solo el día 1 —y su reverso automático— no cuenta: no es un pago, y vuelve a cero.)
  orden := 45; control := 'subs: servicio pagado por otro camino'; nivel := 'aviso';
  select count(*), coalesce(sum(z.m), 0),
         fn_subs_lista(array_agg(format('%s por %s%s', z.numero, fn_subs_usd(z.m), coalesce(' (' || z.quien || ')', '')) order by z.numero), 900)
    into v_n, v_a, v_t
    from (select x.numero, sum(x.monto) as m,
                 max(coalesce((select coalesce(f.nombre_legal, f.nombre_comercial) from subs_fichas f where f.id = x.ficha_id),
                              fn_subs_tercero_nombre(x.tercero_tipo, x.tercero_id))) as quien
            from jsonb_to_recordset(v_it) as x(asiento_id uuid, numero text, medio text, clase text, monto numeric, ficha_id uuid,
                                               tercero_tipo text, tercero_id text)
            join asientos a on a.id = x.asiento_id
           where x.medio = 'otro' and x.clase in ('servicio', 'sin_clasificar') and not a.reversible and a.camino <> 'reverso_automatico'
           group by x.numero
          having sum(x.monto) <> 0) z;
  ok := v_n = 0;
  detalle := case when ok then format('En %s, todo el servicio se pagó desde el banco, con tarjeta, o está en una cuenta por pagar.', v_anio)
                  else format('En %s hay servicio por %s en %s asiento(s) que no salió del banco ni de una tarjeta (lo pagó alguien de su '
                              'bolsillo, o su deuda se saldó contra otra cuenta): %s. El 1099 no lo cuenta solo. Si lo pagó la empresa '
                              'por otro camino (Edgar de su bolsillo, y la empresa se lo devolvió), márcalo «pagado» en Subs → Pagos y '
                              'cuenta ese día; si no, di que no es servicio. Pregúntale al CPA.',
                              v_anio, fn_subs_usd(v_a), v_n, v_t) end;
  return next;

  -- 50. Una ficha que se reporta, incompleta: sin W-9, sin TIN, sin dirección, sin tipo de entidad o sin nombre legal.
  orden := 50; control := 'subs: fichas que se reportan, incompletas'; nivel := 'aviso';
  select count(*), fn_subs_lista(array_agg(format('%s (le falta %s%s)', f.nombre, f.falta_texto,
                                          case when r.pasa_umbral then format('; ya pasa del umbral: %s', fn_subs_usd(r.reportable)) else '' end)
                                   order by coalesce(r.reportable, 0) desc, f.nombre), 1000)
    into v_n, v_t
    from fn_subs_fichas(null) f
    left join jsonb_to_recordset(v_r) as r(ficha_id uuid, reportable numeric, pasa_umbral boolean) on r.ficha_id = f.ficha_id
   where f.activa and f.reporta = 'si' and cardinality(f.falta) > 0;
  ok := v_n = 0;
  detalle := case when ok then 'Cada ficha marcada «se le reporta» tiene su nombre legal, su tipo de entidad, su dirección, su TIN y su W-9.'
                  else format('%s ficha(s) que se reportan están incompletas: %s.', v_n, v_t) end;
  return next;

  -- 55. Fichas por decidir (con el CPA) que ya tienen pagos de servicio en el año.
  orden := 55; control := 'subs: fichas por decidir con pagos'; nivel := 'aviso';
  select count(*), fn_subs_lista(array_agg(format('%s (%s%s)', r.nombre, fn_subs_usd(r.pagado_servicio),
                                          case when r.pasa_umbral then ', pasa del umbral' else '' end)
                                   order by r.pagado_servicio desc, r.nombre), 900)
    into v_n, v_t
    from jsonb_to_recordset(v_r) as r(nombre text, reporta_efectivo text, pagado_servicio numeric, pasa_umbral boolean)
   where r.reporta_efectivo = 'por_decidir' and r.pagado_servicio <> 0;
  ok := v_n = 0;
  detalle := case when ok then format('En %s nadie con pagos de servicio está «por decidir».', v_anio)
                  else format('%s ficha(s) con pagos en %s siguen «por decidir»: %s. Decide con el CPA si se les reporta: hasta entonces '
                              'no entran en la hoja del 1099.', v_n, v_anio, v_t) end;
  return next;

  -- 60. Pagos en efectivo que no se sabe si son servicio: a una cuenta por pagar sin papel (lo de la apertura, lo pagado
  --     de más, lo que no se pudo seguir) o a alguien con ficha por una cuenta de gasto sin la etiqueta del 1099. De
  --     quien sea: con ficha, sin ficha o sin nombre. (A quien su ficha dice que no se le reporta no se le pregunta...
  --     SALVO por lo que se le pagó en los días en que SÍ se le reportaba: si su ficha cambió a «no» desde un día —entró
  --     a la nómina, se hizo corporación— lo pagado antes sigue contando para su 1099 si es servicio, así que se pregunta,
  --     y solo por ese monto. Antes se miraba nada más cómo está la ficha al final del año, y a quien pasó a «no» a
  --     mitad de año el control le decía «no hay pagos sin clasificar» con dinero de cuando se le reportaba por decidir.)
  orden := 60; control := 'subs: pagos sin clasificar'; nivel := 'aviso';
  select count(*), fn_subs_lista(array_agg(format('%s (%s)', z.nombre, fn_subs_usd(z.monto)) order by z.monto desc, z.nombre), 900)
    into v_n, v_t
    from (select r.nombre,
                 case when r.reporta_efectivo <> 'no' then r.sin_clasificar
                      -- (su ficha dice «no» y nunca dijo otra cosa en el año: nada que preguntar)
                      when r.reporta_efectivo is null or r.ficha_id is null or r.cambios is null then 0
                      -- (dice «no», pero cambió: lo sin clasificar de los días en que no decía «no»)
                      else (select coalesce(sum(x.monto), 0)
                              from jsonb_to_recordset(v_it) as x(ficha_id uuid, fecha date, medio text, clase text, monto numeric)
                             where x.ficha_id = r.ficha_id and x.medio = 'efectivo' and x.clase = 'sin_clasificar'
                               and exists (select 1 from fn_subs_estado_al(x.ficha_id, x.fecha) e where e.reporta_efectivo <> 'no')) end as monto
            from jsonb_to_recordset(v_r) as r(ficha_id uuid, nombre text, reporta_efectivo text, sin_clasificar numeric, cambios text)) z
   where z.monto <> 0;
  ok := v_n = 0;
  detalle := case when ok then format('En %s no hay pagos sin clasificar.', v_anio)
                  else format('En %s hay pagos que no se sabe si son servicio (a lo que traía QuickBooks en la apertura, de más, o por '
                              'una cuenta de gasto sin la etiqueta del 1099) de %s: %s. Di de cada pago si fue servicio o no: hasta '
                              'entonces no cuenta.', v_anio, v_n, v_t) end;
  return next;

  -- 70. Alguien con servicio este mes (pagado o devengado) sin su COI vigente ese día.
  orden := 70; control := 'subs: COI de quien tuvo servicio este mes'; nivel := 'aviso';
  select count(*), count(*) filter (where k.cubierto is not true),
         fn_subs_lista(array_agg(format('%s (%s)', k.nombre, k.que_falta) order by k.nombre) filter (where k.cubierto is not true), 900)
    into v_n, v_a, v_t
    from fn_subs_coi(date_trunc('month', v_hoy)::date, v_hoy, v_hoy) k;
  ok := v_a = 0;
  detalle := case when v_n = 0 then format('En %s nadie tiene servicio pagado ni devengado todavía.', fn_subs_mes(v_hoy))
                  when ok then format('Los %s con servicio en %s tenían su COI vigente ese día.', v_n, fn_subs_mes(v_hoy))
                  else format('%s de los %s con servicio en %s no tenían su COI vigente: %s. Pídeselo y súbelo a su ficha.',
                              v_a, v_n, fn_subs_mes(v_hoy), v_t) end;
  return next;

  -- 75. Un COI que vence pronto, de alguien con servicio reciente.
  orden := 75; control := 'subs: COI que vence pronto'; nivel := 'aviso';
  select count(*), fn_subs_lista(array_agg(format('%s (%s, el %s)', k.nombre, k.coi_chip, fn_subs_dia(k.coi_vence)) order by k.coi_vence, k.nombre), 900)
    into v_n, v_t
    from fn_subs_coi(null, null, null) k
   where k.coi_estado = 'por_vencer';
  ok := v_n = 0;
  detalle := case when ok then 'Ningún COI de alguien con servicio reciente vence pronto.'
                  else format('%s COI de alguien con servicio reciente vence(n) pronto: %s. Pide el nuevo antes de que venza.', v_n, v_t) end;
  return next;

  -- 80. Un reverso de este año que resta un pago de servicio de un año anterior: el 1099 de aquel año quizá ya se presentó.
  orden := 80; control := 'subs: reversos de pagos de un año anterior'; nivel := 'aviso';
  select count(*), coalesce(sum(x.monto), 0),
         fn_subs_lista(array_agg(format('%s del %s por %s (el pago era de %s)', x.numero, fn_subs_dia(x.fecha), fn_subs_usd(x.monto),
                                x.anio_original) order by x.fecha, x.numero), 900)
    into v_n, v_a, v_t
    from jsonb_to_recordset(v_it) as x(numero text, fecha date, medio text, clase text, monto numeric, reverso boolean, anio_original int)
   where x.reverso and x.anio_original < v_anio and x.medio in ('efectivo', 'tarjeta') and x.clase in ('servicio', 'sin_clasificar');
  ok := v_n = 0;
  detalle := case when ok then format('En %s ningún reverso resta un pago de un año anterior.', v_anio)
                  else format('En %s hay %s reverso(s) por %s que restan pagos de un año anterior: %s. Restan en %s (su fecha); si el 1099 '
                              'de aquel año ya se presentó, pregunta al CPA si hay que corregirlo.', v_anio, v_n, fn_subs_usd(v_a), v_t, v_anio) end;
  return next;

  -- 82. Pagos que el banco fecha en un año y el libro en otro (un pago del 30 de diciembre que entró con diciembre ya
  --     cerrado se asienta en enero): cuentan en el año que diga la configuración (subs_config.fecha_pago: el asiento, de
  --     fábrica; o el banco). ▶ CPA.
  orden := 82; control := 'subs: pagos que el banco fecha en otro año'; nivel := 'aviso';
  select count(*), coalesce(sum(x.monto), 0),
         fn_subs_lista(array_agg(format('%s por %s (el banco dice %s y el libro %s)', x.numero, fn_subs_usd(x.monto),
                                        fn_subs_dia(x.fecha_banco), fn_subs_dia(x.fecha_libro)) order by x.fecha_libro, x.numero), 900)
    into v_n, v_a, v_t
    from (select y.numero, min(y.fecha_banco) as fecha_banco, min(y.fecha_libro) as fecha_libro, sum(y.monto) as monto
            from (select * from jsonb_to_recordset(v_it) as a(numero text, orden int, medio text, clase text, monto numeric, fecha_banco date,
                                                              fecha_libro date, anio_libro int)
                  union
                  select * from jsonb_to_recordset(v_il) as b(numero text, orden int, medio text, clase text, monto numeric, fecha_banco date,
                                                              fecha_libro date, anio_libro int)) y
           where y.medio = 'efectivo' and y.clase in ('servicio', 'sin_clasificar') and y.fecha_banco is not null
             and extract(year from y.fecha_banco)::int <> y.anio_libro
           group by y.numero) x;
  ok := v_n = 0;
  detalle := case when ok then format('En %s ningún pago tiene una fecha en el banco y otro año en el libro.', v_anio)
                  else format('%s pago(s) por %s tienen un año en el banco y otro en el libro: %s. Hoy cuentan con la fecha %s. Pregúntale '
                              'al CPA con cuál van, y si hace falta se cambia en la configuración de los subs.', v_n, fn_subs_usd(v_a), v_t,
                              (select case when c.fecha_pago = 'banco' then 'del banco' else 'del libro (la del asiento)' end
                                 from subs_config c where c.id = 1)) end;
  return next;

  -- 85. Lo exportado de un año ya no es lo que el libro dice: la última hoja de cada año contra el 1099 de hoy.
  orden := 85; control := 'subs: la hoja exportada sigue al día'; nivel := 'aviso';
  v_malo := '{}'; v_n := 0;
  for e in select distinct on (x.anio) x.anio, x.huella, x.total, x.filas, x.generado_el, coalesce((x.opciones->>'bajo_umbral')::boolean, false) as bajo
             from subs_exportaciones x order by x.anio, x.generado_el desc loop
    v_n := v_n + 1;
    select md5(coalesce(string_agg(r.ficha_id::text || ':' || r.reportable::text, '|' order by r.ficha_id), '')),
           coalesce(sum(r.reportable), 0), count(*)
      into v_x, v_a, v_b
      from fn_subs_1099(e.anio) r
     where r.ficha_id is not null and cardinality(r.falta) = 0 and r.reportable > 0 and (r.pasa_umbral or e.bajo);
    if v_x is distinct from e.huella then
      v_malo := v_malo || format('%s (exportado el %s: %s fila(s) por %s; hoy: %s por %s)', e.anio,
                                 fn_subs_dia((e.generado_el at time zone 'America/New_York')::date), e.filas, fn_subs_usd(e.total),
                                 v_b, fn_subs_usd(v_a));
    end if;
  end loop;
  ok := cardinality(v_malo) = 0;
  detalle := case when v_n = 0 then 'Todavía no se ha exportado ninguna hoja del 1099.'
                  when ok then format('La última hoja exportada de cada año (%s) sigue siendo lo que el libro dice.', v_n)
                  else format('Lo exportado ya no es lo que el libro dice en: %s. Si esa hoja ya se presentó, pregunta al CPA si hay que '
                              'corregirla; si no, vuelve a exportarla.', fn_subs_lista(v_malo, 900)) end;
  return next;

  -- 88. El umbral del año, confirmado (con el CPA).
  orden := 88; control := 'subs: el umbral del año, confirmado'; nivel := 'aviso';
  select format('%s («%s», anotado el %s)', fn_subs_usd(u.umbral), left(u.nota, 120), fn_subs_dia((u.confirmado_el at time zone 'America/New_York')::date))
    into v_t from subs_umbrales u where u.anio = v_anio;
  ok := v_t is not null;
  detalle := case when ok then format('El umbral de %s está confirmado: %s.', v_anio, v_t)
                  else format('El umbral de %s (%s) es el de fábrica y nadie lo ha confirmado. Pregúntale al CPA cuánto es para %s y si '
                              'se reporta a quien llega justo, y anótalo con su nota.', v_anio, fn_subs_usd(v_umbral), v_anio) end;
  return next;

  -- 90. Las protecciones de la capa (por nombre exacto), y los candados del bucket si esta base tiene Storage.
  orden := 90; control := 'subs: las protecciones de la capa'; nivel := 'cuadre';
  select coalesce(array_agg(z.que order by z.que), '{}') into v_malo
    from (select format('la tabla %s no existe', t) as que from unnest(c_tablas) t where to_regclass('public.' || t) is null
          union all
          select format('la tabla %s no tiene la seguridad por fila puesta', c.relname)
            from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = any (c_tablas) and not c.relrowsecurity
          union all
          select format('%s puede %s en %s', r.rol, pr.p, c.relname)
            from pg_class c
            cross join unnest(array['anon', 'service_role']) r(rol)
            cross join unnest(array['select', 'insert', 'update', 'delete', 'truncate']) pr(p)
           where c.relnamespace = 'public'::regnamespace and (c.relname = any (c_tablas) or c.relname = any (c_vistas))
             and has_table_privilege(r.rol, c.oid, pr.p)
          union all
          select format('a la tabla %s le falta su guarda (o está apagada)', t)
            from unnest(c_tablas) t
           where to_regclass('public.' || t) is not null
             and (select count(*) from pg_trigger g
                   where g.tgrelid = to_regclass('public.' || t) and g.tgname in ('trg_' || t || '_guarda', 'trg_' || t || '_sin_truncate')
                     and g.tgenabled <> 'D') < 2
          union all
          select format('la policy %s de %s no pide al dueño', pl.polname, c.relname)
            from pg_policy pl join pg_class c on c.oid = pl.polrelid
           where c.relnamespace = 'public'::regnamespace and c.relname = any (c_tablas)
             and coalesce(pg_get_expr(pl.polqual, pl.polrelid), '') || coalesce(pg_get_expr(pl.polwithcheck, pl.polrelid), '') not like '%es_dueno%'
          union all
          select format('la policy %s del TIN no pide el código del teléfono y la marca', pl.polname)
            from pg_policy pl
           where pl.polrelid = to_regclass('public.subs_tin')
             and (coalesce(pg_get_expr(pl.polqual, pl.polrelid), '') not like '%aal2%'
                  or coalesce(pg_get_expr(pl.polqual, pl.polrelid), '') not like '%mx_subs.tin%'
                  or coalesce(pg_get_expr(pl.polwithcheck, pl.polrelid), '') not like '%aal2%'
                  or coalesce(pg_get_expr(pl.polwithcheck, pl.polrelid), '') not like '%mx_subs.tin%')
          union all
          select 'al TIN le falta su candado restrictivo'
           where not exists (select 1 from pg_policy pl where pl.polrelid = to_regclass('public.subs_tin') and not pl.polpermissive)
          union all
          select 'el planificador puede guardar valores del TIN en sus estadísticas (la columna no tiene su objetivo en 0)'
            from pg_attribute a
           where a.attrelid = to_regclass('public.subs_tin') and a.attname = 'tin' and a.attstattarget is distinct from 0
          union all
          select format('el TIN va en la publicación %s (saldría por Realtime)', pb.pubname)
            from pg_publication pb
           where pb.puballtables
              or exists (select 1 from pg_publication_rel pr where pr.prpubid = pb.oid and pr.prrelid = to_regclass('public.subs_tin'))
          union all
          select format('%s lee la tabla del TIN', dc.oid::regclass)
            from pg_depend d
            join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
            join pg_class dc on dc.oid = rw.ev_class
           where d.refclassid = 'pg_class'::regclass and d.refobjid = to_regclass('public.subs_tin') and dc.oid <> d.refobjid
          union all
          select format('la vista %s no existe', v) from unnest(c_vistas) v where to_regclass('public.' || v) is null
          union all
          select format('la vista %s no lee con los permisos de quien la mira', c.relname)
            from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relname = any (c_vistas) and c.relkind = 'v'
             and not coalesce(c.reloptions @> array['security_invoker=true'], false)
          union all
          select format('la función %s corre con permisos de dueño', p.proname)
            from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any (c_fn) and p.prosecdef
          union all
          select format('%s puede ejecutar %s', r.rol, p.proname)
            from pg_proc p cross join unnest(array['anon', 'service_role']) r(rol)
           where p.pronamespace = 'public'::regnamespace and p.proname = any (c_fn) and has_function_privilege(r.rol, p.oid, 'execute')
          union all
          select format('falta la función %s', f) from unnest(c_fn) f
           where not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = f)
          union all
          select 'el bucket de los subs: ' || b.que
            from (select 'la tabla de Storage no tiene la seguridad por fila puesta' as que
                   where v_storage and not coalesce((select c.relrowsecurity from pg_class c where c.oid = to_regclass('storage.objects')), false)
                  union all
                  select format('falta su candado «%s»', n.n)
                    from unnest(c_bucket_aal || c_bucket_cierra) n(n)
                   where v_storage
                     and not exists (select 1 from pg_policy pl where pl.polrelid = to_regclass('storage.objects') and pl.polname = n.n)
                   group by n.n
                  union all
                  select format('«%s» no pide el código del teléfono', pl.polname)
                    from pg_policy pl
                   where v_storage and pl.polrelid = to_regclass('storage.objects') and pl.polname = any (c_bucket_aal)
                     and coalesce(pg_get_expr(pl.polqual, pl.polrelid), '') || coalesce(pg_get_expr(pl.polwithcheck, pl.polrelid), '')
                         not like '%aal2%'
                  union all
                  select format('«%s» ya no es un candado (dejó de ser restrictiva)', pl.polname)
                    from pg_policy pl
                   where v_storage and pl.polrelid = to_regclass('storage.objects') and pl.polname = any (c_bucket_cierra) and pl.polpermissive) b) z;
  -- (que el bucket exista y sea privado se mira desde el SQL Editor y la ronda: por la API, Storage no deja leer su
  -- lista de buckets, y «no lo veo» no es «no existe»)
  if v_storage and to_regclass('storage.buckets') is not null and not fn_subs_por_api() then
    begin
      execute 'select case when not exists (select 1 from storage.buckets b where b.id = ''subs'') then ''el bucket de los subs: no existe'' '
              'when exists (select 1 from storage.buckets b where b.id = ''subs'' and b.public) then ''el bucket de los subs: es público'' end'
         into v_x;
    exception when others then
      v_x := null;
    end;
    if v_x is not null then
      v_malo := v_malo || v_x;
    end if;
  end if;
  ok := cardinality(v_malo) = 0;
  detalle := case when ok then 'Las diez tablas con su seguridad por fila y su guarda, nada para la llave pública ni para la de servicio, '
                               'el TIN con sus candados (el dueño, su código y la marca), fuera de toda publicación, de toda vista y de las '
                               'estadísticas del planificador, las '
                               'vistas con los permisos de quien mira, ninguna función con permisos de dueño; '
                               || case when v_storage then 'y el bucket de los subs, privado, solo para el dueño con su código del '
                                                           'teléfono (nadie borra ni pisa).'
                                       else 'esta base no tiene Storage: el bucket de los subs no se mira aquí.' end
                  else fn_subs_lista(v_malo, 1400) || '.' end;
  return next;

  -- 92. El registro del servidor (el log de Postgres) no guarda los parámetros de las órdenes: el TIN se teclea en la app y
  --     llega a la base como parámetro de una orden; si el servidor apuntara los parámetros (de toda orden, de las que
  --     fallan, o de las lentas), el TIN iría a su registro. Se mira la configuración del servidor; no se puede cambiar
  --     desde aquí.
  orden := 92; control := 'subs: el registro del servidor no guarda parámetros'; nivel := 'aviso';
  begin
    v_malo := array_remove(array[
      case when coalesce(current_setting('log_statement', true), 'none') in ('all', 'mod')
           then format('apunta todas las órdenes que escriben (log_statement = %s)', current_setting('log_statement', true)) end,
      case when coalesce(current_setting('log_parameter_max_length_on_error', true), '0') <> '0'
           then 'apunta los parámetros de las órdenes que fallan (log_parameter_max_length_on_error no está en 0)' end,
      case when coalesce(current_setting('log_min_duration_statement', true), '-1') not in ('-1')
                and coalesce(current_setting('log_parameter_max_length', true), '-1') <> '0'
           then format('apunta las órdenes lentas con sus parámetros (log_min_duration_statement = %s)',
                       current_setting('log_min_duration_statement', true)) end,
      case when coalesce(current_setting('pgaudit.log_parameter', true), 'off') = 'on' then 'la auditoría apunta parámetros (pgaudit.log_parameter)' end], null);
  exception when others then
    v_malo := array[format('no deja leer su configuración (%s)', sqlstate)];
  end;
  ok := cardinality(v_malo) = 0;
  detalle := case when ok then 'El servidor no apunta los parámetros de las órdenes: un TIN tecleado en la app no va a su registro. (Una '
                               'orden que FALLA sí queda apuntada, sin sus parámetros: por eso ningún mensaje de error de los subs repite '
                               'lo tecleado, y por eso un TIN no se escribe nunca dentro de una orden en el SQL Editor.)'
                  else format('El servidor %s. Un TIN tecleado en la app podría quedar en el registro del servidor (lo ve quien tenga '
                              'acceso al panel de Supabase). Avisa para ajustarlo en la configuración de la base.',
                              array_to_string(v_malo, '; ')) end;
  return next;

  -- 95. Cada archivo registrado (y no retirado) sigue en Storage y mide lo mismo.
  orden := 95; control := 'subs: cada archivo sigue en Storage'; nivel := 'aviso';
  if not v_storage then
    ok := true; detalle := 'Esta base no tiene Storage: no se mira.';
  elsif fn_subs_por_api() and coalesce((select auth.jwt() ->> 'aal'), '') <> 'aal2' then
    ok := true; detalle := 'No se mira en esta sesión: el bucket de los subs pide el código del teléfono.';
  else
    select count(*), count(*) filter (where s.ruta is null or (s.bytes is not null and s.bytes <> a.bytes)),
           fn_subs_lista(array_agg(format('%s (%s)', a.ruta, case when s.ruta is null then 'ya no está' else 'mide otra cosa' end) order by a.ruta)
                  filter (where s.ruta is null or (s.bytes is not null and s.bytes <> a.bytes)), 900)
      into v_n, v_a, v_t
      from subs_archivos a
      left join fn_subs_storage() s on s.ruta = a.ruta
     where a.retirado_el is null;
    ok := v_a = 0;
    detalle := case when ok then format('%s archivo(s) registrado(s): todos siguen en el bucket de los subs y miden lo que se registró.', v_n)
                    else format('%s de %s archivo(s) registrados no están como se registraron: %s. Vuelve a subir el papel y regístralo.',
                                v_a, v_n, v_t) end;
  end if;
  return next;
end $$;
revoke execute on function public.fn_subs_control(int) from public, anon, service_role;
grant  execute on function public.fn_subs_control(int) to authenticated;
comment on function public.fn_subs_control(int) is 'c14: el control de los subs y del 1099 de un año (sin año, el año en curso): 10 cada línea de servicio del año repartida entera; 12 cada pago a una cuenta por pagar repartido entero; 20 las fichas coherentes (terceros que existen; desde el SQL Editor, cada TIN anotado con su fila y buena forma); 30 servicio pagado a alguien sin ficha; 40 servicio pagado sin tercero; 45 servicio pagado por otro camino; 50 fichas que se reportan, incompletas; 55 fichas por decidir con pagos; 60 pagos sin clasificar; 70 COI de quien tuvo servicio este mes; 75 COI que vence pronto; 80 reversos de pagos de un año anterior; 82 pagos que el banco fecha en otro año que el libro; 85 la hoja exportada sigue al día; 88 el umbral del año confirmado; 90 las protecciones de la capa y del bucket; 92 el registro del servidor no guarda parámetros; 95 cada archivo sigue en Storage. nivel: cuadre (algo roto) o aviso. Solo lectura; no lee el TIN por la API; a quien no es el dueño, nada.';

-- LAS DOS FILAS DEL CIERRE (c9: fn_cierre_revisar las pide si esta capa
-- está), para un MES: 160 «subs: COI vigente de cada sub pagado en el mes»
-- (el nombre de siempre) y 179 «subs: W-9 y TIN de cada sub con pago en el
-- mes». Las dos son avisos: no detienen el cierre. Con qué hacer e ir_a.
drop function if exists public.fn_subs_cierre(text);
create function public.fn_subs_cierre(p_periodo text)
returns table (orden int, control text, nivel text, ok boolean, detalle text, que_hacer text, ir_a text)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_d     date;
  v_h     date;
  v_hoy   date := fn_subs_hoy();
  v_nom   text;
  v_n     bigint;
  v_r     bigint;
  v_t     text;
  v_s     numeric;
begin
  if not fn_subs_ve() then
    return;
  end if;
  select p.desde, p.hasta into v_d, v_h from periodos p where p.periodo = p_periodo and p.tipo = 'mes';
  if not found then
    return;
  end if;
  v_nom := fn_subs_mes(v_d);
  ir_a := 'subs'; nivel := 'aviso';

  -- 160. El COI de cada uno con servicio (PAGADO O DEVENGADO: el sub trabajó, se le haya pagado o no) en el mes, vigente
  --      el día de su trabajo o de su pago. El servicio que el libro no dice de quién es no es «un sub»: se dice aparte.
  select count(*) filter (where k.clave <> 'sin_tercero'),
         count(*) filter (where k.clave <> 'sin_tercero' and k.cubierto is not true),
         fn_subs_lista(array_agg(format('%s (%s)', k.nombre, k.que_falta) order by k.nombre)
                         filter (where k.clave <> 'sin_tercero' and k.cubierto is not true), 1000),
         coalesce(sum(k.pagado + k.devengado) filter (where k.clave = 'sin_tercero'), 0)
    into v_n, v_r, v_t, v_s
    from fn_subs_coi(v_d, v_h, least(v_h, v_hoy)) k;
  orden := 160; control := 'subs: COI vigente de cada sub pagado en el mes'; ok := v_r = 0 and v_s = 0;
  detalle := concat_ws(' ',
               case when v_n = 0 then format('Nadie con nombre tuvo servicio (pagado o devengado) en %s.', v_nom)
                    when v_r = 0 then format('Los %s con servicio (pagado o devengado) en %s tenían su COI vigente el día de su trabajo o '
                                             'de su pago.', v_n, v_nom)
                    else format('%s de los %s con servicio (pagado o devengado) en %s no tenían su COI vigente: %s.', v_r, v_n, v_nom, v_t) end,
               case when v_s <> 0 then format('Además hay servicio por %s que el libro no dice de quién es: no se puede mirar su COI.',
                                              fn_subs_usd(v_s)) end);
  que_hacer := case when ok then null
                    else concat_ws(' ',
                           case when v_r > 0 then 'Pide el certificado de seguro (COI) a cada uno y súbelo a su ficha: Contabilidad → Subs y '
                                                  '1099. A quien no tiene ficha, dásela.' end,
                           case when v_s <> 0 then 'Lo que no dice de quién es se atribuye a su ficha en Subs → Pagos.' end) end;
  return next;

  -- 179. El W-9 y el TIN de cada uno con un PAGO de servicio en el mes (en efectivo o con tarjeta). No se le pide a quien
  --      su ficha dice que no se le reporta.
  with pg as (
    select coalesce('ficha:' || c.ficha_id::text, c.tercero_tipo || ':' || c.tercero_id, 'sin_tercero') as clave,
           min(c.ficha_id::text)::uuid as ficha_id, min(c.tercero_tipo) as tt, min(c.tercero_id) as ti, sum(c.monto) as pagado
      from fn_subs_calculo() c
     where c.fecha between v_d and v_h and c.medio in ('efectivo', 'tarjeta') and c.clase = 'servicio'
     group by 1),
  z as (
    select pg.*, f.nombre, f.reporta_efectivo, f.falta,
           case when pg.ficha_id is null and pg.ti is null then 'el libro no dice de quién es'
                when pg.ficha_id is null then 'sin ficha'
                when f.reporta_efectivo = 'no' then null
                when f.falta && array['w9', 'tin']
                  then 'sin ' || array_to_string(array(select case q when 'w9' then 'W-9' else 'TIN' end
                                                         from unnest(f.falta) q where q in ('w9', 'tin') order by q desc), ' ni ') end as que
      from pg left join fn_subs_fichas(null) f on f.ficha_id = pg.ficha_id)
  select count(*), count(*) filter (where z.que is not null),
         fn_subs_lista(array_agg(format('%s (%s; pagado %s)',
                                coalesce(z.nombre, fn_subs_tercero_nombre(z.tt, z.ti), 'Sin tercero'), z.que, fn_subs_usd(z.pagado))
                         order by z.pagado desc) filter (where z.que is not null), 1100)
    into v_n, v_r, v_t
    from z;
  orden := 179; control := 'subs: W-9 y TIN de cada sub con pago en el mes'; ok := v_r = 0;
  detalle := case when v_n = 0 then format('Nadie cobró servicio en %s.', v_nom)
                  when ok then format('Los %s que cobraron servicio en %s tienen su W-9 y su TIN (o su ficha dice que no se les reporta).', v_n, v_nom)
                  else format('%s de los %s que cobraron servicio en %s no tienen su W-9 o su TIN: %s.', v_r, v_n, v_nom, v_t) end;
  que_hacer := case when ok then null
                    else 'Pídeles el W-9 ahora (en enero ya no contestan) y guárdalo con su TIN en su ficha: Contabilidad → Subs y '
                         '1099. Un pago sin nombre se atribuye allí a su ficha.' end;
  return next;
end $$;
revoke execute on function public.fn_subs_cierre(text) from public, anon, service_role;
grant  execute on function public.fn_subs_cierre(text) to authenticated;
comment on function public.fn_subs_cierre(text) is 'c14: las dos filas de los subs para la revisión del cierre (c9) de un mes: 160 «subs: COI vigente de cada sub pagado en el mes» (cada uno con servicio pagado o devengado en el mes, con su COI vigente el día de su trabajo o de su pago; el servicio que el libro no dice de quién es se dice aparte, por su monto) y 179 «subs: W-9 y TIN de cada sub con pago en el mes»; cada una con ok, el detalle en llano, qué hacer e ir_a = subs. Las dos son avisos: no detienen el cierre. Para un período que no es un mes, nada. Solo lectura; a quien no es el dueño, nada.';


-- ---------------------------------------------------------------------
-- 13. Las vistas de la pantalla (security_invoker; leen funciones y tablas
--     de aquí; ninguna toca subs_tin; de periodos y de cuentas no nombran
--     las columnas que c2-pruebas reescribe). Solo authenticated; el equipo,
--     cero filas.
-- ---------------------------------------------------------------------
create view public.v_subs_fichas with (security_invoker = true) as
select f.* from public.fn_subs_fichas(null) f;
revoke all on public.v_subs_fichas from public, anon, authenticated, service_role;
grant select on public.v_subs_fichas to authenticated;
comment on view public.v_subs_fichas is 'c14: cada ficha fiscal, como la pinta la pantalla (las columnas de fn_subs_fichas): su nombre, lo del W-9, si es corporación, si se le reporta y por qué, su dirección, el TIN con máscara (tin_mascara: ***-**-1234; nunca entero), su W-9, su COI (coi_vence, coi_dias, coi_estado, coi_chip) y su exención de WC, sus terceros del libro y lo que le falta para su 1099.';

create view public.v_subs_archivos with (security_invoker = true) as
select a.id as archivo_id, a.ficha_id, coalesce(f.nombre_legal, f.nombre_comercial) as ficha, a.clase, a.ruta, a.sha256, a.bytes,
       a.fecha, a.vence, a.nota, a.registrado_el, a.registrado_por, a.retirado_el is not null as retirado, a.retirado_el,
       a.retirado_motivo,
       (a.retirado_el is null
        and a.id = (select b.id from public.subs_archivos b
                     where b.ficha_id = a.ficha_id and b.clase = a.clase and b.retirado_el is null
                     order by case a.clase when 'coi' then b.vence
                                           when 'w9' then coalesce(b.fecha, (b.registrado_el at time zone 'America/New_York')::date) end desc nulls last,
                              b.registrado_el desc
                     limit 1)) as vigente
  from public.subs_archivos a
  join public.subs_fichas f on f.id = a.ficha_id;
revoke all on public.v_subs_archivos from public, anon, authenticated, service_role;
grant select on public.v_subs_archivos to authenticated;
comment on view public.v_subs_archivos is 'c14: cada papel de cada ficha (W-9, COI, exención de WC), vivo o retirado: su clase, su ruta en el bucket subs, su sha256 y su tamaño, su fecha y cuándo vence, quién y cuándo lo registró, si está retirado y por qué, y si es el que vale hoy de su clase (vigente).';

-- EL 1099: una fila por ficha y año (fn_subs_1099). La pantalla lo pide
-- filtrado por anio: así solo se calcula ese año.
create view public.v_subs_1099 with (security_invoker = true) as
select r.*
  from public.fn_subs_anios() a
  cross join lateral public.fn_subs_1099(a.anio) r;
revoke all on public.v_subs_1099 from public, anon, authenticated, service_role;
grant select on public.v_subs_1099 to authenticated;
comment on view public.v_subs_1099 is 'c14: el 1099 de cada año, una fila por ficha con pagos (las columnas de fn_subs_1099): pagado_servicio, pagado_tarjeta, sin_clasificar, no_servicio, reportable, excluido y excluido_por, umbral y pasa_umbral, falta y falta_texto, listo, el TIN con máscara, parcial y pagos (cada parte, con su asiento y su línea). Se lee filtrada por anio.';

create view public.v_subs_pagos with (security_invoker = true) as
select p.*
  from public.fn_subs_anios() a
  cross join lateral public.fn_subs_pagos(a.anio) p;
revoke all on public.v_subs_pagos from public, anon, authenticated, service_role;
grant select on public.v_subs_pagos to authenticated;
comment on view public.v_subs_pagos is 'c14: cada parte de cada pago de servicio (y de cada pago a una cuenta por pagar), por año (las columnas de fn_subs_pagos): su asiento y su línea, con qué se pagó, qué es y cómo cuenta (estado), de quién es, su partida, su marca. Se lee filtrada por anio.';

create view public.v_subs_coi with (security_invoker = true) as
select k.* from public.fn_subs_coi(null, null, null) k;
revoke all on public.v_subs_coi from public, anon, authenticated, service_role;
grant select on public.v_subs_coi to authenticated;
comment on view public.v_subs_coi is 'c14: cada ficha (o tercero sin ficha) con servicio pagado o devengado en el mes en curso o en los últimos subs_config.coi_ventana_dias días, y su COI a hoy (las columnas de fn_subs_coi): coi_vence, coi_dias (vence − hoy), coi_estado (sin_coi | vencido | por_vencer | vigente), coi_chip («vence en N días»), si cubría cada día con servicio, su exención de WC y qué falta.';

create view public.v_subs_control with (security_invoker = true) as
select c.orden, c.control, c.nivel, c.ok, c.detalle from public.fn_subs_control(null) c;
revoke all on public.v_subs_control from public, anon, authenticated, service_role;
grant select on public.v_subs_control to authenticated;
comment on view public.v_subs_control is 'c14: el control de los subs y del 1099 del año en curso (orden, control, nivel, ok, detalle en llano): 10 y 12 el reparto cuadra; 20 las fichas coherentes; 30 servicio pagado a alguien sin ficha; 40 sin tercero; 45 por otro camino; 50 fichas que se reportan, incompletas; 55 por decidir con pagos; 60 pagos sin clasificar; 70 y 75 el COI; 80 reversos de pagos de un año anterior; 82 pagos que el banco fecha en otro año; 85 la hoja exportada sigue al día; 88 el umbral confirmado; 90 las protecciones; 92 el registro del servidor; 95 los archivos en Storage. nivel: cuadre (algo roto) o aviso. Para otro año, fn_subs_control(año).';


-- ---------------------------------------------------------------------
-- 14. Lo que debe verse al pegar: fn_subs_pegado().
-- ---------------------------------------------------------------------
create or replace function public.fn_subs_pegado() returns table (que text, detalle text)
language plpgsql
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  c       subs_config;
  v_anio  int := extract(year from fn_subs_hoy())::int;
  v_txt   text;
  v_r     record;
  v_sin   bigint;
  v_falta text[] := '{}';
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  select * into c from subs_config where id = 1;
  return query select 'subs_config'::text,
                      format('umbral del 1099: %s%s · no se reporta a: %s · cuentas por pagar que se siguen: %s · no pagan: %s · COI: avisa '
                             'con %s días, mira %s días atrás%s · un pago cuenta con la fecha ' ||
                             case when c.fecha_pago = 'banco' then 'que dijo el banco' else 'de su asiento (▶ CPA: ¿o la del banco?)' end,
                             fn_subs_usd(fn_subs_umbral(v_anio)),
                             case when exists (select 1 from subs_umbrales u where u.anio = v_anio) then format(' (confirmado para %s)', v_anio)
                                  else format(' (de fábrica: ▶ confirmar con el CPA para %s)', v_anio) end,
                             coalesce(nullif(array_to_string(c.entidades_no_reporta, ', '), ''), 'nadie (se le reporta a todos)'),
                             coalesce(nullif(array_to_string(c.cuentas_por_pagar, ', '), ''), 'ninguna'),
                             coalesce(nullif(array_to_string(c.cuentas_no_pago, ', '), ''), 'ninguna'), c.coi_aviso_dias, c.coi_ventana_dias,
                             case when c.coi_exento_basta then ' · al exento de WC le basta su documento' else '' end);
  return query select 'tablas'::text,
                      format('subs_config, subs_umbrales (%s), subs_fichas (%s), subs_tramos (%s vivos), subs_terceros (%s), subs_tin (%s), '
                             'subs_archivos (%s vivos, %s retirados), subs_marcas (%s vivas), subs_historial (%s), subs_exportaciones (%s)',
                             (select count(*) from subs_umbrales), (select count(*) from subs_fichas),
                             (select count(*) from subs_tramos t where t.retirado_el is null), (select count(*) from subs_terceros),
                             (select count(*) from subs_tin), (select count(*) from subs_archivos a where a.retirado_el is null),
                             (select count(*) from subs_archivos a where a.retirado_el is not null),
                             (select count(*) from subs_marcas m where m.retirada_el is null), (select count(*) from subs_historial),
                             (select count(*) from subs_exportaciones));
  return query select 'vistas'::text, 'v_subs_fichas, v_subs_archivos, v_subs_1099, v_subs_pagos, v_subs_coi, v_subs_control'::text;
  if to_regclass('storage.buckets') is not null and to_regclass('storage.objects') is not null then
    return query execute
      'select ''bucket subs''::text, case '
      'when not exists (select 1 from storage.buckets b where b.id = ''subs'') '
      '  then ''NO EXISTE: créalo en Storage (privado) y vuelve a pegar'' '
      'when (select count(*) from pg_catalog.pg_policy pl where pl.polrelid = ''storage.objects''::regclass '
      '       and pl.polname like ''subs: %'') < 7 '
      '  then ''existe, pero le faltan candados: VUELVE A PEGAR este archivo (con la app cerrada); si sigue igual, ponlos en Storage → Policies (solo el dueño, con su código del teléfono, sube y lee; nadie borra ni pisa)'' '
      'else ''privado: solo el dueño, con su código del teléfono, sube y lee; nadie borra ni pisa (7 candados)'' end';
  else
    return query select 'bucket subs'::text, 'sin Storage en esta base (en Supabase el bucket privado «subs» se crea al pegar)'::text;
  end if;
  select count(*) as n, count(*) filter (where f.activa) as activas, count(*) filter (where f.tin_ultimos4 is not null) as con_tin,
         count(*) filter (where f.w9_archivo_id is not null) as con_w9,
         count(*) filter (where f.coi_estado in ('vigente', 'por_vencer')) as con_coi,
         count(*) filter (where f.reporta = 'por_decidir' and not f.es_corporacion) as por_decidir
    into v_r
    from fn_subs_fichas(null) f;
  return query select 'fichas'::text,
                      format('%s ficha(s), %s activas · %s con TIN · %s con W-9 · %s con COI vigente · %s por decidir', v_r.n, v_r.activas,
                             v_r.con_tin, v_r.con_w9, v_r.con_coi, v_r.por_decidir);
  begin
    select format('%s con pagos de servicio · %s pasan del umbral (%s listos para la hoja) · reportable %s · con tarjeta %s · sin '
                  'clasificar %s%s',
                  count(*), count(*) filter (where r.pasa_umbral), count(*) filter (where r.listo),
                  fn_subs_usd(coalesce(sum(r.reportable), 0)), fn_subs_usd(coalesce(sum(r.pagado_tarjeta), 0)),
                  fn_subs_usd(coalesce(sum(r.sin_clasificar), 0)),
                  coalesce(' · ' || min(r.parcial_texto), '')),
           count(*) filter (where r.reporta_efectivo in ('sin_ficha', 'sin_tercero'))
      into v_txt, v_sin
      from fn_subs_1099(v_anio) r;
    if v_sin > 0 then
      v_falta := v_falta || format('dar su ficha (o atribuir sus pagos) a %s que cobraron servicio en %s', v_sin, v_anio);
    end if;
  exception when others then
    v_txt := format('el 1099 de %s falló: %s %s', v_anio, sqlstate, sqlerrm);
  end;
  return query select format('el 1099 de %s', v_anio), v_txt;
  begin
    select format('%s de %s cuadres en rojo%s · %s de %s avisos%s',
                  count(*) filter (where k.nivel = 'cuadre' and k.ok is distinct from true), count(*) filter (where k.nivel = 'cuadre'),
                  coalesce(' (' || string_agg(k.control, '; ' order by k.orden) filter (where k.nivel = 'cuadre' and k.ok is distinct from true) || ')', ''),
                  count(*) filter (where k.nivel = 'aviso' and k.ok is distinct from true), count(*) filter (where k.nivel = 'aviso'),
                  coalesce(' (' || string_agg(k.control, '; ' order by k.orden) filter (where k.nivel = 'aviso' and k.ok is distinct from true) || ')', ''))
      into v_txt
      from fn_subs_control(null) k;
  exception when others then
    v_txt := format('el control falló: %s %s', sqlstate, sqlerrm);
  end;
  return query select 'control'::text, v_txt;
  if not exists (select 1 from subs_umbrales u where u.anio = v_anio) then
    v_falta := v_falta || format('confirmar con el CPA el umbral del 1099 de %s', v_anio);
  end if;
  if not exists (select 1 from subs_fichas) then
    v_falta := v_falta || 'dar de alta la ficha de cada sub y de cada ayudante, con su W-9, su TIN y su COI'::text;
  end if;
  return query select 'qué falta'::text,
                      case when cardinality(v_falta) = 0 then 'nada: todo listo' else array_to_string(v_falta, ' · ') end;
  -- (¿el cierre de esta base ya mira los subs por esta capa? El c9 con su fila 179 lo pide; el de antes no.)
  return query select 'siguiente paso'::text,
                      case when to_regprocedure('public.fn_cierre_revisar(text)') is not null
                                and not exists (select 1 from pg_proc p
                                                 where p.oid = to_regprocedure('public.fn_cierre_revisar(text)')
                                                   and p.prosrc like '%fn_subs_cierre%')
                           then 'El cierre de esta base todavía mira el COI como antes de esta capa (y no trae la fila 179): eso llega '
                                'con el docs/conta/c9-cierre.sql que nombra la fila 179 en su cabecera. Si el que tienes la nombra, vuelve '
                                'a pegarlo; si no, no pasa nada: los subs funcionan sin él, y solo falta su aviso en la lista del cierre. '
                                'Ahora, '
                           else '' end ||
                      'pega docs/conta/c14-pruebas.sql; en la app, Contabilidad → Subs y 1099: una ficha por cada sub y cada ayudante, con '
                      'su W-9, su TIN (pide el código del teléfono) y su COI. El 1099 de 2026 sale de QuickBooks; el de 2027, de aquí.'::text;
end $$;
revoke execute on function public.fn_subs_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_subs_pegado() is 'c14: lo que enseña el final del pegado (nueve filas): la configuración (el umbral y si está confirmado, y con qué fecha cuenta un pago), las tablas y las vistas, el bucket y sus candados, las fichas, el 1099 del año en curso en una línea, el control, qué falta y el paso siguiente. Sin API.';

select * from public.fn_subs_pegado();
