-- =====================================================================
-- c10-pruebas.sql — el jornal repartido por horas y el costo por obra se
-- prueban a sí mismos (c10-costo-obra.sql). 9-nov-2026; 10-nov-2026: las
-- pruebas 48 a 57, una por cada hallazgo de las dos revisiones (v2 de la
-- capa), y el cierre de la suite pasa a ser 58, 59 y 60. 13-nov-2026 (la
-- Fase 11b, v3 de la capa): las pruebas 62, 63 y 64 (las horas que pagó una
-- nómina), y la 20 y la 39 valen también en un mes con nómina. 13-nov, los
-- arreglos de la verificación de la Fase 11b (la capa no cambia): la 20 y
-- la 39 valen también en un mes con nómina QUE CONSERVA SU DEVENGO (con el
-- c3 de la Fase 11b es lo normal: salían «omitida»), y la 59 ya no falla
-- cuando el mes de sus horas está devengado (fallaba los primeros días de
-- cada mes, con el anterior devengado y sin cerrar: aprobar una hora de un
-- mes devengado deja viejo su devengo, y eso lo dice c3, no es de c10).
-- 14-nov-2026 (la Fase 11c, v4 de la capa: dos textos): el c3 de esa fase
-- aparta del devengo las horas que pagó un jornal y lo pone al día solo. La
-- 20 mira el texto del aviso que toca según el c3 de la base (con el nuevo,
-- «se pone al día solo»; con el de antes, «saldría dos veces»); la 39 y la
-- 55 DEVENGAN ANTES DE REPARTIR (con el c3 nuevo, devengar después ya no
-- cuenta esas horas: salían «omitida», o en rojo con más horas aprobadas en
-- el mes), y la 55 cierra el mes con la guarda del cierre de c3 sin efecto
-- dentro de la prueba (ese c3 ya no deja cerrar un mes así; se cambia su
-- función por una que deja pasar, «create or replace», sin apagar ningún
-- trigger ni pedirle nada más a periodos), y pide periodos con un tope de
-- medio segundo: si la app la tiene, sale «omitida». Las tres valen con los
-- dos c3. Y LA MARCA DE PRUEBA DE LA NÓMINA (la 62, la 63 y la 64) se pone
-- encima de la de verdad, sin borrarla: si algo de la base depende de ella
-- (una vista), ya no salen en rojo (2BP01); corren igual, y la 64, que
-- tiene que quitarla, sale «omitida» con ese porqué. Y LOS ARREGLOS DE LA
-- VERIFICACIÓN DE ESA FASE (14-nov; la capa no cambia): la 30 probaba el
-- freno del banco con un Zelle cuya descripción dice PAYROLL, que c6 tomaba
-- por un débito de nómina. Con el c6 de esos arreglos UN ZELLE NUNCA ES DE
-- NÓMINA (lo escribe una persona; Gusto no paga por Zelle), así que la 30
-- prueba el freno con un débito que NO es un Zelle, y además que ese Zelle
-- —el jornal de la semana pagado por Zelle con «payroll» en su nota— ya no
-- se frena: entra por el jornal sin motivo. (Lo que
-- esta suite no puede ver con sus pocas horas —que el costo por obra
-- aguanta años de horas, y de horas pagadas por nómina, dentro del tope de
-- la API— lo mira el banco: pruebas/conta/c10-volumen.sh.)
-- 15-nov-2026 (v5 de la capa: LA CUADRILLA, SOLA): las pruebas 65 a 82. Los
-- Zelle a la cuadrilla entran solos al libro y un cheque pregunta de quién
-- es (lo decidió Edgar). Cada una mira una cosa: el alta sola, lo ambiguo,
-- el registro solo, cada aviso que lo frena (tres pruebas), el deshacer que
-- no vuelve, el cheque, «no es de la cuadrilla», los dos teléfonos, la IA,
-- la tarea sin pantalla, el 1099, el devengo de c3, lo apagado, la obra
-- terminada o sin aprobar que NO frena (la 80: se decidió con la Bandeja
-- de verdad delante), lo que encontró la revisión de la v5 (la 81: la rutina
-- avanza siempre, y registra en nombre de alguien), y que nada
-- queda (la 82). Y se pusieron al día las que cuentan lo que la capa crea (la 1, la
-- 3, la 4, la 5, la 34, la 58, la 60 y la 62: una tabla, una vista y nueve
-- funciones más, y una fila más en el pegado). LO QUE CAMBIA EN CÓMO SE
-- PRUEBA: la rutina que registra sola mira TODO lo pendiente de la Bandeja;
-- para que una prueba no reparta (ni dentro de su subtransacción) un pago de
-- verdad, cada una aparca primero lo real (pg_temp.c10_aparcar: las personas
-- reales del jornal de baja, las que la base daría de alta sola también, y
-- lo dicho de los cheques reales sin persona): se deshace con la prueba. Y
-- sus pagos van de lunes a miércoles (pg_temp.c10_ds): pagan la semana
-- anterior, que ya terminó (la rutina no registra un pago cuya semana no ha
-- terminado). Lo de verdad a la vez (dos sesiones llamando a la rutina en el
-- mismo instante) lo corre el banco: pruebas/conta/c10-concurrencia.sh.
--
-- CÓMO SE CORRE. En el SQL Editor de Supabase: DESPUÉS de c10-costo-obra.sql,
-- pegar este archivo entero → Run. Sale la tabla _pruebas: 82 filas, todas
-- con ok = true (las que salen «omitida» dicen por qué y no son un fallo).
-- Si el editor se cansa antes del final, la corrida sigue en el servidor y
-- se lee después en pruebas.c10_resultado (ver el final).
-- En el banco de pruebas (Postgres 17 en el puerto 5433, con la cadena
-- c1..c9 y c10-costo-obra.sql):
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/c10-pruebas.sql
--
-- Cada prueba escribe dentro de una subtransacción y lo deshace (MXT00):
-- nada queda (ni las personas de prueba, ni sus horas, ni los movimientos
-- del banco, ni los asientos, ni los repartos); la 58 lo comprueba. Ningún
-- aviso sale al teléfono: lo que una hora nueva encola (fn_avisar_horas) se
-- deshace con ella, como en c3-pruebas y c8-pruebas.
--
-- VALEN CON DATOS REALES, SIN SUPONER NADA DE PRODUCCIÓN. Lo que siembran es
-- suyo y se deshace:
--   · TRES PERSONAS DE PRUEBA («Zzana C10 PRUEBA», «Zzbeto…», «Zzcaro…»:
--     nombres que nadie de la cuadrilla lleva), con su usuario en auth.users,
--     su perfil (rol campo) y su tarifa (25, 24 y ninguna). Ninguna prueba
--     usa a una persona real ni sus horas. Si la base no deja crear usuarios
--     de prueba (un trigger de auth.users que pida más datos), las pruebas
--     que los necesitan salen «omitida» y dicen qué dijo la base.
--   · DOCE OBRAS DE PRUEBA («C10 PRUEBA Obra A»…«L», ids c10-prueba-a…l),
--     con sus estados (en ejecución, terminada, cancelada, en pausa,
--     aprobada, estimando).
--   · SUS HORAS, con ids negativos (−1010000001…): no gastan la secuencia.
--   · SUS MOVIMIENTOS DEL BANCO, como los trae Plaid (fn_banco_importar_filas
--     en nombre del dueño, y «Casar» SOLO para ese movimiento:
--     fn_banco_casar), con la descripción «Zelle payment to C10 PRUEBA
--     ZZANA…»: ningún patrón real casa con ella. Las personas REALES cuyo
--     patrón casara con un movimiento de prueba se aparcan (de baja) dentro
--     de la prueba.
--   · El día del pago es hace tres días (o el día 1 del mes, como
--     c8-pruebas: un mes abierto), y las horas van en las dos semanas
--     anteriores a la de ese día.
-- Lo real que cambia un resultado se respeta: las pruebas miran SUS filas
-- (su movimiento, su reparto, sus obras), no «la primera fila» de una
-- vista; los controles ajenos (c2, c3, c4, c6, c8, c9) se comparan con cómo
-- estaban justo antes (lo que ya estaba en rojo se dice y no se cuenta). La
-- 27 (un pago de un mes ya cerrado) cierra dentro de su subtransacción la
-- apertura y el mes abierto más viejo que ya terminó, como c2-pruebas (toma
-- «lock table periodos in exclusive mode»); si el libro real no deja cerrar
-- (su apertura sin cuadrar…), sale «omitida» con lo que dijo c2.
--
-- Lo que mira, una prueba cada una:
--  1 el pegado (precondiciones, 6 tablas, 7 vistas, las 48 funciones por su
--    nombre exacto, la configuración, cada objeto con su comentario «c10: …»);
--  2 las precondiciones en rojo (desde la app; sin una función de c6; una
--    función con nombre de c10 que no es de c10; una vista ajena colgada);
--  3 la API: anon y service_role nada; el equipo 42501 y cero filas en las
--    tablas, las vistas y las auxiliares; el dueño entra y ve;
--  4 el catálogo: nada SECURITY DEFINER, ningún prefijo de otra capa ni de la
--    otra sesión, RLS y policies justas, vistas security_invoker que no
--    fijan columnas de c2 ni cuelgan de vistas de otras capas, nada que
--    nombre objetos de la otra sesión; «permisos» (c2), «protecciones del
--    banco» (c6) y «protecciones de c4» en verde con c10 pegado;
--  5 la guarda de las tablas (a mano, MX003: también el dueño por la API);
--  6 fn_jornal_config y sus frenos;
--  7 fn_jornal_persona (alta, patrón, cuenta, baja, el dueño no) y
--    v_jornal_personas;
--  8 EL NÚCLEO: la suma es el monto, al centavo, con 1, 2, 7 y 12 grupos,
--    montos que no dividen y horas con decimales;
--  9 el núcleo: los mayores restos y sus desempates, a mano; determinista;
-- 10 el núcleo: con CO, con horas sin obra, sin horas, montos mal, y por
--    persona y período;
-- 11 la regla del período: cada día de la semana;
-- 12 el cambio de hora y el fin de año (y la zona horaria de la sesión);
-- 13 las fechas a mano y sus frenos;
-- 14 la propuesta reconoce por el patrón y solo a los dados de alta (la
--    nota del banco, la baja, dos personas que casan);
-- 15 no es un abono, ni un movimiento resuelto, ni uno que no existe;
-- 16 lo que trae la propuesta (líneas, detalle, las dos semanas, la tarifa
--    que sale, la huella: estable, y cambia con las horas);
-- 17 los avisos: sin horas, la tarifa lejos (umbral configurable), sin tarifa;
-- 18 los avisos: obra terminada o no aprobada, obra sin aprobar, falta la
--    cuenta de lo sin obra, una cuenta que ya no sirve;
-- 19 los avisos: horas ya cubiertas, se pisa con otro reparto, «es otro pago
--    de las mismas horas», fechas posteriores al pago;
-- 20 los avisos: posible duplicado sin decidir y devengo estándar en el mes
--    (también en un mes con nómina: ver «EL DEVENGO DE LAS PRUEBAS 20 Y 39»);
-- 21 la propuesta pendiente de la IA (c8) se devuelve y nada de c8 se rompe
--    (lo que un jornal deja abierto en c8, entero, en la 51);
-- 22 APLICAR: el asiento (N líneas con su obra, su CO y la persona, contra
--    el banco; el movimiento casado), el reparto y su detalle guardados;
-- 23 aplicar aprueba las horas por el camino de c3 (con lo que Edgar vio);
-- 24 la huella cambiada → MX011 y NADA cambia;
-- 25 dos veces → la segunda falla limpia; y sus frenos de entrada;
-- 26 más de 5 obras (7) y 12 grupos en un asiento;
-- 27 un pago de un mes ya cerrado → entra el primer día del mes abierto;
-- 28 la obra terminada y la no aprobada reciben su parte;
-- 29 las horas sin obra: sin cuenta no se aplica; con ella, a su cuenta;
-- 30 los frenos del banco valen (un débito que c6 toma por nómina: MX008 y
--    nada cambia; con el motivo de Edgar, entra);
-- 31 DESHACER: el reverso, el movimiento vuelve, el reparto marcado, la
--    aprobación se queda; dos veces no;
-- 32 volver a aplicar con otras fechas;
-- 33 des-casado por fuera (en la Bandeja): el control lo ve, la propuesta
--    lo dice, y fn_jornal_deshacer lo cierra;
-- 34 v_jornal_pendientes, v_jornal_repartos (lo que la pantalla pinta);
-- 35 el control 10 (el reparto es su asiento) en rojo y de vuelta;
-- 36 el control 25 (deshecho con su asiento vivo) en rojo y de vuelta;
-- 37 el control 30 (las horas cambiaron) en rojo y de vuelta;
-- 38 el control 40 (una hora en dos repartos sin aceptarlo);
-- 39 el control 50 (la misma hora en el devengo estándar de un mes y en un
--    jornal que entró al libro ese mes; también en un mes con nómina);
-- 40 el control 60 (dos personas casan con un pago; una cuenta que no sirve);
-- 41 el control 90 (las protecciones de la capa);
-- 42 EL MARGEN: una obra con material, jornales, un subcontrato de verdad
--    en 5200, equipo, otro costo, un CO y su factura: cada columna contra el
--    libro, al centavo, y cada «bajar» suma su cifra;
-- 43 la mano de obra real contra la estándar (sin burden, con burden, una
--    persona sin tarifa, las horas del dueño, las de antes del libro);
-- 44 el estimado (sin estimado enlazado: el escenario B; con él: el suyo y
--    sus beneficios; el convertido antes que el más nuevo);
-- 45 la obra que ya andaba antes del libro sale parcial, y lo dice;
-- 46 el detalle de una obra: por CO, por fase, por cost code (o que no
--    hay), la cobertura y los repartos; los pagos sin repartir;
-- 47 v_margen_control (verde; y en rojo cuando un reparto no es su asiento);
-- Lo que las dos revisiones encontraron (v2), una prueba por hallazgo:
-- 48 un estimado parcial no se compara con un real completo (costo_estimado
--    vacío, estimado_completo y estimado_falta);
-- 49 las horas que llegan tarde a una semana ya repartida (el control 35, la
--    obra y la propuesta del pago siguiente);
-- 50 el pago de una persona dada de alta resuelto fuera del jornal (el
--    control 70 y las obras con horas suyas);
-- 51 lo de la IA (c8) que un jornal deja abierto: la pendiente y la aprobada
--    cuyo asiento se reversó (propuestas_ia, fn_jornal_ia y el control 80);
-- 52 la huella cubre exactamente lo que el «Así es» aprueba (una hora
--    cubierta que cambia entre medias: MX011);
-- 53 el CO y la fase, limpios como los deja c6 (un salto de línea, un
--    tabulador); los CO parecidos se avisan; y el MX001 dice qué línea y qué
--    campo;
-- 54 el devengo de un mes y el jornal pagado al siguiente no chocan;
-- 55 el doble de verdad, en rojo mientras el mes está abierto; cerrado, se
--    dice y no se queda en rojo;
-- 56 el reconocimiento por patrón se avisa (un Zelle a cualquiera no entra;
--    la compra en un comercio; el patrón sin el nombre de pila) y la cuenta
--    de lo sin obra no es cualquier gasto;
-- 57 lo menor: el corte de mes y de año, la nota de aplicar, el núcleo con
--    solo las horas aprobadas, y los textos sin nombres de función;
-- Y el cierre:
-- 58 nada queda al deshacer;
-- 59 con jornales aplicados, deshechos y vueltos a aplicar, NINGÚN control
--    de c2, c3, c4, c6, c8 ni c9 pasa a rojo;
-- 60 el cierre de la suite: c2, c3, c6 y c4 como estaban, c8 sin cuadres
--    rojos, nada de c10 en la API de anon o service_role ni SECURITY
--    DEFINER; y fn_jornal_pegado responde (pegar dos veces no hace daño: lo
--    corre el banco);
-- 61 el cierre (c9) mira la mano de obra repartida (sus filas 170 y 171).
-- La Fase 11b (v3 de la capa): las horas que pagó una nómina (c15):
-- 62 tienen pago real y no van, además, a estándar: con el burden estándar
--    sin fijar, en 0 y en 12.5 la mano de obra cuenta una vez; con el código
--    del teléfono y sin él; la obra, el detalle y el cuadre 70 lo dicen; y a
--    quien cobra por nómina no se le pide darse de alta en el jornal;
-- 63 lo que dice «sin pago» en el jornal: el aviso de la propuesta
--    (pagadas_por_nomina), las «sin pago» de la semana y de la persona, los
--    pagos sin repartir, las horas tardías (35) y los pagos resueltos por
--    fuera (70);
-- 64 con las nóminas de verdad de la base (si las hay): cada hora que su
--    marca da por pagada sale con pago real, con el código y sin él; y el
--    cuadre 70 en verde, con qué pegar, y en rojo.
-- La cuadrilla, sola (v5 de la capa, 15-nov-2026):
-- 65 EL ALTA SOLA: la base da de alta sola a quien tiene horas, por su
--    nombre como palabra entera en la descripción del banco; «no cobra por
--    horas»; ni el dueño ni quien no tiene horas; y si Edgar corrige el
--    patrón, pasa a ser suyo;
-- 66 LO AMBIGUO: con un nombre corto, común, que casa con otra persona o con
--    el patrón de alguien, o que el banco escribe en pagos a dos
--    destinatarios, no adivina y lo dice; su Zelle no se reconoce; y ya dada
--    de alta sola, un pago a otro con su nombre hace preguntar a los dos;
-- 67 EL REGISTRO SOLO: el asiento (5200 por obra y CO, la persona como
--    tercero), el movimiento casado, las horas aprobadas por c3, el reparto
--    con su origen y su regla, la misma huella que el «Así es», nada en
--    5000/5001/6000/6005, y otra vez no hace nada;
-- 68 cada aviso que lo frena (a), con pagos de verdad: el posible duplicado,
--    la tarifa lejos, el cargo que no parece un pago, sin horas, sin tarifa,
--    la cuenta de lo sin obra (la obra terminada o sin aprobar ya NO frena:
--    la 80), las horas ya cubiertas; el único que entra, entra, y los demás
--    no se tocan;
-- 69 cada aviso que lo frena (b): LO QUE PUEDE CASAR CON OTRA COSA DEL LIBRO
--    y lo demás que solo sabe el banco (c6, sin motivo): no entra, queda
--    apuntado, no se insiste con lo mismo; con el motivo de Edgar, a mano;
-- 70 cada aviso que lo frena (c): TODOS los avisos de la propuesta (leídos
--    de su código) y uno que no existe frenan, menos el corte de mes, el de
--    año, el devengo que c3 pone al día solo y la obra terminada, no
--    aprobada o sin aprobar; lo que no se puede aplicar;
--    la semana sin terminar ESPERA; la semana anterior sin pago; y la
--    persona que ya cobra por nómina;
-- 71 EL DESHACER QUE NO VUELVE: lo que Edgar deshizo (o des-casó) no vuelve
--    a entrar solo hasta que él lo pida, y deshecho otra vez, otra vez no;
-- 72 EL CHEQUE: nadie lo reconoce, pregunta de quién es; «es de…» lo reparte
--    y lo registra en la misma llamada; queda escrito de quién era; el
--    patrón no cambia; si algo pide decidir queda como su tarjeta; quitar;
--    ni el dueño ni un cheque ya resuelto; y cómo se lee su número;
-- 73 «NO ES DE LA CUADRILLA»: queda escrito; el cheque deja de preguntar y
--    el Zelle de reconocerse; el aviso de los pagos resueltos por fuera no
--    lo cuenta; se quita; una cosa por llamada; solo el dueño;
-- 74 LOS DOS TELÉFONOS en una sesión: los candados de la corrida, el «Así
--    es» de un pago que la rutina acaba de registrar (MX008, nada doble), el
--    cheque ya resuelto desde el otro teléfono, y lo aceptado a mano;
-- 75 LA IA (c8): la propuesta de una sola obra de un pago que se registra
--    solo se devuelve a la pantalla (c10 no escribe en c8) o, sin pantalla,
--    queda rechazada o caducada por la puerta de c8, con su porqué; la de un
--    pago que espera no se toca;
-- 76 LA RONDA, la tarea sin pantalla: por la API no existe; corre en nombre
--    del dueño solo dentro de su transacción; apunta cómo terminó; el
--    control 85 y la ronda del cierre lo dicen; nunca falla hacia fuera;
-- 77 EL 1099 (c14) cuenta lo que entró solo (el Zelle y el cheque) como el
--    pago por servicios de esa persona; deshecho, deja de contar;
-- 78 EL DEVENGO DE c3 se pone al día al confirmar lo que entró solo (también
--    la tarea sin pantalla) y al deshacerlo; con un c3 anterior, el aviso
--    frena;
-- 79 LO APAGADO: nada entra solo, ni la tarea; el «Así es» sigue; el control
--    lo dice; encendido otra vez, entra, y la regla dice quién la encendió;
-- 80 LA OBRA TERMINADA, NO APROBADA O SIN APROBAR NO FRENA (se decidió con
--    la Bandeja de verdad delante: las obras se terminan después del
--    trabajo): un pago cuya semana tiene horas en una obra terminada y en
--    otra «enviado» entra solo, su parte va a esas obras, y la nota va con
--    lo registrado y queda en el reparto. Lo que sí pregunta: horas con
--    fecha POSTERIOR al día en que su obra se dio por terminada (¿una vuelta
--    de garantía o la obra equivocada?); no una obra reabierta, ni una
--    terminada sin su día de término;
-- 81 LO QUE ENCONTRÓ LA REVISIÓN DE LA v5: la rutina AVANZA SIEMPRE (cuando
--    corta por reloj dice por dónde —«sigue»— y la llamada siguiente sigue
--    después —«despues_de»—: muchos pagos viejos que preguntan ya no tapan
--    al que entra) y registra EN NOMBRE DE ALGUIEN (desde el SQL Editor sin
--    sesión, ni la rutina ni lo que se dice de un pago: 42501, y nada cambia);
-- 82 nada queda, otra vez (lo de la 58, después de las pruebas 65 a 81).
-- Última sentencia: select * from _pruebas order by n;
-- =====================================================================
create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- Lo común: quién es quién, el día del pago, las semanas de las horas.
create temp table if not exists _c10 (k text primary key, v text);
truncate _c10;
insert into _c10
select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _c10 values
  ('p1', '00000000-0000-4000-a000-0000000c1001'),   -- Zzana C10 PRUEBA  (tarifa 25)
  ('p2', '00000000-0000-4000-a000-0000000c1002'),   -- Zzbeto C10 PRUEBA (tarifa 24)
  ('p3', '00000000-0000-4000-a000-0000000c1003'),   -- Zzcaro C10 PRUEBA (sin tarifa)
  ('banco', '1010');
insert into _c10 values ('hoy', fn_fecha_miami(now())::text);
-- el día del pago: hace tres días o el día 1 del mes (un mes abierto, como c8-pruebas)
insert into _c10 values ('d', greatest(fn_fecha_miami(now()) - 3, date_trunc('month', fn_fecha_miami(now()))::date)::text);
-- el lunes de la semana del pago; las horas van en las dos semanas anteriores
insert into _c10
select 'lunes', (x.d - (extract(isodow from x.d)::int - 1))::text from (select (select v from _c10 where k = 'd')::date as d) x;
insert into _c10 values ('libro_desde', fn_margen_libro_desde()::text);
insert into _c10
select 'mes_d', p.periodo from periodos p where p.tipo = 'mes' and (select v from _c10 where k = 'd')::date between p.desde and p.hasta;
insert into _c10 values ('hay_c8', (to_regclass('public.contador_propuestas') is not null)::text);
insert into _c10 values ('hay_c9', (to_regprocedure('public.fn_cierre_revisar(text)') is not null)::text);
-- (la «corrida» de la nómina de prueba de las pruebas 62 a 64: un identificador que ninguna corrida de verdad lleva)
insert into _c10 values ('corrida', '00000000-0000-4000-a000-0000000c10ff');
grant select on _c10 to public;  -- las pruebas cambian de rol y siguen leyendo lo común

-- El control de c4 sin tope por reloj para la sesión (como c8 y c9), y
-- ningún aviso al teléfono desde la ronda de c9 si algo la despierta.
do $$
begin
  perform set_config('c4.control_tope', '0', false);
  perform set_config('mxp.cierre_sin_push', '1', false);
end $$;

create or replace function pg_temp.c10(k text) returns text language sql as $$ select v from _c10 where k = $1 $$;
-- las fechas de las pruebas: el día del pago, el lunes de su semana, y las
-- dos semanas de trabajo anteriores (w1: la anterior; w2: la de antes)
create or replace function pg_temp.c10_d() returns date language sql as $$ select pg_temp.c10('d')::date $$;
create or replace function pg_temp.c10_w1(p_dia int default 0) returns date language sql as $$ select pg_temp.c10('lunes')::date - 7 + p_dia $$;
create or replace function pg_temp.c10_w2(p_dia int default 0) returns date language sql as $$ select pg_temp.c10('lunes')::date - 14 + p_dia $$;

-- Las funciones que crea c10-costo-obra.sql, por su nombre exacto (las 48:
-- las 39 de siempre y las 9 de la cuadrilla sola, v5 del 15-nov-2026).
-- No se buscan por prefijo: otra sesión escribe esta misma base.
create or replace function pg_temp.c10_es_suya(p_nombre text) returns boolean language sql immutable as $$
  select p_nombre = any (array[
    'fn_jornal_exigir_dueno', 'fn_jornal_ve', 'fn_jornal_precondiciones', 'fn_jornal_guarda', 'fn_jornal_usd',
    'fn_jornal_h', 'fn_jornal_dia', 'fn_jornal_rango', 'fn_jornal_mes', 'fn_jornal_texto', 'fn_jornal_limpio',
    'fn_jornal_patron_mal', 'fn_jornal_destinatario', 'fn_jornal_patron_sugerido', 'fn_jornal_cuenta_mal',
    'fn_jornal_periodo', 'fn_jornal_regla', 'fn_jornal_repartir_ids', 'fn_jornal_repartir', 'fn_jornal_tardias',
    'fn_jornal_fuera', 'fn_jornal_ia', 'fn_jornal_opciones', 'fn_jornal_calcular', 'fn_jornal_propuesta', 'fn_jornal_aplicar',
    'fn_jornal_deshacer', 'fn_jornal_config', 'fn_jornal_persona', 'fn_jornal_pegado', 'fn_margen_libro_desde',
    'fn_margen_horas_nomina', 'fn_margen_lineas', 'fn_margen_horas', 'fn_margen_estimado', 'fn_margen_obras',
    'fn_margen_bajar', 'fn_margen_obra', 'fn_margen_control',
    'fn_jornal_version', 'fn_jornal_cheque', 'fn_jornal_nombre_patron', 'fn_jornal_nombre_dudas', 'fn_jornal_cuadrilla',
    'fn_jornal_frenos', 'fn_jornal_solo', 'fn_jornal_pago', 'fn_jornal_solo_programado'])
$$;
create or replace function pg_temp.c10_tablas() returns text[] language sql immutable as $$
  select array['jornal_config', 'jornal_personas', 'jornal_repartos', 'jornal_reparto_lineas', 'jornal_reparto_horas', 'jornal_pagos']
$$;
create or replace function pg_temp.c10_vistas() returns text[] language sql immutable as $$
  select array['v_jornal_pendientes', 'v_jornal_repartos', 'v_jornal_personas', 'v_jornal_control', 'v_jornal_cheques', 'v_margen_obra',
               'v_margen_control']
$$;

-- Ser: el SQL Editor (editor: sin rol ni sesión), el dueño o una persona de
-- prueba por la API (authenticated, en aal2), anon o service_role.
create or replace function pg_temp.c10_ser(quien text) returns void language plpgsql as $$
begin
  execute 'reset role';
  if quien = 'editor' then
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claim.sub', '', true);
  elsif quien in ('service_role', 'anon') then
    perform set_config('request.jwt.claims', json_build_object('role', quien)::text, true);
    perform set_config('request.jwt.claim.sub', '', true);
    execute format('set local role %I', quien);
  else
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c10(quien), 'role', 'authenticated', 'aal', 'aal2')::text, true);
    perform set_config('request.jwt.claim.sub', coalesce(pg_temp.c10(quien), ''), true);
    execute 'set local role authenticated';
  end if;
end $$;

-- SEMBRAR (como el SQL Editor; se deshace con la prueba): las tres personas
-- de prueba con su usuario, su perfil y su tarifa, y las doce obras.
create or replace function pg_temp.c10_sembrar() returns void language plpgsql as $$
declare
  r      record;
  v_meta boolean := exists (select 1 from information_schema.columns
                             where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_user_meta_data');
begin
  perform pg_temp.c10_ser('editor');
  for r in select * from (values ('p1', 'Zzana C10 PRUEBA'), ('p2', 'Zzbeto C10 PRUEBA'), ('p3', 'Zzcaro C10 PRUEBA')) as t(k, nombre) loop
    if v_meta then
      execute format('insert into auth.users (id, email, raw_user_meta_data) values (%L, %L, %L::jsonb) on conflict (id) do nothing',
                     pg_temp.c10(r.k), 'c10-' || r.k || '@c10-pruebas.invalid',
                     json_build_object('nombre', r.nombre, 'name', r.nombre, 'full_name', r.nombre)::text);
    else
      execute format('insert into auth.users (id, email) values (%L, %L) on conflict (id) do nothing',
                     pg_temp.c10(r.k), 'c10-' || r.k || '@c10-pruebas.invalid');
    end if;
    insert into perfiles (id, nombre, rol, activo) values (pg_temp.c10(r.k)::uuid, r.nombre, 'campo', true)
    on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
  end loop;
  insert into costos_equipo (usuario_id, costo_hora) values (pg_temp.c10('p1')::uuid, 25), (pg_temp.c10('p2')::uuid, 24)
  on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
  delete from costos_equipo where usuario_id = pg_temp.c10('p3')::uuid;
  insert into proyectos (id, tipo, nombre, estado) values
    ('c10-prueba-a', 'comercial',   'C10 PRUEBA Obra A', 'ejecucion'),
    ('c10-prueba-b', 'residencial', 'C10 PRUEBA Obra B', 'ejecucion'),
    ('c10-prueba-c', 'servicio',    'C10 PRUEBA Obra C', 'completado'),
    ('c10-prueba-d', 'servicio',    'C10 PRUEBA Obra D', 'no_aprobado'),
    ('c10-prueba-e', 'comercial',   'C10 PRUEBA Obra E', 'pausa'),
    ('c10-prueba-f', 'comercial',   'C10 PRUEBA Obra F', 'aprobado'),
    ('c10-prueba-g', 'residencial', 'C10 PRUEBA Obra G', 'estimando'),
    ('c10-prueba-h', 'servicio',    'C10 PRUEBA Obra H', 'ejecucion'),
    ('c10-prueba-i', 'servicio',    'C10 PRUEBA Obra I', 'ejecucion'),
    ('c10-prueba-j', 'servicio',    'C10 PRUEBA Obra J', 'ejecucion'),
    ('c10-prueba-k', 'servicio',    'C10 PRUEBA Obra K', 'ejecucion'),
    ('c10-prueba-l', 'servicio',    'C10 PRUEBA Obra L', 'ejecucion');
end $$;

-- ¿Se puede sembrar en esta base? Se prueba UNA vez, antes de todo, y se
-- deshace. Si no (auth.users no deja), las pruebas que siembran salen
-- «omitida» con lo que dijo la base.
do $$
declare
  v text := 'ok';
begin
  begin
    perform pg_temp.c10_sembrar();
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v := sqlstate || ': ' || sqlerrm;
  end;
  insert into _c10 values ('siembra', v);
end $$;
-- (la fila «omitida» de una prueba que no puede sembrar; devuelve true si la puso)
create or replace function pg_temp.c10_omitir(p_n int, p_prueba text, p_esperado text) returns boolean language plpgsql as $$
begin
  if pg_temp.c10('siembra') = 'ok' then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado,
    'omitida: esta base no deja crear las personas de prueba (' || left(pg_temp.c10('siembra'), 300) || ')', null);
  return true;
end $$;

-- Un reporte de horas de una persona de prueba (como el SQL Editor), con su
-- id negativo. p_n: 1, 2, 3… dentro de la prueba.
create or replace function pg_temp.c10_hora(p_n int, p_quien text, p_fecha date, p_obra text, p_horas numeric,
                                            p_co text default null, p_fase text default null)
returns bigint language sql as $$
  insert into horas (id, fecha, usuario_id, proyecto_id, fase, horas, co, notas) overriding system value
  values (-(1010000000 + p_n), p_fecha, pg_temp.c10(p_quien)::uuid, p_obra, p_fase, p_horas, p_co, 'c10-pruebas')
  returning id
$$;

-- Un movimiento del banco como lo trae Plaid (en nombre del dueño) y
-- «Casar» solo para él: sin ticket ni asiento que lo explique, queda
-- pendiente en la Bandeja. p_monto en positivo = lo que salió (un Zelle);
-- en negativo, un abono. La descripción lleva «C10 PRUEBA». Devuelve el
-- movimiento. Las personas REALES cuyo patrón casaría con él se aparcan (de
-- baja, con la marca de la guarda): se deshace con la prueba.
create or replace function pg_temp.c10_cargo(p_id text, p_fecha date, p_monto numeric, p_desc text, p_memo text default null)
returns uuid language plpgsql as $$
declare
  v_mov uuid;
  v_txt text;
begin
  if p_desc !~ 'C10 PRUEBA' then
    raise exception 'c10-pruebas: la descripción de un movimiento de prueba lleva «C10 PRUEBA» (%)', p_desc;
  end if;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c10('dueno'), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.c10('dueno'), true);
  perform fn_banco_importar_filas(jsonb_build_object(
    'origen', 'plaid', 'cuenta', pg_temp.c10('banco'), 'nombre', 'Plaid · c10-pruebas · ' || p_id,
    'filas', jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
               'id', p_id, 'fecha', p_fecha::text, 'plaid_monto', p_monto::text, 'descripcion', p_desc, 'memo', p_memo,
               'tipo', case when p_monto < 0 then 'CREDIT' else 'DEBIT' end, 'pendiente', false)))));
  select m.id into v_mov from movimientos_banco m where m.id_externo = p_id order by m.importado_el desc limit 1;
  perform fn_banco_casar(v_mov);
  perform pg_temp.c10_ser('editor');
  select fn_jornal_texto(m.desc_norm, m.memo) into v_txt from movimientos_banco m where m.id = v_mov;
  perform set_config('mx_jornal.escribe', 'jornal_personas', true);
  update jornal_personas jp set activa = false
   where jp.activa and jp.usuario_id not in (pg_temp.c10('p1')::uuid, pg_temp.c10('p2')::uuid, pg_temp.c10('p3')::uuid)
     and v_txt ~* jp.patron;
  perform set_config('mx_jornal.escribe', '', true);
  return v_mov;
end $$;

-- Como el dueño por la API: dar de alta a una persona de prueba con su
-- patrón, pedir la propuesta, y «Así es» (la propuesta y, con su huella,
-- aplicar). Al volver, otra vez el SQL Editor.
create or replace function pg_temp.c10_alta(p_quien text, p_patron text default null) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  r := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10(p_quien),
         'patron', coalesce(p_patron, case p_quien when 'p1' then '\mPRUEBA ZZANA\M' when 'p2' then '\mPRUEBA ZZBETO\M'
                                                   else '\mPRUEBA ZZCARO\M' end)));
  perform pg_temp.c10_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c10_propuesta(p_mov uuid, p_desde date default null, p_hasta date default null,
                                                 p_op jsonb default '{}'::jsonb)
returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  r := fn_jornal_propuesta(p_mov, p_desde, p_hasta, p_op);
  perform pg_temp.c10_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c10_aplicar(p_mov uuid, p_desde date, p_hasta date, p_op jsonb default '{}'::jsonb)
returns jsonb language plpgsql as $$
declare
  v jsonb;
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  v := fn_jornal_propuesta(p_mov, p_desde, p_hasta, p_op);
  r := fn_jornal_aplicar(p_mov, p_desde, p_hasta, v->>'visto', p_op);
  perform pg_temp.c10_ser('editor');
  return r;
end $$;
-- Edgar corrige un reporte de horas en la app (como el dueño por la API: la
-- guarda de correcciones de la app no deja al SQL Editor). p_cambio: lo que
-- va en el SET («horas = 7», «proyecto_id = 'c10-prueba-b'»).
create or replace function pg_temp.c10_corregir(p_n int, p_cambio text) returns void language plpgsql as $$
begin
  perform pg_temp.c10_ser('dueno');
  execute format('update public.horas set %s where id = %s', p_cambio, -(1010000000 + p_n));
  perform pg_temp.c10_ser('editor');
end $$;
create or replace function pg_temp.c10_deshacer(p_reparto uuid, p_motivo text) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  r := fn_jornal_deshacer(p_reparto, p_motivo);
  perform pg_temp.c10_ser('editor');
  return r;
end $$;

-- Los códigos de los avisos de una propuesta, en su orden («-» si ninguno).
-- Sin los del CALENDARIO (otro_mes, otro_anio: las horas de un mes y el
-- asiento en otro): dependen del día en que se corre la suite —las horas de
-- prueba van en las dos semanas anteriores a hoy—, y los prueba la 57 con
-- sus propias fechas. c10_avisos_todos los trae todos.
create or replace function pg_temp.c10_avisos(j jsonb) returns text language sql as $$
  select coalesce(string_agg(a.v->>'codigo', ',' order by a.o), '-') from jsonb_array_elements(j->'avisos') with ordinality as a(v, o)
   where a.v->>'codigo' not in ('otro_mes', 'otro_anio')
$$;
create or replace function pg_temp.c10_avisos_todos(j jsonb) returns text language sql as $$
  select coalesce(string_agg(a.v->>'codigo', ',' order by a.o), '-') from jsonb_array_elements(j->'avisos') with ordinality as a(v, o)
$$;
-- ¿trae ese aviso? su texto (nulo si no)
create or replace function pg_temp.c10_aviso(j jsonb, p_codigo text) returns text language sql as $$
  select a->>'texto' from jsonb_array_elements(j->'avisos') a where a->>'codigo' = p_codigo limit 1
$$;
-- Las líneas de una propuesta en una línea: obra[/CO] horas→monto, …
create or replace function pg_temp.c10_lineas(j jsonb) returns text language sql as $$
  select coalesce(string_agg(format('%s%s %s→%s', replace(l->>'proyecto_id', 'c10-prueba-', ''),
                                    coalesce('/' || (l->>'co'), ''), trim_scale((l->>'horas')::numeric), l->>'monto'),
                             ', ' order by (l->>'n')::int), '-')
         || case when jsonb_typeof(j->'sin_obra') = 'object'
                 then format(' + sin obra %s→%s', trim_scale((j->'sin_obra'->>'horas')::numeric), j->'sin_obra'->>'monto') else '' end
    from jsonb_array_elements(j->'lineas') l
$$;
-- Las líneas de un asiento en una línea: orden cuenta monto [obra[/CO]] [persona], …
create or replace function pg_temp.c10_asiento(p_asiento uuid) returns text language sql as $$
  select string_agg(format('%s %s %s%s%s', l.orden, l.cuenta, l.monto,
                           coalesce(' ' || replace(l.proyecto_id, 'c10-prueba-', '') || coalesce('/' || l.co, ''), ''),
                           case when l.tercero_tipo is null then ''
                                else ' ' || l.tercero_tipo || ':' || coalesce((select k from _c10 where v = l.tercero_id), l.tercero_id) end),
                    ' | ' order by l.orden)
    from asiento_lineas l where l.asiento_id = p_asiento
$$;

-- Una fila del control del jornal o del margen: 'verde' o 'rojo: detalle'
create or replace function pg_temp.c10_jc(p_orden int) returns text language sql as $$
  select case when c.ok then 'verde' else 'rojo: ' || c.detalle end from v_jornal_control c where c.orden = p_orden
$$;
create or replace function pg_temp.c10_mc(p_orden int) returns text language sql as $$
  select case when c.ok then 'verde' else 'rojo: ' || c.detalle end from v_margen_control c where c.orden = p_orden
$$;
-- (solo el color)
create or replace function pg_temp.c10_color(p text) returns text language sql immutable as $$ select split_part(p, ':', 1) $$;

-- LA LLAVE «bajar» de c4, sumada contra v_libro (como pg_temp.c4_bajar de
-- c4-pruebas): cada pedazo vale signo × la suma de «campo» en las filas que
-- cumplen sus filtros (col = valor, col en una lista, col nula, col_no).
create or replace function pg_temp.c10_bajar(p_specs jsonb) returns numeric language plpgsql as $$
declare
  e       jsonb;
  f       record;
  v_where text;
  v_col   text;
  v_s     numeric;
  v_tot   numeric := 0;
begin
  if p_specs is null or jsonb_typeof(p_specs) <> 'array' then
    raise exception 'bajar no es una lista: %', p_specs;
  end if;
  for e in select value from jsonb_array_elements(p_specs) loop
    if e->>'vista' <> 'v_libro' then
      raise exception 'bajar a una vista que c10 no usa: %', e->>'vista';
    end if;
    v_where := 'true';
    for f in select key, value from jsonb_each(coalesce(e->'filtros', '{}'::jsonb)) loop
      if f.key like '%\_no' then
        v_col := left(f.key, length(f.key) - 3);
        if jsonb_typeof(f.value) = 'array' then
          v_where := v_where || format(' and x.%I::text <> all (%L::text[])', v_col,
                                       coalesce((select array_agg(t) from jsonb_array_elements_text(f.value) t), '{}'::text[]));
        else
          v_where := v_where || format(' and x.%I::text <> %L', v_col, f.value #>> '{}');
        end if;
      elsif jsonb_typeof(f.value) = 'null' then
        v_where := v_where || format(' and x.%I is null', f.key);
      elsif jsonb_typeof(f.value) = 'array' then
        v_where := v_where || format(' and x.%I::text = any (%L::text[])', f.key,
                                     coalesce((select array_agg(t) from jsonb_array_elements_text(f.value) t), '{}'::text[]));
      else
        v_where := v_where || format(' and x.%I::text = %L', f.key, f.value #>> '{}');
      end if;
    end loop;
    if e ? 'desde' then v_where := v_where || format(' and x.fecha >= %L::date', e->>'desde'); end if;
    if e ? 'hasta' then v_where := v_where || format(' and x.fecha <= %L::date', e->>'hasta'); end if;
    execute format('select coalesce(sum(x.%I), 0) from public.v_libro x where %s', e->>'campo', v_where) into v_s;
    v_tot := v_tot + coalesce((e->>'signo')::int, 1) * v_s;
  end loop;
  return v_tot;
end $$;

-- LO QUE ESTÁ EN ROJO en las otras capas, como una lista («capa: control»):
-- la cadena y «permisos» de c2, los puentes (c3), el banco (c6), los
-- estados (c4), los cuadres de la IA (c8, si está) y lo que detiene el
-- cierre del mes del pago (c9, si está). Como el SQL Editor.
create or replace function pg_temp.c10_rojos() returns text[] language plpgsql as $$
declare
  v text[] := '{}';
  x text[];
begin
  perform pg_temp.c10_ser('editor');
  select coalesce(array_agg('c2: ' || k.control order by k.control), '{}') into x from fn_verificar_cadena() k where not k.ok;
  v := v || x;
  select coalesce(array_agg('c3: ' || k.control order by k.control), '{}') into x from fn_puentes_verificar() k where not k.ok;
  v := v || x;
  select coalesce(array_agg('c6: ' || k.vista order by k.vista), '{}') into x from fn_banco_control('hoy') k where not k.ok;
  v := v || x;
  select coalesce(array_agg('c4: ' || k.vista order by k.vista), '{}') into x from fn_estados_control('hoy') k where not k.ok;
  v := v || x;
  if pg_temp.c10('hay_c8') = 'true' then
    execute $q$ select coalesce(array_agg('c8: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into x;
    v := v || x;
  end if;
  if pg_temp.c10('hay_c9') = 'true' and pg_temp.c10('mes_d') is not null then
    execute $q$ select coalesce(array_agg('c9: ' || k.orden || ' ' || k.control order by k.orden), '{}')
                  from public.fn_cierre_revisar($1) k where k.nivel = 'detiene' and k.ok is distinct from true $q$
       into x using pg_temp.c10('mes_d');
    v := v || x;
  end if;
  return v;
end $$;
-- (lo nuevo: lo que está en p_ahora y no estaba en p_antes; «ninguno» si nada)
create or replace function pg_temp.c10_nuevos(p_antes text[], p_ahora text[]) returns text language sql as $$
  select coalesce(string_agg(x, '; ' order by x), 'ninguno') from unnest(p_ahora) x where x <> all (p_antes)
$$;

-- LOS CONTROLES DE c10 que YA estaban en rojo antes de las pruebas (con datos
-- reales puede haberlos: una hora real que cambió después de su reparto…).
-- Las pruebas cuentan lo NUEVO; y la que pone un cuadre en rojo y lo
-- devuelve a verde sale «omitida» si ese cuadre ya estaba en rojo.
insert into _c10 select 'jc_rojos', coalesce(string_agg(k.orden::text, ',' order by k.orden), '') from v_jornal_control k where not k.ok;
insert into _c10 select 'mc_rojos', coalesce(string_agg(k.orden::text, ',' order by k.orden), '') from v_margen_control k where not k.ok;
-- «control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo»
create or replace function pg_temp.c10_propios() returns text language sql as $$
  select format('control del jornal: %s en rojo; del margen: %s en rojo',
                (select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'nada nuevo') from v_jornal_control k
                  where not k.ok and k.orden::text <> all (string_to_array(pg_temp.c10('jc_rojos'), ','))),
                (select coalesce(string_agg(k.orden::text, ',' order by k.orden), 'nada nuevo') from v_margen_control k
                  where not k.ok and k.orden::text <> all (string_to_array(pg_temp.c10('mc_rojos'), ','))))
$$;
-- (la fila «omitida» de una prueba cuyo cuadre ya estaba en rojo con datos reales; true si la puso)
create or replace function pg_temp.c10_omitir_rojo(p_n int, p_prueba text, p_esperado text, p_cual text, p_ordenes int[]) returns boolean
language plpgsql as $$
declare
  v text;
begin
  select string_agg(o::text, ', ' order by o) into v
    from unnest(p_ordenes) o
   where o::text = any (string_to_array(pg_temp.c10(case p_cual when 'jornal' then 'jc_rojos' else 'mc_rojos' end), ','));
  if v is null then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado,
    format('omitida: el control %s del %s ya estaba en rojo antes de las pruebas, con los datos de esta base (míralo en v_%s_control): '
           'aquí no se puede ver que pase a rojo y vuelva', v, p_cual, p_cual), null);
  return true;
end $$;

-- Lo que hay en lo que c10 toca (la 58 lo compara)
create or replace function pg_temp.c10_conteos() returns text language sql as $$
  select format('config %s · personas %s · pagos con algo dicho %s · repartos %s · líneas %s · detalle %s · asientos %s · líneas del libro %s · movimientos %s (%s '
                'pendientes) · archivos %s · horas %s (%s aprobadas) · aprobaciones %s · perfiles %s · usuarios %s · tarifas %s · obras %s · '
                'escenarios %s · estimados %s · cerrados %s · funciones %s',
                (select md5(to_jsonb(c)::text) from jornal_config c where c.id = 1), (select count(*) from jornal_personas),
                (select md5(coalesce(string_agg(to_jsonb(g)::text, '|' order by g.movimiento_id), '')) from jornal_pagos g),
                (select count(*) from jornal_repartos), (select count(*) from jornal_reparto_lineas), (select count(*) from jornal_reparto_horas),
                (select count(*) from asientos), (select count(*) from asiento_lineas), (select count(*) from movimientos_banco),
                (select count(*) from movimientos_banco where estado = 'pendiente'), (select count(*) from archivos_banco),
                (select count(*) from horas), (select count(*) from horas where aprobado_el is not null),
                (select count(*) from horas_aprobaciones), (select count(*) from perfiles), (select count(*) from auth.users),
                (select count(*) from costos_equipo), (select count(*) from proyectos), (select count(*) from escenarios),
                (select count(*) from estimados), (select count(*) from periodos where estado = 'cerrado'),
                (select count(*) from pg_proc where pronamespace = 'public'::regnamespace))
$$;
insert into _c10 values ('conteos', pg_temp.c10_conteos());

-- (lo de c3, c4 y c6 que ya estaba en rojo ANTES de las pruebas: la 60 lo dice y no lo cuenta)
insert into _c10
select 'rojos_c3', coalesce(string_agg(control, ', ' order by control), '') from fn_puentes_verificar() where not ok;
insert into _c10
select 'rojos_c4', coalesce(string_agg(vista, ', ' order by vista), '') from fn_estados_control('hoy') where not ok;
insert into _c10
select 'rojos_c6', coalesce(string_agg(vista, ', ' order by vista), '') from fn_banco_control('hoy') where not ok;
-- (las funciones AJENAS a c10 que «permisos» de c2 ya marcaba ANTES de las
-- pruebas —en producción, una función de otra parte de la app—: la 4 y la 60
-- las dicen y no las cuentan como fallo de c10. Una función de c10 nunca
-- entra aquí.)
create or replace function pg_temp.c10_permisos_fallan() returns setof text language sql as $$
  select x.t from fn_verificar_cadena() k, jsonb_array_elements_text(coalesce(k.detalle->'fallan', '[]'::jsonb)) x(t)
   where k.control = 'permisos' and not k.ok
$$;
insert into _c10
select 'ajenas_permisos', coalesce(string_agg(z.f, '; ' order by z.f), '')
  from (select substring(t from 'la función (.+?) es SECURITY DEFINER') as f from pg_temp.c10_permisos_fallan() t) z
 where z.f is not null
   and coalesce(obj_description(coalesce(to_regprocedure(z.f), to_regprocedure('public.' || z.f)), 'pg_proc'), '') not like 'c10: %';
-- «permisos» de c2 sin contar lo ajeno de antes: 'verde' o 'rojo: …'
create or replace function pg_temp.c10_permisos() returns text language plpgsql as $$
declare
  v_ok boolean; v_det text; v_resto text;
begin
  select k.ok, left(k.detalle::text, 300) into v_ok, v_det from fn_verificar_cadena() k where k.control = 'permisos';
  if v_ok then return 'verde'; end if;
  select string_agg(t, ' · ') into v_resto from pg_temp.c10_permisos_fallan() t
   where coalesce(substring(t from 'la función (.+?) es SECURITY DEFINER'), '')
         <> all (coalesce(string_to_array(nullif(pg_temp.c10('ajenas_permisos'), ''), '; '), '{}'::text[]));
  if v_resto is null and exists (select 1 from pg_temp.c10_permisos_fallan()) then return 'verde'; end if;
  return 'rojo: ' || left(coalesce(v_resto, v_det), 300);
end $$;

-- EL DEVENGO DE LAS PRUEBAS 20 Y 39 (13-nov, la Fase 11b). Las dos necesitan
-- un devengo estándar de horas (c3) en el mes del pago. c3 NO devenga un mes
-- que ya tiene el journal de una nómina («ya pagó parte de estas horas»), o
-- devenga solo lo que la nómina no pagó, según su versión: en un mes con
-- nómina estas pruebas salían «omitida», y lo que miran —lo que hace c10 con
-- un devengo en el mes— se quedaba sin probar justo desde la primera nómina.
-- Ahora: sin nómina en el mes, el devengo lo pone c3 como siempre
-- (fn_horas_devengar); CON nómina, lo pone la prueba por la puerta de los
-- puentes, con la misma forma con que lo deja c3 (origen horas_devengo del
-- mes, reversible, 5000 por obra contra 2210, y en su documento cada hora),
-- con SOLO las horas de la prueba. Se deshace con ella. «Omitida» queda solo
-- para cuando de verdad no se puede (c3 y el libro no dejan: se dice qué
-- dijeron).
-- 13-nov, los arreglos de la verificación de la Fase 11b: CON nómina en el
-- mes, PRIMERO SE LE PIDE A c3. El c3 de la Fase 11b sí devenga un mes con
-- nómina (lo que ninguna nómina pagó: las horas de la prueba entre ellas) y
-- ese mes CONSERVA su devengo de verdad al postear la nómina: ponerle otro
-- aparte chocaba con él (23505) y las dos pruebas salían «omitida» en
-- cuanto hubiera una nómina y un devengo en el mes. Si c3 es el de antes y
-- no deja (MX008), lo pone la prueba, como hasta ahora.
-- (14-nov, la Fase 11c) ¿ESTÁ EL c3 QUE APARTA LAS HORAS DE LOS JORNALES Y
-- PONE EL DEVENGO AL DÍA SOLO? Se mira lo mismo que mira c10: su trigger
-- diferido sobre asientos, encendido. Con él, el aviso devengo_estandar y el
-- control 50 dicen otra cosa (la 20 y la 39), y devengar un mes DESPUÉS de
-- repartir un jornal suyo ya no cuenta esas horas: la 39 y la 55 devengan
-- ANTES de repartir (el devengo solo se pone al día al confirmar, y una
-- prueba nunca confirma), y valen con los dos c3.
create or replace function pg_temp.c10_c3_aparta() returns boolean language sql as $$
  select exists (select 1 from pg_trigger t
                  where t.tgrelid = 'public.asientos'::regclass and t.tgname = 'trg_puente_asientos_jornal'
                    and not t.tgisinternal and t.tgenabled in ('O', 'A'))
$$;
create or replace function pg_temp.c10_mes_con_nomina(p_mes text) returns boolean language sql as $$
  select exists (select 1 from asientos a join periodos p on p.periodo = p_mes
                  where coalesce(a.origen_tabla, '') like 'nomina%' and a.fecha_contable between p.desde and p.hasta
                    and a.camino not in ('reverso', 'reverso_automatico')
                    and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso'))
$$;
-- Devuelve {asiento: su número, como: 'c3' | 'prueba'}. Como el SQL Editor.
create or replace function pg_temp.c10_devengar(p_mes text, p_ids bigint[]) returns jsonb language plpgsql as $$
declare
  r jsonb; v_hasta date; v_lin jsonb; v_doc jsonb; v_tot numeric;
  v_debe text := fn_puente_cuenta_de('mano_obra'); v_haber text := fn_puente_cuenta_de('sueldos_devengados');
begin
  perform pg_temp.c10_ser('editor');
  if not pg_temp.c10_mes_con_nomina(p_mes) then
    return fn_horas_devengar(p_mes) || jsonb_build_object('como', 'c3');
  end if;
  begin   -- (con nómina en el mes: primero c3; el de la Fase 11b lo devenga)
    return fn_horas_devengar(p_mes) || jsonb_build_object('como', 'c3');
  exception when others then null;   -- (el c3 de antes: MX008, «ya pagó parte de estas horas». Lo pone la prueba.)
  end;
  select q.hasta into v_hasta from periodos q where q.periodo = p_mes and q.tipo = 'mes';
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('cuenta', v_debe, 'monto', g.monto::text, 'proyecto_id', g.proyecto_id, 'co', g.co,
                                                                 'memo', 'ESTÁNDAR (c10-pruebas): horas aprobadas × costo_hora'))
                            order by g.proyecto_id, g.co), '[]'::jsonb), coalesce(sum(g.monto), 0)
    into v_lin, v_tot
    from (select h.proyecto_id, nullif(btrim(h.co), '') as co, round(sum(h.horas * ce.costo_hora), 2) as monto
            from horas h join costos_equipo ce on ce.usuario_id = h.usuario_id
           where h.id = any (p_ids) and h.proyecto_id is not null
           group by 1, 2) g;
  select jsonb_agg(jsonb_build_object('horas_id', h.id, 'horas', h.horas, 'costo_hora', ce.costo_hora, 'proyecto_id', h.proyecto_id,
                                      'co', nullif(btrim(h.co), ''), 'fase', h.fase) order by h.id)
    into v_doc
    from horas h join costos_equipo ce on ce.usuario_id = h.usuario_id
   where h.id = any (p_ids) and h.proyecto_id is not null;
  r := fn_postear_interno(jsonb_build_object(
         'camino', 'puente', 'fecha', v_hasta::text, 'reversible', true,
         'descripcion', format('C10 PRUEBA: devengo ESTÁNDAR de mano de obra de %s, como lo deja c3 (se deshace)', p_mes),
         'lineas', v_lin || jsonb_build_array(jsonb_build_object('cuenta', v_haber, 'monto', (-v_tot)::text, 'memo', 'ESTÁNDAR (c10-pruebas)')),
         'origen_tabla', 'horas_devengo', 'origen_id', p_mes,
         'procedencia', jsonb_build_object('funcion', 'c10-pruebas', 'etiqueta', 'estándar',
                                           'documento', jsonb_build_object('mes', p_mes, 'horas', v_doc))));
  return jsonb_build_object('asiento', r->>'numero', 'como', 'prueba');
end $$;

-- EL DEVENGO DE UN MES YA DEVENGADO (13-nov, los arreglos de la verificación
-- de la Fase 11b; para la 59). Aplicar un jornal APRUEBA sus horas (y
-- deshacerlo les quita la aprobación que puso). Si el mes de esas horas ya
-- tenía su devengo estándar (c3) y sigue abierto, ese devengo deja de ser el
-- de las horas aprobadas de hoy, y c3 lo dice con su control «devengo» (la
-- fila 131 del cierre): no es un fallo de c10 —pasa con cualquier hora que
-- se apruebe en un mes ya devengado, y c3 dice qué hacer—. La 59 —que mira
-- que un jornal no ponga en rojo nada de las otras capas— fallaba por eso
-- los primeros días de cada mes, con el anterior devengado y sin cerrar.
-- Ahora, si alguno de los meses de sus horas de prueba tiene su devengo
-- vivo, ese rojo de c3 (y su fila del cierre) no se cuenta, y se dice.
-- (No se pone al día el devengo dentro de la prueba. 14-nov, la Fase 11c:
-- el c3 de esa fase aparta del devengo las horas que un jornal pagó DENTRO
-- del mes y lo pone al día solo, pero AL CONFIRMAR la transacción del
-- reparto —un trigger diferido—, y una prueba nunca confirma: dentro de
-- ella el devengo sigue «de ayer», como con el c3 de antes. Ver la cabecera
-- de c10-costo-obra.sql, «LO QUE CAMBIÓ EN LA v4».)
-- Los meses abiertos de las horas de prueba con su devengo vivo ('' si
-- ninguno). Como el SQL Editor.
create or replace function pg_temp.c10_devengo_vivo() returns text language sql as $$
  select coalesce(string_agg(distinct p.periodo, ', ' order by p.periodo), '')
    from horas h join periodos p on p.tipo = 'mes' and p.estado = 'abierto' and h.fecha between p.desde and p.hasta
   where h.notas = 'c10-pruebas' and h.id < 0
     and exists (select 1 from asientos a
                  where a.origen_tabla = 'horas_devengo' and a.origen_id = p.periodo
                    and a.camino not in ('reverso', 'reverso_automatico')
                    and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso'))
$$;
-- (los rojos, sin el «devengo» de c3 ni su fila del cierre)
create or replace function pg_temp.c10_sin_devengo(p text[]) returns text[] language sql as $$
  select coalesce(array_agg(x order by x), '{}') from unnest(p) x where x <> 'c3: devengo' and x !~ '^c9: [0-9]+ puentes: devengo$'
$$;

-- =====================================================================
-- LA CUADRILLA, SOLA (v5 de la capa, 15-nov-2026): lo común de las pruebas
-- 65 a 81.
-- =====================================================================
-- EL DÍA DE UN PAGO QUE ENTRA SOLO. La rutina que registra sola usa SIEMPRE
-- la semana que toca por el día del pago (no hay fechas a mano), y no
-- registra un pago cuya semana todavía no termina. Para que las pruebas
-- valgan cualquier día de la semana, sus pagos van de lunes a miércoles de
-- la semana del pago de siempre (c10_d): pagan la semana anterior (w1), que
-- ya terminó.
create or replace function pg_temp.c10_ds() returns date language sql as $$
  select least(pg_temp.c10_d(), pg_temp.c10('lunes')::date + 2)
$$;
-- (la fila «omitida» si ese día cae en un mes que no está abierto —los
-- primeros días de un mes, con el anterior ya cerrado, o antes de que
-- empiece el libro—: ahí el pago no entra solo por otra razón; true si la puso)
create or replace function pg_temp.c10_omitir_ds(p_n int, p_prueba text, p_esperado text) returns boolean language plpgsql as $$
declare
  v text;
begin
  select to_jsonb(p)->>'estado' into v from periodos p where p.tipo = 'mes' and pg_temp.c10_ds() between p.desde and p.hasta;
  if v = 'abierto' and pg_temp.c10_ds() >= fn_margen_libro_desde() then
    return false;
  end if;
  insert into _pruebas values (p_n, p_prueba, p_esperado,
    format('omitida: el pago de prueba que entra solo iría con fecha %s (de lunes a miércoles de esta semana), y ese mes %s: hoy no se '
           'puede ver que entre solo; vuelve a pegar este archivo otro día de este mes', pg_temp.c10_ds(),
           case when v is null then 'no está en el libro' else 'está ' || v end), null);
  return true;
end $$;
-- APARCAR LO REAL dentro de la prueba (se deshace con ella): la rutina que
-- registra sola mira TODO lo pendiente de la Bandeja. Para que una prueba vea
-- solo lo suyo —y no reparta, ni dentro de su subtransacción, un pago de
-- verdad—: lo automático encendido (en esta base puede estar apagado), las
-- personas reales del jornal de baja, las que la base daría de alta sola por
-- su nombre también (de baja desde ya), los pagos reales de los que Edgar
-- dijo de quién son, sin lo dicho, y cómo terminó la última corrida sin
-- pantalla, sin apuntar (el control 85 la mira). Con lo real aparcado, ese
-- control cuenta solo lo de la prueba: en una base con pagos de verdad
-- esperando una respuesta (lo normal) las pruebas que lo miran no se omiten.
-- Como el SQL Editor, con la marca de la guarda.
create or replace function pg_temp.c10_aparcar() returns void language plpgsql as $$
begin
  perform pg_temp.c10_ser('editor');
  perform set_config('mx_jornal.escribe', 'jornal_config', true);
  update jornal_config set solo = true, solo_ultimo = null where id = 1 and (not solo or solo_ultimo is not null);
  perform set_config('mx_jornal.escribe', 'jornal_personas', true);
  update jornal_personas jp set activa = false
   where jp.activa and jp.usuario_id not in (pg_temp.c10('p1')::uuid, pg_temp.c10('p2')::uuid, pg_temp.c10('p3')::uuid);
  insert into jornal_personas (usuario_id, patron, activa, nota)
  select q.usuario_id, coalesce(q.patron, '\mSIN-PATRON\M'), false, 'c10-pruebas (se deshace)'
    from fn_jornal_cuadrilla() q
   where q.usuario_id not in (pg_temp.c10('p1')::uuid, pg_temp.c10('p2')::uuid, pg_temp.c10('p3')::uuid)
  on conflict (usuario_id) do nothing;
  perform set_config('mx_jornal.escribe', 'jornal_pagos', true);
  update jornal_pagos g set usuario_id = null
   where g.usuario_id is not null
     and exists (select 1 from movimientos_banco m where m.id = g.movimiento_id and m.estado = 'pendiente' and coalesce(m.descripcion, '') !~ 'C10 PRUEBA');
  perform set_config('mx_jornal.escribe', '', true);
end $$;
-- Como el dueño por la API: la rutina que registra sola, y lo que Edgar dice
-- de un pago. Al volver, otra vez el SQL Editor.
create or replace function pg_temp.c10_rutina(p jsonb default '{}'::jsonb) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  r := fn_jornal_solo(p);
  perform pg_temp.c10_ser('editor');
  return r;
end $$;
create or replace function pg_temp.c10_dice(p jsonb) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  r := fn_jornal_pago(p);
  perform pg_temp.c10_ser('editor');
  return r;
end $$;
-- Cómo está un pago de prueba para la rutina, como lo ve el dueño en la lista
-- de pendientes: «entra», «espera [códigos]», «pregunta [códigos]», «no
-- [códigos]» (los códigos de lo que lo frena, en su orden); «no reconocido»
-- si no sale en la lista y sigue pendiente; «resuelto» si ya no está pendiente.
create or replace function pg_temp.c10_solo(p_mov uuid) returns text language plpgsql as $$
declare
  r record;
  v text;
begin
  perform pg_temp.c10_ser('dueno');
  select q.solo, (select string_agg(t.f->>'codigo', ',' order by t.o) from jsonb_array_elements(q.solo_frenos) with ordinality as t(f, o)) as cod
    into r
    from v_jornal_pendientes q where q.movimiento_id = p_mov;
  if found then
    v := r.solo || coalesce(' [' || r.cod || ']', '');
  else
    select case when m.estado <> 'pendiente' then 'resuelto' else 'no reconocido' end into v from movimientos_banco m where m.id = p_mov;
  end if;
  perform pg_temp.c10_ser('editor');
  return coalesce(v, 'no existe');
end $$;
-- (los avisos de una propuesta —o de un reparto, o de lo registrado— que hablan de la obra de unas horas, en su orden:
-- obra_terminada, obra_sin_aprobar, horas_tras_terminada; «-» si ninguno. Los demás dependen del día: no se miran aquí)
create or replace function pg_temp.c10_notas(p_avisos jsonb) returns text language sql as $$
  select coalesce(string_agg(a.v->>'codigo', ',' order by a.o), '-')
    from jsonb_array_elements(case when jsonb_typeof(p_avisos) = 'array' then p_avisos else '[]'::jsonb end) with ordinality as a(v, o)
   where a.v->>'codigo' in ('obra_terminada', 'obra_sin_aprobar', 'horas_tras_terminada')
$$;
-- (lo registrado por la rutina en una corrida, de los pagos que se le dicen: «2: Zzana 200.00, Zzbeto 144.00» o «0»)
create or replace function pg_temp.c10_registrados(p_r jsonb, p_movs uuid[]) returns text language sql as $$
  select count(*)::text || coalesce(': ' || string_agg(format('%s %s', split_part(x->>'persona', ' ', 1), x->>'monto'), ', ' order by x->>'persona', x->>'monto'), '')
    from jsonb_array_elements(coalesce(p_r->'registrados', '[]'::jsonb)) x
   where (x->>'movimiento_id')::uuid = any (p_movs)
$$;


-- =====================================================================
-- Las pruebas
-- =====================================================================

-- 1. El pegado: precondiciones, tablas, vistas, las 48 funciones por su
--    nombre exacto, la configuración (una fila, con una cuenta que sirve),
--    cada objeto con su comentario «c10: …» y la marca de la versión (v5).
do $$
declare
  v_obt text; v_pre text; v_tab int; v_vis int; v_fn int; v_fn2 int; v_sin text; v_cfg text;
  v_esp text := 'nada falta | 6 tablas | 7 vistas | 48 funciones (48 nombres) | sin comentario c10: ninguno | '
                'configuración: 1 fila, id 1, cuenta del jornal que sirve | marca 2026111501';
begin
  begin
    perform pg_temp.c10_ser('editor');
    v_pre := coalesce(fn_jornal_precondiciones(), 'nada falta');
    select count(*) into v_tab from pg_tables where schemaname = 'public' and tablename = any (pg_temp.c10_tablas());
    select count(*) into v_vis from pg_views where schemaname = 'public' and viewname = any (pg_temp.c10_vistas());
    select count(*), count(distinct proname) into v_fn, v_fn2
      from pg_proc where pronamespace = 'public'::regnamespace and pg_temp.c10_es_suya(proname);
    select coalesce(string_agg(x.que, ', ' order by x.que), 'ninguno') into v_sin
      from (select c.relname::text as que from pg_class c
             where c.relnamespace = 'public'::regnamespace
               and (c.relname = any (pg_temp.c10_tablas()) or c.relname = any (pg_temp.c10_vistas()))
               and coalesce(obj_description(c.oid, 'pg_class'), '') not like 'c10: %'
            union all
            select p.proname::text from pg_proc p
             where p.pronamespace = 'public'::regnamespace and pg_temp.c10_es_suya(p.proname)
               and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c10: %') x;
    select format('%s fila, id %s, cuenta del jornal %s', count(*), min(c.id),
                  case when bool_and(fn_jornal_cuenta_mal(c.cuenta_defecto, 'obra') is null) then 'que sirve' else 'que NO sirve' end)
      into v_cfg from jornal_config c;
    v_obt := format('%s | %s tablas | %s vistas | %s funciones (%s nombres) | sin comentario c10: %s | configuración: %s | marca %s',
                    v_pre, v_tab, v_vis, v_fn, v_fn2, v_sin, v_cfg, fn_jornal_version());
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'el pegado: nada falta, 6 tablas, 7 vistas, las 48 funciones por su nombre exacto, la configuración (una fila con una cuenta que sirve), cada objeto con su comentario «c10: …» y la marca de la versión (2026111501: la cuadrilla, sola)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 2. Las precondiciones en rojo: desde la app; sin una función de c6 (se
--    quita dentro de la prueba y se deshace); una función con nombre de c10
--    que no lleva su comentario (no es de c10: no se pisa); una vista ajena
--    colgada de una vista de c10 (se borraría al volver a pegar).
do $$
declare
  v_obt text; v_a text; v_b text; v_c text; v_d text;
  v_esp text := 'desde la app: 42501 | sin fn_banco_descasar: la nombra | una función sin su comentario: la nombra y no la pisa | '
                'una vista ajena colgada: la nombra';
begin
  begin
    -- (desde la app no se instala nada: la función no está en la API)
    perform pg_temp.c10_ser('dueno');
    begin
      v_a := coalesce(fn_jornal_precondiciones(), 'nada');
    exception when others then v_a := sqlstate;
    end;
    perform pg_temp.c10_ser('editor');
    begin
      drop function public.fn_banco_descasar(uuid, text);
      v_b := coalesce(fn_jornal_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      comment on function public.fn_margen_obra(text) is 'otra cosa';
      v_c := coalesce(fn_jornal_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      create view public.c10_prueba_ajena as select o.proyecto_id from public.v_margen_obra o;
      v_d := coalesce(fn_jornal_precondiciones(), 'nada');
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('desde la app: %s | sin fn_banco_descasar: %s | una función sin su comentario: %s | una vista ajena colgada: %s',
                    v_a,
                    case when v_b like '%fn_banco_descasar(uuid,text)%' then 'la nombra' else v_b end,
                    case when v_c like '%sin ser de c10%' and v_c like '%fn_margen_obra(text)%' and v_c like '%No lo piso%'
                         then 'la nombra y no la pisa' else v_c end,
                    case when v_d like '%c10_prueba_ajena%' and v_d like '%depende(n) de las vistas de c10%' then 'la nombra' else v_d end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (2, 'las precondiciones en rojo: desde la app no se llaman (42501); sin una función de c6 la nombran; una función con nombre de c10 sin su comentario no se pisa; una vista ajena colgada de las de c10 se dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 3. La API: las de la pantalla, solo authenticated; las internas, nadie;
--    anon y service_role no ejecutan ni leen nada; el equipo (una persona
--    de prueba, con un reparto SUYO ya en el libro) recibe 42501 de las
--    nueve funciones de la pantalla (las siete de siempre y las dos de la
--    cuadrilla sola: la rutina que registra sola y lo que Edgar dice de un
--    pago) y cero filas de las seis tablas, las siete vistas y las
--    auxiliares de lectura (también la que pregunta qué horas pagó una
--    nómina, la de la cuadrilla y la de los frenos); el dueño entra y ve.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_chk uuid; v_chk2 uuid;
  v_api text; v_sin text; v_anon text; v_srv text; v_x text; v_n int := 0; v_filas bigint := 0; v_k bigint; v_calc text; v_due text;
  v_esp text := 'pantalla mal: ninguna | internas con API: ninguna | anon 42501 y 42501 | service_role 42501 y 42501 | '
                'equipo: 9 de 9 funciones 42501, 0 filas en 6 tablas, 7 vistas y 10 auxiliares, y el cálculo le dice que el movimiento no '
                'existe y los frenos que no es un pago reconocido | dueño: 1 reparto suyo, 12 obras de prueba, el detalle de la obra, 12 + 7 '
                'controles, 1 cheque que espera su pregunta y 1 pago con algo dicho';
begin
  if pg_temp.c10_omitir(3, 'la API por rol', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 6.5);
    v_mov := pg_temp.c10_cargo('c10-t3', pg_temp.c10_d(), 362.50, 'Zelle payment to C10 PRUEBA ZZANA 9003');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    -- (v5) un cheque que espera su pregunta y otro del que Edgar ya dijo algo: el equipo no ve ni el uno ni lo otro
    v_chk := pg_temp.c10_cargo('c10-t3-chk', pg_temp.c10_d(), 111.00, 'CHECK 3003 C10 PRUEBA');
    v_chk2 := pg_temp.c10_cargo('c10-t3-chk2', pg_temp.c10_d(), 112.00, 'CHECK 3004 C10 PRUEBA');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_pago(jsonb_build_object('movimiento_id', v_chk2, 'no_cuadrilla', true));
    perform pg_temp.c10_ser('editor');
    -- las de la pantalla: solo authenticated
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('fn_jornal_propuesta', 'fn_jornal_aplicar', 'fn_jornal_deshacer', 'fn_jornal_config', 'fn_jornal_persona',
                         'fn_jornal_repartir', 'fn_margen_obra', 'fn_jornal_solo', 'fn_jornal_pago', 'fn_jornal_version')
       and not (has_function_privilege('authenticated', p.oid, 'execute')
                and not has_function_privilege('anon', p.oid, 'execute')
                and not has_function_privilege('service_role', p.oid, 'execute'));
    -- las internas: nadie de la API
    select coalesce(string_agg(p.proname, ', ' order by p.proname), 'ninguna') into v_sin
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('fn_jornal_precondiciones', 'fn_jornal_pegado', 'fn_jornal_guarda', 'fn_jornal_solo_programado')
       and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute')
            or has_function_privilege('service_role', p.oid, 'execute'));
    -- anon: ni ejecuta ni lee
    perform pg_temp.c10_ser('anon');
    begin perform fn_jornal_propuesta(v_mov); v_anon := 'entró'; exception when others then v_anon := sqlstate; end;
    begin perform count(*) from v_margen_obra; v_anon := v_anon || ' y leyó'; exception when others then v_anon := v_anon || ' y ' || sqlstate; end;
    perform pg_temp.c10_ser('service_role');
    begin perform fn_jornal_config('{}'::jsonb); v_srv := 'entró'; exception when others then v_srv := sqlstate; end;
    begin perform count(*) from jornal_repartos; v_srv := v_srv || ' y leyó'; exception when others then v_srv := v_srv || ' y ' || sqlstate; end;
    -- el equipo: la misma persona a la que se le pagó
    perform pg_temp.c10_ser('p1');
    begin perform fn_jornal_propuesta(v_mov); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 'x'); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_jornal_deshacer((v_r->>'reparto_id')::uuid, 'no es mío'); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_jornal_config('{"aviso_tarifa_pct": 1}'::jsonb); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'ZZBETO')); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform count(*) from fn_jornal_repartir(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_margen_obra('c10-prueba-a'); exception when insufficient_privilege then v_n := v_n + 1; end;
    -- (v5) ni registra solo, ni dice nada de un pago
    begin perform fn_jornal_solo('{}'::jsonb); exception when insufficient_privilege then v_n := v_n + 1; end;
    begin perform fn_jornal_pago(jsonb_build_object('movimiento_id', v_chk, 'usuario_id', pg_temp.c10('p1'))); exception when insufficient_privilege then v_n := v_n + 1; end;
    select count(*) into v_k from jornal_pagos;           v_filas := v_filas + v_k;
    select count(*) into v_k from v_jornal_cheques;       v_filas := v_filas + v_k;
    select count(*) into v_k from fn_jornal_cuadrilla();  v_filas := v_filas + v_k;
    select count(*) into v_k from jornal_config;          v_filas := v_filas + v_k;
    select count(*) into v_k from jornal_personas;        v_filas := v_filas + v_k;
    select count(*) into v_k from jornal_repartos;        v_filas := v_filas + v_k;
    select count(*) into v_k from jornal_reparto_lineas;  v_filas := v_filas + v_k;
    select count(*) into v_k from jornal_reparto_horas;   v_filas := v_filas + v_k;
    select count(*) into v_k from v_jornal_pendientes;    v_filas := v_filas + v_k;
    select count(*) into v_k from v_jornal_repartos;      v_filas := v_filas + v_k;
    select count(*) into v_k from v_jornal_personas;      v_filas := v_filas + v_k;
    select count(*) into v_k from v_jornal_control;       v_filas := v_filas + v_k;
    select count(*) into v_k from v_margen_obra;          v_filas := v_filas + v_k;
    select count(*) into v_k from v_margen_control;       v_filas := v_filas + v_k;
    select count(*) into v_k from fn_margen_lineas(null); v_filas := v_filas + v_k;
    select count(*) into v_k from fn_margen_horas(null);  v_filas := v_filas + v_k;
    select count(*) into v_k from fn_margen_obras(null);  v_filas := v_filas + v_k;
    select count(*) into v_k from fn_margen_estimado(null); v_filas := v_filas + v_k;
    -- (ni lo que se queda fuera de los repartos: las horas tardías, los pagos resueltos por fuera, lo de la IA)
    select count(*) into v_k from fn_jornal_tardias(null); v_filas := v_filas + v_k;
    select count(*) into v_k from fn_jornal_fuera();       v_filas := v_filas + v_k;
    select count(*) into v_k from fn_jornal_ia(v_mov);     v_filas := v_filas + v_k;
    -- (ni qué horas pagó una nómina)
    select count(*) into v_k from fn_margen_horas_nomina(); v_filas := v_filas + v_k;
    -- (sus horas sí las lee, como siempre; el reparto de un pago por ellas, no)
    select count(*) into v_k from fn_jornal_repartir_ids(array(select h.id from horas h where h.usuario_id = pg_temp.c10('p1')::uuid), 100);
    v_filas := v_filas + v_k;
    v_calc := fn_jornal_calcular(v_mov, null, null)->>'por_que';
    v_x := coalesce(fn_margen_bajar('c10-prueba-a', 'costo')::text, 'nada');
    -- (v5: los frenos de un pago, con un cálculo que alguien le pasara a mano: «ninguno»; y las dudas de un nombre, nada)
    v_x := v_x || case when fn_jornal_frenos(v_mov, jsonb_build_object('reconocido', true, 'persona', jsonb_build_object('usuario_id', pg_temp.c10('p1'))))->>'estado' = 'ninguno'
                            and fn_jornal_nombre_dudas(pg_temp.c10('p1')::uuid, 'Zzana C10 PRUEBA', true) is null then '' else ' / los frenos le contestan' end;
    -- el dueño: entra y ve
    perform pg_temp.c10_ser('dueno');
    select format('%s reparto suyo, %s obras de prueba, %s, %s + %s controles, %s cheque que espera su pregunta y %s pago con algo dicho',
                  (select count(*) from v_jornal_repartos r where r.movimiento_id = v_mov),
                  (select count(*) from v_margen_obra o where o.proyecto_id like 'c10-prueba-%'),
                  case when fn_margen_obra('c10-prueba-a')->'obra'->>'proyecto_id' = 'c10-prueba-a' then 'el detalle de la obra' else 'sin detalle' end,
                  (select count(*) from v_jornal_control), (select count(*) from v_margen_control),
                  (select count(*) from v_jornal_cheques q where q.movimiento_id in (v_chk, v_chk2)),
                  (select count(*) from jornal_pagos g where g.movimiento_id in (v_chk, v_chk2)))
      into v_due;
    perform pg_temp.c10_ser('editor');
    v_obt := format('pantalla mal: %s | internas con API: %s | anon %s | service_role %s | equipo: %s de 9 funciones 42501, %s filas en 6 '
                    'tablas, 7 vistas y 10 auxiliares, y el cálculo le dice que %s | dueño: %s',
                    v_api, v_sin, v_anon, v_srv, v_n, v_filas,
                    case when v_calc = 'No existe ese movimiento del banco.' and v_x = 'nada'
                         then 'el movimiento no existe y los frenos que no es un pago reconocido' else v_calc || ' / ' || v_x end,
                    v_due);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'la API: las de la pantalla solo authenticated y las internas sin API (también la tarea de madrugada); anon y service_role 42501 (ni ejecutan ni leen); el equipo, con un pago suyo repartido, 42501 en las nueve funciones (también la rutina que registra sola y lo que Edgar dice de un pago) y cero filas en tablas, vistas y auxiliares; el dueño entra y ve',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 4. El catálogo: nada SECURITY DEFINER; ningún objeto de c10 con un prefijo
--    de otra capa ni de la otra sesión; RLS con su policy de lectura en cada
--    tabla y ni una policy de más; vistas security_invoker que no fijan las
--    columnas que c2-pruebas reescribe ni cuelgan de vistas de otras capas;
--    nada que nombre objetos de la otra sesión; y «permisos» (c2),
--    «protecciones del banco» (c6) y «protecciones de c4» en verde.
do $$
declare
  v_obt text; v_def text; v_pref text; v_rls text; v_pol text; v_vis text; v_fij int; v_dep text; v_otra text;
  v_c2 text; v_c6 text; v_c4 text;
  v_esp text := 'definer: ninguna | prefijos ajenos: ninguno | sin rls o policy: ninguna | policies que no son las suyas: ninguna | '
                'sin security_invoker: ninguna | columnas de c2 fijadas: 0 | vistas de otras capas debajo: ninguna | nombra lo de la otra '
                'sesión: nada | c2 permisos verde | c6 protecciones verde | c4 protecciones verde';
begin
  begin
    perform pg_temp.c10_ser('editor');
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_def
      from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosecdef and pg_temp.c10_es_suya(p.proname);
    select coalesce(string_agg(x.que, ', '), 'ninguno') into v_pref
      from (select p.proname::text as que from pg_proc p
             where p.pronamespace = 'public'::regnamespace and coalesce(obj_description(p.oid, 'pg_proc'), '') like 'c10: %'
               and (p.proname ~ '^fn_(banco|puente|estados|stripe|plaid|contador|cierre|costos|reporte|horas)_' or p.proname ~ '^fn_reparto_fase')
            union all
            select c.relname::text from pg_class c
             where c.relnamespace = 'public'::regnamespace and coalesce(obj_description(c.oid, 'pg_class'), '') like 'c10: %'
               and c.relname !~ '^(jornal_|v_jornal_|v_margen_)') x;
    select coalesce(string_agg(t.tablename, ', '), 'ninguna') into v_rls
      from pg_tables t
     where t.schemaname = 'public' and t.tablename = any (pg_temp.c10_tablas())
       and (not t.rowsecurity
            or not exists (select 1 from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t.tablename
                              and pl.cmd = 'SELECT' and pl.qual ~ 'es_dueno'));
    -- las policies justas: leer (todas), editar (config, personas, repartos, pagos) y añadir (personas, repartos, líneas, detalle, pagos)
    select coalesce(string_agg(pl.tablename || '.' || pl.policyname, ', ' order by 1), 'ninguna') into v_pol
      from pg_policies pl
     where pl.schemaname = 'public' and pl.tablename = any (pg_temp.c10_tablas())
       and (not ((pl.policyname = pl.tablename || '_dueno' and pl.cmd = 'SELECT')
                 or (pl.policyname = pl.tablename || '_dueno_edita' and pl.cmd = 'UPDATE'
                     and pl.tablename in ('jornal_config', 'jornal_personas', 'jornal_repartos', 'jornal_pagos'))
                 or (pl.policyname = pl.tablename || '_dueno_anade' and pl.cmd = 'INSERT'
                     and pl.tablename in ('jornal_personas', 'jornal_repartos', 'jornal_reparto_lineas', 'jornal_reparto_horas',
                                          'jornal_pagos')))
            or pl.roles <> '{authenticated}'::name[]);
    select coalesce(string_agg(c.relname, ', '), 'ninguna') into v_vis
      from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname = any (pg_temp.c10_vistas())
       and not coalesce((select o.option_value::boolean from pg_options_to_table(c.reloptions) o where o.option_name = 'security_invoker'), false);
    -- las columnas que c2-pruebas reescribe (ALTER COLUMN TYPE): ninguna vista de c10 las fija
    select count(*) into v_fij
      from pg_depend d
      join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
      join pg_class v on v.oid = rw.ev_class
      join pg_attribute a on a.attrelid = d.refobjid and a.attnum = d.refobjsubid
     where d.refclassid = 'pg_class'::regclass and v.relnamespace = 'public'::regnamespace and v.relname = any (pg_temp.c10_vistas())
       and ((d.refobjid = 'public.cuentas'::regclass and a.attname in ('activa', 'saldo_normal'))
            or (d.refobjid = 'public.periodos'::regclass and a.attname in ('estado', 'cerrado_el', 'cerrado_por', 'cadena_al_cerrar')));
    -- ninguna vista de c10 lee una vista de otra capa (se rehacen al volver a pegar su archivo)
    select coalesce(string_agg(distinct v.relname || ' → ' || b.relname, ', '), 'ninguna') into v_dep
      from pg_depend d
      join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
      join pg_class v on v.oid = rw.ev_class
      join pg_class b on d.refclassid = 'pg_class'::regclass and b.oid = d.refobjid
     where v.relnamespace = 'public'::regnamespace and v.relname = any (pg_temp.c10_vistas())
       and b.relkind in ('v', 'm') and b.oid <> v.oid and not (b.relname = any (pg_temp.c10_vistas()));
    -- nada de c10 nombra lo de la otra sesión
    select coalesce(string_agg(x.que, ', '), 'nada') into v_otra
      from (select p.proname::text as que, p.prosrc as src from pg_proc p
             where p.pronamespace = 'public'::regnamespace and pg_temp.c10_es_suya(p.proname)
            union all
            select c.relname::text, pg_get_viewdef(c.oid) from pg_class c
             where c.relnamespace = 'public'::regnamespace and c.relkind = 'v' and c.relname = any (pg_temp.c10_vistas())) x
     where x.src ~* '\m(v_estimado_vs_real_obra|horas_tareas|costos_revision|fn_costos_marcar|fn_cierre_obra|fn_reporte_semanal|horas_estimadas_fase|v_horas_por_fase)\M';
    v_c2 := pg_temp.c10_permisos();
    select case when ok then 'verde' else 'rojo: ' || left(detalle, 300) end into v_c6
      from fn_banco_control('hoy', array['cuadre: el otro lado de cada casado']) where vista = 'cuadre: protecciones del banco';
    select case when ok then 'verde' else 'rojo: ' || left(detalle, 300) end into v_c4
      from fn_estados_control('hoy', array['v_saldos_dinero']) where vista = 'cuadre: protecciones de c4';
    v_obt := format('definer: %s | prefijos ajenos: %s | sin rls o policy: %s | policies que no son las suyas: %s | sin security_invoker: %s | '
                    'columnas de c2 fijadas: %s | vistas de otras capas debajo: %s | nombra lo de la otra sesión: %s | c2 permisos %s | '
                    'c6 protecciones %s | c4 protecciones %s',
                    v_def, v_pref, v_rls, v_pol, v_vis, v_fij, v_dep, v_otra, v_c2, v_c6, v_c4);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'el catálogo: nada SECURITY DEFINER, ningún prefijo de otra capa ni de la otra sesión, RLS y las policies justas, vistas security_invoker que no fijan columnas de c2 ni leen vistas de otras capas, nada nombra lo de la otra sesión; c2 «permisos», c6 y c4 «protecciones» en verde con c10 pegado',
    v_esp,
    v_obt || case when pg_temp.c10('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c10: ' || pg_temp.c10('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;

-- 5. La guarda: las tablas de c10 solo las escriben sus funciones. A mano,
--    MX003: el dueño por la API (la policy le deja; la marca no), el SQL
--    Editor sin la marca, y —con la marca— lo que es rastro no se edita ni
--    se borra. Borrar por la API, ni eso (42501). Una persona sin repartos
--    sí se va (con su perfil).
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_rep uuid; v_chk uuid;
  a text; b text; c text; d text; e text; f text; g text; h text; i text; j text; k text;
  v_esp text := 'el dueño por la API: alta a mano MX003, config a mano MX003, borrar 42501 | el editor sin la marca: MX003, truncar MX003, '
                'borrar la configuración MX003, borrar el detalle MX003 | con la marca: editar un reparto MX003, su detalle MX003, '
                'borrarlo MX003, borrar a quien tiene repartos MX003, a quien no tiene: se va | lo dicho de un pago: el dueño a mano '
                'MX003 y MX003, el editor sin la marca MX003, y con la marca ni se borra (MX003) ni cambia de movimiento (MX003)';
begin
  if pg_temp.c10_omitir(5, 'la guarda de las tablas de c10', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t5', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9005');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_alta('p2');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_rep := (v_r->>'reparto_id')::uuid;
    perform pg_temp.c10_ser('dueno');
    begin insert into jornal_personas (usuario_id, patron) values (pg_temp.c10('p3')::uuid, 'ZZCARO'); a := 'entró';
    exception when others then a := sqlstate; end;
    begin update jornal_config set aviso_tarifa_pct = 1 where id = 1; b := 'entró'; exception when others then b := sqlstate; end;
    begin delete from jornal_personas where usuario_id = pg_temp.c10('p2')::uuid; c := 'entró'; exception when others then c := sqlstate; end;
    perform pg_temp.c10_ser('editor');
    begin
      insert into jornal_repartos (movimiento_id, usuario_id, desde, hasta, regla_periodo, monto, horas, tarifa_sale, cuenta, asiento_id, huella)
      select r.movimiento_id, r.usuario_id, r.desde, r.hasta, r.regla_periodo, r.monto, r.horas, r.tarifa_sale, r.cuenta, r.asiento_id, 'x'
        from jornal_repartos r where r.id = v_rep;
      d := 'entró';
    exception when others then d := sqlstate; end;
    begin truncate jornal_reparto_horas; e := 'entró'; exception when others then e := sqlstate; end;
    begin delete from jornal_config; e := e || ', borrar la configuración entró'; exception when others then e := e || ', borrar la configuración ' || sqlstate; end;
    begin delete from jornal_reparto_horas where reparto_id = v_rep; e := e || ', borrar el detalle entró'; exception when others then e := e || ', borrar el detalle ' || sqlstate; end;
    -- con la marca puesta a mano (el dueño de la base puede): lo que es rastro, ni así
    perform set_config('mx_jornal.escribe', 'jornal_repartos', true);
    begin update jornal_repartos set monto = monto + 1 where id = v_rep; f := 'entró'; exception when others then f := sqlstate; end;
    begin delete from jornal_repartos where id = v_rep; h := 'entró'; exception when others then h := sqlstate; end;
    perform set_config('mx_jornal.escribe', 'jornal_reparto_lineas', true);
    begin update jornal_reparto_lineas set monto = monto + 1 where reparto_id = v_rep; g := 'entró'; exception when others then g := sqlstate; end;
    perform set_config('mx_jornal.escribe', 'jornal_personas', true);
    begin delete from jornal_personas where usuario_id = pg_temp.c10('p1')::uuid; i := 'entró'; exception when others then i := sqlstate; end;
    begin
      delete from jornal_personas where usuario_id = pg_temp.c10('p2')::uuid;
      j := case when exists (select 1 from jornal_personas where usuario_id = pg_temp.c10('p2')::uuid) then 'sigue' else 'se va' end;
    exception when others then j := sqlstate; end;
    perform set_config('mx_jornal.escribe', '', true);
    -- (v5) lo que Edgar dijo de un pago (jornal_pagos): a mano, tampoco; y con la marca ni se borra ni cambia de movimiento
    v_chk := pg_temp.c10_cargo('c10-t5-chk', pg_temp.c10_d(), 105.00, 'CHECK 5005 C10 PRUEBA');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_pago(jsonb_build_object('movimiento_id', v_chk, 'no_cuadrilla', true));
    begin insert into jornal_pagos (movimiento_id, no_cuadrilla) values (v_mov, true); k := 'entró'; exception when others then k := sqlstate; end;
    begin update jornal_pagos set no_cuadrilla = false where movimiento_id = v_chk; k := k || ' y entró'; exception when others then k := k || ' y ' || sqlstate; end;
    perform pg_temp.c10_ser('editor');
    begin update jornal_pagos set no_cuadrilla = false where movimiento_id = v_chk; k := k || ', el editor sin la marca entró'; exception when others then k := k || ', el editor sin la marca ' || sqlstate; end;
    perform set_config('mx_jornal.escribe', 'jornal_pagos', true);
    begin delete from jornal_pagos where movimiento_id = v_chk; k := k || ', y con la marca se borra'; exception when others then k := k || ', y con la marca ni se borra (' || sqlstate || ')'; end;
    begin update jornal_pagos set movimiento_id = v_mov where movimiento_id = v_chk; k := k || ' y cambia de movimiento'; exception when others then k := k || ' ni cambia de movimiento (' || sqlstate || ')'; end;
    perform set_config('mx_jornal.escribe', '', true);
    v_obt := format('el dueño por la API: alta a mano %s, config a mano %s, borrar %s | el editor sin la marca: %s, truncar %s | con la marca: '
                    'editar un reparto %s, su detalle %s, borrarlo %s, borrar a quien tiene repartos %s, a quien no tiene: %s | lo dicho de un '
                    'pago: el dueño a mano %s',
                    a, b, c, d, e, f, g, h, i, j, k);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (5, 'la guarda: a mano no se escribe (MX003: el dueño por la API y el SQL Editor sin la marca), nadie borra por la API (42501), y con la marca un reparto y su detalle ni se editan ni se borran; una persona sin repartos sí se va; y lo que Edgar dijo de un pago tampoco se escribe a mano, ni se borra, ni cambia de movimiento',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 6. fn_jornal_config: cambia lo que se le dice y nada más, y sus frenos
--    (una clave desconocida, una cuenta que no sirve para cada uso, un %
--    fuera de sitio).
do $$
declare
  v_obt text; v_sin text; v_j jsonb;
  a text; b text; c text; d text; e text; f text; g text; h text; i text; k text; l text;
  v_esp text;
begin
  begin
    perform pg_temp.c10_ser('editor');
    -- una cuenta que sirve para lo sin obra (de gasto, sin obra obligatoria): la 7900 si está
    select c.codigo into v_sin from cuentas c
     where fn_jornal_cuenta_mal(c.codigo, 'sin_obra') is null order by (c.codigo = '7900') desc, c.codigo limit 1;
    v_esp := format('clave desconocida 22023 | no es un objeto 22023 | cuenta del jornal: 5000 MX004, 1010 MX004, no existe MX004 | lo sin '
                    'obra: 5200 MX004 (exige obra), 6000 MX004, %s entra | burden: 101 MX005, 12.555 MX005, 12.5 entra, null lo quita | '
                    'umbral: -1 MX005, 40 entra | lo demás no se mueve: sí', v_sin);
    perform pg_temp.c10_ser('dueno');
    begin perform fn_jornal_config('{"cuenta": "5200"}'); a := 'entró'; exception when others then a := sqlstate; end;
    begin perform fn_jornal_config('[1]'); b := 'entró'; exception when others then b := sqlstate; end;
    begin perform fn_jornal_config('{"cuenta_defecto": "5000"}'); c := 'entró'; exception when others then c := sqlstate; end;
    begin perform fn_jornal_config('{"cuenta_defecto": "1010"}'); d := 'entró'; exception when others then d := sqlstate; end;
    begin perform fn_jornal_config('{"cuenta_defecto": "c10-no-existe"}'); e := 'entró'; exception when others then e := sqlstate; end;
    begin perform fn_jornal_config('{"cuenta_sin_obra": "5200"}'); f := 'entró';
    exception when others then f := sqlstate || case when sqlerrm like '%exige obra%' then ' (exige obra)' else '' end; end;
    begin perform fn_jornal_config('{"cuenta_sin_obra": "6000"}'); g := 'entró'; exception when others then g := sqlstate; end;
    begin
      v_j := fn_jornal_config(jsonb_build_object('cuenta_sin_obra', v_sin));
      h := case when v_j->>'cuenta_sin_obra' = v_sin then v_sin || ' entra' else 'no quedó' end;
    exception when others then h := sqlstate; end;
    begin perform fn_jornal_config('{"burden_estandar_pct": 101}'); i := 'entró'; exception when others then i := sqlstate; end;
    begin perform fn_jornal_config('{"burden_estandar_pct": 12.555}'); k := 'entró'; exception when others then k := sqlstate; end;
    v_j := fn_jornal_config('{"burden_estandar_pct": 12.5}');
    l := case when (v_j->>'burden_estandar_pct')::numeric = 12.5 then '12.5 entra' else 'no quedó' end;
    v_j := fn_jornal_config('{"burden_estandar_pct": null}');
    l := l || case when v_j->'burden_estandar_pct' = 'null'::jsonb then ', null lo quita' else ', null no lo quitó' end;
    v_obt := format('clave desconocida %s | no es un objeto %s | cuenta del jornal: 5000 %s, 1010 %s, no existe %s | lo sin obra: 5200 %s, '
                    '6000 %s, %s | burden: 101 %s, 12.555 %s, %s', a, b, c, d, e, f, g, h, i, k, l);
    begin perform fn_jornal_config('{"aviso_tarifa_pct": -1}'); a := 'entró'; exception when others then a := sqlstate; end;
    v_j := fn_jornal_config('{"aviso_tarifa_pct": 40}');
    v_obt := v_obt || format(' | umbral: -1 %s, %s | lo demás no se mueve: %s', a,
                             case when (v_j->>'aviso_tarifa_pct')::numeric = 40 then '40 entra' else 'no quedó' end,
                             -- (el último cambio tocó solo el umbral: la cuenta de lo sin obra sigue, y quedó quién y cuándo)
                             case when v_j->>'cuenta_sin_obra' = v_sin and v_j->>'actualizado_por' = pg_temp.c10('dueno')
                                       and v_j->>'cuenta_defecto' = (select c2.cuenta_defecto from jornal_config c2 where c2.id = 1)
                                  then 'sí' else 'no: ' || v_j::text end);
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (6, 'fn_jornal_config y sus frenos: una clave desconocida 22023; la cuenta del jornal no puede ser de nómina, ni un banco, ni inventada (MX004); la de lo sin obra no puede exigir obra ni ser sueldo; el burden de 0 a 100 con dos decimales (MX005) y null lo quita; el umbral de 0 a 500; cambia solo lo que se le dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 7. fn_jornal_persona: el alta (con su patrón, o el que sale de un
--    movimiento), sus frenos (el dueño no; un perfil que no existe; un
--    patrón que casaría con cualquier pago, corto, o que no es una
--    expresión; una cuenta de nómina; el patrón de otra persona), el cambio
--    y la baja; y v_jornal_personas lo enseña.
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb;
  a text; b text; c text; d text; e text; f text; g text; h text; i text; k text; l text; m text;
  v_esp text := 'alta desde el movimiento: «\mPRUEBA ZZANA\M», 1 pago pendiente | el dueño MX008 | un perfil que no existe 22023 | patrón: '
                '«ZELLE» 22023, «zz» 22023, «(» 22023, vacío 22023 | cuenta 5000 MX004 | el patrón de otra persona MX008 | la vista: Zzana '
                'registrada y activa con 1 pago, Zzbeto sin dar de alta: no sale (sin horas) | con horas, Zzbeto sale sin registrar | la baja: '
                'de baja y 0 pagos | de vuelta con otro patrón: activa y 1 pago | clave desconocida 22023';
begin
  if pg_temp.c10_omitir(7, 'fn_jornal_persona y v_jornal_personas', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    v_mov := pg_temp.c10_cargo('c10-t7', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9007');
    perform pg_temp.c10_ser('dueno');
    v_j := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p1'), 'movimiento_id', v_mov));
    a := format('«%s», %s pago pendiente', v_j->>'patron', v_j->>'pagos_pendientes');
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('dueno'), 'patron', 'EDGAR PRUEBA')); b := 'entró';
    exception when others then b := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', '00000000-0000-4000-a000-0000000c10ff', 'patron', 'NADIE PRUEBA')); c := 'entró';
    exception when others then c := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'ZELLE')); d := 'entró';
    exception when others then d := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'zz')); e := 'entró';
    exception when others then e := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'ZZBETO (')); f := 'entró';
    exception when others then f := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'))); g := 'entró';
    exception when others then g := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'ZZBETO', 'cuenta', '5000')); h := 'entró';
    exception when others then h := sqlstate; end;
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', '\mprueba zzana\M')); i := 'entró';
    exception when others then i := sqlstate; end;
    select format('Zzana %s con %s pago, Zzbeto %s',
                  (select case when v.registrada and v.activa then 'registrada y activa' else 'mal' end || '' from v_jornal_personas v where v.usuario_id = pg_temp.c10('p1')::uuid),
                  (select v.pagos_pendientes from v_jornal_personas v where v.usuario_id = pg_temp.c10('p1')::uuid),
                  case when exists (select 1 from v_jornal_personas v where v.usuario_id = pg_temp.c10('p2')::uuid) then 'sale'
                       else 'sin dar de alta: no sale (sin horas)' end)
      into k;
    perform pg_temp.c10_ser('editor');
    perform pg_temp.c10_hora(1, 'p2', pg_temp.c10_w1(2), 'c10-prueba-a', 4);
    perform pg_temp.c10_ser('dueno');
    select case when not v.registrada and not v.activa and v.patron is null and v.horas_90_dias = 4 then 'Zzbeto sale sin registrar'
                else 'mal: ' || to_jsonb(v)::text end
      into l from v_jornal_personas v where v.usuario_id = pg_temp.c10('p2')::uuid;
    v_j := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p1'), 'activa', false));
    m := format('%s y %s pagos', case when not (v_j->>'activa')::boolean then 'de baja' else 'sigue activa' end,
                (select count(*) from v_jornal_pendientes p where p.movimiento_id = v_mov));
    v_j := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p1'), 'activa', true, 'patron', 'ZZANA 9007'));
    m := m || format(' | de vuelta con otro patrón: %s y %s pago', case when (v_j->>'activa')::boolean and not (v_j->>'nueva')::boolean then 'activa' else 'mal' end,
                     (select count(*) from v_jornal_pendientes p where p.movimiento_id = v_mov));
    v_obt := format('alta desde el movimiento: %s | el dueño %s | un perfil que no existe %s | patrón: «ZELLE» %s, «zz» %s, «(» %s, vacío %s | '
                    'cuenta 5000 %s | el patrón de otra persona %s | la vista: %s | con horas, %s | la baja: %s', a, b, c, d, e, f, g, h, i, k, l, m);
    begin perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p2'), 'patron', 'ZZBETO', 'tarifa', 30)); a := 'entró';
    exception when others then a := sqlstate; end;
    v_obt := v_obt || ' | clave desconocida ' || a;
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (7, 'fn_jornal_persona: el alta con el patrón que sale del movimiento; el dueño no (MX008); frenos del patrón (22023), de la cuenta (MX004) y del patrón repetido (MX008); la baja deja de reconocer sus pagos y el alta de vuelta los reconoce; v_jornal_personas enseña a los dados de alta y a quien tiene horas sin dar de alta',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- EL NÚCLEO (fn_jornal_repartir_ids / fn_jornal_repartir)
-- ---------------------------------------------------------------------
-- Los grupos de un reparto en una línea: obra[/CO] monto, … (lo sin obra al final)
create or replace function pg_temp.c10_grupos(p_ids bigint[], p_monto numeric) returns text language sql as $$
  select coalesce(string_agg(format('%s%s %s', coalesce(replace(g.proyecto_id, 'c10-prueba-', ''), 'sin obra'),
                                    coalesce('/' || g.co, ''), g.monto_grupo), ', ' order by g.grupo), 'ninguno')
    from (select distinct r.grupo, r.proyecto_id, r.co, r.monto_grupo from fn_jornal_repartir_ids(p_ids, p_monto) r) g
$$;
-- ¿Cumple el reparto lo que promete? «N grupos ✓» o lo que falla: los grupos
-- suman el monto; los reportes, también; los de cada grupo, el del grupo;
-- nada negativo; y cada grupo queda a menos de un centavo de su parte exacta.
create or replace function pg_temp.c10_nucleo(p_ids bigint[], p_monto numeric, p_grupos int) returns text language sql as $$
  with r as (select * from fn_jornal_repartir_ids(p_ids, p_monto)),
       g as (select r.grupo, min(r.monto_grupo) as mg, min(r.horas_grupo) as hg, sum(r.monto) as sr, sum(r.horas) as sh,
                    min(r.horas_total) as ht, count(distinct r.monto_grupo) as k
               from r group by r.grupo)
  select case when (select count(*) from g) <> p_grupos then format('%s grupos (se esperaban %s)', (select count(*) from g), p_grupos)
              when (select sum(g.mg) from g) <> p_monto then format('los grupos suman %s y no %s', (select sum(g.mg) from g), p_monto)
              when (select sum(r.monto) from r) <> p_monto then format('los reportes suman %s y no %s', (select sum(r.monto) from r), p_monto)
              when exists (select 1 from g where g.sr <> g.mg or g.sh <> g.hg or g.k <> 1) then 'un grupo no es la suma de sus reportes'
              when exists (select 1 from r where r.monto < 0 or r.monto_grupo < 0) then 'una parte negativa'
              when exists (select 1 from g where abs(g.mg - p_monto * g.hg / g.ht) >= 0.01) then 'un grupo se aleja un centavo o más de su parte'
              when (select count(*) from r) <> cardinality(p_ids) then 'faltan reportes'
              else format('%s grupo%s ✓', p_grupos, case when p_grupos = 1 then '' else 's' end) end
$$;

-- 8. El núcleo: la suma ES el monto, al centavo, con 1, 2, 7 y 12 grupos,
--    con montos que no dividen y horas con decimales.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; f text; v_ids bigint[]; i int;
  v_esp text := '371.33 en una obra: 1 grupo ✓ | 100.00 entre dos: 2 grupos ✓ | 940.00 entre siete: 7 grupos ✓ | 1234.57 entre doce: 12 '
                'grupos ✓ | 0.01 entre tres: 3 grupos ✓ | 999999.99 entre siete: 7 grupos ✓';
begin
  if pg_temp.c10_omitir(8, 'el núcleo: la suma es el monto', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- una obra, tres reportes con decimales
    v_ids := array[pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8),
                   pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 7.5),
                   pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-a', 0.25)];
    a := pg_temp.c10_nucleo(v_ids, 371.33, 1);
    -- dos obras
    v_ids := array[pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-a', 8),
                   pg_temp.c10_hora(5, 'p1', pg_temp.c10_w1(4), 'c10-prueba-b', 4.75)];
    b := pg_temp.c10_nucleo(v_ids, 100.00, 2);
    -- siete obras (una semana de las de verdad: más de las 5 líneas de una propuesta de la IA)
    v_ids := '{}';
    for i in 1..7 loop
      v_ids := v_ids || pg_temp.c10_hora(10 + i, 'p2', pg_temp.c10_w1(i - 1),
                                         'c10-prueba-' || (array['a', 'b', 'e', 'f', 'h', 'i', 'j'])[i],
                                         (array[8, 7.5, 6.25, 5, 3.33, 2, 0.5])[i]);
    end loop;
    c := pg_temp.c10_nucleo(v_ids, 940.00, 7);
    f := pg_temp.c10_nucleo(v_ids, 999999.99, 7);
    e := pg_temp.c10_nucleo(v_ids[1:3], 0.01, 3);
    -- doce obras, con dos reportes en algunas
    v_ids := '{}';
    for i in 1..12 loop
      v_ids := v_ids || pg_temp.c10_hora(30 + i, 'p3', pg_temp.c10_w2((i - 1) % 7), 'c10-prueba-' || chr(96 + i), 0.75 * i);
      if i % 3 = 0 then
        v_ids := v_ids || pg_temp.c10_hora(50 + i, 'p3', pg_temp.c10_w2(i % 7), 'c10-prueba-' || chr(96 + i), 1.1);
      end if;
    end loop;
    d := pg_temp.c10_nucleo(v_ids, 1234.57, 12);
    v_obt := format('371.33 en una obra: %s | 100.00 entre dos: %s | 940.00 entre siete: %s | 1234.57 entre doce: %s | 0.01 entre tres: %s | '
                    '999999.99 entre siete: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (8, 'EL NÚCLEO: la suma de los grupos y la de los reportes es el monto, al centavo (1, 2, 7 y 12 grupos; montos que no dividen; horas con decimales; un centavo entre tres; casi un millón), cada grupo es la suma de sus reportes y ninguno se aleja un centavo de su parte',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 9. El núcleo: los mayores restos y sus desempates, calculados a mano; y
--    es determinista (dos veces, y con los reportes dados en otro orden).
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; f text; g text; h text; v_ids bigint[]; x bigint; y bigint; z bigint;
  v_esp text := 'a 33.34, b 33.33, h 33.33 | a 3.33, b 6.67 | a 0.01, b 0.00, h 0.00 | a 0.00, b 0.02 | h 0.01, sin obra 0.00 | '
                'a 0.01, a/CO #1 0.00 | dentro del grupo, el centavo va al de la fecha más vieja | dos veces igual, y con los reportes al revés';
begin
  if pg_temp.c10_omitir(9, 'el núcleo: los mayores restos', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- tres obras con las mismas horas: el centavo que sobra va a la primera por su id
    x := pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 1);
    y := pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(0), 'c10-prueba-b', 1);
    z := pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(0), 'c10-prueba-h', 1);
    a := pg_temp.c10_grupos(array[x, y, z], 100.00);
    c := pg_temp.c10_grupos(array[x, y, z], 0.01);
    -- 1 h y 2 h: 333.33… y 666.66… centavos; el resto mayor es el de la b
    y := pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 2);
    b := pg_temp.c10_grupos(array[x, y], 10.00);
    -- restos iguales (2 centavos entre 1 h y 3 h): gana quien tiene más horas
    y := pg_temp.c10_hora(5, 'p1', pg_temp.c10_w1(2), 'c10-prueba-b', 3);
    d := pg_temp.c10_grupos(array[x, y], 0.02);
    -- empate entero entre una obra y lo sin obra: lo sin obra, el último
    y := pg_temp.c10_hora(6, 'p1', pg_temp.c10_w1(3), null, 1);
    e := pg_temp.c10_grupos(array[z, y], 0.01);
    -- empate entre la base y un CO de la misma obra: la base primero
    y := pg_temp.c10_hora(7, 'p1', pg_temp.c10_w1(4), 'c10-prueba-a', 1, 'CO #1');
    f := pg_temp.c10_grupos(array[x, y], 0.01);
    -- dentro de un grupo: dos reportes iguales, el centavo al de la fecha más vieja
    y := pg_temp.c10_hora(8, 'p1', pg_temp.c10_w1(5), 'c10-prueba-a', 1);
    select case when (select r.monto from fn_jornal_repartir_ids(array[y, x], 0.01) r where r.horas_id = x) = 0.01
                     and (select r.monto from fn_jornal_repartir_ids(array[y, x], 0.01) r where r.horas_id = y) = 0.00
                then 'dentro del grupo, el centavo va al de la fecha más vieja' else 'mal' end into g;
    -- determinista
    v_ids := array(select hh.id from horas hh where hh.usuario_id = pg_temp.c10('p1')::uuid order by hh.id);
    select case when (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id)) from fn_jornal_repartir_ids(v_ids, 777.77) r)
                     = (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id)) from fn_jornal_repartir_ids(v_ids, 777.77) r)
                     and (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id)) from fn_jornal_repartir_ids(v_ids, 777.77) r)
                       = (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id))
                            from fn_jornal_repartir_ids(array(select u from unnest(v_ids) u order by u desc), 777.77) r)
                then 'dos veces igual, y con los reportes al revés' else 'cambia' end into h;
    v_obt := concat_ws(' | ', a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (9, 'el núcleo, a mano: el centavo que sobra va al resto mayor; a resto igual, a quien tiene más horas; a horas iguales, por obra y CO (la base antes que el CO, lo sin obra al final); dentro del grupo, por fecha; y es determinista',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 10. El núcleo: con CO (el mismo CO con espacios es el mismo; un CO vacío es
--     la base), las horas sin obra (un grupo, al final, sin CO), sin horas
--     (ninguna fila), los montos mal (MX005) y por persona y período.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; f text; v_ids bigint[];
  v_esp text := 'a 40.00, a/CO #1 30.00, b 10.00, sin obra 20.00 (4 grupos ✓) | sin horas: 0 filas | monto 0 MX005, negativo MX005, con '
                'milésimas MX005, nulo MX005 | por persona y período = por sus reportes | fuera del período no entra | fechas al revés 22023';
begin
  if pg_temp.c10_omitir(10, 'el núcleo: CO, sin obra, sin horas, montos mal', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    v_ids := array[pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 4),
                   pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 2, 'CO #1'),
                   pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-a', 1, '  CO #1 '),
                   pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-b', 1, ''),
                   pg_temp.c10_hora(5, 'p1', pg_temp.c10_w1(4), null, 2, 'CO #9')];
    perform pg_temp.c10_hora(6, 'p1', pg_temp.c10_w2(0), 'c10-prueba-h', 9);   -- (otra semana)
    a := format('%s (%s)', pg_temp.c10_grupos(v_ids, 100.00), pg_temp.c10_nucleo(v_ids, 100.00, 4));
    perform pg_temp.c10_ser('dueno');
    select format('sin horas: %s filas', count(*)) into b from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100);
    begin perform count(*) from fn_jornal_repartir_ids(v_ids, 0); c := 'entró'; exception when others then c := sqlstate; end;
    begin perform count(*) from fn_jornal_repartir_ids(v_ids, -5); c := c || ', negativo entró'; exception when others then c := c || ', negativo ' || sqlstate; end;
    begin perform count(*) from fn_jornal_repartir_ids(v_ids, 10.005); c := c || ', con milésimas entró'; exception when others then c := c || ', con milésimas ' || sqlstate; end;
    begin perform count(*) from fn_jornal_repartir_ids(v_ids, null); c := c || ', nulo entró'; exception when others then c := c || ', nulo ' || sqlstate; end;
    select case when (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id))
                        from fn_jornal_repartir(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00) r)
                     = (select md5(string_agg(r::text, '|' order by r.grupo, r.horas_id)) from fn_jornal_repartir_ids(v_ids, 100.00) r)
                then 'por persona y período = por sus reportes' else 'no coinciden' end,
           case when (select count(*) from fn_jornal_repartir(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00) r
                       where r.proyecto_id = 'c10-prueba-h') = 0 then 'fuera del período no entra' else 'entró lo de otra semana' end
      into d, e;
    begin perform count(*) from fn_jornal_repartir(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(6), pg_temp.c10_w1(0), 100); f := 'entró'; exception when others then f := sqlstate; end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('%s | %s | monto 0 %s | %s | %s | fechas al revés %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (10, 'el núcleo: la base y cada CO son grupos aparte (el CO con espacios es el mismo; vacío, la base), lo sin obra es un grupo al final y sin CO, sin horas no hay filas, un monto mal da MX005, y por persona y período da lo mismo que por sus reportes',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- LA REGLA DEL PERÍODO
-- ---------------------------------------------------------------------
-- 11. Cada día de la semana: de lunes a miércoles, la semana anterior (de
--     lunes a domingo); de jueves a domingo, la semana en curso.
do $$
declare
  v_obt text;
  v_esp text := 'lun 2-nov → 26-oct a 1-nov (anterior) | mar 3-nov → 26-oct a 1-nov (anterior) | mié 4-nov → 26-oct a 1-nov (anterior) | '
                'jue 5-nov → 2-nov a 8-nov (en curso) | vie 6-nov → 2-nov a 8-nov (en curso) | sáb 7-nov → 2-nov a 8-nov (en curso) | '
                'dom 8-nov → 2-nov a 8-nov (en curso)';
begin
  begin
    perform pg_temp.c10_ser('editor');
    select string_agg(format('%s %s → %s a %s (%s)', (array['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'])[extract(isodow from g.d)::int],
                             fn_jornal_dia(g.d::date), fn_jornal_dia(p.desde), fn_jornal_dia(p.hasta),
                             case p.regla when 'semana_anterior' then 'anterior' when 'semana_en_curso' then 'en curso' else p.regla end),
                      ' | ' order by g.d)
      into v_obt
      from generate_series(date '2026-11-02', date '2026-11-08', interval '1 day') g(d)
      cross join lateral fn_jornal_periodo(g.d::date) p;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (11, 'la regla del período, cada día de la semana: pago de lunes a miércoles → la semana anterior (lunes a domingo); de jueves a domingo → la semana en curso',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 12. El cambio de hora (1-nov-2026 y 14-mar-2027), el fin de año, el 29 de
--     febrero; 400 días seguidos siempre de lunes a domingo; y lo mismo con
--     la sesión en otra zona horaria (la regla es de fechas, no de horas).
do $$
declare
  v_obt text; a text; b text; c text; d text;
  v_esp text := 'dom 1-nov-2026 → 26-oct a 1-nov-2026 (en curso) | lun 2-nov-2026 → 26-oct a 1-nov-2026 (anterior) | dom 14-mar-2027 → '
                '8-mar a 14-mar-2027 (en curso) | lun 15-mar-2027 → 8-mar a 14-mar-2027 (anterior) | jue 31-dic-2026 → 28-dic a 3-ene-2027 '
                '(en curso) | lun 4-ene-2027 → 28-dic a 3-ene-2027 (anterior) | mar 29-feb-2028 → 21-feb a 27-feb-2028 (anterior) | 400 días '
                'seguidos: siempre de lunes a domingo, la semana del pago o la de antes | igual en Kiritimati, en Los Ángeles y en UTC';
begin
  begin
    perform pg_temp.c10_ser('editor');
    select string_agg(format('%s %s → %s a %s (%s)', (array['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'])[extract(isodow from g.d)::int],
                             fn_jornal_dia(g.d, true), fn_jornal_dia(p.desde), fn_jornal_dia(p.hasta, true),
                             case p.regla when 'semana_anterior' then 'anterior' else 'en curso' end), ' | ' order by g.o)
      into a
      from unnest(array[date '2026-11-01', date '2026-11-02', date '2027-03-14', date '2027-03-15', date '2026-12-31', date '2027-01-04',
                        date '2028-02-29']) with ordinality as g(d, o)
      cross join lateral fn_jornal_periodo(g.d) p;
    select case when count(*) = 400
                     and bool_and(extract(isodow from p.desde) = 1 and p.hasta = p.desde + 6
                                  and ((p.regla = 'semana_en_curso' and g.d::date between p.desde and p.hasta and extract(isodow from g.d) >= 4)
                                       or (p.regla = 'semana_anterior' and g.d::date between p.desde + 7 and p.desde + 9)))
                then '400 días seguidos: siempre de lunes a domingo, la semana del pago o la de antes' else 'algún día mal' end
      into b
      from generate_series(date '2026-09-30', date '2026-09-30' + 399, interval '1 day') g(d)
      cross join lateral fn_jornal_periodo(g.d::date) p;
    select md5(string_agg(p::text, '|' order by g.d)) into c
      from generate_series(date '2026-10-25', date '2027-03-20', interval '1 day') g(d) cross join lateral fn_jornal_periodo(g.d::date) p;
    set local timezone = 'Pacific/Kiritimati';
    select md5(string_agg(p::text, '|' order by g.d)) into d
      from generate_series(date '2026-10-25', date '2027-03-20', interval '1 day') g(d) cross join lateral fn_jornal_periodo(g.d::date) p;
    v_obt := case when c = d then 'Kiritimati' else 'CAMBIA en Kiritimati' end;
    set local timezone = 'America/Los_Angeles';
    select md5(string_agg(p::text, '|' order by g.d)) into d
      from generate_series(date '2026-10-25', date '2027-03-20', interval '1 day') g(d) cross join lateral fn_jornal_periodo(g.d::date) p;
    v_obt := v_obt || case when c = d then ', en Los Ángeles' else ', CAMBIA en Los Ángeles' end;
    set local timezone = 'UTC';
    select md5(string_agg(p::text, '|' order by g.d)) into d
      from generate_series(date '2026-10-25', date '2027-03-20', interval '1 day') g(d) cross join lateral fn_jornal_periodo(g.d::date) p;
    v_obt := format('%s | %s | igual en %s%s', a, b, v_obt, case when c = d then ' y en UTC' else ' y CAMBIA en UTC' end);
    raise exception using errcode = 'MXT00';   -- (la zona de la sesión vuelve a ser la que era)
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (12, 'la regla del período no se mueve con el cambio de hora (1-nov-2026, 14-mar-2027), ni en fin de año, ni el 29 de febrero, ni con la sesión en otra zona horaria; siempre una semana de lunes a domingo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 13. Las fechas a mano: la propuesta va por las horas de las fechas que se
--     pidan y dice qué regla es (la semana anterior, la del pago, o a mano);
--     y sus frenos (una sola fecha, al revés, más de 62 días).
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb; a text; b text; c text; d text; e text; f text; g text; h text; i text; v_def record;
  v_esp text := 'dos semanas atrás: a_mano, 4 h | la semana anterior a la del pago: semana_anterior, 10 h | un solo día: a_mano, 8 h | las dos '
                'semanas: a_mano, 14 h | una sola fecha 22023 | al revés 22023 | 63 días 22023 | 62 días: entra | sin fechas: la de la regla';
begin
  if pg_temp.c10_omitir(13, 'las fechas a mano', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w2(0), 'c10-prueba-a', 4);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(3), 'c10-prueba-b', 2);
    v_mov := pg_temp.c10_cargo('c10-t13', pg_temp.c10_d(), 350.00, 'Zelle payment to C10 PRUEBA ZZANA 9013');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    a := format('%s, %s h', v_j->'periodo'->>'regla', trim_scale((v_j->>'horas')::numeric));
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    b := format('%s, %s h', v_j->'periodo'->>'regla', trim_scale((v_j->>'horas')::numeric));
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(0));
    c := format('%s, %s h', v_j->'periodo'->>'regla', trim_scale((v_j->>'horas')::numeric));
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w2(0), pg_temp.c10_w1(6));
    d := format('%s, %s h', v_j->'periodo'->>'regla', trim_scale((v_j->>'horas')::numeric));
    begin perform pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), null); e := 'entró'; exception when others then e := sqlstate; end;
    begin perform pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(6), pg_temp.c10_w1(0)); f := 'entró'; exception when others then f := sqlstate; end;
    begin perform pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(6) - 62, pg_temp.c10_w1(6)); g := 'entró'; exception when others then g := sqlstate; end;
    begin
      v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(6) - 61, pg_temp.c10_w1(6));
      h := case when v_j->'periodo'->>'regla' = 'a_mano' and (v_j->>'horas')::numeric = 14 then 'entra' else 'mal: ' || (v_j->'periodo')::text end;
    exception when others then h := sqlstate; end;
    -- sin fechas: la semana que dice la regla para el día del pago (la 11 y la 12 prueban la regla)
    select * into v_def from fn_jornal_periodo(pg_temp.c10_d());
    v_j := pg_temp.c10_propuesta(v_mov);
    i := case when (v_j->'periodo'->>'desde')::date = v_def.desde and (v_j->'periodo'->>'hasta')::date = v_def.hasta
                   and v_j->'periodo'->>'regla' = v_def.regla and v_j->'periodo'->'por_defecto'->>'regla' = v_def.regla
                   and v_def.regla = case when extract(isodow from pg_temp.c10_d()) <= 3 then 'semana_anterior' else 'semana_en_curso' end
              then 'la de la regla' else 'otra: ' || (v_j->'periodo')::text end;
    v_obt := format('dos semanas atrás: %s | la semana anterior a la del pago: %s | un solo día: %s | las dos semanas: %s | una sola fecha %s | '
                    'al revés %s | 63 días %s | 62 días: %s | sin fechas: %s', a, b, c, d, e, f, g, h, i);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (13, 'las fechas a mano: la propuesta va por las horas de las fechas pedidas y nombra la regla (semana_anterior, semana_en_curso o a_mano); una sola fecha, las fechas al revés o más de 62 días, 22023; sin fechas, la semana de la regla',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- LA PROPUESTA (fn_jornal_propuesta: solo lee)
-- ---------------------------------------------------------------------
-- 14. Reconoce por el patrón y SOLO a los dados de alta: el pago de quien no
--     lo está no se reconoce (y trae el patrón que saldría y a quién se
--     parece); el nombre puede venir en la nota del banco; si casa con dos
--     personas, con ninguna; y a quien se da de baja se le deja de reconocer.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; m3 uuid; v_j jsonb; a text; b text; c text; d text; e text; f text;
  v_esp text := 'el de Zzana: reconocido (p1) | el de Zzbeto, sin dar de alta: no, sugiere «\mPRUEBA ZZBETO\M» y lo ofrece (p2) | con el nombre '
                'en la nota del banco: reconocido (p1) | si casa con dos: no, y nombra a las dos | afinado: p1 y p2 | de baja: no';
begin
  if pg_temp.c10_omitir(14, 'la propuesta reconoce por el patrón', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    m1 := pg_temp.c10_cargo('c10-t14-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9141');
    m2 := pg_temp.c10_cargo('c10-t14-2', pg_temp.c10_d(), 310.00, 'Zelle payment to C10 PRUEBA ZZBETO 9142');
    m3 := pg_temp.c10_cargo('c10-t14-3', pg_temp.c10_d(), 320.00, 'Zelle payment 9143 C10 PRUEBA', 'C10 PRUEBA ZZANA semana');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(m1);
    a := case when (v_j->>'reconocido')::boolean then format('reconocido (%s)', (select k from _c10 where v = v_j->'persona'->>'usuario_id')) else 'no' end;
    v_j := pg_temp.c10_propuesta(m2);
    b := case when (v_j->>'reconocido')::boolean then 'reconocido'
              else format('no, sugiere «%s» y lo ofrece (%s)', v_j->>'patron_sugerido',
                          (select string_agg((select k from _c10 where v = q->>'usuario_id'), ',') from jsonb_array_elements(v_j->'candidatos') q)) end;
    v_j := pg_temp.c10_propuesta(m3);
    c := case when (v_j->>'reconocido')::boolean then format('reconocido (%s)', (select k from _c10 where v = v_j->'persona'->>'usuario_id')) else 'no: ' || (v_j->>'por_que') end;
    -- un patrón demasiado ancho en la segunda persona: el pago de Zzana casa con las dos
    perform pg_temp.c10_alta('p2', '\mPRUEBA ZZ');
    v_j := pg_temp.c10_propuesta(m1);
    d := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' like '%casa con 2 personas%' and v_j->>'por_que' like '%Zzana C10 PRUEBA y Zzbeto C10 PRUEBA%'
              then 'no, y nombra a las dos' else coalesce(v_j->>'por_que', 'reconocido') end;
    perform pg_temp.c10_alta('p2');
    e := format('%s y %s', (select k from _c10 where v = pg_temp.c10_propuesta(m1)->'persona'->>'usuario_id'),
                (select k from _c10 where v = pg_temp.c10_propuesta(m2)->'persona'->>'usuario_id'));
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p1'), 'activa', false));
    perform pg_temp.c10_ser('editor');
    f := case when (pg_temp.c10_propuesta(m1)->>'reconocido')::boolean then 'sigue reconocido' else 'no' end;
    v_obt := format('el de Zzana: %s | el de Zzbeto, sin dar de alta: %s | con el nombre en la nota del banco: %s | si casa con dos: %s | afinado: %s | '
                    'de baja: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (14, 'la propuesta reconoce el pago por el patrón y solo a los dados de alta: sin alta no (con el patrón que saldría y el perfil al que se parece); el nombre vale también en la nota del banco; si casa con dos personas, con ninguna; de baja, tampoco',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 15. No es un abono, ni un movimiento ya resuelto (ignorado, clasificado a
--     mano en la Bandeja, o ya repartido), ni uno que no existe.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; m3 uuid; m4 uuid; v_j jsonb; v_r jsonb; a text; b text; c text; d text; e text; f text;
  v_esp text := 'un abono: no (es un abono) | ignorado: no (resuelto en el banco) | clasificado a mano: no (resuelto en el banco) | ya repartido: '
                'no, y trae su reparto | no existe: no | sin movimiento 22023 | entre los pendientes: ninguno de los cuatro';
begin
  if pg_temp.c10_omitir(15, 'la propuesta: ni abono ni movimiento resuelto', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    m1 := pg_temp.c10_cargo('c10-t15-1', pg_temp.c10_d(), -500.00, 'Zelle payment from C10 PRUEBA ZZANA 9151');
    m2 := pg_temp.c10_cargo('c10-t15-2', pg_temp.c10_d(), 111.11, 'Zelle payment to C10 PRUEBA ZZANA 9152');
    m3 := pg_temp.c10_cargo('c10-t15-3', pg_temp.c10_d(), 122.22, 'Zelle payment to C10 PRUEBA ZZANA 9153');
    m4 := pg_temp.c10_cargo('c10-t15-4', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9154');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_ignorar(m2, 'c10-pruebas: no era de la empresa (se deshace)');
    perform fn_banco_clasificar(m3, '[{"cuenta": "5200", "proyecto_id": "c10-prueba-b"}]'::jsonb, 'c10-pruebas: un subcontrato de verdad');
    perform pg_temp.c10_ser('editor');
    v_r := pg_temp.c10_aplicar(m4, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_j := pg_temp.c10_propuesta(m1);
    a := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' like 'Es un abono%' then 'no (es un abono)' else v_j::text end;
    v_j := pg_temp.c10_propuesta(m2);
    b := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' like 'Este movimiento ya está resuelto en el banco%' then 'no (resuelto en el banco)' else v_j::text end;
    v_j := pg_temp.c10_propuesta(m3);
    c := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' like 'Este movimiento ya está resuelto en el banco%' then 'no (resuelto en el banco)' else v_j::text end;
    v_j := pg_temp.c10_propuesta(m4);
    d := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' like 'Este pago ya está repartido%'
                   and v_j->'reparto'->>'reparto_id' = v_r->>'reparto_id' then 'no, y trae su reparto' else v_j::text end;
    v_j := pg_temp.c10_propuesta('00000000-0000-4000-a000-0000000c10fe');
    e := case when not (v_j->>'reconocido')::boolean and v_j->>'por_que' = 'No existe ese movimiento del banco.' then 'no' else v_j::text end;
    begin perform pg_temp.c10_propuesta(null); f := 'entró'; exception when others then f := sqlstate; end;
    perform pg_temp.c10_ser('dueno');
    v_obt := format('un abono: %s | ignorado: %s | clasificado a mano: %s | ya repartido: %s | no existe: %s | sin movimiento %s | entre los '
                    'pendientes: %s', a, b, c, d, e, f,
                    (select case when count(*) = 0 then 'ninguno de los cuatro' else count(*)::text end
                       from v_jornal_pendientes p where p.movimiento_id in (m1, m2, m3, m4)));
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (15, 'la propuesta no reconoce un abono, ni un movimiento ya resuelto en el banco (ignorado o clasificado a mano), ni uno ya repartido (trae su reparto), ni uno que no existe; y ninguno sale entre los pendientes',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 16. Lo que trae la propuesta: las líneas por obra y CO que suman el pago,
--     las horas, el detalle por reporte, las dos semanas para elegir, la
--     tarifa que sale junto a la suya, y la huella: estable mientras nada
--     cambie, y otra en cuanto cambian las horas, hay un reporte nuevo o
--     cambian las fechas.
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb; v_k jsonb; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'a 8→200.00, a/CO #1 6.5→162.50, b 1.5→37.50, e 4→100.00 | 20 h, 4 reportes, 3 obras | sale a 25.00 la hora (la suya 25, desvío '
                '0) | el detalle: 5 reportes, 4 entran y suman 500.00 | las dos semanas: la anterior 20 h, la del pago 3 h | se puede aplicar, '
                'sin avisos | la huella: 32 letras, estable; otra con otras horas, con un reporte nuevo y con otras fechas';
begin
  if pg_temp.c10_omitir(16, 'lo que trae la propuesta', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8, null, 'rough');
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 6.5, 'CO #1', 'rough');
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 1.5, null, 'trim');
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-e', 4);
    perform pg_temp.c10_hora(5, 'p1', pg_temp.c10('lunes')::date, 'c10-prueba-h', 3);   -- (la semana del pago)
    v_mov := pg_temp.c10_cargo('c10-t16', pg_temp.c10_d(), 500.00, 'Zelle payment to C10 PRUEBA ZZANA 9016');
    perform pg_temp.c10_alta('p1');
    -- (las dos semanas se piden juntas para ver los cinco reportes: los de la del pago no entran)
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := pg_temp.c10_lineas(v_j);
    b := format('%s h, %s reportes, %s obras', trim_scale((v_j->>'horas')::numeric), v_j->>'reportes', v_j->>'obras');
    c := format('sale a %s la hora (la suya %s, desvío %s)', v_j->>'tarifa_sale', v_j->>'tarifa_equipo', trim_scale((v_j->>'tarifa_desvio_pct')::numeric));
    v_k := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10('lunes')::date + 6, '{}'::jsonb);
    select format('%s reportes, %s entran y suman %s', jsonb_array_length(v_k->'detalle'),
                  (select count(*) from jsonb_array_elements(v_j->'detalle') x where (x->>'entra')::boolean),
                  (select sum((x->>'monto')::numeric) from jsonb_array_elements(v_j->'detalle') x where (x->>'entra')::boolean))
      into d;
    select format('la anterior %s h, la del pago %s h',
                  (select trim_scale((o->>'horas')::numeric) from jsonb_array_elements(v_j->'periodo'->'opciones') o where o->>'regla' = 'semana_anterior'),
                  (select trim_scale((o->>'horas')::numeric) from jsonb_array_elements(v_j->'periodo'->'opciones') o where o->>'regla' = 'semana_en_curso'))
      into e;
    f := case when (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' is null and pg_temp.c10_avisos(v_j) = '-' then 'se puede aplicar, sin avisos'
              else format('puede %s, avisos %s', v_j->>'puede_aplicar', pg_temp.c10_avisos(v_j)) end;
    g := case when v_j->>'visto' ~ '^[0-9a-f]{32}$' then '32 letras' else 'rara' end
         || case when pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6))->>'visto' = v_j->>'visto' then ', estable' else ', NO estable' end;
    begin
      perform pg_temp.c10_corregir(1, 'horas = 7');
      g := g || case when pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6))->>'visto' <> v_j->>'visto' then '; otra con otras horas' else '; la MISMA con otras horas' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      perform pg_temp.c10_hora(6, 'p1', pg_temp.c10_w1(5), 'c10-prueba-a', 1);
      g := g || case when pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6))->>'visto' <> v_j->>'visto' then ', con un reporte nuevo' else ', la MISMA con un reporte nuevo' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    g := g || case when pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(5))->>'visto' <> v_j->>'visto' then ' y con otras fechas' else ' y la MISMA con otras fechas' end;
    v_obt := format('%s | %s | %s | el detalle: %s | las dos semanas: %s | %s | la huella: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (16, 'lo que trae la propuesta: las líneas por obra y CO (suman el pago), las horas, los reportes y las obras, la tarifa que sale junto a la de Costos del equipo, el detalle por reporte, las dos semanas para elegir con sus horas, y la huella (estable; cambia con las horas, con un reporte nuevo y con las fechas)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 17. Los avisos (a): sin horas en esas fechas (no deja aplicar); la tarifa
--     que sale lejos de la suya (un aviso, nunca un freno; el umbral se
--     cambia); y la persona sin tarifa.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; m3 uuid; m4 uuid; v_j jsonb; a text; b text; c text; d text; e text; f text;
  v_esp text := 'sin horas: no deja y lo dice [sin_horas] | 40.00 la hora contra 25: avisa (60 % más) y deja [tarifa_lejos] | con el umbral en '
                '80: no avisa [-] | 15.00 la hora: avisa (40 % menos) [tarifa_lejos] | 26.00 la hora: no avisa [-] | sin tarifa: avisa y deja '
                '[sin_tarifa]';
begin
  if pg_temp.c10_omitir(17, 'los avisos: sin horas, la tarifa, sin tarifa', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w2(0), 'c10-prueba-a', 10);
    perform pg_temp.c10_hora(2, 'p3', pg_temp.c10_w2(1), 'c10-prueba-a', 5);
    m1 := pg_temp.c10_cargo('c10-t17-1', pg_temp.c10_d(), 400.00, 'Zelle payment to C10 PRUEBA ZZANA 9171');
    m2 := pg_temp.c10_cargo('c10-t17-2', pg_temp.c10_d(), 150.00, 'Zelle payment to C10 PRUEBA ZZANA 9172');
    m3 := pg_temp.c10_cargo('c10-t17-3', pg_temp.c10_d(), 260.00, 'Zelle payment to C10 PRUEBA ZZANA 9173');
    m4 := pg_temp.c10_cargo('c10-t17-4', pg_temp.c10_d(), 100.00, 'Zelle payment to C10 PRUEBA ZZCARO 9174');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_alta('p3');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"aviso_tarifa_pct": 25}');
    perform pg_temp.c10_ser('editor');
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s [%s]', case when not (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' like '%no tiene horas reportadas%' then 'no deja y lo dice' else 'mal: ' || coalesce(v_j->>'por_que', 'deja') end,
                pg_temp.c10_avisos(v_j));
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    b := format('%s la hora contra %s: %s y %s [%s]', v_j->>'tarifa_sale', v_j->>'tarifa_equipo',
                case when pg_temp.c10_aviso(v_j, 'tarifa_lejos') like '%(60 % más)%' and pg_temp.c10_aviso(v_j, 'tarifa_lejos') like '%Es solo un aviso%' then 'avisa (60 % más)' else 'no lo dice bien' end,
                case when (v_j->>'puede_aplicar')::boolean then 'deja' else 'NO deja' end, pg_temp.c10_avisos(v_j));
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"aviso_tarifa_pct": 80}');
    perform pg_temp.c10_ser('editor');
    c := format('%s [%s]', case when pg_temp.c10_aviso(pg_temp.c10_propuesta(m1, pg_temp.c10_w2(0), pg_temp.c10_w2(6)), 'tarifa_lejos') is null then 'no avisa' else 'avisa' end,
                pg_temp.c10_avisos(pg_temp.c10_propuesta(m1, pg_temp.c10_w2(0), pg_temp.c10_w2(6))));
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"aviso_tarifa_pct": 25}');
    perform pg_temp.c10_ser('editor');
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    d := format('%s la hora: %s [%s]', v_j->>'tarifa_sale',
                case when pg_temp.c10_aviso(v_j, 'tarifa_lejos') like '%(40 % menos)%' then 'avisa (40 % menos)' else 'no lo dice bien' end, pg_temp.c10_avisos(v_j));
    v_j := pg_temp.c10_propuesta(m3, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    e := format('%s la hora: %s [%s]', v_j->>'tarifa_sale', case when pg_temp.c10_aviso(v_j, 'tarifa_lejos') is null then 'no avisa' else 'avisa' end,
                pg_temp.c10_avisos(v_j));
    v_j := pg_temp.c10_propuesta(m4, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    f := format('%s y %s [%s]', case when pg_temp.c10_aviso(v_j, 'sin_tarifa') like '%no tiene tarifa en Costos del equipo%' and v_j->'tarifa_equipo' = 'null'::jsonb then 'avisa' else 'no avisa' end,
                case when (v_j->>'puede_aplicar')::boolean then 'deja' else 'NO deja' end, pg_temp.c10_avisos(v_j));
    v_obt := format('sin horas: %s | %s | con el umbral en 80: %s | %s | %s | sin tarifa: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (17, 'los avisos: sin horas en esas fechas no deja aplicar; la tarifa que sale lejos de la de Costos del equipo avisa en llano (cuánto más o menos) y deja; el umbral se cambia; dentro del umbral no avisa; sin tarifa, avisa y deja',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 18. Los avisos (b): horas en una obra terminada o cancelada (avisa y
--     deja: su parte va a esa obra), en una sin aprobar; horas sin obra sin
--     la cuenta fijada (no deja) y con ella (deja); y una cuenta que ya no
--     sirve (no deja).
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_sin text; a text; b text; c text; d text; e text; f text;
  v_esp text;
begin
  if pg_temp.c10_omitir(18, 'los avisos: la obra y las cuentas', 'obra terminada, obra sin aprobar, falta la cuenta de lo sin obra, una cuenta que no sirve') then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    select c2.codigo into v_sin from cuentas c2
     where fn_jornal_cuenta_mal(c2.codigo, 'sin_obra') is null order by (c2.codigo = '7900') desc, c2.codigo limit 1;
    v_esp := format('terminada y no aprobada: avisa (C terminada, D no aprobada) y deja | sin aprobar: avisa (G) y deja | sin obra y sin su '
                    'cuenta: no deja [falta_cuenta_sin_obra], 3 h y 75.00 | con su cuenta (%s): deja [-] | la cuenta de la persona ya no '
                    'sirve: no deja [cuenta_mal] | la de lo sin obra ya no sirve: no deja [cuenta_mal]', v_sin);
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-c', 4);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-d', 2);
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-g', 2);
    perform pg_temp.c10_hora(5, 'p1', pg_temp.c10_w2(0), 'c10-prueba-a', 5);
    perform pg_temp.c10_hora(6, 'p1', pg_temp.c10_w2(1), null, 3);
    m1 := pg_temp.c10_cargo('c10-t18-1', pg_temp.c10_d(), 400.00, 'Zelle payment to C10 PRUEBA ZZANA 9181');
    m2 := pg_temp.c10_cargo('c10-t18-2', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9182');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"cuenta_sin_obra": null}');
    perform pg_temp.c10_ser('editor');
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s y %s', case when pg_temp.c10_aviso(v_j, 'obra_terminada') like '%C10 PRUEBA Obra C (terminada)%'
                                     and pg_temp.c10_aviso(v_j, 'obra_terminada') like '%C10 PRUEBA Obra D (no aprobada)%'
                                     and pg_temp.c10_aviso(v_j, 'obra_terminada') like '%Su parte va a esa obra igual%' then 'avisa (C terminada, D no aprobada)' else 'no lo dice bien' end,
                case when (v_j->>'puede_aplicar')::boolean then 'deja' else 'NO deja' end);
    b := format('%s y %s', case when pg_temp.c10_aviso(v_j, 'obra_sin_aprobar') like '%C10 PRUEBA Obra G (estimando)%' then 'avisa (G)' else 'no lo dice bien' end,
                case when (v_j->>'puede_aplicar')::boolean and pg_temp.c10_avisos(v_j) = 'obra_terminada,obra_sin_aprobar' then 'deja' else 'NO deja o sobran avisos: ' || pg_temp.c10_avisos(v_j) end);
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    c := format('%s [%s], %s h y %s', case when not (v_j->>'puede_aplicar')::boolean and (v_j->'sin_obra'->>'falta_cuenta')::boolean
                                               and v_j->>'por_que' like '%no tienen obra%' then 'no deja' else 'DEJA' end,
                pg_temp.c10_avisos(v_j), trim_scale((v_j->'sin_obra'->>'horas')::numeric), v_j->'sin_obra'->>'monto');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config(jsonb_build_object('cuenta_sin_obra', v_sin));
    perform pg_temp.c10_ser('editor');
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    d := format('%s [%s]', case when (v_j->>'puede_aplicar')::boolean and v_j->'sin_obra'->>'cuenta' = v_sin then 'deja' else 'NO deja' end, pg_temp.c10_avisos(v_j));
    -- una cuenta que dejó de servir después (escrita aquí por debajo de fn_jornal_persona / fn_jornal_config, con la marca)
    begin
      perform set_config('mx_jornal.escribe', 'jornal_personas', true);
      update jornal_personas set cuenta = '5000' where usuario_id = pg_temp.c10('p1')::uuid;
      perform set_config('mx_jornal.escribe', '', true);
      v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
      e := format('%s [%s]', case when not (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' like 'La cuenta del jornal de Zzana C10 PRUEBA no sirve%' then 'no deja' else 'DEJA' end,
                  (select string_agg(a2->>'codigo', ',') from jsonb_array_elements(v_j->'avisos') a2 where a2->>'codigo' = 'cuenta_mal'));
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      perform set_config('mx_jornal.escribe', 'jornal_config', true);
      update jornal_config set cuenta_sin_obra = '5200' where id = 1;
      perform set_config('mx_jornal.escribe', '', true);
      v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
      f := format('%s [%s]', case when not (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' like 'La cuenta de lo sin obra ya no sirve%' then 'no deja' else 'DEJA' end,
                  pg_temp.c10_avisos(v_j));
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('terminada y no aprobada: %s | sin aprobar: %s | sin obra y sin su cuenta: %s | con su cuenta (%s): %s | la cuenta de la persona '
                    'ya no sirve: %s | la de lo sin obra ya no sirve: %s', a, b, c, v_sin, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (18, 'los avisos: horas en una obra terminada o no aprobada —como la llama la app; no «cancelada»— (avisa y deja: su parte va a esa obra) o sin aprobar; horas sin obra sin la cuenta fijada (no deja, y dice cuántas horas y cuánto) y con ella (deja); una cuenta que ya no sirve (no deja)',
    coalesce(v_esp, '-'), v_obt, v_obt = v_esp);
end $$;

-- 19. Los avisos (c): las horas que ya cubre otro pago no entran otra vez
--     (todas cubiertas: no deja; con horas nuevas: solo por las nuevas);
--     «es otro pago de las mismas horas» las mete porque Edgar lo pide; y
--     las fechas posteriores al pago.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; m3 uuid; v_j jsonb; a text; b text; c text; d text;
  v_esp text := 'todo cubierto: no deja (ya entraron en otro reparto) [sin_horas,se_pisa] | con 3 h nuevas, solo por ellas: h 3→75.00 '
                '[horas_cubiertas,se_pisa], cubiertas 12 h en 2 reportes | «es otro pago de las mismas horas»: a 8→40.00, b 4→20.00, h '
                '3→15.00 [horas_cubiertas,se_pisa,tarifa_lejos] | fechas posteriores al pago: avisa [sin_horas,horas_tardias,periodo_futuro]';
begin
  if pg_temp.c10_omitir(19, 'los avisos: horas ya cubiertas y fechas posteriores', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    m1 := pg_temp.c10_cargo('c10-t19-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9191');
    m2 := pg_temp.c10_cargo('c10-t19-2', pg_temp.c10_d(), 75.00, 'Zelle payment to C10 PRUEBA ZZANA 9192');
    m3 := pg_temp.c10_cargo('c10-t19-3', pg_temp.c10_d(), 90.00, 'Zelle payment to C10 PRUEBA ZZANA 9193');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s [%s]', case when not (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' like '%ya entraron en otro reparto%' then 'no deja (ya entraron en otro reparto)' else 'DEJA' end,
                pg_temp.c10_avisos(v_j));
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(4), 'c10-prueba-h', 3);
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    b := format('%s [%s], cubiertas %s h en %s reportes', pg_temp.c10_lineas(v_j), pg_temp.c10_avisos(v_j),
                trim_scale((v_j->'cubiertas'->>'horas')::numeric), v_j->'cubiertas'->>'reportes');
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"incluir_cubiertas": true}');
    c := format('%s [%s]', pg_temp.c10_lineas(v_j), pg_temp.c10_avisos(v_j));
    v_j := pg_temp.c10_propuesta(m3, pg_temp.c10_d() + 1, pg_temp.c10_d() + 7);
    d := format('%s [%s]', case when pg_temp.c10_aviso(v_j, 'periodo_futuro') like '%empiezan después del día del pago%' then 'avisa' else 'no avisa' end,
                pg_temp.c10_avisos(v_j));
    v_obt := format('todo cubierto: %s | con 3 h nuevas, solo por ellas: %s | «es otro pago de las mismas horas»: %s | fechas posteriores al '
                    'pago: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (19, 'los avisos: las horas que ya cubre otro pago no entran otra vez (si todas lo están, no deja; con horas nuevas reparte solo por ellas y dice cuáles cubre el otro); con «incluir_cubiertas» entran porque Edgar lo pide; y avisa de unas fechas posteriores al pago',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 20. Los avisos (d): un posible duplicado sin decidir (el banco trajo el
--     mismo pago con otro número: no deja hasta que Edgar diga), y un mes
--     con devengo estándar de horas (c3: avisa de que saldría dos veces; con
--     el c3 de la Fase 11c, 14-nov, avisa de que al aceptar el devengo se
--     pone al día solo y nada sale dos veces: lo que de verdad pasa).
--     (En un mes con nómina el devengo lo pone la prueba, como lo deja c3:
--     arriba, «EL DEVENGO DE LAS PRUEBAS 20 Y 39».)
do $$
declare
  v_obt text; m1 uuid; m2 uuid; m3 uuid; v_j jsonb; a text; b text; c text; d text; v_mes text; v_dia date; v_dev jsonb; v_no text;
  v_esp text := 'el parecido: posible duplicado, no deja [posible_duplicado] | el primero: deja | dicho «no es el mismo»: deja [-] | con el '
                'devengo estándar de ese mes: avisa, con el mes y su asiento [devengo_estandar]';
begin
  if pg_temp.c10_omitir(20, 'los avisos: posible duplicado y devengo estándar', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- (el devengo, en el mes del pago, que está abierto: el día 1, con otra persona para no mezclar)
    v_dia := date_trunc('month', pg_temp.c10_d())::date;
    v_mes := to_char(v_dia, 'YYYY-MM');
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', v_dia, 'c10-prueba-b', 6);
    m1 := pg_temp.c10_cargo('c10-t20-1', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9201');
    m2 := pg_temp.c10_cargo('c10-t20-1b', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9201');
    m3 := pg_temp.c10_cargo('c10-t20-3', pg_temp.c10_d(), 144.00, 'Zelle payment to C10 PRUEBA ZZBETO 9203');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_alta('p2');
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s [%s]', case when not (v_j->>'puede_aplicar')::boolean and v_j->>'por_que' like '%falta decir si es el mismo%' then 'posible duplicado, no deja'
                                else 'mal: ' || coalesce(v_j->>'por_que', 'deja') end, pg_temp.c10_avisos(v_j));
    b := case when (pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6))->>'puede_aplicar')::boolean then 'deja' else 'NO deja' end;
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_duplicado(m2, false, 'c10-pruebas: son dos pagos distintos (se deshace)');
    perform pg_temp.c10_ser('editor');
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    c := format('%s [%s]', case when (v_j->>'puede_aplicar')::boolean then 'deja' else 'NO deja: ' || (v_j->>'por_que') end, pg_temp.c10_avisos(v_j));
    -- el devengo estándar del mes de esas horas (aprobadas antes, como pide c3; con nómina en el mes, puesto por la prueba)
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_horas_aprobar(pg_temp.c10('p2')::uuid, v_dia, v_dia, '{"ids": [-1010000002]}'::jsonb);
      perform pg_temp.c10_ser('editor');
      v_dev := pg_temp.c10_devengar(v_mes, array[-1010000002]::bigint[]);
    exception when others then
      v_no := sqlstate || ': ' || sqlerrm;
      perform pg_temp.c10_ser('editor');
    end;
    if v_no is null then
      v_j := pg_temp.c10_propuesta(m3, v_dia, v_dia);
      -- (con el c3 que lo pone al día solo, el aviso dice eso y no manda a retirar nada; con el de antes, «saldría dos veces»)
      d := format('%s [%s]', case when pg_temp.c10_aviso(v_j, 'devengo_estandar') like '%' || v_mes || ' (asiento ' || (v_dev->>'asiento') || ')%'
                                       and case when pg_temp.c10_c3_aparta()
                                                then pg_temp.c10_aviso(v_j, 'devengo_estandar') like '%se pone al día solo%'
                                                     and pg_temp.c10_aviso(v_j, 'devengo_estandar') like '%nada sale dos veces%'
                                                     and pg_temp.c10_aviso(v_j, 'devengo_estandar') not like '%retirarlo%'
                                                else pg_temp.c10_aviso(v_j, 'devengo_estandar') like '%saldría dos veces%' end
                                  then 'avisa, con el mes y su asiento' else 'no lo dice bien: ' || coalesce(pg_temp.c10_aviso(v_j, 'devengo_estandar'), '(sin aviso)') end,
                  pg_temp.c10_avisos(v_j));
      v_obt := format('el parecido: %s | el primero: %s | dicho «no es el mismo»: %s | con el devengo estándar de ese mes: %s', a, b, c, d);
    else
      v_obt := format('omitida: %s (%s); lo demás: el parecido: %s | el primero: %s | dicho «no es el mismo»: %s',
                      case when pg_temp.c10_mes_con_nomina(v_mes)
                           then format('%s tiene nómina y el libro no dejó poner el devengo de la prueba', v_mes)
                           else format('c3 no dejó devengar %s', v_mes) end, left(v_no, 300), a, b, c);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (20, 'los avisos: un posible duplicado sin decidir no deja aplicar hasta que Edgar diga si es el mismo; y un mes con devengo estándar de horas (c3) avisa de que la mano de obra saldría dos veces, con el mes y su asiento',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 21. La IA (c8) sigue proponiendo para estos pagos: si el movimiento tiene
--     una propuesta suya pendiente, la propuesta, la vista y aplicar la
--     devuelven (la pantalla la rechaza por la función de borde); c8 no la
--     cierra sola, y ninguno de sus cuadres se pone en rojo.
do $$
declare
  v_obt text; v_mov uuid; v_p uuid; v_j jsonb; v_r jsonb; v_antes text[]; v_ahora text[]; a text; b text; c text; d text;
  v_esp text := 'la propuesta la trae | la vista de pendientes también | aplicar la devuelve | c8 la deja pendiente (la rechaza la pantalla) | '
                'cuadres de c8 que pasan a rojo: ninguno';
begin
  if pg_temp.c10('hay_c8') <> 'true' then
    insert into _pruebas values (21, 'la propuesta pendiente de la IA (c8) de un pago se devuelve y nada de c8 se rompe', v_esp,
                                 'omitida: c8 no está en esta base', null);
    return;
  end if;
  if pg_temp.c10_omitir(21, 'la propuesta pendiente de la IA (c8)', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t21', pg_temp.c10_d(), 210.00, 'Zelle payment to C10 PRUEBA ZZANA 9021');
    perform pg_temp.c10_alta('p1');
    -- (una propuesta pendiente de c8 para ese movimiento, como la deja su rutina)
    execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta)
                values ($1, 'edgar', '{"lineas": [{"cuenta": "5200"}], "motivo": "C10 PRUEBA", "confianza": 1, "flags": {"pide_obra": true}}'::jsonb)
                returning id $q$ into v_p using v_mov;
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_antes;
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := case when (v_j->>'propuesta_ia')::uuid = v_p then 'la trae' else 'no la trae' end;
    perform pg_temp.c10_ser('dueno');
    -- (la vista va por la semana de la regla; la propuesta de la IA sale igual)
    b := case when (select p.propuesta_ia from v_jornal_pendientes p where p.movimiento_id = v_mov) = v_p then 'también' else 'no' end;
    perform pg_temp.c10_ser('editor');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    c := case when (v_r->>'propuesta_ia')::uuid = v_p then 'la devuelve' else 'no la devuelve' end;
    execute $q$ select p.estado from public.contador_propuestas p where p.id = $1 $q$ into d using v_p;
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_ahora;
    v_obt := format('la propuesta %s | la vista de pendientes %s | aplicar %s | c8 la deja %s (la rechaza la pantalla) | cuadres de c8 que '
                    'pasan a rojo: %s', a, b, c, d, pg_temp.c10_nuevos(v_antes, v_ahora));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (21, 'la IA (c8) sigue proponiendo para estos pagos: su propuesta pendiente sale en la propuesta, en la vista de pendientes y en lo que devuelve aplicar (para que la pantalla la rechace); c8 no la cierra sola y ninguno de sus cuadres pasa a rojo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- APLICAR («Así es»: fn_jornal_aplicar)
-- ---------------------------------------------------------------------
-- 22. El asiento: por el camino del banco (c6), la línea del banco y una
--     por obra y CO a la cuenta del jornal, cada una con su obra, su CO y la
--     persona (tercero empleado); el movimiento queda casado con él; y el
--     reparto, sus partes y su detalle por reporte quedan guardados.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_as asientos; v_rep jornal_repartos; v_m movimientos_banco; v_j jsonb;
  a text; b text; c text; d text; e text; f text;
  v_esp text := 'el asiento: puente / movimientos_banco, el día del pago, a nombre del dueño, «Clasificado por Edgar: Zelle…» | 1 1010 '
                '-500.00 | 2 5200 200.00 a empleado:p1 | 3 5200 162.50 a/CO #1 empleado:p1 | 4 5200 37.50 b empleado:p1 | 5 5200 100.00 e '
                'empleado:p1 | cada línea dice de quién y de qué semana | el movimiento: casado (clasificado) con ese asiento | el reparto: '
                'aplicado, 500.00, 20 h, 25.00 la hora (la suya 25), semana_anterior, 5200, con la huella de la propuesta, por el dueño | 4 '
                'partes (líneas 2 a 5 del asiento) y 4 reportes que suman 500.00 | lo que devuelve: el reparto, el asiento y 4 líneas | '
                'control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(22, 'aplicar: el asiento, el reparto y su detalle', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8, null, 'rough');
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 6.5, 'CO #1', 'rough');
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 1.5, null, 'trim');
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-e', 4);
    v_mov := pg_temp.c10_cargo('c10-t22', pg_temp.c10_d(), 500.00, 'Zelle payment to C10 PRUEBA ZZANA 9022');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    select * into v_rep from jornal_repartos where id = (v_r->>'reparto_id')::uuid;
    select * into v_as from asientos where id = v_rep.asiento_id;
    select * into v_m from movimientos_banco where id = v_mov;
    a := format('%s / %s, %s, %s, %s', v_as.camino, v_as.origen_tabla,
                case when v_as.fecha_contable = pg_temp.c10_d() then 'el día del pago' else v_as.fecha_contable::text end,
                case when v_as.usuario_id::text = pg_temp.c10('dueno') then 'a nombre del dueño' else 'a nombre de otro' end,
                case when v_as.descripcion like 'Clasificado por Edgar: Zelle payment to C10 PRUEBA ZZANA%' then '«Clasificado por Edgar: Zelle…»' else v_as.descripcion end);
    b := pg_temp.c10_asiento(v_as.id);
    c := case when (select bool_and(l.memo like 'Jornal de Zzana C10 PRUEBA · ' || fn_jornal_dia(pg_temp.c10_w1(0)) || ' a ' || fn_jornal_dia(pg_temp.c10_w1(6), true) || ' · % h de 20 h')
                      from asiento_lineas l where l.asiento_id = v_as.id and l.orden > 1)
              then 'cada línea dice de quién y de qué semana' else 'las notas de las líneas no lo dicen' end;
    d := format('%s (%s) %s', v_m.estado, v_m.casado_clase, case when v_m.asiento_id = v_as.id then 'con ese asiento' else 'con OTRO asiento' end);
    e := format('%s, %s, %s h, %s la hora (la suya %s), %s, %s, %s, %s', v_rep.estado, v_rep.monto, trim_scale(v_rep.horas), v_rep.tarifa_sale,
                trim_scale(v_rep.tarifa_equipo), v_rep.regla_periodo, v_rep.cuenta,
                case when v_rep.huella = v_j->>'visto' then 'con la huella de la propuesta' else 'con OTRA huella' end,
                case when v_rep.creado_por::text = pg_temp.c10('dueno') then 'por el dueño' else 'por otro' end);
    f := format('%s partes (líneas %s a %s del asiento) y %s reportes que suman %s',
                (select count(*) from jornal_reparto_lineas l where l.reparto_id = v_rep.id),
                (select min(l.orden) from jornal_reparto_lineas l where l.reparto_id = v_rep.id),
                (select max(l.orden) from jornal_reparto_lineas l where l.reparto_id = v_rep.id),
                (select count(*) from jornal_reparto_horas h where h.reparto_id = v_rep.id),
                (select sum(h.monto) from jornal_reparto_horas h where h.reparto_id = v_rep.id));
    v_obt := format('el asiento: %s | %s | %s | el movimiento: %s | el reparto: %s | %s | lo que devuelve: %s | %s', a, b, c, d, e, f,
                    case when v_r->>'estado' = 'aplicado' and v_r->'asiento'->>'numero' = v_as.numero and jsonb_array_length(v_r->'lineas') = 4
                              and v_r->>'nota' like 'Repartido: $500.00 de Zzana C10 PRUEBA%entre 3 obra(s); asiento ' || v_as.numero || '%Quedaron aprobados 4 reporte(s)%'
                         then 'el reparto, el asiento y 4 líneas' else v_r::text end,
                    pg_temp.c10_propios());
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (22, 'APLICAR: el asiento entra por el camino del banco (c6), con la línea del banco y una por obra y CO a 5200, cada una con su obra, su CO y la persona como tercero; el movimiento queda casado con él; el reparto, sus partes (con la línea de su asiento) y su detalle por reporte quedan guardados; los controles, en verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 23. «Así es» aprueba las horas que Edgar vio, por el camino de c3
--     (fn_horas_aprobar, con sus ids): quedan aprobadas por el dueño y en
--     horas_aprobaciones con lo que vio. Las que ya estaban aprobadas no se
--     tocan; y otro pago de las mismas horas no tiene nada que aprobar.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_r jsonb; v_r2 jsonb; a text; b text; c text; d text;
  v_esp text := 'antes: 1 de 3 aprobadas | aplicar aprobó las 2 que faltaban: por el dueño, por fn_horas_aprobar, con lo que vio | después: 3 de '
                '3 | el reparto dice cuáles aprobó: 2 | otro pago de las mismas horas: nada que aprobar, y entra';
begin
  if pg_temp.c10_omitir(23, 'aplicar aprueba las horas por c3', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 6);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-b', 2);
    m1 := pg_temp.c10_cargo('c10-t23-1', pg_temp.c10_d(), 400.00, 'Zelle payment to C10 PRUEBA ZZANA 9231');
    m2 := pg_temp.c10_cargo('c10-t23-2', pg_temp.c10_d(), 400.00, 'Zelle payment to C10 PRUEBA ZZANA 9232');
    perform pg_temp.c10_alta('p1');
    -- (el lunes ya lo había aprobado Edgar en Horas)
    perform pg_temp.c10_ser('dueno');
    perform fn_horas_aprobar(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(0), '{"ids": [-1010000001]}'::jsonb);
    perform pg_temp.c10_ser('editor');
    select format('%s de %s aprobadas', count(*) filter (where h.aprobado_el is not null), count(*)) into a
      from horas h where h.usuario_id = pg_temp.c10('p1')::uuid;
    v_r := pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    select format('%s: %s, %s, %s',
                  case when v_r->'horas_aprobadas'->>'reportes' = '2' and v_r->'horas_aprobadas'->'ids' = '[-1010000003, -1010000002]'::jsonb
                       then 'aplicar aprobó las 2 que faltaban' else 'aplicar dice ' || (v_r->'horas_aprobadas')::text end,
                  case when bool_and(h.aprobado_por::text = pg_temp.c10('dueno')) then 'por el dueño' else 'por otro' end,
                  case when (select count(*) from horas_aprobaciones ap
                              where ap.horas_id in (-1010000002, -1010000003) and ap.accion = 'aprobada'
                                and ap.hecho_por::text = pg_temp.c10('dueno')) = 2 then 'por fn_horas_aprobar' else 'sin su rastro' end,
                  case when (select bool_and(ap.detalle->'visto'->'ids' = '[-1010000003, -1010000002]'::jsonb) from horas_aprobaciones ap
                              where ap.horas_id in (-1010000002, -1010000003) and ap.accion = 'aprobada') then 'con lo que vio' else 'sin lo que vio' end)
      into b
      from horas h where h.id in (-1010000002, -1010000003);
    select format('%s de %s', count(*) filter (where h.aprobado_el is not null), count(*)) into c
      from horas h where h.usuario_id = pg_temp.c10('p1')::uuid;
    v_r2 := pg_temp.c10_aplicar(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"incluir_cubiertas": true}');
    d := case when v_r2->'horas_aprobadas'->>'reportes' = '0' and v_r2->>'estado' = 'aplicado' and (v_r2->>'horas')::numeric = 16
              then 'nada que aprobar, y entra' else v_r2::text end;
    v_obt := format('antes: %s | %s | después: %s | el reparto dice cuáles aprobó: %s | otro pago de las mismas horas: %s', a, b, c,
                    (select jsonb_array_length(r.horas_aprobadas) from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid), d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (23, 'aplicar aprueba por el camino de c3 (fn_horas_aprobar, con los ids que Edgar vio) las horas de esas fechas que estaban sin aprobar: quedan por el dueño y en horas_aprobaciones; el reparto guarda cuáles aprobó; otro pago de las mismas horas no aprueba nada',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 24. LA HUELLA: si entre que Edgar miró y que tocó «Así es» cambian las
--     horas (un reporte nuevo, otras horas, otra obra, uno borrado) o una
--     cuenta, o la huella no es la de la propuesta: MX011, y NADA cambia (ni
--     una hora aprobada, ni un asiento, ni un reparto; el pago sigue en la
--     Bandeja). Con la propuesta de ahora, entra.
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb; v_r jsonb; v_antes text; v_visto text; v_sin text;
  a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'un reporte nuevo MX011 | otras horas MX011 | otra obra MX011 | un reporte borrado MX011 | otra cuenta MX011 | una huella '
                'inventada MX011 | y nada cambió: sí | lo dice en llano y pide volver a mirar: sí | con la propuesta de ahora: entra';
begin
  if pg_temp.c10_omitir(24, 'la huella cambiada: MX011 y nada cambia', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), null, 1);
    select c2.codigo into v_sin from cuentas c2
     where fn_jornal_cuenta_mal(c2.codigo, 'sin_obra') is null order by (c2.codigo = '7900') desc, c2.codigo limit 1;
    v_mov := pg_temp.c10_cargo('c10-t24', pg_temp.c10_d(), 325.00, 'Zelle payment to C10 PRUEBA ZZANA 9024');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config(jsonb_build_object('cuenta_sin_obra', v_sin));
    perform pg_temp.c10_ser('editor');
    -- lo que Edgar ve
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_visto := v_j->>'visto';
    select format('%s|%s|%s|%s|%s', (select count(*) from asientos), (select count(*) from jornal_repartos),
                  (select count(*) from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null),
                  (select count(*) from horas_aprobaciones), (select m.estado from movimientos_banco m where m.id = v_mov)) into v_antes;
    -- …y lo que pasa antes de que toque
    begin
      perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-h', 2);
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_visto);
      a := 'entró';
    exception when others then a := sqlstate; g := sqlerrm;
    end;
    begin
      perform pg_temp.c10_corregir(1, 'horas = 7');
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_visto);
      b := 'entró';
    exception when others then b := sqlstate;
    end;
    begin
      perform pg_temp.c10_corregir(2, $s$proyecto_id = 'c10-prueba-h'$s$);
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_visto);
      c := 'entró';
    exception when others then c := sqlstate;
    end;
    begin
      delete from horas where id = -1010000002;
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_visto);
      d := 'entró';
    exception when others then d := sqlstate;
    end;
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_config(jsonb_build_object('cuenta_sin_obra', (select c2.codigo from cuentas c2
                                 where fn_jornal_cuenta_mal(c2.codigo, 'sin_obra') is null and c2.codigo <> v_sin order by c2.codigo limit 1)));
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_visto);
      e := 'entró';
    exception when others then e := sqlstate;
    end;
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 'c10c10c10c10c10c10c10c10c10c10c1');
      f := 'entró';
    exception when others then f := sqlstate;
    end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('un reporte nuevo %s | otras horas %s | otra obra %s | un reporte borrado %s | otra cuenta %s | una huella inventada %s | y '
                    'nada cambió: %s | lo dice en llano y pide volver a mirar: %s', a, b, c, d, e, f,
                    case when (select format('%s|%s|%s|%s|%s', (select count(*) from asientos), (select count(*) from jornal_repartos),
                                             (select count(*) from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null),
                                             (select count(*) from horas_aprobaciones), (select m.estado from movimientos_banco m where m.id = v_mov))) = v_antes
                         then 'sí' else 'NO' end,
                    case when g like 'Las horas de Zzana C10 PRUEBA % ya no son las que viste%no se aprobó ni se posteó nada. Vuelve a mirar%' then 'sí' else 'no: ' || coalesce(g, '-') end);
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_obt := v_obt || ' | con la propuesta de ahora: ' || case when v_r->>'estado' = 'aplicado' then 'entra' else 'no' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (24, 'LA HUELLA: si las horas ya no son las que Edgar vio (un reporte nuevo, otras horas, otra obra, uno borrado), o cambió una cuenta, o la huella no es la de la propuesta, aplicar da MX011 —un código nuevo— y NADA cambia; con la propuesta de ahora, entra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 25. Dos veces: la segunda falla limpia (MX008: ya está repartido) y no
--     queda nada a medias. Y los frenos de entrada (22023) y de fondo (MX008).
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_r jsonb; a text; b text; c text; d text; e text; f text; g text; h text;
  v_esp text := 'la segunda MX008 (ya está repartido) y sigue habiendo 1 reparto y 1 asiento suyo | sin huella 22023 | sin fechas 22023 | al '
                'revés 22023 | 63 días 22023 | una opción desconocida 22023 | el pago de alguien sin dar de alta MX008 | sin horas MX008';
begin
  if pg_temp.c10_omitir(25, 'aplicar dos veces, y sus frenos', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    m1 := pg_temp.c10_cargo('c10-t25-1', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9251');
    m2 := pg_temp.c10_cargo('c10-t25-2', pg_temp.c10_d(), 210.00, 'Zelle payment to C10 PRUEBA ZZBETO 9252');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    begin perform fn_jornal_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6), ''); b := 'entró'; exception when others then b := sqlstate; end;
    begin perform fn_jornal_aplicar(m1, null, null, v_j->>'visto'); c := 'entró'; exception when others then c := sqlstate; end;
    begin perform fn_jornal_aplicar(m1, pg_temp.c10_w1(6), pg_temp.c10_w1(0), v_j->>'visto'); d := 'entró'; exception when others then d := sqlstate; end;
    begin perform fn_jornal_aplicar(m1, pg_temp.c10_w1(6) - 62, pg_temp.c10_w1(6), v_j->>'visto'); e := 'entró'; exception when others then e := sqlstate; end;
    begin perform fn_jornal_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_j->>'visto', '{"incluir_cubierta": true}'); f := 'entró'; exception when others then f := sqlstate; end;
    begin perform fn_jornal_aplicar(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_j->>'visto'); g := 'entró'; exception when others then g := sqlstate; end;
    begin perform fn_jornal_aplicar(m1, pg_temp.c10_w2(0), pg_temp.c10_w2(6), v_j->>'visto'); h := 'entró'; exception when others then h := sqlstate; end;
    -- la buena, y otra vez con la misma huella (dos toques, o dos pantallas)
    v_r := fn_jornal_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_j->>'visto');
    begin
      perform fn_jornal_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_j->>'visto');
      a := 'entró';
    exception when others then a := sqlstate || case when sqlerrm like 'Este pago ya está repartido%' then ' (ya está repartido)' else ' (' || sqlerrm || ')' end;
    end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('la segunda %s y sigue habiendo %s reparto y %s asiento suyo | sin huella %s | sin fechas %s | al revés %s | 63 días %s | una '
                    'opción desconocida %s | el pago de alguien sin dar de alta %s | sin horas %s', a,
                    (select count(*) from jornal_repartos r where r.movimiento_id = m1),
                    (select count(*) from asientos x where x.origen_tabla = 'movimientos_banco' and x.origen_id = m1::text), b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (25, 'aplicar dos veces: la segunda falla limpia (MX008: ya está repartido) y queda un solo reparto y un solo asiento; sin huella, sin fechas, al revés, de más de 62 días o con una opción desconocida, 22023; el pago de alguien sin dar de alta o sin horas, MX008',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 26. Una semana toca más de 5 obras (las 5 líneas son el tope de las
--     propuestas de la IA, c8; este camino no pasa por ahí): 7 obras en un
--     asiento, y 12.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_r jsonb; v_r2 jsonb; i int; a text; b text;
  v_esp text := '7 obras: 8 líneas, las 7 a 5200 suman 940.00 en 7 obras distintas, todas con la persona | 12 obras: 13 líneas, las 12 suman '
                '1000.00 | control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(26, 'más de 5 obras en un asiento', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    for i in 1..7 loop
      perform pg_temp.c10_hora(i, 'p1', pg_temp.c10_w1(i - 1), 'c10-prueba-' || (array['a', 'b', 'e', 'f', 'h', 'i', 'j'])[i],
                               (array[8, 7.5, 6.25, 5, 3.25, 2, 0.5])[i]);
    end loop;
    for i in 1..12 loop
      perform pg_temp.c10_hora(20 + i, 'p2', pg_temp.c10_w1((i - 1) % 7), 'c10-prueba-' || chr(96 + i), 1);
    end loop;
    m1 := pg_temp.c10_cargo('c10-t26-1', pg_temp.c10_d(), 940.00, 'Zelle payment to C10 PRUEBA ZZANA 9261');
    m2 := pg_temp.c10_cargo('c10-t26-2', pg_temp.c10_d(), 1000.00, 'Zelle payment to C10 PRUEBA ZZBETO 9262');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_alta('p2');
    v_r := pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_r2 := pg_temp.c10_aplicar(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    select format('%s líneas, las %s a 5200 suman %s en %s obras distintas, %s', count(*), count(*) filter (where l.cuenta = '5200'),
                  sum(l.monto) filter (where l.cuenta = '5200'), count(distinct l.proyecto_id),
                  case when bool_and(l.tercero_id = pg_temp.c10('p1')) filter (where l.cuenta = '5200') then 'todas con la persona' else 'alguna sin la persona' end)
      into a from asiento_lineas l where l.asiento_id = (v_r->'asiento'->>'id')::uuid;
    select format('%s líneas, las %s suman %s', count(*), count(*) filter (where l.cuenta = '5200'), sum(l.monto) filter (where l.cuenta = '5200'))
      into b from asiento_lineas l where l.asiento_id = (v_r2->'asiento'->>'id')::uuid;
    v_obt := format('7 obras: %s | 12 obras: %s | %s', a, b, pg_temp.c10_propios());
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (26, 'una semana con más de 5 obras entra en UN asiento (c6 no limita las líneas; las 5 son de las propuestas de c8, por las que este camino no pasa): 7 obras, y 12',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 27. Un pago de un mes YA CERRADO: lo que dicen c6 y c2 con todo lo que el
--     banco trae tarde: el asiento entra el primer día del mes abierto, con
--     su nota; la propuesta lo avisa antes, y el reparto va igual por las
--     horas de sus fechas. (Cierra la apertura y el mes abierto más viejo que
--     ya terminó dentro de la prueba, como c2-pruebas; si el libro real no
--     deja cerrar, sale «omitida» con lo que dijo c2.)
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb; v_r jsonb; v_mes periodos; v_ap periodos; v_abre date; v_no text; a text; b text; c text;
  v_esp text := 'la propuesta lo avisa (mes_cerrado, con la fecha en que entrará) y deja | el asiento entra el primer día del mes abierto, con '
                'su nota de tardío | el reparto, por las horas de sus fechas: a 8→200.00 | control del jornal: nada nuevo en rojo; del margen: '
                'nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(27, 'un pago de un mes ya cerrado', v_esp) then return; end if;
  begin
    perform pg_temp.c10_ser('editor');
    lock table periodos in exclusive mode;
    select * into v_mes from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.hasta < fn_fecha_miami(now()) order by p.desde limit 1;
    if v_mes.periodo is null then
      -- no queda un mes terminado por cerrar: vale el último que ya esté cerrado
      select * into v_mes from periodos p where p.tipo = 'mes' and p.estado = 'cerrado' order by p.desde desc limit 1;
      if v_mes.periodo is null then
        v_no := 'no hay un mes terminado (ni abierto ni cerrado) donde poner el pago';
      end if;
    else
      begin
        select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
        if v_ap.estado = 'abierto' then
          if not exists (select 1 from asientos x where x.periodo = v_ap.periodo and x.tipo = 'apertura' and x.reversa_a is null
                            and not exists (select 1 from asientos r where r.reversa_a = x.id and r.camino = 'reverso')) then
            perform fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
              'descripcion', 'C10 PRUEBA: apertura de prueba (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1600', 'monto', '1000.00'),
                                          jsonb_build_object('cuenta', '3100', 'monto', '-1000.00'))));
          end if;
          perform fn_cerrar_periodo(v_ap.periodo);
        end if;
        perform fn_cerrar_periodo(v_mes.periodo);
      exception when others then
        v_no := format('c2 no dejó cerrar %s (%s: %s)', v_mes.periodo, sqlstate, left(sqlerrm, 300));
      end;
    end if;
    if v_no is null then
      select min(p.desde) into v_abre from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.desde > v_mes.hasta;
      perform pg_temp.c10_sembrar();
      -- (la semana del lunes anterior al último día del mes cerrado; el pago, ese último día)
      perform pg_temp.c10_hora(1, 'p1', v_mes.hasta - 9, 'c10-prueba-a', 8);
      v_mov := pg_temp.c10_cargo('c10-t27', v_mes.hasta, 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9027');
      perform pg_temp.c10_alta('p1');
      v_j := pg_temp.c10_propuesta(v_mov, v_mes.hasta - 13, v_mes.hasta - 7);
      a := format('%s y %s', case when pg_temp.c10_aviso(v_j, 'mes_cerrado') like '%ese mes ya está cerrado: el asiento entrará con fecha ' || fn_jornal_dia(v_abre, true) || '%'
                                       and (v_j->'movimiento'->>'mes_cerrado')::boolean then 'la propuesta lo avisa (mes_cerrado, con la fecha en que entrará)'
                                  else 'la propuesta no lo avisa bien: ' || pg_temp.c10_avisos(v_j) end,
                  case when (v_j->>'puede_aplicar')::boolean then 'deja' else 'NO deja: ' || (v_j->>'por_que') end);
      v_r := pg_temp.c10_aplicar(v_mov, v_mes.hasta - 13, v_mes.hasta - 7);
      b := case when (v_r->'asiento'->>'fecha_contable')::date = v_abre and v_r->>'tardio' like 'Documento tardío del ' || v_mes.hasta || '%'
                     and (select x.procedencia ? 'tardio' from asientos x where x.id = (v_r->'asiento'->>'id')::uuid)
                then 'el asiento entra el primer día del mes abierto, con su nota de tardío'
                else format('el asiento entra el %s (se esperaba el %s), tardío: %s', v_r->'asiento'->>'fecha_contable', v_abre, coalesce(v_r->>'tardio', 'no lo dice')) end;
      c := pg_temp.c10_lineas(v_r);
      v_obt := format('%s | %s | el reparto, por las horas de sus fechas: %s | %s', a, b, c, pg_temp.c10_propios());
    else
      v_obt := 'omitida: ' || v_no;
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (27, 'un pago de un mes YA CERRADO entra como c6 y c2 meten todo lo que llega tarde: el primer día del mes abierto, con su nota; la propuesta lo avisa antes (con la fecha) y el reparto va por las horas de sus fechas',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 28. La obra terminada y la cancelada reciben su parte: ni c2 ni c6 piden
--     que la obra esté activa (eso es de las propuestas de la IA); el
--     trabajo se hizo ahí, y el costo queda en esa obra.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb;
  v_esp text := 'c 4→100.00, d 4→100.00 [obra_terminada] | 1 1010 -200.00 | 2 5200 100.00 c empleado:p1 | 3 5200 100.00 d empleado:p1 | el '
                'costo queda en la terminada: 100.00, y en la no aprobada: 100.00';
begin
  if pg_temp.c10_omitir(28, 'la obra terminada y la cancelada reciben su parte', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-c', 4);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-d', 4);
    v_mov := pg_temp.c10_cargo('c10-t28', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9028');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    v_obt := format('%s [%s] | %s | el costo queda en la terminada: %s, y en la no aprobada: %s', pg_temp.c10_lineas(v_r), pg_temp.c10_avisos(v_r),
                    pg_temp.c10_asiento((v_r->'asiento'->>'id')::uuid),
                    (select o.mano_obra_jornales from v_margen_obra o where o.proyecto_id = 'c10-prueba-c' and o.estado = 'completado'),
                    (select o.costo_real from v_margen_obra o where o.proyecto_id = 'c10-prueba-d' and o.estado = 'no_aprobado'));
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (28, 'la obra terminada y la no aprobada reciben su parte (ni c2 ni c6 piden que la obra esté activa: el trabajo se hizo ahí): entra con su aviso y el costo queda en esa obra',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 29. Las horas sin obra: sin la cuenta fijada no se aplica (MX008, y nada
--     cambia); con ella, su parte va a esa cuenta, sin obra y con la
--     persona, y el reparto lo guarda.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_sin text; a text; v_antes int;
  v_esp text;
begin
  if pg_temp.c10_omitir(29, 'las horas sin obra', 'sin la cuenta no se aplica; con ella, a su cuenta') then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    select c2.codigo into v_sin from cuentas c2
     where fn_jornal_cuenta_mal(c2.codigo, 'sin_obra') is null order by (c2.codigo = '7900') desc, c2.codigo limit 1;
    v_esp := format('sin la cuenta: MX008 (dice que la fije) y nada cambia | con ella: 1 1010 -200.00 | 2 5200 150.00 a empleado:p1 | 3 %s '
                    '50.00 empleado:p1 | el reparto la guarda (%s; la parte sin obra es la línea 3) | control del jornal: nada nuevo en '
                    'rojo; del margen: nada nuevo en rojo', v_sin, v_sin);
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 6);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), null, 2);
    v_mov := pg_temp.c10_cargo('c10-t29', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9029');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"cuenta_sin_obra": null}');
    perform pg_temp.c10_ser('editor');
    select count(*) into v_antes from asientos;
    begin
      perform pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
      a := 'entró';
    exception when others then
      a := sqlstate || case when sqlerrm like '%no tienen obra%Di una vez a qué cuenta va la mano de obra sin obra%' then ' (dice que la fije)' else ' (' || sqlerrm || ')' end;
    end;
    a := a || case when (select count(*) from asientos) = v_antes and (select m.estado from movimientos_banco m where m.id = v_mov) = 'pendiente'
                        and not exists (select 1 from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null)
                   then ' y nada cambia' else ' y ALGO cambió' end;
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config(jsonb_build_object('cuenta_sin_obra', v_sin));
    perform pg_temp.c10_ser('editor');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_obt := format('sin la cuenta: %s | con ella: %s | el reparto la guarda (%s; la parte sin obra es la línea %s) | %s', a,
                    pg_temp.c10_asiento((v_r->'asiento'->>'id')::uuid),
                    (select r.cuenta_sin_obra from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid),
                    (select l.orden from jornal_reparto_lineas l where l.reparto_id = (v_r->>'reparto_id')::uuid and l.proyecto_id is null),
                    pg_temp.c10_propios());
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (29, 'las horas sin obra no pueden ir a 5200 (exige obra): sin la cuenta fijada no se aplica (MX008, nada cambia); con ella, su parte va a esa cuenta, sin obra y con la persona, y el reparto la guarda',
    coalesce(v_esp, '-'), v_obt, v_obt = v_esp);
end $$;

-- 30. Los frenos del banco VALEN: fn_jornal_aplicar llama a c6 sin motivo, y
--     lo que c6 no deja pasar sin el motivo escrito de Edgar tampoco pasa
--     aquí. Un débito que c6 toma por nómina (su descripción dice PAYROLL):
--     MX008 con el mensaje de c6, y nada cambia; con el motivo de Edgar
--     (p_opciones.motivo), entra, y el asiento lo lleva.
--     (14-nov, los arreglos de la verificación de la Fase 11c) El débito del
--     ejemplo ya no es un Zelle: con el c6 de esos arreglos UN ZELLE NUNCA
--     ES DE NÓMINA. Y se prueba lo que eso cambia aquí: el Zelle a esa misma
--     persona cuya descripción dice PAYROLL (su jornal de la semana, con
--     «payroll» en la nota) no lo frena c6 y entra por el jornal SIN motivo.
--     Con un c6 anterior esa parte sale en rojo y dice qué pegar.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_j jsonb; a text; b text; v_antes int; v_zel uuid; v_z jsonb; c text;
  v_esp text := 'c6 lo toma por nómina; la propuesta lo reconoce y deja | sin motivo: MX008, con el mensaje de c6 («dilo en el motivo»), y nada '
                'cambia | con el motivo de Edgar: entra, el asiento lo lleva y el reparto lo guarda | un Zelle a la misma persona que dice '
                'PAYROLL: c6 no lo toma por nómina (un Zelle nunca lo es) y entra por el jornal sin motivo';
begin
  if pg_temp.c10_omitir(30, 'los frenos del banco valen', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t30', pg_temp.c10_d(), 200.00, 'ACH DEBIT C10 PRUEBA ZZANA PAYROLL 9030');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s; %s', case when (select m.estado_motivo from movimientos_banco m where m.id = v_mov) = 'nomina' then 'c6 lo toma por nómina'
                               else 'c6 dice ' || coalesce((select m.estado_motivo from movimientos_banco m where m.id = v_mov), '-') end,
                case when (v_j->>'reconocido')::boolean and (v_j->>'puede_aplicar')::boolean then 'la propuesta lo reconoce y deja' else 'la propuesta no' end);
    select count(*) into v_antes from asientos;
    begin
      perform pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
      b := 'entró';
    exception when others then
      b := sqlstate || case when sqlerrm like 'Es un débito de nómina%dilo en el motivo%' then ', con el mensaje de c6 («dilo en el motivo»)' else ' (' || sqlerrm || ')' end;
    end;
    b := b || case when (select count(*) from asientos) = v_antes and (select m.estado from movimientos_banco m where m.id = v_mov) = 'pendiente'
                        and not exists (select 1 from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null)
                        and not exists (select 1 from jornal_repartos r where r.movimiento_id = v_mov)
                   then ', y nada cambia' else ', y ALGO cambió' end;
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"motivo": "c10-pruebas: es su jornal de la semana, no la nómina"}');
    -- (el Zelle que dice PAYROLL, con sus horas de la semana de antes: c6 no lo toma por nómina y el jornal lo reparte sin motivo)
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w2(0), 'c10-prueba-b', 4);
    v_zel := pg_temp.c10_cargo('c10-t30z', pg_temp.c10_d(), 100.00, 'Zelle payment to C10 PRUEBA ZZANA PAYROLL 9031');
    c := case when (select m.estado_motivo from movimientos_banco m where m.id = v_zel) is distinct from 'nomina'
              then 'c6 no lo toma por nómina (un Zelle nunca lo es)'
              else 'c6 LO TOMA POR NÓMINA (el c6 pegado es anterior a los arreglos del 14-nov: vuelve a pegar sus dos partes)' end;
    begin
      v_z := pg_temp.c10_aplicar(v_zel, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
      c := c || case when v_z->>'estado' = 'aplicado' and (select r.opciones->>'motivo' from jornal_repartos r where r.id = (v_z->>'reparto_id')::uuid) is null
                     then ' y entra por el jornal sin motivo' else ' y no entra como debe: ' || left(v_z::text, 200) end;
    exception when others then
      c := c || ' y NO entra sin motivo: ' || sqlstate || ' (' || left(sqlerrm, 160) || ')';
    end;
    v_obt := format('%s | sin motivo: %s | con el motivo de Edgar: %s | un Zelle a la misma persona que dice PAYROLL: %s', a, b,
                    case when v_r->>'estado' = 'aplicado'
                              and (select x.descripcion from asientos x where x.id = (v_r->'asiento'->>'id')::uuid) like 'c10-pruebas: es su jornal de la semana, no la nómina: ACH%'
                              and (select r.opciones->>'motivo' from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid) = 'c10-pruebas: es su jornal de la semana, no la nómina'
                         then 'entra, el asiento lo lleva y el reparto lo guarda' else v_r::text end, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (30, 'los frenos del banco valen: lo que c6 no deja clasificar sin el motivo escrito de Edgar (aquí, un débito que toma por nómina) tampoco pasa por el jornal: MX008 con el mensaje de c6 y nada cambia; con el motivo en p_opciones.motivo, entra. Y un Zelle nunca es de nómina (c6, 14-nov): el que dice PAYROLL entra por el jornal sin motivo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- DESHACER (fn_jornal_deshacer) Y LO QUE LA PANTALLA PINTA
-- ---------------------------------------------------------------------
-- 31. Deshacer va por el camino del banco (fn_banco_descasar): el asiento
--     NO se borra, se reversa; el movimiento vuelve a la Bandeja; el reparto
--     queda marcado con quién, por qué y su reverso; la aprobación de las
--     horas SE QUEDA; y el pago vuelve a salir entre los pendientes. Dos
--     veces no; sin motivo, tampoco.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_d jsonb; v_rep jornal_repartos; a text; b text; c text; d text; e text; f text; g text; h text;
  v_esp text := 'el asiento sigue en el libro y su reverso lo anula (5200 de las dos obras, en 0.00), con el motivo | el movimiento vuelve a la '
                'Bandeja (pendiente, sin asiento) | el reparto queda marcado: deshecho, por el dueño, con su motivo y su reverso | las 2 horas '
                'siguen aprobadas | el pago vuelve a salir entre los pendientes, con sus 12 h | otra vez MX008 | sin motivo 22023 | un reparto '
                'que no existe 22023 | control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(31, 'deshacer un reparto', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- (las horas, en la semana que la regla da para el día del pago: así el pago vuelve a salir con ellas)
    perform pg_temp.c10_hora(1, 'p1', (select p.desde from fn_jornal_periodo(pg_temp.c10_d()) p), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', (select p.desde + 1 from fn_jornal_periodo(pg_temp.c10_d()) p), 'c10-prueba-b', 4);
    v_mov := pg_temp.c10_cargo('c10-t31', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9031');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, (select p.desde from fn_jornal_periodo(pg_temp.c10_d()) p), (select p.hasta from fn_jornal_periodo(pg_temp.c10_d()) p));
    v_d := pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: era de otra semana');
    select * into v_rep from jornal_repartos where id = (v_r->>'reparto_id')::uuid;
    a := format('%s (5200 de las dos obras, en %s), %s',
                case when exists (select 1 from asientos x where x.id = v_rep.asiento_id)
                          and (select x.camino = 'reverso' and x.reversa_a = v_rep.asiento_id from asientos x where x.id = v_rep.reverso_id)
                     then 'el asiento sigue en el libro y su reverso lo anula' else 'el asiento o su reverso no están como deben' end,
                (select sum(l.monto) from asiento_lineas l where l.cuenta = '5200' and l.proyecto_id in ('c10-prueba-a', 'c10-prueba-b')),
                case when (select x.motivo from asientos x where x.id = v_rep.reverso_id) like '%c10-pruebas: era de otra semana%' then 'con el motivo' else 'sin el motivo' end);
    select format('%s, %s', m.estado, case when m.asiento_id is null then 'sin asiento' else 'CON asiento' end) into b from movimientos_banco m where m.id = v_mov;
    c := format('%s, %s, %s', v_rep.estado, case when v_rep.deshecho_por::text = pg_temp.c10('dueno') and v_rep.deshecho_el is not null then 'por el dueño' else 'por otro' end,
                case when v_rep.deshecho_motivo = 'c10-pruebas: era de otra semana' and v_rep.reverso_id = (v_d->'reverso'->>'id')::uuid
                          and v_d->>'estado' = 'deshecho' and not (v_d->>'por_fuera')::boolean and v_d->>'movimiento_estado' = 'pendiente'
                     then 'con su motivo y su reverso' else 'mal: ' || v_d::text end);
    select format('las %s horas siguen aprobadas', count(*)) into d from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null;
    perform pg_temp.c10_ser('dueno');
    select format('con sus %s h', trim_scale(p.horas)) into e from v_jornal_pendientes p where p.movimiento_id = v_mov;
    perform pg_temp.c10_ser('editor');
    begin perform pg_temp.c10_deshacer(v_rep.id, 'otra vez, por si acaso'); f := 'entró'; exception when others then f := sqlstate; end;
    begin perform pg_temp.c10_deshacer(v_rep.id, ' x '); g := 'entró'; exception when others then g := sqlstate; end;
    begin perform pg_temp.c10_deshacer('00000000-0000-4000-a000-0000000c10fd', 'no existe'); h := 'entró'; exception when others then h := sqlstate; end;
    v_obt := format('%s | el movimiento vuelve a la Bandeja (%s) | el reparto queda marcado: %s | %s | el pago vuelve a salir entre los '
                    'pendientes, %s | otra vez %s | sin motivo %s | un reparto que no existe %s | %s', a, b, c, d, coalesce(e, 'NO sale'), f, g, h,
                    pg_temp.c10_propios());
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (31, 'DESHACER va por el camino del banco: el asiento se reversa (no se borra), el movimiento vuelve a la Bandeja, el reparto queda marcado (quién, por qué, su reverso) y no se borra, la aprobación de las horas se queda, y el pago vuelve a salir entre los pendientes; dos veces MX008, sin motivo 22023',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 32. Volver a aplicar con otras fechas: deshecho el primero, el mismo pago
--     se reparte por otra semana; quedan los dos repartos (uno deshecho, uno
--     aplicado) y el costo, en la obra buena.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_r2 jsonb;
  v_esp text := 'primero a 8→260.00 (semana_anterior); deshecho; después b 5→260.00 (a_mano) | del mismo pago: 2 repartos (1 aplicado, 1 '
                'deshecho) y 3 asientos (el primero, su reverso y el nuevo) | el costo: en la a 0.00, en la b 260.00 | las horas de las dos '
                'semanas, aprobadas: 2 | control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(32, 'volver a aplicar con otras fechas', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w2(0), 'c10-prueba-b', 5);
    v_mov := pg_temp.c10_cargo('c10-t32', pg_temp.c10_d(), 260.00, 'Zelle payment to C10 PRUEBA ZZANA 9032');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: no era esa semana, era la de antes');
    v_r2 := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    perform pg_temp.c10_ser('dueno');
    v_obt := format('primero %s (%s); deshecho; después %s (%s) | del mismo pago: %s repartos (%s aplicado, %s deshecho) y %s asientos (el primero, '
                    'su reverso y el nuevo) | el costo: en la a %s, en la b %s | las horas de las dos semanas, aprobadas: %s | %s',
                    pg_temp.c10_lineas(v_r), v_r->>'regla_periodo', pg_temp.c10_lineas(v_r2), v_r2->>'regla_periodo',
                    (select count(*) from v_jornal_repartos r where r.movimiento_id = v_mov),
                    (select count(*) from v_jornal_repartos r where r.movimiento_id = v_mov and r.estado = 'aplicado' and r.asiento_vivo),
                    (select count(*) from v_jornal_repartos r where r.movimiento_id = v_mov and r.estado = 'deshecho' and not r.asiento_vivo and r.reverso is not null),
                    (select count(*) from asientos x where x.origen_tabla = 'movimientos_banco' and x.origen_id = v_mov::text),
                    (select o.mano_obra_jornales from v_margen_obra o where o.proyecto_id = 'c10-prueba-a'),
                    (select o.mano_obra_jornales from v_margen_obra o where o.proyecto_id = 'c10-prueba-b'),
                    (select count(*) from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null),
                    pg_temp.c10_propios());
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (32, 'volver a aplicar con otras fechas: deshecho el primer reparto, el mismo pago se reparte por otra semana (un asiento nuevo); quedan los dos repartos como rastro y el costo, solo en la obra buena',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 33. Des-casado POR FUERA (Edgar lo suelta en la Bandeja, sin pasar por el
--     jornal): c6 reversa el asiento y el reparto queda «aplicado» sin
--     asiento vivo. El control lo ve (20, en rojo, con qué hacer), la
--     propuesta lo dice y no deja repartir encima, y fn_jornal_deshacer lo
--     cierra sin tocar el libro otra vez.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_j jsonb; v_d jsonb; a text; b text; c text; d text; e text; v_n int;
  v_esp text := 'des-casado en la Bandeja: el control 20 en rojo, y dice qué hacer; el margen, nada nuevo en rojo | la propuesta: no deja '
                '[reparto_suelto] y trae el reparto | aplicar MX008 | deshacer lo cierra (por fuera) sin otro asiento | el control vuelve a '
                'verde y el pago se puede repartir';
begin
  if pg_temp.c10_omitir(33, 'des-casado por fuera', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(33, 'des-casado por fuera', v_esp, 'jornal', array[20]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t33', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9033');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_descasar(v_mov, 'c10-pruebas: lo suelto en la Bandeja (se deshace)');
    perform pg_temp.c10_ser('editor');
    a := format('%s; el margen, %s',
                case when pg_temp.c10_jc(20) like 'rojo: %se reversó por fuera%→ toca «Deshacer» en ese reparto (en Repartos), con su motivo%'
                          and pg_temp.c10_jc(20) !~ 'fn_|v_jornal|v_margen' then 'el control 20 en rojo, y dice qué hacer'
                     else 'el control 20: ' || pg_temp.c10_jc(20) end,
                split_part(split_part(pg_temp.c10_propios(), 'del margen: ', 2), ' en rojo', 1) || ' en rojo');
    v_j := pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    b := format('%s [%s] y %s', case when (v_j->>'puede_aplicar')::boolean then 'DEJA' else 'no deja' end,
                (select string_agg(x->>'codigo', ',') from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = 'reparto_suelto'),
                case when (select x->>'reparto_id' from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = 'reparto_suelto') = v_r->>'reparto_id'
                     then 'trae el reparto' else 'no trae el reparto' end);
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_j->>'visto');
      c := 'entró';
    exception when others then c := sqlstate;
    end;
    perform pg_temp.c10_ser('editor');
    select count(*) into v_n from asientos;
    v_d := pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: se había des-casado en la Bandeja');
    d := format('%s %s', case when (v_d->>'por_fuera')::boolean and v_d->>'estado' = 'deshecho' and v_d->'reverso'->>'numero' is not null then 'lo cierra (por fuera)' else 'no: ' || v_d::text end,
                case when (select count(*) from asientos) = v_n then 'sin otro asiento' else 'con OTRO asiento' end);
    e := format('%s y %s', case when pg_temp.c10_jc(20) = 'verde' then 'el control vuelve a verde' else pg_temp.c10_jc(20) end,
                case when (pg_temp.c10_propuesta(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6))->>'puede_aplicar')::boolean then 'el pago se puede repartir' else 'el pago sigue sin poder repartirse' end);
    v_obt := format('des-casado en la Bandeja: %s | la propuesta: %s | aplicar %s | deshacer %s | %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (33, 'des-casado por fuera (en la Bandeja, sin pasar por el jornal): el control 20 lo pone en rojo con qué hacer, la propuesta lo dice (reparto_suelto) y no deja repartir encima, y fn_jornal_deshacer lo cierra sin tocar el libro otra vez; después, verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 34. Lo que la pantalla pinta: v_jornal_pendientes (la tarjeta de «mano de
--     obra» de la Bandeja: la misma cuenta que la propuesta sin fechas) y
--     v_jornal_repartos (el historial), con sus columnas: las del contrato.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_r jsonb; v_j jsonb; a text; b text; c text; v_def record;
  v_esp text := 'pendientes: 300.00 de Zzana C10 PRUEBA, 12 h en 2 reportes y 2 obras, a 25.00 la hora, se puede aplicar, con la huella y las '
                'líneas de la propuesta | repartos: aplicado, 150.00 por 6 h en 1 obra (C10 PRUEBA Obra H, línea 2), su asiento vivo, 1 hora '
                'aprobada, por el dueño | las columnas: las del contrato';
begin
  if pg_temp.c10_omitir(34, 'v_jornal_pendientes y v_jornal_repartos', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    select * into v_def from fn_jornal_periodo(pg_temp.c10_d());
    perform pg_temp.c10_hora(1, 'p1', v_def.desde, 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', v_def.desde + 1, 'c10-prueba-b', 4);
    perform pg_temp.c10_hora(3, 'p1', v_def.desde - 14, 'c10-prueba-h', 6);
    m2 := pg_temp.c10_cargo('c10-t34-2', pg_temp.c10_d(), 150.00, 'Zelle payment to C10 PRUEBA ZZANA 9342');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(m2, v_def.desde - 14, v_def.desde - 8);
    m1 := pg_temp.c10_cargo('c10-t34-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9341');
    v_j := pg_temp.c10_propuesta(m1);
    perform pg_temp.c10_ser('dueno');
    select format('%s de %s, %s h en %s reportes y %s obras, a %s la hora, %s, %s', p.monto, p.persona, trim_scale(p.horas), p.reportes, p.obras,
                  p.tarifa_sale,
                  -- (sin avisos, salvo los del calendario —otro_mes, otro_anio—, que dependen del día en que se corre; y la
                  -- etiqueta corta y la cuenta de avisos de la vista son las de la lista)
                  case when p.puede_aplicar and p.por_que is null
                            and (select count(*) from jsonb_array_elements(p.avisos) a2 where a2->>'codigo' not in ('otro_mes', 'otro_anio')) = 0
                            and p.n_avisos = jsonb_array_length(p.avisos)
                            and p.aviso is not distinct from (select string_agg(a2->>'corto', ' · ') from jsonb_array_elements(p.avisos) a2)
                       then 'se puede aplicar' else 'NO se puede: ' || coalesce(p.por_que, p.aviso) end,
                  case when p.visto = v_j->>'visto' and p.lineas = v_j->'lineas' and p.desde = v_def.desde and p.hasta = v_def.hasta and p.regla = v_def.regla
                            and p.fecha = pg_temp.c10_d() and p.cuenta = pg_temp.c10('banco') and p.usuario_id::text = pg_temp.c10('p1') and p.tarifa = 25
                            and p.periodo_texto = fn_jornal_rango(v_def.desde, v_def.hasta) and p.horas_sin_obra is null and p.propuesta_ia is null
                       then 'con la huella y las líneas de la propuesta' else 'con otra cosa que la propuesta' end)
      into a from v_jornal_pendientes p where p.movimiento_id = m1;
    select format('%s, %s por %s h en %s obra (%s, línea %s), %s, %s hora aprobada, %s', r.estado, r.monto, trim_scale(r.horas), r.obras,
                  r.lineas->0->>'obra', r.lineas->0->>'orden',
                  case when r.asiento_vivo and r.asiento = v_r->'asiento'->>'numero' and r.asiento_fecha = pg_temp.c10_d() and r.reverso is null then 'su asiento vivo' else 'su asiento NO' end,
                  r.horas_aprobadas,
                  case when r.creado_por::text = pg_temp.c10('dueno') and r.creado_por_nombre = (select pf.nombre from perfiles pf where pf.id = r.creado_por)
                            and r.persona = 'Zzana C10 PRUEBA' and r.fecha_pago = pg_temp.c10_d() and r.cuenta_banco = pg_temp.c10('banco')
                            and r.regla_periodo = 'a_mano' and r.cuenta = '5200' and r.tarifa_sale = 25.00 and r.deshecho_el is null
                       then 'por el dueño' else 'con algo mal: ' || to_jsonb(r)::text end)
      into b from v_jornal_repartos r where r.movimiento_id = m2;
    perform pg_temp.c10_ser('editor');
    select case when (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                       where a2.attrelid = 'public.v_jornal_pendientes'::regclass and a2.attnum > 0)
                     = 'movimiento_id,cuenta,fecha,monto,descripcion,usuario_id,persona,tarifa,desde,hasta,regla,periodo_texto,horas,reportes,obras,'
                       'horas_sin_obra,tarifa_sale,puede_aplicar,por_que,aviso,n_avisos,avisos,lineas,visto,propuesta_ia,'
                       'por,cheque,solo,solo_por_que,solo_frenos,solo_entra_el'   -- (15-nov, v5: seis más, al final: la cuadrilla, sola)
                     and (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                           where a2.attrelid = 'public.v_jornal_cheques'::regclass and a2.attnum > 0)
                     = 'movimiento_id,cuenta,fecha,monto,descripcion,cheque'
                     and (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                           where a2.attrelid = 'public.v_jornal_repartos'::regclass and a2.attnum > 0)
                     = 'reparto_id,estado,movimiento_id,fecha_pago,cuenta_banco,descripcion,usuario_id,persona,desde,hasta,regla_periodo,periodo_texto,'
                       'monto,horas,tarifa_sale,tarifa_equipo,cuenta,cuenta_sin_obra,obras,lineas,asiento_id,asiento,asiento_fecha,asiento_vivo,avisos,'
                       'opciones,horas_aprobadas,creado_el,creado_por,creado_por_nombre,deshecho_el,deshecho_por,deshecho_por_nombre,deshecho_motivo,'
                       'reverso_id,reverso,origen,por,regla,cheque'   -- (15-nov, v5: cuatro más, al final)
                     and (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                           where a2.attrelid = 'public.v_jornal_personas'::regclass and a2.attnum > 0)
                     = 'usuario_id,nombre,rol,perfil_activo,registrada,activa,patron,cuenta_propia,cuenta,tarifa,nota,creado_el,actualizado_el,'
                       'pagos_pendientes,pagos_pendientes_monto,repartos,repartido,ultimo_reparto,horas_90_dias,horas_sin_pago,'
                       'horas_nomina_90_dias,'   -- (13-nov, v3: una columna más, al final: las que pagó una nómina)
                       'alta,sola,patron_nombre,sola_por_que'   -- (15-nov, v5: cuatro más, al final: quién la dio de alta y si la base puede)
                     and (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                           where a2.attrelid = 'public.v_jornal_control'::regclass and a2.attnum > 0) = 'orden,cuadre,nivel,ok,detalle'
                     and (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                           where a2.attrelid = 'public.v_margen_control'::regclass and a2.attnum > 0) = 'orden,cuadre,nivel,ok,detalle'
                     and (select string_agg(a2.attname, ',' order by a2.attnum) from pg_attribute a2
                           where a2.attrelid = 'public.v_margen_obra'::regclass and a2.attnum > 0)
                     = 'proyecto_id,obra,cliente,tipo,estado,completado_el,libro_desde,parcial,parcial_por,contrato,ingreso_libro,material_real,'
                       'mano_obra_real,mano_obra_jornales,mano_obra_nomina,subcontratos_real,equipo_real,otros_costos_real,costo_real,horas_reales,'
                       'horas_co,horas_base,horas_antes_libro,horas_con_pago_real,horas_estandar,horas_dueno,horas_sin_aprobar,mano_obra_estandar,'
                       'mano_obra_estandar_falta,mano_obra_dueno,burden_estandar_pct,costo_con_estandar,horas_estimadas,tarifa_estimada,escenario,'
                       'estimado_id,mano_obra_estimada,material_presupuesto,costo_estimado,estimado_completo,estimado_falta,margen_real,'
                       'margen_real_pct,margen_estimado,margen_estimado_pct,diferencia,pagos_sin_repartir,asientos,avisos'
                then 'las del contrato' else 'han cambiado' end
      into c;
    v_obt := format('pendientes: %s | repartos: %s | las columnas: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (34, 'lo que la pantalla pinta: v_jornal_pendientes (el pago con su semana, sus horas, sus obras, la tarifa que sale, si se puede aplicar, la huella y las líneas: lo mismo que la propuesta sin fechas) y v_jornal_repartos (el historial); y las columnas de las siete vistas son las del contrato (las de la cuadrilla sola, al final de cada una)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- v_jornal_control: cada cuadre en rojo, y de vuelta a verde
-- (el 20, en la 33). Lo que solo se rompe por debajo de las guardas se
-- rompe aquí apagando la guarda de la tabla de c10 dentro de la prueba (se
-- deshace con ella).
-- ---------------------------------------------------------------------
-- 35. El 10: cada reparto aplicado ES las líneas de su asiento, y su
--     detalle por reporte suma cada parte.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_rep uuid; a text; b text; c text; d text; e text;
  v_esp text := 'verde | una parte cambiada por debajo: rojo (no es su línea; no suman el pago; el detalle no suma) | de vuelta: verde | el '
                'detalle de un reporte cambiado: rojo (el detalle no suma) | de vuelta: verde';
begin
  if pg_temp.c10_omitir(35, 'el control 10 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(35, 'el control 10 del jornal', v_esp, 'jornal', array[10]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    v_mov := pg_temp.c10_cargo('c10-t35', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9035');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_rep := (v_r->>'reparto_id')::uuid;
    a := pg_temp.c10_jc(10);
    alter table public.jornal_reparto_lineas disable trigger trg_jornal_reparto_lineas_guarda;
    alter table public.jornal_reparto_horas disable trigger trg_jornal_reparto_horas_guarda;
    update jornal_reparto_lineas set monto = monto + 1 where reparto_id = v_rep and n = 1;
    b := pg_temp.c10_jc(10);
    -- (y lo dice sin nombrar una función ni una vista: ese detalle lo lee Edgar en la Bandeja)
    b := case when b like 'rojo: %la parte 1 (201.00) no es la línea 2 de su asiento%sus partes no suman el pago%su detalle por reporte de horas no suma sus partes%'
                   and b like '%→ no toques el libro: mira ese reparto y su asiento (en Repartos), y avisa.' and b !~ 'fn_|v_jornal|v_margen'
              then 'rojo (no es su línea; no suman el pago; el detalle no suma)' else b end;
    update jornal_reparto_lineas set monto = monto - 1 where reparto_id = v_rep and n = 1;
    c := pg_temp.c10_jc(10);
    update jornal_reparto_horas set monto = monto - 0.01 where reparto_id = v_rep and horas_id = -1010000002;
    d := pg_temp.c10_jc(10);
    d := case when d like 'rojo: %su detalle por reporte de horas no suma sus partes%' and d not like '%no es la línea%' then 'rojo (el detalle no suma)' else d end;
    update jornal_reparto_horas set monto = monto + 0.01 where reparto_id = v_rep and horas_id = -1010000002;
    e := pg_temp.c10_jc(10);
    v_obt := format('%s | una parte cambiada por debajo: %s | de vuelta: %s | el detalle de un reporte cambiado: %s | de vuelta: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (35, 'el control 10 del jornal (cada reparto aplicado es las líneas de su asiento, al centavo, y su detalle por reporte suma cada parte): en rojo si una parte o el detalle se cambian por debajo de la guarda, y de vuelta a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 36. El 25: ningún reparto marcado deshecho con su asiento todavía vivo.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_rep uuid; a text; b text; c text;
  v_esp text := 'verde | marcado deshecho por debajo, con su asiento vivo: rojo, y dice qué hacer | de vuelta: verde';
begin
  if pg_temp.c10_omitir(36, 'el control 25 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(36, 'el control 25 del jornal', v_esp, 'jornal', array[25]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t36', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9036');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_rep := (v_r->>'reparto_id')::uuid;
    a := pg_temp.c10_jc(25);
    alter table public.jornal_repartos disable trigger trg_jornal_repartos_guarda;
    update jornal_repartos set estado = 'deshecho', deshecho_el = now(), deshecho_motivo = 'c10-pruebas: por debajo' where id = v_rep;
    b := pg_temp.c10_jc(25);
    b := case when b like 'rojo: %asiento ' || (v_r->'asiento'->>'numero') || '%su asiento sigue en el libro: des-casa su pago en la Bandeja%' then 'rojo, y dice qué hacer' else b end;
    update jornal_repartos set estado = 'aplicado', deshecho_el = null, deshecho_motivo = null where id = v_rep;
    c := pg_temp.c10_jc(25);
    v_obt := format('%s | marcado deshecho por debajo, con su asiento vivo: %s | de vuelta: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (36, 'el control 25 del jornal (ningún reparto deshecho con su asiento todavía vivo): en rojo si un reparto se marca deshecho por debajo de la guarda, con qué hacer; de vuelta a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 37. El 30: las horas de un reparto aplicado siguen como se repartieron.
--     Edgar corrige unas horas en la app (c3 les quita la aprobación), les
--     cambia la obra, o se borra un reporte: en rojo, y dice cuál y qué
--     pasó; deshecho el reparto (se vuelve a repartir con las de hoy), verde.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'verde | otras horas: rojo (el reporte del lunes cambió de horas, de 8 a 7) | las de antes, pero ya sin aprobar: rojo (ya no '
                'está aprobado) | aprobadas otra vez: verde | otra obra: rojo (cambió de obra) | un reporte borrado: rojo (se borró), y dice '
                'qué hacer | deshecho el reparto: verde';
begin
  if pg_temp.c10_omitir(37, 'el control 30 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(37, 'el control 30 del jornal', v_esp, 'jornal', array[30]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-h', 2);
    v_mov := pg_temp.c10_cargo('c10-t37', pg_temp.c10_d(), 350.00, 'Zelle payment to C10 PRUEBA ZZANA 9037');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := pg_temp.c10_jc(30);
    perform pg_temp.c10_corregir(1, 'horas = 7');
    b := pg_temp.c10_jc(30);
    b := case when b like 'rojo: %el reporte -1010000001 del ' || pg_temp.c10_w1(0) || ' cambió de horas (de 8 a 7)%' then 'rojo (el reporte del lunes cambió de horas, de 8 a 7)' else b end;
    perform pg_temp.c10_corregir(1, 'horas = 8');
    c := pg_temp.c10_jc(30);
    c := case when c like 'rojo: %el reporte -1010000001 %ya no está aprobado%' then 'rojo (ya no está aprobado)' else c end;
    perform pg_temp.c10_ser('dueno');
    perform fn_horas_aprobar(pg_temp.c10('p1')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"ids": [-1010000001]}'::jsonb);
    perform pg_temp.c10_ser('editor');
    d := pg_temp.c10_jc(30);
    perform pg_temp.c10_corregir(2, $s$proyecto_id = 'c10-prueba-i'$s$);
    e := pg_temp.c10_jc(30);
    e := case when e like 'rojo: %el reporte -1010000002 %cambió de obra%' then 'rojo (cambió de obra)' else e end;
    delete from horas where id = -1010000003;
    f := pg_temp.c10_jc(30);
    f := case when f like 'rojo: %el reporte -1010000003 %se borró%→ el pago se repartió con otras horas: deshaz ese reparto%' then 'rojo (se borró), y dice qué hacer' else f end;
    perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: las horas cambiaron, se vuelve a repartir');
    g := pg_temp.c10_jc(30);
    v_obt := format('%s | otras horas: %s | las de antes, pero ya sin aprobar: %s | aprobadas otra vez: %s | otra obra: %s | un reporte borrado: '
                    '%s | deshecho el reparto: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (37, 'el control 30 del jornal (las horas de cada reparto aplicado siguen como se repartieron y aprobadas): en rojo si unas horas cambian, pierden su aprobación, cambian de obra o se borran, con cuál y qué hacer; de vuelta a verde al aprobarlas o al deshacer el reparto',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 38. El 40: ninguna hora en dos repartos vivos sin que Edgar lo aceptara.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_r jsonb; a text; b text; c text; d text;
  v_esp text := 'un pago: verde | otro pago de las mismas horas, pedido por Edgar: verde, y lo dice | lo mismo sin haberlo pedido: rojo (en 2 '
                'repartos), y dice qué hacer | de vuelta: verde';
begin
  if pg_temp.c10_omitir(38, 'el control 40 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(38, 'el control 40 del jornal', v_esp, 'jornal', array[40]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    m1 := pg_temp.c10_cargo('c10-t38-1', pg_temp.c10_d(), 120.00, 'Zelle payment to C10 PRUEBA ZZANA 9381');
    m2 := pg_temp.c10_cargo('c10-t38-2', pg_temp.c10_d(), 80.00, 'Zelle payment to C10 PRUEBA ZZANA 9382');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := pg_temp.c10_jc(40);
    v_r := pg_temp.c10_aplicar(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"incluir_cubiertas": true}');
    b := pg_temp.c10_jc(40);
    b := case when b = 'verde' and (select k.detalle from v_jornal_control k where k.orden = 40) like '% reporte(s) de horas están en dos repartos porque Edgar lo pidió%'
              then 'verde, y lo dice' else b end;
    alter table public.jornal_repartos disable trigger trg_jornal_repartos_guarda;
    update jornal_repartos set opciones = '{}'::jsonb where id = (v_r->>'reparto_id')::uuid;
    c := pg_temp.c10_jc(40);
    c := case when c like 'rojo: %el reporte -1010000001 %(en 2 repartos)%→ una semana pagada dos veces sin decirlo: deshaz el reparto que sobre%' then 'rojo (en 2 repartos), y dice qué hacer' else c end;
    update jornal_repartos set opciones = '{"incluir_cubiertas": true}'::jsonb where id = (v_r->>'reparto_id')::uuid;
    d := pg_temp.c10_color(pg_temp.c10_jc(40));
    v_obt := format('un pago: %s | otro pago de las mismas horas, pedido por Edgar: %s | lo mismo sin haberlo pedido: %s | de vuelta: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (38, 'el control 40 del jornal (ninguna hora en dos repartos vivos sin que Edgar lo aceptara): verde con «es otro pago de las mismas horas» (y lo dice); en rojo si el segundo reparto no lo lleva escrito; de vuelta a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 39. El 50: una hora que está a la vez en el devengo estándar de un mes
--     (c3, fn_horas_devengar) y en un jornal que entró al libro en ese mismo
--     mes cuenta dos veces: en rojo, con el mes, el devengo, las horas y el
--     jornal; deshecho el jornal, deja de contar (verde, salvo que ese mes
--     tenga jornales reales que también choquen: entonces lo que se mira es
--     que el de la prueba ya no esté). Y en la obra el devengo no cuenta
--     como real (se anula solo con su reverso del día 1). (Lo que NO es
--     doble —el pago que entra al mes siguiente— lo prueba la 54.) (En un
--     mes con nómina el devengo lo pone la prueba, como lo deja c3: «EL
--     DEVENGO DE LAS PRUEBAS 20 Y 39».)
--     (14-nov, la Fase 11c) PRIMERO EL DEVENGO, DESPUÉS EL JORNAL. Antes iba
--     al revés (el jornal y luego devengar); con el c3 de la Fase 11c,
--     devengar después de repartir ya no cuenta esas horas —no hay doble que
--     mirar— y la prueba salía «omitida» o, con más horas aprobadas en el
--     mes, en rojo. El doble que este control vigila queda así: el mes ya
--     devengado con la hora, y su jornal repartido después sin que el
--     devengo se ponga al día (c3 lo hace al confirmar; una prueba no
--     confirma: como si no hubiera podido). Vale con los dos c3. Y el «qué
--     hacer» es el del c3 de la base: volver a devengar, o retirarlo.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_mes text; v_dia date; v_dev jsonb; v_no text; a text; b text; c text; d text; v_n1 int; v_h1 numeric; v_n2 int; v_h2 numeric;
  v_n0 int; v_h0 numeric;
  v_esp text := 'con el devengo estándar del mes, antes del jornal: nada de la prueba cuenta | con el jornal de ese mismo mes: rojo (nombra el '
                'mes, su devengo, las horas y el jornal), y dice qué hacer | en la obra, el devengo no cuenta como real: jornales 200.00, '
                'nómina 0.00 | deshecho el jornal: el de la prueba ya no cuenta';
begin
  if pg_temp.c10_omitir(39, 'el control 50 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(39, 'el control 50 del jornal', v_esp, 'jornal', array[50]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- (en el mes del pago, que está abierto: las horas, el día 1)
    v_dia := date_trunc('month', pg_temp.c10_d())::date;
    v_mes := to_char(v_dia, 'YYYY-MM');
    perform pg_temp.c10_hora(1, 'p1', v_dia, 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t39', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9039');
    perform pg_temp.c10_alta('p1');
    -- (el devengo, con la hora ya aprobada, ANTES del jornal)
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_horas_aprobar(pg_temp.c10('p1')::uuid, v_dia, v_dia, '{"ids": [-1010000001]}'::jsonb);
      perform pg_temp.c10_ser('editor');
      v_dev := pg_temp.c10_devengar(v_mes, array[-1010000001]::bigint[]);
    exception when others then
      v_no := sqlstate || ': ' || sqlerrm;
      perform pg_temp.c10_ser('editor');
    end;
    if v_no is null then
      -- (con un c3 de antes, el devengo de la prueba se lleva también las horas que pagaron los jornales de verdad de ese mes:
      --  lo que ya chocaba antes del jornal de la prueba no es de aquí; se cuenta la diferencia)
      a := pg_temp.c10_jc(50);
      v_h0 := coalesce(substring(a from v_mes || ': el devengo [^ ]+ cuenta ([0-9.]+) h')::numeric, 0);
      v_n0 := coalesce(substring(a from v_mes || ': el devengo [^ ]+ cuenta [0-9.]+ h \([0-9]+ reporte\(s\)\) que ya tienen su pago real en ese mes, en ([0-9]+) jornal')::int, 0);
      v_r := pg_temp.c10_aplicar(v_mov, v_dia, v_dia);
      b := pg_temp.c10_jc(50);
      -- (cuántas horas y cuántos jornales dice que chocan con el devengo de ese mes)
      v_h1 := substring(b from v_mes || ': el devengo [^ ]+ cuenta ([0-9.]+) h')::numeric;
      v_n1 := substring(b from v_mes || ': el devengo [^ ]+ cuenta [0-9.]+ h \([0-9]+ reporte\(s\)\) que ya tienen su pago real en ese mes, en ([0-9]+) jornal')::int;
      a := case when a = 'verde' or (v_n1 = v_n0 + 1 and v_h1 = v_h0 + 8) then 'nada de la prueba cuenta' else a end;
      b := case when b like 'rojo: %' || v_mes || ': el devengo ' || (v_dev->>'asiento') || ' cuenta % h (% reporte(s)) que ya tienen su pago real en ese mes, en % jornal(es)%'
                                   || '→ esa mano de obra sale dos veces en ese mes%'
                                   || case when pg_temp.c10_c3_aparta() then 'vuelve a devengar ese mes (select fn_horas_devengar(%esas horas quedan fuera%'
                                           else 'hay que retirarlo de ese mes antes de cerrarlo%' end
                     and v_n1 = v_n0 + 1 and v_h1 = v_h0 + 8
                then 'rojo (nombra el mes, su devengo, las horas y el jornal), y dice qué hacer' else b end;
      perform pg_temp.c10_ser('dueno');
      select format('jornales %s, nómina %s', o.mano_obra_jornales, o.mano_obra_nomina) into c from v_margen_obra o where o.proyecto_id = 'c10-prueba-a';
      perform pg_temp.c10_ser('editor');
      perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: ese mes va con su devengo estándar');
      d := pg_temp.c10_jc(50);
      v_h2 := coalesce(substring(d from v_mes || ': el devengo [^ ]+ cuenta ([0-9.]+) h')::numeric, 0);
      v_n2 := coalesce(substring(d from v_mes || ': el devengo [^ ]+ cuenta [0-9.]+ h \([0-9]+ reporte\(s\)\) que ya tienen su pago real en ese mes, en ([0-9]+) jornal')::int, 0);
      d := case when d = 'verde' or (v_n2 = v_n1 - 1 and v_h2 = v_h1 - 8) then 'el de la prueba ya no cuenta' else d end;
      v_obt := format('con el devengo estándar del mes, antes del jornal: %s | con el jornal de ese mismo mes: %s | en la obra, el devengo no '
                      'cuenta como real: %s | deshecho el jornal: %s', a, b, c, d);
    else
      v_obt := format('omitida: %s (%s)',
                      case when pg_temp.c10_mes_con_nomina(v_mes)
                           then format('%s tiene nómina y el libro no dejó poner el devengo de la prueba', v_mes)
                           else format('c3 no dejó devengar %s', v_mes) end, left(v_no, 300));
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (39, 'el control 50 del jornal (ninguna hora a la vez en el devengo estándar de un mes y en un jornal que entró al libro ese mes: la mano de obra saldría dos veces): en rojo con el mes, el devengo, las horas y el jornal; en la obra el devengo no cuenta como real; deshecho el jornal, deja de contar',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 40. El 60 (un aviso): cada persona dada de alta se reconoce sin dudas y va
--     a una cuenta que sirve.
do $$
declare
  v_obt text; v_mov uuid; a text; b text; c text; d text; e text;
  v_esp text := 'verde | un pago que casa con dos personas: rojo, de nivel aviso, y dice qué hacer | afinado el patrón: verde | una cuenta que '
                'dejó de servir: rojo (la nombra) | de vuelta: verde';
begin
  if pg_temp.c10_omitir(40, 'el control 60 del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(40, 'el control 60 del jornal', v_esp, 'jornal', array[60]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    v_mov := pg_temp.c10_cargo('c10-t40', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9040');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_alta('p2');
    a := pg_temp.c10_jc(60);
    perform pg_temp.c10_alta('p2', '\mPRUEBA ZZ');
    b := pg_temp.c10_jc(60);
    b := case when b like 'rojo: %«Zelle payment to C10 PRUEBA ZZANA 9040») casa con 2 personas%→ corrígelo en las personas del jornal%'
                   and b !~ 'fn_|v_jornal|v_margen'
                   and (select k.nivel from v_jornal_control k where k.orden = 60) = 'aviso' then 'rojo, de nivel aviso, y dice qué hacer' else b end;
    perform pg_temp.c10_alta('p2');
    c := pg_temp.c10_jc(60);
    perform set_config('mx_jornal.escribe', 'jornal_personas', true);
    update jornal_personas set cuenta = '5000' where usuario_id = pg_temp.c10('p1')::uuid;
    d := pg_temp.c10_jc(60);
    d := case when d like 'rojo: %Zzana C10 PRUEBA: la cuenta 5000 (%) es mano de obra de nómina%' then 'rojo (la nombra)' else d end;
    update jornal_personas set cuenta = null where usuario_id = pg_temp.c10('p1')::uuid;
    perform set_config('mx_jornal.escribe', '', true);
    e := pg_temp.c10_jc(60);
    v_obt := format('%s | un pago que casa con dos personas: %s | afinado el patrón: %s | una cuenta que dejó de servir: %s | de vuelta: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (40, 'el control 60 del jornal (un aviso: cada persona dada de alta se reconoce sin dudas y va a una cuenta que sirve): en rojo si un pago pendiente casa con dos personas, o si una cuenta dejó de servir; de vuelta a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 41. El 90: las protecciones de la capa (por el nombre exacto de cada
--     objeto de c10). Cada cosa se rompe y se deshace en su bloque.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'verde | anon puede ejecutar una función: rojo | una tabla sin RLS: rojo | una función SECURITY DEFINER: rojo | una vista sin '
                'security_invoker: rojo | la guarda de una tabla apagada: rojo | service_role puede leer una tabla: rojo | y todo deshecho: verde';
begin
  if pg_temp.c10_omitir_rojo(41, 'el control 90 del jornal', v_esp, 'jornal', array[90]) then return; end if;
  begin
    perform pg_temp.c10_ser('editor');
    a := pg_temp.c10_jc(90);
    begin
      grant execute on function public.fn_jornal_aplicar(uuid, date, date, text, jsonb) to anon;
      b := pg_temp.c10_jc(90);
      b := case when b like 'rojo: %fn_jornal_aplicar la puede ejecutar anon%→ vuelve a pegar c10-costo-obra.sql%' then 'rojo' else b end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter table public.jornal_repartos disable row level security;
      c := pg_temp.c10_jc(90);
      c := case when c like 'rojo: %jornal_repartos sin RLS%' then 'rojo' else c end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter function public.fn_margen_obra(text) security definer;
      d := pg_temp.c10_jc(90);
      d := case when d like 'rojo: %fn_margen_obra es SECURITY DEFINER%' then 'rojo' else d end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter view public.v_margen_obra set (security_invoker = false);
      e := pg_temp.c10_jc(90);
      e := case when e like 'rojo: %v_margen_obra sin security_invoker%' then 'rojo' else e end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      alter table public.jornal_personas disable trigger trg_jornal_personas_guarda;
      f := pg_temp.c10_jc(90);
      f := case when f like 'rojo: %la guarda trg_jornal_personas_guarda de jornal_personas está apagada%' then 'rojo' else f end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    begin
      grant select on public.jornal_reparto_horas to service_role;
      g := pg_temp.c10_jc(90);
      g := case when g like 'rojo: %service_role puede SELECT en jornal_reparto_horas%' then 'rojo' else g end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('%s | anon puede ejecutar una función: %s | una tabla sin RLS: %s | una función SECURITY DEFINER: %s | una vista sin '
                    'security_invoker: %s | la guarda de una tabla apagada: %s | service_role puede leer una tabla: %s | y todo deshecho: %s',
                    a, b, c, d, e, f, g, pg_temp.c10_jc(90));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (41, 'el control 90 del jornal (las protecciones de la capa, por el nombre exacto de cada objeto): en rojo si anon ejecuta una función, una tabla pierde su RLS, una función pasa a SECURITY DEFINER, una vista pierde security_invoker, se apaga una guarda o service_role lee una tabla; deshecho, verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- EL MARGEN (v_margen_obra, fn_margen_obra, v_margen_control)
-- ---------------------------------------------------------------------
-- Un asiento a mano del dueño (fn_postear), para poner en el libro lo que
-- una obra de prueba necesita: su factura, su material, un subcontrato…
create or replace function pg_temp.c10_postear(p_desc text, p_lineas jsonb) returns uuid language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c10_ser('dueno');
  r := fn_postear(jsonb_build_object('fecha', pg_temp.c10_d()::text, 'descripcion', 'C10 PRUEBA: ' || p_desc || ' (se deshace)', 'lineas', p_lineas));
  perform pg_temp.c10_ser('editor');
  return (select a.id from asientos a where a.numero = r->>'numero');
end $$;

-- 42. Una obra con de todo: su factura (4020), material (5100, parte con un
--     CO), jornales, un subcontrato DE VERDAD en la misma 5200, equipo
--     (5300) y otro costo (5400). Cada columna de v_margen_obra contra el
--     libro, al centavo; y cada «bajar» de fn_margen_obra suma su cifra.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_j jsonb; o record; v_as uuid; a text; b text; c text; d text;
  v_esp text := 'ingreso 5000.00 | material 750.25 | mano de obra 250.00 (jornales 250.00, nómina 0.00) | subcontratos 500.00 | equipo 75.25 | '
                'otros 60.00 | costo 1635.50 | margen 3364.50 (67.3 %) | 3 asientos | cada columna es la del libro: sí | los 8 «bajar» de los '
                'conceptos suman su cifra: sí | por cuenta, la 5200 sale partida en dos (jornales 250.00 y lo demás 500.00) y los 5 «bajar» '
                'suman: sí';
begin
  if pg_temp.c10_omitir(42, 'el margen de una obra con de todo', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8, null, 'rough');
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 2, 'CO #1', 'trim');
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-b', 2);
    perform pg_temp.c10_postear('la factura de la obra A', jsonb_build_array(
      jsonb_build_object('cuenta', '1600', 'monto', '5000.00'),
      jsonb_build_object('cuenta', '4020', 'monto', '-5000.00', 'proyecto_id', 'c10-prueba-a')));
    perform pg_temp.c10_postear('los costos de la obra A', jsonb_build_array(
      jsonb_build_object('cuenta', '5100', 'monto', '300.00', 'proyecto_id', 'c10-prueba-a', 'co', 'CO #1', 'fase', 'rough'),
      jsonb_build_object('cuenta', '5100', 'monto', '450.25', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '5200', 'monto', '500.00', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '5300', 'monto', '75.25', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '5400', 'monto', '60.00', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '3100', 'monto', '-1385.50')));
    v_mov := pg_temp.c10_cargo('c10-t42', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9042');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    v_as := (v_r->'asiento'->>'id')::uuid;
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    v_j := fn_margen_obra('c10-prueba-a');
    perform pg_temp.c10_ser('editor');
    a := format('ingreso %s | material %s | mano de obra %s (jornales %s, nómina %s) | subcontratos %s | equipo %s | otros %s | costo %s | '
                'margen %s (%s %%) | %s asientos', o.ingreso_libro, o.material_real, o.mano_obra_real, o.mano_obra_jornales, o.mano_obra_nomina,
                o.subcontratos_real, o.equipo_real, o.otros_costos_real, o.costo_real, o.margen_real, o.margen_real_pct, o.asientos);
    -- contra el libro, línea por línea (las tablas, no la vista)
    select case when o.ingreso_libro = (select -sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta like '40%')
                     and o.material_real = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta = '5100')
                     and o.mano_obra_jornales = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.asiento_id = v_as and l.orden > 1)
                     and o.subcontratos_real = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta = '5200' and l.asiento_id <> v_as)
                     and o.equipo_real = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta = '5300')
                     and o.otros_costos_real = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta = '5400')
                     and o.costo_real = (select sum(l.monto) from asiento_lineas l where l.proyecto_id = 'c10-prueba-a' and l.cuenta like '5%')
                     and v_j->'obra' = to_jsonb(o)
                then 'sí' else 'NO' end into b;
    select format('%s', case when count(*) = 8 and bool_and(pg_temp.c10_bajar(x->'bajar') = (x->>'real')::numeric) then 'sí' else 'NO (' || count(*) || ')' end)
      into c from jsonb_array_elements(v_j->'conceptos') x where x ? 'bajar';
    select format('la 5200 sale partida en dos (jornales %s y lo demás %s) y los %s «bajar» suman: %s',
                  (select x->>'real' from jsonb_array_elements(v_j->'por_cuenta') x where x->>'cuenta' = '5200' and (x->>'jornal')::boolean),
                  (select x->>'real' from jsonb_array_elements(v_j->'por_cuenta') x where x->>'cuenta' = '5200' and not (x->>'jornal')::boolean),
                  count(*), case when bool_and(pg_temp.c10_bajar(x->'bajar') = (x->>'real')::numeric) then 'sí' else 'NO' end)
      into d from jsonb_array_elements(v_j->'por_cuenta') x;
    v_obt := format('%s | cada columna es la del libro: %s | los 8 «bajar» de los conceptos suman su cifra: %s | por cuenta, %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (42, 'EL MARGEN de una obra con su factura, material, jornales, un subcontrato de verdad en la misma 5200, equipo y otro costo: cada columna de v_margen_obra es la del libro, al centavo; los jornales no se confunden con el subcontrato; y cada «bajar» de fn_margen_obra (por concepto y por cuenta) suma su cifra en v_libro',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 43. La mano de obra DICE si es real o estándar. Real: lo pagado y
--     repartido. Estándar: las horas sin pago real × la tarifa de Costos del
--     equipo × (1 + burden estándar), al centavo por reporte; sin burden
--     fijado, o sin la tarifa de alguien, sale vacía con su porqué. Las del
--     dueño van aparte y no suman; las de antes del libro no van a estándar.
do $$
declare
  v_obt text; v_mov uuid; o record; a text; b text; c text; d text; e text; v_td numeric;
  v_esp text := 'sin burden fijado: 24.75 h; 8 con pago real (200.00), 5.75 a estándar sin cifra (falta el burden), 6 del dueño y 5 de antes '
                'del libro | burden 0: estándar 141.50, costo con estándar 341.50 | burden 12.5: estándar 159.19 (al centavo por reporte), '
                'costo con estándar 359.19 | las del dueño van aparte y no suman: sí | alguien sin tarifa: 9.75 h a estándar sin cifra, y dice '
                'quién | sin aprobar: 20.75 h';
begin
  if pg_temp.c10_omitir(43, 'la mano de obra real contra la estándar', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-h', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w2(0), 'c10-prueba-h', 3.5);
    perform pg_temp.c10_hora(3, 'p2', pg_temp.c10_w2(0), 'c10-prueba-h', 2.25);
    perform pg_temp.c10_hora(4, 'dueno', pg_temp.c10_w2(0), 'c10-prueba-h', 6);
    perform pg_temp.c10_hora(5, 'p2', pg_temp.c10('libro_desde')::date - 3, 'c10-prueba-h', 5);
    select ce.costo_hora into v_td from costos_equipo ce where ce.usuario_id = pg_temp.c10('dueno')::uuid;
    v_mov := pg_temp.c10_cargo('c10-t43', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9043');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"burden_estandar_pct": null}');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    a := format('%s h; %s con pago real (%s), %s a estándar %s, %s del dueño y %s de antes del libro', trim_scale(o.horas_reales),
                trim_scale(o.horas_con_pago_real), o.mano_obra_real, trim_scale(o.horas_estandar),
                case when o.mano_obra_estandar is null and o.costo_con_estandar is null and o.mano_obra_estandar_falta like 'Falta fijar el burden estándar%'
                          and o.burden_estandar_pct is null then 'sin cifra (falta el burden)' else 'con cifra: ' || o.mano_obra_estandar end,
                trim_scale(o.horas_dueno), trim_scale(o.horas_antes_libro));
    perform fn_jornal_config('{"burden_estandar_pct": 0}');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    b := format('estándar %s, costo con estándar %s', o.mano_obra_estandar, o.costo_con_estandar);
    perform fn_jornal_config('{"burden_estandar_pct": 12.5}');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    c := format('estándar %s (al centavo por reporte), costo con estándar %s', o.mano_obra_estandar, o.costo_con_estandar);
    -- (las 6 h del dueño: aparte, con su tarifa si la tiene, y fuera del costo)
    d := case when o.costo_con_estandar = o.costo_real + o.mano_obra_estandar and o.horas_dueno = 6
                   and o.mano_obra_dueno is not distinct from round(6 * v_td * 1.125, 2)
                   and exists (select 1 from unnest(o.avisos) x where x like '6 h de % (dueño) no están en el costo: no cobra por hora.')
              then 'sí' else 'NO' end;
    perform pg_temp.c10_ser('editor');
    perform pg_temp.c10_hora(6, 'p3', pg_temp.c10_w2(1), 'c10-prueba-h', 4);
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    e := format('%s h a estándar %s', trim_scale(o.horas_estandar),
                case when o.mano_obra_estandar is null and o.mano_obra_estandar_falta = 'Falta la tarifa de Zzcaro C10 PRUEBA en Costos del equipo: la mano de obra estándar no se calcula.'
                     then 'sin cifra, y dice quién' else 'con cifra o sin decir quién: ' || coalesce(o.mano_obra_estandar_falta, o.mano_obra_estandar::text) end);
    v_obt := format('sin burden fijado: %s | burden 0: %s | burden 12.5: %s | las del dueño van aparte y no suman: %s | alguien sin tarifa: %s | '
                    'sin aprobar: %s h', a, b, c, d, e, trim_scale(o.horas_sin_aprobar));
    perform pg_temp.c10_ser('editor');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (43, 'la mano de obra dice si es REAL (pagada y repartida) o ESTÁNDAR (horas sin pago real × la tarifa de Costos del equipo × (1 + burden estándar), al centavo por reporte): sin el burden fijado o sin la tarifa de alguien sale vacía y dice por qué; las horas del dueño van aparte y no suman; las de antes del libro no van a estándar',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 44. El estimado, de las mismas fuentes que la app: sin estimado enlazado,
--     el escenario B; con él, el suyo y sus beneficios; el «convertido»
--     antes que el más nuevo. (Los escenarios A y B se fijan dentro de la
--     prueba con tarifas redondas; se deshace.)
do $$
declare
  v_obt text; o record; a text; b text; c text; d text; e text;
  v_esp text := 'sin estimado enlazado: B, 36.25 la hora × 100 h = 3625.00, material 2000.00, costo 5625.00, contrato 9000.00, margen 3375.00 '
                '(37.5 %), diferencia 5625.00 | con su estimado: A, 42.38, mano de obra 4238.00 | con sus beneficios: 35.86, mano de obra '
                '3586.00 | el convertido antes que el más nuevo: B, 36.25 | una obra sin datos: sin cifras, y lo dice';
begin
  if pg_temp.c10_omitir(44, 'el estimado de una obra', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    insert into escenarios (id, nombre, foreman, journeyman, helper, pct_foreman, pct_journeyman, pct_helper, benefits) values
      ('B', 'C10 PRUEBA B', 40, 30, 20, 0.2, 0.5, 0.3, 0.25), ('A', 'C10 PRUEBA A', 50, 35, 22, 0.1, 0.6, 0.3, 0.30)
    on conflict (id) do update set foreman = excluded.foreman, journeyman = excluded.journeyman, helper = excluded.helper,
      pct_foreman = excluded.pct_foreman, pct_journeyman = excluded.pct_journeyman, pct_helper = excluded.pct_helper, benefits = excluded.benefits;
    update proyectos set horas_estimadas = 100 where id = 'c10-prueba-i';
    update proyectos set horas_estimadas = null where id = 'c10-prueba-j';
    insert into finanzas_proyecto (proyecto_id, contrato, presupuesto_materiales) values ('c10-prueba-i', 9000, 2000)
    on conflict (proyecto_id) do update set contrato = excluded.contrato, presupuesto_materiales = excluded.presupuesto_materiales;
    delete from finanzas_proyecto where proyecto_id = 'c10-prueba-j';
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    perform pg_temp.c10_ser('editor');
    a := format('%s, %s la hora × %s h = %s, material %s, costo %s, contrato %s, margen %s (%s %%), diferencia %s%s', o.escenario, o.tarifa_estimada,
                trim_scale(o.horas_estimadas), o.mano_obra_estimada, o.material_presupuesto, o.costo_estimado, o.contrato, o.margen_estimado,
                o.margen_estimado_pct, o.diferencia, case when o.estimado_id is null then '' else ' (CON estimado)' end);
    insert into estimados (id, nombre, proyecto_id, escenario, estado, benefits_pct, creado) overriding system value
    values (-1010000001, 'C10 PRUEBA estimado de la obra I', 'c10-prueba-i', 'A', 'borrador', null, now());
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    perform pg_temp.c10_ser('editor');
    b := format('%s, %s, mano de obra %s%s', o.escenario, o.tarifa_estimada, o.mano_obra_estimada, case when o.estimado_id = -1010000001 then '' else ' (OTRO estimado)' end);
    update estimados set benefits_pct = 0.10 where id = -1010000001;
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    perform pg_temp.c10_ser('editor');
    c := format('%s, mano de obra %s', o.tarifa_estimada, o.mano_obra_estimada);
    insert into estimados (id, nombre, proyecto_id, escenario, estado, benefits_pct, creado) overriding system value
    values (-1010000002, 'C10 PRUEBA estimado convertido de la obra I', 'c10-prueba-i', 'B', 'convertido', null, now() - interval '30 days');
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    d := format('%s, %s%s', o.escenario, o.tarifa_estimada, case when o.estimado_id = -1010000002 then '' else ' (el OTRO estimado)' end);
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-j';
    perform pg_temp.c10_ser('editor');
    e := case when o.horas_estimadas is null and o.mano_obra_estimada is null and o.material_presupuesto is null and o.costo_estimado is null
                   and o.contrato is null and o.margen_estimado is null and o.diferencia is null
                   and o.avisos @> array['Sin contrato en la ficha de la obra.', 'Sin horas estimadas.', 'Sin presupuesto de material.']
              then 'sin cifras, y lo dice' else 'con cifras: ' || to_jsonb(o)::text end;
    v_obt := format('sin estimado enlazado: %s | con su estimado: %s | con sus beneficios: %s | el convertido antes que el más nuevo: %s | una '
                    'obra sin datos: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (44, 'el estimado sale de las mismas fuentes que la app (horas_estimadas, el presupuesto de material y el contrato de la ficha, y la tarifa del escenario): sin estimado enlazado, el escenario B; con él, el suyo, con sus beneficios si los tiene; el «convertido» antes que el más nuevo; sin datos, sin cifras y lo dice',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 45. El libro empieza el día después de la apertura: una obra que ya
--     andaba antes sale «parcial», y se dice en llano qué tenía.
do $$
declare
  v_obt text; o record; a text; b text; c text;
  v_esp text := 'con horas de antes del libro: parcial (horas), y lo dice | con horas de antes de la app en su ficha: parcial (horas de antes '
                'de la app), 12 h de base | una obra nueva: no es parcial';
begin
  if pg_temp.c10_omitir(45, 'la obra que ya andaba antes del libro', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p2', pg_temp.c10('libro_desde')::date - 10, 'c10-prueba-k', 5);
    update proyectos set horas_reales_base = 12 where id = 'c10-prueba-l';
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-k';
    a := format('%s (%s), %s', case when o.parcial then 'parcial' else 'NO parcial' end, o.parcial_por,
                case when exists (select 1 from unnest(o.avisos) x
                                   where x = format('El libro empieza el %s y esta obra ya tenía de antes: horas. Lo de antes está en QuickBooks: aquí el real es parcial.',
                                                    fn_jornal_dia(pg_temp.c10('libro_desde')::date, true)))
                          and o.libro_desde = pg_temp.c10('libro_desde')::date and o.horas_antes_libro = 5 and o.horas_estandar = 0
                     then 'y lo dice' else 'y NO lo dice bien' end);
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-l';
    b := format('%s (%s), %s h de base', case when o.parcial then 'parcial' else 'NO parcial' end, o.parcial_por, trim_scale(o.horas_base));
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-j';
    c := case when not o.parcial and o.parcial_por is null then 'no es parcial' else 'parcial: ' || o.parcial_por end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('con horas de antes del libro: %s | con horas de antes de la app en su ficha: %s | una obra nueva: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (45, 'el libro empieza el día después de la apertura: una obra que ya andaba entonces (horas de antes, o de antes de la app en su ficha) sale parcial y dice en llano qué tenía; una obra nueva, no',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 46. El detalle de una obra (fn_margen_obra): por CO (la base aparte de
--     cada CO), por fase, por cost code (hoy ninguna línea lo trae: se dice;
--     con una que lo lleve, sale con su «bajar»), la cobertura de la mano de
--     obra por persona, los repartos que la tocan, y los pagos reconocidos
--     que siguen sin repartir.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_k jsonb; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'por CO: Base (sin CO) 8 h, mano de obra 200.00, material 450.25, costo 650.25; CO #1 2 h, mano de obra 50.00, material 300.00, '
                'costo 350.00 | por fase: rough 8 h, 200.00 pagados y 300.00 más en el libro; trim 2 h, 50.00 pagados | sin código: lo dice | '
                'con una línea con código: C10-PRUEBA 100.00, y su «bajar» suma | la cobertura: Zzana C10 PRUEBA 10 h, las 10 con pago real, '
                '250.00 | los repartos: 1, aplicado, 250.00 de 300.00 por 10 h | un pago suyo sin repartir: 1, y lo avisa';
begin
  if pg_temp.c10_omitir(46, 'el detalle de una obra', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8, null, 'rough');
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 2, 'CO #1', 'trim');
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-b', 2);
    perform pg_temp.c10_postear('el material de la obra A', jsonb_build_array(
      jsonb_build_object('cuenta', '5100', 'monto', '300.00', 'proyecto_id', 'c10-prueba-a', 'co', 'CO #1', 'fase', 'rough'),
      jsonb_build_object('cuenta', '5100', 'monto', '450.25', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '3100', 'monto', '-750.25')));
    m1 := pg_temp.c10_cargo('c10-t46-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9461');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    v_j := fn_margen_obra('c10-prueba-a');
    perform pg_temp.c10_ser('editor');
    select string_agg(format('%s %s h, mano de obra %s, material %s, costo %s', x->>'etiqueta', trim_scale((x->>'horas')::numeric),
                             x->>'mano_obra_real', x->>'material_real', x->>'costo_real'), '; ' order by o)
      into a from jsonb_array_elements(v_j->'por_co') with ordinality as t(x, o);
    select string_agg(format('%s %s h, %s pagados%s', x->>'etiqueta', trim_scale((x->>'horas')::numeric), x->>'mano_obra_real',
                             case when (x->>'otros_costos_libro')::numeric <> 0 then format(' y %s más en el libro', x->>'otros_costos_libro') else '' end),
                      '; ' order by o)
      into b from jsonb_array_elements(v_j->'por_fase') with ordinality as t(x, o);
    c := case when not (v_j->'por_cost_code'->>'hay')::boolean and v_j->'por_cost_code'->>'nota' like 'Todavía no hay nada capturado con código en esta obra%'
                   and jsonb_array_length(v_j->'por_cost_code'->'filas') = 0 then 'lo dice' else (v_j->'por_cost_code')::text end;
    select format('%s %s h, las %s con pago real, %s', x->>'persona', trim_scale((x->>'horas')::numeric), trim_scale((x->>'horas_con_pago_real')::numeric), x->>'pagado')
      into e from jsonb_array_elements(v_j->'cobertura') x;
    select format('%s, %s, %s de %s por %s h', jsonb_array_length(v_j->'repartos'), x->>'estado', x->>'monto_obra', x->>'monto', trim_scale((x->>'horas_obra')::numeric))
      into f from jsonb_array_elements(v_j->'repartos') x;
    -- una línea con código (un código de prueba en la tabla de la app; se deshace)
    insert into codigos_partida (codigo, nombre, nombre_en, categoria) values ('C10-PRUEBA', 'C10 PRUEBA código', 'C10 TEST code', 'preliminares');
    perform pg_temp.c10_postear('material con código de la obra A', jsonb_build_array(
      jsonb_build_object('cuenta', '5100', 'monto', '100.00', 'proyecto_id', 'c10-prueba-a', 'cost_code', 'C10-PRUEBA'),
      jsonb_build_object('cuenta', '3100', 'monto', '-100.00')));
    -- y otro pago suyo en la Bandeja, con una hora nueva de esta obra en la semana que le toca
    perform pg_temp.c10_hora(4, 'p1', (select p.desde + 3 from fn_jornal_periodo(pg_temp.c10_d()) p), 'c10-prueba-a', 1);
    m2 := pg_temp.c10_cargo('c10-t46-2', pg_temp.c10_d(), 25.00, 'Zelle payment to C10 PRUEBA ZZANA 9462');
    perform pg_temp.c10_ser('dueno');
    v_k := fn_margen_obra('c10-prueba-a');
    perform pg_temp.c10_ser('editor');
    d := case when (v_k->'por_cost_code'->>'hay')::boolean
              then format('%s %s, y su «bajar» %s', v_k->'por_cost_code'->'filas'->0->>'cost_code', v_k->'por_cost_code'->'filas'->0->>'real',
                          case when pg_temp.c10_bajar(v_k->'por_cost_code'->'filas'->0->'bajar') = 100.00
                                    and v_k->'por_cost_code'->>'nota' = '$100.00 de costo llevan código; el resto ($1,000.25) no.' then 'suma' else 'NO suma' end)
              else 'no sale' end;
    g := format('%s, %s', v_k->'obra'->>'pagos_sin_repartir',
                case when exists (select 1 from jsonb_array_elements_text(v_k->'avisos') x where x like '1 pago(s) de mano de obra de esas semanas siguen sin repartir en la Bandeja%')
                     then 'y lo avisa' else 'y NO lo avisa' end);
    v_obt := format('por CO: %s | por fase: %s | sin código: %s | con una línea con código: %s | la cobertura: %s | los repartos: %s | un pago '
                    'suyo sin repartir: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (46, 'el detalle de una obra (fn_margen_obra): por CO (la base aparte de cada CO), por fase (horas y dólares), por cost code (hoy ninguna línea lo trae y se dice; con una que lo lleve sale con su «bajar»), la cobertura de la mano de obra por persona, los repartos que la tocan y los pagos reconocidos sin repartir',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 47. v_margen_control: con una obra con de todo, en verde (también contra
--     «Estados», c4); y el 40 en rojo cuando un reparto deja de ser su asiento.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; a text; b text; c text;
  v_esp text := 'con una obra con de todo: nada nuevo en rojo, y el costo de cada obra es el de Estados (c4) | un reparto que ya no es su '
                'asiento: el 40 en rojo, con la diferencia (1.00) | de vuelta: verde';
begin
  if pg_temp.c10_omitir(47, 'v_margen_control', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(47, 'v_margen_control', v_esp, 'margen', array[40, 60]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    perform pg_temp.c10_postear('la factura y los costos de la obra A', jsonb_build_array(
      jsonb_build_object('cuenta', '1600', 'monto', '2000.00'),
      jsonb_build_object('cuenta', '4020', 'monto', '-2000.00', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '5100', 'monto', '450.25', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '5200', 'monto', '500.00', 'proyecto_id', 'c10-prueba-a'),
      jsonb_build_object('cuenta', '3100', 'monto', '-950.25')));
    v_mov := pg_temp.c10_cargo('c10-t47', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9047');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s, y %s', split_part(split_part(pg_temp.c10_propios(), 'del margen: ', 2), ' en rojo', 1) || ' en rojo',
                case when (select k.ok and k.detalle like 'Obra por obra, el costo real de aquí es el de «Estados»%' from v_margen_control k where k.orden = 60)
                     then 'el costo de cada obra es el de Estados (c4)'
                     else 'contra Estados: ' || (select k.detalle from v_margen_control k where k.orden = 60) end);
    alter table public.jornal_reparto_lineas disable trigger trg_jornal_reparto_lineas_guarda;
    update jornal_reparto_lineas set monto = monto + 1 where reparto_id = (v_r->>'reparto_id')::uuid and n = 1;
    b := pg_temp.c10_mc(40);
    b := case when b like 'rojo: El libro tiene % de jornales por obra y los repartos aplicados dicen %: diferencia -$1.00.%' then 'el 40 en rojo, con la diferencia (1.00)' else b end;
    update jornal_reparto_lineas set monto = monto - 1 where reparto_id = (v_r->>'reparto_id')::uuid and n = 1;
    c := pg_temp.c10_mc(40);
    v_obt := format('con una obra con de todo: %s | un reparto que ya no es su asiento: %s | de vuelta: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (47, 'v_margen_control: con una obra con factura, material, un subcontrato y jornales, nada nuevo en rojo, y el costo de cada obra es el de «Estados» (v_costo_por_obra, c4); el 40 se pone en rojo si un reparto deja de ser su asiento, y vuelve a verde',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- LO QUE LAS DOS REVISIONES ENCONTRARON (v2): una prueba por hallazgo
-- ---------------------------------------------------------------------
-- 48. UN ESTIMADO PARCIAL NO SE COMPARA CON UN REAL COMPLETO. El costo
--     estimado es mano de obra (horas × tarifa) más material. Si la mitad
--     que falta ya tiene real en la obra, o hay horas estimadas y no hay con
--     qué valorarlas, no hay total: costo_estimado, el margen estimado y la
--     diferencia salen vacíos, estimado_completo es falso y estimado_falta
--     dice qué falta. Lo que falta y todavía no tiene real no estorba.
--     (Antes la mitad que faltaba sumaba 0, y la obra salía «se pasa» o
--     «dentro» contra un real que sí la traía.)
do $$
declare
  v_obt text; o record; v_j jsonb; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'sin presupuesto de material y con material en el libro: sin total, y lo dice (la mano de obra estimada sigue: 3625.00) | sin '
                'horas estimadas y con horas a estándar: sin total, y lo dice | con horas estimadas y sin tarifas en su escenario: sin total, '
                'y lo dice | sin presupuesto de material y sin material en el libro: se compara (1450.00, diferencia 1450.00) | sin nada '
                'estimado: sin estimado, y lo dice | el detalle: el total sin estimado ni diferencia y con su nota; el material — contra '
                '300.00; la mano de obra 3625.00, diferencia 3625.00 | puesto el presupuesto que faltaba: 5625.00, diferencia 5325.00, margen '
                'estimado 3375.00';
begin
  if pg_temp.c10_omitir(48, 'un estimado parcial no se compara con un real completo', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    insert into escenarios (id, nombre, foreman, journeyman, helper, pct_foreman, pct_journeyman, pct_helper, benefits) values
      ('B', 'C10 PRUEBA B', 40, 30, 20, 0.2, 0.5, 0.3, 0.25)
    on conflict (id) do update set foreman = excluded.foreman, journeyman = excluded.journeyman, helper = excluded.helper,
      pct_foreman = excluded.pct_foreman, pct_journeyman = excluded.pct_journeyman, pct_helper = excluded.pct_helper, benefits = excluded.benefits;
    insert into escenarios (id, nombre) values ('C10Z', 'C10 PRUEBA sin tarifas');
    -- I: horas estimadas, SIN presupuesto de material, y material en el libro
    update proyectos set horas_estimadas = 100 where id = 'c10-prueba-i';
    insert into finanzas_proyecto (proyecto_id, contrato, presupuesto_materiales) values ('c10-prueba-i', 9000, null)
    on conflict (proyecto_id) do update set contrato = excluded.contrato, presupuesto_materiales = excluded.presupuesto_materiales;
    perform pg_temp.c10_postear('el material de la obra I', jsonb_build_array(
      jsonb_build_object('cuenta', '5100', 'monto', '300.00', 'proyecto_id', 'c10-prueba-i'),
      jsonb_build_object('cuenta', '3100', 'monto', '-300.00')));
    -- J: presupuesto de material, SIN horas estimadas, y horas a estándar
    update proyectos set horas_estimadas = null where id = 'c10-prueba-j';
    insert into finanzas_proyecto (proyecto_id, contrato, presupuesto_materiales) values ('c10-prueba-j', 5000, 2000)
    on conflict (proyecto_id) do update set contrato = excluded.contrato, presupuesto_materiales = excluded.presupuesto_materiales;
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-j', 2);
    -- K: horas estimadas y material, pero su estimado va con un escenario sin tarifas
    update proyectos set horas_estimadas = 50 where id = 'c10-prueba-k';
    insert into finanzas_proyecto (proyecto_id, contrato, presupuesto_materiales) values ('c10-prueba-k', 4000, 1000)
    on conflict (proyecto_id) do update set contrato = excluded.contrato, presupuesto_materiales = excluded.presupuesto_materiales;
    insert into estimados (id, nombre, proyecto_id, escenario, estado, benefits_pct, creado) overriding system value
    values (-1010000048, 'C10 PRUEBA estimado de la obra K', 'c10-prueba-k', 'C10Z', 'borrador', null, now());
    -- L: horas estimadas, sin material presupuestado NI en el libro; H: nada
    -- estimado (y con horas a estándar: sigue siendo «no hay estimado», no «incompleto»)
    update proyectos set horas_estimadas = 40 where id = 'c10-prueba-l';
    delete from finanzas_proyecto where proyecto_id in ('c10-prueba-l', 'c10-prueba-h');
    update proyectos set horas_estimadas = null where id = 'c10-prueba-h';
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-h', 3);
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"burden_estandar_pct": 0}');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    a := case when o.costo_estimado is null and not o.estimado_completo and o.margen_estimado is null and o.margen_estimado_pct is null
                   and o.diferencia is null
                   and o.estimado_falta = 'Estimado incompleto: no tiene presupuesto de material y ya lleva $300.00 de material en el libro. '
                                          'No da un total que comparar con el costo real: se compara concepto por concepto lo que sí está estimado.'
                   and o.avisos @> array[o.estimado_falta, 'Sin presupuesto de material.']
              then format('sin total, y lo dice (la mano de obra estimada sigue: %s)', o.mano_obra_estimada)
              else 'mal: ' || to_jsonb(o)::text end;
    v_j := fn_margen_obra('c10-prueba-i');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-j';
    b := case when o.costo_estimado is null and not o.estimado_completo and o.diferencia is null and o.material_presupuesto = 2000
                   and o.estimado_falta like 'Estimado incompleto: no tiene horas estimadas y ya lleva mano de obra (2 h a estándar). No da un total%'
                   and o.avisos @> array[o.estimado_falta]
              then 'sin total, y lo dice' else 'mal: ' || coalesce(o.estimado_falta, '(sin porqué)') || ' / ' || coalesce(o.costo_estimado::text, 'nulo') end;
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-k';
    c := case when o.costo_estimado is null and not o.estimado_completo and o.diferencia is null and o.tarifa_estimada is null
                   and o.estimado_falta like 'Estimado incompleto: hay 50 h estimadas y falta el escenario C10Z del estimador (o sus tarifas) para valorarlas. No da un total%'
              then 'sin total, y lo dice' else 'mal: ' || coalesce(o.estimado_falta, '(sin porqué)') || ' / ' || coalesce(o.costo_estimado::text, 'nulo') end;
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-l';
    d := case when o.estimado_completo and o.estimado_falta is null and o.material_presupuesto is null
              then format('se compara (%s, diferencia %s)', o.costo_estimado, o.diferencia)
              else 'mal: ' || coalesce(o.estimado_falta, '(sin porqué)') end;
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    e := case when o.costo_estimado is null and not o.estimado_completo and o.diferencia is null and o.horas_estandar = 3
                   and o.estimado_falta = 'No hay estimado: faltan las horas estimadas y el presupuesto de material.'
                   and o.avisos @> array['Sin horas estimadas.', 'Sin presupuesto de material.'] and not (o.avisos @> array[o.estimado_falta])
              then 'sin estimado, y lo dice' else 'mal: ' || coalesce(o.estimado_falta, '(sin porqué)') end;
    select format('el total %s; el material %s contra %s; la mano de obra %s, diferencia %s',
                  (select case when x->'estimado' = 'null'::jsonb and x->'diferencia' = 'null'::jsonb and not (x->>'estimado_completo')::boolean
                                    and x->>'nota' like 'Estimado incompleto: no tiene presupuesto de material%' and (x->>'real')::numeric = 300.00
                               then 'sin estimado ni diferencia y con su nota' else x::text end
                     from jsonb_array_elements(v_j->'conceptos') x where x->>'concepto' = 'total'),
                  (select coalesce(x->>'estimado', '—') from jsonb_array_elements(v_j->'conceptos') x where x->>'concepto' = 'material'),
                  (select x->>'real' from jsonb_array_elements(v_j->'conceptos') x where x->>'concepto' = 'material'),
                  (select x->>'estimado' from jsonb_array_elements(v_j->'conceptos') x where x->>'concepto' = 'mano_obra'),
                  (select x->>'diferencia' from jsonb_array_elements(v_j->'conceptos') x where x->>'concepto' = 'mano_obra'))
      into f;
    perform pg_temp.c10_ser('editor');
    update finanzas_proyecto set presupuesto_materiales = 2000 where proyecto_id = 'c10-prueba-i';
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-i';
    g := case when o.estimado_completo and o.estimado_falta is null
              then format('%s, diferencia %s, margen estimado %s', o.costo_estimado, o.diferencia, o.margen_estimado)
              else 'mal: ' || coalesce(o.estimado_falta, '(sin porqué)') end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('sin presupuesto de material y con material en el libro: %s | sin horas estimadas y con horas a estándar: %s | con horas '
                    'estimadas y sin tarifas en su escenario: %s | sin presupuesto de material y sin material en el libro: %s | sin nada '
                    'estimado: %s | el detalle: %s | puesto el presupuesto que faltaba: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (48, 'UN ESTIMADO PARCIAL NO SE COMPARA CON UN REAL COMPLETO: si falta el presupuesto de material y la obra ya lleva material, o faltan las horas estimadas y ya lleva mano de obra, o hay horas estimadas y su escenario no tiene tarifas, costo_estimado, el margen estimado y la diferencia salen vacíos, estimado_completo es falso y estimado_falta dice qué falta; lo que falta y aún no tiene real no estorba; sin nada, «no hay estimado»; el detalle compara concepto por concepto',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 49. LAS HORAS QUE LLEGAN TARDE a una semana ya repartida. Repartido el
--     pago de la semana, la persona reporta después unas horas de esa misma
--     semana: no recibieron nada (el pago sigue entre las demás obras) y en
--     su obra salen a estándar. Antes todo quedaba en verde. Ahora lo dicen
--     el control (el 35, un aviso), la obra, y la propuesta del pago
--     siguiente (con las fechas que las cogerían). Se arregla repartiéndolas
--     con el pago que las cubra, o deshaciendo y repitiendo aquel reparto.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_r jsonb; v_j jsonb; o record; a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'repartida la semana: el 35 verde | llega un reporte de esa semana: el 35 en rojo, de nivel aviso, lo nombra y dice qué '
                'hacer, sin nombrar funciones; los demás, como estaban | la obra: 6 h a estándar, y lo avisa | el pago siguiente (otra '
                'semana): avisa [sin_horas,horas_tardias], 6 h en 1 reporte, con sus fechas | con sus fechas a mano: h 6→150.00 '
                '[se_pisa] | deshecho y vuelto a repartir el primero: a 8→133.33, b 4→66.67, h 6→100.00, y el 35 verde | o repartidas con '
                'el pago siguiente: el 35 verde, y la obra ya sin horas a estándar';
begin
  if pg_temp.c10_omitir(49, 'las horas que llegan tarde a una semana ya repartida', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(49, 'las horas que llegan tarde a una semana ya repartida', v_esp, 'jornal', array[35]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    m1 := pg_temp.c10_cargo('c10-t49-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9491');
    m2 := pg_temp.c10_cargo('c10-t49-2', pg_temp.c10_d(), 150.00, 'Zelle payment to C10 PRUEBA ZZANA 9492');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"burden_estandar_pct": 0}');
    perform pg_temp.c10_ser('editor');
    v_r := pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := pg_temp.c10_jc(35);
    -- (el sábado de esa semana, reportado después del «Así es»)
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(5), 'c10-prueba-h', 6);
    b := pg_temp.c10_jc(35);
    b := format('%s; %s',
                case when b like 'rojo: Zzana C10 PRUEBA: 6 h en 1 reporte(s) (' || fn_jornal_dia(pg_temp.c10_w1(5)) || ' en C10 PRUEBA Obra H) dentro del reparto del pago del '
                                 || pg_temp.c10_d() || ' → se reportaron o se movieron después de repartir esa semana%Toca «Deshacer» en ese reparto%'
                                 || 'repártelas con él eligiendo sus fechas a mano.'
                          and (select k.nivel from v_jornal_control k where k.orden = 35) = 'aviso' and b !~ 'fn_|v_jornal|v_margen'
                     then 'el 35 en rojo, de nivel aviso, lo nombra y dice qué hacer, sin nombrar funciones' else b end,
                case when (select coalesce(string_agg(k.orden::text, ',' order by k.orden), '') from v_jornal_control k
                            where not k.ok and k.orden <> 35 and k.orden::text <> all (string_to_array(pg_temp.c10('jc_rojos'), ','))) = ''
                          and split_part(pg_temp.c10_propios(), 'del margen: ', 2) = 'nada nuevo en rojo'
                     then 'los demás, como estaban' else pg_temp.c10_propios() end);
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    perform pg_temp.c10_ser('editor');
    c := format('%s h a estándar, %s', trim_scale(o.horas_estandar),
                case when exists (select 1 from unnest(o.avisos) x
                                   where x like '6 h de esta obra son de una semana ya repartida y no entraron en su reparto (Zzana C10 PRUEBA, pago del '
                                                || fn_jornal_dia(pg_temp.c10_d()) || '): se reportaron o se movieron después. Aquí salen a estándar%')
                     then 'y lo avisa' else 'y NO lo avisa: ' || array_to_string(o.avisos, ' · ') end);
    -- el pago siguiente, por otra semana: no las recoge, y lo dice
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    d := format('avisa [%s], %s h en %s reporte, %s', pg_temp.c10_avisos(v_j),
                (select trim_scale((x->>'horas')::numeric) from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = 'horas_tardias'),
                (select x->>'reportes' from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = 'horas_tardias'),
                case when (select (x->>'desde')::date = pg_temp.c10_w1(5) and (x->>'hasta')::date = pg_temp.c10_w1(5)
                                  and x->>'texto' like 'Zzana C10 PRUEBA tiene 6 h de una semana ya repartida que no están en ningún reparto%'
                             from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = 'horas_tardias')
                     then 'con sus fechas' else 'sin sus fechas' end);
    -- con las fechas que las cogen (a mano), entran
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w1(5), pg_temp.c10_w1(5));
    e := format('%s [%s]', pg_temp.c10_lineas(v_j), pg_temp.c10_avisos(v_j));
    -- arreglo 1: deshacer aquel reparto y repetirlo con las horas de hoy
    begin
      perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: llegó un reporte de esa semana');
      f := format('%s, y el 35 %s', pg_temp.c10_lineas(pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6))), pg_temp.c10_jc(35));
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    -- arreglo 2: repartirlas con el pago que las cubre
    perform pg_temp.c10_aplicar(m2, pg_temp.c10_w1(5), pg_temp.c10_w1(5));
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-h';
    perform pg_temp.c10_ser('editor');
    g := format('el 35 %s, y la obra %s', pg_temp.c10_jc(35),
                case when o.horas_estandar = 0 and o.mano_obra_jornales = 150.00
                          and not exists (select 1 from unnest(o.avisos) x where x like '%semana ya repartida%')
                     then 'ya sin horas a estándar' else 'con ' || trim_scale(o.horas_estandar) || ' h a estándar' end);
    v_obt := format('repartida la semana: el 35 %s | llega un reporte de esa semana: %s | la obra: %s | el pago siguiente (otra semana): %s | '
                    'con sus fechas a mano: %s | deshecho y vuelto a repartir el primero: %s | o repartidas con el pago siguiente: %s',
                    a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (49, 'LAS HORAS QUE LLEGAN TARDE a una semana ya repartida (se reportaron después del «Así es») ya no pasan calladas: el control del jornal lo dice (el 35, un aviso, con la persona, las horas, la obra y el pago), la obra avisa de que esas horas salen a estándar con el pago repartido entre las demás, y la propuesta del pago siguiente las ofrece con sus fechas; se arregla repartiéndolas con ese pago o deshaciendo y repitiendo el primero',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 50. EL PAGO DE UNA PERSONA DADA DE ALTA RESUELTO POR OTRO CAMINO
--     (clasificado a mano en la Bandeja: 5200 entero a una obra). Su costo
--     queda entero ahí, sin su nombre, y sus horas de esas semanas salen
--     además a estándar: la semana cuenta dos veces en el costo con
--     estándar. Antes, todo en verde. Ahora lo dicen el control (el 70, un
--     aviso) y cada obra con horas suyas sin pago; des-casado y repartido
--     por horas, se va.
do $$
declare
  v_obt text; m1 uuid; o record; p record; a text; b text; c text; d text; e text;
  v_esp text := 'en la Bandeja: el 70 verde | clasificado a mano (5200 entero a la obra A): el 70 en rojo, de nivel aviso, nombra el pago, '
                'cómo se resolvió y las 12 h sin pago, y dice qué hacer, sin nombrar funciones | la obra A: subcontratos 300.00, mano de '
                'obra real 0.00, 8 h a estándar (200.00), y lo avisa; la B: 4 h a estándar, y lo avisa | des-casado en la Bandeja: el 70 '
                'verde | repartido por sus horas: A 200.00 y B 100.00 de mano de obra real, sin horas a estándar y sin el aviso';
begin
  if pg_temp.c10_omitir(50, 'el pago de una persona dada de alta resuelto fuera del jornal', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(50, 'el pago de una persona dada de alta resuelto fuera del jornal', v_esp, 'jornal', array[70]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    m1 := pg_temp.c10_cargo('c10-t50', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9050');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"burden_estandar_pct": 0}');
    perform pg_temp.c10_ser('editor');
    a := pg_temp.c10_jc(70);
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_clasificar(m1, '[{"cuenta": "5200", "proyecto_id": "c10-prueba-a"}]'::jsonb, 'c10-pruebas: clasificado a mano, sin repartir');
    perform pg_temp.c10_ser('editor');
    b := pg_temp.c10_jc(70);
    b := case when b like 'rojo: el pago del ' || pg_temp.c10_d() || ' a Zzana C10 PRUEBA por $300.00 (%clasificado%, asiento %): 12 h suyas sin pago del '
                          || (pg_temp.c10('lunes')::date - 7) || ' al ' || (pg_temp.c10('lunes')::date + 6)
                          || ' → si era su pago por horas, su costo quedó entero donde se clasificó%Des-cásalo en la Bandeja, con su motivo, y repártelo por sus horas.%'
                   and (select k.nivel from v_jornal_control k where k.orden = 70) = 'aviso' and b !~ 'fn_|v_jornal|v_margen'
              then 'el 70 en rojo, de nivel aviso, nombra el pago, cómo se resolvió y las 12 h sin pago, y dice qué hacer, sin nombrar funciones'
              else b end;
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    select * into p from v_margen_obra where proyecto_id = 'c10-prueba-b';
    perform pg_temp.c10_ser('editor');
    c := format('la obra A: subcontratos %s, mano de obra real %s, %s h a estándar (%s), %s; la B: %s h a estándar, %s', o.subcontratos_real,
                o.mano_obra_real, trim_scale(o.horas_estandar), o.mano_obra_estandar,
                case when exists (select 1 from unnest(o.avisos) x
                                   where x like '1 pago(s) de mano de obra se resolvieron en la Bandeja sin repartir por horas ($300.00 a Zzana C10 PRUEBA el '
                                                || fn_jornal_dia(pg_temp.c10_d()) || '): si era el pago de esas semanas%Des-cásalo en la Bandeja y repártelo por sus horas.')
                     then 'y lo avisa' else 'y NO lo avisa' end,
                trim_scale(p.horas_estandar),
                case when exists (select 1 from unnest(p.avisos) x where x like '1 pago(s) de mano de obra se resolvieron en la Bandeja sin repartir por horas%')
                     then 'y lo avisa' else 'y NO lo avisa' end);
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_descasar(m1, 'c10-pruebas: era su pago por horas');
    perform pg_temp.c10_ser('editor');
    d := pg_temp.c10_jc(70);
    perform pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    select * into p from v_margen_obra where proyecto_id = 'c10-prueba-b';
    perform pg_temp.c10_ser('editor');
    e := format('A %s y B %s de mano de obra real, %s', o.mano_obra_real, p.mano_obra_real,
                case when o.horas_estandar = 0 and p.horas_estandar = 0 and o.subcontratos_real = 0
                          and not exists (select 1 from unnest(o.avisos || p.avisos) x where x like '%sin repartir por horas%')
                          and pg_temp.c10_jc(70) = 'verde'
                     then 'sin horas a estándar y sin el aviso' else 'con algo todavía: ' || array_to_string(o.avisos, ' · ') end);
    v_obt := format('en la Bandeja: el 70 %s | clasificado a mano (5200 entero a la obra A): %s | %s | des-casado en la Bandeja: el 70 %s | '
                    'repartido por sus horas: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (50, 'EL PAGO DE UNA PERSONA DADA DE ALTA RESUELTO FUERA DEL JORNAL (clasificado a mano en la Bandeja) ya no pasa callado: el control del jornal lo dice (el 70, un aviso: el pago, cómo se resolvió, las horas suyas sin pago y qué hacer) y cada obra con horas suyas de esas semanas avisa de que salen además a estándar; des-casado y repartido por sus horas, el aviso se va y la mano de obra queda como real en sus obras',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 51. LO DE LA IA (c8) QUE UN JORNAL DEJA ABIERTO. c10 no puede cerrar
--     propuestas de c8 (son de su función de borde); las devuelve, con qué
--     hacer con cada una, para que la pantalla las cierre, y las enseña en
--     su control (el 80, un aviso) mientras sigan abiertas:
--       · la PENDIENTE del movimiento (ya no se puede aprobar: «rechazar»);
--       · la APROBADA cuyo asiento se reversó —Edgar la aceptó y después
--         des-casó el pago para repartirlo por horas— («caducar»): deja en
--         rojo el cuadre 60 de c8, y antes c10 ni la veía.
--     (El «Así es» no se frena por una pendiente: cabecera, «decisiones».)
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_p uuid; v_p2 uuid; v_j jsonb; v_r jsonb; v_c0 text[]; v_c1 text[]; v_c2 text[]; v_c3 text[];
  a text; b text; c text; d text; e text; f text; g text;
  v_esp text := 'pendiente: la propuesta trae 1 abierta (pendiente → rechazar) | aplicar la devuelve, y el 80 lo dice (un aviso, con lo que '
                'proponía y qué hacer, sin nombrar funciones) | para reintentar: 1 | rechazada (lo que hace la pantalla): el 80 verde | '
                'aprobada y des-casada: c8 60 en rojo; la propuesta trae 1 abierta (sin_asiento → caducar) y ninguna pendiente | repartido: '
                'aplicar la devuelve y el 80 lo dice; c8 sigue con el 60 (c10 no lo cierra) | caducada (lo que hace la pantalla): el 80 '
                'verde y c8 sin cuadres nuevos';
begin
  if pg_temp.c10('hay_c8') <> 'true' then
    insert into _pruebas values (51, 'lo de la IA (c8) que un jornal deja abierto se devuelve y se enseña en el control', v_esp,
                                 'omitida: c8 no está en esta base', null);
    return;
  end if;
  if pg_temp.c10_omitir(51, 'lo de la IA (c8) que un jornal deja abierto', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(51, 'lo de la IA (c8) que un jornal deja abierto', v_esp, 'jornal', array[80]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-b', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w2(0), 'c10-prueba-b', 4);
    m1 := pg_temp.c10_cargo('c10-t51-1', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9511');
    m2 := pg_temp.c10_cargo('c10-t51-2', pg_temp.c10_d(), 100.00, 'Zelle payment to C10 PRUEBA ZZANA 9512');
    perform pg_temp.c10_alta('p1');
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_c0;
    -- (a) la propuesta PENDIENTE de la IA para ese Zelle, como la deja su rutina
    execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta)
                values ($1, 'edgar', '{"lineas": [{"cuenta": "5200", "proyecto_id": "c10-prueba-b"}], "motivo": "C10 PRUEBA", "confianza": 1, "flags": {}}'::jsonb)
                returning id $q$ into v_p using m1;
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := case when (v_j->>'propuesta_ia')::uuid = v_p and jsonb_array_length(v_j->'propuestas_ia') = 1
              then format('la propuesta trae 1 abierta (%s → %s)', v_j->'propuestas_ia'->0->>'clase', v_j->'propuestas_ia'->0->>'que_hacer')
              else 'la propuesta trae ' || (v_j->'propuestas_ia')::text end;
    v_r := pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    b := pg_temp.c10_jc(80);
    b := format('%s, y %s',
                case when (v_r->>'propuesta_ia')::uuid = v_p and (v_r->'propuestas_ia'->0->>'propuesta_id')::uuid = v_p then 'aplicar la devuelve' else 'aplicar NO la devuelve' end,
                case when b like 'rojo: el pago del ' || pg_temp.c10_d() || ' a Zzana C10 PRUEBA ($200.00): su propuesta de la IA sigue pendiente (proponía 5200 → C10 PRUEBA Obra B)'
                                 || ' → ya no se pueden aprobar%a la pendiente se le dice «No es eso»%'
                          and (select k.nivel from v_jornal_control k where k.orden = 80) = 'aviso' and b !~ 'fn_|v_jornal|v_margen|v_contador'
                     then 'el 80 lo dice (un aviso, con lo que proponía y qué hacer, sin nombrar funciones)' else 'el 80: ' || b end);
    perform pg_temp.c10_ser('dueno');
    select count(*)::text into c from fn_jornal_ia(null) i where i.movimiento_id in (m1, m2);
    perform pg_temp.c10_ser('editor');
    -- (lo que hace la pantalla por la función de borde «contador»: «No es eso»)
    execute 'select public.fn_contador_rechazar($1, $2, $3)' using v_p, pg_temp.c10('dueno')::uuid, 'c10-pruebas: se repartió por sus horas';
    d := 'el 80 ' || pg_temp.c10_jc(80);
    -- (b) la APROBADA cuyo asiento se reversa: Edgar acepta la propuesta de la IA y después des-casa el pago para repartirlo
    execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta)
                values ($1, 'edgar', '{"lineas": [{"cuenta": "5200", "proyecto_id": "c10-prueba-b"}], "motivo": "C10 PRUEBA", "confianza": 1, "flags": {}}'::jsonb)
                returning id $q$ into v_p2 using m2;
    execute 'select public.fn_contador_aprobar($1, $2, null, false)' using v_p2, pg_temp.c10('dueno')::uuid;
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_descasar(m2, 'c10-pruebas: es mano de obra, va por sus horas');
    perform pg_temp.c10_ser('editor');
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_c1;
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    e := format('c8 %s en rojo; %s', pg_temp.c10_nuevos(v_c0, v_c1),
                case when v_j->'propuesta_ia' = 'null'::jsonb and jsonb_array_length(v_j->'propuestas_ia') = 1
                          and (v_j->'propuestas_ia'->0->>'propuesta_id')::uuid = v_p2 and v_j->'propuestas_ia'->0->>'estado' = 'aprobada'
                     then format('la propuesta trae 1 abierta (%s → %s) y ninguna pendiente', v_j->'propuestas_ia'->0->>'clase', v_j->'propuestas_ia'->0->>'que_hacer')
                     else 'la propuesta trae ' || (v_j->'propuestas_ia')::text end);
    v_r := pg_temp.c10_aplicar(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_c2;
    f := pg_temp.c10_jc(80);
    f := format('%s; c8 sigue con el %s (c10 no lo cierra)',
                case when (v_r->'propuestas_ia'->0->>'propuesta_id')::uuid = v_p2 and v_r->'propuesta_ia' = 'null'::jsonb
                          and f like 'rojo: el pago del ' || pg_temp.c10_d() || ' a Zzana C10 PRUEBA ($100.00): su propuesta de la IA está aprobada y su asiento % ya no vive (proponía 5200 → C10 PRUEBA Obra B)'
                                     || ' → %la aprobada cuyo asiento se reversó se cierra con su motivo%'
                     then 'aplicar la devuelve y el 80 lo dice' else 'el 80: ' || f end,
                pg_temp.c10_nuevos(v_c0, v_c2));
    -- (lo que hace la pantalla: «caducar», con su motivo)
    execute 'select public.fn_contador_caducar($1, $2, $3)' using v_p2, pg_temp.c10('dueno')::uuid, 'c10-pruebas: se repartió por sus horas';
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_c3;
    g := format('el 80 %s y c8 %s', pg_temp.c10_jc(80), case when pg_temp.c10_nuevos(v_c0, v_c3) = 'ninguno' then 'sin cuadres nuevos' else 'con ' || pg_temp.c10_nuevos(v_c0, v_c3) end);
    v_obt := format('pendiente: %s | %s | para reintentar: %s | rechazada (lo que hace la pantalla): %s | aprobada y des-casada: %s | repartido: '
                    '%s | caducada (lo que hace la pantalla): %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (51, 'LO DE LA IA (c8) QUE UN JORNAL DEJA ABIERTO: la propuesta pendiente del movimiento y la aprobada cuyo asiento se reversó (des-casado para repartirlo) salen en propuestas_ia —con qué hacer: rechazar o caducar— en la propuesta y en lo que devuelve aplicar, fn_jornal_ia las da para reintentar, y el control del jornal las enseña (el 80, un aviso) hasta que la pantalla las cierra por la función de borde; c10 no escribe en c8',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 52. LA HUELLA CUBRE EXACTAMENTE LO QUE EL «ASÍ ES» APRUEBA. Aplicar manda
--     a c3 TODOS los reportes sin aprobar de esas fechas, también los que no
--     entran porque ya los cubre otro pago. Antes la huella llevaba solo los
--     que entran: una hora cubierta que cambiaba entre que Edgar miraba y
--     tocaba (c3 le quita la aprobación) se aprobaba con horas que él no vio.
--     Ahora la huella lleva cada reporte que se aprueba: MX011, y nada cambia.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_k jsonb; v_r jsonb; a text; b text; c text; d text; e text; v_antes text;
  v_esp text := 'lo que Edgar ve: entran 12 h, 12 h cubiertas, y va a aprobar 2 reportes [horas_cubiertas,se_pisa] | cambia una hora '
                'cubierta (c3 le quita la aprobación) y toca «Así es» con lo que vio: MX011, y nada cambió | lo que ve ahora: va a aprobar '
                '3 —la cubierta que cambió, avisada [horas_cubiertas,cubiertas_sin_aprobar,se_pisa]—, con otra huella | con la de ahora: '
                'entra, aprueba las 3 y queda escrito lo que vio | el reparto que la cubría: el control 30 lo dice';
begin
  if pg_temp.c10_omitir(52, 'la huella cubre lo que el «Así es» aprueba', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w2(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w2(1), 'c10-prueba-b', 4);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(0), 'c10-prueba-h', 8);
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(1), 'c10-prueba-i', 4);
    m1 := pg_temp.c10_cargo('c10-t52-1', pg_temp.c10_d(), 300.00, 'Zelle payment to C10 PRUEBA ZZANA 9521');
    m2 := pg_temp.c10_cargo('c10-t52-2', pg_temp.c10_d(), 360.00, 'Zelle payment to C10 PRUEBA ZZANA 9522');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_aplicar(m1, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    -- Edgar mira el segundo pago con las dos semanas (la primera ya la cubre el otro reparto)
    v_j := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w1(6));
    a := format('entran %s h, %s h cubiertas, y va a aprobar %s reportes [%s]', trim_scale((v_j->>'horas')::numeric),
                trim_scale((v_j->'cubiertas'->>'horas')::numeric),
                case when v_j->'aprueba'->'ids' = '[-1010000004, -1010000003]'::jsonb then v_j->'aprueba'->>'reportes' else (v_j->'aprueba')::text end,
                pg_temp.c10_avisos(v_j));
    select format('%s|%s|%s|%s|%s', (select count(*) from asientos), (select count(*) from jornal_repartos),
                  (select count(*) from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null),
                  (select count(*) from horas_aprobaciones where accion = 'aprobada'), (select m.estado from movimientos_banco m where m.id = m2)) into v_antes;
    -- …y entre medias cambia una hora CUBIERTA (del otro reparto): c3 le tumba la aprobación
    perform pg_temp.c10_corregir(1, 'horas = 7');
    v_antes := v_antes || '|' || (select (h.aprobado_el is null)::text from horas h where h.id = -1010000001);
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(m2, pg_temp.c10_w2(0), pg_temp.c10_w1(6), v_j->>'visto');
      b := 'entró';
    exception when others then b := sqlstate;
    end;
    perform pg_temp.c10_ser('editor');
    b := b || case when (select format('%s|%s|%s|%s|%s', (select count(*) from asientos), (select count(*) from jornal_repartos),
                                       (select count(*) + 1 from horas h where h.usuario_id = pg_temp.c10('p1')::uuid and h.aprobado_el is not null),
                                       (select count(*) from horas_aprobaciones where accion = 'aprobada'),
                                       (select m.estado from movimientos_banco m where m.id = m2))
                                || '|' || (select (h.aprobado_el is null)::text from horas h where h.id = -1010000001)) = v_antes
                   then ', y nada cambió' else ', y ALGO cambió' end;
    v_k := pg_temp.c10_propuesta(m2, pg_temp.c10_w2(0), pg_temp.c10_w1(6));
    c := format('va a aprobar %s —%s [%s]—, %s',
                case when v_k->'aprueba'->'ids' = '[-1010000004, -1010000003, -1010000001]'::jsonb then v_k->'aprueba'->>'reportes' else (v_k->'aprueba')::text end,
                case when (select x->'horas_ids' = '[-1010000001]'::jsonb and x->>'texto' like '1 reporte(s) de esas fechas que no entran en este reparto están sin aprobar%Al aceptar quedan aprobados como están hoy.%'
                             from jsonb_array_elements(v_k->'avisos') x where x->>'codigo' = 'cubiertas_sin_aprobar')
                     then 'la cubierta que cambió, avisada' else 'sin avisar de la cubierta' end,
                pg_temp.c10_avisos(v_k),
                case when v_k->>'visto' <> v_j->>'visto' then 'con otra huella' else 'con la MISMA huella' end);
    v_r := pg_temp.c10_aplicar(m2, pg_temp.c10_w2(0), pg_temp.c10_w1(6));
    d := format('%s, aprueba las %s y %s', case when v_r->>'estado' = 'aplicado' and (v_r->>'horas')::numeric = 12 then 'entra' else 'no entra' end,
                case when v_r->'horas_aprobadas'->'ids' = '[-1010000004, -1010000003, -1010000001]'::jsonb then v_r->'horas_aprobadas'->>'reportes' else (v_r->'horas_aprobadas')::text end,
                case when (select ap.horas = 7 and ap.detalle->'visto'->'ids' = '[-1010000004, -1010000003, -1010000001]'::jsonb
                             from horas_aprobaciones ap where ap.horas_id = -1010000001 and ap.accion = 'aprobada' order by ap.hecho_el desc limit 1)
                     then 'queda escrito lo que vio' else 'NO queda escrito lo que vio' end);
    e := pg_temp.c10_jc(30);
    e := case when e like 'rojo: %el reporte -1010000001 del ' || pg_temp.c10_w2(0) || ' cambió de horas (de 8 a 7)%' then 'el control 30 lo dice' else e end;
    v_obt := format('lo que Edgar ve: %s | cambia una hora cubierta (c3 le quita la aprobación) y toca «Así es» con lo que vio: %s | lo que ve '
                    'ahora: %s | con la de ahora: %s | el reparto que la cubría: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (52, 'LA HUELLA CUBRE EXACTAMENTE LO QUE EL «ASÍ ES» APRUEBA: lleva cada reporte de esas fechas que se va a aprobar, entre o no en el reparto («aprueba»); si una hora que ya cubre otro pago cambia entre que Edgar mira y toca (c3 le quita la aprobación), aplicar da MX011 y nada cambia —antes la aprobaba con horas que él no vio—; al volver a mirar la ve avisada (cubiertas_sin_aprobar) y entonces sí',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 53. EL CO Y LA FASE, LIMPIOS COMO LOS DEJA c6. Un CO con un salto de línea
--     detrás (un pegado, el conector) o que es solo un tabulador: c6 limpia
--     tabuladores y saltos al postear, y c10 quitaba solo espacios: el mismo
--     CO salía en dos grupos, el asiento «no era el reparto» y el pago no se
--     podía repartir (MX001 «la línea 3… Avisa»). Ahora van limpios igual en
--     el núcleo, la propuesta, la huella, el margen y el control; lo que solo
--     cambia por las mayúsculas se avisa (co_parecidos) y no se adivina; y si
--     el asiento de c6 no fuera el reparto, el error dice qué línea, qué
--     campo y qué hacer.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_r jsonb; v_k jsonb; a text; b text; c text; d text; e text; f text;
  v_esp text := 'tres grupos: base 2→50.00, CO #1 6→150.00, co #1 2→50.00 [co_parecidos], y se puede aplicar | el aviso nombra los dos CO '
                'parecidos | aplicado: 4 líneas, el CO sin saltos ni tabuladores; el detalle guarda «CO #1» y la fase «rough»; control del '
                'jornal: nada nuevo en rojo; del margen: nada nuevo en rojo | el margen por CO: Base (sin CO) 2 h, CO #1 6 h, co #1 2 h | si el '
                'asiento del banco no fuera el reparto: MX001, dice la línea, el campo y qué hacer, y nada cambia';
begin
  if pg_temp.c10_omitir(53, 'el CO y la fase, limpios como los deja c6', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 4, E'CO #1\n', E'rough\n');
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 2, 'CO #1', 'rough');
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-a', 1, E'\t');
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(3), 'c10-prueba-a', 1);
    perform pg_temp.c10_hora(5, 'p1', pg_temp.c10_w1(4), 'c10-prueba-a', 2, E' co #1\r\n');
    perform pg_temp.c10_hora(6, 'p1', pg_temp.c10_w2(0), 'c10-prueba-b', 2, 'CO #9');
    m1 := pg_temp.c10_cargo('c10-t53-1', pg_temp.c10_d(), 250.00, 'Zelle payment to C10 PRUEBA ZZANA 9531');
    m2 := pg_temp.c10_cargo('c10-t53-2', pg_temp.c10_d(), 50.00, 'Zelle payment to C10 PRUEBA ZZANA 9532');
    perform pg_temp.c10_alta('p1');
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    -- (los grupos, la base primero y los CO por su letra: el orden de dos CO que solo cambian en las mayúsculas depende
    -- de la intercalación de la base, y aquí no importa)
    select format('%s grupos: %s [%s], y %s', case jsonb_array_length(v_j->'lineas') when 3 then 'tres' else jsonb_array_length(v_j->'lineas')::text end,
                  string_agg(format('%s %s→%s', coalesce(l->>'co', 'base'), trim_scale((l->>'horas')::numeric), l->>'monto'), ', '
                             order by (l->>'co' is null) desc, (l->>'co') collate "C"),
                  pg_temp.c10_avisos(v_j), case when (v_j->>'puede_aplicar')::boolean then 'se puede aplicar' else 'NO se puede: ' || (v_j->>'por_que') end)
      into a from jsonb_array_elements(v_j->'lineas') l;
    b := case when pg_temp.c10_aviso(v_j, 'co_parecidos') ~ '^Hay CO escritos de dos formas en la misma obra \(C10 PRUEBA Obra A: («CO #1» y «co #1»|«co #1» y «CO #1»)\): salen como líneas distintas\.'
              then 'el aviso nombra los dos CO parecidos' else coalesce(pg_temp.c10_aviso(v_j, 'co_parecidos'), 'sin aviso') end;
    v_r := pg_temp.c10_aplicar(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    select format('%s líneas, el CO %s; el detalle guarda «%s» y la fase «%s»; %s', count(*),
                  case when bool_and(l.co is not distinct from fn_jornal_limpio(l.co)) and count(*) filter (where l.co = 'CO #1') = 1
                            and count(*) filter (where l.co = 'co #1') = 1 and count(*) filter (where l.co is null) = 2
                       then 'sin saltos ni tabuladores' else 'CON algo raro' end,
                  (select rh.co from jornal_reparto_horas rh where rh.reparto_id = (v_r->>'reparto_id')::uuid and rh.horas_id = -1010000001),
                  (select rh.fase from jornal_reparto_horas rh where rh.reparto_id = (v_r->>'reparto_id')::uuid and rh.horas_id = -1010000001),
                  pg_temp.c10_propios())
      into c from asiento_lineas l where l.asiento_id = (v_r->'asiento'->>'id')::uuid;
    perform pg_temp.c10_ser('dueno');
    v_k := fn_margen_obra('c10-prueba-a');
    perform pg_temp.c10_ser('editor');
    select string_agg(format('%s %s h', x->>'etiqueta', trim_scale((x->>'horas')::numeric)), ', ' order by (x->>'co' is null) desc, (x->>'co') collate "C")
      into d from jsonb_array_elements(v_k->'por_co') x;
    -- LA RED: si c6 dejara otra cosa en la línea (aquí, un trigger de prueba le cambia el CO al entrar), el error lo dice
    begin
      create function public.c10_prueba_altera() returns trigger language plpgsql as $f$
      begin
        if new.co = 'CO #9' then new.co := 'CO #9 (cambiado)'; end if;
        return new;
      end $f$;
      create trigger zzz_c10_prueba_altera before insert on public.asiento_lineas for each row execute function public.c10_prueba_altera();
      begin
        perform pg_temp.c10_aplicar(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
        e := 'entró';
      exception when others then
        e := sqlstate || case when sqlerrm like 'El asiento % que dejó el banco no es el reparto que se le pidió: la línea 2 (C10 PRUEBA Obra B): el CO quedó ''CO #9 (cambiado)'' y se pidió ''CO #9''. '
                                                || 'No se guardó nada%el pago sigue en la Bandeja%corrígelos en Horas y vuelve a mirar el reparto; si no, avisa con este mensaje.'
                              then ', dice la línea, el campo y qué hacer' else ' (' || sqlerrm || ')' end;
      end;
      perform pg_temp.c10_ser('editor');
      f := case when (select m.estado from movimientos_banco m where m.id = m2) = 'pendiente'
                     and (select h.aprobado_el is null from horas h where h.id = -1010000006)
                     and not exists (select 1 from jornal_repartos r where r.movimiento_id = m2)
                     and not exists (select 1 from asientos x where x.origen_tabla = 'movimientos_banco' and x.origen_id = m2::text)
                then 'y nada cambia' else 'y ALGO cambió' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    v_obt := format('%s | %s | aplicado: %s | el margen por CO: %s | si el asiento del banco no fuera el reparto: %s, %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (53, 'EL CO Y LA FASE VAN LIMPIOS COMO LOS DEJA c6 (sin espacios, tabuladores ni saltos de línea en las puntas): un CO con un salto de línea detrás es el mismo CO —un grupo, una línea— y uno que es solo un tabulador es la base; el pago se reparte (antes paraba con MX001 «Avisa»); dos CO que solo cambian en las mayúsculas se avisan (co_parecidos) y no se juntan; y si el asiento del banco no fuera el reparto, el MX001 dice qué línea, qué campo y qué hacer, y nada cambia',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 54. EL DEVENGO DE UN MES Y EL JORNAL DEL SIGUIENTE NO CHOCAN (el uso de
--     manual de fn_horas_devengar, c3): un mes devengado por lo trabajado y
--     todavía no pagado (Dr 5000 / Cr 2210 a fin de mes, con su reverso del
--     día 1) y su Zelle pagado al mes siguiente. El libro: el devengo en su
--     mes; al siguiente, su reverso y el pago real: nada dos veces. Antes el
--     control 50 lo ponía en rojo (miraba el mes de las HORAS contra el del
--     devengo, y daba por vivo un devengo ya deshecho) y no tenía vuelta, y
--     la propuesta avisaba «saldría dos veces». (El doble de verdad —el pago
--     que entra en el mismo mes— lo prueba la 39; y lo que pasa con él al
--     cerrar el mes, la 55.)
do $$
declare
  v_obt text; v_mov uuid; v_j jsonb; v_r jsonb; v_m0 date; v_fin date; v_mes text; v_mes1 text; v_dev jsonb; v_no text; a text; b text; c text;
  v_c0 text; v_c1 text;
  v_esp text;
begin
  if pg_temp.c10_omitir(54, 'el devengo de un mes y el jornal del siguiente no chocan', 'ni la propuesta avisa ni el control 50 se pone en rojo') then return; end if;
  if pg_temp.c10_omitir_rojo(54, 'el devengo de un mes y el jornal del siguiente no chocan', 'ni la propuesta avisa ni el control 50 se pone en rojo', 'jornal', array[50]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- (el último día del mes anterior al del pago: trabajado ese mes, pagado en el siguiente)
    v_m0 := date_trunc('month', pg_temp.c10_d())::date;
    v_fin := v_m0 - 1;
    v_mes := to_char(v_fin, 'YYYY-MM');
    v_mes1 := to_char(v_m0, 'YYYY-MM');
    v_esp := format('la propuesta del pago no avisa del devengo | aplicado: el asiento cae en %s, y el control 50 no cuenta ese jornal | el libro de la obra: '
                    '%s 5000 200.00 · %s 5000 -200.00 · %s 5200 200.00: nada dos veces', v_mes1, v_mes, v_mes1, v_mes1);
    perform pg_temp.c10_hora(1, 'p1', v_fin, 'c10-prueba-a', 8);
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_horas_aprobar(pg_temp.c10('p1')::uuid, v_fin, v_fin, '{"ids": [-1010000001]}'::jsonb);
      perform pg_temp.c10_ser('editor');
      v_dev := fn_horas_devengar(v_mes);
    exception when others then
      v_no := sqlstate || ': ' || sqlerrm;
      perform pg_temp.c10_ser('editor');
    end;
    if v_no is null then
      -- (el devengo de c3 se lleva TODAS las horas aprobadas del mes: en una
      --  base con jornales de verdad pagados dentro de ese mes, ESE devengo de
      --  prueba ya es un doble de verdad para ellos y el 50 sale en rojo por
      --  ellos, no por el de aquí. Por eso se mira que el jornal del mes
      --  siguiente NO MUEVA el control: verde, o igual que antes de aplicarlo
      --  —el detalle lleva las horas, los reportes y los jornales contados—.)
      v_c0 := pg_temp.c10_jc(50);
      v_mov := pg_temp.c10_cargo('c10-t54', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9054');
      perform pg_temp.c10_alta('p1');
      v_j := pg_temp.c10_propuesta(v_mov, v_fin, v_fin);
      a := case when pg_temp.c10_aviso(v_j, 'devengo_estandar') is null and (v_j->>'puede_aplicar')::boolean and (v_j->>'horas')::numeric = 8
                then 'la propuesta del pago no avisa del devengo' else 'la propuesta avisa: ' || coalesce(pg_temp.c10_aviso(v_j, 'devengo_estandar'), v_j->>'por_que') end;
      v_r := pg_temp.c10_aplicar(v_mov, v_fin, v_fin);
      v_c1 := pg_temp.c10_jc(50);
      b := format('el asiento cae en %s, y el control 50 %s', v_r->'asiento'->>'periodo',
                  case when v_c1 = 'verde' or v_c1 = v_c0 then 'no cuenta ese jornal' else v_c1 end);
      select string_agg(format('%s %s %s', q.periodo, q.cuenta, q.s), ' · ' order by q.periodo, q.cuenta) into c
        from (select x.periodo, l.cuenta, sum(l.monto) as s
                from asiento_lineas l join asientos x on x.id = l.asiento_id
               where l.proyecto_id = 'c10-prueba-a' and l.cuenta in ('5000', '5200')
               group by x.periodo, l.cuenta) q;
      v_obt := format('%s | aplicado: %s | el libro de la obra: %s: nada dos veces', a, b, c);
    else
      v_obt := format('omitida: c3 no dejó devengar %s (%s)', v_mes, left(v_no, 300));
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (54, 'EL DEVENGO DE UN MES Y EL JORNAL DEL SIGUIENTE NO CHOCAN: un mes devengado por lo trabajado y todavía no pagado (fn_horas_devengar, c3) y su Zelle pagado al mes siguiente: la propuesta no avisa de doble y el control 50 no cuenta ese jornal: sigue en verde (el mes lleva el devengo; el siguiente, su reverso y el pago real). Antes salía en rojo, sin vuelta',
    coalesce(v_esp, '-'), v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 55. EL DOBLE DE VERDAD, Y LO QUE PASA AL CERRAR EL MES. Un pago que entra
--     al libro en un mes y el devengo de ese mismo mes con esas horas: el 50
--     en rojo mientras el mes está abierto (se puede arreglar: retirar el
--     devengo antes de cerrar). Si el mes se cierra así, ya no tiene arreglo
--     en ese mes —el siguiente lo compensa con el reverso del devengo—: el
--     control lo deja dicho y NO se queda en rojo para siempre (con el cierre
--     de c9 mirándolo sería un «detiene» sin salida). Cierra, dentro de la
--     prueba, la apertura y el mes abierto más viejo que ya terminó, como la
--     27; si el libro real no deja, sale «omitida» con lo que dijo c2.
--     (14-nov, la Fase 11c) PRIMERO EL DEVENGO, DESPUÉS EL JORNAL, como la
--     39 y por lo mismo. Y con el c3 de la Fase 11c UN MES YA NO SE CIERRA
--     ASÍ (su guarda del cierre lo para, MX008: lo prueba la 131 de c3):
--     lo que aquí se mira es lo que dice c10 de un mes que SE CERRÓ con el
--     doble dentro (antes de esa fase), así que la prueba cierra con esa
--     guarda de c3 SIN EFECTO dentro de su transacción: cambia su función
--     por una que deja pasar («create or replace»: no le pide ningún candado
--     a periodos, nadie más la ve cambiada y se deshace con la prueba; no
--     apaga ningún trigger). Y, como cierra meses, toma periodos en
--     exclusiva con un tope de MEDIO SEGUNDO puesto antes de pedirla: si
--     alguien la tiene (la app posteando), sale «omitida» y lo dice.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_mes periodos; v_ap periodos; v_dev jsonb; v_no text; a text; b text;
  v_esp text := 'pagado y devengado en el mismo mes, abierto: el 50 en rojo (la misma hora en el devengo y en el jornal de ese mes) | '
                'cerrado ese mes: el 50 verde, y lo deja dicho (ya cerrado, sin arreglo: el mes siguiente lo compensa)';
begin
  if pg_temp.c10_omitir(55, 'el doble de verdad, y al cerrar el mes', v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(55, 'el doble de verdad, y al cerrar el mes', v_esp, 'jornal', array[50]) then return; end if;
  begin
    perform pg_temp.c10_ser('editor');
    -- (el tope de medio segundo, ANTES de pedir periodos: si la app lo tiene, «omitida» en vez de hacerla esperar)
    set local lock_timeout = '500ms';
    lock table periodos in exclusive mode;
    select * into v_mes from periodos p where p.tipo = 'mes' and p.estado = 'abierto' and p.hasta < fn_fecha_miami(now()) order by p.desde limit 1;
    if v_mes.periodo is null then
      v_no := 'no hay un mes terminado y todavía abierto donde pagar, devengar y cerrar';
    else
      perform pg_temp.c10_sembrar();
      -- (trabajado y PAGADO dentro de ese mes: el pago, su último día)
      perform pg_temp.c10_hora(1, 'p1', v_mes.hasta - 2, 'c10-prueba-a', 8);
      v_mov := pg_temp.c10_cargo('c10-t55', v_mes.hasta, 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9055');
      perform pg_temp.c10_alta('p1');
      -- (el devengo, con la hora ya aprobada, ANTES del jornal)
      begin
        perform pg_temp.c10_ser('dueno');
        perform fn_horas_aprobar(pg_temp.c10('p1')::uuid, v_mes.hasta - 2, v_mes.hasta - 2, '{"ids": [-1010000001]}'::jsonb);
        perform pg_temp.c10_ser('editor');
        v_dev := fn_horas_devengar(v_mes.periodo);
      exception when others then
        v_no := format('c3 no dejó devengar %s (%s: %s)', v_mes.periodo, sqlstate, left(sqlerrm, 300));
        perform pg_temp.c10_ser('editor');
      end;
      if v_no is null then
        v_r := pg_temp.c10_aplicar(v_mov, v_mes.hasta - 2, v_mes.hasta - 2);
      end if;
    end if;
    if v_no is null then
      a := pg_temp.c10_jc(50);
      a := case when a like 'rojo: %' || v_mes.periodo || ': el devengo ' || (v_dev->>'asiento') || ' cuenta % h (% reporte(s)) que ya tienen su pago real en ese mes, en % jornal(es)%'
                                || '→ esa mano de obra sale dos veces en ese mes%'
                then 'el 50 en rojo (la misma hora en el devengo y en el jornal de ese mes)' else 'el 50: ' || a end;
      begin
        select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
        if v_ap.estado = 'abierto' then
          if not exists (select 1 from asientos x where x.periodo = v_ap.periodo and x.tipo = 'apertura' and x.reversa_a is null
                            and not exists (select 1 from asientos r where r.reversa_a = x.id and r.camino = 'reverso')) then
            perform fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
              'descripcion', 'C10 PRUEBA: apertura de prueba (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1600', 'monto', '1000.00'),
                                          jsonb_build_object('cuenta', '3100', 'monto', '-1000.00'))));
          end if;
          perform fn_cerrar_periodo(v_ap.periodo);
        end if;
        -- (la guarda del cierre del c3 de la Fase 11c no deja cerrar un mes con el doble dentro: aquí se mira el que ya se cerró
        --  así. Se deja sin efecto cambiando su función por una que deja pasar, dentro de la prueba: sin «alter table»)
        if pg_temp.c10_c3_aparta() and to_regprocedure('public.fn_puente_periodos_devengo()') is not null then
          execute 'create or replace function public.fn_puente_periodos_devengo() returns trigger language plpgsql '
               || 'set search_path = public, pg_temp as $b$ begin return new; end $b$';
        end if;
        perform fn_cerrar_periodo(v_mes.periodo);
      exception when others then
        v_no := format('c2 no dejó cerrar %s (%s: %s)', v_mes.periodo, sqlstate, left(sqlerrm, 300));
      end;
    end if;
    if v_no is null then
      b := case when (select k.ok and k.detalle like 'Ninguna hora está a la vez en el devengo estándar de un mes abierto y en un jornal que entró al libro ese mes.%'
                                     || '(Ya cerrado, sin arreglo: ' || v_mes.periodo || ': el devengo ' || (v_dev->>'asiento') || ' cuenta %'
                                     || 'ese mes quedó con esa mano de obra dos veces y el siguiente con ella de menos, por el reverso del devengo.)'
                        from v_jornal_control k where k.orden = 50)
                then 'el 50 verde, y lo deja dicho (ya cerrado, sin arreglo: el mes siguiente lo compensa)' else 'el 50: ' || pg_temp.c10_jc(50) || ' / ' || (select k.detalle from v_jornal_control k where k.orden = 50) end;
      v_obt := format('pagado y devengado en el mismo mes, abierto: %s | cerrado ese mes: %s', a, b);
    else
      v_obt := 'omitida: ' || v_no;
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then
      v_obt := 'omitida: no se consiguió un candado en medio segundo (alguien está usando la app o pegando un archivo en este momento); '
               || 'nada quedó a medias: vuelve a pegar este archivo en un rato';
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (55, 'EL DOBLE DE VERDAD (el pago y el devengo estándar de las mismas horas en el mismo mes) pone el control 50 en rojo mientras ese mes está abierto y se puede arreglar; si el mes se cierra así, el control lo deja dicho y no se queda en rojo para siempre (el mes siguiente lo compensa con el reverso del devengo)',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 56. EL RECONOCIMIENTO POR PATRÓN, Y LA CUENTA DE LO SIN OBRA. Un patrón no
--     sabe qué clase de movimiento mira ni de quién es: la compra en un
--     comercio cuyo nombre lleva el de alguien casa igual que su Zelle, y el
--     patrón de una persona puesto en el perfil de otra reconocía sus pagos a
--     nombre de la otra, sin decir nada. No se frena (un banco puede
--     describir un pago de otra forma, y la app el nombre de pila): se DICE,
--     al dar de alta y en la propuesta. Y un patrón que casaría con un Zelle
--     a cualquiera no entra. La cuenta de lo sin obra, además, ya no es
--     «cualquier gasto».
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_k jsonb; v_sin text; a text; b text; c text; d text; e text; x1 text; x2 text; x3 text; x4 text;
  v_esp text;
begin
  if pg_temp.c10_omitir(56, 'el reconocimiento por patrón, y la cuenta de lo sin obra', 'los avisos del patrón y las cuentas que no sirven') then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    select c2.codigo into v_sin from cuentas c2
     where fn_jornal_cuenta_mal(c2.codigo, 'sin_obra') is null order by (c2.codigo = '7900') desc, c2.codigo limit 1;
    v_esp := format('«un Zelle a quien sea» no vale, y lo dice; con su nombre, sí | al dar de alta: avisa de que casa con pagos descritos de 2 '
                    'formas (el Zelle y la compra en el comercio), y lo pone en la nota | la compra en el comercio: reconocida, con su aviso '
                    '[no_parece_pago]; el Zelle, sin él | un patrón sin el nombre de pila del perfil: avisa y entra | lo sin obra: 6010 MX004 '
                    '(la alimenta otra parte del libro), 6950 MX004, 7920 MX004, %s entra', v_sin);
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    m1 := pg_temp.c10_cargo('c10-t56-1', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9561');
    m2 := pg_temp.c10_cargo('c10-t56-2', pg_temp.c10_d(), 88.40, 'POS PURCHASE C10 PRUEBA ZZANA SUPPLY 0042');
    perform pg_temp.c10_ser('dueno');
    a := format('%s; %s',
                case when fn_jornal_patron_mal('ZELLE PAYMENT TO [A-Z]') like '%casaría con cualquier pago (también con «ZELLE PAYMENT TO otra persona»)%'
                          and fn_jornal_patron_mal('ZELLE.*') is not null and fn_jornal_patron_mal('\mTO\M \w+') is not null
                     then '«un Zelle a quien sea» no vale, y lo dice' else coalesce(fn_jornal_patron_mal('ZELLE PAYMENT TO [A-Z]'), 'VALE') end,
                case when fn_jornal_patron_mal('\mPRUEBA ZZANA\M') is null then 'con su nombre, sí' else 'con su nombre NO' end);
    v_j := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p1'), 'patron', '\mPRUEBA ZZANA\M'));
    b := case when jsonb_array_length(v_j->'avisos') = 1
                   and v_j->'avisos'->>0 like 'El patrón casa con pagos que el banco describe de 2 formas distintas («POS PURCHASE PRUEBA ZZANA», «PRUEBA ZZANA»): mira que todos sean suyos%'
                   -- (en un LIKE la barra invertida es el escape: va doble)
                   and v_j->>'nota_alta' like 'Zzana C10 PRUEBA: 2 pago(s) pendientes reconocidos con «\\mPRUEBA ZZANA\\M». Ojo: El patrón casa con pagos%'
              then 'avisa de que casa con pagos descritos de 2 formas (el Zelle y la compra en el comercio), y lo pone en la nota'
              else coalesce((v_j->'avisos')::text, 'sin avisos') end;
    v_k := fn_jornal_propuesta(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    c := format('%s; el Zelle, %s',
                case when (v_k->>'reconocido')::boolean
                          and (select x->>'texto' from jsonb_array_elements(v_k->'avisos') x where x->>'codigo' = 'no_parece_pago')
                              like 'El banco no lo describe como un pago a una persona (un Zelle, una transferencia, un cheque): «POS PURCHASE C10 PRUEBA ZZANA SUPPLY 0042».%clasifícalo en la Bandeja como siempre.'
                     then 'reconocida, con su aviso [no_parece_pago]' else 'sin su aviso: ' || pg_temp.c10_avisos(v_k) end,
                case when pg_temp.c10_aviso(fn_jornal_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6)), 'no_parece_pago') is null then 'sin él' else 'CON él' end);
    -- (el patrón de «otra» persona en el perfil de Zzcaro: su nombre de pila no sale en él)
    v_j := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p3'), 'patron', '\mPRUEBA ZZOTRA\M'));
    d := case when v_j->'avisos'->>0 = 'El patrón «\mPRUEBA ZZOTRA\M» no lleva el nombre de Zzcaro C10 PRUEBA («ZZCARO»): mira que sea el de sus pagos y no el de otra persona.'
                   and (v_j->>'activa')::boolean and v_j->>'nota_alta' like '% Ojo: El patrón «\\mPRUEBA ZZOTRA\\M» no lleva el nombre de Zzcaro C10 PRUEBA%'
              then 'avisa y entra' else coalesce((v_j->'avisos')::text, 'sin avisos') end;
    begin perform fn_jornal_config('{"cuenta_sin_obra": "6010"}'); x1 := 'entra';
    exception when others then x1 := sqlstate || case when sqlerrm like '%la alimenta otra parte del libro%' then ' (la alimenta otra parte del libro)' else '' end; end;
    begin perform fn_jornal_config('{"cuenta_sin_obra": "6950"}'); x2 := 'entra'; exception when others then x2 := sqlstate; end;
    begin perform fn_jornal_config('{"cuenta_sin_obra": "7920"}'); x3 := 'entra'; exception when others then x3 := sqlstate; end;
    begin
      x4 := case when fn_jornal_config(jsonb_build_object('cuenta_sin_obra', v_sin))->>'cuenta_sin_obra' = v_sin then v_sin || ' entra' else 'no quedó' end;
    exception when others then x4 := sqlstate; end;
    perform pg_temp.c10_ser('editor');
    -- (si el plan de cuentas de esta base no trae la 6010, el porqué es otro —«no existe»— y sigue sin entrar)
    if not exists (select 1 from cuentas k where k.codigo = '6010') and x1 = 'MX004' then x1 := 'MX004 (la alimenta otra parte del libro)'; end if;
    e := format('6010 %s, 6950 %s, 7920 %s, %s', x1, x2, x3, x4);
    v_obt := format('%s | al dar de alta: %s | la compra en el comercio: %s | un patrón sin el nombre de pila del perfil: %s | lo sin obra: %s',
                    a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (56, 'EL RECONOCIMIENTO POR PATRÓN SE AVISA, NO SE ADIVINA: un patrón que casaría con un Zelle a cualquiera no entra; al dar de alta se dice si el patrón casa con pagos que el banco describe de varias formas (un comercio con un nombre parecido) o si no lleva el nombre de pila del perfil; y la propuesta avisa si el movimiento no parece un pago a una persona. La cuenta de lo sin obra no admite las que alimenta otra parte del libro ni las de etiqueta fiscal propia',
    coalesce(v_esp, '-'), v_obt, v_obt = v_esp);
end $$;

-- 57. LO MENOR, DICHO: el corte de mes y de año (las horas de un mes y el
--     asiento en otro: el libro va por la fecha del pago, como QuickBooks, y
--     se avisa con cuántas horas, cuánto y cuándo entra); la nota de aplicar
--     no cuenta las obras a las que no les llegó ni un centavo; el núcleo
--     reparte también solo por las horas APROBADAS (lo que pedirá f11); la
--     nota del estándar dice que va con la tarifa de hoy; el control dice
--     dónde salen los jornales en «Estados»; y ningún detalle de los dos
--     controles nombra una función ni una vista.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; v_r jsonb; v_k jsonb; v_m0 date; v_fin date; v_ano date; v_cod text; a text; b text; c text; d text; e text;
  v_esp text := 'las horas del mes anterior: avisa (8 h, 200.00, con el día en que entra el asiento) | las de otro año: avisa (4 h, 250.00, '
                'y el ejercicio en que queda) | un pago de 2 centavos entre tres obras: la nota cuenta 2 obras y dice que a 1 grupo no le '
                'llegó nada | el núcleo: 4 reportes con todas las horas y 3 con solo las aprobadas, y los dos suman 100.00 | la nota del '
                'estándar dice que va con la tarifa de hoy; el control dice dónde salen los jornales en Estados; y ningún detalle nombra '
                'una función ni una vista';
begin
  if pg_temp.c10_omitir(57, 'el corte de mes y de año, la nota de aplicar, el núcleo con las aprobadas y los textos', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    v_m0 := date_trunc('month', pg_temp.c10_d())::date;
    v_fin := v_m0 - 1;                                           -- el último día del mes anterior al del pago
    v_ano := date_trunc('year', pg_temp.c10_d())::date - 1;      -- el 31 de diciembre del año anterior
    perform pg_temp.c10_hora(1, 'p1', v_fin, 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', v_m0, 'c10-prueba-b', 2);
    perform pg_temp.c10_hora(3, 'p1', v_ano, 'c10-prueba-h', 4);
    m1 := pg_temp.c10_cargo('c10-t57-1', pg_temp.c10_d(), 250.00, 'Zelle payment to C10 PRUEBA ZZANA 9571');
    perform pg_temp.c10_alta('p1');
    -- (a) el mes: 8 h del mes anterior y 2 h del mes del pago
    v_j := pg_temp.c10_propuesta(m1, v_fin, v_m0);
    v_cod := case when extract(year from v_fin) <> extract(year from pg_temp.c10_d()) then 'otro_anio' else 'otro_mes' end;
    select case when (x->>'horas')::numeric = 8 and (x->>'monto')::numeric = 200.00 and (x->>'fecha_asiento')::date = pg_temp.c10_d()
                     and x->>'texto' like '8 h de este pago ($200.00) se trabajaron en % y el asiento entra el ' || fn_jornal_dia(pg_temp.c10_d(), true) || ': su costo queda en %(el libro va por la fecha del pago, como QuickBooks)%Es solo un aviso.'
                     and (v_j->>'puede_aplicar')::boolean and (v_j->'movimiento'->>'fecha_asiento')::date = pg_temp.c10_d()
                then 'avisa (8 h, 200.00, con el día en que entra el asiento)' else x::text end
      into a from jsonb_array_elements(v_j->'avisos') x where x->>'codigo' = v_cod;
    -- (b) el año: una hora del 31 de diciembre del año anterior. La propuesta no deja más de 62 días hacia atrás; el
    --     cálculo es el mismo y aquí se le pide directo, como el dueño, con ese solo día.
    perform pg_temp.c10_ser('dueno');
    v_k := fn_jornal_calcular(m1, v_ano, v_ano, '{}'::jsonb);
    perform pg_temp.c10_ser('editor');
    select case when (x->>'horas')::numeric = 4 and (x->>'monto')::numeric = 250.00
                     and x->>'texto' like '4 h de este pago ($250.00) se trabajaron en ' || to_char(v_ano, 'YYYY') || ' y el asiento entra el ' || fn_jornal_dia(pg_temp.c10_d(), true)
                                          || ': su costo queda en el ejercicio ' || to_char(pg_temp.c10_d(), 'YYYY') || ' %Si el CPA quiere ese costo en el año en que se trabajó%'
                then 'avisa (4 h, 250.00, y el ejercicio en que queda)' else x::text end
      into b from jsonb_array_elements(v_k->'avisos') x where x->>'codigo' = 'otro_anio';
    -- (c) un pago de 2 centavos entre tres obras: a una no le llega nada
    perform pg_temp.c10_hora(4, 'p2', pg_temp.c10_w1(0), 'c10-prueba-a', 1);
    perform pg_temp.c10_hora(5, 'p2', pg_temp.c10_w1(0), 'c10-prueba-b', 1);
    perform pg_temp.c10_hora(6, 'p2', pg_temp.c10_w1(0), 'c10-prueba-h', 1);
    m2 := pg_temp.c10_cargo('c10-t57-2', pg_temp.c10_d(), 0.02, 'Zelle payment to C10 PRUEBA ZZBETO 9572');
    perform pg_temp.c10_alta('p2');
    v_r := pg_temp.c10_aplicar(m2, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    c := case when v_r->>'nota' like 'Repartido: $0.02 de Zzbeto C10 PRUEBA (%, 3 h) entre 2 obra(s); asiento %. A 1 grupo(s) de horas no les llegó ni un centavo (el pago es muy chico): no llevan línea. Quedaron aprobados 3 reporte(s) de horas.'
                   and (select count(*) from asiento_lineas l where l.asiento_id = (v_r->'asiento'->>'id')::uuid) = 3
              then 'la nota cuenta 2 obras y dice que a 1 grupo no le llegó nada' else v_r->>'nota' end;
    -- (d) el núcleo, con todas las horas y con solo las aprobadas (las tres de arriba ya lo están; la cuarta, no)
    perform pg_temp.c10_hora(7, 'p2', pg_temp.c10_w1(1), 'c10-prueba-i', 2);
    perform pg_temp.c10_ser('dueno');
    select format('%s reportes con todas las horas y %s con solo las aprobadas, y los dos suman %s',
                  (select count(*) from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00)),
                  (select count(*) from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00, true)),
                  case when (select sum(r.monto) from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00) r) = 100.00
                            and (select sum(r.monto) from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00, true) r) = 100.00
                            and not exists (select 1 from fn_jornal_repartir(pg_temp.c10('p2')::uuid, pg_temp.c10_w1(0), pg_temp.c10_w1(6), 100.00, true) r
                                             where r.proyecto_id = 'c10-prueba-i')
                       then '100.00' else 'otra cosa' end)
      into d;
    -- (e) los textos
    v_k := fn_margen_obra('c10-prueba-i');
    select format('%s; %s; y %s',
                  case when (select x->>'nota' from jsonb_array_elements(v_k->'conceptos') x where x->>'concepto' = 'mano_obra_estandar')
                            like '%con la tarifa y el burden de hoy (si cambian, este número cambia). No está en el libro.'
                         or (select x->>'nota' from jsonb_array_elements(v_k->'conceptos') x where x->>'concepto' = 'mano_obra_estandar') like 'Falta %'
                       then 'la nota del estándar dice que va con la tarifa de hoy' else 'la nota del estándar NO lo dice' end,
                  case when to_regclass('public.v_costo_por_obra') is null
                         or (select not k.ok or k.detalle like '%en «Estados» salen dentro de «Subcontratos» y aquí como mano de obra real; el total de cada obra es el mismo.' from v_margen_control k where k.orden = 60)
                       then 'el control dice dónde salen los jornales en Estados' else 'el control NO dice dónde salen los jornales' end,
                  case when not exists (select 1 from (select k.detalle from v_jornal_control k union all select k.detalle from v_margen_control k) z
                                         where z.detalle ~ '\m(fn_[a-z_]+|v_(jornal|margen|costo|contador)_[a-z_]+)\M')
                       then 'ningún detalle nombra una función ni una vista'
                       else 'algún detalle nombra una función o una vista: ' || (select string_agg(left(z.detalle, 120), ' · ')
                                                                                     from (select k.detalle from v_jornal_control k union all select k.detalle from v_margen_control k) z
                                                                                    where z.detalle ~ '\m(fn_[a-z_]+|v_(jornal|margen|costo|contador)_[a-z_]+)\M') end)
      into e;
    perform pg_temp.c10_ser('editor');
    v_obt := format('las horas del mes anterior: %s | las de otro año: %s | un pago de 2 centavos entre tres obras: %s | el núcleo: %s | %s',
                    coalesce(a, 'sin aviso [' || pg_temp.c10_avisos_todos(v_j) || ']'), coalesce(b, 'sin aviso'), c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (57, 'LO MENOR, DICHO: las horas de otro mes —o de otro año— que el asiento (que entra el día del pago) se avisan con cuántas horas, cuánto y cuándo entra (otro_mes, otro_anio); la nota de aplicar no cuenta las obras a las que no les llegó ni un centavo; el núcleo reparte también por solo las horas aprobadas (lo que pedirá f11); la nota del estándar dice que va con la tarifa de hoy; el control dice dónde salen los jornales en «Estados»; y ningún detalle de los controles nombra una función ni una vista',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- ---------------------------------------------------------------------
-- EL CIERRE DE LA SUITE
-- ---------------------------------------------------------------------
-- 58. Nada queda: lo que c10 toca (y lo que sus pruebas sembraron) está
--     como antes de la primera prueba.
do $$
declare
  v_obt text;
begin
  begin
    perform pg_temp.c10_ser('editor');
    v_obt := case when pg_temp.c10_conteos() = pg_temp.c10('conteos') then 'igual que antes' else 'antes: ' || pg_temp.c10('conteos') || ' · ahora: ' || pg_temp.c10_conteos() end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (58, 'nada queda de las pruebas: la configuración, las personas, los repartos, los asientos, los movimientos y archivos del banco, las horas y sus aprobaciones, los perfiles y usuarios, las tarifas, las obras, los escenarios, los estimados, los períodos cerrados y las funciones, como antes',
    'igual que antes', v_obt, v_obt = 'igual que antes');
end $$;

-- 59. Con jornales aplicados, deshechos y vueltos a aplicar, NINGÚN control
--     de las otras capas pasa a rojo: la cadena y «permisos» de c2, los
--     puentes (c3), el banco (c6), los estados (c4), los cuadres de la IA
--     (c8, si está) y lo que detiene el cierre del mes (c9, si está). Se
--     compara con cómo estaban con el pago ya en la Bandeja (lo que ya
--     estaba en rojo se dice, y no cuenta). (Si el mes de esas horas ya
--     estaba devengado y sigue abierto, aprobarlas deja su devengo viejo y
--     c3 lo dice: ese rojo —el «devengo» de c3 y su fila del cierre— no es
--     de c10 y no se cuenta, y se dice: «EL DEVENGO DE UN MES YA
--     DEVENGADO», arriba.)
do $$
declare
  v_obt text; v_mov uuid; m2 uuid; v_r jsonb; s0 text[]; s1 text[]; s2 text[]; s3 text[]; s4 text[]; v_antes text := ''; v_dev text := '';
  v_esp text := 'al aplicar: ninguno | al deshacer: ninguno | al volver a aplicar con otras fechas: ninguno | con otro pago de las mismas '
                'horas: ninguno';
begin
  if pg_temp.c10_omitir(59, 'ningún control de las otras capas pasa a rojo', v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 4);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-c', 2);
    perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w2(0), 'c10-prueba-h', 5);
    v_mov := pg_temp.c10_cargo('c10-t59-1', pg_temp.c10_d(), 350.00, 'Zelle payment to C10 PRUEBA ZZANA 9591');
    m2 := pg_temp.c10_cargo('c10-t59-2', pg_temp.c10_d(), 125.00, 'Zelle payment to C10 PRUEBA ZZANA 9592');
    perform pg_temp.c10_alta('p1');
    s0 := pg_temp.c10_rojos();
    v_dev := pg_temp.c10_devengo_vivo();
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    s1 := pg_temp.c10_rojos();
    perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: no era esa semana');
    s2 := pg_temp.c10_rojos();
    perform pg_temp.c10_aplicar(v_mov, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    s3 := pg_temp.c10_rojos();
    perform pg_temp.c10_aplicar(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6), '{"incluir_cubiertas": true}');
    s4 := pg_temp.c10_rojos();
    if v_dev <> '' then   -- (un mes de esas horas ya estaba devengado: el «devengo» de c3 no es de esta prueba)
      s1 := pg_temp.c10_sin_devengo(s1); s2 := pg_temp.c10_sin_devengo(s2); s3 := pg_temp.c10_sin_devengo(s3); s4 := pg_temp.c10_sin_devengo(s4);
    end if;
    v_obt := format('al aplicar: %s | al deshacer: %s | al volver a aplicar con otras fechas: %s | con otro pago de las mismas horas: %s',
                    pg_temp.c10_nuevos(s0, s1), pg_temp.c10_nuevos(s0, s2), pg_temp.c10_nuevos(s0, s3), pg_temp.c10_nuevos(s0, s4));
    v_antes := array_to_string(s0, '; ');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (59, 'con jornales aplicados, deshechos, vueltos a aplicar y un segundo pago de las mismas horas, NINGÚN control de las otras capas pasa a rojo: la cadena y «permisos» (c2), los puentes (c3), el banco (c6), los estados (c4), los cuadres de la IA (c8) y lo que detiene el cierre del mes (c9)',
    v_esp, v_obt || case when v_antes <> '' then ' (ya en rojo antes, con el pago en la Bandeja: ' || v_antes || ')' else '' end
                 || case when v_dev <> '' then format(' (%s ya estaba devengado y sigue abierto: aprobar sus horas deja viejo ese devengo, y c3 lo dice —su control «devengo»—; no se cuenta aquí)', v_dev) else '' end,
    v_obt = v_esp);
end $$;

-- 60. El cierre de la suite: c2 (la cadena y «permisos»), c3, c6 y c4 como
--     estaban con c10 pegado (lo que ya estaba en rojo antes se dice y no
--     cuenta), c8 sin cuadres rojos, nada de c10 para anon o service_role ni
--     SECURITY DEFINER; y fn_jornal_pegado responde con sus diez filas (la
--     de la cuadrilla sola, desde la v5) y la
--     configuración sigue siendo UNA (pegar dos veces no la pisa: lo corre
--     el banco, con dos pegados seguidos antes de esta suite).
do $$
declare
  v_obt text; v_c2 text; v_c3 text; v_c6 text; v_c4 text; v_c8 text; v_api text; v_n int; v_cfg int;
  v_esp text := 'c2 verde | c3 verde | c6 verde | c4 verde | c8 cuadres rojos: ninguno | c10 para anon o service_role, o definer: ninguna | el '
                'pegado: 10 filas, y la configuración 1 fila (id 1)';
begin
  begin
    perform pg_temp.c10_ser('editor');
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c2 from fn_verificar_cadena()
     where not ok and not (control = 'permisos' and pg_temp.c10_permisos() = 'verde');
    select coalesce(string_agg(control, ', ' order by control), 'verde') into v_c3 from fn_puentes_verificar()
     where not ok and not (control = any (string_to_array(pg_temp.c10('rojos_c3'), ', ')));
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c6 from fn_banco_control('hoy')
     where not ok and not (vista = any (string_to_array(pg_temp.c10('rojos_c6'), ', ')));
    select coalesce(string_agg(vista, ', ' order by vista), 'verde') into v_c4 from fn_estados_control('hoy')
     where not ok and not (vista = any (string_to_array(pg_temp.c10('rojos_c4'), ', ')));
    if pg_temp.c10('hay_c8') = 'true' then
      execute $q$ select coalesce(string_agg(orden::text, ' ' order by orden), 'ninguno') from public.v_contador_control where nivel = 'cuadre' and not ok $q$ into v_c8;
    else
      v_c8 := 'ninguno';
    end if;
    select coalesce(string_agg(p.proname, ', '), 'ninguna') into v_api
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and pg_temp.c10_es_suya(p.proname)
       and (p.prosecdef or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('service_role', p.oid, 'execute'));
    select count(*) into v_n from fn_jornal_pegado();
    select count(*) into v_cfg from jornal_config;
    v_obt := format('c2 %s | c3 %s | c6 %s | c4 %s | c8 cuadres rojos: %s | c10 para anon o service_role, o definer: %s | el pegado: %s filas, y la '
                    'configuración %s fila (id %s)', v_c2, v_c3, v_c6, v_c4, v_c8, v_api, v_n, v_cfg, (select id from jornal_config limit 1));
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (60, 'el cierre de la suite: c2, c3, c6 y c4 en verde con c10 puesto (salvo lo que ya estaba en rojo antes), c8 sin cuadres rojos, nada de c10 para anon o service_role ni SECURITY DEFINER; fn_jornal_pegado responde y la configuración es una fila (pegar dos veces no la pisa: lo corre el banco)',
    v_esp,
    v_obt || case when pg_temp.c10('rojos_c3') <> '' then ' (ya en rojo antes, en c3: ' || pg_temp.c10('rojos_c3') || ')' else '' end
          || case when pg_temp.c10('rojos_c4') <> '' then ' (ya en rojo antes, en c4: ' || pg_temp.c10('rojos_c4') || ')' else '' end
          || case when pg_temp.c10('rojos_c6') <> '' then ' (ya en rojo antes, en c6: ' || pg_temp.c10('rojos_c6') || ')' else '' end
          || case when pg_temp.c10('ajenas_permisos') <> '' then ' (c2 permisos ya en rojo antes, por una función ajena a c10: ' || pg_temp.c10('ajenas_permisos') || ')' else '' end,
    v_obt = v_esp);
end $$;


-- 61. EL CIERRE MIRA LA MANO DE OBRA REPARTIDA (c9, con su bloque de c10:
--     las filas 170 y 171 de fn_cierre_revisar). Sin ese bloque un mes se
--     podía cerrar con un reparto suelto. La 170 (detiene) dice lo mismo que
--     los cuadres de v_jornal_control y v_margen_control; la 171, sus
--     avisos. Un reparto des-casado por fuera pone la 170 en rojo con el
--     detalle del control 20; deshecho, vuelve a como estaba. Si el c9 de
--     esta base es el de antes (sin el bloque), se omite y dice qué pegar.
do $$
declare
  v_obt text; v_mov uuid; v_r jsonb; v_per text; a text; b text; c text; v_rojos int; v_ok0 boolean;
  f record;
  v_nom text := 'el cierre (c9) mira la mano de obra repartida: la fila 170 de su revisión (detiene) dice lo que los cuadres de c10 y '
                'la 171 sus avisos; un reparto des-casado por fuera la pone en rojo, y deshecho vuelve a como estaba';
  v_esp text := 'antes: la 170 detiene y dice lo que los cuadres de c10; la 171 es un aviso | des-casado por fuera: la 170 en rojo, '
                'detiene, con el reparto suelto | deshecho: la 170 como antes';
begin
  if to_regprocedure('public.fn_cierre_revisar(text)') is null then
    insert into _pruebas values (61, v_nom, v_esp, 'omitida: c9 (el cierre) no está en esta base', null);
    return;
  end if;
  if pg_temp.c10_omitir(61, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(61, v_nom, v_esp, 'jornal', array[20]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    select p.periodo into v_per from periodos p where p.tipo = 'mes' and pg_temp.c10_d() between p.desde and p.hasta;
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    v_mov := pg_temp.c10_cargo('c10-t61', pg_temp.c10_d(), 200.00, 'Zelle payment to C10 PRUEBA ZZANA 9061');
    perform pg_temp.c10_alta('p1');
    v_r := pg_temp.c10_aplicar(v_mov, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    select (select count(*) from v_jornal_control x where x.nivel = 'cuadre' and x.ok is not true)
         + (select count(*) from v_margen_control y where y.nivel = 'cuadre' and y.ok is not true)
      into v_rojos;
    perform pg_temp.c10_ser('dueno');
    select x.nivel, x.ok into f from fn_cierre_revisar(v_per) x where x.orden = 170;
    if not found then
      v_obt := 'omitida: el cierre de esta base todavía no trae las filas de la mano de obra (170 y 171): vuelve a pegar '
               'docs/conta/c9-cierre.sql y corre esto otra vez';
      raise exception using errcode = 'MXT00';
    end if;
    v_ok0 := f.ok;
    a := format('la 170 %s y %s; la 171 %s', f.nivel,
                case when f.ok = (v_rojos = 0) then 'dice lo que los cuadres de c10'
                     else format('dice %s con %s cuadre(s) de c10 en rojo', f.ok, v_rojos) end,
                coalesce((select case when x.nivel = 'aviso' then 'es un aviso' else 'es ' || x.nivel end
                            from fn_cierre_revisar(v_per) x where x.orden = 171), 'no está'));
    perform fn_banco_descasar(v_mov, 'c10-pruebas: lo suelto en la Bandeja (se deshace)');
    select x.nivel, x.ok, x.detalle into f from fn_cierre_revisar(v_per) x where x.orden = 170;
    b := format('la 170 %s, %s, %s', case when f.ok then 'en VERDE' else 'en rojo' end, f.nivel,
                case when f.detalle like '%se reversó por fuera%' then 'con el reparto suelto'
                     else 'sin decir cuál: ' || left(coalesce(f.detalle, ''), 200) end);
    perform pg_temp.c10_ser('editor');
    perform pg_temp.c10_deshacer((v_r->>'reparto_id')::uuid, 'c10-pruebas: se había des-casado en la Bandeja');
    perform pg_temp.c10_ser('dueno');
    select x.ok into f from fn_cierre_revisar(v_per) x where x.orden = 170;
    perform pg_temp.c10_ser('editor');
    c := case when f.ok is not distinct from v_ok0 then 'la 170 como antes' else 'la 170 NO volvió: ' || coalesce(f.ok::text, 'nulo') end;
    v_obt := format('antes: %s | des-casado por fuera: %s | deshecho: %s', a, b, c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (61, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- =====================================================================
-- LA FASE 11b (v3 de la capa, 13-nov-2026): LAS HORAS QUE PAGÓ UNA NÓMINA
-- =====================================================================
-- La nómina (c15) se pega DESPUÉS de c10 y es opcional. Lo único que c10 lee
-- de ella es su marca sin dinero: qué reporte de horas pagó qué corrida
-- posteada y viva, y su día de pago (ni un importe, ni un nombre). Las
-- pruebas 62 y 63 ponen esa marca DE PRUEBA dentro de su subtransacción: una
-- función con ese nombre que devuelve los reportes que la prueba diga. Así
-- valen con c15 pegada y sin ella; si c15 está, su función de verdad queda
-- como estaba al deshacerse la prueba (como el reloj fingido de c2-pruebas),
-- y nadie más la ve cambiada. El journal de la nómina de prueba entra al
-- libro por la puerta de los puentes, con el origen de una nómina, como lo
-- deja c15. La 64 mira, además, las nóminas DE VERDAD de la base (si las
-- hay) con la marca de verdad, con el código del teléfono y sin él.
-- NO FRENAN A LA APP: poner y quitar la marca de prueba pide un candado
-- sobre esa función; cada una de estas pruebas pone, DENTRO de su bloque,
-- un tope de MEDIO SEGUNDO a cualquier espera (lock_timeout; se deshace con
-- ella). Si alguien lo tiene ocupado, la prueba no espera más: sale
-- «omitida» y lo dice (no es un fallo: se vuelve a pegar en un rato).
create or replace function pg_temp.c10_sin_candado() returns text language sql immutable as $$
  select 'omitida: no se consiguió un candado en medio segundo (alguien está usando la app o pegando un archivo en este momento); '
         || 'nada quedó a medias: vuelve a pegar este archivo en un rato'::text
$$;

-- La marca de prueba. p_modo: 'ok' (devuelve esos reportes, con ese día de
-- pago), 'falla' (existe y no contesta) o 'quitar' (no está: como una nómina
-- de antes del 13-nov, que no la trae).
-- (14-nov-2026, la Fase 11c) LA MARCA DE PRUEBA SE PONE ENCIMA, SIN BORRAR LA
-- DE VERDAD («create or replace»: la misma forma que la de c15, sus tres
-- columnas). Antes se borraba y se creaba la de prueba; si algo de la base
-- dependía de ella (una vista, por ejemplo), la base no dejaba borrarla
-- (2BP01) y la 62, la 63 y la 64 salían en rojo sin que nada estuviera roto.
-- Puesta encima, lo que dependa de ella sigue en pie y la prueba corre. Solo
-- hay que quitarla de verdad en 'quitar' (la 64) o si la de la base devuelve
-- otra cosa (una nómina de otra versión: «create or replace» no deja cambiar
-- lo que devuelve, 42P13); si entonces algo depende de ella, MXT22 y la
-- prueba sale «omitida» con ese porqué. Todo se deshace con la prueba.
create or replace function pg_temp.c10_marca(p_ids bigint[], p_dia date default null, p_modo text default 'ok') returns void
language plpgsql as $$
declare
  v_def text;
  v_det text;
begin
  perform pg_temp.c10_ser('editor');
  if p_modo = 'quitar' then
    if to_regprocedure('public.fn_nomina_horas_con_pago()') is not null then
      begin
        drop function public.fn_nomina_horas_con_pago();
      exception when dependent_objects_still_exist then
        get stacked diagnostics v_det = pg_exception_detail;
        raise exception using errcode = 'MXT22',
          message = format('algo de esta base depende de la marca de la nómina (fn_nomina_horas_con_pago: %s) y no se deja quitar un '
                           'instante para la prueba; nada se tocó', left(coalesce(nullif(v_det, ''), 'sin detalle'), 200));
      end;
    end if;
    return;
  end if;
  v_def := case when p_modo = 'falla'
                then $f$
                  create or replace function public.fn_nomina_horas_con_pago()
                  returns table (horas_id bigint, corrida_id uuid, dia_pago date)
                  language plpgsql stable
                  set search_path = public, pg_temp
                  as $b$ begin raise exception 'c10-pruebas: la marca de prueba no contesta'; end $b$
                $f$
                else format($f$
                  create or replace function public.fn_nomina_horas_con_pago()
                  returns table (horas_id bigint, corrida_id uuid, dia_pago date)
                  language sql stable
                  set search_path = public, pg_temp
                  as $b$ select x, %L::uuid, %L::date from unnest(%L::bigint[]) x $b$
                $f$, pg_temp.c10('corrida'), p_dia, p_ids) end;
  begin
    execute v_def;
  exception when invalid_function_definition then
    begin
      drop function public.fn_nomina_horas_con_pago();
    exception when dependent_objects_still_exist then
      get stacked diagnostics v_det = pg_exception_detail;
      raise exception using errcode = 'MXT22',
        message = format('la marca de la nómina de esta base (fn_nomina_horas_con_pago) devuelve otra cosa que la que c10 conoce, y '
                         'algo depende de ella (%s): no se deja cambiar un instante para la prueba; nada se tocó',
                         left(coalesce(nullif(v_det, ''), 'sin detalle'), 200));
    end;
    execute v_def;
  end;
  revoke execute on function public.fn_nomina_horas_con_pago() from public, anon, service_role;
  grant  execute on function public.fn_nomina_horas_con_pago() to authenticated;
end $$;

-- El journal de una nómina de prueba en el libro, por la puerta de los
-- puentes y con el origen de una nómina (como lo deja c15): el sueldo por
-- obra y CO contra lo que queda por pagar y, aparte, el burden real a cada
-- obra contra su bolsa. Devuelve el número del journal.
create or replace function pg_temp.c10_nomina(p_fecha date, p_journal jsonb, p_burden jsonb default null) returns text
language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.c10_ser('editor');
  r := fn_postear_interno(jsonb_build_object(
         'camino', 'puente', 'fecha', p_fecha::text, 'descripcion', 'C10 PRUEBA: el journal de una nómina de prueba (se deshace)',
         'lineas', p_journal, 'origen_tabla', 'nomina_corridas', 'origen_id', pg_temp.c10('corrida'),
         'procedencia', jsonb_build_object('funcion', 'c10-pruebas')));
  if p_burden is not null then
    perform fn_postear_interno(jsonb_build_object(
         'camino', 'puente', 'fecha', p_fecha::text, 'descripcion', 'C10 PRUEBA: el burden real de esa nómina de prueba (se deshace)',
         'lineas', p_burden, 'origen_tabla', 'nomina_burden', 'origen_id', pg_temp.c10('corrida'),
         'procedencia', jsonb_build_object('funcion', 'c10-pruebas')));
  end if;
  return r->>'numero';
end $$;

-- El dueño por la API SIN el código del teléfono (aal1): «Costo por obra» se
-- lee así, y tiene que decir lo mismo.
create or replace function pg_temp.c10_ser_sin_codigo() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.c10('dueno'), 'role', 'authenticated', 'aal', 'aal1')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.c10('dueno'), true);
  execute 'set local role authenticated';
end $$;

-- Una obra del margen en una línea (para comparar con el código y sin él)
create or replace function pg_temp.c10_obra_txt(p_obra text) returns text language sql as $$
  select format('%s h, %s con pago real, %s a estándar, nómina %s, estándar %s, costo con estándar %s', trim_scale(o.horas_reales),
                trim_scale(o.horas_con_pago_real), trim_scale(o.horas_estandar), o.mano_obra_nomina,
                coalesce(o.mano_obra_estandar::text, 'vacío'), coalesce(o.costo_con_estandar::text, 'vacío'))
    from v_margen_obra o where o.proyecto_id = p_obra
$$;

-- 62. LAS HORAS QUE PAGÓ UNA NÓMINA TIENEN PAGO REAL. Dos obras con la
--     mano de obra de una nómina en el libro (5000 y 5010 con su obra): la
--     A con 36 h que esa nómina pagó (16 de Zzana y 20 de Zzbeto) y 6 h más
--     de Zzana sin pago; la B con 18 h, todas pagadas por la nómina. Antes
--     (la v2) las 54 h salían «a estándar» y, con el burden estándar fijado,
--     su mano de obra contaba dos veces en el costo con estándar. Con la
--     marca de la nómina: con pago real, sin importe por reporte; solo las 6
--     h sin pago van a estándar; con el burden sin fijar, en 0 y en 12.5;
--     con el código del teléfono y sin él. El detalle de la obra dice
--     cuántas horas son de nómina y no inventa lo que le tocó a cada quien.
--     Y a quien cobra por nómina ya no se le pide darse de alta en el jornal.
do $$
declare
  v_obt text; o record; p record; v_j jsonb; v_ids bigint[];
  a text; b text; c text; d text; e text; f text; g text; h text; i text; k text; x1 text; x2 text;
  v_esp text := 'sin fijar el burden: A 42 h, 36 con pago real y 6 a estándar, nómina 1000.00, estándar sin cifra (falta el burden); B 18 h, 18 '
                'y 0, nómina 500.00, estándar 0.00, costo con estándar 500.00 | burden 0: A estándar 150.00, costo con estándar 1150.00; B '
                '0.00 y 500.00 | burden 12.5: A 168.75 y 1168.75; B 0.00 y 500.00 | la obra lo dice: sí | sin el código del teléfono: lo '
                'mismo | reporte por reporte: los 6 de la nómina con pago real y sin importe; el otro, a estándar | el detalle de la A: '
                'la mano de obra real 1000.00 en 36 h (36 de nómina); quién trabajó: Zzana C10 PRUEBA 22 h, 16 de nómina, pagado vacío, 6 a '
                'estándar; Zzbeto C10 PRUEBA 20 h, 20 de nómina, pagado vacío, 0 a estándar; con su nota: sí; por fase: rough 10 h, 10 de '
                'nómina, vacía; Sin fase 32 h, 26 de nómina, vacía; nóminas: 1, con 4 reportes y 36 h | el control 70: verde, 54 h en 6 '
                'reporte(s) | las personas: Zzana C10 PRUEBA 6 h sin pago y 26 de nómina en 90 días; Zzbeto C10 PRUEBA 0 h sin pago y 28 de '
                'nómina en 90 días; al pegar ya no se pide darlas de alta, y la base tampoco las da de alta sola (cobran por nómina) | sin la '
                'marca (como en la v2): A 42 h a estándar, costo con estándar 2158.75; y al pegar la base dice que las reconocerá sola, por '
                'su nombre, a las dos';
begin
  if pg_temp.c10_omitir(62, 'las horas que pagó una nómina tienen pago real', v_esp) then return; end if;
  begin
    set local lock_timeout = '500ms';
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(3, 'p2', pg_temp.c10_w1(0), 'c10-prueba-a', 10, null, 'rough');
    perform pg_temp.c10_hora(4, 'p2', pg_temp.c10_w1(1), 'c10-prueba-a', 10);
    perform pg_temp.c10_hora(5, 'p1', pg_temp.c10_w1(2), 'c10-prueba-b', 10, 'CO #1');
    perform pg_temp.c10_hora(6, 'p2', pg_temp.c10_w1(2), 'c10-prueba-b', 8);
    perform pg_temp.c10_hora(7, 'p1', pg_temp.c10_w2(0), 'c10-prueba-a', 6);
    v_ids := array[-1010000001, -1010000002, -1010000003, -1010000004, -1010000005, -1010000006];
    -- la nómina en el libro: el sueldo por obra y CO, y el burden real a cada obra (A: 880 + 120; B: 250 + 192 + 58)
    perform pg_temp.c10_nomina(pg_temp.c10_d(),
      jsonb_build_array(jsonb_build_object('cuenta', '5000', 'monto', '880.00', 'proyecto_id', 'c10-prueba-a'),
                        jsonb_build_object('cuenta', '5000', 'monto', '250.00', 'proyecto_id', 'c10-prueba-b', 'co', 'CO #1'),
                        jsonb_build_object('cuenta', '5000', 'monto', '192.00', 'proyecto_id', 'c10-prueba-b'),
                        jsonb_build_object('cuenta', '2210', 'monto', '-1322.00')),
      jsonb_build_array(jsonb_build_object('cuenta', '5010', 'monto', '120.00', 'proyecto_id', 'c10-prueba-a'),
                        jsonb_build_object('cuenta', '5010', 'monto', '58.00', 'proyecto_id', 'c10-prueba-b'),
                        jsonb_build_object('cuenta', '5015', 'monto', '-178.00')));
    perform pg_temp.c10_marca(v_ids, pg_temp.c10_d());
    -- (a) sin fijar el burden
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"burden_estandar_pct": null}');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    select * into p from v_margen_obra where proyecto_id = 'c10-prueba-b';
    a := format('A %s h, %s con pago real y %s a estándar, nómina %s, estándar %s; B %s h, %s y %s, nómina %s, estándar %s, costo con estándar %s',
                trim_scale(o.horas_reales), trim_scale(o.horas_con_pago_real), trim_scale(o.horas_estandar), o.mano_obra_nomina,
                case when o.mano_obra_estandar is null and o.costo_con_estandar is null and o.mano_obra_estandar_falta like 'Falta fijar el burden estándar%'
                     then 'sin cifra (falta el burden)' else 'con cifra: ' || coalesce(o.mano_obra_estandar::text, 'nula') end,
                trim_scale(p.horas_reales), trim_scale(p.horas_con_pago_real), trim_scale(p.horas_estandar), p.mano_obra_nomina,
                coalesce(p.mano_obra_estandar::text, 'vacío'), coalesce(p.costo_con_estandar::text, 'vacío'));
    -- (b) burden 0
    perform fn_jornal_config('{"burden_estandar_pct": 0}');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    select * into p from v_margen_obra where proyecto_id = 'c10-prueba-b';
    b := format('A estándar %s, costo con estándar %s; B %s y %s', o.mano_obra_estandar, o.costo_con_estandar, p.mano_obra_estandar, p.costo_con_estandar);
    -- (c) burden 12.5
    perform fn_jornal_config('{"burden_estandar_pct": 12.5}');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    select * into p from v_margen_obra where proyecto_id = 'c10-prueba-b';
    c := format('A %s y %s; B %s y %s', o.mano_obra_estandar, o.costo_con_estandar, p.mano_obra_estandar, p.costo_con_estandar);
    -- (d) lo que dice la obra
    d := case when exists (select 1 from unnest(o.avisos) x
                            where x = '6 h van a estándar (sin pago real: ni un pago repartido por horas ni una nómina): $168.75, estándar, no real.')
                   and not exists (select 1 from unnest(p.avisos) x where x like '%van a estándar%')
              then 'sí' else 'no: ' || array_to_string(o.avisos, ' · ') end;
    -- (e) sin el código del teléfono (aal1), lo mismo
    x1 := pg_temp.c10_obra_txt('c10-prueba-a') || ' / ' || pg_temp.c10_obra_txt('c10-prueba-b');
    perform pg_temp.c10_ser_sin_codigo();
    x2 := pg_temp.c10_obra_txt('c10-prueba-a') || ' / ' || pg_temp.c10_obra_txt('c10-prueba-b');
    e := case when x1 = x2 and x1 like '42 h, 36 con pago real, 6 a estándar, nómina 1000.00, estándar 168.75, costo con estándar 1168.75 / 18 h, 18 con pago real,%'
              then 'lo mismo' else 'con el código: ' || x1 || ' · sin él: ' || x2 end;
    -- (f) reporte por reporte
    select format('los %s de la nómina con pago real y sin importe; el otro, %s',
                  count(*) filter (where q.horas_id = any (v_ids) and q.clase = 'pago_real' and q.monto_real = 0 and q.repartos = 0),
                  coalesce(max(case when q.horas_id = -1010000007 then case q.clase when 'estandar' then 'a estándar' else q.clase end end), 'no sale'))
      into f from fn_margen_horas(null) q where q.horas_id = any (v_ids || array[-1010000007::bigint]);
    -- (g) el detalle de la obra A
    v_j := fn_margen_obra('c10-prueba-a');
    select format('la mano de obra real %s en %s h (%s de nómina)', x->>'real', trim_scale((x->>'horas')::numeric), trim_scale((x->>'horas_nomina')::numeric))
      into g from jsonb_array_elements(v_j->'conceptos') x where x->>'concepto' = 'mano_obra_real';
    select g || '; quién trabajó: '
             || string_agg(format('%s %s h, %s de nómina, pagado %s, %s a estándar', x->>'persona', trim_scale((x->>'horas')::numeric),
                                  trim_scale((x->>'horas_nomina')::numeric), coalesce(x->>'pagado', 'vacío'), trim_scale((x->>'horas_estandar')::numeric)),
                           '; ' order by x->>'persona')
             || '; con su nota: ' || case when bool_and(x->>'nota' like 'Parte de estas horas las pagó una nómina:%con el código del teléfono.') then 'sí' else 'no' end
      into g from jsonb_array_elements(v_j->'cobertura') x;
    select g || '; por fase: '
             || string_agg(format('%s %s h, %s de nómina, %s', x->>'etiqueta', trim_scale((x->>'horas')::numeric), trim_scale((x->>'horas_nomina')::numeric),
                                  coalesce(x->>'mano_obra_real', 'vacía')), '; ' order by t.o)
      into g from jsonb_array_elements(v_j->'por_fase') with ordinality as t(x, o);
    g := g || format('; nóminas: %s, con %s reportes y %s h', jsonb_array_length(v_j->'nominas'), v_j->'nominas'->0->>'reportes',
                     trim_scale((v_j->'nominas'->0->>'horas')::numeric));
    perform pg_temp.c10_ser('editor');
    -- (h) el cuadre 70
    select case when k7.ok and k7.detalle = '54 h con obra, en 6 reporte(s), las pagó una nómina posteada: cuentan como pago real y no van, además, a estándar.'
                then 'verde, 54 h en 6 reporte(s)' else case when k7.ok then 'verde: ' else 'rojo: ' end || k7.detalle end
      into h from v_margen_control k7 where k7.orden = 70;
    -- (i) las personas del jornal (ninguna de las dos está dada de alta): sus horas sin pago y las que les pagó la nómina;
    --     y el «qué falta» del pegado ya no pide darlas de alta (cobran por nómina, no por Zelle)
    select string_agg(format('%s %s h sin pago y %s de nómina en 90 días', v.nombre, trim_scale(v.horas_sin_pago), trim_scale(v.horas_nomina_90_dias)),
                      '; ' order by v.nombre)
      into i from v_jornal_personas v where v.usuario_id in (pg_temp.c10('p1')::uuid, pg_temp.c10('p2')::uuid);
    select i || '; al pegar ' || case when q.detalle !~ 'Zz(ana|beto) C10 PRUEBA' then 'ya no se pide darlas de alta' else 'SE PIDE darlas de alta: ' || left(q.detalle, 300) end
      into i from fn_jornal_pegado() q where q.que = 'qué falta';
    -- (v5) y la base tampoco las da de alta sola: no adivina, y lo dice (cobran por nómina)
    select i || case when (select count(*) from fn_jornal_cuadrilla() c2
                            where c2.usuario_id in (pg_temp.c10('p1')::uuid, pg_temp.c10('p2')::uuid) and not c2.sola
                              and c2.por_que like 'ya cobra por nómina%') = 2
                          and q.detalle ~ 'NO puede reconocer solas[^·]*Zzana C10 PRUEBA \(ya cobra por nómina'
                     then ', y la base tampoco las da de alta sola (cobran por nómina)' else ', y la cuadrilla sola dice: ' || left(q.detalle, 300) end
      into i from fn_jornal_pegado() q where q.que = 'la cuadrilla, sola';
    -- (k) sin la marca: lo de antes (la mano de obra, dos veces; y las dos, por dar de alta)
    perform pg_temp.c10_marca('{}');
    perform pg_temp.c10_ser('dueno');
    select format('A %s h a estándar, costo con estándar %s', trim_scale(q.horas_estandar), q.costo_con_estandar)
      into k from v_margen_obra q where q.proyecto_id = 'c10-prueba-a';
    perform pg_temp.c10_ser('editor');
    -- (v5: con lo automático encendido ya no se pide darlas de alta: la base dice que las reconocerá sola, por su nombre.
    --  Lo automático se enciende aquí, dentro de la prueba, por si en esta base está apagado)
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"solo": true}'::jsonb);
    perform pg_temp.c10_ser('editor');
    select k || '; y al pegar ' || case when q.detalle ~ 'reconocerá solas, por su nombre: [^·]*Zzana C10 PRUEBA' and q.detalle ~ 'reconocerá solas, por su nombre: [^·]*Zzbeto C10 PRUEBA'
                                             and (select f.detalle !~ 'Zz(ana|beto) C10 PRUEBA' from fn_jornal_pegado() f where f.que = 'qué falta')
                                        then 'la base dice que las reconocerá sola, por su nombre, a las dos' else 'NO lo dice: ' || left(q.detalle, 300) end
      into k from fn_jornal_pegado() q where q.que = 'la cuadrilla, sola';
    v_obt := format('sin fijar el burden: %s | burden 0: %s | burden 12.5: %s | la obra lo dice: %s | sin el código del teléfono: %s | reporte por '
                    'reporte: %s | el detalle de la A: %s | el control 70: %s | las personas: %s | sin la marca (como en la v2): %s',
                    a, b, c, d, e, f, g, h, i, k);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT22' then v_obt := 'omitida: ' || sqlerrm;
    when lock_not_available then v_obt := pg_temp.c10_sin_candado();
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (62, 'LAS HORAS QUE PAGÓ UNA NÓMINA TIENEN PAGO REAL (la Fase 11b): con la mano de obra de una nómina en el libro, sus horas ya no van además a estándar —con el burden estándar sin fijar, en 0 y en 12.5 la mano de obra cuenta UNA vez en el costo con estándar—, con el código del teléfono y sin él; solo las horas sin ningún pago van a estándar, y la obra lo dice; el detalle dice cuántas horas son de nómina sin inventar lo que le tocó a cada quien; el cuadre 70 lo cuenta; a quien cobra por nómina no se le pide darse de alta en el jornal; y sin la marca de la nómina todo sale como antes',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 63. LO QUE DICE «SIN PAGO» CON UNA NÓMINA, EN EL JORNAL. (a) El Zelle a
--     alguien que ya cobra por nómina se reconoce igual por su patrón:
--     repartido por sus horas, las contaría otra vez; la propuesta lo AVISA
--     (pagadas_por_nomina) y deja (qué horas entran no cambia). (b) Las «sin
--     pago» de esa semana, las de la persona y los pagos sin repartir de la
--     obra ya no cuentan esas horas. (c) Una hora que llega tarde a una
--     semana ya repartida deja de ser tardía cuando la paga una nómina. (d)
--     El pago de esa persona clasificado a mano en la Bandeja ya no deja
--     «horas suyas sin pago» si las pagó la nómina.
do $$
declare
  v_obt text; m1 uuid; m2 uuid; v_j jsonb; o record; a text; b text; c text; d text; e text; f text; g text; x text; y text;
  v_dia text;
  v_esp text := 'antes de la nómina: a 8→200.00, b 8→200.00 [-] | con esas horas pagadas por una nómina: a 8→200.00, b 8→200.00 '
                '[pagadas_por_nomina], lo avisa y deja | la semana anterior: 16 h, 0 sin pago | la obra A: 0 pago(s) sin repartir, sin ese '
                'aviso | las personas: Zzana C10 PRUEBA 5 h sin pago | una hora que llega tarde a una semana repartida: el 35 la nombra y '
                'la obra la lleva a estándar; la paga una nómina: el 35 ya no, y en su obra sale con pago real | el pago de Zzana '
                'clasificado a mano en la Bandeja: el 70 no lo nombra; sin la marca, sí (16 h suyas sin pago)';
begin
  if pg_temp.c10_omitir(63, 'lo que dice «sin pago» con una nómina, en el jornal', v_esp) then return; end if;
  begin
    set local lock_timeout = '500ms';
    perform pg_temp.c10_sembrar();
    v_dia := fn_jornal_dia(pg_temp.c10_d(), true);
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 8);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w2(0), 'c10-prueba-h', 5);
    perform pg_temp.c10_hora(4, 'p2', pg_temp.c10_w2(0), 'c10-prueba-h', 4);
    m1 := pg_temp.c10_cargo('c10-t63-1', pg_temp.c10_d(), 400.00, 'Zelle payment to C10 PRUEBA ZZANA 9631');
    m2 := pg_temp.c10_cargo('c10-t63-2', pg_temp.c10_d(), 96.00, 'Zelle payment to C10 PRUEBA ZZBETO 9632');
    perform pg_temp.c10_alta('p1');
    perform pg_temp.c10_alta('p2');
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"burden_estandar_pct": 0}');
    perform pg_temp.c10_ser('editor');
    -- (a) la propuesta del pago de Zzana por esa semana, antes y después de que una nómina pague esas horas
    perform pg_temp.c10_marca('{}');
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('%s [%s]', pg_temp.c10_lineas(v_j), pg_temp.c10_avisos(v_j));
    perform pg_temp.c10_marca(array[-1010000001, -1010000002], pg_temp.c10_d());
    v_j := pg_temp.c10_propuesta(m1, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    b := format('%s [%s], %s', pg_temp.c10_lineas(v_j), pg_temp.c10_avisos(v_j),
                case when pg_temp.c10_aviso(v_j, 'pagadas_por_nomina') like '16 h de este reparto ya las pagó una nómina (día de pago ' || v_dia
                                 || '): su costo ya está en su obra por la nómina, y con este pago entraría otra vez.%Es solo un aviso.'
                          and (v_j->>'puede_aplicar')::boolean
                     then 'lo avisa y deja' else coalesce(pg_temp.c10_aviso(v_j, 'pagadas_por_nomina'), 'no lo avisa') end);
    -- (b) las «sin pago» de esa semana, los pagos sin repartir de la obra y las horas sin pago de la persona
    select format('%s h, %s sin pago', trim_scale((q->>'horas')::numeric), trim_scale((q->>'horas_sin_pago')::numeric))
      into c from jsonb_array_elements(v_j->'periodo'->'opciones') q where q->>'regla' = 'semana_anterior';
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    d := format('%s pago(s) sin repartir, %s', o.pagos_sin_repartir,
                case when exists (select 1 from unnest(o.avisos) q where q like '%siguen sin repartir en la Bandeja%') then 'CON el aviso' else 'sin ese aviso' end);
    select format('%s %s h sin pago', v.nombre, trim_scale(v.horas_sin_pago)) into e from v_jornal_personas v where v.usuario_id = pg_temp.c10('p1')::uuid;
    perform pg_temp.c10_ser('editor');
    -- (c) repartido el pago de Zzbeto por su semana, llega tarde un reporte suyo de esa semana; después lo paga una nómina
    perform pg_temp.c10_aplicar(m2, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    perform pg_temp.c10_hora(5, 'p2', pg_temp.c10_w2(3), 'c10-prueba-a', 3);
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    perform pg_temp.c10_ser('editor');
    x := case when (select k.detalle like '%Zzbeto C10 PRUEBA: 3 h en 1 reporte(s)%' and not k.ok from v_jornal_control k where k.orden = 35)
                   and o.horas_estandar = 3 and exists (select 1 from unnest(o.avisos) q where q like '3 h de esta obra son de una semana ya repartida%')
              then 'el 35 la nombra y la obra la lleva a estándar'
              else 'el 35: ' || pg_temp.c10_jc(35) || ' · la obra: ' || trim_scale(o.horas_estandar) || ' h a estándar' end;
    perform pg_temp.c10_marca(array[-1010000001, -1010000002, -1010000005], pg_temp.c10_d());
    perform pg_temp.c10_ser('dueno');
    select * into o from v_margen_obra where proyecto_id = 'c10-prueba-a';
    perform pg_temp.c10_ser('editor');
    y := case when not coalesce((select k.detalle like '%Zzbeto C10 PRUEBA%' from v_jornal_control k where k.orden = 35), false)
                   and (select count(*) from fn_jornal_tardias(pg_temp.c10('p2')::uuid)) = 0
                   and o.horas_estandar = 0 and o.horas_con_pago_real = 11
                   and not exists (select 1 from unnest(o.avisos) q where q like '%semana ya repartida%')
              then 'el 35 ya no, y en su obra sale con pago real'
              else 'el 35: ' || pg_temp.c10_jc(35) || ' · la obra: ' || trim_scale(o.horas_estandar) || ' h a estándar y ' || trim_scale(o.horas_con_pago_real) || ' con pago real' end;
    f := x || '; la paga una nómina: ' || y;
    -- (d) el pago de Zzana, clasificado a mano en la Bandeja (5200 entero a la obra A)
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_clasificar(m1, '[{"cuenta": "5200", "proyecto_id": "c10-prueba-a"}]'::jsonb, 'c10-pruebas: clasificado a mano, sin repartir');
    perform pg_temp.c10_ser('editor');
    x := case when coalesce((select k.detalle like '%a Zzana C10 PRUEBA por $400.00%' from v_jornal_control k where k.orden = 70), false)
              then 'el 70 LO NOMBRA' else 'el 70 no lo nombra' end;
    perform pg_temp.c10_marca(array[-1010000005], pg_temp.c10_d());
    y := case when (select k.detalle like '%a Zzana C10 PRUEBA por $400.00 (%): 16 h suyas sin pago del %' and not k.ok from v_jornal_control k where k.orden = 70)
              then 'sí (16 h suyas sin pago)' else 'no: ' || pg_temp.c10_jc(70) end;
    g := x || '; sin la marca, ' || y;
    v_obt := format('antes de la nómina: %s | con esas horas pagadas por una nómina: %s | la semana anterior: %s | la obra A: %s | las personas: %s | '
                    'una hora que llega tarde a una semana repartida: %s | el pago de Zzana clasificado a mano en la Bandeja: %s',
                    a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT22' then v_obt := 'omitida: ' || sqlerrm;
    when lock_not_available then v_obt := pg_temp.c10_sin_candado();
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (63, 'LO QUE DICE «SIN PAGO» CON UNA NÓMINA, EN EL JORNAL (la Fase 11b): la propuesta del Zelle a alguien cuyas horas ya pagó una nómina lo avisa antes de aceptar (pagadas_por_nomina) y deja, sin cambiar qué horas entran; esas horas ya no cuentan como «sin pago» ni en la semana, ni en la persona, ni en los pagos sin repartir de su obra; una hora que llegó tarde a una semana repartida deja de ser tardía cuando la paga una nómina (el control 35 y la obra); y un pago suyo clasificado a mano en la Bandeja ya no deja «horas suyas sin pago» (el control 70)',
    v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 64. CON LAS NÓMINAS DE VERDAD DE ESTA BASE, Y EL CUADRE 70. (a) Si la
--     nómina (c15) está, cada reporte de horas con obra que su marca DE
--     VERDAD da por pagado sale en el margen con pago real: con el código
--     del teléfono y sin él (sin él la marca contesta igual: no lleva
--     dinero). Con nóminas de verdad en la base esto las mira a ellas; sin
--     ninguna, se cumple en vacío, y se dice. (b) El cuadre 70 del margen:
--     verde con la marca; si la nómina de la base no la trae (la de antes
--     del 13-nov), verde con qué pegar mientras no haya ninguna nómina en el
--     libro y EN ROJO desde que la hay; y si la marca no contesta, en rojo
--     —y el costo por obra sigue contestando, con esas horas a estándar,
--     como antes—.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text; v_n1 bigint; v_n2 bigint; v_m1 bigint; v_m2 bigint; v_t text; v_q1 text; v_q2 text;
  v_c15 boolean := to_regclass('public.nomina_corridas') is not null;
  v_marca boolean := to_regprocedure('public.fn_nomina_horas_con_pago()') is not null;
  v_hay boolean := exists (select 1 from asientos q where q.origen_tabla = 'nomina_corridas' and q.camino not in ('reverso', 'reverso_automatico')
                                        and not exists (select 1 from asientos r where r.reversa_a = q.id and r.camino = 'reverso'));
  v_nom text := 'CON LAS NÓMINAS DE VERDAD DE ESTA BASE, Y EL CUADRE 70 (la Fase 11b): cada reporte de horas que la marca de la nómina da por pagado sale con pago real en el costo por obra, con el código del teléfono y sin él; el cuadre 70 del margen está verde con la marca, dice qué pegar si la nómina de la base no la trae y todavía no hay ninguna en el libro, se pone en rojo si ya la hay o si la marca no contesta, y aun así el costo por obra sigue contestando';
  v_esp text;
begin
  v_esp := 'las horas que la nómina de esta base ya pagó: '
           || case when v_marca then 'todas con pago real, con el código del teléfono y sin él'
                   when v_c15 then 'la nómina de esta base es la de antes del 13-nov y no lo dice: vuelve a pegar c15-nomina.sql'
                   else '(la nómina no está en esta base)' end
           || ' | el cuadre 70 con la marca: verde'
           || ' | sin la marca y sin nóminas en el libro: '
           || case when v_hay then '(no se prueba: esta base ya tiene nóminas en el libro)'
                   when v_c15 then 'verde, y dice qué pegar antes de la primera'
                   else 'verde: la nómina no está en esta base' end
           || ' | sin la marca y con una nómina en el libro: '
           || case when v_c15 then 'rojo, y dice qué pegar' else 'verde: la nómina no está en esta base' end
           || ' | la marca no contesta, con una nómina en el libro: rojo, y el costo por obra sigue contestando (las horas, a estándar)'
           || ' | con la marca otra vez: verde';
  if pg_temp.c10_omitir(64, v_nom, v_esp) then return; end if;
  begin
    set local lock_timeout = '500ms';
    -- (a) la marca de verdad de esta base, tal como está
    if v_marca then
      -- (los reportes con obra que la marca da por pagados, y cuántos de ellos saca el margen con pago real: tienen que ser
      -- todos. Sin cruces: la lista de la nómina, como expresión con su tabla hash; con años de horas un cruce se hace eterno)
      v_q1 := 'select count(*) from public.horas x where x.proyecto_id is not null and x.horas > 0 and x.horas < 100000 '
           || 'and (x.id in (select n.horas_id from public.fn_nomina_horas_con_pago() n)) is true';
      v_q2 := 'select count(*) from public.fn_margen_horas(null) h where h.clase = ''pago_real'' '
           || 'and (h.horas_id in (select n.horas_id from public.fn_nomina_horas_con_pago() n)) is true';
      perform pg_temp.c10_ser('dueno');
      execute v_q1 into v_n1;
      execute v_q2 into v_m1;
      v_m1 := v_n1 - v_m1;
      perform pg_temp.c10_ser_sin_codigo();
      execute v_q1 into v_n2;
      execute v_q2 into v_m2;
      v_m2 := v_n2 - v_m2;
      perform pg_temp.c10_ser('editor');
      a := case when v_m1 = 0 and v_m2 = 0 and v_n1 = v_n2 then 'todas con pago real, con el código del teléfono y sin él'
                else format('con el código, %s de %s reporte(s) NO salen con pago real; sin él, %s de %s', v_m1, v_n1, v_m2, v_n2) end;
      v_t := format(' (%s reporte(s) de horas con obra pagados por nóminas de verdad)', v_n1);
    elsif v_c15 then
      a := 'la nómina de esta base es la de antes del 13-nov y no lo dice: vuelve a pegar c15-nomina.sql';
    else
      a := '(la nómina no está en esta base)';
    end if;
    -- (b) el cuadre 70, con una marca de prueba
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_marca(array[-1010000001], pg_temp.c10_d());
    b := case when (select k.ok from v_margen_control k where k.orden = 70) then 'verde' else pg_temp.c10_mc(70) end;
    perform pg_temp.c10_marca(null, null, 'quitar');
    if v_hay then
      c := '(no se prueba: esta base ya tiene nóminas en el libro)';
    else
      select case when k.ok and v_c15 and k.detalle like 'Todavía no hay ninguna nómina en el libro, pero la nómina de esta base es la de antes del 13-nov-2026%'
                                             || 'vuelve a pegar c15-nomina.sql%' then 'verde, y dice qué pegar antes de la primera'
                  when k.ok and not v_c15 and k.detalle like 'La nómina no está en esta base:%' then 'verde: la nómina no está en esta base'
                  else pg_temp.c10_mc(70) || ' · ' || k.detalle end
        into c from v_margen_control k where k.orden = 70;
    end if;
    -- (una nómina en el libro: el journal de prueba)
    perform pg_temp.c10_nomina(pg_temp.c10_d(),
      jsonb_build_array(jsonb_build_object('cuenta', '5000', 'monto', '200.00', 'proyecto_id', 'c10-prueba-a'),
                        jsonb_build_object('cuenta', '2210', 'monto', '-200.00')));
    select case when not k.ok and v_c15 and k.detalle like 'Hay % nómina(s) en el libro y la nómina de esta base es la de antes del 13-nov-2026%las horas que '
                                                 || 'pagaron salen a estándar%Vuelve a pegar c15-nomina.sql%' then 'rojo, y dice qué pegar'
                when k.ok and not v_c15 and k.detalle like 'La nómina no está en esta base:%' then 'verde: la nómina no está en esta base'
                else pg_temp.c10_mc(70) || ' · ' || k.detalle end
      into d from v_margen_control k where k.orden = 70;
    perform pg_temp.c10_marca(null, null, 'falla');
    perform pg_temp.c10_ser('dueno');
    select case when not k.ok and k.detalle like 'Hay % nómina(s) en el libro y no se pudo leer qué horas pagó cada nómina (la base contestó %)%'
                     and k.detalle !~ 'fn_|v_margen|v_jornal'
                     and (select o.horas_estandar = 8 and o.horas_con_pago_real = 0 and o.mano_obra_nomina = 200.00 from v_margen_obra o where o.proyecto_id = 'c10-prueba-a')
                then 'rojo, y el costo por obra sigue contestando (las horas, a estándar)'
                else case when k.ok then 'verde' else 'rojo' end || ' · ' || k.detalle end
      into e from v_margen_control k where k.orden = 70;
    perform pg_temp.c10_ser('editor');
    perform pg_temp.c10_marca(array[-1010000001], pg_temp.c10_d());
    v_obt := format('las horas que la nómina de esta base ya pagó: %s | el cuadre 70 con la marca: %s | sin la marca y sin nóminas en el libro: %s | sin '
                    'la marca y con una nómina en el libro: %s | la marca no contesta, con una nómina en el libro: %s | con la marca otra vez: %s',
                    a, b, c, d, e, case when (select k.ok from v_margen_control k where k.orden = 70) then 'verde' else pg_temp.c10_mc(70) end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT22' then v_obt := 'omitida: ' || sqlerrm;
    when lock_not_available then v_obt := pg_temp.c10_sin_candado();
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (64, v_nom, v_esp, v_obt || case when v_obt like 'omitida:%' then '' else coalesce(v_t, '') end,
                               case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- =====================================================================
-- LA CUADRILLA, SOLA (v5 de la capa, 15-nov-2026). Lo decidió Edgar: «No
-- tendría que tocar ningún botón de repartir horas ni nada, sino que eso lo
-- hiciera automático». Los Zelle a la cuadrilla entran solos; un cheque
-- pregunta de quién es. Una regla de la base, no la IA.
-- =====================================================================
-- 65. EL ALTA SOLA. La base reconoce los pagos de cada persona de la
--     cuadrilla con horas SIN que Edgar la dé de alta: su nombre, como
--     palabra entera en la descripción del banco, sacado de su perfil. La
--     rutina que registra sola la da de alta (alta «sola», a nombre del
--     dueño que la corre); correrla otra vez no da de alta a nadie más. Y
--     CON ALGUIEN YA DADO DE ALTA, la que llega después (sus primeras horas)
--     también entra sola: que haya otra persona activa no la deja fuera.
--     «Esta persona no cobra por horas» (de baja, sin patrón) la deja fuera
--     para siempre; quien no tiene horas en 90 días no entra, y el dueño
--     tampoco. Su Zelle se reconoce sin que nadie la diera de alta a mano. Y
--     si Edgar corrige el patrón, pasa a ser suyo (alta «edgar»).
do $$
declare
  v_obt text; v_r jsonb; m1 uuid; m2 uuid; a text; b text; c text; d text; e text; f text; g text;
  v_ps uuid[] := array[pg_temp.c10('p1')::uuid, pg_temp.c10('p2')::uuid, pg_temp.c10('p3')::uuid];
  v_nom text := 'EL ALTA SOLA (la cuadrilla sola): la base da de alta sola a cada persona de la cuadrilla con horas, por su nombre como '
                'palabra entera en la descripción del banco (alta «sola», a nombre del dueño); ni el dueño ni quien no tiene horas en 90 '
                'días; con alguien ya dado de alta, la que llega después también entra sola; «esta persona no cobra por horas» la deja '
                'fuera; otra vez no da de alta a nadie más; su Zelle se reconoce sin darla de alta a mano; y si Edgar corrige el patrón, '
                'pasa a ser suyo';
  v_esp text := 'con horas en 90 días solo Zzana: la base puede darla de alta sola («ZZANA C10 PRUEBA»); a Zzbeto y a Zzcaro, sin horas, '
                'no; al dueño, nunca | la rutina da de alta sola a 1 (Zzana): activa, alta «sola», con el patrón de su nombre y a nombre '
                'del dueño | llegan las primeras horas de las otras dos, con Zzana ya dada de alta: la base puede darlas de alta solas a '
                'las 2 (Zzbeto «ZZBETO C10 PRUEBA», Zzcaro «ZZCARO C10 PRUEBA») | «Zzcaro no cobra por horas»: queda de baja y la base '
                'ya no la da de alta | la rutina da de alta sola a 1 (Zzbeto) | otra vez: a nadie más | el Zelle de Zzbeto se reconoce sin '
                'darlo de alta a mano (por su patrón) | Edgar corrige el patrón de Zzana: pasa a ser suyo (alta «edgar») y reconoce 1 pago';
begin
  if pg_temp.c10_omitir(65, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_aparcar();
    -- (a) quién puede darse de alta sola: con horas en 90 días, por su nombre
    perform pg_temp.c10_ser('dueno');
    select format('con horas en 90 días solo Zzana: %s; a Zzbeto y a Zzcaro, sin horas, %s; al dueño, %s',
                  coalesce((select 'la base puede darla de alta sola («' || substring(q.patron from '^\\m(.*)\\M$') || '»)'
                              from fn_jornal_cuadrilla() q where q.usuario_id = pg_temp.c10('p1')::uuid and q.sola), 'la base NO puede'),
                  case when not exists (select 1 from fn_jornal_cuadrilla() q where q.usuario_id in (pg_temp.c10('p2')::uuid, pg_temp.c10('p3')::uuid)) then 'no' else 'TAMBIÉN' end,
                  case when not exists (select 1 from fn_jornal_cuadrilla() x join perfiles pf on pf.id = x.usuario_id where pf.rol = 'dueno') then 'nunca' else 'TAMBIÉN' end)
      into a;
    -- (b) la rutina (sin tiempo para registrar nada: aquí solo se mira el alta)
    v_r := fn_jornal_solo('{"segundos": 0}'::jsonb);
    select format('la rutina da de alta sola a %s (%s): %s', count(*), string_agg(split_part(x->>'nombre', ' ', 1), ', ' order by x->>'nombre'),
                  case when (select count(*) from jornal_personas j
                              where j.usuario_id = any (v_ps) and j.activa and j.alta = 'sola' and j.creado_por::text = pg_temp.c10('dueno')
                                and j.patron = fn_jornal_nombre_patron((select pf.nombre from perfiles pf where pf.id = j.usuario_id))) = 1
                       then 'activa, alta «sola», con el patrón de su nombre y a nombre del dueño' else 'pero NO queda como debe' end)
      into b
      from jsonb_array_elements(v_r->'altas') x where (x->>'usuario_id')::uuid = any (v_ps);
    -- (c) llegan las primeras horas de las otras dos, CON ZZANA YA DADA DE ALTA Y ACTIVA: también pueden entrar solas
    perform pg_temp.c10_ser('editor');
    perform pg_temp.c10_hora(2, 'p2', pg_temp.c10_w1(1), 'c10-prueba-b', 6);
    perform pg_temp.c10_hora(3, 'p3', pg_temp.c10_w1(2), 'c10-prueba-b', 5);
    perform pg_temp.c10_ser('dueno');
    select format('la base puede darlas de alta solas a las %s (%s)', count(*) filter (where q.sola),
                  string_agg(case when q.sola then format('%s «%s»', split_part(q.nombre, ' ', 1), substring(q.patron from '^\\m(.*)\\M$'))
                                  else format('%s NO: %s', split_part(q.nombre, ' ', 1), q.por_que) end, ', ' order by q.nombre))
      into c
      from fn_jornal_cuadrilla() q where q.usuario_id = any (v_ps);
    -- (d) «esta persona no cobra por horas»: de baja, sin patrón; la base ya no la da de alta sola
    v_r := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p3'), 'activa', false));
    d := case when (select not j.activa and j.patron = '\mZZCARO C10 PRUEBA\M' from jornal_personas j where j.usuario_id = pg_temp.c10('p3')::uuid)
                   and not exists (select 1 from fn_jornal_cuadrilla() q where q.usuario_id = pg_temp.c10('p3')::uuid)
                   and v_r->>'nota_alta' like 'Zzcaro C10 PRUEBA queda de baja%'
              then 'queda de baja y la base ya no la da de alta' else 'NO: ' || left(v_r::text, 200) end;
    -- (e) la rutina: da de alta a Zzbeto; y otra vez, a nadie más
    v_r := fn_jornal_solo('{"segundos": 0}'::jsonb);
    select format('la rutina da de alta sola a %s (%s)', count(*), string_agg(split_part(x->>'nombre', ' ', 1), ', ' order by x->>'nombre'))
      into e
      from jsonb_array_elements(v_r->'altas') x where (x->>'usuario_id')::uuid = any (v_ps);
    v_r := fn_jornal_solo('{"segundos": 0}'::jsonb);
    e := format('%s | otra vez: %s', e,
                case when not exists (select 1 from jsonb_array_elements(v_r->'altas') x where (x->>'usuario_id')::uuid = any (v_ps))
                          and (select count(*) from jornal_personas j where j.usuario_id = any (v_ps)) = 3 then 'a nadie más' else 'OTRA VEZ: ' || (v_r->'altas')::text end);
    perform pg_temp.c10_ser('editor');
    -- (f) su Zelle se reconoce sin que nadie lo diera de alta a mano
    m1 := pg_temp.c10_cargo('c10-t65-1', pg_temp.c10_ds(), 144.00, 'Zelle payment to ZZBETO C10 PRUEBA 9651');
    perform pg_temp.c10_ser('dueno');
    select case when q.persona = 'Zzbeto C10 PRUEBA' and q.por = 'patron' then 'se reconoce sin darlo de alta a mano (por su patrón)' else 'sale como ' || coalesce(q.persona, '?') || ' / ' || coalesce(q.por, '?') end
      into f from v_jornal_pendientes q where q.movimiento_id = m1;
    perform pg_temp.c10_ser('editor');
    -- (g) Edgar corrige el patrón: pasa a ser suyo
    m2 := pg_temp.c10_cargo('c10-t65-2', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9652');
    perform pg_temp.c10_ser('dueno');
    v_r := fn_jornal_persona(jsonb_build_object('usuario_id', pg_temp.c10('p1'), 'patron', 'ZZANA C10'));
    g := case when v_r->>'alta' = 'edgar' and v_r->>'patron' = 'ZZANA C10' and (v_r->>'pagos_pendientes')::int = 1
              then 'pasa a ser suyo (alta «edgar») y reconoce 1 pago' else left(v_r::text, 300) end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('%s | %s | llegan las primeras horas de las otras dos, con Zzana ya dada de alta: %s | «Zzcaro no cobra por horas»: %s | %s | '
                    'el Zelle de Zzbeto %s | Edgar corrige el patrón de Zzana: %s',
                    a, coalesce(b, 'la rutina no da de alta a nadie'), c, d, e, coalesce(f, 'NO se reconoce'), g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (65, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 66. LO AMBIGUO: NO ADIVINA, Y LO DICE. Con un nombre que deja dudas la
--     base NO da de alta sola a la persona, y dice por qué (en la fila de la
--     persona: sola = false y su porqué): un nombre demasiado corto; uno
--     demasiado común (casaría con lo que el banco escribe en cualquier
--     pago); uno que casa con el de otra persona (la otra, si el suyo no
--     deja dudas, sí entra); dos iguales (ninguna de las dos); uno que casa
--     con el patrón de quien ya cobra por horas; y uno que el banco ya
--     escribe en pagos a dos destinatarios distintos. Su Zelle se queda
--     entonces como un movimiento normal. Y a quien la base ya dio de alta
--     sola, si después llega un pago a OTRO con su mismo nombre, ninguno de
--     los dos entra solo: lo pregunta.
do $$
declare
  v_obt text; v_r jsonb; m1 uuid; m2 uuid; a text; b text; c text; d text; e text; f text; g text; h text;
  p1 uuid := pg_temp.c10('p1')::uuid; p2 uuid := pg_temp.c10('p2')::uuid;
  v_nom text := 'LO AMBIGUO: NO ADIVINA, Y LO DICE (la cuadrilla sola): con un nombre demasiado corto, demasiado común, que casa con el de '
                'otra persona o con el patrón de quien ya cobra por horas, o que el banco escribe en pagos a dos destinatarios, la base no '
                'da de alta sola a la persona y dice por qué; su Zelle se queda como un movimiento normal; y si a quien ya dio de alta sola '
                'le llega un pago a otro con su mismo nombre, ninguno de los dos entra solo';
  v_esp text := 'corto («Zz»): no, y lo dice | común («Zelle Payment»): no, y lo dice | casa con otra persona («Zzana» y «Zzana C10 PRUEBA»): '
                'la primera no, y lo dice; la segunda sí | dos iguales: ninguna de las dos | casa con el patrón de quien ya cobra por horas: '
                'no, y lo dice | el banco la escribe en pagos a un solo destinatario: sí; a dos: no, y dice cuáles | la rutina no la da de '
                'alta y su fila dice por qué | su Zelle se queda como un movimiento normal | ya dada de alta sola, llega un pago a otro con '
                'su nombre: los dos preguntan (su nombre casa con dos personas) y ninguno entra solo';
begin
  if pg_temp.c10_omitir(66, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(66, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', pg_temp.c10_w1(1), 'c10-prueba-b', 6);
    perform pg_temp.c10_aparcar();
    -- (a) demasiado corto
    update perfiles set nombre = 'Zz' where id = p1;
    select case when not q.sola and q.por_que like 'su nombre en la app («Zz») es demasiado corto%' then 'no, y lo dice' else 'MAL: ' || coalesce(q.por_que, 'sola') end
      into a from fn_jornal_cuadrilla() q where q.usuario_id = p1;
    -- (b) demasiado común: lo que el banco escribe en cualquier pago
    update perfiles set nombre = 'Zelle Payment' where id = p1;
    select case when not q.sola and q.por_que like 'su nombre en la app («Zelle Payment») es demasiado común%' then 'no, y lo dice' else 'MAL: ' || coalesce(q.por_que, 'sola') end
      into b from fn_jornal_cuadrilla() q where q.usuario_id = p1;
    -- (c) casa con otra persona: «Zzana» sale también en «Zzana C10 PRUEBA»
    update perfiles set nombre = 'Zzana' where id = p1;
    update perfiles set nombre = 'Zzana C10 PRUEBA' where id = p2;
    select format('la primera %s; la segunda %s',
                  (select case when not q.sola and q.por_que like 'su nombre («ZZANA») casa también con el de Zzana C10 PRUEBA%' then 'no, y lo dice' else 'MAL: ' || coalesce(q.por_que, 'sola') end
                     from fn_jornal_cuadrilla() q where q.usuario_id = p1),
                  (select case when q.sola then 'sí' else 'NO: ' || q.por_que end from fn_jornal_cuadrilla() q where q.usuario_id = p2))
      into c;
    -- (d) dos iguales
    update perfiles set nombre = 'Zzana C10 PRUEBA' where id = p1;
    select case when count(*) filter (where not q.sola and q.por_que like '%casa también con el de Zzana C10 PRUEBA%') = 2 then 'ninguna de las dos' else 'MAL: ' || count(*) filter (where q.sola) || ' sola(s)' end
      into d from fn_jornal_cuadrilla() q where q.usuario_id in (p1, p2);
    -- (e) casa con el patrón de quien ya cobra por horas (Zzbeto, dado de alta por Edgar con «ZZANA»)
    update perfiles set nombre = 'Zzbeto C10 PRUEBA' where id = p2;
    perform pg_temp.c10_alta('p2', 'ZZANA');
    select case when not q.sola and q.por_que like 'su nombre («ZZANA C10 PRUEBA») casa también con el patrón de Zzbeto C10 PRUEBA%' then 'no, y lo dice' else 'MAL: ' || coalesce(q.por_que, 'sola') end
      into e from fn_jornal_cuadrilla() q where q.usuario_id = p1;
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_persona(jsonb_build_object('usuario_id', p2, 'activa', false));
    perform pg_temp.c10_ser('editor');
    -- (f) lo que el banco ya trajo: con un solo destinatario, sí; con dos, no
    update perfiles set nombre = 'Zzana' where id = p1;
    m1 := pg_temp.c10_cargo('c10-t66-1', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA ALFA C10 PRUEBA 9661');
    select case when q.sola then 'sí' else 'NO: ' || q.por_que end into f from fn_jornal_cuadrilla() q where q.usuario_id = p1;
    -- (la rutina la da de alta sola con ese único destinatario; sin tiempo para registrar: aquí se mira el alta)
    v_r := pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    m2 := pg_temp.c10_cargo('c10-t66-2', pg_temp.c10_ds(), 210.00, 'Zelle payment to ZZANA BETA C10 PRUEBA 9662');
    -- (i) ya dada de alta sola, llega un pago a otro con su nombre: los dos preguntan
    h := format('los dos %s y %s', case when pg_temp.c10_solo(m1) = 'pregunta [nombre_ambiguo]' and pg_temp.c10_solo(m2) = 'pregunta [nombre_ambiguo]'
                                        then 'preguntan (su nombre casa con dos personas)' else pg_temp.c10_solo(m1) || ' / ' || pg_temp.c10_solo(m2) end,
                case when pg_temp.c10_registrados(pg_temp.c10_rutina(), array[m1, m2]) = '0'
                          and (select count(*) from movimientos_banco m where m.id in (m1, m2) and m.estado = 'pendiente') = 2
                     then 'ninguno entra solo' else 'ALGUNO ENTRÓ' end);
    -- (y sin estar dada de alta, con esos dos pagos en el banco: no, y dice cuáles)
    perform set_config('mx_jornal.escribe', 'jornal_personas', true);
    delete from jornal_personas where usuario_id = p1;
    perform set_config('mx_jornal.escribe', '', true);
    select f || '; a dos: ' || case when not q.sola and q.por_que = 'el banco escribe «ZZANA» en pagos a 2 destinatarios distintos (ZZANA ALFA, ZZANA BETA): no se sabe cuál es'
                                    then 'no, y dice cuáles' else 'MAL: ' || coalesce(q.por_que, 'sola') end
      into f from fn_jornal_cuadrilla() q where q.usuario_id = p1;
    -- (g) la rutina no la da de alta, y su fila lo dice; su Zelle se queda como un movimiento normal
    v_r := pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    perform pg_temp.c10_ser('dueno');
    g := case when not exists (select 1 from jsonb_array_elements(v_r->'altas') x where (x->>'usuario_id')::uuid = p1)
                   and not exists (select 1 from jornal_personas j where j.usuario_id = p1)
                   and (select not v.registrada and v.sola is false and v.sola_por_que like 'el banco escribe «ZZANA» en pagos a 2 destinatarios%' and v.patron_nombre = '\mZZANA\M'
                          from v_jornal_personas v where v.usuario_id = p1)
              then 'la rutina no la da de alta y su fila dice por qué' else 'MAL: ' || (v_r->'altas')::text end;
    g := g || ' | su Zelle ' || case when not (fn_jornal_propuesta(m1)->>'reconocido')::boolean and not exists (select 1 from v_jornal_pendientes q where q.movimiento_id in (m1, m2))
                                     then 'se queda como un movimiento normal' else 'SE RECONOCE' end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('corto («Zz»): %s | común («Zelle Payment»): %s | casa con otra persona («Zzana» y «Zzana C10 PRUEBA»): %s | dos iguales: %s | '
                    'casa con el patrón de quien ya cobra por horas: %s | el banco la escribe en pagos a un solo destinatario: %s | %s | ya dada '
                    'de alta sola, llega un pago a otro con su nombre: %s', a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (66, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 67. EL REGISTRO SOLO. El Zelle a una persona de la cuadrilla, reconocido
--     sin que Edgar toque nada, entra solo al libro: mano de obra de la
--     cuadrilla (la cuenta del jornal, 5200), una línea por obra y CO con la
--     persona como tercero, repartido por las horas del período que paga; el
--     movimiento queda casado; las horas, aprobadas por c3 a nombre del
--     dueño; y el rastro, escrito: el reparto dice que entró «solo», por el
--     patrón, con su regla (cuál, desde dónde corrió y en nombre de quién), y
--     cada línea del asiento, «registrado solo (la regla de Edgar)». NO ES
--     SALARIO: ni una línea en 5000, 5001, 6000 ni 6005, y el control de la
--     mano de obra de c3 sigue como estaba. Es lo mismo que habría entrado
--     con el «Así es» (la huella es la de la propuesta). Y correr la rutina
--     otra vez no hace nada.
do $$
declare
  v_obt text; v_r jsonb; v_r2 jsonb; v_j jsonb; m1 uuid; a text; b text; c text; d text; e text; f text; v_as uuid; v_mo0 text; v_n0 int;
  rp jornal_repartos;
  v_nom text := 'EL REGISTRO SOLO (la cuadrilla sola): el Zelle de una persona de la cuadrilla entra solo al libro como mano de obra (5200), '
                'una línea por obra y CO con la persona como tercero, por las horas del período que paga; el movimiento casado; las horas '
                'aprobadas por c3 a nombre del dueño; el reparto con origen «solo», por el patrón y con su regla; el asiento lo dice en '
                'cada línea; ni una línea en 5000, 5001, 6000 o 6005; es la huella de la propuesta; y otra vez no hace nada';
  v_esp text := 'antes: entra | la rutina registra 1: Zzana 362.50 y lo dice | el asiento: 1 1010 -362.50 | 2 5200 200.00 a empleado:p1 | 3 '
                '5200 62.50 b empleado:p1 | 4 5200 100.00 b/CO #1 empleado:p1; cada línea dice «registrado solo (la regla de Edgar)»; nada '
                'en 5000, 5001, 6000 ni 6005 | el pago casado con ese asiento; las 3 horas aprobadas por c3 a nombre del dueño | el '
                'reparto: origen solo, por patron, la semana anterior, regla «la cuadrilla, sola» desde la pantalla y en nombre del dueño, '
                'con la huella de la propuesta | la mano de obra de c3, como estaba; control del jornal: nada nuevo en rojo; del margen: nada '
                'nuevo en rojo | otra vez: no registra nada (1 reparto, los mismos asientos)';
begin
  if pg_temp.c10_omitir(67, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(67, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 2.5);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-b', 4, 'CO #1');
    perform pg_temp.c10_aparcar();
    select coalesce((select case when k.ok then 'verde' else 'rojo' end from fn_puentes_verificar() k where k.control = 'mano_de_obra'), 'no está') into v_mo0;
    m1 := pg_temp.c10_cargo('c10-t67-1', pg_temp.c10_ds(), 362.50, 'Zelle payment to ZZANA C10 PRUEBA 9671');
    -- (el alta sola, sin registrar todavía; y cómo está el pago: entra)
    perform pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    a := pg_temp.c10_solo(m1);
    v_j := pg_temp.c10_propuesta(m1);
    -- (b) la rutina, como al abrir Contabilidad
    v_r := pg_temp.c10_rutina();
    b := format('la rutina registra %s y %s', pg_temp.c10_registrados(v_r, array[m1]),
                case when v_r->>'nota' like 'Registrado solo: 1 pago(s) a la cuadrilla por $362.50 (Zzana C10 PRUEBA $362.50).%'
                          and v_r->'registrados'->0->>'nota' like 'Registrado solo: $362.50 de Zzana C10 PRUEBA (%, 14.5 h) entre 2 obra(s); asiento %Quedaron aprobados 3 reporte(s) de horas.'
                     then 'lo dice' else 'dice: ' || coalesce(v_r->>'nota', '(nada)') end);
    select * into rp from jornal_repartos r where r.movimiento_id = m1 and r.estado = 'aplicado';
    v_as := rp.asiento_id;
    c := format('%s; %s; %s', pg_temp.c10_asiento(v_as),
                case when (select bool_and(l.memo like 'Jornal de Zzana C10 PRUEBA · % · registrado solo (la regla de Edgar) · % h de 14.5 h') from asiento_lineas l where l.asiento_id = v_as and l.orden > 1)
                     then 'cada línea dice «registrado solo (la regla de Edgar)»' else 'las líneas NO lo dicen' end,
                case when not exists (select 1 from asiento_lineas l where l.asiento_id = v_as and l.cuenta in ('5000', '5001', '6000', '6005'))
                     then 'nada en 5000, 5001, 6000 ni 6005' else 'HAY líneas de sueldo' end);
    d := format('%s; %s',
                case when (select m.estado = 'casado' and m.asiento_id = v_as from movimientos_banco m where m.id = m1) then 'el pago casado con ese asiento' else 'el pago NO casó' end,
                case when (select count(*) from horas h where h.id in (-1010000001, -1010000002, -1010000003) and h.aprobado_el is not null and h.aprobado_por::text = pg_temp.c10('dueno')) = 3
                          and (select count(*) from horas_aprobaciones x where x.horas_id in (-1010000001, -1010000002, -1010000003) and x.accion = 'aprobada') = 3
                     then 'las 3 horas aprobadas por c3 a nombre del dueño' else 'las horas NO quedaron aprobadas como deben' end);
    e := format('origen %s, por %s, %s, regla «%s» desde la %s y %s, %s', rp.origen, rp.por,
                case rp.regla_periodo when 'semana_anterior' then 'la semana anterior' else rp.regla_periodo end, rp.regla->>'regla', rp.regla->>'corrio',
                case when rp.regla->>'en_nombre_de' = pg_temp.c10('dueno') and rp.creado_por::text = pg_temp.c10('dueno') then 'en nombre del dueño' else 'SIN decir en nombre de quién' end,
                case when rp.huella = v_j->>'visto' and rp.desde = pg_temp.c10_w1(0) and rp.hasta = pg_temp.c10_w1(6) then 'con la huella de la propuesta' else 'con OTRA huella' end);
    f := format('la mano de obra de c3, %s; %s',
                case when coalesce((select case when k.ok then 'verde' else 'rojo' end from fn_puentes_verificar() k where k.control = 'mano_de_obra'), 'no está') = v_mo0 then 'como estaba' else 'CAMBIÓ' end,
                pg_temp.c10_propios());
    -- (g) otra vez
    select count(*) into v_n0 from asientos;
    v_r2 := pg_temp.c10_rutina();
    v_obt := format('antes: %s | %s | el asiento: %s | %s | el reparto: %s | %s | otra vez: %s', a, b, c, d, e, f,
                    case when pg_temp.c10_registrados(v_r2, array[m1]) = '0' and (v_r2->>'completo')::boolean
                              and (select count(*) from jornal_repartos r where r.movimiento_id = m1) = 1 and (select count(*) from asientos) = v_n0
                         then 'no registra nada (1 reparto, los mismos asientos)' else 'HIZO algo: ' || left(v_r2::text, 200) end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (67, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 68. CADA AVISO QUE LO FRENA (a): lo que la propuesta ve. Entra solo lo que
--     se puede aplicar SIN ningún aviso que pida decidir; con uno, el pago se
--     queda en la Bandeja con UNA pregunta clara, y nada se toca. Con sus
--     pagos de verdad (cada uno, el Zelle de una persona reconocida sola por
--     su nombre): el que sale a su tarifa ENTRA; el mismo pago traído dos
--     veces (un posible duplicado), la tarifa que sale lejos de la suya, el
--     cargo en un comercio con su nombre, la persona sin horas en esa semana
--     y la que no tiene tarifa con que comparar, PREGUNTAN. Y el que entraba
--     deja de entrar si en su semana hay horas sin obra con su cuenta sin
--     fijar; las horas en una obra terminada o en una sin aprobar NO lo
--     frenan (la revisión del 15-nov: su parte va a esa obra igual; la 80).
--     La rutina registra el
--     único que entra y deja los demás como estaban, cada uno con su porqué;
--     registrado ese, otro pago de las mismas horas (ya cubiertas) pregunta.
do $$
declare
  v_obt text; v_r jsonb; mA uuid; mB uuid; mC uuid; mD uuid; mE uuid; mF uuid; v_m uuid[]; a text; b text; c text; d text; e text;
  v_nom text := 'CADA AVISO QUE LO FRENA (la cuadrilla sola), con pagos de verdad: entra solo el que no trae ningún aviso que pida decidir; '
                'el posible duplicado, la tarifa que sale lejos, el cargo que no parece un pago a una persona, la semana sin horas y la '
                'persona sin tarifa PREGUNTAN, y el que entraba deja de entrar con horas sin obra y su cuenta sin fijar (las de una obra '
                'terminada o sin aprobar no lo frenan); la rutina registra el único que entra y no toca los demás (pendientes, sin reparto, cada '
                'uno con su porqué); y con las horas ya cubiertas por ese, otro pago de la misma semana pregunta';
  v_esp text := 'a su tarifa: entra | el mismo, traído dos veces: pregunta [posible_duplicado] | la tarifa lejos: pregunta [tarifa_lejos] | '
                'en un comercio con su nombre: pregunta [no_parece_pago] | sin horas esa semana: pregunta [sin_horas] | sin tarifa: pregunta '
                '[sin_tarifa] | el que entraba, con horas en una obra terminada, en una sin aprobar y sin obra (sin su cuenta): pregunta '
                '[falta_cuenta_sin_obra] (la obra terminada y la sin aprobar no frenan) | la rutina registra 1: Zzana 200.00; los otros 5 no entraron, '
                'cada uno con su pregunta, y siguen pendientes y sin reparto | con las horas ya cubiertas: pregunta [sin_horas,se_pisa] | '
                'otra vez: 0';
begin
  if pg_temp.c10_omitir(68, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(68, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', pg_temp.c10_w2(1), 'c10-prueba-b', 6);
    perform pg_temp.c10_hora(3, 'p3', pg_temp.c10_w1(2), 'c10-prueba-b', 5);
    perform pg_temp.c10_aparcar();
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"aviso_tarifa_pct": 25, "cuenta_sin_obra": null}');
    perform pg_temp.c10_ser('editor');
    mA := pg_temp.c10_cargo('c10-t68-1',  pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9681');
    mB := pg_temp.c10_cargo('c10-t68-1b', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9681');
    mC := pg_temp.c10_cargo('c10-t68-3',  pg_temp.c10_ds(), 400.00, 'Zelle payment to ZZANA C10 PRUEBA 9683');
    mD := pg_temp.c10_cargo('c10-t68-4',  pg_temp.c10_ds(), 200.00, 'POS PURCHASE ZZANA C10 PRUEBA SUPPLY 9684');
    mE := pg_temp.c10_cargo('c10-t68-5',  pg_temp.c10_ds(), 144.00, 'Zelle payment to ZZBETO C10 PRUEBA 9685');
    mF := pg_temp.c10_cargo('c10-t68-6',  pg_temp.c10_ds(), 100.00, 'Zelle payment to ZZCARO C10 PRUEBA 9686');
    v_m := array[mA, mB, mC, mD, mE, mF];
    -- (el alta sola de las tres, sin registrar nada todavía)
    perform pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    a := format('a su tarifa: %s | el mismo, traído dos veces: %s | la tarifa lejos: %s | en un comercio con su nombre: %s | sin horas esa '
                'semana: %s | sin tarifa: %s', pg_temp.c10_solo(mA), pg_temp.c10_solo(mB), pg_temp.c10_solo(mC), pg_temp.c10_solo(mD),
                pg_temp.c10_solo(mE), pg_temp.c10_solo(mF));
    -- (b) el que entraba deja de entrar: la cuenta de lo sin obra (la obra terminada y la sin aprobar ya no frenan)
    begin
      perform pg_temp.c10_hora(4, 'p1', pg_temp.c10_w1(1), 'c10-prueba-c', 4);
      perform pg_temp.c10_hora(5, 'p1', pg_temp.c10_w1(2), 'c10-prueba-g', 2);
      perform pg_temp.c10_hora(6, 'p1', pg_temp.c10_w1(3), null, 2);
      b := (select string_agg(x, ',') from unnest(string_to_array(substring(pg_temp.c10_solo(mA) from '\[(.*)\]'), ',')) x
             where x not in ('tarifa_lejos'));
      b := split_part(pg_temp.c10_solo(mA), ' ', 1) || ' [' || coalesce(b, '') || ']'
           || case when pg_temp.c10_notas(pg_temp.c10_propuesta(mA)->'avisos') = 'obra_terminada,obra_sin_aprobar'
                   then ' (la obra terminada y la sin aprobar no frenan)' else ' (FALTAN los avisos de las obras)' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    -- (c) la rutina: registra el único que entra; los demás, como estaban
    v_r := pg_temp.c10_rutina();
    c := format('la rutina registra %s; %s', pg_temp.c10_registrados(v_r, v_m),
                case when (select count(*) from jsonb_array_elements(v_r->'no_entraron') x
                            where (x->>'movimiento_id')::uuid = any (v_m) and x->>'estado' = 'pregunta' and length(x->>'por_que') > 20) = 5
                          and (select count(*) from movimientos_banco m where m.id = any (v_m) and m.id <> mA and m.estado = 'pendiente' and m.asiento_id is null) = 5
                          and (select count(*) from jornal_repartos r where r.movimiento_id = any (v_m)) = 1
                          and (select count(*) from horas h where h.id in (-1010000002, -1010000003) and h.aprobado_el is not null) = 0
                     then 'los otros 5 no entraron, cada uno con su pregunta, y siguen pendientes y sin reparto'
                     else 'ALGO se tocó: ' || left((v_r->'no_entraron')::text, 300) end);
    -- (d) las horas ya cubiertas por el que entró
    d := pg_temp.c10_solo(mC);
    v_r := pg_temp.c10_rutina();
    e := pg_temp.c10_registrados(v_r, v_m);
    v_obt := format('%s | el que entraba, con horas en una obra terminada, en una sin aprobar y sin obra (sin su cuenta): %s | %s | con las '
                    'horas ya cubiertas: %s | otra vez: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (68, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 69. CADA AVISO QUE LO FRENA (b): LO QUE PUEDE CASAR CON OTRA COSA DEL LIBRO,
--     y lo demás que solo sabe el banco. Eso no lo ve la propuesta: lo sabe c6
--     al postear, y la rutina le pregunta SIN motivo, como el «Así es» (los
--     frenos del banco valen enteros). Si c6 lo frena, el pago NO entra, nada
--     queda a medias, y queda apuntado lo que dijo (jornal_pagos: el último
--     intento): espera en la Bandeja con ese porqué.
--     (a) Un débito que c6 toma por nómina (dice PAYROLL; no es un Zelle): la
--     propuesta lo da por bueno, la rutina lo intenta, c6 dice «dilo en el
--     motivo», y no entra. No se insiste con lo mismo: la corrida siguiente
--     no lo vuelve a intentar; pasadas 20 horas, o si las horas cambian, sí.
--     Con el «Así es» de Edgar y su motivo, entra (a mano).
--     (b) UN CHEQUE QUE PUEDE SER OTRO YA APUNTADO EN EL LIBRO (un asiento a
--     mano del mismo monto en esa cuenta, de días antes, sin su número: un
--     cheque tarda en cobrarse). Edgar dice de quién es; c6 dice «puede ser
--     esto del libro», y no entra: queda como la tarjeta de esa persona, con
--     su porqué. Con su motivo, entra.
do $$
declare
  v_obt text; v_r jsonb; v_j jsonb; mA uuid; mC uuid; a text; b text; c text; d text; e text; f text; g text; v_n0 int; v_t0 timestamptz;
  v_t1 timestamptz; v_fa date; v_mes text; v_no text;
  v_nom text := 'CADA AVISO QUE LO FRENA (la cuadrilla sola): LO QUE PUEDE CASAR CON OTRA COSA DEL LIBRO y lo demás que solo sabe el banco. '
                'La rutina postea por c6 SIN motivo: lo que c6 frena no entra, nada queda a medias y queda apuntado lo que dijo; no se '
                'insiste con lo mismo (sí pasadas 20 horas o si las horas cambian); con el «Así es» de Edgar y su motivo, entra a mano. Un '
                'débito que c6 toma por nómina, y un cheque que puede ser otro ya apuntado en el libro';
  v_esp text := 'el débito que dice PAYROLL: c6 lo toma por nómina; para la propuesta, entra | la rutina lo intenta y no entra: lo dice («dilo en '
                'el motivo»), queda apuntado (MX008) y nada cambia | después: pregunta [no_entro] | otra vez: no lo vuelve a intentar | '
                'pasadas 20 horas: lo vuelve a intentar, y tampoco | con las horas cambiadas: entra, se intenta de nuevo, y tampoco | con '
                'el «Así es» de Edgar y su motivo: entra, a mano | el cheque que puede ser otro ya apuntado en el libro: Edgar dice de quién '
                'es y no entra: lo dice («puede ser esto del libro»), queda como la tarjeta de Zzbeto [no_entro] y nada cambia; con su '
                'motivo: entra, a mano y por lo que dijo Edgar';
begin
  if pg_temp.c10_omitir(69, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(69, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', pg_temp.c10_w1(1), 'c10-prueba-b', 10);
    perform pg_temp.c10_aparcar();
    mA := pg_temp.c10_cargo('c10-t69-1', pg_temp.c10_ds(), 200.00, 'ACH DEBIT ZZANA C10 PRUEBA PAYROLL 9691');
    perform pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    a := format('%s; para la propuesta, %s', case when (select m.estado_motivo from movimientos_banco m where m.id = mA) = 'nomina' then 'c6 lo toma por nómina'
                                                  else 'c6 dice ' || coalesce((select m.estado_motivo from movimientos_banco m where m.id = mA), '-') end,
                pg_temp.c10_solo(mA));
    select count(*) into v_n0 from asientos;
    v_r := pg_temp.c10_rutina();
    b := format('%s, %s y %s',
                case when pg_temp.c10_registrados(v_r, array[mA]) = '0'
                          and exists (select 1 from jsonb_array_elements(v_r->'no_entraron') x
                                       where (x->>'movimiento_id')::uuid = mA and x->>'estado' = 'pregunta'
                                         and x->>'por_que' like 'No entró solo: Es un débito de nómina%dilo en el motivo%')
                     then 'la rutina lo intenta y no entra: lo dice («dilo en el motivo»)' else 'la rutina: ' || left(v_r::text, 300) end,
                (select 'queda apuntado (' || coalesce(g2.intento_codigo, 'nada') || ')' from jornal_pagos g2 where g2.movimiento_id = mA),
                case when (select count(*) from asientos) = v_n0 and (select m.estado from movimientos_banco m where m.id = mA) = 'pendiente'
                          and not exists (select 1 from horas h where h.id = -1010000001 and h.aprobado_el is not null)
                          and not exists (select 1 from jornal_repartos r where r.movimiento_id = mA)
                     then 'nada cambia' else 'ALGO cambió' end);
    c := pg_temp.c10_solo(mA);
    -- (otra vez: lo mismo no se vuelve a intentar)
    select g2.intento_el into v_t0 from jornal_pagos g2 where g2.movimiento_id = mA;
    v_r := pg_temp.c10_rutina();
    d := case when (select g2.intento_el from jornal_pagos g2 where g2.movimiento_id = mA) = v_t0 and pg_temp.c10_registrados(v_r, array[mA]) = '0'
              then 'no lo vuelve a intentar' else 'LO VOLVIÓ a intentar' end;
    -- (pasadas 20 horas: sí)
    perform set_config('mx_jornal.escribe', 'jornal_pagos', true);
    update jornal_pagos set intento_el = intento_el - interval '21 hours' where movimiento_id = mA returning intento_el into v_t1;
    perform set_config('mx_jornal.escribe', '', true);
    v_r := pg_temp.c10_rutina();
    e := case when (select g2.intento_el from jornal_pagos g2 where g2.movimiento_id = mA) > v_t0 and pg_temp.c10_registrados(v_r, array[mA]) = '0'
                   and (select m.estado from movimientos_banco m where m.id = mA) = 'pendiente'
              then 'lo vuelve a intentar, y tampoco' else 'NO lo reintentó, o entró' end;
    -- (con las horas cambiadas —otra huella—: entra otra vez para la propuesta, y se intenta de nuevo)
    select g2.intento_el into v_t0 from jornal_pagos g2 where g2.movimiento_id = mA;
    perform pg_temp.c10_corregir(1, 'proyecto_id = ''c10-prueba-b''');
    f := pg_temp.c10_solo(mA);
    v_r := pg_temp.c10_rutina();
    f := format('%s, %s', f, case when (select g2.intento_el from jornal_pagos g2 where g2.movimiento_id = mA) > v_t0
                                       and pg_temp.c10_registrados(v_r, array[mA]) = '0' and pg_temp.c10_solo(mA) = 'pregunta [no_entro]'
                                  then 'se intenta de nuevo, y tampoco' else 'NO se intentó de nuevo, o entró' end);
    -- (el «Así es» de Edgar, con su motivo)
    v_r := pg_temp.c10_aplicar(mA, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"motivo": "c10-pruebas: es su jornal de la semana, no la nómina"}');
    g := case when v_r->>'estado' = 'aplicado' and (select r.origen from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid) = 'mano'
              then 'entra, a mano' else left(v_r::text, 200) end;
    v_obt := format('el débito que dice PAYROLL: %s | %s | después: %s | otra vez: %s | pasadas 20 horas: %s | con las horas cambiadas: %s | con '
                    'el «Así es» de Edgar y su motivo: %s', a, b, c, d, e, f, g);
    -- (b) el cheque que puede ser otro ya apuntado en el libro: un asiento a mano de 8 días antes, del mismo monto, en esa cuenta
    v_fa := pg_temp.c10_ds() - 8;
    select to_jsonb(p)->>'estado' into v_mes from periodos p where p.tipo = 'mes' and v_fa between p.desde and p.hasta;
    if v_mes is distinct from 'abierto' or v_fa < fn_margen_libro_desde() then
      v_no := format('el asiento a mano del cheque iría con fecha %s y ese mes %s', v_fa, case when v_mes is null then 'no está en el libro' else 'está ' || v_mes end);
    else
      perform pg_temp.c10_ser('dueno');
      perform fn_postear(jsonb_build_object('fecha', v_fa::text, 'descripcion', 'C10 PRUEBA: un cheque a un proveedor, apuntado a mano (se deshace)',
                'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5400', 'monto', '240.00', 'proyecto_id', 'c10-prueba-a'),
                                            jsonb_build_object('cuenta', pg_temp.c10('banco'), 'monto', '-240.00'))));
      perform pg_temp.c10_ser('editor');
      mC := pg_temp.c10_cargo('c10-t69-2', pg_temp.c10_ds(), 240.00, 'CHECK 9692 C10 PRUEBA');
      select count(*) into v_n0 from asientos;
      v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC, 'usuario_id', pg_temp.c10('p2')));
      a := format('Edgar dice de quién es y %s, queda como la tarjeta de %s y %s',
                  case when not (v_r->>'registrado')::boolean
                            and v_r->>'nota' like 'Anotado: este pago es de Zzbeto C10 PRUEBA. No entró solo: Puede ser esto del libro:%un cheque tarda en cobrarse%dilo en el motivo.'
                       then 'no entra: lo dice («puede ser esto del libro»)' else 'MAL: ' || left(v_r::text, 300) end,
                  (select split_part(q.persona, ' ', 1) || ' [' || (select string_agg(t.f->>'codigo', ',') from jsonb_array_elements(q.solo_frenos) t(f)) || ']'
                     from (select pg_temp.c10_ser('dueno')) s, v_jornal_pendientes q where q.movimiento_id = mC and q.por = 'edgar' and q.cheque = '9692'),
                  case when (select count(*) from asientos) = v_n0 and (select m.estado from movimientos_banco m where m.id = mC) = 'pendiente'
                            and not exists (select 1 from horas h where h.id = -1010000002 and h.aprobado_el is not null)
                            and not exists (select 1 from jornal_repartos r where r.movimiento_id = mC)
                       then 'nada cambia' else 'ALGO cambió' end);
      perform pg_temp.c10_ser('editor');
      v_r := pg_temp.c10_aplicar(mC, pg_temp.c10_w1(0), pg_temp.c10_w1(6), '{"motivo": "c10-pruebas: es el cheque de su semana, no el del proveedor"}');
      b := case when v_r->>'estado' = 'aplicado'
                     and (select r.origen || '/' || r.por from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid) = 'mano/edgar'
                then 'entra, a mano y por lo que dijo Edgar' else left(v_r::text, 200) end;
      v_obt := format('%s | el cheque que puede ser otro ya apuntado en el libro: %s; con su motivo: %s', v_obt, a, b);
    end if;
    if v_no is not null then
      v_obt := format('omitida: lo del cheque no se puede ver hoy (%s); lo demás: %s', v_no, v_obt);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (69, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 70. CADA AVISO QUE LO FRENA (c): TODOS, MENOS LOS QUE NO PIDEN NADA. La
--     lista es de lo que NO frena, no de lo que frena: un aviso que se añada
--     mañana a la propuesta frena también. Con un pago que entra solo y su
--     cálculo de verdad, se le pone UNO a uno cada aviso que la propuesta
--     sabe dar (leídos de su código: nadie los copia aquí a mano) y uno que
--     no existe todavía: frenan todos menos el corte de mes, el de año, el
--     devengo estándar cuando el c3 de la base lo pone al día solo y —la
--     revisión del 15-nov— la obra terminada, no aprobada o sin aprobar (su
--     parte va a esa obra igual: no piden adivinar nada). Y lo que
--     la propuesta no mira y un «Así es» sin Edgar delante sí debe mirar: lo
--     que no se puede aplicar aunque ningún aviso lo diga; LA SEMANA QUE
--     PAGA SIN TERMINAR (no pregunta: espera, y dice qué lunes entra); LA
--     SEMANA ANTERIOR SIN PAGO cuando el pago, por su día, pagaría la semana
--     en curso; y LA PERSONA QUE YA COBRA POR NÓMINA (una nómina le pagó
--     horas en 90 días; si pagó las de ESTE reparto, lo dice el aviso de la
--     propuesta y no dos veces).
do $$
declare
  v_obt text; v_j jsonb; v_f jsonb; mA uuid; a text; b text; c text; d text; e text; v_n int; v_si text; v_no text; r record;
  v_hoy date := pg_temp.c10('hoy')::date; v_om text;
  v_nom text := 'CADA AVISO QUE LO FRENA (la cuadrilla sola): TODOS menos los que no piden nada. Cada aviso que la propuesta sabe dar (leídos '
                'de su código) y uno que no existe todavía frenan el registro solo, menos el corte de mes, el de año, el devengo que c3 '
                'pone al día solo y la obra terminada, no aprobada o sin aprobar; frena lo que no se puede aplicar; la semana que paga sin terminar ESPERA (y dice qué día entra); la semana '
                'anterior sin pago pregunta; y la persona que ya cobra por nómina pregunta (una sola vez)';
  v_esp text;
begin
  v_esp := format('el pago y su cálculo de verdad: entra | de los 22 avisos que la propuesta sabe dar y uno que no existe todavía, frenan %s: '
                  'todos menos %s | sin poder aplicarse y sin aviso que lo diga: pregunta [no_se_puede] | la semana que paga termina hoy: '
                  'espera [semana_sin_terminar], entra mañana | paga la semana en curso y la anterior tiene horas sin pago: pregunta '
                  '[semana_anterior_sin_pago,semana_sin_terminar] | una nómina le pagó horas de otra semana: pregunta [cobra_por_nomina]; '
                  'las de esta: pregunta [pagadas_por_nomina]',
                  case when pg_temp.c10_c3_aparta() then 18 else 19 end,
                  case when pg_temp.c10_c3_aparta() then 'devengo_estandar, obra_sin_aprobar, obra_terminada, otro_anio, otro_mes'
                       else 'obra_sin_aprobar, obra_terminada, otro_anio, otro_mes (el c3 de esta base no pone el devengo al día solo: '
                            'devengo_estandar también frena)' end);
  if pg_temp.c10_omitir(70, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(70, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w2(0), 'c10-prueba-b', 4);
    perform pg_temp.c10_aparcar();
    mA := pg_temp.c10_cargo('c10-t70-1', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9701');
    perform pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    a := pg_temp.c10_solo(mA);
    v_j := pg_temp.c10_propuesta(mA);
    -- (los avisos de verdad de este cálculo —hoy, a lo más, los del calendario— fuera: se pone uno a uno)
    perform pg_temp.c10_ser('dueno');
    v_n := 0;
    for r in
      select x.c from (select distinct m[1] as c
                         from regexp_matches(pg_get_functiondef('public.fn_jornal_calcular(uuid,date,date,jsonb)'::regprocedure),
                                             $r$'codigo', '([a-z_]+)'$r$, 'g') m
                       union select 'uno_que_no_existe_todavia') x
       order by x.c
    loop
      v_f := fn_jornal_frenos(mA, jsonb_set(v_j, '{avisos}', jsonb_build_array(jsonb_build_object('codigo', r.c, 'corto', 'c10-pruebas', 'texto', 'c10-pruebas: el aviso ' || r.c))));
      v_n := v_n + (r.c <> 'uno_que_no_existe_todavia')::int;
      if v_f->>'estado' = 'pregunta' and v_f->'frenos'->0->>'codigo' = r.c and v_f->>'por_que' = 'c10-pruebas: el aviso ' || r.c then
        v_si := concat_ws(', ', v_si, r.c);
      elsif v_f->>'estado' = 'entra' then
        v_no := concat_ws(', ', v_no, r.c);
      else
        v_no := concat_ws(', ', v_no, r.c || ' (¿' || coalesce(v_f->>'estado', '?') || '?)');
      end if;
    end loop;
    b := format('de los %s avisos que la propuesta sabe dar y uno que no existe todavía, frenan %s: todos menos %s%s', v_n,
                array_length(string_to_array(v_si, ', '), 1), coalesce(v_no, 'NINGUNO'),
                case when pg_temp.c10_c3_aparta() then '' else ' (el c3 de esta base no pone el devengo al día solo: devengo_estandar también frena)' end);
    -- (sin poder aplicarse, y sin un aviso que lo diga)
    v_f := fn_jornal_frenos(mA, jsonb_set(jsonb_set(jsonb_set(v_j, '{avisos}', '[]'), '{puede_aplicar}', 'false'), '{por_que}', '"c10-pruebas: no se puede"'));
    c := format('%s [%s]', v_f->>'estado', (select string_agg(t.f->>'codigo', ',' order by t.o) from jsonb_array_elements(v_f->'frenos') with ordinality t(f, o)));
    -- (la semana que paga termina hoy: espera, y entra mañana)
    v_f := fn_jornal_frenos(mA, jsonb_set(jsonb_set(v_j, '{avisos}', '[]'), '{periodo,hasta}', to_jsonb(v_hoy::text)));
    d := format('%s [%s], entra %s', v_f->>'estado', (select string_agg(t.f->>'codigo', ',' order by t.o) from jsonb_array_elements(v_f->'frenos') with ordinality t(f, o)),
                case when (v_f->>'entra_el')::date = v_hoy + 1 and v_f->>'por_que' like 'Paga la semana %: entra solo el %, con todas sus horas.%' then 'mañana'
                     else coalesce(v_f->>'entra_el', '?') || ' / ' || coalesce(v_f->>'por_que', '') end);
    -- (paga la semana en curso, y la anterior tiene horas suyas sin pago)
    v_f := fn_jornal_frenos(mA, jsonb_set(jsonb_set(jsonb_set(jsonb_set(v_j, '{avisos}', '[]'), '{periodo,hasta}', to_jsonb(v_hoy::text)),
                                                    '{periodo,regla}', '"semana_en_curso"'),
                                          '{periodo,opciones}', jsonb_build_array(jsonb_build_object('regla', 'semana_anterior', 'horas_sin_pago', 8,
                                                                                  'desde', pg_temp.c10_w1(0), 'hasta', pg_temp.c10_w1(6)))));
    e := format('%s [%s]', v_f->>'estado', (select string_agg(t.f->>'codigo', ',' order by t.o) from jsonb_array_elements(v_f->'frenos') with ordinality t(f, o)));
    perform pg_temp.c10_ser('editor');
    v_obt := format('el pago y su cálculo de verdad: %s | %s | sin poder aplicarse y sin aviso que lo diga: %s | la semana que paga termina hoy: '
                    '%s | paga la semana en curso y la anterior tiene horas sin pago: %s', a, b, c, d, e);
    -- (la persona que ya cobra por nómina: la marca de prueba de las 62 a 64)
    begin
      perform pg_temp.c10_marca(array[-1010000002]::bigint[], pg_temp.c10_w2(4));
      a := pg_temp.c10_solo(mA);
      perform pg_temp.c10_marca(array[-1010000001, -1010000002]::bigint[], pg_temp.c10_w2(4));
      b := pg_temp.c10_solo(mA);
      v_obt := format('%s | una nómina le pagó horas de otra semana: %s; las de esta: %s', v_obt, a, b);
    exception when sqlstate 'MXT22' then
      v_om := sqlerrm;
      perform pg_temp.c10_ser('editor');
    end;
    if v_om is not null then
      v_obt := format('omitida: lo de quien ya cobra por nómina no se puede ver en esta base (%s); lo demás: %s', left(v_om, 300), v_obt);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (70, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 71. EL DESHACER QUE NO VUELVE. Un pago que entró solo y que Edgar deshizo
--     («Deshacer», con su motivo) NO vuelve a entrar solo: «Edgar dijo que
--     no». La rutina puede correr cien veces: el pago se queda pendiente en
--     la Bandeja, con ese porqué (cuándo lo deshizo y su motivo). Lo mismo si
--     lo soltó por fuera, des-casándolo en la Bandeja. Vuelve a entrar SOLO
--     si él lo pide («que vuelva a entrar solo»: queda escrito cuándo y quién
--     lo pidió, y se intenta en el momento); y si lo deshace otra vez, otra
--     vez no vuelve. O lo acepta él a mano con su «Así es» (el reparto dice
--     «a mano»). No hay lista aparte que se pueda olvidar: sale de la
--     historia del pago (su reparto deshecho, su casado deshecho), que no se
--     borra.
do $$
declare
  v_obt text; v_r jsonb; v_d jsonb; mA uuid; mB uuid; rA uuid; a text; b text; c text; d text; e text; f text; g text; v_n0 int;
  v_nom text := 'EL DESHACER QUE NO VUELVE (la cuadrilla sola): lo que Edgar deshizo NO vuelve a entrar solo («Edgar dijo que no», con cuándo y '
                'su motivo), por más que la rutina corra; tampoco lo que soltó des-casándolo en la Bandeja; vuelve a entrar solo si él lo '
                'pide (queda escrito, y se intenta en el momento), y deshecho otra vez, otra vez no vuelve; o lo acepta a mano con su «Así es»';
  v_esp text := 'la rutina registra 2: Zzana 200.00, Zzbeto 144.00 | Edgar deshace el de Zzana y la nota lo avisa: no [edgar_dijo_no], con '
                'cuándo y su motivo | la rutina, tres veces: 0, 0, 0; sigue pendiente, con 1 reparto (deshecho) y sin asiento nuevo | el de '
                'Zzbeto, des-casado en la Bandeja: no [edgar_dijo_no,sin_horas,se_pisa,reparto_suelto]; la rutina: 0 | «que vuelva a entrar '
                'solo»: queda escrito quién lo pidió y entra en el momento (origen solo, desde la pantalla) | deshecho otra vez: no '
                '[edgar_dijo_no]; la rutina: 0 | el de Zzbeto, cerrado su reparto y con el «Así es» de Edgar: entra, a mano';
begin
  if pg_temp.c10_omitir(71, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(71, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', pg_temp.c10_w1(1), 'c10-prueba-b', 6);
    perform pg_temp.c10_aparcar();
    mA := pg_temp.c10_cargo('c10-t71-1', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9711');
    mB := pg_temp.c10_cargo('c10-t71-2', pg_temp.c10_ds(), 144.00, 'Zelle payment to ZZBETO C10 PRUEBA 9712');
    v_r := pg_temp.c10_rutina();
    a := 'la rutina registra ' || pg_temp.c10_registrados(v_r, array[mA, mB]);
    -- (a) Edgar deshace el de Zzana
    select r.id into rA from jornal_repartos r where r.movimiento_id = mA and r.estado = 'aplicado';
    v_d := pg_temp.c10_deshacer(rA, 'c10-pruebas: no era de esta semana');
    perform pg_temp.c10_ser('dueno');
    select format('Edgar deshace el de Zzana y %s: %s, %s',
                  case when v_d->>'nota' like '%Este pago ya no vuelve a entrar solo: si lo quieres repartido, acéptalo tú en la Bandeja.' then 'la nota lo avisa' else 'la nota NO lo avisa' end,
                  pg_temp.c10_solo(mA),
                  case when q.solo_por_que like 'Lo deshiciste el % («c10-pruebas: no era de esta semana»): no vuelve a entrar solo.%' then 'con cuándo y su motivo' else 'dice: ' || coalesce(q.solo_por_que, '(nada)') end)
      into b
      from (select pg_temp.c10_ser('dueno')) s, v_jornal_pendientes q where q.movimiento_id = mA;
    perform pg_temp.c10_ser('editor');
    -- (b) la rutina, tres veces
    select count(*) into v_n0 from asientos;
    c := format('%s, %s, %s; %s', pg_temp.c10_registrados(pg_temp.c10_rutina(), array[mA]), pg_temp.c10_registrados(pg_temp.c10_rutina('{"corrio": "banco"}'), array[mA]),
                pg_temp.c10_registrados(pg_temp.c10_rutina(jsonb_build_object('movimiento_id', mA)), array[mA]),
                case when (select m.estado from movimientos_banco m where m.id = mA) = 'pendiente'
                          and (select count(*) || ' ' || min(r.estado) from jornal_repartos r where r.movimiento_id = mA) = '1 deshecho'
                          and (select count(*) from asientos) = v_n0
                     then 'sigue pendiente, con 1 reparto (deshecho) y sin asiento nuevo' else 'ALGO cambió' end);
    -- (c) el de Zzbeto, soltado por fuera: des-casado en la Bandeja
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_descasar(mB, 'c10-pruebas: lo suelto en la Bandeja (se deshace)');
    perform pg_temp.c10_ser('editor');
    d := format('%s; la rutina: %s', pg_temp.c10_solo(mB), pg_temp.c10_registrados(pg_temp.c10_rutina(), array[mA, mB]));
    -- (d) «que vuelva a entrar solo»
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mA, 'solo', true));
    e := case when (v_r->>'registrado')::boolean and v_r->>'dicho' = 'solo'
                   and (select g2.solo_pedido_por::text = pg_temp.c10('dueno') and g2.solo_pedido_el is not null from jornal_pagos g2 where g2.movimiento_id = mA)
                   and (select r.origen || '/' || (r.regla->>'corrio') from jornal_repartos r where r.movimiento_id = mA and r.estado = 'aplicado') = 'solo/pantalla'
              then 'queda escrito quién lo pidió y entra en el momento (origen solo, desde la pantalla)' else 'NO: ' || left(v_r::text, 300) end;
    -- (e) deshecho otra vez: otra vez no vuelve
    select r.id into rA from jornal_repartos r where r.movimiento_id = mA and r.estado = 'aplicado';
    perform pg_temp.c10_deshacer(rA, 'c10-pruebas: tampoco');
    f := format('%s; la rutina: %s', pg_temp.c10_solo(mA), pg_temp.c10_registrados(pg_temp.c10_rutina(), array[mA, mB]));
    -- (f) el de Zzbeto: cerrado su reparto suelto, Edgar lo acepta a mano
    select r.id into rA from jornal_repartos r where r.movimiento_id = mB and r.estado = 'aplicado';
    perform pg_temp.c10_deshacer(rA, 'c10-pruebas: se había des-casado en la Bandeja');
    v_r := pg_temp.c10_aplicar(mB, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    g := case when v_r->>'estado' = 'aplicado' and (select r.origen from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid) = 'mano'
                   and (select r.regla is null from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid)
              then 'entra, a mano' else left(v_r::text, 200) end;
    v_obt := format('%s | %s | la rutina, tres veces: %s | el de Zzbeto, des-casado en la Bandeja: %s | «que vuelva a entrar solo»: %s | deshecho '
                    'otra vez: %s | el de Zzbeto, cerrado su reparto y con el «Así es» de Edgar: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (71, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 72. EL CHEQUE: «QUE ME PREGUNTE». Un cheque llega como «CHECK 1043», sin
--     nombre: la base no lo adivina (no lo reconoce nadie, la rutina no lo
--     toca) y la Bandeja pregunta de quién es (v_jornal_cheques). Edgar
--     elige a la persona y EN ESA MISMA LLAMADA se reparte por sus horas y
--     se registra solo, con las mismas reglas que un Zelle: mano de obra de
--     la cuadrilla (5200) por obra, con ella como tercero; el asiento dice
--     «cheque 1043 · registrado solo (la regla de Edgar)»; y queda escrito de
--     quién era y quién lo dijo (para el 1099 y Costo por obra). EL PATRÓN DE
--     LA PERSONA NO CAMBIA por un cheque. Si algo pide decidir, no entra y
--     lo dice: el cheque queda como la tarjeta de mano de obra de esa
--     persona. Vale también para alguien que no está dado de alta en el
--     jornal; lo dicho se puede quitar (vuelve a preguntar); el dueño no
--     cobra un jornal (MX008); y de un cheque ya resuelto no se dice nada
--     (MX008). Cómo se lee el número de un cheque (fn_jornal_cheque).
do $$
declare
  v_obt text; v_r jsonb; mC1 uuid; mC2 uuid; a text; b text; c text; d text; e text; f text; g text; h text; v_as uuid; v_pat text;
  v_nom text := 'EL CHEQUE (la cuadrilla sola): llega sin nombre, la base no lo adivina y la Bandeja pregunta de quién es; Edgar elige a la '
                'persona y en esa misma llamada se reparte por sus horas y se registra solo (5200 por obra, con ella como tercero; el asiento '
                'dice «cheque N · registrado solo»); queda escrito de quién era y quién lo dijo; el patrón de la persona no cambia; si algo '
                'pide decidir, no entra y queda como su tarjeta; vale para quien no está dado de alta; lo dicho se quita; ni el dueño ni un '
                'cheque ya resuelto (MX008)';
  v_esp text := 'el número: del banco 1043 | de la descripción 1043 y 1043 | cheque sin número: vacío | «TO CHK 7781» y un Zelle: no son cheques '
                '| dos cheques: nadie los reconoce, preguntan de quién son (9721, 9722) y la rutina no los toca | «es de Zzbeto»: se '
                'registra en el momento: 1 1010 -240.00 | 2 5200 240.00 b empleado:p2; el asiento dice «cheque 9721 · registrado solo (la '
                'regla de Edgar)»; el reparto: origen solo, por edgar, desde el cheque, cheque 9721; escrito de quién era y quién lo dijo; '
                'su patrón, el mismo; sus horas, aprobadas; ya no pregunta | el dueño: MX008 | «es de Zzcaro», que no está dada de alta: no '
                'entra y lo dice; queda como su tarjeta: pregunta [sin_tarifa], por edgar, cheque 9722 | quitado lo dicho: vuelve a '
                'preguntar | «es de Zzana»: se registra (Zzana 200.00) | de un cheque ya resuelto: MX008';
begin
  if pg_temp.c10_omitir(72, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(72, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', pg_temp.c10_w1(1), 'c10-prueba-b', 10);
    perform pg_temp.c10_hora(3, 'p3', pg_temp.c10_w1(2), 'c10-prueba-b', 8);
    perform pg_temp.c10_aparcar();
    -- (a) cómo se lee el número de un cheque
    a := format('el número: del banco %s | de la descripción %s y %s | cheque sin número: %s | «TO CHK 7781» y un Zelle: %s',
                fn_jornal_cheque('CHECK', '0001043', 'CHECK'), fn_jornal_cheque('DEBIT', null, 'CHECK 1043'), fn_jornal_cheque(null, '', 'CHK #001043 C10 PRUEBA'),
                case when fn_jornal_cheque('CHECK', null, 'CHECK') = '' then 'vacío' else coalesce(fn_jornal_cheque('CHECK', null, 'CHECK'), 'nulo') end,
                case when fn_jornal_cheque('DEBIT', null, 'ONLINE TRANSFER TO CHK 7781') is null and fn_jornal_cheque('DEBIT', null, 'ZELLE PAYMENT TO ZZANA C10 PRUEBA 9720') is null
                     then 'no son cheques' else 'SALEN como cheques' end);
    mC1 := pg_temp.c10_cargo('c10-t72-1', pg_temp.c10_ds(), 240.00, 'CHECK 9721 C10 PRUEBA');
    mC2 := pg_temp.c10_cargo('c10-t72-2', pg_temp.c10_ds(), 200.00, 'CHECK 9722 C10 PRUEBA');
    -- (el alta sola de las tres; y Zzcaro, de baja y sin patrón: lo que deja «esta persona no cobra por horas»)
    v_r := pg_temp.c10_rutina();
    perform set_config('mx_jornal.escribe', 'jornal_personas', true);
    delete from jornal_personas where usuario_id = pg_temp.c10('p3')::uuid;
    insert into jornal_personas (usuario_id, patron, activa, nota) values (pg_temp.c10('p3')::uuid, '\mSIN-PATRON\M', false, 'c10-pruebas: no cobra por horas (se deshace)');
    perform set_config('mx_jornal.escribe', '', true);
    select j.patron into v_pat from jornal_personas j where j.usuario_id = pg_temp.c10('p2')::uuid;
    -- (b) nadie los reconoce; preguntan; la rutina no los toca
    perform pg_temp.c10_ser('dueno');
    b := format('dos cheques: %s, preguntan de quién son (%s) y %s',
                case when pg_temp.c10_solo(mC1) = 'no reconocido' and pg_temp.c10_solo(mC2) = 'no reconocido' then 'nadie los reconoce' else 'ALGUIEN los reconoce' end,
                (select string_agg(q.cheque, ', ' order by q.cheque) from (select pg_temp.c10_ser('dueno')) s, v_jornal_cheques q where q.movimiento_id in (mC1, mC2)),
                case when pg_temp.c10_registrados(v_r, array[mC1, mC2]) = '0' and (select count(*) from movimientos_banco m where m.id in (mC1, mC2) and m.estado = 'pendiente') = 2
                     then 'la rutina no los toca' else 'la rutina LOS TOCÓ' end);
    -- (c) «es de Zzbeto»
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC1, 'usuario_id', pg_temp.c10('p2')));
    select r.asiento_id into v_as from jornal_repartos r where r.movimiento_id = mC1 and r.estado = 'aplicado';
    perform pg_temp.c10_ser('dueno');
    c := format('%s: %s; %s; el reparto: %s; %s; su patrón, %s; sus horas, %s; %s',
                case when (v_r->>'registrado')::boolean and v_r->>'dicho' = 'es_de' and v_r->>'persona' = 'Zzbeto C10 PRUEBA' and v_r->>'estado' = 'registrado' then 'se registra en el momento' else 'NO se registra: ' || left(v_r::text, 300) end,
                pg_temp.c10_asiento(v_as),
                case when (select bool_and(l.memo like 'Jornal de Zzbeto C10 PRUEBA · % · cheque 9721 · registrado solo (la regla de Edgar) · %') from asiento_lineas l where l.asiento_id = v_as and l.orden > 1)
                     then 'el asiento dice «cheque 9721 · registrado solo (la regla de Edgar)»' else 'el asiento NO lo dice' end,
                (select format('origen %s, por %s, desde el %s, cheque %s', q.origen, q.por, q.regla->>'corrio', q.cheque) from v_jornal_repartos q where q.movimiento_id = mC1 and q.estado = 'aplicado'),
                case when (select g2.usuario_id::text = pg_temp.c10('p2') and g2.dicho_por::text = pg_temp.c10('dueno') and g2.dicho_el is not null and not g2.no_cuadrilla
                             from jornal_pagos g2 where g2.movimiento_id = mC1)
                          and (select r.usuario_id::text = pg_temp.c10('p2') from jornal_repartos r where r.movimiento_id = mC1 and r.estado = 'aplicado')
                     then 'escrito de quién era y quién lo dijo' else 'NO quedó escrito' end,
                case when (select j.patron = v_pat and j.alta = 'sola' from jornal_personas j where j.usuario_id = pg_temp.c10('p2')::uuid) then 'el mismo' else 'CAMBIÓ' end,
                case when (select h.aprobado_el is not null from horas h where h.id = -1010000002) then 'aprobadas' else 'SIN aprobar' end,
                case when not exists (select 1 from v_jornal_cheques q where q.movimiento_id = mC1) then 'ya no pregunta' else 'SIGUE preguntando' end);
    perform pg_temp.c10_ser('editor');
    -- (d) el dueño no cobra un jornal
    begin
      perform pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC2, 'usuario_id', pg_temp.c10('dueno')));
      d := 'lo acepta';
    exception when others then
      d := sqlstate || case when sqlerrm like '%es el dueño: no cobra un jornal%' then '' else ' (' || sqlerrm || ')' end;
      perform pg_temp.c10_ser('editor');
    end;
    -- (e) «es de Zzcaro», que no está dada de alta (y no tiene tarifa): no entra, y queda como su tarjeta
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC2, 'usuario_id', pg_temp.c10('p3')));
    perform pg_temp.c10_ser('dueno');
    e := format('%s; queda como su tarjeta: %s',
                case when not (v_r->>'registrado')::boolean and v_r->>'estado' = 'pregunta'
                          and v_r->>'nota' like 'Anotado: este pago es de Zzcaro C10 PRUEBA. No entró solo: %no tiene tarifa en Costos del equipo%' then 'no entra y lo dice' else 'MAL: ' || left(v_r::text, 300) end,
                (select format('%s, por %s, cheque %s', pg_temp.c10_solo(mC2), q.por, q.cheque)
                   from (select pg_temp.c10_ser('dueno')) s, v_jornal_pendientes q where q.movimiento_id = mC2 and q.persona = 'Zzcaro C10 PRUEBA'));
    -- (f) quitado lo dicho: vuelve a preguntar
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC2, 'quitar', true));
    perform pg_temp.c10_ser('dueno');
    f := case when v_r->>'dicho' = 'quitado' and exists (select 1 from v_jornal_cheques q where q.movimiento_id = mC2)
                   and not exists (select 1 from v_jornal_pendientes q where q.movimiento_id = mC2) then 'vuelve a preguntar' else 'NO vuelve a preguntar' end;
    -- (g) «es de Zzana»: se registra
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC2, 'usuario_id', pg_temp.c10('p1')));
    g := case when (v_r->>'registrado')::boolean then 'se registra (' || split_part(v_r->>'persona', ' ', 1) || ' ' || (v_r->'reparto'->>'monto') || ')' else 'NO: ' || left(v_r::text, 300) end;
    -- (h) de un cheque ya resuelto no se dice nada
    begin
      perform pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC2, 'no_cuadrilla', true));
      h := 'lo acepta';
    exception when others then
      h := sqlstate || case when sqlerrm like 'Ese movimiento ya está resuelto en el banco%' then '' else ' (' || sqlerrm || ')' end;
      perform pg_temp.c10_ser('editor');
    end;
    v_obt := format('%s | %s | «es de Zzbeto»: %s | el dueño: %s | «es de Zzcaro», que no está dada de alta: %s | quitado lo dicho: %s | «es de '
                    'Zzana»: %s | de un cheque ya resuelto: %s', a, b, c, d, e, f, g, h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (72, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 73. «NO ES DE LA CUADRILLA». La otra respuesta a la pregunta del cheque, y
--     el «No es mano de obra» de la tarjeta de un Zelle reconocido: queda
--     escrito (quién lo dijo y cuándo), el cheque deja de preguntar, el
--     Zelle deja de reconocerse aunque el banco escriba el nombre de alguien
--     de la cuadrilla, la rutina no lo toca, y el pago se queda en la Bandeja
--     para clasificarlo como siempre. Clasificado así, el aviso de «un pago
--     de la cuadrilla resuelto por fuera» (el 70) no lo cuenta: lo dijo
--     Edgar. Lo dicho se quita (vuelve a reconocerse y entra solo). Se dice
--     UNA cosa por llamada; un abono no es un pago a nadie (MX008); solo el
--     dueño.
do $$
declare
  v_obt text; v_r jsonb; v_j jsonb; mC uuid; mZ uuid; mY uuid; mAb uuid; a text; b text; c text; d text; e text; f text; g text;
  v_nom text := '«NO ES DE LA CUADRILLA» (la cuadrilla sola): queda escrito quién lo dijo; el cheque deja de preguntar y el Zelle reconocido '
                'deja de reconocerse; la rutina no lo toca y se queda en la Bandeja para clasificarlo como siempre; clasificado así, el '
                'aviso de los pagos resueltos por fuera no lo cuenta; lo dicho se quita y vuelve a entrar solo; una cosa por llamada, un '
                'abono no (MX008) y solo el dueño';
  v_esp text := 'el cheque: queda escrito quién lo dijo, deja de preguntar y sigue pendiente | el Zelle reconocido (entra): dicho «no es mano '
                'de obra», no se reconoce, la propuesta dice por qué, y la rutina no lo toca: 0 | clasificado en la Bandeja como siempre: '
                'el aviso de los pagos resueltos por fuera no lo cuenta; sin haberlo dicho, sí | quitado lo dicho: entra, y la rutina lo '
                'registra: 1: Zzana 210.00 | dos cosas a la vez: 22023; una clave desconocida: 22023; sin decir nada: 22023 | un abono: '
                'MX008 | Zzbeto por la API: 42501; anon: 42501';
begin
  if pg_temp.c10_omitir(73, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(73, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_aparcar();
    mC := pg_temp.c10_cargo('c10-t73-1', pg_temp.c10_ds(), 300.00, 'CHECK 9731 C10 PRUEBA');
    mZ := pg_temp.c10_cargo('c10-t73-2', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9732');
    mY := pg_temp.c10_cargo('c10-t73-3', pg_temp.c10_ds(), 210.00, 'Zelle payment to ZZANA C10 PRUEBA 9733');
    mAb := pg_temp.c10_cargo('c10-t73-4', pg_temp.c10_ds(), -50.00, 'Zelle payment from ZZANA C10 PRUEBA 9734');
    perform pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    -- (a) el cheque
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC, 'no_cuadrilla', true));
    perform pg_temp.c10_ser('dueno');
    a := format('%s, %s y %s',
                case when v_r->>'dicho' = 'no_cuadrilla' and v_r->>'nota' like 'Anotado: este pago no es de la cuadrilla.%'
                          and (select g2.no_cuadrilla and g2.usuario_id is null and g2.dicho_por::text = pg_temp.c10('dueno') and g2.dicho_el is not null
                                 from jornal_pagos g2 where g2.movimiento_id = mC)
                     then 'queda escrito quién lo dijo' else 'NO queda escrito: ' || left(v_r::text, 200) end,
                case when not exists (select 1 from v_jornal_cheques q where q.movimiento_id = mC) then 'deja de preguntar' else 'SIGUE preguntando' end,
                case when (select m.estado from movimientos_banco m where m.id = mC) = 'pendiente' then 'sigue pendiente' else 'YA NO está pendiente' end);
    perform pg_temp.c10_ser('editor');
    -- (b) el Zelle reconocido: «No es mano de obra»
    b := pg_temp.c10_solo(mZ);
    perform pg_temp.c10_dice(jsonb_build_object('movimiento_id', mZ, 'no_cuadrilla', true));
    perform pg_temp.c10_dice(jsonb_build_object('movimiento_id', mY, 'no_cuadrilla', true));
    v_j := pg_temp.c10_propuesta(mZ);
    b := format('el Zelle reconocido (%s): dicho «no es mano de obra», %s, %s, y la rutina no lo toca: %s', b,
                case when pg_temp.c10_solo(mZ) = 'no reconocido' and not (v_j->>'reconocido')::boolean and (v_j->>'no_cuadrilla')::boolean then 'no se reconoce' else 'SE RECONOCE' end,
                case when v_j->>'por_que' like 'Dijiste que este pago no es de la cuadrilla%se clasifica en la Bandeja como siempre%' then 'la propuesta dice por qué' else 'la propuesta dice: ' || coalesce(v_j->>'por_que', '(nada)') end,
                pg_temp.c10_registrados(pg_temp.c10_rutina(), array[mC, mZ, mY]));
    -- (c) clasificado en la Bandeja como siempre: el 70 no lo cuenta (lo dijo Edgar); sin haberlo dicho, sí
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_clasificar(mZ, '[{"cuenta": "5200", "proyecto_id": "c10-prueba-a"}]'::jsonb, 'c10-pruebas: no es de la cuadrilla, clasificado a mano');
    c := case when not exists (select 1 from fn_jornal_fuera() x where x.movimiento_id = mZ) then 'no lo cuenta' else 'LO CUENTA' end;
    begin
      perform fn_jornal_pago(jsonb_build_object('movimiento_id', mY, 'quitar', true));
      perform fn_banco_clasificar(mY, '[{"cuenta": "5200", "proyecto_id": "c10-prueba-a"}]'::jsonb, 'c10-pruebas: clasificado a mano, sin decir nada');
      c := c || '; sin haberlo dicho, ' || case when exists (select 1 from fn_jornal_fuera() x where x.movimiento_id = mY) then 'sí' else 'TAMPOCO' end;
      raise exception using errcode = 'MXT01';
    exception when sqlstate 'MXT01' then null;
    end;
    perform pg_temp.c10_ser('editor');
    -- (d) quitado lo dicho: vuelve a reconocerse, y entra solo
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mY, 'quitar', true));
    d := format('%s, y la rutina lo registra: %s', pg_temp.c10_solo(mY), pg_temp.c10_registrados(pg_temp.c10_rutina(), array[mC, mZ, mY]));
    -- (e) una cosa por llamada
    perform pg_temp.c10_ser('dueno');
    begin perform fn_jornal_pago(jsonb_build_object('movimiento_id', mC, 'usuario_id', pg_temp.c10('p1'), 'no_cuadrilla', true)); e := 'lo acepta';
    exception when others then e := sqlstate; end;
    begin perform fn_jornal_pago(jsonb_build_object('movimiento_id', mC, 'obra', 'c10-prueba-a')); e := e || '; una clave desconocida: lo acepta';
    exception when others then e := e || '; una clave desconocida: ' || sqlstate; end;
    begin perform fn_jornal_pago(jsonb_build_object('movimiento_id', mC)); e := e || '; sin decir nada: lo acepta';
    exception when others then e := e || '; sin decir nada: ' || sqlstate; end;
    -- (f) un abono
    begin perform fn_jornal_pago(jsonb_build_object('movimiento_id', mAb, 'no_cuadrilla', true)); f := 'lo acepta';
    exception when others then f := sqlstate || case when sqlerrm like 'Es un abono%' then '' else ' (' || sqlerrm || ')' end; end;
    -- (g) solo el dueño
    perform pg_temp.c10_ser('p2');
    begin perform fn_jornal_pago(jsonb_build_object('movimiento_id', mC, 'quitar', true)); g := 'lo acepta';
    exception when others then g := sqlstate; end;
    perform pg_temp.c10_ser('anon');
    begin perform fn_jornal_pago(jsonb_build_object('movimiento_id', mC, 'quitar', true)); g := g || '; anon: lo acepta';
    exception when others then g := g || '; anon: ' || sqlstate; end;
    perform pg_temp.c10_ser('editor');
    v_obt := format('el cheque: %s | %s | clasificado en la Bandeja como siempre: el aviso de los pagos resueltos por fuera %s | quitado lo '
                    'dicho: %s | dos cosas a la vez: %s | un abono: %s | Zzbeto por la API: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (73, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 74. LOS DOS TELÉFONOS, lo que se puede ver en una sola sesión (lo de
--     verdad a la vez —dos sesiones llamando a la rutina en el mismo
--     instante— lo corre pruebas/conta/c10-concurrencia.sh). Un pago, UN
--     reparto vivo, entre por donde entre:
--       · la corrida toma su candado (una a la vez) y el de cada persona, en
--         orden: un «Así es», un «Deshacer» o un alta de otra pestaña esperan;
--       · Edgar tenía abierta la tarjeta de un pago en un teléfono y, mientras,
--         el otro abrió Contabilidad y la rutina lo registró: su «Así es» (con
--         la huella que vio) falla limpio (MX008: ya está repartido) y nada se
--         dobla; la rutina otra vez, entera o para ese pago, no hace nada;
--       · un cheque: un teléfono dice «es de Zzcaro» (entra) y el otro, que
--         aún enseñaba la pregunta, dice «es de Zzana» o «no es de la
--         cuadrilla»: MX008 (ya está resuelto), y sigue siendo de Zzcaro;
--       · al revés: aceptado a mano en un teléfono, la rutina del otro no lo
--         toca.
do $$
declare
  v_obt text; v_r jsonb; v_j jsonb; mA uuid; mB uuid; mC uuid; mD uuid; a text; b text; c text; d text; e text; f text; v_n0 int;
  v_nom text := 'LOS DOS TELÉFONOS en una sesión (la cuadrilla sola; a la vez de verdad: c10-concurrencia.sh): un pago, un reparto vivo. La '
                'corrida toma su candado y el de cada persona; el «Así es» de un pago que la rutina acaba de registrar falla limpio (MX008) '
                'y nada se dobla; la rutina otra vez no hace nada; el cheque que un teléfono ya resolvió no acepta otra respuesta del otro '
                '(MX008); y lo aceptado a mano no lo toca la rutina';
  v_esp text := 'un teléfono abre la tarjeta; el otro abre Contabilidad y la rutina registra 2: Zzana 200.00, Zzbeto 144.00, con su candado y '
                'el de las 3 personas | el «Así es» del primero, con lo que vio: MX008 (ya está repartido), y nada se dobla | la rutina otra '
                'vez, entera y para ese pago: 0 y 0 | el cheque: «es de Zzcaro» entra; desde el otro, «es de Zzana»: MX008 y «no es de la '
                'cuadrilla»: MX008; sigue siendo de Zzcaro | aceptado a mano en un teléfono (con otras fechas); la rutina del otro: 0 | '
                'cada uno de los 4 pagos, 1 reparto vivo y 1 asiento; control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(74, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(74, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    insert into costos_equipo (usuario_id, costo_hora) values (pg_temp.c10('p3')::uuid, 20);
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', pg_temp.c10_w1(1), 'c10-prueba-b', 6);
    perform pg_temp.c10_hora(3, 'p3', pg_temp.c10_w1(2), 'c10-prueba-b', 5);
    perform pg_temp.c10_hora(4, 'p2', pg_temp.c10_w2(1), 'c10-prueba-a', 4);
    perform pg_temp.c10_aparcar();
    mA := pg_temp.c10_cargo('c10-t74-1', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9741');
    mB := pg_temp.c10_cargo('c10-t74-2', pg_temp.c10_ds(), 144.00, 'Zelle payment to ZZBETO C10 PRUEBA 9742');
    mC := pg_temp.c10_cargo('c10-t74-3', pg_temp.c10_ds(), 100.00, 'CHECK 9743 C10 PRUEBA');
    perform pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    -- (a) un teléfono abre la tarjeta del pago de Zzana (se queda con su huella); el otro abre Contabilidad
    v_j := pg_temp.c10_propuesta(mA);
    v_r := pg_temp.c10_rutina();
    a := format('un teléfono abre la tarjeta; el otro abre Contabilidad y la rutina registra %s, %s', pg_temp.c10_registrados(v_r, array[mA, mB, mC]),
                case when exists (select 1 from pg_locks l where l.pid = pg_backend_pid() and l.locktype = 'advisory' and l.granted
                                     and l.classid = 820261115 and l.objid = hashtext('jornal:solo')::oid)
                     then format('con su candado y el de las %s personas',
                                 (select count(*) from pg_locks l where l.pid = pg_backend_pid() and l.locktype = 'advisory' and l.granted and l.classid = 820261109
                                     and l.objid in (hashtext('jornal:' || pg_temp.c10('p1'))::oid, hashtext('jornal:' || pg_temp.c10('p2'))::oid,
                                                     hashtext('jornal:' || pg_temp.c10('p3'))::oid)))
                     else 'SIN su candado' end);
    -- (b) el «Así es» del primero, con la huella que vio
    select count(*) into v_n0 from asientos;
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_jornal_aplicar(mA, (v_j->'periodo'->>'desde')::date, (v_j->'periodo'->>'hasta')::date, v_j->>'visto');
      b := 'ENTRÓ otra vez';
    exception when others then
      b := sqlstate || case when sqlerrm ~ 'ya (está|se) repart' then ' (ya está repartido)' else ' (' || left(sqlerrm, 160) || ')' end;
    end;
    perform pg_temp.c10_ser('editor');
    b := b || case when (select count(*) from asientos) = v_n0 and (select count(*) from jornal_repartos r where r.movimiento_id = mA) = 1
                   then ', y nada se dobla' else ', y ALGO se dobló' end;
    -- (c) la rutina otra vez
    c := format('%s y %s', pg_temp.c10_registrados(pg_temp.c10_rutina(), array[mA, mB, mC]),
                pg_temp.c10_registrados(pg_temp.c10_rutina(jsonb_build_object('movimiento_id', mA)), array[mA, mB, mC]));
    -- (d) el cheque: una respuesta desde cada teléfono
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC, 'usuario_id', pg_temp.c10('p3')));
    d := '«es de Zzcaro» ' || case when (v_r->>'registrado')::boolean then 'entra' else 'NO entra: ' || left(v_r::text, 200) end;
    begin
      perform pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC, 'usuario_id', pg_temp.c10('p1')));
      d := d || '; desde el otro, «es de Zzana»: LO ACEPTA';
    exception when others then
      d := d || '; desde el otro, «es de Zzana»: ' || sqlstate;
      perform pg_temp.c10_ser('editor');
    end;
    begin
      perform pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC, 'no_cuadrilla', true));
      d := d || ' y «no es de la cuadrilla»: LO ACEPTA';
    exception when others then
      d := d || ' y «no es de la cuadrilla»: ' || sqlstate;
      perform pg_temp.c10_ser('editor');
    end;
    d := d || case when (select g2.usuario_id::text = pg_temp.c10('p3') and not g2.no_cuadrilla from jornal_pagos g2 where g2.movimiento_id = mC)
                        and (select r.usuario_id::text = pg_temp.c10('p3') from jornal_repartos r where r.movimiento_id = mC and r.estado = 'aplicado')
                   then '; sigue siendo de Zzcaro' else '; YA NO es de Zzcaro' end;
    -- (e) al revés: aceptado a mano en un teléfono (las horas de la semana de antes), y la rutina del otro
    mD := pg_temp.c10_cargo('c10-t74-4', pg_temp.c10_ds(), 96.00, 'Zelle payment to ZZBETO C10 PRUEBA 9744');
    v_r := pg_temp.c10_aplicar(mD, pg_temp.c10_w2(0), pg_temp.c10_w2(6));
    e := format('%s; la rutina del otro: %s',
                case when v_r->>'estado' = 'aplicado' and (select r.origen from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid) = 'mano'
                     then 'aceptado a mano en un teléfono (con otras fechas)' else 'NO se aceptó: ' || left(v_r::text, 200) end,
                pg_temp.c10_registrados(pg_temp.c10_rutina(), array[mA, mB, mC, mD]));
    f := format('%s; %s',
                case when (select count(*) from jornal_repartos r where r.movimiento_id in (mA, mB, mC, mD) and r.estado = 'aplicado') = 4
                          and (select count(*) from jornal_repartos r where r.movimiento_id in (mA, mB, mC, mD)) = 4
                          and (select count(distinct r.asiento_id) from jornal_repartos r where r.movimiento_id in (mA, mB, mC, mD)) = 4
                          and (select count(*) from movimientos_banco m where m.id in (mA, mB, mC, mD) and m.estado = 'casado') = 4
                     then 'cada uno de los 4 pagos, 1 reparto vivo y 1 asiento' else 'los repartos NO cuadran' end, pg_temp.c10_propios());
    v_obt := format('%s | el «Así es» del primero, con lo que vio: %s | la rutina otra vez, entera y para ese pago: %s | el cheque: %s | %s | %s',
                    a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (74, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 75. LA IA (c8) NO PROPONE UNA SOLA OBRA PARA UN PAGO A LA CUADRILLA. La IA
--     sigue sin postear nunca; registrar solo es una regla de la base. Pero
--     su rutina propone para todo lo que espera en la Bandeja, y a un pago a
--     la cuadrilla le propone UNA obra. Cuando ese pago se registra solo
--     (repartido entre sus obras), su propuesta ya no vale:
--       · con la pantalla delante, la rutina (y la respuesta de un cheque) la
--         DEVUELVE para que la pantalla la cierre por la función de borde
--         (c10 no escribe en c8), y el control 80 la enseña mientras tanto;
--       · sin pantalla (la tarea de madrugada), se cierra por la puerta de
--         c8: la pendiente queda RECHAZADA y la aprobada cuyo asiento ya no
--         vive (Edgar la aceptó y después des-casó el pago), CADUCADA, las
--         dos con su porqué; c8 no queda con ningún cuadre nuevo en rojo.
--     La de un pago que todavía ESPERA una respuesta no se toca (si se
--     cerrara, la IA volvería a proponer —y a gastar— en su próxima vuelta):
--     la propuesta del jornal la trae, y la pantalla no la enseña.
do $$
declare
  v_obt text; v_r jsonb; v_j jsonb; v_u jsonb; mA uuid; mB uuid; mC uuid; mD uuid; pA uuid; pB uuid; pC uuid; pD uuid; v_c0 text[]; v_c1 text[];
  a text; b text; c text; d text; e text; f text;
  v_nom text := 'LA IA (c8) y la cuadrilla sola: la IA sigue sin postear; la propuesta de la IA (una sola obra) de un pago que se registra '
                'solo ya no vale: con pantalla, la rutina y la respuesta del cheque la devuelven para que la pantalla la cierre (c10 no '
                'escribe en c8) y el control 80 la enseña; sin pantalla, la tarea la cierra por la puerta de c8 (la pendiente, rechazada; la '
                'aprobada sin asiento vivo, caducada), con su porqué y sin cuadres nuevos en c8; la de un pago que espera no se toca';
  v_esp text := 'con pantalla: la rutina registra 1: Zzana 200.00 y devuelve su propuesta de la IA (pendiente → rechazar), que sigue pendiente '
                'en c8; el 80 la enseña | el cheque «es de Zzcaro»: se registra y devuelve la suya (pendiente → rechazar) | el pago que c8 '
                'había clasificado y Edgar des-casó: «que vuelva a entrar solo» lo registra y devuelve la suya (sin_asiento → caducar) | sin '
                'pantalla: la tarea cierra 3 por la puerta de c8: rechazada, rechazada y caducada, con su porqué (mano de obra de la '
                'cuadrilla); el 80 verde; c8 sin cuadres nuevos | la del pago que espera una respuesta: sigue pendiente, y la propuesta '
                'del jornal la trae (pendiente → rechazar)';
begin
  if pg_temp.c10('hay_c8') <> 'true' then
    insert into _pruebas values (75, v_nom, v_esp, 'omitida: c8 no está en esta base', null);
    return;
  end if;
  if pg_temp.c10_omitir(75, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(75, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(75, v_nom, v_esp, 'jornal', array[80]) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    insert into costos_equipo (usuario_id, costo_hora) values (pg_temp.c10('p3')::uuid, 20);
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', pg_temp.c10_w1(1), 'c10-prueba-b', 6);
    perform pg_temp.c10_hora(3, 'p3', pg_temp.c10_w1(2), 'c10-prueba-b', 5);
    perform pg_temp.c10_aparcar();
    mA := pg_temp.c10_cargo('c10-t75-1', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9751');
    mB := pg_temp.c10_cargo('c10-t75-2', pg_temp.c10_ds(), 144.00, 'Zelle payment to ZZBETO C10 PRUEBA 9752');
    mC := pg_temp.c10_cargo('c10-t75-3', pg_temp.c10_ds(), 100.00, 'CHECK 9753 C10 PRUEBA');
    mD := pg_temp.c10_cargo('c10-t75-4', pg_temp.c10_ds(), 400.00, 'Zelle payment to ZZANA C10 PRUEBA 9754');
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_c0;
    -- (la propuesta de la IA de cada uno, como la deja su rutina: una sola obra)
    execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta)
                values ($1, 'edgar', '{"lineas": [{"cuenta": "5200", "proyecto_id": "c10-prueba-b"}], "motivo": "C10 PRUEBA", "confianza": 1, "flags": {}}'::jsonb)
                returning id $q$ into pA using mA;
    execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta)
                values ($1, 'edgar', '{"lineas": [{"cuenta": "5200", "proyecto_id": "c10-prueba-b"}], "motivo": "C10 PRUEBA", "confianza": 1, "flags": {}}'::jsonb)
                returning id $q$ into pB using mB;
    execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta)
                values ($1, 'edgar', '{"lineas": [{"cuenta": "5200", "proyecto_id": "c10-prueba-b"}], "motivo": "C10 PRUEBA", "confianza": 1, "flags": {}}'::jsonb)
                returning id $q$ into pC using mC;
    execute $q$ insert into public.contador_propuestas (movimiento_id, fuente, propuesta)
                values ($1, 'edgar', '{"lineas": [{"cuenta": "5200", "proyecto_id": "c10-prueba-b"}], "motivo": "C10 PRUEBA", "confianza": 1, "flags": {}}'::jsonb)
                returning id $q$ into pD using mD;
    -- (el de Zzbeto: Edgar había aceptado la propuesta de la IA —entero a una obra— y después lo des-casó para repartirlo por horas)
    execute 'select public.fn_contador_aprobar($1, $2, null, false)' using pB, pg_temp.c10('dueno')::uuid;
    perform pg_temp.c10_ser('dueno');
    perform fn_banco_descasar(mB, 'c10-pruebas: es mano de obra, va por sus horas');
    perform pg_temp.c10_ser('editor');
    perform pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    -- (a) con pantalla: la rutina registra el de Zzana y devuelve su propuesta; c10 no la toca
    v_r := pg_temp.c10_rutina(jsonb_build_object('movimiento_id', mA));
    execute 'select estado from public.contador_propuestas where id = $1' into a using pA;
    b := pg_temp.c10_jc(80);
    a := format('la rutina registra %s y %s, que sigue %s en c8; %s', pg_temp.c10_registrados(v_r, array[mA, mB, mC, mD]),
                case when jsonb_array_length(v_r->'propuestas_ia') = 1 and (v_r->'propuestas_ia'->0->>'propuesta_id')::uuid = pA
                     then format('devuelve su propuesta de la IA (%s → %s)', v_r->'propuestas_ia'->0->>'clase', v_r->'propuestas_ia'->0->>'que_hacer')
                     else 'devuelve ' || (v_r->'propuestas_ia')::text end, a,
                case when b like 'rojo: el pago del ' || pg_temp.c10_ds() || ' a Zzana C10 PRUEBA ($200.00): su propuesta de la IA sigue pendiente%' then 'el 80 la enseña' else 'el 80: ' || b end);
    -- (b) el cheque: la respuesta de Edgar la devuelve también
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC, 'usuario_id', pg_temp.c10('p3')));
    b := case when (v_r->>'registrado')::boolean and jsonb_array_length(v_r->'propuestas_ia') = 1 and (v_r->'propuestas_ia'->0->>'propuesta_id')::uuid = pC
              then format('se registra y devuelve la suya (%s → %s)', v_r->'propuestas_ia'->0->>'clase', v_r->'propuestas_ia'->0->>'que_hacer')
              else 'NO: ' || left(v_r::text, 300) end;
    -- (c) el des-casado: «que vuelva a entrar solo»
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mB, 'solo', true));
    c := case when (v_r->>'registrado')::boolean and jsonb_array_length(v_r->'propuestas_ia') = 1 and (v_r->'propuestas_ia'->0->>'propuesta_id')::uuid = pB
              then format('lo registra y devuelve la suya (%s → %s)', v_r->'propuestas_ia'->0->>'clase', v_r->'propuestas_ia'->0->>'que_hacer')
              else 'NO: ' || left(v_r::text, 300) end;
    -- (d) sin pantalla: la tarea las cierra por la puerta de c8, con su porqué
    v_u := fn_jornal_solo_programado();
    execute $q$ select coalesce(array_agg(k.orden::text order by k.orden), '{}') from public.v_contador_control k where k.nivel = 'cuadre' and not k.ok $q$ into v_c1;
    execute $q$ select format('%s, %s y %s, %s',
                         (select p.estado from public.contador_propuestas p where p.id = $1), (select p.estado from public.contador_propuestas p where p.id = $2),
                         (select p.estado from public.contador_propuestas p where p.id = $3),
                         case when (select count(*) from public.contador_propuestas p
                                     where p.id in ($1, $2) and p.motivo_edgar like 'Es mano de obra de la cuadrilla: se registró sola%'
                                       and p.aprobado_por = $4) = 2
                                   and (select p.nota like '%Es mano de obra de la cuadrilla: se registró sola%' from public.contador_propuestas p where p.id = $3)
                              then 'con su porqué (mano de obra de la cuadrilla)' else 'SIN su porqué' end) $q$
       into d using pA, pC, pB, pg_temp.c10('dueno')::uuid;
    d := format('la tarea cierra %s por la puerta de c8: %s; el 80 %s; c8 %s', v_u->>'ia_cerradas', d, pg_temp.c10_jc(80),
                case when pg_temp.c10_nuevos(v_c0, v_c1) = 'ninguno' then 'sin cuadres nuevos' else 'con ' || pg_temp.c10_nuevos(v_c0, v_c1) end);
    -- (e) la del pago que espera una respuesta (la tarifa sale lejos): no se toca
    execute 'select estado from public.contador_propuestas where id = $1' into e using pD;
    v_j := pg_temp.c10_propuesta(mD);
    e := format('sigue %s, y %s', e,
                case when pg_temp.c10_solo(mD) like 'pregunta [%' and jsonb_array_length(v_j->'propuestas_ia') = 1 and (v_j->'propuestas_ia'->0->>'propuesta_id')::uuid = pD
                     then format('la propuesta del jornal la trae (%s → %s)', v_j->'propuestas_ia'->0->>'clase', v_j->'propuestas_ia'->0->>'que_hacer')
                     else 'la propuesta del jornal trae ' || coalesce((v_j->'propuestas_ia')::text, '(nada)') || ' / ' || pg_temp.c10_solo(mD) end);
    v_obt := format('con pantalla: %s | el cheque «es de Zzcaro»: %s | el pago que c8 había clasificado y Edgar des-casó: «que vuelva a entrar '
                    'solo» %s | sin pantalla: %s | la del pago que espera una respuesta: %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (75, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 76. LA RONDA: LA TAREA SIN PANTALLA (fn_jornal_solo_programado). Lo que
--     Plaid trae sola cada madrugada entra sin que Edgar abra la app: la
--     dispara pg_cron (o el SQL Editor), por la API no existe. Corre la misma
--     rutina EN NOMBRE DEL DUEÑO, solo dentro de su transacción (después,
--     nadie): cada reparto dice quién —Edgar, por la regla que eligió—, las
--     horas quedan aprobadas a su nombre, y queda apuntado cómo terminó
--     (jornal_config.solo_ultimo). Lo que no entra solo lo dice el control
--     del jornal (el 85, un aviso) y, por él, la ronda de cada noche del
--     cierre (c9, su fila 171: c9 no se toca). Y NUNCA FALLA HACIA FUERA: si
--     algo se rompe (aquí, sin un dueño activo), no revienta la tarea, no
--     registra nada, y el error queda apuntado y el 85 lo dice.
do $$
declare
  v_obt text; v_u jsonb; mA uuid; mB uuid; a text; b text; c text; d text; rp jornal_repartos; v_n0 int;
  v_nom text := 'LA RONDA, la tarea sin pantalla (la cuadrilla sola): por la API no existe; como pg_cron o el SQL Editor corre la rutina en '
                'nombre del dueño solo dentro de su transacción (el reparto dice quién y por qué regla; las horas, aprobadas a su nombre) y '
                'apunta cómo terminó; lo que no entra solo lo dice el control 85 y, por él, la ronda del cierre (c9, fila 171, sin tocar '
                'c9); y si algo se rompe no falla hacia fuera: no registra nada, el error queda apuntado y el 85 lo dice';
  v_esp text := 'por la API: el dueño 42501, service_role 42501, anon 42501 | como la tarea: registra 1 por 200.00, da de alta a 2 y 1 espera '
                'una respuesta; el reparto: creado por el dueño, origen solo, regla «la cuadrilla, sola» desde la rutina, en nombre del '
                'dueño, elegida de fábrica; las horas, aprobadas a nombre del dueño; queda apuntado cómo terminó; después, sin nadie en la '
                'sesión | el 85, en rojo y de aviso: 1 pago por $300.00 que no entró solo; la ronda del cierre lo lleva '
                'a su fila 171 (un aviso), no a la 170 | sin un dueño activo: no falla hacia fuera, no registra nada, el error queda '
                'apuntado y el 85 lo dice';
begin
  if pg_temp.c10_omitir(76, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(76, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', pg_temp.c10_w1(1), 'c10-prueba-b', 6);
    perform pg_temp.c10_aparcar();
    -- (con lo real aparcado el control 85 cuenta solo lo de esta prueba; si aun así está en rojo, aquí no se puede ver que pase a rojo y vuelva)
    if pg_temp.c10_jc(85) <> 'verde' then
      v_obt := 'omitida: con lo real aparcado, el control 85 del jornal sigue en rojo en esta base (' || left(pg_temp.c10_jc(85), 300)
               || '): aquí no se puede ver que pase a rojo y vuelva';
      raise exception using errcode = 'MXT00';
    end if;
    mA := pg_temp.c10_cargo('c10-t76-1', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9761');
    mB := pg_temp.c10_cargo('c10-t76-2', pg_temp.c10_ds(), 300.00, 'Zelle payment to ZZBETO C10 PRUEBA 9762');
    -- (a) por la API no existe
    perform pg_temp.c10_ser('dueno');
    begin perform fn_jornal_solo_programado(); a := 'el dueño LA EJECUTA'; exception when others then a := 'el dueño ' || sqlstate; end;
    perform pg_temp.c10_ser('service_role');
    begin perform fn_jornal_solo_programado(); a := a || ', service_role LA EJECUTA'; exception when others then a := a || ', service_role ' || sqlstate; end;
    perform pg_temp.c10_ser('anon');
    begin perform fn_jornal_solo_programado(); a := a || ', anon LA EJECUTA'; exception when others then a := a || ', anon ' || sqlstate; end;
    perform pg_temp.c10_ser('editor');
    -- (b) como la tarea (pg_cron o el SQL Editor)
    v_u := fn_jornal_solo_programado();
    select * into rp from jornal_repartos r where r.movimiento_id = mA and r.estado = 'aplicado';
    b := format('registra %s por %s, da de alta a %s y %s espera una respuesta; el reparto: %s; las horas, %s; %s; después, %s',
                v_u->>'registrados', v_u->>'monto', v_u->>'altas', (v_u->>'preguntan')::int + (v_u->>'dijo_no')::int,
                case when rp.id is null then 'NO HAY'
                     else format('creado por %s, origen %s, regla «%s» desde la %s, %s, elegida %s',
                                 case when rp.creado_por::text = pg_temp.c10('dueno') then 'el dueño' else coalesce(rp.creado_por::text, 'NADIE') end, rp.origen,
                                 rp.regla->>'regla', rp.regla->>'corrio',
                                 case when rp.regla->>'en_nombre_de' = pg_temp.c10('dueno') then 'en nombre del dueño' else 'en nombre de ' || coalesce(rp.regla->>'en_nombre_de', 'NADIE') end,
                                 case when rp.regla->>'elegida' like 'de fábrica:%' and rp.regla->'elegida_por' is null then 'de fábrica' else coalesce(rp.regla->>'elegida', '?') end) end,
                case when (select h.aprobado_por::text = pg_temp.c10('dueno') and h.aprobado_el is not null from horas h where h.id = -1010000001)
                     then 'aprobadas a nombre del dueño' else 'SIN aprobar a su nombre' end,
                case when (select c2.solo_ultimo->>'registrados' = '1' and c2.solo_ultimo->>'error' is null and (c2.solo_ultimo->>'el')::timestamptz is not null
                                  and (c2.solo_ultimo - 'el') = (v_u - 'el' - 'encendido')
                             from jornal_config c2 where c2.id = 1)
                     then 'queda apuntado cómo terminó' else 'NO queda apuntado' end,
                case when auth.uid() is null and coalesce(current_setting('request.jwt.claims', true), '') = '' then 'sin nadie en la sesión'
                     else 'la sesión SIGUE como ' || coalesce(auth.uid()::text, '?') end);
    -- (c) lo que no entró solo lo dice el control (85) y, por él, la ronda del cierre (c9: 171)
    c := pg_temp.c10_jc(85);
    c := case when c like 'rojo: 1 pago(s) a la cuadrilla por $300.00 (el más viejo, del ' || fn_jornal_dia(pg_temp.c10_ds(), true) || ') siguen en la Bandeja con la semana '
                           || 'que pagan ya terminada: no entraron solos (algo pide tu respuesta, o los deshiciste antes). → abre la Bandeja:%'
                   and (select k.nivel from v_jornal_control k where k.orden = 85) = 'aviso' and c !~ 'fn_|v_jornal|v_margen|jornal_'
              then 'el 85, en rojo y de aviso: 1 pago por $300.00 que no entró solo' else 'el 85: ' || c end;
    -- (la ronda del cierre no se corre aquí —tarda, y ya la corre la 61—: se mira que su revisión lleve a su fila 171 los avisos de este control)
    c := c || case when to_regprocedure('public.fn_cierre_revisar(text)') is null then '; (c9 no está en esta base)'
                   when pg_get_functiondef('public.fn_cierre_revisar(text)'::regprocedure) ~ 'x\.nivel as n, x\.ok is true as ok, x\.detalle from public\.v_jornal_control x'
                        and pg_get_functiondef('public.fn_cierre_revisar(text)'::regprocedure) ~ 'case when r\.n = ''aviso'' then 171 else 170 end'
                   then '; la ronda del cierre lo lleva a su fila 171 (un aviso), no a la 170'
                   else '; la revisión del cierre de esta base NO lleva los avisos de este control a su fila 171' end;
    -- (d) si algo se rompe (sin un dueño activo): no falla hacia fuera
    select count(*) into v_n0 from jornal_repartos;
    begin
      update perfiles set activo = false where rol = 'dueno';
      v_u := fn_jornal_solo_programado();
      d := format('%s, %s, %s y %s', 'no falla hacia fuera',
                  case when (select count(*) from jornal_repartos) = v_n0 and (v_u->>'registrados')::int = 0 then 'no registra nada' else 'REGISTRÓ algo' end,
                  case when v_u->>'error' like '42501: no hay un dueño activo%' and (select c2.solo_ultimo->>'error' from jornal_config c2 where c2.id = 1) = v_u->>'error'
                       then 'el error queda apuntado' else 'el error: ' || coalesce(v_u->>'error', '(ninguno)') end,
                  case when pg_temp.c10_jc(85) like '%La última corrida sin pantalla (el %) falló: 42501: no hay un dueño activo%→ avisa; mientras, los pagos entran solos al abrir Contabilidad.'
                       then 'el 85 lo dice' else 'el 85 NO lo dice: ' || pg_temp.c10_jc(85) end);
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then d := 'FALLA hacia fuera: ' || sqlstate || ' ' || left(sqlerrm, 200);
    end;
    v_obt := format('por la API: %s | como la tarea: %s | %s | sin un dueño activo: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (76, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 77. EL 1099 (c14) VE LO QUE ENTRÓ SOLO. Lo registrado solo es lo mismo que
--     un «Así es»: cada línea del asiento (menos la del banco) lleva a la
--     persona como tercero, y el cálculo del 1099 lo toma entero como su pago
--     por servicios, por jornal: el Zelle reconocido por su nombre y el
--     cheque del que Edgar dijo de quién era (el banco no trae su nombre:
--     queda escrito en el libro). Deshecho, deja de contar.
do $$
declare
  v_obt text; v_r jsonb; mA uuid; mC uuid; a text; b text; c text; v_anio int; v_as uuid[];
  v_nom text := 'EL 1099 (c14) ve lo que entró solo (la cuadrilla sola): el Zelle registrado solo y el cheque del que Edgar dijo de quién era '
                'cuentan enteros como el pago por servicios de esa persona (por jornal, con ella como tercero); deshecho, deja de contar';
  v_esp text := 'el Zelle de Zzana (solo) y el cheque de Zzbeto («es de…»): registrados | para el 1099: Zzana 2 líneas por jornal y de servicio, '
                '362.50; Zzbeto 1, 240.00 | lo que se le pagó por servicios en el año: Zzana 362.50, Zzbeto 240.00 | deshecho el cheque: '
                'Zzbeto 0.00, Zzana 362.50';
begin
  if to_regprocedure('public.fn_subs_calculo()') is null or to_regprocedure('public.fn_subs_1099(integer)') is null then
    insert into _pruebas values (77, v_nom, v_esp, 'omitida: los subcontratistas y el 1099 (c14) no están en esta base', null);
    return;
  end if;
  if pg_temp.c10_omitir(77, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(77, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-b', 6.5);
    perform pg_temp.c10_hora(3, 'p2', pg_temp.c10_w1(1), 'c10-prueba-b', 10);
    perform pg_temp.c10_aparcar();
    mA := pg_temp.c10_cargo('c10-t77-1', pg_temp.c10_ds(), 362.50, 'Zelle payment to ZZANA C10 PRUEBA 9771');
    mC := pg_temp.c10_cargo('c10-t77-2', pg_temp.c10_ds(), 240.00, 'CHECK 9772 C10 PRUEBA');
    v_r := pg_temp.c10_rutina();
    a := pg_temp.c10_registrados(v_r, array[mA, mC]);
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC, 'usuario_id', pg_temp.c10('p2')));
    a := case when a = '1: Zzana 362.50' and (v_r->>'registrado')::boolean then 'registrados' else 'NO: ' || a || ' / ' || left(v_r::text, 200) end;
    select array_agg(r.asiento_id) into v_as from jornal_repartos r where r.movimiento_id in (mA, mC) and r.estado = 'aplicado';
    -- (el año con que el 1099 los cuenta: el de su fecha, la del libro o la del banco según su ajuste)
    perform pg_temp.c10_ser('dueno');
    select max(x.anio) into v_anio from fn_subs_calculo() x where x.asiento_id = any (v_as);
    select format('Zzana %s líneas por jornal y de servicio, %s; Zzbeto %s, %s',
                  count(*) filter (where x.tercero_id = pg_temp.c10('p1') and x.via = 'jornal' and x.clase = 'servicio' and x.tercero_tipo = 'empleado'),
                  coalesce(sum(x.monto) filter (where x.tercero_id = pg_temp.c10('p1')), 0)::numeric(14,2),
                  count(*) filter (where x.tercero_id = pg_temp.c10('p2') and x.via = 'jornal' and x.clase = 'servicio' and x.tercero_tipo = 'empleado'),
                  coalesce(sum(x.monto) filter (where x.tercero_id = pg_temp.c10('p2')), 0)::numeric(14,2))
      into b
      from fn_subs_calculo() x where x.asiento_id = any (v_as);
    select format('Zzana %s, Zzbeto %s',
                  coalesce(max(x.pagado_servicio) filter (where x.clave = 'empleado:' || pg_temp.c10('p1')), 0)::numeric(14,2),
                  coalesce(max(x.pagado_servicio) filter (where x.clave = 'empleado:' || pg_temp.c10('p2')), 0)::numeric(14,2))
      into c
      from fn_subs_1099(v_anio) x where x.clave in ('empleado:' || pg_temp.c10('p1'), 'empleado:' || pg_temp.c10('p2'));
    perform pg_temp.c10_ser('editor');
    v_obt := format('el Zelle de Zzana (solo) y el cheque de Zzbeto («es de…»): %s | para el 1099: %s | lo que se le pagó por servicios en el año: %s', a, b, c);
    perform pg_temp.c10_deshacer((select r.id from jornal_repartos r where r.movimiento_id = mC and r.estado = 'aplicado'), 'c10-pruebas: el cheque no era suyo');
    perform pg_temp.c10_ser('dueno');
    select format('Zzbeto %s, Zzana %s',
                  coalesce(max(x.pagado_servicio) filter (where x.clave = 'empleado:' || pg_temp.c10('p2')), 0)::numeric(14,2),
                  coalesce(max(x.pagado_servicio) filter (where x.clave = 'empleado:' || pg_temp.c10('p1')), 0)::numeric(14,2))
      into c
      from fn_subs_1099(v_anio) x where x.clave in ('empleado:' || pg_temp.c10('p1'), 'empleado:' || pg_temp.c10('p2'));
    perform pg_temp.c10_ser('editor');
    v_obt := v_obt || ' | deshecho el cheque: ' || c;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (77, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 78. EL DEVENGO DE c3 SIGUE AL DÍA CON LO QUE ENTRA SOLO. El corte de los
--     jornales en el devengo estándar de un mes (c3, Fase 11c: su trigger
--     diferido sobre asientos) vale igual para un pago registrado solo: es
--     el mismo asiento, por la misma puerta. Con el mes del pago ya
--     devengado (las horas de esa semana, aprobadas y a estándar), el Zelle
--     ENTRA SOLO —el aviso del devengo no pide nada: c3 lo pone al día solo—
--     y, al confirmar, el devengo deja de contar las horas que ese pago
--     cubrió (y sigue con las de quien no ha cobrado): nada sale dos veces, y
--     el control del doble (el 50) queda en verde. Deshecho el pago, el
--     devengo vuelve a contarlas. Y lo mismo al confirmar la tarea sin
--     pantalla (el SQL Editor / pg_cron, sin nadie en la sesión). Con un c3 anterior (que no lo pone al día
--     solo) el aviso SÍ frena: pregunta, y nada entra.
--     (Una prueba nunca confirma: aquí se dispara el trigger a mano, como
--     hace c3-pruebas, y se deja como estaba.)
-- (lo que el devengo VIVO de un mes cuenta en las dos obras de la prueba)
create or replace function pg_temp.c10_t78(p_mes text, p_cta text) returns text language sql as $f$
  select format('obra A %s, obra B %s',
                coalesce(sum(l.monto) filter (where l.proyecto_id = 'c10-prueba-a'), 0)::numeric(14,2),
                coalesce(sum(l.monto) filter (where l.proyecto_id = 'c10-prueba-b'), 0)::numeric(14,2))
    from asientos x join asiento_lineas l on l.asiento_id = x.id
   where x.origen_tabla = 'horas_devengo' and x.origen_id = p_mes and x.camino not in ('reverso', 'reverso_automatico')
     and not exists (select 1 from asientos r where r.reversa_a = x.id and r.camino = 'reverso')
     and l.cuenta = p_cta
$f$;
do $$
declare
  v_obt text; v_r jsonb; v_u jsonb; mA uuid; mB uuid; a text; b text; c text; d text; e text; v_dia date; v_mes text; v_dev jsonb; v_no text; v_5000 text;
  v_nom text := 'EL DEVENGO DE c3 sigue al día con lo que entra solo (la cuadrilla sola): con el mes del pago ya devengado, el Zelle entra '
                'solo (el aviso del devengo no pide nada si c3 lo pone al día solo) y, al confirmar, el devengo deja de contar las horas '
                'que ese pago cubrió y sigue con las demás; el control del doble, en verde; también al confirmar la tarea sin pantalla; '
                'deshecho, vuelve a contarlas. Con un c3 anterior, el aviso frena';
  v_esp text;
begin
  v_esp := case when pg_temp.c10_c3_aparta()
                then 'el mes devengado: obra A 200.00, obra B 144.00 | el pago: entra, con el aviso del devengo [devengo_estandar] | la rutina '
                     'registra 1: Zzana 200.00; antes de confirmar el devengo sigue igual: obra A 200.00, obra B 144.00 | al confirmar: obra A '
                     '0.00, obra B 144.00; el control del doble: verde | deshecho, y al confirmar: obra A 200.00, obra B 144.00 | la tarea '
                     'sin pantalla registra 1 (el de Zzbeto), y al confirmar: obra A 200.00, obra B 0.00'
                else 'el mes devengado: obra A 200.00, obra B 144.00 | el pago: pregunta [devengo_estandar] (el c3 de esta base no pone el '
                     'devengo al día solo) | la rutina registra 0' end;
  if pg_temp.c10_omitir(78, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(78, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_rojo(78, v_nom, v_esp, 'jornal', array[50]) then return; end if;
  -- (las horas, en la semana anterior y dentro del mes del pago: el día más temprano de esa semana que cae en ese mes)
  v_mes := to_char(pg_temp.c10_ds(), 'YYYY-MM');
  v_dia := greatest(pg_temp.c10_w1(0), date_trunc('month', pg_temp.c10_ds())::date);
  if v_dia > pg_temp.c10_w1(6) then
    insert into _pruebas values (78, v_nom, v_esp,
      format('omitida: la semana que paga el pago de prueba (%s a %s) cae entera en el mes anterior al del pago (%s): hoy no se puede ver un '
             'jornal pagado dentro del mes devengado; vuelve a pegar este archivo otro día', pg_temp.c10_w1(0), pg_temp.c10_w1(6), v_mes), null);
    return;
  end if;
  begin
    perform pg_temp.c10_sembrar();
    v_5000 := fn_puente_cuenta_de('mano_obra');
    perform pg_temp.c10_hora(1, 'p1', v_dia, 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', v_dia, 'c10-prueba-b', 6);
    begin
      perform pg_temp.c10_ser('dueno');
      perform fn_horas_aprobar(pg_temp.c10('p1')::uuid, v_dia, v_dia, '{"ids": [-1010000001]}'::jsonb);
      perform fn_horas_aprobar(pg_temp.c10('p2')::uuid, v_dia, v_dia, '{"ids": [-1010000002]}'::jsonb);
      perform pg_temp.c10_ser('editor');
      v_dev := pg_temp.c10_devengar(v_mes, array[-1010000001, -1010000002]::bigint[]);
    exception when others then
      v_no := sqlstate || ': ' || sqlerrm;
      perform pg_temp.c10_ser('editor');
    end;
    if v_no is not null then
      v_obt := format('omitida: %s (%s)', case when pg_temp.c10_mes_con_nomina(v_mes) then format('%s tiene nómina y el libro no dejó poner el devengo de la prueba', v_mes)
                                               else format('c3 no dejó devengar %s', v_mes) end, left(v_no, 300));
      raise exception using errcode = 'MXT00';
    end if;
    a := pg_temp.c10_t78(v_mes, v_5000);
    perform pg_temp.c10_aparcar();
    mA := pg_temp.c10_cargo('c10-t78-1', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9781');
    perform pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    b := pg_temp.c10_solo(mA);
    if pg_temp.c10_c3_aparta() then
      b := format('%s, con el aviso del devengo [%s]', b, pg_temp.c10_avisos(pg_temp.c10_propuesta(mA)));
      v_r := pg_temp.c10_rutina();
      c := format('la rutina registra %s; antes de confirmar el devengo sigue igual: %s', pg_temp.c10_registrados(v_r, array[mA]), pg_temp.c10_t78(v_mes, v_5000));
      -- (confirmar, como el dueño por la app: lo que hace el commit)
      perform pg_temp.c10_ser('dueno');
      execute 'set constraints public.trg_puente_asientos_jornal immediate';
      execute 'set constraints public.trg_puente_asientos_jornal deferred';
      perform pg_temp.c10_ser('editor');
      d := format('%s; el control del doble: %s', pg_temp.c10_t78(v_mes, v_5000), pg_temp.c10_jc(50));
      -- (deshecho: el devengo vuelve a contarlas. En «immediate» desde antes: un «Deshacer» lo pone al día en el momento)
      perform pg_temp.c10_ser('dueno');
      execute 'set constraints public.trg_puente_asientos_jornal immediate';
      perform fn_jornal_deshacer((select r.id from jornal_repartos r where r.movimiento_id = mA and r.estado = 'aplicado'), 'c10-pruebas: se deshace para ver el devengo');
      execute 'set constraints public.trg_puente_asientos_jornal deferred';
      perform pg_temp.c10_ser('editor');
      e := pg_temp.c10_t78(v_mes, v_5000);
      -- (la tarea sin pantalla registra el de Zzbeto, y se confirma como ella: el SQL Editor / pg_cron, sin nadie en la sesión)
      mB := pg_temp.c10_cargo('c10-t78-2', pg_temp.c10_ds(), 144.00, 'Zelle payment to ZZBETO C10 PRUEBA 9782');
      v_u := fn_jornal_solo_programado();
      execute 'set constraints public.trg_puente_asientos_jornal immediate';
      execute 'set constraints public.trg_puente_asientos_jornal deferred';
      v_obt := format('el mes devengado: %s | el pago: %s | %s | al confirmar: %s | deshecho, y al confirmar: %s | la tarea sin pantalla registra '
                      '%s (el de Zzbeto), y al confirmar: %s', a, b, c, d, e, v_u->>'registrados', pg_temp.c10_t78(v_mes, v_5000));
    else
      v_r := pg_temp.c10_rutina();
      v_obt := format('el mes devengado: %s | el pago: %s (el c3 de esta base no pone el devengo al día solo) | la rutina registra %s', a, b,
                      pg_temp.c10_registrados(v_r, array[mA]));
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  begin
    execute 'set constraints public.trg_puente_asientos_jornal deferred';
  exception when others then null;
  end;
  insert into _pruebas values (78, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 79. LO APAGADO. El ajuste para apagar lo automático (Costo por obra →
--     Ajustes; de fábrica, ENCENDIDO: lo eligió Edgar). Apagado —queda
--     escrito quién lo apagó y cuándo—, nada entra solo: la rutina no hace
--     nada (ni da de alta a nadie), la tarea sin pantalla tampoco, un pago
--     reconocido espera con ese porqué, y la respuesta de un cheque se anota
--     pero no lo registra. Todo lo demás sigue: el pago se reconoce, la
--     tarjeta se pinta y el «Así es» de Edgar lo reparte a mano, como antes
--     de la v5. El control lo dice. Encendido otra vez, lo que esperaba
--     entra solo, y la regla del reparto dice que la encendió Edgar.
do $$
declare
  v_obt text; v_r jsonb; v_u jsonb; mA uuid; mC uuid; a text; b text; c text; d text; e text; f text; g text; v_ult jsonb; rp jornal_repartos;
  v_nom text := 'LO APAGADO (la cuadrilla sola): el ajuste que apaga lo automático (de fábrica, encendido) deja escrito quién y cuándo; '
                'apagado, la rutina y la tarea sin pantalla no hacen nada, el pago reconocido espera con ese porqué y la respuesta de un '
                'cheque se anota sin registrarlo; el «Así es» a mano sigue como siempre; el control lo dice; encendido otra vez, lo que '
                'esperaba entra solo y la regla dice que la encendió Edgar';
  v_esp text := 'de fábrica: encendido | apagado por Edgar: queda escrito quién y cuándo | la rutina: apagada, no corre, no registra (0) ni da de '
                'alta a nadie, y lo dice | la tarea sin pantalla: apagada, y no apunta nada | el pago reconocido: no [apagado], con su porqué | '
                'el cheque «es de Zzbeto»: anotado, no se registra, y queda como su tarjeta: no [apagado] | el control: en rojo, 2 pagos, y '
                'dice que está apagado | el «Así es» de Edgar: entra, a mano | encendido otra vez: la rutina registra 1: Zzbeto 240.00, y la '
                'regla dice que la encendió Edgar';
begin
  if pg_temp.c10_omitir(79, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(79, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', pg_temp.c10_w1(1), 'c10-prueba-b', 10);
    -- (de fábrica: lo que deja el pegado en una base nueva; aquí se mira el valor por defecto de la columna)
    a := case when (select pg_get_expr(d.adbin, d.adrelid) from pg_attrdef d join pg_attribute t on t.attrelid = d.adrelid and t.attnum = d.adnum
                     where d.adrelid = 'public.jornal_config'::regclass and t.attname = 'solo') = 'true' then 'encendido' else 'APAGADO' end;
    perform pg_temp.c10_aparcar();
    -- (con lo real aparcado el control 85 cuenta solo lo de esta prueba; si aun así está en rojo, aquí no se puede ver que pase a rojo y vuelva)
    if pg_temp.c10_jc(85) <> 'verde' then
      v_obt := 'omitida: con lo real aparcado, el control 85 del jornal sigue en rojo en esta base (' || left(pg_temp.c10_jc(85), 300)
               || '): aquí no se puede ver que pase a rojo y vuelva';
      raise exception using errcode = 'MXT00';
    end if;
    mA := pg_temp.c10_cargo('c10-t79-1', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9791');
    mC := pg_temp.c10_cargo('c10-t79-2', pg_temp.c10_ds(), 240.00, 'CHECK 9792 C10 PRUEBA');
    perform pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    select c2.solo_ultimo into v_ult from jornal_config c2 where c2.id = 1;
    -- (a) Edgar lo apaga
    perform pg_temp.c10_ser('dueno');
    v_r := fn_jornal_config('{"solo": false}');
    perform pg_temp.c10_ser('editor');
    b := case when not (v_r->>'solo')::boolean
                   and (select not c2.solo and c2.solo_por::text = pg_temp.c10('dueno') and c2.solo_el is not null from jornal_config c2 where c2.id = 1)
              then 'queda escrito quién y cuándo' else 'NO queda escrito: ' || left(v_r::text, 200) end;
    -- (b) la rutina: nada (con una persona más con horas, que encendida daría de alta)
    perform pg_temp.c10_hora(3, 'p3', pg_temp.c10_w1(2), 'c10-prueba-b', 5);
    v_r := pg_temp.c10_rutina();
    c := format('%s, %s, no registra (%s) %s, y %s', case when not (v_r->>'encendido')::boolean then 'apagada' else 'ENCENDIDA' end,
                case when not (v_r->>'corrio')::boolean then 'no corre' else 'CORRE' end, pg_temp.c10_registrados(v_r, array[mA, mC]),
                case when jsonb_array_length(v_r->'altas') = 0 and not exists (select 1 from jornal_personas j where j.usuario_id = pg_temp.c10('p3')::uuid)
                     then 'ni da de alta a nadie' else 'y DA DE ALTA' end,
                case when v_r->>'nota' like 'El registro automático de los pagos a la cuadrilla está apagado%' then 'lo dice' else 'NO lo dice' end);
    -- (c) la tarea sin pantalla
    v_u := fn_jornal_solo_programado();
    d := case when v_u = '{"encendido": false}'::jsonb and (select c2.solo_ultimo from jornal_config c2 where c2.id = 1) is not distinct from v_ult
              then 'apagada, y no apunta nada' else 'HIZO algo: ' || left(v_u::text, 200) end;
    -- (d) el pago reconocido, y el cheque
    perform pg_temp.c10_ser('dueno');
    select format('%s, %s', pg_temp.c10_solo(mA),
                  case when q.solo_por_que like 'El registro automático de los pagos a la cuadrilla está apagado (Costo por obra → Ajustes): este pago espera tu «Así es».'
                       then 'con su porqué' else 'dice: ' || coalesce(q.solo_por_que, '(nada)') end)
      into e
      from (select pg_temp.c10_ser('dueno')) s, v_jornal_pendientes q where q.movimiento_id = mA;
    v_r := pg_temp.c10_dice(jsonb_build_object('movimiento_id', mC, 'usuario_id', pg_temp.c10('p2')));
    f := format('%s, y queda como su tarjeta: %s',
                case when not (v_r->>'registrado')::boolean and v_r->>'estado' = 'no'
                          and v_r->>'nota' like 'Anotado: este pago es de Zzbeto C10 PRUEBA. No entró solo: El registro automático de los pagos a la cuadrilla está apagado%'
                          and (select m.estado from movimientos_banco m where m.id = mC) = 'pendiente'
                     then 'anotado, no se registra' else 'MAL: ' || left(v_r::text, 300) end, pg_temp.c10_solo(mC));
    -- (e) el control lo dice
    g := pg_temp.c10_jc(85);
    g := case when g like 'rojo: 2 pago(s) a la cuadrilla por $440.00 (%) siguen en la Bandeja con la semana que pagan ya terminada: el registro automático está apagado (Costo por obra → Ajustes). → %'
              then 'en rojo, 2 pagos, y dice que está apagado' else g end;
    -- (f) el «Así es» de Edgar sigue como siempre
    v_r := pg_temp.c10_aplicar(mA, pg_temp.c10_w1(0), pg_temp.c10_w1(6));
    a := format('de fábrica: %s | apagado por Edgar: %s | la rutina: %s | la tarea sin pantalla: %s | el pago reconocido: %s | el cheque «es de '
                'Zzbeto»: %s | el control: %s | el «Así es» de Edgar: %s', a, b, c, d, e, f, g,
                case when v_r->>'estado' = 'aplicado' and (select r.origen from jornal_repartos r where r.id = (v_r->>'reparto_id')::uuid) = 'mano'
                     then 'entra, a mano' else left(v_r::text, 200) end);
    -- (g) encendido otra vez: lo que esperaba entra solo, y la regla dice quién la encendió
    perform pg_temp.c10_ser('dueno');
    perform fn_jornal_config('{"solo": true}');
    perform pg_temp.c10_ser('editor');
    v_r := pg_temp.c10_rutina();
    select * into rp from jornal_repartos r where r.movimiento_id = mC and r.estado = 'aplicado';
    v_obt := format('%s | encendido otra vez: la rutina registra %s, y %s', a, pg_temp.c10_registrados(v_r, array[mA, mC]),
                    case when rp.regla->>'elegida' = 'la encendió Edgar' and rp.regla->>'elegida_por' = pg_temp.c10('dueno') and rp.regla->>'elegida_el' is not null
                         then 'la regla dice que la encendió Edgar' else 'la regla dice: ' || coalesce(rp.regla::text, '(nada)') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (79, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 80. LA OBRA TERMINADA, NO APROBADA O SIN APROBAR NO FRENA EL REGISTRO SOLO
--     (la revisión del 15-nov-2026; se decidió con la Bandeja de verdad
--     delante). Las obras se terminan DESPUÉS del trabajo: casi todo pago de
--     una semana ya pasada tiene horas en una obra que hoy está terminada, o
--     cuya propuesta sigue «enviado», y con ese aviso de freno no entraba
--     solo casi ninguno. Ese aviso no pide adivinar nada: las horas dicen en
--     qué obra se hizo el trabajo, y su parte va a esa obra igual. Ahora el
--     pago entra solo, y el aviso queda como NOTA: va con lo registrado (lo
--     que la rutina devuelve) y queda escrito en el reparto (lo que enseña
--     «Registrado solo»). LO QUE SÍ PREGUNTA: unas horas con fecha POSTERIOR
--     al día en que su obra se dio por terminada (proyectos.completado_el: la
--     app no deja reportar horas en una obra terminada, así que es una
--     vuelta de garantía o un reporte en la obra equivocada, y eso no se
--     sabe sin Edgar). No pregunta por las del mismo día, ni por una obra
--     reabierta (en ejecución, aunque conserve su día de término), ni por
--     una terminada sin su día de término (no se sabe si son de antes).
--     (El banco de pruebas no trae esa columna de la app; producción sí. Si
--     falta, se pone dentro de la prueba y se va con ella.)
do $$
declare
  v_obt text; v_r jsonb; v_j jsonb; mA uuid; mB uuid; a text; b text; c text; d text; e text; v_as uuid; v_txt text; v_om text;
  ra jornal_repartos; rb jornal_repartos;
  v_nom text := 'LA OBRA TERMINADA, NO APROBADA O SIN APROBAR NO FRENA (la cuadrilla sola): un pago cuya semana tiene horas en una obra '
                'terminada y en otra «enviado», y otro con horas en una no aprobada, ENTRAN SOLOS; su parte va a esas obras, y el aviso '
                'queda como nota en lo registrado y en el reparto. Sí pregunta por unas horas con fecha posterior al día en que su obra '
                'se dio por terminada (¿garantía o la obra equivocada?); no por las del mismo día, ni por una obra reabierta, ni por una '
                'terminada sin su día de término';
  v_esp text := 'antes: entra, con la nota [obra_terminada,obra_sin_aprobar], y entra, con la nota [obra_terminada] | con las horas '
                'DESPUÉS del día en que la obra se terminó: pregunta [horas_tras_terminada] y lo dice (el «Así es» sigue pudiendo); el '
                'mismo día: entra; reabierta, con su día de término: entra [obra_sin_aprobar]; terminada sin su día: entra '
                '[obra_terminada,obra_sin_aprobar] | la rutina registra 2: Zzana 200.00, Zzbeto 144.00 | el asiento de Zzana: 1 1010 '
                '-200.00 | 2 5200 100.00 a empleado:p1 | 3 5200 50.00 c empleado:p1 | 4 5200 50.00 g empleado:p1 | la nota va con lo '
                'registrado [obra_terminada,obra_sin_aprobar] y [obra_terminada] y queda en el reparto, con su texto (la obra terminada, '
                'la enviada y la no aprobada, por su nombre) | control del jornal: nada nuevo en rojo; del margen: nada nuevo en rojo';
begin
  if pg_temp.c10_omitir(80, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(80, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- (la obra G nace «estimando»: aquí, «enviado»: la propuesta ya está en manos del cliente)
    update proyectos set estado = 'enviado' where id = 'c10-prueba-g';
    -- Zzana: 4 h en una obra en marcha (A), 2 h en una terminada (C) y 2 h en una enviada (G): 8 h, a su tarifa (25)
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 4);
    perform pg_temp.c10_hora(2, 'p1', pg_temp.c10_w1(1), 'c10-prueba-c', 2);
    perform pg_temp.c10_hora(3, 'p1', pg_temp.c10_w1(2), 'c10-prueba-g', 2);
    -- Zzbeto: 6 h en una obra no aprobada (D), a su tarifa (24)
    perform pg_temp.c10_hora(4, 'p2', pg_temp.c10_w1(0), 'c10-prueba-d', 6);
    perform pg_temp.c10_aparcar();
    mA := pg_temp.c10_cargo('c10-t80-1', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9801');
    mB := pg_temp.c10_cargo('c10-t80-2', pg_temp.c10_ds(), 144.00, 'Zelle payment to ZZBETO C10 PRUEBA 9802');
    -- (el alta sola, sin registrar todavía; y cómo está cada pago: entra, y su propuesta trae la nota)
    perform pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    a := format('%s, con la nota [%s], y %s, con la nota [%s]', pg_temp.c10_solo(mA), pg_temp.c10_notas(pg_temp.c10_propuesta(mA)->'avisos'),
                pg_temp.c10_solo(mB), pg_temp.c10_notas(pg_temp.c10_propuesta(mB)->'avisos'));
    -- (b) LAS HORAS DESPUÉS DE TERMINADA LA OBRA (se deshace aquí mismo: la rutina registra después lo de arriba)
    begin
      if not exists (select 1 from information_schema.columns
                      where table_schema = 'public' and table_name = 'proyectos' and column_name = 'completado_el') then
        execute 'alter table public.proyectos add column completado_el date';
      end if;
      -- las 2 h de Zzana en la obra C son del martes de esa semana; la obra se dio por terminada el lunes: son de DESPUÉS
      execute format('update public.proyectos set completado_el = %L where id = %L', pg_temp.c10_w1(0), 'c10-prueba-c');
      v_j := pg_temp.c10_propuesta(mA);
      b := format('%s y %s', pg_temp.c10_solo(mA),
                  case when pg_temp.c10_aviso(v_j, 'horas_tras_terminada') like 'Hay horas con fecha posterior al día en que su obra se dio por terminada: 2 h del % en C10 PRUEBA Obra C (terminada el %). Si fue una vuelta de garantía, su parte va a esa obra: acéptalo con «Así es». Si se apuntaron en la obra equivocada, corrígela en Horas y vuelve a mirar.'
                            and (v_j->>'puede_aplicar')::boolean and pg_temp.c10_notas(v_j->'avisos') = 'obra_terminada,obra_sin_aprobar,horas_tras_terminada'
                       then 'lo dice (el «Así es» sigue pudiendo)' else 'dice: ' || coalesce(pg_temp.c10_aviso(v_j, 'horas_tras_terminada'), '(nada)') end);
      -- terminada ese mismo martes: sus horas no son de después
      execute format('update public.proyectos set completado_el = %L where id = %L', pg_temp.c10_w1(1), 'c10-prueba-c');
      b := b || '; el mismo día: ' || pg_temp.c10_solo(mA);
      -- reabierta: en ejecución, y conserva su día de término (el lunes)
      execute format('update public.proyectos set estado = %L, completado_el = %L where id = %L', 'ejecucion', pg_temp.c10_w1(0), 'c10-prueba-c');
      b := b || format('; reabierta, con su día de término: %s [%s]', pg_temp.c10_solo(mA), pg_temp.c10_notas(pg_temp.c10_propuesta(mA)->'avisos'));
      -- terminada, sin su día de término
      execute format('update public.proyectos set estado = %L, completado_el = null where id = %L', 'completado', 'c10-prueba-c');
      b := b || format('; terminada sin su día: %s [%s]', pg_temp.c10_solo(mA), pg_temp.c10_notas(pg_temp.c10_propuesta(mA)->'avisos'));
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      -- (esta base no deja poner el día de término de una obra de prueba —no trae la columna y no se puede añadir, o algo
      -- suyo no lo admite—: se dice, y lo demás se mira igual)
      when others then
        v_om := sqlstate || ': ' || sqlerrm;
        perform pg_temp.c10_ser('editor');
    end;
    -- (c) la rutina, como al abrir Contabilidad: entran los dos
    v_r := pg_temp.c10_rutina();
    c := format('la rutina registra %s', pg_temp.c10_registrados(v_r, array[mA, mB]));
    select * into ra from jornal_repartos r where r.movimiento_id = mA and r.estado = 'aplicado';
    select * into rb from jornal_repartos r where r.movimiento_id = mB and r.estado = 'aplicado';
    d := pg_temp.c10_asiento(ra.asiento_id);
    -- (d) LA NOTA: va con lo registrado (lo que devuelve la rutina) y queda en el reparto (lo que lee «Registrado solo»), con su texto
    perform pg_temp.c10_ser('dueno');
    select string_agg(x.t, ' ' order by x.o) into v_txt
      from (select a.o, a.v->>'texto' as t
              from v_jornal_repartos q, jsonb_array_elements(q.avisos) with ordinality as a(v, o)
             where q.reparto_id = ra.id and q.origen = 'solo' and a.v->>'codigo' in ('obra_terminada', 'obra_sin_aprobar')) x;
    perform pg_temp.c10_ser('editor');
    e := format('la nota va con lo registrado [%s] y [%s] y %s',
                pg_temp.c10_notas((select x->'avisos' from jsonb_array_elements(v_r->'registrados') x where (x->>'movimiento_id')::uuid = mA)),
                pg_temp.c10_notas((select x->'avisos' from jsonb_array_elements(v_r->'registrados') x where (x->>'movimiento_id')::uuid = mB)),
                case when pg_temp.c10_notas(ra.avisos) = 'obra_terminada,obra_sin_aprobar' and pg_temp.c10_notas(rb.avisos) = 'obra_terminada'
                          and ra.origen = 'solo' and rb.origen = 'solo'
                          and v_txt = 'Hay horas en una obra que ya no está activa: C10 PRUEBA Obra C (terminada). Su parte va a esa obra igual: el trabajo se hizo ahí. '
                                      'Hay horas en una obra que todavía no está aprobada: C10 PRUEBA Obra G (enviado). Su parte va a esa obra.'
                          and (select a.v->>'corto' || ': ' || (a.v->>'texto') from jsonb_array_elements(rb.avisos) a(v) where a.v->>'codigo' = 'obra_terminada')
                              = 'Hay una obra no aprobada: Hay horas en una obra que ya no está activa: C10 PRUEBA Obra D (no aprobada). Su parte va a esa obra igual: el trabajo se hizo ahí.'
                     then 'queda en el reparto, con su texto (la obra terminada, la enviada y la no aprobada, por su nombre)'
                     else 'en el reparto queda: ' || coalesce(v_txt, '(nada)') || ' / ' || coalesce(rb.avisos::text, '(nada)') end);
    v_obt := format('antes: %s | con las horas DESPUÉS del día en que la obra se terminó: %s | %s | el asiento de Zzana: %s | %s | %s', a, b, c, d, e,
                    pg_temp.c10_propios());
    if v_om is not null then
      v_obt := format('omitida: lo de las horas de después de terminada la obra no se puede ver en esta base (no deja poner el día de '
                      'término de una obra de prueba: %s); lo demás: %s', left(v_om, 300), v_obt);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (80, v_nom, v_esp, v_obt, case when v_obt like 'omitida:%' then null else v_obt = v_esp end);
end $$;

-- 81. LO QUE ENCONTRÓ LA REVISIÓN DE LA v5 (15-nov-2026), una prueba por
--     las dos cosas de la rutina:
--     (a) LA RUTINA AVANZA SIEMPRE. No empieza un pago más pasado su
--     presupuesto de tiempo, y la pantalla la vuelve a llamar. Antes cada
--     llamada volvía a empezar por el pago más viejo: con muchos pagos
--     esperando una respuesta de Edgar (cada uno cuesta su cálculo, aunque no
--     entre) se le iba el tiempo en los mismos y el más nuevo —el que sí
--     entraba— no se miraba nunca. Ahora, cuando corta, dice por dónde iba
--     («sigue»: el último pago que miró) y la llamada siguiente sigue DESPUÉS
--     de él («despues_de»). Aquí, sin esperar a ningún reloj: sin tiempo no
--     mira ninguno y lo dice; con «despues_de» mira solo lo que va después
--     (registra el que entra sin volver a mirar los dos de antes); si ese
--     movimiento ya no existe empieza por el principio; y lo que no es un id,
--     22023. (El corte por reloj de verdad, con miles de horas delante, lo
--     corre el banco: pruebas/conta/c10-volumen.sh.)
--     (b) REGISTRA EN NOMBRE DE ALGUIEN. Desde el SQL Editor sin sesión
--     (nadie en cuyo nombre registrar) la rutina registraba igual: el
--     reparto, el asiento y la aprobación de las horas quedaban sin decir
--     quién. Ahora ni la rutina ni lo que se dice de un pago corren así
--     (42501, y nada cambia): con la sesión del dueño, o la tarea sin
--     pantalla, que lo fija ella (la 76).
do $$
declare
  v_obt text; v_r jsonb; m1 uuid; m2 uuid; m3 uuid; a text; b text; c text; d text; e text; f text; v_n0 int;
  v_nom text := 'LO QUE ENCONTRÓ LA REVISIÓN DE LA v5 (la cuadrilla sola): la rutina AVANZA SIEMPRE (cuando corta por reloj dice por '
                'dónde iba —«sigue»— y la llamada siguiente sigue después —«despues_de»—: dos pagos viejos que preguntan no tapan al que '
                'entra) y registra EN NOMBRE DE ALGUIEN (desde el SQL Editor sin sesión, ni la rutina ni lo que se dice de un pago: 42501, '
                'y nada cambia)';
  v_esp text := 'sin tiempo: no mira ninguno, quedan 3, y no dice por dónde seguir (no llegó a mirar nada) | sin tiempo, después del '
                'primero: quedan 2 y sigue donde venía | después del segundo: registra 1, el tercero, sin volver a mirar los dos de '
                'antes, y termina (completo, sin «sigue») | los dos de antes: pregunta [tarifa_lejos] y pregunta [tarifa_lejos], pendientes '
                '| después de uno que ya no existe: empieza por el principio (mira los 2 que quedan) | después del último: nada que mirar, '
                'completo | lo que no es un id: 22023 | desde el SQL Editor sin sesión: la rutina 42501 y lo dicho de un pago 42501; nada '
                'cambia';
begin
  if pg_temp.c10_omitir(81, v_nom, v_esp) then return; end if;
  if pg_temp.c10_omitir_ds(81, v_nom, v_esp) then return; end if;
  begin
    perform pg_temp.c10_sembrar();
    -- tres personas con 8 h en la semana y su pago de ese mismo día, cada uno a su tarifa (25, 24 y —aquí— 26): los tres entrarían
    insert into costos_equipo (usuario_id, costo_hora) values (pg_temp.c10('p3')::uuid, 26)
    on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
    perform pg_temp.c10_hora(1, 'p1', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(2, 'p2', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_hora(3, 'p3', pg_temp.c10_w1(0), 'c10-prueba-a', 8);
    perform pg_temp.c10_aparcar();
    perform pg_temp.c10_cargo('c10-t81-1', pg_temp.c10_ds(), 200.00, 'Zelle payment to ZZANA C10 PRUEBA 9811');
    perform pg_temp.c10_cargo('c10-t81-2', pg_temp.c10_ds(), 192.00, 'Zelle payment to ZZBETO C10 PRUEBA 9812');
    perform pg_temp.c10_cargo('c10-t81-3', pg_temp.c10_ds(), 208.00, 'Zelle payment to ZZCARO C10 PRUEBA 9813');
    -- EL ORDEN EN QUE LA RUTINA LOS MIRA (por fecha y, el mismo día, por su id: no se elige): el primero, el segundo y el tercero
    select (array_agg(m.id order by m.fecha, m.id))[1], (array_agg(m.id order by m.fecha, m.id))[2], (array_agg(m.id order by m.fecha, m.id))[3]
      into m1, m2, m3
      from movimientos_banco m where m.id_externo in ('c10-t81-1', 'c10-t81-2', 'c10-t81-3');
    -- (el alta sola de las tres)
    perform pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    -- los dos primeros PREGUNTAN (a sus dos personas se les sube la tarifa: lo pagado sale lejos); el tercero entra
    update costos_equipo ce set costo_hora = ce.costo_hora * 3
     where ce.usuario_id in (select (case m.id_externo when 'c10-t81-1' then pg_temp.c10('p1') when 'c10-t81-2' then pg_temp.c10('p2')
                                                       else pg_temp.c10('p3') end)::uuid
                               from movimientos_banco m where m.id in (m1, m2));
    -- (a) sin tiempo: no mira ninguno
    v_r := pg_temp.c10_rutina('{"segundos": 0}'::jsonb);
    a := case when not (v_r->>'completo')::boolean and (v_r->>'quedan')::int = 3 and jsonb_array_length(v_r->'registrados') = 0
                   and jsonb_array_length(v_r->'no_entraron') = 0 and jsonb_typeof(v_r->'sigue') = 'null'
              then 'no mira ninguno, quedan 3, y no dice por dónde seguir (no llegó a mirar nada)' else left(v_r::text, 300) end;
    v_r := pg_temp.c10_rutina(jsonb_build_object('segundos', 0, 'despues_de', m1));
    b := case when not (v_r->>'completo')::boolean and (v_r->>'quedan')::int = 2 and v_r->>'sigue' = m1::text and jsonb_array_length(v_r->'altas') = 0
              then 'quedan 2 y sigue donde venía' else left(v_r::text, 300) end;
    -- después del segundo: solo mira el tercero, que entra
    v_r := pg_temp.c10_rutina(jsonb_build_object('despues_de', m2));
    c := format('registra %s, %s, y %s',
                case when jsonb_array_length(v_r->'registrados') = 1 and v_r->'registrados'->0->>'movimiento_id' = m3::text then '1, el tercero'
                     else jsonb_array_length(v_r->'registrados')::text || ': ' || left((v_r->'registrados')::text, 200) end,
                case when jsonb_array_length(v_r->'no_entraron') = 0 and (v_r->>'preguntan')::int = 0 then 'sin volver a mirar los dos de antes'
                     else 'MIRÓ los de antes: ' || left((v_r->'no_entraron')::text, 200) end,
                case when (v_r->>'completo')::boolean and jsonb_typeof(v_r->'sigue') = 'null' then 'termina (completo, sin «sigue»)'
                     else 'NO termina: ' || coalesce(v_r->>'sigue', '?') end);
    d := format('%s y %s, %s', pg_temp.c10_solo(m1), pg_temp.c10_solo(m2),
                case when (select count(*) from movimientos_banco m where m.id in (m1, m2) and m.estado = 'pendiente') = 2
                          and not exists (select 1 from jornal_repartos r where r.movimiento_id in (m1, m2)) then 'pendientes' else 'TOCADOS' end);
    -- después de un movimiento que ya no existe: se empieza por el principio
    v_r := pg_temp.c10_rutina(jsonb_build_object('despues_de', '00000000-0000-4000-a000-0000000c10fe'));
    e := case when (v_r->>'completo')::boolean and (select count(*) from jsonb_array_elements(v_r->'no_entraron') x where (x->>'movimiento_id')::uuid in (m1, m2)) = 2
              then 'empieza por el principio (mira los 2 que quedan)' else left(v_r::text, 300) end;
    v_r := pg_temp.c10_rutina(jsonb_build_object('despues_de', m3));
    e := e || ' | después del último: ' || case when (v_r->>'completo')::boolean and (v_r->>'quedan')::int = 0 and jsonb_array_length(v_r->'no_entraron') = 0
                                                      and jsonb_array_length(v_r->'registrados') = 0 then 'nada que mirar, completo' else left(v_r::text, 300) end;
    begin
      perform pg_temp.c10_rutina('{"despues_de": "el-de-antes"}'::jsonb);
      e := e || ' | lo que no es un id: LO ACEPTA';
    exception when others then
      e := e || ' | lo que no es un id: ' || sqlstate;
      perform pg_temp.c10_ser('editor');
    end;
    -- (b) desde el SQL Editor sin sesión: ni la rutina ni lo que se dice de un pago
    perform pg_temp.c10_ser('editor');
    select count(*) into v_n0 from asientos;
    begin perform fn_jornal_solo('{}'::jsonb); f := 'la rutina CORRE'; exception when others then f := 'la rutina ' || sqlstate; end;
    begin perform fn_jornal_pago(jsonb_build_object('movimiento_id', m1, 'no_cuadrilla', true)); f := f || ' y lo dicho de un pago SE ANOTA';
    exception when others then f := f || ' y lo dicho de un pago ' || sqlstate; end;
    f := f || case when (select count(*) from asientos) = v_n0 and not exists (select 1 from jornal_pagos g where g.movimiento_id = m1 and g.no_cuadrilla)
                        and (select count(*) from jornal_repartos r where r.movimiento_id in (m1, m2, m3)) = 1 then '; nada cambia' else '; ALGO cambió' end;
    v_obt := format('sin tiempo: %s | sin tiempo, después del primero: %s | después del segundo: %s | los dos de antes: %s | después de uno que '
                    'ya no existe: %s | desde el SQL Editor sin sesión: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.c10_ser('editor');
  insert into _pruebas values (81, v_nom, v_esp, v_obt, v_obt = v_esp);
end $$;

-- 82. Nada queda, otra vez: después de las pruebas de la cuadrilla sola (65
--     a 81), lo que c10 toca está como antes de la primera prueba (lo mismo
--     que mira la 58, que corre antes que ellas): ni una persona dada de
--     alta sola, ni un pago con algo dicho, ni un reparto, ni lo automático
--     apagado, ni la marca de la nómina cambiada.
do $$
declare
  v_obt text;
begin
  begin
    perform pg_temp.c10_ser('editor');
    v_obt := case when pg_temp.c10_conteos() = pg_temp.c10('conteos') then 'igual que antes' else 'antes: ' || pg_temp.c10('conteos') || ' · ahora: ' || pg_temp.c10_conteos() end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (82, 'nada queda de las pruebas de la cuadrilla sola (65 a 81): la configuración (lo automático, su última corrida), las personas, los pagos con algo dicho, los repartos, los asientos, los movimientos del banco, las horas y sus aprobaciones, los perfiles, las tarifas, las obras y las funciones, como antes de la primera prueba',
    'igual que antes', v_obt, v_obt = 'igual que antes');
end $$;

-- Lo que se puso para la sesión, como estaba
reset c4.control_tope;
reset mxp.cierre_sin_push;

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD (como c2, c3, c4, c6,
-- p1, c8 y c9): si el SQL Editor deja de esperar, la corrida sigue en el
-- servidor hasta el final y se lee después con
--   select * from pruebas.c10_resultado order by n;
-- Fuera de la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Guarda solo la última
-- corrida, con su hora. No es parte del libro y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade».
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c10_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c10_resultado from public, anon, authenticated, service_role;
truncate pruebas.c10_resultado;
insert into pruebas.c10_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
