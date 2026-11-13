-- =====================================================================
-- c15-nomina.sql — LA NÓMINA: EL PUENTE CON GUSTO, POR ARCHIVO
-- (el «Payroll journal» de cada nómina entra al libro, repartido sobre las
-- obras por las horas aprobadas, con su burden real; y los cargos de Gusto
-- del banco se casan con lo que cada nómina dejó por pagar) · c15, la
-- Fase 11.
-- 13-nov-2026. Se pega en el SQL Editor DESPUÉS de c1, c2, c3, c4, c6 y c10
-- (y de c7, s1, p1, c8, c9, c11, c12, c13 y c14 si se usan: la cadena de
-- siempre). Idempotente: se puede volver a pegar entero (no pisa la
-- configuración, ni el mapeo de columnas que Edgar haya cambiado, ni una
-- persona, ni una corrida). Después se pega c15-pruebas.sql.
--
-- Qué hace. Gusto calcula la nómina, retiene, deposita y presenta el 941, el
-- 940, el RT-6 y los W-2; la app NO calcula nada de eso. Lo que la app hace
-- es llevar al libro lo que Gusto ya hizo: Edgar baja de Gusto el «Payroll
-- journal» de cada nómina (CSV) y lo sube; la base lo lee, comprueba que
-- cuadra al centavo, reparte el sueldo de cada persona entre las obras por
-- sus horas aprobadas del período de pago, y postea UN asiento por nómina
-- (el journal) más el reparto de su burden real a las obras. Después casa
-- cada cargo de Gusto en el banco con lo que esa nómina dejó por pagar, y
-- compara lo posteado con lo que Gusto declaró (941, 940, RT-6).
--
-- LO QUE ESTÁ DECIDIDO (docs/CONTA-PLAN.md y fases/f11-nomina.md; no se
-- rediscute):
--   · Gusto, plan Simple, cada dos semanas; el puente es POR ARCHIVO (Gusto
--     no da su API a una app privada de un solo cliente). Primera nómina con
--     día de pago en enero de 2027.
--   · Este journal es la ÚNICA fuente de dólares de la mano de obra directa
--     (5000, 5001) y de su burden real. Nunca una lectura de «escenarios».
--   · El día de pago («check date») es la fecha fiscal: la del asiento y la
--     de los trimestres del 941 y del RT-6.
--   · Los sueldos son lo más delicado del libro después del TIN: solo el
--     dueño, y lo de cada persona solo con el código del teléfono.
--
-- LO QUE NO ESTÁ COMPROBADO (y por eso es configurable): los RÓTULOS exactos
-- de las columnas del CSV de Gusto. El mapeo de fábrica trae los nombres de
-- las 86 columnas de su motor de informes y los rótulos que se les suponen;
-- todo va por NOMBRE (nunca por posición), se amplía desde la pantalla, y
-- una columna con cifras que el mapeo no conozca FRENA la corrida en vez de
-- perderse. Se confirma con el primer archivo real.
--
-- LAS PIEZAS:
--   (1) EL ARCHIVO (fn_nomina_ensayo, fn_nomina_importar). La pantalla lee
--       el CSV en el navegador y manda SUS CELDAS COMO TEXTO: {nombre,
--       sha256, bytes, filas: [[celda, …], …]} (cabecera y filas; nada
--       sumado ni convertido en JavaScript: el dinero se lee aquí, en
--       numeric). La base:
--       · busca la cabecera por sus nombres (lo de arriba es preámbulo), y
--         reconoce «Check date: …» y «Pay period: …» sueltos. NO SUPONE UNA
--         FORMA: todavía no hay un archivo real de Gusto. Vale con una sola
--         tabla o POR SECCIONES (cada una con su cabecera: el resumen por
--         empleado y, en otra parte, el detalle de lo patronal); las filas
--         de título y las que vienen en cero se saltan (y se dice); las
--         fechas valen como 01/22/2027, 2027-01-22 o «Jan 22, 2027», y el
--         período en dos columnas o en una celda («… - …»); la persona es su
--         identificador de Gusto si el archivo lo trae y, si no, su nombre
--         sin importar el orden («Uno, ZZ Ayudante» = «ZZ Ayudante Uno»);
--       · parte el archivo en CORRIDAS (una por día de pago, período, tipo
--         y llave de nómina de Gusto), con sus personas y sus líneas por
--         concepto. Una fila que no dice su día de pago, su período o su
--         tipo los HEREDA solo si no hay duda (el único día de pago del
--         archivo; la única nómina de ese día): si hay dos candidatas,
--         MX009 y no se adivina. Un concepto que sale en dos partes del
--         archivo (el resumen y el detalle de la misma nómina: tengan
--         cabeceras distintas o LA MISMA) cuenta UNA vez, y si las dos
--         partes no dicen lo mismo la corrida no cuadra; lo único que se
--         suma son dos filas de una persona dentro de una misma parte;
--       · trata las filas «Total» como CONTROL (se comparan, nunca se
--         suman), lleven su rótulo en la primera celda o donde iría el
--         nombre de la persona (si el archivo trae otras columnas delante);
--         y una nota o un título de una o dos celdas en medio del archivo
--         se salta, aunque caiga debajo de una columna de dinero;
--       · EL NETO Y LOS REEMBOLSOS: Gusto define neto = bruto − lo retenido
--         − las deducciones, y cheque = neto + reembolsos. Si el neto de
--         una persona ya trae su reembolso, se reconoce (cuadra así y no de
--         la otra forma), se avisa, y el reembolso no se cuenta dos veces
--         en lo que queda por pagar;
--       · LO DELICADO NO SE GUARDA NUNCA, ni en un error ni en un registro:
--         una columna de clase «delicado» (SSN, cuenta y ruta del banco,
--         fecha de nacimiento, dirección de casa, correo, teléfono) se
--         salta entera; una celda con forma de Seguro Social en una columna
--         desconocida la vuelve delicada; en una que sí se guarda, el
--         archivo no entra. Ningún mensaje repite el valor de una celda:
--         dice la fila y la columna. Y EL NAVEGADOR NO LAS MANDA: la
--         pantalla quita esas columnas antes de llamar (por su nombre, con
--         la lista «delicado» del mapeo, y cualquier celda con forma
--         ###-##-####); la base lo vuelve a hacer por si acaso. El archivo
--         mismo no se guarda en ningún sitio (ni en Storage): solo su
--         nombre, su sha256 y su tamaño;
--       · CUADRA AL CENTAVO O NO SE POSTEA: por persona, las partes contra
--         su total, bruto − lo retenido − las deducciones = neto, y neto +
--         reembolsos = cheque; y en total, la fila de totales del archivo
--         contra la suma de sus filas. Lo que no cuadra dice dónde, con las
--         dos cifras. La corrida entra igual (a la vista), sin poderse
--         postear;
--       · NO ENTRA DOS VECES (fn_nomina_ya). Una nómina es «la misma» que
--         otra viva POR SU LLAVE (la de Gusto o, sin ella, su día de pago,
--         su tipo y un período que no contradiga al de la que ya está) o
--         POR SUS PERSONAS Y SUS CIFRAS (firma_personas: cuántas son y el
--         bruto y el neto de cada una; el mismo día de pago, diga lo que
--         diga su tipo o su período, o con otro día y un período que se
--         pisa; o, si a una le falta el período —un resumen sin fechas, con
--         su día de pago dicho a mano—, con el día a menos de una semana; o
--         si es la misma nómina del mismo archivo, subido otra vez con otro
--         día): la misma nómina bajada de Gusto SIN la columna del tipo
--         entra como «regular» y con ella como «fuera de ciclo»; bajada sin
--         el desglose del bruto trae otros conceptos; con el período dicho a
--         mano puede traer otro período. Es la misma. (El margen de una
--         semana supone la nómina cada dos semanas, como hoy: dos nóminas
--         distintas con las mismas cifras caen a 13 días o más. ▶ Si algún
--         día fuera semanal, se baja. Y si un archivo sin fechas de verdad
--         vale para dos nóminas idénticas, la segunda entra con su porqué.)
--           – con las mismas cifras, concepto por concepto: «ya_estaba»;
--           – con las mismas personas y sus mismos bruto y neto, pero otras
--             columnas: «otra_distinta» con misma = sí. NO entra como «otra
--             nómina» (entraría dos veces al libro) salvo con su porqué
--             escrito ({"otra_nomina": true, "otra_porque": "…"}: dos bonos
--             iguales el mismo día);
--           – con otras cifras: «otra_distinta», y Edgar dice si REEMPLAZA
--             a la que estaba ({"reemplazar": true}: solo si aquella está
--             sin postear y es una; queda descartada, con su motivo, y la
--             nueva conserva su período dicho a mano y lo decidido para
--             cada persona) o si es OTRA nómina del mismo día
--             ({"otra_nomina": true}).
--         {"reemplazar": true} vale también con las mismas cifras: así se
--         vuelve a leer una corrida después de decirle al mapeo qué era una
--         columna. Una posteada no se reemplaza: se anula y se vuelve a
--         subir. Postear tiene el mismo freno («repetida») y el control lo
--         vigila (aviso 32).
--   (2) EL MAPEO DE COLUMNAS (nomina_columnas, fn_nomina_columna): cada
--       nombre de columna, limpio, con su clase (parte del bruto, impuesto
--       del empleado, deducción, neto, reembolso, impuesto o beneficio del
--       patrón, horas, un total de control, delicado, ignorar…), su cuenta
--       si es dinero y con qué renglón de las declaraciones amarra. Una
--       columna con cifras que no esté ahí deja la corrida SIN POSTEAR hasta
--       que Edgar diga qué es (y vuelva a subir el archivo: lo que no se
--       conocía no se guardó).
--   (3) LAS PERSONAS (nomina_personas, fn_nomina_persona): cada empleado del
--       journal se enlaza UNA vez con su perfil de la app y su CLASE:
--         campo    mano de obra directa: 5000, por obra según sus horas
--         oficial  el accionista-oficial: 5001 la parte de obra, 6005 lo demás
--         oficina  6000
--       Por defecto, la que sale del rol del perfil (dueño → oficial; campo
--       → campo); Edgar la confirma. Sin enlazar o sin confirmar, sus
--       corridas no se postean.
--   (4) EL REPARTO (fn_nomina_plan, fn_nomina_propuesta). Por persona de
--       campo: sus HORAS APROBADAS del período de pago (horas.aprobado_el),
--       agrupadas por obra y CO. LA REGLA, AL CENTAVO (el núcleo de c10,
--       fn_jornal_repartir_ids, sin rehacerlo): su bruto se reparte primero
--       entre sus GRUPOS (cada obra y CO; lo sin obra, aparte) en proporción
--       a las horas de cada uno: cada grupo recibe su parte truncada al
--       centavo, y los centavos que faltan van de uno en uno a los grupos
--       de mayor resto (en el empate, al de más horas); y después, igual,
--       entre los reportes de horas de cada grupo. La suma ES el bruto, sin
--       un centavo de más ni de menos. Lo que el patrón paga por ella
--       (impuestos y beneficios patronales), por las MISMAS horas.
--       · horas sin obra: a la cuenta de lo sin obra (la de la nómina; si no
--         dice nada, la del jornal de c10), con su aviso;
--       · alguien con sueldo y NINGUNA hora aprobada FRENA la corrida hasta
--         que Edgar elija: aprobar sus horas, o mandarlo «sin obra» con su
--         nota (fn_nomina_decidir);
--       · las horas que pagó Gusto contra las aprobadas: un aviso con las
--         dos cifras (el sueldo se reparte por las de la app);
--       · EL OFICIAL: la parte de obra de su sueldo es bruto × (sus horas
--         aprobadas en obra) ÷ (las horas que cubre su sueldo en el período,
--         80 de fábrica, o las que reportó si son más), a 5001 por obra; lo
--         demás, a 6005. ▶ La regla es de Edgar y del CPA: configurable.
--       · UNA HORA, UNA NÓMINA (nomina_reparto_horas, EL LOTE): cada reporte
--         de horas que una corrida pagó queda apuntado con lo que le tocó.
--         Una hora no se reparte dos veces (ni la que ya pagó un jornal por
--         Zelle de c10): un índice único lo impide aunque dos pestañas
--         posteen a la vez. Una corrida fuera de ciclo (un bono) usa las
--         horas de clave sin quedárselas, salvo que Edgar diga que es la
--         que las paga (fn_nomina_corrida, toma_horas).
--       · LO QUE SE DICE Y NO FRENA: horas en una obra terminada o todavía
--         sin aprobar (su parte va a esa obra: el trabajo se hizo ahí),
--         horas sin aprobar, impuestos sin su renglón de las declaraciones,
--         los reembolsos (bajan lo que se le debe a cada empleado, A SU
--         NOMBRE —por su perfil: el nombre no va escrito en el libro—; si a
--         ESE empleado no se le debe tanto, se dice antes de postear: lo que
--         se le deba a otro no cuenta), la nómina
--         que CRUZA EL AÑO (su período empieza en el año anterior al de su
--         día de pago: entra entera en el año del día de pago, y se dice si
--         diciembre quedó devengado o no) y la que deja algo A FAVOR (una
--         corrección que devuelve: importes en negativo).
--   (5) EL ASIENTO (fn_nomina_postear). Una corrida = su journal, en la
--       fecha del día de pago (con la regla del documento tardío de c3 si su
--       mes ya cerró), con origen «nomina_corridas» y su papel = la corrida:
--         Dr 5000 por obra y CO · Dr 5001 por obra · Dr 6000 / 6005 / lo sin
--            obra · Dr 6010 (lo patronal de oficina) · Dr 5015 (lo patronal
--            de la gente de obra: la bolsa del burden real) · Dr 2250 (los
--            reembolsos que Gusto paga con el neto)
--         Cr 2210 (el neto y los reembolsos) · Cr 2220 (el 941: lo retenido
--            y Social Security y Medicare del patrón) · Cr 2225 (FUTA) ·
--            Cr 2230 (el reempleo de Florida) · Cr 2240 (deducciones)
--       Una CORRECCIÓN que devuelve trae todo en negativo: el mismo asiento
--       al revés, y sus cuentas por pagar quedan A FAVOR (se guardan con su
--       signo: lo que Gusto descontará o devolverá).
--       Y UN SEGUNDO ASIENTO, el reparto del burden real (origen
--       «nomina_burden»): Dr 5010 por obra y CO / Cr 5015, por las mismas
--       horas. Van separados porque c3 no deja el burden por obra (5010) en
--       un asiento con cuentas que no sean del bloque 50xx; así c3 «mano de
--       obra» queda en verde y c10 y c12 leen en 5010 el burden REAL de
--       cada obra. Lo que Edgar VIO es lo que entra («visto», la huella de la
--       propuesta: si algo cambió entre que miró y que tocó, MX011 y nada
--       cambia). Dos toques o dos pestañas dejan un asiento.
--       · POR QUÉ UN TRIGGER CON LOS PERMISOS DEL DUEÑO DE LA BASE
--         (fn_nomina_al_libro, la única función SECURITY DEFINER de la
--         capa). c3 exige que toda línea de 5000 y 5001 venga de un asiento
--         con origen «nomina…», y c2 solo deja poner el origen del primer
--         asiento de un papel a su puente (fn_postear_interno, sin API):
--         fn_postear, la puerta del dueño, lo rechaza. La corrida entra como
--         entran los recibos de c3: por el puente de su papel, que es un
--         trigger de nomina_corridas (como el de la numeración de c11): no
--         se puede llamar suelto, no tiene EXECUTE para nadie, vuelve a
--         pedir al dueño y su código, y solo postea si el asiento ES el
--         journal guardado, cuenta por cuenta (fn_nomina_journal: MX001 si
--         una cuenta por pagar no suma lo del journal; MX004 si trae una
--         cuenta que la corrida no explica, aunque sume cero). Antes de
--         postear o reversar toma los períodos en lectura compartida, en
--         el mismo orden que c3: un cierre a la vez no se cruza.
--       · ANULAR (fn_nomina_anular): no se borra nada. Sus dos asientos se
--         reversan (por el mismo puente: fn_reversar, la puerta del dueño,
--         no reversa asientos de puente), el lote suelta sus horas y el
--         archivo se puede volver a subir. Con cargos de Gusto casados,
--         antes se des-casan.
--       · EL DEVENGO ESTÁNDAR DE c3. c3 no devenga un mes que tiene journal
--         de nómina, y no puede saber qué horas pagó cada journal (está
--         sellado). Al postear, si el mes tenía un devengo vivo, se deshace
--         aquí mismo por la función de c3 (contaría dos veces). Lo que queda
--         fuera es LA COLA: lo trabajado al final del mes que se paga el
--         mes siguiente no se devenga; su costo entra con la nómina que lo
--         paga. fn_nomina_cola(mes) dice cuánto es y el control lo avisa.
--         ▶ CPA: si al cierre del año hay que devengarla.
--   (6) EL CARGO DE GUSTO EN EL BANCO (fn_nomina_cargos, _cargo_propuesta,
--       _cargo_casar, _cargo_cuota, _cargo_deshacer). c6 deja cada cargo de
--       Gusto en la Bandeja «esperando su journal». Aquí se casa con lo que
--       su corrida dejó por pagar: Dr 2210 / 2220 / 2225 / 2230 / 2240 /
--       Cr el banco, EN LA FECHA DEL CARGO, por la puerta de clasificar de
--       c6 (el movimiento queda casado y la conciliación se confirma como
--       siempre). Gusto cobra el neto y los impuestos por separado, y un
--       cargo puede pagar dos nóminas: las partes de un cargo suman el
--       cargo AL CENTAVO y ninguna paga de más; lo que no casa así no se
--       casa, y se dice con las dos cifras. LA CUOTA MENSUAL de Gusto no es
--       nómina: sale por fn_nomina_cargo_cuota a su gasto (6500).
--       · LO QUE UNA CORRECCIÓN DEJÓ A FAVOR entra restando: el cargo de
--         impuestos que Gusto cobró ya descontado casa con «lo de la nómina
--         del día X menos lo que quedó a favor de la del día Y» (partes en
--         negativo), y una DEVOLUCIÓN de Gusto (un depósito con su nombre)
--         sale en la misma lista y se casa contra lo que quedó a favor.
--         ▶ A confirmar con Gusto cómo cobra de verdad una corrección.
--       · LO QUE GUSTO NO COBRA (el neto de quien cobró con CHEQUE DE PAPEL;
--         una deducción que se le paga a un tercero: una cuota sindical, un
--         seguro, un 401(k) por fuera) se casa por la misma puerta con el
--         cargo del banco que lo pagó, con su nota: queda «por fuera de
--         Gusto». fn_nomina_cargos_fuera() propone los que dan al centavo.
--       · UN CARGO CASADO AQUÍ Y DES-CASADO DESPUÉS EN LA BANDEJA del banco
--         deja de contar como pagado en el acto (su asiento ya está
--         reversado), sale como «descasado» y, al casarlo otra vez, el de
--         antes se apunta deshecho solo.
--   (7) EL AMARRE (nomina_declaraciones, fn_nomina_declaracion,
--       fn_nomina_amarre): Edgar teclea los totales de cada 941 (trimestre),
--       940 (año) y RT-6 (trimestre); la base los compara con lo posteado
--       POR DÍA DE PAGO. Una diferencia mayor que la tolerancia es un aviso
--       con las dos cifras.
--   (8) LAS HORAS PARA GUSTO (fn_nomina_horas_gusto, fn_nomina_lote): las
--       aprobadas de un período, por persona y semana laboral (total,
--       regulares hasta 40 y extra; el día en que empieza la semana, de la
--       configuración), en tabla y en CSV («Employee name, Regular hours,
--       Overtime hours, Total hours, Pay period start, Pay period end»,
--       fechas MM/DD/YYYY: ▶ a confirmar con la plantilla de Gusto). Si el
--       período corta una semana laboral, las horas aprobadas de esa semana
--       de ANTES del período ya gastaron su parte de las 40 (horas_antes).
--       El lote queda guardado con sus semanas como quedaron; si después
--       cambia una hora suya, o se aprueba otra del período, el control lo
--       avisa. Quien cobra sueldo fijo (el oficial, la oficina) sale en la
--       tabla y no va al lote.
--   (9) EL CONTROL (v_nomina_control) y EL CIERRE (fn_nomina_cierre): ver
--       las secciones 16 y 17. El cierre de c9 las pide con su bloque (filas
--       180 a 183); mientras c9 no lo traiga, la nómina funciona igual. Lo
--       que el cierre guarda y manda al teléfono va SIN el nombre ni las
--       cifras de nadie (el texto «corto» de cada control); el detalle
--       entero, en la página de la nómina, con el código.
--   (9b) LO QUE QUEDA EN LA BOLSA DEL BURDEN REAL (fn_nomina_bolsa,
--       fn_nomina_bolsa_repartir): la prima de WC que el banco amortiza
--       cada mes a la bolsa (5015) no es de ninguna corrida; al terminar el
--       mes se reparte a las obras (5010) por las horas que la nómina pagó
--       ese mes, por la puerta del dueño. ▶ CPA: la clave y si se reparte.
--  (10) PARA LAS OTRAS CAPAS (solo lectura): fn_nomina_horas_pagadas() (qué
--       horas pagó cada corrida: lo que c10 necesita para no llevarlas,
--       además, a estándar), fn_nomina_pagado_hasta() (el «pagado hasta» de
--       cada persona: el corte que el devengo de c3 esperaba),
--       fn_nomina_cola(mes), fn_nomina_auxiliar(fecha) (el auxiliar de 2210,
--       2220, 2225, 2230 y 2240 a una fecha, para la cédula de c13) y
--       v_nomina_papel (el papel de sus asientos, con las columnas de
--       v_papel_fases).
--
-- LO QUE ESTA CAPA NO PUEDE ARREGLAR SOLA (las capas de al lado están
-- selladas; cada cosa tiene aquí su función de lectura, lista para usar):
--   · c10 (el costo por obra) cuenta como «a estándar» las horas que ya
--     pagó una nómina (su mano de obra real sí la lee bien del libro): el
--     día que se ponga un burden estándar, su «costo con estándar» las
--     contaría de más. Lo que le falta leer: fn_nomina_horas_pagadas().
--   · c13 (la cédula de corte) enseña 2220 a 2240 como «sin auxiliar: llega
--     con la nómina», y compara 2210 con los devengos de horas (con el neto
--     de una nómina por pagar —o adelantado a Gusto— al corte dice «no
--     cuadra»): su auxiliar es fn_nomina_auxiliar(fecha), con su signo.
--   · c4 y c6 (v_asiento_papel) dicen de un asiento de la nómina «el papel
--     ya no está»: su papel es v_nomina_papel. No se puede añadir desde
--     aquí: c6 SELLA la definición de v_papel_fases y su cuadre «las
--     protecciones del banco» se pone en rojo si cambia (probado). Con una
--     nómina en el libro, la prueba 25 de c4-pruebas.sql («toda cifra baja
--     a su asiento y a su papel») falla por eso.
--   · c12 (el WIP) avisa «horas sin costo en el libro» de las horas que una
--     nómina ya pagó (lee de c10 «con pago real»).
--   · c3 no devenga un mes con nómina: la cola del mes (lo trabajado y sin
--     pagar) se dice (fn_nomina_cola, el aviso 80) y no se devenga. ▶ CPA.
--   · c14 (el 1099): quien pasa a W-2 deja de ser de 1099 desde su primera
--     nómina; se dice en su ficha de c14 (un tramo), no aquí.
--
-- LA SEGURIDAD:
--   · Solo el dueño (es_dueno) ve y toca la nómina. El equipo, 42501 y cero
--     filas; anon y service_role, ningún privilegio (ni tabla, ni vista, ni
--     función).
--   · LO QUE LLEVA DINERO DE UNA NÓMINA (cada corrida con sus totales, sus
--     descuadres y sus avisos —que nombran a su gente con sus cifras—; lo
--     de cada persona: lo que cobra, sus líneas, su reparto, su lote; y los
--     cargos casados con sus partes) se LEE solo con el código del teléfono
--     (aal2): una nómina de una sola persona ES lo que cobró esa persona. Y
--     TODO lo que escribe la nómina lo pide también, tenga o no factor la
--     cuenta: sin él, 403 con el código «MFA», como la guarda de s1. Sin el
--     código, el control y el cierre dicen «entra con él» en lo que mira
--     dinero y no lo dan por bueno. Las vistas no traen lo de cada persona:
--     sale de fn_nomina_propuesta.
--   · EL LIBRO ES EL LIBRO: los asientos de la nómina los lee quien lee el
--     libro (c2 y s1 dicen quién). Van por cuenta y obra, sin el nombre de
--     nadie (el reembolso va a nombre del empleado por su perfil, no
--     escrito); pero el sueldo del único oficial es su cuenta, y una nómina
--     de una sola persona es lo que cobró: eso no se puede esconder del
--     libro.
--   · Lo que el cierre guarda y lo que sale al teléfono no lleva el nombre
--     ni las cifras de ninguna persona.
--   · Las tablas se escriben solo por las funciones de aquí (la guarda, con
--     su marca de transacción): a mano, MX003, aunque sea el dueño. Una
--     corrida solo avanza: importada → posteada → anulada, o descartada.
--   · Ninguna función es SECURITY DEFINER salvo el trigger del puente.
--
-- LOS ERRORES (en llano; ninguno repite una celda del archivo):
--   MX000  falta algo para pegar (no se tocó nada)
--   MX001  no cuadra: el asiento no es el journal guardado; las partes de
--          un cargo no suman el cargo
--   MX003  inmutable: una tabla de la nómina a mano; un rastro
--   MX004  cuenta: no sirve para ese uso
--   MX005  una celda que debía ser un importe, unas horas o una fecha no lo
--          es, o trae más de dos decimales (no se adivina ni se redondea)
--   MX008  estado: la corrida tiene frenos (con la lista); ya no está
--          importada; un cargo ya resuelto; pagar de más; anular con cargos
--          casados; un perfil ya enlazado
--   MX009  el archivo no se puede leer: sin cabecera, sin filas, sin día de
--          pago, o con filas que no dicen de cuál de dos nóminas son
--   MX011  lo que se va a postear ya no es lo que Edgar vio
--   42501  no es el dueño.   22023  un argumento mal escrito.
--   PGRST / MFA (403)  falta el código del teléfono.
--   55P03  el pegado no consiguió un candado en medio segundo: se vuelve a
--          pegar.
--
-- LOS CANDADOS (pg_advisory_xact_lock, clase 820261115): uno para importar,
-- uno por corrida al postear y anular, uno para casar y deshacer cargos, uno
-- para armar un lote, uno para repartir la bolsa. Postear toma además las horas del período de cada
-- persona (for update), para que nadie las cambie mientras entra.
--
-- LO QUE NO TOCA: ni c1…c14 ni sus tablas (llama a sus funciones por lo que
-- su contrato permite: fn_postear_interno y fn_reversar_interno desde su
-- puente, fn_postear —la puerta del dueño— para repartir la bolsa,
-- fn_horas_devengar, fn_banco_clasificar, fn_banco_descasar,
-- fn_jornal_repartir_ids); ni perfiles, horas, proyectos o costos_equipo,
-- que son de la app (los lee; sin llaves foráneas hacia ellos). No guarda
-- el archivo. No manda nada a Gusto.
--
-- PARA INSTALAR: (1) pegar este archivo en el SQL Editor (con la app
-- cerrada mejor: si no consigue un candado en medio segundo para con 55P03 y
-- no aplica nada); el final enseña fn_nomina_pegado(): nueve filas. (2)
-- pegar c15-pruebas.sql. (3) Si el c9-cierre.sql que se tiene nombra las
-- filas 180 a 183 en su cabecera, volver a pegarlo.
-- =====================================================================

-- (Lo primero, como en c4, c6, c10, c12 y c14: el pegado espera un candado
-- como mucho medio segundo. Con la app leyendo, para con 55P03 («lock
-- timeout»), no se aplica nada y se vuelve a pegar. Dura lo que dura el
-- pegado, una transacción.)
set local lock_timeout = '500ms';


-- ---------------------------------------------------------------------
-- 0. Las guardas, y lo que este archivo da por hecho (MX000 sin tocar nada)
-- ---------------------------------------------------------------------
-- Lo que falta para pegar c15, en llano (nulo = nada). La usan la
-- precondición de abajo y las pruebas.
create or replace function public.fn_nomina_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
  v_v     bigint;
  c_tablas constant text[] := array['nomina_config', 'nomina_columnas', 'nomina_personas', 'nomina_archivos', 'nomina_corridas',
                                    'nomina_corrida_personas', 'nomina_lineas', 'nomina_reparto', 'nomina_reparto_horas', 'nomina_pagos',
                                    'nomina_pago_partes', 'nomina_declaraciones', 'nomina_lotes', 'nomina_lote_horas', 'nomina_historial'];
  c_vistas constant text[] := array['v_nomina_corridas', 'v_nomina_personas', 'v_nomina_cargos', 'v_nomina_amarre', 'v_nomina_lotes',
                                    'v_nomina_control', 'v_nomina_papel'];
  c_fn     constant text[] := array['fn_nomina_precondiciones', 'fn_nomina_por_api', 'fn_nomina_exigir_dueno', 'fn_nomina_ve', 'fn_nomina_aal2',
                                    'fn_nomina_exigir_codigo', 'fn_nomina_ve_personas', 'fn_nomina_guarda', 'fn_nomina_al_libro',
                                    'fn_nomina_usd', 'fn_nomina_h', 'fn_nomina_dia', 'fn_nomina_hoy', 'fn_nomina_lista', 'fn_nomina_norm', 'fn_nomina_clave',
                                    'fn_nomina_monto', 'fn_nomina_fecha', 'fn_nomina_delicado', 'fn_nomina_etiqueta', 'fn_nomina_cuenta_mal',
                                    'fn_nomina_cuenta_sin_obra', 'fn_nomina_cuentas', 'fn_nomina_fecha_asiento', 'fn_nomina_apunta',
                                    'fn_nomina_config', 'fn_nomina_columna', 'fn_nomina_journal', 'fn_nomina_leer', 'fn_nomina_propone', 'fn_nomina_ya',
                                    'fn_nomina_ensayo', 'fn_nomina_importar',
                                    'fn_nomina_corrida', 'fn_nomina_descartar', 'fn_nomina_persona', 'fn_nomina_decidir', 'fn_nomina_plan',
                                    'fn_nomina_propuesta', 'fn_nomina_postear', 'fn_nomina_anular', 'fn_nomina_pendiente', 'fn_nomina_cargos',
                                    'fn_nomina_cargo_propuesta', 'fn_nomina_cargo_casar', 'fn_nomina_cargo_cuota', 'fn_nomina_cargo_deshacer',
                                    'fn_nomina_cargos_fuera',
                                    'fn_nomina_declaracion', 'fn_nomina_amarre', 'fn_nomina_por_horas', 'fn_nomina_horas_gusto', 'fn_nomina_lote',
                                    'fn_nomina_lote_csv',
                                    'fn_nomina_horas_pagadas', 'fn_nomina_cola', 'fn_nomina_pagado_hasta', 'fn_nomina_auxiliar',
                                    'fn_nomina_bolsa', 'fn_nomina_bolsa_repartir', 'fn_nomina_control',
                                    'fn_nomina_cierre',
                                    'fn_nomina_pegado'];
begin
  foreach v_x in array array['es_dueno()', 'fn_desde_editor()', 'fn_fecha_miami(timestamptz)', 'fn_libro_version()',
                             'fn_postear_interno(jsonb)', 'fn_reversar_interno(uuid,text,text,jsonb)', 'fn_verificar_cadena()',
                             'fn_puente_cuenta_de(text)', 'fn_horas_devengar(text)', 'fn_banco_clasificar(uuid,jsonb,text)',
                             'fn_banco_descasar(uuid,text)', 'fn_jornal_repartir_ids(bigint[],numeric)'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'periodos', 'asientos', 'asiento_lineas', 'perfiles', 'proyectos', 'horas', 'costos_equipo',
                             'puente_cuentas', 'movimientos_banco', 'jornal_config', 'jornal_repartos', 'jornal_reparto_horas'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if to_regprocedure('auth.uid()') is null or to_regprocedure('auth.jwt()') is null then
    v_falta := v_falta || 'auth.uid() y auth.jwt() (Supabase Auth)'::text;
  end if;
  if cardinality(v_falta) > 0 then
    return format('c15 se pega después de c1, c2, c3, c4, c6 y c10 (y de c7, s1, p1, c8, c9, c11, c12, c13 y c14 si se usan), con las '
                  'tablas de la app: falta %s.', array_to_string(v_falta, ', '));
  end if;
  -- La versión de c2 que va con esta capa (la del tiempo en producción).
  execute 'select public.fn_libro_version()' into v_v;
  if coalesce(v_v, 0) < 2026100201 then
    return format('el c2-libro.sql pegado es anterior (marca %s; esta capa pide 2026100201): vuelve a pegar c2-libro.sql.', v_v);
  end if;
  -- Las columnas que esta capa lee por su nombre.
  select string_agg(x.t || '.' || x.c, ', ' order by x.t, x.c) into v_x
    from (values ('horas', 'id'), ('horas', 'fecha'), ('horas', 'usuario_id'), ('horas', 'proyecto_id'), ('horas', 'horas'),
                 ('horas', 'co'), ('horas', 'fase'), ('horas', 'aprobado_el'),
                 ('perfiles', 'id'), ('perfiles', 'nombre'), ('perfiles', 'rol'), ('perfiles', 'activo'),
                 ('proyectos', 'id'), ('proyectos', 'nombre'), ('costos_equipo', 'usuario_id'), ('costos_equipo', 'costo_hora'),
                 ('asientos', 'numero'), ('asientos', 'fecha_contable'), ('asientos', 'origen_tabla'), ('asientos', 'origen_id'),
                 ('asientos', 'camino'), ('asientos', 'reversa_a'), ('asientos', 'cadena_pos'),
                 ('asiento_lineas', 'asiento_id'), ('asiento_lineas', 'orden'), ('asiento_lineas', 'cuenta'), ('asiento_lineas', 'monto'),
                 ('asiento_lineas', 'proyecto_id'), ('asiento_lineas', 'co'),
                 ('cuentas', 'codigo'), ('cuentas', 'nombre'), ('cuentas', 'tipo'), ('cuentas', 'regla_obra'), ('cuentas', 'imputable'),
                 ('periodos', 'periodo'), ('periodos', 'tipo'), ('periodos', 'desde'), ('periodos', 'hasta'), ('periodos', 'anio'),
                 ('puente_cuentas', 'rol'), ('puente_cuentas', 'cuenta'),
                 ('movimientos_banco', 'estado'), ('movimientos_banco', 'estado_motivo'), ('movimientos_banco', 'monto'),
                 ('movimientos_banco', 'fecha'), ('movimientos_banco', 'cuenta'), ('movimientos_banco', 'descripcion'),
                 ('movimientos_banco', 'desc_norm'), ('movimientos_banco', 'asiento_id'), ('movimientos_banco', 'casado_regla'),
                 ('jornal_config', 'cuenta_sin_obra'), ('jornal_repartos', 'estado'), ('jornal_reparto_horas', 'horas_id')) as x(t, c)
   where not exists (select 1 from information_schema.columns k
                      where k.table_schema = 'public' and k.table_name = x.t and k.column_name = x.c);
  if v_x is not null then
    return format('faltan columnas que esta capa lee: %s. ¿Es la base de la app, con c3, c6 y c10 pegados?', v_x);
  end if;
  -- Las cuentas del plan (c1) que esta capa usa de fábrica, y las dos de la
  -- mano de obra que c3 nombra en sus cuentas del puente.
  select string_agg(q.c, ', ' order by q.c) into v_x
    from unnest(array['2210', '2220', '2225', '2230', '2240', '2250', '5010', '5015', '6000', '6005', '6010', '6500']) q(c)
   where not exists (select 1 from cuentas k where k.codigo = q.c);
  if v_x is not null then
    return format('faltan en el plan de cuentas (c1) las cuentas de la nómina: %s. Vuelve a pegar c1-plan-de-cuentas.sql.', v_x);
  end if;
  select string_agg(q.r, ', ' order by q.r) into v_x
    from unnest(array['mano_obra', 'mano_obra_oficial', 'sueldos_devengados']) q(r)
   where not exists (select 1 from puente_cuentas pc where pc.rol = q.r);
  if v_x is not null then
    return format('faltan en las cuentas del puente (c3) las de la mano de obra: %s. Vuelve a pegar c3-puentes.sql.', v_x);
  end if;
  -- Una tabla con el nombre de las de c15 que no sea de c15: se para antes de
  -- tocar nada (la lección de c8 con ia_propuestas).
  foreach v_x in array array['nomina_config:cuenta_bolsa', 'nomina_columnas:concepto', 'nomina_personas:clave', 'nomina_archivos:sha256',
                             'nomina_corridas:dia_pago', 'nomina_corrida_personas:persona_id', 'nomina_lineas:concepto',
                             'nomina_reparto:destino', 'nomina_reparto_horas:horas_id', 'nomina_pagos:movimiento_id',
                             'nomina_pago_partes:pago_id', 'nomina_declaraciones:forma', 'nomina_lotes:semana_empieza',
                             'nomina_lote_horas:lote_id', 'nomina_historial:que'] loop
    if to_regclass('public.' || split_part(v_x, ':', 1)) is not null
       and not exists (select 1 from information_schema.columns
                        where table_schema = 'public' and table_name = split_part(v_x, ':', 1) and column_name = split_part(v_x, ':', 2)) then
      return format('la tabla %s ya existe en esta base y no es la de c15 (no tiene la columna %s): otra cosa usa ese nombre. No la '
                    'toco; avisa antes de seguir.', split_part(v_x, ':', 1), split_part(v_x, ':', 2));
    end if;
  end loop;
  -- Una vista o una función con nombre de c15 que no sea de c15 (otra sesión
  -- escribe esta misma base): «create or replace» la pisaría sin avisar.
  select string_agg(x.que, ', ' order by x.que) into v_x
    from (select 'la vista ' || c.relname as que
            from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind in ('v', 'm', 'r') and c.relname = any (c_vistas)
             and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c15: %'
          union all
          select 'la función ' || p.oid::regprocedure::text
            from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.proname = any (c_fn)
             and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c15: %') x;
  if v_x is not null then
    return format('ya hay en esta base, con nombre de c15 y sin ser de c15: %s. No lo piso; avisa antes de seguir.', v_x);
  end if;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: la nómina la ve y la toca solo el dueño.';
  end if;
  -- Nada ajeno colgado de las vistas de c15 (se borran y se rehacen).
  select string_agg(distinct format('la vista %s', dc.oid::regclass), ', ') into v_x
    from pg_depend d
    join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
    join pg_class dc on dc.oid = rw.ev_class
    join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
   where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v' and cv.relname = any (c_vistas)
     and dc.oid <> cv.oid
     and not (dc.relnamespace = 'public'::regnamespace and dc.relname = any (c_vistas));
  if v_x is not null then
    return format('%s depende(n) de las vistas de c15, que al pegarlo se borran y se rehacen: guarda su definición, bórralas, '
                  'pega c15 y vuelve a crearlas.', v_x);
  end if;
  return null;
end $$;
revoke execute on function public.fn_nomina_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_nomina_precondiciones() is 'c15: lo que falta para pegar c15-nomina.sql (nulo = nada): c1, c2 (marca 2026100201), c3, c6 y c10, las tablas y columnas del libro, del banco y de la app que lee, las cuentas de la nómina en el plan y en las cuentas del puente, Supabase Auth, el SQL Editor, un dueño activo, nada ajeno con nombre de c15 y nada ajeno sobre sus vistas.';

do $$
declare
  v text;
begin
  v := public.fn_nomina_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c15-nomina NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1, c2, c3, c4, c6, c7, s1, p1, c8, c9, c10, c11, c12, c13, c14 y después este archivo (pruebas/conta/README.md, §0).';
  end if;
end $$;

-- Las vistas de c15 se borran aquí y se rehacen al final (18): así una
-- auxiliar puede cambiar las columnas que devuelve sin que su vista lo
-- impida. La precondición ya comprobó que nada ajeno cuelga de ellas.
drop view if exists public.v_nomina_corridas, public.v_nomina_personas, public.v_nomina_cargos, public.v_nomina_amarre,
                    public.v_nomina_lotes, public.v_nomina_control, public.v_nomina_papel;
-- (Y una función cuya salida cambia de columnas tampoco se puede rehacer encima —«cannot change return type»—: si la que hay
-- es la de antes, se borra aquí, con sus vistas ya borradas, y se rehace abajo. El control ganó la columna «corto».)
do $$
begin
  if to_regprocedure('public.fn_nomina_control()') is not null
     and not exists (select 1 from pg_proc p
                      where p.oid = to_regprocedure('public.fn_nomina_control()') and 'corto' = any (p.proargnames)) then
    drop function public.fn_nomina_control();
  end if;
end $$;

-- ¿Entró la petición por la API? Por el rol con que entró (el ajuste «role»
-- de la sesión, que PostgREST fija a authenticated, anon o service_role) o
-- por el rol de ahora: dentro de una función con permisos de dueño
-- current_user cambia, y el ajuste no. El SQL Editor y pg_cron entran sin
-- «set role» (none) como el dueño de la base. (La misma regla que c14.)
create or replace function public.fn_nomina_por_api() returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select current_user in ('authenticated', 'anon', 'service_role')
      or coalesce(nullif(current_setting('role', true), 'none'), session_user::text) in ('authenticated', 'anon', 'service_role', 'authenticator')
$$;
revoke execute on function public.fn_nomina_por_api() from public, anon, service_role;
grant  execute on function public.fn_nomina_por_api() to authenticated;
comment on function public.fn_nomina_por_api() is 'c15: verdadero si la petición entró por la API (el rol con que entró o el de ahora es authenticated, anon o service_role); falso en el SQL Editor y en pg_cron.';

-- ¿Quién llama por la API? Solo el dueño. Desde el SQL Editor o pg_cron pasa.
create or replace function public.fn_nomina_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if fn_nomina_por_api() and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501',
      message = 'La nómina (lo que cobra cada persona, sus corridas y sus cargos del banco) la ve y la toca solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_nomina_exigir_dueno() from public, anon, service_role;
grant  execute on function public.fn_nomina_exigir_dueno() to authenticated;
comment on function public.fn_nomina_exigir_dueno() is 'c15: la guarda de lo que llama la pantalla: por la API solo el dueño (es_dueno); el SQL Editor y pg_cron pasan.';

-- ¿Ve quien mira? Lo mismo, sin error: las auxiliares de las vistas no
-- frenan a nadie; a quien no es el dueño no le devuelven nada.
create or replace function public.fn_nomina_ve() returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select not public.fn_nomina_por_api() or coalesce(es_dueno(), false)
$$;
revoke execute on function public.fn_nomina_ve() from public, anon, service_role;
grant  execute on function public.fn_nomina_ve() to authenticated;
comment on function public.fn_nomina_ve() is 'c15: verdadero para el dueño por la API y para el SQL Editor; las auxiliares de las vistas no devuelven nada a los demás.';

-- EL CÓDIGO DEL TELÉFONO. ¿Pasó esta sesión el segundo factor? (su token
-- dice aal2). Fuera de la API (el SQL Editor, pg_cron), sí.
create or replace function public.fn_nomina_aal2() returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select not public.fn_nomina_por_api() or coalesce((select auth.jwt() ->> 'aal'), '') = 'aal2'
$$;
revoke execute on function public.fn_nomina_aal2() from public, anon, service_role;
grant  execute on function public.fn_nomina_aal2() to authenticated;
comment on function public.fn_nomina_aal2() is 'c15: verdadero si la sesión de la API pasó el código del teléfono (aal2), y fuera de la API.';

-- Por la API, la sesión tiene que haber pasado el segundo factor, tenga o no
-- factor la cuenta. Contesta como la guarda de s1 (403, código «MFA»): la
-- app ya sabe pedirlo. Lo piden todas las que escriben la nómina y las que
-- leen lo de cada persona.
create or replace function public.fn_nomina_exigir_codigo() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if not fn_nomina_aal2() then
    raise sqlstate 'PGRST' using
      message = json_build_object(
        'code',    'MFA',
        'message', 'Falta el código del teléfono: lo que cobra cada persona solo se ve y se toca con él. Actívalo en Contabilidad → '
                   'Conexiones y seguridad (si no lo tienes) y entra otra vez escribiéndolo.',
        'details', 'Esta sesión no pasó el segundo factor (aal1).',
        'hint',    'mfa')::text,
      detail = json_build_object('status', 403)::text;
  end if;
end $$;
revoke execute on function public.fn_nomina_exigir_codigo() from public, anon, service_role;
grant  execute on function public.fn_nomina_exigir_codigo() to authenticated;
comment on function public.fn_nomina_exigir_codigo() is 'c15: por la API, la sesión tiene que haber pasado el código del teléfono (aal2); si no, 403 con el código MFA, como la guarda de s1. El SQL Editor pasa.';

-- ¿Ve lo de cada persona? El dueño, con su código. Sin error (para las
-- vistas y los controles).
create or replace function public.fn_nomina_ve_personas() returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select public.fn_nomina_ve() and public.fn_nomina_aal2()
$$;
revoke execute on function public.fn_nomina_ve_personas() from public, anon, service_role;
grant  execute on function public.fn_nomina_ve_personas() to authenticated;
comment on function public.fn_nomina_ve_personas() is 'c15: verdadero para el dueño con el código del teléfono (y para el SQL Editor): quien puede leer lo de cada persona.';


-- ---------------------------------------------------------------------
-- 1. Lo común: cómo se lee un monto, unas horas, un día; cómo se limpia el
--    nombre de una columna; cómo se lee una celda del archivo (un importe,
--    una fecha) y qué celda no se guarda nunca.
-- ---------------------------------------------------------------------
create or replace function public.fn_nomina_usd(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null then '—'
              when p < 0 then '-$' || to_char(-p, 'FM999,999,999,990.00')
              else '$' || to_char(p, 'FM999,999,999,990.00') end
$$;
revoke execute on function public.fn_nomina_usd(numeric) from public, anon, service_role;
grant  execute on function public.fn_nomina_usd(numeric) to authenticated;
comment on function public.fn_nomina_usd(numeric) is 'c15: un monto en dólares como se lee ($1,234.56).';

create or replace function public.fn_nomina_h(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$ select case when p is null then '—' else trim_scale(p)::text end $$;
revoke execute on function public.fn_nomina_h(numeric) from public, anon, service_role;
grant  execute on function public.fn_nomina_h(numeric) to authenticated;
comment on function public.fn_nomina_h(numeric) is 'c15: unas horas como se leen (42, 6.5).';

create or replace function public.fn_nomina_dia(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select extract(day from p)::int || '-'
         || (array['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'])[extract(month from p)::int]
         || '-' || extract(year from p)::int
$$;
revoke execute on function public.fn_nomina_dia(date) from public, anon, service_role;
grant  execute on function public.fn_nomina_dia(date) to authenticated;
comment on function public.fn_nomina_dia(date) is 'c15: un día en corto con su año (8-ene-2027): no se confunde el mes con el día.';

create or replace function public.fn_nomina_hoy() returns date
language sql stable
set search_path = public, pg_temp
as $$ select public.fn_fecha_miami(now()) $$;
revoke execute on function public.fn_nomina_hoy() from public, anon, service_role;
grant  execute on function public.fn_nomina_hoy() to authenticated;
comment on function public.fn_nomina_hoy() is 'c15: hoy en Miami.';

create or replace function public.fn_nomina_lista(p_items text[], p_max int default 900) returns text
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
revoke execute on function public.fn_nomina_lista(text[], int) from public, anon, service_role;
grant  execute on function public.fn_nomina_lista(text[], int) to authenticated;
comment on function public.fn_nomina_lista(text[], int) is 'c15: una lista larga para el detalle de un control: sus elementos mientras quepan en p_max caracteres y, si no caben todos, «… y N más» (ninguno queda cortado a medias).';

-- EL NOMBRE DE UNA COLUMNA, LIMPIO: en minúsculas, y todo lo que no es letra
-- ni número, un espacio. «Employee first name», «employee_first_name» y
-- «EMPLOYEE  FIRST-NAME» son la misma columna. Así se busca en el mapeo.
create or replace function public.fn_nomina_norm(p text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select nullif(btrim(regexp_replace(lower(coalesce(p, '')), '[^[:alnum:]]+', ' ', 'g')), '')
$$;
revoke execute on function public.fn_nomina_norm(text) from public, anon, service_role;
grant  execute on function public.fn_nomina_norm(text) to authenticated;
comment on function public.fn_nomina_norm(text) is 'c15: el nombre de una columna (o de una persona) limpio para compararlo: en minúsculas y con un espacio donde había cualquier cosa que no fuera letra o número. Vacío = nulo.';

-- UN IMPORTE (o unas horas) como viene en una celda: 1958.00, 1,958.00,
-- $1,958.00, (50.00), -50.00; vacío y «-» son cero. Cualquier otra cosa no
-- es un número: nulo (quien llama decide; nunca se adivina). Una coma solo
-- vale como separador de miles bien puesto: «1,95» no es 195.
create or replace function public.fn_nomina_monto(p text) returns numeric
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  t   text := btrim(coalesce(p, ''), E' \t\r\n');
  neg boolean := false;
begin
  if t in ('', '-', '—', '–') then
    return 0;
  end if;
  if t ~ '^\(.*\)$' then
    neg := true;
    t := btrim(substr(t, 2, length(t) - 2));
  end if;
  if left(t, 1) = '-' then
    neg := not neg;
    t := btrim(substr(t, 2));
  end if;
  if left(t, 1) = '$' then
    t := btrim(substr(t, 2));
    if left(t, 1) = '-' then
      neg := not neg;
      t := btrim(substr(t, 2));
    end if;
  end if;
  if t ~ '^[0-9]{1,3}(,[0-9]{3})+(\.[0-9]+)?$' then
    t := replace(t, ',', '');
  elsif t !~ '^[0-9]+(\.[0-9]+)?$' and t !~ '^\.[0-9]+$' then
    return null;
  end if;
  if length(t) > 40 then
    return null;
  end if;
  return case when neg then -(t::numeric) else t::numeric end;
end $$;
revoke execute on function public.fn_nomina_monto(text) from public, anon, service_role;
grant  execute on function public.fn_nomina_monto(text) to authenticated;
comment on function public.fn_nomina_monto(text) is 'c15: un importe (o unas horas) como viene en una celda del archivo: 1958.00, 1,958.00, $1,958.00, (50.00), -50.00; vacío y «-» son 0. Lo que no es un número, nulo (no se adivina; una coma solo vale como separador de miles).';

-- UNA FECHA como viene en una celda: MM/DD/AAAA (como las da Gusto) o
-- AAAA-MM-DD. Otra cosa, o un día que no existe: nulo.
create or replace function public.fn_nomina_fecha(p text) returns date
language plpgsql immutable
set search_path = public, pg_temp
as $$
declare
  t text := btrim(coalesce(p, ''), E' \t\r\n');
  m text[];
  n int;
begin
  m := regexp_match(t, '^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$');
  if m is not null then
    begin
      return make_date(m[3]::int, m[1]::int, m[2]::int);
    exception when others then
      return null;
    end;
  end if;
  m := regexp_match(t, '^([0-9]{4})-([0-9]{2})-([0-9]{2})$');
  if m is not null then
    begin
      return make_date(m[1]::int, m[2]::int, m[3]::int);
    exception when others then
      return null;
    end;
  end if;
  -- «Jan 22, 2027» o «January 22, 2027» (el mes, en inglés: como lo escribe Gusto)
  m := regexp_match(t, '^([A-Za-z]{3,9})\.? ([0-9]{1,2}), ([0-9]{4})$');
  if m is not null then
    n := array_position(array['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'], left(lower(m[1]), 3));
    if n is null or lower(m[1]) <> all (array['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'sept', 'oct', 'nov', 'dec', 'january',
                                              'february', 'march', 'april', 'june', 'july', 'august', 'september', 'october', 'november',
                                              'december']) then
      return null;
    end if;
    begin
      return make_date(m[3]::int, n, m[2]::int);
    exception when others then
      return null;
    end;
  end if;
  return null;
end $$;
revoke execute on function public.fn_nomina_fecha(text) from public, anon, service_role;
grant  execute on function public.fn_nomina_fecha(text) to authenticated;
comment on function public.fn_nomina_fecha(text) is 'c15: una fecha como viene en una celda del archivo: MM/DD/AAAA (como las da Gusto), AAAA-MM-DD o «Jan 22, 2027». Otra forma, o un día que no existe, nulo (nunca se adivina: 22/01/2027 no es una fecha).';

-- LA CLAVE DE UNA PERSONA: su nombre limpio con sus palabras EN ORDEN ALFABÉTICO.
-- «ZZ Ayudante Uno», «Uno, ZZ Ayudante» y «UNO ZZ AYUDANTE» son la misma
-- persona: el archivo puede traer el nombre y el apellido en dos columnas o
-- en una sola, en cualquier orden, y Gusto tiene dos formatos de journal.
create or replace function public.fn_nomina_clave(p text) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select nullif(array_to_string(array(select w from unnest(string_to_array(public.fn_nomina_norm(p), ' ')) w order by w), ' '), '')
$$;
revoke execute on function public.fn_nomina_clave(text) from public, anon, service_role;
grant  execute on function public.fn_nomina_clave(text) to authenticated;
comment on function public.fn_nomina_clave(text) is 'c15: la clave de una persona de la nómina: su nombre limpio (fn_nomina_norm) con sus palabras en orden alfabético, para reconocerla de un archivo a otro aunque el nombre venga en otro orden («Uno, ZZ Ayudante» = «ZZ Ayudante Uno»). Vacío = nulo.';

-- ¿ESTA CELDA TIENE FORMA DE DATO DELICADO? Un número de Seguro Social
-- (###-##-####, entero o dentro de un texto). Lo que tenga esa forma no se
-- guarda en ningún sitio ni se repite en ningún mensaje. (El nombre de un
-- IMPUESTO —«Employee social security tax»— no tiene esa forma: es una
-- columna de dinero como las demás.)
create or replace function public.fn_nomina_delicado(p text) returns boolean
language sql immutable
set search_path = public, pg_temp
as $$
  select coalesce(p ~ '(^|[^0-9])[0-9]{3}-[0-9]{2}-[0-9]{4}([^0-9]|$)', false)
$$;
revoke execute on function public.fn_nomina_delicado(text) from public, anon, service_role;
grant  execute on function public.fn_nomina_delicado(text) to authenticated;
comment on function public.fn_nomina_delicado(text) is 'c15: verdadero si un texto lleva algo con la forma de un número de Seguro Social (###-##-####): no se guarda ni se repite en ningún mensaje.';

-- EL RÓTULO DE UNA COLUMNA, PARA ENSEÑARLO O GUARDARLO. Un rótulo es un
-- nombre, no un dato: si lo que llegó como rótulo parece un dato (un número,
-- un importe, algo con forma de Seguro Social, o es larguísimo) se enseña
-- como «columna N» y no se repite.
create or replace function public.fn_nomina_etiqueta(p text, p_n int) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null or btrim(p) = '' then format('columna %s (sin nombre)', p_n)
              when public.fn_nomina_delicado(p) or btrim(p) ~ '^[-$(). ,0-9]+$' or length(btrim(p)) > 80 or btrim(p) ~ '@'
                then format('columna %s', p_n)
              else btrim(p) end
$$;
revoke execute on function public.fn_nomina_etiqueta(text, int) from public, anon, service_role;
grant  execute on function public.fn_nomina_etiqueta(text, int) to authenticated;
comment on function public.fn_nomina_etiqueta(text, int) is 'c15: el rótulo de una columna para enseñarlo o guardarlo: tal cual si es un nombre; «columna N» si parece un dato (un número, un correo, algo con forma de Seguro Social, o más de 80 caracteres).';


-- ---------------------------------------------------------------------
-- 2. Las tablas (nacen cerradas: solo el dueño lee, y lo de cada persona
--    solo con el código del teléfono; escribe solo el dueño por las
--    funciones de aquí, con la marca de la transacción). Montos en dólares,
--    numeric(14,2); horas, numeric. Llaves foráneas a cuentas, asientos,
--    movimientos_banco y entre tablas de c15; a perfiles, horas y proyectos
--    NO (son de la app: no se les cuelga nada que cambie cómo se borran; lo
--    que cambie después lo ve el control). Para crecer, «add column if not
--    exists».
-- ---------------------------------------------------------------------
-- La configuración: una sola fila.
create table if not exists public.nomina_config (
  id                    int           primary key,
  cuenta_sin_obra       text          references public.cuentas (codigo),
  cuenta_oficina        text          not null default '6000' references public.cuentas (codigo),
  cuenta_oficial        text          not null default '6005' references public.cuentas (codigo),
  cuenta_bolsa          text          not null default '5015' references public.cuentas (codigo),
  cuenta_burden_obra    text          not null default '5010' references public.cuentas (codigo),
  cuenta_burden_admin   text          not null default '6010' references public.cuentas (codigo),
  cuenta_cuota          text          not null default '6500' references public.cuentas (codigo),
  semana_empieza        int           not null default 1,
  horas_extra_desde     numeric       not null default 40,
  horas_periodo_oficial numeric       not null default 80,
  cargo_dias_antes      int           not null default 10,
  cargo_dias_despues    int           not null default 5,
  saldo_dias            int           not null default 10,
  amarre_tolerancia     numeric(14,2) not null default 1.00,
  cargo_patrones        jsonb         not null default '{"neto": "\\mNET\\M", "impuestos": "\\mTAX\\M", "reembolsos": "\\mREM\\M", "manutencion": "\\mCSD\\M", "cuota": "\\mFEE\\M"}'::jsonb,
  actualizado           timestamptz   not null default now(),
  actualizado_por       uuid,
  constraint nomina_config_una     check (id = 1),
  constraint nomina_config_semana  check (semana_empieza between 1 and 7),
  constraint nomina_config_horas   check (horas_extra_desde > 0 and horas_extra_desde <= 168 and horas_periodo_oficial > 0
                                          and horas_periodo_oficial <= 744),
  constraint nomina_config_dias    check (cargo_dias_antes between 0 and 60 and cargo_dias_despues between 0 and 60
                                          and saldo_dias between 0 and 365),
  constraint nomina_config_amarre  check (amarre_tolerancia >= 0 and amarre_tolerancia <= 1000),
  constraint nomina_config_patrones check (jsonb_typeof(cargo_patrones) = 'object')
);
comment on table public.nomina_config is 'c15: la configuración de la nómina (una fila): la cuenta de las horas sin obra de la gente de campo (cuenta_sin_obra; vacía = la del jornal de c10), la del sueldo de oficina (6000) y la del oficial (6005), la bolsa del burden real (5015), el burden por obra al que se reparte (5010) y el burden de oficina (6010), la de la cuota mensual de Gusto (6500); el día en que empieza la semana laboral (semana_empieza: 1 lunes … 7 domingo) y desde cuántas horas a la semana son extra (40); las horas que cubre el sueldo del oficial en un período de pago (80); cuántos días antes y después del día de pago se busca el cargo de Gusto; a los cuántos días de la nómina un saldo por pagar se avisa; la tolerancia del amarre con el 941, el 940 y el RT-6; y cómo se reconoce cada cargo de Gusto por su descripción (cargo_patrones). Se cambia con fn_nomina_config.';

-- EL MAPEO DE LAS COLUMNAS DEL ARCHIVO: por su NOMBRE (limpio), nunca por
-- su posición. De fábrica trae los nombres de las 86 columnas del «Payroll
-- journal» de Gusto y sus rótulos probables; lo que no esté aquí y traiga
-- cifras deja la corrida sin postear hasta que Edgar diga qué es.
create table if not exists public.nomina_columnas (
  alias            text        primary key,
  concepto         text        not null,
  clase            text        not null,
  cuenta           text        references public.cuentas (codigo),
  declara          text,
  de_fabrica       boolean     not null default false,
  nota             text,
  creado_el        timestamptz not null default now(),
  actualizado_el   timestamptz not null default now(),
  actualizado_por  uuid,
  constraint nomina_columnas_alias   check (alias = public.fn_nomina_norm(alias) and length(alias) <= 80),
  constraint nomina_columnas_concepto check (concepto ~ '^[a-z][a-z0-9_]{0,59}$'),
  constraint nomina_columnas_clase   check (clase in ('llave', 'tipo', 'dia_pago', 'periodo_desde', 'periodo_hasta', 'periodo', 'nombre', 'apellido',
                                                      'segundo', 'nombre_completo', 'empleado_id', 'metodo_pago', 'horas', 'horas_fuera',
                                                      'bruto', 'bruto_total', 'imp_empleado', 'imp_empleado_total', 'deduccion',
                                                      'deduccion_total', 'neto', 'reembolso', 'reembolso_total', 'cheque_total',
                                                      'imp_patron', 'imp_patron_total', 'ben_patron', 'ben_patron_total', 'costo_total',
                                                      'delicado', 'ignorar')),
  constraint nomina_columnas_declara check (declara is null or (declara in ('fit', 'ss_ee', 'med_ee', 'med_adic', 'ss_er', 'med_er', 'futa', 'suta')
                                                                and clase in ('imp_empleado', 'imp_patron'))),
  constraint nomina_columnas_cuenta  check (cuenta is null or clase in ('imp_empleado', 'imp_empleado_total', 'deduccion', 'deduccion_total',
                                                                        'neto', 'reembolso', 'reembolso_total', 'imp_patron',
                                                                        'imp_patron_total', 'ben_patron', 'ben_patron_total'))
);
comment on table public.nomina_columnas is 'c15: el mapeo de las columnas del archivo de nómina, por su NOMBRE limpio (alias: en minúsculas, sin puntuación): a qué concepto corresponde (concepto: el identificador de Gusto), qué clase de dato es (clase: la llave y las fechas de la nómina, la persona, las horas, cada parte del bruto, cada impuesto del empleado y del patrón, las deducciones, el neto, los reembolsos, los totales —que se usan de control y nunca se suman—, lo delicado —que no se guarda nunca— y lo que se ignora), a qué cuenta del libro va lo que es dinero (cuenta), y con qué renglón de las declaraciones amarra (declara: fit, ss_ee, med_ee, med_adic, ss_er, med_er, futa, suta). De fábrica, el de Gusto (de_fabrica); se cambia y se amplía con fn_nomina_columna. Una columna con cifras que no esté aquí deja la corrida sin postear.';

-- LAS PERSONAS del journal: cada empleado, enlazado a su perfil de la app y
-- con su clase. Nace sin enlazar (con una propuesta por el nombre, que la
-- pantalla enseña); Edgar lo enlaza y lo confirma UNA vez.
create table if not exists public.nomina_personas (
  id               uuid        primary key default gen_random_uuid(),
  nombre           text        not null,
  clave            text        not null,
  gusto_id         text,
  usuario_id       uuid,
  clase            text,
  a_obra           boolean     not null default true,
  horas_periodo    numeric,
  confirmado_el    timestamptz,
  confirmado_por   uuid,
  activo           boolean     not null default true,
  nota             text,
  creado_el        timestamptz not null default now(),
  creado_por       uuid,
  actualizado_el   timestamptz not null default now(),
  actualizado_por  uuid,
  constraint nomina_personas_nombre   check (btrim(nombre) <> '' and length(nombre) <= 200),
  constraint nomina_personas_clase    check (clase is null or clase in ('campo', 'oficial', 'oficina')),
  constraint nomina_personas_horas    check (horas_periodo is null or (horas_periodo > 0 and horas_periodo <= 744)),
  constraint nomina_personas_confirma check (confirmado_el is null or (usuario_id is not null and clase is not null))
);
create unique index if not exists nomina_personas_clave_unica   on public.nomina_personas (clave);
create unique index if not exists nomina_personas_gusto_unico   on public.nomina_personas (gusto_id) where gusto_id is not null;
create unique index if not exists nomina_personas_usuario_unico on public.nomina_personas (usuario_id) where usuario_id is not null;
comment on table public.nomina_personas is 'c15: cada empleado que aparece en un journal de nómina: su nombre como lo trae el archivo, su clave (el nombre limpio, con el que se le reconoce de un archivo a otro; gusto_id, el identificador de Gusto, si el archivo lo trae), su perfil de la app (usuario_id = perfiles.id, sin llave foránea: es de la app), su clase (campo: mano de obra directa, 5000, repartida por obra según sus horas; oficial: el accionista-oficial, 5001 por obra según sus horas y 6005 lo demás; oficina: 6000), si las horas del oficial en obra llevan parte de su sueldo a la obra (a_obra) y cuántas horas cubre su sueldo en un período (horas_periodo; vacío = lo de la configuración), y cuándo y quién lo confirmó. Sin enlazar o sin confirmar, sus corridas no se postean. Se escribe con fn_nomina_persona.';

-- Cada archivo que entró (su nombre, su sha256 y su tamaño: el archivo
-- mismo NO se guarda; se vuelve a bajar de Gusto cuando haga falta).
create table if not exists public.nomina_archivos (
  id             uuid        primary key default gen_random_uuid(),
  nombre         text        not null,
  sha256         text        not null,
  bytes          bigint      not null,
  filas          int         not null,
  corridas       int         not null,
  delicado       text[]      not null default '{}',
  importado_el   timestamptz not null default clock_timestamp(),
  importado_por  uuid,
  constraint nomina_archivos_sha   check (sha256 ~ '^[0-9a-f]{64}$'),
  constraint nomina_archivos_forma check (bytes > 0 and filas > 0 and corridas > 0 and btrim(nombre) <> '' and length(nombre) <= 200)
);
create index if not exists nomina_archivos_sha_idx on public.nomina_archivos (sha256);
comment on table public.nomina_archivos is 'c15: cada archivo de nómina que entró: su nombre, su sha256 y su tamaño (lo que manda la pantalla), cuántas filas traía, cuántas nóminas nuevas dejó, los rótulos de las columnas delicadas que traía y NO se guardaron (delicado: solo sus nombres), cuándo y quién. El archivo mismo no se guarda: lleva datos de las personas; se vuelve a bajar de Gusto. Solo se añade.';

-- LA CORRIDA: una nómina (un día de pago, un período, un tipo), con sus
-- totales del journal, cómo se leyó y, posteada, su asiento.
create table if not exists public.nomina_corridas (
  id                 uuid          primary key default gen_random_uuid(),
  archivo_id         uuid          not null references public.nomina_archivos (id),
  n                  int           not null,
  llave              text          not null,
  firma              text          not null,
  dia_pago           date          not null,
  periodo_desde      date,
  periodo_hasta      date,
  tipo               text          not null,
  tipo_texto         text,
  gusto_id           text,
  toma_horas         boolean       not null,
  estado             text          not null default 'importada',
  personas           int           not null,
  bruto              numeric(14,2) not null default 0,
  imp_empleado       numeric(14,2) not null default 0,
  deducciones        numeric(14,2) not null default 0,
  neto               numeric(14,2) not null default 0,
  reembolsos         numeric(14,2) not null default 0,
  reembolsos_en_neto numeric(14,2) not null default 0,
  imp_patron         numeric(14,2) not null default 0,
  ben_patron         numeric(14,2) not null default 0,
  horas              numeric       not null default 0,
  declara            jsonb         not null default '{}'::jsonb,
  cuadra             boolean       not null,
  descuadres         jsonb         not null default '[]'::jsonb,
  columnas           jsonb         not null default '[]'::jsonb,
  sin_clasificar     jsonb         not null default '[]'::jsonb,
  totales_archivo    jsonb,
  avisos             jsonb         not null default '[]'::jsonb,
  importada_el       timestamptz   not null default clock_timestamp(),
  importada_por      uuid,
  plan               jsonb,
  huella             text,
  pasivos            jsonb,
  asiento_id         uuid          references public.asientos (id),
  asiento_numero     text,
  fecha_asiento      date,
  burden_asiento_id  uuid          references public.asientos (id),
  posteada_el        timestamptz,
  posteada_por       uuid,
  anulada_el         timestamptz,
  anulada_por        uuid,
  anulada_motivo     text,
  reverso_id         uuid          references public.asientos (id),
  burden_reverso_id  uuid          references public.asientos (id),
  descartada_el      timestamptz,
  descartada_por     uuid,
  descartada_motivo  text,
  constraint nomina_corridas_tipo     check (tipo in ('regular', 'fuera_de_ciclo')),
  constraint nomina_corridas_estado   check (estado in ('importada', 'posteada', 'anulada', 'descartada')),
  constraint nomina_corridas_periodo  check ((periodo_desde is null) = (periodo_hasta is null)
                                             and (periodo_desde is null or (periodo_desde <= periodo_hasta and periodo_hasta - periodo_desde <= 92))),
  constraint nomina_corridas_asiento  check ((estado in ('posteada', 'anulada')) = (asiento_id is not null)
                                             and (asiento_id is null) = (asiento_numero is null) and (asiento_id is null) = (fecha_asiento is null)
                                             and (asiento_id is null) = (plan is null) and (asiento_id is null) = (pasivos is null)
                                             and (asiento_id is null) = (posteada_el is null)
                                             and (burden_asiento_id is null or asiento_id is not null)),
  constraint nomina_corridas_anulada  check ((estado = 'anulada') = (anulada_el is not null)
                                             and (estado = 'anulada') = (coalesce(btrim(anulada_motivo), '') <> '')
                                             and (estado = 'anulada') = (reverso_id is not null)
                                             and (burden_reverso_id is not null) = (estado = 'anulada' and burden_asiento_id is not null)),
  constraint nomina_corridas_descarte check ((estado = 'descartada') = (descartada_el is not null)
                                             and (estado = 'descartada') = (coalesce(btrim(descartada_motivo), '') <> '')),
  constraint nomina_corridas_json     check (jsonb_typeof(descuadres) = 'array' and jsonb_typeof(columnas) = 'array'
                                             and jsonb_typeof(sin_clasificar) = 'array' and jsonb_typeof(avisos) = 'array'
                                             and jsonb_typeof(declara) = 'object')
);
-- (Lo que llegó después: «add column if not exists».)
--   firma_personas  la huella de SUS PERSONAS Y SUS CIFRAS: cuántas son y, de cada una, su bruto y su neto (sin sus
--                   nombres, en orden). La misma nómina bajada de Gusto con otras columnas (sin el desglose del bruto, sin la
--                   columna del tipo, con otro período dicho a mano) trae otra «firma» —sus conceptos son otros— pero ESTA
--                   huella es la misma: por ella se reconoce y no entra dos veces.
--   otra_porque     el porqué, escrito por Edgar, cuando una nómina que parece la misma que otra viva (las mismas personas con
--                   el mismo bruto y el mismo neto) de verdad es otra (dos bonos iguales el mismo día).
alter table public.nomina_corridas add column if not exists firma_personas text;
alter table public.nomina_corridas add column if not exists otra_porque text;
-- (una nómina, una corrida VIVA; las anuladas y las descartadas quedan como rastro)
create unique index if not exists nomina_corridas_llave_viva on public.nomina_corridas (llave) where estado in ('importada', 'posteada');
create index if not exists nomina_corridas_dia_idx on public.nomina_corridas (dia_pago);
create unique index if not exists nomina_corridas_asiento_unico on public.nomina_corridas (asiento_id) where asiento_id is not null;
comment on table public.nomina_corridas is 'c15: cada nómina (corrida) leída de un archivo: su día de pago (dia_pago: la fecha fiscal, la de los trimestres del 941, y la del asiento), su período de pago (lo trabajado: la clave del reparto por horas), su tipo (regular o fuera de ciclo, con el texto del archivo), su llave (qué nómina es: no entra dos veces), su firma (sus cifras, concepto por concepto) y la huella de sus personas (firma_personas: cuántas son y el bruto y el neto de cada una, para reconocer la misma nómina bajada con otras columnas; otra_porque: el porqué cuando una que parece la misma es otra), si se queda con las horas del período (toma_horas: las regulares sí), su estado (importada → posteada → anulada; o descartada), cuántas personas y sus totales del journal (bruto, impuestos del empleado, deducciones, neto, reembolsos, impuestos y beneficios del patrón, horas), lo que amarra con las declaraciones (declara), si cuadra al centavo y dónde no (descuadres), cómo se leyó cada columna (columnas), las columnas con cifras que el mapeo no conoce (sin_clasificar) y los totales que traía el archivo. Posteada: lo que fue al libro (plan), lo que Edgar vio (huella), lo que quedó por pagar en cada cuenta (pasivos: en positivo lo que se debe; en negativo lo que quedó a favor, cuando una corrección devuelve), su asiento y el del reparto del burden, quién y cuándo. Anulada: quién, cuándo, por qué y sus reversos. Nunca se borra.';
comment on column public.nomina_corridas.dia_pago is 'El día de pago («check date») que dice el ARCHIVO: es la fecha fiscal (941, 940, RT-6, W-2). El amarre con las declaraciones va por este día, no por la fecha del asiento (que es la misma salvo que su mes ya estuviera cerrado).';

-- Cada persona de una corrida, con sus totales, si cuadra, y lo que Edgar
-- decidió para ella en ESA corrida (sin horas: «sin obra», con su nota).
create table if not exists public.nomina_corrida_personas (
  corrida_id     uuid          not null references public.nomina_corridas (id),
  persona_id     uuid          not null references public.nomina_personas (id),
  n              int           not null,
  nombre         text          not null,
  metodo_pago    text,
  bruto          numeric(14,2) not null default 0,
  imp_empleado   numeric(14,2) not null default 0,
  deducciones    numeric(14,2) not null default 0,
  neto           numeric(14,2) not null default 0,
  reembolsos     numeric(14,2) not null default 0,
  imp_patron     numeric(14,2) not null default 0,
  ben_patron     numeric(14,2) not null default 0,
  horas          numeric,
  horas_fuera    numeric,
  neto_con_reembolso boolean   not null default false,
  cuadra         boolean       not null,
  descuadre      text,
  decision       text,
  decision_nota  text,
  decidido_el    timestamptz,
  decidido_por   uuid,
  constraint nomina_corrida_personas_pk       primary key (corrida_id, persona_id),
  constraint nomina_corrida_personas_decision check ((decision is null or decision = 'sin_obra')
                                                     and (decision is null) = (coalesce(btrim(decision_nota), '') = ''))
);
create index if not exists nomina_corrida_personas_persona_idx on public.nomina_corrida_personas (persona_id);
comment on table public.nomina_corrida_personas is 'c15: cada persona de una corrida: su nombre como lo trae el archivo, cómo se le pagó (metodo_pago), sus totales (bruto, impuestos suyos, deducciones, neto, reembolsos, impuestos y beneficios del patrón), sus horas según Gusto (trabajadas: horas; pagadas sin trabajar: horas_fuera), si su fila cuadra al centavo (bruto − impuestos − deducciones = neto) y, si no, dónde (descuadre); y lo que Edgar decidió para ella en esta corrida cuando tiene sueldo y ninguna hora aprobada en el período (decision: sin_obra, con su nota). Es lo que cobra cada persona: se lee solo con el código del teléfono.';

-- Las líneas del journal: por persona y concepto (solo lo que no es cero).
create table if not exists public.nomina_lineas (
  corrida_id   uuid          not null,
  persona_id   uuid          not null,
  concepto     text          not null,
  clase        text          not null,
  cuenta       text          references public.cuentas (codigo),
  declara      text,
  monto        numeric(14,2),
  horas        numeric,
  columna      text,
  constraint nomina_lineas_pk      primary key (corrida_id, persona_id, concepto),
  constraint nomina_lineas_persona foreign key (corrida_id, persona_id) references public.nomina_corrida_personas (corrida_id, persona_id),
  constraint nomina_lineas_clase   check (clase in ('bruto', 'imp_empleado', 'deduccion', 'neto', 'reembolso', 'imp_patron', 'ben_patron',
                                                    'horas', 'horas_fuera')),
  constraint nomina_lineas_valor   check ((clase in ('horas', 'horas_fuera')) = (horas is not null)
                                          and (clase in ('horas', 'horas_fuera')) = (monto is null))
);
comment on table public.nomina_lineas is 'c15: las líneas de cada corrida, por persona y concepto (el identificador de Gusto: regular_earnings, employee_federal_income_tax…), solo las que no son cero: su clase (bruto, imp_empleado, deduccion, neto, reembolso, imp_patron, ben_patron; horas y horas_fuera llevan horas, no dinero), la cuenta del libro a la que va (la del mapeo el día que se importó), con qué renglón de las declaraciones amarra, y el rótulo de la columna de donde salió. No se edita ni se borra. Se lee solo con el código del teléfono.';

-- EL REPARTO: lo que fue al libro de cada persona, por destino.
create table if not exists public.nomina_reparto (
  corrida_id   uuid          not null references public.nomina_corridas (id),
  n            int           not null,
  persona_id   uuid          not null references public.nomina_personas (id),
  clase        text          not null,
  destino      text          not null,
  cuenta       text          not null references public.cuentas (codigo),
  proyecto_id  text,
  co           text,
  horas        numeric,
  monto        numeric(14,2) not null,
  constraint nomina_reparto_pk      primary key (corrida_id, n),
  constraint nomina_reparto_clase   check (clase in ('bruto', 'patron')),
  constraint nomina_reparto_destino check (destino in ('obra', 'sin_obra', 'oficina', 'oficial')),
  constraint nomina_reparto_obra    check ((destino = 'obra') = (proyecto_id is not null) and (co is null or proyecto_id is not null)),
  constraint nomina_reparto_monto   check (monto <> 0)
);
create index if not exists nomina_reparto_obra_idx on public.nomina_reparto (proyecto_id) where proyecto_id is not null;
comment on table public.nomina_reparto is 'c15: el reparto de cada corrida posteada, por persona: cada parte de su bruto (clase bruto) y de lo que el patrón paga por ella (clase patron: impuestos y beneficios patronales) con su destino (obra: con su obra y su CO, por sus horas aprobadas del período; sin_obra: sus horas sin obra; oficial: lo del oficial que no es de obra; oficina), su cuenta, las horas del grupo y su monto. Lo de clase patron con destino obra entra a la bolsa del burden real y de ahí a cada obra en el asiento del reparto. La suma por persona es su bruto y su parte patronal, al centavo. No se edita ni se borra. Se lee solo con el código del teléfono.';

-- EL LOTE: qué reportes de horas (horas.id) se repartieron en qué corrida.
create table if not exists public.nomina_reparto_horas (
  corrida_id   uuid          not null references public.nomina_corridas (id),
  persona_id   uuid          not null references public.nomina_personas (id),
  horas_id     bigint        not null,
  usuario_id   uuid          not null,
  fecha        date          not null,
  proyecto_id  text,
  co           text,
  fase         text,
  horas        numeric       not null,
  bruto        numeric(14,2) not null default 0,
  patron       numeric(14,2) not null default 0,
  titular      boolean       not null,
  vivo         boolean       not null default true,
  constraint nomina_reparto_horas_pk    primary key (corrida_id, horas_id),
  constraint nomina_reparto_horas_horas check (horas > 0)
);
-- (una hora, una corrida que la paga: la que la «tiene» —titular— y sigue viva)
create unique index if not exists nomina_reparto_horas_una on public.nomina_reparto_horas (horas_id) where titular and vivo;
create index if not exists nomina_reparto_horas_hora_idx on public.nomina_reparto_horas (horas_id);
comment on table public.nomina_reparto_horas is 'c15: EL LOTE de cada corrida posteada: cada reporte de horas (horas.id, sin llave foránea: es de la app) que sirvió de clave del reparto, como estaba al repartir (persona, fecha, obra, CO, fase, horas), con la parte del bruto y de lo patronal que le tocó. titular: esa corrida es la que PAGA esa hora (una corrida regular se queda con las horas de su período; una fuera de ciclo las usa de clave sin quedárselas); vivo: la corrida no se ha anulado. Una hora tiene como mucho una corrida titular viva: ninguna hora se reparte dos veces. Lo único que cambia es vivo, al anular. Se lee solo con el código del teléfono.';

-- Los cargos de Gusto en el banco, casados con sus corridas.
create table if not exists public.nomina_pagos (
  id               uuid          primary key default gen_random_uuid(),
  movimiento_id    uuid          not null references public.movimientos_banco (id),
  clase            text          not null,
  fecha            date          not null,
  monto            numeric(14,2) not null,
  asiento_id       uuid          not null references public.asientos (id),
  estado           text          not null default 'aplicado',
  nota             text,
  creado_el        timestamptz   not null default clock_timestamp(),
  creado_por       uuid,
  deshecho_el      timestamptz,
  deshecho_por     uuid,
  deshecho_motivo  text,
  reverso_id       uuid          references public.asientos (id),
  constraint nomina_pagos_clase    check (clase in ('nomina', 'cuota', 'fuera')),
  constraint nomina_pagos_monto    check (monto <> 0),
  constraint nomina_pagos_estado   check (estado in ('aplicado', 'deshecho')),
  constraint nomina_pagos_deshecho check ((estado = 'deshecho') = (deshecho_el is not null)
                                          and (estado = 'deshecho') = (coalesce(btrim(deshecho_motivo), '') <> ''))
);
create unique index if not exists nomina_pagos_movimiento_vivo on public.nomina_pagos (movimiento_id) where estado = 'aplicado';
create unique index if not exists nomina_pagos_asiento_unico on public.nomina_pagos (asiento_id);
comment on table public.nomina_pagos is 'c15: cada movimiento del banco resuelto desde la nómina: el movimiento, su clase (nomina: un cargo de Gusto que paga lo que una o varias corridas dejaron por pagar, o una devolución de Gusto que baja lo que quedó a favor; fuera: un pago que NO es de Gusto —el cheque de papel de alguien, una deducción que se le paga a un tercero— casado con lo que una corrida dejó por pagar, con su nota; cuota: la cuota mensual de Gusto, que no es nómina y va a su gasto), su fecha y su monto (lo que salió del banco, en positivo; una devolución, en negativo), el asiento que puso el banco (c6) al clasificarlo, su estado (aplicado o deshecho), quién y cuándo; y, deshecho, por quién, cuándo, por qué y el reverso. Un movimiento, un pago vivo. Solo se añade; lo único que cambia es el paso a deshecho.';

create table if not exists public.nomina_pago_partes (
  pago_id     uuid          not null references public.nomina_pagos (id),
  n           int           not null,
  corrida_id  uuid          not null references public.nomina_corridas (id),
  cuenta      text          not null references public.cuentas (codigo),
  monto       numeric(14,2) not null,
  constraint nomina_pago_partes_pk    primary key (pago_id, n),
  constraint nomina_pago_partes_monto check (monto <> 0)
);
-- (En una base que ya tenía estas dos tablas con las reglas de antes —solo importes positivos, sin la clase «fuera»—, se
-- cambian aquí; si ya son las de ahora, no se toca nada.)
do $$
declare
  r record;
begin
  for r in select * from (values ('nomina_pagos', 'nomina_pagos_monto', '%<>%', 'check (monto <> 0)'),
                                 ('nomina_pagos', 'nomina_pagos_clase', '%fuera%', 'check (clase in (''nomina'', ''cuota'', ''fuera''))'),
                                 ('nomina_pago_partes', 'nomina_pago_partes_monto', '%<>%', 'check (monto <> 0)')) as x(t, c, marca, d) loop
    if not exists (select 1 from pg_constraint k
                    where k.conrelid = ('public.' || r.t)::regclass and k.conname = r.c and pg_get_constraintdef(k.oid) like r.marca) then
      execute format('alter table public.%I drop constraint if exists %I', r.t, r.c);
      execute format('alter table public.%I add constraint %I %s', r.t, r.c, r.d);
    end if;
  end loop;
end $$;
create index if not exists nomina_pago_partes_corrida_idx on public.nomina_pago_partes (corrida_id);
comment on table public.nomina_pago_partes is 'c15: las partes de cada cargo de Gusto casado: qué corrida y qué cuenta por pagar (2210 el neto y los reembolsos, 2220 el 941, 2225 el FUTA, 2230 el reempleo de Florida, 2240 las deducciones) paga, y cuánto (en positivo lo que paga; en negativo lo que descuenta de lo que una corrección dejó a favor, o lo que devuelve). Un cargo puede pagar varias cuentas de una corrida o de varias; una corrida se paga con uno o con varios cargos. Las partes de un cargo suman el cargo, al centavo. No se edita ni se borra.';

-- Lo que Gusto presentó: los totales de cada 941, 940 y RT-6, tecleados.
create table if not exists public.nomina_declaraciones (
  id              uuid          primary key default gen_random_uuid(),
  forma           text          not null,
  anio            int           not null,
  trimestre       int,
  salarios        numeric(14,2),
  retencion       numeric(14,2),
  ss_medicare     numeric(14,2),
  futa            numeric(14,2),
  contribucion    numeric(14,2),
  presentada_el   date,
  confirmacion    text,
  nota            text,
  vigente         boolean       not null default true,
  registrada_el   timestamptz   not null default clock_timestamp(),
  registrada_por  uuid,
  sustituida_el   timestamptz,
  constraint nomina_declaraciones_forma check (forma in ('941', '940', 'rt6')),
  constraint nomina_declaraciones_anio  check (anio between 2026 and 2999),
  constraint nomina_declaraciones_trim  check ((forma = '940') = (trimestre is null) and (trimestre is null or trimestre between 1 and 4)),
  constraint nomina_declaraciones_vig   check (vigente = (sustituida_el is null))
);
create unique index if not exists nomina_declaraciones_vigente on public.nomina_declaraciones (forma, anio, coalesce(trimestre, 0)) where vigente;
comment on table public.nomina_declaraciones is 'c15: los totales de cada declaración de nómina que presentó Gusto, tecleados por Edgar: el 941 de un trimestre (salarios, retención federal, Social Security y Medicare —las dos mitades—), el 940 de un año (salarios, FUTA) y el RT-6 de Florida de un trimestre (salarios, contribución), con su fecha, su confirmación y una nota. La base los compara con lo posteado por día de pago (el amarre). Corregir una es teclearla otra vez: la anterior deja de estar vigente y queda como rastro. Nada de aquí postea.';

-- Las horas que se le pasan a Gusto: el lote de un período.
create table if not exists public.nomina_lotes (
  id                 uuid        primary key default gen_random_uuid(),
  desde              date        not null,
  hasta              date        not null,
  semana_empieza     int         not null,
  horas_extra_desde  numeric     not null,
  personas           int         not null,
  horas              numeric     not null,
  regulares          numeric     not null,
  extra              numeric     not null,
  semanas            jsonb       not null default '[]'::jsonb,
  huella             text        not null,
  vigente            boolean     not null default true,
  nota               text,
  creado_el          timestamptz not null default clock_timestamp(),
  creado_por         uuid,
  sustituido_el      timestamptz,
  constraint nomina_lotes_fechas check (desde <= hasta and hasta - desde <= 92),
  constraint nomina_lotes_semanas check (jsonb_typeof(semanas) = 'array'),
  constraint nomina_lotes_vig    check (vigente = (sustituido_el is null))
);
create unique index if not exists nomina_lotes_vigente on public.nomina_lotes (desde, hasta) where vigente;
comment on table public.nomina_lotes is 'c15: cada lote de horas aprobadas de un período que Edgar pasó a Gusto: el período, el día en que empieza la semana laboral y desde cuántas horas son extra (como estaban al armarlo), cuántas personas, las horas (total, regulares y extra), su huella, quién y cuándo. Armar otra vez el mismo período deja el anterior como rastro. Si después cambia una hora del lote, o se aprueba una nueva de ese período, el control lo avisa.';

create table if not exists public.nomina_lote_horas (
  lote_id      uuid     not null references public.nomina_lotes (id),
  horas_id     bigint   not null,
  usuario_id   uuid     not null,
  fecha        date     not null,
  semana       date     not null,
  proyecto_id  text,
  co           text,
  horas        numeric  not null,
  constraint nomina_lote_horas_pk primary key (lote_id, horas_id)
);
create index if not exists nomina_lote_horas_hora_idx on public.nomina_lote_horas (horas_id);
comment on table public.nomina_lote_horas is 'c15: los reportes de horas de cada lote que se pasó a Gusto, como estaban entonces (persona, fecha, la semana laboral en que cae, obra, CO y horas). No se edita ni se borra.';

-- Quién cambió qué (la configuración, el mapeo, las personas, las
-- decisiones, las declaraciones).
create table if not exists public.nomina_historial (
  id         uuid        primary key default gen_random_uuid(),
  que        text        not null,
  ref        text,
  antes      jsonb,
  despues    jsonb,
  hecho_el   timestamptz not null default clock_timestamp(),
  hecho_por  uuid,
  constraint nomina_historial_que check (que in ('config', 'columna', 'columna_fuera', 'persona', 'decision', 'corrida', 'declaracion'))
);
create index if not exists nomina_historial_que_idx on public.nomina_historial (que, hecho_el);
comment on table public.nomina_historial is 'c15: cada cambio a la configuración de la nómina, al mapeo de las columnas, a una persona (su enlace, su clase, su confirmación), a una decisión de una corrida, al período de una corrida o a una declaración: qué decía antes y qué dice después, quién y cuándo. Solo se añade. No lleva lo que cobra nadie.';


-- ---------------------------------------------------------------------
-- 3. La guarda de las tablas de c15 (la de c6, c9, c10, c12 y c14, en su
--    forma): solo se escriben con la marca de la transacción
--    (mx_nomina.escribe = el nombre de la tabla), que ponen las funciones de
--    aquí justo antes de escribir y quitan después. A mano —desde PostgREST,
--    aunque sea el dueño, o desde el SQL Editor sin la marca— da MX003. Lo
--    que es rastro no se edita ni se borra, y una corrida solo avanza:
--    importada → posteada → anulada, o importada → descartada. SECURITY
--    INVOKER, sin grant a nadie (la dispara la tabla).
-- ---------------------------------------------------------------------
create or replace function public.fn_nomina_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_marca  text := coalesce(current_setting('mx_nomina.escribe', true), '');
  v_libres text[];
  v_o      jsonb;
  v_n      jsonb;
  v_est    text;
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003',
      message = format('%s no se trunca: es la nómina y su rastro.', tg_table_name);
  end if;
  if tg_op = 'DELETE' and tg_table_name <> 'nomina_columnas' then
    raise exception using errcode = 'MX003',
      message = format('%s no se borra: %s', tg_table_name,
                       case tg_table_name
                         when 'nomina_config' then 'es la configuración (una fila); se cambia desde Contabilidad → Nómina.'
                         when 'nomina_corridas' then 'una corrida importada por error se descarta, y una posteada se anula (su asiento se reversa); las dos quedan.'
                         when 'nomina_personas' then 'una persona se da de baja (activo = no) y su historia queda.'
                         when 'nomina_pagos' then 'un cargo mal casado se deshace con su motivo y queda.'
                         when 'nomina_declaraciones' then 'una declaración se corrige tecleándola otra vez; la anterior queda.'
                         else 'es rastro.' end);
  end if;
  if v_marca <> tg_table_name then
    raise exception using errcode = 'MX003',
      message = format('%s se escribe solo desde la pantalla de Nómina (sus funciones), no a mano.', tg_table_name);
  end if;
  if tg_op = 'DELETE' then
    if (to_jsonb(old)->>'de_fabrica')::boolean then
      raise exception using errcode = 'MX003',
        message = 'Una columna de fábrica del mapeo no se quita: se cambia (a qué concepto, clase o cuenta va), o se deja en «ignorar».';
    end if;
    return old;
  end if;
  if tg_op = 'INSERT' then
    if tg_table_name in ('nomina_lineas', 'nomina_corrida_personas') then
      select c.estado into v_est from public.nomina_corridas c where c.id = (to_jsonb(new)->>'corrida_id')::uuid;
      if v_est is distinct from 'importada' then
        raise exception using errcode = 'MX003', message = format('%s: las líneas de una corrida entran con ella, al importarla.', tg_table_name);
      end if;
    end if;
    return new;
  end if;
  -- UPDATE
  v_o := to_jsonb(old);
  v_n := to_jsonb(new);
  if tg_table_name in ('nomina_archivos', 'nomina_lineas', 'nomina_reparto', 'nomina_pago_partes', 'nomina_lote_horas', 'nomina_historial') then
    raise exception using errcode = 'MX003', message = format('%s no se edita: es rastro.', tg_table_name);
  elsif tg_table_name = 'nomina_corridas' then
    -- (la huella de sus personas, a una corrida de antes de que existiera: se le pone UNA vez, al pegar; es lo que ya traía)
    if v_o->>'firma_personas' is null and v_n->>'firma_personas' is not null
       and (v_n - 'firma_personas') is not distinct from (v_o - 'firma_personas') then
      return new;
    end if;
    if v_o->>'estado' in ('anulada', 'descartada') then
      raise exception using errcode = 'MX003',
        message = format('Una corrida %s ya no cambia: queda como rastro. Si hace falta, se vuelve a subir su archivo.', v_o->>'estado');
    end if;
    v_libres := case
      when v_o->>'estado' = 'posteada' and v_n->>'estado' = 'anulada'
        then array['estado', 'anulada_el', 'anulada_por', 'anulada_motivo', 'reverso_id', 'burden_reverso_id']
      when v_o->>'estado' = 'importada' and v_n->>'estado' = 'posteada'
        then array['estado', 'plan', 'huella', 'pasivos', 'asiento_id', 'asiento_numero', 'fecha_asiento', 'burden_asiento_id',
                   'posteada_el', 'posteada_por']
      when v_o->>'estado' = 'importada' and v_n->>'estado' = 'descartada'
        then array['estado', 'descartada_el', 'descartada_por', 'descartada_motivo']
      when v_o->>'estado' = 'importada' and v_n->>'estado' = 'importada'
        then array['periodo_desde', 'periodo_hasta', 'toma_horas', 'llave', 'avisos', 'otra_porque']
      else null end;
    if v_libres is null then
      raise exception using errcode = 'MX003',
        message = format('Una corrida no pasa de %s a %s: se importa, se postea y, si estaba mal, se anula (o se descarta antes de postearla).',
                         v_o->>'estado', v_n->>'estado');
    end if;
    if (v_n - v_libres) is distinct from (v_o - v_libres) then
      raise exception using errcode = 'MX003',
        message = 'Lo que una corrida trajo de su archivo (su día de pago, sus totales, cómo se leyó) no se edita: si estaba mal, se '
                  'descarta o se anula y se vuelve a subir el archivo.';
    end if;
  elsif tg_table_name = 'nomina_corrida_personas' then
    v_libres := array['decision', 'decision_nota', 'decidido_el', 'decidido_por'];
    if (v_n - v_libres) is distinct from (v_o - v_libres) then
      raise exception using errcode = 'MX003', message = 'Lo que una persona trajo en una corrida no se edita: solo lo que Edgar decide para ella.';
    end if;
    select c.estado into v_est from public.nomina_corridas c where c.id = old.corrida_id;
    if v_est is distinct from 'importada' then
      raise exception using errcode = 'MX003', message = 'Una decisión se toma antes de postear la corrida: ya posteada, no cambia.';
    end if;
  elsif tg_table_name = 'nomina_reparto_horas' then
    if (v_n - array['vivo']) is distinct from (v_o - array['vivo']) or not (old.vivo and not new.vivo) then
      raise exception using errcode = 'MX003', message = 'El lote de una corrida no se edita: solo deja de estar vivo, una vez, al anularla.';
    end if;
  elsif tg_table_name = 'nomina_pagos' then
    v_libres := array['estado', 'deshecho_el', 'deshecho_por', 'deshecho_motivo', 'reverso_id'];
    if (v_n - v_libres) is distinct from (v_o - v_libres) or not (old.estado = 'aplicado' and new.estado = 'deshecho') then
      raise exception using errcode = 'MX003', message = 'Un cargo casado no se edita: solo queda deshecho, una vez, con su motivo.';
    end if;
  elsif tg_table_name = 'nomina_declaraciones' then
    v_libres := array['vigente', 'sustituida_el'];
    if (v_n - v_libres) is distinct from (v_o - v_libres) or not (old.vigente and not new.vigente) then
      raise exception using errcode = 'MX003', message = 'Una declaración tecleada no se edita: se teclea otra vez y la anterior queda como rastro.';
    end if;
  elsif tg_table_name = 'nomina_lotes' then
    v_libres := array['vigente', 'sustituido_el'];
    if (v_n - v_libres) is distinct from (v_o - v_libres) or not (old.vigente and not new.vigente) then
      raise exception using errcode = 'MX003', message = 'Un lote de horas no se edita: se arma otro y el anterior queda como rastro.';
    end if;
  elsif tg_table_name = 'nomina_personas' then
    if v_n->>'id' is distinct from v_o->>'id' or v_n->>'clave' is distinct from v_o->>'clave' then
      raise exception using errcode = 'MX003', message = 'nomina_personas: su llave y su clave no cambian.';
    end if;
  elsif tg_table_name = 'nomina_columnas' then
    if v_n->>'alias' is distinct from v_o->>'alias' or v_n->>'de_fabrica' is distinct from v_o->>'de_fabrica' then
      raise exception using errcode = 'MX003', message = 'nomina_columnas: el nombre de una columna del mapeo no cambia (se añade otra).';
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.fn_nomina_guarda() from public, anon, authenticated, service_role;
comment on function public.fn_nomina_guarda() is 'c15: la guarda de las tablas de c15: se escriben solo con la marca de la transacción (mx_nomina.escribe) que ponen sus funciones; una corrida solo avanza (importada → posteada → anulada, o importada → descartada) y lo que trajo de su archivo no se edita; las líneas, el reparto, los archivos, las partes de un pago y el historial no se editan; el lote solo deja de estar vivo; un pago solo queda deshecho; una declaración y un lote de horas solo quedan sustituidos; y nada se borra (salvo una columna del mapeo que no es de fábrica).';

do $$
declare
  t text;
begin
  foreach t in array array['nomina_config', 'nomina_columnas', 'nomina_personas', 'nomina_archivos', 'nomina_corridas',
                           'nomina_corrida_personas', 'nomina_lineas', 'nomina_reparto', 'nomina_reparto_horas', 'nomina_pagos',
                           'nomina_pago_partes', 'nomina_declaraciones', 'nomina_lotes', 'nomina_lote_horas', 'nomina_historial'] loop
    execute format('create or replace trigger trg_%s_guarda before insert or update or delete on public.%I '
                   'for each row execute function public.fn_nomina_guarda()', t, t);
    execute format('create or replace trigger trg_%s_sin_truncate before truncate on public.%I '
                   'for each statement execute function public.fn_nomina_guarda()', t, t);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 4. Los permisos: RLS. El dueño lee; LO QUE LLEVA DINERO DE UNA NÓMINA (la
--    corrida con sus totales, sus descuadres, sus avisos y su asiento; lo de
--    cada persona: sus totales, sus líneas, su reparto, su lote; y los
--    cargos casados con sus partes), solo con el código del teléfono (aal2):
--    una nómina de una sola persona —un bono— ES lo que cobró esa persona, y
--    los descuadres y los avisos de una corrida nombran a su gente con sus
--    cifras. Sin el código, el dueño lee la configuración, el mapeo, las
--    personas (sin dinero), los archivos, las declaraciones, los lotes de
--    horas y el historial. Escribe el dueño, con su código, por las
--    funciones de aquí (la policy dice quién; la marca de la guarda, por
--    dónde). anon y service_role, ningún privilegio: service_role se salta
--    las policies, y lo que lo para es no tener grant.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  p record;
  c_todas    constant text[] := array['nomina_config', 'nomina_columnas', 'nomina_personas', 'nomina_archivos', 'nomina_corridas',
                                      'nomina_corrida_personas', 'nomina_lineas', 'nomina_reparto', 'nomina_reparto_horas', 'nomina_pagos',
                                      'nomina_pago_partes', 'nomina_declaraciones', 'nomina_lotes', 'nomina_lote_horas', 'nomina_historial'];
  c_personas constant text[] := array['nomina_corridas', 'nomina_corrida_personas', 'nomina_lineas', 'nomina_reparto', 'nomina_reparto_horas',
                                      'nomina_pagos', 'nomina_pago_partes'];
  c_edita    constant text[] := array['nomina_config', 'nomina_columnas', 'nomina_personas', 'nomina_corridas', 'nomina_corrida_personas',
                                      'nomina_reparto_horas', 'nomina_pagos', 'nomina_declaraciones', 'nomina_lotes'];
  c_codigo   constant text   := '(select es_dueno()) and (select auth.jwt() ->> ''aal'') = ''aal2''';
begin
  foreach t in array c_todas loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    if t = any (c_personas) then
      execute format('create policy %I on public.%I for select to authenticated using (%s)', t || '_dueno_codigo', t, c_codigo);
    else
      execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    end if;
    execute format('grant select on public.%I to authenticated', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (%s)', t || '_dueno_anade', t, c_codigo);
    execute format('grant insert on public.%I to authenticated', t);
    if t = any (c_edita) then
      execute format('create policy %I on public.%I for update to authenticated using (%s) with check (%s)', t || '_dueno_edita', t,
                     c_codigo, c_codigo);
      execute format('grant update on public.%I to authenticated', t);
    end if;
  end loop;
  execute format('create policy nomina_columnas_dueno_quita on public.nomina_columnas for delete to authenticated using (%s)', c_codigo);
  grant delete on public.nomina_columnas to authenticated;
end $$;

-- La fila de la configuración (con la marca de la guarda): al volver a pegar
-- no se pisa nada.
do $$
begin
  if not exists (select 1 from public.nomina_config where id = 1) then
    perform set_config('mx_nomina.escribe', 'nomina_config', true);
    insert into public.nomina_config (id) values (1);
    perform set_config('mx_nomina.escribe', '', true);
  end if;
end $$;

-- La huella de las personas (firma_personas) de las corridas que entraron
-- antes de que existiera: se calcula UNA vez, de lo que ya traían (cuántas
-- personas y el bruto y el neto de cada una). La guarda lo deja pasar solo
-- así: de vacío a su valor, sin tocar nada más.
do $$
begin
  if exists (select 1 from public.nomina_corridas where firma_personas is null) then
    perform set_config('mx_nomina.escribe', 'nomina_corridas', true);
    update public.nomina_corridas c
       set firma_personas = (select count(*) || ':' || md5(coalesce(string_agg(round(cp.bruto, 2) || ':' || round(cp.neto, 2), ','
                                                                               order by cp.bruto, cp.neto), ''))
                               from public.nomina_corrida_personas cp where cp.corrida_id = c.id)
     where c.firma_personas is null;
    perform set_config('mx_nomina.escribe', '', true);
  end if;
end $$;

-- EL MAPEO DE FÁBRICA: los nombres de las 86 columnas del informe «Payroll
-- journal» de Gusto (los identificadores de su motor de informes, leídos de
-- su SDK público) y los rótulos que se le conocen o se le suponen a la
-- pantalla (el identificador con espacios; «Pay date», «Gross pay»…). NO
-- está comprobado contra un archivo real: por eso todo va por nombre, se
-- amplía con fn_nomina_columna, y lo que no esté aquí y traiga cifras frena
-- la corrida en vez de perderse. Lo que ya está en la tabla no se pisa
-- (Edgar pudo cambiarlo).
do $$
begin
  perform set_config('mx_nomina.escribe', 'nomina_columnas', true);
  insert into public.nomina_columnas (alias, concepto, clase, cuenta, declara, de_fabrica, nota)
  select public.fn_nomina_norm(v.alias), v.concepto, v.clase, v.cuenta, v.declara, true, v.nota
    from (values
      -- la nómina: su llave, su tipo y sus fechas
      ('payroll uuid', 'payroll_uuid', 'llave', null, null, null),
      ('payroll id', 'payroll_uuid', 'llave', null, null, null),
      ('payroll type', 'payroll_type', 'tipo', null, null, 'Regular, o fuera de ciclo (bonus, correction, off-cycle…)'),
      ('check date', 'check_date', 'dia_pago', null, null, 'El día de pago: la fecha fiscal y la del asiento'),
      ('pay date', 'check_date', 'dia_pago', null, null, null),
      ('payday', 'check_date', 'dia_pago', null, null, null),
      ('pay day', 'check_date', 'dia_pago', null, null, null),
      ('pay period start', 'pay_period_start', 'periodo_desde', null, null, null),
      ('pay period start date', 'pay_period_start', 'periodo_desde', null, null, null),
      ('period start', 'pay_period_start', 'periodo_desde', null, null, null),
      ('pay period end', 'pay_period_end', 'periodo_hasta', null, null, null),
      ('pay period end date', 'pay_period_end', 'periodo_hasta', null, null, null),
      ('period end', 'pay_period_end', 'periodo_hasta', null, null, null),
      ('pay period', 'pay_period', 'periodo', null, null, 'El período de pago en una sola celda (del … al …)'),
      ('payroll period', 'pay_period', 'periodo', null, null, null),
      -- la persona
      ('employee first name', 'employee_first_name', 'nombre', null, null, null),
      ('first name', 'employee_first_name', 'nombre', null, null, null),
      ('employee last name', 'employee_last_name', 'apellido', null, null, null),
      ('last name', 'employee_last_name', 'apellido', null, null, null),
      ('employee middle initial', 'employee_middle_initial', 'segundo', null, null, null),
      ('middle initial', 'employee_middle_initial', 'segundo', null, null, null),
      ('preferred first name', 'preferred_first_name', 'ignorar', null, null, null),
      ('employee', 'employee_name', 'nombre_completo', null, null, null),
      ('employee name', 'employee_name', 'nombre_completo', null, null, null),
      ('name', 'employee_name', 'nombre_completo', null, null, null),
      ('employee uuid', 'employee_uuid', 'empleado_id', null, null, null),
      ('employee id', 'employee_uuid', 'empleado_id', null, null, null),
      ('gusto employee id', 'employee_uuid', 'empleado_id', null, null, null),
      ('payment method', 'payment_method', 'metodo_pago', null, null, 'Direct Deposit o Check: el neto pagado con cheque no lo cobra Gusto'),
      -- lo que no se postea ni hace falta
      ('employee department', 'employee_department', 'ignorar', null, null, null),
      ('department', 'employee_department', 'ignorar', null, null, null),
      ('job title', 'job_title', 'ignorar', null, null, null),
      ('title', 'job_title', 'ignorar', null, null, null),
      ('employment', 'employment', 'ignorar', null, null, null),
      ('employment type', 'employment_type', 'ignorar', null, null, null),
      ('start date', 'start_date', 'ignorar', null, null, null),
      ('end date', 'end_date', 'ignorar', null, null, null),
      ('risk class code', 'risk_class_code', 'ignorar', null, null, 'La clase de riesgo de WC'),
      ('work address', 'work_address', 'ignorar', null, null, null),
      ('work address city', 'work_address_city', 'ignorar', null, null, null),
      ('work address state', 'work_address_state', 'ignorar', null, null, null),
      ('work address street', 'work_address_street', 'ignorar', null, null, null),
      ('work address zip', 'work_address_zip', 'ignorar', null, null, null),
      ('employee compensation', 'employee_compensation', 'ignorar', null, null, 'Una tarifa: no se postea'),
      ('employee compensation time period', 'employee_compensation_time_period', 'ignorar', null, null, null),
      ('regular rate', 'regular_rate', 'ignorar', null, null, 'Una tarifa: no se postea'),
      ('overtime rate', 'overtime_rate', 'ignorar', null, null, 'Una tarifa: no se postea'),
      ('double overtime rate', 'double_overtime_rate', 'ignorar', null, null, 'Una tarifa: no se postea'),
      ('paid time off rate', 'paid_time_off_rate', 'ignorar', null, null, 'Una tarifa: no se postea'),
      ('sick rate', 'sick_rate', 'ignorar', null, null, 'Una tarifa: no se postea'),
      -- las horas (nunca dinero)
      ('regular hours', 'regular_hours', 'horas', null, null, null),
      ('overtime hours', 'overtime_hours', 'horas', null, null, null),
      ('double overtime hours', 'double_overtime_hours', 'horas', null, null, null),
      ('paid time off hours', 'paid_time_off_hours', 'horas_fuera', null, null, 'Pagadas sin trabajar'),
      ('sick time off hours', 'sick_time_off_hours', 'horas_fuera', null, null, 'Pagadas sin trabajar'),
      ('holiday hours', 'holiday_hours', 'horas_fuera', null, null, 'Pagadas sin trabajar'),
      ('total time off hours', 'total_time_off_hours', 'ignorar', null, null, 'Un total: no se suma'),
      ('total hours', 'total_hours', 'ignorar', null, null, 'Un total: no se suma'),
      -- el bruto, parte por parte
      ('regular earnings', 'regular_earnings', 'bruto', null, null, null),
      ('overtime earnings', 'overtime_earnings', 'bruto', null, null, null),
      ('double overtime earnings', 'double_overtime_earnings', 'bruto', null, null, null),
      ('bonus', 'bonus', 'bruto', null, null, null),
      ('commission', 'commission', 'bruto', null, null, null),
      ('paycheck tips', 'paycheck_tips', 'bruto', null, null, null),
      ('cash tips', 'cash_tips', 'bruto', null, null, 'Propinas en efectivo: Gusto las resta del neto. Si alguna vez traen dinero, la fila no cuadra y se dice'),
      ('additional earnings', 'additional_earnings', 'bruto', null, null, null),
      ('paid time off earnings', 'paid_time_off_earnings', 'bruto', null, null, null),
      ('sick time off earnings', 'sick_time_off_earnings', 'bruto', null, null, null),
      ('holiday earnings', 'holiday_earnings', 'bruto', null, null, null),
      ('total time off earnings', 'total_time_off_earnings', 'ignorar', null, null, 'Un total de partes que ya están: no se suma'),
      ('gross earnings', 'gross_earnings', 'bruto_total', null, null, 'El bruto: control de sus partes (o el bruto mismo, si el archivo no trae sus partes)'),
      ('gross pay', 'gross_earnings', 'bruto_total', null, null, null),
      ('gross wages', 'gross_earnings', 'bruto_total', null, null, null),
      -- lo que se le retiene al empleado: todo al 941 (2220)
      ('employee federal income tax', 'employee_federal_income_tax', 'imp_empleado', '2220', 'fit', null),
      ('federal income tax', 'employee_federal_income_tax', 'imp_empleado', '2220', 'fit', null),
      ('employee social security tax', 'employee_social_security_tax', 'imp_empleado', '2220', 'ss_ee', null),
      ('employee medicare tax', 'employee_medicare_tax', 'imp_empleado', '2220', 'med_ee', null),
      ('employee medicare additional tax', 'employee_medicare_additional_tax', 'imp_empleado', '2220', 'med_adic', null),
      ('employee additional medicare tax', 'employee_medicare_additional_tax', 'imp_empleado', '2220', 'med_adic', null),
      ('employee state income tax', 'employee_state_income_tax', 'imp_empleado', null, null, 'Florida no tiene impuesto estatal sobre el sueldo: sin cuenta a propósito. Si trae dinero, la corrida se frena'),
      ('employee taxes', 'employee_taxes', 'imp_empleado_total', '2220', null, 'El total de lo retenido: control (o lo retenido mismo, si no viene el detalle)'),
      ('total employee taxes', 'employee_taxes', 'imp_empleado_total', '2220', null, null),
      -- las deducciones
      ('employee deductions', 'employee_deductions', 'deduccion', '2240', null, null),
      ('employee benefit contributions', 'employee_benefit_contributions', 'deduccion', '2240', null, null),
      ('garnishments', 'garnishments', 'deduccion', '2240', null, 'Embargos y manutención'),
      ('employee donations', 'employee_donations', 'deduccion', '2240', null, null),
      ('total employee deductions', 'total_employee_deductions', 'deduccion_total', '2240', null, 'Un total: control'),
      -- el neto, el cheque y los reembolsos
      ('net pay', 'net_pay', 'neto', '2210', null, 'Lo que Gusto deposita a la gente: es lo que casa con su cargo del neto'),
      ('check amount', 'check_amount', 'cheque_total', null, null, 'Neto más reembolsos: control'),
      ('reimbursements', 'reimbursements', 'reembolso_total', '2250', null, 'El total de los reembolsos (o el reembolso mismo, si no viene partido)'),
      ('one time reimbursements', 'one_time_reimbursements', 'reembolso', '2250', null, null),
      ('recurring reimbursements', 'recurring_reimbursements', 'reembolso', '2250', null, null),
      -- lo que pone el patrón
      ('employer social security tax', 'employer_social_security_tax', 'imp_patron', '2220', 'ss_er', null),
      ('employer medicare tax', 'employer_medicare_tax', 'imp_patron', '2220', 'med_er', null),
      ('employer futa tax', 'employer_futa_tax', 'imp_patron', '2225', 'futa', 'El FUTA (940)'),
      ('employer suta tax', 'employer_suta_tax', 'imp_patron', '2230', 'suta', 'El reempleo de Florida (RT-6)'),
      ('employer taxes', 'employer_taxes', 'imp_patron_total', null, null, 'Un total: control. Solo, sin su detalle, no se puede postear (el FUTA y el reempleo van a cuentas distintas)'),
      ('total employer taxes', 'employer_taxes', 'imp_patron_total', null, null, null),
      ('employer benefit contributions', 'employer_benefit_contributions', 'ben_patron', null, null, 'Sin cuenta hasta que haya un beneficio: se dice a cuál va con el primero'),
      ('total employer benefit contributions', 'total_employer_benefit_contributions', 'ben_patron_total', null, null, 'Un total: control'),
      ('total employer contributions', 'total_employer_benefit_contributions', 'ben_patron_total', null, null, 'Un total: control'),
      ('employer cost', 'employer_cost', 'costo_total', null, null, 'Un total: solo se compara, como aviso'),
      ('total employer cost', 'employer_cost', 'costo_total', null, null, null),
      -- LO DELICADO: no se guarda nunca
      ('bank account account number', 'bank_account_account_number', 'delicado', null, null, null),
      ('bank account routing number', 'bank_account_routing_number', 'delicado', null, null, null),
      ('bank account type', 'bank_account_type', 'delicado', null, null, null),
      ('bank account', 'bank_account', 'delicado', null, null, null),
      ('account number', 'bank_account_account_number', 'delicado', null, null, null),
      ('routing number', 'bank_account_routing_number', 'delicado', null, null, null),
      ('date of birth', 'date_of_birth', 'delicado', null, null, null),
      ('birth date', 'date_of_birth', 'delicado', null, null, null),
      ('dob', 'date_of_birth', 'delicado', null, null, null),
      ('home address', 'home_address', 'delicado', null, null, null),
      ('home address city', 'home_address_city', 'delicado', null, null, null),
      ('home address state', 'home_address_state', 'delicado', null, null, null),
      ('home address street', 'home_address_street', 'delicado', null, null, null),
      ('home address zip', 'home_address_zip', 'delicado', null, null, null),
      ('employee email', 'employee_email', 'delicado', null, null, null),
      ('employee work email', 'employee_work_email', 'delicado', null, null, null),
      ('email', 'employee_email', 'delicado', null, null, null),
      ('work email', 'employee_work_email', 'delicado', null, null, null),
      ('personal email', 'employee_email', 'delicado', null, null, null),
      ('employee phone number', 'employee_phone_number', 'delicado', null, null, null),
      ('phone number', 'employee_phone_number', 'delicado', null, null, null),
      ('phone', 'employee_phone_number', 'delicado', null, null, null),
      ('ssn', 'ssn', 'delicado', null, null, null),
      ('employee ssn', 'ssn', 'delicado', null, null, null),
      ('social security number', 'ssn', 'delicado', null, null, null),
      ('employee social security number', 'ssn', 'delicado', null, null, null),
      ('tin', 'ssn', 'delicado', null, null, null)
    ) as v(alias, concepto, clase, cuenta, declara, nota)
   where (v.cuenta is null or exists (select 1 from public.cuentas k where k.codigo = v.cuenta))
  on conflict (alias) do nothing;
  perform set_config('mx_nomina.escribe', '', true);
end $$;


-- ---------------------------------------------------------------------
-- 5. Las cuentas: cuál sirve para qué, las que usa la nómina hoy, y la
--    fecha con que entra un asiento.
-- ---------------------------------------------------------------------
-- ¿Sirve esta cuenta para este uso? Nulo = sí; si no, el porqué en llano.
--   pasivo        lo que se queda debiendo (lo retenido, los impuestos del
--                 patrón, las deducciones, el neto) y los reembolsos que se
--                 le devuelven a un empleado: una cuenta de pasivo sin obra
--   sueldo        el sueldo de oficina y el del oficial: un gasto sin obra
--   sin_obra      las horas sin obra de la gente de campo: un costo o un
--                 gasto que no exija obra y que no sea del bloque 50xx
--   bolsa         la bolsa del burden real: del bloque 50xx y sin obra
--   burden_obra   el burden por obra: del bloque 50xx y con obra
--   burden_admin  el burden de oficina: un gasto sin obra
--   cuota         la cuota de Gusto: un gasto sin obra que el banco deje
--                 clasificar (ni 50xx ni sueldo)
create or replace function public.fn_nomina_cuenta_mal(p_cuenta text, p_uso text) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select case when p_cuenta is null then 'falta la cuenta'
              when c.codigo is null then format('la cuenta %s no existe en el plan de cuentas', p_cuenta)
              when not c.activa then format('la cuenta %s (%s) está inactiva: ya no recibe asientos', c.codigo, c.nombre)
              when not c.imputable then format('la cuenta %s (%s) es de grupo: va a una de sus subcuentas', c.codigo, c.nombre)
              when p_uso = 'pasivo' and (c.tipo <> 'pasivo' or c.regla_obra = 'obligatoria')
                then format('la cuenta %s (%s) no es un pasivo sin obra: lo retenido, lo que se debe y lo que se devuelve van a una cuenta '
                            '22xx', c.codigo, c.nombre)
              when p_uso in ('sueldo', 'burden_admin', 'cuota') and (c.tipo not in ('gasto', 'otro_gasto') or c.regla_obra = 'obligatoria')
                then format('la cuenta %s (%s) no es un gasto sin obra', c.codigo, c.nombre)
              when p_uso = 'cuota' and (left(c.codigo, 2) = '50' or c.codigo in ('6000', '6005'))
                then format('la cuenta %s (%s) es de sueldos: la cuota de Gusto es un gasto de software', c.codigo, c.nombre)
              when p_uso = 'sin_obra' and (c.tipo not in ('costo', 'gasto', 'otro_gasto') or c.regla_obra = 'obligatoria')
                then format('la cuenta %s (%s) no es un costo o un gasto que admita ir sin obra', c.codigo, c.nombre)
              when p_uso = 'sin_obra' and left(c.codigo, 2) = '50'
                then format('la cuenta %s (%s) es del bloque de la mano de obra por obra y su burden: lo sin obra va a un gasto (el sueldo '
                            'de oficina, por ejemplo)', c.codigo, c.nombre)
              when p_uso = 'bolsa' and (left(c.codigo, 2) <> '50' or c.regla_obra <> 'prohibida')
                then format('la cuenta %s (%s) no es una bolsa del burden (del bloque 50xx y sin obra)', c.codigo, c.nombre)
              when p_uso = 'burden_obra' and (left(c.codigo, 2) <> '50' or c.regla_obra = 'prohibida')
                then format('la cuenta %s (%s) no es el burden por obra (del bloque 50xx y con obra)', c.codigo, c.nombre)
         end
    from (select p_cuenta as q) x
    left join public.cuentas c on c.codigo = x.q
$$;
revoke execute on function public.fn_nomina_cuenta_mal(text, text) from public, anon, service_role;
grant  execute on function public.fn_nomina_cuenta_mal(text, text) to authenticated;
comment on function public.fn_nomina_cuenta_mal(text, text) is 'c15: por qué una cuenta no sirve para un uso de la nómina (nulo = sirve): pasivo (lo que se queda debiendo y los reembolsos: un pasivo sin obra), sueldo y burden_admin (un gasto sin obra), sin_obra (un costo o un gasto que no exija obra, fuera del bloque 50xx), bolsa (50xx sin obra), burden_obra (50xx con obra), cuota (un gasto sin obra que no sea de sueldos).';

-- La cuenta de las horas SIN OBRA de la gente de campo: la que diga la
-- nómina y, si no dice nada, la del jornal de c10 (si sirve para un sueldo
-- por nómina). Nulo = todavía no hay: se pide antes de postear.
create or replace function public.fn_nomina_cuenta_sin_obra() returns text
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce((select c.cuenta_sin_obra from public.nomina_config c where c.id = 1),
                  (select j.cuenta_sin_obra from public.jornal_config j
                    where j.id = 1 and public.fn_nomina_cuenta_mal(j.cuenta_sin_obra, 'sin_obra') is null))
$$;
revoke execute on function public.fn_nomina_cuenta_sin_obra() from public, anon, service_role;
grant  execute on function public.fn_nomina_cuenta_sin_obra() to authenticated;
comment on function public.fn_nomina_cuenta_sin_obra() is 'c15: la cuenta a la que van las horas sin obra de la gente de campo: la de la configuración de la nómina y, si está vacía, la del jornal (c10) cuando sirve. Nulo si ninguna dice nada.';

-- Las cuentas que usa la nómina HOY, en un objeto: la mano de obra directa
-- y la del oficial (las que c3 nombra en sus cuentas del puente), las de la
-- configuración, y la efectiva de lo sin obra.
create or replace function public.fn_nomina_cuentas() returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
           'mano_obra',         (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'mano_obra'),
           'mano_obra_oficial', (select pc.cuenta from public.puente_cuentas pc where pc.rol = 'mano_obra_oficial'),
           'oficina', c.cuenta_oficina, 'oficial', c.cuenta_oficial, 'sin_obra', public.fn_nomina_cuenta_sin_obra(),
           'bolsa', c.cuenta_bolsa, 'burden_obra', c.cuenta_burden_obra, 'burden_admin', c.cuenta_burden_admin, 'cuota', c.cuenta_cuota)
    from public.nomina_config c
   where c.id = 1 and (select public.fn_nomina_ve())
$$;
revoke execute on function public.fn_nomina_cuentas() from public, anon, service_role;
grant  execute on function public.fn_nomina_cuentas() to authenticated;
comment on function public.fn_nomina_cuentas() is 'c15: las cuentas que usa la nómina hoy: mano_obra y mano_obra_oficial (las de las cuentas del puente de c3: 5000 y 5001), oficina, oficial, sin_obra (la efectiva, o nulo), bolsa (el burden real), burden_obra, burden_admin y cuota. A quien no es el dueño, nada.';

-- LA FECHA DEL ASIENTO de una corrida: su día de pago, con la regla del
-- documento tardío (§5.7 del plan, la misma de c3 para sus papeles y de c6
-- para lo del banco): si el mes del día de pago está abierto, ese día; si
-- está cerrado, el primer día del primer mes abierto posterior, con su
-- nota; y si ese mes es de un año posterior, como ajuste de su ejercicio
-- (ajuste_cpa, afecta_periodo = el mes cerrado), para que no caiga en el
-- resultado del año siguiente. El amarre con las declaraciones NO usa esta
-- fecha: usa el día de pago del archivo.
create or replace function public.fn_nomina_fecha_asiento(p_fecha date)
returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_per     public.periodos;
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
      'nota', format('Nómina tardía: su día de pago (%s) cae en %s, que ya estaba cerrado y es de %s, un ejercicio anterior. Entra el %s '
                     'como ajuste de ese ejercicio, para que no caiga en el resultado de %s.',
                     fn_nomina_dia(p_fecha), v_per.periodo, extract(year from p_fecha)::int, fn_nomina_dia(v_abierto),
                     extract(year from v_abierto)::int));
  end if;
  return jsonb_build_object(
    'fecha', v_abierto, 'tipo', 'normal',
    'nota', format('Nómina tardía: su día de pago (%s) cae en %s, que ya estaba cerrado. Entra el primer día del mes abierto (%s).',
                   fn_nomina_dia(p_fecha), v_per.periodo, fn_nomina_dia(v_abierto)));
end $$;
revoke execute on function public.fn_nomina_fecha_asiento(date) from public, anon, service_role;
grant  execute on function public.fn_nomina_fecha_asiento(date) to authenticated;
comment on function public.fn_nomina_fecha_asiento(date) is 'c15: la fecha con que entra al libro el asiento de una corrida, por su día de pago: ese día si su mes está abierto; si está cerrado, el primer día del primer mes abierto posterior (con su nota) y, si ese mes es de otro año, como ajuste del ejercicio anterior (tipo ajuste_cpa y afecta_periodo). La misma regla del documento tardío de c3 y de c6.';

-- Apuntar un cambio en el historial (con la marca de la guarda, y dejando
-- la que hubiera puesta).
create or replace function public.fn_nomina_apunta(p_que text, p_ref text, p_antes jsonb, p_despues jsonb) returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_prev text := coalesce(current_setting('mx_nomina.escribe', true), '');
begin
  perform set_config('mx_nomina.escribe', 'nomina_historial', true);
  insert into nomina_historial (que, ref, antes, despues, hecho_por) values (p_que, p_ref, p_antes, p_despues, auth.uid());
  perform set_config('mx_nomina.escribe', v_prev, true);
end $$;
revoke execute on function public.fn_nomina_apunta(text, text, jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_nomina_apunta(text, text, jsonb, jsonb) to authenticated;
comment on function public.fn_nomina_apunta(text, text, jsonb, jsonb) is 'c15: apunta un cambio en el historial de la nómina (qué, a qué, antes y después). La usan las funciones de aquí; a mano no escribe nada que no sea suyo (la policy pide al dueño con su código).';


-- ---------------------------------------------------------------------
-- 6. LA CONFIGURACIÓN Y EL MAPEO, por la pantalla.
-- ---------------------------------------------------------------------
-- fn_nomina_config(): la configuración de hoy y las cuentas que usa la
-- nómina. fn_nomina_config('{"clave": valor…}'): cambia lo que se diga (con
-- el código del teléfono). Las cuentas, validadas para su uso; un patrón,
-- que sea una expresión válida.
create or replace function public.fn_nomina_config(p jsonb default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c_claves constant text[] := array['cuenta_sin_obra', 'cuenta_oficina', 'cuenta_oficial', 'cuenta_bolsa', 'cuenta_burden_obra',
                                    'cuenta_burden_admin', 'cuenta_cuota', 'semana_empieza', 'horas_extra_desde', 'horas_periodo_oficial',
                                    'cargo_dias_antes', 'cargo_dias_despues', 'saldo_dias', 'amarre_tolerancia', 'cargo_patrones'];
  c_usos   constant jsonb := '{"cuenta_sin_obra": "sin_obra", "cuenta_oficina": "sueldo", "cuenta_oficial": "sueldo", "cuenta_bolsa": "bolsa",
                               "cuenta_burden_obra": "burden_obra", "cuenta_burden_admin": "burden_admin", "cuenta_cuota": "cuota"}';
  v_a  nomina_config;
  v_d  nomina_config;
  v_k  text;
  v_x  text;
  v_n  numeric;
begin
  perform fn_nomina_exigir_dueno();
  select * into v_a from nomina_config where id = 1;
  if p is null or p = '{}'::jsonb then
    return to_jsonb(v_a) || jsonb_build_object('cuentas', fn_nomina_cuentas());
  end if;
  perform fn_nomina_exigir_codigo();
  if jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'La configuración llega como un objeto: {"clave": valor}.';
  end if;
  select string_agg(k, ', ' order by k) into v_x from jsonb_object_keys(p) k where k <> all (c_claves);
  if v_x is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en la configuración de la nómina: %s. Valen: %s.', v_x,
                                                              array_to_string(c_claves, ', '));
  end if;
  v_d := v_a;
  foreach v_k in array c_claves loop
    continue when not p ? v_k;
    if v_k like 'cuenta\_%' then
      v_x := nullif(btrim(p->>v_k), '');
      if v_x is null and v_k <> 'cuenta_sin_obra' then
        raise exception using errcode = 'MX004', message = format('%s no puede quedar vacía.', v_k);
      end if;
      if v_x is not null and fn_nomina_cuenta_mal(v_x, c_usos->>v_k) is not null then
        raise exception using errcode = 'MX004', message = format('%s: %s.', v_k, fn_nomina_cuenta_mal(v_x, c_usos->>v_k));
      end if;
      v_d := jsonb_populate_record(v_d, jsonb_build_object(v_k, v_x));
    elsif v_k = 'cargo_patrones' then
      if jsonb_typeof(p->v_k) <> 'object'
         or exists (select 1 from jsonb_each(p->v_k) e
                     where e.key not in ('neto', 'impuestos', 'reembolsos', 'manutencion', 'cuota') or jsonb_typeof(e.value) <> 'string') then
        raise exception using errcode = '22023',
          message = 'cargo_patrones es un objeto con neto, impuestos, reembolsos, manutencion y cuota: cada uno, la expresión con que '
                    'se reconoce ese cargo de Gusto en la descripción del banco.';
      end if;
      for v_x in select e.value #>> '{}' from jsonb_each(p->v_k) e loop
        begin
          perform 'x' ~* v_x;
        exception when others then
          raise exception using errcode = '22023', message = 'Uno de los patrones de los cargos no es una expresión válida.';
        end;
      end loop;
      v_d.cargo_patrones := v_a.cargo_patrones || (p->v_k);
    else
      begin
        v_n := (p->>v_k)::numeric;
      exception when others then
        raise exception using errcode = 'MX005', message = format('%s es un número.', v_k);
      end;
      if v_n is null or scale(v_n) is null then
        raise exception using errcode = 'MX005', message = format('%s es un número.', v_k);
      end if;
      if (v_k = 'semana_empieza' and (v_n <> trunc(v_n) or v_n not between 1 and 7))
         or (v_k = 'horas_extra_desde' and (v_n <= 0 or v_n > 168))
         or (v_k = 'horas_periodo_oficial' and (v_n <= 0 or v_n > 744))
         or (v_k in ('cargo_dias_antes', 'cargo_dias_despues') and (v_n <> trunc(v_n) or v_n not between 0 and 60))
         or (v_k = 'saldo_dias' and (v_n <> trunc(v_n) or v_n not between 0 and 365))
         or (v_k = 'amarre_tolerancia' and (v_n < 0 or v_n > 1000 or v_n <> round(v_n, 2))) then
        raise exception using errcode = 'MX005',
          message = format('%s fuera de medida (llegó %s): %s.', v_k, v_n,
                           case v_k when 'semana_empieza' then 'el día en que empieza la semana laboral, de 1 (lunes) a 7 (domingo)'
                                    when 'horas_extra_desde' then 'desde cuántas horas a la semana son extra (40)'
                                    when 'horas_periodo_oficial' then 'las horas que cubre el sueldo del oficial en un período de pago (80)'
                                    when 'amarre_tolerancia' then 'en dólares con centavos, de 0 a 1000'
                                    when 'saldo_dias' then 'días enteros, de 0 a 365'
                                    else 'días enteros, de 0 a 60' end);
      end if;
      v_d := jsonb_populate_record(v_d, jsonb_build_object(v_k, v_n));
    end if;
  end loop;
  perform set_config('mx_nomina.escribe', 'nomina_config', true);
  update nomina_config
     set cuenta_sin_obra = v_d.cuenta_sin_obra, cuenta_oficina = v_d.cuenta_oficina, cuenta_oficial = v_d.cuenta_oficial,
         cuenta_bolsa = v_d.cuenta_bolsa, cuenta_burden_obra = v_d.cuenta_burden_obra, cuenta_burden_admin = v_d.cuenta_burden_admin,
         cuenta_cuota = v_d.cuenta_cuota, semana_empieza = v_d.semana_empieza, horas_extra_desde = v_d.horas_extra_desde,
         horas_periodo_oficial = v_d.horas_periodo_oficial, cargo_dias_antes = v_d.cargo_dias_antes,
         cargo_dias_despues = v_d.cargo_dias_despues, saldo_dias = v_d.saldo_dias, amarre_tolerancia = v_d.amarre_tolerancia,
         cargo_patrones = v_d.cargo_patrones, actualizado = clock_timestamp(), actualizado_por = auth.uid()
   where id = 1
  returning * into v_d;
  perform set_config('mx_nomina.escribe', '', true);
  perform fn_nomina_apunta('config', null, to_jsonb(v_a) - array['actualizado', 'actualizado_por'],
                           to_jsonb(v_d) - array['actualizado', 'actualizado_por']);
  return to_jsonb(v_d) || jsonb_build_object('cuentas', fn_nomina_cuentas());
end $$;
revoke execute on function public.fn_nomina_config(jsonb) from public, anon, service_role;
grant  execute on function public.fn_nomina_config(jsonb) to authenticated;
comment on function public.fn_nomina_config(jsonb) is 'c15: sin argumento, la configuración de la nómina de hoy y las cuentas que usa (cuentas). Con un objeto, cambia lo que diga (con el código del teléfono): las cuentas (validadas para su uso; cuenta_sin_obra puede vaciarse), semana_empieza (1 lunes … 7 domingo), horas_extra_desde, horas_periodo_oficial, cargo_dias_antes y cargo_dias_despues, saldo_dias, amarre_tolerancia y cargo_patrones (neto, impuestos, reembolsos, manutencion, cuota). Queda en el historial. Solo el dueño.';

-- UNA COLUMNA DEL MAPEO: dice qué es una columna del archivo (por su nombre)
-- o cambia lo que se decía. {"columna": "Employer SUTA tax", "clase":
-- "imp_patron", "cuenta": "2230", "declara": "suta"}; "concepto" si se quiere
-- otro que el nombre de la columna; {"columna": …, "quitar": true} quita una
-- que no es de fábrica. Las corridas YA importadas no cambian (lo que se
-- leyó, leído está): la que esperaba esta columna se descarta y se vuelve a
-- subir su archivo.
create or replace function public.fn_nomina_columna(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c_claves constant text[] := array['columna', 'concepto', 'clase', 'cuenta', 'declara', 'nota', 'quitar'];
  c_con_cuenta constant text[] := array['imp_empleado', 'imp_empleado_total', 'deduccion', 'deduccion_total', 'neto', 'reembolso',
                                        'reembolso_total', 'imp_patron', 'imp_patron_total', 'ben_patron', 'ben_patron_total'];
  v_alias text;
  v_a     nomina_columnas;
  v_d     nomina_columnas;
  v_x     text;
  v_clase text;
  v_cta   text;
  v_dec   text;
  v_con   text;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'Una columna del mapeo llega como un objeto: {"columna": "su nombre", "clase": "…"}.';
  end if;
  select string_agg(k, ', ' order by k) into v_x from jsonb_object_keys(p) k where k <> all (c_claves);
  if v_x is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida: %s. Valen: %s.', v_x, array_to_string(c_claves, ', '));
  end if;
  v_alias := fn_nomina_norm(p->>'columna');
  if v_alias is null or length(v_alias) > 80 or fn_nomina_delicado(p->>'columna') or v_alias ~ '^[0-9 ]+$' then
    raise exception using errcode = '22023',
      message = 'Di el nombre de la columna tal como viene en la cabecera del archivo («columna»): un nombre, no un dato.';
  end if;
  select * into v_a from nomina_columnas where alias = v_alias;
  if coalesce((p->>'quitar')::boolean, false) then
    if v_a.alias is null then
      return jsonb_build_object('columna', v_alias, 'quitada', false, 'nota', 'Esa columna no estaba en el mapeo.');
    end if;
    perform set_config('mx_nomina.escribe', 'nomina_columnas', true);
    delete from nomina_columnas where alias = v_alias;
    perform set_config('mx_nomina.escribe', '', true);
    perform fn_nomina_apunta('columna_fuera', v_alias, to_jsonb(v_a), null);
    return jsonb_build_object('columna', v_alias, 'quitada', true);
  end if;
  v_clase := coalesce(nullif(btrim(p->>'clase'), ''), v_a.clase);
  if v_clase is null then
    raise exception using errcode = '22023', message = 'Di qué es esa columna («clase»): bruto, imp_empleado, deduccion, imp_patron, ben_patron, reembolso, horas, ignorar…';
  end if;
  v_cta := case when p ? 'cuenta' then nullif(btrim(p->>'cuenta'), '') else v_a.cuenta end;
  v_dec := case when p ? 'declara' then nullif(btrim(p->>'declara'), '') else v_a.declara end;
  v_con := coalesce(nullif(btrim(p->>'concepto'), ''), v_a.concepto,
                    left(case when v_alias ~ '^[a-z]' then '' else 'c_' end || replace(v_alias, ' ', '_'), 60));
  if v_con !~ '^[a-z][a-z0-9_]{0,59}$' then
    raise exception using errcode = '22023', message = 'El concepto es un nombre corto en minúsculas, con guiones bajos (por ejemplo, employer_401k_match).';
  end if;
  if v_clase <> all (array['llave', 'tipo', 'dia_pago', 'periodo_desde', 'periodo_hasta', 'periodo', 'nombre', 'apellido', 'segundo', 'nombre_completo',
                           'empleado_id', 'metodo_pago', 'horas', 'horas_fuera', 'bruto', 'bruto_total', 'imp_empleado', 'imp_empleado_total',
                           'deduccion', 'deduccion_total', 'neto', 'reembolso', 'reembolso_total', 'cheque_total', 'imp_patron',
                           'imp_patron_total', 'ben_patron', 'ben_patron_total', 'costo_total', 'delicado', 'ignorar']) then
    raise exception using errcode = '22023',
      message = 'Esa clase no existe. Las de dinero: bruto, imp_empleado, deduccion, neto, reembolso, imp_patron, ben_patron (y sus '
                'totales, que solo son control: bruto_total, imp_empleado_total, deduccion_total, reembolso_total, cheque_total, '
                'imp_patron_total, ben_patron_total, costo_total). Las demás: horas, horas_fuera, dia_pago, periodo_desde, periodo_hasta, periodo, '
                'tipo, llave, nombre, apellido, segundo, nombre_completo, empleado_id, metodo_pago, delicado, ignorar.';
  end if;
  if v_cta is not null and v_clase <> all (c_con_cuenta) then
    raise exception using errcode = 'MX004', message = format('Una columna de clase %s no lleva cuenta.', v_clase);
  end if;
  if v_cta is not null and fn_nomina_cuenta_mal(v_cta, 'pasivo') is not null then
    raise exception using errcode = 'MX004', message = format('La cuenta de esa columna: %s.', fn_nomina_cuenta_mal(v_cta, 'pasivo'));
  end if;
  if v_dec is not null and (v_dec <> all (array['fit', 'ss_ee', 'med_ee', 'med_adic', 'ss_er', 'med_er', 'futa', 'suta'])
                            or v_clase not in ('imp_empleado', 'imp_patron')) then
    raise exception using errcode = '22023',
      message = 'declara dice con qué renglón de las declaraciones amarra un impuesto: fit, ss_ee, med_ee, med_adic (del empleado), '
                'ss_er, med_er, futa, suta (del patrón). Solo en columnas de clase imp_empleado o imp_patron.';
  end if;
  perform set_config('mx_nomina.escribe', 'nomina_columnas', true);
  insert into nomina_columnas (alias, concepto, clase, cuenta, declara, de_fabrica, nota, actualizado_por)
  values (v_alias, v_con, v_clase, v_cta, v_dec, false, nullif(btrim(p->>'nota'), ''), auth.uid())
  on conflict (alias) do update
     set concepto = excluded.concepto, clase = excluded.clase, cuenta = excluded.cuenta, declara = excluded.declara,
         nota = coalesce(excluded.nota, nomina_columnas.nota), actualizado_el = clock_timestamp(), actualizado_por = auth.uid()
  returning * into v_d;
  perform set_config('mx_nomina.escribe', '', true);
  perform fn_nomina_apunta('columna', v_alias, to_jsonb(v_a), to_jsonb(v_d));
  return to_jsonb(v_d) || jsonb_build_object(
    'nota_corridas', 'Las corridas ya importadas no cambian: la que esperaba esta columna se descarta y se vuelve a subir su archivo.');
end $$;
revoke execute on function public.fn_nomina_columna(jsonb) from public, anon, service_role;
grant  execute on function public.fn_nomina_columna(jsonb) to authenticated;
comment on function public.fn_nomina_columna(jsonb) is 'c15: dice qué es una columna del archivo de nómina, por su nombre ({columna, clase, cuenta?, declara?, concepto?, nota?}), o cambia lo que se decía; {columna, quitar: true} quita una que no es de fábrica. La cuenta, un pasivo sin obra; declara, solo en un impuesto. Queda en el historial. Las corridas ya importadas no cambian: se descartan y se vuelve a subir su archivo. Con el código del teléfono. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 7. EL PUENTE AL LIBRO: el trigger de nomina_corridas. ES LA ÚNICA
--    FUNCIÓN SECURITY DEFINER DE LA CAPA, y por qué:
--    · c3 exige (control «mano de obra») que toda línea de 5000 o de 5001
--      venga de un journal de nómina: un asiento con origen «nomina…». Y
--      c2 solo deja poner el origen del PRIMER asiento de un papel a su
--      puente (fn_postear_interno, camino «puente», sin grant a la API):
--      fn_postear, la puerta del dueño, lo rechaza («fn_postear lleva
--      origen_tabla y origen_id solo para sustituir el asiento reversado de
--      ese documento»). Por la puerta del dueño el journal entraría sin
--      origen y c3 lo pondría en rojo para siempre.
--    · Por eso la corrida entra como entran los recibos y las facturas de
--      c3: por el puente de SU papel. El papel es la fila de la corrida; el
--      puente, este trigger. Devuelve «trigger» (Postgres no deja llamarla
--      suelta) y no tiene EXECUTE para nadie: es lo que c2 («permisos») y c6
--      («protecciones del banco») admiten, y lo que ya hace c11 con el
--      número de la factura. Solo corre cuando una corrida pasa de
--      importada a posteada, o de posteada a anulada, y eso solo lo hacen
--      fn_nomina_postear y fn_nomina_anular (la guarda de arriba pide su
--      marca y corre antes: los triggers van por orden de nombre).
--    · NO SE FÍA DE QUIEN LA DISPARA: vuelve a pedir al dueño y su código
--      del teléfono; el asiento sale del plan que guardó la corrida, pero
--      solo entra si ES el journal guardado: cada cuenta por pagar, al
--      centavo, lo que suman las líneas del journal; el sueldo y lo patronal,
--      su total; y ninguna cuenta fuera de las de la nómina. No lee el
--      banco ni toca nada más que el libro.
--    Postea DOS asientos, porque c3 no deja el burden por obra (5010) en un
--    asiento con otras cuentas: (1) EL JOURNAL (origen nomina_corridas), en
--    la fecha del día de pago; (2) EL REPARTO DEL BURDEN REAL (origen
--    nomina_burden): Dr 5010 por obra / Cr 5015, solo cuentas del bloque
--    50xx, por las mismas horas. Anular reversa los dos (fn_reversar_interno
--    de c2: en su fecha si su mes sigue abierto; si no, donde c2 diga).
-- ---------------------------------------------------------------------
-- LO QUE EL JOURNAL GUARDADO DICE, cuenta por cuenta, de lo que NO es
-- sueldo: lo que queda por pagar (clase «pasivo», en negativo: el haber) —lo
-- retenido, los impuestos y los beneficios del patrón, las deducciones, y
-- el neto con los reembolsos que Gusto paga con el cheque— y los reembolsos
-- que se devuelven a los empleados (clase «reembolso», en positivo: el
-- debe). Sale de las líneas de la corrida (nomina_lineas) y de los totales
-- de cada persona: el plan arma el asiento con esto, el puente comprueba
-- que el asiento ES esto antes de postear, y el control lo compara con el
-- libro. Una línea sin cuenta sale con la cuenta vacía (y frena).
create or replace function public.fn_nomina_journal(p_corrida uuid)
returns table (cuenta text, clase text, monto numeric)
language sql stable
set search_path = public, pg_temp
as $$
  with neta as (
    -- (la cuenta del neto: la de sus líneas; si ninguna persona trae neto, la de su columna)
    select coalesce((select min(l.cuenta) from public.nomina_lineas l where l.corrida_id = p_corrida and l.clase = 'neto'),
                    (select min(k->>'cuenta') from public.nomina_corridas c cross join lateral jsonb_array_elements(c.columnas) k
                      where c.id = p_corrida and k->>'clase' = 'neto')) as c)
  select q.cuenta, q.clase, sum(q.m)
    from (select l.cuenta, case when l.clase = 'reembolso' then 'reembolso' else 'pasivo' end as clase,
                 case when l.clase = 'reembolso' then l.monto else -l.monto end as m
            from public.nomina_lineas l
           where l.corrida_id = p_corrida and l.clase in ('imp_empleado', 'imp_patron', 'ben_patron', 'deduccion', 'reembolso')
          union all
          select neta.c, 'pasivo', -(cp.neto + case when cp.neto_con_reembolso then 0 else cp.reembolsos end)
            from public.nomina_corrida_personas cp cross join neta
           where cp.corrida_id = p_corrida) q
   group by q.cuenta, q.clase
$$;
revoke execute on function public.fn_nomina_journal(uuid) from public, anon, service_role;
grant  execute on function public.fn_nomina_journal(uuid) to authenticated;
comment on function public.fn_nomina_journal(uuid) is 'c15: lo que el journal guardado de una corrida dice, cuenta por cuenta, de lo que no es sueldo: lo que queda por pagar (clase pasivo, en negativo: lo retenido, los impuestos y beneficios del patrón, las deducciones, y el neto con los reembolsos que se pagan con el cheque) y los reembolsos que se devuelven (clase reembolso, en positivo). De sus líneas y de los totales de cada persona. El plan arma el asiento con esto y el puente comprueba que el asiento es esto. Solo lectura; lo de cada persona, con el código del teléfono.';

create or replace function public.fn_nomina_al_libro()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cfg     nomina_config;
  v_sueldo  text[];
  v_x       text;
  v_n       numeric;
  v_esp     numeric;
  v_fecha   jsonb;
  v_arch    nomina_archivos;
  v_proc    jsonb;
  v_extra   jsonb := '{}'::jsonb;
  v_res     jsonb;
  v_bur     jsonb;
  v_motivo  text;
begin
  if tg_op <> 'UPDATE' or new.estado is not distinct from old.estado
     or not ((old.estado = 'importada' and new.estado = 'posteada') or (old.estado = 'posteada' and new.estado = 'anulada')) then
    return new;
  end if;
  -- Quién: el dueño, con su código (o el SQL Editor); y por la función.
  if fn_nomina_por_api() then
    if not coalesce(es_dueno(), false) then
      raise exception using errcode = '42501', message = 'La nómina la postea y la anula solo Edgar (el dueño).';
    end if;
    if coalesce((select auth.jwt() ->> 'aal'), '') <> 'aal2' then
      raise exception using errcode = '42501', message = 'La nómina se postea y se anula con el código del teléfono.';
    end if;
  end if;
  if coalesce(current_setting('mx_nomina.escribe', true), '') <> 'nomina_corridas' then
    raise exception using errcode = 'MX003', message = 'Una corrida se postea y se anula solo desde la pantalla de Nómina (sus funciones).';
  end if;
  select * into v_arch from nomina_archivos where id = new.archivo_id;
  -- (los períodos, tomados ANTES del primer asiento, como hacen los puentes de c3: así un cierre de mes en curso espera a
  -- esto o esto a él, y no se traban entre sí cuando después se deshace el devengo estándar del mes)
  perform 1 from periodos for share;

  if new.estado = 'anulada' then
    v_motivo := btrim(new.anulada_motivo);
    v_proc := jsonb_build_object('funcion', 'fn_nomina_anular', 'corrida', new.id);
    if old.burden_asiento_id is not null then
      v_bur := fn_reversar_interno(old.burden_asiento_id, v_motivo, 'reverso', v_proc);
      new.burden_reverso_id := (v_bur->>'id')::uuid;
    end if;
    v_res := fn_reversar_interno(old.asiento_id, v_motivo, 'reverso', v_proc);
    new.reverso_id := (v_res->>'id')::uuid;
    return new;
  end if;

  -- POSTEAR. El plan, y que sea el journal guardado.
  if new.plan is null or jsonb_typeof(new.plan->'asiento'->'lineas') is distinct from 'array'
     or jsonb_array_length(new.plan->'asiento'->'lineas') < 2 then
    raise exception using errcode = 'MX001', message = 'La corrida no trae el asiento que hay que postear.';
  end if;
  if not new.cuadra or jsonb_array_length(new.sin_clasificar) > 0 then
    raise exception using errcode = 'MX008',
      message = 'Esta corrida no cuadra con su archivo o trae columnas con cifras sin clasificar: no se postea.';
  end if;
  select * into v_cfg from nomina_config where id = 1;
  -- (las cuentas del sueldo y de lo que el patrón paga por su gente)
  v_sueldo := array[(select pc.cuenta from puente_cuentas pc where pc.rol = 'mano_obra'),
                    (select pc.cuenta from puente_cuentas pc where pc.rol = 'mano_obra_oficial'),
                    v_cfg.cuenta_oficina, v_cfg.cuenta_oficial, v_cfg.cuenta_bolsa, v_cfg.cuenta_burden_admin, fn_nomina_cuenta_sin_obra()];
  -- (cada cuenta de lo que no es sueldo —lo que queda por pagar y los reembolsos—: al centavo, lo que dice el journal)
  for v_x, v_n in select j.cuenta, sum(j.monto) from fn_nomina_journal(new.id) j group by j.cuenta loop
    if v_x is null then
      raise exception using errcode = 'MX004', message = 'Una línea del journal no tiene cuenta: no se postea.';
    end if;
    if v_x = any (v_sueldo) then
      raise exception using errcode = 'MX004',
        message = format('La cuenta %s es del sueldo y también de lo que queda por pagar: no puede ser las dos cosas. No se posteó nada.', v_x);
    end if;
    select coalesce(sum((k->>'monto')::numeric), 0) into v_esp
      from jsonb_array_elements(new.plan->'asiento'->'lineas') k where k->>'cuenta' = v_x;
    if v_esp <> v_n then
      raise exception using errcode = 'MX001',
        message = format('El asiento no es el journal guardado: en la cuenta %s lleva %s y el journal dice %s. No se posteó nada: vuelve a '
                         'pedir la propuesta.', v_x, v_esp, v_n);
    end if;
  end loop;
  -- (ninguna cuenta ajena: toda línea va a una cuenta del sueldo o a una de las que nombra el journal)
  select string_agg(distinct k->>'cuenta', ', ') into v_x
    from jsonb_array_elements(new.plan->'asiento'->'lineas') k
   where not coalesce(k->>'cuenta' = any (v_sueldo), false)
     and not exists (select 1 from fn_nomina_journal(new.id) j where j.cuenta = k->>'cuenta');
  if v_x is not null then
    raise exception using errcode = 'MX004',
      message = format('El asiento lleva una cuenta que no es de esta nómina (%s). No se posteó nada: vuelve a pedir la propuesta.', v_x);
  end if;
  -- (el sueldo y lo patronal: su total)
  select coalesce(sum((k->>'monto')::numeric), 0) into v_esp
    from jsonb_array_elements(new.plan->'asiento'->'lineas') k where k->>'cuenta' = any (v_sueldo);
  select coalesce(sum(l.monto), 0) into v_n
    from nomina_lineas l where l.corrida_id = new.id and l.clase in ('bruto', 'imp_patron', 'ben_patron');
  if v_esp <> v_n then
    raise exception using errcode = 'MX001',
      message = format('El asiento no es el journal guardado: al sueldo y a lo patronal lleva %s y el journal dice %s. No se posteó nada: '
                       'vuelve a pedir la propuesta.', v_esp, v_n);
  end if;
  -- (el reparto del burden: solo el burden por obra contra la bolsa, y justo lo que entró a la bolsa)
  if new.plan->'burden' is not null and jsonb_typeof(new.plan->'burden') <> 'null' then
    if jsonb_typeof(new.plan->'burden'->'lineas') is distinct from 'array'
       or exists (select 1 from jsonb_array_elements(new.plan->'burden'->'lineas') k
                   where k->>'cuenta' not in (v_cfg.cuenta_burden_obra, v_cfg.cuenta_bolsa)) then
      raise exception using errcode = 'MX004', message = 'El reparto del burden solo lleva el burden por obra y su bolsa.';
    end if;
    select coalesce(sum((k->>'monto')::numeric), 0) into v_esp
      from jsonb_array_elements(new.plan->'burden'->'lineas') k where k->>'cuenta' = v_cfg.cuenta_burden_obra;
    select coalesce(sum((k->>'monto')::numeric), 0) into v_n
      from jsonb_array_elements(new.plan->'asiento'->'lineas') k where k->>'cuenta' = v_cfg.cuenta_bolsa;
    if v_esp <> v_n then
      raise exception using errcode = 'MX001',
        message = format('El reparto del burden lleva a las obras %s y a la bolsa entraron %s: tienen que ser lo mismo.', v_esp, v_n);
    end if;
  end if;

  v_fecha := fn_nomina_fecha_asiento(new.dia_pago);
  if v_fecha->>'tipo' = 'ajuste_cpa' then
    v_extra := jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', v_fecha->>'afecta_periodo', 'motivo', v_fecha->>'nota');
  end if;
  v_proc := jsonb_strip_nulls(jsonb_build_object(
              'funcion', 'fn_nomina_postear', 'corrida', new.id, 'fecha_documento', new.dia_pago,
              'periodo_desde', new.periodo_desde, 'periodo_hasta', new.periodo_hasta, 'tipo_nomina', new.tipo,
              'archivo', v_arch.nombre, 'sha256', v_arch.sha256, 'huella', new.huella, 'tardio', v_fecha->>'nota'));
  v_res := fn_postear_interno(
    jsonb_build_object('camino', 'puente', 'fecha', v_fecha->>'fecha',
                       'descripcion', left(format('Nómina de Gusto del %s%s: %s persona(s), bruto %s, neto %s (su journal)',
                                                  fn_nomina_dia(new.dia_pago),
                                                  coalesce(format(', período del %s al %s', fn_nomina_dia(new.periodo_desde),
                                                                  fn_nomina_dia(new.periodo_hasta)), ''),
                                                  new.personas, fn_nomina_usd(new.bruto), fn_nomina_usd(new.neto)), 500),
                       'lineas', new.plan->'asiento'->'lineas',
                       'origen_tabla', 'nomina_corridas', 'origen_id', new.id::text, 'procedencia', v_proc) || v_extra);
  new.asiento_id     := (v_res->>'id')::uuid;
  new.asiento_numero := v_res->>'numero';
  new.fecha_asiento  := (v_res->>'fecha_contable')::date;
  if new.plan->'burden' is not null and jsonb_typeof(new.plan->'burden') <> 'null' then
    v_bur := fn_postear_interno(
      jsonb_build_object('camino', 'puente', 'fecha', v_fecha->>'fecha',
                         'descripcion', left(format('Reparto del burden real de la nómina del %s a sus obras, por las mismas horas (%s)',
                                                    fn_nomina_dia(new.dia_pago), v_res->>'numero'), 500),
                         'lineas', new.plan->'burden'->'lineas',
                         'origen_tabla', 'nomina_burden', 'origen_id', new.id::text,
                         'procedencia', v_proc || jsonb_build_object('journal', v_res->>'numero')) || v_extra);
    new.burden_asiento_id := (v_bur->>'id')::uuid;
  end if;
  return new;
end $$;
revoke execute on function public.fn_nomina_al_libro() from public, anon, authenticated, service_role;
comment on function public.fn_nomina_al_libro() is 'c15: EL PUENTE de la nómina al libro, el trigger de nomina_corridas (la única función SECURITY DEFINER de la capa: el origen «nomina…» que c3 exige a la mano de obra solo lo puede poner un puente, por la puerta interna de c2). Al pasar una corrida a posteada, comprueba que el asiento del plan ES el journal guardado (cada cuenta de lo que queda por pagar y de los reembolsos al centavo, el sueldo y lo patronal en su total, ninguna cuenta ajena) y postea el journal (origen nomina_corridas, en la fecha del día de pago, con la regla del documento tardío) y el reparto del burden real a las obras (origen nomina_burden: 5010 por obra contra 5015). Al pasarla a anulada, reversa los dos. Vuelve a pedir al dueño y su código. Por ser de trigger nadie la puede llamar suelta; sin EXECUTE para nadie.';

-- (por orden de nombre va después de trg_nomina_corridas_guarda)
create or replace trigger trg_nomina_corridas_libro before update on public.nomina_corridas
  for each row execute function public.fn_nomina_al_libro();


-- ---------------------------------------------------------------------
-- 8. LEER EL ARCHIVO. fn_nomina_leer no escribe nada: recibe las celdas del
--    CSV como TEXTO (lo que manda la pantalla) y devuelve lo que entendió.
--    La usan el ensayo (para enseñarlo) y la importación (para guardarlo).
--    · Busca la CABECERA: la primera fila que tiene a la vez una columna de
--      persona y una de dinero que el mapeo conoce (lo de arriba es
--      preámbulo). Si otra fila vuelve a ser una cabecera, empieza otra
--      sección y se vuelve a mapear. Nunca por posición: por nombre.
--    · Un «Check date: …» o un «Pay period: …» suelto (en el preámbulo o
--      entre secciones) da el día de pago y el período de las filas que no
--      los traen en su columna.
--    · Una fila «Total», «Totals», «Grand total» o «Subtotal» (o una fila
--      sin nombre y con cifras) es CONTROL: se compara con la suma de las
--      filas, nunca se suma.
--    · LO DELICADO NO SE LEE: una columna de clase «delicado» se salta
--      entera; una celda con forma de número de Seguro Social en una columna
--      que no se conoce la vuelve delicada; en una que sí se guarda (un
--      nombre), el archivo no entra. Ningún mensaje repite el valor de una
--      celda: dice la fila y la columna.
--    · Lo que no es un importe en una columna de dinero, o trae más de dos
--      decimales, para el archivo (no se adivina ni se redondea).
--    · Una columna que el mapeo no conoce: si alguna de sus celdas es una
--      cifra distinta de cero, sale en «sin_clasificar» (y la corrida no se
--      postea hasta que se diga qué es); sus valores no se guardan.
--    · Parte el archivo en corridas: una por día de pago, período, tipo y
--      llave de nómina. Y a cada persona de cada corrida le calcula sus
--      totales y sus compuertas: las partes contra su total, bruto −
--      impuestos − deducciones = neto, neto + reembolsos = cheque.
-- ---------------------------------------------------------------------
create or replace function public.fn_nomina_leer(p_archivo jsonb, p_opciones jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  c_persona constant text[] := array['nombre', 'apellido', 'nombre_completo', 'empleado_id'];
  c_dinero  constant text[] := array['bruto', 'bruto_total', 'imp_empleado', 'imp_empleado_total', 'deduccion', 'deduccion_total', 'neto',
                                     'reembolso', 'reembolso_total', 'cheque_total', 'imp_patron', 'imp_patron_total', 'ben_patron',
                                     'ben_patron_total', 'costo_total'];
  c_horas   constant text[] := array['horas', 'horas_fuera'];
  c_grupos  constant text[] := array['bruto', 'imp_empleado', 'deduccion', 'reembolso', 'imp_patron', 'ben_patron'];
  c_fecha   constant text   := '([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}|[0-9]{4}-[0-9]{2}-[0-9]{2}|[A-Za-z]{3,9}\.? [0-9]{1,2}, [0-9]{4})';
  v_op      jsonb := coalesce(p_opciones, '{}'::jsonb);
  v_map     jsonb;
  v_filas   jsonb;
  v_nf      int;
  r         int;
  i         int;
  v_row     jsonb;
  v_cells   text[];
  v_nc      int;
  v_ne      int;
  v_txt     text;
  v_al      text;
  v_m       jsonb;
  v_num     numeric;
  v_es_cab  boolean;
  v_hp      boolean;
  v_hd      boolean;
  v_hn      boolean;
  v_sec     int := 0;
  a_label   text[];
  a_alias   text[];
  a_con     text[];
  a_clase   text[];
  a_cta     text[];
  a_dec     text[];
  a_cifras  int[];
  a_deli    boolean[];
  v_cols    jsonb := '[]'::jsonb;
  v_data    jsonb := '[]'::jsonb;
  v_tots    jsonb := '[]'::jsonb;
  v_ceros   jsonb := '{}'::jsonb;
  v_fdia    date := null;
  v_fdes    date := null;
  v_fhas    date := null;
  v_sdia    date;
  v_sdes    date;
  v_shas    date;
  v_ult_tot int;
  v_cab_fila int;
  v_primera text;
  v_nom     text;
  v_ape     text;
  v_comp    text;
  v_emp     text;
  v_met     text;
  v_tipo    text;
  v_llave   text;
  v_dia     date;
  v_des     date;
  v_has     date;
  v_v       jsonb;
  v_tiene   boolean;
  v_es_tot  boolean;
  v_es_sub  boolean;
  v_fechas  date[];
  v_cand    text;
  v_delicado text[] := '{}';
  -- la segunda parte
  k         record;
  pr        record;
  d         record;
  v_un_dia  date;
  v_secs    int[];
  v_cm      jsonb;
  v_pres    jsonb;
  v_s       jsonb;
  v_pers    jsonb;
  v_lin     jsonb;
  v_desc    text[];
  v_cdesc   jsonb;
  v_avisos  jsonb;
  v_corr    jsonb := '[]'::jsonb;
  v_n       int := 0;
  v_bru     numeric; v_ime numeric; v_ded numeric; v_net numeric; v_ree numeric; v_imp numeric; v_ben numeric;
  v_hor     numeric; v_hfu numeric; v_base numeric; v_incl boolean;
  t_bru     numeric; t_ime numeric; t_ded numeric; t_net numeric; t_ree numeric; t_imp numeric; t_ben numeric; t_hor numeric;
  t_rin     numeric;
  v_tarch   jsonb;
  v_firma   text;
  v_fb      numeric[];
  v_fn      numeric[];
  v_key     text;
  v_dec     jsonb;
  v_nceros  int;
  v_sig     jsonb;
  v_rep     boolean;
begin
  perform fn_nomina_exigir_dueno();
  if p_archivo is null or jsonb_typeof(p_archivo) <> 'object' then
    raise exception using errcode = '22023', message = 'El archivo llega como un objeto: {"nombre", "sha256", "bytes", "filas": [[celda, …], …]}.';
  end if;
  select string_agg(q, ', ' order by q) into v_txt from jsonb_object_keys(p_archivo) q where q not in ('nombre', 'sha256', 'bytes', 'filas');
  if v_txt is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en el archivo: %s. Valen nombre, sha256, bytes y filas.', v_txt);
  end if;
  select string_agg(q, ', ' order by q) into v_txt from jsonb_object_keys(v_op) q
   where q not in ('fila_cabecera', 'dia_pago', 'periodo_desde', 'periodo_hasta', 'tipo', 'otra_nomina', 'otra_porque', 'reemplazar');
  if v_txt is not null then
    raise exception using errcode = '22023',
      message = format('Opción desconocida: %s. Valen fila_cabecera, dia_pago, periodo_desde, periodo_hasta, tipo, otra_nomina (con '
                       'otra_porque) y reemplazar.', v_txt);
  end if;
  if coalesce(btrim(p_archivo->>'nombre'), '') = '' or length(p_archivo->>'nombre') > 200 or fn_nomina_delicado(p_archivo->>'nombre') then
    raise exception using errcode = '22023', message = 'Falta el nombre del archivo (hasta 200 letras).';
  end if;
  if coalesce(p_archivo->>'sha256', '') !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'Falta la huella del archivo (sha256: 64 caracteres en minúsculas): la calcula la pantalla al leerlo.';
  end if;
  if coalesce(p_archivo->>'bytes', '') !~ '^[1-9][0-9]{0,11}$' then
    raise exception using errcode = '22023', message = 'Falta el tamaño del archivo (bytes).';
  end if;
  v_filas := p_archivo->'filas';
  if jsonb_typeof(v_filas) is distinct from 'array' or jsonb_array_length(v_filas) = 0 then
    raise exception using errcode = 'MX009', message = 'El archivo no trae filas: ¿es el «Payroll journal» de Gusto en CSV? Bájalo otra vez.';
  end if;
  v_nf := jsonb_array_length(v_filas);
  if v_nf > 5000 then
    raise exception using errcode = 'MX009',
      message = format('El archivo trae %s filas: más de 5,000 no es una nómina. Bájalo de una nómina cada vez (día de pago = ese día).', v_nf);
  end if;
  if (v_op ? 'dia_pago' and fn_nomina_fecha(v_op->>'dia_pago') is null)
     or (v_op ? 'periodo_desde' and fn_nomina_fecha(v_op->>'periodo_desde') is null)
     or (v_op ? 'periodo_hasta' and fn_nomina_fecha(v_op->>'periodo_hasta') is null)
     or ((v_op ? 'periodo_desde') <> (v_op ? 'periodo_hasta'))
     or (v_op ? 'fila_cabecera' and coalesce(v_op->>'fila_cabecera', '') !~ '^[1-9][0-9]{0,3}$')
     or (v_op ? 'tipo' and coalesce(v_op->>'tipo', '') not in ('regular', 'fuera_de_ciclo')) then
    raise exception using errcode = '22023',
      message = 'Una opción viene mal: dia_pago, periodo_desde y periodo_hasta son fechas (AAAA-MM-DD; el período, las dos); fila_cabecera, '
                'el número de la fila de la cabecera; tipo, regular o fuera_de_ciclo.';
  end if;
  select coalesce(jsonb_object_agg(c.alias, jsonb_build_object('concepto', c.concepto, 'clase', c.clase, 'cuenta', c.cuenta,
                                                               'declara', c.declara)), '{}'::jsonb)
    into v_map from nomina_columnas c;

  -- ============ PRIMERA PARTE: fila por fila ============
  for r in 1 .. v_nf loop
    v_row := v_filas->(r - 1);
    if jsonb_typeof(v_row) is distinct from 'array' then
      raise exception using errcode = '22023', message = format('La fila %s no es una lista de celdas.', r);
    end if;
    if jsonb_array_length(v_row) > 400 then
      raise exception using errcode = 'MX009', message = format('La fila %s trae más de 400 celdas: no parece un journal de nómina.', r);
    end if;
    -- (cada celda, limpia: sin la marca de inicio de archivo, sin espacios duros, sin espacios en las puntas)
    select coalesce(array_agg(btrim(replace(replace(coalesce(e.t, ''), E'﻿', ''), E' ', ' '), E' \t\r\n') order by e.o), '{}')
      into v_cells
      from jsonb_array_elements_text(v_row) with ordinality e(t, o);
    v_nc := cardinality(v_cells);
    select count(*) into v_ne from unnest(v_cells) q where q <> '';
    continue when v_ne = 0;

    -- ¿Es una cabecera?
    v_hp := false; v_hd := false; v_hn := false;
    for i in 1 .. v_nc loop
      continue when v_cells[i] = '';
      v_m := v_map->fn_nomina_norm(v_cells[i]);
      if v_m is not null then
        v_hp := v_hp or (v_m->>'clase') = any (c_persona);
        v_hd := v_hd or (v_m->>'clase') = any (c_dinero);
      elsif fn_nomina_monto(v_cells[i]) is not null then
        v_hn := true;
      end if;
    end loop;
    v_es_cab := (v_hp and v_hd and not v_hn) or (v_op->>'fila_cabecera')::int is not distinct from r;

    if v_es_cab then
      -- (cierra la sección anterior: sus columnas)
      if v_sec > 0 then
        for i in 1 .. cardinality(a_label) loop
          v_cols := v_cols || jsonb_build_object('sec', v_sec, 'n', i, 'columna', a_label[i], 'alias', a_alias[i], 'concepto', a_con[i],
                                                 'clase', case when a_deli[i] then 'delicado' else a_clase[i] end, 'cuenta', a_cta[i],
                                                 'declara', a_dec[i], 'cifras', a_cifras[i]);
        end loop;
      end if;
      v_sec := v_sec + 1;
      v_cab_fila := r;
      v_ult_tot := r;
      v_sdia := null; v_sdes := null; v_shas := null;
      a_label := '{}'; a_alias := '{}'; a_con := '{}'; a_clase := '{}'; a_cta := '{}'; a_dec := '{}'; a_cifras := '{}'; a_deli := '{}';
      for i in 1 .. v_nc loop
        v_al := fn_nomina_norm(v_cells[i]);
        v_m := case when v_al is null then null else v_map->v_al end;
        a_label  := a_label || fn_nomina_etiqueta(v_cells[i], i);
        a_alias  := a_alias || coalesce(v_al, '');
        a_con    := a_con || (v_m->>'concepto');
        a_clase  := a_clase || (case when v_cells[i] = '' then 'ignorar' else v_m->>'clase' end);
        a_cta    := a_cta || (v_m->>'cuenta');
        a_dec    := a_dec || (v_m->>'declara');
        a_cifras := a_cifras || 0;
        a_deli   := a_deli || false;
      end loop;
      continue;
    end if;

    -- Una nota suelta: «Check date: …» o «Pay period: …» (una o dos celdas).
    if v_ne <= 2 then
      select string_agg(q, ': ') into v_txt from unnest(v_cells) q where q <> '';
      if lower(v_txt) ~ '^(check date|pay date|payday|pay day|pay period|period)' then
        select coalesce(array_agg(distinct fn_nomina_fecha(m[1])), '{}') into v_fechas
          from regexp_matches(v_txt, c_fecha, 'g') m
         where fn_nomina_fecha(m[1]) is not null;
        if lower(v_txt) ~ '^(check date|pay date|payday|pay day)' and cardinality(v_fechas) = 1 then
          if v_sec = 0 then v_fdia := v_fechas[1]; else v_sdia := v_fechas[1]; end if;
        elsif lower(v_txt) ~ '^(pay period|period)' and cardinality(v_fechas) between 1 and 2 then
          if v_sec = 0 then
            v_fdes := (select min(q) from unnest(v_fechas) q); v_fhas := (select max(q) from unnest(v_fechas) q);
          else
            v_sdes := (select min(q) from unnest(v_fechas) q); v_shas := (select max(q) from unnest(v_fechas) q);
          end if;
        end if;
        continue;
      end if;
    end if;
    continue when v_sec = 0;   -- el preámbulo: no se guarda

    -- UN TÍTULO O UNA NOTA SUELTA dentro de una parte del archivo (una o dos celdas, y ninguna es una cifra): «Employer tax
    -- breakdown», el nombre de la empresa repetido entre dos partes… No es una fila de datos: se salta ANTES de leerla por
    -- columnas (si la primera columna de esa parte es de dinero, su texto no es «un importe que no es un importe»).
    if v_ne <= 2 and not exists (select 1 from unnest(v_cells) q
                                  where q <> '' and (q in ('-', '—', '–') or fn_nomina_monto(q) is not null)) then
      continue;
    end if;

    -- Una fila de una sección: de datos, de total, o un título.
    v_nom := null; v_ape := null; v_comp := null; v_emp := null; v_met := null; v_tipo := null; v_llave := null;
    v_dia := null; v_des := null; v_has := null; v_v := '{}'::jsonb; v_tiene := false; v_primera := null;
    for i in 1 .. least(v_nc, cardinality(a_label)) loop
      v_txt := v_cells[i];
      continue when v_txt = '';
      if v_primera is null then v_primera := fn_nomina_norm(v_txt); end if;
      if a_clase[i] is null then
        -- no se conoce: no se guarda; solo se cuenta si trae cifras, o se aparta si parece delicada
        if fn_nomina_delicado(v_txt) then
          a_deli[i] := true;
        else
          v_num := fn_nomina_monto(v_txt);
          if v_num is not null and v_num <> 0 then
            a_cifras[i] := a_cifras[i] + 1;
            v_tiene := true;
          end if;
        end if;
      elsif a_clase[i] in ('delicado', 'ignorar') or a_deli[i] then
        null;
      elsif a_clase[i] = any (c_dinero) or a_clase[i] = any (c_horas) then
        v_num := fn_nomina_monto(v_txt);
        if v_num is null then
          raise exception using errcode = 'MX005',
            message = format('La fila %s, columna «%s», no es %s (tiene %s caracteres que no forman un número). No se guardó nada. '
                             'Mira esa fila en el archivo: si es una nota o un título que Gusto puso en medio, bájalo otra vez sin '
                             'ella (o con otra forma del informe); si esa columna no lleva %s, corrige en los ajustes lo que el '
                             'mapeo dice de ella.', r, a_label[i],
                             case when a_clase[i] = any (c_horas) then 'un número de horas' else 'un importe' end, length(v_txt),
                             case when a_clase[i] = any (c_horas) then 'horas' else 'dinero' end);
        end if;
        if a_clase[i] = any (c_dinero) and scale(v_num) > 2 and v_num <> round(v_num, 2) then
          raise exception using errcode = 'MX005',
            message = format('La fila %s, columna «%s», trae un importe con más de dos decimales: el libro va en centavos y aquí no se '
                             'redondea nada. No se guardó nada.', r, a_label[i]);
        end if;
        if v_num <> 0 then
          v_v := v_v || jsonb_build_object(a_con[i], coalesce((v_v->>a_con[i])::numeric, 0) + v_num);
          v_tiene := true;
        end if;
      else
        if fn_nomina_delicado(v_txt) or length(v_txt) > 200 then
          raise exception using errcode = '22023',
            message = format('La fila %s, columna «%s», trae algo que no es lo que esa columna dice (parece un dato delicado, o es demasiado '
                             'largo). No se guardó nada: quita esa columna al bajar el archivo de Gusto y vuelve a subirlo.', r, a_label[i]);
        end if;
        case a_clase[i]
          when 'nombre' then v_nom := v_txt;
          when 'apellido' then v_ape := v_txt;
          when 'nombre_completo' then v_comp := v_txt;
          when 'empleado_id' then v_emp := v_txt;
          when 'metodo_pago' then v_met := v_txt;
          when 'tipo' then v_tipo := v_txt;
          when 'llave' then v_llave := v_txt;
          when 'segundo' then null;
          when 'periodo' then
            -- (el período en una sola celda: «01/03/2027 - 01/16/2027»)
            select coalesce(array_agg(distinct fn_nomina_fecha(m[1])), '{}') into v_fechas
              from regexp_matches(v_txt, c_fecha, 'g') m where fn_nomina_fecha(m[1]) is not null;
            if cardinality(v_fechas) not between 1 and 2 then
              raise exception using errcode = 'MX005',
                message = format('La fila %s, columna «%s», no es un período de pago (dos fechas: del … al …). No se guardó nada.', r, a_label[i]);
            end if;
            v_des := (select min(q) from unnest(v_fechas) q); v_has := (select max(q) from unnest(v_fechas) q);
          else
            -- una fecha
            if fn_nomina_fecha(v_txt) is null then
              raise exception using errcode = 'MX005',
                message = format('La fila %s, columna «%s», no es una fecha (MM/DD/AAAA o AAAA-MM-DD). No se guardó nada.', r, a_label[i]);
            end if;
            if a_clase[i] = 'dia_pago' then v_dia := fn_nomina_fecha(v_txt);
            elsif a_clase[i] = 'periodo_desde' then v_des := fn_nomina_fecha(v_txt);
            else v_has := fn_nomina_fecha(v_txt); end if;
        end case;
      end if;
    end loop;
    v_cand := nullif(btrim(coalesce(v_nom, '') || ' ' || coalesce(v_ape, '')), '');
    if v_cand is null then v_cand := v_comp; end if;
    -- ¿ES UNA FILA DE TOTAL? Por su primera celda («Totals», «Grand total», «Subtotal»…), o porque lo que trae donde iría la
    -- persona ES ese rótulo (el archivo puede traer otras columnas delante del nombre, y entonces «Totals» cae en la columna
    -- del nombre o del apellido: no es una persona que se llame así), o porque no trae persona y sí cifras.
    v_es_sub := coalesce(v_primera ~ '(^| )sub ?totals?( |$)', false)
                or exists (select 1 from unnest(array[fn_nomina_norm(v_nom), fn_nomina_norm(v_ape), fn_nomina_norm(v_comp),
                                                      fn_nomina_norm(v_emp), fn_nomina_norm(v_cand)]) q
                            where q ~ '^sub ?(totals?|totales?)$');
    v_es_tot := v_es_sub or coalesce(v_primera ~ '(^| )totals?( |$)', false)
                or exists (select 1 from unnest(array[fn_nomina_norm(v_nom), fn_nomina_norm(v_ape), fn_nomina_norm(v_comp),
                                                      fn_nomina_norm(v_emp), fn_nomina_norm(v_cand)]) q
                            where q ~ '^((grand|report|payroll|company|overall|all) )?(totals?|totales?)$')
                or (v_cand is null and v_emp is null and v_tiene);
    if v_es_tot then
      -- una fila de total: CONTROL, nunca suma
      v_tots := v_tots || jsonb_build_object('sec', v_sec, 'fila', r, 'desde_fila', case when v_es_sub then v_ult_tot else v_cab_fila end,
                                             'clase', case when v_es_sub then 'subtotal' else 'total' end, 'v', v_v);
      v_ult_tot := r;
      continue;
    end if;
    continue when v_cand is null and v_emp is null;   -- ni persona ni cifras: no dice nada
    if not v_tiene then
      -- una persona con todo en cero (no cobró nada en esta nómina), o un título de sección (una o dos celdas): no entra
      if v_ne > 2 then
        v_ceros := v_ceros || jsonb_build_object(v_sec::text, coalesce((v_ceros->>(v_sec::text))::int, 0) + 1);
      end if;
      continue;
    end if;
    v_cand := coalesce(v_cand, 'Empleado ' || left(v_emp, 12));
    v_data := v_data || jsonb_build_object(
      'sec', v_sec, 'fila', r, 'nombre', v_cand, 'clave', fn_nomina_clave(v_cand), 'gusto_emp', v_emp, 'metodo', v_met,
      'pk', coalesce('id:' || lower(v_emp), 'n:' || fn_nomina_clave(v_cand)),
      'dia', coalesce(v_dia, v_sdia, v_fdia), 'desde', coalesce(v_des, v_sdes, v_fdes), 'hasta', coalesce(v_has, v_shas, v_fhas),
      'tipo', v_tipo, 'llave', v_llave, 'v', v_v);
  end loop;
  if v_sec > 0 then
    for i in 1 .. cardinality(a_label) loop
      v_cols := v_cols || jsonb_build_object('sec', v_sec, 'n', i, 'columna', a_label[i], 'alias', a_alias[i], 'concepto', a_con[i],
                                             'clase', case when a_deli[i] then 'delicado' else a_clase[i] end, 'cuenta', a_cta[i],
                                             'declara', a_dec[i], 'cifras', a_cifras[i]);
    end loop;
  end if;
  if v_sec = 0 then
    select string_agg(format('la %s (%s celdas)', q.o, q.n), ', ' order by q.o) into v_txt
      from (select e.o, jsonb_array_length(e.f) as n
              from jsonb_array_elements(v_filas) with ordinality e(f, o)
             where jsonb_typeof(e.f) = 'array' and jsonb_array_length(e.f) >= 3
               and not exists (select 1 from jsonb_array_elements_text(e.f) c where btrim(c) <> '' and public.fn_nomina_monto(c) is not null
                                                                               and btrim(c) not in ('-', '—'))
             order by jsonb_array_length(e.f) desc, e.o limit 3) q;
    raise exception using errcode = 'MX009',
      message = format('No encontré la cabecera del archivo: ninguna fila tiene a la vez una columna de persona (el nombre del empleado) y una '
                       'de dinero (el bruto, el neto…) con un nombre que yo conozca. %sDi en qué fila está la cabecera (en la pantalla, aquí '
                       'abajo; la opción «fila_cabecera») y, después, qué es cada columna que no conozca; o baja de Gusto el «Payroll '
                       'journal» en CSV con sus columnas de siempre.',
                       coalesce('Las filas que parecen una cabecera: ' || v_txt || '. ', ''));
  end if;
  if jsonb_array_length(v_data) = 0 then
    raise exception using errcode = 'MX009',
      message = 'El archivo tiene cabecera pero ninguna fila de empleado con cifras: ¿es de una nómina sin nadie, o le falta la columna del '
                'nombre? Bájalo otra vez con «Employee first name» y «Employee last name» (o di qué columna es el nombre: Nómina → Ajustes '
                '→ el mapeo de las columnas → «Añadir o cambiar una»).';
  end if;
  select coalesce(array_agg(distinct q->>'columna' order by q->>'columna'), '{}') into v_delicado
    from jsonb_array_elements(v_cols) q where q->>'clase' = 'delicado';
  -- (la forma de cada parte del archivo: sus columnas, en orden; dos partes con la misma forma son del mismo tipo)
  select coalesce(jsonb_object_agg(q.sec, q.sig), '{}'::jsonb) into v_sig
    from (select c->>'sec' as sec, md5(string_agg(c->>'alias', '|' order by (c->>'n')::int)) as sig
            from jsonb_array_elements(v_cols) c group by c->>'sec') q;

  -- ============ SEGUNDA PARTE: las corridas ============
  -- (0) LO QUE UNA FILA NO TRAE LO HEREDA, si solo hay una posibilidad. El día de pago: el único del archivo (y si no, el que
  --     diga la pantalla). El período, el tipo y la llave de la nómina: los de las demás filas de su mismo día de pago. Así
  --     las filas de un resumen sin fechas caen en la misma nómina que su detalle (y no forman otra, que entraría dos veces).
  --     Con dos posibilidades no se adivina: el archivo se para.
  select case when count(distinct x.dia) = 1 then min(x.dia) end into v_un_dia
    from jsonb_to_recordset(v_data) as x(dia date) where x.dia is not null;
  v_un_dia := coalesce(v_un_dia, case when not exists (select 1 from jsonb_to_recordset(v_data) as x(dia date) where x.dia is not null)
                                      then fn_nomina_fecha(v_op->>'dia_pago') end);
  select coalesce(jsonb_agg(case when q->>'dia' is null and v_un_dia is not null then q || jsonb_build_object('dia', v_un_dia) else q end
                            order by (q->>'fila')::int), '[]'::jsonb)
    into v_data from jsonb_array_elements(v_data) q;
  select string_agg(format('la %s', q->>'fila'), ', ') into v_txt from jsonb_array_elements(v_data) q where q->>'dia' is null;
  if v_txt is not null then
    raise exception using errcode = 'MX009',
      message = format('No sé el día de pago de %s fila(s) (%s): el archivo no trae la columna del día de pago («Check date») en todas sus '
                       'partes, o trae varias nóminas. Bájalo de Gusto con esa columna (base «pay date», una nómina cada vez), o di cuál '
                       'es su día de pago (en la pantalla, aquí abajo; la opción «dia_pago») y se vuelve a leer. No se guardó nada.',
                       (select count(*) from jsonb_array_elements(v_data) q where q->>'dia' is null), left(v_txt, 200));
  end if;
  for d in
    select x.dia,
           count(distinct (x.desde, x.hasta)) filter (where x.desde is not null or x.hasta is not null) as n_per,
           count(*) filter (where x.desde is null and x.hasta is null) as sin_per,
           min(x.desde) filter (where x.desde is not null) as desde, min(x.hasta) filter (where x.hasta is not null) as hasta,
           count(distinct case when lower(x.tipo) ~ 'regular' then 'regular' else 'fuera_de_ciclo' end) filter (where x.tipo is not null) as n_tipo,
           count(*) filter (where x.tipo is null) as sin_tipo, min(x.tipo) filter (where x.tipo is not null) as tipo,
           count(distinct lower(x.llave)) filter (where x.llave is not null) as n_llave,
           count(*) filter (where x.llave is null) as sin_llave, min(x.llave) filter (where x.llave is not null) as llave
      from jsonb_to_recordset(v_data) as x(dia date, desde date, hasta date, tipo text, llave text)
     group by x.dia
  loop
    if (d.sin_per > 0 and d.n_per > 1) or (d.sin_tipo > 0 and d.n_tipo > 1) or (d.sin_llave > 0 and d.n_llave > 1) then
      raise exception using errcode = 'MX009',
        message = format('El archivo trae más de una nómina con día de pago %s y filas que no dicen de cuál son (les falta %s): no se '
                         'adivina. Bájalo de Gusto de una nómina cada vez, o solo con el detalle por nómina. No se guardó nada.',
                         fn_nomina_dia(d.dia),
                         concat_ws(', ', case when d.sin_per > 0 and d.n_per > 1 then 'el período de pago' end,
                                         case when d.sin_tipo > 0 and d.n_tipo > 1 then 'el tipo de nómina' end,
                                         case when d.sin_llave > 0 and d.n_llave > 1 then 'la llave de la nómina' end));
    end if;
    if (d.sin_per > 0 and d.n_per = 1) or (d.sin_tipo > 0 and d.n_tipo = 1) or (d.sin_llave > 0 and d.n_llave = 1) then
      select jsonb_agg(case when (q->>'dia')::date = d.dia
                            then q || jsonb_strip_nulls(jsonb_build_object(
                                        'desde', case when q->>'desde' is null and q->>'hasta' is null and d.n_per = 1 then d.desde end,
                                        'hasta', case when q->>'desde' is null and q->>'hasta' is null and d.n_per = 1 then d.hasta end,
                                        'tipo', case when q->>'tipo' is null and d.n_tipo = 1 then d.tipo end,
                                        'llave', case when q->>'llave' is null and d.n_llave = 1 then d.llave end))
                            else q end order by (q->>'fila')::int)
        into v_data from jsonb_array_elements(v_data) q;
    end if;
  end loop;
  -- (lo que diga la pantalla, para lo que el archivo no trae en ninguna parte)
  select jsonb_agg(q || jsonb_strip_nulls(jsonb_build_object(
                          'desde', case when q->>'desde' is null and q->>'hasta' is null then fn_nomina_fecha(v_op->>'periodo_desde') end,
                          'hasta', case when q->>'desde' is null and q->>'hasta' is null then fn_nomina_fecha(v_op->>'periodo_hasta') end,
                          'tn', case when coalesce(q->>'tipo', v_op->>'tipo') is null or lower(coalesce(q->>'tipo', v_op->>'tipo')) ~ 'regular'
                                     then 'regular' else 'fuera_de_ciclo' end))
                   order by (q->>'fila')::int)
    into v_data from jsonb_array_elements(v_data) q;
  if exists (select 1 from jsonb_array_elements(v_data) q
              where (q->>'desde' is null) <> (q->>'hasta' is null) or (q->>'desde')::date > (q->>'hasta')::date
                 or (q->>'hasta')::date - (q->>'desde')::date > 92) then
    raise exception using errcode = 'MX005',
      message = 'El período de pago de alguna fila viene a medias, al revés o es de más de tres meses. No se guardó nada.';
  end if;

  for k in
    select g.*, row_number() over (order by g.fila)::int as n
      from (select x.dia, x.desde, x.hasta, x.tn, x.llave, min(x.fila) as fila, min(x.tipo) as tipo_texto,
                   array_agg(distinct x.sec) as secs, bool_or(x.tipo is null) as sin_tipo
              from jsonb_to_recordset(v_data) as x(sec int, fila int, dia date, desde date, hasta date, tipo text, tn text, llave text)
             group by x.dia, x.desde, x.hasta, x.tn, x.llave) g
     order by g.fila
  loop
    v_n := v_n + 1;
    v_secs := k.secs;
    v_avisos := '[]'::jsonb;
    v_desc := '{}';
    -- (el mapeo de los conceptos de sus secciones, y qué grupos traen sus partes y cuáles solo su total)
    select coalesce(jsonb_object_agg(q.concepto, jsonb_build_object('clase', q.clase, 'cuenta', q.cuenta, 'declara', q.declara,
                                                                    'columna', q.columna)), '{}'::jsonb)
      into v_cm
      from (select distinct on (c->>'concepto') c->>'concepto' as concepto, c->>'clase' as clase, c->>'cuenta' as cuenta,
                   c->>'declara' as declara, c->>'columna' as columna
              from jsonb_array_elements(v_cols) c
             where (c->>'sec')::int = any (v_secs) and c->>'concepto' is not null and c->>'clase' not in ('delicado', 'ignorar')
             order by c->>'concepto', (c->>'sec')::int, (c->>'n')::int) q;
    select coalesce(jsonb_object_agg(q.clase, true), '{}'::jsonb) into v_pres
      from (select distinct c->>'clase' as clase from jsonb_array_elements(v_cols) c
             where (c->>'sec')::int = any (v_secs) and c->>'clase' is not null) q;
    if not (v_pres ? 'neto') then
      v_desc := v_desc || 'el archivo no trae la columna del neto («Net pay»): sin ella no se puede comprobar que cada fila cuadra'::text;
    end if;
    if not (v_pres ? 'bruto' or v_pres ? 'bruto_total') then
      v_desc := v_desc || 'el archivo no trae el bruto («Gross earnings» o sus partes)'::text;
    end if;
    v_pers := '[]'::jsonb;
    t_bru := 0; t_ime := 0; t_ded := 0; t_net := 0; t_ree := 0; t_imp := 0; t_ben := 0; t_hor := 0; t_rin := 0;
    v_firma := '';
    v_fb := '{}'; v_fn := '{}';
    v_dec := '{}'::jsonb;
    v_rep := false;
    for pr in
      -- cada persona de la corrida: sus filas (por su identificador de Gusto si el archivo lo trae; si no, por su nombre). UN
      -- CONCEPTO, UNA VEZ: las filas de una persona DENTRO DE UNA MISMA PARTE del archivo (la misma tabla, bajo su cabecera) se
      -- suman (dos filas suyas); si el mismo concepto sale además en OTRA parte del archivo —tenga otra cabecera (el resumen y
      -- el detalle de lo patronal) o LA MISMA (el resumen por empleado y, debajo, el de su nómina con las mismas columnas)—,
      -- tiene que decir lo mismo y cuenta una sola vez; si dice otra cosa, no cuadra. (Antes, dos partes con la misma cabecera
      -- se sumaban: el resumen y su detalle con las mismas columnas entraban al doble, con solo un aviso.)
      with f as (
             select x.pk, x.sec, x.fila, x.nombre, x.clave, x.gusto_emp, x.metodo, x.v
               from jsonb_to_recordset(v_data) as x(pk text, sec int, fila int, nombre text, clave text, gusto_emp text, metodo text,
                                                    dia date, desde date, hasta date, tn text, llave text, v jsonb)
              where x.dia = k.dia and x.desde is not distinct from k.desde and x.hasta is not distinct from k.hasta
                and x.tn = k.tn and x.llave is not distinct from k.llave),
           s as (select f.pk, f.sec, e.key, sum(e.value::numeric) as v
                   from f, jsonb_each_text(f.v) e group by f.pk, f.sec, e.key),
           c as (select s.pk, s.key, min(s.v) as v, count(distinct s.v) as nd,
                        string_agg(distinct trim_scale(s.v)::text, ' y ') as vs
                   from s group by s.pk, s.key)
      select f.pk, (array_agg(f.nombre order by f.fila))[1] as nombre, (array_agg(f.clave order by f.fila))[1] as clave,
             min(f.fila) as fila, max(f.gusto_emp) as gusto_emp, max(f.metodo) as metodo,
             (select max(q.n) from (select count(*) as n from f f2 where f2.pk = f.pk group by f2.sec) q) as filas,
             -- (¿sale en dos partes del archivo con LA MISMA cabecera? Entonces cuenta una vez, y se dice)
             (select count(distinct f2.sec) > count(distinct v_sig->>(f2.sec::text)) from f f2 where f2.pk = f.pk) as repetida,
             (select coalesce(jsonb_object_agg(c.key, c.v), '{}'::jsonb) from c where c.pk = f.pk) as v,
             (select string_agg(format('«%s» sale en dos partes del archivo con cifras distintas (%s)', coalesce(v_cm->c.key->>'columna', c.key), c.vs),
                                '; ' order by c.key) from c where c.pk = f.pk and c.nd > 1) as choque
        from f
       group by f.pk
       order by min(f.fila)
    loop
      -- (sus sumas por clase)
      select coalesce(jsonb_object_agg(q.clase, q.s), '{}'::jsonb) into v_s
        from (select v_cm->e.key->>'clase' as clase, sum(e.value::numeric) as s
                from jsonb_each_text(pr.v) e where v_cm ? e.key group by 1) q;
      v_bru := case when v_pres ? 'bruto' then coalesce((v_s->>'bruto')::numeric, 0) else coalesce((v_s->>'bruto_total')::numeric, 0) end;
      v_ime := case when v_pres ? 'imp_empleado' then coalesce((v_s->>'imp_empleado')::numeric, 0)
                    else coalesce((v_s->>'imp_empleado_total')::numeric, 0) end;
      v_ded := case when v_pres ? 'deduccion' then coalesce((v_s->>'deduccion')::numeric, 0)
                    else coalesce((v_s->>'deduccion_total')::numeric, 0) end;
      v_ree := case when v_pres ? 'reembolso' then coalesce((v_s->>'reembolso')::numeric, 0)
                    else coalesce((v_s->>'reembolso_total')::numeric, 0) end;
      v_imp := case when v_pres ? 'imp_patron' then coalesce((v_s->>'imp_patron')::numeric, 0)
                    else coalesce((v_s->>'imp_patron_total')::numeric, 0) end;
      v_ben := case when v_pres ? 'ben_patron' then coalesce((v_s->>'ben_patron')::numeric, 0)
                    else coalesce((v_s->>'ben_patron_total')::numeric, 0) end;
      v_net := coalesce((v_s->>'neto')::numeric, 0);
      v_hor := case when v_pres ? 'horas' then coalesce((v_s->>'horas')::numeric, 0) end;
      v_hfu := case when v_pres ? 'horas_fuera' then coalesce((v_s->>'horas_fuera')::numeric, 0) end;
      -- EL NETO: bruto − lo retenido − las deducciones. (Así lo define Gusto; el reembolso va aparte y el cheque es neto +
      -- reembolso. Si en el archivo el neto de alguien ya trae su reembolso —y solo entonces cuadra—, se toma así y se dice.)
      v_base := v_bru - v_ime - v_ded;
      v_incl := v_pres ? 'neto' and v_net <> v_base and v_ree <> 0 and v_net = v_base + v_ree;
      -- (sus compuertas)
      select concat_ws('; ',
               pr.choque,
               case when v_pres ? 'bruto' and v_pres ? 'bruto_total' and coalesce((v_s->>'bruto')::numeric, 0) <> coalesce((v_s->>'bruto_total')::numeric, 0)
                    then format('el bruto: su columna dice %s y sus partes suman %s', fn_nomina_usd(coalesce((v_s->>'bruto_total')::numeric, 0)),
                                fn_nomina_usd(coalesce((v_s->>'bruto')::numeric, 0))) end,
               case when v_pres ? 'imp_empleado' and v_pres ? 'imp_empleado_total'
                         and coalesce((v_s->>'imp_empleado')::numeric, 0) <> coalesce((v_s->>'imp_empleado_total')::numeric, 0)
                    then format('lo retenido: su total dice %s y sus partes suman %s', fn_nomina_usd(coalesce((v_s->>'imp_empleado_total')::numeric, 0)),
                                fn_nomina_usd(coalesce((v_s->>'imp_empleado')::numeric, 0))) end,
               case when v_pres ? 'deduccion' and v_pres ? 'deduccion_total'
                         and coalesce((v_s->>'deduccion')::numeric, 0) <> coalesce((v_s->>'deduccion_total')::numeric, 0)
                    then format('las deducciones: su total dice %s y sus partes suman %s', fn_nomina_usd(coalesce((v_s->>'deduccion_total')::numeric, 0)),
                                fn_nomina_usd(coalesce((v_s->>'deduccion')::numeric, 0))) end,
               case when v_pres ? 'reembolso' and v_pres ? 'reembolso_total'
                         and coalesce((v_s->>'reembolso')::numeric, 0) <> coalesce((v_s->>'reembolso_total')::numeric, 0)
                    then format('los reembolsos: su total dice %s y sus partes suman %s', fn_nomina_usd(coalesce((v_s->>'reembolso_total')::numeric, 0)),
                                fn_nomina_usd(coalesce((v_s->>'reembolso')::numeric, 0))) end,
               case when v_pres ? 'imp_patron' and v_pres ? 'imp_patron_total'
                         and coalesce((v_s->>'imp_patron')::numeric, 0) <> coalesce((v_s->>'imp_patron_total')::numeric, 0)
                    then format('los impuestos del patrón: su total dice %s y sus partes suman %s',
                                fn_nomina_usd(coalesce((v_s->>'imp_patron_total')::numeric, 0)), fn_nomina_usd(coalesce((v_s->>'imp_patron')::numeric, 0))) end,
               case when v_pres ? 'ben_patron' and v_pres ? 'ben_patron_total'
                         and coalesce((v_s->>'ben_patron')::numeric, 0) <> coalesce((v_s->>'ben_patron_total')::numeric, 0)
                    then format('los beneficios del patrón: su total dice %s y sus partes suman %s',
                                fn_nomina_usd(coalesce((v_s->>'ben_patron_total')::numeric, 0)), fn_nomina_usd(coalesce((v_s->>'ben_patron')::numeric, 0))) end,
               case when v_pres ? 'neto' and v_base <> v_net and not v_incl
                    then format('bruto %s − retenido %s − deducciones %s = %s, y su neto dice %s (diferencia %s)', fn_nomina_usd(v_bru),
                                fn_nomina_usd(v_ime), fn_nomina_usd(v_ded), fn_nomina_usd(v_base), fn_nomina_usd(v_net),
                                fn_nomina_usd(v_net - v_base)) end,
               case when v_pres ? 'cheque_total' and (case when v_incl then v_net else v_net + v_ree end) <> coalesce((v_s->>'cheque_total')::numeric, 0)
                    then format('neto %s%s = %s, y su cheque dice %s', fn_nomina_usd(v_net),
                                case when v_incl then ' (que ya trae su reembolso)' else ' + reembolsos ' || fn_nomina_usd(v_ree) end,
                                fn_nomina_usd(case when v_incl then v_net else v_net + v_ree end),
                                fn_nomina_usd(coalesce((v_s->>'cheque_total')::numeric, 0))) end)
        into v_txt;
      v_txt := nullif(v_txt, '');
      if v_txt is not null then
        v_desc := v_desc || format('%s (fila %s): %s%s', pr.nombre, pr.fila, v_txt,
                                   case when pr.choque is not null and pr.repetida
                                        then ' (esas dos partes del archivo traen las mismas columnas: si son dos nóminas del mismo día, baja el '
                                             'archivo de una nómina cada vez; si es la misma nómina repetida, bájalo solo con el resumen)'
                                        else '' end);
      end if;
      v_rep := v_rep or (pr.repetida and pr.choque is null);
      if pr.filas > 1 then
        v_avisos := v_avisos || jsonb_build_object('codigo', 'persona_repetida', 'texto',
          format('%s aparece en %s filas de la misma parte del archivo, en esta nómina: se sumaron como una sola persona. Si son dos personas '
                 'con el mismo nombre, baja el archivo con el identificador del empleado («Employee uuid»).', pr.nombre, pr.filas));
      end if;
      if v_incl then
        v_avisos := v_avisos || jsonb_build_object('codigo', 'neto_con_reembolso', 'texto',
          format('%s: en este archivo su neto (%s) ya trae su reembolso (%s): se tomó así (lo que se le paga es el neto, no el neto más el '
                 'reembolso).', pr.nombre, fn_nomina_usd(v_net), fn_nomina_usd(v_ree)));
      end if;
      if v_pres ? 'costo_total' and v_bru + v_imp + v_ben <> coalesce((v_s->>'costo_total')::numeric, 0) then
        v_avisos := v_avisos || jsonb_build_object('codigo', 'costo_total', 'texto',
          format('%s: bruto + lo patronal suma %s y la columna del costo total del patrón dice %s. No frena: esa columna no se postea.',
                 pr.nombre, fn_nomina_usd(v_bru + v_imp + v_ben), fn_nomina_usd(coalesce((v_s->>'costo_total')::numeric, 0))));
      end if;
      -- (sus líneas: las partes de cada grupo, o su total si el archivo no trae las partes; el neto; las horas)
      select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
               'concepto', q.concepto, 'clase', q.clase, 'cuenta', q.cuenta, 'declara', q.declara, 'columna', q.columna,
               'monto', case when q.clase not in ('horas', 'horas_fuera') then q.val end,
               'horas', case when q.clase in ('horas', 'horas_fuera') then q.val end)) order by q.concepto), '[]'::jsonb)
        into v_lin
        from (select e.key as concepto,
                     case when v_cm->e.key->>'clase' like '%\_total' then replace(v_cm->e.key->>'clase', '_total', '') else v_cm->e.key->>'clase' end as clase,
                     v_cm->e.key->>'cuenta' as cuenta, v_cm->e.key->>'declara' as declara, v_cm->e.key->>'columna' as columna,
                     e.value::numeric as val
                from jsonb_each_text(pr.v) e
               where v_cm ? e.key and e.value::numeric <> 0
                 and (   v_cm->e.key->>'clase' in ('bruto', 'imp_empleado', 'deduccion', 'reembolso', 'imp_patron', 'ben_patron', 'neto',
                                                   'horas', 'horas_fuera')
                      or (v_cm->e.key->>'clase' like '%\_total'
                          and replace(v_cm->e.key->>'clase', '_total', '') = any (c_grupos)
                          and not v_pres ? replace(v_cm->e.key->>'clase', '_total', '')))) q;
      v_pers := v_pers || jsonb_build_object(
        'n', jsonb_array_length(v_pers) + 1, 'nombre', pr.nombre, 'clave', pr.clave, 'gusto_id', pr.gusto_emp, 'metodo_pago', pr.metodo,
        'bruto', v_bru, 'imp_empleado', v_ime, 'deducciones', v_ded, 'neto', v_net, 'reembolsos', v_ree, 'imp_patron', v_imp,
        'ben_patron', v_ben, 'horas', v_hor, 'horas_fuera', v_hfu, 'neto_con_reembolso', v_incl, 'cuadra', v_txt is null, 'descuadre', v_txt,
        'lineas', v_lin);
      t_bru := t_bru + v_bru; t_ime := t_ime + v_ime; t_ded := t_ded + v_ded; t_net := t_net + v_net; t_ree := t_ree + v_ree;
      t_imp := t_imp + v_imp; t_ben := t_ben + v_ben; t_hor := t_hor + coalesce(v_hor, 0);
      t_rin := t_rin + case when v_incl then v_ree else 0 end;
      -- (la firma: sus cifras concepto por concepto, escritas siempre igual —1958, 1958.0 y 1958.00 son la misma—; y, aparte,
      -- su bruto y su neto para la huella de las personas)
      v_firma := v_firma || pr.clave || ':' || (select coalesce(string_agg(z->>'concepto' || '=' || coalesce(round((z->>'monto')::numeric, 2)::text,
                                                                                                           trim_scale((z->>'horas')::numeric)::text),
                                                                           ',' order by z->>'concepto'), '')
                                                  from jsonb_array_elements(v_lin) z) || ';';
      v_fb := v_fb || v_bru; v_fn := v_fn || v_net;
      -- (lo que amarra con las declaraciones, por renglón; un impuesto sin su renglón se cuenta aparte: «sin_renglon»)
      select v_dec || coalesce(jsonb_object_agg(q.d, q.s), '{}'::jsonb) into v_dec
        from (select coalesce(z->>'declara', 'sin_renglon') as d,
                     coalesce((v_dec->>coalesce(z->>'declara', 'sin_renglon'))::numeric, 0) + sum((z->>'monto')::numeric) as s
                from jsonb_array_elements(v_lin) z
               where z->>'declara' is not null or z->>'clase' in ('imp_empleado', 'imp_patron') group by 1) q;
    end loop;
    if v_rep then
      v_avisos := v_avisos || jsonb_build_object('codigo', 'parte_repetida', 'texto',
        'El archivo trae esta nómina en dos partes con las mismas columnas (el resumen por empleado y, otra vez, el de su nómina), y '
        'cada persona dice lo mismo en las dos: se contó UNA vez. Si de verdad fueran dos pagos distintos del mismo día con las mismas '
        'cifras, baja el archivo de una nómina cada vez.');
    end if;
    -- (las filas de total del archivo contra la suma de sus filas, parte por parte del archivo)
    v_tarch := null;
    for pr in
      select t.sec, t.fila, t.desde_fila, t.clase, t.v,
             (select coalesce(jsonb_object_agg(z.kk, z.vv), '{}'::jsonb)
                from (select e.key as kk, sum(e.value::numeric) as vv
                        from jsonb_array_elements(v_data) q2, jsonb_each_text(q2->'v') e
                       where (q2->>'sec')::int = t.sec and (q2->>'fila')::int > t.desde_fila and (q2->>'fila')::int < t.fila
                       group by e.key) z) as suma,
             (select count(*) from jsonb_array_elements(v_data) q2
               where (q2->>'sec')::int = t.sec and (q2->>'fila')::int > t.desde_fila and (q2->>'fila')::int < t.fila) as filas,
             (select count(*) from jsonb_array_elements(v_data) q2
               where (q2->>'sec')::int = t.sec and (q2->>'fila')::int > t.desde_fila and (q2->>'fila')::int < t.fila
                 and (q2->>'dia')::date = k.dia and (q2->>'desde') is not distinct from k.desde::text
                 and (q2->>'hasta') is not distinct from k.hasta::text and (q2->>'llave') is not distinct from k.llave
                 and q2->>'tn' = k.tn) as suyas
        from jsonb_to_recordset(v_tots) as t(sec int, fila int, desde_fila int, clase text, v jsonb)
       where t.sec = any (v_secs)
       order by t.fila
    loop
      continue when pr.suyas = 0;
      select string_agg(format('«%s»: la fila de total dice %s y las filas suman %s', coalesce(v_cm->q.kk->>'columna', q.kk),
                               trim_scale(q.t), trim_scale(q.s)), '; ' order by q.kk)
        into v_txt
        from (select coalesce(a.key, b.key) as kk, coalesce(a.value::numeric, 0) as t, coalesce(b.value::numeric, 0) as s
                from jsonb_each_text(pr.v) a full join jsonb_each_text(pr.suma) b on b.key = a.key) q
       where q.t <> q.s;
      if v_txt is not null then
        v_desc := v_desc || format('la fila de total (fila %s) no es la suma de las %s filas de arriba: %s', pr.fila, pr.filas, left(v_txt, 600));
      end if;
      if pr.clase = 'total' and pr.suyas = pr.filas and pr.suyas = jsonb_array_length(v_pers) and v_tarch is null then
        v_tarch := pr.v;
      end if;
    end loop;
    if not exists (select 1 from jsonb_array_elements(v_tots) t where (t->>'sec')::int = any (v_secs)) then
      v_avisos := v_avisos || jsonb_build_object('codigo', 'sin_fila_total', 'texto',
        'El archivo no trae fila de total: cada persona se comprobó por su cuenta (bruto − retenido − deducciones = neto), pero el total '
        'del archivo no se pudo comparar con nada.');
    end if;
    if k.sin_tipo and not v_op ? 'tipo' then
      v_avisos := v_avisos || jsonb_build_object('codigo', 'sin_tipo', 'texto',
        'El archivo no dice qué tipo de nómina es («Payroll type»): se toma por una nómina regular. Si es un bono o una corrección, dilo '
        'antes de postearla (que no se quede con las horas del período).');
    end if;
    if k.desde is null then
      v_avisos := v_avisos || jsonb_build_object('codigo', 'sin_periodo', 'texto',
        'El archivo no trae el período de pago («Pay period start» y «Pay period end»): sin él no hay horas con qué repartir a la gente de '
        'campo. Dilo antes de postearla.');
    end if;
    select coalesce(sum((e.value)::int), 0) into v_nceros from jsonb_each_text(v_ceros) e where (e.key)::int = any (v_secs);
    if v_nceros > 0 then
      v_avisos := v_avisos || jsonb_build_object('codigo', 'filas_en_cero', 'texto',
        format('%s fila(s) del archivo traen a alguien con todo en cero (no cobró nada en esta nómina): no entran.', v_nceros));
    end if;
    v_key := case when k.llave is not null then 'id:' || lower(k.llave)
                  else 'f:' || k.dia || '|' || coalesce(k.desde::text, '') || '|' || coalesce(k.hasta::text, '') || '|' || k.tn end;
    v_cdesc := to_jsonb(v_desc);
    v_corr := v_corr || jsonb_build_object(
      'n', v_n, 'llave', v_key, 'firma', md5(v_firma),
      'firma_personas', (select count(*) || ':' || md5(coalesce(string_agg(round(t.b, 2) || ':' || round(t.n, 2), ',' order by t.b, t.n), ''))
                           from unnest(v_fb, v_fn) as t(b, n)),
      'dia_pago', k.dia, 'periodo_desde', k.desde, 'periodo_hasta', k.hasta,
      'tipo', k.tn, 'tipo_texto', left(coalesce(k.tipo_texto, v_op->>'tipo'), 60), 'gusto_id', k.llave,
      'personas', v_pers,
      'totales', jsonb_build_object('personas', jsonb_array_length(v_pers), 'bruto', t_bru, 'imp_empleado', t_ime, 'deducciones', t_ded,
                                    'neto', t_net, 'reembolsos', t_ree, 'reembolsos_en_neto', t_rin, 'imp_patron', t_imp,
                                    'ben_patron', t_ben, 'horas', t_hor),
      'declara', v_dec, 'cuadra', cardinality(v_desc) = 0, 'descuadres', v_cdesc,
      'columnas', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                            'columna', c->>'columna', 'concepto', case when c->>'clase' = 'delicado' then null else c->>'concepto' end,
                            'clase', c->>'clase', 'cuenta', case when c->>'clase' = 'delicado' then null else c->>'cuenta' end,
                            'cifras', case when c->>'clase' is null then (c->>'cifras')::int end))
                          order by (c->>'sec')::int, (c->>'n')::int), '[]'::jsonb)
                     from jsonb_array_elements(v_cols) c where (c->>'sec')::int = any (v_secs) and c->>'alias' <> ''),
      'sin_clasificar', (select coalesce(jsonb_agg(jsonb_build_object('columna', c->>'columna', 'celdas', (c->>'cifras')::int)
                                                   order by (c->>'sec')::int, (c->>'n')::int), '[]'::jsonb)
                           from jsonb_array_elements(v_cols) c
                          where (c->>'sec')::int = any (v_secs) and c->>'clase' is null and (c->>'cifras')::int > 0),
      'totales_archivo', v_tarch, 'avisos', v_avisos);
  end loop;
  return jsonb_build_object(
    'archivo', jsonb_build_object('nombre', btrim(p_archivo->>'nombre'), 'sha256', p_archivo->>'sha256', 'bytes', (p_archivo->>'bytes')::bigint,
                                  'filas', v_nf),
    'delicado', to_jsonb(v_delicado), 'corridas', v_corr);
end $$;
revoke execute on function public.fn_nomina_leer(jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_nomina_leer(jsonb, jsonb) to authenticated;
comment on function public.fn_nomina_leer(jsonb, jsonb) is 'c15: lee las celdas de un archivo de nómina ({nombre, sha256, bytes, filas: [[celda, …], …]}, todas como texto) y devuelve lo que entendió, sin escribir nada: sus corridas (una por día de pago, período, tipo y llave), cada una con sus personas (totales, líneas por concepto, si cuadra y dónde no), sus totales, cómo se leyó cada columna, las que traen cifras y el mapeo no conoce, la comparación con las filas de total del archivo y sus avisos; y los rótulos de las columnas delicadas, que no se leen. Un concepto cuenta una vez por persona: si sale en dos partes del archivo (un resumen y su detalle, con otra cabecera o con la misma) tiene que decir lo mismo; solo se suman dos filas suyas de una misma parte. Lo que una fila no trae (el período, el tipo) lo hereda de las demás filas de su día de pago si solo hay una posibilidad. Opciones: fila_cabecera, dia_pago, periodo_desde y periodo_hasta, tipo. Ningún mensaje repite el valor de una celda. La usan el ensayo y la importación. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 9. EL ENSAYO Y LA IMPORTACIÓN.
--    · fn_nomina_ensayo: lo que se entendería del archivo, sin guardar
--      nada: qué columna fue a qué concepto, qué se ignoró, qué no se
--      conoce, si cuadra, si esa nómina ya estaba, y quién es cada persona
--      (enlazada, por enlazar, y con qué perfil se propone).
--    · fn_nomina_importar: guarda cada nómina nueva del archivo (la corrida,
--      sus personas y sus líneas). NO ENTRA DOS VECES (fn_nomina_ya): una
--      nómina del archivo «ya está» si hay una corrida viva (importada o
--      posteada) con su misma llave (la de Gusto, si el archivo la trae; si
--      no, su día de pago, su período y su tipo), o del mismo día de pago y
--      del mismo tipo con un período que no la contradiga (el mismo, o una
--      de las dos sin período) y sin dos llaves de Gusto distintas. Así la
--      misma nómina bajada de Gusto de dos formas (con más o menos
--      columnas, con o sin su llave, con o sin su período) no entra dos
--      veces. Con las MISMAS cifras contesta «ya_estaba»; con OTRAS no entra
--      sola («otra_distinta») y Edgar dice qué es:
--        {"reemplazar": true}   la que estaba —importada y sin postear— se
--                               descarta y entra esta (el archivo corregido,
--                               o subido otra vez con el mapeo ya completo);
--        {"otra_nomina": true}  son dos nóminas distintas del mismo día (dos
--                               bonos): entra además de la otra.
--      Una que ya está POSTEADA no se reemplaza: se anula antes.
--    · Una corrida que no cuadra o que trae columnas sin clasificar ENTRA
--      (queda importada, a la vista, con su porqué) pero no se puede postear.
--    Lo que cobra cada persona: las dos piden el código del teléfono.
-- ---------------------------------------------------------------------
-- El perfil de la app que se le propone a una persona del journal por su
-- nombre: el ÚNICO perfil activo cuyas palabras son las de su nombre (o
-- están todas dentro, o al revés: «Edgar» y «Edgar Apellido») y que todavía
-- no está enlazado con nadie de la nómina. Con dos candidatos no se propone
-- ninguno. La clase, la que sale de su rol (dueño → oficial; campo → campo).
create or replace function public.fn_nomina_propone(p_clave text)
returns table (usuario_id uuid, perfil text, clase text)
language sql stable
set search_path = public, pg_temp
as $$
  select (array_agg(x.id))[1], min(x.nombre), min(case x.rol when 'dueno' then 'oficial' when 'campo' then 'campo' end)
    from public.perfiles x
   where coalesce(x.activo, true) and p_clave is not null
     and (string_to_array(public.fn_nomina_clave(x.nombre), ' ') <@ string_to_array(p_clave, ' ')
          or string_to_array(p_clave, ' ') <@ string_to_array(public.fn_nomina_clave(x.nombre), ' '))
     and not exists (select 1 from public.nomina_personas o where o.usuario_id = x.id)
     and (select public.fn_nomina_ve())
  having count(*) = 1
$$;
revoke execute on function public.fn_nomina_propone(text) from public, anon, service_role;
grant  execute on function public.fn_nomina_propone(text) to authenticated;
comment on function public.fn_nomina_propone(text) is 'c15: el perfil de la app que se le propone a una persona del journal por su nombre (su clave): el único perfil activo con las mismas palabras —o con todas dentro, o al revés— que todavía no está enlazado con nadie de la nómina, y la clase que sale de su rol (dueño → oficial; campo → campo). Con dos candidatos, ninguno. Es solo una propuesta: Edgar la confirma. A quien no es el dueño, nada.';

-- ¿ESTA NÓMINA YA ESTÁ? Las corridas vivas (importadas o posteadas) que son
-- la misma nómina que una leída de un archivo (p_c: como la devuelve
-- fn_nomina_leer). Una nómina es «la misma» que otra viva por dos caminos:
--   POR SU LLAVE: la misma llave; o el mismo día de pago y el mismo tipo,
--     con un período que no la contradiga y sin dos llaves de Gusto
--     distintas;
--   POR SUS PERSONAS Y SUS CIFRAS (firma_personas: cuántas son y el bruto y
--     el neto de cada una): las mismas, con el mismo día de pago —diga lo
--     que diga su tipo, su período o su llave: la misma nómina bajada sin la
--     columna del tipo entra como «regular» y con ella como «fuera de
--     ciclo»—, o con otro día de pago y un período que se pisa con el suyo
--     (el día de pago dicho a mano, mal); o, si a una de las dos le falta
--     el período (un resumen sin fechas, con su día de pago dicho a mano),
--     con el día de pago a menos de una semana (la nómina es cada dos
--     semanas: dos nóminas distintas con las mismas cifras caen a 14 días);
--     o si salen DEL MISMO ARCHIVO (su sha256) y son la misma nómina
--     dentro de él (su número), diga el día que diga quien lo sube. Dos
--     nóminas de verdad distintas no
--     traen a las mismas personas con el mismo bruto y el mismo neto el
--     mismo día (y si alguna vez pasa —dos bonos iguales—, Edgar lo dice con
--     su porqué).
-- Devuelve nulo si ninguna; si no, {igual: hay una con las mismas cifras
-- concepto por concepto; misma: por sus personas y sus cifras; otro_dia (y
-- por qué es la misma con otro día: mismo_archivo, o cerca —sin período y a
-- menos de una semana—; si ninguna de las dos, por su período);
-- corrida, estado, tipo, dia_pago, bruto, neto, personas, archivo,
-- importada_el, posteadas, importadas: los ids de las que solo están
-- importadas; lee_distinto: la que está —sin postear— se leyó con otro mapeo
-- (le quedaban columnas sin clasificar, o no cuadraba) y hoy se leería bien}.
create or replace function public.fn_nomina_ya(p_c jsonb) returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  with e0 as (
    -- (mismo_archivo: sale del mismo archivo —su sha256— y es la misma nómina dentro de él —su número—: las varias nóminas de un
    -- archivo de un rango de fechas no son «la misma» entre sí por salir de él. cerca: a una de las dos le falta el período y
    -- sus días de pago, distintos, quedan a menos de una semana)
    select c.*,
           (p_c->>'sha256' is not null and c.n = (p_c->>'n')::int
            and exists (select 1 from public.nomina_archivos a where a.id = c.archivo_id and a.sha256 = p_c->>'sha256')) as mismo_archivo,
           ((c.periodo_desde is null or p_c->>'periodo_desde' is null) and c.dia_pago <> (p_c->>'dia_pago')::date
            and abs(c.dia_pago - (p_c->>'dia_pago')::date) <= 6) as cerca
      from public.nomina_corridas c
     where c.estado in ('importada', 'posteada')),
  e as (
    select c.id, c.estado, c.tipo, c.firma, c.dia_pago, c.bruto, c.neto, c.personas, c.importada_el, c.archivo_id,
           c.cuadra, c.sin_clasificar, c.mismo_archivo, c.cerca,
           (   split_part(c.llave, '#', 1) = p_c->>'llave'
            or (c.dia_pago = (p_c->>'dia_pago')::date and c.tipo = p_c->>'tipo'
                and (c.periodo_desde is null or p_c->>'periodo_desde' is null
                     or (c.periodo_desde = (p_c->>'periodo_desde')::date and c.periodo_hasta = (p_c->>'periodo_hasta')::date))
                and not (c.gusto_id is not null and p_c->>'gusto_id' is not null and lower(c.gusto_id) <> lower(p_c->>'gusto_id')))) as por_llave,
           (c.firma_personas is not null and c.firma_personas = p_c->>'firma_personas'
            and (   c.dia_pago = (p_c->>'dia_pago')::date
                 or (c.periodo_desde is not null and p_c->>'periodo_desde' is not null
                     and c.periodo_desde <= (p_c->>'periodo_hasta')::date and c.periodo_hasta >= (p_c->>'periodo_desde')::date)
                 or c.cerca or c.mismo_archivo)) as por_cifras
      from e0 c),
  f as (select e.* from e where e.por_llave or e.por_cifras),
  m as (select f.* from f
         order by (f.firma = p_c->>'firma') desc, f.por_cifras desc, (f.estado = 'posteada') desc, f.importada_el desc limit 1)
  select case when m.id is null then null
              else jsonb_build_object('igual', m.firma = p_c->>'firma', 'misma', m.por_cifras or m.firma = p_c->>'firma',
                                      'otro_dia', m.dia_pago <> (p_c->>'dia_pago')::date,
                                      'mismo_archivo', m.mismo_archivo and m.por_cifras and m.dia_pago <> (p_c->>'dia_pago')::date,
                                      'cerca', m.cerca and m.por_cifras,
                                      'corrida', m.id, 'estado', m.estado, 'tipo', m.tipo, 'dia_pago', m.dia_pago,
                                      'bruto', m.bruto, 'neto', m.neto, 'personas', m.personas, 'importada_el', m.importada_el,
                                      'archivo', (select a.nombre from public.nomina_archivos a where a.id = m.archivo_id),
                                      'lee_distinto', m.estado = 'importada'
                                                      and (m.cuadra is distinct from (p_c->>'cuadra')::boolean
                                                           or m.sin_clasificar is distinct from (p_c->'sin_clasificar')),
                                      'posteadas', (select count(*) from f where f.estado = 'posteada'),
                                      'importadas', (select coalesce(jsonb_agg(f.id order by f.importada_el), '[]'::jsonb) from f
                                                      where f.estado = 'importada')) end
    from (select 1) uno left join m on true
$$;
revoke execute on function public.fn_nomina_ya(jsonb) from public, anon, service_role;
grant  execute on function public.fn_nomina_ya(jsonb) to authenticated;
comment on function public.fn_nomina_ya(jsonb) is 'c15: ¿esta nómina (leída de un archivo) ya está? Las corridas vivas —importadas o posteadas— que son la misma: por su llave (la misma; o su mismo día de pago y tipo con un período que no la contradiga y sin dos llaves de Gusto distintas) o por sus personas y sus cifras (las mismas personas con el mismo bruto y el mismo neto, el mismo día de pago —sea cual sea su tipo o su período—, o con otro día y un período que se pisa, o —si a una le falta el período— con el día de pago a menos de una semana, o si es la misma nómina del mismo archivo). Nulo si ninguna; si no, {igual (las mismas cifras concepto por concepto), misma (las mismas personas con su bruto y su neto), otro_dia (y por qué con otro día: mismo_archivo o cerca; si ninguno, por su período), corrida, estado, tipo, dia_pago, bruto, neto, personas, archivo, importada_el, lee_distinto, posteadas, importadas}. Solo lectura; con el código del teléfono.';

create or replace function public.fn_nomina_ensayo(p_archivo jsonb, p_opciones jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_l    jsonb;
  v_c    jsonb;
  v_out  jsonb := '[]'::jsonb;
  v_ya   jsonb;
  v_per  jsonb;
  v_arch nomina_archivos;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  v_l := fn_nomina_leer(p_archivo, p_opciones);
  select a.* into v_arch from nomina_archivos a where a.sha256 = p_archivo->>'sha256' order by a.importado_el desc limit 1;
  for v_c in select value from jsonb_array_elements(v_l->'corridas') loop
    v_ya := fn_nomina_ya(v_c || jsonb_build_object('sha256', v_l->'archivo'->>'sha256'));
    select coalesce(jsonb_agg(
             (q.p - 'lineas') || jsonb_build_object(
               'persona_id', pe.id, 'usuario_id', pe.usuario_id, 'clase', pe.clase, 'confirmada', pe.confirmado_el is not null,
               'perfil', (select pf.nombre from perfiles pf where pf.id = pe.usuario_id),
               'propuesta', case when pe.usuario_id is null then
                 (select jsonb_build_object('usuario_id', pp.usuario_id, 'nombre', pp.perfil, 'clase', pp.clase)
                    from fn_nomina_propone(q.p->>'clave') pp) end)
             order by (q.p->>'n')::int), '[]'::jsonb)
      into v_per
      from (select value as p from jsonb_array_elements(v_c->'personas')) q
      left join lateral (select o.* from nomina_personas o
                          where (q.p->>'gusto_id' is not null and o.gusto_id = q.p->>'gusto_id')
                             or (o.clave = q.p->>'clave' and (q.p->>'gusto_id' is null or o.gusto_id is null))
                          order by (o.gusto_id is not distinct from q.p->>'gusto_id') desc limit 1) pe on true;
    v_out := v_out || ((v_c - 'personas') || jsonb_build_object(
      'personas', v_per,
      'ya_estaba', case when v_ya is null then null
                        else jsonb_build_object('corrida', v_ya->'corrida', 'estado', v_ya->'estado', 'mismas_cifras', v_ya->'igual',
                                                'misma', v_ya->'misma', 'otro_dia', v_ya->'otro_dia', 'mismo_archivo', v_ya->'mismo_archivo',
                                                'cerca', v_ya->'cerca', 'tipo', v_ya->'tipo',
                                                'dia_pago', v_ya->'dia_pago', 'personas', v_ya->'personas',
                                                'importada_el', v_ya->'importada_el', 'archivo', v_ya->'archivo', 'bruto', v_ya->'bruto',
                                                'neto', v_ya->'neto', 'lee_distinto', v_ya->'lee_distinto',
                                                -- (reemplazarla: la que está es una, sin postear, y esta trae otras cifras o se lee distinto)
                                                'se_puede_reemplazar', (v_ya->>'posteadas')::int = 0 and jsonb_array_length(v_ya->'importadas') = 1
                                                                       and (not (v_ya->>'igual')::boolean or (v_ya->>'lee_distinto')::boolean),
                                                -- (subirla como OTRA nómina del mismo día: solo si no es la misma por sus personas y sus cifras)
                                                'se_puede_otra', not (v_ya->>'misma')::boolean) end,
      'se_puede_postear', (v_c->>'cuadra')::boolean and jsonb_array_length(v_c->'sin_clasificar') = 0));
  end loop;
  return jsonb_build_object(
    'archivo', (v_l->'archivo') || jsonb_build_object('ya_importado', case when v_arch.id is null then null
                                                                          else jsonb_build_object('nombre', v_arch.nombre, 'importado_el', v_arch.importado_el) end),
    'delicado', v_l->'delicado', 'corridas', v_out,
    'entraria', (select count(*) from jsonb_array_elements(v_out) q where q->'ya_estaba' is null or q->'ya_estaba' = 'null'::jsonb));
end $$;
revoke execute on function public.fn_nomina_ensayo(jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_nomina_ensayo(jsonb, jsonb) to authenticated;
comment on function public.fn_nomina_ensayo(jsonb, jsonb) is 'c15: EL ENSAYO de un archivo de nómina: lo que se entendería sin guardar nada. Devuelve {archivo (y si ese mismo archivo ya se importó), delicado (los rótulos de las columnas que no se leen), corridas: cada una con sus totales, cómo se leyó cada columna, sin_clasificar, cuadra y descuadres, avisos, sus personas (totales, si están enlazadas y confirmadas, y el perfil que se propone por el nombre), ya_estaba (si esa nómina ya está: su corrida, su estado, su tipo y su día de pago, mismas_cifras —concepto por concepto—, misma —las mismas personas con el mismo bruto y el mismo neto: es la misma nómina bajada de otra forma—, otro_dia, lee_distinto, se_puede_reemplazar y se_puede_otra) y se_puede_postear; entraria (cuántas son nuevas)}. Con el código del teléfono. Solo el dueño.';

create or replace function public.fn_nomina_importar(p_archivo jsonb, p_opciones jsonb default '{}'::jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_l      jsonb;
  v_c      jsonb;
  v_p      jsonb;
  v_ya     jsonb;
  v_arch   uuid;
  v_id     uuid;
  v_pid    uuid;
  v_llave  text;
  v_res    jsonb := '[]'::jsonb;
  v_nuevas jsonb := '[]'::jsonb;
  v_n      int := 0;
  v_msg    text;
  v_pe     nomina_personas;
  v_otra   boolean;
  v_reem   boolean;
  v_porque text;
  v_vieja  uuid;
  v_old    nomina_corridas;
  v_misma  boolean;
  v_igual  boolean;
  v_puede  boolean;
  v_cons   text;
  v_nd     int;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  begin
    v_otra := coalesce((p_opciones->>'otra_nomina')::boolean, false);
    v_reem := coalesce((p_opciones->>'reemplazar')::boolean, false);
  exception when others then
    raise exception using errcode = '22023', message = 'otra_nomina y reemplazar son verdadero o falso.';
  end;
  if v_otra and v_reem then
    raise exception using errcode = '22023', message = 'O es otra nómina del mismo día, o reemplaza a la que estaba: las dos cosas a la vez, no.';
  end if;
  v_porque := nullif(btrim(p_opciones->>'otra_porque'), '');
  if p_opciones ? 'otra_porque'
     and (not v_otra or v_porque is null or length(v_porque) < 3 or length(v_porque) > 300 or fn_nomina_delicado(v_porque)) then
    raise exception using errcode = '22023',
      message = 'otra_porque va con otra_nomina: unas palabras que digan por qué una nómina que trae a las mismas personas con las mismas '
                'cifras que otra es, de verdad, otra (dos bonos iguales el mismo día).';
  end if;
  -- (una importación a la vez: dos pestañas con el mismo archivo se esperan, y la segunda ve lo que dejó la primera)
  perform pg_advisory_xact_lock(820261115, hashtext('nomina:importar'));
  v_l := fn_nomina_leer(p_archivo, p_opciones);
  for v_c in select value from jsonb_array_elements(v_l->'corridas') loop
    v_llave := v_c->>'llave';
    v_ya := fn_nomina_ya(v_c || jsonb_build_object('sha256', v_l->'archivo'->>'sha256'));
    v_vieja := null;
    if v_ya is not null then
      v_igual := (v_ya->>'igual')::boolean;
      v_misma := (v_ya->>'misma')::boolean;
      v_puede := (v_ya->>'posteadas')::int = 0 and jsonb_array_length(v_ya->'importadas') = 1;
      if v_reem and v_puede then
        -- EN LUGAR DE LA QUE ESTABA (una, importada y sin postear): aquella se descarta y entra esta. Vale también con las
        -- mismas cifras: es como se vuelve a leer una corrida después de decirle al mapeo qué era una columna.
        v_vieja := (v_ya->'importadas'->>0)::uuid;
        perform set_config('mx_nomina.escribe', 'nomina_corridas', true);
        update nomina_corridas set estado = 'descartada', descartada_el = clock_timestamp(), descartada_por = auth.uid(),
                                   descartada_motivo = left(format('La sustituye otra subida de su archivo («%s»).', v_l->'archivo'->>'nombre'), 300)
         where id = v_vieja and estado = 'importada';
        perform set_config('mx_nomina.escribe', '', true);
      elsif v_otra and (not v_misma or v_porque is not null) then
        -- OTRA NÓMINA DEL MISMO DÍA. Si trae a las mismas personas con el mismo bruto y el mismo neto que la que está, solo
        -- con su porqué escrito (si no, es la misma bajada de otra forma y entraría dos veces al libro).
        v_llave := v_llave || '#' || left(v_c->>'firma', 8);
        if exists (select 1 from nomina_corridas c where c.llave = v_llave and c.estado in ('importada', 'posteada')) then
          v_res := v_res || jsonb_build_object('n', v_c->'n', 'resultado', 'ya_estaba', 'dia_pago', v_c->'dia_pago',
                                               'texto', 'Esa otra nómina del mismo día ya estaba: no entra dos veces.');
          continue;
        end if;
      elsif v_igual then
        v_res := v_res || jsonb_build_object(
          'n', v_c->'n', 'resultado', 'ya_estaba', 'corrida', v_ya->'corrida', 'estado', v_ya->'estado', 'dia_pago', v_ya->'dia_pago',
          'lee_distinto', v_ya->'lee_distinto', 'se_puede_reemplazar', v_puede and (v_ya->>'lee_distinto')::boolean,
          'otro_dia', v_ya->'otro_dia',
          'texto', format('La nómina del %s ya estaba (%s, del archivo «%s»): no entra dos veces.%s%s',
                          fn_nomina_dia((v_ya->>'dia_pago')::date), v_ya->>'estado', v_ya->>'archivo',
                          case when (v_ya->>'otro_dia')::boolean
                               then format(' (Esta dice que su día de pago es el %s, pero trae a las mismas personas con las mismas cifras '
                                           'y %s: es la misma. Si de verdad es otra nómina, súbela '
                                           'como otra nómina diciendo por qué.)', fn_nomina_dia((v_c->>'dia_pago')::date),
                                           case when (v_ya->>'mismo_archivo')::boolean then 'sale del mismo archivo que aquella'
                                                when (v_ya->>'cerca')::boolean
                                                  then 'su día de pago queda a menos de una semana del de aquella, sin un período que las distinga'
                                                else 'un período que se pisa con el de aquella' end)
                               when v_ya->>'tipo' <> v_c->>'tipo'
                               then format(' (Aquella entró como %s y esta dice %s: es la misma, con las mismas cifras.)',
                                           case v_ya->>'tipo' when 'regular' then 'regular' else 'fuera de ciclo' end,
                                           case v_c->>'tipo' when 'regular' then 'regular' else 'fuera de ciclo' end)
                               else '' end,
                          case when v_puede and (v_ya->>'lee_distinto')::boolean
                               then ' La que está se leyó de otra forma (le quedaban columnas sin clasificar, o no cuadraba) y con lo '
                                    'que el mapeo dice hoy se leería distinto: si es eso lo que quieres, súbela diciendo que reemplaza '
                                    'a la que estaba.'
                               else '' end));
        continue;
      else
        v_res := v_res || jsonb_build_object(
          'n', v_c->'n', 'resultado', 'otra_distinta', 'corrida', v_ya->'corrida', 'estado', v_ya->'estado', 'dia_pago', v_ya->'dia_pago',
          'misma', v_misma, 'otro_dia', v_ya->'otro_dia', 'se_puede_reemplazar', v_puede, 'se_puede_otra', not v_misma,
          'texto',
          case when v_misma then
            format('Ya hay una nómina del %s (%s, del archivo «%s») con las MISMAS %s persona(s), cada una con su mismo bruto y su mismo '
                   'neto (en total, bruto %s y neto %s): es la misma nómina, bajada de Gusto de otra forma%s. No entró: como «otra '
                   'nómina» su sueldo y sus impuestos entrarían dos veces al libro. %s Si de verdad son dos nóminas distintas con las '
                   'mismas personas y las mismas cifras (dos bonos iguales el mismo día), súbela como otra nómina diciendo por qué.',
                   fn_nomina_dia((v_ya->>'dia_pago')::date), v_ya->>'estado', v_ya->>'archivo', v_ya->>'personas',
                   fn_nomina_usd((v_ya->>'bruto')::numeric), fn_nomina_usd((v_ya->>'neto')::numeric),
                   concat_ws('', case when (v_ya->>'otro_dia')::boolean
                                      then format(' (esta dice que su día de pago es el %s, y %s)',
                                                  fn_nomina_dia((v_c->>'dia_pago')::date),
                                                  case when (v_ya->>'mismo_archivo')::boolean then 'sale del mismo archivo que aquella'
                                                       when (v_ya->>'cerca')::boolean
                                                         then 'queda a menos de una semana del de aquella, sin un período que las distinga'
                                                       else 'su período se pisa con el de aquella' end) end,
                                 case when v_ya->>'tipo' <> v_c->>'tipo'
                                      then format(' (aquella entró como %s y esta dice %s)',
                                                  case v_ya->>'tipo' when 'regular' then 'regular' else 'fuera de ciclo' end,
                                                  case v_c->>'tipo' when 'regular' then 'regular' else 'fuera de ciclo' end) end),
                   case when (v_ya->>'posteadas')::int > 0
                          then 'La que está ya se posteó: no hace falta subirla otra vez; si a aquella le faltaba algo (el detalle de '
                               'sus impuestos, su tipo), anúlala y sube esta.'
                        when v_puede
                          then 'Si prefieres esta forma del archivo (trae más detalle, o su tipo), súbela diciendo que reemplaza a la '
                               'que estaba.'
                        else 'Hay más de una sin postear de esa nómina: descarta la que sobre.' end)
          else
            format('Ya hay una nómina del %s de ese tipo (%s, del archivo «%s») y esta trae OTRAS cifras: %s persona(s), bruto %s y '
                   'neto %s, contra %s persona(s), bruto %s y neto %s de la que está%s. No entró. %s',
                   fn_nomina_dia((v_ya->>'dia_pago')::date), v_ya->>'estado', v_ya->>'archivo',
                   v_c->'totales'->>'personas', fn_nomina_usd((v_c->'totales'->>'bruto')::numeric),
                   fn_nomina_usd((v_c->'totales'->>'neto')::numeric), v_ya->>'personas', fn_nomina_usd((v_ya->>'bruto')::numeric),
                   fn_nomina_usd((v_ya->>'neto')::numeric),
                   case when (v_c->'totales'->>'bruto')::numeric = (v_ya->>'bruto')::numeric
                             and (v_c->'totales'->>'neto')::numeric = (v_ya->>'neto')::numeric
                             and v_c->'totales'->>'personas' = v_ya->>'personas'
                        then ' (los totales coinciden: cambia el reparto entre las personas)' else '' end,
                   case when (v_ya->>'posteadas')::int > 0
                        then 'La que está ya se posteó: si Gusto la corrigió, anúlala y vuelve a subir esta; si son dos nóminas '
                             'distintas del mismo día, súbela diciendo que es otra nómina.'
                        when jsonb_array_length(v_ya->'importadas') > 1
                        then 'Hay más de una nómina sin postear de ese día y ese tipo: descarta la que sobre y vuelve a subir esta; '
                             'o, si es otra nómina más del mismo día, súbela diciendo que es otra nómina.'
                        else 'Si es la misma (Gusto la corrigió, o la subes otra vez con sus columnas ya dichas), súbela diciendo '
                             'que reemplaza a la que estaba; si son dos nóminas distintas del mismo día, diciendo que es otra '
                             'nómina.' end) end);
        continue;
      end if;
    end if;
    v_nuevas := v_nuevas || (v_c || jsonb_build_object('llave', v_llave, 'reemplaza', v_vieja is not null, 'vieja', v_vieja,
                                                       'otra_porque', case when v_ya is not null and v_otra then v_porque end));
  end loop;

  if jsonb_array_length(v_nuevas) > 0 then
    perform set_config('mx_nomina.escribe', 'nomina_archivos', true);
    insert into nomina_archivos (nombre, sha256, bytes, filas, corridas, delicado, importado_por)
    values (v_l->'archivo'->>'nombre', v_l->'archivo'->>'sha256', (v_l->'archivo'->>'bytes')::bigint, (v_l->'archivo'->>'filas')::int,
            jsonb_array_length(v_nuevas), array(select jsonb_array_elements_text(v_l->'delicado')), auth.uid())
    returning id into v_arch;
    for v_c in select value from jsonb_array_elements(v_nuevas) loop
      v_n := v_n + 1;
      perform set_config('mx_nomina.escribe', 'nomina_corridas', true);
      insert into nomina_corridas (archivo_id, n, llave, firma, firma_personas, otra_porque, dia_pago, periodo_desde, periodo_hasta, tipo,
                                   tipo_texto, gusto_id, toma_horas,
                                   personas, bruto, imp_empleado, deducciones, neto, reembolsos, reembolsos_en_neto, imp_patron, ben_patron,
                                   horas, declara, cuadra, descuadres, columnas, sin_clasificar, totales_archivo, avisos, importada_por)
      values (v_arch, (v_c->>'n')::int, v_c->>'llave', v_c->>'firma', v_c->>'firma_personas', v_c->>'otra_porque', (v_c->>'dia_pago')::date,
              (v_c->>'periodo_desde')::date, (v_c->>'periodo_hasta')::date, v_c->>'tipo', v_c->>'tipo_texto', v_c->>'gusto_id',
              v_c->>'tipo' = 'regular',
              (v_c->'totales'->>'personas')::int, (v_c->'totales'->>'bruto')::numeric, (v_c->'totales'->>'imp_empleado')::numeric,
              (v_c->'totales'->>'deducciones')::numeric, (v_c->'totales'->>'neto')::numeric, (v_c->'totales'->>'reembolsos')::numeric,
              coalesce((v_c->'totales'->>'reembolsos_en_neto')::numeric, 0), (v_c->'totales'->>'imp_patron')::numeric,
              (v_c->'totales'->>'ben_patron')::numeric, (v_c->'totales'->>'horas')::numeric,
              v_c->'declara', (v_c->>'cuadra')::boolean, v_c->'descuadres', v_c->'columnas', v_c->'sin_clasificar',
              nullif(v_c->'totales_archivo', 'null'::jsonb), v_c->'avisos', auth.uid())
      returning id into v_id;
      for v_p in select value from jsonb_array_elements(v_c->'personas') loop
        -- la persona: por su identificador de Gusto si el archivo lo trae; si no, por su nombre (su clave)
        v_pe := null;
        if v_p->>'gusto_id' is not null then
          select * into v_pe from nomina_personas pe where pe.gusto_id = v_p->>'gusto_id';
        end if;
        if v_pe.id is null then
          select * into v_pe from nomina_personas pe
           where pe.clave = v_p->>'clave' and (v_p->>'gusto_id' is null or pe.gusto_id is null);
        end if;
        perform set_config('mx_nomina.escribe', 'nomina_personas', true);
        if v_pe.id is null then
          insert into nomina_personas (nombre, clave, gusto_id, creado_por)
          values (v_p->>'nombre', case when exists (select 1 from nomina_personas o where o.clave = v_p->>'clave')
                                       then (v_p->>'clave') || ' ' || left(md5(v_p->>'gusto_id'), 6) else v_p->>'clave' end,
                  v_p->>'gusto_id', auth.uid())
          returning id into v_pid;
        else
          v_pid := v_pe.id;
          if v_pe.gusto_id is null and v_p->>'gusto_id' is not null then
            update nomina_personas set gusto_id = v_p->>'gusto_id', actualizado_el = clock_timestamp(), actualizado_por = auth.uid()
             where id = v_pid;
          end if;
        end if;
        perform set_config('mx_nomina.escribe', 'nomina_corrida_personas', true);
        insert into nomina_corrida_personas (corrida_id, persona_id, n, nombre, metodo_pago, bruto, imp_empleado, deducciones, neto,
                                             reembolsos, imp_patron, ben_patron, horas, horas_fuera, neto_con_reembolso, cuadra, descuadre)
        values (v_id, v_pid, (v_p->>'n')::int, v_p->>'nombre', left(v_p->>'metodo_pago', 60), (v_p->>'bruto')::numeric,
                (v_p->>'imp_empleado')::numeric, (v_p->>'deducciones')::numeric, (v_p->>'neto')::numeric, (v_p->>'reembolsos')::numeric,
                (v_p->>'imp_patron')::numeric, (v_p->>'ben_patron')::numeric, (v_p->>'horas')::numeric, (v_p->>'horas_fuera')::numeric,
                coalesce((v_p->>'neto_con_reembolso')::boolean, false), (v_p->>'cuadra')::boolean, v_p->>'descuadre');
        perform set_config('mx_nomina.escribe', 'nomina_lineas', true);
        insert into nomina_lineas (corrida_id, persona_id, concepto, clase, cuenta, declara, monto, horas, columna)
        select v_id, v_pid, x.concepto, x.clase, x.cuenta, x.declara, x.monto, x.horas, x.columna
          from jsonb_to_recordset(v_p->'lineas') as x(concepto text, clase text, cuenta text, declara text, monto numeric, horas numeric,
                                                       columna text);
      end loop;
      -- LA QUE REEMPLAZA CONSERVA lo que Edgar ya le había dicho a la de antes: su período (si este archivo no lo trae), si se
      -- queda con las horas (si es del mismo tipo) y lo decidido para cada persona («sin obra», con su nota).
      v_cons := null;
      if (v_c->>'reemplaza')::boolean then
        select * into v_old from nomina_corridas where id = (v_c->>'vieja')::uuid;
        if v_old.id is not null then
          if (v_c->>'periodo_desde' is null and v_old.periodo_desde is not null) or (v_old.tipo = v_c->>'tipo' and v_old.toma_horas <> (v_c->>'tipo' = 'regular')) then
            perform set_config('mx_nomina.escribe', 'nomina_corridas', true);
            update nomina_corridas k
               set periodo_desde = coalesce(k.periodo_desde, v_old.periodo_desde), periodo_hasta = coalesce(k.periodo_hasta, v_old.periodo_hasta),
                   toma_horas = case when v_old.tipo = k.tipo then v_old.toma_horas else k.toma_horas end,
                   llave = case when k.gusto_id is not null or position('#' in k.llave) > 0 or k.periodo_desde is not null then k.llave
                                else 'f:' || k.dia_pago || '|' || coalesce(v_old.periodo_desde::text, '') || '|'
                                     || coalesce(v_old.periodo_hasta::text, '') || '|' || k.tipo end
             where k.id = v_id;
            v_cons := 'su período y si se queda con las horas';
          end if;
          perform set_config('mx_nomina.escribe', 'nomina_corrida_personas', true);
          update nomina_corrida_personas cp
             set decision = o.decision, decision_nota = o.decision_nota, decidido_el = o.decidido_el, decidido_por = o.decidido_por
            from nomina_corrida_personas o
           where o.corrida_id = v_old.id and o.decision is not null and cp.corrida_id = v_id and cp.persona_id = o.persona_id;
          get diagnostics v_nd = row_count;
          if v_nd > 0 then
            v_cons := concat_ws(' y ', v_cons, format('lo decidido para %s persona(s)', v_nd));
          end if;
        end if;
      end if;
      perform set_config('mx_nomina.escribe', '', true);
      v_res := v_res || jsonb_build_object(
        'n', v_c->'n', 'resultado', case when (v_c->>'reemplaza')::boolean then 'reemplazada' else 'nueva' end, 'corrida', v_id,
        'estado', 'importada', 'dia_pago', v_c->'dia_pago',
        'periodo_desde', v_c->'periodo_desde', 'periodo_hasta', v_c->'periodo_hasta', 'tipo', v_c->'tipo', 'totales', v_c->'totales',
        'cuadra', v_c->'cuadra', 'descuadres', v_c->'descuadres', 'sin_clasificar', v_c->'sin_clasificar', 'avisos', v_c->'avisos',
        'por_enlazar', (select count(*) from nomina_corrida_personas cp join nomina_personas pe on pe.id = cp.persona_id
                         where cp.corrida_id = v_id and (pe.usuario_id is null or pe.confirmado_el is null)),
        'texto', format('Entró la nómina del %s%s: %s persona(s), bruto %s, neto %s.%s%s', fn_nomina_dia((v_c->>'dia_pago')::date),
                        case when (v_c->>'reemplaza')::boolean
                             then ' (en lugar de la que estaba sin postear' || coalesce('; conserva ' || v_cons, '') || ')' else '' end,
                        v_c->'totales'->>'personas', fn_nomina_usd((v_c->'totales'->>'bruto')::numeric),
                        fn_nomina_usd((v_c->'totales'->>'neto')::numeric),
                        case when not (v_c->>'cuadra')::boolean then ' NO CUADRA con su archivo: no se puede postear hasta arreglarlo.' else '' end,
                        case when jsonb_array_length(v_c->'sin_clasificar') > 0
                             then format(' Trae %s columna(s) con cifras que no conozco: dime qué son y vuelve a subirla diciendo que '
                                         'reemplaza a esta.', jsonb_array_length(v_c->'sin_clasificar')) else '' end));
    end loop;
  end if;
  perform set_config('mx_nomina.escribe', '', true);
  v_msg := case when v_n = 0 and exists (select 1 from jsonb_array_elements(v_res) q where q->>'resultado' = 'otra_distinta' and (q->>'misma')::boolean)
                  then 'No entró nada: esa nómina ya está, bajada de otra forma (mira el detalle).'
                when v_n = 0 and exists (select 1 from jsonb_array_elements(v_res) q where q->>'resultado' = 'otra_distinta')
                  then 'No entró nada: ya hay una nómina de ese día con otras cifras (mira el detalle).'
                when v_n = 0 then 'Ese archivo ya estaba importado: no entró nada nuevo.'
                when v_n = jsonb_array_length(v_res) then format('Entró: %s nómina(s).', v_n)
                else format('Entraron %s nómina(s); las otras %s ya estaban o no pudieron entrar (mira el detalle).', v_n,
                            jsonb_array_length(v_res) - v_n) end;
  return jsonb_build_object('archivo', jsonb_build_object('id', v_arch, 'nombre', v_l->'archivo'->>'nombre', 'nuevo', v_arch is not null),
                            'nuevas', v_n, 'corridas', (select coalesce(jsonb_agg(q order by (q->>'n')::int), '[]'::jsonb)
                                                          from jsonb_array_elements(v_res) q),
                            'delicado', v_l->'delicado', 'mensaje', v_msg);
end $$;
revoke execute on function public.fn_nomina_importar(jsonb, jsonb) from public, anon, service_role;
grant  execute on function public.fn_nomina_importar(jsonb, jsonb) to authenticated;
comment on function public.fn_nomina_importar(jsonb, jsonb) is 'c15: IMPORTA un archivo de nómina ({nombre, sha256, bytes, filas}; las celdas como texto): guarda cada nómina nueva (la corrida, sus personas —dadas de alta sin enlazar si no se conocían— y sus líneas por persona y concepto). No entra dos veces: la misma nómina —por su llave, o por sus personas y sus cifras— con las mismas cifras concepto por concepto contesta «ya_estaba»; con otras, «otra_distinta» (no entra): si trae a las mismas personas con el mismo bruto y el mismo neto es la misma bajada de otra forma (misma: true; se_puede_otra: false) y como «otra nómina» solo entra con su porqué ({"otra_nomina": true, "otra_porque": "…"}); si trae otras cifras, o {"reemplazar": true} —la que estaba, una y sin postear, se descarta y entra esta, conservando su período dicho a mano y lo decidido para cada persona— u {"otra_nomina": true}. {"reemplazar": true} vale también con las mismas cifras (para volver a leerla con el mapeo de hoy). Lo delicado no se guarda. Devuelve {archivo, nuevas, corridas: [{n, resultado: nueva | reemplazada | ya_estaba | otra_distinta, corrida, misma, se_puede_reemplazar, se_puede_otra, texto…}], delicado, mensaje}. Una importación a la vez. Con el código del teléfono. Solo el dueño.';

-- Lo que se le puede decir a una corrida IMPORTADA antes de postearla: su
-- período de pago (si el archivo no lo traía, o venía mal) y si se queda
-- con las horas de ese período (una regular, sí; un bono o una corrección,
-- no: las usa de clave y siguen siendo de su nómina regular).
create or replace function public.fn_nomina_corrida(p_corrida uuid, p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c       nomina_corridas;
  d       nomina_corridas;
  v_x     text;
  v_des   date;
  v_has   date;
  v_toma  boolean;
  v_llave text;
  v_por   text;
  o       nomina_corridas;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'Di qué cambia: {"periodo_desde": "AAAA-MM-DD", "periodo_hasta": "AAAA-MM-DD"} o {"toma_horas": true | false}.';
  end if;
  select string_agg(k, ', ' order by k) into v_x from jsonb_object_keys(p) k
   where k not in ('periodo_desde', 'periodo_hasta', 'toma_horas', 'otra_porque');
  if v_x is not null then
    raise exception using errcode = '22023',
      message = format('Clave desconocida: %s. Valen periodo_desde, periodo_hasta, toma_horas y otra_porque.', v_x);
  end if;
  select * into c from nomina_corridas where id = p_corrida for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa corrida.';
  end if;
  if c.estado <> 'importada' then
    raise exception using errcode = 'MX008',
      message = format('Esa corrida está %s: su período y sus horas ya no se cambian.', c.estado);
  end if;
  v_des := c.periodo_desde; v_has := c.periodo_hasta; v_toma := c.toma_horas;
  if p ? 'periodo_desde' or p ? 'periodo_hasta' then
    v_des := fn_nomina_fecha(p->>'periodo_desde');
    v_has := fn_nomina_fecha(p->>'periodo_hasta');
    if v_des is null or v_has is null or v_des > v_has or v_has - v_des > 92 then
      raise exception using errcode = '22023',
        message = 'El período de pago son dos fechas (periodo_desde y periodo_hasta, AAAA-MM-DD), en orden y de tres meses como mucho.';
    end if;
  end if;
  if p ? 'toma_horas' then
    begin
      v_toma := (p->>'toma_horas')::boolean;
    exception when others then
      v_toma := null;
    end;
    if v_toma is null then
      raise exception using errcode = '22023', message = 'toma_horas es verdadero o falso.';
    end if;
  end if;
  v_por := c.otra_porque;
  if p ? 'otra_porque' then
    v_por := nullif(btrim(p->>'otra_porque'), '');
    if v_por is null or length(v_por) < 3 or length(v_por) > 300 or fn_nomina_delicado(v_por) then
      raise exception using errcode = '22023',
        message = 'otra_porque: unas palabras que digan por qué esta nómina, que trae a las mismas personas con las mismas cifras que otra, es otra.';
    end if;
  end if;
  -- (con ese período, ¿pasa a ser LA MISMA que otra viva? Las mismas personas con el mismo bruto y el mismo neto, el mismo
  -- día de pago o con un período que se pisa —o, si a una le falta el período, a menos de una semana; o la misma nómina del
  -- mismo archivo, subido otra vez—: no sigue sin su porqué)
  select k.* into o from nomina_corridas k
   where k.id <> c.id and k.estado in ('importada', 'posteada') and c.firma_personas is not null and k.firma_personas = c.firma_personas
     and (k.dia_pago = c.dia_pago
          or (k.periodo_desde is not null and v_des is not null and k.periodo_desde <= v_has and k.periodo_hasta >= v_des)
          or ((k.periodo_desde is null or v_des is null) and abs(k.dia_pago - c.dia_pago) <= 6)
          or (k.n = c.n and k.archivo_id <> c.archivo_id
              and exists (select 1 from nomina_archivos a1 join nomina_archivos a2 on a2.sha256 = a1.sha256
                           where a1.id = k.archivo_id and a2.id = c.archivo_id)))
   order by (k.estado = 'posteada') desc, k.importada_el limit 1;
  if o.id is not null and v_por is null then
    raise exception using errcode = 'MX008',
      message = format('Con ese período esta nómina sería la misma que la del %s que ya está (%s): las mismas %s persona(s), cada una '
                       'con su mismo bruto y su mismo neto%s. Si es la misma, descarta esta; si de verdad son dos, di por qué.',
                       fn_nomina_dia(o.dia_pago), o.estado, o.personas,
                       case when o.dia_pago = c.dia_pago then ''
                            when o.periodo_desde is not null and v_des is not null and o.periodo_desde <= v_has and o.periodo_hasta >= v_des
                              then ', con un período que se pisa con el suyo'
                            else ', del mismo archivo o con su día de pago a menos de una semana del suyo' end);
  end if;
  v_llave := case when c.gusto_id is not null or position('#' in c.llave) > 0 then c.llave
                  else 'f:' || c.dia_pago || '|' || coalesce(v_des::text, '') || '|' || coalesce(v_has::text, '') || '|' || c.tipo end;
  begin
    perform set_config('mx_nomina.escribe', 'nomina_corridas', true);
    update nomina_corridas set periodo_desde = v_des, periodo_hasta = v_has, toma_horas = v_toma, llave = v_llave, otra_porque = v_por
     where id = c.id
    returning * into d;
    perform set_config('mx_nomina.escribe', '', true);
  exception when unique_violation then
    perform set_config('mx_nomina.escribe', '', true);
    raise exception using errcode = 'MX008',
      message = format('Ya hay otra nómina viva del %s con ese período y ese tipo: esta sería la misma. Descarta la que sobre.',
                       fn_nomina_dia(c.dia_pago));
  end;
  perform fn_nomina_apunta('corrida', c.id::text,
                           jsonb_build_object('periodo_desde', c.periodo_desde, 'periodo_hasta', c.periodo_hasta, 'toma_horas', c.toma_horas),
                           jsonb_build_object('periodo_desde', d.periodo_desde, 'periodo_hasta', d.periodo_hasta, 'toma_horas', d.toma_horas));
  return jsonb_strip_nulls(jsonb_build_object('corrida', d.id, 'periodo_desde', d.periodo_desde, 'periodo_hasta', d.periodo_hasta,
                                              'toma_horas', d.toma_horas, 'otra_porque', d.otra_porque))
         || jsonb_build_object('periodo_desde', d.periodo_desde, 'periodo_hasta', d.periodo_hasta);
end $$;
revoke execute on function public.fn_nomina_corrida(uuid, jsonb) from public, anon, service_role;
grant  execute on function public.fn_nomina_corrida(uuid, jsonb) to authenticated;
comment on function public.fn_nomina_corrida(uuid, jsonb) is 'c15: lo que se le dice a una corrida importada antes de postearla: su período de pago ({periodo_desde, periodo_hasta}: si el archivo no lo traía), si se queda con las horas del período ({toma_horas}: una regular sí; un bono o una corrección, no) y, si trae a las mismas personas con las mismas cifras que otra viva del mismo día (o con un período que se pisa), por qué es otra ({otra_porque}; sin él, MX008). Queda en el historial. Con el código del teléfono. Solo el dueño.';

-- DESCARTAR una corrida importada (por error, o para volver a subirla con el
-- mapeo ya corregido): queda como rastro y deja libre su llave. Una posteada
-- no se descarta: se anula.
create or replace function public.fn_nomina_descartar(p_corrida uuid, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c nomina_corridas;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  if coalesce(length(btrim(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'Descartar una corrida dice por qué (motivo).';
  end if;
  select * into c from nomina_corridas where id = p_corrida for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa corrida.';
  end if;
  if c.estado = 'descartada' then
    return jsonb_build_object('corrida', c.id, 'descartada', true, 'ya_estaba', true);
  end if;
  if c.estado <> 'importada' then
    raise exception using errcode = 'MX008',
      message = format('Esa corrida está %s: %s', c.estado,
                       case when c.estado = 'posteada' then 'ya está en el libro; no se descarta, se anula (su asiento se reversa).'
                            else 'ya no cambia.' end);
  end if;
  perform set_config('mx_nomina.escribe', 'nomina_corridas', true);
  update nomina_corridas set estado = 'descartada', descartada_el = clock_timestamp(), descartada_por = auth.uid(),
                             descartada_motivo = btrim(p_motivo)
   where id = c.id;
  perform set_config('mx_nomina.escribe', '', true);
  return jsonb_build_object('corrida', c.id, 'descartada', true, 'ya_estaba', false);
end $$;
revoke execute on function public.fn_nomina_descartar(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_nomina_descartar(uuid, text) to authenticated;
comment on function public.fn_nomina_descartar(uuid, text) is 'c15: descarta una corrida IMPORTADA (subida por error, o para volver a subirla con el mapeo corregido), con su motivo: queda como rastro y su nómina se puede volver a importar. Una posteada no se descarta: se anula. Con el código del teléfono. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 10. LAS PERSONAS: enlazar cada empleado del journal con su perfil de la
--     app y decir su clase. Una vez; desde entonces sus corridas se reparten
--     solas. Y lo que Edgar decide para una persona en UNA corrida.
-- ---------------------------------------------------------------------
create or replace function public.fn_nomina_persona(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c_claves constant text[] := array['id', 'usuario_id', 'clase', 'a_obra', 'horas_periodo', 'nota', 'activo', 'confirmar'];
  a      nomina_personas;
  d      nomina_personas;
  v_x    text;
  v_u    uuid;
  v_pf   perfiles;
  v_cl   text;
  v_hp   numeric;
  v_conf boolean;
  v_cambia boolean;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'Una persona de la nómina llega como un objeto: {"id": …, "usuario_id": …, "clase": …, "confirmar": true}.';
  end if;
  select string_agg(k, ', ' order by k) into v_x from jsonb_object_keys(p) k where k <> all (c_claves);
  if v_x is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida: %s. Valen: %s.', v_x, array_to_string(c_claves, ', '));
  end if;
  begin
    select * into a from nomina_personas where id = (p->>'id')::uuid for update;
  exception when others then
    a := null;
  end;
  if a.id is null then
    raise exception using errcode = '22023', message = 'No existe esa persona de la nómina (id): aparecen solas al importar un archivo.';
  end if;
  v_u := a.usuario_id;
  if p ? 'usuario_id' then
    begin
      v_u := nullif(btrim(p->>'usuario_id'), '')::uuid;
    exception when others then
      raise exception using errcode = '22023', message = 'usuario_id es el perfil de la app de esa persona.';
    end;
  end if;
  if v_u is not null then
    select * into v_pf from perfiles pf where pf.id = v_u;
    if not found then
      raise exception using errcode = '22023', message = 'Ese perfil no existe en la app.';
    end if;
    if exists (select 1 from nomina_personas o where o.usuario_id = v_u and o.id <> a.id) then
      raise exception using errcode = 'MX008',
        message = format('%s ya está enlazado con otra persona de la nómina (%s): un perfil, una persona. Si es la misma con otro nombre '
                         'en Gusto, suelta primero la otra.', v_pf.nombre,
                         (select o.nombre from nomina_personas o where o.usuario_id = v_u and o.id <> a.id limit 1));
    end if;
  end if;
  v_cl := case when p ? 'clase' then nullif(btrim(p->>'clase'), '')
               else coalesce(a.clase, case v_pf.rol when 'dueno' then 'oficial' when 'campo' then 'campo' end) end;
  if v_cl is not null and v_cl not in ('campo', 'oficial', 'oficina') then
    raise exception using errcode = '22023',
      message = 'La clase es campo (mano de obra, repartida por obra según sus horas), oficial (el accionista-oficial) u oficina.';
  end if;
  v_hp := a.horas_periodo;
  if p ? 'horas_periodo' then
    begin
      v_hp := nullif(btrim(p->>'horas_periodo'), '')::numeric;
    exception when others then
      raise exception using errcode = 'MX005', message = 'horas_periodo es un número de horas.';
    end;
    if v_hp is not null and (scale(v_hp) is null or v_hp <= 0 or v_hp > 744) then
      raise exception using errcode = 'MX005', message = 'horas_periodo: las horas que cubre su sueldo en un período de pago (más de 0).';
    end if;
  end if;
  v_cambia := v_u is distinct from a.usuario_id or v_cl is distinct from a.clase;
  v_conf := coalesce((p->>'confirmar')::boolean, false);
  if v_conf and (v_u is null or v_cl is null) then
    raise exception using errcode = 'MX008',
      message = 'Para confirmar a una persona hay que decir quién es en la app (su perfil) y su clase (campo, oficial u oficina).';
  end if;
  perform set_config('mx_nomina.escribe', 'nomina_personas', true);
  update nomina_personas
     set usuario_id = v_u, clase = v_cl, horas_periodo = v_hp,
         a_obra = case when p ? 'a_obra' then coalesce((p->>'a_obra')::boolean, a_obra) else a_obra end,
         activo = case when p ? 'activo' then coalesce((p->>'activo')::boolean, activo) else activo end,
         nota = case when p ? 'nota' then nullif(btrim(p->>'nota'), '') else nota end,
         confirmado_el = case when v_conf then clock_timestamp() when v_cambia then null else confirmado_el end,
         confirmado_por = case when v_conf then auth.uid() when v_cambia then null else confirmado_por end,
         actualizado_el = clock_timestamp(), actualizado_por = auth.uid()
   where id = a.id
  returning * into d;
  perform set_config('mx_nomina.escribe', '', true);
  perform fn_nomina_apunta('persona', a.id::text,
                           jsonb_build_object('usuario_id', a.usuario_id, 'clase', a.clase, 'a_obra', a.a_obra, 'horas_periodo', a.horas_periodo,
                                              'activo', a.activo, 'confirmado', a.confirmado_el is not null),
                           jsonb_build_object('usuario_id', d.usuario_id, 'clase', d.clase, 'a_obra', d.a_obra, 'horas_periodo', d.horas_periodo,
                                              'activo', d.activo, 'confirmado', d.confirmado_el is not null));
  return jsonb_build_object('id', d.id, 'nombre', d.nombre, 'usuario_id', d.usuario_id, 'perfil', v_pf.nombre, 'clase', d.clase,
                            'a_obra', d.a_obra, 'horas_periodo', d.horas_periodo, 'activo', d.activo,
                            'confirmada', d.confirmado_el is not null,
                            'nota', case when v_cambia and not v_conf
                                         then 'Cambió su enlace o su clase: hay que confirmarla otra vez antes de postear sus corridas.' end);
end $$;
revoke execute on function public.fn_nomina_persona(jsonb) from public, anon, service_role;
grant  execute on function public.fn_nomina_persona(jsonb) to authenticated;
comment on function public.fn_nomina_persona(jsonb) is 'c15: enlaza a una persona del journal con su perfil de la app y dice su clase ({id, usuario_id, clase: campo | oficial | oficina, a_obra?, horas_periodo?, nota?, activo?, confirmar: true}). Sin clase, la que sale del rol del perfil (dueño → oficial; campo → campo). Un perfil, una persona. Confirmar pide perfil y clase; cambiar el enlace o la clase sin confirmar deja a la persona sin confirmar (sus corridas no se postean). Queda en el historial. Con el código del teléfono. Solo el dueño.';

create or replace function public.fn_nomina_decidir(p_corrida uuid, p_persona uuid, p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c   nomina_corridas;
  cp  nomina_corrida_personas;
  v_x text;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'Di qué decides: {"decision": "sin_obra", "nota": "por qué"} o {"quitar": true}.';
  end if;
  select string_agg(k, ', ' order by k) into v_x from jsonb_object_keys(p) k where k not in ('decision', 'nota', 'quitar');
  if v_x is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida: %s. Valen decision, nota y quitar.', v_x);
  end if;
  select * into c from nomina_corridas where id = p_corrida for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa corrida.';
  end if;
  if c.estado <> 'importada' then
    raise exception using errcode = 'MX008', message = format('Esa corrida está %s: lo decidido para sus personas ya no cambia.', c.estado);
  end if;
  select * into cp from nomina_corrida_personas where corrida_id = p_corrida and persona_id = p_persona;
  if not found then
    raise exception using errcode = '22023', message = 'Esa persona no está en esa corrida.';
  end if;
  perform set_config('mx_nomina.escribe', 'nomina_corrida_personas', true);
  if coalesce((p->>'quitar')::boolean, false) then
    update nomina_corrida_personas set decision = null, decision_nota = null, decidido_el = null, decidido_por = null
     where corrida_id = p_corrida and persona_id = p_persona;
  else
    if coalesce(p->>'decision', '') <> 'sin_obra' or coalesce(length(btrim(p->>'nota')), 0) < 3 then
      perform set_config('mx_nomina.escribe', '', true);
      raise exception using errcode = '22023',
        message = 'Lo que se puede decidir para quien tiene sueldo y ninguna hora aprobada en el período es «sin_obra» (su sueldo va entero a '
                  'la cuenta de lo sin obra), con su nota: por qué. Lo otro es aprobar sus horas en la app y volver a mirar.';
    end if;
    update nomina_corrida_personas set decision = 'sin_obra', decision_nota = btrim(p->>'nota'), decidido_el = clock_timestamp(),
                                       decidido_por = auth.uid()
     where corrida_id = p_corrida and persona_id = p_persona;
  end if;
  perform set_config('mx_nomina.escribe', '', true);
  perform fn_nomina_apunta('decision', p_corrida::text || ' ' || p_persona::text,
                           jsonb_build_object('decision', cp.decision, 'nota', cp.decision_nota),
                           case when coalesce((p->>'quitar')::boolean, false) then null
                                else jsonb_build_object('decision', 'sin_obra', 'nota', btrim(p->>'nota')) end);
  return jsonb_build_object('corrida', p_corrida, 'persona', p_persona,
                            'decision', case when coalesce((p->>'quitar')::boolean, false) then null else 'sin_obra' end);
end $$;
revoke execute on function public.fn_nomina_decidir(uuid, uuid, jsonb) from public, anon, service_role;
grant  execute on function public.fn_nomina_decidir(uuid, uuid, jsonb) to authenticated;
comment on function public.fn_nomina_decidir(uuid, uuid, jsonb) is 'c15: lo que Edgar decide para una persona en UNA corrida importada cuando tiene sueldo y ninguna hora aprobada en el período: {"decision": "sin_obra", "nota": "por qué"} manda su sueldo entero a la cuenta de lo sin obra; {"quitar": true} lo deshace. Queda en el historial. Con el código del teléfono. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 11. EL REPARTO Y EL ASIENTO. fn_nomina_plan calcula, para una corrida
--     importada, qué iría al libro y por qué no puede ir todavía (los
--     frenos). No escribe nada (con p_tomar, toma las horas de cada persona
--     en el período para que nadie las cambie mientras se postea).
--     POR PERSONA, según su clase:
--       campo    su bruto se reparte por sus HORAS APROBADAS del período de
--                pago (horas.aprobado_el), agrupadas por obra y CO, con el
--                núcleo de c10 (fn_jornal_repartir_ids: al centavo, por
--                mayores restos; la suma ES el bruto). Cada obra, a la mano
--                de obra directa (5000) con su obra y su CO; sus horas sin
--                obra, a la cuenta de lo sin obra. Lo que el patrón paga por
--                ella (impuestos y beneficios patronales), por las MISMAS
--                horas: la parte de las obras entra a la bolsa del burden
--                real (5015) y de ahí a cada obra (5010) en el asiento del
--                reparto; la de lo sin obra, al burden de oficina (6010).
--       oficial  la parte de su sueldo que es de obra: sus horas aprobadas
--                con obra entre las horas que cubre su sueldo en el período
--                (o las que reportó, si son más). Esa parte, por obra, a
--                5001; lo demás, a 6005. Lo patronal, igual: la parte de
--                obra a la bolsa y a sus obras; lo demás, a 6010. Sin horas
--                en obra (o con a_obra en falso), todo a 6005.
--       oficina  su bruto a 6000 y lo patronal a 6010.
--     UNA HORA, UNA NÓMINA: una corrida que «toma horas» (las regulares) no
--     usa las que ya pagó otra corrida viva ni las que ya pagó un jornal por
--     Zelle (c10), y se queda con las que usa. Una que no las toma (un bono,
--     una corrección) usa de clave todas las aprobadas del período, sin
--     quedárselas.
--     LOS FRENOS (no se postea hasta resolverlos; cada uno dice qué hacer):
--     no cuadra con su archivo · una columna con cifras sin clasificar · una
--     columna de dinero sin cuenta · una cuenta que ya no sirve · alguien
--     sin enlazar o sin confirmar · sin período de pago · alguien de campo
--     con sueldo y ninguna hora aprobada (hasta que se aprueben o Edgar
--     diga «sin obra») · falta la cuenta de lo sin obra.
--     LOS AVISOS (no frenan): las horas de Gusto no son las aprobadas, hay
--     horas del período sin aprobar, horas que ya pagó otra nómina, horas
--     sin obra, el mes del día de pago ya está cerrado.
-- ---------------------------------------------------------------------
create or replace function public.fn_nomina_plan(p_corrida uuid, p_tomar boolean default false) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c        nomina_corridas;
  cfg      nomina_config;
  v_ct     jsonb;
  v_frenos jsonb := '[]'::jsonb;
  v_avisos jsonb := '[]'::jsonb;
  v_partes jsonb := '[]'::jsonb;
  v_horas  jsonb := '[]'::jsonb;
  v_pers   jsonb := '[]'::jsonb;
  v_fa     jsonb;
  v_neto   text;
  v_x      text;
  p        record;
  v_bruto  numeric;
  v_patron numeric;
  v_ids    bigint[];
  v_ap_h   numeric;
  v_ap_n   int;
  v_sa_h   numeric;
  v_sa_n   int;
  v_oc_h   numeric;
  v_oc_txt text;
  v_us_h   numeric;
  v_so_h   numeric;
  v_rb     jsonb;
  v_rp     jsonb;
  v_pp     jsonb;
  v_d      numeric;
  v_ho     numeric;
  v_hs     numeric;
  v_pb     numeric;
  v_ppat   numeric;
  v_sb     int;
  v_sp     int;
  v_lin    jsonb;
  v_bur    jsonb;
  v_pas    jsonb;
  v_visto  text;
  v_dia    text;
  v_cla    jsonb;
  v_ndd    numeric;
  v_y      text;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  select * into c from nomina_corridas where id = p_corrida;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa corrida.';
  end if;
  select * into cfg from nomina_config where id = 1;
  v_ct := fn_nomina_cuentas();
  v_dia := fn_nomina_dia(c.dia_pago);

  -- LOS FRENOS DE LA CORRIDA
  if not c.cuadra then
    v_frenos := v_frenos || jsonb_build_object('codigo', 'no_cuadra', 'texto',
      format('No cuadra con su archivo: %s. Míralo en Gusto; si el archivo estaba mal, descártala y sube el bueno.',
             left((select string_agg(q, ' · ') from jsonb_array_elements_text(c.descuadres) q), 900)));
  end if;
  if jsonb_array_length(c.sin_clasificar) > 0 then
    v_frenos := v_frenos || jsonb_build_object('codigo', 'columna_sin_clasificar', 'texto',
      format('Trae %s columna(s) con cifras que no sé qué son: %s. Di qué es cada una (y a qué cuenta va, si es dinero) y vuelve a subir '
             'su archivo diciendo que reemplaza a esta: lo que no se conocía no se guardó.', jsonb_array_length(c.sin_clasificar),
             (select string_agg(format('«%s»', q->>'columna'), ', ') from jsonb_array_elements(c.sin_clasificar) q)));
  end if;
  select string_agg(distinct format('«%s»', l.columna), ', ') into v_x
    from nomina_lineas l
   where l.corrida_id = c.id and l.clase in ('imp_empleado', 'imp_patron', 'ben_patron', 'deduccion', 'reembolso', 'neto')
     and l.cuenta is null;
  if v_x is not null then
    v_frenos := v_frenos || jsonb_build_object('codigo', 'falta_cuenta', 'texto',
      format('La(s) columna(s) %s trae(n) dinero y el mapeo no dice a qué cuenta va (Florida no tiene impuesto estatal sobre el sueldo; un '
             'beneficio nuevo necesita su cuenta; y los impuestos del patrón en un solo total no se pueden separar: baja el archivo con su '
             'detalle). Dile su cuenta y vuelve a subir su archivo diciendo que reemplaza a esta.', v_x));
  end if;
  select string_agg(distinct fn_nomina_cuenta_mal(l.cuenta, 'pasivo'), '; ') into v_x
    from nomina_lineas l where l.corrida_id = c.id and l.cuenta is not null and fn_nomina_cuenta_mal(l.cuenta, 'pasivo') is not null;
  if v_x is not null then
    v_frenos := v_frenos || jsonb_build_object('codigo', 'cuenta_mal', 'texto', format('Una cuenta del mapeo ya no sirve: %s.', v_x));
  end if;
  select string_agg(q.m, '; ') into v_x
    from (values (fn_nomina_cuenta_mal(v_ct->>'mano_obra', 'burden_obra')), (fn_nomina_cuenta_mal(v_ct->>'mano_obra_oficial', 'burden_obra')),
                 (fn_nomina_cuenta_mal(v_ct->>'oficina', 'sueldo')), (fn_nomina_cuenta_mal(v_ct->>'oficial', 'sueldo')),
                 (fn_nomina_cuenta_mal(v_ct->>'bolsa', 'bolsa')), (fn_nomina_cuenta_mal(v_ct->>'burden_obra', 'burden_obra')),
                 (fn_nomina_cuenta_mal(v_ct->>'burden_admin', 'burden_admin')),
                 (case when v_ct->>'sin_obra' is not null then fn_nomina_cuenta_mal(v_ct->>'sin_obra', 'sin_obra') end)) q(m)
   where q.m is not null;
  if v_x is not null then
    v_frenos := v_frenos || jsonb_build_object('codigo', 'cuenta_mal', 'texto', format('Una cuenta de la nómina ya no sirve: %s. Cámbiala en los ajustes de la nómina.', v_x));
  end if;
  select count(distinct l.cuenta), min(l.cuenta) into v_d, v_neto from nomina_lineas l where l.corrida_id = c.id and l.clase = 'neto';
  if v_d > 1 then
    v_frenos := v_frenos || jsonb_build_object('codigo', 'cuenta_mal', 'texto', 'El neto de esta corrida va a más de una cuenta: tiene que ir a una sola.');
  end if;
  if v_neto is null then
    select min(k->>'cuenta') into v_neto from jsonb_array_elements(c.columnas) k where k->>'clase' = 'neto';
  end if;
  -- (LA MISMA NÓMINA, DOS VECES: otra ya POSTEADA con las mismas personas, cada una con su mismo bruto y su mismo neto, el mismo
  -- día de pago o con un período que se pisa. No se postea sin que Edgar diga por qué es otra.)
  select string_agg(format('la del %s (asiento %s)', fn_nomina_dia(o.dia_pago), o.asiento_numero), ', ' order by o.dia_pago, o.id) into v_x
    from nomina_corridas o
   where o.id <> c.id and o.estado = 'posteada' and c.firma_personas is not null and o.firma_personas = c.firma_personas
     and c.otra_porque is null
     and (o.dia_pago = c.dia_pago
          or (o.periodo_desde is not null and c.periodo_desde is not null
              and o.periodo_desde <= c.periodo_hasta and o.periodo_hasta >= c.periodo_desde)
          -- (a una le falta el período —un resumen sin fechas, con su día de pago dicho a mano— y caen a menos de una semana; o
          -- es la misma nómina del mismo archivo, subido otra vez con otro día)
          or ((o.periodo_desde is null or c.periodo_desde is null) and abs(o.dia_pago - c.dia_pago) <= 6)
          or (o.n = c.n and o.archivo_id <> c.archivo_id
              and exists (select 1 from nomina_archivos a1 join nomina_archivos a2 on a2.sha256 = a1.sha256
                           where a1.id = o.archivo_id and a2.id = c.archivo_id)));
  if v_x is not null then
    v_frenos := v_frenos || jsonb_build_object('codigo', 'repetida', 'texto',
      format('Esta nómina trae a las mismas %s persona(s), cada una con su mismo bruto y su mismo neto, que %s, que ya está en el libro: '
             'parece la misma, y posteada entraría dos veces. Si es la misma, descártala; si de verdad es otra (dos bonos iguales), '
             'di por qué y vuelve a mirar.', c.personas, v_x));
  end if;
  v_fa := fn_nomina_fecha_asiento(c.dia_pago);
  if v_fa ? 'nota' then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'mes_cerrado', 'texto', v_fa->>'nota');
  end if;
  -- (LA NÓMINA QUE CRUZA EL AÑO: su período empieza en un año anterior al de su día de pago. Entra entera en el año de su día
  -- de pago —así la cuentan el 941, el 940 y el W-2—; lo trabajado en el año anterior solo queda como costo de ese año si su
  -- último mes se devengó antes de cerrarlo.)
  if c.periodo_desde is not null and extract(year from c.periodo_desde) < extract(year from c.dia_pago) then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'cruza_el_anio', 'texto',
      format('Esta nómina cruza el año: paga el %s lo trabajado desde el %s. Entra entera en %s, el año de su día de pago (así la '
             'cuentan el 941, el 940 y los W-2). Lo trabajado en %s %s Y si esas horas de %s ya se pagaron por otro lado (por Zelle), '
             'no deben venir en esta nómina: míralo en Gusto.',
             v_dia, fn_nomina_dia(c.periodo_desde), extract(year from c.dia_pago)::int, extract(year from c.periodo_desde)::int,
             case when exists (select 1 from asientos a
                                where a.origen_tabla = 'horas_devengo' and a.origen_id = to_char(c.periodo_desde, 'YYYY-MM')
                                  and a.camino not in ('reverso', 'reverso_automatico')
                                  and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso'))
                  then format('ya quedó como costo de ese año, a tarifa estándar, con el devengo de horas de %s (que se reversó solo el día 1).',
                              to_char(c.periodo_desde, 'YYYY-MM'))
                  else format('NO queda como costo de ese año: %s no tiene su devengo de horas. Si el CPA lo quiere en ese año, se '
                              'devenga antes de cerrar ese mes.', to_char(c.periodo_desde, 'YYYY-MM')) end,
             extract(year from c.periodo_desde)::int));
  end if;
  if c.periodo_desde is null and exists (select 1 from nomina_corrida_personas cp join nomina_personas pe on pe.id = cp.persona_id
                                          where cp.corrida_id = c.id and pe.clase = 'campo') then
    v_frenos := v_frenos || jsonb_build_object('codigo', 'sin_periodo', 'texto',
      'No sé el período de pago de esta nómina (el archivo no lo traía): sin él no hay horas con qué repartir a la gente de campo. Dilo '
      '(desde y hasta) y vuelve a mirar.');
  end if;

  -- PERSONA POR PERSONA
  for p in
    select cp.persona_id, cp.n, cp.nombre, cp.bruto, cp.imp_patron + cp.ben_patron as patron, cp.neto, cp.horas as horas_gusto,
           cp.decision, cp.decision_nota, pe.usuario_id, pe.clase, pe.a_obra, pe.horas_periodo, pe.confirmado_el,
           pf.id as perfil_id, pf.nombre as perfil
      from nomina_corrida_personas cp
      join nomina_personas pe on pe.id = cp.persona_id
      left join perfiles pf on pf.id = pe.usuario_id
     where cp.corrida_id = c.id
     order by cp.n
  loop
    v_bruto := p.bruto; v_patron := p.patron;
    v_sb := sign(v_bruto)::int; v_sp := sign(v_patron)::int;
    v_pp := '[]'::jsonb; v_ap_h := null; v_ap_n := null; v_sa_h := null; v_sa_n := null; v_us_h := null; v_so_h := null; v_oc_h := null;
    if p.usuario_id is null or p.perfil_id is null or p.confirmado_el is null or p.clase is null then
      v_frenos := v_frenos || jsonb_build_object('codigo', case when p.usuario_id is null then 'sin_enlazar'
                                                                when p.perfil_id is null then 'perfil_no_existe' else 'sin_confirmar' end,
        'persona', p.persona_id, 'texto',
        case when p.usuario_id is null
               then format('%s no está enlazado con nadie de la app: di quién es y su clase (campo, oficial u oficina).', p.nombre)
             when p.perfil_id is null
               then format('El perfil de la app con que estaba enlazado %s ya no existe: enlázalo con el suyo.', p.nombre)
             else format('%s está enlazado con %s pero sin confirmar: confírmalo (quién es y su clase) una vez.', p.nombre, p.perfil) end);
    elsif p.clase = 'oficina' then
      if v_bruto <> 0 then
        v_pp := v_pp || jsonb_build_object('persona_id', p.persona_id, 'clase', 'bruto', 'destino', 'oficina', 'cuenta', v_ct->>'oficina', 'monto', v_bruto);
      end if;
      if v_patron <> 0 then
        v_pp := v_pp || jsonb_build_object('persona_id', p.persona_id, 'clase', 'patron', 'destino', 'oficina', 'cuenta', v_ct->>'burden_admin', 'monto', v_patron);
      end if;
    elsif c.periodo_desde is null then
      -- sin período: el oficial entero a su cuenta; la gente de campo ya tiene su freno arriba
      if p.clase = 'oficial' then
        if v_bruto <> 0 then
          v_pp := v_pp || jsonb_build_object('persona_id', p.persona_id, 'clase', 'bruto', 'destino', 'oficial', 'cuenta', v_ct->>'oficial', 'monto', v_bruto);
        end if;
        if v_patron <> 0 then
          v_pp := v_pp || jsonb_build_object('persona_id', p.persona_id, 'clase', 'patron', 'destino', 'oficial', 'cuenta', v_ct->>'burden_admin', 'monto', v_patron);
        end if;
      end if;
    else
      -- SUS HORAS del período (tomadas, si se va a postear: nadie las cambia mientras)
      if p_tomar then
        perform 1 from (select h.id from horas h
                         where h.usuario_id = p.usuario_id and h.fecha between c.periodo_desde and c.periodo_hasta
                         order by h.id for update) z;
      end if;
      select coalesce(sum(h.horas) filter (where h.aprobado_el is not null), 0), count(*) filter (where h.aprobado_el is not null),
             coalesce(sum(h.horas) filter (where h.aprobado_el is null), 0), count(*) filter (where h.aprobado_el is null)
        into v_ap_h, v_ap_n, v_sa_h, v_sa_n
        from horas h
       where h.usuario_id = p.usuario_id and h.fecha between c.periodo_desde and c.periodo_hasta and h.horas > 0 and h.horas < 100000;
      -- (las que ya pagó otra nómina viva, o un jornal por Zelle)
      select coalesce(sum(h.horas), 0),
             string_agg(distinct coalesce('la nómina del ' || fn_nomina_dia(o.dia_pago), 'un pago por Zelle ya repartido'), ', ')
        into v_oc_h, v_oc_txt
        from horas h
        left join nomina_reparto_horas rh on rh.horas_id = h.id and rh.titular and rh.vivo and rh.corrida_id <> c.id
        left join nomina_corridas o on o.id = rh.corrida_id
       where h.usuario_id = p.usuario_id and h.fecha between c.periodo_desde and c.periodo_hasta and h.aprobado_el is not null
         and h.horas > 0 and h.horas < 100000 and c.toma_horas
         and (rh.horas_id is not null
              or exists (select 1 from jornal_reparto_horas jh join jornal_repartos jr on jr.id = jh.reparto_id
                          where jh.horas_id = h.id and jr.estado = 'aplicado'));
      select coalesce(array_agg(h.id order by h.id), '{}'), coalesce(sum(h.horas), 0),
             coalesce(sum(h.horas) filter (where h.proyecto_id is null), 0), coalesce(sum(h.horas) filter (where h.proyecto_id is not null), 0)
        into v_ids, v_us_h, v_so_h, v_ho
        from horas h
       where h.usuario_id = p.usuario_id and h.fecha between c.periodo_desde and c.periodo_hasta and h.aprobado_el is not null
         and h.horas > 0 and h.horas < 100000
         and (not c.toma_horas
              or (not exists (select 1 from nomina_reparto_horas rh where rh.horas_id = h.id and rh.titular and rh.vivo and rh.corrida_id <> c.id)
                  and not exists (select 1 from jornal_reparto_horas jh join jornal_repartos jr on jr.id = jh.reparto_id
                                   where jh.horas_id = h.id and jr.estado = 'aplicado')));
      v_hs := v_so_h;
      if p.clase = 'oficial' then
        -- la parte de obra de su sueldo: sus horas con obra entre las que cubre su sueldo (o las que reportó, si son más)
        select coalesce(array_agg(h.id order by h.id), '{}') into v_ids from horas h where h.id = any (v_ids) and h.proyecto_id is not null;
        v_d := greatest(coalesce(p.horas_periodo, cfg.horas_periodo_oficial), v_ho + v_hs);
        v_pb := case when p.a_obra and v_ho > 0 and v_bruto > 0 then least(round(v_bruto * v_ho / v_d, 2), v_bruto) else 0 end;
        v_ppat := case when p.a_obra and v_ho > 0 and v_patron > 0 then least(round(v_patron * v_ho / v_d, 2), v_patron) else 0 end;
        v_rb := null; v_rp := null;
        if v_pb > 0 then
          select jsonb_agg(to_jsonb(q)) into v_rb from fn_jornal_repartir_ids(v_ids, v_pb) q;
          select v_pp || coalesce(jsonb_agg(jsonb_build_object('persona_id', p.persona_id, 'clase', 'bruto', 'destino', 'obra',
                                    'cuenta', v_ct->>'mano_obra_oficial', 'proyecto_id', g.proyecto_id, 'co', g.co, 'horas', g.horas_grupo,
                                    'monto', g.monto_grupo) order by g.grupo), '[]'::jsonb)
            into v_pp
            from (select distinct (q->>'grupo')::int as grupo, q->>'proyecto_id' as proyecto_id, q->>'co' as co,
                         (q->>'horas_grupo')::numeric as horas_grupo, (q->>'monto_grupo')::numeric as monto_grupo
                    from jsonb_array_elements(v_rb) q) g
           where g.monto_grupo <> 0;
        end if;
        if v_bruto - v_pb <> 0 then
          v_pp := v_pp || jsonb_build_object('persona_id', p.persona_id, 'clase', 'bruto', 'destino', 'oficial', 'cuenta', v_ct->>'oficial',
                                             'monto', v_bruto - v_pb);
        end if;
        if v_ppat > 0 then
          select jsonb_agg(to_jsonb(q)) into v_rp from fn_jornal_repartir_ids(v_ids, v_ppat) q;
          select v_pp || coalesce(jsonb_agg(jsonb_build_object('persona_id', p.persona_id, 'clase', 'patron', 'destino', 'obra',
                                    'cuenta', v_ct->>'bolsa', 'proyecto_id', g.proyecto_id, 'co', g.co, 'horas', g.horas_grupo,
                                    'monto', g.monto_grupo) order by g.grupo), '[]'::jsonb)
            into v_pp
            from (select distinct (q->>'grupo')::int as grupo, q->>'proyecto_id' as proyecto_id, q->>'co' as co,
                         (q->>'horas_grupo')::numeric as horas_grupo, (q->>'monto_grupo')::numeric as monto_grupo
                    from jsonb_array_elements(v_rp) q) g
           where g.monto_grupo <> 0;
        end if;
        if v_patron - v_ppat <> 0 then
          v_pp := v_pp || jsonb_build_object('persona_id', p.persona_id, 'clase', 'patron', 'destino', 'oficial', 'cuenta', v_ct->>'burden_admin',
                                             'monto', v_patron - v_ppat);
        end if;
        if v_pb > 0 or v_ppat > 0 then
          select v_horas || coalesce(jsonb_agg(jsonb_build_object(
                   'persona_id', p.persona_id, 'usuario_id', p.usuario_id, 'horas_id', b.horas_id, 'fecha', b.fecha, 'proyecto_id', b.proyecto_id,
                   'co', b.co, 'fase', b.fase, 'horas', b.horas, 'bruto', coalesce(b.bruto, 0), 'patron', coalesce(b.patron, 0),
                   'titular', c.toma_horas) order by b.horas_id), '[]'::jsonb)
            into v_horas
            from (select coalesce((x->>'horas_id')::bigint, (y->>'horas_id')::bigint) as horas_id,
                         coalesce(x->>'fecha', y->>'fecha') as fecha, coalesce(x->>'proyecto_id', y->>'proyecto_id') as proyecto_id,
                         coalesce(x->>'co', y->>'co') as co, coalesce(x->>'fase', y->>'fase') as fase,
                         coalesce((x->>'horas')::numeric, (y->>'horas')::numeric) as horas, (x->>'monto')::numeric as bruto,
                         (y->>'monto')::numeric as patron
                    from jsonb_array_elements(coalesce(v_rb, '[]'::jsonb)) x
                    full join jsonb_array_elements(coalesce(v_rp, '[]'::jsonb)) y on (y->>'horas_id') = (x->>'horas_id')) b;
        end if;
        v_us_h := case when v_pb > 0 or v_ppat > 0 then v_ho else 0 end;
        if p.a_obra and v_ho > 0 and v_bruto > 0 then
          v_avisos := v_avisos || jsonb_build_object('codigo', 'oficial_en_obra', 'persona', p.persona_id, 'texto',
            format('%s: %s h aprobadas en obra de las %s que cubre su sueldo en el período → %s de su sueldo va a sus obras (5001) y %s a la '
                   'compensación de oficiales.', p.nombre, fn_nomina_h(v_ho), fn_nomina_h(v_d), fn_nomina_usd(v_pb), fn_nomina_usd(v_bruto - v_pb)));
        end if;
      elsif cardinality(v_ids) = 0 then
        -- campo, sin horas que valgan
        if v_bruto = 0 and v_patron = 0 then
          null;
        elsif p.decision = 'sin_obra' then
          if v_ct->>'sin_obra' is null then
            v_frenos := v_frenos || jsonb_build_object('codigo', 'falta_cuenta_sin_obra', 'persona', p.persona_id, 'texto',
              format('Decidiste mandar el sueldo de %s sin obra, y falta decir a qué cuenta va lo sin obra (una vez, en los ajustes de la '
                     'nómina: el sueldo de oficina, 6000, por ejemplo).', p.nombre));
          else
            if v_bruto <> 0 then
              v_pp := v_pp || jsonb_build_object('persona_id', p.persona_id, 'clase', 'bruto', 'destino', 'sin_obra', 'cuenta', v_ct->>'sin_obra', 'monto', v_bruto);
            end if;
            if v_patron <> 0 then
              v_pp := v_pp || jsonb_build_object('persona_id', p.persona_id, 'clase', 'patron', 'destino', 'sin_obra', 'cuenta', v_ct->>'burden_admin', 'monto', v_patron);
            end if;
            v_avisos := v_avisos || jsonb_build_object('codigo', 'sin_obra_decidido', 'persona', p.persona_id, 'texto',
              format('%s: su sueldo (%s) va entero sin obra, porque así lo decidiste: «%s».', p.nombre, fn_nomina_usd(v_bruto), p.decision_nota));
          end if;
        else
          v_frenos := v_frenos || jsonb_build_object('codigo', 'sin_horas', 'persona', p.persona_id, 'texto',
            format('%s tiene sueldo en esta nómina (%s) y ninguna hora aprobada del %s al %s%s%s. Aprueba sus horas en la app y vuelve a '
                   'mirar, o decide mandarlo sin obra (con una nota).', p.nombre, fn_nomina_usd(v_bruto), fn_nomina_dia(c.periodo_desde),
                   fn_nomina_dia(c.periodo_hasta),
                   case when v_sa_n > 0 then format(' (tiene %s reporte(s) sin aprobar, %s h)', v_sa_n, fn_nomina_h(v_sa_h)) else '' end,
                   case when v_oc_h > 0 then format(' (sus %s h aprobadas ya las pagó %s)', fn_nomina_h(v_oc_h), v_oc_txt) else '' end));
        end if;
      else
        -- campo, con horas: el bruto y lo patronal, por las mismas horas (el núcleo de c10)
        v_rb := null; v_rp := null;
        if v_bruto <> 0 then
          select jsonb_agg(to_jsonb(q)) into v_rb from fn_jornal_repartir_ids(v_ids, abs(v_bruto)) q;
        end if;
        if v_patron <> 0 then
          select jsonb_agg(to_jsonb(q)) into v_rp from fn_jornal_repartir_ids(v_ids, abs(v_patron)) q;
        end if;
        if v_so_h > 0 and v_ct->>'sin_obra' is null then
          v_frenos := v_frenos || jsonb_build_object('codigo', 'falta_cuenta_sin_obra', 'persona', p.persona_id, 'texto',
            format('%s tiene %s h aprobadas sin obra en el período, y falta decir a qué cuenta va lo sin obra (una vez, en los ajustes de la '
                   'nómina: el sueldo de oficina, 6000, por ejemplo). O ponles su obra en Horas.', p.nombre, fn_nomina_h(v_so_h)));
        else
          select v_pp || coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                   'persona_id', p.persona_id, 'clase', 'bruto', 'destino', case when g.proyecto_id is null then 'sin_obra' else 'obra' end,
                   'cuenta', case when g.proyecto_id is null then v_ct->>'sin_obra' else v_ct->>'mano_obra' end,
                   'proyecto_id', g.proyecto_id, 'co', g.co, 'horas', g.horas_grupo, 'monto', v_sb * g.monto_grupo)) order by g.grupo), '[]'::jsonb)
            into v_pp
            from (select distinct (q->>'grupo')::int as grupo, q->>'proyecto_id' as proyecto_id, q->>'co' as co,
                         (q->>'horas_grupo')::numeric as horas_grupo, (q->>'monto_grupo')::numeric as monto_grupo
                    from jsonb_array_elements(coalesce(v_rb, '[]'::jsonb)) q) g
           where g.monto_grupo <> 0;
          select v_pp || coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                   'persona_id', p.persona_id, 'clase', 'patron', 'destino', case when g.proyecto_id is null then 'sin_obra' else 'obra' end,
                   'cuenta', case when g.proyecto_id is null then v_ct->>'burden_admin' else v_ct->>'bolsa' end,
                   'proyecto_id', g.proyecto_id, 'co', g.co, 'horas', g.horas_grupo, 'monto', v_sp * g.monto_grupo)) order by g.grupo), '[]'::jsonb)
            into v_pp
            from (select distinct (q->>'grupo')::int as grupo, q->>'proyecto_id' as proyecto_id, q->>'co' as co,
                         (q->>'horas_grupo')::numeric as horas_grupo, (q->>'monto_grupo')::numeric as monto_grupo
                    from jsonb_array_elements(coalesce(v_rp, '[]'::jsonb)) q) g
           where g.monto_grupo <> 0;
          select v_horas || coalesce(jsonb_agg(jsonb_build_object(
                   'persona_id', p.persona_id, 'usuario_id', p.usuario_id, 'horas_id', b.horas_id, 'fecha', b.fecha, 'proyecto_id', b.proyecto_id,
                   'co', b.co, 'fase', b.fase, 'horas', b.horas, 'bruto', v_sb * coalesce(b.bruto, 0), 'patron', v_sp * coalesce(b.patron, 0),
                   'titular', c.toma_horas) order by b.horas_id), '[]'::jsonb)
            into v_horas
            from (select coalesce((x->>'horas_id')::bigint, (y->>'horas_id')::bigint) as horas_id,
                         coalesce(x->>'fecha', y->>'fecha') as fecha, coalesce(x->>'proyecto_id', y->>'proyecto_id') as proyecto_id,
                         coalesce(x->>'co', y->>'co') as co, coalesce(x->>'fase', y->>'fase') as fase,
                         coalesce((x->>'horas')::numeric, (y->>'horas')::numeric) as horas, (x->>'monto')::numeric as bruto,
                         (y->>'monto')::numeric as patron
                    from jsonb_array_elements(coalesce(v_rb, '[]'::jsonb)) x
                    full join jsonb_array_elements(coalesce(v_rp, '[]'::jsonb)) y on (y->>'horas_id') = (x->>'horas_id')) b;
          if v_so_h > 0 then
            v_avisos := v_avisos || jsonb_build_object('codigo', 'sin_obra', 'persona', p.persona_id, 'texto',
              format('%s tiene %s h aprobadas sin obra en el período: su parte del sueldo va a la cuenta de lo sin obra (%s), no a una obra.',
                     p.nombre, fn_nomina_h(v_so_h), v_ct->>'sin_obra'));
          end if;
        end if;
      end if;
      -- sus avisos de horas
      if p.clase = 'campo' and c.toma_horas and p.horas_gusto is not null and p.horas_gusto <> v_ap_h then
        v_avisos := v_avisos || jsonb_build_object('codigo', 'horas_distintas', 'persona', p.persona_id, 'texto',
          format('%s: Gusto le pagó %s h trabajadas y en la app tiene %s h aprobadas del %s al %s. El sueldo se reparte por las de la app; '
                 'si faltan horas por aprobar o sobran en Gusto, míralo.', p.nombre, fn_nomina_h(p.horas_gusto), fn_nomina_h(v_ap_h),
                 fn_nomina_dia(c.periodo_desde), fn_nomina_dia(c.periodo_hasta)));
      end if;
      if p.clase = 'campo' and v_sa_n > 0 and cardinality(v_ids) > 0 then
        v_avisos := v_avisos || jsonb_build_object('codigo', 'sin_aprobar', 'persona', p.persona_id, 'texto',
          format('%s tiene %s reporte(s) de horas sin aprobar en el período (%s h): no entran en el reparto. Si son de esta nómina, apruébalos '
                 'antes de postear.', p.nombre, v_sa_n, fn_nomina_h(v_sa_h)));
      end if;
      if p.clase = 'oficial' and p.a_obra and v_sa_n > 0 then
        v_avisos := v_avisos || jsonb_build_object('codigo', 'sin_aprobar', 'persona', p.persona_id, 'texto',
          format('%s tiene %s reporte(s) de horas sin aprobar en el período (%s h): no cuentan para la parte de obra de su sueldo. Si son de '
                 'esta nómina, apruébalos antes de postear.', p.nombre, v_sa_n, fn_nomina_h(v_sa_h)));
      end if;
      if v_oc_h > 0 and cardinality(v_ids) > 0 then
        v_avisos := v_avisos || jsonb_build_object('codigo', 'ya_pagadas', 'persona', p.persona_id, 'texto',
          format('%s: %s h aprobadas del período ya las pagó %s: no se reparten otra vez.', p.nombre, fn_nomina_h(v_oc_h), v_oc_txt));
      end if;
    end if;
    v_partes := v_partes || v_pp;
    v_pers := v_pers || jsonb_build_object(
      'persona_id', p.persona_id, 'n', p.n, 'nombre', p.nombre, 'usuario_id', p.usuario_id, 'perfil', p.perfil, 'clase', p.clase,
      'confirmada', p.confirmado_el is not null, 'bruto', v_bruto, 'patron', v_patron, 'neto', p.neto, 'horas_gusto', p.horas_gusto,
      'horas_aprobadas', v_ap_h, 'horas_sin_aprobar', v_sa_h, 'horas_usadas', v_us_h, 'horas_ya_pagadas', v_oc_h, 'decision', p.decision,
      'partes', (select coalesce(jsonb_agg(q || jsonb_build_object('obra', (select pr.nombre from proyectos pr where pr.id = q->>'proyecto_id'))),
                                 '[]'::jsonb) from jsonb_array_elements(v_pp) q));
  end loop;

  -- LO DE LA CORRIDA QUE NO FRENA Y CONVIENE SABER
  -- (una obra que ya no está activa, o que todavía no está aprobada, recibe su parte igual: el trabajo se hizo ahí; se dice)
  select string_agg(distinct format('%s (%s)', pr.nombre, case pr.estado when 'completado' then 'terminada' else 'no aprobada' end), '; ')
           filter (where pr.estado in ('completado', 'no_aprobado')),
         string_agg(distinct format('%s (%s)', pr.nombre, case pr.estado when 'estimando' then 'en estimación' else 'con la propuesta enviada' end), '; ')
           filter (where pr.estado in ('estimando', 'enviado'))
    into v_x, v_y
    from jsonb_array_elements(v_partes) q join proyectos pr on pr.id = q->>'proyecto_id';
  if v_x is not null then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'obra_terminada', 'texto',
      format('Hay horas en una obra que ya no está activa: %s. Su parte del sueldo va a esa obra igual: el trabajo se hizo ahí.', v_x));
  end if;
  if v_y is not null then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'obra_sin_aprobar', 'texto',
      format('Hay horas en una obra que todavía no está aprobada: %s. Su parte del sueldo va a esa obra.', v_y));
  end if;
  if c.tipo = 'fuera_de_ciclo' then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'fuera_de_ciclo', 'texto',
      format('Es una nómina fuera de ciclo%s: %s', coalesce(' («' || c.tipo_texto || '»)', ''),
             case when c.toma_horas
                  then 'se queda con las horas aprobadas de su período (ninguna otra nómina las repartirá).'
                  else 'el sueldo de la gente de campo se reparte por las horas aprobadas de su período SIN quedárselas (siguen siendo de su '
                       'nómina regular). Si esta es la nómina que paga esas horas (un finiquito, la primera de alguien nuevo), dilo antes '
                       'de postearla.' end));
  end if;
  -- (un impuesto sin su renglón de las declaraciones: el amarre con el 941, el 940 y el RT-6 no lo contaría)
  select string_agg(distinct format('«%s»', coalesce(l.columna, l.concepto)), ', ') into v_x
    from nomina_lineas l where l.corrida_id = c.id and l.clase in ('imp_empleado', 'imp_patron') and l.declara is null and l.monto <> 0;
  if v_x is not null then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'sin_renglon', 'texto',
      format('%s trae(n) impuestos y el mapeo no dice con qué renglón de las declaraciones amarra(n) (la retención, Social Security, '
             'Medicare, FUTA, reempleo): entra(n) al libro, pero el amarre con el 941, el 940 y el RT-6 no lo(s) puede contar. Si es un '
             'total sin su detalle, baja el archivo con el detalle de impuestos; si es un impuesto nuevo, dile su renglón.', v_x));
  end if;
  -- (los reembolsos que paga esta nómina bajan lo que se le debe A CADA EMPLEADO, a su nombre: si a alguno no se le debe tanto,
  -- se dice. Lo que se le deba a otro empleado no cuenta: cada línea del reembolso lleva a su persona.)
  if c.reembolsos > 0 then
    select string_agg(q.t, '; ' order by q.t) into v_x
      from (select case when z.debe >= 0 then format('a %s se le deben %s en %s', z.nombre, fn_nomina_usd(z.debe), z.cuenta)
                        else format('a %s no se le debe nada en %s (ya tiene %s devueltos de más)', z.nombre, z.cuenta, fn_nomina_usd(-z.debe)) end
                   || format(' y esta nómina le devuelve %s', fn_nomina_usd(z.devuelve)) as t
              from (select l.cuenta, pe.nombre, sum(l.monto) as devuelve,
                           coalesce((select -sum(m.monto) from asiento_lineas m
                                      where m.cuenta = l.cuenta and m.tercero_tipo = 'empleado' and m.tercero_id = pf.id::text), 0) as debe
                      from nomina_lineas l
                      join nomina_personas pe on pe.id = l.persona_id
                      left join perfiles pf on pf.id = pe.usuario_id
                     where l.corrida_id = c.id and l.clase = 'reembolso' and l.cuenta is not null
                     group by l.cuenta, pe.id, pe.nombre, pf.id
                    having sum(l.monto) <> 0) z
             where z.debe < z.devuelve) q;
    v_avisos := v_avisos || jsonb_build_object('codigo', 'reembolsos', 'texto',
      format('Esta nómina devuelve %s en reembolsos a empleados: baja lo que se les debe, a nombre de cada uno.%s', fn_nomina_usd(c.reembolsos),
             coalesce(' OJO: ' || v_x || ': quedaría al revés. ¿Ese gasto se registró como pagado de su bolsillo (un recibo con reembolso)? '
                      'Si no, regístralo.', '')));
  end if;

  -- EL ASIENTO (el journal): el debe por cuenta, obra y CO; lo patronal de obra junto, a la bolsa; los reembolsos, por persona y
  -- a su nombre; y el haber: lo que queda por pagar en cada cuenta (fn_nomina_journal: lo que dice el journal guardado).
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('cuenta', q.cuenta, 'monto', q.monto::text, 'proyecto_id', q.proyecto_id,
                                                                 'co', q.co, 'memo', q.memo, 'tercero_tipo', q.tt, 'tercero_id', q.ti))
                            order by q.o, q.cuenta, q.proyecto_id, q.co nulls first, q.ti nulls first),
                  '[]'::jsonb)
    into v_lin
    from (select 1 as o, x.cuenta, x.proyecto_id, x.co, sum(x.monto) as monto,
                 format('Nómina del %s%s', v_dia,
                        case when bool_and(x.clase = 'bruto') and sum(x.horas) is not null then format(': %s h', fn_nomina_h(sum(x.horas)))
                             when bool_and(x.clase = 'patron') then ': lo que el patrón paga por su gente (impuestos y beneficios)'
                             else '' end) as memo, null::text as tt, null::text as ti
            from (select q->>'cuenta' as cuenta, q->>'proyecto_id' as proyecto_id, q->>'co' as co, (q->>'monto')::numeric as monto,
                         (q->>'horas')::numeric as horas, q->>'clase' as clase
                    from jsonb_array_elements(v_partes) q
                   where not (q->>'clase' = 'patron' and q->>'destino' = 'obra')) x
           group by x.cuenta, x.proyecto_id, x.co having sum(x.monto) <> 0
          union all
          select 2, v_ct->>'bolsa', null, null, sum((q->>'monto')::numeric),
                 format('Nómina del %s: lo que el patrón paga por la gente de obra (burden real; se reparte a sus obras)', v_dia), null, null
            from jsonb_array_elements(v_partes) q
           where q->>'clase' = 'patron' and q->>'destino' = 'obra'
          having coalesce(sum((q->>'monto')::numeric), 0) <> 0
          union all
          -- (a nombre de cada empleado por su perfil —el tercero de la línea—; su nombre NO va escrito en el memo: el libro lo
          -- lee más gente que la nómina)
          select 3, l.cuenta, null, null, sum(l.monto), format('Nómina del %s: reembolso a un empleado (a su nombre)', v_dia),
                 case when pf.id is not null then 'empleado' end, pf.id::text
            from nomina_lineas l
            join nomina_personas pe on pe.id = l.persona_id
            left join perfiles pf on pf.id = pe.usuario_id
           where l.corrida_id = c.id and l.clase = 'reembolso' and l.cuenta is not null
           group by l.cuenta, pe.id, pf.id having sum(l.monto) <> 0
          union all
          select 4, j.cuenta, null, null, j.monto,
                 left(format('Nómina del %s: %s', v_dia,
                             concat_ws(', ', (select string_agg(distinct coalesce(l.columna, l.concepto), ', ') from nomina_lineas l
                                               where l.corrida_id = c.id and l.cuenta = j.cuenta
                                                 and l.clase in ('imp_empleado', 'imp_patron', 'ben_patron', 'deduccion')),
                                             case when j.cuenta = v_neto then 'el neto (y los reembolsos) por pagar' end)), 200), null, null
            from fn_nomina_journal(c.id) j
           where j.clase = 'pasivo' and j.cuenta is not null and j.monto <> 0) q;
  -- EL REPARTO DEL BURDEN REAL a las obras: 5010 por obra y CO contra la bolsa
  select case when coalesce(sum(x.monto), 0) = 0 then null
              else jsonb_agg(jsonb_strip_nulls(jsonb_build_object('cuenta', v_ct->>'burden_obra', 'monto', x.monto::text,
                                                                  'proyecto_id', x.proyecto_id, 'co', x.co,
                                                                  'memo', format('Burden real de la nómina del %s, por las mismas horas', v_dia)))
                             order by x.proyecto_id, x.co nulls first)
                   || jsonb_build_object('cuenta', v_ct->>'bolsa', 'monto', (-sum(x.monto))::text,
                                         'memo', format('Burden real de la nómina del %s, repartido a sus obras', v_dia)) end
    into v_bur
    from (select q->>'proyecto_id' as proyecto_id, q->>'co' as co, sum((q->>'monto')::numeric) as monto
            from jsonb_array_elements(v_partes) q
           where q->>'clase' = 'patron' and q->>'destino' = 'obra'
           group by 1, 2 having sum((q->>'monto')::numeric) <> 0) x;
  -- LO QUE QUEDA POR PAGAR en cada cuenta (lo que cobrará Gusto): lo que el journal acredita en cada una. CON SU SIGNO: una
  -- corrección que DEVUELVE (importes en negativo) deja esas cuentas al revés —a favor—, y eso también se guarda (en
  -- negativo): Gusto lo descuenta de su cargo siguiente o lo devuelve al banco, y entonces se casa.
  select coalesce(jsonb_object_agg(j.cuenta, -j.monto), '{}'::jsonb) into v_pas
    from fn_nomina_journal(c.id) j where j.clase = 'pasivo' and j.cuenta is not null and j.monto <> 0;
  if exists (select 1 from jsonb_each_text(v_pas) e where (e.value)::numeric < 0) then
    v_avisos := v_avisos || jsonb_build_object('codigo', 'a_favor', 'texto',
      format('Esta nómina trae importes en negativo (una corrección que devuelve) y deja A FAVOR %s. No es dinero que haya que pagar: '
             'Gusto lo descuenta de su cargo siguiente o lo devuelve al banco; cuando llegue ese movimiento, se casa en «Cargos de '
             'Gusto» y estas cuentas quedan en cero. (Cómo lo cobra Gusto, a confirmar con la primera corrección de verdad.)',
             (select string_agg(format('%s en %s', fn_nomina_usd(-(e.value)::numeric), e.key), ', ' order by e.key)
                from jsonb_each_text(v_pas) e where (e.value)::numeric < 0)));
  end if;
  select coalesce(jsonb_object_agg(e.key, case when e.key = v_neto then 'neto'
                                               when exists (select 1 from nomina_lineas l
                                                             where l.corrida_id = c.id and l.cuenta = e.key
                                                               and l.clase in ('imp_empleado', 'imp_patron')) then 'impuestos'
                                               else 'deducciones' end), '{}'::jsonb)
    into v_cla from jsonb_each(v_pas) e;
  select coalesce(sum(cp.neto), 0) into v_ndd from nomina_corrida_personas cp
   where cp.corrida_id = c.id and coalesce(cp.metodo_pago, '') !~* 'check';
  if jsonb_array_length(v_frenos) = 0 and jsonb_array_length(v_lin) < 2 then
    v_frenos := v_frenos || jsonb_build_object('codigo', 'vacia', 'texto', 'Esta nómina no trae nada que llevar al libro (todo en cero).');
  end if;
  if jsonb_array_length(v_frenos) = 0 then
    v_visto := md5(jsonb_build_object('lineas', v_lin, 'burden', v_bur, 'fecha', v_fa->>'fecha',
                                      'horas', (select coalesce(jsonb_agg(jsonb_build_array(q->'horas_id', q->'horas', q->'proyecto_id', q->'co',
                                                                                             q->'bruto', q->'patron') order by (q->>'horas_id')::bigint),
                                                                '[]'::jsonb) from jsonb_array_elements(v_horas) q))::text);
  end if;
  return jsonb_build_object(
    'corrida', c.id, 'estado', c.estado, 'dia_pago', c.dia_pago, 'periodo_desde', c.periodo_desde, 'periodo_hasta', c.periodo_hasta,
    'tipo', c.tipo, 'toma_horas', c.toma_horas, 'fecha_asiento', v_fa, 'puede_postear', jsonb_array_length(v_frenos) = 0 and c.estado = 'importada',
    'frenos', v_frenos, 'avisos', v_avisos || c.avisos, 'personas', v_pers,
    'asiento', jsonb_build_object('lineas', v_lin), 'burden', case when v_bur is null then null else jsonb_build_object('lineas', v_bur) end,
    'pasivos', v_pas, 'clases', v_cla, 'neto_deposito', v_ndd, 'partes', v_partes, 'horas', v_horas,
    'totales', jsonb_build_object('bruto', c.bruto, 'imp_empleado', c.imp_empleado, 'deducciones', c.deducciones, 'neto', c.neto,
                                  'reembolsos', c.reembolsos, 'imp_patron', c.imp_patron, 'ben_patron', c.ben_patron,
                                  'debe', (select coalesce(sum((q->>'monto')::numeric), 0) from jsonb_array_elements(v_lin) q
                                            where (q->>'monto')::numeric > 0)),
    'visto', v_visto);
end $$;
revoke execute on function public.fn_nomina_plan(uuid, boolean) from public, anon, service_role;
grant  execute on function public.fn_nomina_plan(uuid, boolean) to authenticated;
comment on function public.fn_nomina_plan(uuid, boolean) is 'c15: EL PLAN de una corrida: qué iría al libro y qué lo frena. Por persona, según su clase (campo: su bruto por sus horas aprobadas del período, por obra y CO, con el núcleo de c10; oficial: la parte de obra por sus horas en obra entre las que cubre su sueldo; oficina), lo patronal por las mismas horas (lo de obra, a la bolsa del burden real y de ahí a cada obra), el asiento (asiento.lineas), el reparto del burden (burden.lineas), lo que queda por pagar en cada cuenta (pasivos), las partes y los reportes de horas que se usarían, los frenos y los avisos en llano, y la huella de todo ello (visto: nula si hay frenos). No escribe nada; con p_tomar, toma las horas de cada persona en el período. Con el código del teléfono. Solo el dueño.';

-- LA PROPUESTA que enseña la pantalla: de una corrida importada, su plan
-- (sin las listas internas); de una posteada o anulada, lo que fue al
-- libro: su reparto guardado, su asiento y lo que queda por pagar.
create or replace function public.fn_nomina_propuesta(p_corrida uuid) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c nomina_corridas;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  select * into c from nomina_corridas where id = p_corrida;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa corrida.';
  end if;
  if c.estado = 'importada' then
    return fn_nomina_plan(p_corrida, false) - array['partes', 'horas', 'clases', 'neto_deposito'];
  end if;
  return jsonb_build_object(
    'corrida', c.id, 'estado', c.estado, 'dia_pago', c.dia_pago, 'periodo_desde', c.periodo_desde, 'periodo_hasta', c.periodo_hasta,
    'tipo', c.tipo, 'toma_horas', c.toma_horas, 'puede_postear', false, 'frenos', '[]'::jsonb, 'avisos', c.avisos,
    'asiento', coalesce(c.plan->'asiento', '{}'::jsonb) || jsonb_build_object('id', c.asiento_id, 'numero', c.asiento_numero, 'fecha', c.fecha_asiento),
    'burden', case when c.burden_asiento_id is not null
                   then c.plan->'burden' || jsonb_build_object('id', c.burden_asiento_id,
                                                               'numero', (select a.numero from asientos a where a.id = c.burden_asiento_id)) end,
    'pasivos', c.pasivos,
    'anulada', case when c.estado = 'anulada' then jsonb_build_object('el', c.anulada_el, 'motivo', c.anulada_motivo,
                                                                     'reverso', (select a.numero from asientos a where a.id = c.reverso_id)) end,
    'descartada', case when c.estado = 'descartada' then jsonb_build_object('el', c.descartada_el, 'motivo', c.descartada_motivo) end,
    'personas', (select coalesce(jsonb_agg(jsonb_build_object(
                          'persona_id', cp.persona_id, 'n', cp.n, 'nombre', cp.nombre, 'bruto', cp.bruto, 'patron', cp.imp_patron + cp.ben_patron,
                          'neto', cp.neto, 'horas_gusto', cp.horas, 'decision', cp.decision,
                          'horas_usadas', (select sum(rh.horas) from nomina_reparto_horas rh where rh.corrida_id = c.id and rh.persona_id = cp.persona_id),
                          'partes', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                                'clase', r.clase, 'destino', r.destino, 'cuenta', r.cuenta, 'proyecto_id', r.proyecto_id,
                                                'obra', (select pr.nombre from proyectos pr where pr.id = r.proyecto_id), 'co', r.co,
                                                'horas', r.horas, 'monto', r.monto)) order by r.n), '[]'::jsonb)
                                       from nomina_reparto r where r.corrida_id = c.id and r.persona_id = cp.persona_id)) order by cp.n), '[]'::jsonb)
                   from nomina_corrida_personas cp where cp.corrida_id = c.id),
    'totales', jsonb_build_object('bruto', c.bruto, 'imp_empleado', c.imp_empleado, 'deducciones', c.deducciones, 'neto', c.neto,
                                  'reembolsos', c.reembolsos, 'imp_patron', c.imp_patron, 'ben_patron', c.ben_patron),
    'visto', c.huella);
end $$;
revoke execute on function public.fn_nomina_propuesta(uuid) from public, anon, service_role;
grant  execute on function public.fn_nomina_propuesta(uuid) to authenticated;
comment on function public.fn_nomina_propuesta(uuid) is 'c15: lo que la pantalla enseña de una corrida. Importada: su plan (personas con sus partes por obra, el asiento, el reparto del burden, lo que quedará por pagar, los frenos, los avisos y «visto», lo que hay que devolver al postear). Posteada o anulada: lo que fue al libro (su reparto guardado, sus asientos, lo que queda por pagar; y, anulada, cuándo, por qué y su reverso). Con el código del teléfono. Solo el dueño.';

-- POSTEAR: lo que Edgar VIO es lo que entra. p_visto es la huella que le dio
-- la propuesta; si entre que miró y que tocó cambió algo (una hora aprobada,
-- desaprobada o movida de obra, una cuenta, una persona), MX011 y no entra
-- nada: se vuelve a mirar. Con frenos, MX008 con la lista. Dos toques (o dos
-- pestañas) dejan UN asiento: el segundo recibe el que ya estaba.
-- Y EL DEVENGO ESTÁNDAR de c3: c3 no devenga un mes que tiene journal de
-- nómina (contaría dos veces lo que el journal ya pagó), y si el journal
-- llega DESPUÉS de un devengo dice que «volver a devengar lo deshace». Aquí
-- se hace solo, en la misma transacción: si el mes del asiento tiene un
-- devengo estándar vivo y sigue abierto, se deshace por la función de c3
-- (el dueño la puede llamar); el resultado lo dice.
create or replace function public.fn_nomina_postear(p_corrida uuid, p_visto text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c      nomina_corridas;
  d      nomina_corridas;
  v_plan jsonb;
  v_mes  text;
  v_dev  jsonb;
  v_devtxt text;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  perform pg_advisory_xact_lock(820261115, hashtext('nomina:corrida:' || p_corrida::text));
  select * into c from nomina_corridas where id = p_corrida for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa corrida.';
  end if;
  if c.estado = 'posteada' then
    return jsonb_build_object('corrida', c.id, 'posteada', true, 'ya_estaba', true,
                              'asiento', jsonb_build_object('id', c.asiento_id, 'numero', c.asiento_numero, 'fecha', c.fecha_asiento));
  end if;
  if c.estado <> 'importada' then
    raise exception using errcode = 'MX008',
      message = format('Esa corrida está %s: no se postea. Si hace falta, vuelve a subir su archivo.', c.estado);
  end if;
  v_plan := fn_nomina_plan(p_corrida, true);
  if jsonb_array_length(v_plan->'frenos') > 0 then
    raise exception using errcode = 'MX008',
      message = format('La nómina del %s todavía no se puede postear: %s', fn_nomina_dia(c.dia_pago),
                       left((select string_agg(q->>'texto', ' · ') from jsonb_array_elements(v_plan->'frenos') q), 1500)),
      detail = (select jsonb_agg(q->'codigo') from jsonb_array_elements(v_plan->'frenos') q)::text;
  end if;
  if p_visto is null or p_visto is distinct from v_plan->>'visto' then
    raise exception using errcode = 'MX011',
      message = 'Lo que se va a postear ya no es lo que viste: cambiaron las horas aprobadas del período, una cuenta o una persona entre '
                'que miraste y que tocaste. No se posteó nada: vuelve a mirar la propuesta.';
  end if;
  -- el reparto y el lote
  perform set_config('mx_nomina.escribe', 'nomina_reparto', true);
  insert into nomina_reparto (corrida_id, n, persona_id, clase, destino, cuenta, proyecto_id, co, horas, monto)
  select c.id, row_number() over ()::int, (q.p->>'persona_id')::uuid, q.p->>'clase', q.p->>'destino', q.p->>'cuenta', q.p->>'proyecto_id',
         q.p->>'co', (q.p->>'horas')::numeric, (q.p->>'monto')::numeric
    from (select value as p from jsonb_array_elements(v_plan->'partes') with ordinality e(value, o) order by e.o) q;
  begin
    perform set_config('mx_nomina.escribe', 'nomina_reparto_horas', true);
    insert into nomina_reparto_horas (corrida_id, persona_id, horas_id, usuario_id, fecha, proyecto_id, co, fase, horas, bruto, patron, titular)
    select c.id, (q->>'persona_id')::uuid, (q->>'horas_id')::bigint, (q->>'usuario_id')::uuid, (q->>'fecha')::date, q->>'proyecto_id',
           q->>'co', q->>'fase', (q->>'horas')::numeric, (q->>'bruto')::numeric, (q->>'patron')::numeric, (q->>'titular')::boolean
      from jsonb_array_elements(v_plan->'horas') q;
  exception when unique_violation then
    perform set_config('mx_nomina.escribe', '', true);
    raise exception using errcode = 'MX011',
      message = 'Otra nómina acaba de quedarse con horas de este período mientras posteabas: no se posteó nada. Vuelve a mirar la propuesta.';
  end;
  -- la corrida pasa a posteada: su puente pone el journal y el reparto del burden en el libro
  perform set_config('mx_nomina.escribe', 'nomina_corridas', true);
  update nomina_corridas
     set estado = 'posteada', plan = jsonb_build_object('asiento', v_plan->'asiento', 'burden', v_plan->'burden', 'fecha', v_plan->'fecha_asiento',
                                                        'clases', v_plan->'clases', 'neto_deposito', v_plan->'neto_deposito'),
         huella = v_plan->>'visto', pasivos = v_plan->'pasivos', posteada_el = clock_timestamp(), posteada_por = auth.uid()
   where id = c.id
  returning * into d;
  perform set_config('mx_nomina.escribe', '', true);
  -- el devengo estándar del mes, si lo había
  v_mes := to_char(d.fecha_asiento, 'YYYY-MM');
  if exists (select 1 from asientos a
              where a.origen_tabla = 'horas_devengo' and a.origen_id = v_mes and a.camino not in ('reverso', 'reverso_automatico')
                and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    begin
      v_dev := fn_horas_devengar(v_mes);
      v_devtxt := format('El mes %s tenía un devengo estándar de horas: con el journal de la nómina dentro contaba dos veces esas horas, y se '
                         'deshizo aquí mismo.', v_mes);
    exception when others then
      v_devtxt := format('El mes %s tiene un devengo estándar de horas que ya no se pudo deshacer (%s): cuenta dos veces lo que esta nómina '
                         'pagó. Míralo antes de cerrar el mes.', v_mes, left(sqlerrm, 300));
    end;
  end if;
  return jsonb_build_object(
    'corrida', d.id, 'posteada', true, 'ya_estaba', false,
    'asiento', jsonb_build_object('id', d.asiento_id, 'numero', d.asiento_numero, 'fecha', d.fecha_asiento),
    'burden', case when d.burden_asiento_id is not null
                   then jsonb_build_object('id', d.burden_asiento_id, 'numero', (select a.numero from asientos a where a.id = d.burden_asiento_id)) end,
    'pasivos', d.pasivos, 'avisos', v_plan->'avisos', 'devengo', v_devtxt,
    'horas', jsonb_array_length(v_plan->'horas'));
end $$;
revoke execute on function public.fn_nomina_postear(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_nomina_postear(uuid, text) to authenticated;
comment on function public.fn_nomina_postear(uuid, text) is 'c15: POSTEA una corrida importada: vuelve a calcular su plan con las horas tomadas y, si no hay frenos (MX008, con la lista) y es lo que Edgar vio (p_visto: la huella de la propuesta; si no, MX011 y nada cambia), guarda el reparto y el lote de horas y pasa la corrida a posteada: su puente pone en el libro el journal (en la fecha del día de pago) y el reparto del burden real a las obras. Si el mes tenía un devengo estándar de horas vivo, lo deshace por la función de c3 y lo dice. Dos toques dejan un asiento (ya_estaba). Devuelve {corrida, posteada, ya_estaba, asiento, burden, pasivos, avisos, devengo, horas}. Con el código del teléfono. Solo el dueño.';

-- ANULAR una corrida posteada: no se borra nada. Sus dos asientos se
-- reversan (por el puente: fn_reversar_interno de c2), su lote suelta sus
-- horas y la corrida queda anulada, con su motivo; su archivo se puede
-- volver a subir. Con cargos de Gusto casados contra ella, antes se
-- des-casan (si no, lo pagado quedaría en el libro sin lo que pagaba).
create or replace function public.fn_nomina_anular(p_corrida uuid, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c   nomina_corridas;
  d   nomina_corridas;
  v_x text;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  if coalesce(length(btrim(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'Anular una corrida dice por qué (motivo): queda escrito en su reverso.';
  end if;
  perform pg_advisory_xact_lock(820261115, hashtext('nomina:pagos'));
  perform pg_advisory_xact_lock(820261115, hashtext('nomina:corrida:' || p_corrida::text));
  select * into c from nomina_corridas where id = p_corrida for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe esa corrida.';
  end if;
  if c.estado = 'anulada' then
    return jsonb_build_object('corrida', c.id, 'anulada', true, 'ya_estaba', true,
                              'reverso', (select a.numero from asientos a where a.id = c.reverso_id));
  end if;
  if c.estado <> 'posteada' then
    raise exception using errcode = 'MX008',
      message = format('Esa corrida está %s: solo se anula una posteada%s.', c.estado,
                       case when c.estado = 'importada' then ' (una importada se descarta)' else '' end);
  end if;
  -- (los que SIGUEN casados en el banco: uno que ya se des-casó en la Bandeja no paga nada, aunque aquí no se haya deshecho)
  select string_agg(format('el del %s por %s', fn_nomina_dia(pg.fecha), fn_nomina_usd(pg.monto)), ', ' order by pg.fecha) into v_x
    from nomina_pagos pg
    join movimientos_banco mb on mb.id = pg.movimiento_id and mb.asiento_id = pg.asiento_id and mb.estado in ('casado', 'en_transito')
   where pg.estado = 'aplicado' and exists (select 1 from nomina_pago_partes pp where pp.pago_id = pg.id and pp.corrida_id = c.id);
  if v_x is not null then
    raise exception using errcode = 'MX008',
      message = format('Esta nómina tiene cargos de Gusto casados (%s): des-cásalos antes de anularla, o lo pagado quedaría en el libro sin '
                       'lo que pagaba. Después de volver a subirla y postearla, se casan otra vez.', v_x);
  end if;
  perform set_config('mx_nomina.escribe', 'nomina_corridas', true);
  update nomina_corridas set estado = 'anulada', anulada_el = clock_timestamp(), anulada_por = auth.uid(), anulada_motivo = btrim(p_motivo)
   where id = c.id
  returning * into d;
  perform set_config('mx_nomina.escribe', 'nomina_reparto_horas', true);
  update nomina_reparto_horas set vivo = false where corrida_id = c.id and vivo;
  perform set_config('mx_nomina.escribe', '', true);
  return jsonb_build_object('corrida', d.id, 'anulada', true, 'ya_estaba', false,
                            'reverso', (select a.numero from asientos a where a.id = d.reverso_id),
                            'reverso_burden', (select a.numero from asientos a where a.id = d.burden_reverso_id),
                            'nota', 'Su archivo se puede volver a subir: entrará como una corrida nueva.');
end $$;
revoke execute on function public.fn_nomina_anular(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_nomina_anular(uuid, text) to authenticated;
comment on function public.fn_nomina_anular(uuid, text) is 'c15: ANULA una corrida posteada, con su motivo: su puente reversa su journal y el reparto de su burden (no se borra nada), su lote suelta sus horas y la corrida queda anulada; su archivo se puede volver a subir. Con cargos de Gusto casados contra ella, MX008: antes se des-casan. Dos toques, un reverso (ya_estaba). Con el código del teléfono. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 12. EL CARGO DE GUSTO EN EL BANCO. Gusto no cobra el día de pago: cobra
--     ANTES (hasta cuatro días hábiles antes) y en VARIOS cargos por nómina:
--     el neto, los impuestos (lo retenido y lo del patrón, FUTA y reempleo
--     incluidos), los reembolsos y la manutención; y, aparte, su cuota
--     mensual, que no es nómina. c6 deja cada cargo en la Bandeja con el
--     motivo «nomina» («espera su journal»). Aquí se casa con su corrida:
--     el journal dejó por pagar el neto y los reembolsos (2210), el 941
--     (2220), el FUTA (2225), el reempleo (2230) y las deducciones (2240),
--     y el cargo los paga: Dr esas cuentas / Cr el banco, EN LA FECHA DEL
--     CARGO (el dinero sale ese día: el banco concilia; entre el cargo y el
--     día de pago esas cuentas quedan con lo adelantado a Gusto).
--     · El asiento lo pone c6, por su puerta de siempre (fn_banco_clasificar,
--       llamada por el dueño, con su motivo: «Nómina de Gusto: …»), y deja
--       el movimiento casado con él: la conciliación del banco se confirma
--       como con cualquier otro cargo. Deshacer es fn_banco_descasar.
--     · Un cargo puede pagar varias cuentas de una corrida (los impuestos:
--       2220, 2225 y 2230) o de dos corridas (la regular y un bono del mismo
--       día); una corrida se paga con varios cargos. Las partes de un cargo
--       suman el cargo AL CENTAVO y ninguna paga más de lo que su corrida
--       dejó por pagar: lo que no casa así no se casa, y se dice con las
--       dos cifras.
--     · LA CUOTA DE GUSTO sale por fn_nomina_cargo_cuota: a su gasto (6500),
--       con su motivo, por la misma puerta de c6. El descriptor de c6 la
--       atrapa («GUSTO»), pero no para siempre: es lo que c6 mismo dice
--       («si de verdad es otra cosa —la cuota mensual de Gusto—, dilo en el
--       motivo»).
-- ---------------------------------------------------------------------
-- Lo que cada corrida posteada dejó por pagar, por cuenta, y lo que falta.
-- CON SU SIGNO: en positivo, lo que se debe; en negativo, lo que quedó A
-- FAVOR (una corrección que devuelve). Un cargo casado cuenta mientras SIGUE
-- casado con su asiento en el banco: si se des-casó en la Bandeja (por
-- fuera de la nómina), su asiento ya está reversado y lo que pagaba vuelve a
-- estar pendiente, aunque aquí nadie lo haya deshecho todavía.
create or replace function public.fn_nomina_pendiente(p_corrida uuid default null)
returns table (corrida_id uuid, dia_pago date, cuenta text, clase text, acreditado numeric(14,2), pagado numeric(14,2),
               pendiente numeric(14,2))
language sql stable
set search_path = public, pg_temp
as $$
  select c.id, c.dia_pago, e.key, coalesce(c.plan->'clases'->>e.key, 'deducciones'), (e.value)::numeric(14,2),
         coalesce(pg.s, 0)::numeric(14,2), ((e.value)::numeric - coalesce(pg.s, 0))::numeric(14,2)
    from public.nomina_corridas c
    cross join lateral jsonb_each_text(c.pasivos) e
    left join lateral (select sum(pp.monto) as s
                         from public.nomina_pago_partes pp
                         join public.nomina_pagos g on g.id = pp.pago_id
                         join public.movimientos_banco m on m.id = g.movimiento_id
                        where pp.corrida_id = c.id and pp.cuenta = e.key and g.estado = 'aplicado'
                          and m.asiento_id = g.asiento_id and m.estado in ('casado', 'en_transito')) pg on true
   where c.estado = 'posteada' and (p_corrida is null or c.id = p_corrida)
     and (select public.fn_nomina_ve())
$$;
revoke execute on function public.fn_nomina_pendiente(uuid) from public, anon, service_role;
grant  execute on function public.fn_nomina_pendiente(uuid) to authenticated;
comment on function public.fn_nomina_pendiente(uuid) is 'c15: lo que cada corrida posteada (o una) dejó por pagar en cada cuenta (acreditado: lo que dice su journal; en negativo si quedó a favor —una corrección que devuelve—), lo que ya movieron sus cargos casados que siguen casados en el banco (pagado) y lo que falta (pendiente: en positivo, por pagar; en negativo, a favor), con la clase de la cuenta (neto, impuestos o deducciones). Solo lectura; con el código del teléfono.';

-- LA PROPUESTA de un movimiento de Gusto pendiente: qué corrida (o qué dos)
-- y qué cuentas paga, si alguna combinación da su monto AL CENTAVO. Se miran
-- las corridas posteadas con día de pago cerca del movimiento (de
-- cargo_dias_despues antes a cargo_dias_antes después; las que tienen algo
-- A FAVOR, hasta tres meses antes) y, de cada una: su neto (el de quienes
-- cobran por depósito), sus reembolsos, el neto con los reembolsos, sus
-- impuestos, sus deducciones, y todo junto; después, las mismas clases
-- sumando dos corridas. Lo que una corrección dejó a favor entra RESTANDO:
-- un cargo de impuestos que Gusto cobró con ese descuento casa con «los
-- impuestos de la nómina del día X menos lo que quedó a favor de la del día
-- Y»; y una DEVOLUCIÓN de Gusto (un depósito), con lo que quedó a favor. La
-- descripción del banco (NET, TAX, REM, CSD, FEE) ordena las opciones;
-- nunca decide sola. Si nada da el monto, lo dice con las cifras de cada
-- corrida cercana.
create or replace function public.fn_nomina_cargo_propuesta(p_movimiento uuid) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  m       movimientos_banco;
  cfg     nomina_config;
  v_x     numeric;
  v_txt   text;
  v_hint  text;
  v_ops   jsonb := '[]'::jsonb;
  v_uno   jsonb := '[]'::jsonb;
  c       record;
  o       jsonb;
  o2      jsonb;
  v_res   jsonb := '[]'::jsonb;
  v_cerca text;
  v_pago  nomina_pagos;
  c_que   constant jsonb := '{"neto": "el neto", "reembolsos": "los reembolsos", "neto_y_reembolsos": "el neto y los reembolsos",
                              "impuestos": "los impuestos (lo retenido y lo del patrón)", "deducciones": "las deducciones",
                              "todo": "todo lo que quedó por pagar"}';
begin
  perform fn_nomina_exigir_dueno();
  select * into m from movimientos_banco where id = p_movimiento;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese movimiento del banco.';
  end if;
  select * into cfg from nomina_config where id = 1;
  -- (su pago vivo DE VERDAD: aplicado y con el movimiento todavía casado con su asiento)
  select g.* into v_pago from nomina_pagos g
   where g.movimiento_id = m.id and g.estado = 'aplicado' and m.asiento_id = g.asiento_id and m.estado in ('casado', 'en_transito');
  v_x := -m.monto;   -- (lo que salió del banco: un cargo, en positivo; una devolución de Gusto, en negativo)
  v_txt := coalesce(m.desc_norm, '') || ' ' || coalesce(m.descripcion, '') || ' ' || coalesce(m.memo, '');
  v_hint := case when m.monto > 0 then 'devolucion'
                 when v_txt ~* (cfg.cargo_patrones->>'cuota') then 'cuota'
                 when v_txt ~* (cfg.cargo_patrones->>'impuestos') then 'impuestos'
                 when v_txt ~* (cfg.cargo_patrones->>'reembolsos') then 'reembolsos'
                 when v_txt ~* (cfg.cargo_patrones->>'manutencion') then 'deducciones'
                 when v_txt ~* (cfg.cargo_patrones->>'neto') then 'neto' end;
  if v_pago.id is not null or m.estado <> 'pendiente' or m.monto = 0 then
    return jsonb_build_object('movimiento', m.id, 'fecha', m.fecha, 'monto', v_x, 'descripcion', m.descripcion, 'estado', m.estado,
                              'pago', v_pago.id, 'clase_probable', v_hint, 'opciones', '[]'::jsonb, 'mejor', null,
                              'texto', case when v_pago.id is not null then 'Este cargo ya está casado desde la nómina.'
                                            when m.monto = 0 then 'Este movimiento no mueve dinero.'
                                            else 'Este movimiento ya está resuelto en la Bandeja.' end);
  end if;
  -- las opciones de cada corrida cercana
  for c in
    select k.id, k.dia_pago, k.neto, k.reembolsos, coalesce((k.plan->>'neto_deposito')::numeric, k.neto) as neto_dd,
           (select coalesce(jsonb_agg(jsonb_build_object('cuenta', p.cuenta, 'clase', p.clase, 'pendiente', p.pendiente) order by p.cuenta), '[]'::jsonb)
              from fn_nomina_pendiente(k.id) p where p.pendiente <> 0) as pend
      from nomina_corridas k
     where k.estado = 'posteada'
       and (   k.dia_pago between m.fecha - cfg.cargo_dias_despues and m.fecha + cfg.cargo_dias_antes
            or (k.dia_pago between m.fecha - 92 and m.fecha + cfg.cargo_dias_antes
                and exists (select 1 from fn_nomina_pendiente(k.id) p where p.pendiente < 0)))
     order by abs(k.dia_pago - m.fecha), k.dia_pago, k.id
  loop
    continue when jsonb_array_length(c.pend) = 0;
    v_cerca := concat_ws('; ', v_cerca, format('la nómina del %s tiene %s', fn_nomina_dia(c.dia_pago),
      (select string_agg(format('%s %s en %s (%s)', fn_nomina_usd(abs((q->>'pendiente')::numeric)),
                                case when (q->>'pendiente')::numeric < 0 then 'a favor' else 'por pagar' end, q->>'cuenta',
                                case q->>'clase' when 'neto' then 'neto y reembolsos' when 'impuestos' then 'impuestos' else 'deducciones' end),
                         ', ' order by q->>'cuenta') from jsonb_array_elements(c.pend) q)));
    -- (cada clase de cargo, con sus partes)
    v_uno := '[]'::jsonb;
    -- el neto de quienes cobran por depósito, los reembolsos, y el neto con los reembolsos (todo lo de la cuenta del neto)
    select v_uno || coalesce(jsonb_agg(z.op), '[]'::jsonb) into v_uno
      from (select jsonb_build_object('clase', w.clase, 'corrida', c.id, 'dia_pago', c.dia_pago, 'total', w.total,
                                      'partes', jsonb_build_array(jsonb_build_object('corrida', c.id, 'cuenta', q->>'cuenta', 'monto', w.total))) as op
              from jsonb_array_elements(c.pend) q
              cross join lateral (values ('neto', c.neto_dd), ('neto', c.neto), ('reembolsos', c.reembolsos),
                                         ('neto_y_reembolsos', (q->>'pendiente')::numeric)) w(clase, total)
             where q->>'clase' = 'neto' and w.total <> 0 and sign(w.total) = sign((q->>'pendiente')::numeric)
               and abs(w.total) <= abs((q->>'pendiente')::numeric)
             group by w.clase, w.total, q->>'cuenta') z;
    -- los impuestos (todas sus cuentas, enteras), las deducciones, y todo
    select v_uno || coalesce(jsonb_agg(z.op), '[]'::jsonb) into v_uno
      from (select jsonb_build_object('clase', w.clase, 'corrida', c.id, 'dia_pago', c.dia_pago,
                                      'total', sum((q->>'pendiente')::numeric),
                                      'partes', jsonb_agg(jsonb_build_object('corrida', c.id, 'cuenta', q->>'cuenta',
                                                                             'monto', (q->>'pendiente')::numeric) order by q->>'cuenta')) as op
              from jsonb_array_elements(c.pend) q
              cross join lateral (values ('impuestos'), ('deducciones'), ('todo')) w(clase)
             where w.clase = 'todo' or q->>'clase' = w.clase
             group by w.clase
            having sum((q->>'pendiente')::numeric) <> 0) z;
    v_ops := v_ops || v_uno;
  end loop;
  -- una corrida sola
  for o in select value from jsonb_array_elements(v_ops) loop
    if (o->>'total')::numeric = v_x
       and not exists (select 1 from jsonb_array_elements(v_res) r where r->'partes' = o->'partes') then
      v_res := v_res || jsonb_build_object(
        'clase', o->>'clase', 'partes', o->'partes', 'corridas', jsonb_build_array(o->'corrida'),
        'texto', case when v_x > 0 then format('Paga %s de la nómina del %s', c_que->>(o->>'clase'), fn_nomina_dia((o->>'dia_pago')::date))
                      else format('Devuelve lo que quedó a favor de la nómina del %s (%s)', fn_nomina_dia((o->>'dia_pago')::date),
                                  replace(c_que->>(o->>'clase'), 'todo lo que quedó por pagar', 'todo')) end);
    end if;
  end loop;
  -- dos corridas, la misma clase de cargo (una de ellas puede estar a favor: entra restando)
  if jsonb_array_length(v_res) = 0 then
    for o in select value from jsonb_array_elements(v_ops) loop
      for o2 in select value from jsonb_array_elements(v_ops) loop
        if o->>'clase' = o2->>'clase' and (o->>'corrida') < (o2->>'corrida') and (o->>'total')::numeric + (o2->>'total')::numeric = v_x
           and not exists (select 1 from jsonb_array_elements(v_res) r where r->'partes' = (o->'partes') || (o2->'partes')) then
          v_res := v_res || jsonb_build_object(
            'clase', o->>'clase', 'partes', (o->'partes') || (o2->'partes'), 'corridas', jsonb_build_array(o->'corrida', o2->'corrida'),
            'texto', case when (o->>'total')::numeric > 0 and (o2->>'total')::numeric > 0
                            then format('Paga %s de dos nóminas: la del %s y la del %s', c_que->>(o->>'clase'),
                                        fn_nomina_dia((o->>'dia_pago')::date), fn_nomina_dia((o2->>'dia_pago')::date))
                          when (o->>'total')::numeric < 0 and (o2->>'total')::numeric < 0
                            then format('Devuelve lo que quedó a favor de dos nóminas: la del %s y la del %s',
                                        fn_nomina_dia((o->>'dia_pago')::date), fn_nomina_dia((o2->>'dia_pago')::date))
                          else format('Paga %s de la nómina del %s, descontando %s que quedaron a favor de la del %s', c_que->>(o->>'clase'),
                                      fn_nomina_dia((case when (o->>'total')::numeric > 0 then o else o2 end->>'dia_pago')::date),
                                      fn_nomina_usd(-least((o->>'total')::numeric, (o2->>'total')::numeric)),
                                      fn_nomina_dia((case when (o->>'total')::numeric > 0 then o2 else o end->>'dia_pago')::date)) end);
        end if;
      end loop;
    end loop;
  end if;
  -- lo que dice el banco ordena las opciones (la que coincide, primero)
  select coalesce(jsonb_agg(r order by (case when r->>'clase' = v_hint or (v_hint = 'neto' and r->>'clase' = 'neto_y_reembolsos') then 0 else 1 end),
                            r->>'texto'), '[]'::jsonb)
    into v_res from jsonb_array_elements(v_res) r;
  return jsonb_build_object(
    'movimiento', m.id, 'fecha', m.fecha, 'monto', v_x, 'descripcion', m.descripcion, 'estado', m.estado, 'pago', null,
    'clase_probable', v_hint, 'opciones', v_res,
    'mejor', case when jsonb_array_length(v_res) = 1 and v_hint is distinct from 'cuota' then 0 end,
    'cuota', m.monto < 0 and (v_hint = 'cuota' or (v_hint is null and v_cerca is null)),
    'texto', case when v_hint = 'cuota' and jsonb_array_length(v_res) = 0
                    then format('Parece la cuota mensual de Gusto (%s): no es nómina; va a su gasto (%s).', fn_nomina_usd(v_x), cfg.cuenta_cuota)
                  when jsonb_array_length(v_res) = 1 then v_res->0->>'texto' || format(' (%s, al centavo).', fn_nomina_usd(abs(v_x)))
                  when jsonb_array_length(v_res) > 1
                    then format('El movimiento de %s casa de %s maneras: elige cuál.', fn_nomina_usd(abs(v_x)), jsonb_array_length(v_res))
                  when m.monto > 0 and v_cerca is null
                    then format('Es un depósito de Gusto (%s del %s) y ninguna nómina posteada cercana tiene nada a favor. Si es la '
                                'devolución de una corrección, sube y postea antes el archivo de esa corrección.', fn_nomina_usd(m.monto),
                                fn_nomina_dia(m.fecha))
                  when m.monto > 0
                    then format('Es un depósito de Gusto de %s y no casa al centavo con lo que ninguna nómina tiene a favor: %s. No se '
                                'casa solo: míralo en Gusto y dime qué devuelve.', fn_nomina_usd(m.monto), left(v_cerca, 900))
                  when v_cerca is null
                    then format('No hay ninguna nómina posteada con día de pago cerca de este cargo (%s del %s) que tenga algo por pagar. Si es de '
                                'una nómina, sube y postea antes su archivo; si es la cuota mensual de Gusto, dilo.', fn_nomina_usd(v_x),
                                fn_nomina_dia(m.fecha))
                  else format('El cargo es de %s y no casa al centavo con nada: %s. No se casa solo: míralo en Gusto (¿un cargo que junta '
                              'dos cosas?, ¿la cuota?) y dime qué paga.', fn_nomina_usd(v_x), left(v_cerca, 900)) end);
end $$;
revoke execute on function public.fn_nomina_cargo_propuesta(uuid) from public, anon, service_role;
grant  execute on function public.fn_nomina_cargo_propuesta(uuid) to authenticated;
comment on function public.fn_nomina_cargo_propuesta(uuid) is 'c15: la propuesta para un movimiento de Gusto pendiente en el banco (un cargo, o una devolución —un depósito—): {movimiento, fecha, monto (lo que salió: un cargo en positivo, una devolución en negativo), descripcion, clase_probable (lo que sugiere su descripción: neto, impuestos, reembolsos, deducciones, cuota o devolucion), opciones: [{clase, texto, partes: [{corrida, cuenta, monto}], corridas}], mejor (la única, si lo es), cuota (si parece la cuota mensual), texto en llano}. Una opción existe solo si suma el movimiento al centavo con lo que una corrida cercana —o dos— dejó por pagar; lo que una corrección dejó a favor entra restando (monto en negativo). Si ninguna, el texto lo dice con las cifras de cada corrida. Solo lee. Solo el dueño.';

-- Los cargos de Gusto: los pendientes en la Bandeja del banco (con su
-- propuesta en una línea), los casados desde aquí y la cuota. También una
-- DEVOLUCIÓN de Gusto (un depósito con su nombre: monto en negativo) y los
-- pagos casados «por fuera de Gusto». Un cargo casado desde aquí que después
-- se DES-CASÓ en la Bandeja del banco sale como «descasado» (su movimiento
-- vuelve a salir, además, entre los pendientes): se deshace aquí, o se casa
-- otra vez y se apunta solo.
create or replace function public.fn_nomina_cargos()
returns table (movimiento_id uuid, fecha date, monto numeric(14,2), descripcion text, cuenta text, estado text, clase_probable text,
               pago_id uuid, asiento_id uuid, asiento text, corridas text, texto text, opciones int)
language sql stable
set search_path = public, pg_temp
as $$
  with pat as materialized (select (select d.patron from public.banco_descriptores d where d.clave = 'nomina') as nomina),
       pend as (
         select m.id, m.fecha, (-m.monto)::numeric(14,2) as monto, m.descripcion, m.cuenta,
                public.fn_nomina_cargo_propuesta(m.id) as p
           from public.movimientos_banco m cross join pat
          where m.estado = 'pendiente' and m.monto <> 0
            and (   (m.monto < 0 and (m.estado_motivo = 'nomina'
                                      or (m.estado_motivo is null and pat.nomina is not null
                                          and coalesce(m.desc_norm, m.descripcion, '') ~* pat.nomina)))
                 or (m.monto > 0 and pat.nomina is not null and coalesce(m.desc_norm, m.descripcion, '') ~* pat.nomina)))
  select pend.id, pend.fecha, pend.monto, pend.descripcion, pend.cuenta, 'pendiente'::text, pend.p->>'clase_probable', null::uuid, null::uuid,
         null::text, null::text, pend.p->>'texto', jsonb_array_length(pend.p->'opciones')
    from pend
   where (select public.fn_nomina_ve())
  union all
  select g.movimiento_id, g.fecha, g.monto, m.descripcion, m.cuenta,
         case when not (m.asiento_id is not distinct from g.asiento_id and m.estado in ('casado', 'en_transito')) then 'descasado'
              when g.clase = 'cuota' then 'cuota' else 'casado' end, g.clase, g.id, g.asiento_id, a.numero,
         (select string_agg(distinct 'la del ' || public.fn_nomina_dia(c.dia_pago), ', ')
            from public.nomina_pago_partes pp join public.nomina_corridas c on c.id = pp.corrida_id where pp.pago_id = g.id),
         case when not (m.asiento_id is not distinct from g.asiento_id and m.estado in ('casado', 'en_transito'))
                then 'Se des-casó en la Bandeja del banco (su asiento ya está reversado): deshazlo aquí también, o cásalo otra vez desde '
                     'los que esperan y se apunta solo.'
              when g.clase = 'cuota' then 'La cuota mensual de Gusto: a su gasto, no es nómina.'
              else (select case when g.clase = 'fuera' then 'Pagado por fuera de Gusto: ' when g.monto < 0 then 'Devolución de Gusto: ' else 'Paga ' end
                           || string_agg(format('%s en %s', public.fn_nomina_usd(q.s), q.cuenta), ', ' order by q.cuenta)
                      from (select pp.cuenta, sum(pp.monto) as s from public.nomina_pago_partes pp where pp.pago_id = g.id group by pp.cuenta) q) end,
         0
    from public.nomina_pagos g
    join public.movimientos_banco m on m.id = g.movimiento_id
    left join public.asientos a on a.id = g.asiento_id
   where g.estado = 'aplicado' and (select public.fn_nomina_ve())
$$;
revoke execute on function public.fn_nomina_cargos() from public, anon, service_role;
grant  execute on function public.fn_nomina_cargos() to authenticated;
comment on function public.fn_nomina_cargos() is 'c15: los movimientos de Gusto en el banco: los PENDIENTES en la Bandeja (los cargos que el banco dejó esperando el journal de la nómina y las devoluciones de Gusto —un depósito con su nombre: monto en negativo—), con lo que sugiere su descripción, su propuesta en una línea y cuántas opciones tiene; y los ya resueltos desde la nómina (casado: con qué nóminas y qué cuentas pagó, también los pagados por fuera de Gusto; cuota: la mensual de Gusto; descasado: se casó aquí y después se des-casó en la Bandeja del banco: se deshace aquí), con su asiento. Solo lectura. A quien no es el dueño, nada.';

-- LO QUE PUEDE SER UN PAGO «POR FUERA DE GUSTO»: un cargo del banco que NO
-- es de Gusto y que da, al centavo, algo que una nómina posteada dejó por
-- pagar y que Gusto no cobra: el neto de UNA persona pagada con cheque de
-- papel (el cheque que cobró), o todo lo que queda de una cuenta de
-- deducciones (una cuota sindical, un seguro, un 401(k) que se le paga a un
-- tercero). Son CANDIDATOS: nada los cuenta como cargos de Gusto sin casar ni
-- detiene el cierre; la pantalla los enseña como sugerencia y Edgar los casa
-- —con su nota— por la misma puerta. Cualquier otro cargo del banco se puede
-- casar igual desde la nómina, diciendo sus partes y su nota.
create or replace function public.fn_nomina_cargos_fuera()
returns table (movimiento_id uuid, fecha date, monto numeric(14,2), descripcion text, corrida_id uuid, dia_pago date, clase text,
               partes jsonb, texto text)
language sql stable
set search_path = public, pg_temp
as $$
  with cfg as materialized (select c.cargo_dias_antes as antes from public.nomina_config c where c.id = 1),
       pat as materialized (select (select d.patron from public.banco_descriptores d where d.clave = 'nomina') as nomina),
       pend as (select p.corrida_id, p.dia_pago, p.cuenta, p.clase, p.pendiente from public.fn_nomina_pendiente() p where p.pendiente > 0),
       cand as (
         select pe.corrida_id, pe.dia_pago, pe.cuenta, 'cheque'::text as clase,
                (cp.neto + case when cp.neto_con_reembolso then 0 else cp.reembolsos end) as monto
           from pend pe
           join public.nomina_corrida_personas cp on cp.corrida_id = pe.corrida_id
          where pe.clase = 'neto' and coalesce(cp.metodo_pago, '') ~* 'check'
            and (cp.neto + case when cp.neto_con_reembolso then 0 else cp.reembolsos end) > 0
            and (cp.neto + case when cp.neto_con_reembolso then 0 else cp.reembolsos end) <= pe.pendiente
         union
         select pe.corrida_id, pe.dia_pago, pe.cuenta, 'deduccion', pe.pendiente from pend pe where pe.clase = 'deducciones')
  select m.id, m.fecha, (-m.monto)::numeric(14,2), m.descripcion, c.corrida_id, c.dia_pago, c.clase,
         jsonb_build_array(jsonb_build_object('corrida', c.corrida_id, 'cuenta', c.cuenta, 'monto', c.monto)),
         case c.clase
           when 'cheque' then format('Puede ser el cheque de papel de una persona de la nómina del %s: %s, lo que se le pagó con cheque, '
                                     'al centavo. Si lo es, cásalo como pagado por fuera de Gusto, con su nota.',
                                     public.fn_nomina_dia(c.dia_pago), public.fn_nomina_usd(c.monto))
           else format('Puede ser el pago de las deducciones de la nómina del %s (%s): %s, lo que queda por pagar de ellas, al centavo. '
                       'Si lo es, cásalo como pagado por fuera de Gusto, con su nota.',
                       public.fn_nomina_dia(c.dia_pago), c.cuenta, public.fn_nomina_usd(c.monto)) end
    from public.movimientos_banco m
    cross join cfg cross join pat
    join cand c on c.monto = -m.monto and m.fecha between c.dia_pago - cfg.antes and c.dia_pago + 92
   where m.estado = 'pendiente' and m.monto < 0
     and not (m.estado_motivo is not distinct from 'nomina'
              or (pat.nomina is not null and coalesce(m.desc_norm, m.descripcion, '') ~* pat.nomina))
     and (select public.fn_nomina_ve_personas())
   order by m.fecha, m.id, c.dia_pago
$$;
revoke execute on function public.fn_nomina_cargos_fuera() from public, anon, service_role;
grant  execute on function public.fn_nomina_cargos_fuera() to authenticated;
comment on function public.fn_nomina_cargos_fuera() is 'c15: los cargos del banco que NO son de Gusto, pendientes en la Bandeja, que dan al centavo algo que una nómina posteada dejó por pagar y que Gusto no cobra: el neto de una persona pagada con cheque de papel (clase cheque) o todo lo que queda de una cuenta de deducciones (clase deduccion), con las partes listas para casarlo y su texto en llano. Son candidatos: no cuentan como cargos de Gusto sin casar. Se casan por la misma puerta, con su nota (quedan «por fuera de Gusto»). Solo lectura; con el código del teléfono.';

-- CASAR un movimiento del banco con lo que paga. p_partes: [{"corrida": …,
-- "cuenta": "2210", "monto": "4810.68"}, …] (lo que da la propuesta, o lo
-- que Edgar diga). Suman el movimiento al centavo y ninguna paga de más.
--   · UN CARGO DE GUSTO: partes en positivo (lo que paga); puede llevar
--     partes en NEGATIVO contra lo que una corrección dejó a favor (el
--     descuento que Gusto se cobró): cada cuenta del cargo, sumada, tiene
--     que quedar pagando.
--   · UNA DEVOLUCIÓN DE GUSTO (un depósito): todas sus partes en negativo,
--     contra lo que quedó a favor.
--   · UN CARGO QUE NO ES DE GUSTO (el cheque de papel de alguien; una
--     deducción que se le paga a un tercero): igual, pero con su NOTA (qué
--     es): queda «por fuera de Gusto».
-- Si el movimiento se había casado aquí y después se des-casó en la Bandeja
-- del banco, el pago de antes se apunta deshecho aquí mismo y se casa de
-- nuevo.
create or replace function public.fn_nomina_cargo_casar(p_movimiento uuid, p_partes jsonb, p_nota text default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  m       movimientos_banco;
  v_pago  nomina_pagos;
  v_x     text;
  v_suma  numeric;
  r       record;
  v_lin   jsonb;
  v_mot   text;
  v_res   jsonb;
  v_as    uuid;
  v_id    uuid;
  v_gusto boolean;
  v_nota  text := nullif(btrim(p_nota), '');
  v_sig   int;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  if jsonb_typeof(p_partes) is distinct from 'array' or jsonb_array_length(p_partes) = 0 then
    raise exception using errcode = '22023',
      message = 'Di qué paga el cargo: una lista de partes [{"corrida": …, "cuenta": "2210", "monto": "…"}] (la que da su propuesta).';
  end if;
  if exists (select 1 from jsonb_array_elements(p_partes) q
              where jsonb_typeof(q) <> 'object' or (select count(*) from jsonb_object_keys(q) k where k not in ('corrida', 'cuenta', 'monto')) > 0
                 or coalesce(q->>'corrida', '') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                 or coalesce(q->>'cuenta', '') = '' or coalesce(q->>'monto', '') !~ '^-?[0-9]+(\.[0-9]{1,2})?$' or (q->>'monto')::numeric = 0) then
    raise exception using errcode = '22023',
      message = 'Cada parte dice su corrida, su cuenta y su monto (en dólares con centavos, distinto de cero; en negativo, lo que se '
                'descuenta de algo que quedó a favor).';
  end if;
  -- (un cargo a la vez: dos pestañas con el mismo se esperan, y la segunda ve lo que dejó la primera)
  perform pg_advisory_xact_lock(820261115, hashtext('nomina:pagos'));
  select * into m from movimientos_banco where id = p_movimiento;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese movimiento del banco.';
  end if;
  select * into v_pago from nomina_pagos g where g.movimiento_id = m.id and g.estado = 'aplicado';
  if v_pago.id is not null and m.asiento_id is not distinct from v_pago.asiento_id and m.estado in ('casado', 'en_transito') then
    return jsonb_build_object('pago', v_pago.id, 'movimiento', m.id, 'ya_estaba', true,
                              'asiento', (select a.numero from asientos a where a.id = v_pago.asiento_id));
  end if;
  if v_pago.id is not null then
    -- (se casó aquí y después se des-casó en la Bandeja del banco: su asiento ya está reversado; el pago de antes se apunta
    -- deshecho aquí mismo, y se sigue)
    perform set_config('mx_nomina.escribe', 'nomina_pagos', true);
    update nomina_pagos set estado = 'deshecho', deshecho_el = clock_timestamp(), deshecho_por = auth.uid(),
                            deshecho_motivo = 'Se des-casó en la Bandeja del banco; se apuntó aquí al volver a casarlo.',
                            reverso_id = (select r2.id from asientos r2 where r2.reversa_a = v_pago.asiento_id and r2.camino = 'reverso' limit 1)
     where id = v_pago.id;
    perform set_config('mx_nomina.escribe', '', true);
  end if;
  if m.estado <> 'pendiente' or m.monto = 0 then
    raise exception using errcode = 'MX008',
      message = case when m.monto = 0 then 'Ese movimiento no mueve dinero.'
                     else 'Ese movimiento ya está resuelto en la Bandeja del banco: si se resolvió mal, des-cásalo allí y vuelve aquí.' end;
  end if;
  v_sig := case when m.monto < 0 then 1 else -1 end;   -- (un cargo paga: +; una devolución baja lo que quedó a favor: −)
  v_gusto := m.estado_motivo is not distinct from 'nomina'
             or coalesce(coalesce(m.desc_norm, m.descripcion, '') ~* (select d.patron from banco_descriptores d where d.clave = 'nomina'), false);
  if not v_gusto and coalesce(length(v_nota), 0) < 3 then
    raise exception using errcode = '22023',
      message = case when m.monto > 0
                     then 'Ese depósito no es de Gusto (el banco no lo nombra): para casarlo con lo que una nómina dejó a favor, di en la '
                          'nota qué es.'
                     else 'Ese cargo no es de Gusto (el banco no lo nombra): para casarlo con lo que una nómina dejó por pagar —el cheque '
                          'de papel de alguien, una deducción que se le paga a un tercero—, di en la nota qué es.' end;
  end if;
  select sum((q->>'monto')::numeric) into v_suma from jsonb_array_elements(p_partes) q;
  if v_suma <> -m.monto then
    raise exception using errcode = 'MX001',
      message = format('Las partes suman %s y el %s es de %s: tienen que dar lo mismo, al centavo. No se casó nada.', fn_nomina_usd(v_suma),
                       case when m.monto < 0 then 'cargo' else 'depósito (en negativo: una devolución)' end, fn_nomina_usd(-m.monto));
  end if;
  for r in
    select (q.c)::uuid as corrida, q.cuenta, sum(q.monto) as monto, k.estado, k.dia_pago, p.pendiente
      from (select x->>'corrida' as c, x->>'cuenta' as cuenta, (x->>'monto')::numeric as monto from jsonb_array_elements(p_partes) x) q
      left join nomina_corridas k on k.id = (q.c)::uuid
      left join lateral (select pe.pendiente from fn_nomina_pendiente((q.c)::uuid) pe where pe.cuenta = q.cuenta) p on true
     group by q.c, q.cuenta, k.estado, k.dia_pago, p.pendiente
  loop
    if r.estado is distinct from 'posteada' then
      raise exception using errcode = 'MX008',
        message = 'Una de las partes nombra una corrida que no está posteada: un cargo se casa con lo que una nómina posteada dejó por pagar.';
    end if;
    if r.pendiente is null then
      raise exception using errcode = 'MX008',
        message = format('La nómina del %s no dejó nada por pagar en la cuenta %s: ese cargo no la paga.', fn_nomina_dia(r.dia_pago), r.cuenta);
    end if;
    if r.monto <> 0 and (sign(r.monto) <> sign(r.pendiente) or abs(r.monto) > abs(r.pendiente)) then
      raise exception using errcode = 'MX008',
        message = case when r.pendiente >= 0 and r.monto > 0
                         then format('La nómina del %s tiene %s por pagar en %s y esta parte le pagaría %s: de más. No se casó nada.',
                                     fn_nomina_dia(r.dia_pago), fn_nomina_usd(r.pendiente), r.cuenta, fn_nomina_usd(r.monto))
                       when r.pendiente < 0 and r.monto < 0
                         then format('La nómina del %s tiene %s a favor en %s y esta parte le descontaría %s: de más. No se casó nada.',
                                     fn_nomina_dia(r.dia_pago), fn_nomina_usd(-r.pendiente), r.cuenta, fn_nomina_usd(-r.monto))
                       when r.monto < 0
                         then format('La nómina del %s no tiene nada a favor en %s (tiene %s por pagar): una parte en negativo solo va '
                                     'contra lo que una corrección dejó a favor. No se casó nada.',
                                     fn_nomina_dia(r.dia_pago), r.cuenta, fn_nomina_usd(r.pendiente))
                       else format('La nómina del %s no tiene nada por pagar en %s (tiene %s a favor): eso se descuenta con una parte en '
                                   'negativo, o llega como una devolución. No se casó nada.',
                                   fn_nomina_dia(r.dia_pago), r.cuenta, fn_nomina_usd(-r.pendiente)) end;
    end if;
  end loop;
  -- (cada CUENTA del movimiento, sumadas sus partes, va en el sentido del movimiento: el banco pone una línea por cuenta)
  select string_agg(z.cuenta, ', ' order by z.cuenta) into v_x
    from (select x->>'cuenta' as cuenta, sum((x->>'monto')::numeric) as s from jsonb_array_elements(p_partes) x group by 1) z
   where z.s * v_sig <= 0;
  if v_x is not null then
    raise exception using errcode = 'MX008',
      message = format('En este movimiento la cuenta %s quedaría al revés (lo que se le descuenta es tanto o más que lo que se le paga): '
                       'el banco no lo puede poner así. Cásalo sin esa parte, y lo que quedó a favor en esa cuenta, con el movimiento '
                       'que de verdad lo descuente o lo devuelva. No se casó nada.', v_x);
  end if;
  select jsonb_agg(jsonb_build_object('cuenta', z.cuenta, 'monto', abs(z.monto)::text,
                                      'memo', left(format('%s: %s lo de %s', case when v_gusto then 'Gusto' else 'Nómina, por fuera de Gusto' end,
                                                          case when m.monto < 0 then 'paga' else 'devuelve' end, z.dias), 200)) order by z.cuenta),
         string_agg(z.cuenta, ', ' order by z.cuenta)
    into v_lin, v_x
    from (select q.cuenta, sum(q.monto) as monto,
                 string_agg(distinct 'la nómina del ' || fn_nomina_dia(k.dia_pago), ' y ') as dias
            from (select (x->>'corrida')::uuid as c, x->>'cuenta' as cuenta, (x->>'monto')::numeric as monto from jsonb_array_elements(p_partes) x) q
            join nomina_corridas k on k.id = q.c
           group by q.cuenta) z;
  v_mot := left(format('%s: este %s %s lo que %s dejó %s (%s)%s',
                       case when v_gusto then 'Nómina de Gusto' else 'Nómina, pagado por fuera de Gusto' end,
                       case when m.monto < 0 then 'cargo' else 'depósito' end, case when m.monto < 0 then 'paga' else 'devuelve' end,
                       (select string_agg(distinct 'la nómina del ' || fn_nomina_dia(k.dia_pago), ' y ')
                          from jsonb_array_elements(p_partes) x join nomina_corridas k on k.id = (x->>'corrida')::uuid),
                       case when m.monto < 0 then 'por pagar' else 'a favor' end, v_x, coalesce('. ' || v_nota, '')), 400);
  -- el asiento lo pone el banco (c6), por su puerta, y deja el movimiento casado con él
  v_res := fn_banco_clasificar(m.id, v_lin, v_mot);
  select mm.asiento_id into v_as from movimientos_banco mm where mm.id = m.id;
  if v_as is null then
    raise exception using errcode = 'MX001', message = 'El banco no dejó el asiento del cargo: no se casó nada.';
  end if;
  perform set_config('mx_nomina.escribe', 'nomina_pagos', true);
  insert into nomina_pagos (movimiento_id, clase, fecha, monto, asiento_id, nota, creado_por)
  values (m.id, case when v_gusto then 'nomina' else 'fuera' end, m.fecha, -m.monto, v_as, v_nota, auth.uid())
  returning id into v_id;
  perform set_config('mx_nomina.escribe', 'nomina_pago_partes', true);
  insert into nomina_pago_partes (pago_id, n, corrida_id, cuenta, monto)
  select v_id, row_number() over (order by z.c, z.cuenta)::int, z.c, z.cuenta, z.monto
    from (select (x->>'corrida')::uuid as c, x->>'cuenta' as cuenta, sum((x->>'monto')::numeric) as monto
            from jsonb_array_elements(p_partes) x group by 1, 2) z
   where z.monto <> 0;
  perform set_config('mx_nomina.escribe', '', true);
  return jsonb_build_object(
    'pago', v_id, 'movimiento', m.id, 'ya_estaba', false, 'clase', case when v_gusto then 'nomina' else 'fuera' end,
    'asiento', (select a.numero from asientos a where a.id = v_as),
    'fecha', (select a.fecha_contable from asientos a where a.id = v_as), 'monto', -m.monto,
    'queda_por_pagar', (select coalesce(jsonb_agg(jsonb_build_object('corrida', p.corrida_id, 'dia_pago', p.dia_pago, 'cuenta', p.cuenta,
                                                                     'pendiente', p.pendiente) order by p.dia_pago, p.cuenta), '[]'::jsonb)
                          from fn_nomina_pendiente() p
                         where p.pendiente <> 0 and p.corrida_id in (select (x->>'corrida')::uuid from jsonb_array_elements(p_partes) x)));
end $$;
revoke execute on function public.fn_nomina_cargo_casar(uuid, jsonb, text) from public, anon, service_role;
grant  execute on function public.fn_nomina_cargo_casar(uuid, jsonb, text) to authenticated;
comment on function public.fn_nomina_cargo_casar(uuid, jsonb, text) is 'c15: CASA un movimiento del banco con lo que paga: p_partes [{corrida, cuenta, monto}] (las de su propuesta, o las que diga Edgar). Suman el movimiento al centavo (MX001 con las dos cifras) y ninguna mueve más de lo que su corrida posteada tiene en esa cuenta (MX008 con las cifras). Un cargo de Gusto paga (partes en positivo) y puede descontar lo que una corrección dejó a favor (partes en negativo); una devolución de Gusto —un depósito— baja lo que quedó a favor (partes en negativo); un cargo que no es de Gusto (un cheque de papel, una deducción pagada a un tercero) se casa igual con su nota y queda «por fuera de Gusto». El asiento (en la fecha del movimiento) lo pone el banco por su puerta de clasificar, con su motivo, y deja el movimiento casado. Dos toques, un pago (ya_estaba); si se había des-casado en la Bandeja, el de antes se apunta deshecho. Devuelve {pago, clase, asiento, fecha, monto, queda_por_pagar}. Con el código del teléfono. Solo el dueño.';

-- LA CUOTA MENSUAL DE GUSTO: no es nómina. A su gasto, por la puerta del banco.
create or replace function public.fn_nomina_cargo_cuota(p_movimiento uuid, p_nota text default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  m      movimientos_banco;
  cfg    nomina_config;
  v_pago nomina_pagos;
  v_as   uuid;
  v_id   uuid;
  v_res  jsonb;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  perform pg_advisory_xact_lock(820261115, hashtext('nomina:pagos'));
  select * into m from movimientos_banco where id = p_movimiento;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese movimiento del banco.';
  end if;
  select * into v_pago from nomina_pagos g where g.movimiento_id = m.id and g.estado = 'aplicado';
  if v_pago.id is not null and m.asiento_id is not distinct from v_pago.asiento_id and m.estado in ('casado', 'en_transito') then
    return jsonb_build_object('pago', v_pago.id, 'movimiento', m.id, 'ya_estaba', true, 'clase', v_pago.clase);
  end if;
  if v_pago.id is not null then
    -- (se resolvió aquí y después se des-casó en la Bandeja del banco: el de antes se apunta deshecho, y se sigue)
    perform set_config('mx_nomina.escribe', 'nomina_pagos', true);
    update nomina_pagos set estado = 'deshecho', deshecho_el = clock_timestamp(), deshecho_por = auth.uid(),
                            deshecho_motivo = 'Se des-casó en la Bandeja del banco; se apuntó aquí al volver a resolverlo.',
                            reverso_id = (select r2.id from asientos r2 where r2.reversa_a = v_pago.asiento_id and r2.camino = 'reverso' limit 1)
     where id = v_pago.id;
    perform set_config('mx_nomina.escribe', '', true);
  end if;
  if m.estado <> 'pendiente' or m.monto >= 0 then
    raise exception using errcode = 'MX008', message = 'Ese movimiento no es un cargo pendiente del banco.';
  end if;
  select * into cfg from nomina_config where id = 1;
  if fn_nomina_cuenta_mal(cfg.cuenta_cuota, 'cuota') is not null then
    raise exception using errcode = 'MX004', message = format('La cuenta de la cuota de Gusto: %s.', fn_nomina_cuenta_mal(cfg.cuenta_cuota, 'cuota'));
  end if;
  v_res := fn_banco_clasificar(m.id, jsonb_build_array(jsonb_build_object('cuenta', cfg.cuenta_cuota)),
                               left('Cuota mensual de Gusto: un gasto de software, no es nómina'
                                    || coalesce('. ' || nullif(btrim(p_nota), ''), ''), 400));
  select mm.asiento_id into v_as from movimientos_banco mm where mm.id = m.id;
  perform set_config('mx_nomina.escribe', 'nomina_pagos', true);
  insert into nomina_pagos (movimiento_id, clase, fecha, monto, asiento_id, nota, creado_por)
  values (m.id, 'cuota', m.fecha, -m.monto, v_as, nullif(btrim(p_nota), ''), auth.uid())
  returning id into v_id;
  perform set_config('mx_nomina.escribe', '', true);
  return jsonb_build_object('pago', v_id, 'movimiento', m.id, 'ya_estaba', false, 'clase', 'cuota', 'cuenta', cfg.cuenta_cuota,
                            'asiento', (select a.numero from asientos a where a.id = v_as), 'monto', -m.monto);
end $$;
revoke execute on function public.fn_nomina_cargo_cuota(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_nomina_cargo_cuota(uuid, text) to authenticated;
comment on function public.fn_nomina_cargo_cuota(uuid, text) is 'c15: resuelve un cargo de Gusto que es su CUOTA MENSUAL (no es nómina): a su gasto (la cuenta de la configuración, 6500), por la puerta de clasificar del banco, con su motivo. El movimiento queda casado y la conciliación sigue. Con el código del teléfono. Solo el dueño.';

-- DESHACER un cargo casado desde aquí (se casó con la nómina que no era, o
-- hay que anular su corrida): el banco lo des-casa por su puerta (reversa su
-- asiento; el movimiento vuelve a la Bandeja) y el pago queda deshecho, con
-- su motivo. Si ya se había des-casado en la Bandeja, solo se apunta.
create or replace function public.fn_nomina_cargo_deshacer(p_pago uuid, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  g      nomina_pagos;
  m      movimientos_banco;
  v_rev  uuid;
  v_fuera boolean := false;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  if coalesce(length(btrim(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'Deshacer un cargo casado dice por qué (motivo).';
  end if;
  perform pg_advisory_xact_lock(820261115, hashtext('nomina:pagos'));
  select * into g from nomina_pagos where id = p_pago for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese cargo casado.';
  end if;
  if g.estado = 'deshecho' then
    return jsonb_build_object('pago', g.id, 'deshecho', true, 'ya_estaba', true);
  end if;
  select * into m from movimientos_banco where id = g.movimiento_id;
  if m.estado in ('casado', 'en_transito') and m.asiento_id = g.asiento_id then
    perform fn_banco_descasar(m.id, 'Nómina: ' || btrim(p_motivo));
  else
    v_fuera := true;
  end if;
  select r.id into v_rev from asientos r where r.reversa_a = g.asiento_id and r.camino = 'reverso' limit 1;
  perform set_config('mx_nomina.escribe', 'nomina_pagos', true);
  update nomina_pagos set estado = 'deshecho', deshecho_el = clock_timestamp(), deshecho_por = auth.uid(), deshecho_motivo = btrim(p_motivo),
                          reverso_id = v_rev
   where id = g.id;
  perform set_config('mx_nomina.escribe', '', true);
  return jsonb_build_object('pago', g.id, 'deshecho', true, 'ya_estaba', false, 'por_fuera', v_fuera,
                            'reverso', (select a.numero from asientos a where a.id = v_rev),
                            'nota', case when v_fuera then 'Ese cargo ya se había des-casado en la Bandeja del banco: aquí solo se apuntó.'
                                         else 'El cargo volvió a la Bandeja del banco: se puede casar otra vez.' end);
end $$;
revoke execute on function public.fn_nomina_cargo_deshacer(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_nomina_cargo_deshacer(uuid, text) to authenticated;
comment on function public.fn_nomina_cargo_deshacer(uuid, text) is 'c15: deshace un cargo de Gusto casado desde la nómina (o su cuota), con su motivo: el banco lo des-casa por su puerta (su asiento se reversa y el movimiento vuelve a la Bandeja) y el pago queda deshecho. Si ya se había des-casado en la Bandeja, solo se apunta (por_fuera). Dos toques, uno (ya_estaba). Con el código del teléfono. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 13. EL AMARRE CON LAS DECLARACIONES. Gusto presenta el 941 (cada
--     trimestre), el 940 (cada año) y el RT-6 de Florida (cada trimestre).
--     Edgar teclea sus totales y la base los compara con lo posteado POR DÍA
--     DE PAGO (las declaraciones cuentan por el día de pago, no por el
--     período trabajado):
--       941    salarios · retención federal · Social Security y Medicare
--              (las dos mitades: lo del empleado y lo del patrón)
--       940    salarios (todos los pagos) · FUTA
--       RT-6   salarios · contribución de reempleo
--     Una diferencia mayor que la tolerancia (centavos: el 941 redondea por
--     renglón) es un AVISO con las dos cifras. Los «salarios» del libro son
--     el bruto: si hay deducciones antes de impuestos (un 401k, un seguro),
--     el 941 trae menos, y la diferencia es esa; en el 940 y en el RT-6 van
--     los pagos brutos, y un 401(k) no los baja (la pista lo dice por forma;
--     ▶ CPA: la sección 125). Nada de aquí postea.
-- ---------------------------------------------------------------------
create or replace function public.fn_nomina_declaracion(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c_claves constant text[] := array['forma', 'anio', 'trimestre', 'salarios', 'retencion', 'ss_medicare', 'futa', 'contribucion',
                                    'presentada_el', 'confirmacion', 'nota', 'quitar'];
  v_x     text;
  v_forma text;
  v_anio  int;
  v_tri   int;
  v_k     text;
  v_n     numeric;
  v_val   jsonb := '{}'::jsonb;
  v_ant   nomina_declaraciones;
  v_d     nomina_declaraciones;
  v_pres  date;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'Una declaración llega como un objeto: {"forma": "941", "anio": 2027, "trimestre": 1, "salarios": "…", …}.';
  end if;
  select string_agg(k, ', ' order by k) into v_x from jsonb_object_keys(p) k where k <> all (c_claves);
  if v_x is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida: %s. Valen: %s.', v_x, array_to_string(c_claves, ', '));
  end if;
  v_forma := lower(replace(coalesce(p->>'forma', ''), '-', ''));
  if v_forma not in ('941', '940', 'rt6') then
    raise exception using errcode = '22023', message = 'La forma es 941, 940 o rt6 (el RT-6 de Florida).';
  end if;
  if coalesce(p->>'anio', '') !~ '^20[2-9][0-9]$' then
    raise exception using errcode = '22023', message = 'Falta el año de la declaración (por ejemplo, 2027).';
  end if;
  v_anio := (p->>'anio')::int;
  if v_forma = '940' then
    if p ? 'trimestre' and nullif(p->>'trimestre', '') is not null then
      raise exception using errcode = '22023', message = 'El 940 es del año entero: no lleva trimestre.';
    end if;
  else
    if coalesce(p->>'trimestre', '') !~ '^[1-4]$' then
      raise exception using errcode = '22023', message = 'Falta el trimestre (1 a 4).';
    end if;
    v_tri := (p->>'trimestre')::int;
  end if;
  select * into v_ant from nomina_declaraciones d
   where d.forma = v_forma and d.anio = v_anio and coalesce(d.trimestre, 0) = coalesce(v_tri, 0) and d.vigente
     for update;
  if coalesce((p->>'quitar')::boolean, false) then
    if v_ant.id is null then
      return jsonb_build_object('forma', v_forma, 'anio', v_anio, 'trimestre', v_tri, 'quitada', false);
    end if;
    perform set_config('mx_nomina.escribe', 'nomina_declaraciones', true);
    update nomina_declaraciones set vigente = false, sustituida_el = clock_timestamp() where id = v_ant.id;
    perform set_config('mx_nomina.escribe', '', true);
    perform fn_nomina_apunta('declaracion', v_ant.id::text, to_jsonb(v_ant), null);
    return jsonb_build_object('forma', v_forma, 'anio', v_anio, 'trimestre', v_tri, 'quitada', true);
  end if;
  foreach v_k in array array['salarios', 'retencion', 'ss_medicare', 'futa', 'contribucion'] loop
    continue when not p ? v_k or nullif(btrim(p->>v_k), '') is null;
    if (v_forma = '941' and v_k not in ('salarios', 'retencion', 'ss_medicare'))
       or (v_forma = '940' and v_k not in ('salarios', 'futa'))
       or (v_forma = 'rt6' and v_k not in ('salarios', 'contribucion')) then
      raise exception using errcode = '22023',
        message = format('%s no es un renglón de esa declaración. El 941 lleva salarios, retencion y ss_medicare; el 940, salarios y futa; '
                         'el RT-6, salarios y contribucion.', v_k);
    end if;
    v_n := fn_nomina_monto(p->>v_k);
    if v_n is null or v_n < 0 or v_n <> round(v_n, 2) or v_n >= 1000000000 then
      raise exception using errcode = 'MX005', message = format('%s es un monto en dólares con centavos (como lo dice la declaración).', v_k);
    end if;
    v_val := v_val || jsonb_build_object(v_k, v_n);
  end loop;
  if v_val = '{}'::jsonb then
    raise exception using errcode = '22023', message = 'Teclea al menos un total de la declaración (salarios, y lo que lleve esa forma).';
  end if;
  if p ? 'presentada_el' and nullif(btrim(p->>'presentada_el'), '') is not null then
    v_pres := fn_nomina_fecha(p->>'presentada_el');
    if v_pres is null then
      raise exception using errcode = '22023', message = 'presentada_el es una fecha (AAAA-MM-DD).';
    end if;
  end if;
  perform set_config('mx_nomina.escribe', 'nomina_declaraciones', true);
  if v_ant.id is not null then
    update nomina_declaraciones set vigente = false, sustituida_el = clock_timestamp() where id = v_ant.id;
  end if;
  insert into nomina_declaraciones (forma, anio, trimestre, salarios, retencion, ss_medicare, futa, contribucion, presentada_el,
                                    confirmacion, nota, registrada_por)
  values (v_forma, v_anio, v_tri, (v_val->>'salarios')::numeric, (v_val->>'retencion')::numeric, (v_val->>'ss_medicare')::numeric,
          (v_val->>'futa')::numeric, (v_val->>'contribucion')::numeric, v_pres, left(nullif(btrim(p->>'confirmacion'), ''), 100),
          left(nullif(btrim(p->>'nota'), ''), 500), auth.uid())
  returning * into v_d;
  perform set_config('mx_nomina.escribe', '', true);
  perform fn_nomina_apunta('declaracion', v_d.id::text, case when v_ant.id is not null then to_jsonb(v_ant) end, to_jsonb(v_d));
  return to_jsonb(v_d) || jsonb_build_object(
    'amarre', (select coalesce(jsonb_agg(to_jsonb(a) order by a.campo), '[]'::jsonb) from fn_nomina_amarre(v_anio) a
                where a.forma = v_forma and coalesce(a.trimestre, 0) = coalesce(v_tri, 0)));
end $$;
revoke execute on function public.fn_nomina_declaracion(jsonb) from public, anon, service_role;
grant  execute on function public.fn_nomina_declaracion(jsonb) to authenticated;
comment on function public.fn_nomina_declaracion(jsonb) is 'c15: teclea los totales de una declaración de nómina que presentó Gusto: {forma: 941 | 940 | rt6, anio, trimestre (no en el 940), salarios, retencion y ss_medicare (941), futa (940), contribucion (rt6), presentada_el?, confirmacion?, nota?}; {…, quitar: true} la retira. Teclearla otra vez deja la anterior como rastro. Devuelve la fila y su amarre contra lo posteado. No postea nada. Con el código del teléfono. Solo el dueño.';

create or replace function public.fn_nomina_amarre(p_anio int default null)
returns table (forma text, anio int, trimestre int, desde date, hasta date, campo text, declarado numeric(14,2), libro numeric(14,2),
               diferencia numeric(14,2), ok boolean, corridas int, detalle text)
language sql stable
set search_path = public, pg_temp
as $$
  with cfg as materialized (select c.amarre_tolerancia as t from public.nomina_config c where c.id = 1),
       k as (select extract(year from c.dia_pago)::int as anio, extract(quarter from c.dia_pago)::int as tri, c.bruto,
                    coalesce((c.declara->>'fit')::numeric, 0) as fit,
                    coalesce((c.declara->>'ss_ee')::numeric, 0) + coalesce((c.declara->>'med_ee')::numeric, 0)
                      + coalesce((c.declara->>'med_adic')::numeric, 0) + coalesce((c.declara->>'ss_er')::numeric, 0)
                      + coalesce((c.declara->>'med_er')::numeric, 0) as ssm,
                    coalesce((c.declara->>'futa')::numeric, 0) as futa, coalesce((c.declara->>'suta')::numeric, 0) as suta
               from public.nomina_corridas c
              where c.estado = 'posteada' and (select public.fn_nomina_ve())),
       libro as (
         select '941'::text as forma, k.anio, k.tri, x.campo, x.v, count(*) over (partition by k.anio, k.tri) as n0
           from k cross join lateral (values ('salarios', k.bruto), ('retencion', k.fit), ('ss_medicare', k.ssm)) x(campo, v)
         union all
         select 'rt6', k.anio, k.tri, x.campo, x.v, 0 from k cross join lateral (values ('salarios', k.bruto), ('contribucion', k.suta)) x(campo, v)
         union all
         select '940', k.anio, null::int, x.campo, x.v, 0 from k cross join lateral (values ('salarios', k.bruto), ('futa', k.futa)) x(campo, v)),
       lib as (select l.forma, l.anio, l.tri, l.campo, sum(l.v) as v, count(*)::int as n from libro l group by l.forma, l.anio, l.tri, l.campo),
       dec as (
         select d.forma, d.anio, d.trimestre as tri, x.campo, x.v
           from public.nomina_declaraciones d
           cross join lateral (values ('salarios', d.salarios), ('retencion', d.retencion), ('ss_medicare', d.ss_medicare), ('futa', d.futa),
                                      ('contribucion', d.contribucion)) x(campo, v)
          where d.vigente and (select public.fn_nomina_ve())
            and (   (d.forma = '941' and x.campo in ('salarios', 'retencion', 'ss_medicare'))
                 or (d.forma = '940' and x.campo in ('salarios', 'futa'))
                 or (d.forma = 'rt6' and x.campo in ('salarios', 'contribucion'))))
  select z.forma, z.anio, z.tri,
         make_date(z.anio, case when z.tri is null then 1 else z.tri * 3 - 2 end, 1),
         (make_date(z.anio, case when z.tri is null then 12 else z.tri * 3 end, 1) + interval '1 month')::date - 1,
         z.campo, z.declarado::numeric(14,2), z.libro::numeric(14,2), (z.declarado - z.libro)::numeric(14,2),
         case when z.declarado is null then null else abs(z.declarado - z.libro) <= cfg.t end, z.n,
         format('%s%s de %s, %s: ', case z.forma when '941' then 'El 941' when '940' then 'El 940' else 'El RT-6' end,
                coalesce(' del trimestre ' || z.tri, ''), z.anio,
                case z.campo when 'salarios' then 'salarios' when 'retencion' then 'retención federal'
                             when 'ss_medicare' then 'Social Security y Medicare' when 'futa' then 'FUTA' else 'contribución de reempleo' end)
         || case when z.declarado is null
                   then format('el libro tiene %s en %s nómina(s) con día de pago en ese período, y la declaración no está tecleada.',
                               public.fn_nomina_usd(z.libro), z.n)
                 when abs(z.declarado - z.libro) <= cfg.t
                   then format('amarra: la declaración dice %s y el libro %s.', public.fn_nomina_usd(z.declarado), public.fn_nomina_usd(z.libro))
                 else format('NO amarra: la declaración dice %s y el libro tiene %s en %s nómina(s) con día de pago en ese período '
                             '(diferencia %s).%s', public.fn_nomina_usd(z.declarado), public.fn_nomina_usd(z.libro), z.n,
                             public.fn_nomina_usd(z.declarado - z.libro),
                             -- (la pista, por forma: lo que baja los salarios no es lo mismo en el 941 que en el 940 o el RT-6)
                             case when z.campo = 'salarios' and z.declarado < z.libro and z.forma = '941'
                                    then ' Los salarios del libro son el bruto: si hay deducciones antes de impuestos (un 401(k), un '
                                         'seguro que se descuenta antes de impuestos), el 941 trae menos, y la diferencia es esa. Si no '
                                         'las hay, ¿sobra una nómina de ese período?'
                                  when z.campo = 'salarios' and z.declarado < z.libro
                                    then format(' Los salarios del libro son el bruto, y en %s van los pagos brutos: un 401(k) NO los baja '
                                                '(un seguro que se descuenta antes de impuestos, de la sección 125, puede: a confirmar '
                                                'con el CPA). Si no es eso, ¿sobra una nómina de ese período?',
                                                case z.forma when '940' then 'el 940' else 'el RT-6' end)
                                  else ' ¿Falta subir una nómina de ese período, o hay una de más?' end) end
    from (select coalesce(l.forma, d.forma) as forma, coalesce(l.anio, d.anio) as anio, coalesce(l.tri, d.tri) as tri,
                 coalesce(l.campo, d.campo) as campo, d.v as declarado, coalesce(l.v, 0) as libro, coalesce(l.n, 0) as n
            from lib l
            full join dec d on d.forma = l.forma and d.anio = l.anio and d.tri is not distinct from l.tri and d.campo = l.campo
           where d.v is not null or l.v is not null) z
    cross join cfg
   where p_anio is null or z.anio = p_anio
   order by z.anio, z.tri nulls last, z.forma, z.campo
$$;
revoke execute on function public.fn_nomina_amarre(int) from public, anon, service_role;
grant  execute on function public.fn_nomina_amarre(int) to authenticated;
comment on function public.fn_nomina_amarre(int) is 'c15: EL AMARRE de la nómina con sus declaraciones (de un año, o de todos): una fila por declaración, período y renglón (941: salarios, retencion, ss_medicare; 940: salarios, futa; rt6: salarios, contribucion) con lo declarado (lo que tecleó Edgar; vacío si falta), lo que el libro tiene en las corridas posteadas con DÍA DE PAGO en ese período, la diferencia, si amarra (ok: dentro de la tolerancia; vacío si la declaración no está tecleada), cuántas nóminas y el detalle en llano con las dos cifras. Solo lectura. A quien no es el dueño, nada.';


-- ---------------------------------------------------------------------
-- 14. LAS HORAS PARA GUSTO. El plan Simple de Gusto no trae reloj: las horas
--     se le teclean o se le suben. Aquí salen las APROBADAS de un período,
--     por persona y por SEMANA LABORAL (el día en que empieza, de la
--     configuración): total, regulares y extra. Las extra son de cada semana
--     por su cuenta: lo que pasa de 40 EN LA SEMANA (no se promedian las dos
--     del período). Si el período corta una semana por la mitad (la semana
--     laboral empieza otro día que el período de pago), las horas de esa
--     semana que cayeron ANTES del período ya gastaron su parte de las 40
--     (horas_antes: las aprobadas de esos días): las de dentro son regulares
--     hasta completar las 40 y extra lo demás. Los días de esa semana que
--     caen DESPUÉS del período se cuentan en el lote siguiente, igual. La
--     fila lo dice (semana_partida).
--     fn_nomina_lote guarda lo que se le pasó a Gusto (qué reportes de
--     horas, cuántas, y la tabla por persona y semana) y devuelve el CSV. Si
--     después cambia una hora del lote o se aprueba otra de ese período, el
--     control lo avisa.
--     EL CSV ES GENÉRICO (Employee name, Regular hours, Overtime hours,
--     Total hours, Pay period start, Pay period end: una fila por persona):
--     las columnas exactas de la plantilla «Import payroll data» de Gusto no
--     están comprobadas. ▶ Se confirma con la plantilla que Edgar baje.
-- ---------------------------------------------------------------------
-- ¿A esta persona Gusto le paga POR HORAS? Sí, salvo que esté en la nómina
-- como oficial o de oficina (sueldo fijo: a Gusto no se le pasan sus horas)
-- o que, sin estar todavía en la nómina, sea el dueño (que entrará como
-- oficial). Sus horas siguen saliendo en la tabla, marcadas; al CSV y al
-- lote no van.
create or replace function public.fn_nomina_por_horas(p_usuario uuid) returns boolean
language sql stable
set search_path = public, pg_temp
as $$
  select coalesce((select pe.clase = 'campo' from public.nomina_personas pe where pe.usuario_id = p_usuario and pe.clase is not null),
                  not exists (select 1 from public.perfiles pf where pf.id = p_usuario and pf.rol = 'dueno'))
$$;
revoke execute on function public.fn_nomina_por_horas(uuid) from public, anon, service_role;
grant  execute on function public.fn_nomina_por_horas(uuid) to authenticated;
comment on function public.fn_nomina_por_horas(uuid) is 'c15: verdadero si a esa persona Gusto le paga por horas (sus horas aprobadas van en el lote y en el CSV para Gusto): todos, salvo quien está en la nómina como oficial o de oficina (sueldo fijo) y, mientras no esté en la nómina, el dueño.';

create or replace function public.fn_nomina_horas_gusto(p_desde date, p_hasta date)
returns table (usuario_id uuid, persona text, empleado text, por_horas boolean, semana_desde date, semana_hasta date, horas numeric,
               horas_antes numeric, regulares numeric, extra numeric, reportes int, sin_aprobar numeric, semana_partida boolean)
language sql stable
set search_path = public, pg_temp
as $$
  with cfg as materialized (select c.semana_empieza as s, c.horas_extra_desde as x from public.nomina_config c where c.id = 1),
       h as (select h.usuario_id, h.horas, h.aprobado_el is not null as ap,
                    (h.fecha - ((extract(isodow from h.fecha)::int - cfg.s + 7) % 7))::date as semana
               from public.horas h cross join cfg
              where h.fecha between p_desde and p_hasta and h.horas > 0 and h.horas < 100000
                and p_desde is not null and p_hasta is not null and p_desde <= p_hasta and p_hasta - p_desde <= 92
                and (select public.fn_nomina_ve())),
       g as (select h.usuario_id, h.semana, coalesce(sum(h.horas) filter (where h.ap), 0) as horas,
                    (count(*) filter (where h.ap))::int as reportes, coalesce(sum(h.horas) filter (where not h.ap), 0) as sin_aprobar
               from h group by h.usuario_id, h.semana),
       -- (las horas aprobadas de esa misma semana laboral que cayeron ANTES del período: ya gastaron su parte de las 40)
       a as (select g.usuario_id, g.semana, g.horas, g.reportes, g.sin_aprobar,
                    case when g.semana < p_desde
                         then coalesce((select sum(q.horas) from public.horas q
                                         where q.usuario_id = g.usuario_id and q.fecha >= g.semana and q.fecha < p_desde
                                           and q.aprobado_el is not null and q.horas > 0 and q.horas < 100000), 0)
                         else 0 end as antes
               from g)
  select a.usuario_id, pf.nombre, pe.nombre, public.fn_nomina_por_horas(a.usuario_id), a.semana, a.semana + 6, a.horas, a.antes,
         least(a.horas, greatest(cfg.x - a.antes, 0)), a.horas - least(a.horas, greatest(cfg.x - a.antes, 0)),
         a.reportes, a.sin_aprobar, a.semana < p_desde or a.semana + 6 > p_hasta
    from a cross join cfg
    left join public.perfiles pf on pf.id = a.usuario_id
    left join public.nomina_personas pe on pe.usuario_id = a.usuario_id
   order by pf.nombre, a.usuario_id, a.semana
$$;
revoke execute on function public.fn_nomina_horas_gusto(date, date) from public, anon, service_role;
grant  execute on function public.fn_nomina_horas_gusto(date, date) to authenticated;
comment on function public.fn_nomina_horas_gusto(date, date) is 'c15: las horas APROBADAS de un período (hasta tres meses), por persona y por semana laboral (la que empieza el día de la configuración): la persona (su perfil) y cómo se llama en Gusto si está enlazada (empleado), si Gusto le paga por horas (por_horas: quien es de sueldo fijo —el oficial, la oficina— sale en la tabla pero no va al lote ni al CSV), la semana, sus horas dentro del período, las aprobadas de esa misma semana que cayeron antes del período (horas_antes: ya gastaron su parte de las 40), las regulares (hasta completar las horas_extra_desde de la configuración, 40, en la semana) y las extra (lo demás, semana por semana), cuántos reportes, las horas todavía sin aprobar de esa semana, y si el período corta esa semana (semana_partida). Solo lectura. A quien no es el dueño, nada.';

-- El CSV de un lote guardado: una fila por persona, con lo que suman sus semanas (como quedaron al armarlo).
create or replace function public.fn_nomina_lote_csv(p_lote uuid) returns text
language sql stable
set search_path = public, pg_temp
as $$
  with l as (select * from public.nomina_lotes where id = p_lote and (select public.fn_nomina_ve())),
       p as (select (s->>'usuario_id')::uuid as usuario_id, min(coalesce(s->>'empleado', s->>'persona', s->>'usuario_id')) as nombre,
                    sum((s->>'horas')::numeric) as horas, sum((s->>'regulares')::numeric) as regulares, sum((s->>'extra')::numeric) as extra
               from l cross join lateral jsonb_array_elements(l.semanas) s
              group by (s->>'usuario_id')::uuid)
  select 'Employee name,Regular hours,Overtime hours,Total hours,Pay period start,Pay period end' || E'\n'
         || coalesce(string_agg(format('%s,%s,%s,%s,%s,%s', '"' || replace(p.nombre, '"', '""') || '"',
                                       trim_scale(p.regulares), trim_scale(p.extra), trim_scale(p.horas),
                                       to_char(l.desde, 'MM/DD/YYYY'), to_char(l.hasta, 'MM/DD/YYYY')),
                                E'\n' order by p.nombre, p.usuario_id) || E'\n', '')
    from l
    left join p on true
   group by l.desde, l.hasta
$$;
revoke execute on function public.fn_nomina_lote_csv(uuid) from public, anon, service_role;
grant  execute on function public.fn_nomina_lote_csv(uuid) to authenticated;
comment on function public.fn_nomina_lote_csv(uuid) is 'c15: el CSV de un lote de horas guardado, para pasarlo a Gusto: una fila por persona (Employee name: como se llama en Gusto si está enlazada; si no, su nombre en la app) con sus horas regulares, extra y totales del período (Regular hours, Overtime hours, Total hours, Pay period start, Pay period end), como quedaron al armar el lote. Columnas genéricas: las de la plantilla de Gusto no están comprobadas. Solo lectura. A quien no es el dueño, nada.';

create or replace function public.fn_nomina_lote(p_desde date, p_hasta date, p_nota text default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg   nomina_config;
  v_id  uuid;
  v_tot record;
  v_h   text;
  v_av  jsonb := '[]'::jsonb;
  v_sem jsonb;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  if p_desde is null or p_hasta is null or p_desde > p_hasta or p_hasta - p_desde > 92 then
    raise exception using errcode = '22023', message = 'El lote de horas es de un período: desde y hasta (en orden, tres meses como mucho).';
  end if;
  select * into cfg from nomina_config where id = 1;
  perform pg_advisory_xact_lock(820261115, hashtext('nomina:lote'));
  select count(distinct g.usuario_id) filter (where g.horas > 0 and g.por_horas) as personas,
         coalesce(sum(g.horas) filter (where g.por_horas), 0) as horas, coalesce(sum(g.regulares) filter (where g.por_horas), 0) as regulares,
         coalesce(sum(g.extra) filter (where g.por_horas), 0) as extra, coalesce(sum(g.sin_aprobar) filter (where g.por_horas), 0) as sin_aprobar,
         coalesce(bool_or(g.semana_partida and g.horas > 0 and g.por_horas), false) as partida,
         coalesce(sum(g.horas_antes) filter (where g.horas > 0 and g.por_horas), 0) as antes,
         string_agg(distinct g.persona, ', ') filter (where g.horas > 0 and g.por_horas and g.empleado is null) as sin_enlazar,
         string_agg(distinct g.persona, ', ') filter (where g.horas > 0 and not g.por_horas) as fijos
    into v_tot
    from fn_nomina_horas_gusto(p_desde, p_hasta) g;
  if v_tot.horas = 0 then
    raise exception using errcode = 'MX008',
      message = format('No hay horas aprobadas de quien cobra por horas del %s al %s%s: no hay lote que armar. Apruébalas en la app y vuelve.', fn_nomina_dia(p_desde),
                       fn_nomina_dia(p_hasta), case when v_tot.sin_aprobar > 0 then format(' (hay %s h sin aprobar)', fn_nomina_h(v_tot.sin_aprobar)) else '' end);
  end if;
  select coalesce(jsonb_agg(to_jsonb(g) order by g.persona, g.usuario_id, g.semana_desde), '[]'::jsonb) into v_sem
    from fn_nomina_horas_gusto(p_desde, p_hasta) g where g.horas > 0 and g.por_horas;
  select md5(coalesce(string_agg(h.id || ':' || h.usuario_id || ':' || h.fecha || ':' || h.horas || ':' || coalesce(h.proyecto_id, ''), '|'
                                 order by h.id), ''))
    into v_h
    from horas h
   where h.fecha between p_desde and p_hasta and h.aprobado_el is not null and h.horas > 0 and h.horas < 100000
     and fn_nomina_por_horas(h.usuario_id);
  perform set_config('mx_nomina.escribe', 'nomina_lotes', true);
  update nomina_lotes set vigente = false, sustituido_el = clock_timestamp() where desde = p_desde and hasta = p_hasta and vigente;
  insert into nomina_lotes (desde, hasta, semana_empieza, horas_extra_desde, personas, horas, regulares, extra, semanas, huella, nota, creado_por)
  values (p_desde, p_hasta, cfg.semana_empieza, cfg.horas_extra_desde, v_tot.personas, v_tot.horas, v_tot.regulares, v_tot.extra, v_sem, v_h,
          left(nullif(btrim(p_nota), ''), 500), auth.uid())
  returning id into v_id;
  perform set_config('mx_nomina.escribe', 'nomina_lote_horas', true);
  insert into nomina_lote_horas (lote_id, horas_id, usuario_id, fecha, semana, proyecto_id, co, horas)
  select v_id, h.id, h.usuario_id, h.fecha, (h.fecha - ((extract(isodow from h.fecha)::int - cfg.semana_empieza + 7) % 7))::date,
         h.proyecto_id, nullif(btrim(h.co), ''), h.horas
    from horas h
   where h.fecha between p_desde and p_hasta and h.aprobado_el is not null and h.horas > 0 and h.horas < 100000
     and fn_nomina_por_horas(h.usuario_id);
  perform set_config('mx_nomina.escribe', '', true);
  if v_tot.fijos is not null then
    v_av := v_av || jsonb_build_object('codigo', 'sueldo_fijo', 'texto',
      format('%s tiene(n) horas aprobadas en el período y cobra(n) sueldo fijo: no van en el lote ni en el CSV (a Gusto no se le pasan).',
             v_tot.fijos));
  end if;
  if v_tot.sin_aprobar > 0 then
    v_av := v_av || jsonb_build_object('codigo', 'sin_aprobar', 'texto',
      format('Quedan %s h sin aprobar en el período: NO van en el lote. Si son de esta nómina, apruébalas y arma el lote otra vez.',
             fn_nomina_h(v_tot.sin_aprobar)));
  end if;
  if v_tot.partida then
    v_av := v_av || jsonb_build_object('codigo', 'semana_partida', 'texto',
      format('El período corta una semana laboral (la semana empieza en %s): las horas extra de esa semana se cuentan con la semana entera%s. '
             'Si el período de pago de Gusto empieza otro día, cambia el día en que empieza la semana en los ajustes.',
             (array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'])[cfg.semana_empieza],
             case when v_tot.antes > 0 then format(' (las %s h aprobadas de antes del período ya gastaron su parte de las %s)',
                                                   fn_nomina_h(v_tot.antes), fn_nomina_h(cfg.horas_extra_desde))
                  else '; los días de después del período irán en el lote siguiente' end));
  end if;
  if v_tot.sin_enlazar is not null then
    v_av := v_av || jsonb_build_object('codigo', 'sin_enlazar', 'texto',
      format('%s todavía no está(n) enlazado(s) con su nombre de Gusto: en el CSV sale(n) con su nombre de la app.', v_tot.sin_enlazar));
  end if;
  return jsonb_build_object(
    'lote', v_id, 'desde', p_desde, 'hasta', p_hasta, 'personas', v_tot.personas, 'horas', v_tot.horas, 'regulares', v_tot.regulares,
    'extra', v_tot.extra, 'avisos', v_av, 'csv', fn_nomina_lote_csv(v_id), 'semanas', v_sem);
end $$;
revoke execute on function public.fn_nomina_lote(date, date, text) from public, anon, service_role;
grant  execute on function public.fn_nomina_lote(date, date, text) to authenticated;
comment on function public.fn_nomina_lote(date, date, text) is 'c15: ARMA Y GUARDA el lote de horas aprobadas de un período para pasarlo a Gusto: qué reportes de horas y cuántas (como están hoy), la tabla por persona y semana laboral (regulares y extra), con el día en que empieza la semana y desde cuántas horas son extra. Devuelve {lote, personas, horas, regulares, extra, semanas (por persona y semana), csv, avisos (horas sin aprobar que no van, una semana cortada por el período, alguien sin enlazar, alguien de sueldo fijo cuyas horas no van)}. Armar otra vez el mismo período deja el anterior como rastro. Sin horas aprobadas, MX008. Con el código del teléfono. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 15. PARA LAS OTRAS CAPAS (solo lectura; c3, c10 y c13 están sellados y
--     hoy no las llaman: quedan listas para cuando se abran).
--     · fn_nomina_horas_pagadas(): cada reporte de horas que una corrida
--       viva PAGÓ, con lo que le tocó. Es lo que c10 necesita para no
--       contar esas horas, además, a estándar; y lo que c3 necesita para
--       devengar solo lo trabajado y no pagado.
--     · fn_nomina_cola(mes): las horas aprobadas de un mes, de la gente de
--       campo de la nómina, que ninguna corrida ha pagado todavía (lo
--       trabajado al final del mes que se paga el mes siguiente), con su
--       costo estándar si lo hay. c3 no devenga un mes que tiene journal de
--       nómina: esto es lo que se queda fuera de ese mes.
--     · fn_nomina_auxiliar(fecha): el auxiliar de las cuentas por pagar de
--       la nómina a una fecha: qué corrida dejó qué por pagar y qué cargos
--       lo pagaron. Para la cédula de corte (c13).
-- ---------------------------------------------------------------------
create or replace function public.fn_nomina_horas_pagadas()
returns table (horas_id bigint, corrida_id uuid, dia_pago date, fecha_asiento date, usuario_id uuid, horas numeric, bruto numeric(14,2),
               patron numeric(14,2))
language sql stable
set search_path = public, pg_temp
as $$
  select rh.horas_id, rh.corrida_id, c.dia_pago, c.fecha_asiento, rh.usuario_id, rh.horas, rh.bruto, rh.patron
    from public.nomina_reparto_horas rh
    join public.nomina_corridas c on c.id = rh.corrida_id
   where rh.titular and rh.vivo and c.estado = 'posteada' and (select public.fn_nomina_ve_personas())
$$;
revoke execute on function public.fn_nomina_horas_pagadas() from public, anon, service_role;
grant  execute on function public.fn_nomina_horas_pagadas() to authenticated;
comment on function public.fn_nomina_horas_pagadas() is 'c15: los reportes de horas (horas.id) que una corrida de nómina viva PAGÓ (su lote), con su día de pago, la fecha de su asiento, la persona, las horas y lo que le tocó del bruto y de lo patronal. Es «el pagado hasta» que c3 esperaba de la nómina y lo que el costo por obra (c10) necesita para no llevar esas horas, además, a estándar. Solo lectura; lo de cada persona, con el código del teléfono.';

create or replace function public.fn_nomina_cola(p_mes text)
returns table (usuario_id uuid, persona text, proyecto_id text, obra text, horas numeric, estandar numeric(14,2), desde date, hasta date)
language sql stable
set search_path = public, pg_temp
as $$
  select h.usuario_id, pf.nombre, h.proyecto_id, pr.nombre, sum(h.horas),
         round(sum(h.horas * ce.costo_hora), 2)::numeric(14,2), min(h.fecha), max(h.fecha)
    from public.periodos p
    join public.horas h on h.fecha between p.desde and p.hasta
    left join public.perfiles pf on pf.id = h.usuario_id
    left join public.proyectos pr on pr.id = h.proyecto_id
    left join public.costos_equipo ce on ce.usuario_id = h.usuario_id
   where p.periodo = p_mes and p.tipo = 'mes' and h.aprobado_el is not null and h.horas > 0 and h.horas < 100000
     and public.fn_nomina_por_horas(h.usuario_id)
     and not exists (select 1 from public.nomina_reparto_horas rh where rh.horas_id = h.id and rh.titular and rh.vivo)
     and not exists (select 1 from public.jornal_reparto_horas jh join public.jornal_repartos jr on jr.id = jh.reparto_id
                      where jh.horas_id = h.id and jr.estado = 'aplicado')
     and (select public.fn_nomina_ve_personas())
   group by h.usuario_id, pf.nombre, h.proyecto_id, pr.nombre
$$;
revoke execute on function public.fn_nomina_cola(text) from public, anon, service_role;
grant  execute on function public.fn_nomina_cola(text) to authenticated;
comment on function public.fn_nomina_cola(text) is 'c15: LA COLA de un mes: las horas aprobadas de ese mes, de quien cobra por horas, que ninguna corrida viva (ni un pago por Zelle) ha pagado todavía, por persona y obra, con su costo estándar (horas × la tarifa de costos_equipo; vacío sin tarifa) y sus fechas. Es lo trabajado y todavía no pagado que el journal llevará al mes siguiente: lo que el devengo estándar de c3 devengaría si supiera el corte. Solo lectura; con el código del teléfono.';

-- EL «PAGADO HASTA» de cada persona: el último día del período de pago de la
-- última nómina REGULAR viva (la que se queda con las horas) que la pagó. Es
-- el corte que c3 esperaba de la nómina para su devengo («solo lo trabajado
-- y todavía no pagado»). Las nóminas fuera de ciclo (un bono, una
-- corrección) no pagan «hasta» nada: no cuentan.
create or replace function public.fn_nomina_pagado_hasta()
returns table (usuario_id uuid, persona text, pagado_hasta date, corrida_id uuid, dia_pago date)
language sql stable
set search_path = public, pg_temp
as $$
  select distinct on (pe.usuario_id) pe.usuario_id, pe.nombre, c.periodo_hasta, c.id, c.dia_pago
    from public.nomina_corridas c
    join public.nomina_corrida_personas cp on cp.corrida_id = c.id
    join public.nomina_personas pe on pe.id = cp.persona_id and pe.usuario_id is not null
   where c.estado = 'posteada' and c.toma_horas and c.periodo_hasta is not null and (select public.fn_nomina_ve_personas())
   order by pe.usuario_id, c.periodo_hasta desc, c.dia_pago desc, c.id
$$;
revoke execute on function public.fn_nomina_pagado_hasta() from public, anon, service_role;
grant  execute on function public.fn_nomina_pagado_hasta() to authenticated;
comment on function public.fn_nomina_pagado_hasta() is 'c15: el «pagado hasta» de cada persona de la nómina (por su perfil): el último día del período de pago de la última nómina regular viva que la pagó, con esa corrida y su día de pago. Las nóminas fuera de ciclo no cuentan. Es el corte que el devengo estándar de c3 esperaba de la nómina. Solo lectura; con el código del teléfono.';

create or replace function public.fn_nomina_auxiliar(p_fecha date default null)
returns table (cuenta text, clase text, corrida_id uuid, dia_pago date, descripcion text, acreditado numeric(14,2), pagado numeric(14,2),
               saldo numeric(14,2), asiento text, cargos text)
language sql stable
set search_path = public, pg_temp
as $$
  with f as materialized (select coalesce(p_fecha, public.fn_nomina_hoy()) as d),
       cr as (
         -- lo que cada corrida dejó por pagar, si su asiento está en el libro ese día (y su reverso, si se anuló, todavía no)
         select c.id, e.key as cuenta, (e.value)::numeric as monto
           from public.nomina_corridas c
           cross join f
           cross join lateral jsonb_each_text(c.pasivos) e
           left join public.asientos r on r.id = c.reverso_id
          where c.asiento_id is not null and c.fecha_asiento <= f.d and (c.estado = 'posteada' or r.fecha_contable > f.d)),
       pg as (
         -- lo que cada cargo casado le pagó, si su asiento está en el libro ese día (y su reverso, si se deshizo, todavía no)
         -- (el reverso se busca en el LIBRO: un cargo des-casado en la Bandeja del banco ya está reversado aunque aquí nadie lo
         -- haya deshecho todavía)
         select pp.corrida_id as id, pp.cuenta, sum(pp.monto) as monto,
                string_agg(format('%s del %s por %s', a.numero, public.fn_nomina_dia(a.fecha_contable), public.fn_nomina_usd(pp.monto)), '; '
                           order by a.fecha_contable, a.numero) as cargos
           from public.nomina_pago_partes pp
           join public.nomina_pagos g on g.id = pp.pago_id
           join public.asientos a on a.id = g.asiento_id
           cross join f
           left join lateral (select min(r.fecha_contable) as fecha from public.asientos r
                               where r.reversa_a = g.asiento_id and r.camino = 'reverso') rv on true
          where a.fecha_contable <= f.d and (rv.fecha is null or rv.fecha > f.d)
          group by pp.corrida_id, pp.cuenta)
  select z.cuenta, coalesce(c.plan->'clases'->>z.cuenta, 'deducciones'), c.id, c.dia_pago,
         format('Nómina del %s%s', public.fn_nomina_dia(c.dia_pago),
                coalesce(format(' (del %s al %s)', public.fn_nomina_dia(c.periodo_desde), public.fn_nomina_dia(c.periodo_hasta)), '')),
         z.acreditado::numeric(14,2), z.pagado::numeric(14,2), (z.acreditado - z.pagado)::numeric(14,2), c.asiento_numero, z.cargos
    from (select coalesce(cr.id, pg.id) as id, coalesce(cr.cuenta, pg.cuenta) as cuenta, coalesce(cr.monto, 0) as acreditado,
                 coalesce(pg.monto, 0) as pagado, pg.cargos
            from cr full join pg on pg.id = cr.id and pg.cuenta = cr.cuenta) z
    join public.nomina_corridas c on c.id = z.id
   where z.acreditado - z.pagado <> 0 and (select public.fn_nomina_ve())
   order by z.cuenta, c.dia_pago, c.id
$$;
revoke execute on function public.fn_nomina_auxiliar(date) from public, anon, service_role;
grant  execute on function public.fn_nomina_auxiliar(date) to authenticated;
comment on function public.fn_nomina_auxiliar(date) is 'c15: EL AUXILIAR de las cuentas por pagar de la nómina (2210, 2220, 2225, 2230, 2240 y las que diga el mapeo) a una fecha (sin fecha, hoy): una fila por cuenta y corrida con saldo ese día: lo que su journal dejó por pagar (acreditado; en negativo si una corrección lo dejó a favor), lo que sus cargos casados ya movieron hasta ese día (pagado; cargos dice cuáles) y el saldo (positivo: se debe; negativo: Gusto ya cobró una nómina cuyo día de pago todavía no llega, o hay algo a favor). La suma por cuenta es lo que la nómina explica de su saldo en el libro. Para la cédula de corte (c13). Solo lectura. A quien no es el dueño, nada.';


-- ---------------------------------------------------------------------
-- 15b. LO QUE QUEDA EN LA BOLSA DEL BURDEN REAL Y NO ES DE UNA NÓMINA.
--     Cada corrida mete en la bolsa (5015) lo que el patrón paga por su
--     gente de obra y lo saca, en su segundo asiento, a sus obras: lo suyo
--     queda en cero. Pero a la bolsa entra también, por el banco (c6), la
--     PRIMA DE WC que se amortiza cada mes desde 1410, y su ajuste de
--     auditoría (c1: «5015 … prima de WC amortizada desde 1410 y su ajuste
--     de auditoría. Sale a las obras por reparto»; «5010 solo recibe lo que
--     se REPARTE a las obras: el real, Dr 5010-obra / Cr 5015, por horas»).
--     Eso no es de ninguna corrida: si nadie lo reparte se queda en la
--     bolsa, y ni el costo por obra (c10) ni el WIP (c12) llevan la WC.
--     · fn_nomina_bolsa(mes) dice cuánto hay en la bolsa al terminar ese
--       mes, de dónde vino y cómo se repartiría: a las obras, por las horas
--       que las nóminas con asiento en ese mes pagaron en cada obra y CO (la
--       clave de siempre), al centavo, por mayores restos.
--     · fn_nomina_bolsa_repartir(mes, visto) lo postea en el último día del
--       mes: Dr el burden por obra / Cr la bolsa, por la puerta del dueño (un
--       asiento a mano con solo cuentas del bloque 50xx, lo que c3 admite).
--       Lo que Edgar vio es lo que entra (MX011). Se deshace reversándolo en
--       el Libro, como cualquier asiento a mano.
--     Un mes sin horas pagadas por la nómina no tiene con qué repartir: su
--     saldo se arrastra y sale con el mes siguiente. Un mes ya cerrado
--     tampoco se toca: lo mismo.
--     ▶ CPA: la clave (las horas pagadas del mes; la prima de WC se calcula
--     sobre los sueldos) y si se reparte cada mes. Si prefiere no repartir,
--     la bolsa se cierra a la variación de burden (5019) al cierre del año
--     con un asiento suyo; hasta entonces el aviso 75 lo dice.
-- ---------------------------------------------------------------------
create or replace function public.fn_nomina_bolsa(p_mes text default null) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg     nomina_config;
  per     periodos;
  v_hoy   date := fn_nomina_hoy();
  v_saldo numeric;
  v_part  jsonb;
  v_clave jsonb;
  v_h     numeric;
  v_lin   jsonb;
  v_puede boolean;
  v_txt   text;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  select * into cfg from nomina_config where id = 1;
  select p.* into per from periodos p
   where p.tipo = 'mes'
     and p.periodo = coalesce(nullif(btrim(p_mes), ''), (select max(q.periodo) from periodos q where q.tipo = 'mes' and q.hasta < v_hoy));
  if not found then
    raise exception using errcode = '22023', message = 'Di de qué mes (AAAA-MM): no existe ese mes en el libro.';
  end if;
  -- lo que hay en la bolsa al terminar el mes
  select coalesce(sum(l.monto), 0) into v_saldo
    from asiento_lineas l join asientos a on a.id = l.asiento_id
   where l.cuenta = cfg.cuenta_bolsa and a.fecha_contable <= per.hasta;
  -- de dónde vino (lo que entró a la bolsa hasta ese día y no es de una corrida: lo último primero)
  select coalesce(jsonb_agg(jsonb_build_object('asiento', x.numero, 'fecha', x.fecha, 'monto', x.monto, 'que', x.que)
                            order by x.fecha desc, x.numero desc), '[]'::jsonb)
    into v_part
    from (select a.numero, a.fecha_contable as fecha, sum(l.monto) as monto, left(a.descripcion, 160) as que
            from asiento_lineas l join asientos a on a.id = l.asiento_id
           where l.cuenta = cfg.cuenta_bolsa and a.fecha_contable <= per.hasta
             and not exists (select 1 from nomina_corridas k
                              where a.id in (k.asiento_id, k.burden_asiento_id, k.reverso_id, k.burden_reverso_id))
           group by a.id, a.numero, a.fecha_contable, a.descripcion
          having sum(l.monto) <> 0
           order by a.fecha_contable desc, a.numero desc limit 24) x;
  -- la clave: las horas que las nóminas con asiento en el mes pagaron en cada obra y CO; y su parte, al centavo
  with h as (select rh.proyecto_id, rh.co, sum(rh.horas) as horas
               from nomina_reparto_horas rh
               join nomina_corridas k on k.id = rh.corrida_id
              where k.estado = 'posteada' and rh.vivo and rh.titular and rh.proyecto_id is not null
                and k.fecha_asiento between per.desde and per.hasta
              group by rh.proyecto_id, rh.co),
       t as (select coalesce(sum(h.horas), 0) as total from h),
       b as (select h.proyecto_id, h.co, h.horas, trunc(abs(v_saldo) * h.horas / t.total, 2) as base,
                    abs(v_saldo) * h.horas / t.total - trunc(abs(v_saldo) * h.horas / t.total, 2) as resto
               from h cross join t where t.total > 0),
       r as (select b.*, row_number() over (order by b.resto desc, b.horas desc, b.proyecto_id, b.co nulls first) as n,
                    round((abs(v_saldo) - sum(b.base) over ()) * 100) as centavos
               from b)
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                    'proyecto_id', r.proyecto_id, 'obra', (select pr.nombre from proyectos pr where pr.id = r.proyecto_id), 'co', r.co,
                    'horas', r.horas, 'monto', sign(v_saldo) * (r.base + case when r.n <= r.centavos then 0.01 else 0 end)))
                            order by r.proyecto_id, r.co nulls first), '[]'::jsonb),
         coalesce(sum(r.horas), 0)
    into v_clave, v_h
    from r;
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                    'cuenta', cfg.cuenta_burden_obra, 'monto', (q->>'monto'), 'proyecto_id', q->>'proyecto_id', 'co', q->>'co',
                    'memo', format('Burden real de %s que no es de una nómina (la prima de WC), por las horas pagadas del mes', per.periodo)))
                            order by q->>'proyecto_id', q->>'co' nulls first), '[]'::jsonb)
         || jsonb_build_object('cuenta', cfg.cuenta_bolsa, 'monto', (-v_saldo)::text,
                               'memo', format('Lo que quedó en la bolsa del burden real al terminar %s, repartido a sus obras', per.periodo))
    into v_lin
    from jsonb_array_elements(v_clave) q where (q->>'monto')::numeric <> 0;
  v_puede := v_saldo <> 0 and v_h > 0 and per.hasta < v_hoy and per.estado = 'abierto';
  v_txt := case when v_saldo = 0 then format('Al terminar %s la bolsa del burden real (%s) no tiene nada sin repartir.', per.periodo, cfg.cuenta_bolsa)
                when per.hasta >= v_hoy
                  then format('%s todavía no termina: lo que quede en la bolsa del burden real (hoy, %s) se reparte al terminar el mes.',
                              per.periodo, fn_nomina_usd(v_saldo))
                when per.estado <> 'abierto'
                  then format('%s ya está cerrado: lo que quedó en su bolsa del burden real (%s) no se reparte en un mes cerrado; se '
                              'arrastra y sale con el mes siguiente.', per.periodo, fn_nomina_usd(v_saldo))
                when v_h = 0
                  then format('En %s ninguna nómina pagó horas en obra: no hay con qué repartir lo que quedó en la bolsa del burden real '
                              '(%s). Se arrastra y sale con el mes siguiente.', per.periodo, fn_nomina_usd(v_saldo))
                else format('Al terminar %s quedan %s en la bolsa del burden real (%s) que no son de ninguna nómina (la prima de WC que '
                            'se amortiza cada mes, su ajuste de auditoría). Se reparten a %s obra(s), por las %s h que la nómina pagó ese '
                            'mes en cada una, y así el costo por obra lleva su parte.', per.periodo, fn_nomina_usd(v_saldo),
                            cfg.cuenta_bolsa, jsonb_array_length(v_clave), fn_nomina_h(v_h)) end;
  return jsonb_build_object(
    'mes', per.periodo, 'hasta', per.hasta, 'saldo', v_saldo, 'de_donde', v_part, 'horas', v_h, 'clave', v_clave,
    'lineas', case when v_puede then v_lin else '[]'::jsonb end, 'puede', v_puede, 'texto', v_txt,
    'visto', case when v_puede then md5(jsonb_build_object('mes', per.periodo, 'lineas', v_lin)::text) end);
end $$;
revoke execute on function public.fn_nomina_bolsa(text) from public, anon, service_role;
grant  execute on function public.fn_nomina_bolsa(text) to authenticated;
comment on function public.fn_nomina_bolsa(text) is 'c15: lo que queda en la bolsa del burden real al terminar un mes (sin mes, el último terminado) y no es de una nómina —la prima de WC amortizada, su ajuste de auditoría—: {mes, hasta, saldo, de_donde (los asientos que lo metieron), horas y clave (las horas que las nóminas con asiento en ese mes pagaron en cada obra y CO, con la parte que le toca a cada una, al centavo), lineas (el asiento que lo repartiría: el burden por obra contra la bolsa), puede (hay saldo, hay horas, el mes terminó y sigue abierto), texto en llano y visto (lo que hay que devolver al repartir)}. No escribe nada. Con el código del teléfono. Solo el dueño.';

create or replace function public.fn_nomina_bolsa_repartir(p_mes text, p_visto text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v     jsonb;
  v_res jsonb;
begin
  perform fn_nomina_exigir_dueno();
  perform fn_nomina_exigir_codigo();
  perform pg_advisory_xact_lock(820261115, hashtext('nomina:bolsa'));
  v := fn_nomina_bolsa(p_mes);
  if not (v->>'puede')::boolean then
    raise exception using errcode = 'MX008', message = v->>'texto';
  end if;
  if p_visto is null or p_visto is distinct from v->>'visto' then
    raise exception using errcode = 'MX011',
      message = 'Lo que se va a repartir ya no es lo que viste: cambió lo que hay en la bolsa del burden o las horas pagadas del mes. No '
                'se posteó nada: vuelve a mirarlo.';
  end if;
  -- (por la puerta del dueño: un asiento a mano con solo cuentas del bloque 50xx —el burden por obra contra su bolsa—)
  v_res := fn_postear(jsonb_build_object(
             'fecha', v->>'hasta',
             'descripcion', left(format('Reparto a las obras de lo que quedó en la bolsa del burden real al terminar %s (la prima de WC '
                                        'amortizada y lo que entró por fuera de la nómina), por las horas que la nómina pagó ese mes',
                                        v->>'mes'), 500),
             'lineas', v->'lineas',
             'motivo', 'El burden real se reparte a las obras por las horas pagadas: lo de cada nómina sale solo con ella; esto es lo '
                       'demás que entró a la bolsa (la prima de WC amortizada desde los seguros pagados por adelantado).'));
  return jsonb_build_object('mes', v->>'mes', 'asiento', v_res->>'numero', 'fecha', v_res->>'fecha_contable', 'monto', v->'saldo',
                            'obras', jsonb_array_length(v->'clave'),
                            'nota', 'Si hay que deshacerlo, se reversa ese asiento en el Libro.');
end $$;
revoke execute on function public.fn_nomina_bolsa_repartir(text, text) from public, anon, service_role;
grant  execute on function public.fn_nomina_bolsa_repartir(text, text) to authenticated;
comment on function public.fn_nomina_bolsa_repartir(text, text) is 'c15: REPARTE a las obras lo que quedó en la bolsa del burden real al terminar un mes y no es de una nómina (la prima de WC amortizada): postea, en el último día del mes y por la puerta del dueño, el burden por obra contra la bolsa, por las horas que la nómina pagó ese mes en cada obra. Lo visto es lo que entra (p_visto; si no, MX011). Sin saldo, sin horas pagadas, con el mes sin terminar o ya cerrado, MX008 con su porqué. Devuelve {mes, asiento, fecha, monto, obras}. Se deshace reversando su asiento en el Libro. Con el código del teléfono. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 16. EL CONTROL: v_nomina_control (orden, control, nivel, ok, detalle).
--     nivel «cuadre» = si está en rojo, algo del libro o del reparto no es
--     lo que debe (detiene el cierre); «aviso» = hay algo que mirar.
--       10 cuadre  cada corrida posteada es su asiento (vivo, con sus
--                  cifras), y cada asiento de la nómina es de su corrida
--       15 cuadre  cada corrida posteada cuadra con su journal
--       20 cuadre  el reparto de cada corrida suma su bruto y lo patronal,
--                  y su lote es el de sus horas
--       25 cuadre  cada cargo casado sigue casado con su asiento, sus partes
--                  suman el cargo y ninguna corrida está pagada de más
--       30 aviso   corridas importadas sin postear
--       32 aviso   nóminas que parecen la misma, dos veces
--       35 aviso   cargos de Gusto en el banco sin casar
--       40 aviso   personas sin enlazar o sin confirmar
--       45 aviso   horas de Gusto distintas de las aprobadas
--       50 aviso   horas aprobadas de un período ya pagado que no entraron
--                  en ninguna nómina
--       55 aviso   horas de un lote ya repartido que cambiaron después
--       60 aviso   lo que quedó por pagar de una nómina y no baja
--       62 aviso   en las cuentas por pagar de la nómina, lo que el libro
--                  tiene y la nómina no explica (se mira desde unos días
--                  antes de la primera nómina: Gusto cobra antes del día de
--                  pago; un asiento reversado y su reverso no cuentan)
--       65 aviso   el 941, el 940 o el RT-6 que no amarra, o que falta
--       70 aviso   un lote de horas pasado a Gusto que ya no es el de hoy
--       75 aviso   la bolsa del burden real con saldo sin repartir
--       80 aviso   la cola: lo trabajado en el mes y todavía no pagado
--       85 aviso   lo que falta de configurar
--       90 cuadre  las protecciones de la capa
--     Lo que mira el dinero de una nómina (todo menos 40, 70, 75, 85 y 90)
--     pide el código del teléfono: por la API sin él, y habiendo entrado
--     algún archivo, lo dice y no se da por bueno. Cada fila trae además su
--     texto «corto»: lo mismo SIN el nombre ni las cifras de ninguna persona
--     (lo que usa el cierre: c9 guarda sus filas y las manda al teléfono).
-- ---------------------------------------------------------------------
create or replace function public.fn_nomina_control()
returns table (orden int, control text, nivel text, ok boolean, detalle text, corto text)
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  cfg     nomina_config;
  v_hoy   date := fn_nomina_hoy();
  v_ve    boolean := fn_nomina_ve();
  v_vp    boolean := fn_nomina_ve_personas();
  v_hay   int;
  v_n     int;
  v_txt   text;
  v_s     numeric;
  v_ctas  text[];
  v_mes   text;
  v_ini   date;
  v_tapa  boolean;
  v_n2    int;
  c_sin   constant text := 'Hay nóminas en la base y para comprobar esto hace falta el código del teléfono: entra con él.';
  -- (los controles que miran el dinero de una nómina: sin el código del teléfono no se leen, y no se dan por buenos)
  c_dinero constant int[] := array[10, 15, 20, 25, 30, 32, 35, 45, 50, 55, 60, 62, 65, 80];
  c_tablas constant text[] := array['nomina_config', 'nomina_columnas', 'nomina_personas', 'nomina_archivos', 'nomina_corridas',
                                    'nomina_corrida_personas', 'nomina_lineas', 'nomina_reparto', 'nomina_reparto_horas', 'nomina_pagos',
                                    'nomina_pago_partes', 'nomina_declaraciones', 'nomina_lotes', 'nomina_lote_horas', 'nomina_historial'];
  c_fn     constant text[] := array['fn_nomina_precondiciones', 'fn_nomina_por_api', 'fn_nomina_exigir_dueno', 'fn_nomina_ve', 'fn_nomina_aal2',
                                    'fn_nomina_exigir_codigo', 'fn_nomina_ve_personas', 'fn_nomina_guarda', 'fn_nomina_al_libro',
                                    'fn_nomina_usd', 'fn_nomina_h', 'fn_nomina_dia', 'fn_nomina_hoy', 'fn_nomina_lista', 'fn_nomina_norm', 'fn_nomina_clave',
                                    'fn_nomina_monto', 'fn_nomina_fecha', 'fn_nomina_delicado', 'fn_nomina_etiqueta', 'fn_nomina_cuenta_mal',
                                    'fn_nomina_cuenta_sin_obra', 'fn_nomina_cuentas', 'fn_nomina_fecha_asiento', 'fn_nomina_apunta',
                                    'fn_nomina_config', 'fn_nomina_columna', 'fn_nomina_journal', 'fn_nomina_leer', 'fn_nomina_propone', 'fn_nomina_ya',
                                    'fn_nomina_ensayo', 'fn_nomina_importar',
                                    'fn_nomina_corrida', 'fn_nomina_descartar', 'fn_nomina_persona', 'fn_nomina_decidir', 'fn_nomina_plan',
                                    'fn_nomina_propuesta', 'fn_nomina_postear', 'fn_nomina_anular', 'fn_nomina_pendiente', 'fn_nomina_cargos',
                                    'fn_nomina_cargo_propuesta', 'fn_nomina_cargo_casar', 'fn_nomina_cargo_cuota', 'fn_nomina_cargo_deshacer',
                                    'fn_nomina_cargos_fuera',
                                    'fn_nomina_declaracion', 'fn_nomina_amarre', 'fn_nomina_por_horas', 'fn_nomina_horas_gusto', 'fn_nomina_lote',
                                    'fn_nomina_lote_csv',
                                    'fn_nomina_horas_pagadas', 'fn_nomina_cola', 'fn_nomina_pagado_hasta', 'fn_nomina_auxiliar',
                                    'fn_nomina_bolsa', 'fn_nomina_bolsa_repartir', 'fn_nomina_control',
                                    'fn_nomina_cierre',
                                    'fn_nomina_pegado'];
begin
  if not v_ve then
    return;
  end if;
  select * into cfg from nomina_config where id = 1;
  select count(*) into v_hay from nomina_corridas k where k.estado in ('posteada', 'anulada');
  -- (por la API y sin el código del teléfono, las corridas no se leen: si algún archivo entró alguna vez, lo que mira el dinero
  -- de una nómina no se da por bueno y lo dice; con el código, o desde el SQL Editor y la ronda, se mira todo)
  v_tapa := not v_vp and exists (select 1 from nomina_archivos);
  if v_tapa then
    v_hay := greatest(v_hay, 1);
  end if;

  -- 10. Cada corrida posteada es su asiento.
  select count(*), fn_nomina_lista(array_agg(q.t order by q.t)) into v_n, v_txt
    from (select format('la nómina del %s (%s): %s', fn_nomina_dia(k.dia_pago), coalesce(k.asiento_numero, 'sin asiento'), x.que) as t
            from nomina_corridas k
            left join asientos a on a.id = k.asiento_id
            cross join lateral (
              select concat_ws(', ',
                case when a.id is null then 'su asiento no está en el libro' end,
                case when a.id is not null and (a.origen_tabla is distinct from 'nomina_corridas' or a.origen_id is distinct from k.id::text)
                     then 'su asiento no dice que es de esta corrida' end,
                case when k.estado = 'posteada' and exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
                     then 'su asiento se reversó en el libro sin anular la corrida' end,
                case when k.estado = 'anulada' and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
                     then 'está anulada y su asiento sigue vivo' end,
                case when k.estado = 'posteada' and k.burden_asiento_id is not null
                          and exists (select 1 from asientos r where r.reversa_a = k.burden_asiento_id and r.camino = 'reverso')
                     then 'el reparto de su burden se reversó sin anular la corrida' end,
                case when a.id is not null
                          and exists (select 1 from jsonb_each_text(k.pasivos) e
                                       where (e.value)::numeric <> coalesce((select -sum(l.monto) from asiento_lineas l
                                                                              where l.asiento_id = a.id and l.cuenta = e.key), 0))
                     then 'lo que dejó por pagar no es lo que dice su asiento' end,
                -- (la bolsa es la cuenta que está en los dos asientos: lo que el journal le metió y lo que el reparto le sacó
                -- suman cero, sea cual sea su signo —una corrección que devuelve lo trae todo al revés—)
                case when k.estado = 'posteada' and k.burden_asiento_id is not null
                          and (   not exists (select 1 from asiento_lineas b join asiento_lineas j2 on j2.cuenta = b.cuenta
                                               where b.asiento_id = k.burden_asiento_id and j2.asiento_id = a.id)
                               or exists (select 1 from (select l.cuenta, sum(l.monto) as s from asiento_lineas l
                                                          where l.asiento_id = k.burden_asiento_id group by l.cuenta) b
                                                   join (select l2.cuenta, sum(l2.monto) as s from asiento_lineas l2
                                                          where l2.asiento_id = a.id group by l2.cuenta) j2 on j2.cuenta = b.cuenta
                                           where b.s + j2.s <> 0))
                     then 'lo que su journal metió en la bolsa del burden no es lo que su reparto sacó a las obras' end,
                case when a.id is not null
                          and (select coalesce(sum(l.monto), 0) from asiento_lineas l where l.asiento_id = a.id and l.monto > 0)
                              <> k.bruto + k.imp_patron + k.ben_patron + k.reembolsos
                          and k.bruto >= 0 and k.imp_patron >= 0 and k.ben_patron >= 0 and k.reembolsos >= 0
                     then format('su asiento lleva %s al debe y su journal dice %s',
                                 fn_nomina_usd((select coalesce(sum(l.monto), 0) from asiento_lineas l where l.asiento_id = a.id and l.monto > 0)),
                                 fn_nomina_usd(k.bruto + k.imp_patron + k.ben_patron + k.reembolsos)) end) as que) x
           where k.estado in ('posteada', 'anulada') and x.que <> ''
          union all
          select format('el asiento %s dice ser de una nómina y no es el de ninguna corrida posteada', a.numero)
            from asientos a
           where a.origen_tabla in ('nomina_corridas', 'nomina_burden') and a.camino not in ('reverso', 'reverso_automatico')
             and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
             and not exists (select 1 from nomina_corridas k
                              where k.estado = 'posteada' and a.id in (k.asiento_id, k.burden_asiento_id))) q;
  orden := 10; control := 'cada corrida posteada es su asiento'; nivel := 'cuadre'; ok := v_n = 0;
  detalle := case when v_n = 0 then format('%s corrida(s) en el libro: cada una con su asiento, y cada asiento de la nómina con su corrida.', v_hay)
                  else format('%s no cuadra(n): %s. Avisa antes de tocar nada: el libro y la nómina ya no dicen lo mismo.', v_n, v_txt) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 15. Cada corrida posteada cuadra con su journal.
  select count(*), fn_nomina_lista(array_agg(q.t order by q.t)) into v_n, v_txt
    from (select format('la nómina del %s: %s', fn_nomina_dia(k.dia_pago),
                        concat_ws(', ', case when not k.cuadra then 'se posteó sin cuadrar con su archivo' end,
                                        case when k.bruto - k.imp_empleado - k.deducciones + k.reembolsos_en_neto <> k.neto
                                             then format('bruto − retenido − deducciones da %s y su neto es %s',
                                                         fn_nomina_usd(k.bruto - k.imp_empleado - k.deducciones + k.reembolsos_en_neto),
                                                         fn_nomina_usd(k.neto)) end,
                                        case when jsonb_array_length(k.sin_clasificar) > 0 then 'tiene columnas con cifras sin clasificar' end)) as t
            from nomina_corridas k
           where k.estado = 'posteada'
             and (not k.cuadra or k.bruto - k.imp_empleado - k.deducciones + k.reembolsos_en_neto <> k.neto
                  or jsonb_array_length(k.sin_clasificar) > 0)
          union all
          select format('la nómina del %s: las líneas de %s no suman sus totales', fn_nomina_dia(k.dia_pago), cp.nombre)
            from nomina_corridas k
            join nomina_corrida_personas cp on cp.corrida_id = k.id
            cross join lateral (
              select coalesce(sum(l.monto) filter (where l.clase = 'bruto'), 0) as bruto,
                     coalesce(sum(l.monto) filter (where l.clase = 'imp_empleado'), 0) as imp_empleado,
                     coalesce(sum(l.monto) filter (where l.clase = 'deduccion'), 0) as deducciones,
                     coalesce(sum(l.monto) filter (where l.clase = 'neto'), 0) as neto,
                     coalesce(sum(l.monto) filter (where l.clase = 'reembolso'), 0) as reembolsos,
                     coalesce(sum(l.monto) filter (where l.clase = 'imp_patron'), 0) as imp_patron,
                     coalesce(sum(l.monto) filter (where l.clase = 'ben_patron'), 0) as ben_patron
                from nomina_lineas l where l.corrida_id = k.id and l.persona_id = cp.persona_id) s
           where k.estado = 'posteada' and v_vp
             and (cp.bruto <> s.bruto or cp.imp_empleado <> s.imp_empleado or cp.deducciones <> s.deducciones or cp.neto <> s.neto
                  or cp.reembolsos <> s.reembolsos or cp.imp_patron <> s.imp_patron or cp.ben_patron <> s.ben_patron)) q;
  orden := 15; control := 'cada corrida posteada cuadra con su journal'; nivel := 'cuadre';
  ok := v_n = 0 and (v_vp or v_hay = 0);
  detalle := case when v_n > 0 then format('%s no cuadra(n): %s.', v_n, v_txt)
                  when not v_vp and v_hay > 0 then c_sin
                  else 'Cada corrida posteada cuadra al centavo con su journal: bruto − retenido − deducciones = neto, persona por persona y en total.' end;
  corto := case when v_n > 0 then format('%s cosa(s) de una nómina posteada no cuadran con su journal.', v_n) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 20. El reparto y el lote.
  if v_vp then
    select count(*), fn_nomina_lista(array_agg(q.t order by q.t)) into v_n, v_txt
      from (select format('la nómina del %s: el reparto de %s suma %s de sueldo y %s de lo patronal, y su journal dice %s y %s',
                          fn_nomina_dia(k.dia_pago), cp.nombre, fn_nomina_usd(r.b), fn_nomina_usd(r.p), fn_nomina_usd(cp.bruto),
                          fn_nomina_usd(cp.imp_patron + cp.ben_patron)) as t
              from nomina_corridas k
              join nomina_corrida_personas cp on cp.corrida_id = k.id
              cross join lateral (select coalesce(sum(r.monto) filter (where r.clase = 'bruto'), 0) as b,
                                         coalesce(sum(r.monto) filter (where r.clase = 'patron'), 0) as p
                                    from nomina_reparto r where r.corrida_id = k.id and r.persona_id = cp.persona_id) r
             where k.estado = 'posteada' and (r.b <> cp.bruto or r.p <> cp.imp_patron + cp.ben_patron)
            union all
            select format('la nómina del %s: el lote de %s reparte %s por sus horas y su reparto por horas es de %s', fn_nomina_dia(k.dia_pago),
                          cp.nombre, fn_nomina_usd(h.b), fn_nomina_usd(r.b))
              from nomina_corridas k
              join nomina_corrida_personas cp on cp.corrida_id = k.id
              cross join lateral (select coalesce(sum(rh.bruto), 0) as b from nomina_reparto_horas rh
                                   where rh.corrida_id = k.id and rh.persona_id = cp.persona_id) h
              cross join lateral (select coalesce(sum(r.monto), 0) as b from nomina_reparto r
                                   where r.corrida_id = k.id and r.persona_id = cp.persona_id and r.clase = 'bruto' and r.horas is not null) r
             where k.estado = 'posteada' and h.b <> r.b
            union all
            select format('la nómina del %s (%s): su lote %s', fn_nomina_dia(k.dia_pago), k.estado,
                          case when k.estado = 'posteada' then 'tiene horas que ya no están vivas' else 'sigue teniendo horas vivas' end)
              from nomina_corridas k
             where k.estado in ('posteada', 'anulada')
               and exists (select 1 from nomina_reparto_horas rh where rh.corrida_id = k.id and rh.vivo <> (k.estado = 'posteada'))) q;
  else
    v_n := 0; v_txt := null;
  end if;
  orden := 20; control := 'el reparto de cada corrida suma su journal, y su lote es el de sus horas'; nivel := 'cuadre';
  ok := v_n = 0 and (v_vp or v_hay = 0);
  detalle := case when v_n > 0 then format('%s no cuadra(n): %s.', v_n, v_txt)
                  when not v_vp and v_hay > 0 then c_sin
                  else 'El reparto de cada persona suma su bruto y lo patronal al centavo, cada lote reparte lo que dice su reparto, y ninguna hora '
                       'está en dos nóminas vivas.' end;
  corto := case when v_n > 0 then format('%s cosa(s) del reparto de una nómina no suman lo de su journal.', v_n) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 25. Los cargos casados.
  select count(*), fn_nomina_lista(array_agg(q.t order by q.t)) into v_n, v_txt
    from (select format('el cargo del %s por %s: %s', fn_nomina_dia(g.fecha), fn_nomina_usd(g.monto),
                        concat_ws(', ',
                          case when m.id is null or m.estado not in ('casado', 'en_transito') or m.asiento_id is distinct from g.asiento_id
                               then 'ya no está casado con su asiento en el banco (se des-casó en la Bandeja)'
                                    || case when exists (select 1 from asientos r where r.reversa_a = g.asiento_id and r.camino = 'reverso')
                                            then ', y su asiento ya está reversado' else '' end
                                    || ': en Cargos de Gusto, deshazlo aquí también, o cásalo otra vez y se apunta solo'
                               when exists (select 1 from asientos r where r.reversa_a = g.asiento_id and r.camino = 'reverso')
                               then 'su asiento se reversó' end,
                          case when g.clase <> 'cuota' and g.monto <> coalesce((select sum(pp.monto) from nomina_pago_partes pp where pp.pago_id = g.id), 0)
                               then 'sus partes no suman el cargo' end,
                          case when g.clase <> 'cuota' and exists (select 1 from nomina_pago_partes pp join nomina_corridas k on k.id = pp.corrida_id
                                                                    where pp.pago_id = g.id and k.estado <> 'posteada')
                               then 'paga una nómina que ya no está posteada' end)) as t
            from nomina_pagos g
            left join movimientos_banco m on m.id = g.movimiento_id
           where g.estado = 'aplicado'
             and (m.id is null or m.estado not in ('casado', 'en_transito') or m.asiento_id is distinct from g.asiento_id
                  or exists (select 1 from asientos r where r.reversa_a = g.asiento_id and r.camino = 'reverso')
                  or (g.clase <> 'cuota' and g.monto <> coalesce((select sum(pp.monto) from nomina_pago_partes pp where pp.pago_id = g.id), 0))
                  or (g.clase <> 'cuota' and exists (select 1 from nomina_pago_partes pp join nomina_corridas k on k.id = pp.corrida_id
                                                      where pp.pago_id = g.id and k.estado <> 'posteada')))
          union all
          select format('la nómina del %s tiene pagado de más en %s: dejó %s %s y sus cargos suman %s', fn_nomina_dia(p.dia_pago), p.cuenta,
                        case when p.acreditado < 0 then 'a favor' else 'por pagar' end, fn_nomina_usd(abs(p.acreditado)), fn_nomina_usd(p.pagado))
            from fn_nomina_pendiente() p
           where (p.acreditado >= 0 and p.pendiente < 0) or (p.acreditado < 0 and p.pendiente > 0)) q;
  orden := 25; control := 'cada cargo de Gusto casado sigue casado, sus partes suman el cargo y nada está pagado de más'; nivel := 'cuadre';
  ok := v_n = 0;
  detalle := case when v_n = 0 then format('%s cargo(s) de Gusto resueltos desde la nómina, cada uno con su asiento del banco.',
                                           (select count(*) from nomina_pagos g where g.estado = 'aplicado'))
                  else format('%s no cuadra(n): %s.', v_n, v_txt) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 30. Corridas importadas sin postear.
  select count(*), fn_nomina_lista(array_agg(format('la del %s (%s, bruto %s)%s', fn_nomina_dia(k.dia_pago), k.tipo, fn_nomina_usd(k.bruto),
                                                    case when not k.cuadra then ': NO cuadra con su archivo'
                                                         when jsonb_array_length(k.sin_clasificar) > 0 then ': trae columnas sin clasificar'
                                                         else '' end) order by k.dia_pago, k.id))
    into v_n, v_txt from nomina_corridas k where k.estado = 'importada';
  orden := 30; control := 'corridas importadas sin postear'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Ninguna nómina importada espera por postear.'
                  else format('%s nómina(s) importada(s) y sin postear: %s. Mientras no se posteen no están en el libro: ábrelas, resuelve lo que '
                              'las frene y postéalas (o descártalas si se subieron por error).', v_n, v_txt) end;
  corto := case when v_n > 0 then format('%s nómina(s) importada(s) y sin postear: mientras no se posteen no están en el libro.', v_n) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 32. Nóminas que parecen la misma, dos veces (las mismas personas con el mismo bruto y el mismo neto, el mismo día de pago o
  -- con un período que se pisa; o, si a una le falta el período, a menos de una semana; o la misma nómina del mismo archivo,
  -- subido otra vez), sin que Edgar haya dicho por qué son dos.
  select count(*), fn_nomina_lista(array_agg(q.t order by q.t)) into v_n, v_txt
    from (select format('la del %s (%s%s) y la del %s (%s%s): %s persona(s), bruto %s', fn_nomina_dia(a1.dia_pago), a1.estado,
                        coalesce(', asiento ' || a1.asiento_numero, ''), fn_nomina_dia(b1.dia_pago), b1.estado,
                        coalesce(', asiento ' || b1.asiento_numero, ''), a1.personas, fn_nomina_usd(a1.bruto)) as t
            from nomina_corridas a1
            join nomina_corridas b1 on b1.firma_personas = a1.firma_personas
                                   and (b1.importada_el, b1.id) > (a1.importada_el, a1.id)
                                   and b1.estado in ('importada', 'posteada') and b1.otra_porque is null
                                   and (b1.dia_pago = a1.dia_pago
                                        or (b1.periodo_desde is not null and a1.periodo_desde is not null
                                            and b1.periodo_desde <= a1.periodo_hasta and b1.periodo_hasta >= a1.periodo_desde)
                                        or ((b1.periodo_desde is null or a1.periodo_desde is null) and abs(b1.dia_pago - a1.dia_pago) <= 6)
                                        or (b1.n = a1.n and b1.archivo_id <> a1.archivo_id
                                            and exists (select 1 from nomina_archivos f1 join nomina_archivos f2 on f2.sha256 = f1.sha256
                                                         where f1.id = a1.archivo_id and f2.id = b1.archivo_id)))
           where a1.estado in ('importada', 'posteada') and a1.firma_personas is not null) q;
  select count(*) into v_n2
    from nomina_corridas a1
    join nomina_corridas b1 on b1.firma_personas = a1.firma_personas and (b1.importada_el, b1.id) > (a1.importada_el, a1.id)
                           and b1.estado = 'posteada' and b1.otra_porque is null
                           and (b1.dia_pago = a1.dia_pago
                                or (b1.periodo_desde is not null and a1.periodo_desde is not null
                                    and b1.periodo_desde <= a1.periodo_hasta and b1.periodo_hasta >= a1.periodo_desde)
                                or ((b1.periodo_desde is null or a1.periodo_desde is null) and abs(b1.dia_pago - a1.dia_pago) <= 6)
                                or (b1.n = a1.n and b1.archivo_id <> a1.archivo_id
                                    and exists (select 1 from nomina_archivos f1 join nomina_archivos f2 on f2.sha256 = f1.sha256
                                                 where f1.id = a1.archivo_id and f2.id = b1.archivo_id)))
   where a1.estado = 'posteada' and a1.firma_personas is not null;
  orden := 32; control := 'nóminas que parecen la misma, dos veces'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Ninguna nómina viva trae a las mismas personas con las mismas cifras que otra del mismo día (o del mismo período).'
                  else format('%s caso(s): %s. Traen a las mismas personas, cada una con su mismo bruto y su mismo neto: parecen la misma '
                              'nómina subida dos veces%s. Si es la misma, descarta la que sobra (o anúlala, si ya se posteó); si de verdad '
                              'son dos, di por qué en la segunda.', v_n, v_txt,
                              case when v_n2 > 0 then format(' (%s ya con las DOS en el libro: su sueldo está dos veces)', v_n2) else '' end) end;
  corto := case when v_n > 0 then format('%s par(es) de nóminas parecen la misma, subida dos veces%s.', v_n,
                                         case when v_n2 > 0 then ' (y ya está dos veces en el libro)' else '' end) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 35. Cargos de Gusto sin casar.
  select count(*), coalesce(sum(g.monto), 0), fn_nomina_lista(array_agg(format('%s del %s («%s»)', fn_nomina_usd(g.monto), fn_nomina_dia(g.fecha),
                                                                               left(coalesce(g.descripcion, ''), 40)) order by g.fecha, g.movimiento_id))
    into v_n, v_s, v_txt from fn_nomina_cargos() g where g.estado = 'pendiente';
  orden := 35; control := 'cargos de Gusto en el banco sin casar con su nómina'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Ningún cargo de Gusto espera en la Bandeja del banco.'
                  else format('%s cargo(s) de Gusto por %s esperan en el banco: %s. Cada uno se casa con lo que su nómina dejó por pagar (o se '
                              'dice que es la cuota mensual): mientras no, la conciliación del banco no se confirma.', v_n, fn_nomina_usd(v_s), v_txt) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 40. Personas sin enlazar o sin confirmar.
  select count(*), fn_nomina_lista(array_agg(format('%s (%s)', pe.nombre,
                                                    case when pe.usuario_id is null then 'sin enlazar'
                                                         when not exists (select 1 from perfiles pf where pf.id = pe.usuario_id) then 'su perfil ya no existe'
                                                         else 'sin confirmar' end) order by pe.nombre))
    into v_n, v_txt
    from nomina_personas pe
   where pe.activo and (pe.usuario_id is null or pe.confirmado_el is null or not exists (select 1 from perfiles pf where pf.id = pe.usuario_id));
  orden := 40; control := 'personas de la nómina sin enlazar o sin confirmar'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Cada persona de la nómina está enlazada con su perfil de la app y confirmada.'
                  else format('%s persona(s): %s. Sus nóminas no se postean hasta decir quién es cada una en la app y su clase (campo, oficial u '
                              'oficina).', v_n, v_txt) end;
  corto := case when v_n > 0 then format('%s persona(s) de la nómina sin enlazar o sin confirmar: sus nóminas no se postean hasta decir quién es '
                                         'cada una.', v_n) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 45. Horas de Gusto distintas de las aprobadas (corridas vivas de los últimos 120 días).
  if v_vp then
    select count(*), fn_nomina_lista(array_agg(q.t order by q.t)) into v_n, v_txt
      from (select format('%s en la nómina del %s: Gusto le pagó %s h y en la app tiene %s h aprobadas del período', cp.nombre,
                          fn_nomina_dia(k.dia_pago), fn_nomina_h(cp.horas), fn_nomina_h(h.ap)) as t
              from nomina_corridas k
              join nomina_corrida_personas cp on cp.corrida_id = k.id
              join nomina_personas pe on pe.id = cp.persona_id and pe.clase = 'campo' and pe.usuario_id is not null
              cross join lateral (select coalesce(sum(h.horas), 0) as ap from horas h
                                   where h.usuario_id = pe.usuario_id and h.fecha between k.periodo_desde and k.periodo_hasta
                                     and h.aprobado_el is not null and h.horas > 0 and h.horas < 100000) h
             where k.estado in ('importada', 'posteada') and k.periodo_desde is not null and k.dia_pago >= v_hoy - 120
               and k.toma_horas   -- (un bono o una corrección no pagan las horas del período: su columna de horas no dice nada)
               and cp.horas is not null and cp.horas <> h.ap) q;
  else
    v_n := 0; v_txt := null;
  end if;
  orden := 45; control := 'horas que pagó Gusto distintas de las aprobadas en la app'; nivel := 'aviso';
  ok := v_n = 0 and (v_vp or v_hay = 0);
  detalle := case when v_n > 0 then format('%s caso(s): %s. El sueldo se repartió (o se repartirá) por las horas de la app: si faltan por aprobar o '
                                           'sobran en Gusto, míralo.', v_n, v_txt)
                  when not v_vp and v_hay > 0 then c_sin
                  else 'Las horas que pagó Gusto son las aprobadas en la app, persona por persona (nóminas de los últimos 120 días).' end;
  corto := case when v_n > 0 then format('%s caso(s) en que las horas que pagó Gusto no son las aprobadas en la app.', v_n) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 50. Horas aprobadas de un período ya pagado que no entraron en ninguna nómina.
  if v_vp then
    select count(*), coalesce(sum(q.h), 0), fn_nomina_lista(array_agg(q.t order by q.t)) into v_n, v_s, v_txt
      from (select sum(h.horas) as h,
                   format('%s: %s h del %s al %s (período de la nómina del %s)', pe.nombre, fn_nomina_h(sum(h.horas)), fn_nomina_dia(min(h.fecha)),
                          fn_nomina_dia(max(h.fecha)), fn_nomina_dia(k.dia_pago)) as t
              from nomina_corridas k
              join nomina_corrida_personas cp on cp.corrida_id = k.id
              join nomina_personas pe on pe.id = cp.persona_id and pe.clase = 'campo' and pe.usuario_id is not null
              join horas h on h.usuario_id = pe.usuario_id and h.fecha between k.periodo_desde and k.periodo_hasta
                          and h.aprobado_el is not null and h.horas > 0 and h.horas < 100000
             where k.estado = 'posteada' and k.toma_horas and k.periodo_desde is not null and k.dia_pago >= v_hoy - 120
               and not exists (select 1 from nomina_reparto_horas rh where rh.horas_id = h.id and rh.titular and rh.vivo)
               and not exists (select 1 from jornal_reparto_horas jh join jornal_repartos jr on jr.id = jh.reparto_id
                                where jh.horas_id = h.id and jr.estado = 'aplicado')
             group by k.id, k.dia_pago, pe.id, pe.nombre) q;
  else
    v_n := 0; v_txt := null; v_s := 0;
  end if;
  orden := 50; control := 'horas aprobadas de un período ya pagado que no entraron en ninguna nómina'; nivel := 'aviso';
  ok := v_n = 0 and (v_vp or v_hay = 0);
  detalle := case when v_n > 0 then format('%s h en %s caso(s): %s. Se aprobaron (o cambiaron de fecha) después de postear su nómina: ninguna nómina '
                                           'las pagó ni les repartió sueldo. Si Gusto ya las pagó en esa nómina, anúlala y vuelve a subirla; si '
                                           'se pagan en la siguiente, entrarán con su corrección.', fn_nomina_h(v_s), v_n, v_txt)
                  when not v_vp and v_hay > 0 then c_sin
                  else 'Todas las horas aprobadas de los períodos ya pagados entraron en su nómina (últimos 120 días).' end;
  corto := case when v_n > 0 then format('%s h aprobadas de un período ya pagado no entraron en ninguna nómina (%s caso(s)).', fn_nomina_h(v_s), v_n) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 55. Horas de un lote ya repartido que cambiaron después.
  if v_vp then
    select count(*), fn_nomina_lista(array_agg(q.t order by q.t)) into v_n, v_txt
      from (select format('el reporte %s de la nómina del %s: %s', rh.horas_id, fn_nomina_dia(k.dia_pago),
                          case when h.id is null then 'ya no existe'
                               when h.aprobado_el is null then 'perdió su aprobación (le cambiaron algo)'
                               else concat_ws(', ', case when h.horas <> rh.horas then format('eran %s h y ahora son %s', fn_nomina_h(rh.horas), fn_nomina_h(h.horas)) end,
                                                    case when h.proyecto_id is distinct from rh.proyecto_id then 'cambió de obra' end,
                                                    case when nullif(btrim(h.co, E' \t\r\n'), '') is distinct from rh.co then 'cambió de CO' end,
                                                    case when h.fecha <> rh.fecha then 'cambió de fecha' end,
                                                    case when h.usuario_id <> rh.usuario_id then 'cambió de persona' end) end) as t
              from nomina_reparto_horas rh
              join nomina_corridas k on k.id = rh.corrida_id
              left join horas h on h.id = rh.horas_id
             where rh.vivo and k.estado = 'posteada'
               and (h.id is null or h.aprobado_el is null or h.horas <> rh.horas or h.proyecto_id is distinct from rh.proyecto_id
                    or nullif(btrim(h.co, E' \t\r\n'), '') is distinct from rh.co or h.fecha <> rh.fecha or h.usuario_id <> rh.usuario_id)) q;
  else
    v_n := 0; v_txt := null;
  end if;
  orden := 55; control := 'horas de una nómina ya repartida que cambiaron después'; nivel := 'aviso';
  ok := v_n = 0 and (v_vp or v_hay = 0);
  detalle := case when v_n > 0 then format('%s reporte(s): %s. El sueldo se repartió con las horas de entonces: si el cambio mueve dinero entre '
                                           'obras, anula la nómina y vuelve a subirla (se repartirá con las de hoy).', v_n, v_txt)
                  when not v_vp and v_hay > 0 then c_sin
                  else 'Las horas con que se repartió cada nómina siguen como estaban.' end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 60. Lo que quedó por pagar (o a favor) y no baja. Cada cosa con su camino: el neto y los impuestos los cobra Gusto; el neto
  -- de quien cobró con cheque de papel baja cuando el cheque se cobra; las deducciones las paga quien las cobra (la manutención,
  -- Gusto; una cuota sindical, un seguro o un 401(k) por fuera, a ese tercero); y lo que una corrección dejó a favor lo descuenta
  -- o lo devuelve Gusto.
  select count(*), coalesce(sum(abs(p.pendiente)), 0),
         fn_nomina_lista(array_agg(format('%s %sen %s de la nómina del %s', fn_nomina_usd(abs(p.pendiente)),
                                          case when p.pendiente < 0 then 'a favor ' else '' end, p.cuenta, fn_nomina_dia(p.dia_pago))
                                   order by p.dia_pago, p.cuenta)),
         concat_ws(' ',
           case when bool_or(p.pendiente > 0 and p.clase in ('neto', 'impuestos'))
                then 'El neto y los impuestos los cobra Gusto: si ya los cobró, falta casar su cargo (Cargos de Gusto); si no, míralo en '
                     'Gusto. Si a alguien se le pagó con cheque de papel, su neto baja cuando ese cheque se cobra en el banco: ese cargo '
                     'se casa aquí, como pagado por fuera de Gusto.' end,
           case when bool_or(p.pendiente > 0 and p.clase = 'deducciones')
                then 'Las deducciones las paga quien las cobra: la manutención, Gusto (su cargo se casa aquí); una cuota sindical, un '
                     'seguro o un 401(k) que no pasan por Gusto se le pagan a ese tercero, y ese pago del banco se casa aquí como pagado '
                     'por fuera de Gusto (no se clasifica en la Bandeja).' end,
           case when bool_or(p.pendiente < 0)
                then 'Lo que está a favor (una corrección que devolvió) lo descuenta Gusto de un cargo o lo devuelve al banco: ese '
                     'movimiento se casa aquí.' end)
    into v_n, v_s, v_txt, v_mes
    from fn_nomina_pendiente() p where p.pendiente <> 0 and p.dia_pago + cfg.saldo_dias < v_hoy;
  orden := 60; control := 'lo que una nómina dejó por pagar y sigue sin su cargo'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then format('Nada de lo que dejaron por pagar las nóminas lleva más de %s días sin su cargo.', cfg.saldo_dias)
                  else format('%s en %s saldo(s) con más de %s días: %s. %s', fn_nomina_usd(v_s), v_n, cfg.saldo_dias, v_txt, v_mes) end;
  corto := case when v_n > 0 then format('%s saldo(s) de una nómina llevan más de %s días sin su cargo del banco.', v_n, cfg.saldo_dias) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 62. Lo que entró a las cuentas por pagar de la nómina por otro lado. Se mira desde unos días ANTES de la primera nómina
  --     (los mismos en que se busca su cargo: Gusto cobra antes del día de pago, y un cargo suyo clasificado en la Bandeja
  --     sin pasar por la nómina cae antes de su primera corrida). Un asiento reversado y su reverso no cuentan: se anulan,
  --     caigan o no los dos dentro de lo que se mira (el devengo de horas de un mes y su reverso del día 1).
  select coalesce(array_agg(distinct x.c), '{}') into v_ctas
    from (select e.key as c from nomina_corridas k cross join lateral jsonb_each_text(k.pasivos) e where k.pasivos is not null) x;
  select min(least(k.fecha_asiento, k.dia_pago)) into v_ini from nomina_corridas k where k.asiento_id is not null;
  select least(v_ini, min(g.fecha)) into v_ini from nomina_pagos g where g.clase <> 'cuota';
  v_ini := v_ini - cfg.cargo_dias_antes;
  if v_ini is null then
    v_n := 0; v_txt := null;
  else
    select count(*), fn_nomina_lista(array_agg(format('%s: %s que la %s, en %s asiento(s) que no son de la nómina (%s)', q.cuenta,
                                                      fn_nomina_usd(abs(q.neto)), case when q.neto > 0 then 'suben' else 'bajan' end, q.n, q.cuales)
                                               order by q.cuenta))
      into v_n, v_txt
      from (select l.cuenta, -sum(l.monto) as neto, count(distinct a.id) as n,
                   left(string_agg(distinct a.numero, ', '), 200) as cuales
              from asiento_lineas l
              join asientos a on a.id = l.asiento_id
             where l.cuenta = any (v_ctas) and a.fecha_contable >= v_ini
               and a.reversa_a is null and not exists (select 1 from asientos r where r.reversa_a = a.id)
               and not exists (select 1 from nomina_corridas k where a.id in (k.asiento_id, k.reverso_id, k.burden_asiento_id, k.burden_reverso_id))
               and not exists (select 1 from nomina_pagos g where a.id = g.asiento_id or a.reversa_a = g.asiento_id)
             group by l.cuenta having sum(l.monto) <> 0) q;
  end if;
  orden := 62; control := 'en las cuentas por pagar de la nómina, lo que entró por otro lado'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_ini is null then 'Todavía no hay ninguna nómina en el libro.'
                  when v_n = 0 then format('Desde el %s (unos días antes de la primera nómina, cuando Gusto empieza a cobrar), todo lo que se mueve '
                                           'en sus cuentas por pagar (%s) viene de sus corridas y de sus cargos casados.', fn_nomina_dia(v_ini),
                                           array_to_string(v_ctas, ', '))
                  else format('%s cuenta(s) con movimientos que no son de la nómina desde el %s: %s. Entró por otro lado (un asiento a mano, un '
                              'devengo de horas que sigue vivo, un cargo de Gusto —o el pago de una deducción— clasificado en la Bandeja sin '
                              'pasar por la nómina): míralo en el mayor de esa cuenta; el auxiliar de la nómina no lo explica. Si es un '
                              'movimiento del banco que paga lo de una nómina, des-cásalo en Movimientos y cásalo desde Nómina → Cargos de '
                              'Gusto: así la nómina sabe que está pagado.', v_n, fn_nomina_dia(v_ini), v_txt) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 65. El amarre con las declaraciones.
  select count(*), fn_nomina_lista(array_agg(q.t order by q.o, q.t)) into v_n, v_txt
    from (select 1 as o, a.detalle as t from fn_nomina_amarre(null) a where a.ok is false
          union all
          select 0, format('la nómina del %s trae %s de impuestos sin su renglón de las declaraciones (la retención, Social Security, Medicare, '
                           'FUTA, reempleo): están en el libro, pero el amarre no los puede contar. Dile su renglón a esa columna (o baja el '
                           'archivo con el detalle de impuestos), anúlala y vuelve a subirla', fn_nomina_dia(k.dia_pago),
                           fn_nomina_usd((k.declara->>'sin_renglon')::numeric))
            from nomina_corridas k
           where k.estado = 'posteada' and coalesce((k.declara->>'sin_renglon')::numeric, 0) <> 0
          union all
          select 2, format('falta teclear %s%s de %s (terminó el %s y tiene %s nómina(s))',
                           case a.forma when '941' then 'el 941' when '940' then 'el 940' else 'el RT-6' end,
                           coalesce(' del trimestre ' || a.trimestre, ''), a.anio, fn_nomina_dia(a.hasta), max(a.corridas))
            from fn_nomina_amarre(null) a
           where a.declarado is null and a.hasta + 31 < v_hoy
           group by a.forma, a.anio, a.trimestre, a.hasta) q;
  orden := 65; control := 'el 941, el 940 y el RT-6 amarran con lo posteado'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Cada declaración tecleada amarra con lo posteado por día de pago, y no falta ninguna de un período ya vencido.'
                  else format('%s por mirar: %s', v_n, v_txt) end;
  corto := case when v_n > 0 then format('%s cosa(s) por mirar en el amarre con el 941, el 940 y el RT-6 (una que no amarra, una que falta '
                                         'teclear o impuestos sin su renglón).', v_n) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 70. Un lote de horas pasado a Gusto que ya no es el de hoy.
  select count(*), fn_nomina_lista(array_agg(q.t order by q.t)) into v_n, v_txt
    from (select format('el del %s al %s: %s', fn_nomina_dia(l.desde), fn_nomina_dia(l.hasta),
                        concat_ws(', ', case when x.cambiadas > 0 then format('%s reporte(s) suyos cambiaron o ya no están aprobados', x.cambiadas) end,
                                        case when x.nuevas > 0 then format('hay %s reporte(s) aprobados después (%s h) que no iban', x.nuevas, fn_nomina_h(x.nuevas_h)) end)) as t
            from nomina_lotes l
            cross join lateral (
              select (select count(*) from nomina_lote_horas lh left join horas h on h.id = lh.horas_id
                       where lh.lote_id = l.id and (h.id is null or h.aprobado_el is null or h.horas <> lh.horas or h.fecha <> lh.fecha
                                                    or h.usuario_id <> lh.usuario_id)) as cambiadas,
                     (select count(*) from horas h
                       where h.fecha between l.desde and l.hasta and h.aprobado_el is not null and h.horas > 0 and h.horas < 100000
                         and fn_nomina_por_horas(h.usuario_id)
                         and not exists (select 1 from nomina_lote_horas lh where lh.lote_id = l.id and lh.horas_id = h.id)) as nuevas,
                     (select coalesce(sum(h.horas), 0) from horas h
                       where h.fecha between l.desde and l.hasta and h.aprobado_el is not null and h.horas > 0 and h.horas < 100000
                         and fn_nomina_por_horas(h.usuario_id)
                         and not exists (select 1 from nomina_lote_horas lh where lh.lote_id = l.id and lh.horas_id = h.id)) as nuevas_h) x
           where l.vigente and l.hasta >= v_hoy - 120 and (x.cambiadas > 0 or x.nuevas > 0)) q;
  orden := 70; control := 'el lote de horas que se pasó a Gusto sigue siendo el de hoy'; nivel := 'aviso'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Los lotes de horas pasados a Gusto (últimos 120 días) siguen siendo las horas aprobadas de su período.'
                  else format('%s lote(s) ya no son las horas de hoy: %s. Si Gusto todavía no corrió esa nómina, arma el lote otra vez y pásaselo; '
                              'si ya la corrió, lo que cambió va de corrección en la siguiente.', v_n, v_txt) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 75. La bolsa del burden real.
  select coalesce(sum(l.monto), 0) into v_s from asiento_lineas l where l.cuenta = cfg.cuenta_bolsa;
  orden := 75; control := 'la bolsa del burden real, repartida a las obras'; nivel := 'aviso'; ok := v_s = 0;
  detalle := case when v_s = 0 then format('La bolsa del burden real (%s) no tiene nada sin repartir.', cfg.cuenta_bolsa)
                  else format('La bolsa del burden real (%s) tiene %s sin repartir a las obras. Lo que el patrón paga en cada nómina por la gente '
                              'de obra sale solo a sus obras; lo que queda es lo que entra por otro lado (la prima de WC que se amortiza cada mes, '
                              'su ajuste de auditoría). Al terminar cada mes se reparte a las obras, por las horas que la nómina pagó ese mes '
                              '(Nómina → Ajustes: «lo que queda en la bolsa del burden»): así el costo de cada obra lleva su parte. Si el CPA '
                              'prefiere no repartirlo, lo cierra él a la variación de burden al cierre del año.',
                              cfg.cuenta_bolsa, fn_nomina_usd(v_s)) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 80. La cola del último mes terminado que tiene nómina.
  select max(p.periodo) into v_mes
    from periodos p
   where p.tipo = 'mes' and p.hasta < v_hoy
     and exists (select 1 from nomina_corridas k where k.estado = 'posteada' and k.fecha_asiento between p.desde and p.hasta);
  if v_mes is not null and v_vp then
    select count(distinct q.usuario_id), coalesce(sum(q.horas), 0),
           format('%s h de %s persona(s)%s', fn_nomina_h(coalesce(sum(q.horas), 0)), count(distinct q.usuario_id),
                  coalesce(format(', unos %s a su tarifa estándar', fn_nomina_usd(sum(q.estandar))), ''))
      into v_n, v_s, v_txt from fn_nomina_cola(v_mes) q;
  else
    v_n := 0; v_s := 0; v_txt := null;
  end if;
  orden := 80; control := 'lo trabajado en el mes y todavía no pagado por ninguna nómina'; nivel := 'aviso';
  ok := v_s = 0 and (v_vp or v_mes is null);
  detalle := case when v_mes is null then 'Todavía no hay un mes terminado con nómina.'
                  when not v_vp then c_sin
                  when v_s = 0 then format('En %s no quedó nada trabajado sin pagar: todas sus horas aprobadas las pagó una nómina.', v_mes)
                  else format('En %s quedaron %s trabajadas y sin pagar al terminar el mes: su costo entra con la nómina que las pague, en el mes '
                              'siguiente (un mes con nómina no lleva devengo de horas). No es un error: es el desfase de siempre entre lo '
                              'trabajado y lo pagado; al cierre del año el CPA decide si lo ajusta.', v_mes, v_txt) end;
  corto := case when v_mes is not null and v_vp and v_s <> 0
                then format('En %s quedaron %s h trabajadas y sin pagar al terminar el mes: su costo entra con la nómina que las pague.',
                            v_mes, fn_nomina_h(v_s)) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 85. Lo que falta de configurar.
  select concat_ws(' ',
           case when fn_nomina_cuenta_sin_obra() is null and exists (select 1 from nomina_personas pe where pe.clase = 'campo')
                then 'Falta decir a qué cuenta van las horas sin obra de la gente de campo (una vez, en los ajustes de la nómina).' end,
           case when exists (select 1 from nomina_columnas nc where nc.cuenta is not null and fn_nomina_cuenta_mal(nc.cuenta, 'pasivo') is not null)
                then 'Una cuenta del mapeo de columnas ya no sirve: ' ||
                     (select string_agg(distinct fn_nomina_cuenta_mal(nc.cuenta, 'pasivo'), '; ') from nomina_columnas nc
                       where nc.cuenta is not null and fn_nomina_cuenta_mal(nc.cuenta, 'pasivo') is not null) || '.' end)
    into v_txt;
  orden := 85; control := 'la configuración de la nómina'; nivel := 'aviso'; ok := coalesce(v_txt, '') = '';
  detalle := case when coalesce(v_txt, '') = '' then 'Las cuentas de la nómina y las del mapeo de columnas sirven.' else v_txt end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;

  -- 90. Las protecciones de la capa (por nombre exacto).
  select count(*), string_agg(y.que, '; ') into v_n, v_txt
    from (select pr.proname || ' corre con permisos de más' as que
            from pg_catalog.pg_proc pr
           where pr.pronamespace = 'public'::regnamespace and pr.proname = any (c_fn) and pr.prosecdef and pr.proname <> 'fn_nomina_al_libro'
          union all
          select 'el puente al libro ya no es un trigger con los permisos del dueño de la base'
            from pg_catalog.pg_proc pr
           where pr.pronamespace = 'public'::regnamespace and pr.proname = 'fn_nomina_al_libro'
             and (not pr.prosecdef or pr.prorettype <> 'trigger'::regtype)
          union all
          select format('%s la puede ejecutar %s', pr.proname, g.r)
            from pg_catalog.pg_proc pr cross join (values ('anon'), ('service_role')) g(r)
           where pr.pronamespace = 'public'::regnamespace and pr.proname = any (c_fn) and has_function_privilege(g.r, pr.oid, 'execute')
          union all
          select pr.proname || ' la puede ejecutar la app'
            from pg_catalog.pg_proc pr
           where pr.pronamespace = 'public'::regnamespace
             and pr.proname in ('fn_nomina_precondiciones', 'fn_nomina_guarda', 'fn_nomina_al_libro', 'fn_nomina_pegado')
             and has_function_privilege('authenticated', pr.oid, 'execute')
          union all
          select t.t || case when c.oid is null then ' no existe' when not c.relrowsecurity then ' sin RLS' else ' sin su guarda' end
            from unnest(c_tablas) t(t)
            left join pg_catalog.pg_class c on c.oid = to_regclass('public.' || t.t)
           where c.oid is null or not c.relrowsecurity
              or not exists (select 1 from pg_catalog.pg_trigger tg
                              where tg.tgrelid = c.oid and tg.tgname = 'trg_' || t.t || '_guarda' and tg.tgenabled = 'O'
                                and tg.tgfoid = to_regproc('public.fn_nomina_guarda'))
          union all
          select t.t || ' la puede leer o escribir quien no debe'
            from unnest(c_tablas) t(t)
           where to_regclass('public.' || t.t) is not null
             and (has_table_privilege('anon', 'public.' || t.t, 'select, insert, update, delete')
                  or has_table_privilege('service_role', 'public.' || t.t, 'select, insert, update, delete'))
          union all
          select t.t || ' (lo que lleva dinero de una nómina) se lee sin el código del teléfono'
            from unnest(array['nomina_corridas', 'nomina_corrida_personas', 'nomina_lineas', 'nomina_reparto', 'nomina_reparto_horas',
                              'nomina_pagos', 'nomina_pago_partes']) t(t)
           where to_regclass('public.' || t.t) is not null
             and not exists (select 1 from pg_catalog.pg_policy pl
                              where pl.polrelid = to_regclass('public.' || t.t) and pl.polcmd = 'r'
                                and coalesce(pg_get_expr(pl.polqual, pl.polrelid), '') like '%aal2%'
                                and coalesce(pg_get_expr(pl.polqual, pl.polrelid), '') like '%es_dueno()%')
          union all
          select t.t || ' tiene una policy de más'
            from unnest(c_tablas) t(t)
           where to_regclass('public.' || t.t) is not null
             and exists (select 1 from pg_catalog.pg_policy pl
                          where pl.polrelid = to_regclass('public.' || t.t)
                            and coalesce(pg_get_expr(pl.polqual, pl.polrelid), pg_get_expr(pl.polwithcheck, pl.polrelid), '') not like '%es_dueno()%')
          union all
          select 'el puente de las corridas no está puesto o está apagado'
           where not exists (select 1 from pg_catalog.pg_trigger tg
                              where tg.tgrelid = to_regclass('public.nomina_corridas') and tg.tgname = 'trg_nomina_corridas_libro'
                                and tg.tgenabled = 'O' and tg.tgfoid = to_regproc('public.fn_nomina_al_libro'))
          union all
          select v.v || ' no lee con los permisos de quien la mira'
            from unnest(array['v_nomina_corridas', 'v_nomina_personas', 'v_nomina_cargos', 'v_nomina_amarre', 'v_nomina_lotes',
                              'v_nomina_control', 'v_nomina_papel']) v(v)
            join pg_catalog.pg_class c on c.oid = to_regclass('public.' || v.v)
           where not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o where o.option_name = 'security_invoker'), false)
              or has_table_privilege('anon', c.oid, 'select') or has_table_privilege('service_role', c.oid, 'select')) y;
  orden := 90; control := 'las protecciones de la nómina'; nivel := 'cuadre'; ok := v_n = 0;
  detalle := case when v_n = 0 then 'Solo el dueño ve la nómina y lo que lleva su dinero pide su código; nada se escribe a mano; el equipo, la '
                                    'llave pública y la de servicio no ven nada; y al libro solo se entra por el puente de las corridas.'
                  else format('%s cosa(s) no están como deben: %s. Vuelve a pegar el archivo de la nómina.', v_n, left(v_txt, 1200)) end;
  if v_tapa and orden = any (c_dinero) then ok := false; detalle := c_sin; corto := c_sin; end if;
  corto := coalesce(corto, detalle);
  return next;
  corto := null;
end $$;
revoke execute on function public.fn_nomina_control() from public, anon, service_role;
grant  execute on function public.fn_nomina_control() to authenticated;
comment on function public.fn_nomina_control() is 'c15: EL CONTROL de la nómina: una fila por control (orden, control, nivel: cuadre | aviso, ok, detalle en llano con cifras, y corto: lo mismo sin el nombre ni las cifras de ninguna persona, para el cierre y el teléfono). Cuadres: cada corrida posteada es su asiento (10) y cuadra con su journal (15), su reparto y su lote (20), cada cargo casado (25), las protecciones (90). Avisos: corridas sin postear (30), nóminas que parecen la misma dos veces (32), cargos de Gusto sin casar (35), personas sin enlazar (40), horas de Gusto distintas de las aprobadas (45), horas de un período pagado que no entraron (50), horas de un lote que cambiaron (55), lo que no baja (60), lo que el libro tiene y la nómina no explica (62), el amarre con el 941, el 940 y el RT-6 (65), el lote de horas para Gusto (70), la bolsa del burden (75), la cola del mes (80), la configuración (85). Lo que mira persona por persona pide el código del teléfono. A quien no es el dueño, nada.';

-- ---------------------------------------------------------------------
-- 17. PARA EL CIERRE (c9): cuatro filas fijas de la revisión de un mes.
--       180 detiene  cada cargo de Gusto del mes, casado con su nómina
--       181 detiene  cada nómina con día de pago en el mes, posteada
--       182 detiene  los cuadres de la nómina
--       183 aviso    sus avisos, en una fila
--     Las dos primeras son lo que deja mal el libro DEL MES: un cargo de
--     Gusto sin casar es dinero que salió del banco y no está en el libro;
--     una nómina sin postear es el sueldo del mes que falta. En la apertura
--     y en un año no aplican (la nómina va por mes), salvo los cuadres.
-- ---------------------------------------------------------------------
create or replace function public.fn_nomina_cierre(p_periodo text)
returns table (orden int, control text, nivel text, ok boolean, detalle text, que_hacer text, ir_a text)
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  p     periodos;
  v_mes boolean;
  v_n   int;
  v_s   numeric;
  v_txt text;
  r     record;
  v_tapa boolean;
begin
  if not fn_nomina_ve() then
    return;
  end if;
  select * into p from periodos where periodo = p_periodo;
  if not found then
    return;
  end if;
  v_mes := p.tipo = 'mes';
  ir_a := 'nomina';
  -- (por la API sin el código del teléfono las corridas no se leen: si algún archivo entró, no se dan por buenas)
  v_tapa := not fn_nomina_ve_personas() and exists (select 1 from nomina_archivos);

  orden := 180; control := 'nómina: cada cargo de Gusto del mes casado con su nómina'; nivel := 'detiene';
  if v_mes then
    select count(*), coalesce(sum(g.monto), 0),
           fn_nomina_lista(array_agg(format('%s del %s', fn_nomina_usd(g.monto), fn_nomina_dia(g.fecha)) order by g.fecha, g.movimiento_id), 600)
      into v_n, v_s, v_txt from fn_nomina_cargos() g where g.estado = 'pendiente' and g.fecha between p.desde and p.hasta;
    ok := v_n = 0;
    detalle := case when v_n = 0 then 'Ningún cargo de Gusto del mes espera en el banco.'
                    else format('%s cargo(s) de Gusto del mes por %s salieron del banco y no están en el libro: %s.', v_n, fn_nomina_usd(v_s), v_txt) end;
    que_hacer := case when v_n > 0 then 'Contabilidad → Nómina → Cargos de Gusto: cada uno se casa con lo que su nómina dejó por pagar (sube y '
                                        'postea antes su archivo si falta), o se dice que es la cuota mensual.' end;
  else
    ok := true; detalle := 'No aplica: la nómina va por mes.'; que_hacer := null;
  end if;
  return next;

  orden := 181; control := 'nómina: cada nómina con día de pago en el mes, posteada'; nivel := 'detiene';
  if v_mes then
    -- (sin lo que cobra nadie: esta fila la guarda el cierre y sale al teléfono; el bruto de una nómina de una sola persona es
    -- lo que cobró esa persona)
    select count(*), fn_nomina_lista(array_agg(format('la del %s', fn_nomina_dia(k.dia_pago)) order by k.dia_pago, k.id), 600)
      into v_n, v_txt from nomina_corridas k where k.estado = 'importada' and k.dia_pago between p.desde and p.hasta;
    ok := v_n = 0 and not v_tapa;
    detalle := case when v_tapa then 'Hay nóminas en la base y para mirarlas hace falta el código del teléfono: entra con él.'
                    when v_n = 0
                      then format('%s nómina(s) con día de pago en el mes, todas posteadas.',
                                  (select count(*) from nomina_corridas k where k.estado = 'posteada' and k.dia_pago between p.desde and p.hasta))
                    else format('%s nómina(s) del mes importada(s) y sin postear: %s. Su sueldo y sus impuestos todavía no están en el libro.', v_n, v_txt) end;
    que_hacer := case when v_tapa then 'Entra con el código del teléfono y vuelve a mirar.'
                      when v_n > 0 then 'Contabilidad → Nómina: ábrela, resuelve lo que la frena (una persona sin enlazar, horas sin aprobar, una '
                                        'columna sin clasificar) y postéala; o descártala si se subió por error.' end;
  else
    ok := true; detalle := 'No aplica: la nómina va por mes.'; que_hacer := null;
  end if;
  return next;

  for r in select c.nivel as n, count(*) filter (where not c.ok) as rojos, count(*) as filas,
                  string_agg(c.orden::text, ', ' order by c.orden) filter (where not c.ok) as cuales,
                  string_agg(c.orden || ': ' || case when length(c.detalle) > c.tope then left(c.detalle, c.tope - 1) || '…' else c.detalle end,
                             ' · ' order by c.orden) filter (where not c.ok) as det
             -- (de cada control, su texto CORTO: lo que pasa, sin el nombre ni las cifras de nadie. Esta fila la guarda el cierre
             -- y sale al teléfono; el detalle entero, con el código, está en la página de la nómina)
             from (select k.orden, k.nivel, k.ok is true as ok, coalesce(k.corto, k.detalle, '') as detalle,
                          greatest(120, 1380 / greatest(count(*) filter (where k.ok is not true) over (partition by k.nivel), 1))::int as tope
                     from fn_nomina_control() k) c
            group by c.nivel order by c.nivel desc
  loop
    orden := case when r.n = 'aviso' then 183 else 182 end;
    -- (el nombre de los cuadres dice cuáles están en rojo: la ronda de c9 avisa de un rojo nuevo por el nombre; el de los
    -- avisos es fijo, para que el teléfono no suene cada vez que cambia la lista)
    control := case when r.n = 'aviso' then 'nómina: sus avisos (c15)'
                    else 'nómina: sus cuadres (c15)' || case when r.rojos > 0 then format(' — %s en rojo: %s', r.rojos, r.cuales) else '' end end;
    nivel := case when r.n = 'aviso' then 'aviso' else 'detiene' end;
    ok := r.rojos = 0;
    detalle := case when r.rojos = 0 then format('Los %s, en verde.', r.filas)
                    else format('%s en rojo (%s). ', r.rojos, r.cuales) || coalesce(r.det, 'sin detalle') end;
    que_hacer := case when r.rojos > 0 then 'Aquí va qué pasa en cada uno (con su número), sin nombres ni lo que cobra nadie; el detalle '
                                            'entero, en Contabilidad → Nómina (con el código del teléfono).' end;
    return next;
  end loop;
end $$;
revoke execute on function public.fn_nomina_cierre(text) from public, anon, service_role;
grant  execute on function public.fn_nomina_cierre(text) to authenticated;
comment on function public.fn_nomina_cierre(text) is 'c15: las cuatro filas de la nómina para la revisión del cierre de un período (c9 las pide y las pone): 180 cada cargo de Gusto del mes casado con su nómina (detiene), 181 cada nómina con día de pago en el mes posteada (detiene), 182 los cuadres de la nómina (detiene) y 183 sus avisos (aviso); cada una con su detalle en llano —SIN el nombre ni las cifras de ninguna persona: el cierre guarda estas filas y las manda al teléfono—, qué hacer y a qué página ir (nomina). En la apertura y en un año, la 180 y la 181 no aplican. A quien no es el dueño, nada.';


-- ---------------------------------------------------------------------
-- 18. LAS VISTAS (security_invoker: leen con los permisos de quien mira;
--     el equipo, 0 filas por las policies; anon y service_role, sin grant).
--     Se borraron al principio del archivo y se rehacen aquí.
--       v_nomina_corridas   la lista de nóminas, con su estado, sus totales,
--                           su asiento y lo que les queda por pagar
--       v_nomina_personas   las personas del journal: con quién están
--                           enlazadas, su clase y qué les falta
--       v_nomina_cargos     los cargos de Gusto: pendientes y resueltos
--       v_nomina_amarre     el 941, el 940 y el RT-6 contra lo posteado
--       v_nomina_lotes      los lotes de horas pasados a Gusto, y si cambiaron
--       v_nomina_control    el control
--       v_nomina_papel      el papel de los asientos de la nómina (con las
--                           cuatro columnas de v_papel_fases de c4/c6)
--     Ninguna trae lo que cobra una persona: eso sale de fn_nomina_propuesta
--     (con el código del teléfono).
-- ---------------------------------------------------------------------
create view public.v_nomina_corridas with (security_invoker = true) as
select c.id                                   as corrida_id,
       c.archivo_id,
       ar.nombre                              as archivo,
       c.dia_pago,
       c.periodo_desde,
       c.periodo_hasta,
       c.tipo,
       c.tipo_texto,
       c.toma_horas,
       c.estado,
       c.personas,
       c.bruto,
       c.imp_empleado,
       c.deducciones,
       c.neto,
       c.reembolsos,
       c.imp_patron,
       c.ben_patron,
       c.horas,
       c.cuadra,
       c.descuadres,
       c.sin_clasificar,
       c.avisos,
       c.asiento_id,
       c.asiento_numero,
       c.fecha_asiento,
       c.burden_asiento_id,
       ba.numero                              as burden_numero,
       c.pasivos,
       pd.por_pagar,
       pd.pagado,
       c.importada_el,
       c.posteada_el,
       c.anulada_el,
       c.anulada_motivo,
       rv.numero                              as reverso_numero,
       c.descartada_el,
       c.descartada_motivo,
       pd.a_favor,
       c.otra_porque
  from public.nomina_corridas c
  join public.nomina_archivos ar on ar.id = c.archivo_id
  left join public.asientos ba on ba.id = c.burden_asiento_id
  left join public.asientos rv on rv.id = c.reverso_id
  -- (por_pagar: lo que todavía se debe, cuenta por cuenta; a_favor: lo que una corrección dejó a favor y nadie ha descontado ni
  -- devuelto todavía. No se restan entre sí: son de cuentas distintas y cada una espera su movimiento del banco.)
  left join lateral (select sum(greatest(p.pendiente, 0))::numeric(14,2) as por_pagar, sum(p.pagado) as pagado,
                            sum(greatest(-p.pendiente, 0))::numeric(14,2) as a_favor
                       from public.fn_nomina_pendiente(c.id) p) pd on true;

create view public.v_nomina_personas with (security_invoker = true) as
select pe.id                                  as persona_id,
       pe.nombre,
       pe.usuario_id,
       pf.nombre                              as perfil,
       pf.rol                                 as perfil_rol,
       pe.clase,
       pe.a_obra,
       pe.horas_periodo,
       pe.activo,
       pe.confirmado_el,
       case when pe.usuario_id is null then 'sin_enlazar'
            when pf.id is null then 'perfil_no_existe'
            when pe.confirmado_el is null then 'sin_confirmar'
            else 'lista' end                  as estado,
       pr.usuario_id                          as propuesta_usuario_id,
       pr.perfil                              as propuesta_perfil,
       pr.clase                               as propuesta_clase,
       pe.nota,
       pe.creado_el,
       pe.actualizado_el
  from public.nomina_personas pe
  left join public.perfiles pf on pf.id = pe.usuario_id
  left join lateral (
    -- (la propuesta: el único perfil activo de la app con las palabras de su nombre que todavía no está enlazado con nadie de
    -- la nómina; con dos candidatos no se propone ninguno)
    select x.usuario_id, x.perfil, x.clase from public.fn_nomina_propone(pe.clave) x where pe.usuario_id is null) pr on true;

create view public.v_nomina_cargos with (security_invoker = true) as
select g.movimiento_id, g.fecha, g.monto, g.descripcion, g.cuenta, g.estado, g.clase_probable, g.pago_id, g.asiento_id, g.asiento,
       g.corridas, g.texto, g.opciones
  from public.fn_nomina_cargos() g;

create view public.v_nomina_amarre with (security_invoker = true) as
select a.forma, a.anio, a.trimestre, a.desde, a.hasta, a.campo, a.declarado, a.libro, a.diferencia, a.ok, a.corridas, a.detalle
  from public.fn_nomina_amarre(null) a;

create view public.v_nomina_lotes with (security_invoker = true) as
select l.id                                   as lote_id,
       l.desde,
       l.hasta,
       l.semana_empieza,
       l.horas_extra_desde,
       l.personas,
       l.horas,
       l.regulares,
       l.extra,
       l.vigente,
       l.nota,
       l.creado_el,
       l.sustituido_el,
       x.cambiadas,
       x.nuevas,
       x.nuevas_horas,
       l.vigente and (x.cambiadas > 0 or x.nuevas > 0) as cambio
  from public.nomina_lotes l
  cross join lateral (
    select (select count(*) from public.nomina_lote_horas lh left join public.horas h on h.id = lh.horas_id
             where lh.lote_id = l.id and (h.id is null or h.aprobado_el is null or h.horas <> lh.horas or h.fecha <> lh.fecha
                                          or h.usuario_id <> lh.usuario_id)) as cambiadas,
           (select count(*) from public.horas h
             where h.fecha between l.desde and l.hasta and h.aprobado_el is not null and h.horas > 0 and h.horas < 100000
               and public.fn_nomina_por_horas(h.usuario_id)
               and not exists (select 1 from public.nomina_lote_horas lh where lh.lote_id = l.id and lh.horas_id = h.id)) as nuevas,
           (select coalesce(sum(h.horas), 0) from public.horas h
             where h.fecha between l.desde and l.hasta and h.aprobado_el is not null and h.horas > 0 and h.horas < 100000
               and public.fn_nomina_por_horas(h.usuario_id)
               and not exists (select 1 from public.nomina_lote_horas lh where lh.lote_id = l.id and lh.horas_id = h.id)) as nuevas_horas) x;

create view public.v_nomina_control with (security_invoker = true) as
select k.orden, k.control, k.nivel, k.ok, k.detalle, k.corto
  from public.fn_nomina_control() k;

-- EL PAPEL de los asientos de la nómina, con las cuatro columnas de
-- v_papel_fases (c4 la crea, c6 la llena y la SELLA: su control «las
-- protecciones del banco» se pone en rojo si alguien le cambia la
-- definición, así que este archivo no la toca —se probó añadirle esta rama
-- desde aquí y ese cuadre del banco lo detecta—). Hasta que c6 le añada
-- esta rama, v_asiento_papel de c4 dice de un asiento de la nómina
-- «nomina_corridas … (el papel ya no está)»: el papel ESTÁ, y es este. La
-- pantalla lo lee de aquí por origen_tabla y origen_id.
create view public.v_nomina_papel with (security_invoker = true) as
select 'nomina_corridas'::text                as origen_tabla,
       c.id::text                             as origen_id,
       concat_ws(' · ', 'Nómina de Gusto del ' || public.fn_nomina_dia(c.dia_pago),
                 'período del ' || public.fn_nomina_dia(c.periodo_desde) || ' al ' || public.fn_nomina_dia(c.periodo_hasta),
                 case c.tipo when 'regular' then 'regular' else 'fuera de ciclo' end,
                 c.personas || ' persona(s)', 'bruto ' || public.fn_nomina_usd(c.bruto), 'neto ' || public.fn_nomina_usd(c.neto),
                 'archivo «' || ar.nombre || '»', c.estado) as papel,
       null::text                             as ruta
  from public.nomina_corridas c
  join public.nomina_archivos ar on ar.id = c.archivo_id
union all
select 'nomina_burden'::text, c.id::text,
       concat_ws(' · ', 'Reparto del burden real de la nómina de Gusto del ' || public.fn_nomina_dia(c.dia_pago) || ' a sus obras',
                 'journal ' || c.asiento_numero, c.estado),
       null::text
  from public.nomina_corridas c
 where c.burden_asiento_id is not null;

do $$
declare
  v text;
begin
  foreach v in array array['v_nomina_corridas', 'v_nomina_personas', 'v_nomina_cargos', 'v_nomina_amarre', 'v_nomina_lotes',
                           'v_nomina_control', 'v_nomina_papel'] loop
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', v);
    execute format('grant select on public.%I to authenticated', v);
  end loop;
end $$;
comment on view public.v_nomina_corridas is 'c15: la lista de nóminas (corridas): su archivo, su día de pago y su período, su tipo, su estado (importada, posteada, anulada, descartada), sus totales del journal, si cuadra y dónde no, las columnas sin clasificar, sus avisos, su asiento y el del reparto del burden, lo que dejó por pagar en cada cuenta (pasivos: en negativo, lo que una corrección dejó a favor), lo que le queda por pagar (por_pagar), lo que le queda a favor sin descontar ni devolver (a_favor) y lo ya movido por sus cargos casados (pagado), sus fechas y, si se dijo que es otra nómina con las mismas personas y cifras que otra, por qué (otra_porque). No trae lo de cada persona. Solo el dueño, con el código del teléfono.';
comment on view public.v_nomina_personas is 'c15: las personas del journal de nómina: su nombre en el archivo, su perfil de la app, su clase, si su sueldo de oficial va en parte a obra y cuántas horas cubre, su estado (sin_enlazar, perfil_no_existe, sin_confirmar, lista) y, sin enlazar, el perfil que se propone por el nombre (solo si hay uno y está libre) con la clase que saldría de su rol. No trae lo que cobra nadie. Solo el dueño.';
comment on view public.v_nomina_cargos is 'c15: los cargos de Gusto en el banco: los pendientes en la Bandeja (con lo que sugiere su descripción, su propuesta en una línea y cuántas opciones tiene) y los resueltos desde la nómina (casado o cuota, con su asiento y qué pagó). Solo el dueño.';
comment on view public.v_nomina_amarre is 'c15: el amarre con el 941, el 940 y el RT-6: una fila por declaración, período y renglón con lo declarado (lo que tecleó Edgar), lo posteado por día de pago, la diferencia, si amarra y el detalle en llano. Solo el dueño.';
comment on view public.v_nomina_lotes is 'c15: los lotes de horas aprobadas que se pasaron a Gusto: su período, sus horas (total, regulares, extra), si es el vigente y si ya no es el de hoy (cambio): cuántos reportes suyos cambiaron o perdieron su aprobación (cambiadas) y cuántos se aprobaron después sin ir en él (nuevas, nuevas_horas). Solo el dueño.';
comment on view public.v_nomina_control is 'c15: el control de la nómina: una fila por control (orden, control, nivel: cuadre | aviso, ok, detalle en llano, y corto: lo mismo sin el nombre ni las cifras de nadie). Solo el dueño.';
comment on view public.v_nomina_papel is 'c15: el papel de los asientos de la nómina, con las cuatro columnas de v_papel_fases (origen_tabla, origen_id, papel, ruta): el journal de cada corrida (origen nomina_corridas) y el reparto de su burden real (origen nomina_burden). Solo el dueño, con el código del teléfono.';


-- ---------------------------------------------------------------------
-- 19. Lo que debe verse al pegar: fn_nomina_pegado().
-- ---------------------------------------------------------------------
create or replace function public.fn_nomina_pegado() returns table (que text, detalle text)
language plpgsql
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  c       nomina_config;
  v_txt   text;
  v_falta text[] := '{}';
  v_r     record;
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  select * into c from nomina_config where id = 1;
  return query select 'nomina_config'::text,
                      format('sueldo de oficina %s · oficial %s · sin obra %s · bolsa del burden real %s → burden por obra %s · burden de '
                             'oficina %s · cuota de Gusto %s · la semana empieza en %s y las extra desde %s h · el sueldo del oficial cubre '
                             '%s h por período · el cargo de Gusto se busca de %s días antes a %s después del día de pago · tolerancia del '
                             'amarre %s',
                             c.cuenta_oficina, c.cuenta_oficial,
                             coalesce(fn_nomina_cuenta_sin_obra() || case when c.cuenta_sin_obra is null then ' (la del jornal)' else '' end,
                                      'SIN DECIR (▶ Edgar: dila antes de la primera nómina con horas sin obra)'),
                             c.cuenta_bolsa, c.cuenta_burden_obra, c.cuenta_burden_admin, c.cuenta_cuota,
                             (array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'])[c.semana_empieza],
                             fn_nomina_h(c.horas_extra_desde), fn_nomina_h(c.horas_periodo_oficial), c.cargo_dias_antes, c.cargo_dias_despues,
                             fn_nomina_usd(c.amarre_tolerancia));
  return query select 'el mapeo de columnas'::text,
                      format('%s nombres de columna (%s de fábrica, los del «Payroll journal» de Gusto; %s añadidos aquí) · %s con cuenta · %s que no '
                             'se guardan nunca (delicado). A confirmar con el primer archivo real.',
                             count(*), count(*) filter (where k.de_fabrica), count(*) filter (where not k.de_fabrica),
                             count(*) filter (where k.cuenta is not null), count(*) filter (where k.clase = 'delicado'))
                        from nomina_columnas k;
  return query select 'tablas'::text,
                      format('nomina_config, nomina_columnas, nomina_personas (%s), nomina_archivos (%s), nomina_corridas (%s: %s importadas, '
                             '%s posteadas, %s anuladas, %s descartadas), nomina_corrida_personas, nomina_lineas, nomina_reparto, '
                             'nomina_reparto_horas (%s horas pagadas vivas), nomina_pagos (%s vivos), nomina_pago_partes, '
                             'nomina_declaraciones (%s vigentes), nomina_lotes (%s vigentes), nomina_lote_horas, nomina_historial (%s)',
                             (select count(*) from nomina_personas), (select count(*) from nomina_archivos),
                             (select count(*) from nomina_corridas),
                             (select count(*) from nomina_corridas k where k.estado = 'importada'),
                             (select count(*) from nomina_corridas k where k.estado = 'posteada'),
                             (select count(*) from nomina_corridas k where k.estado = 'anulada'),
                             (select count(*) from nomina_corridas k where k.estado = 'descartada'),
                             (select count(*) from nomina_reparto_horas rh where rh.titular and rh.vivo),
                             (select count(*) from nomina_pagos g where g.estado = 'aplicado'),
                             (select count(*) from nomina_declaraciones d where d.vigente),
                             (select count(*) from nomina_lotes l where l.vigente), (select count(*) from nomina_historial));
  return query select 'vistas'::text,
                      'v_nomina_corridas, v_nomina_personas, v_nomina_cargos, v_nomina_amarre, v_nomina_lotes, v_nomina_control, v_nomina_papel'::text;
  return query select 'el puente al libro'::text,
                      case when exists (select 1 from pg_trigger tg
                                         where tg.tgrelid = 'public.nomina_corridas'::regclass and tg.tgname = 'trg_nomina_corridas_libro'
                                           and tg.tgenabled = 'O')
                           then 'puesto: una corrida entra al libro al postearla (origen nomina_corridas, y nomina_burden el reparto de su '
                                'burden) y sale al anularla, con sus reversos'
                           else 'NO ESTÁ: vuelve a pegar este archivo' end;
  begin
    select count(*) filter (where g.estado = 'pendiente') as pend, coalesce(sum(g.monto) filter (where g.estado = 'pendiente'), 0) as pend_usd,
           count(*) filter (where g.estado = 'casado') as casados, count(*) filter (where g.estado = 'cuota') as cuotas
      into v_r from fn_nomina_cargos() g;
    v_txt := format('%s pendiente(s) en la Bandeja por %s · %s casado(s) con su nómina · %s cuota(s) mensual(es)', v_r.pend,
                    fn_nomina_usd(v_r.pend_usd), v_r.casados, v_r.cuotas);
    if v_r.pend > 0 then
      v_falta := v_falta || format('casar %s cargo(s) de Gusto del banco con su nómina', v_r.pend);
    end if;
  exception when others then
    v_txt := format('la lista de cargos falló: %s %s', sqlstate, sqlerrm);
  end;
  return query select 'los cargos de Gusto en el banco'::text, v_txt;
  begin
    select format('%s de %s cuadres en rojo%s · %s de %s avisos%s',
                  count(*) filter (where k.nivel = 'cuadre' and k.ok is distinct from true), count(*) filter (where k.nivel = 'cuadre'),
                  coalesce(' (' || string_agg(k.orden || ' ' || k.control, '; ' order by k.orden)
                                     filter (where k.nivel = 'cuadre' and k.ok is distinct from true) || ')', ''),
                  count(*) filter (where k.nivel = 'aviso' and k.ok is distinct from true), count(*) filter (where k.nivel = 'aviso'),
                  coalesce(' (' || string_agg(k.orden || ' ' || k.control, '; ' order by k.orden)
                                     filter (where k.nivel = 'aviso' and k.ok is distinct from true) || ')', ''))
      into v_txt
      from fn_nomina_control() k;
  exception when others then
    v_txt := format('el control falló: %s %s', sqlstate, sqlerrm);
  end;
  return query select 'control'::text, v_txt;
  if fn_nomina_cuenta_sin_obra() is null then
    v_falta := v_falta || 'decir a qué cuenta van las horas sin obra de la gente de campo'::text;
  end if;
  if exists (select 1 from nomina_personas pe where pe.activo and (pe.usuario_id is null or pe.confirmado_el is null)) then
    v_falta := v_falta || format('enlazar y confirmar a %s persona(s) de la nómina',
                                 (select count(*) from nomina_personas pe where pe.activo and (pe.usuario_id is null or pe.confirmado_el is null)));
  end if;
  if exists (select 1 from nomina_corridas k where k.estado = 'importada') then
    v_falta := v_falta || format('postear (o descartar) %s nómina(s) importada(s)', (select count(*) from nomina_corridas k where k.estado = 'importada'));
  end if;
  if not exists (select 1 from nomina_corridas) then
    v_falta := v_falta || 'subir el primer «Payroll journal» de Gusto (CSV) y confirmar con él los nombres de sus columnas'::text;
  end if;
  return query select 'qué falta'::text, case when cardinality(v_falta) = 0 then 'nada: todo listo' else array_to_string(v_falta, ' · ') end;
  -- (¿el cierre de esta base ya mira la nómina por esta capa? El c9 con sus filas 180 a 183 lo pide; el de antes no.)
  return query select 'siguiente paso'::text,
                      case when to_regprocedure('public.fn_cierre_revisar(text)') is not null
                                and not exists (select 1 from pg_proc p
                                                 where p.oid = to_regprocedure('public.fn_cierre_revisar(text)')
                                                   and p.prosrc like '%fn_nomina_cierre%')
                           then 'El cierre de esta base todavía no mira la nómina (no trae las filas 180 a 183): eso llega con el '
                                'docs/conta/c9-cierre.sql que las nombra en su cabecera. Si el que tienes las nombra, vuelve a pegarlo; si '
                                'no, no pasa nada: la nómina funciona sin él, y solo faltan sus filas en la lista del cierre. Ahora, '
                           else '' end ||
                      'pega docs/conta/c15-pruebas.sql; en la app, Contabilidad → Nómina: sube el «Payroll journal» de cada nómina (CSV), '
                      'di quién es cada persona una vez, mira el reparto, postéala y casa sus cargos de Gusto del banco.'::text;
end $$;
revoke execute on function public.fn_nomina_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_nomina_pegado() is 'c15: lo que enseña el final del pegado (nueve filas): la configuración, el mapeo de columnas, las tablas y las vistas, el puente al libro, los cargos de Gusto del banco, el control, qué falta y el paso siguiente. Sin API.';

select * from public.fn_nomina_pegado();
