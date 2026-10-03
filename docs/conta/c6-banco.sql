-- =====================================================================
-- C6 · El banco — Max Power Electrical Solutions, Inc. (Fase 6, bloque B
-- de f06: los archivos del banco, el casado, la conciliación, los
-- préstamos y los prepagados)
-- Supabase → SQL Editor. Se pega ENTERO, después de c1-plan-de-cuentas.sql,
-- c2-libro.sql, c3-puentes.sql y c4-estados.sql, DE LA VERSIÓN QUE TRAE
-- ESTA MISMA ENTREGA (sus marcas: c2 2026092701, c3 y c4 2026092601; ver
-- «CAMBIOS A c2, c3 Y c4», abajo). La marca de este archivo es 2026100201
-- (fn_banco_version). Si falta alguno o es anterior, para con MX000 y dice qué volver
-- a pegar, sin tocar nada. Se puede volver a pegar encima de sí mismo las
-- veces que haga falta: no duplica nada, no pisa lo que Edgar ajustó (un
-- descriptor, un préstamo, una póliza) y no toca el libro. Después se pega
-- c6-pruebas.sql (pruebas/conta/README.md, §0).
--
-- QUÉ ES. Lo que dice el banco, al lado del libro, y el hilo entre los dos:
--   · los ARCHIVOS del banco (OFX/QFX de Chase y de Amex; más adelante las
--     filas de Plaid) entran ENTEROS y se guardan tal cual (su texto y su
--     sha256): el respaldo permanente de lo que dijo el banco;
--   · cada MOVIMIENTO del banco es una fila inmutable (MX003): lo que dijo
--     el banco no se edita nunca. Solo cambian su estado y su casado, por
--     sus funciones, con quién, cuándo y por qué (banco_historial);
--   · el CASADO: cada movimiento con lo que lo explica en el libro (el
--     ticket que ya entró por c3, el cobro, la otra mitad de una
--     transferencia, la cuota del préstamo…). Automático SOLO el cruce
--     exacto y dos reglas fijas; todo lo demás se propone y espera a Edgar;
--   · la CONCILIACIÓN de cada cuenta a su fecha de corte, de verdad: libros
--     = banco + depósitos en tránsito − cheques y cargos en circulación,
--     con cada partida explicada y su clic; se confirma solo con 0.00;
--   · los PRÉSTAMOS (cada cuota partida en capital e interés) y los
--     PREPAGADOS (seguros y fianzas al gasto día por día).
--
-- LAS REGLAS QUE NO SE ROMPEN (f06):
--   1. Una línea del banco JAMÁS se contabiliza dos veces: un movimiento
--      tiene un casado vivo, y una línea del libro casa con un movimiento
--      vivo (índices únicos). El mismo movimiento por archivo y por Plaid
--      entra UNA vez (su FITID o su id de Plaid, o su fecha, monto y
--      descripción), o entra marcado «posible duplicado» y espera.
--   2. PRIMERO CASAR, DESPUÉS CLASIFICAR: lo que ya está en el libro (el
--      ticket de c3) se casa; clasificarlo otra vez lo metería dos veces
--      (fn_banco_clasificar lo rechaza y dice con qué casa).
--   3. Un depósito NUNCA va a ingreso: es el cobro de una factura (c3,
--      fn_cobro_registrar), un anticipo de una obra, dinero de Edgar (2900
--      o 3100) o una transferencia. El ingreso lo pone la factura.
--   4. El pago de la tarjeta y el dinero a la reserva (1030) son
--      TRANSFERENCIAS: un asiento para los dos estados de cuenta, venga
--      primero el lado que venga.
--   5. Lo automático es solo el cruce exacto (mismo monto, dentro de su
--      ventana de fechas, sin empate: fn_banco_ventana, en 4) y las reglas
--      FIJAS: el interés de la cuenta del banco a 4910 y los cargos del
--      banco a 6130, cuando el tipo del banco, el signo y el descriptor
--      dicen lo mismo. El resto propone y espera.
--   6. La nómina entra solo por su journal: el de Gusto (f11), y antes de
--      f11 el del proveedor anterior (fn_banco_nomina, desde el SQL
--      Editor). Su débito en el banco espera ese journal y casa con él.
--
-- EL SIGNO. El monto de un movimiento lleva el signo que tiene en el libro
-- la línea de SU cuenta: en el banco (1010, 1030), un depósito es positivo
-- (Dr 1010) y un cargo negativo; en una tarjeta (2100-2013, 2100-2009,
-- acreedoras), una compra es negativa (Cr 2100-x) y un pago positivo. El
-- archivo OFX ya viene así (TRNAMT); Plaid, al revés (se voltea al
-- entrar). Así casar es comparar montos iguales.
--
-- LAS CUENTAS DE EDGAR: Chase 1010 («Chase Chk 4392» en QuickBooks, con su
-- tarjeta de débito …9420), la reserva de impuestos 1030 (por abrir), la
-- Amex Gold …2013 (2100-2013; «1007» en QuickBooks) y la Amex Blue …2009
-- (2100-2009); la caja chica 1050 (el efectivo: su «conciliación» es
-- contarlo). Un archivo dice sus 4 últimos (ACCTID) y va a su cuenta sola:
-- las tarjetas por la tabla tarjetas de c3, los bancos por el último
-- archivo con esos 4 últimos; el primero, diciéndola (p_cuenta), con su
-- aviso; si entró a la que no era, se retira (fn_banco_archivo_retirar,
-- desde el SQL Editor) y se vuelve a subir a la suya (ronda 4).
--
-- =====================================================================
-- LO QUE LLAMA conta.js (todas con es_dueno() por dentro: el equipo y anon
-- no ejecutan nada, 42501). Cada una devuelve jsonb con lo que hizo y, si
-- algo queda pendiente, qué sigue. Los errores con nombre, abajo.
-- =====================================================================
--   IMPORTAR
--   fn_banco_importar_ofx(p_texto text, p_cuenta text default null,
--                         p_nombre text default null)
--       El archivo entero, como texto (OFX 1.x SGML u OFX 2.x XML; de banco,
--       BANKMSGSRSV1, o de tarjeta, CREDITCARDMSGSRSV1). p_cuenta: la
--       cuenta del plan ('1010', '2100-2013') o los 4 últimos ('2013'); sin
--       ella, la que dice el archivo. Lee TRNTYPE, DTPOSTED (y DTUSER),
--       TRNAMT (dos decimales como mucho), FITID, CHECKNUM, NAME y MEMO; el
--       saldo final (LEDGERBAL: BALAMT y DTASOF; AVAILBAL no). Idempotente:
--       el mismo archivo otra vez no entra (su sha256) y un archivo que se
--       solapa con otro solo mete lo nuevo (cuenta los repetidos). Un
--       archivo que no se puede leer: MX009 con la razón en español.
--       Devuelve {archivo, cuenta, formato, filas_leidas, filas_nuevas,
--       filas_repetidas, filas_fuera, duplicados_posibles, desde, hasta,
--       saldo, saldo_al, avisos, siguiente}.
--   fn_banco_importar_filas(p_lote jsonb)
--       Lo mismo con filas ya leídas (Plaid): {"origen": "plaid",
--       "cuenta": "1010" | "ultimos4": "4392", "nombre": "…",
--       "plaid_saldo": "…" (el de Plaid tal cual; en csv o a mano,
--       "saldo", con el signo del libro), "saldo_al": "AAAA-MM-DD",
--       "filas": [{"id": "…", "fecha": "…", "monto": "…" | "plaid_monto":
--       "…", "descripcion": "…", "memo": "…", "tipo": "…", "cheque": "…",
--       "pendiente": false}]}. Solo las posteadas: una pendiente no entra
--       nunca (cuenta en filas_fuera). Los montos y el saldo, con coma de
--       miles o sin ella («-1,029.33»).
--   CASAR
--   fn_banco_casar(p_movimiento uuid)            uno
--   fn_banco_casar_todo(p_cuenta text default null, p_desde date default null)
--       Lo pendiente (de una cuenta, desde una fecha): casa lo que casa
--       solo y deja en cada uno de los demás su PROPUESTA (motivo, texto y
--       opciones: cada opción dice qué función llamar y con qué argumentos,
--       para pintar un botón). Devuelve {pendientes_antes, casados,
--       por_regla, pendientes, por_motivo, completo, ms}. Mira el reloj:
--       con la bandeja atrasada de meses para antes del tope de la API (a
--       los 4 s lo automático, a los 5 s las propuestas) con «completo»:
--       false y «siguiente»: conta.js vuelve a llamar (lo casado queda y
--       la llamada siguiente sigue donde quedó). Las propuestas que no
--       alcanzaron conservan la anterior (propuestas_sin_rehacer) y se
--       rehacen al abrir el movimiento (fn_banco_casar).
--   LA BANDEJA (lo que Edgar decide)
--   fn_banco_casar_con(p_movimiento uuid, p_con jsonb, p_motivo text default null)
--       «Confirmar cruce»: {"lineas": [{"asiento_id", "orden"}]} |
--       {"asiento": "…"} | {"recibo": 123} | {"cobro": "…"} |
--       {"partida_apertura": "…"} | {"movimiento": "…"} (el otro lado de
--       una transferencia). Sobre un cargo CLASIFICADO cuyo ticket llegó
--       después (la bandeja: «llego_su_ticket»), con su ticket ({"recibo"},
--       o su asiento o sus líneas; el repartido entre obras, las de todas
--       sus partes) cambia la clasificación por él (la reversa y casa).
--       (Ronda 4) {"cobro": "…", "comision": "29.30"}: el cobro con tarjeta
--       anotado por el bruto y depositado neto; {"cobro": "…", "corrige":
--       true} con su motivo: el cobro anotado por otro monto se anula y se
--       registra el bueno con este depósito; {"cuota": "…", "diferencia":
--       "capital" | "interes"}: la cuota ya registrada, cobrada por otro
--       monto.
--   fn_banco_cobrar(p_movimiento uuid, p_aplicaciones jsonb, p_notas text default null)
--       Un depósito sin cobro: registra su cobro (fn_cobro_registrar de c3)
--       con este movimiento; p_aplicaciones como en c3 ([{"factura_id",
--       "monto"}, {"proyecto_id", "monto"} …]). Neto de la comisión de un
--       procesador de tarjeta: {"comision": "29.30"} en la lista (el cobro
--       por el bruto y la comisión a 6130, casados juntos).
--   fn_banco_pagar_proveedor(p_movimiento uuid, p_proveedor uuid, p_partidas jsonb default null)
--       Dr 2010 por sus partidas abiertas (las que diga, o las más viejas
--       primero) / Cr el banco. Nunca a 5100. Con un depósito, su
--       reembolso: contra lo que el proveedor tiene a favor (Cr 2010).
--   fn_banco_transferencia(p_movimiento uuid, p_cuenta text, p_motivo text default null)
--       Dinero entre cuentas propias con un solo lado todavía: un asiento
--       con su contrapartida; el otro lado, cuando llegue, casa con él.
--   fn_banco_clasificar(p_movimiento uuid, p_lineas jsonb, p_motivo text default null)
--       Lo que no casó con nada: [{"cuenta", "monto"?, "proyecto_id"?,
--       "cost_code"?, "memo"? …}]. Nunca a ingreso un depósito, ni a una
--       cuenta propia, ni a 2010, 1110, 1120 ni a mano de obra. (Ronda 4)
--       Salvo el cheque devuelto de una factura de QuickBooks (cobrada antes
--       del corte): {"cuenta": "1110", "factura_id": …}, con su motivo.
--       Los errores de una línea dicen su número (el de Edgar).
--   fn_banco_ignorar(p_movimiento uuid, p_motivo text)
--   fn_banco_duplicado(p_movimiento uuid, p_es_el_mismo boolean, p_motivo text default null)
--       Un «posible duplicado»: si es el mismo, ignorado. Un cargo
--       clasificado cuyo ticket llegó: true, es su ticket (como arriba; uno
--       de otro total, no hasta corregir su total; el repartido entre
--       obras, con todas sus partes); false, otra compra (con su motivo).
--       (Ronda 4) Un movimiento casado que puede ser una partida de la
--       apertura: false, con su motivo, no lo es.
--   fn_banco_devolver(p_movimiento uuid, p_cobro uuid, p_motivo text)
--       Un cheque devuelto: fn_cobro_devolver (c3) con este movimiento. El
--       cheque de un depósito de varios (su cobro los junta): p_cobro es la
--       aplicación de la factura que rebotó; se devuelve el cobro y lo que
--       no rebotó se registra otra vez ese día (ronda 4: también uno de los
--       dos cheques de la MISMA factura: la aplicación se parte).
--   fn_banco_descasar(p_movimiento uuid, p_motivo text)
--       Deshace un casado (el asiento que puso, lo reversa) y el movimiento
--       vuelve a la bandeja con su propuesta. Dentro de una conciliación
--       confirmada, no (se reabre antes).
--   CONCILIAR
--   fn_conciliar(p_cuenta text, p_fecha_corte date, p_saldo_statement text default null)
--   fn_conciliacion_partida(p_partida uuid, p_clase text, p_motivo text)
--   fn_conciliacion_confirmar(p_conciliacion uuid)
--   fn_conciliacion_reabrir(p_conciliacion uuid, p_motivo text)
--   fn_conciliacion_apertura(p_cuenta text, p_saldo_statement text,
--                            p_partidas jsonb default '[]', p_motivo text default null)
--   PRÉSTAMOS Y PREPAGADOS
--   fn_prestamo_cuota(p_prestamo uuid, p_movimiento uuid default null, p_fecha date default null,
--                     p_monto text default null, p_capital text default null,
--                     p_interes text default null, p_motivo text default null)
--   fn_prepagados_amortizar(p_periodo text)
--   EL CONTROL (antes de pintar)
--   fn_banco_control(p_periodo text, p_vistas text[] default null)
--       El contrato de fn_estados_control (c4): (orden, vista, filas,
--       esperadas, ok, detalle); ok = false no se pinta, y el detalle dice
--       qué falló o «esperaba N».
-- Desde el SQL Editor (sin grant a la API): fn_prestamo_guardar(jsonb),
-- fn_prepagado_guardar(jsonb) (una póliza de antes del corte dice su
-- saldo_corte: lo que dejó QuickBooks en 1410; la que corrige a otra ya
-- amortizada, "sustituye"; una cancelada, "cancelado_al" y "devuelto"),
-- fn_conciliacion_anular(conciliacion, motivo) (una conciliación ABIERTA
-- hecha por error: se quita, con rastro), fn_banco_descriptor(clave,
-- patron, cuenta, notas), fn_banco_nomina(movimiento, lineas, motivo) (el
-- journal de la nómina del proveedor anterior, antes de f11; también la
-- nómina solo del oficial, 6000/6005), fn_conciliacion_saldo(conciliacion,
-- motivo, documento) (por qué el saldo escrito del statement no es el que
-- trae el archivo del banco ese día, con el documento que lo respalda) y
-- fn_banco_verificar(p_cuentas text[] default null) (la revisión entera;
-- de unas cuentas, si se dicen), y (ronda 4) fn_banco_archivo_retirar(
-- archivo, motivo) (el estado de cuenta subido a la cuenta que no era:
-- sus movimientos, ignorados; sus casados, deshechos; y se vuelve a subir a
-- la suya).
--
-- LAS VISTAS (security_invoker: el dueño ve, el equipo lee 0 filas, anon
-- no las abre; cada cifra con su movimiento_id, su asiento_id/numero y su
-- papel_tabla/papel_id):
--   v_banco_movimientos    cada movimiento con su estado, su regla, su
--                          asiento y su papel (filtrar por cuenta y periodo)
--   v_banco_bandeja        lo pendiente, con motivo, texto y opciones
--   v_banco_saldos         cada banco y tarjeta: libros, banco, pendiente,
--                          última conciliación y alarma
--   v_conciliacion         cada conciliación con su identidad
--   v_conciliacion_partidas lo de cada conciliación en tres grupos
--   v_prestamos            cada préstamo: saldo, porción corriente, cuotas
--   v_prepagados           cada póliza: amortizado, por amortizar, atrasado
--   (y v_papel_fases, para v_asiento_papel de c4)
--
-- LOS ERRORES CON NOMBRE (los de c2 y c3, y uno nuevo):
--   MX000  falta algo que este archivo da por hecho (al pegarlo)
--   MX001  no suma: las líneas no dan el movimiento, capital + interés no
--          dan la cuota
--   MX002  fecha: antes del corte (vive en QuickBooks), un mes cerrado
--   MX003  inmutable: lo que dijo el banco, un casado, una conciliación
--          confirmada, un archivo, el historial
--   MX004  cuenta: no es un banco ni una tarjeta de la empresa, un archivo
--          de otra tarjeta, una cuenta que no va ahí
--   MX005  monto: más de dos decimales, cero, no numérico
--   MX008  estado: ya casado, pendiente de decir si es duplicado, dentro
--          de una conciliación confirmada, con candidatos en el libro…
--   MX009  el archivo del banco no se puede leer (nuevo): dice qué le falta
--          (no es OFX, sin cuenta, sin movimientos, una fecha rota…)
--   42501  no es el dueño.   22023  un argumento mal escrito.
--
-- LOS CANDADOS, en el orden de la app: el del archivo (su sha256) y el de
-- la cuenta al importar; el del casado (uno para todo el banco: dos
-- casados a la vez se esperan, milisegundos); la fila del movimiento; los
-- de c3 si registra un cobro (cobros, recibos); periodos y la cadena (los
-- toma el libro al postear). Ninguno de la app espera al del casado, y el
-- casado nunca espera a un recibo que la app esté guardando.
--
-- CAMBIOS A c2, c3 Y c4 (mínimos; se vuelven a pegar encima de sí mismos
-- sin tocar el libro, en orden, ANTES de este archivo; cada uno dice
-- «CAMBIOS PARA c6» en su cabecera y trae su prueba):
--   · c2: el reparto de funciones y las huellas conocen las de este
--     archivo que llama la app; fn_reversar sobre un asiento del banco dice
--     el camino bueno (des-casar o volver a amortizar); marca 2026092601.
--     Prueba: la 81 de c2-pruebas.sql. Y (ronda 2) fn_libro_huellas_sellar
--     ya no bendice un es_dueno() cambiado cuando resella una fase (c3,
--     c6): el candado lo fija solo el pegado de c2; marca 2026092701.
--     Prueba: la 82 de c2-pruebas.sql;
--   · c3: la guarda de los cobros deja soltar el movimiento de un cobro
--     (de su valor a nulo) solo con la marca de fn_banco_descasar; marca
--     2026092601. Prueba: la 119 de c3-pruebas.sql;
--   · c4: v_asiento_papel lee el papel de los asientos del banco en
--     v_papel_fases (c4 la crea vacía; este archivo la llena); marca
--     fn_estados_version() 2026092601. Prueba: la 111 de c4-pruebas.sql.
--     Y c4-pruebas.sql sigue en verde con el banco en uso (sin cambiar
--     c4-estados.sql): la 17 cuenta la caja chica en el efectivo final y
--     la 26 mira solo los asientos de su escenario; (ronda 2) la 53 mira
--     solo las filas de su escenario y la 39 le da fondos al banco antes de
--     medir (octubre en uso con la apertura sin postear);
--   · c3-pruebas.sql (ronda 2; c3-puentes.sql no cambia): las seis del
--     devengo (28, 57, 67, 74, 77 y 99) devengan en el primer mes abierto
--     SIN journal de nómina; con la nómina de octubre ya en el libro
--     (fn_banco_nomina) salían en rojo sin que nada estuviera roto. (Ronda
--     3) y cuyo último día no pasa del tope de fecha de c2: con la nómina
--     semanal (el mes en curso con su primer journal y el anterior
--     abierto) el mes elegido pasaba del tope y salían en rojo con MX002;
--     ahora «omitida», con el tope (la 120 lo vigila).
--     pruebas/conta/c6-en-uso.sh corre las cuatro suites con octubre en
--     uso (la póliza de QuickBooks, la nómina, un ticket de la segunda
--     obra) y las quiere en verde; (ronda 3) y otra vez c3- y c6-pruebas
--     con noviembre en uso y octubre abierto (la primera nómina semanal de
--     noviembre, octubre y noviembre amortizados).
--
-- LA RONDA 2 DE CORRECCIONES (27-sep; marca 2026092703). Cada arreglo con
-- su prueba en c6-pruebas.sql (el número entre paréntesis):
--   · LA APERTURA. La partida en tránsito que el banco trae a su manera (el
--     cheque sin CHECKNUM, con el número solo en NAME; el depósito del
--     30-sep en dos) sale en la bandeja como «partida_apertura», con la
--     opción que la casa (o que suma los dos) delante: clasificarla o
--     cobrarla sin motivo es MX008 (la metería dos veces); una partida que
--     nunca llega no deja confirmar el mes sin su motivo (63). Ya no casa
--     sola con cualquier depósito del mismo monto de 60 días: solo por su
--     número de cheque o, sin número, en la primera semana y si nada más
--     lo explica; el cobro de un cliente con su factura abierta espera a
--     Edgar con las dos opciones (64).
--   · «Casar» no rehace una transferencia ni mete su línea dentro de una
--     conciliación CONFIRMADA: la propone diciendo qué reabrir (65).
--   · LA TARJETA. Un abono que no dice que es un pago es una devolución,
--     contra la cuenta y la obra del ticket de ese comercio; AUTOPAY y
--     THANK YOU sueltos ya no son el pago de la tarjeta, R3 solo casa solo
--     el cargo del banco que nombra al emisor con el crédito de la tarjeta
--     que dice pago, y confirmar como transferencia algo sin esa señal
--     pide motivo (66). Su código corto («2013») vale también en casar,
--     conciliar, la apertura y la revisión (79).
--   · EL SALDO ESCRITO del statement que no es el que trae el archivo del
--     banco ese día deja la diferencia en cero pero pide su motivo y su
--     documento (n_pide_motivo, fn_conciliacion_saldo): sin ellos no se
--     confirma, y una confirmada así sale en rojo en el cuadre 54 (67).
--   · LOS PRÉSTAMOS. El capital de la cuota baja primero la cuenta que
--     tiene el saldo (la corriente mientras tenga, después la de largo
--     plazo: la apertura puede traerlo todo en 2530) y el cuadre 55 pone
--     en rojo una cuenta de préstamo con saldo deudor (68). Un pago que no
--     es la cuota, o a menos de 25 días de la anterior (un abono extra a
--     capital), no va por la fórmula: pide lo que dice el statement (69).
--     fn_prestamo_guardar y fn_prepagado_guardar leen la tasa con coma y
--     dicen en español lo que está mal escrito (22023) (70).
--   · LA SEGURIDAD. Volver a pegar este archivo no bendice un es_dueno()
--     cambiado (sección 0, y el sellador de c2) (71). El cuadre 90 ve la
--     función de TRIGGER ajena, SECURITY DEFINER, que lee el banco desde
--     una tabla donde la API escribe (72). El cuadre 53 ve el asiento del
--     banco que se quedó sin su papel (el estado de cuenta borrado entero
--     con las guardas apagadas), y fn_banco_verificar también, con el
--     archivo que el historial dice que entró (73).
--   · LA BANDEJA. El cheque de un cliente devuelto (NSF) propone devolver
--     ESE cobro y su comisión va sola a 6130 (74); la retención liberada y
--     el pago parcial de una factura tienen su botón (75); un cheque sin
--     nombre por lo que se le debe a un proveedor es un abono a su cuenta,
--     no otra vez costo (76); la nómina solo del oficial (6000/6005) entra
--     por fn_banco_nomina y el sueldo no se clasifica desde el banco (77);
--     el reembolso de un proveedor se casa contra lo que tenía a favor
--     (fn_banco_pagar_proveedor con el depósito) (78); des-casar la mitad
--     de una transferencia cuya otra mitad está conciliada dice cuál
--     reabrir (80), y un depósito des-casado de su cobro dice lo que pasó y
--     ofrece anular ese cobro (81).
--   · EL TIEMPO. El cruce de transferencias (R3) mira lo del alcance y sus
--     contrapartes, una vez por llamada y con el reloj antes de cada regla
--     (62): con la bandeja de un año entero sin resolver y dos meses más,
--     casar tarda unos 3 s (antes 57014 en cada llamada). Cada propuesta
--     lleva su propia firma (sus candidatos, su obra, su contraparte): un
--     ticket que no le cambia nada no la rehace ni escribe el historial
--     (59, 82). La pareja de la conciliación se busca por clave (la fecha,
--     el monto que falta) sobre una tabla temporal con sus estadísticas:
--     «Cuadrar» antes de casar tarda 1,1 s con un mes y 1,4 s con dos
--     (antes de 3 a 7 s, y 57014). c6-volumen.sh mide los dos casos. Y el
--     importador ya no depende de las estadísticas de la tabla: con la
--     tabla «vacía» para el planificador (después de un rollback grande,
--     como los de las pruebas) cada fila recorría la cuenta entera por la
--     llave única, que ahora es la llave sola, y un archivo de 3.000
--     después de otros tardaba de 3 a 12 s (la 53 salía en rojo al correr
--     c6-pruebas dos veces seguidas en la misma base). Y fn_banco_control,
--     el que pide cada pantalla, ya no tarda medio segundo con un año de
--     banco: lo ajeno se busca en una pasada (antes limpiaba el texto de
--     todas las funciones en cada vuelta), y los cuadres 51 y 54 suman de
--     una vez (antes una consulta por casado y por conciliación
--     confirmada). c6-pruebas, con un año de banco encima, bajó de 44 a
--     36 s (en PG16, 29 s).
--   (Lo que no se hizo, y por qué, lo dice pruebas/conta/README.md.)
--
-- LA RONDA 3 DE CORRECCIONES (27-sep; marca 2026092704). Cada arreglo con
-- su prueba en c6-pruebas.sql (el número entre paréntesis):
--   · EL TICKET CON OTRO TOTAL (leído sin el tax): el cargo que no casa al
--     centavo con la línea libre de un ticket de su cuenta en la ventana
--     de la compra, que se le parece (el banco nombra su comercio, o no se
--     separan más de un 12 %: fn_banco_otro_total), sale «otro_total» con
--     ese ticket y clasificarlo pide motivo; corregido el total del
--     recibo, casa solo (83). Clasificado antes de que llegue, el ticket de
--     otro total del comercio que nombra el banco se dice («llego_su_ticket»,
--     sin cambiarlo hasta corregir su total), pone en rojo el cuadre 57 y
--     la conciliación lo marca posible_duplicado (84). Y en la
--     conciliación, un ticket o una transferencia de más de 10 días sin su
--     movimiento piden su motivo (un cargo de otro total ya clasificado,
--     una transferencia puesta dos veces).
--   · LAS TRANSFERENCIAS. El pago de la tarjeta que el banco cobra días
--     después (hasta 7) casa con la transferencia que ya lo espera, y otra
--     transferencia por el mismo dinero a 10 días o menos (en cualquier
--     sentido) es MX008: la bandeja dice «transferencia_otro_lado» (85). R3
--     y «Desde …» no meten el asiento dentro de una conciliación confirmada
--     de ninguna de sus cuentas: va al día siguiente de su corte, con la
--     nota (fn_banco_tr_fecha), o no casa solo y dice qué reabrir (89).
--   · LOS DEPÓSITOS. Uno cuya propuesta es su cobro (también el pago
--     parcial) no se clasifica sin motivo, y el cuadre 52 pone en rojo el
--     que se clasificó así (86). El cheque que rebota de un depósito de
--     varios tiene su botón: se devuelve el cobro y lo demás se registra
--     otra vez ese día; clasificar un depósito devuelto, o un retiro contra
--     un ingreso, pide motivo (87). El cobro con tarjeta depositado neto
--     de su comisión: el cobro por el bruto y la comisión a 6130 casados
--     juntos (se reversa con el casado) (94).
--   · LOS CARGOS. Con un proveedor a cuenta, lo que nombra a otro (la luz,
--     el seguro domiciliado, un Zelle a una persona) sale «sin ticket»: el
--     abono a lo más viejo es solo del cheque o el ACH sin nombre
--     (fn_banco_pago_anonimo) (93). La obra propuesta es la de la visita
--     del día de la COMPRA (DTUSER, o el «MM/DD» de la nota); sin él, la
--     única de los días antes del banco, o ninguna y las dice (96).
--   · LA CONCILIACIÓN. Una con la fecha mal escrita, detrás de la última
--     confirmada, no se crea (reabrir va en orden: la última primero), y
--     la abierta hecha por error se anula con fn_conciliacion_anular desde
--     el SQL Editor (95). El statement de la tarjeta cortado antes del
--     30-sep: su cargo ignorado de antes del corte casa con la partida de
--     la apertura (fn_banco_apertura_previas; a mano, fn_banco_casar_con)
--     (92). El motivo de una partida de la apertura que sigue en tránsito
--     pasa al mes siguiente (99).
--   · LOS PREPAGADOS. La póliza corregida se registra como la que
--     SUSTITUYE a la vieja: lo amortizado vuelve y la nueva lo amortiza a
--     sus cuentas; la cancelada con su fecha y lo devuelto queda en cero
--     (88). El cuadre 56 cuenta las canceladas.
--   · PLAID Y LOS LOTES. plaid_saldo se voltea como plaid_monto; «saldo» en
--     un lote de Plaid no entra; el saldo positivo de una tarjeta a mano se
--     avisa; la coma de miles se lee (90).
--   · LA SEGURIDAD. El cuadre 90 ve la REGLA ajena (pg_rewrite) que lee el
--     banco desde una tabla donde la API escribe (91). Volver a pegar este
--     archivo con algo ajeno sobre sus vistas para con MX000 sin tocar
--     nada (fn_banco_vistas_ajenas; sin cascade) (97).
--   · LA BANDEJA. «No es su ticket» dice que pide motivo (98). La firma de
--     cada cargo lleva lo que se les debe a los proveedores que nombra (o
--     toda la 2010 en un pago sin nombre): un ticket a cuenta ya no rehace
--     la propuesta de la gasolina (100).
--   · LAS PRUEBAS en uso: c6-pruebas 22, 46 y 88 salen «omitida» si Edgar
--     ya amortizó un mes posterior al primero abierto; c3-pruebas elige el
--     mes del devengo dentro del tope de c2 (su 120); c6-en-uso.sh lo mide
--     con noviembre en uso.
--   · EL TIEMPO de lo nuevo, con un año de banco (c6-volumen.sh): el ticket
--     de otro total se busca desde las líneas LIBRES (pocas) hacia los
--     cargos, no al revés (fn_banco_tickets_llegados, el cuadre 57, las
--     propuestas: antes más de 8 s en cada «Casar», cada conciliación de
--     una tarjeta y cada control), y cada cargo propone los tres tickets
--     que más se le parecen. Y de paso, lo que cada «Casar» y cada control
--     repetían: el contexto de las propuestas lee las facturas abiertas
--     solo si hay un depósito del banco que proponer
--     (fn_banco_contexto_facturas); la fecha de lo que se le debe a un
--     proveedor sin partida sale de una pasada; el control acepta un
--     cuadre suelto por su nombre (las pruebas y fn_banco_verificar lo
--     usan); las huellas de las vistas se toman de su árbol guardado
--     (pg_rewrite), sin reconstruir su texto, y lo de c4 sellado por c4
--     no se vuelve a leer buscando lo ajeno. c6-pruebas, con las 18
--     pruebas nuevas, sigue en menos de 40 s.
--
-- LA RONDA 4 DE CORRECCIONES (2-oct; marca 2026100201): el casado y la
-- bandeja. Cada arreglo con su prueba en c6-pruebas.sql (entre paréntesis):
--   · LA TRANSFERENCIA DE FIN DE MES (101). La segunda rama de la decisión
--     de la ronda 3 (89): fn_banco_tr_fecha (ahora con el monto) ya no
--     fecha el asiento al día siguiente de la conciliación confirmada de
--     una cuenta si así deja PARTIDO el estado de cuenta de la otra (su
--     conciliación de ese mes la trae; una tarjeta sin conciliaciones, el
--     «hasta» de su archivo: fn_banco_corte_entre). Entonces «Desde …» y
--     «Hacia …» son MX008 y dicen qué reabrir, R3 no lo casa solo, la
--     propuesta lo dice («bloqueo») y la conciliación (la explicación y
--     «falta») nombra la conciliación que hay que reabrir y a quién
--     des-casar. Antes la Blue del 31-oct cuadraba en 0.00 sin poder
--     confirmarse nunca, con un «cásalos o clasifícalos» de algo casado.
--     El asiento empujado guarda por qué (procedencia.fecha_por).
--   · EL COBRO ANOTADO POR OTRO MONTO (102). El paso 11 propone primero los
--     cobros libres (con su línea sin casar) de otro monto, de 30 días
--     antes a 3 después, si ninguno ni varios suman exacto: «neto de su
--     comisión» (fn_banco_casar_con {cobro, comision}, con el tope de 3.5 %
--     más 0.30 y su anexo a 6130, como fn_banco_cobrar) o «corrígelo»
--     ({cobro, corrige}, con su motivo: se anula y se registra el bueno con
--     este depósito). Registrar otro cobro mientras haya uno así pide su
--     porqué en las notas (MX008); el MX008 de c3 que mandaba a «update
--     cobros» dice fn_banco_casar_con. Y en la conciliación, un cobro de
--     más de 10 días sin su depósito pide su motivo (el cuadre 54 lo
--     cuenta). Antes salía «sin cobro registrado» y el cobro quedaba en
--     tránsito para siempre.
--   · EL REBOTE DE UN DEPÓSITO DE DOS CHEQUES DE LA MISMA FACTURA (103):
--     fn_banco_devolver parte la aplicación más grande que lo que rebotó
--     (la elegida o la única): devuelve el cobro y registra otra vez lo que
--     no rebotó a la misma factura; R9 propone ese botón. Antes no había
--     camino.
--   · LA CUOTA DE OTRO MONTO (104): la cuota ya registrada antes que el
--     banco, cobrada por otro monto (±10 días: redondeada, con un recargo),
--     se propone «es ella»: fn_banco_casar_con {cuota, diferencia: capital
--     o interes} anula la registrada y la registra con el cargo. Otra cuota
--     o clasificarlo con una así libre pide motivo; en la conciliación, la
--     cuota de más de 10 días sin su cargo pide el suyo.
--   · LA CUOTA CON UN EXTRA A CAPITAL (105): fn_prestamo_particion pide el
--     statement solo a menos de 25 días de la anterior o por menos que la
--     cuota; la cuota más un extra va por la fórmula (el interés del mes y
--     lo demás a capital), y la propuesta lo dice primero. Antes se tomaba
--     por un abono y quedaba sin el interés del mes.
--   · EL TICKET REPARTIDO QUE LLEGA DESPUÉS DE CLASIFICAR (106):
--     fn_banco_tickets_llegados junta las partes de la misma foto (la
--     ruta, como R1) que suman el cargo: «Llegó su ticket, repartido entre
--     N obras», su botón «Es su ticket (repartido)» va primero (con todas
--     sus partes), fn_banco_duplicado(true) lo acepta y el casado nombra
--     todos sus recibos (110,111). El cuadre 57 y la conciliación lo dicen;
--     la de más de 10 días nombra el cargo aunque se haya dicho que no era
--     (p_todos). Antes cada parte era un ticket de «OTRO total» y el único
--     botón dejaba el gasto dos veces. (Y la frase «con OTRO total: (el
--     banco dice …)» ya no sale vacía en el ticket del mismo monto.)
--   · EL CHEQUE DE QUICKBOOKS QUE REBOTA (107): sin cobro en la app, R9
--     propone la factura de antes del corte (la que nombra una partida de
--     la apertura, o la del mismo monto): fn_banco_clasificar admite {la
--     cuenta por cobrar, factura_id} solo para un depósito devuelto, con
--     motivo (Dr 1110 con su partida y su obra). Antes solo entraba contra
--     el ingreso, con la factura cobrada.
--   · EL LOTE DEL PROCESADOR (108): con el procesador nombrado (QuickBooks
--     Payments, Stripe, Square), el paso 11 prueba pares y tríos de
--     facturas con su comisión dentro del tope (primero las que la app ya
--     da por cobradas).
--   · LO TRABAJADO ANTES DE LA APERTURA (109): mientras la apertura de un
--     banco no esté conciliada, la propuesta de un cheque o un depósito de
--     los primeros 30 días lo avisa (fn_banco_apertura_aviso); con la
--     apertura posteada y la cuenta en ella, clasificarlo o cobrarlo pide
--     motivo. La conciliación de apertura y las del mes cuentan como
--     dudosas (frenan) las partidas que el banco ya trajo y se casaron con
--     otra cosa, y las nombran (fn_banco_apertura_casadas);
--     fn_banco_duplicado(false, motivo) dice que no lo es, por la clave de
--     la partida (fecha, monto y cheque: fn_banco_partida_clave), que no
--     cambia cuando la conciliación de apertura se vuelve a calcular. Sin
--     la apertura posteada todavía (hoy), solo se avisa: no frena.
--   · R7 (110) no vuelve a casar lo que Edgar des-casó (como R1, R2 y R3) y
--     cede ante una partida fuerte de la apertura (la comisión del wire
--     del 30-sep): antes cada des-casar dejaba otro asiento y su reverso.
--   · EL PRIMER ESTADO DE CUENTA EN LA CUENTA EQUIVOCADA (111; es el mismo
--     hallazgo que el del grupo del importador, arreglado aquí una vez): el
--     primero de un banco entra con su aviso (el número y el banco que dice
--     el archivo); el mismo archivo pedido a otra cuenta dice «ya entró …
--     pero a 1030, no a 1010» y cómo retirarlo; un número que entró una
--     sola vez no se da por cierto; y fn_banco_archivo_retirar(archivo,
--     motivo), desde el SQL Editor, lo retira: sus movimientos quedan
--     ignorados (con rastro), sus casados se deshacen (sus asientos, por su
--     reverso), su saldo y su número dejan de contar, y el archivo vuelve
--     a entrar en la suya (el sha256 es único solo entre los vivos).
--   · LA DEVOLUCIÓN EN LA DÉBITO (112): el abono que nombra el comercio de
--     un ticket pagado desde esa cuenta propone ir contra la cuenta y la
--     obra de ese ticket («devolucion_compra»), antes que las facturas, y
--     entra sin motivo. Antes era el «pago parcial» de una factura.
--   · LA CUENTA PERSONAL DE EDGAR (113): el número del otro lado que nombra
--     el banco («TO CHK ...7781», en NAME o en la nota: fn_banco_
--     otra_cuenta) que no es de ningún estado de cuenta ni tarjeta de la
--     empresa (fn_banco_numero_de) es «transferencia_personal»: 3200 o 1130
--     (un retiro), 2900 o 3100 (un depósito, antes que las facturas). Las
--     cuentas propias van con su motivo, que fn_banco_transferencia exige
--     (fn_banco_transferencia_dudosa: el banco nombra otra cuenta, o, entre
--     dos bancos, uno que nunca trajo su estado de cuenta), y R3 no junta
--     lados cuyo número es de otra cuenta. (Por eso la 16 espera ahora
--     «transferencia_personal»: la reserva que no trajo su estado de cuenta
--     no se da por de la empresa.)
--   · LOS NOMBRES DE DOS LETRAS (114): fn_banco_nombra_alguien cuenta AT&T
--     (ATT), US o JC, y BANK o MOBILE detrás de un nombre; las de dos
--     letras del banco (TO, ID, CO, NO…) siguen sin contar.
--   · «CUADRAR EL MES» (115): v_conciliacion trae n_pide_motivo y «falta»
--     (la columna nueva conciliaciones.falta, guardada al recalcular), y
--     con un motivo por dar no está lista y su identidad lo dice.
--   · LOS BOTONES (116): las opciones de siempre que van detrás de una
--     partida de la apertura piden su motivo (fn_banco_opcion_motivo, con
--     el nombre del argumento), y la guarda de 4910 en fn_banco_clasificar
--     mira NAME y MEMO, como la propuesta. pg_temp.c6_pulsar (c6-pruebas)
--     pulsa cada opción que no pide nada, con sus argumentos tal cual.
--   · «LÍNEA 1» (117): lo que c2 rechaza al postear las líneas que escribió
--     Edgar (fn_banco_clasificar, fn_banco_nomina) dice su número, no el
--     del asiento (fn_banco_asiento_edgar), con el mismo código.
--   · LA 89 sube el estado de cuenta de la tarjeta hasta el día 40: cortado
--     el día 30, su asiento del 31 la dejaría partida y R3 ya no lo casa
--     solo (la 101).
--   · EL PEGADO ENCIMA DEL DE PRODUCCIÓN (2026092704, con datos): añade
--     las columnas conciliaciones.falta y archivos_banco.retirado_el,
--     _por, _rol y _motivo (solo si faltan), cambia el sha256 único de
--     archivos_banco por un índice único de los vivos (el mismo dato: hoy
--     ninguno está retirado), y rehace fn_banco_tickets_llegados y
--     fn_banco_tr_fecha (con otra firma; internas). Nada de lo guardado
--     cambia de cifra; las conciliaciones confirmadas no se tocan (su
--     «falta» se llena al recalcular la siguiente).
--   · EL TIEMPO: c6-pruebas, con las 17 nuevas (117), tarda 16 s en PG16
--     y 17 s en PG17.6 en el banco limpio. Con un año de banco
--     (c6-volumen.sh, PG17.6, 2-oct): casar el mes, 2,8 s como mucho (con
--     la ronda 3, 2,4 s); la bandeja 0,35 s; conciliar 0,39 s y confirmar
--     0,37 s; el control 0,43 s; volver a pegar este archivo 2,0 s;
--     fn_banco_verificar 2,9 s; c6-pruebas sola 34,7 s y con cuatro
--     teléfonos 39,0 s (la subida más lenta, 2,3 s); con los meses 13 y 14
--     sin casar, «Cuadrar» 0,65 s y 0,92 s, y casarlos 2,7 s. Todo bajo su
--     tope. La tabla de abajo es la de la ronda 3 (PG16 y PG17.6).--
-- EL TIEMPO (banco de pruebas, pruebas/conta/c6-volumen.sh, 27-sep, con
-- la ronda 3: el libro de c4-volumen, 10.333 asientos, con 2026 ya
-- cerrado —así lo deja: las pruebas corren en enero de 2027—, y 12 meses
-- de estados de cuenta de Chase, Amex Gold y Amex Blue, 9.990 movimientos
-- en 36 archivos QFX; como la app: authenticated, el dueño, los ajustes de
-- ese rol y el tope de 8 s de la API. Nueve meses con la bandeja resuelta
-- y las tres cuentas conciliadas y confirmadas, 27 conciliaciones; los
-- tres últimos sin resolver: 1.243 pendientes al final, y 13.897 asientos
-- con los del banco). En ms (el banco es un contenedor: en Supabase las
-- cifras serán otras, del mismo orden):
--                                                  PG16    PG17.6
--     importar un archivo (el más lento)            410       421
--       (uno de 3.000 movimientos, un año:          ~1.250;  antes 9.900)
--     casar el mes (la llamada más lenta; una        2167      2398
--       por mes)
--     casar otra vez con la bandeja atrasada         481       593
--       (rehace las propuestas viejas)
--       y otra vez, sin nada nuevo (no rehace        494       521
--       ninguna; antes, 2 a 5 s cada vez)
--     una llamada de la bandeja (la peor)            462       472
--     conciliar una cuenta a fin de mes (la peor)    307       324
--     confirmarla (la peor)                          307       317
--     v_banco_movimientos (el mes, las 3 cuentas)    108       134
--     v_banco_bandeja (los 1.243 pendientes)         106       125
--     v_banco_saldos                                 138       143
--     v_conciliacion / v_conciliacion_partidas     85/167    89/134
--     v_prestamos / v_prepagados                    67/122    97/108
--     v_asiento_papel (c4, el mes)                    99        96
--     fn_conciliar con la bandeja atrasada           507       461
--       otra vez (lo que no cambió no se reescribe)  355       356
--     «Cuadrar» (fn_conciliar) un mes recién         706       774
--       importado, sin casar; con dos meses         1049      1158
--       y casar con esos dos meses encima           3029      3345
--     fn_banco_control: bandeja / todo / hoy   300/522/372  325/521/404
--       (antes de la ronda 2: 634/881/782 y 746/1122/975; con lo nuevo de
--       la ronda 3 sin arreglar —el ticket de otro total buscado desde
--       cada línea de los recibos—, más de 8 s: la API lo cortaba)
--     este archivo, pegado la primera vez           1772      2411
--       y otra vez, encima de todo eso             2089      2491
--     fn_banco_verificar (SQL Editor, sin tope;     3220      3541
--       relee cada archivo fila por fila)
--     c6-pruebas.sql entera (100), encima de todo  31,5 s    36,5 s
--       (con cuatro teléfonos subiendo tickets a   36,9 s    42,1 s
--       la vez: la subida que más esperó, 2,5 s y 3,0 s)
--   (Con un año entero sin resolver nada —AL_DIA=0, 5.118 pendientes—, en
--   PG17.6 con la ronda 3: casar cada mes tarda 2,6 s como mucho; con los
--   meses 13 y 14 encima, sin casar, «Cuadrar» tarda 1,1 s con uno y 1,5 s
--   con los dos, y casarlos 4,0 s; c6-pruebas, 36,0 s. Con la ronda 2 eran
--   3,8 s, 1,1 y 1,4 s, 3,4 s y 33,3 s con 82 pruebas; antes de la ronda
--   2, con esa bandeja, cada «Casar» del mes 13 se cortaba a los 8 s
--   (57014) y no casaba nada, «Cuadrar» con dos meses sin casar también, y
--   c6-pruebas tardaba 46 s.)
-- =====================================================================
-- (Lo primero, como en c4: el pegado espera un candado como mucho medio
-- segundo. Con la app posteando o leyendo, para con 55P03 («lock
-- timeout»), no se aplica nada y se vuelve a pegar; sin esto, Postgres
-- podía cortar a la app o al pegado con 40P01. Dura lo que dura el pegado,
-- una transacción.)
set local lock_timeout = '500ms';

-- =====================================================================
-- 0 · PRECONDICIONES — solo lee. Si algo falta, no se aplica nada (el SQL
--     Editor manda todo en una petición: la primera excepción deshace el
--     pegado entero).
--   · c1 y c2 (el libro), c3 (los puentes: cobros, devoluciones,
--     proveedores, tarjetas) y c4 (v_asiento_papel con su rama para los
--     papeles de las fases de después, v_papel_fases), DE LA VERSIÓN QUE
--     ESTE ARCHIVO NECESITA: sus marcas (fn_libro_version al menos
--     2026092701; fn_puente_version y fn_estados_version al menos
--     2026092601). Con uno anterior faltan cosas de verdad (el reparto de
--     c2 que conoce las funciones de aquí y su sellador que no bendice un
--     candado cambiado, la guarda de c3 que deja des-casar un cobro, el
--     papel de los asientos del banco en c4): se dice qué volver a pegar.
--   · El libro SANO en sus huellas (el control «triggers» de c2 en verde)
--     y es_dueno(), el candado, como lo selló c2 (su huella «candado», la
--     que mira el control «permisos»): este archivo termina resellando las
--     huellas (sus funciones de la app se vigilan desde c2), y encima de
--     una guarda tocada o de un candado cambiado los bendeciría.
--   · Si ya hay una tabla con el nombre de una de este archivo, tiene que
--     ser la de este archivo.
--   · Nada AJENO colgado de las vistas de este archivo (una vista o una
--     función de otro que las lea o que devuelva su fila): al pegarlo se
--     borran y se rehacen, y se lo llevarían por delante (como c4).
-- =====================================================================
-- Lo ajeno que depende de las vistas del banco que este archivo borra y
-- rehace (una vista de Edgar o del CPA sobre v_banco_saldos, una función
-- que devuelve «setof v_conciliacion»), o nulo si no hay. Antes el pegado
-- las borraba con «drop view … cascade» y terminaba en verde: solo lo
-- decían dos NOTICE que el SQL Editor no enseña. Ahora no se toca nada y
-- se dicen (MX000), como en c4 (fn_estados_vistas_ajenas). v_papel_fases
-- no está en la lista: se rehace con «create or replace» (v_asiento_papel
-- de c4 depende de ella) y no se borra. La usan la precondición de abajo y
-- c6-pruebas.
create or replace function public.fn_banco_vistas_ajenas()
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  with c6(v) as (
    select unnest(array['v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion', 'v_conciliacion_partidas',
                        'v_prestamos', 'v_prepagados'])
  )
  select string_agg(distinct x.que, ', ')
    from (select format('la vista %s', dc.oid::regclass) as que
            from pg_depend d
            join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
            join pg_class dc on dc.oid = rw.ev_class
            join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
           where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname in (select c6.v from c6)
             and dc.oid <> cv.oid
             and not (dc.relnamespace = 'public'::regnamespace and dc.relname in (select c6.v from c6))
          union all
          select format('la función %s', f.oid::regprocedure)
            from pg_depend d
            join pg_proc f on d.classid = 'pg_proc'::regclass and f.oid = d.objid
            join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
           where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname in (select c6.v from c6)
          union all
          select format('la función %s', f.oid::regprocedure)
            from pg_depend d
            join pg_proc f on d.classid = 'pg_proc'::regclass and f.oid = d.objid
            join pg_type ty on d.refclassid = 'pg_type'::regclass and ty.oid = d.refobjid
            join pg_class cv on cv.oid = ty.typrelid
           where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname in (select c6.v from c6)) x
$$;
revoke execute on function public.fn_banco_vistas_ajenas() from public, anon, authenticated, service_role;

do $$
declare
  v_falta text := '';
  v_ok    boolean;
  v_cand  text;
  r       record;
begin
  -- c1 y c2
  if to_regclass('public.cuentas') is null or to_regclass('public.asientos') is null
     or to_regclass('public.asiento_lineas') is null or to_regclass('public.periodos') is null
     or to_regprocedure('public.fn_postear_interno(jsonb)') is null
     or to_regprocedure('public.fn_reversar_interno(uuid,text,text,jsonb)') is null
     or to_regprocedure('public.fn_libro_huellas_sellar(text)') is null
     or to_regprocedure('public.fn_libro_huellas()') is null or to_regprocedure('public.fn_libro_huellas_calcular()') is null
     or to_regprocedure('public.fn_fecha_miami(timestamptz)') is null then
    v_falta := v_falta || ' · falta el libro: pega antes c1-plan-de-cuentas.sql y c2-libro.sql';
  end if;
  -- c3
  if to_regclass('public.cobros') is null or to_regclass('public.cobros_devoluciones') is null
     or to_regclass('public.proveedores') is null or to_regclass('public.proveedores_alias') is null
     or to_regclass('public.tarjetas') is null or to_regclass('public.puente_cuentas') is null
     or to_regprocedure('public.fn_cobro_registrar(jsonb)') is null
     or to_regprocedure('public.fn_cobro_devolver(uuid,date,text,text)') is null
     or to_regprocedure('public.fn_puente_fecha(date)') is null then
    v_falta := v_falta || ' · faltan los puentes: pega antes c3-puentes.sql';
  end if;
  -- c4
  if to_regclass('public.v_asiento_papel') is null or to_regclass('public.v_papel_fases') is null then
    v_falta := v_falta || ' · faltan los estados (o son de antes de c6: sin v_papel_fases): pega antes c4-estados.sql';
  end if;
  if to_regprocedure('public.es_dueno()') is null or to_regprocedure('auth.uid()') is null then
    v_falta := v_falta || ' · faltan es_dueno() o auth.uid() (¿esto es Supabase?)';
  end if;
  -- Las marcas de versión: se leen de su texto (como hace c4), sin correrlas.
  for r in select q.fn, q.minimo, q.archivo,
                  (select substring(pp.prosrc from '([0-9]{10})')::bigint
                     from pg_proc pp where pp.oid = to_regprocedure('public.' || q.fn)) as v
             from (values ('fn_libro_version()', 2026092701::bigint, 'c2-libro.sql'),
                          ('fn_puente_version()', 2026092601::bigint, 'c3-puentes.sql'),
                          ('fn_estados_version()', 2026092601::bigint, 'c4-estados.sql')) as q(fn, minimo, archivo) loop
    if r.v is null or r.v < r.minimo then
      v_falta := v_falta || format(' · %s es de una versión anterior (%s; hace falta %s o más): vuelve a pegar %s', r.fn,
                                   coalesce(r.v::text, 'sin su marca'), r.minimo, r.archivo);
    end if;
  end loop;
  -- Las tablas de este archivo, si ya existen, son las de este archivo.
  for r in select * from (values ('banco_descriptores', 'patron'), ('archivos_banco', 'sha256'),
                                 ('movimientos_banco', 'desc_norm'), ('movimientos_banco_ids', 'id_externo'),
                                 ('banco_casados', 'deshecho_motivo'), ('banco_casado_lineas', 'casado_id'),
                                 ('conciliaciones', 'saldo_statement'), ('conciliacion_partidas', 'resuelta_en'),
                                 ('prestamos', 'prestamista'), ('prestamo_cuotas', 'saldo_antes'),
                                 ('prepagados', 'cuenta_gasto'), ('prepagados_amortizaciones', 'acumulado'),
                                 ('banco_historial', 'despues')) as v(tabla, columna)
            where to_regclass('public.' || v.tabla) is not null
              and not exists (select 1 from information_schema.columns c
                               where c.table_schema = 'public' and c.table_name = v.tabla and c.column_name = v.columna) loop
    v_falta := v_falta || format(' · ya existe una tabla public.%s que NO es la de este archivo', r.tabla);
  end loop;
  if v_falta <> '' then
    raise exception using
      errcode = 'MX000',
      message = 'c6-banco NO se aplicó, no se tocó nada. Falta lo que este archivo da por hecho:' || v_falta,
      hint    = 'El orden de pegado es c1, c2, c3, c4 y después este archivo (pruebas/conta/README.md, §0). c2, c3 y c4 se '
                'vuelven a pegar encima de sí mismos sin tocar el libro.';
  end if;

  -- El libro sano en sus huellas (ver arriba).
  select v.ok into v_ok from public.fn_verificar_cadena() v where v.control = 'triggers';
  if v_ok is distinct from true then
    raise exception using
      errcode = 'MX000',
      message = 'c6-banco NO se aplicó, no se tocó nada: las huellas del libro no son las del último pegado (control '
                'triggers de fn_verificar_cadena en rojo). Este archivo termina resellándolas, y encima de una guarda '
                'tocada la bendeciría.',
      hint    = 'Mira el detalle de select * from fn_verificar_cadena(); vuelve a pegar c2-libro.sql (y c3, c4) y después este '
                'archivo.';
  end if;
  -- Y es_dueno(), el CANDADO que dice quién ve los libros y el banco, igual
  -- que cuando se pegó c2 (su huella «candado»; c2 la vigila en su control
  -- permisos, no en triggers). Antes solo se miraba triggers: con un
  -- es_dueno() cambiado (que dejara entrar también al equipo), volver a
  -- pegar este archivo lo resellaba como bueno, el control permisos volvía a
  -- verde y el equipo leía el banco entero, con el número de la cuenta.
  select string_agg(coalesce(a.objeto, h.objeto), ', ') into v_cand
    from (select * from public.fn_libro_huellas() x where x.tipo = 'candado') h
    full join (select * from public.fn_libro_huellas_calcular() y where y.tipo = 'candado') a on a.objeto = h.objeto
   where a.md5 is distinct from h.md5;
  if v_cand is not null then
    raise exception using
      errcode = 'MX000',
      message = format('c6-banco NO se aplicó, no se tocó nada: %s cambió desde que se pegó c2-libro.sql (el candado que dice '
                       'quién ve los libros y el banco; el control permisos de fn_verificar_cadena en rojo). Este archivo '
                       'termina resellando las huellas del libro, y encima de un candado cambiado lo bendeciría.', v_cand),
      hint    = 'Revisa que es_dueno() siga diciendo «solo el dueño activo» (select pg_get_functiondef(''public.es_dueno()''::'
                'regprocedure);); si el cambio es bueno, vuelve a pegar c2-libro.sql (fija su huella nueva) y después este archivo.';
  end if;

  -- Nada ajeno colgado de las vistas de este archivo (ver arriba): si lo
  -- hay, no se toca nada y se dice qué es.
  v_cand := public.fn_banco_vistas_ajenas();
  if v_cand is not null then
    raise exception using
      errcode = 'MX000',
      message = format('c6-banco NO se aplicó, no se tocó nada: %s depende(n) de las vistas de este archivo, que al pegarlo se '
                       'borran y se rehacen (se las llevaría por delante sin avisar).', v_cand),
      hint    = 'Guarda su definición (select pg_get_viewdef(''<vista>''::regclass, true); o pg_get_functiondef), bórralas, pega '
                'este archivo y vuelve a crearlas (pruebas/conta/README.md, §0).';
  end if;

  -- La tabla de las visitas de la app (eventos) no es obligatoria: sin
  -- ella no se propone la obra de un cargo sin ticket, y se dice.
  if to_regclass('public.eventos') is null then
    raise notice 'c6: no hay tabla eventos: la bandeja del banco no propondrá la obra con visita ese día.';
  end if;
end $$;

-- La MARCA de esta versión (AAAAMMDDNN), como las de c2, c3 y c4: la fase
-- que necesite un c6 más nuevo la mira. No lee nada; nadie de la API la
-- ejecuta.
create or replace function public.fn_banco_version()
returns bigint
language sql
immutable
set search_path = public, pg_temp
as $$ select 2026100201::bigint $$;
revoke execute on function public.fn_banco_version() from public, anon, authenticated, service_role;
-- =====================================================================
-- 1 · LAS TABLAS
-- Todas nacen cerradas (el bloque fijo de docs/conta/c*.sql, en 1.9):
-- solo el dueño lee; nadie de la API escribe (todo entra por las
-- funciones de este archivo). Lo que el banco dijo no se edita; lo que
-- cambia (el estado de un movimiento, su casado, una conciliación, una
-- regla, un préstamo, un prepagado) cambia por función y deja su rastro en
-- banco_historial: quién, cuándo, antes y después.
-- Llaves uuid, sin secuencia (como los cobros de c3): c6-pruebas.sql crea
-- y deshace, y una secuencia no se deshace con el rollback.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1.1 · banco_historial — el rastro de todo lo que cambia en el banco: el
-- estado y el casado de cada movimiento, cada casado y des-casado, cada
-- conciliación y sus partidas, cada regla de descriptor, cada préstamo,
-- cuota, prepagado y amortización. Lo escriben solo sus triggers (1.8);
-- no se edita, no se borra, no se trunca.
-- ---------------------------------------------------------------------
create table if not exists public.banco_historial (
  id          uuid        primary key default gen_random_uuid(),
  tabla       text        not null,
  clave       text        not null,
  operacion   text        not null,
  cambiado_el timestamptz not null default clock_timestamp(),
  usuario_id  uuid,
  rol         text        not null,
  antes       jsonb,
  despues     jsonb,
  constraint banco_historial_operacion check (operacion in ('INSERT', 'UPDATE', 'DELETE'))
);
create index if not exists banco_historial_idx on public.banco_historial (tabla, clave, cambiado_el);

-- ---------------------------------------------------------------------
-- 1.2 · banco_descriptores — lo que se reconoce en la descripción de un
-- movimiento (NAME y MEMO, normalizados: mayúsculas, sin puntuación de
-- sobra): la nómina de Gusto, un cargo del banco, los intereses, un retiro
-- de cajero, un Zelle de Edgar, un pago de tarjeta o una transferencia, un
-- cheque devuelto. Son DATOS y no un «if» escondido en una función: los
-- archivos de verdad llegan el 16-oct y cada banco escribe distinto; Edgar
-- (o quien lo ayude) ajusta el patrón con fn_banco_descriptor, con rastro.
-- Un patrón solo NO postea: las reglas fijas (intereses → 4910, cargos →
-- 6130) piden además el tipo del banco (TRNTYPE) y el signo; lo demás
-- propone y espera a Edgar.
--   patron  expresión regular de Postgres, sin distinguir mayúsculas;
--   cuenta  la cuenta a la que va (o que se propone): 6130 los cargos,
--           4910 los intereses que paga el banco, 7100 los de la tarjeta.
-- ---------------------------------------------------------------------
create table if not exists public.banco_descriptores (
  clave        text        primary key,
  patron       text        not null,
  cuenta       text        references public.cuentas (codigo),
  para         text        not null,
  notas        text,
  cambiado_por uuid,
  cambiado_rol text,
  cambiado_el  timestamptz not null default now(),
  constraint banco_descriptores_clave check (clave in ('nomina', 'cargo_banco', 'interes', 'interes_tarjeta', 'cajero',
                                                        'zelle_edgar', 'transferencia', 'pago_tarjeta', 'pago_recibido',
                                                        'cheque_devuelto')),
  constraint banco_descriptores_patron check (btrim(patron) <> '')
);
-- (Encima de una versión anterior: la clave pago_recibido, el lado de la
-- tarjeta de su pago. Solo si falta: sin pedir el candado de la tabla
-- cuando ya está.)
do $$
begin
  if not exists (select 1 from pg_constraint k
                  where k.conrelid = 'public.banco_descriptores'::regclass and k.conname = 'banco_descriptores_clave'
                    and pg_get_constraintdef(k.oid) like '%pago_recibido%') then
    alter table public.banco_descriptores drop constraint if exists banco_descriptores_clave;
    alter table public.banco_descriptores add constraint banco_descriptores_clave
      check (clave in ('nomina', 'cargo_banco', 'interes', 'interes_tarjeta', 'cajero', 'zelle_edgar', 'transferencia', 'pago_tarjeta',
                       'pago_recibido', 'cheque_devuelto'));
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 1.3 · archivos_banco — cada archivo (o lote de filas) que entró, ENTERO:
-- su texto tal cual llegó y su sha256 (el respaldo permanente de §5.5 del
-- plan: el importador de archivo se queda para siempre). El mismo sha256
-- no se vuelve a leer. No se edita ni se borra.
--   cuenta         la cuenta del plan (1010, 1030, 2100-2013…)
--   ultimos4       los 4 últimos del número de cuenta del archivo (ACCTID)
--   formato        ofx_sgml (OFX 1.x), ofx_xml (OFX 2.x), plaid, csv, mano
--   desde, hasta   el período que dice el archivo (DTSTART, DTEND)
--   saldo, saldo_al el saldo final que trae (LEDGERBAL: BALAMT y DTASOF),
--                  TAL CUAL: en una tarjeta, lo que se debe va en negativo
--                  (el mismo signo que el libro: 2100-x es acreedora)
--   filas_leidas = filas_nuevas + filas_repetidas + filas_fuera (las
--                  pendientes de Plaid, que nunca entran)
--   duplicados_posibles  cuántas entraron marcadas «posible duplicado»
--   avisos         lo que se vio raro y no para la importación
--   cuenta_confirmada  Edgar dijo, a sabiendas, que un número de cuenta
--                  distinto del de siempre es de esta cuenta (el banco se
--                  lo cambió): sin eso, un estado de cuenta de OTRA cuenta
--                  no entra (MX004). Los archivos OFX (su ACCTID) y los
--                  confirmados son los que dicen de quién es un número.
--   retirado_el, retirado_por, retirado_rol, retirado_motivo  (ronda 4) el
--                  archivo que entró a la cuenta EQUIVOCADA (el QFX de Chase
--                  subido a la reserva): fn_banco_archivo_retirar, desde el
--                  SQL Editor, con su motivo. No se borra ni cambia lo que
--                  dijo el banco: sus movimientos quedan ignorados (con el
--                  motivo), y el archivo deja de contar para su cuenta (su
--                  saldo, su número, su sha256: se puede subir otra vez a
--                  la buena). Antes no tenía vuelta.
-- ---------------------------------------------------------------------
create table if not exists public.archivos_banco (
  id                  uuid          primary key default gen_random_uuid(),
  cuenta              text          not null references public.cuentas (codigo),
  ultimos4            text,
  nombre              text,
  formato             text          not null,
  sha256              text          not null,
  texto               text          not null,
  desde               date,
  hasta               date,
  saldo               numeric(14,2),
  saldo_al            date,
  moneda              text,
  filas_leidas        int           not null,
  filas_nuevas        int           not null,
  filas_repetidas     int           not null,
  filas_fuera         int           not null default 0,
  duplicados_posibles int           not null default 0,
  avisos              jsonb         not null default '[]'::jsonb,
  importado_por       uuid,
  importado_rol       text          not null default current_user,
  importado_el        timestamptz   not null default now(),
  constraint archivos_banco_sha_forma check (sha256 ~ '^[0-9a-f]{64}$'),
  constraint archivos_banco_formato   check (formato in ('ofx_sgml', 'ofx_xml', 'plaid', 'csv', 'mano')),
  constraint archivos_banco_filas     check (filas_leidas = filas_nuevas + filas_repetidas + filas_fuera
                                             and filas_nuevas >= 0 and filas_repetidas >= 0 and filas_fuera >= 0),
  constraint archivos_banco_avisos    check (jsonb_typeof(avisos) = 'array')
);
create index if not exists archivos_banco_cuenta_idx on public.archivos_banco (cuenta, saldo_al);
-- (Columnas nuevas de esta versión: encima de una anterior se añaden, y
-- solo si faltan, sin pedir el candado de la tabla cuando ya están.)
do $$
begin
  if not exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = 'archivos_banco' and c.column_name = 'cuenta_confirmada') then
    alter table public.archivos_banco add column cuenta_confirmada boolean not null default false;
  end if;
  -- (Ronda 4: el archivo retirado, y su sha256 único solo entre los vivos:
  -- el que entró a la cuenta equivocada se sube otra vez a la buena.)
  if not exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = 'archivos_banco' and c.column_name = 'retirado_el') then
    alter table public.archivos_banco add column retirado_el timestamptz, add column retirado_por uuid,
                                      add column retirado_rol text, add column retirado_motivo text;
  end if;
  if exists (select 1 from pg_constraint k where k.conrelid = 'public.archivos_banco'::regclass and k.conname = 'archivos_banco_sha_unico') then
    alter table public.archivos_banco drop constraint archivos_banco_sha_unico;
  end if;
end $$;
create unique index if not exists archivos_banco_sha_vivo on public.archivos_banco (sha256) where retirado_el is null;

-- ---------------------------------------------------------------------
-- 1.4 · movimientos_banco — UNO por movimiento del banco o de la tarjeta,
-- como lo dijo el banco. Lo que el banco dijo NO cambia (UPDATE o DELETE:
-- MX003); cambian solo su estado y su casado, por función y con rastro.
--   fecha              la fecha contable del banco (DTPOSTED; la de Plaid)
--   fecha_transaccion  la de la compra, si viene (DTUSER)
--   periodo            'AAAA-MM' de fecha (por aquí filtran las vistas)
--   monto              CON EL SIGNO DEL BANCO: negativo sale, positivo
--                      entra. En una tarjeta: negativo = cargo, positivo =
--                      pago o abono. Es también el signo de su línea en el
--                      libro (en 1010 un depósito es debe; en 2100-x un
--                      cargo es haber): la línea del asiento en la cuenta
--                      del movimiento tiene su mismo monto.
--   tipo_banco, cheque, descripcion, memo: TRNTYPE, CHECKNUM, NAME y MEMO
--                      tal cual (las entidades como &amp; ya resueltas)
--   desc_norm          la descripción normalizada (la llave y las reglas)
--   origen, id_externo por dónde entró (archivo, plaid, csv, mano) y con
--                      qué id (FITID, el id de Plaid): todos sus ids, en
--                      movimientos_banco_ids
--   llave              la llave determinista: md5 de cuenta, fecha, monto,
--                      descripción normalizada y n, la ocurrencia de esos
--                      cuatro entre los movimientos iguales (dos cafés
--                      iguales el mismo día son 1 y 2). Única por cuenta.
--   archivo_id, fila   de qué archivo y en qué lugar
--   posible_duplicado_de  entró con otro id pero parece ese movimiento
--                      (misma cuenta y monto, fechas a 3 días o menos, otra
--                      descripción): espera a que Edgar diga si es el
--                      mismo (fn_banco_duplicado), nunca en silencio
--   estado             pendiente (espera, con su motivo y su propuesta),
--                      casado (con su papel o su asiento), en_transito
--                      (casado con una transferencia cuyo otro lado
--                      todavía no llegó) o ignorado (con su motivo: en
--                      cero, de antes del corte, un duplicado confirmado,
--                      lo que no es de la empresa)
--   casado_*           el casado vigente (banco_casados), repetido aquí para
--                      leerlo de una vez: clase, referencia, asiento, regla,
--                      si fue automático, quién y cuándo
--   sello              el md5 de lo que dijo el banco (sus campos, su llave,
--                      su archivo y su fila, y el sha256 del archivo), puesto
--                      al entrar (fn_banco_sello). Lo que no se puede
--                      impedir se detecta: un movimiento cambiado con las
--                      guardas apagadas ya no da su sello, y el control lo
--                      dice en rojo en el período que pinta (y
--                      fn_banco_verificar lo compara, además, con su archivo
--                      fila por fila: también lo que se borró)
-- ---------------------------------------------------------------------
create table if not exists public.movimientos_banco (
  id                   uuid          primary key default gen_random_uuid(),
  cuenta               text          not null references public.cuentas (codigo),
  ultimos4             text,
  fecha                date          not null,
  fecha_transaccion    date,
  periodo              text          generated always as
                                       (lpad(extract(year from fecha)::int::text, 4, '0') || '-'
                                        || lpad(extract(month from fecha)::int::text, 2, '0')) stored,
  monto                numeric(14,2) not null,
  tipo_banco           text,
  cheque               text,
  descripcion          text,
  memo                 text,
  desc_norm            text          not null,
  origen               text          not null,
  id_externo           text,
  llave                text          not null,
  archivo_id           uuid          not null references public.archivos_banco (id),
  fila                 int           not null,
  posible_duplicado_de uuid          references public.movimientos_banco (id),
  importado_el         timestamptz   not null default now(),
  estado               text          not null default 'pendiente',
  estado_motivo        text,
  propuesta            jsonb,
  duplicado            text,
  casado_id            uuid,
  casado_clase         text,
  casado_ref           text,
  asiento_id           uuid          references public.asientos (id),
  casado_regla         text,
  casado_auto          boolean,
  casado_por           uuid,
  casado_el            timestamptz,
  cambiado_el          timestamptz,
  sello                text,
  constraint movimientos_banco_origen   check (origen in ('archivo', 'plaid', 'csv', 'mano')),
  constraint movimientos_banco_estado   check (estado in ('pendiente', 'casado', 'en_transito', 'ignorado')),
  constraint movimientos_banco_casado   check ((estado in ('casado', 'en_transito')) = (casado_id is not null)),
  constraint movimientos_banco_ignorado check (estado <> 'ignorado' or coalesce(btrim(estado_motivo), '') <> ''),
  constraint movimientos_banco_duplicado check (duplicado is null or duplicado in ('es_el_mismo', 'no_es_el_mismo')),
  constraint movimientos_banco_fila     check (fila >= 1)
);
-- (Encima de una versión anterior: el sello; los que ya estaban se sellan
-- más abajo, con la guarda puesta.)
do $$
begin
  if not exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = 'movimientos_banco' and c.column_name = 'sello') then
    alter table public.movimientos_banco add column sello text;
  end if;
end $$;
-- (La llave única es la llave sola: ya lleva la cuenta dentro, en su md5.
-- Con la cuenta delante, y la tabla «vacía» para el planificador —las
-- estadísticas de después de un rollback grande, como los de las
-- pruebas—, cada búsqueda por fila del importador elegía este índice por
-- la cuenta sola y recorría la cuenta entera: un archivo de 3.000 después
-- de otros tardaba de 3 a 12 s en vez de 1,5, y la prueba 53 salía en rojo
-- al correr c6-pruebas dos veces seguidas. Si ya estaba con la cuenta, se
-- rehace una vez.)
do $$
begin
  if coalesce(pg_get_indexdef(to_regclass('public.movimientos_banco_llave_unica')) !~ '[(]llave[)]$', false) then
    drop index public.movimientos_banco_llave_unica;
  end if;
end $$;
create unique index if not exists movimientos_banco_llave_unica on public.movimientos_banco (llave);
create index if not exists movimientos_banco_cuenta_fecha_idx on public.movimientos_banco (cuenta, fecha, monto);
create index if not exists movimientos_banco_periodo_idx      on public.movimientos_banco (periodo);
create index if not exists movimientos_banco_pendientes_idx   on public.movimientos_banco (cuenta, fecha) where estado = 'pendiente';
create index if not exists movimientos_banco_archivo_idx      on public.movimientos_banco (archivo_id);
create index if not exists movimientos_banco_asiento_idx      on public.movimientos_banco (asiento_id) where asiento_id is not null;
create index if not exists movimientos_banco_duplicado_idx    on public.movimientos_banco (posible_duplicado_de)
  where posible_duplicado_de is not null;
-- (Del asiento a su movimiento: v_papel_fases busca el papel por el texto
-- de asientos.origen_id.)
create index if not exists movimientos_banco_id_texto_idx     on public.movimientos_banco ((id::text));

-- ---------------------------------------------------------------------
-- 1.5 · movimientos_banco_ids — cada id con que el banco (o Plaid) nombró
-- a un movimiento: el FITID del archivo, el id de Plaid. El mismo
-- movimiento visto por archivo y por Plaid tiene dos, y entró UNA vez.
-- Único por cuenta, origen e id: el mismo id otra vez es el mismo
-- movimiento (el archivo importado dos veces, o dos que se solapan). No
-- se edita ni se borra.
-- ---------------------------------------------------------------------
create table if not exists public.movimientos_banco_ids (
  cuenta        text        not null,
  origen        text        not null,
  id_externo    text        not null,
  movimiento_id uuid        not null references public.movimientos_banco (id),
  archivo_id    uuid        not null references public.archivos_banco (id),
  visto_el      timestamptz not null default now(),
  constraint movimientos_banco_ids_pk primary key (cuenta, origen, id_externo),
  constraint movimientos_banco_ids_origen check (origen in ('archivo', 'plaid', 'csv', 'mano'))
);
create index if not exists movimientos_banco_ids_mov_idx on public.movimientos_banco_ids (movimiento_id);

-- ---------------------------------------------------------------------
-- 1.6 · banco_casados — cada vez que un movimiento se casa con lo que lo
-- explica en el libro, y cada vez que se des-casa (la misma fila, cerrada
-- con su motivo). Uno VIVO por movimiento.
--   clase       recibo (el ticket que ya entró por c3), cobro, devolucion
--               (un cheque devuelto, c3), transferencia (el mismo dinero
--               en dos cuentas propias: un asiento), pago_proveedor,
--               cuota_prestamo, regla (4910, 6130: las fijas), clasificado
--               (lo que Edgar clasificó), asiento (una línea que ya estaba
--               en el libro: un asiento a mano, la nómina de f11),
--               apertura (una partida en tránsito de la era QuickBooks, de
--               la conciliación de apertura: sin asiento propio)
--   referencia  el papel: el id del recibo, del cobro, de la devolución,
--               del proveedor, de la cuota, la partida de la apertura…
--   asiento_id  el asiento (nulo solo en la clase apertura)
--   posteado    true si ESTE casado posteó su asiento (transferencia,
--               pago a proveedor, cuota, regla, clasificado): al
--               des-casar se reversa (fn_reversar_interno, con el motivo,
--               y queda enlazado en reverso_id). Los demás (el ticket, el
--               cobro, la devolución, un asiento que ya estaba) solo se
--               sueltan: su asiento es de su papel.
--   regla       por qué regla (R1…R10, o «Edgar eligió») y automatico
-- Las líneas del libro que casa, en banco_casado_lineas.
-- ---------------------------------------------------------------------
create table if not exists public.banco_casados (
  id              uuid        primary key default gen_random_uuid(),
  movimiento_id   uuid        not null references public.movimientos_banco (id),
  clase           text        not null,
  referencia      text,
  asiento_id      uuid        references public.asientos (id),
  posteado        boolean     not null default false,
  regla           text        not null,
  automatico      boolean     not null,
  motivo          text,
  casado_por      uuid,
  casado_rol      text,
  casado_el       timestamptz,
  deshecho_el     timestamptz,
  deshecho_por    uuid,
  deshecho_rol    text,
  deshecho_motivo text,
  reverso_id      uuid        references public.asientos (id),
  constraint banco_casados_clase    check (clase in ('recibo', 'cobro', 'devolucion', 'transferencia', 'pago_proveedor',
                                                     'cuota_prestamo', 'regla', 'clasificado', 'asiento', 'apertura')),
  constraint banco_casados_asiento  check ((clase = 'apertura') = (asiento_id is null)),
  constraint banco_casados_deshecho check ((deshecho_el is null) = (deshecho_motivo is null)
                                           and (deshecho_motivo is null or btrim(deshecho_motivo) <> ''))
);
create unique index if not exists banco_casados_vivo_unico on public.banco_casados (movimiento_id) where deshecho_el is null;
create index if not exists banco_casados_asiento_idx on public.banco_casados (asiento_id) where asiento_id is not null;
create index if not exists banco_casados_mov_idx on public.banco_casados (movimiento_id);

-- ---------------------------------------------------------------------
-- 1.7 · banco_casado_lineas — las líneas del libro que explica cada
-- casado: su suma es el monto del movimiento (con su signo), y todas son
-- de la cuenta del movimiento. Una línea del libro casa con UN movimiento
-- vivo (índice único): el mismo ticket no paga dos cargos.
-- ---------------------------------------------------------------------
create table if not exists public.banco_casado_lineas (
  casado_id  uuid          not null references public.banco_casados (id),
  asiento_id uuid          not null,
  orden      int           not null,
  cuenta     text          not null,
  monto      numeric(14,2) not null,
  vigente    boolean       not null default true,
  constraint banco_casado_lineas_pk primary key (casado_id, asiento_id, orden),
  constraint banco_casado_lineas_linea foreign key (asiento_id, orden) references public.asiento_lineas (asiento_id, orden)
);
create unique index if not exists banco_casado_lineas_viva_unica on public.banco_casado_lineas (asiento_id, orden) where vigente;

-- ---------------------------------------------------------------------
-- 1.8 · conciliaciones y conciliacion_partidas — la conciliación de
-- verdad, no la igualdad (f06): saldo en libros = saldo del statement +
-- depósitos en tránsito − cargos en circulación. Una por cuenta y fecha
-- de corte (un banco, a fin de mes; una tarjeta, a su fecha de corte).
--   saldo_statement  el que escribe Edgar, COMO LO DICE EL STATEMENT: en
--                    un banco, lo que hay; en una tarjeta, lo que se debe
--                    (en positivo)
--   saldo_archivo    el del archivo con saldo a esa misma fecha (LEDGERBAL,
--                    pasado a la forma del statement); si los dos están y
--                    no dicen lo mismo, se dice
--   saldo_banco      el que vale, con el signo del libro (en una tarjeta,
--                    lo que se debe en negativo)
--   saldo_libros     las líneas de la cuenta hasta la fecha de corte
--   depositos_transito, cargos_circulacion  lo que está en el libro y el
--                    banco todavía no trae (en positivo los dos)
--   sin_casar_banco  lo que el banco trae y el libro no (con su signo):
--                    BLOQUEA la confirmación
--   diferencia       saldo_libros − (saldo_banco + depósitos en tránsito −
--                    cargos en circulación − sin_casar_banco): 0.00 para
--                    confirmar
--   estado           abierta (se recalcula con fn_conciliar) o confirmada
--                    (no se toca; reabrir con motivo deja rastro)
--   hash_partidas    el sha256 de sus partidas al confirmar
--   tipo             normal, o apertura (la del 30-sep, con las partidas
--                    en tránsito de la era QuickBooks escritas a mano)
-- Las partidas son lo que no casa a esa fecha: del lado del libro (una
-- línea sin su movimiento, o una partida de la apertura todavía sin
-- llegar), con su clase (depósito en tránsito, cheque o cargo en
-- circulación, error) y su motivo; y del lado del banco (un movimiento sin
-- su línea), que BLOQUEA. Dos clases más: del lado del libro,
-- «posible_duplicado» (un ticket que llegó después de clasificar su
-- cargo: el gasto estaría dos veces; BLOQUEA hasta que se resuelva o
-- Edgar diga con su motivo que es otra compra), y del lado del banco,
-- «en_libros_despues» (un movimiento casado con el asiento de un papel de
-- ANTES del corte que se contabilizó el día 1 del mes siguiente porque su
-- mes estaba cerrado: explicado, no bloquea). Cuando el banco por fin
-- trae la del libro, la partida dice en qué conciliación y con qué
-- movimiento (resuelta_*).
--   n_dudosas  cuántas partidas «posible_duplicado» tiene (bloquean)
--   saldo_motivo, saldo_documento  por qué vale el saldo que escribió
--              Edgar cuando el archivo del banco dice OTRO a esa misma
--              fecha, y con qué documento (el PDF del statement): sin los
--              dos, no se confirma (fn_conciliacion_saldo, desde el SQL
--              Editor). Antes bastaba con teclear el saldo de libros para
--              «cuadrar» un mes que el banco no cuadraba, y quedaba un aviso
--              que nadie leía
--   n_pide_motivo  cuántas cosas piden todavía su motivo escrito antes de
--              confirmar: el saldo de arriba, y cada partida de la
--              conciliación de apertura que lleva más de 30 días sin llegar
--              (fn_conciliacion_partida). Bloquean, como n_dudosas
--   falta      lo que falta para confirmarla, en palabras (lo mismo que
--              devuelve fn_conciliar), guardado al recalcularla: la
--              pantalla lo lee de v_conciliacion (ronda 4)
-- ---------------------------------------------------------------------
create table if not exists public.conciliaciones (
  id                  uuid          primary key default gen_random_uuid(),
  cuenta              text          not null references public.cuentas (codigo),
  fecha_corte         date          not null,
  tipo                text          not null default 'normal',
  saldo_statement     numeric(14,2),
  saldo_archivo       numeric(14,2),
  archivo_id          uuid          references public.archivos_banco (id),
  saldo_banco         numeric(14,2),
  saldo_libros        numeric(14,2),
  depositos_transito  numeric(14,2),
  cargos_circulacion  numeric(14,2),
  sin_casar_banco     numeric(14,2),
  n_sin_casar         int,
  n_transito          int,
  n_alarmas           int,
  n_dudosas           int,
  diferencia          numeric(14,2),
  estado              text          not null default 'abierta',
  motivo              text,
  calculada_el        timestamptz,
  creada_por          uuid,
  creada_rol          text,
  creada_el           timestamptz,
  confirmada_por      uuid,
  confirmada_rol      text,
  confirmada_el       timestamptz,
  hash_partidas       text,
  reabierta_por       uuid,
  reabierta_rol       text,
  reabierta_el        timestamptz,
  reabierta_motivo    text,
  constraint conciliaciones_unica  unique (cuenta, fecha_corte),
  constraint conciliaciones_tipo   check (tipo in ('normal', 'apertura')),
  constraint conciliaciones_estado check (estado in ('abierta', 'confirmada')),
  constraint conciliaciones_confirmada check (estado <> 'confirmada'
                                              or (confirmada_el is not null and hash_partidas is not null and diferencia = 0))
);

create table if not exists public.conciliacion_partidas (
  id                     uuid          primary key default gen_random_uuid(),
  conciliacion_id        uuid          not null references public.conciliaciones (id),
  lado                   text          not null,
  clase                  text          not null,
  asiento_id             uuid          references public.asientos (id),
  orden                  int,
  movimiento_id          uuid          references public.movimientos_banco (id),
  apertura_partida_id    uuid          references public.conciliacion_partidas (id),
  fecha                  date          not null,
  monto                  numeric(14,2) not null,
  descripcion            text,
  cheque                 text,
  motivo                 text,
  dias                   int,
  alarma                 boolean       not null default false,
  explicacion            text,
  pareja                 jsonb,
  resuelta_en            uuid          references public.conciliaciones (id),
  resuelta_por_movimiento uuid         references public.movimientos_banco (id),
  resuelta_el            timestamptz,
  constraint conciliacion_partidas_lado  check (lado in ('libro', 'banco')),
  constraint conciliacion_partidas_clase check (clase in ('deposito_en_transito', 'cargo_en_circulacion', 'error', 'posible_duplicado',
                                                          'sin_casar', 'en_libros_despues')),
  constraint conciliacion_partidas_forma check ((lado = 'banco') = (clase in ('sin_casar', 'en_libros_despues'))
                                                and (lado <> 'banco' or movimiento_id is not null)),
  constraint conciliacion_partidas_monto check (monto <> 0)
);
-- (Encima de una versión anterior: las dos clases nuevas en sus reglas, y
-- la cuenta de las dudosas. Solo si faltan: sin pedir el candado de la
-- tabla cuando ya están.)
do $$
begin
  if not exists (select 1 from pg_constraint k
                  where k.conrelid = 'public.conciliacion_partidas'::regclass and k.conname = 'conciliacion_partidas_clase'
                    and pg_get_constraintdef(k.oid) like '%en_libros_despues%') then
    alter table public.conciliacion_partidas drop constraint if exists conciliacion_partidas_clase;
    alter table public.conciliacion_partidas add constraint conciliacion_partidas_clase
      check (clase in ('deposito_en_transito', 'cargo_en_circulacion', 'error', 'posible_duplicado', 'sin_casar', 'en_libros_despues'));
  end if;
  if not exists (select 1 from pg_constraint k
                  where k.conrelid = 'public.conciliacion_partidas'::regclass and k.conname = 'conciliacion_partidas_forma'
                    and pg_get_constraintdef(k.oid) like '%en_libros_despues%') then
    alter table public.conciliacion_partidas drop constraint if exists conciliacion_partidas_forma;
    alter table public.conciliacion_partidas add constraint conciliacion_partidas_forma
      check ((lado = 'banco') = (clase in ('sin_casar', 'en_libros_despues')) and (lado <> 'banco' or movimiento_id is not null));
  end if;
  if not exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = 'conciliaciones' and c.column_name = 'n_dudosas') then
    alter table public.conciliaciones add column n_dudosas int;
  end if;
  -- (Esta versión: el saldo del statement que no dice lo mismo que el
  -- archivo del banco vale solo con su motivo y su documento, y cuántas
  -- cosas de la conciliación piden todavía su motivo; ver 6.)
  if not exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = 'conciliaciones' and c.column_name = 'saldo_motivo') then
    alter table public.conciliaciones add column saldo_motivo text;
  end if;
  if not exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = 'conciliaciones' and c.column_name = 'saldo_documento') then
    alter table public.conciliaciones add column saldo_documento text;
  end if;
  if not exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = 'conciliaciones' and c.column_name = 'n_pide_motivo') then
    alter table public.conciliaciones add column n_pide_motivo int;
  end if;
  -- (Ronda 4: lo que falta para confirmarla, en palabras, como lo dice
  -- fn_conciliar: v_conciliacion lo enseña. Nula en las de antes hasta que
  -- se recalculen; una confirmada no se toca.)
  if not exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = 'conciliaciones' and c.column_name = 'falta') then
    alter table public.conciliaciones add column falta text;
  end if;
end $$;
create index if not exists conciliacion_partidas_conc_idx  on public.conciliacion_partidas (conciliacion_id);
create index if not exists conciliacion_partidas_linea_idx on public.conciliacion_partidas (asiento_id, orden) where asiento_id is not null;
create index if not exists conciliacion_partidas_mov_idx   on public.conciliacion_partidas (movimiento_id) where movimiento_id is not null;
-- (La llave foránea a la partida de la apertura: al recalcular se borran
-- partidas, y sin este índice cada borrado recorría la tabla entera.)
create index if not exists conciliacion_partidas_ap_idx    on public.conciliacion_partidas (apertura_partida_id)
  where apertura_partida_id is not null;

-- ---------------------------------------------------------------------
-- 1.9 · prestamos y prestamo_cuotas.
--   tasa_anual   en por ciento (6.99 = 6,99 % al año)
--   cuenta       donde baja el capital de cada cuota (2520, la porción
--                corriente); cuenta_largo, la de largo plazo (2530): el
--                reparto entre las dos (lo que vence en los próximos 12
--                meses) lo enseña v_prestamos y lo postea el cierre (f08)
--   saldo_inicial, saldo_inicial_al  lo que se debía al empezar el libro
--                (el statement al 30-sep; o el principal, si el préstamo
--                es posterior)
--   descriptor   expresión regular para reconocer su pago en el banco
-- Cada cuota es un papel (prestamo_cuotas): su fecha, lo pagado, la
-- partición capital/interés y de dónde salió (la fórmula, o el statement
-- del prestamista, que manda), el saldo antes y después, y su asiento. Una
-- cuota no se edita: se anula (des-casando su movimiento) y se registra
-- la buena.
-- ---------------------------------------------------------------------
create table if not exists public.prestamos (
  id               uuid          primary key default gen_random_uuid(),
  prestamista      text          not null,
  descripcion      text,
  principal        numeric(14,2) not null,
  tasa_anual       numeric(8,4)  not null,
  cuota            numeric(14,2) not null,
  primer_pago      date          not null,
  dia_pago         int           not null,
  plazo_meses      int,
  cuenta           text          not null references public.cuentas (codigo),
  cuenta_largo     text          references public.cuentas (codigo),
  cuenta_interes   text          not null references public.cuentas (codigo),
  cuenta_banco     text          not null references public.cuentas (codigo),
  saldo_inicial    numeric(14,2) not null,
  saldo_inicial_al date          not null,
  descriptor       text,
  estado           text          not null default 'vigente',
  notas            text,
  creado_por       uuid,
  creado_rol       text,
  creado_el        timestamptz   not null default now(),
  cambiado_el      timestamptz,
  constraint prestamos_prestamista check (btrim(prestamista) <> ''),
  constraint prestamos_montos      check (principal > 0 and cuota > 0 and saldo_inicial >= 0 and saldo_inicial <= principal
                                          and tasa_anual >= 0 and tasa_anual < 100),
  constraint prestamos_dia         check (dia_pago between 1 and 31),
  constraint prestamos_plazo       check (plazo_meses is null or plazo_meses > 0),
  constraint prestamos_estado      check (estado in ('vigente', 'pagado', 'cancelado'))
);

create table if not exists public.prestamo_cuotas (
  id             uuid          primary key default gen_random_uuid(),
  prestamo_id    uuid          not null references public.prestamos (id),
  fecha          date          not null,
  monto          numeric(14,2) not null,
  capital        numeric(14,2) not null,
  interes        numeric(14,2) not null,
  fuente         text          not null,
  formula        jsonb,
  saldo_antes    numeric(14,2) not null,
  saldo_despues  numeric(14,2) not null,
  movimiento_id  uuid          references public.movimientos_banco (id),
  asiento_id     uuid          references public.asientos (id),
  motivo         text,
  anulada_el     timestamptz,
  anulada_por    uuid,
  anulada_motivo text,
  creado_por     uuid,
  creado_rol     text,
  creado_el      timestamptz   not null default now(),
  constraint prestamo_cuotas_montos check (monto > 0 and capital >= 0 and interes >= 0 and capital + interes = monto
                                           and saldo_despues = saldo_antes - capital and saldo_despues >= 0),
  constraint prestamo_cuotas_fuente check (fuente in ('formula', 'statement')),
  constraint prestamo_cuotas_anulada check ((anulada_el is null) = (anulada_motivo is null))
);
create index if not exists prestamo_cuotas_prestamo_idx on public.prestamo_cuotas (prestamo_id, fecha);
create unique index if not exists prestamo_cuotas_movimiento_unico on public.prestamo_cuotas (movimiento_id)
  where movimiento_id is not null and anulada_el is null;

-- ---------------------------------------------------------------------
-- 1.10 · prepagados y prepagados_amortizaciones — un seguro o una fianza
-- pagados por adelantado (1410, 1420), que se van al gasto día por día de
-- su cobertura (desde, hasta, ambos incluidos). La prima de WC va a 5015
-- (el burden real, sin obra, c1); GL, auto y sombrilla a 6200; una fianza
-- de una obra, al costo de esa obra. papel_tabla, papel_id: de dónde salió
-- (el recibo, la factura del proveedor o el asiento que la compró).
-- Cada mes amortizado queda en prepagados_amortizaciones: cuánto de cada
-- póliza y en qué asiento. Lo de antes del corte (una póliza del 1-ago)
-- ya lo amortizó QuickBooks: el libro empieza con lo que falta y amortiza
-- desde octubre.
--   saldo_corte  lo que la póliza tenía POR AMORTIZAR al corte: lo que la
--                balanza de QuickBooks dejó en 1410/1420 para ella (el
--                número de la apertura, no uno calculado: QuickBooks suele
--                amortizar 1/12 al mes con un asiento recurrente, no por
--                días). Obligatorio en una póliza que empezó antes del
--                corte; el libro amortiza ESO, día por día, del corte a su
--                fin, y el último día todo lo que falta: 1410 queda en cero
--                al vencer. Si se corrige el monto de la póliza, la
--                diferencia va a lo que falta por amortizar (lo de
--                QuickBooks ya pasó).
-- ---------------------------------------------------------------------
create table if not exists public.prepagados (
  id           uuid          primary key default gen_random_uuid(),
  descripcion  text          not null,
  tipo         text          not null,
  cuenta       text          not null references public.cuentas (codigo),
  cuenta_gasto text          not null references public.cuentas (codigo),
  proyecto_id  text          references public.proyectos (id),
  cost_code    text,
  monto        numeric(14,2) not null,
  desde        date          not null,
  hasta        date          not null,
  saldo_corte  numeric(14,2),
  papel_tabla  text,
  papel_id     text,
  estado       text          not null default 'vigente',
  notas        text,
  creado_por   uuid,
  creado_rol   text,
  creado_el    timestamptz   not null default now(),
  cambiado_el  timestamptz,
  constraint prepagados_descripcion check (btrim(descripcion) <> ''),
  constraint prepagados_tipo        check (tipo in ('seguro', 'fianza', 'otro')),
  constraint prepagados_monto       check (monto > 0),
  constraint prepagados_fechas      check (hasta >= desde),
  constraint prepagados_estado      check (estado in ('vigente', 'cancelado')),
  constraint prepagados_papel       check ((papel_tabla is null) = (papel_id is null)),
  constraint prepagados_saldo_corte check (saldo_corte is null or (saldo_corte >= 0 and saldo_corte <= monto))
);
do $$
begin
  if not exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = 'prepagados' and c.column_name = 'saldo_corte') then
    alter table public.prepagados add column saldo_corte numeric(14,2);
    alter table public.prepagados add constraint prepagados_saldo_corte
      check (saldo_corte is null or (saldo_corte >= 0 and saldo_corte <= monto));
  end if;
end $$;
-- (ronda 3) LA PÓLIZA QUE SE CANCELA, con su camino:
--   sustituida_por  la póliza que la SUSTITUYE (la misma, corregida: otra
--                   cuenta de gasto, otra obra). Lo que llevaba amortizado
--                   vuelve a su cuenta en el mes abierto, y la nueva lo
--                   amortiza por acumulado desde su inicio, a sus cuentas.
--                   Antes «cancélalo y registra otro» amortizaba dos veces
--                   los meses ya amortizados (1410 acababa en negativo).
--   cancelado_al,   la cancelación de verdad: la fecha, y lo que devolvió
--   devuelto        la aseguradora (el depósito se clasifica a 1410/1420).
--                   Hasta esa fecha se amortiza por días; ese día, todo lo
--                   que queda menos lo devuelto (el uso y la penalidad) va
--                   al gasto, y la póliza queda en cero. Antes lo que
--                   quedaba se quedaba en 1410 para siempre.
alter table public.prepagados add column if not exists sustituida_por uuid references public.prepagados (id);
alter table public.prepagados add column if not exists cancelado_al date;
alter table public.prepagados add column if not exists devuelto numeric(14,2);
do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.prepagados'::regclass and conname = 'prepagados_cancelacion') then
    alter table public.prepagados add constraint prepagados_cancelacion
      check ((estado = 'cancelado' or (sustituida_por is null and cancelado_al is null and devuelto is null))
             and (devuelto is null or devuelto >= 0) and (sustituida_por is distinct from id)
             and (devuelto is null or cancelado_al is not null));
  end if;
end $$;

create table if not exists public.prepagados_amortizaciones (
  id           uuid          primary key default gen_random_uuid(),
  prepagado_id uuid          not null references public.prepagados (id),
  periodo      text          not null references public.periodos (periodo),
  grupo        text          not null,
  monto        numeric(14,2) not null,
  acumulado    numeric(14,2) not null,
  asiento_id   uuid          not null references public.asientos (id),
  vigente      boolean       not null default true,
  creado_el    timestamptz   not null default now(),
  constraint prepagados_amortizaciones_grupo check (grupo in ('general', 'mano_de_obra')),
  constraint prepagados_amortizaciones_monto check (monto <> 0)
);
create index if not exists prepagados_amortizaciones_prep_idx on public.prepagados_amortizaciones (prepagado_id, periodo);
create unique index if not exists prepagados_amortizaciones_viva_unica on public.prepagados_amortizaciones (prepagado_id, periodo)
  where vigente;
-- ---------------------------------------------------------------------
-- 1.11 · Las guardas, quién y cuándo, y el historial. TRIGGERS y no
-- policies: una policy no frena al SQL Editor; un trigger sí.
-- Las funciones de este archivo escriben con una MARCA en la sesión
-- (mx_banco.escribe = 'movimiento:<id>', 'casar:<id>'…, solo dentro de su
-- transacción): la guarda deja pasar lo que lleva la marca de esa fila y
-- nada más. Un UPDATE escrito a mano desde el SQL Editor (sin la marca) no
-- entra: MX003. (El dueño de la base puede poner la marca a mano: ninguna
-- base se defiende de su dueño; lo que haga queda en banco_historial.)
-- ---------------------------------------------------------------------

-- Solo el dueño (o el SQL Editor).
create or replace function public.fn_banco_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'El banco lo ve y lo toca solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_banco_exigir_dueno() from public, anon, authenticated, service_role;

-- La marca de la escritura (ver arriba). Nula = sin marca.
create or replace function public.fn_banco_marca(p text) returns void
language sql volatile
set search_path = public, pg_temp
as $$ select set_config('mx_banco.escribe', coalesce(p, ''), true) $$;
revoke execute on function public.fn_banco_marca(text) from public, anon, authenticated, service_role;

-- EL SELLO de un movimiento: el md5 de lo que dijo el banco, con el sha256
-- de su archivo (la misma fórmula la repite, escrita, fn_banco_control: la
-- app no ejecuta las funciones internas).
create or replace function public.fn_banco_sello(p_cuenta text, p_ultimos4 text, p_fecha date, p_ftx date, p_monto numeric, p_tipo text,
                                                 p_cheque text, p_desc text, p_memo text, p_origen text, p_ext text, p_llave text,
                                                 p_archivo uuid, p_fila int, p_sha text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select md5(array_to_string(array[p_cuenta, p_ultimos4, to_char(p_fecha, 'YYYY-MM-DD'), to_char(p_ftx, 'YYYY-MM-DD'), p_monto::text,
                                   p_tipo, p_cheque, p_desc, p_memo, p_origen, p_ext, p_llave, p_archivo::text, p_fila::text, p_sha],
                             '|', '∅'))
$$;
revoke execute on function public.fn_banco_sello(text, text, date, date, numeric, text, text, text, text, text, text, text, uuid, int, text)
  from public, anon, authenticated, service_role;

create or replace function public.fn_banco_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_marca text := coalesce(current_setting('mx_banco.escribe', true), '');
  v_mov   uuid;
  v_c     conciliaciones;
  v_l     asiento_lineas;
  -- Lo que cambia de un movimiento (el resto es lo que dijo el banco).
  -- «periodo» es generada: en un trigger BEFORE todavía no está calculada.
  c_mov   constant text[] := array['estado', 'estado_motivo', 'propuesta', 'duplicado', 'casado_id', 'casado_clase',
                                   'casado_ref', 'asiento_id', 'casado_regla', 'casado_auto', 'casado_por', 'casado_el',
                                   'cambiado_el', 'periodo'];
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003',
      message = format('%s no se trunca: es rastro del banco (y un TRUNCATE no dispara las guardas de cada fila).', tg_table_name);
  end if;

  if tg_table_name = 'banco_historial' then
    -- Solo lo escribe su trigger (segundo nivel de triggers, como en c4).
    if tg_op = 'INSERT' and pg_trigger_depth() > 1 then
      return new;
    end if;
    raise exception using errcode = 'MX003',
      message = 'banco_historial solo lo escribe su trigger: cada cambio del banco deja aquí su fila sola, con quién y cuándo. '
                'No se edita ni se borra, y una fila escrita a mano no entra.';
  end if;

  -- Nada se borra. Las excepciones: las partidas de una conciliación
  -- ABIERTA, que fn_conciliar recalcula enteras (y cada baja queda en el
  -- historial); y una conciliación ABIERTA hecha por error (una fecha mal
  -- escrita) que Edgar anula con su motivo (fn_conciliacion_anular, con la
  -- marca «anular:»), ya sin partidas ni nada que la nombre: queda entera
  -- en banco_historial, con quién, cuándo y por qué. Una confirmada, nunca.
  if tg_op = 'DELETE' and tg_table_name = 'conciliaciones' then
    if v_marca = 'anular:' || old.id and old.estado = 'abierta' and old.tipo = 'normal' and coalesce(btrim(old.motivo), '') <> ''
       and not exists (select 1 from conciliacion_partidas p where p.conciliacion_id = old.id or p.resuelta_en = old.id) then
      return old;
    end if;
  end if;
  if tg_op = 'DELETE' and tg_table_name <> 'conciliacion_partidas' then
    raise exception using errcode = 'MX003',
      message = format('%s no se borra: %s', tg_table_name,
                       case tg_table_name
                         when 'archivos_banco' then 'el archivo del banco es el respaldo permanente de lo que dijo el banco.'
                         when 'movimientos_banco' then 'lo que dijo el banco no se borra. Si no es de la empresa, se ignora con su '
                                                       'motivo (fn_banco_ignorar); si entró dos veces, fn_banco_duplicado.'
                         when 'banco_casados' then 'un casado se deshace con fn_banco_descasar (con su motivo) y queda.'
                         when 'conciliaciones' then 'una conciliación se reabre con su motivo (fn_conciliacion_reabrir) y queda; una '
                                                    'abierta hecha por error se anula con su motivo (fn_conciliacion_anular).'
                         when 'prestamos' then 'un préstamo se marca cancelado o pagado; sus cuotas son rastro.'
                         when 'prepagados' then 'un prepagado se marca cancelado; lo amortizado es rastro.'
                         else 'es rastro del banco.' end);
  end if;

  case tg_table_name
  when 'archivos_banco' then
    if tg_op = 'INSERT' and v_marca = 'archivo:' || new.id then
      new.importado_por := auth.uid();
      new.importado_rol := fn_rol_llamante();
      new.importado_el  := clock_timestamp();
      return new;
    end if;
    -- (Ronda 4) Retirarlo de la cuenta equivocada (fn_banco_archivo_retirar):
    -- una vez, con su motivo; lo que dijo el banco no cambia.
    if tg_op = 'UPDATE' and v_marca = 'retirar:' || old.id and old.retirado_el is null
       and coalesce(btrim(new.retirado_motivo), '') <> ''
       and (to_jsonb(new) - array['retirado_el', 'retirado_por', 'retirado_rol', 'retirado_motivo'])
           = (to_jsonb(old) - array['retirado_el', 'retirado_por', 'retirado_rol', 'retirado_motivo']) then
      new.retirado_el  := clock_timestamp();
      new.retirado_por := auth.uid();
      new.retirado_rol := fn_rol_llamante();
      return new;
    end if;
    raise exception using errcode = 'MX003',
      message = 'Un archivo del banco entra solo por fn_banco_importar_ofx o fn_banco_importar_filas, y no se edita: es el '
                'respaldo de lo que dijo el banco.';

  when 'movimientos_banco_ids' then
    if tg_op = 'INSERT' and v_marca = 'archivo:' || new.archivo_id then
      new.visto_el := clock_timestamp();
      return new;
    end if;
    raise exception using errcode = 'MX003',
      message = 'Los ids de un movimiento del banco los pone solo su importación, y no se editan.';

  when 'movimientos_banco' then
    if tg_op = 'INSERT' then
      if v_marca = 'archivo:' || new.archivo_id then
        if new.casado_id is not null or new.estado not in ('pendiente', 'ignorado') then
          raise exception using errcode = 'MX003', message = 'Un movimiento entra pendiente (o ignorado, con su motivo).';
        end if;
        new.importado_el := clock_timestamp();
        new.sello := fn_banco_sello(new.cuenta, new.ultimos4, new.fecha, new.fecha_transaccion, new.monto, new.tipo_banco, new.cheque,
                                    new.descripcion, new.memo, new.origen, new.id_externo, new.llave, new.archivo_id, new.fila,
                                    (select a.sha256 from archivos_banco a where a.id = new.archivo_id));
        return new;
      end if;
      raise exception using errcode = 'MX003',
        message = 'Un movimiento del banco entra solo por su importación (fn_banco_importar_ofx, fn_banco_importar_filas).';
    end if;
    -- El sello de uno que entró antes de que hubiera sellos (una vez). Todo
    -- lo demás igual, salvo «periodo» (generada: en un trigger BEFORE
    -- todavía no está calculada).
    if v_marca = 'sellar:' || old.id and old.sello is null
       and (to_jsonb(new) - array['sello', 'periodo']) = (to_jsonb(old) - array['sello', 'periodo'])
       and new.sello = fn_banco_sello(old.cuenta, old.ultimos4, old.fecha, old.fecha_transaccion, old.monto, old.tipo_banco,
                                      old.cheque, old.descripcion, old.memo, old.origen, old.id_externo, old.llave, old.archivo_id,
                                      old.fila, (select a.sha256 from archivos_banco a where a.id = old.archivo_id)) then
      return new;
    end if;
    -- UPDATE: solo el estado y el casado, y solo por su función.
    if v_marca = 'movimiento:' || old.id then
      if (to_jsonb(new) - c_mov) is distinct from (to_jsonb(old) - c_mov) then
        raise exception using errcode = 'MX003',
          message = format('Lo que el banco dijo de un movimiento no cambia (%s %s %s): solo su estado y su casado.', old.cuenta,
                           old.fecha, old.monto);
      end if;
      new.cambiado_el := clock_timestamp();
      return new;
    end if;
    raise exception using errcode = 'MX003',
      message = format('Un movimiento del banco no se edita (%s %s %s, %s): lo que dijo el banco se queda. Su estado y su casado '
                       'cambian solo con las funciones del banco (fn_banco_casar, fn_banco_clasificar, fn_banco_ignorar, '
                       'fn_banco_descasar…), con rastro.', old.cuenta, old.fecha, old.monto, coalesce(old.descripcion, ''));

  when 'banco_casados' then
    if tg_op = 'INSERT' then
      if v_marca = 'casar:' || new.movimiento_id and new.deshecho_el is null and new.deshecho_motivo is null
         and new.reverso_id is null then
        new.casado_por := auth.uid();
        new.casado_rol := fn_rol_llamante();
        new.casado_el  := clock_timestamp();
        return new;
      end if;
      raise exception using errcode = 'MX003', message = 'Un casado entra solo por las funciones del banco, vivo.';
    end if;
    if v_marca = 'descasar:' || old.movimiento_id and old.deshecho_el is null and new.deshecho_motivo is not null
       and (to_jsonb(new) - array['deshecho_el', 'deshecho_por', 'deshecho_rol', 'deshecho_motivo', 'reverso_id'])
           = (to_jsonb(old) - array['deshecho_el', 'deshecho_por', 'deshecho_rol', 'deshecho_motivo', 'reverso_id']) then
      new.deshecho_el  := clock_timestamp();
      new.deshecho_por := auth.uid();
      new.deshecho_rol := fn_rol_llamante();
      return new;
    end if;
    raise exception using errcode = 'MX003',
      message = 'Un casado no se edita: se deshace con fn_banco_descasar (con su motivo), una vez, y queda como rastro.';

  when 'banco_casado_lineas' then
    select c.movimiento_id into v_mov from banco_casados c where c.id = coalesce(new.casado_id, old.casado_id);
    if tg_op = 'INSERT' then
      if v_marca = 'casar:' || v_mov and new.vigente then
        -- La línea como está en el libro (cuenta y monto de verdad).
        select * into v_l from asiento_lineas l where l.asiento_id = new.asiento_id and l.orden = new.orden;
        if not found then
          raise exception using errcode = 'MX003', message = 'Esa línea del libro no existe.';
        end if;
        new.cuenta := v_l.cuenta;
        new.monto  := v_l.monto;
        return new;
      end if;
      raise exception using errcode = 'MX003', message = 'Las líneas de un casado entran solo con su casado.';
    end if;
    if v_marca = 'descasar:' || v_mov and old.vigente and not new.vigente
       and (to_jsonb(new) - 'vigente') = (to_jsonb(old) - 'vigente') then
      return new;
    end if;
    raise exception using errcode = 'MX003', message = 'Las líneas de un casado no se editan: se sueltan al des-casarlo.';

  when 'conciliaciones' then
    if tg_op = 'INSERT' then
      if v_marca = 'conciliacion:' || new.id and new.estado = 'abierta' then
        new.creada_por := auth.uid();
        new.creada_rol := fn_rol_llamante();
        new.creada_el  := clock_timestamp();
        return new;
      end if;
      raise exception using errcode = 'MX003', message = 'Una conciliación nace abierta y solo por fn_conciliar o fn_conciliacion_apertura.';
    end if;
    if old.estado = 'confirmada' then
      -- Confirmada no se toca; lo único: reabrirla, con su motivo.
      if v_marca = 'reabrir:' || old.id and new.estado = 'abierta' and coalesce(btrim(new.reabierta_motivo), '') <> ''
         and (to_jsonb(new) - array['estado', 'reabierta_por', 'reabierta_rol', 'reabierta_el', 'reabierta_motivo'])
             = (to_jsonb(old) - array['estado', 'reabierta_por', 'reabierta_rol', 'reabierta_el', 'reabierta_motivo']) then
        new.reabierta_por := auth.uid();
        new.reabierta_rol := fn_rol_llamante();
        new.reabierta_el  := clock_timestamp();
        return new;
      end if;
      raise exception using errcode = 'MX003',
        message = format('La conciliación de %s al %s está confirmada: no se toca. Si hay que rehacerla, se reabre con su motivo '
                         '(fn_conciliacion_reabrir) y queda el rastro.', old.cuenta, old.fecha_corte);
    end if;
    if v_marca = 'conciliacion:' || old.id then
      if new.id <> old.id or new.cuenta <> old.cuenta or new.fecha_corte <> old.fecha_corte or new.tipo <> old.tipo then
        raise exception using errcode = 'MX003', message = 'Una conciliación no cambia de cuenta, de fecha ni de tipo.';
      end if;
      if new.estado = 'confirmada' then
        new.confirmada_por := auth.uid();
        new.confirmada_rol := fn_rol_llamante();
        new.confirmada_el  := clock_timestamp();
      end if;
      return new;
    end if;
    raise exception using errcode = 'MX003',
      message = 'Una conciliación cambia solo con sus funciones (fn_conciliar, fn_conciliacion_confirmar, fn_conciliacion_reabrir).';

  when 'conciliacion_partidas' then
    select * into v_c from conciliaciones c where c.id = coalesce(new.conciliacion_id, old.conciliacion_id);
    if tg_op = 'UPDATE' and v_marca = 'resolver:' || old.id
       and (to_jsonb(new) - array['resuelta_en', 'resuelta_por_movimiento', 'resuelta_el'])
           = (to_jsonb(old) - array['resuelta_en', 'resuelta_por_movimiento', 'resuelta_el']) then
      -- Cuando el banco por fin trae una partida en tránsito: dónde y con
      -- qué movimiento (también en una conciliación ya confirmada: no
      -- cambia lo que se confirmó, dice lo que pasó después; y se suelta si
      -- ese movimiento se des-casa).
      new.resuelta_el := case when new.resuelta_por_movimiento is null and new.resuelta_en is null then null
                              else clock_timestamp() end;
      return new;
    end if;
    if v_c.estado = 'abierta' and v_marca = 'conciliacion:' || v_c.id then
      return case when tg_op = 'DELETE' then old else new end;
    end if;
    raise exception using errcode = 'MX003',
      message = case when v_c.estado = 'confirmada'
                     then format('La conciliación de %s al %s está confirmada: sus partidas no se tocan (se reabre con su motivo).',
                                 v_c.cuenta, v_c.fecha_corte)
                     else 'Las partidas de una conciliación las pone fn_conciliar (y su motivo, fn_conciliacion_partida).' end;

  when 'prestamos' then
    if v_marca = 'prestamo:' || new.id then
      if tg_op = 'INSERT' then
        new.creado_por := auth.uid();
        new.creado_rol := fn_rol_llamante();
        new.creado_el  := clock_timestamp();
      else
        if new.id <> old.id then
          raise exception using errcode = 'MX003', message = 'Un préstamo no cambia de id.';
        end if;
        new.cambiado_el := clock_timestamp();
      end if;
      return new;
    end if;
    raise exception using errcode = 'MX003', message = 'Un préstamo se da de alta y se cambia con fn_prestamo_guardar (con rastro).';

  when 'prestamo_cuotas' then
    if tg_op = 'INSERT' then
      if v_marca = 'cuota:' || new.id and new.anulada_el is null then
        new.creado_por := auth.uid();
        new.creado_rol := fn_rol_llamante();
        new.creado_el  := clock_timestamp();
        return new;
      end if;
      raise exception using errcode = 'MX003', message = 'Una cuota entra solo por fn_prestamo_cuota.';
    end if;
    if v_marca = 'cuota:' || old.id and old.anulada_el is null and new.anulada_motivo is not null
       and (to_jsonb(new) - array['anulada_el', 'anulada_por', 'anulada_motivo'])
           = (to_jsonb(old) - array['anulada_el', 'anulada_por', 'anulada_motivo']) then
      new.anulada_el  := clock_timestamp();
      new.anulada_por := auth.uid();
      return new;
    end if;
    raise exception using errcode = 'MX003',
      message = 'Una cuota no se edita: se anula des-casando su movimiento (fn_banco_descasar) y se registra la buena.';

  when 'prepagados' then
    if v_marca = 'prepagado:' || new.id then
      if tg_op = 'INSERT' then
        new.creado_por := auth.uid();
        new.creado_rol := fn_rol_llamante();
        new.creado_el  := clock_timestamp();
      else
        if new.id <> old.id then
          raise exception using errcode = 'MX003', message = 'Un prepagado no cambia de id.';
        end if;
        new.cambiado_el := clock_timestamp();
      end if;
      return new;
    end if;
    raise exception using errcode = 'MX003', message = 'Un prepagado se da de alta y se cambia con fn_prepagado_guardar (con rastro).';

  when 'prepagados_amortizaciones' then
    if tg_op = 'INSERT' and v_marca = 'amortizar:' || new.periodo and new.vigente then
      new.creado_el := clock_timestamp();
      return new;
    end if;
    if tg_op = 'UPDATE' and v_marca = 'amortizar:' || old.periodo and old.vigente and not new.vigente
       and (to_jsonb(new) - 'vigente') = (to_jsonb(old) - 'vigente') then
      return new;
    end if;
    raise exception using errcode = 'MX003',
      message = 'La amortización de un prepagado la pone y la rehace solo fn_prepagados_amortizar.';

  when 'banco_descriptores' then
    if v_marca = 'descriptor:' || new.clave then
      begin
        perform '' ~* new.patron;
      exception when others then
        raise exception using errcode = '22023',
          message = format('El patrón de «%s» no es una expresión regular válida (%s): %s', new.clave, new.patron, sqlerrm);
      end;
      new.cambiado_por := auth.uid();
      new.cambiado_rol := fn_rol_llamante();
      new.cambiado_el  := clock_timestamp();
      return new;
    end if;
    raise exception using errcode = 'MX003', message = 'Un descriptor del banco se cambia con fn_banco_descriptor (con rastro).';
  else
    raise exception using errcode = 'MX003', message = format('%s: la guarda del banco no conoce esta tabla.', tg_table_name);
  end case;
end $$;
revoke execute on function public.fn_banco_guarda() from public, anon, authenticated, service_role;

-- El historial: cada alta, cambio o baja, DESPUÉS de escrita (si no entra,
-- no queda), con su llave (las columnas que se le pasan al trigger). Un
-- update que no cambia nada no se apunta. Tampoco el de un movimiento que
-- solo cambia su PROPUESTA (lo que la bandeja sugiere, que el motor rehace
-- cuando cambia algo que mira): no es un cambio del banco ni una decisión
-- de Edgar. Antes cada ticket que subía la cuadrilla hacía reescribir la
-- propuesta de todo lo pendiente y el historial guardaba cada fila entera
-- dos veces: 66 MB en un año, el doble que el libro. Lo que Edgar decide
-- sobre un movimiento sí queda: su estado, su casado, un duplicado dicho, y
-- el ticket que dijo que no era el suyo (propuesta.descartados). Y un
-- archivo del banco entra al historial sin su texto (está entero en
-- archivos_banco, con su sha256): su alta queda también fuera de su tabla,
-- y fn_banco_verificar echa de menos el archivo que desaparezca.
create or replace function public.fn_banco_historial()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_fila    jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_antes   jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) end;
  v_despues jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) end;
begin
  if tg_op = 'UPDATE' and v_despues = v_antes then
    return null;
  end if;
  if tg_table_name = 'movimientos_banco' and tg_op = 'UPDATE'
     and (v_antes - array['propuesta', 'estado_motivo', 'cambiado_el']) = (v_despues - array['propuesta', 'estado_motivo', 'cambiado_el'])
     and (v_antes->'propuesta'->'descartados') is not distinct from (v_despues->'propuesta'->'descartados')
     and (v_antes->'propuesta'->'descartado_motivo') is not distinct from (v_despues->'propuesta'->'descartado_motivo')
     -- (ronda 4: lo que Edgar dijo de una partida de la apertura, también)
     and (v_antes->'propuesta'->'apertura_no') is not distinct from (v_despues->'propuesta'->'apertura_no')
     and (v_antes->'propuesta'->'apertura_no_motivo') is not distinct from (v_despues->'propuesta'->'apertura_no_motivo') then
    return null;
  end if;
  if tg_table_name = 'archivos_banco' then
    v_antes := v_antes - 'texto';
    v_despues := v_despues - 'texto';
  end if;
  insert into banco_historial (tabla, clave, operacion, usuario_id, rol, antes, despues)
  values (tg_table_name,
          (select string_agg(coalesce(v_fila->>f, '-'), '|' order by n) from unnest(tg_argv) with ordinality as x(f, n)),
          tg_op, auth.uid(), fn_rol_llamante(), v_antes, v_despues);
  return null;
end $$;
revoke execute on function public.fn_banco_historial() from public, anon, authenticated, service_role;

-- Los triggers. «create or replace trigger» (PG14+): al volver a pegar no
-- hay ni un instante sin la guarda.
do $$
declare
  r record;
begin
  for r in select * from (values
             ('banco_historial',           null),
             ('banco_descriptores',        'clave'),
             ('archivos_banco',            'id'),
             ('movimientos_banco',         'id'),
             ('movimientos_banco_ids',     null),
             ('banco_casados',             'id'),
             ('banco_casado_lineas',       'casado_id,asiento_id,orden'),
             ('conciliaciones',            'id'),
             ('conciliacion_partidas',     'id'),
             ('prestamos',                 'id'),
             ('prestamo_cuotas',           'id'),
             ('prepagados',                'id'),
             ('prepagados_amortizaciones', 'id')) as v(tabla, llave) loop
    execute format('create or replace trigger %I before insert or update or delete on public.%I
                      for each row execute function public.fn_banco_guarda()', 'trg_' || r.tabla || '_guarda', r.tabla);
    execute format('create or replace trigger %I before truncate on public.%I
                      for each statement execute function public.fn_banco_guarda()', 'trg_' || r.tabla || '_sin_truncate', r.tabla);
    if r.llave is not null then
      execute format('create or replace trigger %I after %s on public.%I
                        for each row execute function public.fn_banco_historial(%s)',
                     'trg_' || r.tabla || '_historial',
                     case when r.tabla = 'movimientos_banco' then 'update' else 'insert or update or delete' end,
                     r.tabla,
                     (select string_agg(quote_literal(x), ', ') from unnest(string_to_array(r.llave, ',')) x));
    end if;
  end loop;
end $$;
-- Los movimientos que entraron antes de que hubiera sellos, sellados una
-- vez (con la guarda puesta: solo el sello, y solo si no tenían).
do $$
declare
  r record;
begin
  for r in select m.id from public.movimientos_banco m where m.sello is null loop
    perform public.fn_banco_marca('sellar:' || r.id);
    update public.movimientos_banco m
       set sello = public.fn_banco_sello(m.cuenta, m.ultimos4, m.fecha, m.fecha_transaccion, m.monto, m.tipo_banco, m.cheque,
                                         m.descripcion, m.memo, m.origen, m.id_externo, m.llave, m.archivo_id, m.fila,
                                         (select a.sha256 from public.archivos_banco a where a.id = m.archivo_id))
     where m.id = r.id;
  end loop;
  perform public.fn_banco_marca(null);
end $$;
-- ---------------------------------------------------------------------
-- 1.12 · Quién lee. El bloque fijo de todo docs/conta/c*.sql, tabla por
-- tabla (como c4, 1.7): solo el dueño lee (una policy, «(select
-- es_dueno())»: una vez por consulta, no por fila); nadie de la API
-- escribe (todo entra por las funciones); anon, nada. service_role
-- conserva la lectura (el contador de f07 lee para proponer), salvo el
-- TEXTO de los estados de cuenta (archivos_banco.texto): trae el número
-- entero de la cuenta de Chase con su número de ruta (ACCTID, BANKID) y
-- el de la Amex, y el diseño lo reduce a los 4 últimos en todo lo demás;
-- una llave de servicio (la de una función de borde) lee el archivo por
-- columnas, sin su texto. El dueño lo lee por la API con su policy.
-- «revoke all» y luego «grant select» (en Postgres 17 el «grant all» de Supabase
-- incluye MAINTAIN). Volver a pegar borra toda policy ajena de estas
-- tablas, los permisos por COLUMNA que alguien les dio y todo trigger o
-- regla AJENOS sobre ellas: no son de este archivo, y con ellos las
-- funciones cambiaban el banco sin dejar rastro. Lo que quita, lo dice
-- (NOTICE). La RLS y la policy piden el candado entero de la tabla: solo
-- si hace falta.
-- ---------------------------------------------------------------------
do $$
declare
  t      text;
  p      record;
  v_cols text;
begin
  foreach t in array array['banco_historial', 'banco_descriptores', 'archivos_banco', 'movimientos_banco', 'movimientos_banco_ids',
                           'banco_casados', 'banco_casado_lineas', 'conciliaciones', 'conciliacion_partidas', 'prestamos',
                           'prestamo_cuotas', 'prepagados', 'prepagados_amortizaciones'] loop
    if not (select c.relrowsecurity from pg_class c where c.oid = ('public.' || t)::regclass) then
      execute format('alter table public.%I enable row level security', t);
    end if;
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    -- (los de este archivo no: service_role lee archivos_banco por
    -- columnas, todas menos texto, ver arriba)
    select string_agg(quote_ident(a.attname), ', ' order by a.attnum) into v_cols
      from pg_attribute a
     where a.attrelid = ('public.' || t)::regclass and a.attnum > 0 and not a.attisdropped and a.attacl is not null
       and exists (select 1 from aclexplode(a.attacl) e left join pg_roles r on r.oid = e.grantee
                    where (e.grantee = 0 or r.rolname in ('anon', 'authenticated', 'service_role'))
                      and not (t = 'archivos_banco' and r.rolname = 'service_role' and e.privilege_type = 'SELECT'
                               and a.attname <> 'texto'));
    if v_cols is not null then
      raise notice 'c6: se quitan los permisos por columna de % (%)', t, v_cols;
      execute format('revoke all (%s) on public.%I from public, anon, authenticated, service_role', v_cols, t);
    end if;
    for p in select tg.tgname from pg_trigger tg
              where tg.tgrelid = ('public.' || t)::regclass and not tg.tgisinternal
                and tg.tgname not in ('trg_' || t || '_guarda', 'trg_' || t || '_sin_truncate', 'trg_' || t || '_historial') loop
      raise notice 'c6: se quita el trigger ajeno % de %', p.tgname, t;
      execute format('drop trigger %I on public.%I', p.tgname, t);
    end loop;
    for p in select rw.rulename from pg_rewrite rw
              where rw.ev_class = ('public.' || t)::regclass and rw.rulename <> '_RETURN' loop
      raise notice 'c6: se quita la regla ajena % de %', p.rulename, t;
      execute format('drop rule %I on public.%I', p.rulename, t);
    end loop;
    if t = 'archivos_banco' then
      execute 'grant select on public.archivos_banco to authenticated';
      select string_agg(quote_ident(a.attname), ', ' order by a.attnum) into v_cols
        from pg_attribute a
       where a.attrelid = 'public.archivos_banco'::regclass and a.attnum > 0 and not a.attisdropped and a.attname <> 'texto';
      execute format('grant select (%s) on public.archivos_banco to service_role', v_cols);
    else
      execute format('grant select on public.%I to authenticated, service_role', t);
    end if;
    for p in select pl.policyname from pg_policies pl
              where pl.schemaname = 'public' and pl.tablename = t and pl.policyname <> t || '_dueno' loop
      raise notice 'c6: se quita la policy ajena % de %', p.policyname, t;
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    if not exists (select 1 from pg_policies pl
                    where pl.schemaname = 'public' and pl.tablename = t and pl.policyname = t || '_dueno'
                      and pl.cmd = 'SELECT' and pl.roles = '{authenticated}' and pl.permissive = 'PERMISSIVE'
                      and pl.with_check is null
                      and regexp_replace(pl.qual, '[[:space:]]', '', 'g') = '(SELECTes_dueno()ASes_dueno)') then
      if exists (select 1 from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t and pl.policyname = t || '_dueno') then
        execute format('drop policy %I on public.%I', t || '_dueno', t);
      end if;
      execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 1.13 · Los descriptores de arranque (ver 1.2). Se siembran solo si
-- faltan: lo que Edgar ajustó no se pisa al volver a pegar. Uno que sigue
-- como lo sembró una versión anterior (nadie lo tocó) se pone al día.
--   nomina           la nómina (Gusto; ADP o Paychex del proveedor viejo
--                    hasta el 31-dic): espera al journal de f11
--   cargo_banco      un cargo del banco o de la tarjeta → 6130 (fijo si
--                    además el tipo es FEE o SRVCHG y el signo es de cargo).
--                    También la COMISIÓN de un cheque devuelto («RETURNED
--                    ITEM FEE»), que antes salía como si fuera el cheque
--   interes          intereses que paga el banco → 4910 (fijo si además
--                    el tipo es INT y entra dinero)
--   interes_tarjeta  intereses que cobra la tarjeta → propone 7100
--   cajero           retiro de cajero → pregunta: ¿caja chica o para ti?
--   zelle_edgar      un Zelle de Edgar → propone aporte (3100) o préstamo
--                    del accionista (2900), nunca ingreso
--   transferencia    entre cuentas propias (a la reserva 1030)
--   pago_tarjeta     el pago de una tarjeta DEL LADO DEL BANCO: el nombre
--                    del emisor (AMERICAN EXPRESS, AMEX EPAYMENT, CHASE
--                    CREDIT CRD…), no palabras que usa cualquier
--                    domiciliación. Antes eran también AUTOPAY, THANK YOU y
--                    EPAYMENT sueltos: la luz de FPL («DIRECT DEBIT
--                    AUTOPAY») casaba sola con una devolución de la Amex
--                    como el pago de la tarjeta, y el seguro salía como
--                    transferencia sin ninguna otra opción
--   pago_recibido    el pago de una tarjeta DEL LADO DE LA TARJETA («PAYMENT
--                    RECEIVED - THANK YOU», «ONLINE PAYMENT»): un abono en
--                    la tarjeta que no lo dice es la devolución de una
--                    compra (se clasifica contra su gasto), no un pago
--   cheque_devuelto  un depósito devuelto o revertido → propone la
--                    devolución del cobro (fn_banco_devolver)
-- ---------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in select * from (values
      ('nomina',          '(GUSTO|PAYROLL|\mADP\M|PAYCHEX)',
       'Débito de nómina: espera el journal de nómina (f11) y casa con su línea del banco.', null),
      ('cargo_banco',     '(SERVICE (FEE|CHARGE)|MONTHLY (SERVICE |MAINTENANCE )?FEE|MAINTENANCE FEE|WIRE (TRANSFER )?FEE|'
                          || 'OVERDRAFT|INSUFFICIENT FUNDS|\mNSF\M|ATM FEE|FOREIGN TRANSACTION FEE|ANNUAL (MEMBERSHIP )?FEE|'
                          || 'LATE (PAYMENT )?FEE|RETURNED PAYMENT FEE|STOP PAYMENT FEE|RETURN(ED)? (DEPOSITED )?ITEM (FEE|CHARGE)|'
                          || 'RETURNED (CHECK|DEPOSIT) (FEE|CHARGE))',
       'Cargo del banco o de la tarjeta: a 6130 (regla fija si el tipo del banco es FEE o SRVCHG). También la comisión de un '
       || 'cheque devuelto (el cheque mismo es cheque_devuelto).',
       '(SERVICE (FEE|CHARGE)|MONTHLY (SERVICE |MAINTENANCE )?FEE|MAINTENANCE FEE|WIRE (TRANSFER )?FEE|'
       || 'OVERDRAFT|INSUFFICIENT FUNDS|\mNSF\M|ATM FEE|FOREIGN TRANSACTION FEE|ANNUAL (MEMBERSHIP )?FEE|'
       || 'LATE (PAYMENT )?FEE|RETURNED PAYMENT FEE|STOP PAYMENT FEE)'),
      ('interes',         '(INTEREST (PAYMENT|EARNED|PAID|CREDIT)|^INTEREST$)',
       'Intereses que paga el banco: a 4910 (regla fija si el tipo del banco es INT y entra dinero).', null),
      ('interes_tarjeta', '(INTEREST CHARGE|FINANCE CHARGE|PURCHASE INTEREST)',
       'Intereses de la tarjeta: se propone 7100.', null),
      ('cajero',          '(\mATM\M|CASH WITHDRAWAL|WITHDRAWAL CASH)',
       'Retiro de cajero: ¿caja chica (1050) o para Edgar (3200)? Nunca automático.', null),
      ('zelle_edgar',     'ZELLE (PAYMENT )?FROM EDGAR',
       'Zelle de Edgar: aporte (3100) o préstamo del accionista (2900); nunca ingreso.', null),
      ('transferencia',   '(ONLINE TRANSFER|TRANSFER (TO|FROM)|BOOK TRANSFER|\mXFER\M)',
       'Transferencia entre cuentas propias: un asiento, sin gasto.', null),
      ('pago_tarjeta',    '(AMERICAN EXPRESS|\mAMEX\M|CREDIT CA?RD|CARD ?MEMBER SERV|CARD SERVICES|PAYMENT TO .*CARD)',
       'Pago de una tarjeta, del lado del banco (el nombre del emisor): una transferencia (Dr 2100-x / Cr 1010), sin gasto.',
       '(PAYMENT RECEIVED|AUTOPAY|THANK YOU|EPAYMENT|AMERICAN EXPRESS|\mAMEX\M)'),
      ('pago_recibido',   '(\mPAYMENT\M|\mPYMT\M|\mPMT\M|THANK YOU)',
       'Pago de una tarjeta, del lado de la tarjeta: el abono que dice que es un pago. Otro abono es la devolución de una compra.',
       null),
      ('cheque_devuelto', '(RETURNED (ITEM|CHECK|DEPOSIT)|DEPOSITED ITEM RETURNED|RETURN(ED)? DEPOSIT|CHARGEBACK|REVERSAL)',
       'Depósito devuelto o revertido: se propone la devolución del cobro (fn_banco_devolver).', null)) as v(clave, patron, para, viejo)
  loop
    if not exists (select 1 from public.banco_descriptores d where d.clave = r.clave) then
      perform public.fn_banco_marca('descriptor:' || r.clave);
      insert into public.banco_descriptores (clave, patron, cuenta, para)
      values (r.clave, r.patron, case r.clave when 'cargo_banco' then '6130' when 'interes' then '4910'
                                              when 'interes_tarjeta' then '7100' end, r.para);
      perform public.fn_banco_marca(null);
    elsif r.viejo is not null and exists (select 1 from public.banco_descriptores d where d.clave = r.clave and d.patron = r.viejo) then
      perform public.fn_banco_marca('descriptor:' || r.clave);
      update public.banco_descriptores set patron = r.patron, para = r.para where clave = r.clave;
      perform public.fn_banco_marca(null);
    end if;
  end loop;
end $$;
-- =====================================================================
-- 2 · LOS AYUDANTES (internos: nadie de la API los ejecuta; los llaman las
--     funciones de este archivo). Leer un OFX/QFX, normalizar un texto,
--     decir de qué cuenta es un archivo.
-- =====================================================================

-- Un texto sin espacios de sobra al principio ni al final (también
-- saltos de línea y tabuladores, que btrim a secas no quita). Vacío = nulo.
-- (El tabulador vertical va como chr(11): en una cadena E'' de Postgres
-- «\v» no es un escape, es la letra v, y recortaba las «v» de las puntas:
-- «csv» quedaba en «cs» y el origen csv de un lote no entraba nunca.)
create or replace function public.fn_banco_limpio(p text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$ select nullif(btrim(p, E' \t\r\n\f' || chr(11)), '') $$;
revoke execute on function public.fn_banco_limpio(text) from public, anon, authenticated, service_role;

-- Las entidades de un archivo OFX: &amp; &lt; &gt; &quot; &apos; &nbsp; y
-- las numéricas (&#39; &#x27;). &amp; al final: «&amp;lt;» es el texto
-- «&lt;», no «<».
create or replace function public.fn_banco_entidades(p text)
returns text
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v text := p;
  m text[];
begin
  if v is null or position('&' in v) = 0 then
    return v;
  end if;
  for m in select regexp_matches(v, '&#([xX]?)([0-9a-fA-F]{1,6});', 'g') loop
    begin
      v := replace(v, '&#' || m[1] || m[2] || ';',
                   chr(case when m[1] <> '' then ('x' || lpad(m[2], 8, '0'))::bit(32)::int else m[2]::int end));
    exception when others then
      null;  -- un número que no es un carácter: se queda como venía
    end;
  end loop;
  v := replace(replace(replace(replace(replace(v, '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&nbsp;', ' ');
  return replace(v, '&amp;', '&');
end $$;
revoke execute on function public.fn_banco_entidades(text) from public, anon, authenticated, service_role;

-- La descripción NORMALIZADA de un movimiento: en mayúsculas, lo que no es
-- letra, dígito, # o & se vuelve un espacio, sin espacios de sobra. Es la
-- que se compara (la llave, el mismo movimiento por Plaid y por archivo,
-- los descriptores); la de verdad se guarda tal cual.
create or replace function public.fn_banco_norm(p text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$ select coalesce(btrim(regexp_replace(upper(coalesce(p, '')), '[^[:alnum:]#&]+', ' ', 'g')), '') $$;
revoke execute on function public.fn_banco_norm(text) from public, anon, authenticated, service_role;

-- El valor de un elemento de un bloque OFX: lo que sigue a <TAG> hasta el
-- siguiente «<» (en el dialecto SGML de OFX 1.x los elementos no se
-- cierran: <TRNAMT>-12.34 y el salto de línea; en el XML de OFX 2.x sí:
-- <TRNAMT>-12.34</TRNAMT>; las dos formas dan lo mismo). Sin distinguir
-- mayúsculas, con las entidades resueltas y sin espacios de sobra.
create or replace function public.fn_banco_ofx_valor(p_bloque text, p_tag text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$ select fn_banco_limpio(fn_banco_entidades(substring(p_bloque from '(?i)<' || p_tag || '>([^<]*)'))) $$;
revoke execute on function public.fn_banco_ofx_valor(text, text) from public, anon, authenticated, service_role;

-- Una fecha OFX (AAAAMMDDhhmmss.xxx[-5:EST]): el DÍA, sin convertir zonas
-- (lo que el banco dice que fue ese día, fue ese día).
-- (Sin un bloque de excepción: cada uno abre una subtransacción, y con
-- dos fechas por movimiento un archivo de un año pagaba miles.)
create or replace function public.fn_banco_ofx_fecha(p text, p_que text)
returns date
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_a int;
  v_m int;
  v_d int;
  v   date;
begin
  if p is null then
    raise exception using errcode = 'MX009', message = format('El archivo no se puede leer: falta %s.', p_que);
  end if;
  if p !~ '^[0-9]{8}' then
    raise exception using errcode = 'MX009',
      message = format('El archivo no se puede leer: %s dice «%s», y una fecha OFX es AAAAMMDD (con la hora o sin ella).', p_que, p);
  end if;
  v_a := substr(p, 1, 4)::int;
  v_m := substr(p, 5, 2)::int;
  v_d := substr(p, 7, 2)::int;
  if v_a < 1900 or v_m not between 1 and 12 or v_d not between 1 and 31 then
    raise exception using errcode = 'MX009', message = format('El archivo no se puede leer: %s dice «%s», que no es una fecha.', p_que, p);
  end if;
  v := make_date(v_a, v_m, 1) + (v_d - 1);
  if extract(month from v)::int <> v_m then
    raise exception using errcode = 'MX009', message = format('El archivo no se puede leer: %s dice «%s», que no es una fecha.', p_que, p);
  end if;
  return v;
end $$;
revoke execute on function public.fn_banco_ofx_fecha(text, text) from public, anon, authenticated, service_role;

-- Un monto que llega de un archivo o de Plaid (texto): con signo, con
-- punto decimal (o coma, como la escriben algunos bancos: «-12,34»), sin
-- separador de miles. Nunca más de dos decimales que no sean cero: el
-- libro va en centavos y el redondeo no se decide a escondidas (MX005).
create or replace function public.fn_banco_monto(p text, p_que text)
returns numeric
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v text := replace(coalesce(fn_banco_limpio(p), ''), ' ', '');
  n numeric;
begin
  if v = '' then
    raise exception using errcode = 'MX009', message = format('El archivo no se puede leer: falta %s.', p_que);
  end if;
  if v ~ '^[+-]?[0-9]+,[0-9]{1,2}$' then
    v := replace(v, ',', '.');
  end if;
  if v !~ '^[+-]?([0-9]+(\.[0-9]*)?|\.[0-9]+)$' then
    raise exception using errcode = 'MX005', message = format('%s: «%s» no es un monto.', p_que, p);
  end if;
  n := v::numeric;
  if n <> round(n, 2) then
    raise exception using errcode = 'MX005',
      message = format('%s: %s trae más de dos decimales; el libro va en centavos.', p_que, p);
  end if;
  if abs(n) >= 1000000000000 then
    raise exception using errcode = 'MX005', message = format('%s: %s está fuera de rango.', p_que, p);
  end if;
  return round(n, 2);
end $$;
revoke execute on function public.fn_banco_monto(text, text) from public, anon, authenticated, service_role;

-- Un saldo o un monto que escribe Edgar, o que copia de un statement
-- («25,000.00», «-1,029.33», «$54,172.37», «-1234.5»): con coma de miles o
-- sin ella, dos decimales como mucho. Vacío o nulo: nulo. Es el lector de
-- todo lo que se teclea: la conciliación, la apertura, los préstamos, los
-- prepagados, el journal de la nómina y los lotes a mano o en CSV (antes
-- un lote rechazaba «54,172.37», que fn_conciliar sí aceptaba).
create or replace function public.fn_banco_saldo_texto(p text, p_que text)
returns numeric
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v text := replace(replace(coalesce(fn_banco_limpio(p), ''), '$', ''), ' ', '');
begin
  if v = '' then
    return null;   -- no vino: quien llama decide si hacía falta
  end if;
  if v ~ '^[+-]?[0-9]{1,3}(,[0-9]{3})+(\.[0-9]*)?$' then
    v := replace(v, ',', '');
  end if;
  return fn_banco_monto(v, p_que);
end $$;
revoke execute on function public.fn_banco_saldo_texto(text, text) from public, anon, authenticated, service_role;

-- LEER UN OFX/QFX (los dos dialectos que exportan Chase y Amex): el SGML
-- de OFX 1.x (cabecera OFXHEADER:100 … NEWFILEUID:NONE, elementos sin
-- cerrar) y el XML de OFX 2.x (<?xml …?><?OFX …?>, todo cerrado). Un banco
-- (BANKMSGSRSV1 / STMTRS / BANKACCTFROM) o una tarjeta (CREDITCARDMSGSRSV1 /
-- CCSTMTRS / CCACCTFROM). Devuelve lo que trae, sin escribir nada:
--   { formato, tipo (banco | tarjeta), acctid, ultimos4, acct_tipo,
--     bankid, moneda, desde, hasta, saldo (LEDGERBAL/BALAMT, texto),
--     saldo_al (DTASOF), avisos: [...],
--     filas: [ { n, tipo (TRNTYPE), fecha (DTPOSTED), fecha_transaccion
--               (DTUSER), monto (TRNAMT, texto), id (FITID), cheque
--               (CHECKNUM), descripcion (NAME), memo (MEMO) }, … ] }
-- AVAILBAL (el saldo disponible) se ignora: el que se concilia es el
-- contable. Un archivo que no se puede leer para con MX009 y dice qué
-- falta (y en qué movimiento). Un archivo con más de una cuenta, también:
-- se exporta cada cuenta por separado.
create or replace function public.fn_banco_ofx_leer(p_texto text)
returns jsonb
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_txt     text := replace(coalesce(p_texto, ''), chr(65279), '');
  v_low     text;
  v_formato text;
  v_cuerpo  text;
  v_nb      int;
  v_nc      int;
  v_tipo    text;
  v_tag     text;
  v_stmt    text;
  v_acct    text;
  v_acctid  text;
  v_moneda  text;
  v_lista   text;
  v_cabeza  text;
  v_ledger  text;
  v_saldo   numeric;
  v_saldoal date;
  v_desde   date;
  v_hasta   date;
  v_pieza   text;
  v_ord     bigint;
  v_n       int := 0;
  -- (Las filas en un arreglo, que PL/pgSQL amplía en su sitio: con
  -- «jsonb || fila» cada movimiento copiaba todo lo anterior, y un archivo
  -- de un año, 3.000 movimientos, no entraba en los 8 s de la API.)
  v_filas   jsonb[] := '{}';
  v_avisos  jsonb := '[]'::jsonb;
  v_tt      text;
  v_el      jsonb;
  v_fp      date;
  v_fu      date;
  v_m       numeric;
  v_raros   int := 0;
  v_tipados int := 0;
begin
  if fn_banco_limpio(v_txt) is null then
    raise exception using errcode = 'MX009', message = 'El archivo está vacío.';
  end if;
  v_low := lower(v_txt);
  if v_txt ~* '^[[:space:]]*<\?xml' or position('<?ofx' in v_low) > 0 then
    v_formato := 'ofx_xml';
  elsif v_txt ~* '^[[:space:]]*OFXHEADER[[:space:]]*:' or position('<ofx>' in v_low) > 0 then
    v_formato := 'ofx_sgml';
  else
    raise exception using errcode = 'MX009',
      message = 'El archivo no es un OFX/QFX: no trae la cabecera OFXHEADER ni <OFX>. Descárgalo del banco como «Quicken (QFX)», '
                '«Money (OFX)» o «OFX».';
  end if;
  if position('<ofx>' in v_low) = 0 then
    raise exception using errcode = 'MX009', message = 'El archivo no se puede leer: tiene la cabecera de OFX pero falta <OFX>.';
  end if;
  v_cuerpo := substr(v_txt, position('<ofx>' in v_low));

  -- Un solo estado de cuenta: de banco o de tarjeta.
  v_nb := (length(v_cuerpo) - length(regexp_replace(v_cuerpo, '<[Ss][Tt][Mm][Tt][Rr][Ss]>', '', 'g'))) / 8;
  v_nc := (length(v_cuerpo) - length(regexp_replace(v_cuerpo, '<[Cc][Cc][Ss][Tt][Mm][Tt][Rr][Ss]>', '', 'g'))) / 10;
  if v_nb + v_nc = 0 then
    raise exception using errcode = 'MX009',
      message = 'El archivo no trae ningún estado de cuenta: falta <STMTRS> (de un banco, dentro de <BANKMSGSRSV1>) o '
                '<CCSTMTRS> (de una tarjeta, dentro de <CREDITCARDMSGSRSV1>).';
  end if;
  if v_nb + v_nc > 1 then
    raise exception using errcode = 'MX009',
      message = format('El archivo trae %s estados de cuenta (varias cuentas o tarjetas juntas): descarga cada una por separado.',
                       v_nb + v_nc);
  end if;
  if v_nb = 1 then
    v_tipo := 'banco';
    v_tag  := 'STMTRS';
    if v_cuerpo !~* '<BANKMSGSRSV1>' then
      raise exception using errcode = 'MX009',
        message = 'El archivo no se puede leer: trae <STMTRS> fuera de <BANKMSGSRSV1> (los mensajes del banco).';
    end if;
  else
    v_tipo := 'tarjeta';
    v_tag  := 'CCSTMTRS';
    if v_cuerpo !~* '<CREDITCARDMSGSRSV1>' then
      raise exception using errcode = 'MX009',
        message = 'El archivo no se puede leer: trae <CCSTMTRS> fuera de <CREDITCARDMSGSRSV1> (los mensajes de la tarjeta).';
    end if;
  end if;
  v_stmt := substring(v_cuerpo from '(?i)<' || v_tag || '>(.*)$');
  if v_stmt ~* ('</' || v_tag || '>') then
    v_stmt := substring(v_stmt from '(?i)^(.*?)</' || v_tag || '>');
  end if;

  -- La cuenta.
  v_acct := coalesce(substring(v_stmt from '(?i)<(?:BANKACCTFROM|CCACCTFROM)>(.*?)</(?:BANKACCTFROM|CCACCTFROM)>'),
                     substring(v_stmt from '(?i)<(?:BANKACCTFROM|CCACCTFROM)>(.*)$'));
  if v_acct is null then
    raise exception using errcode = 'MX009',
      message = format('El archivo no se puede leer: falta <%s> (de qué cuenta es).',
                       case when v_tipo = 'banco' then 'BANKACCTFROM' else 'CCACCTFROM' end);
  end if;
  v_acctid := fn_banco_ofx_valor(v_acct, 'ACCTID');
  if v_acctid is null then
    raise exception using errcode = 'MX009',
      message = 'El archivo no se puede leer: falta ACCTID (el número de la cuenta o de la tarjeta).';
  end if;
  v_moneda := upper(fn_banco_ofx_valor(v_stmt, 'CURDEF'));
  if v_moneda is not null and v_moneda <> 'USD' then
    raise exception using errcode = 'MX009', message = format('El archivo está en %s: el libro va en dólares (USD).', v_moneda);
  end if;

  -- La lista de movimientos, su período y el saldo.
  if v_stmt !~* '<BANKTRANLIST>' then
    raise exception using errcode = 'MX009', message = 'El archivo no se puede leer: falta <BANKTRANLIST> (la lista de movimientos).';
  end if;
  v_lista := substring(v_stmt from '(?i)<BANKTRANLIST>(.*)$');
  if v_lista ~* '</BANKTRANLIST>' then
    v_lista := substring(v_lista from '(?i)^(.*?)</BANKTRANLIST>');
  end if;
  v_cabeza := coalesce(substring(v_lista from '(?i)^(.*?)<STMTTRN>'), v_lista);
  v_desde := fn_banco_ofx_fecha(fn_banco_ofx_valor(v_cabeza, 'DTSTART'), 'DTSTART (el primer día del estado de cuenta)');
  v_hasta := fn_banco_ofx_fecha(fn_banco_ofx_valor(v_cabeza, 'DTEND'), 'DTEND (el último día del estado de cuenta)');
  if v_hasta < v_desde then
    raise exception using errcode = 'MX009',
      message = format('El archivo no se puede leer: termina (DTEND %s) antes de empezar (DTSTART %s).', v_hasta, v_desde);
  end if;
  v_ledger := coalesce(substring(v_stmt from '(?i)<LEDGERBAL>(.*?)</LEDGERBAL>'),
                       substring(v_stmt from '(?i)<LEDGERBAL>(.*?)(?:<AVAILBAL>|$)'));
  if v_ledger is not null then
    v_saldo   := fn_banco_monto(fn_banco_ofx_valor(v_ledger, 'BALAMT'), 'BALAMT del saldo final (LEDGERBAL)');
    v_saldoal := fn_banco_ofx_fecha(fn_banco_ofx_valor(v_ledger, 'DTASOF'), 'DTASOF del saldo final (LEDGERBAL)');
  else
    v_avisos := v_avisos || to_jsonb('El archivo no trae el saldo final (LEDGERBAL): para conciliar, escribe el del estado de '
                                     'cuenta.'::text);
  end if;

  -- Cada movimiento. (Sus elementos, de una pasada: cada <TAG> con lo que
  -- le sigue hasta el siguiente «<», el primero de cada uno, como
  -- fn_banco_ofx_valor; antes, una búsqueda por elemento y por fila.)
  for v_pieza, v_ord in select t.x, t.n from regexp_split_to_table(v_lista, '(?i)<STMTTRN>') with ordinality as t(x, n) loop
    continue when v_ord = 1;
    v_pieza := regexp_replace(v_pieza, '(?i)</STMTTRN>.*$', '');
    v_n := v_n + 1;
    select coalesce(jsonb_object_agg(x.tag, x.val), '{}'::jsonb) into v_el
      from (select distinct on (upper(t.m[1])) upper(t.m[1]) as tag, fn_banco_limpio(fn_banco_entidades(t.m[2])) as val
              from regexp_matches(v_pieza, '<([A-Za-z0-9.]+)>([^<]*)', 'g') with ordinality as t(m, o)
             order by upper(t.m[1]), t.o) x;
    v_tt := upper(v_el->>'TRNTYPE');
    if v_tt is null then
      raise exception using errcode = 'MX009', message = format('El archivo no se puede leer: al movimiento %s le falta TRNTYPE.', v_n);
    end if;
    v_fp := fn_banco_ofx_fecha(v_el->>'DTPOSTED', format('DTPOSTED del movimiento %s', v_n));
    v_fu := case when v_el->>'DTUSER' is not null
                 then fn_banco_ofx_fecha(v_el->>'DTUSER', format('DTUSER del movimiento %s', v_n)) end;
    v_m := fn_banco_monto(v_el->>'TRNAMT', format('TRNAMT del movimiento %s', v_n));
    -- (Los signos: un cargo sale en negativo y un abono en positivo. Si
    -- casi todos vienen al revés de su tipo, se avisa.)
    if v_tt in ('DEBIT', 'CHECK', 'FEE', 'SRVCHG', 'ATM', 'POS', 'DIRECTDEBIT', 'CREDIT', 'DEP', 'DIRECTDEP', 'INT', 'DIV') then
      v_tipados := v_tipados + 1;
      if (v_tt in ('DEBIT', 'CHECK', 'FEE', 'SRVCHG', 'ATM', 'POS', 'DIRECTDEBIT') and v_m > 0)
         or (v_tt in ('CREDIT', 'DEP', 'DIRECTDEP', 'INT', 'DIV') and v_m < 0) then
        v_raros := v_raros + 1;
      end if;
    end if;
    v_filas[v_n] := jsonb_strip_nulls(jsonb_build_object(
      'n', v_n, 'tipo', v_tt, 'fecha', v_fp, 'fecha_transaccion', v_fu, 'monto', v_m::text,
      'id', v_el->>'FITID', 'cheque', v_el->>'CHECKNUM', 'descripcion', v_el->>'NAME', 'memo', v_el->>'MEMO'));
  end loop;
  if v_tipados >= 3 and v_raros * 2 > v_tipados then
    v_avisos := v_avisos || to_jsonb(format('%s de %s movimientos traen el signo al revés de su tipo (un cargo en positivo): '
                                            'revisa que el archivo sea del banco tal cual.', v_raros, v_tipados));
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'formato', v_formato, 'tipo', v_tipo, 'acctid', v_acctid,
    'ultimos4', nullif(right(regexp_replace(v_acctid, '[^0-9]', '', 'g'), 4), ''),
    'acct_tipo', upper(fn_banco_ofx_valor(v_acct, 'ACCTTYPE')), 'bankid', fn_banco_ofx_valor(v_acct, 'BANKID'),
    'moneda', coalesce(v_moneda, 'USD'), 'desde', v_desde, 'hasta', v_hasta, 'saldo', v_saldo::text, 'saldo_al', v_saldoal,
    'avisos', v_avisos, 'filas', to_jsonb(v_filas)));
end $$;
revoke execute on function public.fn_banco_ofx_leer(text) from public, anon, authenticated, service_role;

-- La caja chica (el efectivo en la mano, sin estado de cuenta): la cuenta
-- de la forma de pago «efectivo» de c3 (1050).
create or replace function public.fn_banco_caja()
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce((select m.cuenta from mapeo_metodo_pago m where m.forma = 'efectivo' and m.cuenta is not null
                    order by m.confirmado_el desc nulls last limit 1), '1050')
$$;
revoke execute on function public.fn_banco_caja() from public, anon, authenticated, service_role;

-- ¿Es una cuenta PROPIA con estado de cuenta? Un banco (10xx, de activo,
-- sin obra: 1010, 1030…), salvo la caja chica; o una tarjeta de la empresa
-- (una cuenta de pasivo de la tabla tarjetas: 2100-2013, 2100-2009). Entre
-- dos de estas, el mismo dinero es una transferencia.
create or replace function public.fn_banco_es_propia(p_cuenta text)
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce((fn_puente_es_banco(p_cuenta) and p_cuenta is distinct from fn_banco_caja())
                  or exists (select 1 from tarjetas t join cuentas c on c.codigo = t.cuenta
                              where t.cuenta = p_cuenta and c.tipo = 'pasivo' and c.saldo_normal = 'haber'), false)
$$;
revoke execute on function public.fn_banco_es_propia(text) from public, anon, authenticated, service_role;

-- ¿Una cuenta del banco (activo) o de tarjeta (pasivo)? 'banco', 'tarjeta'
-- o nulo si no es propia (la caja chica no tiene estado de cuenta: su
-- «conciliación» es contar el efectivo).
create or replace function public.fn_banco_tipo_cuenta(p_cuenta text)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select case when fn_puente_es_banco(p_cuenta) and p_cuenta is distinct from fn_banco_caja() then 'banco'
              when fn_banco_es_propia(p_cuenta) then 'tarjeta' end
$$;
revoke execute on function public.fn_banco_tipo_cuenta(text) from public, anon, authenticated, service_role;

-- ¿Casa la descripción normalizada con el descriptor de esa clave?
create or replace function public.fn_banco_dice(p_clave text, p_desc text)
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$ select coalesce((select coalesce(p_desc, '') ~* d.patron from banco_descriptores d where d.clave = p_clave), false) $$;
revoke execute on function public.fn_banco_dice(text, text) from public, anon, authenticated, service_role;

-- (Ronda 4) LOS 4 ÚLTIMOS DE LA OTRA CUENTA que nombra una transferencia
-- («ONLINE TRANSFER TO CHK ...7781», «TO SAV XXXXXX1097», «FROM ACCT
-- XXXX1234»), o nulo. Y de quién es ese número en la empresa: una tarjeta
-- dada de alta, o un banco cuyos estados de cuenta lo traen (no un código
-- del plan que se le parezca). Un número que no es de la empresa (la
-- cuenta personal de Edgar) no es «dinero entre cuentas propias»: antes
-- todo ONLINE TRANSFER se tomaba por eso, y el pase a la cuenta personal
-- salía «A 1030 / A la Amex», sin motivo.
create or replace function public.fn_banco_otra_cuenta(p_dn text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select right(substring(coalesce(p_dn, '') from '(?:^| )(?:CHK|CHECKING|SAV|SAVINGS|ACCT|ACCOUNT|DDA|MMA) X*([0-9]{4,})(?: |$)'), 4)
$$;
revoke execute on function public.fn_banco_otra_cuenta(text) from public, anon, authenticated, service_role;

create or replace function public.fn_banco_numero_de(p_u4 text)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce((select t.cuenta from tarjetas t where t.ultimos4 = p_u4 and t.activa order by t.cuenta limit 1),
                  (select a.cuenta from archivos_banco a
                    where a.ultimos4 = p_u4 and a.retirado_el is null and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada)
                    order by a.importado_el desc limit 1))
   where p_u4 is not null
$$;
revoke execute on function public.fn_banco_numero_de(text) from public, anon, authenticated, service_role;

-- (Ronda 4) ¿Por qué una transferencia de este movimiento a (o desde)
-- p_cuenta necesita su motivo? Nulo si no: el banco nombra OTRA cuenta
-- (····7781, que no es la de p_cuenta), o, entre dos bancos, p_cuenta
-- nunca trajo su estado de cuenta (la reserva por abrir: no se sabe que el
-- dinero llegó, y quedaría «en tránsito» para siempre sin que nada lo
-- dijera).
create or replace function public.fn_banco_transferencia_dudosa(m public.movimientos_banco, p_cuenta text)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select case
           when x.u4 is not null and fn_banco_numero_de(x.u4) is distinct from p_cuenta
           then format('el banco dice que es la cuenta ····%s, %s', x.u4,
                       coalesce('que es ' || fn_banco_numero_de(x.u4), 'que no es de ningún estado de cuenta ni tarjeta de la empresa'))
           -- (entre dos bancos: el pago de una tarjeta desde el banco
           -- operativo, cuyo estado de cuenta llega cada mes, no)
           when fn_banco_tipo_cuenta(p_cuenta) = 'banco' and fn_banco_tipo_cuenta(m.cuenta) = 'banco'
                and not exists (select 1 from archivos_banco a where a.cuenta = p_cuenta and a.retirado_el is null)
           then format('%s nunca trajo su estado de cuenta: no se sabe que el dinero llegó allí', p_cuenta) end
    from (select case when coalesce(m.tipo_banco, '') = 'XFER' or fn_banco_dice('transferencia', m.desc_norm)
                      then coalesce(fn_banco_otra_cuenta(m.desc_norm), fn_banco_otra_cuenta(fn_banco_norm(m.memo))) end as u4) x
$$;
revoke execute on function public.fn_banco_transferencia_dudosa(public.movimientos_banco, text)
  from public, anon, authenticated, service_role;

-- EL NÚMERO DE UN CHEQUE: el que dice el banco (CHECKNUM), o, si no lo
-- dice, el que trae la descripción («CHECK 1043», «CHK #1043»). Algunos
-- bancos no mandan CHECKNUM y el número solo va en NAME: antes ese cheque
-- no casaba con su partida de la apertura (por su número) ni tenía la
-- ventana de un cheque. Sin ceros a la izquierda. (La misma expresión
-- regular, escrita, en fn_banco_pool: allí va fila por fila.)
create or replace function public.fn_banco_cheque_num(p_cheque text, p_desc text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select coalesce(nullif(ltrim(fn_banco_limpio(p_cheque), '0'), ''),
                  substring(fn_banco_norm(p_desc)
                            from '(?:^| )(?:CHECK|CHK|CHEQUE|CK)(?: NO)? ?#? ?0*([1-9][0-9]{0,9})(?: |$)'))
$$;
revoke execute on function public.fn_banco_cheque_num(text, text) from public, anon, authenticated, service_role;

-- ¿NOMBRA A ALGUIEN la descripción de un movimiento (NAME, normalizada)?
-- Quitadas las palabras del banco (CHECK, ACH, PAYMENT, ONLINE, TO, FROM,
-- ZELLE, DIRECT DEBIT, PPD, TRACE…), los números y las referencias
-- (JPM99ABC), ¿queda una palabra de dos letras o más? «CHECK 1044» o
-- «ACH DEBIT 12345» no nombran a nadie; «ZELLE PAYMENT TO MIGUEL SANCHEZ»,
-- «FPL DIRECT DEBIT ELEC PYMT» y «PROGRESSIVE INS PREM PPD» sí.
-- (Ronda 4: también los nombres de DOS letras y con «&» —«AT&T*BILL
-- PAYMENT», «US BANK PAYMENT», «ZELLE PAYMENT TO JC»—, y BANK o MOBILE
-- detrás de otro nombre —US BANK, T-MOBILE: un acreedor, un proveedor—.
-- Antes solo contaban las de tres letras o más, sin símbolos, y esos tres
-- salían como «pago sin nombre»: con CED a cuenta, su único botón era
-- «Abono a CED» y el teléfono bajaba la deuda con CED. Las palabras de dos
-- letras del banco —TO, ID, CO, NO…— siguen sin contar.)
create or replace function public.fn_banco_nombra_alguien(p_dn text)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  with banco(w) as (
    select unnest(array['CHECK', 'CHK', 'CHEQUE', 'ACH', 'DEBIT', 'DEBITO', 'CREDIT', 'PAYMENT', 'PAYMENTS', 'PMT',
                        'PYMT', 'PMNT', 'ONLINE', 'BILL', 'BILLPAY', 'PAY', 'WEB', 'PPD', 'CCD', 'TEL', 'IND',
                        'INDN', 'DES', 'ENTRY', 'DESCR', 'DESC', 'SEC', 'FROM', 'FOR', 'THE', 'DIRECT', 'DEP',
                        'DEPOSIT', 'EPAY', 'EPAYMENT', 'WIRE', 'TRANSFER', 'XFER', 'OUTGOING', 'INCOMING', 'OUT',
                        'WITHDRAWAL', 'WITHDRAW', 'POS', 'PURCHASE', 'CARD', 'RECURRING', 'AUTOPAY', 'AUTO',
                        'ELECTRONIC', 'ORIG', 'TRN', 'REF', 'CONF', 'CONFIRMATION', 'TRACE', 'EFT', 'ZELLE',
                        'NAME', 'DATE', 'EED', 'NUM', 'NUMBER', 'TRANSACTION', 'ITEM', 'FEE', 'SERVICE', 'BANK',
                        'ORDER', 'MOBILE', 'EXTERNAL', 'INTERNAL', 'SENT', 'ACCOUNT', 'ACCT', 'SAVINGS', 'CHECKING',
                        'PAID', 'BUSINESS', 'COMPANY', 'AND',
                        -- (las de dos letras que escribe el banco: «PAYMENT TO»,
                        -- «PPD ID», «ORIG CO NAME», «REF NO», «ACH DR»)
                        'TO', 'ID', 'CO', 'NO', 'NR', 'OF', 'ON', 'IN', 'AT', 'BY', 'DR', 'CR', 'AM', 'PM', 'XX'])),
  -- (cada palabra, sin «&» ni «#» —AT&T es ATT, TRACE# es TRACE—, con la
  -- de antes)
  pal as (
    select regexp_replace(w.w, '[&#]', '', 'g') as p, regexp_replace(coalesce(lag(w.w) over (order by w.i), ''), '[&#]', '', 'g') as ant
      from regexp_split_to_table(coalesce(p_dn, ''), ' ') with ordinality as w(w, i))
  select exists (select 1 from pal
                  where pal.p ~ '^[[:alpha:]]{2,}$'
                    and (not exists (select 1 from banco b where b.w = pal.p)
                         -- (BANK o MOBILE detrás de un nombre: US BANK, T MOBILE)
                         or (pal.p in ('BANK', 'MOBILE') and pal.ant ~ '^[[:alpha:]]+$'
                             and not exists (select 1 from banco b where b.w = pal.ant))))
$$;
revoke execute on function public.fn_banco_nombra_alguien(text) from public, anon, authenticated, service_role;

-- ¿UN PAGO SIN NOMBRE? Un cargo con señal de pago (un cheque, un ACH, un
-- «payment», un giro) que no nombra a nadie y que no es una domiciliación
-- (DIRECTDEBIT: la luz, el seguro, que se cobran solos). Solo ESO puede ser,
-- a ciegas, el abono a lo que se le debe a un proveedor (fn_banco_proponer,
-- 10). Antes bastaba la señal: con un proveedor a cuenta, la luz de FPL,
-- el seguro, un Zelle a un ayudante y uno de Edgar a sí mismo salían todos
-- como «Abono a CED» (el único botón), y clasificar la luz pedía motivo.
-- (La usan la propuesta y la firma de cada movimiento: dicen lo mismo.)
create or replace function public.fn_banco_pago_anonimo(p_tipo text, p_cheque text, p_desc text, p_dn text, p_txt text)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  select coalesce(p_tipo, '') <> 'DIRECTDEBIT'
         and not fn_banco_nombra_alguien(p_dn)
         and (fn_banco_cheque_num(p_cheque, p_desc) is not null
              or coalesce(p_tipo, '') in ('CHECK', 'XFER', 'PAYMENT')
              or coalesce(p_txt ~* '(BILL ?PAY|[[:<:]]ACH[[:>:]]|[[:<:]]PAYMENT[[:>:]]|[[:<:]]PMT[[:>:]]|EPAY|[[:<:]]WIRE[[:>:]]|[[:<:]]CHECK[[:>:]]|[[:<:]]CHK[[:>:]])',
                          false))
$$;
revoke execute on function public.fn_banco_pago_anonimo(text, text, text, text, text) from public, anon, authenticated, service_role;

-- ¿NOMBRA el banco AL COMERCIO de un ticket? Una palabra de 4 letras o más
-- de su proveedor (sin THE, INC, LLC…) en la descripción (NAME,
-- normalizada): «THE HOME DEPOT» en «THE HOME DEPOT #6345 MIAMI FL».
create or replace function public.fn_banco_comercio(p_proveedor text, p_dn text)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  select exists (select 1 from regexp_split_to_table(fn_banco_norm(p_proveedor), ' ') as w(w)
                  where length(w.w) >= 4 and w.w not in ('THE', 'INC', 'LLC', 'CORP', 'STORE', 'SUPPLY', 'COMPANY', 'SERVICES')
                    and position(' ' || w.w || ' ' in ' ' || coalesce(p_dn, '') || ' ') > 0)
$$;
revoke execute on function public.fn_banco_comercio(text, text) from public, anon, authenticated, service_role;

-- ¿Puede ser el MISMO GASTO con OTRO TOTAL? Un cargo del banco y la línea
-- de un ticket en esa cuenta, del mismo signo y montos distintos, que se
-- parecen: el banco nombra al comercio del ticket, o los montos no se
-- separan más de un 12 % (el tax de Florida, 6 a 8,5 %; la propina). Lo
-- más común al leer un ticket es tomar el subtotal sin el tax: el cargo
-- de 107.00 y el ticket de 100.00 no casaban, el cargo salía «sin ticket»,
-- se clasificaba y el gasto entraba dos veces (fn_banco_proponer, 12b;
-- fn_banco_clasificar; fn_banco_tickets_llegados).
create or replace function public.fn_banco_otro_total(p_monto numeric, p_dn text, p_linea numeric, p_proveedor text)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  select p_monto <> 0 and p_linea <> p_monto and sign(p_linea) = sign(p_monto)
         and (abs(p_linea - p_monto) <= 0.12 * greatest(abs(p_linea), abs(p_monto)) or fn_banco_comercio(p_proveedor, p_dn))
$$;
revoke execute on function public.fn_banco_otro_total(numeric, text, numeric, text) from public, anon, authenticated, service_role;

-- EL DÍA DE LA COMPRA de un movimiento: el que dice el banco (DTUSER), o
-- el «MM/DD» de su nota o su descripción (la débito de Chase no manda
-- DTUSER y lo escribe ahí: «10/06 LOWES #01234* TAMPA FL Card 9420»), si
-- cae en los 10 días antes del banco. Si no lo trae, nulo: no se inventa.
create or replace function public.fn_banco_fecha_compra(m public.movimientos_banco)
returns date
language sql
immutable
set search_path = public, pg_temp
as $$
  select coalesce(m.fecha_transaccion,
           (select x.d
              from (select case when y.dd <= extract(day from (make_date(y.a, y.mm, 1) + interval '1 month' - interval '1 day'))
                                then make_date(y.a, y.mm, y.dd) end as d
                      from (select g.mm, g.dd,
                                   extract(year from m.fecha)::int
                                   - case when (g.mm, g.dd) > (extract(month from m.fecha)::int, extract(day from m.fecha)::int)
                                          then 1 else 0 end as a
                              from (select r[1]::int as mm, r[2]::int as dd
                                      from regexp_match(concat_ws(' ', m.memo, m.descripcion),
                                                        '(?:^|[^0-9/])(0?[1-9]|1[0-2])/(0?[1-9]|[12][0-9]|3[01])(?:/(?:20)?[0-9]{2})?(?:[^0-9/]|$)')
                                           as r) g) y) x
             where x.d between m.fecha - 10 and m.fecha))
$$;
revoke execute on function public.fn_banco_fecha_compra(public.movimientos_banco) from public, anon, authenticated, service_role;

-- LA OBRA DE UN CARGO, por las visitas (eventos, p_obras: cada día, sus
-- obras): la del día de la compra si ese día hubo visita a UNA sola
-- ({proyecto_id, dia}); sin el día de la compra, la única obra con visita
-- de 3 días antes del banco a ese día ({proyecto_id, desde, hasta}: la
-- débito postea de 1 a 3 días después); con varias, ninguna ({varias}:
-- cuáles y qué día, para que Edgar elija). Antes era la visita del día en
-- que el banco lo posteó: la compra del martes en el Taller Ruiz salía con
-- la obra de la visita del jueves.
create or replace function public.fn_banco_obra_de(m public.movimientos_banco, p_obras jsonb)
returns jsonb
language sql
immutable
set search_path = public, pg_temp
as $$
  with f as (select fn_banco_fecha_compra(m) as fc),
  dias as (select g.d::date as dia, x.p
             from f
             cross join generate_series(coalesce(f.fc, m.fecha - 3), coalesce(f.fc, m.fecha), interval '1 day') as g(d)
             cross join jsonb_array_elements_text(coalesce(p_obras->(g.d::date::text), '[]'::jsonb)) as x(p)),
  n as (select count(distinct dias.p) as n, min(dias.p) as p from dias)
  select case when n.n = 1 and f.fc is not null then jsonb_build_object('proyecto_id', n.p, 'dia', f.fc)
              when n.n = 1 then jsonb_build_object('proyecto_id', n.p, 'desde', m.fecha - 3, 'hasta', m.fecha)
              when n.n > 1 then jsonb_build_object('varias', (select jsonb_agg(jsonb_build_object('proyecto_id', d.p, 'dia', d.dia)
                                                                               order by d.dia, d.p) from dias d))
         end
    from f, n
   where p_obras is not null and p_obras <> '{}'::jsonb
$$;
revoke execute on function public.fn_banco_obra_de(public.movimientos_banco, jsonb) from public, anon, authenticated, service_role;

-- LA CUENTA QUE DICE EDGAR, como la dice: la del plan ('1010', '2100-2013')
-- o su código corto, los 4 últimos de una tarjeta dada de alta ('2013') o
-- de una cuenta cuyos archivos los traen ('4392'). La misma lectura que el
-- importador (fn_banco_cuenta_de), sin mirar ningún archivo: la usan casar,
-- conciliar y la revisión. Antes el importador aceptaba '2013' y casar y
-- conciliar respondían que esa tarjeta no era de la empresa. Lo que no se
-- reconoce vuelve tal cual (quien la usa dice que no es una cuenta).
create or replace function public.fn_banco_cuenta_resolver(p text)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select case when x.c is null then null
              when exists (select 1 from cuentas c where c.codigo = x.c) then x.c
              when x.c ~ '^[0-9]{4}$'
                then coalesce((select t.cuenta from tarjetas t where t.ultimos4 = x.c and t.activa order by t.cuenta limit 1),
                              (select a.cuenta from archivos_banco a
                                where a.ultimos4 = x.c and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada)
                                  and a.retirado_el is null
                                order by a.importado_el desc limit 1),
                              x.c)
              else x.c end
    from (select fn_banco_limpio(p) as c) x
$$;
revoke execute on function public.fn_banco_cuenta_resolver(text) from public, anon, authenticated, service_role;

-- DE QUÉ CUENTA DEL PLAN ES UN ARCHIVO (o un lote de filas):
--   p_cuenta    lo que dice Edgar: una cuenta del plan ('1010', '2100-2013')
--               o los 4 últimos de una tarjeta dada de alta ('2013', '9420');
--   p_ultimos4  los 4 últimos del número de cuenta que trae el archivo;
--   p_tipo      'banco' o 'tarjeta', lo que dice el archivo (nulo: no lo
--               dice, como en las filas de Plaid);
--   p_confirmo  Edgar dice, a sabiendas, que un número de cuenta distinto
--               del de siempre es de esa cuenta (solo un lote lo dice:
--               "confirmo_cuenta", ver fn_banco_importar_filas).
-- De quién es un número lo dicen las tarjetas dadas de alta (tarjetas) y,
-- en un banco, los archivos que lo traen DE VERDAD: los OFX (su ACCTID) y
-- los lotes que Edgar confirmó. Un lote de Plaid o a mano con "cuenta":
-- "1010" no dice ningún número (1010 es la cuenta del plan, no los 4
-- últimos de nada) y no enseña nada. Sin p_cuenta: la tarjeta con esos 4
-- últimos, o el banco cuyos archivos los traen. Y no se adivina nunca:
--   · el archivo de otra tarjeta dada de alta, a otra cuenta: MX004;
--   · el estado de cuenta de OTRA cuenta de banco (sus 4 últimos son de
--     otra cuenta, o la cuenta dicha recibe los de otro número): MX004 y
--     dice cómo confirmarlo si de verdad el banco cambió el número. Antes
--     entraba entero en la cuenta dicha (los movimientos personales de
--     otra cuenta, a la bandeja de la empresa y para siempre: lo que dijo
--     el banco no se borra), el número se quedaba pegado a ella y su saldo
--     pasaba a ser «el del banco» de esa cuenta.
drop function if exists public.fn_banco_cuenta_de(text, text, text);
create or replace function public.fn_banco_cuenta_de(p_cuenta text, p_ultimos4 text, p_tipo text, p_confirmo boolean default false)
returns text
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_c     text := fn_banco_limpio(p_cuenta);
  v_u4    text := fn_banco_limpio(p_ultimos4);
  v_cta   text;
  v_de_u4 text;
  v_banco text;
  v_otros text;
  v_tipo  text;
  v_como  text;
  v_uno   archivos_banco;
  v_n     int;
  v_id    text;
  v_qb    text;
  v_qbn   text;
begin
  if v_u4 is not null then
    select t.cuenta into v_de_u4 from tarjetas t where t.ultimos4 = v_u4 and t.activa;
    if v_de_u4 is null then
      -- El banco cuyos archivos de verdad traen ese número (el último).
      select a.cuenta into v_banco
        from archivos_banco a
       where a.ultimos4 = v_u4 and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada) and a.retirado_el is null
         and (p_tipo is null or fn_banco_tipo_cuenta(a.cuenta) = p_tipo)
       order by a.importado_el desc
       limit 1;
    end if;
  end if;
  if v_c is not null then
    if exists (select 1 from cuentas c where c.codigo = v_c) then
      v_cta := v_c;
    elsif v_c ~ '^[0-9]{4}$' then
      -- Los 4 últimos: de una tarjeta dada de alta, o de una cuenta cuyos
      -- archivos de verdad los traen (Chase ····4392).
      select t.cuenta into v_cta from tarjetas t where t.ultimos4 = v_c and t.activa;
      if v_cta is null then
        select a.cuenta into v_cta
          from archivos_banco a
         where a.ultimos4 = v_c and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada) and a.retirado_el is null
           and (p_tipo is null or fn_banco_tipo_cuenta(a.cuenta) = p_tipo)
         order by a.importado_el desc
         limit 1;
      end if;
      if v_cta is null then
        raise exception using errcode = 'MX004',
          message = format('No hay una tarjeta activa que acabe en %s (tarjetas) ni un archivo anterior de esa cuenta: di la '
                           'cuenta del plan (''1010'', ''1030'', ''2100-2013''…) la primera vez, o da de alta la tarjeta '
                           '(fn_tarjeta_alta).', v_c);
      end if;
    else
      raise exception using errcode = 'MX004',
        message = format('«%s» no es una cuenta del plan ni los 4 últimos de una tarjeta.', v_c);
    end if;
    if v_de_u4 is not null and v_de_u4 <> v_cta then
      raise exception using errcode = 'MX004',
        message = format('El archivo es de la tarjeta que acaba en %s (%s) y dijiste %s: no se adivina. Sube el archivo de esa '
                         'cuenta, o corrige la tarjeta.', v_u4, v_de_u4, v_cta);
    end if;
    -- Un banco: el número del archivo tiene que ser el de esa cuenta.
    if v_u4 is not null and v_de_u4 is null and not coalesce(p_confirmo, false)
       and fn_banco_tipo_cuenta(v_cta) = 'banco' then
      v_como := format('Si de verdad es de %s (el banco le cambió el número), confírmalo una vez, a sabiendas: select '
                       'fn_banco_importar_filas(''{"origen": "mano", "cuenta": "%s", "ultimos4": "%s", "confirmo_cuenta": true, '
                       '"nombre": "%s: número nuevo ····%s", "filas": []}''); y vuelve a subir el archivo.', v_cta, v_cta, v_u4, v_cta,
                       v_u4);
      if v_banco is not null and v_banco <> v_cta then
        -- (Ronda 4: si ese número solo entró UNA vez a la otra cuenta, sin
        -- nada confirmado, no se da por cierto: pudo ser aquel el que entró
        -- a la cuenta equivocada. Se dice cuál y cómo retirarlo.)
        select a.* into v_uno from archivos_banco a
         where a.cuenta = v_banco and a.ultimos4 = v_u4 and a.retirado_el is null and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada)
         order by a.importado_el;
        if (select count(*) from archivos_banco a
             where a.cuenta = v_banco and a.ultimos4 = v_u4 and a.retirado_el is null
               and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada)) = 1
           and not exists (select 1 from conciliaciones cc where cc.cuenta = v_banco and cc.estado = 'confirmada' and cc.tipo = 'normal') then
          raise exception using errcode = 'MX004',
            message = format('El archivo es de la cuenta ····%s, y ese número solo entró una vez, a %s (el archivo «%s» del %s), y '
                             'dijiste %s. Si aquel entró a la cuenta equivocada, retíralo desde el SQL Editor (select '
                             'fn_banco_archivo_retirar(%L, ''el motivo'');) y vuelve a subir este. %s', v_u4, v_banco,
                             coalesce(v_uno.nombre, 'sin nombre'), v_uno.importado_el::date, v_cta, v_uno.id, v_como);
        end if;
        raise exception using errcode = 'MX004',
          message = format('El archivo es de la cuenta ····%s, que es de %s por sus estados de cuenta, y dijiste %s: no se adivina '
                           '(los movimientos de otra cuenta no entran a esta). Sube el de %s. %s', v_u4, v_banco, v_cta, v_cta, v_como);
      end if;
      select string_agg(distinct '····' || a.ultimos4, ', '), count(*), min(a.id::text) into v_otros, v_n, v_id
        from archivos_banco a
       where a.cuenta = v_cta and a.ultimos4 is not null and a.ultimos4 <> v_u4 and a.retirado_el is null
         and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada);
      if v_otros is not null
         and not exists (select 1 from archivos_banco a
                          where a.cuenta = v_cta and a.ultimos4 = v_u4 and a.retirado_el is null
                            and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada)) then
        raise exception using errcode = 'MX004',
          message = format('%s recibe los estados de cuenta de %s y este archivo es de la cuenta ····%s: ¿es de otra cuenta? Los '
                           'movimientos de otra cuenta no entran a esta. %s%s', v_cta, v_otros, v_u4,
                           case when v_n = 1
                                     and not exists (select 1 from conciliaciones cc
                                                      where cc.cuenta = v_cta and cc.estado = 'confirmada' and cc.tipo = 'normal')
                                then format('Si el que entró antes (el único, %s) era de otra cuenta, retíralo desde el SQL Editor '
                                            '(select fn_banco_archivo_retirar(%L, ''el motivo'');) y vuelve a subir este. ', v_otros,
                                            v_id)
                                else '' end, v_como);
      end if;
      -- (Ronda 4) El PRIMER archivo de este número a un banco: si QuickBooks
      -- ya dice de quién es («Chase Chk 4392» → 1010, en la apertura), no
      -- se toma a ciegas a otra cuenta.
      if v_banco is null then
        select m.cuenta, m.nombre_qb into v_qb, v_qbn
          from apertura_mapeo_qb m
         where m.tipo = 'cuenta' and m.cuenta is not null and m.cuenta <> v_cta and fn_banco_tipo_cuenta(m.cuenta) = 'banco'
           and m.nombre_qb ~ ('(^|[^0-9])' || v_u4 || '([^0-9]|$)')
         order by m.cuenta limit 1;
        if v_qb is not null then
          raise exception using errcode = 'MX004',
            message = format('El archivo es de la cuenta ····%s, que en QuickBooks es «%s» (%s), y dijiste %s: no se adivina. Sube '
                             'el de %s. %s', v_u4, v_qbn, v_qb, v_cta, v_cta, v_como);
        end if;
      end if;
    end if;
  else
    v_cta := coalesce(v_de_u4, v_banco);
    if v_cta is null then
      raise exception using errcode = 'MX004',
        message = format('No sé de qué cuenta es el archivo (la cuenta %s no está dada de alta): dilo con p_cuenta, la cuenta del '
                         'plan (''1010'' para Chase, ''1030'' para la reserva) o los 4 últimos de una tarjeta. Las siguientes '
                         'veces ya lo sabré.', coalesce('····' || v_u4, 'que trae'));
    end if;
  end if;
  if fn_puente_cuenta_mal(v_cta) is not null then
    raise exception using errcode = 'MX004', message = format('La cuenta del archivo: %s.', fn_puente_cuenta_mal(v_cta));
  end if;
  v_tipo := fn_banco_tipo_cuenta(v_cta);
  if v_tipo is null then
    raise exception using errcode = 'MX004',
      message = format('%s no es una cuenta de banco (10xx) ni una tarjeta de la empresa (tarjetas): ahí no llega un estado de '
                       'cuenta.', v_cta);
  end if;
  if p_tipo is not null and v_tipo <> p_tipo then
    raise exception using errcode = 'MX004',
      message = format('El archivo es de %s y la cuenta %s es %s.', case when p_tipo = 'tarjeta' then 'una tarjeta de crédito'
                                                                          else 'un banco' end,
                       v_cta, case when v_tipo = 'tarjeta' then 'una tarjeta' else 'un banco' end);
  end if;
  return v_cta;
end $$;
revoke execute on function public.fn_banco_cuenta_de(text, text, text, boolean) from public, anon, authenticated, service_role;
-- =====================================================================
-- 3 · IMPORTAR: el archivo del banco (OFX/QFX) y las filas ya leídas
--     (Plaid, los lectores CSV que vendrán en verde, o una a mano).
-- =====================================================================
-- EL MISMO MOVIMIENTO ENTRA UNA VEZ, o entra marcado «posible duplicado»
-- y espera: nunca dos veces en silencio. Por cada fila, en este orden:
--   0. su id ya salió antes EN ESTE MISMO archivo: con los mismos datos es
--      la misma fila repetida (una); con otros, el banco repitió el id para
--      otro movimiento (entra como nuevo, ver 1);
--   1. su id (el FITID del archivo, el de Plaid) ya está en esa cuenta y ese
--      origen, con la misma fecha y el mismo monto: es el mismo movimiento
--      (el archivo importado otra vez, o dos archivos que se solapan) →
--      repetida. Con OTRA fecha u otro monto no es el mismo: el banco
--      reutilizó el id (un emisor que numera sus FITID por archivo) → entra
--      como nuevo, con ese id solo de referencia, y se dice (aviso y
--      fitid_reusados). Antes se contaba como repetido y el movimiento no
--      entraba nunca;
--   2. hay un movimiento de esa cuenta con la misma fecha, el mismo monto y
--      la misma descripción normalizada que no tiene todavía un id de este
--      origen (entró por el otro camino: por Plaid si esta es del archivo,
--      o por archivo si esta es de Plaid; o sin id), y que esta misma
--      importación no usó ya → es él: repetida, y se le apunta este id. Y
--      el MISMO CHEQUE (su número y su monto, a 5 días o menos) es el mismo
--      movimiento aunque el banco le haya cambiado el FITID → repetida;
--   3. si no, entra marcado «posible duplicado de …» y NO se casa hasta que
--      Edgar diga si es el mismo (fn_banco_duplicado) cuando hay uno de esa
--      cuenta que esta importación no usó ya y que: (a) tiene el mismo
--      monto, a 3 días o menos, y entró por el otro camino (Plaid y el
--      archivo no lo fechan ni lo escriben igual: con otra descripción o con
--      la misma y otro día); (b) tiene la misma fecha, el mismo monto y la
--      misma descripción y entró por este camino con OTRO id (el banco
--      cambió el FITID entre dos descargas que se solapan); o (c) tiene el
--      mismo número de cheque con otro monto;
--   4. si no, es nuevo.
-- Dos cafés iguales el mismo día en el mismo archivo son dos: nada casa
-- con lo que entra en la misma importación, y el paso 2 y el 3 no usan dos
-- veces el mismo movimiento.
-- Lo de antes del corte (el 30-sep y antes) entra ignorado: está en
-- QuickBooks y en el saldo de apertura (si seguía en tránsito al 30-sep, lo
-- dice la conciliación de apertura). Un movimiento en 0, ignorado también.
-- EL TIEMPO: las filas se deciden una por una (con índices: su id, su
-- fecha y monto, su cheque) y se escriben todas de una vez; nada se copia
-- entero por cada fila (antes un archivo de un año, 3.000 movimientos, no
-- cabía en los 8 s de la API: el costo crecía con el cuadrado de las
-- filas).
-- Los candados: el del archivo (su sha256: el mismo archivo en dos
-- sesiones a la vez, la segunda espera y ve que ya estaba) y el de la
-- cuenta (dos importaciones de la misma cuenta se esperan, y la segunda ve
-- lo que metió la primera). Ninguno es del libro: importar no postea.
-- ---------------------------------------------------------------------
-- (Para buscar el mismo dinero por su monto, y el mismo cheque por su
-- número, sin recorrer todos los movimientos de la cuenta.)
create index if not exists movimientos_banco_cuenta_monto_idx  on public.movimientos_banco (cuenta, monto, fecha);
create index if not exists movimientos_banco_cheque_idx        on public.movimientos_banco (cuenta, (ltrim(cheque, '0')))
  where cheque is not null;
drop function if exists public.fn_banco_importar_interno(text, text, text, text, text, text, jsonb, int);
create or replace function public.fn_banco_importar_interno(p_cuenta text, p_origen text, p_formato text, p_nombre text,
                                                           p_texto text, p_sha text, p_leido jsonb, p_fuera int default 0,
                                                           p_confirmada boolean default false)
returns jsonb
language plpgsql
set search_path = public, pg_temp
-- (Cada fila se decide con búsquedas por índice. Sin esto, con las
-- estadísticas de una tabla recién vaciada o nunca analizada, el planificador
-- elegía recorrer la tabla entera en cada fila, y un archivo de 3.000
-- tardaba 15 s en vez de uno.)
set enable_seqscan = off
as $$
declare
  v_arch    uuid := gen_random_uuid();
  v_corte   date := fn_puente_corte();
  v_u4      text := fn_banco_limpio(p_leido->>'ultimos4');
  v_dec     jsonb[] := '{}';
  v_i       int := 0;
  v_usados  uuid[] := '{}';
  v_mm      movimientos_banco;
  v_m       uuid;
  v_dup     uuid;
  v_reusa   boolean;
  v_estado  text;
  v_motivo  text;
  v_nuevo   int := 0;
  v_rep     int := 0;
  v_posib   int := 0;
  v_antes   int := 0;
  v_cero    int := 0;
  v_reus    int := 0;
  v_reus_tx text[] := '{}';
  v_leidas  int := 0;
  v_avisos  jsonb := coalesce(p_leido->'avisos', '[]'::jsonb);
  v_iguales jsonb;
  r         record;
begin
  -- Primero se decide todo (sin escribir): el archivo es inmutable y entra
  -- de una vez con sus cuentas; después sus movimientos, todos juntos.
  for r in
    with f as (
      select t.o as ord, coalesce((t.x->>'n')::int, t.o::int) as n, (t.x->>'fecha')::date as fecha,
             nullif(t.x->>'fecha_transaccion', '')::date as fu, (t.x->>'monto')::numeric as monto,
             upper(fn_banco_limpio(t.x->>'tipo')) as tipo, fn_banco_limpio(t.x->>'cheque') as cheque,
             fn_banco_limpio(t.x->>'descripcion') as descripcion, fn_banco_limpio(t.x->>'memo') as memo,
             fn_banco_norm(coalesce(fn_banco_limpio(t.x->>'descripcion'), fn_banco_limpio(t.x->>'memo'))) as dn,
             fn_banco_limpio(t.x->>'id') as ext
        from jsonb_array_elements(coalesce(p_leido->'filas', '[]'::jsonb)) with ordinality as t(x, o))
    select f.*,
           case when f.ext is not null then first_value(f.ord) over w end as primera,
           first_value(f.fecha) over w as p_fecha, first_value(f.monto) over w as p_monto, first_value(f.dn) over w as p_dn
      from f
    window w as (partition by f.ext order by f.ord)
     order by f.ord
  loop
    v_leidas := v_leidas + 1;
    v_m := null;
    v_dup := null;
    v_reusa := false;
    -- 0. su id ya salió antes en este mismo archivo
    if r.primera is not null and r.primera < r.ord then
      if r.p_fecha = r.fecha and r.p_monto = r.monto and r.p_dn = r.dn then
        v_rep := v_rep + 1;
        continue;
      end if;
      v_reusa := true;
    end if;
    -- 1. su id ya está (en la base), con su fecha y su monto. (Por su
    -- llave, primero el id y después el movimiento: con un join, y la tabla
    -- con las estadísticas de vacía, el planificador recorría todos los ids
    -- de la cuenta en cada fila. Por lo mismo, abajo, las ventanas de fecha
    -- van como rangos y el monto fuera del «o»: cada búsqueda, por índice.)
    if r.ext is not null and not v_reusa then
      select m.* into v_mm
        from movimientos_banco m
       where m.id = (select i.movimiento_id from movimientos_banco_ids i
                      where i.cuenta = p_cuenta and i.origen = p_origen and i.id_externo = r.ext);
      if found then
        if v_mm.fecha = r.fecha and v_mm.monto = r.monto then
          v_m := v_mm.id;
        else
          -- ¿el que ya entró antes con ese mismo id reutilizado?
          select m.id into v_m
            from movimientos_banco m
           where m.cuenta = p_cuenta and m.origen = p_origen and m.id_externo = r.ext and m.fecha = r.fecha and m.monto = r.monto
             and not (m.id = any (v_usados))
           order by m.importado_el, m.fila
           limit 1;
          v_reusa := v_m is null;
        end if;
      end if;
    end if;
    -- 2. el mismo movimiento por el otro camino (o sin id)
    if v_m is null then
      select m.id into v_m
        from movimientos_banco m
       where m.cuenta = p_cuenta and m.fecha = r.fecha and m.monto = r.monto and m.desc_norm = r.dn
         and not (m.id = any (v_usados))
         and (r.ext is null
              or not exists (select 1 from movimientos_banco_ids i where i.movimiento_id = m.id and i.origen = p_origen))
       order by m.importado_el, m.archivo_id, m.fila
       limit 1;
    end if;
    -- 2. el mismo cheque (su número y su monto), aunque cambie su FITID
    if v_m is null and r.cheque is not null and ltrim(r.cheque, '0') <> '' then
      select m.id into v_m
        from movimientos_banco m
       where m.cuenta = p_cuenta and m.cheque is not null and ltrim(m.cheque, '0') = ltrim(r.cheque, '0')
         and m.monto = r.monto and m.fecha between r.fecha - 5 and r.fecha + 5
         and not (m.id = any (v_usados))
       order by abs(m.fecha - r.fecha), m.importado_el, m.fila
       limit 1;
    end if;
    if v_m is not null then
      v_rep := v_rep + 1;
      v_usados := v_usados || v_m;
      v_i := v_i + 1;
      v_dec[v_i] := jsonb_strip_nulls(jsonb_build_object('accion', 'repetida', 'mov', v_m, 'id', r.ext,
                                                          'sin_id', case when v_reusa then true end));
      continue;
    end if;
    -- 3. ¿posible duplicado?
    if r.monto <> 0 and r.fecha >= v_corte then
      -- (El monto y la ventana, fuera del «o»: los dos casos los piden, y
      -- así la búsqueda va siempre por el índice de monto y fecha.)
      select m.id into v_dup
        from movimientos_banco m
       where m.cuenta = p_cuenta and m.monto = r.monto and m.fecha between r.fecha - 3 and r.fecha + 3
         and m.estado <> 'ignorado' and not (m.id = any (v_usados))
         and ((r.ext is null
               or not exists (select 1 from movimientos_banco_ids i where i.movimiento_id = m.id and i.origen = p_origen))
              or (m.fecha = r.fecha and m.desc_norm = r.dn))
       order by abs(m.fecha - r.fecha), m.importado_el, m.fila
       limit 1;
      if v_dup is null and r.cheque is not null and ltrim(r.cheque, '0') <> '' then
        select m.id into v_dup
          from movimientos_banco m
         where m.cuenta = p_cuenta and m.cheque is not null and ltrim(m.cheque, '0') = ltrim(r.cheque, '0')
           and m.estado <> 'ignorado' and m.fecha between r.fecha - 60 and r.fecha + 60 and not (m.id = any (v_usados))
         order by abs(m.fecha - r.fecha), m.importado_el, m.fila
         limit 1;
      end if;
    end if;
    v_estado := 'pendiente';
    v_motivo := null;
    if r.fecha < v_corte then
      v_estado := 'ignorado';
      v_motivo := format('Del %s, antes del corte (%s): está en QuickBooks y en el saldo de apertura. Si seguía en tránsito al '
                         '30-sep, lo dice la conciliación de apertura.', r.fecha, v_corte);
      v_antes := v_antes + 1;
    elsif r.monto = 0 then
      v_estado := 'ignorado';
      v_motivo := 'El banco lo trae en 0: no mueve dinero.';
      v_cero := v_cero + 1;
    elsif v_dup is not null then
      v_motivo := 'posible_duplicado';
      v_posib := v_posib + 1;
      v_usados := v_usados || v_dup;
    end if;
    if v_reusa then
      v_reus := v_reus + 1;
      if cardinality(v_reus_tx) < 5 then
        v_reus_tx := v_reus_tx || format('%s: %s %s', r.ext, r.fecha, r.monto);
      end if;
    end if;
    v_nuevo := v_nuevo + 1;
    v_i := v_i + 1;
    v_dec[v_i] := jsonb_strip_nulls(jsonb_build_object(
      'accion', 'nueva', 'mov', gen_random_uuid(), 'ord', r.ord, 'fila', r.n, 'fecha', r.fecha, 'fecha_transaccion', r.fu,
      'monto', r.monto::text, 'tipo', r.tipo, 'cheque', r.cheque, 'descripcion', r.descripcion, 'memo', r.memo,
      'desc_norm', r.dn, 'id', r.ext, 'sin_id', case when v_reusa then true end, 'dup', v_dup, 'estado', v_estado,
      'motivo', v_motivo));
  end loop;
  if v_reus > 0 then
    v_avisos := v_avisos || to_jsonb(format('El banco repitió el identificador (FITID) de otro movimiento en %s fila(s) (%s%s): no es '
                                            'el mismo (otra fecha u otro monto), así que entraron como movimientos nuevos, con ese id '
                                            'solo de referencia.', v_reus, array_to_string(v_reus_tx, '; '),
                                            case when v_reus > 5 then '; …' else '' end));
  end if;
  -- (Ronda 4) El PRIMER estado de cuenta de un banco no se toma a ciegas:
  -- lo que dice el archivo frente a la cuenta elegida, y cómo retirarlo si
  -- no es de ella (antes el QFX de Chase subido a la reserva entraba sin
  -- aviso y no tenía vuelta).
  if p_formato in ('ofx_sgml', 'ofx_xml') and fn_banco_tipo_cuenta(p_cuenta) = 'banco'
     and not exists (select 1 from archivos_banco a
                      where a.cuenta = p_cuenta and a.retirado_el is null and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada)) then
    v_avisos := v_avisos || to_jsonb(format(
      'Es el primer estado de cuenta de %s (%s): el archivo dice %s····%s%s. Si no es de esta cuenta, retíralo antes de casar nada '
      '(desde el SQL Editor: select fn_banco_archivo_retirar(%L, ''el motivo'');) y súbelo a la suya.',
      p_cuenta, coalesce((select c.nombre from cuentas c where c.codigo = p_cuenta), 'sin nombre'),
      coalesce(nullif(fn_banco_limpio(p_leido->>'acct_tipo'), '') || ' ', ''), coalesce(v_u4, '????'),
      coalesce(', banco ' || fn_banco_limpio(p_leido->>'bankid'), ''), v_arch));
  end if;

  -- El archivo, entero y de una vez.
  perform fn_banco_marca('archivo:' || v_arch);
  insert into archivos_banco (id, cuenta, ultimos4, nombre, formato, sha256, texto, desde, hasta, saldo, saldo_al, moneda,
                              filas_leidas, filas_nuevas, filas_repetidas, filas_fuera, duplicados_posibles, avisos, cuenta_confirmada)
  values (v_arch, p_cuenta, v_u4, fn_banco_limpio(p_nombre), p_formato, p_sha, p_texto,
          nullif(p_leido->>'desde', '')::date, nullif(p_leido->>'hasta', '')::date, nullif(p_leido->>'saldo', '')::numeric,
          nullif(p_leido->>'saldo_al', '')::date, coalesce(p_leido->>'moneda', 'USD'),
          v_leidas + p_fuera, v_nuevo, v_rep, p_fuera, v_posib, v_avisos, coalesce(p_confirmada, false));

  -- Sus movimientos nuevos, de una vez, cada uno con su llave (n: los
  -- iguales que ya había, más su lugar entre los iguales de este archivo).
  -- Los iguales que ya había (misma fecha, monto y descripción) se cuentan
  -- ANTES de escribir, en una sola consulta: contados dentro del mismo
  -- insert, cada fila recorría en el índice las que ese insert acababa de
  -- meter (invisibles para él, pero ahí), y un archivo de 3.000 pagaba el
  -- cuadrado: más de un segundo solo en eso.
  select coalesce(jsonb_object_agg(x.k, x.n), '{}'::jsonb) into v_iguales
    from (select concat_ws('|', m.fecha, m.monto, m.desc_norm) as k, count(*) as n
            from movimientos_banco m
            join (select distinct (d->>'fecha')::date as fecha, round((d->>'monto')::numeric, 2) as monto, d->>'desc_norm' as dn
                    from unnest(v_dec) as u(d)
                   where d->>'accion' = 'nueva') q
              on m.cuenta = p_cuenta and m.fecha = q.fecha and m.monto = q.monto and m.desc_norm = q.dn
           group by 1) x;
  insert into movimientos_banco (id, cuenta, ultimos4, fecha, fecha_transaccion, monto, tipo_banco, cheque, descripcion, memo,
                                 desc_norm, origen, id_externo, llave, archivo_id, fila, posible_duplicado_de, estado, estado_motivo)
  select (d->>'mov')::uuid, p_cuenta, v_u4, (d->>'fecha')::date, (d->>'fecha_transaccion')::date, (d->>'monto')::numeric,
         d->>'tipo', d->>'cheque', d->>'descripcion', d->>'memo', d->>'desc_norm', p_origen, d->>'id',
         md5(concat_ws('|', p_cuenta, d->>'fecha', d->>'monto', d->>'desc_norm') || '|'
             || (coalesce((v_iguales->>concat_ws('|', (d->>'fecha')::date, round((d->>'monto')::numeric, 2), d->>'desc_norm'))::bigint, 0)
                 + row_number() over (partition by d->>'fecha', d->>'monto', d->>'desc_norm' order by (d->>'ord')::int))),
         v_arch, (d->>'fila')::int, (d->>'dup')::uuid, d->>'estado', d->>'motivo'
    from unnest(v_dec) as u(d)
   where d->>'accion' = 'nueva';
  -- Y sus ids (el de un movimiento nuevo; el de uno que ya estaba y llegó
  -- por el otro camino). Un id reutilizado por el banco no: ya es de otro.
  insert into movimientos_banco_ids (cuenta, origen, id_externo, movimiento_id, archivo_id)
  select p_cuenta, p_origen, d->>'id', (d->>'mov')::uuid, v_arch
    from unnest(v_dec) as u(d)
   where d ? 'id' and not d ? 'sin_id'
     and (d->>'accion' = 'nueva'
          or not exists (select 1 from movimientos_banco_ids i
                          where i.cuenta = p_cuenta and i.origen = p_origen and i.id_externo = d->>'id'));
  perform fn_banco_marca(null);

  return jsonb_strip_nulls(jsonb_build_object(
    'archivo', v_arch, 'ya_estaba', false, 'cuenta', p_cuenta, 'ultimos4', v_u4, 'formato', p_formato,
    'desde', p_leido->>'desde', 'hasta', p_leido->>'hasta', 'saldo', p_leido->>'saldo', 'saldo_al', p_leido->>'saldo_al',
    'filas_leidas', v_leidas + p_fuera, 'filas_nuevas', v_nuevo, 'filas_repetidas', v_rep, 'filas_fuera', p_fuera,
    'duplicados_posibles', v_posib, 'fitid_reusados', case when v_reus > 0 then v_reus end,
    'antes_del_corte', v_antes, 'en_cero', v_cero, 'cuenta_confirmada', case when p_confirmada then true end,
    'avisos', v_avisos,
    'siguiente', 'select fn_banco_casar_todo(' || quote_literal(p_cuenta) || ');'));
end $$;
revoke execute on function public.fn_banco_importar_interno(text, text, text, text, text, text, jsonb, int, boolean)
  from public, anon, authenticated, service_role;
-- Lo que devuelve una importación que ya estaba (el mismo sha256).
-- (Ronda 4: p_pedida, la cuenta a la que Edgar lo sube ahora: si entró a
-- OTRA, se dice —«ya entró, pero a 1030, no a 1010»— y cómo retirarlo de
-- allí para subirlo a la buena. Antes decía solo «ya entró… no entra nada»,
-- y no tenía vuelta. Un archivo retirado no cuenta.)
drop function if exists public.fn_banco_ya_importado(text);
create or replace function public.fn_banco_ya_importado(p_sha text, p_pedida text default null)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  select jsonb_strip_nulls(jsonb_build_object(
           'archivo', a.id, 'ya_estaba', true, 'cuenta', a.cuenta, 'ultimos4', a.ultimos4, 'formato', a.formato,
           'desde', a.desde, 'hasta', a.hasta, 'saldo', a.saldo, 'saldo_al', a.saldo_al, 'importado_el', a.importado_el,
           'filas_leidas', a.filas_leidas, 'filas_nuevas', 0, 'filas_repetidas', a.filas_leidas,
           'otra_cuenta', case when p_pedida is not null and p_pedida <> a.cuenta then true end,
           'aviso', case when p_pedida is not null and p_pedida <> a.cuenta
                         then format('Este archivo ya entró el %s (%s), pero a %s, no a %s: no se vuelve a leer, no entra nada. Si '
                                     'entró a la cuenta equivocada, retíralo de %s desde el SQL Editor (select '
                                     'fn_banco_archivo_retirar(%L, ''el motivo'');) y vuelve a subirlo a %s.',
                                     to_char(a.importado_el at time zone 'America/New_York', 'YYYY-MM-DD HH24:MI'),
                                     coalesce(a.nombre, 'sin nombre'), a.cuenta, p_pedida, a.cuenta, a.id, p_pedida)
                         else format('Este archivo ya entró el %s (%s): no se vuelve a leer, no entra nada.',
                                     to_char(a.importado_el at time zone 'America/New_York', 'YYYY-MM-DD HH24:MI'),
                                     coalesce(a.nombre, 'sin nombre')) end))
    from archivos_banco a
   where a.sha256 = p_sha and a.retirado_el is null
$$;
revoke execute on function public.fn_banco_ya_importado(text, text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_banco_importar_ofx(texto, cuenta, nombre) — lo que llama conta.js
-- con el archivo que Edgar sube (el texto entero, tal cual).
--   p_cuenta  opcional: la cuenta del plan ('1010') o los 4 últimos de una
--             tarjeta ('2013'). Sin ella, la dice el archivo (ACCTID) si la
--             tarjeta está dada de alta o si ya entró un archivo de esa
--             cuenta. La primera vez de Chase: p_cuenta = '1010'.
--   p_nombre  el nombre del archivo (para Edgar).
-- Devuelve { archivo, ya_estaba, cuenta, desde, hasta, saldo, saldo_al,
-- filas_leidas, filas_nuevas, filas_repetidas, duplicados_posibles,
-- antes_del_corte, en_cero, avisos, siguiente }. No casa ni postea nada:
-- después conta.js llama a fn_banco_casar_todo (así cada llamada cabe en
-- los 8 s de la API).
--   _rpc('fn_banco_importar_ofx', { p_texto: texto, p_cuenta: '1010', p_nombre: 'Chase_oct.qfx' })
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_importar_ofx(p_texto text, p_cuenta text default null, p_nombre text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sha   text;
  v_ya    jsonb;
  v_leido jsonb;
  v_cta   text;
begin
  perform fn_banco_exigir_dueno();
  if fn_banco_limpio(p_texto) is null then
    raise exception using errcode = 'MX009', message = 'El archivo está vacío.';
  end if;
  v_sha := encode(sha256(convert_to(p_texto, 'UTF8')), 'hex');
  perform pg_advisory_xact_lock(820261001, hashtext('archivo:' || v_sha));
  v_ya := fn_banco_ya_importado(v_sha, fn_banco_cuenta_resolver(p_cuenta));
  if v_ya is not null then
    return v_ya;
  end if;
  v_leido := fn_banco_ofx_leer(p_texto);
  v_cta := fn_banco_cuenta_de(p_cuenta, v_leido->>'ultimos4', v_leido->>'tipo');
  perform pg_advisory_xact_lock(820261001, hashtext('cuenta:' || v_cta));
  return fn_banco_importar_interno(v_cta, 'archivo', v_leido->>'formato', p_nombre, p_texto, v_sha, v_leido, 0);
end $$;
revoke execute on function public.fn_banco_importar_ofx(text, text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_importar_ofx(text, text, text) to authenticated;

-- LAS FILAS de un lote (Plaid, CSV, a mano) como las lee el importador: la
-- fecha, el monto con el signo del banco (el de Plaid, volteado), el
-- tipo, el cheque, la descripción, la nota y el id; y las pendientes de
-- Plaid, contadas aparte (no entran nunca). Lo usan fn_banco_importar_filas
-- y fn_banco_verificar (que relee cada lote guardado, fila por fila).
create or replace function public.fn_banco_lote_filas(p_lote jsonb, p_origen text)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_f      jsonb;
  v_i      int := 0;
  v_fuera  int := 0;
  v_filas  jsonb[] := '{}';
  v_nf     int := 0;
  v_sobra  text;
  v_monto  numeric;
  v_fecha  date;
  v_fu     date;
  v_min    date;
  v_max    date;
  v_pend   boolean;
begin
  for v_f in select value from jsonb_array_elements(p_lote->'filas') loop
    v_i := v_i + 1;
    if jsonb_typeof(v_f) <> 'object' then
      raise exception using errcode = '22023', message = format('Fila %s: va como objeto JSON.', v_i);
    end if;
    select string_agg(k, ', ' order by k) into v_sobra
      from jsonb_object_keys(v_f) k
     where k not in ('id', 'fecha', 'fecha_transaccion', 'monto', 'plaid_monto', 'descripcion', 'memo', 'tipo', 'cheque', 'pendiente');
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Fila %s: clave desconocida: %s.', v_i, v_sobra);
    end if;
    begin
      v_pend := coalesce((v_f->>'pendiente')::boolean, false);
    exception when others then
      raise exception using errcode = '22023', message = format('Fila %s: pendiente es true o false.', v_i);
    end;
    if v_pend then
      v_fuera := v_fuera + 1;   -- lo pendiente no entra nunca
      continue;
    end if;
    if p_origen = 'plaid' then
      if v_f ? 'monto' or not v_f ? 'plaid_monto' then
        raise exception using errcode = '22023',
          message = format('Fila %s: de Plaid llega "plaid_monto", el de Plaid tal cual (positivo = sale dinero); la base lo '
                           'voltea al signo del banco. No "monto".', v_i);
      end if;
      if fn_banco_limpio(v_f->>'id') is null then
        raise exception using errcode = '22023', message = format('Fila %s: una fila de Plaid trae su id (transaction_id).', v_i);
      end if;
      -- (con coma de miles o sin ella, como lo teclea Edgar o lo copia de un
      -- statement: fn_banco_saldo_texto; vacío, lo dice fn_banco_monto)
      v_monto := -coalesce(fn_banco_saldo_texto(v_f->>'plaid_monto', format('Fila %s: plaid_monto', v_i)),
                           fn_banco_monto(v_f->>'plaid_monto', format('Fila %s: plaid_monto', v_i)));
    else
      if v_f ? 'plaid_monto' then
        raise exception using errcode = '22023', message = format('Fila %s: plaid_monto es solo de Plaid; aquí va "monto".', v_i);
      end if;
      v_monto := coalesce(fn_banco_saldo_texto(v_f->>'monto', format('Fila %s: monto', v_i)),
                          fn_banco_monto(v_f->>'monto', format('Fila %s: monto', v_i)));
    end if;
    v_fecha := fn_puente_fecha_texto(v_f->>'fecha', format('Fila %s: la fecha', v_i));
    v_fu := case when fn_banco_limpio(v_f->>'fecha_transaccion') is not null
                 then fn_puente_fecha_texto(v_f->>'fecha_transaccion', format('Fila %s: la fecha de la transacción', v_i)) end;
    v_min := least(v_min, v_fecha);
    v_max := greatest(v_max, v_fecha);
    v_nf := v_nf + 1;
    v_filas[v_nf] := jsonb_strip_nulls(jsonb_build_object(
      'n', v_i, 'tipo', fn_banco_limpio(v_f->>'tipo'), 'fecha', v_fecha, 'fecha_transaccion', v_fu, 'monto', v_monto::text,
      'id', fn_banco_limpio(v_f->>'id'), 'cheque', fn_banco_limpio(v_f->>'cheque'),
      'descripcion', fn_banco_limpio(v_f->>'descripcion'), 'memo', fn_banco_limpio(v_f->>'memo')));
  end loop;
  return jsonb_build_object('filas', to_jsonb(v_filas), 'fuera', v_fuera, 'desde', v_min, 'hasta', v_max);
end $$;
revoke execute on function public.fn_banco_lote_filas(jsonb, text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_banco_importar_filas(lote) — el mismo contrato, para filas ya leídas:
-- Plaid (su función de borde, cuando llegue), los lectores CSV de cada
-- banco (verde) o un movimiento escrito a mano. El lote entero se guarda
-- como el «archivo» (su texto y su sha256): el mismo lote otra vez no se
-- lee.
--   { "origen": "plaid" | "csv" | "mano",
--     "cuenta": "1010" (o los 4 últimos de una tarjeta), "ultimos4": "4392",
--     "nombre": "Plaid 2026-10-12", "saldo": "25000.00" (csv y mano) |
--     "plaid_saldo": "25000.00" (plaid), "saldo_al": "2026-10-12",
--     "desde": "2026-10-01", "hasta": "2026-10-12",
--     "filas": [ { "id": "…", "fecha": "2026-10-05", "fecha_transaccion": "2026-10-04",
--                  "monto": "-245.37"  (csv y mano: con el signo del banco),
--                  "plaid_monto": "245.37" (plaid: el de Plaid TAL CUAL, que va al
--                                           revés: positivo = sale dinero; lo voltea la base),
--                  "descripcion": "HOME DEPOT #6345", "memo": "…", "tipo": "DEBIT",
--                  "cheque": "1043", "pendiente": false }, … ] }
-- EL SIGNO DEL SALDO, como el de las filas: en un lote de csv o a mano,
-- "saldo" va con el signo del LIBRO, como el LEDGERBAL de un QFX (en un
-- banco, lo que hay; en una tarjeta, lo que se debe en NEGATIVO; un saldo
-- positivo en una tarjeta es a favor de la empresa, y se avisa). De
-- Plaid, "plaid_saldo": su balances.current TAL CUAL (en una tarjeta, lo
-- que se debe en positivo), y la base lo pasa al signo del libro (en una
-- tarjeta, lo voltea), como voltea plaid_monto. Antes el saldo de Plaid
-- entraba sin voltear: la Amex salía con su deuda como saldo A FAVOR,
-- «Cuadrar» con el saldo del lote daba el doble de la diferencia y con el
-- del statement escrito pedía motivo todos los meses. Un lote de Plaid con
-- "saldo" (sin decir de qué signo) no entra (22023).
-- Solo lo POSTEADO: una fila de Plaid con "pendiente": true no entra (se
-- cuenta en filas_fuera; cuando Plaid la postee, llega con su propio id).
-- Plaid lleva el id de cada fila; en csv o mano es opcional (sin él, la
-- llave determinista).
-- "cuenta" es la cuenta del plan ("1010") o los 4 últimos de una tarjeta;
-- los 4 últimos del número de la cuenta del banco van en "ultimos4" (la
-- cuenta del plan no es un número de cuenta: antes un lote con "cuenta":
-- "1010" guardaba 1010 como sus 4 últimos, y el primer archivo de otra
-- cuenta que acabara en 1010 caía solo en Chase).
-- "confirmo_cuenta": true — Edgar dice, a sabiendas, que "ultimos4" es
-- ahora un número de "cuenta" (el banco se lo cambió): el lote queda como
-- esa confirmación (puede ir sin filas), y los archivos de ese número
-- entran a esa cuenta (ver fn_banco_cuenta_de).
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_importar_filas(p_lote jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_origen text;
  v_sobra  text;
  v_leido  jsonb;
  v_fuera  int := 0;
  v_texto  text;
  v_u4     text;
  v_conf   boolean;
  v_sha    text;
  v_ya     jsonb;
  v_cta    text;
  v_min    date;
  v_max    date;
  v_saldo  numeric;
  v_avisos jsonb := '[]'::jsonb;
begin
  perform fn_banco_exigir_dueno();
  if p_lote is null or jsonb_typeof(p_lote) <> 'object' then
    raise exception using errcode = '22023', message = 'El lote llega como un objeto JSON con sus filas.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p_lote) k
   where k not in ('origen', 'cuenta', 'ultimos4', 'nombre', 'saldo', 'plaid_saldo', 'saldo_al', 'desde', 'hasta', 'filas',
                   'confirmo_cuenta');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en el lote: %s.', v_sobra);
  end if;
  v_origen := lower(fn_banco_limpio(p_lote->>'origen'));
  if v_origen is null or v_origen not in ('plaid', 'csv', 'mano') then
    raise exception using errcode = '22023', message = 'El origen del lote es plaid, csv o mano.';
  end if;
  if jsonb_typeof(p_lote->'filas') is distinct from 'array' then
    raise exception using errcode = '22023', message = 'El lote trae sus filas (una lista).';
  end if;
  v_texto := p_lote::text;
  v_sha := encode(sha256(convert_to(v_texto, 'UTF8')), 'hex');
  perform pg_advisory_xact_lock(820261001, hashtext('archivo:' || v_sha));
  v_ya := fn_banco_ya_importado(v_sha, fn_banco_cuenta_resolver(p_lote->>'cuenta'));
  if v_ya is not null then
    return v_ya;
  end if;
  begin
    v_conf := coalesce((p_lote->>'confirmo_cuenta')::boolean, false);
  exception when others then
    raise exception using errcode = '22023', message = 'confirmo_cuenta es true o false.';
  end;
  -- Los 4 últimos del número de la cuenta: "ultimos4", o "cuenta" cuando
  -- son 4 dígitos que NO son una cuenta del plan (los de una tarjeta).
  v_u4 := coalesce(fn_banco_limpio(p_lote->>'ultimos4'),
                   case when fn_banco_limpio(p_lote->>'cuenta') ~ '^[0-9]{4}$'
                         and not exists (select 1 from cuentas c where c.codigo = fn_banco_limpio(p_lote->>'cuenta'))
                        then fn_banco_limpio(p_lote->>'cuenta') end);
  if v_conf and (v_u4 is null or not exists (select 1 from cuentas c where c.codigo = fn_banco_limpio(p_lote->>'cuenta'))) then
    raise exception using errcode = '22023',
      message = 'Confirmar el número de una cuenta dice la cuenta del plan ("cuenta": "1010") y sus 4 últimos ("ultimos4").';
  end if;
  v_cta := fn_banco_cuenta_de(p_lote->>'cuenta', v_u4, null, v_conf);
  v_leido := fn_banco_lote_filas(p_lote, v_origen);
  v_fuera := (v_leido->>'fuera')::int;
  v_min := (v_leido->>'desde')::date;
  v_max := (v_leido->>'hasta')::date;
  -- El saldo, con el signo del libro (ver arriba): el de Plaid, volteado en
  -- una tarjeta; el de un lote a mano o en CSV, tal cual (con coma de miles
  -- o sin ella), y si una tarjeta llega en positivo, se avisa.
  if v_origen = 'plaid' then
    if p_lote ? 'saldo' then
      raise exception using errcode = '22023',
        message = 'Un lote de Plaid trae su saldo como lo da Plaid, en "plaid_saldo" (balances.current tal cual: en una tarjeta, lo '
                  'que se debe en positivo); la base lo pasa al signo del libro. No "saldo".';
    end if;
    if fn_banco_limpio(p_lote->>'plaid_saldo') is not null then
      v_saldo := coalesce(fn_banco_saldo_texto(p_lote->>'plaid_saldo', 'El saldo del lote (plaid_saldo)'),
                          fn_banco_monto(p_lote->>'plaid_saldo', 'El saldo del lote (plaid_saldo)'));
      if fn_banco_tipo_cuenta(v_cta) = 'tarjeta' then
        v_saldo := -v_saldo;
      end if;
    end if;
  else
    if p_lote ? 'plaid_saldo' then
      raise exception using errcode = '22023',
        message = 'plaid_saldo es solo de Plaid; aquí va "saldo", con el signo del libro (en una tarjeta, lo que se debe en negativo, '
                  'como el LEDGERBAL del QFX).';
    end if;
    if fn_banco_limpio(p_lote->>'saldo') is not null then
      v_saldo := coalesce(fn_banco_saldo_texto(p_lote->>'saldo', 'El saldo del lote'),
                          fn_banco_monto(p_lote->>'saldo', 'El saldo del lote'));
      if fn_banco_tipo_cuenta(v_cta) = 'tarjeta' and v_saldo > 0 then
        v_avisos := v_avisos || to_jsonb(format('El saldo de la tarjeta llegó en positivo (%s): con el signo del libro, lo que se debe va '
                                                'en negativo y positivo es un saldo A FAVOR de la empresa. Si %s es lo que se debe, el '
                                                'lote lleva "saldo": "-%s" (y se vuelve a subir).', v_saldo, v_saldo, v_saldo));
      end if;
    end if;
  end if;
  if v_conf then
    v_avisos := v_avisos || to_jsonb(format('Edgar confirmó que la cuenta ····%s es de %s.', v_u4, v_cta));
  end if;
  perform pg_advisory_xact_lock(820261001, hashtext('cuenta:' || v_cta));
  return fn_banco_importar_interno(v_cta, v_origen, v_origen, p_lote->>'nombre', v_texto, v_sha,
    jsonb_strip_nulls(jsonb_build_object(
      'ultimos4', v_u4,
      'desde', coalesce(case when fn_banco_limpio(p_lote->>'desde') is not null
                             then fn_puente_fecha_texto(p_lote->>'desde', 'desde') end, v_min),
      'hasta', coalesce(case when fn_banco_limpio(p_lote->>'hasta') is not null
                             then fn_puente_fecha_texto(p_lote->>'hasta', 'hasta') end, v_max),
      'saldo', v_saldo::text,
      'saldo_al', case when fn_banco_limpio(p_lote->>'saldo_al') is not null
                       then fn_puente_fecha_texto(p_lote->>'saldo_al', 'saldo_al') end,
      'filas', v_leido->'filas',
      'avisos', case when jsonb_array_length(v_avisos) > 0 then v_avisos end)),
    v_fuera, v_conf);
end $$;
revoke execute on function public.fn_banco_importar_filas(jsonb) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_importar_filas(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- fn_banco_archivo_retirar(archivo, motivo) — (ronda 4) el archivo que
-- entró a la cuenta EQUIVOCADA: el primer QFX de Chase subido a la reserva
-- (1030), que entraba sin aviso y no tenía vuelta (el mismo archivo a 1010
-- decía «ya entró… no entra nada», una descarga nueva daba MX004 por «la
-- cuenta de sus estados de cuenta», la comisión de R7 no se podía quitar y
-- la reserva se quedaba con el saldo de Chase). Solo desde el SQL Editor,
-- con su motivo:
--   select fn_banco_archivo_retirar('<archivo>', 'era el QFX de Chase: lo subí a 1030 por error');
-- No borra ni cambia lo que dijo el banco: cada movimiento del archivo se
-- des-casa SIN volver a casar (lo que su casado posteó se reversa; una
-- transferencia, por el lado que la posteó: su otro lado vuelve a la
-- bandeja) y queda ignorado con el motivo; el archivo queda retirado
-- (quién, cuándo, por qué) y deja de contar para su cuenta: su saldo, su
-- número (····4392 ya no es de 1030) y su sha256 (se sube otra vez a la
-- cuenta buena, y entra). No se retira dentro de una conciliación
-- confirmada (se reabre antes), ni con un cobro o una devolución casados
-- con sus movimientos (son papeles de c3 a esa cuenta: se des-casan y se
-- anulan antes, y se dice cuáles).
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_archivo_retirar(p_archivo uuid, p_motivo text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  a        archivos_banco;
  v_motivo text := fn_banco_limpio(p_motivo);
  v_conc   conciliaciones;
  v_txt    text;
  r        record;
  v_n      int := 0;
  v_desc   int := 0;
  v_rev    text[] := '{}';
  v_res    jsonb;
  v_dueno  uuid;
begin
  perform fn_banco_exigir_dueno();
  if coalesce(length(v_motivo), 0) < 3 then
    raise exception using errcode = '22023', message = 'Retirar un archivo del banco dice por qué (motivo): queda escrito.';
  end if;
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  select * into a from archivos_banco where id = p_archivo for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese archivo del banco.';
  end if;
  if a.retirado_el is not null then
    raise exception using errcode = 'MX008',
      message = format('Ese archivo ya está retirado (el %s: %s).', a.retirado_el::date, a.retirado_motivo);
  end if;
  perform pg_advisory_xact_lock(820261001, hashtext('cuenta:' || a.cuenta));
  -- Dentro de una conciliación confirmada de su cuenta, no.
  select c.* into v_conc
    from conciliaciones c
   where c.cuenta = a.cuenta and c.estado = 'confirmada' and c.tipo = 'normal'
     and exists (select 1 from movimientos_banco m
                  where m.archivo_id = a.id and m.fecha <= c.fecha_corte and m.estado <> 'ignorado')
   order by c.fecha_corte desc
   limit 1;
  if found then
    raise exception using errcode = 'MX008',
      message = format('La conciliación de %s al %s está confirmada con movimientos de este archivo: reábrela antes (de la última hacia '
                       'atrás, fn_conciliacion_reabrir, con su motivo) y vuelve a retirarlo.', v_conc.cuenta, v_conc.fecha_corte);
  end if;
  -- Un cobro o una devolución (papeles de c3) casados con sus movimientos:
  -- se des-casan y se anulan antes (están en esa cuenta del libro).
  select string_agg(format('%s del %s por %s (%s %s)', m.descripcion, m.fecha, m.monto, m.casado_clase, m.casado_ref), '; '
                    order by m.fecha)
    into v_txt
    from movimientos_banco m
   where m.archivo_id = a.id and m.estado in ('casado', 'en_transito') and m.casado_clase in ('cobro', 'devolucion');
  if v_txt is not null then
    raise exception using errcode = 'MX008',
      message = format('Antes de retirarlo: estos movimientos están casados con un cobro o una devolución en %s: %s. Des-cásalos '
                       '(fn_banco_descasar, con su motivo) y anula ese papel (fn_cobro_anular; la devolución, con su cobro), y '
                       'vuelve a retirarlo.', a.cuenta, v_txt);
  end if;
  for r in select m.* from movimientos_banco m where m.archivo_id = a.id order by m.fecha, m.fila loop
    if r.estado in ('casado', 'en_transito') then
      -- (una transferencia que posteó el OTRO lado: se deshace por él, y
      -- el asiento se reversa entero)
      v_dueno := r.id;
      if r.casado_clase = 'transferencia' then
        select bc.movimiento_id into v_dueno
          from banco_casados bc
         where bc.asiento_id = r.asiento_id and bc.posteado and bc.deshecho_el is null
         limit 1;
        v_dueno := coalesce(v_dueno, r.id);
      end if;
      v_res := fn_banco_descasar_interno(v_dueno, 'Retirado (el archivo entró a la cuenta equivocada): ' || v_motivo);
      v_desc := v_desc + 1;
      if v_res->>'reverso' is not null then
        v_rev := v_rev || (v_res->>'reverso');
      end if;
      -- (si se deshizo por el otro lado y este quedó casado con algo más)
      if exists (select 1 from movimientos_banco x where x.id = r.id and x.estado in ('casado', 'en_transito')) then
        v_res := fn_banco_descasar_interno(r.id, 'Retirado (el archivo entró a la cuenta equivocada): ' || v_motivo);
        if v_res->>'reverso' is not null then
          v_rev := v_rev || (v_res->>'reverso');
        end if;
      end if;
    end if;
    perform fn_banco_marca('movimiento:' || r.id);
    update movimientos_banco
       set estado = 'ignorado', propuesta = null,
           estado_motivo = format('Retirado: el archivo «%s» entró a %s por error (%s).', coalesce(a.nombre, a.id::text), a.cuenta,
                                  v_motivo)
     where id = r.id;
    perform fn_banco_marca(null);
    v_n := v_n + 1;
  end loop;
  perform fn_banco_marca('retirar:' || a.id);
  update archivos_banco set retirado_motivo = v_motivo where id = a.id;
  perform fn_banco_marca(null);
  return jsonb_strip_nulls(jsonb_build_object(
    'archivo', a.id, 'cuenta', a.cuenta, 'nombre', a.nombre, 'retirado', true, 'movimientos', v_n, 'descasados', v_desc,
    'reversos', case when cardinality(v_rev) > 0 then to_jsonb(v_rev) end, 'motivo', v_motivo,
    'siguiente', 'Súbelo a su cuenta: fn_banco_importar_ofx(texto, ''<la cuenta buena>'', nombre). Y recalcula la conciliación '
                 'abierta de ' || a.cuenta || ' si la hay (fn_conciliar).'));
end $$;
revoke execute on function public.fn_banco_archivo_retirar(uuid, text) from public, anon, authenticated, service_role;
-- =====================================================================
-- 4 · EL CASADO: cada movimiento con lo que lo explica en el libro.
-- =====================================================================
-- PRIMERO CASAR, DESPUÉS CLASIFICAR (f05, aporte 10): el gasto que ya
-- entró por su ticket (c3) se CASA con el cargo del banco; clasificarlo
-- otra vez lo metería dos veces. Una línea del banco jamás se contabiliza
-- dos veces: un movimiento tiene un casado vivo, y una línea del libro
-- casa con un movimiento vivo (índices únicos).
-- Lo AUTOMÁTICO es solo el cruce exacto y las reglas fijas; todo lo demás
-- propone y espera a Edgar. Determinista: con el mismo libro y los mismos
-- movimientos, el mismo resultado (un empate no se desempata a ciegas: se
-- propone). En este orden:
--   R0  lo de antes del corte y lo que vale 0: ignorado al importar.
--   R-  un papel que YA nombra al movimiento (el cobro o la devolución que
--       Edgar registró con su movimiento_id) casa con su asiento.
--   R1  cargo de tarjeta o débito ↔ recibo ya contabilizado por c3 con esa
--       tarjeta (la línea de su asiento en esa cuenta, por el mismo
--       monto), con la fecha del ticket dentro de su VENTANA
--       (fn_banco_ventana: de 3 días antes de la compra —DTUSER, si el
--       banco la trae; si no, 7 antes del día del banco— a 3 después; un
--       cheque, hasta 60 días antes si el papel dice su número): cruce
--       exacto. También un ticket repartido entre obras (la misma foto en
--       dos recibos que suman el cargo). Y cualquier línea del libro que ya
--       esté (un asiento a mano, la nómina, la otra mitad de una
--       transferencia, una cuota): el cruce exacto con el libro. Automático
--       solo si es MUTUO: el movimiento tiene una sola línea candidata y
--       esa línea un solo movimiento. La línea de un devengo (un asiento
--       reversible: el libro lo reversa solo el día 1) no explica nada.
--       Un cargo ya CLASIFICADO cuyo ticket llega después no se deja
--       pasar callado: la bandeja lo dice («llego_su_ticket»), el control y
--       la conciliación también, y Edgar cambia la clasificación por el
--       ticket (fn_banco_casar_con) o dice que es otra compra.
--   R2  depósito ↔ cobro vigente sin movimiento (su línea en el banco,
--       mismo monto, en su ventana): casa y escribe cobros.movimiento_id
--       (lo que c3 deja: de nulo a su valor). También dos o tres cobros sin
--       movimiento que lo suman al centavo (los cheques anotados uno por
--       factura y depositados juntos), si la combinación es única y mutua.
--       Un depósito sin cobro PROPONE las facturas abiertas que lo explican
--       (una, o dos que suman) y espera a fn_banco_cobrar. Un Zelle de
--       Edgar propone aporte (3100) o préstamo del accionista (2900). Un
--       depósito NUNCA va a ingreso (a 4900, solo con su motivo escrito).
--   R3  pago de tarjeta y transferencias entre cuentas propias: el mismo
--       dinero en los dos estados de cuenta, con signo contrario, en su
--       DIRECCIÓN (sale de un banco; el lado que entra, del día en que sale
--       a 10 días después) y con el descriptor en la descripción del banco
--       (NAME) del lado que sale: UN asiento (Dr 2100-x / Cr 1010; Dr 1030
--       / Cr 1010) con la fecha del primero, y los dos casados con él. Si
--       solo llegó un lado, se propone y Edgar lo confirma
--       (fn_banco_transferencia): se postea con su contrapartida, y el otro
--       lado, cuando llegue, casa con ESE asiento (R1). Nunca dos.
--   R4  pago a proveedor (por su nombre o sus alias de c3, o un cheque
--       por lo que se le debe): se propone aplicarlo a lo que se le debe en
--       2010 (primero lo que traía QuickBooks en la apertura, después sus
--       papeles, lo más viejo primero) y espera a fn_banco_pagar_proveedor.
--       Nunca a 5100. Una compra con la débito en su mostrador (nada dice
--       pago y no cuadra con lo que se le debe) es un cargo sin ticket; el
--       pago queda como otra opción.
--   R5  retiro de cajero: pregunta «¿caja chica (1050) o para ti (3200)?».
--   R6  débito de nómina (Gusto): espera al journal de f11 y lo dice; la
--       del proveedor anterior, su journal con fn_banco_nomina.
--   R7  intereses del banco → 4910 y cargos del banco o de la tarjeta →
--       6130: reglas FIJAS (automáticas) solo si el tipo del banco (INT;
--       FEE o SRVCHG), el signo y el descriptor dicen lo mismo; si solo
--       uno lo dice, se propone.
--   R8  cuota de un préstamo (su descriptor): propone la partición y espera
--       a fn_prestamo_cuota (el statement del prestamista manda).
--   R9  cheque devuelto o reverso: propone la devolución del cobro
--       (fn_banco_devolver, que llama a fn_cobro_devolver con el
--       movimiento).
--   R10 lo demás, a la bandeja con su propuesta y su motivo; Edgar lo
--       resuelve con fn_banco_clasificar (o fn_banco_ignorar). Un cargo sin
--       ticket propone la obra con visita ese día (eventos), si es una.
-- Los candados, en el orden de la app: el del casado (uno para todo el
-- banco: dos casados a la vez se esperan), la fila del movimiento, los de
-- c3 si registra un cobro, periodos y la cadena (los toma el libro al
-- postear). Ninguno de la app espera al del casado.
-- ---------------------------------------------------------------------

-- EL ASIENTO de un papel del banco (un movimiento, una cuota, un mes de
-- prepagados), por el camino de los puentes: su fecha con la regla del
-- documento tardío de c3 (fn_puente_fecha: con su mes cerrado, el primer
-- día del mes abierto; de un ejercicio anterior, como su ajuste), y si ese
-- papel ya tuvo un asiento reversado, el nuevo dice a cuál sustituye (c2).
create or replace function public.fn_banco_asiento(p_origen_tabla text, p_origen_id text, p_fecha date, p_descripcion text,
                                                   p_lineas jsonb, p_procedencia jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_fecha jsonb := fn_puente_fecha(p_fecha);
  v_sust  uuid  := fn_puente_sustituible(p_origen_tabla, p_origen_id);
  v_res   jsonb;
begin
  perform 1 from periodos for share;
  v_res := fn_postear_interno(
    jsonb_build_object('camino', 'puente', 'fecha', v_fecha->>'fecha', 'descripcion', left(p_descripcion, 500),
                       'lineas', p_lineas, 'origen_tabla', p_origen_tabla, 'origen_id', p_origen_id,
                       'procedencia', coalesce(p_procedencia, '{}'::jsonb)
                                      || jsonb_build_object('fecha_documento', p_fecha)
                                      || case when v_fecha ? 'nota'
                                              then jsonb_build_object('tardio', v_fecha->>'nota') else '{}'::jsonb end
                                      || case when v_sust is not null
                                              then jsonb_build_object('sustituye', (select a.numero from asientos a where a.id = v_sust))
                                              else '{}'::jsonb end)
    || case when v_fecha->>'tipo' = 'ajuste_cpa'
            then jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', v_fecha->>'afecta_periodo', 'motivo', v_fecha->>'nota')
            else '{}'::jsonb end
    || case when v_sust is not null then jsonb_build_object('sustituye_a', v_sust) else '{}'::jsonb end);
  return v_res || jsonb_strip_nulls(jsonb_build_object('tardio', v_fecha->>'nota'));
end $$;
revoke execute on function public.fn_banco_asiento(text, text, date, text, jsonb, jsonb) from public, anon, authenticated, service_role;

-- (Ronda 4) EL ASIENTO CON LAS LÍNEAS QUE ESCRIBIÓ EDGAR (fn_banco_clasificar,
-- fn_banco_nomina). La línea 1 del asiento es la del banco y las de Edgar
-- van detrás: lo que c2 rechaza al postear —la obra que falta o que no
-- existe, el cost code, la cuenta inactiva o de grupo: «Línea N: …»— se
-- dice con el número de Edgar (N − 1), y lo de la línea 1, como «la línea
-- del banco». Antes Edgar mandaba una sola línea y el error le hablaba de
-- la «Línea 2». (Lo demás sale tal cual, con su código.)
create or replace function public.fn_banco_asiento_edgar(p_origen_tabla text, p_origen_id text, p_fecha date, p_descripcion text,
                                                         p_lineas jsonb, p_procedencia jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_estado text;
  v_msg    text;
  v_det    text;
  v_hint   text;
  v_n      int;
begin
  return fn_banco_asiento(p_origen_tabla, p_origen_id, p_fecha, p_descripcion, p_lineas, p_procedencia);
exception when others then
  get stacked diagnostics v_estado = returned_sqlstate, v_msg = message_text, v_det = pg_exception_detail,
                          v_hint = pg_exception_hint;
  v_n := substring(v_msg from '^Línea ([0-9]{1,6}):')::int;
  if v_n = 1 then
    v_msg := regexp_replace(v_msg, '^Línea 1:', format('La línea del banco (%s):', p_lineas->0->>'cuenta'));
  elsif v_n > 1 then
    v_msg := regexp_replace(v_msg, '^Línea [0-9]{1,6}:', format('Línea %s:', v_n - 1));
  end if;
  v_det := nullif(v_det, '');
  v_hint := nullif(v_hint, '');
  if v_det is null and v_hint is null then
    raise exception using errcode = v_estado, message = v_msg;
  elsif v_hint is null then
    raise exception using errcode = v_estado, message = v_msg, detail = v_det;
  elsif v_det is null then
    raise exception using errcode = v_estado, message = v_msg, hint = v_hint;
  else
    raise exception using errcode = v_estado, message = v_msg, detail = v_det, hint = v_hint;
  end if;
end $$;
revoke execute on function public.fn_banco_asiento_edgar(text, text, date, text, jsonb, jsonb)
  from public, anon, authenticated, service_role;

-- Lo que un asiento guarda del movimiento que lo originó (su procedencia).
create or replace function public.fn_banco_proc(m public.movimientos_banco, p_funcion text, p_regla text)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  select jsonb_strip_nulls(jsonb_build_object(
           'funcion', p_funcion, 'regla', p_regla,
           'movimiento', jsonb_build_object('id', m.id, 'cuenta', m.cuenta, 'fecha', m.fecha, 'monto', m.monto,
                                            'descripcion', m.descripcion, 'memo', m.memo, 'tipo', m.tipo_banco,
                                            'cheque', m.cheque, 'id_externo', m.id_externo, 'origen', m.origen,
                                            'archivo', m.archivo_id)))
$$;
revoke execute on function public.fn_banco_proc(public.movimientos_banco, text, text) from public, anon, authenticated, service_role;

-- La clase de un casado con una línea que ya estaba, por el papel de su
-- asiento.
create or replace function public.fn_banco_clase_de(p_asiento uuid)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select case a.origen_tabla
           when 'recibos' then 'recibo'
           when 'cobros' then 'cobro'
           when 'cobros_devoluciones' then 'devolucion'
           when 'prestamo_cuotas' then 'cuota_prestamo'
           when 'movimientos_banco' then case when a.procedencia->>'regla' like 'R3%' then 'transferencia' else 'asiento' end
           else 'asiento' end
    from asientos a where a.id = p_asiento
$$;
revoke execute on function public.fn_banco_clase_de(uuid) from public, anon, authenticated, service_role;

-- La transferencia: sus movimientos casados quedan «en tránsito» mientras
-- alguna línea del asiento en una cuenta propia (el otro estado de cuenta)
-- no tiene todavía su movimiento; con todas casadas, «casado».
create or replace function public.fn_banco_transferencia_estado(p_asiento uuid)
returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_todas boolean;
  r       record;
begin
  select not exists (select 1 from asiento_lineas l
                      where l.asiento_id = p_asiento and fn_banco_es_propia(l.cuenta)
                        and not exists (select 1 from banco_casado_lineas cl
                                         where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente))
    into v_todas;
  for r in select m.id, m.estado from movimientos_banco m
            join banco_casados c on c.id = m.casado_id and c.deshecho_el is null
           where c.asiento_id = p_asiento and m.estado in ('casado', 'en_transito') loop
    if r.estado <> (case when v_todas then 'casado' else 'en_transito' end) then
      perform fn_banco_marca('movimiento:' || r.id);
      update movimientos_banco set estado = case when v_todas then 'casado' else 'en_transito' end where id = r.id;
      perform fn_banco_marca(null);
    end if;
  end loop;
end $$;
revoke execute on function public.fn_banco_transferencia_estado(uuid) from public, anon, authenticated, service_role;

-- UNA PARTIDA DE LA APERTURA, AL DÍA: lo que ya llegó de ella (los
-- movimientos casados con ella, vivos) contra su monto. Completa, dice con
-- qué movimiento terminó de llegar (el último); a medias o sin nada, nada
-- (y la conciliación la sigue enseñando por lo que falta). La llaman casar
-- y des-casar: una partida que el banco trae en dos (el depósito del 30-sep
-- en dos depósitos móviles) casa con los dos.
create or replace function public.fn_banco_apertura_resolver(p_partida uuid)
returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_pa   conciliacion_partidas;
  v_suma numeric;
  v_ult  uuid;
begin
  select * into v_pa from conciliacion_partidas where id = p_partida;
  if not found then
    return;
  end if;
  select coalesce(sum(m.monto), 0), (array_agg(m.id order by m.fecha desc, m.importado_el desc, m.fila desc))[1]
    into v_suma, v_ult
    from banco_casados bc
    join movimientos_banco m on m.id = bc.movimiento_id
   where bc.clase = 'apertura' and bc.deshecho_el is null and bc.referencia = p_partida::text;
  perform fn_banco_marca('resolver:' || p_partida);
  if v_suma = v_pa.monto then
    update conciliacion_partidas
       set resuelta_por_movimiento = v_ult, resuelta_en = case when resuelta_por_movimiento = v_ult then resuelta_en end
     where id = p_partida and resuelta_por_movimiento is distinct from v_ult;
  else
    update conciliacion_partidas set resuelta_por_movimiento = null, resuelta_en = null
     where id = p_partida and (resuelta_por_movimiento is not null or resuelta_en is not null);
  end if;
  perform fn_banco_marca(null);
end $$;
revoke execute on function public.fn_banco_apertura_resolver(uuid) from public, anon, authenticated, service_role;

-- ¿Puede casar este lado de una transferencia con el asiento que ya está?
-- Un asiento para los dos lados lleva UNA fecha; si este lado llegó ANTES
-- que la fecha del asiento, casar lo rehace con la fecha de este lado (ver
-- fn_banco_transferencia_rehacer): el asiento se mueve hacia atrás y el
-- otro lado se suelta y se vuelve a casar. Dentro de una conciliación
-- CONFIRMADA de cualquiera de las dos cuentas (su corte en la fecha nueva o
-- después) eso la cambia por detrás: su saldo en libros deja de ser el que
-- se confirmó, o un movimiento suyo se casa otra vez. Antes el motor lo
-- hacía solo al importar el otro estado de cuenta (el pago de la Amex del
-- 2-nov en Chase, con octubre ya confirmado, y la Amex que lo acredita el
-- 30-oct: Chase al 31-oct pasaba de 48,200.37 a 44,788.19 en libros sin
-- reabrirla). Devuelve cuál conciliación lo impide (y qué hacer), o nulo.
create or replace function public.fn_banco_transferencia_bloqueo(p_mov uuid, p_asiento uuid)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select format('la conciliación de %s al %s está confirmada y casar este lado (del %s) mueve el asiento de la transferencia (%s, '
                'del %s) a esa fecha, dentro de ella: reábrela (fn_conciliacion_reabrir, con su motivo), casa este lado y vuelve '
                'a conciliarla', cc.cuenta, cc.fecha_corte, m.fecha, a.numero, a.fecha_contable)
    from movimientos_banco m
    join asientos a on a.id = p_asiento
    join lateral (select c.cuenta, c.fecha_corte
                    from conciliaciones c
                   where c.estado = 'confirmada' and c.fecha_corte >= m.fecha
                     and c.cuenta in (select l.cuenta from asiento_lineas l where l.asiento_id = p_asiento)
                   order by c.fecha_corte, c.cuenta limit 1) cc on true
   where m.id = p_mov and m.fecha < a.fecha_contable
$$;
revoke execute on function public.fn_banco_transferencia_bloqueo(uuid, uuid) from public, anon, authenticated, service_role;

-- EL CORTE DEL ESTADO DE CUENTA de una cuenta entre dos fechas (el
-- primero), o nulo. Lo que se sabe, en este orden: una conciliación suya
-- con su corte ahí (abierta o confirmada); el día en que corta esa
-- cuenta, el de su última conciliación (fin de mes si fue un fin de mes:
-- la Gold el 22, Chase el 31); y si todavía no tiene ninguna (el primer
-- mes): un banco, fin de mes (Chase y la reserva se concilian a fin de
-- mes); una tarjeta, un archivo suyo que termina ahí (su «hasta» o la
-- fecha de su saldo: el estado de cuenta exportado acaba ese día). Una
-- tarjeta sin conciliaciones ni archivo que corte ahí no se supone: si
-- cortara ahí, su conciliación lo dice y dice qué reabrir
-- (fn_conciliacion_items).
-- (Ronda 4, ver fn_banco_tr_fecha.)
create or replace function public.fn_banco_corte_entre(p_cuenta text, p_desde date, p_hasta date)
returns date
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_uc   date;
  v_tipo text := fn_banco_tipo_cuenta(p_cuenta);
  v_d    date;
begin
  if p_desde is null or p_hasta is null or p_hasta < p_desde then
    return null;
  end if;
  select min(c.fecha_corte) into v_d
    from conciliaciones c
   where c.cuenta = p_cuenta and c.tipo = 'normal' and c.fecha_corte between p_desde and p_hasta;
  if v_d is not null then
    return v_d;
  end if;
  select c.fecha_corte into v_uc
    from conciliaciones c where c.cuenta = p_cuenta and c.tipo = 'normal'
   order by c.fecha_corte desc limit 1;
  if v_uc is null and v_tipo is distinct from 'banco' then
    select min(x.d) into v_d
      from (select a.hasta as d from archivos_banco a
             where a.cuenta = p_cuenta and a.hasta between p_desde and p_hasta and a.retirado_el is null
            union all
            select a.saldo_al from archivos_banco a
             where a.cuenta = p_cuenta and a.saldo is not null and a.saldo_al between p_desde and p_hasta and a.retirado_el is null) x;
    return v_d;
  end if;
  -- (el día de corte: el de la última, o fin de mes)
  select min(g.d::date) into v_d
    from generate_series(p_desde, least(p_hasta, p_desde + 400), interval '1 day') as g(d)
   where case when v_uc is null or v_uc = (date_trunc('month', v_uc) + interval '1 month - 1 day')::date
              then g.d::date = (date_trunc('month', g.d) + interval '1 month - 1 day')::date
              else extract(day from g.d) = extract(day from v_uc)
                   or (extract(day from v_uc) > extract(day from (date_trunc('month', g.d) + interval '1 month - 1 day'))
                       and g.d::date = (date_trunc('month', g.d) + interval '1 month - 1 day')::date) end;
  return v_d;
end $$;
revoke execute on function public.fn_banco_corte_entre(text, date, date) from public, anon, authenticated, service_role;

-- LA FECHA DE UN ASIENTO NUEVO ENTRE DOS CUENTAS PROPIAS: la transferencia
-- que pone R3 con sus dos lados, fn_banco_casar_con con {"movimiento"}, o
-- fn_banco_transferencia con el lado que llegó (p_f2 nulo: el otro no ha
-- llegado). p_monto1: el del primer lado (el otro lleva el contrario). Un
-- asiento para los dos lados lleva UNA fecha: la del primer lado (una
-- línea del libro no va después de su movimiento). Pero NUNCA dentro de
-- una conciliación CONFIRMADA de cualquiera de sus dos cuentas: la
-- cambiaría por detrás (su saldo en libros dejaría de ser el que se
-- confirmó). Antes R3 y el botón «Desde 1010» ponían el pago de fin de mes
-- de la Amex (abonado el 30-oct, cobrado por Chase el 2-nov) el 30-oct,
-- dentro del Chase al 31-oct ya confirmado: el cuadre 54 en rojo, y a
-- reabrirlo cada mes. Si la fecha del primero cae dentro de una
-- confirmada, va la del día siguiente a su corte: el estado de cuenta
-- confirmado no traía ese dinero, así que el banco lo movió después. Pero
-- SOLO si eso no deja partido el otro lado: si el estado de cuenta de la
-- otra cuenta corta en medio (fn_banco_corte_entre: la Blue que corta el
-- 31-oct y abona el pago ese día; la reserva que lo acredita el 2-nov con
-- Chase al 31-oct), su movimiento quedaría dentro de su corte y su línea
-- fuera, y esa conciliación cuadraría en 0.00 sin poder confirmarse nunca
-- (ronda 4: decía «cásalos o clasifícalos» de un movimiento ya casado, y
-- nada decía qué reabrir). Entonces no se postea: {"bloqueo"} dice qué
-- conciliación reabrir, y que el dinero va en ella como cargo en
-- circulación (o depósito en tránsito), que es lo correcto. Si un lado es
-- de una cuenta cuya conciliación confirmada ya lo cubre (entró después
-- de confirmarla), tampoco: {"bloqueo": qué reabrir}. Devuelve {"fecha",
-- "nota", "por"} («por»: la conciliación que movió la fecha, para que la
-- conciliación del otro lado sepa qué decir si cortó ahí sin saberse).
drop function if exists public.fn_banco_tr_fecha(date, text, date, text);
create or replace function public.fn_banco_tr_fecha(p_f1 date, p_c1 text, p_f2 date, p_c2 text, p_monto1 numeric)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_own   conciliaciones;
  v_conf  conciliaciones;
  v_fmin  date := least(p_f1, coalesce(p_f2, p_f1));
  v_f     date;
  v_cc    text;
  v_ck    date;
  v_lista text;
  v_nconf int;
  v_monto numeric;
begin
  -- Un lado dentro de SU conciliación confirmada: no se toca sin reabrirla.
  select c.* into v_own
    from conciliaciones c
   where c.estado = 'confirmada'
     and ((c.cuenta = p_c1 and c.fecha_corte >= p_f1) or (p_f2 is not null and c.cuenta = p_c2 and c.fecha_corte >= p_f2))
   order by c.fecha_corte, c.cuenta
   limit 1;
  if found then
    return jsonb_build_object('bloqueo',
      format('la conciliación de %s al %s está confirmada y el movimiento de esa cuenta que esta transferencia casa cae dentro de '
             'ella (entró después de confirmarla): reábrela (fn_conciliacion_reabrir, con su motivo), casa la transferencia y '
             'vuelve a conciliarla', v_own.cuenta, v_own.fecha_corte),
      'reabrir', jsonb_build_object('cuenta', v_own.cuenta, 'fecha_corte', v_own.fecha_corte));
  end if;
  -- La última confirmada de cualquiera de las dos cuentas.
  select c.* into v_conf
    from conciliaciones c
   where c.estado = 'confirmada' and c.cuenta in (p_c1, coalesce(p_c2, p_c1))
   order by c.fecha_corte desc, c.cuenta
   limit 1;
  v_f := greatest(v_fmin, coalesce(v_conf.fecha_corte + 1, v_fmin));
  if v_f > v_fmin then
    -- ¿Algún lado que ya está en el banco quedaría partido (su movimiento
    -- dentro del corte de su estado de cuenta y su línea después)?
    select x.c, fn_banco_corte_entre(x.c, x.f, v_f - 1) into v_cc, v_ck
      from (values (1, p_c1, p_f1), (2, p_c2, p_f2)) as x(n, c, f)
     where x.f is not null and x.f < v_f and fn_banco_corte_entre(x.c, x.f, v_f - 1) is not null
     order by x.n
     limit 1;
    if v_ck is not null then
      select count(*), string_agg(format('la del %s', c.fecha_corte), ', ' order by c.fecha_corte desc)
        into v_nconf, v_lista
        from conciliaciones c
       where c.cuenta = v_conf.cuenta and c.estado = 'confirmada' and c.fecha_corte >= v_fmin;
      v_monto := case when v_conf.cuenta = p_c1 then p_monto1 else -p_monto1 end;
      return jsonb_build_object('bloqueo',
        format('es del %s y no puede ir después: el estado de cuenta de %s corta el %s y ya la trae (fechada más tarde, esa '
               'conciliación cuadraría sin poder confirmarse nunca), y el %s cae dentro de la conciliación confirmada de %s al %s. '
               '%s y vuelve a casarla: va en ella como %s (el banco de %s la movió después de su corte) y se confirma otra vez',
               v_fmin, v_cc, v_ck, v_fmin, v_conf.cuenta, v_conf.fecha_corte,
               case when v_nconf > 1
                    then format('Reabre las de %s, de la última hacia atrás (%s; fn_conciliacion_reabrir, con su motivo),',
                                v_conf.cuenta, v_lista)
                    else format('Reabre la de %s al %s (fn_conciliacion_reabrir, con su motivo)', v_conf.cuenta, v_conf.fecha_corte) end,
               case when v_monto < 0 then 'cargo en circulación' when v_monto > 0 then 'depósito en tránsito'
                    else 'partida en tránsito' end, v_conf.cuenta),
        'reabrir', jsonb_build_object('cuenta', v_conf.cuenta, 'fecha_corte', v_conf.fecha_corte));
    end if;
  end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'fecha', v_f,
    'nota', case when v_f <> v_fmin
                 then format('Fechada el %s y no el %s: con esa fecha su línea caería dentro de la conciliación confirmada de %s al %s '
                             '(que no traía este dinero: el banco lo movió después).', v_f, v_fmin, v_conf.cuenta, v_conf.fecha_corte) end,
    'por', case when v_f <> v_fmin then jsonb_build_object('cuenta', v_conf.cuenta, 'fecha_corte', v_conf.fecha_corte) end));
end $$;
revoke execute on function public.fn_banco_tr_fecha(date, text, date, text, numeric) from public, anon, authenticated, service_role;

-- CASAR: el movimiento con sus líneas del libro (p_lineas: [{asiento_id,
-- orden}]; vacía en la clase apertura). Las líneas tienen que ser de la
-- cuenta del movimiento, de un asiento vivo, libres, y sumar su monto al
-- centavo. Escribe el casado, sus líneas y el estado del movimiento; en un
-- cobro, su movimiento_id; en una partida de la apertura, con qué
-- movimiento llegó.
create or replace function public.fn_banco_casar_lineas(p_mov uuid, p_clase text, p_ref text, p_asiento uuid, p_lineas jsonb,
                                                        p_regla text, p_auto boolean, p_posteado boolean,
                                                        p_motivo text default null)
returns uuid
language plpgsql
set search_path = public, pg_temp
as $$
declare
  m       movimientos_banco;
  v_id    uuid := gen_random_uuid();
  v_n     int;
  v_suma  numeric;
  v_mal   text;
  v_c     banco_casados;
begin
  select * into m from movimientos_banco where id = p_mov for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese movimiento del banco.';
  end if;
  -- (La única excepción a «solo lo pendiente»: un movimiento de ANTES del
  -- corte, ignorado al entrar, que es una partida en tránsito de la
  -- conciliación de apertura: el statement de la tarjeta cortó antes del
  -- 30-sep y lo de entre su corte y el 30 llega fechado en septiembre. Casa
  -- con su partida, sin tocar el libro; ver fn_banco_apertura_previas.)
  if m.estado <> 'pendiente'
     and not (m.estado = 'ignorado' and p_clase = 'apertura' and m.fecha < fn_puente_corte() and m.duplicado is null
              and m.monto <> 0 and m.casado_id is null) then
    raise exception using errcode = 'MX008',
      message = format('El movimiento del %s por %s ya está %s: no se casa dos veces.', m.fecha, m.monto, m.estado);
  end if;
  if m.posible_duplicado_de is not null and m.duplicado is null then
    raise exception using errcode = 'MX008',
      message = 'Ese movimiento puede ser el mismo que otro que ya entró: primero di si lo es (fn_banco_duplicado).';
  end if;
  if p_clase <> 'apertura' then
    if jsonb_typeof(p_lineas) is distinct from 'array' or jsonb_array_length(p_lineas) = 0 then
      raise exception using errcode = '22023', message = 'Un casado dice con qué líneas del libro (asiento_id y orden).';
    end if;
    select count(*), coalesce(sum(l.monto), 0),
           string_agg(case when l.asiento_id is null then format('la línea %s/%s no existe', x.asiento_id, x.orden)
                           when l.cuenta <> m.cuenta then format('la línea %s de %s es de %s, no de %s', x.orden, a.numero, l.cuenta,
                                                                 m.cuenta)
                           when a.camino in ('reverso', 'reverso_automatico')
                                or exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
                             then format('%s está reversado (o es un reverso)', a.numero)
                           when a.reversible
                                or exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso_automatico')
                             then format('%s es un devengo que el libro reversa solo el día 1 (reversible): no explica un '
                                         'movimiento del banco', a.numero)
                           when exists (select 1 from banco_casado_lineas cl
                                         where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente)
                             then format('la línea %s de %s ya casa con otro movimiento', x.orden, a.numero) end, '; ')
      into v_n, v_suma, v_mal
      from jsonb_to_recordset(p_lineas) as x(asiento_id uuid, orden int)
      left join asiento_lineas l on l.asiento_id = x.asiento_id and l.orden = x.orden
      left join asientos a on a.id = l.asiento_id;
    if v_mal is not null then
      raise exception using errcode = 'MX008', message = format('No se casa: %s.', v_mal);
    end if;
    if v_suma <> m.monto then
      raise exception using errcode = 'MX008',
        message = format('No se casa: las líneas del libro suman %s y el movimiento es de %s (al centavo).', v_suma, m.monto);
    end if;
  end if;
  perform fn_banco_marca('casar:' || p_mov);
  insert into banco_casados (id, movimiento_id, clase, referencia, asiento_id, posteado, regla, automatico, motivo)
  values (v_id, p_mov, p_clase, p_ref, p_asiento, p_posteado, p_regla, p_auto, fn_banco_limpio(p_motivo))
  returning * into v_c;
  if p_clase <> 'apertura' then
    insert into banco_casado_lineas (casado_id, asiento_id, orden, cuenta, monto)
    select v_id, x.asiento_id, x.orden, m.cuenta, 0
      from jsonb_to_recordset(p_lineas) as x(asiento_id uuid, orden int);
  end if;
  perform fn_banco_marca('movimiento:' || p_mov);
  update movimientos_banco
     set estado = 'casado', estado_motivo = null, propuesta = null, casado_id = v_id, casado_clase = p_clase,
         casado_ref = p_ref, asiento_id = p_asiento, casado_regla = p_regla, casado_auto = p_auto,
         casado_por = v_c.casado_por, casado_el = v_c.casado_el
   where id = p_mov;
  perform fn_banco_marca(null);
  if p_clase = 'cobro' then
    -- (c3 deja casar un cobro con su movimiento: de nulo a su valor.)
    update cobros set movimiento_id = p_mov::text where id = p_ref::uuid and movimiento_id is null;
  elsif p_clase = 'apertura' then
    perform fn_banco_apertura_resolver(p_ref::uuid);
  elsif p_clase = 'transferencia' then
    perform fn_banco_transferencia_estado(p_asiento);
  end if;
  return v_id;
end $$;
revoke execute on function public.fn_banco_casar_lineas(uuid, text, text, uuid, jsonb, text, boolean, boolean, text)
  from public, anon, authenticated, service_role;

-- Las líneas LIBRES del libro en una cuenta (vivas, sin movimiento, desde
-- el corte, sin la apertura ni sus ajustes: la apertura se concilia con
-- sus partidas a mano), con la fecha de su papel (la del ticket: un
-- documento tardío se postea el día 1 del mes abierto, pero se compra el
-- día que dice el ticket). Ni la línea de un DEVENGO (un asiento
-- reversible, que el libro reversa solo el día 1 del mes siguiente): no
-- explica un movimiento del banco, y antes el cruce exacto casaba con él
-- un depósito de verdad que así no entraba nunca al libro.
--   tr, tr_otra  la línea es de una transferencia que puso el banco (R3:
--                un lado confirmado) y la otra cuenta propia de ese asiento
--                (su otro lado casa con esta línea, en su dirección);
--   texto        la descripción del asiento y la de la línea (el número de
--                un cheque escrito a mano: «cheque 1045»).
-- (La forma cambia en esta versión: la anterior se quita.)
-- Con EXECUTE: cada llamada se planea con SUS cuentas. Una cuenta con dos
-- líneas se busca por sus índices y todas las del banco de una pasada;
-- como consulta fija, el plan era siempre el de «todas las cuentas» (leer
-- el libro entero): 30 ms por llamada con un año de libro, aunque la
-- cuenta tuviera dos líneas, y el casado la llama varias veces por ronda.
drop function if exists public.fn_banco_lineas_libres(text[], date);
create or replace function public.fn_banco_lineas_libres(p_cuentas text[], p_desde date)
returns table (asiento_id uuid, orden int, cuenta text, monto numeric, numero text, origen_tabla text, origen_id text,
               fecha date, fdoc date, procedencia jsonb, tr boolean, tr_otra text, texto text)
language plpgsql
stable
set search_path = public, pg_temp
as $f$
begin
  return query execute $q$
  select l.asiento_id, l.orden, l.cuenta, l.monto, a.numero, a.origen_tabla, a.origen_id, a.fecha_contable,
         coalesce(case when a.procedencia->>'fecha_documento' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                       then (a.procedencia->>'fecha_documento')::date end, a.fecha_contable),
         a.procedencia,
         coalesce(a.origen_tabla = 'movimientos_banco' and a.procedencia->>'regla' like 'R3%', false),
         case when a.origen_tabla = 'movimientos_banco' and a.procedencia->>'regla' like 'R3%'
              then (select o.cuenta from asiento_lineas o where o.asiento_id = l.asiento_id and o.orden <> l.orden
                     order by o.orden limit 1) end,
         concat_ws(' ', a.descripcion, l.memo)
    from asiento_lineas l
    join asientos a on a.id = l.asiento_id
   where l.cuenta = any ($1)
     and a.fecha_contable >= (select greatest($2, fn_puente_corte()))
     and a.camino not in ('reverso', 'reverso_automatico')
     and a.tipo <> 'apertura'
     and not a.reversible
     and not (a.tipo = 'ajuste_cpa' and a.afecta_periodo in (select p.periodo from periodos p where p.tipo = 'apertura'))
     and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino in ('reverso', 'reverso_automatico'))
     and not exists (select 1 from banco_casado_lineas cl where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente)
  $q$ using p_cuentas, p_desde;
end $f$;
revoke execute on function public.fn_banco_lineas_libres(text[], date) from public, anon, authenticated, service_role;

-- LAS PARTIDAS DE LA APERTURA QUE EL BANCO TRAJO ANTES DEL CORTE. El
-- statement de una tarjeta no corta el 30-sep (la Gold, el 22): QuickBooks
-- la concilia al statement del 22 y deja «sin conciliar» lo de después
-- (el Shell del 24), que es justo lo que la conciliación de apertura pide
-- escribir como partida en tránsito. Pero el banco lo trae en el statement
-- siguiente CON SU FECHA (el 25-sep), antes del corte: entra ignorado
-- («está en QuickBooks») y la partida no casaba nunca: la conciliación de
-- octubre quedaba con libros = banco y una diferencia igual a la partida,
-- sin confirmarse, y todos los caminos daban la vuelta (casarla decía «ya
-- está ignorado», des-casarlo «es de antes del corte»). Ahora, en una
-- TARJETA, el movimiento ignorado de antes del corte por lo mismo que una
-- partida sin llegar (su cheque, si los dos lo dicen), fechado desde 3
-- días antes de la partida, casa SOLO con ella si es el único y ella la
-- única (sin tocar el libro: ya está en el saldo de la apertura). En un
-- banco (su statement corta a fin de mes: lo de septiembre ya estaba en
-- él) no se supone: lo dice la conciliación («falta», con la llamada) y lo
-- casa Edgar (fn_banco_casar_con con {"partida_apertura"}). Lo llama el
-- motor al empezar, aunque no haya nada pendiente.
create or replace function public.fn_banco_apertura_previas(p_cuenta text)
returns int
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_corte date := fn_puente_corte();
  v_n     int := 0;
  r       record;
begin
  if not exists (select 1 from conciliacion_partidas pa join conciliaciones c on c.id = pa.conciliacion_id
                  where c.tipo = 'apertura' and c.estado = 'confirmada' and pa.lado = 'libro' and pa.asiento_id is null
                    and pa.resuelta_por_movimiento is null and (p_cuenta is null or c.cuenta = p_cuenta)) then
    return 0;
  end if;
  for r in
    with ap as (
      select pa.id as partida, c.cuenta, pa.monto, pa.fecha, nullif(ltrim(pa.cheque, '0'), '') as cheque
        from conciliacion_partidas pa
        join conciliaciones c on c.id = pa.conciliacion_id
       where c.tipo = 'apertura' and c.estado = 'confirmada' and pa.lado = 'libro' and pa.asiento_id is null and pa.clase <> 'error'
         and pa.resuelta_por_movimiento is null and (p_cuenta is null or c.cuenta = p_cuenta)
         and fn_banco_tipo_cuenta(c.cuenta) = 'tarjeta'
         and not exists (select 1 from banco_casados bc
                          where bc.clase = 'apertura' and bc.deshecho_el is null and bc.referencia = pa.id::text)),
    mv as (
      select m.id, m.cuenta, m.monto, coalesce(m.fecha_transaccion, m.fecha) as fc, fn_banco_cheque_num(m.cheque, m.descripcion) as cheque
        from movimientos_banco m
       where m.estado = 'ignorado' and m.fecha < v_corte and m.monto <> 0 and m.duplicado is null and m.casado_id is null
         and m.cuenta in (select ap.cuenta from ap)
         -- (los de un archivo retirado no son de esta cuenta: ronda 4)
         and not exists (select 1 from archivos_banco a where a.id = m.archivo_id and a.retirado_el is not null)
         -- (lo que Edgar des-casó de una partida no vuelve a casar solo)
         and not exists (select 1 from banco_casados bc
                          where bc.movimiento_id = m.id and bc.deshecho_el is not null and bc.clase = 'apertura')),
    par as (
      select mv.id as mov, ap.partida
        from mv join ap on ap.cuenta = mv.cuenta and ap.monto = mv.monto
       where mv.fc >= ap.fecha - 3 and (ap.cheque is null or mv.cheque is null or ap.cheque = mv.cheque)),
    pc as (select par.*, count(*) over (partition by par.mov) as nm, count(*) over (partition by par.partida) as np from par)
    select pc.mov, pc.partida from pc where pc.nm = 1 and pc.np = 1
  loop
    perform fn_banco_casar_lineas(r.mov, 'apertura', r.partida::text, null, '[]'::jsonb,
                                  'Apertura: la partida en tránsito del 30-sep que el banco trajo antes del corte (el statement de la '
                                  'tarjeta cortó antes del 30-sep)', true, false);
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;
revoke execute on function public.fn_banco_apertura_previas(text) from public, anon, authenticated, service_role;

-- Los movimientos que pueden casar (el «pool»): pendientes, desde el corte,
-- de esas cuentas, sin un «posible duplicado» por resolver; con su fecha
-- de la compra (DTUSER, si vino), su descripción (NAME, normalizada: los
-- descriptores de las transferencias y del pago de una tarjeta se buscan
-- AHÍ) y el texto con la nota (NAME y MEMO: las demás propuestas).
-- (Por qué solo NAME: el MEMO de un Zelle lo escribe quien manda el
-- dinero, y un cliente que pone «thank you» en la nota convertía su pago
-- en una «transferencia desde la Amex».)
-- cheque: el número del cheque (CHECKNUM o, si el banco no lo manda, el de
-- NAME: «CHECK 1043»; fn_banco_cheque_num, escrita aquí para no llamarla
-- fila por fila).
drop function if exists public.fn_banco_pool(text[]);
create or replace function public.fn_banco_pool(p_cuentas text[])
returns table (id uuid, cuenta text, fecha date, ftx date, monto numeric, tipo_banco text, cheque text, dn text, dtxt text)
language sql
stable
set search_path = public, pg_temp
as $$
  select m.id, m.cuenta, m.fecha, m.fecha_transaccion, m.monto, m.tipo_banco,
         coalesce(nullif(ltrim(m.cheque, '0'), ''),
                  substring(m.desc_norm from '(?:^| )(?:CHECK|CHK|CHEQUE|CK)(?: NO)? ?#? ?0*([1-9][0-9]{0,9})(?: |$)')),
         m.desc_norm,
         case when m.memo is null then m.desc_norm else btrim(m.desc_norm || ' ' || fn_banco_norm(m.memo)) end
    from movimientos_banco m
   where m.estado = 'pendiente' and m.fecha >= (select fn_puente_corte()) and m.cuenta = any (p_cuentas)
     and (m.posible_duplicado_de is null or m.duplicado = 'no_es_el_mismo')
$$;
revoke execute on function public.fn_banco_pool(text[]) from public, anon, authenticated, service_role;

-- LA VENTANA en que una línea del libro es el mismo dinero que un
-- movimiento del banco (una sola regla para el casado, la propuesta y las
-- guardas). Devuelve 'fuerte' (casa sola si es la única, y mutua), 'debil'
-- (se propone y frena clasificar, pero no casa sola) o nulo (no es él).
--   · lo de siempre (un ticket, un cobro, una cuota, un asiento a mano):
--     la fecha del papel entre 3 días antes de la COMPRA (DTUSER, si el
--     banco la trae; si no, 7 antes del día del banco: la tarjeta postea
--     días después de un viernes o de un festivo) y 3 días después del día
--     del banco. Antes eran ±3 días del día del banco a secas, y un ticket
--     del viernes que la Amex posteaba el martes salía «sin ticket» y se
--     dejaba clasificar: el gasto entraba dos veces;
--   · un CHEQUE: además, hasta 60 días antes (un cheque tarda en
--     cobrarse): fuerte si el papel dice su número («cheque 1045»), débil
--     si no;
--   · el otro lado de una TRANSFERENCIA ya posteada, en su dirección: el
--     lado que entra, del día del que sale a 10 días después (un ACH a otro
--     banco tarda 3 a 5 días hábiles); en una tarjeta, desde 7 días antes
--     (la Amex acredita el pago el día que se hace y Chase lo cobra de 1 a
--     3 días HÁBILES después: pagada un viernes, o antes de un lunes
--     festivo, el cargo llega el martes o el miércoles, a +4 o +5). El lado
--     que sale, al revés. Antes eran ±3 días, y después 3 en la tarjeta: el
--     pago de la Amex de un viernes que Chase cobraba el martes no casaba,
--     la bandeja decía «el otro lado todavía no llegó», ofrecía otra
--     transferencia y el mismo dinero entraba dos veces.
create or replace function public.fn_banco_ventana(p_fecha date, p_ftx date, p_cheque text, p_fdoc date, p_monto numeric,
                                                   p_tr boolean, p_tipo text, p_tr_otra_tipo text, p_texto text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
           when p_tr then
             case when p_monto > 0
                  then case when p_fecha between p_fdoc - (case when p_tipo = 'tarjeta' then 7 else 0 end) and p_fdoc + 10
                            then 'fuerte' end
                  else case when p_fecha between p_fdoc - 10 and p_fdoc + (case when p_tr_otra_tipo = 'tarjeta' then 7 else 0 end)
                            then 'fuerte' end end
           -- (least() no da nulo si un lado lo es: sin DTUSER, 7 días antes)
           when p_fdoc between (case when p_ftx is not null then least(p_ftx, p_fecha) - 3 else p_fecha - 7 end) and p_fecha + 3
             then 'fuerte'
           when p_cheque ~ '^[0-9]+$' and ltrim(p_cheque, '0') <> '' and p_fdoc between p_fecha - 60 and p_fecha + 3 then
             case when coalesce(p_texto, '') ~* ('(^|[^0-9])0*' || ltrim(p_cheque, '0') || '([^0-9]|$)') then 'fuerte' else 'debil' end
         end
$$;
revoke execute on function public.fn_banco_ventana(date, date, text, date, numeric, boolean, text, text, text)
  from public, anon, authenticated, service_role;
-- SANAR los casados cuyo papel se rehízo. Si c3 rehace un papel ya casado
-- con el banco (el ticket se corrigió con ✎: su puente reversa el asiento y
-- pone el que lo sustituye), el casado apuntaba a una línea reversada: se
-- mueve, con rastro, a la línea del asiento que la sustituye (la misma
-- cuenta y el mismo monto); si el papel ya no la tiene (se anuló, cambió
-- el monto o la tarjeta), el casado se deshace y el movimiento vuelve a la
-- bandeja con el porqué. Solo los que NO posteó el banco (los suyos solo
-- se reversan des-casando). Lo corren el casado y la conciliación antes
-- de mirar nada. Un casado con la línea de un devengo (un asiento
-- reversible, que el libro reversa solo el día 1) también se deshace: no
-- explica el movimiento.
-- DENTRO DE UNA CONCILIACIÓN CONFIRMADA no se toca (la misma regla que
-- fn_banco_descasar: se reabre antes): antes se des-casaba, el cargo de un
-- mes cerrado y conciliado volvía a la bandeja, y el control de la app
-- seguía en verde. Se queda casado, y el control («un movimiento, un
-- casado») lo dice en rojo con qué conciliación reabrir.
-- LOS ANEXOS de un casado: los asientos que puso el banco JUNTO a un papel
-- que no es suyo (la comisión de un cobro con tarjeta, fn_banco_cobrar).
-- Si el casado se deshace (des-casar, o su cobro se anuló), se reversan
-- con él: sin su cobro la comisión no se explica, y su línea del banco
-- quedaría suelta para casar con otra cosa. Devuelve cuántos.
create or replace function public.fn_banco_anexos_reversar(p_casado uuid, p_motivo text)
returns int
language plpgsql
set search_path = public, pg_temp
as $$
declare
  a   record;
  v_n int := 0;
begin
  for a in select distinct x.id
             from banco_casado_lineas bl
             join asientos x on x.id = bl.asiento_id
            where bl.casado_id = p_casado and x.origen_tabla = 'movimientos_banco' and x.procedencia ? 'anexo'
              and not exists (select 1 from asientos r where r.reversa_a = x.id and r.camino in ('reverso', 'reverso_automatico'))
  loop
    perform fn_reversar_interno(a.id, p_motivo, 'reverso', jsonb_build_object('funcion', 'fn_banco_descasar', 'anexo', true));
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;
revoke execute on function public.fn_banco_anexos_reversar(uuid, text) from public, anon, authenticated, service_role;

create or replace function public.fn_banco_sanar()
returns int
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c      record;
  v_sust uuid;
  v_lin  jsonb;
  v_suma numeric;
  v_n    int := 0;
  v_num  text;
  v_viva jsonb;
  v_sviv numeric;
begin
  for c in
    select bc.*, m.cuenta, m.monto, a.numero as numero_viejo
      from banco_casados bc
      join movimientos_banco m on m.id = bc.movimiento_id and m.casado_id = bc.id
      join asientos a on a.id = bc.asiento_id
     where bc.deshecho_el is null and not bc.posteado and bc.asiento_id is not null
       and exists (select 1 from banco_casado_lineas bl
                    where bl.casado_id = bc.id and bl.vigente
                      and exists (select 1 from asientos r
                                   where r.reversa_a = bl.asiento_id and r.camino in ('reverso', 'reverso_automatico')))
       and not exists (select 1 from conciliaciones cc
                        where cc.cuenta = m.cuenta and cc.estado = 'confirmada' and cc.fecha_corte >= m.fecha)
  loop
    -- El que lo sustituye (vivo), si lo hay.
    select s.id, s.numero into v_sust, v_num
      from asientos s
     where s.sustituye_a = c.asiento_id
       and not exists (select 1 from asientos r where r.reversa_a = s.id and r.camino = 'reverso');
    v_lin := null;
    if v_sust is not null then
      select jsonb_agg(jsonb_build_object('asiento_id', l.asiento_id, 'orden', l.orden) order by l.orden), sum(l.monto)
        into v_lin, v_suma
        from asiento_lineas l
       where l.asiento_id = v_sust and l.cuenta = c.cuenta
         and not exists (select 1 from banco_casado_lineas cl where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente);
      -- (con las líneas del casado que siguen vivas: la comisión que puso el
      -- banco junto al cobro sigue con él)
      select jsonb_agg(jsonb_build_object('asiento_id', bl.asiento_id, 'orden', bl.orden) order by bl.asiento_id, bl.orden),
             sum(l.monto)
        into v_viva, v_sviv
        from banco_casado_lineas bl
        join asiento_lineas l on l.asiento_id = bl.asiento_id and l.orden = bl.orden
       where bl.casado_id = c.id and bl.vigente and bl.asiento_id <> c.asiento_id
         and not exists (select 1 from asientos r where r.reversa_a = bl.asiento_id and r.camino in ('reverso', 'reverso_automatico'));
      if v_viva is not null then
        v_lin := v_lin || v_viva;
        v_suma := v_suma + v_sviv;
      end if;
      if v_suma is distinct from c.monto then
        v_lin := null;
      end if;
    end if;
    perform fn_banco_marca('descasar:' || c.movimiento_id);
    update banco_casados
       set deshecho_motivo = case when v_lin is not null
                                  then format('Su papel se rehízo: %s se reversó y lo sustituye %s (se vuelve a casar con él).',
                                              c.numero_viejo, v_num)
                                  else format('Su papel se reversó (%s) y ya no tiene una línea en %s por %s: vuelve a la bandeja.',
                                              c.numero_viejo, c.cuenta, c.monto) end
     where id = c.id;
    update banco_casado_lineas set vigente = false where casado_id = c.id and vigente;
    perform fn_banco_marca('movimiento:' || c.movimiento_id);
    update movimientos_banco
       set estado = 'pendiente', estado_motivo = null, propuesta = null, casado_id = null, casado_clase = null, casado_ref = null,
           asiento_id = null, casado_regla = null, casado_auto = null, casado_por = null, casado_el = null
     where id = c.movimiento_id;
    perform fn_banco_marca(null);
    if c.clase = 'cobro' and v_lin is null then
      perform set_config('mx_puente.escribe', 'cobros_descasar:' || c.referencia, true);
      update cobros set movimiento_id = null where id = c.referencia::uuid and movimiento_id = c.movimiento_id::text;
      perform set_config('mx_puente.escribe', '', true);
    end if;
    if v_lin is null then
      perform fn_banco_anexos_reversar(c.id, format('Su papel se reversó (%s): la comisión se va con él.', c.numero_viejo));
    end if;
    if v_lin is not null then
      perform fn_banco_casar_lineas(c.movimiento_id, c.clase, c.referencia, v_sust, v_lin,
                                    c.regla || ' · su papel se rehízo (' || v_num || ')', c.automatico, false, c.motivo);
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;
revoke execute on function public.fn_banco_sanar() from public, anon, authenticated, service_role;
-- REHACER una transferencia con otra fecha. Un solo asiento para los dos
-- lados (R3) lleva UNA fecha, y una línea del libro no puede ir después de
-- su movimiento (en el corte de en medio, el banco lo tendría y el libro
-- no: la conciliación no cerraría). Si el otro lado llega con una fecha
-- ANTERIOR a la del asiento (se confirmó primero el pago en la tarjeta, del
-- 2-nov, y después llega la salida de Chase, del 31-oct), el asiento se
-- reversa y se vuelve a postear con la fecha más temprana (sustituye_a,
-- como todo papel de puente que cambia), y el lado que ya estaba casado se
-- vuelve a casar con él. Todo en una transacción, con su motivo.
create or replace function public.fn_banco_transferencia_rehacer(p_asiento uuid, p_fecha date, p_motivo text)
returns uuid
language plpgsql
set search_path = public, pg_temp
as $$
declare
  a        asientos;
  v_lineas jsonb;
  v_res    jsonb;
  v_nuevo  uuid;
  c        record;
  v_antes  jsonb := '[]'::jsonb;
  x        jsonb;
begin
  select * into a from asientos where id = p_asiento;
  select jsonb_agg(jsonb_strip_nulls(jsonb_build_object('cuenta', l.cuenta, 'monto', l.monto::text, 'memo', l.memo)) order by l.orden)
    into v_lineas
    from asiento_lineas l where l.asiento_id = p_asiento;
  -- Los casados vivos con ese asiento se sueltan (el reverso es este mismo
  -- paso) y se vuelven a casar con el nuevo, línea por línea.
  for c in select bc.*, (select jsonb_agg(jsonb_build_object('orden', cl.orden)) from banco_casado_lineas cl
                          where cl.casado_id = bc.id and cl.vigente) as ordenes
             from banco_casados bc
            where bc.asiento_id = p_asiento and bc.deshecho_el is null loop
    v_antes := v_antes || jsonb_build_array(to_jsonb(c));
    perform fn_banco_marca('descasar:' || c.movimiento_id);
    update banco_casados set deshecho_motivo = p_motivo where id = c.id;
    update banco_casado_lineas set vigente = false where casado_id = c.id and vigente;
    perform fn_banco_marca('movimiento:' || c.movimiento_id);
    update movimientos_banco
       set estado = 'pendiente', casado_id = null, casado_clase = null, casado_ref = null, asiento_id = null, casado_regla = null,
           casado_auto = null, casado_por = null, casado_el = null
     where id = c.movimiento_id;
    perform fn_banco_marca(null);
  end loop;
  perform fn_reversar_interno(p_asiento, p_motivo, 'reverso',
                              jsonb_build_object('funcion', 'fn_banco_transferencia_rehacer', 'nueva_fecha', p_fecha));
  v_res := fn_banco_asiento(a.origen_tabla, a.origen_id, p_fecha, a.descripcion, v_lineas,
                            (a.procedencia - array['fecha_documento', 'tardio', 'sustituye', 'conexion', 'puerta'])
                            || jsonb_build_object('rehecha', p_motivo));
  v_nuevo := (v_res->>'id')::uuid;
  for x in select value from jsonb_array_elements(v_antes) loop
    perform fn_banco_casar_lineas((x->>'movimiento_id')::uuid, x->>'clase', x->>'referencia', v_nuevo,
                                  (select jsonb_agg(jsonb_build_object('asiento_id', v_nuevo, 'orden', (o->>'orden')::int))
                                     from jsonb_array_elements(x->'ordenes') o),
                                  x->>'regla', (x->>'automatico')::boolean, (x->>'posteado')::boolean, p_motivo);
  end loop;
  return v_nuevo;
end $$;
revoke execute on function public.fn_banco_transferencia_rehacer(uuid, date, text) from public, anon, authenticated, service_role;

-- LAS FACTURAS ABIERTAS del contexto (su cuenta por cobrar o su retención,
-- con algo por cobrar): las que pueden explicar un depósito. Aparte, porque
-- solo las lee la propuesta de un depósito del banco (fn_banco_contexto
-- las lleva si se piden).
create or replace function public.fn_banco_contexto_facturas()
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  with k as (select fn_puente_cuenta_de('cxc') as cxc, fn_puente_cuenta_de('retencion_cxc') as ret)
  select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'num', fa.num, 'proyecto_id', fa.proyecto_id,
                                               'fecha', fa.fecha, 's1', f.s1, 's2', f.s2,
                                               -- (ronda 4: la que la app o QuickBooks ya dan por
                                               -- cobrada —con tarjeta, por su enlace de pago—: en el
                                               -- lote de un procesador va primero)
                                               'marcada', coalesce(fa.pagada, false) or fa.cobrada_el is not null,
                                               -- (las palabras de su obra y su cliente: un depósito que las
                                               -- nombra; una vez por obra, no por factura)
                                               'nom', nm.nom)
                            order by f.id), '[]'::jsonb)
    -- (lo de cada factura, sumado por su número y después con sus datos:
    -- antes se agrupaba por los datos de la factura)
    from (select (case when l.partida_id ~ '^-?[0-9]{1,18}$' then l.partida_id::bigint end) as id,
                 coalesce(sum(l.monto) filter (where l.cuenta = k.cxc), 0) as s1,
                 coalesce(sum(l.monto) filter (where l.cuenta = k.ret), 0) as s2
            from asiento_lineas l
            cross join k
           where l.partida_tabla = 'facturas' and l.cuenta in (k.cxc, k.ret)
           group by 1) f
    join facturas fa on fa.id = f.id and coalesce(fa.estado, 'emitida') <> 'anulada'
    left join (select pj.id, jsonb_agg(distinct w.w) as nom
                 from proyectos pj
                 cross join regexp_split_to_table(fn_banco_norm(concat_ws(' ', pj.nombre, pj.cliente)), ' ') as w(w)
                where length(w.w) >= 4
                group by pj.id) nm on nm.id = fa.proyecto_id
   where f.s1 > 0 or f.s2 > 0
$$;
revoke execute on function public.fn_banco_contexto_facturas() from public, anon, authenticated, service_role;

-- EL CONTEXTO de las propuestas: lo que no cambia de un movimiento a otro
-- (las cuentas del plan que se proponen, los descriptores, las cuentas
-- propias, los proveedores con sus nombres ya normalizados y lo que se les
-- debe, los préstamos y las facturas abiertas), leído UNA vez por llamada
-- y no una por movimiento. Con la bandeja llena (miles de movimientos
-- pendientes) cada propuesta cuesta décimas de milisegundo, no
-- milisegundos.
-- (Antes sin argumento: se quita, para que no queden dos.)
drop function if exists public.fn_banco_contexto();
create or replace function public.fn_banco_contexto(p_facturas boolean default true)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  with k as (select fn_puente_cuenta_de('cxc') as cxc, fn_puente_cuenta_de('retencion_cxc') as ret,
                    fn_puente_cuenta_de('cxp') as cxp, fn_banco_caja() as caja),
  -- Las cuentas propias con estado de cuenta (bancos sin la caja chica, y
  -- las tarjetas): su tipo, y si se ofrecen como destino (activas e
  -- imputables). (activa se lee por nombre en una función: las vistas no
  -- la nombran, ver c4.)
  pr as (select c.codigo, c.nombre, fn_banco_tipo_cuenta(c.codigo) as tipo, (c.activa and c.imputable) as opcion
           from cuentas c
          -- (solo las que pueden serlo, un banco 10xx o una tarjeta dada de
          -- alta, pasan por la función: «case» decide el orden)
          where case when left(c.codigo, 2) = '10' or exists (select 1 from tarjetas t where t.cuenta = c.codigo)
                     then fn_banco_es_propia(c.codigo) else false end),
  -- Lo que se le debe a cada proveedor en su cuenta por pagar (2010, a su
  -- nombre): cada partida abierta (un ticket o un trabajo a cuenta) y lo
  -- que se le debe SIN partida: lo que traía QuickBooks en la apertura (su
  -- A/P Aging), menos lo que ya se le pagó sin partida. Lo más viejo
  -- primero (lo de QuickBooks, del 30-sep, antes que todo).
  -- (materialized: una pasada por la 2010 para todos, no una por proveedor)
  -- (el saldo de cada partida de una pasada, sin fechas; la fecha de su
  -- primera línea, solo de las que siguen abiertas: antes cada línea de la
  -- 2010 iba a buscar su asiento)
  deu1 as materialized (select l.tercero_id, l.partida_tabla, l.partida_id, -sum(l.monto) as saldo
            from asiento_lineas l
            cross join k
           where l.cuenta = k.cxp and l.tercero_tipo = 'proveedor'
           group by l.tercero_id, l.partida_tabla, l.partida_id),
  -- (la fecha de lo que se debe SIN partida, de una pasada por esas líneas:
  -- antes, por cada proveedor, una búsqueda entre todas sus líneas)
  sinp as materialized (select l.tercero_id, l.partida_id, min(a.fecha_contable) as desde
            from asiento_lineas l
            join asientos a on a.id = l.asiento_id
            cross join k
           where l.cuenta = k.cxp and l.tercero_tipo = 'proveedor' and l.tercero_id is not null and l.partida_tabla is null
           group by l.tercero_id, l.partida_id),
  deu0 as materialized (
    select d.tercero_id, d.partida_tabla, d.partida_id, d.saldo,
           case when d.saldo <= 0 then null
                when d.partida_tabla is not null
                then (select min(a.fecha_contable) from asiento_lineas l2 join asientos a on a.id = l2.asiento_id
                       where l2.partida_tabla = d.partida_tabla and l2.partida_id = d.partida_id
                         and l2.cuenta = k.cxp and l2.tercero_tipo = 'proveedor' and l2.tercero_id = d.tercero_id)
                else (select s.desde from sinp s
                       where s.tercero_id = d.tercero_id and s.partida_id is not distinct from d.partida_id) end as desde
      from deu1 d cross join k),
  deu as (select * from deu0 where deu0.saldo > 0),
  -- (lo de cada proveedor, agrupado UNA vez: antes cada proveedor recorría
  -- todas las partidas de la 2010, y con un año de libro el contexto de
  -- cada «Casar» tardaba el doble)
  deup as (select q.tercero_id,
                  jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                    'partida_tabla', q.partida_tabla, 'partida_id', q.partida_id, 'saldo', q.saldo, 'desde', q.desde,
                    'apertura', case when q.partida_tabla is null then true end))
                    order by (q.partida_tabla is not null), q.desde, q.partida_tabla, q.partida_id) as items,
                  sum(q.saldo) as total
             from deu q group by q.tercero_id),
  -- lo que cada proveedor tiene A FAVOR de la empresa (una devolución a
  -- cuenta, un pago de más): lo que un reembolso suyo puede pagar
  fav as (select deu0.tercero_id, -sum(deu0.saldo) as a_favor from deu0 where deu0.saldo < 0 group by deu0.tercero_id)
  select jsonb_build_object(
    'cxc', k.cxc, 'ret', k.ret, 'cxp', k.cxp, 'caja', k.caja,
    'pat',  (select coalesce(jsonb_object_agg(d.clave, d.patron), '{}'::jsonb) from banco_descriptores d where d.patron is not null),
    'dest', (select coalesce(jsonb_object_agg(d.clave, d.cuenta), '{}'::jsonb) from banco_descriptores d where d.cuenta is not null),
    'tipos', (select coalesce(jsonb_object_agg(pr.codigo, pr.tipo), '{}'::jsonb) from pr),
    'propias', (select coalesce(jsonb_agg(jsonb_build_object('codigo', pr.codigo, 'nombre', pr.nombre, 'tipo', pr.tipo,
                                                             'u4', (select jsonb_agg(t.ultimos4) from tarjetas t
                                                                     where t.cuenta = pr.codigo and t.ultimos4 ~ '^[0-9]{4}$'))
                                          order by pr.codigo), '[]'::jsonb)
                  from pr where pr.opcion),
    -- Las cuentas con partidas de la conciliación de apertura todavía sin
    -- llegar (octubre y noviembre de 2026): solo en ellas se buscan.
    'aper_cuentas', (select coalesce(jsonb_agg(distinct c.cuenta), '[]'::jsonb)
                       from conciliacion_partidas pa join conciliaciones c on c.id = pa.conciliacion_id
                      where c.tipo = 'apertura' and c.estado = 'confirmada' and pa.lado = 'libro' and pa.asiento_id is null
                        and pa.clase <> 'error' and pa.resuelta_por_movimiento is null),
    -- Cada proveedor activo con las formas de buscarlo en la descripción
    -- (su nombre y sus alias de 3 letras o más, normalizados y entre
    -- espacios: palabra entera) y lo que se le debe (items: lo más viejo
    -- primero; debe: el total).
    'proveedores', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'nombre', p.nombre, 'pats', x.pats,
                                                                 'items', coalesce(d.items, '[]'::jsonb), 'debe', coalesce(d.total, 0),
                                                                 'a_favor', coalesce(fv.a_favor, 0))
                                              order by p.nombre), '[]'::jsonb)
                      from proveedores p
                      cross join lateral (
                        select jsonb_agg(distinct y.pat) as pats
                          from (select ' ' || fn_banco_norm(p.nombre) || ' ' as pat
                                union all
                                select ' ' || fn_banco_norm(al.alias) || ' '
                                  from proveedores_alias al where al.proveedor_id = p.id and length(al.alias) >= 3) y
                         where y.pat <> '  ') x
                      left join deup d on d.tercero_id = p.id::text
                      left join fav fv on fv.tercero_id = p.id::text
                     where p.activo and (x.pats is not null or d.total is not null or fv.tercero_id is not null)),
    'prestamos', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'cuenta_banco', p.cuenta_banco, 'descriptor', p.descriptor)),
                                  '[]'::jsonb)
                    from prestamos p where p.estado = 'vigente' and p.descriptor is not null))
    -- (las facturas abiertas, solo si se piden: las lee un depósito del
    -- banco, y el motor las pide al primero que las necesita; un «Casar»
    -- de la tarjeta no las lee)
    || case when p_facturas then jsonb_build_object('facturas', fn_banco_contexto_facturas()) else '{}'::jsonb end
    from k
$$;
revoke execute on function public.fn_banco_contexto(boolean) from public, anon, authenticated, service_role;

-- LA FIRMA de lo que las propuestas miran: si no cambió desde la propuesta
-- de un movimiento, esa propuesta sigue valiendo y el motor no la rehace.
-- Antes cada «Casar» rehacía la propuesta de TODO lo pendiente aunque nada
-- hubiera cambiado, y con la bandeja atrasada cada llamada tardaba 2 a 5 s
-- con el candado del casado tomado (cada clic de la bandeja esperaba).
-- Va POR PARTES, porque no todas las propuestas miran lo mismo (ver
-- fn_banco_firma_mov): lo que se cobra (los cobros, sus devoluciones y
-- sus casados; las facturas: lo último posteado en 1110/1120) lo miran los
-- depósitos (y un cheque devuelto); los proveedores y sus alias, los
-- cargos y los depósitos del banco (un nombre nuevo puede empezar a casar
-- con cualquiera); lo que se le debe a cada proveedor (lo posteado en 2010
-- A SU NOMBRE), solo los movimientos que lo nombran, y lo de toda la
-- 2010, solo un pago sin nombre del banco (fn_banco_prov_mira); los
-- préstamos y sus cuotas, los cargos del banco; las partidas de la
-- apertura, las cuentas que las
-- tienen; y todos, los descriptores, las tarjetas y las cuentas activas.
-- Lo del libro en el banco y las tarjetas no entra: lo que casaría con un
-- movimiento (p_cands) se calcula en cada llamada y va en su firma. Antes
-- era el último asiento del libro entero (o de los bancos y las tarjetas):
-- cada ticket que subía la cuadrilla hacía rehacer todas las propuestas, y
-- reescribirlas idénticas salvo la firma. Y hasta la ronda 3, lo posteado
-- en 2010 iba en la firma de TODO cargo: cada ticket a cuenta del supply
-- (y cada pago a un proveedor) rehacía la propuesta de la gasolina, de la
-- luz y de todo lo pendiente, idénticas salvo la firma, gastando el tope
-- del «Casar» en eso. Solo agregados baratos (índices y cuentas), una vez
-- por llamada.
drop function if exists public.fn_banco_firma();
create or replace function public.fn_banco_firma()
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  with k as (select fn_puente_cuenta_de('cxc') as cxc, fn_puente_cuenta_de('retencion_cxc') as ret,
                    fn_puente_cuenta_de('cxp') as cxp),
  -- (los casados que cuentan, de una pasada por banco_casados)
  bc as materialized (
    select count(*) filter (where c.clase in ('cobro', 'devolucion')) as cob,
           count(*) filter (where c.clase in ('cobro', 'devolucion') and c.deshecho_el is null) as cob_v,
           count(*) filter (where c.clase = 'cuota_prestamo') as cuo,
           count(*) filter (where c.clase = 'cuota_prestamo' and c.deshecho_el is null) as cuo_v,
           count(*) filter (where c.clase = 'apertura') as ap,
           count(*) filter (where c.clase = 'apertura' and c.deshecho_el is null) as ap_v
      from banco_casados c where c.clase in ('cobro', 'devolucion', 'cuota_prestamo', 'apertura'))
  select jsonb_build_object(
    'base', md5(concat_ws('|',
              (select coalesce(max(d.cambiado_el)::text, '') || ':' || count(*) from banco_descriptores d),
              (select count(*) || ':' || coalesce(max(t.ultimos4), '') || ':' || count(*) filter (where t.activa) from tarjetas t),
              (select count(*) filter (where c.activa) from cuentas c),
              -- (ronda 4: la apertura posteada y sus conciliaciones
              -- confirmadas: el aviso de los primeros días cambia con ellas)
              (select count(*) from asientos a where a.tipo = 'apertura'),
              (select count(*) from conciliaciones c where c.tipo = 'apertura' and c.estado = 'confirmada'))),
    'cobros', md5(concat_ws('|',
              (select count(*) || ':' || count(c.movimiento_id) || ':' || count(*) filter (where c.estado = 'vigente') from cobros c),
              (select count(*) from cobros_devoluciones),
              (select bc.cob || ':' || bc.cob_v from bc))),
    -- (Lo posteado en cuentas por cobrar y en cuentas por pagar, por
    -- cuántas líneas tienen: las líneas del libro no se borran ni se
    -- cambian, así que cualquier asiento nuevo que las toque cambia la
    -- cuenta. Antes se buscaba el último asiento que las tocaba recorriendo
    -- el libro hacia atrás: con un año de banco, 10 ms en cada «Casar».)
    'fact', md5(concat_ws('|',
              (select count(*) from asiento_lineas l, k where l.cuenta in (k.cxc, k.ret)),
              (select count(*) || ':' || coalesce(max(f.id), 0) from facturas f))),
    'provs', md5(concat_ws('|',
              (select count(*) || ':' || count(*) filter (where p.activo) from proveedores p),
              (select count(*) from proveedores_alias))),
    'cxp', (select count(*)::text from asiento_lineas l, k where l.cuenta = k.cxp),
    -- (lo de cada proveedor: cuántas líneas tiene en 2010 a su nombre)
    'cxp_prov', (select coalesce(jsonb_object_agg(x.t, x.n), '{}'::jsonb)
                   from (select l.tercero_id as t, count(*) as n
                           from asiento_lineas l, k
                          where l.cuenta = k.cxp and l.tercero_tipo = 'proveedor' and l.tercero_id is not null
                          group by l.tercero_id) x),
    'cuotas', md5(concat_ws('|',
              (select count(*) || ':' || coalesce(max(p.cambiado_el)::text, '') from prestamos p),
              (select count(*) || ':' || count(*) filter (where q.anulada_el is null) from prestamo_cuotas q),
              (select bc.cuo || ':' || bc.cuo_v from bc))),
    'apert', md5(concat_ws('|',
              (select count(*) || ':' || count(p.resuelta_por_movimiento) || ':' || count(*) filter (where c.estado = 'confirmada')
                 from conciliaciones c join conciliacion_partidas p on p.conciliacion_id = c.id where c.tipo = 'apertura'),
              (select bc.ap || ':' || bc.ap_v from bc))))
$$;
revoke execute on function public.fn_banco_firma() from public, anon, authenticated, service_role;

-- LOS PROVEEDORES QUE MIRA LA PROPUESTA de un movimiento (para su firma):
-- los que su descripción nombra (su nombre o sus alias, como los busca
-- fn_banco_proponer en el pago a un proveedor y en su reembolso), y «*»
-- (toda la 2010) si es un pago sin nombre del banco (fn_banco_pago_anonimo:
-- el abono a lo más viejo se ofrece a cualquiera al que se le deba). Nulo
-- si no mira a ninguno. Va en la propuesta («mira»), y la firma se hace
-- con lo que se le debe a ESOS: un ticket a cuenta de CED no rehace la
-- propuesta de la gasolina ni la de la luz.
create or replace function public.fn_banco_prov_mira(m public.movimientos_banco, p_tipo text, p_ctx jsonb)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  select case when m.monto < 0 or (p_tipo = 'banco' and m.monto > 0) then
           (select jsonb_agg(x.v order by x.v)
              from (select p->>'id' as v
                      from jsonb_array_elements(coalesce(p_ctx->'proveedores', '[]'::jsonb)) p
                     where jsonb_typeof(p->'pats') = 'array'
                       and exists (select 1 from jsonb_array_elements_text(p->'pats') t(pat)
                                    where position(t.pat in ' ' || s.txt || ' ') > 0)
                    union all
                    select '*'
                     where p_tipo = 'banco' and m.monto < 0
                       and fn_banco_pago_anonimo(m.tipo_banco, m.cheque, m.descripcion, m.desc_norm, s.txt)) x)
         end
    from (select case when m.memo is null then m.desc_norm else btrim(m.desc_norm || ' ' || fn_banco_norm(m.memo)) end as txt) s
$$;
revoke execute on function public.fn_banco_prov_mira(public.movimientos_banco, text, jsonb) from public, anon, authenticated, service_role;

-- La firma de UN movimiento: las partes de la de arriba que su propuesta
-- mira (según sea un depósito, un cargo del banco, una compra con tarjeta
-- o un abono en ella), lo que casaría con él (p_cands), la obra con visita
-- ese día, lo PENDIENTE que puede ser el otro lado de su transferencia
-- (p_contras), lo pendiente de su cuenta si tiene partidas de la apertura
-- (p_aper, las sumas), en un abono de tarjeta, los tickets (su
-- devolución se propone contra el ticket de ese comercio), lo que se le
-- debe a los proveedores que mira (p_mira, de fn_banco_prov_mira), y los
-- tickets con otro total que más se le parecen (p_otros, hasta tres).
drop function if exists public.fn_banco_firma_mov(jsonb, text, numeric, boolean, jsonb, text, text, text, text);
create or replace function public.fn_banco_firma_mov(p_g jsonb, p_tipo text, p_monto numeric, p_cd boolean, p_cands jsonb,
                                                     p_obra text, p_contras text, p_aper text, p_rec text, p_mira jsonb,
                                                     p_otros jsonb)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select md5(concat_ws('|', coalesce(p_g->>'base', '-'),
                       coalesce(case when p_tipo = 'banco' and p_monto > 0
                                     then concat_ws(':', p_g->>'cobros', p_g->>'fact') end, '-'),
                       coalesce(case when p_monto < 0 or (p_tipo = 'banco' and p_monto > 0)
                                     then concat_ws(':', p_g->>'provs',
                                                    case when coalesce(p_mira ? '*', false) then p_g->>'cxp'
                                                         else (select string_agg(e.v || '=' || coalesce(p_g->'cxp_prov'->>e.v, '0'), ','
                                                                                 order by e.v)
                                                                 from jsonb_array_elements_text(coalesce(p_mira, '[]'::jsonb)) e(v))
                                                    end) end, '-'),
                       coalesce(case when p_tipo = 'banco' and p_monto < 0 then p_g->>'cuotas' end, '-'),
                       coalesce(case when p_tipo = 'banco' and p_monto < 0 and p_cd then p_g->>'cobros' end, '-'),
                       coalesce(case when p_aper is not null then concat_ws(':', p_g->>'apert', p_aper) end, '-'),
                       coalesce(case when p_tipo = 'tarjeta' and p_monto > 0 then p_rec end, '-'),
                       coalesce(p_cands::text, '-'), coalesce(p_obra, '-'), coalesce(p_contras, '-'), coalesce(p_otros::text, '-')))
$$;
revoke execute on function public.fn_banco_firma_mov(jsonb, text, numeric, boolean, jsonb, text, text, text, text, jsonb, jsonb)
  from public, anon, authenticated, service_role;

-- ¿Cuadra un pago con lo que se le debe a un proveedor? Una partida
-- entera, o las más viejas hasta ahí (lo de QuickBooks y la de octubre:
-- el statement del supply), o todo lo que se le debe.
create or replace function public.fn_banco_cuadra(p_items jsonb, p_x numeric)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  select exists (select 1 from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) as i(v) where (i.v->>'saldo')::numeric = p_x)
      or exists (select 1
                   from (select sum((i.v->>'saldo')::numeric) over (order by i.o) as acum
                           from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) with ordinality as i(v, o)) s
                  where s.acum = p_x)
$$;
revoke execute on function public.fn_banco_cuadra(jsonb, numeric) from public, anon, authenticated, service_role;

-- LAS PARTIDAS DE LA APERTURA QUE PUEDEN SER ESTE MOVIMIENTO (la
-- conciliación de apertura, confirmada: lo que QuickBooks tenía en tránsito
-- al 30-sep y el banco trae en octubre). Un movimiento de los primeros
-- meses que es una de ellas NO se clasifica ni se cobra: ya está en el
-- saldo de la apertura, y hacerlo lo mete dos veces (el cheque 1043 otra
-- vez al costo; el depósito del 30 otra vez a 1010 como un aporte). Se
-- ofrece, para casarlo con ella (fn_banco_casar_con):
--   · la partida por lo que falta de ella, igual al movimiento (primero la
--     del mismo número de cheque: el de CHECKNUM o el de NAME);
--   · la partida que este movimiento suma con OTROS pendientes (uno o dos)
--     de la misma cuenta: el depósito del 30 que el banco trajo en dos
--     depósitos móviles ({"partida_apertura", "movimientos": [los otros]});
--   · y, en las dos primeras semanas y si no hay nada de lo anterior, la
--     partida de la que puede ser una PARTE (pide su motivo).
-- Devuelve la lista de opciones (o nulo). fuertes: cuántas son del mismo
-- monto o suman (las que frenan clasificar sin motivo).
create or replace function public.fn_banco_apertura_opciones(m public.movimientos_banco)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_corte date := fn_puente_corte();
  v_chq   text := fn_banco_cheque_num(m.cheque, m.descripcion);
  v_ops   jsonb := '[]'::jsonb;
  v_part  jsonb := '[]'::jsonb;
  v_n     int := 0;
  r       record;
  s       record;
begin
  if m.estado <> 'pendiente' or m.fecha < v_corte or m.fecha > v_corte + 180 or m.monto = 0 then
    return null;
  end if;
  for r in
    select pa.id, pa.fecha, (pa.monto - coalesce(x.llego, 0))::numeric(14,2) as resto, pa.monto as total,
           nullif(ltrim(pa.cheque, '0'), '') as cheque, pa.descripcion
      from conciliacion_partidas pa
      join conciliaciones c on c.id = pa.conciliacion_id
      left join lateral (select sum(mm.monto) as llego
                           from banco_casados bc join movimientos_banco mm on mm.id = bc.movimiento_id
                          where bc.clase = 'apertura' and bc.deshecho_el is null and bc.referencia = pa.id::text) x on true
     where c.cuenta = m.cuenta and c.tipo = 'apertura' and c.estado = 'confirmada' and pa.lado = 'libro' and pa.asiento_id is null
       and pa.clase <> 'error'
       and sign(pa.monto - coalesce(x.llego, 0)) = sign(m.monto) and abs(m.monto) <= abs(pa.monto - coalesce(x.llego, 0))
       and (pa.cheque is null or v_chq is null or nullif(ltrim(pa.cheque, '0'), '') = v_chq)
     order by (nullif(ltrim(pa.cheque, '0'), '') = v_chq) desc nulls last, (pa.monto - coalesce(x.llego, 0) = m.monto) desc, pa.fecha, pa.id
  loop
    if r.resto = m.monto then
      v_n := v_n + 1;
      v_ops := v_ops || jsonb_build_array(jsonb_build_object(
        'texto', format('Es la partida en tránsito del 30-sep (la conciliación de apertura): %s del %s por %s%s',
                        coalesce(r.descripcion, 'la partida'), r.fecha, r.resto,
                        case when r.cheque = v_chq then ', el mismo cheque' when r.resto <> r.total then format(' (lo que falta de %s)', r.total)
                             else '' end),
        'llamar', 'fn_banco_casar_con',
        'args', jsonb_build_object('p_movimiento', m.id, 'p_con', jsonb_build_object('partida_apertura', r.id))));
    elsif r.cheque is null then
      -- Con uno o dos pendientes más de la cuenta, del mismo signo, la suman.
      for s in
        (select array[x.id] as ids, format('el del %s por %s', x.fecha, x.monto) as txt
           from movimientos_banco x
          where x.cuenta = m.cuenta and x.estado = 'pendiente' and x.id <> m.id and x.monto = r.resto - m.monto
            and x.fecha between v_corte and v_corte + 180 and (x.posible_duplicado_de is null or x.duplicado = 'no_es_el_mismo')
          order by abs(x.fecha - m.fecha), x.fecha, x.id
          limit 2)
        union all
        (select array[x.id, y.id], format('los del %s por %s y del %s por %s', x.fecha, x.monto, y.fecha, y.monto)
           from movimientos_banco x
           join movimientos_banco y on y.cuenta = x.cuenta and y.estado = 'pendiente' and y.id > x.id and y.id <> m.id
                                   and y.monto = r.resto - m.monto - x.monto and sign(y.monto) = sign(m.monto)
                                   and y.fecha between v_corte and v_corte + 180
                                   and (y.posible_duplicado_de is null or y.duplicado = 'no_es_el_mismo')
          where x.cuenta = m.cuenta and x.estado = 'pendiente' and x.id <> m.id and sign(x.monto) = sign(m.monto)
            and abs(x.monto) < abs(r.resto - m.monto)
            and x.fecha between v_corte and v_corte + 180 and (x.posible_duplicado_de is null or x.duplicado = 'no_es_el_mismo')
          order by abs(x.fecha - m.fecha) + abs(y.fecha - m.fecha), x.id, y.id
          limit 2)
      loop
        v_n := v_n + 1;
        v_ops := v_ops || jsonb_build_array(jsonb_build_object(
          'texto', format('Con %s suma la partida en tránsito del 30-sep (la conciliación de apertura): %s del %s por %s',
                          s.txt, coalesce(r.descripcion, 'la partida'), r.fecha, r.resto),
          'llamar', 'fn_banco_casar_con',
          'args', jsonb_build_object('p_movimiento', m.id,
                                     'p_con', jsonb_build_object('partida_apertura', r.id, 'movimientos', to_jsonb(s.ids)))));
      end loop;
      if m.fecha <= v_corte + 15 then
        v_part := v_part || jsonb_build_array(jsonb_build_object(
          'texto', format('Es una parte de la partida en tránsito del 30-sep: %s del %s (faltan %s): el banco la trajo en partes',
                          coalesce(r.descripcion, 'la partida'), r.fecha, r.resto),
          'llamar', 'fn_banco_casar_con', 'pide_motivo', true,
          'args', jsonb_build_object('p_movimiento', m.id, 'p_con', jsonb_build_object('partida_apertura', r.id))));
      end if;
    end if;
  end loop;
  if v_n = 0 then
    v_ops := v_part;
  end if;
  return case when jsonb_array_length(v_ops) > 0 then jsonb_build_object('opciones', v_ops, 'fuertes', v_n) end;
end $$;
revoke execute on function public.fn_banco_apertura_opciones(public.movimientos_banco) from public, anon, authenticated, service_role;

-- (Ronda 4) LA APERTURA QUE TODAVÍA NO ESTÁ CONCILIADA en una cuenta de
-- banco: 'sin_apertura' si el asiento de apertura no está posteado todavía
-- (hoy en producción: la balanza de QuickBooks llega hacia el 9-oct);
-- 'sin_conciliar' si la cuenta tiene su saldo de apertura y su
-- conciliación de apertura no está confirmada; nulo si ya lo está (o la
-- cuenta no es un banco, o no estaba en QuickBooks). Mientras tanto, un
-- cheque o un depósito de los primeros 30 días puede ser una partida que
-- QuickBooks tenía en tránsito al 30-sep (ya está en el saldo de la
-- apertura): la propuesta lo dice, y con la apertura posteada clasificarlo
-- o cobrarlo pide su motivo. Antes la bandeja lo daba por un gasto o un
-- cobro más y el dinero entraba dos veces sin que nada lo dijera.
create or replace function public.fn_banco_apertura_estado(p_cuenta text)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select case
           when fn_banco_tipo_cuenta(p_cuenta) is distinct from 'banco' then null
           when exists (select 1 from conciliaciones c where c.cuenta = p_cuenta and c.tipo = 'apertura' and c.estado = 'confirmada')
           then null
           when not exists (select 1 from asientos a
                             where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                               and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso'))
           then 'sin_apertura'
           when exists (select 1 from asientos a join asiento_lineas l on l.asiento_id = a.id
                         where a.tipo = 'apertura' and l.cuenta = p_cuenta and a.camino not in ('reverso', 'reverso_automatico')
                           and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso'))
           then 'sin_conciliar' end
$$;
revoke execute on function public.fn_banco_apertura_estado(text) from public, anon, authenticated, service_role;

-- (Ronda 4) ¿Puede ser este movimiento una partida de la apertura que
-- todavía no se concilió? El aviso en palabras (o nulo): un cheque o un
-- depósito de un banco, de los primeros 30 días, con su apertura sin
-- conciliar (fn_banco_apertura_estado).
create or replace function public.fn_banco_apertura_aviso(m public.movimientos_banco)
returns text
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_corte date := fn_puente_corte();
  v_est   text;
begin
  if m.fecha < v_corte or m.fecha > v_corte + 30 or m.monto = 0
     or not (m.monto > 0 or fn_banco_cheque_num(m.cheque, m.descripcion) is not null) then
    return null;
  end if;
  v_est := fn_banco_apertura_estado(m.cuenta);
  if v_est is null then
    return null;
  end if;
  return format('Falta %s de %s (lo que QuickBooks tenía en tránsito al 30-sep): %s del %s por %s puede ser de septiembre y ya '
                'estar en el saldo de la apertura. %s',
                case v_est when 'sin_apertura' then 'la apertura (y su conciliación)' else 'la conciliación de apertura' end,
                m.cuenta, case when m.monto > 0 then 'un depósito' else 'un cheque' end, m.fecha, m.monto,
                case v_est when 'sin_apertura'
                           then 'Si lo es, espera a conciliar la apertura (casa solo con su partida); si es de octubre, dilo en el '
                                'motivo.'
                           else 'Concilia la apertura antes (fn_conciliacion_apertura: casa solo con su partida); si de verdad es '
                                'de octubre, dilo en el motivo.' end);
end $$;
revoke execute on function public.fn_banco_apertura_aviso(public.movimientos_banco) from public, anon, authenticated, service_role;

-- (Ronda 4) LA CLAVE DE UNA PARTIDA DE LA APERTURA para lo que Edgar dijo
-- que no es (propuesta.apertura_no): su fecha, su monto y su cheque. No su
-- id: fn_conciliacion_apertura rehace las partidas cada vez que se llama, y
-- con el id lo dicho se perdía al volver a calcularla.
create or replace function public.fn_banco_partida_clave(p_fecha date, p_monto numeric, p_cheque text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$ select format('%s|%s|%s', p_fecha, p_monto, coalesce(nullif(ltrim(btrim(p_cheque), '0'), ''), '')) $$;
revoke execute on function public.fn_banco_partida_clave(date, numeric, text) from public, anon, authenticated, service_role;

-- (Ronda 4) LAS PARTIDAS DE LA APERTURA QUE EL BANCO YA TRAJO Y SE CASARON
-- CON OTRA COSA: el banco de octubre se trabajó antes de conciliar la
-- apertura (la balanza llega días después) y el cheque 1038 se clasificó al
-- costo, o el depósito del 30-sep se registró como un anticipo; después la
-- conciliación de apertura los pone en tránsito. Antes nada los juntaba:
-- entraban dos veces (en QuickBooks y otra vez en octubre) y octubre se
-- confirmaba con su motivo «sigue en tránsito». Cada partida sin llegar
-- (de la conciliación p_conc, o de la confirmada de la cuenta) con el
-- movimiento casado que la explica: el mismo cheque (su número) y el mismo
-- monto; o, sin cheque, el mismo monto en los primeros 15 días. Lo que
-- Edgar ya dijo que no es (fn_banco_duplicado con false) no sale. El texto
-- dice qué hacer. Lo cuentan las conciliaciones como posible duplicado
-- (n_dudosas: frenan la confirmación).
create or replace function public.fn_banco_apertura_casadas(p_cuenta text, p_conc uuid default null)
returns table (partida uuid, movimiento uuid, texto text)
language sql
stable
set search_path = public, pg_temp
as $$
  with pa as (
    select pa.id, pa.fecha, pa.descripcion, nullif(ltrim(pa.cheque, '0'), '') as cheque,
           fn_banco_partida_clave(pa.fecha, pa.monto, pa.cheque) as clave,
           (pa.monto - coalesce((select sum(mm.monto) from banco_casados bc join movimientos_banco mm on mm.id = bc.movimiento_id
                                  where bc.clase = 'apertura' and bc.deshecho_el is null and bc.referencia = pa.id::text), 0)) as resto
      from conciliacion_partidas pa
      join conciliaciones c on c.id = pa.conciliacion_id
     where c.cuenta = p_cuenta and c.tipo = 'apertura' and pa.lado = 'libro' and pa.asiento_id is null and pa.clase <> 'error'
       and pa.resuelta_por_movimiento is null
       and case when p_conc is not null then c.id = p_conc else c.estado = 'confirmada' end),
  cand as (
    select pa.id as partida, m.id as mov, m.fecha, m.monto, m.descripcion, m.casado_clase, m.casado_regla, m.asiento_id,
           fn_banco_cheque_num(m.cheque, m.descripcion) as chq, pa.cheque, pa.descripcion as pdesc, pa.fecha as pfecha
      from pa
      join movimientos_banco m on m.cuenta = p_cuenta and m.monto = pa.resto and m.estado in ('casado', 'en_transito')
                              and m.fecha between fn_puente_corte() and fn_puente_corte() + 60
                              and m.casado_clase is distinct from 'apertura'
     where pa.resto <> 0
       and ((pa.cheque is not null and fn_banco_cheque_num(m.cheque, m.descripcion) = pa.cheque)
            or (pa.cheque is null and fn_banco_cheque_num(m.cheque, m.descripcion) is null and m.fecha <= fn_puente_corte() + 15))
       and not coalesce(m.propuesta->'apertura_no' ? pa.clave, false)),
  una as (select distinct on (cand.partida) cand.* from cand order by cand.partida, (cand.chq is not null) desc, cand.fecha, cand.mov)
  select distinct on (una.mov) una.partida, una.mov,
         format('%s del %s por %s («%s») ya está casado (%s%s) y puede ser la partida «%s» del %s: si lo es, %s. Si es otro dinero, '
                'dilo (fn_banco_duplicado con el movimiento %s, false y su motivo)',
                case when una.chq is not null then 'el cheque ' || una.chq when una.monto > 0 then 'el depósito' else 'el cargo' end,
                una.fecha, una.monto, coalesce(una.descripcion, ''),
                coalesce(una.casado_regla, una.casado_clase),
                coalesce(', ' || (select a.numero from asientos a where a.id = una.asiento_id), ''),
                coalesce(una.pdesc, 'en tránsito'), una.pfecha,
                case when una.casado_clase = 'cobro'
                     then format('des-cásalo (fn_banco_descasar, con su motivo) y anula ese cobro (fn_cobro_anular, con su '
                                 'motivo): vuelve a la bandeja y se casa con ella (QuickBooks ya lo tenía cobrado)')
                     else 'des-cásalo (fn_banco_descasar, con su motivo: su asiento se reversa): vuelve a la bandeja y se casa con '
                          'ella (QuickBooks ya lo tenía)' end,
                una.mov)
    from una
   order by una.mov, una.partida
$$;
revoke execute on function public.fn_banco_apertura_casadas(text, uuid) from public, anon, authenticated, service_role;

-- LA PROPUESTA de un movimiento que no casó solo (lo que ve la bandeja): el
-- motivo (un código), el texto en llano, y las opciones: cada una con la
-- función que la resuelve y sus argumentos (conta.js pinta un botón por
-- opción). p_cands: lo del libro que casaría por monto y fecha, pero no
-- solo (varios, o que otro movimiento también quiere, o un cheque viejo
-- que no dice su número); p_obra: la obra con visita el día de la compra
-- (fn_banco_obra_de: {proyecto_id, dia} o {proyecto_id, desde, hasta}, o
-- {varias}: las de esos días, y no se adivina); p_ctx: el contexto de
-- arriba (sin él, lo lee); p_otros: los tickets con otro total que más
-- se le parecen, hasta tres (la regla de fn_banco_otro_total; los calcula
-- el motor, una vez por llamada).
-- (Las versiones anteriores, sin p_ctx, sin p_otros o con la obra como
-- texto, se quitan: con las dos, una llamada sería ambigua.)
drop function if exists public.fn_banco_proponer(public.movimientos_banco, jsonb, text);
drop function if exists public.fn_banco_proponer(public.movimientos_banco, jsonb, text, jsonb);
drop function if exists public.fn_banco_proponer_base(public.movimientos_banco, jsonb, text, jsonb);
create or replace function public.fn_banco_proponer_base(m public.movimientos_banco, p_cands jsonb, p_obra jsonb,
                                                         p_ctx jsonb default null, p_otros jsonb default null)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  k        jsonb := coalesce(p_ctx, fn_banco_contexto());
  -- NAME y MEMO (las propuestas); NAME solo (transferencias y pagos de
  -- tarjeta: el MEMO lo escribe quien manda el dinero).
  v_txt    text := case when m.memo is null then m.desc_norm else btrim(m.desc_norm || ' ' || fn_banco_norm(m.memo)) end;
  v_dn     text := m.desc_norm;
  v_tipo   text;
  v_cxp    text := k->>'cxp';
  v_obra   jsonb;
  v_dup    movimientos_banco;
  v_lista  jsonb;
  v_n      int;
  v_pid    text;
  v_p      prestamos;
  v_cta    text;
  v_x      numeric := abs(m.monto);
  v_pagos  jsonb;
  v_es_tr  boolean;
  v_es_pt  boolean;
  v_es_pr  boolean;
  v_es_fee boolean;
  v_abono  boolean := false;
  v_bloq   text;
  v_part   jsonb;
  v_reemb  jsonb;
  v_nombra text;
  v_exacta boolean;
  v_devol  jsonb;
  v_contra jsonb;
  v_dest   jsonb;
  v_tr     jsonb;
  v_ya_tr  jsonb;
  v_varias text;
  v_proc   boolean := false;
  v_cuota  jsonb;
  v_senal  boolean;
  v_sin_nombre boolean := false;
  v_cobros jsonb;
  v_grupos jsonb;
  v_fact   jsonb;
  v_hay_cobros boolean;
  v_otro_cobro jsonb;
  v_cxcb   text := fn_puente_cuenta_de('cxc');
  v_otra   text;
  v_otra_cta text;
  v_personal boolean := false;
  v_pers   jsonb;
begin
  v_tipo := coalesce(k->'tipos'->>m.cuenta, fn_banco_tipo_cuenta(m.cuenta));
  -- (la obra con visita el DÍA DE LA COMPRA, no el del banco: la débito de
  -- Chase no trae DTUSER y postea de 1 a 3 días después; antes la compra
  -- del martes en el Taller Ruiz salía con la obra de la visita del jueves)
  if p_obra ? 'proyecto_id' then
    select jsonb_build_object('proyecto_id', p.id, 'nombre', p.nombre,
                              'por', case when p_obra ? 'dia'
                                          then format('la obra con visita el día de la compra, %s (eventos)', p_obra->>'dia')
                                          else format('la única obra con visita del %s al %s (eventos): el banco no dice el día de '
                                                      'la compra', p_obra->>'desde', p_obra->>'hasta') end)
      into v_obra from proyectos p where p.id = p_obra->>'proyecto_id';
  elsif p_obra ? 'varias' then
    select format(' Con visita esos días: %s. El banco no dice en cuál fue la compra: elige la obra.',
                  string_agg(format('%s el %s', coalesce(pj.nombre, x->>'proyecto_id'), x->>'dia'), ', ' order by x->>'dia', pj.nombre))
      into v_varias
      from jsonb_array_elements(p_obra->'varias') x left join proyectos pj on pj.id = x->>'proyecto_id';
  end if;

  -- 0. ¿El mismo que otro que ya entró por el otro camino?
  if m.posible_duplicado_de is not null and m.duplicado is null then
    select * into v_dup from movimientos_banco where id = m.posible_duplicado_de;
    return jsonb_build_object(
      'motivo', 'posible_duplicado', 'regla', 'importación',
      'texto', format('¿Es el mismo movimiento que el del %s por %s «%s» (entró por %s)? El mismo dinero no entra dos veces: '
                      'dilo y sigue.', v_dup.fecha, v_dup.monto, coalesce(v_dup.descripcion, ''), v_dup.origen),
      'duplicado_de', v_dup.id,
      'opciones', jsonb_build_array(
        jsonb_build_object('texto', 'Es el mismo (no entra)', 'llamar', 'fn_banco_duplicado',
                           'args', jsonb_build_object('p_movimiento', m.id, 'p_es_el_mismo', true)),
        jsonb_build_object('texto', 'Es otro movimiento', 'llamar', 'fn_banco_duplicado',
                           'args', jsonb_build_object('p_movimiento', m.id, 'p_es_el_mismo', false))));
  end if;

  -- 1. Lo del libro que casaría, pero no solo: se elige. (El otro lado de
  -- una transferencia que ya está en el libro, en su ventana, también sale
  -- aquí: se casa con ESE asiento, nunca otra transferencia.)
  v_n := coalesce(jsonb_array_length(p_cands), 0);
  if v_n > 0 then
    v_es_tr := not exists (select 1 from jsonb_array_elements(p_cands) c where not coalesce((c->>'tr')::boolean, false));
    -- (el otro lado de una transferencia cuyo asiento, al casarlo, se
    -- movería dentro de una conciliación confirmada: se dice cuál reabrir)
    select string_agg(distinct x.b, '; ') into v_bloq
      from (select fn_banco_transferencia_bloqueo(m.id, (c->>'asiento_id')::uuid) as b
              from jsonb_array_elements(p_cands) c where coalesce((c->>'tr')::boolean, false)) x
     where x.b is not null;
    return jsonb_strip_nulls(jsonb_build_object(
      'motivo', case when v_es_tr then 'transferencia_otro_lado' else 'varios_candidatos' end,
      'regla', case when v_es_tr then 'R3' else 'R1' end,
      'texto', case when v_es_tr
                    then 'Es el otro lado de una transferencia que ya está en el libro: cásalo con ella. Otra transferencia '
                         'pondría el mismo dinero dos veces.'
                         || case when v_n > 1 then ' Hay más de una por ese monto: elige la de su fecha.' else '' end
                         || coalesce(' Pero no se casa todavía: ' || v_bloq || '.', '')
                    -- (lo que Edgar des-casó no vuelve a casar solo: se dice, y
                    -- no que «otro movimiento también podría» si no lo hay)
                    when v_n = 1 and p_cands->0->>'descasado' is not null
                    then format('Lo des-casaste de esto (%s): no vuelve a casar solo. Si sí era esto, confirma el cruce. %s',
                                p_cands->0->>'descasado',
                                case when p_cands->0->>'origen_tabla' = 'cobros'
                                     then 'Si el cobro era de otra factura, anúlalo (fn_cobro_anular, con su motivo) y registra '
                                          'el bueno con este depósito (fn_banco_cobrar): cambiarlo de factura es eso.'
                                     else 'Si es otra cosa, di de qué es.' end)
                    when v_n = 1 and coalesce((p_cands->0->>'debil')::boolean, false)
                    then 'Puede ser esto del libro (el mismo monto; un cheque tarda en cobrarse): si lo es, confirma el cruce. '
                         'Clasificarlo lo metería dos veces.'
                    when v_n = 1 and coalesce((p_cands->0->>'otros')::int, 0) > 0
                    then 'Casa con esto del libro (mismo monto, fecha cercana), pero otro movimiento también podría: '
                         'confirma el cruce.'
                    when v_n = 1 then 'Casa con esto del libro (mismo monto, fecha cercana): confirma el cruce.'
                    else format('Casa con %s cosas del libro por el mismo monto y fecha cercana: elige cuál.', v_n) end,
      'candidatos', p_cands,
      'opciones', (select jsonb_agg(jsonb_build_object(
                           'texto', case when coalesce((c->>'tr')::boolean, false)
                                         then 'Es el otro lado de la ' || coalesce(c->>'papel', c->>'numero')
                                         else 'Confirmar cruce con ' || coalesce(c->>'papel', c->>'numero') end,
                           'llamar', 'fn_banco_casar_con',
                           'args', jsonb_build_object('p_movimiento', m.id, 'p_con', jsonb_build_object('lineas', c->'lineas'))))
                     from jsonb_array_elements(p_cands) c)
                  || case when v_n = 1 and p_cands->0->>'descasado' is not null and p_cands->0->>'origen_tabla' = 'cobros'
                          then jsonb_build_array(jsonb_build_object(
                                 'texto', 'El cobro era de otra factura: anúlalo (con su motivo) y registra el bueno con este depósito',
                                 'llamar', 'fn_cobro_anular', 'pide_motivo', true,
                                 'args', jsonb_build_object('p_cobro', p_cands->0->>'origen_id')))
                          else '[]'::jsonb end));
  end if;

  -- 2. La nómina: espera su journal.
  if m.monto < 0 and coalesce(v_txt ~* (k->'pat'->>'nomina'), false) then
    return jsonb_build_object(
      'motivo', 'nomina', 'regla', 'R6',
      'texto', 'Débito de nómina: espera el journal de nómina (f11); cuando entre, casa solo con su línea del banco. No se '
               'clasifica a mano: la mano de obra entra solo por su journal. Si es la nómina del proveedor anterior (antes de '
               'Gusto), registra su journal desde el SQL Editor: fn_banco_nomina(movimiento, las líneas de su journal).');
  end if;

  -- 3. Un depósito devuelto (cheque rebotado) o revertido: la devolución de
  -- su cobro (la factura vuelve a quedar por cobrar). ANTES que el cargo del
  -- banco: «DEPOSITED ITEM RETURNED NSF» dice NSF y no es una comisión; antes
  -- salía como «Cargo del banco · 6130», su único botón dejaba la factura
  -- cobrada y 9,000 de gasto. Su comisión («RETURNED ITEM FEE», un FEE o
  -- una palabra FEE o CHARGE) sí es un cargo del banco: va abajo.
  v_es_fee := coalesce(m.tipo_banco, '') in ('FEE', 'SRVCHG') or v_txt ~ '(^| )(FEE|CHARGE)( |$)';
  if v_tipo = 'banco' and m.monto < 0 and not v_es_fee and coalesce(v_txt ~* (k->'pat'->>'cheque_devuelto'), false) then
    select jsonb_agg(jsonb_build_object('texto', format('Devolver el cobro del %s por %s%s', c.fecha, c.monto,
                                                        coalesce(' (ref ' || c.referencia || ')', '')),
                                        'llamar', 'fn_banco_devolver',
                                        'args', jsonb_build_object('p_movimiento', m.id, 'p_cobro', c.id,
                                                                   'p_motivo', 'El banco lo devolvió: ' || coalesce(m.descripcion, '')))
                     order by c.fecha desc)
      into v_lista
      from (select c.* from cobros c
             where c.estado = 'vigente' and c.cuenta = m.cuenta and c.monto = -m.monto and c.fecha between m.fecha - 90 and m.fecha
               and not exists (select 1 from cobros_devoluciones d where d.cobro_id = c.id)
             order by c.fecha desc limit 5) c;
    -- (el cheque de un depósito de VARIOS: su cobro los junta —el depósito de
    -- dos cheques entró como un cobro de 13,000.00— y rebota uno; su
    -- factura, o su aplicación, suma lo devuelto. Antes no salía nada y el
    -- texto mandaba a fn_banco_devolver, que pedía el cobro entero)
    select jsonb_agg(jsonb_build_object(
             'texto', format('Rebotó el cheque de la factura #%s (%s) del depósito del %s por %s: se devuelve ese cobro y lo que no '
                             'rebotó (%s) se registra otra vez en esta fecha', c.num, -m.monto, c.fecha, c.monto, c.monto + m.monto),
             'llamar', 'fn_banco_devolver',
             'args', jsonb_build_object('p_movimiento', m.id, 'p_cobro', c.app,
                                        'p_motivo', 'El banco lo devolvió: ' || coalesce(m.descripcion, '')))
             order by c.fecha desc, c.num)
      into v_part
      from (select c.id, c.fecha, c.monto, g.app, fa.num
              from cobros c
              join lateral (select x.factura_id as f, min(x.id::text) as app, sum(x.monto) as s
                              from aplicaciones_cobro x where x.cobro_id = c.id group by x.factura_id) g on g.s = -m.monto
              join facturas fa on fa.id = g.f
             where c.estado = 'vigente' and c.cuenta = m.cuenta and c.monto > -m.monto and c.fecha between m.fecha - 90 and m.fecha
               and not exists (select 1 from cobros_devoluciones d where d.cobro_id = c.id)
               and not exists (select 1 from aplicaciones_cobro x where x.cobro_id = c.id and (x.factura_id is null or x.desde_anticipo))
             order by c.fecha desc limit 5) c;
    -- (Ronda 4: los dos cheques de la MISMA factura: el cobro tiene una sola
    -- aplicación, más grande que lo que rebotó; rebotó una parte de ella)
    select coalesce(v_part, '[]'::jsonb) || coalesce(jsonb_agg(jsonb_build_object(
             'texto', format('Rebotó %s del depósito del %s (el cobro de %s a la factura #%s): se devuelve ese cobro y quedan %s '
                             'cobrados de ella, registrados otra vez en esta fecha', -m.monto, c.fecha, c.monto, c.num,
                             c.monto + m.monto),
             'llamar', 'fn_banco_devolver',
             'args', jsonb_build_object('p_movimiento', m.id, 'p_cobro', c.app,
                                        'p_motivo', 'El banco lo devolvió: ' || coalesce(m.descripcion, '')))
             order by c.fecha desc, c.num), '[]'::jsonb)
      into v_part
      from (select c.id, c.fecha, c.monto, x.id as app, fa.num
              from cobros c
              join aplicaciones_cobro x on x.cobro_id = c.id
              join facturas fa on fa.id = x.factura_id
             where c.estado = 'vigente' and c.cuenta = m.cuenta and c.monto > -m.monto and c.fecha between m.fecha - 90 and m.fecha
               and x.monto > -m.monto and x.descuento = 0 and not x.desde_anticipo
               and (select count(*) from aplicaciones_cobro y where y.cobro_id = c.id) = 1
               and not exists (select 1 from cobros_devoluciones d where d.cobro_id = c.id)
             order by c.fecha desc limit 5) c;
    v_part := nullif(v_part, '[]'::jsonb);
    -- (Ronda 4: sin cobro en la app, el cheque de una factura de QuickBooks
    -- —de antes del corte, cobrada allí: el depósito del 30-sep en tránsito
    -- que rebota en octubre—: vuelve a quedar por cobrar contra su partida.
    -- Primero la que nombra una partida de la apertura; después, la del
    -- mismo monto.)
    if v_lista is null and v_part is null then
      select jsonb_agg(jsonb_build_object(
               'texto', format('Rebotó el cheque de la factura #%s (%s, de QuickBooks: cobrada antes del corte): vuelve a quedar '
                               'por cobrar %s', f.num, f.proyecto_id, -m.monto),
               'llamar', 'fn_banco_clasificar',
               'args', jsonb_build_object('p_movimiento', m.id,
                                          'p_lineas', jsonb_build_array(jsonb_build_object('cuenta', v_cxcb, 'factura_id', f.id)),
                                          'p_motivo', 'El banco lo devolvió: ' || coalesce(m.descripcion, '')))
               order by f.nombrada desc, f.fecha desc, f.id)
        into v_part
        from (select f.id, f.num, f.proyecto_id, f.fecha,
                     exists (select 1 from conciliacion_partidas pa join conciliaciones c on c.id = pa.conciliacion_id
                              where c.cuenta = m.cuenta and c.tipo = 'apertura' and pa.lado = 'libro'
                                and pa.descripcion ~ ('#' || f.num || '([^0-9]|$)')) as nombrada
                from facturas f
               where f.fecha < fn_puente_corte() and f.estado is distinct from 'anulada' and f.monto >= -m.monto
                 and coalesce((select sum(l.monto) from asiento_lineas l
                                where l.partida_tabla = 'facturas' and l.partida_id = f.id::text
                                  and l.cuenta in (v_cxcb, fn_puente_cuenta_de('retencion_cxc'))), 0) - m.monto <= round(f.monto, 2)
                 and (f.monto = -m.monto
                      or exists (select 1 from conciliacion_partidas pa join conciliaciones c on c.id = pa.conciliacion_id
                                  where c.cuenta = m.cuenta and c.tipo = 'apertura' and pa.lado = 'libro'
                                    and pa.descripcion ~ ('#' || f.num || '([^0-9]|$)')))
               order by 5 desc, f.fecha desc, f.id
               limit 5) f;
    end if;
    return jsonb_strip_nulls(jsonb_build_object(
      'motivo', 'devolucion', 'regla', 'R9',
      'texto', case when v_lista is null and v_part is not null and v_part->0->>'llamar' = 'fn_banco_clasificar'
                    then 'Un depósito devuelto o revertido, sin un cobro en la app por ese monto: ¿el cheque de una factura de '
                         'QuickBooks (cobrada antes del corte)? Vuelve a quedar por cobrar contra su partida (la cuenta por cobrar '
                         'de esa factura, con su motivo). No es un gasto del banco ni baja el ingreso.'
                    when v_lista is null and v_part is null
                    then 'Un depósito devuelto o revertido, y no encuentro un cobro vigente por ese monto en los últimos 90 días: '
                         '¿de cuál es? (fn_banco_devolver con su cobro; si el depósito era de varios cheques y su cobro los junta, '
                         'con la aplicación del que rebotó; si es de una factura de QuickBooks, fn_banco_clasificar con '
                         '{"cuenta": "' || v_cxcb || '", "factura_id": …} y su motivo). No es un gasto del banco.'
                    when v_lista is null
                    then 'Un depósito devuelto: el cheque de un depósito de varios, y su cobro los junta. Se devuelve el cobro en '
                         'esta fecha y lo que no rebotó se registra otra vez el mismo día (lo que no rebotó sigue cobrado; lo del '
                         'cheque que rebotó vuelve a quedar por cobrar, aunque sea de la misma factura). No es un gasto del banco.'
                    else 'Un depósito devuelto o revertido: se devuelve su cobro en esta fecha (la factura vuelve a quedar por '
                         'cobrar). No es un gasto del banco.' end,
      'opciones', case when v_lista is not null or v_part is not null
                       then coalesce(v_lista, '[]'::jsonb) || coalesce(v_part, '[]'::jsonb) end));
  end if;

  -- 4. Un cargo del banco o de la tarjeta que la regla fija no tomó (el tipo
  -- del banco no lo confirma): se propone.
  if m.monto < 0 and coalesce(v_txt ~* (k->'pat'->>'cargo_banco'), false) then
    v_cta := k->'dest'->>'cargo_banco';
    return jsonb_build_object(
      'motivo', 'cargo_banco', 'regla', 'R7',
      'texto', format('Parece un cargo del banco o de la tarjeta (%s), pero el tipo del banco (%s) no lo confirma: confírmalo.',
                      v_cta, coalesce(m.tipo_banco, 'sin tipo')),
      'opciones', jsonb_build_array(jsonb_build_object('texto', 'Cargo del banco · ' || v_cta, 'llamar', 'fn_banco_clasificar',
                                     'args', jsonb_build_object('p_movimiento', m.id,
                                                                'p_lineas', jsonb_build_array(jsonb_build_object('cuenta', v_cta))))));
  end if;

  -- 5. Intereses: los que paga el banco (4910) y los que cobra la tarjeta (7100).
  if v_tipo = 'banco' and m.monto > 0 and (m.tipo_banco = 'INT' or coalesce(v_txt ~* (k->'pat'->>'interes'), false)) then
    v_cta := k->'dest'->>'interes';
    return jsonb_build_object(
      'motivo', 'interes', 'regla', 'R7',
      'texto', format('Parecen intereses del banco (%s), pero el tipo y la descripción no lo dicen los dos: confírmalo.', v_cta),
      'opciones', jsonb_build_array(jsonb_build_object('texto', 'Intereses · ' || v_cta, 'llamar', 'fn_banco_clasificar',
                                     'args', jsonb_build_object('p_movimiento', m.id,
                                                                'p_lineas', jsonb_build_array(jsonb_build_object('cuenta', v_cta))))));
  end if;
  if v_tipo = 'tarjeta' and m.monto < 0 and (m.tipo_banco = 'INT' or coalesce(v_txt ~* (k->'pat'->>'interes_tarjeta'), false)) then
    v_cta := k->'dest'->>'interes_tarjeta';
    return jsonb_build_object(
      'motivo', 'interes_tarjeta', 'regla', 'R10',
      'texto', format('Intereses de la tarjeta: %s.', v_cta),
      'opciones', jsonb_build_array(jsonb_build_object('texto', 'Intereses · ' || v_cta, 'llamar', 'fn_banco_clasificar',
                                     'args', jsonb_build_object('p_movimiento', m.id,
                                                                'p_lineas', jsonb_build_array(jsonb_build_object('cuenta', v_cta))))));
  end if;

  -- 6. Retiro de cajero: pregunta, nunca automático.
  if v_tipo = 'banco' and m.monto < 0 and (m.tipo_banco = 'ATM' or coalesce(v_txt ~* (k->'pat'->>'cajero'), false)) then
    return jsonb_build_object(
      'motivo', 'cajero', 'regla', 'R5',
      'texto', '¿Caja chica o para ti? Un retiro de cajero no es gasto: entra a la caja chica (1050) y cada compra en efectivo sale '
               'de ahí con su ticket; o es para Edgar (3200, distribución).',
      'opciones', jsonb_build_array(
        jsonb_build_object('texto', 'Caja chica · ' || (k->>'caja'), 'llamar', 'fn_banco_clasificar',
                           'args', jsonb_build_object('p_movimiento', m.id,
                                                      'p_lineas', jsonb_build_array(jsonb_build_object('cuenta', k->>'caja')))),
        jsonb_build_object('texto', 'Para mí · 3200', 'llamar', 'fn_banco_clasificar',
                           'args', jsonb_build_object('p_movimiento', m.id,
                                                      'p_lineas', jsonb_build_array(jsonb_build_object('cuenta', '3200'))))));
  end if;

  -- 7. Un Zelle de Edgar: aporte o préstamo del accionista, nunca ingreso.
  if v_tipo = 'banco' and m.monto > 0 and coalesce(v_txt ~* (k->'pat'->>'zelle_edgar'), false) then
    return jsonb_build_object(
      'motivo', 'aporte_edgar', 'regla', 'R2',
      'texto', 'Dinero de Edgar a la empresa: una aportación (3100) o un préstamo del accionista (2900). Nunca ingreso.',
      'opciones', jsonb_build_array(
        jsonb_build_object('texto', 'Préstamo del accionista · 2900', 'llamar', 'fn_banco_clasificar',
                           'args', jsonb_build_object('p_movimiento', m.id,
                                                      'p_lineas', jsonb_build_array(jsonb_build_object('cuenta', '2900')))),
        jsonb_build_object('texto', 'Aportación · 3100', 'llamar', 'fn_banco_clasificar',
                           'args', jsonb_build_object('p_movimiento', m.id,
                                                      'p_lineas', jsonb_build_array(jsonb_build_object('cuenta', '3100'))))));
  end if;

  -- 8. La cuota de un préstamo. Primero, la cuota que YA está registrada
  -- sin su movimiento (con el statement del prestamista, antes que el
  -- banco) por ese monto: casar con ella, nunca registrar otra. Después, por
  -- su descriptor, la cuota nueva con su partición.
  if v_tipo = 'banco' and m.monto < 0 then
    select jsonb_agg(jsonb_build_object('texto', format('Es la cuota de %s del %s (ya registrada, %s): casar con ella', p.prestamista,
                                                        q.fecha, a.numero),
                                        'llamar', 'fn_banco_casar_con',
                                        'args', jsonb_build_object('p_movimiento', m.id,
                                                                   'p_con', jsonb_build_object('asiento', q.asiento_id)))
                     order by abs(q.fecha - m.fecha), q.fecha)
      into v_cuota
      from prestamo_cuotas q
      join prestamos p on p.id = q.prestamo_id
      join asientos a on a.id = q.asiento_id
     where q.anulada_el is null and q.movimiento_id is null and q.monto = -m.monto and p.cuenta_banco = m.cuenta
       and q.fecha between m.fecha - 60 and m.fecha + 3
       and exists (select 1 from asiento_lineas l
                    where l.asiento_id = q.asiento_id and l.cuenta = m.cuenta
                      and not exists (select 1 from banco_casado_lineas cl
                                       where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente));
    select count(*), min(x->>'id') into v_n, v_pid
      from jsonb_array_elements(k->'prestamos') x
     where x->>'cuenta_banco' = m.cuenta and v_txt ~* (x->>'descriptor');
    if v_cuota is not null then
      return jsonb_build_object(
        'motivo', 'cuota_prestamo', 'regla', 'R8',
        'texto', 'La cuota de este préstamo ya está registrada (con el statement del prestamista) y espera su cargo del banco: '
                 'cásalo con ella. Registrar otra la pondría dos veces (capital e interés).',
        'opciones', v_cuota);
    end if;
    -- (Ronda 4) LA CUOTA YA REGISTRADA POR OTRO MONTO (a 10 días o menos): el
    -- banco cobró la cuota redondeada (1,050.00 por 1,029.33) o con un
    -- recargo. Es ESA cuota: se casa con ella y la diferencia va a capital
    -- (lo pagado de más) o a interés (un recargo), según su statement; la
    -- registrada se anula y se registra otra vez con el cargo. Antes la
    -- bandeja no la nombraba y sus botones registraban OTRA cuota: el
    -- capital bajaba dos veces y la primera quedaba «en circulación» para
    -- siempre.
    select jsonb_agg(x.o order by x.d, x.fecha, x.n) into v_cuota
      from (select abs(q.fecha - m.fecha) as d, q.fecha, n.n,
                   jsonb_build_object(
                     'texto', format('Es la cuota de %s del %s (registrada por %s; el banco cobró %s): %s', p.prestamista, q.fecha,
                                     q.monto, -m.monto,
                                     case n.n when 1 then format('la diferencia (%s) a capital', -m.monto - q.monto)
                                              else format('la diferencia (%s) a interés (un recargo, según el statement)',
                                                          -m.monto - q.monto) end),
                     'llamar', 'fn_banco_casar_con',
                     'args', jsonb_build_object('p_movimiento', m.id,
                                                'p_con', jsonb_build_object('cuota', q.id,
                                                                            'diferencia', case n.n when 1 then 'capital' else 'interes' end))) as o
              from prestamo_cuotas q
              join prestamos p on p.id = q.prestamo_id
              cross join (values (1), (2)) as n(n)
             where q.anulada_el is null and q.movimiento_id is null and q.monto <> -m.monto and p.cuenta_banco = m.cuenta
               and q.fecha between m.fecha - 10 and m.fecha + 10
               and q.capital + (-m.monto - q.monto) * (case n.n when 1 then 1 else 0 end) >= 0
               and q.interes + (-m.monto - q.monto) * (case n.n when 2 then 1 else 0 end) >= 0
               and exists (select 1 from asiento_lineas l
                            where l.asiento_id = q.asiento_id and l.cuenta = m.cuenta
                              and not exists (select 1 from banco_casado_lineas cl
                                               where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente))) x;
    if v_cuota is not null then
      return jsonb_build_object(
        'motivo', 'cuota_prestamo', 'regla', 'R8',
        'texto', 'La cuota de este préstamo ya está registrada, por otro monto, y espera su cargo del banco: es ella (la cuota '
                 'redondeada, o con un recargo). Cásalo con ella: la diferencia va a capital o a interés, según el statement '
                 'del prestamista. Registrar otra la pondría dos veces.',
        'opciones', v_cuota);
    end if;
    if v_n = 1 then
      select p.* into v_p from prestamos p where p.id = v_pid::uuid;
      v_part := fn_prestamo_particion(v_p.id, m.fecha, -m.monto);
      -- Un pago que la fórmula no sabe repartir (a días de la cuota
      -- anterior: un abono aparte; o menos que la cuota) pide el statement.
      -- El abono solo a capital, al final y solo a días de la cuota.
      if coalesce((v_part->>'pide_statement')::boolean, false) then
        return jsonb_build_object(
          'motivo', 'cuota_prestamo', 'regla', 'R8',
          'texto', format('Un pago a %s que la fórmula no sabe repartir (%s). Regístralo con el capital y el interés del statement '
                          'del prestamista (fn_prestamo_cuota con p_capital y p_interes)%s.', v_p.prestamista, v_part->>'aviso',
                          case when v_part->>'aviso' like 'a % días de la cuota%'
                               then '; un abono solo a capital (un «principal only») va entero a capital' else '' end),
          'particion', v_part,
          'opciones', jsonb_build_array(
            jsonb_build_object('texto', format('Con el capital y el interés del statement de %s', v_p.prestamista),
                               'llamar', 'fn_prestamo_cuota', 'pide', jsonb_build_array('p_capital', 'p_interes'),
                               'args', jsonb_build_object('p_prestamo', v_p.id, 'p_movimiento', m.id)))
            || case when v_part->>'aviso' like 'a % días de la cuota%'
                    then jsonb_build_array(
                           jsonb_build_object('texto', format('Abono solo a capital de %s (todo a capital, sin interés)', v_p.prestamista),
                                              'llamar', 'fn_prestamo_cuota',
                                              'args', jsonb_build_object('p_prestamo', v_p.id, 'p_movimiento', m.id,
                                                                         'p_capital', (-m.monto)::text, 'p_interes', '0.00')))
                    else '[]'::jsonb end);
      end if;
      -- (Ronda 4) La cuota del mes con un extra a capital en el mismo cargo:
      -- la fórmula (el interés del mes; el resto, con el extra, a capital).
      if v_part ? 'extra' then
        return jsonb_build_object(
          'motivo', 'cuota_prestamo', 'regla', 'R8',
          'texto', format('Cuota del préstamo de %s con %s de más a capital (%s): la fórmula pone el interés del mes y lo demás a '
                          'capital. Si tienes el statement del prestamista, manda él.', v_p.prestamista, v_part->>'extra',
                          v_part->>'aviso'),
          'particion', v_part,
          'opciones', jsonb_build_array(
            jsonb_build_object('texto', format('Cuota de %s más %s a capital', v_p.prestamista, v_part->>'extra'),
                               'llamar', 'fn_prestamo_cuota',
                               'args', jsonb_build_object('p_prestamo', v_p.id, 'p_movimiento', m.id)),
            jsonb_build_object('texto', format('Con el capital y el interés del statement de %s', v_p.prestamista),
                               'llamar', 'fn_prestamo_cuota', 'pide', jsonb_build_array('p_capital', 'p_interes'),
                               'args', jsonb_build_object('p_prestamo', v_p.id, 'p_movimiento', m.id))));
      end if;
      return jsonb_build_object(
        'motivo', 'cuota_prestamo', 'regla', 'R8',
        'texto', format('Cuota del préstamo de %s: la partición que da la fórmula está abajo; si tienes el statement del '
                        'prestamista, manda él (capital e interés).', v_p.prestamista),
        'particion', v_part,
        'opciones', jsonb_build_array(jsonb_build_object('texto', 'Cuota de ' || v_p.prestamista, 'llamar', 'fn_prestamo_cuota',
                                       'args', jsonb_build_object('p_prestamo', v_p.id, 'p_movimiento', m.id))));
    end if;
  end if;

  -- 9. Dinero entre cuentas propias (el pago de una tarjeta, el pase a la
  -- reserva). En su DIRECCIÓN: de un banco a otro banco o a una tarjeta;
  -- una tarjeta que manda dinero a un banco (un adelanto de efectivo) no se
  -- supone nunca. Los descriptores, en la descripción del banco (NAME), y
  -- con su señal: en el banco, el nombre del emisor de la tarjeta
  -- (pago_tarjeta) o los 4 últimos de una tarjeta de la empresa; en la
  -- tarjeta, que el abono dice que es un pago (pago_recibido). Antes todo
  -- abono en una tarjeta era «dinero entre cuentas propias» y la bandeja
  -- solo ofrecía transferencias: la devolución de Home Depot, confirmada
  -- «desde 1010», dejaba el costo sin bajar y a Chase con un cargo en
  -- circulación que el banco no iba a traer nunca. Un abono sin esa señal
  -- es la devolución de una compra (12, abajo).
  v_es_tr := coalesce(m.tipo_banco, '') = 'XFER' or coalesce(v_dn ~* (k->'pat'->>'transferencia'), false);
  v_es_pt := v_tipo = 'banco' and m.monto < 0
             and (coalesce(v_dn ~* (k->'pat'->>'pago_tarjeta'), false)
                  or exists (select 1 from jsonb_array_elements(k->'propias') x
                              cross join jsonb_array_elements_text(coalesce(x->'u4', '[]'::jsonb)) as u(u4)
                              where x->>'tipo' = 'tarjeta' and v_dn ~ ('(^| )' || u.u4 || '( |$)')));
  v_es_pr := v_tipo = 'tarjeta' and m.monto > 0 and coalesce(v_dn ~* (k->'pat'->>'pago_recibido'), false);
  -- (Ronda 4) LA OTRA CUENTA que nombra la transferencia («TO CHK ...7781»):
  -- si su número no es de la empresa (ni tarjeta ni estado de cuenta que lo
  -- traiga), es la cuenta personal de Edgar: una distribución o un
  -- préstamo, no dinero entre cuentas propias. Antes salían solo las
  -- cuentas propias, sin motivo: 2,000 «en tránsito» en la reserva.
  v_otra := case when v_es_tr and v_tipo = 'banco'
                 -- (en NAME; si el banco lo cortó —«...778»—, en la nota que trae entera)
                 then coalesce(fn_banco_otra_cuenta(v_dn), fn_banco_otra_cuenta(fn_banco_norm(m.memo))) end;
  v_otra_cta := fn_banco_numero_de(v_otra);
  v_personal := v_otra is not null and v_otra_cta is null;
  if v_personal then
    v_pers := case when m.monto < 0
                   then jsonb_build_array(
                          jsonb_build_object('texto', 'Para Edgar (su cuenta ····' || v_otra || '): distribución · 3200',
                                             'llamar', 'fn_banco_clasificar',
                                             'args', jsonb_build_object('p_movimiento', m.id, 'p_lineas',
                                                       jsonb_build_array(jsonb_build_object('cuenta', '3200',
                                                         'memo', left('A la cuenta ····' || v_otra || ' · ' || coalesce(m.descripcion, ''), 200))))),
                          jsonb_build_object('texto', 'Préstamo al accionista · 1130 (se lo devuelve)',
                                             'llamar', 'fn_banco_clasificar',
                                             'args', jsonb_build_object('p_movimiento', m.id, 'p_lineas',
                                                       jsonb_build_array(jsonb_build_object('cuenta', '1130',
                                                         'memo', left('A la cuenta ····' || v_otra || ' · ' || coalesce(m.descripcion, ''), 200))))))
                   else jsonb_build_array(
                          jsonb_build_object('texto', 'De Edgar (su cuenta ····' || v_otra || '): préstamo del accionista · 2900',
                                             'llamar', 'fn_banco_clasificar',
                                             'args', jsonb_build_object('p_movimiento', m.id, 'p_lineas',
                                                       jsonb_build_array(jsonb_build_object('cuenta', '2900',
                                                         'memo', left('Desde la cuenta ····' || v_otra || ' · ' || coalesce(m.descripcion, ''), 200))))),
                          jsonb_build_object('texto', 'Aportación · 3100',
                                             'llamar', 'fn_banco_clasificar',
                                             'args', jsonb_build_object('p_movimiento', m.id, 'p_lineas',
                                                       jsonb_build_array(jsonb_build_object('cuenta', '3100',
                                                         'memo', left('Desde la cuenta ····' || v_otra || ' · ' || coalesce(m.descripcion, ''), 200)))))) end;
  end if;
  if v_es_tr or v_es_pt or v_es_pr then
    -- (El otro lado de una transferencia que YA está en el libro, en su
    -- ventana, es un candidato: sale arriba, en 1.)
    -- a. el otro lado que YA está en el libro FUERA de esa ventana (la
    -- transferencia que puso el otro estado de cuenta, a 10 días o menos,
    -- en cualquier dirección: la Amex abona el viernes y Chase cobra el
    -- martes): se ofrece casar con ella, y otra transferencia solo con su
    -- motivo. Antes la bandeja decía «el otro lado todavía no llegó» y su
    -- único botón posteaba otra: el mismo pago dos veces.
    select jsonb_agg(jsonb_build_object(
                       'texto', format('Es el otro lado de la transferencia %s del %s (ya está en el libro)', l.numero, l.fdoc),
                       'llamar', 'fn_banco_casar_con',
                       'args', jsonb_build_object('p_movimiento', m.id,
                                                  'p_con', jsonb_build_object('lineas', jsonb_build_array(
                                                    jsonb_build_object('asiento_id', l.asiento_id, 'orden', l.orden)))))
                     order by abs(l.fdoc - m.fecha), l.numero)
      into v_ya_tr
      from fn_banco_lineas_libres(array[m.cuenta], m.fecha - 12) l
     where l.tr and l.monto = m.monto and l.fdoc between m.fecha - 10 and m.fecha + 10;
    -- b. el otro lado todavía pendiente, en otra cuenta propia
    select jsonb_agg(x.o order by x.d, x.fecha)
      into v_contra
      from (select abs(x.fecha - m.fecha) as d, x.fecha,
                   jsonb_strip_nulls(jsonb_build_object(
                                      'texto', format('Es la transferencia con %s del %s por %s (%s)', x.cuenta, x.fecha, x.monto,
                                                      coalesce(x.descripcion, '')),
                                      'llamar', 'fn_banco_casar_con',
                                      'args', jsonb_build_object('p_movimiento', m.id,
                                                                 'p_con', jsonb_build_object('movimiento', x.id)),
                                      -- (si su fecha dejaría partida una conciliación: qué reabrir antes)
                                      'bloqueo', fn_banco_tr_fecha(m.fecha, m.cuenta, x.fecha, x.cuenta, m.monto)->>'bloqueo')) as o
              from movimientos_banco x
             where x.estado = 'pendiente' and x.monto = -m.monto and x.fecha between m.fecha - 10 and m.fecha + 10
               and x.cuenta = any (array(select jsonb_object_keys(k->'tipos'))) and x.cuenta <> m.cuenta
               and (x.posible_duplicado_de is null or x.duplicado = 'no_es_el_mismo')
               -- (ronda 4: si nombra la otra cuenta y su número es de otra)
               and (v_otra_cta is null or x.cuenta = v_otra_cta)
               -- (el otro lado, con su señal: el abono de la tarjeta que dice
               -- pago; el cargo del banco que nombra al emisor o la tarjeta)
               and case when m.monto < 0
                        then v_tipo = 'banco'
                             and case when k->'tipos'->>x.cuenta = 'tarjeta'
                                      then v_es_pt and coalesce(x.desc_norm ~* (k->'pat'->>'pago_recibido'), false)
                                      else v_es_tr end
                        else k->'tipos'->>x.cuenta = 'banco'
                             and case when v_tipo = 'tarjeta'
                                      then v_es_pr
                                           and (coalesce(x.desc_norm ~* (k->'pat'->>'pago_tarjeta'), false)
                                                or exists (select 1 from tarjetas t
                                                            where t.cuenta = m.cuenta and t.ultimos4 ~ '^[0-9]{4}$'
                                                              and x.desc_norm ~ ('(^| )' || t.ultimos4 || '( |$)')))
                                      else v_es_tr or coalesce(x.tipo_banco, '') = 'XFER'
                                           or coalesce(x.desc_norm ~* (k->'pat'->>'transferencia'), false) end end
             order by abs(x.fecha - m.fecha), x.fecha
             limit 5) x;
    -- c. a qué cuenta propia (o de cuál viene): se postea la transferencia
    -- y el otro lado, cuando llegue, casa con ella.
    select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                       'texto', format('%s %s (%s)', case when m.monto < 0 then 'A' else 'Desde' end, x->>'codigo', x->>'nombre')
                                || case when fn_banco_transferencia_dudosa(m, x->>'codigo') is not null then ' (con su motivo)'
                                        else '' end,
                       'llamar', 'fn_banco_transferencia',
                       -- (ronda 4: la que no es de la cuenta que nombra el banco,
                       -- o un banco que nunca trajo su estado de cuenta: con su
                       -- motivo, que fn_banco_transferencia exige)
                       'pide_motivo', case when fn_banco_transferencia_dudosa(m, x->>'codigo') is not null then true end,
                       'pide', case when fn_banco_transferencia_dudosa(m, x->>'codigo') is not null
                                    then jsonb_build_array('p_motivo') end,
                       'args', jsonb_build_object('p_movimiento', m.id, 'p_cuenta', x->>'codigo'),
                       'bloqueo', fn_banco_tr_fecha(m.fecha, m.cuenta,
                                                    (select y.fecha from movimientos_banco y
                                                      where y.cuenta = x->>'codigo' and y.estado = 'pendiente' and y.monto = -m.monto
                                                        and y.fecha between m.fecha - 10 and m.fecha + 10
                                                        and (y.posible_duplicado_de is null or y.duplicado = 'no_es_el_mismo')
                                                      order by abs(y.fecha - m.fecha), y.fecha limit 1),
                                                    x->>'codigo', m.monto)->>'bloqueo'))
                     order by x->>'codigo')
      into v_dest
      from jsonb_array_elements(k->'propias') x
     where x->>'codigo' <> m.cuenta
       and case when v_tipo = 'banco' and m.monto < 0 then (v_es_pt and x->>'tipo' = 'tarjeta') or v_es_tr
                when v_tipo = 'banco' then v_es_tr and x->>'tipo' = 'banco'
                when m.monto > 0 then v_es_pr and x->>'tipo' = 'banco'
                else v_es_tr and x->>'tipo' = 'banco' end;
    if v_ya_tr is not null then
      return jsonb_build_object(
        'motivo', 'transferencia_otro_lado', 'regla', 'R3',
        'texto', 'Ya está en el libro la transferencia de este dinero (la puso el otro estado de cuenta, unos días antes o después: '
                 'un fin de semana, un festivo): cásalo con ella. Otra transferencia pondría el mismo dinero dos veces; solo con su '
                 'motivo.',
        'opciones', v_ya_tr
                    || coalesce((select jsonb_agg(o || jsonb_build_object('pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                                                                         'texto', (o->>'texto') || ' (otra transferencia, con su motivo)'))
                                   from jsonb_array_elements(coalesce(v_dest, '[]'::jsonb)) o), '[]'::jsonb));
    end if;
    v_tr := case when v_contra is not null or v_dest is not null then coalesce(v_contra, '[]'::jsonb) || coalesce(v_dest, '[]'::jsonb) end;
    -- (Ronda 4: el retiro a una cuenta que no es de la empresa: primero lo
    -- que es —una distribución o un préstamo al accionista—, y las cuentas
    -- propias, con su motivo.)
    if v_personal and m.monto < 0 then
      return jsonb_build_object(
        'motivo', 'transferencia_personal', 'regla', 'R3',
        'texto', format('Dinero a una cuenta que no es de la empresa (····%s, que no es de ningún estado de cuenta ni tarjeta de la '
                        'empresa: la cuenta personal de Edgar): una distribución (3200) o un préstamo al accionista (1130), nunca '
                        'un gasto ni dinero entre cuentas propias. Si de verdad es una cuenta de la empresa, sube su estado de '
                        'cuenta (su número queda), o confírmala como transferencia con su motivo.', v_otra),
        'opciones', v_pers || coalesce(v_tr, '[]'::jsonb));
    end if;
    -- (Un depósito en un banco pasa primero por sus cobros y sus facturas,
    -- abajo: la transferencia es una opción más, nunca la única.)
    if v_tr is not null and not (v_tipo = 'banco' and m.monto > 0) then
      return jsonb_build_object(
        'motivo', 'transferencia_un_lado', 'regla', 'R3',
        'texto', case when v_contra is not null
                      then 'Es dinero entre cuentas propias (el pago de una tarjeta, el pase a la reserva) y su otro lado ya llegó: '
                           'cásalos (un asiento, sin gasto).'
                      else 'Parece dinero entre cuentas propias (el pago de una tarjeta, el pase a la reserva) y el otro lado todavía '
                           'no llegó. Confírmalo: se postea la transferencia (sin gasto), y el otro lado casará solo con ella '
                           'cuando llegue.' end
                 -- (Ronda 4: si su fecha dejaría partida la conciliación de una
                 -- de las dos cuentas, no se casa sola ni con el botón: se dice
                 -- antes qué reabrir.)
                 || coalesce(' Pero no se casa todavía: ' || (select o->>'bloqueo' from jsonb_array_elements(v_tr) o
                                                               where o ? 'bloqueo' limit 1) || '.', ''),
        'opciones', v_tr)
        || jsonb_strip_nulls(jsonb_build_object('bloqueo', (select o->>'bloqueo' from jsonb_array_elements(v_tr) o
                                                             where o ? 'bloqueo' limit 1)));
    end if;
  end if;

  -- 10. Un pago a un proveedor: su nombre o un alias en la descripción; o,
  -- SIN NOMBRE (fn_banco_pago_anonimo: un cheque o un ACH que no nombra a
  -- nadie, que no es una domiciliación), un pago cuyo monto cuadra con lo
  -- que se le debe (una partida, las más viejas hasta ahí, o todo); y si no
  -- cuadra, un ABONO a lo que se le debe (a lo más viejo) a cada proveedor
  -- que tiene abierto al menos eso. Antes un cheque sin nombre que abonaba
  -- parte de lo que se le debía a CED salía «sin ticket», sin botones y con
  -- el texto que manda a clasificar: clasificado a la obra, el material
  -- contaba dos veces y la deuda con CED seguía entera. Y lo que NOMBRA a
  -- alguien que no es un proveedor (un Zelle a un ayudante o a Edgar, el
  -- pago en línea a FPL, el seguro domiciliado) no es el abono de nadie: es
  -- un cargo sin ticket, con su camino (13).
  if m.monto < 0 then
    v_senal := fn_banco_cheque_num(m.cheque, m.descripcion) is not null
               or coalesce(m.tipo_banco, '') in ('CHECK', 'XFER', 'DIRECTDEBIT', 'PAYMENT')
               or coalesce(v_txt ~* '(BILL ?PAY|[[:<:]]ACH[[:>:]]|[[:<:]]PAYMENT[[:>:]]|[[:<:]]PMT[[:>:]]|EPAY|[[:<:]]WIRE[[:>:]]|[[:<:]]CHECK[[:>:]]|[[:<:]]CHK[[:>:]])', false);
    select jsonb_agg(x.o order by x.nombre) into v_lista
      from (select p->>'nombre' as nombre,
                   jsonb_build_object('texto', 'Pago a ' || (p->>'nombre'), 'proveedor', p->'id', 'llamar', 'fn_banco_pagar_proveedor',
                                      'args', jsonb_build_object('p_movimiento', m.id, 'p_proveedor', p->'id'),
                                      'partidas_abiertas', coalesce(p->'items', '[]'::jsonb)) as o
              from jsonb_array_elements(k->'proveedores') p
             where jsonb_typeof(p->'pats') = 'array'
               and exists (select 1 from jsonb_array_elements_text(p->'pats') t(pat)
                            where position(t.pat in ' ' || v_txt || ' ') > 0)) x;
    -- Una COMPRA con tarjeta (en una tarjeta, o con la débito en el banco:
    -- sin nada que diga pago) con el nombre de un proveedor casi siempre es
    -- una compra de mostrador (el ticket que falta), no el pago de su
    -- cuenta: se propone el pago primero solo si el monto cuadra con lo que
    -- se le debe; si no, va como cargo sin ticket, con el pago como otra
    -- opción. (Antes, en el banco, la compra con la débito salía como pago:
    -- bajaba la factura abierta del proveedor y la compra no llegaba nunca
    -- al costo de la obra.)
    if v_lista is not null and (v_tipo = 'tarjeta' or not v_senal)
       and not exists (select 1 from jsonb_array_elements(v_lista) o where fn_banco_cuadra(o->'partidas_abiertas', v_x)) then
      v_pagos := v_lista;
      v_lista := null;
    end if;
    if v_lista is null and v_pagos is null and v_tipo = 'banco' and v_senal
       and fn_banco_pago_anonimo(m.tipo_banco, m.cheque, m.descripcion, v_dn, v_txt) then
      select jsonb_agg(jsonb_build_object('texto', 'Pago a ' || (p->>'nombre'), 'proveedor', p->'id', 'llamar', 'fn_banco_pagar_proveedor',
                                          'args', jsonb_build_object('p_movimiento', m.id, 'p_proveedor', p->'id'),
                                          'partidas_abiertas', p->'items') order by p->>'nombre')
        into v_lista
        from jsonb_array_elements(k->'proveedores') p
       where fn_banco_cuadra(p->'items', v_x);
      v_sin_nombre := v_lista is not null;
      if v_lista is null then
        select jsonb_agg(jsonb_build_object('texto', format('Abono a %s (se le deben %s: a lo más viejo primero)', p->>'nombre',
                                                            p->>'debe'),
                                            'proveedor', p->'id', 'llamar', 'fn_banco_pagar_proveedor',
                                            'args', jsonb_build_object('p_movimiento', m.id, 'p_proveedor', p->'id'),
                                            'partidas_abiertas', p->'items') order by (p->>'debe')::numeric desc, p->>'nombre')
          into v_lista
          from jsonb_array_elements(k->'proveedores') p
         where coalesce((p->>'debe')::numeric, 0) >= v_x;
        v_abono := v_lista is not null;
      end if;
    end if;
    if v_lista is not null then
      return jsonb_build_object(
        'motivo', 'pago_proveedor', 'regla', 'R4',
        'texto', case when v_abono
                      then 'Un pago sin nombre (un cheque, un ACH) que no cuadra con ninguna partida: si es un abono a lo que se le '
                           'debe a un proveedor, se aplica a lo más viejo primero (fn_banco_pagar_proveedor); su gasto ya entró '
                           'con sus tickets, y al costo entraría dos veces. Si es otra cosa (la renta, una compra de contado '
                           'sin ticket), di de qué es con su motivo.'
                      when v_sin_nombre
                      then 'Un pago sin nombre (un cheque, un ACH) por lo mismo que se le debe a un proveedor: si es su pago, se '
                           'aplica a sus partidas abiertas de ' || v_cxp || ', las más viejas primero (también lo que traía '
                           'QuickBooks). Su gasto ya entró con sus tickets: nunca va otra vez al costo.'
                      when jsonb_array_length(v_lista) = 1
                      then 'Pago a un proveedor: se aplica a sus partidas abiertas de ' || v_cxp || ' (las más viejas primero, '
                           'también lo que traía QuickBooks, o las que elijas). Su gasto ya entró con sus tickets: nunca va otra '
                           'vez al costo.'
                      else 'Pago a un proveedor: la descripción nombra a más de uno; elige cuál.' end,
        'opciones', v_lista);
    end if;
  end if;

  -- 11. Un depósito: nunca a ingreso. Lo que ya está registrado: un cobro por
  -- ese monto (fuera de la ventana del cruce), o VARIOS cobros que suman el
  -- depósito (los cheques que Edgar anotó uno por factura y depositó
  -- juntos: antes el depósito salía «sin cobro», los mensajes llevaban a un
  -- anticipo y el mismo dinero entraba dos veces); el REEMBOLSO de un
  -- proveedor que nombra (contra lo que tiene a favor: fn_banco_pagar_proveedor);
  -- si no, las facturas abiertas que lo explican: una, con su retención,
  -- SOLO su retención (el cliente la libera después), dos que suman, o una
  -- de la que es una PARTE (un pago parcial: primero las de la obra o el
  -- cliente que nombra la descripción). Antes la retención liberada y el pago
  -- parcial salían «sin una factura abierta que lo explique», sin botones y
  -- con el texto llevando al anticipo: la retención se quedaba en 1120 para
  -- siempre y el cliente con un anticipo que no era.
  if v_tipo = 'banco' and m.monto > 0 then
    -- (las facturas abiertas, si el contexto llegó sin ellas)
    if not (k ? 'facturas') then
      k := k || jsonb_build_object('facturas', fn_banco_contexto_facturas());
    end if;
    -- (¿lo deposita un procesador de tarjeta? QuickBooks Payments, Stripe…)
    v_proc := coalesce(v_txt ~ '(^| )(INTUIT|QBPAYMENTS|QUICKBOOKS|STRIPE|SQUARE|SQ|PAYPAL|CLOVER|BANKCARD|MERCHANT|WORLDPAY)( |$)'
                       or v_txt ~ 'QB PAYMENTS', false);
    -- (Ronda 4) LA DEVOLUCIÓN DE UNA COMPRA CON LA DÉBITO: el abono de Home
    -- Depot en 1010 (la débito ····9420 es de 1010) que nombra el comercio de
    -- un ticket pagado DESDE esta cuenta en los últimos 120 días: contra la
    -- cuenta y la obra de su ticket, como en la tarjeta (12, abajo), y antes
    -- que las facturas. Antes solo la tarjeta miraba sus tickets: la
    -- devolución salía «pago parcial» de la factura de un cliente, cobrada
    -- con dinero de Home Depot.
    select jsonb_agg(x.o order by x.fecha desc) into v_devol
      from (select distinct on (l2.cuenta, l2.proyecto_id, l2.cost_code) r.fecha,
                   jsonb_build_object('texto', format('Devolución de %s: contra %s%s (como su ticket del %s)', r.proveedor, l2.cuenta,
                                                      coalesce(' de ' || l2.proyecto_id, ''), r.fecha),
                                      'llamar', 'fn_banco_clasificar',
                                      'args', jsonb_build_object('p_movimiento', m.id,
                                                                 'p_lineas', jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                                                                   'cuenta', l2.cuenta, 'proyecto_id', l2.proyecto_id,
                                                                   'cost_code', l2.cost_code,
                                                                   'memo', left('Devolución · ' || coalesce(m.descripcion, ''), 200)))))) as o
              from recibos r
              join asiento_lineas l2 on l2.asiento_id = r.contabilizado_en and l2.cuenta <> m.cuenta and l2.monto > 0
              join cuentas c2 on c2.codigo = l2.cuenta and c2.tipo in ('costo', 'gasto')
             where r.contabilizado_en is not null and r.fecha between m.fecha - 120 and m.fecha
               and exists (select 1 from asiento_lineas l1 where l1.asiento_id = r.contabilizado_en and l1.cuenta = m.cuenta)
               and exists (select 1 from regexp_split_to_table(fn_banco_norm(r.proveedor), ' ') as w(w)
                            where length(w.w) >= 4 and w.w not in ('THE', 'INC', 'LLC', 'CORP', 'STORE', 'SUPPLY', 'COMPANY')
                              and v_dn ~ ('(^| )' || w.w || '( |$)'))
             order by l2.cuenta, l2.proyecto_id, l2.cost_code, r.fecha desc
             limit 3) x;
    -- (el reembolso de un proveedor que la descripción o la nota nombran)
    select jsonb_agg(jsonb_build_object('texto', format('Reembolso de %s: contra lo que tiene a tu favor (%s)', p->>'nombre', p->>'a_favor'),
                                        'proveedor', p->'id', 'llamar', 'fn_banco_pagar_proveedor',
                                        'args', jsonb_build_object('p_movimiento', m.id, 'p_proveedor', p->'id'))
                     order by p->>'nombre') filter (where coalesce((p->>'a_favor')::numeric, 0) >= m.monto),
           string_agg(p->>'nombre', ', ' order by p->>'nombre') filter (where coalesce((p->>'a_favor')::numeric, 0) < m.monto)
      into v_reemb, v_nombra
      from jsonb_array_elements(k->'proveedores') p
     where jsonb_typeof(p->'pats') = 'array'
       and exists (select 1 from jsonb_array_elements_text(p->'pats') t(pat) where position(t.pat in ' ' || v_txt || ' ') > 0);
    select jsonb_agg(jsonb_build_object('texto', format('Es el cobro del %s por %s%s', c.fecha, c.monto,
                                                        coalesce(' (ref ' || c.referencia || ')', '')),
                                        'llamar', 'fn_banco_casar_con',
                                        'args', jsonb_build_object('p_movimiento', m.id, 'p_con', jsonb_build_object('cobro', c.id)))
                     order by abs(c.fecha - m.fecha))
      into v_cobros
      from cobros c
     where c.estado = 'vigente' and c.movimiento_id is null and c.cuenta = m.cuenta and c.monto = m.monto
       and abs(c.fecha - m.fecha) <= 30 and c.contabilizado_en is not null
       and exists (select 1 from asiento_lineas l
                    where l.asiento_id = c.contabilizado_en and l.cuenta = m.cuenta
                      and not exists (select 1 from banco_casado_lineas cl
                                       where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente));
    with c as (
      select l.asiento_id, l.orden, l.monto, l.fdoc, co.referencia, co.fecha, row_number() over (order by l.fdoc, l.asiento_id) as i
        from fn_banco_lineas_libres(array[m.cuenta], m.fecha - 10) l
        join cobros co on l.origen_tabla = 'cobros' and co.id = (case when l.origen_id ~ '^[0-9a-f-]{36}$' then l.origen_id::uuid end)
       where l.monto > 0 and l.monto < m.monto and co.estado = 'vigente' and co.movimiento_id is null
         and l.fdoc between m.fecha - 7 and m.fecha + 3),
    g as (
      select array[a.i, b.i] as ii, jsonb_build_array(jsonb_build_object('asiento_id', a.asiento_id, 'orden', a.orden),
                                                      jsonb_build_object('asiento_id', b.asiento_id, 'orden', b.orden)) as lineas,
             format('del %s por %s%s y del %s por %s%s', a.fecha, a.monto, coalesce(' (ref ' || a.referencia || ')', ''),
                    b.fecha, b.monto, coalesce(' (ref ' || b.referencia || ')', '')) as txt
        from c a join c b on b.i > a.i and b.monto = m.monto - a.monto
      union all
      select array[a.i, b.i, d.i], jsonb_build_array(jsonb_build_object('asiento_id', a.asiento_id, 'orden', a.orden),
                                                     jsonb_build_object('asiento_id', b.asiento_id, 'orden', b.orden),
                                                     jsonb_build_object('asiento_id', d.asiento_id, 'orden', d.orden)),
             format('del %s por %s, del %s por %s y del %s por %s', a.fecha, a.monto, b.fecha, b.monto, d.fecha, d.monto)
        from c a join c b on b.i > a.i join c d on d.i > b.i and d.monto = m.monto - a.monto - b.monto)
    select jsonb_agg(jsonb_build_object('texto', 'Son los cobros ' || g.txt || ', depositados juntos', 'llamar', 'fn_banco_casar_con',
                                        'args', jsonb_build_object('p_movimiento', m.id, 'p_con', jsonb_build_object('lineas', g.lineas)))
                     order by cardinality(g.ii), g.ii)
      into v_grupos
      from (select * from g order by cardinality(g.ii), g.ii limit 6) g;
    with f as (
      select (x->>'id')::bigint as id, x->>'num' as num, x->>'proyecto_id' as proyecto_id, (x->>'fecha')::date as fecha,
             (x->>'s1')::numeric as s1, (x->>'s2')::numeric as s2,
             -- ¿la descripción nombra su obra o su cliente? (una palabra de 4
             -- letras o más de su nombre)
             exists (select 1 from jsonb_array_elements_text(coalesce(x->'nom', '[]'::jsonb)) as w(w)
                      where position(' ' || w.w || ' ' in ' ' || v_txt || ' ') > 0) as nombra,
             coalesce((x->>'marcada')::boolean, false) as marcada
        from jsonb_array_elements(k->'facturas') x
       where coalesce((x->>'fecha')::date, m.fecha) <= m.fecha),
    op as (
      select 1 as n, f.fecha as orden, format('Factura #%s (%s)', f.num, f.proyecto_id) as texto,
             jsonb_build_array(jsonb_build_object('factura_id', f.id, 'monto', f.s1::text)) as apps
        from f where f.s1 = m.monto
      union all
      select 1, f.fecha, format('Factura #%s (%s) con su retención', f.num, f.proyecto_id),
             jsonb_build_array(jsonb_build_object('factura_id', f.id, 'monto', f.s1::text),
                               jsonb_build_object('factura_id', f.id, 'monto', f.s2::text, 'es_retencion', true))
        from f where f.s2 > 0 and f.s1 > 0 and f.s1 + f.s2 = m.monto
      union all
      -- (su retención sola: el cliente la libera al terminar la obra)
      select 1, f.fecha, format('Factura #%s (%s): su retención', f.num, f.proyecto_id),
             jsonb_build_array(jsonb_build_object('factura_id', f.id, 'monto', f.s2::text, 'es_retencion', true))
        from f where f.s2 > 0 and f.s2 = m.monto
      union all
      -- (una factura cobrada con TARJETA: el procesador —QuickBooks
      -- Payments, Stripe, Square— deposita el neto, y lo que falta es su
      -- comisión, hasta un 3.5 % más 0.30: el cobro por el bruto y la
      -- comisión a su cuenta, 6130. Primero si el banco nombra al
      -- procesador. Antes solo salía «parte de la factura», que la dejaba
      -- abierta por la comisión para siempre)
      select case when v_proc then 1 else 3 end, f.fecha,
             format('Factura #%s (%s) cobrada con tarjeta: el procesador se quedó %s de comisión (→ %s)', f.num, f.proyecto_id,
                    f.s1 - m.monto, coalesce(k->'dest'->>'cargo_banco', '6130')),
             jsonb_build_array(jsonb_build_object('factura_id', f.id, 'monto', f.s1::text),
                               jsonb_build_object('comision', (f.s1 - m.monto)::text))
        from f where f.s1 > m.monto and f.s1 - m.monto <= round(0.035 * f.s1 + 0.30, 2)
      union all
      -- (una parte de una: un pago parcial; primero las que nombra)
      select case when f.nombra then 3 else 4 end, f.fecha,
             format('Parte de la factura #%s (%s): quedarían %s por cobrar', f.num, f.proyecto_id, f.s1 - m.monto),
             jsonb_build_array(jsonb_build_object('factura_id', f.id, 'monto', m.monto::text))
        from f where f.s1 > m.monto
      union all
      -- (dos que suman: por igualdad de montos, no probando todos los pares)
      select 2, greatest(a.fecha, b.fecha), format('Facturas #%s y #%s', least(a.num, b.num), greatest(a.num, b.num)),
             jsonb_build_array(jsonb_build_object('factura_id', a.id, 'monto', a.s1::text),
                               jsonb_build_object('factura_id', b.id, 'monto', b.s1::text))
        from f a join f b on b.s1 = m.monto - a.s1 and b.id > a.id
       where a.s1 > 0 and b.s1 > 0
      union all
      -- (Ronda 4) EL LOTE DEL PROCESADOR: QuickBooks Payments, Stripe o
      -- Square depositan JUNTOS los cobros con tarjeta del día, netos de sus
      -- comisiones: dos o tres facturas por su bruto, y lo que falta, su
      -- comisión (hasta un 3.5 % más 0.30 de cada una). Solo si el banco
      -- nombra al procesador, y primero las que la app ya da por cobradas.
      -- Antes solo se probaba UNA factura y el lote salía «sin factura que
      -- lo explique», sin botones y con el texto llevando al anticipo.
      select case when a.marcada and b.marcada then 1 else 3 end, greatest(a.fecha, b.fecha),
             format('Facturas #%s y #%s cobradas con tarjeta, depositadas juntas: el procesador se quedó %s de comisión (→ %s)',
                    a.num, b.num, a.s1 + b.s1 - m.monto, coalesce(k->'dest'->>'cargo_banco', '6130')),
             jsonb_build_array(jsonb_build_object('factura_id', a.id, 'monto', a.s1::text),
                               jsonb_build_object('factura_id', b.id, 'monto', b.s1::text),
                               jsonb_build_object('comision', (a.s1 + b.s1 - m.monto)::text))
        from f a join f b on b.id > a.id
       where v_proc and a.s1 > 0 and b.s1 > 0 and a.s1 + b.s1 > m.monto
         and a.s1 + b.s1 - m.monto <= round(0.035 * a.s1 + 0.30, 2) + round(0.035 * b.s1 + 0.30, 2)
      union all
      select case when a.marcada and b.marcada and c.marcada then 1 else 4 end, greatest(a.fecha, b.fecha, c.fecha),
             format('Facturas #%s, #%s y #%s cobradas con tarjeta, depositadas juntas: el procesador se quedó %s de comisión (→ %s)',
                    a.num, b.num, c.num, a.s1 + b.s1 + c.s1 - m.monto, coalesce(k->'dest'->>'cargo_banco', '6130')),
             jsonb_build_array(jsonb_build_object('factura_id', a.id, 'monto', a.s1::text),
                               jsonb_build_object('factura_id', b.id, 'monto', b.s1::text),
                               jsonb_build_object('factura_id', c.id, 'monto', c.s1::text),
                               jsonb_build_object('comision', (a.s1 + b.s1 + c.s1 - m.monto)::text))
        from f a join f b on b.id > a.id join f c on c.id > b.id
       where v_proc and a.s1 > 0 and b.s1 > 0 and c.s1 > 0 and a.s1 + b.s1 + c.s1 > m.monto
         and a.s1 + b.s1 + c.s1 - m.monto
             <= round(0.035 * a.s1 + 0.30, 2) + round(0.035 * b.s1 + 0.30, 2) + round(0.035 * c.s1 + 0.30, 2))
    select jsonb_agg(jsonb_build_object('texto', o.texto, 'llamar', 'fn_banco_cobrar',
                                        'args', jsonb_build_object('p_movimiento', m.id, 'p_aplicaciones', o.apps))
                     order by o.n, o.orden desc),
           bool_or(o.n <= 2)
      into v_fact, v_exacta
      from (select * from op order by n, orden desc limit 6) o;
    v_hay_cobros := exists (select 1 from cobros c
                             where c.estado = 'vigente' and c.movimiento_id is null and c.cuenta = m.cuenta
                               and c.fecha between m.fecha - 30 and m.fecha + 3);
    -- (Ronda 4) UN COBRO YA ANOTADO, libre, de OTRO monto, en la ventana del
    -- depósito (de 30 días antes a 3 después): el cobro con tarjeta anotado
    -- por el bruto y depositado neto (la diferencia cabe en la comisión: 3.5 %
    -- más 0.30), o el cheque anotado por otro monto (se corrige: se anula y
    -- se registra el bueno con este depósito, con su motivo). Van antes que
    -- las facturas, y el texto ya no dice «sin cobro registrado». Antes solo
    -- contaba el cobro del mismo monto: la única opción era la factura de
    -- OTRO cliente, y el cobro anotado quedaba en tránsito para siempre.
    select jsonb_agg(x.o order by x.p, x.d, x.fecha)
      into v_otro_cobro
      from (select 0 as p, abs(c.fecha - m.fecha) as d, c.fecha,
                   jsonb_build_object('texto', format('Es el cobro del %s por %s%s, depositado neto de %s de comisión (→ %s)', c.fecha,
                                                      c.monto, coalesce(' (ref ' || c.referencia || ')', ''), c.monto - m.monto,
                                                      coalesce(k->'dest'->>'cargo_banco', '6130')),
                                      'llamar', 'fn_banco_casar_con',
                                      'args', jsonb_build_object('p_movimiento', m.id,
                                                                 'p_con', jsonb_build_object('cobro', c.id,
                                                                                             'comision', (c.monto - m.monto)::text))) as o
              from cobros c
             where c.estado = 'vigente' and c.movimiento_id is null and c.cuenta = m.cuenta and c.contabilizado_en is not null
               and c.fecha between m.fecha - 30 and m.fecha + 3 and c.monto > m.monto
               and c.monto - m.monto <= round(0.035 * c.monto + 0.30, 2)
               and not exists (select 1 from cobros_devoluciones dv where dv.cobro_id = c.id)
               and exists (select 1 from asiento_lineas l
                            where l.asiento_id = c.contabilizado_en and l.cuenta = m.cuenta
                              and not exists (select 1 from banco_casado_lineas cl
                                               where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente))
               -- (con un cobro o varios que lo suman exacto, no: esos van primero)
               and v_cobros is null and v_grupos is null
            union all
            select 1, abs(c.fecha - m.fecha), c.fecha,
                   jsonb_build_object('texto', format('Es el cobro del %s por %s%s, anotado por otro monto: el banco dice %s. Corrígelo '
                                                      '(se anula y se registra el bueno con este depósito, a lo mismo)', c.fecha,
                                                      c.monto, coalesce(' (ref ' || c.referencia || ')', ''), m.monto),
                                      'llamar', 'fn_banco_casar_con', 'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                                      'args', jsonb_build_object('p_movimiento', m.id,
                                                                 'p_con', jsonb_build_object('cobro', c.id, 'corrige', true)))
              from cobros c
             where c.estado = 'vigente' and c.movimiento_id is null and c.cuenta = m.cuenta and c.contabilizado_en is not null
               and c.fecha between m.fecha - 30 and m.fecha + 3 and c.monto <> m.monto
               and abs(c.monto - m.monto) <= 0.5 * greatest(c.monto, m.monto)
               and not exists (select 1 from cobros_devoluciones dv where dv.cobro_id = c.id)
               and exists (select 1 from asiento_lineas l
                            where l.asiento_id = c.contabilizado_en and l.cuenta = m.cuenta
                              and not exists (select 1 from banco_casado_lineas cl
                                               where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente))
               and v_cobros is null and v_grupos is null
               and (select count(*) from aplicaciones_cobro x where x.cobro_id = c.id) = 1
               and not exists (select 1 from aplicaciones_cobro x where x.cobro_id = c.id and (x.desde_anticipo or x.descuento <> 0))
             order by 1, 2, 3
             limit 6) x;
    -- (y con uno así libre, registrar OTRO cobro pide su porqué en las
    -- notas: fn_banco_cobrar lo exige)
    if v_otro_cobro is not null then
      select jsonb_agg(case when o->>'llamar' = 'fn_banco_cobrar'
                            then o || jsonb_build_object('pide_motivo', true, 'pide', jsonb_build_array('p_notas'))
                            else o end order by n)
        into v_fact
        from jsonb_array_elements(v_fact) with ordinality as x(o, n);
    end if;
    v_lista := case when v_cobros is not null or v_grupos is not null or v_otro_cobro is not null or v_devol is not null
                         or v_reemb is not null or v_fact is not null or v_tr is not null or v_pers is not null
                    then coalesce(v_cobros, '[]'::jsonb) || coalesce(v_grupos, '[]'::jsonb)
                         -- (ronda 4: el dinero que llega de la cuenta personal de
                         -- Edgar, antes que las facturas de los clientes)
                         || coalesce(v_pers, '[]'::jsonb) || coalesce(v_otro_cobro, '[]'::jsonb)
                         || coalesce(v_devol, '[]'::jsonb) || coalesce(v_reemb, '[]'::jsonb) || coalesce(v_fact, '[]'::jsonb)
                         || coalesce(v_tr, '[]'::jsonb) end;
    return jsonb_strip_nulls(jsonb_build_object(
      'motivo', case when v_cobros is not null then 'deposito_cobro' when v_grupos is not null then 'deposito_cobros'
                     when v_pers is not null then 'transferencia_personal'
                     when v_otro_cobro is not null then 'deposito_otro_cobro'
                     when v_devol is not null then 'devolucion_compra'
                     when v_reemb is not null then 'reembolso_proveedor'
                     when v_fact is not null and v_exacta then 'deposito_sin_cobro'
                     when v_fact is not null then 'deposito_parcial' when v_tr is not null then 'transferencia_un_lado'
                     else 'deposito_sin_factura' end,
      'regla', case when v_tr is not null and v_cobros is null and v_grupos is null and v_fact is null and v_reemb is null then 'R3'
                    when v_reemb is not null and v_cobros is null and v_grupos is null then 'R4' else 'R2' end,
      'texto', case when v_cobros is not null
                    then 'Hay un cobro registrado por ese monto, pero con otra fecha: si es este depósito, cásalo.'
                    when v_grupos is not null
                    then 'Estos cobros ya registrados suman el depósito (varios cheques depositados juntos): cásalo con ellos. '
                         'Registrar otro cobro o un anticipo metería el mismo dinero dos veces.'
                    when v_pers is not null
                    then format('Dinero que llega de una cuenta que no es de la empresa (····%s: la cuenta personal de Edgar): un '
                                'préstamo del accionista (2900) o una aportación (3100), nunca un ingreso ni el cobro de un cliente. '
                                'Si de verdad es el cobro de una factura, está abajo.', v_otra)
                    when v_otro_cobro is not null
                    then 'Hay un cobro ya anotado, sin su depósito, de otro monto: ¿es este depósito? (un cobro con tarjeta '
                         'depositado neto de su comisión, o un cheque anotado por otro monto). Si lo es, cásalo con él. Registrar '
                         'otro cobro o un anticipo metería el mismo dinero dos veces (solo con su porqué en las notas).'
                    when v_devol is not null
                    then '¿La devolución de una compra pagada con la débito? Nombra el comercio de un ticket pagado desde esta '
                         'cuenta: va contra la cuenta y la obra de su gasto, como su ticket (el costo baja una vez). Si es el cobro '
                         'de un cliente, sus facturas están abajo.'
                    when v_reemb is not null
                    then 'Parece el reembolso de un proveedor (lo nombra): va contra lo que tenía a tu favor en ' || v_cxp
                         || ' (una devolución o un pago de más), no al costo otra vez. Si es otra cosa, abajo.'
                    when v_fact is not null and v_exacta
                    then 'Un depósito sin cobro registrado: estas facturas abiertas lo explican. Elige y se registra su cobro con '
                         'este movimiento. Nunca a ingreso.'
                    when v_fact is not null
                    then 'Un depósito sin cobro registrado que no cuadra exacto con ninguna factura abierta: ¿es una parte de '
                         'una (un pago parcial), su retención, una factura cobrada con tarjeta y depositada neta de su comisión'
                         || case when v_proc then ' (o varias: el lote del procesador)' else '' end
                         || ', o un anticipo de su obra (fn_banco_cobrar con la obra)? Elige y se registra su cobro con este '
                         'movimiento. Nunca a ingreso.'
                         || case when v_nombra is not null
                                 then format(' (Nombra a %s, que no tiene nada a tu favor: si es la devolución de una compra sin '
                                             'su ticket, clasifícala contra el costo de su obra con su motivo.)', v_nombra)
                                 else '' end
                    when v_tr is not null
                    then 'Parece dinero que llega de otra cuenta propia (el pase de la reserva, una transferencia): confírmalo. Si '
                         'es el cobro de un cliente, regístralo con su factura (fn_banco_cobrar).'
                    -- (ronda 4: el depósito de un procesador de tarjetas, sin
                    -- facturas que lo expliquen: lo dice antes que el anticipo)
                    when v_proc
                    then 'Un depósito de un procesador de tarjetas (QuickBooks Payments, Stripe, Square…): junta los cobros con '
                         'tarjeta de una o VARIAS facturas, netos de su comisión. Regístralo con sus facturas por el bruto y la '
                         'comisión aparte (fn_banco_cobrar con [{"factura_id": …, "monto": …}, …, {"comision": "…"}]); la '
                         'comisión va a ' || coalesce(k->'dest'->>'cargo_banco', '6130') || '. Un anticipo solo si de verdad no '
                         'hay factura. Nunca a ingreso.'
                    when v_hay_cobros
                    then 'Ningún cobro registrado (ni dos o tres que sumen) ni una factura abierta explica este depósito: ¿de qué es? '
                         'Un cobro (con su factura, o de anticipo de su obra: fn_banco_cobrar), un aporte de Edgar, un préstamo… '
                         'Nunca a ingreso.'
                    else 'Un depósito sin cobro registrado y sin una factura abierta que lo explique: ¿de qué es? Un cobro (con su '
                         'factura, o de anticipo de su obra: fn_banco_cobrar), un aporte de Edgar, un préstamo… Nunca a ingreso.'
                         || case when v_nombra is not null
                                 then format(' (Nombra a %s, que no tiene nada a tu favor: si es la devolución de una compra sin '
                                             'su ticket, clasifícala contra el costo de su obra con su motivo.)', v_nombra)
                                 else '' end end,
      'opciones', v_lista));
  end if;

  -- 12. Un abono en la tarjeta que no dice que es un pago: la devolución de
  -- una compra. Se propone clasificarla contra la cuenta y la obra del ticket
  -- de ese comercio con esa misma tarjeta (los de los últimos 120 días), y
  -- el pago a la tarjeta queda como la última opción, con su motivo (un
  -- abono en la tarjeta sin su otro lado y sin la palabra pago no se toma
  -- por una transferencia a ciegas).
  if v_tipo = 'tarjeta' and m.monto > 0 then
    select jsonb_agg(x.o order by x.fecha desc) into v_devol
      from (select distinct on (l2.cuenta, l2.proyecto_id, l2.cost_code) r.fecha,
                   jsonb_build_object('texto', format('Devolución de %s: contra %s%s (como su ticket del %s)', r.proveedor, l2.cuenta,
                                                      coalesce(' de ' || l2.proyecto_id, ''), r.fecha),
                                      'llamar', 'fn_banco_clasificar',
                                      'args', jsonb_build_object('p_movimiento', m.id,
                                                                 'p_lineas', jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                                                                   'cuenta', l2.cuenta, 'proyecto_id', l2.proyecto_id,
                                                                   'cost_code', l2.cost_code,
                                                                   'memo', left('Devolución · ' || coalesce(m.descripcion, ''), 200)))))) as o
              from recibos r
              join asiento_lineas l2 on l2.asiento_id = r.contabilizado_en and l2.cuenta <> m.cuenta and l2.monto > 0
              join cuentas c2 on c2.codigo = l2.cuenta and c2.tipo in ('costo', 'gasto')
             where r.contabilizado_en is not null and r.fecha between m.fecha - 120 and m.fecha
               and exists (select 1 from asiento_lineas l1 where l1.asiento_id = r.contabilizado_en and l1.cuenta = m.cuenta)
               and exists (select 1 from regexp_split_to_table(fn_banco_norm(r.proveedor), ' ') as w(w)
                            where length(w.w) >= 4 and w.w not in ('THE', 'INC', 'LLC', 'CORP', 'STORE', 'SUPPLY', 'COMPANY')
                              and v_dn ~ ('(^| )' || w.w || '( |$)'))
             order by l2.cuenta, l2.proyecto_id, l2.cost_code, r.fecha desc
             limit 3) x;
    select jsonb_agg(jsonb_build_object('texto', format('Fue un pago a la tarjeta desde %s (con su motivo)', x->>'codigo'),
                                        'llamar', 'fn_banco_transferencia', 'pide_motivo', true,
                                        'args', jsonb_build_object('p_movimiento', m.id, 'p_cuenta', x->>'codigo')) order by x->>'codigo')
      into v_dest
      from jsonb_array_elements(k->'propias') x
     where x->>'tipo' = 'banco';
    return jsonb_strip_nulls(jsonb_build_object(
      'motivo', 'abono_tarjeta', 'regla', 'R10',
      'texto', '¿La devolución de una compra? Un abono en la tarjeta que no dice que es un pago. Si su recibo de devolución está '
               'en la app, casa solo; si no, clasifícala contra la cuenta y la obra de su gasto (el costo baja una vez). Si de '
               'verdad fue un pago a la tarjeta, confírmalo como transferencia con su motivo.',
      'opciones', case when v_devol is not null or v_dest is not null
                       then coalesce(v_devol, '[]'::jsonb) || coalesce(v_dest, '[]'::jsonb) end));
  end if;

  -- 12b. Un cargo con un TICKET DE OTRO TOTAL: la línea libre de un recibo
  -- en su cuenta, en la ventana de la compra, que se le parece (el banco
  -- nombra su comercio, o el monto no se separa más de un 12 %: el ticket
  -- leído sin el tax). No casa (el dinero no es el mismo): se corrige el
  -- total del recibo (✎ en la app), su asiento se rehace y el cargo casa
  -- solo con él. Antes salía «sin ticket», se clasificaba y el gasto entraba
  -- dos veces (el cargo de 107.00 y el ticket de 100.00: 207.00 a la obra).
  if m.monto < 0 and jsonb_typeof(p_otros) = 'array' and jsonb_array_length(p_otros) > 0 then
    return jsonb_strip_nulls(jsonb_build_object(
      'motivo', 'otro_total', 'regla', 'R1 otro total',
      'texto', format('Hay un ticket sin su cargo que se le parece, con OTRO total: %s (el banco dice %s). ¿Se leyó sin el tax, o '
                      'mal? Corrige su total en la app (✎): su asiento se rehace y este cargo casa solo con él. Clasificarlo metería '
                      'el gasto dos veces: solo con su motivo, si de verdad es otra compra.',
                      (select string_agg(format('el recibo %s del %s por %s', t->>'recibo', t->>'fecha', -(t->>'monto')::numeric),
                                         '; ' order by o)
                         from jsonb_array_elements(p_otros) with ordinality as x(t, o)), -m.monto)
               || case when v_obra is not null then format(' Obra propuesta: %s (%s).', v_obra->>'nombre', v_obra->>'por')
                       else coalesce(v_varias, '') end
               || case when v_pagos is not null then ' Si fue el pago de la cuenta de un proveedor, está abajo.' else '' end,
      'tickets', p_otros, 'obra', v_obra, 'opciones', v_pagos));
  end if;

  -- 13. Un cargo sin ticket: de qué es (con la obra de la visita de ese día,
  -- si la hay: sin ella, el texto no la nombra). Un Zelle a una persona
  -- dice sus dos caminos (el retiro de Edgar, un subcontratista): antes
  -- salía como «Abono a CED» y el retiro del dueño bajaba la deuda de un
  -- proveedor.
  if m.monto < 0 then
    return jsonb_strip_nulls(jsonb_build_object(
      'motivo', 'sin_ticket', 'regla', 'R10',
      'texto', 'Sin ticket ni asiento que lo explique. Si tienes la foto del recibo, súbela: entra por su puente y casa sola. Si no, '
               'di de qué es (fn_banco_clasificar).'
               || case when v_dn ~ '(^| )ZELLE( |$)'
                       then ' Un Zelle a una persona: si es un retiro de Edgar, va a 3200 (lo que saca el accionista); si es el '
                            'pago a un subcontratista, a 5200 con su obra. La nómina (5000/5010) entra solo por su journal.'
                       else '' end
               || case when v_obra is not null then format(' Obra propuesta: %s (%s).', v_obra->>'nombre', v_obra->>'por')
                       else coalesce(v_varias, '') end
               || case when v_pagos is not null then ' Si fue el pago de la cuenta de un proveedor, está abajo.' else '' end,
      'obra', v_obra, 'opciones', v_pagos));
  end if;
  return jsonb_build_object('motivo', 'clasificar', 'regla', 'R10',
                            'texto', 'No se reconoce: di de qué es (fn_banco_clasificar) o, si no es de la empresa, ignóralo con su motivo.');
end $$;
revoke execute on function public.fn_banco_proponer_base(public.movimientos_banco, jsonb, jsonb, jsonb, jsonb)
  from public, anon, authenticated, service_role;

-- (Ronda 4) UNA OPCIÓN QUE PIDE SU MOTIVO: la marca «pide_motivo» y el
-- nombre del argumento donde va (p_notas en fn_banco_cobrar, p_motivo en
-- las demás que lo tienen). La de una función sin motivo, tal cual.
-- (La usan las opciones de siempre que van detrás de una partida de la
-- apertura y las de un movimiento de los primeros días con la apertura
-- sin conciliar: fn_banco_clasificar las rechaza sin motivo, y antes el
-- botón, pulsado con sus argumentos tal cual, fallaba.)
create or replace function public.fn_banco_opcion_motivo(o jsonb)
returns jsonb
language sql
immutable
set search_path = public, pg_temp
as $$
  select case when o->>'llamar' in ('fn_banco_clasificar', 'fn_banco_cobrar', 'fn_banco_transferencia', 'fn_banco_casar_con',
                                    'fn_prestamo_cuota', 'fn_banco_duplicado')
              then o || jsonb_build_object('pide_motivo', true,
                                           'pide', (select coalesce(jsonb_agg(distinct x.v), '[]'::jsonb)
                                                      from (select jsonb_array_elements_text(case when jsonb_typeof(o->'pide') = 'array'
                                                                                                  then o->'pide' else '[]'::jsonb end) as v
                                                            union all
                                                            select case o->>'llamar' when 'fn_banco_cobrar' then 'p_notas'
                                                                                     else 'p_motivo' end) x))
              else o end
$$;
revoke execute on function public.fn_banco_opcion_motivo(jsonb) from public, anon, authenticated, service_role;


-- LA PROPUESTA, con las partidas de la APERTURA delante: si el movimiento
-- puede ser una partida en tránsito de la conciliación de apertura (lo que
-- QuickBooks tenía al 30-sep y el banco trae ahora: fn_banco_apertura_opciones),
-- sus opciones van primero y el motivo es «partida_apertura» (clasificarlo
-- o cobrarlo lo metería dos veces: ya está en el saldo de la apertura); lo
-- demás que se proponía sigue abajo, por si no lo es. Una PARTE posible (un
-- depósito del 30 que el banco trajo en partes) solo se añade al final. Lo
-- que casaría con el libro, un duplicado por decir y el otro lado de una
-- transferencia, primero.
create or replace function public.fn_banco_proponer(m public.movimientos_banco, p_cands jsonb, p_obra jsonb, p_ctx jsonb default null,
                                                    p_otros jsonb default null)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_base jsonb := fn_banco_proponer_base(m, p_cands, p_obra, p_ctx, p_otros);
  v_ap   jsonb;
  v_av   text;
begin
  -- (Ronda 4: la apertura de esta cuenta sin conciliar todavía y un cheque
  -- o un depósito de los primeros días: puede ser de septiembre. Se dice,
  -- y lo que lo clasifica, lo cobra o lo paga pide su motivo.)
  if v_base->>'motivo' is distinct from 'posible_duplicado' then
    v_av := fn_banco_apertura_aviso(m);
    if v_av is not null then
      v_base := v_base || jsonb_build_object(
        'texto', coalesce(v_base->>'texto' || ' ', '') || 'Ojo: ' || v_av,
        'aviso_apertura', v_av,
        'opciones', (select jsonb_agg(case when o->>'llamar' in ('fn_banco_clasificar', 'fn_banco_cobrar', 'fn_banco_transferencia')
                                           then fn_banco_opcion_motivo(o) else o end order by n)
                       from jsonb_array_elements(coalesce(v_base->'opciones', '[]'::jsonb)) with ordinality as x(o, n)));
      v_base := jsonb_strip_nulls(v_base);
    end if;
  end if;
  if v_base->>'motivo' in ('posible_duplicado', 'transferencia_otro_lado', 'varios_candidatos')
     or (p_ctx is not null and not coalesce(p_ctx->'aper_cuentas' ? m.cuenta, false)) then
    return v_base;
  end if;
  v_ap := fn_banco_apertura_opciones(m);
  if v_ap is null then
    return v_base;
  end if;
  if coalesce((v_ap->>'fuertes')::int, 0) = 0 then
    return v_base || jsonb_build_object(
      'texto', coalesce(v_base->>'texto', '') || ' O una parte de una partida en tránsito de la conciliación de apertura (el banco '
               'la trajo en partes): si lo es, cásalo con ella con su motivo.',
      'opciones', coalesce(v_base->'opciones', '[]'::jsonb) || (v_ap->'opciones'));
  end if;
  return jsonb_strip_nulls(v_base || jsonb_build_object(
    'motivo', 'partida_apertura', 'regla', 'R0 apertura', 'motivo_si_no', v_base->>'motivo',
    'texto', 'Puede ser una partida en tránsito de la conciliación de apertura (lo que QuickBooks tenía al 30-sep y el banco trae '
             'ahora): ya está en el saldo de la apertura. Si lo es, cásalo con ella; clasificarlo o registrar un cobro lo metería '
             'dos veces.' || coalesce(' Si no lo es: ' || (v_base->>'texto'), ''),
    -- (Ronda 4: las opciones de siempre van detrás, y piden su motivo:
    -- fn_banco_clasificar las rechaza sin él —«puede ser una partida en
    -- tránsito»—. Antes iban sin marcar y, pulsadas tal cual, fallaban.)
    'opciones', (v_ap->'opciones')
                || coalesce((select jsonb_agg(fn_banco_opcion_motivo(o) order by n)
                               from jsonb_array_elements(coalesce(v_base->'opciones', '[]'::jsonb)) with ordinality as x(o, n)),
                            '[]'::jsonb)));
end $$;
revoke execute on function public.fn_banco_proponer(public.movimientos_banco, jsonb, jsonb, jsonb, jsonb)
  from public, anon, authenticated, service_role;

-- LLEGÓ SU TICKET DESPUÉS: un cargo que Edgar clasificó (no había ticket) y
-- cuyo ticket entró después por c3. El gasto está dos veces en el libro
-- (la clasificación y el ticket) y el ticket queda libre, sin su
-- movimiento: antes nada lo decía y la conciliación lo daba por «cargo en
-- circulación». Cada fila: el movimiento casado por clasificación y la
-- línea libre de un recibo en su cuenta, en la ventana del cruce (la
-- fecha de la compra): por el mismo monto, o con OTRO total si el banco
-- nombra el comercio del ticket (el ticket leído sin el tax: linea_monto,
-- lo que dice el ticket; antes solo el mismo monto, y el cargo de 107.00
-- clasificado con su ticket de 100.00 libre dejaba 207.00 en la obra con
-- el control en verde). Salvo lo que Edgar ya dijo que no es
-- (propuesta.descartados). Lo usan el motor (la propuesta
-- «llego_su_ticket»), la conciliación (la partida «posible_duplicado»,
-- que frena confirmar) y el control (en rojo mientras haya).
-- (Ronda 4) Y el ticket REPARTIDO entre obras (la misma foto —la ruta— en
-- dos o más recibos, como R1) cuyas partes suman el cargo: una fila por
-- parte, con «repartido» (los recibos de la foto, en orden: 110,111) y
-- «obras» (cuántas). Antes cada parte salía como un ticket de OTRO total
-- («¿se leyó sin el tax?»), «Es su ticket» se negaba y el único botón,
-- «No es su ticket», dejaba el gasto dos veces. Si un grupo suma el cargo,
-- sus partes ya no salen como «otro total» de ese cargo. Con p_todos,
-- también lo que Edgar dijo que no era (descartado true): la conciliación
-- lo nombra en su explicación.
-- (Devuelve más columnas que la versión anterior: se quita antes.)
drop function if exists public.fn_banco_tickets_llegados(text[], uuid);
drop function if exists public.fn_banco_tickets_llegados(text[], uuid, boolean);
create or replace function public.fn_banco_tickets_llegados(p_cuentas text[] default null, p_mov uuid default null,
                                                            p_todos boolean default false)
returns table (movimiento_id uuid, cuenta text, fecha date, monto numeric, asiento_id uuid, orden int, recibo text, numero text,
               fdoc date, linea_monto numeric, repartido text, obras int, descartado boolean)
language plpgsql
stable
set search_path = public, pg_temp
as $f$
begin
  -- (Con EXECUTE: se planea con los filtros que de verdad trae. Con los de
  -- «si viene nulo, todo» el planificador creía que había cinco cargos
  -- clasificados y juntaba cada línea de la cuenta con cada cargo: con un
  -- año de banco, más de 3 s en 17.6 en cada «Casar».)
  return query execute $q$
    with cl as materialized (
      -- (los cargos clasificados del alcance, una vez)
      select m.id, m.cuenta, m.fecha, m.monto, m.fecha_transaccion, m.cheque, m.desc_norm, m.propuesta
        from movimientos_banco m
       where m.estado = 'casado' and m.casado_clase = 'clasificado' and m.fecha >= (select fn_puente_corte())
  $q$
  || case when p_cuentas is not null then ' and m.cuenta = any ($1)' else '' end
  || case when p_mov is not null then ' and m.id = $2' else '' end
  || $q$
    ),
    lib as materialized (
      -- (con OTRO total: primero las líneas LIBRES de las cuentas de esos
      -- cargos —pocas: casi todo casa con su movimiento—; después, de ellas,
      -- las de un recibo en los días de esos cargos, buscando su asiento
      -- una por una; y al final, los cargos de su cuenta en esos días. Al
      -- revés, el planificador juntaba cada línea de los recibos con cada
      -- cargo clasificado de dos meses antes de saber si estaba libre: con
      -- un año de banco, más de 8 s en cada «Casar» y en cada conciliación
      -- de una tarjeta)
      select l.asiento_id, l.orden, l.cuenta, l.monto
        from asiento_lineas l
       where exists (select 1 from cl)
         and l.cuenta = any ((select array_agg(distinct cl.cuenta) from cl)::text[])
         and not exists (select 1 from banco_casado_lineas bl where bl.asiento_id = l.asiento_id and bl.orden = l.orden and bl.vigente)
    ),
    lr as materialized (
      select l.asiento_id, l.orden, l.cuenta, l.monto, a.origen_id, a.numero, f.fdoc,
             (select r.proveedor from recibos r
               where r.id = (case when a.origen_id ~ '^-?[0-9]{1,18}$' then a.origen_id::bigint end)) as proveedor
        from lib l
        cross join lateral (select a.* from asientos a where a.id = l.asiento_id offset 0) a
        cross join lateral (select coalesce(case when a.procedencia->>'fecha_documento' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                                                  then (a.procedencia->>'fecha_documento')::date end, a.fecha_contable) as fdoc) f
       where a.origen_tabla = 'recibos' and a.fecha_contable >= (select fn_puente_corte())
         and f.fdoc between (select min(cl.fecha) - 60 from cl) and (select max(cl.fecha) + 3 from cl)
         and a.camino not in ('reverso', 'reverso_automatico') and not a.reversible
         and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino in ('reverso', 'reverso_automatico'))
    ),
    -- (Ronda 4: las partes de un ticket REPARTIDO —la misma foto en dos o
    -- más recibos, con su línea libre—, y los cargos que suman, en los días
    -- de la compra, como R1)
    lg as materialized (
      select l.asiento_id, l.orden, l.cuenta, l.monto, l.origen_id, l.numero, l.fdoc, btrim(rc.ruta) as ruta, rc.id as rid,
             rc.proyecto_id
        from lr l
        join recibos rc on rc.id = (case when l.origen_id ~ '^-?[0-9]{1,18}$' then l.origen_id::bigint end)
       where nullif(btrim(rc.ruta), '') is not null
    ),
    grp as (
      select g.cuenta, g.ruta, sum(g.monto) as total, min(g.fdoc) as f1, max(g.fdoc) as f2,
             string_agg(g.rid::text, ',' order by g.rid) as refs, count(distinct coalesce(g.proyecto_id, ''))::int as obras
        from lg g
       group by g.cuenta, g.ruta
      having count(*) >= 2
    ),
    gm as (
      select m.id, m.cuenta, m.fecha, m.monto, g.ruta, g.refs, g.obras,
             exists (select 1 from lg x where x.cuenta = g.cuenta and x.ruta = g.ruta
                        and coalesce(m.propuesta->'descartados', '[]'::jsonb) ? (x.asiento_id::text || ':' || x.orden)) as descart
        from cl m
        join grp g on g.cuenta = m.cuenta and g.total = m.monto
                  and g.f1 >= (case when m.fecha_transaccion is not null then least(m.fecha_transaccion, m.fecha) - 3
                                    else m.fecha - 7 end)
                  and g.f2 <= m.fecha + 3
    )
    select m.id, m.cuenta, m.fecha, m.monto, l.asiento_id, l.orden, a.origen_id, a.numero, f.fdoc, l.monto, null::text, null::int,
           coalesce(m.propuesta->'descartados', '[]'::jsonb) ? (l.asiento_id::text || ':' || l.orden)
      from cl m
      join asiento_lineas l on l.cuenta = m.cuenta and l.monto = m.monto
      join asientos a on a.id = l.asiento_id
      cross join lateral (select coalesce(case when a.procedencia->>'fecha_documento' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                                                then (a.procedencia->>'fecha_documento')::date end, a.fecha_contable) as fdoc) f
     where a.origen_tabla = 'recibos' and a.fecha_contable >= (select fn_puente_corte())
       and a.camino not in ('reverso', 'reverso_automatico') and not a.reversible
       and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino in ('reverso', 'reverso_automatico'))
       and not exists (select 1 from banco_casado_lineas bl where bl.asiento_id = l.asiento_id and bl.orden = l.orden and bl.vigente)
       and fn_banco_ventana(m.fecha, m.fecha_transaccion, m.cheque, f.fdoc, l.monto, false, null, null, null) = 'fuerte'
       and ($3 or not (coalesce(m.propuesta->'descartados', '[]'::jsonb) ? (l.asiento_id::text || ':' || l.orden)))
    union all
    select m.id, m.cuenta, m.fecha, m.monto, l.asiento_id, l.orden, l.origen_id, l.numero, l.fdoc, l.monto, null::text, null::int,
           coalesce(m.propuesta->'descartados', '[]'::jsonb) ? (l.asiento_id::text || ':' || l.orden)
      from lr l
      join cl m on m.cuenta = l.cuenta and m.fecha between l.fdoc - 3 and l.fdoc + 60
     where m.monto <> l.monto and sign(m.monto) = sign(l.monto)
       and fn_banco_comercio(l.proveedor, m.desc_norm)
       and fn_banco_ventana(m.fecha, m.fecha_transaccion, m.cheque, l.fdoc, m.monto, false, null, null, null) = 'fuerte'
       and ($3 or not (coalesce(m.propuesta->'descartados', '[]'::jsonb) ? (l.asiento_id::text || ':' || l.orden)))
       -- (si un ticket repartido suma ese cargo, sus partes no son «otro total»)
       and not exists (select 1 from gm g where g.id = m.id and ($3 or not g.descart))
    union all
    select m.id, m.cuenta, m.fecha, m.monto, x.asiento_id, x.orden, x.origen_id, x.numero, x.fdoc, x.monto, m.refs, m.obras, m.descart
      from gm m
      join lg x on x.cuenta = m.cuenta and x.ruta = m.ruta
     where $3 or not m.descart
  $q$
  using p_cuentas, p_mov, coalesce(p_todos, false);
end $f$;
revoke execute on function public.fn_banco_tickets_llegados(text[], uuid, boolean) from public, anon, authenticated, service_role;

-- CASAR UN LADO de una transferencia con la línea que la espera (la del
-- asiento que puso el otro lado). Un asiento para los dos lados lleva UNA
-- fecha, y una línea del libro no puede ir después de su movimiento: si
-- este lado llega con fecha anterior a la del asiento (y los dos meses
-- abiertos), el asiento se rehace con la fecha más temprana (ver
-- fn_banco_transferencia_rehacer). Lo usan el motor y fn_banco_casar_con.
create or replace function public.fn_banco_casar_transferencia(p_mov uuid, p_asiento uuid, p_orden int, p_regla text, p_auto boolean,
                                                               p_motivo text default null)
returns uuid
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_f     date;
  v_fa    date;
  v_nuevo uuid := p_asiento;
  v_bloq  text;
begin
  select m.fecha into v_f from movimientos_banco m where m.id = p_mov;
  select a.fecha_contable into v_fa from asientos a where a.id = p_asiento;
  v_bloq := fn_banco_transferencia_bloqueo(p_mov, p_asiento);
  if v_bloq is not null then
    raise exception using errcode = 'MX008', message = format('No se casa todavía: %s.', v_bloq);
  end if;
  if v_f < v_fa
     and exists (select 1 from periodos p where p.tipo <> 'anio' and v_f between p.desde and p.hasta and p.estado = 'abierto')
     and exists (select 1 from periodos p where p.tipo <> 'anio' and v_fa between p.desde and p.hasta and p.estado = 'abierto') then
    v_nuevo := fn_banco_transferencia_rehacer(p_asiento, v_f,
                 format('La otra mitad de la transferencia llegó con fecha %s, antes que la del asiento (%s): se rehace con la fecha '
                        'más temprana, para que ningún corte vea el dinero en el banco sin su línea.', v_f, v_fa));
  end if;
  return fn_banco_casar_lineas(p_mov, 'transferencia',
                               (select c.movimiento_id::text from banco_casados c
                                 where c.asiento_id = v_nuevo and c.deshecho_el is null limit 1),
                               v_nuevo, jsonb_build_array(jsonb_build_object('asiento_id', v_nuevo, 'orden', p_orden)),
                               p_regla, p_auto, false, p_motivo);
end $$;
revoke execute on function public.fn_banco_casar_transferencia(uuid, uuid, int, text, boolean, text)
  from public, anon, authenticated, service_role;

-- EL MOTOR: casa lo que casa solo (R-, R1/R2 mutuos, los tickets
-- repartidos, los cobros que suman un depósito, las partidas de la
-- apertura, las transferencias con sus dos lados, las reglas fijas), en
-- rondas hasta que ya no casa nada nuevo (lo que casa una ronda puede
-- dejar sola a otra línea), y propone lo demás.
--   p_cuenta, p_desde  el alcance (nulos: todo lo pendiente); p_mov, uno.
-- Lo mutuo se mira contra TODO lo pendiente de esas cuentas, no solo contra
-- el alcance: un movimiento de otro mes que también podría casar con esa
-- línea la deja sin casar sola.
-- LA VENTANA de cada línea con cada movimiento es fn_banco_ventana (la
-- fecha de la compra, un cheque que tarda, la dirección de una
-- transferencia): casa solo lo 'fuerte', único y mutuo; lo 'débil' (un
-- cheque sin su número en el libro) cuenta como candidato (frena casar
-- otra cosa sola) y se propone. Con un cheque, si alguna línea dice su
-- número, cuentan solo esas.
-- EL RELOJ: la API de Supabase corta cada llamada a los 8 s y deshace todo
-- lo que hizo; con una bandeja atrasada de meses, casar todo de una vez se
-- pasaba y no casaba nada nunca más. Por eso el motor mira el reloj: lo
-- automático para a los 4 s y las propuestas nuevas a los 5 s, y devuelve
-- lo que hizo con «completo»: false y «siguiente» (volver a llamar: lo
-- casado queda y la llamada siguiente sigue donde esta quedó). Cada
-- llamada hace al menos un casado o una propuesta: siempre avanza. (Las
-- pruebas bajan el tope con el ajuste mx_banco.tope_ms, para ver que en
-- tramos sale lo mismo que de una vez; solo se puede bajar.)
-- LAS PROPUESTAS se hacen solo donde hace falta: lo nuevo (sin propuesta)
-- siempre; lo demás solo si cambió lo que las propuestas miran (su firma,
-- fn_banco_firma) y mientras quede tiempo (hasta 1,5 s): lo que no
-- alcanza conserva la anterior y se rehace al abrir el movimiento
-- (fn_banco_casar) o en la llamada siguiente. Antes cada llamada rehacía
-- la propuesta de TODO lo pendiente aunque nada hubiera cambiado: con la
-- bandeja atrasada, 2 a 5 s por llamada con el candado del casado tomado.
-- Las cuentas y los descriptores se leen una vez, no fila por fila.
create or replace function public.fn_banco_casar_interno(p_cuenta text, p_desde date, p_mov uuid, p_proponer boolean default true)
returns jsonb
language plpgsql
set search_path = public, pg_temp
set jit = off
as $$
declare
  v_inicio  timestamptz := clock_timestamp();
  v_tope_ms int := least(4000, coalesce(case when current_setting('mx_banco.tope_ms', true) ~ '^[0-9]{1,7}$'
                                             then current_setting('mx_banco.tope_ms', true)::int end, 4000));
  v_tope_a  interval := make_interval(secs => v_tope_ms / 1000.0);
  v_tope_p  interval := make_interval(secs => v_tope_ms / 1000.0 + 1);
  v_tope_r  interval := make_interval(secs => v_tope_ms * 0.375 / 1000.0);
  v_hechas  int := 0;
  v_corte   date := fn_puente_corte();
  v_cuentas text[];
  v_cuentas_l text[];
  v_tipos   jsonb;
  v_pat_tr  text;
  v_pat_pt  text;
  v_pat_pr  text;
  v_pat_cd  text;
  v_u4      jsonb;
  v_aper    boolean;
  v_fmontos numeric[];
  v_uno     uuid[] := '{}';
  v_lcand   text[] := '{}';
  v_min     date;
  v_max     date;
  v_ronda   int := 0;
  v_hechos  int;
  v_completo boolean := true;
  v_sin_rehacer int := 0;
  v_sin_propuesta int := 0;
  r         record;
  m         movimientos_banco;
  m2        movimientos_banco;
  v_res     jsonb;
  v_clase   text;
  v_n_papel int := 0;
  v_n_cruce int := 0;
  v_n_grupo int := 0;
  v_n_cobros int := 0;
  v_n_aper  int := 0;
  v_n_trans int := 0;
  v_n_regla int := 0;
  v_n_llego int := 0;
  v_cands   jsonb := '{}'::jsonb;
  v_obras   jsonb := '{}'::jsonb;
  v_ctx     jsonb;
  v_mira    jsonb;
  v_otros   jsonb;
  v_prop    jsonb;
  v_antes   int;
  v_firma   jsonb;
  v_fmov    text;
  v_contras jsonb := '{}'::jsonb;
  v_aper_mov jsonb := '{}'::jsonb;
  v_rec     text;
  v_llego   jsonb := '{}'::jsonb;
  v_rep     text;
  v_rep_op  jsonb;
  v_fuerza  boolean;
  v_trf     jsonb;
  v_conc    text;
begin
  -- Un casado a la vez en todo el banco (ver arriba, los candados).
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  -- Primero, los casados cuyo papel se rehízo (fn_banco_sanar), y las
  -- partidas de la apertura que la tarjeta trajo antes del corte
  -- (fn_banco_apertura_previas: no esperan a que haya algo pendiente).
  perform fn_banco_sanar();
  if p_mov is null then
    v_n_aper := fn_banco_apertura_previas(p_cuenta);
  end if;
  select count(*) into v_antes
    from movimientos_banco x
   where x.estado = 'pendiente' and x.fecha >= v_corte
     and (p_mov is null or x.id = p_mov) and (p_cuenta is null or x.cuenta = p_cuenta) and (p_desde is null or x.fecha >= p_desde);

  <<motor>>
  begin
    exit motor when v_antes = 0;
    -- Todas las cuentas con algo pendiente (una transferencia mira el otro
    -- estado de cuenta), el tipo de cada cuenta propia, y los descriptores
    -- de las transferencias.
    select array_agg(distinct x.cuenta) into v_cuentas
      from movimientos_banco x where x.estado = 'pendiente' and x.fecha >= v_corte;
    -- Lo que casa con líneas del libro (R1, R2, los grupos, la apertura y
    -- las propuestas) mira solo las cuentas del alcance: una línea de una
    -- cuenta solo casa con un movimiento de esa misma cuenta, y lo mutuo de
    -- una línea se mira contra lo pendiente de SU cuenta (todo, no solo el
    -- alcance). Sin esto, casar una cuenta (o abrir un movimiento) recorría
    -- en cada ronda las líneas libres y lo pendiente de TODAS las cuentas:
    -- con un año de banco, un segundo por llamada aunque la cuenta tuviera
    -- tres movimientos.
    v_cuentas_l := case when p_mov is not null then array(select x.cuenta from movimientos_banco x where x.id = p_mov)
                        when p_cuenta is not null then array[p_cuenta]
                        else v_cuentas end;
    select coalesce(jsonb_object_agg(c.codigo, fn_banco_tipo_cuenta(c.codigo)), '{}'::jsonb) into v_tipos
      from cuentas c
     -- (solo las que pueden serlo, un banco 10xx o una tarjeta dada de alta,
     -- pasan por la función: «case» decide el orden)
     where case when left(c.codigo, 2) = '10' or exists (select 1 from tarjetas t where t.cuenta = c.codigo)
                then fn_banco_es_propia(c.codigo) else false end;
    select d.patron into v_pat_tr from banco_descriptores d where d.clave = 'transferencia';
    select d.patron into v_pat_pt from banco_descriptores d where d.clave = 'pago_tarjeta';
    select d.patron into v_pat_pr from banco_descriptores d where d.clave = 'pago_recibido';
    select d.patron into v_pat_cd from banco_descriptores d where d.clave = 'cheque_devuelto';
    -- Los 4 últimos de cada tarjeta de la empresa, por su cuenta: el pago de
    -- una tarjeta que el banco describe con ellos («PAYMENT TO CARD ENDING
    -- 2013») también dice a qué tarjeta va.
    select coalesce(jsonb_object_agg(x.cuenta, x.u4), '{}'::jsonb) into v_u4
      from (select t.cuenta, jsonb_agg(distinct t.ultimos4) as u4 from tarjetas t where t.ultimos4 ~ '^[0-9]{4}$' group by t.cuenta) x;
    -- ¿Hay partidas de la apertura todavía sin llegar en estas cuentas? (Casi
    -- siempre no: solo octubre y noviembre de 2026.)
    v_aper := exists (select 1 from conciliacion_partidas pa join conciliaciones c on c.id = pa.conciliacion_id
                       where c.tipo = 'apertura' and c.estado = 'confirmada' and pa.lado = 'libro' and pa.asiento_id is null
                         and pa.resuelta_por_movimiento is null and c.cuenta = any (v_cuentas_l));

    <<rondas>>
    loop
      v_ronda := v_ronda + 1;
      v_hechos := 0;

      -- R- · El papel ya nombra al movimiento (un cobro o una devolución
      -- registrados con su movimiento_id).
      for r in
        select distinct on (mm.id) mm.id as mov, x0.clase, x0.ref, x0.asiento,
               (select jsonb_agg(jsonb_build_object('asiento_id', l.asiento_id, 'orden', l.orden) order by l.orden)
                  from asiento_lineas l
                 where l.asiento_id = x0.asiento and l.cuenta = mm.cuenta
                   and not exists (select 1 from banco_casado_lineas cl
                                    where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente)) as lineas,
               (select coalesce(sum(l.monto), 0)
                  from asiento_lineas l
                 where l.asiento_id = x0.asiento and l.cuenta = mm.cuenta
                   and not exists (select 1 from banco_casado_lineas cl
                                    where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente)) as suma,
               mm.monto
          from (select 1 as o, 'cobro'::text as clase, c.id::text as ref, c.contabilizado_en as asiento, c.movimiento_id as mid
                  from cobros c where c.movimiento_id is not null and c.estado = 'vigente' and c.contabilizado_en is not null
                union all
                select 2, 'devolucion', d.id::text, d.contabilizado_en, d.movimiento_id
                  from cobros_devoluciones d where d.movimiento_id is not null and d.contabilizado_en is not null) x0
          join movimientos_banco mm on mm.id::text = x0.mid
         where mm.estado = 'pendiente' and mm.fecha >= v_corte
           and (p_mov is null or mm.id = p_mov) and (p_cuenta is null or mm.cuenta = p_cuenta) and (p_desde is null or mm.fecha >= p_desde)
           and (mm.posible_duplicado_de is null or mm.duplicado = 'no_es_el_mismo')
         order by mm.id, x0.o
      loop
        if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
           and clock_timestamp() - v_inicio > v_tope_a then
          v_completo := false;
          exit rondas;
        end if;
        if r.lineas is not null and r.suma = r.monto then
          perform fn_banco_casar_lineas(r.mov, r.clase, r.ref, r.asiento, r.lineas,
                                        case r.clase when 'cobro' then 'R2 el cobro dice este movimiento'
                                                     else 'R9 la devolución dice este movimiento' end, true, false);
          v_n_papel := v_n_papel + 1;
          v_hechos := v_hechos + 1;
        end if;
      end loop;

      -- (El reloj, ANTES de cada regla: una consulta que ya empezó no se
      -- corta, y con la bandeja atrasada cada una cuenta.)
      if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
         and clock_timestamp() - v_inicio > v_tope_a then
        v_completo := false;
        exit rondas;
      end if;
      -- R1 / R2 · El cruce exacto y MUTUO con una línea del libro, en su
      -- ventana (fn_banco_ventana, 'fuerte').
      for r in
        with pool as (select f.*, ((p_mov is null or f.id = p_mov) and (p_cuenta is null or f.cuenta = p_cuenta)
                                   and (p_desde is null or f.fecha >= p_desde)) as al,
                             v_tipos->>f.cuenta as tipo
                        from fn_banco_pool(v_cuentas_l) f),
             lin as (select * from fn_banco_lineas_libres(v_cuentas_l, (select min(least(x.fecha, coalesce(x.ftx, x.fecha))) - 60
                                                                          from pool x))),
             cand as (select p.id as mov, p.fecha, p.al, l.asiento_id, l.orden, l.origen_tabla, l.origen_id, l.tr,
                             fn_banco_ventana(p.fecha, p.ftx, p.cheque, l.fdoc, l.monto, l.tr, p.tipo, v_tipos->>l.tr_otra, l.texto) as v,
                             coalesce(p.cheque ~ '^[0-9]+$' and ltrim(p.cheque, '0') <> ''
                                      and coalesce(l.texto, '') ~* ('(^|[^0-9])0*' || ltrim(p.cheque, '0') || '([^0-9]|$)'), false) as num
                        from pool p
                        join lin l on l.cuenta = p.cuenta and l.monto = p.monto and l.fdoc between p.fecha - 60 and p.fecha + 10
                       where not (l.origen_tabla = 'cobros'
                                  and exists (select 1 from cobros c
                                               where c.id = (case when l.origen_tabla = 'cobros' then l.origen_id::uuid end)
                                                 and c.movimiento_id is not null and c.movimiento_id <> p.id::text))
                         and not (l.origen_tabla = 'cobros_devoluciones'
                                  and exists (select 1 from cobros_devoluciones d
                                               where d.id = (case when l.origen_tabla = 'cobros_devoluciones' then l.origen_id::uuid end)
                                                 and d.movimiento_id is not null and d.movimiento_id <> p.id::text))
                         and not (l.origen_tabla = 'prestamo_cuotas'
                                  and exists (select 1 from prestamo_cuotas q
                                               where q.id = (case when l.origen_tabla = 'prestamo_cuotas' then l.origen_id::uuid end)
                                                 and q.movimiento_id is not null and q.movimiento_id <> p.id))
                         -- (lo que Edgar des-casó no vuelve a casar solo: lo elige él)
                         and not exists (select 1 from banco_casados bc join banco_casado_lineas bl on bl.casado_id = bc.id
                                          where bc.movimiento_id = p.id and bc.deshecho_el is not null
                                            and bl.asiento_id = l.asiento_id and bl.orden = l.orden)),
             cv as (select * from cand where cand.v is not null),
             cc as (select c.*, count(*) over (partition by c.mov) as nm, count(*) filter (where c.num) over (partition by c.mov) as nmn,
                           count(*) over (partition by c.asiento_id, c.orden) as nl,
                           count(*) filter (where c.num) over (partition by c.asiento_id, c.orden) as nln
                      from cv c)
        select cc.mov, cc.fecha, cc.asiento_id, cc.orden, cc.origen_tabla, cc.origen_id, cc.tr
          from cc
         where cc.al and cc.v = 'fuerte'
           and case when cc.nmn > 0 then cc.num and cc.nmn = 1 else cc.nm = 1 end
           and case when cc.nln > 0 then cc.num and cc.nln = 1 else cc.nl = 1 end
         order by cc.fecha, cc.mov
      loop
        if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
           and clock_timestamp() - v_inicio > v_tope_a then
          v_completo := false;
          exit rondas;
        end if;
        v_clase := fn_banco_clase_de(r.asiento_id);
        if v_clase = 'transferencia' then
          -- (Si casarlo rehace el asiento dentro de una conciliación
          -- confirmada, no casa solo: se propone, con qué reabrir.)
          continue when fn_banco_transferencia_bloqueo(r.mov, r.asiento_id) is not null;
          perform fn_banco_casar_transferencia(r.mov, r.asiento_id, r.orden, 'R3 la otra mitad de la transferencia (en su ventana)',
                                               true);
        else
          perform fn_banco_casar_lineas(
            r.mov, v_clase,
            case when v_clase in ('recibo', 'cobro', 'devolucion', 'cuota_prestamo') then r.origen_id
                 else (select a.numero from asientos a where a.id = r.asiento_id) end,
            r.asiento_id, jsonb_build_array(jsonb_build_object('asiento_id', r.asiento_id, 'orden', r.orden)),
            case v_clase when 'recibo' then 'R1 tarjeta o débito = recibo (mismo monto, en la ventana de la compra)'
                         when 'cobro' then 'R2 depósito = cobro (mismo monto, fecha cercana)'
                         when 'devolucion' then 'R9 devolución = su línea del banco'
                         when 'cuota_prestamo' then 'R8 la cuota ya registrada'
                         else 'R1 cruce exacto con el libro (mismo monto, en su ventana)' end,
            true, false);
        end if;
        v_n_cruce := v_n_cruce + 1;
        v_hechos := v_hechos + 1;
      end loop;

      if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
         and clock_timestamp() - v_inicio > v_tope_a then
        v_completo := false;
        exit rondas;
      end if;
      -- Lo que todavía tiene algo del libro en su ventana (fuerte o débil):
      -- no casa solo por ninguna otra regla (se propone); y las líneas que
      -- son candidatas de algún movimiento (no entran en un grupo).
      -- (Lo de las cuentas del alcance y, de las otras, solo lo que podría
      -- ser la otra mitad de una transferencia de ellas: el mismo dinero con
      -- el signo contrario, a días; R3 mira los dos lados. Lo de las otras
      -- cuentas se busca en la tabla por su monto, con las mismas columnas
      -- que fn_banco_pool: antes se leía TODO lo pendiente de todas las
      -- cuentas, con su expresión regular fila por fila, en cada ronda.)
      with alc as materialized (select f.*, v_tipos->>f.cuenta as tipo from fn_banco_pool(v_cuentas_l) f),
           pool as (select * from alc
                    union all
                    select mo.id, mo.cuenta, mo.fecha, mo.fecha_transaccion, mo.monto, mo.tipo_banco,
                           coalesce(nullif(ltrim(mo.cheque, '0'), ''),
                                    substring(mo.desc_norm from '(?:^| )(?:CHECK|CHK|CHEQUE|CK)(?: NO)? ?#? ?0*([1-9][0-9]{0,9})(?: |$)')),
                           mo.desc_norm,
                           case when mo.memo is null then mo.desc_norm else btrim(mo.desc_norm || ' ' || fn_banco_norm(mo.memo)) end,
                           v_tipos->>mo.cuenta
                      from movimientos_banco mo
                     where mo.estado = 'pendiente' and mo.fecha >= v_corte and mo.cuenta = any (v_cuentas)
                       and not (mo.cuenta = any (v_cuentas_l))
                       and (mo.posible_duplicado_de is null or mo.duplicado = 'no_es_el_mismo')
                       and exists (select 1 from alc q where q.monto = -mo.monto and mo.fecha between q.fecha - 13 and q.fecha + 13)),
           lin as (select * from fn_banco_lineas_libres((select array_agg(distinct x.cuenta) from pool x),
                                                        (select min(least(x.fecha, coalesce(x.ftx, x.fecha))) - 60 from pool x))),
           cv as (select p.id, l.asiento_id, l.orden
                    from pool p
                    join lin l on l.cuenta = p.cuenta and l.monto = p.monto and l.fdoc between p.fecha - 60 and p.fecha + 10
                   where fn_banco_ventana(p.fecha, p.ftx, p.cheque, l.fdoc, l.monto, l.tr, p.tipo, v_tipos->>l.tr_otra, l.texto)
                         is not null)
      select coalesce(array_agg(distinct cv.id), '{}'), coalesce(array_agg(distinct cv.asiento_id::text || ':' || cv.orden), '{}')
        into v_uno, v_lcand
        from cv;

      if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
         and clock_timestamp() - v_inicio > v_tope_a then
        v_completo := false;
        exit rondas;
      end if;
      -- R1 · Un ticket repartido entre obras: la misma foto en varios
      -- recibos que suman el cargo (y solo esos, y solo ese cargo).
      for r in
        with pool as (select f.*, ((p_mov is null or f.id = p_mov) and (p_cuenta is null or f.cuenta = p_cuenta)
                                   and (p_desde is null or f.fecha >= p_desde)) as al
                        from fn_banco_pool(v_cuentas_l) f),
             lin as (select * from fn_banco_lineas_libres(v_cuentas_l, (select min(least(x.fecha, coalesce(x.ftx, x.fecha))) - 7
                                                                        from pool x))),
             grp as (select l.cuenta, btrim(rc.ruta) as ruta,
                            jsonb_agg(jsonb_build_object('asiento_id', l.asiento_id, 'orden', l.orden) order by rc.id) as lineas,
                            string_agg(rc.id::text, ',' order by rc.id) as refs, sum(l.monto) as total,
                            min(l.fdoc) as f1, max(l.fdoc) as f2, (array_agg(l.asiento_id order by rc.id))[1] as a1
                       from lin l
                       join recibos rc on l.origen_tabla = 'recibos'
                                      and rc.id = (case when l.origen_id ~ '^-?[0-9]{1,18}$' then l.origen_id::bigint end)
                      where nullif(btrim(rc.ruta), '') is not null
                      group by l.cuenta, btrim(rc.ruta)
                     having count(*) >= 2),
             gc as (select p.id as mov, p.fecha, p.al, g.* from pool p
                      join grp g on g.cuenta = p.cuenta and g.total = p.monto
                                and g.f1 >= (case when p.ftx is not null then least(p.ftx, p.fecha) - 3 else p.fecha - 7 end)
                                and g.f2 <= p.fecha + 3
                     where not exists (select 1 from unnest(v_uno) as u(id) where u.id = p.id)
                       and not exists (select 1 from banco_casados bc
                                        where bc.movimiento_id = p.id and bc.deshecho_el is not null and bc.clase = 'recibo'
                                          and bc.referencia = g.refs)),
             gcc as (select gc.*, count(*) over (partition by gc.mov) as nm, count(*) over (partition by gc.cuenta, gc.ruta) as ng from gc)
        select * from gcc where nm = 1 and ng = 1 and al order by fecha, mov
      loop
        if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
           and clock_timestamp() - v_inicio > v_tope_a then
          v_completo := false;
          exit rondas;
        end if;
        perform fn_banco_casar_lineas(r.mov, 'recibo', r.refs, r.a1, r.lineas,
                                      'R1 tarjeta o débito = ticket repartido entre obras (la misma foto)', true, false);
        v_n_grupo := v_n_grupo + 1;
        v_hechos := v_hechos + 1;
      end loop;

      if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
         and clock_timestamp() - v_inicio > v_tope_a then
        v_completo := false;
        exit rondas;
      end if;
      -- R2 · Un depósito de VARIOS cobros ya registrados (los cheques que
      -- Edgar anotó uno por factura y depositó juntos): dos o tres cobros
      -- vigentes sin movimiento, de esa cuenta, fechados de 7 días antes a 3
      -- después, que suman el depósito al centavo. Solo si la suma es única
      -- (una sola combinación para ese depósito) y mutua (ninguno de esos
      -- cobros entra en la combinación de otro depósito ni casa solo con
      -- otro movimiento). Antes el depósito salía «sin cobro», los mensajes
      -- llevaban a registrar un anticipo y el mismo dinero entraba dos
      -- veces. (El movimiento queda escrito en el primer cobro: c3 deja uno
      -- por movimiento; los demás casan por sus líneas.)
      for r in
        with pool as (select f.*, ((p_mov is null or f.id = p_mov) and (p_cuenta is null or f.cuenta = p_cuenta)
                                   and (p_desde is null or f.fecha >= p_desde)) as al
                        from fn_banco_pool(v_cuentas_l) f
                       where f.monto > 0 and v_tipos->>f.cuenta = 'banco'),
             cl as (select l.asiento_id, l.orden, l.cuenta, l.monto, l.fdoc, co.id as cobro,
                           row_number() over (order by l.fdoc, l.asiento_id, l.orden) as i
                      from fn_banco_lineas_libres(v_cuentas_l, (select min(x.fecha) - 7 from pool x)) l
                      join cobros co on co.id = (case when l.origen_id ~ '^[0-9a-fA-F-]{36}$' then l.origen_id::uuid end)
                     where l.origen_tabla = 'cobros' and l.monto > 0 and co.estado = 'vigente' and co.movimiento_id is null
                       and not exists (select 1 from unnest(v_lcand) as u(k) where u.k = l.asiento_id::text || ':' || l.orden)),
             dep as (select p.* from pool p where not exists (select 1 from unnest(v_uno) as u(id) where u.id = p.id)
                       and not exists (select 1 from banco_casados bc
                                        where bc.movimiento_id = p.id and bc.deshecho_el is not null and bc.clase = 'cobro')),
             combos as (
               select d.id as mov, d.al, d.fecha, array[a.i, b.i] as ii
                 from dep d
                 join cl a on a.cuenta = d.cuenta and a.monto < d.monto and a.fdoc between d.fecha - 7 and d.fecha + 3
                 join cl b on b.cuenta = d.cuenta and b.i > a.i and b.monto = d.monto - a.monto and b.fdoc between d.fecha - 7 and d.fecha + 3
               union all
               select d.id, d.al, d.fecha, array[a.i, b.i, e.i]
                 from dep d
                 join cl a on a.cuenta = d.cuenta and a.monto < d.monto and a.fdoc between d.fecha - 7 and d.fecha + 3
                 join cl b on b.cuenta = d.cuenta and b.i > a.i and a.monto + b.monto < d.monto and b.fdoc between d.fecha - 7 and d.fecha + 3
                 join cl e on e.cuenta = d.cuenta and e.i > b.i and e.monto = d.monto - a.monto - b.monto
                          and e.fdoc between d.fecha - 7 and d.fecha + 3),
             nd as (select c.mov, count(*) as n from combos c group by c.mov),
             nli as (select x.i, count(distinct c.mov) as n from combos c cross join unnest(c.ii) as x(i) group by x.i)
        select c.mov, c.fecha,
               (select jsonb_agg(jsonb_build_object('asiento_id', cl.asiento_id, 'orden', cl.orden) order by cl.i)
                  from cl where cl.i = any (c.ii)) as lineas,
               (select cl.cobro from cl where cl.i = any (c.ii) order by cl.i limit 1) as primero,
               (select cl.asiento_id from cl where cl.i = any (c.ii) order by cl.i limit 1) as a1
          from combos c
          join nd on nd.mov = c.mov and nd.n = 1
         where c.al and not exists (select 1 from unnest(c.ii) as x(i) join nli on nli.i = x.i where nli.n > 1)
         order by c.fecha, c.mov
      loop
        if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
           and clock_timestamp() - v_inicio > v_tope_a then
          v_completo := false;
          exit rondas;
        end if;
        perform fn_banco_casar_lineas(r.mov, 'cobro', r.primero::text, r.a1, r.lineas,
                                      'R2 depósito = varios cobros ya registrados que lo suman (únicos, fecha cercana)', true, false);
        v_n_cobros := v_n_cobros + 1;
        v_hechos := v_hechos + 1;
      end loop;

      -- Las partidas en tránsito de la era QuickBooks (la conciliación de
      -- apertura, confirmada), SOLO en el cruce exacto: el cheque por su
      -- número (CHECKNUM, o el de NAME: «CHECK 1043») y su monto; un depósito
      -- en tránsito (sin número) por su monto, en la primera semana después
      -- del corte (lo que tarda en acreditarse un depósito del 30) y solo si
      -- nada más lo explica: ni un cobro sin movimiento ni una factura
      -- abierta por ese monto. Antes eran 60 días a ciegas: el Zelle de un
      -- cliente del 20-oct se tomaba por el depósito del 30-sep que nunca
      -- llegó, su factura se quedaba abierta y la partida perdida desaparecía
      -- de la conciliación. Lo demás (el cheque sin su número, el depósito
      -- que el banco trae en dos, el que llega tarde, un cargo sin número)
      -- lo propone la bandeja (fn_banco_apertura_opciones) y lo decide Edgar.
      -- Solo si el movimiento no tiene nada del libro en su ventana, y solo
      -- una partida que no tiene todavía nada casado.
      if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
         and clock_timestamp() - v_inicio > v_tope_a then
        v_completo := false;
        exit rondas;
      end if;
      if v_aper then
        if v_fmontos is null then
          -- Lo que explica un depósito: un cobro sin movimiento o lo que
          -- falta por cobrar de una factura (su cuenta por cobrar, su
          -- retención o las dos).
          select coalesce(array_agg(distinct x.m), '{}') into v_fmontos
            from (select c.monto as m from cobros c where c.estado = 'vigente' and c.movimiento_id is null
                  union all
                  select f.s
                    from (select coalesce(sum(l.monto) filter (where l.cuenta = fn_puente_cuenta_de('cxc')), 0) as s1,
                                 coalesce(sum(l.monto) filter (where l.cuenta = fn_puente_cuenta_de('retencion_cxc')), 0) as s2
                            from asiento_lineas l
                            join facturas fa on fa.id = (case when l.partida_id ~ '^-?[0-9]{1,18}$' then l.partida_id::bigint end)
                           where l.partida_tabla = 'facturas'
                             and l.cuenta in (fn_puente_cuenta_de('cxc'), fn_puente_cuenta_de('retencion_cxc'))
                             and coalesce(fa.estado, 'emitida') <> 'anulada'
                           group by fa.id) q
                   cross join lateral (values (q.s1), (q.s2), (q.s1 + q.s2)) as f(s)
                   where f.s > 0) x;
        end if;
        for r in
          with pool as (select f.*, ((p_mov is null or f.id = p_mov) and (p_cuenta is null or f.cuenta = p_cuenta)
                                     and (p_desde is null or f.fecha >= p_desde)) as al
                          from fn_banco_pool(v_cuentas_l) f),
               ap as (select pa.id, c.cuenta, pa.monto, nullif(ltrim(pa.cheque, '0'), '') as cheque
                        from conciliacion_partidas pa
                        join conciliaciones c on c.id = pa.conciliacion_id
                       where c.tipo = 'apertura' and c.estado = 'confirmada' and pa.lado = 'libro' and pa.asiento_id is null
                         and pa.clase <> 'error' and pa.resuelta_por_movimiento is null and c.cuenta = any (v_cuentas_l)
                         and not exists (select 1 from banco_casados bc
                                          where bc.clase = 'apertura' and bc.deshecho_el is null and bc.referencia = pa.id::text)),
               apc as (select p.id as mov, p.fecha, p.al, ap.id as partida
                         from pool p
                         join ap on ap.cuenta = p.cuenta and ap.monto = p.monto
                        where not exists (select 1 from unnest(v_uno) as u(id) where u.id = p.id)
                          and not exists (select 1 from banco_casados bc
                                           where bc.movimiento_id = p.id and bc.deshecho_el is not null and bc.clase = 'apertura'
                                             and bc.referencia = ap.id::text)
                          and ((p.cheque is not null and ap.cheque is not null and p.cheque = ap.cheque)
                               or (p.cheque is null and ap.cheque is null and p.monto > 0 and p.fecha <= v_corte + 7
                                   and not (p.monto = any (v_fmontos))))),
               apcc as (select apc.*, count(*) over (partition by apc.mov) as nm, count(*) over (partition by apc.partida) as np from apc)
          select * from apcc where nm = 1 and np = 1 and al order by fecha, mov
        loop
          if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
             and clock_timestamp() - v_inicio > v_tope_a then
            v_completo := false;
            exit rondas;
          end if;
          perform fn_banco_casar_lineas(r.mov, 'apertura', r.partida::text, null, '[]'::jsonb,
                                        'Apertura: la partida en tránsito del 30-sep (la conciliación de apertura)', true, false);
          v_n_aper := v_n_aper + 1;
          v_hechos := v_hechos + 1;
        end loop;
      end if;

      -- R3 · La transferencia con sus DOS lados pendientes: un asiento con
      -- la fecha del primero, origen el lado que sale, y los dos casados con
      -- él. Solo en su DIRECCIÓN y con el descriptor en la descripción del
      -- banco (NAME, no la nota: el MEMO lo escribe quien manda el dinero):
      -- de un banco a una tarjeta, el pago de la tarjeta, si el lado del
      -- banco nombra al emisor (pago_tarjeta) o los 4 últimos de ESA tarjeta,
      -- Y el lado de la tarjeta dice que es un pago (pago_recibido): un abono
      -- de un comercio en la tarjeta (una devolución) no es el pago. Antes
      -- bastaba AUTOPAY o THANK YOU en el banco y cualquier abono en la
      -- tarjeta: la luz de FPL en AUTOPAY casaba sola con una devolución de
      -- Lowe's como el pago de la Amex, y ni la luz ni la devolución llegaban
      -- nunca a resultados. De un banco a otro, la transferencia (XFER o
      -- transferencia). El lado que entra, del día en que sale a 10 días
      -- después (un ACH a otro banco tarda 3 a 5 días hábiles; en una
      -- tarjeta, desde 3 días antes). Una tarjeta que manda dinero a un banco
      -- (un adelanto de efectivo) no se supone nunca.
      -- EL TIEMPO: lo pendiente se lee de su tabla (con sus estadísticas: con
      -- la función de arriba el planificador creía que eran mil filas, y la
      -- parte filtrada una, y juntaba cada una con todas en un Nested Loop:
      -- 4 s por ronda con un año sin resolver, y la API cortaba cada
      -- «Casar»), solo lo que tiene el monto de algo del alcance (un
      -- movimiento, o una cuenta, no mira todo el banco), y los lados se
      -- juntan por su monto (Hash Join); lo que tiene algo del libro en su
      -- ventana se quita con un anti-join, no mirando un arreglo fila por fila.
      if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
         and clock_timestamp() - v_inicio > v_tope_a then
        v_completo := false;
        exit rondas;
      end if;
      for r in
        with uno as (select distinct u.id from unnest(v_uno) as u(id)),
             alc as (select distinct abs(mb.monto) as x
                       from movimientos_banco mb
                      where mb.estado = 'pendiente' and mb.fecha >= v_corte and mb.cuenta = any (v_cuentas)
                        and (p_mov is null or mb.id = p_mov) and (p_cuenta is null or mb.cuenta = p_cuenta)
                        and (p_desde is null or mb.fecha >= p_desde)),
             pool as materialized (
               select mb.id, mb.cuenta, mb.fecha, mb.monto, mb.tipo_banco, mb.desc_norm as dn, v_tipos->>mb.cuenta as tipo,
                      ((p_mov is null or mb.id = p_mov) and (p_cuenta is null or mb.cuenta = p_cuenta)
                       and (p_desde is null or mb.fecha >= p_desde)) as al
                 from movimientos_banco mb
                where mb.estado = 'pendiente' and mb.fecha >= v_corte and mb.cuenta = any (v_cuentas)
                  and (mb.posible_duplicado_de is null or mb.duplicado = 'no_es_el_mismo')
                  and abs(mb.monto) in (select alc.x from alc)
                  and not exists (select 1 from uno where uno.id = mb.id)),
             sale as (select * from pool where pool.monto < 0 and pool.tipo = 'banco'),
             entra as (select * from pool where pool.monto > 0 and pool.tipo in ('banco', 'tarjeta')),
             tp as (select a.id as mov1, b.id as mov2, a.cuenta as c1, b.cuenta as c2, a.monto as monto1, b.monto as monto2,
                           least(a.fecha, b.fecha) as f, a.al as al1, b.al as al2
                      from sale a
                      join entra b on b.monto = -a.monto and b.cuenta <> a.cuenta
                                  and b.fecha between a.fecha - (case when b.tipo = 'tarjeta' then 7 else 0 end) and a.fecha + 10
                     where case when b.tipo = 'tarjeta'
                                then (coalesce(a.dn ~* v_pat_pt, false)
                                      or exists (select 1 from jsonb_array_elements_text(v_u4->b.cuenta) as u(u4)
                                                  where a.dn ~ ('(^| )' || u.u4 || '( |$)')))
                                     and coalesce(b.dn ~* v_pat_pr, false)
                                else coalesce(a.tipo_banco, '') = 'XFER' or coalesce(a.dn ~* v_pat_tr, false) end
                       and not exists (select 1 from banco_casados bc
                                        where bc.deshecho_el is not null and bc.clase = 'transferencia'
                                          and ((bc.movimiento_id = a.id and bc.referencia = b.id::text)
                                               or (bc.movimiento_id = b.id and bc.referencia = a.id::text)))
                       -- (ronda 4: si un lado nombra la otra cuenta —«TO CHK
                       -- ...7781»— y ese número es de OTRA cuenta de la empresa,
                       -- no son la misma transferencia)
                       and coalesce(fn_banco_numero_de(fn_banco_otra_cuenta(a.dn)) = b.cuenta, true)
                       and coalesce(fn_banco_numero_de(fn_banco_otra_cuenta(b.dn)) = a.cuenta, true)),
             tpc as (select tp.*, count(*) over (partition by tp.mov1) as n1, count(*) over (partition by tp.mov2) as n2 from tp)
        select * from tpc where tpc.n1 = 1 and tpc.n2 = 1 and (tpc.al1 or tpc.al2)
         order by tpc.f, tpc.mov1
      loop
        if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
           and clock_timestamp() - v_inicio > v_tope_a then
          v_completo := false;
          exit rondas;
        end if;
        select * into m from movimientos_banco where id = r.mov1;
        select * into m2 from movimientos_banco where id = r.mov2;
        -- (en esta ronda uno de los dos pudo casar ya con otra cosa)
        continue when m.estado <> 'pendiente' or m2.estado <> 'pendiente';
        -- La fecha del asiento, nunca dentro de una conciliación confirmada
        -- de sus cuentas (fn_banco_tr_fecha): el pago de fin de mes de la
        -- Amex (abonado el 30-oct, cobrado el 2-nov) no se mete en el Chase
        -- al 31-oct ya confirmado. Si ni así cabe, no casa solo: se propone.
        v_trf := fn_banco_tr_fecha(m.fecha, m.cuenta, m2.fecha, m2.cuenta, m.monto);
        continue when v_trf ? 'bloqueo';
        v_res := fn_banco_asiento('movimientos_banco', r.mov1::text, (v_trf->>'fecha')::date,
                   format('Transferencia entre cuentas propias: %s → %s (%s)', r.c1, r.c2, coalesce(m.descripcion, m2.descripcion, '')),
                   jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', r.c1, 'monto', r.monto1::text,
                                                                          'memo', left(m.descripcion, 200))),
                                     jsonb_strip_nulls(jsonb_build_object('cuenta', r.c2, 'monto', r.monto2::text,
                                                                          'memo', left(m2.descripcion, 200)))),
                   fn_banco_proc(m, 'fn_banco_casar', 'R3 transferencia (los dos lados)')
                   || jsonb_strip_nulls(jsonb_build_object('otro_lado', fn_banco_proc(m2, 'fn_banco_casar', 'R3')->'movimiento',
                                                           'fecha_nota', v_trf->>'nota', 'fecha_por', v_trf->'por')));
        perform fn_banco_casar_lineas(r.mov1, 'transferencia', r.mov2::text, (v_res->>'id')::uuid,
                                      jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 1)),
                                      'R3 transferencia (los dos lados, mismo dinero, en su dirección)', true, true);
        perform fn_banco_casar_lineas(r.mov2, 'transferencia', r.mov1::text, (v_res->>'id')::uuid,
                                      jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 2)),
                                      'R3 transferencia (los dos lados, mismo dinero, en su dirección)', true, false);
        v_n_trans := v_n_trans + 1;
        v_hechos := v_hechos + 1;
      end loop;

      -- R7 · Las reglas FIJAS: intereses del banco → 4910; cargos del banco o
      -- de la tarjeta → 6130 (las cuentas, de banco_descriptores). Solo con
      -- el tipo, el signo y el descriptor (en NAME) de acuerdo, y sin nada
      -- del libro en su ventana. Un cheque devuelto no es un cargo del banco
      -- aunque diga NSF («DEPOSITED ITEM RETURNED NSF»): es la devolución de
      -- un cobro (R9), salvo su comisión («RETURNED ITEM FEE»).
      if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
         and clock_timestamp() - v_inicio > v_tope_a then
        v_completo := false;
        exit rondas;
      end if;
      for r in
        with d as (select d.clave, d.patron, d.cuenta from banco_descriptores d
                    where d.clave in ('interes', 'cargo_banco') and d.cuenta is not null and d.patron is not null
                      and fn_puente_cuenta_mal(d.cuenta) is null)
        select mb.id, d.cuenta as destino, d.clave
          from movimientos_banco mb
          join d on (d.clave = 'interes' and v_tipos->>mb.cuenta = 'banco' and mb.monto > 0 and mb.tipo_banco = 'INT')
                 or (d.clave = 'cargo_banco' and v_tipos->>mb.cuenta is not null and mb.monto < 0 and mb.tipo_banco in ('FEE', 'SRVCHG'))
         where mb.estado = 'pendiente' and mb.fecha >= v_corte and mb.cuenta = any (v_cuentas)
           and (p_mov is null or mb.id = p_mov) and (p_cuenta is null or mb.cuenta = p_cuenta) and (p_desde is null or mb.fecha >= p_desde)
           and (mb.posible_duplicado_de is null or mb.duplicado = 'no_es_el_mismo')
           and mb.desc_norm ~* d.patron
           and not (d.clave = 'cargo_banco' and v_pat_cd is not null and mb.desc_norm ~* v_pat_cd
                    and mb.desc_norm !~ '(^| )(FEE|CHARGE)( |$)')
           and not exists (select 1 from unnest(v_uno) as u(id) where u.id = mb.id)
           -- (Ronda 4: lo que Edgar des-casó no vuelve a casar solo, como en
           -- las demás reglas: antes R7 lo volvía a casar en el acto —otro
           -- asiento, su reverso y otro igual en cada vuelta— y no había
           -- forma de casarlo con otra cosa ni de ignorarlo)
           and not exists (select 1 from banco_casados bc where bc.movimiento_id = mb.id and bc.deshecho_el is not null)
           -- (y cede ante una partida en tránsito de la apertura que es él:
           -- la comisión del wire del 30-sep que QuickBooks ya tiene sale a
           -- la bandeja para casarla con su partida, no otra vez a 6130)
           and case when v_aper then coalesce((fn_banco_apertura_opciones(mb)->>'fuertes')::int, 0) = 0 else true end
         order by mb.fecha, mb.id
      loop
        if v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + v_n_trans + v_n_regla > 0
           and clock_timestamp() - v_inicio > v_tope_a then
          v_completo := false;
          exit rondas;
        end if;
        select * into m from movimientos_banco where id = r.id;
        v_res := fn_banco_asiento('movimientos_banco', m.id::text, m.fecha,
                   format('%s: %s', case r.clave when 'interes' then 'Intereses del banco' else 'Cargo del banco' end,
                          coalesce(m.descripcion, m.memo, '')),
                   jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', m.cuenta, 'monto', m.monto::text,
                                                                          'memo', left(m.descripcion, 200))),
                                     jsonb_strip_nulls(jsonb_build_object('cuenta', r.destino, 'monto', (-m.monto)::text,
                                                                          'memo', left(m.descripcion, 200)))),
                   fn_banco_proc(m, 'fn_banco_casar', 'R7 regla fija ' || r.clave || ' → ' || r.destino));
        perform fn_banco_casar_lineas(m.id, 'regla', r.destino, (v_res->>'id')::uuid,
                                      jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 1)),
                                      'R7 regla fija: ' || case r.clave when 'interes' then 'intereses del banco → ' else 'cargo del banco → ' end
                                      || r.destino || ' (tipo ' || m.tipo_banco || ' y descriptor)', true, true);
        v_n_regla := v_n_regla + 1;
        v_hechos := v_hechos + 1;
      end loop;

      exit when v_hechos = 0 or v_ronda >= 4;
    end loop;

    -- Lo que queda, a la bandeja con su propuesta (si lo automático terminó:
    -- si no, la llamada siguiente las hace).
    exit motor when not (p_proponer and v_completo);
    with pool as (select f.*, ((p_mov is null or f.id = p_mov) and (p_cuenta is null or f.cuenta = p_cuenta)
                               and (p_desde is null or f.fecha >= p_desde)) as al,
                         v_tipos->>f.cuenta as tipo
                    from fn_banco_pool(v_cuentas_l) f),
         lin as (select * from fn_banco_lineas_libres(v_cuentas_l, (select min(least(x.fecha, coalesce(x.ftx, x.fecha))) - 60
                                                                      from pool x where x.al))),
         cand as (select p.id as mov, l.asiento_id, l.orden, l.numero, l.origen_tabla, l.origen_id, l.fdoc, l.tr,
                         fn_banco_ventana(p.fecha, p.ftx, p.cheque, l.fdoc, l.monto, l.tr, p.tipo, v_tipos->>l.tr_otra, l.texto) as v,
                         coalesce(p.cheque ~ '^[0-9]+$' and ltrim(p.cheque, '0') <> ''
                                  and coalesce(l.texto, '') ~* ('(^|[^0-9])0*' || ltrim(p.cheque, '0') || '([^0-9]|$)'), false) as num
                    from pool p
                    join lin l on l.cuenta = p.cuenta and l.monto = p.monto and l.fdoc between p.fecha - 60 and p.fecha + 10
                   where not (l.origen_tabla = 'cobros'
                              and exists (select 1 from cobros c
                                           where c.id = (case when l.origen_tabla = 'cobros' then l.origen_id::uuid end)
                                             and c.movimiento_id is not null and c.movimiento_id <> p.id::text))
                     and not (l.origen_tabla = 'prestamo_cuotas'
                              and exists (select 1 from prestamo_cuotas q
                                           where q.id = (case when l.origen_tabla = 'prestamo_cuotas' then l.origen_id::uuid end)
                                             and q.movimiento_id is not null and q.movimiento_id <> p.id))),
         -- (cuántos OTROS movimientos pendientes quieren la misma línea, y si
         -- Edgar ya la des-casó de este movimiento, con su motivo: la bandeja
         -- no dice «otro movimiento también podría» cuando no hay otro, y dice
         -- lo que Edgar deshizo)
         cv as (select cand.*, count(*) over (partition by cand.asiento_id, cand.orden) - 1 as otros, p.al
                  from cand join pool p on p.id = cand.mov
                 where cand.v is not null),
         -- (los TICKETS CON OTRO TOTAL de cada cargo sin nada que case: la
         -- línea libre de un recibo en su cuenta, en la ventana de la compra,
         -- que se le parece —la regla de fn_banco_otro_total, escrita aquí
         -- para todos de una vez— y que no casa con otro movimiento; las
         -- tres que más se le parecen van a su propuesta y a su firma. Las
         -- palabras del comercio de cada ticket se sacan UNA vez («as
         -- materialized»: sin él, el planificador las volvía a sacar en cada
         -- par ticket-cargo), y cada par se compara con números y con un
         -- cruce de listas. Con la función por par, 1.500 cargos con 300
         -- tickets libres tardaban 12 s en cada «Casar»; sacando las palabras
         -- en cada par, 1,5 s aunque no hubiera nada nuevo.)
         -- (los cargos que buscan su ticket, con el primer día en que pudo
         -- ser la compra; y las líneas libres de los recibos en sus cuentas
         -- y en sus días: las de otros meses no se juntan con nada)
         pc as materialized
               (select p.id, p.cuenta, p.monto, p.fecha, string_to_array(coalesce(p.dn, ''), ' ') as pal,
                       case when p.ftx is not null then least(p.ftx, p.fecha) - 3 else p.fecha - 7 end as desde
                  from pool p
                 where p.al and p.monto < 0 and p.id not in (select cv.mov from cv)),
         lr as materialized
               (select l.asiento_id, l.orden, l.numero, l.origen_id, l.fdoc, l.monto, l.cuenta,
                       coalesce((select array_agg(w.w) from regexp_split_to_table(fn_banco_norm(rc.proveedor), ' ') as w(w)
                                  where length(w.w) >= 4
                                    and w.w not in ('THE', 'INC', 'LLC', 'CORP', 'STORE', 'SUPPLY', 'COMPANY', 'SERVICES')),
                                '{}'::text[]) as pal
                  from lin l
                  left join recibos rc on rc.id = (case when l.origen_id ~ '^-?[0-9]{1,18}$' then l.origen_id::bigint end)
                 where exists (select 1 from pc)
                   and l.origen_tabla = 'recibos' and l.monto < 0
                   and l.cuenta = any ((select array_agg(distinct pc.cuenta) from pc)::text[])
                   and l.fdoc between (select min(pc.desde) from pc) and (select max(pc.fecha) + 3 from pc)
                   and (l.asiento_id, l.orden) not in (select cv.asiento_id, cv.orden from cv)),
         otr as (select o.mov, o.asiento_id, o.orden, o.numero, o.origen_id, o.fdoc, o.monto
                   from (select p.id as mov, l.asiento_id, l.orden, l.numero, l.origen_id, l.fdoc, l.monto,
                                row_number() over (partition by p.id order by abs(l.monto - p.monto), l.fdoc, l.numero) as n
                           from pc p
                           join lr l on l.cuenta = p.cuenta and l.monto <> p.monto and l.fdoc between p.desde and p.fecha + 3
                          where abs(l.monto - p.monto) <= 0.12 * greatest(abs(l.monto), abs(p.monto))
                             or l.pal && p.pal) o
                  where o.n <= 3)
    select (select coalesce(jsonb_object_agg(y.mov, y.c), '{}'::jsonb)
              from (select o.mov, jsonb_agg(jsonb_build_object('asiento_id', o.asiento_id, 'orden', o.orden, 'recibo', o.origen_id,
                                                               'numero', o.numero, 'fecha', o.fdoc, 'monto', o.monto)
                                            order by abs(o.monto - p.monto), o.fdoc, o.numero) as c
                      from otr o join pool p on p.id = o.mov
                     group by o.mov) y),
           (select coalesce(jsonb_object_agg(x.mov, x.c), '{}'::jsonb)
             from (select cand.mov,
                          jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                            'asiento_id', cand.asiento_id, 'numero', cand.numero, 'fecha', cand.fdoc, 'origen_tabla', cand.origen_tabla,
                            'origen_id', cand.origen_id,
                            'debil', case when cand.v = 'debil' then true end, 'tr', case when cand.tr then true end,
                            'otros', case when cand.otros > 0 then cand.otros end,
                            'descasado', (select bc.deshecho_motivo from banco_casados bc join banco_casado_lineas bl on bl.casado_id = bc.id
                                           where bc.movimiento_id = cand.mov and bc.deshecho_el is not null
                                             and bl.asiento_id = cand.asiento_id and bl.orden = cand.orden
                                           order by bc.deshecho_el desc limit 1),
                            'papel', concat_ws(' ', case when cand.tr then 'transferencia'
                                                         else case cand.origen_tabla when 'recibos' then 'recibo' when 'cobros' then 'cobro'
                                                                                     when 'cobros_devoluciones' then 'devolución'
                                                                                     when 'movimientos_banco' then 'movimiento del banco'
                                                                                     when 'prestamo_cuotas' then 'cuota' else 'asiento' end end,
                                                    coalesce(case when cand.origen_tabla = 'recibos' then cand.origen_id end, cand.numero),
                                                    'del ' || cand.fdoc),
                            'lineas', jsonb_build_array(jsonb_build_object('asiento_id', cand.asiento_id, 'orden', cand.orden))))
                            order by cand.num desc, cand.v, cand.fdoc, cand.numero) as c
                     from cv as cand where cand.al group by cand.mov) x)
      into v_otros, v_cands;
    -- (Las obras con visita cada día, todas: fn_banco_obra_de elige la del
    -- día de la compra, o la única de los días antes del banco. Desde 10
    -- días antes: la fecha de la compra que trae la nota.)
    select min(coalesce(x.fecha_transaccion, x.fecha)) - 10, max(x.fecha) into v_min, v_max
      from movimientos_banco x
     where x.estado = 'pendiente' and x.fecha >= v_corte
       and (p_mov is null or x.id = p_mov) and (p_cuenta is null or x.cuenta = p_cuenta) and (p_desde is null or x.fecha >= p_desde);
    if to_regclass('public.eventos') is not null then
      execute 'select coalesce(jsonb_object_agg(x.f::text, x.p), ''{}''::jsonb)
                 from (select e.fecha as f, jsonb_agg(distinct e.proyecto_id order by e.proyecto_id) as p
                         from public.eventos e
                        where e.fecha between $1 and $2 and e.proyecto_id is not null
                          and coalesce(e.estado, '''') <> ''cancelado''
                        group by e.fecha) x'
        into v_obras using v_min, v_max;
    end if;
    -- (El contexto, solo si algo necesita propuesta: al primero que la pide.
    -- Si todo casó solo, no se lee.)
    v_ctx := null;
    v_firma := fn_banco_firma();
    -- Lo PENDIENTE que cada propuesta mira, por movimiento: el otro lado de
    -- una transferencia (lo pendiente de otra cuenta por el mismo dinero con
    -- el signo contrario, a 10 días), y en las cuentas con partidas de la
    -- apertura, lo pendiente de la cuenta (las sumas). Así importar un mes
    -- nuevo no deja viejas todas las propuestas de antes (ver fn_banco_firma).
    -- (Ronda 4: y en lo que parece dinero entre cuentas propias, las
    -- conciliaciones —las que hay, cuándo se confirmó o reabrió la última—:
    -- su propuesta dice qué reabrir si su fecha dejaría una partida, y
    -- reabrirla la cambia.)
    select count(*) || ':' || coalesce(max(greatest(c.creada_el, c.confirmada_el, c.reabierta_el))::text, '') into v_conc
      from conciliaciones c;
    select coalesce(jsonb_object_agg(x.id, x.h), '{}'::jsonb) into v_contras
      from (select a.id, concat_ws(':', md5(string_agg(b.id::text, ',' order by b.id)),
                                   case when a.tr then v_conc end) as h
              from (select a0.*,
                           (coalesce(a0.tipo_banco, '') = 'XFER' or coalesce(a0.desc_norm ~* v_pat_tr, false)
                            or (v_tipos->>a0.cuenta = 'banco' and a0.monto < 0
                                and (coalesce(a0.desc_norm ~* v_pat_pt, false)
                                     or exists (select 1 from jsonb_each(v_u4) e cross join jsonb_array_elements_text(e.value) as u(u4)
                                                 where a0.desc_norm ~ ('(^| )' || u.u4 || '( |$)'))))
                            or (v_tipos->>a0.cuenta = 'tarjeta' and a0.monto > 0 and coalesce(a0.desc_norm ~* v_pat_pr, false))) as tr
                      from movimientos_banco a0
                     where a0.estado = 'pendiente' and a0.fecha >= v_corte
                       and (p_mov is null or a0.id = p_mov) and (p_cuenta is null or a0.cuenta = p_cuenta)
                       and (p_desde is null or a0.fecha >= p_desde)) a
              left join movimientos_banco b on b.estado = 'pendiente' and b.fecha >= v_corte and b.monto = -a.monto
                                           and b.cuenta <> a.cuenta and b.fecha between a.fecha - 10 and a.fecha + 10
             where b.id is not null or a.tr
             group by a.id, a.tr) x;
    if v_aper then
      select coalesce(jsonb_object_agg(x.cuenta, x.h), '{}'::jsonb) into v_aper_mov
        from (select mm.cuenta, count(*) || ':' || max(mm.importado_el)::text as h
                from movimientos_banco mm
               where mm.estado = 'pendiente' and mm.fecha >= v_corte and mm.cuenta = any (v_cuentas_l)
                 and mm.cuenta in (select c.cuenta from conciliaciones c join conciliacion_partidas pa on pa.conciliacion_id = c.id
                                    where c.tipo = 'apertura' and c.estado = 'confirmada' and pa.lado = 'libro'
                                      and pa.asiento_id is null and pa.resuelta_por_movimiento is null)
               group by mm.cuenta) x;
    end if;
    select count(*) || ':' || coalesce(max(rc.id), 0) into v_rec from recibos rc where rc.contabilizado_en is not null;
    for m in select * from movimientos_banco x
              where x.estado = 'pendiente' and x.fecha >= v_corte
                and (p_mov is null or x.id = p_mov) and (p_cuenta is null or x.cuenta = p_cuenta)
                and (p_desde is null or x.fecha >= p_desde)
                and (p_mov is not null or x.propuesta is null
                     or x.propuesta->>'firma' is distinct from
                        fn_banco_firma_mov(v_firma, v_tipos->>x.cuenta, x.monto, coalesce(x.desc_norm ~* v_pat_cd, false),
                                           v_cands->(x.id::text), fn_banco_obra_de(x, v_obras)::text,
                                           v_contras->>(x.id::text), v_aper_mov->>x.cuenta, v_rec, x.propuesta->'mira',
                                           v_otros->(x.id::text))
                     or ((x.propuesta->>'motivo') = 'posible_duplicado')
                        is distinct from (x.posible_duplicado_de is not null and x.duplicado is null))
              order by (x.propuesta is null) desc, x.fecha desc, x.importado_el desc, x.fila desc loop
      v_fuerza := m.propuesta is null or p_mov is not null;
      if v_hechas > 0 and clock_timestamp() - v_inicio > (case when v_fuerza then v_tope_p else v_tope_r end) then
        v_sin_rehacer := v_sin_rehacer + 1;
        if m.propuesta is null then
          v_sin_propuesta := v_sin_propuesta + 1;
        end if;
        continue;
      end if;
      if v_ctx is null then
        v_ctx := fn_banco_contexto(false);
      end if;
      -- (las facturas abiertas, al primer depósito del banco que las mira:
      -- un «Casar» de la tarjeta no las lee)
      if m.monto > 0 and v_tipos->>m.cuenta = 'banco' and not (v_ctx ? 'facturas') then
        v_ctx := v_ctx || jsonb_build_object('facturas', fn_banco_contexto_facturas());
      end if;
      -- (los proveedores que mira: van en la propuesta, y su firma lleva lo
      -- que se les debe a ellos, no la 2010 entera)
      v_mira := fn_banco_prov_mira(m, v_tipos->>m.cuenta, v_ctx);
      v_fmov := fn_banco_firma_mov(v_firma, v_tipos->>m.cuenta, m.monto, coalesce(m.desc_norm ~* v_pat_cd, false),
                                   v_cands->(m.id::text), fn_banco_obra_de(m, v_obras)::text,
                                   v_contras->>(m.id::text), v_aper_mov->>m.cuenta, v_rec, v_mira, v_otros->(m.id::text));
      v_prop := fn_banco_proponer(m, v_cands->(m.id::text), fn_banco_obra_de(m, v_obras), v_ctx,
                                  v_otros->(m.id::text))
                || jsonb_build_object('firma', v_fmov)
                || case when v_mira is not null then jsonb_build_object('mira', v_mira) else '{}'::jsonb end;
      v_hechas := v_hechas + 1;
      if v_prop is distinct from m.propuesta or (v_prop->>'motivo') is distinct from m.estado_motivo then
        perform fn_banco_marca('movimiento:' || m.id);
        update movimientos_banco set propuesta = v_prop, estado_motivo = v_prop->>'motivo' where id = m.id;
        perform fn_banco_marca(null);
      end if;
    end loop;
  end motor;

  -- LLEGÓ SU TICKET: los cargos clasificados cuyo ticket entró después (ver
  -- fn_banco_tickets_llegados). Se dice en su propuesta (la bandeja los
  -- enseña aunque estén casados): cambiar la clasificación por el ticket, o
  -- decir que es otra compra. Y se quita donde ya no aplica.
  if p_proponer and v_completo then
    select coalesce(jsonb_object_agg(t.movimiento_id, t.c), '{}'::jsonb) into v_llego
      from (select t.movimiento_id,
                   jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                               'asiento_id', t.asiento_id, 'orden', t.orden, 'recibo', t.recibo, 'numero', t.numero, 'fecha', t.fdoc,
                               'otro_total', case when t.linea_monto <> t.monto and t.repartido is null then -t.linea_monto end,
                               -- (ronda 4: la parte de un ticket repartido entre obras)
                               'repartido', t.repartido, 'obras', t.obras,
                               'parte', case when t.repartido is not null then -t.linea_monto end))
                             order by (t.linea_monto <> t.monto and t.repartido is null), t.repartido nulls first, t.fdoc, t.numero) as c
              from fn_banco_tickets_llegados(case when p_cuenta is not null then array[p_cuenta] end, p_mov) t
             where p_desde is null or t.fecha >= p_desde
             group by t.movimiento_id) t;
    for m in select * from movimientos_banco x
              where x.id in (select k::uuid from jsonb_object_keys(v_llego) k)
                 or (x.propuesta->>'motivo' = 'llego_su_ticket' and x.fecha >= v_corte
                     and (p_mov is null or x.id = p_mov) and (p_cuenta is null or x.cuenta = p_cuenta)
                     and (p_desde is null or x.fecha >= p_desde)) loop
      if v_llego ? m.id::text then
        -- (Ronda 4: el ticket REPARTIDO entre obras —la misma foto en varios
        -- recibos— cuyas partes suman el cargo se dice como tal, y su botón
        -- «Es su ticket (repartido)» va primero: cambia la clasificación por
        -- todas sus partes. Antes cada parte salía como un ticket de OTRO
        -- total, «Es su ticket» se negaba y el único botón dejaba el gasto
        -- dos veces.)
        select string_agg(g.txt, '; ' order by g.rep), jsonb_agg(g.op order by g.rep) into v_rep, v_rep_op
          from (select t->>'repartido' as rep,
                       format('repartido entre %s (la misma foto: %s, que suman %s)',
                              case when max((t->>'obras')::int) >= 2 then format('%s obras', max((t->>'obras')::int))
                                   else format('%s partes', count(*)) end,
                              string_agg(format('el recibo %s del %s por %s', t->>'recibo', t->>'fecha', t->>'parte'), ' y '
                                         order by t->>'fecha', (t->>'recibo')),
                              -m.monto) as txt,
                       jsonb_build_object(
                         'texto', format('Es su ticket (repartido entre %s): los recibos %s, la misma foto',
                                         case when max((t->>'obras')::int) >= 2 then format('%s obras', max((t->>'obras')::int))
                                              else format('%s partes', count(*)) end,
                                         replace(t->>'repartido', ',', ', ')),
                         'llamar', 'fn_banco_casar_con',
                         'args', jsonb_build_object('p_movimiento', m.id,
                                                    'p_con', jsonb_build_object('lineas', jsonb_agg(
                                                      jsonb_build_object('asiento_id', t->'asiento_id', 'orden', t->'orden')
                                                      order by t->>'fecha', (t->>'recibo'))))) as op
                  from jsonb_array_elements(v_llego->(m.id::text)) t
                 where t ? 'repartido'
                 group by t->>'repartido') g;
        v_prop := jsonb_build_object(
          'motivo', 'llego_su_ticket', 'regla', 'R1',
          'texto', case when v_rep is not null
                        then format('Llegó su ticket, %s, DESPUÉS de clasificar este cargo: el gasto está dos veces en el libro (lo '
                                    'que clasificaste y el ticket). Si es su ticket, cámbialo: la clasificación se reversa y el cargo '
                                    'casa con sus partes, cada una en su obra. Si es otra compra del mismo monto, dilo con su motivo.',
                                    v_rep)
                        else 'Llegó el ticket de este cargo DESPUÉS de clasificarlo: el gasto está dos veces en el libro (lo que '
                             'clasificaste y el ticket). Si es su ticket, cámbialo: la clasificación se reversa y el cargo casa con el '
                             'ticket. Si es otra compra del mismo monto, dilo con su motivo.' end
                   -- (el de OTRO total: el banco nombra su comercio; no se cambia
                   -- hasta que su total sea el del banco)
                   -- (solo si hay alguno: antes, sin ninguno, la frase salía
                   -- vacía —«con OTRO total:  (el banco dice …)»— también en
                   -- el ticket del mismo monto)
                   || coalesce((select format(' Del mismo comercio, con OTRO total: %s (el banco dice %s): ¿se leyó sin el tax, o '
                                              'mal? Corrige su total en la app (✎) y aquí saldrá para cambiarlo.',
                                              string_agg(format('el recibo %s del %s por %s', t->>'recibo', t->>'fecha',
                                                                t->>'otro_total'), '; '), -m.monto)
                                  from jsonb_array_elements(v_llego->(m.id::text)) t where t ? 'otro_total'
                                having count(*) > 0), ''),
          'tickets', v_llego->(m.id::text),
          'opciones', coalesce(v_rep_op, '[]'::jsonb)
                      || coalesce((select jsonb_agg(jsonb_build_object(
                                'texto', format('Es su ticket: el recibo %s del %s (%s)', t->>'recibo', t->>'fecha', t->>'numero'),
                                'llamar', 'fn_banco_casar_con',
                                'args', jsonb_build_object('p_movimiento', m.id,
                                                           'p_con', jsonb_build_object('lineas', jsonb_build_array(
                                                             jsonb_build_object('asiento_id', t->'asiento_id', 'orden', t->'orden'))))))
                         from jsonb_array_elements(v_llego->(m.id::text)) t
                        where not (t ? 'otro_total') and not (t ? 'repartido')), '[]'::jsonb)
                      -- (con su motivo: la función lo pide, y el botón lo dice
                      -- como las demás opciones que lo piden —pide_motivo y el
                      -- nombre del argumento—; antes, pulsado con sus argumentos
                      -- tal cual, fallaba)
                      || jsonb_build_array(jsonb_build_object('texto', 'No es su ticket: es otra compra (con su motivo)',
                                                              'llamar', 'fn_banco_duplicado', 'pide_motivo', true,
                                                              'pide', jsonb_build_array('p_motivo'),
                                                              'args', jsonb_build_object('p_movimiento', m.id, 'p_es_el_mismo', false))))
          || case when m.propuesta ? 'descartados' then jsonb_build_object('descartados', m.propuesta->'descartados')
                  else '{}'::jsonb end
          -- (y lo que Edgar dijo de la apertura: ronda 4)
          || jsonb_strip_nulls(jsonb_build_object('apertura_no', m.propuesta->'apertura_no',
                                                  'apertura_no_motivo', m.propuesta->'apertura_no_motivo'));
        v_n_llego := v_n_llego + 1;
      else
        v_prop := nullif(jsonb_strip_nulls(jsonb_build_object('descartados', m.propuesta->'descartados',
                                                              'apertura_no', m.propuesta->'apertura_no',
                                                              'apertura_no_motivo', m.propuesta->'apertura_no_motivo')),
                         '{}'::jsonb);
      end if;
      if v_prop is distinct from m.propuesta then
        perform fn_banco_marca('movimiento:' || m.id);
        update movimientos_banco set propuesta = v_prop where id = m.id;
        perform fn_banco_marca(null);
      end if;
    end loop;
  end if;

  if v_antes = 0 then
    return jsonb_strip_nulls(jsonb_build_object('pendientes_antes', 0, 'casados', v_n_aper, 'pendientes', 0, 'por_motivo', '{}'::jsonb,
                                                'por_regla', case when v_n_aper > 0 then jsonb_build_object('apertura', v_n_aper) end,
                                                'propuestas', 0, 'completo', true,
                                                'llego_su_ticket', case when v_n_llego > 0 then v_n_llego end));
  end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'pendientes_antes', v_antes,
    'casados', v_n_papel + v_n_cruce + v_n_grupo + v_n_cobros + v_n_aper + 2 * v_n_trans + v_n_regla,
    'por_regla', jsonb_build_object('papel_con_su_movimiento', v_n_papel, 'cruce_exacto', v_n_cruce, 'ticket_repartido', v_n_grupo,
                                    'cobros_sumados', v_n_cobros, 'apertura', v_n_aper, 'transferencias', v_n_trans,
                                    'reglas_fijas', v_n_regla),
    'pendientes', (select count(*) from movimientos_banco x
                    where x.estado = 'pendiente' and x.fecha >= v_corte
                      and (p_mov is null or x.id = p_mov) and (p_cuenta is null or x.cuenta = p_cuenta)
                      and (p_desde is null or x.fecha >= p_desde)),
    'por_motivo', (select coalesce(jsonb_object_agg(y.motivo, y.n), '{}'::jsonb)
                     from (select coalesce(x.estado_motivo, 'sin_motivo') as motivo, count(*) as n
                             from movimientos_banco x
                            where x.estado = 'pendiente' and x.fecha >= v_corte
                              and (p_mov is null or x.id = p_mov) and (p_cuenta is null or x.cuenta = p_cuenta)
                              and (p_desde is null or x.fecha >= p_desde)
                            group by 1) y),
    'llego_su_ticket', case when v_n_llego > 0 then v_n_llego end,
    'propuestas', v_hechas,
    'completo', v_completo and v_sin_propuesta = 0,
    'propuestas_sin_rehacer', case when v_sin_rehacer > 0 then v_sin_rehacer end,
    'siguiente', case when not v_completo or v_sin_propuesta > 0
                      then 'Se acabó el tiempo de esta llamada (la API corta a los 8 s): lo casado queda. Vuelve a llamar a '
                           'fn_banco_casar_todo para seguir donde quedó.' end,
    'ms', round(extract(epoch from clock_timestamp() - v_inicio) * 1000)));
end $$;
revoke execute on function public.fn_banco_casar_interno(text, date, uuid, boolean) from public, anon, authenticated, service_role;

-- El movimiento como lo ve la app tras una acción (lo que devuelven las
-- funciones de la app).
create or replace function public.fn_banco_resumen(p_mov uuid)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  select jsonb_strip_nulls(jsonb_build_object(
           'movimiento', m.id, 'cuenta', m.cuenta, 'fecha', m.fecha, 'monto', m.monto, 'descripcion', m.descripcion,
           'estado', m.estado, 'motivo', m.estado_motivo, 'clase', m.casado_clase, 'referencia', m.casado_ref,
           'regla', m.casado_regla, 'automatico', m.casado_auto,
           'asiento', (select a.numero from asientos a where a.id = m.asiento_id), 'asiento_id', m.asiento_id,
           'propuesta', m.propuesta))
    from movimientos_banco m where m.id = p_mov
$$;
revoke execute on function public.fn_banco_resumen(uuid) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_banco_casar(movimiento) — casa UNO (lo que casa solo) o deja su
-- propuesta. Lo que conta.js llama al abrir un movimiento de la bandeja.
--   _rpc('fn_banco_casar', { p_movimiento: '…' })
-- fn_banco_casar_todo(cuenta?, desde?) — todo lo pendiente (de una cuenta,
-- desde una fecha). Lo que conta.js llama después de importar, y el botón
-- «Casar lo seguro». Devuelve cuántos casó y por qué regla, y lo que quedó
-- por motivo (los contadores de la bandeja).
--   _rpc('fn_banco_casar_todo', { p_cuenta: '1010', p_desde: '2026-10-01' })
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_casar(p_movimiento uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_res jsonb;
begin
  perform fn_banco_exigir_dueno();
  if not exists (select 1 from movimientos_banco where id = p_movimiento) then
    raise exception using errcode = '22023', message = 'No existe ese movimiento del banco.';
  end if;
  v_res := fn_banco_casar_interno(null, null, p_movimiento, true);
  return fn_banco_resumen(p_movimiento) || jsonb_build_object('casar', v_res);
end $$;
revoke execute on function public.fn_banco_casar(uuid) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_casar(uuid) to authenticated;

create or replace function public.fn_banco_casar_todo(p_cuenta text default null, p_desde date default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_c text := fn_banco_cuenta_resolver(p_cuenta);
begin
  perform fn_banco_exigir_dueno();
  -- (La cuenta como la dice Edgar: la del plan o su código corto, '2013',
  -- como la acepta el importador.)
  if p_cuenta is not null and fn_banco_tipo_cuenta(v_c) is null then
    raise exception using errcode = 'MX004', message = format('%s no es una cuenta de banco ni una tarjeta de la empresa.', p_cuenta);
  end if;
  return fn_banco_casar_interno(v_c, p_desde, null, true);
end $$;
revoke execute on function public.fn_banco_casar_todo(text, date) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_casar_todo(text, date) to authenticated;
-- =====================================================================
-- 5 · LO QUE RESUELVE EDGAR (la bandeja del banco): cada función toma el
--     candado del casado y la fila del movimiento, mira que siga
--     pendiente, y deja su casado con su regla («Edgar eligió»), quién y
--     cuándo. Todas SECURITY DEFINER (escriben lo que la API no escribe y
--     postean por la puerta interna de c2), con es_dueno() por dentro, y
--     en el reparto de c2 (c_fn_app_fases) y sus huellas.
-- =====================================================================

-- Toma el movimiento para resolverlo: el candado del casado, su fila, y
-- que se pueda (pendiente, desde el corte, sin un «posible duplicado» por
-- decir).
create or replace function public.fn_banco_tomar(p_movimiento uuid, p_duplicado boolean default false)
returns public.movimientos_banco
language plpgsql
set search_path = public, pg_temp
as $$
declare
  m movimientos_banco;
begin
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  select * into m from movimientos_banco where id = p_movimiento for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese movimiento del banco.';
  end if;
  if m.estado <> 'pendiente' then
    raise exception using errcode = 'MX008',
      message = format('El movimiento del %s por %s (%s) ya está %s%s: si estaba mal, primero se des-casa (fn_banco_descasar, con '
                       'su motivo).', m.fecha, m.monto, coalesce(m.descripcion, ''), m.estado,
                       coalesce(' (' || m.casado_regla || ')', coalesce(' (' || m.estado_motivo || ')', '')));
  end if;
  if m.fecha < fn_puente_corte() then
    raise exception using errcode = 'MX002',
      message = format('El movimiento del %s es de antes del corte (%s): está en QuickBooks.', m.fecha, fn_puente_corte());
  end if;
  if not p_duplicado and m.posible_duplicado_de is not null and m.duplicado is null then
    raise exception using errcode = 'MX008',
      message = 'Ese movimiento puede ser el mismo que otro que ya entró (por Plaid o por archivo): primero di si lo es '
                '(fn_banco_duplicado).';
  end if;
  return m;
end $$;
revoke execute on function public.fn_banco_tomar(uuid, boolean) from public, anon, authenticated, service_role;

-- Las líneas libres de un asiento en la cuenta del movimiento.
create or replace function public.fn_banco_lineas_de(p_asiento uuid, p_cuenta text)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  select jsonb_agg(jsonb_build_object('asiento_id', l.asiento_id, 'orden', l.orden) order by l.orden)
    from asiento_lineas l
   where l.asiento_id = p_asiento and l.cuenta = p_cuenta
     and not exists (select 1 from banco_casado_lineas cl where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente)
$$;
revoke execute on function public.fn_banco_lineas_de(uuid, text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_banco_casar_con(movimiento, con, motivo) — «Confirmar cruce»: Edgar
-- elige con qué casa (lo que la propuesta enseña, o lo que él sabe):
--   {"lineas": [{"asiento_id": "…", "orden": 2}, …]}  esas líneas del libro
--                              (varias: los cobros que suman un depósito)
--   {"asiento": "…"}           las líneas libres de ese asiento en la cuenta
--   {"recibo": 123}            el asiento vivo de ese recibo
--   {"cobro": "…"}             el de ese cobro (y escribe su movimiento_id)
--   {"partida_apertura": "…"}  una partida en tránsito de la apertura
--   {"movimiento": "…"}        el otro lado de una transferencia (los dos
--                              pendientes): un asiento, los dos casados
-- Las líneas suman el movimiento al centavo y son de su cuenta. No mira la
-- ventana del cruce: lo decide Edgar (queda dicho en la regla). El otro
-- lado de una transferencia ya posteada casa con ESE asiento (si llegó con
-- fecha anterior a la del asiento, el asiento se rehace con ella).
-- LLEGÓ SU TICKET: con un cargo ya CLASIFICADO (fn_banco_clasificar) y su
-- ticket (el recibo, sus líneas o su asiento), cambia la clasificación por
-- el ticket: la reversa (con su motivo) y casa el cargo con el ticket. El
-- gasto queda una vez. Dentro de una conciliación confirmada, no (se
-- reabre antes).
-- ---------------------------------------------------------------------
-- (El cambio de una clasificación por su ticket, interno: lo llaman
-- fn_banco_casar_con y fn_banco_duplicado.)
create or replace function public.fn_banco_cambiar_por_ticket(p_mov uuid, p_con jsonb, p_motivo text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  m       movimientos_banco;
  v_conc  conciliaciones;
  v_ases  uuid;
  v_lin   jsonb;
  v_rec   text;
  v_mal   text;
  v_res   jsonb;
begin
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  select * into m from movimientos_banco where id = p_mov for update;
  if not found or m.estado <> 'casado' or m.casado_clase is distinct from 'clasificado' then
    raise exception using errcode = 'MX008', message = 'Solo un cargo ya clasificado cambia su clasificación por su ticket.';
  end if;
  select * into v_conc from conciliaciones cc
   where cc.cuenta = m.cuenta and cc.estado = 'confirmada' and cc.fecha_corte >= m.fecha
   order by cc.fecha_corte limit 1;
  if found then
    raise exception using errcode = 'MX008',
      message = format('La conciliación de %s al %s está confirmada con este cargo: reábrela antes (fn_conciliacion_reabrir, con su '
                       'motivo), cambia la clasificación por el ticket y vuelve a conciliar.', v_conc.cuenta, v_conc.fecha_corte);
  end if;
  if p_con ? 'lineas' then
    v_lin := p_con->'lineas';
    if jsonb_typeof(v_lin) is distinct from 'array' or jsonb_array_length(v_lin) = 0 then
      raise exception using errcode = '22023', message = 'lineas es una lista de {asiento_id, orden}.';
    end if;
    v_ases := (v_lin->0->>'asiento_id')::uuid;
  elsif p_con ? 'asiento' then
    v_ases := (p_con->>'asiento')::uuid;
    v_lin := fn_banco_lineas_de(v_ases, m.cuenta);
  else
    select r.contabilizado_en into v_ases from recibos r
     where r.id = (case when p_con->>'recibo' ~ '^-?[0-9]{1,18}$' then (p_con->>'recibo')::bigint end);
    v_lin := fn_banco_lineas_de(v_ases, m.cuenta);
  end if;
  select string_agg(format('%s/%s', x.asiento_id, x.orden), ', ') into v_mal
    from jsonb_to_recordset(coalesce(v_lin, '[]'::jsonb)) as x(asiento_id uuid, orden int)
    left join asientos a on a.id = x.asiento_id
   where a.origen_tabla is distinct from 'recibos';
  if v_lin is null or v_mal is not null then
    raise exception using errcode = 'MX008',
      message = 'Una clasificación solo la sustituye su ticket (un recibo de la app ya en el libro, con su línea libre en esta cuenta).';
  end if;
  -- (Ronda 4: el ticket repartido entre obras trae las líneas de varios
  -- recibos —la misma foto—: el casado los nombra todos, como R1: 110,111)
  select string_agg(x.oid, ',' order by x.n, x.oid) into v_rec
    from (select distinct a.origen_id as oid, case when a.origen_id ~ '^-?[0-9]{1,18}$' then a.origen_id::bigint end as n
            from jsonb_to_recordset(v_lin) as y(asiento_id uuid, orden int)
            join asientos a on a.id = y.asiento_id) x;
  v_res := fn_banco_descasar_interno(m.id,
             coalesce(fn_banco_limpio(p_motivo) || ' · ', '')
             || format('Llegó su ticket (%s %s): la clasificación se reversa y el cargo casa con el ticket.',
                       case when v_rec like '%,%' then 'repartido entre obras, los recibos' else 'recibo' end, v_rec));
  perform fn_banco_casar_lineas(m.id, 'recibo', v_rec, v_ases, v_lin,
                                'R1 llegó su ticket: sustituye la clasificación (Edgar lo confirmó)', false, false, p_motivo);
  return fn_banco_resumen(p_mov) || jsonb_strip_nulls(jsonb_build_object('reverso', v_res->>'reverso',
                                                                         'deshecho', 'clasificado'));
end $$;
revoke execute on function public.fn_banco_cambiar_por_ticket(uuid, jsonb, text) from public, anon, authenticated, service_role;

create or replace function public.fn_banco_casar_con(p_movimiento uuid, p_con jsonb, p_motivo text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m       movimientos_banco;
  m2      movimientos_banco;
  v_sobra text;
  v_ases  uuid;
  v_lin   jsonb;
  v_clase text;
  v_ref   text;
  v_res   jsonb;
  v_pa    conciliacion_partidas;
  v_cobro cobros;
  v_resto numeric;
  v_otros jsonb;
  v_suma2 numeric;
  v_x     text;
  v_trf   jsonb;
  v_com   numeric;
  v_fee   text;
  v_q     prestamo_cuotas;
  v_p     prestamos;
begin
  perform fn_banco_exigir_dueno();
  if p_con is null or jsonb_typeof(p_con) <> 'object' then
    raise exception using errcode = '22023', message = 'Con qué casa, como objeto JSON (lineas, asiento, recibo, cobro, partida_apertura o movimiento).';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(p_con) k
   where k not in ('lineas', 'asiento', 'recibo', 'cobro', 'partida_apertura', 'movimiento', 'movimientos', 'comision', 'corrige',
                   'cuota', 'diferencia');
  if v_sobra is not null
     or (select count(*) from jsonb_object_keys(p_con) k where k not in ('movimientos', 'comision', 'corrige', 'diferencia')) <> 1
     or (p_con ? 'movimientos' and not p_con ? 'partida_apertura')
     or ((p_con ? 'comision' or p_con ? 'corrige') and not p_con ? 'cobro')
     or (p_con ? 'comision' and p_con ? 'corrige')
     or (p_con ? 'diferencia' and not p_con ? 'cuota') then
    raise exception using errcode = '22023',
      message = 'Con qué casa: UNA de lineas, asiento, recibo, cobro, cuota, partida_apertura o movimiento (con partida_apertura, '
                'también movimientos: los otros movimientos que la suman con este; con cobro, su comision —el cobro con tarjeta '
                'depositado neto— o corrige —el cobro anotado por otro monto, con su motivo—; con cuota, su diferencia: '
                'capital o interes).';
  end if;
  -- Llegó su ticket: el cargo ya clasificado cambia la clasificación por él.
  select * into m from movimientos_banco where id = p_movimiento;
  if found and m.estado = 'casado' and m.casado_clase = 'clasificado' and (p_con ?| array['lineas', 'asiento', 'recibo']) then
    return fn_banco_cambiar_por_ticket(p_movimiento, p_con, p_motivo);
  end if;
  -- Una partida en tránsito de la apertura que el banco trajo ANTES del
  -- corte (ignorada al entrar: el statement de la tarjeta, o del banco,
  -- cortó antes del 30-sep): casa con su partida, sin tocar el libro (ver
  -- fn_banco_apertura_previas). Antes: «ya está ignorado… primero se
  -- des-casa», y des-casarlo decía «es de antes del corte»: un círculo.
  if found and p_con ? 'partida_apertura' and not p_con ? 'movimientos' and m.estado = 'ignorado'
     and m.fecha < fn_puente_corte() and m.duplicado is null and m.monto <> 0
     and not exists (select 1 from archivos_banco a where a.id = m.archivo_id and a.retirado_el is not null) then
    perform pg_advisory_xact_lock(820261001, hashtext('casar'));
    select * into m from movimientos_banco where id = p_movimiento for update;
    select pa.* into v_pa
      from conciliacion_partidas pa join conciliaciones c on c.id = pa.conciliacion_id
     where pa.id = (case when p_con->>'partida_apertura' ~ '^[0-9a-fA-F-]{36}$' then (p_con->>'partida_apertura')::uuid end)
       and c.tipo = 'apertura' and c.estado = 'confirmada' and c.cuenta = m.cuenta
       and pa.lado = 'libro' and pa.asiento_id is null and pa.clase <> 'error'
     for update of pa;
    if not found then
      raise exception using errcode = 'MX008',
        message = 'Esa no es una partida en tránsito de la apertura de esta cuenta (la conciliación de apertura tiene que estar '
                  'confirmada).';
    end if;
    select v_pa.monto - coalesce(sum(mm.monto), 0) into v_resto
      from banco_casados bc join movimientos_banco mm on mm.id = bc.movimiento_id
     where bc.clase = 'apertura' and bc.deshecho_el is null and bc.referencia = v_pa.id::text;
    if v_resto <> m.monto
       or (v_pa.cheque is not null and fn_banco_cheque_num(m.cheque, m.descripcion) is not null
           and fn_banco_cheque_num(m.cheque, m.descripcion) <> nullif(ltrim(v_pa.cheque, '0'), '')) then
      raise exception using errcode = 'MX008',
        message = format('No cuadra con la partida en tránsito de la apertura (%s del %s): faltan %s de ella y el movimiento (del %s, '
                         'antes del corte) es de %s%s.', coalesce(v_pa.descripcion, 'la partida'), v_pa.fecha, v_resto, m.fecha,
                         m.monto, case when v_pa.cheque is not null then format(', y ella es el cheque %s', v_pa.cheque) else '' end);
    end if;
    perform fn_banco_casar_lineas(m.id, 'apertura', v_pa.id::text, null, '[]'::jsonb,
                                  'Apertura: Edgar casó la partida en tránsito del 30-sep con el movimiento que el banco trajo antes '
                                  'del corte (estaba ignorado)', false, false, p_motivo);
    return fn_banco_resumen(p_movimiento);
  end if;
  m := fn_banco_tomar(p_movimiento);

  -- (Ronda 4) LA CUOTA DEL PRÉSTAMO YA REGISTRADA (con el statement, antes
  -- que el banco) y el cargo por OTRO monto: la cuota redondeada (1,050.00
  -- por 1,029.33) o con un recargo. Es esa cuota: se anula (su asiento se
  -- reversa) y se registra otra vez con este cargo, con la diferencia a
  -- capital (lo pagado de más) o a interés (el recargo), y casada con él.
  -- Por el mismo monto, casa con su asiento sin más.
  if p_con ? 'cuota' then
    select q.* into v_q from prestamo_cuotas q
     where q.id = (case when p_con->>'cuota' ~ '^[0-9a-fA-F-]{36}$' then (p_con->>'cuota')::uuid end)
     for update;
    if not found or v_q.anulada_el is not null or v_q.movimiento_id is not null then
      raise exception using errcode = 'MX008', message = 'Esa cuota no existe, está anulada o ya tiene su cargo del banco.';
    end if;
    select p.* into v_p from prestamos p where p.id = v_q.prestamo_id;
    if m.monto >= 0 or v_p.cuenta_banco is distinct from m.cuenta or abs(v_q.fecha - m.fecha) > 10 then
      raise exception using errcode = 'MX008',
        message = format('La cuota de %s del %s se paga desde %s y a 10 días o menos de su fecha: este movimiento (%s %s, %s) no es '
                         'su cargo.', v_p.prestamista, v_q.fecha, v_p.cuenta_banco, m.cuenta, m.fecha, m.monto);
    end if;
    if -m.monto = v_q.monto then
      return fn_banco_casar_con(p_movimiento, jsonb_build_object('asiento', v_q.asiento_id), p_motivo);
    end if;
    v_com := -m.monto - v_q.monto;
    if coalesce(p_con->>'diferencia', '') not in ('capital', 'interes')
       or (p_con->>'diferencia' = 'capital' and v_q.capital + v_com < 0)
       or (p_con->>'diferencia' = 'interes' and v_q.interes + v_com < 0) then
      raise exception using errcode = 'MX008',
        message = format('El banco cobró %s y la cuota está registrada por %s: di a dónde va la diferencia (%s): "diferencia": '
                         '"capital" (lo pagado de más) o "interes" (un recargo), según el statement del prestamista. Si el statement '
                         'reparte otra cosa, des-cásala y regístrala con sus cifras.', -m.monto, v_q.monto, v_com);
    end if;
    perform fn_reversar_interno(v_q.asiento_id,
                                format('El banco cobró %s y no %s: la cuota se registra otra vez con su cargo (la diferencia a %s)',
                                       -m.monto, v_q.monto, p_con->>'diferencia'),
                                'reverso', jsonb_build_object('funcion', 'fn_banco_casar_con', 'cuota', v_q.id, 'movimiento', m.id));
    perform fn_banco_marca('cuota:' || v_q.id);
    update prestamo_cuotas
       set anulada_motivo = format('El banco cobró %s (no %s) el %s: se registra otra vez con su cargo', -m.monto, v_q.monto, m.fecha)
     where id = v_q.id;
    perform fn_banco_marca(null);
    return fn_prestamo_cuota(v_p.id, m.id, null, null,
                             (v_q.capital + case when p_con->>'diferencia' = 'capital' then v_com else 0 end)::text,
                             (v_q.interes + case when p_con->>'diferencia' = 'interes' then v_com else 0 end)::text,
                             coalesce(fn_banco_limpio(p_motivo),
                                      format('La cuota del %s (registrada por %s), con el cargo del banco: la diferencia (%s) a %s',
                                             v_q.fecha, v_q.monto, v_com, p_con->>'diferencia')))
           || jsonb_build_object('anulada', v_q.id);
  end if;

  if p_con ? 'movimiento' then
    -- La transferencia con sus dos lados.
    select * into m2 from movimientos_banco where id = (p_con->>'movimiento')::uuid for update;
    if not found or m2.estado <> 'pendiente' or m2.cuenta = m.cuenta or m2.monto <> -m.monto
       or not fn_banco_es_propia(m.cuenta) or not fn_banco_es_propia(m2.cuenta) then
      raise exception using errcode = 'MX008',
        message = 'El otro lado de una transferencia es un movimiento pendiente de OTRA cuenta propia por el mismo monto con el '
                  'signo contrario.';
    end if;
    if m.monto > 0 then   -- el asiento sale del lado que sale
      v_ases := m.id; m := m2; m2 := (select x from movimientos_banco x where x.id = v_ases);
    end if;
    -- (su fecha, nunca dentro de una conciliación confirmada de sus
    -- cuentas: fn_banco_tr_fecha)
    v_trf := fn_banco_tr_fecha(m.fecha, m.cuenta, m2.fecha, m2.cuenta, m.monto);
    if v_trf ? 'bloqueo' then
      raise exception using errcode = 'MX008', message = format('No se casa todavía: %s.', v_trf->>'bloqueo');
    end if;
    v_res := fn_banco_asiento('movimientos_banco', m.id::text, (v_trf->>'fecha')::date,
               format('Transferencia entre cuentas propias: %s → %s (%s)', m.cuenta, m2.cuenta, coalesce(m.descripcion, '')),
               jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', m.cuenta, 'monto', m.monto::text,
                                                                      'memo', left(m.descripcion, 200))),
                                 jsonb_strip_nulls(jsonb_build_object('cuenta', m2.cuenta, 'monto', m2.monto::text,
                                                                      'memo', left(m2.descripcion, 200)))),
               fn_banco_proc(m, 'fn_banco_casar_con', 'R3 transferencia (Edgar eligió los dos lados)')
               || jsonb_strip_nulls(jsonb_build_object('otro_lado', fn_banco_proc(m2, 'fn_banco_casar_con', 'R3')->'movimiento',
                                                       'motivo_edgar', fn_banco_limpio(p_motivo), 'fecha_nota', v_trf->>'nota',
                                                       'fecha_por', v_trf->'por')));
    perform fn_banco_casar_lineas(m.id, 'transferencia', m2.id::text, (v_res->>'id')::uuid,
                                  jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 1)),
                                  'R3 transferencia: Edgar eligió los dos lados', false, true, p_motivo);
    perform fn_banco_casar_lineas(m2.id, 'transferencia', m.id::text, (v_res->>'id')::uuid,
                                  jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 2)),
                                  'R3 transferencia: Edgar eligió los dos lados', false, false, p_motivo);
    return fn_banco_resumen(p_movimiento);
  end if;

  if p_con ? 'partida_apertura' then
    -- Una partida en tránsito de la apertura (lo que QuickBooks tenía al
    -- 30-sep): este movimiento por lo que falta de ella; o este y OTROS
    -- pendientes de la cuenta que la suman («movimientos»: el depósito del
    -- 30 que el banco trajo en dos), cada uno con su casado; o, con su
    -- motivo escrito, una parte (el resto llegará en otro). Antes solo el
    -- mismo monto, uno a uno: el depósito partido no tenía cómo casar y la
    -- bandeja llevaba a meterlo otra vez como un aporte.
    select pa.* into v_pa
      from conciliacion_partidas pa join conciliaciones c on c.id = pa.conciliacion_id
     where pa.id = (case when p_con->>'partida_apertura' ~ '^[0-9a-fA-F-]{36}$' then (p_con->>'partida_apertura')::uuid end)
       and c.tipo = 'apertura' and c.estado = 'confirmada' and c.cuenta = m.cuenta
       and pa.lado = 'libro' and pa.asiento_id is null and pa.clase <> 'error'
     for update of pa;
    if not found then
      raise exception using errcode = 'MX008',
        message = 'Esa no es una partida en tránsito de la apertura de esta cuenta (la conciliación de apertura tiene que estar '
                  'confirmada).';
    end if;
    select v_pa.monto - coalesce(sum(mm.monto), 0) into v_resto
      from banco_casados bc join movimientos_banco mm on mm.id = bc.movimiento_id
     where bc.clase = 'apertura' and bc.deshecho_el is null and bc.referencia = v_pa.id::text;
    v_otros := '[]'::jsonb;
    if p_con ? 'movimientos' then
      if jsonb_typeof(p_con->'movimientos') is distinct from 'array' or jsonb_array_length(p_con->'movimientos') = 0 then
        raise exception using errcode = '22023', message = 'movimientos es una lista de los otros movimientos (sus id) que suman la partida.';
      end if;
      for v_x in select distinct x.v from jsonb_array_elements_text(p_con->'movimientos') as x(v) where x.v <> m.id::text loop
        m2 := fn_banco_tomar(case when v_x ~ '^[0-9a-fA-F-]{36}$' then v_x::uuid end);
        if m2.cuenta <> m.cuenta or sign(m2.monto) <> sign(m.monto) then
          raise exception using errcode = 'MX008',
            message = format('El movimiento del %s por %s no es de %s o va en el otro sentido: no suma esta partida.', m2.fecha, m2.monto,
                             m.cuenta);
        end if;
        v_otros := v_otros || jsonb_build_array(m2.id);
        v_suma2 := coalesce(v_suma2, 0) + m2.monto;
      end loop;
    end if;
    if m.monto + coalesce(v_suma2, 0) = v_resto then
      null;   -- exacto: lo que falta de la partida
    elsif jsonb_array_length(v_otros) = 0 and sign(m.monto) = sign(v_resto) and abs(m.monto) < abs(v_resto)
          and v_pa.cheque is null and fn_banco_limpio(p_motivo) is not null then
      null;   -- una parte, con su motivo
    else
      raise exception using errcode = 'MX008',
        message = format('No cuadra con la partida en tránsito de la apertura (%s del %s): faltan %s de ella y %s %s. Si el banco la '
                         'trajo en partes, casa juntos los movimientos que la suman ({"partida_apertura": "…", "movimientos": '
                         '[los otros]}), o esta parte sola con su motivo escrito.', coalesce(v_pa.descripcion, 'la partida'),
                         v_pa.fecha, v_resto, case when jsonb_array_length(v_otros) > 0 then 'estos movimientos suman' else 'el movimiento es de' end,
                         m.monto + coalesce(v_suma2, 0));
    end if;
    perform fn_banco_casar_lineas(m.id, 'apertura', v_pa.id::text, null, '[]'::jsonb,
                                  case when jsonb_array_length(v_otros) > 0
                                       then 'Apertura: Edgar eligió la partida en tránsito del 30-sep (llegó en varios movimientos)'
                                       when m.monto <> v_resto
                                       then 'Apertura: Edgar eligió la partida en tránsito del 30-sep (una parte, con su motivo)'
                                       else 'Apertura: Edgar eligió la partida en tránsito del 30-sep' end,
                                  false, false, p_motivo);
    for v_x in select x.v from jsonb_array_elements_text(v_otros) as x(v) loop
      perform fn_banco_casar_lineas(v_x::uuid, 'apertura', v_pa.id::text, null, '[]'::jsonb,
                                    'Apertura: Edgar eligió la partida en tránsito del 30-sep (llegó en varios movimientos)',
                                    false, false, p_motivo);
    end loop;
    return fn_banco_resumen(p_movimiento)
           || case when jsonb_array_length(v_otros) > 0 then jsonb_build_object('tambien', v_otros) else '{}'::jsonb end;
  end if;

  if p_con ? 'lineas' then
    v_lin := p_con->'lineas';
    if jsonb_typeof(v_lin) is distinct from 'array' or jsonb_array_length(v_lin) = 0 then
      raise exception using errcode = '22023', message = 'lineas es una lista de {asiento_id, orden}.';
    end if;
    v_ases := (v_lin->0->>'asiento_id')::uuid;
  elsif p_con ? 'asiento' then
    v_ases := (p_con->>'asiento')::uuid;
    v_lin := fn_banco_lineas_de(v_ases, m.cuenta);
  elsif p_con ? 'recibo' then
    select r.contabilizado_en into v_ases from recibos r
     where r.id = (case when p_con->>'recibo' ~ '^-?[0-9]{1,18}$' then (p_con->>'recibo')::bigint end);
    if v_ases is null then
      raise exception using errcode = 'MX008', message = format('El recibo %s no está en el libro (míralo en la bandeja de los puentes).',
                                                                p_con->>'recibo');
    end if;
    v_lin := fn_banco_lineas_de(v_ases, m.cuenta);
  else
    select c.* into v_cobro from cobros c where c.id = (p_con->>'cobro')::uuid;
    if not found or v_cobro.estado <> 'vigente' or v_cobro.contabilizado_en is null then
      raise exception using errcode = 'MX008', message = 'Ese cobro no existe, está anulado o no está en el libro.';
    end if;
    if v_cobro.movimiento_id is not null and v_cobro.movimiento_id <> m.id::text then
      raise exception using errcode = 'MX008',
        message = format('Ese cobro ya está casado con otro movimiento del banco (%s): el mismo dinero no entra dos veces.',
                         v_cobro.movimiento_id);
    end if;
    -- (Ronda 4) EL COBRO ANOTADO POR OTRO MONTO (el cheque anotado por
    -- 2,500.00 que era de 2,050.00): «corrige», con su motivo, lo anula y
    -- registra el bueno con este depósito, a lo mismo que iba (una factura
    -- o el anticipo de una obra). Antes la bandeja ni lo nombraba: ofrecía
    -- la factura de OTRO cliente y el cobro anotado quedaba en tránsito
    -- para siempre.
    if p_con ? 'corrige' then
      if fn_banco_limpio(p_motivo) is null then
        raise exception using errcode = '22023',
          message = 'Corregir un cobro anotado por otro monto dice por qué (motivo): se anula y se registra el bueno con este depósito.';
      end if;
      if v_cobro.movimiento_id is not null then
        raise exception using errcode = 'MX008', message = 'Ese cobro ya está casado con este movimiento: no hay nada que corregir.';
      end if;
      if (select count(*) from aplicaciones_cobro x where x.cobro_id = v_cobro.id) <> 1
         or exists (select 1 from aplicaciones_cobro x where x.cobro_id = v_cobro.id and (x.desde_anticipo or x.descuento <> 0)) then
        raise exception using errcode = 'MX008',
          message = format('Ese cobro (del %s por %s) va a varias facturas, o con descuento: anúlalo (fn_cobro_anular, con su motivo) '
                           'y registra el bueno con este depósito eligiendo a qué va (fn_banco_cobrar).', v_cobro.fecha,
                           v_cobro.monto);
      end if;
      select jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
               'factura_id', x.factura_id, 'proyecto_id', case when x.factura_id is null then x.proyecto_id end,
               'monto', m.monto::text, 'es_retencion', case when x.es_retencion then true end)))
        into v_otros
        from aplicaciones_cobro x where x.cobro_id = v_cobro.id;
      perform fn_cobro_anular(v_cobro.id, format('Anotado por %s y el banco depositó %s el %s: %s', v_cobro.monto, m.monto, m.fecha,
                                                 fn_banco_limpio(p_motivo)));
      return fn_banco_cobrar(m.id, v_otros, format('Corrige el cobro del %s por %s (anulado): %s', v_cobro.fecha, v_cobro.monto,
                                                   fn_banco_limpio(p_motivo)))
             || jsonb_build_object('anulado', v_cobro.id);
    end if;
    v_ases := v_cobro.contabilizado_en;
    v_lin := fn_banco_lineas_de(v_ases, m.cuenta);
    -- (Ronda 4) EL COBRO CON TARJETA DEPOSITADO NETO DE SU COMISIÓN, ya
    -- anotado por el bruto (o des-casado después de cobrarlo): se casa con
    -- él y la comisión entra como su anexo (Dr la cuenta de los cargos del
    -- banco / Cr el banco), como en fn_banco_cobrar, con su tope (3.5 % más
    -- 0.30 del cobro). Antes «las líneas suman 1000.00 y el movimiento es de
    -- 970.70» y no había vuelta a su cobro.
    if p_con ? 'comision' then
      v_com := fn_puente_monto(p_con->>'comision', 'La comisión');
      if v_lin is null or v_com <= 0 or v_cobro.monto - m.monto <> v_com
         or v_com > round(0.035 * v_cobro.monto + 0.30, 2) then
        raise exception using errcode = 'MX008',
          message = format('La comisión de un cobro con tarjeta es lo que el procesador se quedó: el cobro (%s) menos el depósito (%s), '
                           'y como mucho un 3.5 %% más 0.30 del cobro (%s). Con %s no casa; si el cobro está anotado por otro monto, '
                           'corrígelo ({"cobro": …, "corrige": true}, con su motivo).', v_cobro.monto, m.monto,
                           round(0.035 * v_cobro.monto + 0.30, 2), v_com);
      end if;
      v_fee := coalesce((select d.cuenta from banco_descriptores d where d.clave = 'cargo_banco'), '6130');
      if fn_puente_cuenta_mal(v_fee) is not null then
        raise exception using errcode = 'MX004', message = format('La comisión va a %s: %s.', v_fee, fn_puente_cuenta_mal(v_fee));
      end if;
      v_res := fn_banco_asiento('movimientos_banco', m.id::text, m.fecha,
                 format('Comisión del cobro con tarjeta (%s): %s', v_com, coalesce(m.descripcion, m.memo, '')),
                 jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', m.cuenta, 'monto', (-v_com)::text,
                                                                        'memo', left(m.descripcion, 200))),
                                   jsonb_strip_nulls(jsonb_build_object('cuenta', v_fee, 'monto', v_com::text,
                                                                        'memo', left('Comisión · ' || coalesce(m.descripcion, ''), 200)))),
                 fn_banco_proc(m, 'fn_banco_casar_con', 'R2 comisión del cobro con tarjeta')
                 || jsonb_build_object('anexo', 'comision', 'cobro', v_cobro.id));
      v_lin := v_lin || fn_banco_lineas_de((v_res->>'id')::uuid, m.cuenta);
      perform fn_banco_casar_lineas(m.id, 'cobro', v_cobro.id::text, v_ases, v_lin,
                                    format('Edgar eligió: el cobro, depositado neto de %s de comisión → %s', v_com, v_fee),
                                    false, false, p_motivo);
      return fn_banco_resumen(p_movimiento) || jsonb_build_object('comision', v_res->>'numero');
    end if;
  end if;
  if v_lin is null then
    raise exception using errcode = 'MX008',
      message = format('Ese asiento no tiene líneas libres en %s (la cuenta del movimiento): no casa.', m.cuenta);
  end if;
  v_clase := coalesce(fn_banco_clase_de(v_ases), 'asiento');
  if v_clase = 'transferencia' then
    -- El otro lado de una transferencia ya posteada: con ESE asiento.
    if jsonb_array_length(v_lin) <> 1 then
      raise exception using errcode = 'MX008',
        message = 'El otro lado de una transferencia casa con UNA línea: la de esta cuenta en ese asiento.';
    end if;
    perform fn_banco_casar_transferencia(m.id, (v_lin->0->>'asiento_id')::uuid, (v_lin->0->>'orden')::int,
                                         'R3 la otra mitad de la transferencia: Edgar la eligió', false, p_motivo);
    return fn_banco_resumen(p_movimiento);
  end if;
  select case when v_clase in ('recibo', 'cobro', 'devolucion', 'cuota_prestamo') then a.origen_id else a.numero end
    into v_ref from asientos a where a.id = v_ases;
  perform fn_banco_casar_lineas(m.id, v_clase, v_ref, v_ases, v_lin, 'Edgar eligió: ' || v_clase, false, false, p_motivo);
  return fn_banco_resumen(p_movimiento);
end $$;
revoke execute on function public.fn_banco_casar_con(uuid, jsonb, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_casar_con(uuid, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------
-- fn_banco_cobrar(movimiento, aplicaciones, notas) — un depósito sin cobro:
-- Edgar dice a qué facturas va (las que propuso la bandeja, u otras) y se
-- registra SU cobro con fn_cobro_registrar de c3, con este movimiento
-- (movimiento_id): la fecha, el monto y la cuenta son los del banco. Así
-- el depósito nunca va a ingreso: entra a 1110/1120 por factura, o de
-- anticipo de una obra ({"proyecto_id": …, "monto": …}). Con una sola
-- aplicación sin monto, es el del depósito.
--   _rpc('fn_banco_cobrar', { p_movimiento: '…', p_aplicaciones: [{ factura_id: 12 }] })
-- UN COBRO CON TARJETA, depositado NETO de su comisión (QuickBooks
-- Payments, Stripe, Square): {"comision": "29.30"} en la lista (sola, o
-- dentro de una aplicación). El cobro es por el BRUTO (la factura queda
-- cobrada entera: 1,000.00) y la comisión, un asiento del banco junto a él
-- (Dr 6130, la cuenta de los cargos del banco / Cr el banco), casados los
-- dos con el depósito (970.70). Antes no había cómo: aplicar los 1,000.00
-- fallaba («tienen que sumar lo mismo»), el botón de la bandeja dejaba la
-- factura abierta por 29.30 para siempre, y el descuento la llevaba contra
-- el ingreso (los ingresos ya no cuadraban con el bruto del 1099-K).
--   [{"factura_id": 12, "monto": "1000.00"}, {"comision": "29.30"}]
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_cobrar(p_movimiento uuid, p_aplicaciones jsonb, p_notas text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m       movimientos_banco;
  v_apps  jsonb := p_aplicaciones;
  v_res   jsonb;
  v_c     cobros;
  v_medio text;
  v_com   numeric := 0;
  v_x     jsonb;
  v_i     int := 0;
  v_fee   text;
  v_anexo jsonb;
  v_lin   jsonb;
  v_libres text;
  v_sapps numeric;
  v_tope  numeric;
begin
  perform fn_banco_exigir_dueno();
  m := fn_banco_tomar(p_movimiento);
  if not fn_puente_es_banco(m.cuenta) or m.monto <= 0 then
    raise exception using errcode = 'MX008', message = 'Un cobro es un depósito: un movimiento que ENTRA a un banco.';
  end if;
  if jsonb_typeof(v_apps) is distinct from 'array' or jsonb_array_length(v_apps) = 0 then
    raise exception using errcode = '22023',
      message = 'Di a qué va el depósito: a una o varias facturas ({"factura_id": …}), o de anticipo de una obra ({"proyecto_id": …}).';
  end if;
  -- (Ronda 4: el depósito de los primeros 30 días con la apertura posteada
  -- y su conciliación sin confirmar puede ser el depósito en tránsito del
  -- 30-sep, que QuickBooks ya cobró: solo con su motivo, en las notas)
  if fn_banco_limpio(p_notas) is null and fn_banco_apertura_estado(m.cuenta) = 'sin_conciliar'
     and fn_banco_apertura_aviso(m) is not null then
    raise exception using errcode = 'MX008',
      message = replace(fn_banco_apertura_aviso(m), 'dilo en el motivo', 'dilo en las notas (p_notas)');
  end if;
  -- La COMISIÓN del procesador de tarjeta (si la hay): sale de la lista, y
  -- el cobro es por el bruto.
  for v_x in select value from jsonb_array_elements(v_apps) loop
    v_i := v_i + 1;
    if jsonb_typeof(v_x) = 'object' and v_x ? 'comision' then
      v_com := v_com + fn_puente_monto(v_x->>'comision', format('Aplicación %s: la comisión', v_i));
    end if;
  end loop;
  if v_com > 0 then
    select coalesce(jsonb_agg(x.v - 'comision' order by x.o), '[]'::jsonb) into v_apps
      from jsonb_array_elements(v_apps) with ordinality as x(v, o)
     where not (jsonb_typeof(x.v) = 'object' and x.v ? 'comision' and (select count(*) from jsonb_object_keys(x.v)) = 1);
    if jsonb_array_length(v_apps) = 0 then
      raise exception using errcode = '22023',
        message = 'Di a qué va el depósito además de su comisión: a una o varias facturas ({"factura_id": …}).';
    end if;
    v_fee := coalesce((select d.cuenta from banco_descriptores d where d.clave = 'cargo_banco'), '6130');
    if fn_puente_cuenta_mal(v_fee) is not null then
      raise exception using errcode = 'MX004', message = format('La comisión va a %s: %s.', v_fee, fn_puente_cuenta_mal(v_fee));
    end if;
  end if;
  if jsonb_array_length(v_apps) = 1 and not (v_apps->0 ? 'monto') then
    v_apps := jsonb_build_array((v_apps->0) || jsonb_build_object('monto', (m.monto + v_com)::text));
  end if;
  -- (Ronda 4) Las facturas suman MÁS que el depósito, por lo que cabe en la
  -- comisión de un procesador de tarjetas, y no se dijo la comisión: se
  -- dice cómo (antes, el «tienen que sumar lo mismo» de c3 no lo nombraba,
  -- y repartir el neto dejaba las facturas abiertas por su comisión).
  if v_com = 0 and not exists (select 1 from jsonb_array_elements(v_apps) x where jsonb_typeof(x) <> 'object' or not (x ? 'monto')) then
    select sum(fn_puente_monto(x->>'monto', 'Una aplicación: el monto')),
           sum(round(0.035 * fn_puente_monto(x->>'monto', 'Una aplicación: el monto') + 0.30, 2))
      into v_sapps, v_tope
      from jsonb_array_elements(v_apps) x;
    if v_sapps > m.monto and v_sapps - m.monto <= v_tope then
      raise exception using errcode = 'MX008',
        message = format('Las facturas suman %s y el depósito es de %s: si es un cobro con tarjeta depositado neto (el lote del '
                         'procesador), lo que falta (%s) es su comisión: dilo en la lista ({"comision": "%s"}) y el cobro va por el '
                         'bruto, con la comisión a su cuenta. Si es un pago parcial, di cuánto va a cada factura.', v_sapps, m.monto,
                         v_sapps - m.monto, v_sapps - m.monto);
    end if;
  end if;
  -- (Ronda 4) UN COBRO YA ANOTADO, sin su depósito, de OTRO monto (no más
  -- de la mitad de diferencia), en la ventana de este (de 30 días antes a 3
  -- después): puede ser este mismo dinero (el cheque anotado por 2,500.00
  -- que era de 2,050.00; el cobro con tarjeta por el bruto, depositado
  -- neto). Registrar otro lo metería dos veces: se casa con él
  -- (fn_banco_casar_con con «comision» o «corrige»). Solo con lo que lo
  -- explique, en las notas.
  select string_agg(format('el del %s por %s%s', c.fecha, c.monto, coalesce(' (ref ' || c.referencia || ')', '')), '; '
                    order by abs(c.fecha - m.fecha), c.fecha)
    into v_libres
    from cobros c
   where c.estado = 'vigente' and c.movimiento_id is null and c.cuenta = m.cuenta and c.contabilizado_en is not null
     and c.monto <> m.monto and abs(c.monto - m.monto) <= 0.5 * greatest(c.monto, m.monto)
     and c.fecha between m.fecha - 30 and m.fecha + 3
     and not exists (select 1 from cobros_devoluciones dv where dv.cobro_id = c.id)
     -- (su línea, libre: un cobro casado junto con otros —R2— no tiene
     -- movimiento escrito, pero ya tiene su depósito)
     and exists (select 1 from asiento_lineas l
                  where l.asiento_id = c.contabilizado_en and l.cuenta = m.cuenta
                    and not exists (select 1 from banco_casado_lineas cl
                                     where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente));
  if v_libres is not null and fn_banco_limpio(p_notas) is null then
    raise exception using errcode = 'MX008',
      message = format('Hay cobros anotados sin su depósito, de otro monto: %s. Si este depósito es uno de ellos, cásalo con él '
                       '(fn_banco_casar_con con {"cobro": …}: neto de la comisión de la tarjeta, con "comision"; anotado por otro '
                       'monto, con "corrige": true y su motivo). Registrar otro metería el mismo dinero dos veces. Si de verdad '
                       'es otro, dilo en las notas (p_notas).', v_libres);
  end if;
  v_medio := case when m.cheque is not null or fn_banco_dice('cheque_devuelto', m.desc_norm) then 'cheque'
                  when m.desc_norm ~ 'ZELLE' then 'zelle'
                  when coalesce(m.tipo_banco, '') in ('DIRECTDEP', 'XFER') or m.desc_norm ~ '\mACH\M' then 'ach'
                  else 'deposito' end;
  begin
    v_res := fn_cobro_registrar(jsonb_strip_nulls(jsonb_build_object(
               'fecha', m.fecha::text, 'monto', (m.monto + v_com)::text, 'cuenta', m.cuenta,
               'medio', case when v_com > 0 then 'tarjeta' else v_medio end,
               'referencia', coalesce(m.cheque, m.id_externo), 'movimiento_id', m.id::text,
               'notas', coalesce(fn_banco_limpio(p_notas), 'Del banco: ' || coalesce(m.descripcion, ''))
                        || case when v_com > 0 then format(' (depositado neto de %s de comisión)', v_com) else '' end,
               'aplicaciones', v_apps)));
  exception when sqlstate 'MX008' then
    -- (Ronda 4: con el banco instalado, el cobro que ya está se CASA con
    -- este depósito; el «update cobros set movimiento_id» de c3 no lo
    -- casaba —el movimiento seguía pendiente—.)
    if sqlerrm like '%update cobros set movimiento_id%' then
      raise exception using errcode = 'MX008',
        message = format('%s Cásalo con este depósito: fn_banco_casar_con con {"cobro": "%s"}%s.',
                         split_part(sqlerrm, ' Cásalo con su movimiento', 1),
                         substring(sqlerrm from 'where id = ''([0-9a-f-]{36})'''),
                         case when v_com > 0 then format(' y "comision": "%s"', v_com) else '' end);
    end if;
    raise;
  end;
  select * into v_c from cobros where id = (v_res->>'cobro')::uuid;
  v_lin := fn_banco_lineas_de(v_c.contabilizado_en, m.cuenta);
  if v_com > 0 then
    -- (la comisión: un asiento del banco, «anexo» del cobro; se casa junto
    -- con él y, si el casado se deshace, se reversa con él)
    v_anexo := fn_banco_asiento('movimientos_banco', m.id::text, m.fecha,
                 format('Comisión del cobro con tarjeta (%s): %s', v_com, coalesce(m.descripcion, m.memo, '')),
                 jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', m.cuenta, 'monto', (-v_com)::text,
                                                                        'memo', left(m.descripcion, 200))),
                                   jsonb_strip_nulls(jsonb_build_object('cuenta', v_fee, 'monto', v_com::text,
                                                                        'memo', left('Comisión · ' || coalesce(m.descripcion, ''), 200)))),
                 fn_banco_proc(m, 'fn_banco_cobrar', 'R2 comisión del cobro con tarjeta')
                 || jsonb_build_object('anexo', 'comision', 'cobro', v_c.id));
    v_lin := v_lin || fn_banco_lineas_de((v_anexo->>'id')::uuid, m.cuenta);
  end if;
  perform fn_banco_casar_lineas(m.id, 'cobro', v_c.id::text, v_c.contabilizado_en, v_lin,
                                'R2 depósito = cobro (Edgar eligió a qué facturas va)'
                                || case when v_com > 0 then format(', neto de %s de comisión → %s', v_com, v_fee) else '' end,
                                false, false, p_notas);
  return fn_banco_resumen(p_movimiento) || jsonb_build_object('cobro', v_c.id)
         || case when v_anexo is not null then jsonb_build_object('comision', v_anexo->>'numero') else '{}'::jsonb end;
end $$;
revoke execute on function public.fn_banco_cobrar(uuid, jsonb, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_cobrar(uuid, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------
-- fn_banco_pagar_proveedor(movimiento, proveedor, partidas) — el pago a un
-- proveedor (a cuenta, 2010): Dr 2010 por lo que se le debe / Cr el banco
-- (o la tarjeta con que se pagó). NUNCA a 5100: el gasto ya entró con sus
-- tickets. p_partidas nulo: lo más viejo primero (FIFO): primero lo que se
-- le debe SIN partida (lo que traía QuickBooks en la apertura, su A/P
-- Aging al 30-sep, menos lo que ya se le pagó sin partida: el statement de
-- septiembre), después sus partidas por fecha. O lo que Edgar elija:
--   [{"partida_tabla": "recibos", "partida_id": "123", "monto": "400.00"},
--    {"apertura": "CED-87001", "monto": "1850.00"}]
-- («apertura»: lo de QuickBooks, con la referencia que se quiera para el
-- memo). Antes el FIFO saltaba lo de QuickBooks: pagaba las facturas de
-- octubre (también la que seguía abierta) y decía «pagaste de más» con lo
-- de septiembre sin tocar. Lo que sobre del pago (más que todo lo que se
-- le debe) queda a favor con el proveedor, en 2010 sin partida y a su
-- nombre, y se dice.
-- Con un movimiento que ENTRA (un depósito, un abono): el REEMBOLSO del
-- proveedor, contra lo que tiene a favor de la empresa en 2010 (una
-- devolución a su cuenta, lo que se le pagó de más), lo más viejo primero:
-- Dr el banco / Cr 2010 a su nombre. Sin nada a favor, no cabe (MX008): es
-- la devolución de una compra que no está en su cuenta, y se clasifica
-- contra el costo de su obra con su motivo.
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_pagar_proveedor(p_movimiento uuid, p_proveedor uuid, p_partidas jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m        movimientos_banco;
  v_prov   proveedores;
  v_cxp    text := fn_puente_cuenta_de('cxp');
  v_total  numeric;
  v_resto  numeric;
  v_lineas jsonb;
  v_x      numeric;
  v_sinp   numeric;
  v_abierto numeric;
  v_ap     numeric := 0;
  v_avisos jsonb := '[]'::jsonb;
  r        record;
  v_res    jsonb;
begin
  perform fn_banco_exigir_dueno();
  m := fn_banco_tomar(p_movimiento);
  select * into v_prov from proveedores where id = p_proveedor;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese proveedor.';
  end if;
  if m.monto > 0 then
    -- EL REEMBOLSO de un proveedor (dinero que ENTRA: el cheque de CED por
    -- una devolución, lo que se le pagó de más): va contra lo que tiene A
    -- FAVOR de la empresa en su cuenta por pagar (Dr el banco / Cr 2010 a
    -- su nombre), lo más viejo primero; nunca al costo otra vez (la
    -- devolución ya lo bajó). Antes esta función respondía que un pago es
    -- dinero que sale, y clasificarlo a 2010 mandaba aquí: un círculo sin
    -- salida. Si no tiene nada a favor, es la devolución de una compra que
    -- no está en su cuenta: se clasifica contra el costo de su obra, con su
    -- motivo (fn_banco_clasificar).
    if p_partidas is not null then
      raise exception using errcode = '22023',
        message = 'Un reembolso va contra lo que el proveedor tiene a favor, lo más viejo primero: sin p_partidas.';
    end if;
    v_total := m.monto;
    v_resto := v_total;
    v_lineas := jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', m.cuenta, 'monto', m.monto::text,
                                                                       'memo', left('Reembolso de ' || v_prov.nombre, 200))));
    for r in select l.partida_tabla, l.partida_id, sum(l.monto) as favor, min(a.fecha_contable) as desde
               from asiento_lineas l join asientos a on a.id = l.asiento_id
              where l.cuenta = v_cxp and l.tercero_tipo = 'proveedor' and l.tercero_id = p_proveedor::text
              group by l.partida_tabla, l.partida_id
             having sum(l.monto) > 0
              order by min(a.fecha_contable), l.partida_tabla nulls first, l.partida_id loop
      exit when v_resto <= 0;
      v_x := least(v_resto, r.favor);
      v_lineas := v_lineas || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                    'cuenta', v_cxp, 'monto', (-v_x)::text, 'tercero_tipo', 'proveedor', 'tercero_id', p_proveedor::text,
                    'partida_tabla', r.partida_tabla, 'partida_id', r.partida_id,
                    'memo', format('Reembolso de %s: contra lo que tenía a favor%s', v_prov.nombre,
                                   coalesce(' (' || r.partida_tabla || ' ' || r.partida_id || ')', '')))));
      v_resto := v_resto - v_x;
    end loop;
    if v_resto > 0 then
      raise exception using errcode = 'MX008',
        message = format('%s tiene %s a favor de la empresa en %s y el reembolso es de %s: no cabe. Si es la devolución de una compra '
                         'que no está en su cuenta (sin su nota de crédito), clasifícala contra el costo de su obra con su motivo '
                         '(fn_banco_clasificar); si es un cobro, fn_banco_cobrar.', v_prov.nombre, v_total - v_resto, v_cxp, v_total);
    end if;
    v_res := fn_banco_asiento('movimientos_banco', m.id::text, m.fecha, 'Reembolso de ' || v_prov.nombre, v_lineas,
                              fn_banco_proc(m, 'fn_banco_pagar_proveedor', 'R4 reembolso de un proveedor')
                              || jsonb_build_object('proveedor', jsonb_build_object('id', v_prov.id, 'nombre', v_prov.nombre)));
    perform fn_banco_casar_lineas(m.id, 'pago_proveedor', p_proveedor::text, (v_res->>'id')::uuid,
                                  jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 1)),
                                  'R4 reembolso de un proveedor: contra lo que tenía a favor en ' || v_cxp, false, true);
    return fn_banco_resumen(p_movimiento);
  end if;
  if m.monto = 0 then
    raise exception using errcode = 'MX005', message = 'Un movimiento en cero no paga nada.';
  end if;
  v_total := -m.monto;
  v_resto := v_total;
  v_lineas := jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', m.cuenta, 'monto', m.monto::text,
                                                                     'memo', left('Pago a ' || v_prov.nombre, 200))));
  -- Lo que se le debe sin partida (lo de QuickBooks, neto de lo ya pagado
  -- sin partida) y lo abierto en total.
  select coalesce(-sum(l.monto), 0) into v_sinp
    from asiento_lineas l
   where l.cuenta = v_cxp and l.tercero_tipo = 'proveedor' and l.tercero_id = p_proveedor::text and l.partida_tabla is null;
  select v_sinp + coalesce(sum(q.saldo), 0) into v_abierto
    from (select -sum(l.monto) as saldo
            from asiento_lineas l
           where l.cuenta = v_cxp and l.tercero_tipo = 'proveedor' and l.tercero_id = p_proveedor::text and l.partida_tabla is not null
           group by l.partida_tabla, l.partida_id
          having sum(l.monto) < 0) q;
  if p_partidas is null then
    if v_sinp > 0 then
      v_x := least(v_resto, v_sinp);
      v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
                    'cuenta', v_cxp, 'monto', v_x::text, 'tercero_tipo', 'proveedor', 'tercero_id', p_proveedor::text,
                    'memo', format('Pago de lo que traía QuickBooks (apertura) de %s', v_prov.nombre)));
      v_resto := v_resto - v_x;
      v_ap := v_x;
    end if;
    for r in select l.partida_tabla, l.partida_id, -sum(l.monto) as saldo, min(a.fecha_contable) as desde
               from asiento_lineas l join asientos a on a.id = l.asiento_id
              where l.cuenta = v_cxp and l.tercero_tipo = 'proveedor' and l.tercero_id = p_proveedor::text
                and l.partida_tabla is not null
              group by l.partida_tabla, l.partida_id
             having sum(l.monto) < 0
              order by min(a.fecha_contable), l.partida_tabla, l.partida_id loop
      exit when v_resto <= 0;
      v_x := least(v_resto, r.saldo);
      v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
                    'cuenta', v_cxp, 'monto', v_x::text, 'tercero_tipo', 'proveedor', 'tercero_id', p_proveedor::text,
                    'partida_tabla', r.partida_tabla, 'partida_id', r.partida_id,
                    'memo', format('Pago de %s %s de %s', r.partida_tabla, r.partida_id, v_prov.nombre)));
      v_resto := v_resto - v_x;
    end loop;
  else
    if jsonb_typeof(p_partidas) <> 'array' or jsonb_array_length(p_partidas) = 0 then
      raise exception using errcode = '22023',
        message = 'p_partidas: una lista de {partida_tabla, partida_id, monto} (o {apertura, monto}: lo de QuickBooks), o nulo (FIFO).';
    end if;
    for r in select x.partida_tabla, x.partida_id, x.apertura,
                    fn_puente_monto(x.monto, format('El monto para %s', coalesce(x.partida_tabla || ' ' || x.partida_id,
                                                                                 'lo de QuickBooks'))) as monto,
                    (select -sum(l.monto) from asiento_lineas l
                      where l.cuenta = v_cxp and l.tercero_tipo = 'proveedor' and l.tercero_id = p_proveedor::text
                        and l.partida_tabla = x.partida_tabla and l.partida_id = x.partida_id) as saldo
               from jsonb_to_recordset(p_partidas) as x(partida_tabla text, partida_id text, apertura text, monto text) loop
      if r.partida_tabla is null and r.apertura is not null then
        -- Lo de QuickBooks (sin partida).
        if r.monto > v_sinp - v_ap then
          raise exception using errcode = 'MX008',
            message = format('A lo que traía QuickBooks de %s le quedan %s y se le aplican %s: no cabe.', v_prov.nombre,
                             v_sinp - v_ap, r.monto);
        end if;
        v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
                      'cuenta', v_cxp, 'monto', r.monto::text, 'tercero_tipo', 'proveedor', 'tercero_id', p_proveedor::text,
                      'memo', format('Pago de lo que traía QuickBooks (apertura%s) de %s',
                                     case when r.apertura not in ('true', 't') then ': ' || r.apertura else '' end, v_prov.nombre)));
        v_ap := v_ap + r.monto;
        v_resto := v_resto - r.monto;
        continue;
      end if;
      if coalesce(r.saldo, 0) <= 0 then
        raise exception using errcode = 'MX008',
          message = format('%s %s no es una partida abierta de %s en %s (lo que traía QuickBooks va con {"apertura": …}).',
                           r.partida_tabla, r.partida_id, v_prov.nombre, v_cxp);
      end if;
      if r.monto > r.saldo then
        raise exception using errcode = 'MX008',
          message = format('A %s %s de %s le quedan %s abiertos y se le aplican %s: no cabe.', r.partida_tabla, r.partida_id,
                           v_prov.nombre, r.saldo, r.monto);
      end if;
      v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
                    'cuenta', v_cxp, 'monto', r.monto::text, 'tercero_tipo', 'proveedor', 'tercero_id', p_proveedor::text,
                    'partida_tabla', r.partida_tabla, 'partida_id', r.partida_id,
                    'memo', format('Pago de %s %s de %s', r.partida_tabla, r.partida_id, v_prov.nombre)));
      v_resto := v_resto - r.monto;
    end loop;
    if v_resto < 0 then
      raise exception using errcode = 'MX008',
        message = format('Las partidas elegidas suman más (%s) que el pago (%s).', v_total - v_resto, v_total);
    end if;
  end if;
  if v_ap > 0 then
    v_avisos := v_avisos || to_jsonb(format('%s se aplicaron a lo que traía QuickBooks de %s (la apertura: su A/P Aging al 30-sep).',
                                            v_ap, v_prov.nombre));
  end if;
  if v_resto > 0 then
    v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
                  'cuenta', v_cxp, 'monto', v_resto::text, 'tercero_tipo', 'proveedor', 'tercero_id', p_proveedor::text,
                  'memo', format('A favor con %s (pagado de más que lo abierto)', v_prov.nombre)));
    v_avisos := v_avisos || to_jsonb(format(
                  'El pago (%s) es más que todo lo que se le debe a %s (%s, lo de QuickBooks incluido)%s: %s quedan a favor con el '
                  'proveedor en %s, a su nombre (sin partida). Si pagaste algo que todavía no está en la app, sube su factura o su '
                  'ticket.', v_total, v_prov.nombre, greatest(v_abierto, 0),
                  case when p_partidas is not null and v_total - v_resto < v_abierto then ' o que lo que elegiste' else '' end,
                  v_resto, v_cxp));
  end if;
  v_res := fn_banco_asiento('movimientos_banco', m.id::text, m.fecha, 'Pago a ' || v_prov.nombre, v_lineas,
                            fn_banco_proc(m, 'fn_banco_pagar_proveedor', 'R4 pago a proveedor')
                            || jsonb_build_object('proveedor', jsonb_build_object('id', v_prov.id, 'nombre', v_prov.nombre)));
  perform fn_banco_casar_lineas(m.id, 'pago_proveedor', p_proveedor::text, (v_res->>'id')::uuid,
                                jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 1)),
                                'R4 pago a proveedor: a lo que se le debe en ' || v_cxp || case when p_partidas is null then ' (FIFO)'
                                                                                           else ' (lo que eligió Edgar)' end,
                                false, true);
  return fn_banco_resumen(p_movimiento)
         || jsonb_strip_nulls(jsonb_build_object('aviso', case when jsonb_array_length(v_avisos) > 0
                                                               then (select string_agg(x, ' ') from jsonb_array_elements_text(v_avisos) x) end,
                                                 'a_quickbooks', case when v_ap > 0 then v_ap end));
end $$;
revoke execute on function public.fn_banco_pagar_proveedor(uuid, uuid, jsonb) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_pagar_proveedor(uuid, uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- fn_banco_transferencia(movimiento, cuenta, motivo) — dinero entre
-- cuentas propias cuando solo llegó un lado (el pago de la Amex visto en
-- Chase, el pase a la reserva): UN asiento, sin gasto (Dr 2100-x / Cr
-- 1010; Dr 1030 / Cr 1010), con la fecha del movimiento. El movimiento
-- queda «en tránsito» hasta que llegue el otro lado, que casa solo con
-- ESTE asiento (nunca otro). Si el otro lado ya está pendiente, casa ya.
-- Si el asiento que espera ESTE lado ya está en el libro (el otro lado se
-- confirmó antes, o casó con su pareja), no se postea otro (MX008): se
-- casa con él (fn_banco_casar_con), salvo que Edgar diga en el motivo que
-- de verdad es otra transferencia. Antes, con el otro lado a más de 3
-- días (un ACH a otro banco), la bandeja solo ofrecía otra transferencia
-- y el mismo dinero entraba dos veces. Ese asiento se busca a 10 días o
-- menos SIN mirar la dirección (la del cruce, fn_banco_ventana, es para
-- casar solo; aquí se trata de no postear dos veces): antes se buscaba en
-- la misma ventana del cruce, y el pago de la Amex de un viernes que
-- Chase cobraba el martes no la veía y entraba otra vez, sin motivo.
-- La fecha del asiento, nunca dentro de una conciliación confirmada de
-- sus dos cuentas (fn_banco_tr_fecha): el abono de la Amex del 30-oct
-- confirmado «desde 1010» con el Chase al 31-oct ya confirmado va el
-- 1-nov (Chase lo cobró después), no el 30-oct por detrás de octubre.
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_transferencia(p_movimiento uuid, p_cuenta text, p_motivo text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m       movimientos_banco;
  v_res   jsonb;
  v_otro  text;
  v_otro_as text;
  v_tipo  text;
  v_tipo2 text;
  v_senal boolean;
  v_trf   jsonb;
  v_f2    date;
begin
  perform fn_banco_exigir_dueno();
  -- (la cuenta como la dice Edgar: la del plan o su código corto, '2013')
  p_cuenta := fn_banco_cuenta_resolver(p_cuenta);
  m := fn_banco_tomar(p_movimiento);
  if p_cuenta is null or p_cuenta = m.cuenta or not fn_banco_es_propia(p_cuenta) then
    raise exception using errcode = 'MX004',
      message = format('Una transferencia va a OTRA cuenta propia con estado de cuenta (un banco 10xx o una tarjeta de la empresa); '
                       '%s no lo es. La caja chica no es una transferencia: es la respuesta al retiro de cajero (fn_banco_clasificar '
                       'con %s).', coalesce(p_cuenta, 'nula'), fn_banco_caja());
  end if;
  if fn_puente_cuenta_mal(p_cuenta) is not null then
    raise exception using errcode = 'MX004', message = fn_puente_cuenta_mal(p_cuenta);
  end if;
  -- SU SEÑAL, del lado de este movimiento (su descripción del banco, NAME):
  -- un pase entre bancos dice transferencia (o el banco lo da como XFER);
  -- el pago de una tarjeta, visto en el banco, nombra al emisor o los 4
  -- últimos de esa tarjeta; visto en la tarjeta, dice que es un pago. Sin
  -- ella, solo con su motivo escrito: un abono en la tarjeta que no dice
  -- pago es casi siempre la devolución de una compra, y un cargo del banco
  -- que no nombra a nadie, una domiciliación (la luz, el seguro). Antes se
  -- posteaban igual: el costo no bajaba y 1010 quedaba con un cargo «en
  -- circulación» que el banco no iba a traer nunca, y las dos
  -- conciliaciones se confirmaban. (Una tarjeta que manda dinero a un banco,
  -- un adelanto de efectivo, siempre con motivo.)
  v_tipo := fn_banco_tipo_cuenta(m.cuenta);
  v_tipo2 := fn_banco_tipo_cuenta(p_cuenta);
  v_senal := case
               when v_tipo = 'tarjeta' and m.monto > 0 then fn_banco_dice('pago_recibido', m.desc_norm)
               when v_tipo = 'tarjeta' then false
               when v_tipo2 = 'tarjeta' and m.monto > 0 then false
               -- (ronda 4: el pago de una TARJETA, solo con su señal —el emisor o
               -- sus 4 últimos—: «ONLINE TRANSFER TO CHK ...7781» no lo es;
               -- antes la señal genérica iba antes y «A 2100-2013» entraba
               -- sin motivo)
               when v_tipo2 = 'tarjeta'
                 then fn_banco_dice('pago_tarjeta', m.desc_norm)
                      or exists (select 1 from tarjetas t where t.cuenta = p_cuenta and t.ultimos4 ~ '^[0-9]{4}$'
                                    and m.desc_norm ~ ('(^| )' || t.ultimos4 || '( |$)'))
               when coalesce(m.tipo_banco, '') = 'XFER' or fn_banco_dice('transferencia', m.desc_norm) then true
               else false end;
  if not v_senal and fn_banco_limpio(p_motivo) is null then
    raise exception using errcode = 'MX008',
      message = case when v_tipo = 'tarjeta' and m.monto > 0
                     then format('Un abono en la tarjeta que no dice que es un pago («%s») es casi siempre la devolución de una compra: '
                                 'clasifícala contra la cuenta y la obra de su gasto (fn_banco_clasificar), y el costo baja una vez. '
                                 'Como transferencia, %s quedaría con un cargo en circulación que el banco no va a traer nunca. Si de '
                                 'verdad fue un pago a la tarjeta, dilo en el motivo.', coalesce(m.descripcion, ''), p_cuenta)
                     when v_tipo = 'tarjeta'
                     then 'Una tarjeta que manda dinero a un banco (un adelanto de efectivo) no se supone: si de verdad lo es, dilo en '
                          'el motivo.'
                     else format('«%s» no dice que sea dinero entre cuentas propias (ni transferencia, ni el emisor o los 4 últimos '
                                 'de la tarjeta): una domiciliación (la luz, el seguro) es un gasto y se clasifica. Si de verdad es '
                                 'una transferencia a %s, dilo en el motivo.', coalesce(m.descripcion, ''), p_cuenta) end;
  end if;
  -- (Ronda 4) La otra cuenta que nombra el banco no es esta, o esta es un
  -- banco que nunca trajo su estado de cuenta: solo con su motivo.
  if fn_banco_limpio(p_motivo) is null and fn_banco_transferencia_dudosa(m, p_cuenta) is not null then
    raise exception using errcode = 'MX008',
      message = format('No se postea como transferencia a %s sin su motivo: %s. Si es la cuenta personal de Edgar, es una '
                       'distribución (3200) o un préstamo (al accionista, 1130; del accionista, 2900), o una aportación (3100): '
                       'fn_banco_clasificar. Si de verdad es %s, dilo en el motivo.', p_cuenta,
                       fn_banco_transferencia_dudosa(m, p_cuenta), p_cuenta);
  end if;
  select string_agg(format('%s del %s', l.numero, l.fdoc), ', ' order by l.fdoc, l.numero), min(l.asiento_id::text)
    into v_otro, v_otro_as
    from fn_banco_lineas_libres(array[m.cuenta], m.fecha - 15) l
   where l.tr and l.monto = m.monto and l.fdoc between m.fecha - 10 and m.fecha + 10;
  if v_otro is not null and fn_banco_limpio(p_motivo) is null then
    raise exception using errcode = 'MX008',
      message = format('Ya está en el libro la transferencia que espera este lado (%s): es su otro lado (el banco la trae unos días '
                       'antes o después: un fin de semana, un festivo). Cásalo con ella (fn_banco_casar_con con {"asiento": "%s"}); '
                       'otra transferencia pondría el mismo dinero dos veces. Si de verdad es otra, dilo en el motivo.', v_otro,
                       v_otro_as);
  end if;
  -- (Ronda 4: si el otro lado YA está pendiente en esa cuenta, su fecha
  -- cuenta: el asiento va con la del primero y no deja partido su estado
  -- de cuenta; antes «A 2100-2009» desde Chase el 2-nov fechaba el pago el
  -- 2-nov y el abono de la Blue del 31-oct quedaba casado después de su
  -- corte.)
  select x.fecha into v_f2
    from movimientos_banco x
   where x.cuenta = p_cuenta and x.estado = 'pendiente' and x.monto = -m.monto and x.fecha between m.fecha - 10 and m.fecha + 10
     and x.fecha >= fn_puente_corte() and (x.posible_duplicado_de is null or x.duplicado = 'no_es_el_mismo')
   order by abs(x.fecha - m.fecha), x.fecha
   limit 1;
  v_trf := fn_banco_tr_fecha(m.fecha, m.cuenta, v_f2, p_cuenta, m.monto);
  if v_trf ? 'bloqueo' then
    raise exception using errcode = 'MX008', message = format('No se postea todavía: %s.', v_trf->>'bloqueo');
  end if;
  v_res := fn_banco_asiento('movimientos_banco', m.id::text, (v_trf->>'fecha')::date,
             format('Transferencia entre cuentas propias: %s → %s (%s)',
                    case when m.monto < 0 then m.cuenta else p_cuenta end, case when m.monto < 0 then p_cuenta else m.cuenta end,
                    coalesce(m.descripcion, '')),
             jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', m.cuenta, 'monto', m.monto::text,
                                                                    'memo', left(m.descripcion, 200))),
                               jsonb_build_object('cuenta', p_cuenta, 'monto', (-m.monto)::text,
                                                  'memo', 'El otro lado: llega en el estado de cuenta de ' || p_cuenta)),
             fn_banco_proc(m, 'fn_banco_transferencia', 'R3 transferencia (un lado; Edgar la confirmó)')
             || jsonb_strip_nulls(jsonb_build_object('motivo_edgar', fn_banco_limpio(p_motivo), 'fecha_nota', v_trf->>'nota',
                                                     'fecha_por', v_trf->'por')));
  perform fn_banco_casar_lineas(m.id, 'transferencia', p_cuenta, (v_res->>'id')::uuid,
                                jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 1)),
                                'R3 transferencia: Edgar la confirmó; el otro lado casa solo con este asiento', false, true, p_motivo);
  -- El otro lado, si ya llegó (sin proponer nada: solo lo que casa solo;
  -- un ACH tarda días).
  perform fn_banco_casar_interno(p_cuenta, m.fecha - 10, null, false);
  return fn_banco_resumen(p_movimiento);
end $$;
revoke execute on function public.fn_banco_transferencia(uuid, text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_transferencia(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- fn_banco_clasificar(movimiento, líneas, motivo) — lo que no casó con
-- nada: Edgar dice de qué es, y se postea (camino puente, origen
-- movimientos_banco) su línea en el banco contra estas:
--   [{"cuenta": "5100", "monto": "60.00", "proyecto_id": "…", "cost_code": "08-ROUGH",
--     "co": "…", "fase": "…", "memo": "…", "tercero_tipo": "…", "tercero_id": "…"}, …]
-- «monto» es la PARTE DEL MOVIMIENTO que va a esa cuenta, en positivo (la
-- base pone el signo: un cargo va al debe, un abono al haber); una sola
-- línea sin monto lleva el movimiento entero; varias suman el movimiento al
-- centavo. Lo que NO se deja (cada uno dice su camino):
--   · lo que casa con algo que ya está en el libro (un ticket, un cobro,
--     el otro lado de una transferencia), en la ventana del cruce (la
--     fecha de la COMPRA, no la del banco: la Amex postea días después):
--     se casa, no se clasifica (entraría dos veces). Lo que PUEDE ser (un
--     cheque del mismo monto emitido hasta 60 días antes, sin su número en
--     el libro) o una cuota del préstamo ya registrada que espera su cargo:
--     solo con su motivo escrito;
--   · un depósito a ingreso (40xx) o a lo que se cobra (1110, 1120): un
--     depósito de un cliente es un cobro (fn_banco_cobrar). A otros
--     ingresos (49xx), tampoco sin su motivo escrito: los intereses del
--     banco van a 4910 cuando el banco dice que lo son (tipo INT o su
--     descriptor), y la venta de un activo (4920) va con su baja (una línea
--     a 15xx). Y si la bandeja propone un cobro o una factura que lo
--     explica, cualquier otra cuenta pide su motivo;
--   · 2010 (fn_banco_pagar_proveedor), otra cuenta propia
--     (fn_banco_transferencia) y la mano de obra (solo el journal de
--     nómina, f11);
--   · la nómina (Gusto) o un pago a un proveedor con partidas abiertas
--     contra un costo o un gasto: solo con su motivo escrito (una cuota de
--     Gusto es un gasto de software; una compra de contado sin ticket en
--     un supply, un costo), porque así es como se cuela dos veces.
-- Un cargo personal en la tarjeta de la empresa no se ignora: va a 3200
-- (f07, regla b: o a 1130 si Edgar lo devuelve).
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_clasificar(p_movimiento uuid, p_lineas jsonb, p_motivo text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m        movimientos_banco;
  v_l      jsonb;
  v_i      int := 0;
  v_n      int;
  v_sobra  text;
  v_monto  numeric;
  v_suma   numeric := 0;
  v_lineas jsonb;
  v_c      cuentas;
  v_signo  int;
  v_res    jsonb;
  v_cand   text;
  v_motivo text := fn_banco_limpio(p_motivo);
  v_cxc    text := fn_puente_cuenta_de('cxc');
  v_ret    text := fn_puente_cuenta_de('retencion_cxc');
  v_cxp    text := fn_puente_cuenta_de('cxp');
  v_costo  boolean := false;
  v_debil  text;
  v_cuota  text;
  v_tipo   text;
  v_4920   boolean := false;
  v_baja   boolean := false;
  v_intc   text := coalesce((select d.cuenta from banco_descriptores d where d.clave = 'interes'), '4910');
  v_ap     jsonb;
  v_otro   text;
  v_otro_l jsonb;
  v_fac    facturas;
  v_fac_abierto numeric;
begin
  perform fn_banco_exigir_dueno();
  m := fn_banco_tomar(p_movimiento);
  if jsonb_typeof(p_lineas) is distinct from 'array' or jsonb_array_length(p_lineas) = 0 then
    raise exception using errcode = '22023', message = 'Di de qué es: una lista de líneas ({"cuenta": "…", …}).';
  end if;
  v_tipo := fn_banco_tipo_cuenta(m.cuenta);
  -- Primero casar: lo que ya está en el libro no se clasifica otra vez (en
  -- la ventana del cruce, fn_banco_ventana: la fecha de la compra, un
  -- cheque que tarda, el otro lado de una transferencia).
  select string_agg(x.que, ', ') filter (where x.v = 'fuerte'), string_agg(x.que, ', ') filter (where x.v = 'debil')
    into v_cand, v_debil
    from (select format('%s (%s, del %s)', coalesce(case when l.tr then 'la transferencia ' || l.numero end,
                                                    case when l.origen_tabla = 'recibos' then 'el recibo ' || l.origen_id end,
                                                    case when l.origen_tabla = 'cobros' then 'un cobro' end, 'el asiento ' || l.numero),
                        l.numero, l.fdoc) as que,
                 fn_banco_ventana(m.fecha, m.fecha_transaccion, m.cheque, l.fdoc, l.monto, l.tr, v_tipo, fn_banco_tipo_cuenta(l.tr_otra),
                                  l.texto) as v
            from fn_banco_lineas_libres(array[m.cuenta], least(m.fecha, coalesce(m.fecha_transaccion, m.fecha)) - 60) l
           where l.monto = m.monto) x
   where x.v is not null;
  if v_cand is not null then
    raise exception using errcode = 'MX008',
      message = format('Esto ya está en el libro: casa con %s. Cásalo (fn_banco_casar_con): clasificarlo lo metería dos veces.',
                       v_cand);
  end if;
  if v_debil is not null and v_motivo is null then
    raise exception using errcode = 'MX008',
      message = format('Puede ser esto del libro: %s (el mismo monto; un cheque tarda en cobrarse). Si lo es, cásalo '
                       '(fn_banco_casar_con): clasificarlo lo metería dos veces. Si de verdad es otra cosa, dilo en el motivo.',
                       v_debil);
  end if;
  -- Su TICKET CON OTRO TOTAL (la propuesta «otro_total»: la línea libre de un
  -- recibo en su cuenta, en la ventana de la compra, que se le parece; y
  -- que no casa con otro movimiento pendiente). Clasificarlo metería el
  -- gasto dos veces (el cargo de 107.00 y el ticket leído sin el tax, de
  -- 100.00): se corrige el total del recibo y casa solo. Solo con su motivo
  -- escrito; y entonces ese ticket ya no se le propone (descartados).
  if m.monto < 0 then
    select string_agg(format('el recibo %s del %s por %s', l.origen_id, l.fdoc, -l.monto), ', ' order by l.fdoc, l.numero),
           jsonb_agg(l.asiento_id::text || ':' || l.orden)
      into v_otro, v_otro_l
      from fn_banco_lineas_libres(array[m.cuenta], least(m.fecha, coalesce(m.fecha_transaccion, m.fecha)) - 10) l
      left join recibos r on r.id = (case when l.origen_id ~ '^-?[0-9]{1,18}$' then l.origen_id::bigint end)
     where l.origen_tabla = 'recibos'
       and l.fdoc between (case when m.fecha_transaccion is not null then least(m.fecha_transaccion, m.fecha) - 3 else m.fecha - 7 end)
                      and m.fecha + 3
       and fn_banco_otro_total(m.monto, m.desc_norm, l.monto, r.proveedor)
       and not (coalesce(m.propuesta->'descartados', '[]'::jsonb) ? (l.asiento_id::text || ':' || l.orden))
       and not exists (select 1 from movimientos_banco o
                        where o.cuenta = m.cuenta and o.monto = l.monto and o.estado = 'pendiente' and o.id <> m.id
                          and o.fecha between l.fdoc - 10 and l.fdoc + 70
                          and fn_banco_ventana(o.fecha, o.fecha_transaccion, o.cheque, l.fdoc, l.monto, false, v_tipo, null, l.texto)
                              is not null);
    if v_otro is not null and v_motivo is null then
      raise exception using errcode = 'MX008',
        message = format('Puede ser su ticket con OTRO total: %s (el banco dice %s). ¿Se leyó sin el tax, o mal? Corrige su total '
                         'en la app (✎) y este cargo casa solo con él: clasificarlo metería el gasto dos veces. Si de verdad es '
                         'otra compra, dilo en el motivo.', v_otro, -m.monto);
    end if;
  end if;
  -- Una cuota del préstamo ya registrada (con el statement del prestamista)
  -- que espera este cargo: se casa con ella.
  select string_agg(format('la cuota de %s del %s (%s)', p.prestamista, q.fecha, a.numero), ', ' order by q.fecha)
    into v_cuota
    from prestamo_cuotas q
    join prestamos p on p.id = q.prestamo_id
    join asientos a on a.id = q.asiento_id
   where m.monto < 0 and q.anulada_el is null and q.movimiento_id is null and p.cuenta_banco = m.cuenta
     and ((q.monto = -m.monto and q.fecha between m.fecha - 60 and m.fecha + 3)
          -- (ronda 4: o por otro monto a 10 días o menos: la cuota redondeada)
          or (q.monto <> -m.monto and q.fecha between m.fecha - 10 and m.fecha + 10
              and m.estado_motivo = 'cuota_prestamo'))
     and exists (select 1 from asiento_lineas l
                  where l.asiento_id = q.asiento_id and l.cuenta = m.cuenta
                    and not exists (select 1 from banco_casado_lineas cl
                                     where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente));
  if v_cuota is not null and v_motivo is null then
    raise exception using errcode = 'MX008',
      message = format('Ya está registrada %s, que espera su cargo del banco: cásalo con ella (fn_banco_casar_con con su asiento). '
                       'Clasificarlo pondría la cuota dos veces. Si de verdad es otra cosa, dilo en el motivo.', v_cuota);
  end if;
  -- (un depósito cuya propuesta es su COBRO: un cobro registrado, varios que
  -- suman, o una factura que lo explica, entera o una PARTE —el pago parcial
  -- de un cliente—. Antes el parcial se dejaba clasificar sin motivo contra
  -- el costo de la obra: la factura seguía entera por cobrar y el dinero
  -- del cliente entraba dos veces en la utilidad; los intereses que el
  -- banco dice que lo son, no)
  if m.monto > 0 and v_motivo is null
     and not (m.tipo_banco = 'INT' or fn_banco_dice('interes', m.desc_norm))
     and (m.estado_motivo in ('deposito_cobro', 'deposito_cobros', 'deposito_otro_cobro', 'deposito_sin_cobro', 'deposito_parcial')
          or exists (select 1 from jsonb_array_elements(case when jsonb_typeof(m.propuesta->'opciones') = 'array'
                                                             then m.propuesta->'opciones' else '[]'::jsonb end) o
                      where o->>'llamar' = 'fn_banco_cobrar'
                         or (o->>'llamar' = 'fn_banco_casar_con' and coalesce(o->'args'->'p_con' ? 'cobro', false))))
     -- (ronda 4: salvo la línea que la propia bandeja propone —la devolución
     -- de una compra con la débito, contra la cuenta y la obra de su ticket—)
     and not exists (select 1 from jsonb_array_elements(case when jsonb_typeof(m.propuesta->'opciones') = 'array'
                                                             then m.propuesta->'opciones' else '[]'::jsonb end) o
                      where o->>'llamar' = 'fn_banco_clasificar' and jsonb_array_length(p_lineas) = 1
                        and o->'args'->'p_lineas'->0->>'cuenta' = p_lineas->0->>'cuenta'
                        and (o->'args'->'p_lineas'->0->>'proyecto_id') is not distinct from (p_lineas->0->>'proyecto_id')) then
    raise exception using errcode = 'MX008',
      message = 'La bandeja propone un cobro o una factura que explica este depósito (entera o una parte: un pago parcial): '
                'regístralo por ahí (fn_banco_casar_con o fn_banco_cobrar). Si de verdad es otra cosa, dilo en el motivo.';
  end if;
  -- (un depósito DEVUELTO —un cheque que rebotó— no es un gasto: se
  -- devuelve su cobro y la factura vuelve a quedar por cobrar. Antes entraba
  -- sin motivo a 6130, o contra el ingreso, con la factura cobrada)
  if m.estado_motivo = 'devolucion' and v_motivo is null then
    raise exception using errcode = 'MX008',
      message = 'Es un depósito devuelto (un cheque que rebotó): se devuelve su cobro (fn_banco_devolver; si el depósito era de '
                'varios cheques, con la aplicación del que rebotó) y la factura vuelve a quedar por cobrar. No es un gasto. Si de '
                'verdad es otra cosa, dilo en el motivo.';
  end if;
  if m.estado_motivo = 'nomina' and v_motivo is null then
    raise exception using errcode = 'MX008',
      message = 'Es un débito de nómina: espera su journal (f11) y casa solo. Si de verdad es otra cosa (la cuota mensual de Gusto, '
                'por ejemplo), dilo en el motivo.';
  end if;
  -- Una partida en tránsito de la conciliación de APERTURA que este
  -- movimiento puede ser (fn_banco_apertura_opciones: lo que falta de ella
  -- por el mismo monto, su cheque, o la suma con otros pendientes): ya está
  -- en el saldo de la apertura, y clasificarlo lo mete dos veces (el cheque
  -- 1043 otra vez al costo, que QuickBooks ya gastó en septiembre; el
  -- depósito del 30 otra vez a 1010, como un aporte). Solo con su motivo
  -- escrito. Antes entraba sin decir nada, y la conciliación de octubre se
  -- confirmaba con la partida «en tránsito» y los libros por encima del
  -- banco.
  v_ap := fn_banco_apertura_opciones(m);
  if coalesce((v_ap->>'fuertes')::int, 0) > 0 and v_motivo is null then
    raise exception using errcode = 'MX008',
      message = format('Puede ser una partida en tránsito de la conciliación de apertura (%s): ya está en el saldo de la apertura y '
                       'clasificarlo la metería dos veces. Cásalo con ella (fn_banco_casar_con con {"partida_apertura": …}, lo '
                       'que propone la bandeja). Si de verdad es otra cosa, dilo en el motivo.', v_ap->'opciones'->0->>'texto');
  end if;
  -- (Ronda 4: con la apertura posteada y su conciliación sin confirmar, un
  -- cheque o un depósito de los primeros 30 días puede ser una de sus
  -- partidas: solo con su motivo. Sin la apertura posteada todavía, la
  -- propuesta lo avisa, y si entró dos veces, la conciliación de apertura
  -- lo nombra y frena: fn_banco_apertura_casadas.)
  if v_motivo is null and fn_banco_apertura_estado(m.cuenta) = 'sin_conciliar' and fn_banco_apertura_aviso(m) is not null then
    raise exception using errcode = 'MX008', message = fn_banco_apertura_aviso(m);
  end if;
  v_signo := case when m.monto < 0 then 1 else -1 end;
  v_n := jsonb_array_length(p_lineas);
  v_lineas := jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', m.cuenta, 'monto', m.monto::text,
                                                                     'memo', left(m.descripcion, 200))));
  for v_l in select value from jsonb_array_elements(p_lineas) loop
    v_i := v_i + 1;
    if jsonb_typeof(v_l) <> 'object' then
      raise exception using errcode = '22023', message = format('Línea %s: va como objeto JSON.', v_i);
    end if;
    select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(v_l) k
     where k not in ('cuenta', 'monto', 'proyecto_id', 'cost_code', 'co', 'fase', 'memo', 'tercero_tipo', 'tercero_id', 'factura_id');
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Línea %s: clave desconocida: %s.', v_i, v_sobra);
    end if;
    select * into v_c from cuentas where codigo = v_l->>'cuenta';
    if not found or fn_puente_cuenta_mal(v_c.codigo) is not null then
      raise exception using errcode = 'MX004', message = format('Línea %s: %s.', v_i, coalesce(fn_puente_cuenta_mal(v_l->>'cuenta'),
                                                                                         'falta la cuenta'));
    end if;
    if v_c.codigo = m.cuenta or fn_banco_es_propia(v_c.codigo) then
      raise exception using errcode = 'MX008',
        message = format('Línea %s: %s es una cuenta propia con estado de cuenta: el dinero entre cuentas propias es una '
                         'transferencia (fn_banco_transferencia), y su otro lado casa solo.', v_i, v_c.codigo);
    end if;
    if v_c.codigo = v_cxp then
      raise exception using errcode = 'MX008',
        message = format('Línea %s: un pago a %s se aplica a las partidas del proveedor (fn_banco_pagar_proveedor).', v_i, v_cxp);
    end if;
    if m.monto > 0 and v_c.tipo = 'ingreso' then
      raise exception using errcode = 'MX008',
        message = format('Línea %s: un depósito NUNCA va a ingreso (%s). Si es de un cliente, es un cobro de su factura o un '
                         'anticipo de su obra (fn_banco_cobrar); el ingreso lo pone la factura.', v_i, v_c.codigo);
    end if;
    -- (ni un RETIRO contra un ingreso, sin su motivo: lo que baja el ingreso
    -- es una nota de crédito, o la devolución de un cobro)
    if m.monto < 0 and v_c.tipo in ('ingreso', 'otro_ingreso') and v_motivo is null then
      raise exception using errcode = 'MX008',
        message = format('Línea %s: un retiro no va contra un ingreso (%s, %s) sin su motivo escrito. Si es un cheque de un '
                         'cliente que rebotó, se devuelve su cobro (fn_banco_devolver); si le devolviste dinero, es una nota de '
                         'crédito o la devolución de su cobro. Si de verdad es otra cosa, dilo en el motivo.', v_i, v_c.codigo,
                         v_c.nombre);
    end if;
    -- (Ronda 4: «el banco dice que son intereses» con lo mismo que mira la
    -- propuesta —NAME y MEMO—: los de la reserva llegan con NAME «CREDIT» y
    -- MEMO «INTEREST EARNED», la bandeja proponía «Intereses · 4910» y su
    -- botón, pulsado tal cual, se rechazaba)
    if m.monto > 0 and v_c.tipo = 'otro_ingreso'
       and not (v_c.codigo = v_intc
                and (m.tipo_banco = 'INT'
                     or fn_banco_dice('interes', case when m.memo is null then m.desc_norm
                                                      else btrim(m.desc_norm || ' ' || fn_banco_norm(m.memo)) end)))
       and v_motivo is null then
      raise exception using errcode = 'MX008',
        message = format('Línea %s: un depósito no va a %s (%s) sin su motivo escrito. Si es de un cliente, es un cobro de su '
                         'factura o un anticipo de su obra (fn_banco_cobrar): el ingreso lo pone la factura. Los intereses del '
                         'banco van a %s cuando el banco dice que lo son; la venta de un activo, con su baja. Si de verdad es '
                         'otro ingreso, dilo en el motivo.', v_i, v_c.codigo, v_c.nombre, v_intc);
    end if;
    v_4920 := v_4920 or (m.monto > 0 and v_c.codigo = '4920');
    v_baja := v_baja or (v_c.codigo like '15%' and v_c.tipo = 'activo');
    -- (Ronda 4) EL CHEQUE DEVUELTO DE UNA FACTURA DE QUICKBOOKS (de antes
    -- del corte: cobrada allí, sin cobro en la app; el depósito del 30-sep
    -- en tránsito que rebota en octubre): vuelve a quedar por cobrar, contra
    -- SU partida (Dr 1110 de esa factura, de su obra / Cr el banco), con su
    -- motivo. Antes 1110 estaba prohibido sin excepción y lo único que
    -- entraba era contra el ingreso: la factura seguía cobrada y el cliente
    -- debía lo que nadie le iba a cobrar.
    if v_c.codigo = v_cxc and v_l ? 'factura_id' then
      select f.* into v_fac from facturas f
       where f.id = (case when v_l->>'factura_id' ~ '^-?[0-9]{1,18}$' then (v_l->>'factura_id')::bigint end);
      if not found or m.monto >= 0 or v_motivo is null
         or not (m.estado_motivo = 'devolucion' or fn_banco_dice('cheque_devuelto', m.desc_norm))
         or v_fac.fecha >= fn_puente_corte() or v_fac.estado = 'anulada' then
        raise exception using errcode = 'MX008',
          message = format('Línea %s: una factura vuelve a quedar por cobrar desde el banco solo por un cheque DEVUELTO (un retiro que '
                           'el banco da por devuelto), de una factura de antes del corte (cobrada en QuickBooks, sin cobro en la '
                           'app), y con su motivo. Las de la app se devuelven con su cobro (fn_banco_devolver).', v_i);
      end if;
      v_fac_abierto := coalesce((select sum(l.monto) from asiento_lineas l
                                  where l.partida_tabla = 'facturas' and l.partida_id = v_fac.id::text
                                    and l.cuenta in (v_cxc, v_ret)), 0);
      v_monto := case when v_n = 1 and coalesce(fn_banco_limpio(v_l->>'monto'), '') = '' then abs(m.monto)
                      else fn_puente_monto(v_l->>'monto', format('Línea %s: el monto', v_i)) end;
      if v_fac_abierto + v_monto > round(v_fac.monto, 2) then
        raise exception using errcode = 'MX008',
          message = format('Línea %s: la factura #%s es de %s y ya tiene %s por cobrar: no vuelve a quedar por cobrar por %s más.',
                           v_i, v_fac.num, v_fac.monto, v_fac_abierto, v_monto);
      end if;
      v_suma := v_suma + v_monto;
      v_lineas := v_lineas || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                    'cuenta', v_c.codigo, 'monto', (v_signo * v_monto)::text, 'proyecto_id', v_fac.proyecto_id,
                    'partida_tabla', 'facturas', 'partida_id', v_fac.id::text,
                    'memo', coalesce(fn_banco_limpio(v_l->>'memo'),
                                     left(format('Cheque devuelto de la factura #%s (era QuickBooks): %s', v_fac.num,
                                                 coalesce(m.descripcion, '')), 200)))));
      continue;
    end if;
    if v_c.codigo in (v_cxc, v_ret) then
      raise exception using errcode = 'MX008',
        message = case when m.monto < 0
                       then format('Línea %s: lo que se cobra (%s) entra por su cobro, no a mano. Un cheque devuelto de una factura '
                                   'de la app se devuelve con su cobro (fn_banco_devolver); el de una factura de antes del corte '
                                   '(cobrada en QuickBooks), con {"cuenta": "%s", "factura_id": …} y su motivo.', v_i, v_c.codigo,
                                   v_cxc)
                       else format('Línea %s: lo que se cobra (%s) entra por su cobro (fn_banco_cobrar), no a mano.', v_i,
                                   v_c.codigo) end;
    end if;
    if fn_puente_es_mano_de_obra(v_c.codigo) then
      raise exception using errcode = 'MX008',
        message = format('Línea %s: %s es mano de obra, y entra solo por el journal de nómina (f11).', v_i, v_c.codigo);
    end if;
    -- (El sueldo de oficina y el de Edgar como oficial, 6000 y 6005, son
    -- sueldo: solo por su journal, con sus retenciones. Clasificado desde el
    -- banco entraba el neto: la compensación de oficiales (1125-E) corta
    -- en lo retenido y 2220 sin la retención que hay que depositar.)
    if v_c.codigo in ('6000', '6005') then
      raise exception using errcode = 'MX008',
        message = format('Línea %s: %s (%s) es sueldo: entra solo por el journal de su nómina, con sus retenciones (el de Gusto, '
                         'f11; antes de f11, el del proveedor anterior con fn_banco_nomina, desde el SQL Editor).', v_i, v_c.codigo,
                         v_c.nombre);
    end if;
    v_costo := v_costo or v_c.tipo in ('costo', 'gasto', 'otro_gasto');
    if v_n = 1 and coalesce(fn_banco_limpio(v_l->>'monto'), '') = '' then
      v_monto := abs(m.monto);
    else
      v_monto := fn_puente_monto(v_l->>'monto', format('Línea %s: el monto', v_i));
    end if;
    v_suma := v_suma + v_monto;
    v_lineas := v_lineas || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                  'cuenta', v_c.codigo, 'monto', (v_signo * v_monto)::text,
                  'proyecto_id', fn_banco_limpio(v_l->>'proyecto_id'), 'cost_code', fn_banco_limpio(v_l->>'cost_code'),
                  'co', fn_banco_limpio(v_l->>'co'), 'fase', fn_banco_limpio(v_l->>'fase'),
                  'memo', coalesce(fn_banco_limpio(v_l->>'memo'), left(m.descripcion, 200)),
                  'tercero_tipo', fn_banco_limpio(v_l->>'tercero_tipo'), 'tercero_id', fn_banco_limpio(v_l->>'tercero_id'))));
  end loop;
  if v_suma <> abs(m.monto) then
    raise exception using errcode = 'MX001',
      message = format('Las líneas suman %s y el movimiento es de %s: tienen que sumar lo mismo, al centavo.', v_suma, abs(m.monto));
  end if;
  if v_4920 and not v_baja then
    raise exception using errcode = 'MX008',
      message = '4920 (la ganancia o pérdida en la venta de un activo) va junto con su baja: una línea a la cuenta del activo (15xx) '
                'o a su depreciación (1590), con el precio contra su valor en libros (f08).';
  end if;
  if m.estado_motivo = 'pago_proveedor' and v_costo and v_motivo is null then
    raise exception using errcode = 'MX008',
      message = 'Parece un pago a un proveedor con partidas abiertas: su gasto ya entró con sus tickets, y a un costo o un gasto '
                'entraría dos veces. Aplícalo a sus partidas (fn_banco_pagar_proveedor); si de verdad es otra compra, dilo en el '
                'motivo.';
  end if;
  if m.estado_motivo = 'reembolso_proveedor' and v_costo and v_motivo is null then
    raise exception using errcode = 'MX008',
      message = 'Parece el reembolso de un proveedor que tenía algo a tu favor (una devolución a su cuenta, un pago de más): va '
                'contra ese saldo (fn_banco_pagar_proveedor con este depósito), y al costo lo bajaría dos veces. Si de verdad es '
                'la devolución de una compra que no está en su cuenta, dilo en el motivo.';
  end if;
  v_res := fn_banco_asiento_edgar('movimientos_banco', m.id::text, m.fecha,
             coalesce(v_motivo, 'Clasificado por Edgar') || ': ' || coalesce(m.descripcion, m.memo, ''), v_lineas,
             fn_banco_proc(m, 'fn_banco_clasificar', coalesce(m.propuesta->>'regla', 'R10') || ' clasificado por Edgar')
             || jsonb_strip_nulls(jsonb_build_object('motivo_edgar', v_motivo, 'propuesta', m.propuesta->>'motivo')));
  perform fn_banco_casar_lineas(m.id, 'clasificado', (select string_agg(x->>'cuenta', ',') from jsonb_array_elements(p_lineas) x),
                                (v_res->>'id')::uuid,
                                jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 1)),
                                coalesce(m.propuesta->>'regla', 'R10') || ' clasificado por Edgar'
                                || coalesce(' (' || (m.propuesta->>'motivo') || ')', ''), false, true, v_motivo);
  -- (el ticket de otro total que Edgar dijo que no es: ya no se le propone,
  -- ni lo marca «llegó su ticket»; queda escrito por qué)
  if v_otro_l is not null then
    perform fn_banco_marca('movimiento:' || m.id);
    update movimientos_banco
       set propuesta = jsonb_build_object('descartados', coalesce(m.propuesta->'descartados', '[]'::jsonb) || v_otro_l,
                                          'descartado_motivo', v_motivo)
     where id = m.id;
    perform fn_banco_marca(null);
  end if;
  return fn_banco_resumen(p_movimiento);
end $$;
revoke execute on function public.fn_banco_clasificar(uuid, jsonb, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_clasificar(uuid, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------
-- fn_banco_ignorar(movimiento, motivo) — lo que no es de la empresa, con
-- su motivo. OJO: lo que mueve dinero de la empresa no se ignora: un
-- cargo personal en la tarjeta de la empresa se clasifica a 3200 (f07); un
-- movimiento ignorado que mueve dinero deja la conciliación de su cuenta
-- sin cuadrar (se dice). Sirve para un par que se anula (un cargo y su
-- reverso el mismo día), o para lo que entró por error.
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_ignorar(p_movimiento uuid, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m movimientos_banco;
begin
  perform fn_banco_exigir_dueno();
  if coalesce(length(fn_banco_limpio(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'Ignorar un movimiento dice por qué (motivo).';
  end if;
  m := fn_banco_tomar(p_movimiento, true);
  perform fn_banco_marca('movimiento:' || m.id);
  update movimientos_banco set estado = 'ignorado', estado_motivo = fn_banco_limpio(p_motivo), propuesta = null where id = m.id;
  perform fn_banco_marca(null);
  return fn_banco_resumen(p_movimiento)
         || case when m.monto <> 0
                 then jsonb_build_object('aviso', format('Este movimiento mueve %s: ignorado, la conciliación de %s no cuadrará si '
                                                         'nada lo compensa. Si es un cargo personal en la tarjeta de la empresa, no '
                                                         'se ignora: se clasifica a 3200 (fn_banco_clasificar).', m.monto, m.cuenta))
                 else '{}'::jsonb end;
end $$;
revoke execute on function public.fn_banco_ignorar(uuid, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_ignorar(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- fn_banco_duplicado(movimiento, es_el_mismo, motivo) — lo que entró
-- marcado «posible duplicado» (otro id, misma cuenta y monto, fecha
-- cercana): si es el mismo, queda ignorado (el dinero ya está en el
-- otro); si no, sigue su camino (se casa o se propone).
-- Y un cargo CLASIFICADO cuyo ticket llegó después (la bandeja lo dice:
-- «llego_su_ticket»): true, es su ticket (la clasificación se cambia por
-- él, como fn_banco_casar_con; con más de un ticket posible, se elige
-- ahí); false, es otra compra del mismo monto, con su motivo escrito (el
-- gasto queda dos veces a sabiendas, y ese ticket ya no se le propone).
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_duplicado(p_movimiento uuid, p_es_el_mismo boolean, p_motivo text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m    movimientos_banco;
  o    movimientos_banco;
  v_t  jsonb;
  v_ap text;
begin
  perform fn_banco_exigir_dueno();
  if p_es_el_mismo is null then
    raise exception using errcode = '22023', message = 'Di si es el mismo movimiento (true) o no (false).';
  end if;
  select * into m from movimientos_banco where id = p_movimiento;
  -- (Ronda 4) ¿Una partida de la apertura que el banco ya trajo y está
  -- casada con otra cosa (fn_banco_apertura_casadas)? true: se des-casa y
  -- se casa con ella (se dice cómo); false, con su motivo: no lo es, queda
  -- escrito y ya no se le junta (la conciliación deja de frenar por eso).
  if found and m.estado in ('casado', 'en_transito') then
    -- (lo dicho va por la clave de la partida —fecha, monto y cheque—: vale
    -- aunque la conciliación de apertura se vuelva a calcular)
    select jsonb_agg(distinct fn_banco_partida_clave(p.fecha, p.monto, p.cheque)), min(x.texto) into v_t, v_ap
      from conciliaciones c
      cross join lateral fn_banco_apertura_casadas(c.cuenta, c.id) x
      join conciliacion_partidas p on p.id = x.partida
     where c.cuenta = m.cuenta and c.tipo = 'apertura' and x.movimiento = m.id;
    if v_t is not null then
      if p_es_el_mismo then
        raise exception using errcode = 'MX008', message = format('Para casarlo con la partida de la apertura, %s.',
          substring(v_ap from ': si lo es, (.*)\. Si es otro dinero'));
      end if;
      if coalesce(length(fn_banco_limpio(p_motivo)), 0) < 3 then
        raise exception using errcode = '22023',
          message = 'Di por qué no es la partida de la apertura (motivo): queda escrito, y la conciliación deja de juntarlos.';
      end if;
      perform pg_advisory_xact_lock(820261001, hashtext('casar'));
      select * into m from movimientos_banco where id = p_movimiento for update;
      perform fn_banco_marca('movimiento:' || m.id);
      update movimientos_banco
         set propuesta = coalesce(m.propuesta, '{}'::jsonb)
                         || jsonb_build_object('apertura_no', coalesce(m.propuesta->'apertura_no', '[]'::jsonb) || v_t,
                                               'apertura_no_motivo', fn_banco_limpio(p_motivo))
       where id = m.id;
      perform fn_banco_marca(null);
      return fn_banco_resumen(p_movimiento);
    end if;
  end if;
  -- ¿Llegó su ticket? (un cargo ya clasificado)
  if found and m.estado = 'casado' and m.casado_clase = 'clasificado' then
    perform pg_advisory_xact_lock(820261001, hashtext('casar'));
    select jsonb_agg(jsonb_build_object('asiento_id', t.asiento_id, 'orden', t.orden) order by t.fdoc, t.numero) into v_t
      from fn_banco_tickets_llegados(null, m.id) t;
    if v_t is null then
      raise exception using errcode = 'MX008',
        message = 'Ese cargo ya está clasificado y no tiene un ticket que haya llegado después (o ya dijiste que no era el suyo).';
    end if;
    if p_es_el_mismo then
      -- (un ticket de OTRO total no se cambia por la clasificación: el dinero
      -- no es el mismo; primero se corrige su total. Ronda 4: el ticket
      -- REPARTIDO entre obras —la misma foto— cuyas partes suman el cargo es
      -- UN ticket: se cambia con todas sus partes. Antes se negaba por «OTRO
      -- total» y el único camino dejaba el gasto dos veces.)
      select jsonb_agg(c.lineas order by c.f, c.k) into v_t
        from (select coalesce(t.repartido, t.asiento_id::text || ':' || t.orden) as k, min(t.fdoc) as f,
                     jsonb_agg(jsonb_build_object('asiento_id', t.asiento_id, 'orden', t.orden) order by t.fdoc, t.recibo) as lineas
                from fn_banco_tickets_llegados(null, m.id) t
               where t.linea_monto = t.monto or t.repartido is not null
               group by 1) c;
      if v_t is null then
        raise exception using errcode = 'MX008',
          message = format('El ticket que llegó tiene OTRO total que el cargo (%s): ¿se leyó sin el tax, o mal? Corrige primero su '
                           'total en la app (✎); con el total del banco, se cambia por la clasificación. Si es otra compra, dilo '
                           '(false, con su motivo).', -m.monto);
      end if;
      if jsonb_array_length(v_t) > 1 then
        raise exception using errcode = 'MX008',
          message = 'Hay más de un ticket que puede ser el suyo: elige cuál (fn_banco_casar_con con sus líneas).';
      end if;
      return fn_banco_cambiar_por_ticket(m.id, jsonb_build_object('lineas', v_t->0), p_motivo);
    end if;
    if coalesce(length(fn_banco_limpio(p_motivo)), 0) < 3 then
      raise exception using errcode = '22023',
        message = 'Di por qué no es su ticket (motivo): el gasto queda dos veces en el libro, y queda escrito por qué.';
    end if;
    select * into m from movimientos_banco where id = p_movimiento for update;
    perform fn_banco_marca('movimiento:' || m.id);
    update movimientos_banco
       set propuesta = jsonb_build_object(
                         'descartados', coalesce(m.propuesta->'descartados', '[]'::jsonb)
                                        || (select jsonb_agg((t->>'asiento_id') || ':' || (t->>'orden')) from jsonb_array_elements(v_t) t),
                         'descartado_motivo', fn_banco_limpio(p_motivo))
     where id = m.id;
    perform fn_banco_marca(null);
    return fn_banco_resumen(p_movimiento);
  end if;
  m := fn_banco_tomar(p_movimiento, true);
  if m.posible_duplicado_de is null or m.duplicado is not null then
    raise exception using errcode = 'MX008', message = 'Ese movimiento no está marcado como posible duplicado (o ya se dijo).';
  end if;
  select * into o from movimientos_banco where id = m.posible_duplicado_de;
  perform fn_banco_marca('movimiento:' || m.id);
  if p_es_el_mismo then
    update movimientos_banco
       set estado = 'ignorado', duplicado = 'es_el_mismo', propuesta = null,
           estado_motivo = format('Es el mismo movimiento que el del %s por %s (entró por %s, %s): no entra dos veces.%s', o.fecha,
                                  o.monto, o.origen, o.id, coalesce(' ' || fn_banco_limpio(p_motivo), ''))
     where id = m.id;
    perform fn_banco_marca(null);
  else
    update movimientos_banco set duplicado = 'no_es_el_mismo', propuesta = null, estado_motivo = null where id = m.id;
    perform fn_banco_marca(null);
    perform fn_banco_casar_interno(null, null, m.id, true);
  end if;
  return fn_banco_resumen(p_movimiento);
end $$;
revoke execute on function public.fn_banco_duplicado(uuid, boolean, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_duplicado(uuid, boolean, text) to authenticated;

-- ---------------------------------------------------------------------
-- fn_banco_devolver(movimiento, cobro, motivo) — un cheque que rebotó o un
-- depósito que el banco revirtió: la devolución de ese cobro con
-- fn_cobro_devolver de c3, en la fecha del banco y con este movimiento (la
-- factura vuelve a quedar por cobrar), y el movimiento casado con ella.
-- UN CHEQUE DE VARIOS: el depósito de dos cheques entró como UN cobro
-- (13,000.00: las facturas #1101 y #1103) y rebota uno (8,000.00). p_cobro
-- es entonces la APLICACIÓN de ese cobro que rebotó (la bandeja la da), o
-- el cobro si solo una aplicación, o solo una factura, suma lo devuelto.
-- En la fecha del banco: se devuelve el cobro entero (c3 devuelve cobros
-- enteros) y lo que NO rebotó se registra otra vez ese mismo día, un cobro
-- nuevo con sus aplicaciones; el movimiento casa con las dos líneas (la
-- devolución y el cobro nuevo: -13,000.00 + 5,000.00 = -8,000.00). El
-- depósito y su mes no se tocan. Antes no había camino: la devolución
-- pedía el cobro entero, clasificar a 1110 no se puede, y lo único que
-- entraba (sin motivo) era a gasto o contra el ingreso, con la factura
-- cobrada.
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_devolver(p_movimiento uuid, p_cobro uuid, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m       movimientos_banco;
  v_c     cobros;
  v_ap    aplicaciones_cobro;
  v_res   jsonb;
  v_d     cobros_devoluciones;
  v_x     numeric;
  v_rebo  uuid[];
  v_n     int;
  v_opc   text;
  v_resto jsonb;
  v_nuevo cobros;
  v_mot   text := fn_banco_limpio(p_motivo);
  v_parte aplicaciones_cobro;
begin
  perform fn_banco_exigir_dueno();
  m := fn_banco_tomar(p_movimiento);
  select * into v_c from cobros where id = p_cobro;
  if not found then
    -- (la aplicación que rebotó, de un cobro de varios cheques)
    select * into v_ap from aplicaciones_cobro where id = p_cobro;
    if found then
      select * into v_c from cobros where id = v_ap.cobro_id;
    end if;
  end if;
  if v_c.id is null then
    raise exception using errcode = '22023', message = 'No existe ese cobro (ni la aplicación de uno).';
  end if;
  v_x := -m.monto;
  if m.monto >= 0 or v_c.cuenta <> m.cuenta or v_c.monto < v_x then
    raise exception using errcode = 'MX008',
      message = format('La devolución sale del banco por lo mismo que entró el cobro (%s en %s), o por un cheque de él: el '
                       'movimiento es %s en %s.', v_c.monto, v_c.cuenta, m.monto, m.cuenta);
  end if;
  if v_c.monto = v_x then
    v_res := fn_cobro_devolver(v_c.id, m.fecha, coalesce(v_mot, 'El banco lo devolvió: ' || coalesce(m.descripcion, '')), m.id::text);
    select * into v_d from cobros_devoluciones where id = (v_res->>'devolucion')::uuid;
    perform fn_banco_casar_lineas(m.id, 'devolucion', v_d.id::text, v_d.contabilizado_en,
                                  fn_banco_lineas_de(v_d.contabilizado_en, m.cuenta),
                                  'R9 cheque devuelto: Edgar confirmó el cobro', false, false, p_motivo);
    return fn_banco_resumen(p_movimiento) || jsonb_build_object('devolucion', v_d.id);
  end if;

  -- UN CHEQUE DE VARIOS: qué aplicaciones rebotaron.
  if exists (select 1 from aplicaciones_cobro x where x.cobro_id = v_c.id and (x.factura_id is null or x.desde_anticipo)) then
    raise exception using errcode = 'MX008',
      message = format('El cobro del %s por %s lleva un anticipo: la parte que rebotó no se separa sola. Devuélvelo entero '
                       '(fn_cobro_devolver) y registra otra vez lo que sí entró (fn_cobro_registrar), y casa este movimiento '
                       'con las dos líneas (fn_banco_casar_con).', v_c.fecha, v_c.monto);
  end if;
  if v_ap.id is not null then
    -- (la aplicación que dijo Edgar; o, si no suma lo devuelto, todas las
    -- de su factura: la factura y su retención en un cheque)
    if v_ap.monto = v_x then
      v_rebo := array[v_ap.id];
    elsif (select sum(x.monto) from aplicaciones_cobro x where x.cobro_id = v_c.id and x.factura_id = v_ap.factura_id) = v_x then
      select array_agg(x.id) into v_rebo from aplicaciones_cobro x where x.cobro_id = v_c.id and x.factura_id = v_ap.factura_id;
    end if;
  else
    -- (sin decir cuál: la única aplicación, o la única factura, que suma lo
    -- devuelto)
    select count(*), min(x.id::text) into v_n, v_opc from aplicaciones_cobro x where x.cobro_id = v_c.id and x.monto = v_x;
    if v_n = 1 then
      v_rebo := array[v_opc::uuid];
    else
      select count(*), min(g.f::text) into v_n, v_opc
        from (select x.factura_id as f from aplicaciones_cobro x where x.cobro_id = v_c.id
               group by x.factura_id having sum(x.monto) = v_x) g;
      if v_n = 1 then
        select array_agg(x.id) into v_rebo from aplicaciones_cobro x where x.cobro_id = v_c.id and x.factura_id = v_opc::bigint;
      end if;
    end if;
  end if;
  -- (Ronda 4) LOS DOS CHEQUES ERAN DE LA MISMA FACTURA (un cliente paga
  -- una grande con dos cheques, depositados juntos: el cobro tiene UNA
  -- aplicación de 7,000.00 y rebota el de 3,000.00): esa aplicación rebotó
  -- en PARTE. Se devuelve el cobro entero y lo que no rebotó (4,000.00, a la
  -- misma factura) se registra otra vez ese día. Antes el mensaje mandaba a
  -- pasar «su aplicación», que era la misma que ya se había pasado: no
  -- había camino, y lo único que entraba (clasificarlo contra el ingreso)
  -- dejaba la factura abonada por un cheque sin fondos.
  if v_rebo is null then
    if v_ap.id is not null and v_ap.monto > v_x and v_ap.descuento = 0 then
      v_parte := v_ap;
    elsif v_ap.id is null and (select count(*) from aplicaciones_cobro x where x.cobro_id = v_c.id) = 1 then
      select x.* into v_parte from aplicaciones_cobro x where x.cobro_id = v_c.id and x.monto > v_x and x.descuento = 0;
    end if;
    if v_parte.id is not null then
      v_rebo := array[v_parte.id];
    end if;
  end if;
  if v_rebo is null then
    select string_agg(format('%s (factura #%s%s, %s)', x.id, f.num, case when x.es_retencion then ', su retención' else '' end,
                             x.monto), '; ' order by f.num, x.es_retencion)
      into v_opc
      from aplicaciones_cobro x join facturas f on f.id = x.factura_id where x.cobro_id = v_c.id;
    raise exception using errcode = 'MX008',
      message = format('El cobro del %s por %s junta varios cheques y ninguno (o más de uno) es de %s: di cuál rebotó pasando '
                       'su aplicación en p_cobro (la de la factura de ese cheque: si era más grande, rebotó una parte y lo demás '
                       'se registra otra vez): %s.', v_c.fecha, v_c.monto, v_x, v_opc);
  end if;
  -- Lo que NO rebotó, tal como se aplicó (su factura, su retención, su
  -- descuento), para registrarlo otra vez el día de la devolución; y de la
  -- aplicación que rebotó en parte, lo que queda de ella.
  select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'factura_id', x.factura_id, 'monto', x.monto::text,
           'es_retencion', case when x.es_retencion then true end,
           'descuento', case when x.descuento > 0 then x.descuento::text end)) order by x.creado_el, x.id)
    into v_resto
    from aplicaciones_cobro x where x.cobro_id = v_c.id and not (x.id = any (v_rebo));
  if v_parte.id is not null then
    v_resto := coalesce(v_resto, '[]'::jsonb)
               || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                    'factura_id', v_parte.factura_id, 'monto', (v_parte.monto - v_x)::text,
                    'es_retencion', case when v_parte.es_retencion then true end)));
  end if;
  v_res := fn_cobro_devolver(v_c.id, m.fecha,
             format('%s (rebotó el cheque de %s de un depósito de %s: se devuelve el cobro entero y lo demás se registra otra vez '
                    'el mismo día)', coalesce(v_mot, 'El banco lo devolvió: ' || coalesce(m.descripcion, '')), v_x, v_c.monto),
             m.id::text);
  select * into v_d from cobros_devoluciones where id = (v_res->>'devolucion')::uuid;
  v_res := fn_cobro_registrar(jsonb_strip_nulls(jsonb_build_object(
             'fecha', m.fecha::text, 'monto', (v_c.monto - v_x)::text, 'cuenta', v_c.cuenta, 'medio', v_c.medio,
             'referencia', v_c.referencia, 'duplicado_confirmado', true,
             'notas', format('Lo que no rebotó del cobro del %s por %s (%s): el cheque de %s se devolvió el %s.', v_c.fecha, v_c.monto,
                             v_c.id, v_x, m.fecha),
             'aplicaciones', v_resto)));
  select * into v_nuevo from cobros where id = (v_res->>'cobro')::uuid;
  perform fn_banco_casar_lineas(m.id, 'devolucion', v_d.id::text, v_d.contabilizado_en,
                                fn_banco_lineas_de(v_d.contabilizado_en, m.cuenta)
                                || fn_banco_lineas_de(v_nuevo.contabilizado_en, m.cuenta),
                                format('R9 cheque devuelto de un depósito de varios: la devolución del cobro y lo que no rebotó '
                                       '(%s) registrado otra vez', v_c.monto - v_x), false, false, p_motivo);
  return fn_banco_resumen(p_movimiento) || jsonb_build_object('devolucion', v_d.id, 'cobro_nuevo', v_nuevo.id);
end $$;
revoke execute on function public.fn_banco_devolver(uuid, uuid, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_devolver(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- fn_banco_nomina(movimiento, líneas, motivo) — SQL Editor (sin grant a la
-- API). La nómina del proveedor ANTERIOR (antes de Gusto y de f11: la de
-- octubre a diciembre de 2026, ADP o Paychex desde Chase): el journal de
-- esa corrida entra al libro con su débito del banco, con origen
-- 'nomina_proveedor' (el journal del proveedor es la única fuente de
-- dólares de mano de obra: c3 lo reconoce por su origen, nomina…) y casa
-- con él. Sin esto, el débito de nómina de octubre dejaba la conciliación
-- de Chase sin confirmarse nunca: la bandeja decía «no se clasifica a
-- mano» (y así es) y la única salida era un costo de obra falso.
-- p_lineas: las del journal SIN la del banco (la pone esta función: el
-- movimiento), con el signo del libro (debe positivo, haber negativo), que
-- suman lo que salió del banco:
--   select fn_banco_nomina('…', '[{"cuenta": "5000", "monto": "8000.00", "proyecto_id": "…", "memo": "Sueldos 1-15 oct"},
--                                {"cuenta": "5015", "monto": "612.00", "memo": "Impuestos patronales"},
--                                {"cuenta": "2210", "monto": "-612.00", "memo": "Retenciones"}]');
-- (La nómina de Gusto entra por f11 y casa sola con su débito: esto es solo
-- para el proveedor viejo. 5010, el burden por obra, no: entra por reparto
-- desde sus bolsas, como dice c3; los impuestos patronales van a la bolsa
-- del burden real, 5015.) Lo que hace nómina a un journal es su SUELDO: la
-- mano de obra (5000, 5001, 5015) o el sueldo de oficina y el de Edgar
-- como oficial (6000, 6005), con sus retenciones. Una corrida solo del
-- oficial (el sueldo de Edgar: 6005 bruto, 2220 retenido, el neto del
-- banco) es nómina aunque no lleve mano de obra: antes se rechazaba, el
-- mensaje mandaba a clasificar y clasificar no admite la retención; solo
-- entraba el neto a 6005.
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_nomina(p_movimiento uuid, p_lineas jsonb, p_motivo text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  m        movimientos_banco;
  v_l      jsonb;
  v_i      int := 0;
  v_c      cuentas;
  v_sobra  text;
  v_monto  numeric;
  v_suma   numeric := 0;
  v_lineas jsonb;
  v_res    jsonb;
  v_mo     boolean := false;
  v_sueldo boolean := false;
  v_cxp    text := fn_puente_cuenta_de('cxp');
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501',
      message = 'La nómina del proveedor anterior se registra desde el SQL Editor (fn_banco_nomina), no desde la app.';
  end if;
  m := fn_banco_tomar(p_movimiento);
  if m.monto >= 0 or fn_banco_tipo_cuenta(m.cuenta) is distinct from 'banco' then
    raise exception using errcode = 'MX008', message = 'La nómina es un débito de un banco (sale dinero).';
  end if;
  if jsonb_typeof(p_lineas) is distinct from 'array' or jsonb_array_length(p_lineas) = 0 then
    raise exception using errcode = '22023',
      message = 'Las líneas del journal: una lista de {"cuenta", "monto"} con el signo del libro (el haber en negativo).';
  end if;
  v_lineas := jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('cuenta', m.cuenta, 'monto', m.monto::text,
                                                                     'memo', left(m.descripcion, 200))));
  for v_l in select value from jsonb_array_elements(p_lineas) loop
    v_i := v_i + 1;
    if jsonb_typeof(v_l) <> 'object' then
      raise exception using errcode = '22023', message = format('Línea %s: va como objeto JSON.', v_i);
    end if;
    select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(v_l) k
     where k not in ('cuenta', 'monto', 'proyecto_id', 'cost_code', 'co', 'fase', 'memo', 'tercero_tipo', 'tercero_id');
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Línea %s: clave desconocida: %s.', v_i, v_sobra);
    end if;
    select * into v_c from cuentas where codigo = v_l->>'cuenta';
    if not found or fn_puente_cuenta_mal(v_c.codigo) is not null then
      raise exception using errcode = 'MX004', message = format('Línea %s: %s.', v_i, coalesce(fn_puente_cuenta_mal(v_l->>'cuenta'),
                                                                                         'falta la cuenta'));
    end if;
    if fn_banco_es_propia(v_c.codigo) or v_c.codigo = m.cuenta or v_c.codigo = v_cxp
       or v_c.tipo in ('ingreso', 'otro_ingreso') then
      raise exception using errcode = 'MX008',
        message = format('Línea %s: %s no va en un journal de nómina (ni bancos ni tarjetas, ni %s, ni ingresos).', v_i, v_c.codigo,
                         v_cxp);
    end if;
    if fn_puente_es_mano_de_obra(v_c.codigo) and v_c.regla_obra <> 'prohibida'
       and v_c.codigo not in (fn_puente_cuenta_de('mano_obra'), fn_puente_cuenta_de('mano_obra_oficial')) then
      raise exception using errcode = 'MX008',
        message = format('Línea %s: %s (el burden por obra) entra por reparto desde sus bolsas, no desde el journal: los '
                         'impuestos patronales van a la bolsa del burden real (5015).', v_i, v_c.codigo);
    end if;
    v_mo := v_mo or fn_puente_es_mano_de_obra(v_c.codigo);
    v_monto := fn_banco_saldo_texto(v_l->>'monto', format('Línea %s: el monto', v_i));
    if v_monto is null or v_monto = 0 then
      raise exception using errcode = 'MX005', message = format('Línea %s: el monto, con su signo (el haber en negativo).', v_i);
    end if;
    v_sueldo := v_sueldo or (v_c.codigo in ('6000', '6005') and v_monto > 0);
    v_suma := v_suma + v_monto;
    v_lineas := v_lineas || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                  'cuenta', v_c.codigo, 'monto', v_monto::text,
                  'proyecto_id', fn_banco_limpio(v_l->>'proyecto_id'), 'cost_code', fn_banco_limpio(v_l->>'cost_code'),
                  'co', fn_banco_limpio(v_l->>'co'), 'fase', fn_banco_limpio(v_l->>'fase'),
                  'memo', coalesce(fn_banco_limpio(v_l->>'memo'), left(m.descripcion, 200)),
                  'tercero_tipo', fn_banco_limpio(v_l->>'tercero_tipo'), 'tercero_id', fn_banco_limpio(v_l->>'tercero_id'))));
  end loop;
  if v_suma <> -m.monto then
    raise exception using errcode = 'MX001',
      message = format('Las líneas del journal suman %s y del banco salieron %s: tienen que dar lo mismo, al centavo (el haber en '
                       'negativo).', v_suma, -m.monto);
  end if;
  if not (v_mo or v_sueldo) then
    raise exception using errcode = 'MX008',
      message = 'Un journal de nómina lleva su sueldo: la mano de obra (5000, 5001 o la bolsa del burden real, 5015) o el sueldo de '
                'oficina o de oficiales (6000, 6005), con sus retenciones (2210, 2220…) y el neto que salió del banco. Si no es '
                'nómina, clasifícalo (fn_banco_clasificar) con su motivo.';
  end if;
  v_res := fn_banco_asiento_edgar('nomina_proveedor', m.id::text, m.fecha,
             'Nómina del proveedor anterior (su journal): ' || coalesce(m.descripcion, ''), v_lineas,
             fn_banco_proc(m, 'fn_banco_nomina', 'R6 nómina del proveedor anterior (su journal)')
             || jsonb_strip_nulls(jsonb_build_object('motivo_edgar', fn_banco_limpio(p_motivo))));
  perform fn_banco_casar_lineas(m.id, 'asiento', v_res->>'numero', (v_res->>'id')::uuid,
                                jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 1)),
                                'R6 nómina del proveedor anterior: su journal (registrado desde el SQL Editor)', false, true, p_motivo);
  return fn_banco_resumen(p_movimiento) || jsonb_build_object('asiento', v_res->>'numero');
end $$;
revoke execute on function public.fn_banco_nomina(uuid, jsonb, text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_banco_descasar(movimiento, motivo) — deshace un casado (o un
-- «ignorado»), con su motivo y con rastro, sin editar el libro:
--   · si el casado posteó su asiento (una transferencia, un pago a
--     proveedor, una cuota, una regla fija, una clasificación), ese asiento
--     se REVERSA por su camino (fn_reversar_interno, con el motivo) y queda
--     enlazado (reverso_id); una transferencia suelta también su otro
--     lado; una cuota queda anulada;
--   · si casó con un papel que ya estaba (un ticket, un cobro, una
--     devolución, un asiento), solo se suelta: su asiento es de su papel
--     (un cobro pierde su movimiento_id: lo deja c3 con su marca);
--   · el movimiento vuelve a pendiente, con su propuesta; lo que Edgar
--     des-casó no vuelve a casar solo (lo elige él).
-- Dentro de una conciliación confirmada no se des-casa: se reabre antes
-- (fn_conciliacion_reabrir, con su motivo).
-- ---------------------------------------------------------------------
-- (Lo que deshace, sin mirar la conciliación ni volver a proponer: lo
-- llaman fn_banco_descasar y el cambio de una clasificación por su
-- ticket, que ya miraron.)
create or replace function public.fn_banco_descasar_interno(p_mov uuid, p_motivo text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  m     movimientos_banco;
  c     banco_casados;
  x     banco_casados;
  v_rev jsonb;
  v_msg text;
begin
  select * into m from movimientos_banco where id = p_mov;
  select * into c from banco_casados where id = m.casado_id;
  if c.posteado then
    -- El asiento lo puso este casado: se reversa, y se sueltan todos los
    -- casados vivos con él (la otra mitad de una transferencia también).
    -- Si la otra mitad está en una conciliación confirmada, no: se dice
    -- CUÁL (su cuenta y su fecha de corte) y cómo se reabre; antes decía
    -- «reábrela antes» sin decir cuál, y con varias cuentas y meses había
    -- que buscarla a mano.
    select format('La otra mitad de esta transferencia (%s del %s por %s) está en la conciliación de %s al %s, confirmada: '
                  'reábrela antes (fn_conciliacion_reabrir, con su motivo), des-cásala y vuelve a conciliarla.',
                  mm.cuenta, mm.fecha, mm.monto, cc.cuenta, cc.fecha_corte)
      into v_msg
      from banco_casados bx
      join movimientos_banco mm on mm.id = bx.movimiento_id
      join conciliaciones cc on cc.cuenta = mm.cuenta and cc.estado = 'confirmada' and cc.fecha_corte >= mm.fecha
     where bx.asiento_id = c.asiento_id and bx.deshecho_el is null and bx.movimiento_id <> m.id
     order by cc.fecha_corte, cc.cuenta
     limit 1;
    if v_msg is not null then
      raise exception using errcode = 'MX008', message = v_msg;
    end if;
    v_rev := fn_reversar_interno(c.asiento_id, p_motivo, 'reverso',
                                 jsonb_build_object('funcion', 'fn_banco_descasar', 'movimiento', m.id));
    for x in select * from banco_casados where asiento_id = c.asiento_id and deshecho_el is null loop
      perform fn_banco_marca('descasar:' || x.movimiento_id);
      update banco_casados
         set deshecho_motivo = case when x.id = c.id then p_motivo
                                    else 'Se deshizo su otra mitad (' || m.id || '): ' || p_motivo end,
             reverso_id = (v_rev->>'id')::uuid
       where id = x.id;
      update banco_casado_lineas set vigente = false where casado_id = x.id and vigente;
      perform fn_banco_marca('movimiento:' || x.movimiento_id);
      update movimientos_banco
         set estado = 'pendiente', estado_motivo = null, propuesta = null, casado_id = null, casado_clase = null, casado_ref = null,
             asiento_id = null, casado_regla = null, casado_auto = null, casado_por = null, casado_el = null
       where id = x.movimiento_id;
      perform fn_banco_marca(null);
      if x.clase = 'cuota_prestamo' then
        perform fn_banco_marca('cuota:' || x.referencia);
        update prestamo_cuotas set anulada_motivo = p_motivo where id = x.referencia::uuid and anulada_el is null;
        perform fn_banco_marca(null);
      end if;
    end loop;
  else
    perform fn_banco_marca('descasar:' || m.id);
    update banco_casados set deshecho_motivo = p_motivo where id = c.id;
    update banco_casado_lineas set vigente = false where casado_id = c.id and vigente;
    -- (lo que el banco puso junto al papel, la comisión de un cobro con
    -- tarjeta, se reversa con el casado)
    perform fn_banco_anexos_reversar(c.id, p_motivo);
    perform fn_banco_marca('movimiento:' || m.id);
    update movimientos_banco
       set estado = 'pendiente', estado_motivo = null, propuesta = null, casado_id = null, casado_clase = null, casado_ref = null,
           asiento_id = null, casado_regla = null, casado_auto = null, casado_por = null, casado_el = null
     where id = m.id;
    perform fn_banco_marca(null);
    if c.clase = 'cobro' then
      -- (La marca de c3: suelta el movimiento del cobro; sin ella, c3 no lo deja.)
      perform set_config('mx_puente.escribe', 'cobros_descasar:' || c.referencia, true);
      update cobros set movimiento_id = null where id = c.referencia::uuid and movimiento_id = m.id::text;
      perform set_config('mx_puente.escribe', '', true);
    elsif c.clase = 'apertura' then
      -- (la partida, al día: lo que queda casado con ella)
      perform fn_banco_apertura_resolver(c.referencia::uuid);
    elsif c.clase = 'transferencia' then
      perform fn_banco_transferencia_estado(c.asiento_id);
    end if;
  end if;
  return jsonb_strip_nulls(jsonb_build_object('deshecho', c.clase, 'reverso', v_rev->>'numero', 'reverso_id', v_rev->>'id'));
end $$;
revoke execute on function public.fn_banco_descasar_interno(uuid, text) from public, anon, authenticated, service_role;

create or replace function public.fn_banco_descasar(p_movimiento uuid, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m        movimientos_banco;
  v_conc   conciliaciones;
  v_res    jsonb;
  v_motivo text := fn_banco_limpio(p_motivo);
begin
  perform fn_banco_exigir_dueno();
  if coalesce(length(v_motivo), 0) < 3 then
    raise exception using errcode = '22023', message = 'Des-casar dice por qué (motivo): queda escrito.';
  end if;
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  select * into m from movimientos_banco where id = p_movimiento for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese movimiento del banco.';
  end if;
  if m.estado = 'pendiente' then
    raise exception using errcode = 'MX008', message = 'Ese movimiento está pendiente: no hay nada que des-casar.';
  end if;
  -- (Ronda 4: el de un archivo retirado —entró a la cuenta equivocada— no
  -- vuelve: se sube su archivo a la cuenta buena.)
  if exists (select 1 from archivos_banco a where a.id = m.archivo_id and a.retirado_el is not null) then
    raise exception using errcode = 'MX008',
      message = format('Ese movimiento es de un archivo retirado de %s (entró a la cuenta equivocada): no vuelve. Sube su archivo a la '
                       'cuenta buena.', m.cuenta);
  end if;
  -- Uno de antes del corte casado con una partida de la apertura (el
  -- statement cortó antes del 30-sep: fn_banco_apertura_previas) se suelta
  -- de ella y vuelve a ignorado, con su motivo de siempre. Dentro de una
  -- conciliación confirmada no (la partida ya no estaba en tránsito en
  -- ella): se reabre antes, de la última hacia atrás.
  if m.fecha < fn_puente_corte() and m.estado = 'casado' and m.casado_clase = 'apertura' then
    select * into v_conc from conciliaciones cc
     where cc.cuenta = m.cuenta and cc.estado = 'confirmada' and cc.tipo = 'normal'
     order by cc.fecha_corte desc limit 1;
    if found then
      raise exception using errcode = 'MX008',
        message = format('Esa partida de la apertura ya contó como llegada en las conciliaciones confirmadas de %s: reábrelas antes, de '
                         'la última (la del %s) hacia atrás (fn_conciliacion_reabrir, con su motivo), des-cásalo y vuelve a '
                         'conciliarlas.', v_conc.cuenta, v_conc.fecha_corte);
    end if;
    v_res := fn_banco_descasar_interno(m.id, v_motivo);
    perform fn_banco_marca('movimiento:' || m.id);
    update movimientos_banco
       set estado = 'ignorado', propuesta = null,
           estado_motivo = format('Del %s, antes del corte (%s): está en QuickBooks y en el saldo de apertura. Si seguía en tránsito al '
                                  '30-sep, lo dice la conciliación de apertura.', m.fecha, fn_puente_corte())
     where id = m.id;
    perform fn_banco_marca(null);
    return fn_banco_resumen(p_movimiento) || jsonb_build_object('deshecho', 'apertura', 'motivo_deshecho', v_motivo);
  end if;
  if m.fecha < fn_puente_corte() then
    raise exception using errcode = 'MX002', message = 'Ese movimiento es de antes del corte: está en QuickBooks y se queda ignorado.';
  end if;
  select * into v_conc from conciliaciones cc
   where cc.cuenta = m.cuenta and cc.estado = 'confirmada' and cc.fecha_corte >= m.fecha
   order by cc.fecha_corte limit 1;
  if found then
    raise exception using errcode = 'MX008',
      message = format('La conciliación de %s al %s está confirmada con este movimiento: reábrela antes (fn_conciliacion_reabrir, '
                       'con su motivo), des-cásalo y vuelve a conciliar.', v_conc.cuenta, v_conc.fecha_corte);
  end if;
  if m.estado = 'ignorado' then
    perform fn_banco_marca('movimiento:' || m.id);
    update movimientos_banco
       set estado = 'pendiente', estado_motivo = null, propuesta = null,
           duplicado = case when duplicado = 'es_el_mismo' then null else duplicado end
     where id = m.id;
    perform fn_banco_marca(null);
    perform fn_banco_casar_interno(null, null, m.id, true);
    return fn_banco_resumen(p_movimiento) || jsonb_build_object('deshecho', 'ignorado', 'motivo_deshecho', v_motivo);
  end if;
  v_res := fn_banco_descasar_interno(m.id, v_motivo);
  perform fn_banco_casar_interno(null, null, m.id, true);
  return fn_banco_resumen(p_movimiento)
         || jsonb_strip_nulls(jsonb_build_object('deshecho', v_res->>'deshecho', 'motivo_deshecho', v_motivo,
                                                 'reverso', v_res->>'reverso'));
end $$;
revoke execute on function public.fn_banco_descasar(uuid, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_descasar(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- fn_banco_descriptor(clave, patron, cuenta, notas) — el SQL Editor ajusta
-- lo que se reconoce en la descripción de un movimiento (1.2), con
-- rastro. Ninguno postea por sí solo (ver 1.2). No es de la API.
--   select fn_banco_descriptor('zelle_edgar', 'ZELLE (PAYMENT )?FROM EDGAR (M )?APELLIDO');
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_descriptor(p_clave text, p_patron text, p_cuenta text default null,
                                                      p_notas text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_d banco_descriptores;
begin
  perform fn_banco_exigir_dueno();
  select * into v_d from banco_descriptores where clave = p_clave;
  if not found then
    raise exception using errcode = '22023',
      message = format('«%s» no es un descriptor del banco (%s).', p_clave,
                       (select string_agg(d.clave, ', ' order by d.clave) from banco_descriptores d));
  end if;
  if p_cuenta is not null and fn_puente_cuenta_mal(p_cuenta) is not null then
    raise exception using errcode = 'MX004', message = fn_puente_cuenta_mal(p_cuenta);
  end if;
  perform fn_banco_marca('descriptor:' || p_clave);
  update banco_descriptores
     set patron = coalesce(fn_banco_limpio(p_patron), patron), cuenta = coalesce(p_cuenta, cuenta),
         notas = coalesce(fn_banco_limpio(p_notas), notas)
   where clave = p_clave
  returning * into v_d;
  perform fn_banco_marca(null);
  return to_jsonb(v_d);
end $$;
revoke execute on function public.fn_banco_descriptor(text, text, text, text) from public, anon, authenticated, service_role;
-- =====================================================================
-- 6 · LA CONCILIACIÓN (f06: de verdad, no igualdad)
-- =====================================================================
--   saldo en libros = saldo del statement + depósitos en tránsito
--                     − cheques y cargos en circulación
-- con las partidas guardadas por conciliación, cada una con su clic al
-- asiento o al movimiento. A la fecha de corte C de una cuenta:
--   · el saldo en libros: todas sus líneas hasta C (con el signo de c2:
--     en un banco, lo que hay; en una tarjeta, lo que se debe en negativo);
--   · lo que está en el libro y el banco no trae a esa fecha («solo en
--     libros»): cada línea desde el corte sin su movimiento de C o antes
--     (un cheque que el banco cobra después, el pago de la Amex visto en
--     Chase que la Amex trae el 2-nov), y las partidas de la conciliación
--     de apertura que el banco todavía no trajo. Tienen su clase (depósito
--     en tránsito, cheque o cargo en circulación, error) y su motivo, y no
--     impiden confirmar; con más de 30 días son ALARMA (se dice, no frena);
--   · lo que el banco trae y el libro no («solo en el banco»): un
--     movimiento pendiente, o casado con un asiento posterior al corte.
--     BLOQUEA: se casa o se clasifica antes de confirmar. Salvo el que el
--     libro no PUEDE tener antes: casado con un papel que llegó con su mes
--     ya cerrado (tardío: el ticket del 30-oct que se subió el 7-nov entra
--     el 1-nov), o con el mes del corte ya cerrado. Ese es una partida
--     explicada («en_libros_despues»): cuenta en la identidad, no frena y
--     desaparece en la conciliación siguiente. Antes frenaba para siempre:
--     octubre no se reabre y el mensaje mandaba a casar lo ya casado;
--   · el POSIBLE DUPLICADO: la línea libre de un ticket que llegó después
--     de clasificar su cargo (fn_banco_tickets_llegados). No es un cargo en
--     circulación (así se confirmaba el gasto dos veces): BLOQUEA hasta que
--     Edgar la cambie por la clasificación (fn_banco_casar_con) o diga que
--     es otra compra (fn_banco_duplicado);
--   · la diferencia: saldo en libros − (saldo del banco + solo en libros −
--     solo en el banco). Se confirma con 0.00 y nada que bloquee.
-- Lo reversado dentro del corte (el asiento y su reverso) no cuenta. Un
-- casado se mira por su PAPEL (el recibo, el cobro, el movimiento que
-- originó el asiento) y no por su asiento: si c3 rehace un ticket en el
-- mes siguiente, a la fecha de antes vale su asiento de entonces y a la de
-- después el que lo sustituye, y una conciliación ya confirmada no cambia.
-- Una tarjeta se concilia a su fecha de corte (la del statement), no a fin
-- de mes: la fecha de corte es la que Edgar diga.
-- ---------------------------------------------------------------------

-- La clave con que se casan las líneas del libro con los movimientos: el
-- papel (origen del asiento), la cuenta y el monto; sin papel (un asiento
-- a mano), la línea misma.
create or replace function public.fn_banco_clave(p_origen_tabla text, p_origen_id text, p_asiento uuid, p_orden int, p_cuenta text,
                                                 p_monto numeric)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case when p_origen_tabla is null then 'a:' || p_asiento::text || ':' || p_orden
              else 'd:' || p_origen_tabla || ':' || p_origen_id || ':' || p_cuenta || ':' || p_monto::text end
$$;
revoke execute on function public.fn_banco_clave(text, text, uuid, int, text, numeric) from public, anon, authenticated, service_role;

-- LAS PARTIDAS de una cuenta a una fecha de corte (sin escribir nada en
-- las tablas del banco): lo que no casa, con su explicación en palabras.
-- La usan fn_conciliar (que las guarda, con su pareja) y la revisión (que
-- las recalcula para ver si una conciliación confirmada sigue dando lo
-- mismo; sin la pareja, p_pareja = false).
-- LA PAREJA de lo que el banco trae sin su línea se busca aparte, sobre las
-- partidas ya calculadas y puestas en una tabla temporal con sus
-- estadísticas (analyze): así se juntan por clave (la fecha, el monto que
-- falta) y no cada partida del banco con cada línea del libro y cada día.
-- Antes era una sola consulta sobre CTEs que el planificador creía de una
-- fila: con un mes recién importado sin casar, 3 a 7 s solo en la pareja,
-- y con dos meses la API la cortaba (57014).
-- Las partidas de la conciliación de APERTURA cuentan por lo que falta que
-- llegue: una que el banco trajo en dos depósitos (casados con ella, cada
-- uno con su parte) sale por lo que queda; completa, ya no sale.
drop function if exists public.fn_conciliacion_items(text, date);
create or replace function public.fn_conciliacion_items(p_cuenta text, p_corte date, p_pareja boolean default true)
returns table (lado text, clase text, asiento_id uuid, orden int, movimiento_id uuid, apertura_partida_id uuid, fecha date,
               monto numeric, descripcion text, cheque text, numero text, explicacion text, pareja jsonb)
language plpgsql
set search_path = public, pg_temp
set jit = off
as $f$
begin
  -- (La tabla temporal, siempre por su esquema, pg_temp: una tabla con el
  -- mismo nombre en public no la sustituye. Y creada una sola vez por
  -- transacción, sin el aviso «already exists» en el SQL Editor.)
  if to_regclass('pg_temp._mx_conc_items') is null then
    create temp table _mx_conc_items (
      lado text, clase text, asiento_id uuid, orden int, movimiento_id uuid, apertura_partida_id uuid, fecha date, monto numeric,
      descripcion text, cheque text, numero text, explicacion text) on commit drop;
  else
    truncate pg_temp._mx_conc_items;
  end if;
  insert into pg_temp._mx_conc_items
  with
  k as (select fn_puente_corte() as corte0,
               (select p.periodo from periodos p where p.tipo = 'apertura' order by p.desde limit 1) as ap),
  -- Las líneas vivas al corte (sin la apertura; sin lo reversado dentro
  -- del corte, ni sus reversos).
  lv as (
    select l.asiento_id, l.orden, l.monto, a.fecha_contable as fecha, a.numero, coalesce(l.memo, a.descripcion) as descripcion,
           (a.tipo = 'ajuste_cpa' and a.afecta_periodo = k.ap) as ajuste_apertura,
           fn_banco_clave(a.origen_tabla, a.origen_id, a.id, l.orden, l.cuenta, l.monto) as clave,
           -- (qué es: el ticket de una compra con tarjeta o débito, o la
           -- transferencia que puso el banco: los dos llegan al banco en
           -- días, y en tránsito más de 10 piden su motivo)
           case when a.origen_tabla = 'recibos' then 'recibo'
                when a.origen_tabla = 'movimientos_banco' and a.procedencia->>'regla' like 'R3%' then 'transferencia'
                -- (ronda 4: y el cobro ya anotado, que se deposita en días)
                when a.origen_tabla = 'cobros' then 'cobro'
                -- (y la cuota de un préstamo registrada antes que el banco: el
                -- prestamista la cobra el día que toca)
                when a.origen_tabla = 'prestamo_cuotas' then 'cuota' end as es
      from asiento_lineas l
      join asientos a on a.id = l.asiento_id
      cross join k
     where l.cuenta = p_cuenta and a.fecha_contable between k.corte0 and p_corte
       and a.tipo <> 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
       and not exists (select 1 from asientos r
                        where r.reversa_a = a.id and r.camino in ('reverso', 'reverso_automatico') and r.fecha_contable <= p_corte)),
  -- Lo casado a esa fecha: las claves de las líneas de cada casado vivo de
  -- un movimiento de la cuenta de C o antes.
  mc as (
    select m.id as mov, m.fecha, fn_banco_clave(a.origen_tabla, a.origen_id, a.id, bl.orden, bl.cuenta, bl.monto) as clave
      from movimientos_banco m
      join banco_casados bc on bc.id = m.casado_id and bc.deshecho_el is null
      join banco_casado_lineas bl on bl.casado_id = bc.id and bl.vigente
      join asientos a on a.id = bl.asiento_id
      cross join k
     where m.cuenta = p_cuenta and m.fecha between k.corte0 and p_corte),
  lvn as (select lv.*, row_number() over (partition by lv.clave order by lv.fecha, lv.numero, lv.orden) as n from lv),
  mcn as (select mc.*, row_number() over (partition by mc.clave order by mc.fecha, mc.mov) as n from mc),
  solo_libro as (select lvn.* from lvn where not exists (select 1 from mcn where mcn.clave = lvn.clave and mcn.n = lvn.n)),
  mov_sin_linea as (select distinct mcn.mov from mcn where not exists (select 1 from lvn where lvn.clave = mcn.clave and lvn.n = mcn.n)),
  -- Las partidas de la apertura (confirmada) que el banco no trajo a esa
  -- fecha, por lo que falta: su monto menos lo que ya llegó (los
  -- movimientos casados con ella, de C o antes).
  ap as (
    select pa.id, pa.clase, pa.fecha, pa.monto - coalesce(x.llego, 0) as monto, pa.monto as total, pa.descripcion, pa.cheque
      from conciliacion_partidas pa
      join conciliaciones c on c.id = pa.conciliacion_id
      left join lateral (select sum(mm.monto) as llego
                           from banco_casados bc
                           join movimientos_banco mm on mm.id = bc.movimiento_id
                          where bc.clase = 'apertura' and bc.deshecho_el is null and bc.referencia = pa.id::text
                            and mm.fecha <= p_corte and mm.estado <> 'pendiente') x on true
     where c.cuenta = p_cuenta and c.tipo = 'apertura' and c.estado = 'confirmada' and pa.lado = 'libro'
       and pa.monto - coalesce(x.llego, 0) <> 0),
  -- Un «error» de la apertura (QuickBooks tenía el banco mal) y el ajuste a
  -- la apertura que lo corrige (en el mes abierto, contra 3900) se anulan:
  -- por monto contrario, el primero con el primero.
  ape as (select ap.*, row_number() over (partition by ap.monto order by ap.fecha, ap.id) as n from ap where ap.clase = 'error'),
  aje as (select sl.*, row_number() over (partition by sl.monto order by sl.fecha, sl.numero, sl.orden) as n2
            from solo_libro sl where sl.ajuste_apertura),
  par as (select ape.id as partida, aje.asiento_id, aje.orden from ape join aje on aje.monto = -ape.monto and aje.n2 = ape.n),
  apd as (select x.partida, x.texto from fn_banco_apertura_casadas(p_cuenta, null) x),
  -- Lo del banco sin su línea a esa fecha. «despues»: casado con un papel
  -- que el libro no puede tener antes (tardío, o el mes del corte cerrado).
  sb as (
    select m.*,
           (m.estado <> 'pendiente'
            and (exists (select 1 from banco_casado_lineas bl join asientos a on a.id = bl.asiento_id
                          where bl.casado_id = m.casado_id and bl.vigente and a.procedencia ? 'tardio')
                 or exists (select 1 from periodos p
                             where p.tipo = 'mes' and p_corte between p.desde and p.hasta and p.estado = 'cerrado'))) as despues
      from movimientos_banco m, k
     where m.cuenta = p_cuenta and m.fecha between k.corte0 and p_corte and m.estado <> 'ignorado'
       and (m.estado = 'pendiente' or m.id in (select mov_sin_linea.mov from mov_sin_linea))
       and not (m.estado <> 'pendiente' and m.casado_clase = 'apertura')),
  -- Los tickets que llegaron después de clasificar su cargo (el cargo, de
  -- esta cuenta y de esta fecha o antes).
  -- (Ronda 4: con lo que Edgar dijo que no era —descartado—, para nombrar
  -- en la explicación de más de 10 días el cargo clasificado que suma un
  -- ticket repartido entre obras; y la parte de un repartido, como tal)
  tt as materialized (select t.* from fn_banco_tickets_llegados(array[p_cuenta], null, true) t where t.fecha <= p_corte),
  tl as (select t.asiento_id, t.orden, min(t.fecha) as fecha, min(t.monto) as monto, min(t.movimiento_id::text) as mov,
                min(t.repartido) as repartido
           from tt t
          where not t.descartado
          group by t.asiento_id, t.orden),
  tg as (select t.asiento_id, t.orden, min(t.fecha) as fecha, min(t.monto) as monto, min(t.movimiento_id::text) as mov,
                min(t.repartido) as repartido
           from tt t
          where t.descartado and t.repartido is not null
          group by t.asiento_id, t.orden)
  select 'libro'::text as lado,
         case when sl.ajuste_apertura then 'error'
              when tl.asiento_id is not null then 'posible_duplicado'
              when sl.monto > 0 then 'deposito_en_transito' else 'cargo_en_circulacion' end as clase,
         sl.asiento_id, sl.orden, null::uuid as movimiento_id, null::uuid as apertura_partida_id, sl.fecha, sl.monto,
         sl.descripcion, null::text as cheque, sl.numero,
         case when sl.ajuste_apertura
              then 'Ajuste a la apertura (corrige el saldo que traía QuickBooks): no pasa por el banco.'
              when tl.asiento_id is not null and tl.repartido is not null
              then format('¿Duplicado? Es parte de un ticket repartido entre obras (la misma foto: los recibos %s, que suman %s) que '
                          'es el cargo del %s por %s, que se clasificó antes de que llegara: el gasto estaría dos veces. Si es su '
                          'ticket, cámbialo (fn_banco_casar_con del movimiento %s con las líneas de esos recibos; la bandeja lo '
                          'ofrece: «Es su ticket (repartido)»); si es otra compra, dilo (fn_banco_duplicado, false, con su motivo). '
                          'Frena la confirmación.', replace(tl.repartido, ',', ', '), -tl.monto, tl.fecha, tl.monto, tl.mov)
              when tl.asiento_id is not null and tl.monto <> sl.monto
              then format('¿Duplicado? Es un ticket del mismo comercio que el cargo del %s por %s, que se clasificó, con OTRO '
                          'total (%s): ¿se leyó sin el tax, o mal? El gasto estaría dos veces. Corrige su total en la app (✎) y '
                          'cámbialo por la clasificación (fn_banco_casar_con del movimiento %s con este recibo); si es otra '
                          'compra, dilo (fn_banco_duplicado, false, con su motivo). Frena la confirmación.',
                          tl.fecha, tl.monto, sl.monto, tl.mov)
              when tl.asiento_id is not null
              then format('¿Duplicado? Es el ticket del cargo del %s por %s, que se clasificó antes de que llegara: el gasto '
                          'estaría dos veces. Si es su ticket, cámbialo (fn_banco_casar_con del movimiento %s con este recibo); '
                          'si es otra compra, dilo (fn_banco_duplicado, false, con su motivo). Frena la confirmación.',
                          tl.fecha, tl.monto, tl.mov)
              when despues.fecha is not null
              then format('En tránsito: %s del %s que el banco trae el %s, después del corte.',
                          case when sl.monto > 0 then 'depósito' else 'cheque o cargo' end, sl.fecha, despues.fecha)
              -- (El ticket de una compra con tarjeta o débito, o una
              -- transferencia, que lleva más de 10 días sin su movimiento: la
              -- tarjeta postea en 1 a 3 días y el emisor acredita el pago en
              -- 1 a 3. No es un cargo en circulación normal: ¿el cargo llegó
              -- con otro total y se clasificó (el gasto dos veces)? ¿la
              -- transferencia se puso dos veces? Pide su motivo, como las
              -- partidas de la apertura. Antes era un «cheque o cargo en
              -- circulación» más y la conciliación se confirmaba así.)
              -- (Ronda 4: si es parte de un ticket repartido entre obras cuyas
              -- partes suman un cargo clasificado —y Edgar dijo que no era—,
              -- se nombra ese cargo. Antes mandaba a corregir el total de un
              -- ticket que estaba bien.)
              when sl.es = 'recibo' and p_corte - sl.fecha > 10 and tg.asiento_id is not null
              then format('El ticket %s del %s lleva %s días sin su cargo en el banco, y es parte de un ticket repartido entre obras '
                          '(la misma foto: los recibos %s, que suman %s) que es el cargo del %s por %s, clasificado (movimiento %s): '
                          'se dijo que no era su ticket, pero así el gasto está dos veces. Si lo es, cámbialo (fn_banco_casar_con del '
                          'movimiento %s con las líneas de esos recibos); si no, di por qué sigue en tránsito '
                          '(fn_conciliacion_partida, con su motivo).', sl.numero, sl.fecha, p_corte - sl.fecha,
                          replace(tg.repartido, ',', ', '), -tg.monto, tg.fecha, tg.monto, tg.mov, tg.mov)
              when sl.es = 'recibo' and p_corte - sl.fecha > 10
              then format('El ticket %s del %s lleva %s días sin su cargo en el banco (la tarjeta lo postea en 1 a 3 días): ¿llegó con '
                          'otro total y se clasificó (el recibo sin el tax, o mal leído)? Corrige el recibo con ✎ y cámbialo por la '
                          'clasificación, o di por qué sigue en tránsito (fn_conciliacion_partida, con su motivo).', sl.numero, sl.fecha,
                          p_corte - sl.fecha)
              when sl.es = 'transferencia' and p_corte - sl.fecha > 10
              then format('La transferencia %s del %s lleva %s días sin su movimiento en este estado de cuenta (el otro banco o la '
                          'tarjeta la trae en días): ¿se puso dos veces (una desde cada estado de cuenta)? Si sí, des-casa la de '
                          'más; si no, di por qué sigue en tránsito (fn_conciliacion_partida, con su motivo).', sl.numero, sl.fecha,
                          p_corte - sl.fecha)
              -- (Ronda 4: el cobro anotado que lleva más de 10 días sin su
              -- depósito: ¿llegó por otro monto —el cheque anotado mal, el
              -- cobro con tarjeta depositado neto— y se registró otro? Antes
              -- era un «depósito en tránsito» más y los meses se confirmaban
              -- con dinero que no existía.)
              when sl.es = 'cuota' and p_corte - sl.fecha > 10
              then format('La cuota del préstamo %s del %s lleva %s días sin su cargo en el banco (el prestamista la cobra el día que '
                          'toca): ¿la cobró por otro monto (redondeada, con un recargo) y se registró otra? Cásala con su cargo '
                          '(fn_banco_casar_con con {"cuota": …, "diferencia": …}), o di por qué sigue en tránsito '
                          '(fn_conciliacion_partida, con su motivo).', sl.numero, sl.fecha, p_corte - sl.fecha)
              when sl.es = 'cobro' and p_corte - sl.fecha > 10
              then format('El cobro %s del %s lleva %s días sin su depósito en el banco (un cheque se deposita en días): ¿llegó por '
                          'otro monto (el cheque anotado mal, o neto de la comisión de la tarjeta) y se registró otro cobro? Cásalo '
                          'con su depósito (fn_banco_casar_con con el cobro, «comision» o «corrige»), o di por qué sigue en tránsito '
                          '(fn_conciliacion_partida, con su motivo).', sl.numero, sl.fecha, p_corte - sl.fecha)
              else format('En libros, no en el banco: %s desde el %s.',
                          case when sl.monto > 0 then 'depósito en tránsito' else 'cheque o cargo en circulación' end, sl.fecha) end
           as explicacion
    from solo_libro sl
    left join lateral (select min(mm.fecha) as fecha
                         from banco_casado_lineas bl
                         join banco_casados bc on bc.id = bl.casado_id and bc.deshecho_el is null
                         join movimientos_banco mm on mm.id = bc.movimiento_id
                        where bl.asiento_id = sl.asiento_id and bl.orden = sl.orden and bl.vigente and mm.fecha > p_corte) despues
      on true
    left join tl on tl.asiento_id = sl.asiento_id and tl.orden = sl.orden
    left join tg on tg.asiento_id = sl.asiento_id and tg.orden = sl.orden and tl.asiento_id is null
   where not exists (select 1 from par where par.asiento_id = sl.asiento_id and par.orden = sl.orden)
  union all
  -- (Ronda 4: la partida que el banco ya trajo y se casó con OTRA cosa
  -- —el cheque 1038 clasificado al costo antes de conciliar la apertura—
  -- es un posible duplicado: frena, y dice cuál y qué hacer)
  select 'libro', case when apd.partida is not null then 'posible_duplicado' else ap.clase end, null, null, null, ap.id, ap.fecha,
         ap.monto, ap.descripcion, ap.cheque, null,
         format('De la era QuickBooks (conciliación de apertura): %s desde el %s%s%s.',
                case ap.clase when 'error' then 'error de la apertura' when 'deposito_en_transito' then 'depósito en tránsito'
                              else 'cheque o cargo en circulación' end, ap.fecha, coalesce(', cheque ' || ap.cheque, ''),
                case when ap.monto <> ap.total then format(' (llegó una parte: faltan %s de %s)', ap.monto, ap.total) else '' end)
         || coalesce(' ¿Entró dos veces? ' || apd.texto || '. Frena la confirmación.', '')
    from ap
    left join apd on apd.partida = ap.id
   where not exists (select 1 from par where par.partida = ap.id)
  union all
  select 'banco', case when sb.despues then 'en_libros_despues' else 'sin_casar' end, null, null, sb.id, null, sb.fecha, sb.monto,
         sb.descripcion,
         -- (el número del cheque: el de CHECKNUM, o el de NAME)
         coalesce(nullif(ltrim(sb.cheque, '0'), ''),
                  substring(sb.desc_norm from '(?:^| )(?:CHECK|CHK|CHEQUE|CK)(?: NO)? ?#? ?0*([1-9][0-9]{0,9})(?: |$)')),
         null,
         case when sb.estado = 'pendiente'
              then format('En el banco, no en libros: %s.',
                          rtrim(coalesce(sb.propuesta->>'texto', 'falta casarlo o clasificarlo'), '.'))
              when sb.despues
              then format('En el banco el %s; en libros después (%s), porque %s: no puede ir antes. Se explica aquí, no frena, '
                          'y desaparece en la conciliación siguiente.', sb.fecha,
                          (select a.numero || ' del ' || a.fecha_contable from asientos a where a.id = sb.asiento_id),
                          case when exists (select 1 from banco_casado_lineas bl join asientos a on a.id = bl.asiento_id
                                             where bl.casado_id = sb.casado_id and bl.vigente and a.procedencia ? 'tardio')
                               then 'su papel llegó con el mes ya cerrado (documento tardío)'
                               else 'el mes del corte está cerrado' end)
              -- (Ronda 4: la transferencia que se fechó después del corte de
              -- la confirmada de la OTRA cuenta, sin saberse que este estado
              -- de cuenta cortaba en medio —una tarjeta sin conciliaciones
              -- todavía—: se dice qué reabrir y a quién des-casar. Antes
              -- solo «el libro lo tiene después», y «falta» mandaba a casar
              -- lo que ya estaba casado.)
              when tx.conc_cuenta is not null
              then format('En el banco el %s; su transferencia (%s) se fechó el %s para no tocar la conciliación confirmada de %s al '
                          '%s, pero este estado de cuenta corta antes y ya la trae: así no se confirma. Reabre aquella '
                          '(fn_conciliacion_reabrir, con su motivo), des-casa el movimiento %s (fn_banco_descasar: reversa el asiento) '
                          'y vuelve a casarla: irá el %s y en %s quedará como %s.', sb.fecha, tx.numero, tx.fecha_contable,
                          tx.conc_cuenta, tx.conc_corte, coalesce(tx.dueno, sb.id::text), sb.fecha, tx.conc_cuenta,
                          case when tx.monto_otra < 0 then 'cargo en circulación' else 'depósito en tránsito' end)
              else format('En el banco el %s, y casado con un asiento posterior al corte (%s del %s): el libro lo tiene después que el '
                          'banco y así no se confirma. Si su papel lleva mal la fecha, des-cásalo (fn_banco_descasar, con su motivo), '
                          'corrige la fecha y vuelve a casarlo.', sb.fecha, tx.numero, tx.fecha_contable) end
    from sb
    left join lateral (select a.numero, a.fecha_contable,
                              coalesce(a.procedencia->'fecha_por'->>'cuenta',
                                       substring(a.procedencia->>'fecha_nota' from 'confirmada de ([^ ]+) al ')) as conc_cuenta,
                              coalesce(a.procedencia->'fecha_por'->>'fecha_corte',
                                       substring(a.procedencia->>'fecha_nota' from 'confirmada de [^ ]+ al ([0-9-]{10})')) as conc_corte,
                              (select bc.movimiento_id::text from banco_casados bc
                                where bc.asiento_id = a.id and bc.posteado and bc.deshecho_el is null limit 1) as dueno,
                              (select sum(l.monto) from asiento_lineas l
                                where l.asiento_id = a.id
                                  and l.cuenta = coalesce(a.procedencia->'fecha_por'->>'cuenta',
                                                          substring(a.procedencia->>'fecha_nota' from 'confirmada de ([^ ]+) al '))) as monto_otra
                         from asientos a
                        where a.id = sb.asiento_id and sb.estado <> 'pendiente' and not sb.despues) tx on true;

  if not coalesce(p_pareja, true) or not exists (select 1 from pg_temp._mx_conc_items o where o.lado = 'banco' and o.clase = 'sin_casar') then
    return query select o.lado, o.clase, o.asiento_id, o.orden, o.movimiento_id, o.apertura_partida_id, o.fecha, o.monto, o.descripcion,
                        o.cheque, o.numero, o.explicacion, null::jsonb
                   from pg_temp._mx_conc_items o;
    return;
  end if;
  analyze pg_temp._mx_conc_items;
  return query
  with
  -- LA PAREJA de lo que el banco trae sin su línea:
  --   · una partida de la APERTURA que puede ser ella: por su número de
  --     cheque o por lo que falta, o dos movimientos del banco que la suman
  --     (el depósito del 30-sep que el banco trajo en dos): «cásalo con ella»;
  --   · de un DEPÓSITO, dos cobros (o lo que sea del libro que entra) que lo
  --     suman, de 7 días antes a 3 después: los cheques anotados uno por
  --     factura y depositados juntos;
  --   · si no, la línea del libro sin movimiento más parecida (mismo signo,
  --     otro monto, a 3 días o menos): «¿el recibo sin el tax?».
  lib as (select o.* from pg_temp._mx_conc_items o where o.lado = 'libro' and o.asiento_id is not null),
  -- (Cada línea del libro, una vez por cada día de la ventana, con la
  -- fecha del movimiento que le tocaría —fk—: así cada movimiento del
  -- banco encuentra las suyas por clave, con un hash, y no cruzándose con
  -- cada línea y cada día. Con un año sin casar, la pareja bajó de 3,7 s
  -- a 0,2 s.)
  libd as (select o.asiento_id, o.orden, o.numero, o.fecha, o.monto, d.d, o.fecha - d.d as fk
             from pg_temp._mx_conc_items o cross join generate_series(-7, 3) as d(d)
            where o.lado = 'libro' and o.asiento_id is not null),
  ban as (select o.* from pg_temp._mx_conc_items o where o.lado = 'banco' and o.clase = 'sin_casar'),
  apx as (select o.* from pg_temp._mx_conc_items o where o.lado = 'libro' and o.apertura_partida_id is not null and o.clase <> 'error'),
  pap1 as (
    select distinct on (i.movimiento_id) i.movimiento_id,
           jsonb_build_object('partida_apertura', a.apertura_partida_id, 'fecha', a.fecha, 'monto', a.monto,
                              'descripcion', a.descripcion) as x,
           format('%s del %s por %s', coalesce(a.descripcion, 'la partida'), a.fecha, a.monto) as txt
      from ban i
      join apx a on (a.monto = i.monto and (a.cheque is null or i.cheque is null or ltrim(a.cheque, '0') = i.cheque))
                 or (a.cheque is not null and i.cheque is not null and ltrim(a.cheque, '0') = i.cheque and sign(a.monto) = sign(i.monto))
     order by i.movimiento_id, (a.cheque is not null and ltrim(a.cheque, '0') = i.cheque) desc, a.fecha, a.apertura_partida_id),
  pap2 as (
    select distinct on (i.movimiento_id) i.movimiento_id,
           jsonb_build_object('partida_apertura', a.apertura_partida_id, 'fecha', a.fecha, 'monto', a.monto,
                              'descripcion', a.descripcion, 'movimientos', jsonb_build_array(i.movimiento_id, j.movimiento_id)) as x,
           format('%s del %s por %s, con el del %s por %s', coalesce(a.descripcion, 'la partida'), a.fecha, a.monto, j.fecha, j.monto) as txt
      from ban i
      join apx a on a.cheque is null and sign(a.monto) = sign(i.monto) and abs(i.monto) < abs(a.monto)
      join ban j on j.monto = a.monto - i.monto and j.movimiento_id <> i.movimiento_id
     order by i.movimiento_id, a.fecha, a.apertura_partida_id, j.fecha, j.movimiento_id),
  pjs as (
    select distinct on (i.movimiento_id) i.movimiento_id,
           jsonb_build_object('lineas', jsonb_build_array(jsonb_build_object('asiento_id', a.asiento_id, 'orden', a.orden),
                                                          jsonb_build_object('asiento_id', b.asiento_id, 'orden', b.orden)),
                              'numeros', jsonb_build_array(a.numero, b.numero), 'montos', jsonb_build_array(a.monto, b.monto),
                              'suma', a.monto + b.monto) as x,
           format('%s del %s por %s y %s del %s por %s', a.numero, a.fecha, a.monto, b.numero, b.fecha, b.monto) as txt
      from ban i
      join libd a on a.fk = i.fecha and a.monto > 0 and a.monto < i.monto
      join lib b on b.monto = i.monto - a.monto and b.fecha between i.fecha - 7 and i.fecha + 3
                and (b.fecha, b.numero, b.orden) > (a.fecha, a.numero, a.orden)
     where i.monto > 0
     order by i.movimiento_id, a.fecha, a.numero, a.orden, b.fecha, b.numero, b.orden),
  pj as (
    select distinct on (i.movimiento_id) i.movimiento_id,
           jsonb_build_object('asiento_id', o.asiento_id, 'orden', o.orden, 'numero', o.numero, 'fecha', o.fecha, 'monto', o.monto) as x
      from ban i
      join libd o on o.fk = i.fecha and o.d between -3 and 3 and sign(o.monto) = sign(i.monto) and o.monto <> i.monto
     order by i.movimiento_id, abs(o.monto - i.monto), abs(o.d), o.fecha, o.numero, o.orden)
  select i.lado, i.clase, i.asiento_id, i.orden, i.movimiento_id, i.apertura_partida_id, i.fecha, i.monto, i.descripcion, i.cheque,
         i.numero,
         coalesce(case when i.lado = 'banco' and a1.x is not null
                       then format('¿Es la partida en tránsito de la conciliación de apertura (%s)? QuickBooks ya la tenía: '
                                   'cásalo con ella (fn_banco_casar_con con {"partida_apertura": "%s"}), no lo clasifiques ni '
                                   'registres un cobro (entraría dos veces).', a1.txt, a1.x->>'partida_apertura')
                       when i.lado = 'banco' and a2.x is not null
                       then format('Con otro movimiento suma la partida en tránsito de la conciliación de apertura (%s): cásalos '
                                   'con ella (fn_banco_casar_con con {"partida_apertura": "%s", "movimientos": [el otro]}).',
                                   a2.txt, a2.x->>'partida_apertura')
                       when i.lado = 'banco' and s2.x is not null
                       then format('Suman el depósito: %s. Si son este depósito (varios cheques depositados juntos), cásalo con '
                                   'ellos (fn_banco_casar_con con sus líneas); no registres otro cobro ni un anticipo.', s2.txt)
                       when i.lado = 'banco' and i.clase = 'sin_casar' and p.x is not null
                       then format('Monto distinto: banco %s, libros %s (%s del %s): ¿el recibo sin el tax, o un pago parcial?',
                                   i.monto, p.x->>'monto', p.x->>'numero', p.x->>'fecha') end, i.explicacion),
         coalesce(a1.x, a2.x, s2.x, case when i.clase = 'sin_casar' then p.x end)
    from pg_temp._mx_conc_items i
    left join pap1 a1 on i.lado = 'banco' and a1.movimiento_id = i.movimiento_id
    left join pap2 a2 on i.lado = 'banco' and a2.movimiento_id = i.movimiento_id
    left join pj p on i.lado = 'banco' and p.movimiento_id = i.movimiento_id
    left join pjs s2 on i.lado = 'banco' and s2.movimiento_id = i.movimiento_id;
end $f$;
revoke execute on function public.fn_conciliacion_items(text, date, boolean) from public, anon, authenticated, service_role;

-- El saldo en libros de una cuenta a una fecha (todas sus líneas).
create or replace function public.fn_banco_saldo_libros(p_cuenta text, p_fecha date)
returns numeric
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce(sum(l.monto), 0)::numeric(14,2)
    from asiento_lineas l join asientos a on a.id = l.asiento_id
   where l.cuenta = p_cuenta and a.fecha_contable <= p_fecha
$$;
revoke execute on function public.fn_banco_saldo_libros(text, date) from public, anon, authenticated, service_role;

-- La huella de las partidas de una conciliación (lo que se confirma).
create or replace function public.fn_conciliacion_huella(p_conciliacion uuid)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  -- (Las fechas con to_char: el texto de una fecha depende del DateStyle
  -- de la sesión, y la huella no. fn_banco_control la recalcula igual.)
  select encode(sha256(convert_to(
           concat_ws('#', c.cuenta, to_char(c.fecha_corte, 'YYYY-MM-DD'), c.saldo_banco, c.saldo_libros,
                     (select string_agg(concat_ws('|', p.lado, p.clase, p.asiento_id, p.orden, p.movimiento_id, p.apertura_partida_id,
                                                  to_char(p.fecha, 'YYYY-MM-DD'), p.monto),
                                        E'\n' order by p.lado, p.fecha, p.monto, p.asiento_id, p.orden, p.movimiento_id,
                                                       p.apertura_partida_id)
                        from conciliacion_partidas p where p.conciliacion_id = c.id)), 'UTF8')), 'hex')
    from conciliaciones c where c.id = p_conciliacion
$$;
revoke execute on function public.fn_conciliacion_huella(uuid) from public, anon, authenticated, service_role;

-- (fn_banco_saldo_texto, el lector de un saldo escrito, está en 2: lo usa
-- también el importador de lotes.)

-- RECALCULA una conciliación abierta y guarda sus partidas (conservando la
-- clase y el motivo que Edgar les puso), sus cifras y su diferencia; y
-- apunta en las partidas de conciliaciones anteriores las que el banco por
-- fin trajo (en cuál y con qué movimiento). Interna: la llaman
-- fn_conciliar y fn_conciliacion_confirmar.
create or replace function public.fn_conciliacion_recalcular(p_conciliacion uuid)
returns jsonb
language plpgsql
set search_path = public, pg_temp
set jit = off
as $$
declare
  c        conciliaciones;
  v_tipo   text;
  v_libros numeric;
  v_banco  numeric;
  v_dep    numeric;
  v_car    numeric;
  v_sb     numeric;
  v_nsb    int;
  v_ntr    int;
  v_nal    int;
  v_ndu    int;
  v_nnom   int;
  v_npm    int;
  v_npa    int;
  v_npt    int;
  v_hereda jsonb;
  v_prev   text;
  v_sdif   boolean := false;
  v_dif    numeric;
  v_ign    numeric;
  v_nign   int;
  v_arch   archivos_banco;
  v_viejas jsonb;
  r        record;
  v_avisos jsonb := '[]'::jsonb;
  v_ncas   int;
  v_nblq   int;
  v_ndap   int := 0;
  v_aptxt  text;
  v_ctxt   text;
  v_sarch  numeric;
  v_falta  text;
begin
  select * into c from conciliaciones where id = p_conciliacion for update;
  v_tipo := fn_banco_tipo_cuenta(c.cuenta);
  v_libros := fn_banco_saldo_libros(c.cuenta, c.fecha_corte);
  -- El archivo con el saldo a esa misma fecha (el último que entró).
  select * into v_arch from archivos_banco a
   where a.cuenta = c.cuenta and a.saldo_al = c.fecha_corte and a.saldo is not null and a.retirado_el is null
   order by a.importado_el desc limit 1;
  -- El saldo del banco: el que escribió Edgar (como lo dice el statement;
  -- en una tarjeta, lo que se debe), o el del archivo.
  v_banco := case when c.saldo_statement is not null
                  then case when v_tipo = 'tarjeta' then -c.saldo_statement else c.saldo_statement end
                  else v_arch.saldo end;
  -- El saldo escrito que NO dice lo mismo que el archivo del banco al mismo
  -- día: vale solo con su motivo y su documento (el PDF del statement,
  -- fn_conciliacion_saldo); sin ellos no se confirma. Antes valía el
  -- escrito y quedaba un aviso: tecleando el saldo de libros se «cuadraba»
  -- un mes que el banco no cuadraba (un cargo ignorado, un error de tecleo)
  -- y los controles seguían en verde.
  if c.saldo_statement is not null and v_arch.id is not null
     and c.saldo_statement <> (case when v_tipo = 'tarjeta' then -v_arch.saldo else v_arch.saldo end) then
    v_sdif := nullif(btrim(coalesce(c.saldo_motivo, '')), '') is null or nullif(btrim(coalesce(c.saldo_documento, '')), '') is null;
    v_avisos := v_avisos || to_jsonb(format('El statement dice %s y el archivo (%s) dice %s al mismo día: no dicen lo mismo. %s',
                                            c.saldo_statement, coalesce(v_arch.nombre, 'sin nombre'),
                                            case when v_tipo = 'tarjeta' then -v_arch.saldo else v_arch.saldo end,
                                            case when v_sdif
                                                 then 'Si te equivocaste al escribirlo, escríbelo otra vez; si vale el del statement, '
                                                      'dile por qué y con qué documento (fn_conciliacion_saldo, desde el SQL Editor): '
                                                      'sin eso no se confirma.'
                                                 else format('Vale el que escribiste: %s (%s).', c.saldo_motivo, c.saldo_documento) end));
  end if;

  -- Lo que Edgar ya dijo de cada partida (clase y motivo), por su llave.
  select coalesce(jsonb_object_agg(coalesce(p.asiento_id::text || ':' || p.orden, p.movimiento_id::text, p.apertura_partida_id::text,
                                            p.id::text),
                                   jsonb_build_object('clase', p.clase, 'motivo', p.motivo)), '{}'::jsonb)
    into v_viejas
    from conciliacion_partidas p where p.conciliacion_id = c.id and p.motivo is not null;
  -- Y lo que Edgar ya dijo de una partida de la APERTURA que sigue en
  -- tránsito en la última conciliación CONFIRMADA de la cuenta (el cheque
  -- viejo que el proveedor no cobra): su clase y su motivo pasan a esta, con
  -- la fecha en que se dijo, mientras siga igual (lo mismo por llegar) y no
  -- pasen 90 días desde que se dijo por primera vez; después, o si cambió,
  -- se vuelve a pedir. Antes cada mes pedía otra vez lo mismo, sin enseñar
  -- lo que se había dicho.
  if c.tipo = 'normal' then
    select coalesce(jsonb_object_agg(x.ap, jsonb_build_object('clase', x.clase, 'motivo', x.motivo, 'monto', x.monto,
                                                              'en', x.fecha_corte, 'desde', x.desde)), '{}'::jsonb)
      into v_hereda
      from (select distinct on (p.apertura_partida_id) p.apertura_partida_id::text as ap, p.clase, p.motivo, p.monto, pc.fecha_corte,
                   (select min(c2.fecha_corte) from conciliaciones c2 join conciliacion_partidas p2 on p2.conciliacion_id = c2.id
                     where c2.cuenta = c.cuenta and c2.estado = 'confirmada' and c2.tipo = 'normal'
                       and p2.apertura_partida_id = p.apertura_partida_id and p2.motivo = p.motivo) as desde
              from conciliacion_partidas p
              join conciliaciones pc on pc.id = p.conciliacion_id
             where pc.cuenta = c.cuenta and pc.estado = 'confirmada' and pc.tipo = 'normal' and pc.fecha_corte < c.fecha_corte
               and p.lado = 'libro' and p.apertura_partida_id is not null and nullif(btrim(coalesce(p.motivo, '')), '') is not null
             order by p.apertura_partida_id, pc.fecha_corte desc) x
     where c.fecha_corte - x.desde <= 90;
  end if;

  if c.tipo = 'normal' then
    -- Las partidas nuevas contra las que ya estaban: solo se toca lo que
    -- cambió (lo igual se queda como está, sin rastro de más; lo que ya no
    -- está se borra y lo nuevo entra, cada uno con su fila en el
    -- historial). Se comparan por la huella de la fila entera.
    perform fn_banco_marca('conciliacion:' || c.id);
    with items as (
      select i.*,
             -- (lo heredado de la conciliación confirmada anterior: solo una
             -- partida de la apertura que falta por lo mismo)
             case when i.lado = 'libro' and i.apertura_partida_id is not null
                       and not (v_viejas ? i.apertura_partida_id::text)
                       and (v_hereda->i.apertura_partida_id::text->>'monto')::numeric = i.monto
                  then v_hereda->i.apertura_partida_id::text end as h
        from fn_conciliacion_items(c.cuenta, c.fecha_corte) i),
    nuevo as (
      select c.id as conciliacion_id, i.lado,
             case when i.lado = 'libro' and i.clase <> 'posible_duplicado'
                       and v_viejas ? coalesce(i.asiento_id::text || ':' || i.orden, i.apertura_partida_id::text)
                  then v_viejas->coalesce(i.asiento_id::text || ':' || i.orden, i.apertura_partida_id::text)->>'clase'
                  when i.h is not null and i.clase <> 'posible_duplicado' then i.h->>'clase'
                  else i.clase end as clase,
             i.asiento_id, i.orden, i.movimiento_id, i.apertura_partida_id, i.fecha, i.monto::numeric(14,2) as monto, i.descripcion,
             i.cheque,
             coalesce(v_viejas->coalesce(i.asiento_id::text || ':' || i.orden, i.movimiento_id::text, i.apertura_partida_id::text)->>'motivo',
                      i.h->>'motivo') as motivo,
             (c.fecha_corte - i.fecha)::int as dias, (i.lado = 'libro' and c.fecha_corte - i.fecha > 30) as alarma,
             i.explicacion
             || case when i.h is not null
                     then format(' Su motivo lo dijiste en la conciliación del %s (y vale hasta el %s, 90 días desde que lo dijiste '
                                 'por primera vez, el %s); si cambió algo, dilo otra vez (fn_conciliacion_partida).', i.h->>'en',
                                 (i.h->>'desde')::date + 90, i.h->>'desde')
                     else '' end as explicacion,
             i.pareja
        from items i),
    nk as (select n.*, md5(row(n.lado, n.clase, n.asiento_id, n.orden, n.movimiento_id, n.apertura_partida_id, n.fecha, n.monto,
                               n.descripcion, n.cheque, n.motivo, n.dias, n.alarma, n.explicacion, n.pareja)::text) as k
             from nuevo n),
    vk as (select p.id, md5(row(p.lado, p.clase, p.asiento_id, p.orden, p.movimiento_id, p.apertura_partida_id, p.fecha, p.monto,
                                p.descripcion, p.cheque, p.motivo, p.dias, p.alarma, p.explicacion, p.pareja)::text) as k
             from conciliacion_partidas p where p.conciliacion_id = c.id),
    borra as (delete from conciliacion_partidas p
               using vk
               where p.id = vk.id and not exists (select 1 from nk where nk.k = vk.k)
              returning p.id)
    insert into conciliacion_partidas (conciliacion_id, lado, clase, asiento_id, orden, movimiento_id, apertura_partida_id, fecha,
                                       monto, descripcion, cheque, motivo, dias, alarma, explicacion, pareja)
    select nk.conciliacion_id, nk.lado, nk.clase, nk.asiento_id, nk.orden, nk.movimiento_id, nk.apertura_partida_id, nk.fecha,
           nk.monto, nk.descripcion, nk.cheque, nk.motivo, nk.dias, nk.alarma, nk.explicacion, nk.pareja
      from nk
     where not exists (select 1 from vk where vk.k = nk.k);
    perform fn_banco_marca(null);
  end if;

  -- (Lo que bloquea: lo del banco sin su línea, y los posibles duplicados;
  -- lo que el libro tiene después por un mes cerrado cuenta en la
  -- identidad pero no bloquea.)
  select coalesce(sum(p.monto) filter (where p.lado = 'libro' and p.monto > 0), 0),
         coalesce(-sum(p.monto) filter (where p.lado = 'libro' and p.monto < 0), 0),
         coalesce(sum(p.monto) filter (where p.lado = 'banco'), 0),
         count(*) filter (where p.lado = 'banco' and p.clase = 'sin_casar'), count(*) filter (where p.lado = 'libro'),
         count(*) filter (where p.lado = 'libro' and c.fecha_corte - p.fecha > 30),
         count(*) filter (where p.clase = 'posible_duplicado'),
         count(*) filter (where p.lado = 'banco' and p.clase = 'sin_casar'
                            and exists (select 1 from movimientos_banco mm where mm.id = p.movimiento_id and mm.estado_motivo = 'nomina'))
    into v_dep, v_car, v_sb, v_nsb, v_ntr, v_nal, v_ndu, v_nnom
    from conciliacion_partidas p where p.conciliacion_id = c.id;
  -- (Ronda 4: las partidas de la apertura que el banco ya trajo y se
  -- casaron con otra cosa. En la de apertura, de sus propias partidas; en
  -- las de cada mes, las que fn_conciliacion_items marcó como posible
  -- duplicado. Frenan, como n_dudosas, y «falta» dice cuáles.)
  if c.tipo = 'apertura' then
    select count(*), string_agg(x.texto, '; ') into v_ndap, v_aptxt from fn_banco_apertura_casadas(c.cuenta, c.id) x;
    v_ndu := v_ndu + v_ndap;
  else
    select count(*), string_agg(x.texto, '; ' order by p.fecha)
      into v_ndap, v_aptxt
      from conciliacion_partidas p
      join fn_banco_apertura_casadas(c.cuenta, null) x on x.partida = p.apertura_partida_id
     where p.conciliacion_id = c.id and p.clase = 'posible_duplicado';
  end if;
  v_dif := case when v_banco is null then null else v_libros - (v_banco + v_dep - v_car - v_sb) end;
  -- Lo que pide su motivo escrito antes de confirmar: el saldo de arriba, y
  -- cada partida de la conciliación de APERTURA que lleva más de 30 días
  -- sin llegar (¿el depósito del 30-sep que nunca llegó? ¿el cheque que se
  -- clasificó otra vez?): fn_conciliacion_partida. Antes era solo una
  -- alarma y la conciliación se confirmaba con los libros por encima del
  -- banco.
  -- Y (esta versión) el ticket de una compra con tarjeta o débito, o una
  -- transferencia, que lleva más de 10 días en libros sin su movimiento del
  -- banco: la tarjeta postea en 1 a 3 días y el emisor acredita en 1 a 3.
  -- Así se confirmaba el gasto dos veces (el cargo con otro total que se
  -- clasificó, y su ticket «en circulación» para siempre) o el pago de la
  -- tarjeta puesto dos veces (uno desde cada estado de cuenta). Se dice qué
  -- pasó o por qué sigue (fn_conciliacion_partida), como las de la apertura.
  select count(*) filter (where p.apertura_partida_id is not null and p.alarma),
         count(*) filter (where p.asiento_id is not null and p.clase <> 'posible_duplicado' and c.fecha_corte - p.fecha > 10
                            and exists (select 1 from asientos a
                                         where a.id = p.asiento_id
                                           and (a.origen_tabla in ('recibos', 'cobros', 'prestamo_cuotas')
                                                or (a.origen_tabla = 'movimientos_banco' and a.procedencia->>'regla' like 'R3%')))
                            and not exists (select 1 from banco_casado_lineas cl
                                             where cl.asiento_id = p.asiento_id and cl.orden = p.orden and cl.vigente))
    into v_npa, v_npt
    from conciliacion_partidas p
   where p.conciliacion_id = c.id and p.lado = 'libro' and nullif(btrim(coalesce(p.motivo, '')), '') is null;
  v_npm := (case when v_sdif then 1 else 0 end) + v_npa + v_npt;
  -- (La partida de la apertura que sigue en tránsito y que el banco sí trajo
  -- ANTES del corte —el statement de la tarjeta cortó antes del 30-sep y lo
  -- de entre su corte y el 30 llega fechado en septiembre, ignorado—: se
  -- nombra con su movimiento y cómo casarla, en «falta».)
  select string_agg(format('la partida de la apertura «%s» del %s por %s la trajo el banco el %s, antes del corte (está ignorado): '
                           'cásala con él: select fn_banco_casar_con(%L, %L);', coalesce(p.descripcion, 'sin descripción'), p.fecha,
                           p.monto, mm.fecha, mm.id, jsonb_build_object('partida_apertura', p.apertura_partida_id)), '; '
                    order by p.fecha)
    into v_prev
    from conciliacion_partidas p
    join lateral (select x.* from movimientos_banco x
                   where x.cuenta = c.cuenta and x.estado = 'ignorado' and x.fecha < fn_puente_corte() and x.monto = p.monto
                     and x.duplicado is null
                     and not exists (select 1 from archivos_banco a where a.id = x.archivo_id and a.retirado_el is not null)
                     and coalesce(x.fecha_transaccion, x.fecha) >= p.fecha - 3
                     and (p.cheque is null or fn_banco_cheque_num(x.cheque, x.descripcion) is null
                          or fn_banco_cheque_num(x.cheque, x.descripcion) = nullif(ltrim(p.cheque, '0'), ''))
                   order by x.fecha, x.id limit 1) mm on true
   where p.conciliacion_id = c.id and p.lado = 'libro' and p.apertura_partida_id is not null;
  -- Lo ignorado que mueve dinero no está en ninguna partida: si hay, se
  -- dice (la diferencia puede ser eso).
  if c.tipo = 'normal' then
    select count(*), coalesce(sum(m.monto), 0) into v_nign, v_ign
      from movimientos_banco m
     where m.cuenta = c.cuenta and m.estado = 'ignorado' and m.monto <> 0 and m.fecha between fn_puente_corte() and c.fecha_corte
       and m.duplicado is distinct from 'es_el_mismo'
       -- (los de un archivo retirado no son de esta cuenta: ronda 4)
       and not exists (select 1 from archivos_banco a where a.id = m.archivo_id and a.retirado_el is not null);
    if v_nign > 0 and v_ign <> 0 then
      v_avisos := v_avisos || to_jsonb(format('%s movimiento(s) ignorado(s) mueven %s en esta cuenta: la diferencia puede ser eso '
                                              '(lo que es de la empresa no se ignora: se clasifica).', v_nign, v_ign));
    end if;
  end if;
  -- Lo del banco sin su línea que YA está casado (con un asiento posterior
  -- al corte): no se «casa o clasifica» otra vez; se dice qué hacer con
  -- cada uno (ronda 4: la transferencia fechada después del corte de la
  -- confirmada de la otra cuenta, ver fn_banco_tr_fecha; o un papel con la
  -- fecha posterior a la del banco).
  select count(*),
         string_agg(case when x.conc_cuenta is not null
                         then format('la transferencia %s se fechó el %s por la conciliación confirmada de %s al %s, pero este estado '
                                     'de cuenta ya la trae: reabre aquella (fn_conciliacion_reabrir, con su motivo), des-casa el '
                                     'movimiento %s (fn_banco_descasar) y vuelve a casarla', x.numero, x.fecha_contable, x.conc_cuenta,
                                     x.conc_corte, coalesce(x.dueno, x.mov))
                         else format('el del %s por %s está casado con %s del %s: si su papel lleva mal la fecha, des-cásalo, '
                                     'corrígela y vuelve a casarlo', x.fecha, x.monto, x.numero, x.fecha_contable) end,
                    '; ' order by x.fecha, x.mov)
    into v_ncas, v_ctxt
    from (select p.fecha, p.monto, mm.id::text as mov, a.numero, a.fecha_contable,
                 coalesce(a.procedencia->'fecha_por'->>'cuenta',
                          substring(a.procedencia->>'fecha_nota' from 'confirmada de ([^ ]+) al ')) as conc_cuenta,
                 coalesce(a.procedencia->'fecha_por'->>'fecha_corte',
                          substring(a.procedencia->>'fecha_nota' from 'confirmada de [^ ]+ al ([0-9-]{10})')) as conc_corte,
                 (select bc.movimiento_id::text from banco_casados bc
                   where bc.asiento_id = a.id and bc.posteado and bc.deshecho_el is null limit 1) as dueno
            from conciliacion_partidas p
            join movimientos_banco mm on mm.id = p.movimiento_id and mm.estado <> 'pendiente'
            left join asientos a on a.id = mm.asiento_id
           where p.conciliacion_id = c.id and p.lado = 'banco' and p.clase = 'sin_casar') x;
  -- (y lo pendiente cuya propuesta dice que no se casa hasta reabrir otra
  -- conciliación: fn_banco_tr_fecha)
  select count(*) into v_nblq
    from conciliacion_partidas p
    join movimientos_banco mm on mm.id = p.movimiento_id and mm.estado = 'pendiente' and mm.propuesta ? 'bloqueo'
   where p.conciliacion_id = c.id and p.lado = 'banco' and p.clase = 'sin_casar';
  v_sarch := case when v_arch.id is null then null when v_tipo = 'tarjeta' then -v_arch.saldo else v_arch.saldo end;
  -- LO QUE FALTA para confirmarla, en palabras (y guardado: v_conciliacion
  -- lo enseña, ronda 4).
  v_falta := case when v_banco is null then 'el saldo del statement (fn_conciliar con p_saldo_statement)'
                  when v_nsb > 0 and v_nnom = v_nsb
                  then format('%s débito(s) de nómina sin su journal: espera el journal de nómina (f11) o, si es del proveedor '
                              'anterior, regístralo desde el SQL Editor con fn_banco_nomina (no se clasifica a mano)', v_nsb)
                  when v_nsb > 0
                  then concat_ws('; ',
                         case when v_nsb - v_ncas > 0
                              then format('%s movimiento(s) del banco sin su línea en el libro: cásalos o clasifícalos%s%s',
                                          v_nsb - v_ncas,
                                          case when v_nnom > 0
                                               then format(' (%s de nómina: su journal, f11 o fn_banco_nomina)', v_nnom)
                                               else '' end,
                                          case when v_nblq > 0
                                               then format(' (%s espera que reabras otra conciliación antes: lo dice su propuesta)',
                                                           v_nblq)
                                               else '' end) end,
                         case when v_ncas > 0
                              then format('%s movimiento(s) del banco ya casados con un asiento posterior al corte (el libro los '
                                          'tiene después que el banco): %s', v_ncas, v_ctxt) end)
                  when coalesce(v_ndu, 0) > 0
                  then concat_ws('; ',
                         case when v_ndu - v_ndap > 0
                              then format('%s posible(s) duplicado(s): el ticket de un cargo que se clasificó antes de que llegara (el '
                                          'gasto estaría dos veces). Cámbialo por el ticket (fn_banco_casar_con) o di que es otra '
                                          'compra (fn_banco_duplicado)', v_ndu - v_ndap) end,
                         case when v_ndap > 0
                              then format('%s partida(s) de la apertura que el banco ya trajo y están casadas con otra cosa (el '
                                          'dinero estaría dos veces: en QuickBooks y otra vez ahora): %s', v_ndap, v_aptxt) end)
                  when v_dif <> 0 and v_prev is not null
                  then format('la diferencia es %s: %s', v_dif, v_prev)
                  when v_dif <> 0 then format('la diferencia es %s: algo del banco no está (un archivo que falta, un saldo '
                                              'mal escrito, un ignorado que mueve dinero)', v_dif)
                  when coalesce(v_npm, 0) > 0
                  then concat_ws('; ',
                         case when v_sdif then format('el saldo escrito (%s) no es el del archivo del banco a esa fecha (%s): '
                                                      'escríbelo otra vez, o di por qué vale y con qué documento '
                                                      '(fn_conciliacion_saldo, desde el SQL Editor)', c.saldo_statement,
                                                      v_sarch) end,
                         case when v_npa > 0
                              then format('%s partida(s) de la conciliación de apertura llevan más de 30 días sin llegar: ¿cuál '
                                          'es su movimiento? (cásalo con ella: fn_banco_casar_con) o di por qué sigue en tránsito '
                                          '(fn_conciliacion_partida, con su motivo)%s', v_npa,
                                          coalesce('. Y ' || v_prev, '')) end,
                         case when v_npt > 0
                              then format('%s ticket(s), cobro(s), cuota(s) o transferencia(s) llevan más de 10 días en libros '
                                          'sin su movimiento del banco (una tarjeta postea en 1 a 3 días, un pago se acredita en 1 '
                                          'a 3, un cheque se deposita en días, el prestamista cobra el día que toca): ¿un cargo con '
                                          'otro total que se clasificó (el gasto dos veces), un cobro o una cuota que llegó por otro '
                                          'monto, una transferencia puesta dos veces? '
                                          'Corrígelo, o di por qué sigue en tránsito (fn_conciliacion_partida, con su motivo)',
                                          v_npt) end) end;
  perform fn_banco_marca('conciliacion:' || c.id);
  update conciliaciones
     set saldo_libros = v_libros, saldo_banco = v_banco, archivo_id = v_arch.id,
         saldo_archivo = v_sarch,
         depositos_transito = v_dep, cargos_circulacion = v_car, sin_casar_banco = v_sb, n_sin_casar = v_nsb, n_transito = v_ntr,
         n_alarmas = v_nal, n_dudosas = v_ndu, n_pide_motivo = v_npm, diferencia = v_dif, calculada_el = clock_timestamp(),
         falta = v_falta
   where id = c.id;
  perform fn_banco_marca(null);

  -- Las partidas de conciliaciones anteriores de esta cuenta que el banco
  -- ya trajo: en cuál y con qué movimiento.
  if c.tipo = 'normal' then
    for r in select p.id, (select bc.movimiento_id from banco_casado_lineas bl
                             join banco_casados bc on bc.id = bl.casado_id and bc.deshecho_el is null
                            where bl.asiento_id = p.asiento_id and bl.orden = p.orden and bl.vigente limit 1) as mov
               from conciliacion_partidas p
               join conciliaciones pc on pc.id = p.conciliacion_id
              where pc.cuenta = c.cuenta and pc.fecha_corte < c.fecha_corte and pc.id <> c.id and p.lado = 'libro'
                and p.resuelta_en is null and p.asiento_id is not null
                and not exists (select 1 from conciliacion_partidas q
                                 where q.conciliacion_id = c.id and q.asiento_id = p.asiento_id and q.orden = p.orden)
    loop
      if r.mov is not null then
        perform fn_banco_marca('resolver:' || r.id);
        update conciliacion_partidas set resuelta_en = c.id, resuelta_por_movimiento = r.mov where id = r.id;
        perform fn_banco_marca(null);
      end if;
    end loop;
    for r in select p.id from conciliacion_partidas p
               join conciliaciones pc on pc.id = p.conciliacion_id
              where pc.cuenta = c.cuenta and pc.tipo = 'apertura' and p.lado = 'libro' and p.resuelta_en is null
                and p.resuelta_por_movimiento is not null
                and exists (select 1 from movimientos_banco mm where mm.id = p.resuelta_por_movimiento and mm.fecha <= c.fecha_corte)
    loop
      perform fn_banco_marca('resolver:' || r.id);
      update conciliacion_partidas set resuelta_en = c.id where id = r.id;
      perform fn_banco_marca(null);
    end loop;
  end if;

  select * into c from conciliaciones where id = p_conciliacion;
  return jsonb_strip_nulls(jsonb_build_object(
    'conciliacion', c.id, 'cuenta', c.cuenta, 'fecha_corte', c.fecha_corte, 'tipo', c.tipo, 'estado', c.estado,
    'saldo_libros', c.saldo_libros, 'saldo_statement', c.saldo_statement, 'saldo_archivo', c.saldo_archivo,
    'saldo_banco', c.saldo_banco, 'depositos_transito', c.depositos_transito, 'cargos_circulacion', c.cargos_circulacion,
    'sin_casar_banco', c.sin_casar_banco, 'n_sin_casar', c.n_sin_casar, 'n_transito', c.n_transito, 'n_alarmas', c.n_alarmas,
    'n_dudosas', c.n_dudosas, 'n_pide_motivo', c.n_pide_motivo, 'diferencia', c.diferencia,
    'lista_para_confirmar', c.saldo_banco is not null and c.diferencia = 0 and c.n_sin_casar = 0 and coalesce(c.n_dudosas, 0) = 0
                            and coalesce(c.n_pide_motivo, 0) = 0,
    'falta', v_falta,
    'avisos', case when jsonb_array_length(v_avisos) > 0 then v_avisos end));
end $$;
revoke execute on function public.fn_conciliacion_recalcular(uuid) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_conciliar(cuenta, fecha_corte, saldo_statement) — «Cuadrar el mes»:
-- crea (o recalcula, si está abierta) la conciliación de esa cuenta a esa
-- fecha, con sus partidas y su diferencia. p_saldo_statement: el saldo
-- final del statement COMO LO DICE (un banco: lo que hay; una tarjeta: lo
-- que se debe, en positivo); sin él, el que ya escribió antes, o el del
-- archivo que traiga el saldo a esa misma fecha. Una confirmada no se
-- recalcula (MX008): se reabre con su motivo. La de la apertura (30-sep)
-- es fn_conciliacion_apertura. Y no va DETRÁS de la última confirmada de
-- la cuenta (MX008, y dice cuál reabrir): cada conciliación empieza donde
-- termina la anterior confirmada. Antes una fecha mal escrita (el 15 por el
-- 31) creaba una abierta que no se podía quitar y se llevaba los casados
-- de la confirmada del mes; la que ya quedó así se anula con su motivo
-- (fn_conciliacion_anular, desde el SQL Editor).
--   _rpc('fn_conciliar', { p_cuenta: '1010', p_fecha_corte: '2026-10-31', p_saldo_statement: '25310.44' })
-- ---------------------------------------------------------------------
create or replace function public.fn_conciliar(p_cuenta text, p_fecha_corte date, p_saldo_statement text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c     conciliaciones;
  v_id  uuid;
  v_s   numeric;
  v_ult date;
begin
  perform fn_banco_exigir_dueno();
  p_cuenta := fn_banco_cuenta_resolver(p_cuenta);
  if fn_banco_tipo_cuenta(p_cuenta) is null then
    raise exception using errcode = 'MX004',
      message = format('%s no es un banco ni una tarjeta de la empresa: no tiene estado de cuenta que conciliar.', coalesce(p_cuenta, 'nula'));
  end if;
  if p_fecha_corte is null or p_fecha_corte < fn_puente_corte() then
    raise exception using errcode = 'MX002',
      message = format('La fecha de corte va desde el %s; la del 30-sep es la conciliación de apertura (fn_conciliacion_apertura).',
                       fn_puente_corte());
  end if;
  if p_saldo_statement is not null then
    v_s := fn_banco_saldo_texto(p_saldo_statement, 'El saldo del statement');
  end if;
  -- El candado del casado (lo que se mira no cambia mientras se concilia),
  -- y los casados cuyo papel se rehízo, al día.
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  perform fn_banco_sanar();
  select * into c from conciliaciones where cuenta = p_cuenta and fecha_corte = p_fecha_corte for update;
  if found and c.estado = 'confirmada' then
    raise exception using errcode = 'MX008',
      message = format('La conciliación de %s al %s ya está confirmada: no se recalcula. Si hay que rehacerla, se reabre con su '
                       'motivo (fn_conciliacion_reabrir).', p_cuenta, p_fecha_corte);
  end if;
  select cc.fecha_corte into v_ult from conciliaciones cc
   where cc.cuenta = p_cuenta and cc.estado = 'confirmada' and cc.tipo = 'normal' and cc.fecha_corte > p_fecha_corte
   order by cc.fecha_corte desc limit 1;
  if v_ult is not null then
    raise exception using errcode = 'MX008',
      message = format('La conciliación de %s al %s ya está confirmada, después del %s: una conciliación no va detrás de la última '
                       'confirmada (cada una empieza donde termina la anterior, y sus casados son de aquella). Si hay que rehacer '
                       'ese tramo, reabre la del %s (fn_conciliacion_reabrir, con su motivo) y concíliala otra vez%s.', p_cuenta,
                       v_ult, p_fecha_corte, v_ult,
                       case when c.id is not null
                            then format('; si esta fecha fue un error de dedo, anula la abierta del %s (fn_conciliacion_anular, '
                                        'desde el SQL Editor, con su motivo)', p_fecha_corte)
                            else ' (esta fecha, ¿un error de dedo? no se creó nada)' end);
  end if;
  -- (c.id, no «found»: la consulta de la última confirmada lo cambia)
  if c.id is not null and c.tipo = 'apertura' then
    raise exception using errcode = 'MX008', message = 'Esa es la conciliación de apertura: se rehace con fn_conciliacion_apertura.';
  end if;
  if c.id is null then
    v_id := gen_random_uuid();
    perform fn_banco_marca('conciliacion:' || v_id);
    insert into conciliaciones (id, cuenta, fecha_corte, tipo, saldo_statement) values (v_id, p_cuenta, p_fecha_corte, 'normal', v_s);
    perform fn_banco_marca(null);
  else
    v_id := c.id;
    if v_s is not null and v_s is distinct from c.saldo_statement then
      -- (otro saldo: el motivo y el documento del anterior ya no valen)
      perform fn_banco_marca('conciliacion:' || v_id);
      update conciliaciones set saldo_statement = v_s, saldo_motivo = null, saldo_documento = null where id = v_id;
      perform fn_banco_marca(null);
    end if;
  end if;
  return fn_conciliacion_recalcular(v_id);
end $$;
revoke execute on function public.fn_conciliar(text, date, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_conciliar(text, date, text) to authenticated;

-- ---------------------------------------------------------------------
-- fn_conciliacion_partida(partida, clase, motivo) — «dejar en tránsito con
-- motivo» (f05, aporte 15): la clase y el motivo de una partida del lado
-- del libro de una conciliación abierta (un cheque emitido y no cobrado,
-- el depósito del 31, o un error que se corrige con un asiento). Se
-- conservan al recalcular.
-- ---------------------------------------------------------------------
create or replace function public.fn_conciliacion_partida(p_partida uuid, p_clase text, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  p conciliacion_partidas;
  c conciliaciones;
begin
  perform fn_banco_exigir_dueno();
  if coalesce(length(fn_banco_limpio(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'Una partida en tránsito dice por qué (motivo).';
  end if;
  if p_clase is null or p_clase not in ('deposito_en_transito', 'cargo_en_circulacion', 'error') then
    raise exception using errcode = '22023', message = 'La clase es deposito_en_transito, cargo_en_circulacion o error.';
  end if;
  select * into p from conciliacion_partidas where id = p_partida;
  if not found or p.lado <> 'libro' then
    raise exception using errcode = 'MX008',
      message = 'Esa no es una partida del lado del libro (lo del banco sin su línea no se deja en tránsito: se casa o se clasifica).';
  end if;
  if p.clase = 'posible_duplicado' then
    raise exception using errcode = 'MX008',
      message = 'Esa partida es un posible duplicado (el ticket de un cargo ya clasificado): no se deja en tránsito. Cámbiala por la '
                'clasificación (fn_banco_casar_con) o di que es otra compra (fn_banco_duplicado, false, con su motivo).';
  end if;
  select * into c from conciliaciones where id = p.conciliacion_id;
  perform fn_banco_marca('conciliacion:' || c.id);
  update conciliacion_partidas set clase = p_clase, motivo = fn_banco_limpio(p_motivo) where id = p_partida;
  perform fn_banco_marca(null);
  return (select to_jsonb(x) from conciliacion_partidas x where x.id = p_partida);
end $$;
revoke execute on function public.fn_conciliacion_partida(uuid, text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_conciliacion_partida(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- fn_conciliacion_saldo(conciliacion, motivo, documento) — SQL Editor (sin
-- grant a la API). Cuando el saldo que Edgar escribió (el del statement)
-- NO es el del archivo del banco a esa misma fecha (su LEDGERBAL), vale el
-- escrito solo con su porqué y el documento que lo dice (la ruta del PDF
-- del statement en el almacén: docs/banco/…): quedan escritos en la
-- conciliación (con su rastro en banco_historial) y desde ahí se puede
-- confirmar. Un LEDGERBAL tomado a media jornada, o un archivo que no
-- llega al corte, son las razones de verdad; si fue un error de tecleo, se
-- escribe otra vez el saldo (fn_conciliar) y esto no hace falta. Escribir
-- otro saldo borra el motivo y el documento del anterior.
--   select fn_conciliacion_saldo('…', 'El QFX se bajó el 31 a las 10:00; el statement cierra con el cargo de la tarde',
--                                'docs/banco/chase-2026-10.pdf');
-- ---------------------------------------------------------------------
create or replace function public.fn_conciliacion_saldo(p_conciliacion uuid, p_motivo text, p_documento text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c conciliaciones;
begin
  perform fn_banco_exigir_dueno();
  if coalesce(length(fn_banco_limpio(p_motivo)), 0) < 10 then
    raise exception using errcode = '22023',
      message = 'Di por qué vale el saldo que escribiste y no el del archivo del banco (el motivo, en una frase).';
  end if;
  if fn_banco_limpio(p_documento) is null then
    raise exception using errcode = '22023',
      message = 'Di con qué documento: la ruta del statement (el PDF del banco) en el almacén, p. ej. docs/banco/chase-2026-10.pdf.';
  end if;
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  select * into c from conciliaciones where id = p_conciliacion for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa conciliación.';
  end if;
  if c.estado = 'confirmada' then
    raise exception using errcode = 'MX008',
      message = format('La conciliación de %s al %s ya está confirmada: se reabre con su motivo (fn_conciliacion_reabrir).', c.cuenta,
                       c.fecha_corte);
  end if;
  if c.saldo_statement is null then
    raise exception using errcode = 'MX008',
      message = 'Esa conciliación no tiene un saldo escrito: vale el del archivo del banco, y no hace falta motivo.';
  end if;
  perform fn_banco_marca('conciliacion:' || c.id);
  update conciliaciones set saldo_motivo = fn_banco_limpio(p_motivo), saldo_documento = fn_banco_limpio(p_documento) where id = c.id;
  perform fn_banco_marca(null);
  return fn_conciliacion_recalcular(c.id);
end $$;
revoke execute on function public.fn_conciliacion_saldo(uuid, text, text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_conciliacion_confirmar(conciliacion) — la recalcula y la confirma
-- SOLO con diferencia 0.00, con el saldo del banco dicho y sin nada del
-- banco sin su línea. Guarda quién, cuándo y la huella de sus partidas;
-- desde ahí no se toca (reabrir con su motivo deja rastro). Una partida en
-- tránsito de más de 30 días no frena: sale como alarma; salvo la de la
-- conciliación de APERTURA, que pide su motivo escrito (fn_conciliacion_partida),
-- y un saldo escrito que no es el del archivo del banco a esa fecha, que
-- pide su motivo y su documento (fn_conciliacion_saldo): n_pide_motivo.
-- ---------------------------------------------------------------------
create or replace function public.fn_conciliacion_confirmar(p_conciliacion uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c     conciliaciones;
  v_res jsonb;
begin
  perform fn_banco_exigir_dueno();
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  select * into c from conciliaciones where id = p_conciliacion for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa conciliación.';
  end if;
  if c.estado = 'confirmada' then
    raise exception using errcode = 'MX008', message = format('La conciliación de %s al %s ya está confirmada.', c.cuenta, c.fecha_corte);
  end if;
  -- (detrás de la última confirmada de la cuenta no se confirma: ver
  -- fn_conciliar)
  if c.tipo = 'normal' and exists (select 1 from conciliaciones cc
                                    where cc.cuenta = c.cuenta and cc.estado = 'confirmada' and cc.tipo = 'normal'
                                      and cc.fecha_corte > c.fecha_corte) then
    raise exception using errcode = 'MX008',
      message = format('La conciliación de %s al %s va detrás de la última confirmada (la del %s): no se confirma. Reabre aquella '
                       '(fn_conciliacion_reabrir) o, si esta fue un error de dedo, anúlala (fn_conciliacion_anular, desde el SQL '
                       'Editor, con su motivo).', c.cuenta, c.fecha_corte,
                       (select max(cc.fecha_corte) from conciliaciones cc
                         where cc.cuenta = c.cuenta and cc.estado = 'confirmada' and cc.tipo = 'normal'));
  end if;
  if c.tipo = 'normal' then
    perform fn_banco_sanar();
  end if;
  v_res := fn_conciliacion_recalcular(c.id);
  select * into c from conciliaciones where id = p_conciliacion;
  if c.saldo_banco is null or c.n_sin_casar > 0 or coalesce(c.n_dudosas, 0) > 0 or c.diferencia <> 0
     or coalesce(c.n_pide_motivo, 0) > 0 then
    raise exception using errcode = 'MX008',
      message = format('La conciliación de %s al %s no se confirma: falta %s.', c.cuenta, c.fecha_corte, v_res->>'falta');
  end if;
  perform fn_banco_marca('conciliacion:' || c.id);
  update conciliaciones set estado = 'confirmada', hash_partidas = fn_conciliacion_huella(c.id) where id = c.id;
  perform fn_banco_marca(null);
  return v_res || jsonb_build_object('estado', 'confirmada',
                                     'alarmas', (select coalesce(jsonb_agg(jsonb_build_object('fecha', p.fecha, 'monto', p.monto,
                                                                                             'descripcion', p.descripcion,
                                                                                             'dias', p.dias, 'motivo', p.motivo)
                                                                           order by p.fecha), '[]'::jsonb)
                                                   from conciliacion_partidas p where p.conciliacion_id = c.id and p.alarma));
end $$;
revoke execute on function public.fn_conciliacion_confirmar(uuid) from public, anon, authenticated, service_role;
grant  execute on function public.fn_conciliacion_confirmar(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- fn_conciliacion_reabrir(conciliacion, motivo) — la única forma de tocar
-- una confirmada: vuelve a abierta, con su motivo, quién y cuándo (y el
-- rastro entero en banco_historial). Después se recalcula y se confirma
-- otra vez.
-- ---------------------------------------------------------------------
create or replace function public.fn_conciliacion_reabrir(p_conciliacion uuid, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c conciliaciones;
begin
  perform fn_banco_exigir_dueno();
  if coalesce(length(fn_banco_limpio(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'Reabrir una conciliación confirmada dice por qué (motivo): queda escrito.';
  end if;
  select * into c from conciliaciones where id = p_conciliacion for update;
  if not found or c.estado <> 'confirmada' then
    raise exception using errcode = 'MX008',
      message = 'Solo se reabre una conciliación confirmada (una abierta hecha por error se anula con su motivo: '
                'fn_conciliacion_anular, desde el SQL Editor).';
  end if;
  -- De la última hacia atrás: cada conciliación empieza donde termina la
  -- anterior confirmada (sus casados, su tramo); reabrir una de en medio
  -- cambiaría el tramo de la siguiente sin reabrirla.
  if exists (select 1 from conciliaciones cc
              where cc.cuenta = c.cuenta and cc.estado = 'confirmada' and cc.fecha_corte > c.fecha_corte) then
    raise exception using errcode = 'MX008',
      message = format('Reabre antes la del %s (la última confirmada de %s): se reabren de la última hacia atrás.',
                       (select max(cc.fecha_corte) from conciliaciones cc where cc.cuenta = c.cuenta and cc.estado = 'confirmada'),
                       c.cuenta);
  end if;
  perform fn_banco_marca('reabrir:' || c.id);
  update conciliaciones set estado = 'abierta', reabierta_motivo = fn_banco_limpio(p_motivo) where id = c.id;
  perform fn_banco_marca(null);
  return (select jsonb_build_object('conciliacion', x.id, 'cuenta', x.cuenta, 'fecha_corte', x.fecha_corte, 'estado', x.estado,
                                    'reabierta_el', x.reabierta_el, 'motivo', x.reabierta_motivo)
            from conciliaciones x where x.id = c.id);
end $$;
revoke execute on function public.fn_conciliacion_reabrir(uuid, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_conciliacion_reabrir(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- fn_conciliacion_anular(conciliacion, motivo) — SQL Editor (sin grant a
-- la API). Una conciliación ABIERTA hecha por error (la fecha mal escrita:
-- el 15 por el 31) se quita con su motivo: sus partidas (lo que
-- fn_conciliar recalcula siempre entero) y ella salen de las tablas y
-- quedan ENTERAS en banco_historial, con quién, cuándo y por qué (el
-- motivo se escribe en la fila antes de quitarla). Lo que otras
-- conciliaciones decían que se resolvió en ella se suelta (la siguiente lo
-- vuelve a apuntar). Una confirmada no: se reabre (fn_conciliacion_reabrir).
-- Antes no había cómo: ni reabrirla (no está confirmada) ni borrarla (la
-- guarda), y se quedaba para siempre enseñando «banco ¿?».
--   select fn_conciliacion_anular('…', 'La hice con la fecha equivocada (el 15 por el 31)');
-- ---------------------------------------------------------------------
create or replace function public.fn_conciliacion_anular(p_conciliacion uuid, p_motivo text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c       conciliaciones;
  v_motivo text := fn_banco_limpio(p_motivo);
  v_np    int;
  r       record;
begin
  perform fn_banco_exigir_dueno();
  if coalesce(length(v_motivo), 0) < 3 then
    raise exception using errcode = '22023', message = 'Anular una conciliación dice por qué (motivo): queda escrito.';
  end if;
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  select * into c from conciliaciones where id = p_conciliacion for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa conciliación.';
  end if;
  if c.estado <> 'abierta' or c.tipo <> 'normal' then
    raise exception using errcode = 'MX008',
      message = case when c.tipo <> 'normal'
                     then 'La conciliación de apertura no se anula: se rehace (fn_conciliacion_apertura).'
                     else format('La conciliación de %s al %s está confirmada: no se anula (se reabre con su motivo, '
                                 'fn_conciliacion_reabrir).', c.cuenta, c.fecha_corte) end;
  end if;
  -- Lo que otras decían que se resolvió en ella, suelto (la siguiente
  -- conciliación que se recalcule lo vuelve a apuntar).
  for r in select p.id from conciliacion_partidas p where p.resuelta_en = c.id loop
    perform fn_banco_marca('resolver:' || r.id);
    update conciliacion_partidas set resuelta_en = null where id = r.id;
  end loop;
  -- Sus partidas (con su rastro, cada una) y el motivo en la fila.
  perform fn_banco_marca('conciliacion:' || c.id);
  delete from conciliacion_partidas where conciliacion_id = c.id;
  get diagnostics v_np = row_count;
  update conciliaciones set motivo = format('Anulada: %s', v_motivo) where id = c.id;
  perform fn_banco_marca('anular:' || c.id);
  delete from conciliaciones where id = c.id;
  perform fn_banco_marca(null);
  return jsonb_build_object('anulada', c.id, 'cuenta', c.cuenta, 'fecha_corte', c.fecha_corte, 'partidas', v_np, 'motivo', v_motivo,
                            'rastro', 'banco_historial (tabla conciliaciones, clave ' || c.id || ')');
end $$;
revoke execute on function public.fn_conciliacion_anular(uuid, text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_conciliacion_apertura(cuenta, saldo_statement, partidas, motivo) — la
-- conciliación al 30-sep, la de la era QuickBooks: el saldo en libros es
-- el de la apertura (el asiento de fn_apertura, c4) y lo que no casa son
-- las partidas en tránsito que Edgar escribe de la conciliación de
-- QuickBooks (o del statement de septiembre), con su signo del libro:
--   [{"fecha": "2026-09-28", "monto": "-1200.00", "descripcion": "Cheque 1043 a …", "cheque": "1043"},
--    {"fecha": "2026-09-30", "monto": "3200.00", "descripcion": "Depósito del 30"},
--    {"fecha": "2026-09-30", "monto": "100.00", "clase": "error", "descripcion": "QuickBooks tenía 100 de más"}]
-- (positivo: un depósito en tránsito; negativo: un cheque o cargo en
-- circulación; «error»: lo que QuickBooks tenía mal, que corrige un ajuste
-- a la apertura). Se confirma con fn_conciliacion_confirmar (diferencia
-- 0.00). Cuando el banco de octubre trae una, casa sola con ella (el
-- cheque por su número y su monto) y queda dicho. Se rehace mientras esté
-- abierta; no si alguna partida ya la trajo el banco (se des-casa antes).
-- UNA TARJETA no corta el 30-sep (la Gold, el 22): el saldo es el de su
-- último statement al 30-sep o antes (lo que se debía a ese corte), y las
-- partidas, lo que QuickBooks dejó sin conciliar después de él (las
-- compras del 23 al 30). El banco las trae en el statement siguiente con
-- su fecha de septiembre (entran ignoradas: antes del corte) y casan
-- solas con su partida al casar (fn_banco_apertura_previas); si no, la
-- conciliación de octubre dice cuál y con qué llamada casarla.
-- ---------------------------------------------------------------------
create or replace function public.fn_conciliacion_apertura(p_cuenta text, p_saldo_statement text, p_partidas jsonb default '[]'::jsonb,
                                                           p_motivo text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c       conciliaciones;
  v_id    uuid;
  v_fecha date;
  v_s     numeric;
  v_p     jsonb;
  v_i     int := 0;
  v_sobra text;
  v_m     numeric;
  v_clase text;
begin
  perform fn_banco_exigir_dueno();
  p_cuenta := fn_banco_cuenta_resolver(p_cuenta);
  if fn_banco_tipo_cuenta(p_cuenta) is null then
    raise exception using errcode = 'MX004', message = format('%s no es un banco ni una tarjeta de la empresa.', coalesce(p_cuenta, 'nula'));
  end if;
  select p.hasta into v_fecha from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  if v_fecha is null then
    raise exception using errcode = 'MX002', message = 'No hay período de apertura.';
  end if;
  if not exists (select 1 from asientos a where a.tipo = 'apertura' and a.fecha_contable = v_fecha
                   and a.camino not in ('reverso', 'reverso_automatico')
                   and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    raise exception using errcode = 'MX008',
      message = 'Todavía no hay asiento de apertura (fn_apertura, c4): la conciliación de apertura concilia su saldo.';
  end if;
  v_s := fn_banco_saldo_texto(p_saldo_statement, 'El saldo del statement al 30-sep');
  if v_s is null then
    raise exception using errcode = '22023',
      message = 'Falta el saldo del último statement al 30-sep o antes (como lo dice el banco; en una tarjeta, lo que se debía a su '
                'corte: la Gold corta el 22, y lo de después de ese corte hasta el 30-sep va en las partidas).';
  end if;
  if jsonb_typeof(coalesce(p_partidas, '[]'::jsonb)) <> 'array' then
    raise exception using errcode = '22023', message = 'Las partidas en tránsito van como una lista.';
  end if;
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  select * into c from conciliaciones where cuenta = p_cuenta and fecha_corte = v_fecha for update;
  if found and c.estado = 'confirmada' then
    raise exception using errcode = 'MX008',
      message = 'La conciliación de apertura de esa cuenta ya está confirmada: se reabre con su motivo (fn_conciliacion_reabrir).';
  end if;
  if found and exists (select 1 from conciliacion_partidas p where p.conciliacion_id = c.id and p.resuelta_por_movimiento is not null) then
    raise exception using errcode = 'MX008',
      message = 'Alguna partida de esta conciliación de apertura ya la trajo el banco (está casada con su movimiento): des-casa ese '
                'movimiento antes de rehacerla (fn_banco_descasar).';
  end if;
  if found and exists (select 1 from conciliacion_partidas q
                        join conciliacion_partidas p on p.id = q.apertura_partida_id
                       where p.conciliacion_id = c.id) then
    raise exception using errcode = 'MX008',
      message = 'Conciliaciones posteriores de esta cuenta ya usan estas partidas de la apertura: reábrelas y recalcúlalas antes '
                '(con la apertura abierta, sus partidas no cuentan), y luego rehaz la apertura.';
  end if;
  if not found then
    v_id := gen_random_uuid();
    perform fn_banco_marca('conciliacion:' || v_id);
    insert into conciliaciones (id, cuenta, fecha_corte, tipo, saldo_statement, motivo)
    values (v_id, p_cuenta, v_fecha, 'apertura', v_s, fn_banco_limpio(p_motivo));
  else
    v_id := c.id;
    perform fn_banco_marca('conciliacion:' || v_id);
    update conciliaciones set saldo_statement = v_s, motivo = coalesce(fn_banco_limpio(p_motivo), motivo) where id = v_id;
  end if;
  delete from conciliacion_partidas where conciliacion_id = v_id;
  for v_p in select value from jsonb_array_elements(coalesce(p_partidas, '[]'::jsonb)) loop
    v_i := v_i + 1;
    select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(v_p) k
     where k not in ('fecha', 'monto', 'descripcion', 'cheque', 'clase', 'motivo');
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Partida %s: clave desconocida: %s.', v_i, v_sobra);
    end if;
    v_m := fn_banco_saldo_texto(v_p->>'monto', format('Partida %s: el monto', v_i));
    if v_m is null then
      raise exception using errcode = '22023', message = format('Partida %s: falta el monto (con su signo del libro).', v_i);
    end if;
    if v_m = 0 then
      raise exception using errcode = 'MX005', message = format('Partida %s: una partida en 0 no dice nada.', v_i);
    end if;
    v_clase := coalesce(fn_banco_limpio(v_p->>'clase'),
                        case when v_m > 0 then 'deposito_en_transito' else 'cargo_en_circulacion' end);
    if v_clase not in ('deposito_en_transito', 'cargo_en_circulacion', 'error') then
      raise exception using errcode = '22023', message = format('Partida %s: la clase es deposito_en_transito, cargo_en_circulacion o error.', v_i);
    end if;
    insert into conciliacion_partidas (conciliacion_id, lado, clase, fecha, monto, descripcion, cheque, motivo, dias, alarma, explicacion)
    values (v_id, 'libro', v_clase,
            coalesce(case when fn_banco_limpio(v_p->>'fecha') is not null
                          then fn_puente_fecha_texto(v_p->>'fecha', format('Partida %s: la fecha', v_i)) end, v_fecha),
            v_m, fn_banco_limpio(v_p->>'descripcion'), fn_banco_limpio(v_p->>'cheque'),
            coalesce(fn_banco_limpio(v_p->>'motivo'), 'De la conciliación de QuickBooks al 30-sep'),
            0, false, 'De la era QuickBooks: en tránsito al 30-sep.');
  end loop;
  perform fn_banco_marca(null);
  return fn_conciliacion_recalcular(v_id)
         || jsonb_build_object('partidas', v_i)
         || case when fn_banco_tipo_cuenta(p_cuenta) = 'tarjeta' and v_i > 0
                 then jsonb_build_object('aviso',
                        'Una tarjeta corta su statement a mitad de mes: las partidas de antes del 30-sep (lo de después de su corte) '
                        'el banco las trae en el statement siguiente con su fecha de septiembre (entran ignoradas, antes del corte) y '
                        'casan solas con su partida al casar (fn_banco_casar_todo); si alguna no casa, la conciliación de octubre '
                        'dice cuál y con qué llamada.')
                 else '{}'::jsonb end;
end $$;
revoke execute on function public.fn_conciliacion_apertura(text, text, jsonb, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_conciliacion_apertura(text, text, jsonb, text) to authenticated;
-- =====================================================================
-- 7 · LOS PRÉSTAMOS (f06): cada cuota se parte en capital e interés.
-- =====================================================================
-- La cuota del banco (un solo cargo) paga dos cosas: capital, que baja lo
-- que se debe (Dr 2520), e interés, que es gasto (Dr 7100). La partición
-- sale de la FÓRMULA —interés = round(saldo × tasa anual / 12, 2), capital
-- = el resto— o del STATEMENT del prestamista, que manda cuando Edgar lo
-- tiene (el banco calcula por días, y cobra cargos). Cada cuota es un
-- papel (prestamo_cuotas) con su asiento (Dr 25xx capital / Dr 7100
-- interés / Cr el banco), casado con su movimiento. El saldo de cada
-- préstamo es su saldo inicial menos el capital de sus cuotas vivas; la
-- suma de los saldos es lo que dice el libro en sus cuentas (el control
-- «préstamos»). El reparto entre corriente (2520) y largo plazo (2530) lo
-- enseña v_prestamos y lo postea el cierre (f08).
-- ---------------------------------------------------------------------

-- Lo que se debe de un préstamo después de sus cuotas vivas hasta esa
-- fecha (incluida); sin fecha, hoy.
create or replace function public.fn_prestamo_saldo(p_prestamo uuid, p_fecha date default null)
returns numeric
language sql
stable
set search_path = public, pg_temp
as $$
  select (p.saldo_inicial - coalesce((select sum(q.capital) from prestamo_cuotas q
                                       where q.prestamo_id = p.id and q.anulada_el is null
                                         and (p_fecha is null or q.fecha <= p_fecha)), 0))::numeric(14,2)
    from prestamos p where p.id = p_prestamo
$$;
revoke execute on function public.fn_prestamo_saldo(uuid, date) from public, anon, authenticated, service_role;

-- La partición que da la FÓRMULA para un pago de p_monto en p_fecha: el
-- interés del mes sobre lo que se debe (round(saldo × tasa / 100 / 12, 2))
-- y el resto a capital. Si el pago no alcanza el interés, todo es interés
-- (y se dice); si el capital pasa de lo que se debe, no cuadra: manda el
-- statement. La fórmula es la de la CUOTA DEL MES: un pago que no es la
-- cuota (otro monto, o a menos de 25 días de la cuota anterior: un abono
-- extra a capital, dos cuotas juntas) no se parte por ella, que le cobraría
-- otro mes entero de interés (154.51 sobre un abono de 5,000 cinco días
-- después de la cuota): pide_statement, y manda el statement del
-- prestamista (p_capital y p_interes; un abono solo a capital, todo a
-- capital).
create or replace function public.fn_prestamo_particion(p_prestamo uuid, p_fecha date, p_monto numeric)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  p       prestamos;
  v_saldo numeric;
  v_int   numeric;
  v_cap   numeric;
  v_ult   date;
  v_otro  text;
begin
  select * into p from prestamos where id = p_prestamo;
  if not found then
    return null;
  end if;
  v_saldo := fn_prestamo_saldo(p.id, p_fecha);
  v_int := round(v_saldo * p.tasa_anual / 100 / 12, 2);
  v_cap := p_monto - v_int;
  select max(q.fecha) into v_ult from prestamo_cuotas q where q.prestamo_id = p.id and q.anulada_el is null and q.fecha <= p_fecha;
  -- (Ronda 4) Lo que la fórmula no sabe repartir: un pago a menos de 25
  -- días de la cuota anterior (un abono aparte: la fórmula le cobraría
  -- otro mes de interés), o MENOR que la cuota (cómo lo repartió el
  -- prestamista lo dice su statement). La cuota del mes con un EXTRA en el
  -- mismo cargo (1,529.33 = 1,029.33 + 500.00), a 25 días o más de la
  -- anterior, sí va por la fórmula: el interés del mes y el resto a
  -- capital, que es lo que hace el prestamista. Antes todo pago distinto
  -- de la cuota pedía el statement «porque le cobraría otro mes de
  -- interés», y la primera opción lo mandaba todo a capital, sin el
  -- interés del mes.
  v_otro := case when v_ult is not null and p_fecha - v_ult < 25
                 then format('a %s días de la cuota del %s: la fórmula le cobraría otro mes de interés', p_fecha - v_ult, v_ult)
                 when p_monto < p.cuota
                 then format('%s, menos que la cuota (%s): cómo lo repartió el prestamista lo dice su statement', p_monto, p.cuota) end;
  return jsonb_strip_nulls(jsonb_build_object(
    'saldo_antes', v_saldo, 'tasa_anual', p.tasa_anual,
    'interes', least(v_int, p_monto), 'capital', greatest(v_cap, 0),
    'saldo_despues', v_saldo - greatest(v_cap, 0),
    'formula', format('interés = round(%s × %s %% / 12, 2) = %s; capital = %s − %s = %s', v_saldo, p.tasa_anual, v_int, p_monto,
                      least(v_int, p_monto), greatest(v_cap, 0)),
    'extra', case when v_otro is null and p_monto > p.cuota then p_monto - p.cuota end,
    'aviso', case when v_otro is not null then v_otro
                  when v_cap < 0 then 'El pago no alcanza el interés del mes: todo va a interés. Mira el statement.'
                  when v_cap > v_saldo then format('El capital (%s) pasa de lo que se debe (%s): no cuadra; usa el statement.',
                                                   v_cap, v_saldo)
                  when p_monto > p.cuota
                  then format('la cuota del mes (%s) más %s a capital', p.cuota, p_monto - p.cuota) end,
    'pide_statement', case when v_otro is not null then true end,
    'no_cuadra', case when v_cap > v_saldo then true end));
end $$;
revoke execute on function public.fn_prestamo_particion(uuid, date, numeric) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_prestamo_guardar(prestamo jsonb) — da de alta (o cambia) un préstamo
-- desde el SQL Editor, con rastro. No es de la API.
--   select fn_prestamo_guardar('{"prestamista": "Ford Credit", "descripcion": "F-150 2024",
--     "principal": "52000.00", "tasa_anual": "6.99", "cuota": "1029.33", "primer_pago": "2024-03-15",
--     "dia_pago": 15, "plazo_meses": 60, "saldo_inicial": "31415.26", "saldo_inicial_al": "2026-09-30",
--     "descriptor": "FORD CREDIT|FORD MOTOR CR"}');
-- cuenta (2520), cuenta_largo (2530), cuenta_interes (7100) y cuenta_banco
-- (1010) tienen esos valores si no se dicen. saldo_inicial: lo que se
-- debía al empezar el libro (el statement al 30-sep, que la apertura ya
-- trae en 2520/2530); en un préstamo nuevo, el principal (y el depósito
-- del préstamo se clasifica a 2520/2530). Con cuotas ya registradas, lo
-- que mueve el saldo (saldo inicial, su fecha, las cuentas) ya no cambia:
-- se anulan antes; la tasa sí (un préstamo de tasa variable).
-- ---------------------------------------------------------------------
create or replace function public.fn_prestamo_guardar(p_prestamo jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_sobra text;
  v_old   prestamos;
  v_new   prestamos;
  v_id    uuid;
  v_hay   boolean;
  v_x     text;
  v_t     text;
begin
  perform fn_banco_exigir_dueno();
  if p_prestamo is null or jsonb_typeof(p_prestamo) <> 'object' then
    raise exception using errcode = '22023', message = 'El préstamo va como objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(p_prestamo) k
   where k not in ('id', 'prestamista', 'descripcion', 'principal', 'tasa_anual', 'cuota', 'primer_pago', 'dia_pago',
                   'plazo_meses', 'cuenta', 'cuenta_largo', 'cuenta_interes', 'cuenta_banco', 'saldo_inicial',
                   'saldo_inicial_al', 'descriptor', 'estado', 'notas');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en el préstamo: %s.', v_sobra);
  end if;
  if p_prestamo ? 'id' then
    select * into v_old from prestamos where id = (p_prestamo->>'id')::uuid for update;
    if not found then
      raise exception using errcode = '22023', message = 'No existe ese préstamo.';
    end if;
    v_new := v_old;
  else
    v_new.id := gen_random_uuid();
    v_new.cuenta := '2520'; v_new.cuenta_largo := '2530'; v_new.cuenta_interes := '7100';
    v_new.cuenta_banco := coalesce(fn_puente_cuenta_de('banco'), '1010');
    v_new.estado := 'vigente';
  end if;
  v_new.prestamista    := coalesce(fn_banco_limpio(p_prestamo->>'prestamista'), v_new.prestamista);
  v_new.descripcion    := case when p_prestamo ? 'descripcion' then fn_banco_limpio(p_prestamo->>'descripcion') else v_new.descripcion end;
  v_new.principal      := coalesce(fn_banco_saldo_texto(p_prestamo->>'principal', 'El principal'), v_new.principal);
  -- (Lo que Edgar copia del statement, leído como lo escribe: la tasa con
  -- su «%» o con coma decimal, «6.99%», «6,99». Lo que no se entiende se
  -- dice en español, con lo que se espera; antes salía el error de Postgres
  -- en inglés, o el check de la tabla con la fila entera.)
  v_t := replace(replace(coalesce(fn_banco_limpio(p_prestamo->>'tasa_anual'), ''), '%', ''), ' ', '');
  if v_t ~ '^[0-9]+,[0-9]+$' then
    v_t := replace(v_t, ',', '.');
  end if;
  if v_t <> '' and v_t !~ '^[0-9]{1,2}([.][0-9]{1,4})?$' then
    raise exception using errcode = '22023',
      message = format('tasa_anual es el por ciento al año, un número de 0 a 99 con 4 decimales como mucho (6.99, «6.99%%» o «6,99»): '
                       'llegó «%s».', p_prestamo->>'tasa_anual');
  end if;
  v_new.tasa_anual     := coalesce(nullif(v_t, '')::numeric(8,4), v_new.tasa_anual);
  v_new.cuota          := coalesce(fn_banco_saldo_texto(p_prestamo->>'cuota', 'La cuota'), v_new.cuota);
  v_new.primer_pago    := coalesce(case when fn_banco_limpio(p_prestamo->>'primer_pago') is not null then fn_puente_fecha_texto(p_prestamo->>'primer_pago', 'El primer pago') end, v_new.primer_pago);
  v_t := fn_banco_limpio(p_prestamo->>'dia_pago');
  if v_t is not null and (case when v_t !~ '^[0-9]{1,2}$' then true else v_t::int not between 1 and 31 end) then
    raise exception using errcode = '22023',
      message = format('dia_pago es el día del mes en que se paga la cuota, un número de 1 a 31: llegó «%s».', v_t);
  end if;
  v_new.dia_pago       := coalesce(v_t::int, v_new.dia_pago, extract(day from v_new.primer_pago)::int);
  v_t := fn_banco_limpio(p_prestamo->>'plazo_meses');
  if v_t is not null and (case when v_t !~ '^[0-9]{1,3}$' then true else v_t::int = 0 end) then
    raise exception using errcode = '22023',
      message = format('plazo_meses es el número de cuotas del préstamo (60 para cinco años), un número entero: llegó «%s».', v_t);
  end if;
  v_new.plazo_meses    := case when p_prestamo ? 'plazo_meses' then v_t::int else v_new.plazo_meses end;
  v_new.cuenta         := coalesce(fn_banco_limpio(p_prestamo->>'cuenta'), v_new.cuenta);
  v_new.cuenta_largo   := case when p_prestamo ? 'cuenta_largo' then fn_banco_limpio(p_prestamo->>'cuenta_largo') else v_new.cuenta_largo end;
  v_new.cuenta_interes := coalesce(fn_banco_limpio(p_prestamo->>'cuenta_interes'), v_new.cuenta_interes);
  v_new.cuenta_banco   := coalesce(fn_banco_limpio(p_prestamo->>'cuenta_banco'), v_new.cuenta_banco);
  v_new.saldo_inicial  := coalesce(fn_banco_saldo_texto(p_prestamo->>'saldo_inicial', 'El saldo inicial'), v_new.saldo_inicial,
                                   v_new.principal);
  v_new.saldo_inicial_al := coalesce(case when fn_banco_limpio(p_prestamo->>'saldo_inicial_al') is not null
                                          then fn_puente_fecha_texto(p_prestamo->>'saldo_inicial_al', 'La fecha del saldo inicial') end,
                                     v_new.saldo_inicial_al);
  v_new.descriptor     := case when p_prestamo ? 'descriptor' then fn_banco_limpio(p_prestamo->>'descriptor') else v_new.descriptor end;
  v_new.estado         := coalesce(fn_banco_limpio(p_prestamo->>'estado'), v_new.estado);
  v_new.notas          := case when p_prestamo ? 'notas' then fn_banco_limpio(p_prestamo->>'notas') else v_new.notas end;
  if v_new.prestamista is null or v_new.principal is null or v_new.tasa_anual is null or v_new.cuota is null
     or v_new.primer_pago is null or v_new.saldo_inicial_al is null then
    raise exception using errcode = '22023',
      message = 'Un préstamo dice prestamista, principal, tasa_anual (en %), cuota, primer_pago y saldo_inicial_al (y saldo_inicial).';
  end if;
  if v_new.principal <= 0 or v_new.cuota <= 0 then
    raise exception using errcode = '22023',
      message = format('El principal (%s) y la cuota (%s) son de más de cero.', v_new.principal, v_new.cuota);
  end if;
  if v_new.saldo_inicial < 0 or v_new.saldo_inicial > v_new.principal then
    raise exception using errcode = '22023',
      message = format('El saldo inicial (%s, lo que se debía al %s) va de 0 al principal (%s): ¿están al revés?', v_new.saldo_inicial,
                       v_new.saldo_inicial_al, v_new.principal);
  end if;
  if v_new.estado not in ('vigente', 'pagado', 'cancelado') then
    raise exception using errcode = '22023',
      message = format('El estado de un préstamo es vigente, pagado o cancelado: llegó «%s».', v_new.estado);
  end if;
  foreach v_x in array array[v_new.cuenta, v_new.cuenta_largo, v_new.cuenta_interes, v_new.cuenta_banco] loop
    if v_x is not null and fn_puente_cuenta_mal(v_x) is not null then
      raise exception using errcode = 'MX004', message = format('Préstamo: %s.', fn_puente_cuenta_mal(v_x));
    end if;
  end loop;
  if (select c.tipo from cuentas c where c.codigo = v_new.cuenta) <> 'pasivo'
     or (v_new.cuenta_largo is not null and (select c.tipo from cuentas c where c.codigo = v_new.cuenta_largo) <> 'pasivo') then
    raise exception using errcode = 'MX004', message = 'Las cuentas de un préstamo (cuenta, cuenta_largo) son de pasivo (2510, 2520, 2530…).';
  end if;
  if (select c.tipo from cuentas c where c.codigo = v_new.cuenta_interes) not in ('gasto', 'otro_gasto') then
    raise exception using errcode = 'MX004', message = 'El interés de un préstamo es un gasto (7100).';
  end if;
  if fn_banco_tipo_cuenta(v_new.cuenta_banco) is distinct from 'banco' then
    raise exception using errcode = 'MX004', message = format('%s no es un banco de la empresa: la cuota sale de un banco.', v_new.cuenta_banco);
  end if;
  if v_new.descriptor is not null then
    begin
      perform '' ~* v_new.descriptor;
    exception when others then
      raise exception using errcode = '22023', message = format('El descriptor no es una expresión regular válida: %s', sqlerrm);
    end;
  end if;
  v_hay := v_old.id is not null and exists (select 1 from prestamo_cuotas q where q.prestamo_id = v_old.id and q.anulada_el is null);
  if v_hay and (v_new.saldo_inicial <> v_old.saldo_inicial or v_new.saldo_inicial_al <> v_old.saldo_inicial_al
                or v_new.cuenta <> v_old.cuenta or v_new.cuenta_interes <> v_old.cuenta_interes
                or v_new.cuenta_banco <> v_old.cuenta_banco) then
    raise exception using errcode = 'MX008',
      message = 'Ese préstamo ya tiene cuotas: su saldo inicial, su fecha y sus cuentas no cambian (des-casa y anula sus cuotas antes).';
  end if;
  perform fn_banco_marca('prestamo:' || v_new.id);
  if v_old.id is null then
    insert into prestamos (id, prestamista, descripcion, principal, tasa_anual, cuota, primer_pago, dia_pago, plazo_meses, cuenta,
                           cuenta_largo, cuenta_interes, cuenta_banco, saldo_inicial, saldo_inicial_al, descriptor, estado, notas)
    values (v_new.id, v_new.prestamista, v_new.descripcion, v_new.principal, v_new.tasa_anual, v_new.cuota, v_new.primer_pago,
            v_new.dia_pago, v_new.plazo_meses, v_new.cuenta, v_new.cuenta_largo, v_new.cuenta_interes, v_new.cuenta_banco,
            v_new.saldo_inicial, v_new.saldo_inicial_al, v_new.descriptor, v_new.estado, v_new.notas)
    returning * into v_new;
  else
    update prestamos
       set prestamista = v_new.prestamista, descripcion = v_new.descripcion, principal = v_new.principal,
           tasa_anual = v_new.tasa_anual, cuota = v_new.cuota, primer_pago = v_new.primer_pago, dia_pago = v_new.dia_pago,
           plazo_meses = v_new.plazo_meses, cuenta = v_new.cuenta, cuenta_largo = v_new.cuenta_largo,
           cuenta_interes = v_new.cuenta_interes, cuenta_banco = v_new.cuenta_banco, saldo_inicial = v_new.saldo_inicial,
           saldo_inicial_al = v_new.saldo_inicial_al, descriptor = v_new.descriptor, estado = v_new.estado, notas = v_new.notas
     where id = v_new.id
    returning * into v_new;
  end if;
  perform fn_banco_marca(null);
  return to_jsonb(v_new);
end $$;
revoke execute on function public.fn_prestamo_guardar(jsonb) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_prestamo_cuota(prestamo, movimiento, fecha, monto, capital, interes,
-- motivo) — «Cuota del préstamo»: el cargo del banco (p_movimiento) se
-- parte en capital e interés y se postea (Dr cuenta del préstamo capital /
-- Dr 7100 interés / Cr el banco), casado con su movimiento. Del statement
-- del prestamista: p_capital y/o p_interes (manda sobre la fórmula; con
-- uno, el otro es el resto). Sin movimiento (el banco todavía no llegó):
-- p_fecha y p_monto, y el cargo, cuando llegue, casa solo con su línea.
-- Las cuotas van en orden: una anterior a la última viva no entra (se
-- anula la posterior antes, des-casándola). Con movimiento, si la cuota de
-- ese monto ya está registrada sin él (con el statement, antes que el
-- banco; hasta 60 días antes), no se registra otra (MX008): el cargo se
-- casa con ella (fn_banco_casar_con), salvo que Edgar diga en el motivo que
-- de verdad es otra cuota. Antes se registraba otra y el mes quedaba con
-- dos cuotas (capital e interés dos veces).
--   _rpc('fn_prestamo_cuota', { p_prestamo: '…', p_movimiento: '…' })
--   _rpc('fn_prestamo_cuota', { p_prestamo: '…', p_movimiento: '…', p_capital: '842.10', p_interes: '187.23' })
-- ---------------------------------------------------------------------
create or replace function public.fn_prestamo_cuota(p_prestamo uuid, p_movimiento uuid default null, p_fecha date default null,
                                                    p_monto text default null, p_capital text default null,
                                                    p_interes text default null, p_motivo text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m        movimientos_banco;
  p        prestamos;
  v_fecha  date;
  v_monto  numeric;
  v_cap    numeric;
  v_int    numeric;
  v_saldo  numeric;
  v_part   jsonb;
  v_fuente text;
  v_banco  text;
  v_id     uuid := gen_random_uuid();
  v_lineas jsonb;
  v_res    jsonb;
  v_ult    date;
  v_motivo text := fn_banco_limpio(p_motivo);
  v_ya     text;
  v_ya_as  text;
  v_cap1   numeric;
  v_cap2   numeric;
begin
  perform fn_banco_exigir_dueno();
  if p_movimiento is not null then
    m := fn_banco_tomar(p_movimiento);
    if m.monto >= 0 then
      raise exception using errcode = 'MX008', message = 'La cuota de un préstamo es un cargo (sale dinero), y este movimiento entra.';
    end if;
    if fn_banco_tipo_cuenta(m.cuenta) is distinct from 'banco' then
      raise exception using errcode = 'MX008', message = 'La cuota de un préstamo sale de un banco.';
    end if;
    v_fecha := m.fecha;
    v_monto := -m.monto;
    v_banco := m.cuenta;
    if p_fecha is not null and p_fecha <> v_fecha then
      raise exception using errcode = 'MX008', message = format('La cuota va con la fecha del banco (%s), no con %s.', v_fecha, p_fecha);
    end if;
    if fn_banco_limpio(p_monto) is not null and fn_banco_saldo_texto(p_monto, 'El monto') <> v_monto then
      raise exception using errcode = 'MX001', message = format('El banco cobró %s: la cuota es eso.', v_monto);
    end if;
  else
    perform pg_advisory_xact_lock(820261001, hashtext('casar'));
    if p_fecha is null or fn_banco_limpio(p_monto) is null then
      raise exception using errcode = '22023', message = 'Sin movimiento del banco, la cuota dice su fecha y su monto.';
    end if;
    v_fecha := p_fecha;
    v_monto := fn_banco_saldo_texto(p_monto, 'El monto de la cuota');
    if v_fecha < fn_puente_corte() then
      raise exception using errcode = 'MX002', message = 'Una cuota de antes del corte está en QuickBooks (y en la apertura).';
    end if;
  end if;
  select * into p from prestamos where id = p_prestamo for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese préstamo (fn_prestamo_guardar lo da de alta).';
  end if;
  if p.estado <> 'vigente' then
    raise exception using errcode = 'MX008', message = format('El préstamo de %s está %s.', p.prestamista, p.estado);
  end if;
  if m.id is not null and v_motivo is null then
    select string_agg(format('del %s por %s (%s)', q.fecha, q.monto, a.numero), ', ' order by q.fecha), min(q.asiento_id::text)
      into v_ya, v_ya_as
      from prestamo_cuotas q
      join asientos a on a.id = q.asiento_id
     where q.prestamo_id = p.id and q.anulada_el is null and q.movimiento_id is null and q.monto = v_monto
       and q.fecha between v_fecha - 60 and v_fecha + 3
       and exists (select 1 from asiento_lineas l
                    where l.asiento_id = q.asiento_id and l.cuenta = m.cuenta
                      and not exists (select 1 from banco_casado_lineas cl
                                       where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente));
    if v_ya is not null then
      raise exception using errcode = 'MX008',
        message = format('La cuota %s de %s ya está registrada (con el statement del prestamista) y espera su cargo del banco: '
                         'cásalo con ella (fn_banco_casar_con con {"asiento": "%s"}). Registrar otra la pondría dos veces '
                         '(capital e interés). Si de verdad es otra cuota, dilo en el motivo.', v_ya, p.prestamista, v_ya_as);
    end if;
    -- (Ronda 4) La registrada por OTRO monto a 10 días o menos: es ella (la
    -- cuota redondeada, un recargo). Registrar otra, solo con su motivo.
    select string_agg(format('del %s por %s', q.fecha, q.monto), ', ' order by q.fecha), min(q.id::text)
      into v_ya, v_ya_as
      from prestamo_cuotas q
     where q.prestamo_id = p.id and q.anulada_el is null and q.movimiento_id is null and q.monto <> v_monto
       and q.fecha between v_fecha - 10 and v_fecha + 10;
    if v_ya is not null then
      raise exception using errcode = 'MX008',
        message = format('La cuota %s de %s ya está registrada y espera su cargo del banco, que cobró %s: es ella (redondeada, o con '
                         'un recargo). Cásalo con ella y di a dónde va la diferencia (fn_banco_casar_con con {"cuota": "%s", '
                         '"diferencia": "capital"} o "interes"). Registrar otra la pondría dos veces. Si de verdad es otra cuota, '
                         'dilo en el motivo.', v_ya, p.prestamista, v_monto, v_ya_as);
    end if;
  end if;
  if v_banco is null then
    v_banco := p.cuenta_banco;
  end if;
  if v_monto <= 0 then
    raise exception using errcode = 'MX005', message = 'La cuota es de más de cero.';
  end if;
  if v_fecha < p.saldo_inicial_al then
    raise exception using errcode = 'MX008',
      message = format('La cuota del %s es de antes del saldo inicial del préstamo (%s): ya está en ese saldo.', v_fecha,
                       p.saldo_inicial_al);
  end if;
  select max(q.fecha) into v_ult from prestamo_cuotas q where q.prestamo_id = p.id and q.anulada_el is null;
  if v_ult > v_fecha then
    raise exception using errcode = 'MX008',
      message = format('El préstamo ya tiene una cuota del %s, posterior a esta (%s): las cuotas van en orden (su saldo es el de '
                       'la anterior). Des-casa la posterior, registra esta y vuelve a registrar aquella.', v_ult, v_fecha);
  end if;
  v_saldo := fn_prestamo_saldo(p.id, v_fecha);
  if fn_banco_limpio(p_capital) is not null or fn_banco_limpio(p_interes) is not null then
    -- Del statement: manda.
    v_fuente := 'statement';
    v_cap := case when fn_banco_limpio(p_capital) is not null then fn_puente_monto(p_capital, 'El capital', true) end;
    v_int := case when fn_banco_limpio(p_interes) is not null then fn_puente_monto(p_interes, 'El interés', true) end;
    v_cap := coalesce(v_cap, v_monto - v_int);
    v_int := coalesce(v_int, v_monto - v_cap);
    if v_cap < 0 or v_int < 0 or v_cap + v_int <> v_monto then
      raise exception using errcode = 'MX001',
        message = format('Capital (%s) más interés (%s) tienen que ser la cuota (%s), al centavo.', v_cap, v_int, v_monto);
    end if;
    v_part := jsonb_build_object('saldo_antes', v_saldo, 'fuente', 'statement', 'capital', v_cap, 'interes', v_int,
                                 'formula_decia', fn_prestamo_particion(p.id, v_fecha, v_monto));
  else
    v_fuente := 'formula';
    v_part := fn_prestamo_particion(p.id, v_fecha, v_monto);
    if (v_part->>'no_cuadra')::boolean then
      raise exception using errcode = 'MX005',
        message = format('%s Registra la cuota con el capital y el interés del statement (p_capital, p_interes).', v_part->>'aviso');
    end if;
    if (v_part->>'pide_statement')::boolean then
      raise exception using errcode = 'MX008',
        message = format('Ese pago a %s no va por la fórmula (%s). Regístralo con el capital y el interés del statement del '
                         'prestamista (p_capital, p_interes)%s.', p.prestamista, v_part->>'aviso',
                         case when v_part->>'aviso' like 'a % días de la cuota%'
                              then format('; un abono solo a capital va todo a capital (p_capital = %s, p_interes = 0)', v_monto)
                              else '' end);
    end if;
    v_cap := (v_part->>'capital')::numeric;
    v_int := (v_part->>'interes')::numeric;
  end if;
  if v_cap > v_saldo then
    raise exception using errcode = 'MX008',
      message = format('El capital (%s) pasa de lo que se debe del préstamo (%s): revisa el saldo inicial o el statement.', v_cap, v_saldo);
  end if;
  -- El asiento: la línea del banco primero (la que casa con el movimiento).
  v_lineas := jsonb_build_array(jsonb_build_object('cuenta', v_banco, 'monto', (-v_monto)::text,
                                                   'memo', left(format('Cuota %s', p.prestamista), 200)));
  -- EL CAPITAL baja la cuenta del préstamo que tiene el saldo: primero la
  -- porción corriente (cuenta, 2520) mientras tenga saldo acreedor, y lo
  -- demás el largo plazo (cuenta_largo, 2530). La apertura trae el préstamo
  -- como lo tiene QuickBooks (una fila de la balanza, una cuenta: casi
  -- siempre entero en 2530), y el reparto entre las dos lo postea el cierre
  -- (f08). Antes el capital bajaba siempre 2520: desde la primera cuota
  -- quedaba con saldo DEUDOR (c4 lo enseñaba como un activo, «pasivos
  -- pagados de más») y 2530 sin bajar, los dos inflados en todo el capital
  -- pagado.
  if v_cap > 0 then
    v_cap1 := case when p.cuenta_largo is null or p.cuenta_largo = p.cuenta then v_cap
                   else least(v_cap, greatest(-fn_banco_saldo_libros(p.cuenta, v_fecha), 0)) end;
    v_cap2 := v_cap - v_cap1;
    if v_cap1 > 0 then
      v_lineas := v_lineas || jsonb_build_array(jsonb_build_object('cuenta', p.cuenta, 'monto', v_cap1::text,
                                                                   'memo', left(format('Capital · %s%s', p.prestamista,
                                                                                       coalesce(' · ' || p.descripcion, '')), 200)));
    end if;
    if v_cap2 > 0 then
      v_lineas := v_lineas || jsonb_build_array(jsonb_build_object('cuenta', p.cuenta_largo, 'monto', v_cap2::text,
                                                                   'memo', left(format('Capital · %s%s (del largo plazo: la corriente '
                                                                                       'no tiene ese saldo)', p.prestamista,
                                                                                       coalesce(' · ' || p.descripcion, '')), 200)));
    end if;
  end if;
  if v_int > 0 then
    v_lineas := v_lineas || jsonb_build_array(jsonb_build_object('cuenta', p.cuenta_interes, 'monto', v_int::text,
                                                                 'memo', left(format('Interés · %s%s', p.prestamista,
                                                                                     coalesce(' · ' || p.descripcion, '')), 200)));
  end if;
  v_res := fn_banco_asiento('prestamo_cuotas', v_id::text, v_fecha,
             format('Cuota del préstamo de %s%s: capital %s, interés %s (%s)', p.prestamista, coalesce(' (' || p.descripcion || ')', ''),
                    v_cap, v_int, case v_fuente when 'statement' then 'del statement' else 'por la fórmula' end),
             v_lineas,
             case when m.id is not null then fn_banco_proc(m, 'fn_prestamo_cuota', 'R8 cuota del préstamo')
                  else jsonb_build_object('funcion', 'fn_prestamo_cuota') end
             || jsonb_build_object('prestamo', p.id, 'particion', v_part) || jsonb_strip_nulls(jsonb_build_object('motivo_edgar', v_motivo)));
  perform fn_banco_marca('cuota:' || v_id);
  insert into prestamo_cuotas (id, prestamo_id, fecha, monto, capital, interes, fuente, formula, saldo_antes, saldo_despues,
                               movimiento_id, asiento_id, motivo)
  values (v_id, p.id, v_fecha, v_monto, v_cap, v_int, v_fuente, v_part, v_saldo, v_saldo - v_cap, m.id, (v_res->>'id')::uuid,
          v_motivo);
  perform fn_banco_marca(null);
  if m.id is not null then
    perform fn_banco_casar_lineas(m.id, 'cuota_prestamo', v_id::text, (v_res->>'id')::uuid,
                                  jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 1)),
                                  'R8 cuota del préstamo (' || v_fuente || ')', false, true, v_motivo);
  end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'cuota', v_id, 'prestamo', p.id, 'prestamista', p.prestamista, 'fecha', v_fecha, 'monto', v_monto, 'capital', v_cap,
    'interes', v_int, 'fuente', v_fuente, 'saldo_antes', v_saldo, 'saldo_despues', v_saldo - v_cap,
    'asiento_id', v_res->>'id', 'numero', v_res->>'numero', 'movimiento', m.id,
    'tardio', v_res->>'tardio',
    'aviso', case when m.id is null then 'Cuando llegue el cargo del banco, casa solo con esta cuota.' end));
end $$;
revoke execute on function public.fn_prestamo_cuota(uuid, uuid, date, text, text, text, text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_prestamo_cuota(uuid, uuid, date, text, text, text, text) to authenticated;
-- =====================================================================
-- 8 · LOS PREPAGADOS (f06): el seguro y la fianza pagados por adelantado
--     se van al gasto día por día de su cobertura.
-- =====================================================================
-- Un asiento ESTÁNDAR por mes (y otro aparte para la prima de WC, que va a
-- 5015: c3 no deja la mano de obra en un asiento con otras cuentas que
-- 1410), con una línea por póliza: Dr su gasto / Cr 1410 o 1420. Por
-- ACUMULADO: lo del mes es lo que toca hasta su último día menos lo ya
-- amortizado. Así un mes que se quedó sin amortizar (ya cerrado) lo
-- recoge el siguiente, y una póliza corregida (monto, fechas) se ajusta
-- sola en el mes abierto. Lo de antes del corte lo amortizó QuickBooks: el
-- libro amortiza desde octubre lo que falta, que es lo que dice la
-- balanza de QuickBooks para esa póliza (su saldo_corte), no un cálculo.
-- ---------------------------------------------------------------------

-- Lo que el LIBRO lleva amortizado de una póliza hasta p_al, por días
-- (con los dos extremos incluidos). Una póliza que empezó en el corte o
-- después: su monto, de su desde a su hasta. Una que empezó ANTES: lo que
-- tenía por amortizar al corte (su saldo_corte, el número de la balanza
-- de QuickBooks), del corte a su hasta; sin él (una póliza de una versión
-- anterior), el cálculo por días de lo que le quedaba. El último día,
-- todo: el redondeo no deja centavos colgando y 1410 queda en cero al
-- vencer. (La versión anterior, sin el saldo al corte, se quita.)
drop function if exists public.fn_prepagado_acumulado(numeric, date, date, date, date);
create or replace function public.fn_prepagado_acumulado(p_monto numeric, p_desde date, p_hasta date, p_corte date, p_al date,
                                                         p_saldo_corte numeric)
returns numeric
language sql
immutable
set search_path = public, pg_temp
as $$
  with k as (select (case when p_desde < p_corte
                          then coalesce(p_saldo_corte,
                                        p_monto - round(p_monto * (least(p_corte - 1, p_hasta) - p_desde + 1) / (p_hasta - p_desde + 1), 2))
                          else p_monto end)::numeric(14,2) as base,
                    greatest(p_desde, p_corte) as ini)
  select (case when p_al < k.ini or k.base = 0 then 0
               when p_al >= p_hasta then k.base
               else round(k.base * (p_al - k.ini + 1) / (p_hasta - k.ini + 1), 2) end)::numeric(14,2)
    from k
$$;
revoke execute on function public.fn_prepagado_acumulado(numeric, date, date, date, date, numeric)
  from public, anon, authenticated, service_role;

-- Lo que el libro DEBE llevar amortizado de una póliza hasta p_al, con su
-- cancelación: una SUSTITUIDA, nada (lo que llevaba vuelve en el mes
-- abierto: lo amortiza la que la sustituye); una CANCELADA con su fecha,
-- por días hasta ella y desde ella todo lo que queda menos lo devuelto;
-- una vigente, por días (fn_prepagado_acumulado). Una cancelada de una
-- versión anterior (sin su fecha) no se mira: nulo.
create or replace function public.fn_prepagado_meta(p public.prepagados, p_corte date, p_al date)
returns numeric
language sql
immutable
set search_path = public, pg_temp
as $$
  select (case when p.sustituida_por is not null then 0
               when p.estado = 'cancelado' and p.cancelado_al is not null
               then case when p_al >= p.cancelado_al
                         then fn_prepagado_acumulado(p.monto, p.desde, p.hasta, p_corte, p.hasta, p.saldo_corte)
                              - coalesce(p.devuelto, 0)
                         else least(fn_prepagado_acumulado(p.monto, p.desde, p.hasta, p_corte, p_al, p.saldo_corte),
                                    fn_prepagado_acumulado(p.monto, p.desde, p.hasta, p_corte, p.hasta, p.saldo_corte)
                                    - coalesce(p.devuelto, 0)) end
               when p.estado = 'vigente' then fn_prepagado_acumulado(p.monto, p.desde, p.hasta, p_corte, p_al, p.saldo_corte)
          end)::numeric(14,2)
$$;
revoke execute on function public.fn_prepagado_meta(public.prepagados, date, date) from public, anon, authenticated, service_role;

-- El grupo del asiento de una póliza: la prima de WC (su gasto es mano de
-- obra, 5015) va en su propio asiento.
create or replace function public.fn_prepagado_grupo(p_cuenta_gasto text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$ select case when fn_puente_es_mano_de_obra(p_cuenta_gasto) then 'mano_de_obra' else 'general' end $$;
revoke execute on function public.fn_prepagado_grupo(text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_prepagado_guardar(prepagado jsonb) — da de alta (o cambia) una póliza
-- desde el SQL Editor, con rastro. No es de la API.
--   select fn_prepagado_guardar('{"descripcion": "GL 2026-2027 (Progressive)", "tipo": "seguro",
--     "cuenta_gasto": "6200", "monto": "4800.00", "desde": "2026-08-01", "hasta": "2027-07-31",
--     "papel_tabla": "movimientos_banco", "papel_id": "…"}');
-- cuenta: 1410 (seguro) o 1420 (fianza) si no se dice. La prima de WC:
-- cuenta_gasto 5015 (y 1410). Una fianza de una obra: proyecto_id y el
-- costo de esa obra. Con meses ya amortizados, sus cuentas y su obra no
-- cambian: se registra OTRA que la sustituye ("sustituye": el id de la
-- vieja, que queda cancelada): lo que la vieja llevaba amortizado vuelve a
-- su cuenta en el mes abierto y la nueva lo amortiza por acumulado desde
-- su inicio (antes, cancelar y registrar otra amortizaba dos veces los
-- meses ya amortizados). El monto y las fechas sí cambian: el mes abierto
-- recoge la diferencia.
-- CANCELAR una póliza (la aseguradora devuelve lo que no se usó):
--   {"id": …, "estado": "cancelado", "cancelado_al": "2026-12-15", "devuelto": "9000.00"}
-- Hasta esa fecha se amortiza por días; ese día, todo lo que queda menos
-- lo devuelto (el uso y la penalidad) va al gasto, y el depósito de la
-- aseguradora se clasifica a su cuenta (1410/1420): la póliza queda en
-- cero. Antes lo que quedaba se quedaba en 1410 sin camino.
-- Una póliza que empezó ANTES del corte dice su saldo_corte: lo que la
-- balanza de QuickBooks dejó por amortizar para ella en 1410/1420 al
-- 30-sep (QuickBooks suele amortizar 1/12 al mes con un asiento
-- recurrente, no por días: calcularlo por días dejaba 1410 en -2.19 al
-- vencer y el control en rojo para siempre). Si después se corrige su
-- monto, la diferencia va a lo que falta por amortizar (lo de QuickBooks
-- ya pasó): saldo_corte sube o baja con él, salvo que se diga otro.
-- ---------------------------------------------------------------------
create or replace function public.fn_prepagado_guardar(p_prepagado jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_sobra text;
  v_old   prepagados;
  v_new   prepagados;
  v_hay   boolean;
  v_cg    cuentas;
  v_sust  prepagados;
  v_base  numeric;
begin
  perform fn_banco_exigir_dueno();
  if p_prepagado is null or jsonb_typeof(p_prepagado) <> 'object' then
    raise exception using errcode = '22023', message = 'El prepagado va como objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(p_prepagado) k
   where k not in ('id', 'descripcion', 'tipo', 'cuenta', 'cuenta_gasto', 'proyecto_id', 'cost_code', 'monto', 'desde', 'hasta',
                   'papel_tabla', 'papel_id', 'estado', 'notas', 'saldo_corte', 'sustituye', 'cancelado_al', 'devuelto');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en el prepagado: %s.', v_sobra);
  end if;
  if p_prepagado ? 'id' then
    select * into v_old from prepagados where id = (p_prepagado->>'id')::uuid for update;
    if not found then
      raise exception using errcode = '22023', message = 'No existe ese prepagado.';
    end if;
    if p_prepagado ? 'sustituye' then
      raise exception using errcode = '22023',
        message = '«sustituye» es de una póliza NUEVA (sin id): la que reemplaza a la vieja, con sus cuentas buenas.';
    end if;
    if v_old.sustituida_por is not null then
      raise exception using errcode = 'MX008',
        message = format('Esa póliza la sustituyó otra (%s): se cambia esa.', v_old.sustituida_por);
    end if;
    v_new := v_old;
  else
    v_new.id := gen_random_uuid();
    v_new.estado := 'vigente';
    v_new.tipo := 'seguro';
    -- (la que sustituye: la vieja, vigente y con la misma cuenta del activo)
    if fn_banco_limpio(p_prepagado->>'sustituye') is not null then
      select * into v_sust from prepagados
       where id = case when p_prepagado->>'sustituye' ~ '^[0-9a-fA-F-]{36}$' then (p_prepagado->>'sustituye')::uuid end for update;
      if not found then
        raise exception using errcode = '22023', message = format('No existe la póliza que sustituye (%s).', p_prepagado->>'sustituye');
      end if;
      if v_sust.estado <> 'vigente' then
        raise exception using errcode = 'MX008',
          message = format('«%s» ya está cancelada%s: no se sustituye.', v_sust.descripcion,
                           coalesce(' (la sustituyó ' || v_sust.sustituida_por || ')', ''));
      end if;
      v_new.descripcion := v_sust.descripcion;
      v_new.tipo := v_sust.tipo;
      v_new.cuenta := v_sust.cuenta;
      v_new.cuenta_gasto := v_sust.cuenta_gasto;
      v_new.proyecto_id := v_sust.proyecto_id;
      v_new.cost_code := v_sust.cost_code;
      v_new.monto := v_sust.monto;
      v_new.desde := v_sust.desde;
      v_new.hasta := v_sust.hasta;
      v_new.saldo_corte := v_sust.saldo_corte;
      v_new.papel_tabla := v_sust.papel_tabla;
      v_new.papel_id := v_sust.papel_id;
    end if;
  end if;
  v_new.descripcion  := coalesce(fn_banco_limpio(p_prepagado->>'descripcion'), v_new.descripcion);
  v_new.tipo         := coalesce(lower(fn_banco_limpio(p_prepagado->>'tipo')), v_new.tipo);
  -- (en español: seguro, fianza u otro; antes «insurance» decía que faltaba
  -- algo, o salía el check de la tabla con la fila entera)
  if v_new.tipo not in ('seguro', 'fianza', 'otro') then
    raise exception using errcode = '22023',
      message = format('El tipo de un prepagado es seguro, fianza u otro (en español): llegó «%s».', p_prepagado->>'tipo');
  end if;
  v_new.cuenta       := coalesce(fn_banco_limpio(p_prepagado->>'cuenta'), v_new.cuenta,
                                 case v_new.tipo when 'seguro' then '1410' when 'fianza' then '1420' end);
  v_new.cuenta_gasto := coalesce(fn_banco_limpio(p_prepagado->>'cuenta_gasto'), v_new.cuenta_gasto);
  v_new.proyecto_id  := case when p_prepagado ? 'proyecto_id' then fn_banco_limpio(p_prepagado->>'proyecto_id') else v_new.proyecto_id end;
  v_new.cost_code    := case when p_prepagado ? 'cost_code' then fn_banco_limpio(p_prepagado->>'cost_code') else v_new.cost_code end;
  v_new.monto        := coalesce(fn_banco_saldo_texto(p_prepagado->>'monto', 'El monto'), v_new.monto);
  v_new.desde        := coalesce(case when fn_banco_limpio(p_prepagado->>'desde') is not null then fn_puente_fecha_texto(p_prepagado->>'desde', 'Desde') end, v_new.desde);
  v_new.hasta        := coalesce(case when fn_banco_limpio(p_prepagado->>'hasta') is not null then fn_puente_fecha_texto(p_prepagado->>'hasta', 'Hasta') end, v_new.hasta);
  v_new.papel_tabla  := case when p_prepagado ? 'papel_tabla' then fn_banco_limpio(p_prepagado->>'papel_tabla') else v_new.papel_tabla end;
  v_new.papel_id     := case when p_prepagado ? 'papel_id' then fn_banco_limpio(p_prepagado->>'papel_id') else v_new.papel_id end;
  v_new.estado       := coalesce(fn_banco_limpio(p_prepagado->>'estado'), v_new.estado);
  v_new.notas        := case when p_prepagado ? 'notas' then fn_banco_limpio(p_prepagado->>'notas') else v_new.notas end;
  if v_new.descripcion is null or v_new.cuenta is null or v_new.cuenta_gasto is null or v_new.monto is null
     or v_new.desde is null or v_new.hasta is null then
    raise exception using errcode = '22023',
      message = 'Un prepagado dice descripcion, cuenta_gasto, monto, desde y hasta (y la cuenta, si no es seguro ni fianza).';
  end if;
  if v_new.estado not in ('vigente', 'cancelado') then
    raise exception using errcode = '22023',
      message = format('El estado de un prepagado es vigente o cancelado: llegó «%s».', v_new.estado);
  end if;
  if v_new.monto <= 0 then
    raise exception using errcode = '22023', message = format('El monto de la póliza (%s) es de más de cero.', v_new.monto);
  end if;
  if v_new.hasta < v_new.desde then
    raise exception using errcode = '22023',
      message = format('La cobertura va de desde (%s) a hasta (%s): hasta no puede ir antes.', v_new.desde, v_new.hasta);
  end if;
  -- Lo que tenía por amortizar al corte (ver arriba).
  if fn_banco_limpio(p_prepagado->>'saldo_corte') is not null then
    v_new.saldo_corte := fn_banco_saldo_texto(p_prepagado->>'saldo_corte', 'El saldo al corte');
  elsif v_old.id is not null and v_old.saldo_corte is not null and v_new.monto <> v_old.monto then
    v_new.saldo_corte := greatest(v_old.saldo_corte + (v_new.monto - v_old.monto), 0);
  end if;
  if v_new.desde >= fn_puente_corte() then
    if v_new.saldo_corte is not null and v_new.saldo_corte <> v_new.monto and fn_banco_limpio(p_prepagado->>'saldo_corte') is not null then
      raise exception using errcode = '22023',
        message = 'saldo_corte es solo de una póliza que empezó antes del corte (lo que QuickBooks dejó por amortizar al 30-sep).';
    end if;
    v_new.saldo_corte := null;
  elsif v_new.saldo_corte is null then
    raise exception using errcode = '22023',
      message = format('La póliza empezó el %s, antes del corte (%s): di su saldo_corte, lo que la balanza de QuickBooks dejó por '
                       'amortizar para ella en %s al 30-sep (el número de la apertura, no uno calculado).', v_new.desde,
                       fn_puente_corte(), v_new.cuenta);
  elsif v_new.saldo_corte < 0 or v_new.saldo_corte > v_new.monto then
    raise exception using errcode = 'MX005',
      message = format('El saldo al corte (%s) va de 0 al monto de la póliza (%s).', v_new.saldo_corte, v_new.monto);
  end if;
  if fn_puente_cuenta_mal(v_new.cuenta) is not null or fn_puente_cuenta_mal(v_new.cuenta_gasto) is not null then
    raise exception using errcode = 'MX004',
      message = format('Prepagado: %s.', coalesce(fn_puente_cuenta_mal(v_new.cuenta), fn_puente_cuenta_mal(v_new.cuenta_gasto)));
  end if;
  if (select c.tipo from cuentas c where c.codigo = v_new.cuenta) <> 'activo' then
    raise exception using errcode = 'MX004', message = format('%s no es de activo: lo pagado por adelantado es un activo (1410, 1420).', v_new.cuenta);
  end if;
  select * into v_cg from cuentas where codigo = v_new.cuenta_gasto;
  if v_cg.tipo not in ('costo', 'gasto', 'otro_gasto') then
    raise exception using errcode = 'MX004', message = format('%s no es un costo ni un gasto.', v_new.cuenta_gasto);
  end if;
  if fn_puente_es_mano_de_obra(v_new.cuenta_gasto)
     and (v_new.cuenta <> '1410' or v_cg.regla_obra <> 'prohibida' or v_new.proyecto_id is not null) then
    raise exception using errcode = 'MX004',
      message = 'La prima de WC va de 1410 a una bolsa sin obra (5015): el burden de obra (5010) sale solo por su reparto.';
  end if;
  if (v_cg.regla_obra = 'obligatoria' and v_new.proyecto_id is null) or (v_cg.regla_obra = 'prohibida' and v_new.proyecto_id is not null)
     or (v_cg.regla_cost_code = 'obligatoria' and v_new.cost_code is null)
     or (v_cg.regla_cost_code = 'prohibida' and v_new.cost_code is not null) then
    raise exception using errcode = 'MX004',
      message = format('%s (%s): la obra es %s y el cost code %s en esa cuenta.', v_cg.codigo, v_cg.nombre, v_cg.regla_obra,
                       v_cg.regla_cost_code);
  end if;
  if v_new.proyecto_id is not null and not exists (select 1 from proyectos pr where pr.id::text = v_new.proyecto_id) then
    raise exception using errcode = '22023', message = format('No existe la obra %s.', v_new.proyecto_id);
  end if;
  v_hay := v_old.id is not null
           and exists (select 1 from prepagados_amortizaciones a where a.prepagado_id = v_old.id and a.vigente);
  if v_hay and (v_new.cuenta <> v_old.cuenta or v_new.cuenta_gasto <> v_old.cuenta_gasto
                or v_new.proyecto_id is distinct from v_old.proyecto_id or v_new.cost_code is distinct from v_old.cost_code) then
    raise exception using errcode = 'MX008',
      message = format('Ese prepagado ya tiene meses amortizados: sus cuentas y su obra no cambian. Registra la que lo sustituye, con '
                       'las buenas: fn_prepagado_guardar(''{"sustituye": "%s", "cuenta_gasto": "…"}''): lo amortizado vuelve a su '
                       'cuenta en el mes abierto y la nueva lo amortiza desde su inicio (cancelarlo y registrar otra lo amortizaría '
                       'dos veces).', v_old.id);
  end if;
  if v_sust.id is not null and v_new.cuenta <> v_sust.cuenta then
    raise exception using errcode = 'MX008',
      message = format('La que sustituye va en la misma cuenta que la vieja (%s): el dinero de la póliza está ahí.', v_sust.cuenta);
  end if;
  -- LA CANCELACIÓN: su fecha y lo devuelto (ver arriba). Volver a vigente
  -- las quita.
  if v_new.estado = 'cancelado' and v_sust.id is null then
    v_new.cancelado_al := coalesce(case when fn_banco_limpio(p_prepagado->>'cancelado_al') is not null
                                        then fn_puente_fecha_texto(p_prepagado->>'cancelado_al', 'La fecha de la cancelación') end,
                                   v_new.cancelado_al);
    v_new.devuelto := coalesce(fn_banco_saldo_texto(p_prepagado->>'devuelto', 'Lo devuelto'), v_new.devuelto, 0);
    if v_new.cancelado_al is null then
      raise exception using errcode = '22023',
        message = 'Cancelar una póliza dice su fecha y lo que devolvió la aseguradora: {"estado": "cancelado", "cancelado_al": '
                  '"AAAA-MM-DD", "devuelto": "…"} (lo que quede, el uso y la penalidad, va al gasto ese día). Si es para '
                  'corregirla, registra la que la sustituye ("sustituye").';
    end if;
    v_base := fn_prepagado_acumulado(v_new.monto, v_new.desde, v_new.hasta, fn_puente_corte(), v_new.hasta, v_new.saldo_corte);
    if v_new.cancelado_al < greatest(v_new.desde, fn_puente_corte()) or v_new.cancelado_al > v_new.hasta then
      raise exception using errcode = '22023',
        message = format('La cancelación (%s) va dentro de la cobertura que lleva el libro (%s a %s).', v_new.cancelado_al,
                         greatest(v_new.desde, fn_puente_corte()), v_new.hasta);
    end if;
    if v_new.devuelto < 0 or v_new.devuelto > v_base then
      raise exception using errcode = 'MX005',
        message = format('Lo devuelto (%s) va de 0 a lo que el libro tenía por amortizar de ella (%s).', v_new.devuelto, v_base);
    end if;
  elsif v_new.estado = 'vigente' then
    v_new.cancelado_al := null;
    v_new.devuelto := null;
  end if;
  perform fn_banco_marca('prepagado:' || v_new.id);
  if v_old.id is null then
    insert into prepagados (id, descripcion, tipo, cuenta, cuenta_gasto, proyecto_id, cost_code, monto, desde, hasta, saldo_corte,
                            papel_tabla, papel_id, estado, notas, cancelado_al, devuelto)
    values (v_new.id, v_new.descripcion, v_new.tipo, v_new.cuenta, v_new.cuenta_gasto, v_new.proyecto_id, v_new.cost_code, v_new.monto,
            v_new.desde, v_new.hasta, v_new.saldo_corte, v_new.papel_tabla, v_new.papel_id, v_new.estado, v_new.notas,
            v_new.cancelado_al, v_new.devuelto)
    returning * into v_new;
  else
    update prepagados
       set descripcion = v_new.descripcion, tipo = v_new.tipo, cuenta = v_new.cuenta, cuenta_gasto = v_new.cuenta_gasto,
           proyecto_id = v_new.proyecto_id, cost_code = v_new.cost_code, monto = v_new.monto, desde = v_new.desde, hasta = v_new.hasta,
           saldo_corte = v_new.saldo_corte, papel_tabla = v_new.papel_tabla, papel_id = v_new.papel_id, estado = v_new.estado,
           notas = v_new.notas, cancelado_al = v_new.cancelado_al, devuelto = v_new.devuelto
     where id = v_new.id
    returning * into v_new;
  end if;
  perform fn_banco_marca(null);
  -- (la vieja queda cancelada y dice quién la sustituye: su amortizado
  -- vuelve en el mes abierto)
  if v_sust.id is not null then
    perform fn_banco_marca('prepagado:' || v_sust.id);
    update prepagados
       set estado = 'cancelado', sustituida_por = v_new.id,
           notas = concat_ws(' · ', v_sust.notas, format('La sustituye %s (%s)', v_new.id, v_new.cuenta_gasto))
     where id = v_sust.id;
    perform fn_banco_marca(null);
  end if;
  return to_jsonb(v_new) || case when v_sust.id is not null then jsonb_build_object('sustituye', v_sust.id) else '{}'::jsonb end;
end $$;
revoke execute on function public.fn_prepagado_guardar(jsonb) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- fn_prepagados_amortizar(periodo) — «Amortizar el mes»: el asiento
-- estándar del mes (uno, y otro para WC si hay), por acumulado. Idempotente:
-- si ya está y nada cambió, no hace nada; si cambió una póliza (o se
-- canceló), reversa el del mes y pone el bueno (sustituye_a). Un mes
-- cerrado no se toca (lo que falte lo recoge el mes abierto), y un mes
-- anterior a uno ya amortizado tampoco (se amortiza el último: recoge el
-- cambio). Una póliza SUSTITUIDA devuelve en el mes lo que llevaba (su
-- meta es cero: lo amortiza la que la sustituye); una CANCELADA con su
-- fecha lleva al gasto, en el mes de la cancelación, lo que queda menos lo
-- devuelto (fn_prepagado_meta).
--   _rpc('fn_prepagados_amortizar', { p_periodo: '2026-10' })
-- ---------------------------------------------------------------------
create or replace function public.fn_prepagados_amortizar(p_periodo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_per    periodos;
  v_corte  date := fn_puente_corte();
  v_grupo  text;
  v_oid    text;
  v_filas  jsonb;
  v_firma  jsonb;
  v_viejo  asientos;
  v_lineas jsonb;
  v_res    jsonb;
  v_rev    jsonb;
  v_out    jsonb := '[]'::jsonb;
  v_avisos jsonb := '[]'::jsonb;
  v_mas    text;
  r        record;
begin
  perform fn_banco_exigir_dueno();
  select * into v_per from periodos where periodo = p_periodo;
  if not found or v_per.tipo <> 'mes' then
    raise exception using errcode = '22023', message = format('%s no es un mes del libro (AAAA-MM).', coalesce(p_periodo, 'nulo'));
  end if;
  if v_per.hasta < v_corte then
    raise exception using errcode = 'MX002', message = 'Antes del corte lo amortizó QuickBooks.';
  end if;
  if v_per.estado <> 'abierto' then
    raise exception using errcode = 'MX002',
      message = format('%s está cerrado: lo que le faltó lo recoge el mes abierto siguiente (se amortiza por acumulado).', p_periodo);
  end if;
  perform pg_advisory_xact_lock(820261001, hashtext('amortizar'));
  -- Una póliza de antes del corte sin su saldo al corte (de una versión
  -- anterior) no se amortiza a ciegas.
  select string_agg(p.descripcion, ', ' order by p.descripcion) into v_mas
    from prepagados p where p.estado = 'vigente' and p.desde < v_corte and p.saldo_corte is null;
  if v_mas is not null then
    raise exception using errcode = 'MX008',
      message = format('%s empezó antes del corte y no dice su saldo al corte (lo que la balanza de QuickBooks dejó por amortizar '
                       'para ella): dilo con fn_prepagado_guardar({"id": …, "saldo_corte": "…"}) y vuelve a amortizar.', v_mas);
  end if;
  select string_agg(distinct a.periodo, ', ') into v_mas
    from prepagados_amortizaciones a where a.vigente and a.periodo > p_periodo;
  if v_mas is not null then
    raise exception using errcode = 'MX008',
      message = format('Ya está amortizado %s, posterior a %s: amortiza ese mes otra vez (recoge el cambio por acumulado).', v_mas,
                       p_periodo);
  end if;

  foreach v_grupo in array array['general', 'mano_de_obra'] loop
    v_oid := p_periodo || case when v_grupo = 'mano_de_obra' then '|mano_de_obra' else '' end;
    -- Lo que toca a cada póliza este mes.
    select coalesce(jsonb_agg(jsonb_build_object('prepagado', x.id, 'descripcion', x.descripcion, 'cuenta', x.cuenta,
                                                 'cuenta_gasto', x.cuenta_gasto, 'proyecto_id', x.proyecto_id,
                                                 'cost_code', x.cost_code, 'monto', x.acum - x.previo, 'acumulado', x.acum,
                                                 'del_mes', x.acum - x.acum_antes) order by x.id), '[]'::jsonb)
      into v_filas
      from (select p.id, p.descripcion, p.cuenta, p.cuenta_gasto, p.proyecto_id, p.cost_code,
                   fn_prepagado_meta(p, v_corte, v_per.hasta) as acum,
                   fn_prepagado_meta(p, v_corte, v_per.desde - 1) as acum_antes,
                   coalesce((select sum(a.monto) from prepagados_amortizaciones a
                              where a.prepagado_id = p.id and a.vigente and a.periodo < p_periodo), 0) as previo
              from prepagados p
             where (p.estado = 'vigente' or p.sustituida_por is not null or p.cancelado_al is not null)
               and fn_prepagado_grupo(p.cuenta_gasto) = v_grupo) x
     where x.acum - x.previo <> 0;
    v_firma := (select coalesce(jsonb_agg(jsonb_build_object('prepagado', f->>'prepagado', 'monto', f->>'monto', 'cuenta', f->>'cuenta',
                                                           'cuenta_gasto', f->>'cuenta_gasto', 'proyecto_id', f->>'proyecto_id',
                                                           'cost_code', f->>'cost_code')
                                          order by f->>'prepagado'), '[]'::jsonb)
                  from jsonb_array_elements(v_filas) f);
    -- El asiento vivo de ese mes (si hay).
    select a.* into v_viejo from asientos a
     where a.origen_tabla = 'prepagados' and a.origen_id = v_oid and a.camino not in ('reverso', 'reverso_automatico')
       and not exists (select 1 from asientos r2 where r2.reversa_a = a.id and r2.camino = 'reverso');
    if v_viejo.id is not null and v_viejo.procedencia->'firma' = v_firma then
      v_out := v_out || jsonb_build_array(jsonb_build_object('grupo', v_grupo, 'asiento_id', v_viejo.id, 'numero', v_viejo.numero,
                                                             'sin_cambios', true));
      v_viejo := null;
      continue;
    end if;
    if v_viejo.id is not null then
      v_rev := fn_reversar_interno(v_viejo.id, format('Se rehace la amortización de %s: cambió una póliza.', p_periodo), 'reverso',
                                   jsonb_build_object('funcion', 'fn_prepagados_amortizar'));
      perform fn_banco_marca('amortizar:' || p_periodo);
      update prepagados_amortizaciones set vigente = false where asiento_id = v_viejo.id and vigente;
      perform fn_banco_marca(null);
      v_out := v_out || jsonb_build_array(jsonb_build_object('grupo', v_grupo, 'reversado', v_viejo.numero, 'reverso', v_rev->>'numero'));
      v_viejo := null;
    end if;
    if jsonb_array_length(v_filas) = 0 then
      continue;
    end if;
    select jsonb_agg(l order by n, k) into v_lineas
      from (select (row_number() over (order by f->>'prepagado')) as n, 1 as k,
                   jsonb_strip_nulls(jsonb_build_object('cuenta', f->>'cuenta_gasto', 'monto', f->>'monto',
                                                        'proyecto_id', f->>'proyecto_id', 'cost_code', f->>'cost_code',
                                                        'memo', left('Amortización · ' || (f->>'descripcion'), 200))) as l
              from jsonb_array_elements(v_filas) f
            union all
            select (row_number() over (order by f->>'prepagado')), 2,
                   jsonb_strip_nulls(jsonb_build_object('cuenta', f->>'cuenta', 'monto', (-(f->>'monto')::numeric)::text,
                                                        'proyecto_id', case when c.regla_obra <> 'prohibida' then f->>'proyecto_id' end,
                                                        'memo', left('Amortización · ' || (f->>'descripcion'), 200)))
              from jsonb_array_elements(v_filas) f
              join cuentas c on c.codigo = f->>'cuenta') s;
    v_res := fn_banco_asiento('prepagados', v_oid, v_per.hasta,
               format('Amortización de prepagados de %s%s (%s póliza(s))', p_periodo,
                      case when v_grupo = 'mano_de_obra' then ' · prima de WC' else '' end, jsonb_array_length(v_filas)),
               v_lineas,
               jsonb_build_object('funcion', 'fn_prepagados_amortizar', 'periodo', p_periodo, 'grupo', v_grupo, 'firma', v_firma));
    perform fn_banco_marca('amortizar:' || p_periodo);
    insert into prepagados_amortizaciones (prepagado_id, periodo, grupo, monto, acumulado, asiento_id)
    select (f->>'prepagado')::uuid, p_periodo, v_grupo, (f->>'monto')::numeric, (f->>'acumulado')::numeric, (v_res->>'id')::uuid
      from jsonb_array_elements(v_filas) f;
    perform fn_banco_marca(null);
    v_out := v_out || jsonb_build_array(jsonb_build_object('grupo', v_grupo, 'asiento_id', v_res->>'id', 'numero', v_res->>'numero',
                                                           'polizas', jsonb_array_length(v_filas),
                                                           'total', (select sum((f->>'monto')::numeric) from jsonb_array_elements(v_filas) f)));
    for r in select f->>'descripcion' as d, (f->>'monto')::numeric as m, (f->>'del_mes')::numeric as dm
               from jsonb_array_elements(v_filas) f where (f->>'monto')::numeric <> (f->>'del_mes')::numeric loop
      v_avisos := v_avisos || to_jsonb(format('%s: lleva %s y el mes solo son %s (recoge lo que faltó de meses anteriores, o un cambio '
                                              'de la póliza).', r.d, r.m, r.dm));
    end loop;
  end loop;
  return jsonb_strip_nulls(jsonb_build_object('periodo', p_periodo, 'asientos', v_out,
                                              'avisos', case when jsonb_array_length(v_avisos) > 0 then v_avisos end));
end $$;
revoke execute on function public.fn_prepagados_amortizar(text) from public, anon, authenticated, service_role;
grant  execute on function public.fn_prepagados_amortizar(text) to authenticated;
-- =====================================================================
-- 9 · LAS VISTAS (lo que lee conta.js). Todas security_invoker: leen con
-- los permisos de quien las mira, así que el banco solo lo ve el dueño (la
-- policy de sus tablas): el equipo lee 0 filas y anon no las abre.
-- Ninguna llama a una función de este archivo (sin grant a la API: la
-- vista se caería con 42501 al abrirla): casan y suman con SQL llano. Cada
-- cifra lleva su clic: el movimiento (movimiento_id), el asiento
-- (asiento_id, asiento_numero) y el papel (papel_tabla, papel_id).
-- Las que cambian de columnas entre versiones se borran antes de crearlas,
-- SIN cascade: lo ajeno que dependa de ellas ya paró el pegado en la
-- sección 0 (fn_banco_vistas_ajenas), y si algo se colara, el drop falla
-- y no se toca nada (antes «cascade» se lo llevaba callado).
-- =====================================================================
do $$
declare
  v text;
begin
  foreach v in array array['v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion', 'v_conciliacion_partidas',
                           'v_prestamos', 'v_prepagados'] loop
    if to_regclass('public.' || v) is not null then
      execute format('drop view public.%I', v);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 9.1 · v_papel_fases — el papel de los asientos que pone el banco, para
-- v_asiento_papel (c4, 3.5), que lo lee por su llave: el movimiento del
-- banco, la nómina del proveedor anterior, la cuota del préstamo, el mes
-- de prepagados. c4 la crea vacía (sus cuatro columnas, sin filas) y cada
-- fase la rehace con los suyos («create or replace»: v_asiento_papel
-- depende de ella, y así no se borra nada). Mismas columnas siempre, en
-- el mismo orden.
-- ---------------------------------------------------------------------
create or replace view public.v_papel_fases with (security_invoker = true) as
select 'movimientos_banco'::text as origen_tabla,
       m.id::text                as origen_id,
       concat_ws(' · ', 'Movimiento del banco', m.cuenta, m.fecha::text, m.monto::text, nullif(btrim(m.descripcion), ''),
                 'cheque ' || m.cheque, m.estado) as papel,
       null::text                as ruta
  from public.movimientos_banco m
union all
-- (el journal de la nómina del proveedor anterior, fn_banco_nomina: su
-- papel es el débito del banco con que llegó)
select 'nomina_proveedor'::text, m.id::text,
       concat_ws(' · ', 'Nómina del proveedor anterior (su journal, con el débito del banco)', m.cuenta, m.fecha::text,
                 m.monto::text, nullif(btrim(m.descripcion), '')),
       null::text
  from public.movimientos_banco m
union all
select 'prestamo_cuotas'::text, q.id::text,
       concat_ws(' · ', 'Cuota del préstamo de ' || p.prestamista, q.fecha::text, q.monto::text,
                 'capital ' || q.capital || ', interés ' || q.interes || ' (' || q.fuente || ')',
                 case when q.anulada_el is not null then 'anulada: ' || q.anulada_motivo end),
       null::text
  from public.prestamo_cuotas q
  join public.prestamos p on p.id = q.prestamo_id
union all
select 'prepagados'::text, x.origen_id, x.papel, null::text
  from (select a.periodo || case when a.grupo = 'mano_de_obra' then '|mano_de_obra' else '' end as origen_id,
               format('Amortización de prepagados de %s%s', a.periodo,
                      case when a.grupo = 'mano_de_obra' then ' (prima de WC)' else '' end) as papel
          from public.prepagados_amortizaciones a
         group by a.periodo, a.grupo) x;

-- ---------------------------------------------------------------------
-- 9.2 · v_banco_movimientos — cada movimiento del banco como llegó, con su
-- estado (pendiente, casado, en_transito, ignorado), por qué regla y con
-- qué asiento casó, y su papel. «En una conciliación confirmada»: la
-- primera confirmada de su cuenta a su fecha o después (ya no se toca sin
-- reabrirla). lineas: todas las líneas del libro que explica (un ticket
-- repartido entre obras casa con dos).
--   _from('v_banco_movimientos').select('*').eq('cuenta', '1010').eq('periodo', '2026-10')
-- ---------------------------------------------------------------------
create view public.v_banco_movimientos with (security_invoker = true) as
select m.id                         as movimiento_id,
       m.cuenta,
       cu.nombre                    as cuenta_nombre,
       m.ultimos4,
       m.fecha,
       m.fecha_transaccion,
       m.periodo,
       m.monto,
       m.tipo_banco,
       m.cheque,
       m.descripcion,
       m.memo,
       m.origen,
       m.id_externo,
       m.archivo_id,
       ar.nombre                    as archivo,
       m.fila,
       m.estado,
       m.estado_motivo,
       m.propuesta->>'motivo'       as propuesta_motivo,
       m.propuesta->>'texto'        as propuesta_texto,
       m.propuesta,
       m.posible_duplicado_de,
       m.duplicado,
       m.casado_id,
       m.casado_clase,
       m.casado_ref,
       m.casado_regla,
       m.casado_auto,
       m.casado_por,
       m.casado_el,
       m.asiento_id,
       a.numero                     as asiento_numero,
       a.fecha_contable             as asiento_fecha,
       a.origen_tabla               as papel_tabla,
       a.origen_id                  as papel_id,
       (select jsonb_agg(jsonb_build_object('asiento_id', l.asiento_id, 'asiento_numero', la.numero, 'orden', l.orden,
                                            'monto', l.monto, 'papel_tabla', la.origen_tabla, 'papel_id', la.origen_id)
                         order by la.numero, l.orden)
          from public.banco_casado_lineas l
          join public.asientos la on la.id = l.asiento_id
         where l.casado_id = m.casado_id and l.vigente) as lineas,
       (select cc.id from public.conciliaciones cc
         where cc.cuenta = m.cuenta and cc.estado = 'confirmada' and cc.fecha_corte >= m.fecha
         order by cc.fecha_corte limit 1) as conciliacion_id,
       m.importado_el
  from public.movimientos_banco m
  join public.cuentas cu on cu.codigo = m.cuenta
  left join public.archivos_banco ar on ar.id = m.archivo_id
  left join public.asientos a on a.id = m.asiento_id;

-- ---------------------------------------------------------------------
-- 9.3 · v_banco_bandeja — lo que espera a Edgar: cada movimiento pendiente
-- con su motivo (por qué no casó solo), su propuesta en palabras y sus
-- opciones (cada una dice qué función llamar y con qué: la pantalla pinta
-- un botón por opción). dias: desde su fecha; alarma: más de 30 días. Y
-- los cargos ya clasificados cuyo ticket llegó después (motivo
-- «llego_su_ticket»: el gasto está dos veces hasta que Edgar diga).
--   _from('v_banco_bandeja').select('*').order('fecha')
-- ---------------------------------------------------------------------
create view public.v_banco_bandeja with (security_invoker = true) as
select m.id                         as movimiento_id,
       m.cuenta,
       cu.nombre                    as cuenta_nombre,
       m.fecha,
       m.periodo,
       m.monto,
       m.descripcion,
       m.memo,
       m.cheque,
       m.tipo_banco,
       coalesce(case when m.posible_duplicado_de is not null and m.duplicado is null then 'posible_duplicado' end,
                m.propuesta->>'motivo', 'sin_propuesta') as motivo,
       coalesce(m.propuesta->>'texto',
                'Sin propuesta todavía: corre «Casar» (fn_banco_casar_todo) para que el banco lo mire.') as texto,
       m.propuesta->'opciones'      as opciones,
       m.propuesta->'obra'          as obra,
       m.propuesta,
       m.posible_duplicado_de,
       d.fecha                      as duplicado_fecha,
       d.descripcion                as duplicado_descripcion,
       d.origen                     as duplicado_origen,
       public.fn_fecha_miami(now()) - m.fecha as dias,
       public.fn_fecha_miami(now()) - m.fecha > 30 as alarma,
       m.origen,
       m.archivo_id,
       m.importado_el
  from public.movimientos_banco m
  join public.cuentas cu on cu.codigo = m.cuenta
  left join public.movimientos_banco d on d.id = m.posible_duplicado_de
 where m.estado = 'pendiente' or m.propuesta->>'motivo' = 'llego_su_ticket';

-- ---------------------------------------------------------------------
-- 9.4 · v_banco_saldos — una por cuenta propia con estado de cuenta (los
-- bancos 10xx menos la caja chica, y las tarjetas de la tabla tarjetas):
-- el saldo en libros hoy; el último saldo que dijo el banco (el del último
-- archivo que lo trae, LEDGERBAL) y el de libros a esa misma fecha; lo
-- pendiente de casar; y su última conciliación. En el signo del libro (un
-- banco, lo que hay; una tarjeta, lo que se debe en negativo) y como lo
-- dice el estado de cuenta (saldo_*_como_banco: la tarjeta, lo que se
-- debe en positivo). alarma: algo pendiente de más de 30 días, o la última
-- conciliación confirmada tiene más de 45 (un mes y medio sin cuadrar).
-- ---------------------------------------------------------------------
create view public.v_banco_saldos with (security_invoker = true) as
with k as (
  select coalesce((select m.cuenta from public.mapeo_metodo_pago m where m.forma = 'efectivo' and m.cuenta is not null
                    order by m.confirmado_el desc nulls last limit 1), '1050') as caja,
         coalesce((select max(p.hasta) + 1 from public.periodos p where p.tipo = 'apertura'), date '2026-10-01') as corte,
         public.fn_fecha_miami(now()) as hoy),
cu as (
  select c.codigo as cuenta, c.nombre, cx.activa,
         case when left(c.codigo, 2) = '10' and c.tipo = 'activo' then 'banco' else 'tarjeta' end as tipo
    from public.cuentas c
    cross join k
    -- (activa y saldo_normal, leídas de la fila entera y no por su nombre,
    -- como en c4: una vista que nombra una columna le fija el tipo, y las
    -- pruebas 24 y 66 de c2 las reescriben por debajo de sus triggers
    -- para ver que c2 lo delata)
    cross join lateral (select (jsonb_path_query_first(to_jsonb(c), 'strict $.activa') #>> '{}')::boolean as activa,
                               jsonb_path_query_first(to_jsonb(c), 'strict $.saldo_normal') #>> '{}' as saldo_normal) cx
   where c.imputable and c.codigo <> k.caja
     and (   (left(c.codigo, 2) = '10' and c.tipo = 'activo' and cx.saldo_normal = 'debe' and c.regla_obra = 'prohibida')
          or (c.tipo = 'pasivo' and cx.saldo_normal = 'haber' and exists (select 1 from public.tarjetas t where t.cuenta = c.codigo)))
     and (cx.activa or exists (select 1 from public.movimientos_banco m where m.cuenta = c.codigo)))
select cu.cuenta,
       cu.nombre                                                   as cuenta_nombre,
       cu.tipo,
       cu.activa,
       sl.saldo                                                    as saldo_libros,
       case when cu.tipo = 'tarjeta' then -sl.saldo else sl.saldo end as saldo_libros_como_banco,
       ua.id                                                       as ultimo_archivo_id,
       ua.nombre                                                   as ultimo_archivo,
       ua.importado_el                                             as ultimo_importado_el,
       ua.saldo                                                    as saldo_banco,
       case when cu.tipo = 'tarjeta' then -ua.saldo else ua.saldo end as saldo_banco_como_banco,
       ua.saldo_al                                                 as saldo_banco_al,
       case when ua.saldo_al is not null
            then (select coalesce(sum(l.monto), 0) from public.asiento_lineas l join public.asientos a on a.id = l.asiento_id
                   where l.cuenta = cu.cuenta and a.fecha_contable <= ua.saldo_al) end as saldo_libros_al,
       pe.n                                                        as pendientes,
       pe.monto                                                    as pendientes_monto,
       pe.mas_viejo                                                as pendiente_mas_viejo,
       (select count(*) from public.movimientos_banco m where m.cuenta = cu.cuenta and m.estado = 'en_transito') as en_transito,
       uc.id                                                       as ultima_conciliacion_id,
       uc.fecha_corte                                              as ultima_conciliacion,
       uc.estado                                                   as ultima_conciliacion_estado,
       uc.diferencia                                               as ultima_conciliacion_diferencia,
       ucc.fecha_corte                                             as ultima_confirmada,
       k.hoy - coalesce(ucc.fecha_corte, k.corte - 1)              as dias_sin_conciliar,
       (coalesce(k.hoy - pe.mas_viejo > 30, false) or k.hoy - coalesce(ucc.fecha_corte, k.corte - 1) > 45) as alarma,
       concat_ws('; ',
                 case when k.hoy - pe.mas_viejo > 30
                      then format('hay movimientos pendientes desde el %s (más de 30 días)', pe.mas_viejo) end,
                 case when k.hoy - coalesce(ucc.fecha_corte, k.corte - 1) > 45
                      then format('sin conciliación confirmada desde el %s', coalesce(ucc.fecha_corte, k.corte - 1)) end) as alarma_texto
  from cu
  cross join k
  cross join lateral (select coalesce(sum(l.monto), 0)::numeric(14,2) as saldo from public.asiento_lineas l
                       where l.cuenta = cu.cuenta) sl
  left join lateral (select a.* from public.archivos_banco a
                      where a.cuenta = cu.cuenta and a.saldo is not null and a.saldo_al is not null and a.retirado_el is null
                      order by a.saldo_al desc, a.importado_el desc limit 1) ua on true
  cross join lateral (select count(*) as n, coalesce(sum(m.monto), 0) as monto, min(m.fecha) as mas_viejo
                        from public.movimientos_banco m where m.cuenta = cu.cuenta and m.estado = 'pendiente') pe
  left join lateral (select c.* from public.conciliaciones c where c.cuenta = cu.cuenta
                      order by c.fecha_corte desc limit 1) uc on true
  left join lateral (select c.* from public.conciliaciones c where c.cuenta = cu.cuenta and c.estado = 'confirmada'
                      order by c.fecha_corte desc limit 1) ucc on true;

-- ---------------------------------------------------------------------
-- 9.5 · v_conciliacion — una por conciliación: la identidad (libros =
-- banco + en tránsito − solo en el banco) con sus cifras, su estado, quién
-- la confirmó (o reabrió, y por qué) y si ya se puede confirmar.
-- ---------------------------------------------------------------------
create view public.v_conciliacion with (security_invoker = true) as
select c.id                         as conciliacion_id,
       c.cuenta,
       cu.nombre                    as cuenta_nombre,
       c.fecha_corte,
       lpad(extract(year from c.fecha_corte)::int::text, 4, '0') || '-'
         || lpad(extract(month from c.fecha_corte)::int::text, 2, '0') as periodo,
       c.tipo,
       c.estado,
       c.saldo_libros,
       c.saldo_statement,
       c.saldo_archivo,
       c.saldo_banco,
       c.depositos_transito,
       c.cargos_circulacion,
       c.sin_casar_banco,
       c.n_transito,
       c.n_sin_casar,
       c.n_alarmas,
       c.n_dudosas,
       c.n_pide_motivo,
       c.diferencia,
       -- (lo mismo que exige fn_conciliacion_confirmar: también lo que pide
       -- su motivo —el saldo escrito que no es el del archivo, la partida
       -- de la apertura de más de 30 días, el ticket o la transferencia de
       -- más de 10—. Antes la vista no lo miraba: «lista» y «(cuadra)», y
       -- Confirmar fallaba; ronda 4.)
       (c.estado = 'abierta' and c.saldo_banco is not null and c.diferencia = 0 and c.n_sin_casar = 0
        and coalesce(c.n_dudosas, 0) = 0 and coalesce(c.n_pide_motivo, 0) = 0) as lista_para_confirmar,
       format('Libros %s = banco %s + en libros y no en el banco (%s − %s) − en el banco y no en libros (%s) %s',
              c.saldo_libros, coalesce(c.saldo_banco::text, '¿?'), c.depositos_transito, c.cargos_circulacion, c.sin_casar_banco,
              case when c.diferencia is null then '(falta el saldo del statement)'
                   when c.diferencia = 0 and (c.n_sin_casar > 0 or coalesce(c.n_dudosas, 0) > 0) and c.estado = 'abierta'
                   then '(cuadra, pero falta casar lo de abajo)'
                   when c.diferencia = 0 and coalesce(c.n_pide_motivo, 0) > 0 and c.estado = 'abierta'
                   then '(cuadra, pero falta su motivo)'
                   when c.diferencia = 0 then '(cuadra)'
                   else '(diferencia ' || c.diferencia || ')' end) as identidad,
       -- (lo que falta para confirmarla, en palabras: el de su último
       -- cálculo, como lo dijo fn_conciliar)
       case when c.estado = 'abierta' then c.falta end as falta,
       c.archivo_id,
       ar.nombre                    as archivo,
       c.motivo,
       c.calculada_el,
       c.creada_por,
       c.creada_el,
       c.confirmada_por,
       c.confirmada_el,
       c.hash_partidas,
       c.reabierta_por,
       c.reabierta_el,
       c.reabierta_motivo
  from public.conciliaciones c
  join public.cuentas cu on cu.codigo = c.cuenta
  left join public.archivos_banco ar on ar.id = c.archivo_id;

-- ---------------------------------------------------------------------
-- 9.6 · v_conciliacion_partidas — lo de cada conciliación en tres grupos,
-- cada fila con su explicación en palabras y su clic:
--   en_libros_no_en_banco  depósitos en tránsito, cheques y cargos en
--                          circulación, errores (con su motivo; alarma:
--                          más de 30 días);
--   en_banco_no_en_libros  lo que el banco trajo y el libro no tiene a esa
--                          fecha (sin_casar: bloquea la confirmación;
--                          en_libros_despues: el libro lo tiene después
--                          por un mes cerrado, explicado, no bloquea);
--                          (y en el primer grupo, posible_duplicado: el
--                          ticket de un cargo ya clasificado, bloquea);
--   casado                 lo que casó en ese tramo (desde la conciliación
--                          anterior CONFIRMADA de la cuenta, o desde el
--                          corte, hasta esta), con su regla, su asiento y su
--                          papel. Antes el tramo empezaba en la anterior de
--                          cualquier estado: una abierta hecha por error (el
--                          15 por el 31) se llevaba los casados de la
--                          confirmada del mes, que cambiaba sin reabrirse.
--                          Como una conciliación no va detrás de la última
--                          confirmada y se reabren de la última hacia atrás
--                          (fn_conciliar, fn_conciliacion_reabrir), el tramo
--                          de una confirmada no cambia.
-- ---------------------------------------------------------------------
create view public.v_conciliacion_partidas with (security_invoker = true) as
select c.id                         as conciliacion_id,
       c.cuenta,
       c.fecha_corte,
       c.estado                     as conciliacion_estado,
       case p.lado when 'libro' then 'en_libros_no_en_banco' else 'en_banco_no_en_libros' end as grupo,
       p.id                         as partida_id,
       p.clase,
       p.fecha,
       p.monto,
       p.descripcion,
       p.cheque,
       p.dias,
       p.alarma,
       p.motivo,
       p.explicacion,
       p.asiento_id,
       a.numero                     as asiento_numero,
       p.orden,
       a.origen_tabla               as papel_tabla,
       a.origen_id                  as papel_id,
       p.movimiento_id,
       p.apertura_partida_id,
       p.pareja,
       p.resuelta_en,
       p.resuelta_por_movimiento,
       p.resuelta_el
  from public.conciliaciones c
  join public.conciliacion_partidas p on p.conciliacion_id = c.id
  left join public.asientos a on a.id = p.asiento_id
union all
select c.id, c.cuenta, c.fecha_corte, c.estado, 'casado', null::uuid, m.casado_clase, m.fecha, m.monto, m.descripcion, m.cheque,
       null::int, false, null::text,
       format('Casado por %s%s.', coalesce(m.casado_regla, 'su regla'),
              case when m.casado_auto then ' (automático)' else ' (Edgar)' end),
       m.asiento_id, a.numero, null::int, a.origen_tabla, a.origen_id, m.id, null::uuid, null::jsonb, null::uuid, null::uuid,
       null::timestamptz
  from public.conciliaciones c
  join public.movimientos_banco m
    on m.cuenta = c.cuenta and m.estado in ('casado', 'en_transito') and m.fecha <= c.fecha_corte
   and m.fecha > coalesce((select max(c2.fecha_corte) from public.conciliaciones c2
                            where c2.cuenta = c.cuenta and c2.fecha_corte < c.fecha_corte and c2.estado = 'confirmada'),
                          (select max(pa.hasta) from public.periodos pa where pa.tipo = 'apertura'),
                          date '2026-09-30')
  left join public.asientos a on a.id = m.asiento_id
 where c.tipo = 'normal';

-- ---------------------------------------------------------------------
-- 9.7 · v_prestamos — uno por préstamo: lo pagado (capital e interés), lo
-- que se debe, la porción corriente (el capital de las próximas 12 cuotas
-- por la fórmula: lo que va en 2520; el resto, a largo plazo en 2530, lo
-- reclasifica el cierre, f08) y cada cuota con su asiento.
-- ---------------------------------------------------------------------
create view public.v_prestamos with (security_invoker = true) as
select p.id                         as prestamo_id,
       p.prestamista,
       p.descripcion,
       p.estado,
       p.principal,
       p.tasa_anual,
       p.cuota,
       p.primer_pago,
       p.dia_pago,
       p.plazo_meses,
       p.cuenta,
       p.cuenta_largo,
       p.cuenta_interes,
       p.cuenta_banco,
       p.saldo_inicial,
       p.saldo_inicial_al,
       coalesce(q.capital, 0)       as capital_pagado,
       coalesce(q.interes, 0)       as interes_pagado,
       coalesce(q.n, 0)             as cuotas,
       (p.saldo_inicial - coalesce(q.capital, 0))::numeric(14,2) as saldo,
       least(f.corriente, p.saldo_inicial - coalesce(q.capital, 0))::numeric(14,2) as porcion_corriente,
       (p.saldo_inicial - coalesce(q.capital, 0) - least(f.corriente, p.saldo_inicial - coalesce(q.capital, 0)))::numeric(14,2)
                                    as porcion_largo_plazo,
       q.ultima_fecha,
       q.ultimo_asiento_id,
       q.ultimo_asiento_numero,
       q.detalle                    as cuotas_detalle,
       p.descriptor,
       p.notas
  from public.prestamos p
  left join lateral (
    select count(*) as n, sum(x.capital) as capital, sum(x.interes) as interes, max(x.fecha) as ultima_fecha,
           (array_agg(x.asiento_id order by x.fecha desc, x.creado_el desc))[1] as ultimo_asiento_id,
           (array_agg(a.numero order by x.fecha desc, x.creado_el desc))[1] as ultimo_asiento_numero,
           jsonb_agg(jsonb_build_object('cuota_id', x.id, 'fecha', x.fecha, 'monto', x.monto, 'capital', x.capital,
                                        'interes', x.interes, 'fuente', x.fuente, 'saldo_despues', x.saldo_despues,
                                        'asiento_id', x.asiento_id, 'asiento_numero', a.numero,
                                        'movimiento_id', x.movimiento_id) order by x.fecha, x.creado_el) as detalle
      from public.prestamo_cuotas x
      left join public.asientos a on a.id = x.asiento_id
     where x.prestamo_id = p.id and x.anulada_el is null) q on true
  left join lateral (
    -- el capital de las próximas 12 cuotas, mes a mes (interés sobre el
    -- saldo que queda, como la fórmula)
    with recursive s(n, saldo, cap) as (
      select 0, (p.saldo_inicial - coalesce(q.capital, 0))::numeric, 0::numeric
      union all
      select s.n + 1,
             s.saldo - least(s.saldo, greatest(p.cuota - round(s.saldo * p.tasa_anual / 100 / 12, 2), 0)),
             least(s.saldo, greatest(p.cuota - round(s.saldo * p.tasa_anual / 100 / 12, 2), 0))
        from s where s.n < 12 and s.saldo > 0)
    select coalesce(sum(s.cap), 0) as corriente from s) f on true;

-- ---------------------------------------------------------------------
-- 9.8 · v_prepagados — una por póliza: lo que amortizó QuickBooks antes
-- del corte (qb = monto − saldo_corte, el saldo que dejó su balanza), lo
-- que lleva el libro, lo que falta (por_amortizar, lo que debe estar en
-- 1410/1420), lo que ya debía llevar al cierre del mes pasado
-- (debe_llevar) y si va atrasada; y cada mes con su asiento.
-- falta_saldo_corte: la póliza empezó antes del corte y no dice lo que
-- dejó QuickBooks (se calcula por días mientras tanto, y el control lo
-- dice en rojo). Una SUSTITUIDA (sustituida_por) debe llevar cero: si
-- lleva algo, por_amortizar sale negativo hasta que el mes abierto lo
-- devuelve. Una CANCELADA con su fecha (cancelado_al, devuelto): todo lo
-- que queda menos lo devuelto, al gasto el mes de la cancelación.
-- ---------------------------------------------------------------------
create view public.v_prepagados with (security_invoker = true) as
with k as (select coalesce((select max(p.hasta) + 1 from public.periodos p where p.tipo = 'apertura'), date '2026-10-01') as corte,
                  (date_trunc('month', public.fn_fecha_miami(now())::timestamp)::date - 1) as fin_mes_pasado)
select pp.id                        as prepagado_id,
       pp.descripcion,
       pp.tipo,
       pp.estado,
       pp.cuenta,
       pp.cuenta_gasto,
       pp.proyecto_id,
       pp.cost_code,
       pp.monto,
       pp.desde,
       pp.hasta,
       (pp.hasta - pp.desde + 1)    as dias,
       x.qb,
       pp.saldo_corte,
       (pp.desde < k.corte and pp.saldo_corte is null) as falta_saldo_corte,
       coalesce(am.total, 0)        as amortizado,
       case when x.mira then x.meta - coalesce(am.total, 0) else 0 end::numeric(14,2) as por_amortizar,
       x.debe_llevar,
       case when x.mira then greatest(x.debe_llevar - coalesce(am.total, 0), 0) else 0 end::numeric(14,2) as atrasado,
       pp.sustituida_por,
       pp.cancelado_al,
       pp.devuelto,
       am.ultimo_periodo,
       am.ultimo_asiento_id,
       am.ultimo_asiento_numero,
       am.detalle                   as amortizaciones,
       pp.papel_tabla,
       pp.papel_id,
       pp.notas
  from public.prepagados pp
  cross join k
  cross join lateral (
    select q.base, (pp.monto - q.base)::numeric(14,2) as qb,
           -- (lo que el libro debe llevar al final: la sustituida, nada; la
           -- cancelada, todo menos lo devuelto; la vigente, todo)
           q.meta, q.mira,
           (case when not q.mira then 0
                 when pp.sustituida_por is not null then 0
                 when pp.cancelado_al is not null and k.fin_mes_pasado >= pp.cancelado_al then q.meta
                 else least(case when k.fin_mes_pasado < q.ini or q.base = 0 then 0
                                 when k.fin_mes_pasado >= pp.hasta then q.base
                                 else round(q.base * (k.fin_mes_pasado - q.ini + 1) / (pp.hasta - q.ini + 1), 2) end,
                            q.meta) end)::numeric(14,2)
             as debe_llevar
      from (select q0.*,
                   (case when pp.sustituida_por is not null then 0
                         when pp.cancelado_al is not null then q0.base - coalesce(pp.devuelto, 0)
                         else q0.base end)::numeric(14,2) as meta,
                   (pp.estado = 'vigente' or pp.sustituida_por is not null or pp.cancelado_al is not null) as mira
              from (select (case when pp.desde < k.corte
                                 then coalesce(pp.saldo_corte,
                                               pp.monto - round(pp.monto * (least(k.corte - 1, pp.hasta) - pp.desde + 1)
                                                                / (pp.hasta - pp.desde + 1), 2))
                                 else pp.monto end)::numeric(14,2) as base,
                           greatest(pp.desde, k.corte) as ini) q0) q) x
  left join lateral (
    select sum(a.monto) as total, max(a.periodo) as ultimo_periodo,
           (array_agg(a.asiento_id order by a.periodo desc))[1] as ultimo_asiento_id,
           (array_agg(s.numero order by a.periodo desc))[1] as ultimo_asiento_numero,
           jsonb_agg(jsonb_build_object('periodo', a.periodo, 'monto', a.monto, 'acumulado', a.acumulado,
                                        'asiento_id', a.asiento_id, 'asiento_numero', s.numero) order by a.periodo) as detalle
      from public.prepagados_amortizaciones a
      join public.asientos s on s.id = a.asiento_id
     where a.prepagado_id = pp.id and a.vigente) am on true;

-- Los permisos de las vistas: en Supabase una vista nueva nace con todos
-- para anon, authenticated y service_role. Se quitan todos (también los
-- de columna) y se da SELECT solo a authenticated (el dueño ve; el equipo,
-- 0 filas por la policy de las tablas).
do $$
declare
  v      text;
  v_cols text;
begin
  foreach v in array array['v_papel_fases', 'v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion',
                           'v_conciliacion_partidas', 'v_prestamos', 'v_prepagados'] loop
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', v);
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
-- =====================================================================
-- 10 · LAS HUELLAS DEL BANCO (las mira «protecciones del banco», en 11).
-- Como las de c2 y c4: al final de cada pegado se sellan, como valores
-- literales, el md5 de la definición de cada función de este archivo
-- (fn_banco_…, fn_conciliar, fn_conciliacion_…, fn_prestamo_…,
-- fn_prepagado…), de cada trigger, regla y policy de sus tablas y de cada
-- vista. Una guarda vaciada con «create or replace», un trigger rehecho,
-- una policy cambiada o una vista reescrita salen en rojo con su nombre.
-- Solo frena accidentes: quien es dueño de la base puede rehacerlas
-- (basta con volver a pegar este archivo).
-- =====================================================================
create or replace function public.fn_banco_huellas_calcular()
returns table (tipo text, objeto text, md5 text)
language sql
stable
set search_path = public, pg_temp
as $$
  select 'funcion'::text, p.oid::regprocedure::text, md5(pg_get_functiondef(p.oid))
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'
     and (p.proname like 'fn\_banco\_%' or p.proname like 'fn\_conciliacion\_%' or p.proname = 'fn_conciliar'
          or p.proname like 'fn\_prestamo\_%' or p.proname like 'fn\_prepagado%')
     and p.proname <> 'fn_banco_huellas'
  union all
  select 'trigger'::text, c.relname || '.' || t.tgname, md5(pg_get_triggerdef(t.oid))
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
   where c.relnamespace = 'public'::regnamespace and not t.tgisinternal
     and c.relname in ('banco_historial', 'banco_descriptores', 'archivos_banco', 'movimientos_banco', 'movimientos_banco_ids',
                       'banco_casados', 'banco_casado_lineas', 'conciliaciones', 'conciliacion_partidas', 'prestamos',
                       'prestamo_cuotas', 'prepagados', 'prepagados_amortizaciones')
  union all
  select 'regla'::text, c.relname || '.' || r.rulename, md5(pg_get_ruledef(r.oid))
    from pg_rewrite r
    join pg_class c on c.oid = r.ev_class
   where c.relnamespace = 'public'::regnamespace and r.rulename <> '_RETURN'
     and c.relname in ('banco_historial', 'banco_descriptores', 'archivos_banco', 'movimientos_banco', 'movimientos_banco_ids',
                       'banco_casados', 'banco_casado_lineas', 'conciliaciones', 'conciliacion_partidas', 'prestamos',
                       'prestamo_cuotas', 'prepagados', 'prepagados_amortizaciones')
  union all
  select 'policy'::text, c.relname || '.' || po.polname,
         md5(concat_ws('|', po.polcmd, po.polpermissive, array_to_string(array(select r.rolname from pg_roles r
                                                                                   where r.oid = any (po.polroles) order by 1), ','),
                       pg_get_expr(po.polqual, po.polrelid), pg_get_expr(po.polwithcheck, po.polrelid)))
    from pg_policy po
    join pg_class c on c.oid = po.polrelid
   where c.relnamespace = 'public'::regnamespace
     and c.relname in ('banco_historial', 'banco_descriptores', 'archivos_banco', 'movimientos_banco', 'movimientos_banco_ids',
                       'banco_casados', 'banco_casado_lineas', 'conciliaciones', 'conciliacion_partidas', 'prestamos',
                       'prestamo_cuotas', 'prepagados', 'prepagados_amortizaciones')
  union all
  -- (cada vista por su árbol guardado, la regla _RETURN de pg_rewrite, y
  -- sus opciones: cualquier cambio de su definición lo cambia, sin
  -- reconstruir su texto. Con pg_get_viewdef las huellas de las ocho
  -- tardaban 16 ms en CADA llamada al control, que las recalcula)
  select 'vista'::text, c.relname, md5(r.ev_action::text || coalesce(array_to_string(c.reloptions, ','), ''))
    from pg_class c
    join pg_rewrite r on r.ev_class = c.oid and r.rulename = '_RETURN'
   where c.relnamespace = 'public'::regnamespace and c.relkind = 'v'
     and c.relname in ('v_papel_fases', 'v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion',
                       'v_conciliacion_partidas', 'v_prestamos', 'v_prepagados')
$$;
revoke execute on function public.fn_banco_huellas_calcular() from public, anon, authenticated, service_role;

-- El sello: reescribe fn_banco_huellas() con las huellas de este momento.
-- Lo llama el final de este archivo. Sin grant a nadie de la API.
create or replace function public.fn_banco_huellas_sellar()
returns int
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_filas text;
  v_n     int;
begin
  perform fn_banco_exigir_dueno();
  select string_agg(format('(%L, %L, %L)', h.tipo, h.objeto, h.md5), E',\n    ' order by h.tipo, h.objeto), count(*)
    into v_filas, v_n
    from public.fn_banco_huellas_calcular() h;
  execute format($f$
    create or replace function public.fn_banco_huellas()
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
  execute 'revoke execute on function public.fn_banco_huellas() from public, anon, authenticated, service_role';
  execute format('comment on function public.fn_banco_huellas() is %L',
                 'c6: las huellas (md5) de las funciones, triggers, reglas, policies y vistas de c6-banco.sql, selladas por su '
                 'último pegado, el ' || to_char(now() at time zone 'America/New_York', 'YYYY-MM-DD HH24:MI') || ' (Miami).');
  return v_n;
end $$;
revoke execute on function public.fn_banco_huellas_sellar() from public, anon, authenticated, service_role;


-- =====================================================================
-- 11 · fn_banco_control(periodo [, vistas]) — lo que conta.js lee ANTES
-- de pintar una pantalla del banco (la falla ruidosa de f05), con el
-- contrato de fn_estados_control (c4): una fila por vista pedida, con
-- cuántas filas devolvió para ese período (filas) y cuántas dicen las
-- tablas del banco que debía devolver (esperadas), contadas aparte, sin
-- pasar por la vista. ok = false si la vista falló (no existe, se rompió,
-- le quitaron un permiso: el detalle trae el error) o si devolvió otra
-- cantidad («esperaba N»): la pantalla no dibuja, dice cuál falló. Y una
-- fila por cuadre (vista = 'cuadre: …'):
--   un movimiento, un casado   cada casado vivo es el de su movimiento,
--                              sus líneas suman el movimiento al centavo
--                              y son de su cuenta, y ninguna es de un
--                              asiento reversado (por su reverso o por el
--                              automático de un devengo) sin poner al día;
--                              dentro de una conciliación confirmada, dice
--                              cuál reabrir (con v_banco_movimientos o
--                              v_banco_bandeja)
--   depósitos nunca a ingreso  ningún asiento del banco lleva un depósito
--                              a una cuenta de ingreso, ni a otros
--                              ingresos sin su motivo escrito (salvo los
--                              intereses del banco a su cuenta) (ídem)
--   archivos intactos          cada archivo es el que entró (su sha256) y
--                              tiene sus movimientos, cada movimiento del
--                              período da su sello, y ningún asiento del
--                              banco del período (un movimiento, una
--                              nómina, una cuota, un mes de prepagados) se
--                              quedó sin su papel (el estado de cuenta
--                              borrado entero con las guardas apagadas)
--                              (ídem)
--   ningún ticket después de clasificar  ningún cargo clasificado tiene
--                              libre en su cuenta el ticket que llegó
--                              después (el gasto dos veces) (ídem)
--   conciliaciones confirmadas cada una sigue diciendo lo que se confirmó:
--                              su huella, su saldo en libros (algo
--                              posteado después con fecha anterior al
--                              corte la cambia), su identidad en cero, y
--                              nada de su tramo pendiente, ignorado o
--                              casado después de confirmarla; y ninguna
--                              con un saldo escrito distinto del que trae
--                              el archivo ese día, ni con una partida de
--                              la apertura que no llegó, sin su motivo
--                              (con v_conciliacion o v_conciliacion_partidas)
--   préstamos                  lo que dice el libro en sus cuentas = la
--                              suma de sus saldos; cada cuota viva con su
--                              asiento vivo; ninguna cuenta de préstamo
--                              con saldo deudor (con v_prestamos)
--   prepagados                 lo que dice el libro en 1410/1420 = lo que
--                              falta por amortizar; cada mes con su
--                              asiento vivo (con v_prepagados)
-- y SIEMPRE dos más: 'cuadre: protecciones del banco' (sus triggers
-- encendidos y con su función, la RLS y la policy de cada tabla, los
-- permisos de tablas, vistas y funciones, sus huellas, y ninguna función
-- ajena SECURITY DEFINER que lea sus tablas y la API ejecute, o que
-- dispare un trigger de una tabla donde la API escribe) y 'cuadre: c2, c3
-- y c4 al día'.
--   p_periodo: un mes ('2026-10'), la apertura, un año, o 'hoy' (del
--   primero del mes a hoy, en Miami). p_vistas: las de la pantalla (nulo =
--   todas). Un nombre que no conoce, un nulo o una lista vacía: una fila en
--   false (no se pinta). conta.js:
--   _rpc('fn_banco_control', { p_periodo: '2026-10', p_vistas: ['v_banco_movimientos', 'v_banco_bandeja'] })
-- Corre con los permisos de quien llama (no es SECURITY DEFINER), no llama
-- a ninguna función de este archivo (el dueño desde la app no las
-- ejecuta) y va con jit = off, como el de c4. El equipo no la ejecuta.
-- =====================================================================
create or replace function public.fn_banco_control(p_periodo text, p_vistas text[] default null)
returns table (orden int, vista text, filas bigint, esperadas bigint, ok boolean, detalle text)
language plpgsql
set search_path = public, pg_temp
set jit = off
as $$
declare
  -- (un cuadre también se puede pedir solo, por su nombre: se calcula ese,
  -- con las protecciones, y no los de su grupo ni las filas de sus vistas.
  -- Lo usan las pruebas, que miran un cuadre por vez: con un año de banco,
  -- el grupo de v_banco_movimientos tarda 0,2 s y un cuadre suelto mucho
  -- menos)
  v_cuadres text[] := array['cuadre: un movimiento, un casado', 'cuadre: depósitos nunca a ingreso', 'cuadre: archivos intactos',
                            'cuadre: ningún ticket después de clasificar', 'cuadre: conciliaciones confirmadas',
                            'cuadre: préstamos', 'cuadre: prepagados'];
  v_solos   text[] := '{}';
  v_conoce  text[] := array['v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion',
                            'v_conciliacion_partidas', 'v_prestamos', 'v_prepagados'];
  v_tablas  text[] := array['banco_historial', 'banco_descriptores', 'archivos_banco', 'movimientos_banco', 'movimientos_banco_ids',
                            'banco_casados', 'banco_casado_lineas', 'conciliaciones', 'conciliacion_partidas', 'prestamos',
                            'prestamo_cuotas', 'prepagados', 'prepagados_amortizaciones'];
  v_vistas  text[] := array['v_papel_fases', 'v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion',
                            'v_conciliacion_partidas', 'v_prestamos', 'v_prepagados'];
  -- lo que conta.js llama (el resto, sin grant a la API)
  v_app     text[] := array['fn_banco_importar_ofx(text,text,text)', 'fn_banco_importar_filas(jsonb)', 'fn_banco_casar(uuid)',
                            'fn_banco_casar_todo(text,date)', 'fn_banco_casar_con(uuid,jsonb,text)',
                            'fn_banco_cobrar(uuid,jsonb,text)', 'fn_banco_pagar_proveedor(uuid,uuid,jsonb)',
                            'fn_banco_transferencia(uuid,text,text)', 'fn_banco_clasificar(uuid,jsonb,text)',
                            'fn_banco_ignorar(uuid,text)', 'fn_banco_duplicado(uuid,boolean,text)',
                            'fn_banco_devolver(uuid,uuid,text)', 'fn_banco_descasar(uuid,text)', 'fn_conciliar(text,date,text)',
                            'fn_conciliacion_partida(uuid,text,text)', 'fn_conciliacion_confirmar(uuid)',
                            'fn_conciliacion_reabrir(uuid,text)', 'fn_conciliacion_apertura(text,text,jsonb,text)',
                            'fn_prestamo_cuota(uuid,uuid,date,text,text,text,text)', 'fn_prepagados_amortizar(text)',
                            'fn_banco_control(text,text[])'];
  v_hoy     boolean := p_periodo = 'hoy';
  v_pp      periodos;
  v_pid     text;
  v_desde   date;
  v_hasta   date;
  v_corte   date;
  v_pedidas text[];
  v_x       text;
  i         int;
  v_n       bigint;
  v_e       bigint;
  v_err     text;
  v_malos   text[];
  v_prot    text[] := '{}';
  v_hsel    text;
  v_hcal    text;
  v_hue     text[];
  v_simples text;
  v_compues text;
  v_a       numeric;
  v_b       numeric;
  v_cnt     bigint;
  v_c2sel   text;
  v_c2ok    oid[] := '{}';
  v_c4sel   text;
  v_c4ok    oid[] := '{}';
  v_rel     oid[];
  v_fn_c6   oid[];
  v_lee     oid[];
  v_nuevas  oid[];
  v_fnn     text;
  v_rx_c    text;
  v_rx_k    text;
  v_rx_s    text;
  v_rx_f    text;
  v_rx_pre  text;
  v_vuelta  int;
  v_ajeno   text[] := '{}';
begin
  -- (Solo es_dueno(), como el de c4: desde el SQL Editor el usuario no es
  -- authenticated.)
  if current_user in ('authenticated', 'anon') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501', message = 'El banco lo ve solo Edgar (el dueño).';
  end if;
  v_corte := coalesce((select max(p.hasta) + 1 from periodos p where p.tipo = 'apertura'), date '2026-10-01');
  if v_hoy then
    v_hasta := fn_fecha_miami(now());
    v_desde := date_trunc('month', v_hasta::timestamp)::date;
    v_pid := 'hoy';
  else
    select * into v_pp from periodos pp where pp.periodo = p_periodo;
    if not found then
      raise exception using errcode = '22023',
        message = format('No existe el período %s (un mes como ''2026-10'', la apertura, un año, o ''hoy'').', coalesce(p_periodo, '(nulo)'));
    end if;
    v_desde := v_pp.desde; v_hasta := v_pp.hasta; v_pid := v_pp.periodo;
  end if;

  -- 0. Lo que se pide: lo que no conoce, un nulo o una lista vacía, una
  -- fila en false cada uno (nunca un silencio que se lea como «todo bien»).
  if p_vistas is not null and cardinality(p_vistas) = 0 then
    orden := 0; vista := '(ninguna)'; filas := null; esperadas := null; ok := false;
    detalle := 'p_vistas llegó vacía: no se controla nada, y así no se pinta. Pide las vistas de la pantalla, o nulo para todas.';
    return next;
  end if;
  for v_x in select distinct x.v from unnest(coalesce(p_vistas, '{}'::text[])) as x(v)
              where x.v is null or not (x.v = any (v_conoce) or x.v = any (v_cuadres)) loop
    orden := 0; vista := coalesce(v_x, '(nula)'); filas := null; esperadas := null; ok := false;
    detalle := format('La vista «%s» no la conoce el control del banco (¿un error de dedo?): no se pinta. Las que conoce: %s '
                      '(y cada cuadre, por su nombre).',
                      coalesce(v_x, 'nula'), array_to_string(v_conoce, ', '));
    return next;
  end loop;
  v_pedidas := case when p_vistas is null then v_conoce
                    else array(select distinct x.v from unnest(p_vistas) as x(v) where x.v = any (v_conoce)) end;
  v_solos := case when p_vistas is null then '{}'::text[]
                  else array(select distinct x.v from unnest(p_vistas) as x(v) where x.v = any (v_cuadres)) end;

  -- 1. Cada vista pedida: lo que devuelve (como la lee la app) contra lo
  -- que dicen las tablas.
  for i in 1 .. cardinality(v_conoce) loop
    v_x := v_conoce[i];
    continue when not (v_x = any (v_pedidas));
    v_err := null; v_n := null;
    begin
      execute case v_x
                when 'v_banco_movimientos' then 'select count(*) from public.v_banco_movimientos where fecha between $1 and $2'
                when 'v_banco_bandeja' then 'select count(*) from public.v_banco_bandeja where fecha <= $2'
                when 'v_banco_saldos' then 'select count(*) from public.v_banco_saldos'
                when 'v_conciliacion' then 'select count(*) from public.v_conciliacion where fecha_corte between $1 and $2'
                when 'v_conciliacion_partidas' then 'select count(*) from public.v_conciliacion_partidas where fecha_corte between $1 and $2'
                when 'v_prestamos' then 'select count(*) from public.v_prestamos'
                when 'v_prepagados' then 'select count(*) from public.v_prepagados' end
        into v_n using v_desde, v_hasta;
    exception when others then
      v_err := sqlerrm;
    end;
    v_e := case v_x
      when 'v_banco_movimientos' then (select count(*) from movimientos_banco m where m.fecha between v_desde and v_hasta)
      when 'v_banco_bandeja' then (select count(*) from movimientos_banco m
                                    where (m.estado = 'pendiente' or m.propuesta->>'motivo' = 'llego_su_ticket') and m.fecha <= v_hasta)
      when 'v_banco_saldos' then
        (select count(*) from cuentas c
          where c.imputable
            and c.codigo <> coalesce((select mp.cuenta from mapeo_metodo_pago mp where mp.forma = 'efectivo' and mp.cuenta is not null
                                       order by mp.confirmado_el desc nulls last limit 1), '1050')
            and (   (left(c.codigo, 2) = '10' and c.tipo = 'activo' and c.saldo_normal = 'debe' and c.regla_obra = 'prohibida')
                 or (c.tipo = 'pasivo' and c.saldo_normal = 'haber' and exists (select 1 from tarjetas t where t.cuenta = c.codigo)))
            and (c.activa or exists (select 1 from movimientos_banco m where m.cuenta = c.codigo)))
      when 'v_conciliacion' then (select count(*) from conciliaciones c where c.fecha_corte between v_desde and v_hasta)
      when 'v_conciliacion_partidas' then
        (select count(*) from conciliacion_partidas p join conciliaciones c on c.id = p.conciliacion_id
          where c.fecha_corte between v_desde and v_hasta)
        + (select count(*) from conciliaciones c
             join movimientos_banco m
               on m.cuenta = c.cuenta and m.estado in ('casado', 'en_transito') and m.fecha <= c.fecha_corte
              and m.fecha > coalesce((select max(c2.fecha_corte) from conciliaciones c2
                                       where c2.cuenta = c.cuenta and c2.fecha_corte < c.fecha_corte and c2.estado = 'confirmada'),
                                     v_corte - 1)
            where c.tipo = 'normal' and c.fecha_corte between v_desde and v_hasta)
      when 'v_prestamos' then (select count(*) from prestamos)
      when 'v_prepagados' then (select count(*) from prepagados) end;
    orden := i; vista := v_x; filas := v_n; esperadas := v_e;
    ok := v_err is null and v_n = v_e;
    detalle := case when v_err is not null then format('La vista %s falló (%s): no se pinta.', v_x, v_err)
                    when v_n <> v_e then format('La vista %s devolvió %s filas para %s y las tablas del banco dicen %s: esperaba %s. '
                                                'No se pinta.', v_x, v_n, v_pid, v_e, v_e) end;
    return next;
  end loop;

  -- 2. Los cuadres de lo pedido (su grupo de vistas, o el cuadre solo).
  if v_pedidas && array['v_banco_movimientos', 'v_banco_bandeja'] or 'cuadre: un movimiento, un casado' = any (v_solos) then
    -- un movimiento, un casado
    select coalesce(array_agg(s.x), '{}') into v_malos
      from (select format('el movimiento %s (%s %s %s) está %s sin su casado vivo', m.id, m.cuenta, m.fecha, m.monto, m.estado) as x
              from movimientos_banco m
             where m.estado in ('casado', 'en_transito')
               and not exists (select 1 from banco_casados c where c.id = m.casado_id and c.movimiento_id = m.id and c.deshecho_el is null)
            union all
            select format('el casado %s está vivo y su movimiento %s no lo nombra', c.id, c.movimiento_id)
              from banco_casados c join movimientos_banco m on m.id = c.movimiento_id
             where c.deshecho_el is null and m.casado_id is distinct from c.id
            union all
            -- (las sumas de todos los casados de una pasada, no una consulta
            -- por casado: con un año de banco, este cuadre tardaba 0,15 s)
            select format('el movimiento %s (%s %s) casa con líneas que suman %s%s', m.id, m.fecha, m.monto, coalesce(s.suma, 0),
                          case when s.c1 is distinct from m.cuenta or s.c2 is distinct from m.cuenta
                               then ' y no son todas de su cuenta' else '' end)
              from movimientos_banco m
              join banco_casados c on c.id = m.casado_id and c.deshecho_el is null and c.clase <> 'apertura'
              left join (select l.casado_id, sum(al.monto) as suma, min(al.cuenta) as c1, max(al.cuenta) as c2
                           from banco_casado_lineas l
                           join asiento_lineas al on al.asiento_id = l.asiento_id and al.orden = l.orden
                          where l.vigente
                          group by l.casado_id) s on s.casado_id = c.id
             where coalesce(s.suma, 0) <> m.monto or s.c1 is distinct from m.cuenta or s.c2 is distinct from m.cuenta
            union all
            select case when cc.id is not null
                        then format('el movimiento %s (%s %s) casa con el asiento %s, que se reversó, dentro de la conciliación '
                                    'confirmada de %s al %s: reábrela (fn_conciliacion_reabrir, con su motivo) y casa otra vez '
                                    '(fn_banco_casar_todo)', m.id, m.fecha, m.monto, a.numero, cc.cuenta, cc.fecha_corte)
                        when a.reversible
                        then format('el movimiento %s (%s %s) casa con el asiento %s, un devengo que el libro reversa solo el día 1 '
                                    '(reversible): no lo explica. Corre «Casar» (fn_banco_casar_todo), que lo devuelve a la bandeja',
                                    m.id, m.fecha, m.monto, a.numero)
                        else format('el movimiento %s (%s %s) casa con el asiento %s, que se reversó: corre «Casar» '
                                    '(fn_banco_casar_todo), que lo pone con el asiento que lo sustituye o lo devuelve a la bandeja',
                                    m.id, m.fecha, m.monto, a.numero) end
              -- (primero los asientos reversados o reversibles, que son pocos,
              -- y después sus líneas casadas: no cada línea casada del año)
              from (select a0.id, a0.numero, a0.reversible from asientos a0
                     where a0.reversible
                        or a0.id in (select r.reversa_a from asientos r
                                      where r.reversa_a is not null and r.camino in ('reverso', 'reverso_automatico'))) a
              join banco_casado_lineas l on l.asiento_id = a.id and l.vigente
              join banco_casados c on c.id = l.casado_id and c.deshecho_el is null
              join movimientos_banco m on m.id = c.movimiento_id
              left join lateral (select x.id, x.cuenta, x.fecha_corte from conciliaciones x
                                  where x.cuenta = m.cuenta and x.estado = 'confirmada' and x.fecha_corte >= m.fecha
                                  order by x.fecha_corte limit 1) cc on true
            limit 20) s;
    orden := 51; vista := 'cuadre: un movimiento, un casado'; filas := null; esperadas := null;
    ok := cardinality(v_malos) = 0;
    detalle := case when not ok then array_to_string(v_malos, '; ') end;
    return next;
  end if;

  if v_pedidas && array['v_banco_movimientos', 'v_banco_bandeja'] or 'cuadre: depósitos nunca a ingreso' = any (v_solos) then
    -- depósitos nunca a ingreso (ni a otros ingresos sin su motivo: los
    -- intereses del banco, a su cuenta, cuando el banco dice que lo son);
    -- ni, sin su motivo, a otra cuenta cuando la bandeja proponía su COBRO
    -- (una factura que lo explica, entera o una parte: antes el pago
    -- parcial de un cliente se clasificaba contra el costo de su obra, la
    -- factura seguía entera por cobrar y este cuadre, en verde)
    select coalesce(array_agg(s.x), '{}') into v_malos
      from (select case when c.tipo in ('ingreso', 'otro_ingreso')
                        then format('el asiento %s (movimiento %s, un depósito de %s) lleva %s a %s, una cuenta de %s%s', a.numero,
                                    m.id, m.monto, l.monto, l.cuenta,
                                    case when c.tipo = 'ingreso' then 'ingreso' else 'otros ingresos' end,
                                    case when c.tipo = 'otro_ingreso' then ' sin su motivo escrito' else '' end)
                        else format('el asiento %s (movimiento %s, un depósito de %s) lleva %s a %s (%s) sin su motivo escrito, '
                                    'cuando la bandeja proponía su cobro (%s): la factura sigue por cobrar y el dinero del cliente '
                                    'entra dos veces. Des-cásalo y regístralo con su factura (fn_banco_cobrar)', a.numero, m.id, m.monto,
                                    l.monto, l.cuenta, c.nombre, a.procedencia->>'propuesta') end as x
              from asientos a
              join movimientos_banco m on a.origen_tabla = 'movimientos_banco' and m.id::text = a.origen_id
              join asiento_lineas l on l.asiento_id = a.id
              join cuentas c on c.codigo = l.cuenta
             where m.monto > 0 and a.camino not in ('reverso', 'reverso_automatico')
               and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino in ('reverso', 'reverso_automatico'))
               and (c.tipo = 'ingreso'
                    or (c.tipo = 'otro_ingreso' and coalesce(btrim(a.procedencia->>'motivo_edgar'), '') = ''
                        and not (l.cuenta = coalesce((select d.cuenta from banco_descriptores d where d.clave = 'interes'), '4910')
                                 and (m.tipo_banco = 'INT'
                                      or coalesce(m.desc_norm ~* (select d.patron from banco_descriptores d where d.clave = 'interes'),
                                                  false))))
                    or (a.procedencia->>'propuesta' in ('deposito_cobro', 'deposito_cobros', 'deposito_otro_cobro', 'deposito_sin_cobro',
                                                        'deposito_parcial')
                        and a.procedencia->>'funcion' = 'fn_banco_clasificar'
                        and coalesce(btrim(a.procedencia->>'motivo_edgar'), '') = '' and l.cuenta <> m.cuenta))
            limit 20) s;
    orden := 52; vista := 'cuadre: depósitos nunca a ingreso'; filas := null; esperadas := null;
    ok := cardinality(v_malos) = 0;
    detalle := case when not ok then array_to_string(v_malos, '; ') || '. El ingreso lo pone la factura; el depósito es su cobro.' end;
    return next;
  end if;

  if v_pedidas && array['v_banco_movimientos', 'v_banco_bandeja'] or 'cuadre: archivos intactos' = any (v_solos) then
    -- archivos intactos
    select coalesce(array_agg(s.x), '{}') into v_malos
      from (select format('el archivo %s de %s (%s) %s', coalesce(a.nombre, a.id::text), a.cuenta, a.importado_el::date,
                          case when encode(sha256(convert_to(a.texto, 'UTF8')), 'hex') <> a.sha256
                               then 'ya no es el que entró: su texto no da su sha256'
                               else format('dice %s movimientos nuevos y tiene %s', a.filas_nuevas, x.n) end) as x
              from archivos_banco a
              cross join lateral (select count(*) as n from movimientos_banco m where m.archivo_id = a.id) x
             where encode(sha256(convert_to(a.texto, 'UTF8')), 'hex') <> a.sha256 or x.n <> a.filas_nuevas
            union all
            -- el sello de cada movimiento del período (la fórmula de
            -- fn_banco_sello): lo que dijo el banco, sin tocar
            select format('el movimiento %s (%s %s %s «%s») ya no es lo que dijo el banco: %s', m.id, m.cuenta, m.fecha, m.monto,
                          coalesce(m.descripcion, ''),
                          case when m.sello is null then 'no tiene su sello'
                               else 'su sello no da (se cambió por fuera de las funciones del banco, con las guardas apagadas)' end)
              from movimientos_banco m
              left join archivos_banco a on a.id = m.archivo_id
             where m.fecha between v_desde and v_hasta
               and m.sello is distinct from md5(array_to_string(array[m.cuenta, m.ultimos4, to_char(m.fecha, 'YYYY-MM-DD'),
                                                                     to_char(m.fecha_transaccion, 'YYYY-MM-DD'), m.monto::text,
                                                                     m.tipo_banco, m.cheque, m.descripcion, m.memo, m.origen,
                                                                     m.id_externo, m.llave, m.archivo_id::text, m.fila::text,
                                                                     a.sha256], '|', '∅'))
            union all
            -- y cada asiento que puso el banco en el período con su PAPEL (el
            -- movimiento, la nómina del proveedor anterior, la cuota, el mes
            -- de prepagados): el libro no se borra, y su papel tampoco. Si
            -- falta, alguien lo borró por fuera (con las guardas apagadas),
            -- quizá con su archivo entero: antes nada lo veía y el asiento se
            -- quedaba en el libro sin nada que lo explicara
            select format('el asiento %s (%s, %s) lo puso el banco y su papel ya no está (%s %s): se borró por fuera de las funciones '
                          'del banco, con las guardas apagadas. El libro no se toca: se restaura el papel (y su archivo) desde el '
                          'respaldo', a.numero, a.fecha_contable, a.origen_tabla, a.origen_tabla, a.origen_id)
              from asientos a
             where a.origen_tabla in ('movimientos_banco', 'nomina_proveedor', 'prestamo_cuotas', 'prepagados')
               and a.fecha_contable between v_desde and v_hasta
               and case a.origen_tabla
                     when 'prestamo_cuotas' then not exists (select 1 from prestamo_cuotas q where q.id::text = a.origen_id)
                     when 'prepagados' then not exists (select 1 from prepagados_amortizaciones pa
                                                         where pa.periodo = split_part(a.origen_id, '|', 1))
                     else not exists (select 1 from movimientos_banco m where m.id::text = a.origen_id) end
            limit 20) s;
    orden := 53; vista := 'cuadre: archivos intactos'; filas := null; esperadas := null;
    ok := cardinality(v_malos) = 0;
    detalle := case when not ok then array_to_string(v_malos, '; ') end;
    return next;
  end if;

  if v_pedidas && array['v_banco_movimientos', 'v_banco_bandeja'] or 'cuadre: ningún ticket después de clasificar' = any (v_solos) then
    -- el ticket que llegó después de clasificar su cargo (el gasto dos
    -- veces): la misma regla que fn_banco_tickets_llegados, escrita aquí;
    -- también el de OTRO total del comercio que el banco nombra (el ticket
    -- leído sin el tax: antes solo el mismo monto, y el cargo clasificado
    -- con su ticket de otro total libre dejaba el gasto dos veces en verde).
    -- (Los cargos clasificados, una vez; las líneas LIBRES de sus cuentas,
    -- que son pocas; de ellas, las de un recibo en sus días, buscando su
    -- asiento una por una; y los dos casos contra esas. Al revés, cada
    -- línea de los recibos se juntaba con cada cargo clasificado de dos
    -- meses, y con un año de banco este control pasaba de los 8 s de la
    -- API.)
    with cl as materialized (
           select m.id, m.cuenta, m.fecha, m.monto, m.fecha_transaccion, m.descripcion, m.desc_norm, m.propuesta,
                  -- (el primer día en que pudo ser la compra)
                  case when m.fecha_transaccion is not null then least(m.fecha_transaccion, m.fecha) - 3 else m.fecha - 7 end as desde
             from movimientos_banco m
            where m.estado = 'casado' and m.casado_clase = 'clasificado' and m.fecha >= v_corte and m.fecha <= v_hasta),
         lib as materialized (
           select l.asiento_id, l.orden, l.cuenta, l.monto
             from asiento_lineas l
            where exists (select 1 from cl)
              and l.cuenta = any ((select array_agg(distinct cl.cuenta) from cl)::text[])
              and not exists (select 1 from banco_casado_lineas bl
                               where bl.asiento_id = l.asiento_id and bl.orden = l.orden and bl.vigente)),
         lr as materialized (
           select l.asiento_id, l.orden, l.cuenta, l.monto, a.origen_id, a.numero, f.fdoc,
                  -- (las palabras del comercio del ticket: fn_banco_comercio,
                  -- escrito aquí; la app no llama a las funciones internas.
                  -- Su recibo se lee solo para las líneas libres)
                  coalesce((select array_agg(w.w)
                              from recibos r,
                                   regexp_split_to_table(btrim(regexp_replace(upper(coalesce(r.proveedor, '')), '[^[:alnum:]#&]+', ' ',
                                                                              'g')), ' ') as w(w)
                             where r.id = (case when a.origen_id ~ '^-?[0-9]{1,18}$' then a.origen_id::bigint end)
                               and length(w.w) >= 4
                               and w.w not in ('THE', 'INC', 'LLC', 'CORP', 'STORE', 'SUPPLY', 'COMPANY', 'SERVICES')),
                           '{}'::text[]) as pal
             from lib l
             cross join lateral (select a.* from asientos a where a.id = l.asiento_id offset 0) a
             cross join lateral (select coalesce(case when a.procedencia->>'fecha_documento' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                                                      then (a.procedencia->>'fecha_documento')::date end, a.fecha_contable) as fdoc) f
            where a.origen_tabla = 'recibos' and a.fecha_contable >= v_corte
              and f.fdoc between (select min(cl.desde) from cl) and (select max(cl.fecha) + 3 from cl)
              and a.camino not in ('reverso', 'reverso_automatico') and not a.reversible
              and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino in ('reverso', 'reverso_automatico'))),
         -- (Ronda 4: el ticket REPARTIDO entre obras —la misma foto en dos o
         -- más recibos— cuyas partes suman el cargo; sus partes no se dicen
         -- como «otro total»)
         lg as materialized (
           select l.asiento_id, l.orden, l.cuenta, l.monto, l.fdoc, btrim(rc.ruta) as ruta, rc.id as rid
             from lr l
             join recibos rc on rc.id = (case when l.origen_id ~ '^-?[0-9]{1,18}$' then l.origen_id::bigint end)
            where nullif(btrim(rc.ruta), '') is not null),
         grp as (
           select g.cuenta, g.ruta, sum(g.monto) as total, min(g.fdoc) as f1, max(g.fdoc) as f2,
                  string_agg(g.rid::text, ', ' order by g.rid) as refs
             from lg g
            group by g.cuenta, g.ruta
           having count(*) >= 2),
         gm as (
           select m.id, m.cuenta, m.fecha, m.monto, m.descripcion, g.refs
             from cl m
             join grp g on g.cuenta = m.cuenta and g.total = m.monto and g.f1 >= m.desde and g.f2 <= m.fecha + 3
            where not exists (select 1 from lg x
                               where x.cuenta = g.cuenta and x.ruta = g.ruta
                                 and coalesce(m.propuesta->'descartados', '[]'::jsonb) ? (x.asiento_id::text || ':' || x.orden)))
    select coalesce(array_agg(s.x), '{}') into v_malos
      from ((select format('el cargo %s (%s %s %s «%s») se clasificó y después entró su ticket (el recibo %s, %s del %s): el gasto '
                          'está dos veces. Cámbialo por el ticket (fn_banco_casar_con) o di que es otra compra '
                          '(fn_banco_duplicado, false, con su motivo)', m.id, m.cuenta, m.fecha, m.monto, coalesce(m.descripcion, ''),
                          l.origen_id, l.numero, l.fdoc) as x
              from cl m
              join lr l on l.cuenta = m.cuenta and l.monto = m.monto
             where l.fdoc between m.desde and m.fecha + 3
               and not (coalesce(m.propuesta->'descartados', '[]'::jsonb) ? (l.asiento_id::text || ':' || l.orden)))
            union all
            (select format('el cargo %s (%s %s %s «%s») se clasificó y hay un ticket de ese comercio con OTRO total (el recibo %s, '
                           '%s del %s, por %s): ¿leído sin el tax? El gasto está dos veces. Corrige su total en la app (✎) y cámbialo '
                           'por la clasificación, o di que es otra compra (fn_banco_duplicado, false, con su motivo)', m.id, m.cuenta,
                           m.fecha, m.monto, coalesce(m.descripcion, ''), l.origen_id, l.numero, l.fdoc, l.monto)
               from lr l
               join cl m on m.cuenta = l.cuenta and m.fecha between l.fdoc - 3 and l.fdoc + 60
              where m.monto <> l.monto and sign(m.monto) = sign(l.monto)
                and l.pal && string_to_array(coalesce(m.desc_norm, ''), ' ')
                and l.fdoc between m.desde and m.fecha + 3
                and not (coalesce(m.propuesta->'descartados', '[]'::jsonb) ? (l.asiento_id::text || ':' || l.orden))
                and not exists (select 1 from gm g where g.id = m.id))
            union all
            (select format('el cargo %s (%s %s %s «%s») se clasificó y después entró su ticket repartido entre obras (la misma foto: '
                           'los recibos %s, que suman %s): el gasto está dos veces. Cámbialo por el ticket (fn_banco_casar_con con '
                           'las líneas de esos recibos; la bandeja lo ofrece) o di que es otra compra (fn_banco_duplicado, false, con '
                           'su motivo)', g.id, g.cuenta, g.fecha, g.monto, coalesce(g.descripcion, ''), g.refs, -g.monto)
               from gm g)
            limit 20) s;
    orden := 57; vista := 'cuadre: ningún ticket después de clasificar'; filas := null; esperadas := null;
    ok := cardinality(v_malos) = 0;
    detalle := case when not ok then array_to_string(v_malos, '; ') end;
    return next;
  end if;

  if v_pedidas && array['v_conciliacion', 'v_conciliacion_partidas'] or 'cuadre: conciliaciones confirmadas' = any (v_solos) then
    with dia as materialized (
           select l.cuenta, a.fecha_contable as f, sum(l.monto) as s
             from asiento_lineas l join asientos a on a.id = l.asiento_id
            where l.cuenta in (select c0.cuenta from conciliaciones c0 where c0.estado = 'confirmada')
            group by l.cuenta, a.fecha_contable)
    select coalesce(array_agg(s.x), '{}') into v_malos
      from (select format('la conciliación de %s al %s, confirmada, %s', c.cuenta, c.fecha_corte,
                          concat_ws(' y ',
                            case when sl.libros <> c.saldo_libros
                                 then format('decía %s en libros y hoy el libro dice %s a esa fecha (algo se posteó después con '
                                             'fecha anterior al corte: reábrela y concíliala otra vez)', c.saldo_libros, sl.libros) end,
                            case when x.h is distinct from c.hash_partidas then 'sus partidas ya no son las que se confirmaron' end,
                            case when c.diferencia <> 0 or c.saldo_libros <> c.saldo_banco + x.dep - x.car - x.sb
                                 then 'su identidad no da cero' end)) as x
              from conciliaciones c
              -- (lo del libro de cada cuenta por día, de una pasada, y su
              -- saldo a cada corte sumando esos días: antes una consulta por
              -- conciliación sobre todas las líneas de su cuenta, 0,2 s con
              -- un año de conciliaciones confirmadas)
              join (select cc.id,
                           coalesce((select sum(d.s) from dia d where d.cuenta = cc.cuenta and d.f <= cc.fecha_corte), 0) as libros
                      from conciliaciones cc where cc.estado = 'confirmada') sl on sl.id = c.id
              cross join lateral (
                select encode(sha256(convert_to(
                         concat_ws('#', c.cuenta, to_char(c.fecha_corte, 'YYYY-MM-DD'), c.saldo_banco, c.saldo_libros,
                                   (select string_agg(concat_ws('|', p.lado, p.clase, p.asiento_id, p.orden, p.movimiento_id,
                                                                p.apertura_partida_id, to_char(p.fecha, 'YYYY-MM-DD'), p.monto),
                                                      E'\n' order by p.lado, p.fecha, p.monto, p.asiento_id, p.orden, p.movimiento_id,
                                                                     p.apertura_partida_id)
                                      from conciliacion_partidas p where p.conciliacion_id = c.id)), 'UTF8')), 'hex') as h,
                       coalesce((select sum(p.monto) from conciliacion_partidas p
                                  where p.conciliacion_id = c.id and p.lado = 'libro' and p.monto > 0), 0) as dep,
                       coalesce((select -sum(p.monto) from conciliacion_partidas p
                                  where p.conciliacion_id = c.id and p.lado = 'libro' and p.monto < 0), 0) as car,
                       coalesce((select sum(p.monto) from conciliacion_partidas p
                                  where p.conciliacion_id = c.id and p.lado = 'banco'), 0) as sb) x
             where c.estado = 'confirmada'
               and (sl.libros <> c.saldo_libros or x.h is distinct from c.hash_partidas or c.diferencia <> 0
                    or c.saldo_libros <> c.saldo_banco + x.dep - x.car - x.sb)
            union all
            -- lo del banco dentro de una confirmada que hoy está pendiente,
            -- o que se ignoró o se casó DESPUÉS de confirmarla (un
            -- movimiento que llegó tarde, uno que volvió a la bandeja):
            -- la conciliación ya no es la que se confirmó
            select format('el movimiento %s (%s %s %s «%s») %s dentro de la conciliación confirmada de %s al %s: reábrela '
                          '(fn_conciliacion_reabrir, con su motivo) y concíliala otra vez', m.id, m.cuenta, m.fecha, m.monto,
                          coalesce(m.descripcion, ''),
                          case when m.estado = 'pendiente' then 'está pendiente'
                               when m.estado = 'ignorado' then 'se ignoró después de confirmarla'
                               else 'se casó después de confirmarla' end,
                          c.cuenta, c.fecha_corte)
              from conciliaciones c
              join movimientos_banco m on m.cuenta = c.cuenta and m.fecha between v_corte and c.fecha_corte
             where c.estado = 'confirmada' and c.tipo = 'normal'
               and (m.estado = 'pendiente'
                    or (m.estado = 'ignorado' and m.cambiado_el > c.confirmada_el and m.duplicado is distinct from 'es_el_mismo')
                    or (m.estado in ('casado', 'en_transito') and m.casado_el > c.confirmada_el))
            union all
            -- confirmada con algo que pedía su motivo escrito y no lo tiene:
            -- el saldo que se escribió contra el del archivo del banco al
            -- mismo día (sin su motivo y su documento, el mes estaría
            -- «cuadrado» contra un saldo que el banco no dice), o una partida
            -- de la conciliación de apertura con más de 30 días sin llegar
            select format('la conciliación de %s al %s, confirmada, %s: reábrela (fn_conciliacion_reabrir, con su motivo), dile el '
                          'motivo y vuelve a confirmarla', c.cuenta, c.fecha_corte,
                          concat_ws(' y ',
                            case when c.saldo_statement is not null and c.saldo_archivo is not null
                                      and c.saldo_statement <> c.saldo_archivo
                                      and (nullif(btrim(coalesce(c.saldo_motivo, '')), '') is null
                                           or nullif(btrim(coalesce(c.saldo_documento, '')), '') is null)
                                 then format('se confirmó con el saldo escrito %s cuando el archivo del banco dice %s a esa fecha, '
                                             'sin su motivo y su documento (fn_conciliacion_saldo)', c.saldo_statement,
                                             c.saldo_archivo) end,
                            case when exists (select 1 from conciliacion_partidas p
                                               where p.conciliacion_id = c.id and p.apertura_partida_id is not null and p.alarma
                                                 and p.lado = 'libro' and nullif(btrim(coalesce(p.motivo, '')), '') is null)
                                 then 'tiene una partida de la conciliación de apertura con más de 30 días sin llegar y sin su motivo '
                                      '(fn_conciliacion_partida)' end,
                            -- (el ticket o la transferencia de más de 10 días sin
                            -- su movimiento y sin su motivo: la misma regla de
                            -- fn_conciliacion_recalcular)
                            case when exists (select 1 from conciliacion_partidas p
                                               join asientos a on a.id = p.asiento_id
                                              where p.conciliacion_id = c.id and p.lado = 'libro' and p.clase <> 'posible_duplicado'
                                                and c.fecha_corte - p.fecha > 10
                                                and (a.origen_tabla in ('recibos', 'cobros', 'prestamo_cuotas')
                                                     or (a.origen_tabla = 'movimientos_banco' and a.procedencia->>'regla' like 'R3%'))
                                                and nullif(btrim(coalesce(p.motivo, '')), '') is null
                                                and not exists (select 1 from banco_casado_lineas cl
                                                                 where cl.asiento_id = p.asiento_id and cl.orden = p.orden and cl.vigente))
                                 then 'tiene un ticket, un cobro, una cuota o una transferencia de más de 10 días sin su movimiento '
                                      'del banco y sin su motivo (fn_conciliacion_partida)' end))
              from conciliaciones c
             where c.estado = 'confirmada' and c.tipo = 'normal'
               and ((c.saldo_statement is not null and c.saldo_archivo is not null and c.saldo_statement <> c.saldo_archivo
                     and (nullif(btrim(coalesce(c.saldo_motivo, '')), '') is null
                          or nullif(btrim(coalesce(c.saldo_documento, '')), '') is null))
                    or exists (select 1 from conciliacion_partidas p
                                where p.conciliacion_id = c.id and p.apertura_partida_id is not null and p.alarma and p.lado = 'libro'
                                  and nullif(btrim(coalesce(p.motivo, '')), '') is null)
                    or exists (select 1 from conciliacion_partidas p
                                join asientos a on a.id = p.asiento_id
                               where p.conciliacion_id = c.id and p.lado = 'libro' and p.clase <> 'posible_duplicado'
                                 and c.fecha_corte - p.fecha > 10
                                 and (a.origen_tabla in ('recibos', 'cobros', 'prestamo_cuotas')
                                      or (a.origen_tabla = 'movimientos_banco' and a.procedencia->>'regla' like 'R3%'))
                                 and nullif(btrim(coalesce(p.motivo, '')), '') is null
                                 and not exists (select 1 from banco_casado_lineas cl
                                                  where cl.asiento_id = p.asiento_id and cl.orden = p.orden and cl.vigente)))
            limit 20) s;
    orden := 54; vista := 'cuadre: conciliaciones confirmadas'; filas := null; esperadas := null;
    ok := cardinality(v_malos) = 0;
    detalle := case when not ok then array_to_string(v_malos, '; ') end;
    return next;
  end if;

  if 'v_prestamos' = any (v_pedidas) or 'cuadre: préstamos' = any (v_solos) then
    select coalesce(sum(p.saldo_inicial - coalesce((select sum(q.capital) from prestamo_cuotas q
                                                     where q.prestamo_id = p.id and q.anulada_el is null), 0)), 0),
           count(*)
      into v_a, v_cnt
      from prestamos p where p.estado <> 'cancelado';
    select coalesce(-sum(l.monto), 0) into v_b
      from asiento_lineas l
     where l.cuenta in (select p.cuenta from prestamos p where p.estado <> 'cancelado'
                        union select p.cuenta_largo from prestamos p where p.estado <> 'cancelado' and p.cuenta_largo is not null);
    select coalesce(array_agg(s.x), '{}') into v_malos
      from (select format('la cuota %s del %s (%s) %s', q.id, q.fecha, q.monto,
                          case when q.anulada_el is null then 'está viva y su asiento no' else 'está anulada y su asiento sigue vivo' end) as x
              from prestamo_cuotas q
             where (q.anulada_el is null)
                   = exists (select 1 from asientos r where r.reversa_a = q.asiento_id and r.camino in ('reverso', 'reverso_automatico'))
            union all
            -- una cuenta de los préstamos con saldo DEUDOR: el capital bajó
            -- una cuenta que no tenía ese saldo (la apertura trajo el
            -- préstamo entero en la otra). La suma de las dos puede cuadrar
            -- y el balance de c4 la enseña como un activo («pasivos pagados de
            -- más») con el largo plazo sin bajar
            select format('la cuenta %s de los préstamos tiene saldo DEUDOR (%s): el capital pagado bajó una cuenta que no tenía ese '
                          'saldo, y el balance la enseña como un activo. Reclasifica con un asiento a mano (Cr %s / Dr la cuenta del '
                          'préstamo que tiene el saldo), o deja que el cierre (f08) reparta entre corriente y largo plazo', x.cuenta,
                          x.saldo, x.cuenta)
              from (select l.cuenta, sum(l.monto) as saldo
                      from asiento_lineas l
                     where l.cuenta in (select p.cuenta from prestamos p
                                        union select p.cuenta_largo from prestamos p where p.cuenta_largo is not null)
                     group by l.cuenta
                    having sum(l.monto) > 0) x
            limit 20) s;
    orden := 55; vista := 'cuadre: préstamos'; filas := null; esperadas := null;
    ok := v_cnt = 0 or (v_a = v_b and cardinality(v_malos) = 0);
    detalle := case when v_cnt = 0 then 'Sin préstamos registrados (fn_prestamo_guardar, en el SQL Editor).'
                    when not ok then concat_ws('; ',
                      case when v_a <> v_b then format('el libro dice %s en las cuentas de los préstamos y sus saldos suman %s: '
                                                       'falta registrar un préstamo, su desembolso o una cuota', v_b, v_a) end,
                      nullif(array_to_string(v_malos, '; '), ''))
                    else format('%s préstamo(s): se deben %s, lo mismo que dice el libro.', v_cnt, v_a) end;
    return next;
  end if;

  if 'v_prepagados' = any (v_pedidas) or 'cuadre: prepagados' = any (v_solos) then
    -- (lo que debe quedar en 1410/1420 de cada póliza: su meta —la vigente,
    -- todo; la cancelada con su fecha, todo menos lo devuelto; la
    -- sustituida, nada— menos lo amortizado; como fn_prepagado_meta, escrito
    -- aquí: la app no llama a las funciones internas)
    select coalesce(sum(case when p.estado = 'vigente' or p.sustituida_por is not null or p.cancelado_al is not null
                             then (case when p.sustituida_por is not null then 0
                                        else (case when p.desde < v_corte
                                                   then coalesce(p.saldo_corte,
                                                                 p.monto - round(p.monto * (least(v_corte - 1, p.hasta) - p.desde + 1)
                                                                                 / (p.hasta - p.desde + 1), 2))
                                                   else p.monto end)
                                             - coalesce(p.devuelto, 0) end)
                                  - coalesce((select sum(a.monto) from prepagados_amortizaciones a
                                               where a.prepagado_id = p.id and a.vigente), 0)
                             else 0 end), 0),
           count(*)
      into v_a, v_cnt
      from prepagados p;
    select coalesce(sum(l.monto), 0) into v_b
      from asiento_lineas l where l.cuenta in (select distinct p.cuenta from prepagados p);
    select coalesce(array_agg(s.x), '{}') into v_malos
      from (select format('la amortización de %s de %s está viva y su asiento %s no', a.periodo, a.prepagado_id, s2.numero) as x
              from prepagados_amortizaciones a
              join asientos s2 on s2.id = a.asiento_id
             where a.vigente
               and exists (select 1 from asientos r where r.reversa_a = a.asiento_id and r.camino in ('reverso', 'reverso_automatico'))
            union all
            select format('«%s» empezó antes del corte y no dice su saldo al corte (lo que dejó QuickBooks por amortizar para ella: '
                          'fn_prepagado_guardar con saldo_corte)', p.descripcion)
              from prepagados p where p.estado = 'vigente' and p.desde < v_corte and p.saldo_corte is null
            limit 20) s;
    orden := 56; vista := 'cuadre: prepagados'; filas := null; esperadas := null;
    ok := v_cnt = 0 or (v_a = v_b and cardinality(v_malos) = 0);
    detalle := case when v_cnt = 0 then 'Sin prepagados registrados (fn_prepagado_guardar, en el SQL Editor).'
                    when not ok then concat_ws('; ',
                      case when v_a <> v_b then format('el libro dice %s en las cuentas de prepagados y lo que falta por amortizar '
                                                       'suma %s: falta registrar una póliza, clasificar a su cuenta lo que devolvió '
                                                       'la aseguradora de una cancelada, o amortizar un mes '
                                                       '(fn_prepagados_amortizar)%s', v_b, v_a,
                                                       coalesce('. Canceladas: ' || (select string_agg(format(
                                                                  '«%s»%s', p.descripcion,
                                                                  case when p.sustituida_por is not null then ' (sustituida)'
                                                                       else format(' al %s, con %s devueltos', p.cancelado_al,
                                                                                   p.devuelto) end), ', ' order by p.descripcion)
                                                                  from prepagados p
                                                                 where p.sustituida_por is not null or p.cancelado_al is not null),
                                                                '')) end,
                      nullif(array_to_string(v_malos, '; '), ''))
                    else format('%s póliza(s): faltan %s por amortizar, lo mismo que dice el libro.', v_cnt, v_a) end;
    return next;
  end if;

  -- 3. Las protecciones del banco, siempre.
  --   · los triggers de cada tabla, encendidos y con su función;
  select coalesce(array_agg(format('trigger %s en %s %s', t.nombre, t.tabla,
                                   case when tg.oid is null then 'no está'
                                        when tg.tgenabled not in ('O', 'A') then 'apagado'
                                        else 'con otra función (' || tg.tgfoid::regproc::text || ')' end) order by t.nombre), '{}')
    into v_prot
    from (select x.t as tabla, 'trg_' || x.t || y.suf as nombre, y.fn as funcion
            from unnest(v_tablas) as x(t)
            cross join (values ('_guarda', 'fn_banco_guarda'), ('_sin_truncate', 'fn_banco_guarda'),
                               ('_historial', 'fn_banco_historial')) as y(suf, fn)
           where not (y.suf = '_historial' and x.t in ('banco_historial', 'archivos_banco', 'movimientos_banco_ids'))) t
    left join pg_trigger tg on tg.tgrelid = to_regclass('public.' || t.tabla) and tg.tgname = t.nombre
   where tg.oid is null or tg.tgenabled not in ('O', 'A') or tg.tgfoid <> to_regproc('public.' || t.funcion);
  --   · la RLS y su única policy (SELECT del dueño);
  v_prot := v_prot || array(
    select format('%s %s', c.relname,
                  case when not c.relrowsecurity then 'no tiene la RLS encendida'
                       else 'no tiene solo su policy de lectura del dueño' end)
      from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relname = any (v_tablas)
       and (not c.relrowsecurity
            or (select count(*) from pg_policy po where po.polrelid = c.oid) <> 1
            or not exists (select 1 from pg_policy po
                            where po.polrelid = c.oid and po.polname = c.relname || '_dueno' and po.polcmd = 'r'
                              and pg_get_expr(po.polqual, po.polrelid) ~ 'es_dueno\(\)'))
     order by 1);
  --   · los permisos: a anon nada; a authenticated y service_role solo
  --     SELECT en tablas (y archivos_banco, a service_role, solo por
  --     columnas y sin su texto: el número entero de la cuenta); en vistas
  --     solo SELECT a authenticated;
  v_prot := v_prot || array(
    select format('%s tiene %s en %s%s', case when a.grantee = 0 then 'PUBLIC' else r.rolname::text end, a.privilege_type, c.relname,
                  case when c.relname = 'archivos_banco' and r.rolname = 'service_role'
                       then ' (lee el texto de los estados de cuenta, con el número entero de la cuenta)' else '' end)
      from pg_class c
      cross join lateral aclexplode(c.relacl) a
      left join pg_roles r on r.oid = a.grantee
     where c.relnamespace = 'public'::regnamespace and (c.relname = any (v_tablas) or c.relname = any (v_vistas))
       and (a.grantee = 0 or r.rolname in ('anon', 'authenticated', 'service_role'))
       and (a.grantee = 0 or r.rolname = 'anon' or a.privilege_type <> 'SELECT'
            or (c.relname = any (v_vistas) and r.rolname = 'service_role')
            or (c.relname = 'archivos_banco' and r.rolname = 'service_role'))
    union all
    select format('%s tiene %s en la columna %s.%s', case when a.grantee = 0 then 'PUBLIC' else r.rolname::text end, a.privilege_type,
                  c.relname, at.attname)
      from pg_class c
      join pg_attribute at on at.attrelid = c.oid and at.attacl is not null
      cross join lateral aclexplode(at.attacl) a
      left join pg_roles r on r.oid = a.grantee
     where c.relnamespace = 'public'::regnamespace and (c.relname = any (v_tablas) or c.relname = any (v_vistas))
       and (a.grantee = 0 or r.rolname in ('anon', 'authenticated', 'service_role'))
       and not (c.relname = 'archivos_banco' and r.rolname = 'service_role' and a.privilege_type = 'SELECT'
                and at.attname <> 'texto')
    union all
    select format('la vista %s %s', v.x, case when c.oid is null then 'no está' else 'no es security_invoker' end)
      from unnest(v_vistas) as v(x)
      left join pg_class c on c.oid = to_regclass('public.' || v.x)
     where c.oid is null or not coalesce('security_invoker=true' = any (coalesce(c.reloptions, '{}')), false)
    order by 1);
  --   · las funciones: de la API, solo las de conta.js; anon ninguna;
  --     service_role solo las de trigger (e37, como acepta c2);
  v_prot := v_prot || array(
    select format('%s ejecuta %s', r.rolname, p.oid::regprocedure)
      from pg_proc p
      cross join (values ('anon'), ('authenticated'), ('service_role')) as r(rolname)
     where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'
       and (p.proname like 'fn\_banco\_%' or p.proname like 'fn\_conciliacion\_%' or p.proname = 'fn_conciliar'
            or p.proname like 'fn\_prestamo\_%' or p.proname like 'fn\_prepagado%')
       and has_function_privilege(r.rolname, p.oid, 'execute')
       and not (r.rolname = 'authenticated' and replace(p.oid::regprocedure::text, ' ', '') = any (v_app))
       and not (r.rolname = 'service_role' and p.prorettype = 'trigger'::regtype)
    union all
    select format('falta la función %s', f) from unnest(v_app) f where to_regprocedure('public.' || f) is null
    order by 1);
  --   · sus HUELLAS: se corre el TEXTO de las dos (desde la app,
  --     authenticated no ejecuta ni fn_banco_huellas ni la que calcula);
  select max(p.prosrc) filter (where p.oid = to_regprocedure('public.fn_banco_huellas()')),
         max(p.prosrc) filter (where p.oid = to_regprocedure('public.fn_banco_huellas_calcular()'))
    into v_hsel, v_hcal
    from pg_proc p
   where p.oid in (to_regprocedure('public.fn_banco_huellas()'), to_regprocedure('public.fn_banco_huellas_calcular()'));
  if v_hsel is null or v_hcal is null then
    v_hue := array['faltan las huellas del banco (fn_banco_huellas): vuelve a pegar c6-banco.sql'];
  else
    execute 'select coalesce(array_agg(format(''%s %s %s'', coalesce(h.tipo, a.tipo), coalesce(h.objeto, a.objeto),
                                              case when h.objeto is null then ''es nuevo: no es de c6 (volver a pegar c6 lo quita, o lo sella)''
                                                   when a.objeto is null then ''ya no está''
                                                   else ''cambió desde que se pegó c6'' end)
                                       order by coalesce(h.tipo, a.tipo), coalesce(h.objeto, a.objeto)), ''{}'')
               from (' || v_hsel || ') h(tipo, objeto, md5)
               full join (' || v_hcal || ') a(tipo, objeto, md5) on a.tipo = h.tipo and a.objeto = h.objeto
              where a.md5 is distinct from h.md5'
      into v_hue;
  end if;
  v_prot := v_prot || v_hue;
  --   · lo AJENO que abre las tablas del banco a la API (el mismo cierre
  --     que c2 hace para el libro y c4 para sus tablas): una vista (de
  --     cualquier esquema que no sea del sistema) que las lee, directo o a
  --     través de otra vista, sin security_invoker (lee con los permisos de
  --     su dueño y se salta la RLS: en Supabase una vista nace así, y con
  --     SELECT para anon y authenticated: una sola sobre archivos_banco
  --     publicaba los estados de cuenta enteros con la llave pública); una
  --     vista materializada que las copia y que la API puede leer; y una
  --     función SECURITY DEFINER que la API puede ejecutar y que las lee:
  --     porque las nombra, porque depende de ellas, o porque llama a otra
  --     función que las lee (una de este archivo, o una de ayuda SECURITY
  --     INVOKER: llamada desde la DEFINER, corre con los permisos de su
  --     dueño), hasta que no aparezca nada nuevo. En el texto de cada
  --     función sin sus comentarios; un nombre compuesto (archivos_banco)
  --     cuenta dondequiera que aparezca como palabra; uno simple
  --     (conciliaciones), detrás de from, join, into, update, using… o de
  --     una coma o un paréntesis, fuera de las cadenas. Lo de c1, c2 y c3
  --     sellado por c2 (fn_libro_huellas) y sin cambios no es ajeno (c2
  --     nombra las tablas del banco en sus mensajes: fn_reversar dice cómo
  --     se deshace el asiento de un movimiento); se corre el TEXTO de sus
  --     huellas, como las de aquí. Lo mismo lo de c4 sellado por c4
  --     (fn_estados_huellas) y sin cambios: antes se leía, en cada llamada
  --     al control, el texto entero de sus funciones (el de fn_estados_control
  --     solo, 90 KB). (Antes solo se buscaban las funciones
  --     que nombraban una tabla del banco: una vista ajena, o una DEFINER
  --     que leía el banco por una función de ayuda, salían en verde.)
  select p.prosrc into v_c2sel from pg_proc p where p.oid = to_regprocedure('public.fn_libro_huellas()');
  if v_c2sel is not null then
    begin
      execute 'select coalesce(array_agg(p.oid), ''{}'') from (' || v_c2sel || ') h(tipo, objeto, md5)
                 join pg_proc p on p.oid = to_regprocedure(''public.'' || h.objeto)
                where h.tipo = ''funcion'' and md5(pg_get_functiondef(p.oid)) = h.md5'
        into v_c2ok;
    exception when others then
      v_c2ok := '{}';
    end;
  end if;
  select p.prosrc into v_c4sel from pg_proc p where p.oid = to_regprocedure('public.fn_estados_huellas()');
  if v_c4sel is not null then
    begin
      execute 'select coalesce(array_agg(p.oid), ''{}'') from (' || v_c4sel || ') h(tipo, objeto, md5)
                 join pg_proc p on p.oid = to_regprocedure(''public.'' || h.objeto)
                where h.tipo = ''funcion'' and md5(pg_get_functiondef(p.oid)) = h.md5'
        into v_c4ok;
    exception when others then
      v_c4ok := '{}';
    end;
    v_c2ok := v_c2ok || v_c4ok;
  end if;
  with recursive dep(oid) as (
         select c.oid from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = any (v_tablas)
         union
         select rw.ev_class
           from dep
           join pg_depend d on d.refobjid = dep.oid and d.refclassid = 'pg_class'::regclass and d.classid = 'pg_rewrite'::regclass
           join pg_rewrite rw on rw.oid = d.objid
          where rw.ev_class <> dep.oid)
  select coalesce(array_agg(dep.oid), '{}') into v_rel from dep;
  select string_agg(distinct c.relname::text, '|') filter (where c.relname::text !~ '_'),
         string_agg(distinct c.relname::text, '|') filter (where c.relname::text ~ '_')
    into v_simples, v_compues
    from pg_class c
   where c.oid = any (v_rel) and c.relname ~ '^[[:alnum:]_]+$';
  select coalesce(array_agg(f.oid), '{}') into v_fn_c6
    from pg_proc f
   where f.pronamespace = 'public'::regnamespace
     and (f.proname like 'fn\_banco\_%' or f.proname like 'fn\_conciliacion\_%' or f.proname = 'fn_conciliar'
          or f.proname like 'fn\_prestamo\_%' or f.proname like 'fn\_prepagado%');
  v_lee := v_fn_c6;
  v_rx_c := case when v_compues is not null then '[[:<:]](' || v_compues || ')[[:>:]]' end;
  v_rx_k := case when v_simples is not null
                 then '[[:<:]](from|join|into|update|table|only|truncate|using)[[:space:]]+'
                      || '(([[:alnum:]_]+|"[^"]+")[[:space:]]*[.][[:space:]]*)?"?(' || v_simples || ')"?[[:>:]]' end;
  v_rx_s := case when v_simples is not null
                 then '[,(][[:space:]]*(([[:alnum:]_]+|"[^"]+")[[:space:]]*[.][[:space:]]*)?"?(' || v_simples || ')"?[[:>:]]' end;
  -- (La primera vuelta busca los nombres de las tablas y las llamadas a
  -- cualquier función de este archivo, por sus prefijos: son las de
  -- v_fn_c6. Las siguientes, solo las llamadas a las que se acaban de
  -- encontrar: lo demás ya se miró. Y antes de quitarle los comentarios a
  -- una función, su texto tal cual tiene que nombrar alguno de esos
  -- nombres en cualquier parte: quitar comentarios o cadenas nunca hace
  -- aparecer uno. Antes cada vuelta limpiaba y miraba todas las funciones
  -- con todos los nombres: medio segundo en cada llamada al control.)
  v_rx_f := '[[:<:]](fn_banco_[[:alnum:]_]*|fn_conciliacion_[[:alnum:]_]*|fn_conciliar|fn_prestamo_[[:alnum:]_]*'
            || '|fn_prepagado[[:alnum:]_]*)[[:space:]]*[(]';
  -- (El filtro de la primera vuelta, sobre el texto en minúsculas: las
  -- raíces de las tablas y funciones de este archivo —todas llevan banco,
  -- concilia, prestamo o prepagado— y el nombre de cada vista que las lee.)
  select string_agg(distinct lower(c.relname::text), '|') into v_fnn
    from pg_class c
   where c.oid = any (v_rel) and c.relname ~ '^[[:alnum:]_]+$' and lower(c.relname::text) !~ '(banco|concilia|prestamo|prepagado)';
  v_rx_pre := '(banco|concilia|prestamo|prepagado' || coalesce('|' || v_fnn, '') || ')';
  v_vuelta := 0;
  loop
    v_vuelta := v_vuelta + 1;
    select coalesce(array_agg(x.oid), '{}') into v_nuevas
      from (select f.oid, regexp_replace(regexp_replace(f.prosrc, '/\*.*?\*/', ' ', 'g'), '--[^\n]*', ' ', 'g') as src
              from pg_proc f
              join pg_namespace n on n.oid = f.pronamespace
             where n.nspname !~ '^pg_' and n.nspname <> 'information_schema'
               and f.prokind in ('f', 'p')
               and not (f.oid = any (v_lee)) and not (f.oid = any (v_c2ok))
               and not exists (select 1 from pg_depend e
                                where e.classid = 'pg_proc'::regclass and e.objid = f.oid and e.deptype = 'e')
               and ((v_rx_pre is not null and lower(f.prosrc) ~ v_rx_pre)
                    or exists (select 1 from pg_depend d
                                where d.classid = 'pg_proc'::regclass and d.objid = f.oid
                                  and ((d.refclassid = 'pg_class'::regclass and d.refobjid = any (v_rel))
                                       or (d.refclassid = 'pg_proc'::regclass and d.refobjid = any (v_lee)))))) x
     where (v_vuelta = 1 and v_rx_c is not null and x.src ~* v_rx_c)
        or (v_vuelta = 1 and v_rx_k is not null and x.src ~* v_rx_k)
        or (v_vuelta = 1 and v_rx_s is not null and regexp_replace(x.src, '''([^'']|'''')*''', ' ', 'g') ~* v_rx_s)
        or (v_rx_f is not null and x.src ~* v_rx_f)
        or exists (select 1 from pg_depend d
                    where d.classid = 'pg_proc'::regclass and d.objid = x.oid
                      and ((d.refclassid = 'pg_class'::regclass and d.refobjid = any (v_rel))
                           or (d.refclassid = 'pg_proc'::regclass and d.refobjid = any (v_lee))));
    exit when cardinality(v_nuevas) = 0;
    v_lee := v_lee || v_nuevas;
    select string_agg(distinct f.proname::text, '|') into v_fnn
      from pg_proc f where f.oid = any (v_nuevas) and f.proname ~ '^[[:alnum:]_]+$';
    v_rx_f := case when v_fnn is not null then '[[:<:]](' || v_fnn || ')[[:space:]]*[(]' end;
    v_rx_pre := case when v_fnn is not null then '(' || lower(v_fnn) || ')' end;
  end loop;
  v_ajeno := array(
    select x.f from (
      select format('la vista %s.%s lee las tablas del banco sin security_invoker: la API la lee con los permisos de su dueño '
                    '(with (security_invoker = true), y revoke de anon; o se quita)', n.nspname, c.relname) as f
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
       where c.oid = any (v_rel) and c.relkind = 'v'
         and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o
                            where o.option_name = 'security_invoker'), false)
      union all
      select format('la vista materializada %s.%s copia tablas del banco y la API la puede leer (no tiene RLS): se le quita la API, '
                    'o se quita', n.nspname, c.relname)
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
       where c.oid = any (v_rel) and c.relkind = 'm'
         and (has_table_privilege('anon', c.oid, 'SELECT') or has_table_privilege('authenticated', c.oid, 'SELECT')
              or has_table_privilege('service_role', c.oid, 'SELECT'))
      union all
      select format('la función %s es SECURITY DEFINER, lee las tablas del banco (directo, o llamando a otra función que las lee) y '
                    'la puede ejecutar %s: o es SECURITY INVOKER o se le quita la API (revoke execute … from public, anon, '
                    'authenticated, service_role)', f.oid::regprocedure,
                    (select string_agg(g, ', ' order by g)
                       from unnest(array['anon', 'authenticated', 'service_role']) g
                      where has_schema_privilege(g, f.pronamespace, 'USAGE') and has_function_privilege(g, f.oid, 'EXECUTE')))
        from pg_proc f
       where f.oid = any (v_lee) and not (f.oid = any (v_fn_c6))
         and f.prosecdef and f.prokind = 'f'
         and f.prorettype not in ('trigger'::regtype, 'event_trigger'::regtype)
         and exists (select 1 from unnest(array['anon', 'authenticated', 'service_role']) g
                      where has_schema_privilege(g, f.pronamespace, 'USAGE') and has_function_privilege(g, f.oid, 'EXECUTE'))
      union all
      -- y su hermana de TRIGGER: una función SECURITY DEFINER ajena que lee
      -- las tablas del banco, enganchada a un trigger de una tabla donde la
      -- API escribe (horas, recibos…). No hace falta EXECUTE: la dispara el
      -- insert del equipo, corre con los permisos de su dueño (se salta la
      -- RLS del banco) y lo que copie en una columna que el equipo lee (las
      -- notas de sus horas), el equipo lo ve, número de cuenta incluido.
      -- Antes las funciones de trigger no se miraban y esto salía en verde
      select format('la función de trigger %s es SECURITY DEFINER, lee las tablas del banco y la dispara %s, donde la API escribe: '
                    'corre con los permisos de su dueño y se salta la RLS del banco (lo que copie en una columna que el equipo '
                    'lee, el equipo lo ve). O es SECURITY INVOKER, o no lee el banco, o se quita su trigger',
                    f.oid::regprocedure,
                    string_agg(distinct format('el trigger %s de %s', tg.tgname, tg.tgrelid::regclass), ', '))
        from pg_proc f
        join pg_trigger tg on tg.tgfoid = f.oid and not tg.tgisinternal
       where f.oid = any (v_lee) and not (f.oid = any (v_fn_c6)) and f.prosecdef
         and exists (select 1 from unnest(array['anon', 'authenticated', 'service_role']) g
                      where has_table_privilege(g, tg.tgrelid, 'INSERT') or has_table_privilege(g, tg.tgrelid, 'UPDATE')
                         or has_table_privilege(g, tg.tgrelid, 'DELETE'))
       group by f.oid
      union all
      -- y la otra puerta con los permisos del dueño: una REGLA ajena
      -- (pg_rewrite, «on insert to horas do also insert into pendientes
      -- select … from archivos_banco») de una tabla donde la API escribe.
      -- Una regla lee las tablas que nombra con los permisos del dueño de
      -- SU tabla (se salta la RLS del banco), y lo que copie donde el equipo
      -- lee (sus pendientes, sus notas), el equipo lo ve: el estado de
      -- cuenta entero, con el número de la cuenta y el de ruta. Antes solo
      -- se miraban vistas, funciones y triggers, y una regla así salía en
      -- verde. (La de cualquier tabla, no solo las del banco: las de estas,
      -- el pegado las quita.)
      select format('la regla %s de %s lee las tablas del banco y se dispara cuando la API escribe en %s: corre con los permisos '
                    'del dueño de esa tabla y se salta la RLS del banco (lo que copie donde el equipo lee, el equipo lo ve). Se '
                    'quita: drop rule %I on %s;', rw.rulename, rw.ev_class::regclass, rw.ev_class::regclass, rw.rulename,
                    rw.ev_class::regclass)
        from pg_rewrite rw
        join pg_class c on c.oid = rw.ev_class
       where rw.rulename <> '_RETURN' and c.relkind in ('r', 'p', 'f', 'v')
         and not (c.relnamespace = 'public'::regnamespace and c.relname = any (v_tablas))
         and exists (select 1 from pg_depend d
                      where d.classid = 'pg_rewrite'::regclass and d.objid = rw.oid
                        and d.refclassid = 'pg_class'::regclass and d.refobjid = any (v_rel) and d.refobjid <> rw.ev_class)
         and exists (select 1 from unnest(array['anon', 'authenticated', 'service_role']) g
                      where has_table_privilege(g, c.oid, 'INSERT') or has_table_privilege(g, c.oid, 'UPDATE')
                         or has_table_privilege(g, c.oid, 'DELETE'))) x
     order by 1);
  orden := 90; vista := 'cuadre: protecciones del banco'; filas := null; esperadas := null;
  ok := cardinality(v_prot) = 0 and cardinality(v_ajeno) = 0;
  -- (Lo de este archivo lo pone como debe volver a pegarlo; lo ajeno no:
  -- cada uno dice qué hacer. Antes todo terminaba en «vuelve a pegar
  -- c6-banco.sql», que no quita una regla ni un trigger de otra tabla.)
  detalle := case when not ok
                  then concat_ws('. ',
                         case when cardinality(v_prot) > 0
                              then array_to_string(v_prot, '; ') || '. Vuelve a pegar c6-banco.sql (lo pone como debe)' end,
                         case when cardinality(v_ajeno) > 0
                              then 'Lo AJENO que abre el banco (volver a pegar c6 no lo quita): ' || array_to_string(v_ajeno, '; ') end)
                       || '.' end;
  return next;

  -- 4. c2, c3 y c4 al día (su marca, leída de su texto).
  select coalesce(array_agg(format('%s dice %s y el banco necesita %s o más (vuelve a pegar %s)', q.fn, coalesce(q.v::text, 'que no existe'),
                                   q.minimo, q.archivo) order by q.fn), '{}')
    into v_malos
    from (select q0.*, (select substring(pp.prosrc from '([0-9]{10})')::bigint
                          from pg_proc pp where pp.oid = to_regprocedure('public.' || q0.fn)) as v
            from (values ('fn_libro_version()', 2026092701::bigint, 'c2-libro.sql'),
                         ('fn_puente_version()', 2026092601::bigint, 'c3-puentes.sql'),
                         ('fn_estados_version()', 2026092601::bigint, 'c4-estados.sql')) as q0(fn, minimo, archivo)) q
   where coalesce(q.v, 0) < q.minimo;
  orden := 91; vista := 'cuadre: c2, c3 y c4 al día'; filas := null; esperadas := null;
  ok := cardinality(v_malos) = 0;
  detalle := case when not ok then array_to_string(v_malos, '; ') end;
  return next;
end $$;
revoke execute on function public.fn_banco_control(text, text[]) from public, anon, authenticated, service_role;
grant  execute on function public.fn_banco_control(text, text[]) to authenticated;

-- ---------------------------------------------------------------------
-- 12 · fn_banco_verificar(cuentas) — la revisión entera, desde el SQL
-- Editor (no es de la API): los cuadres del control con todo, y lo que el
-- control no puede hacer sin las funciones internas:
--   · cada conciliación confirmada que PUDO cambiar desde que se confirmó
--     (algo posteado después con fecha hasta su corte, un movimiento de su
--     tramo que cambió de estado o de casado, o que entró después),
--     RECALCULADA contra lo que se confirmó (sus partidas una por una). Las
--     demás no se recalculan: el control compara su huella con sus
--     partidas (cuadre 54), y nada de lo que las cambia pasó. Antes se
--     recalculaban todas cada vez y el tiempo crecía con el cuadrado de
--     los meses (5,7 s con 27 confirmadas, 8,5 s con 36);
--   · cada archivo (OFX, o el lote de Plaid, CSV o a mano) leído otra vez,
--     FILA POR FILA contra sus movimientos: cada movimiento del archivo es
--     lo que dice su fila (fecha, fecha de la compra, monto, tipo, cheque,
--     descripción, nota, id) y da su sello; y cada fila del archivo está
--     en un movimiento (el suyo, o el que ya estaba si era repetida). Lo
--     cambiado o BORRADO con las guardas apagadas sale aquí, con su fila;
--   · cada descriptor.
-- p_cuentas: solo esas cuentas (nulo: todas; las pruebas miran solo las
-- suyas).
--   select * from fn_banco_verificar();
--   select * from fn_banco_verificar(array['1010']);
-- (La versión anterior, sin cuentas, se quita.)
-- ---------------------------------------------------------------------
create index if not exists banco_historial_tabla_fecha_idx on public.banco_historial (tabla, cambiado_el);
drop function if exists public.fn_banco_verificar();
create or replace function public.fn_banco_verificar(p_cuentas text[] default null)
returns table (control text, ok boolean, detalle jsonb)
language plpgsql
set search_path = public, pg_temp
set jit = off
as $$
declare
  c        record;
  v_malos  jsonb := '[]'::jsonb;
  v_dif    jsonb;
  v_leido  jsonb;
  v_n      int;
  v_corte  date := fn_puente_corte();
  v_rec    uuid[];
  v_nconf  int;
  v_narch  int := 0;
  v_ajenas text[];
begin
  if not (es_dueno() or fn_desde_editor()) then
    raise exception using errcode = '42501', message = 'El banco lo revisa solo Edgar (el dueño), desde el SQL Editor.';
  end if;
  -- Las cuentas como las dice Edgar (la del plan o su código corto, '2013'),
  -- como el importador. Una que no es un banco ni una tarjeta de la empresa
  -- sale en rojo: antes se revisaba «nada» de ella y todo daba verde.
  if p_cuentas is not null then
    select coalesce(array_agg(x.c) filter (where fn_banco_tipo_cuenta(fn_banco_cuenta_resolver(x.c)) is null), '{}'),
           array_agg(distinct fn_banco_cuenta_resolver(x.c))
      into v_ajenas, p_cuentas
      from unnest(p_cuentas) as x(c);
    control := 'cuentas pedidas';
    ok := cardinality(v_ajenas) = 0;
    detalle := jsonb_build_object('cuentas', to_jsonb(p_cuentas),
                                  'no_son_de_la_empresa', to_jsonb(v_ajenas),
                                  'nota', case when not ok then 'Esas no son un banco ni una tarjeta de la empresa: de ellas no se '
                                                                 'revisa nada.' end);
    return next;
  end if;
  -- (los cuadres, pedidos por su nombre: sin contar las filas de las vistas,
  -- que aquí no se miran)
  return query
    select 'control · ' || x.vista, x.ok, to_jsonb(coalesce(x.detalle, 'bien'))
      from fn_banco_control('hoy', array['cuadre: un movimiento, un casado', 'cuadre: depósitos nunca a ingreso',
                                         'cuadre: archivos intactos', 'cuadre: ningún ticket después de clasificar',
                                         'cuadre: conciliaciones confirmadas', 'cuadre: préstamos', 'cuadre: prepagados']) x
     where x.vista like 'cuadre:%';

  -- Cada asiento que puso el banco, con su PAPEL (el movimiento, la nómina
  -- del proveedor anterior, la cuota, el mes de prepagados), de todos los
  -- meses: el libro no se borra y su papel tampoco. Si falta, se borró por
  -- fuera (con las guardas apagadas), quizá con su archivo entero: la
  -- relectura de los archivos de abajo solo ve los que siguen ahí.
  select coalesce(jsonb_agg(jsonb_build_object('asiento', a.numero, 'fecha', a.fecha_contable, 'papel', a.origen_tabla,
                                               'id', a.origen_id) order by a.cadena_pos), '[]'::jsonb)
    into v_malos
    from asientos a
   where a.origen_tabla in ('movimientos_banco', 'nomina_proveedor', 'prestamo_cuotas', 'prepagados')
     and case a.origen_tabla
           when 'prestamo_cuotas' then not exists (select 1 from prestamo_cuotas q where q.id::text = a.origen_id)
           when 'prepagados' then not exists (select 1 from prepagados_amortizaciones pa where pa.periodo = split_part(a.origen_id, '|', 1))
           else not exists (select 1 from movimientos_banco m where m.id::text = a.origen_id) end
     and (p_cuentas is null
          or exists (select 1 from asiento_lineas l where l.asiento_id = a.id and l.cuenta = any (p_cuentas)));
  control := 'asientos del banco con su papel';
  ok := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('sin_su_papel', v_malos,
                                'nota', case when not ok then 'El papel de esos asientos (y quizá su archivo) se borró por fuera de las '
                                                              'funciones del banco. El libro no se toca: se restaura desde el respaldo.' end);
  return next;
  v_malos := '[]'::jsonb;

  -- Las conciliaciones confirmadas que pudieron cambiar.
  select count(*) into v_nconf
    from conciliaciones cc where cc.estado = 'confirmada' and cc.tipo = 'normal' and (p_cuentas is null or cc.cuenta = any (p_cuentas));
  select coalesce(array_agg(cc.id), '{}') into v_rec
    from conciliaciones cc
   where cc.estado = 'confirmada' and cc.tipo = 'normal' and (p_cuentas is null or cc.cuenta = any (p_cuentas))
     and (exists (select 1 from asiento_lineas l join asientos a on a.id = l.asiento_id
                   where l.cuenta = cc.cuenta and a.fecha_contable <= cc.fecha_corte and a.creado_el > cc.confirmada_el)
          or exists (select 1 from banco_historial h
                      where h.tabla = 'movimientos_banco' and h.cambiado_el > cc.confirmada_el
                        and h.despues->>'cuenta' = cc.cuenta and (h.despues->>'fecha')::date <= cc.fecha_corte
                        and ((h.despues->>'estado') is distinct from (h.antes->>'estado')
                             or (h.despues->>'casado_id') is distinct from (h.antes->>'casado_id')))
          or exists (select 1 from movimientos_banco m
                      where m.cuenta = cc.cuenta and m.fecha between v_corte and cc.fecha_corte and m.importado_el > cc.confirmada_el));
  for c in select * from conciliaciones where id = any (v_rec) order by cuenta, fecha_corte loop
    with hoy as (select i.lado, i.asiento_id, i.orden, i.movimiento_id, i.apertura_partida_id, i.monto
                   from fn_conciliacion_items(c.cuenta, c.fecha_corte, false) i),
         antes as (select p.lado, p.asiento_id, p.orden, p.movimiento_id, p.apertura_partida_id, p.monto
                     from conciliacion_partidas p where p.conciliacion_id = c.id),
         d as ((select 'hoy_de_mas' as que, * from hoy except all select 'hoy_de_mas', * from antes)
               union all
               (select 'ya_no_esta', * from antes except all select 'ya_no_esta', * from hoy))
    select jsonb_agg(to_jsonb(d)) into v_dif from d;
    if v_dif is not null or fn_banco_saldo_libros(c.cuenta, c.fecha_corte) <> c.saldo_libros then
      v_malos := v_malos || jsonb_build_object('cuenta', c.cuenta, 'fecha_corte', c.fecha_corte, 'diferencias', v_dif,
                                               'saldo_libros_confirmado', c.saldo_libros,
                                               'saldo_libros_hoy', fn_banco_saldo_libros(c.cuenta, c.fecha_corte));
    end if;
  end loop;
  control := 'conciliaciones confirmadas, recalculadas';
  ok := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('confirmadas', v_nconf, 'recalculadas', cardinality(v_rec),
                                'sin_cambios_desde_confirmada', v_nconf - cardinality(v_rec), 'no_dan_lo_mismo', v_malos);
  return next;

  -- Cada archivo, leído otra vez, fila por fila contra sus movimientos.
  v_malos := '[]'::jsonb;
  for c in select a.id, a.cuenta, a.nombre, a.formato, a.texto, a.sha256, a.filas_leidas, a.filas_fuera from archivos_banco a
            where p_cuentas is null or a.cuenta = any (p_cuentas)
            order by a.importado_el loop
    v_narch := v_narch + 1;
    begin
      v_leido := case when c.formato in ('ofx_sgml', 'ofx_xml') then fn_banco_ofx_leer(c.texto)
                      else fn_banco_lote_filas(c.texto::jsonb, c.formato) end;
      v_n := jsonb_array_length(coalesce(v_leido->'filas', '[]'::jsonb));
      with f as (
        select coalesce((t.x->>'n')::int, t.o::int) as n, (t.x->>'fecha')::date as fecha,
               nullif(t.x->>'fecha_transaccion', '')::date as fu, (t.x->>'monto')::numeric as monto,
               upper(fn_banco_limpio(t.x->>'tipo')) as tipo, fn_banco_limpio(t.x->>'cheque') as cheque,
               fn_banco_limpio(t.x->>'descripcion') as descripcion, fn_banco_limpio(t.x->>'memo') as memo,
               fn_banco_norm(coalesce(fn_banco_limpio(t.x->>'descripcion'), fn_banco_limpio(t.x->>'memo'))) as dn,
               fn_banco_limpio(t.x->>'id') as ext
          from jsonb_array_elements(coalesce(v_leido->'filas', '[]'::jsonb)) with ordinality as t(x, o)),
      mv as (select m.* from movimientos_banco m where m.archivo_id = c.id),
      malos as (
        select jsonb_build_object('fila', mv.fila, 'movimiento', mv.id,
                                  'que', case when f.n is null then 'su fila no está en el archivo'
                                              when (mv.fecha, mv.fecha_transaccion, mv.monto, mv.tipo_banco, mv.cheque, mv.descripcion,
                                                    mv.memo, mv.id_externo)
                                                   is distinct from (f.fecha, f.fu, f.monto, f.tipo, f.cheque, f.descripcion, f.memo, f.ext)
                                              then format('no es lo que dice el archivo: el movimiento dice %s %s «%s»; el archivo, %s %s «%s»',
                                                          mv.fecha, mv.monto, coalesce(mv.descripcion, ''), f.fecha, f.monto,
                                                          coalesce(f.descripcion, ''))
                                              else 'no da su sello' end) as x
          from mv left join f on f.n = mv.fila
         where f.n is null
            or (mv.fecha, mv.fecha_transaccion, mv.monto, mv.tipo_banco, mv.cheque, mv.descripcion, mv.memo, mv.id_externo)
               is distinct from (f.fecha, f.fu, f.monto, f.tipo, f.cheque, f.descripcion, f.memo, f.ext)
            or mv.sello is distinct from fn_banco_sello(mv.cuenta, mv.ultimos4, mv.fecha, mv.fecha_transaccion, mv.monto, mv.tipo_banco,
                                                        mv.cheque, mv.descripcion, mv.memo, mv.origen, mv.id_externo, mv.llave,
                                                        mv.archivo_id, mv.fila, c.sha256)
        union all
        select jsonb_build_object('fila', f.n, 'que', 'la fila del archivo no está en ningún movimiento (¿se borró?)', 'fecha', f.fecha,
                                  'monto', f.monto, 'descripcion', f.descripcion)
          from f
         where not exists (select 1 from mv where mv.fila = f.n)
           and not exists (select 1 from movimientos_banco m
                            where m.cuenta = c.cuenta and m.monto = f.monto
                              and ((f.ext is not null
                                    and exists (select 1 from movimientos_banco_ids i
                                                 where i.cuenta = c.cuenta and i.id_externo = f.ext and i.movimiento_id = m.id))
                                   or (m.fecha = f.fecha and m.desc_norm = f.dn)
                                   or (f.cheque is not null and m.cheque is not null and ltrim(m.cheque, '0') = ltrim(f.cheque, '0')
                                       and abs(m.fecha - f.fecha) <= 5))))
      select jsonb_agg(x.x) into v_dif from (select malos.x from malos limit 10) x;
      if v_dif is not null or v_n <> c.filas_leidas - c.filas_fuera then
        v_malos := v_malos || jsonb_strip_nulls(jsonb_build_object('archivo', coalesce(c.nombre, c.id::text), 'cuenta', c.cuenta,
                                                                   'dice', c.filas_leidas - c.filas_fuera, 'lee_hoy', v_n,
                                                                   'filas', v_dif));
      end if;
    exception when others then
      v_malos := v_malos || jsonb_build_object('archivo', coalesce(c.nombre, c.id::text), 'cuenta', c.cuenta, 'error', sqlerrm);
    end;
  end loop;
  -- Y los archivos que el historial dice que entraron (su alta queda
  -- también fuera de su tabla) y ya no están: la relectura de arriba solo
  -- ve los que siguen ahí.
  select v_malos || coalesce(jsonb_agg(jsonb_build_object('archivo', coalesce(h.despues->>'nombre', h.clave),
                                                          'cuenta', h.despues->>'cuenta', 'entro_el', h.cambiado_el,
                                                          'error', 'entró (su alta está en el historial) y ya no está: se borró')
                                        order by h.cambiado_el), '[]'::jsonb)
    into v_malos
    from banco_historial h
   where h.tabla = 'archivos_banco' and h.operacion = 'INSERT'
     and (p_cuentas is null or h.despues->>'cuenta' = any (p_cuentas))
     and not exists (select 1 from archivos_banco a where a.id::text = h.clave);
  control := 'archivos, leídos otra vez fila por fila';
  ok := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('archivos', v_narch, 'no_dan_lo_mismo', v_malos);
  return next;

  -- Los descriptores: expresiones regulares válidas y con su cuenta activa.
  v_malos := '[]'::jsonb;
  for c in select * from banco_descriptores loop
    begin
      perform '' ~* c.patron;
      if c.cuenta is not null and fn_puente_cuenta_mal(c.cuenta) is not null then
        v_malos := v_malos || jsonb_build_object('clave', c.clave, 'cuenta', fn_puente_cuenta_mal(c.cuenta));
      end if;
    exception when others then
      v_malos := v_malos || jsonb_build_object('clave', c.clave, 'patron', c.patron, 'error', sqlerrm);
    end;
  end loop;
  control := 'descriptores';
  ok := jsonb_array_length(v_malos) = 0;
  detalle := jsonb_build_object('descriptores', (select count(*) from banco_descriptores), 'mal', v_malos);
  return next;
end $$;
revoke execute on function public.fn_banco_verificar(text[]) from public, anon, authenticated, service_role;
-- =====================================================================
-- 13 · Lo que un auditor lee en pg_description.
-- =====================================================================
comment on table public.banco_historial            is 'c6: el rastro de cada cambio del banco (casados, conciliaciones, préstamos, prepagados, descriptores, el estado de cada movimiento): quién, cuándo, antes y después. No se edita ni se borra.';
comment on table public.banco_descriptores         is 'c6: lo que el banco reconoce en la descripción de un movimiento (nómina, cargo del banco, interés, cajero, Zelle de Edgar, transferencia, pago de tarjeta, cheque devuelto). Se cambia con fn_banco_descriptor.';
comment on table public.archivos_banco             is 'c6: cada archivo del banco (OFX/QFX) o lote de filas (Plaid) que entró, ENTERO: su texto y su sha256. El respaldo permanente de lo que dijo el banco.';
comment on table public.movimientos_banco          is 'c6: un movimiento del banco o de la tarjeta, como lo dijo el banco (inmutable: MX003), con su estado (pendiente, casado, en_transito, ignorado) y su casado. Monto con el signo del libro en esa cuenta.';
comment on table public.movimientos_banco_ids      is 'c6: cada id con que un movimiento llegó (FITID del archivo, id de Plaid): el mismo movimiento por dos caminos entra una vez.';
comment on table public.banco_casados              is 'c6: cada casado de un movimiento con lo que lo explica en el libro (el ticket, el cobro, la transferencia, la cuota…), con su regla, quién y cuándo; y cada des-casado, con su motivo. Uno vivo por movimiento.';
comment on table public.banco_casado_lineas        is 'c6: las líneas del libro de cada casado. Una línea casa con un movimiento vivo.';
comment on table public.conciliaciones             is 'c6: la conciliación de una cuenta a su fecha de corte: libros = banco + en tránsito − solo en el banco. Se confirma con diferencia 0.00; confirmada no se toca (se reabre con su motivo).';
comment on table public.conciliacion_partidas      is 'c6: lo que no casa en cada conciliación (en libros y no en el banco, o al revés), con su clase, su motivo, su explicación y su clic; y dónde se resolvió después.';
comment on table public.prestamos                  is 'c6: cada préstamo (vehículo, línea de crédito): tasa, cuota, cuentas, saldo inicial y el descriptor de su pago. Se da de alta con fn_prestamo_guardar.';
comment on table public.prestamo_cuotas            is 'c6: cada cuota de un préstamo partida en capital e interés (fórmula o statement), con su asiento y su movimiento. Se anula des-casando, no se edita.';
comment on table public.prepagados                 is 'c6: cada póliza (seguro, fianza) pagada por adelantado y su cobertura. Se da de alta con fn_prepagado_guardar.';
comment on table public.prepagados_amortizaciones  is 'c6: lo amortizado de cada póliza en cada mes, con su asiento (uno por mes, estándar).';

comment on view public.v_papel_fases               is 'c6: el papel de los asientos del banco (movimiento, nómina del proveedor anterior, cuota, mes de prepagados), para v_asiento_papel de c4.';
comment on view public.v_banco_movimientos         is 'c6: cada movimiento con su estado, su regla, su asiento y su papel.';
comment on view public.v_banco_bandeja             is 'c6: lo pendiente, con su motivo, su propuesta en palabras y sus opciones (qué función llamar); y lo clasificado cuyo ticket llegó después (llego_su_ticket).';
comment on view public.v_banco_saldos              is 'c6: cada banco y tarjeta: saldo en libros, el último del banco, lo pendiente y su última conciliación.';
comment on view public.v_conciliacion              is 'c6: cada conciliación con su identidad, sus cifras y su estado.';
comment on view public.v_conciliacion_partidas     is 'c6: lo de cada conciliación en tres grupos (en libros y no en el banco, en el banco y no en libros, casado), con su explicación y su clic.';
comment on view public.v_prestamos                 is 'c6: cada préstamo: pagado, saldo, porción corriente y a largo plazo, y sus cuotas con su asiento.';
comment on view public.v_prepagados                is 'c6: cada póliza: lo de QuickBooks, lo amortizado, lo que falta, si va atrasada, y cada mes con su asiento.';

comment on function public.fn_banco_importar_ofx(text, text, text)  is 'c6: importa un archivo OFX/QFX (1.x SGML o 2.x XML, banco o tarjeta) entero; idempotente por sha256 y por FITID.';
comment on function public.fn_banco_importar_filas(jsonb)           is 'c6: importa filas ya leídas (Plaid: solo las posteadas), con el mismo contrato que un archivo.';
comment on function public.fn_banco_casar(uuid)                     is 'c6: casa un movimiento (reglas R1–R10: solo cruce exacto y reglas fijas son automáticos) o deja su propuesta.';
comment on function public.fn_banco_casar_todo(text, date)          is 'c6: casa todo lo pendiente (de una cuenta, desde una fecha) y deja la propuesta de lo que no casó.';
comment on function public.fn_banco_casar_con(uuid, jsonb, text)    is 'c6: Edgar elige con qué casa un movimiento (líneas, asiento, recibo, cobro, partida de la apertura o el otro lado de una transferencia); sobre un cargo clasificado cuyo ticket llegó, cambia la clasificación por el ticket.';
comment on function public.fn_banco_cobrar(uuid, jsonb, text)       is 'c6: un depósito sin cobro: registra el cobro de sus facturas (fn_cobro_registrar) con este movimiento; neto de la comisión de un procesador de tarjeta, el cobro por el bruto y la comisión a 6130. Nunca a ingreso.';
comment on function public.fn_banco_pagar_proveedor(uuid, uuid, jsonb) is 'c6: un pago a un proveedor: Dr 2010 por lo que se le debe (primero lo de QuickBooks, después sus partidas) / Cr el banco. Nunca a 5100.';
comment on function public.fn_banco_transferencia(uuid, text, text) is 'c6: dinero entre cuentas propias (pago de la tarjeta, la reserva): un asiento; el otro lado casa con él.';
comment on function public.fn_banco_clasificar(uuid, jsonb, text)   is 'c6: lo que no casó con nada, con sus líneas (Edgar dice de qué es). Primero casar: lo que ya está en el libro no se clasifica.';
comment on function public.fn_banco_ignorar(uuid, text)             is 'c6: lo que no es de la empresa, con su motivo.';
comment on function public.fn_banco_duplicado(uuid, boolean, text)  is 'c6: dice si un «posible duplicado» es el mismo movimiento que ya entró (se ignora) o no; y si el ticket que llegó después de clasificar un cargo es el suyo.';
comment on function public.fn_banco_devolver(uuid, uuid, text)      is 'c6: un cheque devuelto: la devolución del cobro (fn_cobro_devolver) con este movimiento; el de un depósito de varios (la aplicación que rebotó): el cobro se devuelve y lo demás se registra otra vez ese día.';
comment on function public.fn_banco_descasar(uuid, text)            is 'c6: deshace un casado con su motivo (reversa su asiento si lo puso él) y el movimiento vuelve a la bandeja.';
comment on function public.fn_conciliar(text, date, text)           is 'c6: la conciliación de una cuenta a su fecha de corte, con sus partidas y su diferencia.';
comment on function public.fn_conciliacion_partida(uuid, text, text) is 'c6: la clase y el motivo de una partida en tránsito.';
comment on function public.fn_conciliacion_confirmar(uuid)          is 'c6: confirma una conciliación con diferencia 0.00 y nada del banco sin su línea.';
comment on function public.fn_conciliacion_reabrir(uuid, text)      is 'c6: reabre una conciliación confirmada, con su motivo (queda el rastro).';
comment on function public.fn_conciliacion_apertura(text, text, jsonb, text) is 'c6: la conciliación de la era QuickBooks al 30-sep, con las partidas en tránsito de entonces.';
comment on function public.fn_prestamo_cuota(uuid, uuid, date, text, text, text, text) is 'c6: la cuota de un préstamo partida en capital e interés (fórmula o statement), posteada y casada con su movimiento.';
comment on function public.fn_prepagados_amortizar(text)            is 'c6: el asiento estándar de amortización de prepagados de un mes (por días, por acumulado, idempotente).';
comment on function public.fn_banco_control(text, text[])           is 'c6: lo que conta.js lee antes de pintar el banco: filas de cada vista contra las que dicen las tablas, los cuadres y las protecciones. ok = false no se pinta. p_vistas: las vistas de la pantalla (nulo, todas), o un cuadre suelto por su nombre.';
comment on function public.fn_banco_verificar(text[])               is 'c6: la revisión entera del banco desde el SQL Editor: las conciliaciones confirmadas que pudieron cambiar, recalculadas, y cada archivo releído fila por fila.';
comment on function public.fn_prestamo_guardar(jsonb)               is 'c6: alta o cambio de un préstamo (SQL Editor).';
comment on function public.fn_prepagado_guardar(jsonb)              is 'c6: alta o cambio de una póliza pagada por adelantado (SQL Editor); la de antes del corte dice su saldo_corte (lo que dejó QuickBooks); la que corrige a otra ya amortizada, «sustituye»; la cancelada, su fecha y lo devuelto.';
comment on function public.fn_conciliacion_anular(uuid, text)       is 'c6: quita una conciliación ABIERTA hecha por error (la fecha mal escrita), con su motivo y su rastro (SQL Editor).';
comment on function public.fn_banco_nomina(uuid, jsonb, text)       is 'c6: el journal de la nómina del proveedor anterior (antes de f11), casado con su débito del banco (SQL Editor).';
comment on function public.fn_banco_descriptor(text, text, text, text) is 'c6: cambia lo que se reconoce en la descripción de un movimiento (SQL Editor).';
comment on function public.fn_banco_version()                       is 'c6: la marca de esta versión del banco (AAAAMMDDNN).';


-- =====================================================================
-- 14 · Los sellos. Lo ÚLTIMO, con todo puesto: las huellas del banco, y
-- las del libro (c2 vigila por nombre las funciones de este archivo que
-- llama la app: se resellan con lo que este pegado dejó).
-- =====================================================================
do $$
begin
  perform public.fn_banco_huellas_sellar();
  perform public.fn_libro_huellas_sellar('c6-banco.sql');
end $$;


-- =====================================================================
-- Lo que enseña el SQL Editor al terminar: lo que este archivo dejó
-- puesto, y el control del banco con lo que mira siempre (sus
-- protecciones y que c2, c3 y c4 estén al día). CORTO a propósito, como el
-- de c4: las cifras de cada mes las controla la app (fn_banco_control con
-- la lista de su pantalla), o a mano:
--   select * from fn_banco_control('2026-10');
--   select * from fn_banco_verificar();
-- =====================================================================
select 'c6 · ' || x.que as control, x.ok, to_jsonb(x.detalle) as detalle
  from (values
    ('tablas', (select count(*) = 13 from pg_class c
                 where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity
                   and c.relname in ('banco_historial', 'banco_descriptores', 'archivos_banco', 'movimientos_banco',
                                     'movimientos_banco_ids', 'banco_casados', 'banco_casado_lineas', 'conciliaciones',
                                     'conciliacion_partidas', 'prestamos', 'prestamo_cuotas', 'prepagados',
                                     'prepagados_amortizaciones')
                   and (select count(*) from pg_policy po where po.polrelid = c.oid) = 1),
     '13 tablas, con la RLS encendida y solo su policy de lectura del dueño'),
    ('vistas', (select count(*) = 8 from pg_class v
                 where v.relnamespace = 'public'::regnamespace and v.relkind = 'v'
                   and 'security_invoker=true' = any (coalesce(v.reloptions, '{}'))
                   and v.relname in ('v_papel_fases', 'v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion',
                                     'v_conciliacion_partidas', 'v_prestamos', 'v_prepagados')),
     '8 vistas, todas security_invoker, solo SELECT para authenticated'),
    ('funciones de la app', (select count(*) = 21 from pg_proc p
                              where p.pronamespace = 'public'::regnamespace
                                and has_function_privilege('authenticated', p.oid, 'execute')
                                and not has_function_privilege('anon', p.oid, 'execute')
                                and (p.proname like 'fn\_banco\_%' or p.proname like 'fn\_conciliacion\_%' or p.proname = 'fn_conciliar'
                                     or p.proname like 'fn\_prestamo\_%' or p.proname like 'fn\_prepagado%')),
     '21 funciones que llama conta.js (anon ninguna); el resto, sin grant a la API'),
    ('en el reparto de c2', not exists (select 1 from pg_proc p
                                          where p.pronamespace = 'public'::regnamespace and p.prosecdef
                                            and has_function_privilege('authenticated', p.oid, 'execute')
                                            and (p.proname like 'fn\_banco\_%' or p.proname like 'fn\_conciliacion\_%'
                                                 or p.proname = 'fn_conciliar' or p.proname like 'fn\_prestamo\_%'
                                                 or p.proname like 'fn\_prepagado%')
                                            and position(quote_literal(replace(p.oid::regprocedure::text, ' ', ''))
                                                         in (select pp.prosrc from pg_proc pp
                                                              where pp.oid = to_regprocedure('public.fn_verificar_cadena()'))) = 0),
     'las SECURITY DEFINER que llama la app están en el reparto de c2 (c_fn_app_fases): su control permisos las conoce')
  ) as x(que, ok, detalle)
union all
select 'banco · ' || c.vista, c.ok,
       to_jsonb(coalesce(c.detalle, case when c.filas is null then 'bien' else format('%s filas', c.filas) end))
  from public.fn_banco_control('hoy', array['v_banco_saldos']) c;
