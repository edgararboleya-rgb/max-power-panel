-- =====================================================================
-- c11-emision.sql — LA EMISIÓN DE FACTURAS DESDE LA APP · c11 (la Fase 10
-- son dos capas: esta, la emisión, y c12-wip.sql, el WIP; f10 las llama
-- «c10-facturacion-wip.sql» por un nombre viejo: c10 ya es el costo por
-- obra). 12-nov-2026. Se pega en el SQL Editor DESPUÉS de c1, c2 y c3 (en
-- producción, al final de la cadena: c1, c2, c3, c4, c6, c7, s1, p1, c8,
-- c9, c10 y esta; p1 —los cobros en línea— y Storage pueden faltar: lo que
-- no está no se mira, y se dice). Idempotente: se puede volver a pegar
-- entero (no pisa la configuración, ni un borrador, ni una factura
-- emitida, ni la serie). Después se pega c11-pruebas.sql. No depende de
-- c12 ni c12 de ella.
--
-- REVISIÓN DEL 12-nov-2026, después de pegarlo en producción. La base de
-- la app tiene un índice único que este archivo no conocía —
-- ux_facturas_hito: un hito, UNA sola fila de facturas, contando también
-- las anuladas; es de la otra sesión—, y con él, después de anular la
-- factura de un hito, la buena no entraba (23505). Ahora, al emitir, la
-- anulada SUELTA el hito y queda apuntado (ver «El hito que se vuelve a
-- facturar»). Sobre una base que ya tiene la versión anterior se pega esta
-- ENTERA encima: añade una tabla (emision_soltados) y una fila a lo que
-- enseña el pegado, rehace las funciones y las vistas, y no pisa nada. c9 no
-- hace falta volver a pegarlo por esto.
-- Y de la revisión de ese arreglo (el mismo día), cuatro cosas más, sin
-- tabla ni función nueva: (1) un hito que la ficha SIGUE teniendo como
-- «facturado» por una factura que se anuló desde Contabilidad ya no da un
-- mensaje que no la nombra: dice cuál es, con su nota de crédito, y qué
-- hacer, y el control 75 lo avisa (ver «El hito que sigue como facturado
-- con su factura anulada»); (2) el documento de la factura nueva dice a
-- cuál sustituyó, y el de la anulada, cuál la sustituyó (fn_emision_documento:
-- sustituye y sustituida_por); (3) si la fila de facturas de una emisión
-- choca con un índice único de la base, el error lleva en su detalle —fuera
-- del texto en llano— qué índice fue; y (4) con una factura VIVA del hito el
-- borrador ya no añade «esta la sustituye» por una anulada que también lo
-- apunte: dice solo que ya se facturó.
--
-- Qué hace. Desde el corte (1-ene-2027, configurable) Max Power deja de
-- facturar en QuickBooks: el 🧾 de un hito ya no llama a la función qb,
-- viene aquí. Cinco piezas:
--   (A) EL BORRADOR. Edgar prepara la factura: de un HITO de la obra (el
--       de depósito también se factura; el WIP de c12 lo trata como
--       anticipo, no como avance), por un PORCENTAJE simple del contrato, o
--       T&M (líneas de horas y de material con su precio); y, al final de
--       la obra, la de la RETENCIÓN (la que cobra lo retenido). El borrador
--       vive en las tablas de aquí (emision_documentos y emision_lineas),
--       NO en facturas: ver «Por qué el borrador no vive en facturas».
--       Sus líneas (descripción en inglés, cantidad, precio, importe) suman
--       el monto en numeric; la retención se descuenta sola. Antes del
--       corte se puede preparar y mirar (para probar): emitir, no.
--   (B) LA EMISIÓN (fn_emision_emitir), en UNA transacción, todo o nada:
--       1. toma el borrador, su hito y lo que mira; comprueba que es lo
--          que Edgar vio (el «visto») y que nada frena;
--       2. le da su NÚMERO: MXP-2027-0001, una serie por año, seguida y
--          sin huecos, desde la tabla contadores de c2 (serie
--          «facturas-2027»). El número lo pone un trigger de la tabla
--          emision_serie (la única función SECURITY DEFINER de la capa:
--          contadores es del libro y la API no la escribe; un trigger no se
--          puede llamar suelto). Una emisión que falla no gasta número: se
--          deshace con todo lo demás. Un número que ya lleva OTRA fila de
--          facturas —de la obra que sea, hecha fuera de la app— no se da
--          dos veces: la serie lo SALTA y da el siguiente; la emisión lo
--          dice («saltados») y el control 20 lo sabe (en facturas no queda
--          hueco: ese número lo lleva aquella). La factura de la retención,
--          que no es una fila de facturas, lleva SU serie
--          (MXP-R-2027-0001, «retenciones-2027»): así cada número de la
--          serie de las facturas ES una fila de facturas;
--       3. crea la fila de facturas YA EMITIDA (num, fecha de hoy en Miami,
--          monto, retencion EN DÓLARES, hito_id, a_contratista), como nacen
--          hoy las de QuickBooks: es el camino que c3 ya contabiliza. (Si el
--          hito ya tuvo una factura que se anuló y su fila todavía lo apunta,
--          antes esa fila anulada suelta el hito: la base de la app admite
--          una sola fila de facturas por hito. Ver «El hito que se vuelve a
--          facturar».) El
--          puente de c3 es diferido (corre al confirmar): aquí se adelanta
--          dentro de la misma transacción (set constraints … immediate) y
--          se comprueba que la factura QUEDÓ EN EL LIBRO, al centavo:
--          Dr 1110 lo que el cliente paga ahora + Dr 1120 lo retenido /
--          Cr el ingreso del tipo de su obra. Si el libro no la acepta (una
--          regla sin confirmar, una cuenta inactiva, un mes sin abrir), no
--          se emite NADA y el mensaje dice por qué, en llano. No hay
--          factura emitida fuera del libro;
--       4. mueve el hito a «facturado» (como lo mueve hoy el 🧾: nunca uno
--          ya cobrado);
--       5. congela el documento: guarda el CONTENIDO entero de lo que el
--          cliente va a recibir (un jsonb: la empresa, a quién, la obra,
--          las líneas, los totales, la retención, el contrato y lo
--          facturado, el «How to pay», los términos) y su HUELLA (sha256).
--          Desde ahí no cambia nada: ni el documento ni sus líneas (la
--          guarda de aquí), ni el monto, la fecha, la obra, el número o la
--          retención de la fila de facturas (la guarda de c3).
--   (C) ANULAR ES NOTA DE CRÉDITO, NUNCA BORRAR: fn_emision_anular llama a
--       fn_factura_anular de c3 (NC-AAAA-NNNN, el espejo del asiento, con
--       sus frenos: no con cobros aplicados, no la de la apertura…), deja
--       el documento marcado y devuelve el hito a «pendiente» para hacer la
--       buena, con número nuevo. Lo que el cliente recibió no se corrige.
--       CON UN PAGO POR CUENTA DE BANCO EN CAMINO NO SE ANULA (MX008): ese
--       dinero llegaría a una factura anulada, los cobros en línea lo
--       dejarían de anticipo de la obra, y la factura buena seguiría
--       debiendo entera aunque el cliente ya pagó. Se espera a que el pago
--       entre o falle.
--   (D) EL PDF Y EL ENVÍO. La función de borde nueva (supabase/functions/
--       facturas, del repo) pinta el PDF con el contenido congelado, lo
--       sube al bucket PRIVADO «facturas» (lo crea este archivo: solo el
--       dueño, con su código del teléfono, sube y lee; nadie borra ni pisa)
--       y lo registra aquí (fn_emision_pdf: ruta, sha256, bytes; la base
--       comprueba que el archivo está en Storage y que se pintó de ESE
--       contenido); manda el correo por Resend y registra el envío
--       (fn_emision_envio: a quién, cuándo, el id de Resend; un reenvío es
--       otra fila; «en mano» también se apunta). Todo se añade, nada se
--       edita.
--   (E) EL CORTE Y LOS CONTROLES. v_emision_estado dice si hoy se factura
--       por la app o por QuickBooks (la pantalla desvía el 🧾 con eso);
--       v_emision_control vigila (ver más abajo), y el cierre del mes (c9)
--       lo mira con el bloque de las filas 172 y 173.
--
-- POR QUÉ EL BORRADOR NO VIVE EN facturas (c3 reservó para esto el estado
-- «borrador», y p1 lo conoce). Una fila de facturas la leen hoy cosas que
-- no saben de borradores y que no son de este archivo:
--   · el portal del cliente y el del contratista (cliente.html, gc.html)
--     enseñan las facturas de la obra y las «open invoices» con su monto y
--     sus días: los arma la función de borde «portal», de otra sesión, que
--     no está en este repositorio. Un borrador ahí puede salirle a un
--     cliente como una factura abierta;
--   · la función qb (viva hasta el 31-dic) no factura un hito si ya hay una
--     fila de facturas con ese hito_id: un borrador «para probar» le
--     trancaría el 🧾 a ese hito durante el paralelo;
--   · la app publicada cuenta como factura todo lo que no está anulado
--     (js/db.js), y la bandeja de c3 saca los borradores de más de dos
--     días como «en espera».
-- Nada de eso se puede cambiar desde aquí. Así que el borrador es de c11
-- y la fila de facturas nace al emitir, ya emitida —que es exactamente
-- como nacen hoy las de QuickBooks y lo que todo lo demás ya entiende—. El
-- ciclo de c3 se usa entero y sin rodearlo: su puente la contabiliza, su
-- guarda la congela y su fn_factura_anular la anula.
--
-- EL HITO QUE SE VUELVE A FACTURAR (lo que falló en producción el 12-nov).
-- La base de la app tiene DOS índices únicos sobre facturas.hito_id. Son de
-- la otra sesión (de la app y de la función qb), no de ninguna capa c*:
-- aquí ni se crean ni se quitan. Leídos en producción el 12-nov-2026:
--   ux_facturas_hito       un hito, UNA sola fila de facturas: cuenta TODAS,
--                          también las anuladas
--   ux_facturas_hito_viva  un hito, una sola fila VIVA (sin anular)
-- Y aquí anular es nota de crédito, nunca borrar: la fila anulada se queda,
-- con su hito_id. Con el primero, la factura buena de ese hito no entraba
-- nunca más (23505 «ux_facturas_hito»), la hubiera emitido la app o
-- QuickBooks. Lo que se hace, y por qué así:
--   · AL EMITIR la factura de un hito, en la misma transacción y justo
--     antes de crear su fila de facturas, las filas ANULADAS que todavía
--     apuntan a ese hito lo SUELTAN: su facturas.hito_id pasa a nulo. De
--     cualquier origen: las que emitió la app y las de fuera (una de
--     QuickBooks anulada desde Contabilidad, por c3). En lo demás no
--     cambian: siguen anuladas, con su nota de crédito, su asiento, su
--     número y lo cobrado como estaban. Si la emisión no llega al final
--     (el libro no la acepta, ya no es lo que se vio…), se deshace con
--     todo lo demás y la anulada conserva su hito.
--   · QUEDA APUNTADO en emision_soltados: qué factura (su id, su número, su
--     obra, su nota de crédito, y si era de la app o de fuera), qué hito
--     tenía, qué documento la soltó al emitirse, cuándo y quién. En facturas
--     ya no se ve de qué hito fue la anulada: ahí queda. (Si era de la app,
--     su documento conserva además su hito: emision_documentos.hito_id no
--     cambia nunca.) La emisión lo devuelve también en «soltadas».
--   · EL BORRADOR LO DICE con un aviso que NO frena (código
--     hito_factura_anulada): «El hito … ya tuvo una factura que se anuló: N
--     del día D (nota de crédito NC-…). Esta la sustituye…». Es lo normal
--     después de anular; se dice para que nadie facture dos veces sin
--     darse cuenta de que hubo otra.
--   · SIEMPRE, tenga la base ese índice o no: la regla no depende de lo que
--     otra sesión ponga o quite en facturas (si un día quita
--     ux_facturas_hito y deja el de las vivas, aquí no cambia nada). Con
--     eso, facturas.hito_id dice una sola cosa: cuál es la factura de ese
--     hito HOY (la viva; o la última anulada, si todavía no hay otra).
--   · POR QUÉ AL EMITIR Y NO AL ANULAR. Soltar al anular solo cubriría las
--     anulaciones que pasan por aquí: una factura anulada desde Contabilidad
--     (c3 directo) y una de QuickBooks anulada por c3 seguirían apuntando a
--     su hito, y habría que soltarlas al emitir de todas formas. Y al
--     emitir, soltar la anulada y poner la nueva van juntos: quien lea
--     facturas por su hito (la función qb, su candado) nunca ve el hito sin
--     fila.
--   · LO QUE SE COMPROBÓ (c11-pruebas, la 52 y la 53; c11-concurrencia, 4b
--     y 4c), con los índices de producción puestos:
--       - la guarda de c3 deja ese cambio en una anulada (no cambian su
--         monto, su fecha, su obra, su número, su retención, su estado ni
--         lo cobrado);
--       - su puente no asienta nada: ni el hito ni el estado entran en la
--         firma del papel, y una anulada «no aplica»; el libro solo gana el
--         asiento de la factura nueva;
--       - el trigger de lo cobrado de la app (trg_factura_cobrada) no cambia
--         nada: solo actúa al pasar a pagada, o si cobrado está vacío;
--       - ningún control se enciende, ni de aquí ni de c2, c3, c4, c6, p1,
--         c8, c9 (con c12) ni c10. El aviso 42 («una factura de hito que ya
--         no apunta a su hito») solo mira facturas VIVAS: una anulada que
--         soltó su hito no sale ahí.
--   · LA FUNCIÓN qb (viva hasta el 31-dic). Su candado por hito lee facturas
--     por hito_id SIN mirar el estado: una fila anulada que todavía apunta
--     a un hito le sigue diciendo «ese hito ya se facturó». Eso es de qb y
--     de ANTES de esta capa (una de QuickBooks anulada por c3 ya trancaba
--     su hito), y aquí no cambia: mientras el hito no se vuelva a facturar
--     por la app, la anulada lo conserva y qb no lo factura; y al
--     facturarlo la app, qb encuentra la factura nueva, viva. El soltado no
--     le abre nunca un hito a qb. Lo que sigue sin poderse, y no es de
--     aquí: ANTES DEL CORTE NO HAY NINGÚN CAMINO para volver a facturar un
--     hito cuya factura se anuló: qb (el 🧾 de siempre) lo ve facturado, y
--     la app no emite antes del corte, así que tampoco suelta. Si hiciera
--     falta antes del 1-ene quedan dos salidas: adelantar el corte (desde
--     ese día factura la app, que sí lo hace), o que la otra sesión cambie
--     qb. Y para eso no le basta con «mirar solo las vivas»; son TRES cosas
--     a la vez:
--       - que su candado mire solo las vivas, y que no se rinda si un día
--         encuentra dos filas de facturas del mismo hito (una anulada y una
--         viva): hoy, con dos, no ve ninguna y facturaría otra vez;
--       - quitar ux_facturas_hito (si solo cambia el candado, qb crearía la
--         factura en QuickBooks y su fila chocaría con el índice);
--       - EL NÚMERO: qb le pone a la factura de un hito siempre el mismo
--         número y guarda su fila por obra y número (si ya hay una con ese
--         número en esa obra, la actualiza en vez de crear otra). Si
--         QuickBooks le acepta el número repetido, lo que se actualiza es la
--         fila ANULADA: con otra fecha u otro monto la guarda de c3 lo
--         rechaza (si la anulada estuvo en el libro) y la factura queda
--         hecha en QuickBooks y sin anotar en la app; con la misma fecha y
--         el mismo monto cambia en silencio, y la factura nueva no existe ni
--         para la app ni para el libro. (Comprobado en el banco imitando ese
--         guardado sobre una anulada.)
--   · DOS A LA VEZ. Dos pestañas emitiendo el mismo borrador: una emite y
--     suelta; la otra, MX008, y lo soltado queda apuntado una vez. La app y
--     qb con el mismo hito en el mismo instante: la fila de fuera sujeta su
--     hito (la llave de facturas hacia hitos) y la emisión, que toma el
--     hito lo primero, la espera; cuando le toca ya no es lo que se vio
--     (MX011) o el hito ya está facturado (MX008). Y si aun así su fila de
--     facturas chocara con un índice único de la base —el del hito o el del
--     número—, no sale el error del índice: MX011, en llano, y no queda
--     nada (ni el número). Qué índice chocó va en el DETALLE del error, que
--     la pantalla no enseña y sí queda en la respuesta de la API y en el
--     registro de la base: si un día la base tuviera otro índice único que
--     la emisión no cumple, ese MX011 saldría siempre, y así se sabe cuál.
--   · EL HITO QUE SIGUE COMO «FACTURADO» CON SU FACTURA ANULADA. Anular
--     desde Facturación devuelve el hito a pendiente. Anular DESDE
--     CONTABILIDAD (por c3, que no sabe de hitos; es como se anula hoy una
--     de QuickBooks, y no hay botón: se hace con una consulta) deja la
--     ficha con el hito «facturado» y sin ninguna factura viva. Solo se
--     factura un hito pendiente (ver «Un hito, una factura viva»), así que
--     ese hito no se ofrece y su borrador no se abre; y la ficha de la obra
--     NO TIENE BOTÓN para devolver un hito a pendiente (solo lo pasa a
--     cobrado). Lo que se hace aquí, sin cambiar esa regla:
--       - se DICE, con la factura y su nota de crédito, al pedir el
--         borrador (MX008) y en uno ya abierto (el aviso
--         hito_marcado_facturado, que frena). Si la anulada es de la app y
--         aquí sigue sin cerrar: «ábrela en Facturación y toca Anular»
--         (termina lo de aquí y el hito vuelve a pendiente: ese camino sí
--         tiene botón). Si es de fuera: el hito tiene que volver antes a
--         pendiente, y como la ficha no tiene con qué, «avisa y se hace»;
--       - el CONTROL 75 lo avisa (el hito, la obra, la factura anulada y su
--         nota): sin eso nadie lo ve, porque en «Por facturar» ese hito sale
--         «facturado» y sin botón, y si nadie lo volvió a facturar por otro
--         lado está SIN FACTURAR.
--     Por qué no se factura sin más (se pensó): que el hito esté marcado se
--     explica por la anulada, pero aquí no se puede saber si después se
--     volvió a facturar por QuickBooks a mano; la regla de la casa es no
--     facturar un hito que la ficha da por facturado sin que alguien lo
--     devuelva a pendiente. EN LA PRÁCTICA: la consulta con que se anule una
--     factura de QuickBooks lleva los dos pasos, anularla y devolver su hito
--     a pendiente (update hitos set estado = 'pendiente' where id = …). Y si
--     el control 75 nombra un hito que SÍ se volvió a facturar por fuera, lo
--     que toca es enlazar esa factura a su hito (antes hay que quitarle el
--     hito a la anulada: con el índice de producción no caben las dos); el
--     aviso se apaga con cualquiera de las dos cosas.
--   · SI EL HITO SE BORRA en la ficha, la llave de la app deja en nulo el
--     hito_id de TODAS sus filas de facturas, también de las anuladas, y de
--     eso no queda apunte aquí (a las tablas de la app no se les cuelga
--     nada): de qué hito fue una anulada de la app lo sigue diciendo su
--     documento; de una de fuera, la procedencia de su asiento en los
--     puentes de c3.
--   · LO QUE NO SE PUDO COMPROBAR DESDE AQUÍ: qué enseña el portal del
--     cliente de una factura anulada. Sus facturas y lo que debe los arma la
--     función «portal», de la otra sesión, que no está en este repositorio.
--     Si lee las facturas de un hito por su hito_id, el soltado le viene
--     bien (después de volver a facturar queda una sola, la viva). Lo que
--     hay que preguntarle antes de la primera anulación de verdad: si deja
--     fuera las anuladas de la lista de facturas y de lo que el cliente
--     debe; si no, una anulada le sale al cliente como abierta, tenga hito o
--     no.
--
-- LA RETENCIÓN (c3: facturas.retencion es el MONTO en dólares de ESTA
-- factura que el cliente retiene; va a 1120):
--   · EL PORCENTAJE sale de la obra: el que Edgar ponga (emision_obras, en
--     por ciento: 10 = 10 %), o el del estimado enlazado
--     (estimados.retencion_pct, que la app guarda como FRACCIÓN —0.10 es el
--     10 %; su restricción no deja pasar de 0.2—: aquí se multiplica por
--     100), o ninguno. El borrador lo enseña con su origen y Edgar lo puede
--     cambiar en ese borrador.
--   · LA REGLA DE REDONDEO: retención = round(monto × % × 0.01, 2), con el
--     redondeo de numeric de Postgres (la mitad, lejos de cero), UNA vez por
--     factura sobre el monto entero; lo que el cliente paga ahora es
--     monto − retención (una resta: nunca se redondea dos veces). El 10 %
--     de 1,234.57 son 123.46 y se pagan 1,111.11. Por ser por factura, la
--     suma de lo retenido en una obra puede diferir en centavos del % del
--     contrato (tres hitos de 3,333.33 + 3,333.33 + 3,333.34 al 10 %
--     retienen 333.33 + 333.33 + 333.33 = 999.99): lo que vale es lo que
--     dice cada factura, que es lo que está en 1120.
--   · LA FACTURA DE LA RETENCIÓN (forma «retencion»), al final de la obra,
--     NO es ingreso nuevo: el ingreso entero ya entró con cada factura, y lo
--     retenido está por cobrar en 1120, factura por factura. Por eso NO es
--     una fila de facturas (c3 le pondría ingreso otra vez) y no lleva
--     asiento: es un documento que lista lo retenido de cada factura de la
--     obra, tal como está abierto en el libro ese día, y lo reclama. LLEVA
--     SU PROPIA SERIE (MXP-R-2027-0001: el formato de los ajustes con una R
--     detrás del prefijo; contador «retenciones-AAAA»), no la de las
--     facturas: si tomara número de aquella, la serie de las facturas
--     tendría un número sin fila de facturas (un hueco para quien mire
--     facturas), y el cliente pagaría «la factura MXP-2027-0007», que ni el
--     banco ni los cobros en línea conocen. Su contenido lleva
--     «referencias»: los números de las facturas cuya retención reclama,
--     que es contra lo que se cobra y lo que el cliente cita al pagar.
--     Cuando paga, el cobro va contra la retención de cada factura
--     (es_retencion, por fn_cobro_registrar o por el banco), que es como c3
--     la cobra. Si se emitió mal, se anula (queda marcada, con su motivo;
--     no hay asiento que deshacer). Y mientras esté viva, las facturas que
--     reclama no se anulan desde aquí (primero se anula ella); si una se
--     anula desde Contabilidad, el control 75 lo avisa.
--   · UN CONFLICTO QUE SE VIGILA: la función qb escribe en ese mismo campo
--     un PORCENTAJE en las obras por contratista. Hoy todas valen 0. Aquí
--     siempre se escribe el monto; el control 70 avisa de toda factura que
--     no salió de aquí con una «retención» que parece un porcentaje. Y c3
--     lee estimados.retencion_pct como por ciento en el mensaje con que
--     pide la retención (solo el mensaje: no postea nada con eso).
--
-- EL PAGO EN LÍNEA (decisiones de Edgar: 11-nov, ACH por Stripe como pago
-- principal; 12-nov, SOLO ACH POR AHORA: la tarjeta queda apagada hasta una
-- versión futura de los cobros en línea que contabilice el recargo como
-- ingreso; eso no se hace aquí). p1 está sellado y no se toca. Lo que se
-- comprobó en el banco (c11-pruebas, la 30, la 31 y la 32):
--   · EL ENLACE DE UNA FACTURA DE LA APP ES EL DE p1, SOLO POR CUENTA DE
--     BANCO. p1 arma un Payment Link de un solo uso por lo que el LIBRO
--     dice que la factura debe en 1110 (fn_stripe_enlace_preparar: sus
--     centavos, sus metadatos {mxp: «p1», enlace, factura_id, factura,
--     retencion: «no»} y su llave de idempotencia). Recién emitida, eso es
--     EXACTAMENTE el «Amount due» del documento (monto − retención): lo que
--     la factura dice es lo que Stripe cobra. Pero la función «stripe»
--     manda siempre payment_method_types = [us_bank_account, card], fijo en
--     su código: su enlace deja pagar con tarjeta al mismo precio.
--   · LO QUE TIENE QUE MANDAR A STRIPE LA FUNCIÓN DE BORDE «facturas» (o lo
--     que tiene que dejar puesto), para que el libro cuadre:
--       - el enlace se pide a p1 (su fila en stripe_enlaces: uno vivo por
--         factura, con su ciclo —usado, desfasado, desactivado— como
--         siempre), con con_retencion = false;
--       - line_items: UN precio, en usd, de los centavos que da p1 (nunca
--         otro monto: p1 reparte lo cobrado contra lo que el libro debe);
--       - metadata y payment_intent_data.metadata: los de p1, sin tocar
--         (el aviso de Stripe casa el pago con la factura por ahí);
--       - restrictions.completed_sessions.limit = 1 (un solo uso);
--       - payment_method_types = [us_bank_account] y NADA MÁS. Si el enlace
--         lo creó la función «stripe», se restringe en Stripe (POST
--         /v1/payment_links/{plink} con payment_method_types[0] =
--         us_bank_account) ANTES de enseñar o mandar la URL.
--     fn_emision_pago(documento) le dice a la función de borde qué monto y
--     qué métodos tocan y qué enlace vivo hay; fn_emision_pdf no registra
--     un PDF cuyo enlace no sea el vivo de p1 por lo que el libro debe, o
--     que declare tarjeta. El cobro entra al libro por p1 como siempre:
--     Dr 1020 / Cr 1110 de la factura al cobrar; la comisión de Stripe, a
--     6130 al depositar (sus asientos P1 y P2). Nada de eso es de aquí.
--   · LA TARJETA QUEDA APAGADA (decisión del 12-nov-2026: por ahora solo
--     ACH), y no por gusto. Un pago con recargo cobra más de lo que la
--     factura debe en el libro, y p1 reparte un cobro así: primero lo que
--     la factura debe en 1110, después su retención, y LO QUE SOBRA LO DEJA
--     DE ANTICIPO DE LA OBRA (un saldo a favor del cliente) con el aviso
--     «¿pagó dos veces?». El recargo no es un anticipo: es un ingreso (o
--     una recuperación de la comisión). p1 no tiene dónde decirle a qué
--     cuenta va, y arreglarlo a mano cada vez sería rodearlo. En llano, con
--     las palabras de Edgar: LA TARJETA SE ENCIENDE CUANDO EL SISTEMA DE
--     COBROS SEPA REGISTRAR EL RECARGO. Lo dice UN solo texto
--     (fn_emision_tarjeta_texto) en los ajustes (tarjeta_texto), en el pago
--     de cada factura (tarjeta.por_que), en el control 80 y en
--     v_emision_estado (tarjeta_texto): la pantalla lo enseña tal cual.
--     Mientras, fn_emision_config no deja poner tarjeta_pct (MX008, con ese
--     texto): el campo y la cuenta del recargo existen, vacíos; LA FACTURA
--     NO LE OFRECE TARJETA AL CLIENTE (su contenido dice
--     pago_en_linea.tarjeta = false y, si hay pago en línea, una línea en
--     inglés para el cliente: «Online payment is by bank account (ACH)
--     only.»), y el control 80 avisa si una factura de la app se cobró con
--     tarjeta (el enlace no era solo de cuenta de banco). Las reglas de las
--     marcas de tarjeta sobre recargos (aviso, tope, débito) y a qué cuenta
--     va el recargo NO se afirman aquí: se confirman con Stripe y con el
--     CPA antes de encender nada.
--   · La factura de la retención no lleva enlace propio en esta versión
--     (un enlace de p1 es de UNA factura): se cobra por cheque o
--     transferencia, o con el enlace «con la retención» de cada factura,
--     desde Cobros en línea.
--
-- LA SEGURIDAD (la regla de c2, B.20, y lo que c6, c4, c8, c9 y c10 sellan):
--   · Las funciones que llama la pantalla o la función de borde (con la
--     sesión de Edgar: por la API, nunca como service_role ni directo a la
--     base) son SECURITY INVOKER, sin EXECUTE para public, anon ni
--     service_role, con EXECUTE para authenticated y es_dueno() por dentro
--     (fn_emision_exigir_dueno). Leen con la policy de cada tabla (solo el
--     dueño) y escriben facturas e hitos con las policies que la app ya
--     usa, y las tablas de c11 con su policy de escritura del dueño. Al
--     libro NO entran: el asiento lo pone el puente de c3 (su trigger) y la
--     nota de crédito, fn_factura_anular de c3.
--   · UNA sola SECURITY DEFINER: fn_emision_numerar, el trigger que da el
--     número. Devuelve «trigger» (Postgres no deja llamarla suelta), sin
--     EXECUTE para nadie, y solo corre al insertar en emision_serie, que
--     solo se escribe con la marca de fn_emision_emitir. Por eso «permisos»
--     de c2 y «protecciones del banco» de c6 siguen en verde.
--   · fn_emision_pegado y fn_emision_precondiciones: sin API.
--   · Las tablas nacen con RLS y policies solo-dueño, y con la guarda de
--     c6, c9 y c10: un trigger (fn_emision_guarda) que solo deja escribir
--     con la marca de la transacción (mx_emision.escribe = la tabla) que
--     ponen las funciones de aquí. Un insert o un update a mano por
--     PostgREST, aunque sea del dueño, da MX003. Un documento emitido no
--     cambia (solo se le apunta su anulación, una vez); sus líneas, su
--     número, sus PDF, sus envíos y lo soltado no se editan ni se borran.
--   · Las vistas son security_invoker y leen solo TABLAS (nunca una vista
--     de otra capa, que se rehace al volver a pegar su archivo) y funciones
--     de aquí; de periodos y de cuentas no nombran estado,
--     cadena_al_cerrar, activa ni saldo_normal.
--   · Nada lleva un prefijo de otra capa ni de la otra sesión (fn_factura_,
--     fn_cobro_, fn_anticipo_, fn_doc_, fn_qb_, cxc_…; y en LIKE el «_» es
--     comodín: fn_facturar_x casaría con fn_factura_%): aquí todo es
--     fn_emision_*, emision_* y v_emision_*. es_dueno() no se toca. No pone
--     índices, triggers ni columnas en las tablas de la app; solo una llave
--     foránea DESDE aquí hacia facturas (un documento emitido conserva su
--     factura).
--   · s1 (el código del teléfono) exige aal2 en cada petición de la API si
--     el dueño tiene factor: vale igual para la pantalla y para la función
--     de borde, que llama con la sesión de Edgar. PERO STORAGE NO PASA POR
--     ESA GUARDA: con solo la contraseña (una sesión aal1) se leían y se
--     subían los PDF del bucket «facturas». Por eso las policies del bucket
--     piden aquí el código del teléfono («(select auth.jwt() ->> 'aal') =
--     'aal2'», lo mismo que ya exige la función de borde), y hay además dos
--     candados «restrictive» de lectura y de subida: aunque otra policy
--     permisiva de Storage dejara pasar, en este bucket solo entra el dueño
--     con su código; la llave pública, nunca. El control 90 mira que esos
--     candados sigan puestos. (El bucket «cierres» de c9 tiene el mismo
--     hueco: se cierra en c9, con el bloque que acompaña a esta capa.)
--
-- LOS ERRORES CON NOMBRE (conta.js los enseña tal cual; ninguno es nuevo):
--   MX000  falta algo que este archivo da por hecho: no se aplica nada
--          (fn_emision_precondiciones dice qué)
--   MX001  el asiento que dejó c3 no es el de la factura al centavo: no se
--          emite nada (una red: no debe verse)
--   MX003  las tablas de c11 solo las escriben sus funciones; un documento
--          emitido, sus líneas, su número, sus PDF, sus envíos y lo soltado
--          no cambian
--   MX004  la cuenta del recargo no sirve
--   MX005  un monto o un porcentaje mal (cero, negativo, con decimales de
--          más, fuera de rango)
--   MX008  no procede, con el porqué y qué hacer: todavía no es el corte;
--          faltan los datos de la empresa o el «How to pay»; el hito ya se
--          facturó (aquí, o la ficha lo tiene como facturado: si es por una
--          factura que se anuló, dice cuál y qué hacer) o ya se cobró;
--          el borrador ya se emitió; la factura ya
--          estaba anulada; anularla con un pago por cuenta de banco en
--          camino, o con cobros aplicados; el libro no la aceptó (dice qué
--          falta); la base no dejó soltar el hito de una anulada (una red:
--          no debe verse); la tarjeta está apagada; un PDF con un enlace
--          que no es el suyo; un envío sin PDF; poner el corte después de
--          una factura viva. Y los demás MX008 de c3 al anular, tal cual
--   MX011  YA NO ES LO QUE VISTE: el «visto» que manda la pantalla no es el
--          del borrador de hoy (lo cambió otra pestaña; cambiaron los
--          ajustes que salen en la factura; entró o se anuló otra factura
--          de la obra —cambian su ordinal y lo facturado antes—; o se miró
--          un día y se emite otro), o cambió algo de fuera desde que se
--          armó (el hito, el contrato, la retención, a quién se factura la
--          obra), o el PDF no se pintó del contenido congelado, o —una red—
--          mientras se emitía entró por otro lado una factura de ese mismo
--          hito o con ese mismo número y la fila de facturas chocó con un
--          índice único de la base (cuál, en el detalle del error): no se
--          hace nada; se refresca y se vuelve a pedir
--   22023  entrada mal formada: falta un dato, una clave desconocida, una
--          ruta fuera de su carpeta, un archivo que no está en Storage
--   22007  una fecha que no viene como AAAA-MM-DD
--   42501  permiso: solo el dueño; anon y service_role, nada
--   55P03  (de Postgres) la app estaba usando estas tablas mientras se
--          pegaba el archivo: no se aplicó nada; se vuelve a pegar
--
-- LOS CONTROLES (v_emision_control: orden, cuadre, nivel, ok, detalle):
--   10 cuadre  cada factura emitida por la app es su asiento de c3, al
--              centavo (1110 + 1120 = monto; 1120 = retención; el ingreso)
--   20 cuadre  las series de cada año (facturas y facturas de la
--              retención), sin huecos ni repetidos, y cada contador en su
--              último número (un número saltado vale solo si lo lleva una
--              factura hecha fuera de la app)
--   30 cuadre  cada documento emitido sigue sellado (su huella, sus líneas,
--              sus totales) y su fila de facturas dice lo mismo
--   40 cuadre  ningún hito con dos facturas vivas si alguna salió de la app
--              (el hito de una factura de la app es el de su documento)
--   42 aviso   cada factura de hito de la app sigue enlazada a su hito en
--              la ficha (su fila de facturas no cambió de hito; su hito no
--              se borró quedando hitos por facturar en la obra)
--   44 aviso   en ninguna obra lo facturado por hitos pasa de lo que suman
--              sus hitos (un hito borrado, vuelto a crear y facturado otra
--              vez)
--   50 aviso   cada PDF registrado sigue en Storage y mide lo mismo
--   60 aviso   ninguna factura emitida hace más de N días sin PDF
--   62 aviso   ni sin mandar (o entregar en mano)
--   64 aviso   ninguna factura de la app cobrada entera en el libro y sin
--              marcar como cobrada en la ficha de su obra
--   70 aviso   ninguna factura que no salió de la app con una retención que
--              parece un porcentaje (el conflicto con qb)
--   72 aviso   ninguna factura fechada desde el corte que no salió de la
--              app; ninguna de fuera con un número de la serie
--   75 aviso   ninguna anulada en el libro y sin cerrar aquí; ninguna
--              factura de la retención que reclame lo de una anulada; ningún
--              hito con dos facturas vivas de antes; ningún hito que siga
--              como facturado en la ficha con su factura anulada y sin otra
--              viva
--   80 aviso   el pago en línea como se decidió (ningún cobro con tarjeta de
--              una factura de la app; el porcentaje de tarjeta, vacío;
--              ninguna anulada con un pago en camino)
--   85 aviso   los datos de la empresa y el «How to pay», puestos cuando se
--              acerca el corte
--   90 cuadre  las protecciones de la capa, y los candados del bucket
--              «facturas» (solo el dueño, con su código del teléfono)
--   Un «cuadre» en rojo es algo roto (detiene el cierre del mes: fila 172);
--   un «aviso», algo que mirar (fila 173). Ningún cuadre mira facturas de
--   antes de la app: no se enciende con la historia.
--
-- Decisiones de diseño (lo que f10 y el encargo dejaban abierto):
--   · EL PRECIO DE LA OBRA es finanzas_proyecto.contrato (el plan proponía
--     «la suma de alcances aprobados»: hoy alcances cubre pocas obras y su
--     estado es texto libre; en todas las obras con hitos la suma de los
--     hitos ES el contrato). La forma por porcentaje lo usa de base y lo
--     guarda en el documento; el contenido congelado guarda el contrato y
--     lo facturado de ese día.
--   · LA FECHA ES HOY (en Miami, fn_fecha_miami): no se emite con fecha de
--     ayer ni de mañana. El número va en el orden en que se emite.
--   · «DUE ON RECEIPT» de fábrica (terminos_dias = 0), que es la regla de
--     la casa con QuickBooks; se cambia en los ajustes.
--   · UN HITO, UNA FACTURA VIVA, y un solo borrador por hito (tocar 🧾 dos
--     veces abre el mismo). La factura de un hito lleva UNA línea por el
--     monto del hito; si el hito cambia, el borrador lo dice y se refresca.
--     EL HITO DE UNA FACTURA DE LA APP ES EL DE SU DOCUMENTO
--     (emision_documentos.hito_id, que no cambia), no solo el que diga hoy
--     su fila de facturas: si alguien vacía o cambia facturas.hito_id, o
--     borra el hito (la llave de la app deja facturas.hito_id en nulo), ese
--     hito sigue facturado para el borrador, para la emisión, para la lista
--     de hitos de la obra y para el control 40
--     (fn_emision_factura_de_hito). Y SOLO SE FACTURA UN HITO PENDIENTE (la
--     regla de la app publicada: su 🧾 solo sale en un hito pendiente): uno
--     que la ficha ya tiene como «facturado» y que aquí no tiene ninguna
--     factura viva (se facturó en QuickBooks a mano, o su factura se anotó
--     sin su hito: en producción hay facturas de antes sin hito) NO se
--     factura otra vez: el borrador no se abre y uno ya abierto no se emite
--     (MX008, con qué hacer: si de verdad falta facturarlo, se pone antes en
--     pendiente —la ficha no tiene botón para eso: se avisa y se hace—; y si
--     lo que tiene es una factura suya ANULADA, dice cuál: ver «El hito que
--     sigue como facturado con su factura anulada»), y la lista de hitos de
--     la obra no lo ofrece. Antes solo se
--     frenaba el «cobrado»: el «facturado» sin factura enlazada salía con su
--     botón de facturar y sin un solo aviso (el ingreso, dos veces). Un hito
--     borrado y vuelto a crear es
--     OTRO hito: eso no se puede frenar (no hay con qué saber que es el
--     mismo), pero se dice: el borrador avisa si en la obra hay una factura
--     viva de un hito borrado, y si con esta factura lo facturado pasa del
--     contrato; el control 42 nombra la factura del hito borrado mientras a
--     la obra le queden hitos por facturar; y el control 44 dice si lo
--     facturado por hitos pasa de lo que suman los hitos de la obra.
--     (Durante el paralelo la función qb puede facturar por su lado un hito
--     que la app está emitiendo en ese mismo instante. Aquí no se le pone un
--     índice a facturas, que es de la app; en producción la app tiene los
--     suyos —ver «El hito que se vuelve a facturar»— y con ellos la segunda
--     no entra. En una base sin ellos, si pasa, el control 40 lo dice y
--     detiene el cierre.) Y UN HITO CUYA FACTURA SE ANULÓ SE VUELVE A
--     FACTURAR: la anulada suelta el hito al emitirse la que la sustituye, y
--     queda apuntado.
--   · A QUIÉN SE FACTURA lo dice la obra (el contratista si es por contrato
--     con él; si no, el cliente) y Edgar lo puede escribir en el borrador.
--     Si la obra cambia de destinatario después, el borrador lo dice y se
--     refresca; si solo difieren los datos, avisa y deja.
--   · EL «VISTO»: fn_emision_emitir pide la huella de lo que la pantalla
--     enseñó (como el «Así es» de c10). Una factura emitida no tiene vuelta
--     sin nota de crédito: se emite lo que Edgar vio, no lo que otra
--     pestaña dejó. La huella es de la VISTA PREVIA ENTERA (el documento,
--     sus líneas, los ajustes que salen en la factura, la fecha, el
--     ordinal, el contrato y lo facturado antes en la obra, lo retenido a
--     la fecha): lo que se congela es lo que se vio, salvo el número, y la
--     emisión lo comprueba otra vez al sellar. Dos emisiones a la vez en la
--     MISMA obra van de una en una (un candado por obra): la segunda ya no
--     es lo que se vio —cambiaron su ordinal y lo facturado antes— y para
--     con MX011; se refresca y se emite.
--   · TODO LO QUE VE EL CLIENTE VA EN INGLÉS. La base no sabe inglés: mira
--     si un texto PARECE español (palabras y signos) y entonces no emite
--     hasta que Edgar lo cambie o confirme que está bien así
--     (idioma_revisado). Es una ayuda, no una garantía.
--   · EL CORTE TIENE VUELTA ATRÁS mientras no haya una factura viva: solo
--     las emitidas y SIN ANULAR impiden poner el corte después de su fecha
--     (una emisión de prueba, anulada, no lo clava). Y mover el corte de
--     forma que cambie HOY por dónde se factura lo dice: fn_emision_config
--     devuelve un «aviso» (desde hoy el 🧾 ya no manda a QuickBooks; o
--     vuelve a mandar). v_emision_estado.corte_hasta es el último día en
--     que se puede poner.
--   · LO QUE NO HACE: no marca «pagada» (la casilla de la ficha es de
--     Edgar; desde el corte nadie la marca sola —antes lo hacía
--     QuickBooks—: el control 64 dice qué facturas de la app ya están
--     cobradas enteras en el libro y siguen sin marcar; quién la lleva
--     desde el corte está por decidir con la otra sesión, f15); no manda
--     correos ni habla con Stripe (la función de borde); no propone las
--     líneas T&M desde las horas (se escriben); no hace catálogo, SOV ni
--     paquete del GC (Fase 18).
--     NO HAY NOTA DE CRÉDITO PARCIAL (c3 la dejó «para la facturación de
--     f10»: queda fuera de esta versión): una factura con cobros aplicados
--     no se anula entera —primero se anula ese cobro en el libro—, y
--     rebajar una parte de una factura ya cobrada es un asiento del CPA.
--     Y NO LLEVA LA RETENCIÓN POR PAGAR A SUBCONTRATISTAS (la cuenta 2020):
--     no es de la emisión, y hoy no la lleva ninguna capa. Para llevarla
--     hacen falta dos cosas que no son de aquí: un campo en la app que diga
--     cuánto se le retiene a un sub en cada cuenta suya (y cuándo se le
--     suelta), y una versión del puente de gastos de c3 (sellado) que lo
--     asiente (Dr el costo / Cr 2020 al retener; Dr 2020 / Cr el banco al
--     pagar). Hasta entonces, lo retenido a un sub entra al costo el día
--     que se le paga, y el avance del WIP de esa obra va corto en ese
--     monto.
--
-- Lo que este archivo NO toca: c1..c10, s1, p1, es_dueno(), docs/sql, el
-- libro (ni una línea: el asiento es de c3), la función qb, correo ni
-- portal; ni los índices de facturas de la app (ux_facturas_hito y
-- ux_facturas_hito_viva: no los crea, no los quita y no depende de que
-- estén). De la app: inserta en facturas (como qb), le quita el hito a la
-- fila de facturas ANULADA que lo tenía cuando se emite la que la
-- sustituye (solo hito_id, y solo en una anulada) y mueve hitos.estado
-- (como el 🧾); lee proyectos, hitos, finanzas_proyecto, estimados,
-- contratistas (si existe) y perfiles. De c3 lee puente_cuentas,
-- puente_documentos, mapeo_tipo_proyecto y notas_credito; de p1, si está,
-- stripe_enlaces y stripe_pagos.
--
-- Cómo se instala (Edgar, en este orden):
--   1. SQL Editor → pegar ESTE archivo entero → Run. Al final sale una
--      tabla de doce filas: los ajustes, el corte y por dónde se factura
--      hoy, la serie, las tablas y las vistas, el bucket, el pago en línea,
--      VOLVER A FACTURAR UN HITO (si la base tiene el índice único de
--      facturas por hito que cuenta las anuladas, y que se maneja), QUÉ
--      FALTA (los datos de la empresa, el «How to pay»), el control y el
--      paso siguiente. Si algo de lo que da por hecho falta, para con
--      MX000 y no queda nada. Con la pantalla de Contabilidad cerrada: si
--      alguien la está leyendo, para con 55P03 y basta volver a pegarlo.
--   2. SQL Editor → volver a pegar docs/conta/c9-cierre.sql (el que trae
--      las filas 172 y 173: el cierre mira estos controles). Sin ese paso
--      el cierre no los mira, y la prueba del cierre sale «omitida». (Si el
--      c9 pegado ya las trae —la fila «el cierre del mes» del paso 1 lo
--      dice—, no hace falta: volver a pegar ESTE archivo no las quita.)
--   3. SQL Editor → pegar docs/conta/c11-pruebas.sql → sus filas en true
--      (las «omitida» dicen por qué).
--   4. En la app, Facturación → Ajustes: los datos de la empresa y el
--      «How to pay» (en inglés). Hasta el 31-dic el 🧾 sigue yendo a
--      QuickBooks; aquí se pueden preparar borradores para probar.
--
-- Lo que llama la pantalla y la función de borde (RPC, como el dueño; las
-- que escriben, con POST). Montos: numeric(14,2) en dólares; en el
-- contenido congelado, como texto de dos decimales («1111.11»):
--   fn_emision_config(p jsonb)                       los ajustes (devuelve
--                                                    además tarjeta_texto y,
--                                                    si toca, aviso)
--   fn_emision_obra(p jsonb)                         la retención de una obra
--   fn_emision_borrador(p jsonb)                     crear, cambiar o refrescar un borrador
--   fn_emision_documento(p_documento uuid)           solo lee: el documento entero
--                                                    (una emitida trae además
--                                                    sustituye: las anuladas a
--                                                    las que sustituyó en su
--                                                    hito, y sustituida_por: si
--                                                    es una anulada que soltó
--                                                    su hito, cuál la sustituyó)
--   fn_emision_descartar(p_documento uuid)           tirar un borrador
--   fn_emision_emitir(p_documento uuid, p_visto text, p_opciones jsonb)
--                                                    (devuelve además
--                                                    saltados y aviso si la
--                                                    serie saltó un número, y
--                                                    soltadas si una anulada
--                                                    soltó el hito)
--   fn_emision_anular(p_documento uuid, p_motivo text, p_fecha date)
--   fn_emision_pago(p_documento uuid)                solo lee: qué va a Stripe y qué enlace hay
--   fn_emision_pdf(p_documento uuid, p_archivo jsonb)
--   fn_emision_envio(p_documento uuid, p_envio jsonb)
-- Y lee: v_emision_estado, v_emision_documentos, v_emision_obras,
-- v_emision_control, emision_config.
-- Los avisos de un borrador (fn_emision_documento → avisos: [{codigo,
-- texto, frena}]) se pintan tal como llegan; el de esta revisión,
-- hito_factura_anulada, no frena (y no sale si el hito tiene una factura
-- viva, o si la ficha lo sigue teniendo como facturado: ahí el que sale, y
-- frena, es hito_facturado o hito_marcado_facturado, que nombra la anulada).
-- LO QUE LA PANTALLA DE HOY NO TIENE (se dice aquí para quien la toque): un
-- documento anulado en el libro y sin cerrar aquí le llega con estado
-- «anulada», y en una anulada la pantalla no ofrece «Anular»: cerrar esa
-- anulación (fn_emision_anular, que termina lo de aquí y devuelve el hito a
-- pendiente) hoy no tiene botón. Por eso los mensajes dicen «si ya sale
-- anulada y no ofrece el botón, avisa y se hace».
-- =====================================================================
-- (Lo primero, como en c4, c6, c9 y c10: el pegado espera un candado como
-- mucho medio segundo. Con la app leyendo o emitiendo, para con 55P03
-- («lock timeout»), no se aplica nada y se vuelve a pegar. Dura lo que
-- dura el pegado, una transacción.)
set local lock_timeout = '500ms';


-- ---------------------------------------------------------------------
-- 0. Las guardas, y lo que este archivo da por hecho (MX000 sin tocar nada)
-- ---------------------------------------------------------------------
-- Lo que falta para pegar c11, en llano (nulo = nada). La usan la
-- precondición de abajo y las pruebas.
create or replace function public.fn_emision_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
  v_v     bigint;
  c_tablas constant text[] := array['emision_config', 'emision_obras', 'emision_documentos', 'emision_lineas', 'emision_serie',
                                    'emision_pdfs', 'emision_envios', 'emision_soltados'];
  c_vistas constant text[] := array['v_emision_estado', 'v_emision_documentos', 'v_emision_obras', 'v_emision_control'];
  c_fn     constant text[] := array['fn_emision_precondiciones', 'fn_emision_exigir_dueno', 'fn_emision_ve', 'fn_emision_guarda',
                                    'fn_emision_numerar', 'fn_emision_usd', 'fn_emision_dia', 'fn_emision_numero', 'fn_emision_formato',
                                    'fn_emision_tarjeta_lista', 'fn_emision_tarjeta_texto', 'fn_emision_parece_espanol',
                                    'fn_emision_cuenta', 'fn_emision_saldo', 'fn_emision_retencion', 'fn_emision_retencion_de',
                                    'fn_emision_destinatario', 'fn_emision_enlaces', 'fn_emision_pagos', 'fn_emision_storage',
                                    'fn_emision_retenido', 'fn_emision_factura_de_hito', 'fn_emision_revisar', 'fn_emision_visto',
                                    'fn_emision_contenido', 'fn_emision_documento', 'fn_emision_borrador', 'fn_emision_descartar',
                                    'fn_emision_obra', 'fn_emision_config', 'fn_emision_emitir', 'fn_emision_anular', 'fn_emision_pago',
                                    'fn_emision_pdf', 'fn_emision_envio', 'fn_emision_control', 'fn_emision_pegado'];
begin
  foreach v_x in array array['es_dueno()', 'fn_desde_editor()', 'fn_fecha_miami(timestamptz)', 'fn_libro_version()',
                             'fn_verificar_cadena()', 'fn_factura_anular(bigint,text,date)'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'periodos', 'contadores', 'asientos', 'asiento_lineas', 'perfiles', 'proyectos', 'hitos',
                             'facturas', 'finanzas_proyecto', 'estimados', 'notas_credito', 'puente_documentos', 'puente_cuentas',
                             'mapeo_tipo_proyecto'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if cardinality(v_falta) > 0 then
    return format('c11 se pega después de c1, c2 y c3 (en producción, al final de la cadena: … c9, c10 y c11), con las tablas de la '
                  'app: falta %s.', array_to_string(v_falta, ', '));
  end if;
  -- La versión de c2 que va con esta capa (la del tiempo en producción).
  execute 'select public.fn_libro_version()' into v_v;
  if coalesce(v_v, 0) < 2026100201 then
    return format('el c2-libro.sql pegado es anterior (marca %s; esta capa pide 2026100201): vuelve a pegar c2-libro.sql.', v_v);
  end if;
  -- Las columnas de la app y de c3 que esta capa lee o escribe por su nombre.
  select string_agg(x.t || '.' || x.c, ', ' order by x.t, x.c) into v_x
    from (values ('facturas', 'id'), ('facturas', 'proyecto_id'), ('facturas', 'num'), ('facturas', 'fecha'), ('facturas', 'monto'),
                 ('facturas', 'pagada'), ('facturas', 'hito_id'), ('facturas', 'a_contratista'), ('facturas', 'estado'),
                 ('facturas', 'retencion'), ('facturas', 'contabilizado_en'),
                 ('hitos', 'id'), ('hitos', 'proyecto_id'), ('hitos', 'titulo'), ('hitos', 'condicion'), ('hitos', 'monto'),
                 ('hitos', 'estado'), ('hitos', 'orden'), ('hitos', 'es_deposito'),
                 ('proyectos', 'id'), ('proyectos', 'nombre'), ('proyectos', 'tipo'), ('proyectos', 'estado'), ('proyectos', 'cliente'),
                 ('finanzas_proyecto', 'proyecto_id'), ('finanzas_proyecto', 'contrato'),
                 ('estimados', 'id'), ('estimados', 'proyecto_id'), ('estimados', 'retencion_pct'), ('estimados', 'estado'),
                 ('perfiles', 'rol'), ('perfiles', 'activo'),
                 ('contadores', 'serie'), ('contadores', 'ultimo'),
                 ('asientos', 'origen_tabla'), ('asientos', 'origen_id'), ('asientos', 'reversa_a'), ('asientos', 'camino'),
                 ('asiento_lineas', 'partida_tabla'), ('asiento_lineas', 'partida_id'), ('asiento_lineas', 'cuenta'),
                 ('asiento_lineas', 'monto'),
                 ('notas_credito', 'numero'), ('notas_credito', 'anula_a'),
                 ('puente_documentos', 'tabla'), ('puente_documentos', 'documento_id'), ('puente_documentos', 'motivo'),
                 ('puente_cuentas', 'rol'), ('puente_cuentas', 'cuenta'),
                 ('mapeo_tipo_proyecto', 'tipo'), ('mapeo_tipo_proyecto', 'confirmado_el')) as x(t, c)
   where not exists (select 1 from information_schema.columns k
                      where k.table_schema = 'public' and k.table_name = x.t and k.column_name = x.c);
  if v_x is not null then
    return format('faltan columnas que esta capa lee: %s. ¿Es la base de la app, con c3 pegado?', v_x);
  end if;
  -- El puente de facturas de c3, diferido: la emisión lo adelanta dentro de
  -- su transacción para saber que la factura quedó en el libro.
  if not exists (select 1 from pg_trigger t
                  where t.tgrelid = 'public.facturas'::regclass and t.tgname = 'trg_puente_facturas_despues'
                    and t.tgconstraint <> 0 and t.tgdeferrable) then
    return 'falta el puente diferido de las facturas (trg_puente_facturas_despues, de c3): vuelve a pegar c3-puentes.sql.';
  end if;
  -- Las cuentas por cobrar de los puentes (1110 y 1120), dichas por c3.
  if (select count(*) from puente_cuentas pc join cuentas k on k.codigo = pc.cuenta
       where pc.rol in ('cxc', 'retencion_cxc')) < 2 then
    return 'faltan las cuentas por cobrar de los puentes (cxc y retencion_cxc en puente_cuentas, de c3): vuelve a pegar '
           'c3-puentes.sql.';
  end if;
  -- Una tabla con el nombre de las de c11 que no sea de c11: se para antes
  -- de tocar nada (la lección de c8 con ia_propuestas).
  foreach v_x in array array['emision_config:serie_formato', 'emision_obras:retencion_pct', 'emision_documentos:huella',
                             'emision_lineas:importe', 'emision_serie:secuencia', 'emision_pdfs:sha256',
                             'emision_envios:resend_id', 'emision_soltados:soltado_el'] loop
    if to_regclass('public.' || split_part(v_x, ':', 1)) is not null
       and not exists (select 1 from information_schema.columns
                        where table_schema = 'public' and table_name = split_part(v_x, ':', 1) and column_name = split_part(v_x, ':', 2)) then
      return format('la tabla %s ya existe en esta base y no es la de c11 (no tiene la columna %s): otra cosa usa ese nombre. No la '
                    'toco; avisa antes de seguir.', split_part(v_x, ':', 1), split_part(v_x, ':', 2));
    end if;
  end loop;
  -- Una vista o una función con nombre de c11 que no sea de c11 (otra sesión
  -- escribe esta misma base): «create or replace» la pisaría sin avisar.
  select string_agg(x.que, ', ' order by x.que) into v_x
    from (select 'la vista ' || c.relname as que
            from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind in ('v', 'm', 'r') and c.relname = any (c_vistas)
             and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c11: %'
          union all
          select 'la función ' || p.oid::regprocedure::text
            from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.proname = any (c_fn)
             and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c11: %') x;
  if v_x is not null then
    return format('ya hay en esta base, con nombre de c11 y sin ser de c11: %s. No lo piso; avisa antes de seguir.', v_x);
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: las facturas las emite el dueño.';
  end if;
  -- Nada ajeno colgado de las vistas de c11 (se borran y se rehacen).
  select string_agg(distinct format('la vista %s', dc.oid::regclass), ', ') into v_x
    from pg_depend d
    join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
    join pg_class dc on dc.oid = rw.ev_class
    join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
   where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname = any (c_vistas)
     and dc.oid <> cv.oid
     and not (dc.relnamespace = 'public'::regnamespace and dc.relname = any (c_vistas));
  if v_x is not null then
    return format('%s depende(n) de las vistas de c11, que al pegarlo se borran y se rehacen: guarda su definición, bórralas, '
                  'pega c11 y vuelve a crearlas.', v_x);
  end if;
  return null;
end $$;
revoke execute on function public.fn_emision_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_emision_precondiciones() is 'c11: lo que falta para pegar c11-emision.sql (nulo = nada): c1, c2 (marca 2026100201) y c3 con su puente diferido de facturas y sus cuentas por cobrar, las tablas y columnas de la app que lee o escribe, el SQL Editor, un dueño activo, nada ajeno con nombre de c11 y nada ajeno sobre sus vistas.';

do $$
declare
  v text;
begin
  v := public.fn_emision_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c11-emision NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1, c2, c3, c4, c6, c7, s1, p1, c8, c9, c10 y después este archivo (pruebas/conta/README.md, §0).';
  end if;
end $$;

-- ¿Quién llama por la API? Solo el dueño. Desde el SQL Editor (current_user
-- no es un rol de la API) pasa. Solo es_dueno(), como c4, c6, c9 y c10:
-- fn_desde_editor no es ejecutable por authenticated.
create or replace function public.fn_emision_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if current_user in ('authenticated', 'anon') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501',
      message = 'Las facturas las prepara, las emite y las ve solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_emision_exigir_dueno() from public, anon, service_role;
grant  execute on function public.fn_emision_exigir_dueno() to authenticated;
comment on function public.fn_emision_exigir_dueno() is 'c11: la guarda de lo que llama la pantalla: por la API solo el dueño (es_dueno); el SQL Editor pasa.';

-- ¿Ve quien mira? Lo mismo, sin error: las vistas y sus auxiliares no
-- frenan a nadie; a quien no es el dueño no le devuelven nada.
create or replace function public.fn_emision_ve() returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select current_user not in ('authenticated', 'anon', 'service_role') or coalesce(es_dueno(), false)
$$;
revoke execute on function public.fn_emision_ve() from public, anon, service_role;
grant  execute on function public.fn_emision_ve() to authenticated;
comment on function public.fn_emision_ve() is 'c11: verdadero para el dueño por la API y para el SQL Editor; las vistas y sus auxiliares no devuelven nada a los demás.';


-- ---------------------------------------------------------------------
-- 1. Las tablas (nacen cerradas: solo el dueño lee; escribe solo el dueño
--    por las funciones de aquí, con la marca de la transacción). Montos en
--    dólares, numeric(14,2). Llaves foráneas entre tablas de c11, a
--    cuentas, a asientos y a facturas (un documento emitido conserva su
--    factura); a proyectos y a hitos NO (son de la app: no se les cuelga
--    nada que cambie cómo se borran; lo que cambie después lo ve el
--    control). Para crecer, «add column if not exists».
-- ---------------------------------------------------------------------
-- Los ajustes: una sola fila.
--   corte           desde qué día se factura por la app (antes, QuickBooks)
--   serie_formato   cómo se escribe el número: AAAA es el año y NNNN el
--                   consecutivo del año (con ceros hasta cuatro cifras)
--   terminos_dias   0 = «Due on receipt»; N = vence a los N días
--   terminos_texto  el párrafo «Terms» de la factura (inglés; vacío)
--   empresa         lo que sale en el membrete: {nombre, licencia,
--                   direccion, telefono, correo, web} (vacío: lo pone Edgar)
--   como_pagar      el bloque «How to pay» (inglés; vacío: lo pone Edgar)
--   ach             ¿se ofrece pagar en línea por cuenta de banco (Stripe)?
--   tarjeta_pct     el % que cuesta pagar con tarjeta; nulo = no se ofrece
--                   (hoy no se deja poner: ver la cabecera)
--   cuenta_recargo  la cuenta a la que iría ese recargo (vacía)
--   pdf_dias        a los cuántos días avisa una factura sin PDF o sin mandar
create table if not exists public.emision_config (
  id               int           primary key,
  corte            date          not null default date '2027-01-01',
  serie_formato    text          not null default 'MXP-AAAA-NNNN',
  terminos_dias    int           not null default 0,
  terminos_texto   text          not null default '',
  empresa          jsonb         not null default '{}'::jsonb,
  como_pagar       text          not null default '',
  ach              boolean       not null default true,
  tarjeta_pct      numeric(5,3),
  cuenta_recargo   text          references public.cuentas (codigo),
  pdf_dias         int           not null default 2,
  actualizado      timestamptz   not null default now(),
  actualizado_por  uuid,
  constraint emision_config_una      check (id = 1),
  constraint emision_config_corte    check (corte >= date '2026-10-01'),
  constraint emision_config_formato  check (serie_formato ~ '^[A-Z0-9]{1,8}-AAAA-NNNN$'),
  constraint emision_config_terminos check (terminos_dias between 0 and 120 and length(terminos_texto) <= 2000),
  constraint emision_config_empresa  check (jsonb_typeof(empresa) = 'object'),
  constraint emision_config_pagar    check (length(como_pagar) <= 2000),
  constraint emision_config_tarjeta  check (tarjeta_pct is null or (tarjeta_pct > 0 and tarjeta_pct <= 10)),
  constraint emision_config_pdf_dias check (pdf_dias between 0 and 60)
);
comment on table public.emision_config is 'c11: los ajustes de la facturación (una fila): el corte (desde qué día se factura por la app; antes, por QuickBooks), el formato del número (serie_formato: MXP-AAAA-NNNN), los términos (terminos_dias: 0 = Due on receipt; terminos_texto), lo que sale en la factura de la empresa (empresa: {nombre, licencia, direccion, telefono, correo, web}) y el bloque «How to pay» (como_pagar) —vacíos hasta que Edgar los ponga—, si se ofrece pagar en línea por cuenta de banco (ach), el % de la tarjeta (tarjeta_pct: nulo = no se ofrece; hoy no se deja poner), la cuenta del recargo (cuenta_recargo) y a los cuántos días avisa una factura sin PDF o sin mandar (pdf_dias). Se cambia con fn_emision_config.';

-- Lo que Edgar fija de una obra para facturarla: su retención, en por
-- ciento (10 = 10 %). Nula = la del estimado enlazado (o ninguna); 0 = esta
-- obra no lleva retención aunque el estimado diga otra cosa.
create table if not exists public.emision_obras (
  proyecto_id      text          primary key,
  retencion_pct    numeric(5,2),
  nota             text,
  actualizado      timestamptz   not null default now(),
  actualizado_por  uuid,
  constraint emision_obras_retencion check (retencion_pct is null or (retencion_pct >= 0 and retencion_pct < 100)),
  constraint emision_obras_nota      check (nota is null or length(nota) <= 500)
);
comment on table public.emision_obras is 'c11: lo que Edgar fija de una obra para facturarla: su retención en por ciento (retencion_pct: 10 = 10 %; nula = la del estimado enlazado o ninguna; 0 = sin retención aunque el estimado diga otra cosa) y una nota. Se escribe con fn_emision_obra.';

-- El documento: un borrador o una factura emitida. forma: hito, porcentaje
-- (del contrato), tm (horas y material) o retencion (la que cobra lo
-- retenido: sin fila de facturas ni asiento). monto = la suma de sus
-- líneas; retencion = lo que el cliente retiene de ESTA factura (dólares);
-- a_pagar = monto − retencion. Emitido: su número, su fecha, su factura y
-- su asiento, el contenido congelado y su huella. Anulado: cuándo, quién,
-- por qué y con qué nota de crédito.
create table if not exists public.emision_documentos (
  id                uuid          primary key default gen_random_uuid(),
  estado            text          not null default 'borrador',
  forma             text          not null,
  proyecto_id       text          not null,
  hito_id           bigint,
  es_deposito       boolean       not null default false,
  porcentaje        numeric(7,4),
  base              numeric(14,2),
  a_contratista     boolean       not null default false,
  cliente           jsonb         not null default '{}'::jsonb,
  notas             text,
  retencion_pct     numeric(5,2)  not null default 0,
  retencion_origen  text          not null default 'ninguna',
  monto             numeric(14,2) not null default 0,
  retencion         numeric(14,2) not null default 0,
  a_pagar           numeric(14,2) not null default 0,
  numero            text,
  anio              int,
  secuencia         int,
  fecha             date,
  vence             date,
  factura_id        bigint        references public.facturas (id),
  asiento_id        uuid          references public.asientos (id),
  contenido         jsonb,
  huella            text,
  emitido_el        timestamptz,
  emitido_por       uuid,
  anulado_el        timestamptz,
  anulado_por       uuid,
  anulado_motivo    text,
  nota_credito      text,
  creado_el         timestamptz   not null default now(),
  creado_por        uuid,
  actualizado_el    timestamptz   not null default now(),
  actualizado_por   uuid,
  constraint emision_documentos_estado    check (estado in ('borrador', 'emitida')),
  constraint emision_documentos_forma     check (forma in ('hito', 'porcentaje', 'tm', 'retencion')),
  constraint emision_documentos_hito      check ((forma = 'hito') = (hito_id is not null)),
  constraint emision_documentos_pct       check ((forma = 'porcentaje') = (porcentaje is not null and base is not null)
                                                 and (porcentaje is null or (porcentaje > 0 and porcentaje <= 100))),
  constraint emision_documentos_cliente   check (jsonb_typeof(cliente) = 'object'),
  constraint emision_documentos_notas     check (notas is null or length(notas) <= 2000),
  constraint emision_documentos_ret_pct   check (retencion_pct >= 0 and retencion_pct < 100
                                                 and retencion_origen in ('obra', 'estimado', 'borrador', 'ninguna')),
  constraint emision_documentos_montos    check (monto >= 0 and retencion >= 0 and a_pagar = monto - retencion and a_pagar >= 0),
  constraint emision_documentos_ret_forma check (forma <> 'retencion' or (retencion = 0 and retencion_pct = 0)),
  constraint emision_documentos_emitida   check ((estado = 'emitida') = (numero is not null)
                                                 and (estado = 'emitida') = (anio is not null and secuencia is not null)
                                                 and (estado = 'emitida') = (fecha is not null and vence is not null)
                                                 and (estado = 'emitida') = (contenido is not null and huella is not null)
                                                 and (estado = 'emitida') = (emitido_el is not null)),
  constraint emision_documentos_huella    check (huella is null or huella ~ '^[0-9a-f]{64}$'),
  constraint emision_documentos_factura   check (factura_id is null or (estado = 'emitida' and forma <> 'retencion')),
  constraint emision_documentos_en_libro  check (estado = 'borrador' or forma = 'retencion'
                                                 or (factura_id is not null and asiento_id is not null)),
  constraint emision_documentos_anulado   check ((anulado_el is null) = (anulado_motivo is null)
                                                 and (anulado_el is null or estado = 'emitida')
                                                 and (nota_credito is null or anulado_el is not null)),
  constraint emision_documentos_numero_unico  unique (numero),
  constraint emision_documentos_factura_unica unique (factura_id)
);
create index if not exists emision_documentos_obra_idx on public.emision_documentos (proyecto_id);
create index if not exists emision_documentos_hito_idx on public.emision_documentos (hito_id) where hito_id is not null;
-- (un hito, un borrador: tocar 🧾 dos veces abre el mismo; y una obra, un
-- borrador de retención)
create unique index if not exists emision_documentos_hito_borrador on public.emision_documentos (hito_id)
  where estado = 'borrador' and hito_id is not null;
create unique index if not exists emision_documentos_ret_borrador on public.emision_documentos (proyecto_id)
  where estado = 'borrador' and forma = 'retencion';
-- (cada serie, sus números: las facturas llevan la del año y la factura de la
-- retención la suya, así que el consecutivo es único DENTRO de su serie. La
-- restricción «un consecutivo por año» de una versión anterior de este
-- archivo se quita; al volver a pegar no cambia nada)
alter table public.emision_documentos drop constraint if exists emision_documentos_serie_unica;
create unique index if not exists emision_documentos_serie_idx on public.emision_documentos ((forma = 'retencion'), anio, secuencia)
  where anio is not null;
comment on table public.emision_documentos is 'c11: cada factura que se prepara o se emite desde la app: su estado (borrador o emitida), su forma (hito, porcentaje del contrato, tm = horas y material, o retencion = la que cobra lo retenido, sin fila de facturas ni asiento), la obra, el hito y si es el de depósito, el porcentaje y el contrato que usó de base, a quién se factura (cliente: {nombre, atencion, direccion, correo}; a_contratista), las notas al cliente, la retención (retencion_pct y de dónde salió: obra, estimado, borrador o ninguna), el monto (la suma de sus líneas), lo retenido de esta factura en dólares (retencion) y lo que se paga ahora (a_pagar = monto − retencion). Emitida: su número de su serie del año (numero, anio, secuencia: las facturas, MXP-2027-0001; la factura de la retención, la suya, MXP-R-2027-0001), su fecha y su vencimiento, su fila de facturas y el asiento que puso c3, el contenido congelado de lo que recibe el cliente (contenido) y su huella sha256, quién y cuándo. Anulada: cuándo, quién, por qué y su nota de crédito. Un borrador se cambia con fn_emision_borrador; emitido, no cambia.';
comment on column public.emision_documentos.contenido is 'El documento entero como lo recibe el cliente, congelado al emitir: {v, forma, numero, fecha, vence, terminos, empresa, cliente, obra, lineas, totales, contrato, como_pagar, pago_en_linea, referencias (la de la retención: las facturas cuya retención reclama), notas…}. Los montos van como texto de dos decimales. El PDF se pinta de aquí y de nada más.';
comment on column public.emision_documentos.huella is 'sha256 (hexadecimal) del texto de contenido: lo que ata cada PDF al documento congelado.';

-- Las líneas de un documento: descripción (en inglés), cantidad, precio e
-- importe. importe = round(cantidad × precio, 2), siempre; el monto del
-- documento es su suma. tipo: hito, porcentaje, horas, material, otro, o
-- retencion (lo retenido de una factura: ref dice cuál).
create table if not exists public.emision_lineas (
  documento_id  uuid          not null references public.emision_documentos (id),
  n             int           not null,
  tipo          text          not null,
  descripcion   text          not null,
  detalle       text,
  cantidad      numeric       not null default 1,
  unidad        text,
  precio        numeric       not null,
  importe       numeric(14,2) not null,
  ref           jsonb,
  constraint emision_lineas_pk       primary key (documento_id, n),
  constraint emision_lineas_n        check (n >= 1),
  constraint emision_lineas_tipo     check (tipo in ('hito', 'porcentaje', 'horas', 'material', 'otro', 'retencion')),
  constraint emision_lineas_texto    check (btrim(descripcion) <> '' and length(descripcion) <= 500
                                            and (detalle is null or length(detalle) <= 1000)
                                            and (unidad is null or length(unidad) <= 20)),
  constraint emision_lineas_cantidad check (cantidad > 0 and scale(cantidad) <= 4 and scale(precio) <= 4),
  constraint emision_lineas_importe  check (importe = round(cantidad * precio, 2) and importe <> 0),
  constraint emision_lineas_ref      check (ref is null or jsonb_typeof(ref) = 'object')
);
comment on table public.emision_lineas is 'c11: las líneas de cada documento, en su orden (n): el tipo (hito, porcentaje, horas, material, otro, o retencion = lo retenido de una factura), la descripción y el detalle (en inglés: lo ve el cliente), la cantidad, la unidad, el precio y el importe (= round(cantidad × precio, 2)); ref dice de qué sale (el hito, la factura retenida). El monto del documento es la suma de sus importes. Solo cambian mientras el documento es un borrador.';

-- Las series: un número por fila, por serie y año, seguido y sin huecos. Son
-- DOS: «facturas» (MXP-2027-0001: toda fila de facturas que emite la app
-- lleva uno, y cada número de esa serie es una fila de facturas) y
-- «retenciones» (MXP-R-2027-0001: la factura de la retención, que no es una
-- fila de facturas ni tiene asiento, lleva la suya para no dejar huecos en
-- la de las facturas). El número lo pone el trigger de esta tabla desde
-- contadores («facturas-AAAA» y «retenciones-AAAA»).
create table if not exists public.emision_serie (
  serie         text         not null default 'facturas',
  anio          int          not null,
  secuencia     int          not null,
  numero        text         not null,
  documento_id  uuid         not null references public.emision_documentos (id),
  creado_el     timestamptz  not null default now(),
  creado_por    uuid,
  constraint emision_serie_pk        primary key (serie, anio, secuencia),
  constraint emision_serie_cual      check (serie in ('facturas', 'retenciones')),
  constraint emision_serie_anio      check (anio between 2026 and 2999 and secuencia >= 1),
  constraint emision_serie_numero    unique (numero),
  constraint emision_serie_documento unique (documento_id)
);
-- (la columna «serie» y su llave, también sobre una tabla de una versión
-- anterior de este archivo; al volver a pegar no cambia nada)
do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'emision_serie' and column_name = 'serie') then
    alter table public.emision_serie add column serie text not null default 'facturas';
    alter table public.emision_serie add constraint emision_serie_cual check (serie in ('facturas', 'retenciones'));
    alter table public.emision_serie drop constraint emision_serie_pk;
    alter table public.emision_serie add constraint emision_serie_pk primary key (serie, anio, secuencia);
  end if;
end $$;
comment on table public.emision_serie is 'c11: las series de la facturación: una fila por número, por serie (facturas: MXP-2027-0001, la de las facturas, que son filas de facturas; retenciones: MXP-R-2027-0001, la de la factura de la retención, que no lo es) y año (anio, secuencia), con su número escrito y el documento que lo lleva. El consecutivo lo pone el trigger de esta tabla desde contadores (series facturas-AAAA y retenciones-AAAA) en la misma transacción que emite: una emisión que falla no gasta número. Solo se añade.';

-- Cada PDF de un documento emitido (n: 1, 2, 3…; el último es el que vale):
-- dónde está en el bucket «facturas», su sha256, su tamaño, de qué
-- contenido se pintó (huella) y qué enlace de pago llevaba impreso.
create table if not exists public.emision_pdfs (
  id            uuid         primary key default gen_random_uuid(),
  documento_id  uuid         not null references public.emision_documentos (id),
  n             int          not null,
  ruta          text         not null,
  sha256        text         not null,
  bytes         bigint       not null,
  huella        text         not null,
  pago          jsonb        not null default '{}'::jsonb,
  creado_el     timestamptz  not null default now(),
  creado_por    uuid,
  constraint emision_pdfs_n      unique (documento_id, n),
  constraint emision_pdfs_ruta   unique (ruta),
  constraint emision_pdfs_forma  check (n >= 1 and sha256 ~ '^[0-9a-f]{64}$' and huella ~ '^[0-9a-f]{64}$' and bytes > 0
                                        and jsonb_typeof(pago) = 'object')
);
comment on table public.emision_pdfs is 'c11: cada PDF de una factura emitida, en el bucket privado «facturas»: su versión (n; el último es el que vale), su ruta, su sha256 y su tamaño, la huella del contenido del que se pintó (la del documento) y el enlace de pago que llevaba impreso (pago: {enlace_id, url, metodos, monto}). Solo se añade: un PDF nuevo es otra fila, con otra ruta.';

-- Cada envío de una factura emitida: por correo (con el id de Resend) o en
-- mano. n = 1 es el primer envío; los siguientes, reenvíos.
create table if not exists public.emision_envios (
  id            uuid         primary key default gen_random_uuid(),
  documento_id  uuid         not null references public.emision_documentos (id),
  n             int          not null,
  medio         text         not null default 'correo',
  pdf_id        uuid         references public.emision_pdfs (id),
  para          text         not null,
  cc            text,
  asunto        text,
  resend_id     text,
  nota          text,
  enviado_el    timestamptz  not null default now(),
  enviado_por   uuid,
  constraint emision_envios_n      unique (documento_id, n),
  constraint emision_envios_resend unique (resend_id),
  constraint emision_envios_medio  check (medio in ('correo', 'en_mano')),
  constraint emision_envios_forma  check (n >= 1 and btrim(para) <> '' and length(para) <= 500
                                          and (medio = 'en_mano' or (resend_id is not null and pdf_id is not null)))
);
create index if not exists emision_envios_documento_idx on public.emision_envios (documento_id);
comment on table public.emision_envios is 'c11: cada envío de una factura emitida: el medio (correo o en_mano), a quién (para, cc), el asunto, el PDF que se mandó, el id de Resend, una nota, cuándo y quién. n = 1 es el primer envío; los demás, reenvíos. Solo se añade.';

-- LO SOLTADO (cabecera, «El hito que se vuelve a facturar»): cada fila de
-- facturas ANULADA que dejó de apuntar a su hito (facturas.hito_id pasó a
-- nulo) porque se emitió la factura que la sustituye. Una fila por anulada y
-- por emisión: qué factura era (su id, su número, su obra, su nota de
-- crédito, y si salió de la app o de fuera —QuickBooks—), qué hito tenía,
-- qué documento la soltó al emitirse, cuándo y quién. Es donde queda la
-- historia: en facturas ya no se ve de qué hito fue la anulada.
-- SIN llave hacia facturas ni hacia hitos, a propósito: es un apunte, y no
-- cambia cómo se borran las filas de la app (una anulada que nunca entró al
-- libro se sigue pudiendo borrar; su apunte se queda, con su número).
create table if not exists public.emision_soltados (
  id            uuid         primary key default gen_random_uuid(),
  factura_id    bigint       not null,
  num           text         not null,
  hito_id       bigint       not null,
  proyecto_id   text,
  nota_credito  text,
  de_la_app     boolean      not null default false,
  documento_id  uuid         not null references public.emision_documentos (id),
  soltado_el    timestamptz  not null default now(),
  soltado_por   uuid,
  constraint emision_soltados_una unique (factura_id, documento_id)
);
create index if not exists emision_soltados_documento_idx on public.emision_soltados (documento_id);
create index if not exists emision_soltados_hito_idx on public.emision_soltados (hito_id);
comment on table public.emision_soltados is 'c11: cada factura ANULADA que dejó de apuntar a su hito (su facturas.hito_id pasó a nulo) al emitirse la factura que la sustituye: la anulada (factura_id, num, proyecto_id, su nota_credito si la tiene, de_la_app: si la había emitido la app o era de fuera —QuickBooks—), el hito que tenía (hito_id), el documento que la soltó al emitirse (documento_id), cuándo y quién. La anulada sigue anulada, con su nota de crédito y su asiento: solo deja de figurar como la factura de ese hito, para que la nueva pueda llevarlo (la base de la app admite una sola fila de facturas por hito). La escribe fn_emision_emitir. Solo se añade.';


-- ---------------------------------------------------------------------
-- 2. La guarda de las tablas de c11 (la de c6, c9 y c10, en su forma): solo
--    se escriben con la marca de la transacción (mx_emision.escribe = el
--    nombre de la tabla), que ponen las funciones de aquí justo antes de
--    escribir y quitan después. Un insert o un update a mano —desde
--    PostgREST, aunque sea el dueño, o desde el SQL Editor sin la marca— da
--    MX003. Y lo emitido no se edita ni se borra. SECURITY INVOKER, sin
--    grant a nadie (la dispara la tabla).
-- ---------------------------------------------------------------------
create or replace function public.fn_emision_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_marca text := coalesce(current_setting('mx_emision.escribe', true), '');
  v_est   text;
  c_anula constant text[] := array['anulado_el', 'anulado_por', 'anulado_motivo', 'nota_credito'];
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003',
      message = format('%s no se trunca: es el rastro de las facturas.', tg_table_name);
  end if;
  if v_marca <> tg_table_name then
    raise exception using errcode = 'MX003',
      message = format('%s se escribe solo desde las funciones de facturación (%s), no a mano.', tg_table_name,
                       case tg_table_name
                         when 'emision_config' then 'fn_emision_config'
                         when 'emision_obras' then 'fn_emision_obra'
                         when 'emision_documentos' then 'fn_emision_borrador, fn_emision_emitir y fn_emision_anular'
                         when 'emision_lineas' then 'fn_emision_borrador'
                         when 'emision_serie' then 'fn_emision_emitir'
                         when 'emision_soltados' then 'fn_emision_emitir'
                         when 'emision_pdfs' then 'fn_emision_pdf'
                         else 'fn_emision_envio' end);
  end if;
  if tg_table_name in ('emision_config', 'emision_obras') then
    if tg_op = 'DELETE' then
      raise exception using errcode = 'MX003',
        message = format('%s no se borra: se cambia con su función.', tg_table_name);
    end if;
    return new;
  end if;
  if tg_table_name = 'emision_documentos' then
    if tg_op = 'INSERT' then
      if new.estado <> 'borrador' then
        raise exception using errcode = 'MX003', message = 'Una factura nace en borrador y se emite con fn_emision_emitir.';
      end if;
      return new;
    end if;
    if old.estado <> 'borrador' then
      -- Emitida: no se borra, y lo único que le pasa es anularse, una vez.
      if tg_op = 'DELETE' then
        raise exception using errcode = 'MX003',
          message = format('La factura %s ya se emitió: no se borra. Se anula con su nota de crédito y se hace la buena.', old.numero);
      end if;
      if old.anulado_el is not null or new.anulado_el is null
         or (to_jsonb(new) - c_anula) is distinct from (to_jsonb(old) - c_anula) then
        raise exception using errcode = 'MX003',
          message = format('La factura %s ya se emitió: no cambia. Si está mal, se anula con su nota de crédito (una vez) y se hace '
                           'la buena.', old.numero);
      end if;
      return new;
    end if;
    if tg_op = 'DELETE' then
      return old;
    end if;
    if new.id is distinct from old.id then
      raise exception using errcode = 'MX003', message = 'Un borrador no cambia de identidad.';
    end if;
    return new;
  end if;
  if tg_table_name = 'emision_lineas' then
    if tg_op = 'UPDATE' and new.documento_id is distinct from old.documento_id then
      raise exception using errcode = 'MX003', message = 'Una línea no cambia de documento.';
    end if;
    select d.estado into v_est from emision_documentos d
     where d.id = case when tg_op = 'DELETE' then old.documento_id else new.documento_id end;
    if v_est is distinct from 'borrador' then
      raise exception using errcode = 'MX003',
        message = 'Las líneas de una factura emitida no cambian: se anula con su nota de crédito y se hace la buena.';
    end if;
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;
  -- emision_serie, emision_pdfs, emision_envios y emision_soltados: solo se añaden.
  if tg_op <> 'INSERT' then
    raise exception using errcode = 'MX003',
      message = format('%s no se edita ni se borra: %s.', tg_table_name,
                       case tg_table_name
                         when 'emision_serie' then 'un número dado no se quita ni se cambia'
                         when 'emision_pdfs' then 'un PDF nuevo es otra fila, con otra ruta'
                         when 'emision_soltados' then 'es el apunte de qué factura anulada dejó de figurar en qué hito'
                         else 'un reenvío es otra fila' end);
  end if;
  return new;
end $$;
revoke execute on function public.fn_emision_guarda() from public, anon, authenticated, service_role;
comment on function public.fn_emision_guarda() is 'c11: la guarda de las tablas de c11: se escriben solo con la marca de la transacción (mx_emision.escribe) que ponen sus funciones; un documento emitido no se borra ni cambia (solo se le apunta su anulación, una vez); sus líneas cambian solo en borrador; la serie, los PDF, los envíos y lo soltado solo se añaden; nada se trunca.';

-- EL NÚMERO: el trigger de emision_serie. Toma el contador del año en la
-- tabla contadores de c2 (serie «facturas-AAAA», o «retenciones-AAAA» para
-- la factura de la retención: su fila, con «for update»: dos emisiones a la
-- vez se esperan), lo sube de uno en uno —la guarda de contadores no deja
-- otra cosa— y escribe el consecutivo y el número. Todo dentro de la
-- transacción que emite: si algo falla después, el contador vuelve atrás
-- con lo demás y no queda hueco.
-- UN NÚMERO QUE YA LLEVA OTRA FACTURA NO SE DA DOS VECES: si una fila de
-- facturas —de la obra que sea, hecha fuera de la app— ya tiene escrito el
-- número que toca, la serie lo SALTA y da el siguiente (en facturas no queda
-- hueco: ese número lo lleva aquella; la emisión lo dice y el control 20 lo
-- sabe). Antes solo se miraba la misma obra: en otra salían dos facturas con
-- el mismo número, y en la misma la emisión se quedaba trancada.
-- SECURITY DEFINER porque contadores es del libro: la API solo la lee
-- (c2, «permisos»). Es la única de la capa. Devuelve «trigger»: Postgres no
-- deja llamarla suelta; y sin EXECUTE para nadie. Solo corre al insertar en
-- emision_serie, que pide la marca de fn_emision_emitir (la guarda de
-- arriba corre antes: los triggers van por orden de nombre).
create or replace function public.fn_emision_numerar()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_serie text;
  v_n     bigint;
  v_fmt   text;
  v_num   text;
  v_i     int := 0;
begin
  if new.anio is null or new.anio < 2026 or new.anio > 2999 then
    raise exception using errcode = '22023', message = format('El año de la serie no vale (%s).', coalesce(new.anio::text, 'ninguno'));
  end if;
  if new.serie is null or new.serie not in ('facturas', 'retenciones') then
    raise exception using errcode = '22023', message = format('La serie no vale (%s).', coalesce(new.serie, 'ninguna'));
  end if;
  v_serie := new.serie || '-' || new.anio;
  select c.serie_formato into v_fmt from emision_config c where c.id = 1;
  v_fmt := fn_emision_formato(coalesce(v_fmt, 'MXP-AAAA-NNNN'), new.serie);
  insert into contadores (serie, ultimo) values (v_serie, 0) on conflict (serie) do nothing;
  loop
    select c.ultimo + 1 into v_n from contadores c where c.serie = v_serie for update;
    update contadores set ultimo = v_n where serie = v_serie;
    v_num := fn_emision_numero(v_fmt, new.anio, v_n::int);
    exit when not exists (select 1 from facturas f where f.num = v_num);
    v_i := v_i + 1;
    if v_i >= 50 then
      raise exception using errcode = 'MX008',
        message = format('No se emitió nada: los 50 números siguientes de la serie (hasta el %s) ya los llevan facturas hechas fuera de la '
                         'app. Eso no es normal: avisa antes de seguir.', v_num);
    end if;
  end loop;
  new.secuencia := v_n;
  new.numero    := v_num;
  return new;
end $$;
revoke execute on function public.fn_emision_numerar() from public, anon, authenticated, service_role;
comment on function public.fn_emision_numerar() is 'c11: el trigger que da el número de la serie (emision_serie): sube de uno en uno el contador del año en contadores (c2: serie facturas-AAAA, o retenciones-AAAA para la factura de la retención) y escribe el consecutivo y el número con el formato de los ajustes; un número que ya lleva una fila de facturas hecha fuera de la app se salta (no se da dos veces). SECURITY DEFINER (contadores es del libro) y, por ser de trigger, nadie la puede llamar suelta; sin EXECUTE para nadie.';

do $$
declare
  t text;
begin
  foreach t in array array['emision_config', 'emision_obras', 'emision_documentos', 'emision_lineas', 'emision_serie', 'emision_pdfs',
                           'emision_envios', 'emision_soltados'] loop
    execute format('create or replace trigger trg_%s_guarda before insert or update or delete on public.%I '
                   'for each row execute function public.fn_emision_guarda()', t, t);
    execute format('create or replace trigger trg_%s_sin_truncate before truncate on public.%I '
                   'for each statement execute function public.fn_emision_guarda()', t, t);
  end loop;
end $$;
-- (por orden de nombre va después de trg_emision_serie_guarda)
create or replace trigger trg_emision_serie_numerar before insert on public.emision_serie
  for each row execute function public.fn_emision_numerar();


-- ---------------------------------------------------------------------
-- 3. Los permisos: RLS, «solo el dueño lee», y en las tablas que escribe
--    una función INVOKER, la policy de escritura del dueño (con la guarda
--    de arriba delante: la policy dice quién, la marca dice por dónde).
--    anon y service_role, nada. Por la API solo se borra un borrador y sus
--    líneas (fn_emision_descartar, fn_emision_borrador).
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array['emision_config', 'emision_obras', 'emision_documentos', 'emision_lineas', 'emision_serie', 'emision_pdfs',
                           'emision_envios', 'emision_soltados'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
  foreach t in array array['emision_config', 'emision_obras', 'emision_documentos', 'emision_lineas'] loop
    execute format('create policy %I on public.%I for update to authenticated using ((select es_dueno())) with check ((select es_dueno()))',
                   t || '_dueno_edita', t);
    execute format('grant update on public.%I to authenticated', t);
  end loop;
  foreach t in array array['emision_obras', 'emision_documentos', 'emision_lineas', 'emision_serie', 'emision_pdfs', 'emision_envios',
                           'emision_soltados'] loop
    execute format('create policy %I on public.%I for insert to authenticated with check ((select es_dueno()))',
                   t || '_dueno_anade', t);
    execute format('grant insert on public.%I to authenticated', t);
  end loop;
  foreach t in array array['emision_documentos', 'emision_lineas'] loop
    execute format('create policy %I on public.%I for delete to authenticated using ((select es_dueno()))', t || '_dueno_borra', t);
    execute format('grant delete on public.%I to authenticated', t);
  end loop;
end $$;

-- La fila de los ajustes (con la marca de la guarda): al volver a pegar no
-- se pisa nada.
do $$
begin
  if not exists (select 1 from public.emision_config where id = 1) then
    perform set_config('mx_emision.escribe', 'emision_config', true);
    insert into public.emision_config (id) values (1);
    perform set_config('mx_emision.escribe', '', true);
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 4. Lo común: dinero y fechas en llano, el número, las cuentas por cobrar
--    de c3, lo que una factura debe en el libro, la regla de la retención,
--    a quién se le factura una obra, y lo de p1 y de Storage que se lee si
--    están. Todo SECURITY INVOKER; lo que usan las funciones de la pantalla
--    y las vistas lleva EXECUTE para authenticated.
-- ---------------------------------------------------------------------
-- Las vistas de c11 se borran aquí y se rehacen al final (en este mismo
-- pegado): así una función que cambie puede volver a crearse.
drop view if exists public.v_emision_estado, public.v_emision_documentos, public.v_emision_obras, public.v_emision_control;

-- Dólares como se leen: $1,234.56 (negativo con su signo).
create or replace function public.fn_emision_usd(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null then '—'
              when p < 0 then '-$' || to_char(-p, 'FM999,999,999,990.00')
              else '$' || to_char(p, 'FM999,999,999,990.00') end
$$;
revoke execute on function public.fn_emision_usd(numeric) from public, anon, service_role;
grant  execute on function public.fn_emision_usd(numeric) to authenticated;
comment on function public.fn_emision_usd(numeric) is 'c11: un monto en dólares como se lee ($1,234.56).';

-- Un día como se lee en la app: 1-ene-2027.
create or replace function public.fn_emision_dia(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null then '(sin fecha)'
              else extract(day from p)::int || '-'
                   || (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int]
                   || '-' || extract(year from p)::int end
$$;
revoke execute on function public.fn_emision_dia(date) from public, anon, service_role;
grant  execute on function public.fn_emision_dia(date) to authenticated;
comment on function public.fn_emision_dia(date) is 'c11: un día como se lee (1-ene-2027).';

-- El número escrito: en el formato, AAAA es el año y NNNN el consecutivo
-- (con ceros hasta cuatro cifras; del 10000 en adelante, las que tenga:
-- lpad recortaría, y dos facturas saldrían con el mismo número).
create or replace function public.fn_emision_numero(p_formato text, p_anio int, p_secuencia int) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select replace(replace(coalesce(p_formato, 'MXP-AAAA-NNNN'), 'AAAA', p_anio::text), 'NNNN',
                 case when p_secuencia >= 1000 then p_secuencia::text else lpad(p_secuencia::text, 4, '0') end)
$$;
revoke execute on function public.fn_emision_numero(text, int, int) from public, anon, service_role;
grant  execute on function public.fn_emision_numero(text, int, int) to authenticated;
comment on function public.fn_emision_numero(text, int, int) is 'c11: el número de una factura escrito con el formato de los ajustes (MXP-AAAA-NNNN → MXP-2027-0001).';

-- ¿Se puede encender la tarjeta? Hoy NO: p1 (sellado) deja el recargo de un
-- pago con tarjeta de anticipo de la obra, no en una cuenta de ingreso
-- (cabecera, «El pago en línea»; c11-pruebas, la 32). Mientras esto diga
-- «no», fn_emision_config no deja poner el porcentaje y nada ofrece tarjeta.
-- Se cambia aquí, en una versión de este archivo, el día que p1 sepa
-- registrar un recargo.
create or replace function public.fn_emision_tarjeta_lista() returns boolean
language sql immutable
set search_path = public, pg_temp
as $$ select false $$;
revoke execute on function public.fn_emision_tarjeta_lista() from public, anon, service_role;
grant  execute on function public.fn_emision_tarjeta_lista() to authenticated;
comment on function public.fn_emision_tarjeta_lista() is 'c11: si el libro ya sabe registrar un pago con tarjeta con su recargo. Hoy no (p1 lo dejaría de anticipo de la obra): la tarjeta queda apagada y el porcentaje no se deja poner.';

-- El formato del número de cada serie: el de los ajustes (MXP-AAAA-NNNN) para
-- las facturas; para la factura de la retención, el mismo con una R detrás
-- del prefijo (MXP-R-AAAA-NNNN).
create or replace function public.fn_emision_formato(p_formato text, p_serie text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p_serie = 'retenciones' then replace(coalesce(p_formato, 'MXP-AAAA-NNNN'), '-AAAA-', '-R-AAAA-')
              else coalesce(p_formato, 'MXP-AAAA-NNNN') end
$$;
revoke execute on function public.fn_emision_formato(text, text) from public, anon, service_role;
grant  execute on function public.fn_emision_formato(text, text) to authenticated;
comment on function public.fn_emision_formato(text, text) is 'c11: el formato del número de una serie: el de los ajustes para las facturas (MXP-AAAA-NNNN) y, para la factura de la retención, el mismo con una R detrás del prefijo (MXP-R-AAAA-NNNN).';

-- POR QUÉ LA TARJETA ESTÁ APAGADA, en llano (decisión de Edgar del
-- 12-nov-2026: por ahora solo ACH). Lo dicen los ajustes, el pago de una
-- factura, el control y v_emision_estado: un solo texto.
create or replace function public.fn_emision_tarjeta_texto() returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select 'La tarjeta está apagada: se enciende cuando el sistema de cobros sepa registrar el recargo (hoy lo dejaría como un anticipo de '
         'la obra, no como un ingreso). Por ahora el pago en línea es solo por cuenta de banco (ACH), y la factura no le ofrece tarjeta '
         'al cliente.'::text
$$;
revoke execute on function public.fn_emision_tarjeta_texto() from public, anon, service_role;
grant  execute on function public.fn_emision_tarjeta_texto() to authenticated;
comment on function public.fn_emision_tarjeta_texto() is 'c11: por qué la tarjeta está apagada, en llano (decisión del 12-nov-2026: por ahora solo ACH; se enciende cuando el sistema de cobros sepa registrar el recargo). Un solo texto para los ajustes, el pago, el control y la pantalla.';

-- ¿Parece español? Una ayuda, no una garantía: lo que ve el cliente va en
-- inglés. Verdad si trae ¿ o ¡, una palabra de obra en español, o tres o
-- más palabras sueltas de las que el inglés casi no usa.
create or replace function public.fn_emision_parece_espanol(p text) returns boolean
language sql immutable
set search_path = public, pg_temp
as $$
  select p is not null
     and (   p ~ '[¿¡]'
          or lower(p) ~ ('\m(trabajos?|inspecci[oó]n|instalaci[oó]n|dep[oó]sito|facturas?|a[ñn]adido|aprobad[oa]|el[eé]ctric[oa]s?|'
                         || 'terminar|terminad[oa]|firmar|seg[uú]n|hasta|pagar|cobro|obra|avance|anticipo|retenci[oó]n|cambio|'
                         || 'materiales|horas|tuber[ií]a|tablero|cableado|luminarias?|pendiente|incluye|entrega)\M')
          or (select count(*) from regexp_matches(lower(p), '\m(el|la|los|las|del|de|con|sin|para|por|al|y|en|un|una|que|se)\M', 'g')) >= 3)
$$;
revoke execute on function public.fn_emision_parece_espanol(text) from public, anon, service_role;
grant  execute on function public.fn_emision_parece_espanol(text) to authenticated;
comment on function public.fn_emision_parece_espanol(text) is 'c11: si un texto parece español (¿ o ¡, una palabra de obra en español, o tres palabras sueltas del español). Una ayuda para que lo que ve el cliente vaya en inglés; no una garantía.';

-- La cuenta de un papel de los puentes (c3, puente_cuentas): «cxc» es la de
-- cobrar (1110) y «retencion_cxc» la de la retención por cobrar (1120).
create or replace function public.fn_emision_cuenta(p_rol text) returns text
language sql stable
set search_path = public, pg_temp
as $$ select pc.cuenta from public.puente_cuentas pc where pc.rol = p_rol $$;
revoke execute on function public.fn_emision_cuenta(text) from public, anon, service_role;
grant  execute on function public.fn_emision_cuenta(text) to authenticated;
comment on function public.fn_emision_cuenta(text) is 'c11: la cuenta que c3 usa para un papel (puente_cuentas): cxc (1110) o retencion_cxc (1120).';

-- Lo que una factura debe hoy en el LIBRO: su partida en la cuenta por
-- cobrar (cxc) y en la retención por cobrar (retencion).
create or replace function public.fn_emision_saldo(p_factura bigint)
returns table (cxc numeric, retencion numeric)
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(sum(l.monto) filter (where l.cuenta = (select public.fn_emision_cuenta('cxc'))), 0)::numeric(14,2),
         coalesce(sum(l.monto) filter (where l.cuenta = (select public.fn_emision_cuenta('retencion_cxc'))), 0)::numeric(14,2)
    from public.asiento_lineas l
   where l.partida_tabla = 'facturas' and l.partida_id = p_factura::text
$$;
revoke execute on function public.fn_emision_saldo(bigint) from public, anon, service_role;
grant  execute on function public.fn_emision_saldo(bigint) to authenticated;
comment on function public.fn_emision_saldo(bigint) is 'c11: lo que una factura debe hoy en el libro: su partida en la cuenta por cobrar (cxc) y en la retención por cobrar (retencion).';

-- LA REGLA DE LA RETENCIÓN (cabecera): round(monto × % × 0.01, 2), con el
-- redondeo de numeric (la mitad, lejos de cero), una vez por factura.
create or replace function public.fn_emision_retencion(p_monto numeric, p_pct numeric) returns numeric
language sql immutable
set search_path = public, pg_temp
as $$ select round(coalesce(p_monto, 0) * coalesce(p_pct, 0) * 0.01, 2) $$;
revoke execute on function public.fn_emision_retencion(numeric, numeric) from public, anon, service_role;
grant  execute on function public.fn_emision_retencion(numeric, numeric) to authenticated;
comment on function public.fn_emision_retencion(numeric, numeric) is 'c11: lo que se retiene de una factura: round(monto × % × 0.01, 2), con el redondeo de numeric (la mitad, lejos de cero). El 10 % de 1,234.57 son 123.46.';

-- La retención de una obra, en por ciento, y de dónde sale: la que Edgar
-- fijó (emision_obras), la del estimado enlazado (estimados.retencion_pct,
-- que la app guarda como fracción: × 100; el convertido antes que el más
-- nuevo), o ninguna.
create or replace function public.fn_emision_retencion_de(p_proyecto text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_pct  numeric;
  v_est  bigint;
  v_frac numeric;
begin
  if not fn_emision_ve() then
    return jsonb_build_object('pct', 0, 'origen', 'ninguna');
  end if;
  select o.retencion_pct into v_pct from emision_obras o where o.proyecto_id = p_proyecto;
  if v_pct is not null then
    return jsonb_build_object('pct', v_pct, 'origen', 'obra');
  end if;
  select e.id, e.retencion_pct into v_est, v_frac
    from estimados e
   where e.proyecto_id = p_proyecto and coalesce(e.retencion_pct, 0) > 0
   order by (e.estado = 'convertido') desc, e.id desc
   limit 1;
  if v_est is not null then
    return jsonb_build_object('pct', round(v_frac * 100, 2), 'origen', 'estimado', 'estimado_id', v_est);
  end if;
  return jsonb_build_object('pct', 0, 'origen', 'ninguna');
end $$;
revoke execute on function public.fn_emision_retencion_de(text) from public, anon, service_role;
grant  execute on function public.fn_emision_retencion_de(text) to authenticated;
comment on function public.fn_emision_retencion_de(text) is 'c11: la retención de una obra en por ciento y su origen: {pct, origen: obra (la fijó Edgar) | estimado (la de su estimado enlazado, que la app guarda como fracción: × 100) | ninguna, estimado_id}.';

-- A quién se le factura una obra: al contratista si la obra es por contrato
-- con él (como decide hoy la función qb); si no, al cliente. Lee contratistas
-- si existe (es de otra parte de la app).
create or replace function public.fn_emision_destinatario(p_proyecto text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_pr  jsonb;
  v_gc  jsonb;
  v_con boolean;
begin
  if not fn_emision_ve() then
    return '{}'::jsonb;
  end if;
  select to_jsonb(p) into v_pr from proyectos p where p.id = p_proyecto;
  if v_pr is null then
    return '{}'::jsonb;
  end if;
  v_con := coalesce(v_pr->>'contratista_modo', '') = 'contrato';
  if v_con and nullif(v_pr->>'contratista_id', '') is not null and to_regclass('public.contratistas') is not null then
    execute 'select to_jsonb(c) from public.contratistas c where c.id::text = $1' into v_gc using v_pr->>'contratista_id';
  end if;
  return jsonb_build_object(
    'a_contratista', v_con,
    'cliente', jsonb_strip_nulls(jsonb_build_object(
      'nombre',    nullif(btrim(case when v_gc is not null then v_gc->>'nombre' else v_pr->>'cliente' end), ''),
      'atencion',  case when v_gc is not null
                        then nullif(btrim(coalesce(nullif(btrim(v_pr->>'contratista_contacto'), ''), v_gc->>'contacto')), '') end,
      'direccion', case when v_gc is null then nullif(btrim(v_pr->>'direccion'), '') end,
      'correo',    nullif(btrim(case when v_gc is not null then v_gc->>'email' else v_pr->>'cliente_email' end), ''))));
end $$;
revoke execute on function public.fn_emision_destinatario(text) from public, anon, service_role;
grant  execute on function public.fn_emision_destinatario(text) to authenticated;
comment on function public.fn_emision_destinatario(text) is 'c11: a quién se le factura una obra: {a_contratista, cliente: {nombre, atencion, direccion, correo}}: el contratista si la obra es por contrato con él; si no, el cliente de la obra.';

-- Los enlaces de pago de p1 (stripe_enlaces), si p1 está; si no, nada.
create or replace function public.fn_emision_enlaces()
returns table (factura_id bigint, enlace_id uuid, estado text, url text, monto numeric, con_retencion boolean, creado_el timestamptz)
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if to_regclass('public.stripe_enlaces') is null or not fn_emision_ve() then
    return;
  end if;
  return query execute 'select e.factura_id, e.id, e.estado, e.url, e.monto, e.con_retencion, e.creado_el from public.stripe_enlaces e';
end $$;
revoke execute on function public.fn_emision_enlaces() from public, anon, service_role;
grant  execute on function public.fn_emision_enlaces() to authenticated;
comment on function public.fn_emision_enlaces() is 'c11: los enlaces de pago de p1 (stripe_enlaces: factura, estado, url, monto, si cobra la retención), si los cobros en línea están instalados; si no, ninguno.';

-- Los pagos en línea de p1 (stripe_pagos), si p1 está; si no, nada.
create or replace function public.fn_emision_pagos()
returns table (factura_id bigint, pi text, medio text, estado text, monto numeric, creado_el timestamptz)
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if to_regclass('public.stripe_pagos') is null or not fn_emision_ve() then
    return;
  end if;
  return query execute 'select s.factura_id, s.pi, s.medio, s.estado, s.monto, s.creado_el from public.stripe_pagos s';
end $$;
revoke execute on function public.fn_emision_pagos() from public, anon, service_role;
grant  execute on function public.fn_emision_pagos() to authenticated;
comment on function public.fn_emision_pagos() is 'c11: los pagos en línea de p1 (stripe_pagos: factura, medio, estado, monto), si los cobros en línea están instalados; si no, ninguno.';

-- Lo que hay en el bucket «facturas» de Storage (su ruta y su tamaño, si
-- Storage lo apunta), si esta base tiene Storage; si no, nada.
create or replace function public.fn_emision_storage()
returns table (ruta text, bytes bigint)
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if to_regclass('storage.objects') is null or not fn_emision_ve() then
    return;
  end if;
  return query execute 'select o.name::text, case when o.metadata->>''size'' ~ ''^[0-9]+$'' then (o.metadata->>''size'')::bigint end '
                    || 'from storage.objects o where o.bucket_id = ''facturas''';
end $$;
revoke execute on function public.fn_emision_storage() from public, anon, service_role;
grant  execute on function public.fn_emision_storage() to authenticated;
comment on function public.fn_emision_storage() is 'c11: los archivos del bucket privado «facturas» (ruta y tamaño), si esta base tiene Storage; si no, ninguno.';

-- LO RETENIDO DE UNA OBRA QUE FALTA RECLAMAR: por cada factura emitida de
-- la obra, lo que su partida tiene abierto en la retención por cobrar
-- (1120) en el libro, si todavía no lo reclama una factura de retención
-- viva (emitida y sin anular). De aquí salen las líneas de esa factura.
create or replace function public.fn_emision_retenido(p_proyecto text)
returns table (factura_id bigint, num text, fecha date, saldo numeric)
language sql stable
set search_path = public, pg_temp
as $$
  select f.id, f.num, f.fecha, s.saldo
    from public.facturas f
   cross join lateral (select coalesce(sum(l.monto), 0) as saldo
                         from public.asiento_lineas l
                        where l.partida_tabla = 'facturas' and l.partida_id = f.id::text
                          and l.cuenta = (select public.fn_emision_cuenta('retencion_cxc'))) s
   where f.proyecto_id = p_proyecto and f.estado = 'emitida' and s.saldo > 0
     and not exists (select 1
                       from public.emision_lineas el
                       join public.emision_documentos ed on ed.id = el.documento_id
                      where ed.forma = 'retencion' and ed.estado = 'emitida' and ed.anulado_el is null
                        and el.ref->>'factura_id' = f.id::text)
   order by f.fecha, f.id
$$;
revoke execute on function public.fn_emision_retenido(text) from public, anon, service_role;
grant  execute on function public.fn_emision_retenido(text) to authenticated;
comment on function public.fn_emision_retenido(text) is 'c11: lo retenido de una obra que falta reclamar: por cada factura emitida, lo que su partida tiene abierto en la retención por cobrar (1120) en el libro, si no lo reclama ya una factura de retención viva. Son las líneas de la factura de la retención.';

-- LA FACTURA VIVA DE UN HITO, la sepa quien la sepa: la fila de facturas que
-- apunta a ese hito (facturas.hito_id) O la que la app emitió de ese hito
-- (emision_documentos.hito_id, que no cambia aunque alguien vacíe o cambie
-- facturas.hito_id, o se borre el hito: la llave de facturas lo deja en
-- nulo). Con una, el hito no se factura otra vez: lo miran el borrador, la
-- emisión, la anulación (para soltar el hito), la lista de hitos de la obra
-- y el control. A quien no es el dueño no le devuelve nada.
create or replace function public.fn_emision_factura_de_hito(p_hito bigint)
returns table (factura_id bigint, num text, fecha date, documento_id uuid)
language sql stable
set search_path = public, pg_temp
as $$
  select f.id, f.num, f.fecha, d.id
    from public.facturas f
    left join public.emision_documentos d on d.factura_id = f.id
   where f.hito_id = p_hito and f.estado <> 'anulada' and (select public.fn_emision_ve())
  union
  select f.id, f.num, f.fecha, d.id
    from public.emision_documentos d
    join public.facturas f on f.id = d.factura_id
   where d.hito_id = p_hito and d.estado = 'emitida' and d.anulado_el is null and f.estado <> 'anulada'
     and (select public.fn_emision_ve())
   order by 1
$$;
revoke execute on function public.fn_emision_factura_de_hito(bigint) from public, anon, service_role;
grant  execute on function public.fn_emision_factura_de_hito(bigint) to authenticated;
comment on function public.fn_emision_factura_de_hito(bigint) is 'c11: las facturas vivas de un hito: las filas de facturas que apuntan a él (hito_id) y las que la app emitió de él (el documento guarda su hito aunque la fila de facturas deje de apuntarlo, o el hito se borre). Con una, ese hito no se factura otra vez. A quien no es el dueño no le devuelve nada.';


-- ---------------------------------------------------------------------
-- 5. EL BORRADOR: lo que lo frena o lo avisa, su huella («visto»), el
--    contenido que tendría emitido, el documento entero para la pantalla, y
--    crearlo, cambiarlo, refrescarlo y tirarlo.
-- ---------------------------------------------------------------------
-- LO QUE HAY QUE MIRAR ANTES DE EMITIR un borrador: una lista de {codigo,
-- texto, frena}. «frena» = con eso no se emite. Los códigos que acaban en
-- «_cambio» dicen que algo de fuera cambió desde que se armó el borrador
-- (el hito, el contrato, la retención, a quién se factura la obra): se
-- refresca y se vuelve a mirar.
-- La leen la pantalla (fn_emision_documento) y la emisión.
create or replace function public.fn_emision_revisar(p_documento uuid) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  d      emision_documentos;
  cfg    emision_config;
  pr     proyectos;
  h      hitos;
  v      jsonb := '[]'::jsonb;
  v_hoy  date := fn_fecha_miami(now());
  v_tipo text;
  v_m    mapeo_tipo_proyecto;
  v_x    numeric;
  v_y    numeric;
  v_n    int;
  v_txt  text;
  v_ret  jsonb;
  v_dest jsonb;
  v_viva boolean := false;
begin
  select * into d from emision_documentos where id = p_documento;
  if not found or d.estado <> 'borrador' then
    return v;
  end if;
  select * into cfg from emision_config where id = 1;

  -- El corte
  if v_hoy < cfg.corte then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'antes_del_corte', 'frena', true, 'texto',
      format('Todavía no se factura por la app: hasta el %s las facturas salen por QuickBooks (el 🧾 de siempre). Este borrador se '
             'queda guardado para probar; se podrá emitir desde el %s.', fn_emision_dia(cfg.corte - 1), fn_emision_dia(cfg.corte))));
  end if;
  -- Lo que la factura tiene que llevar de la casa
  if coalesce(btrim(cfg.empresa->>'nombre'), '') = '' then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'falta_empresa', 'frena', true, 'texto',
      'Faltan los datos de la empresa (por lo menos el nombre) en los ajustes de facturación: sin ellos la factura saldría sin '
      'membrete.'));
  end if;
  if btrim(cfg.como_pagar) = '' then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'falta_como_pagar', 'frena', true, 'texto',
      'Falta el texto «How to pay» en los ajustes de facturación: la factura tiene que decirle al cliente cómo pagar.'));
  end if;
  if coalesce(btrim(d.cliente->>'nombre'), '') = '' then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'falta_cliente', 'frena', true, 'texto',
      'Falta a quién se le factura (el nombre del cliente o del contratista): ponlo en el borrador o en la obra.'));
  end if;
  -- La obra
  select * into pr from proyectos where id = d.proyecto_id;
  if not found then
    return v || jsonb_build_array(jsonb_build_object('codigo', 'sin_obra', 'frena', true, 'texto',
      'La obra de este borrador ya no existe: descártalo.'));
  end if;
  if pr.estado in ('completado', 'no_aprobado') then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'obra_cerrada', 'frena', false, 'texto',
      format('La obra «%s» está %s: se puede facturar igual; solo mira que sea lo que quieres.', pr.nombre,
             case pr.estado when 'completado' then 'terminada' else 'marcada como no aprobada' end)));
  end if;
  -- A quién se factura, según la obra HOY: si la obra cambió de destinatario
  -- (del cliente al contratista, o al revés) desde que se armó el borrador,
  -- se refresca; si solo difieren los datos (Edgar los escribió, o cambiaron
  -- en la obra), se dice y se deja.
  v_dest := fn_emision_destinatario(d.proyecto_id);
  if coalesce((v_dest->>'a_contratista')::boolean, false) is distinct from d.a_contratista then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'destinatario_cambio', 'frena', true, 'texto',
      format('La obra «%s» ahora se factura %s y este borrador se armó para facturarle %s: refresca el borrador y vuelve a mirarlo.',
             pr.nombre, case when d.a_contratista then 'al cliente' else 'al contratista' end,
             case when d.a_contratista then 'al contratista' else 'al cliente' end)));
  elsif d.cliente is distinct from coalesce(v_dest->'cliente', '{}'::jsonb) then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'cliente_distinto', 'frena', false, 'texto',
      format('A quién se factura en este borrador (%s) no es lo que tiene la obra ahora (%s): si lo escribiste así a propósito, está '
             'bien; si no, vuelve al de la obra.',
             coalesce(nullif(concat_ws(' · ', d.cliente->>'nombre', d.cliente->>'atencion', d.cliente->>'correo'), ''), 'sin datos'),
             coalesce(nullif(concat_ws(' · ', v_dest->'cliente'->>'nombre', v_dest->'cliente'->>'atencion',
                                       v_dest->'cliente'->>'correo'), ''), 'sin datos'))));
  end if;
  -- El ingreso de su tipo de obra (lo decide c3): sin regla confirmada, el
  -- libro no aceptaría la factura. Se dice antes de gastar nada.
  if d.forma <> 'retencion' then
    v_tipo := nullif(lower(btrim(regexp_replace(coalesce(pr.tipo, ''), '[[:space:]]+', ' ', 'g'))), '');
    select * into v_m from mapeo_tipo_proyecto m where m.tipo = v_tipo;
    if v_tipo is null or v_m.tipo is null then
      v := v || jsonb_build_array(jsonb_build_object('codigo', 'sin_ingreso', 'frena', true, 'texto',
        format('La obra «%s» %s: el libro no sabría a qué ingreso va esta factura. Ponle su tipo a la obra o dale su cuenta en '
               'Contabilidad antes de emitir.', pr.nombre,
               case when v_tipo is null then 'no tiene tipo (residencial, comercial o servicio)'
                    else format('es de tipo «%s» y ese tipo no tiene cuenta de ingreso', pr.tipo) end)));
    elsif v_m.confirmado_el is null then
      v := v || jsonb_build_array(jsonb_build_object('codigo', 'ingreso_sin_confirmar', 'frena', true, 'texto',
        format('La regla de ingreso del tipo de obra «%s» (va a la cuenta %s) está sin confirmar: el libro no aceptaría la factura. '
               'Confírmala en Contabilidad y vuelve a emitir.', v_m.tipo, v_m.cuenta)));
    end if;
  end if;
  -- Las líneas y el monto
  select count(*) into v_n from emision_lineas l where l.documento_id = d.id;
  if v_n = 0 or d.monto <= 0 then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'sin_monto', 'frena', true, 'texto',
      'El borrador no tiene líneas o suma cero: una factura tiene que sumar más de cero.'));
  end if;
  -- Por su forma
  if d.forma = 'hito' then
    select * into h from hitos where id = d.hito_id;
    if not found or h.proyecto_id is distinct from d.proyecto_id then
      v := v || jsonb_build_array(jsonb_build_object('codigo', 'hito_borrado', 'frena', true, 'texto',
        'El hito de este borrador ya no existe (o cambió de obra): descarta el borrador.'));
    else
      if h.estado = 'cobrado' then
        v := v || jsonb_build_array(jsonb_build_object('codigo', 'hito_cobrado', 'frena', true, 'texto',
          format('El hito «%s» ya está marcado como cobrado: no se factura otra vez. Si de verdad hay que facturarlo, ponlo antes en '
                 'pendiente (la ficha no tiene botón para eso: avisa y se hace).', h.titulo)));
      end if;
      -- (la factura viva de ese hito, la sepa quien la sepa: la fila de facturas o el documento que salió de aquí)
      select format('%s del %s', x.num, fn_emision_dia(x.fecha)) into v_txt
        from fn_emision_factura_de_hito(d.hito_id) x order by x.factura_id limit 1;
      v_viva := v_txt is not null;
      if v_viva then
        v := v || jsonb_build_array(jsonb_build_object('codigo', 'hito_facturado', 'frena', true, 'texto',
          format('El hito «%s» ya se facturó: factura %s. No se hace otra; si aquella está mal, se anula con su nota de crédito.',
                 h.titulo, v_txt)));
      elsif h.estado = 'facturado' then
        -- (la ficha lo tiene como FACTURADO y aquí no hay ninguna factura viva suya. Solo se factura un hito pendiente, como
        -- en la app; se dice POR QUÉ está así y qué hacer —el mismo texto que da fn_emision_borrador—:
        --  · una factura de la app de este hito está anulada en el libro y aquí sigue sin cerrar (se anuló desde
        --    Contabilidad): se cierra aquí, y el hito vuelve a pendiente;
        --  · una factura anulada —de fuera, de QuickBooks, o de la app y ya cerrada— todavía apunta a este hito: la ficha
        --    se quedó como estaba cuando se anuló; el hito tiene que volver a pendiente y la ficha no tiene botón para eso;
        --  · ninguna de las dos: se facturó fuera de la app —QuickBooks a mano— o su factura se anotó sin su hito.)
        select string_agg(ed.numero || coalesce(' (nota de crédito ' || n.numero || ')', ''), ', ' order by ed.numero), count(*)
          into v_txt, v_n
          from emision_documentos ed
          join facturas f on f.id = ed.factura_id
          left join notas_credito n on n.anula_a = f.id
         where ed.hito_id = d.hito_id and ed.forma = 'hito' and ed.estado = 'emitida' and ed.anulado_el is null and f.estado = 'anulada';
        if v_txt is not null then
          v_txt := format('El hito «%s» sigue marcado como facturado en la ficha de la obra porque %s en el libro y aquí %s sin '
                          'cerrar. Hay que cerrar esa anulación aquí (Facturación → la factura → Anular; si ya sale anulada y no '
                          'ofrece el botón, avisa y se hace): el hito vuelve a pendiente y entonces se hace la buena.', h.titulo,
                          case when v_n = 1 then 'su factura ' || v_txt || ' está anulada' else 'sus facturas ' || v_txt || ' están anuladas' end,
                          case when v_n = 1 then 'sigue' else 'siguen' end);
        else
          select string_agg(format('%s del %s%s', f.num, fn_emision_dia(f.fecha), coalesce(' (nota de crédito ' || n.numero || ')', '')),
                            ', ' order by f.id), count(*)
            into v_txt, v_n
            from facturas f
            left join notas_credito n on n.anula_a = f.id
           where f.hito_id = d.hito_id and f.estado = 'anulada';
          v_txt := case
            when v_txt is not null
              then format('El hito «%s» sigue marcado como facturado en la ficha de la obra y %s: hoy no tiene ninguna factura viva. Si '
                          'no se volvió a facturar por otro lado (en QuickBooks), está sin facturar: para hacer aquí la buena, el hito '
                          'tiene que volver antes a pendiente (la ficha no tiene botón para eso: avisa y se hace).', h.titulo,
                          case when v_n = 1 then 'su factura ' || v_txt || ' está anulada' else 'sus facturas ' || v_txt || ' están anuladas' end)
            else format('El hito «%s» ya está marcado como facturado en la ficha de la obra y aquí no hay ninguna factura suya (¿se '
                        'facturó en QuickBooks, o su factura se anotó sin su hito?): no se factura otra vez. Si de verdad falta '
                        'facturarlo, ponlo antes en pendiente (la ficha no tiene botón para eso: avisa y se hace).', h.titulo) end;
        end if;
        v := v || jsonb_build_array(jsonb_build_object('codigo', 'hito_marcado_facturado', 'frena', true, 'texto', v_txt));
      end if;
      if round(coalesce(h.monto, 0), 2) is distinct from d.monto or coalesce(h.es_deposito, false) is distinct from d.es_deposito then
        v := v || jsonb_build_array(jsonb_build_object('codigo', 'hito_cambio', 'frena', true, 'texto',
          format('El hito «%s» ahora vale %s y este borrador dice %s: refresca el borrador y vuelve a mirarlo.', h.titulo,
                 fn_emision_usd(round(coalesce(h.monto, 0), 2)), fn_emision_usd(d.monto))));
      end if;
      -- Con esta, lo facturado de la obra pasa de su contrato: avisa y deja (puede faltar una orden de cambio en la ficha).
      select round(fp.contrato, 2) into v_x from finanzas_proyecto fp where fp.proyecto_id = d.proyecto_id;
      select coalesce(sum(round(f.monto, 2)), 0) into v_y from facturas f where f.proyecto_id = d.proyecto_id and f.estado = 'emitida';
      if v_x is not null and v_y + d.monto > v_x then
        v := v || jsonb_build_array(jsonb_build_object('codigo', 'pasa_del_contrato', 'frena', false, 'texto',
          format('Con esta factura lo facturado de la obra (%s) pasa del contrato (%s): mira que este hito no esté ya facturado con otro '
                 'nombre, o que no falte una orden de cambio en el contrato de la obra.', fn_emision_usd(v_y + d.monto), fn_emision_usd(v_x))));
      end if;
      -- Una factura viva de esta obra salió de un hito que después se BORRÓ: este puede ser aquel vuelto a crear.
      select string_agg(format('%s (%s)', ed.numero, fn_emision_usd(ed.monto)), ', ' order by ed.numero) into v_txt
        from emision_documentos ed
        join facturas f on f.id = ed.factura_id
       where ed.proyecto_id = d.proyecto_id and ed.forma = 'hito' and ed.estado = 'emitida' and ed.anulado_el is null
         and f.estado <> 'anulada' and not exists (select 1 from hitos x where x.id = ed.hito_id);
      if v_txt is not null then
        v := v || jsonb_build_array(jsonb_build_object('codigo', 'hito_borrado_facturado', 'frena', false, 'texto',
          format('En esta obra, la factura %s salió de un hito que después se borró. Mira que este hito no sea aquel vuelto a crear: se '
                 'facturaría dos veces. Si lo es, descarta este borrador.', v_txt)));
      end if;
      -- EL HITO YA TUVO UNA FACTURA QUE SE ANULÓ y su fila de facturas todavía lo apunta (la emitió la app o es de fuera, de
      -- QuickBooks): esta la sustituye. Se dice y NO frena: al emitir, la anulada deja de figurar como la factura de este
      -- hito (cabecera, «El hito que se vuelve a facturar»). Solo cuando de verdad la va a sustituir: con una factura VIVA
      -- del hito (ya lo frena «ya se facturó») o con la ficha teniéndolo todavía como facturado (ya lo frena, y nombra la
      -- anulada), «esta la sustituye» sería decir dos cosas a la vez.
      v_txt := null;
      if not v_viva and h.estado is distinct from 'facturado' then
        select string_agg(format('%s del %s%s', f.num, fn_emision_dia(f.fecha), coalesce(' (nota de crédito ' || n.numero || ')', '')),
                          ', ' order by f.id), count(*)
          into v_txt, v_n
          from facturas f
          left join notas_credito n on n.anula_a = f.id
         where f.hito_id = d.hito_id and f.estado = 'anulada';
      end if;
      if v_txt is not null then
        v := v || jsonb_build_array(jsonb_build_object('codigo', 'hito_factura_anulada', 'frena', false, 'texto',
          format('El hito «%s» ya tuvo %s: %s. Esta %s sustituye: al emitirla, %s de figurar como la factura de este hito (en lo '
                 'demás %s) y queda apuntado.', h.titulo,
                 case when v_n = 1 then 'una factura que se anuló' else 'facturas que se anularon' end, v_txt,
                 case when v_n = 1 then 'la' else 'las' end,
                 case when v_n = 1 then 'la anulada deja' else 'las anuladas dejan' end,
                 case when v_n = 1 then 'no cambia: sigue anulada' else 'no cambian: siguen anuladas' end)));
      end if;
    end if;
  elsif d.forma = 'porcentaje' then
    select round(fp.contrato, 2) into v_x from finanzas_proyecto fp where fp.proyecto_id = d.proyecto_id;
    if v_x is distinct from d.base then
      v := v || jsonb_build_array(jsonb_build_object('codigo', 'contrato_cambio', 'frena', true, 'texto',
        format('El contrato de la obra ahora es %s y este borrador se calculó sobre %s: refresca el borrador y vuelve a mirarlo.',
               fn_emision_usd(v_x), fn_emision_usd(d.base))));
    else
      select coalesce(sum(round(f.monto, 2)), 0) into v_y from facturas f where f.proyecto_id = d.proyecto_id and f.estado = 'emitida';
      if v_y + d.monto > v_x then
        v := v || jsonb_build_array(jsonb_build_object('codigo', 'pasa_del_contrato', 'frena', false, 'texto',
          format('Con esta factura lo facturado de la obra (%s) pasa del contrato (%s).', fn_emision_usd(v_y + d.monto),
                 fn_emision_usd(v_x))));
      end if;
    end if;
  elsif d.forma = 'retencion' then
    if exists (select 1 from (select r.factura_id, r.saldo from fn_emision_retenido(d.proyecto_id) r) a
                 full join (select (l.ref->>'factura_id')::bigint as factura_id, l.importe as saldo
                              from emision_lineas l where l.documento_id = d.id) b using (factura_id)
                where a.saldo is distinct from b.saldo) then
      v := v || jsonb_build_array(jsonb_build_object('codigo', 'retencion_cambio', 'frena', true, 'texto',
        'Lo retenido de la obra que falta reclamar ya no es lo que dice este borrador (entró un cobro, o una factura nueva): '
        'refresca el borrador y vuelve a mirarlo.'));
    end if;
  end if;
  if d.forma in ('porcentaje', 'tm')
     and exists (select 1 from hitos x where x.proyecto_id = d.proyecto_id and x.estado = 'pendiente') then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'obra_con_hitos', 'frena', false, 'texto',
      'Esta obra tiene hitos pendientes de facturar: una factura que no sale de un hito no mueve ninguno.'));
  end if;
  -- La retención de la obra (si el borrador no trae la suya)
  if d.forma <> 'retencion' and d.retencion_origen <> 'borrador' then
    v_ret := fn_emision_retencion_de(d.proyecto_id);
    if (v_ret->>'pct')::numeric is distinct from d.retencion_pct then
      v := v || jsonb_build_array(jsonb_build_object('codigo', 'retencion_cambio', 'frena', true, 'texto',
        format('La retención de la obra ahora es %s %% y este borrador dice %s %%: refresca el borrador y vuelve a mirarlo.',
               trim_scale((v_ret->>'pct')::numeric), trim_scale(d.retencion_pct))));
    end if;
  end if;
  if d.forma <> 'retencion' and d.a_contratista and d.retencion_pct = 0 then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'contratista_sin_retencion', 'frena', false, 'texto',
      'Es a un contratista y va sin retención: si él retiene un porcentaje, ponlo en la obra antes de emitir.'));
  end if;
  if d.forma = 'hito' and d.es_deposito and d.retencion > 0 then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'deposito_con_retencion', 'frena', false, 'texto',
      format('Es el depósito y lleva retención (%s %%: se le retienen %s y paga ahora %s). Si del depósito no se retiene, pon en 0 la '
             'retención de este borrador.', trim_scale(d.retencion_pct), fn_emision_usd(d.retencion), fn_emision_usd(d.a_pagar))));
  end if;
  -- El idioma (una ayuda): lo que ve el cliente va en inglés
  select string_agg(distinct x.que, ', ') into v_txt
    from (select 'una línea' as que from emision_lineas l
           where l.documento_id = d.id and (fn_emision_parece_espanol(l.descripcion) or fn_emision_parece_espanol(l.detalle))
          union all select 'las notas' where fn_emision_parece_espanol(d.notas)
          union all select 'el «How to pay»' where fn_emision_parece_espanol(cfg.como_pagar)
          union all select 'los términos' where fn_emision_parece_espanol(cfg.terminos_texto)) x;
  if v_txt is not null then
    v := v || jsonb_build_array(jsonb_build_object('codigo', 'en_espanol', 'frena', true, 'texto',
      format('Parece que hay texto en español (%s) y lo que ve el cliente va en inglés: cámbialo, o confirma que está bien así.',
             v_txt)));
  end if;
  return v;
end $$;
revoke execute on function public.fn_emision_revisar(uuid) from public, anon, service_role;
grant  execute on function public.fn_emision_revisar(uuid) to authenticated;
comment on function public.fn_emision_revisar(uuid) is 'c11: lo que hay que mirar antes de emitir un borrador: una lista de {codigo, texto, frena}: el corte, los datos de la empresa y el «How to pay», a quién se factura (y si la obra cambió de destinatario), la regla de ingreso de la obra, que sume, el hito (ya cobrado, ya facturado —por su fila de facturas o por el documento que salió de él—, o marcado como facturado en la ficha sin factura viva aquí: solo se factura un hito pendiente, y si es por una factura que se anuló dice cuál, con su nota de crédito, y qué hacer; cambió; en la obra hay una factura viva de un hito que se borró; está pendiente y ya tuvo una factura que se anuló y todavía lo apunta: se dice, no frena, y al emitir la anulada lo suelta), el contrato (y si con esta factura lo facturado pasa de él), la retención (y si es el depósito y lleva retención), un texto que parece español… Solo lee.';

-- EL CONTENIDO: el documento entero como lo recibe el cliente. Para un
-- borrador es la vista previa (sin número: p_numero nulo); al emitir es lo
-- que se congela. p_factura: la fila de facturas de este documento si ya
-- está en el libro (para no contar dos veces lo suyo). Los montos van como
-- texto de dos decimales: la pantalla los pinta, no los suma.
--   contrato: el de finanzas_proyecto ese día, lo facturado antes en la obra
--     (las facturas emitidas y sin anular), esta, y el % con esta.
--   totales.retenido_a_la_fecha: lo que el libro tiene en la retención por
--     cobrar de las facturas de la obra, con esta.
create or replace function public.fn_emision_contenido(p_documento uuid, p_numero text, p_fecha date, p_factura bigint)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  d        emision_documentos;
  cfg      emision_config;
  v_pr     jsonb;
  v_h      jsonb;
  v_lin    jsonb;
  v_ret    numeric;
  v_antes  numeric;
  v_n      int;
  v_con    numeric;
  v_ach    boolean;
  v_fecha  date := coalesce(p_fecha, fn_fecha_miami(now()));
begin
  if not fn_emision_ve() then
    return null;
  end if;
  select * into d from emision_documentos where id = p_documento;
  if not found then
    return null;
  end if;
  select * into cfg from emision_config where id = 1;
  v_ach := cfg.ach and d.forma <> 'retencion' and to_regclass('public.stripe_enlaces') is not null;
  select to_jsonb(p) into v_pr from proyectos p where p.id = d.proyecto_id;
  if d.hito_id is not null then
    select jsonb_build_object('id', x.id, 'titulo', x.titulo, 'es_deposito', coalesce(x.es_deposito, false)) into v_h
      from hitos x where x.id = d.hito_id;
  end if;
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'n', l.n, 'tipo', l.tipo, 'descripcion', l.descripcion, 'detalle', l.detalle,
           'cantidad', trim_scale(l.cantidad)::text, 'unidad', l.unidad,
           'precio', case when scale(l.precio) <= 2 then round(l.precio, 2)::text else trim_scale(l.precio)::text end,
           'importe', l.importe::text, 'ref', l.ref)) order by l.n), '[]'::jsonb)
    into v_lin
    from emision_lineas l where l.documento_id = d.id;
  -- lo retenido de la obra en el libro (con esta factura, esté ya o no)
  select coalesce(sum(l.monto), 0) into v_ret
    from asiento_lineas l
    join facturas f on l.partida_tabla = 'facturas' and l.partida_id = f.id::text
   where f.proyecto_id = d.proyecto_id and l.cuenta = fn_emision_cuenta('retencion_cxc');
  if p_factura is null and d.forma <> 'retencion' then
    v_ret := v_ret + d.retencion;
  end if;
  -- lo facturado antes en la obra, y el contrato de hoy
  select coalesce(sum(round(f.monto, 2)), 0), count(*) into v_antes, v_n
    from facturas f
   where f.proyecto_id = d.proyecto_id and f.estado = 'emitida' and (p_factura is null or f.id <> p_factura);
  select round(fp.contrato, 2) into v_con from finanzas_proyecto fp where fp.proyecto_id = d.proyecto_id;
  return jsonb_strip_nulls(jsonb_build_object(
    'v', 1,
    'forma', d.forma,
    'numero', p_numero,
    'fecha', v_fecha,
    'vence', v_fecha + cfg.terminos_dias,
    'terminos', jsonb_build_object('dias', cfg.terminos_dias,
                                   'etiqueta', case when cfg.terminos_dias = 0 then 'Due on receipt' else 'Net ' || cfg.terminos_dias end,
                                   'texto', nullif(btrim(cfg.terminos_texto), '')),
    'empresa', cfg.empresa,
    'cliente', d.cliente,
    'a_contratista', d.a_contratista,
    'obra', jsonb_build_object('id', d.proyecto_id, 'nombre', v_pr->>'nombre', 'direccion', nullif(btrim(v_pr->>'direccion'), ''),
                               'ref', nullif(btrim(v_pr->>'ref'), '')),
    'hito', v_h,
    'ordinal', case when d.forma <> 'retencion' then v_n + 1 end,
    'lineas', v_lin,
    'totales', jsonb_build_object('subtotal', d.monto::text, 'retencion_pct', trim_scale(d.retencion_pct)::text,
                                  'retencion', d.retencion::text, 'a_pagar', d.a_pagar::text,
                                  'retenido_a_la_fecha', v_ret::numeric(14,2)::text),
    'contrato', case when coalesce(v_con, 0) > 0
                     then jsonb_build_object(
                            'monto', v_con::text,
                            'facturado_antes', v_antes::numeric(14,2)::text,
                            'esta', (case when d.forma = 'retencion' then 0 else d.monto end)::numeric(14,2)::text,
                            'facturado_con_esta', (v_antes + case when d.forma = 'retencion' then 0 else d.monto end)::numeric(14,2)::text,
                            'pct', round((v_antes + case when d.forma = 'retencion' then 0 else d.monto end) * 100 / v_con, 1)::text) end,
    'como_pagar', nullif(btrim(cfg.como_pagar), ''),
    -- (el pago en línea: solo por cuenta de banco; la tarjeta no se le ofrece al cliente. «texto» es lo que la factura le
    -- dice, en inglés, cuando hay pago en línea)
    'pago_en_linea', jsonb_build_object('ach', v_ach, 'tarjeta', false,
                                        'texto', case when v_ach then 'Online payment is by bank account (ACH) only.' end),
    -- (la factura de la retención no es una factura del libro: lo que el cliente cita al pagar son los números de las
    -- facturas cuya retención reclama)
    'referencias', case when d.forma = 'retencion'
                        then (select jsonb_agg(l.ref->>'numero' order by l.n)
                                from emision_lineas l where l.documento_id = d.id and l.ref->>'numero' is not null) end,
    'notas', d.notas));
end $$;
revoke execute on function public.fn_emision_contenido(uuid, text, date, bigint) from public, anon, service_role;
grant  execute on function public.fn_emision_contenido(uuid, text, date, bigint) to authenticated;
comment on function public.fn_emision_contenido(uuid, text, date, bigint) is 'c11: el documento entero como lo recibe el cliente: {v, forma, numero, fecha, vence, terminos, empresa, cliente, a_contratista, obra, hito, ordinal, lineas, totales, contrato, como_pagar, pago_en_linea: {ach, tarjeta: false, texto}, referencias (la de la retención), notas}, con los montos como texto de dos decimales. Para un borrador es la vista previa (sin número); al emitir es lo que se congela. Solo lee.';

-- LA HUELLA DE UN BORRADOR («visto»): md5 de TODO lo que la pantalla enseña
-- y la emisión congelaría: la vista previa entera (fn_emision_contenido sin
-- número: el documento, sus líneas, los ajustes que salen en la factura, la
-- fecha de hoy, el ordinal, el contrato y lo facturado antes en la obra, lo
-- retenido a la fecha). fn_emision_emitir la pide: si no es la de hoy
-- —cambió el borrador, cambiaron los ajustes, entró otra factura de la obra
-- entre medias, o se miró ayer y se emite hoy—, MX011. Lo que se congela es
-- lo que se vio, salvo el número.
create or replace function public.fn_emision_visto(p_documento uuid) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select md5(p_documento::text || x.c::text)
    from (select public.fn_emision_contenido(p_documento, null, null, null) as c) x
   where x.c is not null
$$;
revoke execute on function public.fn_emision_visto(uuid) from public, anon, service_role;
grant  execute on function public.fn_emision_visto(uuid) to authenticated;
comment on function public.fn_emision_visto(uuid) is 'c11: la huella de un borrador (md5 de su vista previa entera: el documento, sus líneas, los ajustes que salen en la factura, la fecha, el ordinal, el contrato y lo facturado antes en la obra, lo retenido a la fecha): lo que la pantalla enseñó y lo que se congelaría, salvo el número. fn_emision_emitir la pide.';

-- EL DOCUMENTO ENTERO PARA LA PANTALLA (un borrador o una factura
-- emitida): {documento, lineas, y —borrador— avisos, puede_emitir,
-- por_que_no, visto, vista_previa; —emitida— contenido, huella, libro,
-- sustituye, sustituida_por, pdfs, envios}. sustituye: las facturas
-- anuladas a las que esta sustituyó en su hito ([] si ninguna: [{factura_id,
-- numero, nota_credito?, de_la_app, soltado_el}]); sustituida_por: si esta
-- es una anulada de la app que soltó su hito, la que la sustituyó
-- ({documento, numero, fecha, soltado_el}; nulo si no).
create or replace function public.fn_emision_documento(p_documento uuid) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  d       emision_documentos;
  v_doc   jsonb;
  v_lin   jsonb;
  v_av    jsonb;
  v_estado text;
  v_fest  text;
  v_cxc   numeric;
  v_cret  numeric;
begin
  perform fn_emision_exigir_dueno();
  select * into d from emision_documentos where id = p_documento;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese documento.';
  end if;
  if d.factura_id is not null then
    select f.estado into v_fest from facturas f where f.id = d.factura_id;
  end if;
  v_estado := case when d.estado = 'borrador' then 'borrador'
                   when d.anulado_el is not null or v_fest = 'anulada' then 'anulada' else 'emitida' end;
  v_doc := jsonb_build_object(
    'id', d.id, 'estado', v_estado, 'forma', d.forma, 'proyecto_id', d.proyecto_id,
    'obra', (select p.nombre from proyectos p where p.id = d.proyecto_id),
    'hito_id', d.hito_id, 'hito', (select x.titulo from hitos x where x.id = d.hito_id), 'es_deposito', d.es_deposito,
    'porcentaje', d.porcentaje, 'base', d.base, 'a_contratista', d.a_contratista, 'cliente', d.cliente, 'notas', d.notas,
    'retencion_pct', d.retencion_pct, 'retencion_origen', d.retencion_origen, 'monto', d.monto, 'retencion', d.retencion,
    'a_pagar', d.a_pagar, 'numero', d.numero, 'fecha', d.fecha, 'vence', d.vence, 'factura_id', d.factura_id,
    -- (el asiento de HOY de su factura: si c3 lo rehízo —una regla corregida—, el nuevo; el de la emisión queda en asiento_id)
    'asiento', (select a.numero from asientos a
                 where a.id = coalesce((select f.contabilizado_en from facturas f where f.id = d.factura_id), d.asiento_id)),
    'nota_credito', coalesce(d.nota_credito, (select n.numero from notas_credito n where n.anula_a = d.factura_id)),
    'anulado_el', d.anulado_el, 'anulado_motivo', d.anulado_motivo, 'emitido_el', d.emitido_el, 'creado_el', d.creado_el,
    'actualizado_el', d.actualizado_el);
  select coalesce(jsonb_agg(jsonb_build_object('n', l.n, 'tipo', l.tipo, 'descripcion', l.descripcion, 'detalle', l.detalle,
                                               'cantidad', l.cantidad, 'unidad', l.unidad, 'precio', l.precio, 'importe', l.importe,
                                               'ref', l.ref) order by l.n), '[]'::jsonb)
    into v_lin from emision_lineas l where l.documento_id = d.id;
  if d.estado = 'borrador' then
    v_av := fn_emision_revisar(d.id);
    return jsonb_build_object(
      'documento', v_doc, 'lineas', v_lin, 'avisos', v_av,
      'puede_emitir', not exists (select 1 from jsonb_array_elements(v_av) a where (a->>'frena')::boolean),
      'por_que_no', (select a.value->>'texto' from jsonb_array_elements(v_av) with ordinality a(value, o)
                      where (a.value->>'frena')::boolean order by a.o limit 1),
      'visto', fn_emision_visto(d.id),
      'vista_previa', fn_emision_contenido(d.id, null, null, null));
  end if;
  if d.factura_id is not null then
    select s.cxc, s.retencion into v_cxc, v_cret from fn_emision_saldo(d.factura_id) s;
  end if;
  return jsonb_build_object(
    'documento', v_doc, 'lineas', v_lin, 'contenido', d.contenido, 'huella', d.huella,
    'libro', case when d.factura_id is not null
                  then jsonb_build_object('saldo', v_cxc, 'saldo_retencion', v_cret,
                                          'factura_estado', v_fest) end,
    -- (el hito que se volvió a facturar: a qué facturas anuladas sustituyó esta —las que soltaron el hito al emitirla—, y,
    -- si esta es una anulada de la app que lo soltó, cuál la sustituyó. Sale de emision_soltados)
    'sustituye', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                              'factura_id', s.factura_id, 'numero', s.num, 'nota_credito', s.nota_credito,
                                              'de_la_app', s.de_la_app, 'soltado_el', s.soltado_el)) order by s.factura_id), '[]'::jsonb)
                    from emision_soltados s where s.documento_id = d.id),
    'sustituida_por', (select jsonb_build_object('documento', x.id, 'numero', x.numero, 'fecha', x.fecha, 'soltado_el', s.soltado_el)
                         from emision_soltados s
                         join emision_documentos x on x.id = s.documento_id
                        where d.factura_id is not null and s.factura_id = d.factura_id
                        order by s.soltado_el desc, x.numero desc limit 1),
    'pdfs', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'n', x.n, 'ruta', x.ruta, 'sha256', x.sha256, 'bytes', x.bytes,
                                                          'pago', x.pago, 'creado_el', x.creado_el) order by x.n), '[]'::jsonb)
               from emision_pdfs x where x.documento_id = d.id),
    'envios', (select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'n', e.n, 'medio', e.medio, 'para', e.para, 'cc', e.cc,
                                                            'asunto', e.asunto, 'resend_id', e.resend_id, 'pdf_id', e.pdf_id,
                                                            'nota', e.nota, 'enviado_el', e.enviado_el) order by e.n), '[]'::jsonb)
                 from emision_envios e where e.documento_id = d.id));
end $$;
revoke execute on function public.fn_emision_documento(uuid) from public, anon, service_role;
grant  execute on function public.fn_emision_documento(uuid) to authenticated;
comment on function public.fn_emision_documento(uuid) is 'c11: un documento entero para la pantalla: {documento, lineas} y, si es un borrador, {avisos, puede_emitir, por_que_no, visto, vista_previa}; si está emitido, {contenido, huella, libro: lo que debe hoy, sustituye: las facturas anuladas a las que sustituyó en su hito (las que lo soltaron al emitirse esta; [] si ninguna), sustituida_por: si es una anulada de la app que soltó su hito, la factura que la sustituyó (nulo si no), pdfs, envios}. Solo lee. Solo el dueño.';

-- CREAR, CAMBIAR O REFRESCAR UN BORRADOR. p:
--   documento      el borrador que se cambia (sin él, uno nuevo; el de un
--                  hito, y el de la retención de una obra, son uno solo: si
--                  ya hay, se abre ese)
--   forma          hito | porcentaje | tm | retencion (al crear)
--   proyecto_id    la obra (en la de hito sale del hito)
--   hito_id        el hito (forma hito)
--   porcentaje     el % del contrato (forma porcentaje; 30 = 30 %)
--   lineas         forma tm: [{descripcion, cantidad?, precio, tipo?: horas |
--                  material | otro, unidad?, detalle?}] (las sustituye todas)
--   descripcion, detalle   forma hito y porcentaje: el texto de su línea
--   retencion_pct  el % de retención de ESTE borrador (nulo = el de la obra)
--   cliente        a quién se factura {nombre, atencion?, direccion?,
--                  correo?} (nulo = el de la obra; si la obra cambia de
--                  destinatario —del cliente al contratista o al revés—, al
--                  refrescar se vuelve a leer el de la obra)
--   notas          las notas al cliente (inglés)
-- Cada llamada vuelve a leer lo de fuera (el monto del hito, el contrato,
-- lo retenido, la retención de la obra): llamar solo con «documento» es
-- refrescar. Devuelve fn_emision_documento y {nuevo}.
create or replace function public.fn_emision_borrador(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_sobra  text;
  v_id     uuid;
  d        emision_documentos;
  v_nuevo  boolean := false;
  v_forma  text;
  v_obra   text;
  v_hito   bigint;
  h        hitos;
  pr       proyectos;
  v_pct    numeric;
  v_base   numeric;
  v_dep    boolean := false;
  v_dest   jsonb;
  v_cli    jsonb;
  v_ret    jsonb;
  v_rpct   numeric;
  v_rorig  text;
  v_notas  text;
  v_lin    jsonb;
  v_e      jsonb;
  v_i      int := 0;
  v_desc   text;
  v_det    text;
  v_tipo   text;
  v_cant   numeric;
  v_precio numeric;
  v_imp    numeric;
  v_monto  numeric;
  v_reten  numeric;
  v_txt    text;
  v_vieja  emision_lineas;
begin
  perform fn_emision_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'El borrador llega como un objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p) k
   where k not in ('documento', 'forma', 'proyecto_id', 'hito_id', 'porcentaje', 'lineas', 'descripcion', 'detalle', 'retencion_pct',
                   'cliente', 'notas');
  if v_sobra is not null then
    raise exception using errcode = '22023',
      message = format('Clave desconocida en el borrador: %s. Las que hay: documento, forma, proyecto_id, hito_id, porcentaje, lineas, '
                       'descripcion, detalle, retencion_pct, cliente y notas.', v_sobra);
  end if;

  -- 1. Qué documento
  if p ? 'documento' and jsonb_typeof(p->'documento') <> 'null' then
    begin
      v_id := (p->>'documento')::uuid;
    exception when others then
      raise exception using errcode = '22023', message = 'documento es el identificador del borrador.';
    end;
    select * into d from emision_documentos where id = v_id for update;
    if not found then
      raise exception using errcode = '22023', message = 'No existe ese borrador.';
    end if;
    if d.estado <> 'borrador' then
      raise exception using errcode = 'MX008',
        message = format('La factura %s ya se emitió: no cambia. Si está mal, se anula con su nota de crédito y se hace la buena.',
                         d.numero);
    end if;
    if (p ? 'forma' and p->>'forma' is distinct from d.forma)
       or (p ? 'proyecto_id' and p->>'proyecto_id' is distinct from d.proyecto_id)
       or (p ? 'hito_id' and p->>'hito_id' is distinct from d.hito_id::text) then
      raise exception using errcode = '22023',
        message = 'Un borrador no cambia de forma, de obra ni de hito: descártalo y haz otro.';
    end if;
    v_forma := d.forma; v_obra := d.proyecto_id; v_hito := d.hito_id;
  else
    v_forma := p->>'forma';
    if v_forma is null or v_forma not in ('hito', 'porcentaje', 'tm', 'retencion') then
      raise exception using errcode = '22023',
        message = format('La forma de la factura es hito, porcentaje, tm o retencion (llegó «%s»).', coalesce(v_forma, ''));
    end if;
    v_obra := nullif(btrim(p->>'proyecto_id'), '');
    if v_forma = 'hito' then
      if coalesce(p->>'hito_id', '') !~ '^-?[0-9]{1,18}$' then
        raise exception using errcode = '22023', message = 'Di qué hito se factura (hito_id).';
      end if;
      v_hito := (p->>'hito_id')::bigint;
      select * into h from hitos where id = v_hito;
      if not found then
        raise exception using errcode = '22023', message = format('No existe el hito %s.', v_hito);
      end if;
      if v_obra is null then
        v_obra := h.proyecto_id;
      elsif v_obra is distinct from h.proyecto_id then
        raise exception using errcode = '22023', message = 'Ese hito es de otra obra.';
      end if;
    elsif p ? 'hito_id' and jsonb_typeof(p->'hito_id') <> 'null' then
      raise exception using errcode = '22023', message = 'El hito va solo en la factura por hito.';
    end if;
    if v_obra is null then
      raise exception using errcode = '22023', message = 'Di de qué obra es la factura (proyecto_id).';
    end if;
    -- el borrador de un hito, y el de la retención de una obra, son uno solo
    if v_forma = 'hito' then
      select * into d from emision_documentos where hito_id = v_hito and estado = 'borrador' for update;
    elsif v_forma = 'retencion' then
      select * into d from emision_documentos where proyecto_id = v_obra and forma = 'retencion' and estado = 'borrador' for update;
    end if;
    v_nuevo := d.id is null;
    v_id := d.id;
  end if;

  -- 2. La obra
  select * into pr from proyectos where id = v_obra;
  if not found then
    raise exception using errcode = '22023', message = format('La obra %s no existe.', v_obra);
  end if;
  if not v_nuevo then
    select * into v_vieja from emision_lineas l where l.documento_id = v_id order by l.n limit 1;
  end if;

  -- 3. Sus líneas, según la forma (v_lin nulo = las que tiene se quedan)
  if v_forma = 'hito' then
    select * into h from hitos where id = v_hito for update;
    if not found or h.proyecto_id is distinct from v_obra then
      raise exception using errcode = 'MX008', message = 'El hito de este borrador ya no existe (o cambió de obra): descarta el borrador.';
    end if;
    if h.estado = 'cobrado' then
      raise exception using errcode = 'MX008',
        message = format('El hito «%s» ya está marcado como cobrado: no se factura otra vez. Si de verdad hay que facturarlo, ponlo '
                         'antes en pendiente (la ficha no tiene botón para eso: avisa y se hace).', h.titulo);
    end if;
    select format('%s del %s', x.num, fn_emision_dia(x.fecha)) into v_txt
      from fn_emision_factura_de_hito(v_hito) x order by x.factura_id limit 1;
    if v_txt is not null then
      raise exception using errcode = 'MX008',
        message = format('El hito «%s» ya se facturó: factura %s. No se hace otra; si aquella está mal, se anula con su nota de '
                         'crédito.', h.titulo, v_txt);
    end if;
    -- (solo se factura un hito PENDIENTE, como en la app. El que la ficha ya tiene como facturado y aquí no tiene factura viva
    -- no se factura otra vez; se dice POR QUÉ está así y qué hacer —el mismo texto que el aviso hito_marcado_facturado de
    -- fn_emision_revisar—: una factura de la app anulada en el libro y sin cerrar aquí; una anulada —de fuera, o de la app
    -- ya cerrada— que todavía apunta al hito; o ninguna: se facturó fuera —QuickBooks a mano— o su factura se anotó sin
    -- su hito)
    if h.estado = 'facturado' then
      select string_agg(ed.numero || coalesce(' (nota de crédito ' || n.numero || ')', ''), ', ' order by ed.numero), count(*)
        into v_txt, v_i
        from emision_documentos ed
        join facturas f on f.id = ed.factura_id
        left join notas_credito n on n.anula_a = f.id
       where ed.hito_id = v_hito and ed.forma = 'hito' and ed.estado = 'emitida' and ed.anulado_el is null and f.estado = 'anulada';
      if v_txt is not null then
        raise exception using errcode = 'MX008',
          message = format('El hito «%s» sigue marcado como facturado en la ficha de la obra porque %s en el libro y aquí %s sin '
                           'cerrar. Hay que cerrar esa anulación aquí (Facturación → la factura → Anular; si ya sale anulada y no '
                           'ofrece el botón, avisa y se hace): el hito vuelve a pendiente y entonces se hace la buena.', h.titulo,
                           case when v_i = 1 then 'su factura ' || v_txt || ' está anulada' else 'sus facturas ' || v_txt || ' están anuladas' end,
                           case when v_i = 1 then 'sigue' else 'siguen' end);
      end if;
      select string_agg(format('%s del %s%s', f.num, fn_emision_dia(f.fecha), coalesce(' (nota de crédito ' || n.numero || ')', '')),
                        ', ' order by f.id), count(*)
        into v_txt, v_i
        from facturas f
        left join notas_credito n on n.anula_a = f.id
       where f.hito_id = v_hito and f.estado = 'anulada';
      if v_txt is not null then
        raise exception using errcode = 'MX008',
          message = format('El hito «%s» sigue marcado como facturado en la ficha de la obra y %s: hoy no tiene ninguna factura viva. Si '
                           'no se volvió a facturar por otro lado (en QuickBooks), está sin facturar: para hacer aquí la buena, el hito '
                           'tiene que volver antes a pendiente (la ficha no tiene botón para eso: avisa y se hace).', h.titulo,
                           case when v_i = 1 then 'su factura ' || v_txt || ' está anulada' else 'sus facturas ' || v_txt || ' están anuladas' end);
      end if;
      raise exception using errcode = 'MX008',
        message = format('El hito «%s» ya está marcado como facturado en la ficha de la obra y aquí no hay ninguna factura suya (¿se '
                         'facturó en QuickBooks, o su factura se anotó sin su hito?): no se factura otra vez. Si de verdad falta '
                         'facturarlo, ponlo antes en pendiente (la ficha no tiene botón para eso: avisa y se hace).', h.titulo);
    end if;
    if h.monto is null or round(h.monto, 2) <= 0 then
      raise exception using errcode = 'MX005', message = format('El hito «%s» no tiene monto: ponle su monto antes de facturarlo.', h.titulo);
    end if;
    v_dep  := coalesce(h.es_deposito, false);
    -- (el texto de la línea: el título del hito, tal cual; la obra ya sale en su recuadro. Si está en español, el borrador
    -- lo avisa y Edgar lo escribe en inglés antes de emitir)
    v_desc := coalesce(case when p ? 'descripcion' then nullif(btrim(p->>'descripcion'), '') end, v_vieja.descripcion, btrim(h.titulo));
    v_det  := case when p ? 'detalle' then nullif(btrim(p->>'detalle'), '')
                   when v_vieja.documento_id is not null then v_vieja.detalle
                   else nullif(btrim(h.condicion), '') end;
    v_lin := jsonb_build_array(jsonb_build_object('tipo', 'hito', 'descripcion', v_desc, 'detalle', v_det, 'cantidad', 1,
                                                  'precio', round(h.monto, 2), 'ref', jsonb_build_object('hito_id', h.id)));
  elsif v_forma = 'porcentaje' then
    if p ? 'porcentaje' and jsonb_typeof(p->'porcentaje') <> 'null' then
      begin
        v_pct := (p->>'porcentaje')::numeric;
      exception when others then
        raise exception using errcode = 'MX005', message = 'El porcentaje es un número (30 = 30 %).';
      end;
    else
      v_pct := d.porcentaje;
    end if;
    if v_pct is null then
      raise exception using errcode = '22023', message = 'Di qué porcentaje del contrato se factura (porcentaje: 30 = 30 %).';
    end if;
    if v_pct <= 0 or v_pct > 100 or scale(v_pct) > 4 then
      raise exception using errcode = 'MX005', message = 'El porcentaje va de más de 0 a 100, con cuatro decimales como mucho.';
    end if;
    select round(fp.contrato, 2) into v_base from finanzas_proyecto fp where fp.proyecto_id = v_obra;
    if v_base is null or v_base <= 0 then
      raise exception using errcode = 'MX008',
        message = format('La obra «%s» no tiene su contrato puesto: sin contrato no hay porcentaje que facturar. Ponlo en la obra '
                         '(Dinero), o factura por hito o T&M.', pr.nombre);
    end if;
    v_imp := round(v_base * v_pct * 0.01, 2);
    if v_imp <= 0 then
      raise exception using errcode = 'MX005', message = 'Ese porcentaje de ese contrato da cero.';
    end if;
    v_desc := coalesce(case when p ? 'descripcion' then nullif(btrim(p->>'descripcion'), '') end,
                       case when p ? 'porcentaje' or v_base is distinct from d.base then null else v_vieja.descripcion end,
                       format('Progress billing — %s%% of contract amount (%s)', trim_scale(v_pct), fn_emision_usd(v_base)));
    v_det  := case when p ? 'detalle' then nullif(btrim(p->>'detalle'), '') else v_vieja.detalle end;
    v_lin := jsonb_build_array(jsonb_build_object('tipo', 'porcentaje', 'descripcion', v_desc, 'detalle', v_det, 'cantidad', 1,
                                                  'precio', v_imp));
  elsif v_forma = 'tm' then
    if p ? 'lineas' then
      if jsonb_typeof(p->'lineas') <> 'array' or jsonb_array_length(p->'lineas') = 0 or jsonb_array_length(p->'lineas') > 100 then
        raise exception using errcode = '22023',
          message = 'Las líneas llegan como una lista de 1 a 100: [{descripcion, cantidad, precio, tipo?, unidad?, detalle?}].';
      end if;
      v_lin := '[]'::jsonb;
      for v_e in select value from jsonb_array_elements(p->'lineas') loop
        v_i := v_i + 1;
        if jsonb_typeof(v_e) <> 'object' then
          raise exception using errcode = '22023', message = format('Línea %s: cada línea es un objeto.', v_i);
        end if;
        select string_agg(k, ', ' order by k) into v_sobra
          from jsonb_object_keys(v_e) k where k not in ('tipo', 'descripcion', 'detalle', 'cantidad', 'unidad', 'precio');
        if v_sobra is not null then
          raise exception using errcode = '22023', message = format('Línea %s: clave desconocida: %s.', v_i, v_sobra);
        end if;
        v_tipo := coalesce(nullif(btrim(v_e->>'tipo'), ''), 'otro');
        if v_tipo not in ('horas', 'material', 'otro') then
          raise exception using errcode = '22023', message = format('Línea %s: el tipo es horas, material u otro (llegó «%s»).', v_i, v_tipo);
        end if;
        v_desc := nullif(btrim(v_e->>'descripcion'), '');
        if v_desc is null or length(v_desc) > 500 or length(coalesce(v_e->>'detalle', '')) > 1000
           or length(coalesce(v_e->>'unidad', '')) > 20 then
          raise exception using errcode = '22023',
            message = format('Línea %s: lleva su descripción (hasta 500 letras; el detalle, hasta 1000; la unidad, hasta 20).', v_i);
        end if;
        begin
          v_cant   := coalesce((v_e->>'cantidad')::numeric, 1);
          v_precio := (v_e->>'precio')::numeric;
        exception when others then
          raise exception using errcode = 'MX005', message = format('Línea %s: la cantidad y el precio son números.', v_i);
        end;
        if v_precio is null or v_cant <= 0 or scale(v_cant) > 4 or scale(v_precio) > 4
           or (v_precio < 0 and v_tipo <> 'otro') or round(v_cant * v_precio, 2) = 0 or abs(v_cant * v_precio) > 9999999.99 then
          raise exception using errcode = 'MX005',
            message = format('Línea %s: la cantidad va de más de 0 y el precio no da cero, con cuatro decimales como mucho; un precio '
                             'negativo (un descuento) va solo en una línea de tipo «otro».', v_i);
        end if;
        v_lin := v_lin || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                   'tipo', v_tipo, 'descripcion', v_desc, 'detalle', nullif(btrim(v_e->>'detalle'), ''),
                   'cantidad', v_cant, 'unidad', nullif(btrim(v_e->>'unidad'), ''), 'precio', v_precio)));
      end loop;
    elsif v_nuevo then
      raise exception using errcode = '22023',
        message = 'Una factura T&M lleva sus líneas (lineas: [{descripcion, cantidad, precio, tipo?, unidad?, detalle?}]).';
    end if;
  else  -- retencion
    select coalesce(jsonb_agg(jsonb_build_object(
             'tipo', 'retencion',
             'descripcion', format('Retainage withheld on invoice %s (%s)', r.num, to_char(r.fecha, 'FMMon FMDD, YYYY')),
             'cantidad', 1, 'precio', r.saldo, 'ref', jsonb_build_object('factura_id', r.factura_id, 'numero', r.num))
             order by r.fecha, r.factura_id), '[]'::jsonb)
      into v_lin
      from fn_emision_retenido(v_obra) r;
    if jsonb_array_length(v_lin) = 0 then
      select string_agg(ed.numero, ', ' order by ed.numero) into v_txt
        from emision_documentos ed
       where ed.proyecto_id = v_obra and ed.forma = 'retencion' and ed.estado = 'emitida' and ed.anulado_el is null;
      raise exception using errcode = 'MX008',
        message = format('La obra «%s» no tiene retención por cobrar que reclamar%s.', pr.nombre,
                         coalesce(format(': lo retenido ya está reclamado en %s', v_txt), ' en el libro'));
    end if;
  end if;

  -- 4. La retención de esta factura
  if v_forma = 'retencion' then
    v_rpct := 0; v_rorig := 'ninguna';
  elsif p ? 'retencion_pct' and jsonb_typeof(p->'retencion_pct') <> 'null' then
    begin
      v_rpct := (p->>'retencion_pct')::numeric;
    exception when others then
      raise exception using errcode = 'MX005', message = 'La retención es un porcentaje (10 = 10 %).';
    end;
    if v_rpct is null or v_rpct < 0 or v_rpct >= 100 or scale(v_rpct) > 2 then
      raise exception using errcode = 'MX005', message = 'La retención va de 0 a menos de 100 %, con dos decimales como mucho.';
    end if;
    v_rorig := 'borrador';
  elsif p ? 'retencion_pct' or v_nuevo or d.retencion_origen <> 'borrador' then
    v_ret := fn_emision_retencion_de(v_obra);
    v_rpct := (v_ret->>'pct')::numeric; v_rorig := v_ret->>'origen';
    if v_rpct < 0 or v_rpct >= 100 then
      raise exception using errcode = 'MX005',
        message = format('La retención de la obra «%s» sale en %s %% y eso no vale: fíjala en la obra (10 = 10 %%).', pr.nombre,
                         trim_scale(v_rpct));
    end if;
  else
    v_rpct := d.retencion_pct; v_rorig := d.retencion_origen;
  end if;

  -- 5. A quién se factura
  v_dest := fn_emision_destinatario(v_obra);
  if p ? 'cliente' and jsonb_typeof(p->'cliente') = 'object' then
    select string_agg(k, ', ' order by k) into v_sobra
      from jsonb_object_keys(p->'cliente') k where k not in ('nombre', 'atencion', 'direccion', 'correo');
    if v_sobra is not null then
      raise exception using errcode = '22023',
        message = format('Clave desconocida en cliente: %s. Las que hay: nombre, atencion, direccion y correo.', v_sobra);
    end if;
    if exists (select 1 from jsonb_each(p->'cliente') e where jsonb_typeof(e.value) not in ('string', 'null') or length(e.value #>> '{}') > 300) then
      raise exception using errcode = '22023', message = 'Los datos del cliente son textos de hasta 300 letras.';
    end if;
    select coalesce(jsonb_object_agg(e.key, btrim(e.value #>> '{}')), '{}'::jsonb) into v_cli
      from jsonb_each(p->'cliente') e where nullif(btrim(e.value #>> '{}'), '') is not null;
  elsif p ? 'cliente' and jsonb_typeof(p->'cliente') <> 'null' then
    raise exception using errcode = '22023', message = 'cliente es un objeto {nombre, atencion, direccion, correo}, o null para el de la obra.';
  elsif p ? 'cliente' or v_nuevo
        or d.a_contratista is distinct from coalesce((v_dest->>'a_contratista')::boolean, false) then
    -- (nulo = el de la obra; y si la obra cambió de destinatario —del cliente al contratista o al revés—, también)
    v_cli := coalesce(v_dest->'cliente', '{}'::jsonb);
  else
    v_cli := d.cliente;
  end if;

  -- 6. Las notas
  if p ? 'notas' then
    v_notas := nullif(btrim(p->>'notas'), '');
    if length(coalesce(v_notas, '')) > 2000 then
      raise exception using errcode = '22023', message = 'Las notas llegan hasta 2000 letras.';
    end if;
  else
    v_notas := d.notas;
  end if;

  -- 7. Se escribe: el documento (si es nuevo), sus líneas y sus totales
  if v_nuevo then
    begin
      perform set_config('mx_emision.escribe', 'emision_documentos', true);
      insert into emision_documentos (forma, proyecto_id, hito_id, es_deposito, porcentaje, base, a_contratista, cliente, notas,
                                      retencion_pct, retencion_origen, creado_por, actualizado_por)
      values (v_forma, v_obra, v_hito, v_dep, case when v_forma = 'porcentaje' then v_pct end,
              case when v_forma = 'porcentaje' then v_base end, coalesce((v_dest->>'a_contratista')::boolean, false), v_cli, v_notas,
              v_rpct, v_rorig, auth.uid(), auth.uid())
      returning id into v_id;
      perform set_config('mx_emision.escribe', '', true);
    exception when unique_violation then
      perform set_config('mx_emision.escribe', '', true);
      raise exception using errcode = 'MX008',
        message = case when v_forma = 'hito' then 'Ya hay un borrador de ese hito (se abrió en otra pestaña): ábrelo.'
                       else 'Ya hay un borrador de la retención de esa obra (se abrió en otra pestaña): ábrelo.' end;
    end;
  end if;
  if v_lin is not null then
    perform set_config('mx_emision.escribe', 'emision_lineas', true);
    delete from emision_lineas where documento_id = v_id;
    insert into emision_lineas (documento_id, n, tipo, descripcion, detalle, cantidad, unidad, precio, importe, ref)
    select v_id, x.o, x.e->>'tipo', x.e->>'descripcion', x.e->>'detalle', (x.e->>'cantidad')::numeric, x.e->>'unidad',
           (x.e->>'precio')::numeric, round((x.e->>'cantidad')::numeric * (x.e->>'precio')::numeric, 2), x.e->'ref'
      from jsonb_array_elements(v_lin) with ordinality x(e, o);
    perform set_config('mx_emision.escribe', '', true);
  end if;
  select coalesce(sum(l.importe), 0) into v_monto from emision_lineas l where l.documento_id = v_id;
  if v_monto <= 0 or v_monto > 9999999.99 then
    raise exception using errcode = 'MX005',
      message = format('La factura tiene que sumar más de cero y hasta 9,999,999.99 (suma %s).', fn_emision_usd(v_monto));
  end if;
  v_reten := case when v_forma = 'retencion' then 0 else fn_emision_retencion(v_monto, v_rpct) end;
  perform set_config('mx_emision.escribe', 'emision_documentos', true);
  update emision_documentos
     set es_deposito      = v_dep,
         porcentaje       = case when v_forma = 'porcentaje' then v_pct end,
         base             = case when v_forma = 'porcentaje' then v_base end,
         a_contratista    = coalesce((v_dest->>'a_contratista')::boolean, false),
         cliente          = v_cli,
         notas            = v_notas,
         retencion_pct    = v_rpct,
         retencion_origen = v_rorig,
         monto            = v_monto,
         retencion        = v_reten,
         a_pagar          = v_monto - v_reten,
         actualizado_el   = clock_timestamp(),
         actualizado_por  = auth.uid()
   where id = v_id;
  perform set_config('mx_emision.escribe', '', true);
  return fn_emision_documento(v_id) || jsonb_build_object('nuevo', v_nuevo);
end $$;
revoke execute on function public.fn_emision_borrador(jsonb) from public, anon, service_role;
grant  execute on function public.fn_emision_borrador(jsonb) to authenticated;
comment on function public.fn_emision_borrador(jsonb) is 'c11: crea, cambia o refresca un borrador de factura. p: {documento? (el que se cambia), forma (hito | porcentaje | tm | retencion), proyecto_id, hito_id, porcentaje, lineas: [{descripcion, cantidad?, precio, tipo?, unidad?, detalle?}], descripcion, detalle, retencion_pct (nulo = el de la obra), cliente: {nombre, atencion, direccion, correo} (nulo = el de la obra), notas}. El de un hito y el de la retención de una obra son uno solo (si ya hay, se abre ese). Cada llamada vuelve a leer el hito, el contrato, lo retenido y la retención de la obra: con solo «documento», refresca. Solo se factura un hito pendiente: el ya cobrado, el ya facturado aquí y el que la ficha tiene como facturado sin factura viva aquí dan MX008 (si es por una factura que se anuló, dice cuál y qué hacer). Devuelve fn_emision_documento y {nuevo}. 22023, MX005, MX008. Solo el dueño.';

-- TIRAR UN BORRADOR (no llegó a ser factura: no deja nada).
create or replace function public.fn_emision_descartar(p_documento uuid) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  d emision_documentos;
begin
  perform fn_emision_exigir_dueno();
  select * into d from emision_documentos where id = p_documento for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese borrador.';
  end if;
  if d.estado <> 'borrador' then
    raise exception using errcode = 'MX008',
      message = format('La factura %s ya se emitió: no se tira. Si está mal, se anula con su nota de crédito.', d.numero);
  end if;
  perform set_config('mx_emision.escribe', 'emision_lineas', true);
  delete from emision_lineas where documento_id = d.id;
  perform set_config('mx_emision.escribe', 'emision_documentos', true);
  delete from emision_documentos where id = d.id;
  perform set_config('mx_emision.escribe', '', true);
  return jsonb_build_object('documento', d.id, 'descartado', true);
end $$;
revoke execute on function public.fn_emision_descartar(uuid) from public, anon, service_role;
grant  execute on function public.fn_emision_descartar(uuid) to authenticated;
comment on function public.fn_emision_descartar(uuid) is 'c11: tira un borrador (y sus líneas). Una factura emitida no se tira: MX008. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 6. LOS AJUSTES Y LA RETENCIÓN DE UNA OBRA
-- ---------------------------------------------------------------------
-- LOS AJUSTES. p: {corte: «AAAA-MM-DD», serie_formato, terminos_dias,
-- terminos_texto, empresa: {nombre, licencia, direccion, telefono, correo,
-- web} (sustituye entero), como_pagar, ach, tarjeta_pct, cuenta_recargo,
-- pdf_dias}; solo cambia lo que llega. Devuelve los ajustes como quedaron,
-- con tarjeta_lista, tarjeta_texto (por qué la tarjeta está apagada) y, si
-- mover el corte cambia HOY por dónde se factura, aviso.
create or replace function public.fn_emision_config(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_sobra  text;
  v_corte  date;
  v_fmt    text;
  v_dias   int;
  v_pdf    int;
  v_emp    jsonb;
  v_tar    numeric;
  v_cta    text;
  v_k      cuentas;
  v_min    date;
  v_antes  date;
  v_hoy    date := fn_fecha_miami(now());
  v_aviso  text;
  c        emision_config;
begin
  perform fn_emision_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'Los ajustes llegan como un objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p) k
   where k not in ('corte', 'serie_formato', 'terminos_dias', 'terminos_texto', 'empresa', 'como_pagar', 'ach', 'tarjeta_pct',
                   'cuenta_recargo', 'pdf_dias');
  if v_sobra is not null then
    raise exception using errcode = '22023',
      message = format('Clave desconocida en los ajustes: %s. Las que hay: corte, serie_formato, terminos_dias, terminos_texto, '
                       'empresa, como_pagar, ach, tarjeta_pct, cuenta_recargo y pdf_dias.', v_sobra);
  end if;
  if p ? 'corte' then
    if coalesce(p->>'corte', '') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
      raise exception using errcode = '22007', message = 'El corte es una fecha AAAA-MM-DD (por ejemplo 2027-01-01).';
    end if;
    begin
      v_corte := (p->>'corte')::date;
    exception when others then
      raise exception using errcode = '22007', message = format('«%s» no es una fecha.', p->>'corte');
    end;
    if v_corte < date '2026-10-01' then
      raise exception using errcode = 'MX008', message = 'El corte no puede ser anterior al 1-oct-2026 (el día en que empieza el libro).';
    end if;
    -- (solo cuentan las emitidas y SIN ANULAR: una emisión de prueba, anulada, no deja el corte sin vuelta atrás)
    select min(d.fecha) into v_min
      from emision_documentos d
      left join facturas f on f.id = d.factura_id
     where d.estado = 'emitida' and d.anulado_el is null and coalesce(f.estado, 'emitida') <> 'anulada';
    if v_min is not null and v_corte > v_min then
      raise exception using errcode = 'MX008',
        message = format('Hay facturas emitidas por la app (y sin anular) desde el %s: el corte no se pone después de esa fecha. Si '
                         'fueron de prueba, anúlalas primero.', fn_emision_dia(v_min));
    end if;
    -- Mover el corte de forma que cambie HOY por dónde se factura: se dice (no se frena).
    select x.corte into v_antes from emision_config x where x.id = 1;
    if v_corte <= v_hoy and v_antes > v_hoy then
      v_aviso := format('Desde hoy el 🧾 de cada hito abre la factura aquí y ya NO manda a QuickBooks (el corte estaba en el %s). Si es '
                        'solo para probar, vuelve a poner el corte en su día cuando termines; y si emites una de verdad, mientras '
                        'esté viva (sin anular) el corte ya no se puede poner después de su fecha.', fn_emision_dia(v_antes));
    elsif v_corte > v_hoy and v_antes <= v_hoy then
      v_aviso := format('El corte queda en el %s: hasta entonces el 🧾 vuelve a mandar a QuickBooks, y aquí solo se preparan '
                        'borradores.', fn_emision_dia(v_corte));
    end if;
  end if;
  if p ? 'serie_formato' then
    v_fmt := btrim(coalesce(p->>'serie_formato', ''));
    if v_fmt !~ '^[A-Z0-9]{1,8}-AAAA-NNNN$' then
      raise exception using errcode = '22023',
        message = 'El formato del número es un prefijo de 1 a 8 letras o cifras, el año y el consecutivo: MXP-AAAA-NNNN.';
    end if;
    if v_fmt is distinct from (select x.serie_formato from emision_config x where x.id = 1)
       and exists (select 1 from emision_serie) then
      raise exception using errcode = 'MX008',
        message = 'Ya hay facturas emitidas con el formato de ahora: el formato del número no se cambia a media serie.';
    end if;
  end if;
  if p ? 'terminos_dias' then
    begin
      v_dias := (p->>'terminos_dias')::int;
    exception when others then
      v_dias := null;
    end;
    if v_dias is null or v_dias < 0 or v_dias > 120 then
      raise exception using errcode = 'MX005', message = 'Los días para pagar van de 0 (al recibirla) a 120.';
    end if;
  end if;
  if p ? 'pdf_dias' then
    begin
      v_pdf := (p->>'pdf_dias')::int;
    exception when others then
      v_pdf := null;
    end;
    if v_pdf is null or v_pdf < 0 or v_pdf > 60 then
      raise exception using errcode = 'MX005', message = 'Los días para avisar de una factura sin PDF van de 0 a 60.';
    end if;
  end if;
  if (p ? 'terminos_texto' and length(coalesce(p->>'terminos_texto', '')) > 2000)
     or (p ? 'como_pagar' and length(coalesce(p->>'como_pagar', '')) > 2000) then
    raise exception using errcode = '22023', message = 'Los términos y el «How to pay» llegan hasta 2000 letras cada uno.';
  end if;
  if p ? 'empresa' then
    v_emp := p->'empresa';
    if jsonb_typeof(v_emp) <> 'object' then
      raise exception using errcode = '22023', message = 'empresa es un objeto {nombre, licencia, direccion, telefono, correo, web}.';
    end if;
    select string_agg(k, ', ' order by k) into v_sobra
      from jsonb_object_keys(v_emp) k where k not in ('nombre', 'licencia', 'direccion', 'telefono', 'correo', 'web');
    if v_sobra is not null then
      raise exception using errcode = '22023',
        message = format('Clave desconocida en empresa: %s. Las que hay: nombre, licencia, direccion, telefono, correo y web.', v_sobra);
    end if;
    if exists (select 1 from jsonb_each(v_emp) e where jsonb_typeof(e.value) not in ('string', 'null') or length(e.value #>> '{}') > 300) then
      raise exception using errcode = '22023', message = 'Los datos de la empresa son textos de hasta 300 letras.';
    end if;
    select coalesce(jsonb_object_agg(e.key, btrim(e.value #>> '{}')), '{}'::jsonb) into v_emp
      from jsonb_each(v_emp) e where nullif(btrim(e.value #>> '{}'), '') is not null;
  end if;
  if p ? 'ach' and jsonb_typeof(p->'ach') <> 'boolean' then
    raise exception using errcode = '22023', message = 'ach es true o false.';
  end if;
  if p ? 'tarjeta_pct' and jsonb_typeof(p->'tarjeta_pct') <> 'null' then
    begin
      v_tar := (p->>'tarjeta_pct')::numeric;
    exception when others then
      v_tar := null;
    end;
    if v_tar is null or v_tar <= 0 or v_tar > 10 or scale(v_tar) > 3 then
      raise exception using errcode = 'MX005', message = 'El porcentaje de la tarjeta va de más de 0 a 10, con tres decimales como mucho.';
    end if;
    if not fn_emision_tarjeta_lista() then
      raise exception using errcode = 'MX008', message = fn_emision_tarjeta_texto();
    end if;
  end if;
  if p ? 'cuenta_recargo' and nullif(btrim(p->>'cuenta_recargo'), '') is not null then
    v_cta := btrim(p->>'cuenta_recargo');
    select * into v_k from cuentas k where k.codigo = v_cta;
    if not found then
      raise exception using errcode = 'MX004', message = format('La cuenta %s no existe.', v_cta);
    end if;
    if not v_k.activa or not v_k.imputable or v_k.regla_obra = 'obligatoria'
       or v_k.tipo not in ('ingreso', 'otro_ingreso', 'gasto', 'otro_gasto') then
      raise exception using errcode = 'MX004',
        message = format('La cuenta %s (%s) no sirve para el recargo de la tarjeta: tiene que ser una cuenta activa de ingreso o de '
                         'gasto, de las que reciben asientos y no piden obra.', v_k.codigo, v_k.nombre);
    end if;
  end if;
  perform set_config('mx_emision.escribe', 'emision_config', true);
  update emision_config
     set corte           = case when p ? 'corte' then v_corte else corte end,
         serie_formato   = case when p ? 'serie_formato' then v_fmt else serie_formato end,
         terminos_dias   = case when p ? 'terminos_dias' then v_dias else terminos_dias end,
         terminos_texto  = case when p ? 'terminos_texto' then btrim(coalesce(p->>'terminos_texto', '')) else terminos_texto end,
         empresa         = case when p ? 'empresa' then v_emp else empresa end,
         como_pagar      = case when p ? 'como_pagar' then btrim(coalesce(p->>'como_pagar', '')) else como_pagar end,
         ach             = case when p ? 'ach' then (p->>'ach')::boolean else ach end,
         tarjeta_pct     = case when p ? 'tarjeta_pct' then v_tar else tarjeta_pct end,
         cuenta_recargo  = case when p ? 'cuenta_recargo' then v_cta else cuenta_recargo end,
         pdf_dias        = case when p ? 'pdf_dias' then v_pdf else pdf_dias end,
         actualizado     = now(),
         actualizado_por = auth.uid()
   where id = 1
  returning * into c;
  perform set_config('mx_emision.escribe', '', true);
  return to_jsonb(c) || jsonb_strip_nulls(jsonb_build_object('tarjeta_lista', fn_emision_tarjeta_lista(),
                                                             'tarjeta_texto', fn_emision_tarjeta_texto(), 'aviso', v_aviso));
end $$;
revoke execute on function public.fn_emision_config(jsonb) from public, anon, service_role;
grant  execute on function public.fn_emision_config(jsonb) to authenticated;
comment on function public.fn_emision_config(jsonb) is 'c11: cambia los ajustes de la facturación ({corte, serie_formato, terminos_dias, terminos_texto, empresa: {nombre, licencia, direccion, telefono, correo, web}, como_pagar, ach, tarjeta_pct, cuenta_recargo, pdf_dias}; solo lo que llega) y los devuelve. Devuelve además tarjeta_lista, tarjeta_texto (por qué la tarjeta está apagada, en llano) y, si mover el corte cambia hoy por dónde se factura, aviso. El corte no va antes del 1-oct-2026 ni después de la primera factura emitida y sin anular; el formato no cambia a media serie; el porcentaje de la tarjeta no se deja poner mientras la tarjeta esté apagada (MX008, con ese texto). 22023, 22007, MX004, MX005, MX008. Solo el dueño.';

-- LA RETENCIÓN DE UNA OBRA. p: {proyecto_id, retencion_pct (10 = 10 %; null
-- = la del estimado enlazado o ninguna; 0 = sin retención), nota}.
create or replace function public.fn_emision_obra(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_sobra text;
  v_obra  text;
  v_pct   numeric;
  v_nota  text;
  o       emision_obras;
begin
  perform fn_emision_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'Lo de la obra llega como un objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p) k where k not in ('proyecto_id', 'retencion_pct', 'nota');
  if v_sobra is not null then
    raise exception using errcode = '22023',
      message = format('Clave desconocida: %s. Las que hay: proyecto_id, retencion_pct y nota.', v_sobra);
  end if;
  v_obra := nullif(btrim(p->>'proyecto_id'), '');
  if v_obra is null or not exists (select 1 from proyectos x where x.id = v_obra) then
    raise exception using errcode = '22023', message = format('La obra %s no existe.', coalesce(v_obra, '(ninguna)'));
  end if;
  if p ? 'retencion_pct' and jsonb_typeof(p->'retencion_pct') <> 'null' then
    begin
      v_pct := (p->>'retencion_pct')::numeric;
    exception when others then
      v_pct := -1;
    end;
    if v_pct is null or v_pct < 0 or v_pct >= 100 or scale(v_pct) > 2 then
      raise exception using errcode = 'MX005',
        message = 'La retención de la obra es un porcentaje de 0 a menos de 100, con dos decimales como mucho (10 = 10 %).';
    end if;
  end if;
  v_nota := nullif(btrim(p->>'nota'), '');
  if length(coalesce(v_nota, '')) > 500 then
    raise exception using errcode = '22023', message = 'La nota llega hasta 500 letras.';
  end if;
  perform set_config('mx_emision.escribe', 'emision_obras', true);
  insert into emision_obras (proyecto_id, retencion_pct, nota, actualizado_por)
  values (v_obra, v_pct, v_nota, auth.uid())
  on conflict (proyecto_id) do update
     set retencion_pct   = case when p ? 'retencion_pct' then excluded.retencion_pct else emision_obras.retencion_pct end,
         nota            = case when p ? 'nota' then excluded.nota else emision_obras.nota end,
         actualizado     = now(),
         actualizado_por = auth.uid()
  returning * into o;
  perform set_config('mx_emision.escribe', '', true);
  return to_jsonb(o) || jsonb_build_object('retencion', fn_emision_retencion_de(v_obra));
end $$;
revoke execute on function public.fn_emision_obra(jsonb) from public, anon, service_role;
grant  execute on function public.fn_emision_obra(jsonb) to authenticated;
comment on function public.fn_emision_obra(jsonb) is 'c11: fija la retención de una obra ({proyecto_id, retencion_pct: 10 = 10 %, null = la del estimado enlazado o ninguna, 0 = sin retención; nota}) y devuelve la fila y la retención que vale ({pct, origen}). Los borradores de esa obra que no traen su propio porcentaje lo dicen al refrescarse. 22023, MX005. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 7. EMITIR Y ANULAR
-- ---------------------------------------------------------------------
-- EMITIR un borrador: todo o nada, en esta transacción.
--   p_visto     la huella que traía el borrador (fn_emision_documento →
--               visto): si ya no es la de hoy, MX011 y no pasa nada
--   p_opciones  {idioma_revisado: true} = «sí, ese texto que parece español
--               está bien así»
-- El orden de los candados: el documento, su obra (un candado por obra: dos
-- emisiones de la misma obra van de una en una; la anulación toma el
-- mismo), su hito y las facturas ANULADAS que todavía lo apuntan (o, en la
-- de retención, las facturas de la obra), los ajustes (compartido: no
-- cambian a media emisión), el contador del año, y solo entonces el libro
-- (los períodos y la cadena los toma el puente de c3). Dos emisiones del
-- mismo borrador, o de dos borradores del mismo hito, se esperan: la
-- segunda ve lo que dejó la primera y para con MX008. Dos de la misma obra:
-- la segunda ya no es lo que se vio (cambiaron su ordinal y lo facturado
-- antes) y para con MX011.
-- EL HITO QUE SE VUELVE A FACTURAR (cabecera): justo antes de crear la fila
-- de facturas, las filas ANULADAS que todavía apuntan a ese hito —las que
-- emitió la app y las de fuera, de QuickBooks— lo SUELTAN (hito_id a nulo;
-- en lo demás no cambian) y queda apuntado en emision_soltados. La base de
-- la app admite una sola fila de facturas por hito, también contando las
-- anuladas: sin esto, después de anular no entraba la buena. Todo en esta
-- transacción: si la emisión no llega al final, la anulada conserva su hito.
create or replace function public.fn_emision_emitir(p_documento uuid, p_visto text, p_opciones jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  d        emision_documentos;
  cfg      emision_config;
  v_hoy    date;
  v_sobra  text;
  v_rev    jsonb;
  a        jsonb;
  v_anio   int;
  v_serie  text;
  v_prev   bigint;
  v_salt   jsonb;
  v_num    text;
  v_sec    int;
  v_fid    bigint;
  v_asi    uuid;
  v_asi_n  text;
  v_fc     date;
  v_motivo text;
  v_s1     numeric;
  v_s2     numeric;
  v_s3     numeric;
  v_hito   text;
  v_vista  jsonb;
  v_cont   jsonb;
  v_huella text;
  v_an     record;
  v_k      bigint;
  v_sol    jsonb;
  v_idx    text;
  v_det    text;
begin
  perform fn_emision_exigir_dueno();
  if p_documento is null then
    raise exception using errcode = '22023', message = 'Di qué borrador se emite.';
  end if;
  if p_opciones is not null and jsonb_typeof(p_opciones) <> 'object' then
    raise exception using errcode = '22023', message = 'Las opciones llegan como un objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(coalesce(p_opciones, '{}'::jsonb)) k where k not in ('idioma_revisado');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Opción desconocida: %s. La que hay: idioma_revisado.', v_sobra);
  end if;

  -- 1. El documento, y lo que la emisión mira, tomados antes de mirar nada
  select * into d from emision_documentos where id = p_documento for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese borrador.';
  end if;
  if d.estado <> 'borrador' then
    raise exception using errcode = 'MX008',
      message = format('Ese borrador ya se emitió: es la factura %s del %s%s. No se emite dos veces.', d.numero, fn_emision_dia(d.fecha),
                       case when d.anulado_el is not null then ' (anulada)' else '' end);
  end if;
  -- (la obra: sus emisiones y sus anulaciones, de una en una. La segunda mira lo que dejó la primera)
  perform pg_advisory_xact_lock(820261111, hashtext('obra:' || d.proyecto_id));
  if d.hito_id is not null then
    perform 1 from hitos x where x.id = d.hito_id for update;
    -- (y las facturas ANULADAS que todavía apuntan a ese hito: más abajo lo sueltan)
    perform 1 from facturas f where f.hito_id = d.hito_id and f.estado = 'anulada' order by f.id for update;
  end if;
  if d.forma = 'retencion' then
    perform 1 from facturas f where f.proyecto_id = d.proyecto_id order by f.id for update;
  end if;
  -- (los ajustes, quietos hasta confirmar: lo que se congela es lo que el visto vio)
  select * into cfg from emision_config where id = 1 for share;
  v_hoy := fn_fecha_miami(now());

  -- 2. Es lo que Edgar vio (la vista previa entera: el documento, sus líneas, los ajustes, la fecha, el ordinal, lo
  --    facturado antes y lo retenido a la fecha), y nada lo frena
  v_vista := fn_emision_contenido(d.id, null, null, null);
  if p_visto is null or p_visto is distinct from fn_emision_visto(d.id) then
    raise exception using errcode = 'MX011',
      message = 'El borrador ya no es el que viste (cambió en otra pestaña, cambiaron los ajustes de la factura, entró o se anuló '
                'otra factura de esta obra, o lo miraste otro día): no se emitió nada. Vuelve a mirarlo y emite otra vez.';
  end if;
  v_rev := fn_emision_revisar(d.id);
  for a in select value from jsonb_array_elements(v_rev) loop
    if (a->>'frena')::boolean
       and not (a->>'codigo' = 'en_espanol' and coalesce((p_opciones->>'idioma_revisado')::boolean, false)) then
      raise exception using
        errcode = case when a->>'codigo' like '%\_cambio' then 'MX011' else 'MX008' end,
        message = a->>'texto';
    end if;
  end loop;

  -- 3. Su número: el siguiente del año, sin huecos (el trigger de la serie). Las facturas llevan la serie del año
  --    (MXP-AAAA-NNNN); la factura de la retención, que no es una fila de facturas, la suya (MXP-R-AAAA-NNNN): así cada
  --    número de la serie de las facturas ES una fila de facturas.
  v_anio  := extract(year from v_hoy)::int;
  v_serie := case when d.forma = 'retencion' then 'retenciones' else 'facturas' end;
  select coalesce((select c.ultimo from contadores c where c.serie = v_serie || '-' || v_anio), 0) into v_prev;
  perform set_config('mx_emision.escribe', 'emision_serie', true);
  insert into emision_serie (serie, anio, documento_id, creado_por) values (v_serie, v_anio, d.id, auth.uid())
  returning numero, secuencia into v_num, v_sec;
  perform set_config('mx_emision.escribe', '', true);
  -- (los números que la serie saltó porque ya los llevaba una factura hecha fuera de la app: se dicen)
  if v_sec > v_prev + 1 then
    select jsonb_agg(fn_emision_numero(fn_emision_formato(cfg.serie_formato, v_serie), v_anio, k.k) order by k.k) into v_salt
      from generate_series(v_prev::int + 1, v_sec - 1) k(k)
     where not exists (select 1 from emision_serie s where s.serie = v_serie and s.anio = v_anio and s.secuencia = k.k);
  end if;

  -- 4. La factura, ya emitida, y su asiento (el puente de c3, adelantado)
  if d.forma <> 'retencion' then
    -- (una red: el trigger de la serie ya saltó los números que lleva otra factura, de la obra que sea)
    if exists (select 1 from facturas f where f.num = v_num) then
      raise exception using errcode = 'MX008',
        message = format('Ya hay una factura con el número %s (no salió de aquí): no se emitió nada. Avisa antes de seguir.', v_num);
    end if;
    -- EL HITO QUE SE VUELVE A FACTURAR: las filas de facturas ANULADAS que todavía apuntan a este hito lo sueltan (la base de
    -- la app admite una sola fila de facturas por hito, también contando las anuladas), y queda apuntado cuál, de qué hito y
    -- por qué documento. Siguen anuladas, con su nota de crédito y su asiento: su puente no asienta nada por esto (ni el
    -- hito ni el estado entran en su firma) y lo cobrado no cambia.
    if d.forma = 'hito' then
      for v_an in
        select f.id, f.num, f.proyecto_id,
               (select n.numero from notas_credito n where n.anula_a = f.id) as nota,
               exists (select 1 from emision_documentos x where x.factura_id = f.id) as de_la_app
          from facturas f
         where f.hito_id = d.hito_id and f.estado = 'anulada'
         order by f.id
      loop
        update facturas set hito_id = null where id = v_an.id and estado = 'anulada';
        get diagnostics v_k = row_count;
        if v_k <> 1 then
          raise exception using errcode = 'MX008',
            message = format('No se emitió nada (ni se gastó el número %s): la factura anulada %s sigue figurando como la de este hito y '
                             'la base no dejó cambiarlo. Avisa antes de seguir.', v_num, v_an.num);
        end if;
        perform set_config('mx_emision.escribe', 'emision_soltados', true);
        insert into emision_soltados (factura_id, num, hito_id, proyecto_id, nota_credito, de_la_app, documento_id, soltado_por)
        values (v_an.id, v_an.num, d.hito_id, v_an.proyecto_id, v_an.nota, v_an.de_la_app, d.id, auth.uid());
        perform set_config('mx_emision.escribe', '', true);
        v_sol := coalesce(v_sol, '[]'::jsonb)
                 || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('factura_id', v_an.id, 'numero', v_an.num,
                                                                           'nota_credito', v_an.nota, 'de_la_app', v_an.de_la_app)));
      end loop;
    end if;
    -- (si en este mismo momento entró por otro lado una fila de facturas de este hito, o con este número —la función de
    -- QuickBooks, durante el paralelo—, los índices únicos de facturas paran a la segunda: aquí, dicho en llano)
    -- (QUÉ índice la paró va en el DETALLE del error, fuera del texto en llano: la pantalla no lo enseña, y queda en la
    -- respuesta de la API y en el registro de la base. Si un día la base tuviera otro índice único que la emisión no
    -- cumple, este MX011 saldría siempre: así se sabe cuál es)
    begin
      insert into facturas (proyecto_id, num, fecha, monto, pagada, hito_id, a_contratista, estado, retencion)
      values (d.proyecto_id, v_num, v_hoy, d.monto, false, d.hito_id, d.a_contratista, 'emitida', d.retencion)
      returning id into v_fid;
    exception when unique_violation then
      get stacked diagnostics v_idx = constraint_name, v_det = pg_exception_detail;
      raise exception using errcode = 'MX011',
        message = format('No se emitió nada (ni se gastó el número %s): mientras se emitía entró por otro lado una factura %s (¿se '
                         'facturó a la vez en QuickBooks?). Vuelve a mirar el borrador: si %s, tíralo.', v_num,
                         case when d.forma = 'hito' then 'de este mismo hito, o con ese número' else 'con ese mismo número' end,
                         case when d.forma = 'hito' then 'el hito ya quedó facturado' else 'ya está facturado' end),
        detail  = format('La fila de facturas chocó con el índice único «%s» de la base%s.', coalesce(nullif(v_idx, ''), '(sin nombre)'),
                         coalesce(' (' || nullif(v_det, '') || ')', ''));
    end;
    select f.contabilizado_en into v_asi from facturas f where f.id = v_fid;
    if v_asi is null then
      -- (el puente de c3 corre al confirmar: aquí, ya; y vuelve a quedar diferido)
      set constraints public.trg_puente_facturas_despues immediate;
      set constraints public.trg_puente_facturas_despues deferred;
      select f.contabilizado_en into v_asi from facturas f where f.id = v_fid;
    end if;
    if v_asi is null then
      select pd.motivo into v_motivo from puente_documentos pd where pd.tabla = 'facturas' and pd.documento_id = v_fid::text;
      raise exception using errcode = 'MX008',
        message = format('No se emitió nada (ni se gastó el número %s): el libro no aceptó la factura. %s', v_num,
                         coalesce(v_motivo, 'El puente de las facturas no dijo por qué: mira la bandeja de los puentes en Contabilidad.'));
    end if;
    -- al centavo: 1110 lo que se paga ahora, 1120 lo retenido, y el ingreso
    select coalesce(sum(l.monto) filter (where l.cuenta = fn_emision_cuenta('cxc') and l.partida_tabla = 'facturas'
                                           and l.partida_id = v_fid::text), 0),
           coalesce(sum(l.monto) filter (where l.cuenta = fn_emision_cuenta('retencion_cxc') and l.partida_tabla = 'facturas'
                                           and l.partida_id = v_fid::text), 0),
           coalesce(sum(l.monto) filter (where l.monto < 0), 0)
      into v_s1, v_s2, v_s3
      from asiento_lineas l where l.asiento_id = v_asi;
    if v_s1 <> d.a_pagar or v_s2 <> d.retencion or v_s3 <> -d.monto then
      raise exception using errcode = 'MX001',
        message = format('No se emitió nada: el asiento de la factura %s no es el que toca (por cobrar %s y debía ser %s; retención %s '
                         'y debía ser %s; ingreso %s y debía ser %s). Avisa: no debería pasar.', v_num, v_s1, d.a_pagar, v_s2,
                         d.retencion, -v_s3, d.monto);
    end if;
    select x.numero, x.fecha_contable into v_asi_n, v_fc from asientos x where x.id = v_asi;
  end if;

  -- 5. El hito, como lo mueve el 🧾: a facturado (nunca uno ya cobrado)
  if d.forma = 'hito' then
    update hitos set estado = 'facturado' where id = d.hito_id and estado is distinct from 'cobrado';
    select x.estado into v_hito from hitos x where x.id = d.hito_id;
  end if;

  -- 6. El contenido, congelado, y el sello. Lo que se congela ES lo que se vio, salvo el número: se comprueba (si algo de
  --    la obra cambió entre que se miró y este punto —un cobro, el contrato—, no se emite).
  v_cont := fn_emision_contenido(d.id, v_num, v_hoy, v_fid);
  if (v_cont - 'numero') is distinct from v_vista then
    raise exception using errcode = 'MX011',
      message = 'Algo de la obra cambió mientras se emitía (otra factura, un cobro, el contrato): no se emitió nada. Vuelve a mirar '
                'el borrador y emite otra vez.';
  end if;
  v_huella := encode(sha256(convert_to(v_cont::text, 'UTF8')), 'hex');
  perform set_config('mx_emision.escribe', 'emision_documentos', true);
  update emision_documentos
     set estado = 'emitida', numero = v_num, anio = v_anio, secuencia = v_sec, fecha = v_hoy, vence = v_hoy + cfg.terminos_dias,
         factura_id = v_fid, asiento_id = v_asi, contenido = v_cont, huella = v_huella,
         emitido_el = clock_timestamp(), emitido_por = auth.uid(), actualizado_el = clock_timestamp(), actualizado_por = auth.uid()
   where id = d.id;
  perform set_config('mx_emision.escribe', '', true);

  return jsonb_strip_nulls(jsonb_build_object(
    'documento', d.id, 'estado', 'emitida', 'numero', v_num, 'fecha', v_hoy, 'vence', v_hoy + cfg.terminos_dias,
    'monto', d.monto, 'retencion', d.retencion, 'a_pagar', d.a_pagar,
    'factura_id', v_fid, 'asiento', v_asi_n, 'fecha_contable', v_fc,
    'tardio', case when v_fc is not null and v_fc <> v_hoy
                   then format('El mes de hoy ya estaba cerrado: el asiento entró el %s.', fn_emision_dia(v_fc)) end,
    'hito_id', d.hito_id, 'hito_estado', v_hito, 'huella', v_huella,
    'soltadas', v_sol,
    'saltados', v_salt,
    'aviso', case when v_salt is not null
                  then format('La serie saltó %s: ya lo(s) llevaba una factura hecha fuera de la app (un número no se da dos veces). '
                              'El control de la facturación dice cuál.',
                              (select string_agg(x.x, ', ') from jsonb_array_elements_text(v_salt) x(x))) end,
    'sigue', 'El PDF y el envío: la función de facturas lo pinta con este contenido, lo sube y lo registra.'));
end $$;
revoke execute on function public.fn_emision_emitir(uuid, text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_emision_emitir(uuid, text, jsonb) to authenticated;
comment on function public.fn_emision_emitir(uuid, text, jsonb) is 'c11: emite un borrador, todo o nada: comprueba que es el que Edgar vio (p_visto, la huella de la vista previa entera; si no, MX011) y que nada lo frena (el corte, los datos de la empresa, el hito, la regla de ingreso…: MX008; algo que cambió: MX011); le da el siguiente número de su serie del año, sin huecos (saltando el que ya lleve una factura hecha fuera de la app: lo dice en saltados); si el hito ya tuvo una factura que se anuló y todavía lo apunta, esa fila anulada lo suelta (queda apuntado en emision_soltados; sigue anulada) para que entre la nueva; crea la fila de facturas ya emitida (si en ese momento entró por otro lado una del mismo hito o con ese número, MX011, con el índice que chocó en el detalle del error), adelanta el puente de c3 y comprueba su asiento al centavo (si el libro no la acepta, MX008 con el porqué y no queda nada); mueve el hito a facturado; y congela el contenido con su huella (lo que se vio, salvo el número). Dos emisiones de la misma obra van de una en una. p_opciones: {idioma_revisado}. Devuelve {documento, numero, fecha, vence, monto, retencion, a_pagar, factura_id, asiento, hito_estado, huella, soltadas?: [{factura_id, numero, nota_credito, de_la_app}], saltados?, aviso?}. Solo el dueño.';

-- ANULAR una factura emitida: con su nota de crédito, por c3
-- (fn_factura_anular: NC-AAAA-NNNN, el espejo de su asiento, y sus frenos
-- —no la de la apertura…—, que salen tal cual).
-- Aquí: el documento queda marcado (cuándo, quién, por qué, su nota) y su
-- hito vuelve a pendiente si no le queda otra factura viva. La de retención
-- no tiene asiento: solo se marca. Si la factura ya se anuló desde
-- Contabilidad (c3 directo), esto termina lo de aquí. Y NO se anula (MX008,
-- en llano y con qué hacer):
--   · una factura cuya retención está reclamada en una factura de la
--     retención viva: primero se anula aquella;
--   · una factura con un pago por cuenta de banco EMPEZADO O EN CAMINO (los
--     cobros en línea): ese dinero llegaría a una factura anulada, quedaría
--     de anticipo de la obra, y la factura buena seguiría debiendo entera
--     aunque el cliente ya pagó. Se espera a que el pago entre o falle;
--   · una factura con cobros aplicados (el freno es de c3; aquí se dice sin
--     nombres de funciones): la nota de crédito por una parte no existe
--     todavía (cabecera, «Lo que NO hace»).
create or replace function public.fn_emision_anular(p_documento uuid, p_motivo text, p_fecha date default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  d       emision_documentos;
  v_fest  text;
  v_res   jsonb;
  v_nc    text;
  v_ya    boolean := false;
  v_hito  text;
  v_ret   text;
  v_np    bigint;
  v_nec   bigint;
  v_mp    numeric;
  v_cob   numeric;
  v_enl   jsonb;
begin
  perform fn_emision_exigir_dueno();
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Anular una factura dice por qué (el motivo): queda escrito con ella.';
  end if;
  select * into d from emision_documentos where id = p_documento for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa factura.';
  end if;
  if d.estado = 'borrador' then
    raise exception using errcode = 'MX008', message = 'Un borrador no se anula: se tira (todavía no es una factura).';
  end if;
  if d.anulado_el is not null then
    raise exception using errcode = 'MX008',
      message = format('La factura %s ya estaba anulada%s.', d.numero, coalesce(' (' || d.nota_credito || ')', ''));
  end if;
  -- (la obra, como al emitir: una emisión de la misma obra espera, y mira lo que deja esta anulación)
  perform pg_advisory_xact_lock(820261111, hashtext('obra:' || d.proyecto_id));
  -- (el hito antes que el libro: el mismo orden que al emitir)
  if d.forma = 'hito' and d.hito_id is not null then
    perform 1 from hitos x where x.id = d.hito_id for update;
  end if;
  if d.factura_id is not null then
    select f.estado into v_fest from facturas f where f.id = d.factura_id;
    -- lo retenido de esta factura está reclamado en una factura de la retención viva: primero se anula aquella
    select string_agg(distinct r.numero, ', ') into v_ret
      from emision_documentos r
      join emision_lineas rl on rl.documento_id = r.id
     where r.forma = 'retencion' and r.estado = 'emitida' and r.anulado_el is null and rl.ref->>'factura_id' = d.factura_id::text;
    if v_ret is not null and v_fest is distinct from 'anulada' then
      raise exception using errcode = 'MX008',
        message = format('Lo retenido de la factura %s está reclamado en la factura de la retención %s: anula antes la de la retención (y '
                         'haz otra después), o deja esta como está.', d.numero, v_ret);
    end if;
    if v_fest = 'anulada' then
      v_ya := true;
      select n.numero into v_nc from notas_credito n where n.anula_a = d.factura_id;
    else
      -- UN PAGO EN LÍNEA EMPEZADO O EN CAMINO: no se anula ahora
      select count(*), count(*) filter (where s.estado = 'en_camino'), coalesce(sum(s.monto), 0) into v_np, v_nec, v_mp
        from fn_emision_pagos() s
       where s.factura_id = d.factura_id and s.estado in ('iniciado', 'en_camino');
      if v_np > 0 then
        raise exception using errcode = 'MX008',
          message = format('La factura %s tiene un pago por cuenta de banco %s (%s): no se anula ahora. Ese dinero llegaría a una '
                           'factura anulada y quedaría de anticipo de la obra, y la factura buena seguiría debiendo entera aunque '
                           'el cliente ya pagó. Espera a que el pago entre o falle (se ve en Cobros en línea): si falla, se anula; '
                           'si entra, la factura queda cobrada.', d.numero,
                           case when v_nec > 0 then 'en camino' else 'empezado (el cliente está verificando su cuenta de banco)' end,
                           fn_emision_usd(v_mp));
      end if;
      -- CON COBROS APLICADOS no se anula entera (el freno es de c3: aquí, en llano y con qué hacer)
      select -coalesce(sum(l.monto), 0) into v_cob
        from asiento_lineas l
        join asientos a on a.id = l.asiento_id
       where l.partida_tabla = 'facturas' and l.partida_id = d.factura_id::text
         and a.origen_tabla in ('cobros', 'aplicaciones_cobro', 'cobros_devoluciones');
      if v_cob <> 0 then
        raise exception using errcode = 'MX008',
          message = format('La factura %s tiene cobros aplicados por %s: así no se anula entera, y la nota de crédito por una parte '
                           'todavía no existe. Primero hay que anular ese cobro en el libro (hoy no hay botón: avisa y se hace); '
                           'después se anula esta, se hace la buena y el cobro se registra otra vez contra la buena.', d.numero,
                           fn_emision_usd(v_cob));
      end if;
      v_res := fn_factura_anular(d.factura_id, btrim(p_motivo), p_fecha);
      v_nc := v_res->>'nota_credito';
    end if;
    -- (su enlace de pago vivo, si lo tiene: la pantalla lo dice; la revisión de los cobros en línea lo desactiva)
    select jsonb_build_object('id', e.enlace_id, 'url', e.url, 'estado', e.estado) into v_enl
      from fn_emision_enlaces() e
     where e.factura_id = d.factura_id and e.estado in ('creando', 'activo')
     order by e.creado_el desc limit 1;
  end if;
  -- (el hito vuelve a pendiente si no le queda otra factura viva: la que apunte a él o la que la app emitió de él)
  if d.forma = 'hito' and d.hito_id is not null then
    update hitos set estado = 'pendiente'
     where id = d.hito_id and estado = 'facturado'
       and not exists (select 1 from fn_emision_factura_de_hito(d.hito_id));
    select x.estado into v_hito from hitos x where x.id = d.hito_id;
  end if;
  perform set_config('mx_emision.escribe', 'emision_documentos', true);
  update emision_documentos
     set anulado_el = clock_timestamp(), anulado_por = auth.uid(), anulado_motivo = btrim(p_motivo), nota_credito = v_nc
   where id = d.id;
  perform set_config('mx_emision.escribe', '', true);
  return jsonb_strip_nulls(jsonb_build_object(
    'documento', d.id, 'numero', d.numero, 'anulada', true, 'nota_credito', v_nc,
    'asiento', v_res->>'asiento', 'fecha_contable', v_res->>'fecha_contable',
    'ya_estaba_en_el_libro', case when v_ya then true end,
    'sin_asiento', case when d.factura_id is null then 'La factura de la retención no tiene asiento: quedó anulada y lo retenido se puede volver a reclamar.' end,
    'hito_id', d.hito_id, 'hito_estado', v_hito,
    'enlace', v_enl,
    'sigue', 'Si el cliente ya la recibió, avísale. La buena es un borrador nuevo, con número nuevo'
             || case when v_enl is not null
                     then '. Su enlace de pago sigue vivo: desactívalo en Cobros en línea (si no, lo hace su revisión automática).'
                     else '; su enlace de pago, si tenía, hay que desactivarlo.' end));
end $$;
revoke execute on function public.fn_emision_anular(uuid, text, date) from public, anon, service_role;
grant  execute on function public.fn_emision_anular(uuid, text, date) to authenticated;
comment on function public.fn_emision_anular(uuid, text, date) is 'c11: anula una factura emitida por la app: por c3 (fn_factura_anular: su nota de crédito NC-AAAA-NNNN y el espejo de su asiento, con sus frenos), marca el documento (cuándo, quién, por qué, su nota) y devuelve su hito a pendiente si no le queda otra factura viva. La de retención, sin asiento, solo se marca. Si ya se había anulado en el libro, termina lo de aquí. No anula (MX008, en llano) una factura con un pago por cuenta de banco empezado o en camino, con cobros aplicados, o con su retención reclamada en una factura de la retención viva. Devuelve {numero, anulada, nota_credito, asiento, hito_estado, enlace?: su enlace de pago vivo}. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 8. EL PAGO EN LÍNEA, EL PDF Y EL ENVÍO, del lado de la base. Lo que
--    hace la función de borde «facturas» (con la sesión de Edgar): pide el
--    enlace de pago, pinta el PDF con el contenido congelado, lo sube al
--    bucket privado «facturas» y lo registra; manda el correo y registra
--    el envío. Aquí se comprueba y se guarda.
-- ---------------------------------------------------------------------
-- El bucket privado «facturas» (como «cierres» de c9): solo el dueño sube
-- y lee, Y SOLO CON EL CÓDIGO DEL TELÉFONO (aal2); nadie borra ni pisa por
-- la API (un PDF nuevo va con otro nombre).
--   · POR QUÉ aal2 AQUÍ. La guarda de s1 corta cada petición de la API de
--     datos sin el código del teléfono, pero Storage no pasa por ahí: con
--     solo la contraseña de Edgar se leían (y se subían) los PDF de todas las
--     facturas. La función de borde «facturas» ya exige aal2; el bucket pide
--     ahora lo mismo: «(select auth.jwt() ->> 'aal') = 'aal2'» en sus
--     policies (el patrón de Supabase para exigir el segundo factor en una
--     policy; a confirmar con un PDF de verdad en el primer despliegue).
--   · Y DOS CANDADOS «restrictive» de lectura y de subida (como los de
--     borrar y pisar): aunque otra policy permisiva de Storage —de otra parte
--     de la app, sin filtro de bucket— dejara pasar, en este bucket solo
--     entra el dueño con su código. La llave pública (anon), nunca.
do $$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'c11: esta base no tiene Storage (storage.buckets): el bucket «facturas» no se crea aquí; en Supabase sí.';
    return;
  end if;
  begin
    insert into storage.buckets (id, name, public) values ('facturas', 'facturas', false) on conflict (id) do nothing;
  exception when others then
    raise notice 'c11: no se pudo crear el bucket «facturas» (%): créalo en Storage (privado) y vuelve a pegar.', sqlerrm;
  end;
  begin
    drop policy if exists "facturas: el dueno sube" on storage.objects;
    create policy "facturas: el dueno sube" on storage.objects for insert to authenticated
      with check (bucket_id = 'facturas' and public.es_dueno() and (select auth.jwt() ->> 'aal') = 'aal2');
    drop policy if exists "facturas: el dueno lee" on storage.objects;
    create policy "facturas: el dueno lee" on storage.objects for select to authenticated
      using (bucket_id = 'facturas' and public.es_dueno() and (select auth.jwt() ->> 'aal') = 'aal2');
    drop policy if exists "facturas: solo el dueno con su codigo lee" on storage.objects;
    create policy "facturas: solo el dueno con su codigo lee" on storage.objects as restrictive for select to authenticated
      using (bucket_id is distinct from 'facturas' or (public.es_dueno() and (select auth.jwt() ->> 'aal') = 'aal2'));
    drop policy if exists "facturas: solo el dueno con su codigo sube" on storage.objects;
    create policy "facturas: solo el dueno con su codigo sube" on storage.objects as restrictive for insert to authenticated
      with check (bucket_id is distinct from 'facturas' or (public.es_dueno() and (select auth.jwt() ->> 'aal') = 'aal2'));
    drop policy if exists "facturas: la llave publica no entra" on storage.objects;
    create policy "facturas: la llave publica no entra" on storage.objects as restrictive for all to anon
      using (bucket_id is distinct from 'facturas') with check (bucket_id is distinct from 'facturas');
    drop policy if exists "facturas: no se borra" on storage.objects;
    create policy "facturas: no se borra" on storage.objects as restrictive for delete to anon, authenticated
      using (bucket_id is distinct from 'facturas');
    drop policy if exists "facturas: no se pisa" on storage.objects;
    create policy "facturas: no se pisa" on storage.objects as restrictive for update to anon, authenticated
      using (bucket_id is distinct from 'facturas') with check (bucket_id is distinct from 'facturas');
  exception when others then
    raise notice 'c11: no se pudieron poner las policies del bucket «facturas» (%): ponlas en Storage → Policies (solo el dueño, con su código del teléfono, sube y lee; nadie borra). El control de la facturación lo dirá en rojo.', sqlerrm;
  end;
end $$;

-- LO QUE VA A STRIPE Y LO QUE DICE LA FACTURA de un documento emitido
-- (cabecera, «El pago en línea»). Solo lee. Devuelve:
--   en_linea, por_que_no   si se puede pagar en línea esta factura
--   a_pagar                lo que dice el documento
--   saldo, saldo_retencion lo que debe HOY en el libro (1110 y 1120)
--   stripe                 lo que se manda: {monto, centavos, moneda,
--                          metodos: ["us_bank_account"], con_retencion:
--                          false, un_solo_uso: true, nombre, descripcion}
--                          (los metadatos y la llave de idempotencia son
--                          los de p1 para ese enlace)
--   enlace                 el enlace vivo de p1 de esa factura, si lo hay
--                          ({id, estado, url, monto, con_retencion, vale})
--   en_camino              un pago por cuenta de banco que todavía no liquida
--   tarjeta                {ofrecida: false, por_que}
create or replace function public.fn_emision_pago(p_documento uuid) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  d        emision_documentos;
  cfg      emision_config;
  v_p1     boolean := to_regclass('public.stripe_enlaces') is not null;
  v_fest   text;
  v_cxc    numeric := 0;
  v_cret   numeric := 0;
  v_no     text;
  v_enlace jsonb;
  v_camino jsonb;
begin
  perform fn_emision_exigir_dueno();
  select * into d from emision_documentos where id = p_documento;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese documento.';
  end if;
  if d.estado <> 'emitida' then
    raise exception using errcode = 'MX008', message = 'Un borrador no tiene enlace de pago: se emite primero.';
  end if;
  select * into cfg from emision_config where id = 1;
  if d.factura_id is not null then
    select f.estado into v_fest from facturas f where f.id = d.factura_id;
    select s.cxc, s.retencion into v_cxc, v_cret from fn_emision_saldo(d.factura_id) s;
    select jsonb_build_object('id', e.enlace_id, 'estado', e.estado, 'url', e.url, 'monto', e.monto, 'con_retencion', e.con_retencion,
                              'creado_el', e.creado_el,
                              'vale', e.estado = 'activo' and not e.con_retencion and e.monto = v_cxc)
      into v_enlace
      from fn_emision_enlaces() e
     where e.factura_id = d.factura_id and e.estado in ('creando', 'activo')
     order by e.creado_el desc limit 1;
    select jsonb_build_object('pagos', count(*), 'monto', coalesce(sum(s.monto), 0)) into v_camino
      from fn_emision_pagos() s
     where s.factura_id = d.factura_id and s.estado in ('iniciado', 'en_camino')
    having count(*) > 0;
  end if;
  v_no := case
            when d.anulado_el is not null or v_fest = 'anulada' then 'La factura está anulada: no se cobra.'
            when d.forma = 'retencion'
              then 'La factura de la retención no lleva enlace propio: se cobra por cheque o transferencia, o con el enlace «con la '
                   'retención» de cada factura, desde Cobros en línea.'
            when not cfg.ach then 'El pago en línea está apagado en los ajustes de facturación.'
            when not v_p1 then 'Los cobros en línea (Stripe) no están instalados en esta base.'
            when v_camino is not null then 'Ya hay un pago por cuenta de banco en camino por esta factura: se espera a que se confirme o falle.'
            when v_cxc <= 0 then 'La factura ya no debe nada en el libro.'
            when v_cxc < 0.50 then 'Stripe no cobra menos de 0.50.'
            when v_cxc > 999999.99 then 'Un enlace de pago llega hasta 999,999.99.'
          end;
  return jsonb_strip_nulls(jsonb_build_object(
    'documento', d.id, 'numero', d.numero, 'factura_id', d.factura_id,
    'en_linea', v_no is null, 'por_que_no', v_no,
    'a_pagar', d.a_pagar, 'saldo', v_cxc, 'saldo_retencion', v_cret,
    'stripe', case when v_no is null then jsonb_build_object(
                'monto', v_cxc, 'centavos', (v_cxc * 100)::bigint, 'moneda', 'usd',
                'metodos', jsonb_build_array('us_bank_account'), 'con_retencion', false, 'un_solo_uso', true,
                'nombre', format('Invoice %s · %s', d.numero, coalesce(nullif(btrim(cfg.empresa->>'nombre'), ''), 'Invoice')),
                'descripcion', format('Invoice %s — %s', d.numero, coalesce(nullif(btrim(cfg.empresa->>'nombre'), ''), 'Invoice'))) end,
    'enlace', v_enlace,
    'en_camino', v_camino,
    'tarjeta', jsonb_build_object('ofrecida', false, 'por_que', fn_emision_tarjeta_texto())));
end $$;
revoke execute on function public.fn_emision_pago(uuid) from public, anon, service_role;
grant  execute on function public.fn_emision_pago(uuid) to authenticated;
comment on function public.fn_emision_pago(uuid) is 'c11: lo que va a Stripe y lo que hay del pago en línea de una factura emitida: {en_linea, por_que_no, a_pagar (lo que dice el documento), saldo y saldo_retencion (lo que debe hoy en el libro), stripe: {monto, centavos, moneda, metodos: [us_bank_account], con_retencion: false, un_solo_uso, nombre, descripcion}, enlace (el vivo de p1, y si vale: activo, sin retención y por lo que el libro debe), en_camino, tarjeta: {ofrecida: false, por_que}}. Solo lee. Solo el dueño.';

-- REGISTRAR UN PDF de un documento emitido. p_archivo:
--   ruta    dentro del bucket «facturas», en la carpeta <año>/<número>/ y
--           acabada en .pdf (una ruta nueva por PDF: no se pisa)
--   sha256  del archivo (64 hexadecimales en minúsculas)
--   bytes   su tamaño
--   huella  la del contenido del que se pintó (la del documento): si no es,
--           MX011
--   pago    lo que lleva impreso para pagar en línea, si lleva:
--           {enlace_id, url, metodos: ["us_bank_account"]}
-- La base comprueba que el archivo está en Storage (si esta base lo tiene)
-- y, si Storage apunta su tamaño, que mide lo que se declara; y que el
-- enlace impreso es el vivo de p1 de esa factura, sin retención, por lo
-- que el libro debe, y solo por cuenta de banco. Devuelve {pdf, ya_estaba}.
create or replace function public.fn_emision_pdf(p_documento uuid, p_archivo jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  d        emision_documentos;
  v_sobra  text;
  v_ruta   text;
  v_sha    text;
  v_bytes  bigint;
  v_carp   text;
  v_hay    boolean;
  v_tam    bigint;
  v_pago   jsonb;
  v_met    jsonb;
  v_cxc    numeric;
  v_e      record;
  v_fila   emision_pdfs;
  v_n      int;
begin
  perform fn_emision_exigir_dueno();
  if p_archivo is null or jsonb_typeof(p_archivo) <> 'object' then
    raise exception using errcode = '22023', message = 'El archivo llega como un objeto {ruta, sha256, bytes, huella, pago?}.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p_archivo) k where k not in ('ruta', 'sha256', 'bytes', 'huella', 'pago');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en el archivo: %s.', v_sobra);
  end if;
  select * into d from emision_documentos where id = p_documento for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese documento.';
  end if;
  if d.estado <> 'emitida' then
    raise exception using errcode = 'MX008', message = 'Un borrador no tiene PDF: se emite primero.';
  end if;
  if d.anulado_el is not null then
    raise exception using errcode = 'MX008', message = format('La factura %s está anulada: ya no se le hace PDF.', d.numero);
  end if;
  v_ruta := p_archivo->>'ruta';
  v_sha  := p_archivo->>'sha256';
  v_carp := d.anio || '/' || d.numero || '/';
  if v_ruta is null or left(v_ruta, length(v_carp)) <> v_carp or v_ruta !~ '^[A-Za-z0-9._/-]+\.pdf$'
     or v_ruta ~ '(^|/)\.\.(/|$)' or length(v_ruta) > 300 or position('/' in substr(v_ruta, length(v_carp) + 1)) > 0 then
    raise exception using errcode = '22023',
      message = format('La ruta «%s» tiene que ser un .pdf dentro de la carpeta de esta factura en el bucket facturas (%s…).',
                       coalesce(v_ruta, ''), v_carp);
  end if;
  if coalesce(v_sha, '') !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'El sha256 del PDF va en 64 caracteres hexadecimales en minúsculas.';
  end if;
  begin
    v_bytes := (p_archivo->>'bytes')::bigint;
  exception when others then
    v_bytes := -1;
  end;
  if v_bytes is null or v_bytes <= 0 then
    raise exception using errcode = 'MX005', message = 'bytes es el tamaño del PDF, un entero de más de 0.';
  end if;
  if p_archivo->>'huella' is distinct from d.huella then
    raise exception using errcode = 'MX011',
      message = format('Ese PDF no se pintó del contenido congelado de la factura %s (su huella no es la del documento): no se '
                       'registró. Vuelve a pintarlo desde el documento.', d.numero);
  end if;
  -- el mismo archivo otra vez: ya estaba
  select * into v_fila from emision_pdfs x where x.ruta = v_ruta;
  if found then
    if v_fila.documento_id <> d.id or v_fila.sha256 <> v_sha or v_fila.bytes <> v_bytes then
      raise exception using errcode = 'MX008',
        message = format('Ya hay otro PDF registrado en «%s»: un PDF nuevo va con otro nombre (no se pisa).', v_ruta);
    end if;
    return jsonb_build_object('documento', d.id, 'numero', d.numero, 'ya_estaba', true,
                              'pdf', jsonb_build_object('id', v_fila.id, 'n', v_fila.n, 'ruta', v_fila.ruta, 'sha256', v_fila.sha256,
                                                        'bytes', v_fila.bytes, 'creado_el', v_fila.creado_el));
  end if;
  -- que esté en Storage (si esta base lo tiene; el banco de pruebas lo simula)
  if to_regclass('storage.objects') is not null then
    execute 'select true, case when o.metadata->>''size'' ~ ''^[0-9]+$'' then (o.metadata->>''size'')::bigint end '
            'from storage.objects o where o.bucket_id = ''facturas'' and o.name = $1' into v_hay, v_tam using v_ruta;
    if v_hay is null then
      raise exception using errcode = '22023',
        message = format('«%s» no está en el bucket facturas: sube el PDF primero y regístralo después.', v_ruta);
    elsif v_tam is not null and v_tam <> v_bytes then
      raise exception using errcode = '22023',
        message = format('«%s» mide %s bytes en el bucket facturas y aquí dice %s: no se registró.', v_ruta, v_tam, v_bytes);
    end if;
  end if;
  -- lo que lleva impreso para pagar en línea
  v_pago := '{}'::jsonb;
  if p_archivo ? 'pago' and jsonb_typeof(p_archivo->'pago') <> 'null' then
    if jsonb_typeof(p_archivo->'pago') <> 'object' then
      raise exception using errcode = '22023', message = 'pago es un objeto {enlace_id, url, metodos}.';
    end if;
    select string_agg(k, ', ' order by k) into v_sobra
      from jsonb_object_keys(p_archivo->'pago') k where k not in ('enlace_id', 'url', 'metodos');
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Clave desconocida en pago: %s.', v_sobra);
    end if;
    v_met := p_archivo->'pago'->'metodos';
    if jsonb_typeof(v_met) is distinct from 'array' or jsonb_array_length(v_met) = 0
       or exists (select 1 from jsonb_array_elements_text(v_met) m where m not in ('us_bank_account', 'card')) then
      raise exception using errcode = '22023', message = 'pago.metodos dice con qué se puede pagar ese enlace: ["us_bank_account"].';
    end if;
    if v_met @> '["card"]'::jsonb and not (fn_emision_tarjeta_lista()
                                            and (select c.tarjeta_pct is not null from emision_config c where c.id = 1)) then
      raise exception using errcode = 'MX008',
        message = 'Ese enlace deja pagar con tarjeta y la tarjeta está apagada: el enlace de una factura va solo por cuenta de banco '
                  '(ACH). Restríngelo en Stripe y vuelve a pintar el PDF.';
    end if;
    if d.factura_id is null then
      raise exception using errcode = 'MX008', message = 'La factura de la retención no lleva enlace de pago propio.';
    end if;
    select s.cxc into v_cxc from fn_emision_saldo(d.factura_id) s;
    select * into v_e from fn_emision_enlaces() e
     where e.factura_id = d.factura_id and e.enlace_id::text = p_archivo->'pago'->>'enlace_id';
    if not found then
      raise exception using errcode = 'MX008',
        message = format('Ese enlace no es el de la factura %s en los cobros en línea: el PDF lleva el enlace que arma Cobros en línea '
                         'para ella, no otro.', d.numero);
    end if;
    if v_e.estado <> 'activo' or v_e.con_retencion or v_e.monto <> v_cxc or v_e.url is distinct from p_archivo->'pago'->>'url' then
      raise exception using errcode = 'MX008',
        message = format('El enlace de la factura %s no vale para imprimirlo: %s. Pide uno nuevo y vuelve a pintar el PDF.', d.numero,
                         case when v_e.estado <> 'activo' then 'ya no está activo'
                              when v_e.con_retencion then 'cobra también la retención, que todavía no se debe'
                              when v_e.monto <> v_cxc then format('cobra %s y la factura debe %s en el libro', fn_emision_usd(v_e.monto),
                                                                  fn_emision_usd(v_cxc))
                              else 'su dirección no es la que lleva el PDF' end);
    end if;
    v_pago := jsonb_build_object('enlace_id', v_e.enlace_id, 'url', v_e.url, 'metodos', v_met, 'monto', v_e.monto);
  end if;
  select coalesce(max(x.n), 0) + 1 into v_n from emision_pdfs x where x.documento_id = d.id;
  perform set_config('mx_emision.escribe', 'emision_pdfs', true);
  insert into emision_pdfs (documento_id, n, ruta, sha256, bytes, huella, pago, creado_por)
  values (d.id, v_n, v_ruta, v_sha, v_bytes, d.huella, v_pago, auth.uid())
  returning * into v_fila;
  perform set_config('mx_emision.escribe', '', true);
  return jsonb_build_object('documento', d.id, 'numero', d.numero, 'ya_estaba', false,
                            'pdf', jsonb_build_object('id', v_fila.id, 'n', v_fila.n, 'ruta', v_fila.ruta, 'sha256', v_fila.sha256,
                                                      'bytes', v_fila.bytes, 'creado_el', v_fila.creado_el));
end $$;
revoke execute on function public.fn_emision_pdf(uuid, jsonb) from public, anon, service_role;
grant  execute on function public.fn_emision_pdf(uuid, jsonb) to authenticated;
comment on function public.fn_emision_pdf(uuid, jsonb) is 'c11: registra un PDF de una factura emitida: {ruta (un .pdf en <año>/<número>/ del bucket facturas), sha256, bytes, huella (la del documento: si no es, MX011), pago?: {enlace_id, url, metodos}}. Comprueba que el archivo está en Storage y mide lo declarado, y que el enlace impreso es el vivo de p1 de esa factura, sin retención, por lo que el libro debe y solo por cuenta de banco (MX008 si no). Un PDF nuevo es otra versión (n), con otra ruta. Devuelve {pdf: {id, n, ruta, sha256, bytes}, ya_estaba}. Solo el dueño.';

-- REGISTRAR UN ENVÍO de una factura emitida. p_envio:
--   medio      correo (por omisión) | en_mano
--   para       a quién (el correo; en mano, quién la recibió)
--   cc, asunto, nota
--   resend_id  el id que dio Resend (correo): el mismo dos veces no entra
--              dos veces
--   pdf_id     el PDF que se mandó (por omisión, el último registrado)
-- n = 1 es el primer envío; los siguientes son reenvíos. Devuelve {envio,
-- reenvio, ya_estaba}.
create or replace function public.fn_emision_envio(p_documento uuid, p_envio jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  d        emision_documentos;
  v_sobra  text;
  v_medio  text;
  v_para   text;
  v_resend text;
  v_pdf    uuid;
  v_fila   emision_envios;
  v_n      int;
begin
  perform fn_emision_exigir_dueno();
  if p_envio is null or jsonb_typeof(p_envio) <> 'object' then
    raise exception using errcode = '22023', message = 'El envío llega como un objeto {medio, para, cc, asunto, resend_id, pdf_id, nota}.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p_envio) k where k not in ('medio', 'para', 'cc', 'asunto', 'resend_id', 'pdf_id', 'nota');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en el envío: %s.', v_sobra);
  end if;
  select * into d from emision_documentos where id = p_documento for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese documento.';
  end if;
  if d.estado <> 'emitida' then
    raise exception using errcode = 'MX008', message = 'Un borrador no se manda: se emite primero.';
  end if;
  if d.anulado_el is not null then
    raise exception using errcode = 'MX008', message = format('La factura %s está anulada: ya no se manda.', d.numero);
  end if;
  v_medio  := coalesce(nullif(btrim(p_envio->>'medio'), ''), 'correo');
  v_para   := nullif(btrim(p_envio->>'para'), '');
  v_resend := nullif(btrim(p_envio->>'resend_id'), '');
  if v_medio not in ('correo', 'en_mano') then
    raise exception using errcode = '22023', message = format('El medio es correo o en_mano (llegó «%s»).', v_medio);
  end if;
  if v_para is null or length(v_para) > 500 or (v_medio = 'correo' and v_para !~ '^[^@[:space:]]+@[^@[:space:]]+(\s*,\s*[^@[:space:]]+@[^@[:space:]]+)*$') then
    raise exception using errcode = '22023',
      message = 'Di a quién se mandó (para): en un correo, su dirección (o varias, separadas por comas); en mano, quién la recibió.';
  end if;
  if length(coalesce(p_envio->>'cc', '')) > 500 or length(coalesce(p_envio->>'asunto', '')) > 300 or length(coalesce(p_envio->>'nota', '')) > 500 then
    raise exception using errcode = '22023', message = 'La copia, el asunto y la nota son textos cortos (500, 300 y 500 letras).';
  end if;
  if v_resend is not null then
    select * into v_fila from emision_envios e where e.resend_id = v_resend;
    if found then
      if v_fila.documento_id <> d.id then
        raise exception using errcode = 'MX008', message = 'Ese envío (su id de Resend) ya está registrado en otra factura.';
      end if;
      return jsonb_build_object('documento', d.id, 'numero', d.numero, 'ya_estaba', true, 'reenvio', v_fila.n > 1,
                                'envio', jsonb_build_object('id', v_fila.id, 'n', v_fila.n, 'medio', v_fila.medio, 'para', v_fila.para,
                                                            'enviado_el', v_fila.enviado_el));
    end if;
  end if;
  if p_envio ? 'pdf_id' and jsonb_typeof(p_envio->'pdf_id') <> 'null' then
    begin
      v_pdf := (p_envio->>'pdf_id')::uuid;
    exception when others then
      raise exception using errcode = '22023', message = 'pdf_id es el identificador de un PDF registrado.';
    end;
    if not exists (select 1 from emision_pdfs x where x.id = v_pdf and x.documento_id = d.id) then
      raise exception using errcode = '22023', message = 'Ese PDF no es de esta factura.';
    end if;
  else
    select x.id into v_pdf from emision_pdfs x where x.documento_id = d.id order by x.n desc limit 1;
  end if;
  if v_medio = 'correo' then
    if v_pdf is null then
      raise exception using errcode = 'MX008',
        message = format('La factura %s todavía no tiene su PDF registrado: primero el PDF, después el correo.', d.numero);
    end if;
    if v_resend is null then
      raise exception using errcode = '22023', message = 'Un correo se registra con el id que dio Resend (resend_id): es la prueba de que salió.';
    end if;
  end if;
  select coalesce(max(e.n), 0) + 1 into v_n from emision_envios e where e.documento_id = d.id;
  perform set_config('mx_emision.escribe', 'emision_envios', true);
  insert into emision_envios (documento_id, n, medio, pdf_id, para, cc, asunto, resend_id, nota, enviado_por)
  values (d.id, v_n, v_medio, v_pdf, v_para, nullif(btrim(p_envio->>'cc'), ''), nullif(btrim(p_envio->>'asunto'), ''), v_resend,
          nullif(btrim(p_envio->>'nota'), ''), auth.uid())
  returning * into v_fila;
  perform set_config('mx_emision.escribe', '', true);
  return jsonb_build_object('documento', d.id, 'numero', d.numero, 'ya_estaba', false, 'reenvio', v_fila.n > 1,
                            'envio', jsonb_build_object('id', v_fila.id, 'n', v_fila.n, 'medio', v_fila.medio, 'para', v_fila.para,
                                                        'enviado_el', v_fila.enviado_el));
end $$;
revoke execute on function public.fn_emision_envio(uuid, jsonb) from public, anon, service_role;
grant  execute on function public.fn_emision_envio(uuid, jsonb) to authenticated;
comment on function public.fn_emision_envio(uuid, jsonb) is 'c11: registra un envío de una factura emitida: {medio: correo | en_mano, para, cc, asunto, resend_id (correo: el id de Resend; el mismo dos veces no entra dos veces), pdf_id (por omisión, el último PDF), nota}. Un correo pide su PDF registrado y su id de Resend. n = 1 es el primer envío; los demás, reenvíos. Devuelve {envio: {id, n, medio, para, enviado_el}, reenvio, ya_estaba}. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 9. EL CONTROL (orden, cuadre, nivel, ok, detalle, en llano). Un «cuadre»
--    en rojo es algo roto que hay que arreglar (detiene el cierre del mes);
--    un «aviso», algo que mirar. Ningún cuadre mira facturas de antes de la
--    app: no se enciende con la historia.
-- ---------------------------------------------------------------------
create or replace function public.fn_emision_control()
returns table (orden int, cuadre text, nivel text, ok boolean, detalle text)
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg       emision_config;
  v_hoy     date := fn_fecha_miami(now());
  v_cxc     text := fn_emision_cuenta('cxc');
  v_cret    text := fn_emision_cuenta('retencion_cxc');
  v_n       bigint;
  v_tot     bigint;
  v_d       text;
  v_patron  text;
  v_storage boolean := to_regclass('storage.objects') is not null;
  c_fn constant text[] := array['fn_emision_precondiciones', 'fn_emision_exigir_dueno', 'fn_emision_ve', 'fn_emision_guarda',
                                'fn_emision_numerar', 'fn_emision_usd', 'fn_emision_dia', 'fn_emision_numero', 'fn_emision_formato',
                                'fn_emision_tarjeta_lista', 'fn_emision_tarjeta_texto', 'fn_emision_parece_espanol',
                                'fn_emision_cuenta', 'fn_emision_saldo', 'fn_emision_retencion', 'fn_emision_retencion_de',
                                'fn_emision_destinatario', 'fn_emision_enlaces', 'fn_emision_pagos', 'fn_emision_storage',
                                'fn_emision_retenido', 'fn_emision_factura_de_hito', 'fn_emision_revisar', 'fn_emision_visto',
                                'fn_emision_contenido', 'fn_emision_documento', 'fn_emision_borrador', 'fn_emision_descartar',
                                'fn_emision_obra', 'fn_emision_config', 'fn_emision_emitir', 'fn_emision_anular', 'fn_emision_pago',
                                'fn_emision_pdf', 'fn_emision_envio', 'fn_emision_control', 'fn_emision_pegado'];
  c_tablas constant text[] := array['emision_config', 'emision_obras', 'emision_documentos', 'emision_lineas', 'emision_serie',
                                    'emision_pdfs', 'emision_envios', 'emision_soltados'];
  c_vistas constant text[] := array['v_emision_estado', 'v_emision_documentos', 'v_emision_obras', 'v_emision_control'];
  -- los candados del bucket «facturas» (Storage): los que piden el código del teléfono, y los que cierran
  c_bucket_aal constant text[] := array['facturas: el dueno sube', 'facturas: el dueno lee',
                                        'facturas: solo el dueno con su codigo lee', 'facturas: solo el dueno con su codigo sube'];
  c_bucket_cierra constant text[] := array['facturas: solo el dueno con su codigo lee', 'facturas: solo el dueno con su codigo sube',
                                           'facturas: la llave publica no entra', 'facturas: no se borra', 'facturas: no se pisa'];
begin
  if not fn_emision_ve() then
    return;
  end if;
  select * into cfg from emision_config where id = 1;
  -- (un número con la forma de las series de aquí: MXP-2027-0001 o MXP-R-2027-0001)
  v_patron := '^' || replace(replace(cfg.serie_formato, '-AAAA-', '-(R-)?[0-9]{4}-'), 'NNNN', '[0-9]{4,}') || '$';

  -- 10: cada factura emitida por la app (viva) ES su asiento de c3, al centavo
  select count(*) filter (where y.mal is not null), count(*),
         string_agg(format('la factura %s (%s): %s', y.numero, fn_emision_usd(y.monto), y.mal), '; ' order by y.numero)
           filter (where y.mal is not null)
    into v_n, v_tot, v_d
    from (select d.numero, d.monto,
                 nullif(concat_ws(', ',
                   case when a.id is null then 'no tiene asiento vivo en el libro' end,
                   case when a.id is not null and f.contabilizado_en is distinct from a.id
                        then 'su fila de facturas no apunta a su asiento' end,
                   case when a.id is not null and s.cxc <> d.a_pagar
                        then format('por cobrar en su asiento %s y debía ser %s', s.cxc, d.a_pagar) end,
                   case when a.id is not null and s.ret <> d.retencion
                        then format('retención en su asiento %s y debía ser %s', s.ret, d.retencion) end,
                   case when a.id is not null and s.ing <> -d.monto
                        then format('ingreso en su asiento %s y debía ser %s', -s.ing, d.monto) end), '') as mal
            from emision_documentos d
            join facturas f on f.id = d.factura_id
            left join lateral (select x.id from asientos x
                                where x.origen_tabla = 'facturas' and x.origen_id = d.factura_id::text
                                  and x.camino not in ('reverso', 'reverso_automatico')
                                  and not exists (select 1 from asientos r where r.reversa_a = x.id and r.camino = 'reverso')
                                order by x.cadena_pos desc limit 1) a on true
            left join lateral (select coalesce(sum(l.monto) filter (where l.cuenta = v_cxc and l.partida_tabla = 'facturas'
                                                                      and l.partida_id = d.factura_id::text), 0) as cxc,
                                      coalesce(sum(l.monto) filter (where l.cuenta = v_cret and l.partida_tabla = 'facturas'
                                                                      and l.partida_id = d.factura_id::text), 0) as ret,
                                      coalesce(sum(l.monto) filter (where l.monto < 0), 0) as ing
                                 from asiento_lineas l where l.asiento_id = a.id) s on true
           where d.estado = 'emitida' and d.anulado_el is null and f.estado <> 'anulada') y;
  orden := 10; cuadre := 'facturas: cada factura emitida por la app = su asiento, al centavo'; nivel := 'cuadre'; ok := v_n = 0;
  detalle := case when v_n = 0
                  then format('%s factura(s) viva(s) emitida(s) por la app: cada una está en el libro con su asiento, al centavo (lo '
                              'que se cobra ahora más lo retenido es su monto).', v_tot)
                  else left(v_d, 1500) || ' → no toques el libro ni la factura: avisa.' end;
  return next;

  -- 20: las series de cada año (la de las facturas y la de las facturas de la retención), seguidas y sin repetidos, y cada
  -- contador en su último número. Un consecutivo que falta solo vale si lo lleva una fila de facturas que no salió de la app:
  -- la serie lo saltó para no darlo dos veces (el trigger del número).
  select count(*), string_agg(y.que, '; ' order by y.que) into v_n, v_d
    from (select format('la serie de %s de %s tiene %s número(s), el último el %s, y su contador va en %s', a.cual, a.anio, a.n, a.mx,
                        coalesce(c.ultimo::text, '(sin contador)')) as que
            from (select s.serie, s.anio, count(*) as n, max(s.secuencia) as mx,
                         case s.serie when 'facturas' then 'las facturas' else 'las facturas de la retención' end as cual
                    from emision_serie s group by s.serie, s.anio) a
            left join contadores c on c.serie = a.serie || '-' || a.anio
           where c.ultimo is distinct from a.mx
          union all
          select format('en la serie de %s falta el número %s y ninguna factura lo lleva', a.anio,
                        fn_emision_numero(fn_emision_formato(cfg.serie_formato, a.serie), a.anio, k.k))
            from (select s.serie, s.anio, max(s.secuencia) as mx from emision_serie s group by s.serie, s.anio) a
           cross join lateral generate_series(1, a.mx) k(k)
           where not exists (select 1 from emision_serie s where s.serie = a.serie and s.anio = a.anio and s.secuencia = k.k)
             and not exists (select 1 from facturas f
                              where f.num = fn_emision_numero(fn_emision_formato(cfg.serie_formato, a.serie), a.anio, k.k)
                                and not exists (select 1 from emision_documentos d where d.factura_id = f.id))
          union all
          select format('el contador de %s de %s va en %s y no hay ningún número de ese año',
                        case split_part(c.serie, '-', 1) when 'facturas' then 'las facturas' else 'las facturas de la retención' end,
                        split_part(c.serie, '-', 2), c.ultimo)
            from contadores c
           where c.serie ~ '^(facturas|retenciones)-[0-9]{4}$' and c.ultimo > 0
             and not exists (select 1 from emision_serie s
                              where s.serie = split_part(c.serie, '-', 1) and s.anio = split_part(c.serie, '-', 2)::int)
          union all
          select format('el número %s no tiene su factura emitida', s.numero)
            from emision_serie s
           where not exists (select 1 from emision_documentos d
                              where d.id = s.documento_id and d.estado = 'emitida' and d.numero = s.numero
                                and d.anio = s.anio and d.secuencia = s.secuencia
                                and (d.forma = 'retencion') = (s.serie = 'retenciones'))
          union all
          select format('la factura %s no está en la serie', d.numero)
            from emision_documentos d
           where d.estado = 'emitida' and not exists (select 1 from emision_serie s where s.documento_id = d.id)) y;
  orden := 20; cuadre := 'facturas: la serie de cada año, sin huecos ni repetidos'; nivel := 'cuadre'; ok := v_n = 0;
  detalle := case when v_n = 0
                  then coalesce((select 'Cada serie va seguida y su contador está en el último número: '
                                        || string_agg(format('%s de %s, %s número(s)%s',
                                                             case s.serie when 'facturas' then 'facturas' else 'facturas de la retención' end,
                                                             s.anio, s.n,
                                                             case when s.mx > s.n
                                                                  then format(' (y %s que la serie saltó porque ya lo(s) llevaba una factura '
                                                                              'hecha fuera de la app)', s.mx - s.n) else '' end),
                                                      '; ' order by s.anio, s.serie) || '.'
                                   from (select x.serie, x.anio, count(*) as n, max(x.secuencia) as mx
                                           from emision_serie x group by x.serie, x.anio) s),
                                'Todavía no se ha emitido ninguna factura por la app: la serie empieza en el 1.')
                  else left(v_d, 1500) || ' → un número no se da sin su factura: avisa (no se arregla a mano).' end;
  return next;

  -- 30: cada documento emitido sigue sellado, y su fila de facturas dice lo mismo
  select count(*) filter (where y.mal is not null), count(*),
         string_agg(format('la factura %s: %s', y.numero, y.mal), '; ' order by y.numero) filter (where y.mal is not null)
    into v_n, v_tot, v_d
    from (select d.numero,
                 nullif(concat_ws(', ',
                   case when d.huella is distinct from encode(sha256(convert_to(d.contenido::text, 'UTF8')), 'hex')
                        then 'su contenido ya no es el que se selló' end,
                   case when l.suma is distinct from d.monto or l.n is distinct from jsonb_array_length(d.contenido->'lineas')
                        then 'sus líneas no suman su monto (o no son las del contenido)' end,
                   case when d.contenido->>'numero' is distinct from d.numero
                          or d.contenido->'totales'->>'subtotal' is distinct from d.monto::text
                          or d.contenido->'totales'->>'retencion' is distinct from d.retencion::text
                          or d.contenido->'totales'->>'a_pagar' is distinct from d.a_pagar::text
                        then 'su número o sus totales no son los del contenido' end,
                   case when d.forma <> 'retencion' and d.retencion <> fn_emision_retencion(d.monto, d.retencion_pct)
                        then 'su retención no es su porcentaje de su monto' end,
                   case when d.factura_id is not null
                         and (f.id is null or f.num is distinct from d.numero or f.fecha is distinct from d.fecha
                              or round(f.monto, 2) is distinct from d.monto or coalesce(f.retencion, 0) <> d.retencion
                              or f.proyecto_id is distinct from d.proyecto_id)
                        then 'su fila de facturas no dice lo mismo (número, fecha, monto, retención u obra)' end,
                   case when d.factura_id is not null and d.anulado_el is not null and f.estado is distinct from 'anulada'
                        then 'aquí está anulada y en el libro sigue viva' end), '') as mal
            from emision_documentos d
            left join facturas f on f.id = d.factura_id
            left join lateral (select coalesce(sum(x.importe), 0) as suma, count(*)::int as n
                                 from emision_lineas x where x.documento_id = d.id) l on true
           where d.estado = 'emitida') y;
  orden := 30; cuadre := 'facturas: cada documento emitido sigue sellado'; nivel := 'cuadre'; ok := v_n = 0;
  detalle := case when v_n = 0
                  then format('%s documento(s) emitido(s): su contenido es el que se selló, sus líneas suman su monto y su fila de '
                              'facturas dice lo mismo.', v_tot)
                  else left(v_d, 1500) || ' → lo que el cliente recibió ya no es lo guardado: no corrijas nada a mano; avisa.' end;
  return next;

  -- 40: ningún hito con dos facturas vivas si alguna salió de la app. EL HITO DE UNA FACTURA DE LA APP ES EL DE SU DOCUMENTO
  -- (no cambia), no el que diga hoy su fila de facturas: si alguien vacía o cambia facturas.hito_id —o borra el hito, y la
  -- llave lo deja en nulo— y el hito se factura otra vez, aquí se ve igual.
  select count(*), string_agg(format('el hito %s de %s tiene %s facturas vivas (%s)', y.titulo, y.obra, y.n, y.nums), '; '
                              order by y.obra, y.titulo)
    into v_n, v_d
    from (select coalesce('«' || h.titulo || '»', '(borrado después de facturarlo)') as titulo,
                 coalesce(p.nombre, x.proyecto_id) as obra, x.n, x.nums
            from (select coalesce(d.hito_id, f.hito_id) as hito, min(f.proyecto_id) as proyecto_id, count(*) as n,
                         string_agg(f.num, ', ' order by f.id) as nums
                    from facturas f
                    left join emision_documentos d on d.factura_id = f.id and d.anulado_el is null
                   where f.estado <> 'anulada' and coalesce(d.hito_id, f.hito_id) is not null
                   group by coalesce(d.hito_id, f.hito_id)
                  having count(*) > 1 and bool_or(d.id is not null)) x
            left join hitos h on h.id = x.hito
            left join proyectos p on p.id = x.proyecto_id) y;
  orden := 40; cuadre := 'facturas: ningún hito facturado dos veces'; nivel := 'cuadre'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Ningún hito tiene dos facturas vivas con alguna emitida por la app (el hito de cada factura de la '
                                    'app es el de su documento, diga lo que diga hoy la ficha).'
                  else left(v_d, 1500) || ' → ese hito entró dos veces al ingreso: anula la que sobre (con su nota de crédito).' end;
  return next;

  -- 42 (aviso): la fila de facturas de una factura de hito de la app ya no apunta al hito de su documento (alguien la cambió,
  -- o el hito se borró). Con el hito vivo: la ficha lo enseña sin su factura. Con el hito borrado: mientras la obra tenga
  -- hitos por facturar, uno puede ser aquel vuelto a crear.
  select count(*), string_agg(y.que, '; ' order by y.que) into v_n, v_d
    from (select case when h.id is not null
                      then format('la factura %s (%s) de %s salió del hito «%s» y su fila de facturas ya no lo dice%s', d.numero,
                                  fn_emision_usd(d.monto), coalesce(p.nombre, d.proyecto_id), h.titulo,
                                  case when f.hito_id is not null then ' (apunta a otro hito)' else '' end)
                      else format('la factura %s (%s) de %s salió de un hito que después se borró, y la obra tiene hitos por facturar '
                                  '(%s)', d.numero, fn_emision_usd(d.monto), coalesce(p.nombre, d.proyecto_id), pf.cuales) end as que
            from emision_documentos d
            join facturas f on f.id = d.factura_id
            left join hitos h on h.id = d.hito_id
            left join proyectos p on p.id = d.proyecto_id
            left join lateral (select string_agg('«' || x.titulo || '»', ', ' order by x.orden, x.id) as cuales
                                 from hitos x
                                where h.id is null and x.proyecto_id = d.proyecto_id and coalesce(x.estado, 'pendiente') = 'pendiente'
                                  and coalesce(round(x.monto, 2), 0) > 0
                                  and not exists (select 1 from fn_emision_factura_de_hito(x.id))) pf on true
           where d.forma = 'hito' and d.estado = 'emitida' and d.anulado_el is null and f.estado <> 'anulada'
             and f.hito_id is distinct from d.hito_id
             and (h.id is not null or pf.cuales is not null)) y;
  orden := 42; cuadre := 'facturas: cada factura de hito sigue enlazada a su hito'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Cada factura de hito emitida por la app sigue enlazada a su hito en la ficha de la obra (o su hito '
                                    'se borró y a la obra ya no le queda ninguno por facturar).'
                  else left(v_d, 1500) || ' → la que ya no lo dice: en la ficha ese hito se ve sin su factura, pero YA está facturado '
                       '(la app no deja facturarlo otra vez): avisa para volver a enlazarla. La del hito borrado: si alguno de esos '
                       'hitos es aquel vuelto a crear, NO lo factures: ya se facturó con esa factura.' end;
  return next;

  -- 44 (aviso): en cada obra, lo facturado por hitos (vivo) no pasa de lo que suman sus hitos. Es lo que queda a la vista si
  -- un hito se factura, se borra, se vuelve a crear y se factura otra vez (son dos hitos distintos: el 40 no lo ve).
  select count(*), string_agg(format('en %s lo facturado por hitos suma %s (%s) y sus hitos suman %s', y.obra, fn_emision_usd(y.fact),
                                     y.nums, fn_emision_usd(y.hitos)), '; ' order by y.obra)
    into v_n, v_d
    from (select coalesce(p.nombre, x.proyecto_id) as obra, x.fact, x.nums, coalesce(hs.suma, 0) as hitos
            from (select f.proyecto_id, sum(round(f.monto, 2)) as fact, string_agg(f.num, ', ' order by f.id) as nums,
                         bool_or(d.id is not null) as de_la_app
                    from facturas f
                    left join emision_documentos d on d.factura_id = f.id and d.anulado_el is null
                   where f.estado <> 'anulada' and coalesce(d.hito_id, f.hito_id) is not null
                   group by f.proyecto_id) x
            left join proyectos p on p.id = x.proyecto_id
            left join lateral (select sum(round(h.monto, 2)) as suma from hitos h where h.proyecto_id = x.proyecto_id) hs on true
           where x.de_la_app and x.fact > coalesce(hs.suma, 0)) y;
  orden := 44; cuadre := 'facturas: lo facturado por hitos no pasa de los hitos de la obra'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'En ninguna obra con facturas de hito de la app lo facturado por hitos pasa de lo que suman sus hitos.'
                  else left(v_d, 1500) || ' → un hito se facturó dos veces (¿se borró y se volvió a crear?), o se borró o se rebajó '
                       'después de facturarlo: mira las facturas de esa obra; la que sobre se anula con su nota de crédito, y si lo '
                       'que cambió fue el contrato, pon los hitos como quedaron.' end;
  return next;

  -- 50 (aviso): cada PDF registrado sigue en Storage y mide lo mismo
  if v_storage then
    select count(*) filter (where o.ruta is null or (o.bytes is not null and o.bytes <> x.bytes)), count(*),
           string_agg(format('el PDF %s de la factura %s (%s) %s', x.n, d.numero, x.ruta,
                             case when o.ruta is null then 'ya no está' else format('mide %s y se registró con %s', o.bytes, x.bytes) end),
                      '; ' order by d.numero, x.n)
             filter (where o.ruta is null or (o.bytes is not null and o.bytes <> x.bytes))
      into v_n, v_tot, v_d
      from emision_pdfs x
      join emision_documentos d on d.id = x.documento_id
      left join fn_emision_storage() o on o.ruta = x.ruta;
  else
    v_n := 0; v_tot := (select count(*) from emision_pdfs);
  end if;
  orden := 50; cuadre := 'facturas: cada PDF registrado sigue en su sitio'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when not v_storage then format('Esta base no tiene Storage: los %s PDF registrados no se pueden comprobar aquí.', v_tot)
                  when v_n = 0 then format('%s PDF registrado(s): todos siguen en el bucket facturas y miden lo que se registró (su sha256 '
                                           'queda guardado para comparar la copia que tenga el cliente).', v_tot)
                  else left(v_d, 1500) || ' → vuelve a pintar el PDF de esa factura desde su documento (sale del mismo contenido '
                       'congelado; queda como una versión nueva).' end;
  return next;

  -- 60 (aviso): ninguna factura emitida hace más de N días sin PDF
  select count(*), string_agg(format('%s (del %s%s)', d.numero, fn_emision_dia(d.fecha),
                                     case when d.forma = 'retencion' then '; es la de la retención' else '' end), ', ' order by d.numero)
    into v_n, v_d
    from emision_documentos d
   where d.estado = 'emitida' and d.anulado_el is null and v_hoy - d.fecha > cfg.pdf_dias
     and not exists (select 1 from emision_pdfs x where x.documento_id = d.id);
  orden := 60; cuadre := format('facturas: ninguna emitida hace más de %s día(s) sin su PDF', cfg.pdf_dias); nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Cada factura emitida tiene su PDF (o es de estos días).'
                  else left(v_d, 1500) || ' → están emitidas (las facturas, ya en el libro; la de la retención no lleva asiento), pero '
                       'sin su PDF: ábrelas en Facturación y genera el PDF.' end;
  return next;

  -- 62 (aviso): ni sin mandar
  select count(*), string_agg(format('%s (del %s)', d.numero, fn_emision_dia(d.fecha)), ', ' order by d.numero) into v_n, v_d
    from emision_documentos d
   where d.estado = 'emitida' and d.anulado_el is null and v_hoy - d.fecha > cfg.pdf_dias
     and not exists (select 1 from emision_envios e where e.documento_id = d.id);
  orden := 62; cuadre := format('facturas: ninguna emitida hace más de %s día(s) sin mandar', cfg.pdf_dias); nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Cada factura emitida se mandó o se entregó (o es de estos días).'
                  else left(v_d, 1500) || ' → el cliente todavía no las tiene: mándalas desde Facturación, o apunta que se '
                       'entregaron en mano.' end;
  return next;

  -- 64 (aviso): una factura de la app que el LIBRO ya tiene cobrada entera (no debe nada en la cuenta por cobrar ni en la
  -- retención por cobrar) y que en la ficha de su obra sigue sin marcar como cobrada. Desde el corte nadie marca esa casilla
  -- sola (antes la marcaba QuickBooks): esta capa no la toca —es de Edgar—, pero lo dice.
  select count(*), string_agg(format('%s (%s, de %s)', d.numero, fn_emision_usd(d.monto), coalesce(p.nombre, d.proyecto_id)), ', '
                              order by d.numero)
    into v_n, v_d
    from emision_documentos d
    join facturas f on f.id = d.factura_id
    left join proyectos p on p.id = d.proyecto_id
   cross join lateral fn_emision_saldo(d.factura_id) s
   where d.estado = 'emitida' and d.anulado_el is null and f.estado <> 'anulada'
     and s.cxc = 0 and s.retencion = 0 and not coalesce(f.pagada, false);
  orden := 64; cuadre := 'facturas: las cobradas en el libro, marcadas como cobradas en su obra'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Ninguna factura de la app que el libro tenga cobrada entera está sin marcar como cobrada en la '
                                    'ficha de su obra.'
                  else left(v_d, 1500) || ' → el libro ya las tiene cobradas enteras y en la ficha de su obra siguen sin marcar: '
                       'mientras no se marquen, la ficha y el portal del cliente las enseñan como pendientes de pago. Márcalas como '
                       'cobradas en la obra (Dinero → la factura → cobrada); hoy nada lo hace solo.' end;
  return next;

  -- 70 (aviso): una factura que no salió de la app con una «retención» que parece un porcentaje
  select count(*), string_agg(format('la factura #%s de %s (monto %s) dice retención %s%s', y.num, y.obra, fn_emision_usd(y.monto),
                                     trim_scale(y.retencion),
                                     case when y.en_libro then format(': al libro entraron %s a la retención por cobrar', fn_emision_usd(y.retencion))
                                          else '' end), '; ' order by y.num)
    into v_n, v_d
    from (select f.num, coalesce(p.nombre, f.proyecto_id) as obra, round(f.monto, 2) as monto, f.retencion,
                 f.contabilizado_en is not null as en_libro
            from facturas f
            left join proyectos p on p.id = f.proyecto_id
           where f.retencion > 0 and f.retencion <= 100 and f.estado <> 'anulada'
             and not exists (select 1 from emision_documentos d where d.factura_id = f.id)
             and f.retencion is distinct from
                 fn_emision_retencion(round(f.monto, 2), (fn_emision_retencion_de(f.proyecto_id)->>'pct')::numeric)) y;
  orden := 70; cuadre := 'facturas: ninguna retención que parezca un porcentaje'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0
                  then 'Ninguna factura hecha fuera de la app trae una retención entre 0 y 100 que no cuadre con el porcentaje de su obra.'
                  else left(v_d, 1500) || ' → la retención de una factura va en DÓLARES (lo que el cliente retiene de esa factura). Si ahí '
                       'se escribió el porcentaje (lo hace la función de QuickBooks en las obras por contratista), el libro tiene mal '
                       'repartido lo por cobrar y lo retenido de esa factura: avisa; se corrige con un asiento entre las dos cuentas.' end;
  return next;

  -- 72 (aviso): ninguna factura fechada desde el corte que no salió de la app; ni una hecha fuera —de la fecha que sea— con
  -- un número con la forma de la serie (la serie lo salta para no darlo dos veces) o con el mismo número que una de la app.
  select count(*), string_agg(format('#%s (del %s, %s%s)', f.num, fn_emision_dia(f.fecha), fn_emision_usd(round(f.monto, 2)),
                                     case when exists (select 1 from emision_documentos d where d.numero = f.num)
                                            then '; lleva el MISMO número que una factura de la app'
                                          when f.num ~ v_patron then '; lleva un número con la forma de la serie: la serie lo salta'
                                          else '' end), ', ' order by f.fecha, f.id)
    into v_n, v_d
    from facturas f
   where ((f.fecha >= cfg.corte and f.estado <> 'anulada') or coalesce(f.num ~ v_patron, false))
     and not exists (select 1 from emision_documentos d where d.factura_id = f.id);
  orden := 72; cuadre := 'facturas: desde el corte, todas salen de la app'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then format('Ninguna factura fechada desde el %s se hizo fuera de la app, y ninguna de fuera lleva un '
                                           'número de la serie.', fn_emision_dia(cfg.corte))
                  else left(v_d, 1500) || format(' → desde el %s se factura por la app: esas se hicieron por otro camino '
                       '(¿QuickBooks?, ¿a mano en la ficha?). Mira si están bien así. La que lleva un número con la forma de la serie: '
                       'la app salta ese número para no darlo dos veces. La que lleva el mismo número que una factura de la app: una '
                       'de las dos sobra; avisa.', fn_emision_dia(cfg.corte)) end;
  return next;

  -- 75 (aviso): anuladas en el libro y sin cerrar aquí; una factura de la retención que reclama lo de una anulada; hitos
  -- con dos facturas vivas de antes; y hitos que la ficha sigue teniendo como facturados con su factura anulada
  select count(*), string_agg(y.que, '; ' order by y.que) into v_n, v_d
    from (select format('la factura %s está anulada en el libro y aquí sigue como emitida', d.numero) as que
            from emision_documentos d
            join facturas f on f.id = d.factura_id
           where d.estado = 'emitida' and d.anulado_el is null and f.estado = 'anulada'
          union all
          select format('la factura de la retención %s reclama lo retenido de la factura %s, que está anulada', r.numero,
                        coalesce(rl.ref->>'numero', '#' || f.num))
            from emision_documentos r
            join emision_lineas rl on rl.documento_id = r.id
            join facturas f on f.id::text = rl.ref->>'factura_id'
           where r.forma = 'retencion' and r.estado = 'emitida' and r.anulado_el is null and f.estado = 'anulada'
          union all
          select format('el hito «%s» de %s tiene %s facturas vivas de antes (%s)', h.titulo, coalesce(p.nombre, h.proyecto_id), x.n, x.nums)
            from (select coalesce(d.hito_id, f.hito_id) as hito_id, count(*) as n, string_agg(f.num, ', ' order by f.id) as nums
                    from facturas f
                    left join emision_documentos d on d.factura_id = f.id and d.anulado_el is null
                   where f.estado <> 'anulada' and coalesce(d.hito_id, f.hito_id) is not null
                   group by coalesce(d.hito_id, f.hito_id)
                  having count(*) > 1 and not bool_or(d.id is not null)) x
            join hitos h on h.id = x.hito_id
            left join proyectos p on p.id = h.proyecto_id
          union all
          -- (un hito que la ficha SIGUE teniendo como facturado, sin ninguna factura viva, y con su factura ANULADA todavía
          -- apuntándolo: se anuló desde Contabilidad —por c3, que no sabe de hitos; así se anula una de QuickBooks— y nadie
          -- devolvió el hito a pendiente. La de la app que sigue sin cerrar aquí ya sale arriba: aquí no se repite)
          select format('el hito «%s» de %s sigue como facturado en la ficha y %s: no tiene ninguna factura viva', h.titulo,
                        coalesce(p.nombre, h.proyecto_id),
                        case when x.n = 1 then 'su factura ' || x.nums || ' está anulada' else 'sus facturas ' || x.nums || ' están anuladas' end)
            from hitos h
            left join proyectos p on p.id = h.proyecto_id
           cross join lateral (select count(*) as n,
                                      string_agg(f.num || coalesce(' (nota de crédito ' || n.numero || ')', ''), ', ' order by f.id) as nums
                                 from facturas f
                                 left join notas_credito n on n.anula_a = f.id
                                where f.hito_id = h.id and f.estado = 'anulada') x
           where h.estado = 'facturado' and x.n > 0
             and not exists (select 1 from fn_emision_factura_de_hito(h.id))
             and not exists (select 1 from emision_documentos d
                               join facturas f on f.id = d.factura_id
                              where d.hito_id = h.id and d.forma = 'hito' and d.estado = 'emitida' and d.anulado_el is null
                                and f.estado = 'anulada')) y;
  orden := 75; cuadre := 'facturas: ninguna anulación a medias, ningún hito con dos facturas de antes'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Toda factura de la app anulada en el libro está cerrada aquí, ninguna factura de la retención reclama lo de '
                                    'una anulada, ningún hito trae dos facturas vivas de antes, y ninguno sigue como facturado en la ficha '
                                    'con su factura anulada.'
                  else left(v_d, 1500) || ' → la anulada: ábrela en Facturación y toca Anular (termina lo de aquí y suelta su hito; si ya '
                       'sale anulada y no ofrece el botón, avisa y se hace). La de la retención que reclama una anulada: anúlala y haz otra '
                       '(el cliente tiene una cuenta que ya no es). El hito con dos facturas de antes: mira cuál sobra. El hito que sigue '
                       'como facturado con su factura anulada: si no se volvió a facturar por otro lado, está SIN FACTURAR, y para hacer la '
                       'buena tiene que volver antes a pendiente; si sí se volvió a facturar (en QuickBooks), esa factura tiene que quedar '
                       'enlazada a su hito. La ficha no tiene botón para ninguna de las dos cosas: avisa y se hace.' end;
  return next;

  -- 80 (aviso): el pago en línea como se decidió (12-nov-2026: solo por cuenta de banco; la tarjeta, apagada). Cada cosa,
  -- con qué hacer.
  select count(*), string_agg(y.que, '; ' order by y.que) into v_n, v_d
    from (select format('la factura %s se cobró con tarjeta (%s): su enlace no estaba restringido a cuenta de banco, y la comisión de la '
                        'tarjeta la pagó la empresa → avisa para revisar cómo se crean los enlaces', d.numero, fn_emision_usd(s.monto)) as que
            from fn_emision_pagos() s
            join emision_documentos d on d.factura_id = s.factura_id
           where s.medio = 'tarjeta' and s.estado not in ('fallido', 'iniciado')
             and not (fn_emision_tarjeta_lista() and cfg.tarjeta_pct is not null)
          union all
          select format('el porcentaje de la tarjeta está puesto (%s %%) y la tarjeta sigue apagada → quítalo de los ajustes de facturación '
                        'hasta que la tarjeta se pueda encender', trim_scale(cfg.tarjeta_pct))
           where cfg.tarjeta_pct is not null and not fn_emision_tarjeta_lista()
          union all
          select format('la factura %s está anulada y tiene un pago por cuenta de banco en camino (%s): cuando entre, los cobros en línea '
                        'lo dejarán de anticipo de la obra → cuando llegue, aplícalo a la factura buena (o devuélvelo)', d.numero,
                        fn_emision_usd(sum(s.monto)))
            from fn_emision_pagos() s
            join emision_documentos d on d.factura_id = s.factura_id
            join facturas f on f.id = d.factura_id
           where s.estado in ('iniciado', 'en_camino') and (d.anulado_el is not null or f.estado = 'anulada')
           group by d.numero) y;
  orden := 80; cuadre := 'facturas: el pago en línea, solo por cuenta de banco'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Ninguna factura de la app se cobró con tarjeta, el porcentaje de la tarjeta está vacío y ninguna '
                                    'anulada tiene un pago en camino. ' || fn_emision_tarjeta_texto()
                  else left(v_d, 1500) || '.' end;
  return next;

  -- 85 (aviso): los datos de la empresa y el «How to pay», puestos cuando se acerca el corte
  v_d := concat_ws(' y ', case when coalesce(btrim(cfg.empresa->>'nombre'), '') = '' then 'los datos de la empresa' end,
                          case when btrim(cfg.como_pagar) = '' then 'el texto «How to pay»' end);
  orden := 85; cuadre := 'facturas: los datos de la empresa y el «How to pay»'; nivel := 'aviso';
  ok := v_d = '' or v_hoy < cfg.corte - 14;
  detalle := case when v_d = '' then 'Los datos de la empresa y el «How to pay» están puestos.'
                  when v_hoy < cfg.corte - 14
                    then format('Faltan %s en los ajustes de facturación; se piden desde dos semanas antes del corte (%s).', v_d,
                                fn_emision_dia(cfg.corte))
                  else format('Faltan %s en los ajustes de facturación → sin eso no se puede emitir ninguna factura: ponlos en '
                              'Facturación → Ajustes (en inglés: los ve el cliente).', v_d) end;
  return next;

  -- 90: las protecciones de la capa (por nombre exacto), y los candados del bucket «facturas» si esta base tiene Storage
  -- (sus policies se leen del catálogo: solo el dueño, con el código del teléfono, sube y lee; nadie borra ni pisa).
  select count(*), string_agg(y.que, '; ') into v_n, v_d
    from (select pr.proname || ' es SECURITY DEFINER' as que
            from pg_catalog.pg_proc pr
           where pr.pronamespace = 'public'::regnamespace and pr.proname = any (c_fn) and pr.prosecdef and pr.proname <> 'fn_emision_numerar'
          union all
          select 'la función del número ya no es la de un trigger con los permisos del dueño de la base'
            from pg_catalog.pg_proc pr
           where pr.pronamespace = 'public'::regnamespace and pr.proname = 'fn_emision_numerar'
             and (not pr.prosecdef or pr.prorettype <> 'trigger'::regtype)
          union all
          select format('%s la puede ejecutar %s', pr.proname, g.r)
            from pg_catalog.pg_proc pr cross join (values ('anon'), ('service_role')) g(r)
           where pr.pronamespace = 'public'::regnamespace and pr.proname = any (c_fn) and has_function_privilege(g.r, pr.oid, 'execute')
          union all
          select pr.proname || ' la puede ejecutar authenticated'
            from pg_catalog.pg_proc pr
           where pr.pronamespace = 'public'::regnamespace
             and pr.proname in ('fn_emision_precondiciones', 'fn_emision_guarda', 'fn_emision_numerar', 'fn_emision_pegado')
             and has_function_privilege('authenticated', pr.oid, 'execute')
          union all
          select c.relname || case when not c.relrowsecurity then ' sin RLS' else ' sin su policy de lectura del dueño' end
            from pg_catalog.pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname = any (c_tablas)
             and (not c.relrowsecurity
                  or not exists (select 1 from pg_catalog.pg_policy pl
                                  where pl.polrelid = c.oid and pl.polname = c.relname || '_dueno' and pl.polcmd = 'r'))
          union all
          select format('%s puede %s en %s', g.r, q.q, c.relname)
            from pg_catalog.pg_class c
            cross join (values ('anon'), ('service_role')) g(r)
            cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) q(q)
           where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v')
             and (c.relname = any (c_tablas) or c.relname = any (c_vistas))
             and has_table_privilege(g.r, c.oid, q.q)
          union all
          select format('authenticated puede %s en %s', q.q, c.relname)
            from pg_catalog.pg_class c
            cross join (values ('DELETE'), ('TRUNCATE')) q(q)
           where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname = any (c_tablas)
             and not (q.q = 'DELETE' and c.relname in ('emision_documentos', 'emision_lineas'))
             and has_table_privilege('authenticated', c.oid, q.q)
          union all
          select c.relname || ' sin security_invoker'
            from pg_catalog.pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname = any (c_vistas)
             and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o
                                where o.option_name = 'security_invoker'), false)
          union all
          select format('la guarda %s de %s %s', x.tg, x.t,
                        case when tg.oid is null then 'no está' when tg.tgenabled not in ('O', 'A') then 'está apagada'
                             else 'tiene otra función' end)
            from (select t.t, 'trg_' || t.t || s.s as tg, 'fn_emision_guarda' as fn
                    from unnest(c_tablas) t(t) cross join (values ('_guarda'), ('_sin_truncate')) s(s)
                  union all
                  select 'emision_serie', 'trg_emision_serie_numerar', 'fn_emision_numerar') x
            left join pg_catalog.pg_trigger tg on tg.tgrelid = to_regclass('public.' || x.t) and tg.tgname = x.tg
           where tg.oid is null or tg.tgenabled not in ('O', 'A')
              or tg.tgfoid is distinct from to_regprocedure('public.' || x.fn || '()')
          union all
          select 'el bucket de las facturas: ' || b.que
            from (select 'la tabla de Storage no tiene sus candados encendidos (RLS)' as que
                   where not coalesce((select c.relrowsecurity from pg_catalog.pg_class c
                                        where c.oid = to_regclass('storage.objects')), false)
                  union all
                  select format('falta el candado «%s»', n.n)
                    from unnest(c_bucket_aal || c_bucket_cierra) n(n)
                   where not exists (select 1 from pg_catalog.pg_policy pl
                                      where pl.polrelid = to_regclass('storage.objects') and pl.polname = n.n)
                   group by n.n
                  union all
                  select format('el candado «%s» no pide el código del teléfono', pl.polname)
                    from pg_catalog.pg_policy pl
                   where pl.polrelid = to_regclass('storage.objects') and pl.polname = any (c_bucket_aal)
                     and coalesce(pg_get_expr(pl.polqual, pl.polrelid), '') || coalesce(pg_get_expr(pl.polwithcheck, pl.polrelid), '')
                         not like '%aal2%'
                  union all
                  select format('el candado «%s» ya no es de los que cierran', pl.polname)
                    from pg_catalog.pg_policy pl
                   where pl.polrelid = to_regclass('storage.objects') and pl.polname = any (c_bucket_cierra) and pl.polpermissive) b
           where v_storage) y;
  orden := 90; cuadre := 'facturas: protecciones de la capa'; nivel := 'cuadre'; ok := v_n = 0;
  detalle := case when v_n = 0
                  then 'Solo la función del número corre con los permisos del dueño de la base (es de trigger y nadie la ejecuta '
                       'suelta); ninguna la ejecutan anon ni service_role; las tablas con RLS y su guarda; las vistas '
                       'security_invoker; '
                       || case when v_storage then 'y el bucket de las facturas, solo para el dueño con su código del teléfono (nadie '
                                                   'borra ni pisa).'
                               else 'esta base no tiene Storage: el bucket de las facturas no se mira aquí.' end
                  else left(v_d, 1500) || ' → vuelve a pegar c11-emision.sql (lo pone como debe).' end;
  return next;
end $$;
revoke execute on function public.fn_emision_control() from public, anon, service_role;
grant  execute on function public.fn_emision_control() to authenticated;
comment on function public.fn_emision_control() is 'c11: el control de la facturación (lo que enseña v_emision_control): orden, cuadre, nivel (cuadre o aviso), ok y el detalle en llano. Solo lee; a quien no es el dueño no le devuelve nada.';


-- ---------------------------------------------------------------------
-- 10. LAS VISTAS de la pantalla (security_invoker: cada una con los
--     permisos de quien la lee; solo leen tablas y funciones de aquí).
-- ---------------------------------------------------------------------
-- POR DÓNDE SE FACTURA HOY (una fila): la app o QuickBooks, y lo que la
-- pantalla necesita para decirlo. siguiente_numero: el de la serie de las
-- facturas del año en que se va a emitir (el de hoy, o el del corte si
-- todavía no llegó), ya saltando los que lleve una factura hecha fuera de
-- la app. corte_hasta: el último día en que se puede poner el corte (la
-- fecha de la primera factura viva emitida por la app; nulo = cualquiera).
-- tarjeta_texto: por qué la tarjeta está apagada, en llano.
create view public.v_emision_estado with (security_invoker = true) as
select h.hoy,
       c.corte,
       h.hoy >= c.corte as por_la_app,
       case when h.hoy >= c.corte then 'app' else 'quickbooks' end as camino,
       case when h.hoy >= c.corte
            then format('Desde el %s las facturas se emiten aquí, con su número de la serie del año.', public.fn_emision_dia(c.corte))
            else format('Hasta el %s las facturas salen por QuickBooks (el 🧾 de siempre). Aquí se pueden preparar borradores para '
                        'probar; se podrán emitir desde el %s.', public.fn_emision_dia(c.corte - 1), public.fn_emision_dia(c.corte)) end
         as texto,
       greatest(c.corte - h.hoy, 0) as dias_para_el_corte,
       c.serie_formato,
       public.fn_emision_numero(c.serie_formato, sn.anio, sn.sec) as siguiente_numero,
       c.terminos_dias,
       array_remove(array[case when coalesce(btrim(c.empresa->>'nombre'), '') = '' then 'empresa' end,
                          case when btrim(c.como_pagar) = '' then 'como_pagar' end], null) as falta,
       h.hoy >= c.corte and coalesce(btrim(c.empresa->>'nombre'), '') <> '' and btrim(c.como_pagar) <> '' as puede_emitir,
       c.ach and to_regclass('public.stripe_enlaces') is not null as pago_en_linea,
       c.tarjeta_pct is not null and public.fn_emision_tarjeta_lista() as tarjeta,
       (select count(*) from public.emision_documentos d where d.estado = 'borrador') as borradores,
       (select count(*) from public.emision_documentos d where d.estado = 'emitida' and d.anulado_el is null) as emitidas,
       (select count(*) from public.emision_documentos d where d.anulado_el is not null) as anuladas,
       (select count(*) from public.emision_documentos d
         where d.estado = 'emitida' and d.anulado_el is null
           and not exists (select 1 from public.emision_pdfs x where x.documento_id = d.id)) as sin_pdf,
       (select count(*) from public.emision_documentos d
         where d.estado = 'emitida' and d.anulado_el is null
           and not exists (select 1 from public.emision_envios e where e.documento_id = d.id)) as sin_mandar,
       (select min(d.fecha)
          from public.emision_documentos d
          left join public.facturas f on f.id = d.factura_id
         where d.estado = 'emitida' and d.anulado_el is null and coalesce(f.estado, 'emitida') <> 'anulada') as corte_hasta,
       public.fn_emision_tarjeta_texto() as tarjeta_texto
  from public.emision_config c
 cross join (select public.fn_fecha_miami(now()) as hoy) h
 cross join lateral (select y.anio,
                            (select min(k.k)
                               from generate_series(y.ultimo + 1, y.ultimo + 51) k(k)
                              where not exists (select 1 from public.facturas f
                                                 where f.num = public.fn_emision_numero(c.serie_formato, y.anio, k.k))) as sec
                       from (select a.anio,
                                    coalesce((select max(s.secuencia) from public.emision_serie s
                                               where s.serie = 'facturas' and s.anio = a.anio), 0) as ultimo
                               from (select extract(year from greatest(h.hoy, c.corte))::int as anio) a) y) sn
 where c.id = 1 and (select public.fn_emision_ve());
revoke all on public.v_emision_estado from public, anon, authenticated, service_role;
grant select on public.v_emision_estado to authenticated;
comment on view public.v_emision_estado is 'c11: por dónde se factura hoy (una fila): hoy (en Miami), el corte, por_la_app y camino (app o quickbooks: la pantalla desvía el 🧾 con esto), texto (en llano), dias_para_el_corte, el formato y el siguiente número de la serie de las facturas (del año en que se va a emitir, ya saltando los que lleve una factura hecha fuera de la app), terminos_dias, falta (lo que falta en los ajustes para poder emitir: empresa, como_pagar), puede_emitir, pago_en_linea (por cuenta de banco, con los cobros en línea instalados), tarjeta (apagada) y tarjeta_texto (por qué, en llano), cuántos borradores, emitidas, anuladas, sin PDF y sin mandar hay, y corte_hasta (el último día en que se puede poner el corte: la fecha de la primera factura viva emitida por la app; nulo = cualquiera).';

-- LOS DOCUMENTOS: una fila por borrador o factura emitida, con lo que la
-- lista de la pantalla pinta. estado: borrador, emitida o anulada.
create view public.v_emision_documentos with (security_invoker = true) as
select d.id,
       case when d.estado = 'borrador' then 'borrador'
            when d.anulado_el is not null or f.estado = 'anulada' then 'anulada' else 'emitida' end as estado,
       d.forma, d.proyecto_id, p.nombre as obra, d.cliente->>'nombre' as cliente, d.a_contratista,
       d.hito_id, h.titulo as hito, d.es_deposito,
       d.numero, d.fecha, d.vence, d.monto, d.retencion_pct, d.retencion, d.a_pagar,
       d.factura_id, a.numero as asiento,
       s.cxc as saldo, s.retencion as saldo_retencion,
       coalesce(d.nota_credito, n.numero) as nota_credito, d.anulado_el, d.anulado_motivo,
       x.pdfs, x.pdf_ruta, x.pdf_el,
       e.envios, e.enviado_el, e.enviado_a,
       case when d.estado = 'borrador' then public.fn_emision_visto(d.id) end as visto,
       d.creado_el, d.actualizado_el, d.emitido_el
  from public.emision_documentos d
  left join public.proyectos p on p.id = d.proyecto_id
  left join public.hitos h on h.id = d.hito_id
  left join public.facturas f on f.id = d.factura_id
  left join public.asientos a on a.id = coalesce(f.contabilizado_en, d.asiento_id)
  left join public.notas_credito n on n.anula_a = d.factura_id
  left join lateral (select t.cxc, t.retencion from public.fn_emision_saldo(d.factura_id) t where d.factura_id is not null) s on true
  left join lateral (select count(*)::int as pdfs,
                            (array_agg(y.ruta order by y.n desc))[1] as pdf_ruta, max(y.creado_el) as pdf_el
                       from public.emision_pdfs y where y.documento_id = d.id) x on true
  left join lateral (select count(*)::int as envios, max(y.enviado_el) as enviado_el,
                            (array_agg(y.para order by y.n desc))[1] as enviado_a
                       from public.emision_envios y where y.documento_id = d.id) e on true
 where (select public.fn_emision_ve());
revoke all on public.v_emision_documentos from public, anon, authenticated, service_role;
grant select on public.v_emision_documentos to authenticated;
comment on view public.v_emision_documentos is 'c11: cada borrador y cada factura emitida por la app: id, estado (borrador, emitida o anulada), forma, la obra, a quién (cliente, a_contratista), el hito y si es el de depósito, numero, fecha, vence, monto, retencion_pct, retencion, a_pagar, su factura y su asiento (el de hoy en el libro), lo que debe hoy en el libro (saldo y saldo_retencion), su nota de crédito y su anulación, cuántos PDF y el último (pdf_ruta, pdf_el), cuántos envíos y el último (enviado_el, enviado_a), el visto de un borrador (la huella de su vista previa entera), y sus fechas.';

-- LAS OBRAS, para facturar: su contrato, lo facturado, su retención y sus
-- hitos (con su factura viva o su borrador, y si se pueden facturar). La
-- factura viva de un hito es la que apunta a él o la que la app emitió de
-- él (fn_emision_factura_de_hito): un hito cuya fila de facturas dejó de
-- apuntarlo sigue saliendo como facturado, y no se puede facturar otra vez.
-- «puede» = el hito está PENDIENTE, no tiene factura viva y tiene monto: el
-- que la ficha ya tiene como facturado (o cobrado) no se ofrece, tenga o no
-- su factura enlazada aquí.
create view public.v_emision_obras with (security_invoker = true) as
select p.id as proyecto_id, p.nombre as obra, p.tipo, p.estado,
       dest.d->'cliente'->>'nombre' as cliente,
       coalesce((dest.d->>'a_contratista')::boolean, false) as a_contratista,
       round(fp.contrato, 2) as contrato,
       fa.facturado, fa.facturas,
       case when fp.contrato is not null then round(fp.contrato, 2) - fa.facturado end as por_facturar,
       (ret.r->>'pct')::numeric as retencion_pct, ret.r->>'origen' as retencion_origen,
       rl.retenido,
       hi.hitos_pendientes, hi.hitos_pendientes_monto, hi.hitos,
       (select count(*)::int from public.emision_documentos d where d.proyecto_id = p.id and d.estado = 'borrador') as borradores,
       exists (select 1 from public.mapeo_tipo_proyecto m
                where m.tipo = nullif(lower(btrim(regexp_replace(coalesce(p.tipo, ''), '[[:space:]]+', ' ', 'g'))), '')
                  and m.confirmado_el is not null) as ingreso_listo
  from public.proyectos p
  left join public.finanzas_proyecto fp on fp.proyecto_id = p.id
 cross join lateral (select public.fn_emision_destinatario(p.id) as d) dest
 cross join lateral (select public.fn_emision_retencion_de(p.id) as r) ret
 cross join lateral (select coalesce(sum(round(f.monto, 2)), 0)::numeric(14,2) as facturado, count(*)::int as facturas
                       from public.facturas f where f.proyecto_id = p.id and f.estado = 'emitida') fa
 cross join lateral (select coalesce(sum(l.monto), 0)::numeric(14,2) as retenido
                       from public.facturas f
                       join public.asiento_lineas l on l.partida_tabla = 'facturas' and l.partida_id = f.id::text
                      where f.proyecto_id = p.id and l.cuenta = (select public.fn_emision_cuenta('retencion_cxc'))) rl
 cross join lateral (select count(*) filter (where y.puede)::int as hitos_pendientes,
                            coalesce(sum(y.monto) filter (where y.puede), 0)::numeric(14,2) as hitos_pendientes_monto,
                            coalesce(jsonb_agg(jsonb_build_object('id', y.id, 'titulo', y.titulo, 'monto', y.monto, 'estado', y.estado,
                                                                  'es_deposito', y.es_deposito, 'factura', y.factura,
                                                                  'borrador', y.borrador, 'puede', y.puede)
                                               order by y.orden, y.id), '[]'::jsonb) as hitos
                       from (select h.id, h.titulo, round(h.monto, 2) as monto, h.estado, coalesce(h.es_deposito, false) as es_deposito,
                                    coalesce(h.orden, 0) as orden, fv.num as factura, bo.id as borrador,
                                    coalesce(h.estado, 'pendiente') = 'pendiente' and fv.num is null
                                      and coalesce(round(h.monto, 2), 0) > 0 as puede
                               from public.hitos h
                               left join lateral (select x.num from public.fn_emision_factura_de_hito(h.id) x
                                                   order by x.factura_id limit 1) fv on true
                               left join lateral (select d.id from public.emision_documentos d
                                                   where d.hito_id = h.id and d.estado = 'borrador' limit 1) bo on true
                              where h.proyecto_id = p.id) y) hi
 where (select public.fn_emision_ve());
revoke all on public.v_emision_obras from public, anon, authenticated, service_role;
grant select on public.v_emision_obras to authenticated;
comment on view public.v_emision_obras is 'c11: cada obra, para facturarla: a quién se factura (cliente, a_contratista), su contrato (finanzas_proyecto.contrato), lo facturado (las facturas emitidas y sin anular) y cuántas, por_facturar, su retención (retencion_pct y de dónde sale: obra, estimado o ninguna), lo retenido que el libro tiene por cobrar (retenido), sus hitos por facturar (hitos_pendientes y su monto: los pendientes sin factura viva) y la lista de todos (hitos: [{id, titulo, monto, estado, es_deposito, factura: el número de su factura viva —la que apunta a él o la que la app emitió de él—, borrador: el id de su borrador, puede: si se puede facturar (pendiente, sin factura viva y con monto)}]), cuántos borradores tiene y si su tipo de obra tiene su regla de ingreso confirmada (ingreso_listo: sin ella el libro no acepta la factura).';

-- EL CONTROL, como vista.
create view public.v_emision_control with (security_invoker = true) as
select c.orden, c.cuadre, c.nivel, c.ok, c.detalle from public.fn_emision_control() c;
revoke all on public.v_emision_control from public, anon, authenticated, service_role;
grant select on public.v_emision_control to authenticated;
comment on view public.v_emision_control is 'c11: el control de la facturación (orden, cuadre, nivel, ok, detalle en llano): 10 cada factura emitida por la app es su asiento de c3, al centavo; 20 las series de cada año (facturas y facturas de la retención) sin huecos ni repetidos y cada contador en el último (un número saltado vale solo si lo lleva una factura hecha fuera de la app); 30 cada documento emitido sigue sellado y su fila de facturas dice lo mismo; 40 ningún hito con dos facturas vivas si alguna salió de la app (el hito de una factura de la app es el de su documento); 42 (aviso) cada factura de hito sigue enlazada a su hito; 44 (aviso) en ninguna obra lo facturado por hitos pasa de lo que suman sus hitos; 50 (aviso) cada PDF registrado sigue en Storage y mide lo mismo; 60 (aviso) ninguna emitida hace más de N días sin PDF; 62 (aviso) ni sin mandar; 64 (aviso) ninguna cobrada entera en el libro y sin marcar como cobrada en su obra; 70 (aviso) ninguna factura de fuera de la app con una retención que parece un porcentaje; 72 (aviso) ninguna fechada desde el corte hecha fuera de la app, ni una de fuera con un número de la serie; 75 (aviso) ninguna anulación a medias, ninguna factura de la retención que reclame lo de una anulada, ni hitos con dos facturas de antes, ni hitos que sigan como facturados en la ficha con su factura anulada y sin otra viva; 80 (aviso) el pago en línea solo por cuenta de banco (la tarjeta, apagada); 85 (aviso) los datos de la empresa y el «How to pay»; 90 las protecciones de la capa y los candados del bucket de las facturas. nivel: cuadre (algo roto: detiene el cierre) o aviso.';

-- ---------------------------------------------------------------------
-- 11. Lo que enseña el SQL Editor al terminar de pegar.
-- ---------------------------------------------------------------------
create or replace function public.fn_emision_pegado() returns table (que text, detalle text)
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg     emision_config;
  v_hoy   date := fn_fecha_miami(now());
  v_anio  int;
  v_falta text;
  v_rojos text;
  v_idx   text;
  v_todas boolean;
  v_nsol  bigint;
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto lo enseña el SQL Editor al pegar c11-emision.sql.';
  end if;
  select * into cfg from emision_config where id = 1;
  v_anio := extract(year from greatest(v_hoy, cfg.corte))::int;
  return query select 'ajustes'::text,
    format('corte %s · número %s · %s · pago en línea por cuenta de banco: %s · tarjeta: apagada · aviso de PDF a los %s día(s)',
           fn_emision_dia(cfg.corte), cfg.serie_formato,
           case when cfg.terminos_dias = 0 then 'se paga al recibirla (Due on receipt)' else format('vence a los %s días', cfg.terminos_dias) end,
           case when cfg.ach then 'sí' else 'no' end, cfg.pdf_dias);
  return query select 'por dónde se factura hoy'::text,
    case when v_hoy >= cfg.corte then format('por la app (el corte fue el %s)', fn_emision_dia(cfg.corte))
         else format('por QuickBooks, hasta el %s (faltan %s días); aquí, borradores para probar', fn_emision_dia(cfg.corte - 1),
                     cfg.corte - v_hoy) end;
  return query select 'la serie'::text,
    coalesce((select string_agg(format('%s de %s: %s número(s), el último %s',
                                       case s.serie when 'facturas' then 'facturas' else 'facturas de la retención' end,
                                       s.anio, s.n, s.ultimo), ' · ' order by s.anio, s.serie)
                from (select x.serie, x.anio, count(*) as n, (array_agg(x.numero order by x.secuencia desc))[1] as ultimo
                        from emision_serie x group by x.serie, x.anio) s),
             format('sin estrenar: la primera factura será %s; la primera factura de la retención (que lleva su propia serie), %s',
                    fn_emision_numero(cfg.serie_formato, v_anio, 1),
                    fn_emision_numero(fn_emision_formato(cfg.serie_formato, 'retenciones'), v_anio, 1)));
  return query select 'tablas'::text, 'emision_config, emision_obras, emision_documentos, emision_lineas, emision_serie, emision_pdfs, emision_envios, emision_soltados'::text;
  return query select 'vistas'::text, 'v_emision_estado, v_emision_documentos, v_emision_obras, v_emision_control'::text;
  if to_regclass('storage.buckets') is not null and to_regclass('storage.objects') is not null then
    return query execute
      'select ''bucket facturas''::text, case '
      'when not exists (select 1 from storage.buckets b where b.id = ''facturas'') '
      '  then ''NO se pudo crear: créalo en Storage (privado) y vuelve a pegar'' '
      'when (select count(*) from pg_catalog.pg_policy pl where pl.polrelid = ''storage.objects''::regclass '
      '        and pl.polname = any (array[''facturas: el dueno sube'', ''facturas: el dueno lee'', '
      '                                    ''facturas: solo el dueno con su codigo lee'', ''facturas: solo el dueno con su codigo sube'', '
      '                                    ''facturas: la llave publica no entra'', ''facturas: no se borra'', ''facturas: no se pisa''])) < 7 '
      '  then ''existe (privado), pero NO se pudieron poner todos sus candados: ponlos en Storage → Policies (solo el dueño, con su '
      'código del teléfono, sube y lee; nadie borra); el control lo dice en rojo'' '
      'else ''existe (privado): solo el dueño, con su código del teléfono, sube y lee; nadie borra ni pisa'' end';
  else
    return query select 'bucket facturas'::text, 'sin Storage en esta base (en Supabase el bucket privado «facturas» se crea al pegar)'::text;
  end if;
  return query select 'pago en línea'::text,
    case when to_regclass('public.stripe_enlaces') is null
           then 'los cobros en línea (p1) no están en esta base: las facturas salen sin enlace de pago'
         when not cfg.ach then 'apagado en los ajustes (ach = false)'
         else 'por cuenta de banco (ACH), con el enlace de los cobros en línea restringido a cuenta de banco. '
              || fn_emision_tarjeta_texto() end;
  -- VOLVER A FACTURAR UN HITO: los índices únicos de facturas por hito que tenga esta base (son de la app, de la otra
  -- sesión: aquí no se crean ni se quitan), leídos del catálogo, y lo que la facturación hace con ellos.
  select string_agg(c.relname || case when coalesce(pg_get_expr(i.indpred, i.indrelid), '') ~* '\mestado\M' then ' (solo las vivas)'
                                      else ' (todas, también las anuladas)' end, ' y ' order by c.relname),
         coalesce(bool_or(coalesce(pg_get_expr(i.indpred, i.indrelid), '') !~* '\mestado\M'), false)
    into v_idx, v_todas
    from pg_catalog.pg_index i
    join pg_catalog.pg_class c on c.oid = i.indexrelid
   where i.indrelid = 'public.facturas'::regclass and i.indisunique and i.indisvalid and i.indnkeyatts = 1 and i.indexprs is null
     and i.indkey[0] = (select a.attnum from pg_catalog.pg_attribute a
                         where a.attrelid = i.indrelid and a.attname = 'hito_id' and not a.attisdropped);
  select count(*) into v_nsol from emision_soltados;
  return query select 'volver a facturar un hito'::text,
    case when v_todas
           then format('esta base admite UNA sola fila de facturas por hito, contando las anuladas (%s; de la app, no de aquí): se maneja '
                       '— al emitir la factura nueva de un hito, la anulada deja de apuntarlo (sigue anulada, con su nota de crédito) y '
                       'queda apuntado en emision_soltados', v_idx)
         when v_idx is not null
           then format('esta base no deja dos facturas vivas del mismo hito (%s; de la app, no de aquí) y no cuenta las anuladas; igual, '
                       'al emitir la factura nueva de un hito la anulada deja de apuntarlo y queda apuntado en emision_soltados', v_idx)
         else 'esta base no tiene un índice único de facturas por hito (producción sí: ux_facturas_hito); igual, al emitir la factura '
              'nueva de un hito la anulada deja de apuntarlo y queda apuntado en emision_soltados' end
    || format(' · soltadas hasta hoy: %s', v_nsol);
  v_falta := concat_ws('; ',
    nullif(concat_ws(' y ',
             case when coalesce(btrim(cfg.empresa->>'nombre'), '') = '' then 'los datos de la empresa (nombre, licencia, dirección, teléfono, correo, web)' end,
             case when btrim(cfg.como_pagar) = '' then 'el texto «How to pay» (en inglés)' end), '')
      || ' → se ponen en la app (Facturación → Ajustes) o con select fn_emision_config(''{…}'')',
    (select format('%s tipo(s) de obra sin su regla de ingreso confirmada (%s): sus facturas no entrarían al libro → se confirman en '
                   'Contabilidad (las reglas de ingreso por tipo de obra)', count(*), string_agg(m.tipo, ', ' order by m.tipo))
       from mapeo_tipo_proyecto m where m.confirmado_el is null having count(*) > 0));
  return query select 'qué falta'::text,
    case when v_falta = '' and v_hoy >= cfg.corte then 'nada: ya se puede emitir'
         when v_falta = '' then format('nada: se podrá emitir desde el corte (%s)', fn_emision_dia(cfg.corte))
         else v_falta end;
  select string_agg(format('%s (%s)', k.orden, k.nivel), ', ' order by k.orden) into v_rojos from fn_emision_control() k where not k.ok;
  return query select 'control'::text,
    format('%s control(es): %s', (select count(*) from fn_emision_control()), coalesce('en rojo ' || v_rojos, 'todos en verde'));
  return query select 'el cierre del mes'::text,
    case when to_regprocedure('public.fn_cierre_revisar(text)') is null then 'c9 (el cierre) no está en esta base'
         when exists (select 1 from pg_proc p where p.oid = to_regprocedure('public.fn_cierre_revisar(text)')
                                                   and p.prosrc like '%v_emision_control%')
           then 'mira estos controles (filas 172 y 173)'
         else 'todavía NO mira estos controles: vuelve a pegar docs/conta/c9-cierre.sql (el que trae las filas 172 y 173)' end;
  return query select 'siguiente paso'::text,
    'pega docs/conta/c11-pruebas.sql; después, en la app, Facturación → Ajustes: los datos de la empresa y el «How to pay»'::text;
end $$;
revoke execute on function public.fn_emision_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_emision_pegado() is 'c11: lo que enseña el SQL Editor al pegar c11-emision.sql (doce filas): los ajustes, por dónde se factura hoy, las series, las tablas y las vistas, el bucket y sus candados, el pago en línea, volver a facturar un hito (los índices únicos de facturas por hito que tenga la base —de la app— y cómo se manejan), qué falta, el control, si el cierre lo mira y el paso siguiente. Sin API.';

select * from public.fn_emision_pegado();
