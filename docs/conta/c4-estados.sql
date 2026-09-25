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
--              de la API escribe; cada cambio con rastro).
--   vistas     27 (ver el contrato, abajo).
--   funciones  del SQL Editor: fn_estados_mapeo_derivar, fn_estados_mapeo,
--              fn_estados_linea, fn_estados_config, fn_apertura_mapeo_qb,
--              fn_apertura_mapeo_trabajo, fn_apertura_balanza_cargar,
--              fn_apertura_plan, fn_apertura_revisar, fn_apertura,
--              fn_comparacion_qb_cargar, fn_diferencia_anotar,
--              fn_diferencia_retirar (y sus ayudantes internos). De la app:
--              fn_estados_control (la única con grant a authenticated).
--   NADA en el libro: ni triggers, ni índices, ni cambios en sus tablas.
--   Las huellas de c2 no cambian y no hay que resellarlas; el control
--   «permisos» de fn_verificar_cadena sigue en verde (lo mira: ninguna
--   vista sin security_invoker, ninguna función SECURITY DEFINER).
--
-- CAMBIOS A c2 Y c3: NINGUNO. (Ver «LO QUE QUEDA ABIERTO» sobre la forma de
-- las policies.)
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
-- líneas del libro), v_flujo_lineas (las que explican el dinero),
-- v_gasto_lineas (las de gasto, con su proveedor); cada una trae el
-- asiento_id de cada línea, y v_asiento_papel lleva del asiento a su papel
-- (el recibo con su foto, la factura, el cobro, la balanza de apertura…).
-- En la comparación también se baja a v_qb_balanzas (las filas de
-- QuickBooks, con su documento) y a diferencias (las anotaciones).
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
--                          flujo), sus etiquetas y sin_fila (sin fila
--                          guardada: sale con lo propuesto y
--                          fn_estados_control la dice en rojo).
--   v_estados_mapeo_propuesto  lo que se deriva de cuentas.tipo y el código.
--   v_cortes               una por período más 'hoy': desde y corte.
--   v_ejercicios           una por año: cerrado o no.
--   v_libro                una por línea del libro (asiento, papel, mapeo,
--                          ejercicio, dimensiones, tercero, partida). monto,
--                          debe y haber. Se filtra por periodo, anio,
--                          cuenta, proyecto_id… Es a donde baja todo.
--   v_mayor                v_libro + saldo corrido por cuenta (saldo,
--                          saldo_en_su_lado) y reversado. El saldo corrido
--                          se calcula con toda la historia de la cuenta y
--                          después se filtra.
--   v_asiento_papel        una por asiento: su papel (texto), papel_ruta
--                          (la foto o el PDF) y papel_existe.
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
--                          componentes del capital ('resultado' del año,
--                          'arrastre', 'por_cerrar', y 'plegado_3200' si el
--                          CPA lo pide), renglones, secciones y los totales
--                          total_activo, total_pasivo, total_capital,
--                          pasivo_mas_capital y cuadra (activo − pasivo −
--                          capital = 0.00, cuadra = true). saldo y cifra.
--   v_resultados           por cuenta, renglón, sección y las utilidades
--                          (bruta, de operación, neta): mes, mes_anterior,
--                          variacion (y %), acumulado (el año hasta el fin
--                          del período), posteriores (ajustes del CPA
--                          fechados después que corrigen hasta este período)
--                          y acumulado_ajustado. Cifras con el signo del
--                          estado (ingresos y costos en positivo; utilidad
--                          negativa = pérdida).
--   v_flujo_caja           por método ('directo', 'indirecto'): renglones,
--                          secciones, totales (efectivo_inicial, cambio,
--                          efectivo_final) y el 'control' (importe = lo que
--                          no cuadra, 0.00; cuadra = directo = indirecto =
--                          cambio del efectivo). importe en positivo =
--                          dinero que entra.
--   v_flujo_lineas         las líneas que no son dinero, con su renglón de
--                          cada método (la base de los dos flujos).
-- TABLERO
--   v_flujo_real_por_mes   una por mes empezado: efectivo_inicial, entradas,
--                          salidas, neto, efectivo_final y el neto por
--                          sección (operación, inversión, financiamiento,
--                          ajustes).
--   v_saldos_dinero        por corte, una por banco, tarjeta y línea de
--                          crédito (activa o con saldo): saldo en su lado
--                          (lo que hay; lo que se debe), saldo_inicial,
--                          cargos, abonos, ultimo_movimiento.
--   v_cxc_antiguedad       por corte, una por partida abierta de cobrar
--                          (factura, anticipo, sin partida) y el 'total':
--                          por_cobrar (1110), retencion (1120, aparte),
--                          total, d0_30…d90_mas, anticipos (en negativo),
--                          cargos, abonos, fecha, dias, tramo. El total,
--                          contra el mayor de 1110 + 1120 (cuadra).
--   v_cxp_antiguedad       lo mismo de pagar (2010 y la retención a
--                          subcontratistas, 2020), por partida o proveedor,
--                          con vence y dias_vencida (los términos del
--                          proveedor); por_pagar en positivo; a_favor.
--   v_gasto_lineas         una por línea de gasto (costo, gastos, otros
--                          gastos) con su proveedor y de dónde salió.
--   v_gasto_por_categoria  por período, una por cuenta de gasto y el total:
--                          mes, acumulado, pct.
--   v_gasto_por_proveedor  por período, una por proveedor y el total.
--   v_costo_por_obra       por período: por obra y cuenta (4xxx y 5xxx),
--                          por obra (ingresos, costo, margen) y el control
--                          por cuenta (auxiliar = mayor): del_periodo,
--                          del_anio, desde_inicio.
--   v_obras_dinero         por corte, una por obra con movimiento:
--                          facturado, cobrado, por_cobrar, retencion, costo
--                          (mano de obra, material, subcontratos), margen.
--                          (El contrato y el presupuesto viven en la app.)
-- QUICKBOOKS
--   v_qb_balanzas          las filas de QuickBooks de cada período, con su
--                          cuenta del plan y su obra (vigente = la que vale).
--   v_comparacion          por período con balanza de QuickBooks, una por
--                          cuenta (y una por cada nombre sin mapeo): libro,
--                          arrastre_apertura, comparable, qb, diferencia,
--                          explicada, sin_explicar, ok.
--   v_comparacion_obra     lo mismo por obra.
--   v_comparacion_resumen  una por período: cuentas que cuadran, lo sin
--                          explicar y la utilidad del libro contra la de
--                          QuickBooks (acumulada y del mes).
--
-- =====================================================================
-- LA APERTURA, PASO A PASO (Edgar, en el SQL Editor, cuando llegue la
-- balanza al 30-sep; ver f04)
-- =====================================================================
--   1. Sube el PDF y el CSV de la balanza a Storage (docs/apertura/…).
--   2. Cárgala: select fn_apertura_balanza_cargar('docs/apertura/balanza-2026-09-30.csv',
--        '[{"cuenta_qb": "Chase Chk 4392", "debe": "25,000.00"}, …]');
--      con la cédula donde hace falta: cuentas por cobrar factura por
--      factura (factura_id, retencion), cuentas por pagar por proveedor
--      (proveedor_qb), cuentas por obra (cliente_trabajo). Dice qué nombres
--      no tienen mapeo todavía.
--   3. Mapea cada nombre: fn_apertura_mapeo_qb('Opening Balance Equity', '3900');
--      y cada Customer:Job: fn_apertura_mapeo_trabajo('Pérez, Juan:Casa Pérez', 'casa-perez-k3m9').
--   4. Mírala: select * from fn_apertura_revisar('docs/apertura/…');
--      Para en el primer problema, con su nombre (MX001 no cuadra, MX004
--      sin mapeo, MX006 una fila que no va así, MX008 falta algo de la app).
--   5. Postéala: select fn_apertura('2026-09-30', 'docs/apertura/…');
--      Otra vez con la misma balanza: no hace nada. Con otra: dice qué
--      cambia y no toca nada; con el motivo, la sustituye.
--   6. Compárala: select * from v_comparacion where periodo = '2026-09-APERTURA';
--      todo en ok (la retención partida a 1120 ya viene anotada).
-- LAS TRAMPAS DE QUICKBOOKS, y qué hace cada una:
--   Opening Balance Equity y Retained Earnings: capital; se mapean (a 3900,
--     salvo que el CPA diga otra cosa). Sin mapeo, para y lo dice.
--   Net Income: no va en una balanza de comprobación (ya está en las
--     cuentas de resultados): si viene, la balanza no cuadra y lo dice.
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
--     retención (1120) va por obra y la cuenta por cobrar (1110) por
--     factura, con la obra de la factura.
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
--   · La apertura va por el camino 'puente' de c2 (papel = la balanza,
--     origen apertura_balanza_qb / el período de la apertura): c2 no deja
--     dos aperturas vivas, y su reverso solo lo hace fn_apertura.
--   · Cuentas por cobrar por factura y retención por obra en la apertura
--     (lo que c3 espera para aplicar los cobros de octubre). QuickBooks
--     tiene la retención dentro de A/R: esa diferencia de criterio la anota
--     fn_apertura sola en diferencias.
--   · El flujo directo, por contrapartida y sin prorratear: en cada asiento
--     que mueve dinero, cada línea que no es dinero explica su parte; como
--     el asiento suma cero, los dos métodos dan exactamente el cambio del
--     efectivo, al centavo. La apertura va en su propio renglón (ajustes).
--   · La antigüedad por la fecha del papel (factura, recibo); la de pagar
--     dice además cuándo vence por los términos del proveedor.
--   · El proveedor de un gasto: el de la línea, el del asiento (su deuda en
--     2010) o el del papel (el nombre del recibo casado con sus alias); un
--     recibo de tarjeta sin alta sale con su nombre escrito.
--   · El control no calcula lo esperado con las vistas: lee las tablas del
--     libro con el mapeo, en una pasada.
--
-- =====================================================================
-- ÍNDICES Y TIEMPOS (medidos con EXPLAIN ANALYZE en el banco de pruebas,
-- PostgreSQL 16, como la app: authenticated con la policy del libro;
-- pruebas/conta/c4-volumen.sh, período 2026-11)
-- =====================================================================
--   @@TIEMPOS@@
-- ÍNDICES: este archivo no añade ninguno al libro. Los que usan las vistas
-- ya están (asientos por período, líneas por asiento, por cuenta, por
-- partida, por obra y por tercero); los de sus propias tablas son sus
-- llaves y el de diferencias por (periodo, cuenta). Un índice por fecha en
-- asientos se midió: con estos volúmenes bajaba el flujo y el gasto un 20 a
-- 35 % y nada lo demás, y tocaría las huellas de c2: no vale todavía. Lo
-- que pesa es la policy del libro (ver abajo), no la falta de índices.
--
-- =====================================================================
-- LO QUE QUEDA ABIERTO
-- =====================================================================
--   · La policy del libro es «using (es_dueno())»: Postgres llama a
--     es_dueno() una vez POR FILA leída (~10 µs cada una). Escrita
--     «using ((select es_dueno()))» (la forma que recomienda Supabase) se
--     llama una vez por consulta: medido con 10.000 asientos, las vistas
--     bajan de 0,2–0,8 s a 0,02–0,2 s y fn_estados_control con todas las
--     vistas de 8,7 s a 1,5 s. Cambiarla toca c1, c2 y c3 (y el control
--     permisos de c2, que la exige tal cual): no se hizo aquí.
--   · fn_estados_control con TODAS las vistas pasa el tope de 8 s de la API
--     con unos 10.000 asientos (hoy no): conta.js le pasa solo las de su
--     pantalla (p_vistas).
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
--   MX003 lo importado o anotado no se edita ni se borra (se carga otro, se
--         retira)
--   MX004 una cuenta de QuickBooks sin mapeo, o mapeada a una de grupo o
--         inactiva; una cuenta que no existe
--   MX005 un monto que no es monto o con más de dos decimales
--   MX006 una fila o un mapeo que no puede ir así (sección, signo, obra,
--         factura, retención)
--   MX007 la apertura ya está con otra balanza (dice qué cambia; con
--         motivo, la sustituye); ya hay una apertura a mano
--   MX008 falta algo de la app: la factura, el proveedor, el recibo, el
--         trabajo externo, la obra, el Customer:Job, la balanza
--   42501 no es el dueño
-- =====================================================================


-- =====================================================================
-- 0 · PRECONDICIONES — solo lee. Si algo falta, no se aplica nada (el SQL
--     Editor manda todo en una sola petición: la primera excepción deshace
--     el pegado entero).
--   · El libro de c1 y c2 (con tercero y partida en las líneas) y los
--     puentes de c3 (las partidas de CxC y CxP, los cobros, los
--     proveedores y los puentes que la apertura pone al día).
--   · Si ya hay una tabla con el nombre de una de este archivo, tiene que
--     ser la de este archivo: «create table if not exists» se saltaría
--     callado una ajena y todo lo de abajo fallaría sin explicar por qué.
-- Este archivo NO toca ninguna tabla, trigger ni función que vigilan las
-- huellas de c2 (no pone triggers en el libro ni índices en sus tablas):
-- no tiene que resellarlas, y fn_verificar_cadena sigue en verde después
-- de pegarlo (su control permisos sí mira las vistas y funciones de aquí:
-- todas son security_invoker, y ninguna SECURITY DEFINER lee el libro).
-- =====================================================================
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
-- cargadas para comparar, y (salvo retirarlas) las diferencias.
create or replace function public.fn_estados_inmutable()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_table_name = 'diferencias' and tg_op = 'UPDATE'
     and (to_jsonb(new) - array['retirada_el', 'retirada_por', 'retirada_motivo'])
         = (to_jsonb(old) - array['retirada_el', 'retirada_por', 'retirada_motivo'])
     and old.retirada_el is null and new.retirada_el is not null then
    return new;  -- retirarla (fn_diferencia_retirar): lo único que se le hace
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
  if not new.efectivo
     and not exists (select 1 from estados_lineas l
                      where l.estado = 'flujo_directo' and l.linea = new.flujo_directo and l.seccion <> 'totales') then
    raise exception using errcode = 'MX006',
      message = format('La cuenta %s: «%s» no es un renglón del flujo directo (estados_lineas).', v_c.codigo, new.flujo_directo);
  end if;
  if not new.efectivo
     and not exists (select 1 from estados_lineas l
                      where l.estado = 'flujo_indirecto' and l.linea = new.flujo_indirecto and l.seccion <> 'totales') then
    raise exception using errcode = 'MX006',
      message = format('La cuenta %s: «%s» no es un renglón del flujo indirecto (estados_lineas).', v_c.codigo, new.flujo_indirecto);
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
-- (Las filas importadas de QuickBooks no se apuntan en el historial al
-- entrar: cada fila ya dice quién y cuándo la cargó; y ya no cambian.)

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
create or replace trigger trg_apertura_balanza_guarda
  before update or delete on public.apertura_balanza_qb
  for each row execute function public.fn_apertura_balanza_guarda();
create or replace trigger trg_apertura_balanza_sin_truncate
  before truncate on public.apertura_balanza_qb
  for each statement execute function public.fn_apertura_balanza_guarda();


-- ---------------------------------------------------------------------
-- 1.7 · Quién lee. El bloque fijo de todo docs/conta/c*.sql, tabla por
-- tabla: solo el dueño lee (una policy); nadie de la API escribe (todo
-- entra por las funciones); anon, nada. service_role conserva la lectura
-- (el contador de f07 lee para proponer). «revoke all» y luego «grant
-- select» (en Postgres 17 el «grant all» de Supabase incluye MAINTAIN).
-- Volver a pegar borra toda policy ajena de estas tablas.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array['estados_historial', 'estados_lineas', 'estados_mapeo', 'estados_config', 'apertura_mapeo_qb',
                           'apertura_balanza_qb', 'comparacion_qb', 'diferencias'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select on public.%I to authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl
              where pl.schemaname = 'public' and pl.tablename = t and pl.policyname <> t || '_dueno' loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('drop policy if exists %I on public.%I', t || '_dueno', t);
    execute format('create policy %I on public.%I for select to authenticated using (es_dueno())', t || '_dueno', t);
  end loop;
end $$;


-- =====================================================================
-- 2 · LOS RENGLONES, LA CONFIGURACIÓN Y EL MAPEO DE CADA CUENTA
-- =====================================================================

-- ---------------------------------------------------------------------
-- 2.0 · Los renglones de los estados (estados_lineas). Solo entra lo que
-- falta: una etiqueta que Edgar ya cambió no la pisa un segundo pegado
-- («not exists», y no solo «on conflict»: el historial no se ensucia).
-- ---------------------------------------------------------------------
insert into public.estados_lineas (estado, seccion, linea, orden, etiqueta_es, etiqueta_en)
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
  ('balance', 'activo_fijo',        'activo_fijo',              200, 'Propiedad y equipo',                                  'Property and equipment'),
  ('balance', 'activo_fijo',        'propiedad_equipo',         210, 'Propiedad y equipo, al costo',                        'Property and equipment, at cost'),
  ('balance', 'activo_fijo',        'depreciacion_acumulada',   220, 'Menos: depreciación acumulada',                       'Less: accumulated depreciation'),
  ('balance', 'otros_activos',      'otros_activos',            300, 'Otros activos',                                       'Other assets'),
  ('balance', 'otros_activos',      'accionista_por_cobrar',    310, 'Cuenta por cobrar al accionista',                     'Due from shareholder'),
  ('balance', 'otros_activos',      'depositos',                320, 'Depósitos',                                           'Deposits'),
  ('balance', 'otros_activos',      'otros_activos_varios',     330, 'Otros activos',                                       'Other assets'),
  ('balance', 'pasivo_circulante',  'pasivo_circulante',        400, 'Pasivo circulante',                                   'Current liabilities'),
  ('balance', 'pasivo_circulante',  'cuentas_por_pagar',        410, 'Cuentas por pagar',                                   'Accounts payable'),
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
  ('flujo_directo', 'financiamiento', 'financiamiento',         300, 'Actividades de financiamiento',                       'Financing activities'),
  ('flujo_directo', 'financiamiento', 'prestamos',              310, 'Préstamos',                                           'Loans'),
  ('flujo_directo', 'financiamiento', 'dueno',                  320, 'Accionista: aportaciones, préstamos y distribuciones', 'Shareholder: contributions, loans and distributions'),
  ('flujo_directo', 'ajustes',        'ajustes',                400, 'Ajustes de ejercicios anteriores y de la apertura',   'Prior-period and opening adjustments'),
  ('flujo_directo', 'totales',        'efectivo_inicial',       900, 'Efectivo al inicio',                                  'Cash at beginning of period'),
  ('flujo_directo', 'totales',        'cambio',                 910, 'Cambio en el efectivo',                               'Net change in cash'),
  ('flujo_directo', 'totales',        'efectivo_final',         920, 'Efectivo al final',                                   'Cash at end of period'),
  -- El flujo de caja, método INDIRECTO: desde la utilidad, el cambio de
  -- cada saldo que no es dinero.
  ('flujo_indirecto', 'operacion',      'operacion',            100, 'Actividades de operación',                            'Operating activities'),
  ('flujo_indirecto', 'operacion',      'resultado',            101, 'Utilidad neta del ejercicio',                         'Net income'),
  ('flujo_indirecto', 'operacion',      'resultado_anteriores', 102, 'Resultados de ejercicios anteriores asentados en el período', 'Prior-year results recorded in the period'),
  ('flujo_indirecto', 'operacion',      'no_monetario',         110, 'Depreciación y otras partidas sin dinero',            'Depreciation and other non-cash items'),
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
  ('flujo_indirecto', 'financiamiento', 'financiamiento',       300, 'Actividades de financiamiento',                       'Financing activities'),
  ('flujo_indirecto', 'financiamiento', 'fin_prestamos',        310, 'Préstamos',                                           'Loans'),
  ('flujo_indirecto', 'financiamiento', 'fin_accionista',       320, 'Préstamos del y al accionista',                       'Shareholder loans'),
  ('flujo_indirecto', 'financiamiento', 'fin_capital',          330, 'Capital aportado',                                    'Contributed capital'),
  ('flujo_indirecto', 'financiamiento', 'fin_distribuciones',   340, 'Distribuciones al accionista',                        'Shareholder distributions'),
  ('flujo_indirecto', 'ajustes',        'ajustes',              400, 'Ajustes a utilidades retenidas y a la apertura',      'Retained earnings and opening adjustments'),
  ('flujo_indirecto', 'totales',        'efectivo_inicial',     900, 'Efectivo al inicio',                                  'Cash at beginning of period'),
  ('flujo_indirecto', 'totales',        'cambio',               910, 'Cambio en el efectivo',                               'Net change in cash'),
  ('flujo_indirecto', 'totales',        'efectivo_final',       920, 'Efectivo al final',                                   'Cash at end of period')
  ) as v(estado, seccion, linea, orden, es, en)
 where not exists (select 1 from public.estados_lineas l
                    where l.estado = v.estado and l.seccion = v.seccion and l.linea = v.linea)
on conflict (estado, seccion, linea) do nothing;

insert into public.estados_config (clave, valor, notas)
select 'plegar_3200', 'no', 'Las distribuciones (3200) se enseñan aparte, las de toda la vida de la empresa. ''si'' = al cerrarse un '
                             'año se pliegan a utilidades retenidas (lo decide el CPA).'
 where not exists (select 1 from public.estados_config where clave = 'plegar_3200')
on conflict (clave) do nothing;

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
--     préstamos (25xx), accionista (1130, 2900, 3000, 3100, 3200) y los
--     ajustes (3900).
--   · Flujo indirecto (el cambio de cada saldo): por la misma familia.
-- ---------------------------------------------------------------------
drop view if exists public.v_estados_mapeo cascade;
drop view if exists public.v_estados_mapeo_propuesto cascade;
-- (Una sola lectura de cuentas, y la regla calculada sobre cada fila con
-- un LATERAL sin tablas: así el planificador la aplana dentro de quien la
-- use, y un join por cuenta va por el índice de cuentas.)
create view public.v_estados_mapeo_propuesto with (security_invoker = true) as
select c.codigo as cuenta,
       c.nombre as cuenta_nombre,
       c.nombre_en as cuenta_nombre_en,
       c.tipo as cuenta_tipo,
       c.saldo_normal,
       case when c.tipo in ('activo', 'pasivo', 'capital') then 'balance' else 'resultados' end as estado,
       d.r[1] as seccion,
       d.r[2] as linea,
       (left(c.codigo, 4)::int * 10 + case when position('-' in c.codigo) > 0 then 5 else 0 end) as orden,
       (case when d.r[1] in ('activo_circulante', 'activo_fijo', 'otros_activos', 'costo', 'gastos', 'otros_gastos')
             then 1 else -1 end)::smallint as signo,
       c.saldo_normal <> (case when d.r[1] in ('activo_circulante', 'activo_fijo', 'otros_activos', 'costo', 'gastos',
                                               'otros_gastos')
                               then 'debe' else 'haber' end) as contra,
       d.r[3] = 'efectivo' as efectivo,
       d.r[3] as flujo_directo,
       d.r[4] as flujo_indirecto
  from public.cuentas c
  cross join lateral (
    select case
             when c.tipo = 'activo' then
               case when left(c.codigo, 2) = '10' then array['activo_circulante', 'efectivo', 'efectivo', 'efectivo']
                    when left(c.codigo, 4) in ('1110', '1190') then array['activo_circulante', 'cuentas_por_cobrar', 'cobros_clientes', 'op_cxc']
                    when left(c.codigo, 4) = '1120' then array['activo_circulante', 'retencion_por_cobrar', 'cobros_clientes', 'op_cxc']
                    when left(c.codigo, 4) = '1130' then array['otros_activos', 'accionista_por_cobrar', 'dueno', 'fin_accionista']
                    when left(c.codigo, 2) = '11' then array['activo_circulante', 'cuentas_por_cobrar', 'cobros_clientes', 'op_cxc']
                    when left(c.codigo, 2) = '12' then array['activo_circulante', 'wip_activo', 'otros_operacion', 'op_wip']
                    when left(c.codigo, 2) = '13' then array['activo_circulante', 'inventario', 'proveedores', 'op_inventario']
                    when left(c.codigo, 2) = '14' then array['activo_circulante', 'prepagados', 'proveedores', 'op_prepagados']
                    when left(c.codigo, 2) = '15' and c.saldo_normal = 'haber'
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

-- Las cuentas que no tienen fila, con lo propuesto (el pegado; y otra vez,
-- sin pisar nada, cada vez que se pega).
insert into public.estados_mapeo (cuenta, estado, seccion, linea, orden, signo, contra, efectivo, flujo_directo, flujo_indirecto)
select p.cuenta, p.estado, p.seccion, p.linea, p.orden, p.signo, p.contra, p.efectivo, p.flujo_directo, p.flujo_indirecto
  from public.v_estados_mapeo_propuesto p
 where not exists (select 1 from public.estados_mapeo m where m.cuenta = p.cuenta)
 order by p.cuenta
on conflict (cuenta) do nothing;

-- ---------------------------------------------------------------------
-- 2.2 · v_estados_mapeo — lo que usan TODOS los estados: la fila de cada
-- cuenta (la guardada; si no la tiene, la propuesta, con sin_fila = true
-- para que fn_estados_control lo diga en rojo), con sus nombres, sus
-- renglones y el orden de su sección y de su renglón.
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
       coalesce(ll.etiqueta_en, coalesce(m.linea, p.linea)) as linea_en
  from public.v_estados_mapeo_propuesto p
  left join public.estados_mapeo m on m.cuenta = p.cuenta
  left join public.estados_lineas ls
         on ls.estado = coalesce(m.estado, p.estado) and ls.seccion = coalesce(m.seccion, p.seccion)
        and ls.linea = coalesce(m.seccion, p.seccion)
  left join public.estados_lineas ll
         on ll.estado = coalesce(m.estado, p.estado) and ll.seccion = coalesce(m.seccion, p.seccion)
        and ll.linea = coalesce(m.linea, p.linea);


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
select p.periodo, p.tipo, p.anio, p.desde, p.hasta as corte, p.estado, p.paralelo
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
select p.anio, p.estado = 'cerrado' as cerrado, p.cerrado_el
  from public.periodos p
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
       m.efectivo,
       m.flujo_directo,
       m.flujo_indirecto,
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
-- 5-oct, aunque se pida solo octubre).
-- ---------------------------------------------------------------------
create view public.v_mayor with (security_invoker = true) as
select v.*,
       (sum(v.monto) over w)::numeric(14,2)                                            as saldo,
       (sum(v.monto) over w * (case when v.saldo_normal = 'debe' then 1 else -1 end))::numeric(14,2) as saldo_en_su_lado,
       exists (select 1 from public.asientos r where r.reversa_a = v.asiento_id and r.camino = 'reverso') as reversado
  from public.v_libro v
window w as (partition by v.cuenta order by v.fecha, v.cadena_pos, v.orden rows between unbounded preceding and current row);

-- ---------------------------------------------------------------------
-- 3.5 · v_asiento_papel — del asiento a su PAPEL: el recibo con su foto,
-- la factura, el trabajo externo, el cobro, la nota de crédito, la
-- devolución, el mes del devengo, la balanza de apertura; o, si el asiento
-- es a mano, el documento que dice (documento_ruta). papel_existe = el papel
-- está (el recibo sigue en su tabla, la balanza tiene sus filas…): un
-- asiento de puente cuyo papel falta es un rastro roto, y se ve. Un
-- reverso lleva el papel de su original.
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
       coalesce(pp.existe, a.documento_ruta is not null) as papel_existe,
       coalesce(pp.papel, case when a.origen_tabla is null
                               then coalesce('Documento: ' || a.documento_ruta, 'Asiento a mano, sin papel')
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
    select true, 'Balanza de QuickBooks de la apertura: ' || a.documento_ruta, a.documento_ruta
     where a.origen_tabla = 'apertura_balanza_qb'
       and exists (select 1 from public.apertura_balanza_qb b where b.documento = a.documento_ruta)
    limit 1
  ) pp on true;


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
             'saldo_inicial', jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', f.filtros,
                                                 'hasta', (p.desde - 1)::text),
             'debe',          jsonb_build_object('vista', 'v_libro', 'campo', 'debe', 'signo', 1, 'filtros', f.filtros,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text),
             'haber',         jsonb_build_object('vista', 'v_libro', 'campo', 'haber', 'signo', 1, 'filtros', f.filtros,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text),
             'saldo_final',   jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', f.filtros,
                                                 'hasta', p.hasta::text))            as bajar
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
             'saldo_inicial', jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', f.filtros,
                                                 'hasta', (p.desde - 1)::text),
             'debe',          jsonb_build_object('vista', 'v_libro', 'campo', 'debe', 'signo', 1, 'filtros', f.filtros,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text),
             'haber',         jsonb_build_object('vista', 'v_libro', 'campo', 'haber', 'signo', 1, 'filtros', f.filtros,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text),
             'saldo_final',   jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', f.filtros,
                                                 'hasta', p.hasta::text))
      from f
     where f.clase <> 'cuenta'
    union all
    -- El total: en cero.
    select t.por_obra, 'total', 999999, null, null, null, null, null, 'Totales', 'Totals', null, null, null,
           t.saldo_inicial, t.debe, t.haber, t.saldo_final, null::numeric(14,2), t.asientos, null, null,
           t.saldo_inicial = 0 and t.saldo_final = 0 and t.debe = t.haber,
           jsonb_build_object(
             'saldo_inicial', jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', '{}'::jsonb,
                                                 'hasta', (p.desde - 1)::text),
             'debe',          jsonb_build_object('vista', 'v_libro', 'campo', 'debe', 'signo', 1, 'filtros', '{}'::jsonb,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text),
             'haber',         jsonb_build_object('vista', 'v_libro', 'campo', 'haber', 'signo', 1, 'filtros', '{}'::jsonb,
                                                 'desde', p.desde::text, 'hasta', p.hasta::text),
             'saldo_final',   jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'filtros', '{}'::jsonb,
                                                 'hasta', p.hasta::text))
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
--     resultado de los ejercicios ya CERRADOS (componente 'arrastre');
--   · «Resultado de ejercicios anteriores por cerrar» = el resultado de los
--     años anteriores que todavía no se cierran (componente 'por_cerrar'):
--     2026, mientras el CPA no entregue;
--   · «Resultado del ejercicio» = el resultado del año del corte, de enero
--     al corte (componente 'resultado');
--   · «Distribuciones» (3200) aparte, todas las de la vida de la empresa.
--     Si el CPA pide plegarlas (estados_config plegar_3200 = 'si'), las de
--     los ejercicios cerrados se enseñan dentro de utilidades retenidas
--     (componente 'plegado_3200', en las dos líneas, con signo contrario):
--     el total del capital no cambia, y no se postea nada.
-- Niveles: 'cuenta' y 'componente' (el detalle), 'linea' (el renglón),
-- 'seccion' (su subtotal) y 'total' (total activo, total pasivo, total
-- capital, pasivo más capital y 'cuadra', que es activo menos pasivo y
-- capital: SIEMPRE 0.00; la columna cuadra lo dice).
--   saldo  debe − haber a la fecha del corte (el del libro);
--   cifra  lo que se pinta: signo × saldo (el activo en positivo, el
--          pasivo y el capital en positivo; una contra-cuenta, restando).
-- «bajar» dice, por cada cifra, qué líneas del libro la suman (ver la
-- cabecera: una lista de filtros sobre v_libro).
-- ---------------------------------------------------------------------
drop view if exists public.v_balance_general cascade;
create view public.v_balance_general with (security_invoker = true) as
select c.periodo, c.tipo as periodo_tipo, c.corte, c.anio, x.*
  from public.v_cortes c
  cross join lateral (
    with l as materialized (
      select v.cuenta, v.estado, v.seccion, v.linea, v.signo, v.monto, v.asiento_id, v.numero, v.ejercicio
        from public.v_libro v
       where v.fecha <= c.corte
    ), cfg as materialized (
      select coalesce((select k.valor from public.estados_config k where k.clave = 'plegar_3200'), 'no') = 'si' as plegar
    ), ej as materialized (
      select e.anio, e.cerrado from public.v_ejercicios e
    ), d as materialized (
      -- El detalle: cada cuenta de balance…
      select 'cuenta'::text as nivel, l.seccion, l.linea, l.cuenta, null::text as componente, l.signo,
             sum(l.monto) as saldo, count(distinct l.asiento_id) as asientos, min(l.asiento_id::text) as asiento_min,
             min(l.numero) as numero_min,
             jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', l.signo,
                                'filtros', jsonb_build_object('cuenta', l.cuenta), 'hasta', c.corte::text) as spec
        from l
       where l.estado = 'balance'
       group by l.seccion, l.linea, l.cuenta, l.signo
      union all
      -- …y los resultados, por ejercicio: el del corte, los cerrados y los
      -- por cerrar.
      select 'componente', 'capital', r.linea_c, null, r.componente, -1::smallint,
             sum(r.monto), count(distinct r.asiento_id), min(r.asiento_id::text), min(r.numero),
             jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                                'filtros', jsonb_build_object('estado', 'resultados',
                                                              'ejercicio', jsonb_agg(distinct r.ejercicio)),
                                'hasta', c.corte::text)
        from (select l.*,
                     case when l.ejercicio = c.anio then 'resultado'
                          when coalesce(ej.cerrado, false) then 'arrastre'
                          else 'por_cerrar' end as componente,
                     case when l.ejercicio = c.anio then 'resultado_ejercicio'
                          when coalesce(ej.cerrado, false) then 'utilidades_retenidas'
                          else 'ejercicios_por_cerrar' end as linea_c
                from l left join ej on ej.anio = l.ejercicio
               where l.estado = 'resultados') r
       group by r.linea_c, r.componente
      union all
      -- Las distribuciones de los ejercicios cerrados, plegadas a
      -- utilidades retenidas (solo si el CPA lo pidió): salen de una línea y
      -- entran en la otra.
      select 'componente', 'capital', z.linea, null, 'plegado_3200', -1::smallint,
             z.s * sum(l.monto), count(distinct l.asiento_id), min(l.asiento_id::text), min(l.numero),
             jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -z.s,
                                'filtros', jsonb_build_object('linea', 'distribuciones',
                                                              'ejercicio', jsonb_agg(distinct l.ejercicio)),
                                'hasta', c.corte::text)
        from l
        join ej on ej.anio = l.ejercicio and ej.cerrado
        cross join cfg
        cross join (values ('utilidades_retenidas', 1), ('distribuciones', -1)) as z(linea, s)
       where cfg.plegar and l.estado = 'balance' and l.linea = 'distribuciones'
       group by z.linea, z.s
    ), dm as materialized (
      -- cifra = signo × saldo: la misma lista de líneas, con el signo de la
      -- cifra o con el del saldo (debe − haber).
      select d.*, jsonb_build_array(d.spec) as b_cifra,
             jsonb_build_array(jsonb_set(d.spec, '{signo}', to_jsonb((d.spec->>'signo')::int * d.signo))) as b_saldo,
             ll.orden as linea_orden, ls.orden as seccion_orden,
             coalesce(m.orden, case d.componente when 'arrastre' then 1 when 'plegado_3200' then 2 else 0 end) as orden,
             coalesce(m.etiqueta_es, case d.componente
                                       when 'arrastre'     then 'Resultados de ejercicios cerrados'
                                       when 'por_cerrar'   then 'Resultados de ejercicios anteriores por cerrar'
                                       when 'resultado'    then 'Resultado del ejercicio ' || c.anio
                                       when 'plegado_3200' then 'Distribuciones de ejercicios cerrados'
                                     end) as etiqueta_es,
             coalesce(m.etiqueta_en, case d.componente
                                       when 'arrastre'     then 'Closed-year results'
                                       when 'por_cerrar'   then 'Prior-year results not yet closed'
                                       when 'resultado'    then 'Net income for ' || c.anio
                                       when 'plegado_3200' then 'Closed-year distributions'
                                     end) as etiqueta_en
        from d
        left join public.v_estados_mapeo m on m.cuenta = d.cuenta
        left join public.estados_lineas ll on ll.estado = 'balance' and ll.seccion = d.seccion and ll.linea = d.linea
        left join public.estados_lineas ls on ls.estado = 'balance' and ls.seccion = d.seccion and ls.linea = d.seccion
    ), tot as materialized (
      select sum(dm.signo * dm.saldo) filter (where dm.seccion in ('activo_circulante', 'activo_fijo', 'otros_activos')) as activo,
             sum(dm.signo * dm.saldo) filter (where dm.seccion in ('pasivo_circulante', 'pasivo_largo_plazo'))           as pasivo,
             sum(dm.signo * dm.saldo) filter (where dm.seccion = 'capital')                                             as capital,
             (select count(distinct l.asiento_id) from l) as asientos
        from dm
    )
    select dm.nivel, dm.seccion, dm.seccion_orden, dm.linea, dm.linea_orden, dm.orden, dm.cuenta, dm.componente,
           dm.etiqueta_es, dm.etiqueta_en, dm.saldo::numeric(14,2) as saldo, (dm.signo * dm.saldo)::numeric(14,2) as cifra,
           dm.asientos, case when dm.asientos = 1 then dm.asiento_min::uuid end as asiento_id,
           case when dm.asientos = 1 then dm.numero_min end as numero, null::boolean as cuadra,
           jsonb_build_object('saldo', dm.b_saldo, 'cifra', dm.b_cifra) as bajar
      from dm
    union all
    -- El renglón: la suma de su detalle.
    select 'linea', dm.seccion, min(dm.seccion_orden), dm.linea, min(dm.linea_orden), min(dm.linea_orden), null, null,
           min(ll.etiqueta_es), min(ll.etiqueta_en), sum(dm.saldo)::numeric(14,2), sum(dm.signo * dm.saldo)::numeric(14,2),
           null::bigint, null, null, null,
           jsonb_build_object('saldo', jsonb_agg(dm.b_saldo->0 order by dm.orden, dm.cuenta, dm.componente),
                              'cifra', jsonb_agg(dm.b_cifra->0 order by dm.orden, dm.cuenta, dm.componente))
      from dm
      left join public.estados_lineas ll on ll.estado = 'balance' and ll.seccion = dm.seccion and ll.linea = dm.linea
     group by dm.seccion, dm.linea
    union all
    -- La sección: su subtotal.
    select 'seccion', dm.seccion, min(dm.seccion_orden), dm.seccion, min(dm.seccion_orden), min(dm.seccion_orden), null, null,
           min(ls.etiqueta_es), min(ls.etiqueta_en), sum(dm.saldo)::numeric(14,2), sum(dm.signo * dm.saldo)::numeric(14,2),
           null::bigint, null, null, null,
           jsonb_build_object('saldo', jsonb_agg(dm.b_saldo->0 order by dm.linea_orden, dm.orden, dm.cuenta, dm.componente),
                              'cifra', jsonb_agg(dm.b_cifra->0 order by dm.linea_orden, dm.orden, dm.cuenta, dm.componente))
      from dm
      left join public.estados_lineas ls on ls.estado = 'balance' and ls.seccion = dm.seccion and ls.linea = dm.seccion
     group by dm.seccion
    union all
    -- Los totales.
    select 'total', 'totales', 9000, t.linea, lt.orden, lt.orden, null, null, lt.etiqueta_es, lt.etiqueta_en,
           null::numeric(14,2), t.cifra::numeric(14,2), tot.asientos, null, null,
           case when t.linea = 'cuadra' then coalesce(t.cifra, 0) = 0 end,
           jsonb_build_object('cifra', t.bajar)
      from tot
      cross join lateral (values
        ('total_activo', coalesce(tot.activo, 0),
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'hasta', c.corte::text,
           'filtros', jsonb_build_object('estado', 'balance',
                                         'seccion', jsonb_build_array('activo_circulante', 'activo_fijo', 'otros_activos'))))),
        ('total_pasivo', coalesce(tot.pasivo, 0),
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
           'filtros', jsonb_build_object('estado', 'balance',
                                         'seccion', jsonb_build_array('pasivo_circulante', 'pasivo_largo_plazo'))))),
        ('total_capital', coalesce(tot.capital, 0),
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
                                              'filtros', jsonb_build_object('estado', 'balance', 'seccion', 'capital')),
                           jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
                                              'filtros', jsonb_build_object('estado', 'resultados')))),
        ('pasivo_mas_capital', coalesce(tot.pasivo, 0) + coalesce(tot.capital, 0),
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
           'filtros', jsonb_build_object('estado', 'balance',
                                         'seccion', jsonb_build_array('pasivo_circulante', 'pasivo_largo_plazo', 'capital'))),
                           jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1, 'hasta', c.corte::text,
                                              'filtros', jsonb_build_object('estado', 'resultados')))),
        ('cuadra', coalesce(tot.activo, 0) - coalesce(tot.pasivo, 0) - coalesce(tot.capital, 0),
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1, 'hasta', c.corte::text,
                                              'filtros', '{}'::jsonb)))
      ) as t(linea, cifra, bajar)
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
--                 año, el año anterior): para «mes contra mes»;
--   variacion     mes − mes_anterior;
--   acumulado     lo que va del año (YTD): de enero al último día del
--                 período, de su ejercicio;
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
      -- Los límites: el período, el anterior y el año.
      select case when p.tipo = 'anio' then make_date(p.anio - 1, 1, 1)
                  else (p.desde - interval '1 month')::date end                     as ant_desde,
             p.desde - 1                                                            as ant_hasta,
             case when p.tipo = 'anio' then p.anio - 1
                  else extract(year from (p.desde - interval '1 month'))::int end   as ant_anio,
             make_date(p.anio, 1, 1)                                                as anio_desde
    ), l as materialized (
      select v.cuenta, v.seccion, v.linea, v.signo, v.monto, v.asiento_id, v.numero, v.fecha, v.ejercicio,
             v.periodo_efectivo,
             (v.ejercicio = p.anio and v.fecha between p.desde and p.hasta)                           as en_mes,
             (v.ejercicio = k.ant_anio and v.fecha between k.ant_desde and k.ant_hasta)               as en_ant,
             (v.ejercicio = p.anio and v.fecha between k.anio_desde and p.hasta)                      as en_acum,
             (v.ejercicio = p.anio and v.fecha > p.hasta and v.tipo = 'ajuste_cpa'
              and (p.tipo = 'anio' or v.periodo_efectivo <= p.periodo))                               as en_post
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
           (g.signo * g.s_ant)::numeric(14,2)                        as mes_anterior,
           (g.signo * (g.s_mes - g.s_ant))::numeric(14,2)            as variacion,
           case when g.s_ant <> 0 then round(100 * (g.s_mes - g.s_ant) / abs(g.s_ant), 1) end as variacion_pct,
           (g.signo * g.s_acum)::numeric(14,2)                       as acumulado,
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
                                                  else jsonb_build_object('periodo_efectivo_hasta', p.periodo) end,
                               'desde', (p.hasta + 1)::text)),
             'acumulado_ajustado', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', g.signo,
                               'filtros', g.filtros || jsonb_build_object('estado', 'resultados', 'ejercicio', p.anio),
                               'desde', k.anio_desde::text, 'hasta', p.hasta::text),
                                                     jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', g.signo,
                               'filtros', g.filtros || jsonb_build_object('estado', 'resultados', 'ejercicio', p.anio,
                                                                          'tipo', 'ajuste_cpa')
                                          || case when p.tipo = 'anio' then '{}'::jsonb
                                                  else jsonb_build_object('periodo_efectivo_hasta', p.periodo) end,
                               'desde', (p.hasta + 1)::text))) as bajar
      from g, k
  ) x;


-- ---------------------------------------------------------------------
-- 4.4 · El flujo de caja, por los dos métodos, sobre las mismas líneas.
-- v_flujo_lineas — cada línea del libro que NO es dinero, con:
--   importe          −monto: lo que esa línea explica del dinero (una
--                    cuenta por cobrar que baja es dinero que entró);
--   toca_efectivo    su asiento mueve dinero (tiene una línea de una
--                    cuenta de efectivo, las 10xx);
--   linea_directo    el renglón del flujo DIRECTO: si el asiento mueve
--                    dinero, el de la cuenta (flujo_directo de su mapeo: el
--                    cobro de una factura sale en «cobros de clientes», el
--                    pago de una tarjeta en «tarjetas»); nulo si no mueve
--                    dinero; el asiento de apertura, en 'ajustes';
--   linea_indirecto  el renglón del flujo INDIRECTO: el resultado del año
--                    ('resultado'), el de un ajuste a un ejercicio anterior
--                    ('resultado_anteriores'), y en las de balance el de su
--                    mapeo (flujo_indirecto: 1110 → op_cxc, 1590 →
--                    no_monetario…); el asiento de apertura, en 'ajustes'.
-- Por qué cuadran los dos, sin prorratear un centavo: cada asiento suma
-- cero, así que en cada asiento lo que se movió en dinero es exactamente
-- −(la suma de sus líneas que no son dinero). El directo suma esas líneas
-- de los asientos que tocan dinero; el indirecto, las de todos (las de un
-- asiento sin dinero suman cero). Los dos dan el cambio del efectivo.
-- El dinero que pasa de un banco a otro (1010 → 1030) no tiene líneas aquí:
-- no cambia el efectivo.
-- ---------------------------------------------------------------------
drop view if exists public.v_flujo_lineas cascade;
create view public.v_flujo_lineas with (security_invoker = true) as
select y.*, eld.seccion as seccion_directo, eli.seccion as seccion_indirecto
  from (select x.asiento_id, x.numero, x.orden, x.fecha, x.periodo, x.periodo_efectivo, x.anio, x.ejercicio, x.tipo, x.camino,
               x.descripcion, x.origen_tabla, x.origen_id, x.cuenta, x.cuenta_nombre, x.estado, x.seccion, x.linea, x.monto,
               (-x.monto)::numeric(14,2) as importe,
               case when x.monto < 0 then 'entrada' else 'salida' end as sentido,
               x.toca_efectivo,
               case when not x.toca_efectivo then null
                    when x.tipo = 'apertura' then 'ajustes'
                    else x.flujo_directo end as linea_directo,
               case when x.tipo = 'apertura' then 'ajustes'
                    when x.estado = 'resultados' and x.ejercicio = x.anio then 'resultado'
                    when x.estado = 'resultados' then 'resultado_anteriores'
                    else x.flujo_indirecto end as linea_indirecto,
               x.proyecto_id, x.tercero_tipo, x.tercero_id, x.partida_tabla, x.partida_id
          from (select v.*,
                       -- (Partido también por fecha y período, que son los de
                       -- todo el asiento: así un filtro por fecha o período
                       -- se aplica antes de calcularlo, y no sobre todo el
                       -- libro.)
                       bool_or(v.efectivo) over (partition by v.periodo, v.fecha, v.asiento_id) as toca_efectivo
                  from public.v_libro v) x
         where not x.efectivo) y
  left join public.estados_lineas eld
         on eld.estado = 'flujo_directo' and eld.linea = y.linea_directo and eld.seccion <> 'totales'
  left join public.estados_lineas eli
         on eli.estado = 'flujo_indirecto' and eli.linea = y.linea_indirecto and eli.seccion <> 'totales';

-- ---------------------------------------------------------------------
-- v_flujo_caja — el estado de flujo de efectivo de cada período (un mes, la
-- apertura o el año), por los dos métodos (metodo 'directo' e
-- 'indirecto'), con:
--   nivel 'linea'    un renglón (cobros de clientes; cuentas por cobrar…);
--   nivel 'seccion'  operación, inversión, financiamiento y ajustes;
--   nivel 'total'    efectivo al inicio, cambio en el efectivo (la suma de
--                    los renglones del método) y efectivo al final;
--   nivel 'control'  'cuadra': el cambio del método es el cambio del
--                    efectivo (final − inicial) Y el otro método da lo
--                    mismo. importe = la diferencia (0.00), cuadra = true.
-- El efectivo es la suma de las cuentas de efectivo del mapeo (las 10xx).
-- ---------------------------------------------------------------------
drop view if exists public.v_flujo_caja cascade;
create view public.v_flujo_caja with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.desde, p.hasta, x.*
  from public.periodos p
  cross join lateral (
    with f as materialized (
      select fl.asiento_id, fl.numero, fl.importe, fl.linea_directo, fl.linea_indirecto
        from public.v_flujo_lineas fl
       where fl.fecha between p.desde and p.hasta
    ), ef as materialized (
      select coalesce(sum(v.monto) filter (where v.fecha < p.desde), 0) as inicial,
             coalesce(sum(v.monto), 0)                                  as final,
             count(distinct v.asiento_id) filter (where v.fecha >= p.desde) as asientos
        from public.v_libro v
       where v.efectivo and v.fecha <= p.hasta
    ), r as materialized (
      select 'directo'::text as metodo, f.linea_directo as linea, sum(f.importe) as importe,
             count(distinct f.asiento_id) as asientos, min(f.asiento_id::text) as asiento_min, min(f.numero) as numero_min
        from f where f.linea_directo is not null
       group by f.linea_directo
      union all
      select 'indirecto', f.linea_indirecto, sum(f.importe), count(distinct f.asiento_id), min(f.asiento_id::text), min(f.numero)
        from f
       group by f.linea_indirecto
    ), rl as materialized (
      select r.*, el.seccion, el.orden as linea_orden, es.orden as seccion_orden, el.etiqueta_es, el.etiqueta_en,
             es.etiqueta_es as seccion_es, es.etiqueta_en as seccion_en
        from r
        left join public.estados_lineas el
               on el.estado = 'flujo_' || r.metodo and el.linea = r.linea and el.seccion <> 'totales'
        left join public.estados_lineas es
               on es.estado = 'flujo_' || r.metodo and es.seccion = el.seccion and es.linea = el.seccion
    ), m as materialized (
      select mm.metodo, coalesce((select sum(rl.importe) from rl where rl.metodo = mm.metodo), 0) as cambio
        from (values ('directo'), ('indirecto')) as mm(metodo)
    )
    select rl.metodo, 'linea'::text as nivel, rl.seccion, rl.seccion_orden, rl.linea, rl.linea_orden,
           coalesce(rl.etiqueta_es, rl.linea) as etiqueta_es, coalesce(rl.etiqueta_en, rl.linea) as etiqueta_en,
           rl.importe::numeric(14,2) as importe, rl.asientos,
           case when rl.asientos = 1 then rl.asiento_min::uuid end as asiento_id,
           case when rl.asientos = 1 then rl.numero_min end as numero,
           null::boolean as cuadra,
           jsonb_build_object('importe', jsonb_build_array(jsonb_build_object(
             'vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
             'filtros', jsonb_build_object('linea_' || rl.metodo, rl.linea),
             'desde', p.desde::text, 'hasta', p.hasta::text))) as bajar
      from rl
    union all
    select rl.metodo, 'seccion', rl.seccion, min(rl.seccion_orden), rl.seccion, min(rl.seccion_orden),
           coalesce(min(rl.seccion_es), rl.seccion), coalesce(min(rl.seccion_en), rl.seccion),
           sum(rl.importe)::numeric(14,2), null, null, null, null,
           jsonb_build_object('importe', jsonb_build_array(jsonb_build_object(
             'vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
             'filtros', jsonb_build_object('linea_' || rl.metodo, jsonb_agg(rl.linea order by rl.linea)),
             'desde', p.desde::text, 'hasta', p.hasta::text)))
      from rl
     group by rl.metodo, rl.seccion
    union all
    select m.metodo, 'total', 'totales', 9000, t.linea, lt.orden, lt.etiqueta_es, lt.etiqueta_en, t.importe::numeric(14,2),
           ef.asientos, null, null, null, jsonb_build_object('importe', t.bajar)
      from m
      cross join ef
      cross join lateral (values
        ('efectivo_inicial', ef.inicial,
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                              'filtros', jsonb_build_object('efectivo', true), 'hasta', (p.desde - 1)::text))),
        ('cambio', m.cambio,
         jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                              'filtros', case when m.metodo = 'directo'
                                                              then jsonb_build_object('toca_efectivo', true)
                                                              else '{}'::jsonb end,
                                              'desde', p.desde::text, 'hasta', p.hasta::text))),
        ('efectivo_final', ef.inicial + m.cambio,
         jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                              'filtros', jsonb_build_object('efectivo', true), 'hasta', (p.desde - 1)::text),
                           jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                              'filtros', case when m.metodo = 'directo'
                                                              then jsonb_build_object('toca_efectivo', true)
                                                              else '{}'::jsonb end,
                                              'desde', p.desde::text, 'hasta', p.hasta::text)))
      ) as t(linea, importe, bajar)
      left join public.estados_lineas lt on lt.estado = 'flujo_' || m.metodo and lt.seccion = 'totales' and lt.linea = t.linea
     where ef.asientos > 0 or ef.inicial <> 0 or exists (select 1 from f)
    union all
    -- El control: el cambio de cada método contra el del efectivo, y los dos
    -- métodos entre sí. importe = lo que no cuadra (0.00).
    select m.metodo, 'control', 'totales', 9999, 'cuadra', 9999,
           'Diferencia contra el cambio del efectivo y contra el otro método (debe ser 0)',
           'Difference vs. the change in cash and vs. the other method (must be 0)',
           (m.cambio - (ef.final - ef.inicial))::numeric(14,2), null, null, null,
           m.cambio = ef.final - ef.inicial and m.cambio = (select o.cambio from m o where o.metodo <> m.metodo),
           jsonb_build_object('importe', jsonb_build_array(
             jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                'filtros', case when m.metodo = 'directo'
                                                then jsonb_build_object('toca_efectivo', true)
                                                else '{}'::jsonb end,
                                'desde', p.desde::text, 'hasta', p.hasta::text),
             jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                                'filtros', jsonb_build_object('efectivo', true), 'desde', p.desde::text, 'hasta', p.hasta::text)))
      from m, ef
     where ef.asientos > 0 or ef.inicial <> 0 or exists (select 1 from f)
  ) x;

-- ---------------------------------------------------------------------
-- 4.5 · v_flujo_real_por_mes — el dinero de verdad, mes por mes (la
-- gráfica de seis meses del Panel): una fila por mes, desde el primero con
-- dinero hasta el mes en curso (o el del último asiento, si es posterior),
-- con el efectivo al inicio, lo que entró y lo que salió (por su
-- contrapartida, como el flujo directo: un cobro de 1,000 con 30 de
-- comisión son 1,000 que entran y 30 que salen; un traspaso entre bancos no
-- es ni lo uno ni lo otro), el neto, el efectivo al final, y el neto por
-- sección del flujo directo (operación, inversión, financiamiento y
-- ajustes). entradas − salidas = neto = operacion + inversion +
-- financiamiento + ajustes = final − inicial.
-- ---------------------------------------------------------------------
drop view if exists public.v_flujo_real_por_mes cascade;
create view public.v_flujo_real_por_mes with (security_invoker = true) as
select p.periodo, p.desde, p.hasta, p.estado as periodo_estado, x.*
  from public.periodos p
  cross join lateral (
    with e as materialized (
      select coalesce(sum(v.monto) filter (where v.fecha < p.desde), 0) as inicial,
             coalesce(sum(v.monto), 0)                                  as final,
             count(distinct v.asiento_id) filter (where v.fecha >= p.desde) as asientos
        from public.v_libro v
       where v.efectivo and v.fecha <= p.hasta
    ), f as materialized (
      select fl.importe, fl.sentido, fl.seccion_directo
        from public.v_flujo_lineas fl
       where fl.fecha between p.desde and p.hasta and fl.toca_efectivo
    )
    select e.inicial::numeric(14,2)                                                                     as efectivo_inicial,
           coalesce((select sum(f.importe) from f where f.sentido = 'entrada'), 0)::numeric(14,2)        as entradas,
           coalesce((select -sum(f.importe) from f where f.sentido = 'salida'), 0)::numeric(14,2)        as salidas,
           (e.final - e.inicial)::numeric(14,2)                                                          as neto,
           e.final::numeric(14,2)                                                                        as efectivo_final,
           coalesce((select sum(f.importe) from f where f.seccion_directo = 'operacion'), 0)::numeric(14,2)      as operacion,
           coalesce((select sum(f.importe) from f where f.seccion_directo = 'inversion'), 0)::numeric(14,2)      as inversion,
           coalesce((select sum(f.importe) from f where f.seccion_directo = 'financiamiento'), 0)::numeric(14,2) as financiamiento,
           coalesce((select sum(f.importe) from f where f.seccion_directo = 'ajustes'), 0)::numeric(14,2)        as ajustes,
           e.asientos,
           jsonb_build_object(
             'efectivo_inicial', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                   'filtros', jsonb_build_object('efectivo', true), 'hasta', (p.desde - 1)::text)),
             'entradas', jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                   'filtros', jsonb_build_object('toca_efectivo', true, 'sentido', 'entrada'),
                                   'desde', p.desde::text, 'hasta', p.hasta::text)),
             'salidas', jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', -1,
                                   'filtros', jsonb_build_object('toca_efectivo', true, 'sentido', 'salida'),
                                   'desde', p.desde::text, 'hasta', p.hasta::text)),
             'neto', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                   'filtros', jsonb_build_object('efectivo', true), 'desde', p.desde::text, 'hasta', p.hasta::text)),
             'efectivo_final', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                   'filtros', jsonb_build_object('efectivo', true), 'hasta', p.hasta::text)),
             'operacion', jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                   'filtros', jsonb_build_object('toca_efectivo', true, 'seccion_directo', 'operacion'),
                                   'desde', p.desde::text, 'hasta', p.hasta::text)),
             'inversion', jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                   'filtros', jsonb_build_object('toca_efectivo', true, 'seccion_directo', 'inversion'),
                                   'desde', p.desde::text, 'hasta', p.hasta::text)),
             'financiamiento', jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                   'filtros', jsonb_build_object('toca_efectivo', true, 'seccion_directo', 'financiamiento'),
                                   'desde', p.desde::text, 'hasta', p.hasta::text)),
             'ajustes', jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                                   'filtros', jsonb_build_object('toca_efectivo', true, 'seccion_directo', 'ajustes'),
                                   'desde', p.desde::text, 'hasta', p.hasta::text))) as bajar
      from e
     where e.asientos > 0 or e.inicial <> 0
  ) x
 where p.tipo = 'mes'
   and p.desde <= greatest(public.fn_fecha_miami(now()), (select max(a.fecha_contable) from public.asientos a));


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
     where cu.activa or g.cuenta is not null
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
--                corte; tramo '0-30', '31-60', '61-90', '90+', 'anticipo'
--                o 'retencion' (si solo queda retención); d0_30…d90_mas =
--                por_cobrar en su tramo.
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
           (case when d.tramo = 'anticipo' then d.por_cobrar else 0 end)::numeric(14,2) as anticipos,
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
             'anticipos',  case when d.tramo = 'anticipo' then jsonb_build_array(d.s_cxc) else '[]'::jsonb end,
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
           coalesce(sum(d.por_cobrar) filter (where d.tramo = 'anticipo'), 0)::numeric(14,2),
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
             'anticipos',  coalesce(jsonb_agg(d.s_cxc) filter (where d.tramo = 'anticipo'), '[]'::jsonb),
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
--   fecha, dias la del papel (la de la línea más vieja si no hay) y los
--               días hasta el corte, con su tramo (como en cobrar);
--   vence       la fecha + los términos del proveedor (Net 30 → 30 días,
--               EOM → fin de mes, contado → el mismo día); nulo si los
--               términos no dicen; dias_vencida = días desde que venció.
-- La fila 'total' compara la suma con el mayor de 2010 + 2020 (cuadra).
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
             v.cuenta = any (k.ret) as es_ret
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
    ), a as materialized (
      select g.*,
             case when g.partida_tabla is not null then 'papel' when g.tercero_sin_partida is not null then 'proveedor'
                  else 'sin_partida' end as tipo,
             coalesce(case when g.partida_tabla = 'recibos' then r.fecha when g.partida_tabla = 'trabajos_externos' then te.fecha end,
                      g.primera) as fecha,
             coalesce(pv.id, pa.id, px.id, pe.id) as proveedor_id,
             case when g.partida_tabla = 'recibos' then r.num_recibo end as referencia,
             case when g.partida_tabla is null
                  then jsonb_build_object('partida_tabla', null, 'tercero_id', g.tercero_sin_partida)
                  else jsonb_build_object('partida_tabla', g.partida_tabla, 'partida_id', g.partida_id) end as filtros
        from g
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
             case when t.tt ~ '(net|neto)[[:space:]]*[0-9]{1,3}'
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
           u.referencia, u.fecha, u.dias, u.vence, c.corte - u.vence as dias_vencida, u.tramo,
           u.por_pagar::numeric(14,2) as por_pagar, u.retencion::numeric(14,2) as retencion,
           (u.por_pagar + u.retencion)::numeric(14,2) as total,
           (case when u.tramo = '0-30'  then u.por_pagar else 0 end)::numeric(14,2) as d0_30,
           (case when u.tramo = '31-60' then u.por_pagar else 0 end)::numeric(14,2) as d31_60,
           (case when u.tramo = '61-90' then u.por_pagar else 0 end)::numeric(14,2) as d61_90,
           (case when u.tramo = '90+'   then u.por_pagar else 0 end)::numeric(14,2) as d90_mas,
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
             'a_favor',   case when u.tramo = 'a_favor' then jsonb_build_array(u.s_cxp) else '[]'::jsonb end,
             'cargos',    jsonb_build_array(jsonb_set(jsonb_set(jsonb_set(u.s_cxp, '{campo}', '"haber"'), '{signo}', '1'),
                                                      '{filtros,cuenta}', to_jsonb(array[u.cxp] || u.ret))),
             'pagos',     jsonb_build_array(jsonb_set(jsonb_set(jsonb_set(u.s_cxp, '{campo}', '"debe"'), '{signo}', '1'),
                                                      '{filtros,cuenta}', to_jsonb(array[u.cxp] || u.ret)))) as bajar
      from u
    union all
    select 'total', null, null, null, null, null, null, null, null, null, null, null, null,
           coalesce(sum(u.por_pagar), 0)::numeric(14,2), coalesce(sum(u.retencion), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar + u.retencion), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar) filter (where u.tramo = '0-30'), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar) filter (where u.tramo = '31-60'), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar) filter (where u.tramo = '61-90'), 0)::numeric(14,2),
           coalesce(sum(u.por_pagar) filter (where u.tramo = '90+'), 0)::numeric(14,2),
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
--   'asiento'    el proveedor de otra línea del mismo asiento (la deuda en
--                2010 de un recibo a cuenta o de un trabajo externo);
--   'trabajo_externo' el proveedor del trabajo externo (el que le puso
--                Edgar, o el de su ayudante);
--   'recibo'     el nombre que trae el recibo, casado con proveedores_alias
--                (así «CED» y «Consolidated Electrical» son el mismo);
--   'recibo_sin_alta' el nombre del recibo, sin alta todavía (se agrupa por
--                su nombre escrito sin adornos);
--   nulo         sin proveedor (un asiento a mano, la nómina).
-- proveedor_clave agrupa: 'id:<uuid>', 'txt:<nombre>' o 'ninguno'.
-- ---------------------------------------------------------------------
drop view if exists public.v_gasto_lineas cascade;
create view public.v_gasto_lineas with (security_invoker = true) as
select y.asiento_id, y.numero, y.orden, y.fecha, y.periodo, y.anio, y.ejercicio, y.tipo, y.camino, y.descripcion,
       y.origen_tabla, y.origen_id, y.cuenta, y.cuenta_nombre, y.seccion, y.linea, y.monto,
       y.monto::numeric(14,2) as gasto,
       y.proyecto_id, y.cost_code, y.memo,
       y.proveedor_id,
       coalesce((select p.nombre from public.proveedores p where p.id = y.proveedor_id), y.recibo_texto) as proveedor,
       case when y.prov_linea is not null then 'linea'
            when y.prov_asiento is not null then 'asiento'
            when y.prov_externo is not null then 'trabajo_externo'
            when y.prov_recibo is not null then 'recibo'
            when y.recibo_clave is not null then 'recibo_sin_alta' end                    as proveedor_fuente,
       coalesce('id:' || y.proveedor_id::text, 'txt:' || y.recibo_clave, 'ninguno')      as proveedor_clave
  from (select z.*, coalesce(z.prov_linea, z.prov_asiento, z.prov_externo, z.prov_recibo) as proveedor_id
          from (select w.*,
                       -- El alias del nombre del recibo (por su índice).
                       case when w.recibo_texto is not null
                            then (select al.proveedor_id from public.proveedores_alias al
                                   where al.alias = lower(btrim(regexp_replace(w.recibo_texto, '[[:space:]]+', ' ', 'g')))) end
                         as prov_recibo,
                       nullif(regexp_replace(lower(coalesce(w.recibo_texto, '')), '[^0-9a-z]', '', 'g'), '') as recibo_clave
                  from (select x.*,
                               case when x.tercero_tipo = 'proveedor' and x.tercero_id ~ '^[0-9a-f-]{36}$'
                                    then x.tercero_id::uuid end as prov_linea,
                               case when x.prov_otra ~ '^[0-9a-f-]{36}$' then x.prov_otra::uuid end as prov_asiento,
                               -- El papel, por su llave (una búsqueda por índice por línea, solo
                               -- en las de su tabla: sin joins que el planificador pueda
                               -- convertir en un recorrido por línea).
                               case when x.origen_tabla = 'trabajos_externos' and x.origen_id ~ '^-?[0-9]{1,18}$'
                                    then (select coalesce(te.proveedor_id,
                                                          (select pe.id from public.proveedores pe where pe.externo_id = te.externo_id))
                                            from public.trabajos_externos te where te.id = x.origen_id::bigint) end as prov_externo,
                               case when x.origen_tabla = 'recibos' and x.origen_id ~ '^-?[0-9]{1,18}$'
                                    then (select nullif(btrim(r.proveedor), '') from public.recibos r
                                           where r.id = x.origen_id::bigint) end as recibo_texto
                          from (select v.*,
                                       -- El proveedor de otra línea del mismo asiento
                                       -- (partido también por período y fecha: ver
                                       -- v_flujo_lineas).
                                       max(v.tercero_id) filter (where v.tercero_tipo = 'proveedor')
                                         over (partition by v.periodo, v.fecha, v.asiento_id) as prov_otra
                                  from public.v_libro v) x
                         where x.estado = 'resultados' and x.seccion in ('costo', 'gastos', 'otros_gastos')) w) z) y;

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
-- período, lo del año y lo de toda la obra (desde_inicio: todas sus líneas
-- hasta el fin del período, de todos los años: el costo de una obra que
-- cruza de año). La obra nula = líneas de esas cuentas sin obra.
-- Niveles: 'cuenta' (obra y cuenta), 'obra' (por obra: ingresos, costo y
-- margen = ingresos − costo) y 'control' (por cuenta: la suma de todas las
-- obras contra el mayor de la cuenta; auxiliar = mayor, cuadra = true).
-- Cifras con el signo del estado de resultados (ingreso y costo en
-- positivo).
-- ---------------------------------------------------------------------
drop view if exists public.v_costo_por_obra cascade;
create view public.v_costo_por_obra with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.desde, p.hasta, x.*
  from public.periodos p
  cross join lateral (
    with l as materialized (
      select v.cuenta, v.seccion, v.signo, v.proyecto_id, v.monto, v.fecha, v.ejercicio, v.asiento_id, v.numero
        from public.v_libro v
        join public.cuentas cu on cu.codigo = v.cuenta
       where v.estado = 'resultados' and v.fecha <= p.hasta
         and (cu.regla_obra <> 'prohibida' or v.proyecto_id is not null)
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
    )
    select 'cuenta'::text as nivel, s.proyecto_id, pr.nombre as obra, pr.cliente, s.cuenta, m.etiqueta_es, m.etiqueta_en,
           s.seccion, m.orden,
           (s.signo * s.s_per)::numeric(14,2) as del_periodo, (s.signo * s.s_anio)::numeric(14,2) as del_anio,
           (s.signo * s.s_ini)::numeric(14,2) as desde_inicio,
           s.asientos, case when s.asientos = 1 then s.asiento_min::uuid end as asiento_id,
           case when s.asientos = 1 then s.numero_min end as numero,
           null::numeric(14,2) as mayor, null::boolean as cuadra,
           jsonb_build_object(
             'del_periodo',  jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', s.signo,
                               'filtros', s.filtros || jsonb_build_object('ejercicio', p.anio),
                               'desde', p.desde::text, 'hasta', p.hasta::text)),
             'del_anio',     jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', s.signo,
                               'filtros', s.filtros || jsonb_build_object('ejercicio', p.anio), 'hasta', p.hasta::text)),
             'desde_inicio', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', s.signo,
                               'filtros', s.filtros, 'hasta', p.hasta::text))) as bajar
      from s
      join public.v_estados_mapeo m on m.cuenta = s.cuenta
      left join public.proyectos pr on pr.id = s.proyecto_id
    union all
    -- Por obra: ingresos, costo y margen.
    select 'obra', s.proyecto_id, min(pr.nombre), min(pr.cliente), null, z.linea, z.linea_en, z.linea, z.orden,
           sum(case when z.linea = 'margen' then -s.s_per
                    when s.seccion = z.linea then s.signo * s.s_per else 0 end)::numeric(14,2),
           sum(case when z.linea = 'margen' then -s.s_anio
                    when s.seccion = z.linea then s.signo * s.s_anio else 0 end)::numeric(14,2),
           sum(case when z.linea = 'margen' then -s.s_ini
                    when s.seccion = z.linea then s.signo * s.s_ini else 0 end)::numeric(14,2),
           null, null, null, null::numeric(14,2), null,
           jsonb_build_object(
             'del_periodo',  jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto',
                               'signo', case when z.linea = 'margen' then -1 else s.signo end,
                               'filtros', s.filtros || jsonb_build_object('ejercicio', p.anio),
                               'desde', p.desde::text, 'hasta', p.hasta::text))
                             filter (where z.linea = 'margen' or s.seccion = z.linea),
             'del_anio',     jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto',
                               'signo', case when z.linea = 'margen' then -1 else s.signo end,
                               'filtros', s.filtros || jsonb_build_object('ejercicio', p.anio), 'hasta', p.hasta::text))
                             filter (where z.linea = 'margen' or s.seccion = z.linea),
             'desde_inicio', jsonb_agg(jsonb_build_object('vista', 'v_libro', 'campo', 'monto',
                               'signo', case when z.linea = 'margen' then -1 else s.signo end,
                               'filtros', s.filtros, 'hasta', p.hasta::text))
                             filter (where z.linea = 'margen' or s.seccion = z.linea))
      from s
      cross join (values ('ingresos', 'Revenue', 1), ('costo', 'Cost', 2), ('margen', 'Margin', 3)) as z(linea, linea_en, orden)
      left join public.proyectos pr on pr.id = s.proyecto_id
     group by s.proyecto_id, z.linea, z.linea_en, z.orden
    union all
    -- El control: auxiliar por obra = mayor, cuenta por cuenta (lo del año).
    select 'control', null, null, null, s.cuenta, min(m.etiqueta_es), min(m.etiqueta_en), min(s.seccion), min(m.orden),
           null::numeric(14,2), (min(s.signo) * sum(s.s_anio))::numeric(14,2), null::numeric(14,2), null, null, null,
           (min(s.signo) * (select coalesce(sum(v.monto), 0) from public.v_libro v
                             where v.cuenta = s.cuenta and v.ejercicio = p.anio and v.fecha <= p.hasta))::numeric(14,2),
           sum(s.s_anio) = (select coalesce(sum(v.monto), 0) from public.v_libro v
                             where v.cuenta = s.cuenta and v.ejercicio = p.anio and v.fecha <= p.hasta),
           jsonb_build_object(
             'del_anio', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', min(s.signo),
                           'filtros', jsonb_build_object('cuenta', s.cuenta, 'ejercicio', p.anio), 'hasta', p.hasta::text)),
             'mayor',    jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', min(s.signo),
                           'filtros', jsonb_build_object('cuenta', s.cuenta, 'ejercicio', p.anio), 'hasta', p.hasta::text)))
      from s
      join public.v_estados_mapeo m on m.cuenta = s.cuenta
     group by s.cuenta
  ) x;

-- ---------------------------------------------------------------------
-- 5.6 · v_obras_dinero — el dinero de cada obra a cada corte (el panel
-- «dinero por obra»), todo del libro y desde el principio de la obra:
--   facturado   el ingreso de la obra (4xxx con su obra);
--   cobrado     el dinero que entró contra sus cuentas por cobrar (1110 y
--               1120 con su obra, en asientos que mueven dinero; menos lo
--               devuelto por el banco; sin la apertura);
--   por_cobrar  su saldo en 1110 (anticipos restando) y retencion en 1120;
--   costo       su costo (5xxx con su obra), y de él mano_de_obra (50xx),
--               material (5100) y subcontratos (5200);
--   margen      facturado − costo, y margen_pct sobre lo facturado.
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
             (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'retencion_cxc') as ret
    ), l as materialized (
      select v.proyecto_id, v.cuenta, v.estado, v.seccion, v.monto, v.asiento_id
        from public.v_libro v
       where v.proyecto_id is not null and v.fecha <= c.corte
    ), cob as materialized (
      select fl.proyecto_id, sum(fl.importe) as cobrado
        from public.v_flujo_lineas fl, k
       where fl.proyecto_id is not null and fl.fecha <= c.corte and fl.toca_efectivo and fl.tipo <> 'apertura'
         and fl.cuenta in (k.cxc, k.ret)
       group by fl.proyecto_id
    ), g as materialized (
      select l.proyecto_id,
             coalesce(-sum(l.monto) filter (where l.seccion = 'ingresos'), 0)                     as facturado,
             coalesce(sum(l.monto) filter (where l.cuenta = k.cxc), 0)                            as por_cobrar,
             coalesce(sum(l.monto) filter (where l.cuenta = k.ret), 0)                            as retencion,
             coalesce(sum(l.monto) filter (where l.seccion = 'costo'), 0)                         as costo,
             coalesce(sum(l.monto) filter (where l.seccion = 'costo' and l.cuenta like '50%'), 0) as mano_de_obra,
             coalesce(sum(l.monto) filter (where l.cuenta = '5100'), 0)                           as material,
             coalesce(sum(l.monto) filter (where l.cuenta = '5200'), 0)                           as subcontratos,
             count(distinct l.asiento_id)                                                         as asientos
        from l, k
       group by l.proyecto_id
    )
    select g.proyecto_id, pr.nombre as obra, pr.cliente, pr.estado as obra_estado,
           g.facturado::numeric(14,2) as facturado, coalesce(cob.cobrado, 0)::numeric(14,2) as cobrado,
           g.por_cobrar::numeric(14,2) as por_cobrar, g.retencion::numeric(14,2) as retencion,
           g.costo::numeric(14,2) as costo, g.mano_de_obra::numeric(14,2) as mano_de_obra,
           g.material::numeric(14,2) as material, g.subcontratos::numeric(14,2) as subcontratos,
           (g.facturado - g.costo)::numeric(14,2) as margen,
           case when g.facturado <> 0 then round(100 * (g.facturado - g.costo) / g.facturado, 1) end as margen_pct,
           g.asientos,
           jsonb_build_object(
             'facturado',    jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', -1,
                               'hasta', c.corte::text,
                               'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'seccion', 'ingresos'))),
             'cobrado',      jsonb_build_array(jsonb_build_object('vista', 'v_flujo_lineas', 'campo', 'importe', 'signo', 1,
                               'hasta', c.corte::text,
                               'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'toca_efectivo', true,
                                                             'tipo_no', 'apertura', 'cuenta', jsonb_build_array(k.cxc, k.ret)))),
             'por_cobrar',   jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'hasta', c.corte::text, 'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'cuenta', k.cxc))),
             'retencion',    jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'hasta', c.corte::text, 'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'cuenta', k.ret))),
             'costo',        jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'hasta', c.corte::text, 'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'seccion', 'costo'))),
             'mano_de_obra', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                               'hasta', c.corte::text,
                               'filtros', jsonb_build_object('proyecto_id', g.proyecto_id, 'seccion', 'costo', 'cuenta_prefijo', '50'))),
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
      left join cob on cob.proyecto_id = g.proyecto_id
      left join public.proyectos pr on pr.id = g.proyecto_id
  ) x;


-- =====================================================================
-- 6 · QUICKBOOKS: LA COMPARACIÓN
-- =====================================================================

-- ---------------------------------------------------------------------
-- 6.1 · v_qb_balanzas — cada fila de QuickBooks que cuenta para comparar,
-- con la cuenta del plan a la que va (apertura_mapeo_qb) y su obra:
--   · de cada período, la balanza de comparacion_qb cargada MÁS TARDE (las
--     anteriores quedan como rastro, vigente = false);
--   · de la apertura, si no se cargó una en comparacion_qb, la balanza con
--     que se posteó el asiento de apertura vivo (fuente
--     'apertura_balanza_qb', con su asiento_id).
--   saldo       debe − haber, como en el libro;
--   cuenta      la cuenta del plan (nula = sin mapeo: v_comparacion la
--               pone en rojo);
--   proyecto_id la obra: la de la fila, la del Customer:Job mapeado o la
--               de su factura.
-- ---------------------------------------------------------------------
drop view if exists public.v_qb_balanzas cascade;
create view public.v_qb_balanzas with (security_invoker = true) as
with ap as materialized (
  -- El asiento de apertura vivo y su balanza.
  select a.id as asiento_id, a.numero, a.documento_ruta, a.periodo
    from public.asientos a
   where a.origen_tabla = 'apertura_balanza_qb' and a.tipo = 'apertura'
     and a.camino not in ('reverso', 'reverso_automatico')
     and not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino = 'reverso')
), cq as materialized (
  select q.*, q.cargado_el = max(q.cargado_el) over (partition by q.periodo) as vigente,
         dense_rank() over (partition by q.periodo order by q.cargado_el desc, q.documento desc) = 1 as ultima
    from public.comparacion_qb q
)
select cq.periodo, 'comparacion_qb'::text as fuente, cq.documento, cq.linea, cq.cuenta_qb, cq.clave, cq.cliente_trabajo,
       coalesce(cq.proyecto_id, mt.proyecto_id) as proyecto_id, cq.saldo::numeric(14,2) as saldo,
       mc.cuenta, c.tipo as cuenta_tipo, cq.ultima as vigente, null::uuid as asiento_id, null::text as numero
  from cq
  left join public.apertura_mapeo_qb mc on mc.tipo = 'cuenta' and mc.clave = cq.clave
  left join public.apertura_mapeo_qb mt on mt.tipo = 'trabajo' and mt.clave = cq.cliente_clave
  left join public.cuentas c on c.codigo = mc.cuenta
union all
select ap.periodo, 'apertura_balanza_qb', b.documento, b.linea, b.cuenta_qb, b.clave, b.cliente_trabajo,
       coalesce(b.proyecto_id, mt.proyecto_id, f.proyecto_id),
       (coalesce(b.debe, 0) - coalesce(b.haber, 0))::numeric(14,2),
       mc.cuenta, c.tipo, not exists (select 1 from public.comparacion_qb q where q.periodo = ap.periodo), ap.asiento_id, ap.numero
  from ap
  join public.apertura_balanza_qb b on b.documento = ap.documento_ruta
  left join public.apertura_mapeo_qb mc on mc.tipo = 'cuenta' and mc.clave = b.clave
  left join public.apertura_mapeo_qb mt on mt.tipo = 'trabajo' and mt.clave = b.cliente_clave
  left join public.facturas f on f.id = b.factura_id
  left join public.cuentas c on c.codigo = mc.cuenta;

-- ---------------------------------------------------------------------
-- 6.2 · v_comparacion — el libro contra QuickBooks, cuenta por cuenta, en
-- cada período que tiene una balanza de QuickBooks (la de la apertura, y
-- las que Edgar cargue: fin de octubre, noviembre, la preliminar y la
-- final de diciembre):
--   libro       el saldo del libro a la fecha del período: las cuentas de
--               balance, toda su historia; las de resultados, lo del año
--               (como la balanza de QuickBooks);
--   arrastre_apertura  solo en los períodos de 2026 posteriores a la
--               apertura: el libro empezó el 30-sep con el resultado de
--               enero a septiembre DENTRO de 3900 (la apertura es balance
--               únicamente), y QuickBooks lo sigue teniendo en cada cuenta
--               de resultados. Para comparar igual, a cada cuenta de
--               resultados se le suma lo que la balanza de apertura traía en
--               ella, y a 3900 se le resta el total. En la apertura misma
--               es al revés: las cuentas de resultados de QuickBooks se
--               comparan dentro de 3900 (como las posteó fn_apertura);
--   comparable  libro + arrastre_apertura;
--   qb          la suma de las filas de QuickBooks mapeadas a la cuenta;
--   diferencia  comparable − qb;
--   explicada   lo que explican las diferencias ANOTADAS vivas del período
--               y la cuenta (fn_diferencia_anotar), por clase (clases);
--   sin_explicar diferencia − explicada; ok = sin_explicar = 0.
-- Una fila de QuickBooks sin mapeo sale sola (cuenta nula, cuenta_qb con
-- su nombre) y en rojo. «Cero diferencias sin explicar» es la meta de cada
-- mes del paralelo.
-- ---------------------------------------------------------------------
drop view if exists public.v_comparacion cascade;
create view public.v_comparacion with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.hasta as corte, p.anio, x.*
  from public.periodos p
  cross join lateral (
    with q as materialized (
      select b.* from public.v_qb_balanzas b where b.periodo = p.periodo and b.vigente
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
      select v.cuenta, v.estado, sum(v.monto) as libro, count(distinct v.asiento_id) as asientos,
             min(v.asiento_id::text) as asiento_min, min(v.numero) as numero_min
        from public.v_libro v
       where v.fecha <= p.hasta and (v.estado = 'balance' or v.ejercicio = p.anio)
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
             coalesce(l.libro, 0) as libro,
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
    )
    select 'cuenta'::text as nivel, u.cuenta, m.cuenta_nombre, m.estado, m.orden, null::text as cuenta_qb, u.cuentas_qb,
           u.libro::numeric(14,2) as libro, u.arrastre::numeric(14,2) as arrastre_apertura,
           (u.libro + u.arrastre)::numeric(14,2) as comparable, u.qb::numeric(14,2) as qb,
           (u.libro + u.arrastre - u.qb)::numeric(14,2) as diferencia, u.explicada::numeric(14,2) as explicada,
           (u.libro + u.arrastre - u.qb - u.explicada)::numeric(14,2) as sin_explicar,
           u.libro + u.arrastre - u.qb - u.explicada = 0 as ok, u.clases, u.anotadas, u.asientos,
           case when u.asientos = 1 then u.asiento_min::uuid end as asiento_id,
           case when u.asientos = 1 then u.numero_min end as numero,
           jsonb_build_object(
             'libro', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                        'hasta', p.hasta::text,
                        'filtros', jsonb_build_object('cuenta', u.cuenta)
                                   || case when m.estado = 'resultados' then jsonb_build_object('ejercicio', p.anio)
                                           else '{}'::jsonb end)),
             'qb',    case when p.tipo = 'apertura' and u.cuenta = '3900'
                           then jsonb_build_array(
                                  jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                                    'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true, 'cuenta', '3900')),
                                  jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                                    'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true,
                                                 'cuenta_tipo_no', jsonb_build_array('activo', 'pasivo', 'capital'))))
                           when p.tipo = 'apertura' and m.estado = 'resultados' then '[]'::jsonb
                           else jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                                  'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true, 'cuenta', u.cuenta)))
                      end,
             'arrastre_apertura', case when u.arrastre = 0 then '[]'::jsonb
                                       else jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo',
                                              'signo', case when u.cuenta = '3900' then -1 else 1 end,
                                              'filtros', jsonb_build_object('fuente', 'apertura_balanza_qb',
                                                           'cuenta_tipo_no', jsonb_build_array('activo', 'pasivo', 'capital'))
                                                         || case when u.cuenta = '3900' then '{}'::jsonb
                                                                 else jsonb_build_object('cuenta', u.cuenta) end)) end,
             'explicada', jsonb_build_array(jsonb_build_object('vista', 'diferencias', 'campo', 'monto', 'signo', 1,
                            'filtros', jsonb_build_object('periodo', p.periodo, 'cuenta', u.cuenta, 'retirada_el', null))))
             as bajar
      from u
      left join public.v_estados_mapeo m on m.cuenta = u.cuenta
     where u.libro <> 0 or u.qb <> 0 or u.arrastre <> 0 or u.anotadas > 0
    union all
    -- Lo que QuickBooks trae y no está mapeado.
    select 'sin_mapeo', null, null, null, 999999, q.cuenta_qb, null, 0::numeric(14,2), 0::numeric(14,2), 0::numeric(14,2),
           sum(q.saldo)::numeric(14,2), (-sum(q.saldo))::numeric(14,2), 0::numeric(14,2), (-sum(q.saldo))::numeric(14,2), false,
           null, 0, 0, null, null,
           jsonb_build_object('qb', jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                                     'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true, 'clave', q.clave,
                                                                   'cuenta', null))))
      from q
     where q.cuenta is null
     group by q.cuenta_qb, q.clave
    having sum(q.saldo) <> 0
  ) x
 where exists (select 1 from public.v_qb_balanzas b where b.periodo = p.periodo and b.vigente);

-- ---------------------------------------------------------------------
-- 6.3 · v_comparacion_obra — lo mismo, por obra, en las cuentas que
-- QuickBooks trae por Customer:Job (o por factura, en la apertura): el
-- saldo del libro de esa cuenta en esa obra contra el de QuickBooks.
-- explicada: las diferencias anotadas con esa obra.
-- ---------------------------------------------------------------------
drop view if exists public.v_comparacion_obra cascade;
create view public.v_comparacion_obra with (security_invoker = true) as
select p.periodo, p.tipo as periodo_tipo, p.hasta as corte, x.*
  from public.periodos p
  cross join lateral (
    with q as materialized (
      select b.cuenta, b.proyecto_id, sum(b.saldo) as qb, array_agg(distinct b.cuenta_qb order by b.cuenta_qb) as cuentas_qb
        from public.v_qb_balanzas b
       where b.periodo = p.periodo and b.vigente and b.cuenta is not null and b.proyecto_id is not null
         and (p.tipo <> 'apertura' or b.cuenta_tipo in ('activo', 'pasivo', 'capital'))
       group by b.cuenta, b.proyecto_id
    ), l as materialized (
      select v.cuenta, v.proyecto_id, sum(v.monto) as libro, count(distinct v.asiento_id) as asientos,
             min(v.asiento_id::text) as asiento_min, min(v.numero) as numero_min
        from public.v_libro v
       where v.fecha <= p.hasta and (v.estado = 'balance' or v.ejercicio = p.anio)
         and v.cuenta in (select q.cuenta from q)
       group by v.cuenta, v.proyecto_id
    ), d as materialized (
      select dd.cuenta, dd.proyecto_id, sum(dd.monto) as explicada, array_agg(distinct dd.clase order by dd.clase) as clases
        from public.diferencias dd
       where dd.periodo = p.periodo and dd.retirada_el is null and dd.proyecto_id is not null
       group by dd.cuenta, dd.proyecto_id
    ), u as materialized (
      select coalesce(q.cuenta, l.cuenta) as cuenta, coalesce(q.proyecto_id, l.proyecto_id) as proyecto_id,
             coalesce(l.libro, 0) as libro, coalesce(q.qb, 0) as qb, q.cuentas_qb,
             coalesce(l.asientos, 0) as asientos, l.asiento_min, l.numero_min
        from q
        full join l on l.cuenta = q.cuenta and l.proyecto_id is not distinct from q.proyecto_id
    )
    select u.cuenta, m.cuenta_nombre, u.proyecto_id, pr.nombre as obra, u.cuentas_qb,
           u.libro::numeric(14,2) as libro, u.qb::numeric(14,2) as qb, (u.libro - u.qb)::numeric(14,2) as diferencia,
           coalesce(d.explicada, 0)::numeric(14,2) as explicada,
           (u.libro - u.qb - coalesce(d.explicada, 0))::numeric(14,2) as sin_explicar,
           u.libro - u.qb - coalesce(d.explicada, 0) = 0 as ok, d.clases, u.asientos,
           case when u.asientos = 1 then u.asiento_min::uuid end as asiento_id,
           case when u.asientos = 1 then u.numero_min end as numero,
           jsonb_build_object(
             'libro', jsonb_build_array(jsonb_build_object('vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                        'hasta', p.hasta::text,
                        'filtros', jsonb_build_object('cuenta', u.cuenta, 'proyecto_id', u.proyecto_id)
                                   || case when m.estado = 'resultados' then jsonb_build_object('ejercicio', p.anio)
                                           else '{}'::jsonb end)),
             'qb',    jsonb_build_array(jsonb_build_object('vista', 'v_qb_balanzas', 'campo', 'saldo', 'signo', 1,
                        'filtros', jsonb_build_object('periodo', p.periodo, 'vigente', true, 'cuenta', u.cuenta,
                                                      'proyecto_id', u.proyecto_id))),
             'explicada', jsonb_build_array(jsonb_build_object('vista', 'diferencias', 'campo', 'monto', 'signo', 1,
                            'filtros', jsonb_build_object('periodo', p.periodo, 'cuenta', u.cuenta, 'proyecto_id', u.proyecto_id,
                                                          'retirada_el', null)))) as bajar
      from u
      left join d on d.cuenta = u.cuenta and d.proyecto_id is not distinct from u.proyecto_id
      left join public.v_estados_mapeo m on m.cuenta = u.cuenta
      left join public.proyectos pr on pr.id = u.proyecto_id
     where u.libro <> 0 or u.qb <> 0
  ) x;

-- ---------------------------------------------------------------------
-- 6.4 · v_comparacion_resumen — una fila por período con balanza de
-- QuickBooks: cuántas cuentas cuadran, cuánto queda sin explicar, y la
-- UTILIDAD del libro contra la de QuickBooks (la del Panel: «utilidad del
-- mes contra QuickBooks»):
--   utilidad_libro / utilidad_qb        lo que va del año (con el arrastre
--                                       de la apertura en 2026);
--   utilidad_mes_libro / utilidad_mes_qb la del mes: la de QuickBooks es su
--                                       acumulado menos el del período
--                                       anterior (si ese período tiene
--                                       balanza, o es la apertura).
-- ---------------------------------------------------------------------
drop view if exists public.v_comparacion_resumen cascade;
create view public.v_comparacion_resumen with (security_invoker = true) as
with c as materialized (
  select v.periodo, v.periodo_tipo, v.corte, v.anio,
         count(*) filter (where v.nivel = 'cuenta')                                        as cuentas,
         count(*) filter (where v.ok)                                                      as cuentas_ok,
         count(*) filter (where not v.ok)                                                  as cuentas_mal,
         count(*) filter (where v.nivel = 'sin_mapeo')                                     as sin_mapeo,
         coalesce(sum(abs(v.sin_explicar)), 0)                                             as sin_explicar,
         -sum(v.comparable) filter (where v.estado = 'resultados')                         as utilidad_libro,
         -sum(v.qb) filter (where v.estado = 'resultados')                                 as utilidad_qb
    from public.v_comparacion v
   group by v.periodo, v.periodo_tipo, v.corte, v.anio
)
select c.periodo, c.periodo_tipo, c.corte, c.cuentas, c.cuentas_ok, c.cuentas_mal, c.sin_mapeo,
       c.sin_explicar::numeric(14,2) as sin_explicar, c.cuentas_mal = 0 as ok,
       coalesce(c.utilidad_libro, 0)::numeric(14,2) as utilidad_libro,
       coalesce(c.utilidad_qb, 0)::numeric(14,2)    as utilidad_qb,
       (coalesce(c.utilidad_libro, 0) - coalesce(c.utilidad_qb, 0))::numeric(14,2) as utilidad_diferencia,
       (case when c.periodo_tipo = 'mes' and ant.periodo is not null
             then coalesce(c.utilidad_libro, 0) - coalesce(ant.utilidad_libro, 0) end)::numeric(14,2) as utilidad_mes_libro,
       (case when c.periodo_tipo = 'mes' and ant.periodo is not null
             then coalesce(c.utilidad_qb, 0) - coalesce(ant.utilidad_qb, 0) end)::numeric(14,2)    as utilidad_mes_qb,
       ant.periodo as periodo_anterior,
       jsonb_build_object('detalle', jsonb_build_object('vista', 'v_comparacion', 'filtros', jsonb_build_object('periodo', c.periodo)))
         as bajar
  from c
  left join lateral (
    -- El período anterior con balanza: el mes anterior, o la apertura si
    -- es octubre. Su utilidad «comparable» de la apertura es la de enero a
    -- septiembre (la de QuickBooks, dentro de 3900).
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
                else a.utilidad_qb end as utilidad_qb
      from c a
     where a.corte = (select max(p2.hasta) from public.periodos p2
                       where p2.tipo in ('mes', 'apertura') and p2.hasta < c.corte)
       and a.periodo_tipo in ('mes', 'apertura')
       and extract(year from a.corte) = c.anio
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
-- Solo el dueño (o el SQL Editor).
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
--                    «1,234.56», «(500.00)» o número;
--   y, en la apertura, lo de la cédula: factura_id, retencion,
--   cliente_trabajo, proyecto_id, proveedor_qb, proveedor_id, recibo_id,
--   trabajo_externo_id, referencia, notas (ver apertura_balanza_qb, 1.5);
--   en la comparación: cliente_trabajo, proyecto_id.
-- Devuelve el resumen (filas, debe, haber, si cuadra) y los nombres que no
-- tienen mapeo todavía: se ven antes de apertura.
-- ---------------------------------------------------------------------
create or replace function public.fn_apertura_balanza_cargar(p_documento text, p_filas jsonb)
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
begin
  perform fn_estados_exigir_dueno();
  if coalesce(btrim(p_documento), '') = '' then
    raise exception using errcode = '22023', message = 'Falta el documento (la ruta del PDF o del CSV de la balanza en Storage).';
  end if;
  if jsonb_typeof(p_filas) is distinct from 'array' or jsonb_array_length(p_filas) = 0 then
    raise exception using errcode = '22023', message = 'Las filas llegan como una lista JSON, una por cuenta de QuickBooks.';
  end if;
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
     where k not in ('cuenta_qb', 'debe', 'haber', 'saldo', 'factura_id', 'retencion', 'cliente_trabajo', 'proyecto_id',
                     'proveedor_qb', 'proveedor_id', 'recibo_id', 'trabajo_externo_id', 'referencia', 'notas');
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
    if v_saldo is not null then
      v_debe  := greatest(v_saldo, 0);
      v_haber := greatest(-v_saldo, 0);
    end if;
    begin
      insert into apertura_balanza_qb (documento, linea, cuenta_qb, debe, haber, factura_id, retencion, cliente_trabajo,
                                       proyecto_id, proveedor_qb, proveedor_id, recibo_id, trabajo_externo_id, referencia,
                                       notas, cargado_por, cargado_rol)
      values (btrim(p_documento), v_n, btrim(v_f->>'cuenta_qb'), v_debe, v_haber, (v_f->>'factura_id')::bigint,
              fn_estados_monto(v_f->'retencion', format('Fila %s (%s), retención', v_n, v_f->>'cuenta_qb')),
              nullif(btrim(v_f->>'cliente_trabajo'), ''), nullif(btrim(v_f->>'proyecto_id'), ''),
              nullif(btrim(v_f->>'proveedor_qb'), ''), (nullif(btrim(v_f->>'proveedor_id'), ''))::uuid,
              (v_f->>'recibo_id')::bigint, (v_f->>'trabajo_externo_id')::bigint, nullif(btrim(v_f->>'referencia'), ''),
              nullif(btrim(v_f->>'notas'), ''), auth.uid(), fn_rol_llamante());
    exception
      when check_violation then
        raise exception using errcode = '22023',
          message = format('Fila %s (%s): la retención va con su factura y es positiva; un papel de la app es un recibo o un '
                           'trabajo externo, no los dos.', v_n, v_f->>'cuenta_qb');
      when invalid_text_representation or numeric_value_out_of_range then
        raise exception using errcode = '22023',
          message = format('Fila %s (%s): factura_id, recibo_id y trabajo_externo_id son números; proveedor_id, un uuid.',
                           v_n, v_f->>'cuenta_qb');
    end;
  end loop;
  return (select jsonb_build_object(
            'documento', btrim(p_documento), 'filas', count(*),
            'debe', coalesce(sum(b.debe), 0), 'haber', coalesce(sum(b.haber), 0),
            'cuadra', coalesce(sum(b.debe), 0) = coalesce(sum(b.haber), 0),
            'sin_mapeo', coalesce(jsonb_agg(distinct b.cuenta_qb) filter (
                           where coalesce(b.debe, 0) <> coalesce(b.haber, 0)
                             and not exists (select 1 from apertura_mapeo_qb m where m.tipo = 'cuenta' and m.clave = b.clave)),
                         '[]'::jsonb),
            'trabajos_sin_mapeo', coalesce(jsonb_agg(distinct b.cliente_trabajo) filter (
                           where b.cliente_clave is not null and b.proyecto_id is null
                             and not exists (select 1 from apertura_mapeo_qb m where m.tipo = 'trabajo' and m.clave = b.cliente_clave)),
                         '[]'::jsonb))
            from apertura_balanza_qb b
           where b.documento = btrim(p_documento));
end $$;
revoke execute on function public.fn_apertura_balanza_cargar(text, jsonb) from public, anon, authenticated, service_role;

create or replace function public.fn_comparacion_qb_cargar(p_periodo text, p_documento text, p_filas jsonb)
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
begin
  perform fn_estados_exigir_dueno();
  if not exists (select 1 from periodos p where p.periodo = p_periodo) then
    raise exception using errcode = '22023', message = format('No existe el período %s.', coalesce(p_periodo, '(nulo)'));
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
    insert into comparacion_qb (periodo, documento, linea, cuenta_qb, cliente_trabajo, proyecto_id, saldo, cargado_por, cargado_rol)
    values (p_periodo, btrim(p_documento), v_n, btrim(v_f->>'cuenta_qb'), nullif(btrim(v_f->>'cliente_trabajo'), ''),
            nullif(btrim(v_f->>'proyecto_id'), ''), coalesce(v_saldo, coalesce(v_debe, 0) - coalesce(v_haber, 0)),
            auth.uid(), fn_rol_llamante());
  end loop;
  return (select jsonb_build_object(
            'periodo', p_periodo, 'documento', btrim(p_documento), 'filas', count(*), 'suma', coalesce(sum(q.saldo), 0),
            'cuadra', coalesce(sum(q.saldo), 0) = 0,
            'sin_mapeo', coalesce(jsonb_agg(distinct q.cuenta_qb) filter (
                           where q.saldo <> 0
                             and not exists (select 1 from apertura_mapeo_qb m where m.tipo = 'cuenta' and m.clave = q.clave)),
                         '[]'::jsonb))
            from comparacion_qb q
           where q.periodo = p_periodo and q.documento = btrim(p_documento));
end $$;
revoke execute on function public.fn_comparacion_qb_cargar(text, text, jsonb) from public, anon, authenticated, service_role;

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
--   MX001  la balanza no cuadra (debe ≠ haber); si trae «Net Income», lo
--          dice: una balanza de comprobación ya tiene el resultado en sus
--          cuentas, y esa fila lo contaría dos veces;
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
--     factura abierta (factura_id), a 1110 con su partida facturas/<id> y la
--     obra de la factura; su retención (la columna retencion) a 1120, misma
--     partida y obra. Un saldo NEGATIVO sin factura (un crédito del cliente)
--     va a 1110 con su obra; uno POSITIVO sin factura, no (MX008): el cobro
--     de octubre no tendría a qué aplicarse;
--   · retención por cobrar (1120): por obra (la de la fila, la de su
--     Customer:Job o la de su factura), con la partida de la factura si la
--     dice;
--   · cuentas por pagar (2010): por proveedor (proveedor_id, o su nombre de
--     QuickBooks casado con proveedores_alias), con la partida del recibo o
--     del trabajo externo si la dice;
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
  v_rqb    text[] := '{}';
  v_lineas jsonb;
  v_part   jsonb;
begin
  select * into v_ap from periodos where tipo = 'apertura' order by desde limit 1;
  if not found then
    raise exception using errcode = 'MX002', message = 'No hay período de apertura en el calendario (c2).';
  end if;
  select count(*), coalesce(sum(b.debe), 0), coalesce(sum(b.haber), 0) into v_filas, v_debe, v_haber
    from apertura_balanza_qb b where b.documento = p_documento;
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
                                          where b.documento = p_documento
                                            and b.clave in ('net income', 'utilidad neta', 'net profit', 'net loss'))
                            then ' Trae «Net Income»: una balanza de comprobación ya tiene el resultado del año en sus cuentas de '
                                 'resultados, y esa fila (que viene de un balance general) lo cuenta dos veces. Quítala.'
                            else ' ¿Falta una fila, o sobra la de totales?' end);
  end if;

  -- 2. Fila por fila, en su orden; la primera que no se puede, para.
  for r in select * from apertura_balanza_qb b where b.documento = p_documento order by b.linea loop
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
        raise exception using errcode = 'MX008',
          message = format('La factura %s (fila %s, %s) no está en la app: sin ella, lo que se cobre en octubre no tiene a qué '
                           'aplicarse. Dala de alta en la app (con su fecha de QuickBooks), o quita factura_id y di su obra.',
                           r.factura_id, r.linea, r.cuenta_qb);
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
                             'cuál (factura_id). Un saldo a favor del cliente (negativo) sí va sin factura, con su obra.',
                             r.linea, r.cuenta_qb, v_saldo, coalesce(', ' || r.cliente_trabajo, ''));
        end if;
        v_raw := v_raw || jsonb_build_object('cuenta', v_cxc, 'monto', v_saldo, 'proyecto_id', v_obra, 'memo', v_memo);
      else
        v_rt := coalesce(r.retencion, 0);
        if v_rt > v_saldo then
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
          if not r.cuenta_qb = any (v_rqb) then
            v_rqb := v_rqb || r.cuenta_qb;
          end if;
        end if;
      end if;
    elsif v_m.cuenta = v_ret then
      if v_obra is null then
        raise exception using errcode = 'MX006',
          message = format('La retención por cobrar va por obra: la fila %s («%s», %s) no dice de qué obra (proyecto_id, su '
                           'Customer:Job o su factura).', r.linea, r.cuenta_qb, v_saldo);
      end if;
      v_raw := v_raw || jsonb_build_object('cuenta', v_ret, 'monto', v_saldo, 'proyecto_id', v_obra,
                                           'partida_tabla', case when r.factura_id is not null then 'facturas' end,
                                           'partida_id', r.factura_id::text, 'memo', v_memo);
    elsif v_m.cuenta = v_cxp then
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
          message = format('Las cuentas por pagar van por proveedor: la fila %s («%s», %s) no dice de quién (proveedor_qb o '
                           'proveedor_id).', r.linea, r.cuenta_qb, v_saldo);
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
                 'cuenta', v_cxp, 'monto', v_saldo, 'tercero_tipo', 'proveedor', 'tercero_id', v_prov::text,
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

  -- 3. Las líneas iguales, en una; el resultado de enero a septiembre, con
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
    'resultado_qb', jsonb_build_object('utilidad', -v_res, 'saldo_por_tipo', v_rtipo),
    'retencion_partida', jsonb_build_object('monto', v_rsplit, 'cuentas_qb', to_jsonb(v_rqb)),
    'partidas', v_part);
end $$;
revoke execute on function public.fn_apertura_plan(text) from public, anon, authenticated, service_role;

-- El plan, como tabla (para mirarlo en el SQL Editor antes de postear):
--   select * from fn_apertura_revisar('docs/apertura/balanza-2026-09-30.csv');
create or replace function public.fn_apertura_revisar(p_documento text)
returns table (orden int, cuenta text, cuenta_nombre text, debe numeric(14,2), haber numeric(14,2), obra text, partida text,
               proveedor text, memo text)
language sql
stable
set search_path = public, pg_temp
as $$
  select l.n::int, l.v->>'cuenta', c.nombre,
         greatest((l.v->>'monto')::numeric, 0)::numeric(14,2), greatest(-(l.v->>'monto')::numeric, 0)::numeric(14,2),
         l.v->>'proyecto_id', (l.v->>'partida_tabla') || '/' || (l.v->>'partida_id'), p.nombre, l.v->>'memo'
    from jsonb_array_elements(fn_apertura_plan(p_documento)->'lineas') with ordinality as l(v, n)
    left join cuentas c on c.codigo = l.v->>'cuenta'
    left join proveedores p on p.id::text = l.v->>'tercero_id'
   order by l.n
$$;
revoke execute on function public.fn_apertura_revisar(text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_apertura(fecha, documento [, motivo]) — postea el asiento de apertura
-- con la balanza «documento» (ya cargada con fn_apertura_balanza_cargar),
-- por el camino de c2 (fn_postear_interno): tipo 'apertura', camino
-- 'puente', en el período de la apertura, con su papel (origen
-- apertura_balanza_qb / el período de la apertura, documento_ruta = la
-- balanza). Idempotente:
--   · con la MISMA balanza ya en el libro: no hace nada (sin_cambios);
--   · con OTRA balanza, y ya hay apertura viva: NO la pisa. Dice qué cambia,
--     renglón por renglón, y para (MX007, sin tocar nada). Si la nueva es la
--     buena (QuickBooks corrigió septiembre), se repite con el motivo: la
--     apertura vieja se reversa y la nueva la sustituye (sustituye_a), el
--     mismo día. Con la apertura ya cerrada, c2 no deja reversarla: lo que
--     falte se corrige con un ajuste a la apertura (ajuste_cpa).
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
begin
  perform fn_estados_exigir_dueno();
  if coalesce(v_doc, '') = '' then
    raise exception using errcode = '22023', message = 'Falta el documento: la balanza de QuickBooks cargada (su ruta).';
  end if;
  -- El candado de los períodos (como los puentes: nadie cierra la apertura
  -- mientras tanto) y el de la apertura (dos a la vez, una espera).
  perform 1 from periodos for share;
  perform pg_advisory_xact_lock(820260930);
  select * into v_ap from periodos where tipo = 'apertura' order by desde limit 1;
  if not found then
    raise exception using errcode = 'MX002', message = 'No hay período de apertura en el calendario (c2).';
  end if;
  if p_fecha is distinct from v_ap.desde then
    raise exception using errcode = 'MX002',
      message = format('La apertura va fechada el día de la apertura, el %s (llegó %s).', v_ap.desde, coalesce(p_fecha::text, 'nada'));
  end if;
  -- Un asiento de apertura que no es de esta función (uno a mano): dos
  -- aperturas duplicarían los saldos.
  select string_agg(a.numero, ', ') into v_otra
    from asientos a
   where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
     and a.origen_tabla is distinct from 'apertura_balanza_qb'
     and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso');
  if v_otra is not null then
    raise exception using errcode = 'MX007',
      message = format('Ya hay un asiento de apertura a mano (%s): la apertura de la balanza lo duplicaría. Revérsalo antes '
                       '(fn_reversar, con la apertura abierta) y vuelve a correr esto.', v_otra);
  end if;

  select a.* into v_vivo
    from asientos a
   where a.origen_tabla = 'apertura_balanza_qb' and a.origen_id = v_ap.periodo
     and a.camino not in ('reverso', 'reverso_automatico')
     and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')
   order by a.cadena_pos desc
   limit 1;
  if v_vivo.id is not null and v_vivo.documento_ruta = v_doc then
    return jsonb_build_object('accion', 'sin_cambios', 'asiento', v_vivo.numero, 'id', v_vivo.id, 'documento', v_doc,
                              'mensaje', format('La apertura ya está en el libro con esta balanza (asiento %s): no se postea otra '
                                                'vez.', v_vivo.numero));
  end if;

  v_plan := fn_apertura_plan(v_doc);

  if v_vivo.id is not null then
    -- Otra balanza: qué cambia, renglón por renglón.
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
    if coalesce(btrim(p_motivo), '') = '' then
      raise exception using errcode = 'MX007',
        message = format('La apertura ya está en el libro con la balanza %s (asiento %s). La balanza %s la cambia en %s renglón(es): '
                         '%s. No se tocó nada. Si %s es la buena, repite con el motivo: select fn_apertura(%L, %L, ''motivo'');',
                         v_vivo.documento_ruta, v_vivo.numero, v_doc, v_n,
                         coalesce(left(v_lista, 900), 'ninguno (las mismas cifras)'), v_doc, v_ap.desde, v_doc),
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
             'camino', 'puente', 'tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
             'descripcion', format('Apertura al %s: balanza de QuickBooks %s', to_char(v_ap.desde, 'DD-MM-YYYY'), v_doc),
             'lineas', v_plan->'lineas',
             'origen_tabla', 'apertura_balanza_qb', 'origen_id', v_ap.periodo, 'documento_ruta', v_doc,
             'sustituye_a', v_sust,
             'procedencia', jsonb_strip_nulls(jsonb_build_object(
                              'funcion', 'fn_apertura', 'documento', v_doc, 'filas_qb', v_plan->'filas_qb',
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
    insert into diferencias (periodo, cuenta, monto, clase, explicacion, asiento_id, origen, anotado_por, anotado_rol)
    values (v_ap.periodo, v_cxc, -v_rsplit, 'criterio',
            format('La retención de las facturas abiertas (%s) viene en QuickBooks dentro de %s; el libro la parte a %s, por obra '
                   'y por factura (f04).', v_rsplit,
                   (select string_agg(e.v, ', ') from jsonb_array_elements_text(v_plan->'retencion_partida'->'cuentas_qb') e(v)),
                   v_ret),
            (v_res->>'id')::uuid, 'fn_apertura', auth.uid(), fn_rol_llamante()),
           (v_ap.periodo, v_ret, v_rsplit, 'criterio',
            format('La retención de las facturas abiertas (%s), que QuickBooks tiene dentro de cuentas por cobrar, va aquí por obra '
                   'y por factura (f04).', v_rsplit),
            (v_res->>'id')::uuid, 'fn_apertura', auth.uid(), fn_rol_llamante());
    v_dif := 2;
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
-- 8 · fn_estados_control(periodo [, vistas]) — lo que conta.js lee ANTES
-- de pintar una pantalla de cifras (la falla ruidosa de f05): una fila por
-- vista, con cuántas filas devolvió para ese período (filas) y cuántas
-- dice el libro que debía devolver (esperadas), calculadas aparte, desde
-- las tablas del libro y el mapeo, sin pasar por la vista. ok = false si la
-- vista falló (no existe, se rompió, le quitaron un permiso: el detalle
-- trae el error) o si devolvió otra cantidad (0 donde hay asientos): la
-- pantalla no dibuja ceros, dice cuál vista falló. Y una fila por cada
-- cuadre que los estados tienen que cumplir (vista = 'cuadre: …'): la
-- balanza en cero, activo = pasivo + capital, el flujo directo = el
-- indirecto = el cambio del efectivo, la antigüedad de cobrar y pagar = su
-- mayor, el auxiliar por obra = el mayor, el resultado del estado de
-- resultados = el del balance, el mapeo completo (una cuenta sin fila es un
-- error dicho) y, si el período tiene balanza de QuickBooks, nada sin
-- explicar.
--   p_vistas: las que usa la pantalla (nulo = todas). conta.js:
--   _rpc('fn_estados_control', { p_periodo: '2026-10', p_vistas: ['v_balanza', 'v_resultados'] })
-- Corre con los permisos de quien llama (no es SECURITY DEFINER): el
-- equipo no la ejecuta (42501).
-- =====================================================================
create or replace function public.fn_estados_control(p_periodo text, p_vistas text[] default null)
returns table (orden int, vista text, filas bigint, esperadas bigint, ok boolean, detalle text)
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_p      periodos;
  v_esp    jsonb;
  v_err_e  text;
  v_en     text;
  r        record;
  v_err    text;
  v_n      bigint;
  v_cuadra boolean;
  v_valor  numeric;
  v_det    text;
  v_cuad   jsonb := '[]'::jsonb;
  v_res    numeric;
  v_bal    numeric;
begin
  -- (Solo es_dueno(): fn_desde_editor no es de la API, y Postgres pide
  -- permiso sobre cada función de la expresión aunque no la llegue a
  -- evaluar. Desde el SQL Editor el usuario no es authenticated.)
  if current_user in ('authenticated', 'anon') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501', message = 'Los estados los ve solo Edgar (el dueño).';
  end if;
  select * into v_p from periodos pp where pp.periodo = p_periodo;
  if not found then
    raise exception using errcode = '22023', message = format('No existe el período %s.', coalesce(p_periodo, '(nulo)'));
  end if;

  -- 1. Lo que el libro dice que cada vista tiene que devolver, en UNA
  -- pasada por sus tablas (asiento_lineas, asientos, el mapeo), sin pasar
  -- por las vistas.
  begin
    with p as (select pp.*, make_date(pp.anio, 1, 1) as ene,
                      case when pp.tipo = 'anio' then make_date(pp.anio - 1, 1, 1)
                           else (pp.desde - interval '1 month')::date end as ad,
                      pp.desde - 1 as ah,
                      case when pp.tipo = 'anio' then pp.anio - 1
                           else extract(year from (pp.desde - interval '1 month'))::int end as aa
                 from periodos pp where pp.periodo = p_periodo),
    m as materialized (select * from v_estados_mapeo),
    k as materialized (select (select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc') as cxc,
                              (select pc.cuenta from puente_cuentas pc where pc.rol = 'retencion_cxc') as ret,
                              (select pc.cuenta from puente_cuentas pc where pc.rol = 'cxp') as cxp),
    ej as materialized (select e.anio, e.estado = 'cerrado' as cerrado from periodos e where e.tipo = 'anio'),
    l as materialized (
      select al.cuenta, al.monto, al.proyecto_id, al.cost_code, al.partida_tabla, al.partida_id, al.tercero_tipo,
             al.tercero_id, a.id as asiento_id, a.fecha_contable as fecha, a.periodo, a.tipo, a.anio,
             case when a.afecta_periodo is null then a.anio
                  else coalesce((select pa.anio from periodos pa where pa.periodo = a.afecta_periodo), a.anio) end as ejercicio,
             a.afecta_periodo, m.estado, m.seccion, m.linea, m.efectivo, m.flujo_directo, m.flujo_indirecto,
             c.regla_obra
        from asiento_lineas al
        join asientos a on a.id = al.asiento_id
        join m on m.cuenta = al.cuenta
        join cuentas c on c.codigo = al.cuenta
    ),
    lp as materialized (select l.* from l, p
                         where (p.tipo = 'anio' and l.anio = p.anio) or (p.tipo <> 'anio' and l.periodo = p.periodo)),
    b as materialized (select l.* from l, p where l.fecha <= p.hasta),
    -- el balance general
    bg as (select distinct b.seccion, b.linea, b.cuenta, null::text as comp from b where b.estado = 'balance'
           union
           select distinct 'capital', case when b.ejercicio = p.anio then 'resultado_ejercicio'
                                           when coalesce(ej.cerrado, false) then 'utilidades_retenidas'
                                           else 'ejercicios_por_cerrar' end, null,
                           case when b.ejercicio = p.anio then 'resultado' when coalesce(ej.cerrado, false) then 'arrastre'
                                else 'por_cerrar' end
             from b left join ej on ej.anio = b.ejercicio, p
            where b.estado = 'resultados'
           union
           select 'capital', z.linea, null, 'plegado_3200'
             from (values ('utilidades_retenidas'), ('distribuciones')) z(linea)
            where coalesce((select c.valor from estados_config c where c.clave = 'plegar_3200'), 'no') = 'si'
              and exists (select 1 from b join ej on ej.anio = b.ejercicio and ej.cerrado
                           where b.estado = 'balance' and b.linea = 'distribuciones')),
    -- el estado de resultados
    rc as (select distinct l.seccion, l.linea, l.cuenta
             from l, p
            where l.estado = 'resultados'
              and ((l.ejercicio = p.anio and l.fecha between p.ene and p.hasta)
                   or (l.ejercicio = p.aa and l.fecha between p.ad and p.ah)
                   or (l.ejercicio = p.anio and l.fecha > p.hasta and l.tipo = 'ajuste_cpa'
                       and (p.tipo = 'anio' or coalesce(l.afecta_periodo, l.periodo) <= p.periodo)))),
    -- el flujo
    f as (select l.*, bool_or(l.efectivo) over (partition by l.asiento_id) as toca
            from l, p where l.fecha between p.desde and p.hasta),
    fx as (select case when f.tipo = 'apertura' then 'ajustes' else f.flujo_directo end as ld,
                  case when f.tipo = 'apertura' then 'ajustes'
                       when f.estado = 'resultados' and f.ejercicio = f.anio then 'resultado'
                       when f.estado = 'resultados' then 'resultado_anteriores'
                       else f.flujo_indirecto end as li, f.toca
             from f where not f.efectivo),
    di as (select distinct 'flujo_directo' as est, fx.ld as linea from fx where fx.toca
           union
           select distinct 'flujo_indirecto', fx.li from fx),
    ds as (select distinct di.est, el.seccion from di
             left join estados_lineas el on el.estado = di.est and el.linea = di.linea and el.seccion <> 'totales'),
    ef as (select coalesce(sum(b.monto) filter (where b.fecha < p.desde), 0) as ini,
                  count(*) filter (where b.fecha >= p.desde) as n
             from b, p where b.efectivo),
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
            where b.estado = 'resultados' and (b.regla_obra <> 'prohibida' or b.proyecto_id is not null)
            group by b.proyecto_id, b.cuenta),
    -- QuickBooks
    qv as (select * from v_qb_balanzas q where q.periodo = p_periodo and q.vigente)
    select jsonb_build_object(
      'v_estados_mapeo', (select count(*) from cuentas),
      'v_cortes', 1,
      'v_libro', (select count(*) from lp),
      'v_mayor', (select count(*) from lp),
      'v_asiento_papel', (select count(distinct lp.asiento_id) from lp),
      'v_balanza', (select count(distinct b.cuenta) from b, p where b.estado = 'balance' or b.ejercicio = p.anio)
                   + (select count(distinct coalesce(ej.cerrado, false)) from b left join ej on ej.anio = b.ejercicio, p
                       where b.estado = 'resultados' and b.ejercicio <> p.anio)
                   + (select case when exists (select 1 from b) then 1 else 0 end),
      'v_balanza_obra', (select count(*) from (select distinct b.cuenta, b.proyecto_id, b.cost_code from b, p
                                                where b.estado = 'balance' or b.ejercicio = p.anio) x)
                        + (select count(distinct coalesce(ej.cerrado, false)) from b left join ej on ej.anio = b.ejercicio, p
                            where b.estado = 'resultados' and b.ejercicio <> p.anio)
                        + (select case when exists (select 1 from b) then 1 else 0 end),
      'v_balance_general', (select count(*) from bg) + (select count(distinct (bg.seccion, bg.linea)) from bg)
                           + (select count(distinct bg.seccion) from bg)
                           + (select case when exists (select 1 from bg) then 5 else 0 end),
      'v_resultados', (select count(*) from rc) + (select count(distinct (rc.seccion, rc.linea)) from rc where rc.linea <> rc.seccion)
                      + (select count(distinct rc.seccion) from rc) + (select case when exists (select 1 from rc) then 3 else 0 end),
      'v_flujo_lineas', (select count(*) from lp where not lp.efectivo),
      'v_flujo_caja', (select count(*) from di) + (select count(*) from ds)
                      + (select case when ef.n > 0 or ef.ini <> 0 or exists (select 1 from fx) then 8 else 0 end from ef),
      'v_flujo_real_por_mes', (select case when p.tipo = 'mes'
                                            and p.desde <= greatest(fn_fecha_miami(now()),
                                                                    (select max(a.fecha_contable) from asientos a))
                                            and exists (select 1 from b where b.efectivo)
                                           then 1 else 0 end from p),
      'v_saldos_dinero', (select count(*) from m join cuentas c on c.codigo = m.cuenta
                           where c.imputable and (m.efectivo or (m.estado = 'balance' and m.linea in ('tarjetas', 'linea_credito')))
                             and (c.activa or exists (select 1 from b where b.cuenta = m.cuenta))),
      'v_cxc_antiguedad', (select count(*) from cx) + (select case when exists (select 1 from b, k where b.cuenta in (k.cxc, k.ret))
                                                                   then 1 else 0 end),
      'v_cxp_antiguedad', (select count(*) from px)
                          + (select case when exists (select 1 from b, k
                                                       where b.cuenta = k.cxp or (b.estado = 'balance' and b.linea = 'retencion_por_pagar'))
                                         then 1 else 0 end),
      'v_gasto_lineas', (select count(*) from lp where lp.estado = 'resultados' and lp.seccion in ('costo', 'gastos', 'otros_gastos')),
      'v_gasto_por_categoria', (select count(*) from gc) + (select case when exists (select 1 from gc) then 1 else 0 end),
      -- (El proveedor de cada línea lo resuelve v_gasto_lineas, que se
      -- controla aparte: aquí se cuentan sus proveedores.)
      'v_gasto_por_proveedor', (select count(distinct gl.proveedor_clave)
                                       + case when count(*) > 0 then 1 else 0 end
                                  from v_gasto_lineas gl, p
                                 where gl.ejercicio = p.anio and gl.fecha between p.ene and p.hasta),
      'v_costo_por_obra', (select count(*) from co) + 3 * (select count(distinct coalesce(co.proyecto_id, '')) from co)
                          + (select count(distinct co.cuenta) from co),
      'v_obras_dinero', (select count(distinct b.proyecto_id) from b where b.proyecto_id is not null),
      'v_qb_balanzas', (select count(*) from qv),
      'v_comparacion_resumen', (select case when exists (select 1 from qv) then 1 else 0 end))
      into v_esp;
  exception when others then
    v_esp := null;
    v_err_e := format('%s: %s', sqlstate, sqlerrm);
  end;

  -- 2. Cada vista, para el período: cuántas filas, y lo que cuadra en ella.
  v_en := case when v_p.tipo = 'anio' then format('anio = %s', v_p.anio) else format('periodo = %L', v_p.periodo) end;
  for r in
    select * from (values
      (1,  'v_estados_mapeo', 'select count(*), not coalesce(bool_or(sin_fila), false), null::numeric, '
                              || 'string_agg(cuenta, '', '' order by cuenta) filter (where sin_fila) from public.v_estados_mapeo'),
      (2,  'v_cortes', 'select count(*), null::boolean, null::numeric, null::text from public.v_cortes where periodo = $1'),
      (3,  'v_libro', 'select count(*), null::boolean, null::numeric, null::text from public.v_libro where ' || v_en),
      (4,  'v_mayor', 'select count(*), null::boolean, null::numeric, null::text from public.v_mayor where ' || v_en),
      (5,  'v_asiento_papel', 'select count(*), null::boolean, null::numeric, null::text from public.v_asiento_papel where '
                              || case when v_p.tipo = 'anio' then format('extract(year from fecha) = %s', v_p.anio)
                                      else format('periodo = %L', v_p.periodo) end),
      (10, 'v_balanza', $q$ select count(*), bool_and(cuadra) filter (where nivel = 'total'), null::numeric,
                               string_agg(format('saldo final %s, debe %s, haber %s', saldo_final, debe, haber), '; ')
                                 filter (where nivel = 'total')
                          from public.v_balanza where periodo = $1 $q$),
      (11, 'v_balanza_obra', 'select count(*), null::boolean, null::numeric, null::text from public.v_balanza_obra where periodo = $1'),
      (12, 'v_balance_general', $q$ select count(*), bool_and(cuadra) filter (where nivel = 'total' and linea = 'cuadra'),
                                       coalesce(sum(cifra) filter (where nivel = 'componente' and componente = 'resultado'), 0),
                                       string_agg(format('activo − pasivo − capital = %s', cifra), '; ')
                                         filter (where nivel = 'total' and linea = 'cuadra')
                                  from public.v_balance_general where periodo = $1 $q$),
      (13, 'v_resultados', $q$ select count(*), null::boolean,
                                  coalesce(sum(acumulado) filter (where nivel = 'total' and linea = 'utilidad_neta'), 0), null::text
                             from public.v_resultados where periodo = $1 $q$),
      (14, 'v_flujo_lineas', 'select count(*), null::boolean, null::numeric, null::text from public.v_flujo_lineas where ' || v_en),
      (15, 'v_flujo_caja', $q$ select count(*), bool_and(cuadra) filter (where nivel = 'control'), null::numeric,
                                  string_agg(format('%s: diferencia %s', metodo, importe), '; ') filter (where nivel = 'control')
                             from public.v_flujo_caja where periodo = $1 $q$),
      (16, 'v_flujo_real_por_mes', 'select count(*), null::boolean, null::numeric, null::text from public.v_flujo_real_por_mes where periodo = $1'),
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
                                      string_agg(format('%s: obras %s, mayor %s', cuenta, del_anio, mayor), '; ')
                                        filter (where nivel = 'control' and not cuadra)
                                 from public.v_costo_por_obra where periodo = $1 $q$),
      (27, 'v_obras_dinero', 'select count(*), null::boolean, null::numeric, null::text from public.v_obras_dinero where periodo = $1'),
      (30, 'v_qb_balanzas', 'select count(*), null::boolean, null::numeric, null::text from public.v_qb_balanzas where periodo = $1 and vigente'),
      (31, 'v_comparacion', $q$ select count(*), bool_and(ok), null::numeric,
                                   string_agg(format('%s: %s sin explicar', coalesce(cuenta, cuenta_qb), sin_explicar), '; ')
                                     filter (where not ok)
                              from public.v_comparacion where periodo = $1 $q$),
      (32, 'v_comparacion_resumen', 'select count(*), null::boolean, null::numeric, null::text from public.v_comparacion_resumen where periodo = $1')
    ) as t(orden, vista, sql)
    where p_vistas is null or t.vista = any (p_vistas)
    order by t.orden
  loop
    orden := r.orden;
    vista := r.vista;
    v_err := null;
    v_n := null; v_cuadra := null; v_valor := null; v_det := null;
    begin
      execute r.sql using p_periodo into v_n, v_cuadra, v_valor, v_det;
    exception when others then
      v_err := format('%s: %s', sqlstate, sqlerrm);
    end;
    filas := v_n;
    -- (v_comparacion no tiene «esperadas»: la mira su cuadre, fila a fila.)
    esperadas := case when r.vista = 'v_comparacion' then v_n else (v_esp->>r.vista)::bigint end;
    ok := v_err is null and v_err_e is null and filas is not distinct from esperadas;
    detalle := case when v_err is not null then format('La vista %s falló: %s. No se pinta.', r.vista, v_err)
                    when v_err_e is not null then format('No se pudo calcular lo que el libro espera (%s): no se pinta.', v_err_e)
                    when not ok then format('La vista %s devolvió %s filas y el libro dice %s: no se pinta.', r.vista, filas,
                                            esperadas) end;
    return next;
    -- Lo que cuadra, para después.
    if v_err is null then
      if r.vista = 'v_estados_mapeo' then
        v_cuad := v_cuad || jsonb_build_object('orden', 57, 'vista', 'cuadre: mapeo completo', 'ok', coalesce(v_cuadra, true),
                                               'detalle', 'cuentas sin fila en estados_mapeo (select fn_estados_mapeo_derivar();): ' || v_det);
      elsif r.vista = 'v_balanza' then
        v_cuad := v_cuad || jsonb_build_object('orden', 50, 'vista', 'cuadre: balanza en cero', 'ok', coalesce(v_cuadra, true), 'detalle', v_det);
      elsif r.vista = 'v_balance_general' then
        v_bal := v_valor;
        v_cuad := v_cuad || jsonb_build_object('orden', 51, 'vista', 'cuadre: activo = pasivo + capital', 'ok', coalesce(v_cuadra, true),
                                               'detalle', v_det);
      elsif r.vista = 'v_resultados' then
        v_res := v_valor;
      elsif r.vista = 'v_flujo_caja' then
        v_cuad := v_cuad || jsonb_build_object('orden', 52, 'vista', 'cuadre: flujo directo = indirecto = cambio del efectivo',
                                               'ok', coalesce(v_cuadra, true), 'detalle', v_det);
      elsif r.vista = 'v_cxc_antiguedad' then
        v_cuad := v_cuad || jsonb_build_object('orden', 53, 'vista', 'cuadre: antigüedad de cobrar = mayor', 'ok', coalesce(v_cuadra, true),
                                               'detalle', v_det);
      elsif r.vista = 'v_cxp_antiguedad' then
        v_cuad := v_cuad || jsonb_build_object('orden', 54, 'vista', 'cuadre: antigüedad de pagar = mayor', 'ok', coalesce(v_cuadra, true),
                                               'detalle', v_det);
      elsif r.vista = 'v_costo_por_obra' then
        v_cuad := v_cuad || jsonb_build_object('orden', 55, 'vista', 'cuadre: auxiliar por obra = mayor', 'ok', coalesce(v_cuadra, true),
                                               'detalle', v_det);
      elsif r.vista = 'v_comparacion' then
        v_cuad := v_cuad || jsonb_build_object('orden', 58, 'vista', 'cuadre: QuickBooks sin diferencias sin explicar',
                                               'ok', coalesce(v_cuadra, true), 'detalle', v_det);
      end if;
    end if;
  end loop;
  if v_res is not null and v_bal is not null then
    v_cuad := v_cuad || jsonb_build_object('orden', 56, 'vista', 'cuadre: resultado del estado = resultado del balance',
                                           'ok', v_res = v_bal,
                                           'detalle', format('estado de resultados %s, balance %s', v_res, v_bal));
  end if;

  -- 3. Los cuadres.
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
  v text;
begin
  foreach v in array array['v_estados_mapeo_propuesto', 'v_estados_mapeo', 'v_cortes', 'v_ejercicios', 'v_libro', 'v_mayor',
                           'v_asiento_papel', 'v_balanza_base', 'v_balanza', 'v_balanza_obra', 'v_balance_general',
                           'v_resultados', 'v_flujo_lineas', 'v_flujo_caja', 'v_flujo_real_por_mes', 'v_saldos_dinero',
                           'v_cxc_antiguedad', 'v_cxp_antiguedad', 'v_gasto_lineas', 'v_gasto_por_categoria',
                           'v_gasto_por_proveedor', 'v_costo_por_obra', 'v_obras_dinero', 'v_qb_balanzas', 'v_comparacion',
                           'v_comparacion_obra', 'v_comparacion_resumen'] loop
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', v);
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
comment on view public.v_flujo_lineas        is 'c4: las líneas que explican el dinero, con su renglón del flujo directo y del indirecto.';
comment on view public.v_flujo_caja          is 'c4: el flujo de efectivo de cada período, directo e indirecto, con su cuadre contra el cambio del efectivo.';
comment on view public.v_flujo_real_por_mes  is 'c4: el dinero de cada mes: inicial, entradas, salidas, neto, final y por sección.';
comment on view public.v_saldos_dinero       is 'c4: el saldo de cada banco, tarjeta y línea de crédito a cada corte.';
comment on view public.v_cxc_antiguedad      is 'c4: lo que se cobra, partida por partida, con su antigüedad, su retención aparte y el total contra el mayor.';
comment on view public.v_cxp_antiguedad      is 'c4: lo que se paga, partida por partida y proveedor, con antigüedad, vencimiento y el total contra el mayor.';
comment on view public.v_gasto_lineas        is 'c4: cada línea de gasto con su proveedor (el de la línea, el del asiento o el del papel).';
comment on view public.v_gasto_por_categoria is 'c4: el gasto de cada período por cuenta: el mes, lo del año y su parte.';
comment on view public.v_gasto_por_proveedor is 'c4: el gasto de cada período por proveedor.';
comment on view public.v_costo_por_obra      is 'c4: ingreso, costo y margen por obra y cuenta; y el control auxiliar = mayor.';
comment on view public.v_obras_dinero        is 'c4: el dinero de cada obra a cada corte: facturado, cobrado, por cobrar, retención, costo y margen.';
comment on view public.v_qb_balanzas         is 'c4: las filas de QuickBooks de cada período, con su cuenta del plan y su obra.';
comment on view public.v_comparacion         is 'c4: el libro contra QuickBooks, cuenta por cuenta, con lo explicado y lo que falta por explicar.';
comment on view public.v_comparacion_obra    is 'c4: el libro contra QuickBooks por obra.';
comment on view public.v_comparacion_resumen is 'c4: por período con balanza de QuickBooks: cuentas que cuadran, lo sin explicar y la utilidad contra QuickBooks.';

comment on function public.fn_estados_control(text, text[])   is 'c4: lo que conta.js lee antes de pintar: filas de cada vista contra las que dice el libro, y los cuadres. ok = false no se pinta.';
comment on function public.fn_estados_mapeo_derivar()         is 'c4: da su fila de estados_mapeo a cada cuenta del plan que no la tiene (lo propuesto).';
comment on function public.fn_estados_mapeo(text, jsonb)      is 'c4: ajusta dónde sale una cuenta (sección, renglón, etiquetas, flujo), con rastro.';
comment on function public.fn_estados_linea(text, text, text, text, text, int, text) is 'c4: crea o cambia un renglón de un estado (etiquetas, orden).';
comment on function public.fn_estados_config(text, text)      is 'c4: cambia lo que decide el CPA de la presentación (plegar_3200).';
comment on function public.fn_apertura_mapeo_qb(text, text, text) is 'c4: mapea un nombre de cuenta de QuickBooks a una cuenta del plan.';
comment on function public.fn_apertura_mapeo_trabajo(text, text, text) is 'c4: mapea un Customer:Job de QuickBooks a una obra de la app.';
comment on function public.fn_apertura_balanza_cargar(text, jsonb) is 'c4: carga (o recarga, si no entró al libro) la balanza de QuickBooks de la apertura.';
comment on function public.fn_apertura_plan(text)             is 'c4: arma el asiento de apertura de una balanza sin postearlo; para en el primer problema, con su nombre.';
comment on function public.fn_apertura_revisar(text)          is 'c4: el plan de la apertura como tabla, para mirarlo antes.';
comment on function public.fn_apertura(date, text, text)      is 'c4: postea la apertura con una balanza de QuickBooks; idempotente; otra balanza dice qué cambia y no pisa (con motivo, la sustituye).';
comment on function public.fn_comparacion_qb_cargar(text, text, jsonb) is 'c4: carga la balanza de QuickBooks de un período para compararla con el libro.';
comment on function public.fn_diferencia_anotar(text, text, text, text, text, text, uuid) is 'c4: anota una diferencia explicada entre el libro y QuickBooks.';
comment on function public.fn_diferencia_retirar(uuid, text)  is 'c4: retira una diferencia anotada, con su motivo (queda el rastro).';


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
    ('vistas', (select count(*) = 27 from pg_class v
                 where v.relnamespace = 'public'::regnamespace and v.relkind = 'v'
                   and 'security_invoker=true' = any (coalesce(v.reloptions, '{}'))
                   and v.relname in ('v_estados_mapeo_propuesto', 'v_estados_mapeo', 'v_cortes', 'v_ejercicios', 'v_libro',
                                      'v_mayor', 'v_asiento_papel', 'v_balanza_base', 'v_balanza', 'v_balanza_obra',
                                      'v_balance_general', 'v_resultados', 'v_flujo_lineas', 'v_flujo_caja',
                                      'v_flujo_real_por_mes', 'v_saldos_dinero', 'v_cxc_antiguedad', 'v_cxp_antiguedad',
                                      'v_gasto_lineas', 'v_gasto_por_categoria', 'v_gasto_por_proveedor', 'v_costo_por_obra',
                                      'v_obras_dinero', 'v_qb_balanzas', 'v_comparacion', 'v_comparacion_obra',
                                      'v_comparacion_resumen')),
     '27 vistas, todas security_invoker, solo SELECT para authenticated'),
    ('mapeo', not exists (select 1 from public.v_estados_mapeo m where m.sin_fila),
     (select format('%s cuentas con su fila; sin fila: %s', count(*) filter (where not m.sin_fila),
                    coalesce(string_agg(m.cuenta, ', ') filter (where m.sin_fila), 'ninguna'))
        from public.v_estados_mapeo m)),
    ('apertura', exists (select 1 from public.asientos a where a.tipo = 'apertura'
                          and a.camino not in ('reverso', 'reverso_automatico')
                          and not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino = 'reverso')),
     coalesce((select format('asiento %s con %s', a.numero, coalesce(a.documento_ruta, 'un asiento a mano'))
                 from public.asientos a
                where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                  and not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino = 'reverso')
                order by a.cadena_pos desc limit 1),
              'todavía no: carga la balanza (fn_apertura_balanza_cargar), mapea sus cuentas (fn_apertura_mapeo_qb) y '
              'select fn_apertura(''2026-09-30'', ''<documento>'');'))
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
