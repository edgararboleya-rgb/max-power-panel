-- =====================================================================
-- c16-tablero.sql — LOS NÚMEROS DEL TABLERO: la portada «Resumen» de
-- Contabilidad, con gráficas, datos, números y enlaces, como el «Business
-- at a glance» de QuickBooks · c16 (no es la Fase 16 del plan, que es el contador de guardia).
-- 13-nov-2026 (marca 2026111303: con lo que encontraron las dos revisiones
-- del 13-nov, cada arreglo con su prueba en c16-pruebas.sql, de la 36 a la
-- 43, y la revisión final, de la 46 a la 50; «LO QUE CAMBIÓ», al final de
-- esta cabecera). Se pega en el SQL Editor
-- DESPUÉS de c1, c2, c3 y c4 (y de
-- c6, c7, s1, p1, c8, c9, c10, c11, c12, c13 y c14 si se usan: la cadena de
-- siempre). Idempotente: se puede volver a pegar entero las veces que haga
-- falta. Después se pega c16-pruebas.sql.
--
-- QUÉ ES. Edgar mandó dos capturas de la portada de QuickBooks y pidió que
-- la de la app «se viera de esta manera, con gráficas, datos, números y
-- enlaces de interés». Esta capa es la mitad que vive en la base: UNA
-- FUNCIÓN POR TARJETA, que devuelve en jsonb todo lo que la tarjeta enseña
-- YA CALCULADO (totales, porcentajes, diferencias, las series de cada
-- gráfica mes a mes con el mes en texto, los tramos de antigüedad, lo que
-- queda por revisar), y fn_tablero(p), que las junta en un solo jsonb con
-- una clave por tarjeta. La pantalla (js/conta.js) dibuja lo que llega: no
-- suma, no resta y no saca porcentajes (el dinero no se toca en
-- JavaScript).
--
-- SOLO LEE. No crea ninguna tabla ni vista, no guarda nada, no escribe en
-- el libro ni en ninguna tabla de otra capa, no pone triggers ni índices:
-- son funciones (ninguna SECURITY DEFINER) y nada más. Lo que la pantalla
-- recuerda de cada persona (qué tarjetas ve, si tapa los montos) lo guarda
-- su navegador: aquí no hay configuración.
--
-- LA VERDAD DE LOS NÚMEROS (lo que no se negocia):
--   · EL LIBRO EMPIEZA CON LA APERTURA (30-sep-2026): lo de antes vive en
--     QuickBooks. Una gráfica «de 12 meses» trae SOLO los meses que el
--     libro tiene y lo dice en llano (libro.texto, y en cada tarjeta
--     antes_del_libro): nunca inventa un mes ni pinta un cero donde no hay
--     libro (un mes DEL libro sin movimientos sí sale, en cero: no se
--     salta). Una comparación con un período que empieza antes del libro no
--     se hace (sale nula, con su porqué en «sin_comparar»).
--   · CADA NÚMERO SALE DE LA BASE: del libro, o de la vista de la capa que
--     ya lo sabe (la misma que enseña su página), y dice DE DÓNDE SALE
--     («fuente», en llano), CON QUÉ FECHA DE CORTE («corte», o «desde» y
--     «hasta») y A DÓNDE LLEVA («ir»: la página de Contabilidad y su
--     apartado, con las palabras de conta.js: ir(x.pagina, x)).
--   · «HOY» es el día de Miami (fn_fecha_miami de c2), como en todas las
--     capas. «Los últimos 30 días» son hoy y los 29 anteriores.
--   · UNA CAPA QUE NO ESTÁ deja SU tarjeta diciéndolo ({ok: false, falta:
--     «c6», motivo}) y las demás siguen. Una tarjeta que falla por lo que
--     sea, igual ({ok: false, motivo en llano, codigo, error}): fn_tablero no
--     se cae. Lo MAL PEDIDO (una tarjeta, una clave o un número que no
--     existen) sí: 22023, sin pintar nada a medias.
--   · LO QUE NO TIENE EQUIVALENTE SE DICE Y NO SE INVENTA. De la portada de
--     QuickBooks no hay aquí: «Mileage» (la app no lleva millas), el
--     «Lending» de Intuit (lo nuestro son los préstamos de c6) ni el umbral
--     («Threshold») de la gráfica de caja (nadie lo ha fijado). El «Sales
--     tax» es el use tax del DR-15 (c9): las ventas gravables todavía no
--     las separa nadie, y la tarjeta lo dice. «Customer Hub» y «Team» no
--     son de Contabilidad. «Payroll» es la página Nómina (c15, la fase 11:
--     el journal de Gusto): el tablero cuenta lo que ella deja en el libro
--     —la mano de obra y su burden en Resultados, en Gastos y en el costo
--     por obra; lo que queda por pagar, en lo que la proyección de caja no
--     incluye— pero todavía no tiene su tarjeta ni su acción (▶ para
--     decidir, abajo).
--
-- LAS TARJETAS (la clave de cada una en fn_tablero, su función y de dónde
-- sale cada cosa). El jsonb exacto de cada una está en el comentario de su
-- función (obj_description) y en el informe de la fase.
--   acciones          fn_tablero_acciones()
--       La fila de acciones rápidas, con lo que cambia de cada una: crear
--       una factura (c11: por dónde se factura hoy y cuántos borradores),
--       la Bandeja (c6: cuántos movimientos esperan y desde cuándo),
--       Conciliar (c6: la cuenta más atrasada), pedir un pago en línea (p1:
--       enlaces activos), Cerrar el mes (c9: qué mes toca y qué lo detiene)
--       y los estados financieros (c4).
--   cobros            fn_tablero_cobros(p_dias)
--       EL EMBUDO DE COBRO: por cobrar (las partidas abiertas de 1110, las
--       de la antigüedad de c4: cuántas facturas y cuántas vencidas) →
--       cobrado en los últimos N días (los cobros vigentes de c3, menos lo
--       devuelto) → depositado (de eso, lo que ya está en el banco: el
--       cobro casado con su movimiento de c6, o el de Stripe cuyo depósito
--       ya llegó al banco, p1).
--   bancos            fn_tablero_bancos()
--       Cada banco y tarjeta (v_banco_saldos de c6, la lista de la página
--       Bancos, sin las dos cuentas de Stripe): saldo según el banco y DE QUÉ
--       DÍA («hoy» o «al 31-oct-2026»), saldo en el libro A HOY (lo
--       posfechado, aparte), la diferencia EL MISMO DÍA (el banco contra el
--       libro a la fecha del saldo del banco, como la página Bancos), lo que
--       espera en la Bandeja contado como su página (v_banco_bandeja: lo
--       pendiente, lo que «llegó su ticket» y lo que el banco quitó), cuándo
--       se actualizó y por dónde (Plaid de c7, o un archivo), su última
--       conciliación y su alarma, en llano.
--   resultados        fn_tablero_resultados(p_desde, p_hasta, p_periodo)
--       EL RESULTADO de este mes, del mes pasado, del año o de un rango:
--       ingresos, costo, gastos, las utilidades, el margen, las dos barras
--       (lo que entra y lo que se gasta), la comparación con el período
--       anterior (si el período va a medias, contra los MISMOS días del
--       anterior) y lo que queda POR REVISAR en la Bandeja con fecha de ese
--       período. Del libro con el mapeo de c4: lo mismo que v_resultados,
--       MENOS el reverso automático del WIP (c12) que cae en un mes que
--       todavía no tiene su propio ajuste: va aparte (wip_aparte), con su
--       texto (fn_tablero_wip).
--   gastos            fn_tablero_gastos(p_dias, p_top)
--       LO GASTADO en los últimos N días por categoría (cada cuenta de
--       costo, gastos y otros gastos, con su etiqueta de c4; sin el ajuste
--       del WIP, que no es un gasto), contra los N días anteriores; las p_top
--       mayores y «las demás» ya sumadas; lo que espera en la Bandeja (puede
--       ser más) y lo que está dos veces en el libro (va de más).
--   caja              fn_tablero_caja(p_meses, p_proyeccion)
--       EL SALDO DE CAJA mes a mes (v_flujo_real_por_mes de c4: el efectivo
--       del balance, lo que entró y lo que salió de verdad; el mes en curso,
--       HASTA HOY, como la caja de hoy: lo que tiene fecha de después de hoy
--       en él va aparte, con su texto), el saldo con
--       que empezó el libro y el de hoy (en llano: de qué cuentas sale); y
--       —solo con lo que de verdad se sabe— UNA PROYECCIÓN marcada como tal,
--       con una línea a la vista («aviso»: no cuenta la nómina, la renta ni
--       lo que se repite; la caja real será menor): hoy + lo por cobrar según
--       su vencimiento (sin lo vencido de más de 60 días ni lo de un cheque
--       devuelto) − lo por pagar según el suyo − las cuotas de los préstamos
--       (c6) − el use tax por la regla del DR-15 ± lo posfechado del libro,
--       con sus supuestos y lo que NO incluye (con sus montos: lo de la
--       nómina, lo devengado…). Sin la apertura en el libro, ni alarma de
--       sobregiro ni proyección (no hay de dónde partir). Sin nada con
--       fecha, sin proyección.
--   facturas          fn_tablero_facturas(p_dias)
--       LAS FACTURAS no pagadas (vencidas y por vencer) y las pagadas en los
--       últimos N días (depositadas y sin depositar).
--   ventas            fn_tablero_ventas(p_anio)
--       LO VENDIDO (la sección «ingresos» de c4, sin el ajuste del WIP) de
--       cada mes del año que el libro tiene, y su total; el título dice desde
--       cuándo hay libro («Ventas de 2026 en el libro (del 1-oct-2026 a
--       hoy)»).
--   por_cobrar        fn_tablero_antiguedad('cobrar')
--   por_pagar         fn_tablero_antiguedad('pagar')
--       LA ANTIGÜEDAD POR VENCIMIENTO, como QuickBooks: corriente (todavía
--       no vence), 1–30, 31–60, 61–90 y más de 90 días de vencida. Cobrar:
--       las partidas de v_cxc_antiguedad (c4); vence lo que dice la factura
--       emitida por la app (c11) o, si no, su fecha más los términos de
--       Facturas → Ajustes (de fábrica «due on receipt»: el mismo día).
--       Pagar: las de v_cxp_antiguedad (c4), con el vencimiento que c4 les
--       da (los términos del proveedor o la balanza de apertura); lo que no
--       tiene vencimiento conocido va en su propio tramo («sin
--       vencimiento»: no se inventa). La retención y lo que hay a favor van
--       aparte (no vencen por términos).
--   conexiones        fn_tablero_conexiones()
--       Lo que la app tiene conectado: cada banco por Plaid (c7; uno que
--       lleva más de 48 horas sin traer nada, con problemas), Stripe (p1) y
--       la IA contable (c8): conectada, con problemas o apagada, cada una con
--       UNA línea en llano (lo de su capa tal cual, en «tecnico»).
--   cobros_en_linea   fn_tablero_cobros_en_linea()
--       STRIPE (p1): lo cobrado que espera su depósito, lo que Stripe
--       descontará del siguiente (un reembolso de algo ya depositado), lo
--       que está en camino, el último depósito que llegó y los que vienen.
--   use_tax           fn_tablero_use_tax()
--       EL USE TAX del DR-15 (v_dr15_mes de c9): lo del mes en curso y lo
--       del mes pasado, lo que se debe hoy en la 2300 y el DR-15 que toca
--       (el del mes pasado: lo que falta pagar y que vence el 20).
--   prestamos         fn_tablero_prestamos()
--       LOS PRÉSTAMOS (v_prestamos de c6): lo que se debe de cada uno, su
--       cuota y la PRÓXIMA (su fecha por el calendario del préstamo y su
--       reparto en capital e interés por la fórmula de c6).
--   obras             fn_tablero_obras(p_top)
--       LO QUE EL LIBRO SABE DE LAS OBRAS: el WIP del mes que toca (c12:
--       sobre y sub-facturado) y el costo por obra (c10: ingreso, costo y
--       margen de las obras con más ingreso).
--   «Qué atender» NO está aquí: sigue como hoy, en la pantalla, con los
--   controles de cada capa.
--
-- fn_tablero(p jsonb) — lo que llama la pantalla (una llamada). p, todo
-- opcional:
--   {"tarjetas": ["cobros", "bancos", …],   solo esas, en ese orden (por
--                                            omisión, todas)
--    "cobros": {"dias": 30}, "facturas": {"dias": 30},
--    "resultados": {"periodo": "mes" | "mes_pasado" | "anio"}
--                  o {"desde": "AAAA-MM-DD", "hasta": "AAAA-MM-DD"},
--    "gastos": {"dias": 30, "top": 5},
--    "caja": {"meses": 12, "proyeccion": 3},
--    "ventas": {"anio": 2026},
--    "obras": {"top": 5},
--    "tope_ms": 4000}
-- Devuelve {ok, version, hoy, generado_el, libro, capas, tarjetas (las
-- pedidas, en su orden), <una clave por tarjeta>, sigue (las que no
-- alcanzaron), ms}. Cada tarjeta trae además «ms» (lo que tardó). EL TOPE
-- POR RELOJ: por la API, pasados «tope_ms» (de fábrica 4000; 0 = sin tope;
-- desde el SQL Editor no hay), las tarjetas que faltan salen {ok: false,
-- sigue: true} y su nombre va en «sigue»: la pantalla las vuelve a pedir
-- ({"tarjetas": sigue}). Así una llamada nunca se acerca a los 8 s de la
-- API. Lo que comparten varias tarjetas (las partidas por cobrar y por
-- pagar, lo cobrado, las cuotas, el estado de Stripe, los saldos de los
-- bancos) se lee UNA vez por llamada.
--
-- LA SEGURIDAD (la regla de c2, B.20, y lo que c4, c6, c9, c10, c12 y c14
-- sellan):
--   · NINGUNA función de aquí es SECURITY DEFINER. Todas son SECURITY
--     INVOKER, sin EXECUTE para public, anon ni service_role, con EXECUTE
--     para authenticated; las que leen algo llaman a fn_tablero_exigir_dueno
--     (es_dueno()): el equipo recibe 42501, anon y service_role no ejecutan
--     nada. Leen con la policy de cada tabla (solo el dueño). «permisos» de
--     c2 sigue en verde.
--   · fn_tablero_precondiciones y fn_tablero_pegado: sin API (solo el SQL
--     Editor).
--   · No hay vistas: nada de aquí cuelga de una vista de otra capa (que se
--     rehace al volver a pegar su archivo y arrastraría las que dependen de
--     ella). Lo de las otras capas se lee dentro de cada función, y si su
--     vista o su tabla no está, la tarjeta lo dice.
--   · Nada lleva un prefijo de otra capa ni de la otra sesión que escribe
--     esta base: aquí todo es fn_tablero_*. es_dueno() no se toca.
--   · EL CÓDIGO DEL TELÉFONO (aal2): al dueño que entra solo con la
--     contraseña lo frena la guarda de s1 (pgrst.db_pre_request,
--     fn_mfa_exigir: 403 «MFA») antes de llegar a cualquier función, como en
--     todas las capas. c16 no la repite a propósito: si s1 se apaga «de
--     urgencia» (su cabecera dice cómo), se apaga igual para todo, y la
--     portada no queda como la única página cerrada. (La revisión del
--     13-nov lo confirmó: anon y service_role no ejecutan nada; el equipo,
--     el equipo inactivo, una sesión sin perfil y el dueño inactivo reciben
--     42501 o nada que tenga un monto.)
--
-- LOS ERRORES CON NOMBRE (ninguno nuevo):
--   MX000  falta algo que este archivo da por hecho: no se aplica nada
--          (fn_tablero_precondiciones dice qué)
--   22023  entrada mal formada: una clave o una tarjeta que no existe, un
--          período o un lado que no existe, días o meses fuera de rango
--   22007  una fecha mal escrita
--   42501  permiso: solo el dueño; anon y service_role, nada
--   55P03  (de Postgres, «lock timeout») la app estaba leyendo mientras se
--          pegaba: no se aplicó nada, se vuelve a pegar
--   Dentro de fn_tablero ninguna tarjeta levanta un error: la que falla lo
--   trae en su clave ({ok: false, motivo, codigo, error}); solo lo mal
--   pedido (22023, 22007) para la llamada entera.
--
-- LO QUE ESTE ARCHIVO NO TOCA: c1…c14, s1, p1, es_dueno(), docs/sql, el
-- libro, las tablas de la app, ninguna tabla ni vista de otra capa: no
-- escribe en ninguna. LEE (con la policy de cada una):
--   c2   asientos, asiento_lineas, periodos y perfiles
--   c3   puente_cuentas, cobros, cobros_devoluciones y aplicaciones_cobro
--   c4   v_estados_mapeo, estados_lineas, v_cxc_antiguedad,
--        v_cxp_antiguedad y v_flujo_real_por_mes
-- y, si están (si no, su tarjeta lo dice):
--   c6   v_banco_saldos, v_banco_bandeja, movimientos_banco, banco_casados,
--        banco_casado_lineas y v_prestamos
--   c7   plaid_conexiones
--   p1   stripe_config, stripe_pagos, stripe_pago_libro, stripe_payouts,
--        stripe_payout_lineas, stripe_enlaces, v_stripe_pagos,
--        v_stripe_payouts y v_stripe_control
--   c8   contador_config y v_contador_control
--   c9   v_cierre_estado y v_dr15_mes
--   c10  v_margen_obra
--   c11  emision_config, emision_documentos y v_emision_estado
--   c12  fn_wip_resumen, fn_wip_asientos y wip_ajustes (solo lee)
--   c13  solo mira si está (para enlazar la cédula de corte)
--
-- CÓMO SE INSTALA (Edgar, en este orden):
--   1. SQL Editor → pegar ESTE archivo entero → Run. Al final sale una
--      tabla de 6 filas: la capa, las capas que ve, el libro, una pasada
--      del tablero (cuántas tarjetas contestan y en cuánto), qué falta y el
--      paso siguiente. Si algo de lo que da por hecho falta, para con
--      MX000 y no queda nada.
--   2. SQL Editor → pegar docs/conta/c16-pruebas.sql → sus filas, todas en
--      true (las «omitida» dicen por qué; no es un fallo).
--   3. Publicar la app con la portada nueva: Contabilidad → Resumen.
--
-- LO QUE LLAMA LA PANTALLA (RPC, como el dueño; todas solo leen y se
-- pueden pedir por GET o por POST):
--   fn_tablero(p jsonb default '{}')                   todas las tarjetas
--   fn_tablero_acciones()
--   fn_tablero_cobros(p_dias int default 30)
--   fn_tablero_bancos()
--   fn_tablero_resultados(p_desde date default null, p_hasta date default null, p_periodo text default null)
--   fn_tablero_gastos(p_dias int default 30, p_top int default 5)
--   fn_tablero_caja(p_meses int default 12, p_proyeccion int default 3)
--   fn_tablero_facturas(p_dias int default 30)
--   fn_tablero_ventas(p_anio int default null)
--   fn_tablero_antiguedad(p_lado text)                 'cobrar' | 'pagar'
--   fn_tablero_conexiones()
--   fn_tablero_cobros_en_linea()
--   fn_tablero_use_tax()
--   fn_tablero_prestamos()
--   fn_tablero_obras(p_top int default 5)
--   fn_tablero_libro()                                  desde cuándo hay libro
--   fn_tablero_version()                                la marca (AAAAMMDDNN)
-- Montos en dólares con dos decimales (numeric(14,2)); porcentajes con un
-- decimal (nulos cuando no hay contra qué comparar); fechas AAAA-MM-DD;
-- meses «AAAA-MM» con su etiqueta en texto («oct 2026»).
--
-- ▶ PARA DECIDIR (no frena nada; se dice):
--   · Los términos de las facturas de QuickBooks (las de antes de facturar
--     por la app) no los sabe la base: se toman los de Facturas → Ajustes
--     (de fábrica «due on receipt»). Si QuickBooks las daba a 15 o 30 días,
--     se cambia ahí y la antigüedad se mueve sola.
--   · EL WIP (con el CPA): las VENTAS son lo vendido, sin el ajuste del WIP
--     de ningún mes (cada mes trae aparte su «wip» y lo que daría con él);
--     los RESULTADOS siguen el libro (como Estados → Resultados) salvo el
--     reverso automático del día 1 de un mes que todavía no tiene su propio
--     ajuste ni está cerrado: ese va aparte, con su texto, hasta que el mes
--     tenga su ajuste (entonces cuenta, y el mes queda como en Estados). Si
--     el CPA prefiere otra regla (todo aparte, o todo dentro), es aquí.
--   · La proyección de caja pone lo YA VENCIDO (por cobrar hasta hace 60
--     días, por pagar y cuotas sin registrar) en el mes de hoy, como si se
--     cobrara y se pagara ya; lo vencido de MÁS de 60 días y lo de una
--     factura con un cheque devuelto no se cuenta (se dice cuánto es). El
--     use tax, el 20 del mes que sigue (el DR-15). Lo que se debe de la
--     nómina (2210–2250), lo devengado (2050) y la línea de crédito no
--     tienen fecha de pago en el libro: van en «no_incluye» con su monto,
--     con TODO lo que el libro tiene en esas cuentas (también lo fechado
--     después de hoy: el journal de una nómina de c15 lleva la fecha de su
--     día de pago, y Gusto cobra del banco unos días antes; contado solo
--     hasta hoy, esos días la deuda salía en negativo). ▶ La nómina (c15) no
--     dice cuándo cobra Gusto cada cosa: si se quisiera restar de la
--     proyección una nómina ya posteada con día de pago después de hoy, o
--     darle su tarjeta («Payroll» en QuickBooks: la última nómina, lo que
--     queda por pagar, los cargos de Gusto que esperan en la Bandeja), es
--     aquí y en la pantalla. Si se quisiera restar también un
--     promedio de lo que sale cada mes (la nómina, la renta), sería un
--     estimado y no el libro: hoy solo se dice, en la línea a la vista,
--     cuánto salió en los meses terminados.
--   · Un banco por Plaid que lleva más de 48 horas sin traer nada sale «con
--     problemas» (la rutina de c7 es diaria).
--
-- LO QUE CAMBIÓ CON LAS DOS REVISIONES (marca 2026111302), cada arreglo con
-- su prueba en c16-pruebas.sql:
--   · bancos: el saldo del banco dice de qué día es; la diferencia, la del
--     mismo día (saldo_libro_al); el libro, a hoy (lo posfechado aparte);
--     lo que espera, como la Bandeja (36, 37, 38, 9).
--   · caja: sin la apertura en el libro, ni alarma de sobregiro ni
--     proyección, y el texto dice por qué (41; y fn_tablero_libro ya no da
--     por viva una apertura reversada: su reverso también es de tipo
--     apertura); la proyección, con su línea a la vista, sin lo vencido de
--     más de 60 días ni lo de un cheque devuelto, con el use tax y lo
--     posfechado, y lo que no incluye con sus montos (15, 37).
--   · resultados y ventas: el reverso del WIP del día 1 (42, 10, 12, 17);
--     sus títulos dicen desde cuándo hay libro (12, 17).
--   · Stripe: un cobro ya depositado y reembolsado después sigue
--     depositado; lo devuelto es lo de verdad; sin la ventana de 120 días de
--     v_stripe_pagos (39, 40); los cobros en línea separan lo que Stripe
--     descontará (21).
--   · gastos: lo que «llegó su ticket» (va de más) y sin el WIP (38, 13).
--   · use tax: el DR-15 que toca (lo que falta y que vence el 20), y el
--     enlace a la pestaña DR-15 (22, 43).
--   · los enlaces generales a la Bandeja llevan la cuenta en nulo (43).
--   · conexiones y bancos en llano: sin códigos, secretos, fechas
--     AAAA-MM-DD, «(s)», «…», «ráfaga» ni «partidas»; lo que está en rojo
--     en Stripe y en la IA, una frase por cada cosa (no el nombre del
--     control entre comillas); lo de cada capa, en «tecnico» (35, 20).
-- Y CON LA REVISIÓN FINAL (marca 2026111303), cada arreglo con su prueba:
--   · caja: el mes en curso es HASTA HOY, como la caja de hoy: lo que tiene
--     fecha de después de hoy en él (un cheque posfechado) va aparte, en
--     despues_de_hoy, con su texto; antes, «nov 2026 (hasta hoy)» terminaba
--     en lo de c4 para el mes entero, 640.00 menos que la caja de hoy en la
--     semilla (14, 46). Los meses ya terminados, los de Estados como siempre.
--   · bancos: lo que dice el banco, SUMADO, solo si todas las cuentas lo
--     dicen del mismo día (banco_al); de días distintos, sin total
--     (banco_texto): la suma del saldo de hoy de una tarjeta y del 31-oct de
--     otra era una cifra que el banco nunca dijo (47).
--   · lo cobrado y lo devuelto: un cobro cuenta en los días en que se cobró
--     el dinero —el que p1 vuelve a registrar tras un reembolso en parte o
--     una disputa, en los del primer cobro de su pago, no en los del
--     cambio—; lo devuelto «ya restado» es solo lo de los cobros de esos
--     días; lo devuelto en esos días de un cobro de antes (un cheque de hace
--     40 días que rebota hoy) va aparte, en devuelto_antes, y no se resta de
--     nada (48, 49).
--   · caja, lo que la proyección NO incluye: lo que se debe de la nómina (y
--     las demás deudas sin fecha de pago) va con todo lo que el libro tiene
--     en sus cuentas, también lo fechado después de hoy (a_hoy y despues lo
--     separan): con la nómina de c15, entre el cargo de Gusto y el día de
--     pago salía una deuda en negativo, y una nómina ya posteada con día de
--     pago después de hoy no se decía (50).
-- Y EL 14-NOV (Fase 11c, marca 2026111401): EL TABLERO APRENDE LA NÓMINA (c15).
-- (PROTOTIPO escrito por el agente de la pantalla porque el de la base no
-- llegó: lo revisa e integra el agente de los arreglos, con sus pruebas.)
--   · fn_tablero_capas gana la clave c15; fn_tablero, la tarjeta «nomina»
--     (fn_tablero_nomina, con {"nomina": {"meses": 6}}): el costo de la
--     nómina de Gusto por mes (del libro: sus journals vivos, por día de
--     pago, hasta hoy), la última y la próxima (ya posteada) con sus totales
--     de la EMPRESA solo con el código del teléfono (de v_nomina_corridas de
--     c15, que lo pide: una nómina de una persona es lo que cobró esa
--     persona), lo que se debe de ella (2210 a 2250, del libro), los cargos
--     de Gusto que esperan en la Bandeja (del banco), las que esperan por
--     postear (con el código), la bolsa del burden y «atender» (lo que pide
--     algo a Edgar, con los textos cortos de c15: sin nombres ni cifras de
--     nadie). Sin el código, «con el código del teléfono», nunca un cero.
--     Sin c15: {ok: false, falta: «c15»}.
--   · La acción rápida «Nómina» (antes de «Cerrar el mes»), con su contador.
--   · La proyección de la caja resta lo que se debe de la nómina en el día
--     de pago de su nómina ya posteada (fn_tablero_nomina_pagos, del libro:
--     lo que Gusto ya cobró y está casado no se resta otra vez), y «no
--     incluye» deja de contarla. Sin c15, como antes.
--   · Ninguna función SECURITY DEFINER, ninguna tabla: sigue solo leyendo.
-- =====================================================================
-- (Lo primero, como en c4, c6, c10, c12 y c14: el pegado espera un candado
-- como mucho medio segundo. Con la app leyendo, para con 55P03 («lock
-- timeout»), no se aplica nada y se vuelve a pegar. Dura lo que dura el
-- pegado.)
set local lock_timeout = '500ms';


-- ---------------------------------------------------------------------
-- 0. Lo que este archivo da por hecho (MX000 sin tocar nada), la marca y
--    la guarda de todo lo que llama la pantalla.
-- ---------------------------------------------------------------------
-- LAS FUNCIONES DE ESTA CAPA, por su firma exacta (las pruebas y el pegado
-- las cuentan por aquí, no por el prefijo: otra sesión escribe esta base).
create or replace function public.fn_tablero_funciones() returns text[]
language sql immutable
set search_path = public, pg_temp
as $$
  select array[
    'fn_tablero_funciones()', 'fn_tablero_precondiciones()', 'fn_tablero_version()', 'fn_tablero_exigir_dueno()',
    'fn_tablero_hoy()', 'fn_tablero_dia(date)', 'fn_tablero_mes(date)', 'fn_tablero_mes_corto(date)', 'fn_tablero_mes_largo(date)',
    'fn_tablero_rango(date,date)', 'fn_tablero_usd(numeric)', 'fn_tablero_plural(bigint,text,text)', 'fn_tablero_llano(text)',
    'fn_tablero_hace(timestamp with time zone)', 'fn_tablero_corto(text,integer)', 'fn_tablero_pct(numeric,numeric,boolean)',
    'fn_tablero_no(text,text,text,text)', 'fn_tablero_capas()', 'fn_tablero_libro()', 'fn_tablero_saldo(text[],date)',
    'fn_tablero_mapa()', 'fn_tablero_wip()', 'fn_tablero_pyg(date,date)', 'fn_tablero_cxc()', 'fn_tablero_cxp()',
    'fn_tablero_cobros_lista(date,date)', 'fn_tablero_devuelto(date,date)', 'fn_tablero_cobrado(jsonb,date,date)',
    'fn_tablero_por_revisar(date,date)',
    'fn_tablero_cuotas(date)', 'fn_tablero_cuotas_fecha(date,integer,integer,integer)', 'fn_tablero_stripe()', 'fn_tablero_saldos()',
    'fn_tablero_acciones()', 'fn_tablero_acciones_de(jsonb,jsonb,jsonb)',
    'fn_tablero_cobros(integer)', 'fn_tablero_cobros_de(jsonb,jsonb)',
    'fn_tablero_bancos()', 'fn_tablero_bancos_de(jsonb)',
    'fn_tablero_resultados(date,date,text)', 'fn_tablero_gastos(integer,integer)',
    'fn_tablero_caja(integer,integer)', 'fn_tablero_caja_de(integer,integer,jsonb,jsonb,jsonb)',
    'fn_tablero_facturas(integer)', 'fn_tablero_facturas_de(jsonb,jsonb)',
    'fn_tablero_ventas(integer)',
    'fn_tablero_antiguedad(text)', 'fn_tablero_antiguedad_de(text,jsonb)',
    'fn_tablero_conexiones()', 'fn_tablero_conexiones_de(jsonb)',
    'fn_tablero_cobros_en_linea()', 'fn_tablero_cobros_en_linea_de(jsonb)',
    'fn_tablero_use_tax()', 'fn_tablero_prestamos()', 'fn_tablero_prestamos_de(jsonb)',
    'fn_tablero_obras(integer)', 'fn_tablero_nomina_pagos()', 'fn_tablero_nomina_estado()', 'fn_tablero_nomina_una(uuid,boolean)',
    'fn_tablero_nomina_de(jsonb,integer)', 'fn_tablero_nomina(integer)', 'fn_tablero_entero(jsonb,text,integer)', 'fn_tablero(jsonb)', 'fn_tablero_pegado()']
$$;
revoke execute on function public.fn_tablero_funciones() from public, anon, service_role;
grant  execute on function public.fn_tablero_funciones() to authenticated;
comment on function public.fn_tablero_funciones() is 'c16: las funciones de esta capa por su firma exacta (el pegado y las pruebas las cuentan por aquí, no por el prefijo).';

-- Lo que falta para pegar c16, en llano (nulo = nada). La usan la guarda de
-- abajo, el pegado y las pruebas.
create or replace function public.fn_tablero_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
  v_v     bigint;
begin
  foreach v_x in array array['es_dueno()', 'fn_desde_editor()', 'fn_fecha_miami(timestamp with time zone)', 'fn_libro_version()',
                             'fn_estados_version()'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'periodos', 'asientos', 'asiento_lineas', 'perfiles', 'proyectos', 'facturas', 'cobros',
                             'cobros_devoluciones', 'aplicaciones_cobro', 'puente_cuentas', 'estados_lineas', 'v_estados_mapeo',
                             'v_cxc_antiguedad', 'v_cxp_antiguedad', 'v_flujo_real_por_mes'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if cardinality(v_falta) > 0 then
    return format('c16 se pega después de c1, c2, c3 y c4 (y de c6, c7, s1, p1, c8, c9, c10, c11, c12, c13 y c14 si se usan), con las '
                  'tablas de la app: falta %s.', array_to_string(v_falta, ', '));
  end if;
  -- (las marcas de c2 y c4 que van con esta capa: las de producción)
  execute 'select public.fn_libro_version()' into v_v;
  if coalesce(v_v, 0) < 2026100201 then
    return format('el c2-libro.sql pegado es anterior (marca %s; esta capa pide 2026100201 o posterior): vuelve a pegar c2-libro.sql.', v_v);
  end if;
  execute 'select public.fn_estados_version()' into v_v;
  if coalesce(v_v, 0) < 2026100901 then
    return format('el c4-estados.sql pegado es anterior (marca %s; esta capa pide 2026100901 o posterior): vuelve a pegar c4-estados.sql.', v_v);
  end if;
  -- (las columnas que esta capa lee por su nombre)
  select string_agg(x.t || '.' || x.c, ', ' order by x.t, x.c) into v_x
    from (values ('asientos', 'id'), ('asientos', 'fecha_contable'), ('asientos', 'anio'), ('asientos', 'tipo'),
                 ('asientos', 'afecta_periodo'), ('asientos', 'reversa_a'), ('asientos', 'camino'),
                 ('asiento_lineas', 'asiento_id'), ('asiento_lineas', 'cuenta'), ('asiento_lineas', 'monto'),
                 ('periodos', 'periodo'), ('periodos', 'tipo'), ('periodos', 'anio'), ('periodos', 'desde'), ('periodos', 'hasta'),
                 ('puente_cuentas', 'rol'), ('puente_cuentas', 'cuenta'), ('perfiles', 'rol'), ('perfiles', 'activo'),
                 ('cobros', 'id'), ('cobros', 'fecha'), ('cobros', 'monto'), ('cobros', 'cuenta'), ('cobros', 'medio'),
                 ('cobros', 'estado'), ('cobros', 'movimiento_id'), ('cobros', 'contabilizado_en'), ('cobros', 'proyecto_id'),
                 ('cobros_devoluciones', 'cobro_id'), ('cobros_devoluciones', 'fecha'), ('cobros_devoluciones', 'monto'),
                 ('aplicaciones_cobro', 'cobro_id'), ('aplicaciones_cobro', 'factura_id'), ('aplicaciones_cobro', 'monto'),
                 ('aplicaciones_cobro', 'es_retencion'),
                 ('estados_lineas', 'estado'), ('estados_lineas', 'seccion'), ('estados_lineas', 'linea'),
                 ('estados_lineas', 'etiqueta_es'),
                 ('v_estados_mapeo', 'cuenta'), ('v_estados_mapeo', 'cuenta_nombre'), ('v_estados_mapeo', 'estado'),
                 ('v_estados_mapeo', 'seccion'), ('v_estados_mapeo', 'linea'), ('v_estados_mapeo', 'etiqueta_es'), ('v_estados_mapeo', 'orden'),
                 ('v_estados_mapeo', 'efectivo'), ('v_estados_mapeo', 'caja'),
                 ('v_cxc_antiguedad', 'periodo'), ('v_cxc_antiguedad', 'nivel'), ('v_cxc_antiguedad', 'tipo'),
                 ('v_cxc_antiguedad', 'partida_tabla'), ('v_cxc_antiguedad', 'partida_id'), ('v_cxc_antiguedad', 'factura_id'),
                 ('v_cxc_antiguedad', 'factura_num'), ('v_cxc_antiguedad', 'proyecto_id'), ('v_cxc_antiguedad', 'obra'),
                 ('v_cxc_antiguedad', 'cliente'), ('v_cxc_antiguedad', 'fecha'), ('v_cxc_antiguedad', 'por_cobrar'),
                 ('v_cxc_antiguedad', 'retencion'),
                 ('v_cxp_antiguedad', 'periodo'), ('v_cxp_antiguedad', 'nivel'), ('v_cxp_antiguedad', 'tipo'),
                 ('v_cxp_antiguedad', 'partida_tabla'), ('v_cxp_antiguedad', 'partida_id'), ('v_cxp_antiguedad', 'proveedor'),
                 ('v_cxp_antiguedad', 'referencia'), ('v_cxp_antiguedad', 'fecha'), ('v_cxp_antiguedad', 'fecha_origen'),
                 ('v_cxp_antiguedad', 'vence'), ('v_cxp_antiguedad', 'dias_vencida'), ('v_cxp_antiguedad', 'por_pagar'),
                 ('v_cxp_antiguedad', 'retencion'),
                 ('v_flujo_real_por_mes', 'periodo'), ('v_flujo_real_por_mes', 'desde'), ('v_flujo_real_por_mes', 'hasta'),
                 ('v_flujo_real_por_mes', 'efectivo_inicial'), ('v_flujo_real_por_mes', 'entradas'),
                 ('v_flujo_real_por_mes', 'salidas'), ('v_flujo_real_por_mes', 'neto'), ('v_flujo_real_por_mes', 'sobregiro'),
                 ('v_flujo_real_por_mes', 'efectivo_final'), ('v_flujo_real_por_mes', 'asientos')) as x(t, c)
   where not exists (select 1 from information_schema.columns k
                      where k.table_schema = 'public' and k.table_name = x.t and k.column_name = x.c);
  if v_x is not null then
    return format('faltan columnas que esta capa lee: %s. ¿Es la base de la app, con c3 y c4 pegados?', v_x);
  end if;
  -- (las dos cuentas por cobrar de los puentes, c3: sin ellas no hay partidas que contar)
  if (select count(*) from puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc')) < 2 then
    return 'faltan las cuentas por cobrar de los puentes (cxc y retencion_cxc en puente_cuentas, de c3): vuelve a pegar c3-puentes.sql.';
  end if;
  -- (una función con nombre de c16 que no sea de c16: «create or replace» la pisaría sin avisar)
  select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_x
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_tablero%'
     and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c16: %';
  if v_x is not null then
    return format('ya hay en esta base, con nombre de c16 y sin ser de c16: %s. No lo piso; avisa antes de seguir.', v_x);
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: el tablero lo ve el dueño.';
  end if;
  return null;
end $$;
revoke execute on function public.fn_tablero_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_tablero_precondiciones() is 'c16: lo que falta para pegar c16-tablero.sql (nulo = nada): c1, c2 (marca 2026100201 o posterior), c3 y c4 (2026100901 o posterior), las tablas, vistas y columnas que lee, las cuentas por cobrar de los puentes, el SQL Editor, un dueño activo y nada ajeno con nombre de c16. Sin API.';

do $$
declare
  v text;
begin
  v := public.fn_tablero_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c16-tablero NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1, c2, c3, c4 (c6, c7, s1, p1, c8, c9, c10, c11, c12, c13, c14) y después este archivo (pruebas/conta/README.md, §0).';
  end if;
end $$;

-- VOLVER A PEGAR: las funciones de c16 que ya estén (su comentario empieza
-- por «c16: ») se quitan y se crean otra vez abajo, todas, con sus
-- permisos. Así una versión nueva entra limpia aunque cambie lo que
-- devuelve una función o su firma («create or replace» no cambia lo que
-- devuelve, y con otra firma haría una segunda función con el mismo
-- nombre: la API no sabría cuál llamar). Nada de otra capa depende de
-- ellas (son lo último de la cadena) y no guardan nada: quitarlas no
-- pierde nada. Solo las de c16; estas dos (la lista y las precondiciones),
-- que ya se usaron arriba, se quedan.
do $$
declare
  r record;
begin
  for r in select p.oid::regprocedure as f
             from pg_proc p
            where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_tablero%'
              and coalesce(obj_description(p.oid, 'pg_proc'), '') like 'c16: %'
              and p.proname not in ('fn_tablero_funciones', 'fn_tablero_precondiciones') loop
    execute format('drop function %s', r.f);
  end loop;
end $$;

-- LA MARCA de esta versión (AAAAMMDDNN), como las de c2, c3, c4 y c6.
create or replace function public.fn_tablero_version() returns bigint
language sql immutable
set search_path = public, pg_temp
as $$ select 2026111401::bigint $$;
revoke execute on function public.fn_tablero_version() from public, anon, service_role;
grant  execute on function public.fn_tablero_version() to authenticated;
comment on function public.fn_tablero_version() is 'c16: la marca de esta versión del tablero (AAAAMMDDNN). La pantalla la mira para saber si la base ya trae la portada nueva.';

-- ¿Quién llama por la API? Solo el dueño. Desde el SQL Editor o pg_cron
-- (current_user no es un rol de la API) pasa. Solo es_dueno(), como c4, c6,
-- c9, c10 y c12.
create or replace function public.fn_tablero_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if current_user in ('authenticated', 'anon', 'service_role') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501',
      message = 'El tablero de Contabilidad (los saldos, lo que se cobra, lo que se debe y el resultado) lo ve solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_tablero_exigir_dueno() from public, anon, service_role;
grant  execute on function public.fn_tablero_exigir_dueno() to authenticated;
comment on function public.fn_tablero_exigir_dueno() is 'c16: la guarda de todo lo que lee: por la API solo el dueño (es_dueno; el equipo recibe 42501); el SQL Editor y pg_cron pasan.';


-- ---------------------------------------------------------------------
-- 1. Lo común: hoy, las fechas y el dinero en llano, los porcentajes,
--    «esta tarjeta no», las capas que hay, el libro y el mapeo de c4.
-- ---------------------------------------------------------------------
-- «Hoy», en Miami (el reloj de c2: las pruebas lo fingen ahí).
create or replace function public.fn_tablero_hoy() returns date
language sql stable
set search_path = public, pg_temp
as $$ select public.fn_fecha_miami(now()) $$;
revoke execute on function public.fn_tablero_hoy() from public, anon, service_role;
grant  execute on function public.fn_tablero_hoy() to authenticated;
comment on function public.fn_tablero_hoy() is 'c16: hoy, en Miami (fn_fecha_miami de c2).';

-- Un día en llano: 30-sep-2026 (como la cédula y los subs: ni 30/09/2026,
-- que en un teléfono de aquí se lee al revés, ni 2026-09-30).
create or replace function public.fn_tablero_dia(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select extract(day from p)::int || '-'
         || (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int]
         || '-' || extract(year from p)::int
$$;
revoke execute on function public.fn_tablero_dia(date) from public, anon, service_role;
grant  execute on function public.fn_tablero_dia(date) to authenticated;
comment on function public.fn_tablero_dia(date) is 'c16: un día en llano (30-sep-2026).';

-- Un mes para el eje o la etiqueta de una gráfica: «oct 2026».
create or replace function public.fn_tablero_mes(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int]
         || ' ' || extract(year from p)::int
$$;
revoke execute on function public.fn_tablero_mes(date) from public, anon, service_role;
grant  execute on function public.fn_tablero_mes(date) to authenticated;
comment on function public.fn_tablero_mes(date) is 'c16: un mes para la etiqueta de una gráfica (oct 2026).';

-- El mes en tres letras, para un eje estrecho: «oct».
create or replace function public.fn_tablero_mes_corto(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$ select (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int] $$;
revoke execute on function public.fn_tablero_mes_corto(date) from public, anon, service_role;
grant  execute on function public.fn_tablero_mes_corto(date) to authenticated;
comment on function public.fn_tablero_mes_corto(date) is 'c16: el mes en tres letras, para un eje estrecho (oct).';

-- Un mes entero, para un título: «octubre de 2026».
create or replace function public.fn_tablero_mes_largo(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select (array['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre',
                'diciembre'])[extract(month from p)::int] || ' de ' || extract(year from p)::int
$$;
revoke execute on function public.fn_tablero_mes_largo(date) from public, anon, service_role;
grant  execute on function public.fn_tablero_mes_largo(date) to authenticated;
comment on function public.fn_tablero_mes_largo(date) is 'c16: un mes entero, para un título (octubre de 2026).';

-- Un rango de días en llano: «1 a 12 de noviembre de 2026» si cae en un
-- mes; si no, «14-oct-2026 a 12-nov-2026».
create or replace function public.fn_tablero_rango(p_desde date, p_hasta date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p_desde = p_hasta then public.fn_tablero_dia(p_desde)
              when date_trunc('month', p_desde) = date_trunc('month', p_hasta)
                then extract(day from p_desde)::int || ' a ' || extract(day from p_hasta)::int || ' de '
                     || public.fn_tablero_mes_largo(p_desde)
              else public.fn_tablero_dia(p_desde) || ' a ' || public.fn_tablero_dia(p_hasta) end
$$;
revoke execute on function public.fn_tablero_rango(date, date) from public, anon, service_role;
grant  execute on function public.fn_tablero_rango(date, date) to authenticated;
comment on function public.fn_tablero_rango(date, date) is 'c16: un rango de días en llano (1 a 12 de noviembre de 2026; 14-oct-2026 a 12-nov-2026).';

-- Dinero en texto, para los mensajes: $1,234.56 (−$1,234.56).
create or replace function public.fn_tablero_usd(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$ select case when p < 0 then '−' else '' end || '$' || btrim(to_char(abs(round(p, 2)), 'FM999,999,999,990.00')) $$;
revoke execute on function public.fn_tablero_usd(numeric) from public, anon, service_role;
grant  execute on function public.fn_tablero_usd(numeric) to authenticated;
comment on function public.fn_tablero_usd(numeric) is 'c16: dinero en texto para los mensajes ($1,234.56; −$1,234.56).';

-- Un número con su palabra, en singular o en plural: «1 cargo», «6 cargos»
-- (nunca «6 cargo(s)»).
create or replace function public.fn_tablero_plural(p_n bigint, p_uno text, p_varios text) returns text
language sql immutable
set search_path = public, pg_temp
as $$ select case when p_n is null then null else p_n::text || ' ' || case when p_n = 1 then p_uno else p_varios end end $$;
revoke execute on function public.fn_tablero_plural(bigint, text, text) from public, anon, service_role;
grant  execute on function public.fn_tablero_plural(bigint, text, text) to authenticated;
comment on function public.fn_tablero_plural(bigint, text, text) is 'c16: un número con su palabra en singular o en plural (1 cargo, 6 cargos; nunca «cargo(s)»).';

-- Un texto de otra capa, en llano para la portada: sus plurales a medias
-- («2 obra(s)», «1 cargo(s)») con su número («2 obras», «1 cargo»). Lo demás,
-- tal cual.
create or replace function public.fn_tablero_llano(p text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select regexp_replace(regexp_replace(regexp_replace(regexp_replace(p,
           '(^|[^0-9])1 ([[:alpha:]áéíóúüñ]+)\(s\)', '\11 \2', 'g'),
           '([[:alpha:]áéíóúüñ]+)\(s\)', '\1s', 'g'),
           '(^|[^0-9])1 ([[:alpha:]áéíóúüñ]+)\(es\)', '\11 \2', 'g'),
           '([[:alpha:]áéíóúüñ]+)\(es\)', '\1es', 'g')
$$;
revoke execute on function public.fn_tablero_llano(text) from public, anon, service_role;
grant  execute on function public.fn_tablero_llano(text) to authenticated;
comment on function public.fn_tablero_llano(text) is 'c16: un texto de otra capa en llano para la portada: «2 obra(s)» → «2 obras», «1 obra(s)» → «1 obra» (y lo mismo con «(es)»). Lo demás, tal cual.';

-- Cuánto hace, en llano: «hace menos de 1 hora», «hace 5 horas» (hasta dos
-- días), «hace 3 días» (de ahí en adelante). Nulo si no hay hora.
create or replace function public.fn_tablero_hace(p timestamptz) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select case when p is null then null
              when now() - p < interval '1 hour' then 'hace menos de 1 hora'
              when now() - p < interval '48 hours'
                then 'hace ' || public.fn_tablero_plural(floor(extract(epoch from now() - p) / 3600)::bigint, 'hora', 'horas')
              else 'hace ' || public.fn_tablero_plural(floor(extract(epoch from now() - p) / 86400)::bigint, 'día', 'días') end
$$;
revoke execute on function public.fn_tablero_hace(timestamptz) from public, anon, service_role;
grant  execute on function public.fn_tablero_hace(timestamptz) to authenticated;
comment on function public.fn_tablero_hace(timestamptz) is 'c16: cuánto hace, en llano (hace menos de 1 hora; hace 5 horas, hasta dos días; hace 3 días después). Nulo sin hora.';

-- Un texto largo, corto para una línea: hasta p_max letras sin partir una
-- palabra, con «…» si se cortó.
create or replace function public.fn_tablero_corto(p text, p_max int) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null or length(p) <= p_max then p
              else coalesce(nullif(substring(left(p, p_max) from '^(.*\S)\s'), ''), left(p, p_max)) || '…' end
$$;
revoke execute on function public.fn_tablero_corto(text, int) from public, anon, service_role;
grant  execute on function public.fn_tablero_corto(text, int) to authenticated;
comment on function public.fn_tablero_corto(text, int) is 'c16: un texto largo, corto para una línea (hasta p_max letras sin partir una palabra, con «…»).';

-- Un porcentaje con un decimal: cuánto es p_parte de p_base (nulo si la
-- base es cero o falta). Con p_abs, sobre el valor absoluto de la base: la
-- variación contra un período anterior, con el signo de la diferencia (la
-- convención de v_resultados de c4: una pérdida que pasa a ganancia sube).
create or replace function public.fn_tablero_pct(p_parte numeric, p_base numeric, p_abs boolean default false) returns numeric
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p_parte is null or p_base is null or p_base = 0 then null
              else round(100 * p_parte / case when p_abs then abs(p_base) else p_base end, 1) end
$$;
revoke execute on function public.fn_tablero_pct(numeric, numeric, boolean) from public, anon, service_role;
grant  execute on function public.fn_tablero_pct(numeric, numeric, boolean) to authenticated;
comment on function public.fn_tablero_pct(numeric, numeric, boolean) is 'c16: un porcentaje con un decimal (nulo si no hay base); con p_abs, la variación contra un período anterior sobre |base|, con el signo de la diferencia (como v_resultados de c4).';

-- «Esta tarjeta no»: por qué, qué capa falta si es eso, y el código del
-- error si fue un error.
create or replace function public.fn_tablero_no(p_tarjeta text, p_motivo text, p_falta text default null, p_codigo text default null)
returns jsonb
language sql immutable
set search_path = public, pg_temp
as $$
  select jsonb_strip_nulls(jsonb_build_object('ok', false, 'tarjeta', p_tarjeta, 'motivo', p_motivo, 'falta', p_falta, 'codigo', p_codigo))
$$;
revoke execute on function public.fn_tablero_no(text, text, text, text) from public, anon, service_role;
grant  execute on function public.fn_tablero_no(text, text, text, text) to authenticated;
comment on function public.fn_tablero_no(text, text, text, text) is 'c16: lo que contesta una tarjeta que no se puede pintar: {ok: false, tarjeta, motivo (en llano), falta (la capa que no está, si es eso), codigo (el del error, si fue un error)}.';

-- LAS CAPAS que esta base tiene, por lo que el tablero lee de cada una.
create or replace function public.fn_tablero_capas() returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'c4',  to_regclass('public.v_cxc_antiguedad') is not null and to_regclass('public.v_cxp_antiguedad') is not null
           and to_regclass('public.v_flujo_real_por_mes') is not null and to_regclass('public.v_estados_mapeo') is not null,
    'c6',  to_regclass('public.v_banco_saldos') is not null and to_regclass('public.movimientos_banco') is not null
           and to_regclass('public.banco_casados') is not null and to_regclass('public.banco_casado_lineas') is not null
           and to_regclass('public.v_banco_bandeja') is not null,
    'c6_prestamos', to_regclass('public.v_prestamos') is not null,
    'c7',  to_regclass('public.plaid_conexiones') is not null,
    'p1',  to_regclass('public.stripe_config') is not null and to_regclass('public.stripe_pagos') is not null
           and to_regclass('public.stripe_enlaces') is not null and to_regclass('public.v_stripe_estado') is not null
           and to_regclass('public.v_stripe_pagos') is not null and to_regclass('public.v_stripe_payouts') is not null
           and to_regclass('public.v_stripe_control') is not null,
    'c8',  to_regclass('public.contador_config') is not null and to_regclass('public.v_contador_control') is not null,
    'c9',  to_regclass('public.v_dr15_mes') is not null and to_regclass('public.v_cierre_estado') is not null,
    'c10', to_regclass('public.v_margen_obra') is not null,
    'c11', to_regclass('public.emision_config') is not null and to_regclass('public.emision_documentos') is not null
           and to_regclass('public.v_emision_estado') is not null,
    'c12', to_regprocedure('public.fn_wip_resumen(text)') is not null,
    'c13', to_regprocedure('public.fn_cedula_resumen(date)') is not null,
    'c14', to_regclass('public.v_subs_control') is not null,
    -- (14-nov, Fase 11c) la nómina con Gusto
    'c15', to_regprocedure('public.fn_nomina_aal2()') is not null and to_regclass('public.v_nomina_corridas') is not null
           and to_regclass('public.v_nomina_control') is not null and to_regprocedure('public.fn_nomina_cargos()') is not null)
$$;
revoke execute on function public.fn_tablero_capas() from public, anon, service_role;
grant  execute on function public.fn_tablero_capas() to authenticated;
comment on function public.fn_tablero_capas() is 'c16: las capas que esta base tiene, por lo que el tablero lee de cada una ({c4, c6, c6_prestamos, c7, p1, c8, c9, c10, c11, c12, c13, c14, c15}: verdadero o falso). La pantalla la usa para saber qué páginas enlazar.';

-- EL LIBRO: desde cuándo hay libro. El día siguiente a la apertura (la
-- regla de v_resultados de c4, de c10 y de c12); sin período de apertura,
-- el primer período que haya. Y si el asiento de la apertura ya está (vivo:
-- la regla de c9, «su asiento de apertura está vivo» — el asiento de tipo
-- apertura que no es el reverso de otro y que nadie reversó; el reverso de
-- una apertura también es de tipo apertura y no cuenta).
create or replace function public.fn_tablero_libro() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_ap    date;
  v_desde date;
  v_en    boolean;
begin
  perform fn_tablero_exigir_dueno();
  select pa.hasta into v_ap from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1;
  v_desde := coalesce(v_ap + 1, (select min(pm.desde) from periodos pm));
  v_en := exists (select 1 from asientos a
                   where a.tipo = 'apertura' and a.reversa_a is null
                     and not exists (select 1 from asientos r where r.reversa_a = a.id));
  return jsonb_build_object(
    'apertura', v_ap, 'desde', v_desde, 'primer_mes', to_char(v_desde, 'YYYY-MM'), 'apertura_en_el_libro', v_en,
    'empieza', fn_tablero_dia(coalesce(v_ap, v_desde)),
    'texto', case when v_desde is null then 'El libro no tiene períodos todavía.'
                  when v_ap is null then format('El libro de la app empieza el %s: lo de antes vive en QuickBooks.', fn_tablero_dia(v_desde))
                  when v_en then format('El libro de la app empieza con la apertura al %s: lo de antes vive en QuickBooks.', fn_tablero_dia(v_ap))
                  else format('El libro de la app empieza el %s; la apertura al %s todavía no está en el libro: los saldos de antes (el '
                              'banco, lo que se debía y lo que debían) no están contados. Lo de antes vive en QuickBooks.',
                              fn_tablero_dia(v_desde), fn_tablero_dia(v_ap)) end);
end $$;
revoke execute on function public.fn_tablero_libro() from public, anon, service_role;
grant  execute on function public.fn_tablero_libro() to authenticated;
comment on function public.fn_tablero_libro() is 'c16: desde cuándo hay libro: {apertura (el día de la apertura), desde (el primer día del libro), primer_mes (AAAA-MM), apertura_en_el_libro (si su asiento ya está y sin reversar), empieza (el día con que se dice en llano: el de la apertura, «30-sep-2026»; sin apertura, el primero del libro), texto (en llano: «El libro de la app empieza con la apertura al 30-sep-2026: lo de antes vive en QuickBooks.»)}. La regla de v_resultados (c4). Solo el dueño.';

-- El saldo en el libro (debe − haber) de una lista de cuentas hasta un día
-- (sin día, todo): contra él cuadra cada tarjeta que lo dice.
create or replace function public.fn_tablero_saldo(p_cuentas text[], p_hasta date default null) returns numeric
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce(sum(l.monto), 0)::numeric(14,2)
    from asiento_lineas l
    join asientos a on a.id = l.asiento_id
   where l.cuenta = any (p_cuentas) and (p_hasta is null or a.fecha_contable <= p_hasta)
$$;
revoke execute on function public.fn_tablero_saldo(text[], date) from public, anon, service_role;
grant  execute on function public.fn_tablero_saldo(text[], date) to authenticated;
comment on function public.fn_tablero_saldo(text[], date) is 'c16: el saldo en el libro (debe − haber) de una lista de cuentas hasta un día (sin día, todo): contra él cuadra cada tarjeta. Lee con la policy del libro: a quien no es el dueño le da 0.';

-- EL MAPEO de cada cuenta a su estado financiero: v_estados_mapeo de c4 (el
-- guardado; sin fila, el propuesto), lo mismo que leen sus estados.
create or replace function public.fn_tablero_mapa()
returns table (cuenta text, nombre text, estado text, seccion text, linea text, etiqueta text, orden int, efectivo boolean, caja boolean)
language sql stable
rows 120
set search_path = public, pg_temp
as $$
  select m.cuenta, m.cuenta_nombre, m.estado, m.seccion, m.linea, coalesce(m.etiqueta_es, m.cuenta_nombre), m.orden,
         coalesce(m.efectivo, false), coalesce(m.caja, false)
    from public.v_estados_mapeo m
$$;
revoke execute on function public.fn_tablero_mapa() from public, anon, service_role;
grant  execute on function public.fn_tablero_mapa() to authenticated;
comment on function public.fn_tablero_mapa() is 'c16: el mapeo de cada cuenta a su estado financiero, el de v_estados_mapeo de c4 (cuenta, nombre, estado, seccion, linea, etiqueta, orden, efectivo, caja). Lee con la policy de c4: a quien no es el dueño no le da nada.';


-- ---------------------------------------------------------------------
-- 2. LAS PIEZAS que comparten varias tarjetas: el resultado de un rango,
--    las partidas por cobrar y por pagar con su vencimiento, lo cobrado,
--    lo que espera en la Bandeja, las cuotas que vienen, Stripe y los
--    saldos de los bancos. fn_tablero lee cada una UNA vez por llamada.
-- ---------------------------------------------------------------------
-- LOS ASIENTOS DEL WIP (c12, fn_wip_asientos: cada ajuste del mes, su
-- reverso automático del día 1, el de corrección y la anulación de un
-- reverso), con su fecha y el mes del ajuste del que son, y si van APARTE.
-- El ajuste del WIP no es una venta ni un gasto: es lo sobre y lo
-- sub-facturado de las obras (y la provisión de pérdida) al cerrar cada mes,
-- que se deshace solo el día 1 del mes siguiente. Un mes que todavía no
-- tiene su propio ajuste (el mes en curso, o uno que se cierra sin él
-- todavía) solo lleva el reverso del ajuste del mes de antes: contado,
-- infla o encoge ese mes con lo de otro (el reverso de octubre metía
-- $17,234.35 de ingreso en el 1 de noviembre de la semilla). Por eso:
--   aparte = el asiento del WIP cae en un mes que no está cerrado y que no
--            tiene todavía un ajuste vivo suyo con fecha hasta hoy. Esos se
--            cuentan aparte, con su nota (el resultado del mes lo cuenta
--            Estados → Resultados, que sigue el libro tal cual); los demás
--            (los de un mes ya ajustado o ya cerrado) se cuentan como
--            siempre, igual que v_resultados de c4.
-- Sin c12, nada.
create or replace function public.fn_tablero_wip()
returns table (asiento_id uuid, fecha date, mes text, papel text, ajuste_periodo text, aparte boolean)
language plpgsql stable
rows 20
set search_path = public, pg_temp
as $$
#variable_conflict use_column
begin
  perform fn_tablero_exigir_dueno();
  if to_regprocedure('public.fn_wip_asientos()') is null or to_regclass('public.wip_ajustes') is null then
    return;
  end if;
  return query execute $q$
    select w.asiento_id, a.fecha_contable, to_char(a.fecha_contable, 'YYYY-MM'), w.papel, aj.periodo,
           (exists (select 1 from public.periodos p
                     where p.tipo = 'mes' and a.fecha_contable between p.desde and p.hasta and p.estado <> 'cerrado')
            and not exists (select 1 from public.wip_ajustes v
                             where v.periodo = to_char(a.fecha_contable, 'YYYY-MM') and v.deshecho_el is null and v.fecha <= $1))
      from public.fn_wip_asientos() w
      join public.asientos a on a.id = w.asiento_id
      left join public.wip_ajustes aj on aj.id = w.ajuste_id$q$
    using fn_tablero_hoy();
end $$;
revoke execute on function public.fn_tablero_wip() from public, anon, service_role;
grant  execute on function public.fn_tablero_wip() to authenticated;
comment on function public.fn_tablero_wip() is 'c16: los asientos del WIP (fn_wip_asientos de c12) con su fecha, su mes, su papel (ajuste | reverso | anulacion), el mes del ajuste del que son, y aparte (caen en un mes sin cerrar que todavía no tiene su propio ajuste vivo con fecha hasta hoy: el reverso del día 1 que espera al ajuste de su mes). Sin c12, nada. Solo lee. Solo el dueño.';

-- EL RESULTADO DE UN RANGO de fechas, del libro con el mapeo de c4: las
-- cinco secciones del estado de resultados y las tres utilidades, con el
-- signo del estado (ingresos y costos en positivo; un resultado negativo es
-- pérdida). Cuenta lo mismo que v_resultados: cada línea de resultados con
-- fecha en el rango y de SU ejercicio (un ajuste del CPA que corrige OTRO
-- año no es de estos días: va al año que corrige; se dice aparte en
-- ajustes_otro_ejercicio y no se cuenta). MENOS lo del WIP que va aparte
-- (fn_tablero_wip: el reverso del día 1 de un mes que todavía no tiene su
-- propio ajuste), que se dice en wip_aparte, con sus secciones y de qué
-- ajustes es: resultado + wip_aparte.resultado = lo de v_resultados.
create or replace function public.fn_tablero_pyg(p_desde date, p_hasta date) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v jsonb;
begin
  perform fn_tablero_exigir_dueno();
  with m as materialized (
    select x.cuenta, x.seccion from fn_tablero_mapa() x where x.estado = 'resultados'
  ), w as materialized (
    select x.asiento_id, x.ajuste_periodo, x.fecha from fn_tablero_wip() x where x.aparte and x.fecha between p_desde and p_hasta
  ), l as materialized (
    select li.monto, li.asiento_id, m.seccion,
           (a.afecta_periodo is null
            or coalesce((select pa.anio from periodos pa where pa.periodo = a.afecta_periodo), a.anio) = a.anio) as suyo,
           exists (select 1 from w where w.asiento_id = li.asiento_id) as wip
      from asiento_lineas li
      join asientos a on a.id = li.asiento_id
      join m on m.cuenta = li.cuenta
     where a.fecha_contable >= p_desde and a.fecha_contable <= p_hasta
  ), s as (
    select coalesce(-sum(l.monto) filter (where l.suyo and not l.wip and l.seccion = 'ingresos'), 0)::numeric(14,2)       as i,
           coalesce(sum(l.monto)  filter (where l.suyo and not l.wip and l.seccion = 'costo'), 0)::numeric(14,2)          as c,
           coalesce(sum(l.monto)  filter (where l.suyo and not l.wip and l.seccion = 'gastos'), 0)::numeric(14,2)         as g,
           coalesce(-sum(l.monto) filter (where l.suyo and not l.wip and l.seccion = 'otros_ingresos'), 0)::numeric(14,2) as oi,
           coalesce(sum(l.monto)  filter (where l.suyo and not l.wip and l.seccion = 'otros_gastos'), 0)::numeric(14,2)   as og,
           count(distinct l.asiento_id) filter (where l.suyo and not l.wip)                                                 as n,
           coalesce(-sum(l.monto) filter (where not l.suyo), 0)::numeric(14,2)                                              as aj,
           coalesce(-sum(l.monto) filter (where l.suyo and l.wip and l.seccion = 'ingresos'), 0)::numeric(14,2)            as wi,
           coalesce(sum(l.monto)  filter (where l.suyo and l.wip and l.seccion = 'costo'), 0)::numeric(14,2)               as wc,
           coalesce(sum(l.monto)  filter (where l.suyo and l.wip and l.seccion = 'gastos'), 0)::numeric(14,2)              as wg,
           coalesce(-sum(l.monto) filter (where l.suyo and l.wip and l.seccion = 'otros_ingresos'), 0)::numeric(14,2)      as woi,
           coalesce(sum(l.monto)  filter (where l.suyo and l.wip and l.seccion = 'otros_gastos'), 0)::numeric(14,2)        as wog,
           count(distinct l.asiento_id) filter (where l.suyo and l.wip)                                                     as wn
      from l
  )
  select jsonb_build_object(
           'ingresos', s.i, 'costo', s.c, 'gastos', s.g, 'otros_ingresos', s.oi, 'otros_gastos', s.og,
           'utilidad_bruta', (s.i - s.c)::numeric(14,2), 'utilidad_operacion', (s.i - s.c - s.g)::numeric(14,2),
           'resultado', (s.i - s.c - s.g + s.oi - s.og)::numeric(14,2),
           'entra', (s.i + s.oi)::numeric(14,2), 'sale', (s.c + s.g + s.og)::numeric(14,2),
           'asientos', s.n, 'ajustes_otro_ejercicio', s.aj,
           'wip_aparte', case when s.wn > 0 then jsonb_build_object(
               'ingresos', s.wi, 'costo', s.wc, 'gastos', s.wg, 'otros_ingresos', s.woi, 'otros_gastos', s.wog,
               'resultado', (s.wi - s.wc - s.wg + s.woi - s.wog)::numeric(14,2),
               'entra', (s.wi + s.woi)::numeric(14,2), 'sale', (s.wc + s.wg + s.wog)::numeric(14,2), 'asientos', s.wn,
               'de', (select coalesce(jsonb_agg(distinct w.ajuste_periodo), '[]'::jsonb) from w where w.ajuste_periodo is not null),
               'fecha', (select min(w.fecha) from w)) end)
    into v
    from s;
  return v;
end $$;
revoke execute on function public.fn_tablero_pyg(date, date) from public, anon, service_role;
grant  execute on function public.fn_tablero_pyg(date, date) to authenticated;
comment on function public.fn_tablero_pyg(date, date) is 'c16: el resultado de un rango de fechas, del libro con el mapeo de c4: {ingresos, costo, gastos, otros_ingresos, otros_gastos, utilidad_bruta, utilidad_operacion, resultado (la utilidad neta), entra (ingresos + otros ingresos), sale (costo + gastos + otros gastos), asientos, ajustes_otro_ejercicio (un ajuste del CPA que corrige otro año: no se cuenta aquí), wip_aparte: {ingresos, costo, gastos, otros_ingresos, otros_gastos, resultado, entra, sale, asientos, de (los meses de sus ajustes), fecha} (el reverso del WIP que espera al ajuste de su mes: no se cuenta; nulo si no hay)}. resultado + wip_aparte.resultado = v_resultados, al centavo. Solo el dueño.';

-- LAS PARTIDAS POR COBRAR de hoy, una por una: las de v_cxc_antiguedad de
-- c4 (cada factura es su partida en 1110 y 1120; un anticipo, la de su
-- cobro; lo que va sin partida, por obra y con la fecha de lo más viejo que
-- sigue sin cobrar), con CUÁNDO VENCE:
--   · la factura emitida por la app (c11) trae su vencimiento (se fijó al
--     emitirla: vence_de = factura);
--   · la que no (las de QuickBooks, o sin c11) y lo que va sin factura, su
--     fecha más los términos de Facturas → Ajustes (emision_config.
--     terminos_dias; de fábrica 0, «due on receipt»: vence el día de su
--     fecha; sin c11, 0): vence_de = terminos.
-- Vence el día que dice y está VENCIDA desde el día siguiente:
-- dias_vencida = hoy − vence (0 o menos: no ha vencido). tramo: corriente,
-- d1_30, d31_60, d61_90, d90_mas; o retencion (solo le queda retención, que
-- no vence por términos: se cobra al terminar la obra), anticipo (dinero
-- que el cliente adelantó, en negativo) o a_favor (un saldo a favor del
-- cliente sin factura, en negativo).
create or replace function public.fn_tablero_cxc()
returns table (tipo text, partida_tabla text, partida_id text, factura_id bigint, factura_num text, proyecto_id text, obra text,
               cliente text, fecha date, vence date, vence_de text, por_cobrar numeric, retencion numeric, dias_vencida int,
               tramo text)
language plpgsql stable
rows 200
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_hoy   date := fn_tablero_hoy();
  v_dias  int := 0;
  v_vence jsonb := '{}'::jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if to_regclass('public.emision_config') is not null and to_regclass('public.emision_documentos') is not null then
    execute 'select coalesce((select c.terminos_dias from public.emision_config c where c.id = 1), 0)' into v_dias;
    execute $q$select coalesce(jsonb_object_agg(d.factura_id::text, d.vence), '{}'::jsonb)
                 from public.emision_documentos d
                where d.factura_id is not null and d.vence is not null and d.estado = 'emitida'$q$ into v_vence;
  end if;
  return query
  with x as (
    select a.tipo, a.partida_tabla, a.partida_id, a.factura_id, a.factura_num, a.proyecto_id, a.obra, a.cliente, a.fecha,
           a.por_cobrar::numeric(14,2) as por_cobrar, a.retencion::numeric(14,2) as retencion,
           (v_vence ->> a.factura_id::text)::date as vence_app
      from public.v_cxc_antiguedad a
     where a.periodo = 'hoy' and a.nivel = 'partida'
  ), y as (
    select x.*,
           case when x.por_cobrar > 0 then coalesce(x.vence_app, x.fecha + v_dias) end as v,
           case when x.por_cobrar <= 0 then null when x.vence_app is not null then 'factura' else 'terminos' end as vd
      from x
  )
  select y.tipo, y.partida_tabla, y.partida_id, y.factura_id, y.factura_num, y.proyecto_id, y.obra, y.cliente, y.fecha, y.v, y.vd,
         y.por_cobrar, y.retencion, (v_hoy - y.v)::int,
         case when y.tipo = 'anticipo' then 'anticipo'
              when y.por_cobrar < 0 then 'a_favor'
              when y.por_cobrar = 0 then 'retencion'
              when y.v is null then 'sin_vencimiento'
              when v_hoy - y.v <= 0 then 'corriente'
              when v_hoy - y.v <= 30 then 'd1_30'
              when v_hoy - y.v <= 60 then 'd31_60'
              when v_hoy - y.v <= 90 then 'd61_90'
              else 'd90_mas' end
    from y;
end $$;
revoke execute on function public.fn_tablero_cxc() from public, anon, service_role;
grant  execute on function public.fn_tablero_cxc() to authenticated;
comment on function public.fn_tablero_cxc() is 'c16: las partidas por cobrar de hoy, una por una (las de v_cxc_antiguedad de c4), con su vencimiento: tipo (factura | anticipo | sin_partida | otra), partida_tabla, partida_id, factura_id, factura_num, proyecto_id, obra, cliente, fecha, vence, vence_de (factura = el de la factura emitida por la app; terminos = su fecha más los términos de Facturas → Ajustes), por_cobrar (1110), retencion (1120), dias_vencida (hoy − vence) y tramo (corriente | d1_30 | d31_60 | d61_90 | d90_mas | retencion | anticipo | a_favor | sin_vencimiento). Solo lee. Solo el dueño.';

-- LAS PARTIDAS POR PAGAR de hoy, una por una: las de v_cxp_antiguedad de c4
-- (cada papel con su proveedor; lo de la apertura, factura por factura; lo
-- pagado sin partida salda lo más viejo del mismo proveedor), con el
-- vencimiento que c4 les da (el de la balanza de apertura, o la fecha más
-- los términos del proveedor: Net 30, Net 10 EOM, Net 10th Prox…). Lo que
-- c4 no sabe cuándo vence (un proveedor sin términos, lo de la apertura sin
-- su fecha) no se inventa: tramo sin_vencimiento. por_pagar en positivo;
-- un saldo a favor (se pagó de más), en negativo, tramo a_favor; solo
-- retención (no vence por términos: se paga al terminar la obra), tramo
-- retencion.
create or replace function public.fn_tablero_cxp()
returns table (tipo text, partida_tabla text, partida_id text, proveedor text, referencia text, fecha date, vence date,
               por_pagar numeric, retencion numeric, dias_vencida int, tramo text)
language plpgsql stable
rows 200
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_hoy date := fn_tablero_hoy();
begin
  perform fn_tablero_exigir_dueno();
  return query
  select x.tipo, x.partida_tabla, x.partida_id, x.proveedor, x.referencia, x.fecha,
         case when x.por_pagar > 0 then x.vence end,
         x.por_pagar::numeric(14,2), x.retencion::numeric(14,2),
         case when x.por_pagar > 0 and x.vence is not null then (v_hoy - x.vence)::int end,
         case when x.por_pagar < 0 then 'a_favor'
              when x.por_pagar = 0 then 'retencion'
              when x.vence is null then 'sin_vencimiento'
              when v_hoy - x.vence <= 0 then 'corriente'
              when v_hoy - x.vence <= 30 then 'd1_30'
              when v_hoy - x.vence <= 60 then 'd31_60'
              when v_hoy - x.vence <= 90 then 'd61_90'
              else 'd90_mas' end
    from public.v_cxp_antiguedad x
   where x.periodo = 'hoy' and x.nivel = 'partida';
end $$;
revoke execute on function public.fn_tablero_cxp() from public, anon, service_role;
grant  execute on function public.fn_tablero_cxp() to authenticated;
comment on function public.fn_tablero_cxp() is 'c16: las partidas por pagar de hoy, una por una (las de v_cxp_antiguedad de c4), con su vencimiento: tipo (papel | proveedor | sin_partida), partida_tabla, partida_id, proveedor, referencia, fecha, vence (el que c4 les da: la balanza de apertura o los términos del proveedor; nulo si no se sabe), por_pagar (2010, en positivo), retencion (2020), dias_vencida (hoy − vence) y tramo (corriente | d1_30 | d31_60 | d61_90 | d90_mas | sin_vencimiento | retencion | a_favor). Solo lee. Solo el dueño.';

-- LOS COBROS de un rango de días, uno por uno, con si ya están en el banco.
-- Un cobro es un papel de c3 (cobros): cuenta el vigente con su fecha en el
-- rango; lo devuelto de él (un cheque rebotado, cobros_devoluciones) se le
-- resta (neto). Su CLASE: stripe (entró a la cuenta puente de p1), caja (la
-- caja chica) o banco. Su ESTADO:
--   depositado  banco: casado con su movimiento del banco (c6: el cobro
--               con su movimiento, o su línea del banco casada); stripe: los
--               depósitos de Stripe ya asentados cubren lo que su pago tiene
--               en el libro (lo que falta depositar es cero o MENOS: un
--               reembolso después del depósito lo descuenta Stripe del
--               siguiente) y todos llegaron al banco y están casados
--   sin_casar   banco: todavía no aparece en el banco (el cheque en la
--               mano, el depósito que el banco aún no trae)
--   en_camino   stripe: ya va en un depósito de Stripe que el banco aún no
--               casó
--   en_stripe   stripe: cobrado, todavía en Stripe
--   en_caja     en la caja chica: no está en el banco
--   sin_banco   banco, en una base sin c6: no se sabe
-- Lo de Stripe se lee de las tablas de p1 (el pago de cada cobro, por su
-- rastro stripe_pago_libro, y lo que liquidaron sus depósitos) con la misma
-- regla de v_stripe_pagos, pero SIN su ventana de 120 días: un cobro viejo
-- ya depositado sigue depositado.
create or replace function public.fn_tablero_cobros_lista(p_desde date, p_hasta date)
returns table (cobro_id uuid, fecha date, monto numeric, devuelto numeric, neto numeric, cuenta text, medio text, clase text,
               estado text, depositado numeric, a_facturas numeric, facturas bigint[], proyecto_id text)
language plpgsql stable
rows 100
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_hoy    date := fn_tablero_hoy();
  v_c6     boolean := to_regclass('public.banco_casado_lineas') is not null and to_regclass('public.banco_casados') is not null;
  v_p1     boolean := to_regclass('public.stripe_config') is not null and to_regclass('public.stripe_pagos') is not null
                      and to_regclass('public.stripe_pago_libro') is not null and to_regclass('public.stripe_payouts') is not null
                      and to_regclass('public.stripe_payout_lineas') is not null;
  v_puente text;
  v_st     jsonb := '{}'::jsonb;    -- cobro → estado de su pago en Stripe (p1)
  v_cas    uuid[] := '{}';          -- los cobros del rango ya casados con el banco (c6)
  v_caja   text[];                  -- las cuentas de caja chica (c4)
  v_origen jsonb := '{}'::jsonb;    -- cobro que p1 volvió a registrar → el día del primer cobro de su pago (la revisión final)
  v_ids    uuid[];                  -- los cobros del rango, por el día en que se cobró el dinero
begin
  perform fn_tablero_exigir_dueno();
  v_caja := array(select m.cuenta from fn_tablero_mapa() m where m.caja);
  if p_desde is null or p_hasta is null or p_desde > p_hasta then
    raise exception using errcode = '22023', message = 'El rango de los cobros lleva sus dos fechas, en orden.';
  end if;
  if v_p1 then
    execute 'select c.cuenta_puente from public.stripe_config c where c.id = 1' into v_puente;
    -- (EL DÍA EN QUE SE COBRÓ: cuando un pago de Stripe cambia —un reembolso en parte, una disputa—, p1 devuelve su cobro y
    --  registra uno nuevo por lo que queda, con la fecha del cambio. Ese dinero se cobró el día del primer cobro de su pago, no
    --  el del cambio: el cobro nuevo cuenta en los días de aquel. Sin esto, un pago de hace dos meses reembolsado en parte hoy
    --  salía «cobrado en los últimos 30 días».)
    execute $q$select coalesce(jsonb_object_agg(z.cobro_id::text, z.origen), '{}'::jsonb)
                 from (select pl.cobro_id, min(c2.fecha) as origen, max(c.fecha) as propia
                         from public.stripe_pago_libro pl
                         join public.cobros c on c.id = pl.cobro_id
                         join public.stripe_pago_libro pl2 on pl2.pago_id = pl.pago_id and pl2.accion = 'cobro'
                         join public.cobros c2 on c2.id = pl2.cobro_id
                        where pl.accion = 'cobro'
                        group by pl.cobro_id) z
                where z.origen < z.propia$q$ into v_origen;
  end if;
  v_ids := array(select c.id from cobros c
                  where c.estado = 'vigente' and coalesce((v_origen ->> c.id::text)::date, c.fecha) between p_desde and p_hasta);
  if v_p1 and v_c6 and v_puente is not null then
    -- (cada cobro de Stripe del rango → su pago; lo que liquidaron los depósitos asentados de ese pago y si todos llegaron al
    --  banco y están casados: la regla de v_stripe_pagos de p1, sin su ventana de 120 días)
    execute $q$
      with cfg as (select * from public.stripe_config where id = 1),
      k as (
        select c.id as cobro_id,
               coalesce((select s.id from public.stripe_pagos s where s.cobro_id = c.id limit 1),
                        (select pl.pago_id from public.stripe_pago_libro pl where pl.cobro_id = c.id and pl.accion = 'cobro'
                          order by pl.id desc limit 1)) as pago_id
          from public.cobros c
         where c.id = any ($1) and c.cuenta = $2
      ), dep as (
        select l.pago_id, sum(l.monto) as liquidado,
               bool_and(exists (select 1 from public.asiento_lineas al
                                  join public.banco_casado_lineas bcl on bcl.asiento_id = al.asiento_id and bcl.orden = al.orden and bcl.vigente
                                  join public.banco_casados bc on bc.id = bcl.casado_id and bc.deshecho_el is null
                                 cross join cfg
                                 where al.asiento_id = q.asiento_llegada and al.cuenta = cfg.cuenta_banco)) as todos_casados
          from public.stripe_payout_lineas l
          join public.stripe_payouts q on q.id = l.payout_id
         where l.clase = 'pago' and l.pago_id in (select k.pago_id from k) and q.asiento_salida is not null
           and not exists (select 1 from public.asientos r where r.reversa_a = q.asiento_salida and r.camino = 'reverso')
         group by l.pago_id
      )
      select coalesce(jsonb_object_agg(k.cobro_id::text,
               case when s.estado = 'cobrado' and dep.liquidado is not null
                         and case when coalesce(s.resuelto ? 'fuera', false) then 0 else s.en_libro - dep.liquidado end <= 0
                    then case when coalesce(dep.todos_casados, false) then 'depositado' else 'en_payout' end
                    else 'cobrado' end), '{}'::jsonb)
        from k
        left join public.stripe_pagos s on s.id = k.pago_id
        left join dep on dep.pago_id = k.pago_id$q$
      into v_st using v_ids, v_puente;
  end if;
  if v_c6 then
    execute $q$select coalesce(array_agg(c.id), '{}'::uuid[])
                 from public.cobros c
                where c.id = any ($1)
                  and (c.movimiento_id is not null
                       or exists (select 1 from public.banco_casado_lineas bl
                                    join public.banco_casados bc on bc.id = bl.casado_id
                                   where bl.asiento_id = c.contabilizado_en and bl.cuenta = c.cuenta and bl.vigente
                                     and bc.deshecho_el is null))$q$
      into v_cas using v_ids;
  end if;
  return query
  with k as (
    select c.id, c.fecha, c.monto, c.cuenta, c.medio, c.proyecto_id,
           coalesce((select sum(d.monto) from cobros_devoluciones d where d.cobro_id = c.id and d.fecha <= v_hoy), 0)::numeric(14,2) as dev,
           case when c.cuenta = v_puente then 'stripe'
                when c.cuenta = any (v_caja) then 'caja'
                else 'banco' end as clase
      from cobros c
     where c.id = any (v_ids)
  ), e as (
    select k.*, (k.monto - k.dev)::numeric(14,2) as neto,
           case k.clase
             when 'stripe' then case v_st ->> k.id::text when 'depositado' then 'depositado' when 'en_payout' then 'en_camino'
                                                          else 'en_stripe' end
             when 'caja' then 'en_caja'
             else case when not v_c6 then 'sin_banco' when k.id = any (v_cas) then 'depositado' else 'sin_casar' end end as est
      from k
  )
  select e.id, e.fecha, e.monto::numeric(14,2), e.dev, e.neto, e.cuenta, e.medio, e.clase, e.est,
         (case when e.est = 'depositado' then e.neto else 0 end)::numeric(14,2),
         coalesce((select sum(ap.monto) from aplicaciones_cobro ap where ap.cobro_id = e.id and ap.factura_id is not null), 0)::numeric(14,2),
         coalesce((select array_agg(distinct ap.factura_id) from aplicaciones_cobro ap where ap.cobro_id = e.id and ap.factura_id is not null),
                  '{}'::bigint[]),
         e.proyecto_id
    from e;
end $$;
revoke execute on function public.fn_tablero_cobros_lista(date, date) from public, anon, service_role;
grant  execute on function public.fn_tablero_cobros_lista(date, date) to authenticated;
comment on function public.fn_tablero_cobros_lista(date, date) is 'c16: los cobros vigentes de un rango (c3), uno por uno: cobro_id, fecha, monto, devuelto (lo rebotado de él), neto, cuenta, medio, clase (banco | stripe | caja), estado (depositado | sin_casar | en_camino | en_stripe | en_caja | sin_banco), depositado (el neto si está en el banco), a_facturas (lo aplicado a facturas), facturas (sus ids), proyecto_id. Un cobro entra en el rango por el día en que se cobró el dinero: el que p1 volvió a registrar tras un reembolso en parte o una disputa, por el día del primer cobro de su pago (no por el del cambio). Depositado = casado con su movimiento del banco (c6) o, si entró por Stripe, los depósitos de su pago ya asentados cubren lo que tiene en el libro (lo que falta depositar es cero o menos, como tras un reembolso) y todos están casados en el banco (las tablas de p1, sin la ventana de 120 días de v_stripe_pagos). Solo lee. Solo el dueño.';

-- LO DEVUELTO DE VERDAD en un rango: cada devolución de un cobro (c3,
-- cobros_devoluciones) con fecha en esos días, MENOS la parte técnica de
-- Stripe: cuando un pago cambia (un reembolso, una disputa), p1 devuelve el
-- cobro vivo ENTERO y registra uno nuevo por lo que queda (stripe_pago_libro:
-- la «devolucion» y el «cobro» de ese mismo momento); lo devuelto de verdad
-- es la diferencia (1,250.00 − 1,000.00 = el reembolso de 250.00). Un cheque
-- rebotado (sin Stripe) cuenta entero. Y DE QUÉ COBRO ES (la revisión final):
-- lo de un cobro de ESTOS días ya está restado de lo cobrado en ellos (su
-- neto); lo de un cobro de ANTES (un cheque de hace 40 días que rebota hoy,
-- un pago de Stripe de hace dos meses reembolsado en parte hoy) no estaba en
-- lo cobrado de estos días: va aparte, en «antes». El día de un cobro es el
-- día en que se cobró el dinero (el de un cobro que p1 volvió a registrar,
-- el del primer cobro de su pago). {monto, n, cheques: {monto, n}, stripe:
-- {monto, n}, antes: {monto, n, cheques: {monto, n}, stripe: {monto, n}}}.
create or replace function public.fn_tablero_devuelto(p_desde date, p_hasta date) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if to_regclass('public.stripe_pago_libro') is not null then
    execute $q$
      with d as (
        select dv.id, dv.monto,
               exists (select 1 from public.stripe_pago_libro pd where pd.devolucion_id = dv.id and pd.accion = 'devolucion') as de_stripe,
               coalesce((select sum(pc.monto) from public.stripe_pago_libro pd
                           join public.stripe_pago_libro pc on pc.pago_id = pd.pago_id and pc.accion = 'cobro' and pc.creado_el = pd.creado_el
                          where pd.devolucion_id = dv.id and pd.accion = 'devolucion'), 0) as rehecho,
               -- (el día en que se cobró: el del cobro; si p1 lo volvió a registrar, el del primer cobro de su pago)
               coalesce((select min(c2.fecha) from public.stripe_pago_libro pl
                           join public.stripe_pago_libro pl2 on pl2.pago_id = pl.pago_id and pl2.accion = 'cobro'
                           join public.cobros c2 on c2.id = pl2.cobro_id
                          where pl.cobro_id = dv.cobro_id and pl.accion = 'cobro'), c.fecha) as origen
          from public.cobros_devoluciones dv
          join public.cobros c on c.id = dv.cobro_id
         where dv.fecha between $1 and $2
      ), x as (
        select d.de_stripe, d.origen >= $1 as de_estos, greatest(d.monto - d.rehecho, 0)::numeric(14,2) as real from d
      )
      select jsonb_build_object(
               'monto', coalesce(sum(x.real) filter (where x.de_estos), 0)::numeric(14,2), 'n', count(*) filter (where x.de_estos and x.real > 0),
               'cheques', jsonb_build_object('monto', coalesce(sum(x.real) filter (where x.de_estos and not x.de_stripe), 0)::numeric(14,2),
                                             'n', count(*) filter (where x.de_estos and not x.de_stripe and x.real > 0)),
               'stripe', jsonb_build_object('monto', coalesce(sum(x.real) filter (where x.de_estos and x.de_stripe), 0)::numeric(14,2),
                                            'n', count(*) filter (where x.de_estos and x.de_stripe and x.real > 0)),
               'antes', jsonb_build_object(
                  'monto', coalesce(sum(x.real) filter (where not x.de_estos), 0)::numeric(14,2), 'n', count(*) filter (where not x.de_estos and x.real > 0),
                  'cheques', jsonb_build_object('monto', coalesce(sum(x.real) filter (where not x.de_estos and not x.de_stripe), 0)::numeric(14,2),
                                                'n', count(*) filter (where not x.de_estos and not x.de_stripe and x.real > 0)),
                  'stripe', jsonb_build_object('monto', coalesce(sum(x.real) filter (where not x.de_estos and x.de_stripe), 0)::numeric(14,2),
                                               'n', count(*) filter (where not x.de_estos and x.de_stripe and x.real > 0))))
        from x$q$ into v using p_desde, p_hasta;
  else
    select jsonb_build_object('monto', coalesce(sum(dv.monto) filter (where c.fecha >= p_desde), 0)::numeric(14,2),
                              'n', count(*) filter (where c.fecha >= p_desde and dv.monto > 0),
                              'cheques', jsonb_build_object('monto', coalesce(sum(dv.monto) filter (where c.fecha >= p_desde), 0)::numeric(14,2),
                                                            'n', count(*) filter (where c.fecha >= p_desde and dv.monto > 0)),
                              'stripe', jsonb_build_object('monto', 0::numeric(14,2), 'n', 0),
                              'antes', jsonb_build_object(
                                 'monto', coalesce(sum(dv.monto) filter (where c.fecha < p_desde), 0)::numeric(14,2),
                                 'n', count(*) filter (where c.fecha < p_desde and dv.monto > 0),
                                 'cheques', jsonb_build_object('monto', coalesce(sum(dv.monto) filter (where c.fecha < p_desde), 0)::numeric(14,2),
                                                               'n', count(*) filter (where c.fecha < p_desde and dv.monto > 0)),
                                 'stripe', jsonb_build_object('monto', 0::numeric(14,2), 'n', 0)))
      into v
      from cobros_devoluciones dv join cobros c on c.id = dv.cobro_id
     where dv.fecha between p_desde and p_hasta;
  end if;
  return v;
end $$;
revoke execute on function public.fn_tablero_devuelto(date, date) from public, anon, service_role;
grant  execute on function public.fn_tablero_devuelto(date, date) to authenticated;
comment on function public.fn_tablero_devuelto(date, date) is 'c16: lo devuelto de verdad en un rango (c3, cobros_devoluciones), sin la devolución técnica con que p1 rehace un cobro de Stripe que cambió: {monto, n, cheques: {monto, n} (cheques rebotados y demás devoluciones sin Stripe), stripe: {monto, n} (reembolsos y disputas, solo lo que de verdad se devolvió)} de los cobros de ESOS días (ya restado de lo cobrado en ellos), y antes: {monto, n, cheques, stripe} (lo devuelto en esos días de cobros de antes: no estaba en lo cobrado de esos días). El día de un cobro es el día en que se cobró (el de un cobro que p1 volvió a registrar, el del primer cobro de su pago). Solo lee. Solo el dueño.';

-- LO COBRADO, sumado: el resumen de una lista de cobros (la de arriba, en
-- jsonb) para el embudo y la tarjeta de facturas. Y lo devuelto en esos
-- días (de Stripe, solo lo que de verdad se devolvió: fn_tablero_devuelto):
-- lo de los cobros de esos días, «ya restado» de lo cobrado; lo de un cobro
-- de antes (un cheque de hace 40 días que rebota hoy), aparte, en
-- devuelto_antes: no estaba en lo cobrado y no se resta de nada (la
-- revisión final: antes decía «ya restado» de todo).
create or replace function public.fn_tablero_cobrado(p_lista jsonb, p_desde date, p_hasta date) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_c6 boolean := to_regclass('public.banco_casado_lineas') is not null;
  r    record;
  v_dv jsonb;
begin
  perform fn_tablero_exigir_dueno();
  v_dv := fn_tablero_devuelto(p_desde, p_hasta);
  select coalesce(sum(x.neto) filter (where x.neto > 0), 0)::numeric(14,2) as monto,
         count(*) filter (where x.neto > 0) as n,
         (select count(distinct f.v) from jsonb_array_elements(coalesce(p_lista, '[]'::jsonb)) j,
                 jsonb_array_elements_text(j -> 'facturas') f(v)
           where (j ->> 'neto')::numeric > 0) as facturas,
         coalesce(sum(x.a_facturas) filter (where x.neto > 0), 0)::numeric(14,2) as a_facturas,
         coalesce(sum(x.depositado) filter (where x.neto > 0), 0)::numeric(14,2) as dep,
         count(*) filter (where x.neto > 0 and x.estado = 'depositado') as n_dep,
         coalesce(sum(x.neto) filter (where x.neto > 0 and x.estado = 'sin_casar'), 0)::numeric(14,2) as sin_casar,
         count(*) filter (where x.neto > 0 and x.estado = 'sin_casar') as n_sin_casar,
         coalesce(sum(x.neto) filter (where x.neto > 0 and x.estado = 'en_camino'), 0)::numeric(14,2) as en_camino,
         count(*) filter (where x.neto > 0 and x.estado = 'en_camino') as n_en_camino,
         coalesce(sum(x.neto) filter (where x.neto > 0 and x.estado = 'en_stripe'), 0)::numeric(14,2) as en_stripe,
         count(*) filter (where x.neto > 0 and x.estado = 'en_stripe') as n_en_stripe,
         coalesce(sum(x.neto) filter (where x.neto > 0 and x.estado = 'en_caja'), 0)::numeric(14,2) as en_caja,
         count(*) filter (where x.neto > 0 and x.estado = 'en_caja') as n_en_caja,
         count(*) filter (where x.neto > 0 and x.estado = 'sin_banco') as n_sin_banco
    into r
    from jsonb_to_recordset(coalesce(p_lista, '[]'::jsonb)) as x(neto numeric, estado text, depositado numeric, a_facturas numeric);
  return jsonb_build_object(
    'desde', p_desde, 'hasta', p_hasta, 'dias', p_hasta - p_desde + 1,
    'monto', r.monto, 'n', r.n, 'facturas', r.facturas, 'a_facturas', r.a_facturas,
    'anticipos', (r.monto - r.a_facturas)::numeric(14,2),
    -- (sin el banco, c6, no se sabe qué está depositado: nulo, aunque no haya cobros)
    'depositado', case when r.n_sin_banco = 0 and v_c6 then jsonb_build_object('monto', r.dep, 'n', r.n_dep) end,
    'sin_depositar', case when r.n_sin_banco = 0 and v_c6
                          then jsonb_build_object('monto', (r.monto - r.dep)::numeric(14,2), 'n', r.n - r.n_dep,
                                                  'sin_casar', jsonb_build_object('monto', r.sin_casar, 'n', r.n_sin_casar,
                                                                                  'etiqueta', 'todavía no sale en el banco (el cheque en la mano, el depósito que el banco aún no trae)'),
                                                  'en_camino', jsonb_build_object('monto', r.en_camino, 'n', r.n_en_camino,
                                                                                  'etiqueta', 'en un depósito de Stripe que el banco todavía no trae'),
                                                  'en_stripe', jsonb_build_object('monto', r.en_stripe, 'n', r.n_en_stripe,
                                                                                  'etiqueta', 'en Stripe, sin depositar'),
                                                  'en_caja', jsonb_build_object('monto', r.en_caja, 'n', r.n_en_caja,
                                                                                'etiqueta', 'en la caja chica (efectivo o cheque sin depositar)')) end,
    'devuelto', (v_dv - 'antes') || jsonb_build_object('etiqueta', 'devuelto de lo cobrado en estos días (cheques rebotados y reembolsos; ya restado)'),
    -- (lo devuelto en estos días de un cobro de ANTES: no estaba en lo cobrado; se dice aparte y no se resta de nada)
    'devuelto_antes', case when coalesce((v_dv -> 'antes' ->> 'n')::int, 0) > 0
                           then (v_dv -> 'antes') || jsonb_build_object('etiqueta', 'devuelto en estos días de cobros de antes (no estaban en lo cobrado; no se resta)') end,
    'nota', case when not v_c6 then 'Sin el banco (c6) en esta base no se sabe qué cobros ya están depositados.' end,
    'fuente', 'los cobros vigentes de esos días (c3), menos lo devuelto; depositado = casado con su movimiento del banco (c6) o, si '
              || 'entró por Stripe, su depósito ya casado en el banco (p1)'
              || case when not v_c6 then ' (sin c6 en esta base)' else '' end);
end $$;
revoke execute on function public.fn_tablero_cobrado(jsonb, date, date) from public, anon, service_role;
grant  execute on function public.fn_tablero_cobrado(jsonb, date, date) to authenticated;
comment on function public.fn_tablero_cobrado(jsonb, date, date) is 'c16: lo cobrado en un rango, sumado desde la lista de fn_tablero_cobros_lista (en jsonb): {desde, hasta, dias, monto (los netos), n (cobros), facturas (cuántas facturas tocaron), a_facturas (lo aplicado a facturas), anticipos (lo que no), depositado: {monto, n}, sin_depositar: {monto, n, sin_casar, en_camino, en_stripe, en_caja} (cada uno {monto, n, etiqueta: en llano}), devuelto: {monto, n, cheques: {monto, n}, stripe: {monto, n}, etiqueta} (lo devuelto DE VERDAD de los cobros de esos días, ya restado de lo cobrado: los cheques rebotados enteros y, de Stripe, solo el reembolso, no la devolución técnica con que p1 rehace el cobro: fn_tablero_devuelto), devuelto_antes: {monto, n, cheques, stripe, etiqueta} (lo devuelto en esos días de cobros de antes: no estaba en lo cobrado y no se resta; nulo si no hay), nota, fuente}. depositado y sin_depositar son nulos si no hay banco (c6). Solo el dueño.';

-- LO QUE ESPERA EN LA BANDEJA (c6) con fecha en un rango (sin fechas,
-- todo): las MISMAS filas que la página de la Bandeja (v_banco_bandeja):
--   · lo pendiente (sin casar ni clasificar). Un CARGO que espera puede ser
--     un gasto que todavía no está en el libro; un DEPÓSITO que espera es un
--     cobro (nunca un ingreso: el ingreso lo pone la factura);
--   · lo clasificado cuyo ticket llegó DESPUÉS («llegó su ticket»): ese
--     gasto está DOS VECES en el libro hasta que Edgar diga cuál se queda
--     (lo gastado va de más, no de menos);
--   · lo casado que el banco o Plaid quitaron (hasta que se des-case).
-- {n (todas sus filas), cargos y depositos (lo pendiente), dobles (llegó su
-- ticket), quitadas, mas_viejo, ir}. Nulo sin c6.
create or replace function public.fn_tablero_por_revisar(p_desde date, p_hasta date) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if to_regclass('public.v_banco_bandeja') is null then
    return null;
  end if;
  execute $q$
    with b as (
      select x.movimiento_id, x.fecha, x.monto, x.motivo,
             x.motivo = 'llego_su_ticket' as doble, x.motivo = 'quitada' as quitada
        from public.v_banco_bandeja x
       where ($1::date is null or x.fecha >= $1) and ($2::date is null or x.fecha <= $2)
    )
    select jsonb_build_object(
             'n', count(*),
             'cargos', jsonb_build_object('n', count(*) filter (where b.monto < 0 and not b.doble and not b.quitada),
                                          'monto', coalesce(-sum(b.monto) filter (where b.monto < 0 and not b.doble and not b.quitada), 0)::numeric(14,2)),
             'depositos', jsonb_build_object('n', count(*) filter (where b.monto > 0 and not b.doble and not b.quitada),
                                             'monto', coalesce(sum(b.monto) filter (where b.monto > 0 and not b.doble and not b.quitada), 0)::numeric(14,2)),
             'dobles', jsonb_build_object('n', count(*) filter (where b.doble),
                                          'monto', coalesce(-sum(b.monto) filter (where b.doble), 0)::numeric(14,2)),
             'quitadas', jsonb_build_object('n', count(*) filter (where b.quitada),
                                            'monto', coalesce(sum(b.monto) filter (where b.quitada), 0)::numeric(14,2)),
             'mas_viejo', min(b.fecha),
             'desde', $1, 'hasta', $2,
             -- (la Bandeja entera, sin el filtro de una cuenta que se haya quedado de antes)
             'ir', jsonb_build_object('pagina', 'bandeja', 'cuenta', null, 'desde', $1, 'hasta', $2))
      from b
  $q$ into v using p_desde, p_hasta;
  return v;
end $$;
revoke execute on function public.fn_tablero_por_revisar(date, date) from public, anon, service_role;
grant  execute on function public.fn_tablero_por_revisar(date, date) to authenticated;
comment on function public.fn_tablero_por_revisar(date, date) is 'c16: lo que espera en la Bandeja (c6) con fecha en un rango (sin fechas, todo), contado como la página de la Bandeja (v_banco_bandeja): {n (todas sus filas), cargos: {n, monto} y depositos: {n, monto} (lo pendiente; en positivo), dobles: {n, monto} (lo clasificado cuyo ticket llegó después: el gasto está dos veces en el libro), quitadas: {n, monto} (lo casado que el banco quitó), mas_viejo, desde, hasta, ir: {pagina: bandeja, cuenta: nulo (la Bandeja entera), desde, hasta}}. Un cargo pendiente puede ser un gasto que falta en el libro; un depósito es un cobro, no un ingreso. Nulo sin c6. Solo el dueño.';

-- LAS CUOTAS QUE VIENEN de cada préstamo vigente (c6), hasta un día: desde
-- la PRÓXIMA (la siguiente de su calendario contando las ya registradas)
-- hasta p_hasta. EL CALENDARIO de un préstamo sale de su primer pago y de
-- cuántas cuotas tiene el año (prestamos.cuotas_al_anio, c6): mensual el
-- día de pago de cada mes (el último día del mes si el mes es más corto);
-- cada 2, 3, 6 o 12 meses, el día del primer pago; semanal o cada dos
-- semanas, cada 7 o 14 días; quincenal (dos al mes), el día del primer pago
-- y quince días después. LA PRÓXIMA: las fechas del calendario hasta el
-- saldo inicial (lo de antes del libro) ya pasaron; de las que siguen, la
-- primera después de las que el libro ya tiene registradas (una pagada
-- unos días antes o después cuenta por la suya; si falta una, la próxima es
-- la que falta y sale «atrasada»: puede que su cargo esté esperando en la
-- Bandeja). EL REPARTO de cada una es la fórmula de c6 (el interés del
-- período sobre lo que se debe; el resto, a capital; la última, lo que
-- quede): lo que dirá el statement salvo un pago extra.
create or replace function public.fn_tablero_cuotas(p_hasta date)
returns table (prestamo_id uuid, prestamista text, n int, fecha date, monto numeric, capital numeric, interes numeric,
               saldo_despues numeric, atrasada boolean)
language plpgsql stable
rows 50
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_hoy   date := fn_tablero_hoy();
  p       record;
  v_k     int;
  v_k0    int;
  v_f     date;
  v_saldo numeric;
  v_int   numeric;
  v_cap   numeric;
  v_i     int;
begin
  perform fn_tablero_exigir_dueno();
  if to_regclass('public.v_prestamos') is null then
    return;
  end if;
  for p in execute $q$select x.prestamo_id, x.prestamista, x.saldo, x.cuota, x.tasa_anual, x.cuotas_al_anio, x.primer_pago,
                             x.dia_pago, x.saldo_inicial_al, x.cuotas
                        from public.v_prestamos x
                       where x.estado = 'vigente' and x.saldo > 0 and x.cuota > 0 and x.primer_pago is not null
                       order by x.prestamista, x.prestamo_id$q$ loop
    -- cuántas fechas del calendario caen hasta el saldo inicial (ya pagadas fuera del libro)
    v_k0 := 0;
    loop
      v_f := fn_tablero_cuotas_fecha(p.primer_pago, p.dia_pago, p.cuotas_al_anio, v_k0);
      exit when v_f > coalesce(p.saldo_inicial_al, p.primer_pago - 1) or v_k0 > 5000;
      v_k0 := v_k0 + 1;
    end loop;
    v_k := v_k0 + coalesce(p.cuotas, 0)::int;
    v_saldo := p.saldo;
    v_i := 0;
    loop
      v_f := fn_tablero_cuotas_fecha(p.primer_pago, p.dia_pago, p.cuotas_al_anio, v_k);
      exit when v_saldo <= 0 or v_i >= 600 or (v_f > p_hasta and v_i > 0);
      v_int := round(v_saldo * p.tasa_anual / 100 / p.cuotas_al_anio, 2);
      v_cap := least(v_saldo, greatest(p.cuota - v_int, 0));
      v_saldo := v_saldo - v_cap;
      prestamo_id := p.prestamo_id; prestamista := p.prestamista; n := v_i + 1; fecha := v_f;
      monto := (v_cap + v_int)::numeric(14,2); capital := v_cap::numeric(14,2); interes := v_int::numeric(14,2);
      saldo_despues := v_saldo::numeric(14,2); atrasada := v_f < v_hoy;
      return next;
      exit when v_cap = 0;   -- (la cuota no cubre ni el interés: no baja nunca; con una basta)
      v_i := v_i + 1;
      v_k := v_k + 1;
    end loop;
  end loop;
end $$;

-- (la fecha número k —desde 0— del calendario de un préstamo; ver arriba)
create or replace function public.fn_tablero_cuotas_fecha(p_primer date, p_dia int, p_al_anio int, p_k int) returns date
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  v_meses int := case p_al_anio when 12 then 1 when 6 then 2 when 4 then 3 when 2 then 6 when 1 then 12 end;
  v_dias  int := case p_al_anio when 52 then 7 when 26 then 14 end;
  v_base  date;
  v_dia   int;
  v_a     int;
  v_slot  int;
begin
  if v_meses is not null then
    v_base := (date_trunc('month', p_primer) + make_interval(months => p_k * v_meses))::date;
    v_dia := case when p_al_anio = 12 then coalesce(p_dia, extract(day from p_primer)::int) else extract(day from p_primer)::int end;
    return v_base + least(v_dia, extract(day from (v_base + interval '1 month' - interval '1 day'))::int) - 1;
  elsif v_dias is not null then
    return p_primer + p_k * v_dias;
  elsif p_al_anio = 24 then
    -- quincenal: el día del primer pago y quince días después, cada mes
    v_a := case when extract(day from p_primer) <= 15 then extract(day from p_primer)::int else extract(day from p_primer)::int - 15 end;
    v_slot := case when extract(day from p_primer) <= 15 then 0 else 1 end + p_k;
    v_base := (date_trunc('month', p_primer) + make_interval(months => v_slot / 2))::date;
    v_dia := case when v_slot % 2 = 0 then v_a else v_a + 15 end;
    return v_base + least(v_dia, extract(day from (v_base + interval '1 month' - interval '1 day'))::int) - 1;
  else
    -- (otra frecuencia: por días, el año entre sus cuotas)
    return p_primer + (p_k * 365 / greatest(p_al_anio, 1));
  end if;
end $$;
revoke execute on function public.fn_tablero_cuotas_fecha(date, int, int, int) from public, anon, service_role;
grant  execute on function public.fn_tablero_cuotas_fecha(date, int, int, int) to authenticated;
comment on function public.fn_tablero_cuotas_fecha(date, int, int, int) is 'c16: la fecha número k (desde 0) del calendario de un préstamo: mensual el día de pago (o el último del mes); cada 2, 3, 6 o 12 meses el día del primer pago; semanal o cada dos semanas, cada 7 o 14 días; quincenal, el día del primer pago y quince después.';
revoke execute on function public.fn_tablero_cuotas(date) from public, anon, service_role;
grant  execute on function public.fn_tablero_cuotas(date) to authenticated;
comment on function public.fn_tablero_cuotas(date) is 'c16: las cuotas que vienen de cada préstamo vigente (v_prestamos de c6) hasta un día, desde la próxima sin registrar: prestamo_id, prestamista, n (1 = la próxima), fecha (por su calendario), monto, capital, interes (la fórmula de c6), saldo_despues, atrasada (su fecha ya pasó y el libro no la tiene). Siempre sale la próxima, aunque caiga después de ese día. Solo lee. Solo el dueño.';

-- STRIPE (p1) en una pieza, para las conexiones, los cobros en línea y las
-- acciones: las mismas cifras de v_stripe_estado (sin la dirección de la
-- función), leídas de donde las lee ella —su control (v_stripe_control) UNA
-- vez, para contar lo que está en rojo y decir qué es; lo que falta
-- depositar de v_stripe_pagos; lo demás, de sus tablas— porque la vista
-- entera relee su control y cuesta el doble. Las pruebas comparan cada
-- cifra con v_stripe_estado. Y el último depósito que llegó y los que
-- vienen. Nulo sin p1.
create or replace function public.fn_tablero_stripe() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy date := fn_tablero_hoy();
  v     jsonb;
  v_c   jsonb;
  v_u   jsonb;
  v_s   jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if (fn_tablero_capas() ->> 'p1')::boolean is not true then
    return null;
  end if;
  -- su control, una vez: los cuadres y las alarmas en rojo (como los cuenta v_stripe_estado: «not ok»)
  execute $q$select jsonb_build_object(
                'cuadres_rojos', count(*) filter (where c.nivel = 'cuadre' and not c.ok),
                'alarmas', count(*) filter (where c.nivel = 'alarma' and not c.ok),
                'rojos', coalesce(jsonb_agg(jsonb_build_object('orden', c.orden, 'control', c.control, 'nivel', c.nivel, 'detalle', c.detalle)
                                            order by (c.nivel = 'cuadre') desc, c.orden) filter (where c.ok is not true), '[]'::jsonb))
               from public.v_stripe_control c$q$ into v_c;
  execute $q$select jsonb_build_object(
                'modo', c.modo, 'rutina_activa', c.rutina_activa, 'cuenta_puente', c.cuenta_puente, 'cuenta_paso', c.cuenta_paso,
                'cuenta_banco', c.cuenta_banco,
                'por_depositar', (select coalesce(sum(v.falta_depositar), 0)::numeric(14,2) from public.v_stripe_pagos v),
                'n_por_depositar', (select count(*) filter (where v.falta_depositar <> 0) from public.v_stripe_pagos v),
                -- (las dos partes: lo cobrado que espera su depósito, y lo que Stripe descontará del siguiente —un reembolso
                --  hecho después de que su pago ya se depositó—)
                'cobrado_espera', (select coalesce(sum(v.falta_depositar) filter (where v.falta_depositar > 0), 0)::numeric(14,2)
                                     from public.v_stripe_pagos v),
                'n_cobrado_espera', (select count(*) filter (where v.falta_depositar > 0) from public.v_stripe_pagos v),
                'por_descontar', (select coalesce(-sum(v.falta_depositar) filter (where v.falta_depositar < 0), 0)::numeric(14,2)
                                    from public.v_stripe_pagos v),
                'n_por_descontar', (select count(*) filter (where v.falta_depositar < 0) from public.v_stripe_pagos v),
                'en_camino', (select coalesce(sum(s.monto), 0)::numeric(14,2) from public.stripe_pagos s where s.estado in ('iniciado', 'en_camino')),
                'n_en_camino', (select count(*) from public.stripe_pagos s where s.estado in ('iniciado', 'en_camino')),
                'enlaces_activos', (select count(*) from public.stripe_enlaces e where e.estado = 'activo'),
                'pagos_revisar', (select count(*) from public.stripe_pagos s where s.estado = 'revisar'),
                'payouts_pendientes', (select count(*) from public.stripe_payouts q
                                        where q.estado in ('en_camino', 'esperando_composicion', 'esperando_cobros', 'revisar')),
                'ultimo_evento_el', c.ultimo_evento_el, 'ultimo_barrido_el', c.ultimo_barrido_el, 'ultimo_error', c.ultimo_error,
                'ultimo_error_el', c.ultimo_error_el)
               from public.stripe_config c where c.id = 1$q$ into v;
  if v is null then
    return null;
  end if;
  execute $q$select jsonb_build_object('monto', q.monto, 'llegada', q.llegada, 'n_pagos', q.n_pagos, 'estado', q.estado_pantalla)
               from public.v_stripe_payouts q
              where q.estado = 'asentado' and q.llegada <= $1
              order by q.llegada desc, q.creado_el desc limit 1$q$ into v_u using v_hoy;
  execute $q$select coalesce(jsonb_agg(jsonb_build_object('monto', q.monto, 'llegada', q.llegada, 'n_pagos', q.n_pagos,
                                                          'estado', q.estado_pantalla) order by q.llegada nulls last), '[]'::jsonb)
               from public.v_stripe_payouts q
              where q.estado in ('en_camino', 'esperando_composicion', 'esperando_cobros')
                 or (q.estado = 'asentado' and q.llegada > $1)$q$ into v_s using v_hoy;
  return v || v_c || jsonb_build_object('ultimo_deposito', v_u, 'siguientes', v_s);
end $$;
revoke execute on function public.fn_tablero_stripe() from public, anon, service_role;
grant  execute on function public.fn_tablero_stripe() to authenticated;
comment on function public.fn_tablero_stripe() is 'c16: Stripe (p1) en una pieza: las cifras de v_stripe_estado (modo, rutina_activa, las cuentas, por_depositar y n_por_depositar —y sus dos partes: cobrado_espera y n_cobrado_espera, lo cobrado que espera su depósito; por_descontar y n_por_descontar, lo que Stripe descontará del siguiente por un reembolso de algo ya depositado—, en_camino y n_en_camino, enlaces_activos, pagos_revisar, payouts_pendientes, el último aviso, barrido y error, cuadres_rojos, alarmas) leídas de donde las lee ella, rojos (lo de su control que no está en verde: orden, control, nivel, detalle), ultimo_deposito ({monto, llegada, n_pagos, estado}) y siguientes (los depósitos que vienen). Sin la dirección de la función. Nulo sin p1. Solo el dueño.';

-- LOS SALDOS DE LOS BANCOS Y LAS TARJETAS (c6), cuenta por cuenta, para las
-- tarjetas de bancos y de acciones: v_banco_saldos (la lista de la página
-- Bancos) sin las dos cuentas de Stripe (p1: no son un banco con estado de
-- cuenta; la página Bancos las esconde), con su conexión de Plaid (c7) si
-- la tiene. EL LIBRO, A HOY (lo fechado hasta hoy, como la caja; lo que
-- tiene fecha de después —un cheque posfechado— se dice aparte) y A LA
-- FECHA DEL SALDO DEL BANCO (para compararlos el mismo día, como la página
-- Bancos). LO QUE ESPERA, contado como la Bandeja (v_banco_bandeja: lo
-- pendiente, lo que llegó su ticket y lo que el banco quitó). Nulo sin c6.
create or replace function public.fn_tablero_saldos() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy     date := fn_tablero_hoy();
  v_ocultas text[] := '{}';
  v_plaid   jsonb := '{}'::jsonb;
  v         jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if (fn_tablero_capas() ->> 'c6')::boolean is not true then
    return null;
  end if;
  if to_regclass('public.stripe_config') is not null then
    execute 'select array_remove(array[c.cuenta_puente, c.cuenta_paso], null) from public.stripe_config c where c.id = 1' into v_ocultas;
  end if;
  if to_regclass('public.plaid_conexiones') is not null then
    -- (por cuenta del plan, su conexión: la activa primero, y la sincronizada más reciente)
    execute $q$select coalesce(jsonb_object_agg(z.cuenta, z.j), '{}'::jsonb)
                 from (select distinct on (x.value ->> 'cuenta') x.value ->> 'cuenta' as cuenta,
                              jsonb_build_object('institucion', c.institucion, 'estado', c.estado, 'error', c.ultimo_error,
                                                 'ultimo_sync', c.ultimo_sync) as j
                         from public.plaid_conexiones c, jsonb_array_elements(c.cuentas) x
                        where c.estado <> 'desconectada' and x.value ->> 'cuenta' is not null
                        order by x.value ->> 'cuenta', (c.estado = 'activa') desc, c.ultimo_sync desc nulls last) z$q$ into v_plaid;
  end if;
  execute $q$
    with s as materialized (
      select x.* from public.v_banco_saldos x where not (x.cuenta = any ($1))
    ), lh as (
      -- el libro de cada cuenta hasta hoy (y lo de después de hoy)
      select l.cuenta, coalesce(sum(l.monto) filter (where a.fecha_contable <= $3), 0) as hoy,
             coalesce(sum(l.monto) filter (where a.fecha_contable > $3), 0) as despues
        from public.asiento_lineas l join public.asientos a on a.id = l.asiento_id
       where l.cuenta in (select s.cuenta from s)
       group by l.cuenta
    ), b as (
      -- lo de la Bandeja de cada cuenta (las filas de su página)
      select x.cuenta, count(*) as n, coalesce(sum(x.monto), 0) as monto, min(x.fecha) as viejo,
             count(*) filter (where x.motivo = 'llego_su_ticket') as dobles, count(*) filter (where x.motivo = 'quitada') as quitadas
        from public.v_banco_bandeja x
       group by x.cuenta
    )
    select coalesce(jsonb_agg(jsonb_build_object(
             'cuenta', s.cuenta, 'nombre', s.cuenta_nombre, 'tipo', s.tipo, 'activa', s.activa,
             'saldo_banco', s.saldo_banco_como_banco::numeric(14,2), 'saldo_banco_al', s.saldo_banco_al,
             -- (el libro como lo dice el banco: en una tarjeta, lo que se debe en positivo)
             'saldo_libro', ((case when s.tipo = 'tarjeta' then -1 else 1 end) * coalesce(lh.hoy, 0))::numeric(14,2),
             'saldo_libro_despues', ((case when s.tipo = 'tarjeta' then -1 else 1 end) * coalesce(lh.despues, 0))::numeric(14,2),
             'saldo_libro_al', case when s.saldo_banco_al is not null
                                    then ((case when s.tipo = 'tarjeta' then -1 else 1 end) * coalesce(s.saldo_libros_al, 0))::numeric(14,2) end,
             'por_revisar', coalesce(b.n, 0), 'por_revisar_monto', coalesce(b.monto, 0)::numeric(14,2), 'mas_viejo', b.viejo,
             'dobles', coalesce(b.dobles, 0), 'quitadas', coalesce(b.quitadas, 0),
             'pendiente_mas_viejo', s.pendiente_mas_viejo, 'en_transito', s.en_transito,
             'ultimo_importado_el', s.ultimo_importado_el,
             'plaid', $2 -> s.cuenta,
             'ultima_conciliacion', s.ultima_confirmada, 'dias_sin_conciliar', s.dias_sin_conciliar,
             'cubierto_hasta', s.cubierto_hasta, 'mes_sin_cubrir', s.mes_sin_cubrir,
             'alarma', s.alarma, 'alarma_tecnico', nullif(s.alarma_texto, ''))
             order by case s.tipo when 'banco' then 0 else 1 end, s.cuenta), '[]'::jsonb)
      from s
      left join lh on lh.cuenta = s.cuenta
      left join b on b.cuenta = s.cuenta$q$ into v using v_ocultas, v_plaid, v_hoy;
  return v;
end $$;
revoke execute on function public.fn_tablero_saldos() from public, anon, service_role;
grant  execute on function public.fn_tablero_saldos() to authenticated;
comment on function public.fn_tablero_saldos() is 'c16: los bancos y las tarjetas (v_banco_saldos de c6, sin las dos cuentas de Stripe), cuenta por cuenta en un jsonb: cuenta, nombre, tipo (banco | tarjeta), activa, saldo_banco y saldo_banco_al (lo que dice el banco y de qué día; en una tarjeta lo que se debe va en positivo), saldo_libro (el libro HASTA HOY), saldo_libro_despues (lo fechado después de hoy), saldo_libro_al (el libro a la fecha del saldo del banco), por_revisar, por_revisar_monto, mas_viejo, dobles y quitadas (contado como la Bandeja, v_banco_bandeja), pendiente_mas_viejo, en_transito, ultimo_importado_el, plaid ({institucion, estado, error, ultimo_sync} si va por Plaid, c7), ultima_conciliacion, dias_sin_conciliar, cubierto_hasta, mes_sin_cubrir, alarma, alarma_tecnico (el texto de c6, para soporte). Nulo sin c6. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 3. LAS TARJETAS, una función por tarjeta. Cada una contesta un jsonb con
--    «ok», su nombre («tarjeta»), su corte y todo lo que enseña ya
--    calculado, con «fuente» e «ir». Si la capa de la que sale no está, lo
--    dice (fn_tablero_no) y no es un error. Las que comparten piezas con
--    otras tienen dos funciones: la de la tarjeta (lee sus piezas) y la
--    «_de» (arma la tarjeta con las piezas que le dan; fn_tablero le pasa
--    las que ya leyó).
-- ---------------------------------------------------------------------

-- 3.1 · ACCIONES RÁPIDAS: lo que cambia de cada una (la etiqueta corta y el
-- icono son de la pantalla). p_saldos: lo de fn_tablero_saldos;
-- p_stripe: lo de fn_tablero_stripe.
create or replace function public.fn_tablero_acciones_de(p_saldos jsonb, p_stripe jsonb, p_nomina jsonb default null) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_capas jsonb := fn_tablero_capas();
  v_fin   date := date_trunc('month', fn_tablero_hoy())::date - 1;   -- el último día del mes pasado
  v_l     jsonb := '[]'::jsonb;
  v_bj    jsonb;
  r       record;
begin
  perform fn_tablero_exigir_dueno();
  -- CREAR UNA FACTURA (c11): por dónde se factura hoy
  if (v_capas ->> 'c11')::boolean then
    execute 'select e.camino, e.texto, e.borradores, e.puede_emitir, e.falta from public.v_emision_estado e' into r;
    v_l := v_l || jsonb_build_object(
      'clave', 'factura', 'texto', 'Crear una factura', 'disponible', true, 'n', coalesce(r.borradores, 0), 'camino', r.camino,
      'detalle', case when r.camino is null then 'Facturas todavía no tiene sus ajustes.'
                      when r.camino = 'app' and not coalesce(r.puede_emitir, false)
                        then 'Para emitir faltan ' || coalesce((select string_agg(case f when 'empresa' then 'los datos de la empresa'
                                                                                         when 'como_pagar' then 'cómo pagar'
                                                                                         else replace(f, '_', ' ') end, ' y ' order by o)
                                                                  from unnest(r.falta) with ordinality u(f, o)), 'unos datos')
                             || ' en Facturas → Ajustes.'
                      when r.camino = 'app' and coalesce(r.borradores, 0) > 0
                        then format('%s borrador%s por emitir.', r.borradores, case when r.borradores = 1 then '' else 'es' end)
                      when r.camino = 'app' then 'Se emite desde la app.'
                      else r.texto end,
      'alarma', false, 'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'obras'));
  else
    v_l := v_l || jsonb_build_object('clave', 'factura', 'texto', 'Crear una factura', 'disponible', false, 'falta', 'c11',
                                     'detalle', 'La facturación desde la app (c11) no está en esta base.',
                                     'ir', jsonb_build_object('pagina', 'facturas'));
  end if;
  -- LA BANDEJA y CONCILIAR (c6). (Lo que espera, contado como la página de la Bandeja: todas sus filas, de todas las cuentas.)
  if p_saldos is not null then
    v_bj := fn_tablero_por_revisar(null, null);
    select coalesce((v_bj ->> 'n')::int, 0) as n, (v_bj ->> 'mas_viejo')::date as viejo,
           count(*) filter (where (x ->> 'activa')::boolean and x ->> 'ultimo_importado_el' is not null
                              and coalesce((x ->> 'ultima_conciliacion')::date, date '1900-01-01') < v_fin) as por_conciliar,
           count(*) filter (where (x ->> 'activa')::boolean and x ->> 'ultimo_importado_el' is not null) as con_banco,
           (array_agg(x ->> 'cuenta' order by coalesce((x ->> 'ultima_conciliacion')::date, date '1900-01-01'), x ->> 'cuenta')
              filter (where (x ->> 'activa')::boolean and x ->> 'ultimo_importado_el' is not null
                        and coalesce((x ->> 'ultima_conciliacion')::date, date '1900-01-01') < v_fin))[1] as cuenta_atrasada,
           (array_agg(x ->> 'nombre' order by coalesce((x ->> 'ultima_conciliacion')::date, date '1900-01-01'), x ->> 'cuenta')
              filter (where (x ->> 'activa')::boolean and x ->> 'ultimo_importado_el' is not null
                        and coalesce((x ->> 'ultima_conciliacion')::date, date '1900-01-01') < v_fin))[1] as nombre_atrasada,
           (array_agg((x ->> 'ultima_conciliacion')::date order by coalesce((x ->> 'ultima_conciliacion')::date, date '1900-01-01'), x ->> 'cuenta')
              filter (where (x ->> 'activa')::boolean and x ->> 'ultimo_importado_el' is not null
                        and coalesce((x ->> 'ultima_conciliacion')::date, date '1900-01-01') < v_fin))[1] as conciliada_atrasada
      into r
      from jsonb_array_elements(p_saldos) x;
    v_l := v_l || jsonb_build_object(
      'clave', 'bandeja', 'texto', 'Revisar la Bandeja', 'disponible', true, 'n', r.n,
      'detalle', case when r.n = 0 then 'Nada espera.'
                      else format('%s por revisar; el más viejo, del %s.', fn_tablero_plural(r.n, 'movimiento', 'movimientos'),
                                  fn_tablero_dia(r.viejo))
                           || case when coalesce((v_bj -> 'dobles' ->> 'n')::int, 0) > 0
                                   then format(' %s dos veces en el libro (llegó su ticket).',
                                               fn_tablero_plural((v_bj -> 'dobles' ->> 'n')::int, 'gasto está', 'gastos están'))
                                   else '' end end,
      'mas_viejo', r.viejo, 'dias', v_hoy - r.viejo, 'alarma', coalesce(v_hoy - r.viejo > 30, false),
      -- (la Bandeja entera: sin el filtro de una cuenta que se haya quedado de antes)
      'ir', jsonb_build_object('pagina', 'bandeja', 'cuenta', null));
    v_l := v_l || jsonb_build_object(
      'clave', 'conciliar', 'texto', 'Conciliar', 'disponible', true, 'n', r.por_conciliar, 'hasta', v_fin,
      'detalle', case when r.con_banco = 0 then 'Ninguna cuenta trae todavía lo del banco (Plaid o un archivo).'
                      when r.por_conciliar = 0 then format('Todo conciliado hasta el %s.', fn_tablero_dia(v_fin))
                      else format('%s cuenta%s por conciliar hasta el %s (la más atrasada: %s, %s).', r.por_conciliar,
                                  case when r.por_conciliar = 1 then '' else 's' end, fn_tablero_dia(v_fin), r.nombre_atrasada,
                                  coalesce('conciliada al ' || fn_tablero_dia(r.conciliada_atrasada), 'sin ninguna conciliación')) end,
      'alarma', r.por_conciliar > 0 and v_hoy - v_fin > 15,
      'ir', jsonb_strip_nulls(jsonb_build_object('pagina', 'conciliar', 'cuenta', r.cuenta_atrasada)));
  else
    v_l := v_l || jsonb_build_object('clave', 'bandeja', 'texto', 'Revisar la Bandeja', 'disponible', false, 'falta', 'c6',
                                     'detalle', 'El banco (c6) no está en esta base.', 'ir', jsonb_build_object('pagina', 'bandeja'))
               || jsonb_build_object('clave', 'conciliar', 'texto', 'Conciliar', 'disponible', false, 'falta', 'c6',
                                     'detalle', 'El banco (c6) no está en esta base.', 'ir', jsonb_build_object('pagina', 'conciliar'));
  end if;
  -- PEDIR UN PAGO EN LÍNEA (p1)
  if p_stripe is not null then
    v_l := v_l || jsonb_build_object(
      'clave', 'pago', 'texto', 'Pedir un pago en línea', 'disponible', true, 'n', coalesce((p_stripe ->> 'enlaces_activos')::int, 0),
      'detalle', case when coalesce((p_stripe ->> 'enlaces_activos')::int, 0) = 0
                      then 'Ningún enlace de pago activo: se crea desde la factura, en Cobros en línea.'
                      else format('%s enlace%s de pago activo%s.', p_stripe ->> 'enlaces_activos',
                                  case when (p_stripe ->> 'enlaces_activos')::int = 1 then '' else 's' end,
                                  case when (p_stripe ->> 'enlaces_activos')::int = 1 then '' else 's' end) end,
      'alarma', false, 'ir', jsonb_build_object('pagina', 'cobros'));
  else
    v_l := v_l || jsonb_build_object('clave', 'pago', 'texto', 'Pedir un pago en línea', 'disponible', false, 'falta', 'p1',
                                     'detalle', 'Los cobros en línea (p1) no están en esta base.', 'ir', jsonb_build_object('pagina', 'cobros'));
  end if;
  -- (14-nov, Fase 11c) LA NÓMINA (c15): las nóminas por postear (con el código) y los cargos de Gusto que esperan casarse
  if p_nomina is not null then
    v_l := v_l || jsonb_build_object(
      'clave', 'nomina', 'texto', 'Nómina', 'disponible', true,
      'n', coalesce((p_nomina -> 'por_postear' ->> 'n')::int, 0) + coalesce((p_nomina -> 'cargos' ->> 'n')::int, 0)
           + coalesce((p_nomina -> 'cargos' ->> 'descasados')::int, 0),
      'detalle', concat_ws(' ',
                   case when p_nomina -> 'por_postear' is null or jsonb_typeof(p_nomina -> 'por_postear') = 'null'
                          then 'Las nóminas por postear se ven con el código del teléfono.'
                        when (p_nomina -> 'por_postear' ->> 'n')::int > 0
                          then format('%s por postear.', fn_tablero_plural((p_nomina -> 'por_postear' ->> 'n')::int, 'nómina', 'nóminas')) end,
                   case when (p_nomina -> 'cargos' ->> 'n')::int > 0
                          then format('%s de Gusto por casar; el más viejo, del %s.', fn_tablero_plural((p_nomina -> 'cargos' ->> 'n')::int, 'cargo', 'cargos'),
                                      fn_tablero_dia((p_nomina -> 'cargos' ->> 'mas_viejo')::date)) end,
                   case when coalesce((p_nomina -> 'cargos' ->> 'descasados')::int, 0) > 0
                          then format('%s des-casado en la Bandeja.', fn_tablero_plural((p_nomina -> 'cargos' ->> 'descasados')::int, 'cargo', 'cargos')) end,
                   case when coalesce((p_nomina -> 'control' ->> 'cuadres_rojos')::int, 0) > 0
                          then format('%s de la nómina en rojo.', fn_tablero_plural((p_nomina -> 'control' ->> 'cuadres_rojos')::int, 'cuadre', 'cuadres')) end,
                   case when coalesce((p_nomina -> 'por_postear' ->> 'n')::int, 0) + coalesce((p_nomina -> 'cargos' ->> 'n')::int, 0)
                             + coalesce((p_nomina -> 'cargos' ->> 'descasados')::int, 0) + coalesce((p_nomina -> 'control' ->> 'cuadres_rojos')::int, 0) = 0
                             and p_nomina -> 'por_postear' is not null and jsonb_typeof(p_nomina -> 'por_postear') <> 'null'
                          then 'Nada espera.' end),
      'alarma', coalesce((p_nomina -> 'control' ->> 'cuadres_rojos')::int, 0) > 0 or coalesce((p_nomina -> 'por_postear' ->> 'n')::int, 0) > 0
                or coalesce((p_nomina -> 'cargos' ->> 'dias')::int, 0) > 5 or coalesce((p_nomina -> 'cargos' ->> 'descasados')::int, 0) > 0,
      'con_codigo', coalesce((p_nomina ->> 'con_codigo')::boolean, false),
      'ir', jsonb_build_object('pagina', 'nomina', 'sub', case when coalesce((p_nomina -> 'por_postear' ->> 'n')::int, 0) = 0
                                                                  and coalesce((p_nomina -> 'cargos' ->> 'n')::int, 0)
                                                                      + coalesce((p_nomina -> 'cargos' ->> 'descasados')::int, 0) > 0
                                                               then 'cargos' else 'nominas' end));
  else
    v_l := v_l || jsonb_build_object('clave', 'nomina', 'texto', 'Nómina', 'disponible', false, 'falta', 'c15',
                                     'detalle', 'La nómina con Gusto (c15) no está en esta base.', 'ir', jsonb_build_object('pagina', 'nomina'));
  end if;
  -- CERRAR EL MES (c9): el período que toca
  if (v_capas ->> 'c9')::boolean then
    execute 'select e.periodo, e.nombre, e.terminado, e.detienen, e.avisos, e.revisado_el, e.hasta
               from public.v_cierre_estado e where e.siguiente order by e.desde limit 1' into r;
    v_l := v_l || jsonb_build_object(
      'clave', 'cierre', 'texto', 'Cerrar el mes', 'disponible', true, 'n', coalesce(r.detienen, 0), 'periodo', r.periodo,
      'terminado', r.terminado,
      'detalle', case when r.periodo is null then 'No hay ningún período por cerrar.'
                      when not r.terminado then format('Toca %s, que termina el %s.', r.nombre, fn_tablero_dia(r.hasta))
                      when r.revisado_el is null then format('Toca %s: todavía sin revisar.', r.nombre)
                      when coalesce(r.detienen, 0) = 0 then format('Toca %s: nada lo detiene, se puede cerrar.', r.nombre)
                      else format('Toca %s: %s cosa%s por resolver antes de cerrar.', r.nombre, r.detienen,
                                  case when r.detienen = 1 then '' else 's' end) end,
      'alarma', coalesce(r.terminado and v_hoy - r.hasta > 20, false),
      'ir', jsonb_strip_nulls(jsonb_build_object('pagina', 'cierre', 'sub', 'cierre', 'periodo', r.periodo)));
  else
    v_l := v_l || jsonb_build_object('clave', 'cierre', 'texto', 'Cerrar el mes', 'disponible', false, 'falta', 'c9',
                                     'detalle', 'El cierre del mes (c9) no está en esta base.', 'ir', jsonb_build_object('pagina', 'cierre'));
  end if;
  -- LOS ESTADOS FINANCIEROS (c4)
  v_l := v_l || jsonb_build_object('clave', 'estados', 'texto', 'Estados financieros', 'disponible', true,
                                   'detalle', 'Resultados, balance, balanza y flujo de caja, del libro.', 'alarma', false,
                                   'ir', jsonb_build_object('pagina', 'estados', 'sub', 'resultados'));
  return jsonb_build_object('ok', true, 'tarjeta', 'acciones', 'corte', v_hoy, 'lista', v_l,
                            'fuente', 'Facturas (c11), la Bandeja y las conciliaciones (c6), los enlaces de pago (p1), la nómina (c15), el cierre (c9) y los estados (c4)');
end $$;
revoke execute on function public.fn_tablero_acciones_de(jsonb, jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero_acciones_de(jsonb, jsonb, jsonb) to authenticated;
comment on function public.fn_tablero_acciones_de(jsonb, jsonb, jsonb) is 'c16: arma la fila de acciones rápidas con los saldos de los bancos, Stripe y lo que espera de la nómina ya leídos (los de fn_tablero_saldos, fn_tablero_stripe y fn_tablero_nomina_estado; nulos si su capa no está). La tarjeta es fn_tablero_acciones. Solo el dueño.';

create or replace function public.fn_tablero_acciones() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_tablero_exigir_dueno();
  return fn_tablero_acciones_de(fn_tablero_saldos(), fn_tablero_stripe(), fn_tablero_nomina_estado());
end $$;
revoke execute on function public.fn_tablero_acciones() from public, anon, service_role;
grant  execute on function public.fn_tablero_acciones() to authenticated;
comment on function public.fn_tablero_acciones() is 'c16: la fila de acciones rápidas: {ok, tarjeta: «acciones», corte, lista: [{clave (factura | bandeja | conciliar | pago | nomina | cierre | estados), texto, disponible, n (borradores; movimientos por revisar; cuentas por conciliar; enlaces activos; nóminas por postear y cargos de Gusto por casar —sin el código, solo los cargos—; cosas que detienen el cierre), detalle (en llano), alarma, camino? (factura: app | quickbooks), mas_viejo? y dias? (bandeja), hasta? (conciliar: el fin del mes pasado), periodo? y terminado? (cierre), falta? (la capa que no está), ir: {pagina, sub?, cuenta?, periodo?}}], fuente}. Solo lee. Solo el dueño.';

-- 3.2 · EL EMBUDO DE COBRO: por cobrar → cobrado en los últimos N días →
-- depositado. p_cxc: las partidas de fn_tablero_cxc (jsonb); p_cobrado: lo
-- de fn_tablero_cobrado.
create or replace function public.fn_tablero_cobros_de(p_cxc jsonb, p_cobrado jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_libro numeric;
  v_dep   jsonb := p_cobrado -> 'depositado';
  r       record;
begin
  perform fn_tablero_exigir_dueno();
  select coalesce(sum(x.por_cobrar) filter (where x.por_cobrar > 0), 0)::numeric(14,2) as monto,
         count(*) filter (where x.por_cobrar > 0) as n,
         count(*) filter (where x.por_cobrar > 0 and x.tipo = 'factura') as facturas,
         coalesce(sum(x.por_cobrar) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)::numeric(14,2) as vencido,
         count(*) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')) as n_vencido,
         count(*) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas') and x.tipo = 'factura') as f_vencidas,
         max(x.dias_vencida) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')) as dias_mas_vieja,
         coalesce(sum(x.por_cobrar) filter (where x.tramo = 'corriente'), 0)::numeric(14,2) as por_vencer,
         count(*) filter (where x.tramo = 'corriente') as n_por_vencer,
         coalesce(sum(x.por_cobrar) filter (where x.tramo = 'sin_vencimiento'), 0)::numeric(14,2) as sin_vence,
         count(*) filter (where x.tramo = 'sin_vencimiento') as n_sin_vence,
         coalesce(sum(x.retencion), 0)::numeric(14,2) as retencion, count(*) filter (where x.retencion <> 0) as n_retencion,
         coalesce(sum(x.por_cobrar) filter (where x.por_cobrar < 0), 0)::numeric(14,2) as a_favor,
         count(*) filter (where x.por_cobrar < 0) as n_a_favor
    into r
    from jsonb_to_recordset(coalesce(p_cxc, '[]'::jsonb))
         as x(tipo text, por_cobrar numeric, retencion numeric, dias_vencida int, tramo text);
  v_libro := fn_tablero_saldo((select array_agg(pc.cuenta) from puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc')), v_hoy);
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'cobros', 'corte', v_hoy,
    'dias', p_cobrado -> 'dias', 'desde', p_cobrado -> 'desde', 'hasta', p_cobrado -> 'hasta',
    'por_cobrar', jsonb_build_object(
        'monto', r.monto, 'n', r.n, 'facturas', r.facturas,
        'vencidas', jsonb_build_object('monto', r.vencido, 'n', r.n_vencido, 'facturas', r.f_vencidas, 'dias_mas_vieja', r.dias_mas_vieja),
        'por_vencer', jsonb_build_object('monto', r.por_vencer, 'n', r.n_por_vencer),
        'sin_vencimiento', jsonb_build_object('monto', r.sin_vence, 'n', r.n_sin_vence),
        'retencion', jsonb_build_object('monto', r.retencion, 'n', r.n_retencion),
        'a_favor', jsonb_build_object('monto', r.a_favor, 'n', r.n_a_favor),
        'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'facturas')),
    'cobrado', jsonb_build_object('monto', p_cobrado -> 'monto', 'n', p_cobrado -> 'n', 'facturas', p_cobrado -> 'facturas',
                                  'a_facturas', p_cobrado -> 'a_facturas', 'anticipos', p_cobrado -> 'anticipos',
                                  'devuelto', p_cobrado -> 'devuelto', 'devuelto_antes', p_cobrado -> 'devuelto_antes',
                                  'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'facturas')),
    'depositado', case when v_dep is not null and v_dep <> 'null'::jsonb
                       then v_dep || jsonb_build_object('ir', jsonb_build_object('pagina', 'movimientos')) end,
    'sin_depositar', case when p_cobrado -> 'sin_depositar' is not null and p_cobrado -> 'sin_depositar' <> 'null'::jsonb
                          then (p_cobrado -> 'sin_depositar') || jsonb_build_object('ir', jsonb_build_object('pagina', 'conciliar')) end,
    -- los tres pasos del embudo, listos para pintar
    'pasos', jsonb_build_array(
        -- (los detalles van sin punto final: la pantalla los pinta como píldoras)
        jsonb_build_object('clave', 'por_cobrar', 'etiqueta', 'Por cobrar', 'monto', r.monto, 'n', r.n,
                           'detalle', case when r.n = 0 then 'Nada por cobrar'
                                           when r.n_vencido = 0 then 'Ninguna vencida'
                                           else fn_tablero_plural(r.n_vencido, 'vencida', 'vencidas') end,
                           'alarma', r.n_vencido > 0, 'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'facturas')),
        jsonb_build_object('clave', 'cobrado', 'etiqueta', 'Cobrado', 'monto', p_cobrado -> 'monto', 'n', p_cobrado -> 'n',
                           'detalle', fn_tablero_plural((p_cobrado ->> 'n')::int, 'cobro', 'cobros')
                                      || ' en los últimos ' || (p_cobrado ->> 'dias') || ' días',
                           'alarma', false, 'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'facturas')),
        jsonb_build_object('clave', 'depositado', 'etiqueta', 'Depositado',
                           'monto', case when v_dep is not null and v_dep <> 'null'::jsonb then v_dep -> 'monto' end,
                           'n', case when v_dep is not null and v_dep <> 'null'::jsonb then v_dep -> 'n' end,
                           'detalle', case when v_dep is null or v_dep = 'null'::jsonb then 'Sin el banco (c6) no se sabe'
                                           when (p_cobrado -> 'sin_depositar' ->> 'monto')::numeric = 0 then 'Todo lo cobrado está en el banco'
                                           else fn_tablero_usd((p_cobrado -> 'sin_depositar' ->> 'monto')::numeric)
                                                || ' cobrado todavía no está en el banco' end,
                           'alarma', false, 'ir', jsonb_build_object('pagina', 'movimientos'))),
    'cuadre', jsonb_build_object('ok', (r.monto + r.a_favor + r.retencion) = v_libro, 'libro', v_libro,
                                 'suma', (r.monto + r.a_favor + r.retencion)::numeric(14,2),
                                 'texto', 'por cobrar + retención + anticipos y saldos a favor = el saldo de las cuentas por cobrar en el libro'),
    'nota', p_cobrado -> 'nota',
    'fuente', 'por cobrar: lo abierto de cada factura y anticipo en las cuentas por cobrar del libro (la antigüedad de c4), vencido según su '
              || 'vencimiento; cobrado y depositado: ' || (p_cobrado ->> 'fuente'),
    'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'facturas'));
end $$;
revoke execute on function public.fn_tablero_cobros_de(jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero_cobros_de(jsonb, jsonb) to authenticated;
comment on function public.fn_tablero_cobros_de(jsonb, jsonb) is 'c16: arma el embudo de cobro con las partidas por cobrar (las de fn_tablero_cxc, en jsonb) y lo cobrado (lo de fn_tablero_cobrado). La tarjeta es fn_tablero_cobros. Solo el dueño.';

create or replace function public.fn_tablero_cobros(p_dias int default 30) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy  date := fn_tablero_hoy();
  v_dias int := coalesce(p_dias, 30);
begin
  perform fn_tablero_exigir_dueno();
  if v_dias < 1 or v_dias > 366 then
    raise exception using errcode = '22023', message = format('Los días van de 1 a 366 (llegó %s).', v_dias);
  end if;
  return fn_tablero_cobros_de(
    (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from fn_tablero_cxc() x),
    fn_tablero_cobrado((select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from fn_tablero_cobros_lista(v_hoy - (v_dias - 1), v_hoy) x),
                       v_hoy - (v_dias - 1), v_hoy));
end $$;
revoke execute on function public.fn_tablero_cobros(int) from public, anon, service_role;
grant  execute on function public.fn_tablero_cobros(int) to authenticated;
comment on function public.fn_tablero_cobros(int) is 'c16: el embudo de cobro de los últimos N días (de fábrica 30): {ok, tarjeta: «cobros», corte, dias, desde, hasta, por_cobrar: {monto, n (partidas), facturas, vencidas: {monto, n, facturas, dias_mas_vieja}, por_vencer: {monto, n}, sin_vencimiento: {monto, n}, retencion: {monto, n} (aparte: se cobra al terminar la obra), a_favor: {monto, n} (anticipos y saldos a favor, en negativo), ir}, cobrado: {monto, n (cobros), facturas, a_facturas, anticipos, devuelto: {monto, n} (de los cobros de estos días: ya restado), devuelto_antes: {monto, n} (de cobros de antes: no se resta; nulo si no hay), ir}, depositado: {monto, n, ir} (nulo sin c6), sin_depositar: {monto, n, sin_casar, en_camino, en_stripe, en_caja (cada uno {monto, n}), ir} (nulo sin c6), pasos: [{clave (por_cobrar | cobrado | depositado), etiqueta, monto, n, detalle, alarma, ir}] (los tres del embudo), cuadre: {ok, libro, suma, texto} (por cobrar + retención + a favor = 1110 + 1120 en el libro), nota, fuente, ir}. 22023 con días fuera de 1–366. Solo lee. Solo el dueño.';

-- 3.3 · BANCOS Y TARJETAS: cada cuenta con lo que dice el banco, lo que
-- dice el libro, lo que espera en la Bandeja y cuándo se actualizó.
-- p_saldos: lo de fn_tablero_saldos.
create or replace function public.fn_tablero_bancos_de(p_saldos jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy date := fn_tablero_hoy();
  r     record;
begin
  perform fn_tablero_exigir_dueno();
  if p_saldos is null then
    return fn_tablero_no('bancos', 'El banco (c6) no está en esta base: los saldos de los bancos y las tarjetas se llevan ahí.', 'c6');
  end if;
  with x as (
    select (e ->> 'cuenta') as cuenta, (e ->> 'nombre') as nombre, (e ->> 'tipo') as tipo, (e ->> 'activa')::boolean as activa,
           (e ->> 'saldo_banco')::numeric as saldo_banco, (e ->> 'saldo_banco_al')::date as saldo_banco_al,
           (e ->> 'saldo_libro')::numeric as saldo_libro, coalesce((e ->> 'saldo_libro_despues')::numeric, 0) as despues,
           (e ->> 'saldo_libro_al')::numeric as saldo_libro_al,
           (e ->> 'por_revisar')::int as por_revisar, (e ->> 'por_revisar_monto')::numeric as por_revisar_monto,
           (e ->> 'mas_viejo')::date as mas_viejo, coalesce((e ->> 'dobles')::int, 0) as dobles,
           coalesce((e ->> 'quitadas')::int, 0) as quitadas, (e ->> 'pendiente_mas_viejo')::date as pendiente_mas_viejo,
           (e ->> 'en_transito')::int as en_transito,
           greatest((e ->> 'ultimo_importado_el')::timestamptz, (e -> 'plaid' ->> 'ultimo_sync')::timestamptz) as actualizado_el,
           case when e -> 'plaid' is not null and e -> 'plaid' <> 'null'::jsonb then 'plaid'
                when e ->> 'ultimo_importado_el' is not null then 'archivo' end as via,
           nullif(e -> 'plaid', 'null'::jsonb) as plaid,
           (e ->> 'ultima_conciliacion')::date as ultima_conciliacion, (e ->> 'dias_sin_conciliar')::int as dias_sin_conciliar,
           (e ->> 'cubierto_hasta')::date as cubierto_hasta, e ->> 'mes_sin_cubrir' as mes_sin_cubrir,
           coalesce((e ->> 'alarma')::boolean, false) as alarma, e ->> 'alarma_tecnico' as alarma_tecnico
      from jsonb_array_elements(p_saldos) e
  ), v as (
    select x.*,
           -- (lo que dice la alarma de c6, en llano y con las fechas como se dicen: sus mismas reglas)
           nullif(concat_ws(' ',
             case when v_hoy - x.pendiente_mas_viejo > 30
                  then format('Hay movimientos esperando en la Bandeja desde el %s (más de 30 días).', fn_tablero_dia(x.pendiente_mas_viejo)) end,
             case when x.dias_sin_conciliar > 45
                  then case when x.ultima_conciliacion is null then format('Sin conciliar desde que empezó el libro (hace %s).',
                                                                           fn_tablero_plural(x.dias_sin_conciliar, 'día', 'días'))
                            else format('Conciliada por última vez al %s (hace %s).', fn_tablero_dia(x.ultima_conciliacion),
                                        fn_tablero_plural(x.dias_sin_conciliar, 'día', 'días')) end end,
             case when x.mes_sin_cubrir is not null
                  then format('Lo que trajo el banco llega hasta el %s y %s ya terminó: falta traer lo de esta cuenta hasta el %s antes de cerrar el mes.',
                              fn_tablero_dia(x.cubierto_hasta), fn_tablero_mes_largo(to_date(x.mes_sin_cubrir || '-01', 'YYYY-MM-DD')),
                              fn_tablero_dia((to_date(x.mes_sin_cubrir || '-01', 'YYYY-MM-DD') + interval '1 month')::date - 1)) end), '') as alarma_texto,
           -- (la conexión de Plaid, en llano: lo que pide; el código del banco, aparte, para soporte)
           case when x.plaid is not null then jsonb_build_object(
                  'institucion', x.plaid ->> 'institucion', 'estado', x.plaid ->> 'estado', 'ultimo_sync', x.plaid -> 'ultimo_sync',
                  'texto', case when x.plaid ->> 'estado' = 'error'
                                  then coalesce(x.plaid ->> 'institucion', 'El banco')
                                       || case when coalesce(x.plaid ->> 'error', '') ~* 'ITEM_LOGIN_REQUIRED|login|credencial|contraseña'
                                               then ' pide volver a entrar: en Conexiones se vuelve a conectar.'
                                               else ' no deja traer los movimientos: en Conexiones se vuelve a conectar.' end
                                when x.plaid ->> 'ultimo_sync' is null then 'Conectada; todavía no ha traído movimientos.'
                                when now() - (x.plaid ->> 'ultimo_sync')::timestamptz > interval '48 hours'
                                  then format('No trae nada desde %s (lo trae cada mañana): mira Conexiones.',
                                              fn_tablero_hace((x.plaid ->> 'ultimo_sync')::timestamptz))
                                else 'Al día.' end,
                  'tecnico', x.plaid ->> 'error') end as conexion
      from x
     where x.activa or x.saldo_libro <> 0 or x.despues <> 0 or x.por_revisar > 0 or x.saldo_banco <> 0
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'cuenta', v.cuenta, 'nombre', v.nombre, 'tipo', v.tipo, 'activa', v.activa,
           -- LO QUE DICE EL BANCO y de qué día («hoy» o «al 31-oct-2026»)
           'saldo_banco', v.saldo_banco, 'saldo_banco_al', v.saldo_banco_al,
           'saldo_banco_dias', v_hoy - v.saldo_banco_al,
           'saldo_banco_texto', case when v.saldo_banco_al is null then null
                                     when v.saldo_banco_al >= v_hoy then 'hoy'
                                     else 'al ' || fn_tablero_dia(v.saldo_banco_al) end,
           -- LO QUE DICE EL LIBRO, a hoy (y lo fechado después, aparte)
           'saldo_libro', v.saldo_libro::numeric(14,2),
           'posfechado', case when v.despues <> 0
                              then jsonb_build_object('monto', v.despues::numeric(14,2),
                                     'texto', case when v.tipo = 'banco' and v.despues < 0
                                                     then format('Además salen %s con fecha de después de hoy (un cheque posfechado, un pago programado): no van en el saldo de hoy.',
                                                                 fn_tablero_usd(-v.despues))
                                                   when v.tipo = 'banco'
                                                     then format('Además entran %s con fecha de después de hoy: no van en el saldo de hoy.', fn_tablero_usd(v.despues))
                                                   else format('Además hay %s de cargos o pagos con fecha de después de hoy: no van en lo que se debe hoy.',
                                                               fn_tablero_usd(abs(v.despues))) end) end,
           -- LA DIFERENCIA, el mismo día: el banco contra el libro a la fecha del saldo del banco (como la página Bancos)
           'saldo_libro_al', v.saldo_libro_al::numeric(14,2),
           'diferencia', case when v.saldo_banco is not null and v.saldo_libro_al is not null then (v.saldo_banco - v.saldo_libro_al)::numeric(14,2) end,
           'diferencia_al', v.saldo_banco_al,
           'por_revisar', v.por_revisar, 'por_revisar_monto', v.por_revisar_monto, 'mas_viejo', v.mas_viejo,
           'dias_mas_viejo', v_hoy - v.mas_viejo, 'dobles', v.dobles, 'quitadas', v.quitadas, 'en_transito', v.en_transito,
           'actualizado_el', v.actualizado_el,
           'horas', case when v.actualizado_el is not null then floor(extract(epoch from now() - v.actualizado_el) / 3600)::int end,
           'dias', case when v.actualizado_el is not null then floor(extract(epoch from now() - v.actualizado_el) / 86400)::int end,
           'actualizado_texto', fn_tablero_hace(v.actualizado_el),
           'via', v.via, 'conexion', v.conexion,
           'ultima_conciliacion', v.ultima_conciliacion, 'dias_sin_conciliar', v.dias_sin_conciliar,
           'alarma', v.alarma or coalesce(v.conexion ->> 'estado' = 'error', false), 'alarma_texto', v.alarma_texto,
           'alarma_tecnico', v.alarma_tecnico,
           'ir', jsonb_build_object('pagina', 'bandeja', 'cuenta', v.cuenta),
           'ir_conciliar', jsonb_build_object('pagina', 'conciliar', 'cuenta', v.cuenta),
           'ir_movimientos', jsonb_build_object('pagina', 'movimientos', 'cuenta', v.cuenta))
           order by case v.tipo when 'banco' then 0 else 1 end, v.cuenta), '[]'::jsonb) as lista,
         count(*) filter (where v.tipo = 'banco') as n_b,
         coalesce(sum(v.saldo_libro) filter (where v.tipo = 'banco'), 0)::numeric(14,2) as b_libro,
         count(*) filter (where v.tipo = 'banco' and v.saldo_banco is not null) as n_b_banco,
         coalesce(sum(v.saldo_banco) filter (where v.tipo = 'banco'), 0)::numeric(14,2) as b_banco,
         count(distinct v.saldo_banco_al) filter (where v.tipo = 'banco' and v.saldo_banco is not null) as b_dias,
         max(v.saldo_banco_al) filter (where v.tipo = 'banco' and v.saldo_banco is not null) as b_al,
         count(*) filter (where v.tipo = 'tarjeta') as n_t,
         coalesce(sum(v.saldo_libro) filter (where v.tipo = 'tarjeta'), 0)::numeric(14,2) as t_libro,
         count(*) filter (where v.tipo = 'tarjeta' and v.saldo_banco is not null) as n_t_banco,
         coalesce(sum(v.saldo_banco) filter (where v.tipo = 'tarjeta'), 0)::numeric(14,2) as t_banco,
         count(distinct v.saldo_banco_al) filter (where v.tipo = 'tarjeta' and v.saldo_banco is not null) as t_dias,
         max(v.saldo_banco_al) filter (where v.tipo = 'tarjeta' and v.saldo_banco is not null) as t_al,
         coalesce(sum(v.por_revisar), 0) as pend, coalesce(sum(v.por_revisar_monto), 0)::numeric(14,2) as pend_monto,
         coalesce(sum(v.dobles), 0) as dobles, coalesce(sum(v.quitadas), 0) as quitadas,
         coalesce(sum(v.despues) filter (where v.tipo = 'banco'), 0)::numeric(14,2) as b_despues,
         min(v.mas_viejo) as viejo, count(*) filter (where v.alarma or coalesce(v.conexion ->> 'estado' = 'error', false)) as alarmas,
         max(v.actualizado_el) as actualizado
    into r
    from v;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'bancos', 'corte', v_hoy, 'actualizado_el', r.actualizado, 'actualizado_texto', fn_tablero_hace(r.actualizado),
    'cuentas', r.lista,
    -- (LO QUE DICE EL BANCO, SUMADO, solo si todas las cuentas que lo traen lo dicen DEL MISMO DÍA: sumar el saldo de hoy de una
    --  tarjeta con el del 31-oct de otra da una cifra que el banco nunca dijo. Si son de días distintos, sin total —cada cuenta
    --  dice el suyo y su día— y banco_texto lo dice. La revisión final.)
    'totales', jsonb_build_object(
        'bancos', jsonb_build_object('n', r.n_b, 'libro', r.b_libro, 'con_banco', r.n_b_banco,
                                     'banco', case when r.n_b_banco > 0 and r.b_dias = 1 then r.b_banco end,
                                     'banco_al', case when r.n_b_banco > 0 and r.b_dias = 1 then r.b_al end,
                                     'banco_texto', case when r.b_dias > 1 then 'de días distintos (cada cuenta dice el suyo, abajo)' end),
        'tarjetas', jsonb_build_object('n', r.n_t, 'libro', r.t_libro, 'con_banco', r.n_t_banco,
                                       'banco', case when r.n_t_banco > 0 and r.t_dias = 1 then r.t_banco end,
                                       'banco_al', case when r.n_t_banco > 0 and r.t_dias = 1 then r.t_al end,
                                       'banco_texto', case when r.t_dias > 1 then 'de días distintos (cada cuenta dice el suyo, abajo)' end),
        'por_revisar', jsonb_build_object('n', r.pend, 'monto', r.pend_monto, 'mas_viejo', r.viejo, 'dias', v_hoy - r.viejo,
                                          'dobles', r.dobles, 'quitadas', r.quitadas,
                                          'alarma', coalesce(v_hoy - r.viejo > 30, false)),
        'alarmas', r.alarmas),
    'nota', concat_ws(' ',
              'El libro, a hoy; lo del banco, del día que dice cada cuenta. La diferencia compara los dos el mismo día.',
              case when r.b_despues < 0
                   then format('De los bancos salen %s con fecha de después de hoy: no van en el saldo de hoy.', fn_tablero_usd(-r.b_despues))
                   when r.b_despues > 0
                   then format('A los bancos entran %s con fecha de después de hoy: no van en el saldo de hoy.', fn_tablero_usd(r.b_despues)) end),
    'fuente', 'la lista de la página Bancos (c6): el saldo según el banco es el del último archivo o lote de Plaid que '
              'trajo saldo (y de qué día); el del libro, la suma de la cuenta hasta hoy; en las tarjetas, lo que se debe va en positivo',
    'ir', jsonb_build_object('pagina', 'bancos'),
    -- (la Bandeja entera: sin el filtro de una cuenta que se haya quedado de antes)
    'ir_bandeja', jsonb_build_object('pagina', 'bandeja', 'cuenta', null),
    'ir_conciliar', jsonb_build_object('pagina', 'conciliar'));
end $$;
revoke execute on function public.fn_tablero_bancos_de(jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero_bancos_de(jsonb) to authenticated;
comment on function public.fn_tablero_bancos_de(jsonb) is 'c16: arma la tarjeta de bancos y tarjetas con lo de fn_tablero_saldos (nulo sin c6). La tarjeta es fn_tablero_bancos. Solo el dueño.';

create or replace function public.fn_tablero_bancos() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_tablero_exigir_dueno();
  return fn_tablero_bancos_de(fn_tablero_saldos());
end $$;
revoke execute on function public.fn_tablero_bancos() from public, anon, service_role;
grant  execute on function public.fn_tablero_bancos() to authenticated;
comment on function public.fn_tablero_bancos() is 'c16: bancos y tarjetas (v_banco_saldos de c6, sin las dos cuentas de Stripe; las inactivas solo si tienen saldo o algo por revisar): {ok, tarjeta: «bancos», corte, actualizado_el y actualizado_texto (lo más reciente), cuentas: [{cuenta, nombre, tipo (banco | tarjeta), activa, saldo_banco y saldo_banco_al (lo que dice el banco y de qué día; nulo sin archivo ni Plaid; en una tarjeta, lo que se debe en positivo), saldo_banco_dias (cuántos días tiene), saldo_banco_texto («hoy» o «al 31-oct-2026»: se pinta junto al saldo del banco), saldo_libro (el libro HASTA HOY), posfechado: {monto, texto} (lo de después de hoy; nulo si no hay), saldo_libro_al (el libro a la fecha del saldo del banco), diferencia (banco − libro, EL MISMO DÍA: saldo_banco − saldo_libro_al), diferencia_al, por_revisar (las filas de la Bandeja de esa cuenta), por_revisar_monto, mas_viejo, dias_mas_viejo, dobles (llegó su ticket), quitadas, en_transito, actualizado_el, horas, dias, actualizado_texto («hace 5 horas», «hace 3 días»), via (plaid | archivo), conexion: {institucion, estado, ultimo_sync, texto (en llano: qué pide), tecnico (lo que dijo Plaid, para soporte)} (Plaid, c7), ultima_conciliacion, dias_sin_conciliar, alarma, alarma_texto (en llano, con las fechas como se dicen), alarma_tecnico (el de c6, para soporte), ir (la Bandeja de esa cuenta), ir_conciliar, ir_movimientos}], totales: {bancos: {n, libro, con_banco, banco (lo que dicen los bancos, sumado: solo si todos lo dicen del mismo día; si no, nulo), banco_al (ese día), banco_texto (por qué no hay suma: de días distintos)}, tarjetas: {n, libro, con_banco, banco, banco_al, banco_texto}, por_revisar: {n, monto, mas_viejo, dias, dobles, quitadas, alarma}, alarmas}, nota, fuente, ir, ir_bandeja (la Bandeja entera: cuenta nula), ir_conciliar}. Sin c6: {ok: false, falta: «c6»}. Solo lee. Solo el dueño.';


-- 3.4 · EL RESULTADO de un período, contra el anterior.
--   p_periodo: 'mes' (el de hoy; de fábrica), 'mes_pasado', 'anio' (el de
--   hoy) o 'anio_pasado'; o p_desde y p_hasta (las dos). El período va
--   contado HASTA HOY si todavía no termina (lo que tenga fecha de después
--   se dice aparte y no se cuenta).
--   EL ANTERIOR: de un período de meses enteros, los meses de antes (de
--   noviembre, octubre; del año, el año pasado); si el período va a medias,
--   los MISMOS DÍAS del anterior (del 1 al 12 de noviembre contra el 1 al 12
--   de octubre: comparar medio mes con un mes entero engaña). De un rango
--   cualquiera, los mismos días justo antes. Si el anterior empieza antes
--   del libro, no hay comparación (y se dice: vive en QuickBooks).
create or replace function public.fn_tablero_resultados(p_desde date default null, p_hasta date default null, p_periodo text default null)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy      date := fn_tablero_hoy();
  v_libro    date;
  v_per      text := lower(btrim(coalesce(p_periodo, '')));
  v_desde    date;
  v_hasta    date;
  v_al       date;
  v_etq      text;
  v_meses    int;
  v_alineado boolean;
  v_en_curso boolean;
  a_desde    date;
  a_hasta    date;
  a_etq      text;
  v_comp     boolean;
  v_r        jsonb;
  v_a        jsonb;
  v_d        jsonb;
  v_rev      jsonb;
  v_etqs     jsonb;
  v_filas    jsonb;
  v_w        jsonb;
  v_tit      text;
begin
  perform fn_tablero_exigir_dueno();
  v_libro := (fn_tablero_libro() ->> 'desde')::date;
  if v_per <> '' and (p_desde is not null or p_hasta is not null) then
    raise exception using errcode = '22023',
      message = 'Se pide un período por su nombre (p_periodo) o por sus fechas (p_desde y p_hasta), no las dos cosas.';
  end if;
  if v_per = '' and p_desde is null and p_hasta is null then
    v_per := 'mes';
  end if;
  if v_per = 'mes' then
    v_desde := date_trunc('month', v_hoy)::date; v_hasta := (v_desde + interval '1 month')::date - 1;
  elsif v_per = 'mes_pasado' then
    v_desde := (date_trunc('month', v_hoy) - interval '1 month')::date; v_hasta := date_trunc('month', v_hoy)::date - 1;
  elsif v_per = 'anio' then
    v_desde := date_trunc('year', v_hoy)::date; v_hasta := (v_desde + interval '1 year')::date - 1;
  elsif v_per = 'anio_pasado' then
    v_desde := (date_trunc('year', v_hoy) - interval '1 year')::date; v_hasta := date_trunc('year', v_hoy)::date - 1;
  elsif v_per = '' then
    if p_desde is null or p_hasta is null then
      raise exception using errcode = '22023', message = 'Un rango lleva sus dos fechas: p_desde y p_hasta.';
    end if;
    if p_desde > p_hasta then
      raise exception using errcode = '22023', message = format('El rango va al revés: del %s al %s.', p_desde, p_hasta);
    end if;
    if p_hasta - p_desde > 1100 then
      raise exception using errcode = '22023', message = 'Un rango va de un día a tres años.';
    end if;
    v_per := 'rango'; v_desde := p_desde; v_hasta := p_hasta;
  else
    raise exception using errcode = '22023',
      message = format('No conozco el período «%s». Los que hay: mes, mes_pasado, anio, anio_pasado (o p_desde y p_hasta).', left(p_periodo, 40));
  end if;
  if v_libro is null then
    return fn_tablero_no('resultados', 'El libro no tiene períodos todavía.');
  end if;
  v_alineado := v_desde = date_trunc('month', v_desde)::date and v_hasta = (date_trunc('month', v_hasta) + interval '1 month')::date - 1;
  v_meses := (extract(year from v_hasta)::int - extract(year from v_desde)::int) * 12
             + extract(month from v_hasta)::int - extract(month from v_desde)::int + 1;
  v_etq := case when v_alineado and v_meses = 1 then fn_tablero_mes_largo(v_desde)
                when v_alineado and v_meses = 12 and extract(month from v_desde) = 1 then extract(year from v_desde)::int::text
                else fn_tablero_rango(v_desde, v_hasta) end;
  if v_hasta < v_libro then
    return fn_tablero_no('resultados', format('Ese período (%s) es de antes del libro, que empieza el %s: vive en QuickBooks.',
                                              v_etq, fn_tablero_libro() ->> 'empieza'))
           || jsonb_build_object('antes_del_libro', true, 'periodo', v_per, 'desde', v_desde, 'hasta', v_hasta, 'etiqueta', v_etq);
  end if;
  if v_desde > v_hoy then
    return fn_tablero_no('resultados', format('Ese período (%s) todavía no empieza.', v_etq))
           || jsonb_build_object('futuro', true, 'periodo', v_per, 'desde', v_desde, 'hasta', v_hasta, 'etiqueta', v_etq);
  end if;
  v_en_curso := v_hoy < v_hasta;
  v_al := least(v_hasta, v_hoy);
  -- el período anterior
  if v_alineado then
    a_desde := (v_desde - make_interval(months => v_meses))::date;
    a_hasta := v_desde - 1;
    if v_en_curso then
      a_hasta := least(a_hasta, (v_hoy - make_interval(months => v_meses))::date);
    end if;
    a_etq := case when a_hasta = v_desde - 1 and v_meses = 1 then fn_tablero_mes_largo(a_desde)
                  when a_hasta = v_desde - 1 and v_meses = 12 and extract(month from a_desde) = 1 then extract(year from a_desde)::int::text
                  else fn_tablero_rango(a_desde, a_hasta) end;
  else
    a_desde := v_desde - (v_hasta - v_desde + 1);
    a_hasta := case when v_en_curso then a_desde + (v_hoy - v_desde) else v_desde - 1 end;
    a_etq := fn_tablero_rango(a_desde, a_hasta);
  end if;
  v_comp := a_desde >= v_libro;
  v_r := fn_tablero_pyg(v_desde, v_al);
  v_a := case when v_comp then fn_tablero_pyg(a_desde, a_hasta) end;
  v_d := case when v_en_curso then fn_tablero_pyg(v_al + 1, v_hasta) end;
  v_rev := fn_tablero_por_revisar(greatest(v_desde, v_libro), v_al);
  -- las etiquetas de los renglones, las de c4 (estados_lineas)
  select coalesce(jsonb_object_agg(el.linea, el.etiqueta_es), '{}'::jsonb) into v_etqs
    from estados_lineas el
   where el.estado = 'resultados' and (el.seccion = el.linea or el.seccion = 'totales');
  select jsonb_agg(jsonb_build_object(
           'clave', k.clave, 'etiqueta', coalesce(v_etqs ->> k.linea, k.omision), 'es_total', k.es_total,
           'monto', (v_r ->> k.clave)::numeric,
           'anterior', (v_a ->> k.clave)::numeric,
           'variacion', ((v_r ->> k.clave)::numeric - (v_a ->> k.clave)::numeric)::numeric(14,2),
           'variacion_pct', fn_tablero_pct((v_r ->> k.clave)::numeric - (v_a ->> k.clave)::numeric, (v_a ->> k.clave)::numeric, true))
           order by k.o) into v_filas
    from (values (1, 'ingresos', 'ingresos', 'Ingresos', false), (2, 'costo', 'costo', 'Costo de obra', false),
                 (3, 'utilidad_bruta', 'utilidad_bruta', 'Utilidad bruta', true), (4, 'gastos', 'gastos', 'Gastos de operación', false),
                 (5, 'utilidad_operacion', 'utilidad_operacion', 'Utilidad de operación', true),
                 (6, 'otros_ingresos', 'otros_ingresos', 'Otros ingresos', false), (7, 'otros_gastos', 'otros_gastos', 'Otros gastos', false),
                 (8, 'resultado', 'utilidad_neta', 'Utilidad neta', true)) k(o, clave, linea, omision, es_total);
  -- LO DEL WIP QUE VA APARTE (el reverso del día 1 que espera el ajuste de su mes), en llano
  v_w := v_r -> 'wip_aparte';
  if v_w is not null and v_w <> 'null'::jsonb then
    v_w := v_w || jsonb_build_object('texto', format(
      'No se cuenta aquí el reverso automático del ajuste del WIP de %s (del %s): %s de ingreso y %s de costo. No es una venta ni un '
      'gasto de estos días: deshace lo sobre y sub-facturado que se ajustó al cerrar %s, y se compensa con el ajuste del WIP de %s al '
      'cerrar el mes. Con él, como lo cuenta Estados → Resultados (que sigue el libro tal cual), %s de estos días sería %s.',
      coalesce((select string_agg(fn_tablero_mes_largo(to_date(e || '-01', 'YYYY-MM-DD')), ' y ' order by e)
                  from jsonb_array_elements_text(v_w -> 'de') e), 'el mes anterior'),
      fn_tablero_dia((v_w ->> 'fecha')::date), fn_tablero_usd((v_w ->> 'ingresos')::numeric), fn_tablero_usd((v_w ->> 'costo')::numeric),
      coalesce((select string_agg(fn_tablero_mes_largo(to_date(e || '-01', 'YYYY-MM-DD')), ' y ' order by e)
                  from jsonb_array_elements_text(v_w -> 'de') e), 'el mes anterior'),
      fn_tablero_mes_largo((v_w ->> 'fecha')::date),
      case when (v_r ->> 'resultado')::numeric + (v_w ->> 'resultado')::numeric < 0 then 'la pérdida' else 'la utilidad' end,
      fn_tablero_usd((v_r ->> 'resultado')::numeric + (v_w ->> 'resultado')::numeric)));
  else
    v_w := null;
  end if;
  -- EL TÍTULO DE LA CIFRA, en llano: el período y, si va a medias o empieza antes del libro, desde cuándo cuenta
  v_tit := format('%s de %s', case when (v_r ->> 'resultado')::numeric < 0 then 'Pérdida' else 'Utilidad' end,
                  case when v_desde < v_libro
                         then format('%s en el libro (del %s a %s)', v_etq, fn_tablero_dia(v_libro),
                                     case when v_en_curso then 'hoy' else fn_tablero_dia(v_hasta) end)
                       when v_en_curso then v_etq || ' (hasta hoy)'
                       else v_etq end);
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'resultados', 'periodo', v_per, 'etiqueta', v_etq, 'titulo', v_tit,
    'desde', v_desde, 'hasta', v_hasta, 'corte', v_al,
    'en_curso', v_en_curso, 'parcial', v_desde < v_libro, 'desde_libro', case when v_desde < v_libro then v_libro end,
    'resultado', v_r -> 'resultado', 'es_perdida', (v_r ->> 'resultado')::numeric < 0,
    'margen_pct', case when (v_r ->> 'ingresos')::numeric > 0 then fn_tablero_pct((v_r ->> 'resultado')::numeric, (v_r ->> 'ingresos')::numeric) end,
    'ingresos', v_r -> 'ingresos', 'costo', v_r -> 'costo', 'gastos', v_r -> 'gastos',
    'otros_ingresos', v_r -> 'otros_ingresos', 'otros_gastos', v_r -> 'otros_gastos',
    'utilidad_bruta', v_r -> 'utilidad_bruta', 'utilidad_operacion', v_r -> 'utilidad_operacion',
    'asientos', v_r -> 'asientos',
    -- las dos barras: lo que entra y lo que se gasta (entra − sale = el resultado), con lo que espera en la Bandeja de esos días
    'barras', jsonb_build_array(
        jsonb_build_object('clave', 'ingresos', 'etiqueta', 'Ingresos', 'monto', v_r -> 'entra', 'anterior', v_a -> 'entra',
                           'por_revisar', v_rev -> 'depositos',
                           'nota', 'Un depósito que espera en la Bandeja es un cobro: el ingreso lo pone la factura.'),
        jsonb_build_object('clave', 'gastos', 'etiqueta', 'Costo y gastos', 'monto', v_r -> 'sale', 'anterior', v_a -> 'sale',
                           'por_revisar', v_rev -> 'cargos', 'dobles', v_rev -> 'dobles',
                           'nota', 'Un cargo que espera en la Bandeja puede ser un gasto que todavía no está en el libro; uno que «llegó '
                                   'su ticket» está dos veces en el libro hasta que se resuelva.')),
    'renglones', v_filas,
    'anterior', case when v_comp
                     then jsonb_build_object('desde', a_desde, 'hasta', a_hasta, 'etiqueta', a_etq, 'resultado', v_a -> 'resultado',
                                             'ingresos', v_a -> 'ingresos', 'entra', v_a -> 'entra', 'sale', v_a -> 'sale',
                                             'margen_pct', case when (v_a ->> 'ingresos')::numeric > 0
                                                                then fn_tablero_pct((v_a ->> 'resultado')::numeric, (v_a ->> 'ingresos')::numeric) end) end,
    'variacion', case when v_comp
                      then jsonb_build_object(
                             'monto', ((v_r ->> 'resultado')::numeric - (v_a ->> 'resultado')::numeric)::numeric(14,2),
                             'pct', fn_tablero_pct((v_r ->> 'resultado')::numeric - (v_a ->> 'resultado')::numeric, (v_a ->> 'resultado')::numeric, true),
                             'sube', (v_r ->> 'resultado')::numeric > (v_a ->> 'resultado')::numeric,
                             'igual', (v_r ->> 'resultado')::numeric = (v_a ->> 'resultado')::numeric,
                             'contra', a_etq) end,
    'sin_comparar', case when not v_comp
                         then format('El período anterior (%s) empieza antes del libro (%s): vive en QuickBooks.', a_etq, fn_tablero_libro() ->> 'empieza') end,
    'despues_de_hoy', case when v_en_curso and coalesce((v_d ->> 'asientos')::int, 0) > 0
                           then jsonb_build_object('asientos', v_d -> 'asientos', 'resultado', v_d -> 'resultado',
                                                   'texto', format('En este período hay %s con fecha de después de hoy: no %s.',
                                                                   fn_tablero_plural((v_d ->> 'asientos')::int, 'asiento', 'asientos'),
                                                                   case when (v_d ->> 'asientos')::int = 1 then 'va contado' else 'van contados' end)) end,
    'ajustes_otro_ejercicio', v_r -> 'ajustes_otro_ejercicio',
    'wip_aparte', v_w,
    'por_revisar', v_rev,
    'nota', case when v_desde < v_libro
                 then format('El libro empieza el %s: lo de antes vive en QuickBooks y no está aquí.', fn_tablero_libro() ->> 'empieza') end,
    'fuente', 'el libro, con el mapeo de los estados financieros (c4): lo mismo que el estado de resultados',
    'ir', jsonb_build_object('pagina', 'estados', 'sub', 'resultados',
                             'periodo', case when v_alineado and v_meses = 1 then to_char(v_desde, 'YYYY-MM')
                                             when v_alineado and v_meses = 12 and extract(month from v_desde) = 1 then to_char(v_desde, 'YYYY')
                                             else to_char(v_al, 'YYYY-MM') end));
end $$;
revoke execute on function public.fn_tablero_resultados(date, date, text) from public, anon, service_role;
grant  execute on function public.fn_tablero_resultados(date, date, text) to authenticated;
comment on function public.fn_tablero_resultados(date, date, text) is 'c16: el resultado de un período (p_periodo: mes | mes_pasado | anio | anio_pasado; o p_desde y p_hasta), contado hasta hoy si no ha terminado: {ok, tarjeta: «resultados», periodo, etiqueta (noviembre de 2026; 2026; 1 a 12 de noviembre de 2026), desde, hasta, corte, en_curso, parcial y desde_libro (si empieza antes del libro), resultado (utilidad neta), es_perdida, margen_pct (resultado ÷ ingresos), ingresos, costo, gastos, otros_ingresos, otros_gastos, utilidad_bruta, utilidad_operacion, asientos, barras: [{clave: ingresos | gastos, etiqueta, monto (ingresos + otros ingresos; costo + gastos + otros gastos), anterior, por_revisar: {n, monto} (depósitos o cargos de esos días que esperan en la Bandeja), nota}], renglones: [{clave, etiqueta (la de c4), es_total, monto, anterior, variacion, variacion_pct}] (el estado entero, para la tabla), anterior: {desde, hasta, etiqueta, resultado, ingresos, entra, sale, margen_pct} (nulo si empieza antes del libro), variacion: {monto, pct, sube, igual, contra}, sin_comparar (por qué no hay anterior), despues_de_hoy, ajustes_otro_ejercicio, por_revisar (la Bandeja de esos días: {n, cargos, depositos, dobles, quitadas, mas_viejo, ir…}; nulo sin c6), wip_aparte: {ingresos, costo, gastos, otros_ingresos, otros_gastos, resultado, entra, sale, asientos, de, fecha, texto} (el reverso automático del WIP del día 1 en un mes que todavía no tiene su propio ajuste: NO se cuenta en las cifras de arriba —resultado + wip_aparte.resultado = Estados → Resultados— y el texto lo explica; nulo si no hay), titulo (la cifra en llano: «Utilidad de noviembre de 2026 (hasta hoy)», «Utilidad de 2026 en el libro (del 1-oct-2026 a hoy)»), nota, fuente, ir}. Un período de antes del libro: {ok: false, antes_del_libro: true}; uno que no ha empezado: {ok: false, futuro: true}. 22023 si el período no existe. Solo lee. Solo el dueño.';

-- 3.5 · LO GASTADO en los últimos N días, por categoría, contra los N
-- anteriores. Una categoría es una cuenta de costo, de gastos o de otros
-- gastos (las tres secciones de gasto del estado de resultados de c4), con
-- la etiqueta de c4. Hoy y los N − 1 días anteriores, contra los N días
-- justo antes; si esos empiezan antes del libro, no hay comparación. El
-- ajuste del WIP (c12: la provisión de pérdida y su reverso del día 1) NO
-- es un gasto: no se cuenta aquí (sí en Resultados), y la nota lo dice.
-- Lo que espera en la Bandeja se dice con su sentido: un cargo pendiente
-- puede ser un gasto que falta (lo gastado puede ser más); uno que «llegó
-- su ticket» está dos veces en el libro (lo gastado va de más).
create or replace function public.fn_tablero_gastos(p_dias int default 30, p_top int default 5) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_libro date;
  v_dias  int := coalesce(p_dias, 30);
  v_top   int := coalesce(p_top, 5);
  v_desde date;
  a_desde date;
  a_hasta date;
  v_comp  boolean;
  v_rev   jsonb;
  v_wip   int := 0;
  r       record;
begin
  perform fn_tablero_exigir_dueno();
  if v_dias < 1 or v_dias > 366 then
    raise exception using errcode = '22023', message = format('Los días van de 1 a 366 (llegó %s).', v_dias);
  end if;
  if v_top < 1 or v_top > 20 then
    raise exception using errcode = '22023', message = format('Las categorías de la gráfica van de 1 a 20 (llegó %s).', v_top);
  end if;
  v_libro := (fn_tablero_libro() ->> 'desde')::date;
  if v_libro is null then
    return fn_tablero_no('gastos', 'El libro no tiene períodos todavía.');
  end if;
  v_desde := v_hoy - (v_dias - 1);
  a_desde := v_desde - v_dias;
  a_hasta := v_desde - 1;
  v_comp := a_desde >= v_libro;
  v_rev := fn_tablero_por_revisar(greatest(v_desde, v_libro), v_hoy);
  -- (cuántos asientos del WIP con líneas de gasto caen en estos días: no se cuentan)
  select count(distinct x.asiento_id) into v_wip
    from fn_tablero_wip() x
    join asiento_lineas li on li.asiento_id = x.asiento_id
    join fn_tablero_mapa() m on m.cuenta = li.cuenta and m.estado = 'resultados' and m.seccion in ('costo', 'gastos', 'otros_gastos')
   where x.fecha >= v_desde and x.fecha <= v_hoy;
  with m as materialized (
    select x.cuenta, x.etiqueta, x.seccion, x.orden from fn_tablero_mapa() x
     where x.estado = 'resultados' and x.seccion in ('costo', 'gastos', 'otros_gastos')
  ), w as materialized (
    select x.asiento_id from fn_tablero_wip() x where x.fecha >= a_desde and x.fecha <= v_hoy
  ), ln as materialized (
    select li.cuenta, a.fecha_contable >= v_desde as actual, li.monto
      from asiento_lineas li
      join asientos a on a.id = li.asiento_id
     where li.cuenta in (select m.cuenta from m)
       and a.fecha_contable >= a_desde and a.fecha_contable <= v_hoy
       and (a.afecta_periodo is null
            or coalesce((select pa.anio from periodos pa where pa.periodo = a.afecta_periodo), a.anio) = a.anio)
       and not exists (select 1 from w where w.asiento_id = li.asiento_id)
  ), c as (
    select m.cuenta, m.etiqueta as nombre, m.seccion, m.orden,
           coalesce(sum(ln.monto) filter (where ln.actual), 0)::numeric(14,2) as monto,
           coalesce(sum(ln.monto) filter (where not ln.actual), 0)::numeric(14,2) as anterior
      from m join ln on ln.cuenta = m.cuenta
     group by m.cuenta, m.etiqueta, m.seccion, m.orden
  ), t as (
    select coalesce(sum(c.monto), 0)::numeric(14,2) as total, coalesce(sum(c.anterior), 0)::numeric(14,2) as anterior,
           coalesce(sum(c.monto) filter (where c.monto > 0), 0)::numeric(14,2) as positivo,
           coalesce(sum(c.monto) filter (where c.monto < 0), 0)::numeric(14,2) as negativo,
           count(*) filter (where c.monto <> 0) as n
      from c
  ), o as (
    select c.*, row_number() over (order by c.monto desc, c.cuenta) as pos from c where c.monto > 0
  )
  select t.total, t.anterior, t.positivo, t.negativo, t.n,
         (select coalesce(jsonb_agg(jsonb_build_object(
                   'cuenta', c.cuenta, 'nombre', c.nombre, 'seccion', c.seccion, 'monto', c.monto,
                   'pct', fn_tablero_pct(c.monto, nullif(t.total, 0)),
                   'anterior', case when v_comp then c.anterior end,
                   'variacion', case when v_comp then (c.monto - c.anterior)::numeric(14,2) end,
                   'variacion_pct', case when v_comp then fn_tablero_pct(c.monto - c.anterior, c.anterior, true) end)
                   order by c.monto desc, c.cuenta), '[]'::jsonb)
            from c where c.monto <> 0 or (v_comp and c.anterior <> 0)) as categorias,
         (select coalesce(jsonb_agg(z.j order by z.o), '[]'::jsonb)
            from (select o.pos as o, jsonb_build_object('clave', o.cuenta, 'nombre', o.nombre, 'monto', o.monto,
                                                        'pct', fn_tablero_pct(o.monto, nullif(t.positivo, 0)), 'categorias', 1) as j
                    from o where o.pos <= v_top
                  union all
                  select v_top + 1, jsonb_build_object('clave', 'otras', 'nombre', 'Las demás', 'monto', sum(o.monto)::numeric(14,2),
                                                       'pct', fn_tablero_pct(sum(o.monto), nullif(t.positivo, 0)),
                                                       'categorias', count(*))
                    from o where o.pos > v_top having count(*) > 0) z) as grafica
    into r
    from t;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'gastos', 'dias', v_dias, 'desde', v_desde, 'hasta', v_hoy, 'corte', v_hoy,
    'etiqueta', format('Últimos %s días', v_dias),
    'total', r.total, 'n_categorias', r.n, 'categorias', r.categorias,
    -- la gráfica: las «top» mayores y las demás juntas; sus porcentajes son de lo gastado en positivo
    'grafica', r.grafica, 'total_grafica', r.positivo,
    'abonos', case when r.negativo <> 0 then r.negativo end,
    'anterior', case when v_comp then jsonb_build_object('desde', a_desde, 'hasta', a_hasta, 'total', r.anterior,
                                                         'etiqueta', fn_tablero_rango(a_desde, a_hasta)) end,
    'variacion', case when v_comp then (r.total - r.anterior)::numeric(14,2) end,
    'variacion_pct', case when v_comp then fn_tablero_pct(r.total - r.anterior, r.anterior, true) end,
    'sin_comparar', case when not v_comp
                         then format('Los %s días anteriores (%s) empiezan antes del libro (%s): viven en QuickBooks.', v_dias,
                                     fn_tablero_rango(a_desde, a_hasta), fn_tablero_libro() ->> 'empieza') end,
    'parcial', v_desde < v_libro,
    'por_revisar', v_rev -> 'cargos',
    'dobles', v_rev -> 'dobles',
    'wip_fuera', case when v_wip > 0 then v_wip end,
    'ir_bandeja', jsonb_build_object('pagina', 'bandeja', 'cuenta', null, 'desde', v_desde, 'hasta', v_hoy),
    'nota', nullif(concat_ws(' ',
              case when v_desde < v_libro
                   then format('El libro empieza el %s: de estos %s días solo cuentan los que tienen libro.', fn_tablero_libro() ->> 'empieza', v_dias) end,
              case when r.negativo <> 0
                   then format('Hay categorías con saldo a favor en estos días (%s): bajan el total y no salen en la gráfica.',
                               fn_tablero_usd(r.negativo)) end,
              case when coalesce((v_rev -> 'cargos' ->> 'n')::int, 0) > 0
                   then format('%s de estos días %s en la Bandeja (%s): lo gastado puede ser más.',
                               fn_tablero_plural((v_rev -> 'cargos' ->> 'n')::int, 'cargo', 'cargos'),
                               case when (v_rev -> 'cargos' ->> 'n')::int = 1 then 'espera' else 'esperan' end,
                               fn_tablero_usd((v_rev -> 'cargos' ->> 'monto')::numeric)) end,
              case when coalesce((v_rev -> 'dobles' ->> 'n')::int, 0) > 0
                   then format('%s de estos días %s DOS VECES en el libro (llegó su ticket después de clasificar el cargo): lo gastado va de más en %s hasta que se resuelva en la Bandeja.',
                               fn_tablero_plural((v_rev -> 'dobles' ->> 'n')::int, 'gasto', 'gastos'),
                               case when (v_rev -> 'dobles' ->> 'n')::int = 1 then 'está' else 'están' end,
                               fn_tablero_usd((v_rev -> 'dobles' ->> 'monto')::numeric)) end,
              case when v_wip > 0
                   then 'El ajuste del WIP de las obras (la provisión de pérdida y su reverso) no es un gasto: no se cuenta aquí; está en Resultados.' end), ''),
    'fuente', 'el libro: las cuentas de costo, gastos y otros gastos del estado de resultados (c4), por la fecha de cada asiento, sin el ajuste del WIP',
    'ir', jsonb_build_object('pagina', 'estados', 'sub', 'resultados', 'periodo', to_char(v_hoy, 'YYYY-MM')));
end $$;
revoke execute on function public.fn_tablero_gastos(int, int) from public, anon, service_role;
grant  execute on function public.fn_tablero_gastos(int, int) to authenticated;
comment on function public.fn_tablero_gastos(int, int) is 'c16: lo gastado en los últimos N días (hoy y los N − 1 anteriores; de fábrica 30) por categoría, contra los N días de antes: {ok, tarjeta: «gastos», dias, desde, hasta, corte, etiqueta, total, n_categorias, categorias: [{cuenta, nombre (la etiqueta de c4), seccion (costo | gastos | otros_gastos), monto, pct (del total), anterior, variacion, variacion_pct}] (de mayor a menor), grafica: [{clave (la cuenta, u «otras»), nombre, monto, pct, categorias}] (las p_top mayores y las demás juntas; pct de total_grafica), total_grafica (lo gastado en positivo), abonos (lo que hay a favor, si lo hay), anterior: {desde, hasta, total, etiqueta}, variacion, variacion_pct, sin_comparar (por qué no hay anterior), parcial, por_revisar: {n, monto} (cargos pendientes de esos días en la Bandeja: lo gastado puede ser más; nulo sin c6), dobles: {n, monto} (gastos de esos días que están dos veces en el libro porque su ticket llegó después: lo gastado va de más; nulo sin c6), wip_fuera (cuántos asientos del ajuste del WIP caen en estos días: no se cuentan, no son un gasto), ir_bandeja, nota (en llano: lo de antes del libro, los abonos, lo pendiente, lo doble y el WIP), fuente, ir}. Sin el ajuste del WIP (c12). Un ajuste del CPA que corrige otro año no cuenta. 22023 con días o top fuera de rango. Solo lee. Solo el dueño.';

-- 3.6 · LAS VENTAS: lo vendido (las cuentas de la sección «ingresos» de c4)
-- de cada mes de un año, y su total. Solo los meses que el libro tiene: los
-- de antes viven en QuickBooks, y se dice (en el título también: «Ventas de
-- 2026 en el libro (del 1-oct-2026 a hoy)», no «Ventas de 2026»). El mes en
-- curso, hasta hoy. SIN EL AJUSTE DEL WIP (c12): lo sobre y sub-facturado
-- de las obras que el CPA ajusta al cerrar cada mes, y su reverso del día 1,
-- no son ventas de ese mes (el reverso de octubre metía $17,234.35 en el 1
-- de noviembre y hacía de noviembre «el mejor mes» con la mitad de lo
-- facturado). Cada mes trae aparte su «wip» y lo que daría con él
-- («con_wip», lo que dice Resultados), y la nota lo explica.
create or replace function public.fn_tablero_ventas(p_anio int default null) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_libro date;
  v_anio  int := coalesce(p_anio, extract(year from fn_tablero_hoy())::int);
  v_m0    date;
  v_m1    date;
  v_fuera int;
  v_corte date;
  r       record;
begin
  perform fn_tablero_exigir_dueno();
  if v_anio < 2000 or v_anio > 2100 then
    raise exception using errcode = '22023', message = format('El año no parece un año (llegó %s).', v_anio);
  end if;
  v_libro := (fn_tablero_libro() ->> 'desde')::date;
  if v_libro is null then
    return fn_tablero_no('ventas', 'El libro no tiene períodos todavía.');
  end if;
  if make_date(v_anio, 12, 31) < v_libro then
    return fn_tablero_no('ventas', format('%s es de antes del libro, que empieza el %s: sus ventas viven en QuickBooks.', v_anio, fn_tablero_libro() ->> 'empieza'))
           || jsonb_build_object('antes_del_libro', true, 'anio', v_anio);
  end if;
  if make_date(v_anio, 1, 1) > v_hoy then
    return fn_tablero_no('ventas', format('%s todavía no empieza.', v_anio)) || jsonb_build_object('futuro', true, 'anio', v_anio);
  end if;
  v_m0 := greatest(make_date(v_anio, 1, 1), date_trunc('month', v_libro)::date);
  v_m1 := least(make_date(v_anio, 12, 1), date_trunc('month', v_hoy)::date);
  v_fuera := extract(month from v_m0)::int - 1;   -- los meses del año de antes del libro
  v_corte := least(v_hoy, make_date(v_anio, 12, 31));
  with ms as (
    select g::date as mes from generate_series(v_m0::timestamp, v_m1::timestamp, interval '1 month') g
  ), m as materialized (
    select x.cuenta from fn_tablero_mapa() x where x.estado = 'resultados' and x.seccion = 'ingresos'
  ), w as materialized (
    select x.asiento_id from fn_tablero_wip() x where x.fecha >= v_m0 and x.fecha <= v_corte
  ), ln as materialized (
    select date_trunc('month', a.fecha_contable)::date as mes, li.monto, li.asiento_id,
           exists (select 1 from w where w.asiento_id = li.asiento_id) as wip
      from asiento_lineas li
      join asientos a on a.id = li.asiento_id
     where li.cuenta in (select m.cuenta from m)
       and a.fecha_contable >= v_m0 and a.fecha_contable <= v_corte
       and (a.afecta_periodo is null
            or coalesce((select pa.anio from periodos pa where pa.periodo = a.afecta_periodo), a.anio) = a.anio)
  ), x as (
    select ms.mes, coalesce(-sum(ln.monto) filter (where not ln.wip), 0)::numeric(14,2) as monto,
           coalesce(-sum(ln.monto) filter (where ln.wip), 0)::numeric(14,2) as wip,
           count(distinct ln.asiento_id) filter (where not ln.wip) as asientos
      from ms left join ln on ln.mes = ms.mes group by ms.mes
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'mes', to_char(x.mes, 'YYYY-MM'), 'etiqueta', fn_tablero_mes(x.mes), 'corto', fn_tablero_mes_corto(x.mes),
           'monto', x.monto, 'wip', x.wip, 'con_wip', (x.monto + x.wip)::numeric(14,2),
           'asientos', x.asientos, 'en_curso', x.mes = date_trunc('month', v_hoy)::date,
           'hasta', least((x.mes + interval '1 month')::date - 1, v_hoy)) order by x.mes), '[]'::jsonb) as meses,
         coalesce(sum(x.monto), 0)::numeric(14,2) as total, coalesce(sum(x.wip), 0)::numeric(14,2) as total_wip, count(*) as n,
         bool_or(x.wip <> 0) as hay_wip,
         (select string_agg(format('%s %s', fn_tablero_mes_corto(y.mes), fn_tablero_usd(y.wip)), ', ' order by y.mes)
            from x y where y.wip <> 0) as wip_meses,
         (select jsonb_build_object('mes', to_char(y.mes, 'YYYY-MM'), 'etiqueta', fn_tablero_mes(y.mes), 'monto', y.monto)
            from x y where y.monto > 0 order by y.monto desc, y.mes limit 1) as mejor
    into r
    from x;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'ventas', 'anio', v_anio, 'desde', v_m0, 'corte', v_corte,
    'etiqueta', case when v_fuera > 0
                       then format('%s en el libro: %s', v_anio,
                                   case when v_m0 = v_m1 then fn_tablero_mes_corto(v_m0)
                                        else fn_tablero_mes_corto(v_m0) || '–' || fn_tablero_mes_corto(v_m1) end)
                     when v_anio = extract(year from v_hoy)::int then format('Lo que va de %s', v_anio)
                     else v_anio::text end,
    -- (el título de la cifra grande, en llano: nunca «Ventas de 2026» si el libro solo tiene de octubre en adelante)
    'titulo', case when v_fuera > 0
                     then format('Ventas de %s en el libro (del %s a %s)', v_anio, fn_tablero_dia(greatest(v_m0, v_libro)),
                                 case when v_corte = v_hoy then 'hoy' else fn_tablero_dia(v_corte) end)
                   when v_corte = v_hoy then format('Ventas de %s (hasta hoy)', v_anio)
                   else format('Ventas de %s', v_anio) end,
    'total', r.total, 'meses', r.meses, 'meses_con_libro', r.n, 'mejor_mes', r.mejor,
    'wip', case when r.hay_wip then jsonb_build_object(
             'monto', r.total_wip, 'con_wip', (r.total + r.total_wip)::numeric(14,2),
             'texto', format('Sin el ajuste del WIP de las obras (lo sobre y sub-facturado que el CPA ajusta al cerrar cada mes y se deshace el día 1): '
                             'no es lo vendido. Con él, como lo cuenta Resultados: %s.', r.wip_meses)) end,
    'antes_del_libro', case when v_fuera > 0
                            then jsonb_build_object('meses', v_fuera,
                                   'texto', format('%s de %s no %s en el libro, que empieza el %s: %s en QuickBooks.',
                                                   case when v_fuera = 1 then 'Enero'
                                                        else 'De enero a ' || (array['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
                                                                                     'agosto', 'septiembre', 'octubre', 'noviembre'])[v_fuera] end,
                                                   v_anio, case when v_fuera = 1 then 'está' else 'están' end, fn_tablero_libro() ->> 'empieza',
                                                   case when v_fuera = 1 then 'vive' else 'viven' end)) end,
    'fuente', 'el libro: las cuentas de ingreso del estado de resultados (c4), por la fecha de cada asiento, sin el ajuste del WIP; el mes en curso, hasta hoy',
    'ir', jsonb_build_object('pagina', 'estados', 'sub', 'resultados', 'periodo', v_anio::text));
end $$;
revoke execute on function public.fn_tablero_ventas(int) from public, anon, service_role;
grant  execute on function public.fn_tablero_ventas(int) to authenticated;
comment on function public.fn_tablero_ventas(int) is 'c16: las ventas (los ingresos de la sección «ingresos» de c4, SIN el ajuste del WIP de c12) de cada mes de un año (de fábrica, el de hoy): {ok, tarjeta: «ventas», anio, desde, corte, etiqueta («2026 en el libro: oct–nov»; «Lo que va de 2027»; «2025»), titulo (la cifra en llano: «Ventas de 2026 en el libro (del 1-oct-2026 a hoy)»), total, meses: [{mes (AAAA-MM), etiqueta (oct 2026), corto (oct), monto (sin el WIP), wip (lo del ajuste del WIP con fecha de ese mes), con_wip (lo que dice Resultados), asientos, en_curso, hasta}] (solo los meses que el libro tiene, hasta el de hoy; un mes sin ventas sale en 0.00), meses_con_libro, mejor_mes: {mes, etiqueta, monto} (por lo vendido), wip: {monto, con_wip, texto} (nulo si no hay WIP en el año), antes_del_libro: {meses, texto} (los meses del año que viven en QuickBooks; nulo si no hay), fuente, ir}. Un año de antes del libro: {ok: false, antes_del_libro: true}; uno que no ha empezado: {ok: false, futuro: true}. 22023 si el año no parece un año. Solo lee. Solo el dueño.';


-- 3.7 · LA ANTIGÜEDAD de lo que se cobra y de lo que se paga, por
-- VENCIMIENTO, como QuickBooks: corriente (no ha vencido), 1–30, 31–60,
-- 61–90 y más de 90 días de vencida. p_lado: 'cobrar' | 'pagar'; p_filas:
-- las partidas de fn_tablero_cxc o de fn_tablero_cxp (jsonb). Lo que no
-- tiene vencimiento conocido va en su tramo aparte (sin_vencimiento: cuenta
-- en el total, no se inventa su fecha); la retención y lo que hay a favor,
-- aparte (no vencen).
create or replace function public.fn_tablero_antiguedad_de(p_lado text, p_filas jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_lado  text := lower(btrim(coalesce(p_lado, '')));
  v_ctas  text[];
  v_libro numeric;
  v_dias  int := 0;
  r       record;
begin
  perform fn_tablero_exigir_dueno();
  if v_lado not in ('cobrar', 'pagar') then
    raise exception using errcode = '22023', message = format('El lado es «cobrar» o «pagar» (llegó «%s»).', left(coalesce(p_lado, ''), 40));
  end if;
  if v_lado = 'cobrar' then
    select array_agg(pc.cuenta order by pc.cuenta) into v_ctas from puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc');
    v_libro := fn_tablero_saldo(v_ctas, v_hoy);
    if to_regclass('public.emision_config') is not null then
      execute 'select coalesce((select c.terminos_dias from public.emision_config c where c.id = 1), 0)' into v_dias;
    end if;
  else
    select array_agg(distinct u.c order by u.c) into v_ctas
      from (select pc.cuenta as c from puente_cuentas pc where pc.rol = 'cxp'
            union all
            select m.cuenta from fn_tablero_mapa() m where m.estado = 'balance' and m.linea = 'retencion_por_pagar') u;
    v_libro := -fn_tablero_saldo(v_ctas, v_hoy);
  end if;
  with x as materialized (
    select coalesce(f.por_cobrar, f.por_pagar)::numeric(14,2) as monto, coalesce(f.retencion, 0)::numeric(14,2) as retencion,
           f.tramo, f.dias_vencida, f.fecha, f.vence, coalesce(f.factura_num, f.referencia) as papel,
           coalesce(f.obra, f.proveedor) as de, f.cliente as detalle, f.partida_tabla, f.partida_id, f.tipo
      from jsonb_to_recordset(coalesce(p_filas, '[]'::jsonb))
           as f(por_cobrar numeric, por_pagar numeric, retencion numeric, tramo text, dias_vencida int, fecha date, vence date,
                factura_num text, referencia text, obra text, proveedor text, cliente text, partida_tabla text, partida_id text,
                tipo text)
  ), t as (
    select coalesce(sum(x.monto) filter (where x.monto > 0), 0)::numeric(14,2) as total,
           count(*) filter (where x.monto > 0) as n,
           count(*) filter (where x.monto > 0 and x.tipo in ('factura', 'papel')) as n_fact
      from x
  )
  select t.total, t.n, t.n_fact,
         (select jsonb_agg(jsonb_build_object('clave', k.clave, 'etiqueta', k.etiqueta,
                     'monto', coalesce((select sum(x.monto) from x where x.tramo = k.clave), 0)::numeric(14,2),
                     'n', (select count(*) from x where x.tramo = k.clave),
                     'pct', fn_tablero_pct((select sum(x.monto) from x where x.tramo = k.clave), nullif(t.total, 0)),
                     'vencido', k.clave <> 'corriente') order by k.o)
            from (values (1, 'corriente', 'Corriente'), (2, 'd1_30', '1–30'), (3, 'd31_60', '31–60'), (4, 'd61_90', '61–90'),
                         (5, 'd90_mas', 'Más de 90')) k(o, clave, etiqueta)) as tramos,
         coalesce((select sum(x.monto) from x where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)::numeric(14,2) as vencido,
         (select count(*) from x where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')) as n_vencido,
         coalesce((select sum(x.monto) from x where x.tramo = 'sin_vencimiento'), 0)::numeric(14,2) as sin_vence,
         (select count(*) from x where x.tramo = 'sin_vencimiento') as n_sin_vence,
         coalesce((select sum(x.retencion) from x), 0)::numeric(14,2) as retencion,
         (select count(*) from x where x.retencion <> 0) as n_retencion,
         coalesce((select sum(x.monto) from x where x.monto < 0), 0)::numeric(14,2) as a_favor,
         (select count(*) from x where x.monto < 0) as n_a_favor,
         (select coalesce(jsonb_agg(jsonb_build_object('papel', y.papel, 'de', y.de, 'detalle', y.detalle, 'fecha', y.fecha,
                                                       'vence', y.vence, 'dias_vencida', y.dias_vencida, 'monto', y.monto, 'tramo', y.tramo,
                                                       'partida_tabla', y.partida_tabla, 'partida_id', y.partida_id)
                                    order by y.dias_vencida desc, y.monto desc), '[]'::jsonb)
            from (select * from x where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')
                   order by x.dias_vencida desc, x.monto desc, x.papel limit 5) y) as viejas
    into r
    from t;
  return jsonb_build_object(
    'ok', true, 'tarjeta', case when v_lado = 'cobrar' then 'por_cobrar' else 'por_pagar' end, 'lado', v_lado, 'corte', v_hoy,
    'total', r.total, 'n', r.n, 'facturas', r.n_fact,
    -- (cuántas, en llano: facturas, no «partidas»)
    'cuantas', case when v_lado = 'cobrar'
                    then fn_tablero_plural(r.n_fact, 'factura', 'facturas')
                         || case when r.n > r.n_fact then ' y ' || fn_tablero_plural(r.n - r.n_fact, 'saldo sin factura', 'saldos sin factura') else '' end
                    else fn_tablero_plural(r.n_fact, 'factura de proveedor', 'facturas de proveedores')
                         || case when r.n > r.n_fact then ' y ' || fn_tablero_plural(r.n - r.n_fact, 'saldo de proveedor sin factura', 'saldos de proveedores sin factura') else '' end end,
    'tramos', r.tramos,
    'sin_vencimiento', jsonb_build_object('monto', r.sin_vence, 'n', r.n_sin_vence),
    'vencido', jsonb_build_object('monto', r.vencido, 'n', r.n_vencido, 'pct', fn_tablero_pct(r.vencido, nullif(r.total, 0))),
    'retencion', jsonb_build_object('monto', r.retencion, 'n', r.n_retencion),
    'a_favor', jsonb_build_object('monto', r.a_favor, 'n', r.n_a_favor),
    'mas_vencidas', r.viejas,
    'cuadre', jsonb_build_object('ok', (r.total + r.retencion + r.a_favor) = v_libro, 'libro', v_libro,
                                 'suma', (r.total + r.retencion + r.a_favor)::numeric(14,2), 'cuentas', to_jsonb(v_ctas),
                                 'texto', case when v_lado = 'cobrar'
                                               then 'los tramos + lo que va sin vencimiento + la retención + los anticipos y saldos a favor = el saldo de las cuentas por cobrar en el libro'
                                               else 'los tramos + lo que va sin vencimiento + la retención + lo que hay a favor = el saldo de las cuentas por pagar en el libro' end),
    'regla', case when v_lado = 'cobrar'
                  then format('Vence el día que dice la factura emitida por la app; la que no lo trae (las de QuickBooks), %s. '
                              'La retención y los anticipos no vencen: van aparte.',
                              case when v_dias = 0 then 'el día de su fecha («due on receipt», los términos de Facturas → Ajustes)'
                                   else format('a los %s días de su fecha (los términos de Facturas → Ajustes)', v_dias) end)
                  else 'Vence según los términos del proveedor (Net 30, Net 10 EOM y los demás) o lo que dijo la balanza de apertura; lo que no se '
                       'sabe cuándo vence (un proveedor sin términos, lo de la apertura sin su fecha) va aparte, sin vencimiento. La '
                       'retención a los subcontratistas no vence por términos: va aparte.' end,
    'fuente', case when v_lado = 'cobrar'
                   then 'lo abierto de cada factura y anticipo en las cuentas por cobrar del libro (la antigüedad de c4), por su vencimiento'
                   else 'lo que se debe de cada factura de proveedor en las cuentas por pagar del libro (la antigüedad de c4), por su vencimiento' end,
    'ir', case when v_lado = 'cobrar' then jsonb_build_object('pagina', 'facturas', 'sub', 'facturas')
               when (fn_tablero_capas() ->> 'c13')::boolean then jsonb_build_object('pagina', 'cedula', 'sub', 'cedula', 'cuenta', v_ctas[1])
               else jsonb_build_object('pagina', 'estados', 'sub', 'balance', 'cuenta', v_ctas[1]) end);
end $$;
revoke execute on function public.fn_tablero_antiguedad_de(text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero_antiguedad_de(text, jsonb) to authenticated;
comment on function public.fn_tablero_antiguedad_de(text, jsonb) is 'c16: arma la antigüedad de un lado (cobrar | pagar) con sus partidas ya leídas (las de fn_tablero_cxc o fn_tablero_cxp, en jsonb). La tarjeta es fn_tablero_antiguedad. Solo el dueño.';

create or replace function public.fn_tablero_antiguedad(p_lado text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_lado text := lower(btrim(coalesce(p_lado, '')));
begin
  perform fn_tablero_exigir_dueno();
  if v_lado = 'cobrar' then
    return fn_tablero_antiguedad_de(v_lado, (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from fn_tablero_cxc() x));
  elsif v_lado = 'pagar' then
    return fn_tablero_antiguedad_de(v_lado, (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from fn_tablero_cxp() x));
  end if;
  raise exception using errcode = '22023', message = format('El lado es «cobrar» o «pagar» (llegó «%s»).', left(coalesce(p_lado, ''), 40));
end $$;
revoke execute on function public.fn_tablero_antiguedad(text) from public, anon, service_role;
grant  execute on function public.fn_tablero_antiguedad(text) to authenticated;
comment on function public.fn_tablero_antiguedad(text) is 'c16: la antigüedad por VENCIMIENTO de lo que se cobra («cobrar») o de lo que se paga («pagar»): {ok, tarjeta (por_cobrar | por_pagar), lado, corte, total (lo que se debe, sin retención ni lo que hay a favor), n (cuántas cosas abiertas), facturas (de ellas, facturas), cuantas (en llano: «7 facturas y 1 saldo sin factura»), tramos: [{clave (corriente | d1_30 | d31_60 | d61_90 | d90_mas), etiqueta, monto, n, pct (del total), vencido}], sin_vencimiento: {monto, n} (cuenta en el total; no se sabe cuándo vence), vencido: {monto, n, pct}, retencion: {monto, n}, a_favor: {monto, n} (en negativo: anticipos y saldos a favor), mas_vencidas: [{papel, de, detalle, fecha, vence, dias_vencida, monto, tramo, partida_tabla, partida_id}] (las cinco más vencidas), cuadre: {ok, libro, suma, cuentas, texto} (total + retención + a favor = el saldo de sus cuentas en el libro), regla (cómo se sabe el vencimiento, en llano), fuente, ir}. 22023 con otro lado. Solo lee. Solo el dueño.';

-- 3.8 · LAS FACTURAS: las no pagadas (vencidas y por vencer) y lo cobrado
-- en los últimos N días (depositado y sin depositar). p_cxc: las partidas
-- de fn_tablero_cxc (jsonb); p_cobrado: lo de fn_tablero_cobrado.
create or replace function public.fn_tablero_facturas_de(p_cxc jsonb, p_cobrado jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy date := fn_tablero_hoy();
  v_dep jsonb := p_cobrado -> 'depositado';
  v_sin jsonb := p_cobrado -> 'sin_depositar';
  r     record;
begin
  perform fn_tablero_exigir_dueno();
  select coalesce(sum(x.por_cobrar), 0)::numeric(14,2) as monto, count(*) as n,
         coalesce(sum(x.por_cobrar) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)::numeric(14,2) as vencido,
         count(*) filter (where x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')) as n_vencido,
         coalesce(sum(x.por_cobrar) filter (where x.tramo not in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')), 0)::numeric(14,2) as por_vencer,
         count(*) filter (where x.tramo not in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')) as n_por_vencer,
         (select jsonb_build_object('factura', y.factura_num, 'obra', y.obra, 'fecha', y.fecha, 'vence', y.vence,
                                    'dias_vencida', y.dias_vencida, 'monto', y.por_cobrar)
            from jsonb_to_recordset(coalesce(p_cxc, '[]'::jsonb))
                 as y(tipo text, factura_num text, obra text, fecha date, vence date, dias_vencida int, por_cobrar numeric, tramo text)
           where y.tipo = 'factura' and y.por_cobrar > 0 and y.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')
           order by y.dias_vencida desc, y.por_cobrar desc limit 1) as vieja
    into r
    from jsonb_to_recordset(coalesce(p_cxc, '[]'::jsonb)) as x(tipo text, por_cobrar numeric, tramo text)
   where x.tipo = 'factura' and x.por_cobrar > 0;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'facturas', 'corte', v_hoy,
    'no_pagadas', jsonb_build_object(
        'monto', r.monto, 'n', r.n,
        'vencidas', jsonb_build_object('monto', r.vencido, 'n', r.n_vencido, 'pct', fn_tablero_pct(r.vencido, nullif(r.monto, 0))),
        'por_vencer', jsonb_build_object('monto', r.por_vencer, 'n', r.n_por_vencer, 'pct', fn_tablero_pct(r.por_vencer, nullif(r.monto, 0))),
        'mas_vencida', r.vieja,
        'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'facturas')),
    'pagadas', jsonb_build_object(
        'dias', p_cobrado -> 'dias', 'desde', p_cobrado -> 'desde', 'hasta', p_cobrado -> 'hasta',
        'monto', p_cobrado -> 'monto', 'n', p_cobrado -> 'n', 'facturas', p_cobrado -> 'facturas',
        'anticipos', p_cobrado -> 'anticipos',
        'depositado', case when v_dep is not null and v_dep <> 'null'::jsonb
                           then v_dep || jsonb_build_object('pct', fn_tablero_pct((v_dep ->> 'monto')::numeric, nullif((p_cobrado ->> 'monto')::numeric, 0))) end,
        'sin_depositar', case when v_sin is not null and v_sin <> 'null'::jsonb
                              then v_sin || jsonb_build_object('pct', fn_tablero_pct((v_sin ->> 'monto')::numeric, nullif((p_cobrado ->> 'monto')::numeric, 0))) end,
        'nota', p_cobrado -> 'nota',
        'ir', jsonb_build_object('pagina', 'movimientos')),
    'fuente', 'no pagadas: las facturas con saldo en las cuentas por cobrar del libro (sin su retención), vencidas según su vencimiento; '
              || 'pagadas: ' || (p_cobrado ->> 'fuente'),
    'ir', jsonb_build_object('pagina', 'facturas', 'sub', 'facturas'));
end $$;
revoke execute on function public.fn_tablero_facturas_de(jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero_facturas_de(jsonb, jsonb) to authenticated;
comment on function public.fn_tablero_facturas_de(jsonb, jsonb) is 'c16: arma la tarjeta de facturas con las partidas por cobrar (fn_tablero_cxc, en jsonb) y lo cobrado (fn_tablero_cobrado). La tarjeta es fn_tablero_facturas. Solo el dueño.';

create or replace function public.fn_tablero_facturas(p_dias int default 30) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy  date := fn_tablero_hoy();
  v_dias int := coalesce(p_dias, 30);
begin
  perform fn_tablero_exigir_dueno();
  if v_dias < 1 or v_dias > 366 then
    raise exception using errcode = '22023', message = format('Los días van de 1 a 366 (llegó %s).', v_dias);
  end if;
  return fn_tablero_facturas_de(
    (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from fn_tablero_cxc() x),
    fn_tablero_cobrado((select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from fn_tablero_cobros_lista(v_hoy - (v_dias - 1), v_hoy) x),
                       v_hoy - (v_dias - 1), v_hoy));
end $$;
revoke execute on function public.fn_tablero_facturas(int) from public, anon, service_role;
grant  execute on function public.fn_tablero_facturas(int) to authenticated;
comment on function public.fn_tablero_facturas(int) is 'c16: las facturas: {ok, tarjeta: «facturas», corte, no_pagadas: {monto, n, vencidas: {monto, n, pct}, por_vencer: {monto, n, pct}, mas_vencida: {factura, obra, fecha, vence, dias_vencida, monto}, ir} (las facturas con saldo por cobrar, sin su retención), pagadas: {dias, desde, hasta, monto, n (cobros), facturas, anticipos, depositado: {monto, n, pct}, sin_depositar: {monto, n, pct, sin_casar, en_camino, en_stripe, en_caja}, nota, ir} (lo cobrado en los últimos N días, como en el embudo; depositado y sin_depositar nulos sin c6), fuente, ir}. 22023 con días fuera de 1–366. Solo lee. Solo el dueño.';

-- 3.9 · LOS PRÉSTAMOS (c6): lo que se debe de cada uno, su cuota y la
-- PRÓXIMA (fn_tablero_cuotas: su fecha por el calendario del préstamo y su
-- reparto por la fórmula de c6). p_cuotas: las de fn_tablero_cuotas (jsonb).
create or replace function public.fn_tablero_prestamos_de(p_cuotas jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_ctas  text[];
  v_libro numeric;
  r       record;
begin
  perform fn_tablero_exigir_dueno();
  if to_regclass('public.v_prestamos') is null then
    return fn_tablero_no('prestamos', 'Los préstamos (c6) no están en esta base: se llevan con el banco.', 'c6');
  end if;
  execute $q$
    with c as (
      select x.* from jsonb_to_recordset(coalesce($1, '[]'::jsonb))
             as x(prestamo_id uuid, prestamista text, n int, fecha date, monto numeric, capital numeric, interes numeric,
                  saldo_despues numeric, atrasada boolean)
    ), p as (
      select v.*, (select jsonb_build_object('fecha', c.fecha, 'monto', c.monto, 'capital', c.capital, 'interes', c.interes,
                                             'saldo_despues', c.saldo_despues, 'atrasada', c.atrasada, 'dias', c.fecha - $2)
                     from c where c.prestamo_id = v.prestamo_id and c.n = 1) as proxima
        from public.v_prestamos v
       where v.estado = 'vigente' or v.saldo <> 0
    )
    select coalesce(jsonb_agg(jsonb_build_object(
             'prestamo_id', p.prestamo_id, 'prestamista', p.prestamista, 'descripcion', p.descripcion, 'estado', p.estado,
             'saldo', p.saldo, 'principal', p.principal,
             'pagado_pct', fn_tablero_pct(p.principal - p.saldo, nullif(p.principal, 0)),
             'cuota', p.cuota, 'tasa_anual', p.tasa_anual, 'cuotas_al_anio', p.cuotas_al_anio,
             'frecuencia', case p.cuotas_al_anio when 12 then 'mensual' when 52 then 'semanal' when 26 then 'cada dos semanas'
                                                 when 24 then 'quincenal' when 6 then 'cada dos meses' when 4 then 'trimestral'
                                                 when 2 then 'semestral' when 1 then 'anual' else p.cuotas_al_anio || ' al año' end,
             'cuotas_registradas', p.cuotas, 'ultima_cuota', p.ultima_fecha,
             'porcion_corriente', p.porcion_corriente, 'porcion_largo_plazo', p.porcion_largo_plazo,
             'cuentas', to_jsonb(array_remove(array[p.cuenta, p.cuenta_largo], null)),
             'proxima', p.proxima) order by (p.estado = 'vigente') desc, p.saldo desc, p.prestamista), '[]'::jsonb) as lista,
           coalesce(sum(p.saldo) filter (where p.estado = 'vigente'), 0)::numeric(14,2) as saldo,
           count(*) filter (where p.estado = 'vigente') as n,
           coalesce(sum(p.porcion_corriente) filter (where p.estado = 'vigente'), 0)::numeric(14,2) as corriente,
           (select jsonb_build_object('fecha', c.fecha, 'monto', c.monto, 'prestamista', c.prestamista, 'atrasada', c.atrasada,
                                      'dias', c.fecha - $2)
              from c where c.n = 1 order by c.fecha, c.prestamista limit 1) as proxima,
           (select coalesce(sum(c.monto), 0)::numeric(14,2) from c where c.fecha <= $2 + 30) as en_30,
           (select count(*) from c where c.atrasada) as atrasadas,
           array(select distinct u from public.v_prestamos v2, unnest(array[v2.cuenta, v2.cuenta_largo]) u
                  where u is not null order by 1) as ctas
      from p
  $q$ into r using p_cuotas, v_hoy;
  v_ctas := r.ctas;
  v_libro := case when cardinality(v_ctas) > 0 then -fn_tablero_saldo(v_ctas, v_hoy) end;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'prestamos', 'corte', v_hoy,
    'lista', r.lista,
    'totales', jsonb_build_object('saldo', r.saldo, 'n', r.n, 'porcion_corriente', r.corriente, 'proxima', r.proxima,
                                  'en_30_dias', r.en_30, 'atrasadas', r.atrasadas),
    'libro', jsonb_build_object('saldo', v_libro, 'cuentas', to_jsonb(v_ctas), 'igual', v_libro = r.saldo,
                                'texto', case when v_libro is null then 'Sin préstamos registrados.'
                                              when v_libro = r.saldo then 'Lo que se debe según los préstamos es el saldo de sus cuentas en el libro.'
                                              else format('Sus cuentas en el libro dicen %s y los préstamos registrados %s: la cédula de corte lo explica.',
                                                          fn_tablero_usd(v_libro), fn_tablero_usd(r.saldo)) end),
    'regla', 'La próxima cuota es la siguiente del calendario del préstamo (su primer pago y cada período después) contando las que el '
             'libro ya tiene; si su fecha ya pasó, sale «atrasada» (su cargo puede estar esperando en la Bandeja). Su reparto en capital e '
             'interés es el de la fórmula de c6.',
    'fuente', 'los préstamos de c6: lo que se debe es el saldo inicial menos el capital de las cuotas registradas',
    'ir', case when (fn_tablero_capas() ->> 'c13')::boolean and cardinality(v_ctas) > 0
               then jsonb_build_object('pagina', 'cedula', 'sub', 'cedula', 'cuenta', v_ctas[1])
               else jsonb_build_object('pagina', 'estados', 'sub', 'balance') end);
end $$;
revoke execute on function public.fn_tablero_prestamos_de(jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero_prestamos_de(jsonb) to authenticated;
comment on function public.fn_tablero_prestamos_de(jsonb) is 'c16: arma la tarjeta de los préstamos con sus cuotas que vienen (las de fn_tablero_cuotas, en jsonb). La tarjeta es fn_tablero_prestamos. Solo el dueño.';

create or replace function public.fn_tablero_prestamos() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_tablero_exigir_dueno();
  return fn_tablero_prestamos_de((select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
                                    from fn_tablero_cuotas((date_trunc('month', fn_tablero_hoy()) + interval '12 months')::date - 1) x));
end $$;
revoke execute on function public.fn_tablero_prestamos() from public, anon, service_role;
grant  execute on function public.fn_tablero_prestamos() to authenticated;
comment on function public.fn_tablero_prestamos() is 'c16: los préstamos (v_prestamos de c6; los vigentes y los que tengan saldo): {ok, tarjeta: «prestamos», corte, lista: [{prestamo_id, prestamista, descripcion, estado, saldo (lo que se debe), principal, pagado_pct (lo pagado del principal), cuota, tasa_anual, cuotas_al_anio, frecuencia (en llano), cuotas_registradas, ultima_cuota, porcion_corriente, porcion_largo_plazo, cuentas, proxima: {fecha, monto, capital, interes, saldo_despues, atrasada, dias (de hoy a su fecha)}}], totales: {saldo, n, porcion_corriente, proxima: {fecha, monto, prestamista, atrasada, dias}, en_30_dias (las cuotas de los próximos 30 días, con las atrasadas), atrasadas}, libro: {saldo (el de sus cuentas en el libro), cuentas, igual, texto}, regla, fuente, ir}. Sin c6: {ok: false, falta: «c6»}. Solo lee. Solo el dueño.';


-- 3.10 · EL SALDO DE CAJA mes a mes, y UNA PROYECCIÓN con lo que de verdad
-- se sabe.
--   LA CAJA es el efectivo del balance de c4 (las cuentas que su mapeo
--   marca «efectivo»: bancos, reserva, Stripe en tránsito, caja chica; una
--   cuenta en rojo es sobregiro y va aparte). Mes a mes, lo de
--   v_flujo_real_por_mes de c4 (lo que enseña Estados → Flujo de caja): el
--   efectivo al empezar y al terminar cada mes, lo que entró y lo que salió
--   de verdad. Trae los meses que el libro tiene, hasta p_meses: nunca uno
--   inventado; el primero arranca con el saldo de la apertura. HOY: el
--   saldo del libro con todo lo fechado hasta hoy, y en llano de qué cuentas
--   sale (los bancos y Stripe en tránsito: por eso no es la cifra de la
--   tarjeta de bancos).
--   SIN LA APERTURA EN EL LIBRO (el saldo del banco al 30-sep todavía no
--   entró), la caja de aquí NO es lo que hay en el banco: es solo lo que
--   entró y salió desde que empezó el libro. Se dice, no se da la alarma de
--   sobregiro (sería falsa) y no hay proyección (no hay de dónde partir).
--   LA PROYECCIÓN (p_proyeccion meses, contando el de hoy; 0 = sin ella),
--   marcada como tal, con una línea visible (aviso) que dice lo que NO
--   cuenta y que la caja real será menor:
--     hoy
--     + lo POR COBRAR en su vencimiento (lo vencido hasta hace 60 días, en el
--       mes de hoy; lo vencido hace MÁS de 60 días y lo de una factura con
--       un cheque devuelto no se cuenta: se dice cuánto es)
--     − lo POR PAGAR en su vencimiento (lo ya vencido, en el mes de hoy)
--     − las CUOTAS de los préstamos (c6) en su fecha (las que faltan por
--       registrar, en el mes de hoy)
--     − el USE TAX por su regla (el DR-15: lo de un mes se paga a más tardar
--       el 20 del mes que sigue; lo que ya se debía de antes, el 20 de este
--       mes, o hoy si ya pasó)
--     ± lo que el LIBRO ya tiene con fecha de después de hoy (un cheque
--       posfechado: sale en su día), salvo lo que ya va por otro lado (un
--       pago posfechado de una factura, de una cuota o del use tax).
--   NO incluye nada que el libro no tenga con fecha (lo que falta facturar
--   o comprar, la nómina, la renta, lo de las tarjetas, la retención, lo
--   que se debe de la nómina, lo devengado, la línea de crédito): lo dice en
--   «no_incluye», con sus montos. Si no hay nada que proyectar en esos meses,
--   NO HAY PROYECCIÓN.
--   p_cxc, p_cxp y p_cuotas: las partidas y las cuotas ya leídas (jsonb de
--   fn_tablero_cxc, fn_tablero_cxp y fn_tablero_cuotas); nulas, sin ellas.
create or replace function public.fn_tablero_caja_de(p_meses int, p_proyeccion int, p_cxc jsonb, p_cxp jsonb, p_cuotas jsonb)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy    date := fn_tablero_hoy();
  v_lib    jsonb;
  v_libro  date;
  v_ap     date;
  v_en     boolean;
  v_meses  int := coalesce(p_meses, 12);
  v_proy   int := coalesce(p_proyeccion, 3);
  v_mhoy   date := date_trunc('month', fn_tablero_hoy())::date;
  v_m0     date;
  v_fin    date;
  v_hist   jsonb;
  v_ctas   jsonb;
  v_saldo  numeric;
  v_sobre  numeric;
  v_neto   numeric;
  v_ini    numeric;     -- el efectivo con que empieza el mes de hoy, según v_flujo_real_por_mes
  v_ini_l  numeric;     -- lo mismo, sumado del libro (el cuadre)
  v_pm     jsonb;
  v_hay    boolean := false;
  v_serie  jsonb := '[]'::jsonb;
  v_no     jsonb := '[]'::jsonb;
  v_sin    text;
  v_aviso  text;
  v_hoytx  text;
  v_antes  text;
  v_ut     text;        -- la cuenta del use tax
  v_ut_s0  numeric := 0;
  v_ut_p   numeric := 0;
  v_ut_h   numeric := 0;
  v_ut_v   numeric := 0;   -- lo del use tax que ya se debía al empezar el mes (y sigue sin pagar)
  v_ut_n   numeric := 0;   -- lo de este mes
  v_mod    text[];      -- las cuentas que la proyección ya lleva por su regla (para no contar dos veces un pago posfechado)
  v_pres   text[];      -- las cuentas de los préstamos (c6)
  v_efe    text[];      -- las cuentas de efectivo
  v_dev    bigint[] := '{}';   -- las facturas con un cheque devuelto
  v_sal    jsonb;       -- lo que salió de la caja en los meses terminados
  v_sob_m  numeric;     -- el mes de hoy, HASTA HOY: lo que cambió el sobregiro, como c4
  v_caj_m  numeric;     -- (y la caja chica en rojo: no se pinta; c4 lo junta con el financiamiento)
  v_neto_m numeric;     -- el mes de hoy, hasta hoy: el neto del efectivo
  v_mov    record;      -- el mes de hoy: lo que entró y salió hasta hoy, y lo que tiene fecha de después de hoy
  v_fmes   date := (date_trunc('month', fn_tablero_hoy()) + interval '1 month')::date - 1;   -- el último día del mes de hoy
  v_c15    boolean := to_regclass('public.v_nomina_corridas') is not null and to_regclass('public.nomina_config') is not null;   -- (11c)
  v_nom    jsonb := '[]'::jsonb;   -- (11c) lo que se debe de la nómina, por día (fn_tablero_nomina_pagos)
  r        record;
  w        record;
begin
  perform fn_tablero_exigir_dueno();
  if v_meses < 1 or v_meses > 36 then
    raise exception using errcode = '22023', message = format('Los meses de la serie van de 1 a 36 (llegó %s).', v_meses);
  end if;
  if v_proy < 0 or v_proy > 12 then
    raise exception using errcode = '22023', message = format('Los meses de la proyección van de 0 a 12 (llegó %s).', v_proy);
  end if;
  v_lib := fn_tablero_libro();
  v_libro := (v_lib ->> 'desde')::date;
  v_ap := (v_lib ->> 'apertura')::date;
  v_en := coalesce((v_lib ->> 'apertura_en_el_libro')::boolean, false);
  if v_libro is null then
    return fn_tablero_no('caja', 'El libro no tiene períodos todavía.');
  end if;
  if v_libro > v_hoy then
    return fn_tablero_no('caja', format('El libro empieza el %s: todavía no hay ningún mes que enseñar.', v_lib ->> 'empieza'));
  end if;
  v_m0 := greatest(date_trunc('month', v_libro)::date, (v_mhoy - make_interval(months => v_meses - 1))::date);
  v_efe := array(select m.cuenta from fn_tablero_mapa() m where m.efectivo);
  -- LOS MESES (los de v_flujo_real_por_mes de c4 que caen en la serie; la vista se lee UNA vez)
  with f as materialized (
    select x.desde, x.efectivo_inicial, x.entradas, x.salidas, x.neto, x.sobregiro, x.efectivo_final, x.asientos
      from v_flujo_real_por_mes x
     where x.desde >= v_m0 and x.desde <= v_mhoy
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'mes', to_char(g.mes, 'YYYY-MM'), 'etiqueta', fn_tablero_mes(g.mes), 'corto', fn_tablero_mes_corto(g.mes),
           'desde', g.mes, 'hasta', (g.mes + interval '1 month')::date - 1,
           -- (un mes que c4 no trae no tiene efectivo ni movimientos de efectivo: va en cero, no se salta)
           'inicial', coalesce(f.efectivo_inicial, 0), 'entradas', coalesce(f.entradas, 0), 'salidas', coalesce(f.salidas, 0),
           'neto', coalesce(f.neto, 0), 'sobregiro', coalesce(f.sobregiro, 0), 'final', coalesce(f.efectivo_final, 0),
           'asientos', coalesce(f.asientos, 0),
           'en_curso', g.mes = v_mhoy, 'sin_movimientos', coalesce(f.asientos, 0) = 0) order by g.mes), '[]'::jsonb),
         coalesce((select f2.efectivo_inicial from f f2 where f2.desde = v_mhoy), 0)
    into v_hist, v_ini
    from (select gs::date as mes from generate_series(v_m0::timestamp, v_mhoy::timestamp, interval '1 month') gs) g
    left join f on f.desde = g.mes;
  -- HOY, del libro: cada cuenta de efectivo con lo fechado hasta hoy (y hasta el fin del mes pasado, para el cuadre)
  with ef as materialized (
    select m.cuenta, m.nombre, m.caja from fn_tablero_mapa() m where m.efectivo
  ), s as (
    select ef.cuenta, ef.nombre, ef.caja,
           coalesce(sum(l.monto) filter (where a.fecha_contable <= v_hoy), 0) as hoy,
           coalesce(sum(l.monto) filter (where a.fecha_contable < v_mhoy), 0) as ini
      from ef
      left join asiento_lineas l on l.cuenta = ef.cuenta
      left join asientos a on a.id = l.asiento_id
     group by ef.cuenta, ef.nombre, ef.caja
  )
  select coalesce(sum(greatest(s.hoy, 0)), 0)::numeric(14,2), coalesce(-sum(least(s.hoy, 0)), 0)::numeric(14,2),
         coalesce(sum(greatest(s.ini, 0)), 0)::numeric(14,2),
         coalesce(jsonb_agg(jsonb_build_object('cuenta', s.cuenta, 'nombre', s.nombre, 'saldo', s.hoy::numeric(14,2)) order by s.cuenta)
                    filter (where s.hoy <> 0), '[]'::jsonb),
         coalesce(sum(least(s.ini, 0) - least(s.hoy, 0)) filter (where not s.caja), 0)::numeric(14,2),
         coalesce(sum(least(s.ini, 0) - least(s.hoy, 0)) filter (where s.caja), 0)::numeric(14,2),
         coalesce(sum(s.hoy - s.ini), 0)::numeric(14,2)
    into v_saldo, v_sobre, v_ini_l, v_ctas, v_sob_m, v_caj_m, v_neto_m
    from s;
  v_neto := v_saldo - v_sobre;
  -- EL MES DE HOY, HASTA HOY (la revisión final): lo que la tarjeta dice del mes en curso es «hasta hoy», como la caja de hoy; lo
  -- que tiene fecha de DESPUÉS de hoy en este mes (un cheque posfechado) no va ahí —c4 lo pone en el mes entero, y su «al
  -- terminar» ya no era la caja de hoy—: va aparte, con su texto. Con la regla de c4 (v_flujo_real_por_mes): por asiento, su neto
  -- de efectivo (un traspaso entre cuentas de caja no entra ni sale); un error y su reverso, los dos de este mes y hasta hoy,
  -- tampoco. Al terminar = el efectivo de hoy (las cuentas en negro), como el punto «hoy» de la línea.
  with mv as materialized (
    select a.id, a.fecha_contable as f, a.camino, a.reversa_a, sum(l.monto) as neto
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where l.cuenta = any (v_efe) and a.fecha_contable between v_mhoy and v_fmes
     group by a.id, a.fecha_contable, a.camino, a.reversa_a
  ), par as (
    select mv.id from mv
     where mv.f <= v_hoy
       and ((mv.camino = 'reverso' and exists (select 1 from asientos ao where ao.id = mv.reversa_a and ao.fecha_contable between v_mhoy and v_fmes))
            or exists (select 1 from asientos ar where ar.reversa_a = mv.id and ar.camino = 'reverso' and ar.fecha_contable between v_mhoy and v_hoy))
  )
  select coalesce(sum(mv.neto) filter (where mv.f <= v_hoy and mv.neto > 0 and mv.id not in (select par.id from par)), 0)::numeric(14,2) as entradas,
         coalesce(-sum(mv.neto) filter (where mv.f <= v_hoy and mv.neto < 0 and mv.id not in (select par.id from par)), 0)::numeric(14,2) as salidas,
         count(*) filter (where mv.f <= v_hoy) as asientos,
         count(*) filter (where mv.f > v_hoy) as d_asientos,
         coalesce(sum(mv.neto) filter (where mv.f > v_hoy and mv.neto > 0), 0)::numeric(14,2) as d_entradas,
         coalesce(-sum(mv.neto) filter (where mv.f > v_hoy and mv.neto < 0), 0)::numeric(14,2) as d_salidas
    into v_mov
    from mv;
  select jsonb_agg(case when (h ->> 'mes') = to_char(v_mhoy, 'YYYY-MM')
                        then h || jsonb_build_object(
                               'entradas', v_mov.entradas, 'salidas', v_mov.salidas, 'neto', v_neto_m,
                               'sobregiro', v_sob_m, 'final', v_saldo, 'asientos', v_mov.asientos,
                               'sin_movimientos', v_mov.asientos = 0, 'corte', v_hoy,
                               'despues_de_hoy', case when v_mov.d_asientos > 0 then jsonb_build_object(
                                   'asientos', v_mov.d_asientos, 'entradas', v_mov.d_entradas, 'salidas', v_mov.d_salidas,
                                   'texto', format('Además, %s de %s %s fecha de después de hoy (%s): no %s en lo de hoy.',
                                                   fn_tablero_plural(v_mov.d_asientos, 'asiento', 'asientos'), fn_tablero_mes_largo(v_mhoy),
                                                   case when v_mov.d_asientos = 1 then 'tiene' else 'tienen' end,
                                                   concat_ws(' y ', case when v_mov.d_entradas > 0 then 'entra ' || fn_tablero_usd(v_mov.d_entradas) end,
                                                                     case when v_mov.d_salidas > 0 then 'sale ' || fn_tablero_usd(v_mov.d_salidas) end,
                                                                     case when v_mov.d_entradas = 0 and v_mov.d_salidas = 0 then 'entre cuentas de la caja' end),
                                                   case when v_mov.d_asientos = 1 then 'va' else 'van' end)) end)
                        else h end order by o)
    into v_hist
    from jsonb_array_elements(v_hist) with ordinality t(h, o);
  v_hist := coalesce(v_hist, '[]'::jsonb);
  -- (de qué cuentas sale la caja de hoy, en llano: «Banco operativo ($34,612.81) y Stripe — cobros en tránsito ($860.00)»)
  select case when count(*) = 0 then null
              when count(*) = 1 then min(t.x)
              else array_to_string((array_agg(t.x order by t.o))[1:count(*) - 1], ', ') || ' y ' || (array_agg(t.x order by t.o))[count(*)] end
    into v_hoytx
    from (select (c ->> 'nombre') || ' (' || fn_tablero_usd((c ->> 'saldo')::numeric) || ')' as x, o
            from jsonb_array_elements(v_ctas) with ordinality u(c, o)) t;
  v_hoytx := case when not v_en and v_ap is not null
                    then format('La apertura (lo que había en el banco al %s) todavía no está en el libro: esto NO es lo que hay en el banco, '
                                'solo lo que entró y salió desde el %s.', fn_tablero_dia(v_ap), fn_tablero_dia(v_libro))
                  when not v_en
                    then format('El libro empezó el %s sin apertura: esto es solo lo que entró y salió desde entonces, no lo que hay en el banco.',
                                fn_tablero_dia(v_libro))
                  when v_hoytx is null then 'Ninguna cuenta de caja tiene saldo hoy.'
                  else format('La caja de hoy junta %s.', v_hoytx)
                       || case when v_sobre > 0 then format(' Una cuenta está en rojo: sobregiro de %s.', fn_tablero_usd(v_sobre)) else '' end end;
  -- (lo de antes del libro, en llano y con las mismas palabras que el libro: con apertura en el libro, o sin ella todavía)
  v_antes := case when (v_mhoy - make_interval(months => v_meses - 1))::date >= date_trunc('month', v_libro)::date then null
                  when v_en then format('El libro empieza con la apertura al %s: los meses de antes viven en QuickBooks y no se pintan.',
                                        fn_tablero_dia(v_ap))
                  when v_ap is not null then format('El libro empieza el %s; la apertura al %s todavía no está en el libro. Los meses de antes '
                                                    'viven en QuickBooks y no se pintan.', fn_tablero_dia(v_libro), fn_tablero_dia(v_ap))
                  else format('El libro empieza el %s: los meses de antes viven en QuickBooks y no se pintan.', fn_tablero_dia(v_libro)) end;
  -- LA LÍNEA: la apertura, el cierre de cada mes terminado, hoy y lo proyectado
  if v_ap is not null and v_en and v_m0 = date_trunc('month', v_libro)::date and jsonb_array_length(v_hist) > 0 then
    v_serie := v_serie || jsonb_build_object('fecha', v_ap, 'etiqueta', fn_tablero_dia(v_ap), 'saldo', v_hist -> 0 -> 'inicial',
                                             'tipo', 'apertura');
  end if;
  select v_serie || coalesce(jsonb_agg(jsonb_build_object('fecha', (h ->> 'hasta')::date, 'mes', h ->> 'mes',
                                                          'etiqueta', fn_tablero_dia((h ->> 'hasta')::date), 'saldo', h -> 'final',
                                                          'tipo', 'cierre') order by h ->> 'mes'), '[]'::jsonb)
    into v_serie
    from jsonb_array_elements(v_hist) h
   where (h ->> 'hasta')::date < v_hoy and h -> 'final' is not null and h -> 'final' <> 'null'::jsonb;
  v_serie := v_serie || jsonb_build_object('fecha', v_hoy, 'etiqueta', 'hoy', 'saldo', v_saldo, 'tipo', 'hoy');
  -- LA PROYECCIÓN
  if v_proy = 0 then
    v_sin := 'No se pidió proyección.';
  elsif not v_en then
    v_sin := case when v_ap is not null
                  then format('La apertura (lo que había en el banco al %s) todavía no está en el libro: sin ella no hay de dónde partir.', fn_tablero_dia(v_ap))
                  else 'El libro no tiene apertura: sin lo que había en el banco al empezar no hay de dónde partir.' end;
  else
    v_fin := (v_mhoy + make_interval(months => v_proy))::date - 1;
    -- (las cuentas que la proyección ya lleva por su regla: un pago posfechado contra ellas no se cuenta otra vez)
    v_ut := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'use_tax'), '2300');
    v_mod := array(select pc.cuenta from puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc', 'cxp')
                   union select m.cuenta from fn_tablero_mapa() m where m.estado = 'balance' and m.linea in ('retencion_por_pagar', 'prestamos_corto', 'prestamos_largo')
                   union select v_ut);
    if to_regclass('public.v_prestamos') is not null then
      execute $q$select array(select distinct u from public.v_prestamos v, unnest(array[v.cuenta, v.cuenta_largo]) u where u is not null)$q$
        into v_pres;
    end if;
    -- (las facturas con un cheque devuelto de verdad —no la devolución técnica de Stripe—: lo suyo no se cuenta como cobrado)
    if to_regclass('public.stripe_pago_libro') is not null then
      execute $q$select coalesce(array_agg(distinct ap.factura_id), '{}'::bigint[])
                   from public.aplicaciones_cobro ap join public.cobros_devoluciones d on d.cobro_id = ap.cobro_id
                  where ap.factura_id is not null
                    and not exists (select 1 from public.stripe_pago_libro pd where pd.devolucion_id = d.id)$q$ into v_dev;
    else
      select coalesce(array_agg(distinct ap.factura_id), '{}'::bigint[]) into v_dev
        from aplicaciones_cobro ap join cobros_devoluciones d on d.cobro_id = ap.cobro_id
       where ap.factura_id is not null;
    end if;
    -- EL USE TAX (la 2300) por la regla del DR-15
    v_ut_s0 := -fn_tablero_saldo(array[v_ut], v_mhoy - 1);
    select coalesce(sum(l.monto) filter (where l.monto > 0), 0) into v_ut_p
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where l.cuenta = v_ut and a.fecha_contable between v_mhoy and v_hoy;
    v_ut_h := -fn_tablero_saldo(array[v_ut], v_hoy);
    v_ut_v := greatest(least(v_ut_s0 - v_ut_p, v_ut_h), 0);
    v_ut_n := greatest(v_ut_h - v_ut_v, 0);
    -- (14-nov, Fase 11c) LA NÓMINA: con c15, lo que se debe de ella según el libro sale el día de pago de su nómina ya posteada
    -- (la que lo tiene después de hoy) y lo demás hoy (fn_tablero_nomina_pagos: sin contar dos veces lo que Gusto ya cobró)
    if v_c15 then
      select coalesce(jsonb_agg(jsonb_build_object('f', x.fecha, 'monto', x.monto, 'asiento', x.asiento)), '[]'::jsonb) into v_nom
        from fn_tablero_nomina_pagos() x;
    end if;
    with c as (
      select greatest(x.vence, v_hoy) as f, x.por_cobrar as monto, x.vence < v_hoy as vencido
        from jsonb_to_recordset(coalesce(p_cxc, '[]'::jsonb)) as x(por_cobrar numeric, vence date, tramo text, dias_vencida int, factura_id bigint)
       where x.por_cobrar > 0 and x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas')
         and coalesce(x.dias_vencida, 0) <= 60 and not coalesce(x.factura_id = any (v_dev), false)
    ), p as (
      select greatest(x.vence, v_hoy) as f, x.por_pagar as monto, x.vence < v_hoy as vencido
        from jsonb_to_recordset(coalesce(p_cxp, '[]'::jsonb)) as x(por_pagar numeric, vence date, tramo text)
       where x.por_pagar > 0 and x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas')
    ), q as (
      select greatest(x.fecha, v_hoy) as f, x.monto, x.atrasada
        from jsonb_to_recordset(coalesce(p_cuotas, '[]'::jsonb)) as x(fecha date, monto numeric, atrasada boolean)
    ), u as (
      -- (el use tax: lo de antes, el 20 de este mes —u hoy, si ya pasó—; lo de este mes, el 20 del que sigue)
      select greatest(v_mhoy + 19, v_hoy) as f, v_ut_v as monto, v_hoy > v_mhoy + 19 as vencido where v_ut_v > 0
      union all
      select (v_mhoy + interval '1 month')::date + 19, v_ut_n, false where v_ut_n > 0
    ), nm as (
      -- (11c) lo que se debe de la nómina, en su día (lo de después del último mes de la proyección no entra: va en «no incluye»)
      select greatest(x.f, v_hoy) as f, x.monto from jsonb_to_recordset(v_nom) as x(f date, monto numeric)
    ), lb as (
      -- (lo que el libro ya tiene en la caja con fecha de después de hoy, salvo lo que va por otro lado)
      select a.fecha_contable as f, l.monto
        from asiento_lineas l join asientos a on a.id = l.asiento_id
       where l.cuenta = any (v_efe) and a.fecha_contable > v_hoy and a.fecha_contable <= v_fin
         and not exists (select 1 from asiento_lineas l2 where l2.asiento_id = a.id and l2.cuenta = any (v_mod || coalesce(v_pres, '{}'::text[])))
    ), ms as (
      select g::date as mes, ((g + interval '1 month')::date - 1) as hasta
        from generate_series(v_mhoy::timestamp, v_fin::timestamp, interval '1 month') g
    ), k as (
      select ms.mes, ms.hasta,
             coalesce((select sum(c.monto) from c where c.f between ms.mes and ms.hasta), 0)::numeric(14,2) as cobrar,
             coalesce((select sum(c.monto) from c where c.vencido and c.f between ms.mes and ms.hasta), 0)::numeric(14,2) as cobrar_vencido,
             coalesce((select sum(p.monto) from p where p.f between ms.mes and ms.hasta), 0)::numeric(14,2) as pagar,
             coalesce((select sum(p.monto) from p where p.vencido and p.f between ms.mes and ms.hasta), 0)::numeric(14,2) as pagar_vencido,
             coalesce((select sum(q.monto) from q where q.f between ms.mes and ms.hasta), 0)::numeric(14,2) as cuotas,
             coalesce((select sum(q.monto) from q where q.atrasada and q.f between ms.mes and ms.hasta), 0)::numeric(14,2) as cuotas_atrasadas,
             coalesce((select sum(u.monto) from u where u.f between ms.mes and ms.hasta), 0)::numeric(14,2) as impuestos,
             coalesce((select sum(nm.monto) from nm where nm.f between ms.mes and ms.hasta), 0)::numeric(14,2) as nomina,
             coalesce((select sum(lb.monto) from lb where lb.f between ms.mes and ms.hasta), 0)::numeric(14,2) as libro
        from ms
    ), z as (
      select k.*, (k.cobrar - k.pagar - k.cuotas - k.impuestos - k.nomina + k.libro)::numeric(14,2) as neto,
             (v_neto + sum(k.cobrar - k.pagar - k.cuotas - k.impuestos - k.nomina + k.libro) over (order by k.mes))::numeric(14,2) as saldo
        from k
    )
    select coalesce(jsonb_agg(jsonb_build_object(
             'mes', to_char(z.mes, 'YYYY-MM'), 'etiqueta', fn_tablero_mes(z.mes), 'corto', fn_tablero_mes_corto(z.mes), 'hasta', z.hasta,
             'cobrar', z.cobrar, 'cobrar_vencido', z.cobrar_vencido, 'pagar', z.pagar, 'pagar_vencido', z.pagar_vencido,
             'cuotas', z.cuotas, 'cuotas_atrasadas', z.cuotas_atrasadas, 'impuestos', z.impuestos,
             -- (11c) lo que se debe de la nómina en el mes (solo con c15: sin ella, nulo)
             'nomina', case when v_c15 then z.nomina end, 'libro', z.libro,
             'neto', z.neto, 'saldo', z.saldo) order by z.mes), '[]'::jsonb),
           coalesce(bool_or(z.cobrar <> 0 or z.pagar <> 0 or z.cuotas <> 0 or z.impuestos <> 0 or z.nomina <> 0 or z.libro <> 0), false)
      into v_pm, v_hay
      from z;
    if v_hay then
      select v_serie || coalesce(jsonb_agg(jsonb_build_object('fecha', (e ->> 'hasta')::date, 'mes', e ->> 'mes',
                                                              'etiqueta', fn_tablero_dia((e ->> 'hasta')::date), 'saldo', e -> 'saldo',
                                                              'tipo', 'proyeccion') order by e ->> 'mes'), '[]'::jsonb)
        into v_serie
        from jsonb_array_elements(v_pm) e;
    else
      v_sin := 'No hay nada con fecha por cobrar, por pagar, de cuotas de préstamos, de impuestos ni de la nómina en esos meses: sin proyección.';
    end if;
    -- LO QUE NO INCLUYE, con sus montos (lo que el libro sí sabe pero no tiene fecha, o no se cuenta a propósito)
    select coalesce(sum(x.retencion), 0)::numeric(14,2) as ret_c,
           coalesce(sum(x.por_cobrar) filter (where x.tramo = 'sin_vencimiento'), 0)::numeric(14,2) as sinv_c,
           coalesce(sum(x.por_cobrar) filter (where x.por_cobrar > 0 and x.vence > v_fin), 0)::numeric(14,2) as despues_c,
           coalesce(sum(x.por_cobrar) filter (where x.por_cobrar > 0 and x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')
                                              and coalesce(x.dias_vencida, 0) > 60 and not coalesce(x.factura_id = any (v_dev), false)), 0)::numeric(14,2) as viejo_c,
           count(*) filter (where x.por_cobrar > 0 and x.tramo in ('d1_30', 'd31_60', 'd61_90', 'd90_mas')
                              and coalesce(x.dias_vencida, 0) > 60 and not coalesce(x.factura_id = any (v_dev), false)) as n_viejo_c,
           coalesce(sum(x.por_cobrar) filter (where x.por_cobrar > 0 and x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas')
                                              and coalesce(x.factura_id = any (v_dev), false)), 0)::numeric(14,2) as dev_c,
           count(*) filter (where x.por_cobrar > 0 and x.tramo in ('corriente', 'd1_30', 'd31_60', 'd61_90', 'd90_mas')
                              and coalesce(x.factura_id = any (v_dev), false)) as n_dev_c
      into r
      from jsonb_to_recordset(coalesce(p_cxc, '[]'::jsonb)) as x(por_cobrar numeric, retencion numeric, vence date, tramo text, dias_vencida int, factura_id bigint);
    select coalesce(sum(x.retencion), 0)::numeric(14,2) as ret_p,
           coalesce(sum(x.por_pagar) filter (where x.tramo = 'sin_vencimiento'), 0)::numeric(14,2) as sinv_p,
           coalesce(sum(x.por_pagar) filter (where x.por_pagar > 0 and x.vence > v_fin), 0)::numeric(14,2) as despues_p
      into w
      from jsonb_to_recordset(coalesce(p_cxp, '[]'::jsonb)) as x(por_pagar numeric, retencion numeric, vence date, tramo text);
    v_no := jsonb_build_array(
      jsonb_build_object('clave', 'sin_fecha', 'texto', case when v_c15
                                                             then 'Lo que todavía no está en el libro: lo que falta facturar o comprar, las nóminas '
                                                                  'que Gusto todavía no ha corrido, la renta, los seguros y los demás gastos que se repiten.'
                                                             else 'Lo que todavía no está en el libro: lo que falta facturar o comprar, la nómina, la '
                                                                  'renta, los seguros y los demás gastos que se repiten.' end),
      jsonb_build_object('clave', 'tarjetas', 'texto', 'Lo que se debe en las tarjetas: no se sabe cuándo se paga.',
                         'monto', (select -fn_tablero_saldo(array_agg(m.cuenta), v_hoy) from fn_tablero_mapa() m
                                    where m.estado = 'balance' and m.linea = 'tarjetas')),
      jsonb_build_object('clave', 'retencion', 'texto', 'La retención: la que se cobra y la que se paga a los subs al terminar cada obra.',
                         'cobrar', r.ret_c, 'pagar', w.ret_p))
      -- (las otras deudas de corto plazo del libro, por su renglón del balance: lo que se debe de la nómina, lo devengado, la línea de crédito…)
      -- (CON TODO LO QUE EL LIBRO TIENE en esas cuentas, también lo fechado después de hoy —la revisión final—: el journal de una
      --  nómina (c15) lleva la fecha de su día de pago y Gusto cobra del banco unos días antes: contada solo hasta hoy, esos días
      --  la deuda salía en negativo; y una nómina ya posteada con día de pago después de hoy no se decía. a_hoy y despues lo separan.)
      || coalesce((select jsonb_agg(jsonb_build_object('clave', 'deuda', 'linea', d.linea, 'etiqueta', d.etiqueta, 'monto', d.monto,
                                                       'a_hoy', d.a_hoy, 'despues', (d.monto - d.a_hoy)::numeric(14,2),
                                                       'cuentas', to_jsonb(d.cuentas),
                                                       'texto', case d.linea
                                                                  when 'nomina_por_pagar' then 'Lo que se debe de la nómina (los impuestos retenidos y lo demás): se paga con cada declaración y cada nómina.'
                                                                  when 'devengados' then 'Lo devengado que todavía no tiene su factura: sale cuando llegue.'
                                                                  when 'linea_credito' then 'La línea de crédito: el libro no tiene cuándo se paga.'
                                                                  else d.etiqueta || ': el libro no tiene cuándo se paga.' end
                                                                || case when d.monto <> d.a_hoy
                                                                        then format(' Cuenta lo que el libro ya tiene en esas cuentas con fecha de después de hoy (%s).',
                                                                                    fn_tablero_usd(d.monto - d.a_hoy))
                                                                        else '' end)
                                    order by d.orden)
                     from (select m.linea, min(coalesce(el.etiqueta_es, m.linea)) as etiqueta, min(m.orden) as orden,
                                  array_agg(m.cuenta order by m.cuenta) as cuentas,
                                  (-fn_tablero_saldo(array_agg(m.cuenta), null))::numeric(14,2) as monto,
                                  (-fn_tablero_saldo(array_agg(m.cuenta), v_hoy))::numeric(14,2) as a_hoy
                             from fn_tablero_mapa() m
                             left join estados_lineas el on el.estado = 'balance' and el.linea = m.linea
                            where m.estado = 'balance' and m.seccion = 'pasivo_circulante'
                              and m.linea not in ('cuentas_por_pagar', 'retencion_por_pagar', 'tarjetas', 'impuestos_por_pagar', 'wip_pasivo',
                                                  'provision_perdidas', 'prestamos_corto')
                            group by m.linea) d
                    -- (11c: con c15, lo que se debe de la nómina ya va en la proyección; lo que queda a favor, no: se dice aquí)
                    where d.monto <> 0 and not (v_c15 and d.linea = 'nomina_por_pagar' and d.monto > 0)), '[]'::jsonb)
      || case when r.viejo_c <> 0
              then jsonb_build_array(jsonb_build_object('clave', 'vencido_viejo', 'monto', r.viejo_c, 'n', r.n_viejo_c,
                                                        'texto', format('Lo por cobrar vencido hace más de 60 días (%s): no se cuenta como cobrado.',
                                                                        fn_tablero_plural(r.n_viejo_c, 'factura', 'facturas'))))
              else '[]'::jsonb end
      || case when r.dev_c <> 0
              then jsonb_build_array(jsonb_build_object('clave', 'cheque_devuelto', 'monto', r.dev_c, 'n', r.n_dev_c,
                                                        'texto', format('Lo de %s con un cheque devuelto: no se cuenta hasta que se cobre.',
                                                                        fn_tablero_plural(r.n_dev_c, 'factura', 'facturas'))))
              else '[]'::jsonb end
      || case when r.sinv_c <> 0 or w.sinv_p <> 0
              then jsonb_build_array(jsonb_build_object('clave', 'sin_vencimiento', 'texto', 'Lo que no se sabe cuándo vence.',
                                                        'cobrar', r.sinv_c, 'pagar', w.sinv_p))
              else '[]'::jsonb end
      || case when r.despues_c <> 0 or w.despues_p <> 0
              then jsonb_build_array(jsonb_build_object('clave', 'despues', 'texto', format('Lo que vence después del %s.', fn_tablero_dia(v_fin)),
                                                        'cobrar', r.despues_c, 'pagar', w.despues_p))
              else '[]'::jsonb end;
    -- LA LÍNEA VISIBLE: lo que no cuenta, y que la caja real será menor (con lo que de verdad salió en los meses terminados)
    select jsonb_build_object('n', count(*), 'min', min((h ->> 'salidas')::numeric), 'max', max((h ->> 'salidas')::numeric),
                              'mes', min(h ->> 'hasta'))
      into v_sal
      from jsonb_array_elements(v_hist) h
     where (h ->> 'hasta')::date < v_hoy;
    v_aviso := case when v_c15
                    then 'Proyección, no el libro: solo cuenta lo facturado por cobrar, lo por pagar, las cuotas de los préstamos, el use tax y lo que '
                         'se debe de las nóminas ya posteadas. No cuenta las nóminas que Gusto todavía no ha corrido, la renta ni los demás gastos '
                         'que se repiten: la caja real será menor.'
                    else 'Proyección, no el libro: solo cuenta lo facturado por cobrar, lo por pagar, las cuotas de los préstamos y el use tax. '
                         'No cuenta la nómina, la renta ni los demás gastos que se repiten: la caja real será menor.' end
               || case when (v_sal ->> 'n')::int = 1
                         then format(' En %s salieron de la caja %s.', fn_tablero_mes_largo(date_trunc('month', (v_sal ->> 'mes')::date)::date),
                                     fn_tablero_usd((v_sal ->> 'max')::numeric))
                       when (v_sal ->> 'n')::int > 1
                         then format(' En los meses ya terminados del libro salieron de la caja entre %s y %s al mes.',
                                     fn_tablero_usd((v_sal ->> 'min')::numeric), fn_tablero_usd((v_sal ->> 'max')::numeric))
                       else '' end;
  end if;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'caja', 'corte', v_hoy,
    'hoy', jsonb_build_object('saldo', v_saldo, 'sobregiro', v_sobre, 'neto', v_neto, 'cuentas', v_ctas,
                              -- (la alarma de sobregiro solo si la apertura está en el libro: sin ella, el saldo no es el del banco)
                              'alarma', v_en and v_sobre > 0, 'sin_apertura', not v_en, 'texto', v_hoytx,
                              'ir', jsonb_build_object('pagina', 'bancos')),
    'sin_apertura', not v_en,
    'apertura', case when v_ap is not null then jsonb_build_object('fecha', v_ap, 'en_el_libro', v_en,
                                                                   'saldo', case when v_m0 = date_trunc('month', v_libro)::date and v_en
                                                                                 then v_hist -> 0 -> 'inicial' end) end,
    'meses', v_hist, 'meses_pedidos', v_meses, 'meses_con_libro', jsonb_array_length(v_hist),
    'antes_del_libro', case when v_antes is not null then jsonb_build_object('texto', v_antes) end,
    'serie', v_serie,
    'proyeccion', case when v_proy > 0 and v_en and v_hay
                       then jsonb_build_object(
                              'meses', v_pm, 'desde', v_hoy, 'hasta', v_fin, 'saldo_inicial', v_neto,
                              'aviso', v_aviso,
                              'supuestos', jsonb_build_array(
                                 'Es una proyección, no el libro: lo que ya se sabe con fecha.',
                                 'Lo por cobrar entra el día que vence; lo vencido hasta hace 60 días, este mes. Lo vencido hace más de 60 días y lo de una factura con un cheque devuelto no se cuentan.',
                                 'Lo por pagar sale el día que vence; lo ya vencido, este mes.',
                                 'Las cuotas de los préstamos salen en su fecha, con la fórmula de c6; las que faltan por registrar, este mes.',
                                 'El use tax sale el 20 del mes que sigue al de la compra (el DR-15); lo que ya se debía, el 20 de este mes (o hoy, si ya pasó).',
                                 'Lo que el libro ya tiene con fecha de después de hoy (un cheque posfechado) sale o entra en su día.')
                               || case when v_c15 then jsonb_build_array(
                                    'Lo que se debe de la nómina (2210 a 2250, del libro) sale el día de pago de su nómina ya posteada; lo de las '
                                    'nóminas ya pagadas que sigue sin su cargo, hoy. Gusto lo cobra del banco unos días antes de cada día de pago: la '
                                    'app no sabe qué día exacto, y usa el día de pago. Lo que Gusto ya cobró y está casado no se resta otra vez.')
                                  else '[]'::jsonb end,
                              'no_incluye', v_no) end,
    'sin_proyeccion', case when not (v_proy > 0 and v_en and v_hay) then v_sin end,
    'cuadre', jsonb_build_object('ok', v_ini is null or v_ini = v_ini_l, 'libro', v_ini_l, 'vista', v_ini,
                                 'texto', 'el efectivo con que empieza este mes (el flujo de caja de c4) = el del libro al cierre del mes pasado'),
    'fuente', 'el efectivo del balance de c4 (bancos, reserva, Stripe en tránsito y caja chica): mes a mes, lo mismo que Estados → Flujo de caja; hoy, el '
              || 'libro hasta hoy; la proyección, con lo por cobrar, lo por pagar, las cuotas de los préstamos, el use tax y lo posfechado',
    'ir', jsonb_build_object('pagina', 'estados', 'sub', 'flujo', 'periodo', to_char(v_hoy, 'YYYY-MM')));
end $$;
revoke execute on function public.fn_tablero_caja_de(int, int, jsonb, jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero_caja_de(int, int, jsonb, jsonb, jsonb) to authenticated;
comment on function public.fn_tablero_caja_de(int, int, jsonb, jsonb, jsonb) is 'c16: arma el flujo de caja con las partidas por cobrar y por pagar y las cuotas ya leídas (jsonb de fn_tablero_cxc, fn_tablero_cxp y fn_tablero_cuotas). La tarjeta es fn_tablero_caja. Solo el dueño.';

create or replace function public.fn_tablero_caja(p_meses int default 12, p_proyeccion int default 3) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_proy int := coalesce(p_proyeccion, 3);
begin
  perform fn_tablero_exigir_dueno();
  if v_proy < 0 or v_proy > 12 then
    raise exception using errcode = '22023', message = format('Los meses de la proyección van de 0 a 12 (llegó %s).', v_proy);
  end if;
  return fn_tablero_caja_de(p_meses, v_proy,
    case when v_proy > 0 then (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from fn_tablero_cxc() x) end,
    case when v_proy > 0 then (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from fn_tablero_cxp() x) end,
    case when v_proy > 0 then (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
                                 from fn_tablero_cuotas((date_trunc('month', fn_tablero_hoy()) + make_interval(months => v_proy))::date - 1) x) end);
end $$;
revoke execute on function public.fn_tablero_caja(int, int) from public, anon, service_role;
grant  execute on function public.fn_tablero_caja(int, int) to authenticated;
comment on function public.fn_tablero_caja(int, int) is 'c16: el flujo de caja: {ok, tarjeta: «caja», corte, hoy: {saldo (el efectivo del libro hoy, las cuentas en negro), sobregiro, neto, cuentas: [{cuenta, nombre, saldo}], alarma (sobregiro de verdad: solo con la apertura en el libro), sin_apertura, texto (en llano: de qué cuentas sale, o que sin la apertura no es lo del banco), ir}, sin_apertura (la apertura todavía no está en el libro: la caja no es lo del banco, sin alarma ni proyección), apertura: {fecha, en_el_libro, saldo} (con lo que empezó el libro; saldo nulo si su asiento todavía no está), meses: [{mes, etiqueta, corto, desde, hasta, inicial, entradas, salidas, neto, sobregiro, final, asientos, en_curso, sin_movimientos; el de hoy además corte y despues_de_hoy: {asientos, entradas, salidas, texto}}] (v_flujo_real_por_mes de c4: solo los meses del libro, hasta p_meses; el mes que c4 no trae —sin efectivo ni movimientos— va en cero; EL MES EN CURSO, HASTA HOY, con la regla de c4: lo que entró y salió del 1 a hoy y al terminar = el efectivo de hoy; lo que tiene fecha de después de hoy en él, aparte, en despues_de_hoy), meses_pedidos, meses_con_libro, antes_del_libro: {texto} (si la serie pedida empieza antes del libro; con las palabras del libro, con o sin la apertura), serie: [{fecha, mes?, etiqueta, saldo, tipo (apertura | cierre | hoy | proyeccion)}] (la línea, en orden: la apertura si su asiento está, lo de verdad hasta hoy y lo proyectado después), proyeccion: {meses: [{mes, etiqueta, corto, hasta, cobrar, cobrar_vencido, pagar, pagar_vencido, cuotas, cuotas_atrasadas, impuestos (el use tax por la regla del DR-15), libro (lo posfechado del libro), neto, saldo}], desde, hasta, saldo_inicial, aviso (LA LÍNEA VISIBLE bajo la gráfica: lo que no cuenta y que la caja real será menor, con lo que salió de verdad en los meses terminados), supuestos: [texto], no_incluye: [{clave (sin_fecha | tarjetas | retencion | deuda | vencido_viejo | cheque_devuelto | sin_vencimiento | despues), texto, monto? | cobrar?, pagar?, n?, linea?, etiqueta?, cuentas?, a_hoy? y despues? (deuda: su monto es todo lo que el libro tiene en esas cuentas; a_hoy, lo de hasta hoy; despues, lo fechado después)}]} (nulo sin apertura en el libro o sin nada con fecha), sin_proyeccion (por qué no hay), cuadre: {ok, libro, vista, texto}, fuente, ir}. p_meses de 1 a 36 (12); p_proyeccion de 0 a 12 (3), contando el mes de hoy. 22023 fuera de rango. Solo lee. Solo el dueño.';

-- 3.11 · LAS CONEXIONES: lo que la app tiene conectado con el mundo. Cada
-- banco por Plaid (c7), Stripe (p1) y la IA contable (c8). «Conectada»: al
-- día; «con problemas»: pide algo (volver a entrar al banco, una cuenta del
-- banco sin fijar, un banco que lleva más de dos días sin traer nada —la
-- rutina de Plaid es diaria—, un control de su capa en rojo, un error
-- después de lo último que salió bien); «apagada»: la IA contable
-- desactivada. Lo que no está instalado va aparte (sin_instalar).
-- EN LLANO: en la portada va UNA línea que Edgar entiende («El banco pide
-- volver a entrar», «La IA contable no está configurada»), sin códigos, sin
-- nombres de secretos, sin fechas AAAA-MM-DD ni textos cortados; lo que
-- dijo cada capa, tal cual, va en «tecnico» (para la página Conexiones y
-- para soporte). p_stripe: lo de fn_tablero_stripe.
create or replace function public.fn_tablero_conexiones_de(p_stripe jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy  date := fn_tablero_hoy();
  v_l    jsonb := '[]'::jsonb;
  v_no   jsonb := '[]'::jsonb;
  v_desc int := 0;
  v_n    int;
  v_r    jsonb;
  v_t    text[];
  r      record;
begin
  perform fn_tablero_exigir_dueno();
  -- LOS BANCOS POR PLAID (c7)
  if to_regclass('public.plaid_conexiones') is not null then
    for r in execute $q$select c.id, c.institucion, c.estado, c.ultimo_sync, c.ultimo_error, c.creado_el,
                               (select count(*) from jsonb_array_elements(c.cuentas) x where x ->> 'cuenta' is null) as sin_fijar,
                               (select count(*) from jsonb_array_elements(c.cuentas) x where x ->> 'cuenta' is not null) as fijas
                          from public.plaid_conexiones c
                         order by c.creado_el, c.id$q$ loop
      if r.estado = 'desconectada' then
        v_desc := v_desc + 1;
        continue;
      end if;
      v_l := v_l || jsonb_build_object(
        'tipo', 'banco', 'nombre', coalesce(r.institucion, 'Un banco') || ' (Plaid)',
        'estado', case when r.estado = 'error' or r.sin_fijar > 0 or now() - r.ultimo_sync > interval '48 hours' then 'con_problemas'
                       else 'conectada' end,
        'detalle', case when r.estado = 'error'
                          then case when coalesce(r.ultimo_error, '') ~* 'ITEM_LOGIN_REQUIRED|login|credencial|contraseña'
                                    then 'El banco pide volver a entrar: hay que volver a conectarlo.'
                                    else 'El banco no deja traer los movimientos: hay que volver a conectarlo.' end
                        when r.sin_fijar > 0 then format('%s del banco sin decir a qué cuenta va: hasta decirlo no se trae nada.',
                                                         fn_tablero_plural(r.sin_fijar, 'cuenta', 'cuentas'))
                        when r.ultimo_sync is null then 'Conectado; todavía no ha traído movimientos.'
                        when now() - r.ultimo_sync > interval '48 hours'
                          then format('No trae nada desde %s (lo trae cada mañana).', fn_tablero_hace(r.ultimo_sync))
                        else format('Al día: lo trajo %s.', fn_tablero_hace(r.ultimo_sync)) end,
        'tecnico', r.ultimo_error,
        'ultimo_sync', r.ultimo_sync, 'cuentas', r.fijas,
        'ir', jsonb_build_object('pagina', 'conexiones'));
    end loop;
  else
    v_no := v_no || jsonb_build_object('tipo', 'banco', 'nombre', 'Los bancos por Plaid', 'falta', 'c7');
  end if;
  -- STRIPE (p1)
  if p_stripe is not null then
    v_r := p_stripe -> 'rojos';
    -- (sus alarmas en rojo, cada una en una frase que Edgar entiende —por su número en v_stripe_control de p1, como las de
    --  la IA abajo—, no el nombre del control entre comillas; la primera es la que manda)
    select coalesce(array_agg(x.f order by x.o), '{}'::text[]) into v_t
      from (select o, case (e ->> 'orden')::int
                        when 22 then case when substring(e ->> 'control' from '([0-9]+) días') is not null
                                          then format('Hay cobros en línea de hace más de %s días que no se han depositado.',
                                                      substring(e ->> 'control' from '([0-9]+) días'))
                                          else 'Hay cobros en línea que llevan muchos días sin depositarse.' end
                        when 24 then 'Un depósito que Stripe ya pagó no está en el libro.'
                        when 26 then 'Un depósito de Stripe no casa con lo que trajo el banco.'
                        when 29 then 'Hay avisos de Stripe que no se han procesado.'
                        when 30 then 'Hay pagos de Stripe por revisar.'
                        when 31 then 'Un pago por cuenta de banco tarda más de lo normal.'
                        when 32 then case when e ->> 'detalle' = 'nunca ha corrido' then 'Su revisión automática nunca ha corrido.'
                                          else 'Su revisión automática no está corriendo.' end
                        when 35 then 'Hay un enlace de cobro que no está al día.'
                        when 38 then 'Hay depósitos de Stripe que llevan más de 2 días esperando o por revisar.'
                        when 39 then 'La función de Stripe tiene una llave de prueba: así no entra ningún cobro de verdad.'
                        else 'Tiene algo por revisar.' end as f
              from jsonb_array_elements(coalesce(v_r, '[]'::jsonb)) with ordinality t(e, o)
             where e ->> 'nivel' is distinct from 'cuadre') x;
    v_l := v_l || jsonb_build_object(
      'tipo', 'cobros', 'nombre', 'Stripe (cobros en línea)',
      'estado', case when coalesce((p_stripe ->> 'cuadres_rojos')::int, 0) > 0 or coalesce((p_stripe ->> 'alarmas')::int, 0) > 0
                          or (p_stripe ->> 'ultimo_error' is not null
                              and (p_stripe ->> 'ultimo_error_el')::timestamptz
                                  >= coalesce((p_stripe ->> 'ultimo_evento_el')::timestamptz, '-infinity'::timestamptz))
                          or p_stripe ->> 'modo' is null then 'con_problemas'
                     else 'conectada' end,
      'detalle', case when coalesce((p_stripe ->> 'cuadres_rojos')::int, 0) > 0
                        then 'Algo de los cobros en línea no cuadra con el libro: mira Cobros en línea.'
                      when cardinality(v_t) > 0
                        then case when cardinality(v_t) > 1
                                  then rtrim(v_t[1], '.') || format(' (y %s más: mira Cobros en línea).', cardinality(v_t) - 1)
                                  else v_t[1] end
                      when p_stripe ->> 'ultimo_error' is not null
                           and (p_stripe ->> 'ultimo_error_el')::timestamptz >= coalesce((p_stripe ->> 'ultimo_evento_el')::timestamptz, '-infinity'::timestamptz)
                        then 'Su último aviso dio error: mira Cobros en línea.'
                      when p_stripe ->> 'modo' is null then 'Instalado; todavía no ha llegado ningún aviso de Stripe.'
                      when p_stripe ->> 'modo' = 'prueba' then 'Conectado con una llave de prueba.'
                      else 'Conectado.' end,
      'tecnico', nullif(concat_ws(' | ',
                   (select string_agg((e ->> 'control') || coalesce(': ' || (e ->> 'detalle'), ''), ' | ' order by o)
                      from jsonb_array_elements(coalesce(v_r, '[]'::jsonb)) with ordinality t(e, o)),
                   p_stripe ->> 'ultimo_error'), ''),
      'modo', p_stripe ->> 'modo', 'ultimo_evento_el', p_stripe -> 'ultimo_evento_el',
      'ir', jsonb_build_object('pagina', 'conexiones'));
  else
    v_no := v_no || jsonb_build_object('tipo', 'cobros', 'nombre', 'Stripe (cobros en línea)', 'falta', 'p1');
  end if;
  -- LA IA CONTABLE (c8)
  if to_regclass('public.contador_config') is not null and to_regclass('public.v_contador_control') is not null then
    -- (lo de v_contador_estado que hace falta, leído de donde lo lee ella: su configuración y su control, una vez;
    --  «frenada» es el tope del mes, que su control dice en rojo)
    execute $q$with k as materialized (select k.nivel, k.ok, k.orden, k.control, k.detalle from public.v_contador_control k)
               select c.activa, c.ultimo_error, c.ultimo_error_el, c.ultima_rafaga_el,
                      (select count(*) from k where k.nivel = 'cuadre' and not k.ok) as cuadres_rojos,
                      (select count(*) from k where k.nivel = 'alarma' and not k.ok) as alarmas,
                      (select coalesce(array_agg(k.orden order by k.orden), '{}'::int[]) from k where k.ok is not true) as ordenes,
                      (select string_agg(k.control || coalesce(': ' || k.detalle, ''), ' | ' order by (k.nivel = 'cuadre') desc, k.orden)
                         from k where k.ok is not true) as tecnico
                 from public.contador_config c where c.id = 1$q$ into r;
    get diagnostics v_n = row_count;
    if v_n > 0 then
      -- (lo que está en rojo, cada cosa en una frase que Edgar entiende; la primera es la que manda)
      v_t := array_remove(array[
               case when r.cuadres_rojos > 0 then 'Uno de sus controles no cuadra con el libro.' end,
               case when 73 = any (r.ordenes) then 'La IA contable no está configurada: nunca ha propuesto nada.' end,
               case when 74 = any (r.ordenes) then 'Su rutina diaria no está corriendo.' end,
               case when 72 = any (r.ordenes) then 'Su última corrida dio error.' end,
               case when 70 = any (r.ordenes) then 'Llegó al tope de gasto del mes: no propone más hasta el mes que viene.' end,
               case when 71 = any (r.ordenes) then 'Hay propuestas esperando tu visto bueno desde hace más de 7 días.' end,
               case when r.alarmas > 0 and not (r.ordenes && array[70, 71, 72, 73, 74]) then 'Tiene algo por revisar.' end], null);
      v_l := v_l || jsonb_build_object(
        'tipo', 'ia', 'nombre', 'La IA contable',
        'estado', case when not coalesce(r.activa, false) then 'apagada'
                       when coalesce(r.cuadres_rojos, 0) > 0 or coalesce(r.alarmas, 0) > 0
                            or (r.ultimo_error is not null and r.ultimo_error_el >= coalesce(r.ultima_rafaga_el, '-infinity'::timestamptz))
                         then 'con_problemas'
                       else 'conectada' end,
        'detalle', case when not coalesce(r.activa, false) then 'Desactivada: no propone nada.'
                        when cardinality(v_t) > 0
                          then case when cardinality(v_t) > 1
                                    then rtrim(v_t[1], '.') || format(' (y %s más: mira Conexiones).', cardinality(v_t) - 1)
                                    else v_t[1] end
                        when r.ultimo_error is not null and r.ultimo_error_el >= coalesce(r.ultima_rafaga_el, '-infinity'::timestamptz)
                          then 'Su última corrida dio error.'
                        when r.ultima_rafaga_el is null then 'Activa; todavía no ha propuesto nada.'
                        else format('Al día: propuso %s.', fn_tablero_hace(r.ultima_rafaga_el)) end,
        'tecnico', nullif(concat_ws(' | ', r.tecnico, r.ultimo_error), ''),
        'ir', jsonb_build_object('pagina', 'conexiones'));
    end if;
  else
    v_no := v_no || jsonb_build_object('tipo', 'ia', 'nombre', 'La IA contable', 'falta', 'c8');
  end if;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'conexiones', 'corte', v_hoy,
    'total', jsonb_array_length(v_l),
    'conectadas', (select count(*) from jsonb_array_elements(v_l) e where e ->> 'estado' = 'conectada'),
    'con_problemas', (select count(*) from jsonb_array_elements(v_l) e where e ->> 'estado' = 'con_problemas'),
    'apagadas', (select count(*) from jsonb_array_elements(v_l) e where e ->> 'estado' = 'apagada'),
    'desconectadas', v_desc,
    'lista', (select coalesce(jsonb_agg(e order by case e ->> 'estado' when 'con_problemas' then 0 when 'apagada' then 1 else 2 end, o), '[]'::jsonb)
                from jsonb_array_elements(v_l) with ordinality t(e, o)),
    'sin_instalar', v_no,
    'fuente', 'las conexiones de Plaid (c7), el estado de Stripe (p1) y el de la IA contable (c8)',
    'ir', jsonb_build_object('pagina', 'conexiones'));
end $$;
revoke execute on function public.fn_tablero_conexiones_de(jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero_conexiones_de(jsonb) to authenticated;
comment on function public.fn_tablero_conexiones_de(jsonb) is 'c16: arma la tarjeta de conexiones con Stripe ya leído (lo de fn_tablero_stripe; nulo sin p1). La tarjeta es fn_tablero_conexiones. Solo el dueño.';

create or replace function public.fn_tablero_conexiones() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_tablero_exigir_dueno();
  return fn_tablero_conexiones_de(fn_tablero_stripe());
end $$;
revoke execute on function public.fn_tablero_conexiones() from public, anon, service_role;
grant  execute on function public.fn_tablero_conexiones() to authenticated;
comment on function public.fn_tablero_conexiones() is 'c16: lo que la app tiene conectado: {ok, tarjeta: «conexiones», corte, total, conectadas, con_problemas, apagadas, desconectadas (bancos de Plaid dados de baja: no cuentan), lista: [{tipo (banco | cobros | ia), nombre, estado (conectada | con_problemas | apagada; un banco que lleva más de 48 horas sin traer nada, con problemas), detalle (UNA línea en llano: qué pide, sin códigos ni fechas AAAA-MM-DD), tecnico (lo que dijo su capa tal cual, para la página Conexiones y soporte; nulo si nada), ultimo_sync? y cuentas? (banco), modo? y ultimo_evento_el? (cobros), ir}] (lo que tiene problemas primero), sin_instalar: [{tipo, nombre, falta (la capa)}], fuente, ir}. Sin la dirección de ninguna función ni ninguna llave. Solo lee. Solo el dueño.';

-- 3.12 · LOS COBROS EN LÍNEA (p1): lo cobrado que falta depositar, lo que
-- está en camino (pagos por cuenta de banco que todavía no se cobran), el
-- último depósito que llegó y los que vienen. p_stripe: lo de
-- fn_tablero_stripe.
create or replace function public.fn_tablero_cobros_en_linea_de(p_stripe jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy date := fn_tablero_hoy();
begin
  perform fn_tablero_exigir_dueno();
  if p_stripe is null then
    return fn_tablero_no('cobros_en_linea', 'Los cobros en línea (p1, Stripe) no están en esta base.', 'p1');
  end if;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'cobros_en_linea', 'corte', v_hoy, 'modo', p_stripe -> 'modo',
    -- (lo que falta depositar, en sus dos partes: lo cobrado que espera su depósito, y lo que Stripe descontará del
    --  siguiente por un reembolso de algo ya depositado; las dos juntas = lo que dice Cobros en línea)
    'por_depositar', jsonb_build_object('monto', p_stripe -> 'cobrado_espera', 'n', p_stripe -> 'n_cobrado_espera',
                                        'etiqueta', 'cobrado que espera su depósito al banco'),
    'por_descontar', case when coalesce((p_stripe ->> 'n_por_descontar')::int, 0) > 0
                          then jsonb_build_object('monto', p_stripe -> 'por_descontar', 'n', p_stripe -> 'n_por_descontar',
                                                  'etiqueta', 'reembolsos que Stripe descontará del próximo depósito') end,
    'falta_depositar', jsonb_build_object('monto', p_stripe -> 'por_depositar', 'n', p_stripe -> 'n_por_depositar'),
    'en_camino', jsonb_build_object('monto', p_stripe -> 'en_camino', 'n', p_stripe -> 'n_en_camino',
                                    'etiqueta', 'pagos por cuenta de banco que todavía no se cobran'),
    'ultimo_deposito', p_stripe -> 'ultimo_deposito',
    'siguientes', coalesce(p_stripe -> 'siguientes', '[]'::jsonb),
    'enlaces_activos', p_stripe -> 'enlaces_activos',
    'pagos_revisar', p_stripe -> 'pagos_revisar',
    'alarmas', p_stripe -> 'alarmas', 'cuadres_rojos', p_stripe -> 'cuadres_rojos',
    'texto', concat_ws(' ',
               case when coalesce((p_stripe ->> 'cobrado_espera')::numeric, 0) = 0 then 'Nada cobrado espera su depósito.'
                    else format('%s cobrado en %s espera su depósito al banco.', fn_tablero_usd((p_stripe ->> 'cobrado_espera')::numeric),
                                fn_tablero_plural((p_stripe ->> 'n_cobrado_espera')::int, 'pago', 'pagos')) end,
               case when coalesce((p_stripe ->> 'por_descontar')::numeric, 0) > 0
                    then format('Stripe descontará %s del próximo depósito (%s después de depositado).',
                                fn_tablero_usd((p_stripe ->> 'por_descontar')::numeric),
                                case when (p_stripe ->> 'n_por_descontar')::int = 1 then 'un reembolso hecho'
                                     else (p_stripe ->> 'n_por_descontar') || ' reembolsos hechos' end) end,
               case when coalesce((p_stripe ->> 'en_camino')::numeric, 0) > 0
                    then format('Además, %s en %s por cuenta de banco que todavía no se cobra%s.',
                                fn_tablero_usd((p_stripe ->> 'en_camino')::numeric),
                                case when (p_stripe ->> 'n_en_camino')::int = 1 then 'un pago' else (p_stripe ->> 'n_en_camino') || ' pagos' end,
                                case when (p_stripe ->> 'n_en_camino')::int = 1 then '' else 'n' end) end),
    'fuente', 'Cobros en línea (p1) y sus depósitos: por depositar = cobrado en Stripe que todavía no sale en un '
              'depósito (y aparte, lo que Stripe descontará por un reembolso de algo ya depositado); en camino = pagos por cuenta de '
              'banco iniciados que Stripe aún no da por cobrados',
    'ir', jsonb_build_object('pagina', 'cobros'));
end $$;
revoke execute on function public.fn_tablero_cobros_en_linea_de(jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero_cobros_en_linea_de(jsonb) to authenticated;
comment on function public.fn_tablero_cobros_en_linea_de(jsonb) is 'c16: arma la tarjeta de los cobros en línea con lo de fn_tablero_stripe (nulo sin p1). La tarjeta es fn_tablero_cobros_en_linea. Solo el dueño.';

create or replace function public.fn_tablero_cobros_en_linea() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_tablero_exigir_dueno();
  return fn_tablero_cobros_en_linea_de(fn_tablero_stripe());
end $$;
revoke execute on function public.fn_tablero_cobros_en_linea() from public, anon, service_role;
grant  execute on function public.fn_tablero_cobros_en_linea() to authenticated;
comment on function public.fn_tablero_cobros_en_linea() is 'c16: Stripe (p1): {ok, tarjeta: «cobros_en_linea», corte, modo (prueba | real | nulo: todavía sin avisos), por_depositar: {monto, n, etiqueta} (cobrado que espera su depósito: solo lo que falta de más de cero), por_descontar: {monto, n, etiqueta} (en positivo: reembolsos de algo ya depositado que Stripe descontará del siguiente; nulo si no hay), falta_depositar: {monto, n} (las dos juntas: lo de v_stripe_estado), en_camino: {monto, n, etiqueta} (pagos por cuenta de banco iniciados), ultimo_deposito: {monto, llegada, n_pagos, estado} (el último que llegó; nulo si ninguno), siguientes: [{monto, llegada, n_pagos, estado}] (los depósitos que vienen), enlaces_activos, pagos_revisar, alarmas, cuadres_rojos, texto (en llano), fuente, ir}. Sin p1: {ok: false, falta: «p1»}. Solo lee. Solo el dueño.';

-- 3.13 · EL USE TAX (el DR-15 de c9; el DR-15 de Florida es la declaración
-- de «sales and use tax»: de lo que se vende y de lo que se compra sin
-- impuesto). Lo de este mes y lo del mes pasado (v_dr15_mes: la base del use
-- tax, lo cargado y lo pagado en 2300), lo que se debe HOY en la 2300 (el
-- libro hasta hoy) y EL DR-15 QUE TOCA: el del mes pasado, que se paga a más
-- tardar el 20 de este mes (la regla del DR-15), con lo que de él ya se pagó
-- en este mes y lo que falta. (Lo «pagado» de v_dr15_mes en un mes es lo que
-- se pagó EN ese mes: el DR-15 del mes de antes. No se mezcla.) Las ventas
-- gravables y el sales tax cobrado todavía no se saben (las facturas no
-- separan el impuesto): nulos, y la tarjeta lo dice.
create or replace function public.fn_tablero_use_tax() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy   date := fn_tablero_hoy();
  v_mhoy  date := date_trunc('month', fn_tablero_hoy())::date;
  v_libro date;
  v_cta   text;
  v_mes   jsonb;
  v_ant   jsonb;
  v_nota  text;
  v_pas   text := to_char(date_trunc('month', fn_tablero_hoy()) - interval '1 month', 'YYYY-MM');
  v_s0    numeric;
  v_pag   numeric;
  v_falta numeric;
  v_vence date := date_trunc('month', fn_tablero_hoy())::date + 19;
  v_dr    jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if to_regclass('public.v_dr15_mes') is null then
    return fn_tablero_no('use_tax', 'El cierre del mes (c9), donde vive el DR-15, no está en esta base.', 'c9');
  end if;
  v_libro := (fn_tablero_libro() ->> 'desde')::date;
  v_cta := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'use_tax'), '2300');
  execute $q$select jsonb_build_object('periodo', d.periodo, 'etiqueta', fn_tablero_mes_largo(d.desde), 'desde', d.desde, 'hasta', d.hasta,
                                       'compras_n', d.compras_use_tax_n, 'base', d.compras_use_tax_base, 'cargado', d.use_tax_cargado_2300,
                                       'pagado', d.use_tax_pagado_2300, 'saldo_al_cierre', d.use_tax_saldo_2300),
                    d.nota
               from public.v_dr15_mes d where d.periodo = $1$q$
    into v_mes, v_nota using to_char(v_hoy, 'YYYY-MM');
  execute $q$select jsonb_build_object('periodo', d.periodo, 'etiqueta', fn_tablero_mes_largo(d.desde), 'desde', d.desde, 'hasta', d.hasta,
                                       'compras_n', d.compras_use_tax_n, 'base', d.compras_use_tax_base, 'cargado', d.use_tax_cargado_2300,
                                       'pagado', d.use_tax_pagado_2300, 'saldo_al_cierre', d.use_tax_saldo_2300)
               from public.v_dr15_mes d where d.periodo = $1 and d.hasta >= $2$q$
    into v_ant using v_pas, v_libro;
  -- EL DR-15 QUE TOCA (el del mes pasado): lo que se debía al cerrarlo, lo que de eso ya se pagó en este mes y lo que falta
  if v_ant is not null then
    v_s0 := -fn_tablero_saldo(array[v_cta], v_mhoy - 1);
    select coalesce(sum(l.monto) filter (where l.monto > 0), 0) into v_pag
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where l.cuenta = v_cta and a.fecha_contable between v_mhoy and v_hoy;
    v_falta := greatest(v_s0 - v_pag, 0);
    v_dr := jsonb_build_object(
      'periodo', v_pas, 'etiqueta', v_ant ->> 'etiqueta', 'use_tax', (v_ant ->> 'cargado')::numeric,
      'se_debia', v_s0::numeric(14,2), 'pagado', least(v_pag, greatest(v_s0, 0))::numeric(14,2), 'falta', v_falta::numeric(14,2),
      'vence', v_vence, 'vencido', v_hoy > v_vence and v_falta > 0,
      'texto', format('El DR-15 de %s lleva %s de use tax', v_ant ->> 'etiqueta', fn_tablero_usd((v_ant ->> 'cargado')::numeric))
               || case when v_s0 <= 0 then ': no se debe nada.'
                       when v_falta = 0 then format('; ya está pagado (%s en %s).', fn_tablero_usd(least(v_pag, v_s0)), fn_tablero_mes_largo(v_mhoy))
                       when v_hoy > v_vence then format('; venció el %s y falta pagar %s.', fn_tablero_dia(v_vence), fn_tablero_usd(v_falta))
                       else format('; se paga a más tardar el %s: falta pagar %s.', fn_tablero_dia(v_vence), fn_tablero_usd(v_falta)) end);
  end if;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'use_tax', 'corte', v_hoy, 'cuenta', v_cta,
    'saldo_hoy', -fn_tablero_saldo(array[v_cta], v_hoy),
    'mes', v_mes, 'mes_pasado', v_ant, 'dr15', v_dr,
    'sin_mes_pasado', case when v_ant is null then format('El mes pasado es de antes del libro (empieza el %s): vive en QuickBooks.', fn_tablero_libro() ->> 'empieza') end,
    'ventas_gravables', null, 'sales_tax_cobrado', null,
    'que_es', 'El DR-15 de Florida es la declaración del «sales and use tax». Aquí va el use tax de lo que se compra sin impuesto; el '
              'sales tax de lo que se vende todavía no se separa en las facturas, así que no se pinta.',
    'nota', v_nota,
    'texto', format('Use tax por pagar hoy: %s (la %s).', fn_tablero_usd(-fn_tablero_saldo(array[v_cta], v_hoy)), v_cta)
             || coalesce(' ' || (v_dr ->> 'texto'), ''),
    'fuente', 'el DR-15 del cierre del mes (c9): la base del use tax (las compras que la IA marcó con use tax y Edgar aprobó), lo cargado y lo pagado en la '
              || v_cta || '; lo de hoy, el libro hasta hoy; el plazo, el del DR-15 (el 20 del mes que sigue)',
    -- (a la pestaña DR-15 del cierre del mes, la de ese mes)
    'ir', jsonb_strip_nulls(jsonb_build_object('pagina', 'cierre', 'sub', 'dr15', 'periodo', case when v_ant is not null then v_pas end)));
end $$;
revoke execute on function public.fn_tablero_use_tax() from public, anon, service_role;
grant  execute on function public.fn_tablero_use_tax() to authenticated;
comment on function public.fn_tablero_use_tax() is 'c16: el use tax del DR-15 (v_dr15_mes de c9): {ok, tarjeta: «use_tax», corte, cuenta (la 2300), saldo_hoy (lo que se debe hoy, del libro), mes y mes_pasado: {periodo, etiqueta, desde, hasta, compras_n, base, cargado, pagado (lo pagado EN ese mes: el DR-15 del mes de antes), saldo_al_cierre} (mes_pasado nulo si es de antes del libro), dr15: {periodo, etiqueta, use_tax (lo cargado ese mes), se_debia (la 2300 al cerrarlo), pagado (de eso, lo pagado en este mes), falta, vence (el 20 de este mes), vencido, texto} (el DR-15 que toca: el del mes pasado; nulo si es de antes del libro), sin_mes_pasado, ventas_gravables y sales_tax_cobrado (nulos: las facturas no separan el impuesto), que_es (qué es el DR-15, en llano), nota (la de c9), texto (en llano), fuente, ir (Cierre del mes → DR-15, ese mes)}. Sin c9: {ok: false, falta: «c9»}. Solo lee. Solo el dueño.';

-- 3.14 · LO QUE EL LIBRO SABE DE LAS OBRAS: el WIP del mes que toca (c12:
-- sobre y sub-facturado, cuántas obras y cómo está el ajuste) y el costo
-- por obra (c10: ingreso, costo y margen de las obras con más ingreso, y
-- los totales). Una de las dos que no esté lo dice en su parte.
create or replace function public.fn_tablero_obras(p_top int default 5) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy  date := fn_tablero_hoy();
  v_top  int := coalesce(p_top, 5);
  v_wip  jsonb;
  v_cos  jsonb;
  v_j    jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if v_top < 1 or v_top > 30 then
    raise exception using errcode = '22023', message = format('Las obras de la lista van de 1 a 30 (llegó %s).', v_top);
  end if;
  -- EL WIP (c12)
  if to_regprocedure('public.fn_wip_resumen(text)') is not null then
    execute 'select public.fn_wip_resumen(null)' into v_j;
    v_wip := jsonb_build_object(
      'ok', true, 'periodo', v_j -> 'periodo', 'nombre', v_j -> 'nombre', 'cerrado', v_j -> 'cerrado', 'terminado', v_j -> 'terminado',
      'exigido', v_j -> 'exigido',
      'sobre_facturado', v_j -> 'totales' -> 'sobre_facturado', 'sub_facturado', v_j -> 'totales' -> 'sub_facturado',
      'neto', ((v_j -> 'totales' ->> 'sub_facturado')::numeric - (v_j -> 'totales' ->> 'sobre_facturado')::numeric)::numeric(14,2),
      'perdida_provision', v_j -> 'totales' -> 'perdida_provision',
      'obras', v_j -> 'obras', 'ajuste', v_j -> 'ajuste',
      -- (los textos de c12, con sus plurales en llano: «2 obras», no «2 obra(s)»)
      'por_que_no', fn_tablero_llano(v_j ->> 'por_que_no'), 'nota', fn_tablero_llano(v_j ->> 'nota'),
      'ir', jsonb_strip_nulls(jsonb_build_object('pagina', 'wip', 'sub', 'mes', 'periodo', v_j ->> 'periodo')));
  else
    v_wip := fn_tablero_no('obras', 'El WIP (c12) no está en esta base.', 'c12');
  end if;
  -- EL COSTO POR OBRA (c10)
  if to_regclass('public.v_margen_obra') is not null then
    execute $q$
      with o as (
        select m.proyecto_id, m.obra, m.cliente, m.estado, m.ingreso_libro::numeric(14,2) as ingreso, m.costo_real::numeric(14,2) as costo,
               m.margen_real::numeric(14,2) as margen, m.margen_real_pct as margen_pct, m.parcial, m.parcial_por
          from public.v_margen_obra m
         where coalesce(m.ingreso_libro, 0) <> 0 or coalesce(m.costo_real, 0) <> 0
      )
      select jsonb_build_object(
               'ok', true,
               'obras', (select coalesce(jsonb_agg(jsonb_build_object(
                                   'proyecto_id', y.proyecto_id, 'obra', y.obra, 'cliente', y.cliente, 'estado', y.estado,
                                   'ingreso', y.ingreso, 'costo', y.costo, 'margen', y.margen, 'margen_pct', y.margen_pct,
                                   'parcial', y.parcial, 'parcial_por', y.parcial_por,
                                   'ir', jsonb_build_object('pagina', 'obras', 'sel', y.proyecto_id)) order by y.ingreso desc, y.obra), '[]'::jsonb)
                           from (select * from o order by o.ingreso desc, o.obra limit $1) y),
               'totales', jsonb_build_object('n', count(*), 'ingreso', coalesce(sum(o.ingreso), 0)::numeric(14,2),
                                             'costo', coalesce(sum(o.costo), 0)::numeric(14,2),
                                             'margen', coalesce(sum(o.margen), 0)::numeric(14,2),
                                             'margen_pct', fn_tablero_pct(sum(o.margen), nullif(sum(o.ingreso), 0)),
                                             'parciales', count(*) filter (where o.parcial)),
               'nota', case when count(*) filter (where o.parcial) > 0
                            then format('%s ya %s antes del libro: lo real de aquí es parcial (lo de antes está en QuickBooks).',
                                        fn_tablero_plural(count(*) filter (where o.parcial), 'obra', 'obras'),
                                        case when count(*) filter (where o.parcial) = 1 then 'andaba' else 'andaban' end) end,
               'ir', jsonb_build_object('pagina', 'obras'))
        from o$q$ into v_cos using v_top;
  else
    v_cos := fn_tablero_no('obras', 'El costo por obra (c10) no está en esta base.', 'c10');
  end if;
  if not (v_wip ->> 'ok')::boolean and not (v_cos ->> 'ok')::boolean then
    return fn_tablero_no('obras', 'Ni el WIP (c12) ni el costo por obra (c10) están en esta base.', 'c10, c12')
           || jsonb_build_object('wip', v_wip, 'costo', v_cos);
  end if;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'obras', 'corte', v_hoy, 'top', v_top,
    'wip', v_wip, 'costo', v_cos,
    'fuente', 'el WIP del mes que toca (c12: sobre y sub-facturado de las obras listas) y el costo por obra (c10: lo del libro desde '
              || 'que empieza)',
    'ir', jsonb_build_object('pagina', 'obras'));
end $$;
revoke execute on function public.fn_tablero_obras(int) from public, anon, service_role;
grant  execute on function public.fn_tablero_obras(int) to authenticated;
comment on function public.fn_tablero_obras(int) is 'c16: lo que el libro sabe de las obras: {ok, tarjeta: «obras», corte, top, wip: {ok, periodo (el mes que toca), nombre, cerrado, terminado, exigido, sobre_facturado, sub_facturado, neto (sub − sobre), perdida_provision, obras: {total, listas, pendientes, por_revisar, …}, ajuste: {vivo, al_dia, …}, por_que_no, nota, ir} (sin c12: {ok: false, falta: «c12»}), costo: {ok, obras: [{proyecto_id, obra, cliente, estado, ingreso, costo, margen, margen_pct, parcial, parcial_por, ir}] (las p_top con más ingreso), totales: {n, ingreso, costo, margen, margen_pct, parciales}, nota, ir} (sin c10: {ok: false, falta: «c10»}), fuente, ir}. Sin las dos: {ok: false}. 22023 con p_top fuera de 1–30. Solo lee. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 4. fn_tablero: TODAS LAS TARJETAS EN UNA LLAMADA (lo que pide la
--    pantalla). Lee cada pieza compartida una vez; cada tarjeta, en su
--    propio bloque: la que falla trae {ok: false, motivo, codigo} y las
--    demás siguen. Por la API, con el tope por reloj.
-- ---------------------------------------------------------------------
-- Un número entero de p (o el de fábrica): 22023 si no es un entero.
create or replace function public.fn_tablero_entero(p jsonb, p_clave text, p_omision int) returns int
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  v text;
begin
  if p is null or not p ? p_clave or jsonb_typeof(p -> p_clave) = 'null' then
    return p_omision;
  end if;
  v := p ->> p_clave;
  if jsonb_typeof(p -> p_clave) not in ('number', 'string') or v !~ '^\s*-?[0-9]{1,6}\s*$' then
    raise exception using errcode = '22023', message = format('«%s» es un número entero (llegó «%s»).', p_clave, left(coalesce(v, ''), 40));
  end if;
  return v::int;
end $$;
revoke execute on function public.fn_tablero_entero(jsonb, text, int) from public, anon, service_role;
grant  execute on function public.fn_tablero_entero(jsonb, text, int) to authenticated;
comment on function public.fn_tablero_entero(jsonb, text, int) is 'c16: un número entero de lo que pide la pantalla (o el de fábrica); 22023 si no lo es.';

create or replace function public.fn_tablero(p jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  c_todas constant text[] := array['acciones', 'cobros', 'bancos', 'resultados', 'gastos', 'caja', 'facturas', 'ventas', 'por_cobrar',
                                   'por_pagar', 'conexiones', 'cobros_en_linea', 'use_tax', 'prestamos', 'obras', 'nomina'];
  c_subs  constant jsonb := '{"cobros": ["dias"], "facturas": ["dias"], "resultados": ["periodo", "desde", "hasta"],
                              "gastos": ["dias", "top"], "caja": ["meses", "proyeccion"], "ventas": ["anio"], "obras": ["top"],
                              "nomina": ["meses"]}';
  v_p     jsonb := coalesce(p, '{}'::jsonb);
  v_t0    timestamptz := clock_timestamp();
  v_hoy   date;
  v_api   boolean := current_user in ('authenticated', 'anon', 'service_role');
  v_tope  int;
  v_ped   text[];
  v_k     text;
  v_x     text;
  v_out   jsonb := '{}'::jsonb;
  v_sigue text[] := '{}';
  v_j     jsonb;
  v_t1    timestamptz;
  -- lo que se pide de cada tarjeta
  v_cob_dias  int;
  v_fac_dias  int;
  v_res_per   text;
  v_res_desde date;
  v_res_hasta date;
  v_gas_dias  int;
  v_gas_top   int;
  v_caja_m    int;
  v_caja_p    int;
  v_ven_anio  int;
  v_obr_top   int;
  v_nom_mes   int;   -- (11c)
  -- LAS PIEZAS COMPARTIDAS: lo leído (s_), si ya se leyó (l_) y su error (e_: «código|mensaje»)
  s_cxc jsonb; l_cxc boolean := false; e_cxc text;
  s_cxp jsonb; l_cxp boolean := false; e_cxp text;
  s_cob jsonb; l_cob boolean := false; e_cob text;   -- lo cobrado en los días del embudo
  s_cof jsonb; l_cof boolean := false; e_cof text;   -- lo cobrado en los días de las facturas (si son otros)
  s_cuo jsonb; l_cuo boolean := false; e_cuo text;   -- las cuotas de los próximos 12 meses
  s_str jsonb; l_str boolean := false; e_str text;   -- Stripe
  s_sal jsonb; l_sal boolean := false; e_sal text;   -- los saldos de los bancos
  s_nom jsonb; l_nom boolean := false; e_nom text;   -- (11c) lo que espera de la nómina (c15)
begin
  perform fn_tablero_exigir_dueno();
  v_hoy := fn_tablero_hoy();
  -- LO QUE SE PIDE, bien formado (22023 si no)
  if jsonb_typeof(v_p) <> 'object' then
    raise exception using errcode = '22023', message = 'Lo que se pide es un objeto: {"tarjetas": […], "resultados": {"periodo": "mes"}, …}.';
  end if;
  for v_k in select jsonb_object_keys(v_p) loop
    if v_k <> 'tarjetas' and v_k <> 'tope_ms' and not c_subs ? v_k then
      raise exception using errcode = '22023',
        message = format('Clave desconocida: «%s». Las que hay: tarjetas, tope_ms, cobros, facturas, resultados, gastos, caja, ventas, obras, nomina.', left(v_k, 40));
    end if;
    if c_subs ? v_k then
      if jsonb_typeof(v_p -> v_k) <> 'object' then
        raise exception using errcode = '22023', message = format('«%s» es un objeto (por ejemplo {"dias": 30}).', v_k);
      end if;
      for v_x in select jsonb_object_keys(v_p -> v_k) loop
        if not (c_subs -> v_k) ? v_x then
          raise exception using errcode = '22023',
            message = format('Clave desconocida en «%s»: «%s». Las que hay: %s.', v_k, left(v_x, 40),
                             (select string_agg(e, ', ') from jsonb_array_elements_text(c_subs -> v_k) e));
        end if;
      end loop;
    end if;
  end loop;
  if v_p ? 'tarjetas' and jsonb_typeof(v_p -> 'tarjetas') <> 'null' then
    if jsonb_typeof(v_p -> 'tarjetas') <> 'array' then
      raise exception using errcode = '22023', message = '«tarjetas» es una lista de nombres de tarjeta.';
    end if;
    select array_agg(e order by o) into v_ped
      from (select e, min(o) as o from jsonb_array_elements_text(v_p -> 'tarjetas') with ordinality t(e, o) group by e) u;
    select string_agg(e, ', ') into v_x from unnest(coalesce(v_ped, '{}'::text[])) e where e <> all (c_todas);
    if v_x is not null then
      raise exception using errcode = '22023',
        message = format('No conozco la tarjeta «%s». Las que hay: %s.', left(v_x, 60), array_to_string(c_todas, ', '));
    end if;
    v_ped := coalesce(v_ped, '{}'::text[]);
  else
    v_ped := c_todas;
  end if;
  v_tope := coalesce(fn_tablero_entero(v_p, 'tope_ms', null), case when v_api then 4000 else 0 end);
  if v_tope < 0 or v_tope > 7000 then
    raise exception using errcode = '22023', message = format('El tope va de 0 (sin tope) a 7000 ms (llegó %s).', v_tope);
  end if;
  v_cob_dias := fn_tablero_entero(v_p -> 'cobros', 'dias', 30);
  v_fac_dias := fn_tablero_entero(v_p -> 'facturas', 'dias', 30);
  v_gas_dias := fn_tablero_entero(v_p -> 'gastos', 'dias', 30);
  v_gas_top  := fn_tablero_entero(v_p -> 'gastos', 'top', 5);
  v_caja_m   := fn_tablero_entero(v_p -> 'caja', 'meses', 12);
  v_caja_p   := fn_tablero_entero(v_p -> 'caja', 'proyeccion', 3);
  v_ven_anio := fn_tablero_entero(v_p -> 'ventas', 'anio', extract(year from v_hoy)::int);
  v_obr_top  := fn_tablero_entero(v_p -> 'obras', 'top', 5);
  v_nom_mes  := fn_tablero_entero(v_p -> 'nomina', 'meses', 6);
  if v_nom_mes < 1 or v_nom_mes > 24 then
    raise exception using errcode = '22023', message = format('Los meses de la nómina van de 1 a 24 (llegó %s).', v_nom_mes);
  end if;
  foreach v_x in array array[v_cob_dias, v_fac_dias, v_gas_dias]::text[] loop
    if v_x::int < 1 or v_x::int > 366 then
      raise exception using errcode = '22023', message = format('Los días van de 1 a 366 (llegó %s).', v_x);
    end if;
  end loop;
  if v_caja_p < 0 or v_caja_p > 12 then
    raise exception using errcode = '22023', message = format('Los meses de la proyección van de 0 a 12 (llegó %s).', v_caja_p);
  end if;
  v_res_per := v_p -> 'resultados' ->> 'periodo';
  begin
    v_res_desde := (v_p -> 'resultados' ->> 'desde')::date;
    v_res_hasta := (v_p -> 'resultados' ->> 'hasta')::date;
  exception when others then
    raise exception using errcode = '22007', message = 'Las fechas de los resultados van como AAAA-MM-DD.';
  end;

  -- CADA TARJETA, en su bloque
  foreach v_k in array v_ped loop
    v_t1 := clock_timestamp();
    if v_tope > 0 and extract(epoch from v_t1 - v_t0) * 1000 > v_tope then
      v_out := v_out || jsonb_build_object(v_k, jsonb_build_object('ok', false, 'tarjeta', v_k, 'sigue', true,
                                                                   'motivo', 'No alcanzó el tiempo de esta llamada: se vuelve a pedir.'));
      v_sigue := v_sigue || v_k;
      continue;
    end if;
    begin
      -- las piezas que esta tarjeta necesita (una vez por llamada; su error queda para las que las usan)
      if v_k in ('cobros', 'facturas', 'por_cobrar', 'caja') and not l_cxc and not (v_k = 'caja' and v_caja_p = 0) then
        l_cxc := true;
        begin
          s_cxc := (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from fn_tablero_cxc() x);
        exception when others then e_cxc := sqlstate || '|' || sqlerrm;
        end;
      end if;
      if v_k in ('por_pagar', 'caja') and not l_cxp and not (v_k = 'caja' and v_caja_p = 0) then
        l_cxp := true;
        begin
          s_cxp := (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from fn_tablero_cxp() x);
        exception when others then e_cxp := sqlstate || '|' || sqlerrm;
        end;
      end if;
      if (v_k = 'cobros' or (v_k = 'facturas' and v_fac_dias = v_cob_dias)) and not l_cob then
        l_cob := true;
        begin
          s_cob := fn_tablero_cobrado((select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
                                         from fn_tablero_cobros_lista(v_hoy - (v_cob_dias - 1), v_hoy) x),
                                      v_hoy - (v_cob_dias - 1), v_hoy);
        exception when others then e_cob := sqlstate || '|' || sqlerrm;
        end;
      end if;
      if v_k = 'facturas' and v_fac_dias <> v_cob_dias and not l_cof then
        l_cof := true;
        begin
          s_cof := fn_tablero_cobrado((select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
                                         from fn_tablero_cobros_lista(v_hoy - (v_fac_dias - 1), v_hoy) x),
                                      v_hoy - (v_fac_dias - 1), v_hoy);
        exception when others then e_cof := sqlstate || '|' || sqlerrm;
        end;
      end if;
      if v_k in ('prestamos', 'caja') and not l_cuo and not (v_k = 'caja' and v_caja_p = 0) then
        l_cuo := true;
        begin
          s_cuo := (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
                      from fn_tablero_cuotas((date_trunc('month', v_hoy) + interval '12 months')::date - 1) x);
        exception when others then e_cuo := sqlstate || '|' || sqlerrm;
        end;
      end if;
      if v_k in ('acciones', 'conexiones', 'cobros_en_linea') and not l_str then
        l_str := true;
        begin
          s_str := fn_tablero_stripe();
        exception when others then e_str := sqlstate || '|' || sqlerrm;
        end;
      end if;
      if v_k in ('acciones', 'bancos') and not l_sal then
        l_sal := true;
        begin
          s_sal := fn_tablero_saldos();
        exception when others then e_sal := sqlstate || '|' || sqlerrm;
        end;
      end if;
      if v_k in ('acciones', 'nomina') and not l_nom then
        l_nom := true;
        begin
          s_nom := fn_tablero_nomina_estado();
        exception when others then e_nom := sqlstate || '|' || sqlerrm;
        end;
      end if;
      -- la tarjeta (si una pieza que necesita falló, lo dice ella)
      v_x := case v_k
               when 'cobros' then coalesce(e_cxc, e_cob)
               when 'facturas' then coalesce(e_cxc, case when v_fac_dias = v_cob_dias then e_cob else e_cof end)
               when 'por_cobrar' then e_cxc
               when 'por_pagar' then e_cxp
               when 'caja' then case when v_caja_p > 0 then coalesce(e_cxc, e_cxp, e_cuo) end
               when 'prestamos' then e_cuo
               when 'acciones' then coalesce(e_sal, e_str, e_nom)
               when 'nomina' then e_nom
               when 'bancos' then e_sal
               when 'conexiones' then e_str
               when 'cobros_en_linea' then e_str end;
      if v_x is not null then
        v_j := fn_tablero_no(v_k, 'Esta tarjeta no se pudo leer ahora: la base contestó con un error. Las demás siguen.', null, split_part(v_x, '|', 1))
               || jsonb_build_object('error', fn_tablero_corto(substr(v_x, strpos(v_x, '|') + 1), 300));
      else
        v_j := case v_k
                 when 'acciones' then fn_tablero_acciones_de(s_sal, s_str, s_nom)
                 when 'cobros' then fn_tablero_cobros_de(s_cxc, s_cob)
                 when 'bancos' then fn_tablero_bancos_de(s_sal)
                 when 'resultados' then case when v_res_desde is not null or v_res_hasta is not null
                                             then fn_tablero_resultados(v_res_desde, v_res_hasta, v_res_per)
                                             else fn_tablero_resultados(null, null, v_res_per) end
                 when 'gastos' then fn_tablero_gastos(v_gas_dias, v_gas_top)
                 when 'caja' then fn_tablero_caja_de(v_caja_m, v_caja_p, s_cxc, s_cxp, s_cuo)
                 when 'facturas' then fn_tablero_facturas_de(s_cxc, case when v_fac_dias = v_cob_dias then s_cob else s_cof end)
                 when 'ventas' then fn_tablero_ventas(v_ven_anio)
                 when 'por_cobrar' then fn_tablero_antiguedad_de('cobrar', s_cxc)
                 when 'por_pagar' then fn_tablero_antiguedad_de('pagar', s_cxp)
                 when 'conexiones' then fn_tablero_conexiones_de(s_str)
                 when 'cobros_en_linea' then fn_tablero_cobros_en_linea_de(s_str)
                 when 'use_tax' then fn_tablero_use_tax()
                 when 'prestamos' then fn_tablero_prestamos_de(s_cuo)
                 when 'obras' then fn_tablero_obras(v_obr_top)
                 when 'nomina' then fn_tablero_nomina_de(s_nom, v_nom_mes) end;
      end if;
    exception when others then
      -- (lo mal pedido —un número fuera de su rango, un período que no existe— es de quien pide: falla la llamada entera)
      if sqlstate in ('22023', '22007') then
        raise;
      end if;
      v_j := fn_tablero_no(v_k, 'Esta tarjeta no se pudo leer ahora: la base contestó con un error. Las demás siguen.', null, sqlstate)
             || jsonb_build_object('error', fn_tablero_corto(sqlerrm, 300));
    end;
    v_out := v_out || jsonb_build_object(v_k, v_j || jsonb_build_object('ms', round(extract(epoch from clock_timestamp() - v_t1) * 1000)::int));
  end loop;
  return jsonb_build_object('ok', true, 'version', fn_tablero_version(), 'hoy', v_hoy, 'generado_el', clock_timestamp(),
                            'libro', fn_tablero_libro(), 'capas', fn_tablero_capas(), 'tarjetas', to_jsonb(v_ped))
         || v_out
         || jsonb_build_object('sigue', to_jsonb(v_sigue), 'ms', round(extract(epoch from clock_timestamp() - v_t0) * 1000)::int);
end $$;
revoke execute on function public.fn_tablero(jsonb) from public, anon, service_role;
grant  execute on function public.fn_tablero(jsonb) to authenticated;
comment on function public.fn_tablero(jsonb) is 'c16: el tablero de la portada de Contabilidad en UNA llamada. p (todo opcional): {tarjetas: [acciones, cobros, bancos, resultados, gastos, caja, facturas, ventas, por_cobrar, por_pagar, conexiones, cobros_en_linea, use_tax, prestamos, obras, nomina] (solo esas, en ese orden), cobros: {dias}, facturas: {dias}, resultados: {periodo: mes | mes_pasado | anio | anio_pasado} o {desde, hasta}, gastos: {dias, top}, caja: {meses, proyeccion}, ventas: {anio}, obras: {top}, nomina: {meses}, tope_ms (por la API, de fábrica 4000; 0 = sin tope)}. Devuelve {ok, version, hoy, generado_el, libro (fn_tablero_libro), capas (fn_tablero_capas), tarjetas (las pedidas), una clave por tarjeta con lo de su función más «ms» (la que falla: {ok: false, motivo (en llano), codigo, error (lo que contestó la base, para quien da soporte)}; la que no tiene su capa: {ok: false, motivo, falta}; la que no alcanzó el tope: {ok: false, sigue: true}), sigue (las que no alcanzaron: se piden otra vez), ms}. Lo que comparten varias tarjetas se lee una vez. 22023 con una clave, una tarjeta o un número que no existe; 22007 con una fecha mal escrita; 42501 si no es el dueño. Solo lee.';



-- ---------------------------------------------------------------------
-- 4b. (14-nov, Fase 11c) LA NÓMINA (c15): lo que se debe de ella por día
--     (para la proyección de la caja), lo que espera de ella (para su
--     acción rápida y «Qué atender») y su tarjeta. Todo por to_regclass /
--     to_regprocedure y execute: sin c15, la tarjeta dice que no está y la
--     caja sigue como antes.
-- LA SEGURIDAD (el criterio de c15): lo de la EMPRESA que ya está en el
-- libro (el costo de la nómina por mes, lo que se debe en 2210 a 2250, la
-- bolsa 5015) y lo del banco (los cargos de Gusto que esperan en la Bandeja)
-- se enseña sin el código del teléfono, como lo enseñan Estados y la
-- Bandeja. Lo de UNA NÓMINA (sus totales, cuántas personas, lo que le queda
-- por pagar, las que esperan por postear, los cuadres de c15) solo con el
-- código (aal2: lo da c15 por sus vistas, que lo piden): una nómina de una
-- sola persona —un bono— ES lo que cobró esa persona. Sin el código, la
-- tarjeta lo dice («con el código del teléfono») y no pone un cero. Nada de
-- una persona sale nunca: ni nombres ni lo que cobra nadie.
-- ---------------------------------------------------------------------
-- LO QUE SE DEBE DE LA NÓMINA, POR DÍA, DEL LIBRO (sin el código; lo usa la
-- proyección de la caja). P = todo lo que el libro tiene en las cuentas de
-- «nómina por pagar» del balance (2210 a 2250; también lo fechado después
-- de hoy). Cada nómina ya posteada con día de pago DESPUÉS de hoy (su
-- journal, vivo) se debe ese día por lo que su journal dejó en esas
-- cuentas; lo que Gusto ya cobró de ellas antes de su día de pago (P menor
-- que lo de esas nóminas) se descuenta de la más próxima primero; lo demás
-- de P (lo de las nóminas ya pagadas que sigue sin su cargo, lo retenido
-- que no se ha depositado) se debe HOY. Si P no es positivo (todo pagado, o
-- a favor), nada. Lo que Gusto ya cobró y está casado no está en P: no se
-- resta dos veces.
create or replace function public.fn_tablero_nomina_pagos()
returns table (fecha date, monto numeric, asiento text, de_hoy boolean)
language plpgsql stable
rows 4
set search_path = public, pg_temp
as $$
declare
  v_hoy  date := fn_tablero_hoy();
  v_ctas text[];
  v_p    numeric;
begin
  perform fn_tablero_exigir_dueno();
  v_ctas := array(select m.cuenta from fn_tablero_mapa() m where m.estado = 'balance' and m.linea = 'nomina_por_pagar');
  if cardinality(v_ctas) = 0 then
    return;
  end if;
  v_p := -fn_tablero_saldo(v_ctas, null);
  if v_p <= 0 then
    return;
  end if;
  return query
  with j as (
    select a.numero, a.fecha_contable as f, (-sum(l.monto))::numeric(14,2) as deja
      from asientos a join asiento_lineas l on l.asiento_id = a.id
     where a.origen_tabla = 'nomina_corridas' and a.fecha_contable > v_hoy and a.reversa_a is null
       and not exists (select 1 from asientos r where r.reversa_a = a.id)
       and l.cuenta = any (v_ctas)
     group by a.id, a.numero, a.fecha_contable
    having -sum(l.monto) > 0
  ), x as (
    select j.*, sum(j.deja) over (order by j.f, j.numero) as acum, sum(j.deja) over () as fut from j
  ), y as (
    select x.f, x.numero,
           (greatest(0, x.acum - greatest(x.fut - v_p, 0)) - greatest(0, x.acum - x.deja - greatest(x.fut - v_p, 0)))::numeric(14,2) as m
      from x
  )
  select v_hoy, (v_p - coalesce((select max(x.fut) from x), 0))::numeric(14,2), null::text, true
   where v_p - coalesce((select max(x.fut) from x), 0) > 0
  union all
  select y.f, y.m, y.numero, false from y where y.m > 0
  order by 1, 3;
end $$;
revoke execute on function public.fn_tablero_nomina_pagos() from public, anon, service_role;
grant  execute on function public.fn_tablero_nomina_pagos() to authenticated;
comment on function public.fn_tablero_nomina_pagos() is 'c16: (14-nov, Fase 11c) lo que se debe de la nómina por día, del libro (sin el código del teléfono): cada nómina posteada con día de pago después de hoy, ese día, por lo que su journal dejó en 2210–2250 (menos lo que Gusto ya cobró de ella, de la más próxima primero); lo demás de esas cuentas, hoy. Filas {fecha, monto, asiento (el journal, o nulo para lo de hoy), de_hoy}. Sin nada que se deba, ninguna fila. Solo el dueño.';

-- LO QUE ESPERA DE LA NÓMINA (la pieza que comparten su tarjeta y su
-- acción rápida; fn_tablero la lee UNA vez): si la sesión trae el código,
-- los cargos y devoluciones de Gusto que esperan en la Bandeja (del banco:
-- sin el código), los des-casados (con el código), las nóminas importadas
-- sin postear (con el código) y el control de c15 (sus filas que no están
-- en verde, con su texto corto: sin el nombre ni las cifras de nadie). Sin
-- c15, nulo.
create or replace function public.fn_tablero_nomina_estado() returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy  date := fn_tablero_hoy();
  v_cod  boolean;
  v_hay  boolean;
  v_car  record;
  v_pp   record;
  v_ctl  record;
  c_sin  constant text := 'Hay nóminas en la base y para comprobar esto hace falta el código del teléfono%';
begin
  perform fn_tablero_exigir_dueno();
  if to_regprocedure('public.fn_nomina_aal2()') is null or to_regprocedure('public.fn_nomina_cargos()') is null
     or to_regclass('public.v_nomina_corridas') is null or to_regclass('public.v_nomina_control') is null
     or to_regclass('public.nomina_archivos') is null or to_regclass('public.nomina_config') is null then
    return null;
  end if;
  execute 'select public.fn_nomina_aal2()' into v_cod;
  execute 'select exists (select 1 from public.nomina_archivos)' into v_hay;
  execute $q$
    select count(*) filter (where g.estado = 'pendiente' and g.monto > 0) as n,
           coalesce(sum(g.monto) filter (where g.estado = 'pendiente' and g.monto > 0), 0)::numeric(14,2) as monto,
           min(g.fecha) filter (where g.estado = 'pendiente' and g.monto > 0) as viejo,
           count(*) filter (where g.estado = 'pendiente' and g.monto < 0) as nd,
           coalesce(-sum(g.monto) filter (where g.estado = 'pendiente' and g.monto < 0), 0)::numeric(14,2) as md,
           count(*) filter (where g.estado = 'descasado') as des
      from public.fn_nomina_cargos() g where g.estado in ('pendiente', 'descasado')$q$ into v_car;
  execute $q$select count(*) as n, min(k.dia_pago) as primero, max(k.dia_pago) as ultimo
               from public.v_nomina_corridas k where k.estado = 'importada'$q$ into v_pp;
  execute format($q$
    select count(*) filter (where k.nivel = 'cuadre' and k.ok is not true and k.detalle not like %1$L) as cuadres,
           count(*) filter (where k.nivel = 'aviso' and k.ok is not true and k.detalle not like %1$L) as avisos,
           count(*) filter (where k.ok is not true and k.detalle like %1$L) as con_codigo,
           coalesce(jsonb_agg(jsonb_build_object('orden', k.orden, 'nivel', k.nivel, 'texto', k.corto) order by k.orden)
                      filter (where k.ok is not true and k.detalle not like %1$L), '[]'::jsonb) as filas
      from public.v_nomina_control k$q$, c_sin) into v_ctl;
  return jsonb_build_object(
    'con_codigo', v_cod, 'hay_nominas', v_hay,
    'cargos', jsonb_build_object('n', v_car.n, 'monto', v_car.monto, 'mas_viejo', v_car.viejo, 'dias', v_hoy - v_car.viejo,
                                 'devoluciones', jsonb_build_object('n', v_car.nd, 'monto', v_car.md),
                                 'descasados', case when v_cod then v_car.des end),
    -- (sin el código, c15 no deja ver ninguna corrida: el número no se sabe —nulo—, no es un cero)
    'por_postear', case when v_cod or not v_hay then jsonb_build_object('n', v_pp.n, 'primero', v_pp.primero, 'ultimo', v_pp.ultimo) end,
    'control', jsonb_build_object('cuadres_rojos', v_ctl.cuadres, 'avisos', v_ctl.avisos, 'con_codigo', v_ctl.con_codigo, 'filas', v_ctl.filas));
end $$;
revoke execute on function public.fn_tablero_nomina_estado() from public, anon, service_role;
grant  execute on function public.fn_tablero_nomina_estado() to authenticated;
comment on function public.fn_tablero_nomina_estado() is 'c16: (14-nov, Fase 11c) lo que espera de la nómina (c15), una vez por llamada: {con_codigo (aal2), hay_nominas, cargos: {n, monto, mas_viejo, dias, devoluciones: {n, monto}, descasados (nulo sin el código)}, por_postear: {n, primero, ultimo} (nulo sin el código si hay nóminas), control: {cuadres_rojos, avisos, con_codigo (las filas que sin el código no se pueden comprobar), filas: [{orden, nivel, texto}] (el texto corto de c15: sin nombres ni cifras de nadie)}}. Sin c15, nulo. Solo el dueño.';

-- UNA NÓMINA de la tarjeta (la última o la próxima), por su journal: con el código, lo de c15 (v_nomina_corridas, que lo pide);
-- sin él, su día de pago y su asiento, y que lo demás va con el código (una nómina de una persona es lo que cobró esa persona).
create or replace function public.fn_tablero_nomina_una(p_asiento uuid, p_cod boolean) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v jsonb;
begin
  perform fn_tablero_exigir_dueno();
  if p_cod then
    execute $q$
      select jsonb_build_object(
               'corrida', k.corrida_id, 'dia_pago', k.dia_pago, 'etiqueta', public.fn_tablero_dia(k.dia_pago),
               'periodo_desde', k.periodo_desde, 'periodo_hasta', k.periodo_hasta,
               'periodo', case when k.periodo_desde is not null then public.fn_tablero_rango(k.periodo_desde, k.periodo_hasta) end,
               'tipo', k.tipo, 'tipo_texto', k.tipo_texto, 'personas', k.personas,
               'costo', (k.bruto + k.imp_patron + k.ben_patron)::numeric(14,2), 'bruto', k.bruto,
               'patron', (k.imp_patron + k.ben_patron)::numeric(14,2), 'impuestos', (k.imp_empleado + k.imp_patron)::numeric(14,2),
               'neto', k.neto, 'deducciones', k.deducciones, 'reembolsos', k.reembolsos,
               'por_pagar', coalesce(k.por_pagar, 0), 'a_favor', coalesce(k.a_favor, 0), 'asiento', k.asiento_numero, 'con_codigo', true,
               'ir', jsonb_build_object('pagina', 'nomina', 'sub', 'nominas', 'corrida', k.corrida_id))
        from public.v_nomina_corridas k where k.asiento_id = $1 and k.estado = 'posteada'$q$
      into v using p_asiento;
  end if;
  return coalesce(v, (select jsonb_build_object('dia_pago', a.fecha_contable, 'etiqueta', fn_tablero_dia(a.fecha_contable), 'asiento', a.numero,
                                                'con_codigo', false, 'texto', 'Sus totales y cuántas personas, con el código del teléfono.',
                                                'ir', jsonb_build_object('pagina', 'nomina', 'sub', 'nominas'))
                        from asientos a where a.id = p_asiento));
end $$;
revoke execute on function public.fn_tablero_nomina_una(uuid, boolean) from public, anon, service_role;
grant  execute on function public.fn_tablero_nomina_una(uuid, boolean) to authenticated;
comment on function public.fn_tablero_nomina_una(uuid, boolean) is 'c16: (14-nov, Fase 11c) una nómina de la tarjeta por su journal: con el código (p_cod), lo de v_nomina_corridas de c15 (que lo pide); sin él, su día de pago y su asiento, y que lo demás va con el código. Solo el dueño.';

-- LA TARJETA DE LA NÓMINA («Payroll» en la portada de QuickBooks).
create or replace function public.fn_tablero_nomina_de(p_e jsonb, p_meses int default 6) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_hoy    date := fn_tablero_hoy();
  v_mhoy   date := date_trunc('month', fn_tablero_hoy())::date;
  v_meses  int := coalesce(p_meses, 6);
  v_lib    jsonb;
  v_m0     date;
  v_cod    boolean;
  v_cfg    record;
  v_bur    text[];
  v_ctas   text[];
  v_serie  jsonb;
  v_ult    record;
  v_prox   record;
  v_ulj    jsonb;
  v_prj    jsonb;
  v_debe   jsonb;
  v_dt     numeric;
  v_dh     numeric;
  v_bolsa  numeric;
  v_bmes   date;
  v_at     jsonb := '[]'::jsonb;
  v_car    jsonb;
  v_pp     jsonb;
  v_ctl    jsonb;
  v_hay    boolean;
begin
  perform fn_tablero_exigir_dueno();
  if v_meses < 1 or v_meses > 24 then
    raise exception using errcode = '22023', message = format('Los meses de la nómina van de 1 a 24 (llegó %s).', v_meses);
  end if;
  if p_e is null then
    return fn_tablero_no('nomina', 'La nómina con Gusto (c15) no está en esta base: cuando se pegue docs/conta/c15-nomina.sql, aquí sale '
                                   'cada nómina, lo que se debe de ella y los cargos de Gusto que esperan.', 'c15');
  end if;
  v_cod := coalesce((p_e ->> 'con_codigo')::boolean, false);
  v_car := p_e -> 'cargos';
  v_pp  := nullif(p_e -> 'por_postear', 'null'::jsonb);
  v_ctl := p_e -> 'control';
  v_lib := fn_tablero_libro();
  execute 'select k.cuenta_bolsa, k.cuenta_burden_admin, k.cuenta_burden_obra from public.nomina_config k where k.id = 1' into v_cfg;
  v_bur := array_remove(array[v_cfg.cuenta_bolsa, v_cfg.cuenta_burden_admin, v_cfg.cuenta_burden_obra], null);
  v_ctas := array(select m.cuenta from fn_tablero_mapa() m where m.estado = 'balance' and m.linea = 'nomina_por_pagar' order by m.cuenta);
  v_m0 := greatest(date_trunc('month', coalesce((v_lib ->> 'desde')::date, v_mhoy))::date, (v_mhoy - make_interval(months => v_meses - 1))::date);
  -- LOS MESES: lo que costó la nómina de Gusto cada mes, del libro (sus journals vivos —ni anulados ni reversos—, por su día de
  -- pago, hasta hoy): el sueldo y lo del patrón (la bolsa del burden y el burden de oficina y de obra), en las cuentas de
  -- resultados; lo que el journal deja en el balance (lo que se debe) no es costo.
  with j as materialized (
    select a.id, a.fecha_contable as f
      from asientos a
     where a.origen_tabla = 'nomina_corridas' and a.reversa_a is null
       and not exists (select 1 from asientos r where r.reversa_a = a.id)
  ), c as (
    select date_trunc('month', j.f)::date as mes, j.id, l.cuenta, l.monto
      from j join asiento_lineas l on l.asiento_id = j.id
      join fn_tablero_mapa() m on m.cuenta = l.cuenta and m.estado = 'resultados'
     where j.f <= v_hoy
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'mes', to_char(g.mes, 'YYYY-MM'), 'etiqueta', fn_tablero_mes(g.mes), 'corto', fn_tablero_mes_corto(g.mes),
           'en_curso', g.mes = v_mhoy,
           'costo', coalesce(s.costo, 0), 'sueldos', coalesce(s.costo - s.patron, 0), 'patron', coalesce(s.patron, 0),
           'nominas', coalesce(s.n, 0)) order by g.mes), '[]'::jsonb)
    into v_serie
    from (select gs::date as mes from generate_series(v_m0::timestamp, v_mhoy::timestamp, interval '1 month') gs) g
    left join (select c.mes, sum(c.monto)::numeric(14,2) as costo,
                      coalesce(sum(c.monto) filter (where c.cuenta = any (v_bur)), 0)::numeric(14,2) as patron, count(distinct c.id) as n
                 from c group by c.mes) s on s.mes = g.mes;
  -- LA ÚLTIMA (día de pago hasta hoy) y LA PRÓXIMA (ya posteada, con día de pago después de hoy), del libro
  select a.id, a.numero, a.fecha_contable as f into v_ult
    from asientos a
   where a.origen_tabla = 'nomina_corridas' and a.reversa_a is null and a.fecha_contable <= v_hoy
     and not exists (select 1 from asientos r where r.reversa_a = a.id)
   order by a.fecha_contable desc, a.numero desc limit 1;
  select a.id, a.numero, a.fecha_contable as f into v_prox
    from asientos a
   where a.origen_tabla = 'nomina_corridas' and a.reversa_a is null and a.fecha_contable > v_hoy
     and not exists (select 1 from asientos r where r.reversa_a = a.id)
   order by a.fecha_contable, a.numero limit 1;
  v_hay := v_ult.id is not null or v_prox.id is not null;
  -- (lo de una nómina: con el código, de v_nomina_corridas de c15 —que lo pide—; sin él, su día y que lo demás va con el código)
  v_prj := case when v_ult.id is not null then fn_tablero_nomina_una(v_ult.id, v_cod) end;
  v_ulj := case when v_prox.id is not null then fn_tablero_nomina_una(v_prox.id, v_cod) end;
  -- LO QUE SE DEBE DE LA NÓMINA, según el libro (2210 a 2250, con lo fechado después de hoy), cuenta por cuenta
  select coalesce(jsonb_agg(jsonb_build_object('cuenta', m.cuenta, 'nombre', m.nombre,
                                               'monto', (-fn_tablero_saldo(array[m.cuenta], null))::numeric(14,2)) order by m.cuenta)
                    filter (where fn_tablero_saldo(array[m.cuenta], null) <> 0), '[]'::jsonb)
    into v_debe
    from fn_tablero_mapa() m where m.cuenta = any (v_ctas);
  v_dt := -fn_tablero_saldo(v_ctas, null);
  v_dh := -fn_tablero_saldo(v_ctas, v_hoy);
  -- LA BOLSA DEL BURDEN REAL (5015 de fábrica), hasta hoy: lo del patrón que todavía no se repartió a las obras
  select coalesce(sum(l.monto), 0)::numeric(14,2), max(a.fecha_contable) into v_bolsa, v_bmes
    from asiento_lineas l join asientos a on a.id = l.asiento_id
   where l.cuenta = v_cfg.cuenta_bolsa and a.fecha_contable <= v_hoy;
  -- «QUÉ ATENDER»: lo de la nómina que pide algo a Edgar, cada cosa con su apartado
  if (v_ctl ->> 'cuadres_rojos')::int > 0 then
    v_at := v_at || jsonb_build_object('clave', 'cuadre', 'alarma', true,
              'texto', format('La nómina no cuadra (%s): ', fn_tablero_plural((v_ctl ->> 'cuadres_rojos')::int, 'cuadre en rojo', 'cuadres en rojo'))
                       || (select string_agg(f ->> 'texto', ' ' order by (f ->> 'orden')::int) from jsonb_array_elements(v_ctl -> 'filas') f
                            where f ->> 'nivel' = 'cuadre'),
              'ir', jsonb_build_object('pagina', 'nomina', 'sub', 'nominas'));
  end if;
  if v_pp is not null and (v_pp ->> 'n')::int > 0 then
    v_at := v_at || jsonb_build_object('clave', 'por_postear', 'alarma', true,
              'texto', format('%s de Gusto %s sin postear (%s): mientras no, no está en el libro.',
                              fn_tablero_plural((v_pp ->> 'n')::int, 'nómina importada', 'nóminas importadas'),
                              case when (v_pp ->> 'n')::int = 1 then 'espera' else 'esperan' end,
                              case when v_pp ->> 'primero' = v_pp ->> 'ultimo' then 'día de pago ' || fn_tablero_dia((v_pp ->> 'primero')::date)
                                   else 'días de pago del ' || fn_tablero_dia((v_pp ->> 'primero')::date) || ' al ' || fn_tablero_dia((v_pp ->> 'ultimo')::date) end),
              'ir', jsonb_build_object('pagina', 'nomina', 'sub', 'nominas'));
  end if;
  if (v_car ->> 'n')::int > 0 then
    v_at := v_at || jsonb_build_object('clave', 'cargos', 'alarma', (v_car ->> 'dias')::int > 5,
              'texto', format('%s de Gusto por %s %s en el banco sin casar con su nómina (el más viejo, del %s): mientras no, la conciliación no se confirma.',
                              fn_tablero_plural((v_car ->> 'n')::int, 'cargo', 'cargos'), fn_tablero_usd((v_car ->> 'monto')::numeric),
                              case when (v_car ->> 'n')::int = 1 then 'espera' else 'esperan' end, fn_tablero_dia((v_car ->> 'mas_viejo')::date)),
              'ir', jsonb_build_object('pagina', 'nomina', 'sub', 'cargos'));
  end if;
  if (v_car -> 'devoluciones' ->> 'n')::int > 0 then
    v_at := v_at || jsonb_build_object('clave', 'devoluciones', 'alarma', false,
              'texto', format('%s de Gusto por %s %s casarse con su nómina.',
                              fn_tablero_plural((v_car -> 'devoluciones' ->> 'n')::int, 'devolución', 'devoluciones'),
                              fn_tablero_usd((v_car -> 'devoluciones' ->> 'monto')::numeric),
                              case when (v_car -> 'devoluciones' ->> 'n')::int = 1 then 'espera' else 'esperan' end),
              'ir', jsonb_build_object('pagina', 'nomina', 'sub', 'cargos'));
  end if;
  if coalesce((v_car ->> 'descasados')::int, 0) > 0 then
    v_at := v_at || jsonb_build_object('clave', 'descasados', 'alarma', true,
              'texto', format('%s de Gusto se des-%s en la Bandeja: deshazlo también en Nómina → Cargos de Gusto.',
                              fn_tablero_plural((v_car ->> 'descasados')::int, 'cargo', 'cargos'),
                              case when (v_car ->> 'descasados')::int = 1 then 'casó' else 'casaron' end),
              'ir', jsonb_build_object('pagina', 'nomina', 'sub', 'cargos'));
  end if;
  if v_bolsa <> 0 and v_bmes is not null and date_trunc('month', v_bmes)::date < v_mhoy then
    v_at := v_at || jsonb_build_object('clave', 'bolsa', 'alarma', false,
              'texto', format('La bolsa del burden real (%s) tiene %s sin repartir a las obras de un mes ya terminado: se reparte en Nómina → Ajustes.',
                              v_cfg.cuenta_bolsa, fn_tablero_usd(v_bolsa)),
              'ir', jsonb_build_object('pagina', 'nomina', 'sub', 'ajustes'));
  end if;
  if not v_cod and (v_ctl ->> 'con_codigo')::int > 0 then
    v_at := v_at || jsonb_build_object('clave', 'codigo', 'alarma', false,
              'texto', 'Lo de cada nómina (sus cuadres, las que esperan por postear) se comprueba con el código del teléfono: sal y vuelve a entrar con él.',
              'ir', jsonb_build_object('pagina', 'conexiones'));
  end if;
  return jsonb_build_object(
    'ok', true, 'tarjeta', 'nomina', 'corte', v_hoy, 'con_codigo', v_cod,
    'codigo', case when not v_cod then jsonb_build_object(
                'texto', 'Lo de cada nómina (sus totales, cuántas personas, lo que le queda por pagar y las que esperan por postear) se ve con el código del teléfono.',
                'ir', jsonb_build_object('pagina', 'conexiones')) end,
    'sin_nominas', not v_hay,
    'texto', case when not v_hay then 'Todavía no hay ninguna nómina de Gusto en el libro: sale aquí cuando subas su primer «Payroll journal» (Nómina → Nóminas).' end,
    'ultima', v_prj, 'proxima', v_ulj,
    'siguiente', case when v_ulj is null then jsonb_build_object(
                   'texto', 'La app no sabe cuándo es la siguiente: Gusto no se lo dice. Sale aquí en cuanto subas su journal.') end,
    'meses', v_serie, 'meses_pedidos', v_meses,
    'meses_con_nomina', (select count(*) from jsonb_array_elements(v_serie) s where (s ->> 'nominas')::int > 0),
    'debe', jsonb_build_object('monto', v_dt::numeric(14,2), 'a_hoy', v_dh::numeric(14,2), 'despues', (v_dt - v_dh)::numeric(14,2),
                               'cuentas', v_debe,
                               'texto', case when v_dt > 0 then 'Lo que el libro dice que se debe de la nómina (lo neto, lo retenido, lo del patrón, las deducciones y los reembolsos): Gusto lo cobra del banco unos días antes de cada día de pago.'
                                             when v_dt < 0 then 'El libro tiene a favor en las cuentas de la nómina (una corrección de Gusto que devolvió, o algo pagado de más): se casa con su devolución en Nómina → Cargos de Gusto.'
                                             else 'Nada se debe de la nómina según el libro.' end,
                               'ir', jsonb_build_object('pagina', 'nomina', 'sub', 'cargos')),
    'cargos', v_car || jsonb_build_object('ir', jsonb_build_object('pagina', 'nomina', 'sub', 'cargos')),
    'por_postear', case when v_pp is not null then v_pp || jsonb_build_object('ir', jsonb_build_object('pagina', 'nomina', 'sub', 'nominas')) end,
    'bolsa', jsonb_build_object('cuenta', v_cfg.cuenta_bolsa, 'monto', v_bolsa,
                                'texto', case when v_bolsa = 0 then 'La bolsa del burden real está repartida a las obras.'
                                              else format('La bolsa del burden real (%s) tiene %s sin repartir a las obras: se reparte al terminar su mes.',
                                                          v_cfg.cuenta_bolsa, fn_tablero_usd(v_bolsa)) end,
                                'ir', jsonb_build_object('pagina', 'nomina', 'sub', 'ajustes')),
    'control', v_ctl - 'filas',
    'atender', v_at,
    'fuente', 'las nóminas de Gusto que entraron por Nómina (c15): su costo por mes, del libro (sus journals, por su día de pago); lo que se debe, '
              || 'de las cuentas 2210 a 2250 del libro; los cargos de Gusto, de la Bandeja del banco; lo de cada nómina, de c15 con el código del teléfono',
    'ir', jsonb_build_object('pagina', 'nomina', 'sub', 'nominas'));
end $$;
revoke execute on function public.fn_tablero_nomina_de(jsonb, int) from public, anon, service_role;
grant  execute on function public.fn_tablero_nomina_de(jsonb, int) to authenticated;
comment on function public.fn_tablero_nomina_de(jsonb, int) is 'c16: (14-nov, Fase 11c) arma la tarjeta de la nómina con lo que espera de ella ya leído (fn_tablero_nomina_estado; nulo sin c15). La tarjeta es fn_tablero_nomina. Solo el dueño.';

create or replace function public.fn_tablero_nomina(p_meses int default 6) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_tablero_exigir_dueno();
  return fn_tablero_nomina_de(fn_tablero_nomina_estado(), p_meses);
end $$;
revoke execute on function public.fn_tablero_nomina(int) from public, anon, service_role;
grant  execute on function public.fn_tablero_nomina(int) to authenticated;
comment on function public.fn_tablero_nomina(int) is 'c16: (14-nov, Fase 11c) LA TARJETA DE LA NÓMINA: {ok, tarjeta: «nomina», corte, con_codigo, codigo (sin el código: {texto, ir}), sin_nominas, texto, ultima y proxima (con el código: {corrida, dia_pago, etiqueta, periodo, tipo, tipo_texto, personas, costo, bruto, patron, impuestos, neto, deducciones, reembolsos, por_pagar, a_favor, asiento, con_codigo: true, ir}; sin él: {dia_pago, etiqueta, asiento, con_codigo: false, texto, ir}), siguiente (si no hay próxima: {texto}), meses [{mes, etiqueta, corto, en_curso, costo, sueldos, patron, nominas}], meses_pedidos, meses_con_nomina, debe {monto, a_hoy, despues, cuentas [{cuenta, nombre, monto}], texto, ir}, cargos {n, monto, mas_viejo, dias, devoluciones {n, monto}, descasados, ir}, por_postear ({n, primero, ultimo, ir}; nulo sin el código), bolsa {cuenta, monto, texto, ir}, control {cuadres_rojos, avisos, con_codigo}, atender [{clave, alarma, texto, ir}], fuente, ir}. Sin c15: {ok: false, falta: «c15», motivo}. Solo lee. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 5. EL PEGADO: lo que enseña el final (seis filas). Solo el SQL Editor.
-- ---------------------------------------------------------------------
create or replace function public.fn_tablero_pegado() returns table (que text, detalle text)
language plpgsql
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_fn   int;
  v_com  int;
  v_def  int;
  v_api  int;
  v_tab  int;
  v_t    jsonb;
  v_ok   int := 0;
  v_falta int := 0;
  v_mal  text[] := '{}';
  v_no   text[] := '{}';
  v_k    text;
  r      record;
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  select count(*), count(*) filter (where coalesce(obj_description(p.oid, 'pg_proc'), '') like 'c16: %'),
         count(*) filter (where p.prosecdef),
         count(*) filter (where has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('service_role', p.oid, 'execute'))
    into v_fn, v_com, v_def, v_api
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and replace(p.oid::regprocedure::text, 'public.', '') = any (fn_tablero_funciones());
  select count(*) into v_tab from pg_class c
   where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v', 'm', 'p')
     and coalesce(obj_description(c.oid, 'pg_class'), '') like 'c16: %';
  return query select 'la capa'::text,
    format('c16 · marca %s · %s de %s funciones (%s con su comentario «c16: …») · %s · %s · %s', fn_tablero_version(), v_fn,
           cardinality(fn_tablero_funciones()), v_com,
           case when v_def = 0 then 'ninguna SECURITY DEFINER' else v_def || ' SECURITY DEFINER (¡no debería!)' end,
           case when v_api = 0 then 'ninguna para anon ni service_role' else v_api || ' que anon o service_role pueden ejecutar (¡no debería!)' end,
           case when v_tab = 0 then 'ninguna tabla ni vista: solo lee' else fn_tablero_plural(v_tab, 'tabla o vista', 'tablas o vistas') || ' con nombre de c16 (¡no debería!)' end);
  v_t := fn_tablero_capas();
  return query select 'las capas que ve'::text,
    (select string_agg(x.k || ' ' || case when (v_t ->> x.k)::boolean then 'sí' else 'no' end, ' · ' order by x.o)
       from (values (1, 'c4'), (2, 'c6'), (3, 'c6_prestamos'), (4, 'c7'), (5, 'p1'), (6, 'c8'), (7, 'c9'), (8, 'c10'), (9, 'c11'),
                    (10, 'c12'), (11, 'c13'), (12, 'c14'), (13, 'c15')) x(o, k));
  return query select 'el libro'::text,
    (fn_tablero_libro() ->> 'texto') || coalesce(' · ' || (select fn_tablero_plural(count(*), 'asiento', 'asientos') || ', del ' || fn_tablero_dia(min(a.fecha_contable))
                                                                   || ' al ' || fn_tablero_dia(max(a.fecha_contable))
                                                              from asientos a having count(*) > 0), ' · todavía sin asientos');
  v_t := fn_tablero('{"tope_ms": 0}'::jsonb);
  foreach v_k in array (select array_agg(e) from jsonb_array_elements_text(v_t -> 'tarjetas') e) loop
    if (v_t -> v_k ->> 'ok')::boolean then
      v_ok := v_ok + 1;
    elsif v_t -> v_k ? 'falta' then
      v_falta := v_falta + 1;
      v_no := v_no || (v_k || ' (falta ' || (v_t -> v_k ->> 'falta') || ')');
    else
      v_mal := v_mal || (v_k || ': ' || left(coalesce(v_t -> v_k ->> 'motivo', '?'), 160));
    end if;
  end loop;
  return query select 'una pasada del tablero'::text,
    format('%s tarjetas: %s contestan, %s dicen que su capa no está%s, %s fallan · %s ms', jsonb_array_length(v_t -> 'tarjetas'), v_ok, v_falta,
           case when cardinality(v_no) > 0 then ' (' || array_to_string(v_no, ', ') || ')' else '' end, cardinality(v_mal), v_t ->> 'ms');
  return query select 'qué falta'::text,
    case when cardinality(v_mal) > 0 then 'una tarjeta falla: ' || array_to_string(v_mal, ' | ') || '. Manda la captura.'
         when v_def + v_api + v_tab > 0 or v_com < v_fn or v_fn < cardinality(fn_tablero_funciones()) then 'algo de la capa no está como debe (arriba). Manda la captura.'
         else 'nada: todas las tarjetas contestan' || case when v_falta > 0 then ' (las de una capa que no está lo dicen ellas)' else '' end end;
  return query select 'siguiente paso'::text,
    'pega docs/conta/c16-pruebas.sql (sus filas, todas en true u «omitida» con su porqué); después, la portada nueva de Contabilidad sale al publicar la app.'::text;
end $$;
revoke execute on function public.fn_tablero_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_tablero_pegado() is 'c16: lo que enseña el final del pegado: la capa (sus funciones, que ninguna es SECURITY DEFINER ni de anon o service_role, que no crea tablas), las capas que ve, el libro, una pasada del tablero (cuántas tarjetas contestan y en cuánto), qué falta y el paso siguiente. Solo el SQL Editor.';

select * from public.fn_tablero_pegado();
