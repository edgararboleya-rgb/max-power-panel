-- =====================================================================
-- c10-costo-obra.sql — EL JORNAL REPARTIDO POR HORAS Y EL COSTO POR OBRA
-- (ESTIMADO CONTRA REAL) · c10 (la Fase 9; f09 lo llama «c9-costo-obra.sql»
-- por un nombre viejo: c9 ya es el cierre).
-- 9-nov-2026; v2 del 10-nov-2026 (los arreglos de las dos revisiones, antes
-- de pegarlo en producción: al final de esta cabecera, «LO QUE CAMBIÓ EN LA
-- v2»); v3 del 13-nov-2026 (la Fase 11b: las horas que ya pagó una nómina
-- tienen pago real y no van, además, a estándar: «LO QUE CAMBIÓ EN LA v3»,
-- al final de esta cabecera). Se pega en el SQL Editor DESPUÉS de c1, c2,
-- c3, c4 y c6 (c7, s1, p1, c8 y c9 pueden faltar: lo que no está no se
-- mira, y se dice; la nómina, c15, se pega DESPUÉS de este archivo y es
-- opcional: si está, se le pregunta al vuelo qué horas pagó). Idempotente:
-- se puede volver a pegar entero (no pisa la configuración, ni una persona
-- dada de alta, ni un reparto). Después se pega c10-pruebas.sql.
--
-- Qué hace. DOS PIEZAS:
--   (A) EL JORNAL. En 2026 no hay nómina: los ayudantes cobran por Zelle
--       desde la cuenta de la empresa, y esos Zelle esperaban en la Bandeja
--       porque una propuesta de la IA (c8) lleva UNA obra y 5200
--       Subcontratos exige obra. Un Zelle a un ayudante no es de una obra:
--       es su semana, repartida entre las obras donde estuvo. Desde aquí,
--       el pago a una persona dada de alta (jornal_personas: «el Zelle a
--       esta persona se reparte por sus horas», reconocido por un patrón
--       contra la descripción del banco) entra al libro como N líneas de su
--       cuenta (5200), cada una con su obra y su CO si las horas lo llevan,
--       y con la persona en la línea (tercero empleado = su perfil), para
--       que el 1099 de f12a sume solo. La clave del reparto son SUS HORAS
--       del período; el pago NO es horas × tarifa (sale entre 19 y 27 $/h,
--       a veces más: un fijo semanal, dos semanas juntas, horas mal
--       reportadas): las horas solo dicen a qué obra va cada dólar.
--         · EL NÚCLEO (fn_jornal_repartir: persona, período, monto → las
--           partes por obra y CO, al centavo, y el detalle por reporte de
--           horas) no sabe nada del banco ni del Zelle: no escribe nada, y
--           es el que f11 alimentará en enero con el journal real de Gusto
--           (5000/5010) sin rehacerlo. Lo del Zelle (reconocer el pago,
--           elegir la semana, aprobar las horas, postear por el banco) va
--           aparte, encima: fn_jornal_propuesta, fn_jornal_aplicar,
--           fn_jornal_deshacer.
--         · EL PERÍODO POR DEFECTO sale del día del pago, porque así paga
--           Edgar (deducido de sus pagos reales): el lunes —a veces el
--           martes— paga la semana anterior; el jueves o el viernes, la
--           semana en curso. Regla: pago de lunes a miércoles → la semana
--           anterior (de lunes a domingo); pago de jueves a domingo → la
--           semana en curso (de lunes a domingo). «Desde el pago anterior»
--           NO sirve: hay semanas sin Zelle (pagadas por otro lado) y pagos
--           que cubren dos. El período se ve SIEMPRE y Edgar lo cambia
--           antes de aceptar (semana anterior / esta semana / fechas a
--           mano, hasta 62 días): fn_jornal_propuesta trae las dos semanas
--           con sus horas para que elija de un toque.
--         · EL «ASÍ ES» DE EDGAR ES LA APROBACIÓN DE LAS HORAS QUE VIO. El
--           plan (§1, §3) dice que la clave del reparto son las horas
--           APROBADAS y que el papel del asiento es el reporte de horas
--           aprobado; en producción ninguna hora está aprobada (c3 trae
--           fn_horas_aprobar y nunca se usó). fn_jornal_propuesta devuelve
--           «visto»: la huella de EXACTAMENTE lo que el «Así es» reparte y
--           aprueba: cada reporte que entra y cada reporte de esas fechas
--           que está sin aprobar, entre o no (c3 aprueba por persona y
--           fechas, y pide esa lista entera: «aprueba»), con su fecha, obra,
--           CO, fase y horas; y el movimiento, la persona, las fechas, el
--           monto y las cuentas. fn_jornal_aplicar, en UNA transacción: toma
--           las horas de esa persona en esas fechas (nadie las cambia
--           mientras), vuelve a calcular, y si la huella ya no es la que
--           Edgar vio para con MX011 y no cambia NADA; si es la misma,
--           aprueba esos reportes por el camino de c3 (fn_horas_aprobar, con
--           los ids que vio: queda en horas_aprobaciones), postea por el
--           camino del banco y guarda el reparto con su detalle. Del estado
--           financiero al asiento, del asiento al reparto, del reparto a
--           cada reporte de horas aprobado. (Un reporte que no entra —ya lo
--           cubre otro pago— y que perdió su aprobación porque le cambiaron
--           las horas se aprueba también, y Edgar lo ve antes: el aviso
--           cubiertas_sin_aprobar; si cambia entre que mira y toca, MX011.)
--         · EL CAMINO AL LIBRO ES EL DEL BANCO (c6): fn_banco_clasificar,
--           la misma puerta por la que Edgar clasifica cualquier cargo de
--           la Bandeja, llamada por él (fn_jornal_aplicar es SECURITY
--           INVOKER: corre con su sesión). Comprobado en el banco de
--           pruebas antes de construir encima: c6 no limita el número de
--           líneas (las 5 son de las propuestas de c8, por las que este
--           camino NO pasa: una semana toca hasta 7 obras), admite el
--           tercero empleado (perfiles.id), rechaza 50xx, 6000 y 6005 (la
--           mano de obra de nómina y el sueldo entran solo por su journal)
--           y deja el movimiento casado con su asiento (camino puente,
--           origen movimientos_banco). Todos sus frenos siguen valiendo: lo
--           que «puede casar con algo» que ya está en el libro (un ticket,
--           un cheque del mismo monto, una partida de la apertura, un pago a
--           un proveedor con partidas) no entra sin el motivo escrito de
--           Edgar, y aquí tampoco: fn_jornal_aplicar llama a c6 SIN motivo
--           (así ningún freno se salta) y el mensaje de c6 sale tal cual; si
--           de verdad es otra cosa, Edgar lo dice en p_opciones.motivo, que
--           es el motivo de c6. Un movimiento de un mes ya cerrado entra
--           como c6 mete todo lo que llega tarde: el primer día del mes
--           abierto, con su nota (la propuesta lo avisa antes). Deshacer es
--           fn_banco_descasar: el asiento se REVERSA (no se borra), el
--           movimiento vuelve a la Bandeja y el reparto queda marcado con
--           su motivo; dentro de una conciliación confirmada c6 pide
--           reabrirla antes, y lo dice.
--         · LA OBRA TERMINADA O CANCELADA recibe su parte: el trabajo se
--           hizo ahí. Ni c2 ni c6 piden que la obra esté activa para
--           postear a ella (solo que exista); eso lo exige c8 a las
--           propuestas de la IA, que adivinan la obra. Aquí la obra no se
--           adivina: la dicen las horas. Se avisa («está terminada: su
--           parte va a esa obra igual») y entra.
--         · LAS HORAS SIN OBRA no pueden ir a 5200 (exige obra): van a la
--           cuenta que Edgar fije UNA vez (jornal_config.cuenta_sin_obra,
--           vacía al principio: la propuesta lo dice, no deja aplicar y la
--           pantalla la pide; o se les pone su obra en Horas y entran como
--           las demás). Una cuenta de costo o de gasto que no exija obra,
--           que no sea de nómina (50xx) ni sueldo (6000, 6005).
--         · LAS HORAS YA CUBIERTAS POR OTRO PAGO no entran otra vez: si
--           parte de las horas de esas fechas ya está en un reparto vivo,
--           este reparte solo por las que faltan y lo dice (cuál). Si es
--           OTRO PAGO DE LA MISMA SEMANA (un adelanto el jueves y el resto
--           el lunes), Edgar lo pide con p_opciones.incluir_cubiertas y el
--           pago se reparte también por ellas; queda escrito en el reparto,
--           y el control distingue lo que Edgar aceptó de lo que no.
--         · LAS HORAS QUE LLEGAN TARDE a una semana ya repartida (se
--           reportaron o se les cambió la fecha después del «Así es») no
--           recibieron nada de ese pago: sigue repartido entre las demás
--           obras, y ellas salen a estándar. Nadie lo veía (el control solo
--           miraba las horas que sí entraron). Ahora se dice en tres sitios
--           (fn_jornal_tardias): el control del jornal (el 35), la obra
--           (v_margen_obra.avisos) y la propuesta del pago siguiente de esa
--           persona (aviso horas_tardias, con las fechas que las cogerían).
--           Se arregla deshaciendo aquel reparto y repitiéndolo, o metiéndolas
--           en el pago que las cubra (fechas a mano). Siguen a estándar
--           mientras tanto: no tienen pago real repartido, y si Edgar las
--           paga con el Zelle siguiente es que de verdad estaban sin pagar.
--         · EL PAGO DE UNA PERSONA DADA DE ALTA RESUELTO POR OTRO CAMINO
--           (clasificado a mano en la Bandeja, o aprobada la propuesta de la
--           IA) no deja rastro en el jornal: su costo queda entero donde se
--           clasificó —sin su nombre: el 1099 por tercero no lo suma— y sus
--           horas de esas semanas salen, además, a estándar. Se dice
--           (fn_jornal_fuera): el control (el 70, un aviso) y las obras con
--           horas suyas sin pago en la semana del pago o en la anterior. Si
--           de verdad era otra cosa, el aviso se va cuando esas horas tengan
--           su pago.
--         · EL CO Y LA FASE de las horas van LIMPIOS COMO LOS DEJA c6 al
--           postear (fn_jornal_limpio: sin espacios, tabuladores ni saltos
--           de línea en las puntas; la regla de fn_banco_limpio) en el
--           núcleo, la propuesta, la huella, el margen y el control. Con
--           btrim a secas, un CO con un salto de línea detrás (un pegado, el
--           conector) era otro grupo, c6 lo limpiaba al postear y el asiento
--           «no era el reparto»: el pago no se podía repartir. Si aun así el
--           asiento de c6 no fuera el reparto, el error dice qué línea, qué
--           campo y qué hacer. El CO sigue siendo texto libre: «co #1» y
--           «CO #1» son dos líneas, y la propuesta lo avisa (co_parecidos).
--         · EL RECONOCIMIENTO ES POR PATRÓN, y un patrón no sabe qué clase
--           de movimiento mira: la compra en un comercio cuyo nombre lleva
--           el de alguien casa igual que su Zelle. No se frena (un banco
--           puede describir un pago de otra forma); se dice: el aviso
--           no_parece_pago en la propuesta, y al dar de alta, si el patrón
--           no lleva el nombre de pila del perfil o casa con pagos que el
--           banco describe a nombre de varios (fn_jornal_persona.avisos). Y
--           un patrón que casaría con un Zelle a cualquiera no entra.
--         · LA «TARIFA QUE SALE» (pago ÷ horas del período) se enseña junto
--           a la de costos_equipo; si se aleja más de aviso_tarifa_pct (25 %
--           de fábrica) es un AVISO en llano («revisa las fechas»), nunca
--           un freno.
--   (B) EL MARGEN: el costo por obra y el estimado contra real, DESDE EL
--       LIBRO. v_margen_obra (una fila por obra) y fn_margen_obra (una
--       obra, con su detalle):
--         · EL REAL es lo que el libro tiene con esa obra, sin corte de
--           fecha: material (5100), mano de obra real, subcontratos (el
--           resto de 5200), equipo (5300) y lo demás de costo; y el ingreso
--           (40xx). El libro empieza el día después de la apertura (30-sep-
--           2026): lo de antes está en QuickBooks. Una obra que ya andaba
--           entonces (saldo en la apertura; facturas, tickets, trabajos
--           externos u horas de antes) sale con parcial = true y se dice en
--           llano, como hace v_costo_por_obra de c4. No se copia a c4: se
--           leen las mismas tablas con su misma regla (las cuentas de tipo
--           costo e ingreso con obra), y v_margen_control comprueba, obra
--           por obra y al centavo, que el costo de aquí ES el de «Estados»
--           (v_costo_por_obra) y el del mayor: no hay dos números de costo
--           por obra en la app.
--         · LA MANO DE OBRA DICE SI ES REAL O ESTÁNDAR. Real = lo pagado y
--           repartido: las líneas de los jornales (por su asiento, vayan a
--           la cuenta que vayan) y la nómina (50xx con obra: 5000, 5001,
--           5010; c15, desde enero de 2027). Estándar = las horas de esa
--           obra que NO tienen pago real (ni un pago repartido por horas ni
--           una nómina que las pagara: v3) × costos_equipo.costo_hora ×
--           (1 + burden_estandar_pct), por reporte y al centavo, con la
--           etiqueta «estándar, no real»: NUNCA se postea desde aquí.
--           Si falta el burden (UNA sola tasa, la fija Edgar; 0 si no
--           aplica) o la tarifa de alguien, sale vacía con su porqué, sin
--           inventar. Las horas de antes del libro no van a estándar (su
--           costo está en QuickBooks) y LAS DEL DUEÑO van aparte
--           (horas_dueno, mano_obra_dueno): no cobra por hora; su parte de
--           obra entrará por la nómina (5001, f11), como decide c3 con el
--           devengo. No suman en costo_con_estandar.
--         · EL ESTIMADO sale de las MISMAS fuentes que la app ya enseña
--           (para que no haya dos «estimados»): las horas de
--           proyectos.horas_estimadas, el material de
--           finanzas_proyecto.presupuesto_materiales, el contrato de
--           finanzas_proyecto.contrato, y la tarifa de mano de obra
--           round((foreman × pct_foreman + journeyman × pct_journeyman +
--           helper × pct_helper) × (1 + benefits), 2) del escenario. Y lo
--           que pide f09: si la obra tiene un estimado enlazado
--           (estimados.proyecto_id; el «convertido», o el más reciente), el
--           escenario es el suyo (estimados.escenario) y los beneficios
--           coalesce(estimados.benefits_pct, escenarios.benefits); si no,
--           el escenario B. escenarios.benefits_detalle NUNCA es costo
--           real: es lo que se le cotiza al cliente, y aquí no se lee.
--         · UN ESTIMADO PARCIAL NO SE COMPARA CON UN REAL COMPLETO. El
--           costo estimado es mano de obra (horas × tarifa) más material; a
--           muchas obras les falta una de las dos mitades (las horas
--           estimadas o el presupuesto de material). Si la mitad que falta
--           ya tiene real en la obra —o hay horas estimadas y no hay con qué
--           valorarlas—, no hay total que comparar: costo_estimado, el
--           margen estimado y la diferencia salen vacíos, estimado_completo
--           es falso y estimado_falta dice qué falta, en llano. Lo que
--           falta y todavía no tiene real no estorba. Concepto por concepto
--           se sigue comparando lo que sí está estimado. (Antes la mitad que
--           faltaba sumaba 0, y la obra salía «se pasa» o «dentro» contra un
--           real que sí la traía.)
--         · POR CO (la base aparte de cada CO), POR FASE (horas y dólares
--           de mano de obra) y POR COST CODE: solo lo que las líneas
--           llevan. Hoy ninguna línea del libro trae cost code: se dice en
--           llano («todavía no hay nada capturado con código») y no se
--           inventa. El estimado de cada CO vive en alcances (f10): si su
--           referencia es la del CO se enseña su monto; si no, nada.
--         · Cada número del real trae su «bajar» (la llave de c4: los
--           pedazos de v_libro que lo suman), para llegar a sus asientos.
--
-- LA REGLA DE REDONDEO (fn_jornal_repartir_ids; determinista, sin flotantes):
--   el monto se parte en centavos por MAYORES RESTOS. Con C centavos, H
--   horas en total y h horas en un grupo (obra + CO; lo sin obra es un
--   grupo): a cada grupo le toca la parte entera de C × h / H; los
--   centavos que sobran (siempre menos que grupos) van de uno en uno a los
--   grupos con mayor resto. A resto igual, primero el grupo con más horas;
--   a horas iguales, por obra (su id, en orden) y CO (sin CO primero); lo
--   sin obra, el último. Todo en numeric exacto (div y resta, nunca una
--   división con decimales). La suma de los grupos ES el monto. Después,
--   dentro de cada grupo, sus centavos se parten igual entre sus reportes
--   de horas (a resto igual: más horas, fecha, número de reporte): la suma
--   de los reportes de un grupo es su monto, y la de todos, el pago. Un
--   grupo al que no le llega ni un centavo no lleva línea en el libro (c2 no
--   admite líneas en cero) y queda en el detalle con 0.00. El orden de las
--   líneas en el asiento: la del banco primero (la pone c6), después cada
--   obra por su id y CO, y lo sin obra al final.
--
-- LA SEGURIDAD (la regla de c2, B.20, y lo que c6, c4, c8 y c9 sellan):
--   · NINGUNA función de aquí es SECURITY DEFINER. Las que llama la
--     pantalla (fn_jornal_propuesta, fn_jornal_aplicar, fn_jornal_deshacer,
--     fn_jornal_config, fn_jornal_persona, fn_jornal_repartir,
--     fn_margen_obra) son SECURITY INVOKER, sin EXECUTE para public, anon
--     ni service_role, con EXECUTE para authenticated y es_dueno() por
--     dentro (fn_jornal_exigir_dueno): leen con la policy de cada tabla
--     (solo el dueño) y escriben con la policy de escritura del dueño de
--     las tablas de c10; al libro y al banco entran por las funciones que
--     c3 y c6 ya dan al dueño (fn_horas_aprobar, fn_banco_clasificar,
--     fn_banco_descasar). Así «permisos» de c2 y «protecciones del banco»
--     de c6 siguen en verde. Las auxiliares que usan las vistas no frenan a
--     nadie con un error: leen con RLS, y a quien no es el dueño no le
--     devuelven nada (el equipo no lee nada de c10: lleva dinero y lo que
--     cobra cada compañero).
--   · fn_jornal_pegado y fn_jornal_precondiciones: sin API (solo el SQL
--     Editor).
--   · Las tablas nacen con RLS y policies solo-dueño (leer, y escribir en
--     las que escribe una función INVOKER), y con la guarda de c6 y c9: un
--     trigger (fn_jornal_guarda) que solo deja escribir con la marca de la
--     transacción (mx_jornal.escribe = la tabla) que ponen las funciones
--     de aquí: un insert o un update a mano por PostgREST, aunque sea del
--     dueño, da MX003. Un reparto y su detalle solo se añaden; lo único que
--     cambia en un reparto es que pasa a «deshecho», una vez, con su motivo.
--   · Las vistas son security_invoker y leen solo TABLAS (nunca una vista
--     de c3, c4, c6, p1, c8 o c9, que se rehacen al volver a pegar su
--     archivo) y funciones de aquí; de periodos y de cuentas no nombran
--     estado, cadena_al_cerrar, activa ni saldo_normal (c2-pruebas las
--     reescribe a propósito: se leen de la fila entera).
--   · Nada lleva un prefijo que otra capa sella (fn_banco_%, fn_puente_%,
--     fn_estados_%, fn_stripe_%, fn_plaid_%, fn_contador_%, fn_cierre_%)
--     ni de la otra sesión que escribe esta base (fn_costos_%, fn_reporte_%,
--     fn_reparto_fase%, fn_horas_%): aquí todo es fn_jornal_% / jornal_% /
--     v_jornal_% y fn_margen_% / v_margen_%. es_dueno() no se toca. Y c10
--     no depende de ningún objeto de esa otra sesión (v_estimado_vs_real_
--     obra, horas_tareas, costos_revision…): se instala y funciona sin ellos.
--   · Lo que la pantalla escribe pasa por PostgREST con la sesión del
--     dueño: s1 (el código del teléfono) exige aal2 en cada petición si el
--     dueño tiene factor; la pantalla pide el código como en el resto de
--     la contabilidad. Esta capa no añade nada a eso.
--
-- LOS ERRORES CON NOMBRE (conta.js los traduce mirando el código):
--   MX000  falta algo que este archivo da por hecho (precondición): no se
--          aplica nada (fn_jornal_precondiciones dice qué)
--   MX003  las tablas de c10 solo las escriben sus funciones (la guarda); un
--          reparto y su detalle no se editan ni se borran
--   MX004  una cuenta que no sirve para esto (la del jornal, la de lo sin
--          obra): no existe, inactiva, de grupo, de nómina, o exige/prohíbe
--          obra al revés
--   MX005  un monto mal: el del núcleo (nulo, cero, negativo o con más de
--          dos decimales), el burden o el umbral de la tarifa
--   MX001  (además del de c2 y c6) el asiento que dejó c6 no es el reparto
--          que se le pidió: dice qué línea, qué campo —lo que quedó y lo que
--          se pidió— y qué hacer; no se guarda nada. Es una red: con el CO
--          y la fase limpios como c6 no debe verse
--   MX008  no procede: el movimiento no es un pago reconocido, ya está
--          resuelto, es un posible duplicado sin decidir, no hay horas en
--          esas fechas, falta la cuenta de lo sin obra, el reparto ya
--          estaba deshecho, el patrón ya es de otra persona; y los MX008 de
--          c6 y de c3, que salen tal cual
--   MX011  NUEVO (los MX000–MX010 ya estaban tomados): LAS HORAS YA NO SON
--          LAS QUE VISTE. La huella que manda la pantalla no es la de las
--          horas de hoy (alguien reportó, cambió o borró horas, o cambió una
--          cuenta, entre que Edgar miró y que tocó): no se aprueba ni se
--          postea nada; se vuelve a pedir la propuesta
--   22023  entrada mal formada: falta un dato, las fechas al revés o de más
--          de 62 días, una clave desconocida, un patrón que no es una
--          expresión válida o que casaría con cualquier pago
--   42501  permiso: solo el dueño; anon y service_role, nada
--   55P03  (de Postgres, «lock timeout») la app estaba usando las tablas de
--          c10 mientras se pegaba este archivo: no se aplicó nada, se vuelve
--          a pegar (con la pantalla de Contabilidad cerrada)
--   Y los de c2, c3 y c6 que salen tal cual al aprobar, postear o deshacer
--   (MX001, MX002, MX004, MX006, MX007, MX008), con su mensaje en llano.
--
-- Decisiones de diseño (lo que f09 y el encargo dejaban abierto):
--   · EL TERCERO DE LA LÍNEA es tercero_tipo = 'empleado', tercero_id = su
--     perfil (perfiles.id), que es lo que c2 admite para una persona de la
--     cuadrilla (proveedor es proveedores.id: el supply, el sub). Un
--     ayudante que cobra por Zelle con horas en la app ES un perfil: no se
--     da de alta dos veces. El 1099 de f12a sumará por tercero empleado en
--     las cuentas con etiqueta 1099 (5200) más lo sin obra del mismo
--     reparto (jornal_repartos lo dice entero, por persona y año).
--   · LA APROBACIÓN AL DESHACER SE QUEDA. Lo que Edgar aprobó son las
--     horas (las vio y dijo «así es»); deshacer un reparto dice que el
--     PAGO se repartió mal (otra semana, otra persona), no que las horas
--     fueran mentira. Además c3 solo sabe retirar aprobaciones por fechas
--     (fn_horas_desaprobar), no por reporte: retirarlas aquí se llevaría
--     las de otros repartos de esas mismas fechas. Si unas horas estaban
--     mal, se corrigen en Horas (la corrección tumba su aprobación sola,
--     c3) o se retira su aprobación con fn_horas_desaprobar; el control lo
--     ve si eran de un reparto vivo.
--   · UNA HORA, UN PAGO, salvo que Edgar diga otra cosa (arriba). Y un
--     movimiento, un reparto vivo (índice único).
--   · QUÉ ES «CON PAGO REAL»: la hora que está en el detalle de un reparto
--     aplicado o, desde la v3, la que pagó una nómina posteada y viva (c15
--     lo dice con su marca sin dinero: qué reporte de horas pagó qué
--     corrida, y nada más; se lee al vuelo, y sin c15 no hay ninguna).
--   · EL DEVENGO ESTÁNDAR DE c3 (fn_horas_devengar, opcional: Dr 5000 / Cr
--     2210 a fin de mes, por las horas aprobadas × su tarifa; se deshace
--     solo el día 1 del mes siguiente) es para lo trabajado y TODAVÍA NO
--     PAGADO. Con jornales, doble es solo esto: una hora que está en el
--     documento de un devengo vivo y, a la vez, en un jornal que entró al
--     libro DENTRO del mes de ese devengo (o antes): ese mes la lleva dos
--     veces, y el siguiente de menos. Un jornal que entra después —el Zelle
--     del lunes 2-nov por la última semana de octubre, con octubre
--     devengado— no choca: octubre lleva el devengo, y noviembre su reverso
--     y el pago real. El control 50 y el aviso devengo_estandar miran eso (la
--     misma hora, y la fecha del asiento del jornal contra el fin de mes del
--     devengo); lo que ya no tiene arreglo —un mes cerrado— se dice y no
--     deja el cuadre en rojo. c3 todavía no aparta del devengo las horas ya
--     pagadas con jornales (está sellado): por eso, en un mes cuyos jornales
--     ya entraron, el devengo cuenta de más y hay que retirarlo antes de
--     cerrar. En v_margen_obra el devengo no cuenta como real: se anula solo
--     con su reverso del día 1.
--   · LA FECHA DEL ASIENTO ES LA DEL PAGO (la que trae el banco; con su mes
--     cerrado, el primer día del mes abierto: la regla de c6 para todo). El
--     libro de 2026 va, en esto, por lo pagado, como QuickBooks: la semana
--     del 26-oct pagada el 2-nov deja su costo en noviembre, y la última de
--     diciembre pagada el 4-ene, en 2027. No se cambia aquí (es cómo c6
--     fecha todo lo del banco, y un jornal con otra fecha que su movimiento
--     no casaría con él); se DICE antes de aceptar: los avisos otro_mes y
--     otro_anio, con cuántas horas, cuánto y dónde cae. Si el CPA quiere el
--     costo de diciembre en su año, tiene el devengo de c3 (que ya no choca
--     con el pago de enero) o su ajuste de fin de año.
--   · LA RUTINA DE LA IA (c8) sigue proponiendo para estos Zelle (no sabe
--     de c10, y c8 está sellado): la Bandeja pinta la tarjeta de «mano de
--     obra» con v_jornal_pendientes en vez de la propuesta de la IA. c8 no
--     cierra sola la propuesta de un movimiento que se resuelve por fuera, y
--     c10 no puede escribir en c8 (sus funciones son de la función de borde
--     «contador»). Lo que un jornal deja abierto en c8:
--       - la propuesta PENDIENTE del movimiento: ya no se puede aprobar (el
--         movimiento queda casado); a los 7 días enciende la alarma 71 de c8
--         (un aviso) y, el día que la obra que proponía se termina, su
--         cuadre 64, que el cierre de c9 toma por «detiene»;
--       - la APROBADA O EDITADA cuyo asiento se reversó (Edgar la aceptó y
--         después des-casó el pago para repartirlo por horas): deja en rojo
--         el cuadre 60 de c8 («detiene» en c9). Por el camino de c8 se
--         habría cerrado sola; por este, no.
--     Lo que hace c10: fn_jornal_propuesta y fn_jornal_aplicar devuelven las
--     dos clases (propuesta_ia, la pendiente, como siempre; y propuestas_ia,
--     todas, con qué hacer con cada una: rechazar o caducar) para que la
--     PANTALLA las cierre por la función de borde; fn_jornal_ia() da en
--     cualquier momento las que siguen abiertas en pagos ya repartidos (para
--     reintentarlo); y el control del jornal las enseña (el 80, un aviso)
--     con qué hacer. No se frena el «Así es» por una propuesta pendiente: la
--     rutina propone para TODO lo pendiente dos veces al día, así que casi
--     todo pago la tendría, y repartir dependería de que la función de borde
--     conteste. Aplicar o deshacer un jornal no pone en rojo ningún cuadre
--     de c6, c4 ni c9; de c8, los dos de arriba si la pantalla no cierra lo
--     que se le devuelve.
--   · EL ESTÁNDAR SE CALCULA CON LA TARIFA Y EL BURDEN DE HOY: costos_equipo
--     guarda una tarifa por persona, sin historia, y es de la app. Si la
--     tarifa de alguien cambia, cambia el estándar de todas sus horas sin
--     pago, también las de obras ya terminadas. Es una estimación para
--     comparar («estándar, no real»), nunca un asiento; se dice en su nota.
--     Lo que tiene pago real repartido no se mueve.
--   · EN «ESTADOS» (c4) LOS JORNALES SALEN COMO «SUBCONTRATOS»: van a la
--     5200 (contract labor, como en QuickBooks, con su etiqueta 1099), y c4
--     —sellado— no sabe del jornal. Aquí salen aparte, como mano de obra
--     real. El total por obra es el mismo (v_margen_control, el 60, lo
--     comprueba y lo dice); la etiqueta, no.
--   · UN PAGO SE REPARTE ENTERO POR HORAS. Si un Zelle lleva además otra
--     cosa (un reembolso de material), hoy va entero por horas —a la cuenta
--     del jornal, y a la base del 1099— o entero por la Bandeja, a mano. No
--     hay forma de apartar una parte: queda para cuando haga falta (una
--     opción «aparte» de fn_jornal_aplicar con sus líneas, que irían detrás
--     de las del jornal en el mismo asiento). Mientras, lo honesto es que
--     el reembolso vaya en otro Zelle.
--   · UN REPARTO QUE QUEDÓ SUELTO. Si Edgar des-casa en la Bandeja (c6) un
--     pago ya repartido, c6 reversa el asiento y el reparto sigue «aplicado»
--     sin asiento vivo: c6 no sabe del jornal, y está sellado. El control lo
--     pone en rojo (el 20) y dice qué hacer; la propuesta de ese pago trae
--     el aviso reparto_suelto (con el reparto) y no deja repartir encima; y
--     fn_jornal_deshacer lo cierra sin tocar el libro otra vez (por_fuera).
--     La pantalla ofrece «Deshacer» ahí mismo.
--
-- EL VOLUMEN Y LA CONCURRENCIA (medido en el banco, PG17, como el dueño por
-- la API, con RLS):
--   · Con 200 obras, 5.000 reportes de horas, 7.500 asientos (17.600 líneas)
--     y 20 repartos (la v2, con sus avisos nuevos): fn_jornal_propuesta
--     14 ms; v_jornal_pendientes 45 ms; v_margen_obra entera 280 ms;
--     fn_margen_obra de una obra 80 ms; v_jornal_control 36 ms;
--     v_margen_control 450 ms (lee v_costo_por_obra de c4). Y con un año de
--     banco encima (6.000 cargos ya resueltos, 40 de ellos descritos como
--     el pago de alguien dado de alta): v_margen_obra 340 ms, fn_margen_obra
--     125 ms y v_jornal_control 85 ms (fn_jornal_fuera arma el texto de cada
--     cargo resuelto una vez y lo prueba contra el patrón de cada persona
--     activa: crece con los cargos del banco, no con el libro). Nada
--     cuadrático: las líneas de los jornales y las horas pagadas se buscan
--     por sus índices (contra un CTE el planificador comparaba cada línea
--     del libro con cada parte), los perfiles y las tarifas se leen una vez
--     (la policy de costos_equipo llama a es_dueno() por cada fila leída), y
--     el cálculo de un pago se hace una vez por fila de v_jornal_pendientes.
--   · Dos «Así es» a la vez sobre el mismo pago, dos pagos de la misma
--     semana a la vez, un reporte de horas que llega mientras Edgar acepta,
--     dos «Deshacer» a la vez, dos altas a la vez y volver a pegar con la
--     pantalla leyendo: pruebas/conta/c10-concurrencia.sh (uno entra; el
--     otro, MX008 o MX011, limpio; el pegado, 55P03 o entra).
--
-- EL CAMINO DE VUELTA AL ESTIMADOR (f09: «se diseña aquí, se construye en
-- f18»). Solo diseño:
--   · QUÉ CORRIGE QUÉ. (1) Horas por partida: el estimador multiplica
--     cantidad × horas de cada receta; lo real son horas por obra, CO y
--     fase (hoy) y por tarea (horas_tareas, de la otra sesión: código de
--     partida y cantidad hecha por reporte). La corrección es el cociente
--     horas reales ÷ horas estimadas de la partida, obra cerrada por obra
--     cerrada, y se propone como factor por código de partida y tipo de
--     obra cuando lo sostienen al menos tres obras cerradas y no parciales.
--     (2) Tarifa real con burden: de v_margen_obra sale el costo real por
--     hora pagada (mano_obra_real ÷ horas_con_pago_real) por obra y por
--     persona; contra la tarifa del escenario (la de arriba) da el ajuste
--     de foreman/journeyman/helper y, con el journal de f11 (5010 real),
--     el de «benefits». Hasta f11 solo corrige la tarifa base: el burden de
--     2026 es una tasa estándar, no un dato. (3) Desperdicio de material:
--     material_real (5100) ÷ material_presupuesto por obra cerrada, y por
--     cost code cuando los tickets lo lleven: corrige misc_pct y la merma.
--   · QUÉ FALTA CAPTURAR. El cost code en la línea del libro (hoy ninguna:
--     el ticket no lo trae; f10 lo pone al facturar por partidas, y la
--     Bandeja puede pedirlo al clasificar material); la tarea de cada hora
--     (horas_tareas ya la captura: f18 la lee, c10 no depende de ella); el
--     estimado enlazado a cada obra (estimados.proyecto_id: hoy muchas
--     obras no lo tienen y caen al escenario B) y el estimado de cada CO
--     (alcances, f10); y obras CERRADAS ENTERAS en el libro: las que
--     empezaron antes del 30-sep son parciales y no corrigen nada.
--   · CÓMO VUELVE. f18 construye una tabla de propuestas de corrección al
--     estimador (parámetro, valor de hoy, valor que saldría, las obras que
--     lo sostienen con su «bajar») que Edgar aprueba de una en una: como la
--     IA contable, propone y nunca cambia sola. Entran solo obras
--     completadas, no parciales, con toda su mano de obra real (sin horas a
--     estándar) y con v_margen_control en verde.
--
-- Lo que este archivo NO toca: c1..c9, s1, p1, es_dueno(), docs/sql, el
-- libro (solo entra por fn_banco_clasificar y fn_banco_descasar, como el
-- dueño), las tablas de la app (lee horas, proyectos, perfiles,
-- costos_equipo, finanzas_proyecto, escenarios, estimados, alcances,
-- facturas, recibos, trabajos_externos; las horas se aprueban por
-- fn_horas_aprobar). No pone índices, triggers ni llaves en las tablas de
-- la app.
--
-- Cómo se instala (Edgar, en este orden, con la cadena pegada como dice
-- pruebas/conta/README.md):
--   1. SQL Editor → pegar ESTE archivo entero → Run. Al final sale una
--      tabla: la configuración, las tablas y las vistas, las personas dadas
--      de alta, cuántos pagos reconoce hoy, QUÉ FALTA (las personas con
--      horas sin dar de alta, la cuenta de lo sin obra, el burden
--      estándar), el control y el paso siguiente. Si algo de lo que da por
--      hecho falta, para con MX000 y no queda nada. Con la pantalla de
--      Contabilidad cerrada: si alguien la está leyendo en ese momento, para
--      con 55P03 («lock timeout»), no queda nada y basta volver a pegarlo.
--   2. SQL Editor → volver a pegar docs/conta/c9-cierre.sql (el del 10-nov:
--      su revisión trae las filas 170 y 171, que miran los controles de
--      este archivo; es idempotente). Sin este paso el cierre no mira los
--      repartos, y la prueba 61 sale «omitida» diciéndolo.
--   3. SQL Editor → pegar docs/conta/c10-pruebas.sql → sus filas, todas en
--      true (las «omitida» dicen por qué; no es un fallo).
--   4. En la app: Contabilidad → Bandeja. En el Zelle de un ayudante,
--      «Es mano de obra: repartir por sus horas» lo da de alta (una vez por
--      persona); desde entonces sus pagos salen con la semana, las obras y
--      lo que le toca a cada una, y «Así es» los mete al libro.
--   Para fijar el burden estándar: select fn_jornal_config('{"burden_estandar_pct": 0}');
--   (0 si a los ayudantes de 2026 no se les carga nada encima de su tarifa).
--   La cuenta de lo sin obra: select fn_jornal_config('{"cuenta_sin_obra": "…"}');
--
-- Lo que llama la pantalla (RPC, como el dueño; las que escriben, con POST):
--   fn_jornal_propuesta(p_movimiento uuid, p_desde date, p_hasta date, p_opciones jsonb)   solo lee
--   fn_jornal_aplicar(p_movimiento uuid, p_desde date, p_hasta date, p_visto text, p_opciones jsonb)
--   fn_jornal_deshacer(p_reparto uuid, p_motivo text)
--   fn_jornal_persona(p jsonb) / fn_jornal_config(p jsonb)
--   fn_jornal_repartir(p_usuario uuid, p_desde date, p_hasta date, p_monto numeric,
--                      p_solo_aprobadas boolean)                                          el núcleo (f11)
--   fn_margen_obra(p_proyecto text)                                                       el detalle de una obra
--   fn_jornal_ia(p_movimiento uuid)       solo lee: lo de la IA (c8) que un pago repartido deja abierto
-- Y lee: v_jornal_pendientes, v_jornal_repartos, v_jornal_personas,
-- v_jornal_control, v_margen_obra, v_margen_control, jornal_config.
-- Montos en dólares, numeric(14,2); horas, numeric tal cual se reportan.
--
-- LO QUE CAMBIÓ EN LA v2 (10-nov-2026; nada renombrado: columnas, claves y
-- avisos de más):
--   · v_margen_obra: estimado_completo y estimado_falta; costo_estimado,
--     margen_estimado, margen_estimado_pct y diferencia salen VACÍOS cuando
--     el estimado no da un total que comparar (antes sumaban 0 por lo que
--     faltaba). fn_margen_obra: el concepto «total» trae estimado_completo y
--     nota.
--   · fn_jornal_propuesta / fn_jornal_aplicar: «aprueba» {reportes, ids} (lo
--     que el «Así es» aprueba: la huella lo cubre entero), «propuestas_ia»
--     (lo de c8 que queda abierto, con que_hacer), movimiento.fecha_asiento;
--     avisos nuevos: horas_tardias, cubiertas_sin_aprobar, no_parece_pago,
--     co_parecidos, otro_mes, otro_anio; devengo_estandar solo cuando de
--     verdad es doble; obra_terminada dice «no aprobada» (no «cancelada»).
--   · v_jornal_control: tres avisos más (35 horas tardías, 70 pagos resueltos
--     fuera del jornal, 80 propuestas de la IA abiertas), el 50 con su regla
--     nueva, y ningún detalle nombra ya una función o una vista.
--   · fn_jornal_persona devuelve avisos; fn_jornal_config no admite para lo
--     sin obra una cuenta con etiqueta fiscal propia ni las que alimenta
--     otra parte del libro; fn_jornal_repartir tiene p_solo_aprobadas.
--
-- LO QUE CAMBIÓ EN LA v3 (13-nov-2026, la Fase 11b: la nómina de c15; nada
-- renombrado, ninguna tabla ni columna nueva, ningún dato se toca al volver
-- a pegar: la configuración, las personas y los repartos quedan como están):
--   · LAS HORAS QUE PAGÓ UNA NÓMINA TIENEN PAGO REAL. Desde enero de 2027 la
--     gente de obra cobra por nómina (c15): su costo entra al libro con el
--     journal, por sus horas (5000, 5001 y 5010 con su obra). El margen leía
--     bien ese dinero (mano_obra_nomina), pero seguía contando sus HORAS
--     como «a estándar»: solo reconocía como pago real el reparto de un
--     Zelle. Con el burden estándar fijado, esa mano de obra salía dos veces
--     en costo_con_estandar (medido en el banco: una obra con 2,336.25 de
--     nómina en el libro y 18 h suyas a estándar daba 2,826.25 con el burden
--     en 0). Desde aquí, la hora que pagó una nómina posteada y viva es
--     «pago real»: fn_margen_horas_nomina() la pregunta al vuelo a la marca
--     sin dinero de c15 (qué reporte de horas pagó qué corrida y su día de
--     pago; ni un importe ni un nombre). c15 se pega después y es opcional:
--     sin ella no hay ninguna, y todo queda como en la v2.
--   · LO MISMO EN TODO LO QUE DICE «SIN PAGO» O «A ESTÁNDAR»: las horas
--     tardías (fn_jornal_tardias, el control 35), los pagos resueltos por
--     fuera (fn_jornal_fuera, el control 70), los pagos sin repartir de una
--     obra (pagos_sin_repartir), las horas sin pago de cada persona
--     (v_jornal_personas) y las «sin pago» de cada semana en la propuesta.
--     Una hora que pagó una nómina no sale en ninguno. Y el texto de la obra
--     dice «N h van a estándar (sin pago real: ni un pago repartido por
--     horas ni una nómina)».
--   · A QUIEN YA COBRA POR NÓMINA NO SE LE PIDE DARSE DE ALTA EN EL JORNAL.
--     v_jornal_personas trae una columna más, al final: horas_nomina_90_dias
--     (las de los últimos 90 días que pagó una nómina). El «qué falta» del
--     pegado («dar de alta a quien cobra por sus horas…») deja de nombrar a
--     quien las tiene: no cobra por Zelle. La pantalla, con esa columna,
--     puede decir «cobra por nómina» en vez de «sin dar de alta».
--   · EL DETALLE DE UNA OBRA (fn_margen_obra), sin inventar: lo que le tocó a
--     cada hora de una nómina es el sueldo de una persona y vive en la
--     nómina, con el código del teléfono; aquí no se lee. Su dinero sale
--     donde el libro lo tiene (por concepto, por cuenta y por CO). Por fase y
--     por persona se dice cuántas horas son de nómina (horas_nomina) y lo
--     repartido de los pagos por horas (mano_obra_jornales, pagado_jornales);
--     mano_obra_real (por fase) y pagado (por persona) salen VACÍOS, con su
--     nota, cuando hay horas de nómina: ya no son el total. Y trae «nominas»:
--     las que pagaron horas de la obra (día de pago, reportes y horas).
--   · UN AVISO NUEVO EN LA PROPUESTA DE UN PAGO, pagadas_por_nomina: el Zelle
--     a alguien que ya cobra por nómina se reconoce igual por su patrón, y
--     repartido por sus horas las contaría otra vez. Se dice antes de
--     aceptar; no frena, y NO cambia qué horas entran en un reparto (eso
--     sigue como en la v2: una hora ya cubierta por otro REPARTO no entra;
--     una que pagó una nómina, entra y se avisa).
--   · UN CUADRE MÁS EN EL CONTROL DEL MARGEN, el 70: «las horas que pagó una
--     nómina cuentan como pago real». Verde sin la nómina en la base, y con
--     ella cuando su marca se deja leer (dice cuántas horas). Si la nómina
--     de la base es la de antes del 13-nov (no trae la marca) o no se deja
--     leer: verde con qué pegar mientras no haya ninguna nómina en el libro;
--     EN ROJO desde que la hay (sus horas saldrían a estándar). El final del
--     pegado lo dice también en «qué falta».
--   · AGUANTA AÑOS DE HORAS. La lista de las horas que pagó una nómina se
--     lee una vez por consulta y cada reporte se busca en ella en una tabla
--     hash (como expresión, «h.id in (select …)», nunca como cruce: con las
--     policies de horas la base cree que sale un solo reporte y, cruzando,
--     recorría la lista entera por cada uno). Medido en el banco como el
--     dueño por la API, con 40,000 reportes y 30,000 pagados por nómina: el
--     costo por obra 1.7 s (1.6 s en la v2) y el control del margen 3.1 s
--     (3.0 s); con el cruce, 63 s (el tope de la API son 8). El renglón 70
--     no da otra pasada por las horas: cuenta en la misma del 50. Lo vigila
--     pruebas/conta/c10-volumen.sh.
--   · LA SEGURIDAD NO CAMBIA: ninguna función de aquí es SECURITY DEFINER
--     (tampoco la nueva); c10 no lee ni un importe de la nómina.
--   · LA DE ANTES (lo que NO se arregla aquí): el reparto de un Zelle sigue
--     sin apartar las horas que pagó una nómina (solo avisa); y quien ya
--     estaba dado de alta en el jornal y pasa a nómina sigue dado de alta
--     (su Zelle se reconocería por su patrón): conviene darlo de baja
--     (fn_jornal_persona, activa = false). Una hora en un reparto aplicado
--     que además pagó una nómina no la nombra ningún control: se avisa
--     antes de aceptar el reparto, no después.
-- =====================================================================
-- (Lo primero, como en c4 y c6: el pegado espera un candado como mucho
-- medio segundo. Con la app leyendo o repartiendo, para con 55P03 («lock
-- timeout»), no se aplica nada y se vuelve a pegar; sin esto, Postgres
-- podía cortar a la app o al pegado con 40P01. Menos que deadlock_timeout,
-- 1 s. Dura lo que dura el pegado, una transacción.)
set local lock_timeout = '500ms';


-- ---------------------------------------------------------------------
-- 0. Las guardas, y lo que este archivo da por hecho (MX000 sin tocar nada)
-- ---------------------------------------------------------------------
-- Lo que falta para pegar c10, en llano (nulo = nada). La usan la
-- precondición de abajo y las pruebas.
create or replace function public.fn_jornal_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
  v_v     bigint;
  c_tablas constant text[] := array['jornal_config', 'jornal_personas', 'jornal_repartos', 'jornal_reparto_lineas',
                                    'jornal_reparto_horas'];
  c_vistas constant text[] := array['v_jornal_pendientes', 'v_jornal_repartos', 'v_jornal_personas', 'v_jornal_control',
                                    'v_margen_obra', 'v_margen_control'];
  c_fn     constant text[] := array['fn_jornal_exigir_dueno', 'fn_jornal_ve', 'fn_jornal_precondiciones', 'fn_jornal_guarda',
                                    'fn_jornal_usd', 'fn_jornal_h', 'fn_jornal_dia', 'fn_jornal_rango', 'fn_jornal_mes', 'fn_jornal_texto',
                                    'fn_jornal_limpio', 'fn_jornal_patron_mal', 'fn_jornal_destinatario', 'fn_jornal_patron_sugerido',
                                    'fn_jornal_cuenta_mal',
                                    'fn_jornal_periodo', 'fn_jornal_regla', 'fn_jornal_repartir_ids', 'fn_jornal_repartir',
                                    'fn_jornal_tardias', 'fn_jornal_fuera', 'fn_jornal_ia',
                                    'fn_jornal_opciones', 'fn_jornal_calcular', 'fn_jornal_propuesta', 'fn_jornal_aplicar',
                                    'fn_jornal_deshacer', 'fn_jornal_config', 'fn_jornal_persona', 'fn_jornal_pegado',
                                    'fn_margen_libro_desde', 'fn_margen_horas_nomina', 'fn_margen_lineas', 'fn_margen_horas',
                                    'fn_margen_estimado', 'fn_margen_obras', 'fn_margen_bajar', 'fn_margen_obra', 'fn_margen_control'];
begin
  foreach v_x in array array['es_dueno()', 'fn_desde_editor()', 'fn_fecha_miami(timestamptz)', 'fn_verificar_cadena()',
                             'fn_libro_version()', 'fn_horas_aprobar(uuid,date,date,jsonb)',
                             'fn_horas_desaprobar(uuid,date,date,text)', 'fn_banco_clasificar(uuid,jsonb,text)',
                             'fn_banco_descasar(uuid,text)', 'fn_banco_control(text,text[])',
                             'fn_estados_control(text,text[])'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'periodos', 'asientos', 'asiento_lineas', 'perfiles', 'proyectos', 'horas',
                             'costos_equipo', 'finanzas_proyecto', 'escenarios', 'estimados', 'alcances', 'codigos_partida',
                             'facturas', 'recibos', 'trabajos_externos', 'horas_aprobaciones', 'movimientos_banco',
                             'banco_casados', 'v_libro'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if cardinality(v_falta) > 0 then
    return format('c10 se pega después de c1, c2, c3, c4 y c6 (y de c7, s1, p1, c8 y c9 si se usan), con las tablas de la app: '
                  'falta %s.', array_to_string(v_falta, ', '));
  end if;
  -- La versión de c2 que va con esta capa (la del tiempo en producción).
  execute 'select public.fn_libro_version()' into v_v;
  if coalesce(v_v, 0) < 2026100201 then
    return format('el c2-libro.sql pegado es anterior (marca %s; esta capa pide 2026100201): vuelve a pegar c2-libro.sql.', v_v);
  end if;
  -- Las columnas de la app que esta capa lee por su nombre.
  select string_agg(x.t || '.' || x.c, ', ' order by x.t, x.c) into v_x
    from (values ('horas', 'aprobado_el'), ('horas', 'co'), ('horas', 'fase'), ('horas', 'usuario_id'), ('horas', 'proyecto_id'),
                 ('horas', 'fecha'), ('horas', 'horas'),
                 ('perfiles', 'nombre'), ('perfiles', 'rol'), ('perfiles', 'activo'),
                 ('proyectos', 'nombre'), ('proyectos', 'tipo'), ('proyectos', 'estado'), ('proyectos', 'cliente'),
                 ('proyectos', 'horas_estimadas'), ('proyectos', 'horas_reales_base'),
                 ('costos_equipo', 'costo_hora'), ('finanzas_proyecto', 'contrato'),
                 ('finanzas_proyecto', 'presupuesto_materiales'),
                 ('escenarios', 'foreman'), ('escenarios', 'journeyman'), ('escenarios', 'helper'), ('escenarios', 'pct_foreman'),
                 ('escenarios', 'pct_journeyman'), ('escenarios', 'pct_helper'), ('escenarios', 'benefits'),
                 ('estimados', 'proyecto_id'), ('estimados', 'escenario'), ('estimados', 'benefits_pct'), ('estimados', 'estado'),
                 ('estimados', 'creado'),
                 ('alcances', 'proyecto_id'), ('alcances', 'ref'), ('alcances', 'titulo'), ('alcances', 'monto'),
                 ('codigos_partida', 'nombre'), ('facturas', 'fecha'), ('recibos', 'fecha'), ('trabajos_externos', 'fecha'),
                 ('movimientos_banco', 'desc_norm'), ('movimientos_banco', 'memo'), ('movimientos_banco', 'posible_duplicado_de'),
                 ('asiento_lineas', 'tercero_id'), ('asiento_lineas', 'orden'), ('asientos', 'procedencia'),
                 ('cuentas', 'tipo'), ('cuentas', 'regla_obra'), ('cuentas', 'imputable'), ('cuentas', 'etiqueta_fiscal')) as x(t, c)
   where not exists (select 1 from information_schema.columns k
                      where k.table_schema = 'public' and k.table_name = x.t and k.column_name = x.c);
  if v_x is not null then
    return format('faltan columnas que esta capa lee: %s. ¿Es la base de la app, con c3 y c6 pegados?', v_x);
  end if;
  -- La cuenta de fábrica del jornal (5200, subcontratos: por obra, etiqueta 1099).
  if not exists (select 1 from cuentas k where k.codigo = '5200') then
    return 'falta la 5200 (Subcontratos) en el plan de cuentas (c1): vuelve a pegar c1-plan-de-cuentas.sql.';
  end if;
  -- Una tabla con el nombre de las de c10 que no sea de c10: se para antes de
  -- tocar nada (la lección de c8 con ia_propuestas).
  foreach v_x in array array['jornal_config:burden_estandar_pct', 'jornal_personas:patron', 'jornal_repartos:regla_periodo',
                             'jornal_reparto_lineas:reparto_id', 'jornal_reparto_horas:horas_id'] loop
    if to_regclass('public.' || split_part(v_x, ':', 1)) is not null
       and not exists (select 1 from information_schema.columns
                        where table_schema = 'public' and table_name = split_part(v_x, ':', 1) and column_name = split_part(v_x, ':', 2)) then
      return format('la tabla %s ya existe en esta base y no es la de c10 (no tiene la columna %s): otra cosa usa ese nombre. No la '
                    'toco; avisa antes de seguir.', split_part(v_x, ':', 1), split_part(v_x, ':', 2));
    end if;
  end loop;
  -- Una vista o una función con nombre de c10 que no sea de c10 (otra sesión
  -- escribe esta misma base): «create or replace» la pisaría sin avisar.
  select string_agg(x.que, ', ' order by x.que) into v_x
    from (select 'la vista ' || c.relname as que
            from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind in ('v', 'm', 'r') and c.relname = any (c_vistas)
             and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c10: %'
          union all
          select 'la función ' || p.oid::regprocedure::text
            from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.proname = any (c_fn)
             and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c10: %') x;
  if v_x is not null then
    return format('ya hay en esta base, con nombre de c10 y sin ser de c10: %s. No lo piso; avisa antes de seguir.', v_x);
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: el jornal lo reparte el dueño.';
  end if;
  -- Nada ajeno colgado de las vistas de c10 (se borran y se rehacen).
  select string_agg(distinct format('la vista %s', dc.oid::regclass), ', ') into v_x
    from pg_depend d
    join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
    join pg_class dc on dc.oid = rw.ev_class
    join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
   where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname = any (c_vistas)
     and dc.oid <> cv.oid
     and not (dc.relnamespace = 'public'::regnamespace and dc.relname = any (c_vistas));
  if v_x is not null then
    return format('%s depende(n) de las vistas de c10, que al pegarlo se borran y se rehacen: guarda su definición, bórralas, '
                  'pega c10 y vuelve a crearlas.', v_x);
  end if;
  return null;
end $$;
revoke execute on function public.fn_jornal_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_jornal_precondiciones() is 'c10: lo que falta para pegar c10-costo-obra.sql (nulo = nada): c1, c2 (marca 2026100201), c3, c4 y c6, las tablas y columnas de la app que lee, la 5200, el SQL Editor, un dueño activo, nada ajeno con nombre de c10 y nada ajeno sobre sus vistas.';

do $$
declare
  v text;
begin
  v := public.fn_jornal_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c10-costo-obra NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1, c2, c3, c4, c6, c7, s1, p1, c8, c9 y después este archivo (pruebas/conta/README.md, §0).';
  end if;
end $$;

-- ¿Quién llama por la API? Solo el dueño. Desde el SQL Editor (current_user
-- no es un rol de la API) pasa. Solo es_dueno(), como c4, c6 y c9:
-- fn_desde_editor no es ejecutable por authenticated.
create or replace function public.fn_jornal_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if current_user in ('authenticated', 'anon') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501',
      message = 'El reparto de la mano de obra y el costo por obra los ve y los toca solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_jornal_exigir_dueno() from public, anon, service_role;
grant  execute on function public.fn_jornal_exigir_dueno() to authenticated;
comment on function public.fn_jornal_exigir_dueno() is 'c10: la guarda de lo que llama la pantalla: por la API solo el dueño (es_dueno); el SQL Editor pasa.';

-- ¿Ve quien mira? Lo mismo, sin error: las auxiliares de las vistas no
-- frenan a nadie; a quien no es el dueño no le devuelven nada.
create or replace function public.fn_jornal_ve() returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select current_user not in ('authenticated', 'anon', 'service_role') or coalesce(es_dueno(), false)
$$;
revoke execute on function public.fn_jornal_ve() from public, anon, service_role;
grant  execute on function public.fn_jornal_ve() to authenticated;
comment on function public.fn_jornal_ve() is 'c10: verdadero para el dueño por la API y para el SQL Editor; las auxiliares de las vistas no devuelven nada a los demás.';


-- ---------------------------------------------------------------------
-- 1. Las tablas (nacen cerradas: solo el dueño lee; escribe solo el dueño
--    por las funciones de aquí, con la marca de la transacción). Montos en
--    dólares, numeric(14,2); horas, numeric. Llaves foráneas a cuentas,
--    perfiles, movimientos_banco, asientos y entre tablas de c10; a horas y
--    a proyectos NO (son de la app: no se les cuelga nada que cambie cómo
--    se borran; lo que cambie después lo ve el control). Para crecer, «add
--    column if not exists».
-- ---------------------------------------------------------------------
-- La configuración: una sola fila. cuenta_defecto es la del jornal (5200);
-- cuenta_sin_obra nace vacía (la fija Edgar una vez); burden_estandar_pct
-- nace vacío (UNA tasa, en %, para el costo estándar; 0 si no aplica);
-- aviso_tarifa_pct, cuánto puede alejarse la tarifa que sale de la de
-- costos_equipo antes de avisar.
create table if not exists public.jornal_config (
  id                   int          primary key,
  cuenta_defecto       text         not null default '5200' references public.cuentas (codigo),
  cuenta_sin_obra      text         references public.cuentas (codigo),
  burden_estandar_pct  numeric(5,2),
  aviso_tarifa_pct     numeric(5,2) not null default 25,
  actualizado          timestamptz  not null default now(),
  actualizado_por      uuid,
  constraint jornal_config_una    check (id = 1),
  constraint jornal_config_burden check (burden_estandar_pct is null or burden_estandar_pct between 0 and 100),
  constraint jornal_config_aviso  check (aviso_tarifa_pct between 0 and 500)
);
comment on table public.jornal_config is 'c10: la configuración del jornal y del costo por obra (una fila): la cuenta de las líneas con obra (cuenta_defecto, 5200), la de las horas sin obra (cuenta_sin_obra; vacía hasta que Edgar la fije), el burden estándar en % (burden_estandar_pct: UNA tasa para el costo estándar de las horas sin pago real; vacío hasta que Edgar lo fije, 0 si no aplica) y cuánto puede alejarse la tarifa que sale de un pago de la de costos_equipo antes de avisar (aviso_tarifa_pct, 25). Se cambia con fn_jornal_config.';

-- Las personas cuyo pago se reparte por sus horas: «el Zelle a esta persona
-- es su jornal». patron: una expresión regular (sin distinguir mayúsculas)
-- que se prueba contra la descripción normalizada del banco (desc_norm, y
-- la nota). cuenta: la de sus líneas con obra (vacía = la de fábrica).
create table if not exists public.jornal_personas (
  usuario_id       uuid        primary key references public.perfiles (id) on delete cascade,
  patron           text        not null,
  cuenta           text        references public.cuentas (codigo),
  activa           boolean     not null default true,
  nota             text,
  creado_el        timestamptz not null default now(),
  creado_por       uuid,
  actualizado_el   timestamptz not null default now(),
  actualizado_por  uuid,
  constraint jornal_personas_patron check (btrim(patron) <> '' and length(patron) <= 200)
);
create unique index if not exists jornal_personas_patron_unico on public.jornal_personas (lower(btrim(patron))) where activa;
comment on table public.jornal_personas is 'c10: las personas de la cuadrilla cuyo pago (el Zelle) se reparte por sus horas: su perfil (usuario_id), cómo se reconoce su pago en la descripción del banco (patron: una expresión regular, sin distinguir mayúsculas, contra movimientos_banco.desc_norm y su nota), la cuenta de sus líneas con obra (cuenta; vacía = jornal_config.cuenta_defecto), si está activa, y quién y cuándo la dio de alta y la cambió. Sin persona dada de alta, nada se reconoce solo. Se escribe con fn_jornal_persona (la baja es lógica: activa = false).';

-- Cada reparto: un pago (un movimiento del banco) de una persona, repartido
-- por sus horas de un período. Solo se añade; lo único que cambia es que
-- pasa a «deshecho» (una vez, con su motivo y el reverso que puso c6).
create table if not exists public.jornal_repartos (
  id               uuid          primary key default gen_random_uuid(),
  movimiento_id    uuid          not null references public.movimientos_banco (id),
  usuario_id       uuid          not null references public.perfiles (id),
  desde            date          not null,
  hasta            date          not null,
  regla_periodo    text          not null,
  monto            numeric(14,2) not null,
  horas            numeric       not null,
  tarifa_sale      numeric(10,2) not null,
  tarifa_equipo    numeric,
  cuenta           text          not null references public.cuentas (codigo),
  cuenta_sin_obra  text          references public.cuentas (codigo),
  asiento_id       uuid          not null references public.asientos (id),
  estado           text          not null default 'aplicado',
  huella           text          not null,
  avisos           jsonb         not null default '[]'::jsonb,
  opciones         jsonb         not null default '{}'::jsonb,
  horas_aprobadas  jsonb         not null default '[]'::jsonb,
  creado_el        timestamptz   not null default now(),
  creado_por       uuid,
  deshecho_el      timestamptz,
  deshecho_por     uuid,
  deshecho_motivo  text,
  reverso_id       uuid          references public.asientos (id),
  constraint jornal_repartos_fechas  check (desde <= hasta and hasta - desde <= 61),
  constraint jornal_repartos_regla   check (regla_periodo in ('semana_anterior', 'semana_en_curso', 'a_mano')),
  constraint jornal_repartos_monto   check (monto > 0),
  constraint jornal_repartos_horas   check (horas > 0),
  constraint jornal_repartos_estado  check (estado in ('aplicado', 'deshecho')),
  constraint jornal_repartos_deshecho check ((estado = 'deshecho') = (deshecho_el is not null and coalesce(btrim(deshecho_motivo), '') <> '')),
  constraint jornal_repartos_avisos  check (jsonb_typeof(avisos) = 'array' and jsonb_typeof(opciones) = 'object'
                                            and jsonb_typeof(horas_aprobadas) = 'array')
);
-- (un movimiento, un reparto VIVO; los deshechos quedan como rastro)
create unique index if not exists jornal_repartos_movimiento_vivo on public.jornal_repartos (movimiento_id) where estado = 'aplicado';
create index if not exists jornal_repartos_usuario_idx on public.jornal_repartos (usuario_id, desde, hasta);
-- (y un asiento, un reparto: cada «Así es» deja su asiento)
create unique index if not exists jornal_repartos_asiento_unico on public.jornal_repartos (asiento_id);
comment on table public.jornal_repartos is 'c10: cada pago de una persona repartido por sus horas: el movimiento del banco, la persona, el período (desde, hasta) y la regla que lo eligió (semana_anterior, semana_en_curso o a_mano), el monto repartido, las horas que entraron, la tarifa que sale (monto ÷ horas) y la de costos_equipo ese día, la cuenta de las líneas con obra y la de lo sin obra, el asiento que puso c6 (fn_banco_clasificar), el estado (aplicado o deshecho), la huella de las horas que Edgar vio, los avisos que traía la propuesta, las opciones con que se aplicó (incluir_cubiertas, motivo), los reportes de horas que aprobó (fn_horas_aprobar), quién y cuándo; y, deshecho, por quién, cuándo, por qué y el reverso que puso c6 (fn_banco_descasar). Solo se añade: lo único que cambia es el paso a deshecho.';
comment on column public.jornal_repartos.huella is 'md5 de lo que Edgar vio al aceptar (el «visto» de fn_jornal_propuesta): el movimiento, la persona, las fechas, el monto, las cuentas y cada reporte de horas que entra o que el «Así es» aprueba (id, fecha, obra, CO, fase, horas, si entra y si se aprueba).';

-- Lo que fue al libro, por obra y CO (n: el orden del grupo; orden: el de su
-- línea en el asiento, vacío si al grupo no le llegó ni un centavo).
create table if not exists public.jornal_reparto_lineas (
  reparto_id   uuid          not null references public.jornal_repartos (id),
  n            int           not null,
  orden        int,
  proyecto_id  text,
  co           text,
  cuenta       text          not null references public.cuentas (codigo),
  horas        numeric       not null,
  monto        numeric(14,2) not null,
  constraint jornal_reparto_lineas_pk    primary key (reparto_id, n),
  constraint jornal_reparto_lineas_monto check (monto >= 0 and horas > 0),
  constraint jornal_reparto_lineas_orden check ((orden is null) = (monto = 0)),
  constraint jornal_reparto_lineas_co    check (co is null or proyecto_id is not null)
);
create index if not exists jornal_reparto_lineas_obra_idx on public.jornal_reparto_lineas (proyecto_id) where proyecto_id is not null;
-- (cada parte, una línea distinta del asiento)
create unique index if not exists jornal_reparto_lineas_orden_unico on public.jornal_reparto_lineas (reparto_id, orden) where orden is not null;
comment on table public.jornal_reparto_lineas is 'c10: las partes de cada reparto, por obra y CO (proyecto_id vacío = las horas sin obra): n es el orden del grupo, orden el de su línea en el asiento (la 1 es la del banco; vacío si al grupo no le llegó ni un centavo y no lleva línea), la cuenta, las horas del grupo y su monto. La suma de un reparto es su monto, al centavo. No se edita ni se borra.';

-- El detalle por reporte de horas: el papel del asiento (cada hora que
-- entró, como estaba al repartir, con su parte del pago).
create table if not exists public.jornal_reparto_horas (
  reparto_id   uuid          not null references public.jornal_repartos (id),
  horas_id     bigint        not null,
  n            int           not null,
  fecha        date          not null,
  proyecto_id  text,
  co           text,
  fase         text,
  horas        numeric       not null,
  monto        numeric(14,2) not null,
  constraint jornal_reparto_horas_pk    primary key (reparto_id, horas_id),
  constraint jornal_reparto_horas_monto check (monto >= 0 and horas > 0),
  constraint jornal_reparto_horas_grupo foreign key (reparto_id, n) references public.jornal_reparto_lineas (reparto_id, n)
);
create index if not exists jornal_reparto_horas_hora_idx on public.jornal_reparto_horas (horas_id);
comment on table public.jornal_reparto_horas is 'c10: el detalle de cada reparto por reporte de horas (horas.id, sin llave foránea: es de la app), como estaba al repartir (fecha, obra, CO, fase, horas), su grupo (n) y su parte del pago. La suma por reparto es su monto, al centavo. Es el «reporte de horas aprobado» al que llega cada dólar de mano de obra, y lo que dice qué horas tienen pago real. No se edita ni se borra.';


-- ---------------------------------------------------------------------
-- 2. La guarda de las tablas de c10 (la de c6 y c9, en su forma): solo se
--    escriben con la marca de la transacción (mx_jornal.escribe = el nombre
--    de la tabla), que ponen las funciones de aquí justo antes de escribir
--    y quitan después. Un insert o un update a mano —desde PostgREST,
--    aunque sea el dueño, o desde el SQL Editor sin la marca— da MX003. Y
--    lo que es rastro no se edita ni se borra. SECURITY INVOKER, sin grant
--    a nadie (la dispara la tabla).
-- ---------------------------------------------------------------------
create or replace function public.fn_jornal_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_marca text := coalesce(current_setting('mx_jornal.escribe', true), '');
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003',
      message = format('%s no se trunca: es rastro de los repartos.', tg_table_name);
  end if;
  if tg_op = 'DELETE' then
    -- (una persona dada de alta se va con su perfil —la llave en cascada— si
    -- nunca se le repartió nada; con repartos, ni ella ni su perfil se borran)
    -- (old.usuario_id se lee de la fila entera: la guarda es de las cinco
    -- tablas, y no todas tienen esa columna)
    if tg_table_name = 'jornal_personas'
       and not exists (select 1 from jornal_repartos r where r.usuario_id = (to_jsonb(old)->>'usuario_id')::uuid) then
      return old;
    end if;
    raise exception using errcode = 'MX003',
      message = format('%s no se borra: %s', tg_table_name,
                       case tg_table_name
                         when 'jornal_personas' then 'esa persona tiene pagos repartidos; se da de baja (fn_jornal_persona con activa = false) y queda.'
                         when 'jornal_repartos' then 'un reparto se deshace con su motivo (fn_jornal_deshacer) y queda.'
                         when 'jornal_config' then 'es la configuración (una fila); se cambia con fn_jornal_config.'
                         else 'es el detalle de un reparto.' end);
  end if;
  if v_marca <> tg_table_name then
    raise exception using errcode = 'MX003',
      message = format('%s se escribe solo desde las funciones del jornal (%s), no a mano.', tg_table_name,
                       case tg_table_name
                         when 'jornal_config' then 'fn_jornal_config'
                         when 'jornal_personas' then 'fn_jornal_persona'
                         when 'jornal_repartos' then 'fn_jornal_aplicar y fn_jornal_deshacer'
                         else 'fn_jornal_aplicar' end);
  end if;
  if tg_op = 'UPDATE' then
    if tg_table_name = 'jornal_repartos' then
      -- Lo único que le pasa a un reparto: deshacerse, una vez.
      if old.estado <> 'aplicado' or new.estado <> 'deshecho'
         or (to_jsonb(new) - array['estado', 'deshecho_el', 'deshecho_por', 'deshecho_motivo', 'reverso_id'])
            is distinct from
            (to_jsonb(old) - array['estado', 'deshecho_el', 'deshecho_por', 'deshecho_motivo', 'reverso_id']) then
        raise exception using errcode = 'MX003',
          message = 'Un reparto no se edita: se deshace con su motivo (una vez) y se vuelve a repartir.';
      end if;
    elsif tg_table_name in ('jornal_reparto_lineas', 'jornal_reparto_horas') then
      raise exception using errcode = 'MX003', message = format('%s no se edita: es el detalle de un reparto.', tg_table_name);
    elsif tg_table_name = 'jornal_personas' and (to_jsonb(new)->>'usuario_id') is distinct from (to_jsonb(old)->>'usuario_id') then
      raise exception using errcode = 'MX003', message = 'Una persona dada de alta no cambia de perfil: se da de baja y se da de alta la otra.';
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.fn_jornal_guarda() from public, anon, authenticated, service_role;
comment on function public.fn_jornal_guarda() is 'c10: la guarda de las tablas de c10: se escriben solo con la marca de la transacción (mx_jornal.escribe) que ponen sus funciones; un reparto solo pasa a deshecho (una vez), su detalle no se edita, y nada se borra (una persona sin repartos se va con su perfil).';

do $$
declare
  t text;
begin
  foreach t in array array['jornal_config', 'jornal_personas', 'jornal_repartos', 'jornal_reparto_lineas', 'jornal_reparto_horas'] loop
    execute format('create or replace trigger trg_%s_guarda before insert or update or delete on public.%I '
                   'for each row execute function public.fn_jornal_guarda()', t, t);
    execute format('create or replace trigger trg_%s_sin_truncate before truncate on public.%I '
                   'for each statement execute function public.fn_jornal_guarda()', t, t);
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
  foreach t in array array['jornal_config', 'jornal_personas', 'jornal_repartos', 'jornal_reparto_lineas', 'jornal_reparto_horas'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
  -- Lo que escriben las funciones de la pantalla (como el dueño).
  foreach t in array array['jornal_config', 'jornal_personas', 'jornal_repartos'] loop
    execute format('create policy %I on public.%I for update to authenticated using ((select es_dueno())) with check ((select es_dueno()))',
                   t || '_dueno_edita', t);
    execute format('grant update on public.%I to authenticated', t);
  end loop;
  foreach t in array array['jornal_personas', 'jornal_repartos', 'jornal_reparto_lineas', 'jornal_reparto_horas'] loop
    execute format('create policy %I on public.%I for insert to authenticated with check ((select es_dueno()))',
                   t || '_dueno_anade', t);
    execute format('grant insert on public.%I to authenticated', t);
  end loop;
end $$;

-- La fila de la configuración (con la marca de la guarda): al volver a pegar
-- no se pisa nada.
do $$
begin
  if not exists (select 1 from public.jornal_config where id = 1) then
    perform set_config('mx_jornal.escribe', 'jornal_config', true);
    insert into public.jornal_config (id) values (1);
    perform set_config('mx_jornal.escribe', '', true);
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 4. Lo común: dinero, horas y fechas en llano, la descripción con que se
--    reconoce un pago, el patrón de una persona, las cuentas que sirven, y
--    la regla del período. Todo SECURITY INVOKER; lo que usan las funciones
--    de la pantalla y las vistas lleva EXECUTE para authenticated.
-- ---------------------------------------------------------------------
-- Las vistas de c10 se borran aquí y se rehacen al final (en este mismo
-- pegado): así una función que cambie puede volver a crearse.
drop view if exists public.v_jornal_pendientes, public.v_jornal_repartos, public.v_jornal_personas, public.v_jornal_control,
                    public.v_margen_obra, public.v_margen_control;

-- Dólares como se leen: $1,234.56 (negativo con su signo).
create or replace function public.fn_jornal_usd(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null then '—'
              when p < 0 then '-$' || to_char(-p, 'FM999,999,999,990.00')
              else '$' || to_char(p, 'FM999,999,999,990.00') end
$$;
revoke execute on function public.fn_jornal_usd(numeric) from public, anon, service_role;
grant  execute on function public.fn_jornal_usd(numeric) to authenticated;
comment on function public.fn_jornal_usd(numeric) is 'c10: un monto en dólares como se lee ($1,234.56).';

-- Horas como se leen: 42, 6.5 (sin ceros de sobra).
create or replace function public.fn_jornal_h(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$ select case when p is null then '—' else trim_scale(p)::text end $$;
revoke execute on function public.fn_jornal_h(numeric) from public, anon, service_role;
grant  execute on function public.fn_jornal_h(numeric) to authenticated;
comment on function public.fn_jornal_h(numeric) is 'c10: unas horas como se leen (42, 6.5).';

-- Un día en corto: 19-oct (con el año si se pide: 19-oct-2026).
create or replace function public.fn_jornal_dia(p date, p_anio boolean default false) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select extract(day from p)::int || '-'
         || (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int]
         || case when p_anio then '-' || extract(year from p)::int else '' end
$$;
revoke execute on function public.fn_jornal_dia(date, boolean) from public, anon, service_role;
grant  execute on function public.fn_jornal_dia(date, boolean) to authenticated;
comment on function public.fn_jornal_dia(date, boolean) is 'c10: un día en corto (19-oct; con el año, 19-oct-2026).';

-- Un período en una frase: «del 19 al 25 de octubre de 2026», «del 26 de
-- octubre al 1 de noviembre de 2026», «el 19 de octubre de 2026».
create or replace function public.fn_jornal_rango(p_desde date, p_hasta date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  with m(n) as (select array['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre',
                             'noviembre', 'diciembre'])
  select case when p_desde is null or p_hasta is null then '(sin fechas)'
              when p_desde = p_hasta
                then format('el %s de %s de %s', extract(day from p_desde)::int, m.n[extract(month from p_desde)::int],
                            extract(year from p_desde)::int)
              when date_trunc('month', p_desde) = date_trunc('month', p_hasta)
                then format('del %s al %s de %s de %s', extract(day from p_desde)::int, extract(day from p_hasta)::int,
                            m.n[extract(month from p_hasta)::int], extract(year from p_hasta)::int)
              when extract(year from p_desde) = extract(year from p_hasta)
                then format('del %s de %s al %s de %s de %s', extract(day from p_desde)::int, m.n[extract(month from p_desde)::int],
                            extract(day from p_hasta)::int, m.n[extract(month from p_hasta)::int], extract(year from p_hasta)::int)
              else format('del %s de %s de %s al %s de %s de %s', extract(day from p_desde)::int, m.n[extract(month from p_desde)::int],
                          extract(year from p_desde)::int, extract(day from p_hasta)::int, m.n[extract(month from p_hasta)::int],
                          extract(year from p_hasta)::int) end
    from m
$$;
revoke execute on function public.fn_jornal_rango(date, date) from public, anon, service_role;
grant  execute on function public.fn_jornal_rango(date, date) to authenticated;
comment on function public.fn_jornal_rango(date, date) is 'c10: un período en una frase («del 19 al 25 de octubre de 2026»).';

-- Un mes como se dice: «octubre de 2026» (el de ese día).
create or replace function public.fn_jornal_mes(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select (array['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre',
                'diciembre'])[extract(month from p)::int] || ' de ' || extract(year from p)::int
$$;
revoke execute on function public.fn_jornal_mes(date) from public, anon, service_role;
grant  execute on function public.fn_jornal_mes(date) to authenticated;
comment on function public.fn_jornal_mes(date) is 'c10: el mes de un día como se dice («octubre de 2026»).';

-- El texto con que se reconoce un pago: la descripción normalizada del
-- banco (movimientos_banco.desc_norm, que c6 deja en mayúsculas, solo con
-- letras, dígitos, # y &) y su nota normalizada igual (la regla de c6,
-- fn_banco_norm, escrita aquí: la app no ejecuta las funciones internas de
-- c6). Chase pone el nombre en la descripción; otros bancos, en la nota.
create or replace function public.fn_jornal_texto(p_desc_norm text, p_memo text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select btrim(coalesce(p_desc_norm, '') || ' '
               || btrim(regexp_replace(upper(coalesce(p_memo, '')), '[^[:alnum:]#&]+', ' ', 'g')))
$$;
revoke execute on function public.fn_jornal_texto(text, text) from public, anon, service_role;
grant  execute on function public.fn_jornal_texto(text, text) to authenticated;
comment on function public.fn_jornal_texto(text, text) is 'c10: el texto de un movimiento contra el que se prueba el patrón de cada persona: su descripción normalizada (desc_norm) y su nota, normalizada como c6.';

-- Un texto como lo deja el banco antes de postearlo (c6, fn_banco_limpio):
-- sin espacios, tabuladores ni saltos de línea en las puntas; vacío = nulo.
-- El CO y la fase de unas horas pasan por aquí en el núcleo, en la
-- propuesta, en la huella, en el margen y en el control: así el CO que c10
-- reparte es, letra por letra, el que c6 escribe en la línea del asiento.
-- (btrim a secas quita solo espacios: un CO con un salto de línea al final
-- —un pegado, el conector— salía como un grupo aparte del mismo CO sin él, y
-- al postear c6 lo limpiaba y el asiento «no era el reparto»: el pago no se
-- podía repartir. La regla de c6 va escrita aquí: la app no ejecuta sus
-- funciones internas. El tabulador vertical, como chr(11): en una cadena
-- E'' «\v» no es un escape.)
create or replace function public.fn_jornal_limpio(p text) returns text
language sql immutable
set search_path = public, pg_temp
as $$ select nullif(btrim(p, E' \t\r\n\f' || chr(11)), '') $$;
revoke execute on function public.fn_jornal_limpio(text) from public, anon, service_role;
grant  execute on function public.fn_jornal_limpio(text) to authenticated;
comment on function public.fn_jornal_limpio(text) is 'c10: un texto sin espacios, tabuladores ni saltos de línea en las puntas (vacío = nulo): la misma limpieza que c6 (fn_banco_limpio) le hace al CO y a la fase antes de postear. Con ella se agrupan, se enseñan, se huellan y se comparan el CO y la fase de las horas.';

-- ¿Sirve este patrón? Nulo = sí; si no, el porqué en llano. Tiene que ser
-- una expresión regular que Postgres entienda, con al menos tres letras o
-- dígitos, y no puede casar con cualquier pago (un «ZELLE» a secas casaría
-- con todos los Zelle, y el de Edgar a su casero entraría como jornal). Se
-- prueba contra lo que el banco escribe sin nombre («ZELLE PAYMENT TO») y
-- contra pagos a OTRA persona, con un nombre que nadie lleva («QQXZ WWKJ»):
-- un patrón con el nombre de alguien no casa con ese; uno que diga «un Zelle
-- a quien sea» («ZELLE PAYMENT TO [A-Z]») sí, y no vale. (Lo que casa de
-- verdad en esta base —con cuántos destinatarios distintos— lo mira
-- fn_jornal_persona al dar de alta.)
create or replace function public.fn_jornal_patron_mal(p text) returns text
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  v text := btrim(coalesce(p, ''));
  s text;
begin
  if v = '' then
    return 'falta el patrón: lo que el banco escribe en sus pagos (su nombre, como sale en la descripción del Zelle)';
  end if;
  if length(v) > 200 then
    return 'el patrón es demasiado largo (200 letras como mucho)';
  end if;
  if length(regexp_replace(v, '[^[:alnum:]]', '', 'g')) < 3 then
    return 'el patrón es demasiado corto: al menos tres letras de su nombre';
  end if;
  begin
    perform 'X' ~* v;
  exception when others then
    return format('«%s» no es un patrón que la base entienda (%s): escribe su nombre tal como sale en el banco', v, sqlerrm);
  end;
  foreach s in array array['', 'X', 'ZELLE', 'ZELLE PAYMENT TO', 'ZELLE PAYMENT TO 12345678901', 'ZELLE PAYMENT FROM',
                           'ONLINE TRANSFER', 'ONLINE PAYMENT', 'PAYMENT', 'PAYMENT TO', 'CHECK 1234', 'ACH DEBIT',
                           'DEBIT CARD PURCHASE', 'TRANSFER TO', 'WITHDRAWAL',
                           -- (pagos a otra persona y a un comercio, con un nombre que nadie lleva)
                           'ZELLE PAYMENT TO QQXZ WWKJ', 'ZELLE PAYMENT TO QQXZ WWKJ 12345678901', 'ZELLE PMT TO QQXZ',
                           'ONLINE TRANSFER TO QQXZ WWKJ', 'PAYMENT TO QQXZ WWKJ', 'POS PURCHASE QQXZ WWKJ SUPPLY 0042'] loop
    if s ~* v then
      return format('«%s» casaría con cualquier pago (también con «%s»): tiene que llevar su nombre', v,
                    case when s = '' then 'una descripción vacía'
                         when s like '%QQXZ%' then replace(replace(s, 'QQXZ WWKJ', 'otra persona'), 'QQXZ', 'otra persona')
                         else s end);
    end if;
  end loop;
  return null;
end $$;
revoke execute on function public.fn_jornal_patron_mal(text) from public, anon, service_role;
grant  execute on function public.fn_jornal_patron_mal(text) to authenticated;
comment on function public.fn_jornal_patron_mal(text) is 'c10: por qué un patrón no sirve para reconocer el pago de una persona (nulo = sirve): vacío, corto, no es una expresión regular válida, o casaría con cualquier pago (con lo que el banco escribe sin nombre, o con un pago a otra persona).';

-- A QUIÉN dice el banco que fue un pago: el nombre que escribe en su
-- descripción (ya normalizada: desc_norm), sin el «ZELLE PAYMENT TO» de
-- delante ni el código de confirmación de detrás (las palabras con un
-- dígito), hasta cuatro palabras. «ZELLE PAYMENT TO ZZANA PRUEBA
-- JPM99ABC123» → «ZZANA PRUEBA». Vacío si no queda nada. De aquí salen el
-- patrón que se propone para una persona y la cuenta de con cuántos
-- destinatarios distintos casa un patrón (fn_jornal_persona).
create or replace function public.fn_jornal_destinatario(p_desc_norm text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select array_to_string((array(select w.t
                                  from regexp_split_to_table(
                                         regexp_replace(coalesce(p_desc_norm, ''),
                                           '^(ZELLE( PAYMENT| PMT| TRANSFER)?( TO| FROM)?|ONLINE (PAYMENT|TRANSFER)( TO)?|PAYMENT TO|TRANSFER TO) ',
                                           ''), ' ') with ordinality as w(t, o)
                                 where w.t !~ '[0-9]' and w.t !~ '[#&]' and w.t <> ''
                                 order by w.o))[1:4], ' ')
$$;
revoke execute on function public.fn_jornal_destinatario(text) from public, anon, service_role;
grant  execute on function public.fn_jornal_destinatario(text) to authenticated;
comment on function public.fn_jornal_destinatario(text) is 'c10: a quién dice el banco que fue un pago: el nombre de su descripción normalizada, sin «ZELLE PAYMENT TO» ni el código de confirmación (hasta cuatro palabras; vacío si no queda nada).';

-- El patrón que la pantalla ofrece al dar de alta a una persona desde un
-- movimiento: ese nombre, entre límites de palabra. «ZELLE PAYMENT TO ZZANA
-- PRUEBA JPM99ABC123» → «\mZZANA PRUEBA\M». Nulo si no queda un nombre.
create or replace function public.fn_jornal_patron_sugerido(p_movimiento uuid) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select case when length(regexp_replace(z.nombre, '[^[:alnum:]]', '', 'g')) >= 3 and public.fn_jornal_patron_mal(z.nombre) is null
              then '\m' || z.nombre || '\M' end
    from (select public.fn_jornal_destinatario(m.desc_norm) as nombre
            from public.movimientos_banco m
           where m.id = p_movimiento) z
$$;
revoke execute on function public.fn_jornal_patron_sugerido(uuid) from public, anon, service_role;
grant  execute on function public.fn_jornal_patron_sugerido(uuid) to authenticated;
comment on function public.fn_jornal_patron_sugerido(uuid) is 'c10: el patrón que se propone para dar de alta a una persona desde un movimiento del banco: el nombre de su descripción, sin «ZELLE PAYMENT TO» ni el código de confirmación, entre límites de palabra. Nulo si no queda un nombre. Lee el movimiento con la policy de quien llama.';

-- ¿Sirve esta cuenta? p_uso 'obra' (las líneas con obra del jornal) o
-- 'sin_obra' (las horas sin obra). Nulo = sí; si no, el porqué en llano.
-- Lo que c6 rechaza desde el banco (50xx, la mano de obra de nómina; 6000 y
-- 6005, sueldo) se dice aquí, antes: así ningún reparto se cae al postear.
-- Y lo sin obra no va a cualquier gasto: no a una cuenta con su propia
-- etiqueta fiscal (multas no deducibles, depreciación, comidas al 50 %, el
-- seguro del accionista…: cada una tiene su renglón en la declaración) ni a
-- las que alimenta otra parte del libro (el burden de la nómina, los cargos
-- del banco, la depreciación del cierre, los incobrables, los intereses,
-- los impuestos). Queda lo que el CPA puede querer: un gasto general (7900
-- mientras decide) o una cuenta nueva para la mano de obra sin obra.
create or replace function public.fn_jornal_cuenta_mal(p_cuenta text, p_uso text) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select case when p_cuenta is null then 'falta la cuenta'
              when c.codigo is null then format('la cuenta %s no existe en el plan de cuentas', p_cuenta)
              when not c.activa then format('la cuenta %s (%s) está inactiva: ya no recibe asientos', c.codigo, c.nombre)
              when not c.imputable then format('la cuenta %s (%s) es de grupo: va a una de sus subcuentas', c.codigo, c.nombre)
              when left(c.codigo, 2) = '50'
                then format('la cuenta %s (%s) es mano de obra de nómina: entra solo por el journal del proveedor de nómina (f11), '
                            'y el banco no la deja pasar', c.codigo, c.nombre)
              when c.codigo in ('6000', '6005')
                then format('la cuenta %s (%s) es sueldo: entra solo por el journal de su nómina, y el banco no la deja pasar',
                            c.codigo, c.nombre)
              when p_uso = 'obra' and c.tipo <> 'costo'
                then format('la cuenta %s (%s) no es de costo de obra: el jornal con obra va a una cuenta 5xxx (de fábrica, 5200)',
                            c.codigo, c.nombre)
              when p_uso = 'obra' and c.regla_obra = 'prohibida'
                then format('la cuenta %s (%s) no admite obra, y cada parte del jornal lleva la suya', c.codigo, c.nombre)
              when p_uso = 'sin_obra' and c.tipo not in ('costo', 'gasto', 'otro_gasto')
                then format('la cuenta %s (%s) no es de costo ni de gasto', c.codigo, c.nombre)
              when p_uso = 'sin_obra' and c.regla_obra = 'obligatoria'
                then format('la cuenta %s (%s) exige obra, y esto es justo lo que no la tiene', c.codigo, c.nombre)
              when p_uso = 'sin_obra' and nullif(btrim(c.etiqueta_fiscal), '') is not null and c.etiqueta_fiscal <> '1099'
                then format('la cuenta %s (%s) lleva su propia etiqueta fiscal («%s»): es de otra cosa, y la mano de obra sin obra '
                            'ahí saldría mal en la declaración', c.codigo, c.nombre, c.etiqueta_fiscal)
              when p_uso = 'sin_obra' and c.codigo in ('6010', '6130', '6950', '6980', '7100', '9000')
                then format('la cuenta %s (%s) la alimenta otra parte del libro (la nómina, el banco, el cierre o los impuestos): la '
                            'mano de obra sin obra no va ahí', c.codigo, c.nombre)
         end
    from (select p_cuenta as q) x
    left join public.cuentas c on c.codigo = x.q
$$;
revoke execute on function public.fn_jornal_cuenta_mal(text, text) from public, anon, service_role;
grant  execute on function public.fn_jornal_cuenta_mal(text, text) to authenticated;
comment on function public.fn_jornal_cuenta_mal(text, text) is 'c10: por qué una cuenta no sirve para el jornal (nulo = sirve): p_uso «obra» (activa, imputable, de costo, que admita obra) o «sin_obra» (de costo o gasto, que no exija obra, sin etiqueta fiscal propia —salvo 1099— y que no sea de las que alimenta otra parte del libro: 6010, 6130, 6950, 6980, 7100, 9000); nunca 50xx, 6000 ni 6005 (c6 no las deja entrar desde el banco).';

-- LA REGLA DEL PERÍODO: la semana de trabajo (de lunes a domingo) que paga
-- un pago, según el día en que se hizo. De lunes a miércoles, la semana
-- ANTERIOR; de jueves a domingo, la semana EN CURSO. Solo fechas (ninguna
-- hora, ningún huso): el cambio de hora no la mueve.
create or replace function public.fn_jornal_periodo(p_fecha date)
returns table (desde date, hasta date, regla text)
language sql immutable
set search_path = public, pg_temp
as $$
  select case when x.d <= 3 then x.lunes - 7 else x.lunes end,
         case when x.d <= 3 then x.lunes - 1 else x.lunes + 6 end,
         case when x.d <= 3 then 'semana_anterior' else 'semana_en_curso' end
    from (select extract(isodow from p_fecha)::int as d, p_fecha - (extract(isodow from p_fecha)::int - 1) as lunes) x
   where p_fecha is not null
$$;
revoke execute on function public.fn_jornal_periodo(date) from public, anon, service_role;
grant  execute on function public.fn_jornal_periodo(date) to authenticated;
comment on function public.fn_jornal_periodo(date) is 'c10: la semana de trabajo (lunes a domingo) que paga un pago hecho ese día: de lunes a miércoles, la semana anterior; de jueves a domingo, la semana en curso. Devuelve desde, hasta y la regla (semana_anterior o semana_en_curso).';

-- Cómo se llama un período respecto del día del pago: la semana anterior a
-- la del pago, la del pago, o fechas a mano.
create or replace function public.fn_jornal_regla(p_fecha date, p_desde date, p_hasta date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p_desde = x.lunes - 7 and p_hasta = x.lunes - 1 then 'semana_anterior'
              when p_desde = x.lunes and p_hasta = x.lunes + 6 then 'semana_en_curso'
              else 'a_mano' end
    from (select p_fecha - (extract(isodow from p_fecha)::int - 1) as lunes) x
$$;
revoke execute on function public.fn_jornal_regla(date, date, date) from public, anon, service_role;
grant  execute on function public.fn_jornal_regla(date, date, date) to authenticated;
comment on function public.fn_jornal_regla(date, date, date) is 'c10: el nombre de un período respecto del día del pago: semana_anterior (la semana antes de la del pago), semana_en_curso (la del pago) o a_mano.';

-- Desde cuándo hay libro: el día después de la apertura (30-sep-2026 → el 1
-- de octubre); lo de antes está en QuickBooks. La misma regla que c4. (Lo
-- usan el margen y, del jornal, lo que mira «desde que empieza el libro».)
create or replace function public.fn_margen_libro_desde() returns date
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce((select pa.hasta + 1 from public.periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1),
                  (select min(pm.desde) from public.periodos pm where pm.tipo = 'mes'))
$$;
revoke execute on function public.fn_margen_libro_desde() from public, anon, service_role;
grant  execute on function public.fn_margen_libro_desde() to authenticated;
comment on function public.fn_margen_libro_desde() is 'c10: el primer día del libro (el día después de la apertura; sin ella, el primer mes): lo de antes está en QuickBooks. La misma regla que v_costo_por_obra de c4.';

-- LAS HORAS QUE YA PAGÓ UNA NÓMINA (v3, 13-nov-2026, la Fase 11b). Desde
-- enero de 2027 la gente de obra cobra por nómina (c15: el journal de Gusto
-- entra al libro repartido por sus horas aprobadas). Esas horas TIENEN pago
-- real —su costo está en el libro, en 5000, 5001 y 5010 con su obra— y aquí
-- salían «a estándar»: solo se reconocía como pago real el reparto de un
-- Zelle. Con el burden estándar fijado, su mano de obra contaba dos veces en
-- «costo con estándar» (la real del libro y, encima, la estándar).
--   · c15 SE PEGA DESPUÉS de este archivo y es opcional: aquí no se nombra
--     nada suyo que rompa el pegado. Se mira si está su marca sin dinero
--     (qué reporte de horas pagó qué corrida posteada y viva, y su día de
--     pago: ni un importe, ni un nombre) y se lee al vuelo. Sin c15, ninguna
--     fila: todo sigue como en la v2.
--   · LA SEGURIDAD NO CAMBIA: esta función corre con los permisos de quien
--     llama (no es SECURITY DEFINER). Lo que cobra cada persona sigue
--     pidiendo el código del teléfono en c15, y aquí no se lee; la marca
--     contesta al dueño sin el código porque no lleva dinero («Costo por
--     obra» se lee sin él), y al equipo no le da nada.
--   · SI LA MARCA NO SE PUEDE LEER (un c15 de antes del 13-nov, que no la
--     trae; o una que cambió de forma) no se rompe el costo por obra: ninguna
--     fila —como antes de la v3—, y el control del margen (el 70) lo dice, en
--     rojo si ya hay una nómina en el libro, con qué volver a pegar.
-- La leen el margen (fn_margen_horas: la clase de cada hora), lo que se
-- queda fuera de los repartos (las horas tardías, los pagos resueltos por
-- fuera), las personas del jornal y la propuesta de un pago (un aviso).
create or replace function public.fn_margen_horas_nomina()
returns table (horas_id bigint, corrida_id uuid, dia_pago date)
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_h bigint[];
  v_c uuid[];
  v_d date[];
begin
  if not fn_jornal_ve() or to_regprocedure('public.fn_nomina_horas_con_pago()') is null then
    return;
  end if;
  -- (leída entera a tres listas antes de devolver nada: si la lectura falla,
  -- no queda media respuesta)
  begin
    execute 'select coalesce(array_agg(n.horas_id::bigint), ''{}''), coalesce(array_agg(n.corrida_id::uuid), ''{}''), '
         || 'coalesce(array_agg(n.dia_pago::date), ''{}'') '
         || 'from public.fn_nomina_horas_con_pago() n where n.horas_id is not null'
       into v_h, v_c, v_d;
  exception when others then
    return;
  end;
  return query select u.h, u.c, u.d from unnest(v_h, v_c, v_d) as u(h, c, d);
end $$;
revoke execute on function public.fn_margen_horas_nomina() from public, anon, service_role;
grant  execute on function public.fn_margen_horas_nomina() to authenticated;
comment on function public.fn_margen_horas_nomina() is 'c10: las horas que ya pagó una nómina posteada y viva, si la nómina (c15) está en esta base: el reporte de horas, su corrida y su día de pago, de la marca sin dinero de c15, leída al vuelo (c15 se pega después y es opcional; sin ella, o si su marca no se puede leer, ninguna fila: lo dice el control 70 del margen). Ni un importe ni un nombre: lo que cobra cada persona sigue en la nómina, con el código del teléfono. La usan el margen (esas horas tienen pago real: no van a estándar), las horas tardías, los pagos resueltos por fuera, las personas del jornal y la propuesta de un pago. Solo lectura; a quien no es el dueño, nada.';


-- ---------------------------------------------------------------------
-- 5. EL NÚCLEO DEL REPARTO. No sabe nada del banco ni del Zelle y no
--    escribe nada: unas horas y un monto → la parte de cada obra y CO, al
--    centavo, y la de cada reporte de horas. Es lo que f11 alimentará con
--    el journal de nómina (persona, período de pago, bruto) sin rehacerlo.
--    La regla de redondeo, en la cabecera («LA REGLA DE REDONDEO»).
-- ---------------------------------------------------------------------
-- Por reportes de horas (sus ids): una fila por reporte, con su grupo (el
-- orden de su línea: cada obra por su id y CO, y lo sin obra al final), las
-- horas y el monto del grupo, y las horas y el monto del reporte. Los
-- montos de los grupos suman p_monto; los de los reportes de un grupo, el
-- del grupo. Sin horas que valgan, ninguna fila.
create or replace function public.fn_jornal_repartir_ids(p_ids bigint[], p_monto numeric)
returns table (grupo int, proyecto_id text, co text, horas_grupo numeric, monto_grupo numeric(14,2),
               horas_id bigint, fecha date, fase text, horas numeric, monto numeric(14,2),
               horas_total numeric, monto_total numeric(14,2))
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
begin
  if p_monto is null or p_monto <= 0 or p_monto >= 1000000000 or p_monto <> round(p_monto, 2) then
    raise exception using errcode = 'MX005',
      message = format('El monto a repartir va en dólares con centavos y mayor que cero (llegó %s): el libro va en centavos.',
                       coalesce(p_monto::text, 'nada'));
  end if;
  return query
  with h as (
    -- (el CO solo vale con obra: c2 no admite CO en una línea sin ella; y va
    -- limpio como lo deja c6 al postear: «CO #1» con un salto de línea detrás
    -- es el mismo CO, un solo grupo)
    select x.id, x.fecha as f, x.proyecto_id as pid,
           case when x.proyecto_id is null then null else public.fn_jornal_limpio(x.co) end as c,
           public.fn_jornal_limpio(x.fase) as fa, x.horas as hrs
      from public.horas x
     where x.id = any (p_ids) and x.horas > 0 and x.horas < 100000
       and (select public.fn_jornal_ve())   -- (el equipo lee las horas; el reparto de un pago, no)
  ), t as (
    select sum(h.hrs) as ht, (round(p_monto, 2) * 100)::numeric as cents from h
  ), g1 as (
    select h.pid, h.c, sum(h.hrs) as hg from h group by h.pid, h.c
  ), g2 as (
    -- la parte entera de cada grupo y su resto (sobre el mismo divisor: se comparan exactos)
    select g1.pid, g1.c, g1.hg, t.ht, t.cents,
           div(t.cents * g1.hg, t.ht) as piso,
           t.cents * g1.hg - div(t.cents * g1.hg, t.ht) * t.ht as resto
      from g1 cross join t
  ), g3 as (
    select g2.*,
           row_number() over (order by (g2.pid is null), g2.pid, g2.c nulls first)::int as g,
           row_number() over (order by g2.resto desc, g2.hg desc, (g2.pid is null), g2.pid, g2.c nulls first) as r,
           g2.cents - sum(g2.piso) over () as sobra
      from g2
  ), g4 as (
    select g3.*, g3.piso + case when g3.r <= g3.sobra then 1 else 0 end as cg from g3
  ), r1 as (
    select h.id, h.f, h.pid, h.c, h.fa, h.hrs, g4.g, g4.hg, g4.cg, g4.ht,
           div(g4.cg * h.hrs, g4.hg) as piso,
           g4.cg * h.hrs - div(g4.cg * h.hrs, g4.hg) * g4.hg as resto
      from h
      join g4 on g4.pid is not distinct from h.pid and g4.c is not distinct from h.c
  ), r2 as (
    select r1.*,
           row_number() over (partition by r1.g order by r1.resto desc, r1.hrs desc, r1.f, r1.id) as r,
           r1.cg - sum(r1.piso) over (partition by r1.g) as sobra
      from r1
  )
  select r2.g, r2.pid, r2.c, r2.hg, (r2.cg / 100)::numeric(14,2),
         r2.id, r2.f, r2.fa, r2.hrs, ((r2.piso + case when r2.r <= r2.sobra then 1 else 0 end) / 100)::numeric(14,2),
         r2.ht, round(p_monto, 2)::numeric(14,2)
    from r2
   order by r2.g, r2.f, r2.id;
end $$;
revoke execute on function public.fn_jornal_repartir_ids(bigint[], numeric) from public, anon, service_role;
grant  execute on function public.fn_jornal_repartir_ids(bigint[], numeric) to authenticated;
comment on function public.fn_jornal_repartir_ids(bigint[], numeric) is 'c10: EL NÚCLEO por reportes de horas: reparte un monto entre esos reportes (horas.id) por sus horas, agrupados por obra y CO (lo sin obra, un grupo), al centavo y por mayores restos (a resto igual: más horas, obra, CO; lo sin obra al final): una fila por reporte con su grupo, las horas y el monto del grupo y los del reporte. Los grupos suman el monto; los reportes de cada grupo, el del grupo. No escribe nada; a quien no es el dueño no le devuelve nada. MX005 si el monto no es mayor que cero y en centavos.';

-- Por persona y período (lo que usará f11): las horas de esa persona en
-- esas fechas. TODAS, las que ya tengan otro pago también: quién descuenta
-- qué lo decide quien llama (el jornal del Zelle lo hace en su propuesta).
-- p_solo_aprobadas: solo las APROBADAS. El plan (§1, §3) dice que la clave
-- del reparto de la nómina son las horas aprobadas: f11 lo pide así
-- (fn_jornal_repartir(persona, desde, hasta, bruto, true)) y, si con todas
-- sale otra cosa, es que quedan horas por aprobar en ese período de pago. El
-- jornal del Zelle no lo usa: su «Así es» aprueba las horas que reparte, en
-- la misma transacción. Sin él (falso, de fábrica), todas: para mirar.
-- (La versión de antes, de cuatro parámetros, se quita: la de cinco con su
-- valor de fábrica contesta igual a quien la llama con cuatro.)
drop function if exists public.fn_jornal_repartir(uuid, date, date, numeric);
create or replace function public.fn_jornal_repartir(p_usuario uuid, p_desde date, p_hasta date, p_monto numeric,
                                                     p_solo_aprobadas boolean default false)
returns table (grupo int, proyecto_id text, co text, horas_grupo numeric, monto_grupo numeric(14,2),
               horas_id bigint, fecha date, fase text, horas numeric, monto numeric(14,2),
               horas_total numeric, monto_total numeric(14,2))
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
begin
  perform fn_jornal_exigir_dueno();
  if p_usuario is null or p_desde is null or p_hasta is null or p_desde > p_hasta then
    raise exception using errcode = '22023',
      message = 'El reparto es de una persona en un período: usuario, desde y hasta (desde ≤ hasta), y el monto.';
  end if;
  return query
  select a.* from fn_jornal_repartir_ids(array(select x.id from public.horas x
                                                where x.usuario_id = p_usuario and x.fecha between p_desde and p_hasta
                                                  and (not coalesce(p_solo_aprobadas, false) or x.aprobado_el is not null)), p_monto) a;
end $$;
revoke execute on function public.fn_jornal_repartir(uuid, date, date, numeric, boolean) from public, anon, service_role;
grant  execute on function public.fn_jornal_repartir(uuid, date, date, numeric, boolean) to authenticated;
comment on function public.fn_jornal_repartir(uuid, date, date, numeric, boolean) is 'c10: EL NÚCLEO (lo que f11 alimentará con el journal de nómina): las horas de una persona en un período —todas, o solo las aprobadas con p_solo_aprobadas—, agrupadas por obra y CO, y la parte de un monto que le toca a cada grupo y a cada reporte, al centavo (fn_jornal_repartir_ids). Solo lee; no sabe nada del banco. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 5b. LO QUE SE QUEDA FUERA DE LOS REPARTOS. Tres lecturas que usan a la
--     vez la propuesta, el control y el margen (una sola cuenta para los
--     tres), de tres cosas que pasaban calladas, con todo en verde:
--       · las horas que llegan TARDE a una semana ya repartida;
--       · el pago de una persona dada de alta que se resolvió en la Bandeja
--         por OTRO camino (clasificado a mano, o aprobada la propuesta de
--         la IA): su costo queda entero en una obra, sin su nombre, y sus
--         horas salen además a estándar;
--       · las propuestas de la IA (c8) de un pago que se reparte por horas.
--     SECURITY INVOKER y solo lectura: leen con la policy de quien llama, y
--     a quien no es el dueño no le devuelven nada (fn_jornal_ve).
-- ---------------------------------------------------------------------
-- LAS HORAS TARDÍAS: reportes de una persona con fecha DENTRO de un reparto
-- suyo aplicado (con su asiento vivo) que no están en ningún reparto
-- aplicado. Al repartir entran todas las horas de esas fechas que no
-- tienen ya otro pago; las que aparecen después (se reportaron tarde, se
-- les cambió la fecha, o se deshizo el otro reparto que las cubría) no
-- recibieron nada: el pago de esa semana sigue repartido entre las demás
-- obras —de más— y estas salen a estándar —encima—. Se arregla deshaciendo
-- aquel reparto y repitiéndolo con las horas de hoy, o metiéndolas en el
-- pago que las cubra (con sus fechas). Una fila por reporte, con el reparto
-- en cuyas fechas cae (el más antiguo, si caen en varios).
-- (v3) Las que después pagó una NÓMINA ya no son tardías: tienen su pago, y
-- en su obra salen con pago real, no a estándar.
create or replace function public.fn_jornal_tardias(p_usuario uuid default null)
returns table (horas_id bigint, usuario_id uuid, persona text, fecha date, proyecto_id text, obra text, horas numeric,
               reparto_id uuid, fecha_pago date, desde date, hasta date)
language sql stable
set search_path = public, pg_temp
as $$
  select distinct on (h.id)
         h.id, h.usuario_id, pf.nombre, h.fecha, h.proyecto_id, pr.nombre, h.horas, r.id, m.fecha, r.desde, r.hasta
    from public.jornal_repartos r
    join public.horas h on h.usuario_id = r.usuario_id and h.fecha between r.desde and r.hasta and h.horas > 0 and h.horas < 100000
    left join public.perfiles pf on pf.id = h.usuario_id
    left join public.proyectos pr on pr.id = h.proyecto_id
    left join public.movimientos_banco m on m.id = r.movimiento_id
   where r.estado = 'aplicado'
     and (p_usuario is null or r.usuario_id = p_usuario)
     and not exists (select 1 from public.asientos x where x.reversa_a = r.asiento_id and x.camino = 'reverso')
     and not exists (select 1 from public.jornal_reparto_horas rh join public.jornal_repartos r2 on r2.id = rh.reparto_id
                      where rh.horas_id = h.id and r2.estado = 'aplicado')
     and h.id not in (select n.horas_id from public.fn_margen_horas_nomina() n)
     and (select public.fn_jornal_ve())
   order by h.id, r.creado_el, r.id
$$;
revoke execute on function public.fn_jornal_tardias(uuid) from public, anon, service_role;
grant  execute on function public.fn_jornal_tardias(uuid) to authenticated;
comment on function public.fn_jornal_tardias(uuid) is 'c10: las horas tardías (de todos, o de una persona): reportes con fecha dentro de un reparto suyo aplicado y vivo que no están en ningún reparto aplicado ni los pagó una nómina (se reportaron o se movieron después de repartir esa semana, o se deshizo el reparto que las cubría), cada uno con el reparto en cuyas fechas cae. Las leen la propuesta (aviso horas_tardias), el control del jornal (35) y el margen. Solo lectura; a quien no es el dueño, nada.';

-- LOS PAGOS RESUELTOS POR FUERA: movimientos del banco ya casados por otro
-- camino (clasificados a mano, aprobada la propuesta de la IA, casados con
-- un papel), desde que empieza el libro, que el banco describe como el pago
-- de una persona ACTIVA del jornal, sin reparto aplicado, y con horas de esa
-- persona sin pago real en la semana del pago o en la anterior (las dos que
-- ofrece la propuesta). Si era su pago por horas, su costo está entero en
-- otra parte del libro (en una obra, o en ninguna; y sin su nombre: el 1099
-- por tercero no lo suma) y esas horas, además, salen a estándar. Si la
-- persona no tiene horas sin pago en esas semanas no sale: no hay nada que
-- repartir (es lo que la propia propuesta manda hacer con un pago sin
-- horas: clasificarlo en la Bandeja). Una fila por pago y obra con horas
-- sin pago (proyecto_id vacío: las horas sin obra).
-- (v3) Las horas que pagó una NÓMINA tienen su pago: no cuentan aquí (el
-- Zelle a alguien que ya cobra por nómina —un bono, un reembolso— que se
-- clasificó en la Bandeja no deja ninguna hora suya sin pagar).
create or replace function public.fn_jornal_fuera()
returns table (movimiento_id uuid, fecha date, monto numeric(14,2), descripcion text, resuelto_como text, asiento text,
               usuario_id uuid, persona text, desde date, hasta date, proyecto_id text, obra text, horas numeric)
language sql stable
set search_path = public, pg_temp
as $$
  with lb as materialized (select public.fn_margen_libro_desde() as d),
       jp as materialized (select x.usuario_id, x.patron from public.jornal_personas x where x.activa),
       -- (los candidatos: el texto de cada movimiento se arma UNA vez, y sin
       -- personas activas no se lee ni un movimiento)
       mv as materialized (
         select m.id, m.fecha, (-m.monto)::numeric(14,2) as monto, m.descripcion,
                coalesce(m.casado_regla, m.casado_clase, m.estado) as como, m.asiento_id, j.usuario_id,
                m.fecha - (extract(isodow from m.fecha)::int - 1) as lunes
           from public.movimientos_banco m
           cross join lb
           cross join lateral (select public.fn_jornal_texto(m.desc_norm, m.memo) as t offset 0) x
           join jp j on x.t ~* j.patron
          where (select count(*) from jp) > 0
            and m.estado = 'casado' and m.monto < 0 and m.fecha >= lb.d
            and not exists (select 1 from public.jornal_repartos r where r.movimiento_id = m.id and r.estado = 'aplicado'))
  select mv.id, mv.fecha, mv.monto, mv.descripcion, mv.como, a.numero, mv.usuario_id, pf.nombre, mv.lunes - 7, mv.lunes + 6,
         h.proyecto_id, pr.nombre, sum(h.horas)
    from mv
    cross join lb
    join public.horas h on h.usuario_id = mv.usuario_id and h.fecha between mv.lunes - 7 and mv.lunes + 6
                       and h.fecha >= lb.d and h.horas > 0 and h.horas < 100000
    left join public.perfiles pf on pf.id = mv.usuario_id
    left join public.proyectos pr on pr.id = h.proyecto_id
    left join public.asientos a on a.id = mv.asiento_id
   where not exists (select 1 from public.jornal_reparto_horas rh join public.jornal_repartos r on r.id = rh.reparto_id
                      where rh.horas_id = h.id and r.estado = 'aplicado')
     and h.id not in (select n.horas_id from public.fn_margen_horas_nomina() n)
     and (select public.fn_jornal_ve())
   group by mv.id, mv.fecha, mv.monto, mv.descripcion, mv.como, a.numero, mv.usuario_id, pf.nombre, mv.lunes, h.proyecto_id, pr.nombre
$$;
revoke execute on function public.fn_jornal_fuera() from public, anon, service_role;
grant  execute on function public.fn_jornal_fuera() to authenticated;
comment on function public.fn_jornal_fuera() is 'c10: los pagos resueltos por fuera del jornal: movimientos ya casados por otro camino, desde que empieza el libro, que el banco describe como el pago de una persona activa del jornal, sin reparto aplicado, y con horas de esa persona sin pago real (ni un reparto aplicado ni una nómina que las pagara) en la semana del pago o en la anterior; una fila por pago y obra con esas horas. Los leen el control del jornal (70, un aviso) y el margen. Solo lectura; a quien no es el dueño, nada.';

-- LAS PROPUESTAS DE LA IA (c8) QUE UN JORNAL DEJARÍA ABIERTAS. c8 no sabe de
-- c10 (está sellado) y su rutina propone para todo lo pendiente, también
-- para estos Zelle. Cuando el pago se reparte por horas, la propuesta de la
-- IA de ese movimiento ya no se puede aprobar (el movimiento queda casado) y
-- c8 no la cierra sola: «pendiente», enciende su alarma 71 a los 7 días y
-- su cuadre 64 —que el cierre de c9 toma por «detiene»— el día que la obra
-- que proponía se termina; «aprobada» o «editada» con su asiento ya
-- reversado (Edgar la había aceptado y después des-casó el pago para
-- repartirlo), deja su cuadre 60 en rojo. Solo la función de borde
-- «contador» (o el SQL Editor) las cierra: «No es eso» (rechazar) la
-- pendiente, «caducar» la otra; c10 no puede (ni debe) escribir en c8. Aquí
-- se LEEN, para que fn_jornal_aplicar no deje una pendiente detrás, la
-- pantalla sepa cuáles cerrar y el control diga las que quedaron.
--   clase 'pendiente'    la propuesta pendiente del movimiento (una como mucho)
--   clase 'sin_asiento'  aprobada o editada, con su asiento reversado o sin él
-- De un movimiento, o —sin decir cuál— de todos los que tienen un reparto
-- aplicado. Sin c8 en la base (o si su tabla cambia de forma), nada.
create or replace function public.fn_jornal_ia(p_movimiento uuid default null)
returns table (movimiento_id uuid, propuesta_id uuid, clase text, estado text, resumen text, asiento text)
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if to_regclass('public.contador_propuestas') is null or not fn_jornal_ve() then
    return;
  end if;
  begin
    return query execute $q$
      select p.movimiento_id, p.id,
             case when p.estado = 'pendiente' then 'pendiente' else 'sin_asiento' end,
             p.estado,
             (select string_agg((l.x->>'cuenta') || coalesce(' → ' || pr.nombre, ''), ' + ' order by l.o)
                from jsonb_array_elements(case when jsonb_typeof(p.propuesta->'lineas') = 'array' then p.propuesta->'lineas'
                                               else '[]'::jsonb end) with ordinality as l(x, o)
                left join public.proyectos pr on pr.id = l.x->>'proyecto_id'),
             a.numero
        from public.contador_propuestas p
        left join public.asientos a on a.id = p.asiento_id
       where ($1::uuid is null or p.movimiento_id = $1::uuid)
         and ($1::uuid is not null
              or exists (select 1 from public.jornal_repartos r where r.movimiento_id = p.movimiento_id and r.estado = 'aplicado'))
         and (p.estado = 'pendiente'
              or (p.estado in ('aprobada', 'editada')
                  and (a.id is null
                       or exists (select 1 from public.asientos rv
                                   where rv.reversa_a = a.id and rv.camino in ('reverso', 'reverso_automatico')))))
       order by p.creado_el, p.id $q$ using p_movimiento;
  exception when others then
    -- (c8 cambió de forma: c10 no se cae por eso; lo suyo lo dice su control)
    return;
  end;
end $$;
revoke execute on function public.fn_jornal_ia(uuid) from public, anon, service_role;
grant  execute on function public.fn_jornal_ia(uuid) to authenticated;
comment on function public.fn_jornal_ia(uuid) is 'c10: las propuestas de la IA (c8) que un jornal dejaría abiertas, de un movimiento o de todos los que tienen un reparto aplicado: la pendiente (clase pendiente: se rechaza, «No es eso») y las aprobadas o editadas cuyo asiento ya no vive (clase sin_asiento: se caducan), con lo que proponían. Las cierra la función de borde «contador», no c10. Sin c8 en la base, nada. Solo lectura; a quien no es el dueño, nada.';


-- ---------------------------------------------------------------------
-- 6. EL JORNAL DEL ZELLE, lo que solo lee: las opciones, el cálculo (uno
--    solo: lo usan la propuesta, aplicar y la vista de pendientes) y
--    fn_jornal_propuesta.
-- ---------------------------------------------------------------------
-- Las opciones de un reparto, validadas: incluir_cubiertas (repartir también
-- por las horas que ya tienen otro pago: «es otro pago de la misma semana»)
-- y motivo (el motivo escrito de Edgar, que es el de c6: lo que deja pasar
-- sus frenos de «si de verdad es otra cosa, dilo en el motivo»). Una clave
-- desconocida, 22023: un «inclur_cubiertas» mal escrito no pasa callado.
create or replace function public.fn_jornal_opciones(p jsonb) returns jsonb
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  v_sobra text;
begin
  if p is null or jsonb_typeof(p) = 'null' then
    return jsonb_build_object('incluir_cubiertas', false);
  end if;
  if jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023',
      message = 'Las opciones llegan como un objeto JSON: {"incluir_cubiertas": true, "motivo": "…"} (las dos, opcionales).';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(p) k where k not in ('incluir_cubiertas', 'motivo');
  if v_sobra is not null then
    raise exception using errcode = '22023',
      message = format('Opción desconocida: %s. Las que hay: incluir_cubiertas (true o false) y motivo (un texto).', v_sobra);
  end if;
  if p ? 'incluir_cubiertas' and jsonb_typeof(p->'incluir_cubiertas') not in ('boolean', 'null') then
    raise exception using errcode = '22023', message = 'incluir_cubiertas es true o false.';
  end if;
  if p ? 'motivo' and jsonb_typeof(p->'motivo') not in ('string', 'null') then
    raise exception using errcode = '22023', message = 'motivo es un texto.';
  end if;
  return jsonb_strip_nulls(jsonb_build_object('incluir_cubiertas', coalesce((p->>'incluir_cubiertas')::boolean, false),
                                              'motivo', left(nullif(btrim(p->>'motivo'), ''), 500)));
end $$;
revoke execute on function public.fn_jornal_opciones(jsonb) from public, anon, service_role;
grant  execute on function public.fn_jornal_opciones(jsonb) to authenticated;
comment on function public.fn_jornal_opciones(jsonb) is 'c10: las opciones de un reparto, validadas y en su forma: {incluir_cubiertas, motivo}. Una clave desconocida o un tipo mal, 22023.';

-- EL CÁLCULO de un pago: ¿es de una persona dada de alta?, su período, sus
-- horas, las líneas, los avisos, si se puede aplicar y la huella de lo que
-- entra. SOLO LEE, con la policy de quien llama: no frena a nadie (a quien
-- no es el dueño el banco no le enseña el movimiento, y contesta «no
-- existe»). Sin fechas, el período por defecto (fn_jornal_periodo con la
-- fecha del movimiento). Lo que devuelve, en fn_jornal_propuesta.
create or replace function public.fn_jornal_calcular(p_movimiento uuid, p_desde date, p_hasta date,
                                                     p_opciones jsonb default '{}'::jsonb)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  m          movimientos_banco;
  cfg        jornal_config;
  jp         jornal_personas;
  pf         perfiles;
  rp         jornal_repartos;
  v_mov      jsonb;
  v_txt      text;
  v_n        int;
  v_nombres  text;
  v_tarifa   numeric;
  v_cuenta   text;
  v_def      record;
  v_mes      record;
  v_lunes    date;
  v_desde    date;
  v_hasta    date;
  v_regla    text;
  v_incl     boolean := coalesce((p_opciones->>'incluir_cubiertas')::boolean, false);
  v_monto    numeric(14,2);
  v_ids      bigint[];
  v_tot_n    int;
  v_cub_n    int;
  v_cub_h    numeric;
  v_cub      jsonb;
  v_cub_txt  text;
  v_horas    numeric := 0;
  v_rep_n    int := 0;
  v_obras    int := 0;
  v_lineas   jsonb := '[]'::jsonb;
  v_sin      jsonb;
  v_det      jsonb := '[]'::jsonb;
  v_avisos   jsonb := '[]'::jsonb;
  v_puede    boolean := true;
  v_porque   text;
  v_sale     numeric;
  v_desvio   numeric;
  v_visto    text;
  v_x        text;
  v_y        text;
  v_j        jsonb;
  v_d        date;
  v_pia      uuid;
  v_iac      jsonb := '[]'::jsonb;
  v_ops      jsonb;
  v_apr      bigint[];
  v_fa       date;
  v_h2       numeric;
  v_m2       numeric;
  v_b        boolean;
  v_d2       date;
  v_d3       date;
  v_h3       numeric;
  v_m3       numeric;
  v_nom      bigint[];
begin
  select * into m from movimientos_banco where id = p_movimiento;
  if not found then
    return jsonb_build_object('reconocido', false, 'por_que', 'No existe ese movimiento del banco.');
  end if;
  v_mov := jsonb_build_object('id', m.id, 'fecha', m.fecha, 'monto', abs(m.monto), 'cuenta', m.cuenta,
                              'descripcion', m.descripcion, 'estado', m.estado);
  if m.monto >= 0 then
    return jsonb_build_object('reconocido', false, 'movimiento', v_mov,
                              'por_que', 'Es un abono (dinero que entra): un jornal es un pago que sale.');
  end if;
  select * into rp from jornal_repartos r where r.movimiento_id = m.id and r.estado = 'aplicado';
  if m.estado <> 'pendiente' then
    return jsonb_strip_nulls(jsonb_build_object(
      'reconocido', false, 'movimiento', v_mov,
      'reparto', case when rp.id is not null
                      then jsonb_build_object('reparto_id', rp.id, 'asiento_id', rp.asiento_id, 'desde', rp.desde, 'hasta', rp.hasta) end,
      'por_que', case when rp.id is not null and m.asiento_id = rp.asiento_id
                      then format('Este pago ya está repartido (%s, asiento %s). Si estaba mal, deshazlo con su motivo y vuelve a '
                                  'repartirlo.', fn_jornal_rango(rp.desde, rp.hasta),
                                  coalesce((select a.numero from asientos a where a.id = rp.asiento_id), '?'))
                      else format('Este movimiento ya está resuelto en el banco (%s): no está en la Bandeja. Si estaba mal, primero '
                                  'se des-casa allí, con su motivo.', coalesce(m.casado_regla, m.estado_motivo, m.estado)) end));
  end if;

  -- ¿De quién es? El patrón de UNA persona activa contra lo que dice el banco.
  v_txt := fn_jornal_texto(m.desc_norm, m.memo);
  select count(*), string_agg(coalesce(p.nombre, '(sin nombre)'), ' y ' order by p.nombre, x.usuario_id)
    into v_n, v_nombres
    from jornal_personas x
    left join perfiles p on p.id = x.usuario_id
   where x.activa and v_txt ~* x.patron;
  if v_n = 0 then
    return jsonb_strip_nulls(jsonb_build_object(
      'reconocido', false, 'movimiento', v_mov,
      'por_que', 'No es el pago de nadie dado de alta para repartir por horas. Si es de alguien de la cuadrilla con horas en la '
                 'app, dalo de alta y sus pagos se reconocerán solos.',
      'patron_sugerido', fn_jornal_patron_sugerido(m.id),
      -- (a quién se parece: los perfiles activos, sin dar de alta, cuyo nombre de pila sale en la descripción)
      'candidatos', (select jsonb_agg(jsonb_build_object('usuario_id', q.id, 'nombre', q.nombre, 'rol', q.rol) order by q.nombre, q.id)
                       from (select p.id, p.nombre, p.rol,
                                    upper(translate(split_part(btrim(p.nombre), ' ', 1), 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN')) as pila
                               from perfiles p
                              where p.rol <> 'dueno' and coalesce(p.activo, true)
                                and not exists (select 1 from jornal_personas j where j.usuario_id = p.id and j.activa)) q
                      where q.pila ~ '^[A-Z]{3,}$' and v_txt ~ ('\m' || q.pila || '\M'))));
  end if;
  if v_n > 1 then
    return jsonb_build_object(
      'reconocido', false, 'movimiento', v_mov,
      'por_que', format('El banco lo describe de una forma que casa con %s personas dadas de alta (%s): afina el patrón de una de '
                        'ellas para que no se pisen.', v_n, v_nombres));
  end if;
  select x.* into jp from jornal_personas x where x.activa and v_txt ~* x.patron;
  select * into pf from perfiles where id = jp.usuario_id;
  select ce.costo_hora into v_tarifa from costos_equipo ce where ce.usuario_id = jp.usuario_id;
  select * into cfg from jornal_config where id = 1;
  v_cuenta := coalesce(jp.cuenta, cfg.cuenta_defecto);
  v_monto  := abs(m.monto);

  -- (v3) Los reportes de horas de esta persona que ya pagó una nómina (c15, si
  -- está): leídos una vez. No cambian QUÉ horas entran en un reparto —eso
  -- sigue como en la v2—; solo qué se dice de ellas (las «sin pago» de cada
  -- semana y el aviso pagadas_por_nomina, abajo).
  -- (La lista de la nómina, como expresión con su tabla hash y no como cruce:
  -- ver fn_margen_horas.)
  select coalesce(array_agg(h.id), '{}') into v_nom
    from horas h
   where h.usuario_id = jp.usuario_id
     and (h.id in (select n.horas_id from fn_margen_horas_nomina() n)) is true;

  -- El período: el que se pide, o el de la regla (según el día del pago).
  select * into v_def from fn_jornal_periodo(m.fecha);
  v_desde := coalesce(p_desde, v_def.desde);
  v_hasta := coalesce(p_hasta, v_def.hasta);
  v_regla := fn_jornal_regla(m.fecha, v_desde, v_hasta);
  v_lunes := m.fecha - (extract(isodow from m.fecha)::int - 1);
  select coalesce(jsonb_agg(jsonb_build_object(
           'regla', o.regla, 'desde', o.desde, 'hasta', o.hasta, 'por_defecto', o.regla = v_def.regla,
           'horas', (select coalesce(sum(h.horas), 0) from horas h
                      where h.usuario_id = jp.usuario_id and h.fecha between o.desde and o.hasta and h.horas > 0 and h.horas < 100000),
           'horas_sin_pago', (select coalesce(sum(h.horas), 0) from horas h
                               where h.usuario_id = jp.usuario_id and h.fecha between o.desde and o.hasta and h.horas > 0
                                 and h.horas < 100000 and not (h.id = any (v_nom))
                                 and not exists (select 1 from jornal_reparto_horas rh join jornal_repartos r on r.id = rh.reparto_id
                                                  where rh.horas_id = h.id and r.estado = 'aplicado'))) order by o.desde), '[]'::jsonb)
    into v_ops
    from (values ('semana_anterior', v_lunes - 7, v_lunes - 1), ('semana_en_curso', v_lunes, v_lunes + 6)) as o(regla, desde, hasta);

  -- Sus horas de esas fechas: las que entran (las que no tienen ya otro pago
  -- repartido, salvo que se pida) y las ya cubiertas.
  select coalesce(array_agg(h.id order by h.id) filter (where c.n is null or v_incl), '{}'),
         count(*), count(*) filter (where c.n is not null), coalesce(sum(h.horas) filter (where c.n is not null), 0)
    into v_ids, v_tot_n, v_cub_n, v_cub_h
    from horas h
    left join lateral (select 1 as n
                        where exists (select 1 from jornal_reparto_horas rh join jornal_repartos r on r.id = rh.reparto_id
                                       where rh.horas_id = h.id and r.estado = 'aplicado')) c on true
   where h.usuario_id = jp.usuario_id and h.fecha between v_desde and v_hasta and h.horas > 0 and h.horas < 100000;
  -- LO QUE EL «ASÍ ES» APROBARÁ: todos sus reportes de esas fechas que hoy
  -- están sin aprobar, ENTREN O NO en este reparto (c3 aprueba por persona y
  -- fechas, y pide exactamente esa lista: fn_horas_aprobar). Los que no
  -- entran —los que ya cubre otro pago— y están sin aprobar (cambiaron
  -- después de repartirse, o se les retiró la aprobación) van también en la
  -- huella y en un aviso: Edgar no aprueba nada que no haya visto.
  select coalesce(array_agg(h.id order by h.id), '{}') into v_apr
    from horas h
   where h.usuario_id = jp.usuario_id and h.fecha between v_desde and v_hasta and h.aprobado_el is null;

  -- El reparto (el núcleo), las líneas por obra y CO, lo sin obra, y el
  -- detalle de TODOS los reportes de esas fechas (los que entran, con su
  -- parte; los que no, dicho).
  with a as materialized (select * from fn_jornal_repartir_ids(v_ids, v_monto)),
       g as (select distinct a.grupo, a.proyecto_id, a.co, a.horas_grupo, a.monto_grupo from a)
  select (select coalesce(jsonb_agg(jsonb_build_object('n', g.grupo, 'proyecto_id', g.proyecto_id, 'obra', coalesce(pr.nombre, g.proyecto_id),
                                                       'obra_estado', pr.estado, 'co', g.co, 'horas', g.horas_grupo,
                                                       'monto', g.monto_grupo, 'cuenta', v_cuenta) order by g.grupo), '[]'::jsonb)
            from g left join proyectos pr on pr.id = g.proyecto_id
           where g.proyecto_id is not null),
         (select jsonb_build_object('n', g.grupo, 'horas', g.horas_grupo, 'monto', g.monto_grupo, 'cuenta', cfg.cuenta_sin_obra,
                                    'falta_cuenta', cfg.cuenta_sin_obra is null)
            from g where g.proyecto_id is null),
         coalesce((select max(a.horas_total) from a), 0),
         (select count(*) from a),
         (select count(distinct g.proyecto_id) from g where g.proyecto_id is not null),
         (select coalesce(jsonb_agg(jsonb_build_object(
                    'horas_id', h.id, 'fecha', h.fecha, 'proyecto_id', h.proyecto_id, 'obra', pr.nombre,
                    'co', case when h.proyecto_id is null then null else fn_jornal_limpio(h.co) end,
                    'fase', fn_jornal_limpio(h.fase), 'horas', h.horas, 'aprobada', h.aprobado_el is not null,
                    'entra', a.horas_id is not null, 'monto', a.monto, 'n', a.grupo,
                    'cubierta_por', (select jsonb_agg(rh.reparto_id order by r.creado_el, r.id)
                                       from jornal_reparto_horas rh join jornal_repartos r on r.id = rh.reparto_id
                                      where rh.horas_id = h.id and r.estado = 'aplicado')) order by h.fecha, h.id), '[]'::jsonb)
            from horas h
            left join a on a.horas_id = h.id
            left join proyectos pr on pr.id = h.proyecto_id
           where h.usuario_id = jp.usuario_id and h.fecha between v_desde and v_hasta and h.horas > 0 and h.horas < 100000)
    into v_lineas, v_sin, v_horas, v_rep_n, v_obras, v_det;

  -- Lo ya cubierto por otro pago, con cuál.
  if v_cub_n > 0 then
    select jsonb_build_object('horas', v_cub_h, 'reportes', v_cub_n, 'incluidas', v_incl,
                              'repartos', coalesce(jsonb_agg(jsonb_build_object('reparto_id', q.id, 'fecha_pago', q.fecha, 'monto', q.monto,
                                                                                'desde', q.desde, 'hasta', q.hasta, 'horas', q.h)
                                                             order by q.fecha, q.id), '[]'::jsonb)),
           string_agg(format('el del pago del %s (%s, %s)', fn_jornal_dia(q.fecha), fn_jornal_usd(q.monto),
                             fn_jornal_rango(q.desde, q.hasta)), '; ' order by q.fecha, q.id)
      into v_cub, v_cub_txt
      from (select r.id, mm.fecha, r.monto, r.desde, r.hasta, sum(rh.horas) as h
              from jornal_reparto_horas rh
              join jornal_repartos r on r.id = rh.reparto_id and r.estado = 'aplicado'
              join movimientos_banco mm on mm.id = r.movimiento_id
              join horas h on h.id = rh.horas_id
             where h.usuario_id = jp.usuario_id and h.fecha between v_desde and v_hasta
             group by r.id, mm.fecha, r.monto, r.desde, r.hasta) q;
  end if;

  -- LOS AVISOS, en llano, y lo que no deja aplicar.
  if v_horas = 0 then
    v_puede := false;
    v_porque := case when v_tot_n = 0
                     then format('%s no tiene horas reportadas %s. Elige otras fechas (la semana anterior, esta semana, o a mano); '
                                 'si este pago no es por horas, clasifícalo en la Bandeja como siempre.',
                                 pf.nombre, fn_jornal_rango(v_desde, v_hasta))
                     else format('Las %s h de %s %s ya entraron en otro reparto: %s. Si este es OTRO pago de esas mismas horas (un '
                                 'adelanto y el resto), repártelo también por ellas; si no, elige otras fechas.',
                                 fn_jornal_h(v_cub_h), pf.nombre, fn_jornal_rango(v_desde, v_hasta), v_cub_txt) end;
    v_avisos := v_avisos || jsonb_build_object('codigo', 'sin_horas', 'corto', 'Sin horas en esas fechas', 'texto', v_porque);
  elsif v_cub_n > 0 then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'horas_cubiertas', 'corto', 'Parte de las horas ya tiene otro pago', 'texto',
      case when v_incl
           then format('%s h de esas fechas ya estaban en otro reparto (%s) y entran también en este, porque lo pediste: es otro pago '
                       'de las mismas horas.', fn_jornal_h(v_cub_h), v_cub_txt)
           else format('%s h de esas fechas ya las cubre otro pago (%s): no entran en este reparto, que va solo por las %s h que '
                       'faltaban.', fn_jornal_h(v_cub_h), v_cub_txt, fn_jornal_h(v_horas)) end);
  end if;
  -- Reportes de esas fechas que NO entran aquí (ya los cubre otro pago) y hoy
  -- están sin aprobar: el «Así es» los aprueba igual (c3 aprueba por persona y
  -- fechas), Edgar lo ve antes, y van en la huella.
  select count(*),
         left(string_agg(format('%s h del %s%s', fn_jornal_h(h.horas), fn_jornal_dia(h.fecha), coalesce(' en ' || pr.nombre, ' sin obra')),
                         '; ' order by h.fecha, h.id), 600),
         coalesce(jsonb_agg(h.id order by h.id), '[]'::jsonb)
    into v_n, v_x, v_j
    from horas h
    left join proyectos pr on pr.id = h.proyecto_id
   where h.id = any (v_apr) and not (h.id = any (v_ids));
  if v_n > 0 then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'cubiertas_sin_aprobar', 'corto', 'Hay horas de otro pago sin aprobar',
      'horas_ids', v_j, 'texto',
      format('%s reporte(s) de esas fechas que no entran en este reparto están sin aprobar (ya los cubre otro pago, y cambiaron después '
             'o se les quitó la aprobación): %s. Al aceptar quedan aprobados como están hoy. El reparto que los cubre sigue hecho con '
             'las horas de antes: lo dice el control del jornal.', v_n, v_x));
  end if;
  -- Horas suyas de una semana YA repartida que no están en ningún reparto
  -- (llegaron tarde) y que tampoco entran en este: ningún pago las recoge
  -- solo. Con las fechas que las cogerían (desde, hasta), para ofrecerlas.
  select count(*), coalesce(sum(t.horas), 0),
         left(string_agg(format('%s h del %s%s (semana del pago del %s)', fn_jornal_h(t.horas), fn_jornal_dia(t.fecha),
                                coalesce(' en ' || t.obra, ' sin obra'), fn_jornal_dia(t.fecha_pago)), '; ' order by t.fecha, t.horas_id), 600),
         min(t.fecha), max(t.fecha)
    into v_n, v_h2, v_x, v_d2, v_d3
    from fn_jornal_tardias(jp.usuario_id) t
   where not (t.horas_id = any (v_ids));
  if v_n > 0 then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'horas_tardias', 'corto', 'Tiene horas de una semana ya repartida sin pago',
      'horas', v_h2, 'reportes', v_n, 'desde', v_d2, 'hasta', v_d3, 'texto',
      format('%s tiene %s h de una semana ya repartida que no están en ningún reparto (se reportaron o se movieron después): %s. Si '
             'este pago las cubre, elige fechas que las incluyan (a mano, desde el %s); si no, deshaz aquel reparto y vuelve a '
             'repartirlo con las horas de hoy.', pf.nombre, fn_jornal_h(v_h2), v_x, fn_jornal_dia(v_d2, true)));
  end if;
  select string_agg(format('el del pago del %s (%s, %s)', fn_jornal_dia(mm.fecha), fn_jornal_usd(r.monto), fn_jornal_rango(r.desde, r.hasta)),
                    '; ' order by mm.fecha, r.id),
         jsonb_agg(r.id order by mm.fecha, r.id)
    into v_x, v_j
    from jornal_repartos r
    join movimientos_banco mm on mm.id = r.movimiento_id
   where r.usuario_id = jp.usuario_id and r.estado = 'aplicado' and r.desde <= v_hasta and r.hasta >= v_desde;
  if v_x is not null then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'se_pisa', 'corto', 'Se pisa con otro reparto', 'repartos', v_j, 'texto',
      format('Estas fechas se pisan con otro reparto de %s: %s. Mira que no sea la misma semana pagada dos veces.', pf.nombre, v_x));
  end if;
  if v_horas > 0 then
    v_sale := round(v_monto / v_horas, 2);
  end if;
  if v_tarifa is null then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'sin_tarifa', 'corto', 'Sin tarifa para comparar', 'texto',
      format('%s no tiene tarifa en Costos del equipo: no hay con qué comparar lo que sale por hora.', pf.nombre));
  elsif v_sale is not null and v_tarifa > 0 then
    v_desvio := round((v_sale / v_tarifa - 1) * 100, 1);
    if abs(v_desvio) > cfg.aviso_tarifa_pct then
      v_avisos := v_avisos || jsonb_build_object('codigo', 'tarifa_lejos', 'corto', 'La tarifa que sale se aleja de la suya', 'texto',
        -- (y si el Zelle lleva además otra cosa —un reembolso de material—, sale
        -- caro por hora: un pago se reparte entero, no hay cómo apartar una parte)
        format('Sale a %s la hora y su tarifa en Costos del equipo es %s (%s %% %s). Revisa las fechas (¿el pago es de otra semana, o '
               'de dos?) o las horas reportadas; y si el pago lleva además otra cosa (un reembolso de material), aquí iría entero a '
               'su mano de obra. Es solo un aviso: se puede repartir igual.', fn_jornal_usd(v_sale),
               fn_jornal_usd(v_tarifa), trim_scale(abs(v_desvio)), case when v_desvio > 0 then 'más' else 'menos' end));
    end if;
  end if;
  -- ¿Lo describe el banco como un pago a una persona? Un cargo en un comercio
  -- cuyo nombre lleva el de alguien («POS PURCHASE … ZZANA SUPPLY») casa con
  -- su patrón igual que su Zelle: se dice, para que no entre como jornal sin
  -- mirarlo. Un aviso, no un freno (un banco puede describir un pago de otra
  -- forma).
  if v_txt !~ '\m(ZELLE|TRANSFER|TRANSFERENCIA|PAYMENT|PMT|PAGO|CHECK|CHEQUE|ACH|WIRE|VENMO|PAYPAL|CASHAPP|P2P)\M'
     or v_txt ~ '\m(POS|PURCHASE|COMPRA|CARD|TARJETA)\M' then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'no_parece_pago', 'corto', 'No parece un pago a una persona', 'texto',
      format('El banco no lo describe como un pago a una persona (un Zelle, una transferencia, un cheque): «%s». Mira que no sea una '
             'compra en un comercio con un nombre parecido al de %s: si lo es, no lo repartas, clasifícalo en la Bandeja como siempre.',
             left(coalesce(m.descripcion, m.memo, ''), 80), pf.nombre));
  end if;
  select string_agg(distinct format('%s (%s)', x->>'obra', case x->>'obra_estado' when 'completado' then 'terminada' else 'no aprobada' end), '; ')
           filter (where x->>'obra_estado' in ('completado', 'no_aprobado')),
         coalesce(bool_or(x->>'obra_estado' = 'completado'), false),
         string_agg(distinct format('%s (%s)', x->>'obra', x->>'obra_estado'), '; ')
           filter (where x->>'obra_estado' in ('estimando', 'enviado'))
    into v_x, v_b, v_y
    from jsonb_array_elements(v_lineas) x;
  if v_x is not null then
    -- (terminada = completado; «no aprobada» = no_aprobado, como la llama la app)
    v_avisos := v_avisos || jsonb_build_object('codigo', 'obra_terminada',
      'corto', case when v_b then 'Hay una obra terminada' else 'Hay una obra no aprobada' end, 'texto',
      format('Hay horas en una obra que ya no está activa: %s. Su parte va a esa obra igual: el trabajo se hizo ahí.', v_x));
  end if;
  if v_y is not null then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'obra_sin_aprobar', 'corto', 'Hay una obra sin aprobar', 'texto',
      format('Hay horas en una obra que todavía no está aprobada: %s. Su parte va a esa obra.', v_y));
  end if;
  -- Dos CO de la misma obra que solo se distinguen por las mayúsculas, los
  -- espacios o un signo («co #1» y «CO #1»): el CO es texto libre (hasta que
  -- f10 les dé su lista) y salen como dos líneas. Se dice; no se adivina cuál
  -- es el bueno.
  select string_agg(format('%s: %s', q.obra, q.cos), '; ' order by q.obra)
    into v_x
    from (select x->>'obra' as obra, string_agg('«' || (x->>'co') || '»', ' y ' order by x->>'co') as cos
            from jsonb_array_elements(v_lineas) x
           where x->>'co' is not null
           group by x->>'proyecto_id', x->>'obra', upper(regexp_replace(x->>'co', '[^[:alnum:]]', '', 'g'))
          having count(*) > 1) q;
  if v_x is not null then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'co_parecidos', 'corto', 'Hay CO que parecen el mismo', 'texto',
      format('Hay CO escritos de dos formas en la misma obra (%s): salen como líneas distintas. Si son el mismo, corrígelo en Horas '
             'y vuelve a mirar.', v_x));
  end if;
  if v_sin is not null then
    if cfg.cuenta_sin_obra is null then
      v_x := format('%s h no tienen obra (les tocan %s) y no pueden ir a %s, que exige obra. Di una vez a qué cuenta va la mano de '
                    'obra sin obra (ajustes del jornal), o ponles su obra en Horas y vuelve a mirar.',
                    fn_jornal_h((v_sin->>'horas')::numeric), fn_jornal_usd((v_sin->>'monto')::numeric), v_cuenta);
      v_avisos := v_avisos || jsonb_build_object('codigo', 'falta_cuenta_sin_obra', 'corto', 'Falta la cuenta de lo sin obra', 'texto', v_x);
      if v_puede then v_puede := false; v_porque := v_x; end if;
    elsif fn_jornal_cuenta_mal(cfg.cuenta_sin_obra, 'sin_obra') is not null then
      v_x := format('La cuenta de lo sin obra ya no sirve: %s. Cámbiala en los ajustes del jornal.',
                    fn_jornal_cuenta_mal(cfg.cuenta_sin_obra, 'sin_obra'));
      v_avisos := v_avisos || jsonb_build_object('codigo', 'cuenta_mal', 'corto', 'Una cuenta ya no sirve', 'texto', v_x);
      if v_puede then v_puede := false; v_porque := v_x; end if;
    end if;
  end if;
  if jsonb_array_length(v_lineas) > 0 and fn_jornal_cuenta_mal(v_cuenta, 'obra') is not null then
    v_x := format('La cuenta del jornal de %s no sirve: %s. Cámbiala (la suya, o la de fábrica en los ajustes del jornal).',
                  pf.nombre, fn_jornal_cuenta_mal(v_cuenta, 'obra'));
    v_avisos := v_avisos || jsonb_build_object('codigo', 'cuenta_mal', 'corto', 'Una cuenta ya no sirve', 'texto', v_x);
    if v_puede then v_puede := false; v_porque := v_x; end if;
  end if;
  if m.posible_duplicado_de is not null and m.duplicado is null then
    v_x := 'El banco trajo este movimiento dos veces (se parece a otro que ya estaba) y falta decir si es el mismo: decídelo '
           'primero en la Bandeja.';
    v_avisos := v_avisos || jsonb_build_object('codigo', 'posible_duplicado', 'corto', 'Posible duplicado sin decidir', 'texto', v_x);
    if v_puede then v_puede := false; v_porque := v_x; end if;
  end if;
  -- LA FECHA CON QUE ENTRARÁ EL ASIENTO (la regla de c6 y c3 para todo lo que
  -- trae el banco: la del movimiento; con su mes ya cerrado, el primer día
  -- del primer mes abierto posterior).
  select p.periodo, p.estado into v_mes from periodos p where p.tipo <> 'anio' and m.fecha between p.desde and p.hasta;
  v_fa := m.fecha;
  if v_mes.estado = 'cerrado' then
    select min(p.desde) into v_d from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.desde > m.fecha;
    v_fa := coalesce(v_d, m.fecha);
    v_avisos := v_avisos || jsonb_build_object('codigo', 'mes_cerrado', 'corto', 'El mes del pago está cerrado', 'texto',
      format('El pago es del %s y ese mes ya está cerrado: el asiento entrará con fecha %s (el primer día del mes abierto), como '
             'todo lo que el banco trae tarde. El reparto sigue siendo por las horas de las fechas que elijas.',
             fn_jornal_dia(m.fecha, true), coalesce(fn_jornal_dia(v_d, true), '(no hay un mes abierto)')));
  end if;
  -- EL CORTE DE MES Y DE AÑO. El asiento entra el día del pago (el libro va
  -- por la fecha del banco, como QuickBooks): las horas de otro mes —o de
  -- otro año— dejan su costo en el mes del pago. Se dice, con cuántas horas y
  -- cuánto; no se frena. Lo del año es lo que le importa al CPA (el ejercicio
  -- fiscal): si quiere ese costo en el año en que se trabajó, es un ajuste
  -- suyo de fin de año (o el devengo de diciembre de c3, que ya no choca con
  -- un pago hecho en enero: abajo).
  select coalesce(sum(q.h) filter (where q.otro_anio), 0), coalesce(sum(q.m) filter (where q.otro_anio), 0),
         string_agg(distinct q.anio, ' y ' order by q.anio) filter (where q.otro_anio),
         coalesce(sum(q.h), 0), coalesce(sum(q.m), 0), string_agg(fn_jornal_mes(q.mes), ' y ' order by q.mes)
    into v_h2, v_m2, v_y, v_h3, v_m3, v_x
    from (select date_trunc('month', (x->>'fecha')::date)::date as mes, min(to_char((x->>'fecha')::date, 'YYYY')) as anio,
                 bool_or(to_char((x->>'fecha')::date, 'YYYY') <> to_char(v_fa, 'YYYY')) as otro_anio,
                 sum((x->>'horas')::numeric) as h, sum((x->>'monto')::numeric) as m
            from jsonb_array_elements(v_det) x
           where (x->>'entra')::boolean and to_char((x->>'fecha')::date, 'YYYY-MM') <> to_char(v_fa, 'YYYY-MM')
           group by 1) q;
  if v_h2 > 0 then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'otro_anio', 'corto', 'Horas de otro año', 'horas', v_h2, 'monto', v_m2,
      'fecha_asiento', v_fa, 'texto',
      format('%s h de este pago (%s) se trabajaron en %s y el asiento entra el %s: su costo queda en el ejercicio %s (el libro va por '
             'la fecha del pago, como QuickBooks). Si el CPA quiere ese costo en el año en que se trabajó, es un ajuste suyo de fin de '
             'año: díselo. Es solo un aviso.', fn_jornal_h(v_h2), fn_jornal_usd(v_m2), v_y, fn_jornal_dia(v_fa, true),
             to_char(v_fa, 'YYYY')));
  elsif v_h3 > 0 then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'otro_mes', 'corto', 'Horas de otro mes', 'horas', v_h3, 'monto', v_m3,
      'fecha_asiento', v_fa, 'texto',
      format('%s h de este pago (%s) se trabajaron en %s y el asiento entra el %s: su costo queda en %s (el libro va por la fecha del '
             'pago, como QuickBooks). Es solo un aviso.', fn_jornal_h(v_h3), fn_jornal_usd(v_m3), v_x, fn_jornal_dia(v_fa, true),
             fn_jornal_mes(v_fa)));
  end if;
  -- EL DEVENGO ESTÁNDAR (c3, fn_horas_devengar: opcional) pone en su mes lo
  -- trabajado y TODAVÍA NO PAGADO, y se deshace solo el día 1 del mes
  -- siguiente. Doble es solo esto: una hora que entra en este reparto está en
  -- el documento de un devengo vivo, y este pago entra al libro DENTRO del
  -- mes de ese devengo (o antes). Un pago que entra después —el lunes
  -- siguiente al fin de mes— no choca: ese mes lleva el devengo, y el
  -- siguiente su reverso y el pago real.
  select string_agg(format('%s (asiento %s)', q.mes, q.numero), ', ' order by q.mes, q.numero), coalesce(sum(q.h), 0)
    into v_x, v_h2
    from (select a.origen_id as mes, a.numero, sum(h.horas) as h
            from asientos a
            cross join lateral jsonb_array_elements(case when jsonb_typeof(a.procedencia->'documento'->'horas') = 'array'
                                                         then a.procedencia->'documento'->'horas' else '[]'::jsonb end) d
            join horas h on h.id = (case when d->>'horas_id' ~ '^-?[0-9]{1,18}$' then (d->>'horas_id')::bigint end)
           where a.origen_tabla = 'horas_devengo' and a.camino not in ('reverso', 'reverso_automatico')
             and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')
             and a.fecha_contable >= v_fa
             and h.id = any (v_ids)
           group by a.origen_id, a.numero) q;
  if v_x is not null then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'devengo_estandar', 'corto', 'Horas ya en el devengo estándar del mes',
      'horas', v_h2, 'texto',
      format('%s h de este reparto ya están en el devengo estándar de %s, y este pago entra al libro el %s, dentro de ese mes: su '
             'mano de obra saldría dos veces ahí (el devengo en 5000 y el pago real). El devengo estándar es solo para lo trabajado '
             'y todavía no pagado: hay que retirarlo de ese mes antes de cerrarlo (avisa).', fn_jornal_h(v_h2), v_x,
             fn_jornal_dia(v_fa, true)));
  end if;
  -- (v3, la Fase 11b) HORAS DE ESTE REPARTO QUE YA PAGÓ UNA NÓMINA. Desde
  -- enero de 2027 la gente de obra cobra por nómina (c15) y su costo entra
  -- al libro con el journal, por esas mismas horas. Un Zelle a alguien que
  -- ya cobra así (un bono, un reembolso, un adelanto) se reconoce igual por
  -- su patrón, y repartido por sus horas las contaría otra vez en su obra.
  -- Se DICE antes de aceptar; no frena ni cambia qué horas entran (puede ser
  -- de verdad otro pago de esas horas, y lo decide Edgar).
  select count(*), coalesce(sum(h.horas), 0) into v_n, v_h2
    from horas h where h.id = any (v_ids) and h.id = any (v_nom);
  if v_n > 0 then
    select string_agg(q.d, ', ' order by q.f) into v_x
      from (select distinct n.dia_pago as f, fn_jornal_dia(n.dia_pago, true) as d
              from fn_margen_horas_nomina() n where n.horas_id = any (v_ids) and n.dia_pago is not null) q;
    v_avisos := v_avisos || jsonb_build_object('codigo', 'pagadas_por_nomina', 'corto', 'Horas que ya pagó una nómina',
      'horas', v_h2, 'reportes', v_n, 'texto',
      format('%s h de este reparto ya las pagó una nómina%s: su costo ya está en su obra por la nómina, y con este pago entraría otra '
             'vez. Si este pago es de otras horas, elige sus fechas; si es otra cosa (un bono, un reembolso), no lo repartas por '
             'horas: clasifícalo en la Bandeja como siempre. Es solo un aviso.', fn_jornal_h(v_h2),
             coalesce(' (día de pago ' || v_x || ')', '')));
  end if;
  if v_desde > m.fecha then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'periodo_futuro', 'corto', 'Las fechas son posteriores al pago', 'texto',
      format('Las fechas (%s) empiezan después del día del pago (%s): ¿seguro que pagó por adelantado?',
             fn_jornal_rango(v_desde, v_hasta), fn_jornal_dia(m.fecha, true)));
  end if;

  -- Un reparto anterior de ESTE pago que quedó suelto: su asiento se reversó
  -- por fuera (des-casado en la Bandeja) y el reparto sigue «aplicado». Es lo
  -- primero que hay que arreglar: marcarlo deshecho, con su motivo.
  if rp.id is not null then
    v_x := format('Este pago ya tuvo un reparto (%s) y su asiento se reversó por fuera, des-casándolo en la Bandeja: el reparto '
                  'sigue sin marcar. Márcalo deshecho con su motivo (Deshacer, en los repartos) y vuelve a repartirlo.',
                  fn_jornal_rango(rp.desde, rp.hasta));
    v_avisos := v_avisos || jsonb_build_object('codigo', 'reparto_suelto', 'corto', 'Tiene un reparto anterior sin cerrar',
                                               'reparto_id', rp.id, 'texto', v_x);
    v_puede := false;
    v_porque := v_x;
  end if;

  -- LA HUELLA de lo que Edgar ve: el movimiento, la persona, las fechas, el
  -- monto, las cuentas, si entran las cubiertas, y CADA reporte que entra o
  -- que el «Así es» va a aprobar: su id, fecha, obra, CO, fase y horas
  -- (limpios, como se reparten), si entra («E») y si se aprueba («A»). La
  -- huella cubre EXACTAMENTE lo que se aprueba: un reporte que no entra (ya
  -- lo cubre otro pago) y pierde su aprobación entre que Edgar mira y toca
  -- —alguien le cambió las horas, y c3 se la tumbó— cambia la huella, y no se
  -- aprueba sin que él lo vea.
  v_visto := md5(concat_ws('|', 'c10', m.id::text, jp.usuario_id::text, to_char(v_desde, 'YYYY-MM-DD'), to_char(v_hasta, 'YYYY-MM-DD'),
                           v_monto::text, v_cuenta, coalesce(cfg.cuenta_sin_obra, '-'), case when v_incl then 'con' else 'sin' end)
                 || E'\n'
                 || coalesce((select string_agg(concat_ws('|', h.id::text, to_char(h.fecha, 'YYYY-MM-DD'), coalesce(h.proyecto_id, '-'),
                                                          coalesce(case when h.proyecto_id is null then null else fn_jornal_limpio(h.co) end, '-'),
                                                          coalesce(fn_jornal_limpio(h.fase), '-'), trim_scale(h.horas)::text,
                                                          case when h.id = any (v_ids) then 'E' else '-' end,
                                                          case when h.id = any (v_apr) then 'A' else '-' end), E'\n' order by h.id)
                                from horas h where h.id = any (v_ids) or h.id = any (v_apr)), ''));

  -- Las propuestas de la IA (c8) que este pago tiene abiertas, si c8 está: la
  -- pendiente (propuesta_ia, como siempre) y, con ella, las aprobadas o
  -- editadas cuyo asiento ya no vive (propuestas_ia, con qué hacer con cada
  -- una: «rechazar» la pendiente, «caducar» las otras). Las cierra la pantalla
  -- por la función de borde «contador»: c10 no escribe en c8.
  select coalesce(jsonb_agg(jsonb_build_object('propuesta_id', i.propuesta_id, 'clase', i.clase, 'estado', i.estado,
                                               'resumen', i.resumen, 'asiento', i.asiento,
                                               'que_hacer', case i.clase when 'pendiente' then 'rechazar' else 'caducar' end)
                            order by (i.clase = 'pendiente') desc, i.propuesta_id), '[]'::jsonb),
         (array_agg(i.propuesta_id) filter (where i.clase = 'pendiente'))[1]
    into v_iac, v_pia
    from fn_jornal_ia(m.id) i;

  return jsonb_build_object(
    'reconocido', true,
    'movimiento', v_mov || jsonb_build_object('periodo', v_mes.periodo, 'mes_cerrado', coalesce(v_mes.estado = 'cerrado', false),
                                              'fecha_asiento', v_fa),
    'persona', jsonb_build_object('usuario_id', jp.usuario_id, 'nombre', pf.nombre, 'rol', pf.rol, 'tarifa', v_tarifa,
                                  'cuenta', v_cuenta, 'patron', jp.patron),
    'periodo', jsonb_build_object('desde', v_desde, 'hasta', v_hasta, 'regla', v_regla, 'texto', fn_jornal_rango(v_desde, v_hasta),
                                  'por_defecto', jsonb_build_object('desde', v_def.desde, 'hasta', v_def.hasta, 'regla', v_def.regla),
                                  'opciones', v_ops),
    'horas', v_horas, 'reportes', v_rep_n, 'obras', v_obras,
    'lineas', v_lineas, 'sin_obra', v_sin, 'detalle', v_det, 'cubiertas', v_cub,
    'tarifa_sale', v_sale, 'tarifa_equipo', v_tarifa, 'tarifa_desvio_pct', v_desvio,
    'avisos', v_avisos, 'puede_aplicar', v_puede, 'por_que', v_porque,
    'visto', v_visto, 'aprueba', jsonb_build_object('reportes', cardinality(v_apr), 'ids', to_jsonb(v_apr)),
    'propuesta_ia', v_pia, 'propuestas_ia', v_iac,
    'opciones', jsonb_build_object('incluir_cubiertas', v_incl));
end $$;
revoke execute on function public.fn_jornal_calcular(uuid, date, date, jsonb) from public, anon, service_role;
grant  execute on function public.fn_jornal_calcular(uuid, date, date, jsonb) to authenticated;
comment on function public.fn_jornal_calcular(uuid, date, date, jsonb) is 'c10: el cálculo de un pago de mano de obra (lo que devuelve fn_jornal_propuesta), sin frenar a nadie: lee con la policy de quien llama (a quien no es el dueño le contesta que el movimiento no existe). Lo usan fn_jornal_propuesta, fn_jornal_aplicar y v_jornal_pendientes: una sola cuenta para lo que se enseña y lo que se postea.';

-- LA PROPUESTA de un movimiento del banco. SOLO LEE. Si no es un pago
-- reconocido: {reconocido: false, por_que, movimiento, y —si es un cargo
-- pendiente sin persona— patron_sugerido y candidatos}. Si lo es:
--   movimiento   {id, fecha, monto (lo pagado, en positivo), cuenta,
--                 descripcion, estado, periodo, mes_cerrado, fecha_asiento
--                 (el día con que entrará al libro)}
--   persona      {usuario_id, nombre, rol, tarifa (costos_equipo), cuenta, patron}
--   periodo      {desde, hasta, regla (semana_anterior | semana_en_curso |
--                 a_mano), texto, por_defecto {desde, hasta, regla},
--                 opciones [{regla, desde, hasta, por_defecto, horas,
--                 horas_sin_pago}] (las dos semanas, para elegir de un toque)}
--   horas, reportes, obras      lo que entra: horas, reportes y nº de obras
--   lineas       [{n, proyecto_id, obra, obra_estado, co, horas, monto, cuenta}]
--   sin_obra     {n, horas, monto, cuenta, falta_cuenta} o null
--   detalle      [{horas_id, fecha, proyecto_id, obra, co, fase, horas,
--                 aprobada, entra, monto, n, cubierta_por}] (todos los
--                 reportes de esas fechas)
--   cubiertas    {horas, reportes, incluidas, repartos [...]} o null
--   tarifa_sale, tarifa_equipo, tarifa_desvio_pct
--   avisos       [{codigo, corto, texto}]: sin_horas, horas_cubiertas,
--                cubiertas_sin_aprobar (+horas_ids), horas_tardias (+horas,
--                reportes, desde, hasta: las fechas que las cogerían),
--                se_pisa (+repartos [ids]), sin_tarifa, tarifa_lejos,
--                no_parece_pago, obra_terminada, obra_sin_aprobar,
--                co_parecidos, falta_cuenta_sin_obra, cuenta_mal,
--                posible_duplicado, mes_cerrado, otro_anio u otro_mes
--                (+horas, monto, fecha_asiento), devengo_estandar (+horas),
--                periodo_futuro, reparto_suelto (+reparto_id)
--   puede_aplicar, por_que
--   visto        la huella que hay que devolver a fn_jornal_aplicar
--   aprueba      {reportes, ids}: los reportes de esas fechas que el «Así es»
--                va a aprobar (todos los que están sin aprobar, entren o no)
--   propuesta_ia la propuesta pendiente de c8 para este movimiento (o null)
--   propuestas_ia [{propuesta_id, clase (pendiente | sin_asiento), estado,
--                resumen, asiento, que_hacer (rechazar | caducar)}]: todo lo
--                de c8 que este pago tiene abierto (la pendiente, y las
--                aprobadas o editadas cuyo asiento ya no vive)
--   opciones     {incluir_cubiertas}
-- Las fechas a mano van las dos (o ninguna: el período por defecto), hasta
-- 62 días. Solo el dueño.
create or replace function public.fn_jornal_propuesta(p_movimiento uuid, p_desde date default null, p_hasta date default null,
                                                      p_opciones jsonb default '{}'::jsonb)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  perform fn_jornal_exigir_dueno();
  if p_movimiento is null then
    raise exception using errcode = '22023', message = 'Di de qué movimiento del banco (p_movimiento).';
  end if;
  if (p_desde is null) <> (p_hasta is null) then
    raise exception using errcode = '22023', message = 'Las fechas a mano van las dos (desde y hasta), o ninguna: entonces va la semana que toca.';
  end if;
  if p_desde > p_hasta then
    raise exception using errcode = '22023', message = format('Las fechas están al revés: desde %s hasta %s.', p_desde, p_hasta);
  end if;
  if p_hasta - p_desde > 61 then
    raise exception using errcode = '22023',
      message = format('Un pago se reparte por las horas de hasta 62 días, y de %s a %s van %s. Si de verdad paga más, repártelo '
                       'en dos.', p_desde, p_hasta, p_hasta - p_desde + 1);
  end if;
  return fn_jornal_calcular(p_movimiento, p_desde, p_hasta, fn_jornal_opciones(p_opciones));
end $$;
revoke execute on function public.fn_jornal_propuesta(uuid, date, date, jsonb) from public, anon, service_role;
grant  execute on function public.fn_jornal_propuesta(uuid, date, date, jsonb) to authenticated;
comment on function public.fn_jornal_propuesta(uuid, date, date, jsonb) is 'c10: la propuesta de reparto de un pago (SOLO LEE): si el movimiento es el pago de una persona dada de alta, la persona y su tarifa, el período (el de la regla del día del pago, o las fechas que se pidan) con las dos semanas para elegir, las horas, las líneas por obra y CO, lo sin obra, el detalle por reporte, lo ya cubierto por otro pago, la tarifa que sale, los avisos en llano, si se puede aplicar y por qué no, «visto» (la huella que hay que devolver a fn_jornal_aplicar), «aprueba» (los reportes que el «Así es» aprobará) y lo de la IA (c8) que el pago tiene abierto (propuesta_ia, propuestas_ia). Si no lo es, {reconocido: false, por_que}. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 7. EL JORNAL DEL ZELLE, lo que escribe: aplicar, deshacer, la
--    configuración y las personas. Todo SECURITY INVOKER, como el dueño.
-- ---------------------------------------------------------------------
-- «ASÍ ES». En UNA transacción: toma las horas de esa persona en esas
-- fechas, vuelve a calcular, y
--   · si el movimiento ya no es un pago reconocido que se pueda aplicar (ya
--     está resuelto, no hay horas, falta la cuenta de lo sin obra…): MX008
--     con el porqué, y nada cambia;
--   · si la huella no es la que Edgar vio (p_visto): MX011, y nada cambia;
--   · aprueba las horas de esas fechas que estaban sin aprobar, por el
--     camino de c3 (fn_horas_aprobar con sus ids: lo que Edgar vio, la
--     lista «aprueba» del cálculo, que la huella cubre entera);
--   · postea por el camino del banco (fn_banco_clasificar, c6): la línea del
--     banco y una por obra y CO a la cuenta del jornal, con su obra, su CO y
--     la persona (tercero empleado); lo sin obra, a su cuenta. Sin motivo,
--     salvo el que Edgar escriba en p_opciones.motivo (el de c6). Lo que c6,
--     c3 o c2 rechacen sale tal cual, y nada queda a medias;
--   · comprueba que el asiento que quedó ES el reparto, línea por línea, y
--     guarda el reparto con sus partes y su detalle por reporte de horas.
-- Dos a la vez sobre el mismo movimiento: una espera a la otra (el candado
-- de la persona) y, cuando le toca, el movimiento ya no está pendiente:
-- MX008, limpia. Devuelve {reparto_id, movimiento_id, estado, persona,
-- desde, hasta, regla_periodo, monto, horas, tarifa_sale, asiento {id,
-- numero, fecha_contable, periodo}, tardio (la nota de c6 si el mes del pago
-- estaba cerrado), horas_aprobadas {reportes, ids}, lineas, sin_obra,
-- avisos, propuesta_ia, propuestas_ia (lo de c8 que queda abierto: la
-- pantalla lo cierra por la función de borde «contador»), nota}. NO se frena
-- por una propuesta pendiente de la IA (cabecera, «decisiones»).
create or replace function public.fn_jornal_aplicar(p_movimiento uuid, p_desde date, p_hasta date, p_visto text,
                                                    p_opciones jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_op      jsonb;
  v_j       jsonb;
  v_u       uuid;
  v_nombre  text;
  v_id      uuid := gen_random_uuid();
  v_ids     bigint[];
  v_ap      jsonb;
  v_lineas  jsonb;
  v_res     jsonb;
  v_as      asientos;
  v_mal     text;
  v_n       int;
  v_memo    text;
  v_sin     jsonb;
  v_cta_sin text;
begin
  perform fn_jornal_exigir_dueno();
  v_op := fn_jornal_opciones(p_opciones);
  if p_movimiento is null or p_desde is null or p_hasta is null then
    raise exception using errcode = '22023',
      message = 'Aplicar un reparto dice el movimiento y las fechas que viste (p_movimiento, p_desde, p_hasta): las trae fn_jornal_propuesta.';
  end if;
  if p_desde > p_hasta or p_hasta - p_desde > 61 then
    raise exception using errcode = '22023',
      message = format('Las fechas no valen: de %s a %s (desde ≤ hasta, y hasta 62 días).', p_desde, p_hasta);
  end if;
  if coalesce(btrim(p_visto), '') = '' then
    raise exception using errcode = '22023',
      message = 'Falta «visto»: la huella de lo que viste (la trae fn_jornal_propuesta). Sin ella no se aprueba ni se postea nada.';
  end if;

  -- ¿De quién es? (sin candados todavía: solo para saber qué persona tomar)
  v_j := fn_jornal_calcular(p_movimiento, p_desde, p_hasta, v_op);
  if not coalesce((v_j->>'reconocido')::boolean, false) then
    raise exception using errcode = 'MX008', message = coalesce(v_j->>'por_que', 'Ese movimiento no es un pago que se pueda repartir.');
  end if;
  v_u := (v_j->'persona'->>'usuario_id')::uuid;
  -- El candado de la persona: dos repartos suyos a la vez se esperan (uno
  -- cubre unas horas y el otro lo tiene que ver). Y sus horas de esas
  -- fechas, tomadas: nadie las cambia mientras.
  perform pg_advisory_xact_lock(820261109, hashtext('jornal:' || v_u::text));
  perform 1 from (select h.id from horas h where h.usuario_id = v_u and h.fecha between p_desde and p_hasta order by h.id for update) t;

  -- El cálculo bueno, con todo tomado.
  v_j := fn_jornal_calcular(p_movimiento, p_desde, p_hasta, v_op);
  if not coalesce((v_j->>'reconocido')::boolean, false) then
    raise exception using errcode = 'MX008', message = coalesce(v_j->>'por_que', 'Ese movimiento no es un pago que se pueda repartir.');
  end if;
  if (v_j->'persona'->>'usuario_id')::uuid is distinct from v_u then
    raise exception using errcode = 'MX011',
      message = 'El pago ya no se reconoce como de la misma persona (alguien cambió los patrones mientras): vuelve a mirarlo.';
  end if;
  if not coalesce((v_j->>'puede_aplicar')::boolean, false) then
    raise exception using errcode = 'MX008', message = coalesce(v_j->>'por_que', 'Este pago no se puede repartir todavía.');
  end if;
  if (v_j->>'visto') is distinct from btrim(p_visto) then
    raise exception using errcode = 'MX011',
      message = format('Las horas de %s %s ya no son las que viste (alguien reportó, cambió o borró horas, o cambió una cuenta, '
                       'entre que miraste y que tocaste): no se aprobó ni se posteó nada. Vuelve a mirar el reparto y acepta lo '
                       'que veas ahora.', v_j->'persona'->>'nombre', v_j->'periodo'->>'texto'),
      hint = 'vuelve a pedir fn_jornal_propuesta';
  end if;
  v_nombre := v_j->'persona'->>'nombre';

  -- LA APROBACIÓN, por el camino de c3: los reportes de esas fechas que
  -- estaban sin aprobar, TODOS (entren o no en este reparto: c3 aprueba por
  -- persona y fechas, y pide esa lista exacta). Es la lista «aprueba» del
  -- cálculo, la misma que va en la huella: lo que Edgar vio, por sus ids. Si
  -- entre medias apareció otro, c3 lo dice (MX008) y aquí sale como MX011.
  select coalesce(array_agg(x.v::bigint order by x.v::bigint), '{}')
    into v_ids
    from jsonb_array_elements_text(v_j->'aprueba'->'ids') x(v);
  if cardinality(v_ids) > 0 then
    begin
      v_ap := fn_horas_aprobar(v_u, p_desde, p_hasta, jsonb_build_object('ids', to_jsonb(v_ids)));
    exception when sqlstate 'MX008' then
      raise exception using errcode = 'MX011',
        message = format('Las horas de %s %s cambiaron mientras se aprobaban: no se aprobó ni se posteó nada. Vuelve a mirar el '
                         'reparto. (%s)', v_nombre, v_j->'periodo'->>'texto', sqlerrm),
        hint = 'vuelve a pedir fn_jornal_propuesta';
    end;
  end if;

  -- LAS LÍNEAS para c6, en el orden de los grupos: cada obra y CO a la cuenta
  -- del jornal, con la persona; lo sin obra, a su cuenta. Un grupo al que no
  -- le llegó ni un centavo no lleva línea.
  v_sin := case when jsonb_typeof(v_j->'sin_obra') = 'object' then v_j->'sin_obra' end;
  v_cta_sin := v_sin->>'cuenta';
  v_memo := format('Jornal de %s · %s', v_nombre, case when p_desde = p_hasta then fn_jornal_dia(p_desde, true)
                                                       else fn_jornal_dia(p_desde) || ' a ' || fn_jornal_dia(p_hasta, true) end);
  select jsonb_agg(z.l order by z.n)
    into v_lineas
    from (select (x->>'n')::int as n,
                 jsonb_strip_nulls(jsonb_build_object(
                   'cuenta', x->>'cuenta', 'monto', ((x->>'monto')::numeric(14,2))::text, 'proyecto_id', x->>'proyecto_id',
                   'co', x->>'co',
                   'memo', left(format('%s · %s h de %s h', v_memo, fn_jornal_h((x->>'horas')::numeric),
                                       fn_jornal_h((v_j->>'horas')::numeric)), 200),
                   'tercero_tipo', 'empleado', 'tercero_id', v_u::text)) as l
            from jsonb_array_elements(v_j->'lineas') x
           where (x->>'monto')::numeric > 0
          union all
          select (v_sin->>'n')::int,
                 jsonb_build_object(
                   'cuenta', v_cta_sin, 'monto', ((v_sin->>'monto')::numeric(14,2))::text,
                   'memo', left(format('%s · %s h sin obra de %s h', v_memo, fn_jornal_h((v_sin->>'horas')::numeric),
                                       fn_jornal_h((v_j->>'horas')::numeric)), 200),
                   'tercero_tipo', 'empleado', 'tercero_id', v_u::text)
           where v_sin is not null and (v_sin->>'monto')::numeric > 0) z;
  if v_lineas is null then
    raise exception using errcode = 'MX008', message = 'No hay nada que postear: a ningún grupo de horas le toca ni un centavo.';
  end if;

  -- EL CAMINO AL LIBRO: el del banco. Sus frenos, sus mensajes y su asiento.
  v_res := fn_banco_clasificar(p_movimiento, v_lineas, v_op->>'motivo');
  select a.* into v_as
    from movimientos_banco mm
    join asientos a on a.id = mm.asiento_id
   where mm.id = p_movimiento and mm.estado = 'casado';
  if v_as.id is null then
    raise exception using errcode = 'MX008',
      message = 'El banco clasificó el movimiento pero no quedó casado con su asiento: no se guarda el reparto. Avisa.';
  end if;
  -- El asiento que quedó ES el reparto: la línea 1 es la del banco y las
  -- nuestras van detrás, en su orden, con su cuenta, su monto, su obra, su CO
  -- y la persona.
  -- (Si no lo fuera —c6 limpia o cambia algo que c10 no previó—, se dice QUÉ
  -- línea y QUÉ campo, con lo que quedó y lo que se pidió, y qué hacer: nada
  -- se guarda, y el pago sigue en la Bandeja. El CO y la fase ya van limpios
  -- como los deja c6, fn_jornal_limpio: antes un CO con un salto de línea
  -- paraba aquí con «la línea 3… Avisa», sin decir que era el CO.)
  select string_agg(format('la línea %s%s: %s', z.o + 1, coalesce(' (' || pr.nombre || ')', ''),
                           concat_ws('; ',
                             case when al.asiento_id is null then 'no está en el asiento' end,
                             case when al.asiento_id is not null and al.cuenta is distinct from z.l->>'cuenta'
                                  then format('la cuenta quedó %s y se pidió %s', al.cuenta, z.l->>'cuenta') end,
                             case when al.asiento_id is not null and al.monto is distinct from (z.l->>'monto')::numeric
                                  then format('el monto quedó %s y se pidió %s', al.monto, z.l->>'monto') end,
                             case when al.asiento_id is not null and al.proyecto_id is distinct from z.l->>'proyecto_id'
                                  then format('la obra quedó «%s» y se pidió «%s»', coalesce(al.proyecto_id, ''), coalesce(z.l->>'proyecto_id', '')) end,
                             case when al.asiento_id is not null and al.co is distinct from z.l->>'co'
                                  then format('el CO quedó %s y se pidió %s', coalesce(quote_literal(al.co), 'vacío'),
                                              coalesce(quote_literal(z.l->>'co'), 'vacío')) end,
                             case when al.asiento_id is not null
                                       and (al.tercero_tipo is distinct from 'empleado' or al.tercero_id is distinct from v_u::text)
                                  then 'no lleva a la persona (tercero empleado)' end)),
                    ' · ' order by z.o)
    into v_mal
    from (select x.l, x.o from jsonb_array_elements(v_lineas) with ordinality as x(l, o)) z
    left join asiento_lineas al on al.asiento_id = v_as.id and al.orden = z.o + 1
    left join proyectos pr on pr.id = z.l->>'proyecto_id'
   where al.asiento_id is null
      or al.cuenta is distinct from z.l->>'cuenta' or al.monto is distinct from (z.l->>'monto')::numeric
      or al.proyecto_id is distinct from z.l->>'proyecto_id' or al.co is distinct from z.l->>'co'
      or al.tercero_tipo is distinct from 'empleado' or al.tercero_id is distinct from v_u::text;
  if v_mal is not null
     or (select count(*) from asiento_lineas al where al.asiento_id = v_as.id) <> jsonb_array_length(v_lineas) + 1 then
    raise exception using errcode = 'MX001',
      message = format('El asiento %s que dejó el banco no es el reparto que se le pidió: %s. No se guardó nada (ni el asiento, ni el '
                       'reparto, ni la aprobación de las horas): el pago sigue en la Bandeja. Si lo que no coincide es el CO o la '
                       'obra de unas horas, corrígelos en Horas y vuelve a mirar el reparto; si no, avisa con este mensaje.',
                       v_as.numero,
                       coalesce(left(v_mal, 900),
                                format('trae %s líneas y se pidieron %s (la del banco y una por cada parte)',
                                       (select count(*) from asiento_lineas al where al.asiento_id = v_as.id),
                                       jsonb_array_length(v_lineas) + 1)));
  end if;

  -- EL REPARTO, sus partes y su detalle (con la marca de la guarda).
  perform set_config('mx_jornal.escribe', 'jornal_repartos', true);
  insert into jornal_repartos (id, movimiento_id, usuario_id, desde, hasta, regla_periodo, monto, horas, tarifa_sale, tarifa_equipo,
                               cuenta, cuenta_sin_obra, asiento_id, huella, avisos, opciones, horas_aprobadas, creado_por)
  values (v_id, p_movimiento, v_u, p_desde, p_hasta, v_j->'periodo'->>'regla', (v_j->'movimiento'->>'monto')::numeric,
          (v_j->>'horas')::numeric, (v_j->>'tarifa_sale')::numeric, (v_j->>'tarifa_equipo')::numeric,
          v_j->'persona'->>'cuenta', case when v_sin is not null then v_cta_sin end, v_as.id, v_j->>'visto', v_j->'avisos', v_op,
          to_jsonb(v_ids), auth.uid());
  perform set_config('mx_jornal.escribe', 'jornal_reparto_lineas', true);
  insert into jornal_reparto_lineas (reparto_id, n, orden, proyecto_id, co, cuenta, horas, monto)
  select v_id, y.n, case when y.monto > 0 then (row_number() over (partition by (y.monto > 0) order by y.n))::int + 1 end,
         y.proyecto_id, y.co, y.cuenta, y.horas, y.monto
    from (select (x->>'n')::int as n, x->>'proyecto_id' as proyecto_id, x->>'co' as co, x->>'cuenta' as cuenta,
                 (x->>'horas')::numeric as horas, (x->>'monto')::numeric(14,2) as monto
            from jsonb_array_elements(v_j->'lineas') x
          union all
          select (v_sin->>'n')::int, null, null, v_cta_sin, (v_sin->>'horas')::numeric, (v_sin->>'monto')::numeric(14,2)
           where v_sin is not null) y;
  perform set_config('mx_jornal.escribe', 'jornal_reparto_horas', true);
  insert into jornal_reparto_horas (reparto_id, horas_id, n, fecha, proyecto_id, co, fase, horas, monto)
  select v_id, (x->>'horas_id')::bigint, (x->>'n')::int, (x->>'fecha')::date, x->>'proyecto_id', x->>'co', x->>'fase',
         (x->>'horas')::numeric, (x->>'monto')::numeric(14,2)
    from jsonb_array_elements(v_j->'detalle') x
   where (x->>'entra')::boolean;
  perform set_config('mx_jornal.escribe', '', true);

  return jsonb_build_object(
    'reparto_id', v_id, 'movimiento_id', p_movimiento, 'estado', 'aplicado',
    'persona', v_j->'persona', 'desde', p_desde, 'hasta', p_hasta, 'regla_periodo', v_j->'periodo'->>'regla',
    'monto', (v_j->'movimiento'->>'monto')::numeric, 'horas', (v_j->>'horas')::numeric, 'tarifa_sale', (v_j->>'tarifa_sale')::numeric,
    'asiento', jsonb_build_object('id', v_as.id, 'numero', v_as.numero, 'fecha_contable', v_as.fecha_contable, 'periodo', v_as.periodo),
    'tardio', v_as.procedencia->>'tardio',
    'horas_aprobadas', jsonb_build_object('reportes', cardinality(v_ids), 'ids', to_jsonb(v_ids)),
    'lineas', v_j->'lineas', 'sin_obra', v_sin, 'avisos', v_j->'avisos',
    -- (lo de la IA que este pago deja abierto, para que la pantalla lo cierre
    -- por la función de borde «contador»: la pendiente —«No es eso»— y las
    -- aprobadas cuyo asiento ya no vive —«caducar»—; si no llega a cerrarlas,
    -- el control del jornal, el 80, las sigue enseñando)
    'propuesta_ia', v_j->'propuesta_ia', 'propuestas_ia', v_j->'propuestas_ia',
    -- (las obras a las que les llegó dinero: un grupo al que no le toca ni un
    -- centavo no lleva línea, y no se cuenta)
    'nota', format('Repartido: %s de %s (%s, %s h) entre %s obra(s)%s; asiento %s del %s.%s%s',
                   fn_jornal_usd((v_j->'movimiento'->>'monto')::numeric), v_nombre, v_j->'periodo'->>'texto',
                   fn_jornal_h((v_j->>'horas')::numeric),
                   (select count(distinct x->>'proyecto_id') from jsonb_array_elements(v_j->'lineas') x where (x->>'monto')::numeric > 0),
                   case when v_sin is not null and (v_sin->>'monto')::numeric > 0 then ' y lo sin obra' else '' end,
                   v_as.numero, fn_jornal_dia(v_as.fecha_contable, true),
                   case when (select count(*) from jsonb_array_elements(v_j->'lineas' || case when v_sin is not null then jsonb_build_array(v_sin)
                                                                                           else '[]'::jsonb end) x
                               where (x->>'monto')::numeric = 0) > 0
                        then format(' A %s grupo(s) de horas no les llegó ni un centavo (el pago es muy chico): no llevan línea.',
                                    (select count(*) from jsonb_array_elements(v_j->'lineas' || case when v_sin is not null
                                                                                                    then jsonb_build_array(v_sin)
                                                                                                    else '[]'::jsonb end) x
                                      where (x->>'monto')::numeric = 0))
                        else '' end,
                   case when cardinality(v_ids) > 0 then format(' Quedaron aprobados %s reporte(s) de horas.', cardinality(v_ids)) else '' end));
end $$;
revoke execute on function public.fn_jornal_aplicar(uuid, date, date, text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_jornal_aplicar(uuid, date, date, text, jsonb) to authenticated;
comment on function public.fn_jornal_aplicar(uuid, date, date, text, jsonb) is 'c10: «Así es»: en una transacción vuelve a calcular el reparto de un pago; si la huella (p_visto) ya no es la de las horas de hoy, MX011 y nada cambia; si lo es, aprueba por c3 (fn_horas_aprobar) los reportes de esas fechas sin aprobar —los que la huella cubre—, postea por c6 (fn_banco_clasificar: una línea por obra y CO con la persona como tercero; lo sin obra a su cuenta), comprueba el asiento línea por línea (MX001 con la línea y el campo, si no lo fuera) y guarda el reparto con su detalle; devuelve también lo de la IA (c8) que queda abierto (propuestas_ia). MX008 si el movimiento ya está resuelto, no hay horas o falta una cuenta; los errores de c6, c3 y c2 salen tal cual. p_opciones: {incluir_cubiertas, motivo}. Solo el dueño.';

-- DESHACER un reparto, con su motivo: por el camino del banco
-- (fn_banco_descasar, c6): el asiento se REVERSA (no se borra) y el
-- movimiento vuelve a la Bandeja; el reparto queda marcado «deshecho» con
-- quién, cuándo, por qué y el reverso (no se borra). Si el movimiento ya se
-- había des-casado por fuera (en la Bandeja), el asiento ya está reversado:
-- solo se marca el reparto (así se arregla lo que v_jornal_control señala).
-- La aprobación de las horas SE QUEDA (cabecera, «decisiones»): se aprobó lo
-- que Edgar vio, y lo que se deshace es el reparto del pago. Lo que c6
-- rechace (el movimiento dentro de una conciliación confirmada: se reabre
-- antes) sale tal cual. Devuelve {reparto_id, estado, movimiento_id,
-- movimiento_estado, asiento {id, numero}, reverso {id, numero,
-- fecha_contable}, por_fuera, horas_siguen_aprobadas, nota}.
create or replace function public.fn_jornal_deshacer(p_reparto uuid, p_motivo text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  r        jornal_repartos;
  v_mov    movimientos_banco;
  v_mot    text := nullif(btrim(regexp_replace(coalesce(p_motivo, ''), '\s+', ' ', 'g')), '');
  v_fuera  boolean := false;
  v_rev    asientos;
  v_num    text;
  v_aprob  int;
begin
  perform fn_jornal_exigir_dueno();
  if p_reparto is null then
    raise exception using errcode = '22023', message = 'Di qué reparto (p_reparto).';
  end if;
  if coalesce(length(v_mot), 0) < 3 then
    raise exception using errcode = '22023', message = 'Deshacer un reparto dice por qué (motivo): queda escrito en él y en el reverso.';
  end if;
  select * into r from jornal_repartos where id = p_reparto;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese reparto.';
  end if;
  perform pg_advisory_xact_lock(820261109, hashtext('jornal:' || r.usuario_id::text));
  select * into r from jornal_repartos where id = p_reparto for update;
  if r.estado <> 'aplicado' then
    raise exception using errcode = 'MX008',
      message = format('Ese reparto ya estaba deshecho (el %s: %s).', fn_jornal_dia(fn_fecha_miami(r.deshecho_el), true), r.deshecho_motivo);
  end if;
  select * into v_mov from movimientos_banco where id = r.movimiento_id;
  select a.numero into v_num from asientos a where a.id = r.asiento_id;
  if v_mov.estado = 'casado' and v_mov.asiento_id = r.asiento_id then
    -- el camino del banco: reversa el asiento y devuelve el movimiento a la Bandeja
    perform fn_banco_descasar(r.movimiento_id, v_mot);
  else
    -- ya se soltó por fuera: su asiento tiene que estar reversado
    if not exists (select 1 from asientos x where x.reversa_a = r.asiento_id and x.camino = 'reverso') then
      raise exception using errcode = 'MX008',
        message = format('El movimiento ya no está casado con el asiento %s de este reparto, y ese asiento sigue vivo en el libro: '
                         'no lo toco. Mira el control del jornal (Contabilidad → Bandeja) y avisa.', coalesce(v_num, '?'));
    end if;
    v_fuera := true;
  end if;
  select x.* into v_rev from asientos x where x.reversa_a = r.asiento_id and x.camino = 'reverso' order by x.cadena_pos desc limit 1;
  perform set_config('mx_jornal.escribe', 'jornal_repartos', true);
  update jornal_repartos
     set estado = 'deshecho', deshecho_el = clock_timestamp(), deshecho_por = auth.uid(), deshecho_motivo = v_mot, reverso_id = v_rev.id
   where id = r.id;
  perform set_config('mx_jornal.escribe', '', true);
  select count(*) into v_aprob
    from jornal_reparto_horas rh join horas h on h.id = rh.horas_id
   where rh.reparto_id = r.id and h.aprobado_el is not null;
  select * into v_mov from movimientos_banco where id = r.movimiento_id;
  return jsonb_build_object(
    'reparto_id', r.id, 'estado', 'deshecho', 'movimiento_id', r.movimiento_id, 'movimiento_estado', v_mov.estado,
    'asiento', jsonb_build_object('id', r.asiento_id, 'numero', v_num),
    'reverso', jsonb_build_object('id', v_rev.id, 'numero', v_rev.numero, 'fecha_contable', v_rev.fecha_contable),
    'por_fuera', v_fuera, 'horas_siguen_aprobadas', v_aprob,
    'nota', format('Reparto deshecho: el asiento %s quedó reversado con el %s%s. %s',
                   coalesce(v_num, '?'), coalesce(v_rev.numero, '?'),
                   case when v_fuera then ' (ya se había des-casado en la Bandeja)' else ' y el pago volvió a la Bandeja' end,
                   case when v_aprob > 0
                        then format('Sus %s reporte(s) de horas siguen aprobados: se aprobó lo que viste, y lo que se deshace es el '
                                    'reparto del pago.', v_aprob)
                        else '' end));
end $$;
revoke execute on function public.fn_jornal_deshacer(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_jornal_deshacer(uuid, text) to authenticated;
comment on function public.fn_jornal_deshacer(uuid, text) is 'c10: deshace un reparto con su motivo por el camino de c6 (fn_banco_descasar: el asiento se reversa y el movimiento vuelve a la Bandeja); el reparto queda marcado deshecho (quién, cuándo, por qué, su reverso) y no se borra. Si el movimiento ya se había des-casado por fuera, solo marca el reparto. La aprobación de las horas se queda. MX008 si ya estaba deshecho; los errores de c6 salen tal cual. Solo el dueño.';

-- LA CONFIGURACIÓN: {cuenta_defecto?, cuenta_sin_obra? (o null para
-- quitarla), burden_estandar_pct? (0 a 100, o null), aviso_tarifa_pct? (0 a
-- 500)}. Devuelve la fila como quedó.
create or replace function public.fn_jornal_config(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_sobra text;
  v_bur   numeric;
  v_av    numeric;
  v_x     text;
  c       jornal_config;
begin
  perform fn_jornal_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'La configuración llega como un objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p) k where k not in ('cuenta_defecto', 'cuenta_sin_obra', 'burden_estandar_pct', 'aviso_tarifa_pct');
  if v_sobra is not null then
    raise exception using errcode = '22023',
      message = format('Clave desconocida en la configuración: %s. Las que hay: cuenta_defecto, cuenta_sin_obra, burden_estandar_pct y '
                       'aviso_tarifa_pct.', v_sobra);
  end if;
  if p ? 'cuenta_defecto' then
    v_x := fn_jornal_cuenta_mal(nullif(btrim(p->>'cuenta_defecto'), ''), 'obra');
    if v_x is not null then
      raise exception using errcode = 'MX004', message = format('La cuenta del jornal no vale: %s.', v_x);
    end if;
  end if;
  if p ? 'cuenta_sin_obra' and nullif(btrim(p->>'cuenta_sin_obra'), '') is not null then
    v_x := fn_jornal_cuenta_mal(btrim(p->>'cuenta_sin_obra'), 'sin_obra');
    if v_x is not null then
      raise exception using errcode = 'MX004',
        message = format('La cuenta de la mano de obra sin obra no vale: %s. Sirve una de gasto general que no exija obra (7900 mientras '
                         'el CPA decide), o la que él cree para esto.', v_x);
    end if;
  end if;
  if p ? 'burden_estandar_pct' and jsonb_typeof(p->'burden_estandar_pct') <> 'null' then
    begin
      v_bur := (p->>'burden_estandar_pct')::numeric;
    exception when others then
      raise exception using errcode = 'MX005', message = 'burden_estandar_pct es un % (por ejemplo 12.5; 0 si no aplica), o null para quitarlo.';
    end;
    if v_bur is null or v_bur < 0 or v_bur > 100 or v_bur <> round(v_bur, 2) then
      raise exception using errcode = 'MX005', message = 'burden_estandar_pct va de 0 a 100, con dos decimales como mucho.';
    end if;
  end if;
  if p ? 'aviso_tarifa_pct' then
    begin
      v_av := (p->>'aviso_tarifa_pct')::numeric;
    exception when others then
      raise exception using errcode = 'MX005', message = 'aviso_tarifa_pct es un % (por ejemplo 25).';
    end;
    if v_av is null or v_av < 0 or v_av > 500 or v_av <> round(v_av, 2) then
      raise exception using errcode = 'MX005', message = 'aviso_tarifa_pct va de 0 a 500, con dos decimales como mucho.';
    end if;
  end if;
  perform set_config('mx_jornal.escribe', 'jornal_config', true);
  update jornal_config
     set cuenta_defecto      = case when p ? 'cuenta_defecto' then btrim(p->>'cuenta_defecto') else cuenta_defecto end,
         cuenta_sin_obra     = case when p ? 'cuenta_sin_obra' then nullif(btrim(p->>'cuenta_sin_obra'), '') else cuenta_sin_obra end,
         burden_estandar_pct = case when p ? 'burden_estandar_pct' then v_bur else burden_estandar_pct end,
         aviso_tarifa_pct    = case when p ? 'aviso_tarifa_pct' then v_av else aviso_tarifa_pct end,
         actualizado         = now(),
         actualizado_por     = auth.uid()
   where id = 1
  returning * into c;
  perform set_config('mx_jornal.escribe', '', true);
  return to_jsonb(c);
end $$;
revoke execute on function public.fn_jornal_config(jsonb) from public, anon, service_role;
grant  execute on function public.fn_jornal_config(jsonb) to authenticated;
comment on function public.fn_jornal_config(jsonb) is 'c10: cambia la configuración del jornal ({cuenta_defecto?, cuenta_sin_obra? (o null), burden_estandar_pct? (0–100 o null), aviso_tarifa_pct? (0–500)}) y la devuelve. MX004 si una cuenta no sirve, MX005 si un % está mal. Solo el dueño.';

-- UNA PERSONA: alta, cambio o baja lógica. p: {usuario_id, patron?,
-- movimiento_id? (si no se dice el patrón, el que sale de ese movimiento:
-- fn_jornal_patron_sugerido), cuenta? (o null: la de fábrica), activa?,
-- nota?}. El alta pide patrón (o movimiento). El dueño no se da de alta: lo
-- que saca Edgar es una distribución (3200), no un jornal. Devuelve la fila,
-- su nombre, cuántos pagos pendientes reconoce ahora su patrón, y si alguno
-- casa también con otra persona.
create or replace function public.fn_jornal_persona(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_sobra  text;
  v_u      uuid;
  v_pf     perfiles;
  v_ex     jornal_personas;
  v_patron text;
  v_cuenta text;
  v_activa boolean;
  v_x      text;
  v_n      int;
  v_amb    int;
  v_fila   jornal_personas;
  v_pila   text;
  v_nd     int;
  v_dtxt   text;
  v_av     text[] := '{}';
begin
  perform fn_jornal_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'La persona llega como un objeto JSON: {"usuario_id": "…", "patron": "…"}.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p) k where k not in ('usuario_id', 'patron', 'movimiento_id', 'cuenta', 'activa', 'nota');
  if v_sobra is not null then
    raise exception using errcode = '22023',
      message = format('Clave desconocida: %s. Las que hay: usuario_id, patron, movimiento_id, cuenta, activa y nota.', v_sobra);
  end if;
  begin
    v_u := (p->>'usuario_id')::uuid;
  exception when others then
    v_u := null;
  end;
  if v_u is null then
    raise exception using errcode = '22023', message = 'Di quién: usuario_id (su perfil en la app).';
  end if;
  select * into v_pf from perfiles where id = v_u;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese perfil en la app.';
  end if;
  if v_pf.rol = 'dueno' then
    raise exception using errcode = 'MX008',
      message = format('%s es el dueño: no cobra un jornal. Lo que saca de la empresa es una distribución (3200) y se clasifica en '
                       'la Bandeja como siempre.', v_pf.nombre);
  end if;
  if p ? 'activa' and jsonb_typeof(p->'activa') <> 'boolean' then
    raise exception using errcode = '22023', message = 'activa es true o false.';
  end if;
  -- (el candado de la persona, el mismo de aplicar y deshacer: dos altas de
  -- la misma persona a la vez se esperan, y la segunda la ve ya dada de alta)
  perform pg_advisory_xact_lock(820261109, hashtext('jornal:' || v_u::text));
  select * into v_ex from jornal_personas where usuario_id = v_u for update;
  -- el patrón: el que se dice, el del movimiento, o el que ya tenía
  v_patron := nullif(btrim(p->>'patron'), '');
  if v_patron is null and nullif(p->>'movimiento_id', '') is not null then
    begin
      v_patron := fn_jornal_patron_sugerido((p->>'movimiento_id')::uuid);
    exception when invalid_text_representation then
      raise exception using errcode = '22023', message = 'movimiento_id es el id (uuid) de un movimiento del banco.';
    end;
    if v_patron is null then
      raise exception using errcode = '22023',
        message = 'De la descripción de ese movimiento no sale un nombre: escribe el patrón (su nombre, como lo pone el banco).';
    end if;
  end if;
  v_patron := coalesce(v_patron, v_ex.patron);
  v_x := fn_jornal_patron_mal(v_patron);
  if v_x is not null then
    raise exception using errcode = '22023', message = format('El patrón no vale: %s.', v_x);
  end if;
  v_activa := coalesce((p->>'activa')::boolean, v_ex.activa, true);
  v_cuenta := case when p ? 'cuenta' then nullif(btrim(p->>'cuenta'), '') else v_ex.cuenta end;
  if v_cuenta is not null then
    v_x := fn_jornal_cuenta_mal(v_cuenta, 'obra');
    if v_x is not null then
      raise exception using errcode = 'MX004', message = format('La cuenta de su jornal no vale: %s.', v_x);
    end if;
  end if;
  if v_activa and exists (select 1 from jornal_personas o
                           where o.usuario_id <> v_u and o.activa and lower(btrim(o.patron)) = lower(v_patron)) then
    raise exception using errcode = 'MX008',
      message = format('Ese patrón («%s») ya es el de otra persona dada de alta: cada pago tiene que ser de una sola.', v_patron);
  end if;
  perform set_config('mx_jornal.escribe', 'jornal_personas', true);
  begin
    if v_ex.usuario_id is null then
      insert into jornal_personas (usuario_id, patron, cuenta, activa, nota, creado_por, actualizado_por)
      values (v_u, v_patron, v_cuenta, v_activa, nullif(btrim(p->>'nota'), ''), auth.uid(), auth.uid())
      returning * into v_fila;
    else
      update jornal_personas
         set patron = v_patron, cuenta = v_cuenta, activa = v_activa,
             nota = case when p ? 'nota' then nullif(btrim(p->>'nota'), '') else nota end,
             actualizado_el = now(), actualizado_por = auth.uid()
       where usuario_id = v_u
      returning * into v_fila;
    end if;
  exception when unique_violation then
    -- (dos personas con el mismo patrón, dadas de alta a la vez desde dos pantallas)
    raise exception using errcode = 'MX008',
      message = format('Ese patrón («%s») ya es el de otra persona dada de alta: cada pago tiene que ser de una sola.', v_patron);
  end;
  perform set_config('mx_jornal.escribe', '', true);
  -- cuántos pagos pendientes reconoce ahora, y cuántos casan también con otra
  select count(*),
         count(*) filter (where exists (select 1 from jornal_personas o
                                         where o.usuario_id <> v_u and o.activa and fn_jornal_texto(mm.desc_norm, mm.memo) ~* o.patron))
    into v_n, v_amb
    from movimientos_banco mm
   where v_fila.activa and mm.estado = 'pendiente' and mm.monto < 0 and fn_jornal_texto(mm.desc_norm, mm.memo) ~* v_fila.patron;
  -- LO QUE NO SE PUEDE SABER SOLO, DICHO (avisos; ninguno frena: el banco
  -- puede escribir el nombre legal y la app el de pila):
  --   · el patrón no lleva el nombre de pila del perfil: ¿es el de otra
  --     persona? (el patrón de Zzana en el perfil de Zzcaro reconocía sus
  --     pagos a nombre de Zzcaro, con ella como tercero, sin decir nada);
  --   · el patrón casa, en lo que el banco ya trajo, con pagos a varios
  --     destinatarios distintos (un comercio con un nombre parecido, otra
  --     persona con el mismo apellido): tiene que llevar solo su nombre.
  if v_fila.activa then
    v_pila := upper(translate(split_part(btrim(coalesce(v_pf.nombre, '')), ' ', 1), 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN'));
    if v_pila ~ '^[A-Z]{3,}$' and position(v_pila in upper(v_fila.patron)) = 0 then
      v_av := v_av || format('El patrón «%s» no lleva el nombre de %s («%s»): mira que sea el de sus pagos y no el de otra persona.',
                             v_fila.patron, v_pf.nombre, v_pila);
    end if;
    select count(*), left(string_agg('«' || q.d || '»', ', ' order by q.n desc, q.d), 300)
      into v_nd, v_dtxt
      from (select fn_jornal_destinatario(mm.desc_norm) as d, count(*) as n
              from movimientos_banco mm
             where mm.monto < 0 and fn_jornal_texto(mm.desc_norm, mm.memo) ~* v_fila.patron
             group by 1) q;
    if v_nd > 1 then
      v_av := v_av || format('El patrón casa con pagos que el banco describe de %s formas distintas (%s): mira que todos sean suyos; si '
                             'alguno es de un comercio o de otra persona, afina el patrón.', v_nd, v_dtxt);
    end if;
  end if;
  return to_jsonb(v_fila)
         || jsonb_build_object('nombre', v_pf.nombre, 'nueva', v_ex.usuario_id is null, 'pagos_pendientes', v_n, 'ambiguos', v_amb,
                               'avisos', to_jsonb(v_av),
                               'nota_alta', case when not v_fila.activa then format('%s queda de baja: sus pagos ya no se reconocen solos.', v_pf.nombre)
                                                 when v_amb > 0 then format('%s de sus %s pago(s) pendientes casan también con otra persona: afina el patrón.', v_amb, v_n)
                                                 else format('%s: %s pago(s) pendientes reconocidos con «%s».', v_pf.nombre, v_n, v_fila.patron) end
                                            || case when cardinality(v_av) > 0 then ' Ojo: ' || array_to_string(v_av, ' ') else '' end);
end $$;
revoke execute on function public.fn_jornal_persona(jsonb) from public, anon, service_role;
grant  execute on function public.fn_jornal_persona(jsonb) to authenticated;
comment on function public.fn_jornal_persona(jsonb) is 'c10: da de alta, cambia o da de baja (activa = false) a una persona cuyo pago se reparte por sus horas: {usuario_id, patron? (o movimiento_id: sale de su descripción), cuenta?, activa?, nota?}. El patrón se valida (22023), la cuenta también (MX004), el dueño no (MX008), y dos personas no comparten patrón (MX008). Devuelve la fila, su nombre, cuántos pagos pendientes reconoce y sus avisos (el patrón no lleva su nombre de pila; casa con pagos a varios destinatarios). Solo el dueño.';


-- ---------------------------------------------------------------------
-- 8. EL MARGEN: el costo por obra y el estimado contra real, desde el
--    libro. Tres piezas de lectura (las líneas del libro por concepto, las
--    horas por clase y el estimado), cada una para todas las obras o para
--    una, y encima fn_margen_obras (la fila por obra: v_margen_obra) y
--    fn_margen_obra (el detalle de una). Todo SECURITY INVOKER y solo
--    lectura: lee con la policy de quien llama, y a quien no es el dueño no
--    le devuelve nada (fn_jornal_ve).
-- ---------------------------------------------------------------------
-- (Desde cuándo hay libro —fn_margen_libro_desde: el día después de la
-- apertura— está arriba, en lo común: también lo usa el jornal.)

-- LAS LÍNEAS DEL LIBRO con obra, de costo (cuentas de tipo costo: 5xxx) y
-- de ingreso (40xx), cada una con su CONCEPTO:
--   ingreso       las cuentas de tipo ingreso (importe en positivo = haber)
--   mano_obra     las líneas de un jornal (por su asiento y su orden: las de
--                 cada reparto, aplicado o deshecho, y las de su reverso,
--                 que las anulan; es_jornal) y las 50xx (la nómina de f11)
--   material      5100
--   subcontratos  5200 (lo que no es jornal)
--   equipo        5300
--   otros         lo demás de costo
-- importe: el costo en positivo (debe − haber); el ingreso, en positivo.
-- Sin corte de fecha: todo lo que el libro tiene.
create or replace function public.fn_margen_lineas(p_proyecto text default null)
returns table (proyecto_id text, asiento_id uuid, orden int, numero text, fecha date, cuenta text, concepto text,
               co text, fase text, cost_code text, importe numeric(14,2), es_jornal boolean, reparto_id uuid)
language sql stable
set search_path = public, pg_temp
as $$
  -- (¿es la línea de un jornal? Su asiento es el de un reparto, o el reverso
  -- del de un reparto, y su orden es el de una de sus partes con obra. Se
  -- busca por los índices —el asiento de cada reparto es único—: contra un
  -- CTE, el planificador puede comparar cada línea del libro con cada parte.)
  select l.proyecto_id, l.asiento_id, l.orden, a.numero, a.fecha_contable, l.cuenta,
         case when cu.tipo = 'ingreso' then 'ingreso'
              when jl.reparto_id is not null or l.cuenta like '50%' then 'mano_obra'
              when l.cuenta = '5100' then 'material'
              when l.cuenta = '5200' then 'subcontratos'
              when l.cuenta = '5300' then 'equipo'
              else 'otros' end,
         public.fn_jornal_limpio(l.co), public.fn_jornal_limpio(l.fase), l.cost_code,
         (case when cu.tipo = 'ingreso' then -l.monto else l.monto end)::numeric(14,2),
         jl.reparto_id is not null, jl.reparto_id
    from public.asiento_lineas l
    join public.asientos a on a.id = l.asiento_id
    join public.cuentas cu on cu.codigo = l.cuenta
    left join public.jornal_repartos r on r.asiento_id = coalesce(a.reversa_a, l.asiento_id)
    left join public.jornal_reparto_lineas jl on jl.reparto_id = r.id and jl.orden = l.orden and jl.proyecto_id is not null
   where l.proyecto_id is not null and cu.tipo in ('costo', 'ingreso')
     and (p_proyecto is null or l.proyecto_id = p_proyecto)
     and (select public.fn_jornal_ve())
$$;
revoke execute on function public.fn_margen_lineas(text) from public, anon, service_role;
grant  execute on function public.fn_margen_lineas(text) to authenticated;
comment on function public.fn_margen_lineas(text) is 'c10: las líneas del libro con obra, de costo e ingreso, con su concepto (ingreso, mano_obra, material, subcontratos, equipo, otros): la mano de obra son las líneas de los jornales (por su asiento; las de un reparto deshecho se anulan con su reverso) y las 50xx. Todas las obras, o una. Solo lectura.';

-- LAS HORAS con obra, cada reporte con su CLASE:
--   pago_real        está en el detalle de un reparto aplicado (monto_real:
--                    lo que le tocó; repartos: en cuántos está) o, desde la
--                    v3, la pagó una nómina posteada y viva (c15). De las
--                    de la nómina aquí NO va importe (monto_real 0 y
--                    repartos 0): lo que le tocó a cada hora es el sueldo
--                    de una persona y se ve en la nómina, con el código del
--                    teléfono; su costo está en el libro, por obra y CO
--                    (5000, 5001 y 5010: mano_obra_nomina)
--   antes_del_libro  es de antes del libro: su costo está en QuickBooks
--   dueno            es del dueño, sin pago: no cobra por hora (las que le
--                    pagó la nómina como oficial, 5001, tienen pago real)
--   estandar         lo demás: sin pago real (ni un pago repartido ni una
--                    nómina). monto_estandar = horas ×
--                    costos_equipo.costo_hora × (1 + burden), al centavo;
--                    vacío si falta la tarifa o el burden
-- (monto_estandar va también en las del dueño, con su tarifa, para
-- enseñarlo aparte: no suma en el costo.)
create or replace function public.fn_margen_horas(p_proyecto text default null)
returns table (horas_id bigint, proyecto_id text, usuario_id uuid, persona text, es_dueno boolean, fecha date, co text, fase text,
               horas numeric, aprobada boolean, clase text, tarifa numeric, monto_real numeric(14,2),
               monto_estandar numeric(14,2), repartos int)
language sql stable
set search_path = public, pg_temp
as $$
  with lb as materialized (select public.fn_margen_libro_desde() as d),
       cfg as materialized (select (select c.burden_estandar_pct from public.jornal_config c where c.id = 1) as b),
       -- (los perfiles y las tarifas, leídos UNA vez: la policy de
       -- costos_equipo llama a es_dueno() por cada fila que se lee, y buscarla
       -- reporte por reporte la llamaba miles de veces)
       pf as materialized (select p.id, p.nombre, p.rol from public.perfiles p),
       ce as materialized (select c.usuario_id, c.costo_hora from public.costos_equipo c)
  select h.id, h.proyecto_id, h.usuario_id, pf.nombre, coalesce(pf.rol = 'dueno', false), h.fecha,
         public.fn_jornal_limpio(h.co), public.fn_jornal_limpio(h.fase), h.horas, h.aprobado_el is not null,
         k.clase, ce.costo_hora, coalesce(pg.monto, 0)::numeric(14,2),
         (case when k.clase in ('estandar', 'dueno') then round(h.horas * ce.costo_hora * (1 + cfg.b / 100), 2) end)::numeric(14,2),
         pg.n
    from public.horas h
    cross join lb
    cross join cfg
    left join pf on pf.id = h.usuario_id
    left join ce on ce.usuario_id = h.usuario_id
    -- LO PAGADO DE VERDAD, por reporte: el detalle de los repartos vivos (por
    -- el índice de cada reporte) y, desde la v3, lo que pagó una nómina (qué
    -- reportes, sin su importe; lo demás de esta capa no cambia).
    cross join lateral (select sum(rh.monto) as monto, count(*)::int as n
                          from public.jornal_reparto_horas rh
                          join public.jornal_repartos r on r.id = rh.reparto_id
                         where rh.horas_id = h.id and r.estado = 'aplicado') pg
    -- (v3) LAS QUE PAGÓ UNA NÓMINA (c15, si está): la lista se lee UNA vez y
    -- se consulta por reporte como EXPRESIÓN («h.id in (select …)»: una tabla
    -- hash), no como cruce. Con las policies de horas el planificador cree
    -- que sale un solo reporte y, como cruce, recorría la lista entera por
    -- cada uno: medido en el banco con 40,000 reportes y 30,000 pagados por
    -- nómina, 63 s desde la app (el tope de la API son 8); así, 1.5 s, como
    -- antes de la v3. Lo vigila pruebas/conta/c10-volumen.sh.
    cross join lateral (select case when pg.n > 0
                                      or h.id in (select n.horas_id from public.fn_margen_horas_nomina() n) then 'pago_real'
                                    when h.fecha < lb.d then 'antes_del_libro'
                                    when pf.rol = 'dueno' then 'dueno'
                                    else 'estandar' end as clase) k
   where h.proyecto_id is not null and h.horas > 0 and h.horas < 100000
     and (p_proyecto is null or h.proyecto_id = p_proyecto)
     and (select public.fn_jornal_ve())
$$;
revoke execute on function public.fn_margen_horas(text) from public, anon, service_role;
grant  execute on function public.fn_margen_horas(text) to authenticated;
comment on function public.fn_margen_horas(text) is 'c10: las horas con obra, reporte por reporte, con su clase: pago_real (está en un reparto aplicado, con lo que le tocó; o la pagó una nómina posteada y viva —c15—: de esas no va importe aquí, monto_real 0 y repartos 0, porque es el sueldo de una persona; su costo está en el libro por obra), antes_del_libro (su costo está en QuickBooks), dueno (no cobra por hora) o estandar (sin pago real, ni un pago repartido ni una nómina: horas × costos_equipo.costo_hora × (1 + burden estándar), al centavo; vacío si falta la tarifa o el burden). Todas las obras, o una. Solo lectura.';

-- EL ESTIMADO de cada obra, de las MISMAS fuentes que la app ya enseña:
-- horas_estimadas (proyectos), material_presupuesto y contrato
-- (finanzas_proyecto), y la tarifa de mano de obra del escenario:
-- round((foreman × pct_foreman + journeyman × pct_journeyman + helper ×
-- pct_helper) × (1 + beneficios), 2). Con un estimado enlazado a la obra
-- (estimados.proyecto_id: el «convertido», o el más reciente), el escenario
-- es el suyo y los beneficios coalesce(estimados.benefits_pct,
-- escenarios.benefits); sin él, el escenario B. Un cero es «no hay».
-- benefits_detalle no se lee: es lo que se cotiza, no un costo.
-- (Su costo_estimado es la suma de LO QUE HAY estimado, mano de obra y
-- material. Si con eso hay un total que comparar contra el real lo decide
-- fn_margen_obras, que es quien ve el real: v_margen_obra.costo_estimado
-- sale vacío cuando el estimado está incompleto.)
create or replace function public.fn_margen_estimado(p_proyecto text default null)
returns table (proyecto_id text, horas_estimadas numeric, escenario text, estimado_id bigint, beneficios numeric,
               tarifa_estimada numeric(10,2), mano_obra_estimada numeric(14,2), material_presupuesto numeric(14,2),
               contrato numeric(14,2), costo_estimado numeric(14,2))
language sql stable
set search_path = public, pg_temp
as $$
  select p.id, nullif(p.horas_estimadas, 0), coalesce(e.escenario, 'B'), e.id, coalesce(e.benefits_pct, sc.benefits),
         t.tarifa::numeric(10,2),
         round(nullif(p.horas_estimadas, 0) * t.tarifa, 2)::numeric(14,2),
         round(nullif(fp.presupuesto_materiales, 0), 2)::numeric(14,2),
         round(nullif(fp.contrato, 0), 2)::numeric(14,2),
         (case when nullif(p.horas_estimadas, 0) * t.tarifa is null and nullif(fp.presupuesto_materiales, 0) is null then null
               else coalesce(round(nullif(p.horas_estimadas, 0) * t.tarifa, 2), 0) + coalesce(round(fp.presupuesto_materiales, 2), 0) end)::numeric(14,2)
    from public.proyectos p
    left join public.finanzas_proyecto fp on fp.proyecto_id = p.id
    left join lateral (select es.id, es.escenario, es.benefits_pct
                         from public.estimados es
                        where es.proyecto_id = p.id
                        order by (es.estado = 'convertido') desc nulls last, es.creado desc nulls last, es.id desc
                        limit 1) e on true
    left join public.escenarios sc on sc.id = coalesce(e.escenario, 'B')
    cross join lateral (select round((sc.foreman * sc.pct_foreman + sc.journeyman * sc.pct_journeyman + sc.helper * sc.pct_helper)
                                     * (1 + coalesce(e.benefits_pct, sc.benefits)), 2) as tarifa) t
   where (p_proyecto is null or p.id = p_proyecto)
     and (select public.fn_jornal_ve())
$$;
revoke execute on function public.fn_margen_estimado(text) from public, anon, service_role;
grant  execute on function public.fn_margen_estimado(text) to authenticated;
comment on function public.fn_margen_estimado(text) is 'c10: el estimado de cada obra, de las mismas fuentes que la app: horas_estimadas (proyectos), material_presupuesto y contrato (finanzas_proyecto) y la tarifa de mano de obra del escenario con que se cotizó (el del estimado enlazado, con coalesce(estimados.benefits_pct, escenarios.benefits); sin estimado enlazado, el B). Un cero cuenta como «no hay». costo_estimado es la suma de lo que hay (si da un total que comparar con el real lo decide fn_margen_obras). Solo lectura.';

-- LA FILA POR OBRA (v_margen_obra la enseña entera; fn_margen_obra pide una):
--   proyecto_id, obra, cliente, tipo, estado, completado_el
--   libro_desde, parcial (ya andaba antes del libro), parcial_por (qué tenía)
--   contrato; ingreso_libro (40xx)
--   EL REAL DEL LIBRO: material_real (5100), mano_obra_real (= mano_obra_
--     jornales, lo pagado y repartido, + mano_obra_nomina, 50xx),
--     subcontratos_real (el resto de 5200), equipo_real (5300),
--     otros_costos_real, costo_real (la suma)
--   LAS HORAS: horas_reales (todas las reportadas con esa obra), horas_co
--     (las que llevan CO), horas_base (las de antes de la app, de la ficha),
--     horas_antes_libro, horas_con_pago_real (las de un reparto aplicado
--     y, desde la v3, las que pagó una nómina), horas_estandar (sin pago
--     real: ni lo uno ni lo otro; sin las del dueño ni las de antes del
--     libro), horas_dueno, horas_sin_aprobar
--   EL ESTÁNDAR: mano_obra_estandar (vacía, con mano_obra_estandar_falta,
--     si falta el burden o la tarifa de alguien; 0 si no hay horas a
--     estándar), mano_obra_dueno (aparte: no suma), burden_estandar_pct,
--     costo_con_estandar (costo_real + mano_obra_estandar)
--   EL ESTIMADO: horas_estimadas, tarifa_estimada, escenario, estimado_id,
--     mano_obra_estimada, material_presupuesto, costo_estimado,
--     estimado_completo y estimado_falta. UN ESTIMADO PARCIAL NO SE COMPARA
--     CON UN REAL COMPLETO: costo_estimado (mano de obra estimada + material
--     presupuestado) solo sale si el estimado da un total que comparar
--     (estimado_completo). No lo da —y costo_estimado, margen_estimado, su %
--     y diferencia salen vacíos, con el porqué en estimado_falta— cuando:
--       · no hay nada estimado (ni horas ni material);
--       · hay horas estimadas y no hay con qué valorarlas (falta el
--         escenario o sus tarifas);
--       · no hay mano de obra estimada y la obra YA lleva mano de obra (real,
--         u horas a estándar);
--       · no hay presupuesto de material y la obra YA lleva material en el
--         libro.
--     estimado_falta empieza por «No hay estimado» (nada estimado, lleve o
--     no real la obra) o por «Estimado incompleto» (hay una parte y falta
--     otra, y dice cuál). Lo que falta y todavía no tiene real (una obra de
--     servicio sin material, por ejemplo) no estorba: se compara lo mismo
--     con lo mismo.
--     Antes la parte que faltaba sumaba 0 y la obra salía «se pasa» o «dentro»
--     contra un real que sí traía ese concepto. Concepto por concepto
--     (fn_margen_obra) se sigue comparando lo que sí está estimado.
--   margen_real (ingreso_libro − costo_real) y su % sobre el ingreso;
--   margen_estimado (contrato − costo_estimado) y su % sobre el contrato;
--   diferencia (costo_estimado − costo_con_estandar: en positivo, la obra
--     va por debajo de lo estimado; vacía si el estimado no está completo o
--     si el estándar no se puede calcular)
--   pagos_sin_repartir (pagos reconocidos en la Bandeja cuya semana tiene
--     horas de esta obra), asientos, avisos (text[], en llano: también las
--     horas tardías de una semana ya repartida y los pagos de mano de obra
--     resueltos fuera del jornal, que dejan horas de esta obra a estándar)
-- (Crece por el final del estimado: se borra y se rehace, porque «create or
-- replace» no cambia las columnas de lo que devuelve; las vistas que la leen
-- se borraron arriba y se rehacen abajo, en este mismo pegado.)
drop function if exists public.fn_margen_obras(text);
create or replace function public.fn_margen_obras(p_proyecto text default null)
returns table (proyecto_id text, obra text, cliente text, tipo text, estado text, completado_el date,
               libro_desde date, parcial boolean, parcial_por text,
               contrato numeric(14,2), ingreso_libro numeric(14,2),
               material_real numeric(14,2), mano_obra_real numeric(14,2), mano_obra_jornales numeric(14,2),
               mano_obra_nomina numeric(14,2), subcontratos_real numeric(14,2), equipo_real numeric(14,2),
               otros_costos_real numeric(14,2), costo_real numeric(14,2),
               horas_reales numeric, horas_co numeric, horas_base numeric, horas_antes_libro numeric,
               horas_con_pago_real numeric, horas_estandar numeric, horas_dueno numeric, horas_sin_aprobar numeric,
               mano_obra_estandar numeric(14,2), mano_obra_estandar_falta text, mano_obra_dueno numeric(14,2),
               burden_estandar_pct numeric, costo_con_estandar numeric(14,2),
               horas_estimadas numeric, tarifa_estimada numeric(10,2), escenario text, estimado_id bigint,
               mano_obra_estimada numeric(14,2), material_presupuesto numeric(14,2), costo_estimado numeric(14,2),
               estimado_completo boolean, estimado_falta text,
               margen_real numeric(14,2), margen_real_pct numeric, margen_estimado numeric(14,2),
               margen_estimado_pct numeric, diferencia numeric(14,2),
               pagos_sin_repartir int, asientos int, avisos text[])
language sql stable
set search_path = public, pg_temp
as $$
  with lb as materialized (select public.fn_margen_libro_desde() as d),
       cfg as materialized (select (select c.burden_estandar_pct from public.jornal_config c where c.id = 1) as b),
       lin as materialized (
         select x.proyecto_id,
                coalesce(sum(x.importe) filter (where x.concepto = 'ingreso'), 0) as ingreso,
                coalesce(sum(x.importe) filter (where x.concepto = 'material'), 0) as material,
                coalesce(sum(x.importe) filter (where x.concepto = 'mano_obra'), 0) as mano_obra,
                coalesce(sum(x.importe) filter (where x.concepto = 'mano_obra' and x.es_jornal), 0) as jornales,
                coalesce(sum(x.importe) filter (where x.concepto = 'subcontratos'), 0) as subcontratos,
                coalesce(sum(x.importe) filter (where x.concepto = 'equipo'), 0) as equipo,
                coalesce(sum(x.importe) filter (where x.concepto = 'otros'), 0) as otros,
                coalesce(sum(x.importe) filter (where x.concepto <> 'ingreso'), 0) as costo,
                count(distinct x.asiento_id)::int as asientos
           from public.fn_margen_lineas(p_proyecto) x
          group by x.proyecto_id),
       hrs as materialized (
         select h.proyecto_id,
                sum(h.horas) as horas,
                coalesce(sum(h.horas) filter (where h.co is not null), 0) as horas_co,
                coalesce(sum(h.horas) filter (where h.clase = 'antes_del_libro'), 0) as antes,
                coalesce(sum(h.horas) filter (where h.clase = 'pago_real'), 0) as pagadas,
                coalesce(sum(h.horas) filter (where h.clase = 'estandar'), 0) as estandar,
                coalesce(sum(h.horas) filter (where h.clase = 'dueno'), 0) as dueno,
                coalesce(sum(h.horas) filter (where not h.aprobada), 0) as sin_aprobar,
                sum(h.monto_estandar) filter (where h.clase = 'estandar') as mo_estandar,
                sum(h.monto_estandar) filter (where h.clase = 'dueno') as mo_dueno,
                string_agg(distinct coalesce(h.persona, 'alguien sin perfil'), ', ')
                  filter (where h.clase = 'estandar' and h.tarifa is null) as sin_tarifa,
                string_agg(distinct h.persona, ', ') filter (where h.clase = 'dueno') as duenos
           from public.fn_margen_horas(p_proyecto) h
          group by h.proyecto_id),
       est as materialized (select * from public.fn_margen_estimado(p_proyecto)),
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
          group by y.proyecto_id),
       pend as materialized (
         -- Los pagos reconocidos que siguen en la Bandeja, por las obras donde
         -- esa persona tiene horas sin pago en la semana que les toca.
         select h.proyecto_id, count(distinct q.id)::int as n
           from (select m.id, jp.usuario_id, per.desde, per.hasta
                   from public.movimientos_banco m
                   join public.jornal_personas jp on jp.activa and public.fn_jornal_texto(m.desc_norm, m.memo) ~* jp.patron
                   cross join lateral public.fn_jornal_periodo(m.fecha) per
                  where m.estado = 'pendiente' and m.monto < 0) q
           join public.horas h on h.usuario_id = q.usuario_id and h.fecha between q.desde and q.hasta and h.proyecto_id is not null
          where (p_proyecto is null or h.proyecto_id = p_proyecto)
            and not exists (select 1 from public.jornal_reparto_horas rh join public.jornal_repartos r on r.id = rh.reparto_id
                             where rh.horas_id = h.id and r.estado = 'aplicado')
            -- (v3: ni las que ya pagó una nómina: su costo sí está en la obra)
            and h.id not in (select n.horas_id from public.fn_margen_horas_nomina() n)
          group by h.proyecto_id),
       tar as materialized (
         -- LAS HORAS TARDÍAS de cada obra (fn_jornal_tardias): de una semana que
         -- esa persona ya tiene repartida, y fuera de su reparto. Salen a
         -- estándar (no tienen pago real repartido) y el pago de esa semana
         -- sigue entero entre las demás obras: se dice, para que no parezca
         -- que la semana costó lo pagado MÁS el estándar.
         select t.proyecto_id, sum(t.horas) as horas,
                string_agg(distinct format('%s, pago del %s', coalesce(t.persona, 'alguien'), public.fn_jornal_dia(t.fecha_pago)), '; ') as quien
           from public.fn_jornal_tardias(null) t
          where t.proyecto_id is not null and (p_proyecto is null or t.proyecto_id = p_proyecto)
          group by t.proyecto_id),
       fue as materialized (
         -- LOS PAGOS RESUELTOS FUERA DEL JORNAL (fn_jornal_fuera) que dejan horas
         -- de esta obra sin pago real: su costo está en otra parte del libro y
         -- estas horas salen, además, a estándar.
         select f.proyecto_id, count(distinct f.movimiento_id)::int as n,
                string_agg(distinct format('%s a %s el %s', public.fn_jornal_usd(f.monto), coalesce(f.persona, 'alguien'),
                                           public.fn_jornal_dia(f.fecha)), '; ') as cual
           from public.fn_jornal_fuera() f
          where f.proyecto_id is not null and (p_proyecto is null or f.proyecto_id = p_proyecto)
          group by f.proyecto_id)
  select p.id, p.nombre, p.cliente, p.tipo, p.estado,
         (case when to_jsonb(p)->>'completado_el' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then left(to_jsonb(p)->>'completado_el', 10)::date end),
         lb.d, pre.proyecto_id is not null, pre.que,
         est.contrato, coalesce(lin.ingreso, 0)::numeric(14,2),
         coalesce(lin.material, 0)::numeric(14,2), coalesce(lin.mano_obra, 0)::numeric(14,2), coalesce(lin.jornales, 0)::numeric(14,2),
         (coalesce(lin.mano_obra, 0) - coalesce(lin.jornales, 0))::numeric(14,2), coalesce(lin.subcontratos, 0)::numeric(14,2),
         coalesce(lin.equipo, 0)::numeric(14,2), coalesce(lin.otros, 0)::numeric(14,2), coalesce(lin.costo, 0)::numeric(14,2),
         coalesce(hrs.horas, 0), coalesce(hrs.horas_co, 0), nullif(p.horas_reales_base, 0), coalesce(hrs.antes, 0),
         coalesce(hrs.pagadas, 0), coalesce(hrs.estandar, 0), coalesce(hrs.dueno, 0), coalesce(hrs.sin_aprobar, 0),
         s.mo_estandar::numeric(14,2), s.falta, hrs.mo_dueno::numeric(14,2), cfg.b,
         (coalesce(lin.costo, 0) + s.mo_estandar)::numeric(14,2),
         est.horas_estimadas, est.tarifa_estimada, est.escenario, est.estimado_id,
         est.mano_obra_estimada, est.material_presupuesto, e.costo::numeric(14,2),
         e.completo, e.falta,
         (coalesce(lin.ingreso, 0) - coalesce(lin.costo, 0))::numeric(14,2),
         case when coalesce(lin.ingreso, 0) <> 0 then round(100 * (lin.ingreso - lin.costo) / lin.ingreso, 1) end,
         (est.contrato - e.costo)::numeric(14,2),
         case when est.contrato <> 0 then round(100 * (est.contrato - e.costo) / est.contrato, 1) end,
         (e.costo - (coalesce(lin.costo, 0) + s.mo_estandar))::numeric(14,2),
         coalesce(pend.n, 0), coalesce(lin.asientos, 0),
         array_remove(array[
           case when pre.proyecto_id is not null
                then format('El libro empieza el %s y esta obra ya tenía de antes: %s. Lo de antes está en QuickBooks: aquí el real es '
                            'parcial.', public.fn_jornal_dia(lb.d, true), pre.que) end,
           case when coalesce(pend.n, 0) > 0
                then format('%s pago(s) de mano de obra de esas semanas siguen sin repartir en la Bandeja: su costo todavía no está en '
                            'esta obra.', pend.n) end,
           -- (v3: «sin pago real» es sin ninguno de los dos: ni un pago repartido por
           -- horas ni una nómina. Las que pagó una nómina ya no salen aquí.)
           case when coalesce(hrs.estandar, 0) > 0
                then format('%s h van a estándar (sin pago real: ni un pago repartido por horas ni una nómina)%s.',
                            public.fn_jornal_h(hrs.estandar),
                            case when s.mo_estandar is not null then ': ' || public.fn_jornal_usd(s.mo_estandar) || ', estándar, no real'
                                 else '' end) end,
           case when s.falta is not null then s.falta end,
           case when tar.proyecto_id is not null
                then format('%s h de esta obra son de una semana ya repartida y no entraron en su reparto (%s): se reportaron o se movieron '
                            'después. Aquí salen a estándar, y el pago de esa semana sigue repartido entre las demás obras. Deshaz ese '
                            'reparto y vuelve a repartirlo con las horas de hoy, o repártelas con el pago que las cubra.',
                            public.fn_jornal_h(tar.horas), tar.quien) end,
           case when fue.proyecto_id is not null
                then format('%s pago(s) de mano de obra se resolvieron en la Bandeja sin repartir por horas (%s): si era el pago de esas '
                            'semanas, su costo está en otra parte del libro y las horas de esta obra salen, además, a estándar. '
                            'Des-cásalo en la Bandeja y repártelo por sus horas.', fue.n, fue.cual) end,
           case when coalesce(hrs.dueno, 0) > 0
                then format('%s h de %s (dueño) no están en el costo: no cobra por hora.', public.fn_jornal_h(hrs.dueno),
                            coalesce(hrs.duenos, 'el dueño')) end,
           case when est.contrato is null then 'Sin contrato en la ficha de la obra.' end,
           case when est.horas_estimadas is null then 'Sin horas estimadas.' end,
           case when est.horas_estimadas is not null and est.tarifa_estimada is null
                then format('Falta el escenario %s del estimador (o sus tarifas): no hay con qué estimar la mano de obra.', est.escenario) end,
           case when est.material_presupuesto is null then 'Sin presupuesto de material.' end,
           case when not e.completo and not e.nada then e.falta end
         ], null)
    from public.proyectos p
    cross join lb
    cross join cfg
    left join lin on lin.proyecto_id = p.id
    left join hrs on hrs.proyecto_id = p.id
    left join est on est.proyecto_id = p.id
    left join pre on pre.proyecto_id = p.id
    left join pend on pend.proyecto_id = p.id
    left join tar on tar.proyecto_id = p.id
    left join fue on fue.proyecto_id = p.id
    cross join lateral (
      select case when coalesce(hrs.estandar, 0) = 0 then 0
                  when cfg.b is null or hrs.sin_tarifa is not null then null
                  else hrs.mo_estandar end as mo_estandar,
             case when coalesce(hrs.estandar, 0) = 0 then null
                  when cfg.b is null
                    then 'Falta fijar el burden estándar (0 si no aplica): la mano de obra estándar no se calcula.'
                  when hrs.sin_tarifa is not null
                    then format('Falta la tarifa de %s en Costos del equipo: la mano de obra estándar no se calcula.', hrs.sin_tarifa)
             end as falta) s
    -- ¿DA EL ESTIMADO UN TOTAL QUE COMPARAR? Qué le falta, y si lo que falta
    -- ya tiene real en la obra (arriba, en la cabecera de la función).
    cross join lateral (
      select (est.horas_estimadas is null and est.material_presupuesto is null) as nada,
             (est.horas_estimadas is not null and est.tarifa_estimada is null) as mo_sin_tarifa,
             (est.mano_obra_estimada is null and (coalesce(lin.mano_obra, 0) <> 0 or coalesce(hrs.estandar, 0) > 0)) as mo_falta,
             (est.material_presupuesto is null and coalesce(lin.material, 0) <> 0) as mat_falta) q
    cross join lateral (
      select q.nada,
             not (q.nada or q.mo_sin_tarifa or q.mo_falta or q.mat_falta) as completo,
             case when not (q.nada or q.mo_sin_tarifa or q.mo_falta or q.mat_falta)
                  then coalesce(est.mano_obra_estimada, 0) + coalesce(est.material_presupuesto, 0) end as costo,
             -- (sin nada estimado —ni horas ni material— es «no hay estimado», lleve o
             -- no lleve real la obra; «incompleto» es cuando hay una parte y falta otra)
             case when q.nada then 'No hay estimado: faltan las horas estimadas y el presupuesto de material.'
                  when q.mo_sin_tarifa or q.mo_falta or q.mat_falta
                    then 'Estimado incompleto: '
                         || concat_ws('; y ',
                              case when q.mo_sin_tarifa
                                     then format('hay %s h estimadas y falta el escenario %s del estimador (o sus tarifas) para valorarlas',
                                                 public.fn_jornal_h(est.horas_estimadas), est.escenario)
                                   when q.mo_falta
                                     then format('no tiene horas estimadas y ya lleva mano de obra (%s)',
                                                 concat_ws(' y ',
                                                   case when coalesce(lin.mano_obra, 0) <> 0 then public.fn_jornal_usd(lin.mano_obra) || ' real' end,
                                                   case when coalesce(hrs.estandar, 0) > 0 then public.fn_jornal_h(hrs.estandar) || ' h a estándar' end)) end,
                              case when q.mat_falta
                                     then format('no tiene presupuesto de material y ya lleva %s de material en el libro',
                                                 public.fn_jornal_usd(lin.material)) end)
                         || '. No da un total que comparar con el costo real: se compara concepto por concepto lo que sí está estimado.'
             end as falta) e
   where (p_proyecto is null or p.id = p_proyecto)
     and (select public.fn_jornal_ve())
$$;
revoke execute on function public.fn_margen_obras(text) from public, anon, service_role;
grant  execute on function public.fn_margen_obras(text) to authenticated;
comment on function public.fn_margen_obras(text) is 'c10: la fila de v_margen_obra para todas las obras, o para una: el real del libro por concepto (la mano de obra, real: jornales y nómina), las horas por clase, la mano de obra estándar («estándar, no real»: nunca se postea), el estimado de las fuentes de la app (costo_estimado solo si da un total que comparar: estimado_completo; si no, estimado_falta dice qué falta), los márgenes, la diferencia y los avisos en llano (también las horas tardías y los pagos resueltos fuera del jornal). Solo lectura.';

-- La llave «bajar» (la de c4: los pedazos de v_libro que suman una cifra)
-- de un concepto del real de una obra. Las líneas de un jornal se piden por
-- sus asientos (los de cada reparto y los de su reverso); las demás, por su
-- cuenta, sin esos asientos.
create or replace function public.fn_margen_bajar(p_proyecto text, p_concepto text, p_cuenta text default null)
returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  with j as materialized (
         -- (los asientos de los jornales que tocan la obra, y sus reversos: de
         -- las tablas del jornal, por su índice; son los mismos que marcan
         -- es_jornal en fn_margen_lineas)
         select coalesce(jsonb_agg(distinct x.id), '[]'::jsonb) as ids
           from (select r.asiento_id as id
                   from public.jornal_reparto_lineas l
                   join public.jornal_repartos r on r.id = l.reparto_id
                  where l.proyecto_id = p_proyecto and l.orden is not null
                 union all
                 select rv.id
                   from public.jornal_reparto_lineas l
                   join public.jornal_repartos r on r.id = l.reparto_id
                   join public.asientos rv on rv.reversa_a = r.asiento_id
                  where l.proyecto_id = p_proyecto and l.orden is not null) x),
       k as materialized (
         select coalesce(jsonb_agg(c.codigo order by c.codigo) filter (where c.tipo = 'ingreso'), '[]'::jsonb) as ingreso,
                coalesce(jsonb_agg(c.codigo order by c.codigo) filter (where c.tipo = 'costo'), '[]'::jsonb) as costo,
                coalesce(jsonb_agg(c.codigo order by c.codigo) filter (where c.tipo = 'costo' and c.codigo like '50%'), '[]'::jsonb) as nomina,
                coalesce(jsonb_agg(c.codigo order by c.codigo)
                           filter (where c.tipo = 'costo' and c.codigo not like '50%' and c.codigo not in ('5100', '5200', '5300')),
                         '[]'::jsonb) as otros
           from public.cuentas c),
       b as (select jsonb_build_object('vista', 'v_libro', 'campo', 'monto') as base,
                    jsonb_build_object('proyecto_id', p_proyecto) as f,
                    case when jsonb_array_length(j.ids) > 0 then jsonb_build_object('asiento_id_no', j.ids) else '{}'::jsonb end as sin_j,
                    j.ids, k.*
               from j cross join k)
  select case p_concepto
           when 'ingreso' then jsonb_build_array(b.base || jsonb_build_object('signo', -1, 'filtros', b.f || jsonb_build_object('cuenta', b.ingreso)))
           when 'costo' then jsonb_build_array(b.base || jsonb_build_object('signo', 1, 'filtros', b.f || jsonb_build_object('cuenta', b.costo)))
           when 'material' then jsonb_build_array(b.base || jsonb_build_object('signo', 1, 'filtros', b.f || jsonb_build_object('cuenta', '5100') || b.sin_j))
           when 'subcontratos' then jsonb_build_array(b.base || jsonb_build_object('signo', 1, 'filtros', b.f || jsonb_build_object('cuenta', '5200') || b.sin_j))
           when 'equipo' then jsonb_build_array(b.base || jsonb_build_object('signo', 1, 'filtros', b.f || jsonb_build_object('cuenta', '5300') || b.sin_j))
           when 'otros' then jsonb_build_array(b.base || jsonb_build_object('signo', 1, 'filtros', b.f || jsonb_build_object('cuenta', b.otros) || b.sin_j))
           when 'mano_obra_jornales'
             then case when jsonb_array_length(b.ids) > 0
                       then jsonb_build_array(b.base || jsonb_build_object('signo', 1, 'filtros', b.f || jsonb_build_object('asiento_id', b.ids, 'cuenta', b.costo)))
                       else '[]'::jsonb end
           when 'mano_obra_nomina' then jsonb_build_array(b.base || jsonb_build_object('signo', 1, 'filtros', b.f || jsonb_build_object('cuenta', b.nomina) || b.sin_j))
           when 'mano_obra'
             then (case when jsonb_array_length(b.ids) > 0
                        then jsonb_build_array(b.base || jsonb_build_object('signo', 1, 'filtros', b.f || jsonb_build_object('asiento_id', b.ids, 'cuenta', b.costo)))
                        else '[]'::jsonb end)
                  || jsonb_build_array(b.base || jsonb_build_object('signo', 1, 'filtros', b.f || jsonb_build_object('cuenta', b.nomina) || b.sin_j))
           when 'cuenta' then jsonb_build_array(b.base || jsonb_build_object('signo', 1, 'filtros', b.f || jsonb_build_object('cuenta', p_cuenta) || b.sin_j))
           when 'cuenta_jornal'
             then case when jsonb_array_length(b.ids) > 0
                       then jsonb_build_array(b.base || jsonb_build_object('signo', 1, 'filtros', b.f || jsonb_build_object('asiento_id', b.ids, 'cuenta', p_cuenta)))
                       else '[]'::jsonb end
         end
    from b
   where (select public.fn_jornal_ve())
$$;
revoke execute on function public.fn_margen_bajar(text, text, text) from public, anon, service_role;
grant  execute on function public.fn_margen_bajar(text, text, text) to authenticated;
comment on function public.fn_margen_bajar(text, text, text) is 'c10: la llave «bajar» de c4 (los pedazos de v_libro que suman una cifra) para un concepto del real de una obra: ingreso, costo, material, subcontratos, equipo, otros, mano_obra (o mano_obra_jornales y mano_obra_nomina), y por cuenta (cuenta, cuenta_jornal). Las líneas de un jornal se piden por sus asientos.';

-- EL DETALLE DE UNA OBRA: {obra (su fila de v_margen_obra), conceptos
-- (estimado contra real: material, mano de obra —con su real y su
-- estándar—, subcontratos, equipo, otros y el total, cada número del real
-- con su «bajar»), por_cuenta, por_co (la base aparte de cada CO), por_fase
-- (horas y dólares de mano de obra), por_cost_code (o «todavía no hay nada
-- capturado con código»), cobertura (por persona: cuántas horas con pago
-- real y cuántas a estándar), repartos (los que la tocan) y avisos}.
-- (v3) CON HORAS QUE PAGÓ UNA NÓMINA. Su dinero está en el libro por obra y
-- CO (5000, 5001, 5010: el concepto «mano de obra real», por cuenta y por
-- CO lo traen como siempre), pero NO por fase ni por persona: lo que le
-- tocó a cada hora es el sueldo de alguien y vive en la nómina, con el
-- código del teléfono. Aquí se dice cuántas son y no se inventa su importe:
--   · por_fase y cobertura traen horas_nomina (las que pagó una nómina) y
--     mano_obra_jornales / pagado_jornales (lo que sí se sabe: lo repartido
--     de los pagos por horas). mano_obra_real (por fase) y pagado (por
--     persona) salen VACÍOS —no en cero— cuando hay horas de nómina, con su
--     nota: ya no son el total;
--   · nominas: las nóminas que pagaron horas de esta obra (su día de pago,
--     cuántos reportes y cuántas horas), sin importes.
create or replace function public.fn_margen_obra(p_proyecto text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  o          record;
  v_concep   jsonb;
  v_cuentas  jsonb;
  v_co       jsonb;
  v_fase     jsonb;
  v_cc       jsonb;
  v_cob      jsonb;
  v_rep      jsonb;
  v_alc      jsonb := '[]'::jsonb;
  v_lin      jsonb;
  v_hor      jsonb;
  v_nom      bigint[];
  v_nominas  jsonb;
  v_mapa     jsonb;
  c_nota_nom constant text := 'Parte de estas horas las pagó una nómina: su costo está en el libro por obra (la mano de obra de nómina), '
                              'y lo que le tocó a cada persona se ve en Nómina, con el código del teléfono.';
begin
  perform fn_jornal_exigir_dueno();
  if coalesce(btrim(p_proyecto), '') = '' then
    raise exception using errcode = '22023', message = 'Di de qué obra (p_proyecto).';
  end if;
  select * into o from fn_margen_obras(p_proyecto);
  if not found then
    raise exception using errcode = '22023', message = format('No existe la obra «%s».', p_proyecto);
  end if;
  -- Las líneas del libro y las horas de la obra, leídas UNA vez: de ahí salen
  -- todos los cortes de abajo.
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_lin from fn_margen_lineas(p_proyecto) x;
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_hor from fn_margen_horas(p_proyecto) x;
  -- (v3) Los reportes de esta obra que pagó una nómina, y qué nóminas: sin
  -- importes (lo que le tocó a cada hora no se lee aquí). La marca se lee
  -- UNA vez y cada reporte suyo se busca entre los de la obra (v_hor) por su
  -- número, en un diccionario: sin un cruce que dependa de cómo lo planee la
  -- base (ver fn_margen_horas).
  select coalesce(jsonb_object_agg(x.horas_id::text, x.horas), '{}'::jsonb) into v_mapa
    from jsonb_to_recordset(v_hor) as x(horas_id bigint, horas numeric);
  with nm as materialized (
         select n.horas_id, n.corrida_id, n.dia_pago, (v_mapa->>(n.horas_id::text))::numeric as horas
           from fn_margen_horas_nomina() n
          where v_mapa ? (n.horas_id::text))
  select coalesce((select array_agg(nm.horas_id) from nm), '{}'),
         coalesce((select jsonb_agg(jsonb_build_object('corrida_id', z.corrida_id, 'dia_pago', z.dia_pago, 'reportes', z.n, 'horas', z.h)
                                    order by z.dia_pago, z.corrida_id)
                     from (select nm.corrida_id, nm.dia_pago, count(*) as n, sum(nm.horas) as h
                             from nm
                            group by nm.corrida_id, nm.dia_pago) z), '[]'::jsonb)
    into v_nom, v_nominas;

  -- Estimado contra real, por concepto.
  v_concep := jsonb_build_array(
    jsonb_build_object('concepto', 'material', 'nivel', 'concepto', 'etiqueta', 'Material',
                       'estimado', o.material_presupuesto, 'real', o.material_real, 'estandar', null, 'total', o.material_real,
                       'diferencia', o.material_presupuesto - o.material_real, 'bajar', fn_margen_bajar(p_proyecto, 'material')),
    jsonb_build_object('concepto', 'mano_obra', 'nivel', 'concepto', 'etiqueta', 'Mano de obra',
                       'estimado', o.mano_obra_estimada, 'real', o.mano_obra_real, 'estandar', o.mano_obra_estandar,
                       'total', o.mano_obra_real + o.mano_obra_estandar,
                       'diferencia', o.mano_obra_estimada - (o.mano_obra_real + o.mano_obra_estandar),
                       'horas_estimadas', o.horas_estimadas, 'horas_reales', o.horas_reales, 'tarifa_estimada', o.tarifa_estimada,
                       'bajar', fn_margen_bajar(p_proyecto, 'mano_obra')),
    jsonb_build_object('concepto', 'mano_obra_real', 'nivel', 'detalle', 'etiqueta', 'Mano de obra real (pagada y repartida)',
                       'estimado', null, 'real', o.mano_obra_real, 'estandar', null, 'total', o.mano_obra_real, 'diferencia', null,
                       'horas', o.horas_con_pago_real, 'jornales', o.mano_obra_jornales, 'nomina', o.mano_obra_nomina,
                       'horas_nomina', (select coalesce(sum(h.horas), 0)
                                          from jsonb_to_recordset(v_hor) as h(horas_id bigint, horas numeric, clase text)
                                         where h.clase = 'pago_real' and h.horas_id = any (v_nom)),
                       'bajar', fn_margen_bajar(p_proyecto, 'mano_obra')),
    jsonb_build_object('concepto', 'mano_obra_estandar', 'nivel', 'detalle', 'etiqueta', 'Mano de obra estándar, no real',
                       'estimado', null, 'real', null, 'estandar', o.mano_obra_estandar, 'total', o.mano_obra_estandar,
                       'diferencia', null, 'horas', o.horas_estandar, 'burden_estandar_pct', o.burden_estandar_pct,
                       -- (con la tarifa y el burden de HOY: costos_equipo no guarda su
                       -- historia, y si la tarifa de alguien cambia, cambia el estándar de
                       -- todas sus horas sin pago, también las de obras ya terminadas. Es
                       -- una estimación para comparar, nunca un asiento: se dice.)
                       'nota', coalesce(o.mano_obra_estandar_falta,
                                        'Horas sin pago real (ni un pago repartido por horas ni una nómina) × la tarifa de Costos del '
                                        'equipo × (1 + burden estándar), con la tarifa y el burden de hoy (si cambian, este número '
                                        'cambia). No está en el libro.')),
    jsonb_build_object('concepto', 'subcontratos', 'nivel', 'concepto', 'etiqueta', 'Subcontratos',
                       'estimado', null, 'real', o.subcontratos_real, 'estandar', null, 'total', o.subcontratos_real, 'diferencia', null,
                       'bajar', fn_margen_bajar(p_proyecto, 'subcontratos')),
    jsonb_build_object('concepto', 'equipo', 'nivel', 'concepto', 'etiqueta', 'Equipo y renta',
                       'estimado', null, 'real', o.equipo_real, 'estandar', null, 'total', o.equipo_real, 'diferencia', null,
                       'bajar', fn_margen_bajar(p_proyecto, 'equipo')),
    jsonb_build_object('concepto', 'otros', 'nivel', 'concepto', 'etiqueta', 'Otros costos de obra',
                       'estimado', null, 'real', o.otros_costos_real, 'estandar', null, 'total', o.otros_costos_real, 'diferencia', null,
                       'bajar', fn_margen_bajar(p_proyecto, 'otros')),
    -- (el total estimado y su diferencia solo salen si el estimado da un total
    -- que comparar: estimado_completo; si no, su nota dice qué falta)
    jsonb_build_object('concepto', 'total', 'nivel', 'total', 'etiqueta', 'Costo de la obra',
                       'estimado', o.costo_estimado, 'real', o.costo_real, 'estandar', o.mano_obra_estandar,
                       'total', o.costo_con_estandar, 'diferencia', o.diferencia, 'estimado_completo', o.estimado_completo,
                       'nota', o.estimado_falta, 'bajar', fn_margen_bajar(p_proyecto, 'costo')),
    jsonb_build_object('concepto', 'ingreso', 'nivel', 'ingreso', 'etiqueta', 'Facturado (en el libro)',
                       'estimado', o.contrato, 'real', o.ingreso_libro, 'estandar', null, 'total', o.ingreso_libro,
                       'diferencia', null, 'bajar', fn_margen_bajar(p_proyecto, 'ingreso')));

  -- Por cuenta (los jornales, aparte de lo demás de su cuenta).
  select coalesce(jsonb_agg(jsonb_build_object(
           'cuenta', x.cuenta, 'nombre', cu.nombre, 'concepto', x.concepto, 'jornal', x.es_jornal, 'real', x.real, 'asientos', x.asientos,
           'bajar', fn_margen_bajar(p_proyecto, case when x.es_jornal then 'cuenta_jornal' else 'cuenta' end, x.cuenta))
           order by x.cuenta, x.es_jornal), '[]'::jsonb)
    into v_cuentas
    from (select l.cuenta, l.concepto, l.es_jornal, sum(l.importe) as real, count(distinct l.asiento_id) as asientos
            from jsonb_to_recordset(v_lin) as l(proyecto_id text, asiento_id uuid, orden int, numero text, fecha date, cuenta text, concepto text, co text, fase text, cost_code text, importe numeric, es_jornal boolean, reparto_id uuid)
           where l.concepto <> 'ingreso'
           group by l.cuenta, l.concepto, l.es_jornal) x
    join cuentas cu on cu.codigo = x.cuenta;

  -- El estimado de cada CO vive en alcances (f10): su monto, si su
  -- referencia es la del CO (el mismo número, o el mismo texto). Si la tabla
  -- no está o cambió, nada.
  begin
    select coalesce(jsonb_agg(jsonb_build_object('ref', a.ref, 'titulo', a.titulo, 'monto', a.monto, 'tipo', a.tipo, 'estado', a.estado)), '[]'::jsonb)
      into v_alc
      from alcances a where a.proyecto_id = p_proyecto and nullif(btrim(a.ref), '') is not null;
  exception when others then
    v_alc := '[]'::jsonb;
  end;

  -- Por CO: la base (co nulo) aparte de cada CO.
  select coalesce(jsonb_agg(jsonb_build_object(
           'co', z.co, 'etiqueta', coalesce(z.co, 'Base (sin CO)'),
           'horas', coalesce(z.horas, 0), 'horas_con_pago_real', coalesce(z.pagadas, 0), 'horas_estandar', coalesce(z.estandar, 0),
           'mano_obra_real', coalesce(z.mano_obra, 0), 'mano_obra_estandar', z.mo_estandar,
           'material_real', coalesce(z.material, 0), 'subcontratos_real', coalesce(z.subcontratos, 0),
           'equipo_real', coalesce(z.equipo, 0), 'otros_costos_real', coalesce(z.otros, 0), 'costo_real', coalesce(z.costo, 0),
           'ingreso_libro', coalesce(z.ingreso, 0),
           'alcance', (select al from jsonb_array_elements(v_alc) al
                        where z.co is not null
                          and (lower(btrim(al->>'ref')) = lower(z.co)
                               or (substring(al->>'ref' from '(?i)^\s*c\.?\s*o\.?\s*[#\-\s]*\s*([0-9]+)\s*$')
                                   = substring(z.co from '(?i)^\s*c\.?\s*o\.?\s*[#\-\s]*\s*([0-9]+)\s*$')))
                        limit 1))
           order by (z.co is not null), z.co), '[]'::jsonb)
    into v_co
    from (select coalesce(a.co, b.co) as co, a.mano_obra, a.material, a.subcontratos, a.equipo, a.otros, a.costo, a.ingreso,
                 b.horas, b.pagadas, b.estandar, b.mo_estandar
            from (select l.co,
                         sum(l.importe) filter (where l.concepto = 'mano_obra') as mano_obra,
                         sum(l.importe) filter (where l.concepto = 'material') as material,
                         sum(l.importe) filter (where l.concepto = 'subcontratos') as subcontratos,
                         sum(l.importe) filter (where l.concepto = 'equipo') as equipo,
                         sum(l.importe) filter (where l.concepto = 'otros') as otros,
                         sum(l.importe) filter (where l.concepto <> 'ingreso') as costo,
                         sum(l.importe) filter (where l.concepto = 'ingreso') as ingreso
                    from jsonb_to_recordset(v_lin) as l(proyecto_id text, asiento_id uuid, orden int, numero text, fecha date, cuenta text, concepto text, co text, fase text, cost_code text, importe numeric, es_jornal boolean, reparto_id uuid) group by l.co) a
            full join (select h.co, sum(h.horas) as horas,
                              sum(h.horas) filter (where h.clase = 'pago_real') as pagadas,
                              sum(h.horas) filter (where h.clase = 'estandar') as estandar,
                              case when count(*) filter (where h.clase = 'estandar' and h.monto_estandar is null) = 0
                                   then coalesce(sum(h.monto_estandar) filter (where h.clase = 'estandar'), 0) end as mo_estandar
                         from jsonb_to_recordset(v_hor) as h(horas_id bigint, proyecto_id text, usuario_id uuid, persona text, es_dueno boolean, fecha date, co text, fase text, horas numeric, aprobada boolean, clase text, tarifa numeric, monto_real numeric, monto_estandar numeric, repartos int) group by h.co) b on coalesce(b.co, chr(1)) = coalesce(a.co, chr(1))) z;

  -- Por fase: horas y dólares de mano de obra (lo real, del detalle de los
  -- repartos; lo estándar, de las horas sin pago), y lo demás del libro que
  -- lleve esa fase.
  -- (v3: con horas de nómina en la fase, su mano de obra real ya no es solo
  -- lo repartido de los jornales, y lo de la nómina no se lleva por fase:
  -- mano_obra_real sale vacía, con su nota; mano_obra_jornales, lo que se sabe)
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
             'nota', case when coalesce(z.h_nomina, 0) > 0 then c_nota_nom end))
           || jsonb_build_object(
           'fase', z.fase, 'etiqueta', coalesce(z.fase, 'Sin fase'),
           'horas', coalesce(z.horas, 0), 'horas_con_pago_real', coalesce(z.pagadas, 0),
           'mano_obra_real', case when coalesce(z.h_nomina, 0) > 0 then null else coalesce(z.pagado, 0) end,
           'mano_obra_jornales', coalesce(z.pagado, 0), 'horas_nomina', coalesce(z.h_nomina, 0),
           'horas_estandar', coalesce(z.estandar, 0), 'mano_obra_estandar', z.mo_estandar,
           'horas_dueno', coalesce(z.dueno, 0), 'horas_antes_libro', coalesce(z.antes, 0),
           'otros_costos_libro', coalesce(z.libro, 0)) order by (z.fase is null), z.fase), '[]'::jsonb)
    into v_fase
    from (select coalesce(b.fase, a.fase) as fase, b.horas, b.pagadas, b.pagado, b.h_nomina, b.estandar, b.mo_estandar, b.dueno, b.antes, a.libro
            from (select h.fase, sum(h.horas) as horas,
                         sum(h.horas) filter (where h.clase = 'pago_real') as pagadas,
                         sum(h.monto_real) as pagado,
                         sum(h.horas) filter (where h.clase = 'pago_real' and h.horas_id = any (v_nom)) as h_nomina,
                         sum(h.horas) filter (where h.clase = 'estandar') as estandar,
                         case when count(*) filter (where h.clase = 'estandar' and h.monto_estandar is null) = 0
                              then coalesce(sum(h.monto_estandar) filter (where h.clase = 'estandar'), 0) end as mo_estandar,
                         sum(h.horas) filter (where h.clase = 'dueno') as dueno,
                         sum(h.horas) filter (where h.clase = 'antes_del_libro') as antes
                    from jsonb_to_recordset(v_hor) as h(horas_id bigint, proyecto_id text, usuario_id uuid, persona text, es_dueno boolean, fecha date, co text, fase text, horas numeric, aprobada boolean, clase text, tarifa numeric, monto_real numeric, monto_estandar numeric, repartos int) group by h.fase) b
            full join (select l.fase, sum(l.importe) as libro
                         from jsonb_to_recordset(v_lin) as l(proyecto_id text, asiento_id uuid, orden int, numero text, fecha date, cuenta text, concepto text, co text, fase text, cost_code text, importe numeric, es_jornal boolean, reparto_id uuid)
                        where l.concepto <> 'ingreso' and not l.es_jornal and l.fase is not null
                        group by l.fase) a on coalesce(a.fase, chr(1)) = coalesce(b.fase, chr(1))) z;

  -- Por cost code: solo lo que las líneas llevan.
  select jsonb_build_object(
           'hay', count(*) > 0,
           'nota', case when count(*) = 0
                        then 'Todavía no hay nada capturado con código en esta obra: las líneas del libro no traen cost code (el ticket '
                             'no lo lleva). Se compara por obra y por cuenta.'
                        else format('%s de costo llevan código; el resto (%s) no.', fn_jornal_usd(coalesce(sum(x.real), 0)),
                                    fn_jornal_usd(o.costo_real - coalesce(sum(x.real), 0))) end,
           'filas', coalesce(jsonb_agg(jsonb_build_object('cost_code', x.cost_code, 'nombre', cp.nombre, 'real', x.real, 'asientos', x.asientos,
                                                          'bajar', jsonb_build_array(jsonb_build_object(
                                                             'vista', 'v_libro', 'campo', 'monto', 'signo', 1,
                                                             'filtros', jsonb_build_object('proyecto_id', p_proyecto, 'cost_code', x.cost_code,
                                                                                           'cuenta', x.cuentas))))
                                       order by x.cost_code), '[]'::jsonb))
    into v_cc
    from (select l.cost_code, sum(l.importe) as real, count(distinct l.asiento_id) as asientos, jsonb_agg(distinct l.cuenta) as cuentas
            from jsonb_to_recordset(v_lin) as l(proyecto_id text, asiento_id uuid, orden int, numero text, fecha date, cuenta text, concepto text, co text, fase text, cost_code text, importe numeric, es_jornal boolean, reparto_id uuid)
           where l.concepto <> 'ingreso' and l.cost_code is not null
           group by l.cost_code) x
    left join codigos_partida cp on cp.codigo = x.cost_code;

  -- La cobertura de la mano de obra, por persona.
  -- (v3: a quien le pagó horas una nómina, «pagado» ya no es lo que cobró por
  -- esta obra —eso es su sueldo, y está en la nómina, con el código—: sale
  -- vacío, con su nota; pagado_jornales es lo repartido de sus pagos por horas)
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
             'nota', case when z.h_nomina > 0 then c_nota_nom end))
           || jsonb_build_object(
           'usuario_id', z.usuario_id, 'persona', z.persona, 'es_dueno', z.es_dueno, 'tarifa', z.tarifa,
           'horas', z.horas, 'horas_con_pago_real', z.pagadas,
           'pagado', case when z.h_nomina > 0 then null else z.pagado end,
           'pagado_jornales', z.pagado, 'horas_nomina', z.h_nomina,
           'horas_estandar', z.estandar, 'estandar', z.mo_estandar, 'horas_dueno', z.dueno, 'horas_antes_libro', z.antes,
           'horas_sin_aprobar', z.sin_aprobar) order by z.es_dueno, z.persona, z.usuario_id), '[]'::jsonb)
    into v_cob
    from (select h.usuario_id, max(h.persona) as persona, bool_or(h.es_dueno) as es_dueno, max(h.tarifa) as tarifa,
                 sum(h.horas) as horas,
                 coalesce(sum(h.horas) filter (where h.clase = 'pago_real'), 0) as pagadas, sum(h.monto_real) as pagado,
                 coalesce(sum(h.horas) filter (where h.clase = 'pago_real' and h.horas_id = any (v_nom)), 0) as h_nomina,
                 coalesce(sum(h.horas) filter (where h.clase = 'estandar'), 0) as estandar,
                 sum(h.monto_estandar) filter (where h.clase in ('estandar', 'dueno')) as mo_estandar,
                 coalesce(sum(h.horas) filter (where h.clase = 'dueno'), 0) as dueno,
                 coalesce(sum(h.horas) filter (where h.clase = 'antes_del_libro'), 0) as antes,
                 coalesce(sum(h.horas) filter (where not h.aprobada), 0) as sin_aprobar
            from jsonb_to_recordset(v_hor) as h(horas_id bigint, proyecto_id text, usuario_id uuid, persona text, es_dueno boolean, fecha date, co text, fase text, horas numeric, aprobada boolean, clase text, tarifa numeric, monto_real numeric, monto_estandar numeric, repartos int)
           group by h.usuario_id) z;

  -- Los repartos que la tocan (aplicados y deshechos).
  select coalesce(jsonb_agg(jsonb_build_object(
           'reparto_id', r.id, 'estado', r.estado, 'fecha_pago', mm.fecha, 'usuario_id', r.usuario_id, 'persona', pf.nombre,
           'desde', r.desde, 'hasta', r.hasta, 'monto', r.monto, 'horas', r.horas,
           'monto_obra', x.monto, 'horas_obra', x.horas, 'asiento_id', r.asiento_id, 'asiento', a.numero,
           'reverso_id', r.reverso_id, 'deshecho_motivo', r.deshecho_motivo) order by mm.fecha, r.creado_el), '[]'::jsonb)
    into v_rep
    from (select l.reparto_id, sum(l.monto) as monto, sum(l.horas) as horas
            from jornal_reparto_lineas l where l.proyecto_id = p_proyecto group by l.reparto_id) x
    join jornal_repartos r on r.id = x.reparto_id
    join movimientos_banco mm on mm.id = r.movimiento_id
    left join perfiles pf on pf.id = r.usuario_id
    left join asientos a on a.id = r.asiento_id;

  return jsonb_build_object(
    'obra', to_jsonb(o), 'conceptos', v_concep, 'por_cuenta', v_cuentas, 'por_co', v_co, 'por_fase', v_fase,
    'por_cost_code', v_cc, 'cobertura', v_cob, 'repartos', v_rep, 'nominas', v_nominas, 'avisos', to_jsonb(o.avisos));
end $$;
revoke execute on function public.fn_margen_obra(text) from public, anon, service_role;
grant  execute on function public.fn_margen_obra(text) to authenticated;
comment on function public.fn_margen_obra(text) is 'c10: el detalle de una obra: su fila de v_margen_obra, estimado contra real por concepto (material, mano de obra con su real y su estándar, subcontratos, equipo, otros, el total y lo facturado; cada número del real con su «bajar» a v_libro), por cuenta, por CO (la base aparte), por fase (horas y dólares de mano de obra), por cost code (o que todavía no hay nada con código), la cobertura de la mano de obra por persona, los repartos que la tocan y las nóminas que pagaron horas suyas (su día de pago y cuántas horas; sin importes: por fase y por persona, lo de la nómina no se lleva aquí y se dice: horas_nomina, y mano_obra_real / pagado vacíos con su nota). Solo lectura. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 9. Las vistas de la pantalla (security_invoker; leen solo tablas y
--    funciones de aquí; se borraron al principio del apartado 4 y se
--    rehacen aquí). De periodos y de cuentas no nombran estado, cadena_al_
--    cerrar, activa ni saldo_normal: lo que haga falta se lee de la fila
--    entera (to_jsonb), como c4, c6, c8 y c9, para no fijarles el tipo
--    (c2-pruebas las reescribe a propósito). A quien no es el dueño no le
--    dan ni una fila.
-- ---------------------------------------------------------------------
-- LOS PAGOS RECONOCIDOS QUE ESPERAN EN LA BANDEJA: los movimientos
-- pendientes que son el pago de UNA persona dada de alta, con su período
-- por defecto y lo que saldría (la misma cuenta que fn_jornal_propuesta sin
-- fechas). La Bandeja pinta estas tarjetas como «mano de obra».
create view public.v_jornal_pendientes with (security_invoker = true) as
select m.id                                         as movimiento_id,
       m.cuenta,
       m.fecha,
       (-m.monto)::numeric(14,2)                    as monto,
       m.descripcion,
       (c.j->'persona'->>'usuario_id')::uuid        as usuario_id,
       c.j->'persona'->>'nombre'                    as persona,
       (c.j->'persona'->>'tarifa')::numeric         as tarifa,
       (c.j->'periodo'->>'desde')::date             as desde,
       (c.j->'periodo'->>'hasta')::date             as hasta,
       c.j->'periodo'->>'regla'                     as regla,
       c.j->'periodo'->>'texto'                     as periodo_texto,
       (c.j->>'horas')::numeric                     as horas,
       (c.j->>'reportes')::int                      as reportes,
       (c.j->>'obras')::int                         as obras,
       (c.j->'sin_obra'->>'horas')::numeric         as horas_sin_obra,
       (c.j->>'tarifa_sale')::numeric               as tarifa_sale,
       (c.j->>'puede_aplicar')::boolean             as puede_aplicar,
       c.j->>'por_que'                              as por_que,
       (select string_agg(a->>'corto', ' · ') from jsonb_array_elements(c.j->'avisos') a) as aviso,
       jsonb_array_length(c.j->'avisos')            as n_avisos,
       c.j->'avisos'                                as avisos,
       c.j->'lineas'                                as lineas,
       c.j->>'visto'                                as visto,
       (c.j->>'propuesta_ia')::uuid                 as propuesta_ia
  from (select mm.id, mm.cuenta, mm.fecha, mm.monto, mm.descripcion
          from public.movimientos_banco mm
         where mm.estado = 'pendiente' and mm.monto < 0
           and exists (select 1 from public.jornal_personas jp
                        where jp.activa and public.fn_jornal_texto(mm.desc_norm, mm.memo) ~* jp.patron)
        offset 0) m
  -- («offset 0»: el cálculo se hace UNA vez por pago; sin él, el planificador
  -- lo repetiría en cada columna que lo lee)
  cross join lateral (select public.fn_jornal_calcular(m.id, null, null, '{}'::jsonb) as j offset 0) c
 where (c.j->>'reconocido')::boolean;
revoke all on public.v_jornal_pendientes from public, anon, authenticated, service_role;
grant select on public.v_jornal_pendientes to authenticated;
comment on view public.v_jornal_pendientes is 'c10: los movimientos pendientes de la Bandeja reconocidos como el pago de una persona dada de alta: el movimiento (fecha, monto en positivo, descripción), la persona y su tarifa, el período por defecto (desde, hasta, regla, texto), las horas, los reportes y el nº de obras que entran, las horas sin obra, la tarifa que sale, si se puede aplicar (y por qué no), los avisos (aviso: sus etiquetas cortas; avisos: enteros), las líneas, la huella (visto) y la propuesta pendiente de la IA si la hay. Es fn_jornal_propuesta sin fechas, fila por fila.';

-- EL HISTORIAL DE REPARTOS, con el nombre, el movimiento, el asiento y, si
-- se deshizo, quién, cuándo, por qué y su reverso.
create view public.v_jornal_repartos with (security_invoker = true) as
select r.id                         as reparto_id,
       r.estado,
       r.movimiento_id,
       m.fecha                      as fecha_pago,
       m.cuenta                     as cuenta_banco,
       m.descripcion,
       r.usuario_id,
       pf.nombre                    as persona,
       r.desde,
       r.hasta,
       r.regla_periodo,
       public.fn_jornal_rango(r.desde, r.hasta) as periodo_texto,
       r.monto,
       r.horas,
       r.tarifa_sale,
       r.tarifa_equipo,
       r.cuenta,
       r.cuenta_sin_obra,
       (select count(distinct l.proyecto_id) from public.jornal_reparto_lineas l
         where l.reparto_id = r.id and l.proyecto_id is not null)::int as obras,
       (select jsonb_agg(jsonb_build_object('n', l.n, 'orden', l.orden, 'proyecto_id', l.proyecto_id, 'obra', pr.nombre, 'co', l.co,
                                            'cuenta', l.cuenta, 'horas', l.horas, 'monto', l.monto) order by l.n)
          from public.jornal_reparto_lineas l
          left join public.proyectos pr on pr.id = l.proyecto_id
         where l.reparto_id = r.id) as lineas,
       r.asiento_id,
       a.numero                     as asiento,
       a.fecha_contable             as asiento_fecha,
       (r.estado = 'aplicado'
        and not exists (select 1 from public.asientos x where x.reversa_a = r.asiento_id and x.camino = 'reverso')) as asiento_vivo,
       r.avisos,
       r.opciones,
       jsonb_array_length(r.horas_aprobadas) as horas_aprobadas,
       r.creado_el,
       r.creado_por,
       pc.nombre                    as creado_por_nombre,
       r.deshecho_el,
       r.deshecho_por,
       pd.nombre                    as deshecho_por_nombre,
       r.deshecho_motivo,
       r.reverso_id,
       rv.numero                    as reverso
  from public.jornal_repartos r
  join public.movimientos_banco m on m.id = r.movimiento_id
  left join public.perfiles pf on pf.id = r.usuario_id
  left join public.asientos a on a.id = r.asiento_id
  left join public.asientos rv on rv.id = r.reverso_id
  left join public.perfiles pc on pc.id = r.creado_por
  left join public.perfiles pd on pd.id = r.deshecho_por;
revoke all on public.v_jornal_repartos from public, anon, authenticated, service_role;
grant select on public.v_jornal_repartos to authenticated;
comment on view public.v_jornal_repartos is 'c10: el historial de repartos (aplicados y deshechos): el pago (movimiento, fecha, cuenta del banco, descripción), la persona, el período y su regla, el monto, las horas, la tarifa que salió y la de costos_equipo, las cuentas, el nº de obras y las líneas (con su obra, su CO y el orden de su línea en el asiento), el asiento y si sigue vivo, los avisos y las opciones con que se aplicó, cuántos reportes aprobó, quién y cuándo; y, deshecho, quién, cuándo, por qué y su reverso.';

-- LAS PERSONAS: las dadas de alta (con su patrón, su cuenta, su tarifa,
-- cuántos pagos suyos esperan y cuántos se repartieron) y, sin dar de alta
-- (registrada = false), los perfiles activos que no son el dueño y tienen
-- horas en los últimos 90 días: a quién ofrece dar de alta la pantalla.
create view public.v_jornal_personas with (security_invoker = true) as
select p.id                                         as usuario_id,
       p.nombre,
       p.rol,
       coalesce(p.activo, true)                     as perfil_activo,
       jp.usuario_id is not null                    as registrada,
       coalesce(jp.activa, false)                   as activa,
       jp.patron,
       jp.cuenta                                    as cuenta_propia,
       case when jp.usuario_id is not null
            then coalesce(jp.cuenta, (select c.cuenta_defecto from public.jornal_config c where c.id = 1)) end as cuenta,
       ce.costo_hora                                as tarifa,
       jp.nota,
       jp.creado_el,
       jp.actualizado_el,
       coalesce(pe.n, 0)                            as pagos_pendientes,
       coalesce(pe.monto, 0)::numeric(14,2)         as pagos_pendientes_monto,
       coalesce(rp.n, 0)                            as repartos,
       coalesce(rp.monto, 0)::numeric(14,2)         as repartido,
       rp.ultimo                                    as ultimo_reparto,
       coalesce(hh.horas_90, 0)                     as horas_90_dias,
       coalesce(hh.sin_pago, 0)                     as horas_sin_pago,
       -- (v3, al final: una columna más) las de los últimos 90 días que pagó una
       -- nómina: quien las tiene ya cobra por nómina, no por Zelle
       coalesce(hh.nomina_90, 0)                    as horas_nomina_90_dias
  from public.perfiles p
  left join public.jornal_personas jp on jp.usuario_id = p.id
  left join public.costos_equipo ce on ce.usuario_id = p.id
  left join lateral (select count(*)::int as n, sum(-mm.monto) as monto
                       from public.movimientos_banco mm
                      where jp.activa and mm.estado = 'pendiente' and mm.monto < 0
                        and public.fn_jornal_texto(mm.desc_norm, mm.memo) ~* jp.patron) pe on true
  left join lateral (select count(*)::int as n, sum(r.monto) as monto, max(r.creado_el) as ultimo
                       from public.jornal_repartos r
                      where r.usuario_id = p.id and r.estado = 'aplicado') rp on true
  left join lateral (select sum(h.horas) filter (where h.fecha >= (select public.fn_fecha_miami(now()) - 90)) as horas_90,
                            -- (v3: sin pago es sin ninguno: ni un reparto aplicado ni una nómina que las pagara)
                            sum(h.horas) filter (where h.fecha >= (select public.fn_margen_libro_desde())
                                                   and not exists (select 1 from public.jornal_reparto_horas rh
                                                                     join public.jornal_repartos r on r.id = rh.reparto_id
                                                                    where rh.horas_id = h.id and r.estado = 'aplicado')
                                                   and h.id not in (select n.horas_id from public.fn_margen_horas_nomina() n)) as sin_pago,
                            sum(h.horas) filter (where h.fecha >= (select public.fn_fecha_miami(now()) - 90)
                                                   and h.id in (select n.horas_id from public.fn_margen_horas_nomina() n)) as nomina_90
                       from public.horas h
                      where h.usuario_id = p.id and h.horas > 0) hh on true
 where p.rol <> 'dueno'
   and (jp.usuario_id is not null or (coalesce(p.activo, true) and coalesce(hh.horas_90, 0) > 0))
   and (select public.fn_jornal_ve());
revoke all on public.v_jornal_personas from public, anon, authenticated, service_role;
grant select on public.v_jornal_personas to authenticated;
comment on view public.v_jornal_personas is 'c10: las personas del jornal: las dadas de alta (registrada: su patrón, su cuenta, si está activa, su tarifa de costos_equipo, cuántos pagos suyos esperan en la Bandeja y por cuánto, cuántos repartos y cuánto repartido, el último) y, con registrada = false, los perfiles activos que no son el dueño con horas en los últimos 90 días (a quién falta dar de alta); horas_sin_pago: sus horas desde que empieza el libro sin pago real (ni un pago repartido por horas ni una nómina que las pagara); horas_nomina_90_dias: las de los últimos 90 días que pagó una nómina (quien las tiene ya cobra por nómina: no hace falta darlo de alta aquí).';

-- EL CONTROL DEL JORNAL (orden, cuadre, nivel, ok, detalle, en llano). Un
-- «cuadre» en rojo es algo roto que hay que arreglar; un «aviso», algo que
-- mirar.
create view public.v_jornal_control with (security_invoker = true) as
with rep as (
       select r.id, r.estado, r.movimiento_id, r.usuario_id, r.desde, r.hasta, r.monto, r.asiento_id, r.opciones, r.creado_el,
              a.numero as asiento, pf.nombre as persona, m.fecha as fecha_pago, m.estado as mov_estado, m.asiento_id as mov_asiento,
              exists (select 1 from public.asientos x where x.reversa_a = r.asiento_id and x.camino = 'reverso') as reversado
         from public.jornal_repartos r
         left join public.asientos a on a.id = r.asiento_id
         left join public.perfiles pf on pf.id = r.usuario_id
         left join public.movimientos_banco m on m.id = r.movimiento_id),
     viv as (select * from rep where estado = 'aplicado'),
     c10 as (
       select 'f' as k, p.oid, p.proname::text as nombre, p.prosecdef
         from pg_catalog.pg_proc p
        where p.pronamespace = 'public'::regnamespace
          and p.proname in ('fn_jornal_exigir_dueno', 'fn_jornal_ve', 'fn_jornal_precondiciones', 'fn_jornal_guarda', 'fn_jornal_usd',
                            'fn_jornal_h', 'fn_jornal_dia', 'fn_jornal_rango', 'fn_jornal_mes', 'fn_jornal_texto', 'fn_jornal_limpio',
                            'fn_jornal_patron_mal', 'fn_jornal_destinatario', 'fn_jornal_patron_sugerido', 'fn_jornal_cuenta_mal',
                            'fn_jornal_periodo', 'fn_jornal_regla', 'fn_jornal_repartir_ids', 'fn_jornal_repartir', 'fn_jornal_tardias',
                            'fn_jornal_fuera', 'fn_jornal_ia', 'fn_jornal_opciones', 'fn_jornal_calcular',
                            'fn_jornal_propuesta', 'fn_jornal_aplicar', 'fn_jornal_deshacer', 'fn_jornal_config', 'fn_jornal_persona',
                            'fn_jornal_pegado', 'fn_margen_libro_desde', 'fn_margen_horas_nomina', 'fn_margen_lineas', 'fn_margen_horas',
                            'fn_margen_estimado', 'fn_margen_obras', 'fn_margen_bajar', 'fn_margen_obra', 'fn_margen_control'))
select z.orden, z.cuadre, z.nivel, z.ok, z.detalle
  from (
    -- 10: cada reparto aplicado (con su asiento vivo) ES las líneas de su asiento
    select 10 as orden, 'jornal: cada reparto aplicado = las líneas de su asiento'::text as cuadre, 'cuadre'::text as nivel,
           t.n = 0 as ok,
           case when t.n = 0
                then format('%s reparto(s) aplicado(s): cada parte está en su asiento con su cuenta, su obra, su CO, su monto y su persona, '
                            'todas suman el pago, y su detalle por reporte de horas suma cada parte.', t.total)
                else left(t.d, 1500) || ' → no toques el libro: mira ese reparto y su asiento (en Repartos), y avisa.' end as detalle
      from (select count(*) filter (where y.mal is not null) as n, count(*) as total,
                   string_agg(format('el reparto del pago del %s a %s (%s, asiento %s): %s', y.fecha_pago, y.persona, y.monto, y.asiento, y.mal),
                              '; ') filter (where y.mal is not null) as d
              from (select v.*,
                           concat_ws(', ',
                             (select string_agg(format('la parte %s (%s) no es la línea %s de su asiento', l.n, l.monto, l.orden), ', ' order by l.n)
                                from public.jornal_reparto_lineas l
                                left join public.asiento_lineas al on al.asiento_id = v.asiento_id and al.orden = l.orden
                               where l.reparto_id = v.id and l.orden is not null
                                 and (al.asiento_id is null or al.cuenta <> l.cuenta or al.monto <> l.monto
                                      or al.proyecto_id is distinct from l.proyecto_id or al.co is distinct from l.co
                                      or al.tercero_tipo is distinct from 'empleado' or al.tercero_id is distinct from v.usuario_id::text)),
                             case when (select coalesce(sum(l.monto), 0) from public.jornal_reparto_lineas l where l.reparto_id = v.id) <> v.monto
                                  then 'sus partes no suman el pago' end,
                             case when exists (select 1
                                                 from public.jornal_reparto_lineas l
                                                 left join lateral (select coalesce(sum(rh.monto), 0) as m, coalesce(sum(rh.horas), 0) as h
                                                                      from public.jornal_reparto_horas rh
                                                                     where rh.reparto_id = l.reparto_id and rh.n = l.n) d on true
                                                where l.reparto_id = v.id and (d.m <> l.monto or d.h <> l.horas))
                                  then 'su detalle por reporte de horas no suma sus partes' end,
                             case when (select count(*) from public.asiento_lineas al where al.asiento_id = v.asiento_id)
                                       <> (select count(*) from public.jornal_reparto_lineas l where l.reparto_id = v.id and l.orden is not null) + 1
                                  then 'su asiento trae otras líneas' end,
                             case when (select -al.monto from public.asiento_lineas al where al.asiento_id = v.asiento_id and al.orden = 1)
                                       is distinct from v.monto
                                  then 'la línea del banco no es el pago' end) as mal0
                      from viv v where not v.reversado) y0
              cross join lateral (select y0.*, nullif(y0.mal0, '') as mal) y) t
    union all
    -- 20: ningún reparto aplicado cuyo asiento se reversó por fuera, o cuyo movimiento ya no está casado con él
    select 20, 'jornal: ningún reparto aplicado con su asiento reversado o su pago suelto', 'cuadre', t.n = 0,
           case when t.n = 0 then 'Cada reparto aplicado tiene su asiento vivo y su pago casado con él.'
                else left(t.d, 1500) || ' → toca «Deshacer» en ese reparto (en Repartos), con su motivo, y, si toca, vuelve a repartir '
                     'el pago.' end
      from (select count(*) as n,
                   string_agg(format('el reparto del pago del %s a %s (%s): %s', v.fecha_pago, v.persona, v.monto,
                                     case when v.reversado then format('su asiento %s se reversó por fuera (des-casado en la Bandeja)', v.asiento)
                                          when v.asiento is null then 'su asiento no existe'
                                          else format('su pago ya no está casado con su asiento %s (está %s)', v.asiento, coalesce(v.mov_estado, '?')) end),
                              '; ') as d
              from viv v
             where v.reversado or v.asiento is null or v.mov_estado is distinct from 'casado' or v.mov_asiento is distinct from v.asiento_id) t
    union all
    -- 25: ningún reparto deshecho con su asiento todavía vivo y casado
    select 25, 'jornal: ningún reparto deshecho con su asiento todavía vivo', 'cuadre', t.n = 0,
           case when t.n = 0 then 'Cada reparto deshecho tiene su asiento reversado.'
                else left(t.d, 1500) || ' → su asiento sigue en el libro: des-casa su pago en la Bandeja (con su motivo), o avisa.' end
      from (select count(*) as n, string_agg(format('el reparto del pago del %s a %s (%s, asiento %s)', v.fecha_pago, v.persona, v.monto, v.asiento), '; ') as d
              from rep v where v.estado = 'deshecho' and not v.reversado) t
    union all
    -- 30: las horas de cada reparto aplicado siguen como se repartieron (y aprobadas)
    select 30, 'jornal: las horas de cada reparto aplicado siguen como se repartieron', 'cuadre', t.n = 0,
           case when t.n = 0 then format('%s reporte(s) de horas en repartos aplicados: siguen con su obra, su CO, su fase y sus horas, y aprobados.', t.total)
                else left(t.d, 1500) || ' → el pago se repartió con otras horas: deshaz ese reparto (con su motivo) y vuelve a repartirlo '
                     'con las de hoy.' end
      from (select count(*) filter (where y.mal is not null) as n, count(*) as total,
                   string_agg(format('%s, pago del %s: el reporte %s del %s %s', y.persona, y.fecha_pago, y.horas_id, y.fecha, y.mal), '; ')
                     filter (where y.mal is not null) as d
              from (select v.persona, v.fecha_pago, rh.horas_id, rh.fecha,
                           case when h.id is null then 'se borró'
                                when h.usuario_id is distinct from v.usuario_id then 'cambió de persona'
                                when h.fecha <> rh.fecha then format('cambió de fecha (ahora %s)', h.fecha)
                                when h.proyecto_id is distinct from rh.proyecto_id then 'cambió de obra'
                                -- (el CO y la fase, limpios como al repartir: la misma regla que c6)
                                when (case when h.proyecto_id is null then null else public.fn_jornal_limpio(h.co) end) is distinct from rh.co then 'cambió de CO'
                                when public.fn_jornal_limpio(h.fase) is distinct from rh.fase then 'cambió de fase'
                                when h.horas <> rh.horas then format('cambió de horas (de %s a %s)', public.fn_jornal_h(rh.horas), public.fn_jornal_h(h.horas))
                                when h.aprobado_el is null then 'ya no está aprobado'
                           end as mal
                      from viv v
                      join public.jornal_reparto_horas rh on rh.reparto_id = v.id
                      left join public.horas h on h.id = rh.horas_id) y) t
    union all
    -- 35 (un aviso): ninguna hora de una semana ya repartida se quedó fuera de su reparto. El 30 mira las horas que SÍ entraron;
    --     las que llegan después a esa semana (se reportaron tarde, o se les cambió la fecha) no las ve nadie: el pago sigue
    --     repartido entre las demás obras y estas salen a estándar. Es un aviso y no un cuadre: Edgar puede pagarlas con el
    --     Zelle siguiente (y entonces eran, de verdad, horas sin pago), y hasta que lo haga no hay nada roto en el libro.
    select 35, 'jornal: ninguna hora de una semana ya repartida se quedó fuera de su reparto', 'aviso', t.n = 0,
           case when t.n = 0 then 'Ninguna persona tiene horas, dentro de las fechas de un reparto suyo aplicado, fuera de sus repartos.'
                else left(t.d, 1500) || ' → se reportaron o se movieron después de repartir esa semana: no recibieron nada de ese pago, que '
                     'sigue repartido entre las demás obras, y en su obra salen a estándar. Toca «Deshacer» en ese reparto y vuelve a '
                     'repartirlo con las horas de hoy; o, si las paga otro pago, repártelas con él eligiendo sus fechas a mano.' end
      from (select count(*) as n,
                   string_agg(format('%s: %s h en %s reporte(s) (%s) dentro del reparto del pago del %s', coalesce(y.persona, '?'),
                                     public.fn_jornal_h(y.h), y.n, y.dias, y.fecha_pago), '; ' order by y.fecha_pago, y.persona) as d
              from (select x.persona, x.reparto_id, x.fecha_pago, count(*) as n, sum(x.horas) as h,
                           string_agg(distinct public.fn_jornal_dia(x.fecha) || coalesce(' en ' || x.obra, ' sin obra'), ', ') as dias
                      from public.fn_jornal_tardias(null) x
                     group by x.persona, x.reparto_id, x.fecha_pago) y) t
    union all
    -- 40: ninguna hora en dos repartos vivos sin que Edgar lo aceptara
    select 40, 'jornal: ninguna hora en dos repartos vivos sin que Edgar lo aceptara', 'cuadre', t.n = 0,
           case when t.n = 0
                then case when t.aceptadas > 0
                          then format('%s reporte(s) de horas están en dos repartos porque Edgar lo pidió (otro pago de las mismas horas).', t.aceptadas)
                          else 'Ninguna hora está en dos repartos vivos.' end
                else left(t.d, 1500) || ' → una semana pagada dos veces sin decirlo: deshaz el reparto que sobre (con su motivo).' end
      from (select count(*) filter (where not y.aceptada) as n, count(*) filter (where y.aceptada) as aceptadas,
                   string_agg(format('el reporte %s del %s de %s (en %s repartos)', y.horas_id, y.fecha, y.persona, y.veces), '; ')
                     filter (where not y.aceptada) as d
              from (select rh.horas_id, min(rh.fecha) as fecha, min(v.persona) as persona, count(*) as veces,
                           -- (aceptada: todos los repartos menos el primero se aplicaron pidiendo las cubiertas)
                           count(*) filter (where coalesce((v.opciones->>'incluir_cubiertas')::boolean, false)) >= count(*) - 1 as aceptada
                      from viv v
                      join public.jornal_reparto_horas rh on rh.reparto_id = v.id
                     where not v.reversado
                     group by rh.horas_id
                    having count(*) > 1) y) t
    union all
    -- 50: ninguna hora a la vez en un devengo estándar vivo (fn_horas_devengar, c3) y en un jornal que entró al libro DENTRO del
    --     mes de ese devengo (o antes). El devengo pone a fin de mes lo trabajado y todavía no pagado, y se deshace solo el día 1
    --     del mes siguiente: el jornal que entra después (el Zelle del lunes) no choca con él —ese mes lleva el devengo, y el
    --     siguiente su reverso y el pago real: nada dos veces—. Antes se comparaba el mes de las HORAS con el del devengo y se
    --     daba por vivo un devengo ya deshecho: el uso de manual del devengo (octubre devengado, y su Zelle el 2-nov) salía en
    --     rojo sin vuelta. Lo que ya no tiene arreglo —un mes cerrado— se dice en el detalle y no deja el cuadre en rojo: el
    --     mes siguiente lo compensa con el reverso del devengo.
    select 50, 'jornal: ninguna hora a la vez en el devengo estándar de un mes y en un jornal pagado ese mes', 'cuadre', t.n = 0,
           case when t.n = 0
                then 'Ninguna hora está a la vez en el devengo estándar de un mes abierto y en un jornal que entró al libro ese mes.'
                     || coalesce(' (Ya cerrado, sin arreglo: ' || t.cerrados || ': ese mes quedó con esa mano de obra dos veces y el '
                                 'siguiente con ella de menos, por el reverso del devengo.)', '')
                else left(t.d, 1500) || ' → esa mano de obra sale dos veces en ese mes (el devengo en 5000 y el pago real) y de menos en el '
                     'siguiente, cuando el devengo se deshace solo. El devengo estándar es solo para lo trabajado y todavía no pagado: hay '
                     'que retirarlo de ese mes antes de cerrarlo (avisa).' end
      from (select count(*) filter (where y.abierto) as n,
                   string_agg(y.que, '; ' order by y.mes) filter (where y.abierto) as d,
                   string_agg(y.que, '; ' order by y.mes) filter (where not y.abierto) as cerrados
              from (select dv.mes, dv.abierto,
                           format('%s: el devengo %s cuenta %s h (%s reporte(s)) que ya tienen su pago real en ese mes, en %s jornal(es)',
                                  dv.mes, dv.numero, public.fn_jornal_h(sum(x.horas)), count(distinct x.horas_id),
                                  count(distinct x.reparto_id)) as que
                      from (select a.id, a.origen_id as mes, a.numero, a.procedencia,
                                   coalesce((select p.hasta from public.periodos p where p.periodo = a.origen_id), a.fecha_contable) as fin,
                                   coalesce((select to_jsonb(p)->>'estado' from public.periodos p where p.periodo = a.origen_id), 'abierto')
                                     = 'abierto' as abierto
                              from public.asientos a
                             where a.origen_tabla = 'horas_devengo' and a.camino not in ('reverso', 'reverso_automatico')
                               and not exists (select 1 from public.asientos x where x.reversa_a = a.id and x.camino = 'reverso')) dv
                      cross join lateral (select rh.horas_id, rh.horas, v.id as reparto_id
                                            from jsonb_array_elements(case when jsonb_typeof(dv.procedencia->'documento'->'horas') = 'array'
                                                                           then dv.procedencia->'documento'->'horas' else '[]'::jsonb end) d
                                            join public.jornal_reparto_horas rh
                                              on rh.horas_id = (case when d->>'horas_id' ~ '^-?[0-9]{1,18}$' then (d->>'horas_id')::bigint end)
                                            join viv v on v.id = rh.reparto_id and not v.reversado
                                            join public.asientos ja on ja.id = v.asiento_id
                                           where ja.fecha_contable <= dv.fin) x
                     group by dv.mes, dv.numero, dv.abierto) y) t
    union all
    -- 60: cada persona activa se reconoce sin dudas y va a una cuenta que sirve; la configuración también
    select 60, 'jornal: cada persona dada de alta se reconoce sin dudas y va a una cuenta que sirve', 'aviso', t.n = 0,
           case when t.n = 0 then format('%s persona(s) activa(s): patrones válidos, ningún pago casa con dos, y sus cuentas sirven.', t.total)
                else left(t.d, 1500) || ' → corrígelo en las personas del jornal (su patrón o su cuenta) o en los ajustes del jornal.' end
      from (select (select count(*) from public.jornal_personas jp where jp.activa) as total, count(*) as n, string_agg(y.que, '; ') as d
              from (select format('%s: %s', coalesce(pf.nombre, jp.usuario_id::text), public.fn_jornal_patron_mal(jp.patron)) as que
                      from public.jornal_personas jp left join public.perfiles pf on pf.id = jp.usuario_id
                     where jp.activa and public.fn_jornal_patron_mal(jp.patron) is not null
                    union all
                    select format('%s: %s', coalesce(pf.nombre, jp.usuario_id::text), public.fn_jornal_cuenta_mal(jp.cuenta, 'obra'))
                      from public.jornal_personas jp left join public.perfiles pf on pf.id = jp.usuario_id
                     where jp.activa and jp.cuenta is not null and public.fn_jornal_cuenta_mal(jp.cuenta, 'obra') is not null
                    union all
                    select 'la cuenta del jornal: ' || public.fn_jornal_cuenta_mal(c.cuenta_defecto, 'obra')
                      from public.jornal_config c where c.id = 1 and public.fn_jornal_cuenta_mal(c.cuenta_defecto, 'obra') is not null
                    union all
                    select 'la cuenta de lo sin obra: ' || public.fn_jornal_cuenta_mal(c.cuenta_sin_obra, 'sin_obra')
                      from public.jornal_config c
                     where c.id = 1 and c.cuenta_sin_obra is not null and public.fn_jornal_cuenta_mal(c.cuenta_sin_obra, 'sin_obra') is not null
                    union all
                    select format('el pago del %s por %s («%s») casa con %s personas', mm.fecha, -mm.monto, left(coalesce(mm.descripcion, ''), 60), k.n)
                      from public.movimientos_banco mm
                      cross join lateral (select count(*) as n from public.jornal_personas jp
                                           where jp.activa and public.fn_jornal_patron_mal(jp.patron) is null
                                             and public.fn_jornal_texto(mm.desc_norm, mm.memo) ~* jp.patron) k
                     where mm.estado = 'pendiente' and mm.monto < 0 and k.n > 1) y) t
    union all
    -- 70 (un aviso): ningún pago de una persona dada de alta resuelto en la Bandeja por OTRO camino (clasificado a mano, o
    --     aprobada la propuesta de la IA) mientras tiene horas sin pago en esas semanas (fn_jornal_fuera). Si era su pago por
    --     horas, su costo está entero donde se clasificó —sin su nombre: el 1099 por tercero no lo suma— y esas horas salen,
    --     además, a estándar: la semana cuenta dos veces en el costo con estándar. Un aviso: puede ser otra cosa de verdad (un
    --     reembolso), y entonces se va solo cuando esas horas tengan su pago.
    select 70, 'jornal: ningún pago de una persona dada de alta resuelto fuera del jornal', 'aviso', t.n = 0,
           case when t.n = 0
                then 'Ningún pago ya resuelto en la Bandeja por otro camino es de una persona del jornal con horas sin pago en esas semanas.'
                else left(t.d, 1500) || ' → si era su pago por horas, su costo quedó entero donde se clasificó (y sin su nombre: no suma '
                     'para su 1099), y sus horas de esas semanas salen además a estándar. Des-cásalo en la Bandeja, con su motivo, y '
                     'repártelo por sus horas. Si de verdad era otra cosa (un reembolso), déjalo: este aviso se va cuando esas horas '
                     'tengan su pago.' end
      from (select count(*) as n,
                   string_agg(format('el pago del %s a %s por %s (%s%s): %s h suyas sin pago del %s al %s', y.fecha, coalesce(y.persona, '?'),
                                     public.fn_jornal_usd(y.monto), coalesce(y.resuelto_como, 'casado'),
                                     coalesce(', asiento ' || y.asiento, ''), public.fn_jornal_h(y.h), y.desde, y.hasta),
                              '; ' order by y.fecha, y.movimiento_id) as d
              from (select f.movimiento_id, f.fecha, f.monto, f.persona, f.resuelto_como, f.asiento, f.desde, f.hasta, sum(f.horas) as h
                      from public.fn_jornal_fuera() f
                     group by f.movimiento_id, f.fecha, f.monto, f.persona, f.resuelto_como, f.asiento, f.desde, f.hasta) y) t
    union all
    -- 80 (un aviso): ninguna propuesta de la IA (c8) abierta en un pago ya repartido (fn_jornal_ia): la pendiente, que ya no se
    --     puede aprobar (el movimiento está casado) y enciende la alarma 71 de c8 a los 7 días y su cuadre 64 el día que la obra
    --     que proponía se termina; y la aprobada o editada cuyo asiento se reversó (Edgar la aceptó y después des-casó el pago
    --     para repartirlo), que deja su cuadre 60 en rojo. El cierre de c9 toma los cuadres de c8 por «detiene». c10 no las
    --     puede cerrar (c8 es de su función de borde): las enseña, con qué hacer.
    select 80, 'jornal: ninguna propuesta de la IA abierta en un pago ya repartido', 'aviso', t.n = 0,
           case when t.n = 0 then 'Ningún pago repartido tiene una propuesta de la IA pendiente, ni una aprobada cuyo asiento ya no vive.'
                else left(t.d, 1500) || ' → ya no se pueden aprobar (ese pago está repartido) y la IA contable las sigue contando como '
                     'abiertas: pueden frenar el cierre del mes. Hay que cerrarlas: a la pendiente se le dice «No es eso»; la aprobada '
                     'cuyo asiento se reversó se cierra con su motivo. Si la Bandeja no lo hizo al repartir, vuelve a abrirla; si siguen '
                     'aquí, avisa.' end
      from (select count(*) as n,
                   string_agg(format('el pago del %s a %s (%s): su propuesta de la IA %s%s', v.fecha_pago, coalesce(v.persona, '?'),
                                     public.fn_jornal_usd(v.monto),
                                     case i.clase when 'pendiente' then 'sigue pendiente'
                                          else format('está %s y su asiento %s ya no vive', i.estado, coalesce(i.asiento, '(no tiene)')) end,
                                     coalesce(' (proponía ' || i.resumen || ')', '')), '; ' order by v.fecha_pago, i.propuesta_id) as d
              from public.fn_jornal_ia(null) i
              join viv v on v.movimiento_id = i.movimiento_id) t
    union all
    -- 90: las protecciones de la capa (como el 63 de c8, por nombre exacto)
    select 90, 'jornal: protecciones de la capa', 'cuadre', t.n = 0,
           case when t.n = 0 then 'Ninguna función de c10 es SECURITY DEFINER ni la ejecutan anon o service_role; las tablas con RLS y su guarda; las vistas security_invoker.'
                else left(t.d, 1500) || ' → vuelve a pegar c10-costo-obra.sql (lo pone como debe).' end
      from (select count(*) as n, string_agg(y.que, '; ') as d
              from (select c10.nombre || ' es SECURITY DEFINER' as que from c10 where c10.prosecdef
                    union all
                    select format('%s la puede ejecutar %s', c10.nombre, g.r)
                      from c10 cross join (values ('anon'), ('service_role')) g(r)
                     where has_function_privilege(g.r, c10.oid, 'execute')
                    union all
                    select c10.nombre || ' la puede ejecutar authenticated'
                      from c10
                     where c10.nombre in ('fn_jornal_precondiciones', 'fn_jornal_guarda', 'fn_jornal_pegado')
                       and has_function_privilege('authenticated', c10.oid, 'execute')
                    union all
                    select c.relname || case when not c.relrowsecurity then ' sin RLS' else ' sin su policy de lectura del dueño' end
                      from pg_catalog.pg_class c
                     where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                       and c.relname in ('jornal_config', 'jornal_personas', 'jornal_repartos', 'jornal_reparto_lineas', 'jornal_reparto_horas')
                       and (not c.relrowsecurity
                            or not exists (select 1 from pg_catalog.pg_policy pl
                                            where pl.polrelid = c.oid and pl.polname = c.relname || '_dueno' and pl.polcmd = 'r'))
                    union all
                    select format('%s puede %s en %s', g.r, q.q, c.relname)
                      from pg_catalog.pg_class c
                      cross join (values ('anon'), ('service_role')) g(r)
                      cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) q(q)
                     where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v')
                       and c.relname in ('jornal_config', 'jornal_personas', 'jornal_repartos', 'jornal_reparto_lineas', 'jornal_reparto_horas',
                                         'v_jornal_pendientes', 'v_jornal_repartos', 'v_jornal_personas', 'v_jornal_control', 'v_margen_obra',
                                         'v_margen_control')
                       and has_table_privilege(g.r, c.oid, q.q)
                    union all
                    select format('authenticated puede %s en %s', q.q, c.relname)
                      from pg_catalog.pg_class c
                      cross join (values ('DELETE'), ('TRUNCATE')) q(q)
                     where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                       and c.relname in ('jornal_config', 'jornal_personas', 'jornal_repartos', 'jornal_reparto_lineas', 'jornal_reparto_horas')
                       and has_table_privilege('authenticated', c.oid, q.q)
                    union all
                    select c.relname || ' sin security_invoker'
                      from pg_catalog.pg_class c
                     where c.relnamespace = 'public'::regnamespace and c.relkind = 'v'
                       and c.relname in ('v_jornal_pendientes', 'v_jornal_repartos', 'v_jornal_personas', 'v_jornal_control', 'v_margen_obra',
                                         'v_margen_control')
                       and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o
                                          where o.option_name = 'security_invoker'), false)
                    union all
                    select format('la guarda %s de %s %s', x.tg, x.t,
                                  case when tg.oid is null then 'no está' when tg.tgenabled not in ('O', 'A') then 'está apagada'
                                       else 'tiene otra función' end)
                      from (select t.t, 'trg_' || t.t || s.s as tg
                              from (values ('jornal_config'), ('jornal_personas'), ('jornal_repartos'), ('jornal_reparto_lineas'),
                                           ('jornal_reparto_horas')) t(t)
                              cross join (values ('_guarda'), ('_sin_truncate')) s(s)) x
                      left join pg_catalog.pg_trigger tg on tg.tgrelid = to_regclass('public.' || x.t) and tg.tgname = x.tg
                     where tg.oid is null or tg.tgenabled not in ('O', 'A')
                        or tg.tgfoid is distinct from to_regprocedure('public.fn_jornal_guarda()')) y) t
  ) z
 where (select public.fn_jornal_ve());
revoke all on public.v_jornal_control from public, anon, authenticated, service_role;
grant select on public.v_jornal_control to authenticated;
comment on view public.v_jornal_control is 'c10: el control del jornal (orden, cuadre, nivel, ok, detalle en llano): 10 cada reparto aplicado es las líneas de su asiento vivo, al centavo y obra por obra, y su detalle por reporte suma cada parte; 20 ningún reparto aplicado con su asiento reversado por fuera o su pago suelto; 25 ninguno deshecho con su asiento vivo; 30 las horas de cada reparto aplicado siguen como se repartieron y aprobadas; 35 (aviso) ninguna hora de una semana ya repartida se quedó fuera de su reparto; 40 ninguna hora en dos repartos vivos sin que Edgar lo aceptara; 50 ninguna hora a la vez en el devengo estándar de un mes y en un jornal pagado ese mes; 60 (aviso) las personas se reconocen sin dudas y sus cuentas sirven; 70 (aviso) ningún pago de una persona dada de alta resuelto fuera del jornal con horas suyas sin pago; 80 (aviso) ninguna propuesta de la IA abierta en un pago ya repartido; 90 las protecciones de la capa. nivel: cuadre (algo roto) o aviso.';

-- EL COSTO POR OBRA: una fila por obra (fn_margen_obras; sus columnas, allí).
create view public.v_margen_obra with (security_invoker = true) as
select o.* from public.fn_margen_obras(null) o;
revoke all on public.v_margen_obra from public, anon, authenticated, service_role;
grant select on public.v_margen_obra to authenticated;
comment on view public.v_margen_obra is 'c10: el costo por obra y el estimado contra real, desde el libro (una fila por obra): estado, libro_desde y parcial (ya andaba antes del libro; parcial_por dice qué tenía); contrato e ingreso_libro (40xx); el real: material_real (5100), mano_obra_real (mano_obra_jornales, lo pagado y repartido, + mano_obra_nomina, 50xx), subcontratos_real (el resto de 5200), equipo_real (5300), otros_costos_real y costo_real; las horas: reales, con CO, de antes del libro, con pago real, a estándar, del dueño, sin aprobar; mano_obra_estandar («estándar, no real»: horas sin pago real × costos_equipo.costo_hora × (1 + burden estándar); vacía con mano_obra_estandar_falta si falta el burden o una tarifa; nunca se postea) y costo_con_estandar; el estimado de las fuentes de la app (horas_estimadas, tarifa_estimada del escenario, mano_obra_estimada, material_presupuesto, costo_estimado); margen_real y margen_estimado con su %, diferencia (costo_estimado − costo_con_estandar), pagos_sin_repartir y avisos en llano.';

-- EL CONTROL DEL MARGEN: el real de v_margen_obra contra el mayor, contra
-- los repartos y contra «Estados» (c4, si está: se lee al vuelo, sin colgar
-- de sus vistas).
create or replace function public.fn_margen_control()
returns table (orden int, cuadre text, nivel text, ok boolean, detalle text)
language plpgsql stable
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_per text;
  v_n   bigint;
  v_d   text;
  v_o   jsonb;
  v_k   bigint;
  v_h   numeric;
  v_hh  numeric;
  v_m   bigint;
begin
  if not fn_jornal_ve() then
    return;
  end if;
  -- (las obras se calculan UNA vez, y de ahí salen todos los renglones)
  select coalesce(jsonb_agg(jsonb_build_object(
           'proyecto_id', x.proyecto_id, 'obra', x.obra, 'costo_real', x.costo_real, 'ingreso_libro', x.ingreso_libro,
           'material_real', x.material_real, 'mano_obra_real', x.mano_obra_real, 'mano_obra_jornales', x.mano_obra_jornales,
           'mano_obra_nomina', x.mano_obra_nomina, 'subcontratos_real', x.subcontratos_real, 'equipo_real', x.equipo_real,
           'otros_costos_real', x.otros_costos_real, 'horas_reales', x.horas_reales, 'horas_antes_libro', x.horas_antes_libro,
           'horas_con_pago_real', x.horas_con_pago_real, 'horas_estandar', x.horas_estandar, 'horas_dueno', x.horas_dueno)), '[]'::jsonb)
    into v_o
    from fn_margen_obras(null) x;
  -- (v3) Las horas con obra de la app (el renglón 50) y, de ellas, las que
  -- pagó una nómina (el renglón 70), en UNA pasada por las horas: desde la
  -- app cada lectura de horas paga su policy fila a fila, y otra pasada solo
  -- para el 70 era un tercio más de espera. (La lista de la nómina, como
  -- expresión con su tabla hash: ver fn_margen_horas.)
  select coalesce(sum(q.horas), 0), count(*) filter (where q.nomina), coalesce(sum(q.horas) filter (where q.nomina), 0)
    into v_hh, v_k, v_h
    from (select h.horas, h.id in (select n.horas_id from fn_margen_horas_nomina() n) as nomina
            from horas h
           where h.proyecto_id is not null and h.horas > 0 and h.horas < 100000) q;
  return query
  with o as materialized (
         select * from jsonb_to_recordset(v_o)
                  as x(proyecto_id text, obra text, costo_real numeric, ingreso_libro numeric, material_real numeric, mano_obra_real numeric,
                       mano_obra_jornales numeric, mano_obra_nomina numeric, subcontratos_real numeric, equipo_real numeric,
                       otros_costos_real numeric, horas_reales numeric, horas_antes_libro numeric, horas_con_pago_real numeric,
                       horas_estandar numeric, horas_dueno numeric)),
       my as (select coalesce(sum(o.costo_real), 0) as c, coalesce(sum(o.ingreso_libro), 0) as i, count(*) as n,
                     coalesce(sum(o.mano_obra_jornales), 0) as j, coalesce(sum(o.horas_reales), 0) as h
                from o),
       gl as (select coalesce(sum(l.monto) filter (where cu.tipo = 'costo'), 0) as c,
                     coalesce(-sum(l.monto) filter (where cu.tipo = 'ingreso'), 0) as i
                from asiento_lineas l
                join cuentas cu on cu.codigo = l.cuenta
               where l.proyecto_id is not null and cu.tipo in ('costo', 'ingreso')),
       rp as (select coalesce(sum(l.monto), 0) as j, count(distinct r.id) as n
                from jornal_repartos r
                join jornal_reparto_lineas l on l.reparto_id = r.id
               where r.estado = 'aplicado' and l.proyecto_id is not null and l.orden is not null
                 and not exists (select 1 from asientos x where x.reversa_a = r.asiento_id and x.camino = 'reverso')),
       hh as (select v_hh as h)
  select 10, 'margen: el costo real por obra sumado = el 5xxx con obra del mayor'::text, 'cuadre'::text, my.c = gl.c,
         case when my.c = gl.c then format('%s obras: su costo real suma %s, lo mismo que las cuentas de costo con obra del mayor.', my.n, fn_jornal_usd(my.c))
              else format('Las obras suman %s de costo y el mayor (cuentas de costo con obra) %s: diferencia %s. Avisa: no toques el libro.',
                          fn_jornal_usd(my.c), fn_jornal_usd(gl.c), fn_jornal_usd(my.c - gl.c)) end
    from my cross join gl
  union all
  select 20, 'margen: el ingreso por obra sumado = el 40xx con obra del mayor', 'cuadre', my.i = gl.i,
         case when my.i = gl.i then format('El ingreso por obra suma %s, lo mismo que las cuentas de ingreso con obra del mayor.', fn_jornal_usd(my.i))
              else format('Las obras suman %s de ingreso y el mayor %s: diferencia %s. Avisa.', fn_jornal_usd(my.i), fn_jornal_usd(gl.i),
                          fn_jornal_usd(my.i - gl.i)) end
    from my cross join gl
  union all
  select 30, 'margen: los conceptos de cada obra suman su costo', 'cuadre', t.n = 0,
         case when t.n = 0 then 'En cada obra, material + mano de obra + subcontratos + equipo + otros = su costo real; y jornales + nómina = su mano de obra real.'
              else format('No suman en: %s. Avisa.', left(t.d, 1200)) end
    from (select count(*) as n, string_agg(o.obra, ', ') as d
            from o
           where o.material_real + o.mano_obra_real + o.subcontratos_real + o.equipo_real + o.otros_costos_real <> o.costo_real
              or o.mano_obra_jornales + o.mano_obra_nomina <> o.mano_obra_real) t
  union all
  select 40, 'margen: la mano de obra de jornales en el libro = los repartos aplicados', 'cuadre', my.j = rp.j,
         case when my.j = rp.j then format('%s reparto(s) aplicado(s) con su asiento vivo: %s de jornales en las obras, lo mismo en el libro.', rp.n, fn_jornal_usd(rp.j))
              else format('El libro tiene %s de jornales por obra y los repartos aplicados dicen %s: diferencia %s. Mira el control del '
                          'jornal (un reparto que no es su asiento).', fn_jornal_usd(my.j), fn_jornal_usd(rp.j), fn_jornal_usd(my.j - rp.j)) end
    from my cross join rp
  union all
  select 50, 'margen: las horas de cada obra = las de la app', 'cuadre', my.h = hh.h and t.n = 0,
         case when my.h = hh.h and t.n = 0
              then format('%s h con obra en la app, las mismas en el margen; y en cada obra, antes del libro + con pago real + a estándar + '
                          'del dueño = sus horas.', fn_jornal_h(hh.h))
              else format('El margen cuenta %s h y la app tiene %s con obra; obras donde las clases no suman: %s. Avisa.', fn_jornal_h(my.h),
                          fn_jornal_h(hh.h), t.n) end
    from my cross join hh
   cross join (select count(*) as n from o
                where o.horas_antes_libro + o.horas_con_pago_real + o.horas_estandar + o.horas_dueno <> o.horas_reales) t;

  -- 60: el costo de cada obra es el que enseña «Estados» (v_costo_por_obra de
  -- c4, todo el libro: su último período). Se lee al vuelo: c10 no cuelga de
  -- las vistas de c4.
  orden := 60; cuadre := 'margen: el costo de cada obra = el de Estados (c4)'; nivel := 'cuadre';
  if to_regclass('public.v_costo_por_obra') is null then
    ok := true; detalle := 'Los estados (c4) no están en esta base: no hay con qué comparar.';
  else
  begin
    select p.periodo into v_per from periodos p order by p.hasta desc, (p.tipo = 'anio') desc limit 1;
    execute $q$
      with c4 as (select v.proyecto_id, sum(v.desde_inicio) as costo
                    from public.v_costo_por_obra v
                   where v.periodo = $1 and v.nivel = 'obra' and v.seccion = 'costo' and v.proyecto_id is not null
                   group by v.proyecto_id),
           yo as (select o.proyecto_id, o.obra, o.costo_real
                    from jsonb_to_recordset($2) as o(proyecto_id text, obra text, costo_real numeric))
      select count(*), left(string_agg(format('%s: aquí %s, en Estados %s', yo.obra, yo.costo_real, coalesce(c4.costo, 0)), '; '), 1200)
        from yo left join c4 on c4.proyecto_id = yo.proyecto_id
       where yo.costo_real <> coalesce(c4.costo, 0) $q$
      into v_n, v_d using v_per, v_o;
    ok := v_n = 0;
    -- (El total por obra es el mismo; la etiqueta no: los jornales de 2026 van
    -- a la 5200 —«contract labor», como en QuickBooks, para el 1099—, y en
    -- «Estados» salen dentro de «Subcontratos»; aquí, aparte, como mano de
    -- obra real. c4 está sellado y no sabe del jornal: se dice.)
    detalle := case when v_n = 0
                    then format('Obra por obra, el costo real de aquí es el de «Estados» (su costo por obra, todo el libro, hasta el '
                                'período %s). Los jornales van a la cuenta de subcontratos: en «Estados» salen dentro de '
                                '«Subcontratos» y aquí como mano de obra real; el total de cada obra es el mismo.', v_per)
                    else format('%s obra(s) con otro costo en Estados: %s. ¿Cambió el mapeo de una cuenta de costo en los estados? Avisa.', v_n, v_d) end;
  exception when others then
    ok := false;
    detalle := format('No se pudo comparar con «Estados» (su costo por obra): %s %s. Avisa.', sqlstate, sqlerrm);
  end;
  end if;
  return next;

  -- 70 (v3, la Fase 11b): LAS HORAS QUE PAGÓ UNA NÓMINA CUENTAN COMO PAGO
  -- REAL. La nómina (c15) se pega después de este archivo y es opcional; si
  -- está, dice con su marca sin dinero qué reportes de horas pagó cada
  -- corrida posteada, y el margen no los lleva, además, a estándar. Este
  -- renglón mira que esa lectura funcione. Si la nómina de esta base no trae
  -- la marca (es la de antes del 13-nov) o no se deja leer, las horas que
  -- pague una nómina saldrían a estándar y, con el burden estándar fijado,
  -- su mano de obra contaría dos veces. En rojo solo si YA hay una nómina en
  -- el libro (su journal vivo: lo ve quien lee el libro, sin el código); si
  -- todavía no hay ninguna, verde, y dice qué pegar antes de la primera.
  orden := 70; cuadre := 'margen: las horas que pagó una nómina cuentan como pago real'; nivel := 'cuadre';
  if to_regclass('public.nomina_corridas') is null and to_regprocedure('public.fn_nomina_horas_con_pago()') is null then
    ok := true;
    detalle := 'La nómina no está en esta base: el pago real de unas horas es el reparto de su pago por horas.';
  else
    select count(*) into v_n
      from asientos a
     where a.origen_tabla = 'nomina_corridas' and a.camino not in ('reverso', 'reverso_automatico')
       and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso');
    v_d := null;
    if to_regprocedure('public.fn_nomina_horas_con_pago()') is null then
      v_d := 'la nómina de esta base es la de antes del 13-nov-2026 y todavía no dice qué horas pagó cada una';
    else
      begin
        -- (¿la marca se deja leer, y con la forma que se espera? Lo mismo que
        -- lee fn_margen_horas_nomina, que si falla calla. Las horas con obra
        -- que pagó ya se contaron arriba —v_k, v_h—, en la pasada del 50.)
        execute 'select count(n.horas_id::bigint) + count(n.corrida_id::uuid) + count(n.dia_pago::date) '
             || 'from public.fn_nomina_horas_con_pago() n'
           into v_m;
      exception when others then
        v_d := format('no se pudo leer qué horas pagó cada nómina (la base contestó %s)', sqlstate);
      end;
    end if;
    if v_d is null then
      ok := true;
      detalle := case when v_k = 0 then 'Ninguna nómina posteada ha pagado todavía horas con obra.'
                      else format('%s h con obra, en %s reporte(s), las pagó una nómina posteada: cuentan como pago real y no van, '
                                  'además, a estándar.', fn_jornal_h(v_h), v_k) end;
    elsif v_n = 0 then
      ok := true;
      detalle := format('Todavía no hay ninguna nómina en el libro, pero %s. Antes de postear la primera, vuelve a pegar '
                        'c15-nomina.sql (el archivo de la nómina): si no, las horas que pague saldrían a estándar.', v_d);
    else
      ok := false;
      detalle := format('Hay %s nómina(s) en el libro y %s: las horas que pagaron salen a estándar en vez de con pago real y, con el '
                        'burden estándar fijado, su mano de obra cuenta dos veces en el costo con estándar. Vuelve a pegar '
                        'c15-nomina.sql (el archivo de la nómina); si sigue en rojo, avisa.', v_n, v_d);
    end if;
  end if;
  return next;
end $$;
revoke execute on function public.fn_margen_control() from public, anon, service_role;
grant  execute on function public.fn_margen_control() to authenticated;
comment on function public.fn_margen_control() is 'c10: el control del margen (lo que enseña v_margen_control): el costo y el ingreso por obra sumados = el mayor (cuentas de costo e ingreso con obra), los conceptos suman, los jornales del libro = los repartos aplicados, las horas = las de la app, el costo de cada obra = el de v_costo_por_obra de c4 (leída al vuelo), y las horas que pagó una nómina cuentan como pago real (la marca sin dinero de c15, si está, se deja leer). Solo lectura; a quien no es el dueño, nada.';

create view public.v_margen_control with (security_invoker = true) as
select c.orden, c.cuadre, c.nivel, c.ok, c.detalle from public.fn_margen_control() c;
revoke all on public.v_margen_control from public, anon, authenticated, service_role;
grant select on public.v_margen_control to authenticated;
comment on view public.v_margen_control is 'c10: el control del margen (orden, cuadre, nivel, ok, detalle): 10 el costo real de v_margen_obra sumado = el 5xxx con obra del mayor, al centavo; 20 lo mismo con el ingreso (40xx); 30 los conceptos de cada obra suman su costo; 40 los jornales del libro = los repartos aplicados; 50 las horas = las de la app; 60 el costo de cada obra = el de «Estados» (v_costo_por_obra, c4); 70 las horas que pagó una nómina cuentan como pago real (si la nómina, c15, está en la base: su marca se deja leer; en rojo si hay una nómina en el libro y no).';


-- ---------------------------------------------------------------------
-- 10. Lo que debe verse al pegar: fn_jornal_pegado().
-- ---------------------------------------------------------------------
create or replace function public.fn_jornal_pegado() returns table (que text, detalle text)
language plpgsql
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  c       jornal_config;
  v_n     int;
  v_m     numeric;
  v_p     int;
  v_txt   text;
  v_falta text[] := '{}';
  v_r     record;
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  select * into c from jornal_config where id = 1;
  return query select 'jornal_config'::text,
                      format('cuenta del jornal %s · lo sin obra %s · burden estándar %s · avisa si la tarifa que sale se aleja más de un %s %%',
                             c.cuenta_defecto, coalesce(c.cuenta_sin_obra, 'SIN FIJAR'),
                             coalesce(trim_scale(c.burden_estandar_pct)::text || ' %', 'SIN FIJAR'), trim_scale(c.aviso_tarifa_pct));
  return query select 'tablas'::text,
                      format('jornal_config, jornal_personas (%s), jornal_repartos (%s aplicados, %s deshechos), jornal_reparto_lineas (%s), '
                             'jornal_reparto_horas (%s)',
                             (select count(*) from jornal_personas),
                             (select count(*) from jornal_repartos r where r.estado = 'aplicado'),
                             (select count(*) from jornal_repartos r where r.estado = 'deshecho'),
                             (select count(*) from jornal_reparto_lineas), (select count(*) from jornal_reparto_horas));
  return query select 'vistas'::text, 'v_jornal_pendientes, v_jornal_repartos, v_jornal_personas, v_jornal_control, v_margen_obra, v_margen_control'::text;
  return query select 'personas dadas de alta'::text,
                      coalesce((select string_agg(format('%s («%s» → %s%s)', v.nombre, v.patron, v.cuenta, case when v.activa then '' else ', de baja' end),
                                                  ' · ' order by v.nombre)
                                  from v_jornal_personas v where v.registrada),
                               'ninguna todavía: sin persona dada de alta, ningún pago se reconoce solo');
  select count(*), coalesce(sum(v.monto), 0), count(*) filter (where v.puede_aplicar) into v_n, v_m, v_p from v_jornal_pendientes v;
  return query select 'pagos reconocidos hoy'::text,
                      case when v_n = 0 then 'ninguno en la Bandeja'
                           else format('%s pago(s) en la Bandeja por %s; %s se pueden repartir ya', v_n, fn_jornal_usd(v_m), v_p) end;
  -- (v3) A quien una nómina le pagó horas en los últimos 90 días no se le pide
  -- darse de alta: ya cobra por nómina, no por Zelle.
  select string_agg(v.nombre, ', ' order by v.nombre) into v_txt
    from v_jornal_personas v where not v.registrada and v.horas_nomina_90_dias = 0;
  if v_txt is not null then
    v_falta := v_falta || format('dar de alta a quien cobra por sus horas (con horas en los últimos 90 días y sin dar de alta: %s)', v_txt);
  end if;
  if c.cuenta_sin_obra is null then
    select coalesce(sum(h.horas), 0) into v_m
      from horas h join perfiles p on p.id = h.usuario_id
     where h.proyecto_id is null and p.rol <> 'dueno' and h.fecha >= fn_margen_libro_desde();
    v_falta := v_falta || format('la cuenta de la mano de obra sin obra (hay %s h sin obra desde que empieza el libro): '
                                 'select fn_jornal_config(''{"cuenta_sin_obra": "…"}'');', fn_jornal_h(v_m));
  end if;
  if c.burden_estandar_pct is null then
    v_falta := v_falta || 'el burden estándar, UNA tasa (0 si no aplica): select fn_jornal_config(''{"burden_estandar_pct": 0}'');'::text;
  end if;
  -- (v3) ¿La nómina de esta base (c15) dice ya qué horas pagó? La de antes del
  -- 13-nov no trae esa marca: con ella, las horas que pague una nómina
  -- saldrían a estándar (lo vigila el control 70 del margen).
  if to_regclass('public.nomina_corridas') is not null and to_regprocedure('public.fn_nomina_horas_con_pago()') is null then
    v_falta := v_falta || ('volver a pegar c15-nomina.sql (el archivo de la nómina): el de esta base es el de antes del 13-nov y '
                           || 'todavía no dice qué horas pagó cada nómina; sin eso, las horas que pague saldrían a estándar')::text;
  end if;
  return query select 'qué falta'::text,
                      case when cardinality(v_falta) = 0 then 'nada: todo listo' else array_to_string(v_falta, ' · ') end;
  select count(*) as obras, count(*) filter (where v.costo_real <> 0) as con_costo, count(*) filter (where v.parcial) as parciales,
         coalesce(sum(v.horas_estandar), 0) as h_est, coalesce(sum(v.horas_con_pago_real), 0) as h_real,
         coalesce(sum(v.costo_real), 0) as costo
    into v_r
    from v_margen_obra v;
  return query select 'costo por obra'::text,
                      format('%s obras · %s con costo en el libro (%s) · %s parciales (ya andaban antes del %s) · %s h con pago real y %s h a estándar',
                             v_r.obras, v_r.con_costo, fn_jornal_usd(v_r.costo), v_r.parciales, fn_jornal_dia(fn_margen_libro_desde(), true),
                             fn_jornal_h(v_r.h_real), fn_jornal_h(v_r.h_est));
  begin
    select format('jornal: %s de %s en rojo%s · margen: %s de %s en rojo%s',
                  (select count(*) from v_jornal_control k where k.ok is distinct from true), (select count(*) from v_jornal_control),
                  coalesce(' (' || (select string_agg(k.cuadre, '; ' order by k.orden) from v_jornal_control k where k.ok is distinct from true) || ')', ''),
                  (select count(*) from v_margen_control k where k.ok is distinct from true), (select count(*) from v_margen_control),
                  coalesce(' (' || (select string_agg(k.cuadre, '; ' order by k.orden) from v_margen_control k where k.ok is distinct from true) || ')', ''))
      into v_txt;
  exception when others then
    v_txt := format('el control falló: %s %s', sqlstate, sqlerrm);
  end;
  return query select 'control'::text, v_txt;
  -- (¿el cierre de esta base ya mira los repartos? El c9 del 10-nov trae las
  -- filas 170 y 171; el de antes no, y hay que volver a pegarlo.)
  return query select 'siguiente paso'::text,
                      case when to_regprocedure('public.fn_cierre_revisar(text)') is not null
                                and not exists (select 1 from pg_proc p
                                                 where p.oid = to_regprocedure('public.fn_cierre_revisar(text)')
                                                   and p.prosrc like '%v_jornal_control%')
                           then 'PRIMERO vuelve a pegar docs/conta/c9-cierre.sql: el cierre de esta base todavía no mira los repartos de '
                                'mano de obra (sus filas 170 y 171). Después, '
                           else '' end ||
                      'pega docs/conta/c10-pruebas.sql; en la app, Contabilidad → Bandeja: en el Zelle de un ayudante, «Es mano de obra: repartir '
                      'por sus horas» lo da de alta, y desde entonces sus pagos salen con su semana, sus obras y lo que le toca a cada una; '
                      '«Así es» los mete al libro (y aprueba esas horas). El costo por obra, en cada obra (estimado contra real).'::text;
end $$;
revoke execute on function public.fn_jornal_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_jornal_pegado() is 'c10: lo que enseña el final del pegado: la configuración, las tablas y las vistas, las personas dadas de alta, cuántos pagos reconoce hoy, qué falta (personas con horas sin dar de alta —no las que ya cobran por nómina—, la cuenta de lo sin obra, el burden estándar; y volver a pegar la nómina, si la de la base es la de antes del 13-nov), el costo por obra en una línea, el control y el paso siguiente.';

select * from public.fn_jornal_pegado();
