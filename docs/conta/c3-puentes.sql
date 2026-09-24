-- =====================================================================
-- C3 · Los puentes — Max Power Electrical Solutions, Inc.
-- Supabase → SQL Editor. Se pega ENTERO, de una vez, DESPUÉS de
-- c1-plan-de-cuentas.sql y c2-libro.sql (la versión con tercero y
-- partida en las líneas). Idempotente: se puede pegar dos veces seguidas
-- sin error y sin duplicar nada. Después se pega c3-pruebas.sql.
--
-- Aquí lo que la cuadrilla y Edgar ya capturan en la obra (recibos,
-- trabajos externos, facturas, horas) se vuelve asiento solo, y se decide
-- DE DÓNDE SALE CADA DÓLAR. La app de obra sigue funcionando igual: nadie
-- tiene que tocar nada distinto en el teléfono. Lo único que cambia a
-- propósito: un papel que ya está en el libro no se borra (lo dice el
-- mensaje, en español, con lo que hay que hacer).
--
-- DOS BLOQUES, separados por la línea «-- ==== BLOQUE B ====», como c2:
--   A · Las tablas, las columnas nuevas, las reglas en borrador, las
--       vistas y unas funciones MÍNIMAS (sin controles). Existen para
--       probar en rojo: con solo el bloque A, c3-pruebas.sql falla porque
--       los puentes no postean y los ataques ENTRAN, no porque falte algo.
--   B · Los controles: las guardas de cada papel, los puentes, los
--       cobros, las notas de crédito, las horas, el verificador y el sello.
-- EL ROJO SE CORRE SOLO EN EL BANCO DE PRUEBAS. En Supabase este archivo
-- se pega SIEMPRE entero.
--
-- =====================================================================
-- EL CONTRATO DE LOS PUENTES (lo siguen todos)
-- =====================================================================
--  1. UN PAPEL, UN ASIENTO VIVO. Cada asiento de puente dice de qué papel
--     sale (origen_tabla, origen_id) y el libro no deja dos vivos del mismo
--     (c2, 23505). Correr un puente dos veces no duplica: el puente guarda
--     en la procedencia la FIRMA del papel (md5 de los campos que usó) y,
--     si el papel no cambió, no hace nada. Los reglas (mapeos) que cambian
--     después NO rehacen lo ya contabilizado: eso solo pasa si el papel
--     cambia o si Edgar lo pide (fn_puentes_rehacer). Rehacer es SIEMPRE
--     reverso + asiento nuevo: si con las reglas de hoy el papel no se
--     contabiliza (una regla en borrador, una factura anulada), no se toca
--     nada y se dice por qué (MX008); nunca queda un reverso suelto.
--  2. CUÁNDO SE CONTABILIZA. En cuanto el papel queda COMPLETO, por un
--     trigger AFTER DIFERIDO de su tabla: corre al confirmar la transacción
--     que lo guarda, con el papel ya como quedó (si la lectura lo escribe en
--     varios pasos en la misma transacción, entra una vez, sin reversos de
--     paso). Quien lo guardó queda en el asiento (usuario_id y rol_bd). Si
--     algo falta (un mapeo, la tarjeta, el proveedor, la obra),
--     el papel se guarda igual — la app nunca falla por el libro — y queda
--     en la bandeja (puentes_bandeja) con el motivo en llano. El trigger
--     atrapa cualquier error del libro por la misma razón: el papel entra,
--     el error queda en la bandeja. Lo pendiente se reintenta con
--     fn_puentes_correr() (el botón «reintentar puente»).
--       · recibos: cuando sale de 'por_leer' (lo leyó la rutina o Edgar
--         le puso el total) y está 'leido' o 'conciliado', con total
--         distinto de cero, fecha, categoría con cuenta, forma de pago
--         resuelta y, si la cuenta la exige, obra. 'por_leer' sin total (o
--         con total) espera: la lectura no ha terminado y lo que cambie
--         mientras se lee no debe dejar reversos. 'sin_foto' (dictado sin
--         papel) espera la foto: todo número llega a su papel. La forma de
--         pago la trae la LECTURA (la app no tiene dónde escribirla): un
--         total tecleado con ✎ o una compra anotada a mano quedan sin
--         ella. Entonces va a cuenta de su proveedor si ese proveedor
--         tiene términos (f03: «o derivada de proveedores.terminos», y la
--         procedencia lo dice); si no, espera en la bandeja con el SQL
--         exacto para escribirla.
--       · trabajos_externos: al anotarse (la app los guarda completos).
--       · facturas: al existir con número, fecha, monto y obra. La tabla
--         no tenía estado: se le pone 'emitida' por omisión (como nacen
--         hoy, desde QuickBooks por la función qb, ya emitidas), y
--         'borrador' queda para la facturación propia de f10.
--       · cobros: al registrarlos (fn_cobro_registrar; f06 los creará desde
--         el banco).
--       · horas: NUNCA postean dinero. Son la clave de reparto (aprobadas
--         por Edgar). Lo único posible es el devengo estándar reversible de
--         cierre (fn_horas_devengar), etiquetado así.
--  3. SI EL PAPEL CAMBIA DESPUÉS DE CONTABILIZADO, el libro no se edita:
--       · recibos y trabajos externos: REVERSO + ASIENTO NUEVO, solos. El
--         nuevo dice a cuál sustituye (sustituye_a) y el reverso dice qué
--         cambió («total 243.57 → 245.37»). Así el ✎ de Edgar sigue
--         funcionando igual, y el rastro queda enlazado y sellado. Si la
--         fecha del papel pasa a otro año (el ticket del 20-dic que era
--         del 4-ene), el asiento nuevo es normal en su año: el gasto es de
--         enero (c2, B.8 paso 5).
--       · Solo queda el reverso, sin asiento nuevo, cuando el papel deja
--         de contar POR SÍ MISMO: anulado, en total 0, de antes del corte,
--         o ya dentro de la apertura. Si lo que falta es una REGLA o un
--         dato (el proveedor escrito con otro nombre, una categoría o una
--         forma de pago que el mapeo no conoce, una duda de la bandeja),
--         el asiento vivo SE QUEDA como estaba —la deuda y el costo siguen
--         siendo reales— y el papel sale en la bandeja como aviso; cuando
--         se resuelve, el puente pone el reverso y el asiento nuevo juntos.
--         Y si el asiento vivo usa una cuenta que ya está inactiva, tampoco
--         se reversa: el saldo quedaría atrapado en ella (c1).
--       · facturas: BLOQUEO con mensaje. Una factura emitida es un papel
--         que ya tiene el cliente: su monto, fecha, obra, número y
--         retención no cambian; se anula con NOTA DE CRÉDITO enlazada
--         (fn_factura_anular) y se hace la buena. Pagada, cobrado,
--         cobrada_el, el enlace de pago y lo de QuickBooks siguen libres.
--  4. ANULADO → REVERSO. Un recibo 'anulado' (o en total 0) se reversa. Un
--     trabajo externo se anula con fn_externo_anular (su costo queda en 0).
--     Un cobro, con fn_cobro_anular. Un recibo anulado NO vuelve con un
--     update cualquiera: el ✎ de la app le manda estado = 'leido' con la
--     nota que Edgar le apunta, y eso lo metía otra vez al libro sin que
--     nadie lo pidiera. La guarda lo deja anulado (la nota y el proveedor
--     sí se guardan); se des-anula a propósito, con su motivo, con
--     fn_recibo_desanular(id, motivo).
--  5. BORRAR un papel que está (o estuvo) en el libro → BLOQUEADO (MX003),
--     con el mensaje de qué hacer, que depende de POR QUÉ está: con su
--     asiento vivo (un recibo se anula con fn_recibo_anular, que también
--     lo saca de las listas de la app; un trabajo externo con
--     fn_externo_anular); con su asiento ya reversado (es el rastro del
--     reverso: no suma nada; si la app todavía lo enseña, se anula);
--     o porque otro asiento lo nombra como partida (la apertura: ponerlo en
--     0 no la toca; se corrige la apertura con un ajuste). Una obra con
--     papeles contabilizados tampoco se borra (se marca Completado). Un
--     papel que nunca entró al libro se borra como siempre, y sale de la
--     bandeja.
--  6. GUARDARRAÍL DEL CORTE: nada fechado antes del 1-oct-2026 (el día
--     después de la apertura) postea por puente: eso ya está en
--     QuickBooks, y entra en la apertura (f04). Pero un recibo o un
--     trabajo externo fechado antes del corte y SUBIDO después (un año mal
--     leído, un ticket de septiembre que llegó tarde, cuando QuickBooks ya
--     cerró el mes) no se calla: espera en la bandeja
--     (fecha_antes_del_corte) hasta que Edgar corrige la fecha o confirma
--     que es de antes del corte y está en QuickBooks
--     (fn_puentes_antes_del_corte). Si la apertura ya lo nombra, está en
--     QuickBooks y no se pregunta.
--     Y un recibo SUBIDO antes del corte es de antes del corte, diga lo que
--     diga la lectura: un ticket no es de después del día en que se
--     fotografió (el «08/10» del 10 de agosto leído como 8 de octubre).
--     Vive en QuickBooks aunque su fecha leída sea de octubre, y el
--     backfill tampoco lo mete. Un recibo subido desde el corte con una
--     fecha leída POSTERIOR al día en que se subió (más de un día) se
--     pregunta: fecha_posterior_a_subida (punto 15).
--     Y UN PAPEL QUE YA ESTÁ EN LA APERTURA no entra otra vez por su puente
--     (si su fecha cambia al corte o después, espera en la bandeja:
--     en_apertura). Las facturas no tienen hora de subida: el guardarraíl
--     solo mira su fecha.
--  7. DOCUMENTO TARDÍO: si la fecha del papel cae en un mes ya cerrado, se
--     postea el primer día del período abierto, con la nota en la
--     procedencia (§5.7 del plan). Si además ese mes es de un EJERCICIO
--     anterior, entra como ajuste de ese ejercicio (ajuste_cpa, con
--     afecta_periodo = el mes del papel): así no cae en el resultado del
--     año siguiente (la misma regla que c2 aplica al reverso).
--  8. NADA A 2300 DESDE UN RECIBO. El total del recibo entra con su
--     impuesto a la cuenta de costo; con el impuesto desconocido (tax
--     nulo) entra el total igual, y la procedencia lo dice. «Incluido en
--     el total» solo se escribe cuando se comprobó (subtotal + tax =
--     total); si falta un dato, dice que no se pudo comprobar, y si no
--     cuadra, el recibo espera (punto 15).
--  9. REGLAS COMO DATOS, CONFIRMADAS. Qué cuenta recibe cada categoría,
--     qué forma de pago es cada metodo_pago, qué ingreso lleva cada tipo
--     de obra: tablas de mapeo que Edgar confirma. Lo que viene aquí es
--     BORRADOR y un borrador NO postea: el papel espera en la bandeja
--     hasta que Edgar confirma la regla (fn_mapeo_confirmar). Cada asiento
--     lleva en su procedencia la regla que usó, quién la confirmó y cuándo,
--     y cada cambio a una regla queda en puente_reglas_historial.
-- 10. LA CASILLA «PAGADA» NO MUEVE DINERO. Durante el paralelo la app sigue
--     marcando pagada a mano (y trg_factura_cobrada sigue poniendo cobrado
--     = monto). El libro NO crea un cobro por eso: el dinero entra una sola
--     vez, cuando llega el depósito del banco (f06 lo casa con la factura y
--     crea el cobro) o cuando Edgar lo registra a propósito
--     (fn_cobro_registrar). La vista facturas_cobro enseña las dos cosas
--     lado a lado. La casilla se retira en f15, y entonces sí la mantiene
--     el libro.
-- 11. EL PAPEL NO SE BORRA EN STORAGE. La foto de un recibo (recibos/…) y
--     los documentos del dueño (docs/…) no se borran por la API: una policy
--     RESTRICTIVA de Storage, que se suma a las que ya hay. La app no borra
--     archivos: no le cambia nada.
-- 12. EL EQUIPO SUBE; LA LECTURA Y EDGAR PONEN EL DINERO. Un recibo que
--     sube un trabajador entra «por leer» (foto, obra, nota, CO, proveedor),
--     a su nombre y con su sesión activa: el total, la fecha, la categoría
--     y la forma de pago los pone la lectura (cerebro) o Edgar. Así nadie
--     del equipo puede, por la API, meter un recibo ya «leído» que el
--     puente contabilizaría. Y el equipo no edita ni borra recibos: lo
--     dice la guarda del recibo, que no depende de la RLS (una vista de
--     dueño como recibos_equipo se la salta; por eso además a esas vistas
--     se les quita la escritura: la app solo las lee). La ruta de la foto
--     ES el papel que va a leer la lectura: la de un recibo nuevo es suya
--     y nueva (bajo recibos/, no la de otro recibo —recibos_equipo le
--     enseña las de todos— ni un archivo de otro en el almacén). Y las
--     horas no las aprueba quien las reporta, ni cambian de número.
-- 13. LOS TRIGGERS DE LA APP CON QUE CONVIVEN LOS PUENTES (ESQUEMA-REAL):
--     este archivo rehace dos, con la MISMA función de siempre:
--       · trg_recibo_marca_material, solo cuando cambian la obra, las notas
--         o el estado del recibo (lo único que lee su función). Así la
--         escritura del propio puente (contabilizado_en) no vuelve a leer
--         las notas de un recibo viejo y no marca «comprado» un material
--         nuevo que nadie ha comprado.
--       · trg_guarda_correccion, que no corre cuando lo único que cambia es
--         la aprobación (aprobado_por, aprobado_el), columnas que su
--         función no conoce. Así Edgar aprueba desde el SQL Editor, y
--         aprobar no gasta el permiso de corrección de un trabajador. Quién
--         aprueba lo vigila la guarda de horas de este archivo.
--     Si alguien vuelve a pegar esos triggers como eran, el control
--     triggers de fn_puentes_verificar lo dice.
-- 14. UN COBRO, UNA VEZ Y A SU TIEMPO. fn_cobro_registrar toma las filas de
--     sus facturas antes de mirar su saldo (dos cobros a la vez, o un cobro
--     mientras se anula la factura, se esperan); con la llave del teléfono
--     (llave_cliente) el mismo cobro mandado dos veces entra una; un
--     movimiento del banco casa con un solo cobro vigente; y lo cobrado
--     antes de la fecha de una factura no se le aplica: es anticipo de la
--     obra. Entra a una cuenta de banco (10xx), no a otra de activo. Cada
--     factura_id se lee UNA vez: el candado y la búsqueda usan el mismo
--     número (« 3» y «+3» son la factura 3 para los dos).
-- 15. LO QUE NO CUADRA EN EL PAPEL SE PREGUNTA, no se contabiliza callado.
--     Un recibo espera en la bandeja, con sus números, si:
--       · fecha_posterior_a_subida: la fecha leída es de más de un día
--         después del día en que se subió (¿mes y día cruzados?);
--       · devolucion: las notas dicen DEVOLUCIÓN (la marca que pone la app)
--         y el total es positivo: la app la enseña como devolución y el
--         libro la contaría como compra;
--       · impuesto: trae subtotal y tax y no suman el total (más de un
--         centavo): el total sin el impuesto, o al revés;
--       · duplicado: otro recibo no anulado tiene la misma foto (ruta) o el
--         mismo ticket (proveedor, número de recibo y total). Entra el que
--         ya está en el libro (o el más viejo); el otro espera, y el motivo
--         dice cuál es. El mismo ticket subido dos veces (otro envío, otra
--         llave) no se le debe dos veces a nadie.
--     Edgar corrige el papel (y entra solo) o confirma que está bien:
--     fn_puentes_confirmar(tabla, id, código, motivo). La confirmación
--     queda escrita (puente_revisados) y vale para ESE dato: si el papel
--     cambia, se vuelve a preguntar. El control duplicados vigila lo que
--     ya está en el libro.
-- 16. LA MANO DE OBRA ESTÁNDAR NO SE CUENTA DOS VECES. El devengo de cierre
--     es solo lo trabajado y todavía no pagado. Hasta que f11 traiga el
--     «pagado hasta» de cada corrida, un mes que ya tiene journal de
--     nómina no se devenga (MX008), y un devengo que convive con un
--     journal del mismo mes sale en rojo (control devengo); volver a
--     devengar lo deshace.
-- 17. LA NOTA DE CRÉDITO SALDA LA FACTURA COMO ESTÁ HOY: lo que su partida
--     debe en cada cuenta de cobrar (1110 y 1120, con su obra, también
--     después de reclasificar la retención) y el espejo de su ingreso. Si
--     otro asiento movió la partida contra otra cuenta (un castigo a
--     incobrables), la nota no lo deshace: fn_factura_anular lo dice
--     (MX008) y nombra ese asiento.
--
-- PARCHE PENDIENTE DE LA APP (f05; no es de este archivo, que no toca js/):
--   · la app no conoce facturas.estado. Una factura anulada con su nota de
--     crédito sigue con pagada = false, y la app la cuenta «por cobrar».
--     Este archivo no la deja marcar cobrada (MX003) y facturas_cobro la
--     avisa; falta en db.js mapear estado y en app.js dejar fuera las
--     'anulada' de facturasPendientes y de facturasHTML.
--   · la FORMA DE PAGO no tiene dónde escribirse: ni formMano, ni
--     formRecibo, ni el ✎ del dueño mandan metodo_pago ni ultimos4 (los
--     llena solo la lectura de cerebro). Falta un selector de forma de
--     pago (con los textos del mapeo confirmado) y los últimos 4 de la
--     tarjeta en los tres. Hasta entonces, un total tecleado va a cuenta
--     de su proveedor si tiene términos, o espera con el SQL exacto.
--   · el 🗑 de un recibo que YA está en el libro debe ofrecer «anular»
--     (estado 'anulado', lo que hace fn_recibo_anular) en vez de borrar:
--     la lista «📥 Por completar» solo suelta un recibo anulado o con
--     obra, y un repetido sin obra se quedaba en ella para siempre.
--   · el ✎ de un recibo ANULADO le manda estado = 'leido': la guarda lo
--     deja anulado y guarda la nota. Para volver a contarlo:
--     fn_recibo_desanular(id, motivo).
--
-- LO QUE NO LLEVA contabilizado_en (f03 lo pedía también en horas y
-- materiales): las horas no postean dinero (son la clave de reparto; su
-- rastro es la aprobación y horas_aprobaciones), y un material de la lista
-- de compras no es un papel contable (el gasto es su recibo). Bloquearlos
-- rompería la corrección de horas y la lista de compras sin ganar nada.
--
-- LA APERTURA (f04) Y LAS PARTIDAS: el asiento de apertura al 30-sep lleva
-- en 1110 y 1120 una línea por factura abierta (partida facturas/<id>, con
-- su obra), y en 2010 una por proveedor (tercero proveedor; y partida
-- recibos/<id> si el ticket está en la app). Así un cobro o un pago de
-- octubre de algo de septiembre se aplica a su partida igual que los de
-- los puentes (fn_cobro_registrar mira el saldo de la partida en el libro).
-- Un papel que la apertura nombra ya está en el libro: su puente no lo
-- vuelve a meter (en_apertura, en la bandeja), y lo que esté mal en él se
-- corrige con un ajuste a la apertura (tipo ajuste_cpa, afecta_periodo =
-- la apertura) contra su partida. Si llegara al revés (el puente primero y
-- la apertura después), el control partidas lo dice.
--
-- LOS ERRORES CON NOMBRE que añade este archivo (además de los de c2):
--   MX003  el papel está en el libro: no se borra (y la factura, no se
--          cambia); una foto que ya es de otro recibo; unas horas que
--          están o estuvieron aprobadas no cambian de número
--   MX008  al puente le falta algo para contabilizar lo que se le pide a
--          propósito (un cobro a una factura que no está en el libro, una
--          nota de crédito de una factura con cobros o movida a mano, un
--          anticipo que no alcanza, un devengo en un mes con nómina, anular
--          un papel cuyo asiento usa una cuenta inactiva…). En los
--          triggers no sale: va a la bandeja.
--
-- QUIÉN LLAMA QUÉ:
--   · El dueño, por RPC desde conta.js (grant a authenticated; por dentro
--     solo pasa el dueño). Las que tocan el libro están en el reparto de
--     c2 (c_fn_app_fases) y en sus huellas:
--       fn_puentes_correr(desde)      el backfill y el «reintentar»
--       fn_puentes_rehacer(tabla, id, motivo)   reverso + asiento nuevo con
--                                     las reglas de hoy
--       fn_puentes_verificar()        los controles de los puentes
--       fn_cobro_registrar(cobro), fn_cobro_anular(id, motivo),
--       fn_anticipo_aplicar(cobro, factura, monto, fecha)
--       fn_factura_anular(factura, motivo, fecha)
--       fn_horas_aprobar(usuario, desde, hasta), fn_horas_desaprobar(…),
--       fn_horas_devengar('AAAA-MM')
--       fn_recibo_anular(id, motivo), fn_externo_anular(id, motivo)
--       fn_recibo_desanular(id, motivo)   volver a contar un recibo anulado
--       fn_puentes_antes_del_corte(tabla, id, motivo)   «sí, es de antes
--                                     del corte y está en QuickBooks»
--       fn_puentes_confirmar(tabla, id, código, motivo)  «el papel está
--                                     bien así» (lo que el punto 15 pregunta)
--       fn_mapeo_categoria, fn_mapeo_metodo_pago, fn_mapeo_tipo_proyecto,
--       fn_mapeo_confirmar, fn_tarjeta_alta, fn_proveedor_alta,
--       fn_proveedor_alias, fn_puentes_cuenta
--   · Por dentro: todas las fn_puente_… (singular). Sin grant a nadie de
--     la API; las llaman los triggers (SECURITY DEFINER) y las de arriba.
--   · Los triggers corren con el rol de quien guardó el papel (un
--     trabajador por la app, la rutina de cerebro con service_role, Edgar):
--     el asiento lo dice (rol_bd, usuario_id). service_role NO ejecuta
--     ninguna función de este archivo: la lectura del recibo (cerebro)
--     escribe el papel, y es el puente —con las reglas de Edgar— el que
--     postea. La procedencia lo dice.
-- =====================================================================


-- =====================================================================
-- ================================ BLOQUE A ============================
-- Las tablas, las columnas nuevas, las reglas en borrador, las vistas y
-- las funciones mínimas para probar en rojo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A.0 · PRECONDICIONES — solo lee. Si algo falta, no se aplica nada.
--   · El libro de c1 y c2, en la versión con tercero y partida en las
--     líneas.
--   · Las tablas de la app que leen los puentes, con las columnas que
--     usan (sacadas del esquema real del 23-sep: si cambió, se para aquí
--     y no a medio camino).
--   · Y el libro SANO en sus huellas (control triggers de c2 en verde).
--     Este archivo termina resellando las huellas (sus funciones y sus
--     triggers se vigilan desde c2): resellar encima de una guarda tocada
--     la bendeciría. Si está en rojo, primero se vuelve a pegar c2.
-- ---------------------------------------------------------------------
do $$
declare
  v_falta text := '';
  v_ok    boolean;
  r       record;
begin
  if to_regclass('public.cuentas') is null or to_regclass('public.asientos') is null
     or to_regclass('public.asiento_lineas') is null
     or to_regprocedure('public.fn_postear_interno(jsonb)') is null
     or to_regprocedure('public.fn_reversar_interno(uuid,text,text,jsonb)') is null then
    v_falta := v_falta || ' · falta el libro: pega antes c1-plan-de-cuentas.sql y c2-libro.sql';
  elsif not exists (select 1 from information_schema.columns
                     where table_schema = 'public' and table_name = 'asiento_lineas' and column_name = 'partida_id')
        or to_regprocedure('public.fn_libro_huellas_sellar(text)') is null then
    v_falta := v_falta || ' · el libro es de antes de f03 (sin tercero ni partida en las líneas): vuelve a pegar c2-libro.sql';
  end if;
  if to_regprocedure('public.es_dueno()') is null or to_regprocedure('public.es_activo()') is null then
    v_falta := v_falta || ' · faltan es_dueno() o es_activo()';
  end if;

  -- Las columnas que leen o escriben los puentes, tabla por tabla.
  for r in
    select v.tabla, v.columna
      from (values ('recibos','id'), ('recibos','proyecto_id'), ('recibos','ruta'), ('recibos','total'),
                   ('recibos','proveedor'), ('recibos','notas'), ('recibos','estado'), ('recibos','autor_id'),
                   ('recibos','creado'), ('recibos','co'), ('recibos','fecha'), ('recibos','categoria'),
                   ('recibos','tax'), ('recibos','subtotal'), ('recibos','num_recibo'), ('recibos','metodo_pago'),
                   ('recibos','ultimos4'),
                   ('facturas','id'), ('facturas','proyecto_id'), ('facturas','num'), ('facturas','fecha'),
                   ('facturas','monto'), ('facturas','pagada'), ('facturas','cobrado'), ('facturas','cobrada_el'),
                   ('facturas','qb_id'), ('facturas','hito_id'), ('facturas','a_contratista'),
                   ('trabajos_externos','id'), ('trabajos_externos','proyecto_id'), ('trabajos_externos','descripcion'),
                   ('trabajos_externos','fecha'), ('trabajos_externos','tipo'), ('trabajos_externos','horas'),
                   ('trabajos_externos','costo'), ('trabajos_externos','creado'), ('trabajos_externos','externo_id'),
                   ('horas','id'), ('horas','fecha'), ('horas','usuario_id'), ('horas','proyecto_id'), ('horas','fase'),
                   ('horas','horas'), ('horas','co'), ('horas','correccion_estado'),
                   ('proyectos','id'), ('proyectos','tipo'), ('proyectos','nombre'),
                   ('perfiles','id'), ('perfiles','rol'), ('perfiles','nombre'),
                   ('costos_equipo','usuario_id'), ('costos_equipo','costo_hora'),
                   ('externos_equipo','id'), ('externos_equipo','nombre'),
                   ('estimados','id'), ('estimados','proyecto_id'), ('estimados','retencion_pct'), ('estimados','estado'))
           as v(tabla, columna)
     where not exists (select 1 from information_schema.columns c
                        where c.table_schema = 'public' and c.table_name = v.tabla and c.column_name = v.columna)
  loop
    v_falta := v_falta || format(' · falta %s.%s', r.tabla, r.columna);
  end loop;

  -- Las llaves a las que este archivo pone una FK (cobros, aplicaciones y
  -- notas de crédito apuntan a facturas y a obras).
  for r in
    select v.tabla
      from (values ('facturas'), ('proyectos')) as v(tabla)
     where to_regclass('public.' || v.tabla) is not null
       and not exists (select 1 from pg_index i
                        where i.indrelid = to_regclass('public.' || v.tabla)
                          and i.indisunique and i.indimmediate and i.indpred is null and i.indnkeyatts = 1
                          and i.indkey[0] = (select a.attnum from pg_attribute a
                                              where a.attrelid = to_regclass('public.' || v.tabla) and a.attname = 'id'))
  loop
    v_falta := v_falta || format(' · %s.id no tiene llave primaria ni unique (este archivo le pone una FK)', r.tabla);
  end loop;

  if v_falta <> '' then
    raise exception using
      errcode = 'MX000',
      message = 'c3-puentes NO se aplicó, no se tocó nada. Falta lo que este archivo da por hecho:' || v_falta,
      hint    = 'Ver docs/conta/ESQUEMA-REAL.md. Si el esquema cambió desde el 23-sep, hay que volver a leerlo antes de pegar.';
  end if;

  select v.ok into v_ok from public.fn_verificar_cadena() v where v.control = 'triggers';
  if v_ok is distinct from true then
    raise exception using
      errcode = 'MX000',
      message = 'c3-puentes NO se aplicó, no se tocó nada: las huellas del libro no son las del último pegado (control '
                'triggers de fn_verificar_cadena en rojo). Este archivo termina resellándolas, y encima de una guarda '
                'tocada la bendeciría.',
      hint    = 'Mira el detalle de select * from fn_verificar_cadena(); vuelve a pegar c2-libro.sql y después este archivo.';
  end if;
end $$;


-- ---------------------------------------------------------------------
-- A.1 · Lo que se escribe igual siempre: la forma normal de un texto que
-- llega de fuera (metodo_pago, categoria, proveedor, tipo de obra: su
-- vocabulario lo pone cerebro o la app, y no se conoce entero). Minúsculas,
-- sin espacios de sobra; vacío = nulo. Las llaves de los mapeos se guardan
-- así, y así se buscan.
-- ---------------------------------------------------------------------
create or replace function public.fn_puente_normalizar(p text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select nullif(lower(btrim(regexp_replace(coalesce(p, ''), '[[:space:]]+', ' ', 'g'))), '')
$$;
revoke execute on function public.fn_puente_normalizar(text) from public, anon, authenticated, service_role;

-- Los 4 últimos de una tarjeta, como los escribe el ticket o la lectura
-- («*4417», «XXXX4417», «4417 »): solo sus dígitos, los cuatro últimos.
-- Nulo si no trae ninguno; si trae menos de cuatro, los que trae (y quien
-- lo usa dice que no alcanza).
create or replace function public.fn_puente_ultimos4(p text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select nullif(right(regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g'), 4), '')
$$;
revoke execute on function public.fn_puente_ultimos4(text) from public, anon, authenticated, service_role;


-- ---------------------------------------------------------------------
-- A.2 · Columnas nuevas en las tablas de la app. Todas nulas o con un
-- valor por omisión que describe lo de hoy: la app no las manda ni las
-- necesita, y lee con select=* (una columna de más no le cambia nada).
--   recibos.llave_cliente     el doble toque sin señal: el teléfono manda
--                             la misma llave dos veces y la segunda da 409
--                             («ya estaba»). La unicidad es un control:
--                             va en el bloque B.
--   recibos / facturas / trabajos_externos .contabilizado_en
--                             el asiento VIVO del papel (del papel al
--                             libro). Lo pone solo el puente.
--   facturas.estado           emitida (así nacen hoy: desde QuickBooks),
--                             borrador (la facturación propia de f10) o
--                             anulada (con su nota de crédito).
--   facturas.retencion        la parte de ESTA factura que el cliente
--                             retiene y paga al final (va a 1120). monto
--                             sigue siendo el total facturado. 0 = sin
--                             retención; nula = nadie lo dijo, que es lo
--                             mismo que 0 salvo que haya señal de retención
--                             (una factura a un GC, o una obra con retención
--                             pactada en su estimado): entonces la factura
--                             espera en la bandeja a que Edgar la diga. La
--                             llenará qb o f10.
--   horas.aprobado_por / aprobado_el
--                             Edgar aprueba las horas por período (la
--                             clave de reparto de la nómina, f11).
-- ---------------------------------------------------------------------
alter table public.recibos           add column if not exists llave_cliente    text;
alter table public.recibos           add column if not exists contabilizado_en uuid references public.asientos (id);
alter table public.facturas          add column if not exists estado           text not null default 'emitida';
alter table public.facturas          add column if not exists retencion        numeric;
alter table public.facturas          add column if not exists contabilizado_en uuid references public.asientos (id);
alter table public.trabajos_externos add column if not exists contabilizado_en uuid references public.asientos (id);
alter table public.horas             add column if not exists aprobado_por     uuid;
alter table public.horas             add column if not exists aprobado_el      timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.facturas'::regclass and conname = 'facturas_estado_valido') then
    alter table public.facturas add constraint facturas_estado_valido
      check (estado in ('borrador', 'emitida', 'anulada'));
  end if;
  -- El dinero del libro va en centavos: una retención con más de dos
  -- decimales no se redondea a escondidas, se rechaza.
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.facturas'::regclass and conname = 'facturas_retencion_valida') then
    alter table public.facturas add constraint facturas_retencion_valida
      check (retencion is null or (retencion >= 0 and scale(retencion) <= 2));
  end if;
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.horas'::regclass and conname = 'horas_aprobacion_completa') then
    alter table public.horas add constraint horas_aprobacion_completa
      check (aprobado_por is null or aprobado_el is not null);
  end if;
end $$;

create index if not exists recibos_contabilizado_idx  on public.recibos (contabilizado_en) where contabilizado_en is not null;
create index if not exists facturas_contabilizado_idx on public.facturas (contabilizado_en) where contabilizado_en is not null;
create index if not exists horas_aprobadas_idx        on public.horas (usuario_id, fecha) where aprobado_el is not null;


-- ---------------------------------------------------------------------
-- A.3 · Las reglas: cuentas por papel, mapeos, tarjetas y proveedores.
-- ---------------------------------------------------------------------

-- Las cuentas que usa cada puente, por lo que son (no un «if 2010»
-- escondido en una función): la de cuentas por pagar, la de cobrar, la de
-- retención… Las pone el plan (f03 y c1); se cambian con
-- fn_puentes_cuenta y cada cambio queda en el historial.
create table if not exists public.puente_cuentas (
  rol          text        primary key,
  cuenta       text        not null references public.cuentas (codigo),
  descripcion  text        not null,
  cambiado_por uuid,
  cambiado_el  timestamptz not null default now()
);

-- La cuenta que recibe el gasto de un recibo, por su categoría (la pone
-- cerebro al leerlo; por omisión 'material'). cuenta: con obra.
-- cuenta_sin_obra: la de un recibo sin obra (p. ej. 1300, la bodega); nula
-- = un recibo sin obra de esta categoría espera en la bandeja a que se le
-- asigne (📌), salvo que la cuenta no exija obra (la gasolina, 6300).
-- confirmado_el nulo = BORRADOR: no postea.
create table if not exists public.mapeo_categoria_recibo (
  categoria       text        primary key,
  cuenta          text        not null references public.cuentas (codigo),
  cuenta_sin_obra text        references public.cuentas (codigo),
  confirmado_por  uuid,
  confirmado_el   timestamptz,
  confirmado_rol  text,
  notas           text,
  constraint mapeo_categoria_forma
    check (categoria = lower(btrim(regexp_replace(categoria, '[[:space:]]+', ' ', 'g'))) and categoria <> '')
);

-- La forma de pago de un recibo, por lo que la lectura escribió en
-- metodo_pago (vocabulario de cerebro, que no se conoce entero). Una
-- forma de las cinco de f03:
--   cuenta_proveedor  a la cuenta abierta del supply → 2010, por proveedor
--   tarjeta           la cuenta la dice la tarjeta (tabla tarjetas, por
--                     los últimos 4 del recibo)
--   banco             cheque, ACH, Zelle… → la cuenta de este renglón
--   efectivo          → la cuenta de este renglón (hasta que Edgar diga de
--                     dónde sale el efectivo, espera en la bandeja)
--   reembolso         lo pagó alguien de su bolsillo: Edgar → 2900; un
--                     empleado → 2250, a su nombre (quien subió el recibo)
create table if not exists public.mapeo_metodo_pago (
  metodo_pago    text        primary key,
  forma          text        not null,
  cuenta         text        references public.cuentas (codigo),
  confirmado_por uuid,
  confirmado_el  timestamptz,
  confirmado_rol text,
  notas          text,
  constraint mapeo_metodo_forma
    check (metodo_pago = lower(btrim(regexp_replace(metodo_pago, '[[:space:]]+', ' ', 'g'))) and metodo_pago <> ''),
  constraint mapeo_metodo_forma_valida
    check (forma in ('cuenta_proveedor', 'tarjeta', 'banco', 'efectivo', 'reembolso')),
  constraint mapeo_metodo_cuenta
    check (    (forma = 'banco' and cuenta is not null)
            or  forma = 'efectivo'
            or (forma in ('cuenta_proveedor', 'tarjeta', 'reembolso') and cuenta is null))
);

-- La cuenta de ingreso de una factura, por el tipo de su obra
-- (proyectos.tipo: residencial, comercial, servicio).
create table if not exists public.mapeo_tipo_proyecto (
  tipo           text        primary key,
  cuenta         text        not null references public.cuentas (codigo),
  confirmado_por uuid,
  confirmado_el  timestamptz,
  confirmado_rol text,
  notas          text,
  constraint mapeo_tipo_forma
    check (tipo = lower(btrim(regexp_replace(tipo, '[[:space:]]+', ' ', 'g'))) and tipo <> '')
);

-- Las tarjetas, por sus últimos 4 (recibos.ultimos4, que llena la lectura
-- del recibo). La cuenta: su subcuenta 2100-XXXX (las Amex, que Edgar
-- añade a la lista de c1), 1010 (la débito de Chase), 2900 (una tarjeta
-- personal de Edgar) o 2250 (la personal de un empleado: empleado_id dice
-- de quién). Ojo: Apple Pay imprime los 4 del teléfono, no los de la
-- tarjeta: se da de alta ese número también. Dos tarjetas con los mismos
-- 4 últimos no se distinguen: el recibo no trae más.
create table if not exists public.tarjetas (
  ultimos4    text        primary key,
  cuenta      text        not null references public.cuentas (codigo),
  titular     text        not null,
  empleado_id uuid,
  activa      boolean     not null default true,
  notas       text,
  creado_por  uuid,
  creado_el   timestamptz not null default now(),
  constraint tarjetas_ultimos4 check (ultimos4 ~ '^[0-9]{4}$'),
  constraint tarjetas_titular  check (btrim(titular) <> '')
);

-- Los proveedores: el supply a cuenta (CED, Platt…), el subcontratista y
-- el ayudante externo (externo_id: su fila en externos_equipo, la nómina de
-- ayudantes de la app). En f12 se le añaden TIN, dirección, tipo, W-9 y
-- COI. El nombre que trae el recibo (texto libre de la lectura) se casa
-- por proveedores_alias: el nombre normalizado y sus variantes.
create table if not exists public.proveedores (
  id          uuid        primary key default gen_random_uuid(),
  nombre      text        not null,
  terminos    text,
  externo_id  bigint,
  activo      boolean     not null default true,
  notas       text,
  creado_por  uuid,
  creado_el   timestamptz not null default now(),
  constraint proveedores_nombre check (btrim(nombre) <> '')
);
create unique index if not exists proveedores_nombre_unico  on public.proveedores (lower(btrim(nombre)));
create unique index if not exists proveedores_externo_unico on public.proveedores (externo_id) where externo_id is not null;

-- A quién se le debe un trabajo externo. La forma de la app manda el
-- ayudante de su nómina (externo_id) o lo «escribe libre» (la opción por
-- omisión, lo normal en un subcontrato de precio cerrado): entonces no hay
-- a quién. Esta columna se lo pone Edgar (nula = el proveedor del
-- ayudante, si lo hay): update trabajos_externos set proveedor_id = … ; el
-- puente la usa antes que externo_id. Sin ella, la deuda de 2010 no sale
-- por proveedor, ni su 1099.
alter table public.trabajos_externos add column if not exists proveedor_id uuid references public.proveedores (id);

create table if not exists public.proveedores_alias (
  alias        text        primary key,
  proveedor_id uuid        not null references public.proveedores (id),
  creado_el    timestamptz not null default now(),
  constraint proveedores_alias_forma
    check (alias = lower(btrim(regexp_replace(alias, '[[:space:]]+', ' ', 'g'))) and alias <> '')
);

-- Cada cambio a una regla (mapeos, tarjetas, proveedores, cuentas de los
-- puentes): quién, cuándo, antes y después. Una regla cambia cómo se
-- contabiliza lo que venga: aquí queda desde cuándo y por quién. Lo llena
-- un trigger (bloque B); no se edita ni se borra.
create table if not exists public.puente_reglas_historial (
  id          uuid        primary key default gen_random_uuid(),
  tabla       text        not null,
  clave       text        not null,
  operacion   text        not null,
  cambiado_el timestamptz not null default clock_timestamp(),
  usuario_id  uuid,
  rol         text        not null,
  antes       jsonb,
  despues     jsonb,
  constraint puente_reglas_historial_operacion check (operacion in ('INSERT', 'UPDATE', 'DELETE'))
);
create index if not exists puente_reglas_historial_idx on public.puente_reglas_historial (tabla, clave, cambiado_el);


-- ---------------------------------------------------------------------
-- A.4 · Los papeles que nacen aquí: cobros, sus aplicaciones y las notas
-- de crédito. Llaves uuid, sin secuencia: c3-pruebas.sql los crea y los
-- deshace, y una secuencia no se deshace con el rollback.
-- ---------------------------------------------------------------------

-- Un cobro es UN depósito: una fecha, un monto, una cuenta de banco. Se
-- reparte en aplicaciones: a una o varias facturas (o a su retención), o
-- se queda como anticipo de una obra. movimiento_id: el movimiento del
-- banco con que lo casa f06 (así el mismo dinero no entra dos veces).
-- llave_cliente: la del teléfono, como en recibos y horas: el mismo cobro
-- mandado dos veces (un doble toque, un reintento tras un corte de red)
-- entra una vez (su unicidad es un control: va en el bloque B).
create table if not exists public.cobros (
  id               uuid          primary key default gen_random_uuid(),
  fecha            date          not null,
  monto            numeric(14,2) not null,
  cuenta           text          not null references public.cuentas (codigo),
  medio            text,
  referencia       text,
  proyecto_id      text          references public.proyectos (id),
  movimiento_id    text,
  notas            text,
  estado           text          not null default 'vigente',
  anulado_el       timestamptz,
  anulado_motivo   text,
  contabilizado_en uuid          references public.asientos (id),
  creado_por       uuid,
  creado_el        timestamptz   not null default now(),
  constraint cobros_monto_positivo check (monto > 0),
  constraint cobros_estado_valido  check (estado in ('vigente', 'anulado')),
  constraint cobros_anulado        check ((estado = 'anulado') = (anulado_el is not null)
                                          and (estado <> 'anulado' or coalesce(btrim(anulado_motivo), '') <> ''))
);
alter table public.cobros add column if not exists llave_cliente text;

-- Un movimiento del banco casa con UN cobro vigente. Uno anulado (aplicado
-- a la factura equivocada, registrado dos veces) conserva su movimiento
-- como rastro, y el bueno que lo sustituye lleva el mismo: por eso la
-- unicidad es solo entre los vigentes. (Una versión anterior de este
-- archivo la pedía entre todos: se rehace si no es esta.)
do $$
begin
  if to_regclass('public.cobros_movimiento_unico') is not null
     and pg_get_indexdef(to_regclass('public.cobros_movimiento_unico')) not like '%estado%' then
    drop index public.cobros_movimiento_unico;
  end if;
end $$;
create unique index if not exists cobros_movimiento_unico on public.cobros (movimiento_id)
  where movimiento_id is not null and estado = 'vigente';

--   monto          el dinero de este cobro que va a esta factura (o que
--                  queda de anticipo)
--   es_retencion   se cobra la retención de la factura (1120), no su parte
--                  normal (1110)
--   descuento      lo que se le perdona al cliente al cobrar (baja el
--                  ingreso de esa factura): cierra la factura sin dinero
--   desde_anticipo esta aplicación NO trae dinero: usa el anticipo que dejó
--                  este cobro, en la fecha de la aplicación
create table if not exists public.aplicaciones_cobro (
  id               uuid          primary key default gen_random_uuid(),
  cobro_id         uuid          not null references public.cobros (id),
  factura_id       bigint        references public.facturas (id),
  proyecto_id      text          not null references public.proyectos (id),
  monto            numeric(14,2) not null,
  es_retencion     boolean       not null default false,
  descuento        numeric(14,2) not null default 0,
  desde_anticipo   boolean       not null default false,
  fecha            date,
  contabilizado_en uuid          references public.asientos (id),
  creado_por       uuid,
  creado_el        timestamptz   not null default now(),
  constraint aplicaciones_monto_positivo    check (monto > 0),
  constraint aplicaciones_descuento_valido  check (descuento >= 0),
  constraint aplicaciones_anticipo          check (factura_id is not null or (not es_retencion and descuento = 0 and not desde_anticipo)),
  constraint aplicaciones_desde_anticipo    check (not desde_anticipo or (fecha is not null and descuento = 0))
);
create index if not exists aplicaciones_cobro_cobro_idx   on public.aplicaciones_cobro (cobro_id);
create index if not exists aplicaciones_cobro_factura_idx on public.aplicaciones_cobro (factura_id) where factura_id is not null;

-- La nota de crédito: la única forma de anular una factura emitida (una
-- emitida no se borra). Una por factura (anula_a), por el total: una nota
-- parcial (un descuento posterior) es de f10. Su número es propio, sin
-- huecos, por año (contadores, serie notas_credito-AAAA): NC-2026-0001.
create table if not exists public.notas_credito (
  id               uuid          primary key default gen_random_uuid(),
  numero           text          not null,
  anula_a          bigint        not null references public.facturas (id),
  fecha            date          not null,
  monto            numeric(14,2) not null,
  motivo           text          not null,
  contabilizado_en uuid          references public.asientos (id),
  creado_por       uuid,
  creado_el        timestamptz   not null default now(),
  constraint notas_credito_numero_unico  unique (numero),
  constraint notas_credito_una_por_factura unique (anula_a),
  constraint notas_credito_motivo        check (btrim(motivo) <> '')
);


-- ---------------------------------------------------------------------
-- A.5 · La memoria de los puentes y el rastro de las horas.
-- ---------------------------------------------------------------------

-- Una fila por papel que el puente ya miró: en qué quedó, por qué, y su
-- asiento vivo. La bandeja sale de aquí. El puente la reescribe cada vez
-- que mira el papel; no es el libro (el libro es asientos), es su estado.
--   contabilizado  tiene asiento vivo
--   pendiente      le falta algo que tiene que resolver Edgar (el motivo
--                  lo dice)
--   espera         le falta algo que llega solo (la lectura de cerebro)
--   no_aplica      no se contabiliza: anulado, en 0, o de antes del corte
--   error          el libro lo rechazó (el motivo trae su mensaje)
-- asiento_id es el asiento vivo del papel, si lo hay: en error puede
-- seguir el de antes (el intento que falló no tocó nada). intentos cuenta
-- las veces que el papel cambió de estado.
create table if not exists public.puente_documentos (
  tabla        text        not null,
  documento_id text        not null,
  estado       text        not null,
  codigo       text,
  motivo       text,
  asiento_id   uuid        references public.asientos (id),
  firma        text,
  intentos     int         not null default 1,
  actualizado  timestamptz not null default now(),
  constraint puente_documentos_pk primary key (tabla, documento_id),
  constraint puente_documentos_tabla  check (tabla in ('recibos', 'facturas', 'trabajos_externos', 'cobros',
                                                       'aplicaciones_cobro', 'notas_credito', 'horas_devengo')),
  constraint puente_documentos_estado check (estado in ('contabilizado', 'pendiente', 'espera', 'no_aplica', 'error')),
  constraint puente_documentos_asiento check (estado <> 'contabilizado' or asiento_id is not null)
);
create index if not exists puente_documentos_estado_idx on public.puente_documentos (estado) where estado in ('pendiente', 'error', 'espera');

-- Lo que Edgar revisó y confirmó de un papel que el puente dejó en la
-- bandeja por una duda que solo él resuelve (cabecera, puntos 6 y 15):
--   fecha_antes_del_corte     fechado antes del corte pero subido después:
--                             de verdad es de antes y está en QuickBooks
--   fecha_posterior_a_subida  la fecha leída es posterior a la subida, y
--                             aun así es la buena
--   duplicado                 comparte foto o ticket con otro recibo, y no
--                             es el mismo gasto
--   impuesto                  subtotal + tax no es el total, y el total es
--                             lo que se pagó
--   devolucion                dice DEVOLUCIÓN y el signo del total es el
--                             bueno
-- dato: lo que confirmó (la fecha, la foto o el ticket, los tres números,
-- el total): si el papel cambia ese dato, la confirmación ya no vale y
-- vuelve a preguntar. Solo se añade (fn_puentes_confirmar,
-- fn_puentes_antes_del_corte).
create table if not exists public.puente_revisados (
  tabla        text        not null,
  documento_id text        not null,
  codigo       text        not null,
  dato         text        not null,
  motivo       text        not null,
  revisado_por uuid,
  revisado_rol text        not null,
  revisado_el  timestamptz not null default clock_timestamp(),
  constraint puente_revisados_pk     primary key (tabla, documento_id, codigo, dato),
  constraint puente_revisados_tabla  check (tabla in ('recibos', 'trabajos_externos')),
  constraint puente_revisados_codigo check (codigo in ('fecha_antes_del_corte', 'fecha_posterior_a_subida', 'duplicado',
                                                      'impuesto', 'devolucion')),
  constraint puente_revisados_motivo check (btrim(motivo) <> '')
);
-- (Una versión anterior de este archivo solo admitía fecha_antes_del_corte:
-- se rehace la restricción si es esa.)
do $$
begin
  if exists (select 1 from pg_constraint
              where conrelid = 'public.puente_revisados'::regclass and conname = 'puente_revisados_codigo'
                and pg_get_constraintdef(oid) not like '%duplicado%') then
    alter table public.puente_revisados drop constraint puente_revisados_codigo;
    alter table public.puente_revisados add constraint puente_revisados_codigo
      check (codigo in ('fecha_antes_del_corte', 'fecha_posterior_a_subida', 'duplicado', 'impuesto', 'devolucion'));
  end if;
end $$;

-- Cada aprobación de horas, y lo que le pasó después: retirada por Edgar,
-- invalidada porque las horas cambiaron (una corrección con permiso), o
-- borrada. Es el «reporte de horas aprobado» al que llega un número de la
-- nómina (§3.2 del plan). Solo se añade.
create table if not exists public.horas_aprobaciones (
  id           uuid        primary key default gen_random_uuid(),
  horas_id     bigint      not null,
  accion       text        not null,
  usuario_id   uuid,
  fecha        date,
  proyecto_id  text,
  horas        numeric,
  aprobado_por uuid,
  hecho_por    uuid,
  rol          text        not null,
  hecho_el     timestamptz not null default clock_timestamp(),
  detalle      jsonb       not null default '{}'::jsonb,
  constraint horas_aprobaciones_accion check (accion in ('aprobada', 'retirada', 'invalidada', 'borrada'))
);
create index if not exists horas_aprobaciones_horas_idx on public.horas_aprobaciones (horas_id, hecho_el);


-- ---------------------------------------------------------------------
-- A.6 · Los valores de arranque.
--   · puente_cuentas: las que fija el plan (f01, f03). No son borrador.
--   · Los tres mapeos: BORRADOR (confirmado_el nulo). ▶ Edgar los corrige
--     y los confirma antes del viernes 2-oct: hasta entonces no postea
--     nada con ellos (el papel espera en la bandeja). El vocabulario de
--     metodo_pago y de categoria lo escribe cerebro y no se conoce entero:
--     van las variantes probables en inglés y en español; lo que llegue
--     distinto cae en la bandeja con su texto tal cual, y se añade.
--   · tarjetas y proveedores: vacías. ▶ Edgar da de alta sus tarjetas (y
--     añade antes sus subcuentas 2100-XXXX a c1) y sus supplies.
-- «on conflict do nothing»: volver a pegar NO pisa lo que Edgar corrigió.
-- ---------------------------------------------------------------------
insert into public.puente_cuentas (rol, cuenta, descripcion)
select v.rol, v.cuenta, v.descripcion
  from (values
    ('cxp',                '2010', 'Cuentas por pagar: lo que se debe a cada proveedor, una partida por papel (recibo a cuenta, trabajo externo). f06 salda las partidas al pagar.'),
    ('cxc',                '1110', 'Cuentas por cobrar: una partida por factura (y por cobro, si deja anticipo).'),
    ('retencion_cxc',      '1120', 'Retención por cobrar: la parte de cada factura que el cliente paga al final, por obra.'),
    ('subcontratos',       '5200', 'El costo de los trabajos externos (ayudantes y subcontratos), por obra.'),
    ('banco',              '1010', 'La cuenta donde entra un cobro si no se dice otra (Chase, la operativa).'),
    ('reembolso_dueno',    '2900', 'Lo que Edgar pagó de su bolsillo por la empresa (préstamo del accionista).'),
    ('reembolso_empleado', '2250', 'Lo que un empleado pagó de su bolsillo por la empresa, a su nombre.'),
    ('mano_obra',          '5000', 'El devengo ESTÁNDAR de las horas aprobadas (debe), reversible el día 1. Nunca la nómina real: esa es del journal (f11).'),
    ('sueldos_devengados', '2210', 'El devengo ESTÁNDAR de las horas aprobadas (haber), reversible el día 1.'),
    ('mano_obra_oficial',  '5001', 'La parte de obra del sueldo de Edgar: solo del journal de nómina (f11). Aquí solo se vigila.'),
    ('use_tax',            '2300', 'Use tax por pagar: NUNCA desde un recibo (el impuesto del ticket es costo). Aquí solo se vigila.')
  ) as v(rol, cuenta, descripcion)
 where exists (select 1 from public.cuentas c where c.codigo = v.cuenta)
on conflict (rol) do nothing;

insert into public.mapeo_categoria_recibo (categoria, cuenta, cuenta_sin_obra, notas)
select v.categoria, v.cuenta, v.sin_obra, v.notas
  from (values
    ('material',          '5100', null, 'La categoría por omisión de recibos. Sin obra espera en la bandeja (📌); si Edgar quiere bodega, cuenta_sin_obra = 1300.'),
    ('materiales',        '5100', null, null),
    ('gasolina',          '6300', null, 'Vehículos: gasto general, sin obra aunque el recibo diga una. ▶ Edgar: ¿o 5300 por obra?'),
    ('combustible',       '6300', null, null),
    ('fuel',              '6300', null, null),
    ('gas',               '6300', null, null),
    ('herramienta',       '6400', null, 'Herramienta menor. Un equipo que dura años es un activo (1520, f08).'),
    ('herramientas',      '6400', null, null),
    ('tools',             '6400', null, null),
    ('uniformes',         '6400', null, null),
    ('comida',            '6350', null, 'Comidas al 50 % (M&E).'),
    ('comidas',           '6350', null, null),
    ('meals',             '6350', null, null),
    ('renta de equipo',   '5300', null, 'Equipo y renta, por obra.'),
    ('equipo',            '5300', null, null),
    ('equipment rental',  '5300', null, null),
    ('permiso',           '5400', null, 'Permisos e inspecciones, por obra.'),
    ('permisos',          '5400', null, null),
    ('permit',            '5400', null, null),
    ('consumibles',       '5500', null, null),
    ('flete',             '5600', null, null),
    ('envio',             '5600', null, null),
    ('freight',           '5600', null, null),
    ('oficina',           '6500', null, null),
    ('office',            '6500', null, null)
  ) as v(categoria, cuenta, sin_obra, notas)
 where exists (select 1 from public.cuentas c where c.codigo = v.cuenta)
on conflict (categoria) do nothing;

insert into public.mapeo_metodo_pago (metodo_pago, forma, cuenta, notas)
select v.metodo, v.forma, v.cuenta, v.notas
  from (values
    ('account',             'cuenta_proveedor', null,   'A la cuenta abierta del supply (statement mensual). ▶ Edgar confirma si CED y Platt son a cuenta.'),
    ('on account',          'cuenta_proveedor', null,   null),
    ('charge',              'cuenta_proveedor', null,   null),
    ('house account',       'cuenta_proveedor', null,   null),
    ('a cuenta',            'cuenta_proveedor', null,   null),
    ('cuenta',              'cuenta_proveedor', null,   null),
    ('credito proveedor',   'cuenta_proveedor', null,   null),
    ('net 30',              'cuenta_proveedor', null,   null),
    ('tarjeta',             'tarjeta',          null,   'La cuenta la dice la tarjeta (tabla tarjetas, por los últimos 4).'),
    ('tarjeta de credito',  'tarjeta',          null,   null),
    ('tarjeta de crédito',  'tarjeta',          null,   null),
    ('tarjeta de debito',   'tarjeta',          null,   null),
    ('tarjeta de débito',   'tarjeta',          null,   null),
    ('credit',              'tarjeta',          null,   null),
    ('credit card',         'tarjeta',          null,   null),
    ('card',                'tarjeta',          null,   null),
    ('debit',               'tarjeta',          null,   'La débito de Chase: su tarjeta, con cuenta 1010.'),
    ('debit card',          'tarjeta',          null,   null),
    ('visa',                'tarjeta',          null,   null),
    ('mastercard',          'tarjeta',          null,   null),
    ('amex',                'tarjeta',          null,   null),
    ('american express',    'tarjeta',          null,   null),
    ('apple pay',           'tarjeta',          null,   'Apple Pay imprime los 4 del teléfono: se dan de alta en tarjetas apuntando a la tarjeta de verdad.'),
    ('google pay',          'tarjeta',          null,   null),
    ('check',               'banco',            '1010', null),
    ('cheque',              'banco',            '1010', null),
    ('ach',                 'banco',            '1010', null),
    ('transfer',            'banco',            '1010', null),
    ('transferencia',       'banco',            '1010', null),
    ('zelle',               'banco',            '1010', null),
    ('wire',                'banco',            '1010', null),
    ('cash',                'efectivo',         null,   '▶ Edgar: la empresa no tiene caja. ¿De quién es el efectivo? (2900 si es tuyo; un empleado → reembolso).'),
    ('efectivo',            'efectivo',         null,   null),
    ('reembolso',           'reembolso',        null,   'Edgar → 2900; un empleado → 2250 a su nombre (quien subió el recibo).'),
    ('reimbursement',       'reembolso',        null,   null),
    ('personal',            'reembolso',        null,   null)
  ) as v(metodo, forma, cuenta, notas)
 where v.cuenta is null or exists (select 1 from public.cuentas c where c.codigo = v.cuenta)
on conflict (metodo_pago) do nothing;

insert into public.mapeo_tipo_proyecto (tipo, cuenta, notas)
select v.tipo, v.cuenta, v.notas
  from (values
    ('residencial', '4010', 'Contrato residencial.'),
    ('comercial',   '4020', 'Contrato comercial.'),
    ('servicio',    '4030', 'Servicio y T&M. Las órdenes de cambio (4040) las separa f10 por su alcance.')
  ) as v(tipo, cuenta, notas)
 where exists (select 1 from public.cuentas c where c.codigo = v.cuenta)
on conflict (tipo) do nothing;


-- ---------------------------------------------------------------------
-- A.7 · Quién lee. El bloque fijo de todo docs/conta/c*.sql, tabla por
-- tabla: solo el dueño lee (una policy); nadie de la API escribe (todo
-- entra por las funciones); anon, nada. service_role conserva la lectura
-- (contador de f07 lee para proponer). «revoke all» y luego «grant select»
-- (en Postgres 17 el «grant all» de Supabase incluye MAINTAIN). Volver a
-- pegar borra toda policy ajena de estas tablas.
-- Las columnas nuevas de las tablas de la app no cambian quién las lee:
-- las mismas policies de siempre.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array['puente_cuentas', 'mapeo_categoria_recibo', 'mapeo_metodo_pago', 'mapeo_tipo_proyecto',
                           'tarjetas', 'proveedores', 'proveedores_alias', 'puente_reglas_historial', 'cobros',
                           'aplicaciones_cobro', 'notas_credito', 'puente_documentos', 'horas_aprobaciones',
                           'puente_revisados'] loop
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


-- ---------------------------------------------------------------------
-- A.8 · Las vistas. Todas security_invoker: leen con los permisos de quien
-- las mira (el libro y los papeles, solo el dueño). Ninguna suma dinero
-- fuera de SQL.
-- ---------------------------------------------------------------------

-- La bandeja: lo que el puente no pudo contabilizar y tiene que resolver
-- Edgar (pendiente), lo que el libro rechazó (error), lo que lleva más de
-- dos días esperando la lectura de cerebro (espera), y lo que sí entró
-- pero con algo que Edgar tiene que completar (aviso: un trabajo externo
-- sin proveedor, que no sale en la deuda por proveedor ni en el 1099). Con
-- el papel al lado para saber de qué se habla.
create or replace view public.puentes_bandeja with (security_invoker = true) as
select d.tabla,
       d.documento_id,
       case when d.estado = 'contabilizado' then 'aviso' else d.estado end as estado,
       d.codigo,
       d.motivo,
       coalesce(r.fecha, (r.creado at time zone 'America/New_York')::date, f.fecha, x.fecha,
                (x.creado at time zone 'America/New_York')::date, c.fecha) as fecha_documento,
       coalesce(r.total, f.monto, x.costo, c.monto)                          as monto,
       coalesce(r.proyecto_id, f.proyecto_id, x.proyecto_id, c.proyecto_id) as proyecto_id,
       case d.tabla
         when 'recibos'           then concat_ws(' · ', r.proveedor, 'metodo_pago: ' || coalesce(r.metodo_pago, '(vacío)'),
                                                 'categoría: ' || coalesce(r.categoria, '(vacía)'), r.estado)
         when 'facturas'          then concat_ws(' · ', '#' || f.num, f.estado)
         when 'trabajos_externos' then x.descripcion
         when 'cobros'            then concat_ws(' · ', c.medio, c.referencia)
       end as papel,
       d.intentos,
       d.actualizado
  from public.puente_documentos d
  left join public.recibos r
         on d.tabla = 'recibos' and r.id = (case when d.tabla = 'recibos' then d.documento_id::bigint end)
  left join public.facturas f
         on d.tabla = 'facturas' and f.id = (case when d.tabla = 'facturas' then d.documento_id::bigint end)
  left join public.trabajos_externos x
         on d.tabla = 'trabajos_externos' and x.id = (case when d.tabla = 'trabajos_externos' then d.documento_id::bigint end)
  left join public.cobros c
         on d.tabla = 'cobros' and c.id = (case when d.tabla = 'cobros' then d.documento_id::uuid end)
 where d.estado in ('pendiente', 'error')
    or (d.estado = 'espera' and d.actualizado < now() - interval '2 days')
    or (d.estado = 'contabilizado' and d.codigo is not null);

-- Las horas aprobadas, por período contable (el mes), trabajador, obra y
-- CO: la clave de reparto de la nómina (f11) y del burden (f09). Horas,
-- nunca dólares. Solo lo aprobado (horas.aprobado_el).
create or replace view public.horas_aprobadas_por_obra_periodo with (security_invoker = true) as
select to_char(h.fecha, 'YYYY-MM') as periodo,
       h.usuario_id,
       p.nombre                    as trabajador,
       h.proyecto_id,
       h.co,
       sum(h.horas)                as horas,
       count(*)                    as reportes,
       min(h.fecha)                as desde,
       max(h.fecha)                as hasta,
       max(h.aprobado_el)          as ultima_aprobacion
  from public.horas h
  left join public.perfiles p on p.id = h.usuario_id
 where h.aprobado_el is not null
 group by to_char(h.fecha, 'YYYY-MM'), h.usuario_id, p.nombre, h.proyecto_id, h.co;

-- Lo que se debe (2010), por proveedor y por partida abierta (el papel que
-- la abrió). Saldo en positivo = se debe. Sin proveedor: la partida de un
-- trabajo externo sin ayudante enlazado (el papel dice a quién).
create or replace view public.cxp_abierta with (security_invoker = true) as
select l.tercero_tipo,
       l.tercero_id,
       coalesce(pr.nombre, x.descripcion)      as a_quien,
       l.partida_tabla,
       l.partida_id,
       -sum(l.monto)                           as saldo,
       min(a.fecha_contable)                   as desde,
       max(a.fecha_contable)                   as ultimo_movimiento,
       count(*)                                as lineas
  from public.asiento_lineas l
  join public.asientos a on a.id = l.asiento_id
  left join public.proveedores pr
         on l.tercero_tipo = 'proveedor' and pr.id = (case when l.tercero_tipo = 'proveedor' then l.tercero_id::uuid end)
  left join public.trabajos_externos x
         on l.partida_tabla = 'trabajos_externos'
        and x.id = (case when l.partida_tabla = 'trabajos_externos' then l.partida_id::bigint end)
 where l.cuenta = (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'cxp')
 group by l.tercero_tipo, l.tercero_id, coalesce(pr.nombre, x.descripcion), l.partida_tabla, l.partida_id
having sum(l.monto) <> 0;

-- Lo que se cobra (1110 y 1120), por partida abierta: una factura (su
-- parte normal y su retención) o un anticipo (la partida es el cobro).
-- Saldo en positivo = nos deben. En negativo: en la partida de un cobro, el
-- anticipo a favor del cliente (lo normal); en la de una factura, que se
-- cobró de más o que su ingreso se reversó (no debería pasar: el control
-- partidas de fn_puentes_verificar lo marca en rojo).
create or replace view public.cxc_abierta with (security_invoker = true) as
select l.cuenta,
       l.proyecto_id,
       l.partida_tabla,
       l.partida_id,
       f.num                                   as factura,
       sum(l.monto)                            as saldo,
       min(a.fecha_contable)                   as desde,
       max(a.fecha_contable)                   as ultimo_movimiento
  from public.asiento_lineas l
  join public.asientos a on a.id = l.asiento_id
  left join public.facturas f
         on l.partida_tabla = 'facturas' and f.id = (case when l.partida_tabla = 'facturas' then l.partida_id::bigint end)
 where l.cuenta in (select pc.cuenta from public.puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc'))
 group by l.cuenta, l.proyecto_id, l.partida_tabla, l.partida_id, f.num
having sum(l.monto) <> 0;

-- La convivencia con la casilla «pagada»: cada factura, con lo que dice la
-- app (pagada, cobrado, que pone Edgar a mano o QuickBooks) y lo que dice
-- el libro (su saldo por cobrar y lo cobrado por cobros). Lo que no casa
-- lo dice el aviso: es lo que f06 tiene que casar con el banco. «cuadra»
-- solo si de verdad cuadra: una anulada (que la app todavía enseña «por
-- cobrar»), una en negativo en el libro o una anulada con saldo tienen su
-- propio aviso.
--   cobrado_libro    SOLO el dinero: lo que los cobros vigentes le
--                    aplicaron (lo que entró al banco, o el anticipo que
--                    se le aplicó). El descuento no es dinero: va aparte.
--   descuento_libro  lo que se le perdonó al cliente al cobrar (baja el
--                    ingreso; cierra la factura sin dinero)
--   saldo_cxc, saldo_retencion
--                    el saldo por cuenta (1110 y 1120): saldo_libro es su
--                    suma, y una suma en cero puede esconder 800 de
--                    retención por cobrar y −800 en 1110.
-- (Las tres últimas columnas van al final: la vista crece sin cambiar las
-- de antes.)
create or replace view public.facturas_cobro with (security_invoker = true) as
select f.id,
       f.num,
       f.proyecto_id,
       f.fecha,
       f.monto,
       f.retencion,
       f.estado,
       f.pagada,
       f.cobrado                               as cobrado_app,
       f.cobrada_el,
       f.contabilizado_en,
       coalesce(s.saldo, 0)                    as saldo_libro,
       coalesce(s.cobrado, 0) - coalesce(d.descuento, 0) as cobrado_libro,
       case
         when f.estado = 'anulada' and (coalesce(s.saldo_cxc, 0) <> 0 or coalesce(s.saldo_retencion, 0) <> 0)
           then format('anulada y con saldo en el libro (%s en cuentas por cobrar, %s en retención): no debería pasar (revisa sus '
                       'cobros, su nota de crédito y lo que se le hizo a mano; control partidas de fn_puentes_verificar)',
                       coalesce(s.saldo_cxc, 0), coalesce(s.saldo_retencion, 0))
         when f.estado = 'anulada' and coalesce(f.pagada, false)
           then 'anulada, pero marcada cobrada en la app: si el cliente pagó de verdad, ese dinero va a otra factura o de anticipo '
                '(fn_cobro_registrar)'
         when f.estado = 'anulada'
           then 'anulada' || coalesce(' con la nota de crédito ' || n.numero, ' antes de entrar al libro')
                || ': no se cobra; la app todavía la enseña «por cobrar» hasta su parche (f05)'
         when coalesce(s.saldo_cxc, 0) < 0 or coalesce(s.saldo_retencion, 0) < 0
           then format('en negativo en el libro (%s en cuentas por cobrar, %s en retención): se cobró de más, su ingreso se '
                       'reversó, o se reclasificó de más entre las dos (control partidas de fn_puentes_verificar)',
                       coalesce(s.saldo_cxc, 0), coalesce(s.saldo_retencion, 0))
         when f.contabilizado_en is null and s.partida_id is null
           then 'fuera del libro (antes del corte o en la bandeja)'
         when f.pagada and coalesce(s.saldo, 0) > 0
           then 'pagada en la app y abierta en el libro: su cobro llega con el banco (f06) o con fn_cobro_registrar'
         when not coalesce(f.pagada, false) and coalesce(s.saldo, 0) = 0 and coalesce(s.cobrado, 0) > 0
           then 'cobrada en el libro y sin marcar en la app'
         when coalesce(s.saldo, 0) = 0 and coalesce(d.descuento, 0) > 0
              and coalesce(f.cobrado, 0) > coalesce(s.cobrado, 0) - coalesce(d.descuento, 0)
           then format('cobrada en el libro con descuento: la app dice cobrado %s y entraron %s (descuento %s). La casilla cuenta '
                       'el descuento como dinero: lo que casa con el banco es %s', coalesce(f.cobrado, 0),
                       coalesce(s.cobrado, 0) - coalesce(d.descuento, 0), d.descuento,
                       coalesce(s.cobrado, 0) - coalesce(d.descuento, 0))
         else 'cuadra'
       end                                     as aviso,
       n.numero                                as nota_credito,
       coalesce(d.descuento, 0)                as descuento_libro,
       coalesce(s.saldo_cxc, 0)                as saldo_cxc,
       coalesce(s.saldo_retencion, 0)          as saldo_retencion
  from public.facturas f
  left join public.notas_credito n on n.anula_a = f.id
  left join (select l.partida_id,
                    sum(l.monto) as saldo,
                    sum(l.monto) filter (where l.cuenta = (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'cxc'))
                      as saldo_cxc,
                    sum(l.monto) filter (where l.cuenta = (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'retencion_cxc'))
                      as saldo_retencion,
                    -sum(l.monto) filter (where a.origen_tabla in ('cobros', 'aplicaciones_cobro')) as cobrado
               from public.asiento_lineas l
               join public.asientos a on a.id = l.asiento_id
              where l.partida_tabla = 'facturas'
                and l.cuenta in (select pc.cuenta from public.puente_cuentas pc where pc.rol in ('cxc', 'retencion_cxc'))
              group by l.partida_id) s
         on s.partida_id = f.id::text
  -- El descuento de los cobros vigentes y contabilizados (el de un cobro
  -- anulado se reversó con él).
  left join (select ap.factura_id, sum(ap.descuento) as descuento
               from public.aplicaciones_cobro ap
               join public.cobros c on c.id = ap.cobro_id
              where c.estado = 'vigente' and c.contabilizado_en is not null and not ap.desde_anticipo
              group by ap.factura_id) d
         on d.factura_id = f.id;


-- Las vistas se leen, no se escriben; y anon, nada (en Supabase toda vista
-- nueva nace con «grant all» para anon y authenticated).
do $$
declare
  v text;
begin
  foreach v in array array['puentes_bandeja', 'horas_aprobadas_por_obra_periodo', 'cxp_abierta', 'cxc_abierta',
                           'facturas_cobro'] loop
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', v);
    execute format('grant select on public.%I to authenticated, service_role', v);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- A.9 · Las funciones de la app que NO son controles: las que dan de alta
-- y confirman reglas, aprueban horas y marcan un papel como anulado. Son
-- delgadas: escriben y ya. Lo que valida (que una regla no apunte a 2300
-- ni a una cuenta de grupo, que un trabajador no se apruebe sus horas…) y
-- lo que postea son triggers y puentes del bloque B.
-- Todas son SECURITY DEFINER: las reglas no tienen policy de escritura
-- (todo entra por funciones), y todas usan las ayudantes internas (sin
-- grant a la API). Por eso cada una mira por dentro que quien llama sea el
-- dueño (o el SQL Editor), y lleva su revoke y el grant explícito a
-- authenticated. Ninguna nombra una tabla del libro.
-- ---------------------------------------------------------------------

-- El corte: el día siguiente a la apertura (1-oct-2026). Nada fechado
-- antes postea por puente: eso vive en QuickBooks y entra en la apertura.
create or replace function public.fn_puente_corte()
returns date
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce((select max(p.hasta) + 1 from periodos p where p.tipo = 'apertura'), date '2026-10-01')
$$;
revoke execute on function public.fn_puente_corte() from public, anon, authenticated, service_role;

create or replace function public.fn_puente_cuenta_de(p_rol text)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select pc.cuenta from puente_cuentas pc where pc.rol = p_rol
$$;
revoke execute on function public.fn_puente_cuenta_de(text) from public, anon, authenticated, service_role;

-- ¿Quién confirma? El dueño por la app, o el SQL Editor (Edgar también).
create or replace function public.fn_puente_quien() returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select jsonb_build_object('usuario', auth.uid(), 'rol', fn_rol_llamante())
$$;
revoke execute on function public.fn_puente_quien() from public, anon, authenticated, service_role;

create or replace function public.fn_puente_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'Esto lo hace solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_puente_exigir_dueno() from public, anon, authenticated, service_role;

-- Una regla nueva o cambiada, confirmada en el mismo toque (es Edgar quien
-- la dicta). Devuelve la regla como quedó.
create or replace function public.fn_mapeo_categoria(p_categoria text, p_cuenta text, p_cuenta_sin_obra text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_m mapeo_categoria_recibo;
begin
  perform fn_puente_exigir_dueno();
  if fn_puente_normalizar(p_categoria) is null then
    raise exception using errcode = '22023', message = 'Falta la categoría.';
  end if;
  insert into mapeo_categoria_recibo (categoria, cuenta, cuenta_sin_obra, confirmado_por, confirmado_el, confirmado_rol)
  values (fn_puente_normalizar(p_categoria), p_cuenta, nullif(btrim(p_cuenta_sin_obra), ''),
          auth.uid(), clock_timestamp(), fn_rol_llamante())
  on conflict (categoria) do update
     set cuenta = excluded.cuenta, cuenta_sin_obra = excluded.cuenta_sin_obra,
         confirmado_por = excluded.confirmado_por, confirmado_el = excluded.confirmado_el,
         confirmado_rol = excluded.confirmado_rol
  returning * into v_m;
  return to_jsonb(v_m);
end $$;
revoke execute on function public.fn_mapeo_categoria(text, text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_mapeo_categoria(text, text, text) to authenticated;

create or replace function public.fn_mapeo_metodo_pago(p_metodo text, p_forma text, p_cuenta text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_m mapeo_metodo_pago;
begin
  perform fn_puente_exigir_dueno();
  if fn_puente_normalizar(p_metodo) is null then
    raise exception using errcode = '22023', message = 'Falta el metodo_pago (el texto que escribe la lectura del recibo).';
  end if;
  if p_forma is null or p_forma not in ('cuenta_proveedor', 'tarjeta', 'banco', 'efectivo', 'reembolso') then
    raise exception using errcode = '22023',
      message = format('Forma «%s» no válida: cuenta_proveedor, tarjeta, banco, efectivo o reembolso.', coalesce(p_forma, ''));
  end if;
  if p_forma = 'banco' and nullif(btrim(p_cuenta), '') is null then
    raise exception using errcode = '22023', message = 'Un pago por banco dice a qué cuenta de banco (p. ej. 1010).';
  end if;
  if p_forma in ('cuenta_proveedor', 'tarjeta', 'reembolso') and nullif(btrim(p_cuenta), '') is not null then
    raise exception using errcode = '22023',
      message = format('La forma %s no lleva cuenta en el mapeo: la dicen el proveedor, la tarjeta o quién pagó.', p_forma);
  end if;
  insert into mapeo_metodo_pago (metodo_pago, forma, cuenta, confirmado_por, confirmado_el, confirmado_rol)
  values (fn_puente_normalizar(p_metodo), p_forma, nullif(btrim(p_cuenta), ''), auth.uid(), clock_timestamp(), fn_rol_llamante())
  on conflict (metodo_pago) do update
     set forma = excluded.forma, cuenta = excluded.cuenta,
         confirmado_por = excluded.confirmado_por, confirmado_el = excluded.confirmado_el,
         confirmado_rol = excluded.confirmado_rol
  returning * into v_m;
  return to_jsonb(v_m);
end $$;
revoke execute on function public.fn_mapeo_metodo_pago(text, text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_mapeo_metodo_pago(text, text, text) to authenticated;

create or replace function public.fn_mapeo_tipo_proyecto(p_tipo text, p_cuenta text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_m mapeo_tipo_proyecto;
begin
  perform fn_puente_exigir_dueno();
  if fn_puente_normalizar(p_tipo) is null then
    raise exception using errcode = '22023', message = 'Falta el tipo de obra (residencial, comercial, servicio…).';
  end if;
  insert into mapeo_tipo_proyecto (tipo, cuenta, confirmado_por, confirmado_el, confirmado_rol)
  values (fn_puente_normalizar(p_tipo), p_cuenta, auth.uid(), clock_timestamp(), fn_rol_llamante())
  on conflict (tipo) do update
     set cuenta = excluded.cuenta,
         confirmado_por = excluded.confirmado_por, confirmado_el = excluded.confirmado_el,
         confirmado_rol = excluded.confirmado_rol
  returning * into v_m;
  return to_jsonb(v_m);
end $$;
revoke execute on function public.fn_mapeo_tipo_proyecto(text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_mapeo_tipo_proyecto(text, text) to authenticated;

-- Confirmar el borrador tal como está: una regla (p_clave) o todas las de
-- una tabla (p_clave nula). p_tabla: categoria, metodo_pago o tipo_proyecto.
-- Devuelve cuántas quedaron confirmadas.
create or replace function public.fn_mapeo_confirmar(p_tabla text, p_clave text default null)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tabla text;
  v_llave text;
  v_n     int;
begin
  perform fn_puente_exigir_dueno();
  select t.tabla, t.llave into v_tabla, v_llave
    from (values ('categoria', 'mapeo_categoria_recibo', 'categoria'),
                 ('metodo_pago', 'mapeo_metodo_pago', 'metodo_pago'),
                 ('tipo_proyecto', 'mapeo_tipo_proyecto', 'tipo')) as t(nombre, tabla, llave)
   where t.nombre = p_tabla;
  if v_tabla is null then
    raise exception using errcode = '22023',
      message = format('Mapeo «%s» no válido: categoria, metodo_pago o tipo_proyecto.', coalesce(p_tabla, ''));
  end if;
  execute format('update public.%I set confirmado_por = $1, confirmado_el = clock_timestamp(), confirmado_rol = $2
                   where confirmado_el is null and ($3::text is null or %I = $3)', v_tabla, v_llave)
    using auth.uid(), fn_rol_llamante(), fn_puente_normalizar(p_clave);
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke execute on function public.fn_mapeo_confirmar(text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_mapeo_confirmar(text, text) to authenticated;

-- Una tarjeta (o volverla a apuntar a otra cuenta, o reactivarla). Los 4
-- últimos se toman como los imprime el ticket («*4417», «XXXX4417»): solo
-- cuentan sus dígitos, los cuatro últimos. Así se da de alta con lo mismo
-- que trae la lectura del recibo.
create or replace function public.fn_tarjeta_alta(p_ultimos4 text, p_cuenta text, p_titular text, p_empleado uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_t  tarjetas;
  v_u4 text := fn_puente_ultimos4(p_ultimos4);
begin
  perform fn_puente_exigir_dueno();
  if v_u4 is null or length(v_u4) <> 4 then
    raise exception using errcode = '22023',
      message = format('«%s» no trae los 4 últimos dígitos de una tarjeta.', coalesce(p_ultimos4, ''));
  end if;
  insert into tarjetas (ultimos4, cuenta, titular, empleado_id, creado_por)
  values (v_u4, p_cuenta, btrim(p_titular), p_empleado, auth.uid())
  on conflict (ultimos4) do update
     set cuenta = excluded.cuenta, titular = excluded.titular, empleado_id = excluded.empleado_id, activa = true
  returning * into v_t;
  return to_jsonb(v_t);
end $$;
revoke execute on function public.fn_tarjeta_alta(text, text, text, uuid) from public, anon, authenticated, service_role;
grant  execute on function public.fn_tarjeta_alta(text, text, text, uuid) to authenticated;

-- Un proveedor, con su nombre como primer alias y los que se le den (las
-- formas en que la lectura escribe su nombre: «CED», «Consolidated
-- Electrical Distributors»…). p_externo: su fila de ayudante en la app.
create or replace function public.fn_proveedor_alta(p_nombre text, p_terminos text default null,
                                                    p_alias text[] default '{}', p_externo bigint default null)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_a  text;
begin
  perform fn_puente_exigir_dueno();
  if coalesce(btrim(p_nombre), '') = '' then
    raise exception using errcode = '22023', message = 'Falta el nombre del proveedor.';
  end if;
  if p_externo is not null and not exists (select 1 from externos_equipo e where e.id = p_externo) then
    raise exception using errcode = '22023', message = format('No existe el ayudante %s en externos_equipo.', p_externo);
  end if;
  insert into proveedores (nombre, terminos, externo_id, creado_por)
  values (btrim(p_nombre), nullif(btrim(p_terminos), ''), p_externo, auth.uid())
  returning id into v_id;
  foreach v_a in array array[p_nombre] || coalesce(p_alias, '{}') loop
    if fn_puente_normalizar(v_a) is not null then
      insert into proveedores_alias (alias, proveedor_id) values (fn_puente_normalizar(v_a), v_id)
      on conflict (alias) do nothing;
    end if;
  end loop;
  return v_id;
end $$;
revoke execute on function public.fn_proveedor_alta(text, text, text[], bigint) from public, anon, authenticated, service_role;
grant  execute on function public.fn_proveedor_alta(text, text, text[], bigint) to authenticated;

create or replace function public.fn_proveedor_alias(p_proveedor uuid, p_alias text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_a proveedores_alias;
begin
  perform fn_puente_exigir_dueno();
  if fn_puente_normalizar(p_alias) is null then
    raise exception using errcode = '22023', message = 'Falta el alias.';
  end if;
  insert into proveedores_alias (alias, proveedor_id) values (fn_puente_normalizar(p_alias), p_proveedor)
  on conflict (alias) do update set proveedor_id = excluded.proveedor_id
  returning * into v_a;
  return to_jsonb(v_a);
end $$;
revoke execute on function public.fn_proveedor_alias(uuid, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_proveedor_alias(uuid, text) to authenticated;

create or replace function public.fn_puentes_cuenta(p_rol text, p_cuenta text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_c puente_cuentas;
begin
  perform fn_puente_exigir_dueno();
  update puente_cuentas set cuenta = p_cuenta, cambiado_por = auth.uid(), cambiado_el = clock_timestamp()
   where rol = p_rol
  returning * into v_c;
  if v_c.rol is null then
    raise exception using errcode = '22023', message = format('No hay una cuenta de puente «%s».', coalesce(p_rol, ''));
  end if;
  return to_jsonb(v_c);
end $$;
revoke execute on function public.fn_puentes_cuenta(text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_puentes_cuenta(text, text) to authenticated;

-- Aprobar las horas de un trabajador en un período (un toque por empleado),
-- desde la app o desde el SQL Editor. Solo las que no estaban aprobadas. El
-- update toca únicamente la aprobación: la guarda de correcciones de la app
-- (trg_guarda_correccion) no corre con eso (el bloque B la rehace así), de
-- modo que aprobar no se topa con «pídele permiso a Edgar» ni gasta el
-- permiso de corrección de un trabajador. Quién aprueba lo vigila la guarda
-- de horas del bloque B, que apunta cada aprobación en horas_aprobaciones.
-- Devuelve cuántos reportes y cuántas horas quedaron aprobados.
create or replace function public.fn_horas_aprobar(p_usuario uuid, p_desde date, p_hasta date)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_n     int;
  v_horas numeric;
begin
  perform fn_puente_exigir_dueno();
  if p_usuario is null or p_desde is null or p_hasta is null or p_desde > p_hasta then
    raise exception using errcode = '22023', message = 'Se aprueba un trabajador en un período: usuario, desde y hasta (desde ≤ hasta).';
  end if;
  with a as (
    update horas set aprobado_por = auth.uid(), aprobado_el = clock_timestamp()
     where usuario_id = p_usuario and fecha between p_desde and p_hasta and aprobado_el is null
    returning horas.horas
  )
  select count(*), coalesce(sum(a.horas), 0) into v_n, v_horas from a;
  return jsonb_build_object('usuario', p_usuario, 'desde', p_desde, 'hasta', p_hasta, 'reportes', v_n, 'horas', v_horas);
end $$;
revoke execute on function public.fn_horas_aprobar(uuid, date, date) from public, anon, authenticated, service_role;
grant  execute on function public.fn_horas_aprobar(uuid, date, date) to authenticated;

create or replace function public.fn_horas_desaprobar(p_usuario uuid, p_desde date, p_hasta date, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_n int;
begin
  perform fn_puente_exigir_dueno();
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Quitar una aprobación dice por qué (motivo).';
  end if;
  perform set_config('mx_puente.motivo', btrim(p_motivo), true);
  update horas set aprobado_por = null, aprobado_el = null
   where usuario_id = p_usuario and fecha between p_desde and p_hasta and aprobado_el is not null;
  get diagnostics v_n = row_count;
  perform set_config('mx_puente.motivo', '', true);
  return jsonb_build_object('usuario', p_usuario, 'desde', p_desde, 'hasta', p_hasta, 'reportes', v_n);
end $$;
revoke execute on function public.fn_horas_desaprobar(uuid, date, date, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_horas_desaprobar(uuid, date, date, text) to authenticated;

-- ---------------------------------------------------------------------
-- A.10 · Las funciones MÍNIMAS de lo que SÍ es control: mismo nombre,
-- mismos parámetros y mismo resultado que las de verdad del bloque B,
-- para que c3-pruebas.sql corra entero en rojo. No postean nada. Se crean
-- SOLO si no existen: volver a pegar el archivo nunca baja un control.
-- Dejan pasar solo al dueño, con sus revoke desde el primer momento.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.fn_puentes_correr(date)') is null then
    execute $f$
      create function public.fn_puentes_correr(p_desde date default null) returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno(); return jsonb_build_object('minima', true); end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_puentes_rehacer(text,text,text)') is null then
    execute $f$
      create function public.fn_puentes_rehacer(p_tabla text, p_id text, p_motivo text) returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno(); return jsonb_build_object('minima', true); end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_puentes_verificar()') is null then
    execute $f$
      create function public.fn_puentes_verificar() returns table (control text, ok boolean, detalle jsonb)
      language plpgsql stable security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno();
                   return query select 'minima'::text, true, '{}'::jsonb; end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_factura_anular(bigint,text,date)') is null then
    execute $f$
      create function public.fn_factura_anular(p_factura bigint, p_motivo text, p_fecha date default null) returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno();
                   update facturas set estado = 'anulada' where id = p_factura;
                   return jsonb_build_object('minima', true); end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_cobro_registrar(jsonb)') is null then
    execute $f$
      create function public.fn_cobro_registrar(p_cobro jsonb) returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$
      declare v_id uuid; v_a jsonb;
      begin
        perform fn_puente_exigir_dueno();
        insert into cobros (fecha, monto, cuenta, medio, referencia, proyecto_id, creado_por)
        values ((p_cobro->>'fecha')::date, (p_cobro->>'monto')::numeric, coalesce(p_cobro->>'cuenta', '1010'),
                p_cobro->>'medio', p_cobro->>'referencia', p_cobro->>'proyecto_id', auth.uid())
        returning id into v_id;
        for v_a in select value from jsonb_array_elements(coalesce(p_cobro->'aplicaciones', '[]'::jsonb)) loop
          insert into aplicaciones_cobro (cobro_id, factura_id, proyecto_id, monto, es_retencion, descuento)
          values (v_id, (v_a->>'factura_id')::bigint,
                  coalesce(v_a->>'proyecto_id', (select f.proyecto_id from facturas f where f.id = (v_a->>'factura_id')::bigint)),
                  (v_a->>'monto')::numeric, coalesce((v_a->>'es_retencion')::boolean, false),
                  coalesce((v_a->>'descuento')::numeric, 0));
        end loop;
        return jsonb_build_object('cobro', v_id, 'minima', true);
      end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_cobro_anular(uuid,text)') is null then
    execute $f$
      create function public.fn_cobro_anular(p_cobro uuid, p_motivo text) returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno();
                   update cobros set estado = 'anulado', anulado_el = now(), anulado_motivo = coalesce(p_motivo, '-')
                    where id = p_cobro;
                   return jsonb_build_object('minima', true); end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_anticipo_aplicar(uuid,bigint,text,date)') is null then
    execute $f$
      create function public.fn_anticipo_aplicar(p_cobro uuid, p_factura bigint, p_monto text, p_fecha date default null)
      returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno(); return jsonb_build_object('minima', true); end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_recibo_anular(bigint,text)') is null then
    execute $f$
      create function public.fn_recibo_anular(p_id bigint, p_motivo text) returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno();
                   update recibos set estado = 'anulado' where id = p_id;
                   return jsonb_build_object('minima', true); end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_externo_anular(bigint,text)') is null then
    execute $f$
      create function public.fn_externo_anular(p_id bigint, p_motivo text) returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno();
                   update trabajos_externos set costo = 0 where id = p_id;
                   return jsonb_build_object('minima', true); end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_horas_devengar(text)') is null then
    execute $f$
      create function public.fn_horas_devengar(p_mes text) returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno(); return jsonb_build_object('minima', true); end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_puentes_antes_del_corte(text,bigint,text)') is null then
    execute $f$
      create function public.fn_puentes_antes_del_corte(p_tabla text, p_id bigint, p_motivo text) returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno(); return jsonb_build_object('minima', true); end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_puentes_confirmar(text,bigint,text,text)') is null then
    execute $f$
      create function public.fn_puentes_confirmar(p_tabla text, p_id bigint, p_codigo text, p_motivo text) returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno(); return jsonb_build_object('minima', true); end $b$
    $f$;
  end if;
  if to_regprocedure('public.fn_recibo_desanular(bigint,text)') is null then
    execute $f$
      create function public.fn_recibo_desanular(p_id bigint, p_motivo text) returns jsonb
      language plpgsql security definer set search_path = public, pg_temp
      as $b$ begin perform fn_puente_exigir_dueno();
                   update recibos set estado = 'leido' where id = p_id;
                   return jsonb_build_object('minima', true); end $b$
    $f$;
  end if;

  execute 'revoke execute on function public.fn_puentes_correr(date) from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_puentes_rehacer(text, text, text) from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_puentes_verificar() from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_factura_anular(bigint, text, date) from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_cobro_registrar(jsonb) from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_cobro_anular(uuid, text) from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_anticipo_aplicar(uuid, bigint, text, date) from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_horas_devengar(text) from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_recibo_anular(bigint, text) from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_externo_anular(bigint, text) from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_puentes_antes_del_corte(text, bigint, text) from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_puentes_confirmar(text, bigint, text, text) from public, anon, authenticated, service_role';
  execute 'revoke execute on function public.fn_recibo_desanular(bigint, text) from public, anon, authenticated, service_role';
  execute 'grant execute on function public.fn_puentes_correr(date) to authenticated';
  execute 'grant execute on function public.fn_puentes_rehacer(text, text, text) to authenticated';
  execute 'grant execute on function public.fn_puentes_verificar() to authenticated';
  execute 'grant execute on function public.fn_factura_anular(bigint, text, date) to authenticated';
  execute 'grant execute on function public.fn_cobro_registrar(jsonb) to authenticated';
  execute 'grant execute on function public.fn_cobro_anular(uuid, text) to authenticated';
  execute 'grant execute on function public.fn_anticipo_aplicar(uuid, bigint, text, date) to authenticated';
  execute 'grant execute on function public.fn_horas_devengar(text) to authenticated';
  execute 'grant execute on function public.fn_recibo_anular(bigint, text) to authenticated';
  execute 'grant execute on function public.fn_externo_anular(bigint, text) to authenticated';
  execute 'grant execute on function public.fn_puentes_antes_del_corte(text, bigint, text) to authenticated';
  execute 'grant execute on function public.fn_puentes_confirmar(text, bigint, text, text) to authenticated';
  execute 'grant execute on function public.fn_recibo_desanular(bigint, text) to authenticated';
end $$;

-- ==== BLOQUE B ====
-- =====================================================================
-- Los controles. Todo se puede volver a pegar: funciones con «create or
-- replace», triggers con «create or replace trigger» (los de restricción,
-- que no lo admiten, se borran y se crean dentro de la misma transacción
-- del pegado: nadie ve un instante sin ellos), restricciones e índices
-- solo si faltan.
--
-- LOS CANDADOS, en este orden siempre (el mismo que el libro de c2): la
-- fila del papel (el trigger ya la tiene; el backfill la toma «skip
-- locked» y salta la que está en uso), las filas de periodos «for share»
-- (todas, ANTES del primer asiento: un papel que cambia deja un reverso y
-- un asiento nuevo, y si la segunda fila se pidiera con el candado de la
-- cadena ya puesto, un cierre de mes en curso se trabaría con él) y, al
-- postear, el candado de la cadena de c2.
-- =====================================================================

-- ---------------------------------------------------------------------
-- B.1 · Las ayudantes (internas: fn_puente_…, sin grant a nadie de la API).
-- ---------------------------------------------------------------------

-- ¿Es una cuenta de MANO DE OBRA? El bloque 50xx del plan (c1): 5000 y
-- 5001 la mano de obra directa, 5010-5019 su burden. Ningún puente de papel
-- carga ahí: los dólares de mano de obra solo salen del journal de nómina
-- (f11) o del devengo estándar reversible (fn_horas_devengar). Un recibo
-- nunca es mano de obra (el ayudante por horas es un trabajo externo, 5200).
create or replace function public.fn_puente_es_mano_de_obra(p_cuenta text)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  select coalesce(left(p_cuenta, 2) = '50', false)
$$;
revoke execute on function public.fn_puente_es_mano_de_obra(text) from public, anon, authenticated, service_role;

-- ¿Puede ir una línea a esta cuenta hoy? Nulo = sí; si no, el porqué en
-- llano (el libro lo pararía igual, con MX004; así lo dice la bandeja).
create or replace function public.fn_puente_cuenta_mal(p_cuenta text)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select case when p_cuenta is null then 'no hay cuenta'
              when c.codigo is null then format('la cuenta %s no existe en el plan', p_cuenta)
              when not c.activa then format('la cuenta %s (%s) está inactiva', c.codigo, c.nombre)
              when not c.imputable then format('la cuenta %s (%s) es de grupo: va a una de sus subcuentas', c.codigo, c.nombre)
         end
    from (select p_cuenta as q) x
    left join cuentas c on c.codigo = x.q
$$;
revoke execute on function public.fn_puente_cuenta_mal(text) from public, anon, authenticated, service_role;

-- La fecha contable de un papel, con la regla del documento tardío (§5.7
-- del plan): si su mes está abierto, su fecha; si está cerrado, el primer
-- día del primer mes abierto posterior, con la nota; y si ese mes abierto
-- es de un año posterior al del papel, como ajuste de su ejercicio
-- (ajuste_cpa, afecta_periodo = el mes cerrado del papel): el mismo
-- criterio que c2 aplica al reverso de un ejercicio anterior. Si no hay
-- período para la fecha, la devuelve tal cual: el libro dirá por qué no
-- entra (MX002), y el papel quedará en la bandeja con ese mensaje.
create or replace function public.fn_puente_fecha(p_fecha date)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_per     periodos;
  v_abierto date;
begin
  select * into v_per from periodos p where p.tipo <> 'anio' and p_fecha between p.desde and p.hasta;
  if not found or v_per.estado = 'abierto' then
    return jsonb_build_object('fecha', p_fecha, 'tipo', 'normal');
  end if;
  select min(p.desde) into v_abierto
    from periodos p
   where p.tipo = 'mes' and p.estado = 'abierto' and p.desde > p_fecha;
  if v_abierto is null then
    return jsonb_build_object('fecha', p_fecha, 'tipo', 'normal');
  end if;
  if extract(year from v_abierto) > extract(year from p_fecha) then
    return jsonb_build_object(
      'fecha', v_abierto, 'tipo', 'ajuste_cpa', 'afecta_periodo', v_per.periodo,
      'nota', format('Documento tardío del %s: su mes (%s) ya estaba cerrado y es de %s, un ejercicio anterior. Entra el %s '
                     'como ajuste de ese ejercicio (ajuste_cpa, afecta_periodo %s), para que no caiga en el resultado de %s.',
                     p_fecha, v_per.periodo, extract(year from p_fecha), v_abierto, v_per.periodo, extract(year from v_abierto)));
  end if;
  return jsonb_build_object(
    'fecha', v_abierto, 'tipo', 'normal',
    'nota', format('Documento tardío del %s: su mes (%s) ya estaba cerrado. Entra el primer día del período abierto (%s), '
                   'como dice §5.7 del plan.', p_fecha, v_per.periodo, v_abierto));
end $$;
revoke execute on function public.fn_puente_fecha(date) from public, anon, authenticated, service_role;

-- El asiento VIVO de un papel (sin su reverso de corrección), si lo hay.
create or replace function public.fn_puente_vivo(p_tabla text, p_id text)
returns public.asientos
language sql
stable
set search_path = public, pg_temp
as $$
  select a.*
    from asientos a
   where a.origen_tabla = p_tabla and a.origen_id = p_id
     and a.camino not in ('reverso', 'reverso_automatico')
     and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
   order by a.cadena_pos desc
   limit 1
$$;
revoke execute on function public.fn_puente_vivo(text, text) from public, anon, authenticated, service_role;

-- El asiento reversado de un papel que todavía no tiene sustituto: el
-- asiento nuevo de ese papel tiene que decir que lo sustituye (c2, B.8).
create or replace function public.fn_puente_sustituible(p_tabla text, p_id text)
returns uuid
language sql
stable
set search_path = public, pg_temp
as $$
  select a.id
    from asientos a
   where a.origen_tabla = p_tabla and a.origen_id = p_id
     and a.camino not in ('reverso', 'reverso_automatico')
     and exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
     and not exists (select 1 from asientos s where s.sustituye_a = a.id)
   order by a.cadena_pos desc
   limit 1
$$;
revoke execute on function public.fn_puente_sustituible(text, text) from public, anon, authenticated, service_role;

-- ¿Está (o estuvo) este papel en el libro? Los números de los asientos que
-- lo nombran, como origen o como partida («asiento 2026-000012» o
-- «asientos 2026-000012, 2026-000015»); nulo si ninguno. Lo usan las
-- guardas: un papel con asientos, aunque estén reversados, es el rastro de
-- esos asientos y no se borra.
create or replace function public.fn_puente_en_libro(p_tabla text, p_id text)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select case when count(*) = 1 then 'asiento ' else 'asientos ' end || string_agg(x.numero, ', ' order by x.pos)
    from (select a.numero, a.cadena_pos as pos
            from asientos a
           where a.origen_tabla = p_tabla and a.origen_id = p_id
          union
          select a.numero, a.cadena_pos
            from asiento_lineas l
            join asientos a on a.id = l.asiento_id
           where l.partida_tabla = p_tabla and l.partida_id = p_id) x
  having count(*) > 0
$$;
revoke execute on function public.fn_puente_en_libro(text, text) from public, anon, authenticated, service_role;

-- ¿Lo nombra la APERTURA? El asiento de apertura (f04) abre una partida
-- por cada papel de la app que seguía abierto al 30-sep (en 2010, partida
-- recibos/<id> o trabajos_externos/<id>), y un ajuste a la apertura (tipo
-- ajuste_cpa, afecta_periodo = la apertura) o un reverso de esos la
-- corrigen. Devuelve lo que todo eso deja en la partida (saldo, en qué
-- asientos, a quién); nulo si no la nombra o si ya quedó en cero. Un papel
-- que la apertura nombra ya está en el libro: su puente no lo vuelve a
-- meter.
create or replace function public.fn_puente_en_apertura(p_tabla text, p_id text)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
           'saldo',    sum(l.monto),
           'asientos', string_agg(distinct a.numero, ', '),
           'a_quien',  coalesce(min(pr.nombre), min(pe.nombre), '-'),
           'apertura', (select p.periodo from periodos p where p.tipo = 'apertura' order by p.desde limit 1))
    from asiento_lineas l
    join asientos a on a.id = l.asiento_id
    left join asientos o on o.id = a.reversa_a
    left join proveedores pr on l.tercero_tipo = 'proveedor' and pr.id::text = l.tercero_id
    left join perfiles pe on l.tercero_tipo = 'empleado' and pe.id::text = l.tercero_id
   where l.partida_tabla = p_tabla and l.partida_id = p_id
     and exists (select 1 from periodos p
                  where p.tipo = 'apertura' and p.periodo in (a.periodo, a.afecta_periodo, o.periodo, o.afecta_periodo))
  having sum(l.monto) <> 0
$$;
revoke execute on function public.fn_puente_en_apertura(text, text) from public, anon, authenticated, service_role;

-- ¿Es una cuenta de BANCO (o de efectivo)? El bloque 10xx del plan de c1
-- (1010 la operativa, 1020 la de nómina, 1030 la reserva, y sus
-- subcuentas): de activo, deudora y sin obra. Un cobro entra ahí, y una
-- forma de pago «banco» sale de ahí; no de la depreciación acumulada, ni de
-- la cuenta del accionista, ni de la bodega.
create or replace function public.fn_puente_es_banco(p_cuenta text)
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce((select left(c.codigo, 2) = '10' and c.tipo = 'activo' and c.saldo_normal = 'debe' and c.regla_obra = 'prohibida'
                     from cuentas c where c.codigo = p_cuenta), false)
$$;
revoke execute on function public.fn_puente_es_banco(text) from public, anon, authenticated, service_role;

-- ¿Puede la cuenta de un puente (puente_cuentas) ser esta, por lo que es?
-- Nulo = sí; si no, el porqué en llano. Además de existir, estar activa y
-- no ser de grupo: la de cobrar es una cuenta por cobrar a clientes (11xx,
-- deudora, por obra); la del banco, un banco; las que se deben, un pasivo;
-- la de subcontratos, un costo por obra; y solo las de mano de obra son
-- del bloque 50xx. La usan la guarda de las reglas y el control reglas.
create or replace function public.fn_puente_cuenta_rol_mal(p_rol text, p_cuenta text)
returns text
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_c   cuentas;
  v_mal text := fn_puente_cuenta_mal(p_cuenta);
begin
  if v_mal is not null then
    return v_mal;
  end if;
  select * into v_c from cuentas where codigo = p_cuenta;
  if fn_puente_es_mano_de_obra(v_c.codigo) <> (p_rol in ('mano_obra', 'mano_obra_oficial')) then
    return case when p_rol in ('mano_obra', 'mano_obra_oficial')
                then format('%s (%s) no es una cuenta de mano de obra (50xx)', v_c.codigo, v_c.nombre)
                else format('%s (%s) es mano de obra (50xx), y ningún otro puente carga ahí', v_c.codigo, v_c.nombre) end;
  end if;
  return case
    when p_rol in ('cxc', 'retencion_cxc')
         and not (left(v_c.codigo, 2) = '11' and v_c.tipo = 'activo' and v_c.saldo_normal = 'debe' and v_c.regla_obra <> 'prohibida')
      then format('%s (%s) no es una cuenta por cobrar a clientes (11xx, deudora, por obra)', v_c.codigo, v_c.nombre)
    when p_rol = 'banco' and not fn_puente_es_banco(v_c.codigo)
      then format('%s (%s) no es una cuenta de banco (10xx, de activo, sin obra)', v_c.codigo, v_c.nombre)
    when p_rol in ('cxp', 'reembolso_dueno', 'reembolso_empleado', 'sueldos_devengados', 'use_tax')
         and not (v_c.tipo = 'pasivo' and v_c.saldo_normal = 'haber')
      then format('%s (%s) no es un pasivo, y lo que se debe va a una cuenta de pasivo', v_c.codigo, v_c.nombre)
    when p_rol in ('subcontratos', 'mano_obra', 'mano_obra_oficial') and not (v_c.tipo = 'costo' and v_c.regla_obra = 'obligatoria')
      then format('%s (%s) no es un costo por obra', v_c.codigo, v_c.nombre)
  end;
end $$;
revoke execute on function public.fn_puente_cuenta_rol_mal(text, text) from public, anon, authenticated, service_role;

-- ¿Puede un RECIBO cargar a esta cuenta (la de su categoría)? Nulo = sí.
-- Un recibo compra algo: un costo, un gasto, u otro gasto, o un activo que
-- se compra (la bodega 13xx, un seguro o una fianza pagados por adelantado
-- 14xx, un activo fijo 15xx, un depósito 16xx). Nunca un banco (el dinero
-- sale de ahí: eso es la forma de pago), ni una cuenta por cobrar (11xx), ni
-- el WIP (12xx), ni una cuenta de saldo acreedor (la depreciación
-- acumulada, una contra-cuenta, un pasivo), ni la mano de obra (50xx: solo
-- nómina o devengo estándar). La usan la guarda de las reglas, el plan del
-- recibo y el control reglas.
create or replace function public.fn_puente_cuenta_gasto_mal(p_cuenta text)
returns text
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_c   cuentas;
  v_mal text := fn_puente_cuenta_mal(p_cuenta);
begin
  if v_mal is not null then
    return v_mal;
  end if;
  select * into v_c from cuentas where codigo = p_cuenta;
  if fn_puente_es_mano_de_obra(v_c.codigo) then
    return format('%s (%s) es mano de obra, y esa solo entra por la nómina (f11) o por el devengo estándar', v_c.codigo, v_c.nombre);
  end if;
  if v_c.saldo_normal <> 'debe' then
    return format('%s (%s) es de saldo acreedor (una contra-cuenta o algo que se debe): un recibo carga un costo, un gasto o un '
                  'activo que se compra', v_c.codigo, v_c.nombre);
  end if;
  if v_c.tipo in ('costo', 'gasto', 'otro_gasto')
     or (v_c.tipo = 'activo' and left(v_c.codigo, 2) in ('13', '14', '15', '16')) then
    return null;
  end if;
  return case
    when v_c.tipo = 'activo' and left(v_c.codigo, 2) = '10'
      then format('%s (%s) es un banco: un recibo no carga al banco, el dinero sale de él (eso lo dice su forma de pago)',
                  v_c.codigo, v_c.nombre)
    when v_c.tipo = 'activo' and left(v_c.codigo, 2) = '11'
      then format('%s (%s) es una cuenta por cobrar: un recibo es algo que se compra, no algo que se cobra', v_c.codigo, v_c.nombre)
    when v_c.tipo = 'activo'
      then format('%s (%s) no es un activo que se compra (la bodega 13xx, un prepagado 14xx, un activo fijo 15xx, un depósito 16xx)',
                  v_c.codigo, v_c.nombre)
    else format('la cuenta %s (%s) es de %s: un recibo carga un costo, un gasto o un activo que se compra', v_c.codigo, v_c.nombre,
                v_c.tipo)
  end;
end $$;
revoke execute on function public.fn_puente_cuenta_gasto_mal(text) from public, anon, authenticated, service_role;

-- Las cuentas INACTIVAS de un asiento («2100-4417 (Amex 4417)»), o nulo.
-- Un reverso de puente sin asiento nuevo no se pone sobre ellas: dejaría
-- ahí un saldo que ya nadie podría mover (c1: con saldo vivo no se
-- inactiva, y un reverso tampoco tendría a dónde ir).
create or replace function public.fn_puente_cuentas_inactivas(p_asiento uuid)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select string_agg(distinct format('%s (%s)', c.codigo, c.nombre), ', ')
    from asiento_lineas l
    join cuentas c on c.codigo = l.cuenta
   where l.asiento_id = p_asiento and not c.activa
$$;
revoke execute on function public.fn_puente_cuentas_inactivas(uuid) from public, anon, authenticated, service_role;

-- Lo que Edgar confirmó de un papel (puente_revisados) para ese código y
-- ese dato, si lo confirmó.
create or replace function public.fn_puente_revisado(p_tabla text, p_id text, p_codigo text, p_dato text)
returns public.puente_revisados
language sql
stable
set search_path = public, pg_temp
as $$
  select * from puente_revisados
   where tabla = p_tabla and documento_id = p_id and codigo = p_codigo and dato = p_dato
   limit 1
$$;
revoke execute on function public.fn_puente_revisado(text, text, text, text) from public, anon, authenticated, service_role;

-- La llave del TICKET de un recibo: su proveedor, su número y su total,
-- sin adornos (solo letras y dígitos, en minúsculas: «HD-4471-0092» y
-- «hd 4471 0092» son el mismo número). Nula si falta alguno (o el total es
-- 0): sin los tres no se puede decir que dos recibos son el mismo ticket.
create or replace function public.fn_puente_recibo_clave(p_proveedor text, p_num text, p_total numeric)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case when x.prov is not null and x.num is not null and p_total is not null and round(p_total, 2) <> 0
              then x.prov || '|' || x.num || '|' || round(p_total, 2)::text end
    from (select nullif(regexp_replace(lower(coalesce(p_proveedor, '')), '[^0-9a-z]', '', 'g'), '') as prov,
                 nullif(regexp_replace(lower(coalesce(p_num, '')), '[^0-9a-z]', '', 'g'), '') as num) x
$$;
revoke execute on function public.fn_puente_recibo_clave(text, text, numeric) from public, anon, authenticated, service_role;

-- ¿Es la foto de OTRO en el almacén? Un archivo de fotos/ con ese nombre
-- que subió otra persona (su dueño en Storage no es quien llama). Sin
-- Storage (el banco de pruebas sin su simulacro), o si no se puede mirar,
-- no: la guarda sigue con lo demás. Un archivo que todavía no existe
-- tampoco: la lectura no tendría nada que leer.
create or replace function public.fn_puente_foto_ajena(p_ruta text)
returns boolean
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_ajena boolean := false;
  v_dueno text;
begin
  if to_regclass('storage.objects') is null or p_ruta is null then
    return false;
  end if;
  -- El dueño del archivo: owner (uuid), o owner_id (texto) donde exista.
  v_dueno := case when exists (select 1 from pg_attribute a
                                where a.attrelid = to_regclass('storage.objects') and a.attname = 'owner_id' and not a.attisdropped)
                  then 'coalesce(o.owner::text, o.owner_id::text)' else 'o.owner::text' end;
  begin
    execute format('select exists (select 1 from storage.objects o where o.bucket_id = ''fotos'' and o.name = $1 '
                   'and %1$s is not null and %1$s is distinct from $2)', v_dueno)
      into v_ajena using p_ruta, auth.uid()::text;
  exception when insufficient_privilege or undefined_column or undefined_table then
    v_ajena := false;
  end;
  return coalesce(v_ajena, false);
end $$;
revoke execute on function public.fn_puente_foto_ajena(text) from public, anon, authenticated, service_role;

-- Qué cambió en el papel entre lo que se contabilizó y lo de hoy, en
-- llano: «total: 243.57 → 245.37; proyecto_id: a → b». Va en el motivo del
-- reverso y en la procedencia del sustituto.
create or replace function public.fn_puente_cambios(p_antes jsonb, p_despues jsonb)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select coalesce(string_agg(format('%s: %s → %s', k, coalesce(p_antes->>k, '(nada)'), coalesce(p_despues->>k, '(nada)')),
                             '; ' order by k), 'sin diferencias en el papel')
    from (select jsonb_object_keys(coalesce(p_antes, '{}'::jsonb) || coalesce(p_despues, '{}'::jsonb)) as k) x
   where (p_antes->x.k) is distinct from (p_despues->x.k)
$$;
revoke execute on function public.fn_puente_cambios(jsonb, jsonb) from public, anon, authenticated, service_role;

-- Un plan que no postea: el estado, el código y el motivo en llano.
create or replace function public.fn_puente_plan_no(p_accion text, p_codigo text, p_motivo text, p_firma text, p_doc jsonb)
returns jsonb
language sql
immutable
set search_path = public, pg_temp
as $$
  select jsonb_build_object('accion', p_accion, 'codigo', p_codigo, 'motivo', p_motivo, 'firma', p_firma, 'documento', p_doc)
$$;
revoke execute on function public.fn_puente_plan_no(text, text, text, text, jsonb) from public, anon, authenticated, service_role;

-- Apunta en qué quedó el papel (puente_documentos) y, en su tabla, su
-- asiento vivo (contabilizado_en). Solo escribe si algo cambió: correr el
-- puente dos veces no mueve nada. La guarda de cada papel solo deja tocar
-- contabilizado_en con la marca mx_puente.escribe = 'tabla:id'.
create or replace function public.fn_puente_marcar(p_tabla text, p_id text, p_estado text, p_codigo text, p_motivo text,
                                                   p_asiento uuid, p_firma text)
returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  insert into puente_documentos (tabla, documento_id, estado, codigo, motivo, asiento_id, firma)
  values (p_tabla, p_id, p_estado, p_codigo, p_motivo, p_asiento, p_firma)
  on conflict (tabla, documento_id) do update
     set estado = excluded.estado, codigo = excluded.codigo, motivo = excluded.motivo,
         asiento_id = excluded.asiento_id, firma = excluded.firma,
         intentos = puente_documentos.intentos + 1, actualizado = clock_timestamp()
   where (puente_documentos.estado, puente_documentos.codigo, puente_documentos.motivo,
          puente_documentos.asiento_id, puente_documentos.firma)
         is distinct from (excluded.estado, excluded.codigo, excluded.motivo, excluded.asiento_id, excluded.firma);
  if p_tabla in ('recibos', 'facturas', 'trabajos_externos', 'cobros', 'aplicaciones_cobro', 'notas_credito') then
    perform set_config('mx_puente.escribe', p_tabla || ':' || p_id, true);
    execute format('update public.%I set contabilizado_en = $1 where id = $2::%s and contabilizado_en is distinct from $1',
                   p_tabla, case when p_tabla in ('cobros', 'aplicaciones_cobro', 'notas_credito') then 'uuid' else 'bigint' end)
      using p_asiento, p_id;
    perform set_config('mx_puente.escribe', '', true);
  end if;
end $$;
revoke execute on function public.fn_puente_marcar(text, text, text, text, text, uuid, text) from public, anon, authenticated, service_role;

-- Un intento que el libro rechazó: queda en la bandeja con su código y su
-- mensaje, y con el asiento vivo que tuviera (el intento no tocó nada).
create or replace function public.fn_puente_marcar_error(p_tabla text, p_id text, p_codigo text, p_mensaje text)
returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_vivo asientos;
begin
  v_vivo := fn_puente_vivo(p_tabla, p_id);
  insert into puente_documentos (tabla, documento_id, estado, codigo, motivo, asiento_id)
  values (p_tabla, p_id, 'error', p_codigo, left(p_mensaje, 1000), v_vivo.id)
  on conflict (tabla, documento_id) do update
     set estado = 'error', codigo = excluded.codigo, motivo = excluded.motivo, asiento_id = excluded.asiento_id,
         intentos = puente_documentos.intentos + 1, actualizado = clock_timestamp();
end $$;
revoke execute on function public.fn_puente_marcar_error(text, text, text, text) from public, anon, authenticated, service_role;


-- ---------------------------------------------------------------------
-- B.2 · Las reglas: su guarda y su historial.
--   · La guarda valida al escribir (por la función o por el SQL Editor):
--     una categoría carga un costo, un gasto o un activo que se compra
--     (13xx-16xx), nunca un pasivo (así nunca 2300 desde un recibo), ni
--     un banco, ni una cuenta por cobrar, ni una de saldo acreedor como la
--     depreciación acumulada (fn_puente_cuenta_gasto_mal); su cuenta sin
--     obra, igual, y no exige obra; un banco es un banco (el bloque 10xx:
--     no la depreciación acumulada, ni la cuenta del accionista, ni la
--     bodega); una tarjeta es un pasivo o un banco (la débito), nunca la
--     cuenta de otro papel de los puentes (cuentas por pagar, use tax,
--     sueldos devengados…), y si es la de reembolsos a empleados dice de
--     quién; un tipo de obra lleva a un ingreso por obra; y cada cuenta de
--     los puentes es de su clase (fn_puente_cuenta_rol_mal: cobrar = 11xx,
--     banco = 10xx, lo que se debe = pasivo, subcontratos = costo por
--     obra, 50xx solo la mano de obra) y es SOLO suya: dos papeles no
--     comparten cuenta. La cuenta tiene que existir, estar activa y no ser
--     de grupo.
--   · El historial apunta cada alta, cambio y baja (después de escrita:
--     si no entra, no queda). No se edita ni se borra.
-- ---------------------------------------------------------------------
create or replace function public.fn_puente_reglas_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_c   cuentas;
  v_mal text;
begin
  if tg_table_name = 'mapeo_categoria_recibo' then
    -- Un recibo compra algo: costo, gasto o un activo que se compra; nunca
    -- el banco, una cuenta por cobrar ni una de saldo acreedor
    -- (fn_puente_cuenta_gasto_mal).
    v_mal := fn_puente_cuenta_gasto_mal(new.cuenta);
    if v_mal is null and new.cuenta_sin_obra is not null then
      v_mal := fn_puente_cuenta_gasto_mal(new.cuenta_sin_obra);
      if v_mal is null then
        select * into v_c from cuentas where codigo = new.cuenta_sin_obra;
        if v_c.regla_obra = 'obligatoria' then
          v_mal := format('la cuenta sin obra %s (%s) exige obra', v_c.codigo, v_c.nombre);
        end if;
      end if;
      if v_mal is not null then
        v_mal := 'su cuenta sin obra: ' || v_mal;
      end if;
    end if;
    if v_mal is not null then
      raise exception using errcode = 'MX004', message = format('La categoría «%s» no puede ir ahí: %s.', new.categoria, v_mal);
    end if;

  elsif tg_table_name = 'mapeo_metodo_pago' then
    if new.cuenta is not null then
      v_mal := fn_puente_cuenta_mal(new.cuenta);
      if v_mal is null then
        select * into v_c from cuentas where codigo = new.cuenta;
        if new.forma = 'banco' and not fn_puente_es_banco(v_c.codigo) then
          v_mal := format('%s (%s) no es una cuenta de banco (10xx, de activo, sin obra)', v_c.codigo, v_c.nombre);
        elsif v_c.tipo not in ('activo', 'pasivo')
              or (v_c.tipo = 'activo' and not fn_puente_es_banco(v_c.codigo))
              or exists (select 1 from puente_cuentas pc
                          where pc.cuenta = v_c.codigo and pc.rol not in ('banco', 'reembolso_dueno', 'reembolso_empleado')) then
          -- (Ni la cuenta de otro papel de los puentes: la de por pagar a
          -- proveedores, la de use tax, la de sueldos devengados…)
          v_mal := format('%s (%s) no es de donde sale un pago (un banco, o lo que se le debe a quien pagó)', v_c.codigo, v_c.nombre);
        end if;
      end if;
      if v_mal is not null then
        raise exception using errcode = 'MX004', message = format('La forma de pago «%s» no puede ir ahí: %s.', new.metodo_pago, v_mal);
      end if;
    end if;

  elsif tg_table_name = 'mapeo_tipo_proyecto' then
    v_mal := fn_puente_cuenta_mal(new.cuenta);
    if v_mal is null then
      select * into v_c from cuentas where codigo = new.cuenta;
      if v_c.tipo <> 'ingreso' or v_c.regla_obra = 'prohibida' then
        v_mal := format('%s (%s) no es un ingreso por obra', v_c.codigo, v_c.nombre);
      end if;
    end if;
    if v_mal is not null then
      raise exception using errcode = 'MX004', message = format('El tipo de obra «%s» no puede ir ahí: %s.', new.tipo, v_mal);
    end if;

  elsif tg_table_name = 'tarjetas' then
    v_mal := fn_puente_cuenta_mal(new.cuenta);
    if v_mal is null then
      select * into v_c from cuentas where codigo = new.cuenta;
      if v_c.tipo not in ('activo', 'pasivo') or v_c.regla_obra <> 'prohibida'
         or (v_c.tipo = 'activo' and not fn_puente_es_banco(v_c.codigo))
         or exists (select 1 from puente_cuentas pc
                     where pc.cuenta = v_c.codigo and pc.rol not in ('banco', 'reembolso_dueno', 'reembolso_empleado')) then
        v_mal := format('%s (%s) no es la cuenta de una tarjeta (una 2100-XXXX, el banco, 2900 o 2250)', v_c.codigo, v_c.nombre);
      elsif v_c.codigo = fn_puente_cuenta_de('reembolso_empleado')
            and (new.empleado_id is null or not exists (select 1 from perfiles p where p.id = new.empleado_id)) then
        v_mal := 'la tarjeta de un empleado dice de quién es (empleado_id, un perfil que existe)';
      end if;
    end if;
    if v_mal is not null then
      raise exception using errcode = 'MX004', message = format('La tarjeta %s no puede ir ahí: %s.', new.ultimos4, v_mal);
    end if;

  elsif tg_table_name = 'puente_cuentas' then
    v_mal := fn_puente_cuenta_rol_mal(new.rol, new.cuenta);
    -- Y cada papel con su propia cuenta: con sueldos_devengados en 2010, el
    -- devengo caía en cuentas por pagar sin proveedor ni partida, y la CxP
    -- por proveedor ya no cuadraba con el mayor.
    if v_mal is null then
      select format('%s ya es la cuenta del puente «%s»: cada papel de los puentes tiene la suya', pc.cuenta, pc.rol)
        into v_mal
        from puente_cuentas pc
       where pc.cuenta = new.cuenta and pc.rol <> new.rol
       order by pc.rol
       limit 1;
    end if;
    if v_mal is not null then
      raise exception using errcode = 'MX004', message = format('La cuenta del puente «%s» no puede ser esa: %s.', new.rol, v_mal);
    end if;

  elsif tg_table_name = 'proveedores' then
    if new.externo_id is not null and not exists (select 1 from externos_equipo e where e.id = new.externo_id) then
      raise exception using errcode = '22023', message = format('No existe el ayudante %s en externos_equipo.', new.externo_id);
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.fn_puente_reglas_guarda() from public, anon, authenticated, service_role;

create or replace function public.fn_puente_reglas_historial()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE' and to_jsonb(new) = to_jsonb(old) then
    return null;
  end if;
  insert into puente_reglas_historial (tabla, clave, operacion, usuario_id, rol, antes, despues)
  values (tg_table_name,
          case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end ->> tg_argv[0],
          tg_op, auth.uid(), fn_rol_llamante(),
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  return null;
end $$;
revoke execute on function public.fn_puente_reglas_historial() from public, anon, authenticated, service_role;

-- Lo que solo se añade (los historiales) y los papeles de dinero que nacen
-- aquí (cobros, aplicaciones, notas de crédito): no se editan ni se borran.
-- Un cobro solo cambia para anularse (fn_cobro_anular) o para casarse con
-- su movimiento del banco (f06: movimiento_id, de nulo a su valor); y todos
-- dejan poner su asiento vivo al puente (contabilizado_en).
create or replace function public.fn_puente_papeles_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_marca text := coalesce(current_setting('mx_puente.escribe', true), '');
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003', message = format('%s no se trunca: es rastro del libro.', tg_table_name);
  end if;
  if tg_table_name in ('puente_reglas_historial', 'horas_aprobaciones', 'puente_revisados') then
    raise exception using errcode = 'MX003',
      message = format('%s no se edita ni se borra (%s): es el rastro de cada cambio.', tg_table_name, tg_op);
  end if;
  if tg_op = 'DELETE' then
    raise exception using errcode = 'MX003',
      message = format('Un papel de dinero no se borra (%s): %s', tg_table_name,
                       case tg_table_name when 'cobros' then 'un cobro se anula con fn_cobro_anular y se registra el bueno.'
                                          else 'se anula lo que lo originó, y el libro lo reversa.' end);
  end if;
  -- UPDATE
  if tg_table_name = 'cobros' then
    if (to_jsonb(new) - array['contabilizado_en', 'estado', 'anulado_el', 'anulado_motivo', 'movimiento_id'])
       is distinct from (to_jsonb(old) - array['contabilizado_en', 'estado', 'anulado_el', 'anulado_motivo', 'movimiento_id']) then
      raise exception using errcode = 'MX003',
        message = 'Un cobro no se edita: se anula (fn_cobro_anular) y se registra el bueno.';
    end if;
    if (new.estado, new.anulado_el, new.anulado_motivo) is distinct from (old.estado, old.anulado_el, old.anulado_motivo)
       and not (old.estado = 'vigente' and new.estado = 'anulado' and v_marca = 'cobros_anular:' || old.id) then
      raise exception using errcode = 'MX003', message = 'Un cobro se anula solo con fn_cobro_anular, y no vuelve.';
    end if;
    if new.movimiento_id is distinct from old.movimiento_id and old.movimiento_id is not null then
      raise exception using errcode = 'MX003',
        message = 'El cobro ya está casado con su movimiento del banco: eso no cambia (se anula y se registra el bueno).';
    end if;
  elsif (to_jsonb(new) - 'contabilizado_en') is distinct from (to_jsonb(old) - 'contabilizado_en') then
    raise exception using errcode = 'MX003',
      message = format('%s no se edita: se anula lo que lo originó y el libro lo reversa.', tg_table_name);
  end if;
  if new.contabilizado_en is distinct from old.contabilizado_en and v_marca <> tg_table_name || ':' || old.id then
    raise exception using errcode = 'MX003', message = 'contabilizado_en lo pone solo el puente.';
  end if;
  return new;
end $$;
revoke execute on function public.fn_puente_papeles_guarda() from public, anon, authenticated, service_role;

do $$
declare
  r record;
begin
  -- Las reglas: guarda (antes) e historial (después).
  for r in select * from (values ('mapeo_categoria_recibo', 'mapeo_categoria', 'categoria'),
                                 ('mapeo_metodo_pago',      'mapeo_metodo_pago', 'metodo_pago'),
                                 ('mapeo_tipo_proyecto',    'mapeo_tipo_proyecto', 'tipo'),
                                 ('tarjetas',               'tarjetas', 'ultimos4'),
                                 ('puente_cuentas',         'cuentas', 'rol'),
                                 ('proveedores',            'proveedores', 'id'),
                                 ('proveedores_alias',      'proveedores_alias', 'alias')) as v(tabla, nombre, llave) loop
    if r.tabla <> 'proveedores_alias' then
      execute format('create or replace trigger %I before insert or update on public.%I
                        for each row execute function public.fn_puente_reglas_guarda()',
                     'trg_puente_' || r.nombre || '_guarda', r.tabla);
    end if;
    execute format('create or replace trigger %I after insert or update or delete on public.%I
                      for each row execute function public.fn_puente_reglas_historial(%L)',
                   'trg_puente_' || r.nombre || '_historial', r.tabla, r.llave);
  end loop;
  -- Lo que no se edita ni se borra.
  for r in select * from (values ('puente_reglas_historial', 'reglas_historial'),
                                 ('horas_aprobaciones',      'horas_aprobaciones'),
                                 ('puente_revisados',        'revisados'),
                                 ('cobros',                  'cobros'),
                                 ('aplicaciones_cobro',      'aplicaciones'),
                                 ('notas_credito',           'notas_credito')) as v(tabla, nombre) loop
    execute format('create or replace trigger %I before update or delete on public.%I
                      for each row execute function public.fn_puente_papeles_guarda()',
                   'trg_puente_' || r.nombre || '_guarda', r.tabla);
    execute format('create or replace trigger %I before truncate on public.%I
                      for each statement execute function public.fn_puente_papeles_guarda()',
                   'trg_puente_' || r.nombre || '_sin_truncate', r.tabla);
  end loop;
end $$;

-- Un proveedor con movimientos en el libro (es el tercero de sus líneas de
-- 2010) no se borra ni cambia de id: sin él, su saldo quedaría a nombre de
-- nadie. Se marca inactivo (activo = false) y deja de recibir papeles
-- nuevos. SECURITY DEFINER: tiene que ver todas las líneas del libro.
create or replace function public.fn_puente_proveedores_borrar()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if (tg_op = 'DELETE' or new.id is distinct from old.id)
     and exists (select 1 from asiento_lineas l where l.tercero_tipo = 'proveedor' and l.tercero_id = old.id::text) then
    raise exception using errcode = 'MX003',
      message = format('El proveedor «%s» tiene movimientos en el libro contable: no se borra (ni cambia de id). Si ya no se le '
                       'compra, márcalo inactivo.', old.nombre);
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
revoke execute on function public.fn_puente_proveedores_borrar() from public, anon, authenticated, service_role;

create or replace trigger trg_puente_proveedores_borrar
  before update or delete on public.proveedores
  for each row execute function public.fn_puente_proveedores_borrar();


-- ---------------------------------------------------------------------
-- B.3 · Los planes: qué asiento sale de cada papel TAL COMO ESTÁ HOY, o
-- por qué no sale. No escriben nada. Cada plan trae:
--   accion           postear | pendiente | espera | no_aplica
--   codigo, motivo   por qué no postea (lo que enseña la bandeja)
--   documento, firma los campos del papel que usa el puente, y su md5: si
--                    el papel no cambia, la firma no cambia y el puente no
--                    hace nada (la idempotencia); si cambia, reverso +
--                    asiento nuevo. Las reglas NO entran en la firma: una
--                    regla que cambia no rehace lo ya contabilizado.
--   fecha_documento  la fecha del papel (el puente le aplica la regla del
--                    documento tardío)
--   asiento          lo que se postea: descripción, líneas (montos como
--                    texto, con su escala), origen, papel y procedencia
-- ---------------------------------------------------------------------

-- El recibo. Dr la cuenta de su categoría (5100 el material: por obra, con
-- su co y su cost code si los trae) por el TOTAL con impuesto; Cr según su
-- forma de pago. Nunca a 2300.
-- Lo que ya está en el libro por la apertura no entra otra vez (en_apertura).
-- Una tarjeta o un proveedor INACTIVOS frenan los papeles nuevos, no los que
-- ya se les cargaron: si el recibo ya tiene su asiento con esa tarjeta o
-- ese proveedor (su deuda sigue viva), al corregirlo se le sigue cargando.
-- Lo que no cuadra en el papel se pregunta ANTES de mirar las reglas
-- (cabecera, punto 15): una fecha leída posterior a la subida, DEVOLUCIÓN
-- con el total en positivo, un total que no es subtotal + tax, el mismo
-- ticket en otro recibo. Cada pregunta lleva su «dato»: lo que Edgar
-- confirma con fn_puentes_confirmar (y si el papel cambia ese dato, se
-- vuelve a preguntar).
create or replace function public.fn_puente_recibo_plan(p_id bigint)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  r          recibos;
  v_estado   text;
  v_fecha    date;
  v_subido   date;
  v_corte    date := fn_puente_corte();
  v_doc      jsonb;
  v_firma    text;
  v_total    numeric;
  v_cat      text;
  v_met      text;
  v_forma    text;
  v_prov     text;
  v_cc       text;
  v_u4       text;
  v_u4raw    text;
  v_ruta     text;
  v_devol    boolean;
  v_dato     text;
  v_suma     numeric;
  v_clave    text;
  v_dup      record;
  v_vivo     asientos;
  v_aper     jsonb;
  v_rev      puente_revisados;
  v_mc       mapeo_categoria_recibo;
  v_mm       mapeo_metodo_pago;
  v_t        tarjetas;
  v_pr       proveedores;
  v_obra     proyectos;
  v_debe     text;
  v_cd       cuentas;
  v_haber    text;
  v_mal      text;
  v_ter_tipo text;
  v_ter_id   text;
  v_partida  boolean := false;
  v_memo     text;
  v_ldebe    jsonb;
  v_lhaber   jsonb;
  v_impuesto text;
  v_notas    jsonb := '[]'::jsonb;
  v_reglas   jsonb := '{}'::jsonb;
  v_use_tax  text := fn_puente_cuenta_de('use_tax');
begin
  select * into r from recibos where id = p_id;
  if not found then
    return fn_puente_plan_no('no_aplica', 'no_existe', 'El recibo ya no existe.', null, null);
  end if;
  v_estado := coalesce(r.estado, 'por_leer');
  v_fecha  := coalesce(r.fecha, fn_fecha_miami(r.creado));
  -- El día en que se subió (hora de Miami): el mismo «hoy» que cuenta
  -- cuando la lectura no trae fecha.
  v_subido := fn_fecha_miami(r.creado);
  v_cat    := fn_puente_normalizar(r.categoria);
  v_met    := fn_puente_normalizar(r.metodo_pago);
  v_prov   := fn_puente_normalizar(r.proveedor);
  v_ruta   := nullif(btrim(r.ruta), '');
  -- Los 4 últimos de la tarjeta, como los traiga la lectura («*4417»,
  -- «XXXX4417»): cuentan sus dígitos.
  v_u4raw  := nullif(btrim(r.ultimos4), '');
  v_u4     := fn_puente_ultimos4(r.ultimos4);
  -- f01: el día que recibos traiga cost_code, entra solo (to_jsonb lo lee
  -- si la columna existe; si no, es nulo).
  v_cc     := nullif(btrim(to_jsonb(r)->>'cost_code'), '');
  -- La marca de devolución que la app pone en las notas («DEVOLUCIÓN — …»,
  -- formRecibo y formMano): la ve la rutina, la ve la lista, y la ve el puente.
  v_devol  := coalesce(r.notas, '') ~* 'devoluci';

  -- La firma: lo que el puente usa del papel. leido y conciliado son lo
  -- mismo para el libro (pasar de uno a otro no reversa nada). La foto
  -- (ruta) sí cuenta: el asiento vivo apunta a su papel (documento_ruta), y
  -- si la foto llega o se cambia después, el asiento nuevo la lleva. La
  -- marca de devolución, solo cuando está (así la firma de un recibo sin
  -- ella es la de siempre).
  v_doc := jsonb_build_object(
    'estado',      case when v_estado in ('leido', 'conciliado') then 'leido' else v_estado end,
    'total',       trim_scale(r.total)::text,
    'fecha',       v_fecha,
    'proyecto_id', r.proyecto_id,
    'co',          nullif(btrim(r.co), ''),
    'categoria',   v_cat,
    'metodo_pago', v_met,
    'ultimos4',    v_u4,
    'proveedor',   v_prov,
    'autor_id',    r.autor_id,
    'cost_code',   v_cc,
    'ruta',        v_ruta)
    || case when v_devol then jsonb_build_object('devolucion', true) else '{}'::jsonb end;
  v_firma := md5(v_doc::text);
  v_aper  := fn_puente_en_apertura('recibos', r.id::text);
  v_vivo  := fn_puente_vivo('recibos', r.id::text);

  if v_estado = 'anulado' then
    if v_aper is not null then
      return fn_puente_plan_no('pendiente', 'en_apertura',
        format('Recibo anulado, pero la apertura (%s) lo tiene como deuda con %s por %s: anularlo en la app no la quita. Si de '
               'verdad no se debe, corrige la apertura con un ajuste (tipo ajuste_cpa, afecta_periodo = ''%s'') contra su '
               'partida recibos/%s.', v_aper->>'asientos', v_aper->>'a_quien', abs((v_aper->>'saldo')::numeric),
               v_aper->>'apertura', r.id), v_firma, v_doc);
    end if;
    return fn_puente_plan_no('no_aplica', 'anulado', 'Recibo anulado: no se contabiliza.', v_firma, v_doc);
  end if;
  if v_aper is not null and round(r.total, 2) = 0 then
    return fn_puente_plan_no('pendiente', 'en_apertura',
      format('Total en 0, pero la apertura (%s) lo tiene como deuda con %s por %s: ponerlo en 0 en la app no la quita. Si de '
             'verdad no se debe, corrige la apertura con un ajuste (tipo ajuste_cpa, afecta_periodo = ''%s'') contra su '
             'partida recibos/%s.', v_aper->>'asientos', v_aper->>'a_quien', abs((v_aper->>'saldo')::numeric),
             v_aper->>'apertura', r.id), v_firma, v_doc);
  end if;
  -- Subido ANTES del corte: es de antes del corte, diga lo que diga la
  -- lectura. Un ticket no es de después del día en que se fotografió: una
  -- fecha leída de octubre en un recibo subido el 10 de agosto es un «08/10»
  -- con el mes y el día cruzados, y ese gasto vive en QuickBooks (llega con
  -- la apertura). Así el backfill tampoco mete en el libro nuevo los
  -- recibos viejos mal leídos.
  if v_subido < v_corte then
    return fn_puente_plan_no('no_aplica', 'antes_del_corte',
      format('Subido el %s, antes del corte (%s): ese gasto vive en QuickBooks y llega con la apertura.%s%s', v_subido, v_corte,
             case when r.fecha is not null and r.fecha >= v_corte
                  then format(' La lectura dice %s, pero un recibo no es de después del día en que se subió: esa fecha está mal '
                              'leída (¿mes y día cruzados?).', r.fecha)
                  else '' end,
             case when v_aper is not null then format(' Está en la apertura (%s).', v_aper->>'asientos') else '' end),
      v_firma, v_doc);
  end if;
  if v_fecha < v_corte then
    -- De antes del corte pero SUBIDO después (un año mal leído, o un ticket
    -- de septiembre que llegó tarde, cuando QuickBooks quizá ya cerró el
    -- mes): eso no se calla. Espera a que Edgar corrija la fecha o confirme
    -- que es de antes del corte y está en QuickBooks. Si la apertura ya lo
    -- nombra, está.
    v_dato := to_char(v_fecha, 'YYYY-MM-DD');
    v_rev  := fn_puente_revisado('recibos', r.id::text, 'fecha_antes_del_corte', v_dato);
    if v_aper is null and v_rev.tabla is null then
      if v_estado = 'por_leer' then
        -- Todavía sin leer: la lectura pondrá la fecha del papel. Se pregunta
        -- después, con la fecha leída.
        return fn_puente_plan_no('espera', 'por_leer',
          'Todavía sin leer (por_leer): lo lee la rutina de las 12 y las 6, y la lectura trae la fecha, el total y la forma de '
          'pago.', v_firma, v_doc);
      end if;
      return fn_puente_plan_no('pendiente', 'fecha_antes_del_corte',
        format('Fechado el %s, antes del corte (%s), pero subido el %s: ¿la fecha está bien leída? Si el año o el mes están mal, '
               'corrígela (en el SQL Editor: update recibos set fecha = ''AAAA-MM-DD'' where id = %s;). Si de verdad es de antes '
               'del corte, confirma que está en QuickBooks: select fn_puentes_antes_del_corte(''recibos'', %s, ''motivo'');',
               v_fecha, v_corte, v_subido, r.id, r.id), v_firma, v_doc)
             || jsonb_build_object('dato', v_dato);
    end if;
    return fn_puente_plan_no('no_aplica', 'antes_del_corte',
      format('Fechado el %s, antes del corte (%s): ese gasto vive en QuickBooks y llega con la apertura.%s', v_fecha, v_corte,
             case when v_aper is not null then format(' Está en la apertura (%s).', v_aper->>'asientos')
                  when v_rev.tabla is not null then format(' Subido el %s; Edgar confirmó que es de antes del corte (%s): %s',
                                                           v_subido, (v_rev.revisado_el at time zone 'America/New_York')::date,
                                                           v_rev.motivo)
                  else '' end),
      v_firma, v_doc);
  end if;
  if v_estado = 'por_leer' then
    -- La lectura es la que trae la forma de pago: un total puesto a mano
    -- con ✎ antes de que lea deja el recibo sin ella (la app no tiene dónde
    -- escribirla), y entonces espera a que se la pongan. No es otra forma
    -- de terminar la lectura.
    return fn_puente_plan_no('espera', 'por_leer',
      format('Todavía sin leer (por_leer): lo lee la rutina de las 12 y las 6, y la lectura trae la fecha, el total y la forma de '
             'pago. Si se le pone el total a mano con ✎ antes, queda sin forma de pago (el ✎ no la tiene) y espera a que se la '
             'escriban (update recibos set metodo_pago = ''…'' where id = %s;).', r.id), v_firma, v_doc);
  end if;
  if v_estado = 'sin_foto' then
    return fn_puente_plan_no('pendiente', 'sin_foto',
      'Falta la foto del recibo: súbela con 📷. Un gasto no entra al libro sin su papel.', v_firma, v_doc);
  end if;
  if v_estado not in ('leido', 'conciliado') then
    return fn_puente_plan_no('pendiente', 'estado',
      format('Estado «%s» desconocido para el puente: contabiliza solo recibos leidos o conciliados.', v_estado), v_firma, v_doc);
  end if;
  if r.total is null then
    return fn_puente_plan_no('pendiente', 'sin_total', 'Leído pero sin total: ponle el total con ✎.', v_firma, v_doc);
  end if;
  v_total := round(r.total, 2);
  if v_total = 0 then
    return fn_puente_plan_no('no_aplica', 'total_cero',
      'Total en 0: no suma nada (así se anula un recibo desde la app).', v_firma, v_doc);
  end if;
  -- Ya está en el libro por la apertura (su deuda al 30-sep): no entra otra
  -- vez. Pasa si su fecha se corrige al corte o después.
  if v_aper is not null then
    return fn_puente_plan_no('pendiente', 'en_apertura',
      format('Este recibo ya está en la apertura (%s) como deuda con %s por %s: no entra otra vez por su puente. Si de verdad es '
             'de después del corte, o está mal en la apertura, se corrige la apertura con un ajuste (tipo ajuste_cpa, '
             'afecta_periodo = ''%s'') contra su partida recibos/%s, y entonces entra.', v_aper->>'asientos', v_aper->>'a_quien',
             abs((v_aper->>'saldo')::numeric), v_aper->>'apertura', r.id), v_firma, v_doc);
  end if;

  -- LO QUE NO CUADRA EN EL PAPEL (cabecera, punto 15).
  -- a) Una fecha leída de DESPUÉS del día en que se subió (con un día de
  --    margen, por la hora de la tienda): un ticket no es de después de su
  --    foto. Casi siempre, el mes y el día cruzados.
  if r.fecha is not null and r.fecha > v_subido + 1 then
    v_dato := to_char(r.fecha, 'YYYY-MM-DD');
    v_rev  := fn_puente_revisado('recibos', r.id::text, 'fecha_posterior_a_subida', v_dato);
    if v_rev.tabla is null then
      return fn_puente_plan_no('pendiente', 'fecha_posterior_a_subida',
        format('La fecha leída (%s) es posterior al día en que se subió el recibo (%s): un ticket no es de después de su foto. '
               '¿Mes y día cruzados? Corrígela (en el SQL Editor: update recibos set fecha = ''AAAA-MM-DD'' where id = %s;). Si de '
               'verdad es esa, confírmalo: select fn_puentes_confirmar(''recibos'', %s, ''fecha_posterior_a_subida'', ''motivo'');',
               r.fecha, v_subido, r.id, r.id), v_firma, v_doc)
             || jsonb_build_object('dato', v_dato);
    end if;
    v_notas := v_notas || to_jsonb(format('La fecha leída (%s) es posterior a la subida (%s): Edgar confirmó que es la buena (%s).',
                                          r.fecha, v_subido, v_rev.motivo));
  end if;
  -- b) DEVOLUCIÓN en las notas y el total en positivo: la app la enseña
  --    como devolución (↩) y el libro la contaría como compra. El total de
  --    una devolución va con signo menos (así la guarda la app).
  if v_devol and v_total > 0 then
    v_dato := v_total::text;
    v_rev  := fn_puente_revisado('recibos', r.id::text, 'devolucion', v_dato);
    if v_rev.tabla is null then
      return fn_puente_plan_no('pendiente', 'devolucion',
        format('Las notas dicen DEVOLUCIÓN y el total es positivo (%s): la app lo enseña como devolución y el libro lo contaría '
               'como compra. Si es una devolución, el total va con signo menos (en el SQL Editor: update recibos set total = -%s '
               'where id = %s;, o con ✎); si es una compra, confírmalo: select fn_puentes_confirmar(''recibos'', %s, ''devolucion'', '
               '''motivo'');', v_total, v_total, r.id, r.id), v_firma, v_doc)
             || jsonb_build_object('dato', v_dato);
    end if;
    v_notas := v_notas || to_jsonb(format('Las notas dicen DEVOLUCIÓN y el total es positivo: Edgar confirmó que es una compra (%s).',
                                          v_rev.motivo));
  end if;
  -- c) El impuesto: subtotal + tax es el total (al centavo; con el signo
  --    del total o sin él, porque una devolución a veces se lee en
  --    positivo). Si no cuadran, la lectura tomó el total sin el impuesto
  --    (o con algo de más): se pregunta. «Incluido en el total» solo se
  --    escribe cuando se comprobó.
  if r.subtotal is not null and r.tax is not null then
    v_suma := round(r.subtotal + r.tax, 2);
    if abs(v_suma - v_total) > 0.01 and abs(v_suma + v_total) > 0.01 then
      v_dato := format('%s|%s|%s', trim_scale(r.total), trim_scale(r.subtotal), trim_scale(r.tax));
      v_rev  := fn_puente_revisado('recibos', r.id::text, 'impuesto', v_dato);
      if v_rev.tabla is null then
        return fn_puente_plan_no('pendiente', 'impuesto',
          format('Subtotal (%s) + tax (%s) = %s, y el total es %s: no cuadran. ¿La lectura tomó el total sin el impuesto (o con '
                 'algo de más)? Corrige el que esté mal (en el SQL Editor: update recibos set total = … where id = %s;). Si el total '
                 'es lo que se pagó (un descuento, un depósito, un flete aparte), confírmalo: select fn_puentes_confirmar(''recibos'', '
                 '%s, ''impuesto'', ''motivo'');', r.subtotal, r.tax, v_suma, v_total, r.id, r.id), v_firma, v_doc)
               || jsonb_build_object('dato', v_dato);
      end if;
      v_impuesto := format('%s: subtotal %s + tax %s = %s no es el total (%s); Edgar confirmó que el total es lo que se pagó (%s). '
                           'Entra el total; es costo, nada a 2300', r.tax, r.subtotal, r.tax, v_suma, v_total, v_rev.motivo);
    else
      v_impuesto := format('%s, incluido en el total (subtotal %s + tax %s = total %s): es costo, nada a 2300',
                           r.tax, r.subtotal, r.tax, v_total);
    end if;
  elsif r.tax is null then
    v_impuesto := 'desconocido (tax vacío): entra el total, que ya lo incluye si lo hubo (no se pudo comprobar); nada a 2300';
  else
    v_impuesto := format('%s: no se pudo comprobar que esté dentro del total (la lectura no trajo el subtotal); entra el total tal '
                         'cual, es costo, nada a 2300', r.tax);
  end if;
  -- d) El mismo papel en OTRO recibo no anulado: la misma foto, o el mismo
  --    ticket (proveedor, número y total). Entra uno: el que ya está en el
  --    libro, o si ninguno está, el más viejo. El otro espera, y el motivo
  --    dice cuál es. Lo que Edgar confirmó que no es el mismo gasto (para
  --    esa foto o ese ticket) ya no se pregunta.
  v_clave := fn_puente_recibo_clave(r.proveedor, r.num_recibo, v_total);
  select o.id,
         (select a.numero from asientos a where a.id = o.contabilizado_en) as numero,
         case when v_ruta is not null and nullif(btrim(o.ruta), '') = v_ruta then 'ruta:' || v_ruta else 'ticket:' || v_clave end
           as dato,
         case when v_ruta is not null and nullif(btrim(o.ruta), '') = v_ruta then format('la misma foto (%s)', v_ruta)
              else format('el mismo ticket (%s #%s por %s)', r.proveedor, r.num_recibo, v_total) end as que
    into v_dup
    from recibos o
   where o.id <> r.id
     and coalesce(o.estado, '') <> 'anulado'
     and (   (v_ruta is not null and nullif(btrim(o.ruta), '') = v_ruta)
          or (v_clave is not null and round(o.total, 2) = v_total
              and fn_puente_recibo_clave(o.proveedor, o.num_recibo, o.total) = v_clave))
     and (   (o.contabilizado_en is not null and r.contabilizado_en is null)
          or ((o.contabilizado_en is not null) = (r.contabilizado_en is not null) and o.id < r.id))
     and not exists (select 1 from puente_revisados pr
                      where pr.tabla = 'recibos' and pr.documento_id = r.id::text and pr.codigo = 'duplicado'
                        and pr.dato = case when v_ruta is not null and nullif(btrim(o.ruta), '') = v_ruta then 'ruta:' || v_ruta
                                           else 'ticket:' || v_clave end)
   order by (o.contabilizado_en is not null) desc, o.id
   limit 1;
  if v_dup.id is not null then
    return fn_puente_plan_no('pendiente', 'duplicado',
      format('Parece el mismo gasto que el recibo %s: %s%s. Subido dos veces no se debe dos veces. Si es el mismo, anula este: select '
             'fn_recibo_anular(%s, ''repetido del recibo %s''); si son dos gastos distintos, confírmalo: select '
             'fn_puentes_confirmar(''recibos'', %s, ''duplicado'', ''motivo'');', v_dup.id, v_dup.que,
             coalesce(', que ya está en el libro (asiento ' || v_dup.numero || ')', ', que todavía no está en el libro'),
             r.id, v_dup.id, r.id), v_firma, v_doc)
           || jsonb_build_object('dato', v_dup.dato, 'duplicado_de', v_dup.id);
  end if;
  select * into v_rev from puente_revisados pr
   where pr.tabla = 'recibos' and pr.documento_id = r.id::text and pr.codigo = 'duplicado'
     and pr.dato in ('ruta:' || coalesce(v_ruta, ''), 'ticket:' || coalesce(v_clave, ''))
   limit 1;
  if v_rev.tabla is not null then
    v_notas := v_notas || to_jsonb(format('Comparte %s con otro recibo: Edgar confirmó que no es el mismo gasto (%s).',
                                          case when v_rev.dato like 'ruta:%' then 'la foto' else 'el ticket' end, v_rev.motivo));
  end if;

  if v_total <> r.total then
    v_notas := v_notas || to_jsonb(format('El total del papel (%s) trae más de dos decimales: entra redondeado a centavos (%s).',
                                          r.total, v_total));
  end if;
  if r.fecha is null then
    v_notas := v_notas || to_jsonb(format('La lectura no trajo la fecha del recibo: entra con la del día en que se subió (%s).',
                                          v_fecha));
  end if;
  if v_ruta is null then
    v_notas := v_notas || to_jsonb('Sin foto del recibo (anotado a mano): el respaldo será el statement de la tarjeta o del banco, '
                                   'o la foto que se le ponga con 📷.'::text);
  end if;

  -- La categoría → la cuenta del gasto.
  if v_cat is null then
    return fn_puente_plan_no('pendiente', 'categoria', 'Sin categoría: la lectura no dijo qué es (material, gasolina…).', v_firma, v_doc);
  end if;
  select * into v_mc from mapeo_categoria_recibo where categoria = v_cat;
  if not found then
    return fn_puente_plan_no('pendiente', 'categoria',
      format('La categoría «%s» no tiene cuenta: dásela con fn_mapeo_categoria(''%s'', cuenta).', r.categoria, v_cat), v_firma, v_doc);
  end if;
  if v_mc.confirmado_el is null then
    return fn_puente_plan_no('pendiente', 'categoria_borrador',
      format('La regla de la categoría «%s» (→ %s) está en borrador: confírmala con fn_mapeo_confirmar(''categoria'', ''%s'').',
             v_cat, v_mc.cuenta, v_cat), v_firma, v_doc);
  end if;
  v_reglas := v_reglas || jsonb_build_object('categoria', to_jsonb(v_mc));
  if r.proyecto_id is not null then
    select * into v_obra from proyectos where id = r.proyecto_id;
    if not found then
      return fn_puente_plan_no('pendiente', 'obra', format('La obra %s del recibo no existe.', r.proyecto_id), v_firma, v_doc);
    end if;
    v_debe := v_mc.cuenta;
  else
    v_debe := coalesce(v_mc.cuenta_sin_obra,
                       (select c.codigo from cuentas c where c.codigo = v_mc.cuenta and c.regla_obra <> 'obligatoria'));
    if v_debe is null then
      return fn_puente_plan_no('pendiente', 'sin_obra',
        format('Sin obra: asígnale el proyecto con 📌 (la cuenta de «%s», %s, va por obra).', v_cat, v_mc.cuenta), v_firma, v_doc);
    end if;
  end if;
  -- (La guarda de las reglas ya no deja apuntar una categoría al banco, a
  -- una cuenta por cobrar o a una de saldo acreedor; esto lo vuelve a mirar
  -- por si la regla se escribió con la guarda apagada.)
  v_mal := fn_puente_cuenta_gasto_mal(v_debe);
  select * into v_cd from cuentas where codigo = v_debe;
  if v_mal is null and v_debe = v_use_tax then
    v_mal := format('la cuenta %s (%s) es la de use tax', v_cd.codigo, v_cd.nombre);
  end if;
  if v_mal is not null then
    return fn_puente_plan_no('pendiente', 'cuenta', format('La regla de la categoría «%s» apunta mal: %s.', v_cat, v_mal), v_firma, v_doc);
  end if;

  -- La forma de pago → la cuenta del haber (y con quién, y qué partida abre).
  if v_met is null then
    -- Sin forma de pago: la trae la lectura, y un total puesto a mano (✎, o
    -- una compra anotada a mano) no la tiene. Si su proveedor tiene
    -- términos (una cuenta abierta con él), va a su cuenta: f03, «o
    -- derivada de proveedores.terminos», y la procedencia lo dice. Si no,
    -- espera, con el SQL exacto para escribirla.
    if v_prov is not null then
      select p.* into v_pr from proveedores_alias a join proveedores p on p.id = a.proveedor_id where a.alias = v_prov;
    end if;
    if v_pr.id is null or nullif(btrim(v_pr.terminos), '') is null
       or (not v_pr.activo and (v_vivo.procedencia->'reglas'->'proveedor'->>'id') is distinct from v_pr.id::text) then
      return fn_puente_plan_no('pendiente', 'metodo_pago',
        format('Sin forma de pago (metodo_pago vacío): la trae la lectura del recibo, y un total puesto a mano (✎, o una compra '
               'anotada a mano) no la tiene; la app todavía no tiene dónde escribirla (parche de f05). Escríbela en el SQL Editor '
               'con un texto del mapeo confirmado (select metodo_pago, forma from mapeo_metodo_pago where confirmado_el is not null '
               'order by forma;), por ejemplo: update recibos set metodo_pago = ''tarjeta'', ultimos4 = ''NNNN'' where id = %s; '
               '(con tarjeta) o update recibos set metodo_pago = ''cheque'' where id = %s;.%s', r.id, r.id,
               case when v_pr.id is not null and not v_pr.activo
                      then format(' (Su proveedor, %s, está inactivo.)', v_pr.nombre)
                    when v_pr.id is not null
                      then format(' (Su proveedor, %s, no tiene términos: con términos iría a su cuenta sola.)', v_pr.nombre)
                    when v_prov is not null
                      then format(' (Si es a la cuenta de «%s», dalo de alta con sus términos, fn_proveedor_alta(''%s'', ''Net 30''), '
                                  'y entra a su cuenta solo.)', r.proveedor, r.proveedor)
                    else '' end), v_firma, v_doc);
    end if;
    v_forma  := 'cuenta_proveedor';
    v_reglas := v_reglas || jsonb_build_object('metodo_pago', jsonb_build_object(
                  'derivada_de', 'proveedores.terminos', 'forma', 'cuenta_proveedor', 'proveedor', v_pr.nombre,
                  'terminos', v_pr.terminos));
    v_notas  := v_notas || to_jsonb(format('Sin forma de pago en el recibo: va a la cuenta de %s porque tiene términos (%s). Si se '
                                           'pagó de otra forma, escríbela (update recibos set metodo_pago = ''…'' where id = %s;) y el '
                                           'libro lo corrige solo.', v_pr.nombre, v_pr.terminos, r.id));
  else
    select * into v_mm from mapeo_metodo_pago where metodo_pago = v_met;
    if not found then
      return fn_puente_plan_no('pendiente', 'metodo_pago',
        format('La forma de pago «%s» no está en el mapeo: dile cuál es con fn_mapeo_metodo_pago(''%s'', forma[, cuenta]).',
               r.metodo_pago, v_met), v_firma, v_doc);
    end if;
    if v_mm.confirmado_el is null then
      return fn_puente_plan_no('pendiente', 'metodo_pago_borrador',
        format('La regla de la forma de pago «%s» (→ %s) está en borrador: confírmala con fn_mapeo_confirmar(''metodo_pago'', ''%s'').',
               v_met, v_mm.forma, v_met), v_firma, v_doc);
    end if;
    v_forma  := v_mm.forma;
    v_reglas := v_reglas || jsonb_build_object('metodo_pago', to_jsonb(v_mm));
  end if;

  if v_forma = 'tarjeta' then
    if v_u4raw is null then
      return fn_puente_plan_no('pendiente', 'tarjeta',
        format('Pagado con tarjeta, pero la lectura no trajo sus últimos 4: escríbelos en el recibo (en el SQL Editor: update recibos '
               'set ultimos4 = ''NNNN'' where id = %s;).', r.id), v_firma, v_doc);
    end if;
    if v_u4 is null or length(v_u4) <> 4 then
      return fn_puente_plan_no('pendiente', 'tarjeta',
        format('La lectura trajo «%s» como los últimos 4 de la tarjeta, y no son 4 dígitos: corrígelo en el recibo (en el SQL '
               'Editor: update recibos set ultimos4 = ''NNNN'' where id = %s;).', v_u4raw, r.id), v_firma, v_doc);
    end if;
    select * into v_t from tarjetas where ultimos4 = v_u4;
    if not found then
      return fn_puente_plan_no('pendiente', 'tarjeta',
        format('La tarjeta terminada en %s no está dada de alta: fn_tarjeta_alta(''%s'', cuenta, titular).', v_u4, v_u4), v_firma, v_doc);
    end if;
    if not v_t.activa then
      -- Inactiva frena lo NUEVO. Un recibo que ya estaba cargado a ella (un
      -- cargo que sigue en su statement) se le sigue cargando al corregirlo.
      if (v_vivo.procedencia->'reglas'->'tarjeta'->>'ultimos4') is distinct from v_u4 then
        return fn_puente_plan_no('pendiente', 'tarjeta',
          format('La tarjeta terminada en %s está inactiva: un recibo nuevo no se le carga. Si el recibo sí es de ella, '
                 'reactívala (fn_tarjeta_alta(''%s'', cuenta, titular)); si es de otra, corrige sus últimos 4.', v_u4, v_u4),
          v_firma, v_doc);
      end if;
      v_notas := v_notas || to_jsonb(format('La tarjeta %s está inactiva: se le sigue cargando porque este recibo ya estaba '
                                            'cargado a ella (asiento %s).', v_u4, v_vivo.numero));
    end if;
    v_haber  := v_t.cuenta;
    v_reglas := v_reglas || jsonb_build_object('tarjeta', to_jsonb(v_t));
    if v_haber = fn_puente_cuenta_de('reembolso_empleado') then
      v_ter_tipo := 'empleado';
      v_ter_id   := v_t.empleado_id::text;
    end if;
  elsif v_forma = 'cuenta_proveedor' then
    if v_pr.id is null then
      if v_prov is null then
        return fn_puente_plan_no('pendiente', 'proveedor',
          'A cuenta del proveedor, pero el recibo no dice cuál: escríbelo con ✎.', v_firma, v_doc);
      end if;
      select p.* into v_pr from proveedores_alias a join proveedores p on p.id = a.proveedor_id where a.alias = v_prov;
      if not found then
        return fn_puente_plan_no('pendiente', 'proveedor',
          format('El proveedor «%s» no está dado de alta (o no con ese nombre): fn_proveedor_alta(''%s'', términos) o '
                 'fn_proveedor_alias(proveedor, ''%s'').', r.proveedor, r.proveedor, v_prov), v_firma, v_doc);
      end if;
    end if;
    if not v_pr.activo then
      -- Inactivo frena lo NUEVO. Su deuda de antes sigue viva: un recibo que
      -- ya se le cargó se le sigue cargando al corregirlo (la foto, la obra).
      if (v_vivo.procedencia->'reglas'->'proveedor'->>'id') is distinct from v_pr.id::text then
        return fn_puente_plan_no('pendiente', 'proveedor',
          format('El proveedor %s está inactivo: un recibo nuevo no se le carga a cuenta. Si sí se le debe, reactívalo (en el SQL '
                 'Editor: update proveedores set activo = true where id = ''%s'';).', v_pr.nombre, v_pr.id), v_firma, v_doc);
      end if;
      v_notas := v_notas || to_jsonb(format('El proveedor %s está inactivo: se le sigue cargando porque este recibo ya era suyo '
                                            '(asiento %s).', v_pr.nombre, v_vivo.numero));
    end if;
    v_haber    := fn_puente_cuenta_de('cxp');
    v_ter_tipo := 'proveedor';
    v_ter_id   := v_pr.id::text;
    v_reglas   := v_reglas || jsonb_build_object('proveedor', jsonb_build_object('id', v_pr.id, 'nombre', v_pr.nombre,
                                                                                 'terminos', v_pr.terminos));
  elsif v_forma in ('banco', 'efectivo') then
    if v_mm.cuenta is null then
      return fn_puente_plan_no('pendiente', 'efectivo',
        format('Pagado en efectivo («%s»): el mapeo no dice de dónde salió el efectivo; dale su cuenta con fn_mapeo_metodo_pago.',
               r.metodo_pago), v_firma, v_doc);
    end if;
    v_haber := v_mm.cuenta;
  else -- reembolso: lo pagó de su bolsillo quien subió el recibo
    if r.autor_id is null then
      return fn_puente_plan_no('pendiente', 'reembolso',
        'Reembolso, pero el recibo no dice quién lo pagó (no tiene autor).', v_firma, v_doc);
    end if;
    if exists (select 1 from perfiles p where p.id = r.autor_id and p.rol = 'dueno') then
      v_haber := fn_puente_cuenta_de('reembolso_dueno');
    else
      v_haber := fn_puente_cuenta_de('reembolso_empleado');
    end if;
  end if;
  -- Un reembolso a empleado es a nombre de alguien (el de la tarjeta, o
  -- quien subió el recibo); y todo lo que se le debe a alguien abre una
  -- partida: la de este recibo.
  if v_haber = fn_puente_cuenta_de('reembolso_empleado') and v_ter_tipo is null then
    if r.autor_id is null then
      return fn_puente_plan_no('pendiente', 'reembolso', 'Reembolso a un empleado, pero no se sabe a cuál.', v_firma, v_doc);
    end if;
    v_ter_tipo := 'empleado';
    v_ter_id   := r.autor_id::text;
  end if;
  v_partida := v_haber in (fn_puente_cuenta_de('cxp'), fn_puente_cuenta_de('reembolso_empleado'),
                           fn_puente_cuenta_de('reembolso_dueno'));
  v_mal := fn_puente_cuenta_mal(v_haber);
  if v_mal is null and v_haber = v_use_tax then
    v_mal := 'un recibo nunca va a use tax: el impuesto del ticket es costo';
  end if;
  if v_mal is not null then
    return fn_puente_plan_no('pendiente', 'cuenta',
      format('La forma de pago «%s» apunta mal: %s.', coalesce(v_met, v_forma), v_mal), v_firma, v_doc);
  end if;

  -- Las dos líneas.
  v_memo := concat_ws(' · ', 'Recibo ' || r.id, nullif(btrim(r.proveedor), ''), '#' || nullif(btrim(r.num_recibo), ''));
  if r.proyecto_id is not null and v_cd.regla_obra <> 'prohibida' then
    v_ldebe := jsonb_strip_nulls(jsonb_build_object(
      'cuenta', v_debe, 'monto', v_total::text, 'proyecto_id', r.proyecto_id, 'co', nullif(btrim(r.co), ''),
      'cost_code', case when v_cd.regla_cost_code <> 'prohibida' then v_cc end, 'memo', v_memo));
  else
    v_ldebe := jsonb_build_object('cuenta', v_debe, 'monto', v_total::text,
                                  'memo', v_memo || coalesce(' · obra ' || r.proyecto_id, ''));
    if r.proyecto_id is not null then
      v_notas := v_notas || to_jsonb(format('La cuenta %s (%s) no va por obra: la obra %s queda en la nota de la línea.',
                                            v_cd.codigo, v_cd.nombre, r.proyecto_id));
    end if;
  end if;
  v_lhaber := jsonb_strip_nulls(jsonb_build_object(
    'cuenta', v_haber, 'monto', (-v_total)::text, 'tercero_tipo', v_ter_tipo, 'tercero_id', v_ter_id,
    'partida_tabla', case when v_partida then 'recibos' end, 'partida_id', case when v_partida then r.id::text end,
    'memo', v_memo));

  return jsonb_build_object(
    'accion', 'postear', 'firma', v_firma, 'documento', v_doc, 'fecha_documento', v_fecha,
    'asiento', jsonb_strip_nulls(jsonb_build_object(
      'descripcion', concat_ws(' · ', 'Recibo ' || r.id, coalesce(nullif(btrim(r.proveedor), ''), 'sin proveedor'),
                               '#' || nullif(btrim(r.num_recibo), ''), v_obra.nombre),
      'lineas', jsonb_build_array(v_ldebe, v_lhaber),
      'origen_tabla', 'recibos', 'origen_id', r.id::text,
      'documento_ruta', v_ruta,
      'procedencia', jsonb_build_object(
        'funcion', 'fn_puente_recibo',
        'reglas', v_reglas,
        'impuesto', v_impuesto,
        'papel', jsonb_strip_nulls(jsonb_build_object('num_recibo', r.num_recibo, 'subtotal', r.subtotal, 'tax', r.tax,
                                                      'ruta', r.ruta, 'estado', r.estado, 'creado', r.creado, 'notas', r.notas)),
        'notas', v_notas))));
end $$;
revoke execute on function public.fn_puente_recibo_plan(bigint) from public, anon, authenticated, service_role;

-- El trabajo externo (el ayudante por horas o el subcontrato). Dr 5200 por
-- obra / Cr 2010, con su propia partida abierta (el pago de f06 la salda) y
-- a nombre de su proveedor: el que Edgar le puso (proveedor_id) o, si no,
-- el enlazado a su ayudante (externo_id). Sin proveedor entra igual (el
-- costo es de la obra, y la partida dice a quién por su papel), pero queda
-- AVISADO en la bandeja: sin él la deuda no sale por proveedor ni en el
-- 1099. El proveedor que se resuelve entra en la firma: ponérselo después
-- (o dar de alta al ayudante) completa el asiento en la siguiente pasada.
-- Un proveedor inactivo frena lo nuevo, no lo que ya se le cargó.
-- Lo que ya está en el libro por la apertura no entra otra vez, y lo
-- fechado antes del corte pero anotado después se pregunta (como el
-- recibo).
create or replace function public.fn_puente_externo_plan(p_id bigint)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  x        trabajos_externos;
  v_fecha  date;
  v_subido date;
  v_doc    jsonb;
  v_firma  text;
  v_costo  numeric;
  v_obra   proyectos;
  v_pr     proveedores;
  v_vivo   asientos;
  v_aper   jsonb;
  v_rev    puente_revisados;
  v_debe   text := fn_puente_cuenta_de('subcontratos');
  v_haber  text := fn_puente_cuenta_de('cxp');
  v_mal    text;
  v_memo   text;
  v_aviso  jsonb;
  v_notas  jsonb := '[]'::jsonb;
begin
  select * into x from trabajos_externos where id = p_id;
  if not found then
    return fn_puente_plan_no('no_aplica', 'no_existe', 'El trabajo externo ya no existe.', null, null);
  end if;
  v_fecha  := coalesce(x.fecha, fn_fecha_miami(x.creado));
  v_subido := (x.creado at time zone 'America/New_York')::date;
  v_vivo   := fn_puente_vivo('trabajos_externos', x.id::text);
  v_aper   := fn_puente_en_apertura('trabajos_externos', x.id::text);
  -- A quién se le debe: el proveedor que Edgar le puso, o el de su ayudante.
  -- Inactivo: solo si su asiento ya era suyo.
  if x.proveedor_id is not null then
    select * into v_pr from proveedores p where p.id = x.proveedor_id;
  elsif x.externo_id is not null then
    select * into v_pr from proveedores p where p.externo_id = x.externo_id;
  end if;
  if v_pr.id is not null and not v_pr.activo
     and (v_vivo.procedencia->'reglas'->'proveedor'->>'id') is distinct from v_pr.id::text then
    if x.proveedor_id is not null then
      v_doc := jsonb_build_object('costo', trim_scale(x.costo)::text, 'fecha', v_fecha, 'proyecto_id', x.proyecto_id,
                                  'externo_id', x.externo_id, 'descripcion', x.descripcion, 'proveedor', x.proveedor_id);
      return fn_puente_plan_no('pendiente', 'proveedor',
        format('El proveedor %s está inactivo: un trabajo nuevo no se le carga. Si sí se le debe, reactívalo (en el SQL Editor: '
               'update proveedores set activo = true where id = ''%s'';), o ponle otro.', v_pr.nombre, v_pr.id),
        md5(v_doc::text), v_doc);
    end if;
    v_notas := v_notas || to_jsonb(format('El proveedor de su ayudante (%s) está inactivo: la partida no va a su nombre.', v_pr.nombre));
    v_pr := null;
  end if;
  -- La firma: el papel y a quién se le debe (sin la clave si no hay nadie,
  -- como antes de que existiera).
  v_doc := jsonb_build_object('costo', trim_scale(x.costo)::text, 'fecha', v_fecha, 'proyecto_id', x.proyecto_id,
                              'externo_id', x.externo_id, 'descripcion', x.descripcion)
           || case when v_pr.id is not null then jsonb_build_object('proveedor', v_pr.id) else '{}'::jsonb end;
  v_firma := md5(v_doc::text);
  if v_aper is not null and round(x.costo, 2) = 0 then
    return fn_puente_plan_no('pendiente', 'en_apertura',
      format('Costo en 0, pero la apertura (%s) lo tiene como deuda con %s por %s: ponerlo en 0 no la quita. Si de verdad no se '
             'debe, corrige la apertura con un ajuste (tipo ajuste_cpa, afecta_periodo = ''%s'') contra su partida '
             'trabajos_externos/%s.', v_aper->>'asientos', v_aper->>'a_quien', abs((v_aper->>'saldo')::numeric),
             v_aper->>'apertura', x.id), v_firma, v_doc);
  end if;
  if v_fecha < fn_puente_corte() then
    select * into v_rev from puente_revisados
     where tabla = 'trabajos_externos' and documento_id = x.id::text and codigo = 'fecha_antes_del_corte'
       and dato = to_char(v_fecha, 'YYYY-MM-DD');
    if v_subido >= fn_puente_corte() and v_aper is null and v_rev.tabla is null then
      return fn_puente_plan_no('pendiente', 'fecha_antes_del_corte',
        format('Fechado el %s, antes del corte (%s), pero anotado el %s: ¿la fecha está bien? Si está mal, corrígela (en el SQL '
               'Editor: update trabajos_externos set fecha = ''AAAA-MM-DD'' where id = %s;). Si de verdad es de antes del corte, '
               'confirma que está en QuickBooks: select fn_puentes_antes_del_corte(''trabajos_externos'', %s, ''motivo'');',
               v_fecha, fn_puente_corte(), v_subido, x.id, x.id), v_firma, v_doc)
             || jsonb_build_object('dato', to_char(v_fecha, 'YYYY-MM-DD'));
    end if;
    return fn_puente_plan_no('no_aplica', 'antes_del_corte',
      format('Fechado el %s, antes del corte (%s): vive en QuickBooks y llega con la apertura.%s', v_fecha, fn_puente_corte(),
             case when v_aper is not null then format(' Está en la apertura (%s).', v_aper->>'asientos')
                  when v_rev.tabla is not null then format(' Anotado el %s; Edgar confirmó que es de antes del corte (%s): %s',
                                                           v_subido, (v_rev.revisado_el at time zone 'America/New_York')::date,
                                                           v_rev.motivo)
                  else '' end),
      v_firma, v_doc);
  end if;
  v_costo := round(x.costo, 2);
  if v_costo = 0 then
    return fn_puente_plan_no('no_aplica', 'costo_cero', 'Costo en 0 (anulado): no suma nada.', v_firma, v_doc);
  end if;
  if v_aper is not null then
    return fn_puente_plan_no('pendiente', 'en_apertura',
      format('Este trabajo externo ya está en la apertura (%s) como deuda con %s por %s: no entra otra vez por su puente. Si de '
             'verdad es de después del corte, o está mal en la apertura, se corrige la apertura con un ajuste (tipo ajuste_cpa, '
             'afecta_periodo = ''%s'') contra su partida trabajos_externos/%s, y entonces entra.', v_aper->>'asientos',
             v_aper->>'a_quien', abs((v_aper->>'saldo')::numeric), v_aper->>'apertura', x.id), v_firma, v_doc);
  end if;
  if v_costo <> x.costo then
    v_notas := v_notas || to_jsonb(format('El costo del papel (%s) trae más de dos decimales: entra redondeado a centavos (%s).',
                                          x.costo, v_costo));
  end if;
  if x.proyecto_id is null then
    return fn_puente_plan_no('pendiente', 'sin_obra', 'Trabajo externo sin obra: el subcontrato va al costo de una obra.', v_firma, v_doc);
  end if;
  select * into v_obra from proyectos where id = x.proyecto_id;
  if not found then
    return fn_puente_plan_no('pendiente', 'obra', format('La obra %s no existe.', x.proyecto_id), v_firma, v_doc);
  end if;
  v_mal := coalesce(fn_puente_cuenta_mal(v_debe), fn_puente_cuenta_mal(v_haber));
  if v_mal is not null then
    return fn_puente_plan_no('pendiente', 'cuenta', format('Las cuentas del puente de trabajos externos: %s.', v_mal), v_firma, v_doc);
  end if;
  if v_pr.id is null then
    v_aviso := jsonb_build_object(
      'codigo', 'sin_proveedor',
      'motivo', format('Entró al costo de la obra, pero sin proveedor: su deuda de 2010 no sale a nombre de nadie, ni en el 1099. '
                       'Dile a quién se le debe (en el SQL Editor: update trabajos_externos set proveedor_id = (select id from '
                       'proveedores where nombre = ''…'') where id = %s;); si no está dado de alta, fn_proveedor_alta(nombre, '
                       'términos). El asiento se completa solo en la siguiente pasada del puente.', x.id));
    v_notas := v_notas || to_jsonb('Sin proveedor: la partida queda abierta a nombre de su papel (la descripción), y en la bandeja '
                                   'como aviso hasta que se le ponga (proveedor_id).'::text);
  end if;
  v_memo := concat_ws(' · ', 'Trabajo externo ' || x.id, x.descripcion,
                      case when x.tipo = 'horas' and x.horas is not null then trim_scale(x.horas)::text || ' h' end);
  return jsonb_build_object(
    'accion', 'postear', 'firma', v_firma, 'documento', v_doc, 'fecha_documento', v_fecha,
    'asiento', jsonb_build_object(
      'descripcion', concat_ws(' · ', 'Trabajo externo ' || x.id, x.descripcion, v_obra.nombre),
      'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', v_debe, 'monto', v_costo::text, 'proyecto_id', x.proyecto_id, 'memo', v_memo),
        jsonb_strip_nulls(jsonb_build_object(
          'cuenta', v_haber, 'monto', (-v_costo)::text,
          'tercero_tipo', case when v_pr.id is not null then 'proveedor' end, 'tercero_id', v_pr.id::text,
          'partida_tabla', 'trabajos_externos', 'partida_id', x.id::text, 'memo', v_memo))),
      'origen_tabla', 'trabajos_externos', 'origen_id', x.id::text,
      'procedencia', jsonb_build_object(
        'funcion', 'fn_puente_externo',
        'reglas', jsonb_strip_nulls(jsonb_build_object(
                    'subcontratos', v_debe, 'cxp', v_haber,
                    'proveedor', case when v_pr.id is not null
                                      then jsonb_build_object('id', v_pr.id, 'nombre', v_pr.nombre,
                                                              'de', case when x.proveedor_id is not null then 'proveedor_id'
                                                                         else 'externo_id' end) end)),
        'papel', jsonb_strip_nulls(jsonb_build_object('tipo', x.tipo, 'horas', x.horas, 'creado', x.creado)),
        'notas', v_notas)))
    || case when v_aviso is not null then jsonb_build_object('aviso', v_aviso) else '{}'::jsonb end;
end $$;
revoke execute on function public.fn_puente_externo_plan(bigint) from public, anon, authenticated, service_role;

-- La factura emitida. Dr 1110 (lo que el cliente paga ahora) y 1120 (su
-- retención), las dos con la factura como partida abierta y por obra; Cr el
-- ingreso del tipo de su obra (mapeo), por el total facturado.
-- La retención la dice la factura (retencion). Si no la dice y hay señal de
-- que la lleva (es a un contratista, o su obra la tiene pactada en su
-- estimado), no se adivina: espera en la bandeja a que Edgar la diga (0 si
-- esta no lleva). Así nunca entra entera a 1110 sin que nadie lo vea.
create or replace function public.fn_puente_factura_plan(p_id bigint)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  f        facturas;
  v_doc    jsonb;
  v_firma  text;
  v_monto  numeric;
  v_ret    numeric;
  v_pct    numeric;
  v_est    bigint;
  v_obra   proyectos;
  v_mt     mapeo_tipo_proyecto;
  v_ing    text;
  v_cxc    text := fn_puente_cuenta_de('cxc');
  v_cret   text := fn_puente_cuenta_de('retencion_cxc');
  v_mal    text;
  v_memo   text;
  v_lineas jsonb := '[]'::jsonb;
  v_notas  jsonb := '[]'::jsonb;
begin
  select * into f from facturas where id = p_id;
  if not found then
    return fn_puente_plan_no('no_aplica', 'no_existe', 'La factura ya no existe.', null, null);
  end if;
  -- El estado no entra en la firma: anular una factura contabilizada no
  -- reversa su asiento (lo compensa su nota de crédito, que es otro papel).
  v_doc := jsonb_build_object('num', f.num, 'monto', trim_scale(f.monto)::text, 'fecha', f.fecha, 'proyecto_id', f.proyecto_id,
                              'retencion', trim_scale(f.retencion)::text);
  v_firma := md5(v_doc::text);
  if f.estado = 'borrador' then
    return fn_puente_plan_no('espera', 'borrador', 'Factura en borrador: se contabiliza al emitirse.', v_firma, v_doc);
  end if;
  -- Anulada: no se contabiliza, le falte lo que le falte (una anulada sin
  -- fecha no se queda en la bandeja pidiendo fecha). Si ya estaba en el
  -- libro, su asiento se queda: lo compensa su nota de crédito.
  if f.estado = 'anulada' then
    return fn_puente_plan_no('no_aplica', 'anulada',
      coalesce('Factura anulada con la nota de crédito ' || (select n.numero from notas_credito n where n.anula_a = f.id)
               || ': su asiento se queda y la nota lo compensa.',
               'Factura anulada antes de entrar al libro: no se contabiliza.'), v_firma, v_doc);
  end if;
  if f.fecha is null then
    return fn_puente_plan_no('pendiente', 'sin_fecha', format('La factura #%s no tiene fecha.', f.num), v_firma, v_doc);
  end if;
  if f.fecha < fn_puente_corte() then
    return fn_puente_plan_no('no_aplica', 'antes_del_corte',
      format('Factura del %s, antes del corte (%s): si sigue abierta, su saldo llega con la apertura (por factura).',
             f.fecha, fn_puente_corte()), v_firma, v_doc);
  end if;
  if f.monto is null then
    return fn_puente_plan_no('pendiente', 'sin_monto', format('La factura #%s no tiene monto.', f.num), v_firma, v_doc);
  end if;
  v_monto := round(f.monto, 2);
  if v_monto = 0 then
    return fn_puente_plan_no('no_aplica', 'monto_cero', 'Factura en 0: no suma nada.', v_firma, v_doc);
  end if;
  if v_monto <> f.monto then
    v_notas := v_notas || to_jsonb(format('El monto del papel (%s) trae más de dos decimales: entra redondeado a centavos (%s).',
                                          f.monto, v_monto));
  end if;
  v_ret := coalesce(f.retencion, 0);
  if v_ret < 0 or (v_monto > 0 and v_ret > v_monto) or (v_monto < 0 and v_ret <> 0) then
    return fn_puente_plan_no('pendiente', 'retencion',
      format('La retención (%s) no cabe en la factura #%s (%s).', v_ret, f.num, v_monto), v_firma, v_doc);
  end if;
  if f.proyecto_id is null then
    return fn_puente_plan_no('pendiente', 'sin_obra', format('La factura #%s no dice de qué obra es.', f.num), v_firma, v_doc);
  end if;
  select * into v_obra from proyectos where id = f.proyecto_id;
  if not found then
    return fn_puente_plan_no('pendiente', 'obra', format('La obra %s de la factura no existe.', f.proyecto_id), v_firma, v_doc);
  end if;
  if fn_puente_normalizar(v_obra.tipo) is null then
    return fn_puente_plan_no('pendiente', 'tipo_proyecto',
      format('La obra «%s» no tiene tipo (residencial, comercial o servicio): sin tipo no se sabe a qué ingreso va la factura #%s.',
             coalesce(nullif(btrim(v_obra.nombre), ''), v_obra.id), f.num), v_firma, v_doc);
  end if;
  select * into v_mt from mapeo_tipo_proyecto where tipo = fn_puente_normalizar(v_obra.tipo);
  if not found then
    return fn_puente_plan_no('pendiente', 'tipo_proyecto',
      format('El tipo de obra «%s» no tiene cuenta de ingreso: dásela con fn_mapeo_tipo_proyecto(''%s'', cuenta).',
             v_obra.tipo, fn_puente_normalizar(v_obra.tipo)), v_firma, v_doc);
  end if;
  if v_mt.confirmado_el is null then
    return fn_puente_plan_no('pendiente', 'tipo_proyecto_borrador',
      format('La regla del tipo de obra «%s» (→ %s) está en borrador: confírmala con fn_mapeo_confirmar(''tipo_proyecto'', ''%s'').',
             v_mt.tipo, v_mt.cuenta, v_mt.tipo), v_firma, v_doc);
  end if;
  v_ing := v_mt.cuenta;
  if f.retencion is null then
    select e.id, e.retencion_pct into v_est, v_pct
      from estimados e
     where e.proyecto_id = f.proyecto_id and coalesce(e.retencion_pct, 0) > 0
     order by (e.estado = 'ganado') desc, e.id desc
     limit 1;
    if v_pct is not null or coalesce(f.a_contratista, false) then
      return fn_puente_plan_no('pendiente', 'retencion',
        format('La factura #%s %s y no dice cuánto retiene el cliente%s. Dilo antes de que entre al libro (en el SQL Editor: '
               'update facturas set retencion = <monto> where id = %s;), con 0 si esta factura no lleva retención.', f.num,
               case when coalesce(f.a_contratista, false) then 'es a un contratista (GC)' else 'es de una obra con retención pactada' end,
               case when v_pct is not null
                    then format(' (el estimado %s pacta el %s %%: en esta factura serían %s)', v_est, trim_scale(v_pct),
                                round(v_monto * v_pct / 100, 2))
                    else '' end,
               f.id), v_firma, v_doc);
    end if;
  end if;
  v_mal := coalesce(fn_puente_cuenta_mal(v_ing), fn_puente_cuenta_mal(v_cxc),
                    case when v_ret > 0 then fn_puente_cuenta_mal(v_cret) end);
  if v_mal is not null then
    return fn_puente_plan_no('pendiente', 'cuenta', format('Las cuentas de la factura: %s.', v_mal), v_firma, v_doc);
  end if;
  v_memo := concat_ws(' · ', 'Factura #' || f.num, v_obra.nombre);
  if v_monto - v_ret <> 0 then
    v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
      'cuenta', v_cxc, 'monto', (v_monto - v_ret)::text, 'proyecto_id', f.proyecto_id,
      'partida_tabla', 'facturas', 'partida_id', f.id::text, 'memo', v_memo));
  end if;
  if v_ret > 0 then
    v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
      'cuenta', v_cret, 'monto', v_ret::text, 'proyecto_id', f.proyecto_id,
      'partida_tabla', 'facturas', 'partida_id', f.id::text, 'memo', v_memo || ' · retención'));
  end if;
  v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
    'cuenta', v_ing, 'monto', (-v_monto)::text, 'proyecto_id', f.proyecto_id, 'memo', v_memo));
  return jsonb_build_object(
    'accion', 'postear', 'firma', v_firma, 'documento', v_doc, 'fecha_documento', f.fecha,
    'asiento', jsonb_build_object(
      'descripcion', concat_ws(' · ', 'Factura #' || f.num, v_obra.nombre),
      'lineas', v_lineas,
      'origen_tabla', 'facturas', 'origen_id', f.id::text,
      'procedencia', jsonb_build_object(
        'funcion', 'fn_puente_factura',
        'reglas', jsonb_build_object('tipo_proyecto', to_jsonb(v_mt), 'cxc', v_cxc, 'retencion_cxc', v_cret),
        'papel', jsonb_strip_nulls(jsonb_build_object('qb_id', f.qb_id, 'hito_id', f.hito_id, 'a_contratista', f.a_contratista,
                                                      'estado', f.estado)),
        'notas', v_notas)));
end $$;
revoke execute on function public.fn_puente_factura_plan(bigint) from public, anon, authenticated, service_role;

-- La cuenta de ingreso de una factura: la de su asiento vivo (lo que se
-- facturó), o la de su tipo de obra si es de antes del corte.
create or replace function public.fn_puente_ingreso_de(p_factura bigint)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce(
    (select l.cuenta
       from asiento_lineas l
       join cuentas c on c.codigo = l.cuenta
      where l.asiento_id = (fn_puente_vivo('facturas', p_factura::text)).id
        and c.tipo in ('ingreso', 'otro_ingreso')
      order by l.orden
      limit 1),
    (select m.cuenta
       from facturas f
       join proyectos p on p.id = f.proyecto_id
       join mapeo_tipo_proyecto m on m.tipo = fn_puente_normalizar(p.tipo) and m.confirmado_el is not null
      where f.id = p_factura))
$$;
revoke execute on function public.fn_puente_ingreso_de(bigint) from public, anon, authenticated, service_role;

-- El cobro. Dr el banco por el depósito; Cr, por cada aplicación, la
-- partida de su factura en 1110 (o en 1120 si es su retención) con lo
-- cobrado más el descuento, y el descuento contra el ingreso de esa
-- factura; lo que no va a ninguna factura queda de anticipo de la obra (Cr
-- 1110 con el cobro como partida). Las aplicaciones «desde_anticipo» no
-- traen dinero: tienen su propio asiento (fn_puente_aplicacion_plan).
-- Las líneas van siempre en el mismo orden (por factura, la retención
-- después, el anticipo al final): el mismo cobro da el mismo asiento.
create or replace function public.fn_puente_cobro_plan(p_id uuid)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  c        cobros;
  a        record;
  v_apps   jsonb;
  v_doc    jsonb;
  v_firma  text;
  v_cxc    text := fn_puente_cuenta_de('cxc');
  v_cret   text := fn_puente_cuenta_de('retencion_cxc');
  v_ing    text;
  v_mal    text;
  v_suma   numeric;
  v_lineas jsonb;
  v_facts  text;
begin
  select * into c from cobros where id = p_id;
  if not found then
    return fn_puente_plan_no('no_aplica', 'no_existe', 'El cobro ya no existe.', null, null);
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'factura_id', x.factura_id, 'proyecto_id', x.proyecto_id,
                                               'monto', x.monto::text, 'es_retencion', x.es_retencion,
                                               'descuento', x.descuento::text)
                            order by x.factura_id nulls last, x.es_retencion, x.id), '[]'::jsonb),
         coalesce(sum(x.monto), 0)
    into v_apps, v_suma
    from aplicaciones_cobro x
   where x.cobro_id = c.id and not x.desde_anticipo;
  v_doc := jsonb_build_object('estado', c.estado, 'fecha', c.fecha, 'monto', c.monto::text, 'cuenta', c.cuenta,
                              'aplicaciones', v_apps);
  v_firma := md5(v_doc::text);
  if c.estado = 'anulado' then
    return fn_puente_plan_no('no_aplica', 'anulado', coalesce('Cobro anulado: ' || c.anulado_motivo, 'Cobro anulado.'), v_firma, v_doc);
  end if;
  if c.fecha < fn_puente_corte() then
    return fn_puente_plan_no('no_aplica', 'antes_del_corte',
      format('Cobro del %s, antes del corte: vive en QuickBooks.', c.fecha), v_firma, v_doc);
  end if;
  if v_suma <> c.monto then
    return fn_puente_plan_no('pendiente', 'aplicaciones',
      format('Las aplicaciones del cobro suman %s y el cobro es de %s.', v_suma, c.monto), v_firma, v_doc);
  end if;
  v_mal := coalesce(fn_puente_cuenta_mal(c.cuenta), fn_puente_cuenta_mal(v_cxc));
  if v_mal is not null then
    return fn_puente_plan_no('pendiente', 'cuenta', format('Las cuentas del cobro: %s.', v_mal), v_firma, v_doc);
  end if;
  v_lineas := jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
    'cuenta', c.cuenta, 'monto', c.monto::text,
    'memo', concat_ws(' · ', 'Cobro', c.medio, c.referencia))));
  for a in select x.*, f.num
             from aplicaciones_cobro x
             left join facturas f on f.id = x.factura_id
            where x.cobro_id = c.id and not x.desde_anticipo
            order by x.factura_id nulls last, x.es_retencion, x.id loop
    if a.factura_id is null then
      v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
        'cuenta', v_cxc, 'monto', (-a.monto)::text, 'proyecto_id', a.proyecto_id,
        'partida_tabla', 'cobros', 'partida_id', c.id::text, 'memo', 'Anticipo de la obra (queda a favor del cliente)'));
    else
      if a.es_retencion and fn_puente_cuenta_mal(v_cret) is not null then
        return fn_puente_plan_no('pendiente', 'cuenta', format('La cuenta de retención: %s.', fn_puente_cuenta_mal(v_cret)), v_firma, v_doc);
      end if;
      v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
        'cuenta', case when a.es_retencion then v_cret else v_cxc end, 'monto', (-(a.monto + a.descuento))::text,
        'proyecto_id', a.proyecto_id, 'partida_tabla', 'facturas', 'partida_id', a.factura_id::text,
        'memo', 'Cobro de la factura #' || a.num || case when a.es_retencion then ' · su retención' else '' end));
      if a.descuento > 0 then
        v_ing := fn_puente_ingreso_de(a.factura_id);
        if v_ing is null then
          return fn_puente_plan_no('pendiente', 'descuento',
            format('No sé a qué ingreso va el descuento de la factura #%s (su obra no tiene tipo con cuenta confirmada).', a.num),
            v_firma, v_doc);
        end if;
        v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
          'cuenta', v_ing, 'monto', a.descuento::text, 'proyecto_id', a.proyecto_id,
          'memo', 'Descuento al cobrar la factura #' || a.num));
      end if;
    end if;
  end loop;
  select string_agg(distinct '#' || f.num, ', ') into v_facts
    from aplicaciones_cobro x join facturas f on f.id = x.factura_id
   where x.cobro_id = c.id and not x.desde_anticipo;
  return jsonb_build_object(
    'accion', 'postear', 'firma', v_firma, 'documento', v_doc, 'fecha_documento', c.fecha,
    'asiento', jsonb_build_object(
      'descripcion', concat_ws(' · ', 'Cobro', c.medio, c.referencia,
                               coalesce('facturas ' || v_facts, 'anticipo')),
      'lineas', v_lineas,
      'origen_tabla', 'cobros', 'origen_id', c.id::text,
      'procedencia', jsonb_build_object(
        'funcion', 'fn_puente_cobro',
        'reglas', jsonb_build_object('cxc', v_cxc, 'retencion_cxc', v_cret),
        'papel', jsonb_strip_nulls(jsonb_build_object('medio', c.medio, 'referencia', c.referencia, 'notas', c.notas,
                                                      'movimiento_id', c.movimiento_id, 'creado_por', c.creado_por)))));
end $$;
revoke execute on function public.fn_puente_cobro_plan(uuid) from public, anon, authenticated, service_role;

-- La aplicación de un anticipo a una factura: sin dinero. Dr 1110 la
-- partida del cobro que dejó el anticipo / Cr 1110 (o 1120) la partida de
-- la factura, en la fecha de la aplicación.
create or replace function public.fn_puente_aplicacion_plan(p_id uuid)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  a       aplicaciones_cobro;
  c       cobros;
  f       facturas;
  v_doc   jsonb;
  v_firma text;
  v_cxc   text := fn_puente_cuenta_de('cxc');
  v_cret  text := fn_puente_cuenta_de('retencion_cxc');
begin
  select * into a from aplicaciones_cobro where id = p_id;
  if not found or not a.desde_anticipo then
    return fn_puente_plan_no('no_aplica', 'no_existe', 'No es la aplicación de un anticipo.', null, null);
  end if;
  select * into c from cobros where id = a.cobro_id;
  select * into f from facturas where id = a.factura_id;
  v_doc := jsonb_build_object('cobro', a.cobro_id, 'cobro_estado', c.estado, 'factura_id', a.factura_id, 'proyecto_id', a.proyecto_id,
                              'monto', a.monto::text, 'es_retencion', a.es_retencion, 'fecha', a.fecha);
  v_firma := md5(v_doc::text);
  if c.estado = 'anulado' then
    return fn_puente_plan_no('no_aplica', 'anulado', 'El cobro del anticipo se anuló.', v_firma, v_doc);
  end if;
  return jsonb_build_object(
    'accion', 'postear', 'firma', v_firma, 'documento', v_doc, 'fecha_documento', a.fecha,
    'asiento', jsonb_build_object(
      'descripcion', format('Anticipo aplicado a la factura #%s', f.num),
      'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', v_cxc, 'monto', a.monto::text, 'proyecto_id', a.proyecto_id,
                           'partida_tabla', 'cobros', 'partida_id', a.cobro_id::text, 'memo', 'Sale del anticipo'),
        jsonb_build_object('cuenta', case when a.es_retencion then v_cret else v_cxc end, 'monto', (-a.monto)::text,
                           'proyecto_id', a.proyecto_id, 'partida_tabla', 'facturas', 'partida_id', a.factura_id::text,
                           'memo', 'Anticipo aplicado a la factura #' || f.num)),
      'origen_tabla', 'aplicaciones_cobro', 'origen_id', a.id::text,
      'procedencia', jsonb_build_object('funcion', 'fn_puente_aplicacion', 'reglas', jsonb_build_object('cxc', v_cxc))));
end $$;
revoke execute on function public.fn_puente_aplicacion_plan(uuid) from public, anon, authenticated, service_role;

-- Las líneas de la nota de crédito de una factura: salda la factura COMO
-- ESTÁ HOY, no como se emitió.
--   · Lo que su partida debe hoy en cada cuenta de cobrar (1110, 1120), con
--     su obra y sus dimensiones, con el signo cambiado: si la retención se
--     reclasificó a mano (Dr 1120 / Cr 1110 contra la partida, lo que piden
--     la guarda de facturas y fn_cobro_registrar), la nota salda las dos
--     cuentas y no deja 800 de retención «por cobrar» en una factura
--     anulada.
--   · El espejo de lo demás de su asiento vivo: el ingreso, con su obra.
-- Cuadra solo si lo que la partida debe hoy es lo que la factura puso:
-- otro asiento que la movió contra OTRA cuenta (un castigo a incobrables,
-- un ajuste a mano contra el ingreso) haría que la nota dejara ese asiento
-- colgado. Entonces «cuadra» es falso y «ajenos» dice cuáles son (los
-- cobros no cuentan aquí: fn_factura_anular los frena antes). «inactivas»:
-- las cuentas de la nota que ya no reciben asientos (c2 la pararía con
-- MX004). Nulo si la factura no tiene asiento vivo.
create or replace function public.fn_puente_nota_lineas(p_factura bigint, p_memo text)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_vivo    asientos := fn_puente_vivo('facturas', p_factura::text);
  v_cxc     text := fn_puente_cuenta_de('cxc');
  v_cret    text := fn_puente_cuenta_de('retencion_cxc');
  v_saldar  jsonb;
  v_ingreso jsonb;
  v_debe    numeric;
  v_ing     numeric;
  v_ajenos  text;
  v_inact   text;
  v_codigos text;
begin
  if v_vivo.id is null then
    return null;
  end if;
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'cuenta', x.cuenta, 'monto', (-x.saldo)::text, 'proyecto_id', x.proyecto_id, 'cost_code', x.cost_code, 'co', x.co,
           'fase', x.fase, 'tercero_tipo', x.tercero_tipo, 'tercero_id', x.tercero_id,
           'partida_tabla', 'facturas', 'partida_id', p_factura::text, 'memo', p_memo))
           order by x.cuenta, x.proyecto_id nulls first, x.co nulls first), '[]'::jsonb),
         coalesce(sum(x.saldo), 0)
    into v_saldar, v_debe
    from (select l.cuenta, l.proyecto_id, l.cost_code, l.co, l.fase, l.tercero_tipo, l.tercero_id, sum(l.monto) as saldo
            from asiento_lineas l
           where l.partida_tabla = 'facturas' and l.partida_id = p_factura::text and l.cuenta in (v_cxc, v_cret)
           group by l.cuenta, l.proyecto_id, l.cost_code, l.co, l.fase, l.tercero_tipo, l.tercero_id
          having sum(l.monto) <> 0) x;
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'cuenta', l.cuenta, 'monto', (-l.monto)::text, 'proyecto_id', l.proyecto_id, 'cost_code', l.cost_code, 'co', l.co,
           'fase', l.fase, 'tercero_tipo', l.tercero_tipo, 'tercero_id', l.tercero_id,
           'partida_tabla', l.partida_tabla, 'partida_id', l.partida_id, 'memo', p_memo)) order by l.orden), '[]'::jsonb),
         coalesce(sum(l.monto), 0)
    into v_ingreso, v_ing
    from asiento_lineas l
   where l.asiento_id = v_vivo.id
     and not (l.partida_tabla = 'facturas' and l.partida_id = p_factura::text and l.cuenta in (v_cxc, v_cret));
  if v_debe + v_ing <> 0 then
    select string_agg(distinct a.numero || coalesce(' (' || nullif(btrim(a.descripcion), '') || ')', ''), '; ')
      into v_ajenos
      from asiento_lineas l
      join asientos a on a.id = l.asiento_id
     where l.partida_tabla = 'facturas' and l.partida_id = p_factura::text and l.cuenta in (v_cxc, v_cret)
       and not (coalesce(a.origen_tabla, '') = 'facturas' and coalesce(a.origen_id, '') = p_factura::text)
       and coalesce(a.origen_tabla, '') not in ('cobros', 'aplicaciones_cobro')
       and a.camino not in ('reverso', 'reverso_automatico')
       and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso');
  end if;
  select string_agg(distinct format('%s (%s)', c.codigo, c.nombre), ', '), string_agg(distinct quote_literal(c.codigo), ', ')
    into v_inact, v_codigos
    from jsonb_array_elements(v_saldar || v_ingreso) x
    join cuentas c on c.codigo = x->>'cuenta'
   where not c.activa;
  return jsonb_strip_nulls(jsonb_build_object('lineas', v_saldar || v_ingreso, 'cuadra', v_debe + v_ing = 0,
                                              'debe_hoy', v_debe, 'asiento', v_vivo.numero, 'ajenos', v_ajenos,
                                              'inactivas', v_inact, 'inactivas_sql', v_codigos));
end $$;
revoke execute on function public.fn_puente_nota_lineas(bigint, text) from public, anon, authenticated, service_role;

-- La nota de crédito: salda su factura como está hoy (fn_puente_nota_lineas:
-- lo que su partida debe en 1110 y 1120, y el espejo de su ingreso), en su
-- fecha y con su número. El asiento de la factura no se reversa: la
-- factura se emitió; la nota de crédito es otro papel que la compensa.
create or replace function public.fn_puente_nota_plan(p_id uuid)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  n       notas_credito;
  f       facturas;
  v_doc   jsonb;
  v_firma text;
  v_lin   jsonb;
begin
  select * into n from notas_credito where id = p_id;
  if not found then
    return fn_puente_plan_no('no_aplica', 'no_existe', 'La nota de crédito ya no existe.', null, null);
  end if;
  select * into f from facturas where id = n.anula_a;
  v_doc := jsonb_build_object('numero', n.numero, 'anula_a', n.anula_a, 'fecha', n.fecha, 'monto', n.monto::text);
  v_firma := md5(v_doc::text);
  v_lin := fn_puente_nota_lineas(n.anula_a, 'Nota de crédito ' || n.numero || ' · anula la factura #' || f.num);
  if v_lin is null then
    return fn_puente_plan_no('pendiente', 'factura_sin_asiento',
      format('La factura #%s que anula no tiene asiento vivo.', f.num), v_firma, v_doc);
  end if;
  if not (v_lin->>'cuadra')::boolean then
    return fn_puente_plan_no('pendiente', 'partida_movida',
      format('La partida de la factura #%s tiene asientos que no son ni ella ni sus cobros (%s): la nota de crédito los dejaría '
             'colgados. Se reversan antes (fn_reversar).', f.num, coalesce(v_lin->>'ajenos', '?')), v_firma, v_doc);
  end if;
  return jsonb_build_object(
    'accion', 'postear', 'firma', v_firma, 'documento', v_doc, 'fecha_documento', n.fecha,
    'asiento', jsonb_build_object(
      'descripcion', format('Nota de crédito %s · anula la factura #%s', n.numero, f.num),
      'lineas', v_lin->'lineas',
      'origen_tabla', 'notas_credito', 'origen_id', n.id::text,
      'procedencia', jsonb_build_object('funcion', 'fn_puente_nota', 'anula_asiento', v_lin->>'asiento', 'motivo', n.motivo,
                                        'salda', format('lo que la factura debía hoy en su partida (%s) y el espejo de su ingreso',
                                                        v_lin->>'debe_hoy'))));
end $$;
revoke execute on function public.fn_puente_nota_plan(uuid) from public, anon, authenticated, service_role;


-- ---------------------------------------------------------------------
-- B.4 · Aplicar un plan: el corazón de los puentes. En este orden:
--   1. Si el papel ya tiene asiento vivo y su firma es la misma: nada
--      (correr el puente dos veces no duplica ni mueve nada).
--   2. Si no hay asiento vivo y el plan no postea: solo apunta el estado
--      (la bandeja).
--   3. Si HAY asiento vivo y el plan de hoy no postea, se decide si el
--      papel dejó de contar o solo le falta algo:
--      · deja de contar POR SÍ MISMO (anulado, en 0, de antes del corte,
--        ya en la apertura; el plan dice no_aplica o en_apertura): su
--        reverso, sin asiento nuevo (paso 5) — salvo que el asiento vivo use
--        una cuenta que ya está inactiva: ese reverso dejaría ahí un saldo
--        que nadie podría mover (c1), y el asiento se queda con su aviso
--        hasta que se reactive;
--      · le falta una REGLA o un dato (un proveedor escrito con otro
--        nombre, una categoría o una forma de pago que el mapeo no conoce,
--        una duda de la bandeja): el asiento vivo SE QUEDA como estaba —la
--        deuda y el costo siguen siendo reales— y el papel sale en la
--        bandeja como aviso, con qué falta. Cuando se resuelva, el plan
--        postea y el puente pone el reverso y el asiento nuevo juntos (solo,
--        o con fn_puentes_correr). Es la misma regla que ya sigue rehacer:
--        nunca un reverso suelto por una regla.
--   4. Desde aquí se escribe en el libro: primero el candado de períodos
--      (ver la cabecera del bloque B).
--   5. Si había asiento vivo (el papel cambió, ya no se contabiliza, o se
--      pide rehacer): su reverso (fn_reversar_interno de c2: la fecha, el
--      mes cerrado y el ajuste de un ejercicio anterior los decide c2), con
--      el motivo en llano: qué cambió. Rehacer a pedido solo si el plan de
--      hoy postea: si no, MX008 y nada cambia (nunca un reverso suelto).
--   6. Si el plan postea: la fecha con la regla del documento tardío, y el
--      asiento por fn_postear_interno (camino puente, con su papel de
--      origen); si el papel ya tuvo un asiento reversado, el nuevo dice a
--      cuál sustituye. En la procedencia: la firma, el papel, la FECHA DEL
--      PAPEL (fecha_documento: con ella c2 sabe si el sustituto de un
--      asiento de otro año es un papel del año nuevo), las reglas, qué lo
--      disparó (y con qué rol: rol_bd e usuario_id los pone c2), la nota
--      del tardío y lo que cambió; si no había asiento vivo (se había
--      reversado: anulado, en 0), lo que cambió es contra el último que se
--      contabilizó, y queda por qué se reversó aquel.
-- ---------------------------------------------------------------------
create or replace function public.fn_puente_aplicar(p_tabla text, p_id text, p_plan jsonb, p_disparo text,
                                                    p_forzar boolean default false, p_motivo text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_vivo    asientos;
  v_rev     jsonb;
  v_fecha   jsonb;
  v_sust    uuid;
  v_proc    jsonb;
  v_asi     jsonb;
  v_res     jsonb;
  v_cambios text;
  v_antes   text;
  v_motivo  text;
  v_inact   text;
  v_edgar   text := nullif(btrim(coalesce(p_motivo, current_setting('mx_puente.motivo', true))), '');
begin
  v_vivo := fn_puente_vivo(p_tabla, p_id);

  -- 1. El papel no cambió. (Si el plan trae un aviso para lo contabilizado,
  -- queda apuntado: sale en la bandeja como aviso.)
  if v_vivo.id is not null and not p_forzar
     and (v_vivo.procedencia->>'firma') is not distinct from (p_plan->>'firma') then
    perform fn_puente_marcar(p_tabla, p_id, 'contabilizado', p_plan->'aviso'->>'codigo', p_plan->'aviso'->>'motivo',
                             v_vivo.id, p_plan->>'firma');
    return jsonb_build_object('accion', 'sin_cambios', 'asiento', v_vivo.numero);
  end if;

  -- 2. Nada vivo y nada que postear. Un papel que ya no existe (se guardó
  -- y se borró en la misma transacción, sin entrar nunca al libro) no deja
  -- memoria en el puente.
  if v_vivo.id is null and p_plan->>'accion' <> 'postear' then
    if p_plan->>'codigo' = 'no_existe' then
      delete from puente_documentos where tabla = p_tabla and documento_id = p_id;
      return jsonb_build_object('accion', 'no_aplica', 'codigo', 'no_existe');
    end if;
    perform fn_puente_marcar(p_tabla, p_id, p_plan->>'accion', p_plan->>'codigo', p_plan->>'motivo', null, p_plan->>'firma');
    return jsonb_build_object('accion', p_plan->>'accion', 'codigo', p_plan->>'codigo', 'motivo', p_plan->>'motivo');
  end if;

  -- Rehacer (a pedido) es reverso + asiento NUEVO. Si con las reglas de hoy
  -- el papel no se contabiliza, no se toca nada: un reverso suelto sacaría
  -- del libro un papel que sigue vivo (una factura con su cobro), o
  -- anularía dos veces lo que ya compensa otro papel (la factura anulada y
  -- su nota de crédito).
  if p_forzar and p_plan->>'accion' <> 'postear' then
    raise exception using errcode = 'MX008',
      message = format('No se rehace %s %s: con las reglas de hoy no se contabiliza (%s). %s Su asiento %s se queda como está.',
                       p_tabla, p_id, p_plan->>'codigo', p_plan->>'motivo', v_vivo.numero);
  end if;

  -- 3. Hay asiento vivo y el plan de hoy no postea: ¿dejó de contar, o le
  -- falta algo?
  if v_vivo.id is not null and p_plan->>'accion' <> 'postear' then
    if not coalesce(p_plan->>'accion' = 'no_aplica' or p_plan->>'codigo' = 'en_apertura', false) then
      perform fn_puente_marcar(p_tabla, p_id, 'contabilizado', p_plan->>'codigo',
        format('El papel cambió y todavía no se puede volver a contabilizar: %s Mientras, su asiento %s se queda como estaba (la '
               'deuda y el costo siguen siendo reales); en cuanto se resuelva, el puente lo reversa y pone el nuevo (solo, o con '
               'select fn_puentes_correr();).', p_plan->>'motivo', v_vivo.numero),
        v_vivo.id, v_vivo.procedencia->>'firma');
      return jsonb_build_object('accion', 'retenido', 'asiento', v_vivo.numero, 'codigo', p_plan->>'codigo',
                                'motivo', p_plan->>'motivo');
    end if;
    v_inact := fn_puente_cuentas_inactivas(v_vivo.id);
    if v_inact is not null then
      perform fn_puente_marcar(p_tabla, p_id, 'contabilizado', 'cuenta_inactiva',
        format('%s Pero su asiento %s usa %s, que ya está inactiva: el reverso dejaría ahí un saldo que nadie podría mover (c1). '
               'Reactívala (update cuentas set activa = true where codigo = ''…'';) y el puente lo reversa solo (select '
               'fn_puentes_correr();); después, sin saldo, se vuelve a inactivar.', p_plan->>'motivo', v_vivo.numero, v_inact),
        v_vivo.id, v_vivo.procedencia->>'firma');
      return jsonb_build_object('accion', 'retenido', 'asiento', v_vivo.numero, 'codigo', 'cuenta_inactiva',
                                'motivo', p_plan->>'motivo');
    end if;
  end if;

  -- 4. El candado de los períodos, antes del primer asiento.
  perform 1 from periodos for share;

  -- 5. El reverso del asiento vivo.
  if v_vivo.id is not null then
    v_cambios := fn_puente_cambios(v_vivo.procedencia->'documento', p_plan->'documento');
    v_motivo := case
                  when p_forzar then 'Rehecho con las reglas de hoy, a pedido'
                  when p_plan->>'accion' = 'postear' then 'El papel cambió después de contabilizado: ' || v_cambios
                  else format('El papel ya no se contabiliza (%s): %s', p_plan->>'codigo', p_plan->>'motivo')
                end || coalesce('. Motivo de Edgar: ' || v_edgar, '');
    -- (Un reverso sin sustituto guarda también cómo quedó el papel: si
    -- vuelve a contar —des-anulado, su total otra vez—, su asiento nuevo
    -- dice qué cambió desde entonces: «estado: anulado → leido».)
    v_rev := fn_reversar_interno(v_vivo.id, v_motivo, 'reverso',
                                 jsonb_build_object('funcion', 'fn_puente_aplicar', 'disparo', p_disparo,
                                                    'documento', jsonb_build_object('tabla', p_tabla, 'id', p_id),
                                                    'cambios', v_cambios)
                                 || case when p_plan->>'accion' <> 'postear' and p_plan ? 'documento'
                                         then jsonb_build_object('papel_despues', p_plan->'documento')
                                         else '{}'::jsonb end);
  end if;

  if p_plan->>'accion' <> 'postear' then
    perform fn_puente_marcar(p_tabla, p_id, p_plan->>'accion', p_plan->>'codigo', p_plan->>'motivo', null, p_plan->>'firma');
    return jsonb_build_object('accion', 'reversado', 'reverso', v_rev->>'numero', 'motivo', v_motivo);
  end if;

  -- 6. El asiento (el primero, o el sustituto del reversado).
  v_fecha := fn_puente_fecha((p_plan->>'fecha_documento')::date);
  v_sust  := fn_puente_sustituible(p_tabla, p_id);
  -- Sin asiento vivo pero con uno reversado (anulado y des-anulado, en 0 y
  -- con su total otra vez): qué cambió desde que se reversó (el papel como
  -- quedó entonces, si su reverso lo guardó; si no, el del último asiento),
  -- y por qué se reversó aquel.
  if v_sust is not null and v_cambios is null then
    select case when r.procedencia ? 'papel_despues'
                then fn_puente_cambios(r.procedencia->'papel_despues', p_plan->'documento')
                else fn_puente_cambios(a.procedencia->'documento', p_plan->'documento') end,
           r.numero || ': ' || r.motivo
      into v_cambios, v_antes
      from asientos a
      left join lateral (select x.numero, x.motivo, x.procedencia from asientos x
                          where x.reversa_a = a.id and x.camino = 'reverso'
                          order by x.cadena_pos desc limit 1) r on true
     where a.id = v_sust;
  end if;
  v_proc  := coalesce(p_plan->'asiento'->'procedencia', '{}'::jsonb)
             || jsonb_build_object('firma', p_plan->>'firma', 'documento', p_plan->'documento', 'disparo', p_disparo,
                                   'fecha_documento', p_plan->>'fecha_documento')
             || case when v_fecha ? 'nota'
                     then jsonb_build_object('tardio', jsonb_build_object('fecha_documento', p_plan->>'fecha_documento',
                                                                          'nota', v_fecha->>'nota'))
                     else '{}'::jsonb end
             || case when v_sust is not null
                     then jsonb_strip_nulls(jsonb_build_object(
                            'sustituye', (select a.numero from asientos a where a.id = v_sust),
                            'cambios', coalesce(v_cambios, 'vuelve a contabilizarse'),
                            'reverso_anterior', v_antes))
                     else '{}'::jsonb end
             || case when v_edgar is not null then jsonb_build_object('motivo_edgar', v_edgar) else '{}'::jsonb end;
  v_asi := (p_plan->'asiento')
           || jsonb_build_object('camino', 'puente', 'fecha', v_fecha->>'fecha', 'procedencia', v_proc)
           || case when v_fecha->>'tipo' = 'ajuste_cpa'
                   then jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', v_fecha->>'afecta_periodo',
                                           'motivo', v_fecha->>'nota')
                   else '{}'::jsonb end
           || case when v_sust is not null then jsonb_build_object('sustituye_a', v_sust) else '{}'::jsonb end;
  v_res := fn_postear_interno(v_asi);
  perform fn_puente_marcar(p_tabla, p_id, 'contabilizado', p_plan->'aviso'->>'codigo', p_plan->'aviso'->>'motivo',
                           (v_res->>'id')::uuid, p_plan->>'firma');
  return jsonb_strip_nulls(jsonb_build_object(
    'accion', case when v_sust is not null then 'sustituido' else 'posteado' end,
    'asiento', v_res->>'numero', 'reverso', v_rev->>'numero', 'fecha_contable', v_res->>'fecha_contable',
    'tardio', v_fecha->>'nota'));
end $$;
revoke execute on function public.fn_puente_aplicar(text, text, jsonb, text, boolean, text) from public, anon, authenticated, service_role;

-- Los puentes, uno por papel: la fila del papel quieta mientras se
-- contabiliza (el trigger ya la tiene; el backfill la toma antes), y su plan
-- aplicado. p_forzar: rehacer con las reglas de hoy (fn_puentes_rehacer).
create or replace function public.fn_puente_recibo(p_id bigint, p_disparo text default 'trigger',
                                                   p_forzar boolean default false, p_motivo text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform 1 from recibos where id = p_id for update;
  return fn_puente_aplicar('recibos', p_id::text, fn_puente_recibo_plan(p_id), p_disparo, p_forzar, p_motivo);
end $$;
revoke execute on function public.fn_puente_recibo(bigint, text, boolean, text) from public, anon, authenticated, service_role;

create or replace function public.fn_puente_externo(p_id bigint, p_disparo text default 'trigger',
                                                    p_forzar boolean default false, p_motivo text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform 1 from trabajos_externos where id = p_id for update;
  return fn_puente_aplicar('trabajos_externos', p_id::text, fn_puente_externo_plan(p_id), p_disparo, p_forzar, p_motivo);
end $$;
revoke execute on function public.fn_puente_externo(bigint, text, boolean, text) from public, anon, authenticated, service_role;

create or replace function public.fn_puente_factura(p_id bigint, p_disparo text default 'trigger',
                                                    p_forzar boolean default false, p_motivo text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform 1 from facturas where id = p_id for update;
  return fn_puente_aplicar('facturas', p_id::text, fn_puente_factura_plan(p_id), p_disparo, p_forzar, p_motivo);
end $$;
revoke execute on function public.fn_puente_factura(bigint, text, boolean, text) from public, anon, authenticated, service_role;

create or replace function public.fn_puente_cobro(p_id uuid, p_disparo text default 'registrar',
                                                  p_forzar boolean default false, p_motivo text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform 1 from cobros where id = p_id for update;
  return fn_puente_aplicar('cobros', p_id::text, fn_puente_cobro_plan(p_id), p_disparo, p_forzar, p_motivo);
end $$;
revoke execute on function public.fn_puente_cobro(uuid, text, boolean, text) from public, anon, authenticated, service_role;

create or replace function public.fn_puente_aplicacion(p_id uuid, p_disparo text default 'aplicar')
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform 1 from aplicaciones_cobro where id = p_id for update;
  return fn_puente_aplicar('aplicaciones_cobro', p_id::text, fn_puente_aplicacion_plan(p_id), p_disparo);
end $$;
revoke execute on function public.fn_puente_aplicacion(uuid, text) from public, anon, authenticated, service_role;

create or replace function public.fn_puente_nota(p_id uuid, p_disparo text default 'anular')
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
begin
  perform 1 from notas_credito where id = p_id for update;
  return fn_puente_aplicar('notas_credito', p_id::text, fn_puente_nota_plan(p_id), p_disparo);
end $$;
revoke execute on function public.fn_puente_nota(uuid, text) from public, anon, authenticated, service_role;


-- ---------------------------------------------------------------------
-- B.5 · Los triggers de los papeles de la app.
--   · La GUARDA (before): contabilizado_en solo lo pone el puente; un
--     recibo que sube un trabajador entra «por leer» (el dinero lo ponen la
--     lectura o Edgar), a su nombre y con su sesión activa; el equipo no
--     edita ni borra recibos (la RLS ya lo dice, pero una vista de dueño
--     como recibos_equipo se la salta: la guarda no depende de ella); la
--     llave del teléfono de un recibo no cambia; un papel que está o
--     estuvo en el libro no se borra (MX003, con qué hacer según por qué
--     está), y uno que nunca entró se borra como siempre y sale de la
--     bandeja; a una factura del libro no se le cambia monto, fecha, obra,
--     número ni retención, su estado solo cambia al anularla con su nota de
--     crédito, y una anulada no se cobra. SECURITY DEFINER: tiene que ver
--     el libro sea quien sea quien borra (con RLS, alguien que no es el
--     dueño vería cero y el papel se borraría).
--   · El PUENTE (después): un trigger de restricción DIFERIDO, que corre al
--     confirmar la transacción y lee el papel como quedó. Así un papel que
--     se escribe en varios pasos en la misma transacción (la lectura de
--     cerebro) entra una vez, ya completo, y no deja reversos de paso.
--     Atrapa cualquier error: el papel se guarda igual y el error queda en
--     la bandeja. SECURITY DEFINER: postea por la puerta interna del libro,
--     que no ejecuta nadie de la API.
-- ---------------------------------------------------------------------

-- Por qué un papel de la app no se borra, en llano (nulo = nunca entró al
-- libro y se borra como siempre). El arreglo depende de por qué está:
--   · tiene su asiento VIVO: se anula y el libro lo reversa solo; el papel
--     se queda como rastro (p_anular dice cómo). Un recibo, con
--     fn_recibo_anular: 'anulado' es lo único que la app saca de sus listas
--     («📥 Por completar», el gasto de la obra, la fecha del Notice to
--     Owner); con el total en 0 sale del libro, pero la app lo sigue
--     enseñando, y sin obra se queda en «Por completar» para siempre;
--   · lo nombra la APERTURA como partida: ponerlo en 0 no la toca; se
--     corrige la apertura con un ajuste contra su partida;
--   · sus asientos ya están reversados: es el rastro de esos reversos, y
--     ya no suma nada en el libro. Un recibo que la app todavía enseña (no
--     está anulado) se anula para quitarlo de sus listas: el libro no
--     cambia;
--   · lo nombra otro asiento como partida (un pago): se corrige ese.
create or replace function public.fn_puente_no_se_borra(p_tabla text, p_id text, p_anular text)
returns text
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_libro text := fn_puente_en_libro(p_tabla, p_id);
  v_vivo  asientos;
  v_aper  jsonb;
  v_papel text := case p_tabla when 'recibos' then 'Este recibo' else 'Este trabajo externo' end;
begin
  if v_libro is null then
    return null;
  end if;
  v_vivo := fn_puente_vivo(p_tabla, p_id);
  if v_vivo.id is not null then
    return format('%s ya está en el libro contable (%s): no se borra. %s', v_papel, v_libro, p_anular);
  end if;
  v_aper := fn_puente_en_apertura(p_tabla, p_id);
  if v_aper is not null then
    return format('%s está en la apertura (%s) como deuda con %s por %s: no se borra, y ponerlo en 0 no toca la apertura. Si '
                  'está repetido o ya no se debe, se corrige la apertura con un ajuste (tipo ajuste_cpa, afecta_periodo = ''%s'') '
                  'contra su partida %s/%s.', v_papel, v_aper->>'asientos', v_aper->>'a_quien',
                  abs((v_aper->>'saldo')::numeric), v_aper->>'apertura', p_tabla, p_id);
  end if;
  if exists (select 1 from asientos a where a.origen_tabla = p_tabla and a.origen_id = p_id) then
    if p_tabla = 'recibos'
       and exists (select 1 from recibos r where r.id = p_id::bigint and r.estado is distinct from 'anulado') then
      return format('%s estuvo en el libro contable (%s, ya reversado): es el rastro de esos asientos y no se borra. En el libro ya '
                    'no suma nada. Para quitarlo también de las listas de la app («📥 Por completar», el gasto de la obra), '
                    'anúlalo: select fn_recibo_anular(%s, ''motivo''); (desde Contabilidad cuando esté). El libro no cambia.',
                    v_papel, v_libro, p_id);
    end if;
    return format('%s estuvo en el libro contable (%s, ya reversado): es el rastro de esos asientos y no se borra. Ya no suma '
                  'nada: no hace falta hacer más.', v_papel, v_libro);
  end if;
  return format('%s está en el libro contable porque otro asiento lo nombra (%s): no se borra, y ponerlo en 0 no toca ese '
                'asiento. Si está mal, se corrige ese asiento.', v_papel, v_libro);
end $$;
revoke execute on function public.fn_puente_no_se_borra(text, text, text) from public, anon, authenticated, service_role;

create or replace function public.fn_puente_recibos_guarda()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_libro text;
  -- Quién puede escribir el dinero de un recibo: Edgar (por la app o el
  -- SQL Editor) y la lectura del recibo (cerebro, con service_role).
  v_priv  boolean := es_dueno() or fn_desde_editor() or fn_rol_llamante() = 'service_role';
begin
  if tg_op = 'INSERT' then
    if new.contabilizado_en is not null then
      raise exception using errcode = 'MX003', message = 'contabilizado_en lo pone solo el puente (es el asiento vivo del recibo).';
    end if;
    -- Lo que sube el equipo va a nombre de quien lo sube, con su sesión
    -- activa (lo mismo que su policy, pero aquí no se lo salta una vista de
    -- dueño): ni anon, ni un trabajador dado de baja, ni a nombre de otro.
    if not v_priv and (new.autor_id is distinct from auth.uid() or not es_activo()) then
      raise exception using errcode = '42501',
        message = 'Un recibo lo sube su autor, con su sesión activa: a nombre de otro, o sin sesión, no entra.';
    end if;
    -- Lo que un trabajador sube entra «por leer»: el total, la fecha, la
    -- forma de pago y la categoría los pone la lectura del recibo (cerebro)
    -- o Edgar. La app del equipo ya sube así (foto, obra, nota, CO y, a
    -- mano, el proveedor); esto cierra el atajo de mandar por la API un
    -- recibo ya «leído» con el monto y la forma de pago que uno quiera, que
    -- el puente contabilizaría (una deuda a un proveedor, un reembolso).
    if not v_priv
       and (new.total is not null or new.subtotal is not null or new.tax is not null or new.fecha is not null
            or new.metodo_pago is not null or new.ultimos4 is not null or new.num_recibo is not null
            or coalesce(new.estado, 'por_leer') <> 'por_leer' or coalesce(new.categoria, 'material') <> 'material') then
      raise exception using errcode = '42501',
        message = 'Un recibo del equipo entra «por leer»: el total, la fecha, la categoría y la forma de pago los pone la lectura '
                  'del recibo o Edgar.';
    end if;
    -- Y la hora de subida la pone la base (la app del equipo no la manda):
    -- sin fecha leída, es la que cuenta para el mes del gasto.
    if not v_priv then
      new.creado := now();
    end if;
    -- La FOTO es el papel que va a leer la lectura (cerebro lee lo que hay
    -- en esa ruta): la de un recibo nuevo es de este recibo. No la de otro
    -- recibo —recibos_equipo le enseña a todo el equipo la ruta de todos, y
    -- apuntar a la foto de un ticket ya contabilizado lo hacía entrar otra
    -- vez, a la obra que uno quisiera o como reembolso a su nombre—, salvo
    -- el MISMO envío otra vez (el doble toque sin señal, con su misma llave:
    -- a ese lo para la llave única con su 409, «ya estaba»).
    if nullif(btrim(new.ruta), '') is not null
       and exists (select 1 from recibos o
                    where nullif(btrim(o.ruta), '') = btrim(new.ruta)
                      and (new.llave_cliente is null or o.llave_cliente is distinct from new.llave_cliente)) then
      raise exception using errcode = case when v_priv then 'MX003' else '42501' end,
        message = format('Esa foto (%s) ya es la de otro recibo (%s): una foto es el papel de un solo recibo. Sube la foto de este.',
                         btrim(new.ruta), (select string_agg(o.id::text, ', ') from recibos o
                                            where nullif(btrim(o.ruta), '') = btrim(new.ruta)));
    end if;
    -- Y lo que sube el equipo va en la carpeta de recibos (así sube la app:
    -- recibos/<obra>/…) y no es un archivo que subió otra persona (un
    -- documento del dueño, la foto de un recibo borrado de otro).
    if not v_priv and nullif(btrim(new.ruta), '') is not null
       and (btrim(new.ruta) not like 'recibos/%' or fn_puente_foto_ajena(btrim(new.ruta))) then
      raise exception using errcode = '42501',
        message = 'La foto de un recibo del equipo es suya y va en recibos/ (la que sube la app): no un archivo de otro.';
    end if;
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if new.contabilizado_en is distinct from old.contabilizado_en
       and coalesce(current_setting('mx_puente.escribe', true), '') <> 'recibos:' || old.id then
      raise exception using errcode = 'MX003', message = 'contabilizado_en lo pone solo el puente (es el asiento vivo del recibo).';
    end if;
    -- El equipo no edita recibos: la RLS solo deja a Edgar, y esto vale
    -- aunque se entre por una vista de dueño (recibos_equipo). Lo único que
    -- cambia en nombre de un trabajador es el asiento vivo que le pone el
    -- puente al confirmar lo que subió.
    if not v_priv and (to_jsonb(new) - 'contabilizado_en') is distinct from (to_jsonb(old) - 'contabilizado_en') then
      raise exception using errcode = '42501',
        message = 'Un recibo lo corrige Edgar (o la lectura del recibo): el equipo lo sube y ya.';
    end if;
    if old.llave_cliente is not null and new.llave_cliente is distinct from old.llave_cliente then
      raise exception using errcode = 'MX003',
        message = 'La llave del teléfono de un recibo no cambia: es la que evita que un doble toque sin señal lo suba dos veces.';
    end if;
    if new.id is distinct from old.id then
      v_libro := fn_puente_en_libro('recibos', old.id::text);
      if v_libro is not null then
        raise exception using errcode = 'MX003',
          message = format('Este recibo ya está en el libro contable (%s): su número ya no cambia.', v_libro);
      end if;
    end if;
    -- Una foto nueva (📷) no puede ser la de otro recibo.
    if nullif(btrim(new.ruta), '') is not null and nullif(btrim(new.ruta), '') is distinct from nullif(btrim(old.ruta), '')
       and exists (select 1 from recibos o where o.id <> old.id and nullif(btrim(o.ruta), '') = btrim(new.ruta)) then
      raise exception using errcode = 'MX003',
        message = format('Esa foto (%s) ya es la de otro recibo (%s): una foto es el papel de un solo recibo.', btrim(new.ruta),
                         (select string_agg(o.id::text, ', ') from recibos o
                           where o.id <> old.id and nullif(btrim(o.ruta), '') = btrim(new.ruta)));
    end if;
    -- Un recibo ANULADO no vuelve con un update cualquiera. El ✎ de la app
    -- manda estado = 'leido' cada vez que lleva total (y enseña los
    -- anulados con su ✎): apuntarle una nota a un repetido ya anulado lo
    -- metía otra vez al libro, sin que nadie lo pidiera. Se queda anulado
    -- (la nota, el proveedor y el total que manda sí se guardan). Volver a
    -- contarlo es a propósito, con su motivo: fn_recibo_desanular.
    if old.estado = 'anulado' and new.estado is distinct from 'anulado'
       and coalesce(current_setting('mx_puente.escribe', true), '') <> 'recibos_desanular:' || old.id then
      new.estado := 'anulado';
    end if;
    return new;
  end if;
  -- DELETE: solo Edgar (la RLS lo dice; esto, aunque se entre por una vista).
  if not v_priv then
    raise exception using errcode = '42501', message = 'Un recibo lo borra solo Edgar.';
  end if;
  v_libro := fn_puente_no_se_borra('recibos', old.id::text,
               format('Si está repetido o no va, anúlalo: select fn_recibo_anular(%s, ''motivo''); (desde Contabilidad cuando esté). '
                      'El libro lo reversa solo, el recibo se queda como rastro y sale de las listas de la app. (Ponerle el total '
                      'en 0 con ✎ también lo saca del libro, pero la app lo sigue enseñando, y sin obra se queda en «📥 Por '
                      'completar».)', old.id));
  if v_libro is not null then
    raise exception using errcode = 'MX003', message = v_libro;
  end if;
  -- Nunca entró al libro: se borra como siempre, y con él lo que el puente
  -- apuntó de él (que no quede en la bandeja un papel que ya no existe).
  delete from puente_documentos where tabla = 'recibos' and documento_id = old.id::text;
  return old;
end $$;
revoke execute on function public.fn_puente_recibos_guarda() from public, anon, authenticated, service_role;

create or replace function public.fn_puente_externos_guarda()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_libro text;
begin
  if tg_op = 'INSERT' then
    if new.contabilizado_en is not null then
      raise exception using errcode = 'MX003', message = 'contabilizado_en lo pone solo el puente.';
    end if;
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if new.contabilizado_en is distinct from old.contabilizado_en
       and coalesce(current_setting('mx_puente.escribe', true), '') <> 'trabajos_externos:' || old.id then
      raise exception using errcode = 'MX003', message = 'contabilizado_en lo pone solo el puente.';
    end if;
    if new.id is distinct from old.id and fn_puente_en_libro('trabajos_externos', old.id::text) is not null then
      raise exception using errcode = 'MX003', message = 'Este trabajo externo ya está en el libro contable: su número ya no cambia.';
    end if;
    return new;
  end if;
  v_libro := fn_puente_no_se_borra('trabajos_externos', old.id::text,
               format('Si estaba mal, anúlalo: su costo queda en 0 y el libro lo reversa (en el SQL Editor: select '
                      'fn_externo_anular(%s, ''motivo''); desde Contabilidad cuando esté). Después anota el bueno.', old.id));
  if v_libro is not null then
    raise exception using errcode = 'MX003', message = v_libro;
  end if;
  delete from puente_documentos where tabla = 'trabajos_externos' and documento_id = old.id::text;
  return old;
end $$;
revoke execute on function public.fn_puente_externos_guarda() from public, anon, authenticated, service_role;

create or replace function public.fn_puente_facturas_guarda()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_libro text;
  v_marca text := coalesce(current_setting('mx_puente.escribe', true), '');
begin
  if tg_op = 'INSERT' then
    if new.contabilizado_en is not null then
      raise exception using errcode = 'MX003', message = 'contabilizado_en lo pone solo el puente.';
    end if;
    if new.estado = 'anulada' then
      raise exception using errcode = 'MX003', message = 'Una factura nace emitida (o en borrador); se anula después, con su nota de crédito.';
    end if;
    return new;
  end if;
  v_libro := fn_puente_en_libro('facturas', old.id::text);
  if tg_op = 'UPDATE' then
    if new.contabilizado_en is distinct from old.contabilizado_en and v_marca <> 'facturas:' || old.id then
      raise exception using errcode = 'MX003', message = 'contabilizado_en lo pone solo el puente.';
    end if;
    if new.estado is distinct from old.estado
       and (old.estado = 'anulada' or (new.estado = 'anulada' and v_marca <> 'facturas_anular:' || old.id)) then
      raise exception using errcode = 'MX003',
        message = format('La factura #%s se anula solo con su nota de crédito (select fn_factura_anular(%s, ''motivo'');), '
                         'y una anulada no vuelve.', old.num, old.id);
    end if;
    -- Una anulada no se cobra: la app todavía no conoce el estado y la
    -- enseña «por cobrar» (ver la cabecera), y tocar ✓ cobrada le pondría
    -- cobrado = monto y lo sumaría a lo cobrado de la obra. Desmarcarla sí
    -- se puede.
    if old.estado = 'anulada'
       and ((coalesce(new.pagada, false) and not coalesce(old.pagada, false))
            or coalesce(new.cobrado, 0) > coalesce(old.cobrado, 0)
            or (new.cobrada_el is not null and new.cobrada_el is distinct from old.cobrada_el)) then
      raise exception using errcode = 'MX003',
        message = format('La factura #%s está anulada%s: no se cobra. Si el cliente pagó de verdad, ese dinero va a la factura '
                         'buena o queda de anticipo de la obra.', old.num,
                         coalesce(' (' || (select n.numero from notas_credito n where n.anula_a = old.id) || ')', ''));
    end if;
    if v_libro is not null then
      if (new.id, new.monto, new.fecha, new.proyecto_id, new.num)
         is distinct from (old.id, old.monto, old.fecha, old.proyecto_id, old.num) then
        raise exception using errcode = 'MX003',
          message = format('La factura #%s ya está en el libro contable (%s): su monto, fecha, obra, número y retención '
                           'ya no cambian. Si está mal, se anula con nota de crédito (select fn_factura_anular(%s, ''motivo'');) '
                           'y se hace la buena.', old.num, v_libro, old.id);
      end if;
      -- La retención tampoco, pero no se arregla anulando una factura buena:
      -- si entró mal repartida (todo a 1110), se reclasifica contra su
      -- partida con un asiento a mano.
      if new.retencion is distinct from old.retencion then
        raise exception using errcode = 'MX003',
          message = format('La factura #%s ya está en el libro contable (%s) con retención %s: la retención ya no cambia en el '
                           'papel. Si quedó mal repartida, se reclasifica con un asiento a mano contra su partida: Dr %s / Cr %s '
                           'por lo retenido (o al revés), las dos líneas con su obra y partida facturas/%s (fn_postear).',
                           old.num, v_libro, coalesce(old.retencion::text, 'ninguna'), fn_puente_cuenta_de('retencion_cxc'),
                           fn_puente_cuenta_de('cxc'), old.id);
      end if;
      if new.estado = 'borrador' and old.estado <> 'borrador' then
        raise exception using errcode = 'MX003',
          message = format('La factura #%s ya está en el libro contable: no vuelve a borrador.', old.num);
      end if;
    end if;
    return new;
  end if;
  -- DELETE
  if v_libro is not null then
    raise exception using errcode = 'MX003',
      message = format('La factura #%s ya está en el libro contable (%s): una factura emitida no se borra. Se anula con '
                       'nota de crédito: select fn_factura_anular(%s, ''motivo''); (desde Contabilidad cuando esté).',
                       old.num, v_libro, old.id);
  end if;
  if exists (select 1 from aplicaciones_cobro a where a.factura_id = old.id)
     or exists (select 1 from notas_credito n where n.anula_a = old.id) then
    raise exception using errcode = 'MX003',
      message = format('La factura #%s tiene cobros o una nota de crédito registrados: no se borra.', old.num);
  end if;
  delete from puente_documentos where tabla = 'facturas' and documento_id = old.id::text;
  return old;
end $$;
revoke execute on function public.fn_puente_facturas_guarda() from public, anon, authenticated, service_role;

-- Los puentes diferidos. Si lo único que cambió es contabilizado_en (la
-- escritura del propio puente), no hay nada que hacer.
create or replace function public.fn_puente_recibos_despues()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE' and (to_jsonb(new) - 'contabilizado_en') = (to_jsonb(old) - 'contabilizado_en') then
    return null;
  end if;
  begin
    perform fn_puente_recibo(new.id, lower(tg_op));
  exception when others then
    perform fn_puente_marcar_error('recibos', new.id::text, sqlstate, sqlerrm);
  end;
  return null;
end $$;
revoke execute on function public.fn_puente_recibos_despues() from public, anon, authenticated, service_role;

create or replace function public.fn_puente_externos_despues()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE' and (to_jsonb(new) - 'contabilizado_en') = (to_jsonb(old) - 'contabilizado_en') then
    return null;
  end if;
  begin
    perform fn_puente_externo(new.id, lower(tg_op));
  exception when others then
    perform fn_puente_marcar_error('trabajos_externos', new.id::text, sqlstate, sqlerrm);
  end;
  return null;
end $$;
revoke execute on function public.fn_puente_externos_despues() from public, anon, authenticated, service_role;

create or replace function public.fn_puente_facturas_despues()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE' and (to_jsonb(new) - 'contabilizado_en') = (to_jsonb(old) - 'contabilizado_en') then
    return null;
  end if;
  begin
    perform fn_puente_factura(new.id, lower(tg_op));
  exception when others then
    perform fn_puente_marcar_error('facturas', new.id::text, sqlstate, sqlerrm);
  end;
  return null;
end $$;
revoke execute on function public.fn_puente_facturas_despues() from public, anon, authenticated, service_role;

create or replace trigger trg_puente_recibos_guarda
  before insert or update or delete on public.recibos
  for each row execute function public.fn_puente_recibos_guarda();
create or replace trigger trg_puente_externos_guarda
  before insert or update or delete on public.trabajos_externos
  for each row execute function public.fn_puente_externos_guarda();
create or replace trigger trg_puente_facturas_guarda
  before insert or update or delete on public.facturas
  for each row execute function public.fn_puente_facturas_guarda();

-- (Un trigger de restricción no admite «or replace»: se borra y se crea,
-- dentro de la transacción del pegado.)
drop trigger if exists trg_puente_recibos_despues on public.recibos;
create constraint trigger trg_puente_recibos_despues
  after insert or update on public.recibos
  deferrable initially deferred
  for each row execute function public.fn_puente_recibos_despues();
drop trigger if exists trg_puente_externos_despues on public.trabajos_externos;
create constraint trigger trg_puente_externos_despues
  after insert or update on public.trabajos_externos
  deferrable initially deferred
  for each row execute function public.fn_puente_externos_despues();
drop trigger if exists trg_puente_facturas_despues on public.facturas;
create constraint trigger trg_puente_facturas_despues
  after insert or update on public.facturas
  deferrable initially deferred
  for each row execute function public.fn_puente_facturas_despues();

-- Una obra con papeles en el libro no se borra (su borrado arrastraría los
-- papeles en cascada). c2 ya la frena si tiene líneas con su obra; esto
-- cubre los papeles que entraron sin obra en la línea (un recibo de
-- gasolina de esa obra, un cobro) y lo dice por su nombre.
create or replace function public.fn_puente_proyectos_guarda()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (select 1 from recibos r where r.proyecto_id = old.id and fn_puente_en_libro('recibos', r.id::text) is not null)
     or exists (select 1 from facturas f where f.proyecto_id = old.id and fn_puente_en_libro('facturas', f.id::text) is not null)
     or exists (select 1 from trabajos_externos x
                 where x.proyecto_id = old.id and fn_puente_en_libro('trabajos_externos', x.id::text) is not null)
     or exists (select 1 from cobros c where c.proyecto_id = old.id)
     or exists (select 1 from aplicaciones_cobro a where a.proyecto_id = old.id) then
    raise exception using errcode = 'MX003',
      message = format('La obra «%s» tiene papeles en el libro contable (recibos, facturas, trabajos externos o cobros): no se '
                       'puede borrar. Si ya no se trabaja en ella, márcala Completado (o No aprobado).',
                       coalesce(nullif(btrim(old.nombre), ''), old.id));
  end if;
  return old;
end $$;
revoke execute on function public.fn_puente_proyectos_guarda() from public, anon, authenticated, service_role;

create or replace trigger trg_puente_proyectos_guarda
  before delete on public.proyectos
  for each row execute function public.fn_puente_proyectos_guarda();

-- El trigger de materiales de la app (trg_recibo_marca_material, AFTER
-- INSERT OR UPDATE, sin lista de columnas) marca «comprado» los materiales
-- en falta de la obra cuya descripción sale en las notas del recibo. Su
-- función solo lee la obra, las notas y el estado. Pero corría con
-- CUALQUIER update del recibo, también con el del propio puente
-- (contabilizado_en) en el backfill, en «reintentar» y al rehacer: volvía a
-- leer las notas de un recibo viejo y se llevaba un material nuevo de la
-- misma obra que nadie había comprado (el cable, la tubería: se vuelven a
-- comprar). Se rehace con la MISMA función, solo cuando cambian esas tres
-- columnas: subir, leer, ✎ (manda las notas), 📌 y anular siguen igual.
-- Solo si existe como lo dejó la app (si no, no es de este archivo).
do $$
begin
  if exists (select 1 from pg_trigger t
              where t.tgrelid = 'public.recibos'::regclass and t.tgname = 'trg_recibo_marca_material' and not t.tgisinternal
                and t.tgfoid = to_regprocedure('public.fn_recibo_marca_material()')) then
    execute 'create or replace trigger trg_recibo_marca_material
               after insert or update of proyecto_id, notas, estado on public.recibos
               for each row execute function public.fn_recibo_marca_material()';
  end if;
end $$;

-- Las vistas de la app para el equipo (recibos_equipo, proyectos_equipo…)
-- corren con los permisos de su dueño, que se salta la RLS, y en Supabase
-- nacen con escritura para anon y authenticated: por ellas un trabajador
-- podía anular, reactivar, mover de obra o borrar recibos, y el puente lo
-- llevaba al libro. La app solo las LEE (js/db.js): se les quita la
-- escritura, y se les deja la lectura. (Además la guarda de recibos ya no
-- depende de la RLS.) El control vistas de fn_puentes_verificar vigila que
-- ninguna vista de dueño sobre los papeles se pueda escribir por la API.
do $$
declare
  v text;
begin
  foreach v in array array['recibos_equipo', 'proyectos_equipo', 'materiales_equipo', 'alcances_equipo', 'documentos_equipo'] loop
    if to_regclass('public.' || v) is not null then
      execute format('revoke insert, update, delete, truncate, references, trigger on public.%I from public, anon, authenticated', v);
    end if;
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- B.6 · Las horas: NUNCA postean dinero. Su guarda, que convive con
-- trg_guarda_correccion (corre después de ella: el orden de los triggers
-- es el alfabético, y ese flujo sigue igual; esa guarda ya no corre cuando
-- lo único que cambia es la aprobación, ver abajo):
--   · la aprobación (aprobado_por, aprobado_el) la pone o la quita solo el
--     dueño (o el SQL Editor): un trabajador con permiso de corrección no
--     se aprueba sus horas;
--   · si unas horas APROBADAS cambian (una corrección con permiso, o Edgar
--     las edita), la aprobación se cae sola y queda escrito: lo aprobado ya
--     no es lo que hay, y hay que volver a aprobarlo; si Edgar cambia las
--     horas y el sello en el mismo update, quedan escritas las dos cosas
--     (lo de antes invalidado, lo de ahora aprobado);
--   · el número de un reporte (id) no cambia si está o estuvo aprobado, ni
--     nunca desde el teléfono del equipo;
--   · cada aprobación, retirada, invalidación o borrado de horas aprobadas
--     queda en horas_aprobaciones.
-- SECURITY DEFINER: apunta en horas_aprobaciones, que no tiene policy de
-- escritura, aunque quien corrige sea un trabajador.
-- ---------------------------------------------------------------------
create or replace function public.fn_puente_horas_guarda()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_dueno  boolean := es_dueno() or fn_desde_editor();
  v_rol    text    := fn_rol_llamante();
  v_cambio boolean;
begin
  if tg_op = 'INSERT' then
    if (new.aprobado_por is not null or new.aprobado_el is not null) and not v_dueno then
      raise exception using errcode = '42501', message = 'Las horas las aprueba Edgar: un reporte nuevo entra sin aprobar.';
    end if;
    if new.aprobado_el is not null then
      insert into horas_aprobaciones (horas_id, accion, usuario_id, fecha, proyecto_id, horas, aprobado_por, hecho_por, rol)
      values (new.id, 'aprobada', new.usuario_id, new.fecha, new.proyecto_id, new.horas, new.aprobado_por, auth.uid(), v_rol);
    end if;
    return new;
  end if;
  if tg_op = 'DELETE' then
    if old.aprobado_el is not null then
      insert into horas_aprobaciones (horas_id, accion, usuario_id, fecha, proyecto_id, horas, aprobado_por, hecho_por, rol, detalle)
      values (old.id, 'borrada', old.usuario_id, old.fecha, old.proyecto_id, old.horas, old.aprobado_por, auth.uid(), v_rol,
              jsonb_build_object('aprobado_el', old.aprobado_el));
    end if;
    return old;
  end if;
  -- UPDATE
  -- El NÚMERO de un reporte de horas no cambia si está o estuvo aprobado: su
  -- aprobación (horas_aprobaciones, el «reporte de horas aprobado») lo
  -- nombra, y renumerado quedaría una hora aprobada sin su aprobación (y un
  -- devengo que cambia de firma cada vez). Desde el teléfono del equipo, ni
  -- eso: la guarda de correcciones de la app no mira el id.
  if new.id is distinct from old.id
     and (not v_dueno or old.aprobado_el is not null
          or exists (select 1 from horas_aprobaciones a where a.horas_id = old.id)) then
    raise exception using errcode = 'MX003',
      message = format('El reporte de horas %s no cambia de número: %s', old.id,
                       case when not v_dueno then 'desde el teléfono del equipo, un reporte no se renumera.'
                            else 'está (o estuvo) aprobado, y su aprobación lo nombra.' end);
  end if;
  if (new.aprobado_por, new.aprobado_el) is distinct from (old.aprobado_por, old.aprobado_el) and not v_dueno then
    raise exception using errcode = '42501',
      message = 'Las horas las aprueba Edgar: un reporte no se aprueba ni se desaprueba desde el teléfono del equipo.';
  end if;
  v_cambio := (new.horas, new.fecha, new.proyecto_id, new.usuario_id, new.co, new.fase)
              is distinct from (old.horas, old.fecha, old.proyecto_id, old.usuario_id, old.co, old.fase);
  if old.aprobado_el is not null and v_cambio and new.aprobado_el is not distinct from old.aprobado_el then
    new.aprobado_por := null;
    new.aprobado_el  := null;
    insert into horas_aprobaciones (horas_id, accion, usuario_id, fecha, proyecto_id, horas, aprobado_por, hecho_por, rol, detalle)
    values (old.id, 'invalidada', new.usuario_id, new.fecha, new.proyecto_id, new.horas, old.aprobado_por, auth.uid(), v_rol,
            jsonb_build_object('antes', jsonb_build_object('horas', old.horas, 'fecha', old.fecha, 'proyecto_id', old.proyecto_id,
                                                           'co', old.co, 'fase', old.fase),
                               'aprobado_el', old.aprobado_el,
                               'nota', 'Las horas cambiaron después de aprobadas: hay que volver a aprobarlas.'));
  elsif old.aprobado_el is not null and v_cambio and new.aprobado_el is not null then
    -- Cambian las horas Y el sello en el mismo update (Edgar, por la API o
    -- el SQL Editor): lo aprobado antes ya no es lo que hay, y lo de ahora
    -- queda aprobado. Las dos cosas quedan escritas.
    insert into horas_aprobaciones (horas_id, accion, usuario_id, fecha, proyecto_id, horas, aprobado_por, hecho_por, rol, detalle)
    values (old.id, 'invalidada', old.usuario_id, old.fecha, old.proyecto_id, old.horas, old.aprobado_por, auth.uid(), v_rol,
            jsonb_build_object('aprobado_el', old.aprobado_el,
                               'nota', 'Las horas cambiaron en el mismo cambio que su aprobación: lo aprobado antes ya no vale.'));
    insert into horas_aprobaciones (horas_id, accion, usuario_id, fecha, proyecto_id, horas, aprobado_por, hecho_por, rol, detalle)
    values (new.id, 'aprobada', new.usuario_id, new.fecha, new.proyecto_id, new.horas, new.aprobado_por, auth.uid(), v_rol,
            jsonb_build_object('antes', jsonb_build_object('horas', old.horas, 'fecha', old.fecha, 'proyecto_id', old.proyecto_id,
                                                           'co', old.co, 'fase', old.fase, 'aprobado_el', old.aprobado_el)));
  elsif old.aprobado_el is null and new.aprobado_el is not null then
    insert into horas_aprobaciones (horas_id, accion, usuario_id, fecha, proyecto_id, horas, aprobado_por, hecho_por, rol)
    values (new.id, 'aprobada', new.usuario_id, new.fecha, new.proyecto_id, new.horas, new.aprobado_por, auth.uid(), v_rol);
  elsif old.aprobado_el is not null and new.aprobado_el is null then
    insert into horas_aprobaciones (horas_id, accion, usuario_id, fecha, proyecto_id, horas, aprobado_por, hecho_por, rol, detalle)
    values (old.id, 'retirada', old.usuario_id, old.fecha, old.proyecto_id, old.horas, old.aprobado_por, auth.uid(), v_rol,
            jsonb_strip_nulls(jsonb_build_object('aprobado_el', old.aprobado_el,
                                                 'motivo', nullif(current_setting('mx_puente.motivo', true), ''))));
  elsif (new.aprobado_por, new.aprobado_el) is distinct from (old.aprobado_por, old.aprobado_el) then
    -- El sello cambia con las mismas horas (se volvió a aprobar): también
    -- queda escrito.
    insert into horas_aprobaciones (horas_id, accion, usuario_id, fecha, proyecto_id, horas, aprobado_por, hecho_por, rol, detalle)
    values (new.id, 'aprobada', new.usuario_id, new.fecha, new.proyecto_id, new.horas, new.aprobado_por, auth.uid(), v_rol,
            jsonb_build_object('antes', jsonb_build_object('aprobado_por', old.aprobado_por, 'aprobado_el', old.aprobado_el)));
  end if;
  return new;
end $$;
revoke execute on function public.fn_puente_horas_guarda() from public, anon, authenticated, service_role;

create or replace trigger trg_puente_horas_guarda
  before insert or update or delete on public.horas
  for each row execute function public.fn_puente_horas_guarda();

-- La guarda de correcciones de la app (trg_guarda_correccion) reconoce al
-- dueño solo por auth.uid(), que en el SQL Editor es nulo: aprobar desde ahí
-- chocaba con «Pídele permiso a Edgar…» (dicho al propio Edgar), y en un
-- reporte con permiso de corrección sin usar se comía ese permiso. Esa guarda
-- vigila lo que el trabajador reporta; la aprobación (aprobado_por,
-- aprobado_el) no la conoce y la vigila la guarda de horas de aquí arriba.
-- Se rehace con la MISMA función y una condición: corre siempre, salvo
-- cuando lo ÚNICO que cambia es la aprobación. Solo si existe como lo dejó
-- la app.
do $$
begin
  if exists (select 1 from pg_trigger t
              where t.tgrelid = 'public.horas'::regclass and t.tgname = 'trg_guarda_correccion' and not t.tgisinternal
                and t.tgfoid = to_regprocedure('public.fn_guarda_correccion()')) then
    execute $t$
      create or replace trigger trg_guarda_correccion
        before update on public.horas
        for each row
        when (   (to_jsonb(new) - array['aprobado_por', 'aprobado_el']) is distinct from (to_jsonb(old) - array['aprobado_por', 'aprobado_el'])
              or (new.aprobado_por, new.aprobado_el) is not distinct from (old.aprobado_por, old.aprobado_el))
        execute function public.fn_guarda_correccion()
    $t$;
  end if;
end $$;


-- ---------------------------------------------------------------------
-- B.7 · Las funciones de la app que tocan el libro (las de verdad; pisan a
-- las mínimas del bloque A). SECURITY DEFINER, con es_dueno() por dentro,
-- en el reparto de c2 (c_fn_app_fases) y en sus huellas.
-- ---------------------------------------------------------------------

-- Un monto que llega como texto: numérico, con dos decimales como mucho
-- (el libro va en centavos; el redondeo no se decide a escondidas) y dentro
-- de rango. p_cero: si admite 0.
create or replace function public.fn_puente_monto(p_texto text, p_que text, p_cero boolean default false)
returns numeric
language plpgsql
immutable
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
    raise exception using errcode = 'MX005', message = format('%s: «%s» no es un monto.', p_que, p_texto);
  end;
  if scale(v) is null or abs(v) >= 1000000000000 then
    raise exception using errcode = 'MX005', message = format('%s: «%s» no es un monto.', p_que, p_texto);
  end if;
  if scale(v) > 2 then
    raise exception using errcode = 'MX005',
      message = format('%s: %s trae %s decimales; el libro va en centavos (máximo 2).', p_que, p_texto, scale(v));
  end if;
  if v < 0 or (v = 0 and not p_cero) then
    raise exception using errcode = 'MX005', message = format('%s tiene que ser mayor que cero (llegó %s).', p_que, p_texto);
  end if;
  return v;
end $$;
revoke execute on function public.fn_puente_monto(text, text, boolean) from public, anon, authenticated, service_role;

-- Una fecha que llega como texto AAAA-MM-DD (nunca en un formato que
-- dependa de la sesión).
create or replace function public.fn_puente_fecha_texto(p_texto text, p_que text)
returns date
language plpgsql
immutable
set search_path = public, pg_temp
as $$
begin
  if p_texto is null or p_texto !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception using errcode = '22007', message = format('%s va como texto AAAA-MM-DD (llegó «%s»).', p_que, coalesce(p_texto, ''));
  end if;
  begin
    return p_texto::date;
  exception when others then
    raise exception using errcode = '22007', message = format('%s: la fecha %s no existe.', p_que, p_texto);
  end;
end $$;
revoke execute on function public.fn_puente_fecha_texto(text, text) from public, anon, authenticated, service_role;

-- El saldo de una partida en una cuenta (lo que falta por cobrar de una
-- factura en 1110 o en 1120; negativo = a favor del cliente).
create or replace function public.fn_puente_saldo(p_cuenta text, p_tabla text, p_id text)
returns numeric
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce(sum(l.monto), 0)
    from asiento_lineas l
   where l.cuenta = p_cuenta and l.partida_tabla = p_tabla and l.partida_id = p_id
$$;
revoke execute on function public.fn_puente_saldo(text, text, text) from public, anon, authenticated, service_role;

-- EL BACKFILL Y EL «REINTENTAR»: pasa el puente por todos los papeles desde
-- p_desde (por omisión, el corte del 1-oct-2026; nunca antes), y por los
-- recibos y trabajos externos SUBIDOS desde entonces aunque su fecha sea de
-- antes (un año mal leído no se queda sin mirar). Idempotente:
-- lo que ya está contabilizado y no cambió no se toca; lo que cambió se
-- reversa y se sustituye; lo pendiente se vuelve a intentar (por ejemplo,
-- después de confirmar un mapeo). Un papel que alguien está guardando en
-- este mismo momento se salta (su propio trigger lo contabiliza). Cada
-- papel va en su propia subtransacción: un error queda en la bandeja y el
-- resto sigue. Devuelve cuántos pasó y cómo quedó la bandeja.
create or replace function public.fn_puentes_correr(p_desde date default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_desde date;
  v_id    text;
  v_tabla text;
  v_n     int := 0;
  v_salta int := 0;
  v_error int := 0;
  v_uno   int;
begin
  perform fn_puente_exigir_dueno();
  v_desde := greatest(coalesce(p_desde, fn_puente_corte()), fn_puente_corte());
  perform 1 from periodos for share;
  for v_tabla, v_id in
    select 'recibos', r.id::text from recibos r
     where coalesce(r.fecha, fn_fecha_miami(r.creado)) >= v_desde or r.contabilizado_en is not null
        or (r.creado at time zone 'America/New_York')::date >= v_desde
        or exists (select 1 from puente_documentos d
                    where d.tabla = 'recibos' and d.documento_id = r.id::text and d.estado in ('pendiente', 'espera', 'error'))
    union all
    select 'trabajos_externos', x.id::text from trabajos_externos x
     where coalesce(x.fecha, fn_fecha_miami(x.creado)) >= v_desde or x.contabilizado_en is not null
        or (x.creado at time zone 'America/New_York')::date >= v_desde
        or exists (select 1 from puente_documentos d
                    where d.tabla = 'trabajos_externos' and d.documento_id = x.id::text and d.estado in ('pendiente', 'espera', 'error'))
    union all
    select 'facturas', f.id::text from facturas f
     where f.fecha is null or f.fecha >= v_desde or f.contabilizado_en is not null
    union all
    select 'cobros', c.id::text from cobros c
     where c.fecha >= v_desde or c.contabilizado_en is not null
    union all
    select 'aplicaciones_cobro', a.id::text from aplicaciones_cobro a
     where a.desde_anticipo and (a.fecha >= v_desde or a.contabilizado_en is not null)
    union all
    select 'notas_credito', n.id::text from notas_credito n
     where n.fecha >= v_desde or n.contabilizado_en is not null
    order by 1, 2
  loop
    begin
      -- (EXECUTE no mueve FOUND: se mira lo que devolvió.)
      v_uno := null;
      execute format('select 1 from public.%I where id = $1::%s for update skip locked', v_tabla,
                     case when v_tabla in ('cobros', 'aplicaciones_cobro', 'notas_credito') then 'uuid' else 'bigint' end)
        into v_uno using v_id;
      if v_uno is null then
        v_salta := v_salta + 1;
      else
        case v_tabla
          when 'recibos'            then perform fn_puente_recibo(v_id::bigint, 'correr');
          when 'trabajos_externos'  then perform fn_puente_externo(v_id::bigint, 'correr');
          when 'facturas'           then perform fn_puente_factura(v_id::bigint, 'correr');
          when 'cobros'             then perform fn_puente_cobro(v_id::uuid, 'correr');
          when 'aplicaciones_cobro' then perform fn_puente_aplicacion(v_id::uuid, 'correr');
          when 'notas_credito'      then perform fn_puente_nota(v_id::uuid, 'correr');
        end case;
        v_n := v_n + 1;
      end if;
    exception when others then
      perform fn_puente_marcar_error(v_tabla, v_id, sqlstate, sqlerrm);
      v_error := v_error + 1;
    end;
  end loop;
  return jsonb_build_object(
    'desde', v_desde, 'pasados', v_n, 'en_uso_saltados', v_salta, 'errores', v_error,
    'estado', (select coalesce(jsonb_object_agg(t.tabla, t.estados), '{}'::jsonb)
                 from (select d.tabla, jsonb_object_agg(d.estado, d.n) as estados
                         from (select tabla, estado, count(*) as n from puente_documentos group by tabla, estado) d
                        group by d.tabla) t));
end $$;
revoke execute on function public.fn_puentes_correr(date) from public, anon, authenticated, service_role;
grant  execute on function public.fn_puentes_correr(date) to authenticated;

-- Rehacer el asiento de un papel con las reglas de HOY (una regla estaba
-- mal y ya se corrigió): reverso + asiento nuevo, enlazados, con el motivo.
-- Las reglas que cambian no rehacen solas lo ya contabilizado: esto es a
-- propósito, papel por papel. Siempre las dos cosas o ninguna: si con las
-- reglas de hoy el papel no se contabiliza, MX008 y nada cambia
-- (fn_puente_aplicar). Una factura anulada no se rehace: su asiento se
-- queda y lo compensa su nota de crédito.
create or replace function public.fn_puentes_rehacer(p_tabla text, p_id text, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_nc text;
begin
  perform fn_puente_exigir_dueno();
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Rehacer un asiento dice por qué (motivo).';
  end if;
  if p_tabla = 'facturas' then
    begin
      select n.numero into v_nc from notas_credito n where n.anula_a = p_id::bigint;
      if v_nc is not null or exists (select 1 from facturas f where f.id = p_id::bigint and f.estado = 'anulada') then
        raise exception using errcode = 'MX008',
          message = format('La factura %s está anulada%s: no se rehace. Su asiento se queda y lo compensa su nota de crédito.',
                           p_id, coalesce(' (' || v_nc || ')', ''));
      end if;
    exception when invalid_text_representation then
      raise exception using errcode = '22023', message = format('«%s» no es el número interno de una factura.', p_id);
    end;
  end if;
  perform 1 from periodos for share;
  case p_tabla
    when 'recibos'           then return fn_puente_recibo(p_id::bigint, 'rehacer', true, p_motivo);
    when 'trabajos_externos' then return fn_puente_externo(p_id::bigint, 'rehacer', true, p_motivo);
    when 'facturas'          then return fn_puente_factura(p_id::bigint, 'rehacer', true, p_motivo);
    when 'cobros'            then return fn_puente_cobro(p_id::uuid, 'rehacer', true, p_motivo);
    else
      raise exception using errcode = '22023',
        message = format('Se rehacen recibos, trabajos_externos, facturas o cobros (llegó «%s»).', coalesce(p_tabla, ''));
  end case;
end $$;
revoke execute on function public.fn_puentes_rehacer(text, text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_puentes_rehacer(text, text, text) to authenticated;

-- REGISTRAR UN COBRO (el depósito que Edgar ya ve en el banco, o el cheque
-- que va a depositar). Lo que llega, como en fn_postear, en JSON y con los
-- montos como texto:
--   { "fecha": "2026-10-12", "monto": "3200.50", "cuenta": "1010",
--     "medio": "cheque", "referencia": "1234", "proyecto_id": "…",
--     "notas": "…", "movimiento_id": "…" (f06),
--     "llave_cliente": "…" (la del teléfono, como en recibos),
--     "aplicaciones": [ { "factura_id": 2, "monto": "3000.00",
--                         "es_retencion": false, "descuento": "0.00" },
--                       { "proyecto_id": "…", "monto": "200.50" } ] }
-- Cada aplicación va a una factura que está en el libro (la del puente, o
-- una de antes del corte con su saldo en la apertura), de fecha igual o
-- anterior al cobro (lo cobrado antes de facturar es un anticipo de la
-- obra, y se aplica con fn_anticipo_aplicar cuando la factura se emite), y
-- no puede cobrar más de lo que esa factura tiene abierto en su cuenta; sin
-- factura, queda de anticipo de su obra. Las aplicaciones suman el cobro,
-- al centavo. Entra a una cuenta de BANCO (10xx). Se postea en el acto: Dr
-- el banco / Cr las partidas.
-- DOS A LA VEZ: antes de mirar el estado y el saldo de sus facturas, el
-- cobro toma sus filas (en orden de id: el mismo candado que toma
-- fn_factura_anular). Así dos cobros a la misma factura, o un cobro
-- mientras se anula, se esperan, y el segundo ve lo que dejó el primero.
-- El MISMO cobro mandado dos veces (un doble toque, un reintento tras un
-- corte): con su llave_cliente entra una vez; la segunda devuelve el que ya
-- estaba (ya_estaba), y con otros datos, MX008. Un movimiento del banco
-- casa con un solo cobro vigente.
-- La casilla «pagada» de la app no cambia: la sigue llevando Edgar a mano
-- durante el paralelo (ver la cabecera, punto 10).
create or replace function public.fn_cobro_registrar(p_cobro jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sobra  text;
  v_fecha  date;
  v_monto  numeric;
  v_cuenta text;
  v_c      cuentas;
  v_id     uuid;
  v_a      jsonb;
  v_i      int := 0;
  v_suma   numeric := 0;
  v_fact   facturas;
  v_obra   text;
  v_am     numeric;
  v_desc   numeric;
  v_ret    boolean;
  v_cta    text;
  v_saldo  numeric;
  v_ya     numeric;
  v_res    jsonb;
  v_apps   jsonb := '[]'::jsonb;
  v_llave  text;
  v_mov    text;
  v_ids    bigint[] := '{}';
  v_fids   bigint[] := '{}';
  v_fid    bigint;
  v_txt    text;
  v_prev   cobros;
  v_otro   cobros;
  v_huella text;
begin
  perform fn_puente_exigir_dueno();
  if p_cobro is null or jsonb_typeof(p_cobro) <> 'object' then
    raise exception using errcode = '22023', message = 'El cobro llega como un objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p_cobro) k
   where k not in ('fecha', 'monto', 'cuenta', 'medio', 'referencia', 'proyecto_id', 'notas', 'movimiento_id', 'llave_cliente',
                   'aplicaciones');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en el cobro: %s.', v_sobra);
  end if;
  v_fecha := fn_puente_fecha_texto(p_cobro->>'fecha', 'La fecha del cobro');
  if v_fecha < fn_puente_corte() then
    raise exception using errcode = 'MX002',
      message = format('Un cobro del %s es de antes del corte (%s): ese dinero vive en QuickBooks.', v_fecha, fn_puente_corte());
  end if;
  v_monto := fn_puente_monto(p_cobro->>'monto', 'El monto del cobro');
  v_cuenta := coalesce(nullif(btrim(p_cobro->>'cuenta'), ''), fn_puente_cuenta_de('banco'));
  select * into v_c from cuentas where codigo = v_cuenta;
  if fn_puente_cuenta_mal(v_cuenta) is not null or not fn_puente_es_banco(v_cuenta) then
    raise exception using errcode = 'MX004',
      message = format('El cobro entra a una cuenta de banco (10xx, de activo, sin obra), y %s no lo es (%s).', v_cuenta,
                       coalesce(fn_puente_cuenta_mal(v_cuenta), v_c.nombre));
  end if;
  if nullif(btrim(p_cobro->>'proyecto_id'), '') is not null
     and not exists (select 1 from proyectos p where p.id = btrim(p_cobro->>'proyecto_id')) then
    raise exception using errcode = '22023', message = format('La obra %s no existe.', p_cobro->>'proyecto_id');
  end if;
  if jsonb_typeof(p_cobro->'aplicaciones') is distinct from 'array' or jsonb_array_length(p_cobro->'aplicaciones') = 0 then
    raise exception using errcode = '22023',
      message = 'El cobro dice a qué va (aplicaciones): a una o varias facturas, a su retención, o de anticipo de una obra.';
  end if;
  v_llave := nullif(btrim(p_cobro->>'llave_cliente'), '');
  v_mov   := nullif(btrim(p_cobro->>'movimiento_id'), '');

  -- Cada factura_id se lee UNA vez, aquí, y ese mismo número es el que toma
  -- el candado de abajo, el que busca la factura y el que va en la huella
  -- de la llave. (Antes el candado solo tomaba los que casaban con una
  -- expresión estricta, y la búsqueda aceptaba « 3» o «+3»: con uno de
  -- esos, un cobro miraba el saldo sin haber tomado la factura, y dos
  -- cobros a la vez la cobraban dos veces.) v_fids va en el orden de las
  -- aplicaciones; nulo = sin factura (un anticipo).
  for v_a in select value from jsonb_array_elements(p_cobro->'aplicaciones') loop
    v_i := v_i + 1;
    if jsonb_typeof(v_a) <> 'object' then
      raise exception using errcode = '22023', message = format('Aplicación %s: va como objeto JSON.', v_i);
    end if;
    v_txt := nullif(btrim(v_a->>'factura_id'), '');
    v_fid := null;
    if v_txt is not null then
      if v_txt !~ '^[+-]?[0-9]{1,18}$' then
        raise exception using errcode = '22023',
          message = format('Aplicación %s: factura_id es el número interno de la factura (llegó «%s»).', v_i, v_a->>'factura_id');
      end if;
      v_fid := v_txt::bigint;
      v_ids := v_ids || v_fid;
    end if;
    v_fids := array_append(v_fids, v_fid);
  end loop;
  v_i := 0;

  -- Los candados, antes de mirar nada: los períodos (como fn_factura_anular),
  -- la llave y el movimiento (el mismo cobro dos veces se espera a sí
  -- mismo; candados de aviso de dos llaves, que no se cruzan con el de la
  -- cadena de c2, que es de una), y las filas de sus facturas, en orden de
  -- id.
  perform 1 from periodos for share;
  if v_llave is not null then
    perform pg_advisory_xact_lock(820260924, hashtext('cobro.llave:' || v_llave));
  end if;
  if v_mov is not null then
    perform pg_advisory_xact_lock(820260924, hashtext('cobro.movimiento:' || v_mov));
  end if;
  perform 1 from facturas where id = any (v_ids) order by id for update;

  -- La misma llave ya entró: es el mismo cobro, mandado otra vez.
  if v_llave is not null then
    select * into v_prev from cobros where llave_cliente = v_llave;
    if found then
      -- La huella de lo que se pide y la de lo que ya entró: fecha, monto,
      -- cuenta y a qué va cada parte.
      begin
        select format('%s|%s|%s|%s', v_fecha, trim_scale(v_monto), v_cuenta, string_agg(t.k, ',' order by t.k))
          into v_huella
          from (select format('%s/%s/%s/%s', coalesce(v_fids[x.n]::text, '-'), trim_scale((x.v->>'monto')::numeric),
                              coalesce((x.v->>'es_retencion')::boolean, false),
                              trim_scale(coalesce(nullif(btrim(x.v->>'descuento'), '')::numeric, 0))) as k
                  from jsonb_array_elements(p_cobro->'aplicaciones') with ordinality as x(v, n)) t;
      exception when others then
        v_huella := null;
      end;
      if v_huella is distinct from
         (select format('%s|%s|%s|%s', v_prev.fecha, trim_scale(v_prev.monto), v_prev.cuenta, string_agg(t.k, ',' order by t.k))
            from (select format('%s/%s/%s/%s', coalesce(a.factura_id::text, '-'), trim_scale(a.monto), a.es_retencion,
                                trim_scale(a.descuento)) as k
                    from aplicaciones_cobro a
                   where a.cobro_id = v_prev.id and not a.desde_anticipo) t) then
        raise exception using errcode = 'MX008',
          message = format('La llave %s ya es de otro cobro (del %s, por %s): el mismo cobro no se manda con otros datos.',
                           v_llave, v_prev.fecha, v_prev.monto);
      end if;
      return jsonb_build_object('cobro', v_prev.id, 'ya_estaba', true, 'estado', v_prev.estado,
                                'asiento', (select a.numero from asientos a where a.id = v_prev.contabilizado_en),
                                'fecha_contable', (select a.fecha_contable from asientos a where a.id = v_prev.contabilizado_en));
    end if;
  end if;
  -- Un movimiento del banco casa con UN cobro vigente.
  if v_mov is not null then
    select * into v_otro from cobros c where c.movimiento_id = v_mov and c.estado = 'vigente' limit 1;
    if found then
      raise exception using errcode = 'MX008',
        message = format('El movimiento del banco %s ya está en otro cobro vigente (del %s, por %s): el mismo dinero no entra dos '
                         'veces. Si ese estaba mal, anúlalo (fn_cobro_anular) y registra este.', v_mov, v_otro.fecha, v_otro.monto);
    end if;
  end if;

  -- Cada aplicación, mirada antes de escribir nada (con sus facturas ya
  -- tomadas: lo que se lee es lo último confirmado).
  for v_a in select value from jsonb_array_elements(p_cobro->'aplicaciones') loop
    v_i := v_i + 1;
    v_fid := v_fids[v_i];
    select string_agg(k, ', ' order by k) into v_sobra
      from jsonb_object_keys(v_a) k
     where k not in ('factura_id', 'proyecto_id', 'monto', 'es_retencion', 'descuento');
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Aplicación %s: clave desconocida: %s.', v_i, v_sobra);
    end if;
    v_am   := fn_puente_monto(v_a->>'monto', format('El monto de la aplicación %s', v_i));
    v_desc := case when coalesce(btrim(v_a->>'descuento'), '') = '' then 0
                   else fn_puente_monto(v_a->>'descuento', format('El descuento de la aplicación %s', v_i), true) end;
    begin
      v_ret := coalesce((v_a->>'es_retencion')::boolean, false);
    exception when others then
      raise exception using errcode = '22023', message = format('Aplicación %s: es_retencion es true o false.', v_i);
    end;
    v_suma := v_suma + v_am;
    if v_fid is null then
      v_obra := coalesce(nullif(btrim(v_a->>'proyecto_id'), ''), nullif(btrim(p_cobro->>'proyecto_id'), ''));
      if v_obra is null or not exists (select 1 from proyectos p where p.id = v_obra) then
        raise exception using errcode = '22023',
          message = format('Aplicación %s: sin factura, queda de anticipo de una obra, y dice de cuál (proyecto_id).', v_i);
      end if;
      if v_ret or v_desc <> 0 then
        raise exception using errcode = '22023',
          message = format('Aplicación %s: un anticipo no lleva retención ni descuento: esos son de una factura.', v_i);
      end if;
      v_apps := v_apps || jsonb_build_array(jsonb_build_object('factura_id', null, 'proyecto_id', v_obra, 'monto', v_am,
                                                               'es_retencion', false, 'descuento', 0));
      continue;
    end if;
    v_fact := null;
    select * into v_fact from facturas where id = v_fid;
    if v_fact.id is null then
      raise exception using errcode = '22023', message = format('Aplicación %s: no existe la factura %s.', v_i, v_fid);
    end if;
    if nullif(btrim(v_a->>'proyecto_id'), '') is not null and btrim(v_a->>'proyecto_id') is distinct from v_fact.proyecto_id then
      raise exception using errcode = 'MX006',
        message = format('Aplicación %s: la factura #%s es de la obra %s, no de %s.', v_i, v_fact.num, v_fact.proyecto_id,
                         v_a->>'proyecto_id');
    end if;
    if v_fact.estado = 'anulada' then
      raise exception using errcode = 'MX008', message = format('La factura #%s está anulada: no se le cobra.', v_fact.num);
    end if;
    if v_fact.contabilizado_en is null and coalesce(v_fact.fecha, fn_puente_corte()) >= fn_puente_corte() then
      raise exception using errcode = 'MX008',
        message = format('La factura #%s todavía no está en el libro (%s): resuélvela en la bandeja antes de cobrarla.', v_fact.num,
                         coalesce((select d.motivo from puente_documentos d
                                    where d.tabla = 'facturas' and d.documento_id = v_fact.id::text), 'sin pasar por el puente'));
    end if;
    -- Lo cobrado antes de facturar no se aplica a la factura: al cierre de
    -- ese mes, la cuenta por cobrar enseñaría una factura que todavía no
    -- existía. Es un anticipo de la obra.
    if v_fact.fecha > v_fecha then
      raise exception using errcode = 'MX002',
        message = format('Aplicación %s: el cobro (%s) es anterior a la factura #%s (%s). Déjalo de anticipo de la obra y '
                         'aplícalo cuando se emita (fn_anticipo_aplicar).', v_i, v_fecha, v_fact.num, v_fact.fecha);
    end if;
    -- Lo que la factura tiene abierto en esa cuenta, menos lo que ya se
    -- le aplica en este mismo cobro.
    v_cta   := case when v_ret then fn_puente_cuenta_de('retencion_cxc') else fn_puente_cuenta_de('cxc') end;
    v_saldo := fn_puente_saldo(v_cta, 'facturas', v_fact.id::text);
    select coalesce(sum((x->>'monto')::numeric + (x->>'descuento')::numeric), 0) into v_ya
      from jsonb_array_elements(v_apps) x
     where (x->>'factura_id')::bigint = v_fact.id and (x->>'es_retencion')::boolean = v_ret;
    if v_am + v_desc > v_saldo - v_ya then
      raise exception using errcode = 'MX008',
        message = format('La factura #%s tiene abiertos %s en %s y esta aplicación le cobra %s: no cabe.%s', v_fact.num,
                         v_saldo - v_ya, v_cta, v_am + v_desc,
                         case when v_fact.fecha < fn_puente_corte()
                              then ' Es de antes del corte: su saldo llega con la apertura (f04); regístralo cuando esté cargada.'
                              when v_ret then ' La retención de la factura se cobra hasta lo retenido. Si su retención entró a '
                                              || fn_puente_cuenta_de('cxc') || ', reclasifícala antes contra su partida (Dr '
                                              || fn_puente_cuenta_de('retencion_cxc') || ' / Cr ' || fn_puente_cuenta_de('cxc')
                                              || ', con fn_postear).'
                              else ' Lo que sobre, déjalo de anticipo de la obra.' end);
    end if;
    v_apps := v_apps || jsonb_build_array(jsonb_build_object('factura_id', v_fact.id, 'proyecto_id', v_fact.proyecto_id,
                                                             'monto', v_am, 'es_retencion', v_ret, 'descuento', v_desc));
  end loop;
  if v_suma <> v_monto then
    raise exception using errcode = 'MX001',
      message = format('Las aplicaciones suman %s y el cobro es de %s: tienen que sumar lo mismo, al centavo.', v_suma, v_monto);
  end if;

  insert into cobros (fecha, monto, cuenta, medio, referencia, proyecto_id, movimiento_id, notas, llave_cliente, creado_por)
  values (v_fecha, v_monto, v_cuenta, nullif(btrim(p_cobro->>'medio'), ''), nullif(btrim(p_cobro->>'referencia'), ''),
          nullif(btrim(p_cobro->>'proyecto_id'), ''), v_mov, nullif(btrim(p_cobro->>'notas'), ''), v_llave, auth.uid())
  returning id into v_id;
  insert into aplicaciones_cobro (cobro_id, factura_id, proyecto_id, monto, es_retencion, descuento, creado_por)
  select v_id, (x->>'factura_id')::bigint, x->>'proyecto_id', (x->>'monto')::numeric, (x->>'es_retencion')::boolean,
         (x->>'descuento')::numeric, auth.uid()
    from jsonb_array_elements(v_apps) x;

  v_res := fn_puente_cobro(v_id, 'registrar');
  if v_res->>'accion' not in ('posteado', 'sustituido', 'sin_cambios') then
    raise exception using errcode = 'MX008', message = format('El cobro no se pudo contabilizar: %s', v_res->>'motivo');
  end if;
  return jsonb_build_object('cobro', v_id, 'asiento', v_res->>'asiento', 'fecha_contable', v_res->>'fecha_contable',
                            'tardio', v_res->>'tardio');
end $$;
revoke execute on function public.fn_cobro_registrar(jsonb) from public, anon, authenticated, service_role;
grant  execute on function public.fn_cobro_registrar(jsonb) to authenticated;

-- ANULAR UN COBRO (el cheque rebotó, se registró dos veces): su asiento se
-- reversa, y también el de cada anticipo suyo que ya se había aplicado. El
-- cobro se queda, anulado, con su motivo: es el rastro.
create or replace function public.fn_cobro_anular(p_cobro uuid, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c        cobros;
  v_res    jsonb;
  v_apps   jsonb := '[]'::jsonb;
  v_inact  text;
  a        record;
begin
  perform fn_puente_exigir_dueno();
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Anular un cobro dice por qué (motivo).';
  end if;
  perform 1 from periodos for share;
  select * into c from cobros where id = p_cobro for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese cobro.';
  end if;
  if c.estado = 'anulado' then
    raise exception using errcode = 'MX008', message = format('Ese cobro ya estaba anulado (%s).', c.anulado_motivo);
  end if;
  -- Su asiento (y el de sus anticipos aplicados) no se reversa sobre una
  -- cuenta que ya está inactiva: el saldo quedaría atrapado en ella (c1).
  -- Se dice antes de tocar nada.
  select string_agg(distinct s.x, ', ') into v_inact
    from (select fn_puente_cuentas_inactivas((fn_puente_vivo('cobros', c.id::text)).id) as x
          union all
          select fn_puente_cuentas_inactivas((fn_puente_vivo('aplicaciones_cobro', ap.id::text)).id)
            from aplicaciones_cobro ap where ap.cobro_id = c.id and ap.desde_anticipo) s
   where s.x is not null;
  if v_inact is not null then
    raise exception using errcode = 'MX008',
      message = format('El asiento de ese cobro usa %s, que ya está inactiva: anularlo dejaría ahí un saldo que nadie podría mover. '
                       'Reactívala antes (update cuentas set activa = true where codigo = ''…'';), anula el cobro, y vuelve a '
                       'inactivarla cuando quede sin saldo.', v_inact);
  end if;
  perform set_config('mx_puente.escribe', 'cobros_anular:' || c.id, true);
  update cobros set estado = 'anulado', anulado_el = clock_timestamp(), anulado_motivo = btrim(p_motivo) where id = c.id;
  perform set_config('mx_puente.escribe', '', true);
  perform set_config('mx_puente.motivo', btrim(p_motivo), true);
  v_res := fn_puente_cobro(c.id, 'anular');
  for a in select x.id from aplicaciones_cobro x where x.cobro_id = c.id and x.desde_anticipo order by x.id loop
    v_apps := v_apps || jsonb_build_array(fn_puente_aplicacion(a.id, 'anular'));
  end loop;
  perform set_config('mx_puente.motivo', '', true);
  return jsonb_build_object('cobro', c.id, 'reverso', v_res->>'reverso', 'anticipos', v_apps);
end $$;
revoke execute on function public.fn_cobro_anular(uuid, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_cobro_anular(uuid, text) to authenticated;

-- APLICAR UN ANTICIPO a una factura de su obra: sin dinero nuevo (el
-- dinero entró con el cobro). Solo lo que el anticipo tiene disponible,
-- solo lo que la factura tiene abierto, y no antes de la factura (ni del
-- cobro). Toma el cobro y la factura antes de mirar sus saldos: dos
-- anticipos a la vez a la misma factura se esperan.
create or replace function public.fn_anticipo_aplicar(p_cobro uuid, p_factura bigint, p_monto text, p_fecha date default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c         cobros;
  f         facturas;
  v_monto   numeric;
  v_fecha   date;
  v_cxc     text := fn_puente_cuenta_de('cxc');
  v_disp    numeric;
  v_saldo   numeric;
  v_id      uuid;
  v_res     jsonb;
begin
  perform fn_puente_exigir_dueno();
  perform 1 from periodos for share;
  select * into c from cobros where id = p_cobro for update;
  if not found or c.estado <> 'vigente' then
    raise exception using errcode = 'MX008', message = 'Ese cobro no existe o está anulado.';
  end if;
  select * into f from facturas where id = p_factura for update;
  if not found then
    raise exception using errcode = '22023', message = format('No existe la factura %s.', p_factura);
  end if;
  if f.estado = 'anulada' then
    raise exception using errcode = 'MX008', message = format('La factura #%s está anulada.', f.num);
  end if;
  if f.contabilizado_en is null and coalesce(f.fecha, fn_puente_corte()) >= fn_puente_corte() then
    raise exception using errcode = 'MX008', message = format('La factura #%s todavía no está en el libro.', f.num);
  end if;
  v_monto := fn_puente_monto(p_monto, 'El monto del anticipo que se aplica');
  v_fecha := coalesce(p_fecha, fn_fecha_miami(now()));
  if v_fecha < c.fecha or v_fecha < fn_puente_corte() then
    raise exception using errcode = 'MX002', message = 'Un anticipo se aplica después de cobrarlo.';
  end if;
  if v_fecha < f.fecha then
    raise exception using errcode = 'MX002',
      message = format('Un anticipo se aplica a la factura #%s cuando ya existe: el %s o después (llegó %s).', f.num, f.fecha, v_fecha);
  end if;
  -- Lo disponible: lo que el anticipo de este cobro tiene a favor, en la
  -- obra de la factura.
  select -coalesce(sum(l.monto), 0) into v_disp
    from asiento_lineas l
   where l.cuenta = v_cxc and l.partida_tabla = 'cobros' and l.partida_id = c.id::text and l.proyecto_id = f.proyecto_id;
  if v_monto > v_disp then
    raise exception using errcode = 'MX008',
      message = format('El anticipo de ese cobro tiene disponibles %s en la obra %s; no alcanza para %s.', v_disp, f.proyecto_id, v_monto);
  end if;
  v_saldo := fn_puente_saldo(v_cxc, 'facturas', f.id::text);
  if v_monto > v_saldo then
    raise exception using errcode = 'MX008', message = format('La factura #%s tiene abiertos %s: no cabe %s.', f.num, v_saldo, v_monto);
  end if;
  insert into aplicaciones_cobro (cobro_id, factura_id, proyecto_id, monto, desde_anticipo, fecha, creado_por)
  values (c.id, f.id, f.proyecto_id, v_monto, true, v_fecha, auth.uid())
  returning id into v_id;
  v_res := fn_puente_aplicacion(v_id, 'aplicar');
  return jsonb_build_object('aplicacion', v_id, 'asiento', v_res->>'asiento', 'fecha_contable', v_res->>'fecha_contable');
end $$;
revoke execute on function public.fn_anticipo_aplicar(uuid, bigint, text, date) from public, anon, authenticated, service_role;
grant  execute on function public.fn_anticipo_aplicar(uuid, bigint, text, date) to authenticated;

-- ANULAR UNA FACTURA EMITIDA: con su NOTA DE CRÉDITO (número propio, sin
-- huecos, por año: NC-2026-0001), que salda la factura como está hoy (lo
-- que su partida debe en 1110 y 1120, y el espejo de su ingreso), en su
-- fecha. La factura se queda (emitida, luego anulada): una emitida no se
-- borra. Una partida movida a mano contra otra cuenta (un castigo), o una
-- cuenta de la factura ya inactiva, se dicen antes (MX008, MX004). Si NUNCA había entrado al libro (estaba en la bandeja), solo se
-- marca anulada; si estuvo y su asiento se reversó, primero se repone. No
-- con cobros vivos aplicados (primero se anulan), ni una de antes del
-- corte (su saldo viene de la apertura: se corrige con un asiento a mano
-- contra su partida). Toma la fila de la factura: un cobro a la vez espera.
create or replace function public.fn_factura_anular(p_factura bigint, p_motivo text, p_fecha date default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  f        facturas;
  v_vivo   asientos;
  v_fecha  date;
  v_cobros numeric;
  v_lin    jsonb;
  v_serie  text;
  v_n      bigint;
  v_numero text;
  v_nc     uuid;
  v_res    jsonb;
begin
  perform fn_puente_exigir_dueno();
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Anular una factura dice por qué (motivo).';
  end if;
  perform 1 from periodos for share;
  select * into f from facturas where id = p_factura for update;
  if not found then
    raise exception using errcode = '22023', message = format('No existe la factura %s.', p_factura);
  end if;
  if f.estado = 'anulada' then
    raise exception using errcode = 'MX008',
      message = format('La factura #%s ya estaba anulada%s.', f.num,
                       coalesce(' (' || (select n.numero from notas_credito n where n.anula_a = f.id) || ')', ''));
  end if;
  if f.estado = 'borrador' then
    raise exception using errcode = 'MX008',
      message = format('La factura #%s está en borrador: todavía no se emitió, no se anula (se corrige o se borra).', f.num);
  end if;
  if f.fecha < fn_puente_corte() then
    raise exception using errcode = 'MX008',
      message = format('La factura #%s es de antes del corte: su saldo viene de QuickBooks en la apertura. Se corrige con un '
                       'asiento a mano (fn_postear) contra su partida.', f.num);
  end if;
  -- Con cobros vivos, no: primero se anulan (sea cual sea el estado de su
  -- asiento; un cobro huérfano sobre una factura anulada no lo vería nadie).
  select -coalesce(sum(l.monto), 0) into v_cobros
    from asiento_lineas l
    join asientos a on a.id = l.asiento_id
   where l.partida_tabla = 'facturas' and l.partida_id = f.id::text
     and a.origen_tabla in ('cobros', 'aplicaciones_cobro');
  if v_cobros <> 0 then
    raise exception using errcode = 'MX008',
      message = format('La factura #%s tiene cobros aplicados por %s: anula antes esos cobros (fn_cobro_anular). Una nota por '
                       'el saldo (parcial) es de la facturación de f10.', f.num, v_cobros);
  end if;
  v_vivo := fn_puente_vivo('facturas', f.id::text);
  if v_vivo.id is null then
    -- Sin asiento vivo. Si NUNCA entró al libro (estaba en la bandeja), solo
    -- se marca: su puente la deja en no_aplica. Pero si estuvo (su asiento
    -- se reversó y el puente todavía no lo repuso), anularla sin nota de
    -- crédito dejaría un número emitido anulado sin su nota: primero se
    -- repone su asiento y después se anula con su nota.
    if fn_puente_en_libro('facturas', f.id::text) is not null then
      raise exception using errcode = 'MX008',
        message = format('La factura #%s estuvo en el libro (%s) y hoy no tiene asiento vivo: primero repón su asiento (select '
                         'fn_puentes_correr();) y después anúlala con su nota de crédito.', f.num,
                         fn_puente_en_libro('facturas', f.id::text));
    end if;
    perform set_config('mx_puente.escribe', 'facturas_anular:' || f.id, true);
    update facturas set estado = 'anulada' where id = f.id;
    perform set_config('mx_puente.escribe', '', true);
    perform fn_puente_factura(f.id, 'anular');
    return jsonb_build_object('factura', f.id, 'anulada', true, 'nota_credito', null,
                              'nota', 'No había entrado al libro: queda anulada sin asiento.',
                              'aviso_app', 'La app todavía la enseña «por cobrar» (no conoce el estado anulada; parche de f05).');
  end if;
  v_fecha := coalesce(p_fecha, fn_fecha_miami(now()));
  if v_fecha < f.fecha then
    raise exception using errcode = 'MX002', message = format('La nota de crédito no va antes que su factura (%s).', f.fecha);
  end if;
  -- La nota salda la factura COMO ESTÁ HOY (fn_puente_nota_lineas): lo que
  -- su partida debe en 1110 y en 1120 (también después de reclasificar su
  -- retención) y el espejo de su ingreso. Dos cosas se miran antes de
  -- escribir nada:
  --   · otro asiento que movió la partida contra OTRA cuenta (un castigo a
  --     incobrables, un ajuste a mano contra el ingreso): la nota lo dejaría
  --     colgado (el gasto del castigo se quedaría y la partida en negativo).
  --     Primero se reversa ese asiento;
  --   · una cuenta de la nota que ya está inactiva (el ingreso de 2026 se
  --     inactivó al cerrar el año): el libro la rechazaría con MX004 a media
  --     anulación. Se dice aquí, en claro, con qué hacer.
  v_lin := fn_puente_nota_lineas(f.id, 'Nota de crédito');
  if not coalesce((v_lin->>'cuadra')::boolean, false) then
    raise exception using errcode = 'MX008',
      message = format('La partida de la factura #%s tiene asientos que no son ni ella ni sus cobros: %s. Un castigo a incobrables o '
                       'un ajuste a mano contra otra cuenta: la nota de crédito saldaría la partida y dejaría ese asiento colgado. '
                       'Revérsalo antes (fn_reversar) y anula después.', f.num, coalesce(v_lin->>'ajenos', '(sin identificar)'));
  end if;
  if v_lin->>'inactivas' is not null then
    raise exception using errcode = 'MX004',
      message = format('La nota de crédito de la factura #%s va a las cuentas de su factura, y %s ya está inactiva (no recibe asientos). '
                       'Para anularla, reactívala (update cuentas set activa = true where codigo in (%s);): lo que deje la nota se '
                       'queda en ella hasta que se traslade o se cierre su año, y entonces se puede volver a inactivar.',
                       f.num, v_lin->>'inactivas', v_lin->>'inactivas_sql');
  end if;
  -- Su número: la serie del año, sin huecos (la guarda de contadores de c2
  -- solo deja avanzar de uno en uno).
  v_serie := 'notas_credito-' || extract(year from v_fecha)::int;
  insert into contadores (serie, ultimo) values (v_serie, 0) on conflict (serie) do nothing;
  select c.ultimo + 1 into v_n from contadores c where c.serie = v_serie for update;
  update contadores set ultimo = v_n where serie = v_serie;
  v_numero := format('NC-%s-%s', extract(year from v_fecha)::int, lpad(v_n::text, 4, '0'));
  insert into notas_credito (numero, anula_a, fecha, monto, motivo, creado_por)
  values (v_numero, f.id, v_fecha, round(f.monto, 2), btrim(p_motivo), auth.uid())
  returning id into v_nc;
  perform set_config('mx_puente.escribe', 'facturas_anular:' || f.id, true);
  update facturas set estado = 'anulada' where id = f.id;
  perform set_config('mx_puente.escribe', '', true);
  v_res := fn_puente_nota(v_nc, 'anular');
  if v_res->>'accion' not in ('posteado', 'sustituido') then
    raise exception using errcode = 'MX008', message = format('La nota de crédito no se pudo contabilizar: %s', v_res->>'motivo');
  end if;
  return jsonb_build_object('factura', f.id, 'anulada', true, 'nota_credito', v_numero, 'asiento', v_res->>'asiento',
                            'fecha_contable', v_res->>'fecha_contable',
                            'aviso_app', 'La app todavía la enseña «por cobrar» (no conoce el estado anulada; parche de f05). '
                                         'Ya no se deja marcar cobrada.');
end $$;
revoke execute on function public.fn_factura_anular(bigint, text, date) from public, anon, authenticated, service_role;
grant  execute on function public.fn_factura_anular(bigint, text, date) to authenticated;

-- EL DEVENGO ESTÁNDAR DE HORAS (opcional, al cierre de un mes): Dr 5000 por
-- obra / Cr 2210, por las horas APROBADAS del mes × costos_equipo.costo_hora.
-- Etiquetado ESTÁNDAR en todas partes: no es la nómina real (esa es del
-- journal del proveedor, f11, la única fuente de dólares de 5000). Es
-- reversible: el libro lo deshace solo el día 1 del mes siguiente. Uno por
-- mes (su «papel» es horas_devengo AAAA-MM).
--   · Las horas de Edgar NO entran: es el oficial de la S-corp y cobra su
--     salario por la nómina; su parte de obra es 5001, del journal (f11),
--     nunca un sueldo devengado por horas × tarifa. Se cuentan aparte
--     (fuera: oficial).
--   · Su firma lleva cada hora aprobada con su obra, su CO y su fase: si
--     unas horas cambian de obra (y se vuelven a aprobar), el devengo
--     cambia; si no cambió nada, volver a llamarlo no hace nada.
--   · Si cambió, dentro del mes, lo corrige (reverso en su fecha, que anula
--     también su reverso del día 1, y el devengo nuevo). Si ya no queda
--     ninguna hora aprobada, lo deshace. Con el mes cerrado, ya no: ya se
--     deshizo solo.
--   · Solo lo trabajado y TODAVÍA NO PAGADO. El journal de nómina del
--     proveedor (origen nomina…, f11) es la única fuente de dólares de 5000
--     y ya pagó sus horas: devengarlas otra vez contaba dos veces la mano de
--     obra del mes (y dejaba en 2210 sueldos «por pagar» ya pagados; en
--     diciembre, pasaba costo de un año al otro). El corte bueno es el
--     «pagado hasta» de cada corrida, que trae f11. Hasta entonces, un mes
--     que ya tiene journal de nómina NO se devenga (MX008), y si el journal
--     llega después del devengo, volver a devengar lo deshace. El corte (el
--     journal del mes, o que no hay) va en la firma y en la procedencia.
-- El control devengo de fn_puentes_verificar compara cada devengo vivo con
-- las horas aprobadas de hoy, y lo marca si convive con un journal del mes.
create or replace function public.fn_puente_devengo_plan(p_mes text)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_per     periodos;
  v_debe    text := fn_puente_cuenta_de('mano_obra');
  v_haber   text := fn_puente_cuenta_de('sueldos_devengados');
  v_lineas  jsonb;
  v_total   numeric;
  v_detalle jsonb;
  v_fuera   jsonb;
  v_firma   text;
  v_nomina  jsonb;
  v_nom_txt text;
begin
  select * into v_per from periodos where periodo = p_mes and tipo = 'mes';
  if not found then
    return null;
  end if;
  -- El journal de nómina del mes (f11): sus asientos vivos, fechados en el
  -- mes. Lo que pagó ya está en 5000.
  select jsonb_agg(a.numero order by a.cadena_pos), string_agg(a.numero, ', ' order by a.cadena_pos)
    into v_nomina, v_nom_txt
    from asientos a
   where coalesce(a.origen_tabla, '') like 'nomina%'
     and a.fecha_contable between v_per.desde and v_per.hasta
     and a.camino not in ('reverso', 'reverso_automatico')
     and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso');
  -- Lo que entra: horas aprobadas del mes, con obra y con costo por hora, de
  -- quien no es el dueño.
  with h as (
    select h.id, h.proyecto_id, nullif(btrim(h.co), '') as co, h.horas, ce.costo_hora
      from horas h
      join costos_equipo ce on ce.usuario_id = h.usuario_id
     where h.fecha between v_per.desde and v_per.hasta and h.aprobado_el is not null and h.proyecto_id is not null
       and not exists (select 1 from perfiles p where p.id = h.usuario_id and p.rol = 'dueno')
  ), g as (
    select h.proyecto_id, h.co, sum(h.horas) as horas, round(sum(h.horas * h.costo_hora), 2) as monto
      from h group by h.proyecto_id, h.co
  )
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'cuenta', v_debe, 'monto', g.monto::text, 'proyecto_id', g.proyecto_id, 'co', g.co,
           'memo', format('ESTÁNDAR: %s h aprobadas × costo_hora', trim_scale(g.horas)))) order by g.proyecto_id, g.co)
           filter (where g.monto <> 0), '[]'::jsonb),
         coalesce(sum(g.monto), 0)
    into v_lineas, v_total
    from g;
  select jsonb_agg(jsonb_build_object('horas_id', h.id, 'horas', h.horas, 'costo_hora', ce.costo_hora,
                                      'proyecto_id', h.proyecto_id, 'co', nullif(btrim(h.co), ''), 'fase', h.fase)
                   order by h.id)
    into v_detalle
    from horas h join costos_equipo ce on ce.usuario_id = h.usuario_id
   where h.fecha between v_per.desde and v_per.hasta and h.aprobado_el is not null and h.proyecto_id is not null
     and not exists (select 1 from perfiles p where p.id = h.usuario_id and p.rol = 'dueno');
  select jsonb_build_object(
           'sin_aprobar', count(*) filter (where h.aprobado_el is null),
           'sin_obra',    count(*) filter (where h.aprobado_el is not null and h.proyecto_id is null),
           'oficial',     count(*) filter (where h.aprobado_el is not null and h.proyecto_id is not null
                                             and exists (select 1 from perfiles p where p.id = h.usuario_id and p.rol = 'dueno')),
           'sin_costo',   count(*) filter (where h.aprobado_el is not null and h.proyecto_id is not null
                                             and not exists (select 1 from perfiles p where p.id = h.usuario_id and p.rol = 'dueno')
                                             and not exists (select 1 from costos_equipo ce where ce.usuario_id = h.usuario_id)))
    into v_fuera
    from horas h
   where h.fecha between v_per.desde and v_per.hasta;
  v_firma := md5(coalesce(v_detalle, '[]'::jsonb)::text);
  if v_nomina is not null then
    -- Con journal de nómina en el mes: no se devenga (ver arriba). Su firma
    -- lleva el journal: un devengo que ya estaba deja de ser «el de hoy».
    v_firma := md5(jsonb_build_object('horas', coalesce(v_detalle, '[]'::jsonb), 'nomina', v_nomina)::text);
    return jsonb_build_object(
      'accion', 'no_aplica', 'codigo', 'nomina_en_el_mes', 'firma', v_firma, 'total', 0, 'fuera', v_fuera, 'nomina', v_nomina,
      'documento', jsonb_build_object('mes', p_mes, 'horas', coalesce(v_detalle, '[]'::jsonb), 'nomina', v_nomina),
      'motivo', format('El mes %s ya tiene journal de nómina (%s): ya pagó parte de estas horas, y el devengo estándar las contaría '
                       'dos veces (en 5000 por el journal y otra vez por el devengo, con un 2210 que ya se pagó). El devengo de '
                       'cierre es solo lo trabajado y todavía no pagado; ese corte (el «pagado hasta» de cada corrida) lo trae f11. '
                       'Hasta entonces, un mes con nómina no se devenga.', p_mes, v_nom_txt));
  end if;
  if v_total = 0 then
    return jsonb_build_object(
      'accion', 'no_aplica', 'codigo', 'sin_horas', 'firma', v_firma, 'total', 0, 'fuera', v_fuera,
      'documento', jsonb_build_object('mes', p_mes, 'horas', coalesce(v_detalle, '[]'::jsonb)),
      'motivo', format('No hay horas aprobadas con obra y con costo en %s (fuera: %s): no hay nada que devengar.', p_mes, v_fuera));
  end if;
  return jsonb_build_object(
    'accion', 'postear', 'firma', v_firma, 'fecha_documento', v_per.hasta, 'total', v_total, 'fuera', v_fuera,
    'documento', jsonb_build_object('mes', p_mes, 'horas', v_detalle),
    'asiento', jsonb_build_object(
      'descripcion', format('Devengo ESTÁNDAR de mano de obra de %s (horas aprobadas × costo por hora; se reversa solo el día 1). '
                            'No es la nómina real: esa es del journal del proveedor.', p_mes),
      'reversible', true,
      'lineas', v_lineas || jsonb_build_array(jsonb_build_object('cuenta', v_haber, 'monto', (-v_total)::text,
                                                                  'memo', 'ESTÁNDAR: sueldos devengados del mes')),
      'origen_tabla', 'horas_devengo', 'origen_id', p_mes,
      'procedencia', jsonb_build_object('funcion', 'fn_horas_devengar', 'etiqueta', 'estándar',
                                        'regla', 'horas aprobadas × costos_equipo.costo_hora, por obra y CO; sin las del dueño '
                                                 '(oficial: su parte de obra es del journal, 5001)',
                                        'corte_nomina', 'sin journal de nómina en el mes al devengar: todas sus horas aprobadas '
                                                        'están sin pagar (f11 traerá el «pagado hasta» de cada corrida)',
                                        'fuera', v_fuera)));
end $$;
revoke execute on function public.fn_puente_devengo_plan(text) from public, anon, authenticated, service_role;

create or replace function public.fn_horas_devengar(p_mes text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_per   periodos;
  v_debe  text := fn_puente_cuenta_de('mano_obra');
  v_haber text := fn_puente_cuenta_de('sueldos_devengados');
  v_plan  jsonb;
  v_res   jsonb;
begin
  perform fn_puente_exigir_dueno();
  select * into v_per from periodos where periodo = p_mes and tipo = 'mes';
  if not found then
    raise exception using errcode = 'MX002', message = format('No existe el mes «%s» (AAAA-MM).', coalesce(p_mes, ''));
  end if;
  if v_per.estado <> 'abierto' then
    raise exception using errcode = 'MX002',
      message = format('El mes %s ya está cerrado: su devengo, si lo hubo, ya se deshizo solo el día 1.', p_mes);
  end if;
  if coalesce(fn_puente_cuenta_mal(v_debe), fn_puente_cuenta_mal(v_haber)) is not null then
    raise exception using errcode = 'MX004',
      message = format('Las cuentas del devengo: %s.', coalesce(fn_puente_cuenta_mal(v_debe), fn_puente_cuenta_mal(v_haber)));
  end if;
  perform 1 from periodos for share;
  v_plan := fn_puente_devengo_plan(p_mes);
  -- Sin horas que devengar: si no había devengo, no hay nada que hacer; si
  -- lo había (se retiraron las aprobaciones), se deshace.
  if v_plan->>'accion' <> 'postear' and (fn_puente_vivo('horas_devengo', p_mes)).id is null then
    raise exception using errcode = 'MX008', message = v_plan->>'motivo';
  end if;
  v_res := fn_puente_aplicar('horas_devengo', p_mes, v_plan, 'devengar');
  return v_res || jsonb_build_object('total', v_plan->'total', 'fuera', v_plan->'fuera');
end $$;
revoke execute on function public.fn_horas_devengar(text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_horas_devengar(text) to authenticated;


-- ---------------------------------------------------------------------
-- B.8 · El doble toque sin señal (recibos.llave_cliente, única): el mismo
-- recibo mandado dos veces entra una (la segunda, 409 = «ya estaba»). Nula
-- = sin llave (lo de antes de este parche, y lo que suba la versión de la
-- app que aún no la manda).
-- ---------------------------------------------------------------------
create unique index if not exists recibos_llave_cliente_unica on public.recibos (llave_cliente);
-- Y lo mismo en los cobros (fn_cobro_registrar devuelve el que ya estaba).
create unique index if not exists cobros_llave_cliente_unica on public.cobros (llave_cliente) where llave_cliente is not null;
-- Una foto, un recibo. La ruta ES el papel que lee la lectura: dos recibos
-- con la misma foto serían el mismo ticket dos veces en el libro (la guarda
-- ya lo rechaza; el índice lo cierra también para quien no pasa por ella).
-- Solo si hoy no hay rutas repetidas: si las hay, el pegado sigue, esos
-- recibos esperan en la bandeja como duplicados y el control duplicados los
-- enseña; cuando se anulen, el siguiente pegado crea el índice.
do $$
begin
  if to_regclass('public.recibos_ruta_unica') is null then
    if exists (select 1 from public.recibos
                where nullif(btrim(ruta), '') is not null
                group by btrim(ruta) having count(*) > 1) then
      raise notice 'c3-puentes: hay recibos que comparten foto (ruta): no se crea recibos_ruta_unica. El control duplicados los enseña.';
    else
      create unique index recibos_ruta_unica on public.recibos (btrim(ruta)) where nullif(btrim(ruta), '') is not null;
    end if;
  end if;
end $$;


-- ---------------------------------------------------------------------
-- B.9 · El papel no se borra ni se mueve en Storage (f03): en el almacén
-- «fotos», la foto de cada recibo (recibos/…) y los documentos del dueño
-- (docs/…) no se borran, no se mueven y no se reemplazan por la API, ni
-- siquiera el dueño: son el respaldo de los asientos.
-- Es una policy RESTRICTIVA: se suma («y») a las que ya existan, sin
-- tocarlas ni tener que saber cómo se llaman, y lo demás del almacén se
-- borra como hoy. La app no borra archivos (solo sube y firma enlaces): no
-- le cambia nada. Solo si existe Storage (en el banco de pruebas, solo con
-- su simulacro). Si la base no deja crear la policy, el pegado sigue y el
-- verificador lo dice (control papel).
-- ---------------------------------------------------------------------
-- Y tampoco se mueve ni se reemplaza: un update del nombre (mover a otra
-- carpeta) o del contenido (subir encima) sacaría el papel de recibos/ o de
-- docs/ y después se borraría por la API, o cambiaría la foto que respalda
-- un asiento ya sellado. La segunda policy, también restrictiva, cierra el
-- UPDATE con el mismo predicado en using (lo que era) y en with check (lo
-- que queda): nada entra ni sale de esas carpetas por update. La app sube
-- con POST sin upsert (un insert, con nombre único): no le cambia nada.
do $$
begin
  if to_regclass('storage.objects') is not null then
    begin
      drop policy if exists "el papel no se borra" on storage.objects;
      create policy "el papel no se borra" on storage.objects
        as restrictive
        for delete
        to anon, authenticated
        using (bucket_id is distinct from 'fotos' or (name not like 'recibos/%' and name not like 'docs/%'));
      drop policy if exists "el papel no se mueve" on storage.objects;
      create policy "el papel no se mueve" on storage.objects
        as restrictive
        for update
        to anon, authenticated
        using (bucket_id is distinct from 'fotos' or (name not like 'recibos/%' and name not like 'docs/%'))
        with check (bucket_id is distinct from 'fotos' or (name not like 'recibos/%' and name not like 'docs/%'));
    exception when insufficient_privilege then
      raise notice 'c3-puentes: no se pudo crear la policy de Storage que protege el papel (%): el verificador lo dirá.', sqlerrm;
    end;
  end if;
end $$;


-- ---------------------------------------------------------------------
-- B.10 · Anular un recibo o un trabajo externo desde Contabilidad (o desde
-- el SQL Editor mientras no esté conta.js), con el motivo escrito. El
-- puente corre en el acto, con ese motivo, y su trigger diferido ya no
-- encuentra nada que hacer al confirmar.
--   · Recibo: su estado pasa a 'anulado' (el que ya usa la app: el trigger
--     de materiales los devuelve a «falta», y sale de «📥 Por completar»).
--     Ponerle el total en 0 con ✎ también lo saca del libro, pero la app lo
--     sigue enseñando. Un anulado no vuelve con un ✎ (la guarda lo deja
--     anulado): se des-anula a propósito con fn_recibo_desanular.
--   · Si su asiento vivo usa una cuenta ya retirada (inactiva), no se anula
--     (MX008): el reverso dejaría ahí un saldo que nadie podría mover.
--   · Trabajo externo: su costo pasa a 0 (así la app deja de sumarlo en el
--     margen de la obra, como cuando se borraba). El papel se queda: es el
--     rastro.
-- ---------------------------------------------------------------------
create or replace function public.fn_recibo_anular(p_id bigint, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_vivo  uuid;
  v_res   jsonb;
  v_inact text;
begin
  perform fn_puente_exigir_dueno();
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Anular un recibo dice por qué (motivo).';
  end if;
  if not exists (select 1 from recibos where id = p_id) then
    raise exception using errcode = '22023', message = format('No existe el recibo %s.', p_id);
  end if;
  perform 1 from periodos for share;
  perform 1 from recibos where id = p_id for update;
  v_vivo := (fn_puente_vivo('recibos', p_id::text)).id;
  -- Su asiento sobre una cuenta ya retirada (inactiva): el reverso dejaría
  -- ahí un saldo que nadie podría mover (c1). Se dice antes de tocar nada.
  v_inact := case when v_vivo is not null then fn_puente_cuentas_inactivas(v_vivo) end;
  if v_inact is not null then
    raise exception using errcode = 'MX008',
      message = format('El asiento del recibo %s (%s) usa %s, que ya está inactiva: anularlo la reversaría y dejaría ahí un saldo '
                       'que nadie podría mover. Reactívala (update cuentas set activa = true where codigo in (%s);) y anula otra '
                       'vez: el saldo que quede se ve en la cuenta y se decide con el CPA a dónde va (un reembolso por cobrar, un '
                       'ajuste). O reclasifica a mano.', p_id, (select a.numero from asientos a where a.id = v_vivo), v_inact,
                       (select string_agg(distinct quote_literal(c.codigo), ', ') from asiento_lineas l join cuentas c on c.codigo = l.cuenta
                         where l.asiento_id = v_vivo and not c.activa));
  end if;
  -- El motivo va en la sesión mientras dura el cambio: lo lee el puente,
  -- corra ahora o al confirmar.
  perform set_config('mx_puente.motivo', btrim(p_motivo), true);
  update recibos set estado = 'anulado' where id = p_id and estado is distinct from 'anulado';
  v_res := fn_puente_recibo(p_id, 'anular', false, btrim(p_motivo));
  perform set_config('mx_puente.motivo', '', true);
  return jsonb_strip_nulls(jsonb_build_object(
    'recibo', p_id, 'anulado', true,
    'reverso', (select r.numero from asientos r where r.reversa_a = v_vivo and r.camino = 'reverso'),
    'estado', (select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = p_id::text)));
end $$;
revoke execute on function public.fn_recibo_anular(bigint, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_recibo_anular(bigint, text) to authenticated;

create or replace function public.fn_externo_anular(p_id bigint, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_vivo  uuid;
  v_res   jsonb;
  v_inact text;
begin
  perform fn_puente_exigir_dueno();
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Anular un trabajo externo dice por qué (motivo).';
  end if;
  if not exists (select 1 from trabajos_externos where id = p_id) then
    raise exception using errcode = '22023', message = format('No existe el trabajo externo %s.', p_id);
  end if;
  perform 1 from periodos for share;
  perform 1 from trabajos_externos where id = p_id for update;
  v_vivo := (fn_puente_vivo('trabajos_externos', p_id::text)).id;
  v_inact := case when v_vivo is not null then fn_puente_cuentas_inactivas(v_vivo) end;
  if v_inact is not null then
    raise exception using errcode = 'MX008',
      message = format('El asiento del trabajo externo %s (%s) usa %s, que ya está inactiva: anularlo la reversaría y dejaría ahí '
                       'un saldo que nadie podría mover. Reactívala (update cuentas set activa = true where codigo in (%s);) y '
                       'anula otra vez; o reclasifica a mano.', p_id, (select a.numero from asientos a where a.id = v_vivo), v_inact,
                       (select string_agg(distinct quote_literal(c.codigo), ', ') from asiento_lineas l join cuentas c on c.codigo = l.cuenta
                         where l.asiento_id = v_vivo and not c.activa));
  end if;
  perform set_config('mx_puente.motivo', btrim(p_motivo), true);
  update trabajos_externos set costo = 0 where id = p_id and costo <> 0;
  v_res := fn_puente_externo(p_id, 'anular', false, btrim(p_motivo));
  perform set_config('mx_puente.motivo', '', true);
  return jsonb_strip_nulls(jsonb_build_object(
    'trabajo_externo', p_id, 'anulado', true,
    'reverso', (select r.numero from asientos r where r.reversa_a = v_vivo and r.camino = 'reverso'),
    'estado', (select d.estado from puente_documentos d where d.tabla = 'trabajos_externos' and d.documento_id = p_id::text)));
end $$;
revoke execute on function public.fn_externo_anular(bigint, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_externo_anular(bigint, text) to authenticated;

-- DES-ANULAR UN RECIBO, a propósito y con su motivo (anulado por error). Es
-- la única puerta: el ✎ de la app manda estado = 'leido' cada vez que lleva
-- total, y la guarda deja anulado lo que estaba anulado. Vuelve a 'leido'
-- si tiene total (a 'por_leer' si no, o a 'sin_foto' si tampoco tiene
-- foto), el puente corre en el acto, y el asiento nuevo dice que sustituye
-- al que se reversó al anularlo, qué cambió y el motivo de Edgar. Si es un
-- repetido de otro, el puente lo dice (duplicado) y no entra.
create or replace function public.fn_recibo_desanular(p_id bigint, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r      recibos;
  v_est  text;
  v_res  jsonb;
begin
  perform fn_puente_exigir_dueno();
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023', message = 'Des-anular un recibo dice por qué (motivo).';
  end if;
  perform 1 from periodos for share;
  select * into r from recibos where id = p_id for update;
  if not found then
    raise exception using errcode = '22023', message = format('No existe el recibo %s.', p_id);
  end if;
  if r.estado is distinct from 'anulado' then
    raise exception using errcode = 'MX008',
      message = format('El recibo %s no está anulado (está «%s»): no hay nada que des-anular.', p_id, coalesce(r.estado, 'por_leer'));
  end if;
  v_est := case when r.total is not null then 'leido'
                when nullif(btrim(r.ruta), '') is null then 'sin_foto'
                else 'por_leer' end;
  -- La marca deja pasar el cambio de estado por la guarda; el motivo lo
  -- lee el puente (corra ahora o al confirmar).
  perform set_config('mx_puente.motivo', btrim(p_motivo), true);
  perform set_config('mx_puente.escribe', 'recibos_desanular:' || p_id, true);
  update recibos set estado = v_est where id = p_id;
  perform set_config('mx_puente.escribe', '', true);
  v_res := fn_puente_recibo(p_id, 'desanular', false, btrim(p_motivo));
  perform set_config('mx_puente.motivo', '', true);
  return jsonb_strip_nulls(jsonb_build_object(
    'recibo', p_id, 'desanulado', true, 'estado', v_est, 'puente', v_res->>'accion', 'asiento', v_res->>'asiento',
    'codigo', v_res->>'codigo', 'motivo', v_res->>'motivo'));
end $$;
revoke execute on function public.fn_recibo_desanular(bigint, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_recibo_desanular(bigint, text) to authenticated;


-- CONFIRMAR LO QUE EL PUENTE PREGUNTA DE UN PAPEL. Un recibo o un trabajo
-- externo que no cuadra espera en la bandeja con su pregunta (cabecera,
-- punto 15): o el papel está mal (se corrige, y el puente lo contabiliza), o
-- está bien así. Esto es lo segundo: Edgar lo confirma, con el motivo; queda
-- escrito (puente_revisados) y el puente sigue. La confirmación vale para
-- ESE dato (la fecha, la foto o el ticket, los tres números, el total): si
-- el papel cambia ese dato, se vuelve a preguntar. Solo si el papel está
-- esperando justo por eso.
--   fecha_antes_del_corte     de verdad es de antes del corte (está en
--                             QuickBooks): pasa a no_aplica
--   fecha_posterior_a_subida  la fecha leída es la buena
--   duplicado                 no es el mismo gasto que el otro recibo
--   impuesto                  el total es lo que se pagó
--   devolucion                es una compra (el total positivo es el bueno)
create or replace function public.fn_puente_confirmar(p_tabla text, p_id bigint, p_codigo text, p_motivo text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_plan jsonb;
  v_res  jsonb;
  v_dato text;
begin
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception using errcode = '22023',
      message = 'Confirmarlo dice por qué (motivo): p. ej. «ticket de septiembre, ya está en QuickBooks».';
  end if;
  if p_tabla is null or p_tabla not in ('recibos', 'trabajos_externos') then
    raise exception using errcode = '22023',
      message = format('Se confirman recibos o trabajos_externos (llegó «%s»).', coalesce(p_tabla, ''));
  end if;
  if p_codigo is null or p_codigo not in ('fecha_antes_del_corte', 'fecha_posterior_a_subida', 'duplicado', 'impuesto', 'devolucion')
     or (p_tabla = 'trabajos_externos' and p_codigo <> 'fecha_antes_del_corte') then
    raise exception using errcode = '22023',
      message = format('«%s» no es una pregunta que se confirme en %s (fecha_antes_del_corte, y en recibos también '
                       'fecha_posterior_a_subida, duplicado, impuesto, devolucion).', coalesce(p_codigo, ''), p_tabla);
  end if;
  perform 1 from periodos for share;
  if p_tabla = 'recibos' then
    perform 1 from recibos where id = p_id for update;
    v_plan := fn_puente_recibo_plan(p_id);
  else
    perform 1 from trabajos_externos where id = p_id for update;
    v_plan := fn_puente_externo_plan(p_id);
  end if;
  if v_plan->>'codigo' is distinct from p_codigo then
    raise exception using errcode = 'MX008',
      message = format('%s %s no está esperando por eso (%s): está en «%s». %s', p_tabla, p_id, p_codigo,
                       coalesce(v_plan->>'codigo', v_plan->>'accion'), coalesce(v_plan->>'motivo', ''));
  end if;
  v_dato := coalesce(v_plan->>'dato', to_char((v_plan->'documento'->>'fecha')::date, 'YYYY-MM-DD'));
  insert into puente_revisados (tabla, documento_id, codigo, dato, motivo, revisado_por, revisado_rol)
  values (p_tabla, p_id::text, p_codigo, v_dato, btrim(p_motivo), auth.uid(), fn_rol_llamante())
  on conflict do nothing;
  v_res := case p_tabla when 'recibos' then fn_puente_recibo(p_id, 'confirmar')
                        else fn_puente_externo(p_id, 'confirmar') end;
  return jsonb_strip_nulls(jsonb_build_object('tabla', p_tabla, 'id', p_id, 'confirmado', p_codigo, 'dato', v_dato,
                                              'estado', v_res->>'accion', 'asiento', v_res->>'asiento',
                                              'codigo', v_res->>'codigo', 'motivo', v_res->>'motivo'));
end $$;
revoke execute on function public.fn_puente_confirmar(text, bigint, text, text) from public, anon, authenticated, service_role;

create or replace function public.fn_puentes_confirmar(p_tabla text, p_id bigint, p_codigo text, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform fn_puente_exigir_dueno();
  return fn_puente_confirmar(p_tabla, p_id, p_codigo, p_motivo);
end $$;
revoke execute on function public.fn_puentes_confirmar(text, bigint, text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_puentes_confirmar(text, bigint, text, text) to authenticated;

-- La de antes del corte, con su nombre de siempre (la bandeja lo receta así).
create or replace function public.fn_puentes_antes_del_corte(p_tabla text, p_id bigint, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform fn_puente_exigir_dueno();
  return fn_puente_confirmar(p_tabla, p_id, 'fecha_antes_del_corte', p_motivo);
end $$;
revoke execute on function public.fn_puentes_antes_del_corte(text, bigint, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_puentes_antes_del_corte(text, bigint, text) to authenticated;


-- ---------------------------------------------------------------------
-- B.11 · fn_puentes_verificar() — los controles de los puentes, con la
-- forma de fn_verificar_cadena (control, ok, detalle): la ronda nocturna
-- de f08 los llamará junto con los del libro. SECURITY DEFINER porque
-- tiene que ver todos los papeles y el catálogo; por eso mira primero que
-- quien llama sea el dueño.
--   triggers     las guardas y los puentes de cada papel existen, están
--                habilitados y llaman a su función; y los dos triggers de la
--                app que este archivo rehace (materiales y correcciones de
--                horas) siguen como los dejó (cabecera, punto 13)
--   documentos   cada papel apunta a su asiento vivo (contabilizado_en) y
--                cada asiento vivo de puente tiene su papel; y ningún papel
--                contabilizado cambió por debajo de su puente (su firma de
--                hoy es la de su asiento)
--   sin_evaluar  papeles desde el corte (o subidos desde el corte) que el
--                puente nunca miró (se arregla con fn_puentes_correr())
--   bandeja      cuántos papeles pendientes, en espera, con error y con
--                aviso; en rojo solo si el libro rechazó alguno (error)
--   reglas       cuántas reglas siguen en BORRADOR (no postean), y ninguna
--                confirmada apunta a una cuenta inactiva, de grupo o que
--                no es de su clase (un cobro «al banco» que no es un banco,
--                una cuenta por cobrar que es un gasto, una categoría que
--                carga al banco, a la CxC o a una contra-cuenta, una forma
--                de pago o una tarjeta en la cuenta de otro papel); y cada
--                papel del puente con su propia cuenta
--   use_tax      ninguna línea de un recibo en 2300
--   mano_de_obra ninguna línea de mano de obra directa (5000, 5001) que no
--                venga de la nómina (f11), de un ajuste del CPA, de un
--                reverso o, la 5000, del devengo estándar de
--                fn_horas_devengar (5000 contra 2210; uno a mano marcado
--                «reversible» no lo es): «un asiento de mano de obra solo
--                puede nacer de un journal o de un devengo reversible» (f03). Y su burden (5010-5019), como lo dice
--                c1: el de obra (5010) solo por reparto desde las bolsas
--                (5011, 5015); las bolsas, entre ellas, desde el journal,
--                desde 1410 (la prima de WC) o contra una factura por pagar
--                (2010, 2050: el ajuste de auditoría de WC). Lo que no se
--                impide, se detecta.
--   partidas     ninguna factura en negativo en 1110/1120 (cobrada de más,
--                o su ingreso reversado), ninguna anulada con saldo en
--                ninguna de las dos (por cuenta, no la suma) ni con un
--                cobro vivo, ningún anticipo con saldo deudor, y ningún
--                papel dos veces (en la apertura y por su puente)
--   devengo      cada devengo estándar vivo de un mes abierto es el de las
--                horas aprobadas de hoy, y el mes no tiene journal de
--                nómina (si no, fn_horas_devengar lo pone al día o lo
--                deshace)
--   duplicados   ningún recibo dos veces en el libro: la misma foto, o el
--                mismo ticket (proveedor, número y total), salvo lo que
--                Edgar confirmó
--   cuentas_inactivas  ninguna cuenta inactiva con saldo vivo (c1)
--   vistas       ninguna vista que lea los papeles con los permisos de su
--                dueño (recibos_equipo…) se puede escribir por la API: por
--                ahí se saltaba la RLS
--   papel        en Storage, las policies restrictivas no dejan borrar ni
--                mover (update) recibos/ ni docs/ (sin Storage, en el banco
--                de pruebas, no aplica)
-- ---------------------------------------------------------------------
create or replace function public.fn_puentes_verificar()
returns table (control text, ok boolean, detalle jsonb)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_malos jsonb;
  v_mas   jsonb;
  v_n     jsonb;
  v_corte date := fn_puente_corte();
begin
  perform fn_puente_exigir_dueno();

  -- triggers
  select coalesce(jsonb_agg(jsonb_build_object('tabla', e.tabla, 'trigger', e.nombre,
                                               'estado', coalesce(t.tgenabled::text, 'NO EXISTE'))), '[]'::jsonb)
    into v_malos
    from (values ('recibos',                 'trg_puente_recibos_guarda',                'fn_puente_recibos_guarda'),
                 ('recibos',                 'trg_puente_recibos_despues',               'fn_puente_recibos_despues'),
                 ('facturas',                'trg_puente_facturas_guarda',               'fn_puente_facturas_guarda'),
                 ('facturas',                'trg_puente_facturas_despues',              'fn_puente_facturas_despues'),
                 ('trabajos_externos',       'trg_puente_externos_guarda',               'fn_puente_externos_guarda'),
                 ('trabajos_externos',       'trg_puente_externos_despues',              'fn_puente_externos_despues'),
                 ('horas',                   'trg_puente_horas_guarda',                  'fn_puente_horas_guarda'),
                 ('proyectos',               'trg_puente_proyectos_guarda',              'fn_puente_proyectos_guarda'),
                 ('cobros',                  'trg_puente_cobros_guarda',                 'fn_puente_papeles_guarda'),
                 ('cobros',                  'trg_puente_cobros_sin_truncate',           'fn_puente_papeles_guarda'),
                 ('aplicaciones_cobro',      'trg_puente_aplicaciones_guarda',           'fn_puente_papeles_guarda'),
                 ('aplicaciones_cobro',      'trg_puente_aplicaciones_sin_truncate',     'fn_puente_papeles_guarda'),
                 ('notas_credito',           'trg_puente_notas_credito_guarda',          'fn_puente_papeles_guarda'),
                 ('notas_credito',           'trg_puente_notas_credito_sin_truncate',    'fn_puente_papeles_guarda'),
                 ('puente_reglas_historial', 'trg_puente_reglas_historial_guarda',       'fn_puente_papeles_guarda'),
                 ('puente_reglas_historial', 'trg_puente_reglas_historial_sin_truncate', 'fn_puente_papeles_guarda'),
                 ('horas_aprobaciones',      'trg_puente_horas_aprobaciones_guarda',     'fn_puente_papeles_guarda'),
                 ('horas_aprobaciones',      'trg_puente_horas_aprobaciones_sin_truncate', 'fn_puente_papeles_guarda'),
                 ('puente_revisados',        'trg_puente_revisados_guarda',              'fn_puente_papeles_guarda'),
                 ('puente_revisados',        'trg_puente_revisados_sin_truncate',        'fn_puente_papeles_guarda'),
                 ('mapeo_categoria_recibo',  'trg_puente_mapeo_categoria_guarda',        'fn_puente_reglas_guarda'),
                 ('mapeo_categoria_recibo',  'trg_puente_mapeo_categoria_historial',     'fn_puente_reglas_historial'),
                 ('mapeo_metodo_pago',       'trg_puente_mapeo_metodo_pago_guarda',      'fn_puente_reglas_guarda'),
                 ('mapeo_metodo_pago',       'trg_puente_mapeo_metodo_pago_historial',   'fn_puente_reglas_historial'),
                 ('mapeo_tipo_proyecto',     'trg_puente_mapeo_tipo_proyecto_guarda',    'fn_puente_reglas_guarda'),
                 ('mapeo_tipo_proyecto',     'trg_puente_mapeo_tipo_proyecto_historial', 'fn_puente_reglas_historial'),
                 ('tarjetas',                'trg_puente_tarjetas_guarda',               'fn_puente_reglas_guarda'),
                 ('tarjetas',                'trg_puente_tarjetas_historial',            'fn_puente_reglas_historial'),
                 ('puente_cuentas',          'trg_puente_cuentas_guarda',                'fn_puente_reglas_guarda'),
                 ('puente_cuentas',          'trg_puente_cuentas_historial',             'fn_puente_reglas_historial'),
                 ('proveedores',             'trg_puente_proveedores_guarda',            'fn_puente_reglas_guarda'),
                 ('proveedores',             'trg_puente_proveedores_historial',         'fn_puente_reglas_historial'),
                 ('proveedores',             'trg_puente_proveedores_borrar',            'fn_puente_proveedores_borrar'),
                 ('proveedores_alias',       'trg_puente_proveedores_alias_historial',   'fn_puente_reglas_historial'))
         as e(tabla, nombre, funcion)
    left join pg_trigger t
           on t.tgrelid = to_regclass('public.' || e.tabla) and t.tgname = e.nombre and not t.tgisinternal
   where t.oid is null
      or t.tgenabled not in ('O', 'A')
      or t.tgfoid is distinct from to_regprocedure('public.' || e.funcion || '()')::oid;
  -- Los dos triggers de la app que este archivo rehace, si existen: el de
  -- materiales solo con la obra, las notas y el estado; el de correcciones
  -- de horas, con su condición (no corre cuando solo cambia la aprobación).
  select coalesce(jsonb_agg(s.falla), '[]'::jsonb) into v_mas
    from (select format('recibos.trg_recibo_marca_material corre con cualquier cambio del recibo (%s): la escritura del puente '
                        'volvería a marcar materiales. Vuelve a pegar c3-puentes.sql.', pg_get_triggerdef(t.oid)) as falla
            from pg_trigger t
           where t.tgrelid = 'public.recibos'::regclass and t.tgname = 'trg_recibo_marca_material' and not t.tgisinternal
             and coalesce((select array_agg(a.attname::text order by a.attname) from pg_attribute a
                            where a.attrelid = t.tgrelid and a.attnum = any (t.tgattr)), '{}')
                 is distinct from array['estado', 'notas', 'proyecto_id']
          union all
          select 'horas.trg_guarda_correccion corre también cuando solo cambia la aprobación: aprobar desde el SQL Editor chocaría '
                 'con ella y gastaría el permiso de corrección de un trabajador. Vuelve a pegar c3-puentes.sql.'
            from pg_trigger t
           where t.tgrelid = 'public.horas'::regclass and t.tgname = 'trg_guarda_correccion' and not t.tgisinternal
             and t.tgqual is null) s;
  control := 'triggers';
  ok      := jsonb_array_length(v_malos) = 0 and jsonb_array_length(v_mas) = 0;
  detalle := jsonb_build_object('fallan', v_malos, 'triggers_de_la_app', v_mas);
  return next;

  -- documentos
  with papeles as (
         select 'recibos'::text as tabla, r.id::text as id, r.contabilizado_en from recibos r
         union all select 'facturas', f.id::text, f.contabilizado_en from facturas f
         union all select 'trabajos_externos', x.id::text, x.contabilizado_en from trabajos_externos x
         union all select 'cobros', c.id::text, c.contabilizado_en from cobros c
         union all select 'aplicaciones_cobro', a.id::text, a.contabilizado_en from aplicaciones_cobro a where a.desde_anticipo
         union all select 'notas_credito', n.id::text, n.contabilizado_en from notas_credito n
       ),
       vivos as (
         select a.origen_tabla as tabla, a.origen_id as id, a.id as asiento, a.numero, a.procedencia->>'firma' as firma
           from asientos a
          where a.camino = 'puente'
            and a.origen_tabla in ('recibos', 'facturas', 'trabajos_externos', 'cobros', 'aplicaciones_cobro', 'notas_credito')
            and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
       )
  select coalesce(jsonb_agg(s.falla order by s.falla), '[]'::jsonb) into v_malos
    from (select format('%s %s apunta a %s y su asiento vivo es %s', p.tabla, p.id, coalesce(p.contabilizado_en::text, '(nada)'),
                        coalesce(v.numero, '(ninguno)')) as falla
            from papeles p
            left join vivos v on v.tabla = p.tabla and v.id = p.id
           where p.contabilizado_en is distinct from v.asiento
          union all
          select format('el asiento %s es de %s %s, que ya no existe', v.numero, v.tabla, v.id)
            from vivos v
           where not exists (select 1 from papeles p where p.tabla = v.tabla and p.id = v.id)
          union all
          -- (Si el puente lo retuvo —el papel cambió y hoy no se puede
          -- volver a contabilizar—, lo dice: primero se arregla lo que dice
          -- la bandeja.)
          select case when d.codigo is not null and d.estado = 'contabilizado'
                      then format('%s %s cambió y su asiento %s se quedó como estaba: el papel de hoy no se puede contabilizar (%s). '
                                  'Se arregla lo que dice la bandeja y fn_puentes_correr() lo pone al día', v.tabla, v.id, v.numero,
                                  d.codigo)
                      else format('%s %s cambió por debajo de su puente (su firma de hoy no es la de %s): fn_puentes_correr() lo pone '
                                  'al día', v.tabla, v.id, v.numero) end
            from vivos v
            left join puente_documentos d on d.tabla = v.tabla and d.documento_id = v.id
           where v.tabla in ('recibos', 'trabajos_externos', 'facturas')
             and v.firma is distinct from (case v.tabla
                                             when 'recibos'           then fn_puente_recibo_plan(v.id::bigint)
                                             when 'trabajos_externos' then fn_puente_externo_plan(v.id::bigint)
                                             else fn_puente_factura_plan(v.id::bigint) end)->>'firma'
          limit 50) s;
  control := 'documentos';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('fallan', v_malos);
  return next;

  -- sin_evaluar
  select coalesce(jsonb_agg(s.papel order by s.papel), '[]'::jsonb) into v_malos
    from (select 'recibos ' || r.id as papel from recibos r
           where (coalesce(r.fecha, fn_fecha_miami(r.creado)) >= v_corte or (r.creado at time zone 'America/New_York')::date >= v_corte)
             and not exists (select 1 from puente_documentos d where d.tabla = 'recibos' and d.documento_id = r.id::text)
          union all
          select 'facturas ' || f.id from facturas f
           where (f.fecha is null or f.fecha >= v_corte)
             and not exists (select 1 from puente_documentos d where d.tabla = 'facturas' and d.documento_id = f.id::text)
          union all
          select 'trabajos_externos ' || x.id from trabajos_externos x
           where (coalesce(x.fecha, fn_fecha_miami(x.creado)) >= v_corte or (x.creado at time zone 'America/New_York')::date >= v_corte)
             and not exists (select 1 from puente_documentos d where d.tabla = 'trabajos_externos' and d.documento_id = x.id::text)
          limit 50) s;
  control := 'sin_evaluar';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('papeles', v_malos,
                                'arreglo', case when jsonb_array_length(v_malos) > 0 then 'select fn_puentes_correr();' end);
  return next;

  -- bandeja
  select coalesce(jsonb_object_agg(x.estado, x.n), '{}'::jsonb) into v_n
    from (select case when d.estado = 'contabilizado' and d.codigo is not null then 'aviso' else d.estado end as estado,
                 count(*) as n
            from puente_documentos d
           group by 1) x;
  control := 'bandeja';
  ok      := coalesce((v_n->>'error')::int, 0) = 0;
  detalle := jsonb_build_object('por_estado', v_n,
                                'errores', (select coalesce(jsonb_agg(jsonb_build_object('papel', d.tabla || ' ' || d.documento_id,
                                                                                         'codigo', d.codigo, 'motivo', d.motivo)),
                                                            '[]'::jsonb)
                                              from (select * from puente_documentos where estado = 'error' limit 20) d));
  return next;

  -- reglas
  select coalesce(jsonb_agg(s.falla order by s.falla), '[]'::jsonb) into v_malos
    from (select format('categoría «%s» → %s: %s', m.categoria, m.cuenta, fn_puente_cuenta_gasto_mal(m.cuenta)) as falla
            from mapeo_categoria_recibo m where m.confirmado_el is not null and fn_puente_cuenta_gasto_mal(m.cuenta) is not null
          union all
          select format('categoría «%s», sin obra → %s: %s', m.categoria, m.cuenta_sin_obra,
                        coalesce(fn_puente_cuenta_gasto_mal(m.cuenta_sin_obra), 'exige obra'))
            from mapeo_categoria_recibo m
            left join cuentas c on c.codigo = m.cuenta_sin_obra
           where m.confirmado_el is not null and m.cuenta_sin_obra is not null
             and (fn_puente_cuenta_gasto_mal(m.cuenta_sin_obra) is not null or c.regla_obra = 'obligatoria')
          union all
          select format('forma de pago «%s» → %s: es la cuenta del puente «%s», no de donde sale un pago', m.metodo_pago, m.cuenta, pc.rol)
            from mapeo_metodo_pago m
            join puente_cuentas pc on pc.cuenta = m.cuenta and pc.rol not in ('banco', 'reembolso_dueno', 'reembolso_empleado')
           where m.confirmado_el is not null
          union all
          select format('tarjeta %s → %s: es la cuenta del puente «%s», no la de una tarjeta', t.ultimos4, t.cuenta, pc.rol)
            from tarjetas t
            join puente_cuentas pc on pc.cuenta = t.cuenta and pc.rol not in ('banco', 'reembolso_dueno', 'reembolso_empleado')
           where t.activa
          union all
          select format('la cuenta %s es de dos papeles del puente («%s» y «%s»): cada uno tiene la suya', a.cuenta, a.rol, b.rol)
            from puente_cuentas a
            join puente_cuentas b on b.cuenta = a.cuenta and b.rol > a.rol
          union all
          select format('forma de pago «%s» → %s: %s', m.metodo_pago, m.cuenta, fn_puente_cuenta_mal(m.cuenta))
            from mapeo_metodo_pago m where m.confirmado_el is not null and m.cuenta is not null and fn_puente_cuenta_mal(m.cuenta) is not null
          union all
          select format('tipo de obra «%s» → %s: %s', m.tipo, m.cuenta, fn_puente_cuenta_mal(m.cuenta))
            from mapeo_tipo_proyecto m where m.confirmado_el is not null and fn_puente_cuenta_mal(m.cuenta) is not null
          union all
          select format('forma de pago «%s» (%s) → %s: no es un banco', m.metodo_pago, m.forma, m.cuenta)
            from mapeo_metodo_pago m
            join cuentas c on c.codigo = m.cuenta
           where m.confirmado_el is not null and (m.forma = 'banco' or c.tipo = 'activo') and not fn_puente_es_banco(m.cuenta)
          union all
          select format('tarjeta %s → %s: %s', t.ultimos4, t.cuenta, fn_puente_cuenta_mal(t.cuenta))
            from tarjetas t where t.activa and fn_puente_cuenta_mal(t.cuenta) is not null
          union all
          select format('tarjeta %s → %s: una cuenta de activo que no es un banco', t.ultimos4, t.cuenta)
            from tarjetas t join cuentas c on c.codigo = t.cuenta
           where t.activa and c.tipo = 'activo' and not fn_puente_es_banco(t.cuenta)
          union all
          select format('cuenta del puente «%s» → %s: %s', pc.rol, pc.cuenta, fn_puente_cuenta_rol_mal(pc.rol, pc.cuenta))
            from puente_cuentas pc where fn_puente_cuenta_rol_mal(pc.rol, pc.cuenta) is not null) s;
  control := 'reglas';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object(
    'mal', v_malos,
    'en_borrador', jsonb_build_object(
      'categoria',     (select count(*) from mapeo_categoria_recibo where confirmado_el is null),
      'metodo_pago',   (select count(*) from mapeo_metodo_pago where confirmado_el is null),
      'tipo_proyecto', (select count(*) from mapeo_tipo_proyecto where confirmado_el is null)),
    'nota', 'Una regla en borrador no postea: el papel espera en la bandeja hasta que Edgar la confirma (fn_mapeo_confirmar).');
  return next;

  -- use_tax
  select coalesce(jsonb_agg(a.numero order by a.cadena_pos), '[]'::jsonb) into v_malos
    from asientos a
   where a.origen_tabla = 'recibos'
     and exists (select 1 from asiento_lineas l where l.asiento_id = a.id and l.cuenta = fn_puente_cuenta_de('use_tax'));
  control := 'use_tax';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('asientos_de_recibo_en_use_tax', v_malos);
  return next;

  -- mano_de_obra: la directa (5000, 5001) y su burden (el resto del bloque
  -- 50xx, c1). Un reverso o un ajuste del CPA valen siempre (corrigen).
  --   · directa: del journal (origen nomina…); y 5000, también del devengo
  --     estándar: el de fn_horas_devengar (camino puente, origen
  --     horas_devengo, reversible, solo 5000 contra 2210). Un asiento a
  --     mano marcado «reversible» no es el devengo: 5000 o 5001 pagados del
  --     banco salían en verde. 5001 (la parte de obra del sueldo de Edgar)
  --     solo del journal;
  --   · burden de obra (5010, por obra): solo por reparto desde sus bolsas
  --     (todas las otras líneas del asiento son del bloque 50xx);
  --   · bolsas sin obra (5011, 5015, 5019): entre ellas y con el de obra,
  --     desde el journal, desde 1410 (la prima de WC pagada por
  --     adelantado, c1) o contra una factura por pagar (2010, o 2050
  --     devengado: el ajuste de auditoría de WC). Pagado directo desde el
  --     banco o una tarjeta, no: los impuestos patronales llegan por el
  --     journal, y así no entran dos veces.
  select coalesce(jsonb_agg(distinct a.numero), '[]'::jsonb) into v_malos
    from asiento_lineas l
    join asientos a on a.id = l.asiento_id
    join cuentas c on c.codigo = l.cuenta
   where fn_puente_es_mano_de_obra(l.cuenta)
     and a.camino not in ('reverso', 'reverso_automatico')
     and a.tipo <> 'ajuste_cpa'
     and (   (l.cuenta = fn_puente_cuenta_de('mano_obra_oficial') and coalesce(a.origen_tabla, '') not like 'nomina%')
          or (l.cuenta = fn_puente_cuenta_de('mano_obra') and coalesce(a.origen_tabla, '') not like 'nomina%'
              and not (a.camino = 'puente' and coalesce(a.origen_tabla, '') = 'horas_devengo' and a.reversible
                       and not exists (select 1 from asiento_lineas m
                                        where m.asiento_id = a.id
                                          and m.cuenta not in (fn_puente_cuenta_de('mano_obra'),
                                                               fn_puente_cuenta_de('sueldos_devengados')))))
          or (l.cuenta not in (fn_puente_cuenta_de('mano_obra'), fn_puente_cuenta_de('mano_obra_oficial'))
              and c.regla_obra <> 'prohibida'
              and exists (select 1 from asiento_lineas m where m.asiento_id = a.id and not fn_puente_es_mano_de_obra(m.cuenta)))
          or (l.cuenta not in (fn_puente_cuenta_de('mano_obra'), fn_puente_cuenta_de('mano_obra_oficial'))
              and c.regla_obra = 'prohibida'
              and coalesce(a.origen_tabla, '') not like 'nomina%'
              and exists (select 1 from asiento_lineas m
                           where m.asiento_id = a.id and not fn_puente_es_mano_de_obra(m.cuenta)
                             and m.cuenta not in ('1410', '2050', fn_puente_cuenta_de('cxp')))));
  control := 'mano_de_obra';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('asientos', v_malos,
                                'regla', 'La mano de obra directa solo entra por el journal de nómina (f11) o, la 5000, por el '
                                         'devengo estándar reversible de fn_horas_devengar (5000 contra 2210); 5001, solo por el '
                                         'journal. El burden de obra (5010), solo por reparto '
                                         'desde sus bolsas (5011, 5015); las bolsas, desde el journal, desde 1410 (la prima de '
                                         'WC) o contra una factura por pagar (2010, 2050), nunca pagadas directo del banco.');
  return next;

  -- partidas: lo que el libro debe cumplir por partida, que la partida doble
  -- sola no ve (el libro cuadra igual).
  select coalesce(jsonb_agg(s.falla order by s.falla), '[]'::jsonb) into v_malos
    from (with fac as (
            select l.partida_id, l.cuenta, sum(l.monto) as saldo
              from asiento_lineas l
             where l.partida_tabla = 'facturas'
               and l.cuenta in (fn_puente_cuenta_de('cxc'), fn_puente_cuenta_de('retencion_cxc'))
             group by l.partida_id, l.cuenta)
          select format('la factura #%s tiene %s en %s: en negativo (se cobró de más, o su ingreso se reversó)',
                        coalesce(f.num, fac.partida_id), fac.saldo, fac.cuenta) as falla
            from fac left join facturas f on f.id::text = fac.partida_id
           where fac.saldo < 0
          union all
          -- (Por cuenta, no la suma: una retención reclasificada a 1110 deja
          -- 1110 en negativo y 1120 abierta, y la suma da cero.)
          select format('la factura #%s está anulada y tiene %s en %s', f.num, fac.saldo, fac.cuenta)
            from facturas f
            join fac on fac.partida_id = f.id::text
           where f.estado = 'anulada' and fac.saldo <> 0
          union all
          select format('el cobro %s (vigente, del %s) está aplicado a la factura anulada #%s', c.id, c.fecha, f.num)
            from aplicaciones_cobro ap
            join cobros c on c.id = ap.cobro_id
            join facturas f on f.id = ap.factura_id
           where c.estado = 'vigente' and f.estado = 'anulada'
          union all
          select format('el anticipo del cobro %s tiene %s en %s: saldo deudor (se aplicó más de lo que dejó)',
                        l.partida_id, sum(l.monto), l.cuenta)
            from asiento_lineas l
           where l.partida_tabla = 'cobros'
             and l.cuenta in (fn_puente_cuenta_de('cxc'), fn_puente_cuenta_de('retencion_cxc'))
           group by l.partida_id, l.cuenta
          having sum(l.monto) > 0
          union all
          select format('%s %s está dos veces en el libro: en la apertura (%s) y por su puente (%s). Se corrige la apertura con un '
                        'ajuste, o se rehace el papel.', p.tabla, p.id, fn_puente_en_apertura(p.tabla, p.id)->>'asientos', a.numero)
            from (select 'recibos'::text as tabla, r.id::text as id, r.contabilizado_en as asiento
                    from recibos r where r.contabilizado_en is not null
                  union all
                  select 'trabajos_externos', x.id::text, x.contabilizado_en
                    from trabajos_externos x where x.contabilizado_en is not null) p
            join asientos a on a.id = p.asiento
           where fn_puente_en_apertura(p.tabla, p.id) is not null
          limit 50) s;
  control := 'partidas';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('fallan', v_malos);
  return next;

  -- devengo: el estándar vivo de cada mes abierto, contra las horas
  -- aprobadas de hoy (las mismas cuentas que haría fn_horas_devengar).
  -- Y si el mes ya tiene journal de nómina, el devengo cuenta dos veces lo
  -- que ese journal pagó (el 5000 del mes, journal más devengo, por encima
  -- de las horas): se deshace.
  select coalesce(jsonb_agg(case when x.plan->>'codigo' = 'nomina_en_el_mes'
                                 then format('el devengo de %s (%s) convive con el journal de nómina del mes (%s): cuenta dos veces '
                                             'las horas que ese journal ya pagó (en 5000, y en 2210 como por pagar). select '
                                             'fn_horas_devengar(''%s''); lo deshace.', x.periodo, x.numero,
                                             (select string_agg(n.v, ', ') from jsonb_array_elements_text(x.plan->'nomina') n(v)),
                                             x.periodo)
                                 else format('el devengo de %s (%s) ya no es el de las horas aprobadas de hoy: select '
                                             'fn_horas_devengar(''%s'');', x.periodo, x.numero, x.periodo) end
                            order by x.periodo), '[]'::jsonb)
    into v_malos
    from (select p.periodo, v.numero, v.procedencia->>'firma' as firma, fn_puente_devengo_plan(p.periodo) as plan
            from periodos p
            cross join lateral fn_puente_vivo('horas_devengo', p.periodo) v
           where p.tipo = 'mes' and p.estado = 'abierto' and v.id is not null) x
   where x.firma is distinct from x.plan->>'firma'
      or x.plan->>'codigo' = 'nomina_en_el_mes';
  control := 'devengo';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('fallan', v_malos);
  return next;

  -- duplicados: el mismo papel dos veces en el libro. Dos recibos con
  -- asiento vivo y la misma foto, o el mismo ticket (proveedor, número y
  -- total): un reembolso no tiene statement de un tercero que lo
  -- contradiga, y se detecta sin la IA. Lo que Edgar confirmó que no es el
  -- mismo gasto (puente_revisados, duplicado) no cuenta.
  select coalesce(jsonb_agg(s.falla order by s.falla), '[]'::jsonb) into v_malos
    from (select format('la foto %s está en %s recibos con asiento vivo (%s): el mismo papel dos veces. Anula el repetido '
                        '(fn_recibo_anular) y el libro lo reversa', k.dato, count(*),
                        string_agg(format('recibo %s → %s', k.id, k.numero), ', ' order by k.id)) as falla
            from (select btrim(r.ruta) as dato, r.id, a.numero
                    from recibos r
                    join asientos a on a.id = r.contabilizado_en
                   where nullif(btrim(r.ruta), '') is not null
                     and not exists (select 1 from puente_revisados pr
                                      where pr.tabla = 'recibos' and pr.documento_id = r.id::text and pr.codigo = 'duplicado'
                                        and pr.dato = 'ruta:' || btrim(r.ruta))) k
           group by k.dato
          having count(*) > 1
          union all
          select format('el ticket %s está en %s recibos con asiento vivo (%s): el mismo gasto dos veces. Anula el repetido '
                        '(fn_recibo_anular); si son dos gastos distintos, confírmalo en el que llegó después '
                        '(fn_puentes_confirmar(''recibos'', id, ''duplicado'', ''motivo''))', k.dato, count(*),
                        string_agg(format('recibo %s → %s', k.id, k.numero), ', ' order by k.id))
            from (select fn_puente_recibo_clave(r.proveedor, r.num_recibo, r.total) as dato, r.id, a.numero
                    from recibos r
                    join asientos a on a.id = r.contabilizado_en
                   where not exists (select 1 from puente_revisados pr
                                      where pr.tabla = 'recibos' and pr.documento_id = r.id::text and pr.codigo = 'duplicado'
                                        and pr.dato = 'ticket:' || fn_puente_recibo_clave(r.proveedor, r.num_recibo, r.total))) k
           where k.dato is not null
           group by k.dato
          having count(*) > 1
          limit 50) s;
  control := 'duplicados';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('fallan', v_malos,
                                'pendientes', (select count(*) from puente_documentos d
                                                where d.tabla = 'recibos' and d.estado = 'pendiente' and d.codigo = 'duplicado'));
  return next;

  -- cuentas_inactivas: ninguna cuenta retirada (inactiva) con saldo vivo,
  -- medido como c1 (por obra y por código; las de resultado, en los años no
  -- cerrados). Un saldo ahí ya no lo mueve nadie: ningún asiento nuevo entra
  -- a una cuenta inactiva.
  select coalesce(jsonb_agg(s.falla order by s.falla), '[]'::jsonb) into v_malos
    from (select format('la cuenta %s (%s) está inactiva y tiene saldo vivo: %s%s %s. Reactívala para trasladarlo (update cuentas '
                        'set activa = true where codigo = %L;)', c.codigo, c.nombre, coalesce(x.obra, '(sin obra)'),
                        case when x.cc is not null then ' / ' || x.cc else '' end, x.saldo, c.codigo) as falla
            from cuentas c
            cross join lateral (
                   select l.proyecto_id as obra, l.cost_code as cc, sum(l.monto) as saldo
                     from asiento_lineas l
                     join asientos a on a.id = l.asiento_id
                    where l.cuenta = c.codigo
                      and (   c.tipo in ('activo', 'pasivo', 'capital')
                           or not exists (select 1 from periodos p
                                           where p.tipo = 'anio' and p.anio = a.anio and p.estado = 'cerrado'))
                    group by l.proyecto_id, l.cost_code
                   having sum(l.monto) <> 0) x
           where not c.activa
           limit 50) s;
  control := 'cuentas_inactivas';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('fallan', v_malos,
                                'retenidos', (select count(*) from puente_documentos d
                                               where d.estado = 'contabilizado' and d.codigo = 'cuenta_inactiva'));
  return next;

  -- vistas: una vista que lee los papeles con los permisos de su dueño (sin
  -- security_invoker) se salta la RLS; si además la API la puede escribir,
  -- por ahí se editan papeles que el puente lleva al libro.
  with recursive dep(oid) as (
         select c.oid from pg_class c
          where c.relnamespace = 'public'::regnamespace
            and c.relname in ('recibos', 'facturas', 'trabajos_externos', 'horas', 'proyectos')
         union
         select rw.ev_class
           from dep
           join pg_depend d on d.refobjid = dep.oid and d.refclassid = 'pg_class'::regclass and d.classid = 'pg_rewrite'::regclass
           join pg_rewrite rw on rw.oid = d.objid
          where rw.ev_class <> dep.oid
       )
  select coalesce(jsonb_agg(format('%s puede hacer %s en la vista %s.%s, que lee los papeles con los permisos de su dueño (revoke '
                                   'insert, update, delete on %s.%s from anon, authenticated;)', r.rol, q.priv, n.nspname,
                                   c.relname, n.nspname, c.relname) order by c.relname, r.rol, q.priv), '[]'::jsonb)
    into v_malos
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    cross join (values ('anon'), ('authenticated')) as r(rol)
    cross join (values ('INSERT', 8), ('UPDATE', 4), ('DELETE', 16)) as q(priv, bit)
   where c.oid in (select dep.oid from dep) and c.relkind = 'v'
     and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o
                        where o.option_name = 'security_invoker'), false)
     and (pg_relation_is_updatable(c.oid, false) & q.bit) <> 0
     and has_table_privilege(r.rol, c.oid, q.priv);
  control := 'vistas';
  ok      := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('fallan', v_malos);
  return next;

  -- papel (Storage)
  control := 'papel';
  if to_regclass('storage.objects') is null then
    ok      := true;
    detalle := jsonb_build_object('nota', 'No hay Storage en esta base (banco de pruebas): no aplica.');
  else
    ok      := exists (select 1 from pg_policies p
                        where p.schemaname = 'storage' and p.tablename = 'objects' and p.policyname = 'el papel no se borra'
                          and p.permissive = 'RESTRICTIVE' and p.cmd = 'DELETE')
           and exists (select 1 from pg_policies p
                        where p.schemaname = 'storage' and p.tablename = 'objects' and p.policyname = 'el papel no se mueve'
                          and p.permissive = 'RESTRICTIVE' and p.cmd = 'UPDATE' and p.with_check is not null);
    detalle := jsonb_build_object(
      'nota', 'La foto de un recibo (recibos/) y los documentos (docs/) del almacén fotos no se borran, no se mueven y no se '
              'reemplazan por la API: los protegen las policies restrictivas «el papel no se borra» (DELETE) y «el papel no se '
              'mueve» (UPDATE).',
      'faltan', (select coalesce(jsonb_agg(e.nombre), '[]'::jsonb)
                   from (values ('el papel no se borra', 'DELETE'), ('el papel no se mueve', 'UPDATE')) e(nombre, cmd)
                  where not exists (select 1 from pg_policies p
                                     where p.schemaname = 'storage' and p.tablename = 'objects' and p.policyname = e.nombre
                                       and p.permissive = 'RESTRICTIVE' and p.cmd = e.cmd)),
      'arreglo', case when not ok then 'vuelve a pegar c3-puentes.sql (desde el SQL Editor)' end);
  end if;
  return next;
end $$;
revoke execute on function public.fn_puentes_verificar() from public, anon, authenticated, service_role;
grant  execute on function public.fn_puentes_verificar() to authenticated;


-- ---------------------------------------------------------------------
-- B.12 · Lo que un auditor lee en pg_description (de aquí sale
-- docs/conta/MAPA-DATOS.md).
-- ---------------------------------------------------------------------
comment on table public.puente_cuentas is
  'Las cuentas que usa cada puente, por lo que son (cxp 2010, cxc 1110, retención 1120, subcontratos 5200, banco 1010, reembolsos '
  '2900/2250, el devengo estándar 5000/2210; mano_obra_oficial 5001 y use_tax 2300, solo vigiladas). Las fija el plan (c3).';
comment on table public.mapeo_categoria_recibo is
  'Qué cuenta recibe el gasto de un recibo, por su categoría (c3). confirmado_el nulo = BORRADOR: no postea. cuenta_sin_obra: la de '
  'un recibo sin obra (nula = espera a que se le asigne). Cada cambio, en puente_reglas_historial.';
comment on table public.mapeo_metodo_pago is
  'Qué forma de pago es cada texto que la lectura escribe en recibos.metodo_pago (c3): cuenta_proveedor (2010, por proveedor), '
  'tarjeta (por sus últimos 4), banco, efectivo o reembolso. Borrador = no postea; un texto que no está, a la bandeja.';
comment on table public.mapeo_tipo_proyecto is
  'La cuenta de ingreso de una factura, por el tipo de su obra (c3). Borrador = no postea.';
comment on table public.tarjetas is
  'Las tarjetas por sus últimos 4 (recibos.ultimos4) y su cuenta: 2100-XXXX, el banco (débito), 2900 (de Edgar) o 2250 (de un '
  'empleado, empleado_id). Apple Pay imprime los 4 del teléfono: se dan de alta también.';
comment on table public.proveedores is
  'Proveedores: supplies, subcontratistas y ayudantes (externo_id = su fila en externos_equipo). Terceros de la CxP (2010). f12 le '
  'añade TIN, W-9 y COI.';
comment on table public.proveedores_alias is
  'Los nombres con que la lectura del recibo escribe a un proveedor (normalizados): así se casa recibos.proveedor con su proveedor.';
comment on table public.puente_reglas_historial is
  'Cada alta, cambio o baja de una regla de los puentes (mapeos, tarjetas, proveedores, cuentas): quién, cuándo, antes y después. '
  'No se edita ni se borra.';
comment on table public.cobros is
  'Un cobro = un depósito (c3): fecha, monto, cuenta de banco; se reparte en aplicaciones_cobro. Postea Dr banco / Cr 1110-1120 '
  'por partida. No se edita ni se borra: se anula (fn_cobro_anular). movimiento_id: su movimiento del banco (f06).';
comment on table public.aplicaciones_cobro is
  'A qué va cada parte de un cobro: una factura, su retención, un descuento, o anticipo de una obra (sin factura); desde_anticipo = '
  'aplica un anticipo ya cobrado a una factura, sin dinero nuevo, con su propio asiento.';
comment on table public.notas_credito is
  'La nota de crédito que anula una factura emitida entera (anula_a), con número propio sin huecos por año (NC-AAAA-NNNN): el '
  'espejo de su asiento. Una factura emitida no se borra.';
comment on table public.puente_documentos is
  'En qué quedó cada papel que el puente miró: contabilizado, pendiente (le toca a Edgar), espera (a la lectura), no_aplica o '
  'error; con su motivo y su asiento vivo. De aquí sale la bandeja (puentes_bandeja).';
comment on table public.puente_revisados is
  'Lo que Edgar confirmó de un papel que esperaba en la bandeja por una duda que solo él resuelve: fecha_antes_del_corte (de verdad es '
  'de antes y está en QuickBooks), fecha_posterior_a_subida (la fecha leída es la buena), duplicado (no es el mismo gasto que el otro '
  'recibo), impuesto (el total es lo que se pagó), devolucion (es una compra). Vale para ese dato: si el papel lo cambia, se vuelve a '
  'preguntar. Solo se añade (c3).';
comment on table public.horas_aprobaciones is
  'Cada aprobación de horas y lo que le pasó: retirada, invalidada (las horas cambiaron después) o borrada. El reporte de horas '
  'aprobado al que llega la nómina (f11). Solo se añade.';
comment on column public.recibos.llave_cliente     is 'La llave del teléfono (única): el doble toque sin señal entra una vez (409 = ya estaba). c3.';
comment on column public.recibos.contabilizado_en  is 'El asiento vivo del recibo (c3). Lo pone solo el puente. Con asiento (aunque reversado), el recibo no se borra.';
comment on column public.facturas.estado           is 'emitida (así nacen, desde QuickBooks), borrador (f10) o anulada (con su nota de crédito). c3.';
comment on column public.facturas.retencion        is 'La parte de esta factura que el cliente retiene y paga al final (va a 1120). monto sigue siendo el total. 0 = sin retención; nula = no se dijo (con señal de retención, la factura espera en la bandeja). c3.';
comment on column public.trabajos_externos.proveedor_id is 'A quién se le debe este trabajo externo (proveedores): lo pone Edgar; nulo = el proveedor de su ayudante (externo_id), si lo hay. Sin proveedor, la deuda no sale por proveedor ni en el 1099 (aviso en la bandeja). c3.';
comment on column public.cobros.llave_cliente      is 'La llave del teléfono (única): el mismo cobro mandado dos veces entra una (la segunda devuelve el que ya estaba). c3.';
comment on column public.facturas.contabilizado_en is 'El asiento vivo de la factura (c3). En el libro: su monto, fecha, obra, número y retención ya no cambian; se anula con nota de crédito.';
comment on column public.trabajos_externos.contabilizado_en is 'El asiento vivo del trabajo externo (c3). En el libro no se borra: se anula (costo 0).';
comment on column public.horas.aprobado_por        is 'Quién aprobó estas horas (el dueño; nulo si fue desde el SQL Editor). Si las horas cambian, la aprobación se cae. c3.';
comment on column public.horas.aprobado_el         is 'Cuándo se aprobaron. Aprobadas = clave de reparto de la nómina (horas_aprobadas_por_obra_periodo). Nunca dinero. c3.';
comment on view public.puentes_bandeja is
  'Lo que el puente no pudo contabilizar y tiene que resolver Edgar (pendiente), lo que el libro rechazó (error), lo que lleva más '
  'de dos días esperando la lectura (espera) y lo que entró con algo por completar (aviso), con el motivo en llano.';
comment on view public.horas_aprobadas_por_obra_periodo is
  'Horas aprobadas por mes, trabajador, obra y CO: la clave de reparto de la nómina (f11) y del burden (f09). Horas, nunca dólares.';
comment on view public.cxp_abierta  is 'Lo que se debe en 2010, por proveedor y por partida abierta (el papel que la abrió).';
comment on view public.cxc_abierta  is 'Lo que se cobra en 1110 y 1120, por partida abierta (factura, o el cobro de un anticipo).';
comment on view public.facturas_cobro is
  'Cada factura con lo que dice la app (pagada, cobrado: la casilla de Edgar o QuickBooks) y lo que dice el libro: cobrado_libro es '
  'solo el dinero de los cobros (el descuento va aparte, en descuento_libro), y el saldo por cuenta (saldo_cxc, saldo_retencion). El '
  'aviso dice lo que f06 tiene que casar con el banco.';
comment on function public.fn_puentes_correr(date)            is 'El backfill y el «reintentar puente»: pasa el puente por todos los papeles desde el corte. Idempotente.';
comment on function public.fn_puentes_rehacer(text, text, text) is 'Reverso + asiento nuevo de un papel con las reglas de hoy, con su motivo (solo el dueño).';
comment on function public.fn_puentes_verificar()             is 'Los controles de los puentes: triggers, papeles contra el libro, bandeja, reglas, use tax, mano de obra y burden, partidas, devengo, duplicados, cuentas inactivas con saldo, vistas del equipo y el papel en Storage.';
comment on function public.fn_puentes_antes_del_corte(text, bigint, text) is 'Confirma que un recibo o trabajo externo fechado antes del corte (y subido después) es de verdad de antes y está en QuickBooks.';
comment on function public.fn_puentes_confirmar(text, bigint, text, text) is 'Confirma, con su motivo, lo que el puente pregunta de un papel (fecha_antes_del_corte, fecha_posterior_a_subida, duplicado, impuesto, devolucion): vale para ese dato.';
comment on function public.fn_recibo_desanular(bigint, text)  is 'Vuelve a contar un recibo anulado (a propósito, con su motivo): el ✎ de la app no lo des-anula.';
comment on function public.fn_cobro_registrar(jsonb)          is 'Registra un cobro con sus aplicaciones (facturas, retención, descuento, anticipo) y lo postea: Dr banco / Cr 1110-1120.';
comment on function public.fn_cobro_anular(uuid, text)        is 'Anula un cobro: reversa su asiento y el de sus anticipos aplicados. El cobro se queda, anulado.';
comment on function public.fn_anticipo_aplicar(uuid, bigint, text, date) is 'Aplica el anticipo de un cobro a una factura de su obra, sin dinero nuevo.';
comment on function public.fn_factura_anular(bigint, text, date) is 'Anula una factura emitida con su nota de crédito (NC-AAAA-NNNN): el espejo de su asiento.';
comment on function public.fn_horas_aprobar(uuid, date, date) is 'Aprueba las horas de un trabajador en un período (un toque por empleado). Horas, nunca dinero.';
comment on function public.fn_horas_devengar(text)            is 'El devengo ESTÁNDAR opcional de un mes: Dr 5000 / Cr 2210 por horas aprobadas × costo por hora (sin las del dueño), reversible el día 1; sin horas, o con journal de nómina en el mes, no devenga (y deshace el que había).';
comment on function public.fn_recibo_anular(bigint, text)     is 'Anula un recibo (estado anulado) y el puente lo reversa con el motivo. Es lo que lo saca de las listas de la app.';
comment on function public.fn_externo_anular(bigint, text)    is 'Anula un trabajo externo (costo 0) y el puente lo reversa con el motivo.';


-- ---------------------------------------------------------------------
-- B.13 · El sello. Lo ÚLTIMO: las funciones y los triggers de este archivo
-- se vigilan desde las huellas de c2 (por nombre y por prefijo). Al
-- empezar (A.0) se comprobó que las huellas estaban sanas; ahora se
-- resellan con lo que este pegado dejó puesto.
-- ---------------------------------------------------------------------
do $$
begin
  perform public.fn_libro_huellas_sellar('c3-puentes.sql');
end $$;


-- =====================================================================
-- Lo que enseña el SQL Editor al terminar: los controles del libro y los
-- de los puentes. Todos en true, salvo «sin_evaluar» la primera vez (los
-- papeles desde el 1-oct todavía no pasaron: select fn_puentes_correr();)
-- y «reglas», que dice cuántas siguen en borrador.
-- =====================================================================
select 'libro · ' || v.control as control, v.ok, v.detalle from public.fn_verificar_cadena() v
union all
select 'puentes · ' || p.control, p.ok, p.detalle from public.fn_puentes_verificar() p;
