-- =====================================================================
-- C4 · Los estados financieros, el tablero y la apertura — Max Power
-- Electrical Solutions, Inc. (Fase 4, bloque A de f04)
-- Supabase → SQL Editor. Se pega ENTERO, después de c1-plan-de-cuentas.sql,
-- c2-libro.sql y c3-puentes.sql (pruebas/conta/README.md, §0). Se puede
-- volver a pegar encima de sí mismo las veces que haga falta: no duplica
-- nada, no pisa lo que Edgar ajustó (un renglón, una etiqueta, un mapeo) y
-- no toca el libro.
--
-- QUÉ ES. Todo lo que se LEE del libro, como vistas: la balanza, el
-- balance general, el estado de resultados, el flujo de caja por los dos
-- métodos, el mayor, y las vistas del tablero (f05: saldos de bancos y
-- tarjetas, antigüedad de lo que se cobra y se paga, en qué se gasta y a
-- quién, costo y dinero por obra, el dinero de cada mes). Y lo que hace
-- falta para empezar: la apertura al 30-sep-2026 desde la balanza de
-- QuickBooks (fn_apertura) y la comparación de cada mes del paralelo
-- contra QuickBooks, con sus diferencias explicadas.
--   · Ninguna cifra se calcula en JavaScript: todo sale de aquí, en
--     numeric(14,2) (dólares con centavos).
--   · Toda cifra baja a su asiento y del asiento a su papel (la llave
--     «bajar», abajo).
--   · Ninguna vista dibuja ceros callada: fn_estados_control dice, antes
--     de pintar, cuántas filas debía dar cada vista según el libro y si
--     los estados cuadran (la falla ruidosa de f05).
--   · Solo el dueño ve algo: todas las vistas son security_invoker (leen
--     con los permisos de quien mira, y el libro es solo del dueño); el
--     equipo lee 0 filas de todas, anon no las abre, y nadie de la API
--     ejecuta nada nuevo salvo fn_estados_control (que al equipo le dice
--     42501).
--
-- LO QUE CREA:
--   tablas     estados_historial, estados_lineas, estados_mapeo,
--              estados_config, apertura_mapeo_qb, apertura_balanza_qb,
--              comparacion_qb, diferencias (RLS, solo el dueño lee, nadie
--              de la API escribe; cada cambio con rastro, también cada
--              fila de QuickBooks que entra; quién y cuándo los pone la
--              base, fn_estados_quien; el historial solo acepta lo que
--              escriben sus triggers).
--   vistas     28 (ver el contrato, abajo).
--   funciones  del SQL Editor: fn_estados_sembrar (los renglones y el
--              mapeo de arranque; la llama el propio pegado y no pisa lo
--              que Edgar cambió), fn_estados_mapeo_derivar, fn_estados_mapeo,
--              fn_estados_linea, fn_estados_config, fn_apertura_mapeo_qb,
--              fn_apertura_mapeo_trabajo, fn_apertura_balanza_cargar,
--              fn_apertura_plan, fn_apertura_revisar, fn_apertura,
--              fn_comparacion_qb_cargar, fn_diferencia_anotar,
--              fn_diferencia_retirar (y sus ayudantes internos), y las
--              huellas de c4 (fn_estados_huellas, sellada al final de cada
--              pegado). De la app: fn_estados_control (la única con grant a
--              authenticated).
--   el JIT     apagado para el rol de la app en esta base («alter role
--              authenticated in database … set jit = off», 10): PostgREST lo
--              aplica en cada consulta, como su tope de 8 s.
--   NADA en el libro: ni triggers, ni índices, ni cambios en sus tablas.
--   Las huellas de c2 no cambian y no hay que resellarlas; el control
--   «permisos» de fn_verificar_cadena sigue en verde (lo mira: ninguna
--   vista sin security_invoker, ninguna función SECURITY DEFINER).
--   UNA VISTA O FUNCIÓN DE AYUDA sobre las tablas de este archivo (una
--   vista para el CPA, por ejemplo) va «with (security_invoker = true)» y
--   con «revoke all … from anon» (en Supabase nace con SELECT para anon y
--   authenticated, y sin security_invoker lee con los permisos de su dueño
--   y se salta la RLS); una función, sin SECURITY DEFINER. Si no,
--   fn_estados_control lo dice en rojo («protecciones de c4»).
--
-- CAMBIOS A c2 Y c3: UNO, la forma de sus policies de lectura (las del
-- dueño): «using ((select es_dueno()))» en vez de «using (es_dueno())».
-- Dicen lo mismo, pero así Postgres llama a es_dueno() UNA vez por
-- consulta y no una por fila leída: con 10.000 asientos, el control del
-- Panel pasa de 6.4 s a 2.4 s. Para tenerla hay que volver a pegar
-- c2-libro.sql y c3-puentes.sql (antes o después de este archivo, da
-- igual: se pegan encima de sí mismos sin tocar el libro); sin volver a
-- pegarlos todo funciona igual, solo más lento. Las tablas de este archivo
-- ya la llevan, y los controles aceptan las dos formas. Y en c3 (ronda 3
-- de c4; ver su cabecera): «reintentar puente» ya no vuelve a planear lo
-- que no cambió (con el libro lleno pasaba de los 8 s de la API), y el
-- cobro de una factura de antes del corte que no cabe dice qué hacer con
-- la apertura ya en el libro.
--
-- =====================================================================
-- CÓMO SE LEEN LAS CIFRAS (lo mismo en todas las vistas)
-- =====================================================================
--   monto     debe − haber, como en el libro: positivo = debe.
--   saldo     la suma de montos: debe − haber a la fecha.
--   cifra     lo que se PINTA en un estado: signo × saldo, donde el signo
--             es el de la sección (+1 activo, costo y gastos; −1 pasivo,
--             capital e ingresos). Así todo sale en positivo en su lado y
--             una contra-cuenta (1590, 3200, 5011) sale restando sola.
--   periodo   el nombre del período (2026-10, 2026-09-APERTURA, 2026, o
--             'hoy' en las vistas que van por corte). Toda vista de estados
--             se filtra por él: where periodo = '2026-10'. Un período de
--             tipo 'anio' es el año entero.
--   corte     el último día del período (en 'hoy', hoy en Miami): el saldo
--             se toma con todo lo fechado hasta ese día, incluido.
--   ejercicio el año al que pertenece una línea: el de su fecha, salvo en
--             un ajuste del CPA (ajuste_cpa), que es del año del período que
--             corrige. Un ajuste de 2026 posteado en enero de 2027 es de
--             2026: no toca el resultado de 2027 y en el balance va a
--             utilidades retenidas (o a «por cerrar»).
--   nivel     el tipo de renglón: 'cuenta' (el detalle), 'componente' (una
--             cifra que no es de una cuenta: el resultado del ejercicio, el
--             arrastre), 'linea' (el renglón del estado), 'seccion' (su
--             subtotal), 'total', 'control' (un cuadre, con cuadra = true),
--             'partida' (una factura, un recibo), 'obra', 'proveedor'.
--   asientos  cuántos asientos hay detrás de la cifra; asiento_id y numero,
--             el asiento, cuando es uno solo.
--   0 FILAS   significa «no hay nada que pintar»: un período sin asientos,
--             o alguien que no es el dueño. NUNCA «la vista falló» (eso es
--             un error), y fn_estados_control dice si el libro esperaba
--             filas.
--
-- LA LLAVE «bajar» (jsonb, en cada fila): por cada columna con cifra, la
-- lista de pedazos que la suman. Cada pedazo es
--   {"vista": "v_libro", "campo": "monto", "signo": 1,
--    "filtros": {"cuenta": "1110", "proyecto_id": "casa-perez-k3m9"},
--    "desde": "2026-10-01", "hasta": "2026-10-31"}
-- y vale signo × la suma de «campo» en las filas de «vista» que cumplen
-- todos los filtros y cuya fecha está entre desde y hasta (los dos
-- opcionales, incluidos). Un filtro es:
--   "col": valor          col = valor (comparado como texto)
--   "col": [v1, v2]       col es uno de ellos
--   "col": null           col es nula
--   "col_hasta": valor    col ≤ valor (periodo_efectivo_hasta)
--   "col_no": valor/[…]   col no es ese (o ninguno de ellos)
-- Una lista vacía vale 0. Las vistas a las que se baja: v_libro (las
-- líneas del libro), v_flujo_lineas (las piezas que explican el dinero),
-- v_gasto_lineas (las de gasto, con su proveedor) y v_efectivo_movimientos
-- (el dinero de cada asiento: lo que entró y salió de los bancos); cada
-- una trae el asiento_id, y v_asiento_papel lleva del asiento a su papel
-- (el recibo con su foto, la factura, el cobro, la balanza de apertura…).
-- En la comparación y en el resultado de la apertura también se baja a
-- v_qb_balanzas (las filas de QuickBooks, con su documento) y a
-- diferencias (las anotaciones).
-- La pantalla lo usa para el clic: cifra → sus líneas → su asiento → su
-- papel. c4-pruebas.sql comprueba, fila por fila y cifra por cifra, que
-- cada «bajar» suma exactamente la cifra y llega a un asiento y a su papel.
--
-- =====================================================================
-- EL CONTRATO DE CADA VISTA (una fila por…, se filtra por…, cifras)
-- =====================================================================
-- BASE
--   v_estados_mapeo        una por cuenta del plan: dónde sale (estado,
--                          sección, renglón, signo, efectivo, renglones del
--                          flujo y su sección), sus etiquetas y sin_fila
--                          (sin fila guardada: sale con lo propuesto y
--                          fn_estados_control la dice en rojo).
--   v_estados_mapeo_propuesto  lo que se deriva de cuentas.tipo y el código.
--   v_cortes               una por período más 'hoy' (del primero del mes a
--                          hoy, en Miami): desde y corte.
--   v_ejercicios           una por año: cerrado o no.
--   v_libro                una por línea del libro (asiento, papel, mapeo,
--                          ejercicio, dimensiones, tercero, partida). monto,
--                          debe y haber. Se filtra por periodo, anio,
--                          cuenta, proyecto_id… Es a donde baja todo.
--   v_mayor                v_libro + saldo corrido por cuenta (saldo,
--                          saldo_en_su_lado) y reversado. El saldo corrido
--                          se calcula con toda la historia de la cuenta y
--                          después se filtra; en las de resultados, por
--                          ejercicio (empieza cada año en cero, como la
--                          balanza: un ajuste del CPA de 2026 posteado en
--                          2027 corre con 2026).
--   v_asiento_papel        una por asiento: su papel (texto), papel_ruta
--                          (la foto o el PDF) y papel_existe. La apertura
--                          es de la balanza solo si la posteó fn_apertura;
--                          una hecha a mano es su propio papel.
-- ESTADOS (por período)
--   v_balanza              una por cuenta con movimiento hasta el corte (en
--                          resultados, las del año), más los componentes
--                          'arrastre' (resultado de años ya cerrados) y
--                          'por_cerrar' (de años anteriores sin cerrar), más
--                          el 'total': saldo_inicial, debe, haber y
--                          saldo_final (debe − haber). El total, en cero
--                          (cuadra = true).
--   v_balanza_obra         lo mismo por cuenta, obra y cost code.
--   v_balance_general      a cada corte (también 'hoy'): cuentas de balance,
--                          componentes del capital ('resultado' del año;
--                          'resultado_apertura', lo de enero al día de la
--                          apertura según su balanza de QuickBooks, que pasa
--                          de utilidades retenidas al resultado del año, y
--                          en los años siguientes, mientras ese año no se
--                          cierre, a «ejercicios anteriores por cerrar»;
--                          'arrastre', 'por_cerrar', y 'plegado_3200' si el
--                          CPA lo pide), las reclasificaciones de
--                          presentación (los saldos contrarios van del otro
--                          lado: anticipos de clientes al pasivo, saldos a
--                          favor con proveedores y tarjetas al activo, un
--                          banco en rojo al pasivo como sobregiro, y toda
--                          otra cuenta de pasivo deudora al activo —2900 a
--                          «cuenta por cobrar al accionista», la nómina y
--                          los impuestos pagados de más— o de activo
--                          acreedora al pasivo),
--                          renglones, secciones y los totales total_activo,
--                          total_pasivo, total_capital, pasivo_mas_capital y
--                          cuadra (activo − pasivo − capital = 0.00, cuadra
--                          = true). saldo y cifra, y saldo_ajustado y
--                          cifra_ajustada (con los ajustes del CPA
--                          posteriores que corrigen hasta el corte, por
--                          FECHA: un ajuste al año cuenta como del 31-dic).
--   v_resultados           por cuenta, renglón, sección y las utilidades
--                          (bruta, de operación, neta): mes, mes_anterior
--                          (nulo antes del libro), variacion (y %, con el
--                          signo del estado: una venta que baja, en
--                          negativo), acumulado (el año hasta el fin del
--                          período, desde acumulado_desde), posteriores
--                          (ajustes del CPA fechados después que corrigen
--                          hasta este período) y acumulado_ajustado. Cifras
--                          con el signo del estado (ingresos y costos en
--                          positivo; utilidad negativa = pérdida).
--   v_flujo_caja           por método ('directo', 'indirecto'): renglones,
--                          secciones (operación, inversión, financiamiento,
--                          ajustes y el bloque 'sin_dinero', que se revela
--                          y NO suma: un activo con tarjeta o con préstamo,
--                          una distribución sin dinero, ASC 230), totales
--                          (efectivo_inicial, cambio, efectivo_final) y los
--                          'control': 'cuadra' (el cambio de cada método =
--                          el del efectivo = el del otro método) y
--                          'cuadra_<sección>' (cada sección igual en los dos
--                          métodos). importe en positivo = dinero que entra.
--                          El efectivo es el del balance (las cuentas en
--                          negro); lo que prestan las que están en rojo es
--                          financiamiento, «Sobregiro bancario». La
--                          apertura no es un flujo: en su período (y en su
--                          año) lo que trajo es el efectivo al inicio.
--   v_flujo_lineas         las piezas que explican el dinero, con su renglón
--                          de cada método (la base de los dos flujos): la
--                          línea que no es dinero, y sus reclasificaciones
--                          (la ganancia en venta de un activo a inversión, el
--                          pago de la tarjeta que compró un activo, por lo
--                          que compró; en un asiento con dinero, la parte de
--                          un activo que cubrió un préstamo del mismo
--                          asiento, a «sin dinero»).
-- TABLERO
--   v_efectivo_movimientos una por asiento que movió dinero: su neto en los
--                          bancos (entrada o salida) y si es un error y su
--                          reverso del mismo mes (par_en_el_mes).
--   v_flujo_real_por_mes   una por mes empezado: efectivo_inicial, lo que
--                          ENTRÓ y SALIÓ de verdad de los bancos (el neto de
--                          cada asiento; sin los pares error-reverso del
--                          mes), neto, sobregiro (lo que prestan los bancos
--                          en rojo), efectivo_final (el del balance) y el
--                          neto por sección (operación, inversión,
--                          financiamiento, ajustes).
--   v_saldos_dinero        por corte, una por banco, tarjeta y línea de
--                          crédito (activa o con saldo): saldo en su lado
--                          (lo que hay; lo que se debe), saldo_inicial,
--                          cargos, abonos, ultimo_movimiento.
--   v_cxc_antiguedad       por corte, una por partida abierta de cobrar
--                          (factura, anticipo, sin partida) y el 'total':
--                          por_cobrar (1110), retencion (1120, aparte),
--                          total, d0_30…d90_mas, anticipos (en negativo:
--                          los anticipos y los saldos a favor), cargos,
--                          abonos, fecha, dias y tramo ('0-30', '31-60',
--                          '61-90', '90+', 'anticipo', 'a_favor' = crédito
--                          del cliente sin factura, 'retencion' = solo
--                          queda la retención). Un cobro parcial deja la
--                          factura abierta por la diferencia; una nota de
--                          crédito la cierra; un cheque devuelto la vuelve
--                          a abrir. El total, contra el mayor de 1110 +
--                          1120 (cuadra).
--   v_cxp_antiguedad       lo mismo de pagar (2010 y la retención a
--                          subcontratistas, 2020), por partida o proveedor:
--                          la fecha del papel, o la de lo más viejo sin
--                          pagar (FIFO; lo de la apertura, factura por
--                          factura con la fecha de la balanza) y de dónde
--                          salió (fecha_origen); sin fecha, tramo
--                          'apertura' (sin_fecha); vence (el de la balanza,
--                          o por los términos del proveedor: Net 30, Net 10
--                          EOM, Net 10th Prox…) y dias_vencida; por_pagar en
--                          positivo; a_favor.
--   v_gasto_lineas         una por línea de gasto (costo, gastos, otros
--                          gastos) con su proveedor y de dónde salió (la
--                          línea, el asiento, el papel; «varios» si el
--                          asiento tiene varios y no se puede repartir).
--   v_gasto_por_categoria  por período, una por cuenta de gasto y el total:
--                          mes, acumulado, pct.
--   v_gasto_por_proveedor  por período, una por proveedor y el total.
--   v_costo_por_obra       por período: nivel 'cuenta' (obra y cuenta, las
--                          de resultados que van por obra), nivel 'obra'
--                          (cuatro filas por obra: ingresos, costo, margen =
--                          ingresos − costo, y otros) y nivel 'control' (por
--                          cuenta, y por sección con todas las cuentas del
--                          estado de resultados: lo repartido por obra en
--                          del_anio, sin_repartir —lo que no tiene obra, como
--                          el burden 5011, 5015 y 5019— y mayor; cuadra):
--                          del_periodo, del_anio,
--                          desde_inicio (toda la obra en el libro, de todos
--                          los años), libro_desde y parcial (la obra ya
--                          andaba antes del libro: lo de antes está en
--                          QuickBooks).
--   v_obras_dinero         por corte, una por obra con movimiento:
--                          por_cobrar_apertura, facturado, cobrado (el
--                          dinero que entró), otros, por_cobrar, retencion y
--                          cuadra (apertura + facturado − cobrado + otros =
--                          por cobrar + retención), costo (mano de obra,
--                          material, subcontratos), margen, libro_desde y
--                          parcial. (El contrato y el presupuesto viven en
--                          la app.)
-- QUICKBOOKS
--   v_qb_balanzas          las filas de QuickBooks de cada período, con su
--                          cuenta del plan y su obra (vigente = la que vale;
--                          con_posteriores = la final del CPA; al = su
--                          fecha si es de una quincena; vivo = el asiento
--                          de la apertura sigue vivo). Las filas de control
--                          (Net Income, TOTAL ASSETS) no salen.
--   v_comparacion          por período con balanza de QuickBooks, una por
--                          cuenta (y una por cada nombre sin mapeo), con el
--                          libro cortado a la fecha de la balanza (al):
--                          arrastre_apertura, posteriores (si la balanza es
--                          la final), comparable, qb, diferencia, explicada,
--                          sin_explicar, ok; cada cifra con su «bajar».
--   v_comparacion_obra     lo mismo por obra, solo en las cuentas que la
--                          balanza del período trae por Customer:Job (con el
--                          arrastre de cada obra).
--   v_comparacion_resumen  una por período: cuentas que cuadran, lo sin
--                          explicar y la utilidad del libro contra la de
--                          QuickBooks (acumulada y del mes), con su «bajar».
--
-- EL CONTROL (lo que conta.js pide antes de pintar una pantalla)
--   select * from fn_estados_control('2026-10', array['v_balanza', 'v_resultados']);
--   select * from fn_estados_control('hoy');   -- el Panel
--   Una fila por vista pedida (25 posibles: todas menos las tres de paso,
--   v_estados_mapeo_propuesto, v_ejercicios y v_balanza_base): filas (lo
--   que devolvió para ese período), esperadas (lo que dice el libro,
--   contado aparte desde sus tablas, el mapeo y las balanzas de
--   QuickBooks, sin pasar por la vista), ok y detalle (por qué no se
--   pinta: la vista falló, o dio otra cantidad, 0 donde hay asientos). Y
--   una fila por cada cuadre de las vistas pedidas: balanza en cero;
--   activo = pasivo + capital; flujo directo = indirecto = cambio del
--   efectivo (y sección por sección); antigüedad de cobrar = mayor;
--   antigüedad de pagar = mayor; auxiliar por obra = mayor; resultado del
--   estado = el del balance (si se piden los dos); mapeo completo;
--   QuickBooks sin diferencias sin explicar, por cuenta y por obra; el
--   dinero por obra; el efectivo del flujo (y el del Panel) = el del
--   balance; y SIEMPRE las protecciones de c4 (sus triggers, sus huellas,
--   sus permisos también por columna, el rastro de cada regla y cada
--   balanza, y lo ajeno que abra sus tablas a la API) y la apertura en el
--   libro (la de la balanza, viva y como entró). Con 'hoy', solo las
--   vistas por corte. Un nombre que no conoce, un nulo o la lista vacía:
--   una fila en rojo (orden 0). Cualquier ok = false: la pantalla no pinta
--   y dice cuál.
--
-- =====================================================================
-- LA APERTURA, PASO A PASO (Edgar, en el SQL Editor, cuando llegue la
-- balanza al 30-sep; ver f04)
-- =====================================================================
--   1. Sube el PDF y el CSV de la balanza a Storage (docs/apertura/…).
--   2. Cárgala: select fn_apertura_balanza_cargar('docs/apertura/balanza-2026-09-30.csv',
--        '[{"cuenta_qb": "Chase Chk 4392", "debe": "25,000.00"}, …]');
--      con la cédula donde hace falta: cuentas por cobrar factura por
--      factura (su número de QuickBooks en factura_num, o el id de la app
--      en factura_id; y retencion), cuentas por pagar por proveedor
--      (proveedor_qb, y si se tiene del A/P Aging, fecha_documento, vence y
--      referencia de cada factura), la retención por cobrar también por
--      factura, la retención por pagar (2020) por proveedor, cuentas por
--      obra (cliente_trabajo). La fila TOTAL del reporte se aparta (no se
--      suma) y dice si coincide. Y SU CONTROL, de su Balance Sheet: la fila
--      «Net Income» (la utilidad de enero a septiembre) y la fila «TOTAL
--      ASSETS»; se apartan (no se suman) y fn_apertura exige que el mapeo
--      dé lo mismo. Dice qué nombres no tienen mapeo todavía.
--   3. Mapea cada nombre: fn_apertura_mapeo_qb('Opening Balance Equity', '3900');
--      y cada Customer:Job: fn_apertura_mapeo_trabajo('Pérez, Juan:Casa Pérez', 'casa-perez-k3m9').
--   4. Mírala: select * from fn_apertura_revisar('docs/apertura/…');
--      Fila por fila de QuickBooks, a qué cuenta del plan va y de qué tipo
--      (activo, costo…), para auditar el mapeo. Para en el primer problema,
--      con su nombre (MX001 no cuadra o no amarra con su control, MX004 sin
--      mapeo, MX006 una fila que no va así, MX008 falta algo de la app).
--   5. Postéala: select fn_apertura('2026-09-30', 'docs/apertura/…');
--      Otra vez con la misma balanza y el mismo mapeo: no hace nada. Con
--      otra balanza, o con la misma y un mapeo corregido: dice qué cambia y
--      no toca nada; con el motivo, la sustituye. Si hay una apertura hecha
--      a mano viva, para (se reversa antes).
--   6. Compárala: select * from v_comparacion where periodo = '2026-09-APERTURA';
--      todo en ok (la retención partida a 1120 ya viene anotada).
-- LAS TRAMPAS DE QUICKBOOKS, y qué hace cada una:
--   Opening Balance Equity y Retained Earnings: capital; se mapean (a 3900,
--     salvo que el CPA diga otra cosa). Sin mapeo, para y lo dice.
--   Net Income: no es una cuenta (ya está en las de resultados): es el
--     CONTROL de la balanza, con TOTAL ASSETS; se aparta al cargarla y la
--     utilidad que da el mapeo tiene que ser la suya. Un mapeo al lado
--     equivocado (material de enero a septiembre a una cuenta de balance)
--     para con MX001 y la fila que lo explica.
--   Las cuentas de resultados de enero a septiembre: a 3900, en una línea
--     con su nota (utilidad, ingresos, costo, gastos).
--   Undeposited Funds: cobros recibidos sin depositar; se mapean al banco
--     (depósito en tránsito). Sin mapeo, para y lo dice.
--   Subcuentas («Credit Cards:Amex 2009», «Chase  Chk 4392 »): el nombre se
--     casa sin mayúsculas ni espacios de sobra, ni alrededor de «:». Una
--     tarjeta que no esté en el plan (Amex 1007) se añade antes en c1. La
--     fila del grupo en 0 se salta.
--   Saldos negativos: en su columna con signo menos o entre paréntesis;
--     saldo = debe − haber, y así entran (una tarjeta con saldo a favor, un
--     banco sobregirado, un crédito del cliente).
--   Customer:Job: casado con la obra (fn_apertura_mapeo_trabajo); la
--     cuenta por cobrar (1110) y la retención (1120) van por factura, con
--     la obra de la factura. Si el Customer:Job está mapeado a otra obra
--     que la de su factura, la carga para (MX006) y dice dónde está la
--     factura: se corrige el mapeo, no se da de alta otra vez.
--   Una cuenta sin mapeo: para en la primera y la nombra (MX004).
--
-- =====================================================================
-- DECISIONES (y por qué)
-- =====================================================================
--   · El resultado de los años anteriores NO se postea: el libro no tiene
--     asientos de cierre. El balance lo arrastra a la vista: resultado del
--     año del corte en «Resultado del ejercicio»; el de años ya cerrados,
--     dentro de «Utilidades retenidas» (3900 + arrastre); el de años sin
--     cerrar, en «por cerrar». Así cerrar un año no escribe nada y un
--     ajuste del CPA a un año cerrado cae donde debe.
--   · 3200 (distribuciones) se enseña aparte, las de toda la vida. Si el
--     CPA quiere plegarlas a utilidades retenidas al cerrar cada año (como
--     QuickBooks): select fn_estados_config('plegar_3200', 'si'); — solo
--     presentación: el total del capital no cambia y no se postea nada.
--   · La apertura entra por fn_postear_interno como asiento de apertura a
--     mano (camino 'mano': la postea Edgar desde el SQL Editor), con su
--     papel (origen apertura_balanza_qb / el período de la apertura,
--     documento_ruta = la balanza): c2 no deja dos asientos vivos del mismo
--     papel, y el de una apertura a mano sin balanza lo para fn_apertura
--     (MX007). No va por el camino 'puente': c2 deja reversar el asiento de
--     apertura con fn_reversar mientras la apertura está abierta (y
--     cerrada, lo manda al ajuste a la apertura), y c3 no deja que nada
--     anterior al corte entre por un puente (la prueba 71 de c2 y la 15 de
--     c3 lo miran, y con la apertura de verdad ya en el libro saldrían en
--     rojo si fuera de puente).
--   · Cuentas por cobrar y retención POR FACTURA en la apertura (lo que c3
--     espera para aplicar los cobros de octubre: el cobro de la retención
--     va contra la partida de su factura en 1120; por obra, sin partida,
--     «no cabía»). Si QuickBooks tiene la retención dentro de A/R, la
--     apertura la parte con la columna retencion de su fila, y esa
--     diferencia de criterio la anota fn_apertura sola en diferencias; si
--     la trae en su propia cuenta (Retainage Receivable), va por factura
--     como la de A/R. La retención por pagar (2020), por proveedor.
--   · El flujo directo, por contrapartida y sin prorratear: en cada asiento
--     que mueve dinero, cada línea que no es dinero explica su parte; como
--     el asiento suma cero, los dos métodos dan exactamente el cambio del
--     efectivo, al centavo, y cada sección igual en los dos (cada cuenta de
--     balance, en la misma sección en los dos métodos: la guarda del mapeo
--     lo exige). La apertura no es un flujo: lo que trajo es el efectivo al
--     inicio de su período y de su año. Lo que se
--     mueve sin dinero (un activo con tarjeta o con préstamo, una
--     distribución a cuenta del accionista) se revela aparte y no suma (ASC
--     230); la venta de un activo sale entera en inversión (la ganancia se
--     resta de la utilidad en el indirecto); el pago de una tarjeta que
--     compró un activo, en inversión (sus cargos más viejos primero). Lo
--     que la empresa le presta al accionista (1130) es inversión.
--   · El balance no compensa saldos contrarios (ASC 210-20): un anticipo de
--     un cliente es pasivo, un saldo a favor con un proveedor es activo, un
--     banco en rojo es sobregiro (y en el flujo, financiamiento), un
--     préstamo del accionista deudor es una cuenta por cobrar al accionista
--     (Schedule L, renglón 7 y no 19), una nómina o un impuesto pagado de
--     más es activo; se reclasifican al presentarlos, cada uno con su
--     «bajar», sin postear nada.
--   · La antigüedad por la fecha del papel (factura, recibo); la de pagar
--     dice además cuándo vence por los términos del proveedor. Lo que trajo
--     la apertura se envejece con la fecha que trae la balanza, o se dice
--     sin fecha: no se inventa el 30-sep.
--   · El proveedor de un gasto: el de la línea, el del asiento (su deuda en
--     2010; con varios, el de la deuda del mismo monto, o «varios» si no se
--     puede saber) o el del papel (el nombre del recibo casado con sus
--     alias); un recibo de tarjeta sin alta sale con su nombre escrito.
--   · El reembolso a un empleado (2250) sale en «Nómina», como la nómina:
--     ASC 230-10-45-25 deja juntar los pagos a empleados y a proveedores, y
--     nadie concilia ese renglón aparte.
--   · El control no calcula lo esperado con las vistas: lee las tablas del
--     libro, el mapeo y las balanzas de QuickBooks, en una pasada, y solo
--     para las vistas pedidas (una vista vacía o rota no se cuenta a sí
--     misma). Corre sin el compilador JIT (set jit = off, solo ella).
--   · Ninguna vista nombra cuentas.activa, cuentas.saldo_normal,
--     periodos.estado ni periodos.cerrado_*: los leen de la fila entera
--     (to_jsonb, en modo strict: si la columna desaparece o cambia de
--     nombre, la vista falla con «JSON object does not contain key», no da
--     nulos). Una vista que nombra una columna le fija el tipo (ALTER TABLE
--     … TYPE sale con 0A000), y las pruebas 24 y 66 de c2 reescriben
--     justo esas columnas por debajo de sus triggers, como ataque, para
--     ver que c2 lo delata: con las vistas nombrándolas, las dos salían en
--     rojo. (c4-pruebas, prueba 1, lo vigila: columnas_fijadas=0.) Una
--     fase futura que haga vistas sobre esas columnas tiene que hacer lo
--     mismo.
--   · Toda columna de cifra es numeric(14,2), también en las ramas de una
--     unión que son cero o nulo: dos decimales exactos, sin que el tipo
--     cambie según la fila.
--
-- =====================================================================
-- ÍNDICES Y TIEMPOS (medidos en el banco de pruebas como la app:
-- authenticated, el dueño, con la policy del libro y el tope de 8 s de la
-- API; pruebas/conta/c4-volumen.sh)
-- =====================================================================
--   Un libro de verdad, hecho por los puentes como lo hace la app: la
--   apertura por su balanza de QuickBooks y 15 meses (oct-2026 a
--   dic-2027) de 30 obras de tres tipos: facturas con retención y sus
--   cobros parciales, tickets con dos tarjetas y su pago, recibos a cuenta
--   de 40 proveedores y su pago con partida, trabajos externos de 10
--   ayudantes, la nómina de cada semana con retenciones, statements
--   repartidos entre obras y gastos del banco: 10.324 asientos, 23.188
--   líneas. Se lee el último mes (2027-12) y 'hoy', en ms (el banco es un
--   contenedor: en Supabase las cifras serán otras, del mismo orden):
--                                                  PG16    PG17.6
--     v_balanza                                     233       231
--     v_balanza_obra                                227       259
--     v_balance_general (el mes / hoy)          388/397   431/410
--     v_resultados                                  158       170
--     v_flujo_caja                                  270       310
--     v_flujo_real_por_mes (todos los meses)        433       499
--     v_saldos_dinero (hoy)                         200       136
--     v_cxc_antiguedad (hoy)                        169       184
--     v_cxp_antiguedad (hoy)                        210       260
--     v_gasto_por_categoria                         417       528
--     v_gasto_por_proveedor                         455       563
--     v_costo_por_obra                              413       461
--     v_obras_dinero (hoy)                          459       541
--     v_comparacion_resumen                         148       144
--     v_libro (el mes)                              103       118
--     v_mayor (1010, el mes)                         91       100
--     v_asiento_papel (el mes)                       72        75
--     fn_estados_control, el Panel (9 vistas)      2414      2944
--     fn_estados_control('hoy')                    1560      1651
--     fn_estados_control, los estados (4)          1268      1523
--     fn_estados_control, el año (4)               1575      1704
--     fn_estados_control, todas las vistas         4030      4746
--     c4-pruebas.sql entero, sobre ese libro      53,5 s    63,1 s
--       (con un teléfono subiendo un ticket cada segundo: ninguna subida
--       cortada; la que más esperó, 6,1 s y 7,4 s)
--   Todo bajo su tope (4 s cada vista, 8 s cada control), los cuadres en
--   verde y fn_verificar_cadena también. Lo que pesaba y ya no: la policy
--   del libro, «using (es_dueno())», llamaba a es_dueno() por cada fila
--   leída (ahora «(select es_dueno())», una vez por consulta: el control
--   del Panel de 6,4 s a 2,4 s); el compilador JIT de Postgres, que tarda
--   más en compilar estas consultas que en correrlas (fn_estados_control
--   lo apaga para sí: el Panel de 4,4 s a 2,5 s, y este archivo se pega en
--   5 s y no en 26 con el libro lleno); v_gasto_lineas, que recorría
--   trabajos_externos por cada línea de gasto (la llave del join era una
--   expresión: ahora se calcula antes, y v_gasto_por_proveedor pasa de
--   4,2 s a 0,5 s); y v_flujo_real_por_mes, que leía el libro entero una
--   vez por cada mes (ahora una pasada).
-- ÍNDICES: este archivo no añade ninguno al libro. Los que usan las vistas
-- ya están (asientos por período, líneas por asiento, por cuenta, por
-- partida, por obra y por tercero); los de sus propias tablas son sus
-- llaves y el de diferencias por (periodo, cuenta). Un índice por fecha en
-- asientos se midió: con estos volúmenes bajaba el flujo y el gasto un 20 a
-- 35 % y nada lo demás, y tocaría las huellas de c2: no vale todavía.
--
-- =====================================================================
-- LO QUE QUEDA ABIERTO
-- =====================================================================
--   · La apertura de verdad (fn_apertura, ya confirmada) deja fuera de
--     juego las pruebas de c4-pruebas que postean una apertura de prueba
--     (29 a 36, 50, 51, 53, 56, 61, 62, 69, 73, 76, 81, 84 y 86: salen
--     «omitida»): se corren antes, recién pegado c4.
--   · El flujo sigue por lo que compró el pago de una tarjeta que compró un
--     activo (o una distribución), pero no un activo comprado a crédito de
--     un proveedor (2010), ni la parte a tarjeta de un activo pagado en
--     parte con dinero EN EL MISMO asiento: su pago sale en operación. Si
--     pasa, se reclasifica con un asiento, o se postea la compra en dos.
--     (Un activo pagado en parte con un PRÉSTAMO en el mismo asiento sí:
--     la parte del préstamo va a «sin dinero».)
--   · El compilador JIT: apagado para la app (el rol authenticated en esta
--     base, 10) y para fn_estados_control y c4-pruebas. Cambiar el rol pide
--     ser su dueño o tener ADMIN sobre él (en Supabase, el SQL Editor lo
--     es): si el pegado no pudo, lo dice con un WARNING, la fila «c4 · jit»
--     del final sale en false y la prueba 88 de c4-pruebas en rojo; se
--     arregla pegando esa sentencia como dueño. Con el JIT del servidor, la
--     gráfica del Panel pasaba de 2 s con el libro lleno, casi todo
--     compilando.
--   · c4-pruebas con el libro lleno tarda algo más de un minuto; ninguna
--     de sus subtransacciones tiene el libro más de 2 o 3 s (la 25 y la 37
--     van por período y por grupo de vistas), pero mientras corre una
--     subida de la app puede esperar eso: mejor correrla sin nadie usando
--     la app. (c4-volumen.sh la corre con cuatro teléfonos subiendo un
--     ticket cada 0,25 s, con 2026 abierto y cerrado, y falla si alguna
--     subida se corta o espera 8 s.)
--   · El contrato y el presupuesto de cada obra viven en la app
--     (finanzas_proyecto, estimados): la pantalla los pone al lado de
--     v_obras_dinero.
--   · La conciliación de bancos y tarjetas (f06), la nómina (f11) y el WIP
--     (f13-14) llenan sus renglones cuando lleguen: las vistas ya los
--     tienen.
--
-- LOS ERRORES CON NOMBRE de este archivo (los de c2 y c3 siguen igual):
--   MX000 falta lo que el archivo da por hecho (no se aplica nada)
--   MX001 la balanza de QuickBooks no cuadra
--   MX002 la apertura va fechada el día de la apertura; no hay apertura
--   MX003 lo importado o anotado no se edita, no se borra, no crece y no se
--         vacía (se carga otro, se retira); las reglas y los mapeos no se
--         vacían con TRUNCATE
--   MX004 una cuenta de QuickBooks sin mapeo, o mapeada a una de grupo o
--         inactiva; una cuenta que no existe
--   MX005 un monto que no es monto o con más de dos decimales
--   MX006 una fila o un mapeo que no puede ir así (sección, signo, obra,
--         factura, retención)
--   MX007 la apertura ya está con otra balanza o con otro mapeo (dice qué
--         cambia; con motivo, la sustituye); ya hay una apertura a mano; la
--         balanza cambió desde que entró (su huella)
--   MX008 falta algo de la app: la factura (por su id o su número), el
--         proveedor, el recibo, el trabajo externo, la obra, el
--         Customer:Job, la balanza; un número de factura que está en dos
--         obras sin decir cuál
--   42501 no es el dueño
-- =====================================================================


-- =====================================================================
-- 0 · PRECONDICIONES — solo lee (y deja puesta la función que mira lo
--     ajeno, fn_estados_vistas_ajenas). Si algo falta, no se aplica nada
--     (el SQL Editor manda todo en una sola petición: la primera excepción
--     deshace el pegado entero, también esa función).
--   · El libro de c1 y c2 (con tercero y partida en las líneas) y los
--     puentes de c3 (las partidas de CxC y CxP, los cobros, los
--     proveedores y los puentes que la apertura pone al día).
--   · Si ya hay una tabla con el nombre de una de este archivo, tiene que
--     ser la de este archivo: «create table if not exists» se saltaría
--     callado una ajena y todo lo de abajo fallaría sin explicar por qué.
--   · Ninguna vista ni función ajena depende de las vistas de este
--     archivo: al volver a pegarlo se borran y se rehacen, y se las
--     llevarían por delante sin avisar (MX000 las nombra).
-- Este archivo NO toca ninguna tabla, trigger ni función que vigilan las
-- huellas de c2 (no pone triggers en el libro ni índices en sus tablas):
-- no tiene que resellarlas, y fn_verificar_cadena sigue en verde después
-- de pegarlo (su control permisos sí mira las vistas y funciones de aquí:
-- todas son security_invoker, y ninguna SECURITY DEFINER lee el libro).
-- Fuera de sus tablas solo cambia un ajuste del rol de la app en esta
-- base (jit = off, 10). Sus propias huellas (7.7) se sellan al final.
-- =====================================================================
-- Lo ajeno que depende de las vistas de este archivo (vistas o funciones
-- de otro, sobre v_libro u otra de c4), o nulo si no hay: al volver a
-- pegar este archivo sus vistas se borran y se rehacen, y se lo llevarían
-- por delante. La usa la precondición de abajo (y c4-pruebas). Va aquí,
-- antes de todo: si la precondición para, el pegado entero se deshace,
-- también ella.
create or replace function public.fn_estados_vistas_ajenas()
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  with c4(v) as (
    select unnest(array['v_estados_mapeo_propuesto', 'v_estados_mapeo', 'v_cortes', 'v_ejercicios', 'v_libro', 'v_mayor',
                        'v_asiento_papel', 'v_qb_balanzas', 'v_balanza_base', 'v_balanza', 'v_balanza_obra',
                        'v_balance_general', 'v_resultados', 'v_flujo_lineas', 'v_flujo_caja', 'v_efectivo_movimientos',
                        'v_flujo_real_por_mes', 'v_saldos_dinero', 'v_cxc_antiguedad', 'v_cxp_antiguedad', 'v_gasto_lineas',
                        'v_gasto_por_categoria', 'v_gasto_por_proveedor', 'v_costo_por_obra', 'v_obras_dinero',
                        'v_comparacion', 'v_comparacion_obra', 'v_comparacion_resumen'])
  )
  select string_agg(distinct x.que, ', ')
    from (select format('la vista %s', dc.oid::regclass) as que
            from pg_depend d
            join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
            join pg_class dc on dc.oid = rw.ev_class
            join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
           where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname in (select c4.v from c4)
             and dc.oid <> cv.oid
             and not (dc.relnamespace = 'public'::regnamespace and dc.relname in (select c4.v from c4))
          union all
          select format('la función %s', f.oid::regprocedure)
            from pg_depend d
            join pg_proc f on d.classid = 'pg_proc'::regclass and f.oid = d.objid
            join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
           where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname in (select c4.v from c4)
          union all
          select format('la función %s', f.oid::regprocedure)
            from pg_depend d
            join pg_proc f on d.classid = 'pg_proc'::regclass and f.oid = d.objid
            join pg_type ty on d.refclassid = 'pg_type'::regclass and ty.oid = d.refobjid
            join pg_class cv on cv.oid = ty.typrelid
           where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname in (select c4.v from c4)) x
$$;
revoke execute on function public.fn_estados_vistas_ajenas() from public, anon, authenticated, service_role;

do $$
declare
  v_falta text := '';
  r       record;
begin
  -- c1 y c2: el plan y el libro.
  if to_regclass('public.cuentas') is null or to_regclass('public.cuentas_historial') is null then
    v_falta := v_falta || ' · falta el plan de cuentas: pega antes c1-plan-de-cuentas.sql';
  end if;
  if to_regclass('public.asientos') is null or to_regclass('public.asiento_lineas') is null
     or to_regclass('public.periodos') is null
     or to_regprocedure('public.fn_postear_interno(jsonb)') is null
     or to_regprocedure('public.fn_reversar_interno(uuid,text,text,jsonb)') is null
     or to_regprocedure('public.fn_estado(text)') is null
     or to_regprocedure('public.fn_fecha_miami(timestamptz)') is null
     or to_regprocedure('public.fn_desde_editor()') is null
     or to_regprocedure('public.fn_rol_llamante()') is null then
    v_falta := v_falta || ' · falta el libro: pega antes c2-libro.sql';
  elsif not exists (select 1 from information_schema.columns
                     where table_schema = 'public' and table_name = 'asiento_lineas' and column_name = 'partida_id') then
    v_falta := v_falta || ' · el libro es de antes de f03 (sin tercero ni partida en las líneas): vuelve a pegar c2-libro.sql';
  end if;
  -- c3: las partidas de CxC y CxP, los cobros y los proveedores.
  if to_regclass('public.puente_cuentas') is null or to_regclass('public.proveedores') is null
     or to_regclass('public.proveedores_alias') is null or to_regclass('public.cobros') is null
     or to_regclass('public.aplicaciones_cobro') is null or to_regclass('public.cobros_devoluciones') is null
     or to_regclass('public.notas_credito') is null
     or to_regprocedure('public.fn_puente_factura(bigint,text,boolean,text)') is null
     or to_regprocedure('public.fn_puente_recibo(bigint,text,boolean,text)') is null
     or to_regprocedure('public.fn_puente_externo(bigint,text,boolean,text)') is null
     or not exists (select 1 from information_schema.columns
                     where table_schema = 'public' and table_name = 'facturas' and column_name = 'estado') then
    v_falta := v_falta || ' · faltan los puentes: pega antes c3-puentes.sql';
  else
    for r in select v.rol from (values ('cxc'), ('retencion_cxc'), ('cxp'), ('reembolso_empleado')) as v(rol)
              where not exists (select 1 from public.puente_cuentas pc where pc.rol = v.rol) loop
      v_falta := v_falta || format(' · falta la cuenta del puente «%s» en puente_cuentas (vuelve a pegar c3-puentes.sql)', r.rol);
    end loop;
  end if;
  if to_regprocedure('public.es_dueno()') is null or to_regprocedure('auth.uid()') is null then
    v_falta := v_falta || ' · faltan es_dueno() o auth.uid() (¿esto es Supabase?)';
  end if;

  -- Las tablas de este archivo, si ya existen, son las de este archivo.
  for r in select * from (values ('estados_mapeo', 'flujo_indirecto'), ('estados_lineas', 'etiqueta_en'),
                                 ('estados_config', 'valor'), ('estados_historial', 'despues'),
                                 ('apertura_mapeo_qb', 'nombre_qb'), ('apertura_balanza_qb', 'trabajo_externo_id'),
                                 ('comparacion_qb', 'cliente_trabajo'), ('diferencias', 'retirada_motivo')) as v(tabla, columna)
            where to_regclass('public.' || v.tabla) is not null
              and not exists (select 1 from information_schema.columns c
                               where c.table_schema = 'public' and c.table_name = v.tabla and c.column_name = v.columna) loop
    v_falta := v_falta || format(' · ya existe una tabla public.%s que NO es la de este archivo', r.tabla);
  end loop;

  if v_falta <> '' then
    raise exception using
      errcode = 'MX000',
      message = 'c4-estados NO se aplicó, no se tocó nada. Falta lo que este archivo da por hecho:' || v_falta,
      hint    = 'El orden de pegado es c1, c2, c3 y después este archivo (pruebas/conta/README.md, §0).';
  end if;

  -- Nada AJENO colgado de las vistas de este archivo: al volver a pegarlo
  -- se borran y se rehacen («drop view … cascade»), y se llevarían por
  -- delante, callado, una vista o una función de otro que dependa de ellas
  -- (una que Edgar arme para su CPA sobre v_libro; las de f06 o f08). Si
  -- las hay, no se toca nada y se dicen.
  v_falta := public.fn_estados_vistas_ajenas();
  if v_falta is not null then
    raise exception using
      errcode = 'MX000',
      message = format('c4-estados NO se aplicó, no se tocó nada: %s depende(n) de las vistas de este archivo, que al pegarlo se '
                       'borran y se rehacen (se las llevaría por delante sin avisar).', v_falta),
      hint    = 'Guarda su definición (select pg_get_viewdef(''<vista>''::regclass, true);), bórralas, pega este archivo y '
                'vuelve a crearlas (pruebas/conta/README.md, §0).';
  end if;
end $$;


-- =====================================================================
-- 1 · LAS TABLAS
-- Todas nacen cerradas (el bloque fijo de docs/conta/c*.sql, en 1.7):
-- solo el dueño lee; nadie de la API escribe (todo entra por las
-- funciones de la sección 6, desde el SQL Editor). Cada cambio a una regla,
-- un mapeo o una anotación queda en estados_historial (quién, cuándo, antes
-- y después), y lo que se importó de QuickBooks no se edita: se carga otra
-- versión.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1.1 · estados_historial — el rastro de todo lo de este archivo que se
-- puede cambiar: las líneas de los estados y sus etiquetas, el mapeo de
-- cada cuenta, la configuración, el mapeo de QuickBooks y las diferencias
-- anotadas. Lo llena un trigger (1.6); no se edita ni se borra. El id es
-- un uuid y no una secuencia: una secuencia no se deshace con el rollback
-- y c4-pruebas.sql dejaría rastro.
-- ---------------------------------------------------------------------
create table if not exists public.estados_historial (
  id          uuid        primary key default gen_random_uuid(),
  tabla       text        not null,
  clave       text        not null,
  operacion   text        not null,
  cambiado_el timestamptz not null default clock_timestamp(),
  usuario_id  uuid,
  rol         text        not null,
  antes       jsonb,
  despues     jsonb,
  constraint estados_historial_operacion check (operacion in ('INSERT', 'UPDATE', 'DELETE')),
  constraint estados_historial_forma
    check (    (operacion = 'INSERT' and antes is null and despues is not null)
           or (operacion = 'UPDATE' and antes is not null and despues is not null)
           or (operacion = 'DELETE' and antes is not null and despues is null))
);
create index if not exists estados_historial_idx on public.estados_historial (tabla, clave, cambiado_el);

-- ---------------------------------------------------------------------
-- 1.2 · estados_lineas — las líneas que se pintan, con su orden y su
-- etiqueta en español y en inglés (el CPA lee la de inglés):
--   estado   balance, resultados, flujo_directo o flujo_indirecto;
--   seccion  el bloque (activo_circulante, pasivo_circulante, capital,
--            ingresos, costo, gastos, operacion, inversion…); la fila con
--            linea = seccion es la de la SECCIÓN (su encabezado; su
--            subtotal se pinta «Total …»). seccion 'totales' guarda las
--            filas calculadas (total activo, utilidad bruta, efectivo al
--            inicio…);
--   linea    el renglón del estado. En el balance agrupa cuentas (efectivo
--            = 1010 + 1030 + 1050). En resultados, por omisión, cada
--            cuenta va sola bajo su sección (linea = seccion): Edgar puede
--            agruparlas con una línea nueva (fn_estados_linea) si el CPA
--            quiere «Mano de obra y burden» en un renglón.
-- Se añaden solas las que faltan; las etiquetas que Edgar cambie no las
-- pisa un segundo pegado.
-- ---------------------------------------------------------------------
create table if not exists public.estados_lineas (
  estado      text not null,
  seccion     text not null,
  linea       text not null,
  orden       int  not null,
  etiqueta_es text not null,
  etiqueta_en text not null,
  notas       text,
  constraint estados_lineas_pk        primary key (estado, seccion, linea),
  constraint estados_lineas_estado    check (estado in ('balance', 'resultados', 'flujo_directo', 'flujo_indirecto')),
  constraint estados_lineas_claves    check (seccion ~ '^[a-z][a-z0-9_]*$' and linea ~ '^[a-z][a-z0-9_]*$'),
  constraint estados_lineas_etiquetas check (btrim(etiqueta_es) <> '' and btrim(etiqueta_en) <> '')
);
-- En el flujo, una cuenta nombra su renglón solo por su nombre: único en
-- cada estado del flujo.
create unique index if not exists estados_lineas_flujo_unica on public.estados_lineas (estado, linea)
  where estado in ('flujo_directo', 'flujo_indirecto') and seccion <> 'totales';

-- ---------------------------------------------------------------------
-- 1.3 · estados_mapeo — dónde sale cada cuenta del plan (f04):
--   estado, seccion, linea  en qué estado, bloque y renglón (una línea de
--                  estados_lineas: la llave foránea no deja apuntar a un
--                  renglón que no existe);
--   orden          su orden dentro del renglón (por omisión, el del código:
--                  2100-2009 después de 2100);
--   etiqueta_es/en su nombre en el estado; nulo = el de la cuenta
--                  (cuentas.nombre / nombre_en), que es lo normal: así un
--                  cambio de nombre en c1 llega solo;
--   signo          cómo se pinta: cifra = signo × (debe − haber). +1 en el
--                  activo, el costo y los gastos; −1 en el pasivo, el
--                  capital y los ingresos. Lo fija la sección (la guarda no
--                  deja otro): así una contra-cuenta sale restando sola;
--   contra         la cuenta va contra su sección (su saldo normal es el
--                  contrario): 1190 y 1590 (activo acreedor), 3200 (capital
--                  deudor), 5011 (costo acreedor). Informativo: la cifra ya
--                  sale en negativo por el signo;
--   efectivo       es dinero: el flujo de caja se mide sobre estas cuentas
--                  (el bloque 10xx: 1010, 1030, 1050);
--   flujo_directo  a qué renglón del flujo DIRECTO va el dinero cuando esta
--                  cuenta es la contrapartida (1110 → cobros de clientes,
--                  2100-x → pagos de tarjetas, 2210 → nómina…);
--   flujo_indirecto a qué renglón del flujo INDIRECTO va el cambio de su
--                  saldo (1110 → cuentas por cobrar, 1590 → depreciación…).
--                  Las de resultados, a «resultado».
-- Se DERIVA de cuentas.tipo y del código (v_estados_mapeo_propuesto, 2.1):
-- el pegado añade la fila de cada cuenta que no la tenga, y
-- fn_estados_mapeo_derivar() lo mismo cuando c1 añada una (una tarjeta
-- nueva). Edgar la ajusta con fn_estados_mapeo (con rastro). Una cuenta
-- del plan SIN fila es un error que se dice: fn_estados_control lo pone en
-- rojo (y mientras tanto los estados la pintan con lo propuesto, para que
-- el balance no pierda dinero callado).
-- Sin la cuenta, la fila sobra: si c1 borra una cuenta sin movimientos (la
-- 7200), su fila se va con ella (on delete cascade) y el historial lo dice.
-- ---------------------------------------------------------------------
create table if not exists public.estados_mapeo (
  cuenta          text     primary key references public.cuentas (codigo) on delete cascade,
  estado          text     not null,
  seccion         text     not null,
  linea           text     not null,
  orden           int      not null,
  etiqueta_es     text,
  etiqueta_en     text,
  signo           smallint not null,
  contra          boolean  not null,
  efectivo        boolean  not null default false,
  flujo_directo   text     not null,
  flujo_indirecto text     not null,
  notas           text,
  constraint estados_mapeo_estado    check (estado in ('balance', 'resultados')),
  constraint estados_mapeo_signo     check (signo in (-1, 1)),
  constraint estados_mapeo_etiquetas check (coalesce(btrim(etiqueta_es), '-') <> '' and coalesce(btrim(etiqueta_en), '-') <> ''),
  constraint estados_mapeo_linea_fk  foreign key (estado, seccion, linea) references public.estados_lineas (estado, seccion, linea)
);

-- ---------------------------------------------------------------------
-- 1.4 · estados_config — lo que el CPA decide de la presentación. Hoy una
-- sola llave:
--   plegar_3200  'no' (por omisión): las distribuciones (3200) se enseñan
--                aparte, todas las de la vida de la empresa. 'si': al
--                cerrarse un año, sus distribuciones se pliegan a
--                utilidades retenidas (como el asiento de cierre que hacen
--                otros sistemas: Dr 3900 / Cr 3200), y 3200 enseña solo las
--                de los años abiertos. No se postea nada: es presentación.
--                Se cambia con fn_estados_config('plegar_3200', 'si').
-- ---------------------------------------------------------------------
create table if not exists public.estados_config (
  clave text primary key,
  valor text not null,
  notas text,
  constraint estados_config_clave check (clave in ('plegar_3200')),
  constraint estados_config_valor check (clave <> 'plegar_3200' or valor in ('si', 'no'))
);

-- ---------------------------------------------------------------------
-- 1.5 · QuickBooks: el mapeo, la balanza de apertura, las balanzas para
-- comparar y las diferencias.
-- ---------------------------------------------------------------------

-- La llave con que se casa un nombre de QuickBooks (una cuenta o un
-- Customer:Job): minúsculas, sin espacios de sobra y sin espacios alrededor
-- de los dos puntos («Chase  Chk 4392 » = «chase chk 4392», «Pérez, Juan :
-- Casa Pérez» = «pérez, juan:casa pérez»). Columna generada: la calcula la
-- base al guardar, siempre igual, y las vistas casan por ella sin llamar a
-- ninguna función (el equipo no ejecuta nada de aquí).

-- apertura_mapeo_qb — cada nombre de QuickBooks y a qué va en el plan. Lo
-- usan la apertura (fn_apertura) y la comparación (v_comparacion), todos
-- los meses del paralelo y el cierre de enero:
--   tipo 'cuenta'   una cuenta de QuickBooks («Chase Chk 4392», «Opening
--                   Balance Equity», «Job Materials») → una cuenta del plan.
--                   Una cuenta de RESULTADOS de QuickBooks se mapea a su
--                   equivalente del plan («Job Materials» → 5100): en la
--                   apertura su saldo cae en utilidades retenidas (3900), y en
--                   la comparación de cada mes se compara con su cuenta;
--   tipo 'trabajo'  un Customer:Job de QuickBooks → una obra de la app. Así
--                   la retención (1120) y la cuenta por cobrar sin factura
--                   van a su obra, y la comparación se corta por obra.
-- Se escribe con fn_apertura_mapeo_qb y fn_apertura_mapeo_trabajo (con
-- rastro).
create table if not exists public.apertura_mapeo_qb (
  tipo        text not null,
  nombre_qb   text not null,
  clave       text generated always as (nullif(lower(btrim(regexp_replace(regexp_replace(coalesce(nombre_qb, ''),
                                          '[[:space:]]+', ' ', 'g'), '[[:space:]]*:[[:space:]]*', ':', 'g'))), '')) stored,
  cuenta      text references public.cuentas (codigo),
  proyecto_id text,
  notas       text,
  constraint apertura_mapeo_qb_pk      primary key (tipo, clave),
  constraint apertura_mapeo_qb_tipo    check (tipo in ('cuenta', 'trabajo')),
  constraint apertura_mapeo_qb_destino check ((tipo = 'cuenta') = (cuenta is not null) and (tipo = 'trabajo') = (proyecto_id is not null))
);

-- apertura_balanza_qb — la balanza de QuickBooks al 30-sep, tal como llega
-- (el CSV; el PDF es el documento), fila por cuenta de QuickBooks con su
-- debe y su haber. Donde hay CÉDULA, la cuenta va en varias filas, una por
-- partida, y su total es la suma:
--   · Accounts Receivable: una fila por factura abierta (factura_id, la de
--     la app, que trae su obra) con su saldo, y retencion = cuánto de ese
--     saldo es retención (va a 1120, por obra). Un saldo NEGATIVO (un
--     crédito a favor del cliente, un pago sin aplicar) no es de una
--     factura: va sin factura, con su obra (proyecto_id o cliente_trabajo);
--   · Accounts Payable: una fila por proveedor (proveedor_id, o su nombre de
--     QuickBooks en proveedor_qb, que se casa con proveedores_alias), y si
--     el ticket está en la app, recibo_id o trabajo_externo_id;
--   · una cuenta por obra (retención, WIP): cliente_trabajo o proyecto_id;
--   · tarjetas y préstamos: una fila por cuenta, con referencia (el
--     statement, el número del préstamo).
-- documento: la ruta del papel (el PDF o el CSV en Storage, docs/…); todas
-- las filas de una balanza lo comparten, y es el documento del asiento de
-- apertura. Una balanza que ya entró al libro no se edita ni se borra (la
-- guarda de 1.6): si QuickBooks la corrige, se carga con otro documento y
-- fn_apertura dice qué cambió. Montos numeric(14,2) como vienen (un saldo
-- negativo puede venir con signo menos en su columna: saldo = debe − haber).
-- Sin llaves foráneas a los papeles de la app (una factura, un recibo): esto
-- es la importación, y un papel que falte lo dice fn_apertura en claro.
create table if not exists public.apertura_balanza_qb (
  documento          text          not null,
  linea              int           not null,
  cuenta_qb          text          not null,
  clave              text generated always as (nullif(lower(btrim(regexp_replace(regexp_replace(coalesce(cuenta_qb, ''),
                                                 '[[:space:]]+', ' ', 'g'), '[[:space:]]*:[[:space:]]*', ':', 'g'))), '')) stored,
  debe               numeric(14,2),
  haber              numeric(14,2),
  factura_id         bigint,
  retencion          numeric(14,2),
  cliente_trabajo    text,
  cliente_clave      text generated always as (nullif(lower(btrim(regexp_replace(regexp_replace(coalesce(cliente_trabajo, ''),
                                                 '[[:space:]]+', ' ', 'g'), '[[:space:]]*:[[:space:]]*', ':', 'g'))), '')) stored,
  proyecto_id        text,
  proveedor_qb       text,
  proveedor_id       uuid,
  recibo_id          bigint,
  trabajo_externo_id bigint,
  referencia         text,
  notas              text,
  cargado_por        uuid,
  cargado_rol        text          not null,
  cargado_el         timestamptz   not null default clock_timestamp(),
  constraint apertura_balanza_qb_pk        primary key (documento, linea),
  constraint apertura_balanza_qb_documento check (btrim(documento) <> ''),
  constraint apertura_balanza_qb_cuenta    check (btrim(cuenta_qb) <> ''),
  constraint apertura_balanza_qb_retencion check (retencion is null or (retencion > 0 and factura_id is not null)),
  constraint apertura_balanza_qb_partida   check (num_nonnulls(recibo_id, trabajo_externo_id) <= 1)
);
-- Lo que trae la cédula de cada partida, además (las cargadas con una
-- versión anterior de este archivo no lo tienen: nulo):
--   fecha_documento  la fecha de la factura del proveedor (o del cliente) en
--                    QuickBooks (el A/P Aging Detail al 30-sep): con ella se
--                    envejece lo que trajo la apertura; sin ella, la
--                    antigüedad de pagar dice tramo 'apertura' y no inventa
--                    una fecha;
--   vence            su vencimiento, si QuickBooks lo trae (si no, sale de
--                    los términos del proveedor);
--   factura_num      el número de la factura como lo trae el A/R Aging de
--                    QuickBooks («1095»): fn_apertura_balanza_cargar busca
--                    con él la factura de la app y pone su factura_id.
alter table public.apertura_balanza_qb add column if not exists fecha_documento date;
alter table public.apertura_balanza_qb add column if not exists vence date;
alter table public.apertura_balanza_qb add column if not exists factura_num text;
-- control: la fila no es una cuenta sino un CONTROL que QuickBooks da
-- aparte, sacado de su Balance Sheet al 30-sep: 'utilidad' = «Net Income»
-- (la utilidad de enero a septiembre; la misma del Profit and Loss) y
-- 'activo' = «TOTAL ASSETS». No se suman a la balanza ni se postean:
-- fn_apertura_plan compara con ellas lo que da el mapeo, y para si no
-- coinciden. Sin ellas, la apertura se comparaba contra la MISMA balanza
-- pasada por el MISMO mapeo (cuadraba siempre): una cuenta de resultados
-- mapeada al balance («Job Materials» a 1300, bodega) metía 210,000 de
-- inventario que no existe y todo salía en verde.
alter table public.apertura_balanza_qb add column if not exists control text;
do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.apertura_balanza_qb'::regclass and conname = 'apertura_balanza_qb_control') then
    alter table public.apertura_balanza_qb
      add constraint apertura_balanza_qb_control check (control is null or control in ('utilidad', 'activo'));
  end if;
end $$;

-- comparacion_qb — las balanzas de QuickBooks de cada período, para
-- compararlas con el libro (v_comparacion): la del 31-oct, la del 30-nov
-- (f12b), la del 31-dic preliminar (el cierre de enero), la de cada mes del
-- paralelo. Una balanza al cierre del período (cuentas de balance a esa
-- fecha, cuentas de resultados en lo que va del año, como la da
-- QuickBooks). Una fila por cuenta de QuickBooks (y, si se trae por
-- Customer:Job, una por cuenta y trabajo). saldo = debe − haber.
-- documento: su papel (el CSV o el PDF); un período puede tener varias
-- versiones (la preliminar y la final): vale la cargada más tarde, y las
-- otras quedan como rastro. No se edita ni se borra: se carga otra.
-- Quién y cuándo (cargado_por, cargado_rol, cargado_el) los pone la base
-- al entrar cada fila (1.6, fn_estados_quien), no quien la escribe: así
-- «la cargada más tarde» no se puede fingir con una fecha escrita a mano.
-- La de la apertura no hace falta cargarla aquí: si no está, v_comparacion
-- usa la balanza de apertura que entró al libro.
create table if not exists public.comparacion_qb (
  periodo         text          not null references public.periodos (periodo),
  documento       text          not null,
  linea           int           not null,
  cuenta_qb       text          not null,
  clave           text generated always as (nullif(lower(btrim(regexp_replace(regexp_replace(coalesce(cuenta_qb, ''),
                                              '[[:space:]]+', ' ', 'g'), '[[:space:]]*:[[:space:]]*', ':', 'g'))), '')) stored,
  cliente_trabajo text,
  cliente_clave   text generated always as (nullif(lower(btrim(regexp_replace(regexp_replace(coalesce(cliente_trabajo, ''),
                                              '[[:space:]]+', ' ', 'g'), '[[:space:]]*:[[:space:]]*', ':', 'g'))), '')) stored,
  proyecto_id     text,
  saldo           numeric(14,2) not null,
  cargado_por     uuid,
  cargado_rol     text          not null,
  cargado_el      timestamptz   not null default clock_timestamp(),
  constraint comparacion_qb_pk        primary key (periodo, documento, linea),
  constraint comparacion_qb_documento check (btrim(documento) <> ''),
  constraint comparacion_qb_cuenta    check (btrim(cuenta_qb) <> '')
);
-- con_posteriores: esta balanza ya trae los ajustes del CPA posteriores al
-- período (la FINAL de diciembre, la que QuickBooks da con lo que el CPA
-- entregó en abril): v_comparacion le suma al libro los ajuste_cpa
-- fechados después que corrigen hasta ese período. La preliminar no. Lo
-- marca fn_comparacion_qb_cargar(…, true); las cargadas antes de esta
-- versión, false.
alter table public.comparacion_qb add column if not exists con_posteriores boolean not null default false;
-- al: la FECHA de la balanza, si no es la del cierre del período (f13-14
-- compara la de cada quincena: la del 15-dic): v_comparacion corta el
-- libro a esa fecha. Nula = el último día del período (lo de siempre).
alter table public.comparacion_qb add column if not exists al date;

-- diferencias — lo que el libro y QuickBooks no dicen igual, EXPLICADO:
-- período, cuenta (y obra si la diferencia es de una obra), monto (libro −
-- QuickBooks), clase y explicación, quién y cuándo:
--   puente    un papel que el puente todavía no pasó (la bandeja) o que
--             QuickBooks tiene en otro mes;
--   mapeo     una cuenta de QuickBooks que no casa uno a uno con el plan;
--   criterio  lo que el libro hace distinto a propósito: la retención
--             partida a 1120, el devengo de nómina, el WIP, la depreciación
--             (f08 y f13-14 las usan así).
-- asiento_id: el asiento que la explica o la corrige, si lo hay. No se
-- borra: una explicación que ya no vale se RETIRA con su motivo
-- (fn_diferencia_retirar) y queda. origen: quién la anotó sola
-- ('fn_apertura': el reparto de la retención de la apertura); nulo = Edgar.
create table if not exists public.diferencias (
  id              uuid          primary key default gen_random_uuid(),
  periodo         text          not null references public.periodos (periodo),
  cuenta          text          not null references public.cuentas (codigo),
  proyecto_id     text,
  monto           numeric(14,2) not null,
  clase           text          not null,
  explicacion     text          not null,
  asiento_id      uuid          references public.asientos (id),
  origen          text,
  anotado_por     uuid,
  anotado_rol     text          not null,
  anotado_el      timestamptz   not null default clock_timestamp(),
  retirada_el     timestamptz,
  retirada_por    uuid,
  retirada_motivo text,
  constraint diferencias_clase       check (clase in ('puente', 'mapeo', 'criterio')),
  constraint diferencias_monto       check (monto <> 0),
  constraint diferencias_explicacion check (btrim(explicacion) <> ''),
  constraint diferencias_retiro      check ((retirada_el is null) = (retirada_motivo is null)
                                            and (retirada_motivo is null or btrim(retirada_motivo) <> ''))
);
create index if not exists diferencias_periodo_idx on public.diferencias (periodo, cuenta) where retirada_el is null;


-- ---------------------------------------------------------------------
-- 1.6 · Las guardas y el historial. TRIGGERS y no policies: una policy no
-- frena al SQL Editor; un trigger sí.
-- ---------------------------------------------------------------------

-- Solo el dueño (o el SQL Editor): lo miran las funciones de este archivo.
create or replace function public.fn_estados_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'Esto lo hace solo Edgar (el dueño), desde el SQL Editor.';
  end if;
end $$;
revoke execute on function public.fn_estados_exigir_dueno() from public, anon, authenticated, service_role;

-- El historial: cada alta, cambio o baja, DESPUÉS de escrita (si no
-- entra, no queda). La llave es la lista de columnas que se le pasa al
-- trigger. Un update que no cambia nada no se apunta.
create or replace function public.fn_estados_historial()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_fila jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  if tg_op = 'UPDATE' and to_jsonb(new) = to_jsonb(old) then
    return null;
  end if;
  insert into estados_historial (tabla, clave, operacion, usuario_id, rol, antes, despues)
  values (tg_table_name,
          (select string_agg(coalesce(v_fila->>f, '-'), '|' order by n) from unnest(tg_argv) with ordinality as x(f, n)),
          tg_op, auth.uid(), fn_rol_llamante(),
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  return null;
end $$;
revoke execute on function public.fn_estados_historial() from public, anon, authenticated, service_role;

-- Lo que no se edita ni se borra: el historial, las balanzas de QuickBooks
-- cargadas para comparar, y (salvo retirarlas) las diferencias. Y lo que
-- no se TRUNCA: las reglas y los mapeos (estados_mapeo, estados_lineas,
-- estados_config, apertura_mapeo_qb): cada cambio suyo deja su fila en
-- estados_historial, y un TRUNCATE (que no dispara los triggers de fila)
-- los borraría todos sin una.
-- Y el historial solo lo escribe su trigger: una fila de estados_historial
-- que entra a mano (el «rastro» de un cambio que se hizo con el trigger
-- apagado, a nombre de quien convenga y con la fecha que convenga) no
-- entra. La escribe fn_estados_historial, que corre dentro del trigger de
-- cada tabla: ahí Postgres va por el segundo nivel de triggers
-- (pg_trigger_depth() > 1); una escrita a mano va por el primero.
create or replace function public.fn_estados_inmutable()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    if tg_table_name = 'estados_historial' and pg_trigger_depth() > 1 then
      return new;
    end if;
    raise exception using errcode = 'MX003',
      message = format('%s solo lo escribe su trigger (fn_estados_historial): cada cambio a una regla, un mapeo, una '
                       'anotación o una balanza de QuickBooks deja aquí su fila solo, con quién y cuándo. Una fila escrita '
                       'a mano no entra.', tg_table_name);
  end if;
  if tg_op = 'TRUNCATE' and tg_table_name in ('estados_mapeo', 'estados_lineas', 'estados_config', 'apertura_mapeo_qb') then
    raise exception using errcode = 'MX003',
      message = format('%s no se trunca: es una tabla de reglas, y cada cambio suyo deja rastro fila por fila '
                       '(estados_historial); un TRUNCATE las borraría todas sin una. Una regla se cambia con su función '
                       '(fn_estados_mapeo, fn_estados_linea, fn_estados_config, fn_apertura_mapeo_qb).', tg_table_name);
  end if;
  if tg_table_name = 'diferencias' and tg_op = 'UPDATE' then
    if (to_jsonb(new) - array['retirada_el', 'retirada_por', 'retirada_motivo'])
         = (to_jsonb(old) - array['retirada_el', 'retirada_por', 'retirada_motivo'])
       and to_jsonb(old)->>'retirada_el' is null and to_jsonb(new)->>'retirada_el' is not null then
      return new;  -- retirarla (fn_diferencia_retirar): lo único que se le hace
    end if;
  end if;
  raise exception using errcode = 'MX003',
    message = format('%s no se edita ni se borra (%s): %s', tg_table_name, tg_op,
                     case tg_table_name
                       when 'estados_historial' then 'es el rastro de cada cambio a los estados.'
                       when 'comparacion_qb' then 'una balanza de QuickBooks cargada es un papel. Si estaba mal, se carga la '
                                                  'buena con otro documento (fn_comparacion_qb_cargar): vale la más reciente.'
                       when 'diferencias' then 'una diferencia anotada se retira con su motivo (fn_diferencia_retirar) y se '
                                               'anota la buena; queda el rastro de las dos.'
                       else 'es rastro.' end);
end $$;
revoke execute on function public.fn_estados_inmutable() from public, anon, authenticated, service_role;

-- Quién y cuándo los pone la BASE, como c2 en cada asiento: al entrar una
-- fila de una balanza de QuickBooks (cargado_por, cargado_rol,
-- cargado_el), al anotar una diferencia (anotado_*) y al retirarla
-- (retirada_el, retirada_por). Lo que traiga quien escribe no cuenta:
-- antes, un insert desde el SQL Editor firmado por alguien del equipo y
-- fechado en 2099 dejaba vigente PARA SIEMPRE una balanza que cuadraba con
-- el libro (la vigente es la cargada más tarde), la carga oficial de
-- después ya no contaba, y no quedaba rastro. Ahora esa fila dice el rol
-- que de verdad la escribió y la hora de verdad. (Corre con quien escribe:
-- la API no escribe estas tablas; si alguien le diera permiso por
-- columna, auth.uid() y fn_rol_llamante() lo dicen, o no lo dejan.)
create or replace function public.fn_estados_quien()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_table_name in ('comparacion_qb', 'apertura_balanza_qb') then
    new.cargado_por := auth.uid();
    new.cargado_rol := fn_rol_llamante();
    new.cargado_el  := clock_timestamp();
  elsif tg_table_name = 'diferencias' then
    if tg_op = 'INSERT' then
      if new.retirada_el is not null or new.retirada_por is not null or new.retirada_motivo is not null then
        raise exception using errcode = 'MX003',
          message = 'Una diferencia se anota viva y se retira después, con su motivo (fn_diferencia_retirar).';
      end if;
      new.anotado_por := auth.uid();
      new.anotado_rol := fn_rol_llamante();
      new.anotado_el  := clock_timestamp();
    elsif old.retirada_el is null and new.retirada_el is not null then
      new.retirada_el  := clock_timestamp();
      new.retirada_por := auth.uid();
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.fn_estados_quien() from public, anon, authenticated, service_role;

-- La balanza de apertura: mientras no haya entrado al libro se corrige
-- libre (es la importación); en cuanto un asiento la usa (su documento es
-- el del asiento de apertura), sus filas ya no cambian ni se borran: son
-- el papel de ese asiento. Una balanza corregida se carga con otro
-- documento. Lee asientos: al ser un trigger corre con quien escribe, que
-- solo puede ser el dueño de la base (la API no escribe esta tabla).
create or replace function public.fn_apertura_balanza_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_doc text := case when tg_op = 'INSERT' then new.documento else old.documento end;
  v_num text;
begin
  if tg_op = 'TRUNCATE' then
    if exists (select 1 from asientos a where a.origen_tabla = 'apertura_balanza_qb') then
      raise exception using errcode = 'MX003',
        message = 'apertura_balanza_qb no se trunca: tiene balanzas que ya entraron al libro (son el papel de su asiento).';
    end if;
    return null;
  end if;
  select string_agg(a.numero, ', ' order by a.cadena_pos) into v_num
    from asientos a
   where a.origen_tabla = 'apertura_balanza_qb'
     and (a.documento_ruta = v_doc or (tg_op = 'UPDATE' and a.documento_ruta = new.documento));
  if v_num is not null then
    raise exception using errcode = 'MX003',
      message = format('La balanza %s ya entró al libro (asiento %s): sus filas son el papel de ese asiento y no cambian. Si '
                       'QuickBooks la corrigió, cárgala con otro documento (fn_apertura_balanza_cargar) y fn_apertura dice '
                       'qué cambió.', v_doc, v_num);
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
revoke execute on function public.fn_apertura_balanza_guarda() from public, anon, authenticated, service_role;

-- El mapeo de cada cuenta, coherente con lo que es la cuenta: el balance
-- lleva activo, pasivo y capital, y resultados lo demás; la sección, la de
-- su tipo; el signo, el de su sección; «contra», si su saldo normal es el
-- contrario al de su sección; el dinero (efectivo) es un activo circulante
-- y va con los renglones de flujo 'efectivo'; y los renglones del flujo
-- existen. Vale igual por la función y por el SQL Editor.
create or replace function public.fn_estados_mapeo_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_c       cuentas;
  v_secc    text[];
  v_signo   smallint;
  v_natural text;
  v_sec_d   text;
  v_sec_i   text;
begin
  select * into v_c from cuentas where codigo = new.cuenta;
  if not found then
    raise exception using errcode = 'MX004', message = format('La cuenta %s no existe en el plan.', new.cuenta);
  end if;
  v_secc := case v_c.tipo
              when 'activo'       then array['activo_circulante', 'activo_fijo', 'otros_activos']
              when 'pasivo'       then array['pasivo_circulante', 'pasivo_largo_plazo']
              when 'capital'      then array['capital']
              when 'ingreso'      then array['ingresos', 'otros_ingresos']
              when 'otro_ingreso' then array['otros_ingresos', 'ingresos']
              when 'costo'        then array['costo']
              when 'gasto'        then array['gastos', 'otros_gastos']
              when 'otro_gasto'   then array['otros_gastos', 'gastos']
            end;
  if new.estado is distinct from (case when v_c.tipo in ('activo', 'pasivo', 'capital') then 'balance' else 'resultados' end)
     or not (new.seccion = any (v_secc)) then
    raise exception using errcode = 'MX006',
      message = format('La cuenta %s (%s) es de %s: va en %s, en una de estas secciones: %s (llegó %s / %s).', v_c.codigo,
                       v_c.nombre, v_c.tipo, case when v_c.tipo in ('activo', 'pasivo', 'capital') then 'el balance'
                                                  else 'resultados' end,
                       array_to_string(v_secc, ', '), new.estado, new.seccion);
  end if;
  v_signo := case when new.seccion in ('activo_circulante', 'activo_fijo', 'otros_activos', 'costo', 'gastos', 'otros_gastos')
                  then 1 else -1 end;
  v_natural := case when v_signo = 1 then 'debe' else 'haber' end;
  if new.signo is distinct from v_signo then
    raise exception using errcode = 'MX006',
      message = format('En %s el signo es %s (cifra = signo × (debe − haber)): así una contra-cuenta sale restando sola. '
                       'Llegó %s para la cuenta %s.', new.seccion, v_signo, new.signo, v_c.codigo);
  end if;
  if new.contra is distinct from (v_c.saldo_normal <> v_natural) then
    raise exception using errcode = 'MX006',
      message = format('La cuenta %s tiene saldo normal %s y va en %s (que crece por el %s): contra = %s, no %s.', v_c.codigo,
                       v_c.saldo_normal, new.seccion, v_natural, v_c.saldo_normal <> v_natural, new.contra);
  end if;
  if new.efectivo and not (new.seccion = 'activo_circulante' and v_c.saldo_normal = 'debe') then
    raise exception using errcode = 'MX006',
      message = format('La cuenta %s no puede ser efectivo: el dinero es un activo circulante de saldo deudor.', v_c.codigo);
  end if;
  if new.efectivo <> (new.flujo_directo = 'efectivo') or new.efectivo <> (new.flujo_indirecto = 'efectivo') then
    raise exception using errcode = 'MX006',
      message = format('La cuenta %s: efectivo = %s va con flujo_directo y flujo_indirecto = ''efectivo'' (y solo ella).',
                       v_c.codigo, new.efectivo);
  end if;
  -- Los renglones del flujo de una cuenta: uno de estados_lineas que no
  -- sea un total, ni del bloque sin dinero (ese lo llena el flujo solo),
  -- ni el encabezado de una sección que tiene renglones (se pintaría
  -- aparte de ellos). Y la SECCIÓN de cada uno.
  if not new.efectivo then
    select l.seccion into v_sec_d
      from estados_lineas l
     where l.estado = 'flujo_directo' and l.linea = new.flujo_directo and l.seccion not in ('totales', 'sin_dinero')
       and (l.linea <> l.seccion
            or not exists (select 1 from estados_lineas o
                            where o.estado = l.estado and o.seccion = l.seccion and o.linea <> o.seccion));
    if v_sec_d is null then
      raise exception using errcode = 'MX006',
        message = format('La cuenta %s: «%s» no es un renglón del flujo directo (estados_lineas; ni un total, ni el bloque '
                         'sin dinero, ni el encabezado de una sección con renglones).', v_c.codigo, new.flujo_directo);
    end if;
    select l.seccion into v_sec_i
      from estados_lineas l
     where l.estado = 'flujo_indirecto' and l.linea = new.flujo_indirecto and l.seccion not in ('totales', 'sin_dinero')
       and (l.linea <> l.seccion
            or not exists (select 1 from estados_lineas o
                            where o.estado = l.estado and o.seccion = l.seccion and o.linea <> o.seccion));
    if v_sec_i is null then
      raise exception using errcode = 'MX006',
        message = format('La cuenta %s: «%s» no es un renglón del flujo indirecto (estados_lineas; ni un total, ni el bloque '
                         'sin dinero, ni el encabezado de una sección con renglones).', v_c.codigo, new.flujo_indirecto);
    end if;
    -- Una cuenta de balance va en la MISMA sección en los dos métodos: así
    -- inversión y financiamiento salen iguales en el directo y en el
    -- indirecto (ASC 230), y el flujo cuadra sección por sección.
    if new.estado = 'balance' and v_sec_d <> v_sec_i then
      raise exception using errcode = 'MX006',
        message = format('La cuenta %s va en la misma sección del flujo en los dos métodos: «%s» es de %s en el directo y «%s» '
                         'de %s en el indirecto.', v_c.codigo, new.flujo_directo, v_sec_d, new.flujo_indirecto, v_sec_i);
    end if;
    -- Una de resultados cuyo dinero no es de operación (la ganancia en la
    -- venta de un activo, 4920, es inversión): el indirecto la saca de la
    -- utilidad y la pone en el renglón del MISMO nombre y sección que el
    -- directo. Tiene que existir.
    if new.estado = 'resultados' and v_sec_d <> 'operacion'
       and not exists (select 1 from estados_lineas l
                        where l.estado = 'flujo_indirecto' and l.linea = new.flujo_directo and l.seccion = v_sec_d) then
      raise exception using errcode = 'MX006',
        message = format('La cuenta %s es de resultados y su dinero va a «%s» (%s) en el directo: el indirecto necesita un '
                         'renglón con ese nombre en esa sección (fn_estados_linea), para sacarlo de la utilidad y ponerlo ahí.',
                         v_c.codigo, new.flujo_directo, v_sec_d);
    end if;
  end if;
  if new.estado = 'resultados' and new.flujo_indirecto <> 'resultado' then
    raise exception using errcode = 'MX006',
      message = format('La cuenta %s es de resultados: en el flujo indirecto va dentro de la utilidad (flujo_indirecto = '
                       '''resultado'').', v_c.codigo);
  end if;
  if new.estado = 'balance' and new.flujo_indirecto in ('resultado', 'resultado_anteriores') then
    raise exception using errcode = 'MX006',
      message = format('La cuenta %s es de balance: en el flujo indirecto va por el cambio de su saldo, no dentro de la utilidad.',
                       v_c.codigo);
  end if;
  return new;
end $$;
revoke execute on function public.fn_estados_mapeo_guarda() from public, anon, authenticated, service_role;

-- «create or replace trigger» (PG14+): al volver a pegar no hay ni un
-- instante sin la guarda.
create or replace trigger trg_estados_mapeo_guarda
  before insert or update on public.estados_mapeo
  for each row execute function public.fn_estados_mapeo_guarda();

create or replace trigger trg_estados_mapeo_historial
  after insert or update or delete on public.estados_mapeo
  for each row execute function public.fn_estados_historial('cuenta');
create or replace trigger trg_estados_lineas_historial
  after insert or update or delete on public.estados_lineas
  for each row execute function public.fn_estados_historial('estado', 'seccion', 'linea');
create or replace trigger trg_estados_config_historial
  after insert or update or delete on public.estados_config
  for each row execute function public.fn_estados_historial('clave');
create or replace trigger trg_apertura_mapeo_qb_historial
  after insert or update or delete on public.apertura_mapeo_qb
  for each row execute function public.fn_estados_historial('tipo', 'clave');
create or replace trigger trg_diferencias_historial
  after insert or update or delete on public.diferencias
  for each row execute function public.fn_estados_historial('periodo', 'cuenta', 'id');
-- Quién y cuándo, de la base (ver fn_estados_quien).
create or replace trigger trg_comparacion_qb_quien
  before insert on public.comparacion_qb
  for each row execute function public.fn_estados_quien();
create or replace trigger trg_apertura_balanza_quien
  before insert on public.apertura_balanza_qb
  for each row execute function public.fn_estados_quien();
create or replace trigger trg_diferencias_quien
  before insert or update on public.diferencias
  for each row execute function public.fn_estados_quien();
-- Las filas de QuickBooks también dejan su rastro, fila por fila (antes
-- no: «cada fila ya dice quién y cuándo la cargó», y eso lo escribía
-- quien insertaba). Así protecciones de c4 (8) puede cruzar cada fila con
-- su historial, como c2 cruza cuentas con cuentas_historial: una fila que
-- entró con los triggers apagados no tiene el suyo, y se ve.
-- La primera vez que se pega esta versión, las que ya estaban se apuntan
-- con lo que dice cada una (quién, su rol y cuándo la cargó); después lo
-- apunta solo el trigger.
do $$
begin
  if to_regclass('public.estados_historial') is not null
     and not exists (select 1 from pg_trigger t
                      where t.tgrelid = 'public.estados_historial'::regclass and t.tgname = 'trg_estados_historial_solo_su_trigger') then
    insert into public.estados_historial (tabla, clave, operacion, cambiado_el, usuario_id, rol, antes, despues)
    select 'comparacion_qb', q.periodo || '|' || q.documento || '|' || q.linea, 'INSERT', q.cargado_el, q.cargado_por,
           q.cargado_rol, null, to_jsonb(q)
      from public.comparacion_qb q
     where not exists (select 1 from public.estados_historial h
                        where h.tabla = 'comparacion_qb' and h.clave = q.periodo || '|' || q.documento || '|' || q.linea);
    insert into public.estados_historial (tabla, clave, operacion, cambiado_el, usuario_id, rol, antes, despues)
    select 'apertura_balanza_qb', b.documento || '|' || b.linea, 'INSERT', b.cargado_el, b.cargado_por, b.cargado_rol, null,
           to_jsonb(b)
      from public.apertura_balanza_qb b
     where not exists (select 1 from public.estados_historial h
                        where h.tabla = 'apertura_balanza_qb' and h.clave = b.documento || '|' || b.linea);
  end if;
end $$;
create or replace trigger trg_comparacion_qb_historial
  after insert or update or delete on public.comparacion_qb
  for each row execute function public.fn_estados_historial('periodo', 'documento', 'linea');
create or replace trigger trg_apertura_balanza_historial
  after insert or update or delete on public.apertura_balanza_qb
  for each row execute function public.fn_estados_historial('documento', 'linea');
-- Y el historial solo lo escribe su trigger (ver fn_estados_inmutable).
create or replace trigger trg_estados_historial_solo_su_trigger
  before insert on public.estados_historial
  for each row execute function public.fn_estados_inmutable();

create or replace trigger trg_estados_historial_inmutable
  before update or delete on public.estados_historial
  for each row execute function public.fn_estados_inmutable();
create or replace trigger trg_estados_historial_sin_truncate
  before truncate on public.estados_historial
  for each statement execute function public.fn_estados_inmutable();
create or replace trigger trg_comparacion_qb_inmutable
  before update or delete on public.comparacion_qb
  for each row execute function public.fn_estados_inmutable();
create or replace trigger trg_comparacion_qb_sin_truncate
  before truncate on public.comparacion_qb
  for each statement execute function public.fn_estados_inmutable();
create or replace trigger trg_diferencias_inmutable
  before update or delete on public.diferencias
  for each row execute function public.fn_estados_inmutable();
create or replace trigger trg_diferencias_sin_truncate
  before truncate on public.diferencias
  for each statement execute function public.fn_estados_inmutable();
-- (También el INSERT: al papel de un asiento de apertura no se le añaden
-- filas.)
create or replace trigger trg_apertura_balanza_guarda
  before insert or update or delete on public.apertura_balanza_qb
  for each row execute function public.fn_apertura_balanza_guarda();
create or replace trigger trg_apertura_balanza_sin_truncate
  before truncate on public.apertura_balanza_qb
  for each statement execute function public.fn_apertura_balanza_guarda();
-- Las reglas y los mapeos no se truncan (su rastro es fila por fila).
create or replace trigger trg_estados_mapeo_sin_truncate
  before truncate on public.estados_mapeo
  for each statement execute function public.fn_estados_inmutable();
create or replace trigger trg_estados_lineas_sin_truncate
  before truncate on public.estados_lineas
  for each statement execute function public.fn_estados_inmutable();
create or replace trigger trg_estados_config_sin_truncate
  before truncate on public.estados_config
  for each statement execute function public.fn_estados_inmutable();
create or replace trigger trg_apertura_mapeo_qb_sin_truncate
  before truncate on public.apertura_mapeo_qb
  for each statement execute function public.fn_estados_inmutable();

-- Una balanza de comparación ya cargada no recibe filas nuevas: cada
-- carga es UN insert (fn_comparacion_qb_cargar), y si después de él el
-- documento tiene filas que no son de ese insert, ya estaba cargado (una
-- fila añadida a mano, con la fecha y el autor que se quiera, cambiaría
-- el papel sin rastro). Mira el insert entero (transition table), después
-- de él: así no depende de lo que la sesión todavía no ve.
create or replace function public.fn_comparacion_qb_sin_filas_nuevas()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_doc text;
begin
  select format('%s de %s', n.documento, n.periodo) into v_doc
    from nuevas n
   where exists (select 1 from comparacion_qb q
                  where q.periodo = n.periodo and q.documento = n.documento
                    and not exists (select 1 from nuevas x
                                     where x.periodo = q.periodo and x.documento = q.documento and x.linea = q.linea))
   limit 1;
  if v_doc is not null then
    raise exception using errcode = 'MX003',
      message = format('La balanza %s ya estaba cargada: no se le añaden filas (es un papel). Si QuickBooks la corrigió, '
                       'cárgala entera con otro documento (fn_comparacion_qb_cargar): vale la más reciente.', v_doc);
  end if;
  return null;
end $$;
revoke execute on function public.fn_comparacion_qb_sin_filas_nuevas() from public, anon, authenticated, service_role;
create or replace trigger trg_comparacion_qb_sin_filas_nuevas
  after insert on public.comparacion_qb
  referencing new table as nuevas
  for each statement execute function public.fn_comparacion_qb_sin_filas_nuevas();


-- ---------------------------------------------------------------------
-- 1.7 · Quién lee. El bloque fijo de todo docs/conta/c*.sql, tabla por
-- tabla: solo el dueño lee (una policy); nadie de la API escribe (todo
-- entra por las funciones); anon, nada. service_role conserva la lectura
-- (el contador de f07 lee para proponer). «revoke all» y luego «grant
-- select» (en Postgres 17 el «grant all» de Supabase incluye MAINTAIN).
-- Volver a pegar borra toda policy ajena de estas tablas, los permisos
-- por COLUMNA que alguien les dio (la pantalla «Column privileges» de
-- Supabase: con un insert por columnas, service_role plantaba una balanza
-- de QuickBooks, y has_table_privilege no lo ve), y todo trigger o regla
-- AJENOS sobre ellas (un trigger que se traga las altas del historial, una
-- regla «do instead nothing»): no son de este archivo, y con ellos las
-- funciones oficiales cambiaban reglas sin dejar rastro. Lo que quita, lo
-- dice (NOTICE).
-- ---------------------------------------------------------------------
do $$
declare
  t      text;
  p      record;
  v_cols text;
  -- Los triggers de este archivo sobre sus tablas (1.6): cualquier otro
  -- es ajeno.
  c_trg  text[] := array['trg_estados_mapeo_guarda', 'trg_estados_mapeo_historial', 'trg_estados_mapeo_sin_truncate',
                         'trg_estados_lineas_historial', 'trg_estados_lineas_sin_truncate',
                         'trg_estados_config_historial', 'trg_estados_config_sin_truncate',
                         'trg_apertura_mapeo_qb_historial', 'trg_apertura_mapeo_qb_sin_truncate',
                         'trg_diferencias_historial', 'trg_diferencias_quien', 'trg_diferencias_inmutable',
                         'trg_diferencias_sin_truncate',
                         'trg_estados_historial_solo_su_trigger', 'trg_estados_historial_inmutable',
                         'trg_estados_historial_sin_truncate',
                         'trg_comparacion_qb_quien', 'trg_comparacion_qb_historial', 'trg_comparacion_qb_inmutable',
                         'trg_comparacion_qb_sin_truncate', 'trg_comparacion_qb_sin_filas_nuevas',
                         'trg_apertura_balanza_quien', 'trg_apertura_balanza_historial', 'trg_apertura_balanza_guarda',
                         'trg_apertura_balanza_sin_truncate'];
begin
  foreach t in array array['estados_historial', 'estados_lineas', 'estados_mapeo', 'estados_config', 'apertura_mapeo_qb',
                           'apertura_balanza_qb', 'comparacion_qb', 'diferencias'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    select string_agg(quote_ident(a.attname), ', ' order by a.attnum) into v_cols
      from pg_attribute a
     where a.attrelid = ('public.' || t)::regclass and a.attnum > 0 and not a.attisdropped and a.attacl is not null
       and exists (select 1 from aclexplode(a.attacl) e left join pg_roles r on r.oid = e.grantee
                    where e.grantee = 0 or r.rolname in ('anon', 'authenticated', 'service_role'));
    if v_cols is not null then
      raise notice 'c4: se quitan los permisos por columna de % (%)', t, v_cols;
      execute format('revoke all (%s) on public.%I from public, anon, authenticated, service_role', v_cols, t);
    end if;
    for p in select tg.tgname from pg_trigger tg
              where tg.tgrelid = ('public.' || t)::regclass and not tg.tgisinternal and not (tg.tgname = any (c_trg)) loop
      raise notice 'c4: se quita el trigger ajeno % de %', p.tgname, t;
      execute format('drop trigger %I on public.%I', p.tgname, t);
    end loop;
    for p in select rw.rulename from pg_rewrite rw
              where rw.ev_class = ('public.' || t)::regclass and rw.rulename <> '_RETURN' loop
      raise notice 'c4: se quita la regla ajena % de %', p.rulename, t;
      execute format('drop rule %I on public.%I', p.rulename, t);
    end loop;
    execute format('grant select on public.%I to authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl
              where pl.schemaname = 'public' and pl.tablename = t and pl.policyname <> t || '_dueno' loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('drop policy if exists %I on public.%I', t || '_dueno', t);
    -- «(select es_dueno())»: una vez por consulta, no por fila (como el
    -- libro en c2 y los puentes en c3).
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
  end loop;
end $$;
-- =====================================================================
-- 2 · LOS RENGLONES, LA CONFIGURACIÓN Y EL MAPEO DE CADA CUENTA
-- =====================================================================

-- ---------------------------------------------------------------------
-- 2.1 · El mapeo PROPUESTO de cada cuenta, derivado de cuentas.tipo y del
-- código (las reglas de c1). Una sola regla, escrita una vez: la usan el
-- pegado (para las cuentas sin fila), fn_estados_mapeo_derivar() y, para
-- una cuenta que todavía no tenga fila, los propios estados.
--   · Balance: 10xx efectivo; 1110 y 1190 cuentas por cobrar (1190 resta);
--     1120 retención por cobrar; 1130 al accionista (otros activos); 12xx
--     WIP; 13xx bodega; 14xx prepagados; 15xx propiedad y equipo, y la de
--     saldo acreedor (1590) su depreciación acumulada; 16xx depósitos;
--     2010 cuentas por pagar; 2020 retención a subs; 2050 devengados;
--     2100-x tarjetas; 22xx nómina; 23xx impuestos; 2400 y 2410 WIP y
--     provisión; 2510 línea de crédito; 2520 préstamo corriente; el resto
--     de 25xx largo plazo; 2900 préstamo del accionista; 3000, 3100, 3200
--     y 3900 en su renglón.
--   · Resultados: cada cuenta sola bajo su sección (ingresos, costo,
--     gastos, otros ingresos, otros gastos). 9000 (impuestos de la
--     empresa) es gasto de operación, como dice c1.
--   · Flujo directo (la contrapartida del dinero): clientes (11xx y los
--     ingresos de obra), proveedores (2010, 2020, 2050, bodega, prepagados,
--     depósitos, el costo y el gasto que no son nómina), tarjetas (2100-x),
--     nómina (22xx, 5000-5019, 6000, 6005, 6006, 6010), impuestos (23xx,
--     9000), intereses (7100, 4910), activos fijos (15xx y 4920),
--     préstamos otorgados (1130: lo que la empresa le presta al accionista
--     es inversión), préstamos recibidos (25xx), accionista (2900, 3000,
--     3100, 3200) y los ajustes (3900).
--   · Flujo indirecto (el cambio de cada saldo): por la misma familia, y
--     cada cuenta de balance en la MISMA sección de los dos métodos (la
--     guarda de 1.6 no deja otra cosa): así inversión y financiamiento son
--     iguales en los dos por construcción.
-- ---------------------------------------------------------------------
drop view if exists public.v_estados_mapeo cascade;
drop view if exists public.v_estados_mapeo_propuesto cascade;
-- (Una sola lectura de cuentas, y la regla calculada sobre cada fila con
-- un LATERAL sin tablas: así el planificador la aplana dentro de quien la
-- use, y un join por cuenta va por el índice de cuentas.)
-- saldo_normal se lee de la fila entera (to_jsonb(c), en modo strict), no
-- nombrando la columna: una vista que nombra una columna le fija el tipo
-- (ALTER TABLE … TYPE sale con 0A000), y las pruebas 24 y 66 de c2 (el
-- ataque que reescribe cuentas y periodos por debajo de sus triggers, y
-- que c2 tiene que delatar) necesitan poder hacerlo. Si la columna
-- desapareciera o cambiara de nombre, la vista falla con «JSON object does
-- not contain key» en vez de dar nulos. Lo mismo en v_cortes,
-- v_ejercicios, v_flujo_real_por_mes (periodos.estado y cerrado_el) y
-- v_saldos_dinero (cuentas.activa).
create view public.v_estados_mapeo_propuesto with (security_invoker = true) as
select c.codigo as cuenta,
       c.nombre as cuenta_nombre,
       c.nombre_en as cuenta_nombre_en,
       c.tipo as cuenta_tipo,
       cn.saldo_normal,
       case when c.tipo in ('activo', 'pasivo', 'capital') then 'balance' else 'resultados' end as estado,
       d.r[1] as seccion,
       d.r[2] as linea,
       (left(c.codigo, 4)::int * 10 + case when position('-' in c.codigo) > 0 then 5 else 0 end) as orden,
       (case when d.r[1] in ('activo_circulante', 'activo_fijo', 'otros_activos', 'costo', 'gastos', 'otros_gastos')
             then 1 else -1 end)::smallint as signo,
       cn.saldo_normal <> (case when d.r[1] in ('activo_circulante', 'activo_fijo', 'otros_activos', 'costo', 'gastos',
                                               'otros_gastos')
                               then 'debe' else 'haber' end) as contra,
       d.r[3] = 'efectivo' as efectivo,
       d.r[3] as flujo_directo,
       d.r[4] as flujo_indirecto
  from public.cuentas c
  cross join lateral (select jsonb_path_query_first(to_jsonb(c), 'strict $.saldo_normal') #>> '{}' as saldo_normal) cn
  cross join lateral (
    select case
             when c.tipo = 'activo' then
               case when left(c.codigo, 2) = '10' then array['activo_circulante', 'efectivo', 'efectivo', 'efectivo']
                    when left(c.codigo, 4) in ('1110', '1190') then array['activo_circulante', 'cuentas_por_cobrar', 'cobros_clientes', 'op_cxc']
                    when left(c.codigo, 4) = '1120' then array['activo_circulante', 'retencion_por_cobrar', 'cobros_clientes', 'op_cxc']
                    -- (Un préstamo que la empresa HACE, al accionista o a otro, es
                    -- inversión: ASC 230-10-45-12a. Solo el que RECIBE, 2900, es
                    -- financiamiento.)
                    when left(c.codigo, 4) = '1130' then array['otros_activos', 'accionista_por_cobrar', 'prestamos_otorgados', 'prestamos_otorgados']
                    when left(c.codigo, 2) = '11' then array['activo_circulante', 'cuentas_por_cobrar', 'cobros_clientes', 'op_cxc']
                    when left(c.codigo, 2) = '12' then array['activo_circulante', 'wip_activo', 'otros_operacion', 'op_wip']
                    when left(c.codigo, 2) = '13' then array['activo_circulante', 'inventario', 'proveedores', 'op_inventario']
                    when left(c.codigo, 2) = '14' then array['activo_circulante', 'prepagados', 'proveedores', 'op_prepagados']
                    when left(c.codigo, 2) = '15' and cn.saldo_normal = 'haber'
                      then array['activo_fijo', 'depreciacion_acumulada', 'otros_operacion', 'no_monetario']
                    when left(c.codigo, 2) = '15' then array['activo_fijo', 'propiedad_equipo', 'activos_fijos', 'activos_fijos']
                    when left(c.codigo, 2) = '16' then array['otros_activos', 'depositos', 'proveedores', 'op_otros']
                    else array['otros_activos', 'otros_activos_varios', 'otros_operacion', 'op_otros'] end
             when c.tipo = 'pasivo' then
               case when left(c.codigo, 4) = '2010' then array['pasivo_circulante', 'cuentas_por_pagar', 'proveedores', 'op_cxp']
                    when left(c.codigo, 4) = '2020' then array['pasivo_circulante', 'retencion_por_pagar', 'proveedores', 'op_cxp']
                    when left(c.codigo, 4) = '2050' then array['pasivo_circulante', 'devengados', 'proveedores', 'op_cxp']
                    when left(c.codigo, 4) = '2100' then array['pasivo_circulante', 'tarjetas', 'tarjetas', 'op_tarjetas']
                    when left(c.codigo, 2) = '22' then array['pasivo_circulante', 'nomina_por_pagar', 'nomina', 'op_nomina']
                    when left(c.codigo, 2) = '23' then array['pasivo_circulante', 'impuestos_por_pagar', 'impuestos', 'op_impuestos']
                    when left(c.codigo, 4) = '2400' then array['pasivo_circulante', 'wip_pasivo', 'otros_operacion', 'op_wip']
                    when left(c.codigo, 4) = '2410' then array['pasivo_circulante', 'provision_perdidas', 'otros_operacion', 'op_wip']
                    when left(c.codigo, 4) = '2510' then array['pasivo_circulante', 'linea_credito', 'prestamos', 'fin_prestamos']
                    when left(c.codigo, 4) = '2520' then array['pasivo_circulante', 'prestamos_corto', 'prestamos', 'fin_prestamos']
                    when left(c.codigo, 2) = '25' then array['pasivo_largo_plazo', 'prestamos_largo', 'prestamos', 'fin_prestamos']
                    when left(c.codigo, 4) = '2900' then array['pasivo_largo_plazo', 'prestamo_accionista', 'dueno', 'fin_accionista']
                    else array['pasivo_circulante', 'otros_pasivos', 'otros_operacion', 'op_otros'] end
             when c.tipo = 'capital' then
               case when left(c.codigo, 4) = '3000' then array['capital', 'capital_social', 'dueno', 'fin_capital']
                    when left(c.codigo, 4) = '3100' then array['capital', 'aportaciones', 'dueno', 'fin_capital']
                    when left(c.codigo, 4) = '3200' then array['capital', 'distribuciones', 'dueno', 'fin_distribuciones']
                    when left(c.codigo, 4) = '3900' then array['capital', 'utilidades_retenidas', 'ajustes', 'ajustes']
                    else array['capital', 'otro_capital', 'dueno', 'fin_capital'] end
             when c.tipo = 'ingreso' then array['ingresos', 'ingresos', 'cobros_clientes', 'resultado']
             when c.tipo = 'otro_ingreso' then
               array['otros_ingresos', 'otros_ingresos',
                     case when left(c.codigo, 4) = '4910' then 'intereses' when left(c.codigo, 4) = '4920' then 'activos_fijos'
                          else 'otros_operacion' end,
                     'resultado']
             when c.tipo = 'costo' then
               array['costo', 'costo', case when left(c.codigo, 2) = '50' then 'nomina' else 'proveedores' end, 'resultado']
             when c.tipo = 'gasto' then
               array['gastos', 'gastos',
                     case when left(c.codigo, 4) in ('6000', '6005', '6006', '6010') then 'nomina'
                          when left(c.codigo, 4) = '9000' then 'impuestos'
                          else 'proveedores' end,
                     'resultado']
             else -- otro_gasto
               array['otros_gastos', 'otros_gastos', case when left(c.codigo, 4) = '7100' then 'intereses' else 'otros_operacion' end,
                     'resultado']
           end as r
  ) d;

-- ---------------------------------------------------------------------
-- 2.2 · v_estados_mapeo — lo que usan TODOS los estados: la fila de cada
-- cuenta (la guardada; si no la tiene, la propuesta, con sin_fila = true
-- para que fn_estados_control lo diga en rojo), con sus nombres, sus
-- renglones y el orden de su sección y de su renglón; y la SECCIÓN de sus
-- dos renglones del flujo (operacion, inversion, financiamiento o
-- ajustes): con ella el flujo sabe qué asiento sin dinero es de inversión
-- o de financiamiento (4.4).
-- ---------------------------------------------------------------------
create view public.v_estados_mapeo with (security_invoker = true) as
select p.cuenta,
       p.cuenta_nombre,
       p.cuenta_nombre_en,
       p.cuenta_tipo,
       p.saldo_normal,
       coalesce(m.estado, p.estado)                         as estado,
       coalesce(m.seccion, p.seccion)                       as seccion,
       coalesce(m.linea, p.linea)                           as linea,
       coalesce(m.orden, p.orden)                           as orden,
       coalesce(m.etiqueta_es, p.cuenta_nombre)             as etiqueta_es,
       coalesce(m.etiqueta_en, p.cuenta_nombre_en)          as etiqueta_en,
       coalesce(m.signo, p.signo)                           as signo,
       coalesce(m.contra, p.contra)                         as contra,
       coalesce(m.efectivo, p.efectivo)                     as efectivo,
       coalesce(m.flujo_directo, p.flujo_directo)           as flujo_directo,
       coalesce(m.flujo_indirecto, p.flujo_indirecto)       as flujo_indirecto,
       m.cuenta is null                                     as sin_fila,
       coalesce(ls.orden, 0)                                as seccion_orden,
       coalesce(ls.etiqueta_es, coalesce(m.seccion, p.seccion)) as seccion_es,
       coalesce(ls.etiqueta_en, coalesce(m.seccion, p.seccion)) as seccion_en,
       coalesce(ll.orden, 0)                                as linea_orden,
       coalesce(ll.etiqueta_es, coalesce(m.linea, p.linea)) as linea_es,
       coalesce(ll.etiqueta_en, coalesce(m.linea, p.linea)) as linea_en,
       case when coalesce(m.efectivo, p.efectivo) then 'efectivo' else fd.seccion end as flujo_directo_seccion,
       case when coalesce(m.efectivo, p.efectivo) then 'efectivo' else fi.seccion end as flujo_indirecto_seccion
  from public.v_estados_mapeo_propuesto p
  left join public.estados_mapeo m on m.cuenta = p.cuenta
  left join public.estados_lineas ls
         on ls.estado = coalesce(m.estado, p.estado) and ls.seccion = coalesce(m.seccion, p.seccion)
        and ls.linea = coalesce(m.seccion, p.seccion)
  left join public.estados_lineas ll
         on ll.estado = coalesce(m.estado, p.estado) and ll.seccion = coalesce(m.seccion, p.seccion)
        and ll.linea = coalesce(m.linea, p.linea)
  left join public.estados_lineas fd
         on fd.estado = 'flujo_directo' and fd.linea = coalesce(m.flujo_directo, p.flujo_directo)
        and fd.seccion not in ('totales', 'sin_dinero')
  left join public.estados_lineas fi
         on fi.estado = 'flujo_indirecto' and fi.linea = coalesce(m.flujo_indirecto, p.flujo_indirecto)
        and fi.seccion not in ('totales', 'sin_dinero');


-- ---------------------------------------------------------------------
-- 2.3 · Sembrar: los renglones de los estados, la configuración y la fila
-- de mapeo de cada cuenta que no la tenga. Solo entra lo que falta: una
-- etiqueta, un renglón o un mapeo que Edgar ya cambió no se pisa («not
-- exists», y no solo «on conflict»: el historial no se ensucia). Lo corre
-- cada pegado; volver a correrlo no cambia nada.
-- ---------------------------------------------------------------------
-- Las cuentas del plan que todavía no tienen fila (una tarjeta nueva de
-- c1), con lo propuesto. Devuelve cuáles entraron.
create or replace function public.fn_estados_mapeo_derivar()
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_nuevas jsonb;
begin
  perform fn_estados_exigir_dueno();
  with ins as (
    insert into estados_mapeo (cuenta, estado, seccion, linea, orden, signo, contra, efectivo, flujo_directo, flujo_indirecto)
    select p.cuenta, p.estado, p.seccion, p.linea, p.orden, p.signo, p.contra, p.efectivo, p.flujo_directo, p.flujo_indirecto
      from v_estados_mapeo_propuesto p
     where not exists (select 1 from estados_mapeo m where m.cuenta = p.cuenta)
     order by p.cuenta
    on conflict (cuenta) do nothing
    returning cuenta, seccion, linea
  )
  select coalesce(jsonb_agg(jsonb_build_object('cuenta', ins.cuenta, 'seccion', ins.seccion, 'linea', ins.linea)
                            order by ins.cuenta), '[]'::jsonb)
    into v_nuevas
    from ins;
  return jsonb_build_object('anadidas', v_nuevas);
end $$;
revoke execute on function public.fn_estados_mapeo_derivar() from public, anon, authenticated, service_role;

create or replace function public.fn_estados_sembrar()
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_lineas int;
  v_config int;
  v_mapeo  jsonb;
begin
  perform fn_estados_exigir_dueno();
  insert into estados_lineas (estado, seccion, linea, orden, etiqueta_es, etiqueta_en)
  select v.estado, v.seccion, v.linea, v.orden, v.es, v.en
    from (values
    -- El balance general: secciones (linea = seccion) y renglones.
    ('balance', 'activo_circulante',  'activo_circulante',        100, 'Activo circulante',                                   'Current assets'),
    ('balance', 'activo_circulante',  'efectivo',                 110, 'Efectivo y equivalentes',                             'Cash and cash equivalents'),
    ('balance', 'activo_circulante',  'cuentas_por_cobrar',       120, 'Cuentas por cobrar, neto',                            'Accounts receivable, net'),
    ('balance', 'activo_circulante',  'retencion_por_cobrar',     130, 'Retención por cobrar',                                'Retainage receivable'),
    ('balance', 'activo_circulante',  'wip_activo',               140, 'Costo y utilidad en exceso de facturación',           'Costs and estimated earnings in excess of billings'),
    ('balance', 'activo_circulante',  'inventario',               150, 'Material en bodega',                                  'Materials inventory'),
    ('balance', 'activo_circulante',  'prepagados',               160, 'Pagos por adelantado',                                'Prepaid expenses'),
    ('balance', 'activo_circulante',  'saldos_a_favor',           165, 'Saldos a favor con proveedores y tarjetas',           'Supplier and credit card debit balances'),
    ('balance', 'activo_circulante',  'impuestos_a_favor',        166, 'Nómina e impuestos pagados de más',                   'Overpaid payroll and taxes'),
    ('balance', 'activo_circulante',  'otros_saldos_deudores',    168, 'Otros pasivos pagados de más',                        'Other liabilities with debit balances'),
    ('balance', 'activo_fijo',        'activo_fijo',              200, 'Propiedad y equipo',                                  'Property and equipment'),
    ('balance', 'activo_fijo',        'propiedad_equipo',         210, 'Propiedad y equipo, al costo',                        'Property and equipment, at cost'),
    ('balance', 'activo_fijo',        'depreciacion_acumulada',   220, 'Menos: depreciación acumulada',                       'Less: accumulated depreciation'),
    ('balance', 'otros_activos',      'otros_activos',            300, 'Otros activos',                                       'Other assets'),
    ('balance', 'otros_activos',      'accionista_por_cobrar',    310, 'Cuenta por cobrar al accionista',                     'Due from shareholder'),
    ('balance', 'otros_activos',      'depositos',                320, 'Depósitos',                                           'Deposits'),
    ('balance', 'otros_activos',      'otros_activos_varios',     330, 'Otros activos',                                       'Other assets'),
    ('balance', 'pasivo_circulante',  'pasivo_circulante',        400, 'Pasivo circulante',                                   'Current liabilities'),
    ('balance', 'pasivo_circulante',  'sobregiro_bancario',       405, 'Sobregiro bancario',                                  'Bank overdraft'),
    ('balance', 'pasivo_circulante',  'cuentas_por_pagar',        410, 'Cuentas por pagar',                                   'Accounts payable'),
    ('balance', 'pasivo_circulante',  'anticipos_clientes',       415, 'Anticipos y saldos a favor de clientes',              'Customer deposits and credit balances'),
    ('balance', 'pasivo_circulante',  'retencion_por_pagar',      420, 'Retención por pagar a subcontratistas',               'Retainage payable'),
    ('balance', 'pasivo_circulante',  'devengados',               430, 'Costos y gastos devengados',                          'Accrued expenses'),
    ('balance', 'pasivo_circulante',  'tarjetas',                 440, 'Tarjetas de crédito',                                 'Credit cards'),
    ('balance', 'pasivo_circulante',  'nomina_por_pagar',         450, 'Nómina y retenciones por pagar',                      'Accrued payroll and withholdings'),
    ('balance', 'pasivo_circulante',  'impuestos_por_pagar',      460, 'Impuestos por pagar',                                 'Taxes payable'),
    ('balance', 'pasivo_circulante',  'wip_pasivo',               470, 'Facturación en exceso de costo',                      'Billings in excess of costs and estimated earnings'),
    ('balance', 'pasivo_circulante',  'provision_perdidas',       480, 'Provisión por pérdida en contratos',                  'Provision for losses on contracts'),
    ('balance', 'pasivo_circulante',  'linea_credito',            490, 'Línea de crédito',                                    'Line of credit'),
    ('balance', 'pasivo_circulante',  'prestamos_corto',          495, 'Préstamos, porción corriente',                        'Loans, current portion'),
    ('balance', 'pasivo_circulante',  'otros_pasivos',            499, 'Otros pasivos circulantes',                           'Other current liabilities'),
    ('balance', 'pasivo_largo_plazo', 'pasivo_largo_plazo',       500, 'Pasivo a largo plazo',                                'Long-term liabilities'),
    ('balance', 'pasivo_largo_plazo', 'prestamos_largo',          510, 'Préstamos a largo plazo',                             'Long-term loans'),
    ('balance', 'pasivo_largo_plazo', 'prestamo_accionista',      520, 'Préstamo del accionista',                             'Loan from shareholder'),
    ('balance', 'capital',            'capital',                  600, 'Capital',                                             'Shareholder''s equity'),
    ('balance', 'capital',            'capital_social',           610, 'Capital social',                                      'Common stock'),
    ('balance', 'capital',            'aportaciones',             620, 'Aportaciones',                                        'Additional paid-in capital'),
    ('balance', 'capital',            'distribuciones',           630, 'Distribuciones al accionista',                        'Shareholder distributions'),
    ('balance', 'capital',            'utilidades_retenidas',     640, 'Utilidades retenidas',                                'Retained earnings'),
    ('balance', 'capital',            'ejercicios_por_cerrar',    650, 'Resultado de ejercicios anteriores por cerrar',       'Prior-year results not yet closed'),
    ('balance', 'capital',            'resultado_ejercicio',      660, 'Resultado del ejercicio',                             'Net income for the year'),
    ('balance', 'capital',            'otro_capital',             670, 'Otras cuentas de capital',                            'Other equity'),
    ('balance', 'totales',            'total_activo',             900, 'Total activo',                                        'Total assets'),
    ('balance', 'totales',            'total_pasivo',             910, 'Total pasivo',                                        'Total liabilities'),
    ('balance', 'totales',            'total_capital',            920, 'Total capital',                                       'Total equity'),
    ('balance', 'totales',            'pasivo_mas_capital',       930, 'Pasivo más capital',                                  'Total liabilities and equity'),
    ('balance', 'totales',            'cuadra',                   940, 'Activo menos pasivo y capital (debe ser 0)',          'Assets less liabilities and equity (must be 0)'),
    -- El estado de resultados: sus secciones (por omisión cada cuenta va
    -- sola bajo la suya) y sus utilidades.
    ('resultados', 'ingresos',        'ingresos',                 100, 'Ingresos',                                            'Revenue'),
    ('resultados', 'costo',           'costo',                    200, 'Costo de obra',                                       'Cost of revenue'),
    ('resultados', 'gastos',          'gastos',                   300, 'Gastos de operación',                                 'Operating expenses'),
    ('resultados', 'otros_ingresos',  'otros_ingresos',           400, 'Otros ingresos',                                      'Other income'),
    ('resultados', 'otros_gastos',    'otros_gastos',             500, 'Otros gastos',                                        'Other expenses'),
    ('resultados', 'totales',         'utilidad_bruta',           250, 'Utilidad bruta',                                      'Gross profit'),
    ('resultados', 'totales',         'utilidad_operacion',       350, 'Utilidad de operación',                               'Operating income'),
    ('resultados', 'totales',         'utilidad_neta',            600, 'Utilidad neta',                                       'Net income'),
    -- El flujo de caja, método DIRECTO: el dinero que entró o salió, por su
    -- contrapartida.
    ('flujo_directo', 'operacion',      'operacion',              100, 'Actividades de operación',                            'Operating activities'),
    ('flujo_directo', 'operacion',      'cobros_clientes',        110, 'Cobros de clientes',                                  'Cash received from customers'),
    ('flujo_directo', 'operacion',      'proveedores',            120, 'Pagos a proveedores y subcontratistas',               'Cash paid to suppliers and subcontractors'),
    ('flujo_directo', 'operacion',      'tarjetas',               130, 'Pagos de tarjetas de crédito',                        'Credit card payments'),
    ('flujo_directo', 'operacion',      'nomina',                 140, 'Nómina',                                              'Payroll'),
    ('flujo_directo', 'operacion',      'impuestos',              150, 'Impuestos',                                           'Taxes paid'),
    ('flujo_directo', 'operacion',      'intereses',              160, 'Intereses',                                           'Interest'),
    ('flujo_directo', 'operacion',      'otros_operacion',        170, 'Otros de operación',                                  'Other operating'),
    ('flujo_directo', 'inversion',      'inversion',              200, 'Actividades de inversión',                            'Investing activities'),
    ('flujo_directo', 'inversion',      'activos_fijos',          210, 'Propiedad y equipo',                                  'Property and equipment'),
    ('flujo_directo', 'inversion',      'prestamos_otorgados',    220, 'Préstamos otorgados (al accionista y a otros)',       'Loans made (to the shareholder and others)'),
    ('flujo_directo', 'financiamiento', 'financiamiento',         300, 'Actividades de financiamiento',                       'Financing activities'),
    ('flujo_directo', 'financiamiento', 'prestamos',              310, 'Préstamos',                                           'Loans'),
    ('flujo_directo', 'financiamiento', 'dueno',                  320, 'Accionista: aportaciones, préstamos recibidos y distribuciones', 'Shareholder: contributions, loans received and distributions'),
    ('flujo_directo', 'financiamiento', 'sobregiro',              330, 'Sobregiro bancario (cambio neto)',                    'Bank overdraft (net change)'),
    ('flujo_directo', 'ajustes',        'ajustes',                400, 'Ajustes de ejercicios anteriores y de la apertura',   'Prior-period and opening adjustments'),
    -- Lo que se movió SIN dinero (un activo con tarjeta o con préstamo, una
    -- distribución sin dinero): se revela aparte y no suma al cambio del
    -- efectivo (ASC 230). Los dos métodos lo enseñan igual.
    ('flujo_directo', 'sin_dinero',     'sin_dinero',             500, 'Actividades sin dinero (se revelan; no suman)',       'Non-cash investing and financing activities (disclosed; not in cash flow)'),
    ('flujo_directo', 'sin_dinero',     'sd_inversion',           510, 'Inversión sin mover dinero (propiedad y equipo, préstamos otorgados)', 'Non-cash investing (property and equipment, loans made)'),
    ('flujo_directo', 'sin_dinero',     'sd_financiamiento',      520, 'Financiamiento sin mover dinero (préstamos, aportaciones y distribuciones)', 'Non-cash financing (loans, contributions and distributions)'),
    ('flujo_directo', 'sin_dinero',     'sd_ajustes',             530, 'Ajustes sin mover dinero (utilidades retenidas y apertura)', 'Non-cash equity adjustments'),
    ('flujo_directo', 'sin_dinero',     'sd_contrapartida',       540, 'Su contrapartida: tarjetas, proveedores y otros saldos', 'Offsetting balances: credit cards, payables and other'),
    ('flujo_directo', 'totales',        'efectivo_inicial',       900, 'Efectivo al inicio',                                  'Cash at beginning of period'),
    ('flujo_directo', 'totales',        'cambio',                 910, 'Cambio en el efectivo',                               'Net change in cash'),
    ('flujo_directo', 'totales',        'efectivo_final',         920, 'Efectivo al final',                                   'Cash at end of period'),
    -- El flujo de caja, método INDIRECTO: desde la utilidad, el cambio de
    -- cada saldo que no es dinero.
    ('flujo_indirecto', 'operacion',      'operacion',            100, 'Actividades de operación',                            'Operating activities'),
    ('flujo_indirecto', 'operacion',      'resultado',            101, 'Utilidad neta del ejercicio',                         'Net income'),
    ('flujo_indirecto', 'operacion',      'resultado_anteriores', 102, 'Resultados de ejercicios anteriores asentados en el período', 'Prior-year results recorded in the period'),
    ('flujo_indirecto', 'operacion',      'no_monetario',         110, 'Depreciación y otras partidas sin dinero',            'Depreciation and other non-cash items'),
    ('flujo_indirecto', 'operacion',      'ganancia_venta_activos', 112, '(Ganancia) o pérdida en venta de propiedad y equipo', '(Gain) loss on sale of property and equipment'),
    ('flujo_indirecto', 'operacion',      'op_cxc',               120, 'Cuentas y retención por cobrar',                      'Receivables and retainage'),
    ('flujo_indirecto', 'operacion',      'op_wip',               130, 'Obras en proceso (sobre y subfacturación)',           'Contracts in progress'),
    ('flujo_indirecto', 'operacion',      'op_inventario',        140, 'Material en bodega',                                  'Inventory'),
    ('flujo_indirecto', 'operacion',      'op_prepagados',        150, 'Pagos por adelantado',                                'Prepaid expenses'),
    ('flujo_indirecto', 'operacion',      'op_otros',             160, 'Otros activos y pasivos',                             'Other assets and liabilities'),
    ('flujo_indirecto', 'operacion',      'op_cxp',               170, 'Cuentas por pagar y devengados',                      'Payables and accruals'),
    ('flujo_indirecto', 'operacion',      'op_tarjetas',          180, 'Tarjetas de crédito',                                 'Credit cards'),
    ('flujo_indirecto', 'operacion',      'op_nomina',            190, 'Nómina por pagar',                                    'Payroll liabilities'),
    ('flujo_indirecto', 'operacion',      'op_impuestos',         195, 'Impuestos por pagar',                                 'Taxes payable'),
    ('flujo_indirecto', 'inversion',      'inversion',            200, 'Actividades de inversión',                            'Investing activities'),
    ('flujo_indirecto', 'inversion',      'activos_fijos',        210, 'Propiedad y equipo',                                  'Property and equipment'),
    ('flujo_indirecto', 'inversion',      'prestamos_otorgados',  220, 'Préstamos otorgados (al accionista y a otros)',       'Loans made (to the shareholder and others)'),
    ('flujo_indirecto', 'financiamiento', 'financiamiento',       300, 'Actividades de financiamiento',                       'Financing activities'),
    ('flujo_indirecto', 'financiamiento', 'fin_prestamos',        310, 'Préstamos',                                           'Loans'),
    ('flujo_indirecto', 'financiamiento', 'fin_accionista',       320, 'Préstamos del accionista',                            'Loans from shareholder'),
    ('flujo_indirecto', 'financiamiento', 'fin_capital',          330, 'Capital aportado',                                    'Contributed capital'),
    ('flujo_indirecto', 'financiamiento', 'fin_distribuciones',   340, 'Distribuciones al accionista',                        'Shareholder distributions'),
    ('flujo_indirecto', 'financiamiento', 'sobregiro',            350, 'Sobregiro bancario (cambio neto)',                    'Bank overdraft (net change)'),
    ('flujo_indirecto', 'ajustes',        'ajustes',              400, 'Ajustes a utilidades retenidas y a la apertura',      'Retained earnings and opening adjustments'),
    ('flujo_indirecto', 'sin_dinero',     'sin_dinero',           500, 'Actividades sin dinero (se revelan; no suman)',       'Non-cash investing and financing activities (disclosed; not in cash flow)'),
    ('flujo_indirecto', 'sin_dinero',     'sd_inversion',         510, 'Inversión sin mover dinero (propiedad y equipo, préstamos otorgados)', 'Non-cash investing (property and equipment, loans made)'),
    ('flujo_indirecto', 'sin_dinero',     'sd_financiamiento',    520, 'Financiamiento sin mover dinero (préstamos, aportaciones y distribuciones)', 'Non-cash financing (loans, contributions and distributions)'),
    ('flujo_indirecto', 'sin_dinero',     'sd_ajustes',           530, 'Ajustes sin mover dinero (utilidades retenidas y apertura)', 'Non-cash equity adjustments'),
    ('flujo_indirecto', 'sin_dinero',     'sd_contrapartida',     540, 'Su contrapartida: tarjetas, proveedores y otros saldos', 'Offsetting balances: credit cards, payables and other'),
    ('flujo_indirecto', 'totales',        'efectivo_inicial',     900, 'Efectivo al inicio',                                  'Cash at beginning of period'),
    ('flujo_indirecto', 'totales',        'cambio',               910, 'Cambio en el efectivo',                               'Net change in cash'),
    ('flujo_indirecto', 'totales',        'efectivo_final',       920, 'Efectivo al final',                                   'Cash at end of period')
    ) as v(estado, seccion, linea, orden, es, en)
   where not exists (select 1 from estados_lineas l
                      where l.estado = v.estado and l.seccion = v.seccion and l.linea = v.linea)
  on conflict (estado, seccion, linea) do nothing;
  get diagnostics v_lineas = row_count;
  insert into estados_config (clave, valor, notas)
  select 'plegar_3200', 'no', 'Las distribuciones (3200) se enseñan aparte, las de toda la vida de la empresa. ''si'' = al cerrarse un '
                               'año se pliegan a utilidades retenidas (lo decide el CPA).'
   where not exists (select 1 from estados_config where clave = 'plegar_3200')
  on conflict (clave) do nothing;
  get diagnostics v_config = row_count;
  -- 1130 (lo que la empresa le presta al accionista) va a inversión en los
  -- dos métodos del flujo. Su fila, si todavía dice lo que proponía la
  -- versión anterior de este archivo (financiamiento), pasa a lo de ahora,
  -- con su rastro; una que Edgar cambió a otra cosa no se toca.
  update estados_mapeo m
     set flujo_directo = p.flujo_directo, flujo_indirecto = p.flujo_indirecto
    from v_estados_mapeo_propuesto p
   where p.cuenta = m.cuenta and left(m.cuenta, 4) = '1130'
     and m.flujo_directo = 'dueno' and m.flujo_indirecto = 'fin_accionista'
     and p.flujo_directo = 'prestamos_otorgados' and p.flujo_indirecto = 'prestamos_otorgados';
  v_mapeo := fn_estados_mapeo_derivar();
  return jsonb_build_object('renglones', v_lineas, 'configuracion', v_config, 'mapeo', v_mapeo->'anadidas');
end $$;
revoke execute on function public.fn_estados_sembrar() from public, anon, authenticated, service_role;

do $$
begin
  perform public.fn_estados_sembrar();
end $$;


-- =====================================================================
-- 3 · LAS VISTAS DE BASE: los cortes, los ejercicios, el libro línea por
-- línea, el mayor con su saldo corrido y el papel de cada asiento.
-- Todas security_invoker: leen con los permisos de quien las mira (el
-- libro, solo el dueño). Ninguna llama a una función de este archivo ni a
-- una ayudante de los puentes (el equipo no ejecuta nada de eso): casan y
-- suman con SQL llano. Cada una que cambia de columnas se borra antes de
-- crearla (drop view … cascade arrastra a las de abajo, que se vuelven a
-- crear en este mismo pegado).
-- =====================================================================
drop view if exists public.v_cortes cascade;
drop view if exists public.v_ejercicios cascade;
drop view if exists public.v_libro cascade;
drop view if exists public.v_asiento_papel cascade;

-- ---------------------------------------------------------------------
-- 3.1 · v_cortes — las fechas a las que se pide un saldo: el último día de
-- cada período (cada mes, la apertura y cada año) y «hoy» (hoy en Miami).
--   periodo   el nombre del período, o 'hoy';
--   desde     su primer día (en 'hoy', el primero del mes en curso: lo que
--             va del mes);
--   corte     su último día (en 'hoy', hoy): el saldo se toma con todo lo
--             fechado hasta ese día, incluido.
-- 'hoy' sale solo si quien mira ve el libro: el equipo no ve ni una fila.
-- ---------------------------------------------------------------------
create view public.v_cortes with (security_invoker = true) as
select p.periodo, p.tipo, p.anio, p.desde, p.hasta as corte,
       jsonb_path_query_first(to_jsonb(p), 'strict $.estado') #>> '{}' as estado,   -- (sin fijarle el tipo: ver 2.1)
       p.paralelo
  from public.periodos p
union all
select 'hoy', 'hoy', extract(year from h.hoy)::int, date_trunc('month', h.hoy::timestamp)::date, h.hoy,
       'abierto',
       coalesce((select p.paralelo from public.periodos p where p.tipo = 'mes' and h.hoy between p.desde and p.hasta), false)
  from (select public.fn_fecha_miami(now()) as hoy) h
 where exists (select 1 from public.periodos);

-- ---------------------------------------------------------------------
-- 3.2 · v_ejercicios — cada año y si ya está cerrado. «Ejercicio cerrado»
-- lo decide el cierre del año (c2): su resultado se arrastra a
-- utilidades retenidas (3900) en el balance de los años siguientes.
-- ---------------------------------------------------------------------
create view public.v_ejercicios with (security_invoker = true) as
select p.anio, f.estado = 'cerrado' as cerrado, f.cerrado_el
  from public.periodos p
  cross join lateral (   -- (sin fijarles el tipo: ver 2.1)
    select jsonb_path_query_first(to_jsonb(p), 'strict $.estado') #>> '{}'                   as estado,
           (jsonb_path_query_first(to_jsonb(p), 'strict $.cerrado_el') #>> '{}')::timestamptz as cerrado_el) f
 where p.tipo = 'anio';

-- ---------------------------------------------------------------------
-- 3.3 · v_libro — el libro LÍNEA POR LÍNEA, con todo lo que hace falta
-- para bajar a él desde cualquier cifra: el asiento (asiento_id, numero,
-- su fecha, su período, su camino) y su papel (origen_tabla, origen_id,
-- documento_ruta), la cuenta con su mapeo (estado, sección, renglón,
-- signo, si es dinero y a qué renglón del flujo va), las dimensiones, el
-- tercero y la partida. Monto con signo (positivo = debe); debe y haber,
-- en positivo.
--   ejercicio         el año al que PERTENECE la línea: el de su asiento,
--                     salvo en un ajuste del CPA, que es del año del
--                     período que corrige (afecta_periodo). Así el reverso
--                     en 2027 de un error de 2026 es de 2026: no mueve el
--                     resultado de 2027 (c2) y en el balance va a
--                     utilidades retenidas.
--   periodo_efectivo  el período al que pertenece: el de su fecha, o el
--                     que corrige un ajuste del CPA («con ajustes
--                     posteriores»).
--   efectivo_hasta    el último día de ese período: HASTA DÓNDE corrige
--                     la línea. Un ajuste del CPA posterior corrige el
--                     corte de un período si efectivo_hasta ≤ el corte: se
--                     compara por FECHA, no por el nombre del período (como
--                     texto, '2026' —el año— quedaba «antes» de
--                     '2026-10', y un ajuste de fin de año salía en los
--                     posteriores de la apertura, de octubre y de
--                     noviembre).
-- Es la vista a la que baja toda cifra (la llave «bajar» de las demás).
-- ---------------------------------------------------------------------
create view public.v_libro with (security_invoker = true) as
-- (El mapeo se lee UNA vez por consulta —88 cuentas— y se casa con las
-- líneas en memoria: con la policy del libro, cada fila leída de una tabla
-- cuesta una llamada a es_dueno(), y buscarlo línea por línea la hacía
-- miles de veces.)
with m as materialized (select * from public.v_estados_mapeo)
select l.asiento_id,
       a.numero,
       l.orden,
       a.fecha_contable                                                        as fecha,
       a.periodo,
       case when a.tipo = 'ajuste_cpa' then a.afecta_periodo else a.periodo end as periodo_efectivo,
       (select pe.hasta from public.periodos pe
         where pe.periodo = case when a.tipo = 'ajuste_cpa' then a.afecta_periodo else a.periodo end)
                                                                               as efectivo_hasta,
       a.anio,
       case when a.afecta_periodo is null then a.anio
            else coalesce((select pa.anio from public.periodos pa where pa.periodo = a.afecta_periodo), a.anio) end
                                                                               as ejercicio,
       a.tipo,
       a.afecta_periodo,
       a.camino,
       a.descripcion,
       a.motivo,
       a.reversa_a,
       a.sustituye_a,
       a.reversible,
       a.origen_tabla,
       a.origen_id,
       a.documento_ruta,
       a.cadena_pos,
       l.cuenta,
       m.cuenta_nombre,
       m.cuenta_tipo,
       m.saldo_normal,
       m.estado,
       m.seccion,
       m.linea,
       m.signo,
       m.contra,
       m.efectivo,
       m.flujo_directo,
       m.flujo_indirecto,
       m.flujo_directo_seccion,
       m.flujo_indirecto_seccion,
       l.monto,
       greatest(l.monto, 0)::numeric(14,2)                                     as debe,
       greatest(-l.monto, 0)::numeric(14,2)                                    as haber,
       l.proyecto_id,
       l.cost_code,
       l.co,
       l.fase,
       l.memo,
       l.tercero_tipo,
       l.tercero_id,
       l.partida_tabla,
       l.partida_id
  from public.asiento_lineas l
  join public.asientos a on a.id = l.asiento_id
  join m on m.cuenta = l.cuenta;

-- ---------------------------------------------------------------------
-- 3.4 · v_mayor — el libro mayor: v_libro con el SALDO CORRIDO de cada
-- cuenta, en el orden del libro (fecha, posición en la cadena, línea).
--   saldo            debe − haber acumulado hasta esa línea (incluida);
--   saldo_en_su_lado el mismo, del lado en que crece la cuenta (positivo
--                    = normal): el que se pinta;
--   reversado        el asiento ya tiene su reverso de corrección.
-- Filtrar por cuenta es rápido (el saldo se calcula por cuenta). Filtrar
-- por fecha o período NO cambia el saldo corrido: se calcula con toda la
-- historia de la cuenta y después se filtra (el saldo del 5-oct es el del
-- 5-oct, aunque se pida solo octubre). En las cuentas de RESULTADOS la
-- historia es la de su EJERCICIO: cada año empieza en cero, como en la
-- balanza y en el estado de resultados (antes el mayor de enero de 2027
-- arrastraba todo 2026 y no cuadraba con ninguno, y es el mayor que f08
-- manda al CPA). Un ajuste del CPA a 2026 posteado en 2027 corre con
-- 2026, que es su ejercicio.
-- ---------------------------------------------------------------------
create view public.v_mayor with (security_invoker = true) as
select v.*,
       (sum(v.monto) over w)::numeric(14,2)                                            as saldo,
       (sum(v.monto) over w * (case when v.saldo_normal = 'debe' then 1 else -1 end))::numeric(14,2) as saldo_en_su_lado,
       exists (select 1 from public.asientos r where r.reversa_a = v.asiento_id and r.camino = 'reverso') as reversado
  from public.v_libro v
window w as (partition by v.cuenta, case when v.estado = 'resultados' then v.ejercicio end
             order by v.fecha, v.cadena_pos, v.orden rows between unbounded preceding and current row);

-- ---------------------------------------------------------------------
-- 3.5 · v_asiento_papel — del asiento a su PAPEL: el recibo con su foto,
-- la factura, el trabajo externo, el cobro, la nota de crédito, la
-- devolución, el mes del devengo, la balanza de apertura; o, si el asiento
-- es a mano, él mismo (su descripción, su motivo y el documento que diga,
-- documento_ruta). papel_existe = el papel está (el recibo sigue en su
-- tabla, la balanza tiene sus filas…): un asiento de puente cuyo papel
-- falta es un rastro roto, y se ve. Un reverso lleva el papel de su
-- original.
-- ---------------------------------------------------------------------
create view public.v_asiento_papel with (security_invoker = true) as
-- (Cada papel por su llave, con una búsqueda por índice por asiento y solo
-- en la tabla de su papel.)
select a.id                                   as asiento_id,
       a.numero,
       a.fecha_contable                       as fecha,
       a.periodo,
       a.tipo,
       a.camino,
       a.descripcion,
       a.origen_tabla,
       a.origen_id,
       a.documento_ruta,
       a.reversa_a,
       a.sustituye_a,
       exists (select 1 from public.asientos x where x.reversa_a = a.id and x.camino = 'reverso') as reversado,
       -- Un asiento a mano es su propio papel (su descripción, su motivo y
       -- el documento que diga); uno de puente, el papel de su origen, que
       -- tiene que seguir ahí.
       case when a.origen_tabla is null then true else coalesce(pp.existe, false) end as papel_existe,
       coalesce(pp.papel, case when a.origen_tabla is null
                               then concat_ws(' · ', 'Asiento a mano: ' || a.descripcion, 'motivo: ' || a.motivo,
                                              'documento: ' || a.documento_ruta)
                               else format('%s %s (el papel ya no está)', a.origen_tabla, a.origen_id) end) as papel,
       coalesce(pp.ruta, a.documento_ruta)    as papel_ruta
  from public.asientos a
  left join lateral (
    select true as existe,
           concat_ws(' · ', 'Recibo ' || r.id, nullif(btrim(r.proveedor), ''), '#' || nullif(btrim(r.num_recibo), ''),
                     r.fecha::text, r.estado) as papel,
           nullif(btrim(r.ruta), '') as ruta
      from public.recibos r
     where a.origen_tabla = 'recibos' and a.origen_id ~ '^-?[0-9]{1,18}$' and r.id = a.origen_id::bigint
    union all
    select true, concat_ws(' · ', 'Factura #' || f.num, f.fecha::text, f.estado), null
      from public.facturas f
     where a.origen_tabla = 'facturas' and a.origen_id ~ '^-?[0-9]{1,18}$' and f.id = a.origen_id::bigint
    union all
    select true, concat_ws(' · ', 'Trabajo externo ' || x.id, x.descripcion, x.fecha::text), null
      from public.trabajos_externos x
     where a.origen_tabla = 'trabajos_externos' and a.origen_id ~ '^-?[0-9]{1,18}$' and x.id = a.origen_id::bigint
    union all
    select true, concat_ws(' · ', 'Cobro', c.medio, c.referencia, c.fecha::text, c.estado), null
      from public.cobros c
     where a.origen_tabla = 'cobros' and a.origen_id ~ '^[0-9a-f-]{36}$' and c.id = a.origen_id::uuid
    union all
    select true, concat_ws(' · ', 'Anticipo aplicado', ap.fecha::text), null
      from public.aplicaciones_cobro ap
     where a.origen_tabla = 'aplicaciones_cobro' and a.origen_id ~ '^[0-9a-f-]{36}$' and ap.id = a.origen_id::uuid
    union all
    select true, concat_ws(' · ', 'Nota de crédito ' || n.numero, n.fecha::text), null
      from public.notas_credito n
     where a.origen_tabla = 'notas_credito' and a.origen_id ~ '^[0-9a-f-]{36}$' and n.id = a.origen_id::uuid
    union all
    select true, concat_ws(' · ', 'Devolución de cobro', dv.fecha::text, dv.motivo), null
      from public.cobros_devoluciones dv
     where a.origen_tabla = 'cobros_devoluciones' and a.origen_id ~ '^[0-9a-f-]{36}$' and dv.id = a.origen_id::uuid
    union all
    select true, 'Devengo estándar de horas aprobadas de ' || p.periodo, null
      from public.periodos p
     where a.origen_tabla = 'horas_devengo' and p.periodo = a.origen_id and p.tipo = 'mes'
    union all
    -- La apertura de la balanza es la que posteó fn_apertura (lo dice su
    -- procedencia), o el reverso de esa. Un asiento de apertura hecho a mano
    -- que dice el mismo papel (un sustituto con fn_postear hereda el origen
    -- del que sustituye, c2) NO es de la balanza: su papel es él mismo.
    select true,
           case when x.de_la_balanza then 'Balanza de QuickBooks de la apertura: ' || a.documento_ruta
                else concat_ws(' · ', 'Asiento de apertura a mano (no lo posteó fn_apertura con esa balanza): ' || a.descripcion,
                               'motivo: ' || a.motivo, 'dice el documento: ' || a.documento_ruta) end,
           a.documento_ruta
      from (select coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'
                   or exists (select 1 from public.asientos o
                               where o.id = a.reversa_a and coalesce(o.procedencia->>'funcion', '') = 'fn_apertura') as de_la_balanza) x
     where a.origen_tabla = 'apertura_balanza_qb'
       and (not x.de_la_balanza or exists (select 1 from public.apertura_balanza_qb b where b.documento = a.documento_ruta))
    limit 1
  ) pp on true;


-- ---------------------------------------------------------------------
-- 3.6 · v_qb_balanzas — cada fila de QuickBooks que cuenta para comparar,
-- con la cuenta del plan a la que va (apertura_mapeo_qb) y su obra:
--   · de cada período, la balanza de comparacion_qb cargada MÁS TARDE (las
--     anteriores quedan como rastro, vigente = false); la hora la pone la
--     base al cargarla (1.6), no quien escribe;
--   · de la apertura, si no se cargó una en comparacion_qb, la balanza con
--     que fn_apertura posteó el ÚLTIMO asiento de apertura (fuente
--     'apertura_balanza_qb', con su asiento_id), VIVO O REVERSADO (vivo lo
--     dice): si alguien reversa la apertura, su balanza de QuickBooks
--     sigue contando y la comparación dice, en rojo, que el libro ya no la
--     tiene (antes desaparecía, y la apertura, octubre y 'hoy' salían en
--     verde con el banco en 0). Si fn_apertura nunca posteó, la balanza de
--     apertura cargada más tarde (sin asiento): el libro, sin apertura,
--     contra QuickBooks. Un asiento de apertura hecho a mano, aunque diga
--     el mismo papel (un sustituto hereda el origen del que sustituye, c2),
--     no trae balanza: su procedencia no es fn_apertura. Las filas de
--     CONTROL de la balanza (Net Income, TOTAL ASSETS) no son cuentas: no
--     salen aquí.
--   saldo           debe − haber, como en el libro;
--   cuenta          la cuenta del plan (nula = sin mapeo: v_comparacion la
--                   pone en rojo);
--   proyecto_id     la obra: la de la fila, la del Customer:Job mapeado o
--                   la de su factura;
--   con_posteriores la balanza trae ya los ajustes del CPA posteriores al
--                   período (la final de diciembre): v_comparacion le suma
--                   al libro los ajuste_cpa fechados después que corrigen
--                   hasta ese período;
--   al              la fecha de la balanza (nula = el fin del período): la
--                   de una quincena corta el libro a ese día;
--   vivo            (la de la apertura) su asiento sigue vivo.
-- (Va aquí, en la base: el balance general la usa para el resultado de
-- enero a septiembre de la apertura.)
-- ---------------------------------------------------------------------
drop view if exists public.v_qb_balanzas cascade;
create view public.v_qb_balanzas with (security_invoker = true) as
with ap as materialized (
  -- La balanza de la apertura: la del último asiento que posteó
  -- fn_apertura (vivo o reversado); si nunca posteó, la cargada más tarde.
  select x.asiento_id, x.numero, coalesce(x.documento_ruta, y.documento) as documento_ruta,
         pa.periodo, coalesce(x.vivo, false) as vivo
    from (select p.periodo from public.periodos p where p.tipo = 'apertura' order by p.desde limit 1) pa
    left join lateral (
      select a.id as asiento_id, a.numero, a.documento_ruta,
             not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino = 'reverso') as vivo
        from public.asientos a
       where a.origen_tabla = 'apertura_balanza_qb' and a.tipo = 'apertura'
         and coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'
         and a.camino not in ('reverso', 'reverso_automatico')
       order by a.cadena_pos desc
       limit 1) x on true
    left join lateral (
      select b.documento from public.apertura_balanza_qb b
       order by b.cargado_el desc, b.documento desc
       limit 1) y on x.asiento_id is null
   where coalesce(x.documento_ruta, y.documento) is not null
), cq as materialized (
  -- La que vale: la balanza (el documento) cargada más tarde en el período.
  select q.*,
         q.documento = first_value(q.documento) over (partition by q.periodo order by q.cargado_el desc, q.documento desc) as ultima
    from public.comparacion_qb q
)
select cq.periodo, 'comparacion_qb'::text as fuente, cq.documento, cq.linea, cq.cuenta_qb, cq.clave, cq.cliente_trabajo,
       coalesce(cq.proyecto_id, mt.proyecto_id) as proyecto_id, cq.saldo::numeric(14,2) as saldo,
       mc.cuenta, c.tipo as cuenta_tipo, cq.ultima as vigente, null::uuid as asiento_id, null::text as numero,
       cq.con_posteriores, cq.al, null::boolean as vivo
  from cq
  left join public.apertura_mapeo_qb mc on mc.tipo = 'cuenta' and mc.clave = cq.clave
  left join public.apertura_mapeo_qb mt on mt.tipo = 'trabajo' and mt.clave = cq.cliente_clave
  left join public.cuentas c on c.codigo = mc.cuenta
union all
select ap.periodo, 'apertura_balanza_qb', b.documento, b.linea, b.cuenta_qb, b.clave, b.cliente_trabajo,
       coalesce(b.proyecto_id, mt.proyecto_id, f.proyecto_id),
       (coalesce(b.debe, 0) - coalesce(b.haber, 0))::numeric(14,2),
       mc.cuenta, c.tipo, not exists (select 1 from public.comparacion_qb q where q.periodo = ap.periodo), ap.asiento_id, ap.numero,
       false, null::date, ap.vivo
  from ap
  join public.apertura_balanza_qb b on b.documento = ap.documento_ruta and b.control is null
  left join public.apertura_mapeo_qb mc on mc.tipo = 'cuenta' and mc.clave = b.clave
  left join public.apertura_mapeo_qb mt on mt.tipo = 'trabajo' and mt.clave = b.cliente_clave
  left join public.facturas f on f.id = b.factura_id
  left join public.cuentas c on c.codigo = mc.cuenta;


-- =====================================================================
-- 4 · LOS ESTADOS FINANCIEROS
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4.1 · La balanza de comprobación, por período (v_balanza) y por período,
-- obra y cost code (v_balanza_obra). Salen de UNA vista de base
-- (v_balanza_base, con los dos cortes a la vez: grouping sets), para que
-- las dos digan siempre lo mismo.
--   Por cuenta: saldo_inicial (antes del primer día del período), debe y
--   haber (lo del período), saldo_final. En el balance, todo desde el
--   principio; en resultados, lo del AÑO del período (enero a la fecha: una
--   cuenta de resultados empieza cada año en cero). El resultado de los
--   años anteriores no está en sus cuentas: sale en dos renglones aparte
--   (nivel 'componente'): «arrastre» (los ejercicios ya CERRADOS: en el
--   balance van dentro de utilidades retenidas, 3900) y «por_cerrar» (los
--   años anteriores que todavía no se cierran: 2026 hasta que el CPA
--   entregue). El libro no postea asientos de cierre: esos renglones son
--   el arrastre, hecho aquí, a la vista.
--   EN CERO: la suma de saldo_final (y la de saldo_inicial) es 0 y el
--   debe es igual al haber: cada asiento cuadra (c2). El renglón nivel
--   'total' lo dice (cuadra).
--   Cada cifra trae con qué bajar a sus líneas (la llave «bajar»).
-- ---------------------------------------------------------------------
drop view if exists public.v_balanza_base cascade;
create view public.v_balanza_base with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.desde, p.hasta, x.*
  from public.periodos p
  cross join lateral (
    with l as materialized (
      select v.cuenta, v.fecha, v.ejercicio, v.monto, v.asiento_id, v.numero, v.proyecto_id, v.cost_code,
             case when v.estado = 'balance' or v.ejercicio = p.anio then 'cuenta'
                  when coalesce(e.cerrado, false) then 'arrastre'
                  else 'por_cerrar' end as clase
        from public.v_libro v
        left join public.v_ejercicios e on e.anio = v.ejercicio
       where v.fecha <= p.hasta
    ), g as materialized (
      select l.clase,
             case when l.clase = 'cuenta' then l.cuenta end                                        as cuenta,
             case when l.clase = 'cuenta' then l.proyecto_id end                                   as proyecto_id,
             case when l.clase = 'cuenta' then l.cost_code end                                     as cost_code,
             grouping(case when l.clase = 'cuenta' then l.proyecto_id end,
                      case when l.clase = 'cuenta' then l.cost_code end) = 0                       as por_obra,
             coalesce(sum(l.monto) filter (where l.fecha < p.desde), 0)::numeric(14,2)             as saldo_inicial,
             coalesce(sum(l.monto) filter (where l.fecha >= p.desde and l.monto > 0), 0)::numeric(14,2)  as debe,
             coalesce(-sum(l.monto) filter (where l.fecha >= p.desde and l.monto < 0), 0)::numeric(14,2) as haber,
             sum(l.monto)::numeric(14,2)                                                           as saldo_final,
             count(distinct l.asiento_id) filter (where l.fecha >= p.desde)                        as asientos,
             min(l.asiento_id::text) filter (where l.fecha >= p.desde)                             as asiento_min,
             min(l.numero) filter (where l.fecha >= p.desde)                                       as numero_min,
             to_jsonb(array_agg(distinct l.ejercicio order by l.ejercicio))                        as ejercicios
        from l
       group by grouping sets ((l.clase, case when l.clase = 'cuenta' then l.cuenta end),
                               (l.clase, case when l.clase = 'cuenta' then l.cuenta end,
                                case when l.clase = 'cuenta' then l.proyecto_id end,
                                case when l.clase = 'cuenta' then l.cost_code end))
    ), f as materialized (
      -- Los filtros con que se baja al libro desde cada renglón.
      select g.*,
             case when g.clase = 'cuenta'
                  then jsonb_build_object('cuenta', g.cuenta)
                       || case when m.estado = 'resultados' then jsonb_build_object('ejercicio', p.anio) else '{}'::jsonb end
                       || case when g.por_obra then jsonb_build_object('proyecto_id', g.proyecto_id, 'cost_code', g.cost_code)
                               else '{}'::jsonb end
                  else jsonb_build_object('estado', 'resultados', 'ejercicio', g.ejercicios) end   as filtros,
             m.cuenta_nombre, m.etiqueta_es, m.etiqueta_en, m.estado, m.seccion, m.linea, m.saldo_normal,
             coalesce(m.orden, case g.clase when 'arrastre' then 39001 else 39002 end)           as orden_cuenta
        from g
        left join public.v_estados_mapeo m on m.cuenta = g.cuenta
    )
    select f.por_obra,
           'cuenta'::text                                                       as nivel,
           f.orden_cuenta                                                       as orden,
           f.cuenta,
           f.cuenta_nombre,
           f.proyecto_id,
           f.cost_code,
           null::text                                                           as componente,
           f.etiqueta_es,
           f.etiqueta_en,
           f.estado,
           f.seccion,
           f.linea,
           f.saldo_inicial, f.debe, f.haber, f.saldo_final,
           (f.saldo_final * case when f.saldo_normal = 'haber' then -1 else 1 end)::numeric(14,2) as saldo_en_su_lado,
           f.asientos,
           case when f.asientos = 1 then f.asiento_min::uuid end               as asiento_id,
           case when f.asientos = 1 then f.numero_min end                       as numero,
           null::boolean                                                        as cuadra,
           jsonb_build_object(
             'saldo_inicial', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', f.filtros,
                                                 'hasta', (p.desde - 1)::text)),
             'debe',          jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'debe', 'signo', 1, 'filtros', f.filtros,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text)),
             'haber',         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'haber', 'signo', 1, 'filtros', f.filtros,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text)),
             'saldo_final',   jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', f.filtros,
                                                 'hasta', p.hasta::text)),
             'saldo_en_su_lado', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto',
                                                 'signo', case when f.saldo_normal = 'haber' then -1 else 1 end,
                                                 'filtros', f.filtros, 'hasta', p.hasta::text))) as bajar
      from f
     where f.clase = 'cuenta'
    union all
    select f.por_obra, 'componente', f.orden_cuenta, null, null, null, null, f.clase,
           case f.clase when 'arrastre' then 'Resultados de ejercicios cerrados (en utilidades retenidas)'
                        else 'Resultados de ejercicios anteriores por cerrar' end,
           case f.clase when 'arrastre' then 'Closed-year results (in retained earnings)'
                        else 'Prior-year results not yet closed' end,
           'balance', 'capital', case f.clase when 'arrastre' then 'utilidades_retenidas' else 'ejercicios_por_cerrar' end,
           f.saldo_inicial, f.debe, f.haber, f.saldo_final, (-f.saldo_final)::numeric(14,2),
           f.asientos, case when f.asientos = 1 then f.asiento_min::uuid end, case when f.asientos = 1 then f.numero_min end,
           null,
           jsonb_build_object(
             'saldo_inicial', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', f.filtros,
                                                 'hasta', (p.desde - 1)::text)),
             'debe',          jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'debe', 'signo', 1, 'filtros', f.filtros,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text)),
             'haber',         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'haber', 'signo', 1, 'filtros', f.filtros,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text)),
             'saldo_final',   jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', f.filtros,
                                                 'hasta', p.hasta::text)),
             'saldo_en_su_lado', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                                                 'filtros', f.filtros, 'hasta', p.hasta::text)))
      from f
     where f.clase <> 'cuenta'
    union all
    -- El total: en cero.
    select t.por_obra, 'total', 999999, null, null, null, null, null, 'Totales', 'Totals', null, null, null,
           t.saldo_inicial, t.debe, t.haber, t.saldo_final, null::numeric(14,2), t.asientos, null, null,
           t.saldo_inicial = 0 and t.saldo_final = 0 and t.debe = t.haber,
           jsonb_build_object(
             'saldo_inicial', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', '{}'::jsonb,
                                                 'hasta', (p.desde - 1)::text)),
             'debe',          jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'debe', 'signo', 1, 'filtros', '{}'::jsonb,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text)),
             'haber',         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'haber', 'signo', 1, 'filtros', '{}'::jsonb,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text)),
             'saldo_final',   jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', '{}'::jsonb,
                                                 'hasta', p.hasta::text)))
      from (select f.por_obra, sum(f.saldo_inicial)::numeric(14,2) as saldo_inicial, sum(f.debe)::numeric(14,2) as debe,
                   sum(f.haber)::numeric(14,2) as haber, sum(f.saldo_final)::numeric(14,2) as saldo_final,
                   (select count(distinct l.asiento_id) from l where l.fecha >= p.desde) as asientos
              from f group by f.por_obra) t
  ) x;

create view public.v_balanza with (security_invoker = true) as
select b.periodo, b.periodo_tipo, b.desde, b.hasta, b.nivel, b.orden, b.cuenta, b.cuenta_nombre, b.componente,
       b.etiqueta_es, b.etiqueta_en, b.estado, b.seccion, b.linea, b.saldo_inicial, b.debe, b.haber, b.saldo_final,
       b.saldo_en_su_lado, b.asientos, b.asiento_id, b.numero, b.cuadra, b.bajar
  from public.v_balanza_base b
 where not b.por_obra;

create view public.v_balanza_obra with (security_invoker = true) as
select b.periodo, b.periodo_tipo, b.desde, b.hasta, b.nivel, b.orden, b.cuenta, b.cuenta_nombre, b.proyecto_id,
       pr.nombre as obra, b.cost_code, b.componente, b.etiqueta_es, b.etiqueta_en, b.estado, b.seccion, b.linea,
       b.saldo_inicial, b.debe, b.haber, b.saldo_final, b.saldo_en_su_lado, b.asientos, b.asiento_id, b.numero, b.cuadra,
       b.bajar
  from public.v_balanza_base b
  left join public.proyectos pr on pr.id = b.proyecto_id
 where b.por_obra;


-- ---------------------------------------------------------------------
-- 4.2 · v_balance_general — el balance general a cada corte (v_cortes: el
-- fin de cada período y «hoy»): activo = pasivo + capital, con el capital
-- completo:
--   · cada cuenta de balance, con su saldo a esa fecha (toda la historia
--     hasta el corte, incluido);
--   · «Utilidades retenidas» = la 3900 (lo que trajo la apertura: el capital
--     de QuickBooks y el resultado de enero a septiembre de 2026) MÁS el
--     resultado de los ejercicios ya CERRADOS (componente 'arrastre'); en
--     los cortes del año de la apertura, MENOS el resultado de enero al día
--     de la apertura (componente 'resultado_apertura'), que va en…
--   · «Resultado del ejercicio» = el resultado del año del corte, de enero
--     al corte: lo del libro (componente 'resultado') y, en el año de la
--     apertura, lo de antes de ella según la balanza de QuickBooks con que
--     fn_apertura la posteó (componente 'resultado_apertura', que baja a
--     esa balanza). Así el balance al 31-oct-2026 dice lo mismo que el de
--     QuickBooks: las utilidades retenidas al 1-ene y el resultado de todo
--     el año. Sin esa balanza (una apertura a mano), el componente
--     'resultado' lo dice en su etiqueta: «desde el 1-oct»;
--   · «Resultado de ejercicios anteriores por cerrar» = el resultado de los
--     años anteriores que todavía no se cierran (componente 'por_cerrar'):
--     2026, mientras el CPA no entregue. Con el de antes de la apertura
--     ('resultado_apertura', que en los cortes de 2027 sale de utilidades
--     retenidas y entra aquí mientras 2026 no se cierre): todo 2026, no solo
--     lo de octubre a diciembre;
--   · «Distribuciones» (3200) aparte, todas las de la vida de la empresa.
--     Si el CPA pide plegarlas (estados_config plegar_3200 = 'si'), las de
--     los ejercicios cerrados se enseñan dentro de utilidades retenidas
--     (componente 'plegado_3200', en las dos líneas, con signo contrario):
--     el total del capital no cambia, y no se postea nada;
--   · LO QUE VA CONTRA SU RENGLÓN SE PINTA DEL OTRO LADO. No se compensa lo
--     de un cliente con lo de otro (ASC 210-20), ni un banco en rojo con
--     otro en negro, ni un pasivo pagado de más con lo que se debe:
--     reclasificaciones de PRESENTACIÓN, como el plegado de 3200. Salen de
--     su renglón y entran en el otro por el mismo monto (componente
--     'reclasif_…' en los dos), cada una con su «bajar» a sus partidas; el
--     libro no cambia, y activo − pasivo − capital sigue en 0.00 (sube el
--     activo y el pasivo por lo mismo):
--       · reclasif_anticipos: las partidas de cobrar (1110 y 1120, partida
--         por partida, las mismas de v_cxc_antiguedad) con saldo ACREEDOR
--         —un anticipo, un saldo a favor del cliente— van al pasivo,
--         «Anticipos y saldos a favor de clientes» (un pasivo del contrato,
--         ASC 606). Así «Cuentas por cobrar» es lo que de verdad se debe;
--       · reclasif_a_favor: lo que un proveedor nos debe (2010 y la
--         retención por pagar con saldo DEUDOR, proveedor por proveedor) y
--         una tarjeta pagada de más (cuenta por cuenta) van al activo,
--         «Saldos a favor con proveedores y tarjetas»;
--       · reclasif_sobregiro: una cuenta de efectivo en rojo (saldo
--         ACREEDOR, cuenta por cuenta) va al pasivo, «Sobregiro bancario»;
--       · reclasif_pasivo_deudor: cualquier otra cuenta de PASIVO con saldo
--         DEUDOR (cuenta por cuenta; no una contra-cuenta) va al activo: el
--         préstamo del accionista (2900) a «Cuenta por cobrar al
--         accionista» (el Schedule L del 1120-S los separa: renglón 7 y
--         19), la nómina y los impuestos pagados de más a «Nómina e
--         impuestos pagados de más», lo demás a «Otros pasivos pagados de
--         más»;
--       · reclasif_activo_acreedor: cualquier otra cuenta de ACTIVO con saldo
--         ACREEDOR va al pasivo: 1130 a «Préstamo del accionista», lo demás a
--         «Otros pasivos circulantes».
-- Niveles: 'cuenta' y 'componente' (el detalle), 'linea' (el renglón),
-- 'seccion' (su subtotal) y 'total' (total activo, total pasivo, total
-- capital, pasivo más capital y 'cuadra', que es activo menos pasivo y
-- capital: SIEMPRE 0.00; la columna cuadra lo dice).
--   saldo            debe − haber a la fecha del corte (el del libro);
--   cifra            lo que se pinta: signo × saldo (el activo en positivo,
--                    el pasivo y el capital en positivo; una contra-cuenta,
--                    restando);
--   saldo_ajustado,  lo mismo «con ajustes posteriores» (f08, regla A): más
--   cifra_ajustada   los ajustes del CPA (ajuste_cpa) fechados DESPUÉS del
--                    corte que corrigen hasta este período (el balance al
--                    31-dic con lo que el CPA entrega en abril). Iguales a
--                    saldo y cifra si no hay; en 'hoy', siempre iguales. Las
--                    reclasificaciones y el resultado de la apertura se
--                    toman al corte.
-- «bajar» dice, por cada cifra, qué líneas del libro la suman (ver la
-- cabecera: una lista de filtros sobre v_libro; el resultado de la apertura
-- baja a v_qb_balanzas, la balanza con que se posteó).
-- ---------------------------------------------------------------------
drop view if exists public.v_balance_general cascade;
create view public.v_balance_general with (security_invoker = true) as
select c.periodo, c.tipo as periodo_tipo, c.corte, c.anio, x.*
  from public.v_cortes c
  cross join lateral (
    with l as materialized (
      -- Lo que cuenta al corte; y, en los cortes de un período (no en
      -- 'hoy'), los ajustes del CPA fechados después que corrigen hasta él
      -- (al_corte = false): van aparte, a las columnas «ajustadas».
      select v.cuenta, v.estado, v.seccion, v.linea, v.signo, v.contra, v.efectivo, v.monto, v.asiento_id, v.numero, v.ejercicio,
             v.proyecto_id, v.tercero_tipo, v.tercero_id, v.partida_tabla, v.partida_id, v.fecha <= c.corte as al_corte
        from public.v_libro v
       where v.fecha <= c.corte
          or (c.tipo in ('mes', 'apertura', 'anio') and v.tipo = 'ajuste_cpa'
              and case when c.tipo = 'anio' then v.ejercicio <= c.anio else v.efectivo_hasta <= c.corte end)
    ), pf as materialized (
      -- Con qué filtros se baja a esos ajustes posteriores (por FECHA: el
      -- período que corrige termina a más tardar el día del corte).
      select c.tipo in ('mes', 'apertura', 'anio') as hay,
             case when c.tipo = 'anio' then jsonb_build_object('tipo', 'ajuste_cpa', 'ejercicio_hasta', c.anio)
                  else jsonb_build_object('tipo', 'ajuste_cpa', 'efectivo_hasta_hasta', c.corte) end as filtros
    ), k as materialized (
      select (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'cxc')           as cxc,
             (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'retencion_cxc') as ret,
             (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'cxp')           as cxp
    ), cfg as materialized (
      select coalesce((select k.valor from public.estados_config k where k.clave = 'plegar_3200'), 'no') = 'si' as plegar
    ), ej as materialized (
      select e.anio, e.cerrado from public.v_ejercicios e
    ), apx as materialized (
      -- La apertura (su año y su día): el libro tiene resultados desde el día siguiente.
      select p.periodo, p.anio, p.hasta from public.periodos p where p.tipo = 'apertura' order by p.desde limit 1
    ), ap as materialized (
      -- El resultado de antes de la apertura en su año, según la balanza de
      -- QuickBooks con que fn_apertura la posteó (viva: si se reversó, 3900
      -- ya no lo trae): q = debe − haber de sus cuentas de resultados
      -- (negativo = utilidad). En los cortes desde el día de la apertura:
      -- los de su año lo ponen en el resultado del ejercicio; los de años
      -- siguientes, mientras ese año NO se cierre, en «ejercicios anteriores
      -- por cerrar» (con lo de octubre a diciembre del libro: el resultado
      -- de TODO 2026). Cerrado el año, los dos van dentro de utilidades
      -- retenidas y no hace falta moverlo. (Antes solo en su año: al
      -- 31-ene-2027 las utilidades retenidas saltaban de 10,000 a 49,000 y
      -- «por cerrar» decía 8,000, sin que se cerrara nada.)
      select apx.periodo, sum(b.saldo) as q, min(b.asiento_id::text) as asiento, min(b.numero) as numero,
             case when apx.anio = c.anio then 'resultado_ejercicio' else 'ejercicios_por_cerrar' end as destino
        from apx
        join public.v_qb_balanzas b on b.periodo = apx.periodo
       where b.fuente = 'apertura_balanza_qb' and b.vivo and b.cuenta_tipo not in ('activo', 'pasivo', 'capital')
         and c.corte >= apx.hasta
         and (apx.anio = c.anio
              or (apx.anio < c.anio and not coalesce((select e.cerrado from ej e where e.anio = apx.anio), false)))
       group by apx.periodo, apx.anio
      having sum(b.saldo) <> 0
    ), r as materialized (
      -- Las reclasificaciones de presentación, una fila por partida,
      -- proveedor o cuenta que va contra su renglón (al corte). comp: la
      -- reclasificación; su renglón de destino y el signo de ese renglón;
      -- filtros: con qué se baja a sus líneas.
      select 'reclasif_anticipos'::text as comp, 'pasivo_circulante'::text as d_seccion, 'anticipos_clientes'::text as d_linea,
             -1 as d_signo, y.seccion, y.linea, y.signo, sum(y.monto) as s, array_agg(distinct y.asiento_id) as ids,
             min(y.numero) as numero_min, y.filtros
        from (select l.*, jsonb_build_object('cuenta', l.cuenta)
                          || case when l.partida_tabla is null
                                  then jsonb_build_object('partida_tabla', null, 'proyecto_id', l.proyecto_id)
                                  else jsonb_build_object('partida_tabla', l.partida_tabla, 'partida_id', l.partida_id) end as filtros
                from l, k
               where l.al_corte and l.cuenta in (k.cxc, k.ret)) y
       group by y.seccion, y.linea, y.signo, y.filtros
      having sum(y.monto) < 0
      union all
      select 'reclasif_a_favor', 'activo_circulante', 'saldos_a_favor', 1, y.seccion, y.linea, y.signo, sum(y.monto),
             array_agg(distinct y.asiento_id), min(y.numero), y.filtros
        from (select l.*, case when l.linea = 'tarjetas' then jsonb_build_object('cuenta', l.cuenta)
                               else jsonb_build_object('cuenta', l.cuenta, 'tercero_tipo', l.tercero_tipo,
                                                       'tercero_id', l.tercero_id) end as filtros
                from l, k
               where l.al_corte and l.estado = 'balance'
                 and (l.cuenta = k.cxp or l.linea in ('retencion_por_pagar', 'tarjetas'))) y
       group by y.seccion, y.linea, y.signo, y.filtros
      having sum(y.monto) > 0
      union all
      select 'reclasif_sobregiro', 'pasivo_circulante', 'sobregiro_bancario', -1, l.seccion, l.linea, l.signo, sum(l.monto),
             array_agg(distinct l.asiento_id), min(l.numero), jsonb_build_object('cuenta', l.cuenta)
        from l
       where l.al_corte and l.efectivo
       group by l.seccion, l.linea, l.signo, l.cuenta
      having sum(l.monto) < 0
      union all
      -- Y TODA otra cuenta de activo o de pasivo con saldo contrario al suyo
      -- (no una contra-cuenta, que es así de por sí), cuenta por cuenta.
      -- Antes solo las tres de arriba: el préstamo del accionista (2900)
      -- deudor salía como pasivo NEGATIVO —es una cuenta por cobrar al
      -- accionista: en el 1120-S, otro renglón del Schedule L (el 7, no el
      -- 19)— y un 941 pagado de más restaba a los sueldos que se deben.
      --   · un pasivo deudor va al activo: 2900 a «Cuenta por cobrar al
      --     accionista»; nómina e impuestos, a «Nómina e impuestos pagados de
      --     más»; los demás, a «Otros pasivos pagados de más»;
      --   · un activo acreedor va al pasivo: 1130 a «Préstamo del
      --     accionista»; los demás, a «Otros pasivos circulantes».
      select 'reclasif_pasivo_deudor', case when l.linea = 'prestamo_accionista' then 'otros_activos' else 'activo_circulante' end,
             case when l.linea = 'prestamo_accionista' then 'accionista_por_cobrar'
                  when l.linea in ('nomina_por_pagar', 'impuestos_por_pagar') then 'impuestos_a_favor'
                  else 'otros_saldos_deudores' end,
             1, l.seccion, l.linea, l.signo, sum(l.monto), array_agg(distinct l.asiento_id), min(l.numero),
             jsonb_build_object('cuenta', l.cuenta)
        from l, k
       where l.al_corte and l.estado = 'balance' and l.seccion in ('pasivo_circulante', 'pasivo_largo_plazo') and not l.contra
         and not (l.cuenta = k.cxp or l.linea in ('retencion_por_pagar', 'tarjetas'))
       group by l.seccion, l.linea, l.signo, l.cuenta
      having sum(l.monto) > 0
      union all
      select 'reclasif_activo_acreedor', case when l.linea = 'accionista_por_cobrar' then 'pasivo_largo_plazo' else 'pasivo_circulante' end,
             case when l.linea = 'accionista_por_cobrar' then 'prestamo_accionista' else 'otros_pasivos' end,
             -1, l.seccion, l.linea, l.signo, sum(l.monto), array_agg(distinct l.asiento_id), min(l.numero),
             jsonb_build_object('cuenta', l.cuenta)
        from l, k
       where l.al_corte and l.estado = 'balance' and l.seccion in ('activo_circulante', 'activo_fijo', 'otros_activos')
         and not l.contra and not l.efectivo and l.cuenta not in (k.cxc, k.ret)
       group by l.seccion, l.linea, l.signo, l.cuenta
      having sum(l.monto) < 0
    ), d as materialized (
      -- El detalle: cada cuenta de balance…
      select 'cuenta'::text as nivel, l.seccion, l.linea, l.cuenta, null::text as componente, l.signo,
             coalesce(sum(l.monto) filter (where l.al_corte), 0)     as saldo,
             coalesce(sum(l.monto) filter (where not l.al_corte), 0) as post,
             count(distinct l.asiento_id) filter (where l.al_corte)  as asientos,
             min(l.asiento_id::text) filter (where l.al_corte)       as asiento_min,
             min(l.numero) filter (where l.al_corte)                 as numero_min,
             jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', l.signo,
                                                  'filtros', jsonb_build_object('cuenta', l.cuenta), 'hasta', c.corte::text)) as specs,
             case when bool_or(not l.al_corte)
                  then jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', l.signo,
                                                            'filtros', jsonb_build_object('cuenta', l.cuenta) || (select pf.filtros from pf),
                                                            'desde', (c.corte + 1)::text))
                  else '[]'::jsonb end as specs_post
        from l
       where l.estado = 'balance'
       group by l.seccion, l.linea, l.cuenta, l.signo
      union all
      -- …los resultados, por ejercicio: el del corte, los cerrados y los
      -- por cerrar…
      select 'componente', 'capital', r2.linea_c, null, r2.componente, -1::smallint,
             coalesce(sum(r2.monto) filter (where r2.al_corte), 0), coalesce(sum(r2.monto) filter (where not r2.al_corte), 0),
             count(distinct r2.asiento_id) filter (where r2.al_corte), min(r2.asiento_id::text) filter (where r2.al_corte),
             min(r2.numero) filter (where r2.al_corte),
             case when bool_or(r2.al_corte)
                  then jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                         'filtros', jsonb_build_object('estado', 'resultados',
                                                       'ejercicio', jsonb_agg(distinct r2.ejercicio) filter (where r2.al_corte)),
                         'hasta', c.corte::text))
                  else '[]'::jsonb end,
             case when bool_or(not r2.al_corte)
                  then jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                         'filtros', jsonb_build_object('estado', 'resultados',
                                                       'ejercicio', jsonb_agg(distinct r2.ejercicio) filter (where not r2.al_corte))
                                    || (select pf.filtros from pf),
                         'desde', (c.corte + 1)::text))
                  else '[]'::jsonb end
        from (select l.*,
                     case when l.ejercicio = c.anio then 'resultado'
                          when coalesce(ej.cerrado, false) then 'arrastre'
                          else 'por_cerrar' end as componente,
                     case when l.ejercicio = c.anio then 'resultado_ejercicio'
                          when coalesce(ej.cerrado, false) then 'utilidades_retenidas'
                          else 'ejercicios_por_cerrar' end as linea_c
                from l left join ej on ej.anio = l.ejercicio
               where l.estado = 'resultados') r2
       group by r2.linea_c, r2.componente
      union all
      -- Las distribuciones de los ejercicios cerrados, plegadas a
      -- utilidades retenidas (solo si el CPA lo pidió): salen de una línea y
      -- entran en la otra.
      select 'componente', 'capital', z.linea, null, 'plegado_3200', -1::smallint,
             z.s * sum(l.monto), 0, count(distinct l.asiento_id), min(l.asiento_id::text), min(l.numero),
             jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -z.s,
                                                  'filtros', jsonb_build_object('linea', 'distribuciones',
                                                                                'ejercicio', jsonb_agg(distinct l.ejercicio)),
                                                  'hasta', c.corte::text)),
             '[]'::jsonb
        from l
        join ej on ej.anio = l.ejercicio and ej.cerrado
        cross join cfg
        cross join (values ('utilidades_retenidas', 1), ('distribuciones', -1)) as z(linea, s)
       where l.al_corte and cfg.plegar and l.estado = 'balance' and l.linea = 'distribuciones'
       group by z.linea, z.s
      union all
      -- El resultado de antes de la apertura: sale de utilidades retenidas y
      -- entra en el resultado del ejercicio (en su año) o en «ejercicios
      -- anteriores por cerrar» (después, mientras su año no se cierre).
      select 'componente', 'capital', z.linea, null, 'resultado_apertura', -1::smallint,
             z.s * ap.q, 0, 1::bigint, ap.asiento, ap.numero,
             jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', -z.s,
                                                  'filtros', jsonb_build_object('periodo', ap.periodo, 'fuente', 'apertura_balanza_qb',
                                                                                'vivo', true,
                                                                                'cuenta_tipo_no', jsonb_build_array('activo', 'pasivo', 'capital')))),
             '[]'::jsonb
        from ap
        cross join lateral (values ('utilidades_retenidas', -1), (ap.destino, 1)) as z(linea, s)
      union all
      -- Las reclasificaciones: salen de su renglón…
      select 'componente', r.seccion, r.linea, null, r.comp, r.signo, -sum(r.s), 0,
             (select count(distinct u) from r x, unnest(x.ids) u where x.comp = r.comp and x.seccion = r.seccion and x.linea = r.linea),
             (select min(u::text) from r x, unnest(x.ids) u where x.comp = r.comp and x.seccion = r.seccion and x.linea = r.linea),
             min(r.numero_min),
             jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -r.signo, 'filtros', r.filtros,
                                          'hasta', c.corte::text) order by r.filtros::text),
             '[]'::jsonb
        from r
       group by r.comp, r.seccion, r.linea, r.signo
      union all
      -- …y entran en el otro.
      select 'componente', r.d_seccion, r.d_linea, null, r.comp, r.d_signo::smallint, sum(r.s), 0,
             (select count(distinct u) from r x, unnest(x.ids) u where x.comp = r.comp),
             (select min(u::text) from r x, unnest(x.ids) u where x.comp = r.comp),
             min(r.numero_min),
             jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', r.d_signo, 'filtros', r.filtros,
                                          'hasta', c.corte::text) order by r.filtros::text),
             '[]'::jsonb
        from r
       group by r.comp, r.d_seccion, r.d_linea, r.d_signo
    ), dm as materialized (
      -- cifra = signo × saldo: la misma lista de líneas, con el signo de la
      -- cifra o con el del saldo (debe − haber); y las «ajustadas», con los
      -- ajustes posteriores.
      select d.*,
             d.specs as b_cifra,
             (select coalesce(jsonb_agg(jsonb_set(e.v, '{signo}', to_jsonb((e.v->>'signo')::int * d.signo)) order by e.o), '[]'::jsonb)
                from jsonb_array_elements(d.specs) with ordinality as e(v, o)) as b_saldo,
             d.specs || d.specs_post as b_cifra_aj,
             (select coalesce(jsonb_agg(jsonb_set(e.v, '{signo}', to_jsonb((e.v->>'signo')::int * d.signo)) order by e.o), '[]'::jsonb)
                from jsonb_array_elements(d.specs || d.specs_post) with ordinality as e(v, o)) as b_saldo_aj,
             ll.orden as linea_orden, ls.orden as seccion_orden,
             coalesce(m.orden, case d.componente when 'arrastre' then 1 when 'plegado_3200' then 2 when 'resultado_apertura' then 3
                                                 when 'reclasif_anticipos' then 4 when 'reclasif_a_favor' then 5
                                                 when 'reclasif_sobregiro' then 6 when 'reclasif_pasivo_deudor' then 7
                                                 when 'reclasif_activo_acreedor' then 8 else 0 end) as orden,
             coalesce(m.etiqueta_es, case d.componente
               when 'arrastre'     then 'Resultados de ejercicios cerrados'
               when 'por_cerrar'   then 'Resultados de ejercicios anteriores por cerrar'
               when 'resultado'    then 'Resultado del ejercicio ' || c.anio
                                        || case when c.anio = apx.anio
                                                then ' desde el ' || to_char(apx.hasta + 1, 'DD-MM-YYYY') || ' (el libro)' else '' end
               when 'plegado_3200' then 'Distribuciones de ejercicios cerrados'
               when 'resultado_apertura' then
                 case when d.linea in ('resultado_ejercicio', 'ejercicios_por_cerrar')
                      then format('Resultado del 01-01-%s al %s según QuickBooks (la balanza de la apertura)', apx.anio,
                                  to_char(apx.hasta, 'DD-MM-YYYY'))
                      else format('Menos: el resultado del 01-01-%s al %s (va en %s)', apx.anio,
                                  to_char(apx.hasta, 'DD-MM-YYYY'),
                                  case when c.anio = apx.anio then 'el resultado del ejercicio'
                                       else 'los ejercicios anteriores por cerrar' end) end
               when 'reclasif_anticipos' then
                 case when d.linea = 'anticipos_clientes' then 'Anticipos y saldos a favor de clientes (sus partidas de cobrar)'
                      else 'Más: anticipos y saldos a favor de clientes (van al pasivo)' end
               when 'reclasif_a_favor' then
                 case when d.linea = 'saldos_a_favor' then 'Saldos a favor con proveedores y tarjetas'
                      else 'Más: saldos a favor con proveedores o tarjetas (van al activo)' end
               when 'reclasif_sobregiro' then
                 case when d.linea = 'sobregiro_bancario' then 'Sobregiro de las cuentas de efectivo en rojo'
                      else 'Más: cuentas de efectivo en rojo (van al pasivo, sobregiro)' end
               when 'reclasif_pasivo_deudor' then
                 case when d.seccion in ('pasivo_circulante', 'pasivo_largo_plazo')
                      then 'Más: saldos deudores de esta cuenta de pasivo (van al activo)'
                      when d.linea = 'accionista_por_cobrar' then 'Préstamo del accionista con saldo deudor: el accionista le debe a la empresa'
                      when d.linea = 'impuestos_a_favor' then 'Nómina e impuestos pagados de más (saldo deudor)'
                      else 'Pasivos con saldo deudor (pagados de más)' end
               when 'reclasif_activo_acreedor' then
                 case when d.seccion in ('activo_circulante', 'activo_fijo', 'otros_activos')
                      then 'Más: saldos acreedores de esta cuenta de activo (van al pasivo)'
                      when d.linea = 'prestamo_accionista' then 'Cuenta por cobrar al accionista con saldo acreedor: la empresa le debe'
                      else 'Activos con saldo acreedor' end
             end) as etiqueta_es,
             coalesce(m.etiqueta_en, case d.componente
               when 'arrastre'     then 'Closed-year results'
               when 'por_cerrar'   then 'Prior-year results not yet closed'
               when 'resultado'    then 'Net income for ' || c.anio
                                        || case when c.anio = apx.anio
                                                then ' since ' || to_char(apx.hasta + 1, 'YYYY-MM-DD') || ' (books)' else '' end
               when 'plegado_3200' then 'Closed-year distributions'
               when 'resultado_apertura' then
                 case when d.linea in ('resultado_ejercicio', 'ejercicios_por_cerrar')
                      then format('Net income %s-01-01 to %s per QuickBooks (opening trial balance)', apx.anio,
                                  to_char(apx.hasta, 'YYYY-MM-DD'))
                      else format('Less: net income %s-01-01 to %s (shown in %s)', apx.anio,
                                  to_char(apx.hasta, 'YYYY-MM-DD'),
                                  case when c.anio = apx.anio then 'net income for the year'
                                       else 'prior-year results not yet closed' end) end
               when 'reclasif_anticipos' then
                 case when d.linea = 'anticipos_clientes' then 'Customer deposits and credit balances (from receivables)'
                      else 'Add back: customer deposits and credit balances (shown as liabilities)' end
               when 'reclasif_a_favor' then
                 case when d.linea = 'saldos_a_favor' then 'Supplier and credit card debit balances'
                      else 'Add back: supplier or credit card debit balances (shown as assets)' end
               when 'reclasif_sobregiro' then
                 case when d.linea = 'sobregiro_bancario' then 'Overdrawn cash accounts'
                      else 'Add back: overdrawn cash accounts (shown as liabilities)' end
               when 'reclasif_pasivo_deudor' then
                 case when d.seccion in ('pasivo_circulante', 'pasivo_largo_plazo')
                      then 'Add back: debit balances of this liability (shown as assets)'
                      when d.linea = 'accionista_por_cobrar' then 'Shareholder loan with a debit balance: due from shareholder'
                      when d.linea = 'impuestos_a_favor' then 'Overpaid payroll and taxes (debit balances)'
                      else 'Liabilities with debit balances (overpaid)' end
               when 'reclasif_activo_acreedor' then
                 case when d.seccion in ('activo_circulante', 'activo_fijo', 'otros_activos')
                      then 'Add back: credit balances of this asset (shown as liabilities)'
                      when d.linea = 'prestamo_accionista' then 'Due from shareholder with a credit balance: owed to the shareholder'
                      else 'Assets with credit balances' end
             end) as etiqueta_en
        from d
        left join apx on true
        left join public.v_estados_mapeo m on m.cuenta = d.cuenta
        left join public.estados_lineas ll on ll.estado = 'balance' and ll.seccion = d.seccion and ll.linea = d.linea
        left join public.estados_lineas ls on ls.estado = 'balance' and ls.seccion = d.seccion and ls.linea = d.seccion
    ), tot as materialized (
      select sum(dm.signo * dm.saldo) filter (where dm.seccion in ('activo_circulante', 'activo_fijo', 'otros_activos')) as activo,
             sum(dm.signo * dm.saldo) filter (where dm.seccion in ('pasivo_circulante', 'pasivo_largo_plazo'))           as pasivo,
             sum(dm.signo * dm.saldo) filter (where dm.seccion = 'capital')                                             as capital,
             sum(dm.signo * (dm.saldo + dm.post))
               filter (where dm.seccion in ('activo_circulante', 'activo_fijo', 'otros_activos'))                       as activo_aj,
             sum(dm.signo * (dm.saldo + dm.post)) filter (where dm.seccion in ('pasivo_circulante', 'pasivo_largo_plazo')) as pasivo_aj,
             sum(dm.signo * (dm.saldo + dm.post)) filter (where dm.seccion = 'capital')                                 as capital_aj,
             (select count(distinct l.asiento_id) from l where l.al_corte) as asientos,
             -- Los componentes del activo y del pasivo (las reclasificaciones):
             -- el total baja también a ellos.
             (select coalesce(jsonb_agg(e.v order by x.orden, e.o), '[]'::jsonb)
                from dm x, jsonb_array_elements(x.b_cifra) with ordinality as e(v, o)
               where x.nivel = 'componente' and x.seccion in ('activo_circulante', 'activo_fijo', 'otros_activos')) as comp_activo,
             (select coalesce(jsonb_agg(e.v order by x.orden, e.o), '[]'::jsonb)
                from dm x, jsonb_array_elements(x.b_cifra) with ordinality as e(v, o)
               where x.nivel = 'componente' and x.seccion in ('pasivo_circulante', 'pasivo_largo_plazo')) as comp_pasivo
        from dm
    ), tp as materialized (
      -- Los ajustes posteriores de los totales, por familia de cuentas.
      select case when pf.hay then jsonb_build_array(
                    jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'desde', (c.corte + 1)::text,
                      'filtros', jsonb_build_object('estado', 'balance',
                                   'seccion', jsonb_build_array('activo_circulante', 'activo_fijo', 'otros_activos')) || pf.filtros))
                  else '[]'::jsonb end as activo,
             case when pf.hay then jsonb_build_array(
                    jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'desde', (c.corte + 1)::text,
                      'filtros', jsonb_build_object('estado', 'balance',
                                   'seccion', jsonb_build_array('pasivo_circulante', 'pasivo_largo_plazo')) || pf.filtros))
                  else '[]'::jsonb end as pasivo,
             case when pf.hay then jsonb_build_array(
                    jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'desde', (c.corte + 1)::text,
                      'filtros', jsonb_build_object('estado', 'balance', 'seccion', 'capital') || pf.filtros),
                    jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'desde', (c.corte + 1)::text,
                      'filtros', jsonb_build_object('estado', 'resultados') || pf.filtros))
                  else '[]'::jsonb end as capital,
             case when pf.hay then jsonb_build_array(
                    jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'desde', (c.corte + 1)::text,
                      'filtros', pf.filtros))
                  else '[]'::jsonb end as todo
        from pf
    )
    select dm.nivel, dm.seccion, dm.seccion_orden, dm.linea, dm.linea_orden, dm.orden, dm.cuenta, dm.componente,
           dm.etiqueta_es, dm.etiqueta_en, dm.saldo::numeric(14,2) as saldo, (dm.signo * dm.saldo)::numeric(14,2) as cifra,
           (dm.saldo + dm.post)::numeric(14,2) as saldo_ajustado, (dm.signo * (dm.saldo + dm.post))::numeric(14,2) as cifra_ajustada,
           dm.asientos, case when dm.asientos = 1 then dm.asiento_min::uuid end as asiento_id,
           case when dm.asientos = 1 then dm.numero_min end as numero, null::boolean as cuadra,
           jsonb_build_object('saldo', dm.b_saldo, 'cifra', dm.b_cifra, 'saldo_ajustado', dm.b_saldo_aj,
                              'cifra_ajustada', dm.b_cifra_aj) as bajar
      from dm
    union all
    -- El renglón: la suma de su detalle (y baja a todas sus piezas).
    select 'linea', g.seccion, g.seccion_orden, g.linea, g.linea_orden, g.linea_orden, null, null, g.etiqueta_es, g.etiqueta_en,
           g.saldo::numeric(14,2), g.cifra::numeric(14,2), g.saldo_aj::numeric(14,2), g.cifra_aj::numeric(14,2),
           null::bigint, null, null, null,
           jsonb_build_object(
             'saldo', (select coalesce(jsonb_agg(e.v order by x.orden, x.cuenta, x.componente, e.o), '[]'::jsonb)
                         from dm x, jsonb_array_elements(x.b_saldo) with ordinality as e(v, o)
                        where x.seccion = g.seccion and x.linea = g.linea),
             'cifra', (select coalesce(jsonb_agg(e.v order by x.orden, x.cuenta, x.componente, e.o), '[]'::jsonb)
                         from dm x, jsonb_array_elements(x.b_cifra) with ordinality as e(v, o)
                        where x.seccion = g.seccion and x.linea = g.linea),
             'saldo_ajustado', (select coalesce(jsonb_agg(e.v order by x.orden, x.cuenta, x.componente, e.o), '[]'::jsonb)
                                  from dm x, jsonb_array_elements(x.b_saldo_aj) with ordinality as e(v, o)
                                 where x.seccion = g.seccion and x.linea = g.linea),
             'cifra_ajustada', (select coalesce(jsonb_agg(e.v order by x.orden, x.cuenta, x.componente, e.o), '[]'::jsonb)
                                  from dm x, jsonb_array_elements(x.b_cifra_aj) with ordinality as e(v, o)
                                 where x.seccion = g.seccion and x.linea = g.linea))
      from (select dm.seccion, dm.linea, min(dm.seccion_orden) as seccion_orden, min(dm.linea_orden) as linea_orden,
                   min(ll.etiqueta_es) as etiqueta_es, min(ll.etiqueta_en) as etiqueta_en,
                   sum(dm.saldo) as saldo, sum(dm.signo * dm.saldo) as cifra,
                   sum(dm.saldo + dm.post) as saldo_aj, sum(dm.signo * (dm.saldo + dm.post)) as cifra_aj
              from dm
              left join public.estados_lineas ll on ll.estado = 'balance' and ll.seccion = dm.seccion and ll.linea = dm.linea
             group by dm.seccion, dm.linea) g
    union all
    -- La sección: su subtotal.
    select 'seccion', g.seccion, g.seccion_orden, g.seccion, g.seccion_orden, g.seccion_orden, null, null, g.etiqueta_es,
           g.etiqueta_en, g.saldo::numeric(14,2), g.cifra::numeric(14,2), g.saldo_aj::numeric(14,2), g.cifra_aj::numeric(14,2),
           null::bigint, null, null, null,
           jsonb_build_object(
             'saldo', (select coalesce(jsonb_agg(e.v order by x.linea_orden, x.orden, x.cuenta, x.componente, e.o), '[]'::jsonb)
                         from dm x, jsonb_array_elements(x.b_saldo) with ordinality as e(v, o) where x.seccion = g.seccion),
             'cifra', (select coalesce(jsonb_agg(e.v order by x.linea_orden, x.orden, x.cuenta, x.componente, e.o), '[]'::jsonb)
                         from dm x, jsonb_array_elements(x.b_cifra) with ordinality as e(v, o) where x.seccion = g.seccion),
             'saldo_ajustado', (select coalesce(jsonb_agg(e.v order by x.linea_orden, x.orden, x.cuenta, x.componente, e.o), '[]'::jsonb)
                                  from dm x, jsonb_array_elements(x.b_saldo_aj) with ordinality as e(v, o) where x.seccion = g.seccion),
             'cifra_ajustada', (select coalesce(jsonb_agg(e.v order by x.linea_orden, x.orden, x.cuenta, x.componente, e.o), '[]'::jsonb)
                                  from dm x, jsonb_array_elements(x.b_cifra_aj) with ordinality as e(v, o) where x.seccion = g.seccion))
      from (select dm.seccion, min(dm.seccion_orden) as seccion_orden, min(ls.etiqueta_es) as etiqueta_es,
                   min(ls.etiqueta_en) as etiqueta_en, sum(dm.saldo) as saldo, sum(dm.signo * dm.saldo) as cifra,
                   sum(dm.saldo + dm.post) as saldo_aj, sum(dm.signo * (dm.saldo + dm.post)) as cifra_aj
              from dm
              left join public.estados_lineas ls on ls.estado = 'balance' and ls.seccion = dm.seccion and ls.linea = dm.seccion
             group by dm.seccion) g
    union all
    -- Los totales.
    select 'total', 'totales', 9000, t.linea, lt.orden, lt.orden, null, null, lt.etiqueta_es, lt.etiqueta_en,
           null::numeric(14,2), t.cifra::numeric(14,2), null::numeric(14,2), t.cifra_aj::numeric(14,2), tot.asientos, null, null,
           case when t.linea = 'cuadra' then coalesce(t.cifra, 0) = 0 and coalesce(t.cifra_aj, 0) = 0 end,
           jsonb_build_object('cifra', t.bajar, 'cifra_ajustada', t.bajar || t.bajar_post)
      from tot
      cross join tp
      cross join lateral (values
        ('total_activo', coalesce(tot.activo, 0), coalesce(tot.activo_aj, 0),
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'hasta', c.corte::text,
           'filtros', jsonb_build_object('estado', 'balance',
                                         'seccion', jsonb_build_array('activo_circulante', 'activo_fijo', 'otros_activos'))))
         || tot.comp_activo,
         tp.activo),
        ('total_pasivo', coalesce(tot.pasivo, 0), coalesce(tot.pasivo_aj, 0),
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
           'filtros', jsonb_build_object('estado', 'balance',
                                         'seccion', jsonb_build_array('pasivo_circulante', 'pasivo_largo_plazo'))))
         || tot.comp_pasivo,
         tp.pasivo),
        ('total_capital', coalesce(tot.capital, 0), coalesce(tot.capital_aj, 0),
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
                                              'filtros', jsonb_build_object('estado', 'balance', 'seccion', 'capital')),
                           jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
                                              'filtros', jsonb_build_object('estado', 'resultados'))),
         tp.capital),
        ('pasivo_mas_capital', coalesce(tot.pasivo, 0) + coalesce(tot.capital, 0), coalesce(tot.pasivo_aj, 0) + coalesce(tot.capital_aj, 0),
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
           'filtros', jsonb_build_object('estado', 'balance',
                                         'seccion', jsonb_build_array('pasivo_circulante', 'pasivo_largo_plazo', 'capital'))),
                           jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
                                              'filtros', jsonb_build_object('estado', 'resultados')))
         || tot.comp_pasivo,
         tp.pasivo || tp.capital),
        ('cuadra', coalesce(tot.activo, 0) - coalesce(tot.pasivo, 0) - coalesce(tot.capital, 0),
         coalesce(tot.activo_aj, 0) - coalesce(tot.pasivo_aj, 0) - coalesce(tot.capital_aj, 0),
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'hasta', c.corte::text,
                                              'filtros', '{}'::jsonb)),
         tp.todo)
      ) as t(linea, cifra, cifra_aj, bajar, bajar_post)
      left join public.estados_lineas lt on lt.estado = 'balance' and lt.seccion = 'totales' and lt.linea = t.linea
     where exists (select 1 from dm)
  ) x;


-- ---------------------------------------------------------------------
-- 4.3 · v_resultados — el estado de resultados de cada período (un mes, o
-- el año entero en el período de tipo 'anio'), con:
--   mes           lo del período: las líneas de resultados de su ejercicio
--                 fechadas dentro del período (en el período 'anio', el
--                 año entero);
--   mes_anterior  lo mismo del período anterior (el mes anterior; en el
--                 año, el año anterior): para «mes contra mes». NULO si ese
--                 período empieza antes del libro (el libro tiene
--                 resultados desde el día siguiente a la apertura: lo de
--                 antes está en QuickBooks): septiembre de 2026 no es 0.00,
--                 es «sin dato en el libro»; y el año 2026 (que en el libro
--                 empieza el 1-oct) no es el año anterior de 2027;
--   variacion     mes − mes_anterior, y variacion_pct = variacion sobre
--                 |mes_anterior| (con el signo del estado: si los ingresos
--                 bajan, sale negativo); nulos si no hay mes anterior;
--   acumulado     lo que va del año (YTD): de enero —o del primer día del
--                 libro, acumulado_desde, en el año de la apertura— al
--                 último día del período, de su ejercicio;
--   posteriores   los ajustes del CPA (ajuste_cpa) fechados DESPUÉS del
--                 período que corrigen su año hasta ese período (el cierre
--                 del CPA en enero corrigiendo diciembre): no cambian el
--                 acumulado de la fecha, pero el año «con ajustes» es
--                 acumulado + posteriores (acumulado_ajustado);
-- con el signo del estado (cifra = signo × (debe − haber)): los ingresos y
-- los costos en positivo. Un ajuste de un ejercicio ANTERIOR fechado en
-- este período no entra aquí (c2: no cae en el resultado de este año); en
-- el balance va dentro de utilidades retenidas o de «por cerrar», y en el
-- flujo indirecto, en su renglón.
-- Niveles: 'cuenta', 'linea' (solo si Edgar agrupó cuentas en un renglón
-- propio), 'seccion' (ingresos, costo, gastos, otros ingresos, otros
-- gastos) y 'total' (utilidad bruta, de operación y neta).
-- Sin ninguna línea de resultados en el año (la apertura, o un año sin
-- asientos), 0 filas.
-- ---------------------------------------------------------------------
drop view if exists public.v_resultados cascade;
create view public.v_resultados with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.desde, p.hasta, p.anio, x.*
  from public.periodos p
  cross join lateral (
    with k as materialized (
      -- Los límites: el período, el anterior y el año; y el primer día con
      -- resultados en el libro (el siguiente a la apertura).
      select y.*, y.ant_desde >= y.libro_desde as hay_ant,
             greatest(make_date(p.anio, 1, 1), y.libro_desde) as acum_desde
        from (select case when p.tipo = 'anio' then make_date(p.anio - 1, 1, 1)
                          else (p.desde - interval '1 month')::date end                     as ant_desde,
                     p.desde - 1                                                            as ant_hasta,
                     case when p.tipo = 'anio' then p.anio - 1
                          else extract(year from (p.desde - interval '1 month'))::int end   as ant_anio,
                     make_date(p.anio, 1, 1)                                                as anio_desde,
                     coalesce((select pa.hasta + 1 from public.periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1),
                              (select min(pm.desde) from public.periodos pm))               as libro_desde) y
    ), l as materialized (
      select v.cuenta, v.seccion, v.linea, v.signo, v.monto, v.asiento_id, v.numero, v.fecha, v.ejercicio,
             v.periodo_efectivo,
             (v.ejercicio = p.anio and v.fecha between p.desde and p.hasta)                           as en_mes,
             (v.ejercicio = k.ant_anio and v.fecha between k.ant_desde and k.ant_hasta)               as en_ant,
             (v.ejercicio = p.anio and v.fecha between k.anio_desde and p.hasta)                      as en_acum,
             -- (Por FECHA: el período que corrige termina a más tardar el
             -- último día de este; un ajuste al AÑO 2026 es del 31-dic, no
             -- de octubre.)
             (v.ejercicio = p.anio and v.fecha > p.hasta and v.tipo = 'ajuste_cpa'
              and (p.tipo = 'anio' or v.efectivo_hasta <= p.hasta))                                  as en_post
        from public.v_libro v, k
       where v.estado = 'resultados'
         and v.ejercicio in (p.anio, k.ant_anio)
    ), c as materialized (
      select l.seccion, l.linea, l.cuenta, l.signo,
             coalesce(sum(l.monto) filter (where l.en_mes), 0)  as s_mes,
             coalesce(sum(l.monto) filter (where l.en_ant), 0)  as s_ant,
             coalesce(sum(l.monto) filter (where l.en_acum), 0) as s_acum,
             coalesce(sum(l.monto) filter (where l.en_post), 0) as s_post,
             count(distinct l.asiento_id) filter (where l.en_mes) as asientos,
             min(l.asiento_id::text) filter (where l.en_mes)       as asiento_min,
             min(l.numero) filter (where l.en_mes)                 as numero_min
        from l
       where l.en_mes or l.en_ant or l.en_acum or l.en_post
       group by l.seccion, l.linea, l.cuenta, l.signo
    ), cm as materialized (
      select c.*, m.orden, m.etiqueta_es, m.etiqueta_en, coalesce(ls.orden, 0) as seccion_orden,
             coalesce(ll.orden, 0) as linea_orden, ll.etiqueta_es as linea_es, ll.etiqueta_en as linea_en,
             ls.etiqueta_es as seccion_es, ls.etiqueta_en as seccion_en
        from c
        join public.v_estados_mapeo m on m.cuenta = c.cuenta
        left join public.estados_lineas ls on ls.estado = 'resultados' and ls.seccion = c.seccion and ls.linea = c.seccion
        left join public.estados_lineas ll on ll.estado = 'resultados' and ll.seccion = c.seccion and ll.linea = c.linea
    ), g as materialized (
      -- Una fila por cifra que se pinta: la cuenta, el renglón agrupado, la
      -- sección y las utilidades. filtros: con qué líneas de v_libro se
      -- baja (el período lo ponen desde y hasta).
      select 'cuenta'::text as nivel, cm.seccion, cm.seccion_orden, cm.linea, cm.linea_orden, cm.orden, cm.cuenta,
             cm.etiqueta_es, cm.etiqueta_en, cm.signo, cm.s_mes, cm.s_ant, cm.s_acum, cm.s_post, cm.asientos,
             cm.asiento_min, cm.numero_min, jsonb_build_object('cuenta', cm.cuenta) as filtros
        from cm
      union all
      select 'linea', cm.seccion, min(cm.seccion_orden), cm.linea, min(cm.linea_orden), min(cm.linea_orden), null,
             min(cm.linea_es), min(cm.linea_en), min(cm.signo), sum(cm.s_mes), sum(cm.s_ant), sum(cm.s_acum), sum(cm.s_post),
             null, null, null, jsonb_build_object('seccion', cm.seccion, 'linea', cm.linea)
        from cm
       where cm.linea <> cm.seccion
       group by cm.seccion, cm.linea
      union all
      select 'seccion', cm.seccion, min(cm.seccion_orden), cm.seccion, min(cm.seccion_orden), min(cm.seccion_orden), null,
             min(cm.seccion_es), min(cm.seccion_en), min(cm.signo), sum(cm.s_mes), sum(cm.s_ant), sum(cm.s_acum),
             sum(cm.s_post), null, null, null, jsonb_build_object('seccion', cm.seccion)
        from cm
       group by cm.seccion
      union all
      select 'total', 'totales', 9000, t.linea, lt.orden, lt.orden, null, lt.etiqueta_es, lt.etiqueta_en, -1::smallint,
             coalesce(sum(cm.s_mes), 0), coalesce(sum(cm.s_ant), 0), coalesce(sum(cm.s_acum), 0), coalesce(sum(cm.s_post), 0),
             null, null, null, jsonb_build_object('seccion', to_jsonb(t.secciones))
        from (values ('utilidad_bruta',     array['ingresos', 'costo']),
                     ('utilidad_operacion', array['ingresos', 'costo', 'gastos']),
                     ('utilidad_neta',      array['ingresos', 'costo', 'gastos', 'otros_ingresos', 'otros_gastos'])) as t(linea, secciones)
        left join cm on cm.seccion = any (t.secciones)
        left join public.estados_lineas lt on lt.estado = 'resultados' and lt.seccion = 'totales' and lt.linea = t.linea
       where exists (select 1 from cm)
       group by t.linea, t.secciones, lt.orden, lt.etiqueta_es, lt.etiqueta_en
    )
    select g.nivel, g.seccion, g.seccion_orden, g.linea, g.linea_orden, g.orden, g.cuenta, g.etiqueta_es, g.etiqueta_en,
           (g.signo * g.s_mes)::numeric(14,2)                        as mes,
           (case when k.hay_ant then g.signo * g.s_ant end)::numeric(14,2) as mes_anterior,
           (case when k.hay_ant then g.signo * (g.s_mes - g.s_ant) end)::numeric(14,2) as variacion,
           -- variacion sobre |mes_anterior|: con el signo del estado (una
           -- venta que baja, en negativo; una pérdida que pasa a ganancia, en
           -- positivo).
           case when k.hay_ant and g.s_ant <> 0 then round(100 * g.signo * (g.s_mes - g.s_ant) / abs(g.s_ant), 1) end as variacion_pct,
           (g.signo * g.s_acum)::numeric(14,2)                       as acumulado,
           k.acum_desde                                              as acumulado_desde,
           (g.signo * g.s_post)::numeric(14,2)                       as posteriores,
           (g.signo * (g.s_acum + g.s_post))::numeric(14,2)          as acumulado_ajustado,
           g.asientos,
           case when g.asientos = 1 then g.asiento_min::uuid end     as asiento_id,
           case when g.asientos = 1 then g.numero_min end            as numero,
           jsonb_build_object(
             'mes',          jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', g.signo,
                               'filtros', g.filtros || jsonb_build_object('estado', 'resultados', 'ejercicio', p.anio),
                               'desde', p.desde::text, 'hasta', p.hasta::text)),
             'mes_anterior', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', g.signo,
                               'filtros', g.filtros || jsonb_build_object('estado', 'resultados', 'ejercicio', k.ant_anio),
                               'desde', k.ant_desde::text, 'hasta', k.ant_hasta::text)),
             'variacion',    jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', g.signo,
                               'filtros', g.filtros || jsonb_build_object('estado', 'resultados', 'ejercicio', p.anio),
                               'desde', p.desde::text, 'hasta', p.hasta::text),
                                               jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -g.signo,
                               'filtros', g.filtros || jsonb_build_object('estado', 'resultados', 'ejercicio', k.ant_anio),
                               'desde', k.ant_desde::text, 'hasta', k.ant_hasta::text)),
             'acumulado',    jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', g.signo,
                               'filtros', g.filtros || jsonb_build_object('estado', 'resultados', 'ejercicio', p.anio),
                               'desde', k.anio_desde::text, 'hasta', p.hasta::text)),
             'posteriores',  jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', g.signo,
                               'filtros', g.filtros || jsonb_build_object('estado', 'resultados', 'ejercicio', p.anio,
                                                                          'tipo', 'ajuste_cpa')
                                          || case when p.tipo = 'anio' then '{}'::jsonb
                                                  else jsonb_build_object('efectivo_hasta_hasta', p.hasta) end,
                               'desde', (p.hasta + 1)::text)),
             'acumulado_ajustado', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', g.signo,
                               'filtros', g.filtros || jsonb_build_object('estado', 'resultados', 'ejercicio', p.anio),
                               'desde', k.anio_desde::text, 'hasta', p.hasta::text),
                                                     jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', g.signo,
                               'filtros', g.filtros || jsonb_build_object('estado', 'resultados', 'ejercicio', p.anio,
                                                                          'tipo', 'ajuste_cpa')
                                          || case when p.tipo = 'anio' then '{}'::jsonb
                                                  else jsonb_build_object('efectivo_hasta_hasta', p.hasta) end,
                               'desde', (p.hasta + 1)::text))) as bajar
      from g, k
  ) x;


-- ---------------------------------------------------------------------
-- 4.4 · El flujo de caja, por los dos métodos, sobre las mismas PIEZAS.
-- v_flujo_lineas — cada línea del libro que NO es dinero, en piezas. Una
-- pieza dice cuánto explica del dinero (importe) y a qué renglón va en
-- cada método (linea_directo, linea_indirecto; nulo = no va en ese
-- método):
--   importe        en la pieza base, −monto: una cuenta por cobrar que baja
--                  es dinero que entró;
--   toca_efectivo  su asiento mueve dinero (tiene una línea de una cuenta de
--                  efectivo, las 10xx);
--   pieza          'linea', la base: UNA por línea (las demás son
--                  reclasificaciones que se anulan entre sí):
--     · en un asiento que mueve dinero, el renglón de su cuenta en cada
--       método (el cobro de una factura: «cobros de clientes» /
--       «cuentas por cobrar»; el pago de una tarjeta: «tarjetas»); la
--       apertura, en 'ajustes'. En la VENTA de un activo (un asiento que
--       abona una cuenta de propiedad y equipo), la depreciación acumulada
--       que se da de baja va con el activo, a inversión;
--     · en un asiento SIN dinero, solo el indirecto: el resultado
--       ('resultado', o 'resultado_anteriores' si es de otro año) y el
--       cambio de cada saldo de operación (la depreciación contra 1590, una
--       compra a crédito), que suman cero. Pero si el asiento sin dinero
--       toca una cuenta de inversión, de financiamiento o de ajustes (un
--       activo comprado con tarjeta o con préstamo, una distribución sin
--       dinero, un ajuste a 3900), sus líneas de balance NO entran al
--       flujo: van al bloque 'sin_dinero', que se revela y no suma (ASC
--       230), igual en los dos métodos ('sd_inversion',
--       'sd_financiamiento', 'sd_ajustes' y su contrapartida,
--       'sd_contrapartida');
--   'sin_dinero_en_resultado'  en el indirecto, la parte de la utilidad
--       que no fue dinero de operación: lo que un asiento sin dinero de
--       inversión o financiamiento movió en resultados (un gasto
--       reclasificado a distribuciones) va de vuelta en 'no_monetario'; y
--       la ganancia o pérdida en venta de un activo (la cuenta de
--       resultados cuyo renglón del directo es de inversión: 4920), en
--       'ganancia_venta_activos';
--   'resultado_a_inversion' (o '…_a_financiamiento')  y esa ganancia entra,
--       en el indirecto, en el renglón de inversión donde la pone el
--       directo: así lo cobrado por el activo sale en inversión en los dos;
--   'tarjeta_paga' / 'tarjeta_compro'  el pago de una tarjeta que financió,
--       sin dinero, un activo (o una distribución) se clasifica por lo que
--       compró: la parte del pago que salda esos cargos (los más viejos
--       primero, FIFO, cargo por cargo de cada tarjeta) sale de «tarjetas»
--       y entra en el renglón de lo comprado, en los dos métodos. (No se
--       siguen así un activo a crédito de un proveedor, 2010, ni la parte
--       a tarjeta de un activo pagado en parte con dinero EN EL MISMO
--       asiento: su pago sale en operación. Si pasa, se reclasifica con un
--       asiento, o se postea la compra en dos.)
--   'cubierto_sin_dinero' / 'cubierto_se_revela'  un activo comprado con
--       préstamo (o aportación) y enganche EN EL MISMO asiento: la parte que
--       pagó el préstamo sin pasar por el banco (el menor de lo invertido y
--       lo financiado) sale de inversión y de financiamiento y se revela en
--       el bloque sin dinero, en los dos métodos (ASC 230-10-50-3); igual al
--       revés, en la venta de un activo cuyo comprador liquida el préstamo.
--       Así el estado no depende de cómo se partió el asiento.
--   seccion_directo, seccion_indirecto  la sección de cada renglón.
-- POR QUÉ CUADRAN LOS DOS MÉTODOS, SECCIÓN POR SECCIÓN, sin prorratear un
-- centavo: cada asiento suma cero, así que en cada asiento lo que se movió
-- en dinero es −(la suma de sus líneas que no son dinero). El directo suma
-- esas piezas; el indirecto, las mismas —cada cuenta de balance en la
-- MISMA sección que en el directo: la guarda del mapeo lo exige— más las
-- de los asientos sin dinero, que suman cero en operación o se van al
-- bloque sin dinero.
-- El dinero que pasa de un banco a otro (1010 → 1030) no tiene piezas: no
-- cambia el efectivo.
-- ---------------------------------------------------------------------
drop view if exists public.v_flujo_lineas cascade;
create view public.v_flujo_lineas with (security_invoker = true) as
with el as materialized (
  -- Los renglones de los dos flujos y su sección.
  select l.estado, l.linea, l.seccion from public.estados_lineas l
   where l.estado in ('flujo_directo', 'flujo_indirecto') and l.seccion <> 'totales'
), mp as materialized (
  select * from public.v_estados_mapeo
), tl as materialized (
  -- Las líneas de las TARJETAS (el renglón 'tarjetas' del balance), toda su
  -- historia, en el orden del libro, con lo cargado (cc) y lo pagado (cp)
  -- acumulado hasta cada una: la cola de cada tarjeta.
  select al.asiento_id, al.orden, al.cuenta, al.monto,
         sum(greatest(-al.monto, 0)) over w as cc, sum(greatest(al.monto, 0)) over w as cp
    from public.asiento_lineas al
    join public.asientos a on a.id = al.asiento_id
   where al.cuenta in (select mp.cuenta from mp where mp.estado = 'balance' and mp.linea = 'tarjetas' and not mp.efectivo)
  window w as (partition by al.cuenta order by a.fecha_contable, a.cadena_pos, al.orden
               rows between unbounded preceding and current row)
), ta as materialized (
  -- Los asientos de esas líneas: si mueven dinero, y cuánto cargaron.
  select al.asiento_id, bool_or(mp.efectivo) as toca, coalesce(sum(al.monto) filter (where al.monto > 0), 0) as debe
    from public.asiento_lineas al
    join mp on mp.cuenta = al.cuenta
   where al.asiento_id in (select tl.asiento_id from tl)
   group by al.asiento_id
), cg as materialized (
  -- Los cargos a tarjeta de un asiento SIN dinero que compró algo de
  -- inversión o de financiamiento: por cada renglón de lo comprado, su
  -- parte del cargo (w).
  select t.cuenta, t.cc, -t.monto as a, al.monto / ta.debe as w, mp.flujo_directo as fd, mp.flujo_indirecto as fi
    from tl t
    join ta on ta.asiento_id = t.asiento_id and not ta.toca and ta.debe > 0
    join public.asiento_lineas al on al.asiento_id = t.asiento_id and al.monto > 0
    join mp on mp.cuenta = al.cuenta and mp.estado = 'balance' and not mp.efectivo
           and mp.flujo_indirecto_seccion in ('inversion', 'financiamiento')
   where t.monto < 0
), pg as materialized (
  -- Los pagos a tarjeta de un asiento CON dinero y la parte de cada uno
  -- que salda esos cargos: lo pagado hasta este pago cubre primero los
  -- cargos más viejos (FIFO), renglón por renglón de lo comprado. Una fila
  -- por línea del pago, con sus destinos.
  select q.asiento_id, q.orden, sum(q.x) as x,
         jsonb_agg(jsonb_build_object('fd', q.fd, 'fi', q.fi, 'x', q.x) order by q.fd, q.fi) as destinos
    from (select t.asiento_id, t.orden, c.fd, c.fi,
                 round(sum(greatest(0, least(c.cc, t.cp) - greatest(c.cc - c.a, t.cp - t.monto)) * c.w), 2) as x
            from tl t
            join ta on ta.asiento_id = t.asiento_id and ta.toca
            join cg c on c.cuenta = t.cuenta and c.cc - c.a < t.cp and t.cp - t.monto < c.cc
           where t.monto > 0
           group by t.asiento_id, t.orden, c.fd, c.fi) q
   where q.x <> 0
   group by q.asiento_id, q.orden
), b as not materialized (
  -- Cada línea del libro con lo que hace su asiento (partido también por
  -- período y fecha, que son los de todo el asiento: así un filtro por
  -- fecha o período se aplica antes, y no sobre todo el libro).
  select v.*,
         bool_or(v.efectivo) over w as toca_efectivo,
         bool_or(not v.efectivo and v.estado = 'balance'
                 and v.flujo_indirecto_seccion in ('inversion', 'financiamiento', 'ajustes')) over w as no_operativo,
         -- La venta o baja de un activo: el asiento abona una cuenta de
         -- propiedad y equipo (no su depreciación, que es la contra).
         max(case when v.estado = 'balance' and v.seccion = 'activo_fijo' and not v.contra and v.monto < 0
                  then v.flujo_directo end) over w as baja_directo,
         max(case when v.estado = 'balance' and v.seccion = 'activo_fijo' and not v.contra and v.monto < 0
                  then v.flujo_indirecto end) over w as baja_indirecto,
         -- Lo que el asiento mueve en inversión y en financiamiento (importe:
         -- −monto): si van en sentido contrario, una parte de lo uno se pagó
         -- con lo otro sin pasar por el banco (ver cubierto_x, abajo).
         sum(case when not v.efectivo and v.estado = 'balance' and v.flujo_indirecto_seccion = 'inversion'
                  then -v.monto else 0 end) over w as inv_neto,
         sum(case when not v.efectivo and v.estado = 'balance' and v.flujo_indirecto_seccion = 'financiamiento'
                  then -v.monto else 0 end) over w as fin_neto
    from public.v_libro v
  window w as (partition by v.periodo, v.fecha, v.asiento_id)
), c as not materialized (
  select b.*,
         -- EL ACTIVO Y SU PRÉSTAMO EN UN SOLO ASIENTO (la camioneta de 40,000:
         -- 5,000 de enganche del banco y 35,000 que el banco del préstamo le
         -- paga directo al concesionario; o la venta de un activo cuyo
         -- comprador liquida el préstamo): en un asiento con dinero, la
         -- inversión y el financiamiento de sentido contrario se cubren uno
         -- al otro hasta el menor de los dos, y esa parte NO fue dinero: va
         -- al bloque sin dinero (sd_inversion / sd_financiamiento), en los
         -- dos métodos, igual que si se hubiera posteado en dos asientos.
         -- Antes, en uno solo, inversión −40,000 y financiamiento +35,000,
         -- con todos los cuadres en verde. cubierto_x: lo cubierto de ESTA
         -- línea (las del lado que cubre, en su orden, hasta completar).
         case when b.toca_efectivo and b.tipo <> 'apertura' and b.estado = 'balance'
                   and sign(b.inv_neto) * sign(b.fin_neto) < 0
                   and ((b.flujo_indirecto_seccion = 'inversion' and sign(-b.monto) = sign(b.inv_neto))
                        or (b.flujo_indirecto_seccion = 'financiamiento' and sign(-b.monto) = sign(b.fin_neto)))
              then greatest(0, least(abs(b.monto),
                                     least(abs(b.inv_neto), abs(b.fin_neto)) - coalesce(sum(abs(b.monto)) over wg, 0)))
              else 0 end as cubierto_x,
         case when b.tipo = 'apertura' then 'ajustes'
              when b.baja_directo is not null and b.estado = 'balance' and b.seccion = 'activo_fijo' and b.contra
                then b.baja_directo
              else b.flujo_directo end as ld,
         case when b.tipo = 'apertura' then 'ajustes'
              when b.estado = 'resultados' and b.ejercicio = b.anio then 'resultado'
              when b.estado = 'resultados' then 'resultado_anteriores'
              when b.baja_indirecto is not null and b.estado = 'balance' and b.seccion = 'activo_fijo' and b.contra
                then b.baja_indirecto
              else b.flujo_indirecto end as li,
         case b.flujo_indirecto_seccion when 'inversion' then 'sd_inversion' when 'financiamiento' then 'sd_financiamiento'
                                        when 'ajustes' then 'sd_ajustes' else 'sd_contrapartida' end as lsd
    from b
   where not b.efectivo
  window wg as (partition by b.periodo, b.fecha, b.asiento_id,
                             case when b.estado = 'balance' and b.flujo_indirecto_seccion = 'inversion'
                                       and sign(-b.monto) = sign(b.inv_neto) then 1
                                  when b.estado = 'balance' and b.flujo_indirecto_seccion = 'financiamiento'
                                       and sign(-b.monto) = sign(b.fin_neto) then 2
                                  else 0 end
                order by b.orden rows between unbounded preceding and 1 preceding)
), y as (
  -- (Una sola pasada por el libro: cada línea da sus piezas en un LATERAL.)
  select c.*, z.pieza, z.importe, z.linea_directo, z.linea_indirecto
    from c
    left join pg on pg.asiento_id = c.asiento_id and pg.orden = c.orden and c.toca_efectivo and c.tipo <> 'apertura'
    cross join lateral (
      select 'linea'::text as pieza, (-c.monto)::numeric(14,2) as importe,
             case when c.toca_efectivo then c.ld
                  when c.no_operativo and c.tipo <> 'apertura' and c.estado = 'balance' then c.lsd end as linea_directo,
             case when c.toca_efectivo then c.li
                  when c.no_operativo and c.tipo <> 'apertura' and c.estado = 'balance' then c.lsd
                  else c.li end as linea_indirecto
      union all
      select 'sin_dinero_en_resultado', c.monto::numeric(14,2), null,
             case when c.flujo_directo_seccion = 'inversion' then 'ganancia_venta_activos' else 'no_monetario' end
       where c.estado = 'resultados' and c.tipo <> 'apertura'
         and ((not c.toca_efectivo and c.no_operativo) or (c.toca_efectivo and c.flujo_directo_seccion <> 'operacion'))
      union all
      select 'resultado_a_' || c.flujo_directo_seccion, (-c.monto)::numeric(14,2), null, c.flujo_directo
       where c.estado = 'resultados' and c.tipo <> 'apertura' and c.toca_efectivo and c.flujo_directo_seccion <> 'operacion'
      union all
      select 'tarjeta_paga', pg.x::numeric(14,2), c.ld, c.li
       where pg.x is not null
      union all
      select 'tarjeta_compro', (-(d->>'x')::numeric)::numeric(14,2), d->>'fd', d->>'fi'
        from jsonb_array_elements(coalesce(pg.destinos, '[]'::jsonb)) d
      union all
      -- Lo cubierto sin dinero (ver cubierto_x): sale de su renglón…
      select 'cubierto_sin_dinero', (sign(c.monto) * c.cubierto_x)::numeric(14,2), c.ld, c.li
       where c.cubierto_x > 0
      union all
      -- …y se revela en el bloque sin dinero, igual en los dos métodos.
      select 'cubierto_se_revela', (-sign(c.monto) * c.cubierto_x)::numeric(14,2), c.lsd, c.lsd
       where c.cubierto_x > 0
    ) z
)
select y.asiento_id, y.numero, y.orden, y.fecha, y.periodo, y.periodo_efectivo, y.anio, y.ejercicio, y.tipo, y.camino,
       y.descripcion, y.origen_tabla, y.origen_id, y.cuenta, y.cuenta_nombre, y.estado, y.seccion, y.linea, y.monto,
       y.pieza, y.importe, case when y.importe > 0 then 'entrada' else 'salida' end as sentido, y.toca_efectivo,
       y.linea_directo, y.linea_indirecto, eld.seccion as seccion_directo, eli.seccion as seccion_indirecto,
       y.proyecto_id, y.tercero_tipo, y.tercero_id, y.partida_tabla, y.partida_id
  from y
  left join el eld on eld.estado = 'flujo_directo' and eld.linea = y.linea_directo
  left join el eli on eli.estado = 'flujo_indirecto' and eli.linea = y.linea_indirecto;

-- ---------------------------------------------------------------------
-- v_flujo_caja — el estado de flujo de efectivo de cada período (un mes, la
-- apertura o el año), por los dos métodos (metodo 'directo' e
-- 'indirecto'). Si el período tiene algo (dinero al empezar, asientos con
-- dinero o piezas), sale ENTERO, con todos sus renglones (los que no
-- tuvieron nada, en 0.00): el estado es siempre igual de un mes a otro, y
-- lo que no está en estados_lineas no se pierde callado (el cuadre lo
-- diría). Niveles:
--   'linea'    un renglón (cobros de clientes; cuentas por cobrar…);
--   'seccion'  operación, inversión, financiamiento, ajustes y el bloque
--              sin dinero (que se revela y NO suma: su fila no lleva
--              total, importe nulo);
--   'total'    efectivo al inicio, cambio en el efectivo (la suma de las
--              secciones que suman) y efectivo al final;
--   'control'  lo que tiene que dar 0.00 (cuadra = true): 'cuadra', el
--              cambio del método contra el del efectivo (final − inicial)
--              y contra el otro método; y 'cuadra_<sección>' (operacion,
--              inversion, financiamiento, ajustes): esa sección en este
--              método contra la del otro. Directo e indirecto dan lo
--              mismo SECCIÓN POR SECCIÓN, no solo en el total.
-- EL EFECTIVO ES EL DEL BALANCE: la suma de las cuentas de efectivo del
-- mapeo (las 10xx) que están en NEGRO; una en rojo no es efectivo sino
-- sobregiro (el balance la pasa al pasivo), y el cambio de lo que los
-- bancos en rojo «prestan» va a financiamiento, en su renglón «Sobregiro
-- bancario». Así el efectivo al inicio y al final son los del balance a
-- cada corte (antes, con un banco en rojo, el flujo decía 19,300 y el
-- balance 20,000, y ningún cuadre lo veía).
-- LA APERTURA NO ES UN FLUJO: en el período que la contiene (el de la
-- apertura y el año 2026), lo que trajo de efectivo es el efectivo al
-- inicio, y su asiento no da piezas (antes el año 2026 empezaba en 0.00 y
-- contaba los 50,000 de QuickBooks como un «ajuste» del año).
-- ---------------------------------------------------------------------
drop view if exists public.v_flujo_caja cascade;
create view public.v_flujo_caja with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.desde, p.hasta, x.*
  from public.periodos p
  cross join lateral (
    with f as materialized (
      -- Las piezas del período. Las del asiento de apertura no suman (su
      -- efectivo es el del inicio: ver ec).
      select fl.asiento_id, fl.numero, fl.importe, fl.linea_directo, fl.linea_indirecto, fl.tipo = 'apertura' as de_apertura
        from public.v_flujo_lineas fl
       where fl.fecha between p.desde and p.hasta
    ), ec as materialized (
      -- Cada cuenta de efectivo: su saldo al empezar (s0, con lo que trae la
      -- apertura si cae en el período) y al terminar (s1).
      select v.cuenta,
             coalesce(sum(v.monto) filter (where v.fecha < p.desde or v.tipo = 'apertura'), 0) as s0,
             coalesce(sum(v.monto), 0)                                                          as s1,
             coalesce(bool_or(v.tipo = 'apertura' and v.fecha >= p.desde), false)                as con_apertura
        from public.v_libro v
       where v.efectivo and v.fecha <= p.hasta
       group by v.cuenta
    ), eb as materialized (
      -- Con qué se baja al saldo de cada cuenta: al empezar (s0: lo de antes
      -- del período, y lo que trae la apertura si cae en él) y al terminar
      -- (s1).
      select ec.cuenta, ec.s0, ec.s1, e.k, e.o, e.v
        from ec
        cross join lateral (
          select 's0' as k, 1 as o, jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                                        'filtros', jsonb_build_object('cuenta', ec.cuenta),
                                                        'hasta', (p.desde - 1)::text) as v
          union all
          select 's0', 2, jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                             'filtros', jsonb_build_object('cuenta', ec.cuenta, 'tipo', 'apertura'),
                                             'desde', p.desde::text, 'hasta', p.hasta::text)
           where ec.con_apertura
          union all
          select 's1', 1, jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                             'filtros', jsonb_build_object('cuenta', ec.cuenta), 'hasta', p.hasta::text)
        ) e
    ), ef as materialized (
      -- El efectivo del balance (las cuentas en negro) al empezar y al
      -- terminar; el cambio del sobregiro (lo que las cuentas en rojo pasan a
      -- deber de más: financiamiento que entra); y cómo se baja a cada uno,
      -- cuenta por cuenta (el sobregiro: +s0 de las que empezaron en rojo,
      -- −s1 de las que terminaron en rojo).
      select coalesce(sum(greatest(ec.s0, 0)), 0)                  as inicial,
             coalesce(sum(greatest(ec.s1, 0)), 0)                  as final,
             coalesce(sum(least(ec.s0, 0) - least(ec.s1, 0)), 0)   as sobregiro,
             coalesce(bool_or(ec.con_apertura), false)            as con_apertura,
             (select min(v.fecha) from public.v_libro v
               where v.efectivo and v.tipo = 'apertura' and v.fecha between p.desde and p.hasta) as apertura_fecha,
             (select count(distinct v.asiento_id) from public.v_libro v
               where v.efectivo and v.fecha between p.desde and p.hasta) as asientos,
             (select coalesce(jsonb_agg(eb.v order by eb.cuenta, eb.o), '[]'::jsonb) from eb where eb.k = 's0' and eb.s0 > 0)
                                                                   as b_inicial,
             (select coalesce(jsonb_agg(eb.v order by eb.cuenta, eb.o), '[]'::jsonb) from eb where eb.k = 's1' and eb.s1 > 0)
                                                                   as b_final,
             (select coalesce(jsonb_agg(case when eb.k = 's1' then jsonb_set(eb.v, '{signo}', '-1') else eb.v end
                                        order by eb.cuenta, eb.k, eb.o), '[]'::jsonb)
                from eb where (eb.k = 's0' and eb.s0 < 0) or (eb.k = 's1' and eb.s1 < 0)) as b_sobregiro
        from ec
    ), hay as materialized (
      select ef.asientos > 0 or exists (select 1 from ec where ec.s0 <> 0) or exists (select 1 from f) as hay from ef
    ), r as materialized (
      select 'directo'::text as metodo, f.linea_directo as linea, sum(f.importe) as importe,
             count(distinct f.asiento_id) as asientos, min(f.asiento_id::text) as asiento_min, min(f.numero) as numero_min
        from f where f.linea_directo is not null and not f.de_apertura
       group by f.linea_directo
      union all
      select 'indirecto', f.linea_indirecto, sum(f.importe), count(distinct f.asiento_id), min(f.asiento_id::text), min(f.numero)
        from f where f.linea_indirecto is not null and not f.de_apertura
       group by f.linea_indirecto
      union all
      -- El sobregiro: financiamiento, en los dos métodos.
      select mm.metodo, 'sobregiro', ef.sobregiro, 0, null, null
        from ef, (values ('directo'), ('indirecto')) as mm(metodo)
       where ef.sobregiro <> 0
    ), rl as materialized (
      -- Todos los renglones de cada método (estados_lineas), con lo suyo.
      -- Una sección sin renglones propios ('ajustes') es su propio renglón.
      select substr(el.estado, 7) as metodo, el.seccion, el.linea, el.orden as linea_orden, el.etiqueta_es, el.etiqueta_en,
             es.orden as seccion_orden, es.etiqueta_es as seccion_es, es.etiqueta_en as seccion_en,
             coalesce(r.importe, 0) as importe, coalesce(r.asientos, 0) as asientos, r.asiento_min, r.numero_min
        from public.estados_lineas el
        join public.estados_lineas es on es.estado = el.estado and es.seccion = el.seccion and es.linea = el.seccion
        left join r on 'flujo_' || r.metodo = el.estado and r.linea = el.linea
       where el.estado in ('flujo_directo', 'flujo_indirecto') and el.seccion <> 'totales'
         and (el.linea <> el.seccion
              or not exists (select 1 from public.estados_lineas o
                              where o.estado = el.estado and o.seccion = el.seccion and o.linea <> o.seccion))
    ), sec as materialized (
      select rl.metodo, rl.seccion, min(rl.seccion_orden) as seccion_orden, min(rl.seccion_es) as seccion_es,
             min(rl.seccion_en) as seccion_en, sum(rl.importe) as importe
        from rl
       group by rl.metodo, rl.seccion
    ), m as materialized (
      select mm.metodo,
             coalesce((select sum(rl.importe) from rl where rl.metodo = mm.metodo and rl.seccion <> 'sin_dinero'), 0) as cambio
        from (values ('directo'), ('indirecto')) as mm(metodo)
    )
    select rl.metodo, 'linea'::text as nivel, rl.seccion, rl.seccion_orden, rl.linea, rl.linea_orden,
           rl.etiqueta_es, rl.etiqueta_en, rl.importe::numeric(14,2) as importe, rl.asientos,
           case when rl.asientos = 1 then rl.asiento_min::uuid end as asiento_id,
           case when rl.asientos = 1 then rl.numero_min end as numero,
           null::boolean as cuadra,
           jsonb_build_object('importe', case when rl.linea = 'sobregiro' then (select ef.b_sobregiro from ef)
                                              else jsonb_build_array(jsonb_build_object(
                                                     'vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                                     'filtros', jsonb_build_object('linea_' || rl.metodo, rl.linea,
                                                                                   'tipo_no', 'apertura'),
                                                     'desde', p.desde::text, 'hasta', p.hasta::text)) end) as bajar
      from rl, hay
     where hay.hay
    union all
    -- (El bloque sin dinero no lleva total: son partidas distintas que
    -- se revelan una por una.)
    select s.metodo, 'seccion', s.seccion, s.seccion_orden, s.seccion, s.seccion_orden, coalesce(s.seccion_es, s.seccion),
           coalesce(s.seccion_en, s.seccion), case when s.seccion <> 'sin_dinero' then s.importe end::numeric(14,2),
           null, null, null, null,
           case when s.seccion <> 'sin_dinero'
                then jsonb_build_object('importe', jsonb_build_array(jsonb_build_object(
                       'vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                       'filtros', jsonb_build_object('seccion_' || s.metodo, s.seccion, 'tipo_no', 'apertura'),
                       'desde', p.desde::text, 'hasta', p.hasta::text))
                       || case when s.seccion = 'financiamiento' then (select ef.b_sobregiro from ef) else '[]'::jsonb end)
                else '{}'::jsonb end
      from sec s, hay
     where hay.hay
    union all
    select m.metodo, 'total', 'totales', 9000, t.linea, lt.orden,
           lt.etiqueta_es || case when t.linea = 'efectivo_inicial' and ef.con_apertura
                                  then ' (con lo que trajo la apertura del ' || to_char(ef.apertura_fecha, 'DD-MM-YYYY') || ')'
                                  else '' end,
           lt.etiqueta_en || case when t.linea = 'efectivo_inicial' and ef.con_apertura
                                  then ' (including the opening balance of ' || to_char(ef.apertura_fecha, 'YYYY-MM-DD') || ')'
                                  else '' end,
           t.importe::numeric(14,2), ef.asientos, null, null, null, jsonb_build_object('importe', t.bajar)
      from m
      cross join ef
      cross join hay
      cross join lateral (values
        ('efectivo_inicial', ef.inicial, ef.b_inicial),
        ('cambio', m.cambio,
         jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                              'filtros', jsonb_build_object('seccion_' || m.metodo || '_no', jsonb_build_array('sin_dinero'),
                                                                            'tipo_no', 'apertura'),
                                              'desde', p.desde::text, 'hasta', p.hasta::text))
         || ef.b_sobregiro),
        -- (= inicial + cambio: el cuadre de abajo lo mira)
        ('efectivo_final', ef.inicial + m.cambio, ef.b_final)
      ) as t(linea, importe, bajar)
      left join public.estados_lineas lt on lt.estado = 'flujo_' || m.metodo and lt.seccion = 'totales' and lt.linea = t.linea
     where hay.hay
    union all
    -- El control: el cambio de cada método contra el del efectivo y contra
    -- el otro método. importe = lo que no cuadra (0.00).
    select m.metodo, 'control', 'totales', 9999, 'cuadra', 9999,
           'Diferencia contra el cambio del efectivo y contra el otro método (debe ser 0)',
           'Difference vs. the change in cash and vs. the other method (must be 0)',
           (m.cambio - (ef.final - ef.inicial))::numeric(14,2), null, null, null,
           m.cambio = ef.final - ef.inicial and m.cambio = (select o.cambio from m o where o.metodo <> m.metodo),
           -- (cambio − (final − inicial) = las piezas − el dinero del período
           -- sin la apertura: el sobregiro se va en los dos lados)
           jsonb_build_object('importe', jsonb_build_array(
             jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                'filtros', jsonb_build_object('seccion_' || m.metodo || '_no', jsonb_build_array('sin_dinero'),
                                                              'tipo_no', 'apertura'),
                                'desde', p.desde::text, 'hasta', p.hasta::text),
             jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                                'filtros', jsonb_build_object('efectivo', true, 'tipo_no', 'apertura'),
                                'desde', p.desde::text, 'hasta', p.hasta::text)))
      from m, ef, hay
     where hay.hay
    union all
    -- Y sección por sección: la de este método contra la del otro.
    select s.metodo, 'control', 'totales', 9999, 'cuadra_' || s.seccion, 9999 + s.seccion_orden,
           format('%s: %s contra %s (debe ser 0)', coalesce(s.seccion_es, s.seccion), s.metodo,
                  case s.metodo when 'directo' then 'indirecto' else 'directo' end),
           format('%s: %s vs. %s (must be 0)', coalesce(s.seccion_en, s.seccion), s.metodo,
                  case s.metodo when 'directo' then 'indirect' else 'direct' end),
           (s.importe - coalesce(o.importe, 0))::numeric(14,2), null, null, null,
           s.importe = coalesce(o.importe, 0),
           jsonb_build_object('importe', jsonb_build_array(
             jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                'filtros', jsonb_build_object('seccion_' || s.metodo, s.seccion, 'tipo_no', 'apertura'),
                                'desde', p.desde::text, 'hasta', p.hasta::text),
             jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', -1,
                                'filtros', jsonb_build_object('seccion_' || case s.metodo when 'directo' then 'indirecto'
                                                                                   else 'directo' end, s.seccion,
                                                              'tipo_no', 'apertura'),
                                'desde', p.desde::text, 'hasta', p.hasta::text)))
      from sec s
      left join sec o on o.seccion = s.seccion and o.metodo <> s.metodo
      cross join hay
     where hay.hay and s.seccion <> 'sin_dinero'
  ) x;

-- ---------------------------------------------------------------------
-- 4.5 · v_efectivo_movimientos — el dinero que se movió, asiento por
-- asiento: cada asiento con líneas de efectivo que no suman cero (un
-- traspaso entre bancos suma cero y no es ni entrada ni salida), con su
-- neto (lo que entró al banco, positivo; lo que salió, negativo), el
-- sentido, y par_en_el_mes: el asiento es un error y su reverso de
-- corrección (fn_reversar) caen en el MISMO mes; ese dinero no se movió
-- de verdad, y la gráfica del Panel no lo cuenta ni como entrada ni como
-- salida (se anulan). Es a donde bajan las entradas y salidas de
-- v_flujo_real_por_mes.
-- ---------------------------------------------------------------------
drop view if exists public.v_efectivo_movimientos cascade;
create view public.v_efectivo_movimientos with (security_invoker = true) as
select v.asiento_id, v.numero, v.fecha, v.periodo, v.anio, v.tipo, v.camino, v.descripcion, v.reversa_a,
       sum(v.monto)::numeric(14,2) as neto,
       case when sum(v.monto) > 0 then 'entrada' else 'salida' end as sentido,
       (    (v.camino = 'reverso'
             and exists (select 1 from public.asientos o
                          where o.id = v.reversa_a
                            and date_trunc('month', o.fecha_contable::timestamp) = date_trunc('month', v.fecha::timestamp)))
        or exists (select 1 from public.asientos r
                    where r.reversa_a = v.asiento_id and r.camino = 'reverso'
                      and date_trunc('month', r.fecha_contable::timestamp) = date_trunc('month', v.fecha::timestamp))) as par_en_el_mes,
       count(*) as lineas
  from public.v_libro v
 where v.efectivo
 group by v.asiento_id, v.numero, v.fecha, v.periodo, v.anio, v.tipo, v.camino, v.descripcion, v.reversa_a
having sum(v.monto) <> 0;

-- ---------------------------------------------------------------------
-- v_flujo_real_por_mes — el dinero de verdad, mes por mes (la gráfica de
-- seis meses del Panel): una fila por mes, desde el primero con dinero
-- hasta el mes en curso (o el del último asiento, si es posterior), con el
-- efectivo al inicio, lo que ENTRÓ y lo que SALIÓ de los bancos (por
-- asiento, su neto de efectivo: un cobro de 1,000 con 30 de comisión son
-- 970 que entran; una nómina de 5,000 con 800 retenidos son 4,200 que
-- salen; un traspaso entre bancos no es ni lo uno ni lo otro; un error y
-- su reverso del mismo mes, tampoco), el neto, el cambio del sobregiro, el
-- efectivo al final, y el neto por sección del flujo directo (operación,
-- inversión, financiamiento —con el sobregiro— y ajustes).
--   entradas − salidas = neto;
--   neto + sobregiro = operacion + inversion + financiamiento + ajustes
--                    = efectivo_final − efectivo_inicial.
-- El efectivo, al inicio y al final, es el del BALANCE (v_flujo_caja): las
-- cuentas de efectivo en negro; una en rojo es sobregiro, y lo que cambia
-- lo que deben los bancos en rojo es la columna sobregiro (financiamiento).
-- Antes el Panel sumaba también la cuenta en rojo y su final no era el
-- efectivo del balance.
-- En UNA pasada: el efectivo, los movimientos y las piezas del flujo se
-- agrupan por mes una sola vez, y el inicial de cada mes es la suma de los
-- anteriores (incluida la apertura, que cae en su mes).
-- ---------------------------------------------------------------------
drop view if exists public.v_flujo_real_por_mes cascade;
create view public.v_flujo_real_por_mes with (security_invoker = true) as
with ef as materialized (
  select date_trunc('month', v.fecha::timestamp)::date as mes, sum(v.monto) as neto, count(distinct v.asiento_id) as asientos
    from public.v_libro v
   where v.efectivo
   group by 1
), efc as materialized (
  -- Lo mismo por cuenta de efectivo (para saber cuáles están en rojo).
  select v.cuenta, date_trunc('month', v.fecha::timestamp)::date as mes, sum(v.monto) as neto
    from public.v_libro v
   where v.efectivo
   group by 1, 2
), mv as materialized (
  select date_trunc('month', m.fecha::timestamp)::date as mes,
         coalesce(sum(m.neto) filter (where m.neto > 0 and not m.par_en_el_mes), 0)  as entradas,
         coalesce(-sum(m.neto) filter (where m.neto < 0 and not m.par_en_el_mes), 0) as salidas
    from public.v_efectivo_movimientos m
   group by 1
), fl as materialized (
  select date_trunc('month', f.fecha::timestamp)::date as mes,
         coalesce(sum(f.importe) filter (where f.seccion_directo = 'operacion'), 0)      as operacion,
         coalesce(sum(f.importe) filter (where f.seccion_directo = 'inversion'), 0)      as inversion,
         coalesce(sum(f.importe) filter (where f.seccion_directo = 'financiamiento'), 0) as financiamiento,
         coalesce(sum(f.importe) filter (where f.seccion_directo = 'ajustes'), 0)        as ajustes
    from public.v_flujo_lineas f
   where f.linea_directo is not null
   group by 1
), h as materialized (
  select greatest(public.fn_fecha_miami(now()), (select max(a.fecha_contable) from public.asientos a)) as hasta_mes
)
select p.periodo, p.desde, p.hasta,
       jsonb_path_query_first(to_jsonb(p), 'strict $.estado') #>> '{}' as periodo_estado,   -- (sin fijarle el tipo: ver 2.1)
       z.inicial::numeric(14,2)                             as efectivo_inicial,
       coalesce(mv.entradas, 0)::numeric(14,2)              as entradas,
       coalesce(mv.salidas, 0)::numeric(14,2)               as salidas,
       coalesce(ef.neto, 0)::numeric(14,2)                  as neto,
       z.sobregiro::numeric(14,2)                           as sobregiro,
       z.final::numeric(14,2)                               as efectivo_final,
       coalesce(fl.operacion, 0)::numeric(14,2)             as operacion,
       coalesce(fl.inversion, 0)::numeric(14,2)             as inversion,
       (coalesce(fl.financiamiento, 0) + z.sobregiro)::numeric(14,2) as financiamiento,
       coalesce(fl.ajustes, 0)::numeric(14,2)               as ajustes,
       coalesce(ef.asientos, 0)                             as asientos,
       jsonb_build_object(
         'efectivo_inicial', z.b_inicial,
         'entradas', jsonb_build_array(jsonb_build_object('vista', 'v_efectivo_movimientos', 'campo', 'neto', 'signo', 1,
                               'filtros', jsonb_build_object('sentido', 'entrada', 'par_en_el_mes', false),
                               'desde', p.desde::text, 'hasta', p.hasta::text)),
         'salidas', jsonb_build_array(jsonb_build_object('vista', 'v_efectivo_movimientos', 'campo', 'neto', 'signo', -1,
                               'filtros', jsonb_build_object('sentido', 'salida', 'par_en_el_mes', false),
                               'desde', p.desde::text, 'hasta', p.hasta::text)),
         'neto', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'filtros', jsonb_build_object('efectivo', true), 'desde', p.desde::text, 'hasta', p.hasta::text)),
         'sobregiro', z.b_sobregiro,
         'efectivo_final', z.b_final,
         'operacion', jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                               'filtros', jsonb_build_object('seccion_directo', 'operacion'),
                               'desde', p.desde::text, 'hasta', p.hasta::text)),
         'inversion', jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                               'filtros', jsonb_build_object('seccion_directo', 'inversion'),
                               'desde', p.desde::text, 'hasta', p.hasta::text)),
         'financiamiento', jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                               'filtros', jsonb_build_object('seccion_directo', 'financiamiento'),
                               'desde', p.desde::text, 'hasta', p.hasta::text)) || z.b_sobregiro,
         'ajustes', jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                               'filtros', jsonb_build_object('seccion_directo', 'ajustes'),
                               'desde', p.desde::text, 'hasta', p.hasta::text))) as bajar
  from public.periodos p
  cross join h
  left join ef on ef.mes = p.desde
  left join mv on mv.mes = p.desde
  left join fl on fl.mes = p.desde
  cross join lateral (
    -- Cada cuenta de efectivo al empezar (s0) y al terminar (s1) el mes: el
    -- efectivo del balance (las que están en negro), el cambio del
    -- sobregiro (+s0 de las que empezaron en rojo, −s1 de las que
    -- terminaron en rojo) y con qué se baja a cada cifra.
    select coalesce(sum(greatest(q.s0, 0)), 0)                 as inicial,
           coalesce(sum(greatest(q.s1, 0)), 0)                 as final,
           coalesce(sum(least(q.s0, 0) - least(q.s1, 0)), 0)   as sobregiro,
           coalesce(bool_or(q.s0 <> 0), false)                 as con_saldo,
           coalesce(jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                                 'filtros', jsonb_build_object('cuenta', q.cuenta), 'hasta', (p.desde - 1)::text)
                              order by q.cuenta) filter (where q.s0 > 0), '[]'::jsonb) as b_inicial,
           coalesce(jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                                 'filtros', jsonb_build_object('cuenta', q.cuenta), 'hasta', p.hasta::text)
                              order by q.cuenta) filter (where q.s1 > 0), '[]'::jsonb) as b_final,
           coalesce(jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                                 'filtros', jsonb_build_object('cuenta', q.cuenta), 'hasta', (p.desde - 1)::text)
                              order by q.cuenta) filter (where q.s0 < 0), '[]'::jsonb)
           || coalesce(jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                                                    'filtros', jsonb_build_object('cuenta', q.cuenta), 'hasta', p.hasta::text)
                                 order by q.cuenta) filter (where q.s1 < 0), '[]'::jsonb) as b_sobregiro
      from (select e.cuenta, coalesce(sum(e.neto) filter (where e.mes < p.desde), 0) as s0,
                   coalesce(sum(e.neto) filter (where e.mes <= p.desde), 0) as s1
              from efc e
             group by e.cuenta) q
  ) z
 where p.tipo = 'mes'
   and p.desde <= h.hasta_mes
   and (coalesce(ef.asientos, 0) > 0 or z.con_saldo);


-- =====================================================================
-- 5 · LAS VISTAS DEL TABLERO (el Panel de f05): saldos de bancos y
-- tarjetas, antigüedad de lo que se cobra y de lo que se paga, en qué se
-- gasta y a quién, costo y dinero por obra. Todas salen del libro, con su
-- «bajar», y todas dan 0 filas a quien no ve el libro.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5.1 · v_saldos_dinero — a cada corte, el saldo de cada cuenta de dinero
-- (tipo 'banco': las de efectivo del mapeo, 10xx), de cada tarjeta
-- ('tarjeta': el renglón tarjetas, 2100-x) y de la línea de crédito
-- ('credito'). Una fila por cuenta imputable de esos renglones que esté
-- activa o tenga movimientos (una tarjeta dada de baja con saldo sigue
-- saliendo):
--   saldo             en su lado: el banco, lo que hay; la tarjeta, lo que
--                     se debe;
--   saldo_inicial     al empezar el período del corte;
--   cargos / abonos   lo que entró por el debe y por el haber en el período
--                     (en el banco, los depósitos y los pagos);
--   ultimo_movimiento la fecha del último asiento hasta el corte.
-- La conciliación contra el estado del banco llega con f06: estas son las
-- cifras del libro.
-- ---------------------------------------------------------------------
drop view if exists public.v_saldos_dinero cascade;
create view public.v_saldos_dinero with (security_invoker = true) as
select c.periodo, c.tipo as periodo_tipo, c.desde, c.corte, x.*
  from public.v_cortes c
  cross join lateral (
    with m as materialized (
      select mp.cuenta, mp.cuenta_nombre, mp.etiqueta_es, mp.etiqueta_en, mp.linea, mp.orden, mp.saldo_normal,
             case when mp.efectivo then 'banco' when mp.linea = 'tarjetas' then 'tarjeta' else 'credito' end as tipo
        from public.v_estados_mapeo mp
        join public.cuentas cu on cu.codigo = mp.cuenta
       where cu.imputable
         and (mp.efectivo or (mp.estado = 'balance' and mp.linea in ('tarjetas', 'linea_credito')))
    ), l as materialized (
      select v.cuenta, v.fecha, v.monto, v.asiento_id, v.numero
        from public.v_libro v
       where v.fecha <= c.corte
         and v.cuenta in (select m.cuenta from m)
    ), g as materialized (
      select l.cuenta,
             sum(l.monto)                                                  as saldo,
             coalesce(sum(l.monto) filter (where l.fecha < c.desde), 0)    as inicial,
             coalesce(sum(l.monto) filter (where l.fecha >= c.desde and l.monto > 0), 0)  as cargos,
             coalesce(-sum(l.monto) filter (where l.fecha >= c.desde and l.monto < 0), 0) as abonos,
             max(l.fecha)                                                  as ultimo,
             count(distinct l.asiento_id) filter (where l.fecha >= c.desde) as asientos,
             min(l.asiento_id::text) filter (where l.fecha >= c.desde)     as asiento_min,
             min(l.numero) filter (where l.fecha >= c.desde)               as numero_min
        from l
       group by l.cuenta
    )
    select m.tipo, m.cuenta, m.cuenta_nombre, m.etiqueta_es, m.etiqueta_en, m.orden,
           (s.s * coalesce(g.saldo, 0))::numeric(14,2)   as saldo,
           (s.s * coalesce(g.inicial, 0))::numeric(14,2) as saldo_inicial,
           coalesce(g.cargos, 0)::numeric(14,2)          as cargos,
           coalesce(g.abonos, 0)::numeric(14,2)          as abonos,
           g.ultimo                                      as ultimo_movimiento,
           coalesce(g.asientos, 0)                       as asientos,
           case when g.asientos = 1 then g.asiento_min::uuid end as asiento_id,
           case when g.asientos = 1 then g.numero_min end        as numero,
           jsonb_build_object(
             'saldo',         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', s.s,
                                'filtros', jsonb_build_object('cuenta', m.cuenta), 'hasta', c.corte::text)),
             'saldo_inicial', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', s.s,
                                'filtros', jsonb_build_object('cuenta', m.cuenta), 'hasta', (c.desde - 1)::text)),
             'cargos',        jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'debe', 'signo', 1,
                                'filtros', jsonb_build_object('cuenta', m.cuenta), 'desde', c.desde::text, 'hasta', c.corte::text)),
             'abonos',        jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'haber', 'signo', 1,
                                'filtros', jsonb_build_object('cuenta', m.cuenta), 'desde', c.desde::text, 'hasta', c.corte::text)))
             as bajar
      from m
      join public.cuentas cu on cu.codigo = m.cuenta
      left join g on g.cuenta = m.cuenta
      cross join lateral (select case when m.saldo_normal = 'haber' then -1 else 1 end as s) s
     where (jsonb_path_query_first(to_jsonb(cu), 'strict $.activa') #>> '{}')::boolean   -- (sin fijarle el tipo: ver 2.1)
        or g.cuenta is not null
  ) x;

-- ---------------------------------------------------------------------
-- 5.2 · v_cxc_antiguedad — lo que se cobra, a cada corte, partida por
-- partida (c3: cada factura es UNA partida en 1110 y 1120, con su obra;
-- cada anticipo, la de su cobro):
--   tipo         'factura' (partida facturas/<id>), 'anticipo' (partida
--                cobros/<id>: dinero recibido sin factura, en negativo),
--                'sin_partida' (líneas de 1110/1120 sin partida, por obra:
--                un crédito del cliente que trajo la apertura, un asiento a
--                mano) u 'otra';
--   por_cobrar   el saldo en cuentas por cobrar (1110) a la fecha;
--   retencion    el saldo en retención por cobrar (1120): no se envejece
--                (se cobra al terminar la obra), va aparte;
--   cargos/abonos lo facturado y lo cobrado, abonado o descontado de esa
--                partida hasta el corte (un cobro parcial deja la factura
--                abierta por la diferencia; una nota de crédito la cierra;
--                un cheque devuelto la vuelve a abrir, en la fecha de la
--                devolución);
--   fecha, dias  la de la factura (la del cobro en un anticipo; la de la
--                línea más vieja si no hay partida) y los días hasta el
--                corte; tramo '0-30', '31-60', '61-90', '90+', 'anticipo',
--                'a_favor' (un saldo a favor del cliente sin factura) o
--                'retencion' (si solo queda retención); d0_30…d90_mas =
--                por_cobrar en su tramo; anticipos = los anticipos y los
--                saldos a favor (en negativo).
-- Solo las partidas abiertas (con saldo). La fila nivel 'total' suma todo y
-- lo compara con el mayor de 1110 + 1120 a la fecha (cuadra): lo que no
-- esté en ninguna fila de la antigüedad no existe en el libro. (La 1190,
-- la provisión de incobrables, no es de ninguna partida: resta aparte en el
-- balance.)
-- ---------------------------------------------------------------------
drop view if exists public.v_cxc_antiguedad cascade;
create view public.v_cxc_antiguedad with (security_invoker = true) as
select c.periodo, c.tipo as periodo_tipo, c.corte, x.*
  from public.v_cortes c
  cross join lateral (
    with k as materialized (
      select (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'cxc')           as cxc,
             (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'retencion_cxc') as ret
    ), l as materialized (
      select v.asiento_id, v.numero, v.fecha, v.cuenta, v.monto, v.proyecto_id, v.partida_tabla, v.partida_id,
             v.cuenta = k.ret as es_ret
        from public.v_libro v, k
       where v.cuenta in (k.cxc, k.ret) and v.fecha <= c.corte
    ), g as materialized (
      select l.partida_tabla, l.partida_id,
             case when l.partida_tabla is null then l.proyecto_id end         as obra_sin_partida,
             min(l.proyecto_id)                                               as proyecto_id,
             coalesce(sum(l.monto) filter (where not l.es_ret), 0)            as por_cobrar,
             coalesce(sum(l.monto) filter (where l.es_ret), 0)                as retencion,
             coalesce(sum(l.monto) filter (where l.monto > 0), 0)             as cargos,
             coalesce(-sum(l.monto) filter (where l.monto < 0), 0)            as abonos,
             min(l.fecha)                                                     as primera,
             count(distinct l.asiento_id)                                     as asientos,
             min(l.asiento_id::text)                                          as asiento_min,
             min(l.numero)                                                    as numero_min
        from l
       group by l.partida_tabla, l.partida_id, case when l.partida_tabla is null then l.proyecto_id end
    ), a as materialized (
      select g.*,
             case when g.partida_tabla = 'facturas' then 'factura' when g.partida_tabla = 'cobros' then 'anticipo'
                  when g.partida_tabla is null then 'sin_partida' else 'otra' end as tipo,
             f.id as factura_id, f.num as factura_num, f.monto as factura_monto,
             coalesce(case when g.partida_tabla = 'facturas' then f.fecha when g.partida_tabla = 'cobros' then co.fecha end,
                      g.primera) as fecha,
             case when g.partida_tabla is null
                  then jsonb_build_object('partida_tabla', null, 'proyecto_id', g.obra_sin_partida)
                  else jsonb_build_object('partida_tabla', g.partida_tabla, 'partida_id', g.partida_id) end as filtros
        from g
        left join public.facturas f
               on g.partida_tabla = 'facturas'
              and f.id = (case when g.partida_tabla = 'facturas' and g.partida_id ~ '^-?[0-9]{1,18}$' then g.partida_id::bigint end)
        left join public.cobros co
               on g.partida_tabla = 'cobros'
              and co.id = (case when g.partida_tabla = 'cobros' and g.partida_id ~ '^[0-9a-f-]{36}$' then g.partida_id::uuid end)
       where g.por_cobrar <> 0 or g.retencion <> 0
    ), t as materialized (
      select a.*, c.corte - a.fecha as dias,
             case when a.tipo = 'anticipo' then 'anticipo'
                  when a.por_cobrar < 0 then 'a_favor'
                  when a.por_cobrar = 0 then 'retencion'
                  when c.corte - a.fecha <= 30 then '0-30'
                  when c.corte - a.fecha <= 60 then '31-60'
                  when c.corte - a.fecha <= 90 then '61-90'
                  else '90+' end as tramo
        from a
    ), d as materialized (
      select t.*, k.cxc, k.ret,
             jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'hasta', c.corte::text,
                                'filtros', t.filtros || jsonb_build_object('cuenta', k.cxc)) as s_cxc,
             jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'hasta', c.corte::text,
                                'filtros', t.filtros || jsonb_build_object('cuenta', k.ret)) as s_ret
        from t, k
    )
    select 'partida'::text as nivel, d.tipo, d.partida_tabla, d.partida_id, d.factura_id, d.factura_num,
           d.proyecto_id, pr.nombre as obra, pr.cliente, d.fecha, d.dias, d.tramo,
           d.por_cobrar::numeric(14,2) as por_cobrar, d.retencion::numeric(14,2) as retencion,
           (d.por_cobrar + d.retencion)::numeric(14,2) as total,
           (case when d.tramo = '0-30'  then d.por_cobrar else 0 end)::numeric(14,2) as d0_30,
           (case when d.tramo = '31-60' then d.por_cobrar else 0 end)::numeric(14,2) as d31_60,
           (case when d.tramo = '61-90' then d.por_cobrar else 0 end)::numeric(14,2) as d61_90,
           (case when d.tramo = '90+'   then d.por_cobrar else 0 end)::numeric(14,2) as d90_mas,
           (case when d.tramo in ('anticipo', 'a_favor') then d.por_cobrar else 0 end)::numeric(14,2) as anticipos,
           d.cargos::numeric(14,2) as cargos, d.abonos::numeric(14,2) as abonos,
           round(d.factura_monto, 2)::numeric(14,2) as factura_monto,
           d.asientos, case when d.asientos = 1 then d.asiento_min::uuid end as asiento_id,
           case when d.asientos = 1 then d.numero_min end as numero,
           null::numeric(14,2) as mayor, null::boolean as cuadra,
           jsonb_build_object(
             'por_cobrar', jsonb_build_array(d.s_cxc),
             'retencion',  jsonb_build_array(d.s_ret),
             'total',      jsonb_build_array(d.s_cxc, d.s_ret),
             'd0_30',      case when d.tramo = '0-30'  then jsonb_build_array(d.s_cxc) else '[]'::jsonb end,
             'd31_60',     case when d.tramo = '31-60' then jsonb_build_array(d.s_cxc) else '[]'::jsonb end,
             'd61_90',     case when d.tramo = '61-90' then jsonb_build_array(d.s_cxc) else '[]'::jsonb end,
             'd90_mas',    case when d.tramo = '90+'   then jsonb_build_array(d.s_cxc) else '[]'::jsonb end,
             'anticipos',  case when d.tramo in ('anticipo', 'a_favor') then jsonb_build_array(d.s_cxc) else '[]'::jsonb end,
             'cargos',     jsonb_build_array(jsonb_set(jsonb_set(d.s_cxc, '{campo}', '"debe"'), '{filtros,cuenta}',
                                                       jsonb_build_array(d.cxc, d.ret))),
             'abonos',     jsonb_build_array(jsonb_set(jsonb_set(d.s_cxc, '{campo}', '"haber"'), '{filtros,cuenta}',
                                                       jsonb_build_array(d.cxc, d.ret)))) as bajar
      from d
      left join public.proyectos pr on pr.id = d.proyecto_id
    union all
    -- El total, contra el mayor.
    select 'total', null, null, null, null, null, null, null, null, null, null, null,
           coalesce(sum(d.por_cobrar), 0)::numeric(14,2), coalesce(sum(d.retencion), 0)::numeric(14,2),
           coalesce(sum(d.por_cobrar + d.retencion), 0)::numeric(14,2),
           coalesce(sum(d.por_cobrar) filter (where d.tramo = '0-30'), 0)::numeric(14,2),
           coalesce(sum(d.por_cobrar) filter (where d.tramo = '31-60'), 0)::numeric(14,2),
           coalesce(sum(d.por_cobrar) filter (where d.tramo = '61-90'), 0)::numeric(14,2),
           coalesce(sum(d.por_cobrar) filter (where d.tramo = '90+'), 0)::numeric(14,2),
           coalesce(sum(d.por_cobrar) filter (where d.tramo in ('anticipo', 'a_favor')), 0)::numeric(14,2),
           null::numeric(14,2), null::numeric(14,2), null::numeric(14,2),
           (select count(distinct l.asiento_id) from l), null, null,
           (select coalesce(sum(l.monto), 0) from l)::numeric(14,2),
           coalesce(sum(d.por_cobrar + d.retencion), 0) = (select coalesce(sum(l.monto), 0) from l),
           jsonb_build_object(
             'por_cobrar', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                             'hasta', c.corte::text, 'filtros', jsonb_build_object('cuenta', (select k.cxc from k)))),
             'retencion',  jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                             'hasta', c.corte::text, 'filtros', jsonb_build_object('cuenta', (select k.ret from k)))),
             'total',      jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                             'hasta', c.corte::text, 'filtros', jsonb_build_object('cuenta', jsonb_build_array((select k.cxc from k), (select k.ret from k))))),
             'd0_30',      coalesce(jsonb_agg(d.s_cxc) filter (where d.tramo = '0-30'), '[]'::jsonb),
             'd31_60',     coalesce(jsonb_agg(d.s_cxc) filter (where d.tramo = '31-60'), '[]'::jsonb),
             'd61_90',     coalesce(jsonb_agg(d.s_cxc) filter (where d.tramo = '61-90'), '[]'::jsonb),
             'd90_mas',    coalesce(jsonb_agg(d.s_cxc) filter (where d.tramo = '90+'), '[]'::jsonb),
             'anticipos',  coalesce(jsonb_agg(d.s_cxc) filter (where d.tramo in ('anticipo', 'a_favor')), '[]'::jsonb),
             'mayor',      jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                             'hasta', c.corte::text,
                             'filtros', jsonb_build_object('cuenta', jsonb_build_array((select k.cxc from k), (select k.ret from k))))))
      from d
    having exists (select 1 from l)
  ) x;

-- ---------------------------------------------------------------------
-- 5.3 · v_cxp_antiguedad — lo que se paga, a cada corte, partida por
-- partida: cada recibo a cuenta y cada trabajo externo es su partida en
-- 2010 (c3), a nombre de su proveedor; lo que trajo la apertura va por
-- proveedor (sin partida, o con la del papel si está en la app).
--   tipo        'papel' (partida recibos/<id> o trabajos_externos/<id>),
--               'proveedor' (sin partida, con proveedor) o 'sin_partida';
--   por_pagar   lo que se debe en cuentas por pagar (2010), en positivo; un
--               saldo a favor (se pagó de más, una nota del proveedor) sale
--               en negativo, tramo 'a_favor';
--   retencion   la retención por pagar a subcontratistas (2020), aparte;
--   fecha, dias la del papel; sin papel (lo que se le debe a un proveedor
--               por la apertura o por asientos a mano), la de lo MÁS VIEJO
--               que sigue sin pagar: cada pago salda primero lo más viejo
--               (FIFO), y lo que trajo la apertura va factura por factura
--               con la fecha que trae la balanza de QuickBooks
--               (fecha_documento: el A/P Aging Detail al 30-sep). Si lo más
--               viejo sin pagar es de la apertura y la balanza no trae su
--               fecha, fecha y dias van nulos y el tramo es 'apertura' (no
--               se inventa el 30-sep); tramo '0-30', '31-60', '61-90',
--               '90+', 'a_favor', 'retencion' o 'apertura' (y sin_fecha =
--               por_pagar en ese tramo);
--   fecha_origen de dónde salió la fecha: 'papel', 'balanza' (QuickBooks),
--               'libro' (el asiento) o nulo (sin fecha);
--   vence       el de la balanza si lo trae; si no, la fecha + los términos
--               del proveedor, leídos en este orden: «Net 10th Prox» o
--               «10 Prox» → el día 10 del mes siguiente; «Net 10 EOM» → fin
--               de mes + 10 días; «Net 10th» → el día 10 del mes siguiente;
--               «Net 30» o «30 días» → 30 días; «EOM» → fin de mes;
--               contado → el mismo día. Nulo si no hay fecha o si los
--               términos no dicen (no se inventa); dias_vencida = días
--               desde que venció.
-- La fila 'total' compara la suma con el mayor de 2010 + 2020 (cuadra).
-- (En cobrar no hace falta: la apertura trae cada cuenta por cobrar con su
-- factura, que tiene su fecha, y sin factura solo saldos a favor.)
-- ---------------------------------------------------------------------
drop view if exists public.v_cxp_antiguedad cascade;
create view public.v_cxp_antiguedad with (security_invoker = true) as
select c.periodo, c.tipo as periodo_tipo, c.corte, x.*
  from public.v_cortes c
  cross join lateral (
    with k as materialized (
      select (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'cxp') as cxp,
             coalesce((select array_agg(m.cuenta order by m.cuenta) from public.v_estados_mapeo m
                        where m.estado = 'balance' and m.linea = 'retencion_por_pagar'), '{}'::text[]) as ret
    ), l as materialized (
      select v.asiento_id, v.numero, v.fecha, v.cuenta, v.monto, v.tercero_tipo, v.tercero_id, v.partida_tabla, v.partida_id,
             v.cuenta = any (k.ret) as es_ret, v.tipo = 'apertura' as de_apertura, v.cadena_pos, v.orden
        from public.v_libro v, k
       where (v.cuenta = k.cxp or v.cuenta = any (k.ret)) and v.fecha <= c.corte
    ), g as materialized (
      select l.partida_tabla, l.partida_id,
             case when l.partida_tabla is null then l.tercero_id end            as tercero_sin_partida,
             min(l.tercero_id) filter (where l.tercero_tipo = 'proveedor')      as tercero_id,
             coalesce(-sum(l.monto) filter (where not l.es_ret), 0)             as por_pagar,
             coalesce(-sum(l.monto) filter (where l.es_ret), 0)                 as retencion,
             coalesce(-sum(l.monto) filter (where l.monto < 0), 0)              as cargos,
             coalesce(sum(l.monto) filter (where l.monto > 0), 0)               as pagos,
             min(l.fecha)                                                       as primera,
             count(distinct l.asiento_id)                                       as asientos,
             min(l.asiento_id::text)                                            as asiento_min,
             min(l.numero)                                                      as numero_min
        from l
       group by l.partida_tabla, l.partida_id, case when l.partida_tabla is null then l.tercero_id end
    ), qb as materialized (
      -- La balanza de QuickBooks que entró al libro (la de la apertura
      -- viva): lo que se le debía a cada proveedor, fila por fila, sin
      -- papel en la app, con su fecha y su vencimiento si los trae.
      select coalesce(b.proveedor_id, al.proveedor_id)::text as tercero_id, b.linea, b.fecha_documento, b.vence, b.referencia,
             coalesce(b.haber, 0) - coalesce(b.debe, 0) as monto, a.fecha_contable as fecha_apertura
        from public.asientos a
        join public.apertura_balanza_qb b on b.documento = a.documento_ruta
        join public.apertura_mapeo_qb m on m.tipo = 'cuenta' and m.clave = b.clave
        cross join k
        left join public.proveedores_alias al
               on b.proveedor_id is null
              and al.alias = nullif(lower(btrim(regexp_replace(coalesce(b.proveedor_qb, ''), '[[:space:]]+', ' ', 'g'))), '')
       where a.tipo = 'apertura' and a.origen_tabla = 'apertura_balanza_qb' and a.fecha_contable <= c.corte
         and coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'
         and a.camino not in ('reverso', 'reverso_automatico')
         and not exists (select 1 from public.asientos x where x.reversa_a = a.id and x.camino = 'reverso')
         and m.cuenta = k.cxp and b.recibo_id is null and b.trabajo_externo_id is null
         and coalesce(b.haber, 0) - coalesce(b.debe, 0) <> 0
    ), la as materialized (
      -- Lo que el libro tiene de la apertura por proveedor, sin papel.
      select l.tercero_id, -sum(l.monto) as monto, min(l.fecha) as fecha_apertura
        from l
       where l.partida_tabla is null and l.de_apertura and not l.es_ret
       group by l.tercero_id
    ), pz as materialized (
      -- Las piezas de lo que se debe sin papel, en su orden: lo de la
      -- apertura factura por factura, si la balanza las trae y suman lo que
      -- el libro tiene de ese proveedor (si no, entero y sin fecha); lo
      -- demás, línea por línea con la fecha de su asiento. monto > 0 es lo
      -- que se debe; < 0, lo que se pagó o abonó.
      select la.tercero_id, q.fecha_documento as fecha, q.vence, q.referencia, q.monto,
             case when q.fecha_documento is not null then 'balanza' end as origen,
             coalesce(q.fecha_documento, la.fecha_apertura) as clave, 0 as o1, q.linea::bigint as o2
        from la
        join qb q on q.tercero_id is not distinct from la.tercero_id
       where la.monto = (select sum(q2.monto) from qb q2 where q2.tercero_id is not distinct from la.tercero_id)
      union all
      select la.tercero_id, null, null, null, la.monto, null, la.fecha_apertura, 0, 0
        from la
       where la.monto <> 0
         and la.monto is distinct from (select sum(q2.monto) from qb q2 where q2.tercero_id is not distinct from la.tercero_id)
      union all
      select l.tercero_id, l.fecha, null, null, -l.monto, 'libro', l.fecha, 1, l.cadena_pos * 1000 + l.orden
        from l
       where l.partida_tabla is null and not l.de_apertura and not l.es_ret
    ), ff as materialized (
      -- Lo más viejo que sigue sin pagar, de cada proveedor.
      select distinct on (y.tercero_id) y.tercero_id, y.fecha, y.vence, y.referencia, y.origen, true as hay
        from (select pz.*,
                     sum(greatest(pz.monto, 0)) over (partition by pz.tercero_id order by pz.clave, pz.o1, pz.o2
                                                      rows between unbounded preceding and current row) as debido,
                     sum(greatest(-pz.monto, 0)) over (partition by pz.tercero_id) as pagado
                from pz) y
       where y.monto > 0 and y.debido > y.pagado
       order by y.tercero_id, y.clave, y.o1, y.o2
    ), a as materialized (
      select g.*,
             case when g.partida_tabla is not null then 'papel' when g.tercero_sin_partida is not null then 'proveedor'
                  else 'sin_partida' end as tipo,
             case when g.partida_tabla = 'recibos' then r.fecha
                  when g.partida_tabla = 'trabajos_externos' then te.fecha
                  when ff.hay then ff.fecha
                  else g.primera end as fecha,
             case when g.partida_tabla in ('recibos', 'trabajos_externos') then 'papel'
                  when ff.hay then ff.origen
                  else 'libro' end as fecha_origen,
             ff.vence as vence_qb,
             coalesce(ff.hay and ff.fecha is null, false) as sin_fecha,
             coalesce(pv.id, pa.id, px.id, pe.id) as proveedor_id,
             case when g.partida_tabla = 'recibos' then r.num_recibo else ff.referencia end as referencia,
             case when g.partida_tabla is null
                  then jsonb_build_object('partida_tabla', null, 'tercero_id', g.tercero_sin_partida)
                  else jsonb_build_object('partida_tabla', g.partida_tabla, 'partida_id', g.partida_id) end as filtros
        from g
        left join ff on g.partida_tabla is null and ff.tercero_id is not distinct from g.tercero_sin_partida
        left join public.recibos r
               on g.partida_tabla = 'recibos'
              and r.id = (case when g.partida_tabla = 'recibos' and g.partida_id ~ '^-?[0-9]{1,18}$' then g.partida_id::bigint end)
        left join public.trabajos_externos te
               on g.partida_tabla = 'trabajos_externos'
              and te.id = (case when g.partida_tabla = 'trabajos_externos' and g.partida_id ~ '^-?[0-9]{1,18}$'
                                then g.partida_id::bigint end)
        left join public.proveedores pv
               on pv.id = (case when g.tercero_id ~ '^[0-9a-f-]{36}$' then g.tercero_id::uuid end)
        left join public.proveedores_alias al
               on al.alias = nullif(lower(btrim(regexp_replace(coalesce(r.proveedor, ''), '[[:space:]]+', ' ', 'g'))), '')
        left join public.proveedores pa on pa.id = al.proveedor_id
        left join public.proveedores px on px.id = te.proveedor_id
        left join public.proveedores pe on pe.externo_id = te.externo_id and te.proveedor_id is null
       where g.por_pagar <> 0 or g.retencion <> 0
    ), t as materialized (
      select a.*, pr.nombre as proveedor, pr.terminos, lower(coalesce(pr.terminos, '')) as tt, c.corte - a.fecha as dias
        from a
        left join public.proveedores pr on pr.id = a.proveedor_id
    ), u as materialized (
      select t.*,
             case when t.vence_qb is not null then t.vence_qb
                  when t.fecha is null then null
                  -- «Net 10th Prox», «10 Prox»: el día 10 del mes siguiente.
                  when t.tt ~ '[0-9]{1,2}[[:space:]]*(st|nd|rd|th)?[[:space:]]*prox'
                    then (date_trunc('month', t.fecha::timestamp) + interval '1 month')::date
                         + least(substring(t.tt from '([0-9]{1,2})[[:space:]]*(?:st|nd|rd|th)?[[:space:]]*prox')::int,
                                 extract(day from date_trunc('month', t.fecha::timestamp) + interval '2 month' - interval '1 day')::int)
                         - 1
                  -- «Net 10 EOM»: fin de mes + 10 días.
                  when t.tt ~ '(net|neto)?[[:space:]]*[0-9]{1,3}[[:space:]]*(eom|fin de mes)'
                    then (date_trunc('month', t.fecha::timestamp) + interval '1 month' - interval '1 day')::date
                         + substring(t.tt from '([0-9]{1,3})[[:space:]]*(?:eom|fin de mes)')::int
                  -- «Net 10th»: el día 10 del mes siguiente.
                  when t.tt ~ '(net|neto)[[:space:]]*[0-9]{1,2}[[:space:]]*(st|nd|rd|th)\M'
                    then (date_trunc('month', t.fecha::timestamp) + interval '1 month')::date
                         + least(substring(t.tt from '(?:net|neto)[[:space:]]*([0-9]{1,2})[[:space:]]*(?:st|nd|rd|th)')::int,
                                 extract(day from date_trunc('month', t.fecha::timestamp) + interval '2 month' - interval '1 day')::int)
                         - 1
                  when t.tt ~ '(net|neto)[[:space:]]*[0-9]{1,3}'
                    then t.fecha + substring(t.tt from '(?:net|neto)[[:space:]]*([0-9]{1,3})')::int
                  when t.tt ~ '[0-9]{1,3}[[:space:]]*(d[ií]as|days)'
                    then t.fecha + substring(t.tt from '([0-9]{1,3})[[:space:]]*(?:d[ií]as|days)')::int
                  when t.tt ~ '(eom|fin de mes)'
                    then (date_trunc('month', t.fecha::timestamp) + interval '1 month' - interval '1 day')::date
                  when t.tt ~ '(contado|cod|c\.o\.d|cash|efectivo|due on receipt|al recibir|prepago|prepaid)'
                    then t.fecha
             end as vence,
             case when t.por_pagar < 0 then 'a_favor'
                  when t.por_pagar = 0 then 'retencion'
                  when t.sin_fecha then 'apertura'
                  when t.dias <= 30 then '0-30'
                  when t.dias <= 60 then '31-60'
                  when t.dias <= 90 then '61-90'
                  else '90+' end as tramo,
             jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
                                'filtros', t.filtros || jsonb_build_object('cuenta', k.cxp)) as s_cxp,
             jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
                                'filtros', t.filtros || jsonb_build_object('cuenta', to_jsonb(k.ret))) as s_ret,
             k.cxp, k.ret
        from t, k
    )
    select 'partida'::text as nivel, u.tipo, u.partida_tabla, u.partida_id, u.proveedor_id, u.proveedor, u.terminos,
           u.referencia, u.fecha, u.fecha_origen, u.dias, u.vence, c.corte - u.vence as dias_vencida, u.tramo,
           u.por_pagar::numeric(14,2) as por_pagar, u.retencion::numeric(14,2) as retencion,
           (u.por_pagar + u.retencion)::numeric(14,2) as total,
           (case when u.tramo = '0-30'  then u.por_pagar else 0 end)::numeric(14,2) as d0_30,
           (case when u.tramo = '31-60' then u.por_pagar else 0 end)::numeric(14,2) as d31_60,
           (case when u.tramo = '61-90' then u.por_pagar else 0 end)::numeric(14,2) as d61_90,
           (case when u.tramo = '90+'   then u.por_pagar else 0 end)::numeric(14,2) as d90_mas,
           (case when u.tramo = 'apertura' then u.por_pagar else 0 end)::numeric(14,2) as sin_fecha,
           (case when u.tramo = 'a_favor' then u.por_pagar else 0 end)::numeric(14,2) as a_favor,
           u.cargos::numeric(14,2) as cargos, u.pagos::numeric(14,2) as pagos,
           u.asientos, case when u.asientos = 1 then u.asiento_min::uuid end as asiento_id,
           case when u.asientos = 1 then u.numero_min end as numero,
           null::numeric(14,2) as mayor, null::boolean as cuadra,
           jsonb_build_object(
             'por_pagar', jsonb_build_array(u.s_cxp),
             'retencion', jsonb_build_array(u.s_ret),
             'total',     jsonb_build_array(u.s_cxp, u.s_ret),
             'd0_30',     case when u.tramo = '0-30'  then jsonb_build_array(u.s_cxp) else '[]'::jsonb end,
             'd31_60',    case when u.tramo = '31-60' then jsonb_build_array(u.s_cxp) else '[]'::jsonb end,
             'd61_90',    case when u.tramo = '61-90' then jsonb_build_array(u.s_cxp) else '[]'::jsonb end,
             'd90_mas',   case when u.tramo = '90+'   then jsonb_build_array(u.s_cxp) else '[]'::jsonb end,
             'sin_fecha', case when u.tramo = 'apertura' then jsonb_build_array(u.s_cxp) else '[]'::jsonb end,
             'a_favor',   case when u.tramo = 'a_favor' then jsonb_build_array(u.s_cxp) else '[]'::jsonb end,
             'cargos',    jsonb_build_array(jsonb_set(jsonb_set(jsonb_set(u.s_cxp, '{campo}', '"haber"'), '{signo}', '1'),
                                                      '{filtros,cuenta}', to_jsonb(array[u.cxp] || u.ret))),
             'pagos',     jsonb_build_array(jsonb_set(jsonb_set(jsonb_set(u.s_cxp, '{campo}', '"debe"'), '{signo}', '1'),
                                                      '{filtros,cuenta}', to_jsonb(array[u.cxp] || u.ret)))) as bajar
      from u
    union all
    select 'total', null, null, null, null, null, null, null, null, null, null, null, null, null,
           coalesce(sum(u.por_pagar), 0)::numeric(14,2), coalesce(sum(u.retencion), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar + u.retencion), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar) filter (where u.tramo = '0-30'), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar) filter (where u.tramo = '31-60'), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar) filter (where u.tramo = '61-90'), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar) filter (where u.tramo = '90+'), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar) filter (where u.tramo = 'apertura'), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar) filter (where u.tramo = 'a_favor'), 0)::numeric(14,2),
           null::numeric(14,2), null::numeric(14,2),
           (select count(distinct l.asiento_id) from l), null, null,
           (select coalesce(-sum(l.monto), 0) from l)::numeric(14,2),
           coalesce(sum(u.por_pagar + u.retencion), 0) = (select coalesce(-sum(l.monto), 0) from l),
           jsonb_build_object(
             'por_pagar', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                            'hasta', c.corte::text, 'filtros', jsonb_build_object('cuenta', (select k.cxp from k)))),
             'retencion', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                            'hasta', c.corte::text, 'filtros', jsonb_build_object('cuenta', (select to_jsonb(k.ret) from k)))),
             'total',     jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                            'hasta', c.corte::text,
                            'filtros', jsonb_build_object('cuenta', (select to_jsonb(array[k.cxp] || k.ret) from k)))),
             'd0_30',     coalesce(jsonb_agg(u.s_cxp) filter (where u.tramo = '0-30'), '[]'::jsonb),
             'd31_60',    coalesce(jsonb_agg(u.s_cxp) filter (where u.tramo = '31-60'), '[]'::jsonb),
             'd61_90',    coalesce(jsonb_agg(u.s_cxp) filter (where u.tramo = '61-90'), '[]'::jsonb),
             'd90_mas',   coalesce(jsonb_agg(u.s_cxp) filter (where u.tramo = '90+'), '[]'::jsonb),
             'sin_fecha', coalesce(jsonb_agg(u.s_cxp) filter (where u.tramo = 'apertura'), '[]'::jsonb),
             'a_favor',   coalesce(jsonb_agg(u.s_cxp) filter (where u.tramo = 'a_favor'), '[]'::jsonb),
             'mayor',     jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                            'hasta', c.corte::text,
                            'filtros', jsonb_build_object('cuenta', (select to_jsonb(array[k.cxp] || k.ret) from k)))))
      from u
    having exists (select 1 from l)
  ) x;

-- ---------------------------------------------------------------------
-- 5.4 · En qué se gasta y a quién.
-- v_gasto_lineas — cada línea de GASTO del libro (las cuentas de costo, de
-- gastos y de otros gastos; gasto = debe − haber: una devolución resta),
-- con su PROVEEDOR, el primero que se sepa en este orden:
--   'linea'      el tercero de la propia línea;
--   'asiento'    el proveedor del mismo asiento (la deuda en 2010 de un
--                recibo a cuenta o de un trabajo externo), si es UNO; si el
--                asiento tiene varios (un devengo de dos subcontratistas),
--                el de la línea de proveedor del mismo monto y de la misma
--                obra (o sin obra), si es una sola;
--   'trabajo_externo' el proveedor del trabajo externo (el que le puso
--                Edgar, o el de su ayudante);
--   'recibo'     el nombre que trae el recibo, casado con proveedores_alias
--                (así «CED» y «Consolidated Electrical» son el mismo);
--   'recibo_sin_alta' el nombre del recibo, sin alta todavía (se agrupa por
--                su nombre escrito sin adornos);
--   'varios'     un asiento con varios proveedores que no se puede repartir
--                línea por línea: sale junto, «Varios proveedores (asiento
--                sin repartir)», en vez de adivinar a cuál se le carga (el
--                clic lleva al asiento, donde se ven);
--   nulo         sin proveedor (un asiento a mano, la nómina).
-- proveedor_clave agrupa: 'id:<uuid>', 'txt:<nombre>', 'varios' o
-- 'ninguno'.
-- (Los papeles, los alias y los nombres se casan con JOIN, una lectura de
-- cada tabla por consulta: buscarlos con una subconsulta por línea, con la
-- policy de cada tabla y una llave calculada, recorría la tabla entera por
-- cada línea de gasto: miles de veces.)
-- ---------------------------------------------------------------------
drop view if exists public.v_gasto_lineas cascade;
create view public.v_gasto_lineas with (security_invoker = true) as
select y.asiento_id, y.numero, y.orden, y.fecha, y.periodo, y.anio, y.ejercicio, y.tipo, y.camino, y.descripcion,
       y.origen_tabla, y.origen_id, y.cuenta, y.cuenta_nombre, y.seccion, y.linea, y.monto,
       y.monto::numeric(14,2) as gasto,
       y.proyecto_id, y.cost_code, y.memo,
       y.proveedor_id,
       coalesce(pn.nombre, y.recibo_texto,
                case when y.fuente = 'varios' then 'Varios proveedores (asiento sin repartir)' end) as proveedor,
       y.fuente                                                                                  as proveedor_fuente,
       coalesce('id:' || y.proveedor_id::text, 'txt:' || y.recibo_clave,
                case when y.fuente = 'varios' then 'varios' end, 'ninguno')                      as proveedor_clave
  from (select z.*,
               coalesce(z.prov_linea, z.prov_asiento, z.prov_externo, z.prov_recibo)             as proveedor_id,
               case when z.prov_linea is not null then 'linea'
                    when z.prov_asiento is not null then 'asiento'
                    when z.prov_externo is not null then 'trabajo_externo'
                    when z.prov_recibo is not null then 'recibo'
                    when z.recibo_clave is not null then 'recibo_sin_alta'
                    when z.varios then 'varios' end                                              as fuente
          from (select x.asiento_id, x.numero, x.orden, x.fecha, x.periodo, x.anio, x.ejercicio, x.tipo, x.camino,
                       x.descripcion, x.origen_tabla, x.origen_id, x.cuenta, x.cuenta_nombre, x.seccion, x.linea, x.monto,
                       x.proyecto_id, x.cost_code, x.memo,
                       case when x.tercero_tipo = 'proveedor' and x.tercero_id ~ '^[0-9a-f-]{36}$'
                            then x.tercero_id::uuid end                                           as prov_linea,
                       case when x.prov_min = x.prov_max and x.prov_min ~ '^[0-9a-f-]{36}$' then x.prov_min::uuid
                            -- Varios proveedores en el asiento: el de la línea
                            -- de su deuda del mismo monto y obra, si es uno
                            -- solo (una búsqueda por el asiento, solo en
                            -- estos asientos, que son pocos).
                            when x.prov_min <> x.prov_max
                              then (select min(o.tercero_id)::uuid
                                      from public.asiento_lineas o
                                     where o.asiento_id = x.asiento_id and o.tercero_tipo = 'proveedor'
                                       and o.tercero_id ~ '^[0-9a-f-]{36}$' and o.monto = -x.monto
                                       and (o.proyecto_id is null or o.proyecto_id = x.proyecto_id)
                                    having count(distinct o.tercero_id) = 1) end                  as prov_asiento,
                       coalesce(x.prov_min <> x.prov_max, false)                                  as varios,
                       coalesce(te.proveedor_id, pe.id)                                           as prov_externo,
                       pa.proveedor_id                                                            as prov_recibo,
                       nullif(btrim(r.proveedor), '')                                             as recibo_texto,
                       nullif(regexp_replace(lower(coalesce(r.proveedor, '')), '[^0-9a-z]', '', 'g'), '') as recibo_clave
                  from (select v.*,
                               -- Los proveedores del asiento (partido también
                               -- por período y fecha: ver v_flujo_lineas).
                               min(v.tercero_id) filter (where v.tercero_tipo = 'proveedor') over w as prov_min,
                               max(v.tercero_id) filter (where v.tercero_tipo = 'proveedor') over w as prov_max,
                               -- (La llave de su papel, ya calculada: el join va
                               -- por la llave primaria, sin recorrer la tabla por
                               -- cada línea.)
                               case when v.origen_tabla = 'recibos' and v.origen_id ~ '^-?[0-9]{1,18}$'
                                    then v.origen_id::bigint end as recibo_id,
                               case when v.origen_tabla = 'trabajos_externos' and v.origen_id ~ '^-?[0-9]{1,18}$'
                                    then v.origen_id::bigint end as trabajo_id
                          from public.v_libro v
                        window w as (partition by v.periodo, v.fecha, v.asiento_id)) x
                  left join public.recibos r on r.id = x.recibo_id
                  left join public.trabajos_externos te on te.id = x.trabajo_id
                  left join public.proveedores pe on pe.externo_id = te.externo_id and te.proveedor_id is null
                  left join public.proveedores_alias pa
                         on pa.alias = nullif(lower(btrim(regexp_replace(coalesce(r.proveedor, ''), '[[:space:]]+', ' ', 'g'))), '')
                 where x.estado = 'resultados' and x.seccion in ('costo', 'gastos', 'otros_gastos')) z) y
  left join public.proveedores pn on pn.id = y.proveedor_id;

-- v_gasto_por_categoria — por período, el gasto de cada cuenta de gasto
-- (la categoría del libro: material, subcontratos, renta, gasolina…): lo
-- del período (mes), lo del año (acumulado) y su parte del total del
-- período (pct). Del ejercicio del período, como el estado de resultados:
-- la suma de mes es el costo más los gastos de v_resultados. La fila
-- 'total' lo suma.
drop view if exists public.v_gasto_por_categoria cascade;
create view public.v_gasto_por_categoria with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.desde, p.hasta, x.*
  from public.periodos p
  cross join lateral (
    with g as materialized (
      select gl.cuenta, gl.seccion,
             coalesce(sum(gl.gasto) filter (where gl.fecha >= p.desde), 0) as mes,
             sum(gl.gasto)                                                 as acumulado,
             count(distinct gl.asiento_id) filter (where gl.fecha >= p.desde) as asientos,
             min(gl.asiento_id::text) filter (where gl.fecha >= p.desde)   as asiento_min,
             min(gl.numero) filter (where gl.fecha >= p.desde)             as numero_min
        from public.v_gasto_lineas gl
       where gl.ejercicio = p.anio and gl.fecha between make_date(p.anio, 1, 1) and p.hasta
       group by gl.cuenta, gl.seccion
    ), t as materialized (
      select coalesce(sum(g.mes), 0) as mes from g
    )
    select 'cuenta'::text as nivel, g.cuenta, m.etiqueta_es, m.etiqueta_en, g.seccion, m.orden,
           g.mes::numeric(14,2) as mes, g.acumulado::numeric(14,2) as acumulado,
           case when t.mes <> 0 then round(100 * g.mes / t.mes, 1) end as pct,
           g.asientos, case when g.asientos = 1 then g.asiento_min::uuid end as asiento_id,
           case when g.asientos = 1 then g.numero_min end as numero,
           jsonb_build_object(
             'mes',       jsonb_build_array(jsonb_build_object('vista', 'v_gasto_lineas', 'campo', 'gasto', 'signo', 1,
                            'filtros', jsonb_build_object('cuenta', g.cuenta, 'ejercicio', p.anio),
                            'desde', p.desde::text, 'hasta', p.hasta::text)),
             'acumulado', jsonb_build_array(jsonb_build_object('vista', 'v_gasto_lineas', 'campo', 'gasto', 'signo', 1,
                            'filtros', jsonb_build_object('cuenta', g.cuenta, 'ejercicio', p.anio),
                            'desde', make_date(p.anio, 1, 1)::text, 'hasta', p.hasta::text))) as bajar
      from g
      cross join t
      join public.v_estados_mapeo m on m.cuenta = g.cuenta
    union all
    select 'total', null, 'Total', 'Total', null, 999999, t.mes::numeric(14,2),
           (select coalesce(sum(g.acumulado), 0) from g)::numeric(14,2), 100, null, null, null,
           jsonb_build_object(
             'mes',       jsonb_build_array(jsonb_build_object('vista', 'v_gasto_lineas', 'campo', 'gasto', 'signo', 1,
                            'filtros', jsonb_build_object('ejercicio', p.anio), 'desde', p.desde::text, 'hasta', p.hasta::text)),
             'acumulado', jsonb_build_array(jsonb_build_object('vista', 'v_gasto_lineas', 'campo', 'gasto', 'signo', 1,
                            'filtros', jsonb_build_object('ejercicio', p.anio),
                            'desde', make_date(p.anio, 1, 1)::text, 'hasta', p.hasta::text)))
      from t
     where exists (select 1 from g)
  ) x;

-- v_gasto_por_proveedor — por período, el gasto de cada proveedor (el de
-- v_gasto_lineas), con las cuentas en que cayó. Mismos números que por
-- categoría, cortados de otra forma: los dos totales son iguales.
drop view if exists public.v_gasto_por_proveedor cascade;
create view public.v_gasto_por_proveedor with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.desde, p.hasta, x.*
  from public.periodos p
  cross join lateral (
    with g as materialized (
      select gl.proveedor_clave, min(gl.proveedor_id::text)::uuid as proveedor_id, min(gl.proveedor) as proveedor,
             min(gl.proveedor_fuente) as fuente,
             coalesce(sum(gl.gasto) filter (where gl.fecha >= p.desde), 0) as mes,
             sum(gl.gasto)                                                 as acumulado,
             array_agg(distinct gl.cuenta order by gl.cuenta) filter (where gl.fecha >= p.desde) as cuentas,
             count(distinct gl.asiento_id) filter (where gl.fecha >= p.desde) as asientos,
             min(gl.asiento_id::text) filter (where gl.fecha >= p.desde)   as asiento_min,
             min(gl.numero) filter (where gl.fecha >= p.desde)             as numero_min
        from public.v_gasto_lineas gl
       where gl.ejercicio = p.anio and gl.fecha between make_date(p.anio, 1, 1) and p.hasta
       group by gl.proveedor_clave
    ), t as materialized (
      select coalesce(sum(g.mes), 0) as mes from g
    )
    select 'proveedor'::text as nivel, g.proveedor_clave, g.proveedor_id,
           coalesce(g.proveedor, 'Sin proveedor') as proveedor, g.fuente, g.cuentas,
           g.mes::numeric(14,2) as mes, g.acumulado::numeric(14,2) as acumulado,
           case when t.mes <> 0 then round(100 * g.mes / t.mes, 1) end as pct,
           g.asientos, case when g.asientos = 1 then g.asiento_min::uuid end as asiento_id,
           case when g.asientos = 1 then g.numero_min end as numero,
           jsonb_build_object(
             'mes',       jsonb_build_array(jsonb_build_object('vista', 'v_gasto_lineas', 'campo', 'gasto', 'signo', 1,
                            'filtros', jsonb_build_object('proveedor_clave', g.proveedor_clave, 'ejercicio', p.anio),
                            'desde', p.desde::text, 'hasta', p.hasta::text)),
             'acumulado', jsonb_build_array(jsonb_build_object('vista', 'v_gasto_lineas', 'campo', 'gasto', 'signo', 1,
                            'filtros', jsonb_build_object('proveedor_clave', g.proveedor_clave, 'ejercicio', p.anio),
                            'desde', make_date(p.anio, 1, 1)::text, 'hasta', p.hasta::text))) as bajar
      from g
      cross join t
    union all
    select 'total', null, null, 'Total', null, null, t.mes::numeric(14,2),
           (select coalesce(sum(g.acumulado), 0) from g)::numeric(14,2), 100, null, null, null,
           jsonb_build_object(
             'mes',       jsonb_build_array(jsonb_build_object('vista', 'v_gasto_lineas', 'campo', 'gasto', 'signo', 1,
                            'filtros', jsonb_build_object('ejercicio', p.anio), 'desde', p.desde::text, 'hasta', p.hasta::text)),
             'acumulado', jsonb_build_array(jsonb_build_object('vista', 'v_gasto_lineas', 'campo', 'gasto', 'signo', 1,
                            'filtros', jsonb_build_object('ejercicio', p.anio),
                            'desde', make_date(p.anio, 1, 1)::text, 'hasta', p.hasta::text)))
      from t
     where exists (select 1 from g)
  ) x;

-- ---------------------------------------------------------------------
-- 5.5 · v_costo_por_obra — por período, el ingreso y el costo de cada obra
-- por cuenta (las de resultados que van por obra: 4xxx y 5xxx), con lo del
-- período, lo del año y lo de toda la obra EN EL LIBRO (desde_inicio: sus
-- líneas hasta el fin del período, de todos los años: el costo de una obra
-- que cruza de año). El libro empieza el día después de la apertura
-- (libro_desde): lo de antes está en QuickBooks, y una obra que ya
-- andaba entonces sale con parcial = true (tiene saldo en la apertura, o
-- facturas, recibos o trabajos externos de antes): su desde_inicio no es
-- la obra entera. La obra nula = líneas de esas cuentas sin obra.
-- Niveles: 'cuenta' (obra y cuenta); 'obra' (por obra, cuatro renglones:
-- ingresos, costo, margen = ingresos − costo, y otros = lo demás de
-- resultados con esa obra, como la chatarra vendida en 4900: ingreso en
-- positivo, gasto en negativo; margen + otros = el resultado de la obra);
-- y 'control': por cuenta, lo REPARTIDO por obra (del_anio: las líneas
-- con obra) más lo SIN REPARTIR (sin_repartir: las líneas sin obra,
-- incluidas las cuentas que no van por obra, como el burden aplicado
-- 5011, el real 5015 y su variación 5019) contra el mayor de la cuenta; y
-- una fila por sección (ingresos y costo, cuenta nula) con lo mismo
-- contra el total de la sección del MAYOR (el estado de resultados), con
-- todas sus cuentas. Las cuentas del control salen del mayor, no del
-- auxiliar: una cuenta de costo que el auxiliar dejara fuera sale en rojo
-- (antes el control sumaba las mismas líneas contra sí mismas y dejaba
-- fuera 5011, 5015 y 5019: no podía salir en rojo, y 300 de burden sin
-- repartir no salían en ninguna fila). Lo sin repartir es la partida de
-- conciliación, a la vista; si al cierre tiene que quedar en cero lo
-- decide f08. Cifras con el signo del estado de resultados (ingreso y
-- costo en positivo).
-- ---------------------------------------------------------------------
drop view if exists public.v_costo_por_obra cascade;
create view public.v_costo_por_obra with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.desde, p.hasta, x.*
  from public.periodos p
  cross join lateral (
    with lb as materialized (
      select coalesce((select pa.hasta + 1 from public.periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1),
                      (select min(pm.desde) from public.periodos pm where pm.tipo = 'mes')) as libro_desde
    ), l as materialized (
      -- Las de resultados que van por obra (o que la traen) y TODAS las de
      -- ingresos y costo (las que no van por obra, sin repartir).
      select v.cuenta, v.seccion, v.signo, v.proyecto_id, v.monto, v.fecha, v.ejercicio, v.asiento_id, v.numero
        from public.v_libro v
        join public.cuentas cu on cu.codigo = v.cuenta
       where v.estado = 'resultados' and v.fecha <= p.hasta
         and (cu.regla_obra <> 'prohibida' or v.proyecto_id is not null or v.seccion in ('ingresos', 'costo'))
    ), mx as materialized (
      -- El mayor del año, por cuenta de ingresos y de costo (aparte del
      -- auxiliar: de aquí salen las cuentas del control).
      select v.cuenta, min(v.seccion) as seccion, min(v.signo) as signo, sum(v.monto) as s
        from public.v_libro v
       where v.estado = 'resultados' and v.seccion in ('ingresos', 'costo') and v.ejercicio = p.anio and v.fecha <= p.hasta
       group by v.cuenta
    ), g as materialized (
      select l.proyecto_id, l.cuenta, min(l.seccion) as seccion, min(l.signo) as signo,
             coalesce(sum(l.monto) filter (where l.ejercicio = p.anio and l.fecha >= p.desde), 0) as s_per,
             coalesce(sum(l.monto) filter (where l.ejercicio = p.anio), 0)                        as s_anio,
             sum(l.monto)                                                                         as s_ini,
             count(distinct l.asiento_id) filter (where l.ejercicio = p.anio and l.fecha >= p.desde) as asientos,
             min(l.asiento_id::text) filter (where l.ejercicio = p.anio and l.fecha >= p.desde)   as asiento_min,
             min(l.numero) filter (where l.ejercicio = p.anio and l.fecha >= p.desde)             as numero_min
        from l
       group by l.proyecto_id, l.cuenta
    ), s as materialized (
      select g.*,
             jsonb_build_object('proyecto_id', g.proyecto_id, 'cuenta', g.cuenta) as filtros
        from g
    ), pc as materialized (
      -- Las obras que ya andaban antes del libro.
      select distinct y.proyecto_id
        from (select a.proyecto_id from public.asiento_lineas a join public.asientos h on h.id = a.asiento_id
               where h.tipo = 'apertura' and a.proyecto_id is not null
              union all
              select f.proyecto_id from public.facturas f, lb where f.fecha < lb.libro_desde
              union all
              select r.proyecto_id from public.recibos r, lb where r.fecha < lb.libro_desde
              union all
              select te.proyecto_id from public.trabajos_externos te, lb where te.fecha < lb.libro_desde) y
       where y.proyecto_id is not null
    )
    select 'cuenta'::text as nivel, s.proyecto_id,
           coalesce(pr.nombre, case when s.proyecto_id is null then 'Sin repartir por obra' end) as obra, pr.cliente, s.cuenta,
           m.etiqueta_es, m.etiqueta_en, s.seccion, m.orden,
           (s.signo * s.s_per)::numeric(14,2) as del_periodo, (s.signo * s.s_anio)::numeric(14,2) as del_anio,
           (s.signo * s.s_ini)::numeric(14,2) as desde_inicio,
           lb.libro_desde, s.proyecto_id is not null and exists (select 1 from pc where pc.proyecto_id = s.proyecto_id) as parcial,
           s.asientos, case when s.asientos = 1 then s.asiento_min::uuid end as asiento_id,
           case when s.asientos = 1 then s.numero_min end as numero,
           null::numeric(14,2) as sin_repartir, null::numeric(14,2) as mayor, null::boolean as cuadra,
           jsonb_build_object(
             'del_periodo',  jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', s.signo,
                               'filtros', s.filtros || jsonb_build_object('ejercicio', p.anio),
                               'desde', p.desde::text, 'hasta', p.hasta::text)),
             'del_anio',     jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', s.signo,
                               'filtros', s.filtros || jsonb_build_object('ejercicio', p.anio), 'hasta', p.hasta::text)),
             'desde_inicio', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', s.signo,
                               'filtros', s.filtros, 'hasta', p.hasta::text))) as bajar
      from s
      cross join lb
      join public.v_estados_mapeo m on m.cuenta = s.cuenta
      left join public.proyectos pr on pr.id = s.proyecto_id
    union all
    -- Por obra: ingresos, costo, margen (= ingresos − costo) y otros.
    select 'obra', s.proyecto_id, coalesce(min(pr.nombre), case when s.proyecto_id is null then 'Sin repartir por obra' end),
           min(pr.cliente), null, z.linea, z.linea_en, z.linea, z.orden,
           sum(case when s.seccion = any (z.secc) or (z.linea = 'otros' and not s.seccion = any (array['ingresos', 'costo']))
                    then z.signo * coalesce(z.fijo, s.signo) * s.s_per else 0 end)::numeric(14,2),
           sum(case when s.seccion = any (z.secc) or (z.linea = 'otros' and not s.seccion = any (array['ingresos', 'costo']))
                    then z.signo * coalesce(z.fijo, s.signo) * s.s_anio else 0 end)::numeric(14,2),
           sum(case when s.seccion = any (z.secc) or (z.linea = 'otros' and not s.seccion = any (array['ingresos', 'costo']))
                    then z.signo * coalesce(z.fijo, s.signo) * s.s_ini else 0 end)::numeric(14,2),
           min(lb.libro_desde), s.proyecto_id is not null and exists (select 1 from pc where pc.proyecto_id = s.proyecto_id),
           null, null, null, null::numeric(14,2), null::numeric(14,2), null,
           jsonb_build_object(
             'del_periodo',  coalesce(jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto',
                               'signo', z.signo * coalesce(z.fijo, s.signo),
                               'filtros', s.filtros || jsonb_build_object('ejercicio', p.anio),
                               'desde', p.desde::text, 'hasta', p.hasta::text))
                             filter (where s.seccion = any (z.secc)
                                        or (z.linea = 'otros' and not s.seccion = any (array['ingresos', 'costo']))), '[]'::jsonb),
             'del_anio',     coalesce(jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto',
                               'signo', z.signo * coalesce(z.fijo, s.signo),
                               'filtros', s.filtros || jsonb_build_object('ejercicio', p.anio), 'hasta', p.hasta::text))
                             filter (where s.seccion = any (z.secc)
                                        or (z.linea = 'otros' and not s.seccion = any (array['ingresos', 'costo']))), '[]'::jsonb),
             'desde_inicio', coalesce(jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto',
                               'signo', z.signo * coalesce(z.fijo, s.signo),
                               'filtros', s.filtros, 'hasta', p.hasta::text))
                             filter (where s.seccion = any (z.secc)
                                        or (z.linea = 'otros' and not s.seccion = any (array['ingresos', 'costo']))), '[]'::jsonb))
      from s
      cross join lb
      -- (secc: las secciones que suma; signo y fijo: la cifra es signo ×
      -- (fijo, o el signo de la cuenta) × (debe − haber). El margen, −1 en
      -- ingresos y costo: ingreso − costo.)
      cross join (values ('ingresos', 'Revenue',                 1, array['ingresos'],          1,  null::int),
                         ('costo',    'Cost',                    2, array['costo'],             1,  null),
                         ('margen',   'Margin',                  3, array['ingresos', 'costo'], -1, 1),
                         ('otros',    'Other income and expense', 4, array[]::text[],           -1, 1))
                  as z(linea, linea_en, orden, secc, signo, fijo)
      left join public.proyectos pr on pr.id = s.proyecto_id
     group by s.proyecto_id, z.linea, z.linea_en, z.orden
    union all
    -- El control, cuenta por cuenta (lo del año): repartido por obra + sin
    -- repartir = mayor. Las cuentas salen del mayor (las de ingresos y
    -- costo) y del auxiliar.
    select 'control', null, null, null, k.cuenta, m.etiqueta_es, m.etiqueta_en, coalesce(k.seccion, m.seccion), m.orden,
           null::numeric(14,2), (k.signo * k.rep)::numeric(14,2), null::numeric(14,2), lb.libro_desde, null,
           null, null, null,
           (k.signo * k.sin)::numeric(14,2), (k.signo * k.mayor)::numeric(14,2), k.rep + k.sin = k.mayor,
           jsonb_build_object(
             -- (lo repartido: todas sus líneas del año menos las que no tienen obra)
             'del_anio', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', k.signo,
                           'filtros', jsonb_build_object('cuenta', k.cuenta, 'ejercicio', p.anio), 'hasta', p.hasta::text),
                                           jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -k.signo,
                           'filtros', jsonb_build_object('cuenta', k.cuenta, 'ejercicio', p.anio, 'proyecto_id', null),
                           'hasta', p.hasta::text)),
             'sin_repartir', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', k.signo,
                           'filtros', jsonb_build_object('cuenta', k.cuenta, 'ejercicio', p.anio, 'proyecto_id', null),
                           'hasta', p.hasta::text)),
             'mayor',    jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', k.signo,
                           'filtros', jsonb_build_object('cuenta', k.cuenta, 'ejercicio', p.anio), 'hasta', p.hasta::text)))
      from (select coalesce(sx.cuenta, mx.cuenta) as cuenta, coalesce(sx.seccion, mx.seccion) as seccion,
                   coalesce(sx.signo, mx.signo) as signo, coalesce(sx.rep, 0) as rep, coalesce(sx.sin, 0) as sin,
                   coalesce(mx.s, (select coalesce(sum(v.monto), 0) from public.v_libro v
                                    where v.cuenta = sx.cuenta and v.ejercicio = p.anio and v.fecha <= p.hasta)) as mayor
              from (select s.cuenta, min(s.seccion) as seccion, min(s.signo) as signo,
                           coalesce(sum(s.s_anio) filter (where s.proyecto_id is not null), 0) as rep,
                           coalesce(sum(s.s_anio) filter (where s.proyecto_id is null), 0) as sin
                      from s group by s.cuenta) sx
              full join mx on mx.cuenta = sx.cuenta) k
      cross join lb
      join public.v_estados_mapeo m on m.cuenta = k.cuenta
    union all
    -- Y por sección: el costo (y el ingreso) repartido por obra más lo sin
    -- repartir contra el total de la sección en el mayor (el estado de
    -- resultados), con todas sus cuentas.
    select 'control', null, null, null, null, z.etiqueta_es, z.etiqueta_en, z.seccion, 0,
           null::numeric(14,2),
           (z.signo * coalesce((select sum(s.s_anio) from s where s.seccion = z.seccion and s.proyecto_id is not null), 0))
             ::numeric(14,2),
           null::numeric(14,2), lb.libro_desde, null, null, null, null,
           (z.signo * coalesce((select sum(s.s_anio) from s where s.seccion = z.seccion and s.proyecto_id is null), 0))
             ::numeric(14,2),
           (z.signo * coalesce((select sum(mx.s) from mx where mx.seccion = z.seccion), 0))::numeric(14,2),
           coalesce((select sum(s.s_anio) from s where s.seccion = z.seccion), 0)
             = coalesce((select sum(mx.s) from mx where mx.seccion = z.seccion), 0),
           jsonb_build_object(
             'del_anio', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', z.signo,
                           'filtros', jsonb_build_object('estado', 'resultados', 'seccion', z.seccion, 'ejercicio', p.anio),
                           'hasta', p.hasta::text),
                                           jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -z.signo,
                           'filtros', jsonb_build_object('estado', 'resultados', 'seccion', z.seccion, 'ejercicio', p.anio,
                                                         'proyecto_id', null),
                           'hasta', p.hasta::text)),
             'sin_repartir', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', z.signo,
                           'filtros', jsonb_build_object('estado', 'resultados', 'seccion', z.seccion, 'ejercicio', p.anio,
                                                         'proyecto_id', null),
                           'hasta', p.hasta::text)),
             'mayor',    jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', z.signo,
                           'filtros', jsonb_build_object('estado', 'resultados', 'seccion', z.seccion, 'ejercicio', p.anio),
                           'hasta', p.hasta::text)))
      from (values ('ingresos', -1, 'Ingresos: repartido por obra + sin repartir = el estado de resultados',
                    'Revenue: allocated to jobs + unallocated = income statement'),
                   ('costo', 1, 'Costo de obra: repartido por obra + sin repartir = el estado de resultados',
                    'Cost of revenue: allocated to jobs + unallocated = income statement')) as z(seccion, signo, etiqueta_es, etiqueta_en)
      cross join lb
     where exists (select 1 from s)
  ) x;

-- ---------------------------------------------------------------------
-- 5.6 · v_obras_dinero — el dinero de cada obra a cada corte (el panel
-- «dinero por obra»), todo del libro, que empieza el día después de la
-- apertura (libro_desde):
--   por_cobrar_apertura lo que la obra traía por cobrar al 30-sep (sus
--               líneas de 1110 y 1120 en el asiento de apertura: facturas
--               de QuickBooks todavía abiertas);
--   facturado   el ingreso de la obra en el libro (4xxx con su obra, neto
--               de notas de crédito y descuentos);
--   cobrado     el DINERO que entró por la obra: lo que sus cuentas por
--               cobrar (1110, 1120) y sus ingresos explican del banco, en
--               asientos que mueven dinero (un cobro de 2,500 con 50 de
--               descuento son 2,450; un cheque devuelto resta; sin la
--               apertura);
--   otros       lo que movió sus cuentas por cobrar sin dinero y sin
--               ingreso (un castigo, un asiento a mano);
--   por_cobrar  su saldo en 1110 (anticipos restando) y retencion en 1120.
--               cuadra: por_cobrar_apertura + facturado − cobrado + otros
--               = por_cobrar + retencion (fn_estados_control lo vigila);
--   costo       su costo en el libro (5xxx con su obra), y de él
--               mano_de_obra (50xx), material (5100) y subcontratos (5200);
--   margen      facturado − costo, y margen_pct sobre lo facturado;
--   parcial     la obra ya andaba antes del libro (tiene saldo en la
--               apertura, o facturas, recibos o trabajos externos de
--               antes): su ingreso y su costo de antes están en QuickBooks,
--               y el margen es solo el del libro (la pantalla lo dice).
-- El contrato y el presupuesto NO son del libro (viven en la app:
-- finanzas_proyecto, estimados): la pantalla los pone al lado.
-- Una fila por obra con algún movimiento hasta el corte.
-- ---------------------------------------------------------------------
drop view if exists public.v_obras_dinero cascade;
create view public.v_obras_dinero with (security_invoker = true) as
select c.periodo, c.tipo as periodo_tipo, c.corte, x.*
  from public.v_cortes c
  cross join lateral (
    with k as materialized (
      select (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'cxc')           as cxc,
             (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'retencion_cxc') as ret,
             coalesce((select pa.hasta + 1 from public.periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1),
                      (select min(pm.desde) from public.periodos pm where pm.tipo = 'mes')) as libro_desde
    ), l as materialized (
      select v.proyecto_id, v.cuenta, v.estado, v.seccion, v.monto, v.asiento_id, v.tipo
        from public.v_libro v
       where v.proyecto_id is not null and v.fecha <= c.corte
    ), fl as materialized (
      -- Lo de sus cuentas por cobrar y sus ingresos, con dinero y sin él
      -- (sin la apertura).
      select f.proyecto_id,
             coalesce(sum(f.importe) filter (where f.toca_efectivo), 0)      as cobrado,
             coalesce(-sum(f.importe) filter (where not f.toca_efectivo), 0) as otros
        from public.v_flujo_lineas f, k
       where f.proyecto_id is not null and f.fecha <= c.corte and f.pieza = 'linea' and f.tipo <> 'apertura'
         and (f.cuenta in (k.cxc, k.ret) or f.seccion = 'ingresos')
       group by f.proyecto_id
    ), g as materialized (
      select l.proyecto_id,
             coalesce(sum(l.monto) filter (where l.tipo = 'apertura' and l.cuenta in (k.cxc, k.ret)), 0) as por_cobrar_apertura,
             coalesce(-sum(l.monto) filter (where l.seccion = 'ingresos'), 0)                     as facturado,
             coalesce(sum(l.monto) filter (where l.cuenta = k.cxc), 0)                            as por_cobrar,
             coalesce(sum(l.monto) filter (where l.cuenta = k.ret), 0)                            as retencion,
             coalesce(sum(l.monto) filter (where l.seccion = 'costo'), 0)                         as costo,
             coalesce(sum(l.monto) filter (where l.seccion = 'costo' and l.cuenta like '50%'), 0) as mano_de_obra,
             coalesce(sum(l.monto) filter (where l.cuenta = '5100'), 0)                           as material,
             coalesce(sum(l.monto) filter (where l.cuenta = '5200'), 0)                           as subcontratos,
             count(distinct l.asiento_id)                                                         as asientos,
             bool_or(l.tipo = 'apertura')                                                         as en_apertura
        from l, k
       group by l.proyecto_id
    ), pc as materialized (
      -- Las obras con papeles de antes del libro.
      select distinct y.proyecto_id
        from (select f.proyecto_id from public.facturas f, k where f.fecha < k.libro_desde
              union all
              select r.proyecto_id from public.recibos r, k where r.fecha < k.libro_desde
              union all
              select te.proyecto_id from public.trabajos_externos te, k where te.fecha < k.libro_desde) y
       where y.proyecto_id is not null
    ), s as materialized (
      select jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'hasta', c.corte::text) as base,
             jsonb_build_object('pieza', 'linea', 'tipo_no', 'apertura') as fb
    )
    select g.proyecto_id, pr.nombre as obra, pr.cliente, pr.estado as obra_estado,
           g.por_cobrar_apertura::numeric(14,2) as por_cobrar_apertura,
           g.facturado::numeric(14,2) as facturado, coalesce(fl.cobrado, 0)::numeric(14,2) as cobrado,
           coalesce(fl.otros, 0)::numeric(14,2) as otros,
           g.por_cobrar::numeric(14,2) as por_cobrar, g.retencion::numeric(14,2) as retencion,
           g.por_cobrar_apertura + g.facturado - coalesce(fl.cobrado, 0) + coalesce(fl.otros, 0) = g.por_cobrar + g.retencion
             as cuadra,
           g.costo::numeric(14,2) as costo, g.mano_de_obra::numeric(14,2) as mano_de_obra,
           g.material::numeric(14,2) as material, g.subcontratos::numeric(14,2) as subcontratos,
           (g.facturado - g.costo)::numeric(14,2) as margen,
           case when g.facturado <> 0 then round(100 * (g.facturado - g.costo) / g.facturado, 1) end as margen_pct,
           k.libro_desde, g.en_apertura or pc.proyecto_id is not null as parcial,
           g.asientos,
           jsonb_build_object(
             'por_cobrar_apertura', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'hasta', c.corte::text,
                               'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'tipo', 'apertura',
                                                             'cuenta', jsonb_build_array(k.cxc, k.ret)))),
             'facturado',    jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                               'hasta', c.corte::text,
                               'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'seccion', 'ingresos'))),
             'cobrado',      jsonb_build_array(
                               s.base || jsonb_build_object('signo', 1, 'filtros', s.fb || jsonb_build_object(
                                 'proyecto_id', g.proyecto_id, 'toca_efectivo', true, 'cuenta', jsonb_build_array(k.cxc, k.ret))),
                               s.base || jsonb_build_object('signo', 1, 'filtros', s.fb || jsonb_build_object(
                                 'proyecto_id', g.proyecto_id, 'toca_efectivo', true, 'seccion', 'ingresos'))),
             'otros',        jsonb_build_array(
                               s.base || jsonb_build_object('signo', -1, 'filtros', s.fb || jsonb_build_object(
                                 'proyecto_id', g.proyecto_id, 'toca_efectivo', false, 'cuenta', jsonb_build_array(k.cxc, k.ret))),
                               s.base || jsonb_build_object('signo', -1, 'filtros', s.fb || jsonb_build_object(
                                 'proyecto_id', g.proyecto_id, 'toca_efectivo', false, 'seccion', 'ingresos'))),
             'por_cobrar',   jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'hasta', c.corte::text, 'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'cuenta', k.cxc))),
             'retencion',    jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'hasta', c.corte::text, 'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'cuenta', k.ret))),
             'costo',        jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'hasta', c.corte::text, 'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'seccion', 'costo'))),
             'mano_de_obra', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'hasta', c.corte::text,
                               'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'seccion', 'costo',
                                                             'cuenta', coalesce((select jsonb_agg(cu.codigo order by cu.codigo)
                                                                                   from public.cuentas cu where cu.codigo like '50%'),
                                                                                '[]'::jsonb)))),
             'material',     jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'hasta', c.corte::text, 'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'cuenta', '5100'))),
             'subcontratos', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'hasta', c.corte::text, 'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'cuenta', '5200'))),
             'margen',       jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                               'hasta', c.corte::text,
                               'filtros', jsonb_build_object('proyecto_id', g.proyecto_id,
                                                             'seccion', jsonb_build_array('ingresos', 'costo'))))) as bajar
      from g
      cross join k
      cross join s
      left join fl on fl.proyecto_id = g.proyecto_id
      left join pc on pc.proyecto_id = g.proyecto_id
      left join public.proyectos pr on pr.id = g.proyecto_id
  ) x;


-- =====================================================================
-- 6 · QUICKBOOKS: LA COMPARACIÓN
-- =====================================================================

-- (6.1 · v_qb_balanzas está en la sección 3 (3.6): el balance general la
-- usa para el resultado de enero a septiembre de la apertura.)

-- ---------------------------------------------------------------------
-- 6.2 · v_comparacion — el libro contra QuickBooks, cuenta por cuenta, en
-- cada período que tiene una balanza de QuickBooks (la de la apertura, y
-- las que Edgar cargue: fin de octubre, noviembre, la preliminar y la
-- final de diciembre):
--   libro       el saldo del libro a la fecha de la balanza (al: la del
--               cierre del período, o la que dijo su carga, como la de una
--               quincena de f13-14): las cuentas de balance, toda su
--               historia; las de resultados, lo del año (como la balanza de
--               QuickBooks). Antes siempre al último día del período: la
--               balanza del 15-dic salía con todo lo posteado después del 15
--               como diferencia sin explicar;
--   arrastre_apertura  solo en los períodos de 2026 posteriores a la
--               apertura: el libro empezó el 30-sep con el resultado de
--               enero a septiembre DENTRO de 3900 (la apertura es balance
--               únicamente), y QuickBooks lo sigue teniendo en cada cuenta
--               de resultados. Para comparar igual, a cada cuenta de
--               resultados se le suma lo que la balanza de apertura traía en
--               ella, y a 3900 se le resta el total. En la apertura misma
--               es al revés: las cuentas de resultados de QuickBooks se
--               comparan dentro de 3900 (como las posteó fn_apertura);
--   posteriores si la balanza de QuickBooks del período es la FINAL (se
--               cargó con p_con_posteriores: ya trae los ajustes del CPA),
--               los ajuste_cpa del libro fechados después del período que
--               lo corrigen (efectivo_hasta hasta su último día; en el año,
--               su ejercicio), como las columnas «ajustadas» del balance y
--               de resultados. Con la preliminar, 0;
--   comparable  libro + arrastre_apertura + posteriores;
--   qb          la suma de las filas de QuickBooks mapeadas a la cuenta;
--   diferencia  comparable − qb;
--   explicada   lo que explican las diferencias ANOTADAS vivas del período
--               y la cuenta (fn_diferencia_anotar), por clase (clases);
--   sin_explicar diferencia − explicada; ok = sin_explicar = 0.
-- Cada cifra trae su «bajar» (la diferencia baja al libro, al arrastre, a
-- los posteriores y, restando, a QuickBooks; sin_explicar, además, a las
-- anotaciones, restando).
-- Una fila de QuickBooks sin mapeo sale sola (cuenta nula, cuenta_qb con
-- su nombre) y en rojo. «Cero diferencias sin explicar» es la meta de cada
-- mes del paralelo.
-- ---------------------------------------------------------------------
drop view if exists public.v_comparacion_resumen cascade;
drop view if exists public.v_comparacion cascade;
create view public.v_comparacion with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.hasta as corte,
       coalesce((select max(b.al) from public.v_qb_balanzas b where b.periodo = p.periodo and b.vigente), p.hasta) as al,
       p.anio, x.*
  from public.periodos p
  cross join lateral (
    with q as materialized (
      select b.* from public.v_qb_balanzas b where b.periodo = p.periodo and b.vigente
    ), pq as materialized (
      -- ¿La balanza vigente es la final (trae los ajustes del CPA)? Y con
      -- qué filtros se baja a esos ajustes (por FECHA: el período que
      -- corrigen termina a más tardar el último día de este). al: la fecha
      -- de la balanza (su carga la dijo; si no, el fin del período).
      select coalesce(bool_or(q.con_posteriores), false) as con,
             coalesce(max(q.al), p.hasta) as al,
             case when p.tipo = 'anio' then jsonb_build_object('tipo', 'ajuste_cpa', 'ejercicio_hasta', p.anio)
                  else jsonb_build_object('tipo', 'ajuste_cpa', 'efectivo_hasta_hasta', p.hasta) end as filtros
        from q
    ), apx as materialized (
      -- La apertura: su período, su año y su balanza (la del asiento vivo).
      select ap.periodo as ap_periodo, ap.anio as ap_anio, ap.hasta as ap_hasta
        from public.periodos ap
       where ap.tipo = 'apertura'
    ), jan as materialized (
      -- Lo que la balanza de apertura traía en cada cuenta de resultados
      -- (enero a septiembre): solo para los períodos del año de la
      -- apertura, posteriores a ella.
      select b.cuenta, sum(b.saldo) as saldo
        from public.v_qb_balanzas b, apx
       where b.periodo = apx.ap_periodo and b.fuente = 'apertura_balanza_qb'
         and b.cuenta_tipo not in ('activo', 'pasivo', 'capital')
         and p.anio = apx.ap_anio and p.hasta > apx.ap_hasta and p.periodo <> apx.ap_periodo
       group by b.cuenta
    ), qa as materialized (
      -- QuickBooks por cuenta del plan. En la apertura, sus cuentas de
      -- resultados van a 3900 (como las posteó fn_apertura).
      select case when p.tipo = 'apertura' and q.cuenta_tipo not in ('activo', 'pasivo', 'capital') then '3900'
                  else q.cuenta end as cuenta,
             sum(q.saldo) as qb,
             array_agg(distinct q.cuenta_qb order by q.cuenta_qb) as cuentas_qb,
             min(q.documento) as documento, min(q.fuente) as fuente
        from q
       where q.cuenta is not null
       group by 1
    ), l as materialized (
      select v.cuenta, v.estado,
             coalesce(sum(v.monto) filter (where v.fecha <= pq.al), 0) as libro,
             coalesce(sum(v.monto) filter (where v.fecha > p.hasta), 0) as posteriores,
             count(distinct v.asiento_id) filter (where v.fecha <= pq.al) as asientos,
             min(v.asiento_id::text) filter (where v.fecha <= pq.al) as asiento_min,
             min(v.numero) filter (where v.fecha <= pq.al) as numero_min
        from public.v_libro v, pq
       where (v.estado = 'balance' or v.ejercicio = p.anio)
         and (v.fecha <= pq.al
              or (pq.con and v.tipo = 'ajuste_cpa' and v.fecha > p.hasta
                  and case when p.tipo = 'anio' then v.ejercicio <= p.anio else v.efectivo_hasta <= p.hasta end))
         and exists (select 1 from q)
       group by v.cuenta, v.estado
    ), d as materialized (
      select dd.cuenta, sum(dd.monto) as explicada, array_agg(distinct dd.clase order by dd.clase) as clases,
             count(*) as anotadas
        from public.diferencias dd
       where dd.periodo = p.periodo and dd.retirada_el is null
       group by dd.cuenta
    ), u as materialized (
      select coalesce(qa.cuenta, l.cuenta, jan.cuenta, d.cuenta) as cuenta,
             coalesce(l.libro, 0) as libro, coalesce(l.posteriores, 0) as posteriores,
             coalesce(jan.saldo, 0)
               - case when coalesce(qa.cuenta, l.cuenta, jan.cuenta, d.cuenta) = '3900'
                      then coalesce((select sum(j2.saldo) from jan j2), 0) else 0 end as arrastre,
             coalesce(qa.qb, 0) as qb, qa.cuentas_qb, qa.documento,
             coalesce(d.explicada, 0) as explicada, d.clases, coalesce(d.anotadas, 0) as anotadas,
             coalesce(l.asientos, 0) as asientos, l.asiento_min, l.numero_min
        from qa
        full join l on l.cuenta = qa.cuenta
        full join jan on jan.cuenta = coalesce(qa.cuenta, l.cuenta)
        full join d on d.cuenta = coalesce(qa.cuenta, l.cuenta, jan.cuenta)
    ), b as materialized (
      -- Los pedazos de cada cifra.
      select u.*, m.cuenta_nombre, m.estado, m.orden,
             jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
               'hasta', pq.al::text,
               'filtros', jsonb_build_object('cuenta', u.cuenta)
                          || case when m.estado = 'resultados' then jsonb_build_object('ejercicio', p.anio)
                                  else '{}'::jsonb end)) as b_libro,
             case when not pq.con or u.posteriores = 0 then '[]'::jsonb
                  else jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                         'desde', (p.hasta + 1)::text,
                         'filtros', jsonb_build_object('cuenta', u.cuenta)
                                    || case when m.estado = 'resultados' then jsonb_build_object('ejercicio', p.anio)
                                            else '{}'::jsonb end
                                    || pq.filtros)) end as b_post,
             case when p.tipo = 'apertura' and u.cuenta = '3900'
                  then jsonb_build_array(
                         jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                           'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true, 'cuenta', '3900')),
                         jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                           'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true,
                                        'cuenta_tipo_no', jsonb_build_array('activo', 'pasivo', 'capital'))))
                  when p.tipo = 'apertura' and m.estado = 'resultados' then '[]'::jsonb
                  else jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                         'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true, 'cuenta', u.cuenta)))
             end as b_qb,
             case when u.arrastre = 0 then '[]'::jsonb
                  else jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo',
                         'signo', case when u.cuenta = '3900' then -1 else 1 end,
                         'filtros', jsonb_build_object('fuente', 'apertura_balanza_qb',
                                      'cuenta_tipo_no', jsonb_build_array('activo', 'pasivo', 'capital'))
                                    || case when u.cuenta = '3900' then '{}'::jsonb
                                            else jsonb_build_object('cuenta', u.cuenta) end)) end as b_arr,
             jsonb_build_array(jsonb_build_object('vista', 'diferencias', 'campo', 'monto', 'signo', 1,
               'filtros', jsonb_build_object('periodo', p.periodo, 'cuenta', u.cuenta, 'retirada_el', null))) as b_expl
        from u
        cross join pq
        left join public.v_estados_mapeo m on m.cuenta = u.cuenta
       where u.libro <> 0 or u.qb <> 0 or u.arrastre <> 0 or u.posteriores <> 0 or u.anotadas > 0
    ), n as materialized (
      -- Los mismos pedazos, restando (para la diferencia y lo sin explicar).
      select b.cuenta,
             (select coalesce(jsonb_agg(jsonb_set(e, '{signo}', to_jsonb(-(e->>'signo')::int))), '[]'::jsonb)
                from jsonb_array_elements(b.b_qb) e) as n_qb,
             (select coalesce(jsonb_agg(jsonb_set(e, '{signo}', to_jsonb(-(e->>'signo')::int))), '[]'::jsonb)
                from jsonb_array_elements(b.b_expl) e) as n_expl
        from b
    )
    select 'cuenta'::text as nivel, b.cuenta, b.cuenta_nombre, b.estado, b.orden, null::text as cuenta_qb, b.cuentas_qb,
           b.libro::numeric(14,2) as libro, b.arrastre::numeric(14,2) as arrastre_apertura,
           b.posteriores::numeric(14,2) as posteriores,
           (b.libro + b.arrastre + b.posteriores)::numeric(14,2) as comparable, b.qb::numeric(14,2) as qb,
           (b.libro + b.arrastre + b.posteriores - b.qb)::numeric(14,2) as diferencia, b.explicada::numeric(14,2) as explicada,
           (b.libro + b.arrastre + b.posteriores - b.qb - b.explicada)::numeric(14,2) as sin_explicar,
           b.libro + b.arrastre + b.posteriores - b.qb - b.explicada = 0 as ok, b.clases, b.anotadas, b.asientos,
           case when b.asientos = 1 then b.asiento_min::uuid end as asiento_id,
           case when b.asientos = 1 then b.numero_min end as numero,
           jsonb_build_object(
             'libro',             b.b_libro,
             'arrastre_apertura', b.b_arr,
             'posteriores',       b.b_post,
             'comparable',        b.b_libro || b.b_arr || b.b_post,
             'qb',                b.b_qb,
             'diferencia',        b.b_libro || b.b_arr || b.b_post || n.n_qb,
             'explicada',         b.b_expl,
             'sin_explicar',      b.b_libro || b.b_arr || b.b_post || n.n_qb || n.n_expl) as bajar
      from b
      join n on n.cuenta is not distinct from b.cuenta
    union all
    -- Lo que QuickBooks trae y no está mapeado.
    select 'sin_mapeo', null, null, null, 999999, q.cuenta_qb, null, 0::numeric(14,2), 0::numeric(14,2), 0::numeric(14,2),
           0::numeric(14,2), sum(q.saldo)::numeric(14,2), (-sum(q.saldo))::numeric(14,2), 0::numeric(14,2),
           (-sum(q.saldo))::numeric(14,2), false, null, 0, 0, null, null,
           jsonb_build_object(
             'libro', '[]'::jsonb, 'arrastre_apertura', '[]'::jsonb, 'posteriores', '[]'::jsonb, 'comparable', '[]'::jsonb,
             'explicada', '[]'::jsonb,
             'qb', jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                     'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true, 'clave', q.clave, 'cuenta', null))),
             'diferencia', jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', -1,
                     'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true, 'clave', q.clave, 'cuenta', null))),
             'sin_explicar', jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', -1,
                     'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true, 'clave', q.clave, 'cuenta', null))))
      from q
     where q.cuenta is null
     group by q.cuenta_qb, q.clave
    having sum(q.saldo) <> 0
  ) x
 where exists (select 1 from public.v_qb_balanzas b where b.periodo = p.periodo and b.vigente);

-- ---------------------------------------------------------------------
-- 6.3 · v_comparacion_obra — lo mismo, por obra, en las cuentas que la
-- balanza vigente del período trae por Customer:Job (o por factura, en la
-- apertura): el saldo del libro de esa cuenta en esa obra contra el de
-- QuickBooks. En una cuenta que QuickBooks NO trae por obra (la balanza
-- mensual de siempre no trae Customer:Job), una diferencia anotada con
-- obra explica la fila por cuenta de v_comparacion y no abre filas por
-- obra (fn_diferencia_anotar lo avisa).
--   arrastre_apertura  como en v_comparacion, por obra: lo que la balanza
--               de apertura traía de esa cuenta de resultados en esa obra
--               (enero a septiembre), en los períodos de 2026 posteriores;
--   posteriores como en v_comparacion (la balanza final), por obra;
--   comparable = libro + arrastre_apertura + posteriores; diferencia =
--   comparable − qb; explicada: las diferencias anotadas con esa obra y no
--   retiradas; sin_explicar = diferencia − explicada.
-- ---------------------------------------------------------------------
drop view if exists public.v_comparacion_obra cascade;
create view public.v_comparacion_obra with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.hasta as corte,
       coalesce((select max(b.al) from public.v_qb_balanzas b where b.periodo = p.periodo and b.vigente), p.hasta) as al,
       x.*
  from public.periodos p
  cross join lateral (
    with qv as materialized (
      select b.* from public.v_qb_balanzas b where b.periodo = p.periodo and b.vigente
    ), pq as materialized (
      select coalesce(bool_or(qv.con_posteriores), false) as con,
             coalesce(max(qv.al), p.hasta) as al,
             case when p.tipo = 'anio' then jsonb_build_object('tipo', 'ajuste_cpa', 'ejercicio_hasta', p.anio)
                  else jsonb_build_object('tipo', 'ajuste_cpa', 'efectivo_hasta_hasta', p.hasta) end as filtros
        from qv
    ), q as materialized (
      select qv.cuenta, qv.proyecto_id, sum(qv.saldo) as qb, array_agg(distinct qv.cuenta_qb order by qv.cuenta_qb) as cuentas_qb
        from qv
       where qv.cuenta is not null and qv.proyecto_id is not null
         and (p.tipo <> 'apertura' or qv.cuenta_tipo in ('activo', 'pasivo', 'capital'))
       group by qv.cuenta, qv.proyecto_id
    ), cq as materialized (
      -- Las cuentas que QuickBooks trae por obra en este período.
      select distinct q.cuenta from q
    ), apx as materialized (
      select ap.periodo as ap_periodo, ap.anio as ap_anio, ap.hasta as ap_hasta
        from public.periodos ap
       where ap.tipo = 'apertura'
    ), jan as materialized (
      -- Enero a septiembre de cada cuenta de resultados en cada obra.
      select b.cuenta, b.proyecto_id, sum(b.saldo) as saldo
        from public.v_qb_balanzas b, apx
       where b.periodo = apx.ap_periodo and b.fuente = 'apertura_balanza_qb'
         and b.cuenta_tipo not in ('activo', 'pasivo', 'capital') and b.proyecto_id is not null
         and b.cuenta in (select cq.cuenta from cq)
         and p.anio = apx.ap_anio and p.hasta > apx.ap_hasta and p.periodo <> apx.ap_periodo
       group by b.cuenta, b.proyecto_id
    ), d as materialized (
      select dd.cuenta, dd.proyecto_id, sum(dd.monto) as explicada, array_agg(distinct dd.clase order by dd.clase) as clases
        from public.diferencias dd
       where dd.periodo = p.periodo and dd.retirada_el is null and dd.proyecto_id is not null
         and dd.cuenta in (select cq.cuenta from cq)
       group by dd.cuenta, dd.proyecto_id
    ), l as materialized (
      select v.cuenta, v.estado, v.proyecto_id,
             coalesce(sum(v.monto) filter (where v.fecha <= pq.al), 0) as libro,
             coalesce(sum(v.monto) filter (where v.fecha > p.hasta), 0) as posteriores,
             count(distinct v.asiento_id) filter (where v.fecha <= pq.al) as asientos,
             min(v.asiento_id::text) filter (where v.fecha <= pq.al) as asiento_min,
             min(v.numero) filter (where v.fecha <= pq.al) as numero_min
        from public.v_libro v, pq
       where (v.estado = 'balance' or v.ejercicio = p.anio)
         and (v.fecha <= pq.al
              or (pq.con and v.tipo = 'ajuste_cpa' and v.fecha > p.hasta
                  and case when p.tipo = 'anio' then v.ejercicio <= p.anio else v.efectivo_hasta <= p.hasta end))
         and v.cuenta in (select cq.cuenta from cq)
       group by v.cuenta, v.estado, v.proyecto_id
    ), u as materialized (
      select coalesce(q.cuenta, l.cuenta, jan.cuenta, d.cuenta) as cuenta,
             coalesce(q.proyecto_id, l.proyecto_id, jan.proyecto_id, d.proyecto_id) as proyecto_id,
             coalesce(l.libro, 0) as libro, coalesce(l.posteriores, 0) as posteriores, coalesce(jan.saldo, 0) as arrastre,
             coalesce(q.qb, 0) as qb, q.cuentas_qb, coalesce(d.explicada, 0) as explicada, d.clases,
             coalesce(l.asientos, 0) as asientos, l.asiento_min, l.numero_min
        from q
        full join l on l.cuenta = q.cuenta and l.proyecto_id = q.proyecto_id
        full join jan on jan.cuenta = coalesce(q.cuenta, l.cuenta) and jan.proyecto_id = coalesce(q.proyecto_id, l.proyecto_id)
        full join d on d.cuenta = coalesce(q.cuenta, l.cuenta, jan.cuenta)
                   and d.proyecto_id = coalesce(q.proyecto_id, l.proyecto_id, jan.proyecto_id)
    ), b as materialized (
      select u.*, m.cuenta_nombre, m.estado,
             jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
               'hasta', pq.al::text,
               'filtros', jsonb_build_object('cuenta', u.cuenta, 'proyecto_id', u.proyecto_id)
                          || case when m.estado = 'resultados' then jsonb_build_object('ejercicio', p.anio)
                                  else '{}'::jsonb end)) as b_libro,
             case when not pq.con or u.posteriores = 0 then '[]'::jsonb
                  else jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                         'desde', (p.hasta + 1)::text,
                         'filtros', jsonb_build_object('cuenta', u.cuenta, 'proyecto_id', u.proyecto_id)
                                    || case when m.estado = 'resultados' then jsonb_build_object('ejercicio', p.anio)
                                            else '{}'::jsonb end
                                    || pq.filtros)) end as b_post,
             case when u.arrastre = 0 then '[]'::jsonb
                  else jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                         'filtros', jsonb_build_object('fuente', 'apertura_balanza_qb', 'cuenta', u.cuenta,
                                                       'proyecto_id', u.proyecto_id))) end as b_arr,
             jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
               'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true, 'cuenta', u.cuenta,
                                             'proyecto_id', u.proyecto_id))) as b_qb,
             jsonb_build_array(jsonb_build_object('vista', 'diferencias', 'campo', 'monto', 'signo', 1,
               'filtros', jsonb_build_object('periodo', p.periodo, 'cuenta', u.cuenta, 'proyecto_id', u.proyecto_id,
                                             'retirada_el', null))) as b_expl
        from u
        cross join pq
        left join public.v_estados_mapeo m on m.cuenta = u.cuenta
       where u.proyecto_id is not null
         and (u.libro <> 0 or u.qb <> 0 or u.explicada <> 0 or u.arrastre <> 0 or u.posteriores <> 0)
    )
    select b.cuenta, b.cuenta_nombre, b.proyecto_id, pr.nombre as obra, b.cuentas_qb,
           b.libro::numeric(14,2) as libro, b.arrastre::numeric(14,2) as arrastre_apertura,
           b.posteriores::numeric(14,2) as posteriores,
           (b.libro + b.arrastre + b.posteriores)::numeric(14,2) as comparable,
           b.qb::numeric(14,2) as qb, (b.libro + b.arrastre + b.posteriores - b.qb)::numeric(14,2) as diferencia,
           b.explicada::numeric(14,2) as explicada,
           (b.libro + b.arrastre + b.posteriores - b.qb - b.explicada)::numeric(14,2) as sin_explicar,
           b.libro + b.arrastre + b.posteriores - b.qb - b.explicada = 0 as ok, b.clases, b.asientos,
           case when b.asientos = 1 then b.asiento_min::uuid end as asiento_id,
           case when b.asientos = 1 then b.numero_min end as numero,
           jsonb_build_object(
             'libro',             b.b_libro,
             'arrastre_apertura', b.b_arr,
             'posteriores',       b.b_post,
             'comparable',        b.b_libro || b.b_arr || b.b_post,
             'qb',                b.b_qb,
             'diferencia',        b.b_libro || b.b_arr || b.b_post || n.n_qb,
             'explicada',         b.b_expl,
             'sin_explicar',      b.b_libro || b.b_arr || b.b_post || n.n_qb || n.n_expl) as bajar
      from b
      cross join lateral (
        select (select coalesce(jsonb_agg(jsonb_set(e, '{signo}', to_jsonb(-(e->>'signo')::int))), '[]'::jsonb)
                  from jsonb_array_elements(b.b_qb) e) as n_qb,
               (select coalesce(jsonb_agg(jsonb_set(e, '{signo}', to_jsonb(-(e->>'signo')::int))), '[]'::jsonb)
                  from jsonb_array_elements(b.b_expl) e) as n_expl) n
      left join public.proyectos pr on pr.id = b.proyecto_id
  ) x;

-- ---------------------------------------------------------------------
-- 6.4 · v_comparacion_resumen — una fila por período con balanza de
-- QuickBooks: cuántas cuentas cuadran, cuánto queda sin explicar (la suma
-- de lo sin explicar de cada cuenta, en valor absoluto: una de +100 y otra
-- de −100 son 200 por explicar), y la UTILIDAD del libro contra la de
-- QuickBooks (la del Panel: «utilidad del mes contra QuickBooks»):
--   utilidad_libro / utilidad_qb        lo que va del año (con el arrastre
--                                       de la apertura en 2026);
--   utilidad_mes_libro / utilidad_mes_qb la del mes: la de QuickBooks es su
--                                       acumulado menos el del período
--                                       anterior (si ese período tiene
--                                       balanza, o es la apertura).
-- Cada cifra baja a los mismos pedazos que las filas de v_comparacion que
-- la suman (con su signo), y la del mes, además, a los del período
-- anterior (restando); de la apertura, a su balanza.
-- ---------------------------------------------------------------------
create view public.v_comparacion_resumen with (security_invoker = true) as
with v as materialized (
  select * from public.v_comparacion
), c as materialized (
  select v.periodo, v.periodo_tipo, v.corte, v.anio,
         count(*) filter (where v.nivel = 'cuenta')                                        as cuentas,
         count(*) filter (where v.ok)                                                      as cuentas_ok,
         count(*) filter (where not v.ok)                                                  as cuentas_mal,
         count(*) filter (where v.nivel = 'sin_mapeo')                                     as sin_mapeo,
         coalesce(sum(abs(v.sin_explicar)), 0)                                             as sin_explicar,
         -sum(v.comparable) filter (where v.estado = 'resultados')                         as utilidad_libro,
         -sum(v.qb) filter (where v.estado = 'resultados')                                 as utilidad_qb
    from v
   group by v.periodo, v.periodo_tipo, v.corte, v.anio
), pz as materialized (
  -- Los pedazos de cada cifra del resumen, período por período.
  select v.periodo, 'utilidad_libro'::text as k, jsonb_set(e, '{signo}', to_jsonb(-(e->>'signo')::int)) as spec
    from v, jsonb_array_elements(v.bajar->'comparable') e
   where v.estado = 'resultados'
  union all
  select v.periodo, 'utilidad_qb', jsonb_set(e, '{signo}', to_jsonb(-(e->>'signo')::int))
    from v, jsonb_array_elements(v.bajar->'qb') e
   where v.estado = 'resultados'
  union all
  select v.periodo, 'sin_explicar', jsonb_set(e, '{signo}', to_jsonb(sign(v.sin_explicar)::int * (e->>'signo')::int))
    from v, jsonb_array_elements(v.bajar->'sin_explicar') e
   where v.sin_explicar <> 0
), bz as materialized (
  select pz.periodo,
         coalesce(jsonb_agg(pz.spec) filter (where pz.k = 'utilidad_libro'), '[]'::jsonb) as b_ul,
         coalesce(jsonb_agg(pz.spec) filter (where pz.k = 'utilidad_qb'), '[]'::jsonb)    as b_uq,
         coalesce(jsonb_agg(pz.spec) filter (where pz.k = 'sin_explicar'), '[]'::jsonb)   as b_se
    from pz
   group by pz.periodo
), r as materialized (
  select c.*, coalesce(bz.b_ul, '[]'::jsonb) as b_ul, coalesce(bz.b_uq, '[]'::jsonb) as b_uq,
         coalesce(bz.b_se, '[]'::jsonb) as b_se,
         (select coalesce(jsonb_agg(jsonb_set(e, '{signo}', to_jsonb(-(e->>'signo')::int))), '[]'::jsonb)
            from jsonb_array_elements(coalesce(bz.b_uq, '[]'::jsonb)) e) as n_uq,
         (select coalesce(jsonb_agg(jsonb_set(e, '{signo}', to_jsonb(-(e->>'signo')::int))), '[]'::jsonb)
            from jsonb_array_elements(coalesce(bz.b_ul, '[]'::jsonb)) e) as n_ul
    from c
    left join bz on bz.periodo = c.periodo
)
select r.periodo, r.periodo_tipo, r.corte, r.cuentas, r.cuentas_ok, r.cuentas_mal, r.sin_mapeo,
       r.sin_explicar::numeric(14,2) as sin_explicar, r.cuentas_mal = 0 as ok,
       coalesce(r.utilidad_libro, 0)::numeric(14,2) as utilidad_libro,
       coalesce(r.utilidad_qb, 0)::numeric(14,2)    as utilidad_qb,
       (coalesce(r.utilidad_libro, 0) - coalesce(r.utilidad_qb, 0))::numeric(14,2) as utilidad_diferencia,
       (case when r.periodo_tipo = 'mes' and ant.periodo is not null
             then coalesce(r.utilidad_libro, 0) - coalesce(ant.utilidad_libro, 0) end)::numeric(14,2) as utilidad_mes_libro,
       (case when r.periodo_tipo = 'mes' and ant.periodo is not null
             then coalesce(r.utilidad_qb, 0) - coalesce(ant.utilidad_qb, 0) end)::numeric(14,2)    as utilidad_mes_qb,
       ant.periodo as periodo_anterior,
       jsonb_build_object(
         'sin_explicar',        r.b_se,
         'utilidad_libro',      r.b_ul,
         'utilidad_qb',         r.b_uq,
         'utilidad_diferencia', r.b_ul || r.n_uq,
         'utilidad_mes_libro',  case when r.periodo_tipo = 'mes' and ant.periodo is not null
                                     then r.b_ul || ant.n_libro else '[]'::jsonb end,
         'utilidad_mes_qb',     case when r.periodo_tipo = 'mes' and ant.periodo is not null
                                     then r.b_uq || ant.n_qb else '[]'::jsonb end) as bajar
  from r
  left join lateral (
    -- El período anterior con balanza: el mes anterior, o la apertura si
    -- es octubre. Su utilidad «comparable» de la apertura es la de enero a
    -- septiembre (la de QuickBooks, dentro de 3900). n_libro y n_qb: sus
    -- pedazos, para restarlos.
    select a.periodo,
           case when a.periodo_tipo = 'apertura'
                then coalesce((select -sum(b.saldo) from public.v_qb_balanzas b
                                where b.periodo = a.periodo and b.fuente = 'apertura_balanza_qb'
                                  and b.cuenta_tipo not in ('activo', 'pasivo', 'capital')), 0)
                else a.utilidad_libro end as utilidad_libro,
           case when a.periodo_tipo = 'apertura'
                then coalesce((select -sum(b.saldo) from public.v_qb_balanzas b
                                where b.periodo = a.periodo and b.vigente
                                  and b.cuenta_tipo not in ('activo', 'pasivo', 'capital')), 0)
                else a.utilidad_qb end as utilidad_qb,
           case when a.periodo_tipo = 'apertura'
                then jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                       'filtros', jsonb_build_object('periodo', a.periodo, 'fuente', 'apertura_balanza_qb',
                                                     'cuenta_tipo_no', jsonb_build_array('activo', 'pasivo', 'capital'))))
                else a.n_ul end as n_libro,
           case when a.periodo_tipo = 'apertura'
                then jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                       'filtros', jsonb_build_object('periodo', a.periodo, 'vigente', true,
                                                     'cuenta_tipo_no', jsonb_build_array('activo', 'pasivo', 'capital'))))
                else a.n_uq end as n_qb
      from r a
     where a.corte = (select max(p2.hasta) from public.periodos p2
                       where p2.tipo in ('mes', 'apertura') and p2.hasta < r.corte)
       and a.periodo_tipo in ('mes', 'apertura')
       and extract(year from a.corte) = r.anio
  ) ant on true;


-- =====================================================================
-- 7 · LAS FUNCIONES (todas desde el SQL Editor: ninguna es de la API,
--     salvo fn_estados_control, en 8). Ninguna es SECURITY DEFINER: corren
--     con los permisos de quien las llama, el dueño de la base. Cada una
--     mira antes que sea el dueño (o el SQL Editor), y cada cambio que
--     hacen queda en estados_historial por los triggers de 1.6.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 7.0 · Ayudantes internos.
-- ---------------------------------------------------------------------
-- Un monto que llega de fuera (un CSV de QuickBooks, lo que Edgar teclea):
-- texto o número JSON, con coma de miles o sin ella, con signo menos o entre
-- paréntesis (como los pone QuickBooks). Nunca más de dos decimales: el
-- redondeo se decide en el origen (MX005, como en c2). Vacío = nulo.
create or replace function public.fn_estados_monto(p_valor jsonb, p_que text)
returns numeric
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  v_txt text;
  v_neg boolean := false;
  v_n   numeric;
begin
  if p_valor is null or jsonb_typeof(p_valor) = 'null' then
    return null;
  end if;
  v_txt := btrim(case when jsonb_typeof(p_valor) = 'string' then p_valor #>> '{}' else p_valor::text end);
  if v_txt = '' then
    return null;
  end if;
  if v_txt ~ '^\(.*\)$' then
    v_neg := true;
    v_txt := btrim(substr(v_txt, 2, length(v_txt) - 2));
  end if;
  v_txt := replace(replace(v_txt, '$', ''), ' ', '');
  if v_txt ~ '^[+-]?[0-9]{1,3}(,[0-9]{3})+(\.[0-9]*)?$' then
    v_txt := replace(v_txt, ',', '');
  end if;
  if v_txt !~ '^[+-]?([0-9]+(\.[0-9]*)?|\.[0-9]+)$' then
    raise exception using errcode = 'MX005', message = format('%s: «%s» no es un monto.', p_que, p_valor #>> '{}');
  end if;
  v_n := v_txt::numeric;
  if scale(v_n) > 2 and v_n <> round(v_n, 2) then
    raise exception using errcode = 'MX005',
      message = format('%s: %s trae más de dos decimales; el libro va en centavos.', p_que, v_txt);
  end if;
  if abs(v_n) >= 1000000000000 then
    raise exception using errcode = 'MX005', message = format('%s: %s está fuera de rango.', p_que, v_txt);
  end if;
  return round(case when v_neg then -v_n else v_n end, 2);
end $$;
revoke execute on function public.fn_estados_monto(jsonb, text) from public, anon, authenticated, service_role;

-- La llave con que se casa un nombre de QuickBooks (la misma expresión de
-- las columnas generadas de 1.5).
create or replace function public.fn_estados_clave_qb(p text)
returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select nullif(lower(btrim(regexp_replace(regexp_replace(coalesce(p, ''), '[[:space:]]+', ' ', 'g'),
                                           '[[:space:]]*:[[:space:]]*', ':', 'g'))), '')
$$;
revoke execute on function public.fn_estados_clave_qb(text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 7.1 · El mapeo de los estados.
-- ---------------------------------------------------------------------
-- Ajustar dónde sale UNA cuenta: p_cambios con las llaves que cambian
-- (seccion, linea, orden, etiqueta_es, etiqueta_en, efectivo,
-- flujo_directo, flujo_indirecto, notas). El estado, el signo y «contra»
-- no se mandan: salen de la cuenta y de su sección. La guarda (1.6) dice en
-- español lo que no cuadra; el historial guarda el antes y el después.
--   select fn_estados_mapeo('5010', '{"linea": "mano_de_obra"}');
create or replace function public.fn_estados_mapeo(p_cuenta text, p_cambios jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_sobra text;
  v_c     cuentas;
  v_m     estados_mapeo;
  v_secc  text;
  v_signo smallint;
begin
  perform fn_estados_exigir_dueno();
  if p_cambios is null or jsonb_typeof(p_cambios) <> 'object' then
    raise exception using errcode = '22023', message = 'Los cambios llegan como un objeto JSON, p. ej. {"linea": "mano_de_obra"}.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p_cambios) k
   where k not in ('seccion', 'linea', 'orden', 'etiqueta_es', 'etiqueta_en', 'efectivo', 'flujo_directo', 'flujo_indirecto', 'notas');
  if v_sobra is not null then
    raise exception using errcode = '22023',
      message = format('Llave que no se cambia aquí: %s (el estado, el signo y «contra» salen de la cuenta y de su sección).', v_sobra);
  end if;
  select * into v_c from cuentas where codigo = p_cuenta;
  if not found then
    raise exception using errcode = 'MX004', message = format('La cuenta %s no existe en el plan.', coalesce(p_cuenta, '(nula)'));
  end if;
  -- Sin fila todavía: primero la propuesta.
  insert into estados_mapeo (cuenta, estado, seccion, linea, orden, signo, contra, efectivo, flujo_directo, flujo_indirecto)
  select p.cuenta, p.estado, p.seccion, p.linea, p.orden, p.signo, p.contra, p.efectivo, p.flujo_directo, p.flujo_indirecto
    from v_estados_mapeo_propuesto p
   where p.cuenta = p_cuenta
     and not exists (select 1 from estados_mapeo m where m.cuenta = p_cuenta)
  on conflict (cuenta) do nothing;
  select * into v_m from estados_mapeo where cuenta = p_cuenta for update;
  v_secc  := coalesce(p_cambios->>'seccion', v_m.seccion);
  v_signo := case when v_secc in ('activo_circulante', 'activo_fijo', 'otros_activos', 'costo', 'gastos', 'otros_gastos')
                  then 1 else -1 end;
  begin
    update estados_mapeo
       set seccion         = v_secc,
           -- Cambiar de sección sin decir el renglón: en resultados, el de
           -- la sección; en el balance hay que decirlo.
           linea           = coalesce(p_cambios->>'linea',
                                      case when p_cambios ? 'seccion' and v_m.estado = 'resultados' then v_secc else v_m.linea end),
           orden           = coalesce((p_cambios->>'orden')::int, v_m.orden),
           etiqueta_es     = case when p_cambios ? 'etiqueta_es' then nullif(btrim(p_cambios->>'etiqueta_es'), '')
                                  else v_m.etiqueta_es end,
           etiqueta_en     = case when p_cambios ? 'etiqueta_en' then nullif(btrim(p_cambios->>'etiqueta_en'), '')
                                  else v_m.etiqueta_en end,
           efectivo        = coalesce((p_cambios->>'efectivo')::boolean, v_m.efectivo),
           flujo_directo   = coalesce(p_cambios->>'flujo_directo', v_m.flujo_directo),
           flujo_indirecto = coalesce(p_cambios->>'flujo_indirecto', v_m.flujo_indirecto),
           notas           = case when p_cambios ? 'notas' then nullif(btrim(p_cambios->>'notas'), '') else v_m.notas end,
           signo           = v_signo,
           contra          = v_c.saldo_normal <> case when v_signo = 1 then 'debe' else 'haber' end
     where cuenta = p_cuenta
     returning * into v_m;
  exception
    when foreign_key_violation then
      raise exception using errcode = 'MX006',
        message = format('La cuenta %s: el renglón %s / %s no existe en estados_lineas. Créalo antes con fn_estados_linea.',
                         p_cuenta, v_secc, coalesce(p_cambios->>'linea', v_m.linea));
    when invalid_text_representation then
      raise exception using errcode = '22023', message = 'orden es un número entero y efectivo es true o false.';
  end;
  return to_jsonb(v_m);
end $$;
revoke execute on function public.fn_estados_mapeo(text, jsonb) from public, anon, authenticated, service_role;

-- Un renglón nuevo (o su etiqueta, su orden o su nota): p. ej. agrupar
-- «Mano de obra y burden» en resultados:
--   select fn_estados_linea('resultados', 'costo', 'mano_de_obra', 'Mano de obra y burden', 'Labor and burden', 210);
-- En el flujo, un renglón es único en su estado (las cuentas lo nombran
-- solo por su nombre). No se borra: un renglón sin cuentas no se pinta.
create or replace function public.fn_estados_linea(p_estado text, p_seccion text, p_linea text, p_etiqueta_es text,
                                                   p_etiqueta_en text, p_orden int default null, p_notas text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_l estados_lineas;
begin
  perform fn_estados_exigir_dueno();
  if p_estado is null or p_estado not in ('balance', 'resultados', 'flujo_directo', 'flujo_indirecto') then
    raise exception using errcode = '22023',
      message = format('Estado «%s» no válido: balance, resultados, flujo_directo o flujo_indirecto.', coalesce(p_estado, ''));
  end if;
  if not exists (select 1 from estados_lineas l where l.estado = p_estado and l.seccion = p_seccion and l.linea = p_seccion) then
    raise exception using errcode = '22023',
      message = format('La sección %s no existe en %s: las secciones son las del archivo (activo_circulante, costo, operacion…).',
                       coalesce(p_seccion, '(nula)'), p_estado);
  end if;
  if p_seccion = 'totales' then
    raise exception using errcode = '22023', message = 'Los totales los calcula este archivo: solo se les cambia la etiqueta.';
  end if;
  -- El bloque sin dinero del flujo lo arma el flujo solo (4.4): sus
  -- renglones son los del archivo; a los suyos solo se les cambia la
  -- etiqueta.
  if p_seccion = 'sin_dinero'
     and not exists (select 1 from estados_lineas l where l.estado = p_estado and l.seccion = p_seccion and l.linea = p_linea) then
    raise exception using errcode = '22023',
      message = 'El bloque sin dinero del flujo lo arma el flujo solo: sus renglones son los del archivo (solo se les cambia la etiqueta).';
  end if;
  insert into estados_lineas (estado, seccion, linea, orden, etiqueta_es, etiqueta_en, notas)
  values (p_estado, p_seccion, p_linea,
          coalesce(p_orden, (select coalesce(max(l.orden), 0) + 1 from estados_lineas l
                              where l.estado = p_estado and l.seccion = p_seccion)),
          btrim(p_etiqueta_es), btrim(p_etiqueta_en), nullif(btrim(p_notas), ''))
  on conflict (estado, seccion, linea) do update
     set etiqueta_es = excluded.etiqueta_es,
         etiqueta_en = excluded.etiqueta_en,
         orden       = coalesce(p_orden, estados_lineas.orden),
         notas       = coalesce(excluded.notas, estados_lineas.notas)
  returning * into v_l;
  return to_jsonb(v_l);
exception
  when unique_violation then
    raise exception using errcode = 'MX006',
      message = format('«%s» ya es un renglón de %s en otra sección: en el flujo cada renglón es único.', p_linea, p_estado);
  when check_violation or not_null_violation then
    raise exception using errcode = '22023',
      message = 'El renglón va en minúsculas y guiones bajos (mano_de_obra), con sus dos etiquetas llenas.';
end $$;
revoke execute on function public.fn_estados_linea(text, text, text, text, text, int, text) from public, anon, authenticated, service_role;

-- Lo que decide el CPA de la presentación (hoy, plegar_3200: 'si' o 'no').
create or replace function public.fn_estados_config(p_clave text, p_valor text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_k estados_config;
begin
  perform fn_estados_exigir_dueno();
  update estados_config set valor = lower(btrim(p_valor)) where clave = p_clave returning * into v_k;
  if not found then
    raise exception using errcode = '22023', message = format('No hay configuración «%s» (hoy solo plegar_3200).', coalesce(p_clave, ''));
  end if;
  return to_jsonb(v_k);
exception
  when check_violation then
    raise exception using errcode = '22023', message = format('%s va con ''si'' o ''no''.', p_clave);
end $$;
revoke execute on function public.fn_estados_config(text, text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 7.2 · El mapeo de QuickBooks.
--   select fn_apertura_mapeo_qb('Chase Chk 4392', '1010');
--   select fn_apertura_mapeo_qb('Opening Balance Equity', '3900', 'Capital que QuickBooks creó al dar saldos iniciales');
--   select fn_apertura_mapeo_trabajo('Pérez, Juan:Casa Pérez', 'casa-perez-k3m9');
-- Mapear otra vez el mismo nombre lo cambia (con rastro).
-- ---------------------------------------------------------------------
create or replace function public.fn_apertura_mapeo_qb(p_nombre_qb text, p_cuenta text, p_notas text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_c cuentas;
  v_m apertura_mapeo_qb;
begin
  perform fn_estados_exigir_dueno();
  if fn_estados_clave_qb(p_nombre_qb) is null then
    raise exception using errcode = '22023', message = 'Falta el nombre de la cuenta de QuickBooks.';
  end if;
  select * into v_c from cuentas where codigo = btrim(p_cuenta);
  if not found then
    raise exception using errcode = 'MX004',
      message = format('La cuenta %s no existe en el plan. Si es una subcuenta nueva (una tarjeta), añádela antes en c1.',
                       coalesce(p_cuenta, '(nula)'));
  end if;
  if not v_c.imputable or not v_c.activa then
    raise exception using errcode = 'MX004',
      message = format('La cuenta %s (%s) %s: el mapeo va a una cuenta donde se puede postear.', v_c.codigo, v_c.nombre,
                       case when not v_c.imputable then 'es de grupo (sus subcuentas llevan el saldo)' else 'está inactiva' end);
  end if;
  insert into apertura_mapeo_qb (tipo, nombre_qb, cuenta, notas)
  values ('cuenta', btrim(p_nombre_qb), v_c.codigo, nullif(btrim(p_notas), ''))
  on conflict (tipo, clave) do update
     set nombre_qb = excluded.nombre_qb, cuenta = excluded.cuenta, notas = coalesce(excluded.notas, apertura_mapeo_qb.notas)
  returning * into v_m;
  return to_jsonb(v_m);
end $$;
revoke execute on function public.fn_apertura_mapeo_qb(text, text, text) from public, anon, authenticated, service_role;

create or replace function public.fn_apertura_mapeo_trabajo(p_nombre_qb text, p_proyecto_id text, p_notas text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_m apertura_mapeo_qb;
begin
  perform fn_estados_exigir_dueno();
  if fn_estados_clave_qb(p_nombre_qb) is null then
    raise exception using errcode = '22023', message = 'Falta el Customer:Job de QuickBooks.';
  end if;
  if not exists (select 1 from proyectos p where p.id = btrim(p_proyecto_id)) then
    raise exception using errcode = '22023', message = format('La obra %s no existe en la app.', coalesce(p_proyecto_id, '(nula)'));
  end if;
  insert into apertura_mapeo_qb (tipo, nombre_qb, proyecto_id, notas)
  values ('trabajo', btrim(p_nombre_qb), btrim(p_proyecto_id), nullif(btrim(p_notas), ''))
  on conflict (tipo, clave) do update
     set nombre_qb = excluded.nombre_qb, proyecto_id = excluded.proyecto_id,
         notas = coalesce(excluded.notas, apertura_mapeo_qb.notas)
  returning * into v_m;
  return to_jsonb(v_m);
end $$;
revoke execute on function public.fn_apertura_mapeo_trabajo(text, text, text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 7.3 · Cargar una balanza de QuickBooks: la de la apertura
-- (fn_apertura_balanza_cargar) o la de un período para comparar
-- (fn_comparacion_qb_cargar). p_filas es la lista de filas del CSV, cada
-- una un objeto:
--   cuenta_qb        el nombre de la cuenta como lo trae QuickBooks;
--   debe, haber      sus columnas (o saldo = debe − haber); texto
--                    «1,234.56», «(500.00)», «$1,234.56» o número;
--   y, en la apertura, lo de la cédula: factura_id (el id de la factura EN
--   LA APP) o factura_num (su número, como lo trae el A/R Aging de
--   QuickBooks: «1095»; se busca en la app), retencion, cliente_trabajo,
--   proyecto_id, proveedor_qb, proveedor_id, recibo_id,
--   trabajo_externo_id, referencia, notas, y la fecha del documento
--   (fecha o fecha_documento) y su vencimiento (vence), como los trae el
--   A/P Aging Detail: «2026-07-15» o «07/15/2026» (ver apertura_balanza_qb,
--   1.5); en la comparación: cliente_trabajo, proyecto_id.
-- La fila de totales del reporte («TOTAL») no es una cuenta: no se carga
-- (sumarla doblaría el debe y el haber del resumen); el resumen la trae
-- aparte, con si coincide con la suma de las filas.
-- En la apertura, además, el CONTROL de QuickBooks (f04, ronda 3): la fila
-- «Net Income» y la fila «TOTAL ASSETS» de su Balance Sheet al 30-sep, como
-- dos filas más de la lista (con su debe o su haber: una utilidad va en
-- haber). Se guardan aparte (control), no se suman, y fn_apertura_plan
-- compara con ellas lo que da el mapeo: sin ellas no postea.
-- Devuelve el resumen (filas, debe, haber, si cuadra, el control) y los
-- nombres que no tienen mapeo todavía: se ven antes de apertura.
-- ---------------------------------------------------------------------
-- Una fecha del CSV: «2026-07-15» o «07/15/2026» (la de QuickBooks en
-- Estados Unidos). Nula si viene vacía; lo demás, un error que dice cuál.
create or replace function public.fn_estados_fecha(p_valor jsonb, p_que text)
returns date
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_t text := btrim(coalesce(p_valor #>> '{}', ''));
begin
  if v_t = '' then
    return null;
  end if;
  begin
    if v_t ~ '^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$' then
      return v_t::date;
    elsif v_t ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' then
      return make_date(split_part(v_t, '/', 3)::int, split_part(v_t, '/', 1)::int, split_part(v_t, '/', 2)::int);
    end if;
  exception
    when others then
      null;  -- (cae al mensaje de abajo)
  end;
  raise exception using errcode = '22023',
    message = format('%s: «%s» no es una fecha (2026-07-15 o 07/15/2026, mes/día/año como QuickBooks).', p_que, v_t);
end $$;
revoke execute on function public.fn_estados_fecha(jsonb, text) from public, anon, authenticated, service_role;

-- ¿Es la fila de totales del reporte?
create or replace function public.fn_estados_es_total(p_cuenta_qb text)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  select lower(btrim(regexp_replace(coalesce(p_cuenta_qb, ''), '[[:space:]]+', ' ', 'g')))
           ~ '^(grand )?totals?:?$|^total general$|^suma total$'
$$;
revoke execute on function public.fn_estados_es_total(text) from public, anon, authenticated, service_role;

-- ¿Es una fila de CONTROL de la apertura (ver apertura_balanza_qb.control)?
-- «Net Income» (o «Net Income (Loss)», «Utilidad neta»…) = 'utilidad';
-- «TOTAL ASSETS» («Total activo»…) = 'activo'; lo demás, nulo.
create or replace function public.fn_apertura_control_qb(p_cuenta_qb text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
           when x.n ~ '^(net income|net income \(loss\)|net profit|net loss|net profit \(loss\)|utilidad neta|p[ée]rdida neta|'
                      'utilidad \(p[ée]rdida\) neta|resultado neto)$' then 'utilidad'
           when x.n ~ '^(total assets|total activos?|total del activo|total de activos)$' then 'activo'
         end
    from (select lower(btrim(regexp_replace(coalesce(p_cuenta_qb, ''), '[[:space:]]+', ' ', 'g'))) as n) x
$$;
revoke execute on function public.fn_apertura_control_qb(text) from public, anon, authenticated, service_role;

create or replace function public.fn_apertura_balanza_cargar(p_documento text, p_filas jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_f      jsonb;
  v_n      int := 0;
  v_sobra  text;
  v_debe   numeric;
  v_haber  numeric;
  v_saldo  numeric;
  v_fid    bigint;
  v_num    text;
  v_obra   text;
  v_cands  text;
  v_ncand  int;
  v_fnum   bigint;
  v_total  jsonb;
  v_ctl    text;
  v_de     text;
begin
  perform fn_estados_exigir_dueno();
  if coalesce(btrim(p_documento), '') = '' then
    raise exception using errcode = '22023', message = 'Falta el documento (la ruta del PDF o del CSV de la balanza en Storage).';
  end if;
  if jsonb_typeof(p_filas) is distinct from 'array' or jsonb_array_length(p_filas) = 0 then
    raise exception using errcode = '22023', message = 'Las filas llegan como una lista JSON, una por cuenta de QuickBooks.';
  end if;
  -- El candado de la apertura (el de fn_apertura): si alguien la está
  -- posteando con esta balanza, esta carga espera a que termine, y
  -- entonces su guarda (1.6) ve el asiento y dice por qué no se puede.
  perform pg_advisory_xact_lock(820260930);
  -- Otra carga del mismo documento lo reemplaza (si ya entró al libro, la
  -- guarda de 1.6 lo impide y dice por qué).
  delete from apertura_balanza_qb where documento = btrim(p_documento);
  for v_f in select value from jsonb_array_elements(p_filas) loop
    v_n := v_n + 1;
    if jsonb_typeof(v_f) <> 'object' then
      raise exception using errcode = '22023', message = format('Fila %s: cada fila es un objeto JSON.', v_n);
    end if;
    select string_agg(k, ', ' order by k) into v_sobra
      from jsonb_object_keys(v_f) k
     where k not in ('cuenta_qb', 'debe', 'haber', 'saldo', 'factura_id', 'factura_num', 'retencion', 'cliente_trabajo',
                     'proyecto_id', 'proveedor_qb', 'proveedor_id', 'recibo_id', 'trabajo_externo_id', 'referencia', 'notas',
                     'fecha', 'fecha_documento', 'vence');
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Fila %s: llave desconocida: %s.', v_n, v_sobra);
    end if;
    if coalesce(btrim(v_f->>'cuenta_qb'), '') = '' then
      raise exception using errcode = '22023', message = format('Fila %s: falta cuenta_qb.', v_n);
    end if;
    if v_f ? 'fecha' and v_f ? 'fecha_documento' then
      raise exception using errcode = '22023', message = format('Fila %s: o fecha o fecha_documento (son lo mismo), no las dos.', v_n);
    end if;
    v_debe  := fn_estados_monto(v_f->'debe', format('Fila %s (%s), debe', v_n, v_f->>'cuenta_qb'));
    v_haber := fn_estados_monto(v_f->'haber', format('Fila %s (%s), haber', v_n, v_f->>'cuenta_qb'));
    v_saldo := fn_estados_monto(v_f->'saldo', format('Fila %s (%s), saldo', v_n, v_f->>'cuenta_qb'));
    if v_saldo is not null and (v_debe is not null or v_haber is not null) then
      raise exception using errcode = '22023', message = format('Fila %s: o debe y haber, o saldo; no los dos.', v_n);
    end if;
    if v_saldo is not null then
      v_debe  := greatest(v_saldo, 0);
      v_haber := greatest(-v_saldo, 0);
    end if;
    -- La fila de totales del reporte: aparte, no se carga.
    if fn_estados_es_total(v_f->>'cuenta_qb') then
      v_total := jsonb_build_object('fila', v_n, 'cuenta_qb', btrim(v_f->>'cuenta_qb'), 'debe', coalesce(v_debe, 0),
                                    'haber', coalesce(v_haber, 0));
      continue;
    end if;
    -- El control de QuickBooks (Net Income, TOTAL ASSETS): se guarda
    -- aparte, una vez cada uno.
    v_ctl := fn_apertura_control_qb(v_f->>'cuenta_qb');
    if v_ctl is not null then
      if exists (select 1 from apertura_balanza_qb b where b.documento = btrim(p_documento) and b.control = v_ctl) then
        raise exception using errcode = '22023',
          message = format('Fila %s (%s): la balanza ya trae su fila de control «%s»; va una sola vez.', v_n, v_f->>'cuenta_qb',
                           case v_ctl when 'utilidad' then 'Net Income' else 'TOTAL ASSETS' end);
      end if;
      insert into apertura_balanza_qb (documento, linea, cuenta_qb, debe, haber, control, notas, cargado_por, cargado_rol)
      values (btrim(p_documento), v_n, btrim(v_f->>'cuenta_qb'), v_debe, v_haber, v_ctl, nullif(btrim(v_f->>'notas'), ''),
              auth.uid(), fn_rol_llamante());
      continue;
    end if;
    -- La factura por su número (el que trae QuickBooks): la de la app con
    -- ese número (y de la obra de la fila, si la dice); si son varias, se
    -- dicen.
    v_fid := null;
    begin
      v_fid := (v_f->>'factura_id')::bigint;
    exception
      when invalid_text_representation or numeric_value_out_of_range then
        raise exception using errcode = '22023',
          message = format('Fila %s (%s): factura_id es el id de la factura en la app (un número); el número de la factura de '
                           'QuickBooks va en factura_num.', v_n, v_f->>'cuenta_qb');
    end;
    v_num := nullif(regexp_replace(btrim(coalesce(v_f->>'factura_num', '')), '^#[[:space:]]*', ''), '');
    if v_num is not null then
      v_obra := coalesce(nullif(btrim(v_f->>'proyecto_id'), ''),
                         (select m.proyecto_id from apertura_mapeo_qb m
                           where m.tipo = 'trabajo'
                             and m.clave = nullif(lower(btrim(regexp_replace(regexp_replace(coalesce(v_f->>'cliente_trabajo', ''),
                                                  '[[:space:]]+', ' ', 'g'), '[[:space:]]*:[[:space:]]*', ':', 'g'))), '')));
      select count(*), string_agg(format('id %s (%s, %s, %s)', f.id, coalesce(f.proyecto_id, 'sin obra'), f.fecha, f.monto),
                                  '; ' order by f.id),
             min(f.id)
        into v_ncand, v_cands, v_fnum
        from facturas f
       where btrim(f.num) = v_num and (v_obra is null or f.proyecto_id = v_obra);
      -- No está en ESA obra, pero sí en otra: lo que está mal es la obra de
      -- la fila (su Customer:Job mapeado a otra obra, o su proyecto_id), no
      -- la app. Darla de alta otra vez la duplicaría (el número es único por
      -- obra) y la apertura pondría su cuenta por cobrar en la obra
      -- equivocada, con todo en verde.
      if v_ncand = 0 and v_obra is not null then
        v_de := case when nullif(btrim(v_f->>'proyecto_id'), '') is not null
                     then format('la fila dice proyecto_id %s', v_obra)
                     else format('su Customer:Job «%s» está mapeado a la obra %s', btrim(v_f->>'cliente_trabajo'), v_obra) end;
        select string_agg(format('en %s (id %s, del %s, por %s)', coalesce(f.proyecto_id, 'sin obra'), f.id, f.fecha, f.monto),
                          '; ' order by f.id)
          into v_cands
          from facturas f
         where btrim(f.num) = v_num;
        if v_cands is not null then
          raise exception using errcode = 'MX006',
            message = format('Fila %s (%s): la factura #%s SÍ está en la app, %s; pero %s. Una factura va con su obra: corrige %s '
                             'y vuelve a cargar la balanza. No la des de alta otra vez: quedaría duplicada, y la apertura '
                             'pondría su cuenta por cobrar en la obra equivocada.', v_n, v_f->>'cuenta_qb', v_num, v_cands, v_de,
                             case when nullif(btrim(v_f->>'proyecto_id'), '') is not null then 'el proyecto_id de la fila'
                                  else format('el mapeo: select fn_apertura_mapeo_trabajo(%L, ''<la obra de la factura>'');',
                                              btrim(v_f->>'cliente_trabajo')) end);
        end if;
      end if;
      if v_ncand = 0 then
        raise exception using errcode = 'MX008',
          message = format('Fila %s (%s): la factura #%s no está en la app%s. Dala de alta en la app con su número y su fecha de '
                           'QuickBooks, y vuelve a cargar la balanza.', v_n, v_f->>'cuenta_qb', v_num,
                           coalesce(' en la obra ' || v_obra, ''));
      elsif v_ncand > 1 then
        raise exception using errcode = 'MX008',
          message = format('Fila %s (%s): hay %s facturas #%s en la app: %s. Di cuál con su Customer:Job (cliente_trabajo) o con '
                           'factura_id.', v_n, v_f->>'cuenta_qb', v_ncand, v_num, v_cands);
      end if;
      if v_fid is not null and v_fid <> v_fnum then
        raise exception using errcode = '22023',
          message = format('Fila %s (%s): factura_id %s y factura_num #%s son facturas distintas (la #%s es la %s).', v_n,
                           v_f->>'cuenta_qb', v_fid, v_num, v_num, v_cands);
      end if;
      v_fid := v_fnum;
    end if;
    begin
      insert into apertura_balanza_qb (documento, linea, cuenta_qb, debe, haber, factura_id, factura_num, retencion,
                                       cliente_trabajo, proyecto_id, proveedor_qb, proveedor_id, recibo_id, trabajo_externo_id,
                                       referencia, notas, fecha_documento, vence, cargado_por, cargado_rol)
      values (btrim(p_documento), v_n, btrim(v_f->>'cuenta_qb'), v_debe, v_haber, v_fid, v_num,
              nullif(fn_estados_monto(v_f->'retencion', format('Fila %s (%s), retención', v_n, v_f->>'cuenta_qb')), 0),
              nullif(btrim(v_f->>'cliente_trabajo'), ''), nullif(btrim(v_f->>'proyecto_id'), ''),
              nullif(btrim(v_f->>'proveedor_qb'), ''), (nullif(btrim(v_f->>'proveedor_id'), ''))::uuid,
              (v_f->>'recibo_id')::bigint, (v_f->>'trabajo_externo_id')::bigint, nullif(btrim(v_f->>'referencia'), ''),
              nullif(btrim(v_f->>'notas'), ''),
              fn_estados_fecha(coalesce(v_f->'fecha', v_f->'fecha_documento'), format('Fila %s (%s), fecha', v_n, v_f->>'cuenta_qb')),
              fn_estados_fecha(v_f->'vence', format('Fila %s (%s), vence', v_n, v_f->>'cuenta_qb')),
              auth.uid(), fn_rol_llamante());
    exception
      when check_violation then
        raise exception using errcode = '22023',
          message = format('Fila %s (%s): la retención va con su factura y es positiva; un papel de la app es un recibo o un '
                           'trabajo externo, no los dos.', v_n, v_f->>'cuenta_qb');
      when invalid_text_representation or numeric_value_out_of_range then
        raise exception using errcode = '22023',
          message = format('Fila %s (%s): recibo_id y trabajo_externo_id son números; proveedor_id, un uuid.',
                           v_n, v_f->>'cuenta_qb');
    end;
  end loop;
  return (select jsonb_strip_nulls(jsonb_build_object(
            'documento', btrim(p_documento), 'filas', count(*) filter (where b.control is null),
            'debe', coalesce(sum(b.debe) filter (where b.control is null), 0),
            'haber', coalesce(sum(b.haber) filter (where b.control is null), 0),
            'cuadra', coalesce(sum(b.debe) filter (where b.control is null), 0)
                      = coalesce(sum(b.haber) filter (where b.control is null), 0),
            'fila_total', v_total || jsonb_build_object(
                            'ignorada', true,
                            'coincide', (v_total->>'debe')::numeric = coalesce(sum(b.debe) filter (where b.control is null), 0)
                                        and (v_total->>'haber')::numeric
                                            = coalesce(sum(b.haber) filter (where b.control is null), 0)),
            'control', jsonb_build_object(
                         'utilidad', -sum(coalesce(b.debe, 0) - coalesce(b.haber, 0)) filter (where b.control = 'utilidad'),
                         'activo', sum(coalesce(b.debe, 0) - coalesce(b.haber, 0)) filter (where b.control = 'activo'),
                         'falta', case when count(*) filter (where b.control = 'utilidad') = 0
                                            or count(*) filter (where b.control = 'activo') = 0
                                       then 'Faltan las filas de control de QuickBooks: «Net Income» y «TOTAL ASSETS» de su '
                                            'Balance Sheet al día de la apertura (fn_apertura_plan compara con ellas lo que da '
                                            'el mapeo; sin ellas no postea).' end),
            'sin_mapeo', coalesce(jsonb_agg(distinct b.cuenta_qb) filter (
                           where b.control is null and coalesce(b.debe, 0) <> coalesce(b.haber, 0)
                             and not exists (select 1 from apertura_mapeo_qb m where m.tipo = 'cuenta' and m.clave = b.clave)),
                         '[]'::jsonb),
            'trabajos_sin_mapeo', coalesce(jsonb_agg(distinct b.cliente_trabajo) filter (
                           where b.control is null and b.cliente_clave is not null and b.proyecto_id is null
                             and not exists (select 1 from apertura_mapeo_qb m where m.tipo = 'trabajo' and m.clave = b.cliente_clave)),
                         '[]'::jsonb)))
            from apertura_balanza_qb b
           where b.documento = btrim(p_documento));
end $$;
revoke execute on function public.fn_apertura_balanza_cargar(text, jsonb) from public, anon, authenticated, service_role;

-- (La versión anterior, sin p_con_posteriores, se quita: con dos firmas,
-- una llamada con tres argumentos sería ambigua.)
drop function if exists public.fn_comparacion_qb_cargar(text, text, jsonb);
-- (Y la de cuatro, sin p_al: con dos firmas, una llamada con cuatro
-- argumentos sería ambigua.)
drop function if exists public.fn_comparacion_qb_cargar(text, text, jsonb, boolean);
-- p_con_posteriores: la balanza ya trae los ajustes del CPA posteriores al
-- período (la FINAL de diciembre, la del CPA): v_comparacion le suma al
-- libro los ajuste_cpa fechados después que lo corrigen. La preliminar
-- (la de siempre) va sin él.
-- p_al: la FECHA de la balanza, si no es la del cierre del período (la de
-- una quincena, f13-14: '2026-12-15'); v_comparacion corta el libro a ese
-- día. Nula = el último día del período. Cada carga queda (vale la más
-- reciente; las anteriores, en v_qb_balanzas y en estados_historial).
create or replace function public.fn_comparacion_qb_cargar(p_periodo text, p_documento text, p_filas jsonb,
                                                           p_con_posteriores boolean default false, p_al date default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_f     jsonb;
  v_n     int := 0;
  v_sobra text;
  v_debe  numeric;
  v_haber numeric;
  v_saldo numeric;
  v_filas jsonb := '[]'::jsonb;
  v_total jsonb;
  v_p     periodos;
begin
  perform fn_estados_exigir_dueno();
  select * into v_p from periodos p where p.periodo = p_periodo;
  if not found then
    raise exception using errcode = '22023', message = format('No existe el período %s.', coalesce(p_periodo, '(nulo)'));
  end if;
  if p_al is not null and (p_al < v_p.desde or p_al > v_p.hasta) then
    raise exception using errcode = '22023',
      message = format('La balanza del %s no es del período %s (del %s al %s).', p_al, p_periodo, v_p.desde, v_p.hasta);
  end if;
  if coalesce(btrim(p_documento), '') = '' then
    raise exception using errcode = '22023', message = 'Falta el documento (la ruta del PDF o del CSV de la balanza en Storage).';
  end if;
  if exists (select 1 from comparacion_qb q where q.periodo = p_periodo and q.documento = btrim(p_documento)) then
    raise exception using errcode = 'MX003',
      message = format('La balanza %s de %s ya está cargada y no se edita: si QuickBooks la corrigió, cárgala con otro documento '
                       '(vale la más reciente).', btrim(p_documento), p_periodo);
  end if;
  if jsonb_typeof(p_filas) is distinct from 'array' or jsonb_array_length(p_filas) = 0 then
    raise exception using errcode = '22023', message = 'Las filas llegan como una lista JSON, una por cuenta de QuickBooks.';
  end if;
  -- Primero se revisa cada fila; después entran todas en UN insert (la
  -- guarda de 1.6 mira el insert entero).
  for v_f in select value from jsonb_array_elements(p_filas) loop
    v_n := v_n + 1;
    if jsonb_typeof(v_f) <> 'object' then
      raise exception using errcode = '22023', message = format('Fila %s: cada fila es un objeto JSON.', v_n);
    end if;
    select string_agg(k, ', ' order by k) into v_sobra
      from jsonb_object_keys(v_f) k
     where k not in ('cuenta_qb', 'debe', 'haber', 'saldo', 'cliente_trabajo', 'proyecto_id');
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Fila %s: llave desconocida: %s.', v_n, v_sobra);
    end if;
    if coalesce(btrim(v_f->>'cuenta_qb'), '') = '' then
      raise exception using errcode = '22023', message = format('Fila %s: falta cuenta_qb.', v_n);
    end if;
    v_debe  := fn_estados_monto(v_f->'debe', format('Fila %s (%s), debe', v_n, v_f->>'cuenta_qb'));
    v_haber := fn_estados_monto(v_f->'haber', format('Fila %s (%s), haber', v_n, v_f->>'cuenta_qb'));
    v_saldo := fn_estados_monto(v_f->'saldo', format('Fila %s (%s), saldo', v_n, v_f->>'cuenta_qb'));
    if v_saldo is not null and (v_debe is not null or v_haber is not null) then
      raise exception using errcode = '22023', message = format('Fila %s: o debe y haber, o saldo; no los dos.', v_n);
    end if;
    v_saldo := coalesce(v_saldo, coalesce(v_debe, 0) - coalesce(v_haber, 0));
    if fn_estados_es_total(v_f->>'cuenta_qb') then
      v_total := jsonb_build_object('fila', v_n, 'cuenta_qb', btrim(v_f->>'cuenta_qb'), 'saldo', v_saldo,
                                    'debe', coalesce(v_debe, 0), 'haber', coalesce(v_haber, 0));
      continue;
    end if;
    v_filas := v_filas || jsonb_build_object('linea', v_n, 'cuenta_qb', btrim(v_f->>'cuenta_qb'),
                                             'cliente_trabajo', nullif(btrim(v_f->>'cliente_trabajo'), ''),
                                             'proyecto_id', nullif(btrim(v_f->>'proyecto_id'), ''), 'saldo', v_saldo);
  end loop;
  if jsonb_array_length(v_filas) = 0 then
    raise exception using errcode = '22023', message = 'La balanza no trae ninguna cuenta (solo la fila de totales).';
  end if;
  insert into comparacion_qb (periodo, documento, linea, cuenta_qb, cliente_trabajo, proyecto_id, saldo, con_posteriores, al,
                              cargado_por, cargado_rol)
  select p_periodo, btrim(p_documento), x.linea, x.cuenta_qb, x.cliente_trabajo, x.proyecto_id, x.saldo,
         coalesce(p_con_posteriores, false), case when p_al < v_p.hasta then p_al end, auth.uid(), fn_rol_llamante()
    from jsonb_to_recordset(v_filas) as x(linea int, cuenta_qb text, cliente_trabajo text, proyecto_id text, saldo numeric)
   order by x.linea;
  return (select jsonb_strip_nulls(jsonb_build_object(
            'periodo', p_periodo, 'documento', btrim(p_documento), 'filas', count(*), 'suma', coalesce(sum(q.saldo), 0),
            'cuadra', coalesce(sum(q.saldo), 0) = 0, 'con_posteriores', coalesce(p_con_posteriores, false),
            'al', coalesce(p_al, v_p.hasta),
            'fila_total', v_total || jsonb_build_object('ignorada', true),
            'sin_mapeo', coalesce(jsonb_agg(distinct q.cuenta_qb) filter (
                           where q.saldo <> 0
                             and not exists (select 1 from apertura_mapeo_qb m where m.tipo = 'cuenta' and m.clave = q.clave)),
                         '[]'::jsonb)))
            from comparacion_qb q
           where q.periodo = p_periodo and q.documento = btrim(p_documento));
end $$;
revoke execute on function public.fn_comparacion_qb_cargar(text, text, jsonb, boolean, date) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 7.4 · Las diferencias explicadas.
--   select fn_diferencia_anotar('2026-10', '2050', '-1250.00', 'criterio',
--            'El libro devenga la nómina de la última semana; QuickBooks la registra al pagarla.');
-- monto = libro − QuickBooks (lo que explica). Una explicación que ya no
-- vale se retira con su motivo (y queda): fn_diferencia_retirar.
-- ---------------------------------------------------------------------
create or replace function public.fn_diferencia_anotar(p_periodo text, p_cuenta text, p_monto text, p_clase text,
                                                       p_explicacion text, p_proyecto_id text default null,
                                                       p_asiento_id uuid default null)
returns uuid
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_id    uuid;
  v_monto numeric;
begin
  perform fn_estados_exigir_dueno();
  if not exists (select 1 from periodos p where p.periodo = p_periodo) then
    raise exception using errcode = '22023', message = format('No existe el período %s.', coalesce(p_periodo, '(nulo)'));
  end if;
  if not exists (select 1 from cuentas c where c.codigo = p_cuenta) then
    raise exception using errcode = 'MX004', message = format('La cuenta %s no existe en el plan.', coalesce(p_cuenta, '(nula)'));
  end if;
  v_monto := fn_estados_monto(to_jsonb(p_monto), 'El monto de la diferencia');
  if coalesce(v_monto, 0) = 0 then
    raise exception using errcode = 'MX005', message = 'Una diferencia en cero no explica nada.';
  end if;
  if p_clase is null or p_clase not in ('puente', 'mapeo', 'criterio') then
    raise exception using errcode = '22023',
      message = format('Clase «%s» no válida: puente (un papel que falta o que QuickBooks tiene en otro mes), mapeo (una cuenta '
                       'que no casa uno a uno) o criterio (lo que el libro hace distinto a propósito).', coalesce(p_clase, ''));
  end if;
  if coalesce(btrim(p_explicacion), '') = '' then
    raise exception using errcode = '22023', message = 'Toda diferencia dice por qué (explicacion).';
  end if;
  if p_proyecto_id is not null and not exists (select 1 from proyectos p where p.id = p_proyecto_id) then
    raise exception using errcode = '22023', message = format('La obra %s no existe en la app.', p_proyecto_id);
  end if;
  if p_asiento_id is not null and not exists (select 1 from asientos a where a.id = p_asiento_id) then
    raise exception using errcode = '22023', message = 'El asiento que dice explicarla no existe.';
  end if;
  -- Con obra, en una cuenta que la balanza de QuickBooks del período no trae
  -- por Customer:Job (la mensual de siempre no lo trae): vale, explica la
  -- fila por cuenta, pero por obra esa cuenta no se compara. Se avisa.
  if p_proyecto_id is not null
     and not exists (select 1 from v_qb_balanzas b
                      where b.periodo = p_periodo and b.vigente and b.cuenta = p_cuenta and b.proyecto_id is not null) then
    raise notice '%', format('La balanza de QuickBooks de %s no trae la %s por Customer:Job: esta diferencia explica la fila por '
                             'cuenta (v_comparacion); por obra esa cuenta no se compara (v_comparacion_obra no abre filas).',
                             p_periodo, p_cuenta);
  end if;
  insert into diferencias (periodo, cuenta, proyecto_id, monto, clase, explicacion, asiento_id, anotado_por, anotado_rol)
  values (p_periodo, p_cuenta, p_proyecto_id, v_monto, p_clase, btrim(p_explicacion), p_asiento_id, auth.uid(), fn_rol_llamante())
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.fn_diferencia_anotar(text, text, text, text, text, text, uuid) from public, anon, authenticated, service_role;

create or replace function public.fn_diferencia_retirar(p_id uuid, p_motivo text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_d diferencias;
begin
  perform fn_estados_exigir_dueno();
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Retirar una diferencia dice por qué (motivo).';
  end if;
  update diferencias
     set retirada_el = clock_timestamp(), retirada_por = auth.uid(), retirada_motivo = btrim(p_motivo)
   where id = p_id and retirada_el is null
  returning * into v_d;
  if not found then
    raise exception using errcode = '22023', message = 'Esa diferencia no existe o ya estaba retirada.';
  end if;
  return to_jsonb(v_d);
end $$;
revoke execute on function public.fn_diferencia_retirar(uuid, text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 7.5 · LA APERTURA: de la balanza de QuickBooks al 30-sep al asiento de
-- apertura.
-- fn_apertura_plan(documento) — arma el asiento SIN postear nada, y se
-- para en el PRIMER problema, diciéndolo con su nombre:
--   MX001  la balanza no cuadra (debe ≠ haber); o no trae su control de
--          QuickBooks (las filas «Net Income» y «TOTAL ASSETS», que se
--          guardan aparte), o lo que da el mapeo NO AMARRA con él: la
--          utilidad de enero a septiembre (−las cuentas de resultados) y
--          el total del activo (las mapeadas a cuentas de activo) tienen que
--          ser los de QuickBooks. Un mapeo equivocado (una cuenta de
--          resultados a una de balance, o al revés) mueve los dos: para, y
--          dice qué filas lo pueden explicar;
--   MX004  una cuenta de QuickBooks sin mapeo (y cómo mapearla), o
--          mapeada a una cuenta de grupo o inactiva;
--   MX006  una fila que no puede ir como viene: retención sin obra o
--          mayor que su saldo, una cuenta por obra sin obra, una factura
--          en una cuenta que no es de cobrar, la obra de la fila distinta
--          de la de su factura;
--   MX008  falta algo de la app: la factura, el proveedor, el recibo, el
--          trabajo externo, la obra o el Customer:Job que la fila nombra.
-- Cómo arma cada fila (saldo = debe − haber; las filas en cero se saltan):
--   · una cuenta de RESULTADOS (ingresos, costos, gastos de enero a
--     septiembre): a 3900, en UNA línea con su nota («resultado de enero a
--     septiembre de 2026 según QuickBooks», con el desglose): la apertura es
--     balance únicamente (c2);
--   · cuentas por cobrar (la cuenta del puente 'cxc', 1110): una fila por
--     factura abierta (factura_id, o factura_num al cargarla), a 1110 con
--     su partida facturas/<id> y la obra de la factura; su retención (la
--     columna retencion) a 1120, misma partida y obra. Un saldo NEGATIVO
--     (un crédito del cliente, una factura pagada de más) va sin factura, a
--     1110 con su obra (con factura: MX006, que lo dice); uno POSITIVO sin
--     factura, no (MX008): el cobro de octubre no tendría a qué aplicarse;
--   · retención por cobrar (1120), cuando QuickBooks la trae en su propia
--     cuenta: POR FACTURA, como la cuenta por cobrar (factura_num o
--     factura_id), con su partida facturas/<id> y la obra de la factura.
--     c3 cobra la retención contra esa partida: sin ella, en octubre el
--     cobro de la retención no cabía (MX006 si falta, con las facturas de
--     la obra que tienen retención en la app);
--   · cuentas por pagar (2010) y retención por pagar a subcontratistas
--     (2020, el renglón retencion_por_pagar): por proveedor (proveedor_id,
--     o su nombre de QuickBooks casado con proveedores_alias; MX008 si no
--     está), con la partida del recibo o del trabajo externo si la dice; la
--     retención, además, con su obra. Antes la 2020 entraba sin proveedor:
--     al pagarle su retención al subcontratista, el balance inventaba un
--     saldo a favor y un pasivo, y la antigüedad lo partía en dos;
--   · lo demás, por cuenta: la obra si la cuenta va por obra (obligatoria,
--     MX006 si falta) u opcional; 15xx y 1590 como totales, hasta que
--     exista el auxiliar de activos fijos.
-- Devuelve {lineas, resultado_qb, retencion_partida, partidas, …}. Las
-- líneas iguales (cuenta, obra, partida, tercero) se suman en una.
-- fn_apertura_revisar(documento) lo enseña como tabla, para mirarlo antes.
-- ---------------------------------------------------------------------
create or replace function public.fn_apertura_plan(p_documento text)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  r        apertura_balanza_qb;
  v_ap     periodos;
  v_cxc    text := (select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc');
  v_ret    text := (select pc.cuenta from puente_cuentas pc where pc.rol = 'retencion_cxc');
  v_cxp    text := (select pc.cuenta from puente_cuentas pc where pc.rol = 'cxp');
  v_m      apertura_mapeo_qb;
  v_c      cuentas;
  v_f      facturas;
  v_saldo  numeric;
  v_rt     numeric;
  v_obra   text;
  v_prov   uuid;
  v_memo   text;
  v_hint   text;
  v_raw    jsonb := '[]'::jsonb;
  v_filas  int;
  v_cero   int := 0;
  v_debe   numeric;
  v_haber  numeric;
  v_res    numeric := 0;
  v_rtipo  jsonb := '{}'::jsonb;
  v_rsplit numeric := 0;
  v_robra  jsonb := '{}'::jsonb;
  v_rqb    text[] := '{}';
  v_lineas jsonb;
  v_part   jsonb;
  v_activo numeric := 0;
  v_nu     int;
  v_na     int;
  v_cu     numeric;
  v_ca     numeric;
  v_pago   boolean;
begin
  select * into v_ap from periodos where tipo = 'apertura' order by desde limit 1;
  if not found then
    raise exception using errcode = 'MX002', message = 'No hay período de apertura en el calendario (c2).';
  end if;
  -- (Las filas de control —Net Income, TOTAL ASSETS— no son cuentas: aparte.)
  select count(*), coalesce(sum(b.debe), 0), coalesce(sum(b.haber), 0) into v_filas, v_debe, v_haber
    from apertura_balanza_qb b where b.documento = p_documento and b.control is null;
  if v_filas = 0 then
    raise exception using errcode = 'MX008',
      message = format('No hay ninguna balanza cargada con el documento «%s»: cárgala antes con fn_apertura_balanza_cargar.',
                       coalesce(p_documento, ''));
  end if;
  -- 1. Que cuadre, antes que nada.
  if v_debe <> v_haber then
    raise exception using errcode = 'MX001',
      message = format('La balanza %s no cuadra: debe %s, haber %s, diferencia %s. No entra.%s', p_documento, v_debe, v_haber,
                       v_debe - v_haber,
                       case when exists (select 1 from apertura_balanza_qb b
                                          where b.documento = p_documento and b.control = 'utilidad')
                            then ' (Su «Net Income» ya va aparte, como control: no se suma.) ¿Falta una fila, o sobra la de '
                                 'totales?'
                            else ' ¿Falta una fila, o sobra la de totales?' end);
  end if;

  -- 2. Fila por fila, en su orden; la primera que no se puede, para.
  for r in select * from apertura_balanza_qb b where b.documento = p_documento and b.control is null order by b.linea loop
    v_saldo := coalesce(r.debe, 0) - coalesce(r.haber, 0);
    if v_saldo = 0 and coalesce(r.retencion, 0) = 0 then
      v_cero := v_cero + 1;
      continue;
    end if;
    select * into v_m from apertura_mapeo_qb m where m.tipo = 'cuenta' and m.clave = r.clave;
    if not found then
      v_hint := case
                  when r.clave ~ '^total' then ' ¿Es la fila de totales del reporte? Esa no va: quítala de la balanza.'
                  when r.clave in ('net income', 'utilidad neta', 'net profit', 'net loss')
                    then ' Es el resultado del año, que en una balanza de comprobación ya viene en sus cuentas: quítala.'
                  when r.clave like '%undeposited%'
                    then ' Undeposited Funds son cobros recibidos y no depositados al 30-sep: van al banco donde se '
                         'depositaron (1010), como depósito en tránsito; su depósito de octubre ya no es un cobro nuevo.'
                  when r.clave like '%opening balance%'
                    then ' Opening Balance Equity es el capital que QuickBooks creó al dar saldos iniciales: por lo normal va a '
                         'utilidades retenidas (3900), salvo que el CPA diga otra cosa.'
                  when r.clave like '%retained earnings%'
                    then ' Retained Earnings va a utilidades retenidas (3900).'
                  else '' end;
      raise exception using errcode = 'MX004',
        message = format('La cuenta de QuickBooks «%s» (fila %s de %s, saldo %s) no está mapeada al plan: select '
                         'fn_apertura_mapeo_qb(%L, ''<cuenta del plan>'');%s', r.cuenta_qb, r.linea, p_documento, v_saldo,
                         r.cuenta_qb, v_hint);
    end if;
    select * into v_c from cuentas c where c.codigo = v_m.cuenta;
    if not v_c.imputable or not v_c.activa then
      raise exception using errcode = 'MX004',
        message = format('La cuenta de QuickBooks «%s» (fila %s) está mapeada a la %s (%s), que %s: corrige el mapeo con '
                         'fn_apertura_mapeo_qb.', r.cuenta_qb, r.linea, v_c.codigo, v_c.nombre,
                         case when not v_c.imputable then 'es de grupo' else 'está inactiva' end);
    end if;
    -- La obra: la de la fila, o la de su Customer:Job.
    v_obra := r.proyecto_id;
    if v_obra is null and r.cliente_clave is not null then
      select m.proyecto_id into v_obra from apertura_mapeo_qb m where m.tipo = 'trabajo' and m.clave = r.cliente_clave;
      if v_obra is null then
        raise exception using errcode = 'MX008',
          message = format('El Customer:Job «%s» (fila %s, %s) no está mapeado a una obra de la app: select '
                           'fn_apertura_mapeo_trabajo(%L, ''<id de la obra>'');', r.cliente_trabajo, r.linea, r.cuenta_qb,
                           r.cliente_trabajo);
      end if;
    end if;
    if v_obra is not null and not exists (select 1 from proyectos p where p.id = v_obra) then
      raise exception using errcode = 'MX008', message = format('La obra %s (fila %s, %s) no existe en la app.', v_obra, r.linea,
                                                                r.cuenta_qb);
    end if;
    -- La factura: existe, y su obra manda.
    v_f := null;
    if r.factura_id is not null then
      select * into v_f from facturas f where f.id = r.factura_id;
      if not found then
        -- factura_id es el id interno de la app, no el número de la
        -- factura: si hay una con ese NÚMERO, se dice cuál.
        select string_agg(format('#%s es la factura id %s (%s)', f.num, f.id, coalesce(f.proyecto_id, 'sin obra')), '; '
                          order by f.id)
          into v_hint
          from facturas f
         where btrim(f.num) = r.factura_id::text;
        raise exception using errcode = 'MX008',
          message = format('La factura con id %s (fila %s, %s) no está en la app: sin ella, lo que se cobre en octubre no tiene a '
                           'qué aplicarse.%s', r.factura_id, r.linea, r.cuenta_qb,
                           case when v_hint is not null
                                then format(' factura_id es el id de la app, no el número de la factura: %s. Pon en la fila '
                                            'factura_num «%s» (o su id) y vuelve a cargar la balanza.', v_hint, r.factura_id)
                                else ' Dala de alta en la app con su número y su fecha de QuickBooks, y ponla en la fila con '
                                     'factura_num (su número).' end);
      end if;
      if v_obra is not null and v_obra is distinct from v_f.proyecto_id then
        raise exception using errcode = 'MX006',
          message = format('La fila %s dice la obra %s, y su factura #%s es de %s: una factura va con su obra.', r.linea, v_obra,
                           v_f.num, coalesce(v_f.proyecto_id, 'ninguna'));
      end if;
      v_obra := v_f.proyecto_id;
      if v_m.cuenta not in (v_cxc, v_ret) then
        raise exception using errcode = 'MX006',
          message = format('La fila %s («%s», a la %s) dice una factura: solo las cuentas por cobrar (%s) y la retención (%s) van '
                           'por factura.', r.linea, r.cuenta_qb, v_m.cuenta, v_cxc, v_ret);
      end if;
    end if;
    v_memo := concat_ws(' · ', 'QuickBooks: ' || r.cuenta_qb, r.cliente_trabajo, 'factura #' || v_f.num, r.proveedor_qb,
                        r.referencia);
    -- (Para el control: el activo, según el mapeo.)
    if v_c.tipo = 'activo' then
      v_activo := v_activo + v_saldo;
    end if;

    if v_c.tipo not in ('activo', 'pasivo', 'capital') then
      -- Resultados de enero a septiembre: a utilidades retenidas.
      v_res   := v_res + v_saldo;
      v_rtipo := jsonb_set(v_rtipo, array[v_c.tipo], to_jsonb(coalesce((v_rtipo->>v_c.tipo)::numeric, 0) + v_saldo));
      v_raw   := v_raw || jsonb_build_object('cuenta', '3900', 'monto', v_saldo, 'clase', 'resultado', 'memo', null);
      continue;
    end if;

    if v_m.cuenta = v_cxc then
      if r.factura_id is null then
        if v_saldo > 0 then
          raise exception using errcode = 'MX008',
            message = format('Las cuentas por cobrar de QuickBooks van factura por factura: la fila %s («%s», %s%s) no dice '
                             'cuál. Ponle su número de factura (factura_num, como lo trae el A/R Aging) y vuelve a cargar la '
                             'balanza; si la factura no está en la app, dala de alta con su fecha de QuickBooks.',
                             r.linea, r.cuenta_qb, v_saldo, coalesce(', ' || r.cliente_trabajo, ''));
        end if;
        v_raw := v_raw || jsonb_build_object('cuenta', v_cxc, 'monto', v_saldo, 'proyecto_id', v_obra, 'memo', v_memo);
      else
        -- Un saldo a favor (negativo) no va por factura: es del cliente, en
        -- su obra (una factura pagada de más, un crédito).
        if v_saldo < 0 then
          raise exception using errcode = 'MX006',
            message = format('La fila %s (factura #%s, %s) es un saldo a favor del cliente: no va por factura. Quita factura_id '
                             '(y factura_num) de esa fila y di su obra (cliente_trabajo o proyecto_id): entra a %s como saldo a '
                             'favor de la obra %s.', r.linea, v_f.num, v_saldo, v_cxc, coalesce(v_f.proyecto_id, '(sin obra)'));
        end if;
        v_rt := coalesce(r.retencion, 0);
        if v_rt > 0 and v_rt > v_saldo then
          raise exception using errcode = 'MX006',
            message = format('La retención de la factura #%s (%s, fila %s) es mayor que su saldo (%s).', v_f.num, v_rt, r.linea,
                             v_saldo);
        end if;
        if v_rt > 0 and v_obra is null then
          raise exception using errcode = 'MX006',
            message = format('La factura #%s (fila %s) no tiene obra: su retención va a %s por obra. Ponle su obra en la app.',
                             v_f.num, r.linea, v_ret);
        end if;
        if v_saldo - v_rt <> 0 then
          v_raw := v_raw || jsonb_build_object('cuenta', v_cxc, 'monto', v_saldo - v_rt, 'proyecto_id', v_obra,
                                               'partida_tabla', 'facturas', 'partida_id', r.factura_id::text, 'memo', v_memo);
        end if;
        if v_rt > 0 then
          v_raw := v_raw || jsonb_build_object('cuenta', v_ret, 'monto', v_rt, 'proyecto_id', v_obra,
                                               'partida_tabla', 'facturas', 'partida_id', r.factura_id::text,
                                               'memo', v_memo || ' · retención');
          v_rsplit := v_rsplit + v_rt;
          v_robra := jsonb_set(v_robra, array[v_obra], to_jsonb(coalesce((v_robra->>v_obra)::numeric, 0) + v_rt));
          if not r.cuenta_qb = any (v_rqb) then
            v_rqb := v_rqb || r.cuenta_qb;
          end if;
        end if;
      end if;
    elsif v_m.cuenta = v_ret then
      -- La retención por cobrar, por FACTURA (ver arriba): contra esa
      -- partida cobra c3 la retención en octubre.
      if r.factura_id is null then
        select string_agg(format('#%s (id %s, retención %s)', f.num, f.id, f.retencion), ', ' order by f.id)
          into v_hint
          from facturas f
         where v_obra is not null and f.proyecto_id = v_obra and coalesce(f.retencion, 0) > 0
           and coalesce(f.estado, 'emitida') <> 'anulada' and f.fecha <= v_ap.hasta;
        raise exception using errcode = 'MX006',
          message = format('La retención por cobrar va por factura, como la cuenta por cobrar: la fila %s («%s», %s%s) no dice de '
                           'cuál. c3 cobra la retención de octubre contra la partida de SU factura; por obra, ese cobro no '
                           'cabría. Parte la fila por factura, con su número de QuickBooks (factura_num) o su id en la app '
                           '(factura_id), y vuelve a cargar la balanza.%s', r.linea, r.cuenta_qb, v_saldo,
                           coalesce(', ' || r.cliente_trabajo, ''),
                           coalesce(format(' En la app, la obra %s tiene retención en: %s.', v_obra, v_hint), ''));
      end if;
      if v_saldo < 0 then
        raise exception using errcode = 'MX006',
          message = format('La fila %s (retención de la factura #%s, %s) es un saldo a favor del cliente: no va a la retención '
                           'por cobrar de una factura. Pásalo a su cuenta por cobrar, sin factura, con su obra.', r.linea, v_f.num,
                           v_saldo);
      end if;
      if v_obra is null then
        raise exception using errcode = 'MX006',
          message = format('La factura #%s (fila %s) no tiene obra: su retención va a %s con la obra de la factura. Ponle su obra '
                           'en la app.', v_f.num, r.linea, v_ret);
      end if;
      v_raw := v_raw || jsonb_build_object('cuenta', v_ret, 'monto', v_saldo, 'proyecto_id', v_obra,
                                           'partida_tabla', 'facturas', 'partida_id', r.factura_id::text, 'memo', v_memo);
    elsif v_m.cuenta = v_cxp
          or exists (select 1 from estados_mapeo em
                      where em.cuenta = v_m.cuenta and em.estado = 'balance' and em.linea = 'retencion_por_pagar') then
      -- Lo que se paga POR PROVEEDOR: la cuenta por pagar y la retención
      -- por pagar a subcontratistas (ver arriba).
      v_pago := v_m.cuenta = v_cxp;
      v_prov := r.proveedor_id;
      if v_prov is null and r.proveedor_qb is not null then
        select a.proveedor_id into v_prov
          from proveedores_alias a
         where a.alias = nullif(lower(btrim(regexp_replace(r.proveedor_qb, '[[:space:]]+', ' ', 'g'))), '');
        if v_prov is null then
          raise exception using errcode = 'MX008',
            message = format('El proveedor de QuickBooks «%s» (fila %s, %s) no está dado de alta (o no con ese nombre): select '
                             'fn_proveedor_alta(%L, ''Net 30''); con sus términos, o si es otro nombre de uno que ya está, '
                             'fn_proveedor_alias.', r.proveedor_qb, r.linea, v_saldo, r.proveedor_qb);
        end if;
      end if;
      if v_prov is null then
        raise exception using errcode = 'MX008',
          message = format('%s van por proveedor: la fila %s («%s», %s) no dice de quién (proveedor_qb o proveedor_id).',
                           case when v_pago then 'Las cuentas por pagar'
                                else format('La retención por pagar a subcontratistas (%s) y su pago', v_m.cuenta) end,
                           r.linea, r.cuenta_qb, v_saldo);
      end if;
      if v_c.regla_obra = 'obligatoria' and v_obra is null then
        raise exception using errcode = 'MX006',
          message = format('La cuenta %s (%s) va por obra: la fila %s («%s», %s) no dice de qué obra (proyecto_id o su '
                           'Customer:Job).', v_c.codigo, v_c.nombre, r.linea, r.cuenta_qb, v_saldo);
      end if;
      if not exists (select 1 from proveedores p where p.id = v_prov) then
        raise exception using errcode = 'MX008', message = format('El proveedor %s (fila %s) no existe.', v_prov, r.linea);
      end if;
      if r.recibo_id is not null and not exists (select 1 from recibos x where x.id = r.recibo_id) then
        raise exception using errcode = 'MX008', message = format('El recibo %s (fila %s) no está en la app.', r.recibo_id, r.linea);
      end if;
      if r.trabajo_externo_id is not null and not exists (select 1 from trabajos_externos x where x.id = r.trabajo_externo_id) then
        raise exception using errcode = 'MX008',
          message = format('El trabajo externo %s (fila %s) no está en la app.', r.trabajo_externo_id, r.linea);
      end if;
      v_raw := v_raw || jsonb_build_object(
                 'cuenta', v_m.cuenta, 'monto', v_saldo, 'tercero_tipo', 'proveedor', 'tercero_id', v_prov::text,
                 'proyecto_id', case when v_c.regla_obra <> 'prohibida' then v_obra end,
                 'partida_tabla', case when r.recibo_id is not null then 'recibos'
                                       when r.trabajo_externo_id is not null then 'trabajos_externos' end,
                 'partida_id', coalesce(r.recibo_id, r.trabajo_externo_id)::text, 'memo', v_memo);
    else
      if v_c.regla_obra = 'obligatoria' and v_obra is null then
        raise exception using errcode = 'MX006',
          message = format('La cuenta %s (%s) va por obra: la fila %s («%s», %s) no dice de qué obra (proyecto_id o su '
                           'Customer:Job).', v_c.codigo, v_c.nombre, r.linea, r.cuenta_qb, v_saldo);
      end if;
      v_raw := v_raw || jsonb_build_object('cuenta', v_c.codigo, 'monto', v_saldo,
                                           'proyecto_id', case when v_c.regla_obra <> 'prohibida' then v_obra end,
                                           'memo', v_memo);
    end if;
  end loop;

  -- 3. El control de QuickBooks: lo que da el mapeo tiene que ser lo que
  -- QuickBooks dice por su lado (la utilidad de enero a septiembre y el
  -- total del activo). Si no, una cuenta está mapeada al lado equivocado.
  select count(*) filter (where b.control = 'utilidad'),
         -sum(coalesce(b.debe, 0) - coalesce(b.haber, 0)) filter (where b.control = 'utilidad'),
         count(*) filter (where b.control = 'activo'),
         sum(coalesce(b.debe, 0) - coalesce(b.haber, 0)) filter (where b.control = 'activo')
    into v_nu, v_cu, v_na, v_ca
    from apertura_balanza_qb b
   where b.documento = p_documento and b.control is not null;
  if v_nu = 0 or v_na = 0 then
    raise exception using errcode = 'MX001',
      message = format('La balanza %s no trae su control de QuickBooks (falta %s). Sin él, la apertura se compara contra la misma '
                       'balanza pasada por el mismo mapeo, y un mapeo equivocado (una cuenta de resultados a una de balance) '
                       'pasa en verde. Añade a la lista de fn_apertura_balanza_cargar las filas «Net Income» (la utilidad de '
                       'enero a septiembre; en haber si es utilidad) y «TOTAL ASSETS» de su Balance Sheet al %s, y vuelve a '
                       'cargarla.', p_documento,
                       concat_ws(' y ', case when v_nu = 0 then '«Net Income»' end, case when v_na = 0 then '«TOTAL ASSETS»' end),
                       to_char(v_ap.hasta, 'DD-MM-YYYY'));
  end if;
  if v_cu <> -v_res or v_ca <> v_activo then
    -- Las filas que lo pueden explicar: las de ese monto.
    select string_agg(format('fila %s «%s» (%s) va a %s, de %s', b.linea, b.cuenta_qb, coalesce(b.debe, 0) - coalesce(b.haber, 0),
                             m.cuenta, c.tipo), '; ' order by b.linea)
      into v_hint
      from apertura_balanza_qb b
      join apertura_mapeo_qb m on m.tipo = 'cuenta' and m.clave = b.clave
      join cuentas c on c.codigo = m.cuenta
     where b.documento = p_documento and b.control is null
       and abs(coalesce(b.debe, 0) - coalesce(b.haber, 0)) in (abs(v_cu + v_res), abs(v_ca - v_activo))
       and abs(coalesce(b.debe, 0) - coalesce(b.haber, 0)) <> 0;
    raise exception using errcode = 'MX001',
      message = format('La balanza %s no amarra con su control de QuickBooks: con el mapeo de hoy la utilidad de enero a septiembre '
                       'es %s y QuickBooks dice %s (Net Income); el activo es %s y QuickBooks dice %s (TOTAL ASSETS). Una '
                       'cuenta está mapeada al lado equivocado (resultados ↔ balance) o a otra clase: corrige su mapeo '
                       '(fn_apertura_mapeo_qb) y míralo fila por fila con select * from fn_apertura_revisar(%L);.%s',
                       p_documento, -v_res, v_cu, v_activo, v_ca, p_documento,
                       coalesce(' Pueden ser: ' || v_hint || '.', ''));
  end if;

  -- 4. Las líneas iguales, en una; el resultado de enero a septiembre, con
  -- su nota.
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'cuenta', x.cuenta, 'monto', x.monto::text, 'proyecto_id', x.proyecto_id,
           'tercero_tipo', x.tercero_tipo, 'tercero_id', x.tercero_id,
           'partida_tabla', x.partida_tabla, 'partida_id', x.partida_id,
           'memo', left(x.memo, 300)))
         order by x.cuenta, x.clase nulls first, x.proyecto_id nulls first, x.partida_tabla nulls first, x.partida_id,
                  x.tercero_id), '[]'::jsonb)
    into v_lineas
    from (select y.cuenta, y.clase, y.proyecto_id, y.tercero_tipo, y.tercero_id, y.partida_tabla, y.partida_id,
                 sum(y.monto) as monto,
                 case when y.clase = 'resultado'
                      then format('Resultado de enero a septiembre de %s según QuickBooks: utilidad %s (ingresos %s, costo %s, '
                                  'gastos %s). La apertura es balance únicamente: ese resultado queda en utilidades retenidas.',
                                  extract(year from v_ap.desde), -v_res,
                                  -(coalesce((v_rtipo->>'ingreso')::numeric, 0) + coalesce((v_rtipo->>'otro_ingreso')::numeric, 0)),
                                  coalesce((v_rtipo->>'costo')::numeric, 0),
                                  coalesce((v_rtipo->>'gasto')::numeric, 0) + coalesce((v_rtipo->>'otro_gasto')::numeric, 0))
                      else string_agg(distinct y.memo, '; ') end as memo
            from jsonb_to_recordset(v_raw) as y(cuenta text, monto numeric, clase text, proyecto_id text, tercero_tipo text,
                                                tercero_id text, partida_tabla text, partida_id text, memo text)
           group by y.cuenta, y.clase, y.proyecto_id, y.tercero_tipo, y.tercero_id, y.partida_tabla, y.partida_id
          having sum(y.monto) <> 0) x;

  select jsonb_build_object(
           'facturas', coalesce(jsonb_agg(distinct (l->>'partida_id')::bigint) filter (where l->>'partida_tabla' = 'facturas'), '[]'),
           'recibos', coalesce(jsonb_agg(distinct (l->>'partida_id')::bigint) filter (where l->>'partida_tabla' = 'recibos'), '[]'),
           'trabajos_externos', coalesce(jsonb_agg(distinct (l->>'partida_id')::bigint)
                                           filter (where l->>'partida_tabla' = 'trabajos_externos'), '[]'))
    into v_part
    from jsonb_array_elements(v_lineas) l;

  return jsonb_build_object(
    'documento', p_documento, 'periodo', v_ap.periodo, 'fecha', v_ap.desde, 'lineas', v_lineas,
    'filas_qb', v_filas, 'ignoradas_en_cero', v_cero, 'debe', v_debe, 'haber', v_haber,
    'control_qb', jsonb_build_object('utilidad', v_cu, 'activo', v_ca, 'amarra', true),
    'resultado_qb', jsonb_build_object('utilidad', -v_res, 'saldo_por_tipo', v_rtipo),
    'retencion_partida', jsonb_build_object('monto', v_rsplit, 'por_obra', v_robra, 'cuentas_qb', to_jsonb(v_rqb)),
    'partidas', v_part);
end $$;
revoke execute on function public.fn_apertura_plan(text) from public, anon, authenticated, service_role;

-- La apertura, como tabla (para mirarla en el SQL Editor antes de postear):
--   select * from fn_apertura_revisar('docs/apertura/balanza-2026-09-30.csv');
-- Primero, FILA POR FILA DE QUICKBOOKS (que = 'balanza'): a qué cuenta del
-- plan va y de qué TIPO es (activo, pasivo, capital, ingreso, costo,
-- gasto…), su obra, su partida y su proveedor: así se audita el mapeo, no
-- solo los saldos (una cuenta de costo de QuickBooks que va a 1300, activo,
-- se ve aquí). Después, el CONTROL de QuickBooks (que = 'control': Net
-- Income y TOTAL ASSETS) contra lo que da el mapeo. Y al final, el asiento
-- que saldría (que = 'asiento'), o, si la balanza no se puede postear, el
-- primer problema con su nombre (que = 'problema', MX001…).
drop function if exists public.fn_apertura_revisar(text);
create or replace function public.fn_apertura_revisar(p_documento text)
returns table (orden int, que text, fila_qb int, cuenta_qb text, debe numeric(14,2), haber numeric(14,2), cuenta text,
               cuenta_nombre text, tipo text, obra text, partida text, proveedor text, memo text)
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_plan jsonb;
  v_err  text;
  v_n    int := 0;
  v_res  numeric;
  v_act  numeric;
begin
  perform fn_estados_exigir_dueno();
  -- Lo que da el mapeo (para el control).
  select -sum(coalesce(b.debe, 0) - coalesce(b.haber, 0)) filter (where c.tipo not in ('activo', 'pasivo', 'capital')),
         sum(coalesce(b.debe, 0) - coalesce(b.haber, 0)) filter (where c.tipo = 'activo')
    into v_res, v_act
    from apertura_balanza_qb b
    join apertura_mapeo_qb m on m.tipo = 'cuenta' and m.clave = b.clave
    join cuentas c on c.codigo = m.cuenta
   where b.documento = p_documento and b.control is null;
  -- 1. Cada fila de QuickBooks, y el control.
  return query
    select (row_number() over (order by (b.control is not null), b.linea))::int,
           case when b.control is null then 'balanza' else 'control' end,
           b.linea, b.cuenta_qb, b.debe, b.haber,
           case when b.control is null then m.cuenta end, case when b.control is null then c.nombre end,
           case when b.control is null then c.tipo end,
           coalesce(b.proyecto_id, mt.proyecto_id, f.proyecto_id),
           case when b.factura_id is not null then 'facturas/' || b.factura_id
                when b.recibo_id is not null then 'recibos/' || b.recibo_id
                when b.trabajo_externo_id is not null then 'trabajos_externos/' || b.trabajo_externo_id end,
           coalesce(b.proveedor_qb, (select pr.nombre from proveedores pr where pr.id = b.proveedor_id)),
           case b.control
             when 'utilidad' then format('Control: la utilidad de enero a septiembre según QuickBooks es %s; según el mapeo, %s: %s',
                                         -(coalesce(b.debe, 0) - coalesce(b.haber, 0)), coalesce(v_res, 0),
                                         case when -(coalesce(b.debe, 0) - coalesce(b.haber, 0)) = coalesce(v_res, 0)
                                              then 'coincide' else 'NO COINCIDE (una cuenta mapeada al lado equivocado)' end)
             when 'activo' then format('Control: el total del activo según QuickBooks es %s; según el mapeo, %s: %s',
                                       coalesce(b.debe, 0) - coalesce(b.haber, 0), coalesce(v_act, 0),
                                       case when coalesce(b.debe, 0) - coalesce(b.haber, 0) = coalesce(v_act, 0)
                                            then 'coincide' else 'NO COINCIDE (una cuenta mapeada a otra clase)' end)
             else case when m.cuenta is null then 'SIN MAPEO: select fn_apertura_mapeo_qb(''' || b.cuenta_qb
                                                  || ''', ''<cuenta del plan>'');'
                       when c.tipo not in ('activo', 'pasivo', 'capital')
                         then 'De resultados (enero a septiembre): entra a 3900 en una línea (la apertura es balance únicamente)'
                  end
           end
      from apertura_balanza_qb b
      left join apertura_mapeo_qb m on m.tipo = 'cuenta' and m.clave = b.clave
      left join cuentas c on c.codigo = m.cuenta
      left join apertura_mapeo_qb mt on mt.tipo = 'trabajo' and mt.clave = b.cliente_clave
      left join facturas f on f.id = b.factura_id
     where b.documento = p_documento
     order by 1;
  get diagnostics v_n = row_count;
  -- 2. El asiento que saldría, o el primer problema con su nombre.
  begin
    v_plan := fn_apertura_plan(p_documento);
  exception when others then
    v_err := sqlstate || ': ' || sqlerrm;
  end;
  if v_err is not null then
    return query select v_n + 1, 'problema'::text, null::int, null::text, null::numeric(14,2), null::numeric(14,2), null::text,
                        null::text, null::text, null::text, null::text, null::text, v_err;
    return;
  end if;
  return query
    select (v_n + l.n)::int, 'asiento'::text, null::int, null::text,
           greatest((l.v->>'monto')::numeric, 0)::numeric(14,2), greatest(-(l.v->>'monto')::numeric, 0)::numeric(14,2),
           l.v->>'cuenta', c.nombre, c.tipo, l.v->>'proyecto_id', (l.v->>'partida_tabla') || '/' || (l.v->>'partida_id'),
           p.nombre, l.v->>'memo'
      from jsonb_array_elements(v_plan->'lineas') with ordinality as l(v, n)
      left join cuentas c on c.codigo = l.v->>'cuenta'
      left join proveedores p on p.id::text = l.v->>'tercero_id'
     order by l.n;
end $$;
revoke execute on function public.fn_apertura_revisar(text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_apertura(fecha, documento [, motivo]) — postea el asiento de apertura
-- con la balanza «documento» (ya cargada con fn_apertura_balanza_cargar),
-- por la puerta de c2 (fn_postear_interno): tipo 'apertura', camino
-- 'mano' (lo postea Edgar desde el SQL Editor), en el período de la
-- apertura, con su papel (origen apertura_balanza_qb / el período de la
-- apertura, documento_ruta = la balanza). No va por el camino 'puente':
-- el de apertura es un asiento que c2 deja reversar con fn_reversar
-- mientras la apertura está abierta y que, cerrada, manda al ajuste a la
-- apertura (MX007); y c3 no deja que nada anterior al corte (1-oct) entre
-- por un puente. «Su» apertura es la que posteó esta función
-- (procedencia 'fn_apertura'): una apertura viva hecha a mano (aunque
-- herede el origen de la que sustituye) la para (MX007: se reversa antes).
-- Idempotente:
--   · con la MISMA balanza ya en el libro y el mismo plan (las mismas
--     líneas: nada cambió en el mapeo): no hace nada (sin_cambios). Si la
--     balanza cambió desde que entró (su huella, md5 de sus filas, no es la
--     que guardó el asiento), para (MX007);
--   · con OTRA balanza, o con la misma y un plan distinto (un mapeo o un
--     Customer:Job corregido), y ya hay apertura viva: NO la pisa. Dice qué
--     cambia, renglón por renglón, y para (MX007, sin tocar nada). Si lo
--     nuevo es lo bueno (QuickBooks corrigió septiembre, o el mapeo estaba
--     mal), se repite con el motivo: la apertura vieja se reversa y la
--     nueva la sustituye (sustituye_a), el mismo día. Con la apertura ya
--     cerrada, c2 no deja reversarla: lo que falte se corrige con un
--     ajuste a la apertura (ajuste_cpa).
-- Bloquea las filas de la balanza mientras la postea (una recarga del
-- mismo documento espera, y después su guarda la para): el asiento y su
-- papel dicen siempre lo mismo.
-- Después, pasa los puentes de c3 por cada factura, recibo y trabajo
-- externo que la apertura nombra (y por los que nombraba la anterior): un
-- papel que ya había entrado por su puente se reversa (queda el de la
-- apertura), y uno que la apertura ya no nombra vuelve a su puente.
-- Y anota sola la diferencia de criterio que crea: la retención que
-- QuickBooks tiene dentro de cuentas por cobrar y el libro parte a 1120
-- (clase criterio, origen 'fn_apertura'), para que v_comparacion de la
-- apertura quede en cero sin explicar.
--   select fn_apertura('2026-09-30', 'docs/apertura/balanza-2026-09-30.csv');
-- ---------------------------------------------------------------------
create or replace function public.fn_apertura(p_fecha date, p_documento text, p_motivo text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_ap      periodos;
  v_doc     text := btrim(p_documento);
  v_vivo    asientos;
  v_otra    text;
  v_plan    jsonb;
  v_cambios jsonb;
  v_n       int;
  v_lista   text;
  v_sust    uuid;
  v_rev     jsonb;
  v_res     jsonb;
  v_ids     bigint[];
  v_id      bigint;
  v_puentes jsonb := '[]'::jsonb;
  v_cxc     text := (select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc');
  v_ret     text := (select pc.cuenta from puente_cuentas pc where pc.rol = 'retencion_cxc');
  v_rsplit  numeric;
  v_dif     int := 0;
  v_huella  text;
begin
  perform fn_estados_exigir_dueno();
  if coalesce(v_doc, '') = '' then
    raise exception using errcode = '22023', message = 'Falta el documento: la balanza de QuickBooks cargada (su ruta).';
  end if;
  -- El candado de los períodos (como los puentes: nadie cierra la apertura
  -- mientras tanto), el de la apertura (dos a la vez, una espera; y una
  -- carga de balanza también) y el de las filas de SU balanza: una recarga
  -- del mismo documento espera a que esto termine, y entonces su guarda ve
  -- el asiento y la para.
  perform 1 from periodos for share;
  perform pg_advisory_xact_lock(820260930);
  perform 1 from apertura_balanza_qb b where b.documento = v_doc for share;
  select * into v_ap from periodos where tipo = 'apertura' order by desde limit 1;
  if not found then
    raise exception using errcode = 'MX002', message = 'No hay período de apertura en el calendario (c2).';
  end if;
  if p_fecha is distinct from v_ap.desde then
    raise exception using errcode = 'MX002',
      message = format('La apertura va fechada el día de la apertura, el %s (llegó %s).', v_ap.desde, coalesce(p_fecha::text, 'nada'));
  end if;
  -- Un asiento de apertura vivo que no es de esta función (uno a mano,
  -- aunque herede el origen del que sustituye): dos aperturas duplicarían
  -- los saldos, y esta función no lo reconoce como suyo.
  select string_agg(a.numero, ', ') into v_otra
    from asientos a
   where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
     and coalesce(a.procedencia->>'funcion', '') <> 'fn_apertura'
     and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso');
  if v_otra is not null then
    raise exception using errcode = 'MX007',
      message = format('Ya hay un asiento de apertura a mano (%s): la apertura de la balanza lo duplicaría. Revérsalo antes '
                       '(fn_reversar, con la apertura abierta) y vuelve a correr esto.', v_otra);
  end if;

  select a.* into v_vivo
    from asientos a
   where a.tipo = 'apertura' and a.origen_tabla = 'apertura_balanza_qb' and a.origen_id = v_ap.periodo
     and coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'
     and a.camino not in ('reverso', 'reverso_automatico')
     and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')
   order by a.cadena_pos desc
   limit 1;

  -- La huella de la balanza: sus filas, en orden (lo que el asiento guarda
  -- de su papel; fn_estados_control la vuelve a calcular).
  select md5(coalesce(string_agg(row(b.linea, b.cuenta_qb, b.debe, b.haber, b.factura_id, b.retencion, b.cliente_trabajo,
                                     b.proyecto_id, b.proveedor_qb, b.proveedor_id, b.recibo_id, b.trabajo_externo_id,
                                     b.referencia, b.notas, b.fecha_documento, b.vence, b.factura_num)::text,
                                 E'\n' order by b.linea), ''))
    into v_huella
    from apertura_balanza_qb b
   where b.documento = v_doc;

  v_plan := fn_apertura_plan(v_doc);

  if v_vivo.id is not null then
    -- Lo que cambia, renglón por renglón, entre el asiento vivo y el plan
    -- de hoy (con otra balanza, o con la misma y otro mapeo).
    with a as (
      select concat_ws('|', l.cuenta, coalesce(l.proyecto_id, '-'), coalesce(l.partida_tabla || '/' || l.partida_id, '-'),
                       coalesce(l.tercero_id, '-')) as k,
             l.cuenta, l.proyecto_id, l.partida_tabla || '/' || l.partida_id as partida, l.tercero_id, sum(l.monto) as m
        from asiento_lineas l
       where l.asiento_id = v_vivo.id
       group by 1, 2, 3, 4, 5
    ), b as (
      select concat_ws('|', x.cuenta, coalesce(x.proyecto_id, '-'), coalesce(x.partida_tabla || '/' || x.partida_id, '-'),
                       coalesce(x.tercero_id, '-')) as k,
             x.cuenta, x.proyecto_id, x.partida_tabla || '/' || x.partida_id as partida, x.tercero_id, sum(x.monto::numeric) as m
        from jsonb_to_recordset(v_plan->'lineas') as x(cuenta text, monto text, proyecto_id text, partida_tabla text,
                                                       partida_id text, tercero_id text)
       group by 1, 2, 3, 4, 5
    )
    select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
             'cuenta', coalesce(a.cuenta, b.cuenta), 'obra', coalesce(a.proyecto_id, b.proyecto_id),
             'partida', coalesce(a.partida, b.partida), 'tercero', coalesce(a.tercero_id, b.tercero_id),
             'antes', coalesce(a.m, 0), 'despues', coalesce(b.m, 0), 'cambio', coalesce(b.m, 0) - coalesce(a.m, 0)))
             order by coalesce(a.k, b.k)), '[]'::jsonb),
           count(*),
           string_agg(format('%s%s%s: %s → %s', coalesce(a.cuenta, b.cuenta),
                             coalesce(' ' || coalesce(a.proyecto_id, b.proyecto_id), ''),
                             coalesce(' ' || coalesce(a.partida, b.partida), ''), coalesce(a.m, 0), coalesce(b.m, 0)),
                      '; ' order by coalesce(a.k, b.k))
      into v_cambios, v_n, v_lista
      from a
      full join b on b.k = a.k
     where coalesce(a.m, 0) <> coalesce(b.m, 0);
    if v_vivo.documento_ruta = v_doc and v_n = 0 then
      if v_vivo.procedencia ? 'huella_balanza' and v_vivo.procedencia->>'huella_balanza' is distinct from v_huella then
        raise exception using errcode = 'MX007',
          message = format('La balanza %s cambió desde que entró al libro (asiento %s): sus filas ya no son las que se '
                           'postearon (su huella no es la del asiento). El papel de un asiento no cambia: revisa quién la tocó '
                           '(las guardas de 1.6 no lo dejan) y vuelve a cargar la buena con otro documento.', v_doc,
                           v_vivo.numero);
      end if;
      return jsonb_build_object('accion', 'sin_cambios', 'asiento', v_vivo.numero, 'id', v_vivo.id, 'documento', v_doc,
                                'mensaje', format('La apertura ya está en el libro con esta balanza y este mapeo (asiento %s): '
                                                  'no se postea otra vez.', v_vivo.numero));
    end if;
    if coalesce(btrim(p_motivo), '') = '' then
      raise exception using errcode = 'MX007',
        message = case
                    when v_vivo.documento_ruta = v_doc
                      then format('La apertura ya está en el libro con la balanza %s (asiento %s), pero con el mapeo de hoy '
                                  'cambia en %s renglón(es): %s. No se tocó nada. Si el mapeo de hoy es el bueno, repite con '
                                  'el motivo: select fn_apertura(%L, %L, ''motivo'');', v_doc, v_vivo.numero, v_n,
                                  left(v_lista, 900), v_ap.desde, v_doc)
                    else format('La apertura ya está en el libro con la balanza %s (asiento %s). La balanza %s la cambia en %s '
                                'renglón(es): %s. No se tocó nada. Si %s es la buena, repite con el motivo: select '
                                'fn_apertura(%L, %L, ''motivo'');', v_vivo.documento_ruta, v_vivo.numero, v_doc, v_n,
                                coalesce(left(v_lista, 900), 'ninguno (las mismas cifras)'), v_doc, v_ap.desde, v_doc) end,
        detail = v_cambios::text;
    end if;
    v_rev := fn_reversar_interno(v_vivo.id, format('Apertura rehecha con la balanza %s: %s', v_doc, btrim(p_motivo)),
                                 'reverso', jsonb_build_object('funcion', 'fn_apertura', 'documento_nuevo', v_doc,
                                                               'cambios', v_cambios));
    v_sust := v_vivo.id;
  else
    -- Una apertura reversada antes (sin sustituto todavía): la nueva la
    -- sustituye.
    select a.id into v_sust
      from asientos a
     where a.origen_tabla = 'apertura_balanza_qb' and a.origen_id = v_ap.periodo
       and a.camino not in ('reverso', 'reverso_automatico')
       and not exists (select 1 from asientos s where s.sustituye_a = a.id)
     order by a.cadena_pos desc
     limit 1;
  end if;

  v_res := fn_postear_interno(jsonb_strip_nulls(jsonb_build_object(
             'camino', 'mano', 'tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
             'descripcion', format('Apertura al %s: balanza de QuickBooks %s', to_char(v_ap.desde, 'DD-MM-YYYY'), v_doc),
             'lineas', v_plan->'lineas',
             'origen_tabla', 'apertura_balanza_qb', 'origen_id', v_ap.periodo, 'documento_ruta', v_doc,
             'sustituye_a', v_sust,
             'procedencia', jsonb_strip_nulls(jsonb_build_object(
                              'funcion', 'fn_apertura', 'documento', v_doc, 'huella_balanza', v_huella,
                              'filas_qb', v_plan->'filas_qb',
                              'ignoradas_en_cero', v_plan->'ignoradas_en_cero', 'resultado_qb', v_plan->'resultado_qb',
                              'retencion_partida', v_plan->'retencion_partida', 'motivo_edgar', nullif(btrim(p_motivo), ''),
                              'sustituye', (select a.numero from asientos a where a.id = v_sust))))));

  -- Los puentes de los papeles que la apertura nombra, y de los que nombraba
  -- la anterior.
  select array_agg(distinct x.id order by x.id) into v_ids
    from (select (e.v)::bigint as id from jsonb_array_elements_text(v_plan->'partidas'->'facturas') e(v)
          union
          select l.partida_id::bigint from asiento_lineas l
           where l.asiento_id = v_sust and l.partida_tabla = 'facturas' and l.partida_id ~ '^-?[0-9]{1,18}$') x;
  foreach v_id in array coalesce(v_ids, '{}') loop
    if exists (select 1 from facturas f where f.id = v_id) then
      v_puentes := v_puentes || jsonb_build_object('facturas', v_id, 'puente', fn_puente_factura(v_id, 'apertura'));
    end if;
  end loop;
  select array_agg(distinct x.id order by x.id) into v_ids
    from (select (e.v)::bigint as id from jsonb_array_elements_text(v_plan->'partidas'->'recibos') e(v)
          union
          select l.partida_id::bigint from asiento_lineas l
           where l.asiento_id = v_sust and l.partida_tabla = 'recibos' and l.partida_id ~ '^-?[0-9]{1,18}$') x;
  foreach v_id in array coalesce(v_ids, '{}') loop
    if exists (select 1 from recibos r where r.id = v_id) then
      v_puentes := v_puentes || jsonb_build_object('recibos', v_id, 'puente', fn_puente_recibo(v_id, 'apertura'));
    end if;
  end loop;
  select array_agg(distinct x.id order by x.id) into v_ids
    from (select (e.v)::bigint as id from jsonb_array_elements_text(v_plan->'partidas'->'trabajos_externos') e(v)
          union
          select l.partida_id::bigint from asiento_lineas l
           where l.asiento_id = v_sust and l.partida_tabla = 'trabajos_externos' and l.partida_id ~ '^-?[0-9]{1,18}$') x;
  foreach v_id in array coalesce(v_ids, '{}') loop
    if exists (select 1 from trabajos_externos t where t.id = v_id) then
      v_puentes := v_puentes || jsonb_build_object('trabajos_externos', v_id, 'puente', fn_puente_externo(v_id, 'apertura'));
    end if;
  end loop;

  -- La diferencia de criterio que crea: la retención partida a 1120.
  update diferencias
     set retirada_el = clock_timestamp(), retirada_por = auth.uid(),
         retirada_motivo = format('La apertura se rehízo con la balanza %s (asiento %s).', v_doc, v_res->>'numero')
   where periodo = v_ap.periodo and origen = 'fn_apertura' and retirada_el is null;
  v_rsplit := coalesce((v_plan->'retencion_partida'->>'monto')::numeric, 0);
  if v_rsplit <> 0 then
    -- Una por obra y cuenta: así la comparación por obra también queda
    -- explicada (la de por cuenta suma las de todas las obras).
    insert into diferencias (periodo, cuenta, proyecto_id, monto, clase, explicacion, asiento_id, origen, anotado_por, anotado_rol)
    select v_ap.periodo, x.cuenta, o.key, x.signo * o.value::numeric, 'criterio',
           case when x.signo < 0
                then format('La retención de las facturas abiertas de esta obra (%s) viene en QuickBooks dentro de %s; el libro la '
                            'parte a %s, por obra y por factura (f04).', o.value,
                            (select string_agg(e.v, ', ') from jsonb_array_elements_text(v_plan->'retencion_partida'->'cuentas_qb') e(v)),
                            v_ret)
                else format('La retención de las facturas abiertas de esta obra (%s), que QuickBooks tiene dentro de cuentas por '
                            'cobrar, va aquí por obra y por factura (f04).', o.value) end,
           (v_res->>'id')::uuid, 'fn_apertura', auth.uid(), fn_rol_llamante()
      from jsonb_each_text(v_plan->'retencion_partida'->'por_obra') o
      cross join (values (v_cxc, -1), (v_ret, 1)) as x(cuenta, signo)
     where o.value::numeric <> 0;
    get diagnostics v_dif = row_count;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'accion', case when v_sust is not null then 'sustituida' else 'posteada' end,
    'asiento', v_res->>'numero', 'id', v_res->>'id', 'documento', v_doc, 'lineas', jsonb_array_length(v_plan->'lineas'),
    'reverso', v_rev->>'numero', 'cambios', v_cambios,
    'resultado_qb', v_plan->'resultado_qb', 'retencion_partida', v_plan->'retencion_partida',
    'ignoradas_en_cero', v_plan->'ignoradas_en_cero', 'puentes', v_puentes, 'diferencias_anotadas', v_dif));
end $$;
revoke execute on function public.fn_apertura(date, text, text) from public, anon, authenticated, service_role;


-- =====================================================================
-- 7.7 · LAS HUELLAS DE c4 (las protege «protecciones de c4», en 8). Como
-- las de c2 (fn_libro_huellas): al final de cada pegado se sellan, como
-- valores literales, el md5 de la definición de cada función de este
-- archivo (fn_estados_…, fn_apertura…, fn_comparacion_…, fn_diferencia_…;
-- también fn_apertura, que postea en el libro, y fn_estados_control, el
-- control que lee la app), de cada trigger y cada regla sobre sus tablas y
-- de cada una de sus vistas. El control recalcula y compara: una guarda
-- vaciada con create or replace (mismo nombre, mismo oid), un trigger
-- rehecho para otros eventos o uno ajeno de más, una regla o una vista
-- cambiada salen en rojo, con su nombre. Solo frena accidentes y cambios
-- torpes: quien es dueño de la base puede rehacerlas (basta con volver a
-- pegar este archivo, que además quita triggers y reglas ajenos, 1.7).
-- =====================================================================
create or replace function public.fn_estados_huellas_calcular()
returns table (tipo text, objeto text, md5 text)
language sql
stable
set search_path = public, pg_temp
as $$
  select 'funcion'::text, p.oid::regprocedure::text, md5(pg_get_functiondef(p.oid))
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'
     and (p.proname like 'fn\_estados\_%' or p.proname like 'fn\_apertura%' or p.proname like 'fn\_comparacion\_%'
          or p.proname like 'fn\_diferencia\_%')
     and p.proname <> 'fn_estados_huellas'
  union all
  select 'trigger'::text, c.relname || '.' || t.tgname, md5(pg_get_triggerdef(t.oid))
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
   where c.relnamespace = 'public'::regnamespace and not t.tgisinternal
     and c.relname in ('estados_historial', 'estados_lineas', 'estados_mapeo', 'estados_config', 'apertura_mapeo_qb',
                       'apertura_balanza_qb', 'comparacion_qb', 'diferencias')
  union all
  select 'regla'::text, c.relname || '.' || r.rulename, md5(pg_get_ruledef(r.oid))
    from pg_rewrite r
    join pg_class c on c.oid = r.ev_class
   where c.relnamespace = 'public'::regnamespace and r.rulename <> '_RETURN'
     and c.relname in ('estados_historial', 'estados_lineas', 'estados_mapeo', 'estados_config', 'apertura_mapeo_qb',
                       'apertura_balanza_qb', 'comparacion_qb', 'diferencias')
  union all
  select 'vista'::text, c.relname, md5(pg_get_viewdef(c.oid) || coalesce(array_to_string(c.reloptions, ','), ''))
    from pg_class c
   where c.relnamespace = 'public'::regnamespace and c.relkind = 'v'
     and c.relname in ('v_estados_mapeo_propuesto', 'v_estados_mapeo', 'v_cortes', 'v_ejercicios', 'v_libro', 'v_mayor',
                       'v_asiento_papel', 'v_qb_balanzas', 'v_balanza_base', 'v_balanza', 'v_balanza_obra',
                       'v_balance_general', 'v_resultados', 'v_flujo_lineas', 'v_flujo_caja', 'v_efectivo_movimientos',
                       'v_flujo_real_por_mes', 'v_saldos_dinero', 'v_cxc_antiguedad', 'v_cxp_antiguedad', 'v_gasto_lineas',
                       'v_gasto_por_categoria', 'v_gasto_por_proveedor', 'v_costo_por_obra', 'v_obras_dinero',
                       'v_comparacion', 'v_comparacion_obra', 'v_comparacion_resumen')
$$;
revoke execute on function public.fn_estados_huellas_calcular() from public, anon, authenticated, service_role;

-- El sello: reescribe fn_estados_huellas() con las huellas de este momento
-- (valores literales) y dice en su comentario cuándo. Lo llama el final de
-- este archivo. Sin grant a nadie de la API.
create or replace function public.fn_estados_huellas_sellar()
returns int
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_filas text;
  v_n     int;
begin
  perform fn_estados_exigir_dueno();
  select string_agg(format('(%L, %L, %L)', h.tipo, h.objeto, h.md5), E',\n    ' order by h.tipo, h.objeto), count(*)
    into v_filas, v_n
    from public.fn_estados_huellas_calcular() h;
  execute format($f$
    create or replace function public.fn_estados_huellas()
    returns table (tipo text, objeto text, md5 text)
    language sql
    immutable
    set search_path = public, pg_temp
    as $b$
      select * from (values
    %s
      ) as v(tipo, objeto, md5)
    $b$
  $f$, v_filas);
  execute 'revoke execute on function public.fn_estados_huellas() from public, anon, authenticated, service_role';
  execute format('comment on function public.fn_estados_huellas() is %L',
                 'c4: las huellas (md5) de las funciones, triggers, reglas y vistas de c4-estados.sql, selladas por su último '
                 'pegado, el ' || to_char(now() at time zone 'America/New_York', 'YYYY-MM-DD HH24:MI') || ' (Miami).');
  return v_n;
end $$;
revoke execute on function public.fn_estados_huellas_sellar() from public, anon, authenticated, service_role;

-- =====================================================================
-- 8 · fn_estados_control(periodo [, vistas]) — lo que conta.js lee ANTES
-- de pintar una pantalla de cifras (la falla ruidosa de f05): una fila por
-- vista, con cuántas filas devolvió para ese período (filas) y cuántas
-- dice el libro que debía devolver (esperadas), calculadas aparte, desde
-- las tablas (el libro, el mapeo y las balanzas de QuickBooks cargadas),
-- sin pasar por la vista. ok = false si la vista falló (no existe, se
-- rompió, le quitaron un permiso: el detalle trae el error) o si devolvió
-- otra cantidad (0 donde hay asientos): la pantalla no dibuja ceros, dice
-- cuál vista falló. Y una fila por cada cuadre que los estados tienen que
-- cumplir (vista = 'cuadre: …'): la balanza en cero, activo = pasivo +
-- capital, el flujo (directo = indirecto = cambio del efectivo, y sección
-- por sección), la antigüedad de cobrar y pagar = su mayor, el auxiliar
-- por obra = el mayor, el dinero por obra, el resultado del estado de
-- resultados = el del balance, el mapeo completo (una cuenta sin fila es
-- un error dicho) y, si el período tiene balanza de QuickBooks, nada sin
-- explicar (por cuenta y por obra). Un cuadre cuya fila de total no llegó
-- (la vista dio 0 filas donde el libro esperaba) sale en false. Y SIEMPRE
-- una fila más: 'cuadre: protecciones de c4' (sus triggers encendidos y
-- con su función, la RLS y la policy de cada tabla, los permisos de sus
-- tablas, vistas y funciones, y la huella de la balanza de la apertura):
-- si alguien apaga una guarda, abre una tabla o toca el papel de la
-- apertura, lo dice aquí, en rojo.
--   p_periodo: un período ('2026-10', '2026-09-APERTURA', '2026') o 'hoy'
--   (el corte del Panel: del primero del mes a hoy, en Miami). Con 'hoy'
--   se controlan las vistas que van por corte (v_estados_mapeo, v_cortes,
--   v_balance_general, v_saldos_dinero, v_cxc_antiguedad, v_cxp_antiguedad
--   y v_obras_dinero); una por período pedida con 'hoy' sale en false.
--   p_vistas: las que usa la pantalla (nulo = todas). Un nombre que el
--   control no conoce (un error de dedo, una vista de paso), un nulo o una
--   lista vacía salen en una fila en false: no se pinta. Pedir
--   v_gasto_por_proveedor controla también v_gasto_lineas (cuenta sus
--   proveedores sobre ella). conta.js:
--   _rpc('fn_estados_control', { p_periodo: '2026-10', p_vistas: ['v_balanza', 'v_resultados'] })
-- Corre con los permisos de quien llama (no es SECURITY DEFINER): el
-- equipo no la ejecuta (42501).
-- Va con jit = off (solo mientras corre): sus consultas son grandes y el
-- compilador JIT de Postgres (encendido por omisión) tarda más en
-- compilarlas que en correrlas; con 10.000 asientos, el control del Panel
-- pasa de 4.4 s a 2.5 s (medido en el banco, PG16, pruebas/conta/
-- c4-volumen.sh).
-- =====================================================================
create or replace function public.fn_estados_control(p_periodo text, p_vistas text[] default null)
returns table (orden int, vista text, filas bigint, esperadas bigint, ok boolean, detalle text)
language plpgsql
set search_path = public, pg_temp
set jit = off
as $$
declare
  -- Las vistas que el control conoce (las de pantalla y a las que se
  -- baja), y las que van por corte (valen con 'hoy').
  v_conoce  text[] := array['v_estados_mapeo', 'v_cortes', 'v_libro', 'v_mayor', 'v_asiento_papel', 'v_balanza',
                            'v_balanza_obra', 'v_balance_general', 'v_resultados', 'v_flujo_lineas', 'v_flujo_caja',
                            'v_efectivo_movimientos', 'v_flujo_real_por_mes', 'v_saldos_dinero', 'v_cxc_antiguedad',
                            'v_cxp_antiguedad', 'v_gasto_lineas', 'v_gasto_por_categoria', 'v_gasto_por_proveedor',
                            'v_costo_por_obra', 'v_obras_dinero', 'v_qb_balanzas', 'v_comparacion', 'v_comparacion_resumen',
                            'v_comparacion_obra'];
  v_corte   text[] := array['v_estados_mapeo', 'v_cortes', 'v_balance_general', 'v_saldos_dinero', 'v_cxc_antiguedad',
                            'v_cxp_antiguedad', 'v_obras_dinero'];
  v_hoy     boolean := p_periodo = 'hoy';
  v_pp      periodos;
  v_pid     text;          -- el período ('hoy' con 'hoy')
  v_tipo    text;
  v_desde   date;
  v_hasta   date;
  v_anio    int;
  v_pedidas text[];
  v_x       text;
  v_esp     jsonb;
  v_err_e   text;
  v_en      text;
  r         record;
  v_err     text;
  v_n       bigint;
  v_cuadra  boolean;
  v_valor   numeric;
  v_det     text;
  v_cuad    jsonb := '[]'::jsonb;
  v_res     numeric;
  v_bal     numeric;
  v_ef_fl   numeric;       -- el efectivo al final del flujo (v_flujo_caja)
  v_ef_re   numeric;       -- el del Panel (v_flujo_real_por_mes)
  v_ef_pd   boolean := false;
  v_apn     text;
  v_hsel    text;
  v_hcal    text;
  v_prot    text[] := '{}';
  v_hue     text[] := '{}';
  v_tablas  text[] := array['estados_historial', 'estados_lineas', 'estados_mapeo', 'estados_config', 'apertura_mapeo_qb',
                            'apertura_balanza_qb', 'comparacion_qb', 'diferencias'];
  v_vistas  text[] := array['v_estados_mapeo_propuesto', 'v_estados_mapeo', 'v_cortes', 'v_ejercicios', 'v_libro', 'v_mayor',
                            'v_asiento_papel', 'v_balanza_base', 'v_balanza', 'v_balanza_obra', 'v_balance_general',
                            'v_resultados', 'v_flujo_lineas', 'v_flujo_caja', 'v_efectivo_movimientos',
                            'v_flujo_real_por_mes', 'v_saldos_dinero', 'v_cxc_antiguedad', 'v_cxp_antiguedad',
                            'v_gasto_lineas', 'v_gasto_por_categoria', 'v_gasto_por_proveedor', 'v_costo_por_obra',
                            'v_obras_dinero', 'v_qb_balanzas', 'v_comparacion', 'v_comparacion_obra', 'v_comparacion_resumen'];
begin
  -- (Solo es_dueno(): fn_desde_editor no es de la API, y Postgres pide
  -- permiso sobre cada función de la expresión aunque no la llegue a
  -- evaluar. Desde el SQL Editor el usuario no es authenticated.)
  if current_user in ('authenticated', 'anon') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501', message = 'Los estados los ve solo Edgar (el dueño).';
  end if;
  if v_hoy then
    -- El corte del Panel, como v_cortes: del primero del mes a hoy.
    v_hasta := fn_fecha_miami(now());
    v_pid := 'hoy'; v_tipo := 'hoy'; v_desde := date_trunc('month', v_hasta::timestamp)::date;
    v_anio := extract(year from v_hasta)::int;
  else
    select * into v_pp from periodos pp where pp.periodo = p_periodo;
    if not found then
      raise exception using errcode = '22023',
        message = format('No existe el período %s (un mes como ''2026-10'', la apertura, un año, o ''hoy'').',
                         coalesce(p_periodo, '(nulo)'));
    end if;
    v_pid := v_pp.periodo; v_tipo := v_pp.tipo; v_desde := v_pp.desde; v_hasta := v_pp.hasta; v_anio := v_pp.anio;
  end if;

  -- 0. Lo que se pide. Lo que el control no conoce, una lista vacía, un
  -- nulo, o una vista por período con 'hoy': una fila en false cada una
  -- (no se pinta: nunca un silencio que la pantalla lea como «todo bien»).
  if p_vistas is not null and cardinality(p_vistas) = 0 then
    orden := 0; vista := '(ninguna)'; filas := null; esperadas := null; ok := false;
    detalle := 'p_vistas llegó vacía: no se controla nada, y así no se pinta. Pide las vistas de la pantalla, o nulo para todas.';
    return next;
  end if;
  for v_x in select distinct x.v from unnest(coalesce(p_vistas, '{}'::text[])) as x(v)
              where x.v is null or not (x.v = any (v_conoce)) loop
    orden := 0; vista := coalesce(v_x, '(nula)'); filas := null; esperadas := null; ok := false;
    detalle := format('La vista «%s» no la conoce el control (¿un error de dedo, o una vista de paso?): no se pinta. Las que '
                      'conoce: %s.', coalesce(v_x, 'nula'), array_to_string(v_conoce, ', '));
    return next;
  end loop;
  v_pedidas := case when p_vistas is null then case when v_hoy then v_corte else v_conoce end
                    else array(select distinct x.v from unnest(p_vistas) as x(v) where x.v = any (v_conoce)) end;
  if 'v_gasto_por_proveedor' = any (v_pedidas) and not 'v_gasto_lineas' = any (v_pedidas) then
    v_pedidas := v_pedidas || 'v_gasto_lineas'::text;
  end if;
  if v_hoy then
    for v_x in select x.v from unnest(v_pedidas) as x(v) where not (x.v = any (v_corte)) order by 1 loop
      orden := 0; vista := v_x; filas := null; esperadas := null; ok := false;
      detalle := format('La vista %s va por período (un mes o el año), no por corte: con ''hoy'' no se controla ni se pinta. '
                        'Pídela con el mes (fn_estados_control(%L)).', v_x, to_char(v_hasta, 'YYYY-MM'));
      return next;
    end loop;
    v_pedidas := array(select x.v from unnest(v_pedidas) as x(v) where x.v = any (v_corte));
  end if;

  -- 1. Lo que el libro dice que cada vista tiene que devolver, en UNA
  -- pasada por sus tablas (asiento_lineas, asientos, el mapeo, las
  -- balanzas de QuickBooks), sin pasar por las vistas. Solo lo de las
  -- vistas pedidas: cada cuenta va en un case, y Postgres no corre la
  -- subconsulta (ni los CTE que solo ella lee) de la rama que no toma.
  begin
    with p as (select v_pid as periodo, v_tipo as tipo, v_desde as desde, v_hasta as hasta, v_anio as anio,
                      make_date(v_anio, 1, 1) as ene,
                      case when v_tipo = 'anio' then make_date(v_anio - 1, 1, 1)
                           else (v_desde - interval '1 month')::date end as ad,
                      v_desde - 1 as ah,
                      case when v_tipo = 'anio' then v_anio - 1
                           else extract(year from (v_desde - interval '1 month'))::int end as aa,
                      v_tipo in ('mes', 'apertura', 'anio') as con_post),
    m as materialized (select * from v_estados_mapeo),
    k as materialized (select (select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc') as cxc,
                              (select pc.cuenta from puente_cuentas pc where pc.rol = 'retencion_cxc') as ret,
                              (select pc.cuenta from puente_cuentas pc where pc.rol = 'cxp') as cxp),
    ej as materialized (select e.anio, e.estado = 'cerrado' as cerrado from periodos e where e.tipo = 'anio'),
    apx as materialized (select pa.periodo, pa.anio, pa.hasta from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1),
    lb as materialized (select coalesce((select apx.hasta + 1 from apx), (select min(pm.desde) from periodos pm where pm.tipo = 'mes'))
                                 as libro_desde),
    l as materialized (
      select al.cuenta, al.monto, al.orden, al.proyecto_id, al.cost_code, al.partida_tabla, al.partida_id, al.tercero_tipo,
             al.tercero_id, a.id as asiento_id, a.fecha_contable as fecha, a.periodo, a.tipo, a.anio, a.camino,
             a.procedencia, a.documento_ruta, a.origen_tabla,
             case when a.afecta_periodo is null then a.anio
                  else coalesce((select pa.anio from periodos pa where pa.periodo = a.afecta_periodo), a.anio) end as ejercicio,
             case when a.tipo = 'ajuste_cpa' then a.afecta_periodo else a.periodo end as periodo_efectivo,
             (select pe.hasta from periodos pe
               where pe.periodo = case when a.tipo = 'ajuste_cpa' then a.afecta_periodo else a.periodo end) as efectivo_hasta,
             a.afecta_periodo, m.estado, m.seccion, m.linea, m.efectivo, m.flujo_directo, m.flujo_indirecto,
             m.flujo_directo_seccion, m.flujo_indirecto_seccion, m.contra, c.regla_obra
        from asiento_lineas al
        join asientos a on a.id = al.asiento_id
        join m on m.cuenta = al.cuenta
        join cuentas c on c.codigo = al.cuenta
    ),
    lp as materialized (select l.* from l, p
                         where (p.tipo = 'anio' and l.anio = p.anio) or (p.tipo not in ('anio', 'hoy') and l.periodo = p.periodo)),
    b as materialized (select l.* from l, p where l.fecha <= p.hasta),
    -- Lo del corte más los ajustes del CPA posteriores que lo corrigen
    -- (las columnas «ajustadas» del balance).
    bx as materialized (select l.*, l.fecha <= p.hasta as al_corte from l, p
                         where l.fecha <= p.hasta
                            or (p.con_post and l.tipo = 'ajuste_cpa'
                                and case when p.tipo = 'anio' then l.ejercicio <= p.anio else l.efectivo_hasta <= p.hasta end)),
    -- el balance general: cuentas, componentes (resultados por ejercicio,
    -- plegado, resultado de la apertura, reclasificaciones), renglones,
    -- secciones y totales
    bgc as (select distinct bx.seccion, bx.linea, bx.cuenta::text as clave from bx where bx.estado = 'balance'
            union
            select distinct 'capital', case when bx.ejercicio = p.anio then 'resultado_ejercicio'
                                            when coalesce(ej.cerrado, false) then 'utilidades_retenidas'
                                            else 'ejercicios_por_cerrar' end,
                            case when bx.ejercicio = p.anio then 'c:resultado' when coalesce(ej.cerrado, false) then 'c:arrastre'
                                 else 'c:por_cerrar' end
              from bx left join ej on ej.anio = bx.ejercicio, p
             where bx.estado = 'resultados'
            union
            select 'capital', z.linea, 'c:plegado_3200'
              from (values ('utilidades_retenidas'), ('distribuciones')) z(linea)
             where coalesce((select c.valor from estados_config c where c.clave = 'plegar_3200'), 'no') = 'si'
               and exists (select 1 from bx join ej on ej.anio = bx.ejercicio and ej.cerrado
                            where bx.al_corte and bx.estado = 'balance' and bx.linea = 'distribuciones')
            union
            -- el resultado de antes de la apertura (la balanza de la apertura
            -- viva): en su año, al resultado del ejercicio; después, mientras
            -- ese año no se cierre, a «ejercicios anteriores por cerrar»
            select 'capital', z.linea, 'c:resultado_apertura'
              from p, apx
              cross join lateral (values ('utilidades_retenidas'),
                                         (case when apx.anio = p.anio then 'resultado_ejercicio'
                                               else 'ejercicios_por_cerrar' end)) z(linea)
             where p.hasta >= apx.hasta
               and (apx.anio = p.anio
                    or (apx.anio < p.anio and not coalesce((select e2.cerrado from ej e2 where e2.anio = apx.anio), false)))
               and exists (select 1 from asientos a
                             join apertura_balanza_qb qb on qb.documento = a.documento_ruta
                             join apertura_mapeo_qb mq on mq.tipo = 'cuenta' and mq.clave = qb.clave
                             join cuentas cq on cq.codigo = mq.cuenta
                            where a.tipo = 'apertura' and a.origen_tabla = 'apertura_balanza_qb' and a.periodo = apx.periodo
                              and coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'
                              and a.camino not in ('reverso', 'reverso_automatico')
                              and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')
                              and cq.tipo not in ('activo', 'pasivo', 'capital')
                            group by a.id
                           having sum(coalesce(qb.debe, 0) - coalesce(qb.haber, 0)) <> 0)
            union
            -- las reclasificaciones: salen de cada renglón que tiene un saldo
            -- contrario y entran en el suyo
            select distinct y.seccion, y.linea, 'r:' || y.comp
              from (select 'reclasif_anticipos' as comp, bx.seccion, bx.linea
                      from bx, k where bx.al_corte and bx.cuenta in (k.cxc, k.ret)
                     group by bx.seccion, bx.linea, bx.cuenta, bx.partida_tabla, bx.partida_id,
                              case when bx.partida_tabla is null then bx.proyecto_id end
                    having sum(bx.monto) < 0
                    union all
                    select 'reclasif_a_favor', bx.seccion, bx.linea
                      from bx, k where bx.al_corte and bx.estado = 'balance'
                                   and (bx.cuenta = k.cxp or bx.linea in ('retencion_por_pagar', 'tarjetas'))
                     group by bx.seccion, bx.linea, bx.cuenta,
                              case when bx.linea <> 'tarjetas' then bx.tercero_tipo end,
                              case when bx.linea <> 'tarjetas' then bx.tercero_id end
                    having sum(bx.monto) > 0
                    union all
                    select 'reclasif_sobregiro', bx.seccion, bx.linea
                      from bx where bx.al_corte and bx.efectivo
                     group by bx.seccion, bx.linea, bx.cuenta
                    having sum(bx.monto) < 0
                    union all
                    select 'reclasif_pasivo_deudor', bx.seccion, bx.linea
                      from bx, k where bx.al_corte and bx.estado = 'balance' and bx.seccion in ('pasivo_circulante', 'pasivo_largo_plazo')
                                   and not bx.contra and not (bx.cuenta = k.cxp or bx.linea in ('retencion_por_pagar', 'tarjetas'))
                     group by bx.seccion, bx.linea, bx.cuenta
                    having sum(bx.monto) > 0
                    union all
                    select 'reclasif_activo_acreedor', bx.seccion, bx.linea
                      from bx, k where bx.al_corte and bx.estado = 'balance'
                                   and bx.seccion in ('activo_circulante', 'activo_fijo', 'otros_activos')
                                   and not bx.contra and not bx.efectivo and bx.cuenta not in (k.cxc, k.ret)
                     group by bx.seccion, bx.linea, bx.cuenta
                    having sum(bx.monto) < 0) y
            union
            -- (y dónde entran: el renglón de destino de cada una)
            select distinct y.s, y.l, 'd:' || y.comp
              from (select 'reclasif_pasivo_deudor' as comp,
                           case when bx.linea = 'prestamo_accionista' then 'otros_activos' else 'activo_circulante' end as s,
                           case when bx.linea = 'prestamo_accionista' then 'accionista_por_cobrar'
                                when bx.linea in ('nomina_por_pagar', 'impuestos_por_pagar') then 'impuestos_a_favor'
                                else 'otros_saldos_deudores' end as l
                      from bx, k where bx.al_corte and bx.estado = 'balance' and bx.seccion in ('pasivo_circulante', 'pasivo_largo_plazo')
                                   and not bx.contra and not (bx.cuenta = k.cxp or bx.linea in ('retencion_por_pagar', 'tarjetas'))
                     group by bx.linea, bx.cuenta
                    having sum(bx.monto) > 0
                    union all
                    select 'reclasif_activo_acreedor',
                           case when bx.linea = 'accionista_por_cobrar' then 'pasivo_largo_plazo' else 'pasivo_circulante' end,
                           case when bx.linea = 'accionista_por_cobrar' then 'prestamo_accionista' else 'otros_pasivos' end
                      from bx, k where bx.al_corte and bx.estado = 'balance'
                                   and bx.seccion in ('activo_circulante', 'activo_fijo', 'otros_activos')
                                   and not bx.contra and not bx.efectivo and bx.cuenta not in (k.cxc, k.ret)
                     group by bx.linea, bx.cuenta
                    having sum(bx.monto) < 0) y
            union
            select distinct z.s, z.l, 'd:' || y.comp
              from (select 'reclasif_anticipos' as comp from bx, k where bx.al_corte and bx.cuenta in (k.cxc, k.ret)
                     group by bx.cuenta, bx.partida_tabla, bx.partida_id, case when bx.partida_tabla is null then bx.proyecto_id end
                    having sum(bx.monto) < 0
                    union all
                    select 'reclasif_a_favor' from bx, k where bx.al_corte and bx.estado = 'balance'
                                   and (bx.cuenta = k.cxp or bx.linea in ('retencion_por_pagar', 'tarjetas'))
                     group by bx.cuenta, case when bx.linea <> 'tarjetas' then bx.tercero_tipo end,
                              case when bx.linea <> 'tarjetas' then bx.tercero_id end
                    having sum(bx.monto) > 0
                    union all
                    select 'reclasif_sobregiro' from bx where bx.al_corte and bx.efectivo
                     group by bx.cuenta having sum(bx.monto) < 0) y
              join (values ('reclasif_anticipos', 'pasivo_circulante', 'anticipos_clientes'),
                           ('reclasif_a_favor', 'activo_circulante', 'saldos_a_favor'),
                           ('reclasif_sobregiro', 'pasivo_circulante', 'sobregiro_bancario')) as z(c, s, l) on z.c = y.comp),
    -- el estado de resultados
    rc as (select distinct l.seccion, l.linea, l.cuenta
             from l, p
            where l.estado = 'resultados'
              and ((l.ejercicio = p.anio and l.fecha between p.ene and p.hasta)
                   or (l.ejercicio = p.aa and l.fecha between p.ad and p.ah)
                   or (l.ejercicio = p.anio and l.fecha > p.hasta and l.tipo = 'ajuste_cpa'
                       and (p.tipo = 'anio' or l.efectivo_hasta <= p.hasta)))),
    -- el flujo: sus renglones fijos (una sección sin renglones propios es
    -- su propio renglón), si el período tiene algo
    fr as (select el.estado, el.seccion
             from estados_lineas el
            where el.estado in ('flujo_directo', 'flujo_indirecto') and el.seccion <> 'totales'
              and (el.linea <> el.seccion
                   or not exists (select 1 from estados_lineas o
                                   where o.estado = el.estado and o.seccion = el.seccion and o.linea <> o.seccion))),
    fh as (select exists (select 1 from l, p where l.fecha between p.desde and p.hasta and not l.efectivo)
                  or exists (select 1 from l, p where l.fecha between p.desde and p.hasta and l.efectivo)
                  or exists (select 1 from l, p where l.efectivo and l.fecha < p.desde
                              group by l.cuenta having sum(l.monto) <> 0) as hay),
    -- el dinero que se movió, asiento por asiento
    em as (select 1 from lp where lp.efectivo group by lp.asiento_id having sum(lp.monto) <> 0),
    -- cobrar y pagar
    cx as (select 1 from b, k where b.cuenta in (k.cxc, k.ret)
            group by b.partida_tabla, b.partida_id, case when b.partida_tabla is null then b.proyecto_id end
           having coalesce(sum(b.monto) filter (where b.cuenta = k.cxc), 0) <> 0
               or coalesce(sum(b.monto) filter (where b.cuenta = k.ret), 0) <> 0),
    px as (select 1 from b, k where b.cuenta = k.cxp or (b.estado = 'balance' and b.linea = 'retencion_por_pagar')
            group by b.partida_tabla, b.partida_id, case when b.partida_tabla is null then b.tercero_id end
           having coalesce(sum(b.monto) filter (where b.cuenta = k.cxp), 0) <> 0
               or coalesce(sum(b.monto) filter (where b.cuenta <> k.cxp), 0) <> 0),
    -- el gasto
    gc as (select distinct l.cuenta from l, p
            where l.estado = 'resultados' and l.seccion in ('costo', 'gastos', 'otros_gastos')
              and l.ejercicio = p.anio and l.fecha between p.ene and p.hasta),
    -- por obra
    co as (select b.proyecto_id, b.cuenta from b
            where b.estado = 'resultados'
              and (b.regla_obra <> 'prohibida' or b.proyecto_id is not null or b.seccion in ('ingresos', 'costo'))
            group by b.proyecto_id, b.cuenta),
    -- (las cuentas del control, que salen del mayor: las de ingresos y costo
    -- con algo en el año, y las del auxiliar)
    coc as (select distinct x.cuenta
              from (select co.cuenta from co
                    union
                    select b.cuenta from b, p where b.estado = 'resultados' and b.seccion in ('ingresos', 'costo')
                                                and b.ejercicio = p.anio) x),
    -- QuickBooks, desde las tablas: la balanza que vale en el período (la
    -- de comparacion_qb cargada más tarde; si no hay, en la apertura, la
    -- que posteó la apertura viva), con su cuenta y su obra.
    qd as (select q.documento, q.al from comparacion_qb q where q.periodo = v_pid order by q.cargado_el desc, q.documento desc limit 1),
    -- la balanza de la apertura: la del último asiento de fn_apertura,
    -- vivo o reversado (si se reversó, la comparación dice que el libro ya
    -- no la tiene); si nunca posteó, la cargada más tarde
    qa0 as materialized (
      select coalesce((select a.documento_ruta from asientos a
                        where a.tipo = 'apertura' and a.origen_tabla = 'apertura_balanza_qb'
                          and coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'
                          and a.camino not in ('reverso', 'reverso_automatico')
                        order by a.cadena_pos desc limit 1),
                      (select b.documento from apertura_balanza_qb b order by b.cargado_el desc, b.documento desc limit 1))
               as documento_ruta,
             (select pa.periodo from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1) as periodo),
    qa as (select qa0.documento_ruta, qa0.periodo from qa0 where qa0.periodo = v_pid and qa0.documento_ruta is not null),
    qal as (select coalesce((select qd.al from qd), v_hasta) as al),
    qt as materialized (
      select x.cuenta_qb, x.clave, x.saldo, x.con_posteriores, mc.cuenta, c.tipo as cuenta_tipo,
             coalesce(x.proyecto_id, mt.proyecto_id, f.proyecto_id) as proyecto_id
        from (select q.cuenta_qb, q.clave, q.saldo, q.con_posteriores, q.cliente_clave, q.proyecto_id, null::bigint as factura_id
                from comparacion_qb q join qd on qd.documento = q.documento
               where q.periodo = v_pid
              union all
              select qb.cuenta_qb, qb.clave, coalesce(qb.debe, 0) - coalesce(qb.haber, 0), false, qb.cliente_clave, qb.proyecto_id,
                     qb.factura_id
                from apertura_balanza_qb qb join qa on qa.documento_ruta = qb.documento
               where not exists (select 1 from qd) and qb.control is null) x
        left join apertura_mapeo_qb mc on mc.tipo = 'cuenta' and mc.clave = x.clave
        left join apertura_mapeo_qb mt on mt.tipo = 'trabajo' and mt.clave = x.cliente_clave
        left join facturas f on f.id = x.factura_id
        left join cuentas c on c.codigo = mc.cuenta
    ),
    qp as (select coalesce(bool_or(qt.con_posteriores), false) as con from qt),
    -- lo que la balanza de apertura traía en cada cuenta de resultados
    -- (enero a septiembre), para los períodos de su año posteriores a ella
    qj as (select mq.cuenta, qb.proyecto_id as p1, mt.proyecto_id as p2, f.proyecto_id as p3,
                  coalesce(qb.debe, 0) - coalesce(qb.haber, 0) as saldo
             from apx, p, qa0
             join apertura_balanza_qb qb on qb.documento = qa0.documento_ruta and qb.control is null
             join apertura_mapeo_qb mq on mq.tipo = 'cuenta' and mq.clave = qb.clave
             join cuentas cq on cq.codigo = mq.cuenta
             left join apertura_mapeo_qb mt on mt.tipo = 'trabajo' and mt.clave = qb.cliente_clave
             left join facturas f on f.id = qb.factura_id
            where qa0.periodo = apx.periodo
              and cq.tipo not in ('activo', 'pasivo', 'capital')
              and p.anio = apx.anio and p.hasta > apx.hasta and p.periodo <> apx.periodo),
    -- v_comparacion: una fila por cuenta con algo (libro, QuickBooks,
    -- arrastre, posteriores o anotaciones), y una por nombre sin mapeo
    vc_q as (select case when p.tipo = 'apertura' and qt.cuenta_tipo not in ('activo', 'pasivo', 'capital') then '3900'
                         else qt.cuenta end as cuenta, sum(qt.saldo) as qb
               from qt, p where qt.cuenta is not null group by 1),
    vc_l as (select l.cuenta, coalesce(sum(l.monto) filter (where l.fecha <= qal.al), 0) as libro,
                    coalesce(sum(l.monto) filter (where l.fecha > p.hasta), 0) as post
               from l, p, qp, qal
              where (l.estado = 'balance' or l.ejercicio = p.anio)
                and (l.fecha <= qal.al
                     or (qp.con and l.tipo = 'ajuste_cpa' and l.fecha > p.hasta
                         and case when p.tipo = 'anio' then l.ejercicio <= p.anio else l.efectivo_hasta <= p.hasta end))
                and exists (select 1 from qt)
              group by l.cuenta),
    vc_j as (select qj.cuenta, sum(qj.saldo) as saldo from qj group by qj.cuenta),
    vc_d as (select d.cuenta, count(*) as n from diferencias d where d.periodo = v_pid and d.retirada_el is null group by d.cuenta),
    vc as (select x.cuenta
             from (select vc_q.cuenta from vc_q union select vc_l.cuenta from vc_l
                   union select vc_j.cuenta from vc_j union select vc_d.cuenta from vc_d) x
             left join vc_q on vc_q.cuenta = x.cuenta
             left join vc_l on vc_l.cuenta = x.cuenta
             left join vc_j on vc_j.cuenta = x.cuenta
             left join vc_d on vc_d.cuenta = x.cuenta
            where coalesce(vc_l.libro, 0) <> 0 or coalesce(vc_q.qb, 0) <> 0 or coalesce(vc_l.post, 0) <> 0
               or coalesce(vc_d.n, 0) > 0
               or coalesce(vc_j.saldo, 0) - case when x.cuenta = '3900' then coalesce((select sum(j2.saldo) from vc_j j2), 0)
                                                 else 0 end <> 0),
    vs as (select 1 from qt where qt.cuenta is null group by qt.cuenta_qb, qt.clave having sum(qt.saldo) <> 0),
    -- v_comparacion_obra: por obra, solo en las cuentas que QuickBooks trae
    -- por obra en el período
    vo_q as (select qt.cuenta, qt.proyecto_id, sum(qt.saldo) as qb from qt, p
              where qt.cuenta is not null and qt.proyecto_id is not null
                and (p.tipo <> 'apertura' or qt.cuenta_tipo in ('activo', 'pasivo', 'capital'))
              group by qt.cuenta, qt.proyecto_id),
    vo_l as (select l.cuenta, l.proyecto_id, coalesce(sum(l.monto) filter (where l.fecha <= qal.al), 0) as libro,
                    coalesce(sum(l.monto) filter (where l.fecha > p.hasta), 0) as post
               from l, p, qp, qal
              where (l.estado = 'balance' or l.ejercicio = p.anio)
                and (l.fecha <= qal.al
                     or (qp.con and l.tipo = 'ajuste_cpa' and l.fecha > p.hasta
                         and case when p.tipo = 'anio' then l.ejercicio <= p.anio else l.efectivo_hasta <= p.hasta end))
                and l.cuenta in (select vo_q.cuenta from vo_q) and l.proyecto_id is not null
              group by l.cuenta, l.proyecto_id),
    vo_j as (select qj.cuenta, coalesce(qj.p1, qj.p2, qj.p3) as proyecto_id, sum(qj.saldo) as saldo from qj
              where coalesce(qj.p1, qj.p2, qj.p3) is not null and qj.cuenta in (select vo_q.cuenta from vo_q)
              group by 1, 2),
    vo_d as (select d.cuenta, d.proyecto_id, sum(d.monto) as monto from diferencias d
              where d.periodo = v_pid and d.retirada_el is null and d.proyecto_id is not null
                and d.cuenta in (select vo_q.cuenta from vo_q)
              group by d.cuenta, d.proyecto_id),
    vo as (select x.cuenta, x.proyecto_id
             from (select vo_q.cuenta, vo_q.proyecto_id from vo_q union select vo_l.cuenta, vo_l.proyecto_id from vo_l
                   union select vo_j.cuenta, vo_j.proyecto_id from vo_j union select vo_d.cuenta, vo_d.proyecto_id from vo_d) x
             left join vo_q on vo_q.cuenta = x.cuenta and vo_q.proyecto_id = x.proyecto_id
             left join vo_l on vo_l.cuenta = x.cuenta and vo_l.proyecto_id = x.proyecto_id
             left join vo_j on vo_j.cuenta = x.cuenta and vo_j.proyecto_id = x.proyecto_id
             left join vo_d on vo_d.cuenta = x.cuenta and vo_d.proyecto_id = x.proyecto_id
            where coalesce(vo_l.libro, 0) <> 0 or coalesce(vo_q.qb, 0) <> 0 or coalesce(vo_d.monto, 0) <> 0
               or coalesce(vo_j.saldo, 0) <> 0 or coalesce(vo_l.post, 0) <> 0)
    select jsonb_build_object(
      'v_estados_mapeo', case when 'v_estados_mapeo' = any (v_pedidas) then
                         (select count(*) from cuentas) end,
      'v_cortes', case when 'v_cortes' = any (v_pedidas) then
                  1 end,
      'v_libro', case when 'v_libro' = any (v_pedidas) then
                 (select count(*) from lp) end,
      'v_mayor', case when 'v_mayor' = any (v_pedidas) then
                 (select count(*) from lp) end,
      'v_asiento_papel', case when 'v_asiento_papel' = any (v_pedidas) then
                         (select count(distinct lp.asiento_id) from lp) end,
      'v_balanza', case when 'v_balanza' = any (v_pedidas) then
                   (select count(distinct b.cuenta) from b, p where b.estado = 'balance' or b.ejercicio = p.anio)
                     + (select count(distinct coalesce(ej.cerrado, false)) from b left join ej on ej.anio = b.ejercicio, p
                         where b.estado = 'resultados' and b.ejercicio <> p.anio)
                     + (select case when exists (select 1 from b) then 1 else 0 end) end,
      'v_balanza_obra', case when 'v_balanza_obra' = any (v_pedidas) then
                        (select count(*) from (select distinct b.cuenta, b.proyecto_id, b.cost_code from b, p
                                                  where b.estado = 'balance' or b.ejercicio = p.anio) x)
                          + (select count(distinct coalesce(ej.cerrado, false)) from b left join ej on ej.anio = b.ejercicio, p
                              where b.estado = 'resultados' and b.ejercicio <> p.anio)
                          + (select case when exists (select 1 from b) then 1 else 0 end) end,
      -- (cuentas y componentes + sus renglones + sus secciones + 5 totales)
      'v_balance_general', case when 'v_balance_general' = any (v_pedidas) then
                           (select count(*) from bgc) + (select count(distinct (bgc.seccion, bgc.linea)) from bgc)
                             + (select count(distinct bgc.seccion) from bgc)
                             + (select case when exists (select 1 from bgc) then 5 else 0 end) end,
      'v_resultados', case when 'v_resultados' = any (v_pedidas) then
                      (select count(*) from rc) + (select count(distinct (rc.seccion, rc.linea)) from rc where rc.linea <> rc.seccion)
                        + (select count(distinct rc.seccion) from rc) + (select case when exists (select 1 from rc) then 3 else 0 end) end,
      -- (las piezas base: una por línea que no es dinero)
      'v_flujo_lineas', case when 'v_flujo_lineas' = any (v_pedidas) then
                        (select count(*) from lp where not lp.efectivo) end,
      -- (por método: sus renglones, sus secciones, 3 totales y un control
      -- por sección que suma más el general)
      'v_flujo_caja', case when 'v_flujo_caja' = any (v_pedidas) then
                      (select case when fh.hay
                                   then (select count(*) from fr) + (select count(distinct (fr.estado, fr.seccion)) from fr)
                                        + 2 * 3
                                        + (select count(distinct (fr.estado, fr.seccion)) from fr where fr.seccion <> 'sin_dinero')
                                        + 2
                                   else 0 end from fh) end,
      'v_efectivo_movimientos', case when 'v_efectivo_movimientos' = any (v_pedidas) then
                                (select count(*) from em) end,
      'v_flujo_real_por_mes', case when 'v_flujo_real_por_mes' = any (v_pedidas) then
                              (select case when p.tipo = 'mes'
                                              and p.desde <= greatest(fn_fecha_miami(now()),
                                                                      (select max(a.fecha_contable) from asientos a))
                                              and (exists (select 1 from l where l.efectivo and l.fecha between p.desde and p.hasta)
                                                   or exists (select 1 from l where l.efectivo and l.fecha < p.desde
                                                               group by l.cuenta having sum(l.monto) <> 0))
                                             then 1 else 0 end from p) end,
      'v_saldos_dinero', case when 'v_saldos_dinero' = any (v_pedidas) then
                         (select count(*) from m join cuentas c on c.codigo = m.cuenta
                             where c.imputable and (m.efectivo or (m.estado = 'balance' and m.linea in ('tarjetas', 'linea_credito')))
                               and (c.activa or exists (select 1 from b where b.cuenta = m.cuenta))) end,
      'v_cxc_antiguedad', case when 'v_cxc_antiguedad' = any (v_pedidas) then
                          (select count(*) from cx) + (select case when exists (select 1 from b, k where b.cuenta in (k.cxc, k.ret))
                                                                     then 1 else 0 end) end,
      'v_cxp_antiguedad', case when 'v_cxp_antiguedad' = any (v_pedidas) then
                          (select count(*) from px)
                            + (select case when exists (select 1 from b, k
                                                         where b.cuenta = k.cxp or (b.estado = 'balance' and b.linea = 'retencion_por_pagar'))
                                           then 1 else 0 end) end,
      'v_gasto_lineas', case when 'v_gasto_lineas' = any (v_pedidas) then
                        (select count(*) from lp where lp.estado = 'resultados' and lp.seccion in ('costo', 'gastos', 'otros_gastos')) end,
      'v_gasto_por_categoria', case when 'v_gasto_por_categoria' = any (v_pedidas) then
                               (select count(*) from gc) + (select case when exists (select 1 from gc) then 1 else 0 end) end,
      -- (El proveedor de cada línea lo resuelve v_gasto_lineas, que se
      -- controla con ella: aquí se cuentan sus proveedores.)
      'v_gasto_por_proveedor', case when 'v_gasto_por_proveedor' = any (v_pedidas) then
                               (select count(distinct gl.proveedor_clave)
                                         + case when count(*) > 0 then 1 else 0 end
                                    from v_gasto_lineas gl, p
                                   where gl.ejercicio = p.anio and gl.fecha between p.ene and p.hasta) end,
      -- (obra y cuenta + 4 renglones por obra + un control por cuenta —las
      -- del auxiliar y las de ingresos y costo del mayor— + 2 por sección)
      'v_costo_por_obra', case when 'v_costo_por_obra' = any (v_pedidas) then
                          (select count(*) from co) + 4 * (select count(distinct coalesce(co.proyecto_id, '')) from co)
                            + (select count(*) from coc)
                            + (select case when exists (select 1 from co) then 2 else 0 end) end,
      -- (el efectivo del balance al corte: el renglón «efectivo», con las
      -- cuentas en rojo fuera, como las pasa v_balance_general al sobregiro)
      'efectivo_balance', case when not v_hoy and ('v_flujo_caja' = any (v_pedidas) or 'v_flujo_real_por_mes' = any (v_pedidas)) then
                          (select coalesce(sum(case when x.s < 0 and not x.contra then 0 else x.s end), 0)
                             from (select b.cuenta, bool_or(b.contra) as contra, sum(b.monto) as s
                                     from b where b.estado = 'balance' and b.linea = 'efectivo'
                                    group by b.cuenta) x) end,
      'v_obras_dinero', case when 'v_obras_dinero' = any (v_pedidas) then
                        (select count(distinct b.proyecto_id) from b where b.proyecto_id is not null) end,
      'v_qb_balanzas', case when 'v_qb_balanzas' = any (v_pedidas) then
                       (select count(*) from qt) end,
      -- (solo si el período tiene balanza de QuickBooks: sin ella, la vista
      -- no da filas)
      'v_comparacion', case when 'v_comparacion' = any (v_pedidas) then
                       (select case when exists (select 1 from qt) then (select count(*) from vc) + (select count(*) from vs)
                                    else 0 end) end,
      'v_comparacion_resumen', case when 'v_comparacion_resumen' = any (v_pedidas) then
                               (select case when exists (select 1 from qt) then 1 else 0 end) end,
      'v_comparacion_obra', case when 'v_comparacion_obra' = any (v_pedidas) then
                            (select count(*) from vo) end)
      into v_esp;
  exception when others then
    v_esp := null;
    v_err_e := format('%s: %s', sqlstate, sqlerrm);
  end;

  -- 2. Cada vista, para el período: cuántas filas, y lo que cuadra en ella.
  v_en := case when v_tipo = 'anio' then format('anio = %s', v_anio) else format('periodo = %L', v_pid) end;
  for r in
    select * from (values
      (1,  'v_estados_mapeo', 'select count(*), not coalesce(bool_or(sin_fila), false), null::numeric, '
                              || 'string_agg(cuenta, '', '' order by cuenta) filter (where sin_fila) from public.v_estados_mapeo'),
      (2,  'v_cortes', 'select count(*), null::boolean, null::numeric, null::text from public.v_cortes where periodo = $1'),
      (3,  'v_libro', 'select count(*), null::boolean, null::numeric, null::text from public.v_libro where ' || v_en),
      (4,  'v_mayor', 'select count(*), null::boolean, null::numeric, null::text from public.v_mayor where ' || v_en),
      (5,  'v_asiento_papel', 'select count(*), null::boolean, null::numeric, null::text from public.v_asiento_papel where '
                              || case when v_tipo = 'anio' then format('extract(year from fecha) = %s', v_anio)
                                      else format('periodo = %L', v_pid) end),
      (10, 'v_balanza', $q$ select count(*), bool_and(cuadra) filter (where nivel = 'total'), null::numeric,
                               string_agg(format('saldo final %s, debe %s, haber %s', saldo_final, debe, haber), '; ')
                                 filter (where nivel = 'total')
                          from public.v_balanza where periodo = $1 $q$),
      (11, 'v_balanza_obra', 'select count(*), null::boolean, null::numeric, null::text from public.v_balanza_obra where periodo = $1'),
      -- (El resultado del libro: el de v_resultados es desde que empieza el
      -- libro; el de antes de la apertura, del balance, es de QuickBooks.)
      (12, 'v_balance_general', $q$ select count(*), bool_and(cuadra) filter (where nivel = 'total' and linea = 'cuadra'),
                                       coalesce(sum(cifra) filter (where nivel = 'componente' and componente = 'resultado'), 0),
                                       string_agg(format('activo − pasivo − capital = %s (ajustado %s)', cifra, cifra_ajustada), '; ')
                                         filter (where nivel = 'total' and linea = 'cuadra')
                                  from public.v_balance_general where periodo = $1 $q$),
      (13, 'v_resultados', $q$ select count(*), null::boolean,
                                  coalesce(sum(acumulado) filter (where nivel = 'total' and linea = 'utilidad_neta'), 0), null::text
                             from public.v_resultados where periodo = $1 $q$),
      (14, 'v_flujo_lineas', 'select count(*) filter (where pieza = ''linea''), null::boolean, null::numeric, null::text '
                             || 'from public.v_flujo_lineas where ' || v_en),
      (15, 'v_flujo_caja', $q$ select count(*), bool_and(cuadra) filter (where nivel = 'control'),
                                  max(importe) filter (where metodo = 'directo' and nivel = 'total' and linea = 'efectivo_final'),
                                  string_agg(format('%s %s: diferencia %s', metodo, linea, importe), '; ')
                                    filter (where nivel = 'control' and not cuadra)
                             from public.v_flujo_caja where periodo = $1 $q$),
      (16, 'v_efectivo_movimientos', 'select count(*), null::boolean, null::numeric, null::text from public.v_efectivo_movimientos where '
                                     || v_en),
      (17, 'v_flujo_real_por_mes', 'select count(*), null::boolean, max(efectivo_final), null::text from public.v_flujo_real_por_mes where periodo = $1'),
      (20, 'v_saldos_dinero', 'select count(*), null::boolean, null::numeric, null::text from public.v_saldos_dinero where periodo = $1'),
      (21, 'v_cxc_antiguedad', $q$ select count(*), bool_and(cuadra) filter (where nivel = 'total'), null::numeric,
                                      string_agg(format('antigüedad %s, mayor %s', total, mayor), '; ') filter (where nivel = 'total')
                                 from public.v_cxc_antiguedad where periodo = $1 $q$),
      (22, 'v_cxp_antiguedad', $q$ select count(*), bool_and(cuadra) filter (where nivel = 'total'), null::numeric,
                                      string_agg(format('antigüedad %s, mayor %s', total, mayor), '; ') filter (where nivel = 'total')
                                 from public.v_cxp_antiguedad where periodo = $1 $q$),
      (23, 'v_gasto_lineas', 'select count(*), null::boolean, null::numeric, null::text from public.v_gasto_lineas where ' || v_en),
      (24, 'v_gasto_por_categoria', 'select count(*), null::boolean, null::numeric, null::text from public.v_gasto_por_categoria where periodo = $1'),
      (25, 'v_gasto_por_proveedor', 'select count(*), null::boolean, null::numeric, null::text from public.v_gasto_por_proveedor where periodo = $1'),
      (26, 'v_costo_por_obra', $q$ select count(*), bool_and(cuadra) filter (where nivel = 'control'), null::numeric,
                                      string_agg(format('%s: repartido por obra %s + sin repartir %s ≠ mayor %s',
                                                        coalesce(cuenta, seccion), del_anio, sin_repartir, mayor), '; ')
                                        filter (where nivel = 'control' and not cuadra)
                                 from public.v_costo_por_obra where periodo = $1 $q$),
      (27, 'v_obras_dinero', $q$ select count(*), bool_and(cuadra), null::numeric,
                                    string_agg(format('%s: apertura %s + facturado %s − cobrado %s + otros %s ≠ por cobrar %s + '
                                                      'retención %s', coalesce(obra, proyecto_id), por_cobrar_apertura, facturado,
                                                      cobrado, otros, por_cobrar, retencion), '; ') filter (where not cuadra)
                               from public.v_obras_dinero where periodo = $1 $q$),
      (30, 'v_qb_balanzas', 'select count(*), null::boolean, null::numeric, null::text from public.v_qb_balanzas where periodo = $1 and vigente'),
      (31, 'v_comparacion', $q$ select count(*), bool_and(ok), null::numeric,
                                   string_agg(format('%s: %s sin explicar', coalesce(cuenta, cuenta_qb), sin_explicar), '; ')
                                     filter (where not ok)
                              from public.v_comparacion where periodo = $1 $q$),
      (32, 'v_comparacion_resumen', 'select count(*), null::boolean, null::numeric, null::text from public.v_comparacion_resumen where periodo = $1'),
      (33, 'v_comparacion_obra', $q$ select count(*), bool_and(ok), null::numeric,
                                        string_agg(format('%s %s: %s sin explicar', cuenta, coalesce(obra, proyecto_id, 'sin obra'),
                                                          sin_explicar), '; ') filter (where not ok)
                                   from public.v_comparacion_obra where periodo = $1 $q$)
    ) as t(orden, vista, sql)
    where t.vista = any (v_pedidas)
    order by t.orden
  loop
    orden := r.orden;
    vista := r.vista;
    v_err := null;
    v_n := null; v_cuadra := null; v_valor := null; v_det := null;
    begin
      execute r.sql using v_pid into v_n, v_cuadra, v_valor, v_det;
    exception when others then
      v_err := format('%s: %s', sqlstate, sqlerrm);
    end;
    filas := v_n;
    esperadas := (v_esp->>r.vista)::bigint;
    ok := v_err is null and v_err_e is null and filas is not distinct from esperadas;
    detalle := case when v_err is not null then format('La vista %s falló: %s. No se pinta.', r.vista, v_err)
                    when v_err_e is not null then format('No se pudo calcular lo que el libro espera (%s): no se pinta.', v_err_e)
                    when not ok then format('La vista %s devolvió %s filas y el libro dice %s: no se pinta.', r.vista, filas,
                                            esperadas) end;
    return next;
    -- Lo que cuadra, para después. Sin su fila de total (la vista no dio
    -- filas) un cuadre vale solo si el libro no esperaba nada.
    v_cuadra := coalesce(v_cuadra, coalesce(esperadas, 0) = 0 and v_err is null);
    if v_err is not null then
      v_cuadra := false;
      v_det := format('la vista %s falló', r.vista);
    end if;
    if r.vista = 'v_estados_mapeo' then
      v_cuad := v_cuad || jsonb_build_object('orden', 57, 'vista', 'cuadre: mapeo completo', 'ok', v_cuadra,
                                             'detalle', 'cuentas sin fila en estados_mapeo (select fn_estados_mapeo_derivar();): '
                                                        || coalesce(v_det, '(la vista no respondió)'));
    elsif r.vista = 'v_balanza' then
      v_cuad := v_cuad || jsonb_build_object('orden', 50, 'vista', 'cuadre: balanza en cero', 'ok', v_cuadra,
                                             'detalle', coalesce(v_det, 'la vista no dio su fila de total'));
    elsif r.vista = 'v_balance_general' then
      v_bal := case when v_err is null then v_valor end;
      v_cuad := v_cuad || jsonb_build_object('orden', 51, 'vista', 'cuadre: activo = pasivo + capital', 'ok', v_cuadra,
                                             'detalle', coalesce(v_det, 'la vista no dio su fila de cuadre'));
    elsif r.vista = 'v_resultados' then
      v_res := case when v_err is null then v_valor end;
    elsif r.vista = 'v_flujo_caja' then
      v_cuad := v_cuad || jsonb_build_object('orden', 52, 'vista', 'cuadre: flujo directo = indirecto = cambio del efectivo',
                                             'ok', v_cuadra, 'detalle', coalesce(v_det, 'la vista no dio sus filas de control'));
      v_ef_pd := true;
      v_ef_fl := case when v_err is null then coalesce(v_valor, case when coalesce(esperadas, 0) = 0 then 0 end) end;
    elsif r.vista = 'v_flujo_real_por_mes' then
      -- (Solo los meses: en la apertura y en el año, la vista no da filas.)
      if v_tipo = 'mes' then
        v_ef_pd := true;
        v_ef_re := case when v_err is null then coalesce(v_valor, case when coalesce(esperadas, 0) = 0 then 0 end) end;
      end if;
    elsif r.vista = 'v_cxc_antiguedad' then
      v_cuad := v_cuad || jsonb_build_object('orden', 53, 'vista', 'cuadre: antigüedad de cobrar = mayor', 'ok', v_cuadra,
                                             'detalle', coalesce(v_det, 'la vista no dio su fila de total'));
    elsif r.vista = 'v_cxp_antiguedad' then
      v_cuad := v_cuad || jsonb_build_object('orden', 54, 'vista', 'cuadre: antigüedad de pagar = mayor', 'ok', v_cuadra,
                                             'detalle', coalesce(v_det, 'la vista no dio su fila de total'));
    elsif r.vista = 'v_costo_por_obra' then
      v_cuad := v_cuad || jsonb_build_object('orden', 55, 'vista', 'cuadre: auxiliar por obra = mayor', 'ok', v_cuadra,
                                             'detalle', coalesce(v_det, 'la vista no dio sus filas de control'));
    elsif r.vista = 'v_obras_dinero' then
      v_cuad := v_cuad || jsonb_build_object('orden', 60, 'vista',
                                             'cuadre: dinero por obra (apertura + facturado − cobrado + otros = por cobrar)',
                                             'ok', v_cuadra, 'detalle', coalesce(v_det, 'la vista no dio filas'));
    elsif r.vista = 'v_comparacion' then
      v_cuad := v_cuad || jsonb_build_object('orden', 58, 'vista', 'cuadre: QuickBooks sin diferencias sin explicar',
                                             'ok', v_cuadra, 'detalle', coalesce(v_det, 'la vista no dio filas'));
    elsif r.vista = 'v_comparacion_obra' then
      v_cuad := v_cuad || jsonb_build_object('orden', 59, 'vista', 'cuadre: QuickBooks por obra sin diferencias sin explicar',
                                             'ok', v_cuadra, 'detalle', coalesce(v_det, 'la vista no dio filas'));
    end if;
  end loop;
  if 'v_resultados' = any (v_pedidas) and 'v_balance_general' = any (v_pedidas) then
    v_cuad := v_cuad || jsonb_build_object('orden', 56, 'vista', 'cuadre: resultado del estado = resultado del balance',
                                           'ok', v_res is not null and v_bal is not null and v_res = v_bal,
                                           'detalle', format('estado de resultados %s, balance %s', coalesce(v_res::text, '(no dio)'),
                                                             coalesce(v_bal::text, '(no dio)')));
  end if;
  -- El efectivo al final del flujo (y el del Panel) es el del balance al
  -- corte: el mismo renglón «efectivo» (con las cuentas en rojo fuera, en
  -- el sobregiro). Antes el cuadre del flujo se comparaba contra el
  -- efectivo del libro, y con un banco en rojo el flujo decía 19,300 y el
  -- balance 20,000, todo en verde.
  if v_ef_pd then
    v_valor := (v_esp->>'efectivo_balance')::numeric;
    v_cuad := v_cuad || jsonb_build_object('orden', 62, 'vista', 'cuadre: efectivo del flujo = efectivo del balance',
      'ok', v_valor is not null
            and ('v_flujo_caja' <> all (v_pedidas) or v_ef_fl = v_valor)
            and ('v_flujo_real_por_mes' <> all (v_pedidas) or v_tipo <> 'mes' or v_ef_re = v_valor),
      'detalle', format('balance (renglón efectivo) %s; flujo de caja %s; flujo del Panel %s', coalesce(v_valor::text, '(no se pudo)'),
                        case when 'v_flujo_caja' = any (v_pedidas) then coalesce(v_ef_fl::text, '(no dio)') else '(no se pidió)' end,
                        case when 'v_flujo_real_por_mes' = any (v_pedidas) and v_tipo = 'mes'
                             then coalesce(v_ef_re::text, '(no dio)') else '(no se pidió)' end));
  end if;

  -- LA APERTURA EN EL LIBRO, siempre (todo período es desde la apertura, y
  -- 'hoy'): un asiento de apertura vivo que posteó fn_apertura, con su
  -- balanza como entró (su huella), y ninguna apertura hecha a mano viva.
  -- Si alguien la reversa «para rehacerla luego», o todavía no se postea,
  -- esto sale en rojo y la pantalla no pinta (f05: las cifras no se
  -- publican hasta que la apertura amarre). Antes, reversada, la balanza
  -- de QuickBooks desaparecía de la comparación y todo salía en verde con
  -- el banco en 0.
  select a.numero into v_apn
    from asientos a
   where a.tipo = 'apertura' and a.origen_tabla = 'apertura_balanza_qb'
     and coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'
     and a.camino not in ('reverso', 'reverso_automatico')
     and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')
   order by a.cadena_pos desc
   limit 1;
  -- (Una apertura hecha a mano, viva, no es la de la balanza: se dice
  -- cuál es, para que no parezca que el libro está sin apertura.)
  select a.numero into v_x
    from asientos a
   where a.tipo = 'apertura' and coalesce(a.procedencia->>'funcion', '') <> 'fn_apertura'
     and a.camino not in ('reverso', 'reverso_automatico')
     and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')
   order by a.cadena_pos desc
   limit 1;
  v_det := case
             when v_apn is null then
               concat_ws('; ',
                 coalesce((select format('la apertura (asiento %s, con la balanza %s) está REVERSADA: el libro no tiene la '
                                         'apertura de QuickBooks. Vuelve a postearla con fn_apertura (y su motivo)',
                                         a.numero, a.documento_ruta)
                             from asientos a
                            where a.tipo = 'apertura' and coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'
                              and a.camino not in ('reverso', 'reverso_automatico')
                            order by a.cadena_pos desc limit 1),
                          case when v_x is null
                               then 'no hay apertura en el libro: carga la balanza de QuickBooks (fn_apertura_balanza_cargar), '
                                    'mapea sus cuentas y postéala con fn_apertura' end),
                 case when v_x is not null
                      then format('la apertura viva (asiento %s) es una hecha a mano: no es la de la balanza de QuickBooks. '
                                  'Postea la de la balanza con fn_apertura y reversa la hecha a mano', v_x) end)
             when exists (select 1 from asientos a
                           where a.tipo = 'apertura' and coalesce(a.procedencia->>'funcion', '') <> 'fn_apertura'
                             and a.camino not in ('reverso', 'reverso_automatico')
                             and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')) then
               format('además de la apertura %s hay un asiento de apertura hecho a mano vivo: la apertura estaría dos veces', v_apn)
             when exists (select 1 from asientos a
                           where a.numero = v_apn and a.procedencia ? 'huella_balanza'
                             and a.procedencia->>'huella_balanza' is distinct from
                                 (select md5(coalesce(string_agg(row(qb.linea, qb.cuenta_qb, qb.debe, qb.haber, qb.factura_id,
                                                                     qb.retencion, qb.cliente_trabajo, qb.proyecto_id,
                                                                     qb.proveedor_qb, qb.proveedor_id, qb.recibo_id,
                                                                     qb.trabajo_externo_id, qb.referencia, qb.notas,
                                                                     qb.fecha_documento, qb.vence, qb.factura_num)::text,
                                                                 E'\n' order by qb.linea), ''))
                                    from apertura_balanza_qb qb where qb.documento = a.documento_ruta)) then
               format('la balanza de la apertura (asiento %s) cambió desde que entró al libro (su huella)', v_apn)
           end;
  v_cuad := v_cuad || jsonb_build_object('orden', 63, 'vista', 'cuadre: apertura en el libro', 'ok', v_det is null,
                                         'detalle', coalesce(v_det, format('asiento %s', v_apn)));

  -- 3. Las protecciones de c4, siempre: lo que la API y el SQL Editor no
  -- deben poder saltarse sin que se vea.
  --   · sus triggers, encendidos ('O' o 'A') y con su función;
  select coalesce(array_agg(format('trigger %s en %s %s', t.nombre, t.tabla,
                                   case when tg.oid is null then 'no está'
                                        when tg.tgenabled not in ('O', 'A') then 'apagado'
                                        else 'con otra función (' || tg.tgfoid::regproc::text || ')' end)
                            order by t.nombre), '{}')
    into v_prot
    from (values ('trg_estados_mapeo_guarda', 'estados_mapeo', 'fn_estados_mapeo_guarda'),
                 ('trg_estados_mapeo_historial', 'estados_mapeo', 'fn_estados_historial'),
                 ('trg_estados_lineas_historial', 'estados_lineas', 'fn_estados_historial'),
                 ('trg_estados_config_historial', 'estados_config', 'fn_estados_historial'),
                 ('trg_apertura_mapeo_qb_historial', 'apertura_mapeo_qb', 'fn_estados_historial'),
                 ('trg_diferencias_historial', 'diferencias', 'fn_estados_historial'),
                 ('trg_estados_historial_inmutable', 'estados_historial', 'fn_estados_inmutable'),
                 ('trg_estados_historial_sin_truncate', 'estados_historial', 'fn_estados_inmutable'),
                 ('trg_comparacion_qb_inmutable', 'comparacion_qb', 'fn_estados_inmutable'),
                 ('trg_comparacion_qb_sin_truncate', 'comparacion_qb', 'fn_estados_inmutable'),
                 ('trg_comparacion_qb_sin_filas_nuevas', 'comparacion_qb', 'fn_comparacion_qb_sin_filas_nuevas'),
                 ('trg_diferencias_inmutable', 'diferencias', 'fn_estados_inmutable'),
                 ('trg_diferencias_sin_truncate', 'diferencias', 'fn_estados_inmutable'),
                 ('trg_apertura_balanza_guarda', 'apertura_balanza_qb', 'fn_apertura_balanza_guarda'),
                 ('trg_apertura_balanza_sin_truncate', 'apertura_balanza_qb', 'fn_apertura_balanza_guarda'),
                 ('trg_estados_mapeo_sin_truncate', 'estados_mapeo', 'fn_estados_inmutable'),
                 ('trg_estados_lineas_sin_truncate', 'estados_lineas', 'fn_estados_inmutable'),
                 ('trg_estados_config_sin_truncate', 'estados_config', 'fn_estados_inmutable'),
                 ('trg_apertura_mapeo_qb_sin_truncate', 'apertura_mapeo_qb', 'fn_estados_inmutable'),
                 ('trg_estados_historial_solo_su_trigger', 'estados_historial', 'fn_estados_inmutable'),
                 ('trg_comparacion_qb_quien', 'comparacion_qb', 'fn_estados_quien'),
                 ('trg_apertura_balanza_quien', 'apertura_balanza_qb', 'fn_estados_quien'),
                 ('trg_diferencias_quien', 'diferencias', 'fn_estados_quien'),
                 ('trg_comparacion_qb_historial', 'comparacion_qb', 'fn_estados_historial'),
                 ('trg_apertura_balanza_historial', 'apertura_balanza_qb', 'fn_estados_historial')) as t(nombre, tabla, funcion)
    left join pg_trigger tg on tg.tgrelid = to_regclass('public.' || t.tabla) and tg.tgname = t.nombre
   where tg.oid is null or tg.tgenabled not in ('O', 'A') or tg.tgfoid <> to_regproc('public.' || t.funcion);
  --   · sus HUELLAS (las de este pegado, fn_estados_huellas): cada función
  --     de c4 (fn_estados_…, fn_apertura…, fn_comparacion_…,
  --     fn_diferencia_…), cada trigger y cada regla de sus tablas y la
  --     definición de cada vista, como quedaron al pegarlo. Mirar solo el
  --     nombre dejaba pasar en verde una guarda vaciada con create or
  --     replace (mismo nombre, mismo oid), un trigger rehecho para otros
  --     eventos, un trigger ajeno que se traga las altas del historial o
  --     una regla «do instead nothing»;
  --     (Corre también desde la app, como el dueño: authenticated no
  --     ejecuta fn_estados_huellas ni fn_estados_huellas_calcular —de la API
  --     solo este control—, así que aquí se corre el TEXTO de las dos,
  --     que está en pg_proc y cualquiera lee: las selladas son valores
  --     literales, y las de ahora, lecturas del catálogo. Antes, desde la
  --     app, este control se caía con 42501.)
  select max(p.prosrc) filter (where p.oid = to_regprocedure('public.fn_estados_huellas()')),
         max(p.prosrc) filter (where p.oid = to_regprocedure('public.fn_estados_huellas_calcular()'))
    into v_hsel, v_hcal
    from pg_proc p
   where p.oid in (to_regprocedure('public.fn_estados_huellas()'), to_regprocedure('public.fn_estados_huellas_calcular()'));
  if v_hsel is null or v_hcal is null then
    v_hue := array['faltan las huellas de c4 (fn_estados_huellas): vuelve a pegar c4-estados.sql'];
  else
    execute 'select coalesce(array_agg(format(''%s %s %s'', coalesce(h.tipo, a.tipo), coalesce(h.objeto, a.objeto),
                                              case when h.objeto is null then ''es nuevo: no es de c4 (volver a pegar c4 lo quita)''
                                                   when a.objeto is null then ''ya no está''
                                                   else ''cambió desde que se pegó c4'' end)
                                       order by coalesce(h.tipo, a.tipo), coalesce(h.objeto, a.objeto)), ''{}'')
               from (' || v_hsel || ') h(tipo, objeto, md5)
               full join (' || v_hcal || ') a(tipo, objeto, md5) on a.tipo = h.tipo and a.objeto = h.objeto
              where a.md5 is distinct from h.md5'
      into v_hue;
  end if;
  v_prot := v_prot || v_hue;
  --   · sus tablas: RLS encendida, UNA policy (la de lectura del dueño,
  --     «es_dueno()» o «(select es_dueno())»), y de privilegios solo
  --     SELECT para authenticated y service_role; nada para anon ni PUBLIC;
  v_prot := v_prot
    || coalesce((select array_agg(format('tabla %s sin RLS', t.t) order by t.t)
                   from unnest(v_tablas) as t(t)
                   join pg_class c on c.oid = to_regclass('public.' || t.t)
                  where not c.relrowsecurity), '{}')
    || coalesce((select array_agg(format('tabla %s con la policy %s (%s)', pl.tablename, pl.policyname,
                                         coalesce(pl.qual, 'sin using')) order by pl.tablename, pl.policyname)
                   from pg_policies pl
                  where pl.schemaname = 'public' and pl.tablename = any (v_tablas)
                    and not (pl.policyname = pl.tablename || '_dueno' and pl.cmd = 'SELECT' and pl.roles = '{authenticated}'
                             and pl.permissive = 'PERMISSIVE'
                             and regexp_replace(pl.qual, '[[:space:]]', '', 'g')
                                   in ('es_dueno()', '(SELECTes_dueno()ASes_dueno)'))), '{}')
    || coalesce((select array_agg(format('tabla %s sin su policy de lectura', t.t) order by t.t)
                   from unnest(v_tablas) as t(t)
                  where not exists (select 1 from pg_policies pl
                                     where pl.schemaname = 'public' and pl.tablename = t.t and pl.policyname = t.t || '_dueno')),
                '{}')
    || coalesce((select array_agg(format('tabla %s: %s puede %s', t.t, g.r, g.priv) order by t.t, g.r, g.priv)
                   from unnest(v_tablas) as t(t)
                   cross join (values ('anon'), ('authenticated'), ('service_role'), ('public')) as g0(r)
                   cross join lateral (select g0.r as r, x.priv
                                         from unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES',
                                                           'TRIGGER']) as x(priv)
                                        where case when g0.r = 'public'
                                                   then exists (select 1 from pg_class c, aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) e
                                                                 where c.oid = to_regclass('public.' || t.t) and e.grantee = 0
                                                                   and e.privilege_type = x.priv)
                                                   else has_table_privilege(g0.r, 'public.' || t.t, x.priv)
                                                        and not (x.priv = 'SELECT' and g0.r in ('authenticated', 'service_role')) end) g),
                '{}')
  --   · sus vistas: security_invoker, y solo SELECT para authenticated;
    || coalesce((select array_agg(format('vista %s %s', v.v,
                                         case when c.oid is null then 'no está'
                                              when not ('security_invoker=true' = any (coalesce(c.reloptions, '{}')))
                                                then 'sin security_invoker'
                                              else 'con permisos de más o de menos' end) order by v.v)
                   from unnest(v_vistas) as v(v)
                   left join pg_class c on c.oid = to_regclass('public.' || v.v) and c.relkind = 'v'
                  where c.oid is null
                     or not ('security_invoker=true' = any (coalesce(c.reloptions, '{}')))
                     or not has_table_privilege('authenticated', c.oid, 'SELECT')
                     or has_table_privilege('authenticated', c.oid, 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
                     or has_table_privilege('anon', c.oid, 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
                     or has_table_privilege('service_role', c.oid, 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')),
                '{}')
  --   · sus funciones: ninguna SECURITY DEFINER; de la API, solo
  --     fn_estados_control (y solo para authenticated);
    || coalesce((select array_agg(format('función %s %s', f.oid::regprocedure,
                                         case when f.prosecdef then 'es SECURITY DEFINER'
                                              when f.proname = 'fn_estados_control' then 'no la puede correr el dueño desde la app, o sí anon'
                                              else 'la puede correr la API' end) order by f.oid::regprocedure::text)
                   from pg_proc f
                  where f.pronamespace = 'public'::regnamespace
                    and (f.proname like 'fn\_estados\_%' or f.proname like 'fn\_apertura%' or f.proname like 'fn\_comparacion\_%'
                         or f.proname like 'fn\_diferencia\_%')
                    and (f.prosecdef
                         or has_function_privilege('anon', f.oid, 'EXECUTE')
                         or (f.proname = 'fn_estados_control' and not has_function_privilege('authenticated', f.oid, 'EXECUTE'))
                         or (f.proname <> 'fn_estados_control' and has_function_privilege('authenticated', f.oid, 'EXECUTE')))),
                '{}')
  --   · los permisos por COLUMNA de sus tablas y vistas (la pantalla
  --     «Column privileges» de Supabase; has_table_privilege no los ve): a
  --     la API, ninguno. Con uno de insert por columnas, service_role
  --     plantaba la balanza vigente de QuickBooks y todo seguía en verde;
    || coalesce((select array_agg(format('%s %s: %s puede %s la columna %s', case when c.relkind = 'v' then 'vista' else 'tabla' end,
                                         c.relname, case when e.grantee = 0 then 'PUBLIC' else ro.rolname::text end,
                                         e.privilege_type, at.attname)
                                  order by c.relname, at.attname, e.privilege_type)
                   from pg_class c
                   join pg_attribute at on at.attrelid = c.oid and at.attnum > 0 and not at.attisdropped and at.attacl is not null
                   cross join lateral aclexplode(at.attacl) e
                   left join pg_roles ro on ro.oid = e.grantee
                  where c.relnamespace = 'public'::regnamespace and c.relname = any (v_tablas || v_vistas)
                    and (e.grantee = 0 or ro.rolname in ('anon', 'authenticated', 'service_role'))), '{}')
  --   · el RASTRO de cada regla, mapeo, anotación y balanza de QuickBooks:
  --     cada fila de estados_mapeo, estados_lineas, estados_config,
  --     apertura_mapeo_qb, diferencias, comparacion_qb y apertura_balanza_qb
  --     es como la dejó su último renglón de estados_historial (buscado por
  --     tabla y clave, la del trigger), y lo que el historial dice que
  --     existe, existe. Como c2 cruza cuentas con cuentas_historial: un
  --     cambio con el trigger de historial apagado un instante (o una fila
  --     de QuickBooks metida así) ya no pasa callado;
    || coalesce((
         with h as (select distinct on (x.tabla, x.clave) x.tabla, x.clave, x.operacion, x.despues
                      from estados_historial x
                     where x.tabla in ('estados_mapeo', 'estados_lineas', 'estados_config', 'apertura_mapeo_qb', 'diferencias',
                                       'comparacion_qb', 'apertura_balanza_qb')
                     order by x.tabla, x.clave, x.cambiado_el desc, x.id desc),
              v as (select 'estados_mapeo'::text as tabla, coalesce(t.cuenta, '-') as clave, to_jsonb(t) as fila
                      from estados_mapeo t
                    union all
                    select 'estados_lineas', concat_ws('|', coalesce(t.estado, '-'), coalesce(t.seccion, '-'), coalesce(t.linea, '-')),
                           to_jsonb(t)
                      from estados_lineas t
                    union all
                    select 'estados_config', coalesce(t.clave, '-'), to_jsonb(t) from estados_config t
                    union all
                    select 'apertura_mapeo_qb', coalesce(t.tipo, '-') || '|' || coalesce(t.clave, '-'), to_jsonb(t)
                      from apertura_mapeo_qb t
                    union all
                    select 'diferencias', coalesce(t.periodo, '-') || '|' || coalesce(t.cuenta, '-') || '|' || t.id::text, to_jsonb(t)
                      from diferencias t
                    union all
                    select 'comparacion_qb', t.periodo || '|' || t.documento || '|' || t.linea, to_jsonb(t) from comparacion_qb t
                    union all
                    select 'apertura_balanza_qb', t.documento || '|' || t.linea, to_jsonb(t) from apertura_balanza_qb t)
         select array_agg(format('%s %s %s', coalesce(v.tabla, h.tabla), coalesce(v.clave, h.clave),
                                 case when h.clave is null then 'no tiene su renglón en estados_historial (entró sin su trigger)'
                                      when v.clave is null then 'ya no está, y su historial no dice que se borró'
                                      when h.operacion = 'DELETE' then 'está, y su historial dice que se borró'
                                      else 'no es como la dejó su último cambio en estados_historial' end)
                          order by coalesce(v.tabla, h.tabla), coalesce(v.clave, h.clave))
           from v
           full join h on h.tabla = v.tabla and h.clave = v.clave
          where h.clave is null
             or (v.clave is null and h.operacion <> 'DELETE')
             or (v.clave is not null and (h.operacion = 'DELETE' or not (v.fila @> h.despues)))), '{}')
  --   · lo AJENO que abre sus tablas a la API: una vista (de cualquier
  --     esquema que no sea del sistema) que las lee, directo o a través de
  --     otra vista, sin security_invoker (lee con los permisos de su dueño
  --     y se salta la RLS: en Supabase nace así, y con SELECT para anon y
  --     authenticated); una vista materializada que las copia y que la API
  --     puede leer; y una función SECURITY DEFINER que las nombra o
  --     depende de ellas y que anon, authenticated o service_role pueden
  --     ejecutar. (Es el error honesto que c2 caza para el libro: una vista
  --     de ayuda para el CPA hecha en el SQL Editor sobre la balanza de
  --     QuickBooks, sin security_invoker, se la daba a la llave pública.)
    || coalesce((
         with recursive dep(oid) as (
                select c.oid from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = any (v_tablas)
                union
                select rw.ev_class
                  from dep
                  join pg_depend d on d.refobjid = dep.oid and d.refclassid = 'pg_class'::regclass
                                  and d.classid = 'pg_rewrite'::regclass
                  join pg_rewrite rw on rw.oid = d.objid
                 where rw.ev_class <> dep.oid),
              nom as (select coalesce(string_agg(distinct c.relname::text, '|'), '-') as rx
                        from pg_class c where c.oid in (select dep.oid from dep) and c.relname ~ '^[[:alnum:]_]+$')
         select array_agg(x.f order by x.f)
           from (select format('la vista %s.%s lee las tablas de c4 sin security_invoker: la API la lee con los permisos de su '
                               'dueño (with (security_invoker = true), y revoke de anon)', n.nspname, c.relname) as f
                   from pg_class c
                   join pg_namespace n on n.oid = c.relnamespace
                  where c.oid in (select dep.oid from dep) and c.relkind = 'v'
                    and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o
                                       where o.option_name = 'security_invoker'), false)
                 union all
                 select format('la vista materializada %s.%s copia tablas de c4 y la API la puede leer', n.nspname, c.relname)
                   from pg_class c
                   join pg_namespace n on n.oid = c.relnamespace
                  where c.oid in (select dep.oid from dep) and c.relkind = 'm'
                    and (has_table_privilege('anon', c.oid, 'SELECT') or has_table_privilege('authenticated', c.oid, 'SELECT')
                         or has_table_privilege('service_role', c.oid, 'SELECT'))
                 union all
                 select format('la función %s es SECURITY DEFINER, lee tablas o vistas de c4 y la puede ejecutar %s',
                               p.oid::regprocedure,
                               (select string_agg(g, ', ' order by g)
                                  from unnest(array['anon', 'authenticated', 'service_role']) g
                                 where has_schema_privilege(g, p.pronamespace, 'USAGE')
                                   and has_function_privilege(g, p.oid, 'EXECUTE')))
                   from pg_proc p
                   join pg_namespace n on n.oid = p.pronamespace
                   cross join nom
                  where n.nspname !~ '^pg_' and n.nspname <> 'information_schema'
                    and p.prosecdef and p.prokind = 'f'
                    and p.prorettype not in ('trigger'::regtype, 'event_trigger'::regtype)
                    and not exists (select 1 from pg_depend e
                                     where e.classid = 'pg_proc'::regclass and e.objid = p.oid and e.deptype = 'e')
                    and exists (select 1 from unnest(array['anon', 'authenticated', 'service_role']) g
                                 where has_schema_privilege(g, p.pronamespace, 'USAGE')
                                   and has_function_privilege(g, p.oid, 'EXECUTE'))
                    and (p.prosrc ~* ('[[:<:]](from|join|into|update|table|only|truncate)[[:space:]]+'
                                      || '(([[:alnum:]_]+|"[^"]+")[[:space:]]*[.][[:space:]]*)?"?(' || nom.rx || ')"?[[:>:]]')
                         or exists (select 1 from pg_depend d
                                     where d.classid = 'pg_proc'::regclass and d.objid = p.oid
                                       and d.refclassid = 'pg_class'::regclass and d.refobjid in (select dep.oid from dep)))) x),
                '{}')
  --   · y el papel de la apertura: su balanza sigue siendo la que se posteó
  --     (la huella que guardó fn_apertura, la misma cuenta que allí).
    || coalesce((select array_agg(format('la balanza %s de la apertura (asiento %s) cambió desde que entró al libro',
                                         a.documento_ruta, a.numero))
                   from asientos a
                  where a.tipo = 'apertura' and a.origen_tabla = 'apertura_balanza_qb'
                    and coalesce(a.procedencia->>'funcion', '') = 'fn_apertura' and a.procedencia ? 'huella_balanza'
                    and a.camino not in ('reverso', 'reverso_automatico')
                    and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')
                    and a.procedencia->>'huella_balanza' is distinct from
                        (select md5(coalesce(string_agg(row(qb.linea, qb.cuenta_qb, qb.debe, qb.haber, qb.factura_id, qb.retencion,
                                                             qb.cliente_trabajo, qb.proyecto_id, qb.proveedor_qb, qb.proveedor_id,
                                                             qb.recibo_id, qb.trabajo_externo_id, qb.referencia, qb.notas,
                                                             qb.fecha_documento, qb.vence, qb.factura_num)::text,
                                                         E'\n' order by qb.linea), ''))
                           from apertura_balanza_qb qb where qb.documento = a.documento_ruta)), '{}');
  v_cuad := v_cuad || jsonb_build_object('orden', 61, 'vista', 'cuadre: protecciones de c4', 'ok', cardinality(v_prot) = 0,
                                         'detalle', left(array_to_string(v_prot, '; '), 1500)
                                                    || '. Vuelve a pegar c4-estados.sql (lo pone todo en su sitio) y revisa quién '
                                                    || 'lo cambió');

  -- 4. Los cuadres.
  for r in select (e->>'orden')::int as o, e->>'vista' as v, (e->>'ok')::boolean as k, e->>'detalle' as d
             from jsonb_array_elements(v_cuad) e order by 1 loop
    orden := r.o;
    vista := r.v;
    filas := null;
    esperadas := null;
    ok := r.k;
    detalle := case when not r.k then format('No cuadra: %s.', coalesce(r.d, '(sin detalle)')) end;
    return next;
  end loop;
end $$;
revoke execute on function public.fn_estados_control(text, text[]) from public, anon, authenticated, service_role;
grant  execute on function public.fn_estados_control(text, text[]) to authenticated;


-- =====================================================================
-- 9 · QUIÉN LEE LAS VISTAS, Y LOS COMENTARIOS
-- Las vistas se leen solo con SELECT, solo desde authenticated (conta.js),
-- y con security_invoker: cada una lee con los permisos de quien la mira,
-- así que el libro solo lo ve el dueño (la policy de sus tablas): el equipo
-- lee 0 filas de todas, y anon no las puede ni abrir. En Supabase una vista
-- nueva nace con todos los permisos para anon, authenticated y
-- service_role: se quitan todos y se da solo el que hace falta. (Las de
-- base también: una vista security_invoker pide permiso sobre las vistas
-- que usa.)
-- =====================================================================
do $$
declare
  v      text;
  v_cols text;
begin
  foreach v in array array['v_estados_mapeo_propuesto', 'v_estados_mapeo', 'v_cortes', 'v_ejercicios', 'v_libro', 'v_mayor',
                           'v_asiento_papel', 'v_balanza_base', 'v_balanza', 'v_balanza_obra', 'v_balance_general',
                           'v_resultados', 'v_flujo_lineas', 'v_flujo_caja', 'v_efectivo_movimientos', 'v_flujo_real_por_mes',
                           'v_saldos_dinero', 'v_cxc_antiguedad', 'v_cxp_antiguedad', 'v_gasto_lineas', 'v_gasto_por_categoria',
                           'v_gasto_por_proveedor', 'v_costo_por_obra', 'v_obras_dinero', 'v_qb_balanzas', 'v_comparacion',
                           'v_comparacion_obra', 'v_comparacion_resumen'] loop
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', v);
    -- (y los permisos por columna que alguien le haya dado: ver 1.7)
    select string_agg(quote_ident(a.attname), ', ' order by a.attnum) into v_cols
      from pg_attribute a
     where a.attrelid = ('public.' || v)::regclass and a.attnum > 0 and not a.attisdropped and a.attacl is not null
       and exists (select 1 from aclexplode(a.attacl) e left join pg_roles r on r.oid = e.grantee
                    where e.grantee = 0 or r.rolname in ('anon', 'authenticated', 'service_role'));
    if v_cols is not null then
      execute format('revoke all (%s) on public.%I from public, anon, authenticated, service_role', v_cols, v);
    end if;
    execute format('grant select on public.%I to authenticated', v);
  end loop;
end $$;

comment on table public.estados_historial   is 'c4: el rastro de cada cambio a los estados (renglones, mapeo, configuración, mapeo de QuickBooks, diferencias): quién, cuándo, antes y después. No se edita ni se borra.';
comment on table public.estados_lineas      is 'c4: los renglones de cada estado (balance, resultados, flujo directo e indirecto), con su orden y sus etiquetas en español e inglés.';
comment on table public.estados_mapeo       is 'c4: dónde sale cada cuenta del plan: estado, sección, renglón, signo, si es dinero y sus renglones del flujo. Derivado de cuentas.tipo; se ajusta con fn_estados_mapeo.';
comment on table public.estados_config      is 'c4: lo que decide el CPA de la presentación (plegar_3200).';
comment on table public.apertura_mapeo_qb   is 'c4: cada nombre de QuickBooks (cuenta o Customer:Job) y a qué va en el plan o en qué obra.';
comment on table public.apertura_balanza_qb is 'c4: la balanza de QuickBooks al 30-sep, fila por cuenta (y por partida donde hay cédula). La que entró al libro no cambia.';
comment on table public.comparacion_qb      is 'c4: las balanzas de QuickBooks de cada período del paralelo, para comparar. No se editan: vale la más reciente.';
comment on table public.diferencias         is 'c4: lo que el libro y QuickBooks no dicen igual, explicado (puente, mapeo o criterio), con quién y cuándo. Se retira, no se borra.';

comment on view public.v_estados_mapeo_propuesto is 'c4: el mapeo que se deriva de cuentas.tipo y del código, para cada cuenta del plan.';
comment on view public.v_estados_mapeo       is 'c4: el mapeo de cada cuenta (el guardado; sin fila, el propuesto y sin_fila = true), con nombres y órdenes.';
comment on view public.v_cortes              is 'c4: las fechas de corte: el último día de cada período y hoy (Miami).';
comment on view public.v_ejercicios          is 'c4: cada año y si está cerrado (su resultado se arrastra a utilidades retenidas).';
comment on view public.v_libro               is 'c4: el libro línea por línea, con su asiento, su papel, su mapeo y su ejercicio. A esta vista baja toda cifra.';
comment on view public.v_mayor               is 'c4: el libro mayor: v_libro con el saldo corrido de cada cuenta.';
comment on view public.v_asiento_papel       is 'c4: del asiento a su papel (recibo con su foto, factura, cobro, balanza de apertura…), y si el papel está.';
comment on view public.v_balanza_base        is 'c4: la base de v_balanza y v_balanza_obra (las dos agrupaciones de una pasada).';
comment on view public.v_balanza             is 'c4: la balanza de comprobación de cada período: saldo inicial, debe, haber y saldo final por cuenta, y el total en cero.';
comment on view public.v_balanza_obra        is 'c4: la balanza por cuenta, obra y cost code.';
comment on view public.v_balance_general     is 'c4: el balance general a cada corte: activo = pasivo + capital (con el resultado del ejercicio, el arrastre y lo por cerrar).';
comment on view public.v_resultados          is 'c4: el estado de resultados de cada período: el mes, el anterior, la variación, lo del año y los ajustes posteriores.';
comment on view public.v_flujo_lineas        is 'c4: las piezas que explican el dinero (cada línea que no es dinero, y sus reclasificaciones), con su renglón del flujo directo y del indirecto.';
comment on view public.v_flujo_caja          is 'c4: el flujo de efectivo de cada período, directo e indirecto, con lo que se movió sin dinero aparte y su cuadre por sección.';
comment on view public.v_efectivo_movimientos is 'c4: el dinero que se movió, asiento por asiento (su neto en los bancos), y si se anula con su reverso en el mes.';
comment on view public.v_flujo_real_por_mes  is 'c4: el dinero de cada mes: inicial, lo que entró y salió de verdad, neto, final y por sección.';
comment on view public.v_saldos_dinero       is 'c4: el saldo de cada banco, tarjeta y línea de crédito a cada corte.';
comment on view public.v_cxc_antiguedad      is 'c4: lo que se cobra, partida por partida, con su antigüedad, su retención aparte y el total contra el mayor.';
comment on view public.v_cxp_antiguedad      is 'c4: lo que se paga, partida por partida y proveedor, con antigüedad, vencimiento y el total contra el mayor.';
comment on view public.v_gasto_lineas        is 'c4: cada línea de gasto con su proveedor (el de la línea, el del asiento o el del papel).';
comment on view public.v_gasto_por_categoria is 'c4: el gasto de cada período por cuenta: el mes, lo del año y su parte.';
comment on view public.v_gasto_por_proveedor is 'c4: el gasto de cada período por proveedor.';
comment on view public.v_costo_por_obra      is 'c4: ingreso, costo, margen y otros por obra y cuenta (desde que empieza el libro); y el control auxiliar = mayor.';
comment on view public.v_obras_dinero        is 'c4: el dinero de cada obra a cada corte: por cobrar de la apertura, facturado, cobrado, otros, por cobrar, retención (y si cuadra), costo y margen.';
comment on view public.v_qb_balanzas         is 'c4: las filas de QuickBooks de cada período, con su cuenta del plan y su obra.';
comment on view public.v_comparacion         is 'c4: el libro contra QuickBooks, cuenta por cuenta, con lo explicado y lo que falta por explicar.';
comment on view public.v_comparacion_obra    is 'c4: el libro contra QuickBooks por obra.';
comment on view public.v_comparacion_resumen is 'c4: por período con balanza de QuickBooks: cuentas que cuadran, lo sin explicar y la utilidad contra QuickBooks.';

comment on function public.fn_estados_control(text, text[])   is 'c4: lo que conta.js lee antes de pintar: filas de cada vista contra las que dice el libro, y los cuadres. ok = false no se pinta.';
comment on function public.fn_estados_mapeo_derivar()         is 'c4: da su fila de estados_mapeo a cada cuenta del plan que no la tiene (lo propuesto).';
comment on function public.fn_estados_sembrar()               is 'c4: siembra lo que falta (renglones, configuración, mapeo) sin pisar lo ajustado; la corre cada pegado.';
comment on function public.fn_estados_mapeo(text, jsonb)      is 'c4: ajusta dónde sale una cuenta (sección, renglón, etiquetas, flujo), con rastro.';
comment on function public.fn_estados_linea(text, text, text, text, text, int, text) is 'c4: crea o cambia un renglón de un estado (etiquetas, orden).';
comment on function public.fn_estados_config(text, text)      is 'c4: cambia lo que decide el CPA de la presentación (plegar_3200).';
comment on function public.fn_apertura_mapeo_qb(text, text, text) is 'c4: mapea un nombre de cuenta de QuickBooks a una cuenta del plan.';
comment on function public.fn_apertura_mapeo_trabajo(text, text, text) is 'c4: mapea un Customer:Job de QuickBooks a una obra de la app.';
comment on function public.fn_apertura_balanza_cargar(text, jsonb) is 'c4: carga (o recarga, si no entró al libro) la balanza de QuickBooks de la apertura.';
comment on function public.fn_apertura_plan(text)             is 'c4: arma el asiento de apertura de una balanza sin postearlo; para en el primer problema, con su nombre.';
comment on function public.fn_apertura_revisar(text)          is 'c4: la apertura como tabla, para mirarla antes: cada fila de QuickBooks con su cuenta del plan y su tipo, el control de QuickBooks y el asiento (o el primer problema).';
comment on function public.fn_apertura(date, text, text)      is 'c4: postea la apertura con una balanza de QuickBooks; idempotente; otra balanza dice qué cambia y no pisa (con motivo, la sustituye).';
comment on function public.fn_comparacion_qb_cargar(text, text, jsonb, boolean, date) is 'c4: carga la balanza de QuickBooks de un período para compararla con el libro (la final, con los ajustes posteriores del CPA; la de una quincena, con su fecha).';
comment on function public.fn_diferencia_anotar(text, text, text, text, text, text, uuid) is 'c4: anota una diferencia explicada entre el libro y QuickBooks.';
comment on function public.fn_diferencia_retirar(uuid, text)  is 'c4: retira una diferencia anotada, con su motivo (queda el rastro).';


-- =====================================================================
-- 10 · EL COMPILADOR JIT, APAGADO PARA LA APP. Con unos 10.000 asientos,
-- el costo estimado de las vistas grandes ronda el umbral del JIT
-- (jit_above_cost, 100.000) y lo cruza con el crecimiento normal del libro:
-- entonces Postgres compila cientos de funciones EN CADA LECTURA (la
-- gráfica del Panel, v_flujo_real_por_mes, de 0,4 s a 2,3–2,5 s, casi todo
-- compilación; v_balance_general y v_comparacion_resumen, de 0,3–0,4 s a
-- 1,3–1,5 s). fn_estados_control y c4-pruebas ya lo apagaban para sí; las
-- vistas que conta.js lee directo, no. PostgREST aplica en cada petición
-- los ajustes del rol con que corre (como el statement_timeout de 8 s de
-- authenticated): se le apaga ahí, solo en esta base. Si el que pega no
-- puede cambiar el rol, lo dice (WARNING) y la fila «c4 · jit» del final
-- sale en false, con qué hacer.
-- =====================================================================
do $$
begin
  execute format('alter role authenticated in database %I set jit = off', current_database());
exception when insufficient_privilege then
  raise warning 'c4: no se pudo apagar el JIT para authenticated (%). Pégalo como dueño de la base: alter role authenticated in database % set jit = off;',
    sqlerrm, current_database();
end $$;

-- Las huellas de c4, al final: ya está todo puesto (7.7).
do $$
begin
  perform public.fn_estados_huellas_sellar();
end $$;


-- =====================================================================
-- Lo que enseña el SQL Editor al terminar: lo que este archivo dejó
-- puesto, los controles del libro que miran permisos y triggers (en true:
-- c4 no toca nada de lo que vigilan las huellas de c2), y el control de los
-- estados del último mes con asientos (o de la apertura). Si alguna cuenta
-- del plan no tiene su fila de mapeo, o la apertura todavía no está, lo
-- dice aquí.
-- =====================================================================
select 'c4 · ' || x.que as control, x.ok, to_jsonb(x.detalle) as detalle
  from (values
    ('vistas', (select count(*) = 28 from pg_class v
                 where v.relnamespace = 'public'::regnamespace and v.relkind = 'v'
                   and 'security_invoker=true' = any (coalesce(v.reloptions, '{}'))
                   and v.relname in ('v_estados_mapeo_propuesto', 'v_estados_mapeo', 'v_cortes', 'v_ejercicios', 'v_libro',
                                      'v_mayor', 'v_asiento_papel', 'v_balanza_base', 'v_balanza', 'v_balanza_obra',
                                      'v_balance_general', 'v_resultados', 'v_flujo_lineas', 'v_flujo_caja',
                                      'v_efectivo_movimientos', 'v_flujo_real_por_mes', 'v_saldos_dinero', 'v_cxc_antiguedad',
                                      'v_cxp_antiguedad', 'v_gasto_lineas', 'v_gasto_por_categoria', 'v_gasto_por_proveedor',
                                      'v_costo_por_obra', 'v_obras_dinero', 'v_qb_balanzas', 'v_comparacion',
                                      'v_comparacion_obra', 'v_comparacion_resumen')),
     '28 vistas, todas security_invoker, solo SELECT para authenticated'),
    ('mapeo', not exists (select 1 from public.v_estados_mapeo m where m.sin_fila),
     (select format('%s cuentas con su fila; sin fila: %s', count(*) filter (where not m.sin_fila),
                    coalesce(string_agg(m.cuenta, ', ') filter (where m.sin_fila), 'ninguna'))
        from public.v_estados_mapeo m)),
    -- (La apertura cuenta si la posteó fn_apertura con su balanza: una
    -- hecha a mano, aunque herede el origen, sale en false y lo dice.)
    ('apertura', exists (select 1 from public.asientos a where a.tipo = 'apertura'
                          and coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'
                          and a.camino not in ('reverso', 'reverso_automatico')
                          and not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino = 'reverso'))
                 and not exists (select 1 from public.asientos a where a.tipo = 'apertura'
                                  and coalesce(a.procedencia->>'funcion', '') <> 'fn_apertura'
                                  and a.camino not in ('reverso', 'reverso_automatico')
                                  and not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino = 'reverso')),
     coalesce((select case when coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'
                           then format('asiento %s con %s', a.numero, a.documento_ruta)
                           else format('asiento %s hecho a mano (no lo posteó fn_apertura con su balanza): revérsalo y corre '
                                       'fn_apertura', a.numero) end
                 from public.asientos a
                where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                  and not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino = 'reverso')
                order by (coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'), a.cadena_pos desc limit 1),
              'todavía no: carga la balanza (fn_apertura_balanza_cargar), mapea sus cuentas (fn_apertura_mapeo_qb) y '
              'select fn_apertura(''2026-09-30'', ''<documento>'');')),
    -- (El JIT apagado para la app: 10.)
    ('jit', exists (select 1 from pg_db_role_setting s
                     where s.setrole = 'authenticated'::regrole
                       and s.setdatabase in (0, (select d.oid from pg_database d where d.datname = current_database()))
                       and 'jit=off' = any (s.setconfig)),
     case when exists (select 1 from pg_db_role_setting s
                        where s.setrole = 'authenticated'::regrole
                          and s.setdatabase in (0, (select d.oid from pg_database d where d.datname = current_database()))
                          and 'jit=off' = any (s.setconfig))
          then 'el JIT está apagado para authenticated (la app, por PostgREST)'
          else format('el JIT sigue encendido para la app: alter role authenticated in database %I set jit = off; (como dueño de la '
                      'base)', current_database()) end)
  ) as x(que, ok, detalle)
union all
select 'libro · ' || v.control, v.ok, v.detalle
  from public.fn_verificar_cadena() v
 where v.control in ('triggers', 'permisos')
union all
select 'estados ' || e.periodo || ' · ' || c.vista, c.ok,
       to_jsonb(coalesce(c.detalle, case when c.filas is null then 'cuadra' else format('%s filas', c.filas) end))
  from (select coalesce((select a.periodo from public.asientos a join public.periodos p on p.periodo = a.periodo
                          where p.tipo in ('mes', 'apertura') order by a.fecha_contable desc, a.cadena_pos desc limit 1),
                        (select p.periodo from public.periodos p where p.tipo = 'apertura' order by p.desde limit 1)) as periodo) e
  cross join lateral public.fn_estados_control(e.periodo) c
 where e.periodo is not null;
