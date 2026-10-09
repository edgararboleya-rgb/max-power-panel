-- =====================================================================
-- C6 · Las pruebas del banco — Max Power Electrical Solutions, Inc.
-- Supabase → SQL Editor. Se pega ENTERO, después de c1, c2-libro.sql,
-- c3-puentes.sql, c4-estados.sql y c6-banco.sql (pruebas/conta/README.md,
-- §0). Lo que enseña al final es la tabla de resultados: una fila por
-- prueba, con lo esperado, lo obtenido y ok. Todo en true = los archivos
-- del banco entran enteros y una sola vez, cada movimiento casa con lo
-- suyo o espera a Edgar con su propuesta, nada del banco va dos veces al
-- libro, la conciliación cuadra de verdad, y el equipo no ve nada.
--
-- NO DEJA RASTRO. Cada prueba es un bloque «do» con una subtransacción
-- adentro: arma lo que necesita con CUENTAS DE PRUEBA (el banco 1098, la
-- reserva 1097 y dos tarjetas, 2100-9996 «····9996» y 2100-9995
-- «····9995», que se crean y se deshacen con ella: así ni los movimientos
-- de verdad ni los de la prueba se cruzan), sus reglas, un proveedor y
-- papeles de prueba (recibos y facturas con ids negativos, «c6-pruebas»),
-- importa estados de cuenta de prueba, casa, concilia, y al final lanza
-- MXT00 para DESHACER todo: los archivos, los movimientos, los casados,
-- las conciliaciones, los asientos, los números, los cierres y el
-- historial. El resultado viaja en variables y se apunta en _pruebas, que
-- es temporal. La última prueba compara la foto del final con la del
-- principio.
--
-- LOS CANDADOS, en el orden de la app: primero el del casado (el que toman
-- las funciones del banco), después los de los recibos (los 512 cajones de
-- c3, si la prueba sube tickets), y al final periodos y la cadena (los
-- toma el libro al postear). pg_temp.c6_candados() toma los dos primeros
-- ANTES que nada; pedirlos con la cadena ya tomada es MXT10. Las que
-- cambian un instante algo que la app podría estar leyendo (vacían una
-- vista, cambian la marca de c2) van con lock_timeout de 2 s: si la app
-- la está usando, salen «omitida».
--
-- LOS DATOS se buscan, no se inventan: el dueño, uno del equipo (si no
-- hay, esas pruebas salen «omitidas»), dos obras con tipo y el mes
-- abierto más antiguo desde el corte. Tarda unos segundos en el banco de
-- pruebas.
--
-- LA RONDA 2 (27-sep; piden la marca 2026092703 de c6-banco.sql): de la
-- 63 a la 82, una por hallazgo (la apertura y sus partidas, la
-- transferencia dentro de una conciliación confirmada, los abonos de la
-- tarjeta y AUTOPAY, el saldo escrito contra el del archivo, los
-- préstamos, los errores en español, el candado de c2, el trigger ajeno,
-- el estado de cuenta borrado, el NSF, la retención y el pago parcial, el
-- cheque sin nombre a un proveedor, la nómina del oficial, el reembolso,
-- el código corto de la tarjeta, des-casar y la firma); la 46 mide solo
-- sus prepagados (una póliza de verdad de QuickBooks no la pone en rojo)
-- y la 59, el casado que no rehace lo que no cambió. La 61 sigue siendo
-- la última.
--
-- LA RONDA 3 (27-sep; piden la marca 2026092704): de la 83 a la 100, una
-- por hallazgo: el ticket con otro total (antes y después de clasificar),
-- el pago de la tarjeta que el banco cobra días después, el pago parcial
-- que no va al costo, el cheque que rebota de un depósito de dos, la
-- póliza sustituida y la cancelada, R3 fuera de la conciliación
-- confirmada, el saldo de Plaid y la coma de miles, la regla ajena, el
-- statement de la tarjeta cortado antes del corte, el proveedor a cuenta
-- que no se traga la luz, el cobro con tarjeta neto de comisión, la
-- conciliación con la fecha mal escrita, la obra del día de la compra,
-- el re-pegado con vistas ajenas, «no es su ticket» con su motivo, el
-- motivo de la partida de la apertura que se hereda y la firma por
-- proveedor. La 10 lleva el día de la compra (DTUSER); la 22 y la 46
-- salen «omitida» si Edgar ya amortizó un mes posterior al primero
-- abierto (la marcha en paralelo), como la 88. Y para seguir en menos de
-- 40 s con un año de banco: pg_temp.c6_cuadre pide el cuadre suelto, por
-- su nombre (la 36 lo mira), la 79 hace una sola revisión con sus dos
-- cuentas, y la 87 elige la opción de la bandeja con SUS dos facturas
-- (con datos de verdad, otra factura abierta suma lo mismo).
--
-- LA RONDA 4 (2-oct; piden la marca 2026100201): de la 101 a la 117, una
-- por hallazgo del casado y la bandeja: el pago de la tarjeta de fin de mes
-- que partiría su estado de cuenta, el cobro anotado por otro monto, el
-- rebote de un depósito de dos cheques de la misma factura, la cuota de
-- otro monto y la cuota con un extra, el ticket repartido que llega
-- después, el cheque de QuickBooks que rebota, el lote del procesador, lo
-- trabajado antes de conciliar la apertura, R7 con lo des-casado y la
-- apertura, el primer archivo subido a la cuenta equivocada (fn_banco_
-- archivo_retirar), la devolución en la débito, la cuenta personal de
-- Edgar, los nombres de dos letras, v_conciliacion con un motivo por dar,
-- cada botón que no pide nada (pg_temp.c6_pulsar los pulsa tal cual) y la
-- «Línea 1» de los errores de c2. La 16 espera ahora
-- «transferencia_personal» (la reserva que no trajo su estado de cuenta no
-- se da por de la empresa) y la 89 sube el estado de cuenta de la tarjeta
-- hasta el día 40 (cortado el 30, ese asiento la dejaría partida: la 101).
-- La 109 sale «omitida» con la apertura de verdad ya posteada (prueba lo
-- de antes de conciliarla, con una apertura de prueba que lleva el banco
-- 1098); la 107, la 109, la 110 y la 116, también cuando el mes abierto más
-- antiguo ya no es el primero después del corte, como la 99.
-- Y de la 118 a la 128, una por hallazgo de la entrada (el importador y
-- los lotes) y de la seguridad: el saldo de un lote a mano o de un QFX
-- retocado que no es el del banco, clasificar sin «Casar» (o con la
-- propuesta de antes), la partida de la apertura por otro camino
-- (transferencia y cuota; cobrar y pagar al proveedor, en la 63, que ahora
-- los prueba), lo que leen las reglas cambiado por fuera, el tope de la
-- comisión (y la del depósito sin procesador), el estado de cuenta de otra
-- tarjeta, el mismo id con la fecha o el monto corregidos, el cheque
-- cobrado otra vez, el banco que numera sus FITID por archivo, la
-- corrección del banco, otra moneda y CDATA en el OFX, y lo que Plaid
-- quita (con el saldo sin fecha y la moneda). El primer archivo subido a
-- la cuenta equivocada ya lo prueba la 111. La 120 sale «omitida» sin la
-- apertura, como la 63.
-- Y de la 129 a la 133 (grupo 3, 3-oct), una por hallazgo de la apertura
-- y el primer mes: los Undeposited Funds en la conciliación de apertura,
-- los préstamos contra la apertura (las dos postean una apertura de prueba
-- con fn_apertura: salen «omitida» con la de verdad ya posteada, o con la
-- apertura cerrada), la cuenta que no llega al fin del mes terminado
-- (cubierto_hasta y el cuadre 58), el ticket que espera en la bandeja de
-- los puentes y el ticket de un cargo clasificado que llega con el mes
-- cerrado (se cambia sin reabrir y sin el «cargo en circulación»
-- fantasma; sale «omitida» sin el mes siguiente). pg_temp.c6_candados no
-- vuelve a pedir lo que ya tiene (la 133 postea y después cierra el mes).
-- La 49 pide el cuadre 51 por su nombre, una vez (antes, también el
-- control entero: con un año de banco, medio segundo, lo que cuestan las
-- cinco nuevas).
-- Y la 134 (grupo 4, 3-oct: el tiempo en producción): ninguna función del
-- banco nombra una de c4 con su paréntesis sin llamarla (fn_banco_control
-- las nombraba en sus mensajes, y «protecciones de c4» daba una vuelta más
-- en cada pantalla). Lo demás de ese grupo lo prueban c2-pruebas (la 83) y
-- c4-pruebas (la 112 y la 113); c6-banco.sql pide ahora c2 y c4 con la
-- marca 2026100201 (y su control, «c2, c3 y c4 al día»).
--
-- LA RONDA 4b (3-oct; piden la marca 2026100301): de la 135 a la 142, lo
-- que encontró la prueba final y EL PRINCIPIO (el dinero del banco no va al
-- patrimonio del accionista sin su motivo, salvo de o a una cuenta personal
-- de Edgar dada de alta; un número que no se conoce no es personal; ningún
-- botón pulsado tal cual deja el control en rojo): el dinero de y a una
-- cuenta que no se conoce (x13b, x13c), la cuenta personal dada de alta y
-- su registro (fn_banco_cuenta_personal), el primer pase a la reserva
-- recién abierta antes de su primer estado de cuenta (x14; x15 y x16: su
-- número dado de alta con un lote vacío), el pase tomado por una
-- distribución cuando llega la reserva (su otro lado clasificado), la
-- tarjeta nueva antes de su primer statement y la personal dada de alta en
-- 2900, la conciliación de octubre sin la de apertura confirmada, el
-- anticipo de una obra cuando unas facturas explican el depósito, y los
-- demás caminos (el cajero, el Zelle de Edgar, los descriptores, un
-- préstamo en 2900 y R3 con la cuenta personal). La 16 espera ahora
-- «cuenta_desconocida» (la reserva sin su estado de cuenta no se supone
-- personal: se pregunta), la 113 da de alta la cuenta personal antes (sus
-- botones entran tal cual y el cuadre 52 sigue en verde), la 119 clasifica
-- el depósito que después explica una factura al desembolso de la línea de
-- crédito (2510): al patrimonio, sin motivo, ya no entra; y la 121 pone
-- también una cuenta personal por fuera de su función (el cuadre 53 la
-- dice). Los botones de un depósito de los primeros 30 días los marca
-- además el aviso de la apertura sin conciliar: esas pruebas los pulsan
-- tal cual (pg_temp.c6_pulsar) en vez de mirar solo su marca. Y
-- pg_temp.c6_montar ya no reescribe los diez descriptores cuando ya están
-- como vienen en c6-banco.sql (fn_banco_descriptor los escribía igual, con
-- su historial, en cada prueba: con un año de banco, más de un segundo de
-- la suite; con lo que la 4b le quitó a c6, la suite sigue bajo sus 40 s).
--
-- LA RONDA 4c (3-oct; piden la marca 2026100302): de la 143 a la 153, EL
-- CRITERIO DEL OTRO LADO (una sola respuesta a «¿quién es el otro lado de
-- este movimiento?», fn_banco_otro_lado, que todos los caminos usan igual),
-- una por lo que encontró la prueba final de la 4b con su arnés: R3 y un
-- número que no se conoce ([a]: los escenarios C, C3 y C4), juntar a mano
-- dos lados que se contradicen ([a]: C2), «Desde …» con la cuenta personal
-- dada de alta ([b]: C2t, C2u y C3s), el depósito que nombra una cuenta
-- propia ([c]: H, y R2 con un cobro anotado), la transferencia sin número
-- que nombra a alguien ([d]: F), la línea de crédito dada de alta por su
-- número ([e]: E, con la cuenta 2599 de prueba), el orden de un depósito
-- de un número que no se conoce ([f]), el pase a la personal con la
-- aportación ya clasificada ([g]: C2v), la baja de la cuenta personal que
-- rehace sus propuestas (G), «TO CHK ...7781», que no es un cheque, con
-- el «Lo que falta» de confirmar, y la 153: la marca de la versión en la
-- firma de cada propuesta (un pegado nuevo rehace lo pendiente en el
-- primer «Casar»). Las once habrían fallado con la 4b (594054b).
-- pg_temp.c6_montar aparta ahora, dentro de cada prueba (se deshace con
-- ella), lo de verdad que se cruza con los números de las pruebas: una
-- cuenta personal dada de alta con ····7781 (o ····1097, ····1098,
-- ····8896, ····5555…) se da de baja, y el lote vacío que dio de alta uno
-- de esos números se retira. Antes, con la personal ····7781 y la reserva
-- ····1097 dadas de alta como dice el README, 38 salían en rojo (MX004);
-- y la 136 cuenta solo el rastro de su alta.
-- pg_temp.c6_sin_aviso, nuevo: una apertura mínima sin las
-- cuentas de prueba (si no hay ninguna), para que el aviso de la apertura
-- de los primeros 30 días no marque todos los botones y se vea lo que la
-- prueba mira; con la apertura cerrada y sin su asiento, la prueba sale
-- «omitida».
--
-- LA RONDA 5 (9-oct; piden la marca 2026100901): la 162, los préstamos de
-- cuota semanal (cuotas_al_anio: la partición por período, la porción
-- corriente de un año de cuotas, la regla de los días por período), y la
-- 163, lo que encontró su verificación: varias cuotas registradas antes
-- que el banco a 7 días (cada cargo casa solo con la de su fecha y la
-- cuota toma su cargo), el recargo del banco con una cuota posterior (a
-- interés entra; a capital, fn_prestamo_cuota_anular), anular de la última
-- hacia atrás, el extra chico como recargo, el pago que no cubre el interés
-- (pide el statement) y la frecuencia como se escribe.
--
-- LA RONDA 4d (3-oct; piden la marca 2026100303): de la 154 a la 161. La
-- 154 es EL CONTROL (el cuadre 59 de fn_banco_control, «el otro lado de
-- cada casado», su fila en fn_banco_verificar y el freno de
-- fn_conciliacion_confirmar): el estado final de los escenarios L02, L02b,
-- L03, L06, L10, L13, L14, L16 y L17 del corrector, escrito con la función
-- interna que casa como lo dejaba la 9849564, sale en rojo, y lo coherente
-- no. Después, una por arreglo: R1 con un asiento escrito a mano (155), el
-- cobro que c3 registró con su movimiento (156), lo que el criterio no
-- leía —los 4 últimos sueltos de la tarjeta personal, el emisor, el
-- cheque, el nombre de QuickBooks que es solo cifras— (157), el duplicado
-- que trae el número (158), la partida de la apertura y lo que llega de la
-- personal (159), la línea de crédito dada de alta después y su desembolso
-- (160), y los botones de antes, la dirección de «Es la transferencia con
-- …» y el orden de lo que falta (161). La 158 mira también que, sin nada
-- que se contradiga, no salga un «Ojo» vacío (lo encontró la
-- verificación). Las ocho habrían fallado con la 4c (9849564). La 23 y
-- la 27 ponen ahora su depósito del libro contra 1600 (un depósito en
-- garantía devuelto) y no contra 3100: el dinero del banco
-- al patrimonio sin la cuenta personal de Edgar ya no casa solo con un
-- «DEPOSIT» (EL CRITERIO contra el libro), y no era lo que miraban. La 36
-- y la 39 miran del cuadre 59 solo lo suyo (con datos de verdad puede
-- venir en rojo por lo que Edgar casó antes de la 4d: es lo que tiene que
-- revisar); la 154 mira además que la copia del control cuente lo mismo
-- que la referencia. Y fn_banco_verificar con cuentas pedidas ya no trae
-- los cuadres del control (miran todo el banco): la 39 se los pide al
-- control, como antes. Con un año de banco, las ocho nuevas suman unos
-- 2,5 s, y la revisión con cuentas, un cuarto de segundo menos en cada una
-- de sus nueve llamadas.
-- =====================================================================

create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;
set jit = off;

-- ---------------------------------------------------------------------
-- Antes de nada: lo que estas pruebas dan por hecho.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('public.movimientos_banco') is null or to_regprocedure('public.fn_banco_importar_ofx(text,text,text)') is null
     or to_regprocedure('public.fn_banco_control(text,text[])') is null or to_regprocedure('public.fn_banco_version()') is null
     or to_regclass('public.v_asiento_papel') is null or to_regprocedure('public.fn_cobro_registrar(jsonb)') is null then
    raise exception using
      errcode = 'MX000',
      message = 'c6-pruebas NO se corrió: pega antes c1-plan-de-cuentas.sql, c2-libro.sql, c3-puentes.sql, c4-estados.sql y '
                'c6-banco.sql.';
  end if;
  -- (Estas pruebas son las de ESTA versión del banco: con una c6-banco.sql
  -- anterior pegada, sus pruebas nuevas saldrían en rojo por lo que falta,
  -- no por un fallo del libro.)
  if public.fn_banco_version() < 2026100901 then
    raise exception using
      errcode = 'MX000',
      message = format('c6-pruebas NO se corrió: la c6-banco.sql pegada es anterior (marca %s; estas pruebas piden 2026100901 o '
                       'más). Vuelve a pegar la c6-banco.sql de esta entrega (entera, o sus dos partes).', public.fn_banco_version());
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Los ayudantes (en pg_temp: mueren con la sesión y nadie más los ve; se
-- llaman con su esquema delante, y siempre como el editor).
--   · c6_foto(): cómo están el libro, los papeles, el banco y su
--     historial, las reglas, los contadores, las secuencias de la app, los
--     eventos, las huellas de c2 y las del banco.
--   · c6_como(quien): suplantar al dueño, al equipo o a anon (o volver a
--     ser el editor), como en c4.
--   · c6_candados(): el candado del casado y los de los recibos, antes que
--     periodos y la cadena (ver arriba).
--   · c6_montar(): las cuentas de prueba, sus tarjetas, las reglas
--     confirmadas, los descriptores de arranque (como vienen en
--     c6-banco.sql: lo que Edgar ajustó no cambia lo que prueban) y el
--     proveedor de prueba.
--   · c6_qfx(...) y c6_ofx_xml(...): un estado de cuenta en OFX 1.x (SGML,
--     como el QFX de Chase y de Amex) o en OFX 2.x (XML).
--   · c6_recibo(json): un recibo de prueba (id negativo), leído, con su
--     forma de pago (la tarjeta ····9996 si no se dice).
--   · c6_mov(cuenta, fitid): el movimiento de prueba por su FITID.
-- ---------------------------------------------------------------------
create or replace function pg_temp.c6_foto() returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_seq     text;
  v_huellas text;
  v_banco   text := '-';
  v_ev      text := '-';
begin
  select left(md5(string_agg(h.tipo || ' ' || h.objeto || ' ' || h.md5, ',' order by h.tipo, h.objeto)), 12)
    into v_huellas
    from public.fn_libro_huellas_calcular() h;
  if to_regprocedure('public.fn_banco_huellas_calcular()') is not null then
    execute 'select left(md5(string_agg(h.tipo || '' '' || h.objeto || '' '' || h.md5, '','' order by h.tipo, h.objeto)), 12)
               from public.fn_banco_huellas_calcular() h' into v_banco;
  end if;
  if to_regclass('public.eventos') is not null then
    execute 'select count(*)::text from public.eventos' into v_ev;
  end if;
  select string_agg(format('%s=%s', t, coalesce((select s.last_value from pg_sequences s
                                                   where s.schemaname || '.' || s.sequencename = pg_get_serial_sequence('public.' || t, 'id')),
                                                  0)), ' ' order by t)
    into v_seq
    from unnest(array['recibos', 'facturas', 'horas', 'trabajos_externos', 'materiales', 'externos_equipo']) t;
  return format('asientos=%s lineas=%s contadores=%s cerrados=%s puente=%s cobros=%s aplic=%s devol=%s recibos=%s facturas=%s '
                'prov=%s alias=%s tarjetas=%s reglas=%s/%s/%s cuentas=%s eventos=%s '
                'banco=%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s descriptores=%s personales=%s sec=[%s] huellas=%s/%s',
                (select count(*) from asientos), (select count(*) from asiento_lineas),
                (select coalesce(sum(ultimo), 0) from contadores),
                (select count(*) from periodos where estado = 'cerrado'),
                (select count(*) || ':' || coalesce(sum(intentos), 0) from puente_documentos),
                (select count(*) from cobros), (select count(*) from aplicaciones_cobro), (select count(*) from cobros_devoluciones),
                (select count(*) from recibos), (select count(*) from facturas),
                (select count(*) from proveedores), (select count(*) from proveedores_alias), (select count(*) from tarjetas),
                (select count(*) from mapeo_categoria_recibo), (select count(*) from mapeo_metodo_pago),
                (select count(*) from mapeo_tipo_proyecto), (select count(*) from cuentas), v_ev,
                (select count(*) from banco_historial), (select count(*) from archivos_banco), (select count(*) from movimientos_banco),
                (select count(*) from movimientos_banco_ids), (select count(*) from banco_casados),
                (select count(*) from banco_casado_lineas), (select count(*) from conciliaciones),
                (select count(*) from conciliacion_partidas), (select count(*) from prestamos), (select count(*) from prestamo_cuotas),
                (select count(*) from prepagados), (select count(*) from prepagados_amortizaciones),
                (select count(*) from movimientos_banco where estado <> 'pendiente'),
                (select md5(string_agg(d.clave || d.patron || coalesce(d.cuenta, ''), ',' order by d.clave)) from banco_descriptores d),
                (select count(*) || ':' || coalesce(md5(string_agg(p.ultimos4 || p.nombre || p.activa::text, ',' order by p.ultimos4)), '-')
                   from banco_cuentas_personales p),
                coalesce(v_seq, '-'), v_huellas, v_banco);
end $$;
revoke execute on function pg_temp.c6_foto() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_como(p_quien text) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  execute 'reset role';
  if p_quien is null then
    perform set_config('request.jwt.claims', '', true);
    return;
  end if;
  perform set_config('request.jwt.claims',
                     json_build_object('sub', case p_quien when 'dueno' then current_setting('mx6.dueno')
                                                           when 'equipo' then current_setting('mx6.equipo') end,
                                       'role', case when p_quien = 'anon' then 'anon' else 'authenticated' end)::text, true);
  execute format('set local role %I', case when p_quien = 'anon' then 'anon' else 'authenticated' end);
end $$;
revoke execute on function pg_temp.c6_como(text) from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_candados() returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_k int;
begin
  -- (Ya tomados —c6_montar los toma al empezar, antes que nada—: no se
  -- piden otra vez, y el orden ya fue el de la app. Así una prueba que
  -- postea y después cierra el mes —c6_cerrar_hasta— no es MXT10; la 133.)
  if (select count(*) from pg_locks l
       where l.pid = pg_backend_pid() and l.granted and l.locktype = 'advisory'
         and l.classid::bigint = 820260925 and l.objsubid = 2) >= 512 then
    return;
  end if;
  if exists (select 1 from pg_locks l
              where l.pid = pg_backend_pid() and l.granted
                and ((l.locktype = 'advisory' and l.classid::bigint = 0 and l.objid::bigint = 820260923 and l.objsubid = 1)
                     or (l.locktype = 'relation' and l.relation = 'public.periodos'::regclass and l.mode <> 'AccessShareLock'))) then
    raise exception using errcode = 'MXT10',
      message = 'c6-pruebas: el candado del casado y los de los recibos se toman antes que periodos y la cadena, como en la app.';
  end if;
  perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  if (select count(*) from pg_locks l
       where l.pid = pg_backend_pid() and l.granted and l.locktype = 'advisory'
         and l.classid::bigint = 820260925 and l.objsubid = 2) < 512 then
    for v_k in 0 .. 511 loop
      perform pg_advisory_xact_lock(820260925, v_k);
    end loop;
  end if;
end $$;
revoke execute on function pg_temp.c6_candados() from public, anon, authenticated, service_role;

-- Los puentes diferidos de c3, en immediate dentro de la subtransacción
-- (el MXT00 los devuelve a diferidos), después de los candados.
create or replace function pg_temp.c6_inmediato() returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_lista text;
begin
  perform pg_temp.c6_candados();
  select string_agg(quote_ident(t.tgname), ', ' order by t.tgname) into v_lista
    from pg_trigger t
   where t.tgname in ('trg_puente_recibos_despues', 'trg_puente_externos_despues', 'trg_puente_facturas_despues')
     and t.tgconstraint <> 0;
  if v_lista is not null then
    execute 'set constraints ' || v_lista || ' immediate';
  end if;
end $$;
revoke execute on function pg_temp.c6_inmediato() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_montar() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_prov uuid;
  v_t    text;
  r      record;
begin
  perform pg_temp.c6_inmediato();
  -- (Ronda 4c) LO DE VERDAD QUE SE CRUZA CON LOS NÚMEROS DE LAS PRUEBAS.
  -- Las pruebas usan ····7781 como un número que nadie conoce (o lo dan
  -- de alta como la cuenta personal de prueba), ····1098 y ····1097 para
  -- sus dos cuentas, ····8896 para su línea de crédito y ····5555,
  -- ····5556, ····7776 y ····7777 como tarjetas que no son de la empresa.
  -- Si Edgar dio de alta uno de esos números de verdad (su cuenta personal
  -- termina en 7781; el número de la reserva, con su lote vacío, en 1097),
  -- la prueba no miraría lo que dice: aquí, dentro de la prueba (que se
  -- deshace entera), esa cuenta personal se da de baja y ese lote vacío se
  -- retira. Antes, con la personal ····7781 y la reserva ····1097 dadas de
  -- alta como dice el README, 38 pruebas salían en rojo (MX004: «ese
  -- número solo entró una vez, a 1030»). Un estado de cuenta de verdad
  -- (con movimientos) de un número así no se toca: sería una cuenta de la
  -- empresa que termina como una de prueba, y la prueba lo dice (MX004).
  -- (La baja, con la marca de su guarda y no con fn_banco_cuenta_personal:
  -- la función rehace la propuesta de lo pendiente que la nombra —ronda
  -- 4c—, y con dos pases de verdad a ····7781 en la bandeja eran 7 s más
  -- de la suite; a la prueba no le hace falta.)
  for r in select p.ultimos4 from banco_cuentas_personales p
            where p.activa and p.ultimos4 in ('7781', '1098', '1097', '8896', '5555', '5556', '7776', '7777', '9996', '9995') loop
    perform fn_banco_marca('personal:' || r.ultimos4);
    update banco_cuentas_personales set activa = false, motivo = 'c6-pruebas: un número de las pruebas (se deshace con la prueba)'
     where ultimos4 = r.ultimos4;
    perform fn_banco_marca(null);
  end loop;
  for r in select a.id from archivos_banco a
            where a.retirado_el is null and a.ultimos4 in ('7781', '1098', '1097', '8896', '5555', '5556', '7776', '7777', '9996', '9995')
              and a.cuenta not in ('1098', '1097', '2100-9996', '2100-9995')
              and not exists (select 1 from movimientos_banco m where m.archivo_id = a.id) loop
    perform fn_banco_archivo_retirar(r.id, 'c6-pruebas: un número de las pruebas (se deshace con la prueba)');
  end loop;
  insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
  values ('1098', 'c6-pruebas: banco de prueba', 'c6 test bank', 'activo', 'debe', true, 'prohibida', 'prohibida'),
         ('1097', 'c6-pruebas: reserva de prueba', 'c6 test reserve', 'activo', 'debe', true, 'prohibida', 'prohibida'),
         ('2100-9996', 'c6-pruebas: tarjeta de prueba', 'c6 test card', 'pasivo', 'haber', true, 'prohibida', 'prohibida'),
         ('2100-9995', 'c6-pruebas: otra tarjeta de prueba', 'c6 test card 2', 'pasivo', 'haber', true, 'prohibida', 'prohibida')
  on conflict (codigo) do nothing;
  perform fn_tarjeta_alta('9996', '2100-9996', 'c6-pruebas: tarjeta');
  perform fn_tarjeta_alta('9995', '2100-9995', 'c6-pruebas: otra tarjeta');
  perform fn_mapeo_categoria('material', '5100');
  perform fn_mapeo_metodo_pago('credito', 'tarjeta');
  perform fn_mapeo_metodo_pago('cuenta_proveedor', 'cuenta_proveedor');
  perform fn_mapeo_metodo_pago('zelle', 'banco', '1098');
  perform fn_mapeo_metodo_pago('debito', 'banco', '1098');
  for v_t in select distinct fn_puente_normalizar(p.tipo) from proyectos p
              where p.id in (current_setting('mx6.obra'), current_setting('mx6.obra2')) loop
    perform fn_mapeo_tipo_proyecto(v_t, coalesce((select m.cuenta from mapeo_tipo_proyecto m where m.tipo = v_t),
                                                 case v_t when 'comercial' then '4020' when 'servicio' then '4030' else '4010' end));
  end loop;
  -- Los descriptores como vienen en c6-banco.sql (1.13).
  for r in select * from (values
      ('nomina',          '(GUSTO|PAYROLL|\mADP\M|PAYCHEX)'),
      ('cargo_banco',     '(SERVICE (FEE|CHARGE)|MONTHLY (SERVICE |MAINTENANCE )?FEE|MAINTENANCE FEE|WIRE (TRANSFER )?FEE|'
                          || 'OVERDRAFT|INSUFFICIENT FUNDS|\mNSF\M|ATM FEE|FOREIGN TRANSACTION FEE|ANNUAL (MEMBERSHIP )?FEE|'
                          || 'LATE (PAYMENT )?FEE|RETURNED PAYMENT FEE|STOP PAYMENT FEE|RETURN(ED)? (DEPOSITED )?ITEM (FEE|CHARGE)|'
                          || 'RETURNED (CHECK|DEPOSIT) (FEE|CHARGE))'),
      ('interes',         '(INTEREST (PAYMENT|EARNED|PAID|CREDIT)|^INTEREST$)'),
      ('interes_tarjeta', '(INTEREST CHARGE|FINANCE CHARGE|PURCHASE INTEREST)'),
      ('cajero',          '(\mATM\M|CASH WITHDRAWAL|WITHDRAWAL CASH)'),
      ('zelle_edgar',     'ZELLE (PAYMENT )?FROM EDGAR'),
      ('transferencia',   '(ONLINE TRANSFER|TRANSFER (TO|FROM)|BOOK TRANSFER|\mXFER\M)'),
      ('pago_tarjeta',    '(AMERICAN EXPRESS|\mAMEX\M|CREDIT CA?RD|CARD ?MEMBER SERV|CARD SERVICES|PAYMENT TO .*CARD)'),
      ('pago_recibido',   '(\mPAYMENT\M|\mPYMT\M|\mPMT\M|THANK YOU)'),
      ('cheque_devuelto', '(RETURNED (ITEM|CHECK|DEPOSIT)|DEPOSITED ITEM RETURNED|RETURN(ED)? DEPOSIT|CHARGEBACK|REVERSAL)')) as v(clave, patron)
  loop
    -- (Ronda 4b: solo el que no está ya así —fn_banco_descriptor lo
    -- escribe aunque sea igual, con su historial—: con los de c6 tal cual,
    -- eran diez escrituras por prueba, un segundo de la suite con un año de
    -- banco.)
    continue when exists (select 1 from banco_descriptores d
                           where d.clave = r.clave and d.patron = fn_banco_limpio(r.patron)
                             and (d.cuenta is not distinct from case r.clave when 'cargo_banco' then '6130' when 'interes' then '4910'
                                                                              when 'interes_tarjeta' then '7100' end
                                  or r.clave not in ('cargo_banco', 'interes', 'interes_tarjeta')));
    perform fn_banco_descriptor(r.clave, r.patron, case r.clave when 'cargo_banco' then '6130' when 'interes' then '4910'
                                                                when 'interes_tarjeta' then '7100' end);
  end loop;
  v_prov := fn_proveedor_alta('C6 PRUEBAS SUPPLY', 'Net 30', array['c6 pruebas supply inc']);
  return jsonb_build_object('proveedor', v_prov);
end $$;
revoke execute on function pg_temp.c6_montar() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_recibo(p jsonb) returns bigint
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_id bigint;
  v_f  date := coalesce((p->>'fecha')::date, current_setting('mx6.desde')::date + 4);
begin
  insert into recibos (id, proyecto_id, ruta, total, proveedor, notas, estado, autor_id, creado, fecha, categoria, subtotal, tax,
                       num_recibo, metodo_pago, ultimos4)
  overriding system value
  values ((p->>'id')::bigint, coalesce(p->>'proyecto_id', current_setting('mx6.obra')),
          coalesce(p->>'ruta', 'recibos/c6-pruebas/' || (p->>'id') || '.jpg'), (p->>'total')::numeric,
          coalesce(p->>'proveedor', 'C6 PRUEBAS SUPPLY'), 'c6-pruebas', 'leido',
          nullif(current_setting('mx6.dueno', true), '')::uuid, (v_f + time '12:00') at time zone 'America/New_York',
          v_f, 'material', null, null, coalesce(p->>'num_recibo', 'C6-' || (p->>'id')),
          coalesce(p->>'metodo_pago', 'credito'), case when p ? 'ultimos4' then p->>'ultimos4'
                                                        when coalesce(p->>'metodo_pago', 'credito') = 'credito' then '9996' end)
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function pg_temp.c6_recibo(jsonb) from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_mov(p_cuenta text, p_fitid text) returns uuid
language sql
stable
set search_path = public, pg_temp
as $$ select m.id from movimientos_banco m where m.cuenta = p_cuenta and m.id_externo = p_fitid order by m.importado_el desc limit 1 $$;
revoke execute on function pg_temp.c6_mov(text, text) from public, anon, authenticated, service_role;

-- El asiento vivo de un papel.
create or replace function pg_temp.c6_vivo(p_tabla text, p_id text) returns uuid
language sql
stable
set search_path = public, pg_temp
as $$
  select a.id from asientos a
   where a.origen_tabla = p_tabla and a.origen_id = p_id and a.camino not in ('reverso', 'reverso_automatico')
     and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
   order by a.cadena_pos desc limit 1
$$;
revoke execute on function pg_temp.c6_vivo(text, text) from public, anon, authenticated, service_role;
-- Un estado de cuenta OFX 1.x (SGML, como el QFX de Chase y de Amex).
--   p_tipo 'banco' | 'tarjeta'; p_movs: [{tipo, fecha, monto, id, nombre, memo, cheque, fecha_usuario}]
create or replace function pg_temp.c6_qfx(p_tipo text, p_acctid text, p_desde date, p_hasta date, p_saldo numeric, p_movs jsonb,
                                          p_saldo_al date default null)
returns text
language sql
immutable
as $$
  select concat_ws(E'\r\n',
    'OFXHEADER:100', 'DATA:OFXSGML', 'VERSION:102', 'SECURITY:NONE', 'ENCODING:USASCII', 'CHARSET:1252', 'COMPRESSION:NONE',
    'OLDFILEUID:NONE', 'NEWFILEUID:NONE', '',
    '<OFX>',
    '<SIGNONMSGSRSV1><SONRS><STATUS><CODE>0<SEVERITY>INFO</STATUS><DTSERVER>' || to_char(p_hasta, 'YYYYMMDD') || '120000[0:GMT]'
      || '<LANGUAGE>ENG<FI><ORG>B1<FID>10898</FI><INTU.BID>10898</SONRS></SIGNONMSGSRSV1>',
    case when p_tipo = 'banco'
         then '<BANKMSGSRSV1><STMTTRNRS><TRNUID>1<STATUS><CODE>0<SEVERITY>INFO</STATUS><STMTRS><CURDEF>USD'
              || '<BANKACCTFROM><BANKID>267084131<ACCTID>' || p_acctid || '<ACCTTYPE>CHECKING</BANKACCTFROM>'
         else '<CREDITCARDMSGSRSV1><CCSTMTTRNRS><TRNUID>1<STATUS><CODE>0<SEVERITY>INFO</STATUS><CCSTMTRS><CURDEF>USD'
              || '<CCACCTFROM><ACCTID>' || p_acctid || '</CCACCTFROM>' end,
    '<BANKTRANLIST>',
    '<DTSTART>' || to_char(p_desde, 'YYYYMMDD') || '120000[0:GMT]',
    '<DTEND>' || to_char(p_hasta, 'YYYYMMDD') || '120000[0:GMT]',
    (select string_agg(concat_ws(E'\r\n', '<STMTTRN>', '<TRNTYPE>' || (m->>'tipo'),
                                 '<DTPOSTED>' || to_char((m->>'fecha')::date, 'YYYYMMDD') || '120000[0:GMT]',
                                 case when m ? 'fecha_usuario' then '<DTUSER>' || to_char((m->>'fecha_usuario')::date, 'YYYYMMDD') end,
                                 '<TRNAMT>' || (m->>'monto'),
                                 '<FITID>' || (m->>'id'),
                                 case when m ? 'cheque' then '<CHECKNUM>' || (m->>'cheque') end,
                                 '<NAME>' || (m->>'nombre'),
                                 case when m ? 'memo' then '<MEMO>' || (m->>'memo') end,
                                 '</STMTTRN>'), E'\r\n' order by o)
       from jsonb_array_elements(p_movs) with ordinality as x(m, o)),
    '</BANKTRANLIST>',
    case when p_saldo is not null
         then '<LEDGERBAL><BALAMT>' || p_saldo::text || '<DTASOF>' || to_char(coalesce(p_saldo_al, p_hasta), 'YYYYMMDD') || '120000[0:GMT]</LEDGERBAL>'
              || '<AVAILBAL><BALAMT>' || (p_saldo - 100)::text || '<DTASOF>' || to_char(p_hasta, 'YYYYMMDD') || '</AVAILBAL>' end,
    case when p_tipo = 'banco' then '</STMTRS></STMTTRNRS></BANKMSGSRSV1>' else '</CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1>' end,
    '</OFX>', '')
$$;

-- El mismo en OFX 2.x (XML, todo cerrado).
create or replace function pg_temp.c6_ofx_xml(p_tipo text, p_acctid text, p_desde date, p_hasta date, p_saldo numeric, p_movs jsonb)
returns text
language sql
immutable
as $$
  select concat_ws(E'\n',
    '<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
    '<?OFX OFXHEADER="200" VERSION="220" SECURITY="NONE" OLDFILEUID="NONE" NEWFILEUID="NONE"?>',
    '<OFX>',
    '  <SIGNONMSGSRSV1><SONRS><STATUS><CODE>0</CODE><SEVERITY>INFO</SEVERITY></STATUS><DTSERVER>' || to_char(p_hasta, 'YYYYMMDD')
      || '</DTSERVER><LANGUAGE>ENG</LANGUAGE></SONRS></SIGNONMSGSRSV1>',
    case when p_tipo = 'banco'
         then '  <BANKMSGSRSV1><STMTTRNRS><TRNUID>1</TRNUID><STATUS><CODE>0</CODE><SEVERITY>INFO</SEVERITY></STATUS><STMTRS>'
              || '<CURDEF>USD</CURDEF><BANKACCTFROM><BANKID>267084131</BANKID><ACCTID>' || p_acctid
              || '</ACCTID><ACCTTYPE>SAVINGS</ACCTTYPE></BANKACCTFROM>'
         else '  <CREDITCARDMSGSRSV1><CCSTMTTRNRS><TRNUID>1</TRNUID><STATUS><CODE>0</CODE><SEVERITY>INFO</SEVERITY></STATUS>'
              || '<CCSTMTRS><CURDEF>USD</CURDEF><CCACCTFROM><ACCTID>' || p_acctid || '</ACCTID></CCACCTFROM>' end,
    '    <BANKTRANLIST>',
    '      <DTSTART>' || to_char(p_desde, 'YYYYMMDD') || '</DTSTART>',
    '      <DTEND>' || to_char(p_hasta, 'YYYYMMDD') || '</DTEND>',
    (select string_agg('      <STMTTRN><TRNTYPE>' || (m->>'tipo') || '</TRNTYPE><DTPOSTED>'
                       || to_char((m->>'fecha')::date, 'YYYYMMDD') || '000000.000[-5:EST]</DTPOSTED><TRNAMT>' || (m->>'monto')
                       || '</TRNAMT><FITID>' || (m->>'id') || '</FITID><NAME>' || (m->>'nombre') || '</NAME>'
                       || coalesce('<MEMO>' || (m->>'memo') || '</MEMO>', '') || '</STMTTRN>', E'\n' order by o)
       from jsonb_array_elements(p_movs) with ordinality as x(m, o)),
    '    </BANKTRANLIST>',
    case when p_saldo is not null
         then '    <LEDGERBAL><BALAMT>' || p_saldo::text || '</BALAMT><DTASOF>' || to_char(p_hasta, 'YYYYMMDD') || '</DTASOF></LEDGERBAL>' end,
    case when p_tipo = 'banco' then '  </STMTRS></STMTTRNRS></BANKMSGSRSV1>' else '  </CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1>' end,
    '</OFX>')
$$;

-- ---------------------------------------------------------------------
-- El escenario de casi todas las pruebas, dentro de su subtransacción:
-- las cuentas y reglas de prueba (c6_montar), tres recibos (uno con la
-- tarjeta ····9996, uno por Zelle desde el banco de prueba, uno a cuenta
-- del proveedor), cuatro facturas de la obra y un cobro de 1,500.00 al
-- banco de prueba. Y los tres estados de cuenta del mes (D = el primer
-- día del mes abierto más antiguo):
--   · el banco 1098 (QFX de Chase, SGML): el cheque 1043 que venía de
--     septiembre, el Zelle al proveedor, el depósito del cobro, un Zelle
--     de un cliente (con &amp;), uno de Edgar, el cajero, el pago de la
--     Amex, la nómina de Gusto, el pase a la reserva, el pago al
--     proveedor, un depósito remoto y el cargo mensual del banco;
--   · la tarjeta ····9996 (QFX de Amex, CCSTMTRS): Home Depot (con su
--     ticket), una compra al proveedor sin ticket, el pago desde el
--     banco, el interés y la cuota anual;
--   · la reserva 1097 (OFX 2.x, XML): el pase desde el banco y el interés.
-- ---------------------------------------------------------------------
create or replace function pg_temp.c6_escenario() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  d       date := current_setting('mx6.desde')::date;
  v_obra  text := current_setting('mx6.obra');
  v_m     jsonb;
  v_cobro jsonb;
begin
  v_m := pg_temp.c6_montar();
  perform pg_temp.c6_recibo(jsonb_build_object('id', -660001, 'total', 245.37, 'fecha', d + 4, 'proveedor', 'THE HOME DEPOT',
                                               'num_recibo', 'C6-HD-1'));
  perform pg_temp.c6_recibo(jsonb_build_object('id', -660002, 'total', 310.00, 'fecha', d + 6, 'metodo_pago', 'zelle'));
  perform pg_temp.c6_recibo(jsonb_build_object('id', -660003, 'total', 850.00, 'fecha', d + 8, 'metodo_pago', 'cuenta_proveedor'));
  insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
  values (-660001, v_obra, 'C6-1', d + 2, 3200.50, 0), (-660002, v_obra, 'C6-2', d + 3, 1000.00, 0),
         (-660003, v_obra, 'C6-3', d + 3, 777.77, 0), (-660004, v_obra, 'C6-4', d + 1, 5000.00, 0);
  v_cobro := fn_cobro_registrar(jsonb_build_object(
               'fecha', (d + 9)::text, 'monto', '1500.00', 'cuenta', '1098', 'medio', 'cheque', 'referencia', 'C6-5521',
               'duplicado_confirmado', 'c6-pruebas: dato de prueba',
               'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -660004, 'monto', '1500.00'))));
  return v_m || jsonb_build_object('cobro', v_cobro->>'cobro');
end $$;
revoke execute on function pg_temp.c6_escenario() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_chase() returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select pg_temp.c6_qfx('banco', '000000001098', d, d + 27, -396.73, jsonb_build_array(
    jsonb_build_object('tipo', 'CHECK', 'fecha', d + 1, 'monto', '-1200.00', 'id', 'C6C1', 'nombre', 'CHECK 1043', 'cheque', '1043'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 7, 'monto', '-310.00', 'id', 'C6C2', 'nombre', 'ZELLE PAYMENT TO C6 PRUEBAS',
                       'memo', 'INV C6-660002'),
    jsonb_build_object('tipo', 'DEP', 'fecha', d + 10, 'monto', '1500.00', 'id', 'C6C3', 'nombre', 'DEPOSIT', 'memo', 'CHECK C6-5521'),
    jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 14, 'monto', '3200.50', 'id', 'C6C4', 'nombre', 'ZELLE FROM JOHN SMITH &amp; SONS'),
    jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 15, 'monto', '1000.00', 'id', 'C6C5', 'nombre', 'ZELLE FROM EDGAR M'),
    jsonb_build_object('tipo', 'ATM', 'fecha', d + 16, 'monto', '-200.00', 'id', 'C6C6', 'nombre', 'ATM WITHDRAWAL 1234 MAIN ST'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 18, 'monto', '-500.00', 'id', 'C6C7', 'nombre', 'AMERICAN EXPRESS ACH PMT'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 19, 'monto', '-4000.00', 'id', 'C6C8', 'nombre', 'GUSTO PAYROLL'),
    jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 20, 'monto', '1777.77', 'id', 'C6C12', 'nombre', 'REMOTE DEPOSIT'),
    jsonb_build_object('tipo', 'XFER', 'fecha', d + 24, 'monto', '-2000.00', 'id', 'C6C9', 'nombre', 'ONLINE TRANSFER TO SAV XXXXXX1097'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 26, 'monto', '-850.00', 'id', 'C6C10', 'nombre', 'BILL PAY C6 PRUEBAS SUPPLY'),
    jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 27, 'monto', '-15.00', 'id', 'C6C11', 'nombre', 'MONTHLY SERVICE FEE')))
    from (select current_setting('mx6.desde')::date as d) x
$$;
revoke execute on function pg_temp.c6_chase() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_amex() returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select pg_temp.c6_qfx('tarjeta', '372700000009996', d - 7, d + 22, -1173.26, jsonb_build_array(
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'fecha_usuario', d + 4, 'monto', '-245.37', 'id', 'C6A1',
                       'nombre', 'THE HOME DEPOT #6311'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 11, 'monto', '-1320.55', 'id', 'C6A2', 'nombre', 'C6 PRUEBAS SUPPLY'),
    jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 19, 'monto', '500.00', 'id', 'C6A3', 'nombre', 'PAYMENT RECEIVED - THANK YOU'),
    jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 22, 'monto', '-12.34', 'id', 'C6A4', 'nombre', 'INTEREST CHARGE ON PURCHASES'),
    jsonb_build_object('tipo', 'FEE', 'fecha', d + 22, 'monto', '-95.00', 'id', 'C6A5', 'nombre', 'ANNUAL MEMBERSHIP FEE')))
    from (select current_setting('mx6.desde')::date as d) x
$$;
revoke execute on function pg_temp.c6_amex() from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_reserva() returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select pg_temp.c6_ofx_xml('banco', '1097', d, d + 27, 2000.42, jsonb_build_array(
    jsonb_build_object('tipo', 'XFER', 'fecha', d + 24, 'monto', '2000.00', 'id', 'C6R1', 'nombre', 'ONLINE TRANSFER FROM CHK XXXXXX1098'),
    jsonb_build_object('tipo', 'INT', 'fecha', d + 27, 'monto', '0.42', 'id', 'C6R2', 'nombre', 'INTEREST PAYMENT')))
    from (select current_setting('mx6.desde')::date as d) x
$$;
revoke execute on function pg_temp.c6_reserva() from public, anon, authenticated, service_role;

-- Importa los tres estados de cuenta (como el dueño, por la API) y casa lo
-- de las cuentas de prueba. Devuelve el resumen del casado.
create or replace function pg_temp.c6_importar_y_casar(p_como_dueno boolean default true) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_c text := pg_temp.c6_chase();
  v_a text := pg_temp.c6_amex();
  v_r text := pg_temp.c6_reserva();
  v_x jsonb;
begin
  if p_como_dueno then
    perform pg_temp.c6_como('dueno');
  end if;
  perform fn_banco_importar_ofx(v_c, '1098', 'c6-pruebas-chase.qfx');
  perform fn_banco_importar_ofx(v_a, null, 'c6-pruebas-amex.qfx');
  perform fn_banco_importar_ofx(v_r, '1097', 'c6-pruebas-reserva.ofx');
  v_x := fn_banco_casar_todo('1098');
  v_x := fn_banco_casar_todo('2100-9996');
  v_x := fn_banco_casar_todo('1097');
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return v_x;
end $$;
revoke execute on function pg_temp.c6_importar_y_casar(boolean) from public, anon, authenticated, service_role;

-- El estado de un movimiento de prueba en una palabra: su estado y, si
-- casó, la clase ('casado:recibo'); si espera, su motivo
-- ('pendiente:nomina').
create or replace function pg_temp.c6_est(p_cuenta text, p_fitid text) returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce((select m.estado || ':' || coalesce(m.casado_clase, m.estado_motivo, '-')
                     from movimientos_banco m where m.cuenta = p_cuenta and m.id_externo = p_fitid
                    order by m.importado_el desc limit 1), 'no_entró')
$$;
revoke execute on function pg_temp.c6_est(text, text) from public, anon, authenticated, service_role;

-- El mes ya amortizado (de verdad) POSTERIOR al mes abierto más antiguo, si
-- lo hay: Edgar amortiza cada mes antes de cerrarlo, y en la marcha en
-- paralelo octubre sigue abierto con noviembre ya amortizado. Amortizar
-- octubre entonces se niega (MX008, la regla): las pruebas que lo
-- amortizan salen «omitida» y lo dicen (la ronda 3 de c6).
create or replace function pg_temp.c6_amortizado_despues() returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select max(a.periodo) from prepagados_amortizaciones a
   where a.vigente and a.periodo > coalesce(nullif(current_setting('mx6.mes', true), ''), '9999-99')
$$;
revoke execute on function pg_temp.c6_amortizado_despues() from public, anon, authenticated, service_role;

-- El reloj fingido y los cierres (como en c4-pruebas): «hoy» en Miami
-- pasa a ser ese día (fn_fecha_miami, dentro de la subtransacción: el
-- MXT00 la devuelve como era), y cerrar hasta un mes cierra en orden la
-- apertura (con un asiento de apertura mínimo de prueba si todavía no
-- hay uno: sin él no se cierra) y los meses hasta ese. Toma el candado de
-- periodos DESPUÉS de los del casado y los recibos (el orden de la app).
create or replace function pg_temp.c6_fingir_hoy(p_hoy date) returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  execute format($f$
    create or replace function public.fn_fecha_miami(t timestamptz) returns date
    language sql stable
    set search_path = public, pg_temp
    as $b$ select greatest((t at time zone 'America/New_York')::date, %L::date) $b$
  $f$, p_hoy);
end $$;
revoke execute on function pg_temp.c6_fingir_hoy(date) from public, anon, authenticated, service_role;

create or replace function pg_temp.c6_cerrar_hasta(p_periodo text) returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_p  periodos;
  v_ap periodos;
  v_q  text;
begin
  perform pg_temp.c6_candados();
  lock table public.periodos in exclusive mode;
  select * into v_p from periodos where periodo = p_periodo;
  perform pg_temp.c6_fingir_hoy(greatest(v_p.hasta + 1, fn_fecha_miami(now())));
  select * into v_ap from periodos where tipo = 'apertura' and estado = 'abierto' order by desde limit 1;
  if v_ap.periodo is not null
     and not exists (select 1 from asientos a
                      where a.periodo = v_ap.periodo and a.tipo = 'apertura' and a.reversa_a is null
                        and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    perform fn_postear_interno(jsonb_build_object(
      'camino', 'mano', 'tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
      'descripcion', 'c6-pruebas: una apertura mínima para poder cerrar (se deshace)', 'documento_ruta', 'docs/c6-pruebas/apertura.pdf',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1050', 'monto', '1.00'),
                                  jsonb_build_object('cuenta', '3900', 'monto', '-1.00'))));
  end if;
  for v_q in select p.periodo from periodos p
              where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= v_p.desde
              order by p.desde loop
    update periodos set estado = 'cerrado' where periodo = v_q;
  end loop;
end $$;
revoke execute on function pg_temp.c6_cerrar_hasta(text) from public, anon, authenticated, service_role;

-- Lo que dice un cuadre del control del banco de un movimiento (o de lo
-- que sea): 'f' si el detalle lo nombra, 't' si no. Así las pruebas miran
-- SOLO lo suyo aunque el banco de verdad tenga otra cosa en rojo.
create or replace function pg_temp.c6_cuadre(p_vista text, p_periodo text, p_quien text) returns text
language sql
set search_path = public, pg_temp
as $$
  -- (Pide solo ese cuadre, por su nombre: el grupo de vistas que lo
  -- calcula, con un año de banco, tarda de 3 a 4 veces más.)
  select case when exists (select 1
                             from fn_banco_control(p_periodo, array[p_vista]) c
                            where c.vista = p_vista and position(p_quien in coalesce(c.detalle, '')) > 0) then 'f' else 't' end
$$;
revoke execute on function pg_temp.c6_cuadre(text, text, text) from public, anon, authenticated, service_role;

-- (Ronda 5) La DIFERENCIA libro − préstamos en las cuentas de los préstamos
-- de negocio (2540/2550): lo que el libro trae en ellas sin préstamo
-- registrado (la apertura antes de su bloque de los préstamos, un asiento
-- a mano) pone el cuadre 55 en rojo en cuanto una prueba registra el suyo.
-- Las pruebas 162 y 163 miden que no la cambian (antes la 162 pedía el
-- cuadre igual que antes, y con saldo ajeno en la 2540 salía en rojo).
create or replace function pg_temp.c6_dif_prestamos() returns numeric
language sql
stable
set search_path = public, pg_temp
as $$
  select (coalesce(-(select sum(l.monto) from asiento_lineas l where l.cuenta in ('2540', '2550')), 0)
          - coalesce((select sum(x.saldo) from v_prestamos x
                       where x.estado <> 'cancelado' and (x.cuenta in ('2540', '2550') or x.cuenta_largo in ('2540', '2550'))), 0))::numeric(14,2)
$$;
revoke execute on function pg_temp.c6_dif_prestamos() from public, anon, authenticated, service_role;

-- Un asiento de apertura mínimo, si todavía no hay uno (recién pegado): la
-- conciliación de apertura concilia su saldo. Si ya está el de verdad, vale
-- ese (las cuentas de prueba no tienen saldo en él). Con la apertura ya
-- cerrada y sin su asiento, MXT01: la prueba sale omitida.
create or replace function pg_temp.c6_apertura_minima() returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if not exists (select 1 from asientos a where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                   and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    if (select p.estado from periodos p where p.tipo = 'apertura' order by p.desde limit 1) is distinct from 'abierto' then
      raise exception using errcode = 'MXT01';
    end if;
    perform fn_postear(jsonb_build_object('tipo', 'apertura',
      'fecha', (select p.hasta from periodos p where p.tipo = 'apertura' order by p.desde limit 1)::text,
      'descripcion', 'c6-pruebas: apertura de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1097', 'monto', '1.00'),
                                  jsonb_build_object('cuenta', '3900', 'monto', '-1.00'))));
  end if;
end $$;
revoke execute on function pg_temp.c6_apertura_minima() from public, anon, authenticated, service_role;

-- (Ronda 4c) SIN EL AVISO DE LA APERTURA en las cuentas de prueba: con el
-- libro recién pegado (sin asiento de apertura), un depósito o un cheque
-- de los primeros 30 días lleva el aviso de la apertura y TODOS sus botones
-- piden su motivo; así no se ve lo que la prueba mira. Una apertura mínima
-- sin las cuentas de prueba (1050 contra 3900; si ya está la de verdad,
-- vale esa: no tiene las de prueba) deja a 1098 y 1097 sin aviso. Con la
-- apertura cerrada y sin su asiento, MXT01: la prueba sale omitida.
create or replace function pg_temp.c6_sin_aviso() returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if not exists (select 1 from asientos a where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                   and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    if (select p.estado from periodos p where p.tipo = 'apertura' order by p.desde limit 1) is distinct from 'abierto' then
      raise exception using errcode = 'MXT01';
    end if;
    perform fn_postear(jsonb_build_object('tipo', 'apertura',
      'fecha', (select p.hasta from periodos p where p.tipo = 'apertura' order by p.desde limit 1)::text,
      'descripcion', 'c6-pruebas: apertura de prueba sin las cuentas de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1050', 'monto', '1.00'),
                                  jsonb_build_object('cuenta', '3900', 'monto', '-1.00'))));
  end if;
end $$;
revoke execute on function pg_temp.c6_sin_aviso() from public, anon, authenticated, service_role;

-- ¿La huella sellada del candado (es_dueno(), la que mira el control
-- permisos de c2) es la de hoy? 't' o 'f'.
create or replace function pg_temp.c6_candado_igual() returns text
language sql
set search_path = public, pg_temp
as $$
  select case when exists (select 1
                             from (select * from public.fn_libro_huellas() x where x.tipo = 'candado') h
                             full join (select * from public.fn_libro_huellas_calcular() y where y.tipo = 'candado') a
                               on a.objeto = h.objeto
                            where a.md5 is distinct from h.md5) then 'f' else 't' end
$$;
revoke execute on function pg_temp.c6_candado_igual() from public, anon, authenticated, service_role;

-- (Ronda 4) PULSAR UN BOTÓN DE LA BANDEJA con sus argumentos tal cual (lo
-- que hace la app con una opción que no pide nada) y deshacerlo: 'ok' si
-- entra, o el código del error. Dentro de su subtransacción (MXT02).
create or replace function pg_temp.c6_pulsar(o jsonb) returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  a jsonb := coalesce(o->'args', '{}'::jsonb);
begin
  begin
    case o->>'llamar'
      when 'fn_banco_clasificar' then
        perform fn_banco_clasificar((a->>'p_movimiento')::uuid, a->'p_lineas', a->>'p_motivo');
      when 'fn_banco_casar_con' then
        perform fn_banco_casar_con((a->>'p_movimiento')::uuid, a->'p_con', a->>'p_motivo');
      when 'fn_banco_cobrar' then
        perform fn_banco_cobrar((a->>'p_movimiento')::uuid, a->'p_aplicaciones', a->>'p_notas');
      when 'fn_banco_transferencia' then
        perform fn_banco_transferencia((a->>'p_movimiento')::uuid, a->>'p_cuenta', a->>'p_motivo');
      when 'fn_banco_devolver' then
        perform fn_banco_devolver((a->>'p_movimiento')::uuid, (a->>'p_cobro')::uuid, a->>'p_motivo');
      when 'fn_banco_pagar_proveedor' then
        perform fn_banco_pagar_proveedor((a->>'p_movimiento')::uuid, (a->>'p_proveedor')::uuid, a->'p_partidas');
      when 'fn_banco_duplicado' then
        perform fn_banco_duplicado((a->>'p_movimiento')::uuid, (a->>'p_es_el_mismo')::boolean, a->>'p_motivo');
      when 'fn_banco_ignorar' then
        perform fn_banco_ignorar((a->>'p_movimiento')::uuid, a->>'p_motivo');
      when 'fn_prestamo_cuota' then
        perform fn_prestamo_cuota((a->>'p_prestamo')::uuid, (a->>'p_movimiento')::uuid, (a->>'p_fecha')::date, a->>'p_monto',
                                  a->>'p_capital', a->>'p_interes', a->>'p_motivo');
      else
        return 'sin_llamar:' || coalesce(o->>'llamar', '-');
    end case;
    raise exception using errcode = 'MXT02';
  exception
    when sqlstate 'MXT02' then return 'ok';
    when others then return sqlstate;
  end;
end $$;
revoke execute on function pg_temp.c6_pulsar(jsonb) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- Preparación: solo lee. Lo que usan todas las pruebas, en ajustes de la
-- sesión (mx6.*), que mueren con ella.
-- ---------------------------------------------------------------------
do $$
declare
  v_dueno  uuid;
  v_equipo uuid;
  v_obra   text;
  v_obra2  text;
  v_mes    text;
  v_desde  date;
  v_sig    text;
begin
  select id into v_dueno from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_equipo from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  select p.id into v_obra from proyectos p where nullif(btrim(p.tipo), '') is not null order by p.id limit 1;
  select p.id into v_obra2 from proyectos p where nullif(btrim(p.tipo), '') is not null and p.id <> v_obra order by p.id limit 1;
  select periodo, desde into v_mes, v_desde from periodos
   where tipo = 'mes' and estado = 'abierto' and desde >= fn_puente_corte() order by desde limit 1;
  select periodo into v_sig from periodos
   where tipo = 'mes' and estado = 'abierto' and desde = (v_desde + interval '1 month')::date;
  perform set_config('mx6.dueno',  coalesce(v_dueno::text, ''), false);
  perform set_config('mx6.equipo', coalesce(v_equipo::text, ''), false);
  perform set_config('mx6.obra',   coalesce(v_obra, ''), false);
  perform set_config('mx6.obra2',  coalesce(v_obra2, coalesce(v_obra, '')), false);
  perform set_config('mx6.mes',    coalesce(v_mes, ''), false);
  perform set_config('mx6.desde',  coalesce(v_desde::text, ''), false);
  perform set_config('mx6.sig',    coalesce(v_sig, ''), false);
  perform set_config('mx6.foto',   pg_temp.c6_foto(), false);
end $$;


-- =====================================================================
-- Los archivos del banco
-- =====================================================================

-- 1. El QFX de Chase (OFX 1.x, SGML), subido por Edgar desde la app: entra
--    ENTERO (su texto y su sha256), con sus 12 movimientos como los dijo el
--    banco (el cheque con su número, el «&amp;» como «&», el signo del
--    libro), el saldo final de LEDGERBAL (no el disponible, AVAILBAL) a su
--    fecha, y quién lo subió. Y al casar, cada uno con lo suyo: el Zelle
--    al proveedor con su ticket, el depósito con su cobro, el pago de la
--    Amex y el pase a la reserva como transferencias, el cargo del banco a
--    6130; lo demás espera con su motivo.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx6.dueno', true), '')::uuid;
  v_obt   text;
  v_esp   text := 'filas=12 nuevas=12 formato=ofx_sgml saldo=-396.73 al=+27 sha=t texto=t quien=dueño cheque=1043 amp=t '
                  'C1=pendiente:sin_ticket C2=casado:recibo C3=casado:cobro C4=pendiente:deposito_sin_cobro '
                  'C5=pendiente:aporte_edgar C6=pendiente:cajero C7=casado:transferencia C8=pendiente:nomina '
                  'C12=pendiente:deposito_sin_cobro C9=casado:transferencia C10=pendiente:pago_proveedor C11=casado:regla';
  v_x     jsonb;
  v_m     jsonb;
  v_c1    uuid;
  v_e1    text;
  v_txt   text;
begin
  if v_dueno is null or current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (1, 'QFX de Chase: entra entero, cada movimiento como lo dijo el banco, y casa lo que casa', v_esp,
                                 'omitida: falta dueño o mes abierto', null);
    return;
  end if;
  begin
    v_m := pg_temp.c6_escenario();
    v_txt := pg_temp.c6_chase();
    perform pg_temp.c6_como('dueno');
    v_x := fn_banco_importar_ofx(v_txt, '1098', 'c6-pruebas-chase.qfx');
    execute 'reset role';
    perform pg_temp.c6_importar_y_casar();
    select format('filas=%s nuevas=%s formato=%s saldo=%s al=+%s sha=%s texto=%s quien=%s cheque=%s amp=%s',
                  v_x->>'filas_leidas', v_x->>'filas_nuevas', a.formato, a.saldo, a.saldo_al - current_setting('mx6.desde')::date,
                  a.sha256 = encode(sha256(convert_to(v_txt, 'UTF8')), 'hex'), a.texto = v_txt,
                  case when a.importado_por = v_dueno then 'dueño' else coalesce(a.importado_por::text, '-') end,
                  (select m.cheque from movimientos_banco m where m.archivo_id = a.id and m.id_externo = 'C6C1'),
                  exists (select 1 from movimientos_banco m where m.archivo_id = a.id and m.descripcion = 'ZELLE FROM JOHN SMITH & SONS'))
      into v_obt
      from archivos_banco a where a.id = (v_x->>'archivo')::uuid;
    -- (El cheque 1043 no dice a quién: sin ticket; con proveedores de verdad
    -- a los que se les debe al menos eso, se propone además como un abono a
    -- ellos, «pago_proveedor» sin nombre. Los dos son lo que la prueba mira:
    -- que no casa con nada.)
    v_c1 := pg_temp.c6_mov('1098', 'C6C1');
    v_e1 := case when (select m.estado || ':' || coalesce(m.estado_motivo, '-') from movimientos_banco m where m.id = v_c1)
                      = 'pendiente:pago_proveedor'
                      and not exists (select 1 from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                                       where m.id = v_c1 and o->'args'->>'p_proveedor' = v_m->>'proveedor')
                 then 'pendiente:sin_ticket' end;
    v_obt := v_obt || ' ' || (select string_agg(replace(x, 'C6C', 'C') || '='
                                                || case when x = 'C6C1' and v_e1 is not null then v_e1 else pg_temp.c6_est('1098', x) end,
                                                ' ' order by o)
                                from unnest(array['C6C1', 'C6C2', 'C6C3', 'C6C4', 'C6C5', 'C6C6', 'C6C7', 'C6C8', 'C6C12', 'C6C9',
                                                  'C6C10', 'C6C11']) with ordinality as t(x, o));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (1, 'QFX de Chase: entra entero, cada movimiento como lo dijo el banco, y casa lo que casa', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 2. El QFX de la Amex (CREDITCARDMSGSRSV1 / CCSTMTRS), sin decir la
--    cuenta: va a la tarjeta ····9996 por sus 4 últimos (tabla tarjetas);
--    una compra en negativo (Cr 2100-9996), el pago en positivo; el saldo
--    que se debe en negativo, a la fecha de corte del statement; la fecha
--    de la compra (DTUSER) aparte de la del banco. Home Depot casa con su
--    ticket, el pago con el lado del banco, la cuota anual a 6130; la
--    compra al proveedor sin ticket y el interés esperan.
do $$
declare
  v_obt   text;
  v_esp   text := 'cuenta=2100-9996 tipo=tarjeta u4=9996 filas=5 saldo=-1173.26 al=+22 compra=-245.37 dtuser=+4 '
                  'A1=casado:recibo A2=pendiente:sin_ticket A3=casado:transferencia A4=pendiente:interes_tarjeta A5=casado:regla';
  v_x     jsonb;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (2, 'QFX de la Amex: a su tarjeta por los 4 últimos, compras en negativo, saldo al corte', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    select format('cuenta=%s tipo=%s u4=%s filas=%s saldo=%s al=+%s compra=%s dtuser=+%s', a.cuenta,
                  (select case when c.tipo = 'pasivo' then 'tarjeta' else c.tipo end from cuentas c where c.codigo = a.cuenta),
                  a.ultimos4, a.filas_leidas, a.saldo, a.saldo_al - current_setting('mx6.desde')::date,
                  (select m.monto from movimientos_banco m where m.archivo_id = a.id and m.id_externo = 'C6A1'),
                  (select m.fecha_transaccion - current_setting('mx6.desde')::date from movimientos_banco m
                    where m.archivo_id = a.id and m.id_externo = 'C6A1'))
      into v_obt
      from archivos_banco a where a.nombre = 'c6-pruebas-amex.qfx';
    v_obt := v_obt || ' ' || (select string_agg(replace(x, 'C6A', 'A') || '=' || pg_temp.c6_est('2100-9996', x), ' ' order by x)
                                from unnest(array['C6A1', 'C6A2', 'C6A3', 'C6A4', 'C6A5']) x);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (2, 'QFX de la Amex: a su tarjeta por los 4 últimos, compras en negativo, saldo al corte', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 3. Un OFX 2.x (XML, todo cerrado, fechas con zona «[-5:EST]»): la
--    reserva. Mismo resultado que el SGML: el pase desde el banco casa con
--    su otro lado (la misma transferencia, un asiento) y el interés va
--    solo a 4910 (regla fija: tipo INT, entra dinero y lo dice el
--    descriptor).
do $$
declare
  v_obt text;
  v_esp text := 'formato=ofx_xml filas=2 saldo=2000.42 R1=casado:transferencia R2=casado:regla interes=4910:-0.42 un_asiento=t';
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (3, 'OFX 2.x (XML): se lee igual; la transferencia es un asiento; el interés, a 4910 solo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    select format('formato=%s filas=%s saldo=%s', a.formato, a.filas_leidas, a.saldo) into v_obt
      from archivos_banco a where a.nombre = 'c6-pruebas-reserva.ofx';
    v_obt := v_obt || format(' R1=%s R2=%s interes=%s un_asiento=%s', pg_temp.c6_est('1097', 'C6R1'), pg_temp.c6_est('1097', 'C6R2'),
                             (select l.cuenta || ':' || l.monto from asiento_lineas l
                               where l.asiento_id = (select m.asiento_id from movimientos_banco m
                                                      where m.id = pg_temp.c6_mov('1097', 'C6R2'))
                                 and l.cuenta <> '1097'),
                             (select m1.asiento_id = m2.asiento_id from movimientos_banco m1, movimientos_banco m2
                               where m1.id = pg_temp.c6_mov('1097', 'C6R1') and m2.id = pg_temp.c6_mov('1098', 'C6C9')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (3, 'OFX 2.x (XML): se lee igual; la transferencia es un asiento; el interés, a 4910 solo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 4. IDEMPOTENTE: el mismo archivo otra vez no entra (su sha256: «ya
--    estaba», con el resumen de la primera vez), y el mismo archivo con
--    otro nombre tampoco: no hay un movimiento de más ni un archivo de más.
do $$
declare
  v_obt text;
  v_esp text := 'segunda=ya_estaba otra_vez=ya_estaba archivos=1 movimientos=12';
  v_x   jsonb;
  v_y   jsonb;
  v_txt text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (4, 'el mismo archivo dos veces entra una', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_txt := pg_temp.c6_chase();
    perform fn_banco_importar_ofx(v_txt, '1098', 'c6-pruebas-chase.qfx');
    v_x := fn_banco_importar_ofx(v_txt, '1098', 'c6-pruebas-chase.qfx');
    v_y := fn_banco_importar_ofx(v_txt, null, 'c6-pruebas-chase (1).qfx');
    v_obt := format('segunda=%s otra_vez=%s archivos=%s movimientos=%s',
                    case when (v_x->>'ya_estaba')::boolean then 'ya_estaba' else 'entró' end,
                    case when (v_y->>'ya_estaba')::boolean then 'ya_estaba' else 'entró' end,
                    (select count(*) from archivos_banco where cuenta = '1098'),
                    (select count(*) from movimientos_banco where cuenta = '1098'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (4, 'el mismo archivo dos veces entra una', v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 5. UN ARCHIVO QUE SE SOLAPA con otro (el banco exporta del 10 al 5 del
--    mes siguiente): solo entra lo nuevo; lo repetido se cuenta. Y dos
--    movimientos iguales el mismo día en el mismo archivo (dos cafés de
--    4.50) entran los dos: cada uno es un movimiento.
do $$
declare
  v_obt text;
  v_esp text := 'leidas=4 nuevas=2 repetidas=2 dos_cafes=2 total=14';
  v_x   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (5, 'un archivo que se solapa mete solo lo nuevo y cuenta lo repetido', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    v_x := fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 20, d + 35, 100.00, jsonb_build_array(
             jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 26, 'monto', '-850.00', 'id', 'C6C10', 'nombre', 'BILL PAY C6 PRUEBAS SUPPLY'),
             jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 27, 'monto', '-15.00', 'id', 'C6C11', 'nombre', 'MONTHLY SERVICE FEE'),
             jsonb_build_object('tipo', 'POS', 'fecha', d + 28, 'monto', '-4.50', 'id', 'C6C13', 'nombre', 'CAFE C6'),
             jsonb_build_object('tipo', 'POS', 'fecha', d + 28, 'monto', '-4.50', 'id', 'C6C14', 'nombre', 'CAFE C6'))),
             null, 'c6-pruebas-solape.qfx');
    v_obt := format('leidas=%s nuevas=%s repetidas=%s dos_cafes=%s total=%s', v_x->>'filas_leidas', v_x->>'filas_nuevas',
                    v_x->>'filas_repetidas',
                    (select count(*) from movimientos_banco where cuenta = '1098' and descripcion = 'CAFE C6'),
                    (select count(*) from movimientos_banco where cuenta = '1098'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (5, 'un archivo que se solapa mete solo lo nuevo y cuenta lo repetido', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 6. EL MISMO MOVIMIENTO POR PLAID Y POR ARCHIVO entra UNA vez: por Plaid
--    (el monto al revés, como lo da Plaid) y después el archivo con el
--    mismo cargo (misma fecha, monto y descripción): repetido, con los
--    dos ids. Uno con el mismo monto a dos días y otra descripción entra
--    marcado «posible duplicado» y espera (no casa, no se clasifica) hasta
--    que Edgar dice si es el mismo; «es el mismo» lo deja ignorado. Lo
--    pendiente de Plaid (pending) no entra nunca.
do $$
declare
  v_obt text;
  v_esp text := 'plaid=2+1fuera archivo=1nuevo+1repetido ids=2 dup=pendiente:posible_duplicado clasificar=MX008 '
                'dicho=ignorado total=3';
  v_p   jsonb;
  v_a   jsonb;
  v_dup uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (6, 'Plaid y el archivo: el mismo movimiento entra una vez; el parecido espera', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_p := fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1098', 'filas', jsonb_build_array(
             jsonb_build_object('id', 'c6-plaid-1', 'fecha', d + 3, 'plaid_monto', '87.65', 'descripcion', 'C6 FERRETERIA'),
             jsonb_build_object('id', 'c6-plaid-2', 'fecha', d + 4, 'plaid_monto', '12.00', 'descripcion', 'C6 CAFE', 'pendiente', true),
             jsonb_build_object('id', 'c6-plaid-3', 'fecha', d + 5, 'plaid_monto', '-40.00', 'descripcion', 'C6 REEMBOLSO'))));
    v_a := fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, 1000.00, jsonb_build_array(
             jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-87.65', 'id', 'C6P1', 'nombre', 'C6 FERRETERIA'),
             jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 7, 'monto', '40.00', 'id', 'C6P2', 'nombre', 'C6 REEMBOLSO CREDIT'))),
             '1098', 'c6-pruebas-plaid.qfx');
    v_dup := pg_temp.c6_mov('1098', 'C6P2');
    perform fn_banco_casar_todo('1098');
    begin
      perform fn_banco_clasificar(v_dup, '[{"cuenta": "6130"}]'::jsonb, 'c6-pruebas');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('plaid=%s+%sfuera archivo=%snuevo+%srepetido ids=%s dup=%s clasificar=%s', v_p->>'filas_nuevas', v_p->>'filas_fuera',
                    v_a->>'filas_nuevas', v_a->>'filas_repetidas',
                    (select count(*) from movimientos_banco_ids i where i.movimiento_id = pg_temp.c6_mov('1098', 'c6-plaid-1')),
                    pg_temp.c6_est('1098', 'C6P2'), v_x);
    perform fn_banco_duplicado(v_dup, true, 'c6-pruebas: es el mismo reembolso');
    v_obt := v_obt || format(' dicho=%s total=%s', (select m.estado from movimientos_banco m where m.id = v_dup),
                             (select count(*) from movimientos_banco where cuenta = '1098'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (6, 'Plaid y el archivo: el mismo movimiento entra una vez; el parecido espera', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 7. UN ARCHIVO QUE NO SE PUEDE LEER no entra (nada, ni el archivo) y dice
--    por qué en español: vacío, que no es OFX, sin <OFX>, dos cuentas en
--    uno, sin la lista de movimientos, una fecha rota, un monto con tres
--    decimales, otra moneda, un movimiento sin FITID ni tipo… MX009 (MX005
--    el monto).
do $$
declare
  v_obt  text := '';
  v_esp  text := 'vacio=MX009 no_ofx=MX009 sin_ofx=MX009 dos=MX009 sin_lista=MX009 fecha=MX009 monto=MX005 moneda=MX009 '
                 'sin_tipo=MX009 espanol=t archivos=0';
  v_base text;
  v_k    text;
  v_t    text;
  v_x    text;
  v_es   boolean := true;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (7, 'un archivo malo no entra y dice por qué en español (MX009)', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_base := pg_temp.c6_qfx('banco', '000000001098', d, d + 9, 10.00, jsonb_build_array(
                jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-1.00', 'id', 'C6M1', 'nombre', 'C6 MAL')));
    for v_k, v_t in select * from (values
        ('vacio', '   '),
        ('no_ofx', 'Fecha,Descripcion,Monto' || chr(10) || '10/03/2026,HOME DEPOT,-12.00'),
        ('sin_ofx', 'OFXHEADER:100' || chr(10) || 'DATA:OFXSGML' || chr(10) || '<BANKMSGSRSV1>'),
        ('dos', replace(v_base, '</BANKMSGSRSV1>', '</BANKMSGSRSV1><BANKMSGSRSV1><STMTTRNRS><STMTRS></STMTRS></STMTTRNRS></BANKMSGSRSV1>')),
        ('sin_lista', regexp_replace(v_base, '<BANKTRANLIST>.*</BANKTRANLIST>', '')),
        ('fecha', replace(v_base, '<DTPOSTED>' || to_char(d + 3, 'YYYYMMDD'), '<DTPOSTED>2026-1')),
        ('monto', replace(v_base, '<TRNAMT>-1.00', '<TRNAMT>-1.005')),
        ('moneda', replace(v_base, '<CURDEF>USD', '<CURDEF>MXN')),
        ('sin_tipo', replace(v_base, '<TRNTYPE>DEBIT', ''))) as x(k, t) loop
      begin
        perform fn_banco_importar_ofx(v_t, '1098', 'c6-pruebas-malo.qfx');
        v_x := 'entró';
      exception when others then
        v_x := sqlstate;
        v_es := v_es and (sqlerrm ~* '(archivo|monto|decimales|centavos|falta|cuenta)');
      end;
      v_obt := v_obt || v_k || '=' || v_x || ' ';
    end loop;
    v_obt := v_obt || format('espanol=%s archivos=%s', v_es, (select count(*) from archivos_banco where nombre = 'c6-pruebas-malo.qfx'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (7, 'un archivo malo no entra y dice por qué en español (MX009)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- El casado
-- =====================================================================

-- 8. TARJETA ↔ RECIBO, automático y con rastro: el cargo de Home Depot en
--    la tarjeta casa con la línea de 2100-9996 del asiento del ticket (el
--    que puso c3), por el mismo monto, con la fecha del ticket a menos de
--    3 días; queda dicho con qué regla, que fue automático, cuándo, y en
--    banco_historial (antes pendiente, después casado). No se postea nada
--    nuevo: el gasto ya entró con el ticket.
do $$
declare
  v_obt text;
  v_esp text := 'estado=casado clase=recibo ref=-660001 regla=R1 auto=t asiento=el_del_recibo lineas=1 asientos_nuevos=0 '
                'historial=pendiente>casado';
  v_m   uuid;
  v_n   bigint;
  v_p0  bigint;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (8, 'tarjeta ↔ recibo: casa sola con el asiento del ticket, con su regla y su rastro', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    -- (Lo de la prueba, no lo de la base: con el banco en uso ya hay
    -- casados que postearon, y restarlos todos daba negativo.)
    v_n := (select count(*) from asientos);
    v_p0 := (select count(*) from banco_casados c where c.posteado and c.deshecho_el is null);
    perform fn_banco_importar_ofx(pg_temp.c6_amex(), null, 'c6-pruebas-amex.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6A1');
    select format('estado=%s clase=%s ref=%s regla=%s auto=%s asiento=%s lineas=%s asientos_nuevos=%s historial=%s',
                  m.estado, m.casado_clase, m.casado_ref, split_part(m.casado_regla, ' ', 1), m.casado_auto,
                  case when m.asiento_id = pg_temp.c6_vivo('recibos', '-660001') then 'el_del_recibo' else coalesce(m.asiento_id::text, '-') end,
                  (select count(*) from banco_casado_lineas l where l.casado_id = m.casado_id and l.vigente),
                  (select count(*) from asientos) - v_n
                    - ((select count(*) from banco_casados c where c.posteado and c.deshecho_el is null) - v_p0),
                  (select h.antes->>'estado' || '>' || (h.despues->>'estado') from banco_historial h
                    where h.tabla = 'movimientos_banco' and h.clave = m.id::text and h.operacion = 'UPDATE'
                      and h.despues->>'estado' = 'casado' order by h.cambiado_el limit 1))
      into v_obt
      from movimientos_banco m where m.id = v_m;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (8, 'tarjeta ↔ recibo: casa sola con el asiento del ticket, con su regla y su rastro', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 9. UN TICKET REPARTIDO entre dos obras (la misma foto, dos recibos que
--    suman el cargo): el cargo casa con los DOS (sus dos líneas de la
--    tarjeta). Y dos tickets del mismo monto a menos de 3 días del mismo
--    cargo NO casan solos (no se adivina): se proponen los dos.
do $$
declare
  v_obt  text;
  v_esp  text := 'repartido=casado:recibo lineas=2 empate=pendiente:varios_candidatos opciones=2';
  v_obra2 text := current_setting('mx6.obra2', true);
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (9, 'ticket repartido casa con sus dos recibos; dos iguales no se adivinan', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660011, 'total', 300.00, 'fecha', d + 2, 'ruta', 'recibos/c6-pruebas/rep.jpg'));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660012, 'total', 120.45, 'fecha', d + 2, 'ruta', 'recibos/c6-pruebas/rep.jpg',
                                                 'proyecto_id', v_obra2));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660013, 'total', 66.60, 'fecha', d + 3, 'num_recibo', 'C6-E1'));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660014, 'total', 66.60, 'fecha', d + 4, 'num_recibo', 'C6-E2'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 9, -487.05, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-420.45', 'id', 'C6T1', 'nombre', 'C6 PRUEBAS SUPPLY #2'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 4, 'monto', '-66.60', 'id', 'C6T2', 'nombre', 'C6 GASOLINERA'))),
              null, 'c6-pruebas-repartido.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_obt := format('repartido=%s lineas=%s empate=%s opciones=%s', pg_temp.c6_est('2100-9996', 'C6T1'),
                    (select count(*) from banco_casado_lineas l join movimientos_banco m on m.casado_id = l.casado_id
                      where m.id = pg_temp.c6_mov('2100-9996', 'C6T1') and l.vigente),
                    pg_temp.c6_est('2100-9996', 'C6T2'),
                    (select jsonb_array_length(m.propuesta->'opciones') from movimientos_banco m
                      where m.id = pg_temp.c6_mov('2100-9996', 'C6T2')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (9, 'ticket repartido casa con sus dos recibos; dos iguales no se adivinan', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 10. LA BANDEJA propone la obra: un cargo sin ticket comprado el día que
--     hubo visita a UNA obra (eventos) sale en v_banco_bandeja con esa obra
--     propuesta; con visitas a dos obras ese día, no se adivina (sin obra).
--     (El día de la COMPRA, el DTUSER del banco: la ronda 3.)
do $$
declare
  v_obt  text;
  v_esp  text;
  v_obra text := current_setting('mx6.obra', true);
  v_o2   text := current_setting('mx6.obra2', true);
  v_f1   date;
  v_f2   date;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  v_esp := format('uno=sin_ticket:%s dos=sin_ticket:- bandeja=2', v_obra);
  if d is null or to_regclass('public.eventos') is null or v_o2 = v_obra then
    insert into _pruebas values (10, 'un cargo sin ticket propone la obra con visita ese día (eventos)', v_esp,
                                 'omitida: falta mes abierto, la tabla eventos o una segunda obra', null);
    return;
  end if;
  -- (Dos días del mes sin visitas de verdad: así las de la prueba son las únicas.)
  select min(x.f) into v_f1 from generate_series(d + 1, d + 25, interval '1 day') g(t), lateral (select g.t::date as f) x
   where not exists (select 1 from eventos e where e.fecha = x.f);
  select min(x.f) into v_f2 from generate_series(v_f1 + 1, d + 26, interval '1 day') g(t), lateral (select g.t::date as f) x
   where not exists (select 1 from eventos e where e.fecha = x.f);
  if v_f1 is null or v_f2 is null then
    insert into _pruebas values (10, 'un cargo sin ticket propone la obra con visita ese día (eventos)', v_esp,
                                 'omitida: no hay dos días del mes sin visitas', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into eventos (id, fecha, titulo, proyecto_id, estado) overriding system value
    values (-660001, v_f1, 'c6-pruebas: visita', v_obra, 'programado'),
           (-660002, v_f2, 'c6-pruebas: visita', v_obra, 'programado'),
           (-660003, v_f2, 'c6-pruebas: otra visita', v_o2, 'programado');
    -- (con el día de la compra, DTUSER: la obra es la de la visita de ESE
    -- día; sin él se miran los días antes del banco, la 96)
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 27, -100.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', v_f1, 'fecha_usuario', v_f1, 'monto', '-61.11', 'id', 'C6E1',
                                 'nombre', 'C6 LOWES #1'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', v_f2, 'fecha_usuario', v_f2, 'monto', '-62.22', 'id', 'C6E2',
                                 'nombre', 'C6 LOWES #2'))),
              null, 'c6-pruebas-eventos.qfx');
    perform fn_banco_casar_todo('2100-9996');
    select format('uno=%s:%s dos=%s:%s bandeja=%s',
                  max(b.motivo) filter (where b.monto = -61.11), coalesce(max(b.obra->>'proyecto_id') filter (where b.monto = -61.11), '-'),
                  max(b.motivo) filter (where b.monto = -62.22), coalesce(max(b.obra->>'proyecto_id') filter (where b.monto = -62.22), '-'),
                  count(*))
      into v_obt
      from v_banco_bandeja b where b.cuenta = '2100-9996';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (10, 'un cargo sin ticket propone la obra con visita ese día (eventos)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 11. DEPÓSITO ↔ COBRO (R2): el depósito casa solo con el cobro que Edgar
--     registró (mismo monto, 1 día después) y el cobro queda con su
--     movimiento (cobros.movimiento_id: de nulo a su valor, lo único que
--     c3 deja). No se postea nada: el asiento es el del cobro.
do $$
declare
  v_obt text;
  v_esp text := 'deposito=casado:cobro asiento=el_del_cobro cobro_dice=el_movimiento';
  v_esc jsonb;
  v_m   uuid;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (11, 'depósito ↔ cobro: casa solo y el cobro queda con su movimiento', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_esc := pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_m := pg_temp.c6_mov('1098', 'C6C3');
    select format('deposito=%s asiento=%s cobro_dice=%s', pg_temp.c6_est('1098', 'C6C3'),
                  case when m.asiento_id = c.contabilizado_en then 'el_del_cobro' else '-' end,
                  case when c.movimiento_id = v_m::text then 'el_movimiento' else coalesce(c.movimiento_id, 'nada') end)
      into v_obt
      from movimientos_banco m, cobros c where m.id = v_m and c.id = (v_esc->>'cobro')::uuid;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (11, 'depósito ↔ cobro: casa solo y el cobro queda con su movimiento', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 12. UN DEPÓSITO SIN COBRO propone las facturas abiertas que lo explican
--     (la de 3,200.50; y para el de 1,777.77, las DOS que suman) y espera;
--     con «fn_banco_cobrar» Edgar elige y se registra el cobro (c3) con
--     este movimiento: Dr el banco / Cr 1110 por factura, casado.
do $$
declare
  v_obt text;
  v_esp text := 'una=Factura #C6-1 dos=Facturas #C6-2 y #C6-3 cobrado=casado:cobro lineas=1098:1777.77|1110:-777.77|1110:-1000.00 '
                'cobro_dice=el_movimiento';
  v_m   uuid;
  v_op  jsonb;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (12, 'un depósito sin cobro propone sus facturas (una o dos) y fn_banco_cobrar registra el cobro',
                                 v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_obt := format('una=%s', (select split_part(o->>'texto', ' (', 1) from movimientos_banco m,
                                      jsonb_array_elements(m.propuesta->'opciones') o
                                where m.id = pg_temp.c6_mov('1098', 'C6C4') and o->>'texto' like '%C6-1 %' limit 1));
    v_m := pg_temp.c6_mov('1098', 'C6C12');
    select o into v_op from movimientos_banco m, jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m and o->>'texto' like 'Facturas #C6-2 y #C6-3%' limit 1;
    v_obt := v_obt || ' dos=' || coalesce(v_op->>'texto', '-');
    perform pg_temp.c6_como('dueno');
    perform fn_banco_cobrar(v_m, v_op->'args'->'p_aplicaciones', 'c6-pruebas');
    execute 'reset role';
    select v_obt || format(' cobrado=%s lineas=%s cobro_dice=%s', pg_temp.c6_est('1098', 'C6C12'),
                           (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.monto desc)
                              from asiento_lineas l where l.asiento_id = m.asiento_id),
                           (select case when c.movimiento_id = v_m::text then 'el_movimiento' else '-' end
                              from cobros c where c.id::text = m.casado_ref))
      into v_obt
      from movimientos_banco m where m.id = v_m;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (12, 'un depósito sin cobro propone sus facturas (una o dos) y fn_banco_cobrar registra el cobro', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 13. UN DEPÓSITO NUNCA VA A INGRESO: clasificarlo a una cuenta de ingreso
--     no entra (MX008, y dice que es su cobro); y si un asiento del banco
--     lo hiciera (uno escrito por la puerta interna, a propósito), el
--     control «depósitos nunca a ingreso» lo dice en rojo.
do $$
declare
  v_obt text;
  v_esp text := 'clasificar=MX008:cobro control_antes=t control_despues=f';
  v_m   uuid;
  v_x   text;
  v_ing text;
begin
  select codigo into v_ing from cuentas where tipo = 'ingreso' and activa and imputable order by (codigo = '4010') desc, codigo limit 1;
  if current_setting('mx6.desde', true) = '' or v_ing is null then
    insert into _pruebas values (13, 'un depósito nunca va a ingreso (y el control lo vigila)', v_esp,
                                 'omitida: falta mes abierto o una cuenta de ingreso', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_m := pg_temp.c6_mov('1098', 'C6C4');
    begin
      perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', v_ing, 'proyecto_id',
                                                                            current_setting('mx6.obra'))), 'c6-pruebas');
      v_x := 'entró';
    exception when others then
      v_x := sqlstate || case when sqlerrm like '%cobro%' then ':cobro' else '' end;
    end;
    -- (ronda 4d: el cuadre por su nombre, solo: con su grupo se calculaba también el 59, que aquí no se mira)
    v_obt := 'clasificar=' || v_x || ' control_antes='
             || (select c.ok::text from fn_banco_control(current_setting('mx6.mes'), array['cuadre: depósitos nunca a ingreso']) c
                  where c.vista = 'cuadre: depósitos nunca a ingreso');
    perform fn_postear_interno(jsonb_build_object(
      'camino', 'puente', 'fecha', (select m.fecha from movimientos_banco m where m.id = v_m)::text,
      'descripcion', 'c6-pruebas: un depósito a ingreso (se deshace)', 'origen_tabla', 'movimientos_banco', 'origen_id', v_m::text,
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '3200.50'),
                                  jsonb_build_object('cuenta', v_ing, 'monto', '-3200.50', 'proyecto_id', current_setting('mx6.obra')))));
    v_obt := v_obt || ' control_despues='
             || (select c.ok::text from fn_banco_control(current_setting('mx6.mes'), array['cuadre: depósitos nunca a ingreso']) c
                  where c.vista = 'cuadre: depósitos nunca a ingreso');
    v_obt := replace(replace(v_obt, 'true', 't'), 'false', 'f');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (13, 'un depósito nunca va a ingreso (y el control lo vigila)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 14. UN ZELLE DE EDGAR no es ingreso ni se casa solo: la bandeja propone
--     préstamo del accionista (2900) o aportación (3100); con el de 2900,
--     Dr el banco / Cr 2900.
do $$
declare
  v_obt text;
  v_esp text := 'propuesta=aporte_edgar opciones=2900,3100 elegido=1098:1000.00|2900:-1000.00';
  v_m   uuid;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (14, 'un Zelle de Edgar: aporte o préstamo del accionista, nunca ingreso', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_m := pg_temp.c6_mov('1098', 'C6C5');
    select format('propuesta=%s opciones=%s', m.propuesta->>'motivo',
                  (select string_agg(o->'args'->'p_lineas'->0->>'cuenta', ',' order by o->'args'->'p_lineas'->0->>'cuenta')
                     from jsonb_array_elements(m.propuesta->'opciones') o))
      into v_obt from movimientos_banco m where m.id = v_m;
    perform fn_banco_clasificar(v_m, '[{"cuenta": "2900"}]'::jsonb, 'c6-pruebas: Edgar prestó');
    v_obt := v_obt || ' elegido=' || (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.orden)
                                        from asiento_lineas l join movimientos_banco m on m.asiento_id = l.asiento_id
                                       where m.id = v_m);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (14, 'un Zelle de Edgar: aporte o préstamo del accionista, nunca ingreso', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 15. EL PAGO DE LA TARJETA es una transferencia, UN asiento para los dos
--     estados de cuenta, venga primero el que venga: con el banco y la
--     Amex subidos en un orden, y en el otro (la Amex primero), el mismo
--     resultado: Dr 2100-9996 / Cr el banco, con la fecha del primero, y
--     los dos movimientos casados con ese asiento. Sin gasto.
do $$
declare
  v_obt text := '';
  v_esp text := 'banco_primero=1asiento:2100-9996:500.00|1098:-500.00:+18 tarjeta_primero=1asiento:2100-9996:500.00|1098:-500.00:+18';
  v_ord int;
  v_a   uuid;
  v_b   uuid;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (15, 'el pago de la tarjeta: un asiento para los dos lados, en cualquier orden', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  for v_ord in 1 .. 2 loop
    begin
      perform pg_temp.c6_montar();
      if v_ord = 1 then
        perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
        perform fn_banco_casar_todo('1098');
        perform fn_banco_importar_ofx(pg_temp.c6_amex(), null, 'c6-pruebas-amex.qfx');
        perform fn_banco_casar_todo('2100-9996');
      else
        perform fn_banco_importar_ofx(pg_temp.c6_amex(), null, 'c6-pruebas-amex.qfx');
        perform fn_banco_casar_todo('2100-9996');
        perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
        perform fn_banco_casar_todo('1098');
      end if;
      v_a := pg_temp.c6_mov('1098', 'C6C7');
      v_b := pg_temp.c6_mov('2100-9996', 'C6A3');
      select v_obt || case when v_ord = 1 then 'banco_primero=' else ' tarjeta_primero=' end
             || case when ma.asiento_id = mb.asiento_id then '1asiento' else 'dos_asientos' end || ':'
             || (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.monto desc) from asiento_lineas l
                  where l.asiento_id = ma.asiento_id)
             || ':+' || ((select a.fecha_contable from asientos a where a.id = ma.asiento_id) - current_setting('mx6.desde')::date)
        into v_obt
        from movimientos_banco ma, movimientos_banco mb where ma.id = v_a and mb.id = v_b;
      raise exception using errcode = 'MXT00';
    exception
      when sqlstate 'MXT00' then null;
      when others then v_obt := v_obt || ' ' || sqlstate || ' ' || left(sqlerrm, 200);
    end;
  end loop;
  insert into _pruebas values (15, 'el pago de la tarjeta: un asiento para los dos lados, en cualquier orden', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 16. EL PASE A LA RESERVA CON UN SOLO LADO: llega el banco y la reserva
--     no; se propone la transferencia y Edgar la confirma
--     (fn_banco_transferencia): se postea con su contrapartida y el
--     movimiento queda «en tránsito»; cuando llega la reserva, su lado
--     casa SOLO con ESE asiento (R1) y los dos quedan casados. Nunca dos
--     asientos. (Ronda 4: el banco nombra «SAV ····1097» y esa reserva
--     todavía no trajo su estado de cuenta: no se sabe que el número es de
--     la empresa; la transferencia, con su motivo. Ronda 4b: un número que
--     no se conoce tampoco es la cuenta personal de Edgar: se pregunta,
--     «cuenta_desconocida», y todo pide su motivo.)
do $$
declare
  v_obt text;
  v_esp text := 'propuesta=cuenta_desconocida antes=en_transito:transferencia despues=casado:transferencia '
                'reserva=casado:transferencia mismo_asiento=t asientos_del_pase=1';
  v_m   uuid;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (16, 'transferencia con un lado: se confirma, y el otro lado casa con ese asiento', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6C9');
    v_obt := 'propuesta=' || (select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_m);
    perform pg_temp.c6_como('dueno');
    perform fn_banco_transferencia(v_m, '1097', 'c6-pruebas: a la reserva');
    execute 'reset role';
    v_obt := v_obt || ' antes=' || pg_temp.c6_est('1098', 'C6C9');
    perform fn_banco_importar_ofx(pg_temp.c6_reserva(), '1097', 'c6-pruebas-reserva.ofx');
    perform fn_banco_casar_todo('1097');
    v_obt := v_obt || format(' despues=%s reserva=%s mismo_asiento=%s asientos_del_pase=%s', pg_temp.c6_est('1098', 'C6C9'),
                             pg_temp.c6_est('1097', 'C6R1'),
                             (select m1.asiento_id = m2.asiento_id from movimientos_banco m1, movimientos_banco m2
                               where m1.id = v_m and m2.id = pg_temp.c6_mov('1097', 'C6R1')),
                             (select count(*) from asiento_lineas l where l.cuenta = '1097' and l.monto = 2000.00));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (16, 'transferencia con un lado: se confirma, y el otro lado casa con ese asiento', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 17. EL CAJERO pregunta: ¿caja chica (1050) o para Edgar (3200)? Nunca
--     automático. Con la caja chica: Dr 1050 / Cr el banco.
do $$
declare
  v_obt  text;
  v_caja text;
  v_esp  text;
  v_m    uuid;
begin
  v_caja := coalesce((select m.cuenta from mapeo_metodo_pago m where m.forma = 'efectivo' and m.cuenta is not null
                       order by m.confirmado_el desc nulls last limit 1), '1050');
  v_esp := format('antes=pendiente:cajero opciones=%s,3200 elegido=1098:-200.00|%s:200.00', v_caja, v_caja);
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (17, 'el cajero pregunta caja chica o Edgar, nunca solo', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6C6');
    select format('antes=%s opciones=%s', pg_temp.c6_est('1098', 'C6C6'),
                  (select string_agg(o->'args'->'p_lineas'->0->>'cuenta', ',' order by o->'args'->'p_lineas'->0->>'cuenta')
                     from jsonb_array_elements(m.propuesta->'opciones') o))
      into v_obt from movimientos_banco m where m.id = v_m;
    perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', v_caja)), null);
    v_obt := v_obt || ' elegido=' || (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.orden)
                                        from asiento_lineas l join movimientos_banco m on m.asiento_id = l.asiento_id
                                       where m.id = v_m);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (17, 'el cajero pregunta caja chica o Edgar, nunca solo', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 18. LA NÓMINA ESPERA su journal (f11): el débito de Gusto no se
--     clasifica sin decir por qué (MX008); cuando el journal está en el
--     libro (su línea del banco por el neto), casa SOLO con él.
do $$
declare
  v_obt text;
  v_esp text := 'antes=pendiente:nomina clasificar=MX008 con_journal=casado:asiento';
  v_m   uuid;
  v_x   text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (18, 'la nómina espera su journal y casa sola con él', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6C8');
    v_obt := 'antes=' || pg_temp.c6_est('1098', 'C6C8');
    begin
      perform fn_banco_clasificar(v_m, '[{"cuenta": "6130"}]'::jsonb, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    -- El journal de la nómina (como lo pondrá f11): el neto sale del banco.
    perform fn_postear_interno(jsonb_build_object(
      'camino', 'puente', 'origen_tabla', 'nomina_c6_pruebas', 'origen_id', 'c6-pruebas-1',
      'fecha', (select m.fecha - 1 from movimientos_banco m where m.id = v_m)::text,
      'descripcion', 'c6-pruebas: journal de nómina (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2210', 'monto', '4000.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-4000.00'))));
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || ' clasificar=' || v_x || ' con_journal=' || pg_temp.c6_est('1098', 'C6C8');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (18, 'la nómina espera su journal y casa sola con él', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 19. LAS REGLAS FIJAS, solo cuando todo lo dice: el interés de la reserva
--     (tipo INT, entra dinero, «INTEREST PAYMENT») → 4910 y el cargo
--     mensual del banco (SRVCHG, sale, «MONTHLY SERVICE FEE») → 6130,
--     automáticos. El mismo cargo de tipo DEBIT (solo el descriptor lo
--     dice) no es automático: se propone.
do $$
declare
  v_obt text;
  v_esp text := 'interes=casado:regla:4910 cargo=casado:regla:6130 solo_descriptor=pendiente:cargo_banco';
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (19, 'reglas fijas: 4910 y 6130 automáticas solo con tipo, signo y descriptor', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_reserva(), '1097', 'c6-pruebas-reserva.ofx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 1.00, jsonb_build_array(
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 27, 'monto', '-15.00', 'id', 'C6C11', 'nombre', 'MONTHLY SERVICE FEE'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 26, 'monto', '-16.00', 'id', 'C6F2', 'nombre', 'MONTHLY SERVICE FEE'))),
              '1098', 'c6-pruebas-reglas.qfx');
    perform fn_banco_casar_todo('1097');
    perform fn_banco_casar_todo('1098');
    v_obt := format('interes=%s:%s cargo=%s:%s solo_descriptor=%s', pg_temp.c6_est('1097', 'C6R2'),
                    (select m.casado_ref from movimientos_banco m where m.id = pg_temp.c6_mov('1097', 'C6R2')),
                    pg_temp.c6_est('1098', 'C6C11'),
                    (select m.casado_ref from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6C11')),
                    pg_temp.c6_est('1098', 'C6F2'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (19, 'reglas fijas: 4910 y 6130 automáticas solo con tipo, signo y descriptor', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 20. EL PAGO A UN PROVEEDOR (su nombre en la descripción) se aplica a sus
--     partidas abiertas de 2010, nunca a 5100: la bandeja lo propone, y
--     fn_banco_pagar_proveedor postea Dr 2010 con la partida del recibo /
--     Cr el banco; la partida queda en cero. Clasificarlo a un costo sin
--     decir por qué no entra (el gasto ya entró con el ticket).
do $$
declare
  v_obt  text;
  v_esp  text := 'propuesta=pago_proveedor a_costo=MX008 pagado=casado:pago_proveedor lineas=1098:-850.00|2010:850.00:recibos/-660003 '
                  'partida=0.00 a_5100=0';
  v_esc  jsonb;
  v_m    uuid;
  v_x    text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (20, 'pago a proveedor: Dr 2010 por sus partidas, nunca 5100', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_esc := pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_m := pg_temp.c6_mov('1098', 'C6C10');
    v_obt := 'propuesta=' || (select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_m);
    begin
      perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                  null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform pg_temp.c6_como('dueno');
    perform fn_banco_pagar_proveedor(v_m, (v_esc->>'proveedor')::uuid, null);
    execute 'reset role';
    select v_obt || format(' a_costo=%s pagado=%s lineas=%s partida=%s a_5100=%s', v_x, pg_temp.c6_est('1098', 'C6C10'),
                           (select string_agg(l.cuenta || ':' || l.monto || coalesce(':' || l.partida_tabla || '/' || l.partida_id, ''),
                                              '|' order by l.orden)
                              from asiento_lineas l where l.asiento_id = m.asiento_id),
                           (select coalesce(sum(l.monto), 0) from asiento_lineas l
                             where l.cuenta = '2010' and l.partida_tabla = 'recibos' and l.partida_id = '-660003'),
                           (select count(*) from asiento_lineas l where l.asiento_id = m.asiento_id and l.cuenta = '5100'))
      into v_obt
      from movimientos_banco m where m.id = v_m;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (20, 'pago a proveedor: Dr 2010 por sus partidas, nunca 5100', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 21. LOS PRÉSTAMOS: la cuota del banco se propone con la partición de la
--     fórmula (interés = round(saldo × tasa / 12)); registrada, Dr 2520
--     capital / Dr 7100 interés / Cr el banco, casada. Con el statement
--     del prestamista, manda él. Una cuota sin movimiento (el banco no ha
--     llegado) y el cargo, cuando llega, casa solo con ella. Y lo que dice
--     el libro en 2520 es lo que se debe (el control «préstamos»).
do $$
declare
  v_obt  text;
  v_esp  text := 'propuesta=cuota_prestamo formula=interes:182.99,capital:846.34 cuota1=1098:-1029.33|2520:846.34|7100:182.99 '
                 'cuota2=statement:850.00/179.33 sin_mov=casado:cuota_prestamo saldo=28870.30 libro_2520=28870.30 control=igual';
  v_p    uuid;
  v_m    uuid;
  v_pos  bigint;
  v_ok0  boolean;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (21, 'préstamos: fórmula, statement, cuota sin movimiento y 2520 = lo que se debe', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    v_ok0 := (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prestamos']) c where c.vista = 'cuadre: préstamos');
    v_p := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS CREDIT', 'descripcion', 'camioneta de prueba',
             'principal', '52000.00', 'tasa_anual', '6.99', 'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15,
             'plazo_meses', 60, 'saldo_inicial', '31415.26', 'saldo_inicial_al', (d - 1)::text, 'cuenta_banco', '1098',
             'descriptor', 'C6 PRUEBAS CREDIT'))->>'id')::uuid;
    -- El saldo del préstamo en el libro (la apertura lo traerá de QuickBooks; aquí, a mano en el mes).
    perform fn_postear(jsonb_build_object('fecha', (d - 1 + 1)::text, 'descripcion', 'c6-pruebas: el préstamo (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '31415.26'),
                                  jsonb_build_object('cuenta', '2520', 'monto', '-31415.26'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 1.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 14, 'monto', '-1029.33', 'id', 'C6L1', 'nombre', 'C6 PRUEBAS CREDIT PMT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 15, 'monto', '-1029.33', 'id', 'C6L2', 'nombre', 'C6 PRUEBAS CREDIT PMT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 17, 'monto', '-1029.33', 'id', 'C6L3', 'nombre', 'C6 PRUEBAS CREDIT PMT'))),
              '1098', 'c6-pruebas-prestamo.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6L1');
    select format('propuesta=%s formula=interes:%s,capital:%s', m.propuesta->>'motivo', m.propuesta->'particion'->>'interes',
                  m.propuesta->'particion'->>'capital')
      into v_obt from movimientos_banco m where m.id = v_m;
    perform pg_temp.c6_como('dueno');
    perform fn_prestamo_cuota(v_p, v_m);
    execute 'reset role';
    v_obt := v_obt || ' cuota1=' || (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.cuenta)
                                       from asiento_lineas l join movimientos_banco m on m.asiento_id = l.asiento_id
                                      where m.id = v_m);
    perform fn_prestamo_cuota(v_p, pg_temp.c6_mov('1098', 'C6L2'), null, null, '850.00', null, 'c6-pruebas: statement');
    v_obt := v_obt || ' cuota2=' || (select q.fuente || ':' || q.capital || '/' || q.interes from prestamo_cuotas q
                                      where q.movimiento_id = pg_temp.c6_mov('1098', 'C6L2'));
    -- La tercera, registrada ANTES de que llegue su cargo (sin movimiento):
    -- el cargo del día 17 casa solo con su línea del banco.
    perform fn_prestamo_cuota(v_p, null, d + 17, '1029.33', '848.62', '180.71', 'c6-pruebas: antes que el banco');
    perform fn_banco_casar_todo('1098');
    -- (Lo que el libro dice de ESTE préstamo: lo que la prueba movió en 2520.
    -- Y el control dice lo mismo que antes de la prueba: sus cifras cuadran
    -- entre sí, y lo que ya había, igual que antes.)
    v_obt := v_obt || format(' sin_mov=%s saldo=%s libro_2520=%s control=%s', pg_temp.c6_est('1098', 'C6L3'),
                             (select x.saldo from v_prestamos x where x.prestamo_id = v_p),
                             (select -sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where a.cadena_pos > v_pos and l.cuenta = '2520'),
                             case when (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prestamos']) c
                                         where c.vista = 'cuadre: préstamos') is not distinct from v_ok0 then 'igual' else 'cambió' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (21, 'préstamos: fórmula, statement, cuota sin movimiento y 2520 = lo que se debe', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 22. LOS PREPAGADOS: una póliza de seguro que empezó en agosto (lo de
--     agosto y septiembre lo amortizó QuickBooks: llega con su saldo al
--     corte, 4,000.00, y el libro lo amortiza por días del corte a su fin)
--     y la prima de WC que empieza a mitad del mes (el mes parcial, por
--     días): un asiento estándar por mes y otro para WC (5015 contra 1410,
--     aparte: c3 no deja la mano de obra con otras cuentas); otra vez el
--     mismo mes, nada (idempotente); la póliza corregida (su monto sube
--     200.00, que van a lo que falta) rehace el mes (reverso y el bueno);
--     lo que dice el libro en 1410 es lo que falta por amortizar.
do $$
declare
  v_obt  text;
  v_esp  text := 'gl=407.89 wc=170.00 asientos=2 wc_solo=1410,5015 otra_vez=sin_cambios corregida=reverso+428.29 libro_1410=igual';
  v_gl   uuid;
  v_x    jsonb;
  v_pos  bigint;
  v_ok0  boolean;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
  v_ini  date;
  v_fin  date;
begin
  if d is null then
    insert into _pruebas values (22, 'prepagados: por días, un asiento por mes (y WC aparte), idempotente, corregible', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  -- La póliza de GL empieza dos meses antes del corte y dura un año (365
  -- días); la de WC, a mitad del mes (el día 15) y dura 365 días.
  v_ini := (fn_puente_corte() - interval '2 months')::date;
  v_fin := (v_ini + interval '1 year')::date - 1;
  if d <> fn_puente_corte() or v_fin - v_ini + 1 <> 365 or extract(day from (d + interval '1 month')::date - 1) <> 31 then
    insert into _pruebas values (22, 'prepagados: por días, un asiento por mes (y WC aparte), idempotente, corregible', v_esp,
                                 'omitida: el mes abierto más antiguo no es el primero después del corte (octubre)', null);
    return;
  end if;
  -- (Edgar ya amortizó un mes POSTERIOR, con este todavía abierto —la marcha
  -- en paralelo—: amortizar este se niega, MX008, y es la regla. Antes la
  -- 22 y la 46 salían en rojo.)
  if pg_temp.c6_amortizado_despues() is not null then
    insert into _pruebas values (22, 'prepagados: por días, un asiento por mes (y WC aparte), idempotente, corregible', v_esp,
                                 format('omitida: ya está amortizado %s, posterior al mes abierto más antiguo (se amortiza el último)',
                                        pg_temp.c6_amortizado_despues()), null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    v_ok0 := (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prepagados']) c where c.vista = 'cuadre: prepagados');
    v_gl := (fn_prepagado_guardar(jsonb_build_object('descripcion', 'c6-pruebas GL', 'tipo', 'seguro', 'cuenta_gasto', '6200',
               'monto', '4800.00', 'desde', v_ini::text, 'hasta', v_fin::text, 'saldo_corte', '4000.00'))->>'id')::uuid;
    perform fn_prepagado_guardar(jsonb_build_object('descripcion', 'c6-pruebas WC', 'tipo', 'seguro', 'cuenta_gasto', '5015',
               'monto', '3650.00', 'desde', (d + 14)::text, 'hasta', (d + 14 + 364)::text));
    -- Lo que falta de GL (de la apertura) y la prima de WC pagada: en el libro.
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: lo que falta de GL y WC (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1410', 'monto', '7650.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-7650.00'))));
    v_x := fn_prepagados_amortizar(current_setting('mx6.mes'));
    select format('gl=%s wc=%s asientos=%s wc_solo=%s',
                  (select a.monto from prepagados_amortizaciones a where a.prepagado_id = v_gl and a.vigente),
                  (select a.monto from prepagados_amortizaciones a join prepagados p on p.id = a.prepagado_id
                    where p.descripcion = 'c6-pruebas WC' and a.vigente),
                  (select count(distinct a.asiento_id) from prepagados_amortizaciones a join prepagados p on p.id = a.prepagado_id
                    where p.descripcion like 'c6-pruebas%' and a.vigente),
                  (select string_agg(distinct l.cuenta, ',' order by l.cuenta) from asiento_lineas l
                    where l.asiento_id = (select a.asiento_id from prepagados_amortizaciones a join prepagados p on p.id = a.prepagado_id
                                           where p.descripcion = 'c6-pruebas WC' and a.vigente)))
      into v_obt;
    v_x := fn_prepagados_amortizar(current_setting('mx6.mes'));
    v_obt := v_obt || ' otra_vez=' || case when (select bool_and((e->>'sin_cambios')::boolean) from jsonb_array_elements(v_x->'asientos') e
                                                  where e ? 'sin_cambios') and not exists (select 1 from jsonb_array_elements(v_x->'asientos') e
                                                                                              where e ? 'reverso')
                                           then 'sin_cambios' else v_x::text end;
    perform fn_prepagado_guardar(jsonb_build_object('id', v_gl, 'monto', '5000.00'));
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: la diferencia de la póliza (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1410', 'monto', '200.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-200.00'))));
    v_x := fn_prepagados_amortizar(current_setting('mx6.mes'));
    v_obt := v_obt || ' corregida=' || case when exists (select 1 from jsonb_array_elements(v_x->'asientos') e where e ? 'reverso')
                                            then 'reverso+' else '' end
             || (select a.monto::text from prepagados_amortizaciones a where a.prepagado_id = v_gl and a.vigente);
    v_obt := v_obt || ' libro_1410=' || case when (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prepagados']) c
                                                    where c.vista = 'cuadre: prepagados') is not distinct from v_ok0
                                             then 'igual' else 'cambió' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (22, 'prepagados: por días, un asiento por mes (y WC aparte), idempotente, corregible', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- La conciliación
-- =====================================================================

-- 23. SE CONFIRMA CON SUS PARTIDAS EN TRÁNSITO: al corte (el día 20), un
--     cheque que el banco cobra después (en circulación) y un depósito del
--     último día que el banco trae después (en tránsito). Libros = banco +
--     en tránsito − en circulación: diferencia 0.00, se confirma, y queda
--     quién, cuándo y la huella de sus partidas. Cada partida dice qué es
--     (y cuándo lo trajo el banco).
do $$
declare
  v_obt text;
  v_esp text := 'transito=2 dep=900.00 car=400.00 dif=0.00 confirmada=t quien=t huella=t explica=t';
  v_c   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (23, 'se confirma con partidas en tránsito y diferencia 0.00', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    -- En el libro: el cheque 2001 del día 18 y el depósito del 20.
    perform fn_postear(jsonb_build_object('fecha', (d + 17)::text, 'descripcion', 'c6-pruebas: cheque 2001 (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6200', 'monto', '400.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-400.00'))));
    -- (ronda 4d: contra 1600, un depósito en garantía que devuelven. Con
    -- 3100 —el dinero del banco al patrimonio del accionista sin su cuenta
    -- personal dada de alta—, EL CRITERIO contra el libro ya no lo deja casar
    -- solo: se propone con su motivo)
    perform fn_postear(jsonb_build_object('fecha', (d + 19)::text, 'descripcion', 'c6-pruebas: depósito del 20 (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '900.00'),
                                  jsonb_build_object('cuenta', '1600', 'monto', '-900.00'))));
    -- El banco los trae después del corte.
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 500.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 21, 'monto', '900.00', 'id', 'C6K1', 'nombre', 'DEPOSIT'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 20, 'monto', '-400.00', 'id', 'C6K2', 'nombre', 'CHECK 2001',
                                 'cheque', '2001'))), '1098', 'c6-pruebas-conc.qfx');
    perform fn_banco_casar_todo('1098');
    perform pg_temp.c6_como('dueno');
    v_c := fn_conciliar('1098', d + 19, '0.00');
    v_c := fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    execute 'reset role';
    select format('transito=%s dep=%s car=%s dif=%s confirmada=%s quien=%s huella=%s explica=%s', c.n_transito, c.depositos_transito,
                  c.cargos_circulacion, c.diferencia, c.estado = 'confirmada',
                  c.confirmada_por = nullif(current_setting('mx6.dueno'), '')::uuid and c.confirmada_el is not null,
                  c.hash_partidas ~ '^[0-9a-f]{64}$',
                  (select bool_and(p.explicacion like '%trae el %' and p.explicacion like '%después del corte%')
                     from conciliacion_partidas p where p.conciliacion_id = c.id))
      into v_obt
      from conciliaciones c where c.id = (v_c->>'conciliacion')::uuid;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (23, 'se confirma con partidas en tránsito y diferencia 0.00', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 24. SIN CUADRAR NO SE CONFIRMA: sin el saldo del statement (y sin
--     archivo con saldo a esa fecha) no; con un saldo que no cuadra
--     (diferencia 10.00) tampoco, y dice cuánto (MX008). Con el bueno, sí
--     (el aporte del libro que el banco todavía no trae va en tránsito: el
--     banco dice 0.00).
do $$
declare
  v_obt text := '';
  v_esp text := 'sin_saldo=MX008 mal=MX008:10.00 bien=confirmada';
  v_c   jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (24, 'sin saldo o con diferencia no se confirma; con 0.00 sí', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_postear(jsonb_build_object('fecha', (d + 2)::text, 'descripcion', 'c6-pruebas: aporte (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '250.00'),
                                  jsonb_build_object('cuenta', '3100', 'monto', '-250.00'))));
    v_c := fn_conciliar('1098', d + 9);
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := 'confirmada';
    exception when others then v_x := sqlstate;
    end;
    v_obt := 'sin_saldo=' || v_x;
    v_c := fn_conciliar('1098', d + 9, '10.00');
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := 'confirmada';
    exception when others then v_x := sqlstate || case when sqlerrm like '%10.00%' then ':10.00' else '' end;
    end;
    v_obt := v_obt || ' mal=' || v_x;
    v_c := fn_conciliar('1098', d + 9, '0.00');
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := (select c.estado from conciliaciones c where c.id = (v_c->>'conciliacion')::uuid);
    exception when others then v_x := sqlstate || ' ' || left(sqlerrm, 80);
    end;
    v_obt := v_obt || ' bien=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (24, 'sin saldo o con diferencia no se confirma; con 0.00 sí', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 25. LO DEL BANCO SIN CASAR BLOQUEA: un movimiento pendiente al corte
--     (aunque la diferencia dé 0.00) no deja confirmar; casado o
--     clasificado, sí.
do $$
declare
  v_obt text;
  v_esp text := 'dif=0.00 sin_casar=1 confirmar=MX008 clasificado_y_confirmada=t';
  v_c   jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (25, 'un movimiento sin casar bloquea la confirmación', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, -33.33, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-33.33', 'id', 'C6B1', 'nombre', 'C6 CARGO RARO'))),
              '1098', 'c6-pruebas-bloquea.qfx');
    perform fn_banco_casar_todo('1098');
    v_c := fn_conciliar('1098', d + 9, '-33.33');
    v_obt := format('dif=%s sin_casar=%s', v_c->>'diferencia', v_c->>'n_sin_casar');
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := 'confirmada';
    exception when others then v_x := sqlstate;
    end;
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6B1'), '[{"cuenta": "6130"}]'::jsonb, null);
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    v_obt := v_obt || ' confirmar=' || v_x || ' clasificado_y_confirmada='
             || (select (c.estado = 'confirmada')::text from conciliaciones c where c.id = (v_c->>'conciliacion')::uuid);
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (25, 'un movimiento sin casar bloquea la confirmación', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 26. MÁS DE 30 DÍAS EN TRÁNSITO: un cheque del libro que el banco no
--     trae en 30 días sale como ALARMA (con cuántos días); no frena la
--     confirmación, pero se dice al confirmar. La clase y el motivo que
--     Edgar le pone (fn_conciliacion_partida) se quedan al recalcular.
do $$
declare
  v_obt text;
  v_esp text := 'alarmas=1 dias=31 motivo=se_queda confirmada=t dicha=1';
  v_c   jsonb;
  v_p   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or current_setting('mx6.sig', true) = '' then
    insert into _pruebas values (26, 'más de 30 días en tránsito: alarma, sin frenar', v_esp, 'omitida: falta el mes abierto y el siguiente',
                                 null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_postear(jsonb_build_object('fecha', (d + 1)::text, 'descripcion', 'c6-pruebas: cheque 3001 (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6200', 'monto', '75.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-75.00'))));
    v_c := fn_conciliar('1098', d + 32, '0.00');
    select p.id into v_p from conciliacion_partidas p where p.conciliacion_id = (v_c->>'conciliacion')::uuid;
    perform fn_conciliacion_partida(v_p, 'cargo_en_circulacion', 'c6-pruebas: el cheque 3001 lo tiene el cliente');
    v_c := fn_conciliar('1098', d + 32);
    v_c := fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    select format('alarmas=%s dias=%s motivo=%s confirmada=%s dicha=%s', c.n_alarmas, p.dias,
                  case when p.motivo = 'c6-pruebas: el cheque 3001 lo tiene el cliente' then 'se_queda' else coalesce(p.motivo, '-') end,
                  (c.estado = 'confirmada')::text, jsonb_array_length(v_c->'alarmas'))
      into v_obt
      from conciliaciones c join conciliacion_partidas p on p.conciliacion_id = c.id
     where c.id = (v_c->>'conciliacion')::uuid;
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (26, 'más de 30 días en tránsito: alarma, sin frenar', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 27. CONFIRMADA NO SE TOCA: ni por update (MX003), ni sus partidas, ni
--     recalculándola (MX008), ni des-casando un movimiento que está dentro
--     (MX008: se reabre antes).
-- 28. REABRIR deja rastro: con su motivo (sin él no), quién y cuándo, y en
--     banco_historial el antes (confirmada) y el después (abierta); se
--     recalcula y se confirma otra vez.
do $$
declare
  v_obt  text := '';
  v_obt2 text := '';
  v_esp  text := 'update=MX003 partida=MX003 conciliar=MX008 descasar=MX008';
  v_esp2 text := 'sin_motivo=22023 reabierta=abierta motivo=t historial=confirmada>abierta otra_vez=confirmada';
  v_c    jsonb;
  v_id   uuid;
  v_x    text;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (27, 'una conciliación confirmada no se toca', v_esp, 'omitida: falta mes abierto', null),
                                (28, 'reabrir una confirmada: con motivo y con rastro', v_esp2, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    -- (ronda 4d: contra 1600, no 3100: ver la 23)
    perform fn_postear(jsonb_build_object('fecha', (d + 2)::text, 'descripcion', 'c6-pruebas: depósito devuelto (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '250.00'),
                                  jsonb_build_object('cuenta', '1600', 'monto', '-250.00'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, 250.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 3, 'monto', '250.00', 'id', 'C6Q1', 'nombre', 'DEPOSIT'))),
              '1098', 'c6-pruebas-confirmada.qfx');
    perform fn_banco_casar_todo('1098');
    v_c := fn_conciliar('1098', d + 9);
    v_id := (v_c->>'conciliacion')::uuid;
    perform fn_conciliacion_confirmar(v_id);
    begin
      update conciliaciones set saldo_statement = 1 where id = v_id;
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := 'update=' || v_x;
    begin
      insert into conciliacion_partidas (conciliacion_id, lado, clase, fecha, monto) values (v_id, 'libro', 'error', d, 1);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' partida=' || v_x;
    begin
      perform fn_conciliar('1098', d + 9, '250.00');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' conciliar=' || v_x;
    begin
      perform fn_banco_descasar(pg_temp.c6_mov('1098', 'C6Q1'), 'c6-pruebas: estaba mal');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' descasar=' || v_x;
    -- 28
    begin
      perform fn_conciliacion_reabrir(v_id, ' ');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt2 := 'sin_motivo=' || v_x;
    perform pg_temp.c6_como('dueno');
    perform fn_conciliacion_reabrir(v_id, 'c6-pruebas: faltaba un cargo');
    execute 'reset role';
    select format(' reabierta=%s motivo=%s historial=%s', c.estado,
                  c.reabierta_motivo = 'c6-pruebas: faltaba un cargo' and c.reabierta_por = nullif(current_setting('mx6.dueno'), '')::uuid
                    and c.reabierta_el is not null,
                  (select h.antes->>'estado' || '>' || (h.despues->>'estado') from banco_historial h
                    where h.tabla = 'conciliaciones' and h.clave = v_id::text and h.antes->>'estado' = 'confirmada'
                    order by h.cambiado_el desc limit 1))
      into v_x from conciliaciones c where c.id = v_id;
    v_obt2 := v_obt2 || replace(v_x, '=true', '=t');
    perform fn_conciliar('1098', d + 9);
    perform fn_conciliacion_confirmar(v_id);
    v_obt2 := v_obt2 || ' otra_vez=' || (select c.estado from conciliaciones c where c.id = v_id);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := v_obt || ' ' || sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (27, 'una conciliación confirmada no se toca', v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false)),
                              (28, 'reabrir una confirmada: con motivo y con rastro', v_esp2, coalesce(v_obt2, '-'),
                               coalesce(v_obt2 = v_esp2, false));
end $$;

-- 29. LA TARJETA SE CONCILIA A SU FECHA DE CORTE (la del statement, no fin
--     de mes), con el saldo del archivo (lo que se debe, en negativo) o el
--     que escribe Edgar (en positivo, como lo dice el statement): igual.
--     Lo que casó sale en el grupo «casado» con su asiento.
do $$
declare
  v_obt text;
  v_esp text := 'corte=+22 libros=-1173.26 banco=-1173.26 dif=0.00 escrito=-1173.26 casados=5 confirmada=t';
  v_c   jsonb;
  v_id  uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
  v_m   uuid;
begin
  if d is null then
    insert into _pruebas values (29, 'la tarjeta se concilia a su fecha de corte', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    -- (lo que esperaba: la compra sin ticket y el interés, clasificados)
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A2'),
                                jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas: material sin ticket');
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A4'), '[{"cuenta": "7100"}]'::jsonb, null);
    -- (el pago desde el banco, ya casado con los dos lados)
    v_c := fn_conciliar('2100-9996', d + 22);
    v_id := (v_c->>'conciliacion')::uuid;
    select format('corte=+%s libros=%s banco=%s dif=%s', c.fecha_corte - d, c.saldo_libros, c.saldo_banco, c.diferencia)
      into v_obt from conciliaciones c where c.id = v_id;
    v_c := fn_conciliar('2100-9996', d + 22, '1,173.26');
    v_obt := v_obt || format(' escrito=%s casados=%s', v_c->>'saldo_banco',
                             (select count(*) from v_conciliacion_partidas p where p.conciliacion_id = v_id and p.grupo = 'casado'
                                and p.asiento_numero is not null));
    perform fn_conciliacion_confirmar(v_id);
    v_obt := v_obt || ' confirmada=' || (select (c.estado = 'confirmada')::text from conciliaciones c where c.id = v_id);
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (29, 'la tarjeta se concilia a su fecha de corte', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 30. LA CONCILIACIÓN DE APERTURA (30-sep, la era QuickBooks): el cheque
--     1043 que estaba en circulación entra como partida; confirmada, el
--     cheque que cobra el banco en octubre casa SOLO con ella (por su
--     número y su monto), sin asiento (ya está en la apertura); la partida
--     dice con qué movimiento llegó, y la conciliación de octubre ya no la
--     trae.
do $$
declare
  v_obt text;
  v_esp text := 'apertura=confirmada cheque=casado:apertura sin_asiento=t resuelta=t en_octubre=0';
  v_c   jsonb;
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or not exists (select 1 from periodos where tipo = 'apertura') then
    insert into _pruebas values (30, 'la conciliación de apertura: su cheque en circulación casa solo en octubre', v_esp,
                                 'omitida: falta mes abierto o la apertura', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    -- Sin asiento de apertura todavía (recién pegado), uno de prueba: la
    -- conciliación de apertura concilia su saldo. (Si ya está la de verdad,
    -- esa vale: la cuenta de prueba no tiene saldo en ella.)
    if not exists (select 1 from asientos a where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                     and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
      if (select p.estado from periodos p where p.tipo = 'apertura' order by p.desde limit 1) <> 'abierto' then
        raise exception using errcode = 'MXT01';
      end if;
      perform fn_postear(jsonb_build_object('tipo', 'apertura',
        'fecha', (select p.hasta from periodos p where p.tipo = 'apertura' order by p.desde limit 1)::text,
        'descripcion', 'c6-pruebas: apertura de prueba (se deshace)',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1097', 'monto', '1.00'),
                                    jsonb_build_object('cuenta', '3900', 'monto', '-1.00'))));
    end if;
    v_c := fn_conciliacion_apertura('1098', '1200.00', jsonb_build_array(jsonb_build_object(
             'fecha', (d - 3)::text, 'monto', '-1200.00', 'cheque', '1043', 'descripcion', 'c6-pruebas: cheque 1043')));
    v_c := fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    v_obt := 'apertura=' || (v_c->>'estado');
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6C1');
    v_obt := v_obt || format(' cheque=%s sin_asiento=%s resuelta=%s', pg_temp.c6_est('1098', 'C6C1'),
                             (select m.asiento_id is null from movimientos_banco m where m.id = v_m),
                             exists (select 1 from conciliacion_partidas p where p.resuelta_por_movimiento = v_m));
    v_c := fn_conciliar('1098', d + 27, '0.00');
    v_obt := v_obt || ' en_octubre=' || (select count(*) from conciliacion_partidas p
                                          where p.conciliacion_id = (v_c->>'conciliacion')::uuid and p.apertura_partida_id is not null);
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (30, 'la conciliación de apertura: su cheque en circulación casa solo en octubre', v_esp,
                               coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;


-- =====================================================================
-- Deshacer, y lo que no se toca
-- =====================================================================

-- 31. UN CHEQUE DEVUELTO: el depósito rebotado se propone como devolución
--     del cobro; fn_banco_devolver la registra con fn_cobro_devolver (c3)
--     en la fecha del banco y con este movimiento: Dr 1110 / Cr el banco.
--     El depósito se queda casado en su día.
do $$
declare
  v_obt text;
  v_esp text := 'propuesta=devolucion devuelto=casado:devolucion devolucion_dice=el_movimiento lineas=1098:-1500.00|1110:1500.00 '
                'deposito=casado:cobro';
  v_esc jsonb;
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (31, 'cheque devuelto: la devolución del cobro con su movimiento', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_esc := pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 12, d + 13, 0.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 13, 'monto', '-1500.00', 'id', 'C6D1', 'nombre', 'DEPOSITED ITEM RETURNED'))),
              '1098', 'c6-pruebas-devuelto.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6D1');
    v_obt := 'propuesta=' || (select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_m);
    perform pg_temp.c6_como('dueno');
    perform fn_banco_devolver(v_m, (v_esc->>'cobro')::uuid, 'c6-pruebas: sin fondos');
    execute 'reset role';
    select v_obt || format(' devuelto=%s devolucion_dice=%s lineas=%s deposito=%s', pg_temp.c6_est('1098', 'C6D1'),
                           (select case when dv.movimiento_id = v_m::text then 'el_movimiento' else coalesce(dv.movimiento_id, '-') end
                              from cobros_devoluciones dv where dv.cobro_id = (v_esc->>'cobro')::uuid),
                           (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.monto)
                              from asiento_lineas l where l.asiento_id = m.asiento_id),
                           pg_temp.c6_est('1098', 'C6C3'))
      into v_obt from movimientos_banco m where m.id = v_m;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (31, 'cheque devuelto: la devolución del cobro con su movimiento', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 32. DES-CASAR, con su motivo (sin él, no): lo que puso el banco (el
--     Zelle de Edgar clasificado) se reversa con el motivo y el movimiento
--     vuelve a la bandeja con su propuesta; lo que solo se casó (el
--     depósito con su cobro) se suelta, y el cobro suelta su movimiento
--     (la marca de c3) sin volver a casar solo (lo que Edgar des-casó lo
--     elige él); la transferencia se reversa y suelta sus DOS lados. Cada
--     casado deshecho queda con quién, cuándo y por qué.
do $$
declare
  v_obt text;
  v_esp text := 'sin_motivo=22023 clasificado=pendiente:aporte_edgar reversado=t cobro=pendiente cobro_suelto=t '
                'transferencia=pendiente+pendiente rastro=3';
  v_esc jsonb;
  v_x   text;
  v_c5  uuid;
  v_c3  uuid;
  v_c7  uuid;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (32, 'des-casar: con motivo; reversa lo que puso, suelta lo demás; queda el rastro', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_esc := pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6C5'), '[{"cuenta": "2900"}]'::jsonb, 'c6-pruebas');
    begin
      perform fn_banco_descasar(pg_temp.c6_mov('1098', 'C6C5'), '');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := 'sin_motivo=' || v_x;
    v_c5 := pg_temp.c6_mov('1098', 'C6C5');
    v_c3 := pg_temp.c6_mov('1098', 'C6C3');
    v_c7 := pg_temp.c6_mov('1098', 'C6C7');
    perform pg_temp.c6_como('dueno');
    perform fn_banco_descasar(v_c5, 'c6-pruebas: era un aporte');
    perform fn_banco_descasar(v_c3, 'c6-pruebas: era otro depósito');
    perform fn_banco_descasar(v_c7, 'c6-pruebas: no era el pago de la tarjeta');
    execute 'reset role';
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || format(' clasificado=%s reversado=%s cobro=%s cobro_suelto=%s transferencia=%s+%s rastro=%s',
               pg_temp.c6_est('1098', 'C6C5'),
               exists (select 1 from banco_casados c join asientos r on r.reversa_a = c.asiento_id and r.id = c.reverso_id
                        where c.movimiento_id = pg_temp.c6_mov('1098', 'C6C5') and c.deshecho_motivo = 'c6-pruebas: era un aporte'),
               (select m.estado from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6C3')),
               (select c.movimiento_id is null from cobros c where c.id = (v_esc->>'cobro')::uuid),
               (select m.estado from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6C7')),
               (select m.estado from movimientos_banco m where m.id = pg_temp.c6_mov('2100-9996', 'C6A3')),
               (select count(*) from banco_casados c
                 where c.deshecho_el is not null and c.deshecho_por = nullif(current_setting('mx6.dueno'), '')::uuid
                   and c.deshecho_motivo like 'c6-pruebas:%'));
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (32, 'des-casar: con motivo; reversa lo que puso, suelta lo demás; queda el rastro', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 33. LO QUE DIJO EL BANCO NO SE TOCA (MX003), ni desde el SQL Editor:
--     cambiar o borrar un movimiento, cambiar un archivo, borrar un
--     casado, escribir en el historial a mano, vaciar la tabla, o poner un
--     casado sin su función.
do $$
declare
  v_obt text := '';
  v_esp text := 'monto=MX003 borrar=MX003 archivo=MX003 casado=MX003 historial=MX003 truncate=MX003 casado_a_mano=MX003';
  v_k   text;
  v_q   text;
  v_x   text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (33, 'lo que dijo el banco no se edita ni se borra (MX003)', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    for v_k, v_q in select * from (values
        ('monto', format('update public.movimientos_banco set monto = monto + 1 where id = %L', pg_temp.c6_mov('1098', 'C6C3'))),
        ('borrar', format('delete from public.movimientos_banco where id = %L', pg_temp.c6_mov('1098', 'C6C3'))),
        ('archivo', 'update public.archivos_banco set texto = texto || '' '' where nombre = ''c6-pruebas-chase.qfx'''),
        ('casado', format('delete from public.banco_casados where movimiento_id = %L', pg_temp.c6_mov('1098', 'C6C3'))),
        ('historial', 'insert into public.banco_historial (tabla, clave, operacion) values (''movimientos_banco'', ''x'', ''UPDATE'')'),
        ('truncate', 'truncate public.movimientos_banco cascade'),
        ('casado_a_mano', format('update public.movimientos_banco set estado = ''ignorado'', estado_motivo = ''a mano'' where id = %L',
                                 pg_temp.c6_mov('1098', 'C6C4')))) as x(k, q) loop
      begin
        execute 'set local lock_timeout = ''2s''';
        execute v_q;
        v_x := 'entró';
      exception when others then v_x := sqlstate;
      end;
      v_obt := v_obt || v_k || '=' || v_x || ' ';
    end loop;
    v_obt := rtrim(v_obt);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := v_obt || sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (33, 'lo que dijo el banco no se edita ni se borra (MX003)', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 34. EL EQUIPO Y ANON no ven nada del banco: el equipo (authenticated, no
--     dueño) lee 0 filas en cada vista y tabla, y no ejecuta ninguna
--     función del banco (42501, por dentro); anon ni abre las vistas ni
--     ejecuta nada (42501).
do $$
declare
  v_obt  text;
  v_esp  text := 'equipo_filas=0 equipo_importar=42501 equipo_casar=42501 equipo_control=42501 anon_vista=42501 anon_casar=42501';
  v_n    bigint := 0;
  v_x    bigint;
  v_v    text;
  v_r    text;
  v_txt  text;
  v_e1   text;
  v_e2   text;
  v_e3   text;
  v_a1   text;
  v_a2   text;
begin
  if current_setting('mx6.equipo', true) = '' or current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (34, 'el equipo y anon no ven ni ejecutan nada del banco', v_esp,
                                 'omitida: no hay nadie del equipo activo, o falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_txt := pg_temp.c6_chase();
    perform pg_temp.c6_como('equipo');
    foreach v_v in array array['v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion', 'v_conciliacion_partidas',
                               'v_prestamos', 'v_prepagados', 'v_papel_fases', 'movimientos_banco', 'archivos_banco', 'banco_casados',
                               'banco_historial', 'conciliaciones', 'prestamos', 'prepagados'] loop
      execute format('select count(*) from public.%I', v_v) into v_x;
      v_n := v_n + v_x;
    end loop;
    begin perform fn_banco_importar_ofx(v_txt, '1098', 'x'); v_e1 := 'entró'; exception when others then v_e1 := sqlstate; end;
    begin perform fn_banco_casar_todo(null, null); v_e2 := 'entró'; exception when others then v_e2 := sqlstate; end;
    begin perform * from fn_banco_control('hoy', null); v_e3 := 'entró'; exception when others then v_e3 := sqlstate; end;
    execute 'reset role';
    perform pg_temp.c6_como('anon');
    begin execute 'select count(*) from public.v_banco_movimientos' into v_x; v_a1 := 'entró'; exception when others then v_a1 := sqlstate; end;
    begin perform fn_banco_casar_todo(null, null); v_a2 := 'entró'; exception when others then v_a2 := sqlstate; end;
    execute 'reset role';
    v_obt := format('equipo_filas=%s equipo_importar=%s equipo_casar=%s equipo_control=%s anon_vista=%s anon_casar=%s', v_n, v_e1, v_e2,
                    v_e3, v_a1, v_a2);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (34, 'el equipo y anon no ven ni ejecutan nada del banco', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 35. TODA CIFRA BAJA: cada movimiento casado (salvo el de la apertura, que
--     no tiene asiento) lleva su asiento con su número y su papel, y
--     v_asiento_papel (c4) encuentra el papel de cada asiento que puso el
--     banco (el movimiento, la cuota, el mes de prepagados); cada partida
--     de una conciliación baja a su asiento o a su movimiento.
do $$
declare
  v_obt text;
  v_esp text := 'movimientos_sin_asiento=0 asientos_sin_papel=0 papel_del_banco=t partidas_sin_clic=0';
  v_c   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (35, 'toda cifra del banco baja a su asiento, su papel y su movimiento', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6C6'), '[{"cuenta": "1050"}]'::jsonb, null);
    v_c := fn_conciliar('1098', d + 27, '-396.73');
    select format('movimientos_sin_asiento=%s', count(*) filter (where v.estado in ('casado', 'en_transito')
                                                                   and v.casado_clase <> 'apertura'
                                                                   and (v.asiento_numero is null or v.papel_tabla is null)))
      into v_obt
      from v_banco_movimientos v where v.cuenta in ('1098', '2100-9996', '1097');
    select v_obt || format(' asientos_sin_papel=%s papel_del_banco=%s',
                           count(*) filter (where not p.papel_existe),
                           bool_and(p.papel like 'Movimiento del banco%') filter (where p.origen_tabla = 'movimientos_banco'))
      into v_obt
      from v_asiento_papel p
     where p.origen_tabla in ('movimientos_banco', 'prestamo_cuotas', 'prepagados')
       and p.asiento_id in (select m.asiento_id from movimientos_banco m where m.cuenta in ('1098', '2100-9996', '1097'));
    v_obt := v_obt || ' partidas_sin_clic=' || (select count(*) from v_conciliacion_partidas p
                                                 where p.conciliacion_id = (v_c->>'conciliacion')::uuid
                                                   and p.asiento_id is null and p.movimiento_id is null and p.apertura_partida_id is null
                                                   and p.grupo <> 'casado');
    v_obt := replace(v_obt, '=true', '=t');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (35, 'toda cifra del banco baja a su asiento, su papel y su movimiento', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 36. EL CONTROL que lee conta.js antes de pintar (fn_banco_control, el
--     contrato de fn_estados_control): con todo bien, cada vista con las
--     filas que dicen las tablas y los cuadres en verde; con una vista
--     vacía («esperaba N»), con una que ya no está (falló), con una lista
--     vacía o un nombre que no conoce: en rojo, no se pinta. Un cuadre
--     pedido solo, por su nombre, sale solo (con las protecciones).
do $$
declare
  v_obt text;
  v_esp text := 'bien=t solo=53,90,91 vacia=f:esperaba rota=f:falló lista_vacia=f desconocida=f';
  v_ok  boolean;
  v_det text;
  v_mes text := current_setting('mx6.mes', true);
begin
  if v_mes = '' then
    insert into _pruebas values (36, 'fn_banco_control: en verde con todo; en rojo con una vista vacía o rota', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform pg_temp.c6_como('dueno');
    -- (ronda 4d: el cuadre 59, «el otro lado de cada casado», mira todo el
    -- banco: con datos de verdad puede venir en rojo por lo suyo —lo que
    -- Edgar casó antes de la 4d y tiene que revisar—; aquí cuenta solo lo de
    -- la prueba, con la referencia)
    select bool_and(c.ok) into v_ok from fn_banco_control(v_mes, array['v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos']) c
     where c.vista not in ('cuadre: prepagados', 'cuadre: préstamos', 'cuadre: el otro lado de cada casado');
    execute 'reset role';
    v_ok := v_ok and not exists (select 1 from unnest(array['1098', '1097', '2100-9996', '2100-9995']) as c(cuenta)
                                   cross join lateral fn_banco_criterio_casados(c.cuenta) x);
    perform pg_temp.c6_como('dueno');
    v_obt := 'bien=' || case when v_ok then 't' else 'f' end;
    v_obt := v_obt || ' solo=' || (select string_agg(c.orden::text, ',' order by c.orden)
                                     from fn_banco_control(v_mes, array['cuadre: archivos intactos']) c);
    execute 'reset role';
    execute 'set local lock_timeout = ''2s''';
    execute format('create or replace view public.v_banco_bandeja with (security_invoker = true) as select * from (%s) x where false',
                   rtrim(pg_get_viewdef('public.v_banco_bandeja'::regclass), '; ' || chr(10)));
    execute 'drop view public.v_conciliacion';
    select c.ok, c.detalle into v_ok, v_det from fn_banco_control(v_mes, array['v_banco_bandeja']) c where c.vista = 'v_banco_bandeja';
    v_obt := v_obt || ' vacia=' || case when v_ok then 't' else 'f' end || case when v_det like '%esperaba%' then ':esperaba' else '' end;
    select c.ok, c.detalle into v_ok, v_det from fn_banco_control(v_mes, array['v_conciliacion']) c where c.vista = 'v_conciliacion';
    v_obt := v_obt || ' rota=' || case when v_ok then 't' else 'f' end || case when v_det like '%falló%' then ':falló' else '' end;
    select bool_and(c.ok) into v_ok from fn_banco_control(v_mes, '{}'::text[]) c;
    v_obt := v_obt || ' lista_vacia=' || case when v_ok then 't' else 'f' end;
    select bool_and(c.ok) into v_ok from fn_banco_control(v_mes, array['v_banco_movimiento']) c where c.orden = 0;
    v_obt := v_obt || ' desconocida=' || case when v_ok then 't' else 'f' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (36, 'fn_banco_control: en verde con todo; en rojo con una vista vacía o rota', v_esp,
                               coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 37. c2, c3 Y c4 AL DÍA: con la marca de un c2 anterior (fn_libro_version
--     2026092504), el control del banco lo dice en rojo, con qué volver a
--     pegar; con la de hoy, en verde.
do $$
declare
  v_obt text;
  v_esp text := 'hoy=t viejo=f:c2-libro.sql';
  v_ok  boolean;
  v_det text;
  v_src text;
begin
  select pg_get_functiondef('public.fn_libro_version()'::regprocedure) into v_src;
  select c.ok into v_ok from fn_banco_control('hoy', array['v_banco_saldos']) c where c.vista = 'cuadre: c2, c3 y c4 al día';
  v_obt := 'hoy=' || case when v_ok then 't' else 'f' end;
  begin
    execute 'set local lock_timeout = ''2s''';
    execute regexp_replace(v_src, '20[0-9]{8}', '2026092504');
    select c.ok, c.detalle into v_ok, v_det from fn_banco_control('hoy', array['v_banco_saldos']) c
     where c.vista = 'cuadre: c2, c3 y c4 al día';
    v_obt := v_obt || ' viejo=' || case when v_ok then 't' else 'f' end || case when v_det like '%c2-libro.sql%' then ':c2-libro.sql' else '' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida';
    when others then v_obt := v_obt || ' ' || sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (37, 'c2, c3 y c4 al día (su marca), o el control lo dice', v_esp, coalesce(v_obt, '-'),
                               case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 38. c2 CONOCE AL BANCO: con el banco trabajando (archivos, casados,
--     asientos del banco, conciliación), el verificador del libro sigue en
--     verde (sus funciones de la app están en su reparto y en sus huellas),
--     y el asiento de un movimiento no se reversa a mano: fn_reversar dice
--     cómo (des-casarlo, MX007). Y ninguna vista del banco nombra
--     cuentas.activa, cuentas.saldo_normal, periodos.estado ni
--     periodos.cerrado_* (les fijaría el tipo, y las pruebas 24 y 66 de c2
--     las reescriben por debajo de sus triggers, como ataque).
do $$
declare
  v_obt text;
  v_esp text := 'libro=t reversar=MX007:fn_banco_descasar fijadas=0';
  v_ok  boolean;
  v_a   uuid;
  v_x   text;
begin
  if current_setting('mx6.desde', true) = '' or current_setting('mx6.dueno', true) = '' then
    insert into _pruebas values (38, 'c2 conoce al banco: el libro en verde y fn_reversar dice cómo deshacer', v_esp,
                                 'omitida: falta mes abierto o el dueño', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    select bool_and(v.ok) into v_ok from fn_verificar_cadena() v where v.control in ('triggers', 'permisos', 'cuadre', 'reversos');
    v_a := (select m.asiento_id from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6C11'));
    perform pg_temp.c6_como('dueno');
    begin
      perform fn_reversar(v_a, 'c6-pruebas: a mano');
      v_x := 'entró';
    exception when others then
      v_x := sqlstate || case when sqlerrm like '%fn_banco_descasar%' then ':fn_banco_descasar' else '' end;
    end;
    execute 'reset role';
    v_obt := 'libro=' || case when v_ok then 't' else 'f' end || ' reversar=' || v_x || ' fijadas='
             || (select count(*) from pg_depend dp
                   join pg_rewrite rw on rw.oid = dp.objid
                   join pg_class vw on vw.oid = rw.ev_class
                   join pg_attribute at on at.attrelid = dp.refobjid and at.attnum = dp.refobjsubid
                  where dp.classid = 'pg_rewrite'::regclass and dp.refclassid = 'pg_class'::regclass
                    and vw.relnamespace = 'public'::regnamespace
                    and vw.relname in ('v_papel_fases', 'v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion',
                                       'v_conciliacion_partidas', 'v_prestamos', 'v_prepagados')
                    and ((dp.refobjid = 'public.cuentas'::regclass and at.attname in ('activa', 'saldo_normal'))
                         or (dp.refobjid = 'public.periodos'::regclass and (at.attname = 'estado' or at.attname like 'cerrado%'))));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (38, 'c2 conoce al banco: el libro en verde y fn_reversar dice cómo deshacer', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 39. LA REVISIÓN ENTERA (fn_banco_verificar, desde el SQL Editor): con el
--     mes casado, una conciliación confirmada (recalculada, da lo mismo) y
--     los archivos leídos otra vez, todo en verde; y los controles de los
--     puentes (c3) también, con los asientos del banco en el libro: ninguno
--     en rojo por algo del escenario (con datos de verdad, un control de c3
--     puede venir en rojo por lo suyo: sale aquí solo si nombra un asiento
--     o un papel de esta prueba; lo demás lo dice c3-pruebas). El
--     escenario lleva también la nómina del proveedor anterior con su
--     journal (la de la 58): el control de mano de obra de c3 no la cuenta.
--     (Se mira aquí, en la misma pasada de los controles de c3: con un año
--     de libro, cada pasada tarda unos 2 s.)
do $$
declare
  v_obt   text;
  v_esp   text := 'banco=t puentes=t nomina=casado:asiento';
  v_ok    boolean;
  v_ok2   boolean;
  v_c     jsonb;
  v_pos   bigint;
  d       date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (39, 'fn_banco_verificar y los controles de los puentes, en verde con el banco trabajando', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    -- (Dónde va la cadena: los asientos de la prueba son los de después.)
    select coalesce(max(a.cadena_pos), 0) into v_pos from asientos a;
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 15, 'monto', '-4000.00', 'id', 'C6J9', 'nombre', 'ADP PAYROLL FEES'))),
              '1098', 'c6-pruebas-adp-39.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_nomina(pg_temp.c6_mov('1098', 'C6J9'), jsonb_build_array(
              jsonb_build_object('cuenta', '5000', 'monto', '3500.00', 'proyecto_id', current_setting('mx6.obra'), 'memo', 'Sueldos'),
              jsonb_build_object('cuenta', '5015', 'monto', '500.00', 'memo', 'Impuestos patronales')), 'c6-pruebas: ADP de octubre');
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A2'),
                                jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas');
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A4'), '[{"cuenta": "7100"}]'::jsonb, null);
    v_c := fn_conciliar('2100-9996', d + 22);
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    -- (Solo las cuentas de la prueba: con un año de banco de verdad, la
    -- revisión entera tarda y la prueba tendría tomados los candados de los
    -- recibos todo ese tiempo.)
    -- (ronda 4d: con cuentas pedidas, la revisión ya no trae los cuadres del
    -- control —miran todo el banco y costaban un cuarto de segundo por
    -- llamada con un año de banco—: los de siempre se piden aquí, al control,
    -- sin préstamos ni prepagados, como antes; y sin el 59, «el otro lado de
    -- cada casado», que con datos de verdad puede venir en rojo por lo suyo:
    -- lo de las cuentas de la prueba lo dice su fila en la revisión, con la
    -- referencia de esas cuentas)
    select bool_and(v.ok) into v_ok from fn_banco_verificar(array['1098', '1097', '2100-9996', '2100-9995']) v;
    v_ok := v_ok and (select bool_and(c.ok)
                        from fn_banco_control('hoy', array['cuadre: un movimiento, un casado', 'cuadre: depósitos nunca a ingreso',
                                                           'cuadre: archivos intactos', 'cuadre: ningún ticket después de clasificar',
                                                           'cuadre: conciliaciones confirmadas']) c
                       where c.vista like 'cuadre:%');
    select bool_and(p.ok
                    or not (exists (select 1 from asientos a where a.cadena_pos > v_pos and position(a.numero in p.detalle::text) > 0)
                            or p.detalle::text ~ '(-66[0-9]{4}|C6-|1098|1097|2100-999[56]|c6-pruebas)'))
      into v_ok2 from fn_puentes_verificar() p
     where p.control in ('triggers', 'documentos', 'use_tax', 'mano_de_obra', 'partidas', 'duplicados', 'vistas');
    v_obt := format('banco=%s puentes=%s nomina=%s', case when v_ok then 't' else 'f' end, case when v_ok2 then 't' else 'f' end,
                    pg_temp.c6_est('1098', 'C6J9'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (39, 'fn_banco_verificar y los controles de los puentes, en verde con el banco trabajando', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- =====================================================================
-- Lo que corrigió la ronda de c6 (una prueba por hallazgo)
-- =====================================================================

-- 40. EL ZELLE DE UN CLIENTE NO ES UNA TRANSFERENCIA: el pago de una
--     tarjeta y el pase a la reserva se reconocen por la descripción del
--     banco (NAME, no la nota que escribe quien manda el dinero) y en su
--     dirección (del banco a la tarjeta). Un Zelle con «thank you» en la
--     nota y una compra de la tarjeta del mismo monto un día antes NO casan
--     solos (antes, como un adelanto de la tarjeta: el cobro no entraba
--     nunca y la compra se contaba dos veces); el Zelle propone la factura
--     que lo explica, sin ninguna transferencia, y la compra espera su
--     ticket.
do $$
declare
  v_obt text;
  v_esp text := 'zelle=pendiente:deposito_sin_cobro compra=pendiente:sin_ticket factura=t transferencias=0 opcion_tarjeta=0';
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (40, 'el Zelle de un cliente con «thank you» no se casa como transferencia; propone su factura', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660401, current_setting('mx6.obra'), 'C6-40', d + 1, 3000.00, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 12, 3000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 10, 'monto', '3000.00', 'id', 'C6Z1', 'nombre', 'ZELLE FROM JOHN SMITH',
                                 'memo', 'Inv C6-40 thank you'))), '1098', 'c6-pruebas-zelle.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 12, -3000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 9, 'monto', '-3000.00', 'id', 'C6Z2', 'nombre', 'GRAYBAR ELECTRIC CO'))),
              null, 'c6-pruebas-graybar.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_casar_todo('2100-9996');
    select format('zelle=%s compra=%s factura=%s transferencias=%s opcion_tarjeta=%s', pg_temp.c6_est('1098', 'C6Z1'),
                  pg_temp.c6_est('2100-9996', 'C6Z2'),
                  case when exists (select 1 from jsonb_array_elements(m.propuesta->'opciones') o
                                     where o->>'llamar' = 'fn_banco_cobrar') then 't' else 'f' end,
                  (select count(*) from banco_casados c
                    where c.movimiento_id in (pg_temp.c6_mov('1098', 'C6Z1'), pg_temp.c6_mov('2100-9996', 'C6Z2'))
                      and c.clase = 'transferencia'),
                  (select count(*) from jsonb_array_elements(m.propuesta->'opciones') o where o->>'llamar' = 'fn_banco_transferencia'))
      into v_obt
      from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6Z1');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (40, 'el Zelle de un cliente con «thank you» no se casa como transferencia; propone su factura', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 41. EL PASE A LA RESERVA QUE TARDA (un ACH a otro banco, 3 a 5 días
--     hábiles): dos pases semanales iguales, cada uno con su otro lado (el
--     que llega DESPUÉS de que sale, hasta 10 días), un asiento por pase;
--     el lado que Edgar confirmó primero y el otro que llega 5 días
--     después casa solo con ESE asiento; y fn_banco_transferencia sobre el
--     que llega no postea otra (MX008: antes, el mismo dinero dos veces).
do $$
declare
  v_obt text;
  v_esp text := 'semana1=mismo semana2=mismo asientos=2 otra_transferencia=MX008 otro_lado=casado:transferencia primero=casado';
  v_w5  uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (41, 'el pase a la reserva que tarda días casa con su otro lado, uno por pase, nunca dos', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 14, 1000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-700.00', 'id', 'C6W5', 'nombre', 'ONLINE TRANSFER TO SAV XXXXXX1097'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 5, 'monto', '-500.00', 'id', 'C6W1', 'nombre', 'ONLINE TRANSFER TO SAV XXXXXX1097'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 12, 'monto', '-500.00', 'id', 'C6W2', 'nombre', 'ONLINE TRANSFER TO SAV XXXXXX1097'))),
              '1098', 'c6-pruebas-pases.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 17, 1000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 10, 'monto', '500.00', 'id', 'C6W3', 'nombre', 'ONLINE TRANSFER FROM CHK XXXXXX1098'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 17, 'monto', '500.00', 'id', 'C6W4', 'nombre', 'ONLINE TRANSFER FROM CHK XXXXXX1098'))),
              '1097', 'c6-pruebas-reserva-pases.ofx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_casar_todo('1097');
    select format('semana1=%s semana2=%s asientos=%s',
                  case when a1.asiento_id = a3.asiento_id then 'mismo' else 'otro' end,
                  case when a2.asiento_id = a4.asiento_id then 'mismo' else 'otro' end,
                  (select count(distinct m.asiento_id) from movimientos_banco m
                    where m.id in (a1.id, a2.id, a3.id, a4.id)))
      into v_obt
      from movimientos_banco a1, movimientos_banco a2, movimientos_banco a3, movimientos_banco a4
     where a1.id = pg_temp.c6_mov('1098', 'C6W1') and a2.id = pg_temp.c6_mov('1098', 'C6W2')
       and a3.id = pg_temp.c6_mov('1097', 'C6W3') and a4.id = pg_temp.c6_mov('1097', 'C6W4');
    -- El de 700, confirmado por Edgar con un solo lado; su otro lado llega
    -- 5 días después (sin casar todavía).
    v_w5 := pg_temp.c6_mov('1098', 'C6W5');
    perform fn_banco_transferencia(v_w5, '1097');
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d + 8, d + 9, 1700.00, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 8, 'monto', '700.00', 'id', 'C6W6', 'nombre', 'ONLINE TRANSFER FROM CHK XXXXXX1098'))),
              '1097', 'c6-pruebas-reserva-700.ofx');
    begin
      perform fn_banco_transferencia(pg_temp.c6_mov('1097', 'C6W6'), '1098');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform fn_banco_casar_todo('1097');
    v_obt := v_obt || format(' otra_transferencia=%s otro_lado=%s primero=%s', v_x, pg_temp.c6_est('1097', 'C6W6'),
                             (select m.estado from movimientos_banco m where m.id = v_w5));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (41, 'el pase a la reserva que tarda días casa con su otro lado, uno por pase, nunca dos', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 42. LO QUE YA ESTÁ EN EL LIBRO A MÁS DE 3 DÍAS DEL BANCO se casa o se
--     propone, no se clasifica otra vez: la compra de la Amex posteada 6
--     días después de su ticket (su DTUSER = la fecha del ticket) casa
--     sola; la de la débito, sin DTUSER, a 6 días también; el cheque 1045
--     anotado a mano casa por su NÚMERO aunque el banco lo cobre 19 días
--     después; el cheque sin su número en el libro (28 días) se propone
--     («puede ser») y clasificarlo sin motivo no entra. Y el texto de un
--     cargo sin ticket no dice «Obra propuesta:  ().» sin obra.
do $$
declare
  v_obt text;
  v_esp text := 'amex=casado:recibo debito=casado:recibo cheque=casado:asiento debil=pendiente:varios_candidatos clasificar=MX008 '
                'texto=sin_hueco';
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (42, 'lo del libro a más de 3 días (DTUSER, débito, cheque) se casa o se propone, no se clasifica', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660421, 'total', 89.99, 'fecha', d + 2, 'proveedor', 'SHELL OIL'));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660422, 'total', 86.40, 'fecha', d + 4, 'metodo_pago', 'debito',
                                                 'proveedor', 'C6 FERRETERIA'));
    perform fn_postear(jsonb_build_object('fecha', (d + 1)::text, 'descripcion', 'c6-pruebas: la renta con el cheque 1045 (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '-1000.00', 'memo', 'Cheque 1045'),
                                  jsonb_build_object('cuenta', '6100', 'monto', '1000.00'))));
    perform fn_postear(jsonb_build_object('fecha', (d + 2)::text, 'descripcion', 'c6-pruebas: un pago con cheque (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '-777.00'),
                                  jsonb_build_object('cuenta', '6100', 'monto', '777.00'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 9, -89.99, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 8, 'fecha_usuario', d + 2, 'monto', '-89.99', 'id', 'C6D1',
                                 'nombre', 'SHELL OIL 57442'))), null, 'c6-pruebas-shell.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 30, -1909.85, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 10, 'monto', '-86.40', 'id', 'C6D2', 'nombre', 'C6 FERRETERIA #3'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 12, 'monto', '-45.45', 'id', 'C6D5', 'nombre', 'C6 SIN TICKET'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 20, 'monto', '-1000.00', 'id', 'C6D3', 'nombre', 'CHECK 1045',
                                 'cheque', '1045'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 30, 'monto', '-777.00', 'id', 'C6D4', 'nombre', 'CHECK 2001',
                                 'cheque', '2001'))), '1098', 'c6-pruebas-cheques.qfx');
    perform fn_banco_casar_todo('2100-9996');
    perform fn_banco_casar_todo('1098');
    begin
      perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6D4'), '[{"cuenta": "6100"}]'::jsonb, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('amex=%s debito=%s cheque=%s debil=%s clasificar=%s texto=%s', pg_temp.c6_est('2100-9996', 'C6D1'),
                    pg_temp.c6_est('1098', 'C6D2'), pg_temp.c6_est('1098', 'C6D3'), pg_temp.c6_est('1098', 'C6D4'), v_x,
                    (select case when m.propuesta->>'texto' like '%()%' then 'con_hueco' else 'sin_hueco' end
                       from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6D5')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (42, 'lo del libro a más de 3 días (DTUSER, débito, cheque) se casa o se propone, no se clasifica', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 43. LA CUOTA YA REGISTRADA con el statement del prestamista (antes que
--     el banco) espera su cargo: si el cargo llega 14 días después, la
--     bandeja propone casar con ELLA (no registrar otra), fn_prestamo_cuota
--     no registra otra (MX008: antes, dos cuotas en el mes, capital e
--     interés dos veces), y casarla deja una sola cuota viva.
do $$
declare
  v_obt text;
  v_esp text := 'propuesta=cuota_prestamo:fn_banco_casar_con otra_cuota=MX008 casado=casado:cuota_prestamo cuotas=1';
  v_p   uuid;
  v_m   uuid;
  v_x   text;
  v_op  jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (43, 'la cuota ya registrada espera su cargo: se casa con ella, no se registra otra', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_p := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS CREDIT', 'descripcion', 'camioneta de prueba',
             'principal', '52000.00', 'tasa_anual', '6.99', 'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15,
             'plazo_meses', 60, 'saldo_inicial', '31415.26', 'saldo_inicial_al', (d - 1)::text, 'cuenta_banco', '1098',
             'descriptor', 'C6 PRUEBAS CREDIT'))->>'id')::uuid;
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: el préstamo (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '31415.26'),
                                  jsonb_build_object('cuenta', '2520', 'monto', '-31415.26'))));
    perform fn_prestamo_cuota(v_p, null, d + 5, '1029.33', '848.62', '180.71', 'c6-pruebas: del statement');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 1.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 19, 'monto', '-1029.33', 'id', 'C6Q1', 'nombre', 'C6 PRUEBAS CREDIT PMT'))),
              '1098', 'c6-pruebas-cuota.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6Q1');
    select m.propuesta->'opciones'->0, format('propuesta=%s:%s', m.propuesta->>'motivo', m.propuesta->'opciones'->0->>'llamar')
      into v_op, v_obt
      from movimientos_banco m where m.id = v_m;
    begin
      perform fn_prestamo_cuota(v_p, v_m);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform fn_banco_casar_con(v_m, v_op->'args'->'p_con', null);
    v_obt := v_obt || format(' otra_cuota=%s casado=%s cuotas=%s', v_x, pg_temp.c6_est('1098', 'C6Q1'),
                             (select count(*) from prestamo_cuotas q where q.prestamo_id = v_p and q.anulada_el is null));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (43, 'la cuota ya registrada espera su cargo: se casa con ella, no se registra otra', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 44. EL TICKET QUE LLEGA DESPUÉS DE CLASIFICAR su cargo ya no pasa
--     callado: el cargo sale en la bandeja («llego_su_ticket»), el control
--     lo dice en rojo, la conciliación lo pone como posible duplicado (no
--     como cargo en circulación) y no se confirma; «no es su ticket» pide
--     su motivo; cambiar la clasificación por el ticket (fn_banco_casar_con)
--     reversa la clasificación, casa el cargo con el ticket y deja el gasto
--     una vez; y entonces el control y la conciliación, en verde.
do $$
declare
  v_obt text;
  v_esp text := 'clasificado=casado:clasificado bandeja=llego_su_ticket control=f conciliacion=posible_duplicado:MX008 '
                'sin_motivo=22023 cambio=casado:recibo gasto_6400=0.00 control_despues=t confirma=confirmada';
  v_m   uuid;
  v_c   jsonb;
  v_x   text;
  v_y   text;
  v_pos bigint;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (44, 'el ticket que llega después de clasificar se dice, bloquea y se cambia por la clasificación', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 20, -45.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 10, 'monto', '-45.00', 'id', 'C6K1', 'nombre', 'C6 AMAZON MKTPLACE'))),
              null, 'c6-pruebas-amazon.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6K1');
    perform fn_banco_clasificar(v_m, '[{"cuenta": "6400"}]'::jsonb, null);
    v_obt := 'clasificado=' || pg_temp.c6_est('2100-9996', 'C6K1');
    -- La cuadrilla sube la foto días después.
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660441, 'total', 45.00, 'fecha', d + 9, 'proveedor', 'AMAZON'));
    perform fn_banco_casar_todo('2100-9996');
    v_obt := v_obt || ' bandeja=' || coalesce((select b.motivo from v_banco_bandeja b where b.movimiento_id = v_m), 'no_está')
             || ' control=' || pg_temp.c6_cuadre('cuadre: ningún ticket después de clasificar', current_setting('mx6.mes'), v_m::text);
    v_c := fn_conciliar('2100-9996', d + 20, '45.00');
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := 'confirmó';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' conciliacion=' || coalesce((select string_agg(p.clase, ',') from conciliacion_partidas p
                                                     where p.conciliacion_id = (v_c->>'conciliacion')::uuid), '-') || ':' || v_x;
    begin
      perform fn_banco_duplicado(v_m, false, null);
      v_y := 'entró';
    exception when others then v_y := sqlstate;
    end;
    perform fn_banco_casar_con(v_m, jsonb_build_object('recibo', -660441), 'c6-pruebas: es su ticket');
    v_c := fn_conciliar('2100-9996', d + 20, '45.00');
    v_obt := v_obt || format(' sin_motivo=%s cambio=%s gasto_6400=%s control_despues=%s confirma=%s', v_y,
                             pg_temp.c6_est('2100-9996', 'C6K1'),
                             (select coalesce(sum(l.monto), 0)::numeric(14,2) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where a.cadena_pos > v_pos and l.cuenta = '6400'),
                             pg_temp.c6_cuadre('cuadre: ningún ticket después de clasificar', current_setting('mx6.mes'), v_m::text),
                             fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid)->>'estado');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (44, 'el ticket que llega después de clasificar se dice, bloquea y se cambia por la clasificación', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 45. UN DEPÓSITO NO VA A OTROS INGRESOS SIN SU MOTIVO: a 4900 sin motivo
--     no entra (MX008; antes entraba y el ingreso quedaba dos veces); con
--     su motivo escrito, sí, y el control lo acepta; los intereses del
--     banco (tipo INT) a 4910, sin motivo; y un asiento del banco que lleva
--     un depósito a 4900 sin motivo (por la puerta interna, a propósito)
--     sale en rojo en «depósitos nunca a ingreso».
do $$
declare
  v_obt text;
  v_esp text := 'sin_motivo=MX008 con_motivo=casado:clasificado intereses=casado:clasificado control=t interno=f';
  v_x   text;
  v_m3  uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (45, 'un depósito no va a otros ingresos (49xx) sin su motivo; el control lo vigila', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 2603.21, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 6, 'monto', '2500.00', 'id', 'C6I1', 'nombre', 'C6 DEPOSITO VARIO'),
              jsonb_build_object('tipo', 'INT', 'fecha', d + 27, 'monto', '3.21', 'id', 'C6I2', 'nombre', 'C6 RENDIMIENTO'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 8, 'monto', '100.00', 'id', 'C6I3', 'nombre', 'C6 OTRO DEPOSITO'))),
              '1098', 'c6-pruebas-ingresos.qfx');
    perform fn_banco_casar_todo('1098');
    begin
      perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6I1'), '[{"cuenta": "4900"}]'::jsonb, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6I1'), '[{"cuenta": "4900"}]'::jsonb,
                                'c6-pruebas: el reembolso de un seguro, no es de un cliente');
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6I2'), '[{"cuenta": "4910"}]'::jsonb, null);
    v_m3 := pg_temp.c6_mov('1098', 'C6I3');
    v_obt := format('sin_motivo=%s con_motivo=%s intereses=%s control=%s', v_x, pg_temp.c6_est('1098', 'C6I1'),
                    pg_temp.c6_est('1098', 'C6I2'),
                    case when pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'),
                                                pg_temp.c6_mov('1098', 'C6I1')::text) = 't'
                          and pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'),
                                                pg_temp.c6_mov('1098', 'C6I2')::text) = 't' then 't' else 'f' end);
    perform fn_postear_interno(jsonb_build_object(
      'camino', 'puente', 'fecha', (d + 8)::text, 'descripcion', 'c6-pruebas: un depósito a otros ingresos sin motivo (se deshace)',
      'origen_tabla', 'movimientos_banco', 'origen_id', v_m3::text,
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '100.00'),
                                  jsonb_build_object('cuenta', '4900', 'monto', '-100.00'))));
    v_obt := v_obt || ' interno=' || pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'), v_m3::text);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (45, 'un depósito no va a otros ingresos (49xx) sin su motivo; el control lo vigila', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 46. LOS PREPAGADOS DE ANTES DEL CORTE amortizan lo que dejó QuickBooks
--     (su saldo al corte, el número de la balanza), no un cálculo por
--     días: una póliza de 4,800.00 del 1-dic al 30-nov que QuickBooks
--     amortizó 1/12 al mes llega con 800.00; el libro amortiza 406.56 en
--     octubre y 393.44 en noviembre, y al vencer lo que la prueba puso en
--     1410 queda en 0.00 (antes, -2.19 y el control en rojo para siempre).
--     Sin su saldo al corte, la póliza no se da de alta. (Mide solo las
--     líneas de SU póliza: con una póliza de verdad de antes del corte ya
--     guardada, su amortización de estos meses no es de la prueba.)
do $$
declare
  v_obt text;
  v_esp text := 'sin_saldo=22023 oct=406.56 nov=393.44 falta=0.00 libro_1410=0.00';
  v_pos bigint;
  v_id  uuid;
  v_x   text;
  v_ini date;
  v_fin date;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or d <> fn_puente_corte() or current_setting('mx6.sig', true) = '' then
    insert into _pruebas values (46, 'prepagados de antes del corte: se amortiza el saldo que dejó QuickBooks y 1410 queda en cero', v_esp,
                                 'omitida: el mes abierto más antiguo no es el primero después del corte, o no está abierto el siguiente',
                                 null);
    return;
  end if;
  if pg_temp.c6_amortizado_despues() is not null then
    insert into _pruebas values (46, 'prepagados de antes del corte: se amortiza el saldo que dejó QuickBooks y 1410 queda en cero', v_esp,
                                 format('omitida: ya está amortizado %s, posterior al mes abierto más antiguo (se amortiza el último)',
                                        pg_temp.c6_amortizado_despues()), null);
    return;
  end if;
  v_ini := (d - interval '10 months')::date;
  v_fin := (d + interval '2 months')::date - 1;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    begin
      perform fn_prepagado_guardar(jsonb_build_object('descripcion', 'c6-pruebas GL QB', 'tipo', 'seguro', 'cuenta_gasto', '6200',
                'monto', '4800.00', 'desde', v_ini::text, 'hasta', v_fin::text));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_id := (fn_prepagado_guardar(jsonb_build_object('descripcion', 'c6-pruebas GL QB', 'tipo', 'seguro', 'cuenta_gasto', '6200',
               'monto', '4800.00', 'desde', v_ini::text, 'hasta', v_fin::text, 'saldo_corte', '800.00'))->>'id')::uuid;
    -- Lo que dejó la apertura en 1410 para ella.
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: lo que QuickBooks dejó en 1410 (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1410', 'monto', '800.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-800.00'))));
    perform fn_prepagados_amortizar(current_setting('mx6.mes'));
    perform fn_prepagados_amortizar(current_setting('mx6.sig'));
    select format('sin_saldo=%s oct=%s nov=%s falta=%s libro_1410=%s', v_x,
                  (select a.monto from prepagados_amortizaciones a where a.prepagado_id = v_id and a.vigente
                      and a.periodo = current_setting('mx6.mes')),
                  (select a.monto from prepagados_amortizaciones a where a.prepagado_id = v_id and a.vigente
                      and a.periodo = current_setting('mx6.sig')),
                  (select x.por_amortizar from v_prepagados x where x.prepagado_id = v_id),
                  -- (solo lo de ESTA póliza: lo que la prueba puso en 1410 y sus
                  -- amortizaciones; una póliza de verdad de antes del corte
                  -- también se amortiza en estos meses y no es de la prueba)
                  (select coalesce(sum(l.monto), 0)::numeric(14,2) from asiento_lineas l join asientos a on a.id = l.asiento_id
                    where a.cadena_pos > v_pos and l.cuenta = '1410'
                      and (a.descripcion like 'c6-pruebas: lo que QuickBooks dejó en 1410%'
                           or l.memo = 'Amortización · c6-pruebas GL QB')))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (46, 'prepagados de antes del corte: se amortiza el saldo que dejó QuickBooks y 1410 queda en cero', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 47. EL TICKET TARDÍO NO BLOQUEA LA CONCILIACIÓN PARA SIEMPRE: una compra
--     con la débito del último día del mes cuyo ticket se sube con el mes
--     ya cerrado (c3 lo postea el día 1 del mes abierto, «tardío») casa
--     con su cargo; en la conciliación de ese mes es una partida explicada
--     («en_libros_despues», no frena) y la conciliación se confirma.
--     (Con el reloj fingido: el mes cerrado dentro de la subtransacción.)
do $$
declare
  v_obt text;
  v_esp text := 'casado=casado:recibo tardio=t clase=en_libros_despues lista=true confirma=confirmada';
  v_c   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
  v_fin date;
begin
  if d is null or current_setting('mx6.sig', true) = '' then
    insert into _pruebas values (47, 'el ticket tardío (mes cerrado) casa y su conciliación se confirma con la partida explicada', v_esp,
                                 'omitida: falta mes abierto o el siguiente', null);
    return;
  end if;
  v_fin := (d + interval '1 month')::date - 1;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, v_fin, -133.70, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', v_fin, 'monto', '-133.70', 'id', 'C6F1', 'nombre', 'C6 FERRETERIA #9'))),
              '1098', 'c6-pruebas-tardio.qfx');
    perform pg_temp.c6_cerrar_hasta(current_setting('mx6.mes'));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660471, 'total', 133.70, 'fecha', v_fin - 1, 'metodo_pago', 'debito',
                                                 'proveedor', 'C6 FERRETERIA'));
    perform fn_banco_casar_todo('1098');
    v_c := fn_conciliar('1098', v_fin, '-133.70');
    v_obt := format('casado=%s tardio=%s clase=%s lista=%s confirma=%s', pg_temp.c6_est('1098', 'C6F1'),
                    (select case when a.procedencia ? 'tardio' then 't' else 'f' end from asientos a
                      where a.id = (select m.asiento_id from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6F1'))),
                    coalesce((select string_agg(p.clase, ',') from conciliacion_partidas p
                               where p.conciliacion_id = (v_c->>'conciliacion')::uuid), '-'),
                    v_c->>'lista_para_confirmar', fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid)->>'estado');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa periodos (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (47, 'el ticket tardío (mes cerrado) casa y su conciliación se confirma con la partida explicada', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 48. LO QUE DIJO EL BANCO, CAMBIADO O BORRADO POR FUERA (con las guardas
--     apagadas un instante, algo que solo puede el dueño de la base): el
--     control ve el monto cambiado (su sello no da) y la revisión entera
--     relee el archivo fila por fila y ve los dos, el cambiado y el
--     borrado. Antes solo se contaban filas y los dos quedaban en verde.
--     Y un movimiento que entró antes de que hubiera sellos (sin sello)
--     sale en rojo hasta que el pegado lo sella: la guarda deja ponerle
--     SOLO el sello (con la marca «sellar:»), y ponerle el sello cambiando
--     otra cosa, no (MX003).
do $$
declare
  v_obt text;
  v_esp text := 'control=f verificar=f filas=2 sin_sello=f sellado=t con_cambio=MX003';
  v_m1  uuid;
  v_m2  uuid;
  v_m3  uuid;
  v_d   jsonb;
  v_s1  text;
  v_s2  text;
  v_s3  text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (48, 'un movimiento cambiado o borrado con las guardas apagadas sale en rojo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    v_m1 := pg_temp.c6_mov('1098', 'C6C5');
    v_m2 := pg_temp.c6_mov('1098', 'C6C8');
    v_m3 := pg_temp.c6_mov('1098', 'C6C6');
    alter table public.movimientos_banco disable trigger user;
    alter table public.movimientos_banco_ids disable trigger user;
    alter table public.archivos_banco disable trigger user;
    update public.movimientos_banco set monto = 100.00 where id = v_m1;
    update public.movimientos_banco set sello = null where id = v_m3;   -- como uno de la versión de antes
    delete from public.movimientos_banco_ids where movimiento_id = v_m2;
    delete from public.movimientos_banco where id = v_m2;
    update public.archivos_banco set filas_nuevas = filas_nuevas - 1, filas_leidas = filas_leidas - 1
     where id = (select m.archivo_id from movimientos_banco m where m.id = v_m1);
    alter table public.movimientos_banco enable trigger user;
    alter table public.movimientos_banco_ids enable trigger user;
    alter table public.archivos_banco enable trigger user;
    v_s1 := pg_temp.c6_cuadre('cuadre: archivos intactos', current_setting('mx6.mes'), v_m3::text);
    -- Sellarlo con el sello y algo más cambiado: no.
    begin
      perform fn_banco_marca('sellar:' || v_m3);
      update public.movimientos_banco m
         set sello = fn_banco_sello(m.cuenta, m.ultimos4, m.fecha, m.fecha_transaccion, m.monto, m.tipo_banco, m.cheque,
                                    m.descripcion, m.memo, m.origen, m.id_externo, m.llave, m.archivo_id, m.fila,
                                    (select a.sha256 from archivos_banco a where a.id = m.archivo_id)),
             descripcion = 'OTRA COSA'
       where m.id = v_m3;
      v_s3 := 'entró';
    exception when others then v_s3 := sqlstate;
    end;
    -- Como lo sella el pegado (el mismo update de 1.11): solo el sello.
    perform fn_banco_marca('sellar:' || v_m3);
    update public.movimientos_banco m
       set sello = fn_banco_sello(m.cuenta, m.ultimos4, m.fecha, m.fecha_transaccion, m.monto, m.tipo_banco, m.cheque,
                                  m.descripcion, m.memo, m.origen, m.id_externo, m.llave, m.archivo_id, m.fila,
                                  (select a.sha256 from archivos_banco a where a.id = m.archivo_id))
     where m.id = v_m3;
    perform fn_banco_marca(null);
    v_s2 := pg_temp.c6_cuadre('cuadre: archivos intactos', current_setting('mx6.mes'), v_m3::text);
    select v.detalle into v_d from fn_banco_verificar(array['1098']) v where v.control = 'archivos, leídos otra vez fila por fila';
    v_obt := format('control=%s verificar=%s filas=%s sin_sello=%s sellado=%s con_cambio=%s',
                    pg_temp.c6_cuadre('cuadre: archivos intactos', current_setting('mx6.mes'), v_m1::text),
                    case when jsonb_array_length(v_d->'no_dan_lo_mismo') > 0 then 'f' else 't' end,
                    (select sum(jsonb_array_length(coalesce(x->'filas', '[]'::jsonb))) from jsonb_array_elements(v_d->'no_dan_lo_mismo') x),
                    v_s1, v_s2, v_s3);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa el banco (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (48, 'un movimiento cambiado o borrado con las guardas apagadas sale en rojo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 49. UNA CONCILIACIÓN CONFIRMADA NO SE ALTERA SIN REABRIRLA: si el ticket
--     de un cargo ya conciliado se anula, «Casar» no des-casa ese cargo
--     (antes volvía a la bandeja con la conciliación confirmada) y el
--     control dice cuál reabrir; y un movimiento que llega tarde con fecha
--     dentro de la confirmada (Plaid) la pone en rojo hasta reabrirla.
do $$
declare
  v_obt text;
  v_esp text := 'confirmada=confirmada sigue=casado:recibo control51=f:reabrir tarde=pendiente control54=f';
  v_c   jsonb;
  v_m   uuid;
  v_p   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (49, 'lo confirmado no cambia sin reabrir: sanar no des-casa; lo que llega tarde, en rojo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A2'),
                                jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas');
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A4'), '[{"cuenta": "7100"}]'::jsonb, null);
    v_c := fn_conciliar('2100-9996', d + 22);
    v_obt := 'confirmada=' || (fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid)->>'estado');
    v_m := pg_temp.c6_mov('2100-9996', 'C6A1');
    perform fn_recibo_anular(-660001, 'c6-pruebas: el ticket estaba mal');
    perform fn_banco_casar_todo('2100-9996');
    -- (el cuadre 51 pedido por su nombre, una vez: antes, además, el control
    -- entero —con un año de banco, medio segundo— para leer lo mismo)
    select v_obt || ' sigue=' || pg_temp.c6_est('2100-9996', 'C6A1') || ' control51='
           || case when position(v_m::text in coalesce(c.detalle, '')) > 0 then 'f' else 't' end
           || case when c.detalle like '%reábrela%' then ':reabrir' else '' end
      into v_obt
      from fn_banco_control(current_setting('mx6.mes'), array['cuadre: un movimiento, un casado']) c
     where c.vista = 'cuadre: un movimiento, un casado';
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '2100-9996', 'filas', jsonb_build_array(
              jsonb_build_object('id', 'c6-plaid-tarde', 'fecha', d + 10, 'plaid_monto', '19.99', 'descripcion', 'C6 LLEGA TARDE'))));
    v_p := pg_temp.c6_mov('2100-9996', 'c6-plaid-tarde');
    v_obt := v_obt || ' tarde=' || (select m.estado from movimientos_banco m where m.id = v_p)
             || ' control54=' || pg_temp.c6_cuadre('cuadre: conciliaciones confirmadas', current_setting('mx6.mes'), v_p::text);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (49, 'lo confirmado no cambia sin reabrir: sanar no des-casa; lo que llega tarde, en rojo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 50. UN DEVENGO NO EXPLICA UN MOVIMIENTO DEL BANCO: la línea de un asiento
--     reversible (el libro lo reversa solo el día 1) no casa con un
--     depósito del mismo monto (antes, el cruce exacto lo casaba y el
--     dinero no entraba nunca al libro), y casar con ella a mano tampoco.
do $$
declare
  v_obt text;
  v_esp text := 'deposito=pendiente a_mano=MX008';
  v_a   jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (50, 'un devengo (asiento reversible) no casa con el banco', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_a := fn_postear(jsonb_build_object('fecha', (d + 5)::text, 'descripcion', 'c6-pruebas: un devengo (se deshace)', 'reversible', true,
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '640.00'),
                                  jsonb_build_object('cuenta', '2050', 'monto', '-640.00'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, 640.00, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 6, 'monto', '640.00', 'id', 'C6V1', 'nombre', 'C6 DEPOSITO'))),
              '1098', 'c6-pruebas-devengo.qfx');
    perform fn_banco_casar_todo('1098');
    begin
      perform fn_banco_casar_con(pg_temp.c6_mov('1098', 'C6V1'), jsonb_build_object('asiento', v_a->>'id'), null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('deposito=%s a_mano=%s', (select m.estado from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6V1')), v_x);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (50, 'un devengo (asiento reversible) no casa con el banco', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 51. EL MISMO MOVIMIENTO CON OTRO ID, O DE OTRO DÍA POR PLAID, espera; y
--     un id reutilizado para OTRO movimiento entra: el banco que cambia el
--     FITID entre dos descargas (misma fecha, monto y descripción) y Plaid
--     con un día de diferencia entran «posible duplicado» (antes, nuevos y
--     sin aviso: el dinero dos veces); el FITID que el banco repite para un
--     movimiento de otra fecha y monto entra como nuevo, con su aviso (antes
--     se daba por repetido y no entraba).
do $$
declare
  v_obt text;
  v_esp text := 'otro_fitid=pendiente:posible_duplicado plaid_otro_dia=pendiente:posible_duplicado reusado=nuevas:1,reusados:1';
  v_x   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (51, 'otro FITID o Plaid de otro día esperan; un FITID reutilizado entra con su aviso', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 7, 100.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-58.10', 'id', 'C6U1', 'nombre', 'C6 TIENDA UNO'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'monto', '-33.00', 'id', 'C6U2', 'nombre', 'C6 TIENDA DOS'))),
              '1098', 'c6-pruebas-semana1.qfx');
    -- La descarga del mes: el mismo movimiento del día 3 con otro FITID.
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 30, 200.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-58.10', 'id', 'C6U1-B', 'nombre', 'C6 TIENDA UNO'))),
              '1098', 'c6-pruebas-mes.qfx');
    -- Plaid, un día después, con otra descripción.
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1098', 'filas', jsonb_build_array(
              jsonb_build_object('id', 'c6-plaid-dos', 'fecha', d + 6, 'plaid_monto', '33.00', 'descripcion', 'TIENDA DOS 123'))));
    -- El FITID C6U2 otra vez, pero para otro movimiento.
    v_x := fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 20, d + 27, 300.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 22, 'monto', '-125.00', 'id', 'C6U2', 'nombre', 'C6 OTRA COSA'))),
              '1098', 'c6-pruebas-reusado.qfx');
    v_obt := format('otro_fitid=%s plaid_otro_dia=%s reusado=nuevas:%s,reusados:%s', pg_temp.c6_est('1098', 'C6U1-B'),
                    pg_temp.c6_est('1098', 'c6-plaid-dos'), v_x->>'filas_nuevas', coalesce(v_x->>'fitid_reusados', '0'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (51, 'otro FITID o Plaid de otro día esperan; un FITID reutilizado entra con su aviso', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 52. EL ESTADO DE CUENTA DE OTRA CUENTA NO ENTRA A ESTA: con 1098
--     recibiendo los archivos de ····1098, uno de ····7777 dicho a 1098
--     para (MX004, y dice cómo confirmarlo); confirmado a sabiendas (un
--     lote con «confirmo_cuenta»), entra. Y un lote de Plaid que dice
--     "cuenta": "1098" (la cuenta del plan) no guarda «1098» como los 4
--     últimos de nada.
do $$
declare
  v_obt text;
  v_esp text := 'otra_cuenta=MX004 confirmada=entra lote_ultimos4=-';
  v_x   text;
  v_y   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (52, 'el archivo de otra cuenta no entra sin confirmarlo; «cuenta» de un lote no son 4 últimos', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 5, 10.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 2, 'monto', '-1.00', 'id', 'C6N1', 'nombre', 'C6 UNO'))),
              '1098', 'c6-pruebas-1098.qfx');
    begin
      perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000007777', d, d + 5, 999.00, jsonb_build_array(
                jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-2.00', 'id', 'C6N2', 'nombre', 'C6 PERSONAL'))),
                '1098', 'c6-pruebas-7777.qfx');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'mano', 'cuenta', '1098', 'ultimos4', '7777', 'confirmo_cuenta', true,
                                                       'nombre', 'c6-pruebas: número nuevo', 'filas', '[]'::jsonb));
    begin
      perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000007777', d, d + 5, 999.00, jsonb_build_array(
                jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-2.00', 'id', 'C6N2', 'nombre', 'C6 PERSONAL'))),
                '1098', 'c6-pruebas-7777.qfx');
      v_y := 'entra';
    exception when others then v_y := sqlstate;
    end;
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1098', 'filas', jsonb_build_array(
              jsonb_build_object('id', 'c6-plaid-u4', 'fecha', d + 4, 'plaid_monto', '3.00', 'descripcion', 'C6 TRES'))));
    v_obt := format('otra_cuenta=%s confirmada=%s lote_ultimos4=%s', v_x, v_y,
                    coalesce((select a.ultimos4 from archivos_banco a where a.formato = 'plaid' and a.cuenta = '1098'
                               order by a.importado_el desc limit 1), '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (52, 'el archivo de otra cuenta no entra sin confirmarlo; «cuenta» de un lote no son 4 últimos', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 53. UN ARCHIVO GRANDE ENTRA: el importador crece con las filas, no con
--     su cuadrado (antes, un QFX de un año, 3,000 movimientos, no cabía
--     nunca en los 8 s de la API). Uno de 1,000 y otro de 3,000 (antes, uno
--     chico de calentamiento; y si no da, otra vez cada uno, con otros
--     montos, y se toma la vez más rápida: un tropiezo del servidor no
--     decide): el grande entra entero y tarda unas tres veces lo que el de
--     1,000 (con el cuadrado serían nueve; el importador de antes daba seis
--     y medio). Se mide la proporción, no los segundos: en Supabase todo
--     tarda más que en el banco de pruebas.
do $$
declare
  v_obt text;
  v_esp text := 'nuevas=1000+3000 lineal=t';
  v_x   jsonb;
  v_n1  text;
  v_n3  text;
  v_t   timestamptz;
  v_t1  numeric := null;
  v_t3  numeric := null;
  v_i   int;
  v_n   int;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (53, 'un archivo de 3,000 movimientos entra entero, y el tiempo crece con las filas', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    -- Cada archivo con sus propios montos (-k.15, -k.25, …): ninguno es
    -- «posible duplicado» de otro, y todos hacen el mismo trabajo.
    for v_i in 0 .. 4 loop
      v_n := case when v_i = 0 then 100 when v_i in (1, 3) then 1000 else 3000 end;
      exit when v_i = 3 and v_t3 < 4.5 * greatest(v_t1, 0.02);
      v_t := clock_timestamp();
      v_x := fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 0.00,
               (select jsonb_agg(jsonb_build_object('tipo', 'DEBIT', 'fecha', d + (g % 28),
                                                    'monto', to_char(-(g % 97 + 1) - 0.15 - v_i * 0.10, 'FM999990.00'),
                                                    'id', 'C6H' || v_i || '-' || g, 'nombre', 'C6 COMPRA ' || v_i || ' ' || g) order by g)
                  from generate_series(1, v_n) g)), '1098', 'c6-pruebas-grande-' || v_i || '.qfx');
      if v_n = 1000 then
        v_t1 := least(coalesce(v_t1, 1e9), extract(epoch from clock_timestamp() - v_t));
        v_n1 := coalesce(v_n1, v_x->>'filas_nuevas');
      elsif v_n = 3000 then
        v_t3 := least(coalesce(v_t3, 1e9), extract(epoch from clock_timestamp() - v_t));
        v_n3 := coalesce(v_n3, v_x->>'filas_nuevas');
      end if;
    end loop;
    v_obt := format('nuevas=%s+%s lineal=%s', v_n1, v_n3,
                    case when v_t3 < 4.5 * greatest(v_t1, 0.02) then 't' else format('f:%s/%s', round(v_t1, 2), round(v_t3, 2)) end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (53, 'un archivo de 3,000 movimientos entra entero, y el tiempo crece con las filas', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 54. LAS PROTECCIONES VEN LO AJENO Y service_role NO LEE EL ESTADO DE
--     CUENTA ENTERO: una vista sin security_invoker sobre el banco (que le
--     da a quien la abra lo que la policy le niega) o una SECURITY DEFINER
--     ejecutable por la API que lee el banco por una función de ayuda
--     ponen «protecciones del banco» en rojo (antes, verde); y service_role
--     lee los archivos por columnas, pero no su texto (el número entero de
--     la cuenta y de la ruta).
do $$
declare
  v_obt text;
  v_esp text := 'vista=f definer=f limpio=t sr_texto=42501 sr_nombre=t';
  v_x   text;
  v_y   text;
  v_a   text;
  v_b   text;
begin
  begin
    execute 'create view public.c6_pruebas_extracto as select m.cuenta, m.fecha, m.monto, m.descripcion from public.movimientos_banco m';
    execute 'grant select on public.c6_pruebas_extracto to authenticated';
    select case when bool_and(c.ok) then 't' else 'f' end into v_x
      from fn_banco_control('hoy', array['v_banco_saldos']) c where c.vista = 'cuadre: protecciones del banco';
    execute 'drop view public.c6_pruebas_extracto';
    execute 'create function public.c6_pruebas_ayuda() returns bigint language sql stable set search_path = public, pg_temp
               as $f$ select count(*) from public.movimientos_banco $f$';
    execute 'create function public.c6_pruebas_puerta() returns bigint language sql stable security definer
               set search_path = public, pg_temp as $f$ select public.c6_pruebas_ayuda() $f$';
    execute 'grant execute on function public.c6_pruebas_puerta() to authenticated';
    select case when bool_and(c.ok) then 't' else 'f' end into v_y
      from fn_banco_control('hoy', array['v_banco_saldos']) c where c.vista = 'cuadre: protecciones del banco';
    execute 'drop function public.c6_pruebas_puerta()';
    execute 'drop function public.c6_pruebas_ayuda()';
    v_obt := format('vista=%s definer=%s limpio=%s', v_x, v_y,
                    (select case when bool_and(c.ok) then 't' else 'f' end
                       from fn_banco_control('hoy', array['v_banco_saldos']) c where c.vista = 'cuadre: protecciones del banco'));
    execute 'set local role service_role';
    begin
      execute 'select count(texto) from public.archivos_banco';
      v_a := 'lee';
    exception when others then v_a := sqlstate;
    end;
    begin
      execute 'select count(nombre) from public.archivos_banco';
      v_b := 't';
    exception when others then v_b := sqlstate;
    end;
    execute 'reset role';
    v_obt := v_obt || format(' sr_texto=%s sr_nombre=%s', v_a, v_b);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (54, 'las protecciones ven vistas y DEFINER ajenas; service_role no lee el texto de los archivos', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 55. UN DEPÓSITO DE DOS CHEQUES YA ANOTADOS casa solo con los dos cobros
--     que lo suman (únicos y a días del depósito): antes salía «sin cobro»,
--     los mensajes llevaban a registrar un anticipo y el mismo dinero
--     entraba dos veces. El primer cobro queda con su movimiento. Y si dos
--     combinaciones pueden sumarlo, no se adivina: se propone.
do $$
declare
  v_obt  text;
  v_esp  text := 'deposito=casado:cobro lineas=2 primero=el_movimiento empate=pendiente:deposito_cobros opciones=2';
  v_c1   jsonb;
  v_obra text := current_setting('mx6.obra', true);
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (55, 'un depósito de varios cobros ya anotados casa con ellos; con empate, se propone', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660551, v_obra, 'C6-551', d + 1, 1250.00, 0), (-660552, v_obra, 'C6-552', d + 1, 2750.00, 0),
           (-660553, v_obra, 'C6-553', d + 1, 1100.00, 0), (-660554, v_obra, 'C6-554', d + 1, 1400.00, 0),
           (-660555, v_obra, 'C6-555', d + 1, 1200.00, 0), (-660556, v_obra, 'C6-556', d + 1, 1300.00, 0);
    v_c1 := fn_cobro_registrar(jsonb_build_object('fecha', (d + 8)::text, 'monto', '1250.00', 'cuenta', '1098', 'medio', 'cheque',
              'referencia', 'C6-551', 'duplicado_confirmado', 'c6-pruebas',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -660551, 'monto', '1250.00'))));
    perform fn_cobro_registrar(jsonb_build_object('fecha', (d + 9)::text, 'monto', '2750.00', 'cuenta', '1098', 'medio', 'cheque',
              'referencia', 'C6-552', 'duplicado_confirmado', 'c6-pruebas',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -660552, 'monto', '2750.00'))));
    -- Dos pares que suman 2,500.00 (1,100 + 1,400 y 1,200 + 1,300): no se adivina.
    perform fn_cobro_registrar(jsonb_build_object('fecha', (d + 15)::text, 'monto', x.m, 'cuenta', '1098', 'medio', 'cheque',
              'referencia', x.r, 'duplicado_confirmado', 'c6-pruebas',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', x.f, 'monto', x.m))))
      from (values ('1100.00', 'C6-553', -660553), ('1400.00', 'C6-554', -660554), ('1200.00', 'C6-555', -660555),
                   ('1300.00', 'C6-556', -660556)) as x(m, r, f);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 6500.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 10, 'monto', '4000.00', 'id', 'C6S1', 'nombre', 'DEPOSIT'),
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 16, 'monto', '2500.00', 'id', 'C6S2', 'nombre', 'DEPOSIT'))),
              '1098', 'c6-pruebas-cheques-juntos.qfx');
    perform fn_banco_casar_todo('1098');
    select format('deposito=%s lineas=%s primero=%s empate=%s opciones=%s', pg_temp.c6_est('1098', 'C6S1'),
                  (select count(*) from banco_casado_lineas l where l.casado_id = m.casado_id and l.vigente),
                  (select case when c.movimiento_id = m.id::text then 'el_movimiento' else coalesce(c.movimiento_id, 'nada') end
                     from cobros c where c.id = (v_c1->>'cobro')::uuid),
                  pg_temp.c6_est('1098', 'C6S2'),
                  (select count(*) from movimientos_banco m2, jsonb_array_elements(m2.propuesta->'opciones') o
                    where m2.id = pg_temp.c6_mov('1098', 'C6S2') and o->>'llamar' = 'fn_banco_casar_con'))
      into v_obt
      from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6S1');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (55, 'un depósito de varios cobros ya anotados casa con ellos; con empate, se propone', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 56. EL CHEQUE POR EL STATEMENT DE UN PROVEEDOR paga primero lo que traía
--     QuickBooks (su deuda sin partida de la apertura) y después sus
--     papeles: un cheque sin nombre por lo que se le debe se propone como
--     su pago (antes: «sin ticket»), y aplicado no deja nada «a favor» ni
--     dice «pagaste de más» (antes el FIFO saltaba lo de QuickBooks).
do $$
declare
  v_obt  text;
  v_esp  text := 'propuesta=pago_proveedor sin_nombre=t qb=1850.00 papel=1100.00 a_favor=0 aviso=quickbooks';
  v_prov uuid;
  v_m    uuid;
  v_r    jsonb;
  v_pos  bigint;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (56, 'el cheque por el statement de un proveedor paga primero lo de QuickBooks', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_prov := (pg_temp.c6_montar()->>'proveedor')::uuid;
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    -- Lo que traía QuickBooks (la apertura: a su nombre, sin partida).
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: lo que se le debía en QuickBooks (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2010', 'monto', '-1850.00', 'tercero_tipo', 'proveedor',
                                                     'tercero_id', v_prov::text),
                                  jsonb_build_object('cuenta', '3900', 'monto', '1850.00'))));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660561, 'total', 1100.00, 'fecha', d + 2, 'metodo_pago', 'cuenta_proveedor'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 14, 100.00, jsonb_build_array(
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 12, 'monto', '-2950.00', 'id', 'C6M1', 'nombre', 'CHECK 1042',
                                 'cheque', '1042'))), '1098', 'c6-pruebas-statement.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6M1');
    select format('propuesta=%s sin_nombre=%s', m.propuesta->>'motivo',
                  case when m.propuesta->>'texto' like '%sin nombre%' then 't' else 'f' end)
      into v_obt from movimientos_banco m where m.id = v_m;
    v_r := fn_banco_pagar_proveedor(v_m, v_prov, null);
    v_obt := v_obt || format(' qb=%s papel=%s a_favor=%s aviso=%s',
               (select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                 where a.cadena_pos > v_pos and a.origen_tabla = 'movimientos_banco' and l.cuenta = '2010' and l.partida_tabla is null),
               (select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                 where a.cadena_pos > v_pos and a.origen_tabla = 'movimientos_banco' and l.cuenta = '2010'
                   and l.partida_tabla = 'recibos'),
               (select count(*) from asiento_lineas l join asientos a on a.id = l.asiento_id
                 where a.cadena_pos > v_pos and a.origen_tabla = 'movimientos_banco' and l.memo like 'A favor%'),
               case when v_r->>'aviso' like '%QuickBooks%' and v_r->>'aviso' not like '%más que%' then 'quickbooks'
                    else coalesce(v_r->>'aviso', '-') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (56, 'el cheque por el statement de un proveedor paga primero lo de QuickBooks', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 57. UNA COMPRA CON LA DÉBITO EN EL MOSTRADOR DE UN PROVEEDOR no es el
--     pago de su cuenta: sin nada que diga pago y sin cuadrar con lo que
--     se le debe, la bandeja la pone como cargo sin ticket (el pago queda
--     como otra opción), y clasificarla a su costo no pide motivo. Antes la
--     única opción era «Pago a …», que saldaba una factura ajena y dejaba
--     la compra sin costo.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=sin_ticket pago_opcion=t clasificar=casado:clasificado';
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (57, 'la compra con la débito en el mostrador de un proveedor no se toma por su pago', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660571, 'total', 750.00, 'fecha', d + 1, 'metodo_pago', 'cuenta_proveedor'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, 100.00, jsonb_build_array(
              jsonb_build_object('tipo', 'POS', 'fecha', d + 5, 'monto', '-87.50', 'id', 'C6O1', 'nombre', 'C6 PRUEBAS SUPPLY #12',
                                 'memo', 'CARD 9420'))), '1098', 'c6-pruebas-mostrador.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6O1');
    select format('bandeja=%s pago_opcion=%s', m.propuesta->>'motivo',
                  case when exists (select 1 from jsonb_array_elements(m.propuesta->'opciones') o
                                     where o->>'llamar' = 'fn_banco_pagar_proveedor') then 't' else 'f' end)
      into v_obt from movimientos_banco m where m.id = v_m;
    perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                null);
    v_obt := v_obt || ' clasificar=' || pg_temp.c6_est('1098', 'C6O1');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (57, 'la compra con la débito en el mostrador de un proveedor no se toma por su pago', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 58. LA NÓMINA DEL PROVEEDOR ANTERIOR (antes de Gusto y de f11): su débito
--     espera su journal y la conciliación lo dice así (no «clasifícalos»);
--     desde el SQL Editor, fn_banco_nomina registra su journal (origen
--     nomina_proveedor: la mano de obra de verdad, 5000 con su obra, y los
--     impuestos patronales a 5015) y lo casa con el débito, y el papel del
--     asiento se encuentra. (Que el control de mano de obra de c3 no lo
--     cuente lo mira la 39, que lleva una nómina así en su escenario, en su
--     pasada de los controles de c3.)
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=nomina falta=nomina journal=casado:asiento papel=t';
  v_c   jsonb;
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (58, 'la nómina del proveedor anterior: su journal con fn_banco_nomina, casado con su débito', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, -4000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 15, 'monto', '-4000.00', 'id', 'C6J1', 'nombre', 'ADP PAYROLL FEES'))),
              '1098', 'c6-pruebas-adp.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6J1');
    v_c := fn_conciliar('1098', d + 20, '-4000.00');
    v_obt := format('bandeja=%s falta=%s', (select m.estado_motivo from movimientos_banco m where m.id = v_m),
                    case when v_c->>'falta' like '%fn_banco_nomina%' then 'nomina' else coalesce(v_c->>'falta', '-') end);
    perform fn_banco_nomina(v_m, jsonb_build_array(
              jsonb_build_object('cuenta', '5000', 'monto', '3500.00', 'proyecto_id', current_setting('mx6.obra'), 'memo', 'Sueldos'),
              jsonb_build_object('cuenta', '5015', 'monto', '500.00', 'memo', 'Impuestos patronales')), 'c6-pruebas: ADP de octubre');
    v_obt := v_obt || format(' journal=%s papel=%s', pg_temp.c6_est('1098', 'C6J1'),
                             (select case when exists (select 1 from v_asiento_papel v
                                                        where v.asiento_id = (select m.asiento_id from movimientos_banco m where m.id = v_m)
                                                          and v.papel is not null) then 't' else 'f' end));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (58, 'la nómina del proveedor anterior: su journal con fn_banco_nomina, casado con su débito', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 59. CASAR NO REHACE LO QUE NO CAMBIÓ: con la bandeja propuesta, otra
--     llamada sin nada nuevo no rehace ninguna propuesta (antes rehacía la
--     de TODO lo pendiente en cada llamada: 2 a 5 s con la bandeja
--     atrasada, con el candado del casado tomado); abrir un movimiento
--     (fn_banco_casar) rehace la suya; un asiento que no le cambia nada a
--     ninguna propuesta (como un ticket de otra cosa: nada casaría con él)
--     no las rehace; y uno que sí (una línea que casaría con un movimiento
--     pendiente) rehace la de ese movimiento.
do $$
declare
  v_obt text;
  v_esp text := 'primera=t segunda=0 abrir=1 ajeno=0 con_cambio=t';
  v_x   jsonb;
  v_y   jsonb;
  v_z   jsonb;
  v_w   jsonb;
  v_a   jsonb;
  v_i   int;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (59, 'casar no rehace las propuestas que no cambiaron', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform fn_banco_importar_ofx(pg_temp.c6_chase(), '1098', 'c6-pruebas-chase.qfx');
    v_x := fn_banco_casar_todo('1098');
    v_y := fn_banco_casar_todo('1098');
    v_z := fn_banco_casar(pg_temp.c6_mov('1098', 'C6C8'));
    perform fn_postear(jsonb_build_object('fecha', current_setting('mx6.desde'), 'descripcion', 'c6-pruebas: algo ajeno (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '1.00'),
                                  jsonb_build_object('cuenta', '6130', 'monto', '-1.00'))));
    v_a := fn_banco_casar_todo('1098');
    -- (dos, para que no case solo: los dos serían del cheque 1043)
    for v_i in 1 .. 2 loop
      perform fn_postear(jsonb_build_object('fecha', (current_setting('mx6.desde')::date + 1)::text,
        'descripcion', 'c6-pruebas: el cheque 1043, a mano (se deshace)',
        'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6130', 'monto', '1200.00'),
                                    jsonb_build_object('cuenta', '1098', 'monto', '-1200.00'))));
    end loop;
    v_w := fn_banco_casar_todo('1098');
    v_obt := format('primera=%s segunda=%s abrir=%s ajeno=%s con_cambio=%s',
                    case when (v_x->>'propuestas')::int > 0 then 't' else 'f:' || coalesce(v_x->>'propuestas', '-') end,
                    v_y->>'propuestas', v_z->'casar'->>'propuestas', v_a->>'propuestas',
                    case when (v_w->>'propuestas')::int > 0 then 't' else 'f:' || coalesce(v_w->>'propuestas', '-') end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (59, 'casar no rehace las propuestas que no cambiaron', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 60. LA REVISIÓN ENTERA NO RECALCULA LO QUE NO CAMBIÓ: con una
--     conciliación confirmada y nada nuevo, fn_banco_verificar no la
--     recalcula (la compara por su huella, en el control); con algo
--     posteado después con fecha dentro de su corte, la recalcula y lo dice
--     en rojo. Antes las recalculaba todas cada vez (8,5 s con 36).
do $$
declare
  v_obt text;
  v_esp text := 'sin_cambios=0 con_cambio=1 rojo=t';
  v_c   jsonb;
  v_d1  jsonb;
  v_d2  jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (60, 'fn_banco_verificar recalcula solo las conciliaciones que pudieron cambiar', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_escenario();
    perform pg_temp.c6_importar_y_casar();
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A2'),
                                jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas');
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6A4'), '[{"cuenta": "7100"}]'::jsonb, null);
    v_c := fn_conciliar('2100-9996', d + 22);
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    select v.detalle into v_d1 from fn_banco_verificar(array['2100-9996']) v where v.control = 'conciliaciones confirmadas, recalculadas';
    perform fn_postear(jsonb_build_object('fecha', (d + 10)::text, 'descripcion', 'c6-pruebas: algo con fecha dentro del corte (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2100-9996', 'monto', '-5.00'),
                                  jsonb_build_object('cuenta', '6130', 'monto', '5.00'))));
    select v.detalle into v_d2 from fn_banco_verificar(array['2100-9996']) v where v.control = 'conciliaciones confirmadas, recalculadas';
    v_obt := format('sin_cambios=%s con_cambio=%s rojo=%s', v_d1->>'recalculadas', v_d2->>'recalculadas',
                    case when jsonb_array_length(v_d2->'no_dan_lo_mismo') > 0 then 't' else 'f' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (60, 'fn_banco_verificar recalcula solo las conciliaciones que pudieron cambiar', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 62. LA BANDEJA ATRASADA NO SE ATASCA: la API corta cada llamada a los
--     8 s y deshace lo que hizo; el motor del casado mira el reloj, para
--     antes con «completo»: false, y la llamada siguiente sigue donde
--     quedó. Con el tope bajado a 0 (el ajuste mx_banco.tope_ms: cada
--     llamada casa uno y para), llamando hasta «completo», sale lo mismo
--     que de una vez: los mismos casados y las mismas propuestas.
do $$
declare
  v_obt    text;
  v_esp    text := 'tramos=t igual=t completo=t';
  v_uno    text;
  v_tramos text;
  v_n      int := 0;
  v_x      jsonb;
  v_c      text;
  v_a      text;
  v_r      text;
  v_cta    text;
begin
  if current_setting('mx6.desde', true) = '' then
    insert into _pruebas values (62, 'la bandeja atrasada no se atasca: en tramos, lo mismo que de una vez', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  -- De una vez.
  begin
    perform pg_temp.c6_escenario();
    -- (Los archivos, antes de ser el dueño: pg_temp es del editor.)
    v_c := pg_temp.c6_chase();
    v_a := pg_temp.c6_amex();
    v_r := pg_temp.c6_reserva();
    perform pg_temp.c6_como('dueno');
    perform fn_banco_importar_ofx(v_c, '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_importar_ofx(v_a, null, 'c6-pruebas-amex.qfx');
    perform fn_banco_importar_ofx(v_r, '1097', 'c6-pruebas-reserva.ofx');
    foreach v_cta in array array['1098', '2100-9996', '1097'] loop
      perform fn_banco_casar_todo(v_cta);
    end loop;
    execute 'reset role';
    select string_agg(m.cuenta || ':' || m.id_externo || '=' || m.estado || ':' || coalesce(m.casado_clase, m.estado_motivo, '-')
                      || ':' || coalesce(m.casado_regla, m.propuesta->>'motivo', '-'), ',' order by m.cuenta, m.id_externo)
      into v_uno
      from movimientos_banco m where m.cuenta in ('1098', '1097', '2100-9996');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_uno := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  -- En tramos: el tope a 0 ms.
  begin
    perform pg_temp.c6_escenario();
    -- (Los archivos, antes de ser el dueño: pg_temp es del editor.)
    v_c := pg_temp.c6_chase();
    v_a := pg_temp.c6_amex();
    v_r := pg_temp.c6_reserva();
    perform pg_temp.c6_como('dueno');
    perform fn_banco_importar_ofx(v_c, '1098', 'c6-pruebas-chase.qfx');
    perform fn_banco_importar_ofx(v_a, null, 'c6-pruebas-amex.qfx');
    perform fn_banco_importar_ofx(v_r, '1097', 'c6-pruebas-reserva.ofx');
    perform set_config('mx_banco.tope_ms', '0', true);
    -- (Cuenta por cuenta de la prueba, como conta.js después de importar: la
    -- bandeja de verdad no entra en el tramo.)
    foreach v_cta in array array['1098', '2100-9996', '1097'] loop
      loop
        v_n := v_n + 1;
        v_x := fn_banco_casar_todo(v_cta);
        exit when coalesce((v_x->>'completo')::boolean, false) or v_n >= 200;
      end loop;
    end loop;
    perform set_config('mx_banco.tope_ms', '', true);
    execute 'reset role';
    select string_agg(m.cuenta || ':' || m.id_externo || '=' || m.estado || ':' || coalesce(m.casado_clase, m.estado_motivo, '-')
                      || ':' || coalesce(m.casado_regla, m.propuesta->>'motivo', '-'), ',' order by m.cuenta, m.id_externo)
      into v_tramos
      from movimientos_banco m where m.cuenta in ('1098', '1097', '2100-9996');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_tramos := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  v_obt := 'tramos=' || case when v_n > 2 then 't' else 'f:' || v_n end
           || ' igual=' || case when v_tramos = v_uno then 't' else 'f: ' || left(coalesce(v_tramos, '-'), 150) end
           || ' completo=' || case when coalesce((v_x->>'completo')::boolean, false) then 't' else 'f' end;
  insert into _pruebas values (62, 'la bandeja atrasada no se atasca: en tramos, lo mismo que de una vez', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 63. LAS PARTIDAS DE LA APERTURA QUE EL BANCO TRAE A SU MANERA: el
--     cheque 1043 que el banco trae sin CHECKNUM (el número solo en NAME,
--     «CHECK 1043») casa solo con su partida; el depósito del 30-sep que
--     trae en DOS depósitos móviles no se clasifica ni se cobra: la bandeja
--     dice que es la partida (partida_apertura, con la opción que los
--     suma), clasificar uno sin motivo es MX008, y casados los dos con ella
--     queda resuelta. Una partida que nunca llega (un depósito que se
--     perdió) no deja confirmar el mes sin su motivo (n_pide_motivo:
--     MX008); con él (fn_conciliacion_partida), se confirma. Antes el
--     cheque salía «sin ticket» y los depósitos «sin factura»: clasificados
--     entraban dos veces y octubre se confirmaba con los libros por encima
--     del banco. (Ronda 4: registrarle un COBRO a uno de los depósitos, o
--     PAGAR otra vez al proveedor el pago del 28-sep en circulación, sin
--     motivo, también es MX008: antes solo lo frenaba clasificar, y el
--     mismo dinero entraba dos veces por fn_banco_cobrar o por
--     fn_banco_pagar_proveedor.)
do $$
declare
  v_obt text;
  v_esp text := 'cheque=casado:apertura bandeja=partida_apertura/partida_apertura suma=t clasificar=MX008 cobrar=MX008 '
                'pagar=MX008 depositos=casado:apertura/casado:apertura resuelta=t pide=1 confirmar=MX008 con_motivo=confirmada';
  v_m3  uuid;
  v_mt  jsonb;
  v_c   jsonb;
  v_m1  uuid;
  v_m2  uuid;
  v_op  jsonb;
  v_x   text;
  v_id  uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or not exists (select 1 from periodos where tipo = 'apertura') then
    insert into _pruebas values (63, 'apertura: el cheque sin CHECKNUM, el depósito que llega en dos y la partida que no llega', v_esp,
                                 'omitida: falta mes abierto o la apertura', null);
    return;
  end if;
  begin
    v_mt := pg_temp.c6_montar();
    perform pg_temp.c6_apertura_minima();
    v_c := fn_conciliacion_apertura('1098', '-1650.00', jsonb_build_array(
             jsonb_build_object('fecha', (d - 3)::text, 'monto', '-1200.00', 'cheque', '1043', 'descripcion', 'c6-pruebas: cheque 1043'),
             jsonb_build_object('fecha', (d - 3)::text, 'monto', '-850.00', 'descripcion', 'c6-pruebas: pago al proveedor del 28-sep'),
             jsonb_build_object('fecha', (d - 1)::text, 'monto', '3200.00', 'descripcion', 'c6-pruebas: el depósito del 30 (dos cheques)'),
             jsonb_build_object('fecha', (d - 1)::text, 'monto', '500.00', 'descripcion', 'c6-pruebas: un depósito que se perdió')));
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 30, -500.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d, 'monto', '-1200.00', 'id', 'C6AP1', 'nombre', 'CHECK 1043'),
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 1, 'monto', '1700.00', 'id', 'C6AP2', 'nombre', 'MOBILE DEPOSIT'),
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 1, 'monto', '1500.00', 'id', 'C6AP3', 'nombre', 'MOBILE DEPOSIT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 9, 'monto', '-850.00', 'id', 'C6AP4', 'nombre', 'BILL PAY C6 PRUEBAS SUPPLY'))),
            '1098', 'c6-pruebas-apertura.qfx');
    perform fn_banco_casar_todo('1098');
    v_m1 := pg_temp.c6_mov('1098', 'C6AP2');
    v_m2 := pg_temp.c6_mov('1098', 'C6AP3');
    select o into v_op
      from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m1 and o->'args'->'p_con' ? 'movimientos'
     limit 1;
    v_obt := format('cheque=%s bandeja=%s/%s suma=%s', pg_temp.c6_est('1098', 'C6AP1'),
                    (select m.estado_motivo from movimientos_banco m where m.id = v_m1),
                    (select m.estado_motivo from movimientos_banco m where m.id = v_m2),
                    case when v_op->'args'->'p_con'->'movimientos' ? v_m2::text then 't' else 'f' end);
    begin
      perform fn_banco_clasificar(v_m1, '[{"cuenta": "3100"}]'::jsonb);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' clasificar=' || v_x;
    -- (ronda 4: ni cobrarlo, ni pagar otra vez al proveedor lo que ya salió)
    begin
      perform fn_banco_cobrar(v_m1, jsonb_build_array(jsonb_build_object('proyecto_id', current_setting('mx6.obra'))), null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' cobrar=' || v_x;
    v_m3 := pg_temp.c6_mov('1098', 'C6AP4');
    begin
      perform fn_banco_pagar_proveedor(v_m3, (v_mt->>'proveedor')::uuid, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' pagar=' || v_x;
    perform fn_banco_casar_con(v_m3, (select o->'args'->'p_con' from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                                       where m.id = v_m3 and o->'args'->'p_con' ? 'partida_apertura' limit 1));
    perform fn_banco_casar_con(v_m1, v_op->'args'->'p_con');
    v_obt := v_obt || format(' depositos=%s/%s resuelta=%s', pg_temp.c6_est('1098', 'C6AP2'),
                             pg_temp.c6_est('1098', 'C6AP3'),
                             case when exists (select 1 from conciliacion_partidas p
                                                where p.monto = 3200.00 and p.resuelta_por_movimiento in (v_m1, v_m2)) then 't' else 'f' end);
    v_c := fn_conciliar('1098', d + 30, null);
    v_id := (v_c->>'conciliacion')::uuid;
    begin
      perform fn_conciliacion_confirmar(v_id);
      v_x := 'confirmada';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || format(' pide=%s confirmar=%s', coalesce(v_c->>'n_pide_motivo', '-'), v_x);
    perform fn_conciliacion_partida((select p.id from conciliacion_partidas p where p.conciliacion_id = v_id and p.monto = 500.00),
                                    'deposito_en_transito', 'c6-pruebas: el banco lo busca y el cliente repone los cheques');
    v_obt := v_obt || ' con_motivo=' || (fn_conciliacion_confirmar(v_id)->>'estado');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (63, 'apertura: el cheque sin CHECKNUM, el depósito que llega en dos y la partida que no llega', v_esp,
                               coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 64. LA PARTIDA DE LA APERTURA NO SE TRAGA EL COBRO DE UN CLIENTE: un
--     depósito en tránsito del 30-sep casa solo con un depósito sin número
--     por su monto SOLO en la primera semana del mes y si nada más lo
--     explica; el Zelle de un cliente del día 20 por el mismo monto que
--     otra partida, con su factura abierta, NO casa solo: se propone la
--     partida junto con la factura, y espera a Edgar. Antes la partida lo
--     tomaba sola (60 días a ciegas): la factura seguía por cobrar y la
--     partida que nunca llegó desaparecía de la conciliación.
do $$
declare
  v_obt text;
  v_esp text := 'semana1=casado:apertura zelle=pendiente:partida_apertura opciones=partida+factura';
  v_c   jsonb;
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or d <> fn_puente_corte() or not exists (select 1 from periodos where tipo = 'apertura') then
    insert into _pruebas values (64, 'apertura: casa sola solo la primera semana y si nada más lo explica; el cobro de un cliente espera',
                                 v_esp, 'omitida: el mes abierto más antiguo no es el primero después del corte, o falta la apertura',
                                 null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_apertura_minima();
    v_c := fn_conciliacion_apertura('1098', '-1773.78', jsonb_build_array(
             jsonb_build_object('fecha', (d - 1)::text, 'monto', '1523.41', 'descripcion', 'c6-pruebas: depósito del 30 (Pérez y Ruiz)'),
             jsonb_build_object('fecha', (d - 1)::text, 'monto', '250.37', 'descripcion', 'c6-pruebas: depósito del 30 (Gómez)')));
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660064, current_setting('mx6.obra'), 'C6-64', d + 11, 1523.41, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 0.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 2, 'monto', '250.37', 'id', 'C6Z1', 'nombre', 'DEPOSIT'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 19, 'monto', '1523.41', 'id', 'C6Z2', 'nombre', 'ZELLE FROM RUIZ AUTO LLC'))),
            '1098', 'c6-pruebas-zelle.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6Z2');
    v_obt := format('semana1=%s zelle=%s opciones=%s+%s', pg_temp.c6_est('1098', 'C6Z1'), pg_temp.c6_est('1098', 'C6Z2'),
                    case when exists (select 1 from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                                       where m.id = v_m and o->>'llamar' = 'fn_banco_casar_con'
                                         and o->'args'->'p_con' ? 'partida_apertura') then 'partida' else '-' end,
                    case when exists (select 1 from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                                       where m.id = v_m and o->>'llamar' = 'fn_banco_cobrar'
                                         and o->'args'->'p_aplicaciones'->0->>'factura_id' = '-660064') then 'factura' else '-' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (64, 'apertura: casa sola solo la primera semana y si nada más lo explica; el cobro de un cliente espera',
                               v_esp, coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 65. «CASAR» NO MUEVE UNA TRANSFERENCIA DENTRO DE UNA CONCILIACIÓN
--     CONFIRMADA: con el banco conciliado y confirmado al día 21, el pago
--     de la tarjeta que sale del banco el 24 (confirmado como
--     transferencia: un lado) y que la tarjeta acredita el 21 —dentro de
--     la confirmada— NO casa solo (rehacer el asiento con esa fecha
--     cambiaría el saldo en libros de la confirmada): se propone diciendo
--     qué reabrir, y casarlo a mano tampoco pasa (MX008). Antes el motor lo
--     rehacía solo y la confirmada quedaba con otro saldo por detrás.
do $$
declare
  v_obt text;
  v_esp text := 'confirmada=confirmada tr=en_transito tarjeta=pendiente:transferencia_otro_lado reabrir=t libros=igual casar=MX008';
  v_c   jsonb;
  v_id  uuid;
  v_m   uuid;
  v_l0  numeric;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (65, 'casar no rehace una transferencia dentro de una conciliación confirmada', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, -15.00, jsonb_build_array(
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 8, 'monto', '-15.00', 'id', 'C6T1', 'nombre', 'MONTHLY SERVICE FEE'))),
            '1098', 'c6-pruebas-t1.qfx');
    perform fn_banco_casar_todo('1098');
    v_c := fn_conciliar('1098', d + 20, null);
    v_id := (v_c->>'conciliacion')::uuid;
    v_obt := 'confirmada=' || (fn_conciliacion_confirmar(v_id)->>'estado');
    v_l0 := (select c.saldo_libros from conciliaciones c where c.id = v_id);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 21, d + 25, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 23, 'monto', '-500.00', 'id', 'C6T2',
                                 'nombre', 'AMERICAN EXPRESS ACH PMT M9003'))),
            '1098', 'c6-pruebas-t2.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || ' tr=' || (fn_banco_transferencia(pg_temp.c6_mov('1098', 'C6T2'), '2100-9996')->>'estado');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d + 10, d + 26, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 20, 'monto', '500.00', 'id', 'C6T3',
                                 'nombre', 'ONLINE PAYMENT - THANK YOU'))),
            null, 'c6-pruebas-t3.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6T3');
    begin
      perform fn_banco_casar_con(v_m, (select m.propuesta->'opciones'->0->'args'->'p_con' from movimientos_banco m where m.id = v_m));
      v_x := 'casó';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || format(' tarjeta=%s reabrir=%s libros=%s casar=%s', pg_temp.c6_est('2100-9996', 'C6T3'),
                             case when (select m.propuesta->>'texto' from movimientos_banco m where m.id = v_m) like '%reábrela%'
                                  then 't' else 'f' end,
                             case when fn_banco_saldo_libros('1098', d + 20) = v_l0 then 'igual' else 'cambió' end, v_x);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (65, 'casar no rehace una transferencia dentro de una conciliación confirmada', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 66. UN ABONO EN LA TARJETA NO ES UN PAGO SI NO LO DICE, Y «AUTOPAY» NO
--     ES EL EMISOR: la luz en AUTOPAY del banco y una devolución de Lowe's
--     del mismo monto en la tarjeta NO casan solas como el pago de la
--     tarjeta (R3); la luz sale «sin ticket» y las devoluciones como abono
--     de la tarjeta, con la cuenta y la obra del ticket de ese comercio
--     (5100); y confirmar una devolución como transferencia sin motivo es
--     MX008 (dejaría al banco con un cargo en circulación que no llegará
--     nunca). Antes la luz casaba sola con la devolución, y la bandeja solo
--     ofrecía transferencias.
do $$
declare
  v_obt text;
  v_esp text := 'luz=pendiente:sin_ticket lowes=pendiente:abono_tarjeta hd=pendiente:abono_tarjeta devolucion=5100 '
                'transferencia=MX008';
  v_m   uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (66, 'un abono de tarjeta sin «pago» es una devolución; AUTOPAY no casa como pago de la tarjeta', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660661, 'total', 64.20, 'fecha', d + 2, 'proveedor', 'THE HOME DEPOT',
                                                 'num_recibo', 'C6-HD-66'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 10, 'monto', '-100.00', 'id', 'C6U1', 'nombre', 'FPL DIRECT DEBIT AUTOPAY'))),
            '1098', 'c6-pruebas-u1.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-64.20', 'id', 'C6U2', 'nombre', 'THE HOME DEPOT #6311'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 12, 'monto', '100.00', 'id', 'C6U3', 'nombre', 'LOWES #1234 TAMPA FL',
                                 'memo', 'RETURN'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 14, 'monto', '45.00', 'id', 'C6U4', 'nombre', 'THE HOME DEPOT 6345'))),
            null, 'c6-pruebas-u2.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6U4');
    begin
      perform fn_banco_transferencia(v_m, '1098');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('luz=%s lowes=%s hd=%s devolucion=%s transferencia=%s', pg_temp.c6_est('1098', 'C6U1'),
                    pg_temp.c6_est('2100-9996', 'C6U3'), pg_temp.c6_est('2100-9996', 'C6U4'),
                    coalesce((select string_agg(distinct o->'args'->'p_lineas'->0->>'cuenta', ',')
                                from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                               where m.id = v_m and o->>'llamar' = 'fn_banco_clasificar'), '-'),
                    v_x);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (66, 'un abono de tarjeta sin «pago» es una devolución; AUTOPAY no casa como pago de la tarjeta', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 67. EL SALDO ESCRITO QUE NO ES EL DEL BANCO NO CUADRA EL MES: con el
--     archivo del banco diciendo su saldo a esa fecha, un saldo escrito
--     que lo contradice (el de libros, tras ignorar un cargo) deja la
--     diferencia en cero pero pide su motivo y su documento
--     (n_pide_motivo): sin ellos no se confirma (MX008); con ellos
--     (fn_conciliacion_saldo, desde el SQL Editor) sí. Y una confirmada
--     así SIN su motivo sale en rojo en el control. Antes se confirmaba con
--     el número tecleado y un aviso que nadie leía.
do $$
declare
  v_obt text;
  v_esp text := 'archivo=89.99 escrito=0.00 pide=1 confirmar=MX008 con_motivo=confirmada control=t sin_motivo=f';
  v_c   jsonb;
  v_id  uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (67, 'un saldo escrito que contradice al archivo del banco no se confirma sin motivo y documento', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, -104.99, jsonb_build_array(
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 8, 'monto', '-15.00', 'id', 'C6S1', 'nombre', 'MONTHLY SERVICE FEE'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 19, 'monto', '-89.99', 'id', 'C6S2', 'nombre', 'AMAZON MKTPLACE PMTS'))),
            '1098', 'c6-pruebas-saldo.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_ignorar(pg_temp.c6_mov('1098', 'C6S2'), 'c6-pruebas: no es de la empresa');
    v_c := fn_conciliar('1098', d + 27, null);
    v_obt := 'archivo=' || (v_c->>'diferencia');
    v_c := fn_conciliar('1098', d + 27, '-15.00');
    v_id := (v_c->>'conciliacion')::uuid;
    v_obt := v_obt || format(' escrito=%s pide=%s', v_c->>'diferencia', coalesce(v_c->>'n_pide_motivo', '-'));
    begin
      perform fn_conciliacion_confirmar(v_id);
      v_x := 'confirmada';
    exception when others then v_x := sqlstate;
    end;
    -- (el motivo y el documento, desde el SQL Editor)
    perform fn_conciliacion_saldo(v_id, 'c6-pruebas: el QFX se bajó a media mañana; el statement cierra con el cargo de la tarde',
                                  'docs/c6-pruebas/statement.pdf');
    v_obt := v_obt || format(' confirmar=%s con_motivo=%s', v_x, fn_conciliacion_confirmar(v_id)->>'estado');
    v_obt := v_obt || ' control=' || pg_temp.c6_cuadre('cuadre: conciliaciones confirmadas', current_setting('mx6.mes'),
                                                       format('1098 al %s', d + 27));
    -- Una confirmada así pero SIN su motivo (lo que pasaría con las guardas
    -- apagadas): el control la dice.
    alter table public.conciliaciones disable trigger user;
    update public.conciliaciones set saldo_motivo = null where id = v_id;
    alter table public.conciliaciones enable trigger user;
    v_obt := v_obt || ' sin_motivo=' || pg_temp.c6_cuadre('cuadre: conciliaciones confirmadas', current_setting('mx6.mes'),
                                                          format('1098 al %s', d + 27));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa el banco (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (67, 'un saldo escrito que contradice al archivo del banco no se confirma sin motivo y documento', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 68. LA CUOTA BAJA LA CUENTA DEL PRÉSTAMO QUE TIENE EL SALDO: con el
--     préstamo entero en el largo plazo (como lo trae la apertura desde la
--     balanza de QuickBooks: una fila, una cuenta), el capital de la cuota
--     baja el largo plazo, no la porción corriente vacía; y una cuenta de
--     préstamos con saldo DEUDOR sale en rojo en el control. Antes el
--     capital bajaba siempre la corriente: quedaba deudora (c4 la enseñaba
--     como un activo) y el largo plazo sin bajar, con el control en verde.
--     (La tasa se escribe como en el statement: «6.99%».)
do $$
declare
  v_obt text;
  v_esp text := 'tasa=6.9900 cuota=1098:-1029.42|2599:869.85|7100:159.57 corriente=0 control=t deudor=f';
  v_p   uuid;
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (68, 'la cuota baja la cuenta del préstamo que tiene el saldo; una deudora sale en rojo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('2598', 'c6-pruebas: préstamo, porción corriente', 'c6 test loan current', 'pasivo', 'haber', true, 'prohibida', 'prohibida'),
           ('2599', 'c6-pruebas: préstamo, largo plazo', 'c6 test loan long term', 'pasivo', 'haber', true, 'prohibida', 'prohibida');
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: el préstamo en el largo plazo (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1097', 'monto', '27394.54'),
                                  jsonb_build_object('cuenta', '2599', 'monto', '-27394.54'))));
    v_p := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS FORD', 'descripcion', 'F-150 de prueba',
             'principal', '52000.00', 'tasa_anual', '6.99%', 'cuota', '1029.42', 'primer_pago', '2024-03-15', 'dia_pago', 15,
             'plazo_meses', 60, 'saldo_inicial', '27394.54', 'saldo_inicial_al', (d - 1)::text, 'cuenta', '2598',
             'cuenta_largo', '2599', 'cuenta_banco', '1098', 'descriptor', 'C6 PRUEBAS FORD'))->>'id')::uuid;
    v_obt := 'tasa=' || (select p.tasa_anual from prestamos p where p.id = v_p);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 14, 'monto', '-1029.42', 'id', 'C6P1', 'nombre', 'C6 PRUEBAS FORD PAYMENT'))),
            '1098', 'c6-pruebas-p1.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6P1');
    perform fn_prestamo_cuota(v_p, v_m);
    v_obt := v_obt || ' cuota=' || (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.cuenta)
                                      from asiento_lineas l join movimientos_banco m on m.asiento_id = l.asiento_id where m.id = v_m)
             || ' corriente=' || (select count(*) from asiento_lineas l where l.cuenta = '2598')
             || ' control=' || pg_temp.c6_cuadre('cuadre: préstamos', current_setting('mx6.mes'), 'la cuenta 2598');
    -- Una cuenta de préstamos deudora (un capital que bajó la que no tenía el saldo): en rojo.
    perform fn_postear(jsonb_build_object('fecha', (d + 15)::text, 'descripcion', 'c6-pruebas: capital a la cuenta vacía (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2598', 'monto', '100.00'),
                                  jsonb_build_object('cuenta', '1097', 'monto', '-100.00'))));
    v_obt := v_obt || ' deudor=' || pg_temp.c6_cuadre('cuadre: préstamos', current_setting('mx6.mes'), 'la cuenta 2598');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (68, 'la cuota baja la cuenta del préstamo que tiene el saldo; una deudora sale en rojo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 69. UN ABONO EXTRA A CAPITAL NO VA POR LA FÓRMULA: cinco días después de
--     la cuota del mes (que sí va por ella: 159.57 de interés), un pago de
--     5,000 solo a capital se propone como tal (pide el statement, con la
--     opción «todo a capital»), por la fórmula no entra (MX008: le
--     cobraría otro mes entero de interés) y con la opción entra entero a
--     capital: lo que se debe queda como lo dice el prestamista. Antes la
--     fórmula le cargaba 154.51 de interés y el saldo quedaba por encima.
do $$
declare
  v_obt text;
  v_esp text := 'interes1=159.57 propuesta=t:5000.00/0.00 formula=MX008 abono=5000.00/0.00 saldo=21524.69';
  v_p   uuid;
  v_m   uuid;
  v_op  jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (69, 'un abono extra a capital no va por la fórmula: pide el statement', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('2598', 'c6-pruebas: préstamo, porción corriente', 'c6 test loan current', 'pasivo', 'haber', true, 'prohibida', 'prohibida'),
           ('2599', 'c6-pruebas: préstamo, largo plazo', 'c6 test loan long term', 'pasivo', 'haber', true, 'prohibida', 'prohibida');
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: el préstamo (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1097', 'monto', '27394.54'),
                                  jsonb_build_object('cuenta', '2599', 'monto', '-27394.54'))));
    v_p := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS FORD', 'principal', '52000.00', 'tasa_anual', '6.99',
             'cuota', '1029.42', 'primer_pago', '2024-03-15', 'dia_pago', 15, 'plazo_meses', 60, 'saldo_inicial', '27394.54',
             'saldo_inicial_al', (d - 1)::text, 'cuenta', '2598', 'cuenta_largo', '2599', 'cuenta_banco', '1098',
             'descriptor', 'C6 PRUEBAS FORD'))->>'id')::uuid;
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 14, 'monto', '-1029.42', 'id', 'C6Q1', 'nombre', 'C6 PRUEBAS FORD PAYMENT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 19, 'monto', '-5000.00', 'id', 'C6Q2',
                                 'nombre', 'C6 PRUEBAS FORD PRINCIPAL ONLY PMT'))),
            '1098', 'c6-pruebas-q.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := 'interes1=' || (fn_prestamo_cuota(v_p, pg_temp.c6_mov('1098', 'C6Q1'))->>'interes');
    v_m := pg_temp.c6_mov('1098', 'C6Q2');
    perform fn_banco_casar(v_m);
    select o into v_op from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m and o->>'llamar' = 'fn_prestamo_cuota' and o->'args' ? 'p_capital' limit 1;
    v_obt := v_obt || format(' propuesta=%s:%s/%s',
                             coalesce((select (m.propuesta->'particion'->>'pide_statement') from movimientos_banco m where m.id = v_m), 'f')
                               ::boolean::text,
                             v_op->'args'->>'p_capital', v_op->'args'->>'p_interes');
    v_obt := replace(v_obt, 'propuesta=true', 'propuesta=t');
    begin
      perform fn_prestamo_cuota(v_p, v_m);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform fn_prestamo_cuota(v_p, v_m, null, null, v_op->'args'->>'p_capital', v_op->'args'->>'p_interes');
    v_obt := v_obt || format(' formula=%s abono=%s saldo=%s', v_x,
                             (select q.capital || '/' || q.interes from prestamo_cuotas q where q.movimiento_id = v_m),
                             (select x.saldo from v_prestamos x where x.prestamo_id = v_p));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (69, 'un abono extra a capital no va por la fórmula: pide el statement', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 70. LO QUE EDGAR COPIA DEL STATEMENT SE LEE, Y LO QUE NO SE ENTIENDE SE
--     DICE EN ESPAÑOL: la tasa con coma decimal («6,99») entra como 6.99;
--     un día de pago «22nd», un saldo inicial mayor que el principal, un
--     estado «activo» y un prepagado de tipo «insurance» responden 22023
--     diciendo qué se espera. Antes eran errores de Postgres en inglés, o
--     el check de la tabla con la fila entera.
do $$
declare
  v_obt text := '';
  v_esp text := 'coma=6.9900 dia=22023:es saldo=22023:es estado=22023:es tipo=22023:es';
  v_base jsonb;
  v_x    text;
  v_caso record;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (70, 'préstamos y prepagados: lo copiado del statement se lee; lo que no, se dice en español', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_base := jsonb_build_object('prestamista', 'C6 PRUEBAS TRUIST', 'descripcion', 'F-250 de prueba', 'principal', '48,000.00',
                                 'tasa_anual', '6,99', 'cuota', '950.00', 'primer_pago', (d + 21)::text, 'saldo_inicial', '41,250.00',
                                 'saldo_inicial_al', (d - 1)::text, 'plazo_meses', '60', 'cuenta_banco', '1098');
    v_obt := 'coma=' || (fn_prestamo_guardar(v_base)->>'tasa_anual');
    for v_caso in select * from (values
        ('dia', v_base || '{"dia_pago": "22nd"}'::jsonb, 'p'),
        ('saldo', v_base || '{"principal": "41,250.00", "saldo_inicial": "48,000.00"}'::jsonb, 'p'),
        ('estado', v_base || '{"estado": "activo"}'::jsonb, 'p'),
        ('tipo', jsonb_build_object('descripcion', 'c6-pruebas GL', 'tipo', 'insurance', 'cuenta_gasto', '6200', 'monto', '4800.00',
                                    'desde', d::text, 'hasta', (d + 364)::text), 'x')) as c(nombre, dato, que) loop
      begin
        if v_caso.que = 'p' then
          perform fn_prestamo_guardar(v_caso.dato);
        else
          perform fn_prepagado_guardar(v_caso.dato);
        end if;
        v_x := 'entró';
      exception when others then
        v_x := sqlstate || case when sqlerrm ~ '(invalid input|violates|Failing row)' then ':crudo' else ':es' end;
      end;
      v_obt := v_obt || format(' %s=%s', v_caso.nombre, v_x);
    end loop;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (70, 'préstamos y prepagados: lo copiado del statement se lee; lo que no, se dice en español', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 71. VOLVER A PEGAR c6 NO BENDICE UN es_dueno() CAMBIADO: con es_dueno()
--     cambiado, su huella «candado» (la que mira el control permisos de
--     c2) ya no es la sellada; resellar las huellas del libro como lo hace
--     el final de c6-banco.sql (fn_libro_huellas_sellar('c6-banco.sql'))
--     la deja como estaba, y el control sigue en rojo; solo el pegado de
--     c2 la fija. (Y c6-banco.sql empieza mirándola: con un es_dueno()
--     cambiado no se pega, MX000.) Antes se resellaba como bueno, el
--     control volvía a verde y el equipo podía leer el banco entero. (Se
--     mira la huella del candado, lo mismo que mira el control permisos,
--     sin correr los diez controles del libro: con un libro grande, segundos.)
do $$
declare
  v_obt text;
  v_esp text := 'cambiado=f resellado_c6=f resellado_c2=t';
  v_src text;
begin
  begin
    set local lock_timeout = '2s';
    v_src := pg_get_functiondef('public.es_dueno()'::regprocedure);
    -- (un cambio que no cambia lo que hace: basta con que su texto no sea
    -- el que se selló)
    execute regexp_replace(v_src, '\$function\$', '$function$' || chr(10) || '  -- c6-pruebas: cambiado' || chr(10));
    v_obt := 'cambiado=' || pg_temp.c6_candado_igual();
    perform fn_libro_huellas_sellar('c6-banco.sql');
    v_obt := v_obt || ' resellado_c6=' || pg_temp.c6_candado_igual();
    perform fn_libro_huellas_sellar('c2-libro.sql');
    v_obt := v_obt || ' resellado_c2=' || pg_temp.c6_candado_igual();
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa es_dueno() (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (71, 'resellar desde c6 no bendice un es_dueno() cambiado; solo el pegado de c2', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 72. LAS PROTECCIONES VEN UN TRIGGER AJENO QUE LEE EL BANCO: una función
--     SECURITY DEFINER ajena que lee las tablas del banco, enganchada a un
--     trigger de una tabla donde la API escribe (horas), pone «protecciones
--     del banco» en rojo aunque la API no pueda ejecutarla (la dispara el
--     insert del equipo, con los permisos de su dueño); sin el trigger, ya
--     no. Antes las funciones de trigger no se miraban: podía copiar el
--     banco a una columna que el equipo lee, con el control en verde.
do $$
declare
  v_obt text;
  v_esp text := 'con_trigger=f sin_trigger=t';
begin
  if to_regclass('public.horas') is null then
    insert into _pruebas values (72, 'las protecciones ven un trigger ajeno SECURITY DEFINER que lee el banco', v_esp,
                                 'omitida: no hay tabla horas', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    execute 'create function public.c6_pruebas_espia() returns trigger language plpgsql security definer
               set search_path = public, pg_temp
               as $f$ begin new.notas := coalesce(new.notas, '''') || (select count(*)::text from public.movimientos_banco);
                             return new; end $f$';
    execute 'revoke execute on function public.c6_pruebas_espia() from public, anon, authenticated, service_role';
    execute 'create trigger c6_pruebas_espia before insert on public.horas for each row execute function public.c6_pruebas_espia()';
    v_obt := 'con_trigger=' || (select case when position('c6_pruebas_espia' in coalesce(c.detalle, '')) > 0 then 'f' else 't' end
                                  from fn_banco_control('hoy', array['v_banco_saldos']) c
                                 where c.vista = 'cuadre: protecciones del banco');
    execute 'drop trigger c6_pruebas_espia on public.horas';
    v_obt := v_obt || ' sin_trigger=' || (select case when position('c6_pruebas_espia' in coalesce(c.detalle, '')) > 0 then 'f' else 't' end
                                            from fn_banco_control('hoy', array['v_banco_saldos']) c
                                           where c.vista = 'cuadre: protecciones del banco');
    execute 'drop function public.c6_pruebas_espia()';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa horas (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (72, 'las protecciones ven un trigger ajeno SECURITY DEFINER que lee el banco', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 73. EL ESTADO DE CUENTA BORRADO ENTERO (con las guardas apagadas un
--     instante: el archivo, sus movimientos, sus casados) no pasa en
--     silencio: el asiento que el banco había puesto (el interés de la
--     reserva, a 4910) queda sin su papel y lo dicen el control («archivos
--     intactos») y la revisión entera («asientos del banco con su papel»,
--     y el archivo que el historial dice que entró). Antes la relectura
--     solo miraba los archivos que seguían ahí y todo daba verde.
do $$
declare
  v_obt text;
  v_esp text := 'control=f papel=f archivo=f';
  v_mov uuid;
  v_arch uuid;
  v_num text;
  v_v   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (73, 'un estado de cuenta borrado entero deja su asiento sin papel y sale en rojo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 27, 12.42, jsonb_build_array(
              jsonb_build_object('tipo', 'INT', 'fecha', d + 27, 'monto', '12.42', 'id', 'C6BO1', 'nombre', 'INTEREST PAYMENT'))),
            '1097', 'c6-pruebas-borrado.ofx');
    perform fn_banco_casar_todo('1097');
    v_mov := pg_temp.c6_mov('1097', 'C6BO1');
    select m.archivo_id, a.numero into v_arch, v_num from movimientos_banco m join asientos a on a.id = m.asiento_id where m.id = v_mov;
    alter table public.banco_casado_lineas disable trigger user;
    alter table public.banco_casados disable trigger user;
    alter table public.movimientos_banco_ids disable trigger user;
    alter table public.movimientos_banco disable trigger user;
    alter table public.archivos_banco disable trigger user;
    delete from public.banco_casado_lineas l using public.banco_casados c where l.casado_id = c.id and c.movimiento_id = v_mov;
    delete from public.banco_casados c where c.movimiento_id = v_mov;
    delete from public.movimientos_banco_ids i where i.movimiento_id = v_mov;
    delete from public.movimientos_banco m where m.id = v_mov;
    delete from public.archivos_banco a where a.id = v_arch;
    alter table public.banco_casado_lineas enable trigger user;
    alter table public.banco_casados enable trigger user;
    alter table public.movimientos_banco_ids enable trigger user;
    alter table public.movimientos_banco enable trigger user;
    alter table public.archivos_banco enable trigger user;
    select jsonb_object_agg(v.control, v.ok) into v_v from fn_banco_verificar(array['1097']) v;
    v_obt := format('control=%s papel=%s archivo=%s', pg_temp.c6_cuadre('cuadre: archivos intactos', current_setting('mx6.mes'), v_num),
                    case when (v_v->>'asientos del banco con su papel')::boolean then 't' else 'f' end,
                    case when (v_v->>'archivos, leídos otra vez fila por fila')::boolean then 't' else 'f' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa el banco (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (73, 'un estado de cuenta borrado entero deja su asiento sin papel y sale en rojo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 74. UN CHEQUE DE CLIENTE DEVUELTO (NSF) NO ES UN CARGO DEL BANCO: el
--     depósito cobrado contra su factura vuelve devuelto («DEPOSITED ITEM
--     RETURNED NSF»): la bandeja propone devolver ESE cobro (y la factura
--     vuelve a quedar por cobrar), no 6130; y su comisión («RETURNED ITEM
--     FEE», tipo FEE) sí es un cargo del banco y va sola a 6130. Antes el
--     cheque salía «Cargo del banco · 6130» (la factura quedaba cobrada y
--     9,000 de gasto) y la comisión como devolución sin botones.
do $$
declare
  v_obt text;
  v_esp text := 'nsf=pendiente:devolucion opcion=t comision=casado:regla devuelto=casado:devolucion por_cobrar=9000.27';
  v_m   uuid;
  v_x   uuid;
  v_cobro uuid;
  v_op  jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (74, 'un cheque devuelto (NSF) propone devolver su cobro; su comisión va a 6130', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660074, current_setting('mx6.obra'), 'C6-74', d + 1, 9000.27, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 8, 'monto', '9000.27', 'id', 'C6NSF1', 'nombre', 'REMOTE ONLINE DEPOSIT 1'))),
            '1098', 'c6-pruebas-nsf1.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_cobrar(pg_temp.c6_mov('1098', 'C6NSF1'), '[{"factura_id": -660074, "monto": "9000.27"}]'::jsonb);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 10, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 15, 'monto', '-9000.27', 'id', 'C6NSF2', 'nombre', 'DEPOSITED ITEM RETURNED NSF'),
              jsonb_build_object('tipo', 'FEE', 'fecha', d + 15, 'monto', '-12.00', 'id', 'C6NSF3', 'nombre', 'RETURNED ITEM FEE'))),
            '1098', 'c6-pruebas-nsf2.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6NSF2');
    v_x := pg_temp.c6_mov('1098', 'C6NSF1');
    v_cobro := (select c.id from cobros c where c.movimiento_id = v_x::text);
    select o into v_op from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m and o->>'llamar' = 'fn_banco_devolver' and o->'args'->>'p_cobro' = v_cobro::text
     limit 1;
    v_obt := format('nsf=%s opcion=%s comision=%s', pg_temp.c6_est('1098', 'C6NSF2'), case when v_op is not null then 't' else 'f' end,
                    pg_temp.c6_est('1098', 'C6NSF3'));
    perform fn_banco_devolver(v_m, (v_op->'args'->>'p_cobro')::uuid, v_op->'args'->>'p_motivo');
    v_obt := v_obt || format(' devuelto=%s por_cobrar=%s', pg_temp.c6_est('1098', 'C6NSF2'),
                             (select sum(l.monto) from asiento_lineas l
                               where l.partida_tabla = 'facturas' and l.partida_id = '-660074' and l.cuenta = fn_puente_cuenta_de('cxc')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (74, 'un cheque devuelto (NSF) propone devolver su cobro; su comisión va a 6130', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 75. LA RETENCIÓN LIBERADA Y EL PAGO PARCIAL TIENEN SU BOTÓN: cobrado el
--     90 % de una factura con retención, el depósito que libera la
--     retención propone «su retención» (y con él la retención queda en
--     0.00), y un pago de una parte de otra factura propone «parte de la
--     factura» (y quedan por cobrar 8,004.00). Antes los dos salían «sin
--     una factura abierta que lo explique», sin botones, y el texto llevaba
--     al anticipo: la retención se quedaba en 1120 para siempre.
do $$
declare
  v_obt text;
  v_esp text := 'retencion=t parcial=t ret_1120=0.00 parcial_1110=8004.00';
  v_mr  uuid;
  v_mp  uuid;
  v_or  jsonb;
  v_opp jsonb;
  v_w   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (75, 'la retención liberada y el pago parcial se proponen contra su factura', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660751, current_setting('mx6.obra'), 'C6-751', d + 1, 10030.00, 1003.00),
           (-660752, current_setting('mx6.obra'), 'C6-752', d + 4, 12011.00, 0);
    -- (el Zelle nombra la obra, como un cliente de verdad: sus facturas van primero)
    select w.w into v_w
      from proyectos p cross join regexp_split_to_table(fn_banco_norm(concat_ws(' ', p.nombre, p.cliente)), ' ') as w(w)
     where p.id = current_setting('mx6.obra') and length(w.w) >= 4
     limit 1;
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 8, 'monto', '9027.00', 'id', 'C6V1', 'nombre', 'REMOTE ONLINE DEPOSIT 3'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 19, 'monto', '4007.00', 'id', 'C6V2',
                                 'nombre', 'ZELLE PAYMENT FROM ' || coalesce(v_w, 'CLIENTE')),
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 26, 'monto', '1003.00', 'id', 'C6V3', 'nombre', 'REMOTE ONLINE DEPOSIT 4'))),
            '1098', 'c6-pruebas-retencion.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_cobrar(pg_temp.c6_mov('1098', 'C6V1'), '[{"factura_id": -660751, "monto": "9027.00"}]'::jsonb);
    perform fn_banco_casar_todo('1098');
    v_mr := pg_temp.c6_mov('1098', 'C6V3');
    v_mp := pg_temp.c6_mov('1098', 'C6V2');
    select o into v_or from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_mr and o->>'llamar' = 'fn_banco_cobrar' and o->'args'->'p_aplicaciones'->0->>'factura_id' = '-660751'
       and (o->'args'->'p_aplicaciones'->0->>'es_retencion')::boolean
     limit 1;
    select o into v_opp from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_mp and o->>'llamar' = 'fn_banco_cobrar' and o->'args'->'p_aplicaciones'->0->>'factura_id' = '-660752'
     limit 1;
    v_obt := format('retencion=%s parcial=%s', case when v_or is not null then 't' else 'f' end,
                    case when v_opp is not null then 't' else 'f' end);
    perform fn_banco_cobrar(v_mr, v_or->'args'->'p_aplicaciones');
    perform fn_banco_cobrar(v_mp, v_opp->'args'->'p_aplicaciones');
    v_obt := v_obt || format(' ret_1120=%s parcial_1110=%s',
                             (select sum(l.monto) from asiento_lineas l
                               where l.partida_tabla = 'facturas' and l.partida_id = '-660751'
                                 and l.cuenta = fn_puente_cuenta_de('retencion_cxc')),
                             (select sum(l.monto) from asiento_lineas l
                               where l.partida_tabla = 'facturas' and l.partida_id = '-660752' and l.cuenta = fn_puente_cuenta_de('cxc')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (75, 'la retención liberada y el pago parcial se proponen contra su factura', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 76. UN CHEQUE SIN NOMBRE QUE ABONA A UN PROVEEDOR NO VA AL COSTO OTRA
--     VEZ: con dos tickets a cuenta del proveedor (2,225.60), un cheque
--     de 1,000.13 que no cuadra con ninguna partida se propone como abono
--     a lo que se le debe; clasificarlo a material sin motivo es MX008, y
--     con el abono la deuda baja a 1,225.47. Antes salía «sin ticket», sin
--     botones: clasificado, el material contaba dos veces y la deuda
--     seguía entera.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=pago_proveedor abono=t clasificar=MX008 debe=1225.47';
  v_prov uuid;
  v_m   uuid;
  v_op  jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (76, 'un cheque sin nombre que no cuadra se propone como abono al proveedor, no al costo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_prov := (pg_temp.c6_montar()->>'proveedor')::uuid;
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660761, 'total', 1245.60, 'fecha', d + 6, 'metodo_pago', 'cuenta_proveedor'));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660762, 'total', 980.00, 'fecha', d + 13, 'metodo_pago', 'cuenta_proveedor'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 22, 'monto', '-1000.13', 'id', 'C6W1', 'nombre', 'CHECK 1044',
                                 'cheque', '1044'))),
            '1098', 'c6-pruebas-abono.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6W1');
    select o into v_op from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m and o->>'llamar' = 'fn_banco_pagar_proveedor' and o->'args'->>'p_proveedor' = v_prov::text
     limit 1;
    begin
      perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('bandeja=%s abono=%s clasificar=%s', (select m.estado_motivo from movimientos_banco m where m.id = v_m),
                    case when v_op is not null then 't' else 'f' end, v_x);
    perform fn_banco_pagar_proveedor(v_m, (v_op->'args'->>'p_proveedor')::uuid);
    v_obt := v_obt || ' debe=' || (select -sum(l.monto) from asiento_lineas l
                                    where l.cuenta = fn_puente_cuenta_de('cxp') and l.tercero_tipo = 'proveedor'
                                      and l.tercero_id = v_prov::text);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (76, 'un cheque sin nombre que no cuadra se propone como abono al proveedor, no al costo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 77. LA NÓMINA SOLO DEL OFICIAL (el sueldo de Edgar, sin mano de obra)
--     entra por su journal: 6005 el bruto, 2220 lo retenido y el neto del
--     banco (fn_banco_nomina, desde el SQL Editor), casado con su débito;
--     y 6005 no se clasifica desde el banco (es sueldo: MX008). Antes el
--     journal se rechazaba por no llevar mano de obra, el mensaje mandaba a
--     clasificar y clasificar no admite la retención: solo entraba el neto.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=nomina clasificar_6005=MX008 journal=casado:asiento lineas=1098:-3950.13|2220:-1050.00|6005:5000.13';
  v_m   uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (77, 'la nómina solo del oficial entra por su journal (6005 y su retención); 6005 no se clasifica', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 14, 'monto', '-3950.13', 'id', 'C6N1', 'nombre', 'ADP WAGE PAY OFFICER'))),
            '1098', 'c6-pruebas-oficial.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6N1');
    begin
      perform fn_banco_clasificar(v_m, '[{"cuenta": "6005"}]'::jsonb, 'c6-pruebas: el sueldo de Edgar');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('bandeja=%s clasificar_6005=%s', (select m.estado_motivo from movimientos_banco m where m.id = v_m), v_x);
    perform fn_banco_nomina(v_m, '[{"cuenta": "6005", "monto": "5000.13", "memo": "Sueldo de Edgar (oficial)"},
                                   {"cuenta": "2220", "monto": "-1050.00", "memo": "Retenciones"}]'::jsonb);
    v_obt := v_obt || format(' journal=%s lineas=%s', pg_temp.c6_est('1098', 'C6N1'),
                             (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.cuenta)
                                from asiento_lineas l join movimientos_banco m on m.asiento_id = l.asiento_id where m.id = v_m));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (77, 'la nómina solo del oficial entra por su journal (6005 y su retención); 6005 no se clasifica', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 78. EL REEMBOLSO DE UN PROVEEDOR TIENE SU CAMINO: con algo a favor de la
--     empresa en su cuenta (un pago de más), el depósito que lo nombra se
--     propone como su reembolso (fn_banco_pagar_proveedor con el
--     depósito: Cr 2010 contra lo que tenía a favor), clasificarlo a un
--     costo sin motivo es MX008, y con el reembolso su cuenta queda en
--     0.00. Sin nada a favor, el reembolso no cabe (MX008, y dice
--     clasificarlo contra el costo con su motivo). Antes pagar_proveedor
--     rechazaba un depósito y clasificar a 2010 mandaba a pagar_proveedor:
--     un círculo.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=reembolso_proveedor clasificar=MX008 reembolso=casado:pago_proveedor cuenta_2010=0.00 sin_favor=MX008';
  v_prov uuid;
  v_m   uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (78, 'el reembolso de un proveedor va contra lo que tenía a favor, no al costo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_prov := (pg_temp.c6_montar()->>'proveedor')::uuid;
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660781, 'total', 300.00, 'fecha', d + 3, 'metodo_pago', 'cuenta_proveedor'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 12, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 10, 'monto', '-450.00', 'id', 'C6X1', 'nombre', 'BILL PAY C6 PRUEBAS SUPPLY'))),
            '1098', 'c6-pruebas-x1.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_pagar_proveedor(pg_temp.c6_mov('1098', 'C6X1'), v_prov);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 13, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 20, 'monto', '150.00', 'id', 'C6X2', 'nombre', 'DEPOSIT',
                                 'memo', 'C6 PRUEBAS SUPPLY REFUND'),
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 21, 'monto', '80.00', 'id', 'C6X3', 'nombre', 'DEPOSIT',
                                 'memo', 'C6 PRUEBAS SUPPLY REFUND'))),
            '1098', 'c6-pruebas-x2.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6X2');
    begin
      perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('bandeja=%s clasificar=%s', (select m.estado_motivo from movimientos_banco m where m.id = v_m), v_x);
    perform fn_banco_pagar_proveedor(v_m, v_prov);
    v_obt := v_obt || format(' reembolso=%s cuenta_2010=%s', pg_temp.c6_est('1098', 'C6X2'),
                             (select coalesce(sum(l.monto), 0) from asiento_lineas l
                               where l.cuenta = fn_puente_cuenta_de('cxp') and l.tercero_tipo = 'proveedor'
                                 and l.tercero_id = v_prov::text));
    begin
      perform fn_banco_pagar_proveedor(pg_temp.c6_mov('1098', 'C6X3'), v_prov);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' sin_favor=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (78, 'el reembolso de un proveedor va contra lo que tenía a favor, no al costo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 79. LA TARJETA CON SU CÓDIGO CORTO (sus 4 últimos: '9996') sirve igual
--     en todo el banco: casar, conciliar (la conciliación es de su cuenta,
--     2100-9996) y la revisión entera; y una cuenta que no es de la
--     empresa en la revisión sale en rojo («cuentas pedidas»), no en verde
--     sin revisar nada. Antes el importador la aceptaba y casar, conciliar
--     y la apertura respondían que esa tarjeta no era de la empresa.
do $$
declare
  v_obt text;
  v_esp text := 'casar=t conciliar=2100-9996 verificar=t:2100-9996 nada=f';
  v_c   jsonb;
  v_det jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (79, 'el código corto de la tarjeta sirve para casar, conciliar y revisar', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'csv', 'cuenta', '9996', 'nombre', 'c6-pruebas-corto.csv',
              'filas', jsonb_build_array(jsonb_build_object('fecha', (d + 17)::text, 'monto', '-64.20',
                                                            'descripcion', 'THE HOME DEPOT 6345 TAMPA FL', 'tipo', 'DEBIT'))));
    v_obt := 'casar=' || case when fn_banco_casar_todo('9996') ? 'completo' then 't' else 'f' end;
    v_c := fn_conciliar('9996', d + 27, '64.20');
    v_obt := v_obt || ' conciliar=' || (v_c->>'cuenta');
    -- (una sola revisión con las dos: la tarjeta por su código corto entra
    -- como su cuenta; la que no es de la empresa sale en rojo. Cada
    -- revisión, con un año de banco, tarda casi medio segundo)
    select v.detalle into v_det from fn_banco_verificar(array['9996', 'nada']) v where v.control = 'cuentas pedidas';
    v_obt := v_obt || format(' verificar=%s:%s nada=%s',
                             case when coalesce(v_det->'no_son_de_la_empresa' ? '9996', true) then 'f' else 't' end,
                             (select string_agg(c.c, ',' order by c.c) from jsonb_array_elements_text(v_det->'cuentas') as c(c)
                               where c.c <> 'nada'),
                             case when coalesce(v_det->'no_son_de_la_empresa' ? 'nada', false) then 'f' else 't' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (79, 'el código corto de la tarjeta sirve para casar, conciliar y revisar', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 80. DES-CASAR LA MITAD DE UNA TRANSFERENCIA cuya otra mitad está en una
--     conciliación confirmada dice CUÁL reabrir (la cuenta y su fecha de
--     corte) y con qué: antes decía «reábrela antes», sin decir cuál.
do $$
declare
  v_obt text;
  v_esp text := 'r3=casado:transferencia confirmada=confirmada descasar=MX008:dice_cual';
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (80, 'des-casar la mitad de una transferencia dice qué conciliación confirmada reabrir', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 4, 'monto', '-500.00', 'id', 'C6DT1',
                                 'nombre', 'ONLINE TRANSFER TO SAV XXXXXX1097'))),
            '1098', 'c6-pruebas-dt1.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 27, 500.00, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 4, 'monto', '500.00', 'id', 'C6DT2',
                                 'nombre', 'ONLINE TRANSFER FROM CHK XXXXXX1098'))),
            '1097', 'c6-pruebas-dt2.ofx');
    perform fn_banco_casar_todo('1098');
    v_obt := 'r3=' || pg_temp.c6_est('1098', 'C6DT1');
    v_obt := v_obt || ' confirmada=' || (fn_conciliacion_confirmar((fn_conciliar('1097', d + 27, null)->>'conciliacion')::uuid)->>'estado');
    begin
      perform fn_banco_descasar(pg_temp.c6_mov('1098', 'C6DT1'), 'c6-pruebas: era de otro mes');
      v_x := 'entró';
    exception when others then
      v_x := sqlstate || case when sqlerrm like format('%%1097 al %s%%', d + 27) and sqlerrm like '%fn_conciliacion_reabrir%'
                              then ':dice_cual' else ':' || left(sqlerrm, 120) end;
    end;
    v_obt := v_obt || ' descasar=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (80, 'des-casar la mitad de una transferencia dice qué conciliación confirmada reabrir', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 81. DES-CASADO DE SU COBRO, UN DEPÓSITO DICE LO QUE PASÓ: vuelve a la
--     bandeja diciendo que Edgar lo des-casó de ese cobro (no «otro
--     movimiento también podría», que no lo hay) y ofrece anular el cobro
--     para registrar el bueno (fn_cobro_anular, con su motivo). Antes solo
--     ofrecía volver al mismo cobro.
do $$
declare
  v_obt text;
  v_esp text := 'tras=pendiente texto=descasaste anular=t';
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (81, 'un depósito des-casado de su cobro dice lo que pasó y ofrece anular el cobro', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660811, current_setting('mx6.obra'), 'C6-811', d + 1, 9000.11, 0),
           (-660812, current_setting('mx6.obra2'), 'C6-812', d + 2, 9000.11, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 8, 'monto', '9000.11', 'id', 'C6D81', 'nombre', 'REMOTE ONLINE DEPOSIT 1'))),
            '1098', 'c6-pruebas-d81.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6D81');
    perform fn_banco_cobrar(v_m, '[{"factura_id": -660811, "monto": "9000.11"}]'::jsonb);
    v_obt := 'tras=' || (fn_banco_descasar(v_m, 'c6-pruebas: era el cobro de la otra factura')->>'estado');
    v_obt := v_obt || format(' texto=%s anular=%s',
                             (select case when m.propuesta->>'texto' like 'Lo des-casaste%' then 'descasaste' else left(m.propuesta->>'texto', 60) end
                                from movimientos_banco m where m.id = v_m),
                             case when exists (select 1 from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                                                where m.id = v_m and o->>'llamar' = 'fn_cobro_anular') then 't' else 'f' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (81, 'un depósito des-casado de su cobro dice lo que pasó y ofrece anular el cobro', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 82. UN TICKET QUE NO LE CAMBIA NADA A LA BANDEJA NO LA REHACE: con la
--     bandeja propuesta, un ticket de otra tarjeta (la cuadrilla sube
--     tickets todo el día) no hace rehacer ninguna propuesta en el
--     siguiente «Casar», y rehacer una propuesta que solo cambia su firma
--     no escribe el historial. Antes cada ticket cambiaba la firma de
--     todas: el siguiente «Casar» las reescribía todas, idénticas, y el
--     historial guardaba cada fila entera dos veces (66 MB en un año).
do $$
declare
  v_obt text;
  v_esp text := 'primera=3 ticket=0 historial=0';
  v_x   jsonb;
  v_h   bigint;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (82, 'un ticket que no le cambia nada a la bandeja no rehace sus propuestas', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-41.13', 'id', 'C6F1', 'nombre', 'SHELL OIL 57442'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'monto', '-17.29', 'id', 'C6F2', 'nombre', 'CHEVRON 0091'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 9, 'monto', '-8.77', 'id', 'C6F3', 'nombre', 'WAWA 5512'))),
            '1098', 'c6-pruebas-firma.qfx');
    v_x := fn_banco_casar_todo('1098');
    v_obt := 'primera=' || (v_x->>'propuestas');
    v_h := (select count(*) from banco_historial where tabla = 'movimientos_banco');
    -- Un ticket de la otra tarjeta (····9995), que nada pendiente espera.
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660820, 'total', 23.45, 'fecha', d + 6, 'proveedor', 'LOWES', 'ultimos4', '9995',
                                                 'num_recibo', 'C6-LW-82'));
    v_x := fn_banco_casar_todo('1098');
    v_obt := v_obt || format(' ticket=%s historial=%s', v_x->>'propuestas',
                             (select count(*) from banco_historial where tabla = 'movimientos_banco') - v_h);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (82, 'un ticket que no le cambia nada a la bandeja no rehace sus propuestas', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- =====================================================================
-- La ronda 3 (27-sep): una por hallazgo, de la 83 a la 100.
-- =====================================================================

-- 83. EL TICKET CON OTRO TOTAL NO DEJA CLASIFICAR SU CARGO: el ticket de
--     THE HOME DEPOT leído sin el tax (100.00) y el cargo de la tarjeta
--     (107.00) no casan (el dinero no es el mismo), pero la bandeja dice
--     «otro_total» con ese ticket; clasificarlo sin motivo es MX008 (el
--     gasto entraría dos veces); corregido el total del recibo (lo que hace
--     ✎: su asiento se rehace), el cargo casa solo con él; y con su motivo
--     («es otra compra») sí se clasifica, y ese ticket ya no se le propone.
--     Antes salía «sin ticket», se clasificaba sin decir nada y la obra
--     quedaba con 207.00 de costo.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=otro_total ticket=100.00 clasificar=MX008 corregido=casado:recibo con_motivo=casado:clasificado descartado=t';
  v_m   uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (83, 'un ticket con otro total (sin el tax) se propone y no deja clasificar su cargo sin motivo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660831, 'total', 100.00, 'fecha', d + 3, 'proveedor', 'THE HOME DEPOT'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 4, 'fecha_usuario', d + 3, 'monto', '-107.00', 'id', 'C6OT1',
                                 'nombre', 'THE HOME DEPOT #6345 MIAMI FL'))),
            null, 'c6-pruebas-otro-total.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6OT1');
    v_obt := format('bandeja=%s ticket=%s', (select m.estado_motivo from movimientos_banco m where m.id = v_m),
                    (select -(m.propuesta->'tickets'->0->>'monto')::numeric from movimientos_banco m where m.id = v_m));
    begin
      perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' clasificar=' || v_x;
    -- (corregido el total del recibo, como con ✎ en la app; se deshace)
    begin
      update recibos set total = 107.00 where id = -660831;
      perform fn_banco_casar_todo('2100-9996');
      v_x := pg_temp.c6_est('2100-9996', 'C6OT1');
      raise exception using errcode = 'MXT02';
    exception when sqlstate 'MXT02' then null;
    end;
    v_obt := v_obt || ' corregido=' || v_x;
    perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas: otra compra del mismo día; ese ticket es de otra');
    v_obt := v_obt || format(' con_motivo=%s descartado=%s', pg_temp.c6_est('2100-9996', 'C6OT1'),
                             case when (select jsonb_array_length(m.propuesta->'descartados') from movimientos_banco m where m.id = v_m) = 1
                                   and not exists (select 1 from fn_banco_tickets_llegados(array['2100-9996'], v_m)) then 't' else 'f' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (83, 'un ticket con otro total (sin el tax) se propone y no deja clasificar su cargo sin motivo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 84. EL TICKET DE OTRO TOTAL QUE LLEGA DESPUÉS DE CLASIFICAR SE DICE: el
--     cargo de 107.00 se clasificó sin ticket y después sube su ticket de
--     THE HOME DEPOT por 100.00: «llego_su_ticket» con el otro total y sin
--     el botón de cambiarlo (el dinero no es el mismo: «es su ticket» es
--     MX008 hasta corregir su total), el cuadre «ningún ticket después de
--     clasificar» en rojo, y la conciliación de la tarjeta lo marca
--     posible_duplicado y no se confirma. Antes solo miraba el mismo monto:
--     el ticket quedaba «en circulación» y todo en verde.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=llego_su_ticket otro_total=t boton=f es_el_mismo=MX008 control=f dif=0.00 conciliacion=posible_duplicado:MX008';
  v_m   uuid;
  v_x   text;
  v_c   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (84, 'el ticket con otro total que llega después de clasificar: se dice, frena el control y la conciliación',
                                 v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 20, -107.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 4, 'fecha_usuario', d + 3, 'monto', '-107.00', 'id', 'C6OT2',
                                 'nombre', 'THE HOME DEPOT #6345 MIAMI FL'))),
            null, 'c6-pruebas-otro-total-2.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6OT2');
    perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660841, 'total', 100.00, 'fecha', d + 3, 'proveedor', 'THE HOME DEPOT'));
    perform fn_banco_casar_todo('2100-9996');
    select format('bandeja=%s otro_total=%s boton=%s', m.propuesta->>'motivo',
                  case when m.propuesta->>'texto' like '%OTRO total%' then 't' else 'f' end,
                  case when exists (select 1 from jsonb_array_elements(m.propuesta->'opciones') o where o->>'llamar' = 'fn_banco_casar_con')
                       then 't' else 'f' end)
      into v_obt from movimientos_banco m where m.id = v_m;
    begin
      perform fn_banco_duplicado(v_m, true);
      v_x := 'cambió';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || format(' es_el_mismo=%s control=%s', v_x,
                             pg_temp.c6_cuadre('cuadre: ningún ticket después de clasificar', current_setting('mx6.mes'), v_m::text));
    v_c := fn_conciliar('2100-9996', d + 20, '107.00');
    v_obt := v_obt || ' dif=' || (v_c->>'diferencia');
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := 'confirmada';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' conciliacion=' || coalesce((select string_agg(distinct p.clase, ',') from conciliacion_partidas p
                                                      where p.conciliacion_id = (v_c->>'conciliacion')::uuid and p.lado = 'libro'), '-')
             || ':' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (84, 'el ticket con otro total que llega después de clasificar: se dice, frena el control y la conciliación',
                               v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 85. EL PAGO DE LA TARJETA QUE EL BANCO COBRA DÍAS DESPUÉS casa con la
--     transferencia que ya lo espera: la tarjeta acredita el pago el día
--     15 (Edgar lo confirmó «desde 1098») y el banco lo cobra el 19 (un
--     fin de semana largo): casa solo con esa línea, un solo asiento y el
--     banco cuadra. Y el que llega 9 días después (fuera de la ventana de
--     casar solo) se propone como «el otro lado» y otra transferencia es
--     MX008. Antes la ventana era de 3 días: la bandeja ofrecía otra
--     transferencia y el pago entraba dos veces.
do $$
declare
  v_obt text;
  v_esp text := 'banco=casado:transferencia asientos=1 dif=0.00 tarde=pendiente:transferencia_otro_lado otra=MX008';
  v_x   text;
  v_n0  bigint;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (85, 'el pago de la tarjeta que el banco cobra días después casa con su transferencia, sin otra', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_n0 := (select count(*) from asientos a where a.descripcion like 'Transferencia%');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 18, 0.00, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 14, 'monto', '500.00', 'id', 'C6P1', 'nombre', 'ONLINE PAYMENT - THANK YOU'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 9, 'monto', '300.00', 'id', 'C6P2', 'nombre', 'ONLINE PAYMENT - THANK YOU'))),
            null, 'c6-pruebas-pago-tarjeta.qfx');
    perform fn_banco_casar_todo('2100-9996');
    perform fn_banco_transferencia(pg_temp.c6_mov('2100-9996', 'C6P1'), '1098');
    perform fn_banco_transferencia(pg_temp.c6_mov('2100-9996', 'C6P2'), '1098');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, -800.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 18, 'monto', '-500.00', 'id', 'C6P3', 'nombre', 'AMERICAN EXPRESS ACH PMT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 18, 'monto', '-300.00', 'id', 'C6P4', 'nombre', 'AMERICAN EXPRESS ACH PMT'))),
            '1098', 'c6-pruebas-pago-banco.qfx');
    perform fn_banco_casar_todo('1098');
    begin
      perform fn_banco_transferencia(pg_temp.c6_mov('1098', 'C6P4'), '2100-9996');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('banco=%s asientos=%s dif=%s tarde=%s otra=%s', pg_temp.c6_est('1098', 'C6P3'),
                    (select count(*) from asientos a where a.descripcion like 'Transferencia%'
                        and exists (select 1 from asiento_lineas l where l.asiento_id = a.id and l.monto = -500.00)) ,
                    '-', pg_temp.c6_est('1098', 'C6P4'), v_x);
    v_obt := replace(v_obt, 'dif=-', 'dif=' || (select (fn_conciliar('1098', d + 20, '-800.00')->>'diferencia')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (85, 'el pago de la tarjeta que el banco cobra días después casa con su transferencia, sin otra', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 86. UN PAGO PARCIAL DE UN CLIENTE NO SE CLASIFICA CONTRA EL COSTO SIN
--     MOTIVO: la bandeja propone la parte de su factura (deposito_parcial);
--     clasificarlo a la obra sin motivo es MX008 (la factura seguiría
--     entera por cobrar y el dinero del cliente entraría dos veces); con su
--     motivo escrito, sí. Y el control «depósitos nunca a ingreso» pone en
--     rojo un asiento del banco que lleva a otra cuenta, sin motivo, un
--     depósito cuya propuesta era su cobro (por la puerta interna, a
--     propósito). Antes solo miraba 4xxx.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=deposito_parcial sin_motivo=MX008 con_motivo=casado:clasificado control=t interno=f';
  v_x   text;
  v_m   uuid;
  v_m2  uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (86, 'un pago parcial de un cliente no se clasifica al costo sin motivo; el control lo vigila', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660861, current_setting('mx6.obra'), 'C6-86', d + 2, 8765.43, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 10, 'monto', '2345.67', 'id', 'C6PP1', 'nombre', 'ZELLE FROM C6 FAMILIA'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 11, 'monto', '1234.56', 'id', 'C6PP2', 'nombre', 'ZELLE FROM C6 FAMILIA'))),
            '1098', 'c6-pruebas-parcial.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6PP1');
    v_m2 := pg_temp.c6_mov('1098', 'C6PP2');
    begin
      perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('bandeja=%s sin_motivo=%s', (select m.estado_motivo from movimientos_banco m where m.id = v_m), v_x);
    perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas: el reembolso de una compra que el cliente pagó por la empresa');
    v_obt := v_obt || format(' con_motivo=%s control=%s', pg_temp.c6_est('1098', 'C6PP1'),
                             pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'), v_m::text));
    perform fn_postear_interno(jsonb_build_object(
      'camino', 'puente', 'fecha', (d + 11)::text, 'descripcion', 'c6-pruebas: un depósito a la obra sin motivo (se deshace)',
      'origen_tabla', 'movimientos_banco', 'origen_id', v_m2::text,
      'procedencia', jsonb_build_object('funcion', 'fn_banco_clasificar', 'propuesta', 'deposito_parcial'),
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '1234.56'),
                                  jsonb_build_object('cuenta', '5100', 'monto', '-1234.56', 'proyecto_id', current_setting('mx6.obra')))));
    v_obt := v_obt || ' interno=' || pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'), v_m2::text);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (86, 'un pago parcial de un cliente no se clasifica al costo sin motivo; el control lo vigila', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 87. EL CHEQUE QUE REBOTA DE UN DEPÓSITO DE DOS CHEQUES tiene su camino:
--     el depósito de 13,000.00 entró como UN cobro de las dos facturas
--     (la opción de la bandeja) y rebota el de 8,000.00: la bandeja
--     propone «rebotó el cheque de la factura…»; clasificarlo sin motivo es
--     MX008 (no es un gasto); con su botón, el cobro se devuelve en esa
--     fecha y lo que no rebotó (5,000.00) se registra otra vez ese día: la
--     factura del cheque rebotado queda por cobrar, la otra cobrada, y el
--     banco cuadra. Antes fn_banco_devolver pedía el cobro entero y lo
--     único que entraba (sin motivo) era a gasto o contra el ingreso.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=devolucion opcion=t clasificar=MX008 devuelto=casado:devolucion por_cobrar=0.00/8000.00 nuevo=5000.00 dif=0.00';
  v_x   text;
  v_m   uuid;
  v_op  jsonb;
  v_r   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (87, 'el cheque que rebota de un depósito de dos: se devuelve y lo demás se registra otra vez', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660871, current_setting('mx6.obra'), 'C6-871', d + 1, 5000.00, 0),
           (-660872, current_setting('mx6.obra'), 'C6-872', d + 2, 8000.00, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 5000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 5, 'monto', '13000.00', 'id', 'C6RB1', 'nombre', 'REMOTE ONLINE DEPOSIT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 9, 'monto', '-8000.00', 'id', 'C6RB2', 'nombre', 'DEPOSITED ITEM RETURNED NSF'))),
            '1098', 'c6-pruebas-rebote.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6RB1');
    -- (la opción de la bandeja con SUS dos facturas: con datos de verdad,
    -- otra factura abierta de 5,000.00 también suma 13,000.00 con la de
    -- 8,000.00, y puede salir antes; si no está entre las opciones, las
    -- mismas aplicaciones escritas aquí)
    perform fn_banco_cobrar(v_m, coalesce(
              (select o->'args'->'p_aplicaciones' from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                where m.id = v_m and o->>'llamar' = 'fn_banco_cobrar' and jsonb_array_length(o->'args'->'p_aplicaciones') = 2
                  and o->'args'->'p_aplicaciones' @> '[{"factura_id": -660871}]'
                  and o->'args'->'p_aplicaciones' @> '[{"factura_id": -660872}]'
                limit 1),
              '[{"factura_id": -660872, "monto": "8000.00"}, {"factura_id": -660871, "monto": "5000.00"}]'::jsonb));
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6RB2');
    select o into v_op from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m and o->>'llamar' = 'fn_banco_devolver' limit 1;
    begin
      perform fn_banco_clasificar(v_m, '[{"cuenta": "6130"}]'::jsonb);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := format('bandeja=%s opcion=%s clasificar=%s', (select m.estado_motivo from movimientos_banco m where m.id = v_m),
                    case when v_op->>'texto' like '%C6-872%' then 't' else 'f' end, v_x);
    v_r := fn_banco_devolver((v_op->'args'->>'p_movimiento')::uuid, (v_op->'args'->>'p_cobro')::uuid, v_op->'args'->>'p_motivo');
    v_obt := v_obt || format(' devuelto=%s por_cobrar=%s/%s nuevo=%s dif=%s', pg_temp.c6_est('1098', 'C6RB2'),
                             (select coalesce(sum(l.monto), 0) from asiento_lineas l where l.partida_tabla = 'facturas' and l.partida_id = '-660871'
                                 and l.cuenta = fn_puente_cuenta_de('cxc')),
                             (select coalesce(sum(l.monto), 0) from asiento_lineas l where l.partida_tabla = 'facturas' and l.partida_id = '-660872'
                                 and l.cuenta = fn_puente_cuenta_de('cxc')),
                             (select c.monto from cobros c where c.id = (v_r->>'cobro_nuevo')::uuid),
                             fn_conciliar('1098', d + 20, '5000.00')->>'diferencia');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (87, 'el cheque que rebota de un depósito de dos: se devuelve y lo demás se registra otra vez', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 88. LA PÓLIZA QUE SE CORRIGE O SE CANCELA tiene su camino: con octubre
--     amortizado a la cuenta equivocada (6200), cambiarle la cuenta es
--     MX008 y el mensaje dice cómo sustituirla; cancelarla sin su fecha es
--     22023. La que la SUSTITUYE (5015) devuelve en noviembre lo que la
--     vieja llevaba (6200 queda en cero) y amortiza por acumulado desde su
--     inicio (61 días: 2,005.48). Y CANCELADA de verdad el 15 de noviembre
--     con 9,000.00 devueltos: noviembre lleva al gasto todo lo que queda
--     menos lo devuelto (3,000.00 en total) y, con la devolución en su
--     cuenta, 1410 queda en cero para ella. Antes «cancélalo y registra
--     otro» amortizaba octubre dos veces y lo cancelado se quedaba en 1410.
--     (Mide solo las líneas de SUS pólizas.)
do $$
declare
  v_obt text;
  v_esp text := 'cambiar=MX008:sustituye cancelar=22023 oct=1019.18 nov=-1019.18/2005.48 gasto=0.00/2005.48 cancelada=3000.00 '
                'queda=0.00 control=igual';
  v_a   uuid;
  v_b   uuid;
  v_x   text;
  v_ok0 boolean;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
  v_sig text := nullif(current_setting('mx6.sig', true), '');
begin
  if d is null or d <> fn_puente_corte() or v_sig is null then
    insert into _pruebas values (88, 'la póliza corregida se sustituye sin amortizar dos veces; la cancelada queda en cero', v_esp,
                                 'omitida: el mes abierto más antiguo no es el primero después del corte, o no está abierto el siguiente',
                                 null);
    return;
  end if;
  if pg_temp.c6_amortizado_despues() is not null then
    insert into _pruebas values (88, 'la póliza corregida se sustituye sin amortizar dos veces; la cancelada queda en cero', v_esp,
                                 format('omitida: ya está amortizado %s, posterior al mes abierto más antiguo (se amortiza el último)',
                                        pg_temp.c6_amortizado_despues()), null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_ok0 := (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prepagados']) c where c.vista = 'cuadre: prepagados');
    v_a := (fn_prepagado_guardar(jsonb_build_object('descripcion', 'c6-pruebas WC 88', 'tipo', 'seguro', 'cuenta_gasto', '6200',
              'monto', '12000.00', 'desde', d::text, 'hasta', (d + 364)::text))->>'id')::uuid;
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: la póliza pagada (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1410', 'monto', '12000.00'),
                                  jsonb_build_object('cuenta', '1098', 'monto', '-12000.00'))));
    perform fn_prepagados_amortizar(current_setting('mx6.mes'));
    begin
      perform fn_prepagado_guardar(jsonb_build_object('id', v_a, 'cuenta_gasto', '5015'));
      v_x := 'entró';
    exception when others then v_x := sqlstate || case when sqlerrm like '%"sustituye"%' then ':sustituye' else '' end;
    end;
    v_obt := 'cambiar=' || v_x;
    begin
      perform fn_prepagado_guardar(jsonb_build_object('id', v_a, 'estado', 'cancelado'));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' cancelar=' || v_x
             || ' oct=' || (select a.monto::text from prepagados_amortizaciones a where a.prepagado_id = v_a and a.vigente);
    v_b := (fn_prepagado_guardar(jsonb_build_object('sustituye', v_a, 'cuenta_gasto', '5015'))->>'id')::uuid;
    perform fn_prepagados_amortizar(v_sig);
    v_obt := v_obt || format(' nov=%s/%s gasto=%s/%s',
               (select a.monto from prepagados_amortizaciones a where a.prepagado_id = v_a and a.periodo = v_sig and a.vigente),
               (select a.monto from prepagados_amortizaciones a where a.prepagado_id = v_b and a.periodo = v_sig and a.vigente),
               (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos s on s.id = l.asiento_id
                 where s.origen_tabla = 'prepagados' and l.cuenta = '6200' and l.memo like '%c6-pruebas WC 88%'
                   and not exists (select 1 from asientos r where r.reversa_a = s.id and r.camino = 'reverso')),
               (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos s on s.id = l.asiento_id
                 where s.origen_tabla = 'prepagados' and l.cuenta = '5015' and l.memo like '%c6-pruebas WC 88%'
                   and not exists (select 1 from asientos r where r.reversa_a = s.id and r.camino = 'reverso')));
    -- La cancelación de verdad: el 15 de noviembre, con 9,000.00 devueltos
    -- (el depósito de la aseguradora, a 1410).
    perform fn_prepagado_guardar(jsonb_build_object('id', v_b, 'estado', 'cancelado', 'cancelado_al', (d + 45)::text,
                                                    'devuelto', '9,000.00'));
    perform fn_prepagados_amortizar(v_sig);
    perform fn_postear(jsonb_build_object('fecha', (d + 50)::text, 'descripcion', 'c6-pruebas: la devolución de la aseguradora (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '9000.00'),
                                  jsonb_build_object('cuenta', '1410', 'monto', '-9000.00'))));
    v_obt := v_obt || format(' cancelada=%s queda=%s control=%s',
               (select sum(a.monto) from prepagados_amortizaciones a where a.prepagado_id in (v_a, v_b) and a.vigente),
               12000.00 - 9000.00 - (select sum(a.monto) from prepagados_amortizaciones a where a.prepagado_id in (v_a, v_b) and a.vigente),
               case when (select c.ok from fn_banco_control(v_sig, array['v_prepagados']) c where c.vista = 'cuadre: prepagados')
                         is not distinct from v_ok0 then 'igual' else 'cambió' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (88, 'la póliza corregida se sustituye sin amortizar dos veces; la cancelada queda en cero', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 89. LA TRANSFERENCIA QUE CASA SOLA NO ENTRA EN UNA CONCILIACIÓN
--     CONFIRMADA: el banco conciliado y confirmado al día 30; la tarjeta
--     acredita el pago el 29 y el banco lo cobra el 32 (el 2 del mes
--     siguiente): R3 los casa con UN asiento fechado el día siguiente al
--     corte confirmado (con la nota que lo dice), y el saldo en libros de
--     la confirmada no cambia. Antes el asiento iba el 29, dentro de la
--     confirmada, y el control seguía en verde. (Ronda 4: el estado de
--     cuenta de la tarjeta llega hasta el 40, más allá del día 31: si
--     cortara antes, ese asiento lo dejaría partido y R3 no lo casa solo
--     —la 102—.)
do $$
declare
  v_obt text;
  v_esp text := 'banco=casado:transferencia tarjeta=casado:transferencia fecha=+31 nota=t libros=igual control=t';
  v_c   jsonb;
  v_l0  numeric;
  v_a   asientos;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or current_setting('mx6.sig', true) = '' then
    insert into _pruebas values (89, 'R3 no mete una transferencia dentro de una conciliación confirmada', v_esp,
                                 'omitida: falta el mes abierto o el siguiente', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 30, -15.00, jsonb_build_array(
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 8, 'monto', '-15.00', 'id', 'C6R3A', 'nombre', 'MONTHLY SERVICE FEE'))),
            '1098', 'c6-pruebas-r3-oct.qfx');
    perform fn_banco_casar_todo('1098');
    v_c := fn_conciliar('1098', d + 30, '-15.00');
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    v_l0 := fn_banco_saldo_libros('1098', d + 30);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d + 10, d + 40, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 29, 'monto', '500.00', 'id', 'C6R3B', 'nombre', 'ONLINE PAYMENT - THANK YOU'))),
            null, 'c6-pruebas-r3-tarjeta.qfx');
    perform fn_banco_casar_todo('2100-9996');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 31, d + 40, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 32, 'monto', '-500.00', 'id', 'C6R3C', 'nombre', 'AMERICAN EXPRESS ACH PMT'))),
            '1098', 'c6-pruebas-r3-nov.qfx');
    perform fn_banco_casar_todo('1098');
    select a.* into v_a from asientos a join movimientos_banco m on m.asiento_id = a.id where m.id = pg_temp.c6_mov('1098', 'C6R3C');
    v_obt := format('banco=%s tarjeta=%s fecha=+%s nota=%s libros=%s control=%s', pg_temp.c6_est('1098', 'C6R3C'),
                    pg_temp.c6_est('2100-9996', 'C6R3B'), v_a.fecha_contable - d,
                    case when v_a.procedencia ? 'fecha_nota' then 't' else 'f' end,
                    case when fn_banco_saldo_libros('1098', d + 30) = v_l0 then 'igual' else 'cambió' end,
                    pg_temp.c6_cuadre('cuadre: conciliaciones confirmadas', current_setting('mx6.mes'), '1098'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (89, 'R3 no mete una transferencia dentro de una conciliación confirmada', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 90. EL SALDO DE UN LOTE DE PLAID de una tarjeta entra con el signo del
--     libro: Plaid da lo que se debe en positivo (plaid_saldo 1,173.26) y
--     el archivo guarda -1,173.26 (como el LEDGERBAL de la Amex); un lote
--     de Plaid con «saldo» (sin decir de qué signo) no entra (22023); y en
--     un lote a mano, el saldo positivo de una tarjeta se avisa. Y los
--     montos con coma de miles («-1,029.33», «54,172.37») entran, como en
--     fn_conciliar. Antes el saldo de Plaid entraba sin voltear (la deuda
--     como saldo a favor) y el lote rechazaba la coma de miles.
do $$
declare
  v_obt text;
  v_esp text := 'plaid=-1173.26 saldo_en_plaid=22023 aviso=t coma=-1029.33/54172.37';
  v_x   jsonb;
  v_e   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (90, 'el saldo de Plaid de una tarjeta entra con el signo del libro; la coma de miles se lee', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_x := fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '9996', 'nombre', 'c6-pruebas plaid',
             'plaid_saldo', '1173.26', 'saldo_al', (d + 5)::text,
             'filas', jsonb_build_array(jsonb_build_object('id', 'C6PL1', 'fecha', (d + 2)::text, 'plaid_monto', '45.10',
                                                           'descripcion', 'C6 SHELL OIL'))));
    v_obt := 'plaid=' || (select a.saldo::text from archivos_banco a where a.id = (v_x->>'archivo')::uuid);
    begin
      perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '9996', 'nombre', 'c6-pruebas plaid 2',
                'saldo', '1173.26', 'saldo_al', (d + 6)::text,
                'filas', jsonb_build_array(jsonb_build_object('id', 'C6PL2', 'fecha', (d + 3)::text, 'plaid_monto', '12.00',
                                                              'descripcion', 'C6 SHELL OIL'))));
      v_e := 'entró';
    exception when others then v_e := sqlstate;
    end;
    v_obt := v_obt || ' saldo_en_plaid=' || v_e;
    v_x := fn_banco_importar_filas(jsonb_build_object('origen', 'mano', 'cuenta', '9996', 'nombre', 'c6-pruebas a mano',
             'saldo', '200.00', 'saldo_al', (d + 7)::text,
             'filas', jsonb_build_array(jsonb_build_object('id', 'C6PL3', 'fecha', (d + 4)::text, 'monto', '-20.00',
                                                           'descripcion', 'C6 SHELL OIL'))));
    v_obt := v_obt || ' aviso=' || case when v_x ? 'avisos' then 't' else 'f' end;
    v_x := fn_banco_importar_filas(jsonb_build_object('origen', 'csv', 'cuenta', '1098', 'nombre', 'c6-pruebas coma.csv',
             'saldo', '54,172.37', 'saldo_al', (d + 8)::text,
             'filas', jsonb_build_array(jsonb_build_object('id', 'C6CM1', 'fecha', (d + 5)::text, 'monto', '-1,029.33',
                                                           'descripcion', 'C6 CHECK 2001'))));
    v_obt := v_obt || format(' coma=%s/%s', (select m.monto from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6CM1')),
                             (select a.saldo from archivos_banco a where a.id = (v_x->>'archivo')::uuid));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (90, 'el saldo de Plaid de una tarjeta entra con el signo del libro; la coma de miles se lee', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 91. LAS PROTECCIONES VEN UNA REGLA AJENA QUE LEE EL BANCO: una regla
--     (create rule) en una tabla donde la API escribe (horas), cuya acción
--     lee las tablas del banco, pone «protecciones del banco» en rojo (se
--     dispara con los permisos del dueño de horas y se salta la RLS del
--     banco); sin la regla, ya no. Antes solo se miraban los triggers: la
--     regla podía copiar el estado de cuenta a una tabla que el equipo lee,
--     con el control en verde.
do $$
declare
  v_obt text;
  v_esp text := 'con_regla=f sin_regla=t';
begin
  if to_regclass('public.horas') is null then
    insert into _pruebas values (91, 'las protecciones ven una regla ajena (pg_rewrite) que lee el banco', v_esp,
                                 'omitida: no hay tabla horas', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    execute 'create rule c6_pruebas_regla as on insert to public.horas do also select count(*) from public.movimientos_banco m';
    v_obt := 'con_regla=' || (select case when position('c6_pruebas_regla' in coalesce(c.detalle, '')) > 0 then 'f' else 't' end
                                from fn_banco_control('hoy', array['v_banco_saldos']) c
                               where c.vista = 'cuadre: protecciones del banco');
    execute 'drop rule c6_pruebas_regla on public.horas';
    v_obt := v_obt || ' sin_regla=' || (select case when position('c6_pruebas_regla' in coalesce(c.detalle, '')) > 0 then 'f' else 't' end
                                          from fn_banco_control('hoy', array['v_banco_saldos']) c
                                         where c.vista = 'cuadre: protecciones del banco');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa horas (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (91, 'las protecciones ven una regla ajena (pg_rewrite) que lee el banco', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 92. EL STATEMENT DE LA TARJETA CORTADO ANTES DEL 30-SEP: el cargo que
--     QuickBooks dejó sin conciliar (la partida de la apertura de la
--     tarjeta) llega fechado antes del corte (ignorado: está en
--     QuickBooks) y casa solo con su partida; la conciliación del mes se
--     confirma; des-casarlo con ella confirmada no se puede, y reabierta
--     vuelve a ignorado; casarlo a mano con su partida, sí. Antes se
--     quedaba ignorado, la partida no llegaba nunca y la conciliación de
--     la tarjeta no se confirmaba.
do $$
declare
  v_obt text;
  v_esp text := 'shell=casado:apertura confirmada=confirmada descasar=MX008 reabierta=ignorado:- a_mano=casado:apertura';
  v_c   jsonb;
  v_id  uuid;
  v_m   uuid;
  v_x   text;
  v_p   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or d <> fn_puente_corte() or not exists (select 1 from periodos where tipo = 'apertura') then
    insert into _pruebas values (92, 'la tarjeta con el statement cortado antes del corte: su cargo casa con la partida de la apertura',
                                 v_esp, 'omitida: el mes abierto más antiguo no es el primero después del corte, o falta la apertura',
                                 null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_apertura_minima();
    -- (la tarjeta de prueba no tiene saldo en la apertura: su último
    -- statement, con 512.18 a favor, es lo que la partida compensa; el de
    -- octubre, lo que se debe después del Shell y de Adobe)
    v_c := fn_conciliacion_apertura('2100-9996', '-512.18', jsonb_build_array(
             jsonb_build_object('fecha', (d - 7)::text, 'monto', '-512.18', 'descripcion', 'c6-pruebas: Shell sin conciliar en QuickBooks')));
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    v_p := (select p.id from conciliacion_partidas p where p.conciliacion_id = (v_c->>'conciliacion')::uuid and p.monto = -512.18);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d - 8, d + 21, -129.99, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d - 6, 'fecha_usuario', d - 7, 'monto', '-512.18', 'id', 'C6SH1',
                                 'nombre', 'SHELL OIL 57444221 TAMPA FL'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 17, 'fecha_usuario', d + 15, 'monto', '-129.99', 'id', 'C6SH2',
                                 'nombre', 'ADOBE *ACROPRO SUBS'))),
            null, 'c6-pruebas-cortado.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6SH1');
    perform fn_banco_clasificar(pg_temp.c6_mov('2100-9996', 'C6SH2'), '[{"cuenta": "6500"}]'::jsonb);
    v_c := fn_conciliar('2100-9996', d + 21, '129.99');
    v_id := (v_c->>'conciliacion')::uuid;
    v_obt := format('shell=%s confirmada=%s', pg_temp.c6_est('2100-9996', 'C6SH1'), fn_conciliacion_confirmar(v_id)->>'estado');
    begin
      perform fn_banco_descasar(v_m, 'c6-pruebas: des-casar con la conciliación confirmada');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    perform fn_conciliacion_reabrir(v_id, 'c6-pruebas: probar el des-casado');
    perform fn_banco_descasar(v_m, 'c6-pruebas: des-casar reabierta');
    v_obt := v_obt || format(' descasar=%s reabierta=%s:%s', v_x, (select m.estado from movimientos_banco m where m.id = v_m),
                             case when (select m.casado_id from movimientos_banco m where m.id = v_m) is null then '-' else 'casado' end);
    perform fn_banco_casar_con(v_m, jsonb_build_object('partida_apertura', v_p));
    v_obt := v_obt || ' a_mano=' || pg_temp.c6_est('2100-9996', 'C6SH1');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (92, 'la tarjeta con el statement cortado antes del corte: su cargo casa con la partida de la apertura',
                               v_esp, coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 93. CON UN PROVEEDOR A CUENTA, LO QUE NOMBRA A OTRO NO ES SU ABONO: con
--     1,500.00 que se le deben al proveedor, la luz (el pago en línea a
--     FPL y su domiciliación) y un Zelle a una persona salen «sin ticket»
--     (clasificar la luz a 6110 entra sin motivo), y el cheque sin nombre
--     sí se propone como abono al proveedor. Antes todo cargo con PAYMENT
--     o DIRECTDEBIT salía «Abono a …» con un solo botón, y el retiro del
--     dueño bajaba la deuda de un proveedor.
do $$
declare
  v_obt text;
  v_esp text := 'fpl=sin_ticket/sin_ticket zelle=sin_ticket cheque=pago_proveedor:abono luz=casado:clasificado';
  v_prov uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (93, 'con un proveedor a cuenta, la luz y un Zelle a una persona no son su abono', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    v_prov := (pg_temp.c6_montar()->>'proveedor')::uuid;
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660931, 'total', 1500.00, 'fecha', d + 2, 'metodo_pago', 'cuenta_proveedor'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 23, 'monto', '-212.33', 'id', 'C6FP1',
                                 'nombre', 'ONLINE PAYMENT 1234567 TO FLORIDA POWER &amp; LIGHT'),
              jsonb_build_object('tipo', 'DIRECTDEBIT', 'fecha', d + 23, 'monto', '-189.40', 'id', 'C6FP2', 'nombre', 'FPL DIRECT DEBIT ELEC PYMT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 25, 'monto', '-350.00', 'id', 'C6FP3',
                                 'nombre', 'ZELLE PAYMENT TO MIGUEL SANCHEZ JPM99ABC'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 26, 'monto', '-700.00', 'id', 'C6FP4', 'nombre', 'CHECK 1044',
                                 'cheque', '1044'))),
            '1098', 'c6-pruebas-luz.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := format('fpl=%s/%s zelle=%s cheque=%s:%s',
                    (select m.estado_motivo from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6FP1')),
                    (select m.estado_motivo from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6FP2')),
                    (select m.estado_motivo from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6FP3')),
                    (select m.estado_motivo from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6FP4')),
                    case when exists (select 1 from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                                       where m.id = pg_temp.c6_mov('1098', 'C6FP4') and o->'args'->>'p_proveedor' = v_prov::text)
                         then 'abono' else '-' end);
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6FP2'), '[{"cuenta": "6110", "memo": "c6-pruebas: la luz"}]'::jsonb);
    v_obt := v_obt || ' luz=' || pg_temp.c6_est('1098', 'C6FP2');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (93, 'con un proveedor a cuenta, la luz y un Zelle a una persona no son su abono', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 94. EL COBRO CON TARJETA, DEPOSITADO NETO DE SU COMISIÓN: el procesador
--     (INTUIT, QB PAYMENTS) deposita 970.70 por la factura de 1,000.00; la
--     bandeja ofrece la factura con su comisión (29.30); con ella, el cobro
--     es por el bruto (la factura queda en cero) y la comisión va a 6130
--     en un asiento del banco casado junto al cobro. Des-casado, la
--     comisión se reversa con él. Antes la factura quedaba abierta por la
--     comisión para siempre, o había que postear a mano.
do $$
declare
  v_obt text;
  v_esp text := 'opcion=29.30 cobrado=casado:cobro por_cobrar=0.00 comision=29.30 descasado=pendiente comision_despues=0.00';
  v_m   uuid;
  v_op  jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (94, 'el cobro con tarjeta neto de comisión: el cobro por el bruto y la comisión a 6130', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660941, current_setting('mx6.obra'), 'C6-94', d + 5, 1000.00, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 8, 'monto', '970.70', 'id', 'C6QB1', 'nombre', 'INTUIT 45001234 DEPOSIT',
                                 'memo', 'QB PAYMENTS'))),
            '1098', 'c6-pruebas-qbpayments.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6QB1');
    select o into v_op from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m and o->>'llamar' = 'fn_banco_cobrar' and o->'args'->'p_aplicaciones' @> '[{"factura_id": -660941}]'
       and exists (select 1 from jsonb_array_elements(o->'args'->'p_aplicaciones') a where a ? 'comision')
     limit 1;
    v_obt := 'opcion=' || coalesce((select a->>'comision' from jsonb_array_elements(v_op->'args'->'p_aplicaciones') a where a ? 'comision'), '-');
    perform fn_banco_cobrar(v_m, v_op->'args'->'p_aplicaciones');
    v_obt := v_obt || format(' cobrado=%s por_cobrar=%s comision=%s', pg_temp.c6_est('1098', 'C6QB1'),
                             (select coalesce(sum(l.monto), 0) from asiento_lineas l
                               where l.partida_tabla = 'facturas' and l.partida_id = '-660941' and l.cuenta = fn_puente_cuenta_de('cxc')),
                             (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where a.origen_tabla = 'movimientos_banco' and a.origen_id = v_m::text and l.cuenta = '6130'));
    perform fn_banco_descasar(v_m, 'c6-pruebas: des-casar el cobro con comisión');
    v_obt := v_obt || format(' descasado=%s comision_despues=%s', (select m.estado from movimientos_banco m where m.id = v_m),
                             (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where l.cuenta = '6130'
                                 and (a.origen_id = v_m::text or a.reversa_a in (select x.id from asientos x where x.origen_id = v_m::text))));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (94, 'el cobro con tarjeta neto de comisión: el cobro por el bruto y la comisión a 6130', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 95. UNA CONCILIACIÓN CON LA FECHA MAL ESCRITA NO SE LLEVA LA CONFIRMADA:
--     con la reserva conciliada y confirmada al día 30 (sus tres intereses
--     casados), conciliar al día 14 (un error de dedo) no crea nada
--     (MX008: va detrás de la última confirmada) y la confirmada sigue con
--     sus tres casados; y una abierta hecha por error DESPUÉS se anula
--     desde el SQL Editor (fn_conciliacion_anular, con su motivo), con
--     rastro. Antes se creaba, se llevaba los casados de la confirmada (el
--     control en verde) y no había cómo quitarla.
do $$
declare
  v_obt text;
  v_esp text := 'confirmada=confirmada antes=MX008 creada=0 casados=3 anulada=0 rastro=DELETE';
  v_c   jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or current_setting('mx6.sig', true) = '' then
    insert into _pruebas values (95, 'una conciliación con la fecha mal escrita no se crea ni se lleva los casados; la abierta se anula',
                                 v_esp, 'omitida: falta el mes abierto o el siguiente', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 30, 1.23, jsonb_build_array(
              jsonb_build_object('tipo', 'INT', 'fecha', d + 4, 'monto', '0.40', 'id', 'C6F1', 'nombre', 'INTEREST PAYMENT'),
              jsonb_build_object('tipo', 'INT', 'fecha', d + 14, 'monto', '0.41', 'id', 'C6F2', 'nombre', 'INTEREST PAYMENT'),
              jsonb_build_object('tipo', 'INT', 'fecha', d + 24, 'monto', '0.42', 'id', 'C6F3', 'nombre', 'INTEREST PAYMENT'))),
            '1097', 'c6-pruebas-fecha-mal.ofx');
    perform fn_banco_casar_todo('1097');
    v_c := fn_conciliar('1097', d + 30, '1.23');
    v_obt := 'confirmada=' || (fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid)->>'estado');
    begin
      perform fn_conciliar('1097', d + 14, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || format(' antes=%s creada=%s casados=%s', v_x,
                             (select count(*) from conciliaciones c where c.cuenta = '1097' and c.fecha_corte = d + 14),
                             (select count(*) from v_conciliacion_partidas p
                               where p.cuenta = '1097' and p.fecha_corte = d + 30 and p.grupo = 'casado'));
    v_c := fn_conciliar('1097', d + 43, null);
    perform fn_conciliacion_anular((v_c->>'conciliacion')::uuid, 'c6-pruebas: la hice con la fecha equivocada');
    v_obt := v_obt || format(' anulada=%s rastro=%s', (select count(*) from conciliaciones c where c.cuenta = '1097' and c.fecha_corte = d + 43),
                             (select h.operacion from banco_historial h
                               where h.tabla = 'conciliaciones' and h.clave = v_c->>'conciliacion'
                               order by h.cambiado_el desc limit 1));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (95, 'una conciliación con la fecha mal escrita no se crea ni se lleva los casados; la abierta se anula',
                               v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 96. LA OBRA PROPUESTA ES LA DEL DÍA DE LA COMPRA, no la del día en que el
--     banco la posteó: la compra con la débito (sin DTUSER) del día 1,
--     posteada el día 3, con «MM/DD» en la nota, propone la obra con visita
--     el día 1 (no la del 3); sin la fecha en la nota, con visitas a dos
--     obras en esos días, no se adivina (y lo dice). Antes proponía la del
--     día del banco.
do $$
declare
  v_obt  text;
  v_esp  text;
  v_obra text := current_setting('mx6.obra', true);
  v_o2   text := current_setting('mx6.obra2', true);
  v_f1   date;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  v_esp := format('compra=%s sin_fecha=- dice=t', v_obra);
  if d is null or to_regclass('public.eventos') is null or v_o2 = v_obra then
    insert into _pruebas values (96, 'la obra propuesta es la de la visita del día de la compra, no la del banco', v_esp,
                                 'omitida: falta mes abierto, la tabla eventos o una segunda obra', null);
    return;
  end if;
  -- (un día del mes sin visitas de verdad, y el siguiente de ese: así las
  -- de la prueba son las únicas del día de la compra)
  select min(x.f) into v_f1 from generate_series(d + 1, d + 24, interval '1 day') g(t), lateral (select g.t::date as f) x
   where not exists (select 1 from eventos e where e.fecha between x.f and x.f + 2);
  if v_f1 is null then
    insert into _pruebas values (96, 'la obra propuesta es la de la visita del día de la compra, no la del banco', v_esp,
                                 'omitida: no hay tres días seguidos del mes sin visitas', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into eventos (id, fecha, titulo, proyecto_id, estado) overriding system value
    values (-660961, v_f1, 'c6-pruebas: visita', v_obra, 'programado'),
           (-660962, v_f1 + 2, 'c6-pruebas: otra visita', v_o2, 'programado');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', v_f1 + 2, 'monto', '-189.73', 'id', 'C6OB1', 'nombre', 'C6 LOWES #01234* TAMPA FL',
                                 'memo', to_char(v_f1, 'MM/DD') || ' C6 LOWES #01234* TAMPA FL CARD 9420'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', v_f1 + 2, 'monto', '-77.10', 'id', 'C6OB2',
                                 'nombre', 'C6 HOME DEPOT #6345 TAMPA FL'))),
            '1098', 'c6-pruebas-obra.qfx');
    perform fn_banco_casar_todo('1098');
    select format('compra=%s sin_fecha=%s dice=%s',
                  coalesce((select m.propuesta->'obra'->>'proyecto_id' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6OB1')), '-'),
                  coalesce((select m.propuesta->'obra'->>'proyecto_id' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6OB2')), '-'),
                  case when (select m.propuesta->>'texto' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6OB2'))
                            like '%elige la obra%' then 't' else 'f' end)
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (96, 'la obra propuesta es la de la visita del día de la compra, no la del banco', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 97. VOLVER A PEGAR c6 NO BORRA LO AJENO QUE DEPENDE DE SUS VISTAS: con una
--     vista de Edgar (o del CPA) sobre v_banco_saldos, la sección 0 la ve
--     (fn_banco_vistas_ajenas: el pegado para con MX000 sin tocar nada), y
--     quitar la vista del banco sin cascade no puede (2BP01). Antes el
--     pegado la borraba en silencio con «drop view … cascade».
do $$
declare
  v_obt text;
  v_esp text := 'ajenas=t drop=2BP01';
  v_x   text;
begin
  begin
    set local lock_timeout = '2s';
    execute 'create view public.c6_pruebas_vista as select * from public.v_banco_saldos';
    v_obt := 'ajenas=' || case when position('c6_pruebas_vista' in coalesce(fn_banco_vistas_ajenas(), '')) > 0 then 't' else 'f' end;
    begin
      execute 'drop view public.v_banco_saldos';
      v_x := 'se borró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' drop=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app lee v_banco_saldos (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (97, 'volver a pegar c6 no borra lo ajeno que depende de sus vistas', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 98. «NO ES SU TICKET» DICE QUE PIDE MOTIVO: en la propuesta de un cargo
--     clasificado cuyo ticket llegó después, el botón lleva pide_motivo y
--     el nombre del argumento (p_motivo), como las demás opciones que lo
--     piden; pulsado con sus argumentos y el motivo, queda descartado.
--     Antes no lo decía y, pulsado tal cual, fallaba.
do $$
declare
  v_obt text;
  v_esp text := 'pide=true:p_motivo pulsado=descartado';
  v_m   uuid;
  v_op  jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (98, '«no es su ticket» dice que pide motivo, y con él se descarta', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 6, 'fecha_usuario', d + 5, 'monto', '-64.20', 'id', 'C6NT1',
                                 'nombre', 'C6 FERRETERIA'))),
            null, 'c6-pruebas-no-es.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6NT1');
    perform fn_banco_clasificar(v_m, '[{"cuenta": "6400"}]'::jsonb);
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660981, 'total', 64.20, 'fecha', d + 5, 'proveedor', 'C6 FERRETERIA'));
    perform fn_banco_casar_todo('2100-9996');
    select o into v_op from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m and o->>'llamar' = 'fn_banco_duplicado' limit 1;
    v_obt := format('pide=%s:%s', coalesce(v_op->>'pide_motivo', 'f'), coalesce(v_op->'pide'->>0, '-'));
    perform fn_banco_duplicado((v_op->'args'->>'p_movimiento')::uuid, (v_op->'args'->>'p_es_el_mismo')::boolean,
                               'c6-pruebas: otra compra del mismo monto');
    v_obt := v_obt || ' pulsado=' || case when (select m.propuesta ? 'descartados' from movimientos_banco m where m.id = v_m)
                                          then 'descartado' else '-' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (98, '«no es su ticket» dice que pide motivo, y con él se descarta', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 99. EL MOTIVO DE UNA PARTIDA DE LA APERTURA QUE SIGUE EN TRÁNSITO PASA AL
--     MES SIGUIENTE: el cheque viejo de QuickBooks que nadie cobra pide su
--     motivo en octubre (se dice y se confirma); en noviembre la partida
--     sigue ahí CON ese motivo (dice de dónde lo heredó) y la conciliación
--     se confirma sin pedirlo otra vez. Antes cada mes lo volvía a pedir.
do $$
declare
  v_obt text;
  v_esp text := 'octubre=1 confirmada=confirmada noviembre=0 heredado=t confirmada2=confirmada';
  v_c   jsonb;
  v_id  uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or d <> fn_puente_corte() or current_setting('mx6.sig', true) = ''
     or not exists (select 1 from periodos where tipo = 'apertura') then
    insert into _pruebas values (99, 'el motivo de una partida de la apertura que sigue en tránsito pasa al mes siguiente', v_esp,
                                 'omitida: el mes abierto más antiguo no es el primero después del corte, o falta el siguiente o la apertura',
                                 null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_apertura_minima();
    v_c := fn_conciliacion_apertura('1098', '150.00', jsonb_build_array(
             jsonb_build_object('fecha', (d - 78)::text, 'monto', '-150.00', 'cheque', '988',
                                'descripcion', 'c6-pruebas: cheque 988 que nadie cobra')));
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    v_c := fn_conciliar('1098', d + 30, '150.00');
    v_id := (v_c->>'conciliacion')::uuid;
    v_obt := 'octubre=' || coalesce(v_c->>'n_pide_motivo', '-');
    perform fn_conciliacion_partida((select p.id from conciliacion_partidas p where p.conciliacion_id = v_id and p.monto = -150.00),
                                    'cargo_en_circulacion', 'c6-pruebas: cheque viejo; se anula en diciembre si no aparece');
    v_obt := v_obt || ' confirmada=' || (fn_conciliacion_confirmar(v_id)->>'estado');
    v_c := fn_conciliar('1098', d + 60, '150.00');
    v_id := (v_c->>'conciliacion')::uuid;
    v_obt := v_obt || format(' noviembre=%s heredado=%s confirmada2=%s', coalesce(v_c->>'n_pide_motivo', '-'),
                             case when (select p.motivo from conciliacion_partidas p where p.conciliacion_id = v_id and p.monto = -150.00)
                                       like 'c6-pruebas: cheque viejo%' then 't' else 'f' end,
                             fn_conciliacion_confirmar(v_id)->>'estado');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (99, 'el motivo de una partida de la apertura que sigue en tránsito pasa al mes siguiente', v_esp,
                               coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 100. UN TICKET A CUENTA DE UN PROVEEDOR NO REHACE LAS PROPUESTAS QUE NO LO
--      MIRAN: con 25 cargos de la tarjeta sin nombre de proveedor ya
--      propuestos, un «Casar» sin nada nuevo no rehace ninguna, y tras un
--      ticket a cuenta del proveedor (5100 / 2010) tampoco (su firma lleva
--      lo que se les debe a los proveedores que nombra, no la 2010 entera);
--      el cheque sin nombre (que sí lo mira: su abono) sí se rehace. Antes
--      cada ticket a cuenta rehacía la propuesta de todos los cargos.
do $$
declare
  v_obt text;
  v_esp text := 'primera=25 sin_nada=0 tras_el_ticket=0 cheque=1';
  v_x   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (100, 'un ticket a cuenta de un proveedor no rehace las propuestas que no lo miran', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 25, null,
              (select jsonb_agg(jsonb_build_object('tipo', 'DEBIT', 'fecha', d + (g % 20), 'monto', to_char(-((g * 37) % 400 + 1) - 0.13, 'FM999990.00'),
                                                   'id', 'C6FI' || g, 'nombre', 'C6 SHELL OIL ' || g) order by g)
                 from generate_series(1, 25) g)),
            null, 'c6-pruebas-firma.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 25, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 20, 'monto', '-4321.09', 'id', 'C6FICH', 'nombre', 'CHECK 7077',
                                 'cheque', '7077'))),
            '1098', 'c6-pruebas-firma-cheque.qfx');
    v_x := fn_banco_casar_todo('2100-9996');
    v_obt := 'primera=' || (v_x->>'propuestas');
    v_x := fn_banco_casar_todo('2100-9996');
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || ' sin_nada=' || (v_x->>'propuestas');
    perform pg_temp.c6_recibo(jsonb_build_object('id', -661001, 'total', 123.45, 'fecha', d + 4, 'metodo_pago', 'cuenta_proveedor'));
    v_x := fn_banco_casar_todo('2100-9996');
    v_obt := v_obt || ' tras_el_ticket=' || (v_x->>'propuestas');
    v_x := fn_banco_casar_todo('1098');
    v_obt := v_obt || ' cheque=' || (v_x->>'propuestas');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (100, 'un ticket a cuenta de un proveedor no rehace las propuestas que no lo miran', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 101. EL PAGO DE LA TARJETA DE FIN DE MES NO PARTE SU ESTADO DE CUENTA
--      (ronda 4): el banco ya conciliado y confirmado al día 30; la
--      tarjeta, cuyo estado de cuenta corta ese mismo día 30, abona el pago
--      el 30 y el banco lo cobra el 32. Fechar el asiento el 31 (el día
--      siguiente a la confirmada) dejaría partida la conciliación de la
--      tarjeta: «Desde 1098» es MX008 y dice qué reabrir, R3 no lo casa
--      solo, la propuesta lo dice (bloqueo) y la conciliación de la
--      tarjeta, en «falta», manda a reabrir. Antes se fechaba el 31 y la
--      tarjeta cuadraba en 0.00 sin poder confirmarse nunca, con un
--      «cásalos o clasifícalos» de algo ya casado.
do $$
declare
  v_obt text;
  v_esp text := 'desde=MX008:reabre bloqueo=t r3=pendiente/pendiente falta=reabrir';
  v_c   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or current_setting('mx6.sig', true) = '' then
    insert into _pruebas values (101, 'el pago de la tarjeta de fin de mes no parte su estado de cuenta: dice qué reabrir', v_esp,
                                 'omitida: falta el mes abierto o el siguiente', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 30, -15.00, jsonb_build_array(
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 8, 'monto', '-15.00', 'id', 'C6FM1', 'nombre', 'MONTHLY SERVICE FEE'))),
            '1098', 'c6-pruebas-fm-oct.qfx');
    perform fn_banco_casar_todo('1098');
    v_c := fn_conciliar('1098', d + 30, '-15.00');
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    -- La tarjeta corta el día 30 y abona el pago ese día.
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d + 1, d + 30, -500.00, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 30, 'monto', '500.00', 'id', 'C6FM2', 'nombre', 'ONLINE PAYMENT - THANK YOU'))),
            null, 'c6-pruebas-fm-tarjeta.qfx');
    perform fn_banco_casar_todo('2100-9996');
    begin
      perform fn_banco_transferencia(pg_temp.c6_mov('2100-9996', 'C6FM2'), '1098');
      v_obt := 'desde=entró';
    exception when others then
      v_obt := 'desde=' || sqlstate || case when sqlerrm like '%Reabre la de 1098 al ' || (d + 30) || '%' then ':reabre' else ':' || left(sqlerrm, 120) end;
    end;
    v_obt := v_obt || ' bloqueo=' || (select case when m.propuesta ? 'bloqueo' then 't' else 'f' end
                                       from movimientos_banco m where m.id = pg_temp.c6_mov('2100-9996', 'C6FM2'));
    -- El banco lo cobra el 32 (el mes siguiente): R3 no los casa solo.
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 31, d + 35, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 32, 'monto', '-500.00', 'id', 'C6FM3', 'nombre', 'AMERICAN EXPRESS ACH PMT'))),
            '1098', 'c6-pruebas-fm-nov.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || format(' r3=%s/%s', split_part(pg_temp.c6_est('1098', 'C6FM3'), ':', 1),
                             split_part(pg_temp.c6_est('2100-9996', 'C6FM2'), ':', 1));
    v_c := fn_conciliar('2100-9996', d + 30, '-500.00');
    v_obt := v_obt || ' falta=' || case when v_c->>'falta' like '%reabras%' then 'reabrir' else coalesce(v_c->>'falta', '-') end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (101, 'el pago de la tarjeta de fin de mes no parte su estado de cuenta: dice qué reabrir', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 102. UN DEPÓSITO QUE NO CUADRA AL CENTAVO CON SU COBRO YA ANOTADO
--      (ronda 4): el cheque anotado por 2,500.00 que el banco deposita por
--      2,050.00 se propone primero («deposito_otro_cobro»): registrar otro
--      cobro pide su porqué (MX008), y se corrige casándolo con él
--      («corrige», con su motivo: el cobro se anula y se registra el bueno
--      con este depósito). El cobro con tarjeta anotado por el bruto y
--      depositado neto casa con él y su comisión (29.30 a 6130). Y un cobro
--      que lleva más de 10 días sin su depósito pide su motivo en la
--      conciliación. Antes salía «sin cobro registrado», la única opción era
--      la factura de otro cliente y el cobro anotado quedaba en tránsito
--      para siempre.
do $$
declare
  v_obt  text;
  v_esp  text := 'propuesta=deposito_otro_cobro:corrige cobrar=MX008 sin_motivo=22023 corrige=casado:cobro anulado=t '
                 'neto=casado:cobro comision=29.30 pide=1';
  v_obra text := current_setting('mx6.obra', true);
  v_c1   uuid;
  v_c2   uuid;
  v_pos  bigint;
  v_c    jsonb;
  v_m1   uuid;
  v_m2   uuid;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (102, 'un depósito de otro monto que su cobro anotado casa con él (corrige o comisión)', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660721, v_obra, 'C6-721', d + 1, 2500.00, 0), (-660722, v_obra, 'C6-722', d + 1, 1000.00, 0),
           (-660723, v_obra, 'C6-723', d + 1, 800.00, 0);
    v_c1 := (fn_cobro_registrar(jsonb_build_object('fecha', (d + 3)::text, 'monto', '2500.00', 'cuenta', '1098', 'medio', 'cheque',
              'referencia', 'C6-5521', 'duplicado_confirmado', 'c6-pruebas',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -660721, 'monto', '2500.00'))))->>'cobro')::uuid;
    v_c2 := (fn_cobro_registrar(jsonb_build_object('fecha', (d + 9)::text, 'monto', '1000.00', 'cuenta', '1098', 'medio', 'tarjeta',
              'referencia', 'C6-TJ1', 'duplicado_confirmado', 'c6-pruebas',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -660722, 'monto', '1000.00'))))->>'cobro')::uuid;
    -- (el que no llega: lleva más de 10 días al corte)
    perform fn_cobro_registrar(jsonb_build_object('fecha', (d + 12)::text, 'monto', '800.00', 'cuenta', '1098', 'medio', 'cheque',
              'referencia', 'C6-7777', 'duplicado_confirmado', 'c6-pruebas',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -660723, 'monto', '800.00'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 30, 3020.70, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 4, 'monto', '2050.00', 'id', 'C6OC1', 'nombre', 'REMOTE ONLINE DEPOSIT 5'),
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 10, 'monto', '970.70', 'id', 'C6OC2', 'nombre', 'QBPAYMENTS DEPOSIT 778812'))),
            '1098', 'c6-pruebas-otro-cobro.qfx');
    perform fn_banco_casar_todo('1098');
    v_m1 := pg_temp.c6_mov('1098', 'C6OC1');
    v_m2 := pg_temp.c6_mov('1098', 'C6OC2');
    select format('propuesta=%s:%s', m.propuesta->>'motivo',
                  case when m.propuesta->'opciones'->0->'args'->'p_con' ? 'corrige' then 'corrige' else '-' end)
      into v_obt from movimientos_banco m where m.id = v_m1;
    perform pg_temp.c6_como('dueno');
    begin
      perform fn_banco_cobrar(v_m1, jsonb_build_array(jsonb_build_object('factura_id', -660721, 'monto', '2050.00')));
      v_obt := v_obt || ' cobrar=entró';
    exception when others then v_obt := v_obt || ' cobrar=' || sqlstate;
    end;
    begin
      perform fn_banco_casar_con(v_m1, jsonb_build_object('cobro', v_c1, 'corrige', true));
      v_obt := v_obt || ' sin_motivo=entró';
    exception when others then v_obt := v_obt || ' sin_motivo=' || sqlstate;
    end;
    perform fn_banco_casar_con(v_m1, jsonb_build_object('cobro', v_c1, 'corrige', true),
                               'c6-pruebas: el cheque era de 2,050.00');
    perform fn_banco_casar_con(v_m2, jsonb_build_object('cobro', v_c2, 'comision', '29.30'));
    execute 'reset role';
    perform set_config('request.jwt.claims', '', true);
    v_c := fn_conciliar('1098', d + 30, '3020.70');
    v_obt := v_obt || format(' corrige=%s anulado=%s neto=%s comision=%s pide=%s', pg_temp.c6_est('1098', 'C6OC1'),
                             (select case when c.estado <> 'vigente' then 't' else 'f' end from cobros c where c.id = v_c1),
                             pg_temp.c6_est('1098', 'C6OC2'),
                             (select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where a.cadena_pos > v_pos and l.cuenta = '6130'),
                             v_c->>'n_pide_motivo');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (102, 'un depósito de otro monto que su cobro anotado casa con él (corrige o comisión)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 103. EL CHEQUE QUE REBOTA DE UN DEPÓSITO DE DOS PARA LA MISMA FACTURA
--      (ronda 4): un depósito de 7,000.00 cobra una parte de la factura de
--      10,000.00 (los dos cheques del cliente, juntos); rebota uno de
--      3,000.00: la bandeja propone devolverlo y fn_banco_devolver, con lo
--      que dice el botón, devuelve el cobro y registra otra vez lo que no
--      rebotó (4,000.00) a la misma factura: quedan 6,000.00 por cobrar.
--      Antes pedía «su aplicación» y, con la única que había (la de
--      7,000.00), se negaba: no había camino.
do $$
declare
  v_obt  text;
  v_esp  text := 'deposito=casado:cobro rebote=pendiente:devolucion devuelto=casado:devolucion por_cobrar=6000.00';
  v_obra text := current_setting('mx6.obra', true);
  v_m    uuid;
  v_o    jsonb;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (103, 'el cheque que rebota de un depósito de dos para la misma factura se devuelve', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660731, v_obra, 'C6-731', d + 1, 10000.00, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 4000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 9, 'monto', '7000.00', 'id', 'C6RB1', 'nombre', 'REMOTE ONLINE DEPOSIT 4'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 13, 'monto', '-3000.00', 'id', 'C6RB2', 'nombre', 'DEPOSITED ITEM RETURNED'))),
            '1098', 'c6-pruebas-rebote-misma.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6RB1');
    select o into v_o from movimientos_banco m, jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m and o->>'llamar' = 'fn_banco_cobrar'
       and exists (select 1 from jsonb_array_elements(o->'args'->'p_aplicaciones') a where a->>'factura_id' = '-660731')
     limit 1;
    perform fn_banco_cobrar(v_m, v_o->'args'->'p_aplicaciones');
    perform fn_banco_casar_todo('1098');
    v_obt := format('deposito=%s rebote=%s', pg_temp.c6_est('1098', 'C6RB1'), pg_temp.c6_est('1098', 'C6RB2'));
    v_m := pg_temp.c6_mov('1098', 'C6RB2');
    select o into v_o from movimientos_banco m, jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m and o->>'llamar' = 'fn_banco_devolver' limit 1;
    perform fn_banco_devolver(v_m, (v_o->'args'->>'p_cobro')::uuid, v_o->'args'->>'p_motivo');
    v_obt := v_obt || format(' devuelto=%s por_cobrar=%s', pg_temp.c6_est('1098', 'C6RB2'),
                             (select coalesce(sum(l.monto), 0) from asiento_lineas l
                               where l.partida_tabla = 'facturas' and l.partida_id = '-660731'
                                 and l.cuenta = fn_puente_cuenta_de('cxc')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (103, 'el cheque que rebota de un depósito de dos para la misma factura se devuelve', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 104. LA CUOTA REGISTRADA ANTES QUE EL BANCO, COBRADA POR OTRO MONTO
--      (ronda 4): Edgar registra la cuota del mes (1,029.33) el día que
--      vence; el banco cobra 1,050.00 (la pagó redondeada). La bandeja la
--      nombra («cuota_prestamo», primero casar con ESA cuota y la
--      diferencia a capital); otra cuota a mano sin motivo es MX008; con el
--      botón, la registrada se anula y queda la del banco: 182.99 de
--      interés, 867.01 a capital, y se deben 30,548.25. Antes no casaba si
--      no era al centavo, la bandeja no la nombraba y sus opciones ponían
--      la cuota dos veces.
do $$
declare
  v_obt  text;
  v_esp  text := 'propuesta=cuota_prestamo:cuota otra=MX008 boton=casado:cuota_prestamo interes=182.99 capital=867.01 saldo=30548.25';
  v_p    uuid;
  v_m    uuid;
  v_o    jsonb;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (104, 'la cuota registrada antes que el banco, cobrada por otro monto, casa con ella', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_p := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS FORD', 'descripcion', 'F-150 de prueba',
             'principal', '52000.00', 'tasa_anual', '6.99', 'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15,
             'plazo_meses', 60, 'saldo_inicial', '31415.26', 'saldo_inicial_al', (d - 1)::text, 'cuenta_banco', '1098',
             'descriptor', 'C6 PRUEBAS FORD'))->>'id')::uuid;
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: el préstamo (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '31415.26'),
                                  jsonb_build_object('cuenta', '2520', 'monto', '-31415.26'))));
    perform fn_prestamo_cuota(v_p, null, d + 14, '1029.33');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 14, 'monto', '-1050.00', 'id', 'C6CQ1', 'nombre', 'C6 PRUEBAS FORD PMT'))),
            '1098', 'c6-pruebas-cuota-otro-monto.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6CQ1');
    select format('propuesta=%s:%s', m.propuesta->>'motivo',
                  case when m.propuesta->'opciones'->0->'args'->'p_con' ? 'cuota' then 'cuota' else '-' end),
           m.propuesta->'opciones'->0
      into v_obt, v_o from movimientos_banco m where m.id = v_m;
    begin
      perform fn_prestamo_cuota(v_p, v_m, null, null, '1050.00', '0.00');
      v_obt := v_obt || ' otra=entró';
    exception when others then v_obt := v_obt || ' otra=' || sqlstate;
    end;
    perform fn_banco_casar_con(v_m, v_o->'args'->'p_con');
    v_obt := v_obt || ' boton=' || pg_temp.c6_est('1098', 'C6CQ1');
    v_obt := v_obt || (select format(' interes=%s capital=%s', q.interes, q.capital) from prestamo_cuotas q
                        where q.movimiento_id = v_m and q.anulada_el is null)
                   || ' saldo=' || (select x.saldo from v_prestamos x where x.prestamo_id = v_p);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (104, 'la cuota registrada antes que el banco, cobrada por otro monto, casa con ella', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 105. LA CUOTA DEL MES MÁS UN EXTRA A CAPITAL EN EL MISMO CARGO (ronda 4):
--      el banco cobra 1,529.33 (la cuota de 1,029.33 más 500.00 a
--      capital). Se propone como tal («Cuota … más 500.00 a capital»,
--      primero) y, con el botón, la fórmula pone el interés del mes
--      (182.99) y lo demás a capital (1,346.34): se deben 30,068.92. Antes
--      se trataba como un abono: la fórmula se negaba y el único camino sin
--      statement era todo a capital, sin el interés del mes.
do $$
declare
  v_obt  text;
  v_esp  text := 'propuesta=cuota_prestamo:extra boton=casado:cuota_prestamo interes=182.99 capital=1346.34 saldo=30068.92';
  v_p    uuid;
  v_m    uuid;
  v_o    jsonb;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (105, 'la cuota del mes más un extra a capital en el mismo cargo: interés del mes y lo demás a capital',
                                 v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_p := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS FORD', 'descripcion', 'F-150 de prueba',
             'principal', '52000.00', 'tasa_anual', '6.99', 'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15,
             'plazo_meses', 60, 'saldo_inicial', '31415.26', 'saldo_inicial_al', (d - 1)::text, 'cuenta_banco', '1098',
             'descriptor', 'C6 PRUEBAS FORD'))->>'id')::uuid;
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: el préstamo (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '31415.26'),
                                  jsonb_build_object('cuenta', '2520', 'monto', '-31415.26'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 14, 'monto', '-1529.33', 'id', 'C6CX1', 'nombre', 'C6 PRUEBAS FORD PMT'))),
            '1098', 'c6-pruebas-cuota-extra.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6CX1');
    select format('propuesta=%s:%s', m.propuesta->>'motivo',
                  case when m.propuesta->'opciones'->0->>'texto' like '%más 500.00 a capital%' then 'extra' else '-' end),
           m.propuesta->'opciones'->0
      into v_obt, v_o from movimientos_banco m where m.id = v_m;
    perform fn_prestamo_cuota((v_o->'args'->>'p_prestamo')::uuid, (v_o->'args'->>'p_movimiento')::uuid,
                              (v_o->'args'->>'p_fecha')::date, v_o->'args'->>'p_monto', v_o->'args'->>'p_capital',
                              v_o->'args'->>'p_interes', v_o->'args'->>'p_motivo');
    v_obt := v_obt || ' boton=' || pg_temp.c6_est('1098', 'C6CX1');
    v_obt := v_obt || (select format(' interes=%s capital=%s', q.interes, q.capital) from prestamo_cuotas q
                        where q.movimiento_id = v_m and q.anulada_el is null)
                   || ' saldo=' || (select x.saldo from v_prestamos x where x.prestamo_id = v_p);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (105, 'la cuota del mes más un extra a capital en el mismo cargo: interés del mes y lo demás a capital',
                               v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 106. EL TICKET REPARTIDO ENTRE DOS OBRAS QUE LLEGA DESPUÉS DE CLASIFICAR
--      SU CARGO (ronda 4): la misma foto en dos recibos (60.00 y 47.00) que
--      suman el cargo de 107.00 ya clasificado. La bandeja dice «llegó su
--      ticket, repartido entre…» y su primer botón es «Es su ticket
--      (repartido…)», con las dos partes; el control lo pone en rojo. Si
--      Edgar dijo que no era, la conciliación de la tarjeta nombra el cargo
--      que suman (no «corrige su total»), y con el botón el cargo casa con
--      las dos partes: el costo queda una vez (107.00). Antes cada parte era
--      un ticket de «OTRO total», «Es su ticket» se negaba y el único botón
--      dejaba el gasto dos veces (214.00).
do $$
declare
  v_obt  text;
  v_esp  text := 'llego=repartido boton=repartido control=f no_es=casado:clasificado conciliacion=2 cambiado=casado:recibo costo=107.00';
  v_obra text := current_setting('mx6.obra', true);
  v_m    uuid;
  v_o    jsonb;
  v_pos  bigint;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (106, 'el ticket repartido entre obras que llega después de clasificar se cambia entero', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 30, 107.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'monto', '-107.00', 'id', 'C6TR1', 'nombre', 'THE HOME DEPOT #6345'))),
            null, 'c6-pruebas-repartido.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6TR1');
    perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', v_obra)));
    -- Llega su ticket: una foto, dos obras.
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660761, 'total', 60.00, 'fecha', d + 4, 'proveedor', 'THE HOME DEPOT',
                                                 'ruta', 'recibos/c6-pruebas/repartido.jpg', 'proyecto_id', v_obra));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660762, 'total', 47.00, 'fecha', d + 4, 'proveedor', 'THE HOME DEPOT',
                                                 'ruta', 'recibos/c6-pruebas/repartido.jpg',
                                                 'proyecto_id', current_setting('mx6.obra2', true)));
    perform fn_banco_casar_todo('2100-9996');
    select format('llego=%s boton=%s', case when m.propuesta->>'motivo' = 'llego_su_ticket' and m.propuesta->>'texto' like '%repartido entre%'
                                            then 'repartido' else coalesce(m.propuesta->>'motivo', '-') end,
                  case when m.propuesta->'opciones'->0->>'texto' like 'Es su ticket (repartido%'
                            and jsonb_array_length(m.propuesta->'opciones'->0->'args'->'p_con'->'lineas') = 2 then 'repartido' else '-' end),
           m.propuesta->'opciones'->0
      into v_obt, v_o from movimientos_banco m where m.id = v_m;
    v_obt := v_obt || ' control=' || pg_temp.c6_cuadre('cuadre: ningún ticket después de clasificar', current_setting('mx6.mes'), v_m::text);
    -- Edgar dice que no es (mal aconsejado): la conciliación nombra el cargo que suman.
    perform fn_banco_duplicado(v_m, false, 'c6-pruebas: creí que era otra compra');
    v_obt := v_obt || ' no_es=' || pg_temp.c6_est('2100-9996', 'C6TR1');
    perform fn_conciliar('2100-9996', d + 30, '107.00');
    v_obt := v_obt || ' conciliacion=' || (select count(*) from v_conciliacion_partidas p
                                            where p.cuenta = '2100-9996' and p.fecha_corte = d + 30 and p.grupo <> 'casado'
                                              and p.explicacion like '%repartido entre obras%' and p.explicacion like '%' || v_m::text || '%');
    perform fn_banco_casar_con(v_m, v_o->'args'->'p_con', 'c6-pruebas: sí era su ticket');
    v_obt := v_obt || format(' cambiado=%s costo=%s', pg_temp.c6_est('2100-9996', 'C6TR1'),
                             (select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where a.cadena_pos > v_pos and l.cuenta = '5100'
                                 and not exists (select 1 from asientos r where r.reversa_a = a.id)
                                 and a.camino not in ('reverso', 'reverso_automatico')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (106, 'el ticket repartido entre obras que llega después de clasificar se cambia entero', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 107. EL CHEQUE DEL DEPÓSITO EN TRÁNSITO DE LA APERTURA QUE REBOTA
--      (ronda 4): la factura #C6-771 se cobró en QuickBooks (antes del
--      corte) y su cheque era el depósito en tránsito del 30-sep; el banco
--      lo trae el día 1 (casa con la partida) y lo devuelve el día 8. Sin
--      cobro en la app, la bandeja propone que vuelva a quedar por cobrar
--      (su cuenta por cobrar, con su partida y su motivo prellenado), y con
--      ese botón la factura debe otra vez 3,200.00 y el ingreso no se toca.
--      Antes la bandeja no daba opciones, la cuenta por cobrar estaba
--      prohibida y lo único que entraba era contra el ingreso, con la
--      factura cobrada.
do $$
declare
  v_obt  text;
  v_esp  text := 'deposito=casado:apertura rebote=pendiente:devolucion opcion=qb boton=casado:clasificado por_cobrar=3200.00 ingreso=0';
  v_obra text := current_setting('mx6.obra', true);
  v_c    jsonb;
  v_m    uuid;
  v_o    jsonb;
  v_pos  bigint;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or d <> fn_puente_corte() or not exists (select 1 from periodos where tipo = 'apertura') then
    insert into _pruebas values (107, 'el cheque de la apertura (una factura de QuickBooks) que rebota vuelve a quedar por cobrar',
                                 v_esp, 'omitida: el mes abierto más antiguo no es el primero después del corte, o falta la apertura',
                                 null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_apertura_minima();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion, pagada, qb_id) overriding system value
    values (-660771, v_obra, 'C6-771', d - 15, 3200.00, 0, true, 'C6-QB-771');
    v_c := fn_conciliacion_apertura('1098', '-3200.00', jsonb_build_array(
             jsonb_build_object('fecha', (d - 1)::text, 'monto', '3200.00',
                                'descripcion', 'c6-pruebas: depósito del 30, el cheque de la #C6-771')));
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, -3200.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d, 'monto', '3200.00', 'id', 'C6QB1', 'nombre', 'REMOTE ONLINE DEPOSIT 1'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 7, 'monto', '-3200.00', 'id', 'C6QB2', 'nombre', 'DEPOSITED ITEM RETURNED'))),
            '1098', 'c6-pruebas-rebote-qb.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6QB2');
    select format('deposito=%s rebote=%s opcion=%s', pg_temp.c6_est('1098', 'C6QB1'), pg_temp.c6_est('1098', 'C6QB2'),
                  case when m.propuesta->'opciones'->0->>'texto' like 'Rebotó el cheque de la factura #C6-771%' then 'qb' else '-' end),
           m.propuesta->'opciones'->0
      into v_obt, v_o from movimientos_banco m where m.id = v_m;
    perform fn_banco_clasificar(v_m, v_o->'args'->'p_lineas', v_o->'args'->>'p_motivo');
    v_obt := v_obt || format(' boton=%s por_cobrar=%s ingreso=%s', pg_temp.c6_est('1098', 'C6QB2'),
                             (select coalesce(sum(l.monto), 0) from asiento_lineas l
                               where l.partida_tabla = 'facturas' and l.partida_id = '-660771'
                                 and l.cuenta = fn_puente_cuenta_de('cxc')),
                             (select count(*) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               join cuentas c on c.codigo = l.cuenta
                               where a.cadena_pos > v_pos and c.tipo in ('ingreso', 'otro_ingreso')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (107, 'el cheque de la apertura (una factura de QuickBooks) que rebota vuelve a quedar por cobrar',
                               v_esp, coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 108. EL LOTE DEL PROCESADOR DE TARJETAS (ronda 4): QuickBooks Payments
--      deposita JUNTOS los cobros con tarjeta de dos facturas (1,000.00 y
--      2,000.00), netos de sus comisiones: 2,912.40. La bandeja propone las
--      dos facturas con la comisión que se quedó (87.60 a 6130), y con ese
--      botón las dos quedan cobradas. Antes solo se probaba una factura: el
--      lote salía sin opciones que lo explicaran y el texto llevaba al
--      anticipo (las dos facturas seguían por cobrar).
do $$
declare
  v_obt  text;
  v_esp  text := 'opcion=t boton=casado:cobro por_cobrar=0.00/0.00 comision=87.60';
  v_obra text := current_setting('mx6.obra', true);
  v_m    uuid;
  v_o    jsonb;
  v_pos  bigint;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (108, 'el lote del procesador (dos facturas netas de comisión) se propone y las cobra', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660781, v_obra, 'C6-781', d + 8, 1000.00, 0), (-660782, v_obra, 'C6-782', d + 8, 2000.00, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 2912.40, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 9, 'monto', '2912.40', 'id', 'C6LP1', 'nombre', 'QBPAYMENTS DEPOSIT 778900'))),
            '1098', 'c6-pruebas-lote.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6LP1');
    select o into v_o from movimientos_banco m, jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m and o->>'llamar' = 'fn_banco_cobrar'
       and (select count(*) from jsonb_array_elements(o->'args'->'p_aplicaciones') a where a->>'factura_id' in ('-660781', '-660782')) = 2
       and exists (select 1 from jsonb_array_elements(o->'args'->'p_aplicaciones') a where a->>'comision' = '87.60')
     limit 1;
    v_obt := 'opcion=' || case when v_o is not null then 't' else 'f' end;
    perform fn_banco_cobrar(v_m, v_o->'args'->'p_aplicaciones');
    v_obt := v_obt || format(' boton=%s por_cobrar=%s comision=%s', pg_temp.c6_est('1098', 'C6LP1'),
                             (select string_agg(coalesce((select sum(l.monto) from asiento_lineas l
                                                           where l.partida_tabla = 'facturas' and l.partida_id = f.id::text
                                                             and l.cuenta = fn_puente_cuenta_de('cxc')), 0)::text, '/' order by f.id desc)
                                from facturas f where f.id in (-660781, -660782)),
                             (select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where a.cadena_pos > v_pos and l.cuenta = '6130'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (108, 'el lote del procesador (dos facturas netas de comisión) se propone y las cobra', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 109. EL BANCO TRABAJADO ANTES DE CONCILIAR LA APERTURA (ronda 4): con la
--      apertura posteada (una de prueba, con el banco 1098 en ella: sale
--      «omitida» si la de verdad ya está posteada) y la conciliación de
--      apertura de 1098 por hacer,
--      el cheque 1038 del día 2 y el depósito del día 1 pueden ser sus
--      partidas en tránsito: la propuesta lo avisa y clasificarlo sin
--      motivo es MX008. Clasificados y cobrados igual (con su motivo), la
--      conciliación de apertura con esas dos partidas las nombra como ya
--      casadas con otra cosa (n_dudosas 2) y no se confirma; «no es» con
--      su motivo (fn_banco_duplicado, false) quita una. Antes nada lo
--      decía, la partida solo casaba con lo pendiente y octubre se
--      confirmaba con el cheque dos veces al costo y un anticipo falso.
do $$
declare
  v_obt  text;
  v_esp  text := 'aviso=t sin_motivo=MX008 cheque=casado:clasificado deposito=casado:cobro dudosas=2 confirmar=MX008 no_es=1';
  v_obra text := current_setting('mx6.obra', true);
  v_c    jsonb;
  v_ch   uuid;
  v_dep  uuid;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or d <> fn_puente_corte()
     or (select p.estado from periodos p where p.tipo = 'apertura' order by p.desde limit 1) is distinct from 'abierto'
     or exists (select 1 from asientos a where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                  and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    insert into _pruebas values (109, 'lo trabajado antes de conciliar la apertura se avisa, pide motivo y la apertura lo nombra', v_esp,
                                 'omitida: la apertura ya está posteada (o cerrada), o el mes abierto más antiguo no es el primero '
                                 'después del corte: prueba lo de antes de conciliarla', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    -- (la apertura, con el banco de prueba en ella: 1,950.00 = 0.00 del banco
    -- + el depósito del 30 en tránsito − el cheque 1038 en circulación)
    perform fn_postear(jsonb_build_object('tipo', 'apertura',
      'fecha', (select p.hasta from periodos p where p.tipo = 'apertura' order by p.desde limit 1)::text,
      'descripcion', 'c6-pruebas: apertura con el banco de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '1950.00'),
                                  jsonb_build_object('cuenta', '3900', 'monto', '-1950.00'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 1950.00, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d, 'monto', '3200.00', 'id', 'C6AB1', 'nombre', 'DEPOSIT  ID NUMBER 778812'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 1, 'monto', '-1250.00', 'id', 'C6AB2', 'nombre', 'CHECK 1038',
                                 'cheque', '1038'))),
            '1098', 'c6-pruebas-antes-de-la-apertura.qfx');
    perform fn_banco_casar_todo('1098');
    v_dep := pg_temp.c6_mov('1098', 'C6AB1');
    v_ch := pg_temp.c6_mov('1098', 'C6AB2');
    v_obt := 'aviso=' || (select case when bool_and(m.propuesta ? 'aviso_apertura') then 't' else 'f' end
                            from movimientos_banco m where m.id in (v_dep, v_ch));
    begin
      perform fn_banco_clasificar(v_ch, jsonb_build_array(jsonb_build_object('cuenta', '5200', 'proyecto_id', v_obra)));
      v_obt := v_obt || ' sin_motivo=entró';
    exception when others then v_obt := v_obt || ' sin_motivo=' || sqlstate;
    end;
    perform fn_banco_clasificar(v_ch, jsonb_build_array(jsonb_build_object('cuenta', '5200', 'proyecto_id', v_obra)),
                                'c6-pruebas: creí que era de octubre');
    perform fn_banco_cobrar(v_dep, jsonb_build_array(jsonb_build_object('proyecto_id', v_obra, 'monto', '3200.00')),
                            'c6-pruebas: creí que era un anticipo');
    v_obt := v_obt || format(' cheque=%s deposito=%s', pg_temp.c6_est('1098', 'C6AB2'), pg_temp.c6_est('1098', 'C6AB1'));
    v_c := fn_conciliacion_apertura('1098', '0.00', jsonb_build_array(
             jsonb_build_object('fecha', (d - 4)::text, 'monto', '-1250.00', 'cheque', '1038', 'descripcion', 'c6-pruebas: cheque 1038'),
             jsonb_build_object('fecha', (d - 1)::text, 'monto', '3200.00', 'descripcion', 'c6-pruebas: depósito del 30')));
    v_obt := v_obt || ' dudosas=' || coalesce(v_c->>'n_dudosas', '-');
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_obt := v_obt || ' confirmar=entró';
    exception when others then v_obt := v_obt || ' confirmar=' || sqlstate;
    end;
    perform fn_banco_duplicado(v_dep, false, 'c6-pruebas: el depósito del 1 es otro dinero');
    v_obt := v_obt || ' no_es=' || coalesce(fn_conciliacion_apertura('1098', '0.00', jsonb_build_array(
             jsonb_build_object('fecha', (d - 4)::text, 'monto', '-1250.00', 'cheque', '1038', 'descripcion', 'c6-pruebas: cheque 1038'),
             jsonb_build_object('fecha', (d - 1)::text, 'monto', '3200.00', 'descripcion', 'c6-pruebas: depósito del 30')))->>'n_dudosas', '-');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (109, 'lo trabajado antes de conciliar la apertura se avisa, pide motivo y la apertura lo nombra', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 110. LA REGLA FIJA (R7) NO VUELVE A CASAR LO QUE EDGAR DES-CASÓ, Y CEDE
--      ANTE UNA PARTIDA DE LA APERTURA (ronda 4): la comisión del wire que
--      QuickBooks dejó en tránsito al 30-sep (la conciliación de apertura
--      de 1098) llega el día 1 como FEE: no se casa sola a 6130, se
--      propone su partida. Y el cargo mensual que R7 casó y Edgar des-casó
--      se queda pendiente en el «Casar» siguiente. Antes R7 la casaba al
--      gasto (el dinero dos veces) y, des-casada, la volvía a casar en el
--      acto (otro asiento y su reverso en cada vuelta).
do $$
declare
  v_obt text;
  v_esp text := 'apertura=pendiente:partida_apertura r7=casado descasado=pendiente otra_vuelta=pendiente';
  v_c   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or d <> fn_puente_corte() or not exists (select 1 from periodos where tipo = 'apertura') then
    insert into _pruebas values (110, 'R7 no vuelve a casar lo des-casado y cede ante una partida de la apertura', v_esp,
                                 'omitida: el mes abierto más antiguo no es el primero después del corte, o falta la apertura', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_apertura_minima();
    v_c := fn_conciliacion_apertura('1098', '25.00', jsonb_build_array(
             jsonb_build_object('fecha', (d - 1)::text, 'monto', '-25.00', 'descripcion', 'c6-pruebas: comisión del wire del 30-sep')));
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, -15.00, jsonb_build_array(
              jsonb_build_object('tipo', 'FEE', 'fecha', d, 'monto', '-25.00', 'id', 'C6R7A', 'nombre', 'ONLINE DOMESTIC WIRE FEE'),
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 8, 'monto', '-15.00', 'id', 'C6R7B', 'nombre', 'MONTHLY SERVICE FEE'))),
            '1098', 'c6-pruebas-r7.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := format('apertura=%s r7=%s', pg_temp.c6_est('1098', 'C6R7A'), split_part(pg_temp.c6_est('1098', 'C6R7B'), ':', 1));
    perform fn_banco_descasar(pg_temp.c6_mov('1098', 'C6R7B'), 'c6-pruebas: lo reviso a mano');
    v_obt := v_obt || ' descasado=' || split_part(pg_temp.c6_est('1098', 'C6R7B'), ':', 1);
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || ' otra_vuelta=' || split_part(pg_temp.c6_est('1098', 'C6R7B'), ':', 1);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (110, 'R7 no vuelve a casar lo des-casado y cede ante una partida de la apertura', v_esp,
                               coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 111. EL PRIMER ESTADO DE CUENTA SUBIDO A LA CUENTA EQUIVOCADA TIENE
--      VUELTA (ronda 4; el mismo hallazgo que el del grupo del importador,
--      arreglado aquí una vez): el QFX del banco 1098 (····1098) subido por
--      error como el primero de la reserva 1097 entra con su aviso («es el
--      primer estado de cuenta de 1097: el archivo dice ····1098 …»); el
--      mismo archivo a 1098 dice que ya entró, pero a 1097 (y cómo
--      retirarlo); fn_banco_archivo_retirar lo retira (sus movimientos,
--      ignorados; la comisión que R7 casó, reversada) y el archivo entra
--      a 1098 con lo suyo. Antes 1097 se quedaba con el saldo y el número
--      del otro banco, su comisión no se podía quitar y el archivo no
--      volvía a entrar («ya entró … no entra nada»).
do $$
declare
  v_obt text;
  v_esp text := 'aviso=t ya=1097 retirado=ignorado:2 de_nuevo=2 r7=casado gasto=15.00 reserva=0.00';
  v_x   jsonb;
  v_f   text;
  v_pos bigint;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (111, 'el primer estado de cuenta subido a la cuenta equivocada se retira y entra a la suya', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    v_f := pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 985.00, jsonb_build_array(
             jsonb_build_object('tipo', 'DEP', 'fecha', d + 3, 'monto', '1000.00', 'id', 'C6WA1', 'nombre', 'REMOTE ONLINE DEPOSIT 7'),
             jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 8, 'monto', '-15.00', 'id', 'C6WA2', 'nombre', 'MONTHLY SERVICE FEE')));
    v_x := fn_banco_importar_ofx(v_f, '1097', 'c6-pruebas-equivocada.qfx');
    v_obt := 'aviso=' || case when (v_x->'avisos')::text like '%primer estado de cuenta de 1097%' then 't' else 'f' end;
    perform fn_banco_casar_todo('1097');
    v_x := fn_banco_importar_ofx(v_f, '1098', 'c6-pruebas-equivocada.qfx');
    v_obt := v_obt || ' ya=' || case when (v_x->>'ya_estaba')::boolean and v_x->>'aviso' like '%pero a 1097, no a 1098%'
                                     then v_x->>'cuenta' else coalesce(v_x->>'aviso', '-') end;
    perform fn_banco_archivo_retirar((select a.id from archivos_banco a where a.cuenta = '1097' and a.nombre = 'c6-pruebas-equivocada.qfx'),
                                     'c6-pruebas: era el de 1098');
    v_obt := v_obt || ' retirado=' || (select string_agg(distinct m.estado, ',') || ':' || count(*) from movimientos_banco m
                                        where m.cuenta = '1097' and m.id_externo in ('C6WA1', 'C6WA2'));
    v_x := fn_banco_importar_ofx(v_f, '1098', 'c6-pruebas-equivocada.qfx');
    v_obt := v_obt || ' de_nuevo=' || coalesce(v_x->>'filas_nuevas', '-');
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || format(' r7=%s gasto=%s reserva=%s', split_part(pg_temp.c6_est('1098', 'C6WA2'), ':', 1),
                             (select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where a.cadena_pos > v_pos and l.cuenta = '6130'),
                             (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where a.cadena_pos > v_pos and l.cuenta = '1097'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (111, 'el primer estado de cuenta subido a la cuenta equivocada se retira y entra a la suya', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 112. LA DEVOLUCIÓN DE UNA COMPRA PAGADA CON LA DÉBITO (ronda 4): Home
--      Depot abona 45.10 en el banco 1098, donde se pagó con la débito el
--      ticket de la obra (5100); con facturas abiertas, la bandeja propone
--      primero la devolución contra la cuenta y la obra de ese ticket
--      («devolucion_compra»), y su botón entra sin motivo; ninguna factura
--      cambia. Antes salía como «pago parcial» de una factura de un cliente
--      y su botón le cobraba 45.10.
do $$
declare
  v_obt  text;
  v_esp  text;
  v_obra text := current_setting('mx6.obra', true);
  v_ob2  text := current_setting('mx6.obra2', true);
  v_m    uuid;
  v_o    jsonb;
  v_pos  bigint;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  v_esp := 'propuesta=devolucion_compra boton=casado:clasificado costo=5100:-45.10:' || coalesce(v_ob2, '-') || ' cobros=0';
  if d is null then
    insert into _pruebas values (112, 'la devolución de una compra pagada con la débito va contra su gasto, no a una factura', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660791, v_obra, 'C6-791', d + 1, 1000.00, 0);
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660792, 'total', 156.78, 'fecha', d + 7, 'proveedor', 'THE HOME DEPOT',
                                                 'metodo_pago', 'debito', 'proyecto_id', v_ob2));
    v_pos := (select coalesce(max(cadena_pos), 0) from asientos);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 45.10, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 12, 'monto', '45.10', 'id', 'C6DV1', 'nombre', 'HOME DEPOT #6345 TAMPA FL'))),
            '1098', 'c6-pruebas-devolucion-debito.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6DV1');
    select 'propuesta=' || coalesce(m.propuesta->>'motivo', '-'), m.propuesta->'opciones'->0
      into v_obt, v_o from movimientos_banco m where m.id = v_m;
    perform fn_banco_clasificar(v_m, v_o->'args'->'p_lineas', v_o->'args'->>'p_motivo');
    v_obt := v_obt || format(' boton=%s costo=%s cobros=%s', pg_temp.c6_est('1098', 'C6DV1'),
                             (select string_agg(l.cuenta || ':' || l.monto || ':' || coalesce(l.proyecto_id, '-'), ',')
                                from asiento_lineas l join movimientos_banco m on m.asiento_id = l.asiento_id
                               where m.id = v_m and l.cuenta <> '1098'),
                             (select count(*) from cobros c where c.movimiento_id = v_m::text));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (112, 'la devolución de una compra pagada con la débito va contra su gasto, no a una factura', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 113. EL DINERO A Y DESDE LA CUENTA PERSONAL DE EDGAR (ronda 4): el banco
--      nombra el otro lado («ONLINE TRANSFER TO CHK ...7781»), y ese número
--      no es de ningún estado de cuenta ni tarjeta de la empresa. El retiro
--      se propone primero como distribución (3200) y el depósito como
--      préstamo del accionista (2900), antes que las facturas abiertas; la
--      transferencia a una cuenta propia pide su motivo (MX008 sin él), y
--      los botones entran tal cual, sin cobrar ninguna factura. Antes los
--      dos salían como dinero entre cuentas propias o como el cobro de una
--      factura: 2,000.00 «en tránsito» para siempre en la reserva y la
--      factura de un cliente cobrada con dinero de Edgar. (Ronda 4b: así
--      solo con la cuenta personal DADA DE ALTA —fn_banco_cuenta_personal—;
--      el depósito es del mismo monto que una factura abierta y su botón
--      deja el cuadre 52 en verde: el asiento dice de qué cuenta personal
--      viene. Sin darla de alta, la 135.)
do $$
declare
  v_obt  text;
  v_esp  text := 'retiro=transferencia_personal:3200 deposito=transferencia_personal:2900 a_reserva=MX008 '
                 'retiro_boton=casado:clasificado deposito_boton=casado:clasificado facturas=0 control52=t';
  v_obra text := current_setting('mx6.obra', true);
  v_r    uuid;
  v_dp   uuid;
  v_o1   jsonb;
  v_o2   jsonb;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (113, 'el dinero a y desde la cuenta personal de Edgar: distribución o préstamo, no otra cuenta', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-660801, v_obra, 'C6-801', d + 1, 5000.00, 0);
    perform fn_banco_cuenta_personal('7781', 'c6-pruebas: la cuenta personal de Edgar');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 3000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 4, 'monto', '-2000.00', 'id', 'C6PE1', 'nombre', 'ONLINE TRANSFER TO CHK ...7781 T',
                                 'memo', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 21877123456'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 5, 'monto', '5000.00', 'id', 'C6PE2', 'nombre', 'ONLINE TRANSFER FROM CHK ...778',
                                 'memo', 'ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 21877129999'))),
            '1098', 'c6-pruebas-personal.qfx');
    perform fn_banco_casar_todo('1098');
    v_r := pg_temp.c6_mov('1098', 'C6PE1');
    v_dp := pg_temp.c6_mov('1098', 'C6PE2');
    select format('retiro=%s:%s', m.propuesta->>'motivo', m.propuesta->'opciones'->0->'args'->'p_lineas'->0->>'cuenta'),
           m.propuesta->'opciones'->0
      into v_obt, v_o1 from movimientos_banco m where m.id = v_r;
    select v_obt || format(' deposito=%s:%s', m.propuesta->>'motivo', m.propuesta->'opciones'->0->'args'->'p_lineas'->0->>'cuenta'),
           m.propuesta->'opciones'->0
      into v_obt, v_o2 from movimientos_banco m where m.id = v_dp;
    begin
      perform fn_banco_transferencia(v_r, '1097');
      v_obt := v_obt || ' a_reserva=entró';
    exception when others then v_obt := v_obt || ' a_reserva=' || sqlstate;
    end;
    perform fn_banco_clasificar(v_r, v_o1->'args'->'p_lineas', v_o1->'args'->>'p_motivo');
    perform fn_banco_clasificar(v_dp, v_o2->'args'->'p_lineas', v_o2->'args'->>'p_motivo');
    v_obt := v_obt || format(' retiro_boton=%s deposito_boton=%s facturas=%s control52=%s', pg_temp.c6_est('1098', 'C6PE1'),
                             pg_temp.c6_est('1098', 'C6PE2'),
                             (select count(*) from aplicaciones_cobro a where a.factura_id = -660801),
                             pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'), v_dp::text));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (113, 'el dinero a y desde la cuenta personal de Edgar: distribución o préstamo, no otra cuenta', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 114. UN PAGO QUE NOMBRA A ALGUIEN CON DOS LETRAS O CON «&» NO ES UN PAGO
--      SIN NOMBRE (ronda 4): con el proveedor de prueba a cuenta (se le
--      deben 850.00), «QW&T*BILL PAYMENT» (como AT&T), «QZ BANK PAYMENT»
--      (como US BANK) y «ZELLE PAYMENT TO QJ 1882917» salen «sin_ticket», y
--      el teléfono entra a 6120 sin motivo; el «CHECK 1044» sin nombre sigue
--      siendo el abono al proveedor. Antes los tres salían «pago_proveedor»
--      con un solo botón («Abono a …») y clasificar el teléfono pedía
--      motivo con un mensaje falso.
do $$
declare
  v_obt text;
  v_esp text := 'qwt=sin_ticket qz_bank=sin_ticket zelle_qj=sin_ticket cheque=pago_proveedor telefono=casado:clasificado';
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (114, 'un pago que nombra a alguien (dos letras, con &) no es el abono a un proveedor', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660811, 'total', 850.00, 'fecha', d + 2, 'metodo_pago', 'cuenta_proveedor'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 25, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 20, 'monto', '-71.40', 'id', 'C6NA1', 'nombre', 'QW&amp;T*BILL PAYMENT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 21, 'monto', '-350.00', 'id', 'C6NA2', 'nombre', 'QZ BANK PAYMENT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 22, 'monto', '-400.00', 'id', 'C6NA3', 'nombre', 'ZELLE PAYMENT TO QJ 1882917'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 23, 'monto', '-850.00', 'id', 'C6NA4', 'nombre', 'CHECK 1044',
                                 'cheque', '1044'))),
            '1098', 'c6-pruebas-nombra.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := format('qwt=%s qz_bank=%s zelle_qj=%s cheque=%s', split_part(pg_temp.c6_est('1098', 'C6NA1'), ':', 2),
                    split_part(pg_temp.c6_est('1098', 'C6NA2'), ':', 2), split_part(pg_temp.c6_est('1098', 'C6NA3'), ':', 2),
                    split_part(pg_temp.c6_est('1098', 'C6NA4'), ':', 2));
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6NA1'), '[{"cuenta": "6120"}]');
    v_obt := v_obt || ' telefono=' || pg_temp.c6_est('1098', 'C6NA1');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (114, 'un pago que nombra a alguien (dos letras, con &) no es el abono a un proveedor', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 115. «CUADRAR EL MES» NO ENCIENDE CONFIRMAR CUANDO FALTA UN MOTIVO
--      (ronda 4): v_conciliacion (lo que lee la app) dice
--      lista_para_confirmar = false, su identidad «(cuadra, pero falta su
--      motivo)» y trae «falta» (lo mismo que fn_conciliar), con un ticket
--      de más de 10 días sin su cargo y con un saldo escrito distinto del
--      archivo del banco. Antes decía true y «(cuadra)»: el botón se
--      encendía y fallaba.
do $$
declare
  v_obt text;
  v_esp text := 'ticket=f:motivo:falta saldo=f:motivo:falta';
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (115, 'v_conciliacion no da por lista una conciliación a la que le falta un motivo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -660821, 'total', 312.40, 'fecha', d + 3, 'proveedor', 'THE HOME DEPOT'));
    perform fn_conciliar('2100-9996', d + 21, '0.00');
    select format('ticket=%s:%s:%s', case when v.lista_para_confirmar then 't' else 'f' end,
                  case when v.identidad like '%(cuadra, pero falta su motivo)%' then 'motivo' else v.identidad end,
                  case when v.falta is not null then 'falta' else '-' end)
      into v_obt from v_conciliacion v where v.cuenta = '2100-9996' and v.fecha_corte = d + 21;
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 4985.00, jsonb_build_array(
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 8, 'monto', '-15.00', 'id', 'C6VC1', 'nombre', 'MONTHLY SERVICE FEE'))),
            '1098', 'c6-pruebas-vconc.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_conciliar('1098', d + 20, '-15.00');
    select v_obt || format(' saldo=%s:%s:%s', case when v.lista_para_confirmar then 't' else 'f' end,
                           case when v.identidad like '%(cuadra, pero falta su motivo)%' then 'motivo' else v.identidad end,
                           case when v.falta is not null then 'falta' else '-' end)
      into v_obt from v_conciliacion v where v.cuenta = '1098' and v.fecha_corte = d + 20;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (115, 'v_conciliacion no da por lista una conciliación a la que le falta un motivo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 116. CADA BOTÓN DE LA BANDEJA QUE NO PIDE NADA ENTRA TAL CUAL (ronda 4):
--      un Zelle de Edgar que puede ser el depósito en tránsito de la
--      apertura (otro depósito del mismo monto también: no casa solo; su
--      partida va primero) deja detrás sus opciones de siempre
--      (2900, 3100) marcadas «pide_motivo» (fn_banco_clasificar las rechaza
--      sin él); y los intereses del banco que solo el MEMO llama así
--      («CREDIT» / «INTEREST EARNED») entran a 4910 con su botón. Se pulsa
--      cada opción que no pide motivo, con sus argumentos tal cual
--      (c6_pulsar): ninguna falla. Antes las dos de abajo y la de los
--      intereses fallaban (MX008) sin decirlo.
do $$
declare
  v_obt  text;
  v_esp  text := 'zelle=partida_apertura interes=interes marcadas=2 pulsadas=3 fallan=0';
  v_c    jsonb;
  v_n    int := 0;
  v_mal  text;
  o      jsonb;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or d <> fn_puente_corte() or not exists (select 1 from periodos where tipo = 'apertura') then
    insert into _pruebas values (116, 'cada botón de la bandeja que no pide motivo entra tal cual', v_esp,
                                 'omitida: el mes abierto más antiguo no es el primero después del corte, o falta la apertura', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_apertura_minima();
    v_c := fn_conciliacion_apertura('1098', '-3200.00', jsonb_build_array(
             jsonb_build_object('fecha', (d - 1)::text, 'monto', '3200.00', 'descripcion', 'c6-pruebas: depósito del 30-sep')));
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 3203.12, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 1, 'monto', '3200.00', 'id', 'C6PM0', 'nombre', 'DEPOSIT  ID NUMBER 778812'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 2, 'monto', '3200.00', 'id', 'C6PM1',
                                 'nombre', 'ZELLE PAYMENT FROM EDGAR MARTINE'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 20, 'monto', '3.12', 'id', 'C6PM2', 'nombre', 'CREDIT',
                                 'memo', 'INTEREST EARNED'))),
            '1098', 'c6-pruebas-botones.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := format('zelle=%s interes=%s', split_part(pg_temp.c6_est('1098', 'C6PM1'), ':', 2),
                    split_part(pg_temp.c6_est('1098', 'C6PM2'), ':', 2));
    v_obt := v_obt || ' marcadas=' || (select count(*) from movimientos_banco m, jsonb_array_elements(m.propuesta->'opciones') x
                                        where m.id = pg_temp.c6_mov('1098', 'C6PM1') and (x->>'pide_motivo')::boolean
                                          and x->'pide' ? 'p_motivo');
    for o in select x from movimientos_banco m, jsonb_array_elements(m.propuesta->'opciones') x
              where m.id in (pg_temp.c6_mov('1098', 'C6PM0'), pg_temp.c6_mov('1098', 'C6PM1'), pg_temp.c6_mov('1098', 'C6PM2'))
                and not coalesce((x->>'pide_motivo')::boolean, false) loop
      v_n := v_n + 1;
      if pg_temp.c6_pulsar(o) <> 'ok' then
        v_mal := concat_ws('; ', v_mal, (o->>'texto') || ': ' || pg_temp.c6_pulsar(o));
      end if;
    end loop;
    v_obt := v_obt || format(' pulsadas=%s fallan=%s', v_n, coalesce(v_mal, '0'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (116, 'cada botón de la bandeja que no pide motivo entra tal cual', v_esp,
                               coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 117. EL ERROR DE UNA LÍNEA DE EDGAR DICE SU NÚMERO (ronda 4): al
--      clasificar con UNA línea mal escrita, lo que c2 rechaza al postear
--      (la obra que falta, la obra que no existe) dice «Línea 1», no la
--      línea del asiento (la 1 es la del banco), con su código de c2.
--      Antes decía «Línea 2» de una sola línea.
do $$
declare
  v_obt text;
  v_esp text := 'sin_obra=MX006:Línea 1 obra_mala=MX006:Línea 1';
  v_m   uuid;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (117, 'el error de c2 en una línea de Edgar dice su número, no el del asiento', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 6, 'monto', '-123.45', 'id', 'C6LN1', 'nombre', 'C6 FERRETERIA LOCAL'))),
            '1098', 'c6-pruebas-linea.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6LN1');
    begin
      perform fn_banco_clasificar(v_m, '[{"cuenta": "5100"}]');
      v_obt := 'sin_obra=entró';
    exception when others then v_obt := 'sin_obra=' || sqlstate || ':' || substring(sqlerrm from '^(Línea [0-9]+)');
    end;
    begin
      perform fn_banco_clasificar(v_m, '[{"cuenta": "5100", "proyecto_id": "c6-pruebas-no-existe"}]');
      v_obt := v_obt || ' obra_mala=entró';
    exception when others then v_obt := v_obt || ' obra_mala=' || sqlstate || ':' || substring(sqlerrm from '^(Línea [0-9]+)');
    end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (117, 'el error de c2 en una línea de Edgar dice su número, no el del asiento', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 118. EL SALDO DE UN LOTE O DE UN QFX RETOCADO NO ES «EL DEL BANCO»
--      (ronda 4): con el QFX del banco diciendo -104.99 a fin de mes, un
--      «lote a mano» de cero filas con el saldo tecleado (-15.00, el de
--      libros tras ignorar un cargo) lo contradice: se dice al subirlo, el
--      QFX sigue siendo el saldo del banco (la conciliación y v_banco_saldos),
--      y el saldo escrito igual al del lote pide su motivo (MX008 sin él).
--      Lo mismo con el QFX retocado (el mismo archivo con otro BALAMT,
--      subido con otro nombre): los dos del banco no dicen lo mismo y piden
--      su motivo. Con él, se confirma; y una confirmada así SIN su motivo
--      sale en rojo en el control aunque su saldo_archivo se haya cambiado
--      para cuadrar (el cuadre 54 rehace el cruce contra los archivos).
--      Antes el lote se volvía «el archivo del banco» y todo en verde.
do $$
declare
  v_obt text;
  v_esp text := 'aviso=t sin_escrito=89.99 mano=1:MX008 saldos=-104.99 retocado=1:MX008 con_motivo=confirmada control=f';
  v_x   jsonb;
  v_c   jsonb;
  v_id  uuid;
  v_r   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (118, 'el saldo de un lote a mano o de un QFX retocado no es el del banco: pide motivo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, -104.99, jsonb_build_array(
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 8, 'monto', '-15.00', 'id', 'C6SL1', 'nombre', 'MONTHLY SERVICE FEE'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 19, 'monto', '-89.99', 'id', 'C6SL2', 'nombre', 'AMAZON MKTPLACE PMTS'))),
            '1098', 'c6-pruebas-saldo-qfx.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_ignorar(pg_temp.c6_mov('1098', 'C6SL2'), 'c6-pruebas: no es de la empresa');
    -- El lote a mano con el saldo tecleado, a la misma fecha.
    v_x := fn_banco_importar_filas(jsonb_build_object('origen', 'mano', 'cuenta', '1098', 'nombre', 'c6-pruebas: saldo tecleado',
                                                      'saldo', '-15.00', 'saldo_al', (d + 27)::text, 'filas', '[]'::jsonb));
    v_obt := 'aviso=' || case when v_x->'avisos' @? '$[*] ? (@ like_regex "no es el que dice")' then 't' else 'f' end;
    v_c := fn_conciliar('1098', d + 27, null);
    v_obt := v_obt || ' sin_escrito=' || (v_c->>'diferencia');
    v_c := fn_conciliar('1098', d + 27, '-15.00');
    v_id := (v_c->>'conciliacion')::uuid;
    begin
      perform fn_conciliacion_confirmar(v_id);
      v_r := 'confirmada';
    exception when others then v_r := sqlstate;
    end;
    v_obt := v_obt || format(' mano=%s:%s saldos=%s', coalesce(v_c->>'n_pide_motivo', '-'), v_r,
                             (select s.saldo_banco from v_banco_saldos s where s.cuenta = '1098'));
    -- El QFX retocado: el mismo, con otro saldo, subido con otro nombre.
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, -15.00, jsonb_build_array(
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 8, 'monto', '-15.00', 'id', 'C6SL1', 'nombre', 'MONTHLY SERVICE FEE'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 19, 'monto', '-89.99', 'id', 'C6SL2', 'nombre', 'AMAZON MKTPLACE PMTS'))),
            '1098', 'c6-pruebas-saldo-qfx (2).qfx');
    v_c := fn_conciliar('1098', d + 27, '-15.00');
    begin
      perform fn_conciliacion_confirmar(v_id);
      v_r := 'confirmada';
    exception when others then v_r := sqlstate;
    end;
    v_obt := v_obt || format(' retocado=%s:%s', coalesce(v_c->>'n_pide_motivo', '-'), v_r);
    perform fn_conciliacion_saldo(v_id, 'c6-pruebas: el statement en PDF dice -15.00; el QFX de -104.99 se bajó antes del ajuste',
                                  'docs/c6-pruebas/statement.pdf');
    v_obt := v_obt || ' con_motivo=' || (fn_conciliacion_confirmar(v_id)->>'estado');
    -- Confirmada así, SIN su motivo y con su saldo_archivo cambiado para
    -- cuadrar con el escrito (lo que pasaría con las guardas apagadas).
    alter table public.conciliaciones disable trigger user;
    update public.conciliaciones set saldo_motivo = null, saldo_archivo = saldo_statement where id = v_id;
    alter table public.conciliaciones enable trigger user;
    v_obt := v_obt || ' control=' || pg_temp.c6_cuadre('cuadre: conciliaciones confirmadas', current_setting('mx6.mes'),
                                                       format('1098 al %s', d + 27));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa el banco (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (118, 'el saldo de un lote a mano o de un QFX retocado no es el del banco: pide motivo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 119. CLASIFICAR SIN «CASAR» MIRA LO MISMO QUE «CASAR» (ronda 4): recién
--      importados, sin la propuesta todavía, el depósito de una factura
--      abierta (al costo de la obra), el pago al proveedor con partidas
--      (otra vez al costo), el cheque devuelto (a 6130) y la nómina (a 6500)
--      dan MX008 sin motivo, como después de «Casar». Y el depósito
--      clasificado sin motivo que después explica una factura abierta de su
--      monto (llegó con fecha de antes) sale en rojo en el cuadre 52 (ronda
--      4b: clasificado al desembolso de la línea de crédito, 2510; a la
--      aportación, 3100, sin motivo ya no entra: es patrimonio). Y la
--      propuesta VIEJA (de un «Casar» de antes de dar de alta al proveedor que
--      el cargo nombra) no vale: se rehace y pide motivo. Antes los cuatro
--      entraban sin pedir nada y el control seguía en verde.
do $$
declare
  v_obt text;
  v_esp text := 'deposito=MX008 proveedor=MX008 devuelto=MX008 nomina=MX008 aporte=MX008 prestamo=casado:clasificado control52=f '
                'vieja=pendiente:sin_ticket>MX008';
  v_m   uuid;
  v_x   text;
  r     record;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (119, 'clasificar sin «Casar»: factura, proveedor, cheque devuelto y nómina piden motivo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661191, current_setting('mx6.obra'), 'C6-119', d + 2, 3200.50, 0);
    perform pg_temp.c6_recibo(jsonb_build_object('id', -661191, 'total', 850.00, 'fecha', d + 5, 'metodo_pago', 'cuenta_proveedor'));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 25, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 14, 'monto', '3200.50', 'id', 'C6NP1', 'nombre', 'ZELLE FROM JOHN SMITH'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 20, 'monto', '-850.00', 'id', 'C6NP2', 'nombre', 'BILL PAY C6 PRUEBAS SUPPLY'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 12, 'monto', '-500.00', 'id', 'C6NP3', 'nombre', 'RETURNED DEPOSITED ITEM'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 9, 'monto', '-4000.00', 'id', 'C6NP4', 'nombre', 'GUSTO PAYROLL'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 15, 'monto', '987654.32', 'id', 'C6NP5', 'nombre', 'WIRE FROM C6 CREDITO'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 18, 'monto', '-321.00', 'id', 'C6NP6', 'nombre', 'BILL PAY C6 OTRO PROVEEDOR'))),
            '1098', 'c6-pruebas-sin-casar.qfx');
    -- (sin «Casar»: ninguno tiene su propuesta)
    for r in select * from (values (1, 'deposito', 'C6NP1', jsonb_build_array(jsonb_build_object('cuenta', '5100',
                                                                                                'proyecto_id', current_setting('mx6.obra')))),
                                   (2, 'proveedor', 'C6NP2', jsonb_build_array(jsonb_build_object('cuenta', '5100',
                                                                                                 'proyecto_id', current_setting('mx6.obra')))),
                                   (3, 'devuelto', 'C6NP3', '[{"cuenta": "6130"}]'::jsonb),
                                   (4, 'nomina', 'C6NP4', '[{"cuenta": "6500"}]'::jsonb)) as t(o, que, fitid, lineas)
             order by o loop
      begin
        perform fn_banco_clasificar(pg_temp.c6_mov('1098', r.fitid), r.lineas, null);
        v_x := 'entró';
      exception when others then v_x := sqlstate;
      end;
      v_obt := concat_ws(' ', v_obt, r.que || '=' || v_x);
    end loop;
    -- El desembolso de la línea de crédito, sin factura que lo explique (ni
    -- siquiera una parte: más que cualquiera abierta): entra sin motivo. (A
    -- la aportación, 3100, no: es patrimonio del accionista, con su motivo.)
    v_m := pg_temp.c6_mov('1098', 'C6NP5');
    begin
      perform fn_banco_clasificar(v_m, '[{"cuenta": "3100"}]'::jsonb, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' aporte=' || v_x;
    perform fn_banco_clasificar(v_m, '[{"cuenta": "2510"}]'::jsonb, null);
    v_obt := v_obt || ' prestamo=' || pg_temp.c6_est('1098', 'C6NP5');
    -- ... y después entra una factura de su monto, con fecha de antes.
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661192, current_setting('mx6.obra'), 'C6-119B', d + 10, 987654.32, 0);
    v_obt := v_obt || ' control52=' || pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'), v_m::text);
    -- Con «Casar» al día, la propuesta guardada vale y no se rehace. Pero si
    -- después cambia lo que mira (aquí: se da de alta el proveedor que el
    -- cargo nombra), la de hoy es otra: clasificarlo al costo sin motivo
    -- pide motivo (su firma_g ya no es la de hoy y se rehace).
    perform fn_banco_casar_todo('1098');
    v_x := pg_temp.c6_est('1098', 'C6NP6');
    perform fn_proveedor_alta('C6 OTRO PROVEEDOR', 'Net 30');
    begin
      perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6NP6'),
                                  jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))), null);
      v_x := v_x || '>entró';
    exception when others then v_x := v_x || '>' || sqlstate;
    end;
    v_obt := v_obt || ' vieja=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (119, 'clasificar sin «Casar»: factura, proveedor, cheque devuelto y nómina piden motivo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 120. LA PARTIDA EN TRÁNSITO DE LA APERTURA NO SE POSTEA OTRA VEZ POR
--      OTRO CAMINO (ronda 4): el pago de la tarjeta del 29-sep y la cuota del
--      préstamo de septiembre, en circulación en la conciliación de
--      apertura, que el banco cobra en octubre: postearlos como
--      transferencia o como la cuota (fn_banco_transferencia,
--      fn_prestamo_cuota) sin motivo es MX008, y el texto nombra la
--      partida; con su motivo, entra. (Cobrar y pagar a un proveedor, en la
--      63.) Antes solo lo frenaba clasificar.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=partida_apertura/partida_apertura transferencia=MX008:nombra cuota=MX008 con_motivo=en_transito';
  v_c   jsonb;
  v_p   uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or not exists (select 1 from periodos where tipo = 'apertura') then
    insert into _pruebas values (120, 'la partida de la apertura no se postea otra vez como transferencia ni como cuota sin motivo', v_esp,
                                 'omitida: falta mes abierto o la apertura', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_apertura_minima();
    v_c := fn_conciliacion_apertura('1098', '1529.33', jsonb_build_array(
             jsonb_build_object('fecha', (d - 2)::text, 'monto', '-500.00', 'descripcion', 'c6-pruebas: pago de la Amex del 29-sep'),
             jsonb_build_object('fecha', (d - 1)::text, 'monto', '-1029.33', 'descripcion', 'c6-pruebas: cuota de septiembre')));
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    v_p := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS FORD', 'descripcion', 'F-150 de prueba',
             'principal', '52000.00', 'tasa_anual', '6.99', 'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15,
             'plazo_meses', 60, 'saldo_inicial', '31415.26', 'saldo_inicial_al', (d - 1)::text, 'cuenta_banco', '1098',
             'descriptor', 'C6 PRUEBAS FORD'))->>'id')::uuid;
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 9, 'monto', '-500.00', 'id', 'C6PT1', 'nombre', 'AMERICAN EXPRESS ACH PMT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 10, 'monto', '-1029.33', 'id', 'C6PT2', 'nombre', 'C6 PRUEBAS FORD PMT'))),
            '1098', 'c6-pruebas-partida-otro-camino.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := format('bandeja=%s/%s', split_part(pg_temp.c6_est('1098', 'C6PT1'), ':', 2), split_part(pg_temp.c6_est('1098', 'C6PT2'), ':', 2));
    begin
      perform fn_banco_transferencia(pg_temp.c6_mov('1098', 'C6PT1'), '2100-9996');
      v_x := 'entró';
    exception when others then
      v_x := sqlstate || case when sqlerrm like '%pago de la Amex del 29-sep%' then ':nombra' else '' end;
    end;
    v_obt := v_obt || ' transferencia=' || v_x;
    begin
      perform fn_prestamo_cuota(v_p, pg_temp.c6_mov('1098', 'C6PT2'));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' cuota=' || v_x;
    v_obt := v_obt || ' con_motivo=' || (fn_banco_transferencia(pg_temp.c6_mov('1098', 'C6PT1'), '2100-9996',
                                                                'c6-pruebas: este pago es otro; el de septiembre lo cobró antes')->>'estado');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (120, 'la partida de la apertura no se postea otra vez como transferencia ni como cuota sin motivo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt = 'omitida' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 121. LO QUE LEEN LAS REGLAS AUTOMÁTICAS, CAMBIADO POR FUERA, SALE EN ROJO
--      (ronda 4): con las guardas apagadas un instante, la descripción
--      normalizada de un movimiento (la que leen R3, R7 y la llave), el
--      patrón de un descriptor y la marca «posible duplicado» de otro: el
--      cuadre 53 dice los tres, y la revisión entera también (relee el
--      archivo y compara cada descriptor con su último cambio en
--      banco_historial). Antes los tres quedaban fuera del sello y en verde.
--      (Ronda 4b: y una cuenta personal de Edgar puesta por fuera de
--      fn_banco_cuenta_personal —deja entrar dinero al patrimonio sin
--      motivo—: el cuadre 53 la dice también.)
do $$
declare
  v_obt text;
  v_esp text := 'desc_norm=f descriptor=f duplicado=f personal=f verificar=f/f';
  v_m1  uuid;
  v_m2  uuid;
  v_d   jsonb;
  v_e   jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (121, 'la descripción normalizada, un descriptor y una marca de duplicado, cambiados por fuera, en rojo',
                                 v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 10, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 4, 'monto', '-1200.00', 'id', 'C6DN1', 'nombre', 'BILL PAY C6 PRUEBAS SUPPLY'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 6, 'monto', '-58.10', 'id', 'C6DN2', 'nombre', 'C6 TIENDA UNO'))),
            '1098', 'c6-pruebas-sellado-1.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 12, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 6, 'monto', '-58.10', 'id', 'C6DN2-B', 'nombre', 'C6 TIENDA UNO'))),
            '1098', 'c6-pruebas-sellado-2.qfx');
    v_m1 := pg_temp.c6_mov('1098', 'C6DN1');
    v_m2 := pg_temp.c6_mov('1098', 'C6DN2-B');
    alter table public.movimientos_banco disable trigger user;
    alter table public.banco_descriptores disable trigger user;
    alter table public.banco_cuentas_personales disable trigger user;
    update public.movimientos_banco set desc_norm = 'AMERICAN EXPRESS ACH PMT' where id = v_m1;
    update public.movimientos_banco set posible_duplicado_de = null where id = v_m2;
    update public.banco_descriptores set patron = patron || '|BILL PAY' where clave = 'pago_tarjeta';
    insert into public.banco_cuentas_personales (ultimos4, nombre) values ('7783', 'c6-pruebas: puesta por fuera');
    alter table public.movimientos_banco enable trigger user;
    alter table public.banco_descriptores enable trigger user;
    alter table public.banco_cuentas_personales enable trigger user;
    -- (el cuadre y la revisión, una vez cada uno: con un año de banco cada
    -- llamada cuenta)
    select coalesce(c.detalle, '') into v_x
      from fn_banco_control(current_setting('mx6.mes'), array['cuadre: archivos intactos']) c
     where c.vista = 'cuadre: archivos intactos';
    v_obt := format('desc_norm=%s descriptor=%s duplicado=%s personal=%s',
                    case when position(v_m1::text in coalesce(v_x, '')) > 0 then 'f' else 't' end,
                    case when position('«pago_tarjeta»' in coalesce(v_x, '')) > 0 then 'f' else 't' end,
                    case when position('c6-pruebas-sellado-2.qfx' in coalesce(v_x, '')) > 0 then 'f' else 't' end,
                    case when position('····7783' in coalesce(v_x, '')) > 0 then 'f' else 't' end);
    select (array_agg(v.detalle) filter (where v.control = 'archivos, leídos otra vez fila por fila'))[1],
           (array_agg(v.detalle) filter (where v.control = 'descriptores'))[1]
      into v_d, v_e
      from fn_banco_verificar(array['1098']) v;
    v_obt := v_obt || format(' verificar=%s/%s',
                             case when jsonb_array_length(v_d->'no_dan_lo_mismo') > 0 then 'f' else 't' end,
                             case when v_e->'mal' @? '$[*] ? (@.clave == "pago_tarjeta")' then 'f' else 't' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa el banco (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (121, 'la descripción normalizada, un descriptor y una marca de duplicado, cambiados por fuera, en rojo',
                               v_esp, coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 122. LA COMISIÓN DE UN COBRO CON TARJETA TIENE TOPE (ronda 4): un
--      depósito de 100.00 no cobra entera una factura de 1,000.00 con 900.00
--      de «comisión» (MX005: lo que se queda el procesador es menos que el
--      depósito); 50.00 de comisión sobre 1,000.00 pasa del tope de un
--      procesador (3.5 % más 0.30: 35.30) y sin motivo es MX008; con su
--      motivo en las notas entra, y el asiento de la comisión guarda su
--      porcentaje y su tope (el cuadre 52 los mira: con motivo, en verde).
--      Y un depósito que no nombra a ningún procesador (un Zelle de 1,234.56
--      contra una factura de 1,272.00): la primera opción de la bandeja ya
--      no es la comisión (es la parte de una factura: el pago parcial),
--      ninguna opción lleva la diferencia a comisión sin pedir su motivo, y
--      cobrarla sin él es MX008. Antes no
--      tenía tope y mandaba 900.00 a 6130, sin motivo y en verde; y el Zelle
--      salía «cobrada con tarjeta» como primera opción. (Con un libro de
--      verdad hay muchas facturas abiertas: la prueba no cuenta con que la
--      opción de la comisión quepa entre las seis que se proponen.)
do $$
declare
  v_obt text;
  v_esp text := 'igual_o_mayor=MX005 sobre_tope=MX008 con_notas=casado:cobro pct=5.00 tope=35.30 control52=t '
                'zelle_primera=sin_comision comision_sin_motivo=0 sin_procesador=MX008 zelle_con_notas=casado:cobro';
  v_m   uuid;
  v_x   text;
  v_op  jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (122, 'la comisión de un cobro con tarjeta: menos que el depósito, y sobre su tope con motivo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661221, current_setting('mx6.obra'), 'C6-122A', d + 2, 1000.00, 0),
           (-661222, current_setting('mx6.obra'), 'C6-122B', d + 3, 1000.00, 0),
           (-661223, current_setting('mx6.obra'), 'C6-122C', d + 14, 1272.00, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 12, 'monto', '100.00', 'id', 'C6CM1', 'nombre', 'INTUIT QBPAYMENTS DEPOSIT'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 13, 'monto', '950.00', 'id', 'C6CM2', 'nombre', 'INTUIT QBPAYMENTS DEPOSIT'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 14, 'monto', '1234.56', 'id', 'C6CM3', 'nombre', 'ZELLE FROM C6 CLIENTE'))),
            '1098', 'c6-pruebas-comision.qfx');
    perform fn_banco_casar_todo('1098');
    begin
      perform fn_banco_cobrar(pg_temp.c6_mov('1098', 'C6CM1'),
                              '[{"factura_id": -661221, "monto": "1000.00"}, {"comision": "900.00"}]'::jsonb, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := 'igual_o_mayor=' || v_x;
    v_m := pg_temp.c6_mov('1098', 'C6CM2');
    begin
      perform fn_banco_cobrar(v_m, '[{"factura_id": -661222, "monto": "1000.00"}, {"comision": "50.00"}]'::jsonb, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' sobre_tope=' || v_x;
    perform fn_banco_cobrar(v_m, '[{"factura_id": -661222, "monto": "1000.00"}, {"comision": "50.00"}]'::jsonb,
                            'c6-pruebas: el procesador cobró además el cargo por contracargo');
    v_obt := v_obt || ' con_notas=' || pg_temp.c6_est('1098', 'C6CM2')
             || (select format(' pct=%s tope=%s', a.procedencia->>'pct', a.procedencia->>'tope')
                   from asientos a
                  where a.origen_tabla = 'movimientos_banco' and a.origen_id = v_m::text and a.procedencia->>'anexo' = 'comision'
                  order by a.cadena_pos desc limit 1)
             || ' control52=' || pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'), v_m::text);
    -- El Zelle de 1,234.56: sin procesador, la primera opción de cobro no
    -- lleva la diferencia a comisión (es la parte de una factura, o la que
    -- cuadre exacta), y ninguna la lleva sin pedir su motivo.
    v_m := pg_temp.c6_mov('1098', 'C6CM3');
    select o into v_op
      from movimientos_banco m, jsonb_array_elements(m.propuesta->'opciones') with ordinality as x(o, n)
     where m.id = v_m and o->>'llamar' = 'fn_banco_cobrar' order by x.n limit 1;
    v_obt := v_obt || ' zelle_primera='
             || case when v_op is null then 'no_hay'
                     when jsonb_path_exists(v_op->'args'->'p_aplicaciones', '$[*].comision') then 'comision:' || (v_op->>'texto')
                     else 'sin_comision' end
             || ' comision_sin_motivo=' || (select count(*) from movimientos_banco m, jsonb_array_elements(m.propuesta->'opciones') o
                                            where m.id = v_m and o->>'llamar' = 'fn_banco_cobrar'
                                              and jsonb_path_exists(o->'args'->'p_aplicaciones', '$[*].comision')
                                              and not coalesce((o->>'pide_motivo')::boolean, false));
    begin
      perform fn_banco_cobrar(v_m, '[{"factura_id": -661223, "monto": "1272.00"}, {"comision": "37.44"}]'::jsonb, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' sin_procesador=' || v_x;
    perform fn_banco_cobrar(v_m, '[{"factura_id": -661223, "monto": "1272.00"}, {"comision": "37.44"}]'::jsonb,
                            'c6-pruebas: el cliente pagó con tarjeta por el portal y el banco lo deposita como Zelle');
    v_obt := v_obt || ' zelle_con_notas=' || pg_temp.c6_est('1098', 'C6CM3');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (122, 'la comisión de un cobro con tarjeta: menos que el depósito, y sobre su tope con motivo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 123. EL ESTADO DE CUENTA DE OTRA TARJETA NO ENTRA A UNA DE LA EMPRESA
--      (ronda 4): con la tarjeta de prueba ····9996, el QFX de una tarjeta
--      ····7777 que no está dada de alta, dicho a 2100-9996, para (MX004);
--      sin decir la cuenta también, y el mensaje dice que lo que no es de la
--      empresa no se sube; dada de alta en esa cuenta (fn_tarjeta_alta),
--      entra. Y una tarjeta dada de alta en otro pasivo (la personal de
--      Edgar en 2900, para sus tickets) no recibe su estado de cuenta: solo
--      las subcuentas de 2100. Antes la personal entraba entera a la Gold.
do $$
declare
  v_obt  text;
  v_esp  text := 'dicha=MX004 sin_cuenta=MX004:no_se_sube alta=2100-9996 en_2900=MX004';
  v_qfx  text;
  v_x    text;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (123, 'el estado de cuenta de otra tarjeta no entra a una de la empresa sin darla de alta', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_qfx := pg_temp.c6_qfx('tarjeta', '379876543217777', d, d + 20, -2262.33, jsonb_build_array(
               jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 7, 'monto', '-1850.00', 'id', 'C6TJ1', 'nombre', 'DELTA AIR LINES'),
               jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 14, 'monto', '-412.33', 'id', 'C6TJ2', 'nombre', 'NORDSTROM #0412')));
    begin
      perform fn_banco_importar_ofx(v_qfx, '2100-9996', 'c6-pruebas-otra-tarjeta.qfx');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := 'dicha=' || v_x;
    begin
      perform fn_banco_importar_ofx(v_qfx, null, 'c6-pruebas-otra-tarjeta.qfx');
      v_x := 'entró';
    exception when others then v_x := sqlstate || case when sqlerrm like '%no se sube%' then ':no_se_sube' else '' end;
    end;
    v_obt := v_obt || ' sin_cuenta=' || v_x;
    perform fn_tarjeta_alta('7777', '2100-9996', 'c6-pruebas: la adicional');
    v_obt := v_obt || ' alta=' || (fn_banco_importar_ofx(v_qfx, '2100-9996', 'c6-pruebas-otra-tarjeta.qfx')->>'cuenta');
    perform fn_tarjeta_alta('7776', '2900', 'c6-pruebas: la personal, para sus tickets');
    begin
      perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '379876543217776', d, d + 20, -99.00, jsonb_build_array(
                jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 9, 'monto', '-99.00', 'id', 'C6TJ3', 'nombre', 'NETFLIX.COM'))),
                null, 'c6-pruebas-personal.qfx');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' en_2900=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (123, 'el estado de cuenta de otra tarjeta no entra a una de la empresa sin darla de alta', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 124. EL MISMO ID CON LA FECHA O EL MONTO CORREGIDOS ESPERA (ronda 4): el
--      FITID que el banco vuelve a mandar con otro día, la transacción de
--      Plaid que vuelve con otro monto («modified», el mismo id) y el cargo
--      del 30-sep (ignorado: antes del corte) que la descarga siguiente
--      trae fechado el 1-oct entran marcados «posible duplicado», con su
--      aviso. Antes entraban como nuevos y sin marca: el gasto dos veces.
do $$
declare
  v_obt text;
  v_esp text := 'fitid=pendiente:posible_duplicado aviso=t plaid=pendiente:posible_duplicado antes_del_corte=pendiente:posible_duplicado';
  v_x   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
  v_k   date := fn_puente_corte();
begin
  if d is null then
    insert into _pruebas values (124, 'el mismo FITID o id de Plaid con la fecha o el monto corregidos entra posible duplicado', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 7, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'monto', '-45.67', 'id', 'C6MI1', 'nombre', 'HOME DEPOT #6345 MIAMI FL'))),
            '1098', 'c6-pruebas-mismo-id-1.qfx');
    v_x := fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 30, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 6, 'monto', '-45.67', 'id', 'C6MI1', 'nombre', 'HOME DEPOT #6345 MIAMI FL'))),
            '1098', 'c6-pruebas-mismo-id-2.qfx');
    v_obt := format('fitid=%s aviso=%s', pg_temp.c6_est('1098', 'C6MI1'),
                    case when v_x->'avisos' @? '$[*] ? (@ like_regex "C6MI1")' then 't' else 'f' end);
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '2100-9996', 'filas', jsonb_build_array(
              jsonb_build_object('id', 'c6-plaid-mod', 'fecha', d + 6, 'plaid_monto', '1050.00', 'descripcion', 'C6 STEAK HOUSE'))));
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '2100-9996', 'filas', jsonb_build_array(
              jsonb_build_object('id', 'c6-plaid-mod', 'fecha', d + 6, 'plaid_monto', '1260.00', 'descripcion', 'C6 STEAK HOUSE'))));
    v_obt := v_obt || ' plaid=' || pg_temp.c6_est('2100-9996', 'c6-plaid-mod');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', v_k - 20, v_k - 1, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', v_k - 1, 'monto', '-612.40', 'id', 'C6MI2', 'nombre', 'FPL DIRECT DEBIT'))),
            '1098', 'c6-pruebas-mismo-id-sep.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', v_k - 2, v_k + 5, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', v_k, 'monto', '-612.40', 'id', 'C6MI2', 'nombre', 'FPL DIRECT DEBIT'))),
            '1098', 'c6-pruebas-mismo-id-oct.qfx');
    v_obt := v_obt || ' antes_del_corte=' || pg_temp.c6_est('1098', 'C6MI2');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (124, 'el mismo FITID o id de Plaid con la fecha o el monto corregidos entra posible duplicado', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 125. EL CHEQUE QUE EL BANCO COBRA OTRA VEZ NO SE PIERDE (ronda 4): el
--      cheque 1043 rebota en la semana 1 y el proveedor lo vuelve a
--      depositar: en la descarga de la semana 2 llega con SU FITID y entra
--      «posible duplicado» (antes se daba por repetido y se perdía); dicho
--      que no es el mismo, lo que entró de la semana 2 suma lo que dicen sus
--      saldos (3,800.00). Y el mismo cheque escrito a mano, otro día,
--      tampoco se descarta: «posible duplicado».
do $$
declare
  v_obt text;
  v_esp text := 'semana2=nuevas:2 cheque=pendiente:posible_duplicado no_es=pendiente suma=3800.00 mano=pendiente:posible_duplicado';
  v_x   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (125, 'el cheque cobrado otra vez, con su FITID, entra posible duplicado; a mano, igual', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 3, -34.00, jsonb_build_array(
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 1, 'monto', '-1200.00', 'id', 'C6RP1', 'nombre', 'CHECK 1043', 'cheque', '1043'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 2, 'monto', '1200.00', 'id', 'C6RP2', 'nombre', 'RETURNED ITEM CHECK 1043'),
              jsonb_build_object('tipo', 'FEE', 'fecha', d + 2, 'monto', '-34.00', 'id', 'C6RP3', 'nombre', 'INSUFFICIENT FUNDS FEE'))),
            '1098', 'c6-pruebas-rebote-1.qfx');
    v_x := fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 4, d + 10, 3766.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 4, 'monto', '5000.00', 'id', 'C6RP4', 'nombre', 'REMOTE ONLINE DEPOSIT'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 5, 'monto', '-1200.00', 'id', 'C6RP5', 'nombre', 'CHECK 1043', 'cheque', '1043'))),
            '1098', 'c6-pruebas-rebote-2.qfx');
    v_obt := format('semana2=nuevas:%s cheque=%s', v_x->>'filas_nuevas', pg_temp.c6_est('1098', 'C6RP5'));
    perform fn_banco_duplicado(pg_temp.c6_mov('1098', 'C6RP5'), false, 'c6-pruebas: el proveedor lo depositó otra vez');
    v_obt := v_obt || format(' no_es=%s suma=%s', split_part(pg_temp.c6_est('1098', 'C6RP5'), ':', 1),
                             (select sum(m.monto) from movimientos_banco m where m.archivo_id = (v_x->>'archivo')::uuid));
    v_x := fn_banco_importar_filas(jsonb_build_object('origen', 'mano', 'cuenta', '1098', 'nombre', 'c6-pruebas: el cheque a mano',
              'filas', jsonb_build_array(jsonb_build_object('fecha', d + 8, 'monto', '-1200.00', 'descripcion', 'CHECK 1043',
                                                            'cheque', '1043'))));
    v_obt := v_obt || ' mano=' || coalesce((select m.estado || ':' || coalesce(m.estado_motivo, '-') from movimientos_banco m
                                             where m.archivo_id = (v_x->>'archivo')::uuid), 'no_entró');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (125, 'el cheque cobrado otra vez, con su FITID, entra posible duplicado; a mano, igual', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 126. EL BANCO QUE NUMERA SUS FITID POR ARCHIVO (ronda 4): en la segunda
--      descarga el «3» ya no es SHELL sino CHEVRON, del mismo día y monto:
--      CHEVRON entra «posible duplicado» (antes se daba por repetida: la
--      otra compra se perdía) y la revisión lo da por bien; y si su
--      movimiento se borra por fuera, la revisión ya no da la fila por vista
--      solo porque su FITID apunta a SHELL.
do $$
declare
  v_obt text;
  v_esp text := 'chevron=pendiente:posible_duplicado verificar=t borrado=f';
  v_m   uuid;
  v_d   jsonb;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (126, 'con FITID por archivo, otra compra del mismo día y monto no se pierde', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 5, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 1, 'monto', '-20.00', 'id', '1', 'nombre', 'WIRE FEE'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 2, 'monto', '5000.00', 'id', '2', 'nombre', 'DEPOSIT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'monto', '-100.00', 'id', '3', 'nombre', 'SHELL OIL 57444 MIAMI'))),
            '1098', 'c6-pruebas-fitid-1.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 2, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 2, 'monto', '5000.00', 'id', '1', 'nombre', 'DEPOSIT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'monto', '-55.10', 'id', '2', 'nombre', 'CED HIALEAH'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'monto', '-100.00', 'id', '3', 'nombre', 'CHEVRON 0091 DORAL'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'monto', '-100.00', 'id', '4', 'nombre', 'SHELL OIL 57444 MIAMI'))),
            '1098', 'c6-pruebas-fitid-2.qfx');
    v_m := (select m.id from movimientos_banco m where m.cuenta = '1098' and m.descripcion = 'CHEVRON 0091 DORAL');
    v_obt := 'chevron=' || coalesce((select m.estado || ':' || coalesce(m.estado_motivo, '-') from movimientos_banco m where m.id = v_m),
                                    'no_entró');
    select v.detalle into v_d from fn_banco_verificar(array['1098']) v where v.control = 'archivos, leídos otra vez fila por fila';
    v_obt := v_obt || ' verificar=' || case when jsonb_array_length(v_d->'no_dan_lo_mismo') > 0 then 'f' else 't' end;
    alter table public.movimientos_banco disable trigger user;
    delete from public.movimientos_banco where id = v_m;
    alter table public.movimientos_banco enable trigger user;
    select v.detalle into v_d from fn_banco_verificar(array['1098']) v where v.control = 'archivos, leídos otra vez fila por fila';
    v_obt := v_obt || ' borrado=' || case when v_d->'no_dan_lo_mismo' @? '$[*].filas[*] ? (@.descripcion == "CHEVRON 0091 DORAL")'
                                          then 'f' else 't' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa el banco (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (126, 'con FITID por archivo, otra compra del mismo día y monto no se pierde', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 127. LO QUE EL OFX DICE Y ANTES NO SE LEÍA (ronda 4): la CORRECCIÓN del
--      banco (CORRECTACTION REPLACE de los intereses que R7 ya casó) entra
--      «posible duplicado» del corregido y R7 no la casa otra vez; el
--      borrado (DELETE) de un cargo pendiente lo deja ignorado; un
--      movimiento en otra moneda (CURRENCY) para el archivo (MX009); y en un
--      OFX 2.x, el nombre dentro de CDATA (con su «&») y un comentario se
--      leen bien.
do $$
declare
  v_obt text;
  v_esp text := 'replace=pendiente:posible_duplicado corregido=casado delete=ignorado moneda=MX009 cdata=C6 HOTEL & SPA';
  v_cab text := concat_ws(E'\r\n', 'OFXHEADER:100', 'DATA:OFXSGML', 'VERSION:102', 'SECURITY:NONE', 'ENCODING:USASCII', 'CHARSET:1252',
                          'COMPRESSION:NONE', 'OLDFILEUID:NONE', 'NEWFILEUID:NONE', '');
  v_ini text := '<OFX><BANKMSGSRSV1><STMTTRNRS><TRNUID>1<STATUS><CODE>0<SEVERITY>INFO</STATUS><STMTRS><CURDEF>USD'
                || '<BANKACCTFROM><BANKID>267084131<ACCTID>000000001097<ACCTTYPE>SAVINGS</BANKACCTFROM><BANKTRANLIST>';
  v_fin text := '</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>';
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (127, 'el OFX: la corrección del banco, otra moneda y CDATA se leen como lo que son', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(v_cab || v_ini
              || format('<DTSTART>%s<DTEND>%s', to_char(d, 'YYYYMMDD'), to_char(d + 15, 'YYYYMMDD'))
              || format('<STMTTRN><TRNTYPE>INT<DTPOSTED>%s<TRNAMT>3.21<FITID>C6OX1<NAME>INTEREST PAYMENT</STMTTRN>', to_char(d + 14, 'YYYYMMDD'))
              || format('<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>%s<TRNAMT>-25.00<FITID>C6OX2<NAME>C6 CARGO RARO</STMTTRN>', to_char(d + 10, 'YYYYMMDD'))
              || v_fin, '1097', 'c6-pruebas-ofx-1.qfx');
    perform fn_banco_casar_todo('1097');
    perform fn_banco_importar_ofx(v_cab || v_ini
              || format('<DTSTART>%s<DTEND>%s', to_char(d + 10, 'YYYYMMDD'), to_char(d + 25, 'YYYYMMDD'))
              || format('<STMTTRN><TRNTYPE>INT<DTPOSTED>%s<TRNAMT>3.12<FITID>C6OX1R<CORRECTFITID>C6OX1<CORRECTACTION>REPLACE'
                        || '<NAME>INTEREST PAYMENT</STMTTRN>', to_char(d + 14, 'YYYYMMDD'))
              || format('<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>%s<TRNAMT>-25.00<FITID>C6OX2D<CORRECTFITID>C6OX2<CORRECTACTION>DELETE'
                        || '<NAME>C6 CARGO RARO</STMTTRN>', to_char(d + 10, 'YYYYMMDD'))
              || v_fin, '1097', 'c6-pruebas-ofx-2.qfx');
    perform fn_banco_casar_todo('1097');
    v_obt := format('replace=%s corregido=%s delete=%s', pg_temp.c6_est('1097', 'C6OX1R'), split_part(pg_temp.c6_est('1097', 'C6OX1'), ':', 1),
                    split_part(pg_temp.c6_est('1097', 'C6OX2'), ':', 1));
    begin
      perform fn_banco_importar_ofx(v_cab || v_ini
                || format('<DTSTART>%s<DTEND>%s', to_char(d + 16, 'YYYYMMDD'), to_char(d + 20, 'YYYYMMDD'))
                || format('<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>%s<TRNAMT>-136.00<FITID>C6OX3<NAME>HOTEL TORONTO'
                          || '<CURRENCY><CURRATE>0.7353<CURSYM>CAD</CURRENCY></STMTTRN>', to_char(d + 17, 'YYYYMMDD'))
                || v_fin, '1097', 'c6-pruebas-ofx-cad.qfx');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' moneda=' || v_x;
    perform fn_banco_importar_ofx(concat_ws(E'\n',
              '<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
              '<?OFX OFXHEADER="200" VERSION="220" SECURITY="NONE" OLDFILEUID="NONE" NEWFILEUID="NONE"?>',
              '<!-- c6-pruebas: un comentario <STMTTRN> que no es un movimiento -->',
              '<OFX><BANKMSGSRSV1><STMTTRNRS><TRNUID>1</TRNUID><STATUS><CODE>0</CODE><SEVERITY>INFO</SEVERITY></STATUS><STMTRS>',
              '<CURDEF>USD</CURDEF><BANKACCTFROM><BANKID>267084131</BANKID><ACCTID>000000001097</ACCTID><ACCTTYPE>SAVINGS</ACCTTYPE>'
                || '</BANKACCTFROM>',
              '<BANKTRANLIST><DTSTART>' || to_char(d + 20, 'YYYYMMDD') || '</DTSTART><DTEND>' || to_char(d + 25, 'YYYYMMDD') || '</DTEND>',
              '<STMTTRN><TRNTYPE>DEBIT</TRNTYPE><DTPOSTED>' || to_char(d + 22, 'YYYYMMDD') || '</DTPOSTED><TRNAMT>-210.00</TRNAMT>'
                || '<FITID>C6OX4</FITID><NAME><![CDATA[C6 HOTEL & SPA]]></NAME></STMTTRN>',
              '</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>'), '1097', 'c6-pruebas-ofx-cdata.ofx');
    v_obt := v_obt || ' cdata=' || coalesce((select m.descripcion from movimientos_banco m where m.id = pg_temp.c6_mov('1097', 'C6OX4')), '-');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (127, 'el OFX: la corrección del banco, otra moneda y CDATA se leen como lo que son', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 128. LO QUE PLAID QUITA, EL SALDO CON SU FECHA Y LA MONEDA (ronda 4): el
--      lote dice lo que Plaid quitó («quitadas»): lo pendiente queda
--      ignorado con su motivo; lo ya clasificado sigue casado y lo dicen la
--      bandeja («quitada», con su botón) y el cuadre 51; des-casado, queda
--      ignorado y el control vuelve a verde. Un saldo sin su fecha
--      (saldo_al) no entra (22023), ni un lote en otra moneda (MX009).
--      Antes el lote no podía decirlo, y la quitada seguía viva.
do $$
declare
  v_obt text;
  v_esp text := 'pendiente=ignorado casado=casado bandeja=quitada:fn_banco_descasar control=f descasar=ignorado control2=t '
                'sin_fecha=22023 moneda=MX009';
  v_m   uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (128, 'Plaid: lo quitado no sigue vivo; el saldo va con su fecha; otra moneda no entra', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '9996', 'plaid_saldo', '912.40',
              'saldo_al', (d + 11)::text, 'filas', jsonb_build_array(
                jsonb_build_object('id', 'c6-plaid-q1', 'fecha', d + 10, 'plaid_monto', '812.40', 'descripcion', 'C6 CED HIALEAH'),
                jsonb_build_object('id', 'c6-plaid-q2', 'fecha', d + 10, 'plaid_monto', '100.00', 'descripcion', 'C6 SHELL OIL'))));
    v_m := pg_temp.c6_mov('2100-9996', 'c6-plaid-q2');
    perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas: gasolina de la camioneta de la obra');
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '9996', 'plaid_saldo', '0.00',
              'saldo_al', (d + 13)::text, 'quitadas', jsonb_build_array('c6-plaid-q1', 'c6-plaid-q2'), 'filas', '[]'::jsonb));
    v_obt := format('pendiente=%s casado=%s bandeja=%s', split_part(pg_temp.c6_est('2100-9996', 'c6-plaid-q1'), ':', 1),
                    split_part(pg_temp.c6_est('2100-9996', 'c6-plaid-q2'), ':', 1),
                    coalesce((select b.motivo || ':' || (b.opciones->0->>'llamar') from v_banco_bandeja b where b.movimiento_id = v_m), '-'));
    v_obt := v_obt || ' control=' || pg_temp.c6_cuadre('cuadre: un movimiento, un casado', current_setting('mx6.mes'), v_m::text);
    perform fn_banco_descasar(v_m, 'c6-pruebas: Plaid lo quitó');
    v_obt := v_obt || ' descasar=' || split_part(pg_temp.c6_est('2100-9996', 'c6-plaid-q2'), ':', 1)
             || ' control2=' || pg_temp.c6_cuadre('cuadre: un movimiento, un casado', current_setting('mx6.mes'), v_m::text);
    begin
      perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '9996', 'plaid_saldo', '10.00',
                'filas', jsonb_build_array(jsonb_build_object('id', 'c6-plaid-q3', 'fecha', d + 12, 'plaid_monto', '10.00',
                                                              'descripcion', 'C6 CAFE'))));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' sin_fecha=' || v_x;
    begin
      perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '9996', 'moneda', 'CAD',
                'filas', jsonb_build_array(jsonb_build_object('id', 'c6-plaid-q4', 'fecha', d + 12, 'plaid_monto', '136.00',
                                                              'descripcion', 'C6 HOTEL TORONTO'))));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' moneda=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (128, 'Plaid: lo quitado no sigue vivo; el saldo va con su fecha; otra moneda no entra', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- =====================================================================
-- La ronda 4, grupo 3 (3-oct): la apertura y el primer mes
-- =====================================================================

-- 129. LOS UNDEPOSITED FUNDS EN LA CONCILIACIÓN DE APERTURA (ronda 4): la
--      balanza de QuickBooks trae el registro del banco (4,800.00) y
--      «Undeposited Funds» (1,200.00: cobros recibidos y sin depositar al
--      30-sep), y c4 lleva los dos al banco (1098). Con el saldo del
--      statement (4,800.00) la conciliación de apertura no cuadra por
--      1,200.00, y su «falta» nombra el registro y los Undeposited Funds
--      (son depósitos en tránsito), sin mandar a buscar un archivo; con su
--      partida, cuadra en 0.00. Antes decía «algo del banco no está (un
--      archivo que falta, un saldo mal escrito, un ignorado…)». (Postea una
--      apertura de prueba con fn_apertura: sale «omitida» con la de verdad
--      ya posteada, o con la apertura cerrada.)
do $$
declare
  v_obt text;
  v_esp text := 'dif=1200.00 nombra=t archivo=f con_partida=0.00';
  v_c   jsonb;
  v_ap  periodos;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  if d is null or v_ap.periodo is null or v_ap.estado <> 'abierto'
     or exists (select 1 from asientos a where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                  and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    insert into _pruebas values (129, 'los Undeposited Funds de la apertura: la conciliación de apertura los nombra', v_esp,
                                 'omitida: la apertura ya está posteada (o cerrada); prueba una de prueba', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_apertura_balanza_cargar('docs/c6-pruebas/qb-apertura-uf.csv', jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'C6 Pruebas Bank 1098', 'debe', '4,800.00'),
      jsonb_build_object('cuenta_qb', 'Undeposited Funds', 'debe', '1,200.00'),
      jsonb_build_object('cuenta_qb', 'Retained Earnings', 'haber', '6,000.00'),
      jsonb_build_object('cuenta_qb', 'Net Income', 'saldo', '0.00'),
      jsonb_build_object('cuenta_qb', 'TOTAL ASSETS', 'saldo', '6,000.00'),
      jsonb_build_object('cuenta_qb', 'Total Liabilities', 'saldo', '0.00')));
    perform fn_apertura_mapeo_qb('C6 Pruebas Bank 1098', '1098');
    perform fn_apertura_mapeo_qb('Undeposited Funds', '1098', 'c6-pruebas: los cobros sin depositar, al banco');
    perform fn_apertura_mapeo_qb('Retained Earnings', '3900');
    perform fn_apertura(v_ap.desde, 'docs/c6-pruebas/qb-apertura-uf.csv');
    v_c := fn_conciliacion_apertura('1098', '4,800.00');
    v_obt := format('dif=%s nombra=%s archivo=%s', v_c->>'diferencia',
                    case when v_c->>'falta' like '%«C6 Pruebas Bank 1098»%' and v_c->>'falta' like '%«Undeposited Funds»%'
                         then 't' else 'f' end,
                    case when v_c->>'falta' like '%archivo%' then 't' else 'f' end);
    v_c := fn_conciliacion_apertura('1098', '4,800.00', jsonb_build_array(jsonb_build_object(
             'fecha', (v_ap.hasta - 1)::text, 'monto', '1200.00', 'descripcion', 'c6-pruebas: Undeposited Funds del 29-sep')));
    v_obt := v_obt || ' con_partida=' || (v_c->>'diferencia');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (129, 'los Undeposited Funds de la apertura: la conciliación de apertura los nombra', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 130. LOS PRÉSTAMOS CONTRA LA APERTURA (ronda 4): QuickBooks parte las
--      cuotas con su propia tabla y no tenía el saldo del prestamista al
--      centavo. Un préstamo de antes del corte guardado sin la apertura en
--      el libro avisa que sus saldos entran con ella; con la apertura de
--      prueba posteada (2520 en 31,428.34 y el statement en 31,415.26),
--      guardarlo avisa la diferencia y cómo se corrige la apertura, y el
--      cuadre de préstamos la nombra («la apertura (QuickBooks) trae…»).
--      Antes el cuadre mandaba a «registrar un préstamo, su desembolso o
--      una cuota» y guardar no decía nada. (Postea una apertura de prueba:
--      sale «omitida» con la de verdad ya posteada, o con la apertura
--      cerrada.)
do $$
declare
  v_obt text;
  v_esp text := 'sin_apertura=t con_apertura=t cuadre=f';
  v_r   jsonb;
  v_ap  periodos;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  select * into v_ap from periodos p where p.tipo = 'apertura' order by p.desde limit 1;
  if d is null or v_ap.periodo is null or v_ap.estado <> 'abierto'
     or exists (select 1 from asientos a where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                  and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    insert into _pruebas values (130, 'los préstamos contra la apertura: guardar lo avisa y el cuadre nombra la apertura', v_esp,
                                 'omitida: la apertura ya está posteada (o cerrada); prueba una de prueba', null);
    return;
  end if;
  -- (ronda 5: con préstamos de antes del corte ya registrados —el bloque de
  -- los préstamos de la apertura, o uno a mano con su saldo— el cuadre los
  -- mezcla con el de prueba y su detalle es otro: la prueba no mide nada)
  if exists (select 1 from prestamos p where p.estado <> 'cancelado' and p.saldo_inicial_al < fn_puente_corte()) then
    insert into _pruebas values (130, 'los préstamos contra la apertura: guardar lo avisa y el cuadre nombra la apertura', v_esp,
                                 'omitida: hay préstamos de antes del corte registrados (el cuadre los mezcla con el de prueba)', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_r := fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS CREDIT', 'descripcion', 'camioneta de prueba (apertura)',
             'principal', '52000.00', 'tasa_anual', '6.99', 'cuota', '1029.33', 'primer_pago', '2024-03-15', 'dia_pago', 15,
             'plazo_meses', 60, 'saldo_inicial', '31415.26', 'saldo_inicial_al', v_ap.hasta::text, 'cuenta_banco', '1098',
             'descriptor', 'C6 PRUEBAS CREDIT'));
    v_obt := 'sin_apertura=' || case when v_r->>'aviso' like 'La apertura todavía no está en el libro%' then 't' else 'f' end;
    perform fn_apertura_balanza_cargar('docs/c6-pruebas/qb-apertura-prestamo.csv', jsonb_build_array(
      jsonb_build_object('cuenta_qb', 'C6 Pruebas Loan F-150', 'haber', '31,428.34'),
      jsonb_build_object('cuenta_qb', 'Retained Earnings', 'debe', '31,428.34'),
      jsonb_build_object('cuenta_qb', 'Net Income', 'saldo', '0.00'),
      jsonb_build_object('cuenta_qb', 'TOTAL ASSETS', 'saldo', '0.00'),
      jsonb_build_object('cuenta_qb', 'Total Liabilities', 'saldo', '31,428.34')));
    perform fn_apertura_mapeo_qb('C6 Pruebas Loan F-150', '2520');
    perform fn_apertura_mapeo_qb('Retained Earnings', '3900');
    perform fn_apertura(v_ap.desde, 'docs/c6-pruebas/qb-apertura-prestamo.csv');
    v_r := fn_prestamo_guardar(jsonb_build_object('id', v_r->>'id', 'notas', 'c6-pruebas: con la apertura posteada'));
    v_obt := v_obt || ' con_apertura='
             || case when v_r->>'aviso' like '%la apertura (QuickBooks) trae 31428.34%' then 't' else 'f' end
             || ' cuadre=' || pg_temp.c6_cuadre('cuadre: préstamos', current_setting('mx6.mes'),
                                                 'la apertura (QuickBooks) trae 31428.34');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (130, 'los préstamos contra la apertura: guardar lo avisa y el cuadre nombra la apertura', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 131. HASTA EL FIN DEL MES (ronda 4): la tarjeta corta su statement a
--      mitad de mes (la Blue el 7, la Gold el 22) y lo de después llega con
--      el siguiente. Terminado el mes (el reloj fingido, al día siguiente) y
--      sin cerrar, con el archivo de la tarjeta hasta el 7: v_banco_saldos
--      dice hasta dónde llegan sus archivos (cubierto_hasta) y el mes al que
--      no llegan (mes_sin_cubrir, también en la alarma), y el control entero
--      (p_vistas nulo: lo de antes de cerrar) lo pone en rojo con la cuenta;
--      ninguna pantalla lo pide (v_banco_saldos sola, sin esa fila). Con la
--      actividad reciente hasta el último día, en verde. Antes nada lo
--      decía y el mes se cerraba sin las compras del 8 al 31.
do $$
declare
  v_obt text;
  v_esp text := 'cubierto=7 mes=t alarma=t cuadre=f pantalla=0 completo=t sin_mes=t';
  v_fin date;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (131, 'el mes terminado al que una cuenta no llega: v_banco_saldos y el control lo dicen', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  v_fin := (d + interval '1 month')::date - 1;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 6, -58.75, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 1, 'monto', '-58.75', 'id', 'C6FM1', 'nombre', 'C6 SHELL OIL 57444'))),
            null, 'c6-pruebas-corte-7.qfx');
    perform pg_temp.c6_fingir_hoy(v_fin + 1);
    select format('cubierto=%s mes=%s alarma=%s', extract(day from s.cubierto_hasta)::int,
                  case when s.mes_sin_cubrir = current_setting('mx6.mes') then 't' else 'f' end,
                  case when s.alarma and s.alarma_texto like '%' || current_setting('mx6.mes') || '%' then 't' else 'f' end)
      into v_obt from v_banco_saldos s where s.cuenta = '2100-9996';
    v_obt := v_obt || ' cuadre=' || pg_temp.c6_cuadre('cuadre: cada cuenta hasta el fin del mes', current_setting('mx6.mes'), '2100-9996')
             || ' pantalla=' || (select count(*) from fn_banco_control(current_setting('mx6.mes'), array['v_banco_saldos']) c
                                  where c.vista = 'cuadre: cada cuenta hasta el fin del mes');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d + 7, v_fin, -82.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 20, 'monto', '-23.25', 'id', 'C6FM2', 'nombre', 'C6 PUBLIX #1123'))),
            null, 'c6-pruebas-actividad-reciente.qfx');
    v_obt := v_obt || ' completo=' || pg_temp.c6_cuadre('cuadre: cada cuenta hasta el fin del mes', current_setting('mx6.mes'),
                                                         '2100-9996')
             || ' sin_mes=' || (select case when s.mes_sin_cubrir is null and s.cubierto_hasta = v_fin then 't' else 'f' end
                                  from v_banco_saldos s where s.cuenta = '2100-9996');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa el banco (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (131, 'el mes terminado al que una cuenta no llega: v_banco_saldos y el control lo dicen', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 132. SU TICKET YA SUBIDO, ESPERANDO EN LA BANDEJA DE LOS PUENTES (ronda 4):
--      un ticket de la tarjeta sin sus 4 últimos (c3 lo deja esperando: la
--      lectura no los trajo; igual con la obra que falta, su regla en
--      borrador…) y el cargo de la tarjeta por su monto: la bandeja del
--      banco dice «ticket_en_bandeja» con ese recibo, clasificar el cargo
--      sin motivo es MX008 (el gasto entraría dos veces en cuanto el ticket
--      entre), y escritos sus 4 últimos (lo que pide c3), el ticket entra y
--      el cargo casa solo con él. Antes la bandeja decía «sin_ticket»
--      («súbela») y se clasificaba sin decir nada.
do $$
declare
  v_obt text;
  v_esp text := 'espera=t bandeja=ticket_en_bandeja:t clasificar=MX008 resuelto=casado:recibo';
  v_m   uuid;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (132, 'el ticket que espera en la bandeja de los puentes: se dice y no deja clasificar sin motivo',
                                 v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -661321, 'total', 84.37, 'fecha', d + 4, 'proveedor', 'C6 FERRETERIA',
                                                 'ultimos4', null));
    v_obt := 'espera=' || case when exists (select 1 from puente_documentos pd
                                             where pd.tabla = 'recibos' and pd.documento_id = '-661321'
                                               and pd.estado in ('pendiente', 'espera', 'error'))
                               then 't' else 'f' end;
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'fecha_usuario', d + 4, 'monto', '-84.37', 'id', 'C6TB1',
                                 'nombre', 'C6 FERRETERIA #12 MIAMI FL'))),
            null, 'c6-pruebas-ticket-en-bandeja.qfx');
    perform fn_banco_casar_todo('2100-9996');
    v_m := pg_temp.c6_mov('2100-9996', 'C6TB1');
    select format(' bandeja=%s:%s', m.propuesta->>'motivo',
                  case when exists (select 1 from jsonb_array_elements(coalesce(m.propuesta->'tickets_bandeja', '[]'::jsonb)) t
                                     where t->>'recibo' = '-661321') then 't' else 'f' end)
      into v_x from movimientos_banco m where m.id = v_m;
    v_obt := v_obt || v_x;
    begin
      perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' clasificar=' || v_x;
    update recibos set ultimos4 = '9996' where id = -661321;
    perform fn_banco_casar_todo('2100-9996');
    v_obt := v_obt || ' resuelto=' || pg_temp.c6_est('2100-9996', 'C6TB1');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (132, 'el ticket que espera en la bandeja de los puentes: se dice y no deja clasificar sin motivo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 133. EL TICKET DE UN CARGO YA CLASIFICADO QUE LLEGA CON EL MES CERRADO
--      (ronda 4): la compra con la débito del último día, clasificada; la
--      conciliación del mes, confirmada; el mes, cerrado. Llega su ticket
--      (c3 lo postea el día 1, tardío) y se cambia por la clasificación SIN
--      reabrir: la clasificación se reversa el día 1 y al corte el cargo
--      casaba con ella, así que la conciliación sigue confirmada y diciendo
--      lo mismo (sin partidas: ni un «cargo en circulación» que nunca
--      circuló ni algo «en libros después»; recalculada, igual a la guardada
--      y con el mismo saldo en libros), su casado lo explica («Al corte
--      casaba con…») y el cuadre 54 no lo nombra. Antes había que reabrirla
--      (MX008) y, rehecha, la clasificación salía como cargo en circulación.
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=llego_su_ticket cambio=casado:recibo sigue=confirmada partidas=0 igual=t nota=t control54=t';
  v_c   jsonb;
  v_id  uuid;
  v_m   uuid;
  v_fin date;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or current_setting('mx6.sig', true) = '' then
    insert into _pruebas values (133, 'el ticket de un cargo clasificado con el mes cerrado: se cambia sin reabrir y sin fantasma',
                                 v_esp, 'omitida: falta mes abierto o el siguiente', null);
    return;
  end if;
  v_fin := (d + interval '1 month')::date - 1;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, v_fin, -233.10, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', v_fin, 'monto', '-233.10', 'id', 'C6TT1',
                                 'nombre', 'C6 FERRETERIA #12 MIAMI FL CARD 0001'))),
            '1098', 'c6-pruebas-ticket-tardio-clasificado.qfx');
    v_m := pg_temp.c6_mov('1098', 'C6TT1');
    -- (con su motivo: no mira la propuesta, y no hace falta «Casar» antes)
    perform fn_banco_clasificar(v_m, jsonb_build_array(jsonb_build_object('cuenta', '5100', 'proyecto_id', current_setting('mx6.obra'))),
                                'c6-pruebas: material de la obra, el ticket todavía no ha llegado');
    v_c := fn_conciliar('1098', v_fin, '-233.10');
    v_id := (v_c->>'conciliacion')::uuid;
    perform fn_conciliacion_confirmar(v_id);
    perform pg_temp.c6_cerrar_hasta(current_setting('mx6.mes'));
    perform pg_temp.c6_recibo(jsonb_build_object('id', -661331, 'total', 233.10, 'fecha', v_fin - 1, 'metodo_pago', 'debito',
                                                 'proveedor', 'C6 FERRETERIA'));
    perform fn_banco_casar_todo('1098');
    v_obt := 'bandeja=' || coalesce((select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_m), '-');
    perform fn_banco_casar_con(v_m, jsonb_build_object('recibo', -661331));
    v_obt := v_obt || format(' cambio=%s sigue=%s partidas=%s', pg_temp.c6_est('1098', 'C6TT1'),
                             (select c.estado from conciliaciones c where c.id = v_id),
                             (select count(*) from fn_conciliacion_items('1098', v_fin, false)));
    v_obt := v_obt || ' igual='
             || case when not exists ((select i.lado, i.asiento_id, i.orden, i.movimiento_id, i.apertura_partida_id, i.monto
                                         from fn_conciliacion_items('1098', v_fin, false) i
                                       except all
                                       select p.lado, p.asiento_id, p.orden, p.movimiento_id, p.apertura_partida_id, p.monto
                                         from conciliacion_partidas p where p.conciliacion_id = v_id)
                                      union all
                                      (select p.lado, p.asiento_id, p.orden, p.movimiento_id, p.apertura_partida_id, p.monto
                                         from conciliacion_partidas p where p.conciliacion_id = v_id
                                       except all
                                       select i.lado, i.asiento_id, i.orden, i.movimiento_id, i.apertura_partida_id, i.monto
                                         from fn_conciliacion_items('1098', v_fin, false) i))
                          and (select c.saldo_libros from conciliaciones c where c.id = v_id)
                              = (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                                  where l.cuenta = '1098' and a.fecha_contable <= v_fin)
                     then 't' else 'f' end
             || ' nota=' || case when exists (select 1 from v_conciliacion_partidas p
                                               where p.conciliacion_id = v_id and p.grupo = 'casado' and p.movimiento_id = v_m
                                                 and p.explicacion like '%Al corte casaba con%') then 't' else 'f' end
             || ' control54=' || pg_temp.c6_cuadre('cuadre: conciliaciones confirmadas', current_setting('mx6.mes'), v_m::text);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate '55P03' then v_obt := 'omitida: la app usa periodos (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (133, 'el ticket de un cargo clasificado con el mes cerrado: se cambia sin reabrir y sin fantasma', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 134. NINGUNA FUNCIÓN DEL BANCO NOMBRA UNA DE c4 CON SU PARÉNTESIS SIN
--      LLAMARLA (ronda 4, el tiempo en producción): «protecciones de c4»
--      (en cada pantalla de cifras) y el control «permisos» de c2 buscan en
--      el texto de cada función las llamadas a las suyas: un nombre y «(».
--      fn_banco_control nombraba 'public.fn_estados_huellas()' y
--      'fn_estados_version()' dentro de sus cadenas, y c4 creía que las
--      llamaba: una vuelta más de lo ajeno en cada pantalla, si el banco no
--      está sellado o cambió (sellado y sin cambios, c4 ya no lo lee). Ahora
--      el nombre va partido ('…_huellas' || '()'). En el texto de cada
--      función de c6 (sin sus comentarios), ningún nombre de una función de
--      c4 seguido de «(» (si un día una la llama de verdad, va en la lista
--      de abajo). Antes salía fn_banco_control. Sin c4, «omitida».
do $$
declare
  v_esp   text := 'ninguna';
  v_obt   text;
  v_rx    text;
  v_llama text[] := '{}';   -- las de c6 que llaman de verdad a una de c4
begin
  select '[[:<:]](' || string_agg(distinct p.proname::text, '|') || ')[[:space:]]*[(]' into v_rx
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname ~ '^[[:alnum:]_]+$'
     and (p.proname like 'fn\_estados\_%' or p.proname like 'fn\_apertura%' or p.proname like 'fn\_comparacion\_%'
          or p.proname like 'fn\_diferencia\_%');
  if v_rx is null then
    insert into _pruebas values (134, 'ninguna función del banco nombra una de c4 con su paréntesis sin llamarla', v_esp,
                                 'omitida: sin c4', null);
    return;
  end if;
  select coalesce(string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text), 'ninguna') into v_obt
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'
     and (p.proname like 'fn\_banco\_%' or p.proname like 'fn\_conciliacion\_%' or p.proname = 'fn_conciliar'
          or p.proname like 'fn\_prestamo\_%' or p.proname like 'fn\_prepagado%')
     and not (p.oid::regprocedure::text = any (v_llama))
     and regexp_replace(regexp_replace(p.prosrc, '/\*.*?\*/', ' ', 'g'), '--[^\n]*', ' ', 'g') ~* v_rx;
  insert into _pruebas values (134, 'ninguna función del banco nombra una de c4 con su paréntesis sin llamarla', v_esp, v_obt,
                               v_obt = v_esp);
end $$;

-- 135. EL DINERO DE (Y A) UNA CUENTA QUE NO SE CONOCE (ronda 4b; x13b y
--      x13c de la prueba final): el banco nombra la cuenta ····7781 («TO
--      SAV ...7781», «FROM CHK ...7781»), que no es de ningún estado de
--      cuenta ni tarjeta de la empresa ni está dada de alta como personal,
--      y el depósito es del mismo monto que una factura abierta. Los dos son
--      «cuenta_desconocida»: ningún botón al patrimonio del accionista ni a
--      otra cuenta propia entra sin motivo (todos piden su motivo), el de la
--      factura entra tal cual, y el préstamo del accionista pulsado tal cual
--      es MX008; con su motivo escrito entra y el cuadre 52 sigue en verde.
--      Antes los dos eran «transferencia_personal», con 3200, 1130, 2900 y
--      3100 sin motivo, y el 2900 tal cual dejaba el cuadre 52 en rojo («lo
--      explica la factura»).
do $$
declare
  v_obt  text;
  v_esp  text := 'retiro=cuenta_desconocida deposito=cuenta_desconocida sin_motivo=0 3200_tal_cual=MX008 factura=ok '
                 '2900_tal_cual=MX008 2900_con_motivo=casado:clasificado control52=t';
  v_obra text := current_setting('mx6.obra', true);
  v_r    uuid;
  v_dp   uuid;
  v_o    jsonb;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (135, 'el dinero de y a una cuenta que no se conoce: nada al patrimonio sin su motivo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661351, v_obra, 'C6-1351', d + 1, 5000.00, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, 3000.00, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 4, 'monto', '-2000.00', 'id', 'C6DS1', 'nombre', 'ONLINE TRANSFER TO SAV ...7781 T',
                                 'memo', 'ONLINE TRANSFER TO SAV ...7781 TRANSACTION#: 21877123456'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 5, 'monto', '5000.00', 'id', 'C6DS2', 'nombre', 'ONLINE TRANSFER FROM CHK ...778',
                                 'memo', 'ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 21877129999'))),
            '1098', 'c6-pruebas-desconocida.qfx');
    perform fn_banco_casar_todo('1098');
    v_r := pg_temp.c6_mov('1098', 'C6DS1');
    v_dp := pg_temp.c6_mov('1098', 'C6DS2');
    -- (los botones del depósito los marca también el aviso de la apertura sin
    -- conciliar de los primeros 30 días: se cuentan los del retiro, y los dos
    -- se pulsan tal cual)
    v_obt := format('retiro=%s deposito=%s sin_motivo=%s 3200_tal_cual=%s factura=%s',
                    (select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_r),
                    (select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_dp),
                    (select count(*) from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                      where m.id = v_r and o->>'llamar' in ('fn_banco_clasificar', 'fn_banco_transferencia')
                        and not coalesce((o->>'pide_motivo')::boolean, false)),
                    (select pg_temp.c6_pulsar(o) from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                      where m.id = v_r and o->'args'->'p_lineas'->0->>'cuenta' = '3200' limit 1),
                    (select pg_temp.c6_pulsar(o) from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                      where m.id = v_dp and o->>'llamar' = 'fn_banco_cobrar' limit 1));
    select o into v_o from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_dp and o->'args'->'p_lineas'->0->>'cuenta' = '2900';
    v_obt := v_obt || ' 2900_tal_cual=' || pg_temp.c6_pulsar(v_o);
    perform fn_banco_clasificar(v_dp, v_o->'args'->'p_lineas', 'c6-pruebas: es dinero de Edgar desde su cuenta personal');
    v_obt := v_obt || format(' 2900_con_motivo=%s control52=%s', pg_temp.c6_est('1098', 'C6DS2'),
                             pg_temp.c6_cuadre('cuadre: depósitos nunca a ingreso', current_setting('mx6.mes'), v_dp::text));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (135, 'el dinero de y a una cuenta que no se conoce: nada al patrimonio sin su motivo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 136. LA CUENTA PERSONAL DE EDGAR SE DA DE ALTA A PROPÓSITO (ronda 4b):
--      fn_banco_cuenta_personal la da de alta (con rastro en
--      banco_historial) y de baja solo con su motivo (MX008 sin él); no da
--      de alta el número de una tarjeta de la empresa (MX004); con ella dada
--      de alta, su estado de cuenta no se sube (MX004: no es de la
--      empresa), nadie la escribe por fuera de su función (MX003), y R3 no
--      junta el retiro a ella con el depósito que llega de ella a la
--      reserva (los dos nombran ····7781: no son el uno del otro, y es
--      patrimonio). Antes no había cómo darla de alta, y R3 los casaba como
--      una transferencia de 1098 a 1097.
do $$
declare
  v_obt text;
  v_esp text := 'alta=true historial=1 tarjeta=MX004 a_mano=MX003 estado_de_cuenta=MX004 '
                'r3=pendiente:transferencia_personal/pendiente:transferencia_personal baja=MX008/false';
  v_x   text;
  v_h0  bigint;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (136, 'la cuenta personal se da de alta a propósito, con rastro, y R3 no la toma por otra propia', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    -- (ronda 4c: el rastro de ESTA alta; con una ····7781 de verdad ya dada
    -- de alta —y dada de baja aquí por c6_montar—, su historial ya tenía filas)
    v_h0 := (select count(*) from banco_historial h where h.tabla = 'banco_cuentas_personales' and h.clave = '7781');
    v_obt := 'alta=' || (fn_banco_cuenta_personal('7781', 'c6-pruebas: Chase personal de Edgar')->>'activa');
    v_obt := v_obt || ' historial='
             || ((select count(*) from banco_historial h where h.tabla = 'banco_cuentas_personales' and h.clave = '7781') - v_h0);
    begin
      perform fn_banco_cuenta_personal('9996', 'c6-pruebas: no es personal');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' tarjeta=' || v_x;
    begin
      insert into banco_cuentas_personales (ultimos4, nombre) values ('7782', 'c6-pruebas: a mano');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' a_mano=' || v_x;
    begin
      perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000007781', d, d + 5, 10.00, jsonb_build_array(
                jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 2, 'monto', '-10.00', 'id', 'C6PZ0', 'nombre', 'NETFLIX.COM'))),
              '1097', 'c6-pruebas-personal.qfx');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' estado_de_cuenta=' || v_x;
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 15, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 12, 'monto', '-500.00', 'id', 'C6PZ1', 'nombre', 'ONLINE TRANSFER TO CHK ...7781'))),
            '1098', 'c6-pruebas-a-la-personal.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 15, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 12, 'monto', '500.00', 'id', 'C6PZ2', 'nombre', 'ONLINE TRANSFER FROM CHK ...7781'))),
            '1097', 'c6-pruebas-desde-la-personal.ofx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_casar_todo('1097');
    v_obt := v_obt || format(' r3=%s/%s', pg_temp.c6_est('1098', 'C6PZ1'), pg_temp.c6_est('1097', 'C6PZ2'));
    begin
      perform fn_banco_cuenta_personal('7781', null, false);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' baja=' || v_x || '/'
             || (fn_banco_cuenta_personal('7781', null, false, 'c6-pruebas: la cerró')->>'activa');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (136, 'la cuenta personal se da de alta a propósito, con rastro, y R3 no la toma por otra propia', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 137. EL PRIMER PASE A LA RESERVA RECIÉN ABIERTA, ANTES DE SU PRIMER
--      ESTADO DE CUENTA (ronda 4b; x14, x15 y x16 de la prueba final): el
--      banco nombra «SAV ····1097» y nada lo reconoce todavía. La propuesta
--      es «cuenta_desconocida» y ningún botón entra sin motivo; «A 1097» sin
--      él es MX008. Su número dado de alta antes, con un lote vacío
--      confirmado («confirmo_cuenta»), no cambia nada de v_banco_saldos de
--      esa cuenta (nada en rojo), y la propuesta pasa a ser la transferencia
--      «A 1097», sin motivo: entra «en tránsito» y, cuando llega el estado
--      de cuenta de la reserva, su lado casa solo con ESE asiento. Antes la
--      primera opción era «Para Edgar (su cuenta ····1097): distribución ·
--      3200», sin motivo y en verde.
do $$
declare
  v_obt  text;
  v_esp  text := 'antes=cuenta_desconocida sin_motivo=0 a_1097=MX008 alta=1097 saldos=true despues=transferencia_un_lado:1097:f '
                 'boton=en_transito:transferencia reserva=casado:transferencia mismo_asiento=t';
  v_m    uuid;
  v_s0   text;
  v_x    text;
  v_o    jsonb;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (137, 'el primer pase a la reserva recién abierta: se pregunta, o se da de alta su número', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 25, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 24, 'monto', '-2000.00', 'id', 'C6RN1',
                                 'nombre', 'ONLINE TRANSFER TO SAV XXXXXX1097'))),
            '1098', 'c6-pruebas-pase.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6RN1');
    v_obt := format('antes=%s sin_motivo=%s', (select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_m),
                    (select count(*) from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                      where m.id = v_m and not coalesce((o->>'pide_motivo')::boolean, false)));
    begin
      perform fn_banco_transferencia(v_m, '1097');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' a_1097=' || v_x;
    select string_agg(concat_ws(':', s.alarma, s.mes_sin_cubrir, s.cubierto_hasta, s.saldo_banco), ',') into v_s0
      from v_banco_saldos s where s.cuenta = '1097';
    v_obt := v_obt || ' alta=' || (fn_banco_importar_filas(jsonb_build_object(
               'origen', 'mano', 'cuenta', '1097', 'ultimos4', '1097', 'confirmo_cuenta', true,
               'nombre', 'c6-pruebas: el número de la reserva', 'filas', '[]'::jsonb))->>'cuenta');
    v_obt := v_obt || ' saldos=' || ((select string_agg(concat_ws(':', s.alarma, s.mes_sin_cubrir, s.cubierto_hasta, s.saldo_banco), ',')
                                        from v_banco_saldos s where s.cuenta = '1097') is not distinct from v_s0)::text;
    perform fn_banco_casar_todo('1098');
    select m.propuesta->'opciones'->0 into v_o from movimientos_banco m where m.id = v_m;
    v_obt := v_obt || format(' despues=%s:%s:%s', (select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_m),
                             v_o->'args'->>'p_cuenta', coalesce((v_o->>'pide_motivo')::boolean, false));
    perform fn_banco_transferencia(v_m, v_o->'args'->>'p_cuenta', v_o->'args'->>'p_motivo');
    v_obt := v_obt || ' boton=' || pg_temp.c6_est('1098', 'C6RN1');
    perform fn_banco_importar_ofx(pg_temp.c6_reserva(), '1097', 'c6-pruebas-reserva.ofx');
    perform fn_banco_casar_todo('1097');
    v_obt := v_obt || format(' reserva=%s mismo_asiento=%s', pg_temp.c6_est('1097', 'C6R1'),
                             (select m1.asiento_id = m2.asiento_id from movimientos_banco m1, movimientos_banco m2
                               where m1.id = v_m and m2.id = pg_temp.c6_mov('1097', 'C6R1')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (137, 'el primer pase a la reserva recién abierta: se pregunta, o se da de alta su número', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 138. EL PASE TOMADO POR UNA DISTRIBUCIÓN, CUANDO LLEGA LA RESERVA (ronda
--      4b; la cola de x14): el pase a la reserva sin su estado de cuenta se
--      clasificó (con su motivo) a 3200. Al llegar el de la reserva, su
--      depósito es «otro_lado_clasificado»: el primer botón des-casa aquel
--      (con su motivo), «Desde 1098» sin motivo es MX008, y des-casado los
--      dos casan solos como una transferencia: 3200 vuelve a 0.00. Antes el
--      depósito proponía «Desde 1098» sin motivo y nada decía que el pase
--      se había tomado por una distribución (1098 con un cargo que su banco
--      no iba a traer, y 3200 con 2,000.00 de más).
do $$
declare
  v_obt  text;
  v_esp  text := 'clasificado=casado:clasificado reserva=pendiente:otro_lado_clasificado boton1=fn_banco_descasar:t desde_1098=MX008 '
                 'retiro=casado:transferencia reserva2=casado:transferencia 3200=0.00';
  v_m    uuid;
  v_r    uuid;
  v_x    text;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (138, 'el pase tomado por una distribución: al llegar la reserva se dice y se des-casa', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 25, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 24, 'monto', '-2000.00', 'id', 'C6RB1',
                                 'nombre', 'ONLINE TRANSFER TO SAV XXXXXX1097'))),
            '1098', 'c6-pruebas-pase.qfx');
    v_m := pg_temp.c6_mov('1098', 'C6RB1');
    perform fn_banco_clasificar(v_m, '[{"cuenta": "3200"}]'::jsonb, 'c6-pruebas: creí que era para mí');
    v_obt := 'clasificado=' || pg_temp.c6_est('1098', 'C6RB1');
    perform fn_banco_importar_ofx(pg_temp.c6_reserva(), '1097', 'c6-pruebas-reserva.ofx');
    perform fn_banco_casar_todo('1097');
    v_r := pg_temp.c6_mov('1097', 'C6R1');
    v_obt := v_obt || format(' reserva=%s boton1=%s:%s', pg_temp.c6_est('1097', 'C6R1'),
                             (select m.propuesta->'opciones'->0->>'llamar' from movimientos_banco m where m.id = v_r),
                             (select coalesce((m.propuesta->'opciones'->0->>'pide_motivo')::boolean, false)
                                from movimientos_banco m where m.id = v_r));
    begin
      perform fn_banco_transferencia(v_r, '1098');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' desde_1098=' || v_x;
    perform fn_banco_descasar(v_m, 'c6-pruebas: era el pase a la reserva');
    v_obt := v_obt || format(' retiro=%s reserva2=%s 3200=%s', pg_temp.c6_est('1098', 'C6RB1'), pg_temp.c6_est('1097', 'C6R1'),
                             (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                               where l.cuenta = '3200' and a.origen_tabla = 'movimientos_banco' and a.origen_id = v_m::text));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (138, 'el pase tomado por una distribución: al llegar la reserva se dice y se des-casa', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 139. LA TARJETA NUEVA ANTES DE SU PRIMER STATEMENT Y LA PERSONAL DADA DE
--      ALTA EN 2900 (ronda 4b): el pago «PAYMENT TO CHASE CARD ENDING IN
--      5555» nombra una tarjeta que nada reconoce: «cuenta_desconocida» y
--      ningún botón sin motivo; dada de alta en su cuenta (fn_tarjeta_alta),
--      la propuesta es la transferencia a esa tarjeta, sin motivo. El de
--      ····7776, la personal de Edgar dada de alta en 2900 (c3, para sus
--      tickets), es «transferencia_personal»: primero el pago de su tarjeta
--      contra 2900, y entra tal cual. 2900 no es nunca una «tarjeta propia»
--      (ninguna transferencia a 2900). Antes los dos ofrecían las tarjetas
--      de la empresa sin motivo, y el de ····7776 también «A 2900».
do $$
declare
  v_obt  text;
  v_esp  text := 'nueva=cuenta_desconocida:0 a_2900=no personal=transferencia_personal:2900:f boton=ok '
                 'alta=transferencia_un_lado:2100-9995:f';
  v_o    jsonb;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (139, 'la tarjeta nueva sin statement se pregunta; la personal en 2900 es patrimonio', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_tarjeta_alta('7776', '2900', 'c6-pruebas: la personal de Edgar, para sus tickets');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 10, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 6, 'monto', '-800.00', 'id', 'C6TN1',
                                 'nombre', 'PAYMENT TO CHASE CARD ENDING IN 5555'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 7, 'monto', '-300.00', 'id', 'C6TN2',
                                 'nombre', 'PAYMENT TO CHASE CARD ENDING IN 7776'))),
            '1098', 'c6-pruebas-tarjetas.qfx');
    perform fn_banco_casar_todo('1098');
    select m.propuesta->'opciones'->0 into v_o from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6TN2');
    v_obt := format('nueva=%s:%s a_2900=%s personal=%s:%s:%s boton=%s',
                    (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6TN1')),
                    (select count(*) from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                      where m.id = pg_temp.c6_mov('1098', 'C6TN1') and not coalesce((o->>'pide_motivo')::boolean, false)),
                    case when exists (select 1 from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                                       where m.cuenta = '1098' and m.id_externo in ('C6TN1', 'C6TN2')
                                         and o->'args'->>'p_cuenta' = '2900') then 'si' else 'no' end,
                    (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6TN2')),
                    v_o->'args'->'p_lineas'->0->>'cuenta', coalesce((v_o->>'pide_motivo')::boolean, false), pg_temp.c6_pulsar(v_o));
    perform fn_tarjeta_alta('5555', '2100-9995', 'c6-pruebas: la tarjeta nueva');
    perform fn_banco_casar_todo('1098');
    select m.propuesta->'opciones'->0 into v_o from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6TN1');
    v_obt := v_obt || format(' alta=%s:%s:%s',
                             (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6TN1')),
                             v_o->'args'->>'p_cuenta', coalesce((v_o->>'pide_motivo')::boolean, false));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (139, 'la tarjeta nueva sin statement se pregunta; la personal en 2900 es patrimonio', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 140. LA CONCILIACIÓN DEL MES SIN LA DE APERTURA CONFIRMADA (ronda 4b):
--      con la apertura posteada (una de prueba, con el banco 1098 en ella:
--      «omitida» si la de verdad ya está posteada, como la 109) y su
--      conciliación de apertura por hacer, la del mes no cuadra por lo que
--      QuickBooks tenía en tránsito, y su «falta» lo dice: falta la
--      conciliación de apertura de 1098; hecha y sin confirmar, que no está
--      confirmada. Antes decía «la diferencia es 100.00: algo del banco no
--      está (un archivo que falta, un saldo mal escrito, un ignorado…)».
do $$
declare
  v_obt  text;
  v_esp  text := 'sin_ella=true abierta=true';
  v_c    jsonb;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null or d <> fn_puente_corte()
     or (select p.estado from periodos p where p.tipo = 'apertura' order by p.desde limit 1) is distinct from 'abierto'
     or exists (select 1 from asientos a where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                  and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    insert into _pruebas values (140, 'la conciliación del mes sin la de apertura confirmada lo dice', v_esp,
                                 'omitida: la apertura ya está posteada (o cerrada), o el mes abierto más antiguo no es el primero '
                                 'después del corte', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_postear(jsonb_build_object('tipo', 'apertura',
      'fecha', (select p.hasta from periodos p where p.tipo = 'apertura' order by p.desde limit 1)::text,
      'descripcion', 'c6-pruebas: apertura con el banco de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '100.00'),
                                  jsonb_build_object('cuenta', '3900', 'monto', '-100.00'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 10, 0.00, '[]'::jsonb), '1098',
                                  'c6-pruebas-mes-sin-apertura.qfx');
    v_c := fn_conciliar('1098', d + 10, '0.00');
    v_obt := 'sin_ella=' || (position('falta la conciliación de apertura de 1098' in coalesce(v_c->>'falta', '')) > 0)::text;
    perform fn_conciliacion_apertura('1098', '0.00', '[]'::jsonb);
    v_c := fn_conciliar('1098', d + 10, '0.00');
    v_obt := v_obt || ' abierta=' || (position('no está confirmada' in coalesce(v_c->>'falta', '')) > 0)::text;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (140, 'la conciliación del mes sin la de apertura confirmada lo dice', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 141. EL ANTICIPO DE UNA OBRA CUANDO UNAS FACTURAS EXPLICAN EL DEPÓSITO
--      (ronda 4b; la observación H08 de la prueba final): el lote de
--      QuickBooks Payments de dos facturas (neto de sus comisiones) y el
--      depósito del monto de una factura abierta no entran como anticipo
--      sin su porqué en las notas (MX008); con él, sí. El depósito que
--      nada explica entra como anticipo sin más. Antes el anticipo entraba
--      sin motivo aunque la bandeja propusiera las dos facturas.
do $$
declare
  v_obt  text;
  v_esp  text := 'lote=MX008 factura=MX008 sin_factura=casado:cobro con_notas=casado:cobro';
  v_obra text := current_setting('mx6.obra', true);
  v_x    text;
  r      record;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (141, 'el anticipo de una obra no tapa las facturas que explican el depósito', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661411, v_obra, 'C6-1411', d + 1, 1000.00, 0), (-661412, v_obra, 'C6-1412', d + 1, 2000.00, 0),
           (-661413, v_obra, 'C6-1413', d + 1, 757.57, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 12, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 9, 'monto', '2912.40', 'id', 'C6AN1', 'nombre', 'QBPAYMENTS DEPOSIT 778900'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 10, 'monto', '757.57', 'id', 'C6AN2', 'nombre', 'REMOTE DEPOSIT'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 11, 'monto', '313.13', 'id', 'C6AN3', 'nombre', 'REMOTE DEPOSIT 2'))),
            '1098', 'c6-pruebas-anticipos.qfx');
    for r in select * from (values (1, 'lote', 'C6AN1'), (2, 'factura', 'C6AN2'), (3, 'sin_factura', 'C6AN3')) as t(o, que, fitid)
              order by o loop
      begin
        perform fn_banco_cobrar(pg_temp.c6_mov('1098', r.fitid), jsonb_build_array(jsonb_build_object('proyecto_id', v_obra)), null);
        v_x := pg_temp.c6_est('1098', r.fitid);
      exception when others then v_x := sqlstate;
      end;
      v_obt := concat_ws(' ', v_obt, r.que || '=' || v_x);
    end loop;
    perform fn_banco_cobrar(pg_temp.c6_mov('1098', 'C6AN1'), jsonb_build_array(jsonb_build_object('proyecto_id', v_obra)),
                            'c6-pruebas: de verdad es el anticipo de otra obra');
    v_obt := v_obt || ' con_notas=' || pg_temp.c6_est('1098', 'C6AN1');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (141, 'el anticipo de una obra no tapa las facturas que explican el depósito', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 142. NADA AL PATRIMONIO SIN MOTIVO, POR NINGÚN CAMINO (ronda 4b): el
--      retiro de cajero «para mí» (3200) y el Zelle de Edgar (2900, 3100)
--      piden su motivo en sus botones (pulsados tal cual, MX008), y
--      clasificar a 3200 sin él es MX008; el depósito del mismo monto que
--      una factura abierta que la bandeja propone como la devolución de una
--      compra con la débito pide su motivo en ese botón (tal cual, MX008: el
--      cuadre 52 lo pondría en rojo); un
--      descriptor (lo que casa solo, R7) no lleva a 3100 ni un préstamo
--      vive en 2900 (MX004). Antes «Para mí · 3200» y los del Zelle entraban
--      con solo pulsarlos, y la devolución pulsada tal cual dejaba el
--      control en rojo.
do $$
declare
  v_obt  text;
  v_esp  text := 'cajero=t zelle=MX008 para_mi=MX008 devolucion=MX008 descriptor=MX004 prestamo=MX004';
  v_obra text := current_setting('mx6.obra', true);
  v_x    text;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (142, 'nada al patrimonio sin motivo por ningún camino (cajero, Zelle, devolución, reglas)', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_recibo(jsonb_build_object('id', -661421, 'total', 120.00, 'fecha', d + 1, 'proveedor', 'C6 FERRETERIA QWERTY',
                                                 'metodo_pago', 'debito', 'ultimos4', null));
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661421, v_obra, 'C6-1421', d + 1, 120.00, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 10, null, jsonb_build_array(
              jsonb_build_object('tipo', 'ATM', 'fecha', d + 3, 'monto', '-200.00', 'id', 'C6PP1', 'nombre', 'ATM WITHDRAWAL 1234 MAIN ST'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 4, 'monto', '1000.00', 'id', 'C6PP2', 'nombre', 'ZELLE FROM EDGAR M'),
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 5, 'monto', '120.00', 'id', 'C6PP3', 'nombre', 'C6 FERRETERIA QWERTY REFUND'))),
            '1098', 'c6-pruebas-patrimonio.qfx');
    perform fn_banco_casar_todo('1098');
    -- (los del Zelle y la devolución, depósitos, los marca también el aviso de
    -- la apertura sin conciliar de los primeros 30 días: se pulsan tal cual)
    v_obt := format('cajero=%s zelle=%s',
                    (select coalesce(bool_and((o->>'pide_motivo')::boolean), false)
                       from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                      where m.id = pg_temp.c6_mov('1098', 'C6PP1') and o->'args'->'p_lineas'->0->>'cuenta' = '3200'),
                    (select pg_temp.c6_pulsar(m.propuesta->'opciones'->0) from movimientos_banco m
                      where m.id = pg_temp.c6_mov('1098', 'C6PP2')));
    begin
      perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6PP1'), '[{"cuenta": "3200"}]'::jsonb, null);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' para_mi=' || v_x;
    v_obt := v_obt || ' devolucion=' || coalesce((select pg_temp.c6_pulsar(o)
                                                    from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                                                   where m.id = pg_temp.c6_mov('1098', 'C6PP3') and o->>'llamar' = 'fn_banco_clasificar'
                                                   limit 1),
                                                  'sin_devolucion');
    begin
      perform fn_banco_descriptor('interes', null, '3100');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' descriptor=' || v_x;
    begin
      perform fn_prestamo_guardar(jsonb_build_object('prestamista', 'c6-pruebas: Edgar', 'principal', '1000.00', 'tasa_anual', '0',
                                                     'cuota', '100.00', 'primer_pago', (d + 30)::text, 'plazo_meses', 10,
                                                     'saldo_inicial_al', d::text, 'cuenta', '2900', 'cuenta_banco', '1098'));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' prestamo=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (142, 'nada al patrimonio sin motivo por ningún camino (cajero, Zelle, devolución, reglas)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 143. R3 Y UN NÚMERO QUE NO SE CONOCE (ronda 4c, [a]; los escenarios C, C3
--      y C4 de la prueba final de la 4b): el banco de prueba se pasa
--      2,017.43 a ····7781 (que nada reconoce) y la reserva trae ese día
--      +2,017.43 «desde CHK ...1098» (el número del banco de prueba): no son
--      el mismo dinero —uno dice que fue a otra cuenta— y R3 no los junta;
--      cuando llega el pase de verdad («TO SAV ...1097») casa ese. Ni el
--      pase a la reserva con el depósito que dice venir de ····7781, ni el
--      pago a la tarjeta ····5555 (que nada reconoce) con el pago recibido
--      en la tarjeta de prueba. Antes R3 casaba los tres pares solos: el
--      pase de verdad quedaba «en tránsito» para siempre, la aportación de
--      Edgar como un pase de 1098, y el pago de su tarjeta personal como el
--      de la tarjeta de la empresa.
do $$
declare
  v_obt text;
  v_esp text := 'c=pendiente/pendiente pase=casado:transferencia/casado:transferencia c4=pendiente/pendiente c3=pendiente/pendiente';
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (143, 'R3 no junta dos lados que se contradicen (un número que no se conoce)', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 4, 'monto', '-2017.43', 'id', 'C6KA1',
                                 'nombre', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 301'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 7, 'monto', '-717.43', 'id', 'C6KA3',
                                 'nombre', 'ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 803'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 8, 'monto', '-640.17', 'id', 'C6KA4',
                                 'nombre', 'PAYMENT TO CHASE CARD ENDING IN 5555 11/08'))),
            '1098', 'c6-pruebas-4c-r3-banco.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 5, 'monto', '2017.43', 'id', 'C6KR1',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...1098 TRANSACTION#: 302'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 8, 'monto', '717.43', 'id', 'C6KR2',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 801'))),
            '1097', 'c6-pruebas-4c-r3-reserva.ofx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 10, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 9, 'monto', '640.17', 'id', 'C6KG1',
                                 'nombre', 'PAYMENT RECEIVED - THANK YOU'))),
            null, 'c6-pruebas-4c-r3-tarjeta.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_casar_todo('1097');
    perform fn_banco_casar_todo('2100-9996');
    v_obt := format('c=%s/%s', split_part(pg_temp.c6_est('1098', 'C6KA1'), ':', 1), split_part(pg_temp.c6_est('1097', 'C6KR1'), ':', 1));
    -- (llega el pase de verdad a la reserva, el día 5)
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 5, d + 6, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 5, 'monto', '-2017.43', 'id', 'C6KA2',
                                 'nombre', 'ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 302'))),
            '1098', 'c6-pruebas-4c-r3-banco2.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || format(' pase=%s/%s c4=%s/%s c3=%s/%s', pg_temp.c6_est('1098', 'C6KA2'), pg_temp.c6_est('1097', 'C6KR1'),
                             split_part(pg_temp.c6_est('1098', 'C6KA3'), ':', 1), split_part(pg_temp.c6_est('1097', 'C6KR2'), ':', 1),
                             split_part(pg_temp.c6_est('1098', 'C6KA4'), ':', 1), split_part(pg_temp.c6_est('2100-9996', 'C6KG1'), ':', 1));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (143, 'R3 no junta dos lados que se contradicen (un número que no se conoce)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 144. JUNTAR A MANO DOS LADOS QUE SE CONTRADICEN PIDE SU MOTIVO (ronda 4c,
--      [a]; el escenario C2): la reserva trae +917,017.43 «FROM EDGAR M
--      MARTINEZ» (sin número: nombra a alguien) y el banco de prueba
--      -917,017.43 a ····7781 (que no se conoce). (Un monto que ninguna
--      factura de verdad explica: con el libro de un año, el depósito de
--      2,017.43 salía «deposito_parcial» con «Parte de la factura #…» de
--      facturas de verdad; aquí se mira EL CRITERIO.) El depósito es
--      «otro_lado_nombrado» y el retiro «cuenta_desconocida»; ningún botón
--      de los dos entra sin motivo, y fn_banco_casar_con {movimiento} sin
--      motivo es MX008 (con él, entra). Antes el primer botón del retiro
--      («Es la transferencia con 1097…») no pedía motivo, y a mano tampoco.
do $$
declare
  v_obt text;
  v_esp text := 'reserva=otro_lado_nombrado banco=cuenta_desconocida sin_motivo=0 a_mano=MX008 con_motivo=casado:transferencia';
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (144, 'juntar a mano dos lados que se contradicen pide su motivo', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_sin_aviso();
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 6, 'monto', '917017.43', 'id', 'C6KR3',
                                 'nombre', 'ONLINE TRANSFER FROM EDGAR M MARTINEZ'))),
            '1097', 'c6-pruebas-4c-nombrado.ofx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 8, 'monto', '-917017.43', 'id', 'C6KA5',
                                 'nombre', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 401'))),
            '1098', 'c6-pruebas-4c-desconocida.qfx');
    perform fn_banco_casar_todo('1097');
    perform fn_banco_casar_todo('1098');
    v_obt := format('reserva=%s banco=%s sin_motivo=%s',
                    (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1097', 'C6KR3')),
                    (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA5')),
                    (select count(*) from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                      where m.id in (pg_temp.c6_mov('1097', 'C6KR3'), pg_temp.c6_mov('1098', 'C6KA5'))
                        and not coalesce((o->>'pide_motivo')::boolean, false)));
    begin
      perform fn_banco_casar_con(pg_temp.c6_mov('1098', 'C6KA5'), jsonb_build_object('movimiento', pg_temp.c6_mov('1097', 'C6KR3')));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' a_mano=' || v_x;
    perform fn_banco_casar_con(pg_temp.c6_mov('1098', 'C6KA5'), jsonb_build_object('movimiento', pg_temp.c6_mov('1097', 'C6KR3')),
                               'c6-pruebas: sí es el mismo dinero');
    v_obt := v_obt || ' con_motivo=' || pg_temp.c6_est('1098', 'C6KA5');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (144, 'juntar a mano dos lados que se contradicen pide su motivo', v_esp, coalesce(v_obt, '-'),
                               case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 145. «DESDE …» CON LA CUENTA PERSONAL DADA DE ALTA (ronda 4c, [b]; los
--      escenarios C2t, C2u y C3s): la reserva trae primero +2,017.43 «FROM
--      EDGAR M MARTINEZ»; su «Desde 1098» pide motivo (el banco nombra a
--      alguien, no una cuenta propia) y tal cual es MX008. Con su motivo
--      entra «en tránsito», y el pase del banco de prueba a la personal de
--      Edgar dada de alta (····7781), por lo mismo, NO casa solo con esa
--      línea (se contradicen): queda pendiente, todo con su motivo, con la
--      opción de des-casar el depósito. Igual el pago recibido en la
--      tarjeta de prueba y el pago del banco a la tarjeta personal de Edgar
--      dada de alta en 2900 (····5556): «Desde 1098» pide su motivo (lo
--      pendiente de 1098 dice que fue a otro sitio) y, con él, el pago a la
--      personal no casa solo. Antes «Desde 1098» entraba sin motivo y, en la
--      misma llamada, el pase a la personal casaba solo como la otra mitad:
--      la distribución a Edgar quedaba como un pase entre cuentas propias.
do $$
declare
  v_obt text;
  v_esp text := 'desde=t/MX008 con_motivo=en_transito banco=pendiente:transferencia_otro_lado sin_motivo=0 descasar=t '
                'tarjeta=t/MX008 tarjeta_con_motivo=en_transito pago_personal=pendiente';
  v_o   jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (145, '«Desde …» no deja que el pase a la personal dada de alta case solo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_sin_aviso();
    perform fn_banco_cuenta_personal('7781', 'c6-pruebas: Chase personal de Edgar');
    perform fn_tarjeta_alta('5556', '2900', 'c6-pruebas: la Sapphire personal de Edgar');
    -- (el número del banco de prueba lo traen sus estados de cuenta)
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 1, null, jsonb_build_array(
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 1, 'monto', '-15.00', 'id', 'C6KA0', 'nombre', 'MONTHLY SERVICE FEE'))),
            '1098', 'c6-pruebas-4c-desde-0.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 6, 'monto', '2017.43', 'id', 'C6KR4',
                                 'nombre', 'ONLINE TRANSFER FROM EDGAR M MARTINEZ'))),
            '1097', 'c6-pruebas-4c-desde.ofx');
    perform fn_banco_casar_todo('1097');
    select o into v_o from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = pg_temp.c6_mov('1097', 'C6KR4') and o->>'llamar' = 'fn_banco_transferencia' and o->'args'->>'p_cuenta' = '1098';
    v_obt := format('desde=%s/%s', coalesce((v_o->>'pide_motivo')::boolean, false), pg_temp.c6_pulsar(v_o));
    perform fn_banco_transferencia(pg_temp.c6_mov('1097', 'C6KR4'), '1098', 'c6-pruebas: creo que la pasé desde el banco');
    v_obt := v_obt || ' con_motivo=' || split_part(pg_temp.c6_est('1097', 'C6KR4'), ':', 1);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 2, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 5, 'monto', '-2017.43', 'id', 'C6KA6',
                                 'nombre', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 401'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 8, 'monto', '-640.17', 'id', 'C6KA7',
                                 'nombre', 'PAYMENT TO CHASE CARD ENDING IN 5556 11/08'))),
            '1098', 'c6-pruebas-4c-desde-1.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || format(' banco=%s sin_motivo=%s descasar=%s', pg_temp.c6_est('1098', 'C6KA6'),
                             (select count(*) from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                               where m.id = pg_temp.c6_mov('1098', 'C6KA6') and not coalesce((o->>'pide_motivo')::boolean, false)),
                             (select case when exists (select 1 from movimientos_banco m
                                                         cross join jsonb_array_elements(m.propuesta->'opciones') o
                                                        where m.id = pg_temp.c6_mov('1098', 'C6KA6') and o->>'llamar' = 'fn_banco_descasar'
                                                          and o->'args'->>'p_movimiento' = pg_temp.c6_mov('1097', 'C6KR4')::text)
                                          then 't' else 'f' end));
    -- (la tarjeta de prueba: el pago recibido, y «Desde 1098»)
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 10, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 9, 'monto', '640.17', 'id', 'C6KG2',
                                 'nombre', 'PAYMENT RECEIVED - THANK YOU'))),
            null, 'c6-pruebas-4c-desde-tarjeta.qfx');
    perform fn_banco_casar_todo('2100-9996');
    select o into v_o from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = pg_temp.c6_mov('2100-9996', 'C6KG2') and o->>'llamar' = 'fn_banco_transferencia' and o->'args'->>'p_cuenta' = '1098';
    v_obt := v_obt || format(' tarjeta=%s/%s', coalesce((v_o->>'pide_motivo')::boolean, false), pg_temp.c6_pulsar(v_o));
    perform fn_banco_transferencia(pg_temp.c6_mov('2100-9996', 'C6KG2'), '1098', 'c6-pruebas: la pagué desde el banco');
    v_obt := v_obt || format(' tarjeta_con_motivo=%s pago_personal=%s', split_part(pg_temp.c6_est('2100-9996', 'C6KG2'), ':', 1),
                             split_part(pg_temp.c6_est('1098', 'C6KA7'), ':', 1));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (145, '«Desde …» no deja que el pase a la personal dada de alta case solo', v_esp, coalesce(v_obt, '-'),
                               case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 146. UN DEPÓSITO QUE NOMBRA UNA CUENTA PROPIA NO ES EL COBRO DE UN
--      CLIENTE (ronda 4c, [c]; el escenario H): la reserva trae +2,017.43
--      «FROM CHK ...1098» (el número del banco de prueba) y hay una factura
--      abierta y un cobro anotado a la reserva por lo mismo. R2 no lo casa
--      solo con el cobro; la propuesta es la transferencia —primero
--      «Desde 1098», sin motivo— y el cobro y la factura piden su motivo;
--      fn_banco_cobrar sin notas y fn_banco_casar_con {cobro} sin motivo son
--      MX008 («no es el cobro de un cliente»). Antes R2 lo casaba solo con el
--      cobro, o la propuesta era «deposito_parcial» con la factura primero y
--      sin motivo: la factura quedaba cobrada con dinero del banco de prueba.
do $$
declare
  v_obt  text;
  v_esp  text := 'r2=pendiente motivo=transferencia_un_lado primero=fn_banco_transferencia cobro=t factura=t cobrar=MX008:t '
                 'casar_cobro=MX008:t';
  v_obra text := current_setting('mx6.obra', true);
  v_c    jsonb;
  v_x    text;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (146, 'un depósito que nombra una cuenta propia no es el cobro de un cliente', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_sin_aviso();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 1, null, jsonb_build_array(
              jsonb_build_object('tipo', 'SRVCHG', 'fecha', d + 1, 'monto', '-15.00', 'id', 'C6KA8', 'nombre', 'MONTHLY SERVICE FEE'))),
            '1098', 'c6-pruebas-4c-propia-0.qfx');
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661461, v_obra, 'C6-1461', d + 1, 5017.43, 0);
    v_c := fn_cobro_registrar(jsonb_build_object(
             'fecha', (d + 3)::text, 'monto', '2017.43', 'cuenta', '1097', 'medio', 'cheque', 'referencia', 'C6-4C-1461',
             'duplicado_confirmado', 'c6-pruebas: dato de prueba',
             'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -661461, 'monto', '2017.43'))));
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 4, 'monto', '2017.43', 'id', 'C6KR5',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...1098 TRANSACTION#: 701'))),
            '1097', 'c6-pruebas-4c-propia.ofx');
    perform fn_banco_casar_todo('1097');
    v_obt := format('r2=%s motivo=%s primero=%s cobro=%s factura=%s', split_part(pg_temp.c6_est('1097', 'C6KR5'), ':', 1),
                    (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1097', 'C6KR5')),
                    (select m.propuesta->'opciones'->0->>'llamar' from movimientos_banco m where m.id = pg_temp.c6_mov('1097', 'C6KR5')),
                    (select coalesce(bool_and((o->>'pide_motivo')::boolean), false)
                       from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                      where m.id = pg_temp.c6_mov('1097', 'C6KR5') and o->>'llamar' = 'fn_banco_casar_con'),
                    (select coalesce(bool_and((o->>'pide_motivo')::boolean), false)
                       from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                      where m.id = pg_temp.c6_mov('1097', 'C6KR5') and o->>'llamar' = 'fn_banco_cobrar'));
    begin
      perform fn_banco_cobrar(pg_temp.c6_mov('1097', 'C6KR5'), '[{"factura_id": -661461, "monto": "2017.43"}]'::jsonb);
      v_x := 'entró';
    exception when others then v_x := sqlstate || ':' || case when sqlerrm like '%no el cobro de un cliente%' then 't' else 'f' end;
    end;
    v_obt := v_obt || ' cobrar=' || v_x;
    begin
      perform fn_banco_casar_con(pg_temp.c6_mov('1097', 'C6KR5'), jsonb_build_object('cobro', v_c->>'cobro'));
      v_x := 'entró';
    exception when others then v_x := sqlstate || ':' || case when sqlerrm like '%no el cobro de un cliente%' then 't' else 'f' end;
    end;
    v_obt := v_obt || ' casar_cobro=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (146, 'un depósito que nombra una cuenta propia no es el cobro de un cliente', v_esp, coalesce(v_obt, '-'),
                               case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 147. LA TRANSFERENCIA SIN NÚMERO QUE NOMBRA A ALGUIEN (ronda 4c, [d]; el
--      escenario F): «ONLINE TRANSFER TO EDGAR M PERSONAL» no se supone ni
--      una cuenta propia ni la personal de Edgar: «otro_lado_nombrado»,
--      todo con su motivo, y ninguna tarjeta de la empresa (no dice que sea
--      el pago de una tarjeta). Antes salía «transferencia_un_lado» con «A
--      1097» sin motivo (la reserva nunca lo iba a traer) y las tarjetas sin
--      pide_motivo: pulsadas tal cual, MX008.
do $$
declare
  v_obt text;
  v_esp text := 'motivo=otro_lado_nombrado sin_motivo=0 tarjetas=0 a_1097=MX008';
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (147, 'la transferencia sin número que nombra a alguien se pregunta, sin botones que fallen', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 8, 'monto', '-1017.43', 'id', 'C6KA9',
                                 'nombre', 'ONLINE TRANSFER TO EDGAR M PERSONAL'))),
            '1098', 'c6-pruebas-4c-nombrado.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := format('motivo=%s sin_motivo=%s tarjetas=%s',
                    (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA9')),
                    (select count(*) from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                      where m.id = pg_temp.c6_mov('1098', 'C6KA9') and not coalesce((o->>'pide_motivo')::boolean, false)),
                    (select count(*) from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                      where m.id = pg_temp.c6_mov('1098', 'C6KA9') and o->'args'->>'p_cuenta' like '2100-%'));
    begin
      perform fn_banco_transferencia(pg_temp.c6_mov('1098', 'C6KA9'), '1097');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' a_1097=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (147, 'la transferencia sin número que nombra a alguien se pregunta, sin botones que fallen', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 148. LA LÍNEA DE CRÉDITO Y LOS PRÉSTAMOS, DADOS DE ALTA POR SU NÚMERO
--      (ronda 4c, [e]; el escenario E): el lote vacío confirmado a una
--      cuenta de deuda (25xx; aquí la 2599 de prueba) da de alta su número
--      —antes MX004, aunque la bandeja lo aconsejaba—; otra vez, «ya
--      estaba»; el mismo número a otra cuenta, MX004. El desembolso
--      («FROM ACCT ...8896») y el pago («TO ACCT ...8896») son
--      «deuda_propia»: su primer botón va a 2599 y entra tal cual; cobrar el
--      desembolso a una factura sin notas es MX008 («no es el cobro de un
--      cliente»).
do $$
declare
  v_obt  text;
  v_esp  text := 'alta=2599 otra_vez=true repetido=MX004 desembolso=deuda_propia pago=deuda_propia boton=ok/ok cobrar=MX008';
  v_obra text := current_setting('mx6.obra', true);
  v_x    text;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (148, 'la línea de crédito se da de alta por su número y su dinero va a ella', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_sin_aviso();
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('2599', 'c6-pruebas: línea de crédito de prueba', 'c6 test line of credit', 'pasivo', 'haber', true, 'prohibida', 'prohibida')
    on conflict (codigo) do nothing;
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661481, v_obra, 'C6-1481', d + 1, 9017.43, 0);
    v_obt := 'alta=' || (fn_banco_importar_filas(jsonb_build_object(
               'origen', 'mano', 'cuenta', '2599', 'ultimos4', '8896', 'confirmo_cuenta', true,
               'nombre', 'c6-pruebas: la línea de crédito ····8896', 'filas', '[]'::jsonb))->>'cuenta');
    v_obt := v_obt || ' otra_vez=' || (fn_banco_importar_filas(jsonb_build_object(
               'origen', 'mano', 'cuenta', '2599', 'ultimos4', '8896', 'confirmo_cuenta', true,
               'nombre', 'c6-pruebas: la línea de crédito ····8896', 'filas', '[]'::jsonb))->>'ya_estaba');
    begin
      perform fn_banco_importar_filas(jsonb_build_object('origen', 'mano', 'cuenta', '2520', 'ultimos4', '8896', 'confirmo_cuenta', true,
                                                         'nombre', 'c6-pruebas: el mismo número a otra deuda', 'filas', '[]'::jsonb));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' repetido=' || v_x;
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 21, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 14, 'monto', '4017.43', 'id', 'C6KA10',
                                 'nombre', 'ONLINE TRANSFER FROM ACCT ...8896 TRANSACTION#: 501'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 20, 'monto', '-1017.43', 'id', 'C6KA11',
                                 'nombre', 'ONLINE TRANSFER TO ACCT ...8896 TRANSACTION#: 502'))),
            '1098', 'c6-pruebas-4c-deuda.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := v_obt || format(' desembolso=%s pago=%s boton=%s/%s',
                             (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA10')),
                             (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA11')),
                             (select pg_temp.c6_pulsar(m.propuesta->'opciones'->0) from movimientos_banco m
                               where m.id = pg_temp.c6_mov('1098', 'C6KA10') and m.propuesta->'opciones'->0->'args'->'p_lineas'->0->>'cuenta' = '2599'),
                             (select pg_temp.c6_pulsar(m.propuesta->'opciones'->0) from movimientos_banco m
                               where m.id = pg_temp.c6_mov('1098', 'C6KA11') and m.propuesta->'opciones'->0->'args'->'p_lineas'->0->>'cuenta' = '2599'));
    begin
      perform fn_banco_cobrar(pg_temp.c6_mov('1098', 'C6KA10'), '[{"factura_id": -661481, "monto": "4017.43"}]'::jsonb);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' cobrar=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (148, 'la línea de crédito se da de alta por su número y su dinero va a ella', v_esp, coalesce(v_obt, '-'),
                               case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 149. EL DEPÓSITO DESDE UN NÚMERO QUE NO SE CONOCE, EN SU ORDEN (ronda 4c,
--      [f]): como en un retiro, primero las cuentas propias y después el
--      patrimonio —todo con su motivo—, y las facturas detrás (lo que dice
--      la cabecera de c6). Antes, en un depósito, el patrimonio iba primero
--      y las cuentas propias las últimas.
do $$
declare
  v_obt  text;
  v_esp  text := 'motivo=cuenta_desconocida primero=fn_banco_transferencia orden=t';
  v_obra text := current_setting('mx6.obra', true);
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (149, 'el depósito de un número que no se conoce: cuentas propias, patrimonio, facturas', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661491, v_obra, 'C6-1491', d + 1, 5017.43, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 5, 'monto', '5017.43', 'id', 'C6KA12',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 21'))),
            '1098', 'c6-pruebas-4c-orden.qfx');
    perform fn_banco_casar_todo('1098');
    select format('motivo=%s primero=%s orden=%s', m.propuesta->>'motivo', m.propuesta->'opciones'->0->>'llamar',
                  (select coalesce(max(x.n) filter (where x.o->>'llamar' = 'fn_banco_transferencia')
                                     < min(x.n) filter (where x.o->>'llamar' = 'fn_banco_clasificar')
                                   and max(x.n) filter (where x.o->>'llamar' = 'fn_banco_clasificar')
                                     < min(x.n) filter (where x.o->>'llamar' = 'fn_banco_cobrar'), false)
                     from jsonb_array_elements(m.propuesta->'opciones') with ordinality as x(o, n))::text)
      into v_obt
      from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA12');
    v_obt := replace(replace(v_obt, 'orden=true', 'orden=t'), 'orden=false', 'orden=f');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (149, 'el depósito de un número que no se conoce: cuentas propias, patrimonio, facturas', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 150. EL PASE A LA PERSONAL DADA DE ALTA, CON LA APORTACIÓN YA CLASIFICADA
--      EN LA RESERVA (ronda 4c, [g]; el escenario C2v): el depósito «FROM
--      EDGAR M MARTINEZ» se clasificó a 3100 con su motivo; el pase del
--      banco de prueba a ····7781 (la personal dada de alta) por lo mismo es
--      «transferencia_personal» y su distribución (3200) entra tal cual. Antes
--      salía «otro_lado_clasificado» («des-casa la aportación: es el otro lado
--      de esta transferencia»), sin los botones del patrimonio.
do $$
declare
  v_obt text;
  v_esp text := 'motivo=transferencia_personal boton=3200:ok';
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (150, 'el pase a la personal no es el otro lado de la aportación ya clasificada', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_cuenta_personal('7781', 'c6-pruebas: Chase personal de Edgar');
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 6, 'monto', '2017.43', 'id', 'C6KR6',
                                 'nombre', 'ONLINE TRANSFER FROM EDGAR M MARTINEZ'))),
            '1097', 'c6-pruebas-4c-aportacion.ofx');
    perform fn_banco_clasificar(pg_temp.c6_mov('1097', 'C6KR6'), '[{"cuenta": "3100"}]'::jsonb,
                                'c6-pruebas: aportación de Edgar desde su cuenta personal');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 5, 'monto', '-2017.43', 'id', 'C6KA13',
                                 'nombre', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 401'))),
            '1098', 'c6-pruebas-4c-a-la-personal.qfx');
    perform fn_banco_casar_todo('1098');
    select format('motivo=%s boton=%s:%s', m.propuesta->>'motivo', m.propuesta->'opciones'->0->'args'->'p_lineas'->0->>'cuenta',
                  pg_temp.c6_pulsar(m.propuesta->'opciones'->0))
      into v_obt
      from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA13');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (150, 'el pase a la personal no es el otro lado de la aportación ya clasificada', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 151. DAR DE BAJA (O DE ALTA) LA CUENTA PERSONAL REHACE YA LAS PROPUESTAS
--      QUE LA NOMBRAN (ronda 4c; la observación del escenario G): sin
--      «Casar», el pase a ····7781 pasa de «transferencia_personal» a
--      «cuenta_desconocida» (su 3200 pide motivo) al darla de baja, y vuelve
--      al darla de alta otra vez. Antes la bandeja enseñaba sus botones
--      viejos sin motivo hasta el siguiente «Casar» (pulsados, MX008).
do $$
declare
  v_obt text;
  v_esp text := 'alta=transferencia_personal baja=cuenta_desconocida:t otra_vez=transferencia_personal';
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (151, 'dar de baja la cuenta personal rehace ya sus propuestas', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform fn_banco_cuenta_personal('7781', 'c6-pruebas: Chase personal de Edgar');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 3, 'monto', '-717.43', 'id', 'C6KA14',
                                 'nombre', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 601'))),
            '1098', 'c6-pruebas-4c-baja.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := 'alta=' || (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA14'));
    perform fn_banco_cuenta_personal('7781', null, false, 'c6-pruebas: la cerró');
    v_obt := v_obt || format(' baja=%s:%s', (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA14')),
                             (select coalesce(bool_and((o->>'pide_motivo')::boolean), false)
                                from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                               where m.id = pg_temp.c6_mov('1098', 'C6KA14') and o->'args'->'p_lineas'->0->>'cuenta' = '3200'));
    perform fn_banco_cuenta_personal('7781', 'c6-pruebas: la abrió otra vez');
    v_obt := v_obt || ' otra_vez=' || (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA14'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (151, 'dar de baja la cuenta personal rehace ya sus propuestas', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 152. «TO CHK ...7781» NO ES UN CHEQUE, Y LO QUE FALTA SE LEE (ronda 4c):
--      la cuenta de cheques que nombra una transferencia no se lee como el
--      número de un cheque (ni en fn_banco_cheque_num ni en el pool del
--      motor), y los cheques de verdad se leen igual («CHECK 1042», «CHK
--      #1043», «CHECK # 1044»). Y confirmar una conciliación con diferencia
--      dice «Lo que falta: la diferencia es …» (antes, «falta la diferencia
--      es …»).
do $$
declare
  v_obt text;
  v_esp text := 'cheques=1042,1043,1044,-,-,- pool=- confirmar=MX008:t';
  v_c   jsonb;
  v_x   text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (152, '«TO CHK ...7781» no es un cheque; «Lo que falta» se lee', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_obt := 'cheques=' || (select string_agg(coalesce(fn_banco_cheque_num(null, x.t), '-'), ',' order by x.n)
                              from unnest(array['CHECK 1042', 'CHK #1043', 'CHECK # 1044', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 301',
                                                'ONLINE TRANSFER FROM CHK ...778', 'TRANSFER TO CK 1234']) with ordinality as x(t, n));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, 50.00, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 3, 'monto', '-717.43', 'id', 'C6KA15',
                                 'nombre', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 301'))),
            '1098', 'c6-pruebas-4c-cheque.qfx');
    v_obt := v_obt || ' pool=' || coalesce((select p.cheque from fn_banco_pool(array['1098']) p
                                             where p.id = pg_temp.c6_mov('1098', 'C6KA15')), '-');
    -- (al día 2, antes del pase: el statement dice 50.00 y el libro nada)
    v_c := fn_conciliar('1098', d + 2, '50.00');
    begin
      perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
      v_x := 'entró';
    exception when others then
      v_x := sqlstate || ':' || case when sqlerrm like '%Lo que falta: la diferencia es %' and sqlerrm not like '%falta la diferencia%'
                                     then 't' else 'f' end;
    end;
    v_obt := v_obt || ' confirmar=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (152, '«TO CHK ...7781» no es un cheque; «Lo que falta» se lee', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 153. UN PEGADO NUEVO REHACE LO PENDIENTE (ronda 4c): la marca de la
--      versión va en la firma de cada propuesta. El pase a ····7781 se
--      propone con la marca de antes (aquí, fn_banco_version cambiada un
--      instante dentro de la prueba, como si la propuesta la hubiera hecho
--      la 4b); vuelta la marca de hoy, el siguiente «Casar» la rehace (su
--      firma cambia), y otro «Casar» ya no (la firma es la misma). Antes la
--      marca no iba en la firma: encima de la 4b se quedaban sus botones
--      hasta que algo de su firma cambiara, y pulsados ya fallaban (MX008).
--      (lock_timeout de 2 s: si alguien cambiaba la función a la vez, sale
--      «omitida».)
do $$
declare
  v_obt text;
  v_esp text := 'rehecha=t estable=t';
  v_ver bigint := fn_banco_version();
  v_f0  text;
  v_f1  text;
  v_f2  text;
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (153, 'un pegado nuevo rehace lo pendiente: la marca va en la firma', v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    set local lock_timeout = '2s';
    perform pg_temp.c6_montar();
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 4, 'monto', '-817.43', 'id', 'C6KA16',
                                 'nombre', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 701'))),
            '1098', 'c6-pruebas-4c-version.qfx');
    execute format('create or replace function public.fn_banco_version() returns bigint language sql immutable '
                   'set search_path = public, pg_temp as $f$ select %s::bigint $f$', v_ver - 1);
    perform fn_banco_casar_todo('1098');
    v_f0 := (select m.propuesta->>'firma' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA16'));
    execute format('create or replace function public.fn_banco_version() returns bigint language sql immutable '
                   'set search_path = public, pg_temp as $f$ select %s::bigint $f$', v_ver);
    perform fn_banco_casar_todo('1098');
    v_f1 := (select m.propuesta->>'firma' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA16'));
    perform fn_banco_casar_todo('1098');
    v_f2 := (select m.propuesta->>'firma' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KA16'));
    v_obt := format('rehecha=%s estable=%s', case when v_f0 is not null and v_f1 is distinct from v_f0 then 't' else 'f' end,
                    case when v_f1 is not null and v_f2 = v_f1 then 't' else 'f' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when lock_not_available then v_obt := 'omitida: alguien cambiaba la función a la vez (lock_timeout)';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 200);
  end;
  insert into _pruebas values (153, 'un pegado nuevo rehace lo pendiente: la marca va en la firma', v_esp, coalesce(v_obt, '-'),
                               case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- =====================================================================
-- Lo que corrigió la ronda 4d (EL CONTROL, y una prueba por arreglo)
-- =====================================================================

-- 154. EL CONTROL: EL OTRO LADO DE CADA CASADO (ronda 4d). Los casados que
--      la versión anterior (9849564) dejaba en verde: el estado final de los
--      escenarios L02, L02b, L03, L06, L10, L13, L14, L16 y L17 del
--      corrector, escrito aquí con la función interna que casa
--      (fn_banco_casar_lineas, como lo dejaba cada camino de entonces: R1
--      con el asiento escrito a mano, el cobro de c3 con su movimiento, la
--      partida de la apertura, la otra mitad de una transferencia, el
--      duplicado dicho «es el mismo»), y el pago recibido en una tarjeta
--      casado a mano con una distribución (3200) sin la cuenta personal.
--      Cada uno sale en rojo en fn_banco_control (el cuadre 59: «esperaba
--      0», y la copia escrita del control cuenta lo mismo que la referencia,
--      fn_banco_criterio_casados, que los nombra a los 10) y en
--      fn_banco_verificar; la
--      conciliación de la tarjeta no se confirma (MX008, dice cuál y cómo);
--      y lo coherente no sale: la personal dada de alta contra 2900, el
--      cheque de un cliente («REMOTE ONLINE DEPOSIT», un tercero) contra su
--      cobro, y lo que se contradice CON su motivo escrito. Escrito el motivo
--      de uno (fn_banco_casar_con con {"casado": …}; sin motivo, 22023; otra
--      vez, MX008: ya lo tiene), sale del rojo y su conciliación se confirma.
do $$
declare
  v_obt  text;
  v_esp  text := 'control=f:esperaba ref=10:t copia=igual coherentes=t verificar=f:10 confirmar=MX008:t motivo_sin=22023 motivo=9 '
                 'otra_vez=MX008 confirmada=t';
  v_obra text := current_setting('mx6.obra', true);
  v_mes  text := current_setting('mx6.mes', true);
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
  v_n1   bigint;
  v_ok   boolean;
  v_tot  bigint;
  v_det  text;
  v_v    record;
  v_c    jsonb;
  v_rojo uuid[] := '{}';
  v_bien uuid[] := '{}';
  v_m    uuid;
  v_a    uuid;
  v_x    text;
  v_conc uuid;
  v_ref  uuid[];
begin
  if d is null or v_mes = '' then
    insert into _pruebas values (154, 'EL CONTROL: el otro lado de cada casado, en rojo; lo coherente no', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_sin_aviso();
    -- La personal ····7781 dada de alta; la Amex personal de Edgar (····7776) en 2900; y una tarjeta de la empresa de Amex.
    perform fn_banco_cuenta_personal('7781', 'c6-pruebas: la personal de prueba');
    perform fn_tarjeta_alta('7776', '2900', 'c6-pruebas: Amex personal de Edgar');
    perform fn_tarjeta_alta('7777', '2100-9996', 'c6-pruebas: Amex Gold de prueba');
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661541, v_obra, 'C6-1541', d + 1, 5017.43, 0);
    -- La reserva de prueba: lo que llega de la personal (L02) y de 1098 (L03).
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 12, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 3, 'monto', '500.00', 'id', 'C6KD1',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 801'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 4, 'monto', '2017.43', 'id', 'C6KD2',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...1098 TRANSACTION#: 701'))),
            '1097', 'c6-pruebas-4d-control-r.ofx');
    -- (L10) Plaid trae primero el pase con el nombre corto, y queda casado como la transferencia «A 1097» (abajo).
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1098', 'nombre', 'c6-pruebas-4d-plaid',
              'filas', jsonb_build_array(jsonb_build_object('id', 'C6KL10', 'fecha', d + 10, 'plaid_monto', '1250.00',
                                                            'descripcion', 'Online Transfer to CHK', 'pendiente', false))));
    v_a := (fn_postear(jsonb_build_object('fecha', (d + 10)::text, 'descripcion', 'c6-pruebas 4d: «A 1097» (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1097', 'monto', '1250.00'),
                                          jsonb_build_object('cuenta', '1098', 'monto', '-1250.00'))))->>'id')::uuid;
    perform fn_banco_casar_lineas(pg_temp.c6_mov('1098', 'C6KL10'), 'transferencia', 'c6-pruebas', v_a, fn_banco_lineas_de(v_a, '1098'),
                                  'R3 transferencia: Edgar la confirmó; el otro lado casa solo con este asiento', false, true);
    -- El banco de prueba.
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 12, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'monto', '-300.00', 'id', 'C6KE1',
                                 'nombre', 'PAYMENT TO CHASE CARD ENDING IN 5555'),
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 5, 'monto', '700.00', 'id', 'C6KE2', 'nombre', 'REMOTE ONLINE DEPOSIT #5'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 6, 'monto', '-1500.00', 'id', 'C6KE3', 'nombre', 'AMEX EPAYMENT ACH PMT 7776'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 7, 'monto', '-640.00', 'id', 'C6KE4',
                                 'nombre', 'CHASE CREDIT CRD AUTOPAY PPD ID: 4760039224'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 8, 'monto', '-2000.00', 'id', 'C6KE5', 'nombre', 'CHECK 1234',
                                 'cheque', '1234'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 9, 'monto', '3200.00', 'id', 'C6KE6',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 91'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 10, 'monto', '-1250.00', 'id', 'C6KE8',
                                 'nombre', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 5'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 11, 'monto', '900.00', 'id', 'C6KE9',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 77'),
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 11, 'monto', '450.00', 'id', 'C6KE10', 'nombre', 'REMOTE ONLINE DEPOSIT #7'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 12, 'monto', '-330.00', 'id', 'C6KE11',
                                 'nombre', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 78'))),
            '1098', 'c6-pruebas-4d-control-b.qfx');
    -- La tarjeta de prueba 2100-9995: un pago recibido.
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009995', d, d + 12, 250.00, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 3, 'monto', '250.00', 'id', 'C6KF1',
                                 'nombre', 'PAYMENT RECEIVED - THANK YOU'))),
            null, 'c6-pruebas-4d-control-t.qfx');
    -- LO QUE DEJABA LA 9849564, caso por caso: el asiento (a mano, o el de su papel) y su casado.
    -- L02: el pase a la reserva escrito a mano, con lo que llega de la personal.
    v_a := (fn_postear(jsonb_build_object('fecha', (d + 2)::text, 'descripcion', 'c6-pruebas 4d: pase a mano (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1097', 'monto', '500.00'),
                                          jsonb_build_object('cuenta', '1098', 'monto', '-500.00'))))->>'id')::uuid;
    v_m := pg_temp.c6_mov('1097', 'C6KD1');
    perform fn_banco_casar_lineas(v_m, 'asiento', 'c6-pruebas', v_a, fn_banco_lineas_de(v_a, '1097'),
                                  'R1 cruce exacto con el libro (mismo monto, en su ventana)', true, false);
    v_rojo := v_rojo || v_m;
    -- L03: el cobro que la app registró con el depósito que viene de 1098, casado solo («R2 el cobro dice este movimiento»).
    v_m := pg_temp.c6_mov('1097', 'C6KD2');
    v_c := fn_cobro_registrar(jsonb_build_object('fecha', (d + 4)::text, 'monto', '2017.43', 'cuenta', '1097', 'medio', 'transferencia',
             'referencia', 'C6-4D-701', 'duplicado_confirmado', 'c6-pruebas: dato de prueba', 'movimiento_id', v_m::text,
             'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -661541, 'monto', '2017.43'))));
    v_a := (select c.contabilizado_en from cobros c where c.id = (v_c->>'cobro')::uuid);
    perform fn_banco_casar_lineas(v_m, 'cobro', v_c->>'cobro', v_a, fn_banco_lineas_de(v_a, '1097'),
                                  'R2 el cobro dice este movimiento', true, false);
    v_rojo := v_rojo || v_m;
    -- L02b, L06 y L13: pagos de tarjeta escritos a mano a 2100-9996, con lo que el banco dice que pagó otra tarjeta: una
    -- ····5555 que nadie conoce, la personal de Edgar (····7776, sus 4 últimos sueltos), y una de CHASE (las de la empresa son Amex).
    foreach v_x in array array['C6KE1:300.00', 'C6KE3:1500.00', 'C6KE4:640.00'] loop
      v_a := (fn_postear(jsonb_build_object('fecha', (d + 4)::text, 'descripcion', 'c6-pruebas 4d: pago de tarjeta a mano (se deshace)',
                'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2100-9996', 'monto', split_part(v_x, ':', 2)),
                                            jsonb_build_object('cuenta', '1098', 'monto', '-' || split_part(v_x, ':', 2)))))->>'id')::uuid;
      v_m := pg_temp.c6_mov('1098', split_part(v_x, ':', 1));
      perform fn_banco_casar_lineas(v_m, 'asiento', 'c6-pruebas', v_a, fn_banco_lineas_de(v_a, '1098'),
                                    'R1 cruce exacto con el libro (mismo monto, en su ventana)', true, false);
      v_rojo := v_rojo || v_m;
    end loop;
    -- L16: la aportación escrita a mano (3100) con el cheque de un cliente depositado por el móvil.
    v_a := (fn_postear(jsonb_build_object('fecha', (d + 4)::text, 'descripcion', 'c6-pruebas 4d: aportación a mano (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '700.00'),
                                          jsonb_build_object('cuenta', '3100', 'monto', '-700.00'))))->>'id')::uuid;
    v_m := pg_temp.c6_mov('1098', 'C6KE2');
    perform fn_banco_casar_lineas(v_m, 'asiento', 'c6-pruebas', v_a, fn_banco_lineas_de(v_a, '1098'),
                                  'R1 cruce exacto con el libro (mismo monto, en su ventana)', true, false);
    v_rojo := v_rojo || v_m;
    -- L14: el cheque 1234 casado como la otra mitad de un pase a la reserva.
    v_a := (fn_postear(jsonb_build_object('fecha', (d + 7)::text, 'descripcion', 'c6-pruebas 4d: pase a la reserva (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1097', 'monto', '2000.00'),
                                          jsonb_build_object('cuenta', '1098', 'monto', '-2000.00'))))->>'id')::uuid;
    v_m := pg_temp.c6_mov('1098', 'C6KE5');
    perform fn_banco_casar_lineas(v_m, 'transferencia', 'c6-pruebas', v_a, fn_banco_lineas_de(v_a, '1098'),
                                  'R3 la otra mitad de la transferencia (en su ventana)', true, false);
    v_rojo := v_rojo || v_m;
    -- L17: lo que llega de la personal, casado con una partida en tránsito de la apertura.
    v_m := pg_temp.c6_mov('1098', 'C6KE6');
    perform fn_banco_casar_lineas(v_m, 'apertura', gen_random_uuid()::text, null, '[]'::jsonb,
                                  'R- la partida en tránsito de la apertura', true, false);
    v_rojo := v_rojo || v_m;
    -- L10: el QFX del mismo pase, con el número de la personal, dicho «es el mismo» sin más.
    v_m := pg_temp.c6_mov('1098', 'C6KE8');
    perform fn_banco_marca('movimiento:' || v_m);
    update movimientos_banco set estado = 'ignorado', duplicado = 'es_el_mismo', propuesta = null,
                                 estado_motivo = 'c6-pruebas: «es el mismo», como lo dejaba la 9849564'
     where id = v_m;
    perform fn_banco_marca(null);
    v_rojo := v_rojo || pg_temp.c6_mov('1098', 'C6KL10');
    -- La tarjeta: el pago recibido casado a mano con una distribución, sin la cuenta personal.
    v_a := (fn_postear(jsonb_build_object('fecha', (d + 3)::text, 'descripcion', 'c6-pruebas 4d: distribución a mano (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2100-9995', 'monto', '250.00'),
                                          jsonb_build_object('cuenta', '3200', 'monto', '-250.00'))))->>'id')::uuid;
    v_m := pg_temp.c6_mov('2100-9995', 'C6KF1');
    perform fn_banco_casar_lineas(v_m, 'asiento', 'c6-pruebas', v_a, fn_banco_lineas_de(v_a, '2100-9995'),
                                  'R1 cruce exacto con el libro (mismo monto, en su ventana)', true, false);
    v_rojo := v_rojo || v_m;
    -- LO COHERENTE: lo de la personal al préstamo del accionista (por la bandeja), el cheque del cliente con su cobro (la app lo
    -- registró con su movimiento; «Casar»), y un pase a la personal casado con una transferencia CON su motivo.
    v_a := (fn_postear(jsonb_build_object('fecha', (d + 11)::text, 'descripcion', 'c6-pruebas 4d: préstamo de Edgar (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '900.00'),
                                          jsonb_build_object('cuenta', '2900', 'monto', '-900.00'))))->>'id')::uuid;
    v_m := pg_temp.c6_mov('1098', 'C6KE9');
    perform fn_banco_casar_lineas(v_m, 'asiento', 'c6-pruebas', v_a, fn_banco_lineas_de(v_a, '1098'),
                                  'R1 cruce exacto con el libro (mismo monto, en su ventana)', true, false);
    v_bien := v_bien || v_m;
    v_m := pg_temp.c6_mov('1098', 'C6KE10');
    perform fn_cobro_registrar(jsonb_build_object('fecha', (d + 11)::text, 'monto', '450.00', 'cuenta', '1098', 'medio', 'cheque',
              'referencia', 'C6-4D-7', 'duplicado_confirmado', 'c6-pruebas: dato de prueba', 'movimiento_id', v_m::text,
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -661541, 'monto', '450.00'))));
    perform fn_banco_casar(v_m);
    v_bien := v_bien || v_m;
    v_a := (fn_postear(jsonb_build_object('fecha', (d + 11)::text, 'descripcion', 'c6-pruebas 4d: pase a mano (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1097', 'monto', '330.00'),
                                          jsonb_build_object('cuenta', '1098', 'monto', '-330.00'))))->>'id')::uuid;
    v_m := pg_temp.c6_mov('1098', 'C6KE11');
    perform fn_banco_casar_lineas(v_m, 'asiento', 'c6-pruebas', v_a, fn_banco_lineas_de(v_a, '1098'),
                                  'Edgar eligió (c6-pruebas)', false, false, 'c6-pruebas: el pase fue a la cuenta de Edgar por error y él lo devolvió');
    v_bien := v_bien || v_m;
    -- EL CONTROL (como la app), la referencia y la revisión.
    perform pg_temp.c6_como('dueno');
    select c.filas, c.detalle, c.ok into v_n1, v_det, v_ok from fn_banco_control(v_mes, array['cuadre: el otro lado de cada casado']) c
     where c.vista = 'cuadre: el otro lado de cada casado';
    execute 'reset role';
    v_obt := format('control=%s:%s', case when v_ok then 't' else 'f' end,
                    case when v_det like 'Esperaba 0 %' then 'esperaba' else coalesce(left(v_det, 60), '-') end);
    select array_agg(x.movimiento_id) filter (where x.cuenta in ('1097', '1098', '2100-9995', '2100-9996')), count(*)
      into v_ref, v_tot
      from fn_banco_criterio_casados() x;
    v_obt := v_obt || format(' ref=%s:%s', coalesce(cardinality(v_ref), 0), case when v_ref @> v_rojo and v_rojo @> v_ref then 't' else 'f' end);
    -- (la copia escrita en el control cuenta lo mismo que la referencia: lo que mira fn_banco_verificar en la revisión entera)
    v_obt := v_obt || ' copia=' || case when v_tot = v_n1 then 'igual' else format('distinta(%s/%s)', v_n1, v_tot) end;
    v_obt := v_obt || ' coherentes=' || case when not (coalesce(v_ref, '{}') && v_bien) and (select count(*) from movimientos_banco m
                                                                                              where m.id = any (v_bien) and m.estado = 'casado') = 3
                                             then 't' else 'f' end;
    select v.ok, v.detalle into v_v from fn_banco_verificar(array['1097', '1098', '2100-9995', '2100-9996']) v
     where v.control = 'el otro lado de cada casado';
    v_obt := v_obt || format(' verificar=%s:%s', case when v_v.ok then 't' else 'f' end, jsonb_array_length(v_v.detalle->'casados'));
    -- La conciliación de la tarjeta (todo lo demás cuadra) no se confirma: dice cuál y cómo.
    v_c := fn_conciliar('2100-9995', d + 12);
    v_conc := (v_c->>'conciliacion')::uuid;
    begin
      perform fn_conciliacion_confirmar(v_conc);
      v_x := 'confirmada';
    exception when others then
      v_x := sqlstate || ':' || case when sqlerrm like '%se contradicen%' and sqlerrm like '%fn_banco_casar_con%'
                                          and sqlerrm like '%' || pg_temp.c6_mov('2100-9995', 'C6KF1')::text || '%' then 't' else 'f' end;
    end;
    v_obt := v_obt || ' confirmar=' || v_x;
    -- Escribir su motivo: sin motivo no; con él, sale del rojo; dos veces no.
    v_m := pg_temp.c6_mov('2100-9995', 'C6KF1');
    begin
      perform fn_banco_casar_con(v_m, jsonb_build_object('casado', (select m.casado_id from movimientos_banco m where m.id = v_m)));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' motivo_sin=' || v_x;
    perform fn_banco_casar_con(v_m, jsonb_build_object('casado', (select m.casado_id from movimientos_banco m where m.id = v_m)),
                               'c6-pruebas: Edgar pagó la tarjeta y lo pasó a su distribución, a sabiendas');
    v_obt := v_obt || ' motivo=' || (select count(*) from unnest(array['1097', '1098', '2100-9995', '2100-9996']) as c(cuenta)
                                       cross join lateral fn_banco_criterio_casados(c.cuenta) x);
    begin
      perform fn_banco_casar_con(v_m, jsonb_build_object('casado', (select m.casado_id from movimientos_banco m where m.id = v_m)),
                                 'c6-pruebas: otra vez');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' otra_vez=' || v_x;
    perform fn_conciliacion_confirmar(v_conc);  -- (la recalcula)
    v_obt := v_obt || ' confirmada=' || case when (select c.estado from conciliaciones c where c.id = v_conc) = 'confirmada' then 't' else 'f' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 300);
  end;
  insert into _pruebas values (154, 'EL CONTROL: el otro lado de cada casado, en rojo; lo coherente no', v_esp, coalesce(v_obt, '-'),
                               case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 155. R1 CON UN ASIENTO ESCRITO A MANO MIRA EL CRITERIO (ronda 4d; L02,
--      L02b y L16): «Casar» ya no junta solo el pase a la reserva escrito a
--      mano con lo que llega de la cuenta personal de Edgar, el pago a mano
--      de una tarjeta de la empresa con el pago a una ····5555 que nadie
--      conoce, ni la aportación escrita a mano (3100) con el cheque de un
--      cliente («REMOTE ONLINE DEPOSIT», un tercero): los tres esperan, y su
--      botón «Confirmar cruce con …» pide el motivo (pulsado sin él, MX008;
--      con él casa, y el control no lo pone en rojo). Lo coherente casa solo
--      como antes: el préstamo del accionista escrito a mano (2900) con lo
--      que llega de la personal dada de alta. Antes R1 casaba los cuatro
--      solos por el cruce exacto.
do $$
declare
  v_obt text;
  v_esp text := 'r1=pendiente,pendiente,pendiente,casado:asiento confirmar_pm=t,t,t tal_cual=MX008 con_motivo=casado:asiento control=t';
  v_mes text := current_setting('mx6.mes', true);
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
  v_a   uuid[] := '{}';
  v_m   uuid[];
  v_o   jsonb;
  v_x   text;
  i     int;
begin
  if d is null or v_mes = '' then
    insert into _pruebas values (155, 'R1 con un asiento escrito a mano mira el criterio; su botón pide el motivo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_sin_aviso();
    perform fn_banco_cuenta_personal('7781', 'c6-pruebas: la personal de prueba');
    -- Lo escrito a mano: el pase a la reserva, el pago de la tarjeta, la aportación y el préstamo del accionista.
    v_a := v_a || (fn_postear(jsonb_build_object('fecha', (d + 2)::text, 'descripcion', 'c6-pruebas 4d: pase a mano (se deshace)',
                     'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1097', 'monto', '500.00'),
                                                 jsonb_build_object('cuenta', '1098', 'monto', '-500.00'))))->>'id')::uuid;
    v_a := v_a || (fn_postear(jsonb_build_object('fecha', (d + 4)::text, 'descripcion', 'c6-pruebas 4d: pago de la tarjeta a mano (se deshace)',
                     'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2100-9996', 'monto', '300.00'),
                                                 jsonb_build_object('cuenta', '1098', 'monto', '-300.00'))))->>'id')::uuid;
    v_a := v_a || (fn_postear(jsonb_build_object('fecha', (d + 4)::text, 'descripcion', 'c6-pruebas 4d: aportación a mano (se deshace)',
                     'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '700.00'),
                                                 jsonb_build_object('cuenta', '3100', 'monto', '-700.00'))))->>'id')::uuid;
    v_a := v_a || (fn_postear(jsonb_build_object('fecha', (d + 10)::text, 'descripcion', 'c6-pruebas 4d: préstamo de Edgar a mano (se deshace)',
                     'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '900.00'),
                                                 jsonb_build_object('cuenta', '2900', 'monto', '-900.00'))))->>'id')::uuid;
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 12, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 3, 'monto', '500.00', 'id', 'C6KG1',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 801'))),
            '1097', 'c6-pruebas-4d-r1-r.ofx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 12, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 5, 'monto', '-300.00', 'id', 'C6KG2',
                                 'nombre', 'PAYMENT TO CHASE CARD ENDING IN 5555'),
              jsonb_build_object('tipo', 'DEP', 'fecha', d + 5, 'monto', '700.00', 'id', 'C6KG3', 'nombre', 'REMOTE ONLINE DEPOSIT #5'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 11, 'monto', '900.00', 'id', 'C6KG4',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 77'))),
            '1098', 'c6-pruebas-4d-r1-b.qfx');
    perform fn_banco_casar_todo('1097');
    perform fn_banco_casar_todo('1098');
    v_m := array[pg_temp.c6_mov('1097', 'C6KG1'), pg_temp.c6_mov('1098', 'C6KG2'), pg_temp.c6_mov('1098', 'C6KG3')];
    v_obt := format('r1=%s,%s,%s,%s', split_part(pg_temp.c6_est('1097', 'C6KG1'), ':', 1), split_part(pg_temp.c6_est('1098', 'C6KG2'), ':', 1),
                    split_part(pg_temp.c6_est('1098', 'C6KG3'), ':', 1), pg_temp.c6_est('1098', 'C6KG4'));
    -- Su botón «Confirmar cruce con …» (las líneas de SU asiento) pide el motivo.
    v_obt := v_obt || ' confirmar_pm=';
    for i in 1 .. 3 loop
      v_obt := v_obt || case when i > 1 then ',' else '' end
               || coalesce((select bool_and(coalesce((o->>'pide_motivo')::boolean, false))::text
                              from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
                             where m.id = v_m[i] and o->>'llamar' = 'fn_banco_casar_con'
                               and o->'args'->'p_con'->'lineas'->0->>'asiento_id' = v_a[i]::text), 'sin_boton');
    end loop;
    v_obt := replace(replace(v_obt, 'true', 't'), 'false', 'f');
    select o into v_o from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o
     where m.id = v_m[1] and o->>'llamar' = 'fn_banco_casar_con' and o->'args'->'p_con'->'lineas'->0->>'asiento_id' = v_a[1]::text;
    v_obt := v_obt || ' tal_cual=' || pg_temp.c6_pulsar(v_o - 'pide_motivo');
    perform fn_banco_casar_con(v_m[1], v_o->'args'->'p_con', 'c6-pruebas: Edgar lo pasó desde su cuenta personal; el pase a mano es este');
    v_obt := v_obt || ' con_motivo=' || pg_temp.c6_est('1097', 'C6KG1')
             || ' control=' -- (EL CONTROL, con su referencia: la 154 y la 39 miran que la copia del control cuente lo mismo)
             || case when exists (select 1 from fn_banco_criterio_casados((select m.cuenta from movimientos_banco m where m.id = v_m[1])) x
                                   where x.movimiento_id = v_m[1]) then 'f' else 't' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 300);
  end;
  insert into _pruebas values (155, 'R1 con un asiento escrito a mano mira el criterio; su botón pide el motivo', v_esp, coalesce(v_obt, '-'),
                               case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 156. EL COBRO QUE LA APP REGISTRÓ CON SU MOVIMIENTO (ronda 4d, L03): la
--      reserva trae +2,017.43 «FROM CHK ...1098» y Chase −2,017.43 «TO SAV
--      ...1097», y la app (c3, fn_cobro_registrar con su movimiento) registra
--      el depósito como el cobro de una factura. «Casar» no lo casa solo (EL
--      CRITERIO: el banco dice que viene de una cuenta de la empresa), ni lo
--      junta con el retiro (R3: su papel ya tiene ese dinero en el libro):
--      espera con su propuesta «cobro_que_lo_nombra», cuyos botones (es su
--      cobro; no lo es: anularlo) piden su motivo. Mientras ese cobro siga
--      vigente, el depósito no se postea otra vez: ni como transferencia, ni
--      clasificado, ni casado con el retiro (MX008, con motivo o sin él). El
--      retiro propone primero anular ese cobro (con su motivo) y no ofrece
--      «A 1097» (fallaría siempre). Con su motivo, casa con su cobro y el
--      control no lo pone en rojo. Antes «R2 el cobro dice este movimiento»
--      lo casaba solo y el pase de Chase quedaba como el cobro de la factura.
do $$
declare
  v_obt  text;
  v_esp  text := 'casar=pendiente:cobro_que_lo_nombra,pendiente botones=2:t transferencia=MX008 clasificar=MX008 otra_cosa=MX008 '
                 'retiro=otro_lado_clasificado:fn_cobro_anular:sin_a_1097 sin_motivo=MX008 con_motivo=casado:cobro control=t';
  v_obra text := current_setting('mx6.obra', true);
  v_mes  text := current_setting('mx6.mes', true);
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
  v_c    jsonb;
  v_m    uuid;
  v_r    uuid;
  v_x    text;
begin
  if d is null or v_mes = '' then
    insert into _pruebas values (156, 'el cobro que la app registró con su movimiento no casa solo si el banco nombra una cuenta propia',
                                 v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_sin_aviso();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661561, v_obra, 'C6-1561', d + 1, 5017.43, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 4, 'monto', '2017.43', 'id', 'C6KH1',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...1098 TRANSACTION#: 701'))),
            '1097', 'c6-pruebas-4d-c3-r.ofx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 3, 'monto', '-2017.43', 'id', 'C6KH2',
                                 'nombre', 'ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 701'))),
            '1098', 'c6-pruebas-4d-c3-b.qfx');
    v_m := pg_temp.c6_mov('1097', 'C6KH1');
    v_r := pg_temp.c6_mov('1098', 'C6KH2');
    v_c := fn_cobro_registrar(jsonb_build_object('fecha', (d + 4)::text, 'monto', '2017.43', 'cuenta', '1097', 'medio', 'transferencia',
             'referencia', 'C6-4D-701', 'duplicado_confirmado', 'c6-pruebas: dato de prueba', 'movimiento_id', v_m::text,
             'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -661561, 'monto', '2017.43'))));
    perform fn_banco_casar_todo('1097');
    perform fn_banco_casar_todo('1098');
    v_obt := format('casar=%s,%s', pg_temp.c6_est('1097', 'C6KH1'), split_part(pg_temp.c6_est('1098', 'C6KH2'), ':', 1));
    v_obt := v_obt || ' botones=' || (select count(*) || ':' || case when bool_and(coalesce((o->>'pide_motivo')::boolean, false)) then 't' else 'f' end
                                        from movimientos_banco m cross join jsonb_array_elements(m.propuesta->'opciones') o where m.id = v_m);
    begin
      perform fn_banco_transferencia(v_m, '1098', 'c6-pruebas: con motivo tampoco');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' transferencia=' || v_x;
    begin
      perform fn_banco_clasificar(v_m, '[{"cuenta": "3100"}]'::jsonb, 'c6-pruebas: con motivo tampoco');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' clasificar=' || v_x;
    begin
      perform fn_banco_casar_con(v_m, jsonb_build_object('movimiento', v_r), 'c6-pruebas: con motivo tampoco');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' otra_cosa=' || v_x;
    v_obt := v_obt || ' retiro=' || (select format('%s:%s:%s', m.propuesta->>'motivo', m.propuesta->'opciones'->0->>'llamar',
                                                   case when exists (select 1 from jsonb_array_elements(m.propuesta->'opciones') o
                                                                      where o->>'llamar' = 'fn_banco_transferencia'
                                                                        and o->'args'->>'p_cuenta' = '1097')
                                                        then 'con_a_1097' else 'sin_a_1097' end)
                                       from movimientos_banco m where m.id = v_r);
    begin
      perform fn_banco_casar_con(v_m, jsonb_build_object('cobro', v_c->>'cobro'));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' sin_motivo=' || v_x;
    perform fn_banco_casar_con(v_m, jsonb_build_object('cobro', v_c->>'cobro'),
                               'c6-pruebas: el cliente pagó a la cuenta de Chase y Edgar lo pasó a la reserva');
    v_obt := v_obt || ' con_motivo=' || pg_temp.c6_est('1097', 'C6KH1')
             || ' control=' -- (EL CONTROL, con su referencia: la 154 y la 39 miran que la copia del control cuente lo mismo)
             || case when exists (select 1 from fn_banco_criterio_casados((select m.cuenta from movimientos_banco m where m.id = v_m)) x
                                   where x.movimiento_id = v_m) then 'f' else 't' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 300);
  end;
  insert into _pruebas values (156, 'el cobro que la app registró con su movimiento no casa solo si el banco nombra una cuenta propia',
                               v_esp, coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 157. LO QUE DICE EL BANCO Y EL CRITERIO NO LEÍA (ronda 4d; L06, L13, L14
--      y L15): los 4 últimos SUELTOS de la tarjeta personal de Edgar dada
--      de alta en 2900 («AMEX EPAYMENT ACH PMT 7776»: su cuenta personal, no
--      dinero entre cuentas propias); el EMISOR de la tarjeta que se paga
--      («CHASE CREDIT CRD AUTOPAY», cuando las de la empresa son Amex: un
--      tercero que nombra a CHASE, y R3 no lo junta con el pago recibido en
--      la tarjeta de la empresa); un CHEQUE no es la otra mitad del pase que
--      ya puso «Desde 1098» (no casa con su línea); y el nombre de
--      QuickBooks que es solo cifras («1007», como trae QuickBooks la Gold)
--      no es el número de esa cuenta (····1007 no se conoce, y se puede dar
--      de alta como personal). Antes: «propia_sin_numero» las dos primeras
--      (R3 casaba el pago a CHASE con el de la Gold), el cheque casaba con
--      el pase, y ····1007 era la Gold (MX004 al darla de alta).
do $$
declare
  v_obt text;
  v_esp text := 'sueltos=personal emisor=tercero:CHASE r3=pendiente,pendiente cheque=pendiente qb_1007=- personal_1007=t';
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
  v_x   text;
begin
  if d is null then
    insert into _pruebas values (157, 'el criterio lee los 4 últimos sueltos, el emisor, el cheque y no un nombre de QuickBooks', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_sin_aviso();
    perform fn_tarjeta_alta('7776', '2900', 'c6-pruebas: Amex personal de Edgar');
    perform fn_tarjeta_alta('7777', '2100-9996', 'c6-pruebas: Amex Gold de prueba');
    -- (L14) La reserva trae primero el pase desde 1098 y Edgar pulsa «Desde 1098» (····1098, dado de alta con un lote vacío: sin
    -- motivo).
    perform fn_banco_importar_filas('{"origen": "mano", "cuenta": "1098", "ultimos4": "1098", "confirmo_cuenta": true,
                                      "nombre": "c6-pruebas: 1098 ····1098", "filas": []}'::jsonb);
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 6, 'monto', '2000.00', 'id', 'C6KI1',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...1098 TRANSACTION#: 61'))),
            '1097', 'c6-pruebas-4d-lee-r.ofx');
    perform fn_banco_transferencia(pg_temp.c6_mov('1097', 'C6KI1'), '1098');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 2, 'monto', '-1500.00', 'id', 'C6KI2', 'nombre', 'AMEX EPAYMENT ACH PMT 7776'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-640.00', 'id', 'C6KI3',
                                 'nombre', 'CHASE CREDIT CRD AUTOPAY PPD ID: 4760039224'),
              jsonb_build_object('tipo', 'CHECK', 'fecha', d + 5, 'monto', '-2000.00', 'id', 'C6KI4', 'nombre', 'CHECK 1234',
                                 'cheque', '1234'))),
            '1098', 'c6-pruebas-4d-lee-b.qfx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('tarjeta', '372700000009996', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'CREDIT', 'fecha', d + 4, 'monto', '640.00', 'id', 'C6KI5',
                                 'nombre', 'PAYMENT RECEIVED - THANK YOU'))),
            null, 'c6-pruebas-4d-lee-t.qfx');
    perform fn_banco_casar_todo('1098');
    perform fn_banco_casar_todo('2100-9996');
    v_obt := format('sueltos=%s emisor=%s:%s',
                    (select fn_banco_otro_lado(m)->>'clase' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KI2')),
                    (select fn_banco_otro_lado(m)->>'clase' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KI3')),
                    (select fn_banco_otro_lado(m)->>'emisor' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KI3')));
    v_obt := v_obt || format(' r3=%s,%s cheque=%s', split_part(pg_temp.c6_est('1098', 'C6KI3'), ':', 1),
                             split_part(pg_temp.c6_est('2100-9996', 'C6KI5'), ':', 1), split_part(pg_temp.c6_est('1098', 'C6KI4'), ':', 1));
    -- (L15) «1007» en QuickBooks es la Gold (2100-9996): no es su número.
    perform fn_apertura_mapeo_qb('1007', '2100-9996', 'c6-pruebas: así nombra QuickBooks la tarjeta');
    v_obt := v_obt || ' qb_1007=' || coalesce(fn_banco_numero_de('1007'), '-');
    begin
      perform fn_banco_cuenta_personal('1007', 'c6-pruebas: una cuenta personal ····1007');
      v_x := 't';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' personal_1007=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 300);
  end;
  insert into _pruebas values (157, 'el criterio lee los 4 últimos sueltos, el emisor, el cheque y no un nombre de QuickBooks', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 158. EL DUPLICADO QUE TRAE EL NÚMERO (ronda 4d, L10): Plaid trae primero
--      «Online Transfer to CHK» (sin número) y Edgar lo confirma «A 1097»;
--      después el QFX trae el mismo pase con el número de la cuenta
--      personal de Edgar dada de alta (····7781). La bandeja dice que aquel
--      está mal casado y sus botones (des-casarlo; es el mismo) piden su
--      motivo. «Es el mismo» sin motivo es MX008 (lo que trae vale para el
--      original, y contradice su casado); con su motivo, el motivo queda
--      también en el casado del original, y el control no lo pone en rojo.
--      Y con el original todavía pendiente, «es el mismo» rehace ya su
--      propuesta con el número (la de la cuenta personal). Antes el número
--      se quedaba en el ignorado y el pase a Edgar seguía como un pase a la
--      reserva, en verde. Y (lo encontró la verificación de la 4d) sin nada
--      que se contradiga, ni el texto del duplicado ni el MX008 de
--      fn_banco_clasificar («Esto ya está en el libro») llevan un «Ojo»
--      vacío: format() con un argumento nulo da '' y no nulo, y salían
--      siempre («aquel está mal casado: .», «Ojo: . Si no es este dinero…»).
do $$
declare
  v_obt text;
  v_esp text := 'bandeja=posible_duplicado:fn_banco_descasar:t:t:t mismo=MX008 con_motivo=ignorado:t control=t '
                'sin_ojo=posible_duplicado:t pendiente=transferencia_personal clasificar=MX008:t';
  v_mes text := current_setting('mx6.mes', true);
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
  v_p   uuid;
  v_q   uuid;
  v_x   text;
begin
  if d is null or v_mes = '' then
    insert into _pruebas values (158, 'el duplicado que trae el número: «es el mismo» contra el casado del original pide motivo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_sin_aviso();
    perform fn_banco_cuenta_personal('7781', 'c6-pruebas: la personal de prueba');
    -- (el número de la reserva de prueba, dado de alta con un lote vacío: «A 1097» sin motivo)
    perform fn_banco_importar_filas('{"origen": "mano", "cuenta": "1097", "ultimos4": "1097", "confirmo_cuenta": true,
                                      "nombre": "c6-pruebas: 1097 ····1097", "filas": []}'::jsonb);
    perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1098', 'nombre', 'c6-pruebas-4d-dup-plaid',
              'filas', jsonb_build_array(
                jsonb_build_object('id', 'C6KJP1', 'fecha', d + 5, 'plaid_monto', '1250.00', 'descripcion', 'Online Transfer to CHK',
                                   'pendiente', false),
                jsonb_build_object('id', 'C6KJP2', 'fecha', d + 6, 'plaid_monto', '880.00', 'descripcion', 'Online Transfer to CHK',
                                   'pendiente', false))));
    v_p := pg_temp.c6_mov('1098', 'C6KJP1');
    perform fn_banco_transferencia(v_p, '1097');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 5, 'monto', '-1250.00', 'id', 'C6KJQ1',
                                 'nombre', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 5'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 6, 'monto', '-880.00', 'id', 'C6KJQ2',
                                 'nombre', 'ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 6'))),
            '1098', 'c6-pruebas-4d-dup-b.qfx');
    perform fn_banco_casar_todo('1098');
    v_q := pg_temp.c6_mov('1098', 'C6KJQ1');
    v_obt := 'bandeja=' || (select format('%s:%s:%s:%s:%s', m.propuesta->>'motivo', m.propuesta->'opciones'->0->>'llamar',
                                          case when (m.propuesta->'opciones'->0->>'pide_motivo')::boolean then 't' else 'f' end,
                                          case when (select bool_and(coalesce((o->>'pide_motivo')::boolean, false))
                                                       from jsonb_array_elements(m.propuesta->'opciones') o
                                                      where o->>'llamar' = 'fn_banco_duplicado' and (o->'args'->>'p_es_el_mismo')::boolean)
                                               then 't' else 'f' end,
                                          case when m.propuesta ? 'contradice' then 't' else 'f' end)
                              from movimientos_banco m where m.id = v_q);
    begin
      perform fn_banco_duplicado(v_q, true);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' mismo=' || v_x;
    perform fn_banco_duplicado(v_q, true, 'c6-pruebas: es el mismo; el pase fue a la cuenta de Edgar y él lo devolvió a la reserva');
    v_obt := v_obt || ' con_motivo=' || split_part(pg_temp.c6_est('1098', 'C6KJQ1'), ':', 1) || ':'
             || case when (select bc.motivo from banco_casados bc join movimientos_banco m on m.casado_id = bc.id where m.id = v_p)
                          like 'c6-pruebas: es el mismo%' then 't' else 'f' end
             || ' control=' -- (EL CONTROL, con su referencia: la 154 y la 39 miran que la copia del control cuente lo mismo)
             || case when exists (select 1 from fn_banco_criterio_casados((select m.cuenta from movimientos_banco m where m.id = v_p)) x
                                   where x.movimiento_id = v_p) then 'f' else 't' end;
    -- (sin nada que se contradiga —el original está pendiente—, su texto sin «Ojo»)
    v_obt := v_obt || ' sin_ojo=' || (select format('%s:%s', m.propuesta->>'motivo',
                                                    case when position('Ojo' in coalesce(m.propuesta->>'texto', '')) = 0 then 't' else 'f' end)
                                        from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KJQ2'));
    -- El original pendiente: «es el mismo» rehace su propuesta con el número del QFX.
    perform fn_banco_duplicado(pg_temp.c6_mov('1098', 'C6KJQ2'), true);
    v_obt := v_obt || ' pendiente=' || coalesce((select m.propuesta->>'motivo' from movimientos_banco m
                                                  where m.id = pg_temp.c6_mov('1098', 'C6KJP2')), '-');
    -- Un cargo que ya está en el libro (escrito a mano: no es una transferencia): clasificarlo, aunque sea con su motivo, es
    -- MX008 «Esto ya está en el libro», sin un «Ojo» vacío.
    perform fn_postear(jsonb_build_object('fecha', (d + 2)::text, 'descripcion', 'c6-pruebas 4d: cargo a mano (se deshace)',
              'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6130', 'monto', '333.00'),
                                          jsonb_build_object('cuenta', '1098', 'monto', '-333.00'))));
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 3, 'monto', '-333.00', 'id', 'C6KJR1', 'nombre', 'C6 PRUEBAS SUPPLY 333'))),
            '1098', 'c6-pruebas-4d-dup-c.qfx');
    begin
      perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6KJR1'), '[{"cuenta": "6130"}]'::jsonb, 'c6-pruebas: con su motivo');
      v_x := 'entró';
    exception when others then
      v_x := sqlstate || ':' || case when sqlerrm like '%ya está en el libro%' and sqlerrm not like '%Ojo%' then 't' else 'f' end;
    end;
    v_obt := v_obt || ' clasificar=' || v_x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 300);
  end;
  insert into _pruebas values (158, 'el duplicado que trae el número: «es el mismo» contra el casado del original pide motivo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 159. LA PARTIDA DE LA APERTURA Y LO QUE LLEGA DE LA PERSONAL (ronda 4d,
--      L17): en la conciliación de apertura, un depósito en tránsito de
--      3,200.00 (el cheque de un cliente del 30-sep); el 2-oct llegan
--      3,200.00 «FROM CHK ...7781» (la cuenta personal de Edgar, dada de
--      alta). La regla de la apertura no los casa solos (EL CRITERIO: ese
--      dinero no es de un tercero); la propuesta va primero con lo personal
--      (su préstamo, su aportación, sin motivo) y la partida de la apertura
--      al final, con su motivo; casarlos sin motivo es MX008, con él entra y
--      el control no lo pone en rojo. Antes la partida casaba sola, o su
--      botón iba primero y sin motivo.
do $$
declare
  v_obt text;
  v_esp text := 'casar=pendiente:transferencia_personal primero=fn_banco_clasificar apertura=ultima:t sin_motivo=MX008 '
                'con_motivo=casado:apertura control=t';
  v_mes text := current_setting('mx6.mes', true);
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
  v_c   jsonb;
  v_m   uuid;
  v_pa  uuid;
  v_x   text;
begin
  if d is null or v_mes = '' or not exists (select 1 from periodos where tipo = 'apertura') then
    insert into _pruebas values (159, 'la partida de la apertura no casa sola con lo que llega de la cuenta personal', v_esp,
                                 'omitida: falta mes abierto o la apertura', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_apertura_minima();
    perform fn_banco_cuenta_personal('7781', 'c6-pruebas: la personal de prueba');
    v_c := fn_conciliacion_apertura('1098', '-3200.00', jsonb_build_array(
             jsonb_build_object('fecha', (d - 1)::text, 'monto', '3200.00', 'descripcion', 'c6-pruebas: depósito del 30-sep (cheque de NCH)')));
    perform fn_conciliacion_confirmar((v_c->>'conciliacion')::uuid);
    v_pa := (select p.id from conciliacion_partidas p where p.conciliacion_id = (v_c->>'conciliacion')::uuid and p.lado = 'libro'
              and p.monto = 3200.00 limit 1);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 1, 'monto', '3200.00', 'id', 'C6KL1',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 91'))),
            '1098', 'c6-pruebas-4d-apertura.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6KL1');
    v_obt := 'casar=' || pg_temp.c6_est('1098', 'C6KL1')
             || (select format(' primero=%s apertura=%s:%s', m.propuesta->'opciones'->0->>'llamar',
                               case when (select max(x.n) from jsonb_array_elements(m.propuesta->'opciones') with ordinality as x(o, n)
                                           where x.o->'args'->'p_con' ? 'partida_apertura')
                                         = jsonb_array_length(m.propuesta->'opciones') then 'ultima' else 'no_ultima' end,
                               case when (select bool_and(coalesce((x.o->>'pide_motivo')::boolean, false))
                                            from jsonb_array_elements(m.propuesta->'opciones') as x(o)
                                           where x.o->'args'->'p_con' ? 'partida_apertura') then 't' else 'f' end)
                   from movimientos_banco m where m.id = v_m);
    begin
      perform fn_banco_casar_con(v_m, jsonb_build_object('partida_apertura', v_pa));
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' sin_motivo=' || v_x;
    perform fn_banco_casar_con(v_m, jsonb_build_object('partida_apertura', v_pa),
                               'c6-pruebas: el cliente pagó a Edgar y él lo pasó a la empresa: es el cheque del 30-sep');
    v_obt := v_obt || ' con_motivo=' || pg_temp.c6_est('1098', 'C6KL1')
             || ' control=' -- (EL CONTROL, con su referencia: la 154 y la 39 miran que la copia del control cuente lo mismo)
             || case when exists (select 1 from fn_banco_criterio_casados((select m.cuenta from movimientos_banco m where m.id = v_m)) x
                                   where x.movimiento_id = v_m) then 'f' else 't' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 300);
  end;
  insert into _pruebas values (159, 'la partida de la apertura no casa sola con lo que llega de la cuenta personal', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 160. LA LÍNEA DE CRÉDITO DADA DE ALTA DESPUÉS (ronda 4d; L01, L01b y
--      L12): Chase trae +5,000.00 «FROM ACCT ...8896» (lo que una factura
--      abierta tiene por cobrar), −1,000.00 «TO ACCT ...8896» y +3,000.00
--      «FROM ACCT ...8896», y «Casar» los propone como una cuenta que no se
--      conoce. Edgar da de alta
--      ····8896 como la línea de crédito (2510, un lote vacío): sus
--      propuestas se rehacen YA, sin otro «Casar» (son su desembolso y su
--      pago). El desembolso que la factura explica dice «con su motivo» y su
--      botón lo pide (clasificarlo sin él es MX008: el cuadre 52); el otro
--      desembolso, a un gasto, tampoco: va entero a su cuenta (MX008); y el
--      pago, partido entre la deuda y sus intereses, entra sin
--      motivo. Antes las propuestas viejas seguían hasta el siguiente
--      «Casar», el texto decía «sin motivo» y su botón fallaba, y el
--      desembolso a un gasto entraba sin motivo.
do $$
declare
  v_obt  text;
  v_esp  text := 'antes=cuenta_desconocida rehechas=3 ahora=deuda_propia,deuda_propia texto=t boton=t tal_cual=MX008 '
                 'a_gasto=MX008 pago_partido=casado:clasificado';
  v_obra text := current_setting('mx6.obra', true);
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
  v_r    jsonb;
  v_m    uuid;
  v_x    text;
begin
  if d is null then
    insert into _pruebas values (160, 'la línea de crédito dada de alta después: propuestas rehechas, desembolso a su cuenta', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_sin_aviso();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-661601, v_obra, 'C6-1601', d + 1, 5000.00, 0);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 4, 'monto', '5000.00', 'id', 'C6KM1',
                                 'nombre', 'ONLINE TRANSFER FROM ACCT ...8896 TRANSACTION#: 2'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 5, 'monto', '-1000.00', 'id', 'C6KM2',
                                 'nombre', 'ONLINE TRANSFER TO ACCT ...8896 TRANSACTION#: 1'),
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 6, 'monto', '3000.00', 'id', 'C6KM3',
                                 'nombre', 'ONLINE TRANSFER FROM ACCT ...8896 TRANSACTION#: 3'))),
            '1098', 'c6-pruebas-4d-loc.qfx');
    v_m := pg_temp.c6_mov('1098', 'C6KM1');
    perform fn_banco_casar(v_m);
    v_obt := 'antes=' || coalesce((select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_m), '-');
    v_r := fn_banco_importar_filas('{"origen": "mano", "cuenta": "2510", "ultimos4": "8896", "confirmo_cuenta": true,
                                     "nombre": "c6-pruebas: la línea ····8896", "filas": []}'::jsonb);
    v_obt := v_obt || ' rehechas=' || coalesce(v_r->>'rehechas', '0')
             || format(' ahora=%s,%s', (select m.propuesta->>'motivo' from movimientos_banco m where m.id = v_m),
                       (select m.propuesta->>'motivo' from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6KM2')));
    v_obt := v_obt || (select format(' texto=%s boton=%s',
                                     case when m.propuesta->>'texto' like '%con su motivo escrito%' then 't' else 'f' end,
                                     case when (select bool_and(coalesce((o->>'pide_motivo')::boolean, false))
                                                  from jsonb_array_elements(m.propuesta->'opciones') o
                                                 where o->>'llamar' = 'fn_banco_clasificar' and o->'args'->'p_lineas'->0->>'cuenta' = '2510')
                                          then 't' else 'f' end)
                         from movimientos_banco m where m.id = v_m);
    begin
      perform fn_banco_clasificar(v_m, '[{"cuenta": "2510"}]'::jsonb);
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' tal_cual=' || v_x;
    -- (otro desembolso, que ninguna factura explica: a un gasto, tampoco)
    begin
      perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6KM3'), '[{"cuenta": "6130"}]'::jsonb);
      v_x := 'entró';
    exception when others then v_x := sqlstate || case when sqlerrm like '%Es su desembolso%' then '' else ':otro' end;
    end;
    v_obt := v_obt || ' a_gasto=' || v_x;
    perform fn_banco_clasificar(pg_temp.c6_mov('1098', 'C6KM2'), '[{"cuenta": "2510", "monto": "950.00"}, {"cuenta": "7100", "monto": "50.00"}]'::jsonb);
    v_obt := v_obt || ' pago_partido=' || pg_temp.c6_est('1098', 'C6KM2');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 300);
  end;
  insert into _pruebas values (160, 'la línea de crédito dada de alta después: propuestas rehechas, desembolso a su cuenta', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 161. LOS BOTONES DE ANTES, LA DIRECCIÓN DE «ES LA TRANSFERENCIA CON …» Y
--      EL ORDEN DE LO QUE FALTA (ronda 4d; L08 y H09): una propuesta hecha
--      por otra versión del banco (el pegado de antes) no enseña sus botones
--      en v_banco_bandeja hasta el siguiente «Casar» (su texto lo dice): los
--      de antes ya no valen (pulsados, el criterio de hoy los frenaría o los
--      dejaría pasar distinto). Un depósito no se propone como la otra
--      mitad de un retiro que el banco hizo DESPUÉS (el dinero no llega antes
--      de salir). Y lo que falta en la conciliación de apertura va en un
--      orden fijo (antes cambiaba de una vez a otra sin que nada cambiara).
do $$
declare
  v_obt text;
  v_esp text := 'vieja=sin_botones:t nueva=con_botones direccion=t orden_fijo=t';
  d     date := nullif(current_setting('mx6.desde', true), '')::date;
  v_m   uuid;
begin
  if d is null then
    insert into _pruebas values (161, 'los botones de antes no se enseñan; la transferencia en su dirección; lo que falta en orden fijo', v_esp,
                                 'omitida: falta mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    perform pg_temp.c6_sin_aviso();
    perform fn_banco_importar_ofx(pg_temp.c6_ofx_xml('banco', '1097', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 3, 'monto', '1000.00', 'id', 'C6KN1',
                                 'nombre', 'ONLINE TRANSFER FROM CHK ...1098 TRANSACTION#: 11'))),
            '1097', 'c6-pruebas-4d-dir-r.ofx');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 9, null, jsonb_build_array(
              jsonb_build_object('tipo', 'XFER', 'fecha', d + 6, 'monto', '-1000.00', 'id', 'C6KN2', 'nombre', 'ONLINE TRANSFER TO SAVINGS'))),
            '1098', 'c6-pruebas-4d-dir-b.qfx');
    v_m := pg_temp.c6_mov('1097', 'C6KN1');
    perform fn_banco_casar(v_m);
    -- (la propuesta del depósito, como si la hubiera hecho la versión de antes)
    perform fn_banco_marca('movimiento:' || v_m);
    update movimientos_banco set propuesta = propuesta || jsonb_build_object('version', fn_banco_version() - 1) where id = v_m;
    perform fn_banco_marca(null);
    v_obt := 'vieja=' || (select case when b.opciones is null then 'sin_botones' else 'con_botones' end || ':'
                                 || case when b.texto like '%antes del último pegado del banco%' then 't' else 'f' end
                            from v_banco_bandeja b where b.movimiento_id = v_m);
    perform fn_banco_marca('movimiento:' || v_m);
    update movimientos_banco set propuesta = propuesta || jsonb_build_object('version', fn_banco_version()) where id = v_m;
    perform fn_banco_marca(null);
    v_obt := v_obt || ' nueva=' || (select case when b.opciones is null then 'sin_botones' else 'con_botones' end
                                      from v_banco_bandeja b where b.movimiento_id = v_m);
    -- (el retiro de 1098 es de DESPUÉS: no es la otra mitad de este depósito)
    v_obt := v_obt || ' direccion=' || case when not exists (select 1 from movimientos_banco m
                                                                cross join jsonb_array_elements(m.propuesta->'opciones') o
                                                               where m.id = v_m and o->'args'->'p_con'->>'movimiento' = pg_temp.c6_mov('1098', 'C6KN2')::text)
                                            then 't' else 'f' end;
    v_obt := v_obt || ' orden_fijo=' || case when position('string_agg(x.texto, ''; '' order by x.texto'
                                                             in (select p.prosrc from pg_proc p
                                                                  where p.oid = 'public.fn_conciliacion_recalcular(uuid)'::regprocedure)) > 0
                                             then 't' else 'f' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when sqlstate 'MXT01' then v_obt := 'omitida: la apertura está cerrada y sin su asiento';
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 300);
  end;
  insert into _pruebas values (161, 'los botones de antes no se enseñan; la transferencia en su dirección; lo que falta en orden fijo', v_esp,
                               coalesce(v_obt, '-'), case when v_obt like 'omitida%' then null else coalesce(v_obt = v_esp, false) end);
end $$;

-- 162. LOS PRÉSTAMOS DE CUOTA SEMANAL (ronda 5, 9-oct): un préstamo que se
--      paga cada semana se da de alta con «frecuencia: semanal» (52 cuotas
--      al año; antes todo préstamo era mensual). La porción corriente es el
--      capital de las próximas 52 cuotas (aquí el préstamo entero: vence
--      dentro del año); la fórmula parte el interés por semana (tasa / 52)
--      y lo que da es lo del portal del prestamista al centavo (37.50 y
--      262.50; a la semana, 35.53 y 264.47); la cuota de la semana
--      siguiente no es «un abono a días de la anterior» (la regla de los 25
--      días se mide con el período: 5 en una semanal), y un pago a 3 días
--      sí pide el statement, con «otra semana de interés». Una frecuencia
--      que no existe, un número que no es de la lista, o los dos en
--      desacuerdo, paran con su mensaje (22023). Cambiar la frecuencia de un
--      préstamo con cuotas sí se puede (no mueve su saldo). Las cuentas son
--      las de los préstamos de negocio (2540/2550, c1 del 9-oct); sin ellas
--      la prueba sale «omitida». El control mide la DIFERENCIA libro −
--      préstamos en 2540/2550 antes y después (el libro puede traer saldo
--      ahí sin préstamo registrado: la apertura antes de su bloque de los
--      préstamos), no que el cuadre siga igual.
do $$
declare
  v_nom  text := 'préstamos de cuota semanal: 52 al año, el interés por semana, la porción corriente entera, los días por período';
  v_obt  text;
  v_esp  text := 'alta=52 corriente=5000.00/0.00 particion=37.50/262.50/52 propuesta=cuota_prestamo:sin_statement '
                 'cuota1=1098:-300.00|2540:262.50|7100:37.50 cuota2=formula:264.47/35.53 saldo=4473.03 tres_dias=pide:otra semana '
                 'mal=22023,22023,22023 cambio=12/2225.89 control=igual';
  v_p    uuid;
  v_m    uuid;
  v_ok0  boolean;
  v_dif0 numeric;
  v_part jsonb;
  v_mal  text := '';
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (162, v_nom, v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  if not exists (select 1 from cuentas c where c.codigo = '2540' and c.imputable and c.activa)
     or not exists (select 1 from cuentas c where c.codigo = '2550' and c.imputable and c.activa) then
    insert into _pruebas values (162, v_nom, v_esp, 'omitida: faltan las cuentas 2540 y 2550 (c1 del 9-oct)', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_ok0 := (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prestamos']) c where c.vista = 'cuadre: préstamos');
    v_dif0 := pg_temp.c6_dif_prestamos();
    v_p := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS SEMANAL', 'descripcion', 'préstamo de prueba, semanal',
             'principal', '12000.00', 'tasa_anual', '39.00', 'cuota', '300.00', 'primer_pago', (d - 120)::text, 'frecuencia', 'semanal',
             'cuenta', '2540', 'cuenta_largo', '2550', 'saldo_inicial', '5000.00', 'saldo_inicial_al', (d - 1)::text,
             'cuenta_banco', '1098', 'descriptor', 'C6 PRUEBAS SEMANAL'))->>'id')::uuid;
    v_obt := 'alta=' || (select x.cuotas_al_anio from v_prestamos x where x.prestamo_id = v_p);
    -- El saldo del préstamo en el libro (la apertura lo traerá de QuickBooks; aquí, a mano en el mes).
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: el préstamo semanal (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '5000.00'),
                                  jsonb_build_object('cuenta', '2540', 'monto', '-5000.00'))));
    v_obt := v_obt || (select format(' corriente=%s/%s', x.porcion_corriente, x.porcion_largo_plazo) from v_prestamos x
                        where x.prestamo_id = v_p);
    v_part := fn_prestamo_particion(v_p, d + 7, 300.00);
    v_obt := v_obt || format(' particion=%s/%s/%s', v_part->>'interes', v_part->>'capital',
                             case when v_part->>'formula' like '%/ 52,%' then '52' else v_part->>'formula' end);
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 7,  'monto', '-300.00', 'id', 'C6W1', 'nombre', 'C6 PRUEBAS SEMANAL PMT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 14, 'monto', '-300.00', 'id', 'C6W2', 'nombre', 'C6 PRUEBAS SEMANAL PMT'))),
            '1098', 'c6-pruebas-semanal.qfx');
    perform fn_banco_casar_todo('1098');
    v_m := pg_temp.c6_mov('1098', 'C6W1');
    v_obt := v_obt || (select format(' propuesta=%s:%s', m.propuesta->>'motivo',
                                     case when coalesce((m.propuesta->'particion'->>'pide_statement')::boolean, false)
                                          then 'pide_statement' else 'sin_statement' end)
                         from movimientos_banco m where m.id = v_m);
    perform pg_temp.c6_como('dueno');
    perform fn_prestamo_cuota(v_p, v_m);
    execute 'reset role';
    v_obt := v_obt || ' cuota1=' || (select string_agg(l.cuenta || ':' || l.monto, '|' order by l.cuenta)
                                       from asiento_lineas l join movimientos_banco m on m.asiento_id = l.asiento_id
                                      where m.id = v_m);
    -- La de la semana siguiente (a 7 días): la fórmula otra vez, sobre el saldo que queda.
    perform fn_prestamo_cuota(v_p, pg_temp.c6_mov('1098', 'C6W2'));
    v_obt := v_obt || ' cuota2=' || (select q.fuente || ':' || q.capital || '/' || q.interes from prestamo_cuotas q
                                      where q.movimiento_id = pg_temp.c6_mov('1098', 'C6W2') and q.anulada_el is null)
                   || ' saldo=' || (select x.saldo from v_prestamos x where x.prestamo_id = v_p);
    -- Un pago a 3 días de la última cuota: pide el statement (otra SEMANA de interés, no otro mes).
    v_part := fn_prestamo_particion(v_p, d + 17, 300.00);
    v_obt := v_obt || ' tres_dias=' || case when coalesce((v_part->>'pide_statement')::boolean, false)
                                                 and v_part->>'aviso' like '%otra semana de interés%'
                                            then 'pide:otra semana' else coalesce(v_part->>'aviso', '-') end;
    -- Lo que no se entiende para y lo dice.
    begin
      perform fn_prestamo_guardar(jsonb_build_object('id', v_p, 'frecuencia', 'cada luna'));
      v_mal := v_mal || 'paso,';
    exception when others then v_mal := v_mal || sqlstate || ',';
    end;
    begin
      perform fn_prestamo_guardar(jsonb_build_object('id', v_p, 'cuotas_al_anio', 13));
      v_mal := v_mal || 'paso,';
    exception when others then v_mal := v_mal || sqlstate || ',';
    end;
    begin
      perform fn_prestamo_guardar(jsonb_build_object('id', v_p, 'frecuencia', 'semanal', 'cuotas_al_anio', 12));
      v_mal := v_mal || 'paso';
    exception when others then v_mal := v_mal || sqlstate;
    end;
    v_obt := v_obt || ' mal=' || v_mal;
    -- La frecuencia se cambia con cuotas registradas (no mueve el saldo): la porción corriente, por mes otra vez.
    perform fn_prestamo_guardar(jsonb_build_object('id', v_p, 'frecuencia', 'mensual'));
    v_obt := v_obt || (select format(' cambio=%s/%s', x.cuotas_al_anio, x.porcion_corriente) from v_prestamos x where x.prestamo_id = v_p);
    v_obt := v_obt || ' control=' || case when pg_temp.c6_dif_prestamos() = v_dif0
                                           and (v_dif0 <> 0 or (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prestamos']) c
                                                                 where c.vista = 'cuadre: préstamos') is not distinct from v_ok0)
                                          then 'igual' else 'cambió' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 300);
  end;
  insert into _pruebas values (162, v_nom, v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 163. LO QUE ENCONTRÓ LA VERIFICACIÓN DE LA RONDA 5 (9-oct, tarde), con el
--      mismo préstamo semanal de cifras inventadas (12,000 al 39 %, cuota
--      300.00, se deben 5,000.00). (a) Tres cuotas registradas ANTES que el
--      banco con el statement (a 7 días, por el mismo monto) y sus tres
--      cargos: cada uno casa solo con la cuota de SU fecha (R8 «la cuota ya
--      registrada») y la cuota toma su cargo (movimiento_id); des-casar uno
--      lo suelta y casarlo a mano (fn_banco_casar_con {asiento}) lo retoma.
--      Antes ninguno casaba (la ventana de cada cargo abarcaba dos cuotas) y
--      la bandeja era R1 con la más vieja primero. Un cargo AJENO por el
--      mismo monto al día siguiente de una cuota registrada no casa con ella
--      (el descriptor del prestamista) y la cuota sigue libre. (b) El banco
--      cobra 325.00 (un recargo de 25.00) dos días después por una cuota
--      registrada antes que tiene otra registrada después: la bandeja
--      ofrece solo «la diferencia a interés» de ESA cuota (no la de la
--      vecina) y dice cómo ir a capital; a capital es MX008 (nombra
--      fn_prestamo_cuota_anular) y nada queda a medias; a interés entra con
--      el mismo capital y el saldo no se mueve. (c) fn_prestamo_cuota_anular:
--      la última sin cargo se anula (su asiento se reversa, el saldo vuelve);
--      la que tiene su cargo, una ya anulada y una que no es la última,
--      MX008. (d) Un extra chico (25.00 sobre 300.00) se ofrece primero como
--      recargo con su motivo (el capital de la cuota, el interés más el
--      recargo) y uno grande (100.00) a capital sin motivo; registrar la
--      cuota rehace la propuesta pendiente de la siguiente (su saldo). (e)
--      Un pago que no cubre el interés de la semana pide el statement
--      (MX008), no entra entero a interés. (f) «cada 2 semanas» es 26,
--      «Quincenal » 24 y «cada  mes» 12, y los textos dicen «de la quincena»
--      y «otras dos semanas». Sin las cuentas 2540 y 2550, «omitida».
do $$
declare
  v_nom  text := 'la verificación de la ronda 5: cuotas registradas antes a 7 días, el recargo con una posterior, anular, el extra chico, '
                 'la frecuencia';
  v_obt  text;
  v_esp  text := 'casados=3 pares=3 suelta=t retoma=t ajeno=pendiente:cuota_prestamo d_libre=t propuesta=cuota_prestamo:interes '
                 'sin_capital=t solo_cercana=t aviso=t capital=MX008:anular '
                 'sustituye=casado:cuota_prestamo 268.45/56.55 saldo=3667.67 anular=ok:3938.13 con_cargo=MX008 repetida=MX008 '
                 'orden=MX008 anular2=ok:3938.13 recargo=270.46/54.54:motivo grande=capital:sin_motivo rehecha=3667.67 '
                 'usura=pide:no alcanza usura_cuota=MX008 frec=26/24/12 textos=de la quincena/otras dos semanas control=igual';
  v_p    uuid;
  v_u    uuid;
  v_m    uuid;
  v_m4   uuid;
  v_q    prestamo_cuotas;
  v_r    jsonb;
  v_o    jsonb;
  v_dif0 numeric;
  v_ok0  boolean;
  v_x    text;
  d      date := nullif(current_setting('mx6.desde', true), '')::date;
begin
  if d is null then
    insert into _pruebas values (163, v_nom, v_esp, 'omitida: falta mes abierto', null);
    return;
  end if;
  if not exists (select 1 from cuentas c where c.codigo = '2540' and c.imputable and c.activa)
     or not exists (select 1 from cuentas c where c.codigo = '2550' and c.imputable and c.activa) then
    insert into _pruebas values (163, v_nom, v_esp, 'omitida: faltan las cuentas 2540 y 2550 (c1 del 9-oct)', null);
    return;
  end if;
  begin
    perform pg_temp.c6_montar();
    v_dif0 := pg_temp.c6_dif_prestamos();
    v_ok0 := (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prestamos']) c where c.vista = 'cuadre: préstamos');
    v_p := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS SEMANAL', 'descripcion', 'préstamo de prueba, semanal',
             'principal', '12000.00', 'tasa_anual', '39.00', 'cuota', '300.00', 'primer_pago', (d - 120)::text, 'frecuencia', 'semanal',
             'cuenta', '2540', 'cuenta_largo', '2550', 'saldo_inicial', '5000.00', 'saldo_inicial_al', (d - 1)::text,
             'cuenta_banco', '1098', 'descriptor', 'C6 PRUEBAS SEMANAL'))->>'id')::uuid;
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: el préstamo semanal (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '5000.00'),
                                  jsonb_build_object('cuenta', '2540', 'monto', '-5000.00'))));
    -- (a) tres cuotas con el statement, antes que el banco, a 7 días; y sus cargos
    perform fn_prestamo_cuota(v_p, null, d + 1,  '300.00', '262.50', '37.50', 'c6-pruebas: del statement');
    perform fn_prestamo_cuota(v_p, null, d + 8,  '300.00', '264.47', '35.53', 'c6-pruebas: del statement');
    perform fn_prestamo_cuota(v_p, null, d + 15, '300.00', '266.45', '33.55', 'c6-pruebas: del statement');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d, d + 20, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 1,  'monto', '-300.00', 'id', 'C6Y1', 'nombre', 'C6 PRUEBAS SEMANAL PMT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 8,  'monto', '-300.00', 'id', 'C6Y2', 'nombre', 'C6 PRUEBAS SEMANAL PMT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 15, 'monto', '-300.00', 'id', 'C6Y3', 'nombre', 'C6 PRUEBAS SEMANAL PMT'))),
            '1098', 'c6-pruebas-semanal-antes.qfx');
    perform fn_banco_casar_todo('1098');
    v_obt := format('casados=%s pares=%s',
                    (select count(*) from movimientos_banco m
                      where m.cuenta = '1098' and m.id_externo in ('C6Y1', 'C6Y2', 'C6Y3') and m.estado = 'casado'
                        and m.casado_regla = 'R8 la cuota ya registrada'),
                    (select count(*) from movimientos_banco m
                      join prestamo_cuotas q on q.movimiento_id = m.id and q.anulada_el is null
                      where m.cuenta = '1098' and m.id_externo in ('C6Y1', 'C6Y2', 'C6Y3') and q.fecha = m.fecha));
    v_m := pg_temp.c6_mov('1098', 'C6Y2');
    select q.* into v_q from prestamo_cuotas q where q.prestamo_id = v_p and q.fecha = d + 8 and q.anulada_el is null;
    perform fn_banco_descasar(v_m, 'c6-pruebas: lo suelto para volver a casarlo a mano');
    v_obt := v_obt || ' suelta=' || case when (select q.movimiento_id from prestamo_cuotas q where q.id = v_q.id) is null then 't' else 'f' end;
    perform fn_banco_casar_con(v_m, jsonb_build_object('asiento', v_q.asiento_id));
    v_obt := v_obt || ' retoma=' || case when (select q.movimiento_id from prestamo_cuotas q where q.id = v_q.id) = v_m then 't' else 'f' end;
    -- (b) el recargo del banco, dos días después, sobre una cuota registrada antes con otra registrada después;
    -- y un cargo ajeno por el mismo monto al día siguiente de la cuota, que no es suyo
    perform fn_prestamo_cuota(v_p, null, d + 20, '300.00', '268.45', '31.55', 'c6-pruebas: del statement');
    perform fn_prestamo_cuota(v_p, null, d + 26, '300.00', '270.46', '29.54', 'c6-pruebas: del statement');
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 21, d + 23, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 21, 'monto', '-300.00', 'id', 'C6Y4A', 'nombre', 'C6 PRUEBAS FERRETERIA'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 22, 'monto', '-325.00', 'id', 'C6Y4', 'nombre', 'C6 PRUEBAS SEMANAL PMT'))),
            '1098', 'c6-pruebas-semanal-recargo.qfx');
    perform fn_banco_casar_todo('1098');
    v_m4 := pg_temp.c6_mov('1098', 'C6Y4');
    select q.* into v_q from prestamo_cuotas q where q.prestamo_id = v_p and q.fecha = d + 20 and q.anulada_el is null;
    v_obt := v_obt || format(' ajeno=%s d_libre=%s', pg_temp.c6_est('1098', 'C6Y4A'), case when v_q.movimiento_id is null then 't' else 'f' end);
    select m.propuesta into v_r from movimientos_banco m where m.id = v_m4;
    v_obt := v_obt || format(' propuesta=%s:%s sin_capital=%s solo_cercana=%s aviso=%s', v_r->>'motivo',
                             case when v_r->'opciones'->0->'args'->'p_con'->>'cuota' = v_q.id::text
                                  then v_r->'opciones'->0->'args'->'p_con'->>'diferencia' else '-' end,
                             case when exists (select 1 from jsonb_array_elements(v_r->'opciones') o
                                                where o->'args'->'p_con'->>'cuota' = v_q.id::text
                                                  and o->'args'->'p_con'->>'diferencia' = 'capital') then 'f' else 't' end,
                             case when exists (select 1 from jsonb_array_elements(v_r->'opciones') o
                                                where o->'args'->'p_con'->>'cuota' <> v_q.id::text) then 'f' else 't' end,
                             case when v_r->>'texto' like '%fn_prestamo_cuota_anular%' then 't' else 'f' end);
    begin
      perform fn_banco_casar_con(v_m4, jsonb_build_object('cuota', v_q.id, 'diferencia', 'capital'));
      v_x := 'entró';
    exception when others then v_x := sqlstate || case when sqlerrm like '%fn_prestamo_cuota_anular%' then ':anular' else '' end;
    end;
    v_obt := v_obt || ' capital=' || v_x;
    perform fn_banco_casar_con(v_m4, jsonb_build_object('cuota', v_q.id, 'diferencia', 'interes'));
    v_obt := v_obt || format(' sustituye=%s %s saldo=%s', pg_temp.c6_est('1098', 'C6Y4'),
                             (select q.capital || '/' || q.interes from prestamo_cuotas q where q.movimiento_id = v_m4 and q.anulada_el is null),
                             (select x.saldo from v_prestamos x where x.prestamo_id = v_p));
    -- (c) anular: la última sin cargo sí; con cargo, ya anulada o no la última, no
    select q.* into v_q from prestamo_cuotas q where q.prestamo_id = v_p and q.fecha = d + 26 and q.anulada_el is null;
    v_r := fn_prestamo_cuota_anular(v_q.id, 'c6-pruebas: la registré de más');
    v_obt := v_obt || format(' anular=%s:%s',
                             case when (select q.anulada_el from prestamo_cuotas q where q.id = v_q.id) is not null
                                       and exists (select 1 from asientos r where r.reversa_a = v_q.asiento_id and r.camino = 'reverso')
                                  then 'ok' else 'f' end,
                             (select x.saldo from v_prestamos x where x.prestamo_id = v_p));
    begin
      perform fn_prestamo_cuota_anular((select q.id from prestamo_cuotas q where q.movimiento_id = v_m4 and q.anulada_el is null),
                                       'c6-pruebas: tiene su cargo');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' con_cargo=' || v_x;
    begin
      perform fn_prestamo_cuota_anular(v_q.id, 'c6-pruebas: otra vez');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' repetida=' || v_x;
    perform fn_prestamo_cuota(v_p, null, d + 23, '300.00', '270.46', '29.54', 'c6-pruebas: del statement');
    perform fn_prestamo_cuota(v_p, null, d + 25, '300.00', '272.49', '27.51', 'c6-pruebas: del statement');
    begin
      perform fn_prestamo_cuota_anular((select q.id from prestamo_cuotas q where q.prestamo_id = v_p and q.fecha = d + 23 and q.anulada_el is null),
                                       'c6-pruebas: no es la última');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' orden=' || v_x;
    perform fn_prestamo_cuota_anular((select q.id from prestamo_cuotas q where q.prestamo_id = v_p and q.fecha = d + 25 and q.anulada_el is null),
                                     'c6-pruebas: de la última hacia atrás');
    perform fn_prestamo_cuota_anular((select q.id from prestamo_cuotas q where q.prestamo_id = v_p and q.fecha = d + 23 and q.anulada_el is null),
                                     'c6-pruebas: de la última hacia atrás');
    v_obt := v_obt || format(' anular2=%s:%s',
                             case when (select count(*) from prestamo_cuotas q where q.prestamo_id = v_p and q.anulada_el is null) = 4
                                  then 'ok' else 'f' end,
                             (select x.saldo from v_prestamos x where x.prestamo_id = v_p));
    -- (d) el extra chico (un recargo) y el grande; la propuesta de la siguiente, rehecha
    perform fn_banco_importar_ofx(pg_temp.c6_qfx('banco', '000000001098', d + 26, d + 27, null, jsonb_build_array(
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 27, 'monto', '-325.00', 'id', 'C6Y5', 'nombre', 'C6 PRUEBAS SEMANAL PMT'),
              jsonb_build_object('tipo', 'DEBIT', 'fecha', d + 27, 'monto', '-400.00', 'id', 'C6Y6', 'nombre', 'C6 PRUEBAS SEMANAL PMT'))),
            '1098', 'c6-pruebas-semanal-extra.qfx');
    perform fn_banco_casar_todo('1098');
    select m.propuesta->'opciones'->0 into v_o from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6Y5');
    v_obt := v_obt || format(' recargo=%s/%s:%s', v_o->'args'->>'p_capital', v_o->'args'->>'p_interes',
                             case when coalesce((v_o->>'pide_motivo')::boolean, false) and v_o->>'texto' like '%recargo%'
                                  then 'motivo' else 'sin_motivo' end);
    select m.propuesta->'opciones'->0 into v_r from movimientos_banco m where m.id = pg_temp.c6_mov('1098', 'C6Y6');
    v_obt := v_obt || ' grande=' || case when v_r->>'texto' like '%más 100.00 a capital%' and not (v_r ? 'pide_motivo')
                                              and not (v_r->'args' ? 'p_capital')
                                         then 'capital:sin_motivo' else coalesce(v_r->>'texto', '-') end;
    perform fn_prestamo_cuota(v_p, pg_temp.c6_mov('1098', 'C6Y5'), null, null, v_o->'args'->>'p_capital', v_o->'args'->>'p_interes',
                              'c6-pruebas: pagué tarde, 25.00 de recargo');
    v_obt := v_obt || ' rehecha=' || coalesce((select m.propuesta->'particion'->>'saldo_antes' from movimientos_banco m
                                                where m.id = pg_temp.c6_mov('1098', 'C6Y6')), '-');
    -- (e) el pago que no cubre el interés de la semana
    v_u := (fn_prestamo_guardar(jsonb_build_object('prestamista', 'C6 PRUEBAS USURA', 'principal', '11000.00', 'tasa_anual', '99',
             'cuota', '150.00', 'primer_pago', (d + 3)::text, 'frecuencia', 'semanal', 'cuenta', '2540', 'cuenta_largo', '2550',
             'saldo_inicial', '11000.00', 'saldo_inicial_al', (d - 1)::text, 'cuenta_banco', '1098',
             'descriptor', 'C6 PRUEBAS USURA'))->>'id')::uuid;
    perform fn_postear(jsonb_build_object('fecha', d::text, 'descripcion', 'c6-pruebas: el préstamo caro (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '1098', 'monto', '11000.00'),
                                  jsonb_build_object('cuenta', '2550', 'monto', '-11000.00'))));
    v_r := fn_prestamo_particion(v_u, d + 10, 150.00);
    v_obt := v_obt || ' usura=' || case when coalesce((v_r->>'pide_statement')::boolean, false)
                                             and v_r->>'aviso' like '%no alcanza el interés de la semana%'
                                        then 'pide:no alcanza' else coalesce(v_r->>'aviso', '-') end;
    begin
      perform fn_prestamo_cuota(v_u, null, d + 10, '150.00');
      v_x := 'entró';
    exception when others then v_x := sqlstate;
    end;
    v_obt := v_obt || ' usura_cuota=' || v_x;
    -- (f) la frecuencia como se escribe, y los textos del período
    v_obt := v_obt || format(' frec=%s/%s/%s',
                             fn_prestamo_guardar(jsonb_build_object('id', v_u, 'frecuencia', 'cada 2 semanas'))->>'cuotas_al_anio',
                             fn_prestamo_guardar(jsonb_build_object('id', v_u, 'frecuencia', 'Quincenal '))->>'cuotas_al_anio',
                             fn_prestamo_guardar(jsonb_build_object('id', v_u, 'frecuencia', 'cada  mes'))->>'cuotas_al_anio')
                   || ' textos=' || fn_prestamo_periodo(24, 'del') || '/' || fn_prestamo_periodo(26, 'otro');
    v_obt := v_obt || ' control=' || case when pg_temp.c6_dif_prestamos() = v_dif0
                                           and (v_dif0 <> 0 or (select c.ok from fn_banco_control(current_setting('mx6.mes'), array['v_prestamos']) c
                                                                 where c.vista = 'cuadre: préstamos') is not distinct from v_ok0)
                                          then 'igual' else 'cambió' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 300);
  end;
  insert into _pruebas values (163, v_nom, v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 61. NO DEJA RASTRO: todo lo de arriba se deshizo. El libro, los papeles,
--     el banco y su historial, las reglas, los descriptores, los eventos,
--     los contadores, las secuencias de la app y las huellas están como al
--     empezar. Va la última.
do $$
declare
  v_antes text := current_setting('mx6.foto', true);
  v_ahora text;
begin
  v_ahora := pg_temp.c6_foto();
  insert into _pruebas values (61, 'no deja rastro: todo como al empezar', v_antes, v_ahora, v_ahora = v_antes);
end $$;

reset jit;

-- =====================================================================
-- EL RESULTADO TAMBIÉN QUEDA EN UNA TABLA DE VERDAD, como el de c4: el SQL
-- Editor de Supabase deja de esperar a los pocos minutos y enseña un error
-- de red, pero la corrida sigue en el servidor hasta el final. Por eso la
-- tabla temporal _pruebas se copia aquí a pruebas.c6_resultado, fuera de
-- la API: PostgREST no expone el esquema pruebas, y ni anon, ni
-- authenticated ni service_role pueden usarlo. Si el editor se cansó, la
-- corrida entera se lee después con
--   select * from pruebas.c6_resultado order by n;
-- Guarda solo la última corrida, con su hora. No es parte del libro (la
-- foto de «no deja rastro» no la mira) y se borra, cuando ya no haga
-- falta, con «drop schema pruebas cascade».
-- =====================================================================
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c6_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c6_resultado from public, anon, authenticated, service_role;
truncate pruebas.c6_resultado;
insert into pruebas.c6_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
