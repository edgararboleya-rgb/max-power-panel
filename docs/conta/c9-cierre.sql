-- =====================================================================
-- c9-cierre.sql — EL CIERRE DEL MES, LA RONDA NOCTURNA, LOS ACTIVOS FIJOS Y
-- LA RESERVA DE IMPUESTOS · c9 (la Fase 8; f08 lo llama «c8-cierre.sql»
-- por un nombre viejo: c8 ya es el contador).
-- 7-nov-2026, v1. Se pega en el SQL Editor DESPUÉS de c1, c2, c3, c4, c6,
-- c7, s1, p1 y c8 (c7, s1, p1 y c8 pueden faltar: lo que no está no se
-- revisa, y se dice). Idempotente: se puede volver a pegar entero (no
-- pisa la configuración, ni un cierre, ni un activo, ni lo que la ronda ya
-- escribió). Después se pega c9-pruebas.sql.
--
-- Qué hace:
--   · EL CIERRE. Hoy un período se cierra con fn_cerrar_periodo (c2), que
--     mira lo del libro: que ya terminó (hora de Miami), que va en orden
--     (la apertura primero, con su asiento vivo), que cuadra, y toma la
--     foto de la cadena. Lo que NO mira es lo de alrededor: los cargos del
--     banco que siguen sin clasificar, la conciliación de cada cuenta al
--     último día del mes, las propuestas de la IA que esperan un toque, la
--     depreciación del mes sin postear, un control del libro o del banco
--     en rojo. Eso es lo que hace esta capa: fn_cierre_revisar(periodo)
--     recorre una lista FIJA de controles, en orden, cada uno con su nivel
--     («detiene» o «aviso»), si está en verde, el detalle en llano con
--     números, qué hacer y a qué página de la app ir; y fn_cierre_cerrar
--     (periodo, confirmación) vuelve a revisar DENTRO de la misma
--     transacción, con el candado de la cadena puesto (nadie postea
--     mientras), y si algo que detiene está en rojo para con MX010 y la
--     lista; si no, llama a fn_cerrar_periodo (c2: el candado es el suyo,
--     aquí no se reimplementa nada) y guarda la fila de cierres: la
--     revisión entera, el hash del mayor del mes (fn_cierre_hash_mayor), la
--     balanza del mes como quedó (para que la ronda compare después),
--     quién y cuándo. Edgar confirma escribiendo exactamente «CERRAR
--     OCTUBRE 2026» («CERRAR LA APERTURA» para la apertura; «CERRAR EL AÑO
--     2026» para un año, que la app no ofrece: el año lo cierra el CPA):
--     un toque de más no cierra nada, porque un cierre no se deshace.
--   · QUÉ SE VIGILA, EN QUÉ ORDEN, Y QUÉ DETIENE (f08, adaptado a lo que
--     la base ya tiene; fn_cierre_revisar, columna orden):
--       10  orden: los períodos anteriores (la apertura incluida) cerrados    detiene
--       15  calendario: el período ya terminó (hora de Miami)                 detiene
--       20  apertura: su asiento de apertura está vivo (solo la apertura)     detiene
--       30  cuadre: debe = haber en el período (fn_estado, c2)               detiene
--       40  banco: todo lo del mes casado o clasificado (cuántos y cuánto,
--           y cuántos tienen propuesta de la IA esperando el toque)           detiene
--       42  ia: propuestas del mes sin decidir (c8, si está)                  aviso
--       50  banco: cada cuenta con estado de cuenta conciliada y confirmada
--           al último día del mes (la apertura: su conciliación de apertura,
--           como aviso)                                                       detiene
--       52  banco: partidas en tránsito de más de 30 días                     aviso
--       60  2010: lo que se le debe a cada proveedor (el auxiliar, la
--           antigüedad y lo que no tiene proveedor; el statement del supply
--           se compara a mano)                                                aviso
--       70  obras: cada línea de costo e ingreso del mes con su obra (el
--           auxiliar por obra suma lo mismo que el mayor; c4 lo cuadra
--           también en «estados»)                                             detiene
--       80  recibos: los tickets del mes sin foto (anotados a mano: su
--           respaldo es el statement, c3)                                     aviso
--       82  recibos: los tickets del mes con impuesto desconocido             aviso
--       90  activos: 1590 = la depreciación acumulada de activos_fijos        detiene
--       92  activos: la depreciación del mes posteada (si hay activos)        detiene
--      100+ libro: fn_verificar_cadena (c2), un renglón por control en rojo   detiene
--      110+ banco (c6): los cuadres de fn_banco_control del período, un
--           renglón por cuadre en rojo (también «cada cuenta hasta el fin
--           del mes»: c6 lo mira sin frenar; aquí frena)                      detiene
--      120+ estados (c4): fn_estados_control del período (antigüedad de
--           pagar = mayor —2010 por proveedor—, el auxiliar por obra = mayor,
--           las protecciones), un renglón por cuadre en rojo                   detiene
--           («apertura en el libro», «caja chica en rojo» y lo de QuickBooks: aviso)
--      130+ puentes (c3): fn_puentes_verificar, un renglón por control rojo   detiene
--      140+ cobros en línea (p1, si está): v_stripe_control
--           (cuadre: detiene; alarma: aviso)
--      145+ ia (c8, si está): v_contador_control (cuadre: detiene; alarma: aviso)
--      150  cambios: cuántos reversos y cuántos asientos de la IA hubo en el
--           mes y cuánto suman (informativo, siempre en verde)                aviso
--      160  subs: COI vigente de cada sub pagado en el mes (sin datos de COI
--           todavía —llegan con f12a— lo dice, en verde)                      aviso
--      170  mano de obra y costo por obra (c10, si está): los cuadres de
--           v_jornal_control y v_margen_control, en una fila               detiene
--      171  mano de obra y costo por obra (c10, si está): sus avisos, en
--           una fila                                                        aviso
--     En verde cada capa deja UN renglón resumen; en rojo, un renglón por
--     control, con el detalle que esa capa escribió. Cada renglón dice qué
--     hacer y a qué página ir (ir_a: bandeja, conciliar, movimientos,
--     estados, cobros, conexiones, cierre, o nulo). La revisión de un
--     período también se guarda (cierre_revisiones: la última, con su hora)
--     para que v_cierre_estado diga cuántos detienen sin volver a correrla.
--   · LA RONDA NOCTURNA (fn_ronda, SQL puro, sin API): corre la revisión
--     del período abierto más viejo que ya terminó (o del mes en curso si
--     ninguno terminó), y los controles globales: la balanza y el hash del
--     mayor de CADA mes cerrado contra los guardados en cierres (si alguien
--     escribió en un mes cerrado por debajo de las guardas, se nota), 1590
--     contra los activos, la reserva 1030 y los estimados de impuestos que
--     vencen en 15 días. Escribe ronda_resultados (fecha de Miami, hora,
--     período, orden, control, nivel, ok, detalle, qué hacer), guarda 90
--     días, y por cada rojo NUEVO respecto de la corrida anterior manda UN
--     aviso al teléfono del dueño por fn_cartero (si existe; nunca con
--     mxp.cierre_sin_push = '1', que usan las pruebas; nunca con
--     cierre_config.aviso_push apagado). La IA no se dispara de noche: la
--     ronda no llama al contador ni a nada que gaste. pg_cron la programa a
--     las 11:45 UTC (mxp-ronda-contable): después de la sincronización de
--     Plaid (11:00) y del contador de la mañana (11:25); en Miami son las
--     6:45 de la mañana en invierno y las 7:45 en verano (pg_cron va en UTC
--     y Miami cambia de horario dos veces al año). v_ronda_ultima enseña la
--     última corrida; conta.js la lee al abrir y, si hay rojo, lo dice.
--   · LOS ACTIVOS FIJOS (activos_fijos): descripción, placa o serie, su
--     cuenta 15xx, fecha en servicio, costo, residual, vida en meses,
--     método libro (línea recta, o manual: un monto fijo al mes), la
--     depreciación acumulada de arranque (lo que QuickBooks traía al 30-sep),
--     el asiento del alta, y su baja o venta. fn_depreciacion_mes(periodo)
--     postea EL asiento del mes, Dr 6950 / Cr 1590, una línea de 6950 por
--     activo vivo (línea recta mensual hasta el residual, o el monto
--     manual) y una de 1590 por el total, por el camino que c2 permite:
--     fn_postear como el dueño (camino mano, procedencia fn_postear), con
--     la descripción «Depreciación de octubre de 2026 (c9)» y su detalle
--     por activo en activos_depreciaciones (periodo, activo, monto, asiento).
--     Idempotente: una segunda vez no duplica (devuelve el que ya estaba).
--     Hoy no hay activos: se cargan en f12 con la cédula del CPA, y hasta
--     entonces todo lo dice en llano y en verde (1590 trae lo de QuickBooks
--     y se comprueba cuando los activos estén).
--   · LA RESERVA DE IMPUESTOS (1030): v_reserva_impuestos calcula lo que
--     debería haber: la utilidad del año a la fecha (de las cuentas de
--     resultados del libro, con la regla de ejercicio de c4: un ajuste del
--     CPA es del año que corrige) × el % que fije el CPA
--     (cierre_config.reserva_pct) − los estimados ya pagados (los pagos a
--     3200 que Edgar marca como impuesto: reserva_estimados →
--     fn_reserva_estimado_marcar) = el objetivo de 1030; y dice «transfiere
--     $X» o «sobra $Y». Sin el %: «falta el % que fije el CPA», y ninguna
--     cifra inventada. Los estimados vencen el 15-abr, 15-jun, 15-sep y
--     15-ene: la vista dice el próximo y si cae en 15 días, y la ronda avisa.
--   · EL DR-15 (v_dr15_mes): por mes, la base del use tax (las compras que
--     la IA marcó «use_tax» y Edgar aprobó, c8), lo cargado y lo pagado en
--     2300, y su saldo; las ventas gravables y el sales tax cobrado todavía
--     no se saben (las facturas de la app no separan el impuesto: f10) y la
--     columna nota lo dice.
--   · EL EXPORT. La pantalla genera los archivos (CSV del mayor, PDF) y los
--     sube al bucket privado «cierres», carpeta <periodo>/ (2026-10/…;
--     2026-09-APERTURA/… para la apertura); después llama a
--     fn_cierre_export(periodo, archivos) con la lista [{ruta, sha256,
--     bytes}] y la base la registra en cierres (export_ruta,
--     export_archivos, exportado_el, exportado_por), comprobando que cada
--     archivo está en Storage. Se puede repetir: el último gana, los
--     anteriores quedan en export_historial. Este archivo crea el bucket y
--     sus policies (solo el dueño sube y lee; nadie borra ni pisa por la
--     API) si Storage existe. El hash del mayor que va en el export es
--     fn_cierre_hash_mayor: sha256 del texto que forman las líneas del
--     período ordenadas por fecha, posición en la cadena y línea, cada una
--     «numero|fecha|orden|cuenta|monto|proyecto_id|cost_code|memo» (vacío
--     cuando es nulo), unidas por salto de línea. Se puede recalcular fuera
--     de la base desde el CSV del mayor: por eso no lleva nada que el CSV
--     no traiga.
--
-- LA SEGURIDAD (la regla de c2, B.20, y lo que c6, c4 y c8 sellan):
--   · NINGUNA función de aquí es SECURITY DEFINER. Las que llama la
--     pantalla (fn_cierre_revisar, fn_cierre_cerrar, fn_cierre_export,
--     fn_cierre_config, fn_activo_alta, fn_activo_baja,
--     fn_depreciacion_mes, fn_reserva_estimado_marcar,
--     fn_reserva_estimado_anular, y las auxiliares que esas usan) son
--     SECURITY INVOKER, sin EXECUTE para public, anon ni service_role, con
--     EXECUTE para authenticated y es_dueno() por dentro (fn_cierre_exigir_
--     dueno): leen con la policy de cada tabla (solo el dueño) y escriben
--     con la policy de escritura del dueño de las tablas de c9. Así el
--     control «permisos» de c2 sigue en verde: una SECURITY DEFINER que
--     leyera el libro y la API ejecutara saldría en rojo (hoy le pasa en
--     producción a fn_costos_marcar, de otra sesión: c9 lo dice en llano y
--     eso SÍ detiene el cierre hasta que se arregle).
--   · Las de la ronda (fn_ronda y lo que solo ella usa): sin API, revocadas
--     de todos; corren como el dueño de la base (pg_cron, el SQL Editor):
--     fn_cierre_sin_api → fn_desde_editor (c2).
--   · Las tablas nuevas nacen con RLS y policies solo-dueño (leer, y
--     escribir en las que escribe una función INVOKER). Y todas llevan la
--     guarda de c6: un trigger (fn_cierre_guarda) que solo deja escribir
--     con la marca de la transacción (mx_cierre.escribe = la tabla), que
--     ponen las funciones de aquí y nadie más: un update a mano desde
--     PostgREST, aunque sea del dueño, da MX003. cierres no se borra y solo
--     cambia en sus columnas de export; activos_depreciaciones y
--     ronda_resultados no se editan (la ronda borra lo de más de 90 días).
--   · Las vistas son security_invoker y leen solo TABLAS (nunca una vista
--     de c3, c4, c6, p1 o c8, que se rehacen al volver a pegar su archivo y
--     pararían con MX000) y funciones de aquí.
--   · Nada lleva un prefijo que otra capa sella (fn_banco_%, fn_puente_%,
--     fn_estados_%, fn_stripe_%, fn_plaid_%, fn_contador_%): aquí todo es
--     fn_cierre_%, fn_ronda, fn_activo_%, fn_depreciacion_mes, fn_reserva_%,
--     y las vistas v_cierre%, v_cierres, v_ronda_%, v_activos_fijos,
--     v_reserva_impuestos, v_dr15_mes. es_dueno() no se toca.
--   · Lo que la pantalla escribe pasa por PostgREST con la sesión del
--     dueño: s1 (el código del teléfono) exige aal2 en cada petición si el
--     dueño tiene factor; la pantalla pide el código como la del contador.
--     Esta capa no añade nada a eso.
--
-- LOS ERRORES CON NOMBRE (conta.js los traduce mirando el código):
--   MX000  falta algo que este archivo da por hecho (precondición): no se
--          aplica nada (fn_cierre_precondiciones dice qué)
--   MX002  el período no existe, ya está cerrado, es el año (el año lo
--          cierra el CPA), o se quiere exportar o depreciar uno que no
--          corresponde; y los MX002 de c2 que salen tal cual
--   MX003  las tablas de c9 solo las escriben sus funciones (la guarda); un
--          cierre no se borra ni se edita; una depreciación posteada no se
--          toca (se reversa en el libro)
--   MX004  la cuenta de un activo no es una 15xx imputable y activa, o
--          falta 6950 o 1590
--   MX005  un monto mal: costo, residual, vida, monto mensual, bytes
--   MX008  ya estaba: el activo ya está dado de baja, el asiento ya está
--          marcado como estimado, el estimado ya está anulado
--   MX010  EL CIERRE SE DETIENE: algo que detiene está en rojo. El mensaje
--          trae la lista en llano (qué, cuánto y qué hacer) y la pista dice
--          cómo pedirla entera (fn_cierre_revisar)
--   22023  entrada mal formada: la confirmación no es exacta («CERRAR
--          OCTUBRE 2026»), una clave desconocida, una fecha que no es
--          AAAA-MM-DD, una ruta fuera de la carpeta del período, un sha256
--          que no lo es, un archivo que no está en el bucket
--   42501  permiso: solo el dueño; anon y service_role, nada; la ronda,
--          solo pg_cron y el SQL Editor
--
-- Decisiones de diseño (lo que f08 y el contrato dejaban abierto):
--   · QUÉ DETIENE Y QUÉ AVISA (arriba). Los recibos sin foto no detienen:
--     c3 los acepta a propósito («anotado a mano: el respaldo es el
--     statement»), y la app tiene «compra sin recibo»; se avisa cuántos.
--     El impuesto desconocido tampoco: el ticket entró por su total, que es
--     lo que se pagó; lo que no se sabe es si llevaba impuesto (DR-15). La
--     conciliación de la APERTURA es aviso: sus diferencias las explica la
--     auditoría de la apertura (c4). Los controles de las otras capas
--     entran con su propio nivel: lo que esa capa llama «cuadre» detiene,
--     lo que llama «alarma» avisa; en c4, «apertura en el libro» (una
--     apertura hecha a mano no es la de la balanza de QuickBooks, pero c2
--     deja cerrar con ella), «la caja chica no queda en rojo» y los cuadres
--     contra QuickBooks avisan (la comparación con QuickBooks es la tarea de
--     Edgar de f08, no un freno).
--   · LA CONCILIACIÓN «AL ÚLTIMO DÍA DEL MES» vale para cada cuenta con
--     estado de cuenta en uso (bancos 10xx menos la caja chica, y las
--     tarjetas de la tabla tarjetas, con movimientos del banco hasta ese
--     día): una conciliación CONFIRMADA (c6) con fecha de corte en el último
--     día del mes o después. Una tarjeta que corta su statement a mitad de
--     mes se concilia igual al 31 con su actividad reciente importada hasta
--     ese día (lo mismo que pide el cuadre 58 de c6, «cada cuenta hasta el
--     fin del mes»).
--   · LA REVISIÓN SE GUARDA (cierre_revisiones, la última por período) y
--     v_cierre_estado lee de ahí «detienen» y «avisos» con su hora
--     (revisado_el): una vista que corriera la revisión entera (los
--     controles de c4 y c6 incluidos) en cada lectura de la pantalla
--     pasaría de los 8 s de la API en producción. La pantalla llama a
--     fn_cierre_revisar(periodo) al abrir (y después de cada arreglo), y
--     eso refresca la fila. fn_cierre_revisar escribe, así que se llama con
--     POST (supabase-js .rpc lo hace así).
--   · LA DEPRECIACIÓN entra por fn_postear (camino mano, el único que c2
--     abre a una función INVOKER): el asiento no lleva origen_tabla (eso es
--     de los puentes DEFINER de c3) y por eso la idempotencia la lleva c9
--     (activos_depreciaciones apunta al asiento; mientras ese asiento esté
--     vivo no se postea otro). Convención: un activo deprecia el mes
--     completo en que entra en servicio y no deprecia el mes de su baja; la
--     cuota es (costo − residual) / vida_meses, al centavo, y la última
--     absorbe el redondeo (nunca pasa del residual). El método libro lo
--     decide el CPA (▶ f08): cierre_config.metodo_depreciacion es el de las
--     altas nuevas; cada activo guarda el suyo.
--   · LOS ESTIMADOS PAGADOS se marcan apuntando al asiento del pago
--     (reserva_estimados.asiento_id, el Dr 3200 que c8 propone para un pago
--     al IRS): nada nuevo en el libro ni en las capas selladas. Un estimado
--     mal marcado se anula con su motivo (queda).
--   · EL AÑO FISCAL de un estimado pagado en enero es el año anterior (el
--     del 15-ene); se puede decir otro.
--   · EL HASH DEL MAYOR no incluye el hash de la cadena de cada asiento
--     (eso ya lo guarda c2 en cadena_al_cerrar): así se recalcula desde el
--     CSV exportado con lo que el CSV trae.
--
-- Lo que este archivo NO toca: c1..c8, s1, p1, es_dueno(), docs/sql, el
-- libro (solo postea la depreciación por fn_postear, como el dueño), el
-- banco (solo lee), las tablas de la app (solo lee recibos, proveedores,
-- perfiles, tarjetas). No reabre un período: la regla A de f08 vive en c2
-- (un ajuste del CPA va al mes abierto con tipo ajuste_cpa y
-- afecta_periodo; un error de un mes cerrado se corrige con fn_reversar).
-- OPERACION.md dice qué hacer cuando algo falla.
--
-- Cómo se instala (Edgar, en este orden, con la cadena pegada como dice
-- pruebas/conta/README.md):
--   1. Database → Extensions: pg_cron habilitado (f08, «Tú»).
--   2. SQL Editor → pegar ESTE archivo entero → Run. Al final sale una
--      tabla: la configuración, las tablas y vistas, el bucket «cierres»,
--      el estado de cada período, cuál es el siguiente cierre y QUÉ LO
--      DETIENE HOY (resumido), los activos, la reserva, la ronda (pg_cron sí
--      o no) y el paso siguiente. Si algo de lo que da por hecho falta,
--      para con MX000 y no queda nada.
--   3. SQL Editor → pegar docs/conta/c9-pruebas.sql → sus filas, todas en
--      true (las que dependen de poder cerrar octubre con datos reales
--      salen «omitida» y dicen por qué; no es un fallo).
--   4. En la app: Contabilidad → Cierre. La lista de octubre dice qué falta
--      (hoy: los movimientos sin clasificar de la bandeja, las
--      conciliaciones al 31-oct, y el control «permisos» de c2 por
--      fn_costos_marcar). Primero se cierra la apertura («CERRAR LA
--      APERTURA»), después octubre («CERRAR OCTUBRE 2026»), y «Exportar»
--      sube el mayor y lo registra. Mañana a las 6:45 (7:45 en verano) corre
--      la ronda sola.
--   Para apagar la ronda: select fn_cierre_config('{"ronda_activa": false}');
--   (o desde Cierre → ajustes). Para apagar los avisos al teléfono:
--   '{"aviso_push": false}'. El % de la reserva: '{"reserva_pct": 25}'.
--
-- Lo que llama la pantalla (RPC, como el dueño, con POST):
--   fn_cierre_revisar(p_periodo text)                      la lista de controles
--   fn_cierre_cerrar(p_periodo text, p_confirmo text)      cierra (MX010 si algo detiene)
--   fn_cierre_export(p_periodo text, p_archivos jsonb)     registra lo subido a Storage
--   fn_cierre_config(p jsonb)                              ronda_activa, reserva_pct, metodo_depreciacion, aviso_push
--   fn_activo_alta(p jsonb) / fn_activo_baja(p_id uuid, p_fecha date, p_motivo text, p_asiento_id uuid)
--   fn_depreciacion_mes(p_periodo text)                    postea el asiento del mes (idempotente)
--   fn_reserva_estimado_marcar(p_asiento uuid, p_nota text, p_anio_fiscal int) / fn_reserva_estimado_anular(p_id uuid, p_motivo text)
--   fn_cierre_hash_mayor(p_periodo text) / fn_cierre_balanza(p_periodo text) / fn_cierre_confirmacion(p_periodo text)
-- Y lee: v_cierre_estado, v_cierres, v_ronda_ultima, v_activos_fijos,
-- v_reserva_impuestos, v_dr15_mes, cierre_config.
-- Lo que llama pg_cron: fn_ronda(). Montos en dólares, numeric(14,2).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Las guardas, y lo que este archivo da por hecho (MX000 sin tocar nada)
-- ---------------------------------------------------------------------
-- ¿Quién llama por la API? Solo el dueño. Desde el SQL Editor o pg_cron
-- (current_user no es un rol de la API) pasa. Solo es_dueno(), como c4 y
-- c6: fn_desde_editor no es ejecutable por authenticated y Postgres pide
-- permiso sobre cada función de la expresión aunque no la evalúe.
create or replace function public.fn_cierre_exigir_dueno() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if current_user in ('authenticated', 'anon') and not coalesce(es_dueno(), false) then
    raise exception using errcode = '42501', message = 'El cierre lo ve y lo toca solo Edgar (el dueño).';
  end if;
end $$;
revoke execute on function public.fn_cierre_exigir_dueno() from public, anon, service_role;
grant  execute on function public.fn_cierre_exigir_dueno() to authenticated;
comment on function public.fn_cierre_exigir_dueno() is 'c9: la guarda de lo que llama la pantalla: por la API solo el dueño (es_dueno); el SQL Editor y pg_cron pasan.';

-- La ronda y lo que solo ella usa: pg_cron o el SQL Editor; nadie de la API.
create or replace function public.fn_cierre_sin_api() returns void
language plpgsql stable
set search_path = public, pg_temp
as $$
begin
  if fn_desde_editor() then return; end if;
  raise exception using errcode = '42501',
    message = 'La ronda la corre pg_cron (o el SQL Editor); la app no.';
end $$;
revoke execute on function public.fn_cierre_sin_api() from public, anon, authenticated, service_role;
comment on function public.fn_cierre_sin_api() is 'c9: la guarda de la ronda: solo pg_cron o el SQL Editor (fn_desde_editor, c2).';

-- Lo que falta para pegar c9, en llano (nulo = nada). La usan la
-- precondición de abajo y las pruebas.
create or replace function public.fn_cierre_precondiciones() returns text
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v_falta text[] := '{}';
  v_x     text;
  v_v     bigint;
begin
  foreach v_x in array array['es_dueno()', 'fn_desde_editor()', 'fn_fecha_miami(timestamptz)', 'fn_postear(jsonb)',
                             'fn_cerrar_periodo(text)', 'fn_verificar_cadena()', 'fn_estado(text)', 'fn_libro_version()',
                             'fn_banco_control(text,text[])', 'fn_estados_control(text,text[])', 'fn_puentes_verificar()'] loop
    if to_regprocedure('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  foreach v_x in array array['cuentas', 'periodos', 'asientos', 'asiento_lineas', 'perfiles', 'proveedores', 'recibos',
                             'puente_documentos', 'puente_cuentas', 'tarjetas', 'movimientos_banco', 'archivos_banco',
                             'conciliaciones', 'conciliacion_partidas'] loop
    if to_regclass('public.' || v_x) is null then
      v_falta := v_falta || v_x;
    end if;
  end loop;
  if cardinality(v_falta) > 0 then
    return format('c9 se pega después de c1, c2, c3, c4 y c6 (y de c7, s1, p1 y c8 si se usan): falta %s.',
                  array_to_string(v_falta, ', '));
  end if;
  -- La versión de c2 que va con esta capa (la del tiempo en producción).
  execute 'select public.fn_libro_version()' into v_v;
  if coalesce(v_v, 0) < 2026100201 then
    return format('el c2-libro.sql pegado es anterior (marca %s; esta capa pide 2026100201): vuelve a pegar c2-libro.sql.', v_v);
  end if;
  -- Las cuentas que esta capa nombra: la depreciación (6950 y 1590), la
  -- reserva (1030), el use tax (2300) y las distribuciones (3200).
  select string_agg(c, ', ' order by c) into v_x
    from unnest(array['1030', '1590', '2300', '3200', '6950']) c
   where not exists (select 1 from cuentas k where k.codigo = c);
  if v_x is not null then
    return format('faltan en el plan de cuentas (c1): %s. Vuelve a pegar c1-plan-de-cuentas.sql.', v_x);
  end if;
  -- Una tabla con el nombre de las de c9 que no sea de c9: se para antes de
  -- tocar nada (la lección de c8 con ia_propuestas).
  foreach v_x in array array['cierre_config:reserva_pct', 'cierres:hash_mayor', 'cierre_revisiones:revision',
                             'ronda_resultados:corrida_el', 'activos_fijos:vida_meses', 'activos_depreciaciones:activo_id',
                             'reserva_estimados:anio_fiscal'] loop
    if to_regclass('public.' || split_part(v_x, ':', 1)) is not null
       and not exists (select 1 from information_schema.columns
                        where table_schema = 'public' and table_name = split_part(v_x, ':', 1) and column_name = split_part(v_x, ':', 2)) then
      return format('la tabla %s ya existe en esta base y no es la de c9 (no tiene la columna %s): otra cosa usa ese nombre. No la toco; avisa antes de seguir.',
                    split_part(v_x, ':', 1), split_part(v_x, ':', 2));
    end if;
  end loop;
  if not fn_desde_editor() then
    return 'Pégalo en el SQL Editor de Supabase: desde la app no se instala nada.';
  end if;
  if not exists (select 1 from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true)) then
    return 'no hay un dueño activo en perfiles: los avisos de la ronda van al dueño.';
  end if;
  -- Nada ajeno colgado de las vistas de c9 (se borran y se rehacen).
  select string_agg(distinct format('la vista %s', dc.oid::regclass), ', ') into v_x
    from pg_depend d
    join pg_rewrite rw on d.classid = 'pg_rewrite'::regclass and rw.oid = d.objid
    join pg_class dc on dc.oid = rw.ev_class
    join pg_class cv on d.refclassid = 'pg_class'::regclass and cv.oid = d.refobjid
   where cv.relnamespace = 'public'::regnamespace and cv.relkind = 'v'
     and cv.relname in ('v_cierre_estado', 'v_cierres', 'v_ronda_ultima', 'v_activos_fijos', 'v_reserva_impuestos', 'v_dr15_mes')
     and dc.oid <> cv.oid
     and not (dc.relnamespace = 'public'::regnamespace
              and dc.relname in ('v_cierre_estado', 'v_cierres', 'v_ronda_ultima', 'v_activos_fijos', 'v_reserva_impuestos', 'v_dr15_mes'));
  if v_x is not null then
    return format('%s depende(n) de las vistas de c9, que al pegarlo se borran y se rehacen: guarda su definición, bórralas, pega c9 '
                  'y vuelve a crearlas.', v_x);
  end if;
  return null;
end $$;
revoke execute on function public.fn_cierre_precondiciones() from public, anon, authenticated, service_role;
comment on function public.fn_cierre_precondiciones() is 'c9: lo que falta para pegar c9-cierre.sql (nulo = nada): c1, c2 (marca 2026100201), c3, c4 y c6, las cuentas 1030/1590/2300/3200/6950, el SQL Editor, un dueño activo, ninguna tabla ajena con nombre de c9 y nada ajeno sobre sus vistas.';

do $$
declare
  v text;
begin
  v := public.fn_cierre_precondiciones();
  if v is not null then
    raise exception using errcode = 'MX000',
      message = 'c9-cierre NO se aplicó, no se tocó nada: ' || v,
      hint    = 'El orden de pegado es c1, c2, c3, c4, c6, c7, s1, p1, c8 y después este archivo (pruebas/conta/README.md, §0).';
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 1. Las tablas (nacen cerradas: solo el dueño lee; escribe solo el dueño
--    por las funciones de aquí, con la marca de la transacción). Montos en
--    dólares, numeric(14,2). Llaves foráneas a periodos, asientos, cuentas,
--    perfiles y entre tablas de c9. Para crecer, «add column if not exists».
-- ---------------------------------------------------------------------
-- La configuración: una sola fila. reserva_pct nace vacío (lo fija el CPA);
-- metodo_depreciacion es el de las altas nuevas (cada activo guarda el
-- suyo); aviso_push, si la ronda avisa al teléfono.
create table if not exists public.cierre_config (
  id                   int         primary key,
  ronda_activa         boolean     not null default true,
  reserva_pct          numeric(5,2),
  metodo_depreciacion  text        not null default 'linea_recta',
  aviso_push           boolean     not null default true,
  actualizado          timestamptz not null default now(),
  actualizado_por      uuid,
  constraint cierre_config_una    check (id = 1),
  constraint cierre_config_pct    check (reserva_pct is null or reserva_pct between 0 and 100),
  constraint cierre_config_metodo check (metodo_depreciacion in ('linea_recta', 'manual'))
);
comment on table public.cierre_config is 'c9: la configuración del cierre (una fila): si la ronda nocturna corre (ronda_activa), el % de la reserva de impuestos que fija el CPA (reserva_pct; vacío hasta que lo diga), el método libro de depreciación de las altas nuevas (linea_recta o manual) y si la ronda avisa al teléfono (aviso_push). Se cambia con fn_cierre_config.';

-- Los cierres: una fila por período cerrado desde la app (la apertura, cada
-- mes, y el año si se cierra por aquí): la revisión entera como estaba al
-- cerrar, el hash del mayor, la balanza del período (para que la ronda
-- compare después), quién y cuándo; y el export (lo subido al bucket
-- «cierres», con su sha256), repetible con historial.
create table if not exists public.cierres (
  periodo            text        primary key references public.periodos (periodo),
  cerrado_el         timestamptz not null,
  cerrado_por        uuid,
  cerrado_rol        text,
  revision           jsonb       not null,
  hash_mayor         text        not null,
  balanza            jsonb       not null,
  asientos           int         not null,
  lineas             int         not null,
  export_ruta        text,
  export_archivos    jsonb,
  export_historial   jsonb       not null default '[]'::jsonb,
  exportado_el       timestamptz,
  exportado_por      uuid,
  constraint cierres_hash_forma    check (hash_mayor ~ '^[0-9a-f]{64}$'),
  constraint cierres_revision_lista check (jsonb_typeof(revision) = 'array'),
  constraint cierres_balanza_lista  check (jsonb_typeof(balanza) = 'array'),
  constraint cierres_export_forma   check ((export_ruta is null) = (export_archivos is null) and (export_ruta is null) = (exportado_el is null)),
  constraint cierres_export_lista   check (export_archivos is null or jsonb_typeof(export_archivos) = 'array')
);
comment on table public.cierres is 'c9: cada período cerrado desde la app: cuándo y quién (cerrado_el, cerrado_por, cerrado_rol), la revisión de fn_cierre_revisar tal como estaba al cerrar (revision), el hash del mayor del período (hash_mayor: fn_cierre_hash_mayor), la balanza del período (balanza: fn_cierre_balanza; la ronda la compara cada noche), y el export al bucket «cierres» (export_ruta = la carpeta, export_archivos = [{ruta, sha256, bytes}], exportado_el, exportado_por; los exports anteriores en export_historial). No se borra; solo cambian sus columnas de export (fn_cierre_export).';
comment on column public.cierres.hash_mayor is 'sha256 de las líneas del período («numero|fecha|orden|cuenta|monto|proyecto_id|cost_code|memo», ordenadas por fecha, cadena_pos y orden, unidas por salto de línea): el ancla que sale fuera de la base en el export.';
comment on column public.cierres.balanza is 'Por cuenta con movimiento hasta el último día del período: [{cuenta, inicial, debe, haber, final}]. La ronda la recalcula cada noche y la compara.';

-- La última revisión de cada período (fn_cierre_revisar la guarda al correr):
-- v_cierre_estado lee de aquí cuántos controles detienen y cuántos avisan,
-- con la hora, sin volver a correrla.
create table if not exists public.cierre_revisiones (
  periodo       text        primary key references public.periodos (periodo),
  revisado_el   timestamptz not null,
  revisado_por  uuid,
  revision      jsonb       not null,
  detienen      int         not null,
  avisos        int         not null,
  ms            int,
  constraint cierre_revisiones_lista check (jsonb_typeof(revision) = 'array')
);
comment on table public.cierre_revisiones is 'c9: la última revisión de cada período abierto (fn_cierre_revisar la reescribe al correr): cuándo, quién, las filas (revision), cuántos controles que detienen están en rojo (detienen), cuántos avisos (avisos) y cuánto tardó (ms). Lo lee v_cierre_estado.';

-- Lo que deja cada corrida de la ronda: una fila por control, con el día de
-- Miami y la hora de la corrida; se guardan 90 días. avisado: se mandó al
-- teléfono (un rojo nuevo).
create table if not exists public.ronda_resultados (
  id          bigint      generated always as identity primary key,
  fecha       date        not null,
  corrida_el  timestamptz not null,
  periodo     text,
  orden       int         not null,
  control     text        not null,
  nivel       text        not null,
  ok          boolean,
  detalle     text,
  que_hacer   text,
  ir_a        text,
  avisado     boolean     not null default false,
  aviso_fallo boolean     not null default false,   -- se intentó mandar y fn_cartero falló: la corrida siguiente lo reintenta
  constraint ronda_resultados_nivel check (nivel in ('detiene', 'aviso'))
);
alter table public.ronda_resultados add column if not exists aviso_fallo boolean not null default false;
create index if not exists ronda_resultados_corrida_idx on public.ronda_resultados (corrida_el desc);
create index if not exists ronda_resultados_fecha_idx   on public.ronda_resultados (fecha);
comment on table public.ronda_resultados is 'c9: lo que la ronda nocturna (fn_ronda, pg_cron a las 11:45 UTC) encontró en cada corrida: el día de Miami (fecha), la hora (corrida_el), el período revisado (nulo en un control global), y por control su orden, nivel (detiene o aviso), ok, detalle en llano, qué hacer y a qué página ir; avisado = ese rojo era nuevo y se mandó al teléfono; aviso_fallo = se intentó y fn_cartero falló (la corrida siguiente lo reintenta). Se guardan 90 días; v_ronda_ultima enseña la última corrida.';

-- Los activos fijos (f08): lo que QuickBooks llevaba en la cédula del CPA y
-- las altas nuevas. Depreciación libro: línea recta mensual hasta el
-- residual, o manual (monto_mensual fijo). dep_acumulada_inicial es lo ya
-- depreciado al arrancar el libro (la cédula de 2025: va dentro del 1590
-- de la apertura). La baja o venta deja el activo con estado baja, su fecha,
-- su motivo y el asiento que la registró (Dr 1590 / Cr 15xx / 4920 …,
-- posteado a mano).
create table if not exists public.activos_fijos (
  id                      uuid          primary key default gen_random_uuid(),
  descripcion             text          not null,
  placa_serie             text,
  cuenta                  text          not null references public.cuentas (codigo),
  fecha_servicio          date          not null,
  costo                   numeric(14,2) not null,
  residual                numeric(14,2) not null default 0,
  vida_meses              int,
  metodo                  text          not null default 'linea_recta',
  monto_mensual           numeric(14,2),
  dep_acumulada_inicial   numeric(14,2) not null default 0,
  asiento_alta_id         uuid          references public.asientos (id),
  estado                  text          not null default 'activo',
  baja_fecha              date,
  baja_motivo             text,
  baja_asiento_id         uuid          references public.asientos (id),
  baja_el                 timestamptz,
  baja_por                uuid,
  notas                   text,
  creado                  timestamptz   not null default now(),
  creado_por              uuid,
  constraint activos_fijos_descripcion check (btrim(descripcion) <> ''),
  constraint activos_fijos_cuenta_15xx check (cuenta ~ '^15[0-9]{2}' and cuenta <> '1590'),
  constraint activos_fijos_costo       check (costo > 0),
  constraint activos_fijos_residual    check (residual >= 0 and residual < costo),
  constraint activos_fijos_inicial     check (dep_acumulada_inicial >= 0 and dep_acumulada_inicial <= costo - residual),
  constraint activos_fijos_metodo      check (metodo in ('linea_recta', 'manual')),
  constraint activos_fijos_linea_recta check (metodo <> 'linea_recta' or (vida_meses is not null and vida_meses between 1 and 600)),
  constraint activos_fijos_manual      check (metodo <> 'manual' or (monto_mensual is not null and monto_mensual > 0)),
  constraint activos_fijos_estado      check (estado in ('activo', 'baja')),
  constraint activos_fijos_baja        check ((estado = 'baja') = (baja_fecha is not null and baja_motivo is not null and baja_el is not null))
);
create index if not exists activos_fijos_estado_idx on public.activos_fijos (estado, fecha_servicio);
comment on table public.activos_fijos is 'c9: los activos fijos (f08): descripción, placa o serie, su cuenta 15xx, fecha en servicio, costo, residual, vida en meses, método libro (linea_recta: (costo − residual) / vida_meses al mes; manual: monto_mensual fijo), la depreciación acumulada de arranque (lo depreciado antes del libro, dentro del 1590 de la apertura), el asiento del alta, y su baja o venta (fecha, motivo, el asiento que la registró). Se cargan con fn_activo_alta y se dan de baja con fn_activo_baja; la depreciación del mes la postea fn_depreciacion_mes. Hoy no hay: se cargan en f12 con la cédula del CPA.';

-- Cada depreciación posteada: período, activo, monto y el asiento del mes
-- (uno por período, con una línea de 6950 por activo). Mientras el asiento
-- siga vivo (sin reverso) el período ya está depreciado.
create table if not exists public.activos_depreciaciones (
  id          uuid          primary key default gen_random_uuid(),
  periodo     text          not null references public.periodos (periodo),
  activo_id   uuid          not null references public.activos_fijos (id),
  monto       numeric(14,2) not null,
  asiento_id  uuid          not null references public.asientos (id),
  creado      timestamptz   not null default now(),
  creado_por  uuid,
  constraint activos_depreciaciones_monto check (monto > 0)
);
create index if not exists activos_depreciaciones_periodo_idx on public.activos_depreciaciones (periodo);
create index if not exists activos_depreciaciones_activo_idx  on public.activos_depreciaciones (activo_id);
comment on table public.activos_depreciaciones is 'c9: cada depreciación posteada por fn_depreciacion_mes: el período, el activo, su monto y el asiento del mes (Dr 6950 / Cr 1590, posteado por fn_postear como el dueño). Un asiento reversado deja de contar: el mes se vuelve a postear.';

-- Los estimados de impuestos pagados (los pagos a 3200 que Edgar marca como
-- impuesto): apuntan al asiento del pago; nada nuevo en el libro.
create table if not exists public.reserva_estimados (
  id             uuid          primary key default gen_random_uuid(),
  fecha          date          not null,
  monto          numeric(14,2) not null,
  asiento_id     uuid          not null references public.asientos (id),
  anio_fiscal    int           not null,
  nota           text,
  creado         timestamptz   not null default now(),
  creado_por     uuid,
  anulado_el     timestamptz,
  anulado_por    uuid,
  anulado_motivo text,
  constraint reserva_estimados_monto    check (monto > 0),
  constraint reserva_estimados_anulado  check ((anulado_el is null) = (anulado_motivo is null))
);
-- (un asiento, un estimado VIVO; los anulados quedan como rastro)
create unique index if not exists reserva_estimados_asiento_vivo on public.reserva_estimados (asiento_id) where anulado_el is null;
comment on table public.reserva_estimados is 'c9: los pagos de impuesto estimado (el Dr 3200 del pago al IRS) que Edgar marcó como estimado (fn_reserva_estimado_marcar): fecha, monto, el asiento y el año fiscal al que van. v_reserva_impuestos los resta del objetivo de la reserva 1030. Uno marcado por error se anula con su motivo (fn_reserva_estimado_anular) y queda.';



-- ---------------------------------------------------------------------
-- 2. La guarda de las tablas de c9 (la de c6, copiada en su forma): solo se
--    escriben con la marca de la transacción (mx_cierre.escribe = el nombre
--    de la tabla), que ponen las funciones de aquí justo antes de escribir
--    y quitan después. Un insert o un update a mano —desde PostgREST,
--    aunque sea el dueño, o desde el SQL Editor sin la marca— da MX003. Y
--    lo que es rastro no se edita ni se borra. SECURITY INVOKER, sin grant
--    a nadie (la dispara la tabla).
-- ---------------------------------------------------------------------
create or replace function public.fn_cierre_guarda()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_marca text := coalesce(current_setting('mx_cierre.escribe', true), '');
begin
  if tg_op = 'TRUNCATE' then
    raise exception using errcode = 'MX003',
      message = format('%s no se trunca: es rastro del cierre.', tg_table_name);
  end if;
  if tg_op = 'DELETE' then
    if tg_table_name = 'ronda_resultados' and v_marca = 'ronda_resultados:limpieza' then
      return old;
    end if;
    raise exception using errcode = 'MX003',
      message = format('%s no se borra: %s', tg_table_name,
                       case tg_table_name
                         when 'cierres' then 'un cierre no se deshace (regla A de f08): lo que faltó entra en el mes abierto como ajuste del CPA.'
                         when 'activos_fijos' then 'un activo se da de baja con su motivo (fn_activo_baja) y queda.'
                         when 'activos_depreciaciones' then 'una depreciación posteada se corrige en el libro (fn_reversar) y se vuelve a postear el mes.'
                         when 'reserva_estimados' then 'un estimado marcado por error se anula con su motivo (fn_reserva_estimado_anular) y queda.'
                         when 'ronda_resultados' then 'solo la ronda borra lo de más de 90 días.'
                         else 'es rastro del cierre.' end);
  end if;
  if v_marca <> tg_table_name then
    raise exception using errcode = 'MX003',
      message = format('%s se escribe solo desde las funciones del cierre (%s), no a mano.', tg_table_name,
                       case tg_table_name
                         when 'cierre_config' then 'fn_cierre_config'
                         when 'cierres' then 'fn_cierre_cerrar y fn_cierre_export'
                         when 'cierre_revisiones' then 'fn_cierre_revisar'
                         when 'ronda_resultados' then 'fn_ronda'
                         when 'activos_fijos' then 'fn_activo_alta y fn_activo_baja'
                         when 'activos_depreciaciones' then 'fn_depreciacion_mes'
                         when 'reserva_estimados' then 'fn_reserva_estimado_marcar y fn_reserva_estimado_anular'
                         else 'c9' end);
  end if;
  if tg_op = 'UPDATE' then
    if tg_table_name = 'cierres' then
      -- Solo cambian las columnas del export: lo demás es la foto del cierre.
      if (new.periodo, new.cerrado_el, new.cerrado_por, new.cerrado_rol, new.revision, new.hash_mayor, new.balanza,
          new.asientos, new.lineas)
         is distinct from
         (old.periodo, old.cerrado_el, old.cerrado_por, old.cerrado_rol, old.revision, old.hash_mayor, old.balanza,
          old.asientos, old.lineas) then
        raise exception using errcode = 'MX003',
          message = format('El cierre de %s no se edita: solo se registra su export (fn_cierre_export).', old.periodo);
      end if;
    elsif tg_table_name in ('activos_depreciaciones', 'ronda_resultados') then
      raise exception using errcode = 'MX003', message = format('%s no se edita: es rastro.', tg_table_name);
    elsif tg_table_name = 'reserva_estimados' then
      -- Lo único que le pasa a un estimado es anularse (una vez).
      if (new.fecha, new.monto, new.asiento_id, new.anio_fiscal, new.creado, new.creado_por)
         is distinct from (old.fecha, old.monto, old.asiento_id, old.anio_fiscal, old.creado, old.creado_por)
         or old.anulado_el is not null then
        raise exception using errcode = 'MX003',
          message = 'Un estimado marcado no se edita: se anula con su motivo (una vez) y se marca el bueno.';
      end if;
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.fn_cierre_guarda() from public, anon, authenticated, service_role;
comment on function public.fn_cierre_guarda() is 'c9: la guarda de las tablas de c9: se escriben solo con la marca de la transacción (mx_cierre.escribe) que ponen sus funciones; un cierre no se borra ni se edita (solo su export), una depreciación o una fila de la ronda no se editan, un estimado solo se anula.';

do $$
declare
  t text;
begin
  foreach t in array array['cierre_config', 'cierres', 'cierre_revisiones', 'ronda_resultados', 'activos_fijos',
                           'activos_depreciaciones', 'reserva_estimados'] loop
    execute format('create or replace trigger trg_%s_guarda before insert or update or delete on public.%I '
                   'for each row execute function public.fn_cierre_guarda()', t, t);
    execute format('create or replace trigger trg_%s_sin_truncate before truncate on public.%I '
                   'for each statement execute function public.fn_cierre_guarda()', t, t);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 3. Los permisos: RLS, «solo el dueño lee», y en las tablas que escribe
--    una función INVOKER, la policy de escritura del dueño (con la guarda
--    de arriba delante: la policy dice quién, la marca dice por dónde).
--    anon y service_role, nada; la secuencia de la ronda, nada.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array['cierre_config', 'cierres', 'cierre_revisiones', 'ronda_resultados', 'activos_fijos',
                           'activos_depreciaciones', 'reserva_estimados'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    for p in select pl.policyname from pg_policies pl where pl.schemaname = 'public' and pl.tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy %I on public.%I for select to authenticated using ((select es_dueno()))', t || '_dueno', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
  -- Lo que escriben las funciones de la pantalla (como el dueño).
  foreach t in array array['cierre_config', 'cierres', 'cierre_revisiones', 'activos_fijos', 'reserva_estimados'] loop
    execute format('create policy %I on public.%I for update to authenticated using ((select es_dueno())) with check ((select es_dueno()))',
                   t || '_dueno_edita', t);
    execute format('grant update on public.%I to authenticated', t);
  end loop;
  foreach t in array array['cierres', 'cierre_revisiones', 'activos_fijos', 'activos_depreciaciones', 'reserva_estimados'] loop
    execute format('create policy %I on public.%I for insert to authenticated with check ((select es_dueno()))',
                   t || '_dueno_anade', t);
    execute format('grant insert on public.%I to authenticated', t);
  end loop;
  execute 'revoke all on sequence public.ronda_resultados_id_seq from public, anon, authenticated, service_role';
end $$;

-- La fila de la configuración (con la marca de la guarda): al volver a pegar
-- no se pisa nada.
do $$
begin
  if not exists (select 1 from public.cierre_config where id = 1) then
    perform set_config('mx_cierre.escribe', 'cierre_config', true);
    insert into public.cierre_config (id) values (1);
    perform set_config('mx_cierre.escribe', '', true);
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 4. Lo común: dinero en llano, el nombre de un período, la confirmación
--    exacta, el período siguiente, el dueño, la balanza y el hash del
--    mayor. Todo SECURITY INVOKER; lo que la pantalla puede necesitar
--    lleva EXECUTE para authenticated (solo lee con la policy del dueño).
-- ---------------------------------------------------------------------
-- Dólares como se leen: $1,234.56 (negativo con su signo).
create or replace function public.fn_cierre_usd(p numeric) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select case when p is null then '—'
              when p < 0 then '-$' || to_char(-p, 'FM999,999,999,990.00')
              else '$' || to_char(p, 'FM999,999,999,990.00') end
$$;
revoke execute on function public.fn_cierre_usd(numeric) from public, anon, service_role;
grant  execute on function public.fn_cierre_usd(numeric) to authenticated;
comment on function public.fn_cierre_usd(numeric) is 'c9: un monto en dólares como se lee ($1,234.56).';

-- El detalle de otro control (un jsonb como el de fn_verificar_cadena o
-- fn_puentes_verificar) en una frase: cada lista no vacía con su nombre y
-- sus elementos; lo demás, su número. Cortado a 700 letras.
create or replace function public.fn_cierre_llano(p jsonb) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select left(coalesce(
           (select string_agg(x.txt, ' · ' order by x.k)
              from (select e.key as k,
                           case when jsonb_typeof(e.value) = 'array' and jsonb_array_length(e.value) > 0
                                then e.key || ': ' || (select string_agg(case when jsonb_typeof(v) = 'string' then v #>> '{}' else v::text end, '; ')
                                                         from jsonb_array_elements(e.value) v)
                                when jsonb_typeof(e.value) in ('number', 'string', 'boolean') then e.key || ' ' || (e.value #>> '{}')
                                end as txt
                      from jsonb_each(case when jsonb_typeof(p) = 'object' then p else '{}'::jsonb end) e) x
             where x.txt is not null),
           case when jsonb_typeof(p) = 'object' then '' else p::text end), 700)
$$;
revoke execute on function public.fn_cierre_llano(jsonb) from public, anon, service_role;
grant  execute on function public.fn_cierre_llano(jsonb) to authenticated;
comment on function public.fn_cierre_llano(jsonb) is 'c9: el detalle jsonb de un control de otra capa en una frase legible.';

-- El mes en español, en mayúsculas (para la confirmación) o en minúsculas.
create or replace function public.fn_cierre_mes_nombre(p date) returns text
language sql immutable
set search_path = public, pg_temp
as $$
  select (array['ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO', 'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE',
                'NOVIEMBRE', 'DICIEMBRE'])[extract(month from p)::int]
$$;
revoke execute on function public.fn_cierre_mes_nombre(date) from public, anon, service_role;
grant  execute on function public.fn_cierre_mes_nombre(date) to authenticated;
comment on function public.fn_cierre_mes_nombre(date) is 'c9: el nombre del mes en español, en mayúsculas (OCTUBRE).';

-- Cómo se nombra un período en una frase: «octubre de 2026», «la apertura
-- (30-sep-2026)», «el año 2026».
create or replace function public.fn_cierre_nombre(p_periodo text) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select case p.tipo
           when 'mes' then lower(fn_cierre_mes_nombre(p.desde)) || ' de ' || p.anio
           when 'apertura' then 'la apertura (' || to_char(p.desde, 'DD') || '-' || lower(left(fn_cierre_mes_nombre(p.desde), 3)) || '-' || p.anio || ')'
           else 'el año ' || p.anio end
    from periodos p where p.periodo = p_periodo
$$;
revoke execute on function public.fn_cierre_nombre(text) from public, anon, service_role;
grant  execute on function public.fn_cierre_nombre(text) to authenticated;
comment on function public.fn_cierre_nombre(text) is 'c9: el período en una frase: «octubre de 2026», «la apertura (30-sep-2026)», «el año 2026».';

-- La confirmación EXACTA que pide fn_cierre_cerrar: «CERRAR OCTUBRE 2026»,
-- «CERRAR LA APERTURA», «CERRAR EL AÑO 2026». Nulo si el período no existe.
create or replace function public.fn_cierre_confirmacion(p_periodo text) returns text
language sql stable
set search_path = public, pg_temp
as $$
  select case p.tipo
           when 'mes' then 'CERRAR ' || fn_cierre_mes_nombre(p.desde) || ' ' || p.anio
           when 'apertura' then 'CERRAR LA APERTURA'
           else 'CERRAR EL AÑO ' || p.anio end
    from periodos p where p.periodo = p_periodo
$$;
revoke execute on function public.fn_cierre_confirmacion(text) from public, anon, service_role;
grant  execute on function public.fn_cierre_confirmacion(text) to authenticated;
comment on function public.fn_cierre_confirmacion(text) is 'c9: el texto exacto que hay que escribir para cerrar ese período («CERRAR OCTUBRE 2026», «CERRAR LA APERTURA», «CERRAR EL AÑO 2026»).';

-- El período, o MX002 en llano si no existe.
create or replace function public.fn_cierre_periodo(p_periodo text) returns public.periodos
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  p periodos;
begin
  select * into p from periodos where periodo = p_periodo;
  if not found then
    raise exception using errcode = 'MX002',
      message = format('No existe el período «%s»: un mes es AAAA-MM (2026-10), la apertura es 2026-09-APERTURA y un año es AAAA.',
                       coalesce(p_periodo, ''));
  end if;
  return p;
end $$;
revoke execute on function public.fn_cierre_periodo(text) from public, anon, service_role;
grant  execute on function public.fn_cierre_periodo(text) to authenticated;
comment on function public.fn_cierre_periodo(text) is 'c9: la fila del período, o MX002 si no existe.';

-- El que toca cerrar ahora: el abierto más viejo entre la apertura y los
-- meses (el orden de c2). Nulo si todo está cerrado.
create or replace function public.fn_cierre_siguiente() returns text
language sql stable
set search_path = public, pg_temp
as $$
  select p.periodo from periodos p
   where p.tipo in ('mes', 'apertura') and p.estado = 'abierto'
   order by p.desde limit 1
$$;
revoke execute on function public.fn_cierre_siguiente() from public, anon, service_role;
grant  execute on function public.fn_cierre_siguiente() to authenticated;
comment on function public.fn_cierre_siguiente() is 'c9: el período que toca cerrar ahora (el abierto más viejo entre la apertura y los meses).';

-- El dueño (el activo más antiguo): a quién avisa la ronda.
create or replace function public.fn_cierre_dueno() returns uuid
language sql stable
set search_path = public, pg_temp
as $$
  select p.id from perfiles p where p.rol = 'dueno' and coalesce(p.activo, true) order by p.creado limit 1
$$;
revoke execute on function public.fn_cierre_dueno() from public, anon, authenticated, service_role;
comment on function public.fn_cierre_dueno() is 'c9: el dueño activo más antiguo (a quien avisa la ronda).';

-- La balanza del período: por cuenta con movimiento hasta su último día,
-- el saldo inicial (antes del período), debe y haber del período y el saldo
-- final, al centavo, ordenada por cuenta. Es lo que se guarda al cerrar y
-- lo que la ronda recalcula cada noche para compararlo: como nada se fecha
-- dentro de un período cerrado, tiene que salir igual.
create or replace function public.fn_cierre_balanza(p_periodo text) returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  with p as (select * from periodos where periodo = p_periodo)
  select coalesce(jsonb_agg(jsonb_build_object('cuenta', x.cuenta, 'inicial', x.inicial, 'debe', x.debe, 'haber', x.haber,
                                               'final', x.final) order by x.cuenta), '[]'::jsonb)
    from (select l.cuenta,
                 coalesce(sum(l.monto) filter (where a.fecha_contable < p.desde), 0)::numeric(14,2)                       as inicial,
                 coalesce(sum(l.monto) filter (where a.fecha_contable >= p.desde and l.monto > 0), 0)::numeric(14,2)      as debe,
                 coalesce(-sum(l.monto) filter (where a.fecha_contable >= p.desde and l.monto < 0), 0)::numeric(14,2)     as haber,
                 coalesce(sum(l.monto), 0)::numeric(14,2)                                                                  as final
            from p
            join asientos a on a.fecha_contable <= p.hasta
            join asiento_lineas l on l.asiento_id = a.id
           group by l.cuenta) x
$$;
revoke execute on function public.fn_cierre_balanza(text) from public, anon, service_role;
grant  execute on function public.fn_cierre_balanza(text) to authenticated;
comment on function public.fn_cierre_balanza(text) is 'c9: la balanza del período por cuenta ([{cuenta, inicial, debe, haber, final}]): lo que cierres guarda al cerrar y la ronda compara cada noche.';

-- EL HASH DEL MAYOR del período: sha256 del texto que forman sus líneas,
-- ordenadas por fecha, posición en la cadena y línea, cada una
-- «numero|fecha|orden|cuenta|monto|proyecto_id|cost_code|memo» (vacío cuando
-- es nulo), unidas por salto de línea. Se recalcula fuera de la base desde
-- el CSV del mayor: es el ancla del export (CONTA-PLAN §3.6).
create or replace function public.fn_cierre_hash_mayor(p_periodo text) returns text
language sql stable
set search_path = public, pg_temp
as $$
  with p as (select * from periodos where periodo = p_periodo)
  select encode(sha256(convert_to(coalesce(
           (select string_agg(concat_ws('|', a.numero, to_char(a.fecha_contable, 'YYYY-MM-DD'), l.orden::text, l.cuenta,
                                        l.monto::text, coalesce(l.proyecto_id, ''), coalesce(l.cost_code, ''), coalesce(l.memo, '')),
                              E'\n' order by a.fecha_contable, a.cadena_pos, l.orden)
              from p
              join asientos a on (p.tipo = 'anio' and a.anio = p.anio) or (p.tipo <> 'anio' and a.periodo = p.periodo)
              join asiento_lineas l on l.asiento_id = a.id), ''), 'UTF8')), 'hex')
$$;
revoke execute on function public.fn_cierre_hash_mayor(text) from public, anon, service_role;
grant  execute on function public.fn_cierre_hash_mayor(text) to authenticated;
comment on function public.fn_cierre_hash_mayor(text) is 'c9: sha256 del mayor del período (sus líneas «numero|fecha|orden|cuenta|monto|proyecto_id|cost_code|memo», en orden, unidas por salto de línea): el ancla que va en el export.';

-- Lo del período en el libro: cuántos asientos y líneas, y si cuadra
-- (fn_estado, c2).
create or replace function public.fn_cierre_cuadre(p_periodo text) returns jsonb
language sql stable
set search_path = public, pg_temp
as $$
  select jsonb_build_object('asientos', e.asientos, 'lineas', e.filas, 'debe', e.total_debe, 'haber', e.total_haber, 'cuadra', e.cuadra)
    from fn_estado(p_periodo) e
$$;
revoke execute on function public.fn_cierre_cuadre(text) from public, anon, service_role;
grant  execute on function public.fn_cierre_cuadre(text) to authenticated;
comment on function public.fn_cierre_cuadre(text) is 'c9: asientos, líneas, debe, haber y si cuadra el período (fn_estado, c2).';


-- ---------------------------------------------------------------------
-- 5. LA REVISIÓN: fn_cierre_revisar(periodo). La lista de la cabecera, en
--    orden, una fila por control. Cada fila: orden, control (corto, con su
--    prefijo), nivel (detiene | aviso), ok, detalle en llano con números,
--    que_hacer y ir_a (la página de la app). Lo de las otras capas se pide
--    a sus propios controles (fn_verificar_cadena, fn_banco_control,
--    fn_estados_control, fn_puentes_verificar, v_stripe_control,
--    v_contador_control) y entra con el nivel que le toca: en verde, un
--    renglón resumen por capa; en rojo, un renglón por control. Al terminar
--    guarda la revisión (cierre_revisiones) si el período sigue abierto.
--    SECURITY INVOKER: lee con la policy del dueño; la pantalla la llama
--    con POST (escribe). Un período que no existe: MX002.
-- ---------------------------------------------------------------------
create or replace function public.fn_cierre_fila(p_orden int, p_control text, p_nivel text, p_ok boolean, p_detalle text,
                                                 p_que_hacer text, p_ir_a text) returns jsonb
language sql immutable
set search_path = public, pg_temp
as $$
  select jsonb_build_object('orden', p_orden, 'control', p_control, 'nivel', p_nivel, 'ok', p_ok,
                            'detalle', left(p_detalle, 1500), 'que_hacer', p_que_hacer, 'ir_a', p_ir_a)
$$;
revoke execute on function public.fn_cierre_fila(int, text, text, boolean, text, text, text) from public, anon, service_role;
grant  execute on function public.fn_cierre_fila(int, text, text, boolean, text, text, text) to authenticated;
comment on function public.fn_cierre_fila(int, text, text, boolean, text, text, text) is 'c9: una fila de la revisión, como jsonb.';

create or replace function public.fn_cierre_revisar(p_periodo text)
returns table (orden int, control text, nivel text, ok boolean, detalle text, que_hacer text, ir_a text)
language plpgsql
set search_path = public, pg_temp
as $$
declare
  p          periodos;
  v_t0       timestamptz := clock_timestamp();
  v_hoy      date := fn_fecha_miami(now());
  v_rows     jsonb := '[]'::jsonb;
  v_nom      text;
  v_mes      boolean;
  v_ap       boolean;
  v_anio     boolean;
  v_hay_c8   boolean := to_regclass('public.contador_propuestas') is not null;
  v_hay_c8c  boolean := to_regclass('public.v_contador_control') is not null;
  v_hay_p1   boolean := to_regclass('public.v_stripe_control') is not null;
  v_txt      text;
  v_txt2     text;
  v_n        bigint;
  v_n2       bigint;
  v_n3       bigint;
  v_s        numeric;
  v_s2       numeric;
  v_s3       numeric;
  v_ok       boolean;
  v_j        jsonb;
  v_i        int;
  v_malos    text[];
  v_caja     text;
  v_cxp      text;
  v_sub      text;
  v_nactivos int;
  v_esp      numeric;
  v_det      int;
  v_avi      int;
  r          record;
begin
  perform fn_cierre_exigir_dueno();
  p := fn_cierre_periodo(p_periodo);
  v_nom  := fn_cierre_nombre(p.periodo);
  v_mes  := p.tipo = 'mes';
  v_ap   := p.tipo = 'apertura';
  v_anio := p.tipo = 'anio';

  -- 5. Ya cerrado (informativo; lo demás se revisa igual: la ronda compara).
  if p.estado = 'cerrado' then
    v_rows := v_rows || fn_cierre_fila(5, 'cerrado: este período ya está cerrado', 'aviso', true,
      format('%s se cerró el %s (hora de Miami)%s; nadie escribe ahí (c2). Lo que faltó entra en el mes abierto como ajuste del CPA.',
             initcap(left(v_nom, 1)) || substr(v_nom, 2), to_char(p.cerrado_el at time zone 'America/New_York', 'DD/MM/YYYY HH24:MI'),
             coalesce(' por ' || (select pf.nombre from perfiles pf where pf.id = p.cerrado_por), '')),
      null, 'cierre');
  end if;

  -- 10. El orden: la apertura primero, y todo lo anterior cerrado.
  if v_ap then
    v_rows := v_rows || fn_cierre_fila(10, 'orden: los períodos anteriores cerrados', 'detiene', true,
      'La apertura es el primer período del libro: no hay nada antes que cerrar.', null, 'cierre');
  elsif v_mes then
    select string_agg(fn_cierre_nombre(q.periodo), ', ' order by q.desde), count(*) into v_txt, v_n
      from periodos q where q.tipo in ('mes', 'apertura') and q.estado = 'abierto' and q.desde < p.desde;
    v_rows := v_rows || fn_cierre_fila(10, 'orden: los períodos anteriores cerrados', 'detiene', v_n = 0,
      case when v_n = 0 then 'Todo lo anterior a ' || v_nom || ' está cerrado.'
           else format('Antes de cerrar %s hay que cerrar %s: todo se cierra en orden, la apertura primero (c2).', v_nom, v_txt) end,
      case when v_n > 0 then format('Cierra primero %s, desde esta misma pantalla.', split_part(v_txt, ', ', 1)) end, 'cierre');
  else
    select string_agg(fn_cierre_nombre(q.periodo), ', ' order by q.desde), count(*) into v_txt, v_n
      from periodos q where (q.tipo <> 'anio' and q.anio = p.anio and q.estado = 'abierto')
                         or (q.tipo = 'anio' and q.anio < p.anio and q.estado = 'abierto');
    v_rows := v_rows || fn_cierre_fila(10, 'orden: todos los meses del año (y los años anteriores) cerrados', 'detiene', v_n = 0,
      case when v_n = 0 then format('Todos los períodos de %s y los años anteriores están cerrados.', p.anio)
           else format('Para cerrar %s faltan por cerrar: %s.', v_nom, v_txt) end,
      case when v_n > 0 then 'El año se cierra cuando el CPA termina sus ajustes y todos sus meses están cerrados (c2).' end, 'cierre');
  end if;

  -- 15. El calendario: ya terminó, en hora de Miami.
  v_rows := v_rows || fn_cierre_fila(15, 'calendario: el período ya terminó', 'detiene', p.hasta < v_hoy,
    case when p.hasta < v_hoy then format('%s terminó el %s; hoy es %s en Miami.', initcap(left(v_nom, 1)) || substr(v_nom, 2), p.hasta, v_hoy)
         else format('%s termina el %s: se cierra a partir del %s (hora de Miami); hoy es %s. Un cierre no se deshace.',
                     initcap(left(v_nom, 1)) || substr(v_nom, 2), p.hasta, p.hasta + 1, v_hoy) end,
    case when p.hasta >= v_hoy then 'Espera a que termine el período: c2 no deja cerrarlo antes.' end, 'cierre');

  -- 20. La apertura, con su asiento vivo.
  if v_ap then
    select a.numero into v_txt
      from asientos a
     where a.periodo = p.periodo and a.tipo = 'apertura' and a.reversa_a is null
       and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')
     order by a.cadena_pos desc limit 1;
    v_rows := v_rows || fn_cierre_fila(20, 'apertura: su asiento de apertura está vivo', 'detiene', v_txt is not null,
      case when v_txt is not null then format('El asiento de apertura %s está vivo (la balanza de QuickBooks al %s).', v_txt, p.desde)
           else format('Falta el asiento de apertura del %s (o se reversó): cerrada vacía, la balanza de QuickBooks ya no tendría dónde entrar (c2).', p.desde) end,
      case when v_txt is null then 'Carga la balanza de QuickBooks al 30-sep (fn_apertura_balanza_cargar), mapea sus cuentas y postéala (fn_apertura, c4); después audítala.' end,
      'estados');
  end if;

  -- 30. El cuadre del período (fn_estado, c2).
  v_j := fn_cierre_cuadre(p.periodo);
  v_ok := coalesce((v_j->>'cuadra')::boolean, true);
  v_rows := v_rows || fn_cierre_fila(30, 'cuadre: debe = haber en el período', 'detiene', v_ok,
    case when (v_j->>'asientos')::int = 0 then format('Sin asientos en %s.', v_nom)
         when v_ok then format('%s asientos y %s líneas en %s: debe %s = haber %s.', v_j->>'asientos', v_j->>'lineas', v_nom,
                               fn_cierre_usd((v_j->>'debe')::numeric), fn_cierre_usd((v_j->>'haber')::numeric))
         else format('Descuadre en %s: debe %s, haber %s. Esto no debería poder pasar (c2 no deja entrar un asiento descuadrado).', v_nom,
                     fn_cierre_usd((v_j->>'debe')::numeric), fn_cierre_usd((v_j->>'haber')::numeric)) end,
    case when not v_ok then 'No corrijas nada a mano: mira fn_verificar_cadena (control cuadre) y OPERACION.md, y avisa.' end, 'conexiones');

  -- 50 (la apertura, aviso). Cada cuenta del banco con saldo en el asiento
  -- de apertura, con su conciliación de apertura confirmada (lo que
  -- QuickBooks tenía en tránsito al 30-sep). No frena la apertura (sus
  -- diferencias las explica la auditoría de c4), pero sin ella c6 no deja
  -- confirmar la conciliación del primer mes: se avisa aquí, antes.
  if v_ap then
    v_caja := coalesce((select m.cuenta from mapeo_metodo_pago m where m.forma = 'efectivo' and m.cuenta is not null
                         order by m.confirmado_el desc nulls last limit 1), '1050');
    select count(*),
           string_agg(format('%s (%s)', cu.nombre, cu.codigo), '; ' order by cu.codigo)
             filter (where not exists (select 1 from conciliaciones x where x.cuenta = cu.codigo and x.tipo = 'apertura' and x.estado = 'confirmada')),
           count(*) filter (where not exists (select 1 from conciliaciones x where x.cuenta = cu.codigo and x.tipo = 'apertura' and x.estado = 'confirmada'))
      into v_n, v_txt, v_n2
      from cuentas cu
     where cu.imputable and cu.codigo <> v_caja
       and left(cu.codigo, 2) = '10' and cu.tipo = 'activo' and cu.saldo_normal = 'debe' and cu.regla_obra = 'prohibida'
       and exists (select 1 from asientos a join asiento_lineas l on l.asiento_id = a.id
                    where a.periodo = p.periodo and a.tipo = 'apertura' and l.cuenta = cu.codigo
                      and a.camino not in ('reverso', 'reverso_automatico')
                      and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso'));
    v_rows := v_rows || fn_cierre_fila(50, 'banco: la conciliación de apertura de cada cuenta', 'aviso', v_n2 = 0,
      case when v_n = 0 then 'Ninguna cuenta del banco tiene saldo en el asiento de apertura: no hay conciliación de apertura que hacer.'
           when v_n2 = 0 then format('Las %s cuenta(s) del banco con saldo en la apertura tienen su conciliación de apertura confirmada.', v_n)
           else format('%s de %s cuenta(s) del banco sin conciliación de apertura confirmada: %s. No frena la apertura, pero sin ella la conciliación de %s de esa cuenta no se confirma (c6).',
                       v_n2, v_n, v_txt, coalesce(fn_cierre_nombre(to_char(p.hasta + 1, 'YYYY-MM')), 'el primer mes')) end,
      case when v_n2 > 0 then 'Conciliar: la conciliación de apertura de cada cuenta (el saldo del statement al 30-sep y lo que QuickBooks tenía en tránsito: cheques sin cobrar, depósitos sin acreditar) y «Confirmar».' end,
      'conciliar');
  end if;

  if v_mes then
    -- 40. El banco: todo casado o clasificado.
    select count(*), coalesce(sum(m.monto) filter (where m.monto < 0), 0), coalesce(sum(m.monto) filter (where m.monto > 0), 0),
           count(*) filter (where m.posible_duplicado_de is not null and m.duplicado is null)
      into v_n, v_s, v_s2, v_n2
      from movimientos_banco m where m.periodo = p.periodo and m.estado = 'pendiente';
    v_n3 := 0;
    if v_hay_c8 then
      execute 'select count(*) from public.contador_propuestas cp join public.movimientos_banco m on m.id = cp.movimiento_id '
              'where m.periodo = $1 and cp.estado = ''pendiente''' into v_n3 using p.periodo;
    end if;
    v_rows := v_rows || fn_cierre_fila(40, 'banco: todo lo del mes casado o clasificado', 'detiene', v_n = 0,
      case when v_n = 0 then format('Todos los movimientos del banco de %s están casados o clasificados.', v_nom)
           else format('%s movimiento(s) del banco de %s sin clasificar ni casar: cargos por %s y depósitos por %s%s%s. Lo que no se clasifique no está en los libros de este mes.',
                       v_n, v_nom, fn_cierre_usd(-v_s), fn_cierre_usd(v_s2),
                       case when v_n2 > 0 then format('; %s posible(s) duplicado(s) sin decidir', v_n2) else '' end,
                       case when v_n3 > 0 then format('; %s de ellos tienen propuesta de la IA esperando tu toque', v_n3) else '' end) end,
      case when v_n > 0 then 'Abre la Bandeja y resuelve cada uno: «Así es» a la propuesta de la IA, «Según yo», «Casar» con su ticket, o ignóralo con su motivo.' end,
      'bandeja');

    -- 42. Las propuestas de la IA del mes sin decidir.
    v_rows := v_rows || fn_cierre_fila(42, 'ia: propuestas del mes sin decidir', 'aviso', coalesce(v_n3, 0) = 0,
      case when not v_hay_c8 then 'El contador (c8) no está en esta base: no hay propuestas de la IA que mirar.'
           when v_n3 = 0 then format('Ninguna propuesta de la IA de %s espera decisión.', v_nom)
           else format('%s propuesta(s) de la IA sobre cargos de %s esperan tu decisión.', v_n3, v_nom) end,
      case when coalesce(v_n3, 0) > 0 then 'Bandeja: «Así es» (entra al libro) o «No es eso».' end, 'bandeja');

    -- 50. Cada cuenta con estado de cuenta, conciliada y confirmada al
    --     último día del mes.
    v_caja := coalesce((select m.cuenta from mapeo_metodo_pago m where m.forma = 'efectivo' and m.cuenta is not null
                         order by m.confirmado_el desc nulls last limit 1), '1050');
    v_malos := '{}'; v_n := 0;
    for r in
      select cu.codigo, cu.nombre,
             (select max(x.fecha_corte) from conciliaciones x
               where x.cuenta = cu.codigo and x.estado = 'confirmada' and x.tipo = 'normal' and x.fecha_corte >= p.hasta) as confirmada_al,
             (select max(x.fecha_corte) from conciliaciones x where x.cuenta = cu.codigo and x.estado = 'confirmada') as ultima_conf,
             (select x.fecha_corte from conciliaciones x
               where x.cuenta = cu.codigo and x.estado = 'abierta' and x.tipo = 'normal' and x.fecha_corte >= p.hasta
               order by x.fecha_corte limit 1) as abierta_al,
             (select x.falta from conciliaciones x
               where x.cuenta = cu.codigo and x.estado = 'abierta' and x.tipo = 'normal' and x.fecha_corte >= p.hasta
               order by x.fecha_corte limit 1) as abierta_falta
        from (select c.codigo, c.nombre
                from cuentas c
               where c.imputable and c.codigo <> v_caja
                 and ((left(c.codigo, 2) = '10' and c.tipo = 'activo' and c.saldo_normal = 'debe' and c.regla_obra = 'prohibida')
                      or (c.tipo = 'pasivo' and exists (select 1 from tarjetas t where t.cuenta = c.codigo)))
                 and exists (select 1 from movimientos_banco m where m.cuenta = c.codigo and m.fecha <= p.hasta)) cu
       order by cu.codigo
    loop
      v_n := v_n + 1;
      if r.confirmada_al is null then
        v_malos := v_malos || format('%s (%s): %s', r.nombre, r.codigo,
          case when r.abierta_al is not null
               then format('hay una conciliación al %s abierta, sin confirmar (%s)', r.abierta_al, coalesce(r.abierta_falta, 'falta cuadrarla'))
               else format('sin conciliación confirmada al %s (la última confirmada: %s)', p.hasta, coalesce(r.ultima_conf::text, 'ninguna')) end);
      end if;
    end loop;
    v_rows := v_rows || fn_cierre_fila(50, 'banco: cada cuenta conciliada al último día del mes', 'detiene', cardinality(v_malos) = 0,
      case when v_n = 0 then format('Ninguna cuenta con estado de cuenta tiene movimientos del banco hasta el %s: nada que conciliar.', p.hasta)
           when cardinality(v_malos) = 0 then format('Las %s cuenta(s) con estado de cuenta tienen su conciliación confirmada al %s (o después).', v_n, p.hasta)
           else format('%s de %s cuenta(s) sin conciliar al %s: %s.', cardinality(v_malos), v_n, p.hasta, array_to_string(v_malos, '; ')) end,
      case when cardinality(v_malos) > 0
           then 'Conciliar: cada cuenta al último día del mes (fn_conciliar) y «Confirmar». Una tarjeta que corta su statement antes se concilia igual al último día, con su actividad reciente importada hasta ese día (QFX o Plaid).' end,
      'conciliar');

    -- 52. Partidas en tránsito de más de 30 días (en la conciliación del fin de mes).
    select count(*), coalesce(sum(abs(pa.monto)), 0),
           string_agg(format('%s %s «%s» (%s días)', pa.fecha, fn_cierre_usd(pa.monto), left(coalesce(pa.descripcion, ''), 40), pa.dias),
                      '; ' order by pa.fecha)
      into v_n, v_s, v_txt
      from conciliacion_partidas pa
      join conciliaciones c on c.id = pa.conciliacion_id
     where c.tipo = 'normal' and c.fecha_corte between p.hasta and p.hasta + 40
       and pa.lado = 'libro' and pa.alarma and pa.resuelta_en is null
       and c.cuenta in (select m.cuenta from movimientos_banco m where m.fecha <= p.hasta);
    v_rows := v_rows || fn_cierre_fila(52, 'banco: partidas en tránsito de más de 30 días', 'aviso', v_n = 0,
      case when v_n = 0 then 'Ninguna partida en tránsito con más de 30 días en las conciliaciones del fin de mes.'
           else format('%s partida(s) en libros que el banco no trae, con más de 30 días, por %s: %s.', v_n, fn_cierre_usd(v_s), v_txt) end,
      case when v_n > 0 then 'Cada una con su motivo (fn_conciliacion_partida): un cheque que no cobran, un depósito que no llegó; si fue un error, corrígelo con un asiento.' end,
      'conciliar');

    -- 60. 2010 por proveedor (el auxiliar y su antigüedad; el statement del supply se compara a mano).
    v_cxp := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'cxp'), '2010');
    select coalesce(-sum(l.monto), 0) into v_s
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where l.cuenta = v_cxp and a.fecha_contable <= p.hasta;
    -- (sin proveedor: sin tercero y sin partida; un trabajo externo lleva su
    -- partida y se nombra por su descripción, como cxp_abierta de c3)
    select coalesce(-sum(l.monto), 0), count(*) into v_s2, v_n2
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where l.cuenta = v_cxp and a.fecha_contable <= p.hasta and l.tercero_tipo is null and l.partida_tabla is null;
    select string_agg(format('%s %s', x.nombre, fn_cierre_usd(x.s)), ', ' order by x.s desc) into v_txt
      from (select coalesce(pr.nombre, te.descripcion, l.tercero_id, l.partida_tabla || ' ' || l.partida_id) as nombre, -sum(l.monto) as s
              from asiento_lineas l
              join asientos a on a.id = l.asiento_id
              left join proveedores pr on l.tercero_tipo = 'proveedor' and pr.id = (case when l.tercero_tipo = 'proveedor' then l.tercero_id::uuid end)
              left join trabajos_externos te on l.partida_tabla = 'trabajos_externos'
                                            and te.id = (case when l.partida_tabla = 'trabajos_externos' then l.partida_id::bigint end)
             where l.cuenta = v_cxp and a.fecha_contable <= p.hasta and (l.tercero_tipo is not null or l.partida_tabla is not null)
             group by 1 having sum(l.monto) <> 0 order by 2 desc limit 5) x;
    select count(*), coalesce(sum(-x.s), 0) into v_n3, v_s3
      from (select l.partida_tabla, l.partida_id, sum(l.monto) as s, min(a.fecha_contable) as desde
              from asiento_lineas l join asientos a on a.id = l.asiento_id
             where l.cuenta = v_cxp and a.fecha_contable <= p.hasta and l.partida_tabla is not null
             group by l.partida_tabla, l.partida_id having sum(l.monto) <> 0) x
     where x.desde < p.hasta - 60;
    v_rows := v_rows || fn_cierre_fila(60, '2010: lo que se le debe a cada proveedor', 'aviso', v_n2 = 0,
      format('%s al %s: %s. Por proveedor: %s. %s partida(s) con más de 60 días por %s.%s', v_cxp, p.hasta, fn_cierre_usd(v_s),
             coalesce(v_txt, 'nada abierto'), v_n3, fn_cierre_usd(v_s3),
             case when v_n2 > 0 then format(' %s línea(s) de %s sin proveedor ni partida por %s: no se pueden comparar con ningún statement.', v_n2, v_cxp, fn_cierre_usd(v_s2)) else '' end),
      'Compara el saldo de cada proveedor con el statement del supply (como en QuickBooks, a mano); lo que no cuadre se corrige con el recibo o el pago que falta. Una línea sin proveedor se corrige con fn_reversar y un asiento con su tercero.',
      'estados');

    -- 70. Las obras: cada línea de costo e ingreso con su obra.
    select count(*), coalesce(sum(abs(l.monto)), 0), string_agg(distinct a.numero, ', ') into v_n, v_s, v_txt
      from asiento_lineas l join asientos a on a.id = l.asiento_id join cuentas c on c.codigo = l.cuenta
     where a.periodo = p.periodo and c.regla_obra = 'obligatoria' and l.proyecto_id is null;
    select count(distinct l.proyecto_id), coalesce(sum(abs(l.monto)), 0) into v_n2, v_s2
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where a.periodo = p.periodo and l.proyecto_id is not null;
    v_rows := v_rows || fn_cierre_fila(70, 'obras: el auxiliar por obra suma lo mismo que el mayor', 'detiene', v_n = 0,
      case when v_n = 0 then format('Todas las líneas de cuentas que exigen obra llevan su obra en %s: %s obra(s), %s en líneas con obra.', v_nom, v_n2, fn_cierre_usd(v_s2))
           else format('%s línea(s) de cuentas que exigen obra sin obra en %s, por %s (asientos %s): el auxiliar por obra no suma lo del mayor.', v_n, v_nom, fn_cierre_usd(v_s), left(v_txt, 200)) end,
      case when v_n > 0 then 'Reversa esos asientos (fn_reversar) y vuelve a postearlos con su obra; c2 no deja entrar una línea así (fueron un insert directo).' end,
      'movimientos');

    -- 80. Los tickets del mes sin foto (anotados a mano).
    select count(*), coalesce(sum(coalesce(r0.total, 0)), 0), string_agg(r0.id::text, ', ' order by r0.id) into v_n, v_s, v_txt
      from recibos r0
      join puente_documentos pd on pd.tabla = 'recibos' and pd.documento_id = r0.id::text and pd.estado = 'contabilizado'
      join asientos a on a.id = pd.asiento_id
     where a.periodo = p.periodo and nullif(btrim(r0.ruta), '') is null;
    v_rows := v_rows || fn_cierre_fila(80, 'recibos: los tickets del mes sin foto', 'aviso', v_n = 0,
      case when v_n = 0 then format('Todos los tickets contabilizados en %s tienen su foto.', v_nom)
           else format('%s ticket(s) de %s entraron sin foto (anotados a mano), por %s: recibos %s. Su respaldo es el statement de la tarjeta o del banco (c3).', v_n, v_nom, fn_cierre_usd(v_s), left(v_txt, 300)) end,
      case when v_n > 0 then 'Si tienes la foto, pónsela en Recibos (📷); si no, el statement del banco es su respaldo.' end, null);

    -- 82. Los tickets del mes con impuesto desconocido.
    select count(*), coalesce(sum(coalesce(r0.total, 0)), 0) into v_n, v_s
      from recibos r0
      join puente_documentos pd on pd.tabla = 'recibos' and pd.documento_id = r0.id::text and pd.estado = 'contabilizado'
      join asientos a on a.id = pd.asiento_id
     where a.periodo = p.periodo and r0.tax is null and r0.subtotal is null;
    v_rows := v_rows || fn_cierre_fila(82, 'recibos: los tickets del mes con impuesto desconocido', 'aviso', v_n = 0,
      case when v_n = 0 then format('Todos los tickets contabilizados en %s dicen su impuesto (o que no llevaban).', v_nom)
           else format('%s ticket(s) de %s por %s entraron sin saber su impuesto (la lectura no trajo subtotal ni tax): entraron por su total, que es lo que se pagó; para el DR-15 no se sabe si llevaban impuesto.', v_n, v_nom, fn_cierre_usd(v_s)) end,
      case when v_n > 0 then 'Ábrelos en Recibos (✎) y completa subtotal e impuesto, o déjalos: el costo está bien.' end, null);
  end if;

  -- 90. 1590 = la depreciación acumulada de los activos (al último día).
  if not v_anio then
    select coalesce(-sum(l.monto), 0) into v_s
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where l.cuenta = '1590' and a.fecha_contable <= p.hasta;
    select count(*) into v_nactivos from activos_fijos;
    select coalesce(sum(case when af.fecha_servicio <= p.hasta then af.dep_acumulada_inicial else 0 end
                        + coalesce((select sum(ad.monto) from activos_depreciaciones ad
                                      join periodos pd on pd.periodo = ad.periodo
                                      join asientos a on a.id = ad.asiento_id
                                     where ad.activo_id = af.id and pd.hasta <= p.hasta
                                       and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')), 0)), 0)
      into v_esp
      from activos_fijos af
     where af.estado = 'activo' or af.baja_asiento_id is null;
    v_rows := v_rows || fn_cierre_fila(90, 'activos: 1590 = la depreciación acumulada de los activos', 'detiene',
      v_nactivos = 0 or v_s = v_esp,
      case when v_nactivos = 0
           then format('No hay activos fijos dados de alta todavía (se cargan en f12 con la cédula del CPA); 1590 tiene %s al %s, lo que trajo QuickBooks. Se comprueba cuando estén.', fn_cierre_usd(v_s), p.hasta)
           when v_s = v_esp then format('1590 al %s: %s en el libro = %s según los %s activo(s) dados de alta.', p.hasta, fn_cierre_usd(v_s), fn_cierre_usd(v_esp), v_nactivos)
           else format('1590 al %s no cuadra: %s en el libro y %s según los %s activo(s) dados de alta (diferencia %s).', p.hasta, fn_cierre_usd(v_s), fn_cierre_usd(v_esp), v_nactivos, fn_cierre_usd(v_s - v_esp)) end,
      case when v_nactivos > 0 and v_s <> v_esp
           then 'Mira qué activo falta o sobra (v_activos_fijos): un alta con su acumulada de arranque, una baja con su asiento, o un asiento de reclasificación a 1590.' end,
      'cierre');
  end if;

  -- 92. La depreciación del mes posteada (si hay activos).
  if v_mes then
    select count(*), coalesce(sum(x.monto), 0) into v_n, v_s from fn_depreciacion_plan(p.periodo) x where x.monto > 0;
    select coalesce(sum(ad.monto), 0), count(distinct ad.asiento_id), string_agg(distinct a.numero, ', ') into v_s2, v_n2, v_txt
      from activos_depreciaciones ad join asientos a on a.id = ad.asiento_id
     where ad.periodo = p.periodo and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso');
    v_rows := v_rows || fn_cierre_fila(92, 'activos: la depreciación del mes posteada', 'detiene',
      (coalesce(v_nactivos, 0) = 0) or (v_n = 0 and v_n2 = 0) or (v_n2 > 0 and v_s2 = v_s),
      case when coalesce(v_nactivos, 0) = 0 then 'No hay activos fijos: nada que depreciar.'
           when v_n = 0 and v_n2 = 0 then format('Ningún activo deprecia en %s.', v_nom)
           when v_n2 > 0 and v_s2 = v_s then format('La depreciación de %s está posteada: %s por %s activo(s) (asiento %s).', v_nom, fn_cierre_usd(v_s2), v_n, v_txt)
           when v_n2 = 0 then format('Falta la depreciación de %s: %s por %s activo(s) (Dr 6950 / Cr 1590).', v_nom, fn_cierre_usd(v_s), v_n)
           else format('La depreciación posteada de %s (%s, asiento %s) no es la que dan los activos de hoy (%s por %s activo(s)).', v_nom, fn_cierre_usd(v_s2), v_txt, fn_cierre_usd(v_s), v_n) end,
      case when coalesce(v_nactivos, 0) > 0 and v_n2 = 0 and v_n > 0 then 'Toca «Postear depreciación» (fn_depreciacion_mes): un asiento con una línea de 6950 por activo y el total a 1590.'
           when coalesce(v_nactivos, 0) > 0 and v_n2 > 0 and v_s2 <> v_s then 'Reversa el asiento de depreciación del mes (fn_reversar, con su motivo) y vuelve a tocar «Postear depreciación».' end,
      'cierre');
  end if;

  -- 100+. El libro: fn_verificar_cadena (c2), un renglón por control en rojo.
  begin
    v_i := 0;
    for r in select c.control, c.detalle from fn_verificar_cadena() c where not c.ok order by c.control loop
      v_i := v_i + 1;
      v_rows := v_rows || fn_cierre_fila(100 + v_i, 'libro: ' || r.control, 'detiene', false, fn_cierre_llano(r.detalle),
        case r.control
          when 'permisos' then 'Cada línea del detalle dice qué lo arregla: volver a pegar c1 o c2, o una función ajena SECURITY DEFINER que lee el libro y la API ejecuta: o se hace SECURITY INVOKER, o se le quita la API (revoke execute on function … from public, anon, authenticated, service_role). Hasta entonces el libro no se cierra.'
          when 'triggers' then 'Vuelve a pegar c1-plan-de-cuentas.sql y c2-libro.sql (tras una restauración o un VACUUM FULL es lo esperado); si no sabes por qué cambió, para y avisa (OPERACION.md).'
          when 'cuentas' then 'Una cuenta cambió sin pasar por su historial: vuelve a pegar c1-plan-de-cuentas.sql y avisa.'
          else 'Alguien tocó el libro por debajo de sus guardas: no corrijas nada a mano; restaura del respaldo de Postgres (OPERACION.md) y avisa.' end,
        'conexiones');
    end loop;
    if v_i = 0 then
      v_rows := v_rows || fn_cierre_fila(100, 'libro: cadena, numeración, guardas y permisos', 'detiene', true,
        'Los 10 controles de fn_verificar_cadena (c2) están en verde.', null, 'conexiones');
    end if;
  exception when others then
    v_rows := v_rows || fn_cierre_fila(100, 'libro: fn_verificar_cadena', 'detiene', false,
      format('No se pudo revisar el libro: %s %s.', sqlstate, sqlerrm), 'Avisa: el control del libro (c2) no responde.', 'conexiones');
  end;

  -- 110+. El banco (c6): los cuadres de fn_banco_control del período.
  begin
    v_i := 0;
    for r in select x.orden as o, x.vista, x.detalle
               from fn_banco_control(p.periodo, array['cuadre: un movimiento, un casado', 'cuadre: depósitos nunca a ingreso',
                                                       'cuadre: archivos intactos', 'cuadre: ningún ticket después de clasificar',
                                                       'cuadre: conciliaciones confirmadas', 'cuadre: préstamos', 'cuadre: prepagados',
                                                       'cuadre: el otro lado de cada casado', 'cuadre: cada cuenta hasta el fin del mes']) x
              where x.ok is distinct from true order by x.orden loop
      v_i := v_i + 1;
      -- (el 58 dice «No frena nada: cerrar el mes no lo mira»: aquí sí frena)
      v_rows := v_rows || fn_cierre_fila(110 + v_i, 'banco: ' || regexp_replace(r.vista, '^cuadre: ', ''), 'detiene', false,
        coalesce(left(regexp_replace(r.detalle, '\s*No frena nada: cerrar el mes no lo mira\.', ''), 700), 'en rojo, sin detalle'),
        case when r.o = 58 then 'Importa lo de esa cuenta hasta el último día del mes (la actividad reciente en QFX, o espera a la sincronización de Plaid) y vuelve a revisar.'
             when r.o in (90, 91) then 'Vuelve a pegar c6-banco.sql (y lo que el detalle diga: c2, c3, c4).'
             when r.o = 54 then 'El detalle dice qué conciliación y por qué: reábrela con su motivo (fn_conciliacion_reabrir) y concíliala otra vez.'
             else 'El detalle dice qué y cómo (c6): lo de un casado se arregla en la Bandeja (des-casar con su motivo).' end,
        case when r.o in (54, 58) then 'conciliar' when r.o in (90, 91) then 'conexiones' else 'bandeja' end);
    end loop;
    if v_i = 0 then
      v_rows := v_rows || fn_cierre_fila(110, 'banco: los cuadres del banco (c6)', 'detiene', true,
        format('Los cuadres de fn_banco_control de %s están en verde (casados, depósitos, archivos, tickets, conciliaciones, préstamos, prepagados, el otro lado de cada casado, cada cuenta hasta el fin del mes, y las protecciones).', v_nom),
        null, 'conciliar');
    end if;
  exception when others then
    v_rows := v_rows || fn_cierre_fila(110, 'banco: fn_banco_control', 'detiene', false,
      format('No se pudo revisar el banco: %s %s.', sqlstate, sqlerrm), 'Avisa: el control del banco (c6) no responde.', 'conciliar');
  end;

  -- 120+. Los estados (c4): la antigüedad de pagar contra el mayor (2010
  --       por proveedor), el auxiliar por obra, la apertura en el libro y
  --       sus protecciones (lo demás de c4 no es del cierre del mes y pesa).
  --       Con tope por reloj de 5 s (el de la API es 3): lo que no llegue
  --       sale en rojo y se vuelve a pedir.
  begin
    perform set_config('c4.control_tope', '5000', true);
    v_i := 0;
    for r in select x.orden as o, x.vista, x.ok as k, x.detalle
               from fn_estados_control(p.periodo, array['v_cxp_antiguedad', 'v_costo_por_obra']) x
              where x.ok is distinct from true order by x.orden loop
      v_i := v_i + 1;
      v_rows := v_rows || fn_cierre_fila(120 + v_i, 'estados: ' || regexp_replace(r.vista, '^cuadre: ', ''),
        case when r.o in (58, 59, 62, 63, 64) then 'aviso' else 'detiene' end, false,
        case when r.k is null then 'Los estados no terminaron a tiempo (' || coalesce(left(r.detalle, 300), 'sin detalle') || ').'
             else coalesce(left(r.detalle, 700), 'en rojo, sin detalle') end,
        case when r.k is null then 'Vuelve a revisar en un momento (c4 tardó más de 5 s).'
             when r.o = 63 then 'c2 deja cerrar con cualquier asiento de apertura vivo, pero los estados (c4) no se publican hasta que la apertura sea la de la balanza de QuickBooks: cárgala (fn_apertura_balanza_cargar) y postéala con fn_apertura; si hay una hecha a mano, revérsala.'
             when r.o = 61 then 'Vuelve a pegar c4-estados.sql.'
             when r.o in (58, 59) then 'La comparación con QuickBooks tiene diferencias sin explicar: anótalas (fn_diferencia_anotar) con su categoría.'
             else 'El detalle dice qué (c4): en Estados, baja de esa cifra al asiento.' end,
        'estados');
    end loop;
    if v_i = 0 then
      v_rows := v_rows || fn_cierre_fila(120, 'estados: la balanza, las antigüedades y el auxiliar por obra (c4)', 'detiene', true,
        format('Los cuadres de fn_estados_control de %s están en verde (antigüedad de pagar = mayor, auxiliar por obra = mayor, apertura en el libro, protecciones).', v_nom),
        null, 'estados');
    end if;
  exception when others then
    v_rows := v_rows || fn_cierre_fila(120, 'estados: fn_estados_control', 'detiene', false,
      format('No se pudo revisar los estados: %s %s.', sqlstate, sqlerrm), 'Avisa: el control de los estados (c4) no responde.', 'estados');
  end;

  -- 130+. Los puentes (c3): fn_puentes_verificar.
  begin
    v_i := 0;
    for r in select c.control, c.detalle from fn_puentes_verificar() c where not c.ok order by c.control loop
      v_i := v_i + 1;
      v_rows := v_rows || fn_cierre_fila(130 + v_i, 'puentes: ' || r.control, 'detiene', false, fn_cierre_llano(r.detalle),
        case r.control
          when 'sin_evaluar' then 'Corre los puentes (select fn_puentes_correr(); o «Reintentar puente» en la app) y vuelve a revisar.'
          when 'bandeja' then 'Un papel que el libro rechazó: la bandeja de los puentes dice cuál y por qué.'
          when 'triggers' then 'Vuelve a pegar c3-puentes.sql.'
          else 'El detalle dice qué (c3).' end,
        'movimientos');
    end loop;
    if v_i = 0 then
      v_rows := v_rows || fn_cierre_fila(130, 'puentes: los controles de los puentes (c3)', 'detiene', true,
        'Los 13 controles de fn_puentes_verificar están en verde.', null, 'movimientos');
    end if;
  exception when others then
    v_rows := v_rows || fn_cierre_fila(130, 'puentes: fn_puentes_verificar', 'detiene', false,
      format('No se pudo revisar los puentes: %s %s.', sqlstate, sqlerrm), 'Avisa: el control de los puentes (c3) no responde.', 'movimientos');
  end;

  -- 140+. Los cobros en línea (p1), si están: v_stripe_control.
  if v_hay_p1 then
    begin
      v_i := 0;
      for r in execute 'select x.orden as o, x.control, x.nivel as n, x.detalle from public.v_stripe_control x where x.ok is distinct from true order by x.orden' loop
        v_i := v_i + 1;
        v_rows := v_rows || fn_cierre_fila(140 + v_i, 'cobros en línea: ' || regexp_replace(r.control, '^(stripe|vista): ', ''),
          case when r.n = 'alarma' then 'aviso' else 'detiene' end,
          false, coalesce(left(r.detalle, 700), 'en rojo, sin detalle'), 'El detalle dice qué (p1): Cobros en línea.', 'cobros');
      end loop;
      if v_i = 0 then
        v_rows := v_rows || fn_cierre_fila(140, 'cobros en línea: los cuadres de Stripe (p1)', 'detiene', true,
          'Los cuadres y las alarmas de v_stripe_control están en verde.', null, 'cobros');
      end if;
    exception when others then
      v_rows := v_rows || fn_cierre_fila(140, 'cobros en línea: v_stripe_control', 'detiene', false,
        format('No se pudo revisar Stripe: %s %s.', sqlstate, sqlerrm), 'Avisa: el control de Stripe (p1) no responde.', 'cobros');
    end;
  end if;

  -- 145+. La IA (c8), si está: v_contador_control.
  if v_hay_c8c then
    begin
      v_i := 0;
      for r in execute 'select x.orden as o, x.control, x.nivel as n, x.detalle from public.v_contador_control x where x.ok is distinct from true order by x.orden' loop
        v_i := v_i + 1;
        v_rows := v_rows || fn_cierre_fila(145 + v_i, 'ia: ' || regexp_replace(r.control, '^(ia|vista): ', ''),
          case when r.n = 'alarma' then 'aviso' else 'detiene' end,
          false, coalesce(left(r.detalle, 700), 'en rojo, sin detalle'), 'El detalle dice qué (c8): la Bandeja y Conexiones → IA contable.', 'bandeja');
      end loop;
      if v_i = 0 then
        v_rows := v_rows || fn_cierre_fila(145, 'ia: los cuadres del contador (c8)', 'detiene', true,
          'Los cuadres y las alarmas de v_contador_control están en verde.', null, 'bandeja');
      end if;
    exception when others then
      v_rows := v_rows || fn_cierre_fila(145, 'ia: v_contador_control', 'detiene', false,
        format('No se pudo revisar el contador: %s %s.', sqlstate, sqlerrm), 'Avisa: el control del contador (c8) no responde.', 'bandeja');
    end;
  end if;

  -- 170 y 171. La mano de obra repartida y el costo por obra (c10), si
  -- están: sus cuadres (v_jornal_control y v_margen_control: uno en rojo
  -- detiene) y sus avisos (horas que llegaron tarde a una semana ya
  -- repartida, un pago de mano de obra resuelto fuera del reparto, una
  -- propuesta de la IA que quedó abierta en un pago repartido, un patrón o
  -- una cuenta que ya no sirve: avisan). Dos filas fijas, con el detalle de
  -- lo que esté en rojo, en un rango que nadie más usa.
  if to_regclass('public.v_jornal_control') is not null and to_regclass('public.v_margen_control') is not null then
    begin
      for r in execute 'select q.n, count(*) filter (where not q.ok) as rojos, count(*) as filas, '
                    || 'left(string_agg(q.detalle, '' · '' order by q.o) filter (where not q.ok), 1200) as detalle '
                    || 'from (select x.orden as o, x.nivel as n, x.ok is true as ok, x.detalle from public.v_jornal_control x '
                    || 'union all select 100 + y.orden, y.nivel, y.ok is true, y.detalle from public.v_margen_control y) q '
                    || 'group by q.n order by q.n desc' loop
        v_rows := v_rows || fn_cierre_fila(case when r.n = 'aviso' then 171 else 170 end,
          case when r.n = 'aviso' then 'mano de obra y costo por obra: sus avisos (c10)'
               else 'mano de obra y costo por obra: sus cuadres (c10)' end,
          case when r.n = 'aviso' then 'aviso' else 'detiene' end, r.rojos = 0,
          case when r.rojos = 0 then format('Los %s, en verde.', r.filas) else coalesce(r.detalle, 'en rojo, sin detalle') end,
          case when r.rojos = 0 then null
               else 'El detalle dice qué (c10): Contabilidad → Bandeja (la mano de obra y sus repartos) y Costo por obra.' end,
          'bandeja');
      end loop;
    exception when others then
      v_rows := v_rows || fn_cierre_fila(170, 'mano de obra y costo por obra: v_jornal_control', 'detiene', false,
        format('No se pudo revisar la mano de obra repartida: %s %s.', sqlstate, sqlerrm),
        'Avisa: el control de la mano de obra (c10) no responde.', 'bandeja');
    end;
  end if;

  -- 150. Cambios del período (informativo): reversos y asientos de la IA.
  select count(*) filter (where a.camino in ('reverso', 'reverso_automatico')),
         coalesce(sum(d.deb) filter (where a.camino in ('reverso', 'reverso_automatico')), 0),
         count(*) filter (where a.camino = 'ia'), coalesce(sum(d.deb) filter (where a.camino = 'ia'), 0),
         count(*) filter (where a.camino = 'mano'), count(*) filter (where a.camino = 'puente')
    into v_n, v_s, v_n2, v_s2, v_n3, v_i
    from asientos a
    cross join lateral (select coalesce(sum(l.monto) filter (where l.monto > 0), 0) as deb from asiento_lineas l where l.asiento_id = a.id) d
   where (v_anio and a.anio = p.anio) or (not v_anio and a.periodo = p.periodo);
  v_rows := v_rows || fn_cierre_fila(150, 'cambios: reversos y asientos de la IA del período', 'aviso', true,
    format('En %s: %s reverso(s) por %s; %s asiento(s) de la IA aprobados por Edgar por %s; %s a mano; %s de los puentes.',
           v_nom, v_n, fn_cierre_usd(v_s), v_n2, fn_cierre_usd(v_s2), v_n3, v_i),
    null, 'movimientos');

  -- 160. Los subs pagados en el mes, con su COI vigente (f12a trae los datos).
  if v_mes then
    v_sub := coalesce((select pc.cuenta from puente_cuentas pc where pc.rol = 'subcontratos'), '5200');
    if exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'proveedores' and column_name = 'coi_vence') then
      execute format($q$
        select count(*), string_agg(format('%%s (%%s)', pr.nombre, case when pr.coi_vence is null then 'sin COI' else 'COI vencido el ' || pr.coi_vence end), '; ')
          from (select distinct l.tercero_id
                  from public.asiento_lineas l join public.asientos a on a.id = l.asiento_id
                 where a.periodo = $1 and l.cuenta = $2 and l.tercero_tipo = 'proveedor') x
          join public.proveedores pr on pr.id = x.tercero_id::uuid
         where pr.coi_vence is null or pr.coi_vence < $3 $q$) into v_n, v_txt using p.periodo, v_sub, p.hasta;
      v_rows := v_rows || fn_cierre_fila(160, 'subs: COI vigente de cada sub pagado en el mes', 'aviso', v_n = 0,
        case when v_n = 0 then format('Todos los subs con costo en %s en %s tienen su COI vigente.', v_sub, v_nom)
             else format('%s sub(s) con costo en %s en %s sin COI vigente: %s.', v_n, v_sub, v_nom, v_txt) end,
        case when v_n > 0 then 'Pide el certificado de seguro (COI) al sub y guárdalo en su ficha (f12a).' end, null);
    else
      v_rows := v_rows || fn_cierre_fila(160, 'subs: COI vigente de cada sub pagado en el mes', 'aviso', true,
        'Todavía no hay datos de COI en proveedores (llegan con f12a: W-9, COI y 1099): no se puede comprobar, y no frena.',
        'Pide el certificado de seguro (COI) a cada sub antes de pagarle (f12a).', null);
    end if;
  end if;

  -- Se guarda la revisión del período abierto (la última), para v_cierre_estado.
  -- (Del período que no terminó no se cuentan el calendario, la conciliación
  -- al último día ni la depreciación del mes: solo se cumplen al terminar,
  -- como en la ronda.)
  select count(*) filter (where (x->>'nivel') = 'detiene' and (x->>'ok')::boolean is distinct from true
                            and not (p.hasta >= v_hoy and (x->>'orden')::int in (15, 50, 92))),
         count(*) filter (where (x->>'nivel') = 'aviso' and (x->>'ok')::boolean is distinct from true)
    into v_det, v_avi
    from jsonb_array_elements(v_rows) x;
  if p.estado = 'abierto' then
    begin
      perform set_config('mx_cierre.escribe', 'cierre_revisiones', true);
      insert into cierre_revisiones (periodo, revisado_el, revisado_por, revision, detienen, avisos, ms)
      values (p.periodo, clock_timestamp(), auth.uid(), v_rows, v_det, v_avi,
              (extract(epoch from clock_timestamp() - v_t0) * 1000)::int)
      on conflict (periodo) do update
         set revisado_el = excluded.revisado_el, revisado_por = excluded.revisado_por, revision = excluded.revision,
             detienen = excluded.detienen, avisos = excluded.avisos, ms = excluded.ms;
      perform set_config('mx_cierre.escribe', '', true);
    exception when others then
      perform set_config('mx_cierre.escribe', '', true);
      raise notice 'fn_cierre_revisar: la revisión de % no se pudo guardar (%): %', p.periodo, sqlstate, sqlerrm;
    end;
  end if;

  return query
    select (x->>'orden')::int, x->>'control', x->>'nivel', (x->>'ok')::boolean, x->>'detalle', x->>'que_hacer', x->>'ir_a'
      from jsonb_array_elements(v_rows) x
     order by 1;
end $$;
revoke execute on function public.fn_cierre_revisar(text) from public, anon, service_role;
grant  execute on function public.fn_cierre_revisar(text) to authenticated;
comment on function public.fn_cierre_revisar(text) is 'c9: la revisión de un período antes de cerrarlo: una fila por control, en orden (orden), con su nivel (detiene o aviso), ok, detalle en llano con números, qué hacer e ir_a (bandeja, conciliar, movimientos, estados, cobros, conexiones, cierre o nulo). Reutiliza los controles de c2, c3, c4, c6, p1 y c8. Guarda la última revisión del período abierto en cierre_revisiones. Solo el dueño; con POST.';


-- ---------------------------------------------------------------------
-- 6. EL CIERRE: fn_cierre_cerrar(periodo, confirmación). Con el candado de
--    la cadena puesto (nadie postea mientras), vuelve a revisar; si algo que
--    detiene está en rojo, MX010 con la lista en llano y no se toca nada;
--    si no, fn_cerrar_periodo (c2) y la fila de cierres. La confirmación es
--    exacta: fn_cierre_confirmacion(periodo).
-- ---------------------------------------------------------------------
create or replace function public.fn_cierre_cerrar(p_periodo text, p_confirmo text)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  p        periodos;
  v_conf   text;
  v_nom    text;
  v_rev    jsonb;
  v_rojos  text[];
  v_n      int;
  v_c2     jsonb;
  v_cie    cierres;
  v_j      jsonb;
  v_hash   text;
  v_bal    jsonb;
begin
  perform fn_cierre_exigir_dueno();
  p := fn_cierre_periodo(p_periodo);
  v_nom  := fn_cierre_nombre(p.periodo);
  v_conf := fn_cierre_confirmacion(p.periodo);
  if p.estado = 'cerrado' then
    raise exception using errcode = 'MX002',
      message = format('%s ya está cerrado (desde el %s, hora de Miami). Un cierre no se repite ni se deshace.',
                       initcap(left(v_nom, 1)) || substr(v_nom, 2), to_char(p.cerrado_el at time zone 'America/New_York', 'DD/MM/YYYY HH24:MI'));
  end if;
  if btrim(coalesce(p_confirmo, '')) <> v_conf then
    raise exception using errcode = '22023',
      message = format('Para cerrar %s escribe exactamente «%s» (llegó «%s»). Un cierre no se deshace: por eso se pide escrito.',
                       v_nom, v_conf, coalesce(p_confirmo, '')),
      hint = v_conf;
  end if;

  -- El candado de la cadena (c2): la revisión y el cierre, sin que entre
  -- ningún asiento entre medias. fn_cerrar_periodo lo vuelve a tomar (es el
  -- mismo de esta transacción).
  perform pg_advisory_xact_lock(820260923);

  select coalesce(jsonb_agg(to_jsonb(x) order by x.orden), '[]'::jsonb),
         coalesce(array_agg(format('%s) %s: %s%s', x.orden, x.control,
                                   case when length(x.detalle) > 400 then left(x.detalle, 399) || '…' else x.detalle end,
                                   coalesce(' → ' || case when length(x.que_hacer) > 200 then left(x.que_hacer, 199) || '…' else x.que_hacer end, ''))
                            order by x.orden) filter (where x.nivel = 'detiene' and x.ok is distinct from true), '{}')
    into v_rev, v_rojos
    from fn_cierre_revisar(p.periodo) x;
  v_n := cardinality(v_rojos);
  if v_n > 0 then
    raise exception using errcode = 'MX010',
      message = format('No se cierra %s: %s cosa(s) lo detienen. %s', v_nom, v_n, left(array_to_string(v_rojos, ' '), 2500)),
      hint    = format('Resuélvelas y vuelve a tocar «Cerrar». La lista entera: select * from fn_cierre_revisar(%L) where nivel = ''detiene'' and not ok;',
                       p.periodo);
  end if;

  -- El cierre de c2 (sus reglas: terminó, en orden, la apertura con su
  -- asiento, cuadre, read committed, el sello y la foto de la cadena).
  v_c2 := fn_cerrar_periodo(p.periodo);

  -- La fila del cierre: la revisión tal como estaba, el hash del mayor, la
  -- balanza como quedó, quién y cuándo.
  v_hash := fn_cierre_hash_mayor(p.periodo);
  v_bal  := fn_cierre_balanza(p.periodo);
  v_j    := fn_cierre_cuadre(p.periodo);
  perform set_config('mx_cierre.escribe', 'cierres', true);
  insert into cierres (periodo, cerrado_el, cerrado_por, cerrado_rol, revision, hash_mayor, balanza, asientos, lineas)
  values (p.periodo, (v_c2->>'cerrado_el')::timestamptz, auth.uid(),
          coalesce(nullif(current_setting('role', true), 'none'), session_user::text), v_rev, v_hash, v_bal,
          (v_j->>'asientos')::int, (v_j->>'lineas')::int)
  returning * into v_cie;
  perform set_config('mx_cierre.escribe', '', true);

  return jsonb_build_object(
    'periodo', p.periodo, 'nombre', v_nom, 'cerrado_el', v_cie.cerrado_el, 'cerrado_por', v_cie.cerrado_por,
    'hash_mayor', v_hash, 'cadena_al_cerrar', v_c2->>'cadena_al_cerrar',
    'asientos', v_cie.asientos, 'lineas', v_cie.lineas,
    'avisos', (select count(*) from jsonb_array_elements(v_rev) x where x->>'nivel' = 'aviso' and (x->>'ok')::boolean is distinct from true),
    'siguiente', fn_cierre_siguiente(),
    'siguiente_confirmacion', fn_cierre_confirmacion(fn_cierre_siguiente()),
    'export_carpeta', p.periodo || '/');
end $$;
revoke execute on function public.fn_cierre_cerrar(text, text) from public, anon, service_role;
grant  execute on function public.fn_cierre_cerrar(text, text) to authenticated;
comment on function public.fn_cierre_cerrar(text, text) is 'c9: cierra un período desde la app: con la confirmación exacta (fn_cierre_confirmacion), vuelve a revisar con el candado de la cadena puesto; si algo que detiene está en rojo, MX010 con la lista y no toca nada; si no, fn_cerrar_periodo (c2) y la fila de cierres (revisión, hash del mayor, balanza, quién, cuándo). Devuelve el cierre, el siguiente período y la carpeta del export. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 7. EL EXPORT: el bucket privado «cierres» y fn_cierre_export. La pantalla
--    sube los archivos a <periodo>/… y registra aquí la lista con su
--    sha256; la base comprueba que están en Storage (si esta base lo tiene).
--    Se puede repetir: el último gana, los anteriores quedan en el historial.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'c9: esta base no tiene Storage (storage.buckets): el bucket «cierres» no se crea aquí; en Supabase sí.';
    return;
  end if;
  begin
    insert into storage.buckets (id, name, public) values ('cierres', 'cierres', false) on conflict (id) do nothing;
  exception when others then
    raise notice 'c9: no se pudo crear el bucket «cierres» (%): créalo en Storage (privado) y vuelve a pegar.', sqlerrm;
  end;
  -- Solo el dueño sube y lee; nadie borra ni pisa por la API (un export se
  -- repite con archivos nuevos: los anteriores quedan).
  begin
    drop policy if exists "cierres: el dueno sube" on storage.objects;
    create policy "cierres: el dueno sube" on storage.objects for insert to authenticated
      with check (bucket_id = 'cierres' and public.es_dueno());
    drop policy if exists "cierres: el dueno lee" on storage.objects;
    create policy "cierres: el dueno lee" on storage.objects for select to authenticated
      using (bucket_id = 'cierres' and public.es_dueno());
    drop policy if exists "cierres: no se borra" on storage.objects;
    create policy "cierres: no se borra" on storage.objects as restrictive for delete to anon, authenticated
      using (bucket_id is distinct from 'cierres');
    drop policy if exists "cierres: no se pisa" on storage.objects;
    create policy "cierres: no se pisa" on storage.objects as restrictive for update to anon, authenticated
      using (bucket_id is distinct from 'cierres') with check (bucket_id is distinct from 'cierres');
  exception when others then
    raise notice 'c9: no se pudieron poner las policies del bucket «cierres» (%): ponlas en Storage → Policies (solo el dueño sube y lee; nadie borra).', sqlerrm;
  end;
end $$;

create or replace function public.fn_cierre_export(p_periodo text, p_archivos jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  p         periodos;
  c         cierres;
  v_carpeta text;
  v_f       jsonb;
  v_i       int := 0;
  v_lista   jsonb := '[]'::jsonb;
  v_rutas   text[] := '{}';
  v_sobra   text;
  v_bytes   bigint;
  v_falta   text[] := '{}';
  v_hay     boolean;
  v_tam     bigint;
  v_total   bigint := 0;
begin
  perform fn_cierre_exigir_dueno();
  p := fn_cierre_periodo(p_periodo);
  select * into c from cierres where periodo = p.periodo;
  if not found then
    raise exception using errcode = 'MX002',
      message = format('%s no está cerrado desde la app: solo se exporta un período cerrado (ciérralo primero).',
                       initcap(left(fn_cierre_nombre(p.periodo), 1)) || substr(fn_cierre_nombre(p.periodo), 2));
  end if;
  if p_archivos is null or jsonb_typeof(p_archivos) <> 'array' or jsonb_array_length(p_archivos) = 0 then
    raise exception using errcode = '22023',
      message = 'Los archivos llegan como una lista [{ruta, sha256, bytes}], con al menos uno (el CSV del mayor).';
  end if;
  v_carpeta := p.periodo || '/';
  for v_f in select value from jsonb_array_elements(p_archivos) loop
    v_i := v_i + 1;
    if jsonb_typeof(v_f) <> 'object' then
      raise exception using errcode = '22023', message = format('Archivo %s: cada archivo es un objeto {ruta, sha256, bytes}.', v_i);
    end if;
    select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(v_f) k where k not in ('ruta', 'sha256', 'bytes', 'tipo');
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Archivo %s: clave desconocida: %s.', v_i, v_sobra);
    end if;
    if coalesce(v_f->>'ruta', '') !~ ('^' || regexp_replace(v_carpeta, '([.])', '\\\1', 'g') || '[^/].*$') or (v_f->>'ruta') ~ '(^|/)\.\.(/|$)' then
      raise exception using errcode = '22023',
        message = format('Archivo %s: la ruta «%s» tiene que estar dentro de la carpeta del período en el bucket cierres (%s…).',
                         v_i, coalesce(v_f->>'ruta', ''), v_carpeta);
    end if;
    if coalesce(v_f->>'sha256', '') !~ '^[0-9a-f]{64}$' then
      raise exception using errcode = '22023',
        message = format('Archivo %s (%s): el sha256 va en 64 caracteres hexadecimales en minúsculas.', v_i, v_f->>'ruta');
    end if;
    begin
      v_bytes := (v_f->>'bytes')::bigint;
    exception when others then
      v_bytes := -1;
    end;
    if v_bytes is null or v_bytes < 0 then
      raise exception using errcode = 'MX005', message = format('Archivo %s (%s): bytes es su tamaño, un entero de 0 o más.', v_i, v_f->>'ruta');
    end if;
    if (v_f->>'ruta') = any (v_rutas) then
      raise exception using errcode = '22023', message = format('Archivo %s: la ruta «%s» viene dos veces.', v_i, v_f->>'ruta');
    end if;
    v_rutas := v_rutas || (v_f->>'ruta');
    v_total := v_total + v_bytes;
    -- Que esté en Storage (si esta base lo tiene; el banco de pruebas lo
    -- simula) y, si Storage apunta su tamaño (metadata.size), que mida lo
    -- que se declara: un registro que no corresponde al archivo subido no
    -- entra.
    if to_regclass('storage.objects') is not null then
      v_hay := null; v_tam := null;
      execute 'select true, case when o.metadata->>''size'' ~ ''^[0-9]+$'' then (o.metadata->>''size'')::bigint end '
              'from storage.objects o where o.bucket_id = ''cierres'' and o.name = $1' into v_hay, v_tam using v_f->>'ruta';
      if v_hay is null then
        v_falta := v_falta || (v_f->>'ruta');
      elsif v_tam is not null and v_tam <> v_bytes then
        raise exception using errcode = '22023',
          message = format('Archivo %s (%s): en el bucket cierres mide %s bytes y aquí dice %s. Vuelve a exportar.', v_i, v_f->>'ruta', v_tam, v_bytes);
      end if;
    end if;
    v_lista := v_lista || jsonb_strip_nulls(jsonb_build_object('ruta', v_f->>'ruta', 'sha256', v_f->>'sha256', 'bytes', v_bytes,
                                                              'tipo', nullif(v_f->>'tipo', '')));
  end loop;
  if cardinality(v_falta) > 0 then
    raise exception using errcode = '22023',
      message = format('No está(n) en el bucket cierres: %s. Sube los archivos primero y registra después.', array_to_string(v_falta, ', '));
  end if;

  perform set_config('mx_cierre.escribe', 'cierres', true);
  update cierres
     set export_historial = case when export_archivos is null then export_historial
                                 else export_historial || jsonb_build_object('exportado_el', exportado_el, 'exportado_por', exportado_por,
                                                                             'export_ruta', export_ruta, 'archivos', export_archivos) end,
         export_ruta      = v_carpeta,
         export_archivos  = v_lista,
         exportado_el     = clock_timestamp(),
         exportado_por    = auth.uid()
   where periodo = p.periodo
  returning * into c;
  perform set_config('mx_cierre.escribe', '', true);

  return jsonb_build_object('periodo', p.periodo, 'export_ruta', c.export_ruta, 'archivos', jsonb_array_length(c.export_archivos),
                            'bytes', v_total, 'exportado_el', c.exportado_el, 'hash_mayor', c.hash_mayor,
                            'veces', jsonb_array_length(c.export_historial) + 1);
end $$;
revoke execute on function public.fn_cierre_export(text, jsonb) from public, anon, service_role;
grant  execute on function public.fn_cierre_export(text, jsonb) to authenticated;
comment on function public.fn_cierre_export(text, jsonb) is 'c9: registra en cierres lo que la pantalla subió al bucket privado «cierres», carpeta <periodo>/, como [{ruta, sha256, bytes, tipo?}]: solo de un período cerrado, cada ruta dentro de su carpeta, el sha256 de 64 hex, y el archivo tiene que estar en Storage. Se puede repetir: el último gana y los anteriores quedan en export_historial. Solo el dueño.';


-- ---------------------------------------------------------------------
-- 8. LOS ACTIVOS FIJOS: el plan de depreciación de un mes, el alta, la baja,
--    el asiento del mes (fn_depreciacion_mes) y la vista. Convención: un
--    activo deprecia el mes completo en que entra en servicio y no deprecia
--    el mes de su baja ni después; la cuota de línea recta es
--    (costo − residual) / vida_meses al centavo, la última absorbe el
--    redondeo y nunca pasa del residual; el método manual deprecia su
--    monto_mensual hasta llegar al residual.
-- ---------------------------------------------------------------------
-- Lo que depreciaría cada activo en un mes (sin postear nada): su monto es
-- la cuota, o lo que falte hasta el residual si es menos; 0 si ya está
-- depreciado del todo. Cuenta lo ya posteado (vivo) en meses ANTERIORES.
create or replace function public.fn_depreciacion_plan(p_periodo text)
returns table (activo_id uuid, descripcion text, cuenta text, metodo text, cuota numeric, acumulada_antes numeric, monto numeric)
language sql stable
set search_path = public, pg_temp
as $$
  with p as (select * from periodos where periodo = p_periodo and tipo = 'mes')
  select af.id, af.descripcion, af.cuenta, af.metodo,
         case af.metodo when 'manual' then af.monto_mensual
              else round((af.costo - af.residual) / af.vida_meses, 2) end as cuota,
         x.acum as acumulada_antes,
         greatest(0, least(case af.metodo when 'manual' then af.monto_mensual
                                else round((af.costo - af.residual) / af.vida_meses, 2) end,
                           af.costo - af.residual - x.acum))::numeric(14,2) as monto
    from p
    join activos_fijos af on af.fecha_servicio <= p.hasta and (af.baja_fecha is null or af.baja_fecha > p.hasta)
    cross join lateral (
      select af.dep_acumulada_inicial
             + coalesce((select sum(ad.monto)
                           from activos_depreciaciones ad
                           join periodos pd on pd.periodo = ad.periodo
                           join asientos a on a.id = ad.asiento_id
                          where ad.activo_id = af.id and pd.hasta < p.desde
                            and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')), 0) as acum) x
   where af.estado = 'activo' or af.baja_fecha > p.hasta
   order by af.fecha_servicio, af.creado
$$;
revoke execute on function public.fn_depreciacion_plan(text) from public, anon, service_role;
grant  execute on function public.fn_depreciacion_plan(text) to authenticated;
comment on function public.fn_depreciacion_plan(text) is 'c9: lo que depreciaría cada activo en ese mes (sin postear): la cuota (línea recta o manual), lo acumulado antes y el monto del mes (lo que falte hasta el residual si es menos; 0 si ya terminó).';

-- El alta de un activo. p: {descripcion, placa_serie?, cuenta (15xx),
-- fecha_servicio (AAAA-MM-DD), costo, residual?, vida_meses (línea recta),
-- metodo? ('linea_recta' | 'manual'; sin él, el de cierre_config),
-- monto_mensual (manual), dep_acumulada_inicial?, asiento_alta_id?, notas?}.
-- Montos como texto o número, al centavo.
create or replace function public.fn_activo_alta(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg      cierre_config;
  v_sobra  text;
  v_metodo text;
  v_fecha  date;
  v_costo  numeric;
  v_res    numeric;
  v_vida   int;
  v_men    numeric;
  v_ini    numeric;
  v_alta   uuid;
  v_c      cuentas;
  a        activos_fijos;
begin
  perform fn_cierre_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'El activo llega como un objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p) k
   where k not in ('descripcion', 'placa_serie', 'cuenta', 'fecha_servicio', 'costo', 'residual', 'vida_meses', 'metodo',
                   'monto_mensual', 'dep_acumulada_inicial', 'asiento_alta_id', 'notas');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en el activo: %s.', v_sobra);
  end if;
  if coalesce(btrim(p->>'descripcion'), '') = '' then
    raise exception using errcode = '22023', message = 'Todo activo dice qué es (descripcion): «Camioneta Ford F-150 2024», «Taladro magnético».';
  end if;
  select * into v_c from cuentas where codigo = p->>'cuenta';
  if not found or v_c.codigo !~ '^15[0-9]{2}' or v_c.codigo = '1590' or not v_c.imputable or not v_c.activa then
    raise exception using errcode = 'MX004',
      message = format('La cuenta del activo es una 15xx imputable y activa (1510 vehículos, 1520 herramienta, 1530 cómputo, 1540 mejoras), no «%s».',
                       coalesce(p->>'cuenta', ''));
  end if;
  if coalesce(p->>'fecha_servicio', '') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception using errcode = '22023', message = 'La fecha en servicio va como texto AAAA-MM-DD.';
  end if;
  begin
    v_fecha := (p->>'fecha_servicio')::date;
  exception when others then
    raise exception using errcode = '22023', message = format('La fecha %s no existe.', p->>'fecha_servicio');
  end;
  begin
    v_costo := (p->>'costo')::numeric;
    v_res   := coalesce((p->>'residual')::numeric, 0);
    v_ini   := coalesce((p->>'dep_acumulada_inicial')::numeric, 0);
    v_men   := (p->>'monto_mensual')::numeric;
  exception when others then
    raise exception using errcode = 'MX005', message = 'costo, residual, dep_acumulada_inicial y monto_mensual son montos (245.37).';
  end;
  if v_costo is null or v_costo <= 0 or scale(v_costo) > 2 then
    raise exception using errcode = 'MX005', message = 'El costo es un monto mayor que cero, en centavos.';
  end if;
  if v_res < 0 or v_res >= v_costo or scale(v_res) > 2 then
    raise exception using errcode = 'MX005', message = 'El residual va de 0 a menos que el costo, en centavos.';
  end if;
  if v_ini < 0 or v_ini > v_costo - v_res or scale(v_ini) > 2 then
    raise exception using errcode = 'MX005', message = 'La depreciación acumulada de arranque va de 0 a (costo − residual), en centavos.';
  end if;
  select * into cfg from cierre_config where id = 1;
  v_metodo := coalesce(nullif(btrim(p->>'metodo'), ''), cfg.metodo_depreciacion, 'linea_recta');
  if v_metodo not in ('linea_recta', 'manual') then
    raise exception using errcode = '22023', message = format('Método «%s» no válido: linea_recta o manual.', v_metodo);
  end if;
  if v_metodo = 'linea_recta' then
    begin
      v_vida := (p->>'vida_meses')::int;
    exception when others then
      raise exception using errcode = 'MX005', message = 'vida_meses es un entero (60 = cinco años).';
    end;
    if v_vida is null or v_vida < 1 or v_vida > 600 then
      raise exception using errcode = 'MX005', message = 'La vida en meses va de 1 a 600 (60 = cinco años, 84 = siete).';
    end if;
  else
    if v_men is null or v_men <= 0 or scale(v_men) > 2 then
      raise exception using errcode = 'MX005', message = 'Con el método manual, monto_mensual es lo que se deprecia cada mes (mayor que cero, en centavos).';
    end if;
    v_vida := case when p ? 'vida_meses' then (p->>'vida_meses')::int end;
  end if;
  if coalesce(p->>'asiento_alta_id', '') <> '' then
    begin
      v_alta := (p->>'asiento_alta_id')::uuid;
    exception when others then
      raise exception using errcode = '22023', message = 'asiento_alta_id es el id (uuid) del asiento que registró la compra.';
    end;
    if not exists (select 1 from asientos x where x.id = v_alta) then
      raise exception using errcode = '22023', message = 'asiento_alta_id no es un asiento del libro.';
    end if;
  end if;

  perform set_config('mx_cierre.escribe', 'activos_fijos', true);
  insert into activos_fijos (descripcion, placa_serie, cuenta, fecha_servicio, costo, residual, vida_meses, metodo, monto_mensual,
                             dep_acumulada_inicial, asiento_alta_id, notas, creado_por)
  values (btrim(p->>'descripcion'), nullif(btrim(p->>'placa_serie'), ''), v_c.codigo, v_fecha, v_costo, v_res, v_vida, v_metodo,
          case when v_metodo = 'manual' then v_men end, v_ini, v_alta, nullif(btrim(p->>'notas'), ''), auth.uid())
  returning * into a;
  perform set_config('mx_cierre.escribe', '', true);
  return (select to_jsonb(v) from v_activos_fijos v where v.id = a.id);
end $$;
revoke execute on function public.fn_activo_alta(jsonb) from public, anon, service_role;
grant  execute on function public.fn_activo_alta(jsonb) to authenticated;
comment on function public.fn_activo_alta(jsonb) is 'c9: da de alta un activo fijo ({descripcion, placa_serie?, cuenta 15xx, fecha_servicio, costo, residual?, vida_meses, metodo?, monto_mensual (manual), dep_acumulada_inicial?, asiento_alta_id?, notas?}) con sus frenos (22023, MX004, MX005). Devuelve su fila de v_activos_fijos. Solo el dueño.';

-- La baja o venta: el activo deja de depreciar desde ese mes; el asiento
-- que la registró (Dr 1590 por lo acumulado, Cr 15xx por el costo, 4920 por
-- la diferencia y el dinero que entró), si ya se posteó a mano, se apunta
-- aquí (y 1590 deja de contar este activo).
create or replace function public.fn_activo_baja(p_id uuid, p_fecha date, p_motivo text, p_asiento_id uuid default null) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  a activos_fijos;
begin
  perform fn_cierre_exigir_dueno();
  select * into a from activos_fijos where id = p_id for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese activo.';
  end if;
  if a.estado = 'baja' then
    raise exception using errcode = 'MX008',
      message = format('«%s» ya está dado de baja desde el %s (%s).', a.descripcion, a.baja_fecha, a.baja_motivo);
  end if;
  if p_fecha is null or p_fecha < a.fecha_servicio then
    raise exception using errcode = '22023',
      message = format('La fecha de la baja va el día que se vendió o se retiró, no antes de que entró en servicio (%s).', a.fecha_servicio);
  end if;
  if coalesce(length(btrim(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'La baja dice por qué (motivo): «vendida», «robada», «chatarra»…';
  end if;
  if p_asiento_id is not null and not exists (select 1 from asientos x where x.id = p_asiento_id) then
    raise exception using errcode = '22023', message = 'p_asiento_id no es un asiento del libro.';
  end if;
  perform set_config('mx_cierre.escribe', 'activos_fijos', true);
  update activos_fijos
     set estado = 'baja', baja_fecha = p_fecha, baja_motivo = btrim(p_motivo), baja_asiento_id = p_asiento_id,
         baja_el = now(), baja_por = auth.uid()
   where id = p_id
  returning * into a;
  perform set_config('mx_cierre.escribe', '', true);
  return (select to_jsonb(v) from v_activos_fijos v where v.id = a.id)
         || jsonb_build_object('nota', case when p_asiento_id is null
                                            then 'Hasta que apuntes el asiento de la baja (Dr 1590 por lo acumulado, Cr ' || a.cuenta || ' por el costo, 4920 por la diferencia), 1590 sigue contando este activo.'
                                            else 'Con su asiento: 1590 ya no cuenta este activo.' end);
end $$;
revoke execute on function public.fn_activo_baja(uuid, date, text, uuid) from public, anon, service_role;
grant  execute on function public.fn_activo_baja(uuid, date, text, uuid) to authenticated;
comment on function public.fn_activo_baja(uuid, date, text, uuid) is 'c9: da de baja (venta, robo, chatarra) un activo desde esa fecha, con su motivo y, si ya se posteó, el asiento de la baja; deja de depreciar ese mes. MX008 si ya estaba de baja. Solo el dueño.';

-- EL ASIENTO DE DEPRECIACIÓN DEL MES: Dr 6950 (una línea por activo, con su
-- memo) / Cr 1590 (el total), fechado el último día del mes, por fn_postear
-- como el dueño. Idempotente: si el mes ya tiene su asiento vivo, lo
-- devuelve (ya_estaba) y no duplica. Devuelve {periodo, activos, monto,
-- asiento: {id, numero} | null, ya_estaba, detalle: [...], nota}.
create or replace function public.fn_depreciacion_mes(p_periodo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  p        periodos;
  v_nom    text;
  v_vivo   record;
  v_plan   jsonb;
  v_n      int;
  v_total  numeric;
  v_lineas jsonb;
  v_res    jsonb;
  v_id     uuid;
begin
  perform fn_cierre_exigir_dueno();
  p := fn_cierre_periodo(p_periodo);
  v_nom := fn_cierre_nombre(p.periodo);
  if p.tipo <> 'mes' then
    raise exception using errcode = 'MX002', message = format('La depreciación se postea por mes (AAAA-MM), no en %s.', v_nom);
  end if;
  -- Dos a la vez no postean dos (el candado de aquí; fn_postear toma el de la cadena).
  perform pg_advisory_xact_lock(820261108, hashtext('depreciacion'));
  select a.id, a.numero, sum(ad.monto) as monto, count(*) as n
    into v_vivo
    from activos_depreciaciones ad
    join asientos a on a.id = ad.asiento_id
   where ad.periodo = p.periodo
     and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
   group by a.id, a.numero
   order by a.cadena_pos desc
   limit 1;
  if v_vivo.id is not null then
    return jsonb_build_object('periodo', p.periodo, 'activos', v_vivo.n, 'monto', v_vivo.monto,
                              'asiento', jsonb_build_object('id', v_vivo.id, 'numero', v_vivo.numero), 'ya_estaba', true,
                              'nota', format('La depreciación de %s ya estaba posteada (asiento %s, %s): no se duplica. Si estaba mal, revérsala (fn_reversar) y vuelve a postear.',
                                             v_nom, v_vivo.numero, fn_cierre_usd(v_vivo.monto)));
  end if;
  if p.estado = 'cerrado' then
    raise exception using errcode = 'MX002',
      message = format('%s ya está cerrado: la depreciación que faltó entra en el mes abierto (un asiento a mano Dr 6950 / Cr 1590, o como ajuste del CPA).',
                       initcap(left(v_nom, 1)) || substr(v_nom, 2));
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('activo_id', x.activo_id, 'descripcion', x.descripcion, 'cuenta', x.cuenta,
                                               'metodo', x.metodo, 'cuota', x.cuota, 'acumulada_antes', x.acumulada_antes, 'monto', x.monto)
                            order by x.descripcion), '[]'::jsonb),
         count(*) filter (where x.monto > 0), coalesce(sum(x.monto), 0)
    into v_plan, v_n, v_total
    from fn_depreciacion_plan(p.periodo) x;
  if v_n = 0 then
    return jsonb_build_object('periodo', p.periodo, 'activos', 0, 'monto', 0, 'asiento', null, 'ya_estaba', false, 'detalle', v_plan,
                              'nota', case when not exists (select 1 from activos_fijos)
                                           then 'No hay activos fijos dados de alta: nada que depreciar (se cargan en f12 con la cédula del CPA).'
                                           else format('Ningún activo deprecia en %s (todos terminaron, o entran en servicio después).', v_nom) end);
  end if;
  select jsonb_agg(jsonb_build_object('cuenta', '6950', 'monto', (x->>'monto'),
                                      'memo', left(format('%s%s · %s', x->>'descripcion',
                                                          coalesce(' (' || (select af.placa_serie from activos_fijos af where af.id = (x->>'activo_id')::uuid) || ')', ''),
                                                          case x->>'metodo' when 'manual' then 'manual' else 'línea recta' end), 200)))
    into v_lineas
    from jsonb_array_elements(v_plan) x where (x->>'monto')::numeric > 0;
  v_lineas := v_lineas || jsonb_build_array(jsonb_build_object('cuenta', '1590', 'monto', (-v_total)::text,
                                                               'memo', format('Depreciación acumulada de %s activo(s)', v_n)));
  v_res := fn_postear(jsonb_build_object(
    'fecha', to_char(p.hasta, 'YYYY-MM-DD'),
    'descripcion', format('Depreciación de %s (c9: fn_depreciacion_mes, %s activo(s))', v_nom, v_n),
    'lineas', v_lineas));
  v_id := (v_res->>'id')::uuid;
  perform set_config('mx_cierre.escribe', 'activos_depreciaciones', true);
  insert into activos_depreciaciones (periodo, activo_id, monto, asiento_id, creado_por)
  select p.periodo, (x->>'activo_id')::uuid, (x->>'monto')::numeric, v_id, auth.uid()
    from jsonb_array_elements(v_plan) x where (x->>'monto')::numeric > 0;
  perform set_config('mx_cierre.escribe', '', true);
  return jsonb_build_object('periodo', p.periodo, 'activos', v_n, 'monto', v_total,
                            'asiento', jsonb_build_object('id', v_id, 'numero', v_res->>'numero'), 'ya_estaba', false,
                            'detalle', v_plan,
                            'nota', format('Posteada la depreciación de %s: %s en %s activo(s) (asiento %s, Dr 6950 / Cr 1590).',
                                           v_nom, fn_cierre_usd(v_total), v_n, v_res->>'numero'));
end $$;
revoke execute on function public.fn_depreciacion_mes(text) from public, anon, service_role;
grant  execute on function public.fn_depreciacion_mes(text) to authenticated;
comment on function public.fn_depreciacion_mes(text) is 'c9: postea el asiento de depreciación del mes (Dr 6950, una línea por activo vivo; Cr 1590 el total), fechado el último día, por fn_postear como el dueño; idempotente (si el mes ya tiene su asiento vivo lo devuelve con ya_estaba). Deja el detalle por activo en activos_depreciaciones. Solo el dueño.';

drop view if exists public.v_activos_fijos;
create view public.v_activos_fijos with (security_invoker = true) as
select af.id, af.descripcion, af.placa_serie, af.cuenta, cu.nombre as cuenta_nombre, af.fecha_servicio, af.costo, af.residual,
       af.vida_meses, af.metodo, af.monto_mensual, af.dep_acumulada_inicial,
       d.posteado                                                   as depreciado_libro,
       (af.dep_acumulada_inicial + d.posteado)::numeric(14,2)       as acumulada,
       (af.costo - af.dep_acumulada_inicial - d.posteado)::numeric(14,2) as valor_libros,
       d.meses                                                      as meses_posteados,
       d.ultimo_periodo,
       case af.metodo when 'manual' then af.monto_mensual else round((af.costo - af.residual) / af.vida_meses, 2) end as cuota_mensual,
       (af.costo - af.residual - af.dep_acumulada_inicial - d.posteado <= 0)                  as terminado,
       af.estado, af.baja_fecha, af.baja_motivo, af.baja_asiento_id, af.baja_el, af.asiento_alta_id, af.notas, af.creado, af.creado_por
  from public.activos_fijos af
  join public.cuentas cu on cu.codigo = af.cuenta
  cross join lateral (
    select coalesce(sum(ad.monto), 0)::numeric(14,2) as posteado, count(*) as meses, max(ad.periodo) as ultimo_periodo
      from public.activos_depreciaciones ad
      join public.asientos a on a.id = ad.asiento_id
     where ad.activo_id = af.id
       and not exists (select 1 from public.asientos r where r.reversa_a = a.id and r.camino = 'reverso')) d;
revoke all on public.v_activos_fijos from public, anon, authenticated, service_role;
grant select on public.v_activos_fijos to authenticated;
comment on view public.v_activos_fijos is 'c9: cada activo fijo con lo depreciado en el libro (asientos vivos), la acumulada (arranque + libro), el valor en libros, los meses posteados, su cuota mensual, si terminó, y su baja.';


-- ---------------------------------------------------------------------
-- 9. La configuración (fn_cierre_config), la reserva de impuestos
--    (v_reserva_impuestos y los estimados) y el DR-15 (v_dr15_mes).
-- ---------------------------------------------------------------------
-- p: {ronda_activa?, reserva_pct? (0 a 100, o null para quitarlo),
-- metodo_depreciacion?, aviso_push?}. Devuelve la configuración como quedó.
create or replace function public.fn_cierre_config(p jsonb) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_sobra text;
  v_pct   numeric;
  c       cierre_config;
begin
  perform fn_cierre_exigir_dueno();
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '22023', message = 'La configuración llega como un objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p) k where k not in ('ronda_activa', 'reserva_pct', 'metodo_depreciacion', 'aviso_push');
  if v_sobra is not null then
    raise exception using errcode = '22023', message = format('Clave desconocida en la configuración: %s.', v_sobra);
  end if;
  if p ? 'reserva_pct' and jsonb_typeof(p->'reserva_pct') <> 'null' then
    begin
      v_pct := (p->>'reserva_pct')::numeric;
    exception when others then
      raise exception using errcode = 'MX005', message = 'reserva_pct es el % que fija el CPA (por ejemplo 25), o null para quitarlo.';
    end;
    if v_pct < 0 or v_pct > 100 or scale(v_pct) > 2 then
      raise exception using errcode = 'MX005', message = 'reserva_pct va de 0 a 100, con dos decimales como mucho.';
    end if;
  end if;
  if p ? 'metodo_depreciacion' and coalesce(p->>'metodo_depreciacion', '') not in ('linea_recta', 'manual') then
    raise exception using errcode = '22023', message = 'metodo_depreciacion es linea_recta o manual (el método libro lo decide el CPA).';
  end if;
  if (p ? 'ronda_activa' and jsonb_typeof(p->'ronda_activa') <> 'boolean')
     or (p ? 'aviso_push' and jsonb_typeof(p->'aviso_push') <> 'boolean') then
    raise exception using errcode = '22023', message = 'ronda_activa y aviso_push son true o false.';
  end if;
  perform set_config('mx_cierre.escribe', 'cierre_config', true);
  update cierre_config
     set ronda_activa        = case when p ? 'ronda_activa' then (p->>'ronda_activa')::boolean else ronda_activa end,
         reserva_pct         = case when p ? 'reserva_pct' then v_pct else reserva_pct end,
         metodo_depreciacion = coalesce(p->>'metodo_depreciacion', metodo_depreciacion),
         aviso_push          = case when p ? 'aviso_push' then (p->>'aviso_push')::boolean else aviso_push end,
         actualizado         = now(),
         actualizado_por     = auth.uid()
   where id = 1
  returning * into c;
  perform set_config('mx_cierre.escribe', '', true);
  return to_jsonb(c);
end $$;
revoke execute on function public.fn_cierre_config(jsonb) from public, anon, service_role;
grant  execute on function public.fn_cierre_config(jsonb) to authenticated;
comment on function public.fn_cierre_config(jsonb) is 'c9: cambia la configuración del cierre ({ronda_activa?, reserva_pct? (0–100 o null), metodo_depreciacion?, aviso_push?}) y la devuelve. Solo el dueño.';

-- Un pago de impuesto estimado: el asiento del pago (su Dr 3200, lo que
-- c8 propone para un pago al IRS) se marca como estimado del año fiscal
-- (el del 15-ene es del año anterior; se puede decir otro).
create or replace function public.fn_reserva_estimado_marcar(p_asiento uuid, p_nota text default null, p_anio_fiscal int default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  a      asientos;
  v_m    numeric;
  v_anio int;
  e      reserva_estimados;
begin
  perform fn_cierre_exigir_dueno();
  select * into a from asientos where id = p_asiento;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese asiento.';
  end if;
  if exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso') or a.reversa_a is not null then
    raise exception using errcode = '22023', message = format('El asiento %s está reversado (o es un reverso): no es un pago vivo.', a.numero);
  end if;
  select coalesce(sum(l.monto), 0) into v_m from asiento_lineas l where l.asiento_id = a.id and l.cuenta = '3200' and l.monto > 0;
  if v_m <= 0 then
    raise exception using errcode = '22023',
      message = format('El asiento %s no carga nada a 3200 (distribuciones al accionista): un pago de impuesto estimado de Edgar va Dr 3200 / Cr banco (c8 lo propone así para un pago al IRS).', a.numero);
  end if;
  if exists (select 1 from reserva_estimados x where x.asiento_id = a.id and x.anulado_el is null) then
    raise exception using errcode = 'MX008', message = format('El asiento %s ya está marcado como estimado pagado.', a.numero);
  end if;
  v_anio := coalesce(p_anio_fiscal,
                     case when extract(month from a.fecha_contable) = 1 then a.anio - 1 else a.anio end);
  if v_anio < 2020 or v_anio > a.anio then
    raise exception using errcode = '22023', message = format('El año fiscal del estimado (%s) no tiene sentido para un pago del %s.', v_anio, a.fecha_contable);
  end if;
  perform set_config('mx_cierre.escribe', 'reserva_estimados', true);
  -- (uno anulado con el mismo asiento no estorba: la unicidad es del vivo)
  insert into reserva_estimados (fecha, monto, asiento_id, anio_fiscal, nota, creado_por)
  values (a.fecha_contable, v_m, a.id, v_anio, nullif(btrim(p_nota), ''), auth.uid())
  returning * into e;
  perform set_config('mx_cierre.escribe', '', true);
  return to_jsonb(e) || jsonb_build_object('asiento_numero', a.numero);
end $$;
revoke execute on function public.fn_reserva_estimado_marcar(uuid, text, int) from public, anon, service_role;
grant  execute on function public.fn_reserva_estimado_marcar(uuid, text, int) to authenticated;
comment on function public.fn_reserva_estimado_marcar(uuid, text, int) is 'c9: marca el asiento de un pago al IRS (su Dr 3200) como impuesto estimado pagado del año fiscal (el de enero cuenta para el año anterior, salvo que se diga otro). MX008 si ya estaba. Solo el dueño.';

create or replace function public.fn_reserva_estimado_anular(p_id uuid, p_motivo text) returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  e reserva_estimados;
begin
  perform fn_cierre_exigir_dueno();
  select * into e from reserva_estimados where id = p_id for update;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese estimado.';
  end if;
  if e.anulado_el is not null then
    raise exception using errcode = 'MX008', message = format('Ese estimado ya estaba anulado (%s).', e.anulado_motivo);
  end if;
  if coalesce(length(btrim(p_motivo)), 0) < 3 then
    raise exception using errcode = '22023', message = 'Anular un estimado dice por qué (motivo).';
  end if;
  perform set_config('mx_cierre.escribe', 'reserva_estimados', true);
  update reserva_estimados set anulado_el = now(), anulado_por = auth.uid(), anulado_motivo = btrim(p_motivo) where id = p_id
  returning * into e;
  perform set_config('mx_cierre.escribe', '', true);
  return to_jsonb(e);
end $$;
revoke execute on function public.fn_reserva_estimado_anular(uuid, text) from public, anon, service_role;
grant  execute on function public.fn_reserva_estimado_anular(uuid, text) to authenticated;
comment on function public.fn_reserva_estimado_anular(uuid, text) is 'c9: anula (con su motivo) un estimado marcado por error; queda. Solo el dueño.';

-- La reserva de impuestos (1030) hoy, en una fila:
--   utilidad_anio      la utilidad del año a la fecha (cuentas de resultados,
--                      con la regla de ejercicio de c4: un ajuste del CPA es
--                      del año que corrige)
--   reserva_pct        el % del CPA (cierre_config)
--   objetivo           utilidad × %, nunca negativo (sin %: nulo)
--   estimados_pagados  lo marcado en reserva_estimados para este año fiscal
--   objetivo_1030      objetivo − estimados pagados (lo que 1030 debería tener)
--   saldo_1030         lo que 1030 tiene
--   diferencia         objetivo_1030 − saldo_1030 (> 0: transfiere; < 0: sobra)
--   mensaje            en llano
--   proximo_estimado, dias_para_estimado, estimado_en_15_dias, monto_sugerido
create or replace function public.fn_reserva_proximo_estimado(p_hoy date) returns date
language sql immutable
set search_path = public, pg_temp
as $$
  select min(d) from (
    select make_date(extract(year from p_hoy)::int + y, m, 15) as d
      from (values (0), (1)) as yy(y), (values (1), (4), (6), (9)) as mm(m)) x
   where d >= p_hoy
$$;
revoke execute on function public.fn_reserva_proximo_estimado(date) from public, anon, service_role;
grant  execute on function public.fn_reserva_proximo_estimado(date) to authenticated;
comment on function public.fn_reserva_proximo_estimado(date) is 'c9: el próximo vencimiento de impuesto estimado desde ese día (15-abr, 15-jun, 15-sep, 15-ene).';

drop view if exists public.v_reserva_impuestos;
create view public.v_reserva_impuestos with (security_invoker = true) as
with hoy as (select public.fn_fecha_miami(now()) as d, extract(year from public.fn_fecha_miami(now()))::int as anio),
     cfg as (select c.reserva_pct from public.cierre_config c where c.id = 1),
     util as (
       select coalesce(-sum(l.monto), 0)::numeric(14,2) as utilidad
         from public.asiento_lineas l
         join public.asientos a on a.id = l.asiento_id
         join public.cuentas c on c.codigo = l.cuenta
         left join public.periodos pa on pa.periodo = a.afecta_periodo
         cross join hoy
        where c.tipo in ('ingreso', 'otro_ingreso', 'costo', 'gasto', 'otro_gasto')
          and a.fecha_contable <= hoy.d
          and (case when a.afecta_periodo is null then a.anio else coalesce(pa.anio, a.anio) end) = hoy.anio),
     r1030 as (select coalesce(sum(l.monto), 0)::numeric(14,2) as saldo
                 from public.asiento_lineas l join public.asientos a on a.id = l.asiento_id, hoy
                where l.cuenta = '1030' and a.fecha_contable <= hoy.d),
     est as (select coalesce(sum(e.monto), 0)::numeric(14,2) as pagados, count(*) as n
               from public.reserva_estimados e, hoy
              where e.anulado_el is null and e.anio_fiscal = hoy.anio),
     calc as (
       select hoy.anio, hoy.d as hoy, util.utilidad as utilidad_anio, cfg.reserva_pct,
              case when cfg.reserva_pct is null then null
                   else greatest(round(util.utilidad * cfg.reserva_pct / 100, 2), 0) end as objetivo,
              est.pagados as estimados_pagados, est.n as estimados_n, r1030.saldo as saldo_1030,
              public.fn_reserva_proximo_estimado(hoy.d) as proximo_estimado
         from hoy, cfg, util, r1030, est)
select c.anio, c.hoy, c.utilidad_anio, c.reserva_pct, c.objetivo, c.estimados_pagados, c.estimados_n,
       case when c.objetivo is null then null else greatest(c.objetivo - c.estimados_pagados, 0)::numeric(14,2) end as objetivo_1030,
       c.saldo_1030,
       case when c.objetivo is null then null
            else (greatest(c.objetivo - c.estimados_pagados, 0) - c.saldo_1030)::numeric(14,2) end as diferencia,
       case when c.reserva_pct is null
              then 'Falta el % que fije el CPA: cuando lo diga, guárdalo en Cierre → ajustes (fn_cierre_config, reserva_pct) y aquí saldrá cuánto transferir a la reserva (1030).'
            when greatest(c.objetivo - c.estimados_pagados, 0) - c.saldo_1030 > 0
              then format('Transfiere %s a la reserva (1030): la utilidad de %s a la fecha es %s, el %s %% son %s, ya pagaste %s en estimados y la reserva tiene %s.',
                          public.fn_cierre_usd(greatest(c.objetivo - c.estimados_pagados, 0) - c.saldo_1030), c.anio,
                          public.fn_cierre_usd(c.utilidad_anio), c.reserva_pct, public.fn_cierre_usd(c.objetivo),
                          public.fn_cierre_usd(c.estimados_pagados), public.fn_cierre_usd(c.saldo_1030))
            when greatest(c.objetivo - c.estimados_pagados, 0) - c.saldo_1030 < 0
              then format('Sobra %s en la reserva (1030): tiene %s y el objetivo es %s (utilidad de %s a la fecha %s × %s %% − %s ya pagados).',
                          public.fn_cierre_usd(c.saldo_1030 - greatest(c.objetivo - c.estimados_pagados, 0)), public.fn_cierre_usd(c.saldo_1030),
                          public.fn_cierre_usd(greatest(c.objetivo - c.estimados_pagados, 0)), c.anio, public.fn_cierre_usd(c.utilidad_anio),
                          c.reserva_pct, public.fn_cierre_usd(c.estimados_pagados))
            else format('La reserva (1030) está al día: %s, lo que piden la utilidad de %s a la fecha (%s) y el %s %% del CPA, menos %s ya pagados.',
                        public.fn_cierre_usd(c.saldo_1030), c.anio, public.fn_cierre_usd(c.utilidad_anio), c.reserva_pct,
                        public.fn_cierre_usd(c.estimados_pagados)) end as mensaje,
       c.proximo_estimado,
       (c.proximo_estimado - c.hoy) as dias_para_estimado,
       (c.proximo_estimado - c.hoy) <= 15 as estimado_en_15_dias,
       case when c.objetivo is null then null else greatest(c.objetivo - c.estimados_pagados, 0)::numeric(14,2) end as monto_sugerido,
       'El monto sugerido es orientativo (lo acumulado y no pagado al % del CPA): el estimado lo fija el CPA.'::text as nota
  from calc c;
revoke all on public.v_reserva_impuestos from public, anon, authenticated, service_role;
grant select on public.v_reserva_impuestos to authenticated;
comment on view public.v_reserva_impuestos is 'c9: la reserva de impuestos (1030) hoy, en una fila: la utilidad del año a la fecha, el % del CPA, el objetivo, los estimados ya pagados, el saldo de 1030, la diferencia y el mensaje («transfiere $X» / «sobra $Y» / «falta el % que fije el CPA»), y el próximo estimado (15-abr, 15-jun, 15-sep, 15-ene) con si cae en 15 días.';

-- La base del use tax que la IA marcó y Edgar aprobó (c8), por mes: la suma
-- de esos cargos. Nula si el contador no está. Por función (sin depender
-- de la tabla de c8): la vista de abajo sigue valiendo sin c8.
create or replace function public.fn_cierre_use_tax_base(p_periodo text) returns jsonb
language plpgsql stable
set search_path = public, pg_temp
as $$
declare
  v jsonb;
begin
  if to_regclass('public.contador_propuestas') is null then
    return null;
  end if;
  execute $q$
    select jsonb_build_object('n', count(*), 'base', coalesce(sum(-m.monto), 0)::numeric(14,2))
      from public.contador_propuestas cp
      join public.movimientos_banco m on m.id = cp.movimiento_id
     where m.periodo = $1 and cp.estado in ('aprobada', 'editada')
       and coalesce((cp.propuesta->'flags'->>'use_tax')::boolean, false) $q$ into v using p_periodo;
  return v;
end $$;
revoke execute on function public.fn_cierre_use_tax_base(text) from public, anon, service_role;
grant  execute on function public.fn_cierre_use_tax_base(text) to authenticated;
comment on function public.fn_cierre_use_tax_base(text) is 'c9: por mes, cuántos cargos marcó la IA como use_tax y Edgar aprobó (c8) y cuánto suman (la base del use tax); nulo sin c8.';

drop view if exists public.v_dr15_mes;
create view public.v_dr15_mes with (security_invoker = true) as
select p.periodo, p.desde, p.hasta,
       (u->>'n')::int                                                  as compras_use_tax_n,
       (u->>'base')::numeric                                           as compras_use_tax_base,
       t.cargos                                                        as use_tax_cargado_2300,
       t.pagos                                                         as use_tax_pagado_2300,
       t.saldo                                                         as use_tax_saldo_2300,
       null::numeric                                                   as ventas_gravables,
       null::numeric                                                   as sales_tax_cobrado,
       concat_ws(' ',
         case when u is null then 'Sin el contador (c8) no se sabe qué compras llevaban use tax: la base sale de las compras que la IA marca «use_tax» y Edgar aprueba.'
              else 'La base son las compras que la IA marcó «use_tax» y Edgar aprobó (c8); la tasa la pone el DR-15.' end,
         'Lo cargado a 2300 es el use tax ya devengado; lo pagado, los pagos al DOR.',
         'Las ventas gravables y el sales tax cobrado todavía no se saben: las facturas de la app no separan el impuesto (llegan con f10).') as nota
  from public.periodos p
  cross join lateral (select public.fn_cierre_use_tax_base(p.periodo) as u) x
  cross join lateral (
    select coalesce(-sum(l.monto) filter (where l.monto < 0), 0)::numeric(14,2) as cargos,
           coalesce(sum(l.monto) filter (where l.monto > 0), 0)::numeric(14,2)  as pagos,
           coalesce((select -sum(l2.monto) from public.asiento_lineas l2 join public.asientos a2 on a2.id = l2.asiento_id
                      where l2.cuenta = '2300' and a2.fecha_contable <= p.hasta), 0)::numeric(14,2) as saldo
      from public.asiento_lineas l
      join public.asientos a on a.id = l.asiento_id
     where l.cuenta = '2300' and a.periodo = p.periodo) t
 where p.tipo = 'mes';
revoke all on public.v_dr15_mes from public, anon, authenticated, service_role;
grant select on public.v_dr15_mes to authenticated;
comment on view public.v_dr15_mes is 'c9: por mes, lo que el DR-15 pide y la base ya sabe: la base del use tax (las compras que la IA marcó use_tax y Edgar aprobó, c8), lo cargado y lo pagado en 2300 y su saldo; las ventas gravables y el sales tax cobrado salen nulos hasta f10 (la nota lo dice).';


-- ---------------------------------------------------------------------
-- 10. LA RONDA NOCTURNA: fn_ronda(). SQL puro, sin API, sin IA. Revisa el
--     período que toca y los controles globales, escribe ronda_resultados,
--     guarda 90 días y avisa al teléfono de cada rojo NUEVO. Nunca falla
--     hacia fuera (pg_cron no dejaría rastro): cada pieza con su excepción,
--     escrita como un rojo. Devuelve cuántos controles salieron en rojo.
-- ---------------------------------------------------------------------
-- Los controles globales (la ronda los suma a la revisión del período):
--   · cierre guardado: <periodo>  la balanza y el hash del mayor de cada
--                      período cerrado desde la app, recalculados hoy,
--                      contra los guardados al cerrar;
--   · activos: 1590   hoy (igual que el 90 de la revisión);
--   · reserva: 1030   si la reserva queda corta (aviso), o falta el %;
--   · reserva: próximo estimado   si vence en 15 días (aviso).
create or replace function public.fn_ronda_globales() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_rows jsonb := '[]'::jsonb;
  r      record;
  v_h    text;
  v_b    jsonb;
  v_dif  text;
  v_s    numeric;
  v_esp  numeric;
  v_n    int;
  v_hoy  date := fn_fecha_miami(now());
  v_res  record;
begin
  -- Cada cierre guardado, recalculado hoy.
  for r in select c.periodo, c.hash_mayor, c.balanza, c.cerrado_el from cierres c order by c.periodo loop
    begin
      v_h := fn_cierre_hash_mayor(r.periodo);
      v_b := fn_cierre_balanza(r.periodo);
      if v_h = r.hash_mayor and v_b = r.balanza then
        v_rows := v_rows || fn_cierre_fila(200, 'cierre guardado: ' || r.periodo, 'detiene', true,
          format('La balanza y el hash del mayor de %s siguen iguales a los guardados al cerrar (%s…).', fn_cierre_nombre(r.periodo), left(r.hash_mayor, 12)),
          null, 'cierre');
      else
        select string_agg(format('%s: guardado inicial %s / debe %s / haber %s / final %s, hoy %s / %s / %s / %s',
                                 coalesce(g.cuenta, h.cuenta), coalesce(g.inicial::text, '—'), coalesce(g.debe::text, '—'),
                                 coalesce(g.haber::text, '—'), coalesce(g.final::text, '—'), coalesce(h.inicial::text, '—'),
                                 coalesce(h.debe::text, '—'), coalesce(h.haber::text, '—'), coalesce(h.final::text, '—')),
                          '; ' order by coalesce(g.cuenta, h.cuenta))
          into v_dif
          from jsonb_to_recordset(r.balanza) as g(cuenta text, inicial numeric, debe numeric, haber numeric, final numeric)
          full join jsonb_to_recordset(v_b) as h(cuenta text, inicial numeric, debe numeric, haber numeric, final numeric) on h.cuenta = g.cuenta
         where (g.inicial, g.debe, g.haber, g.final) is distinct from (h.inicial, h.debe, h.haber, h.final);
        v_rows := v_rows || fn_cierre_fila(200, 'cierre guardado: ' || r.periodo, 'detiene', false,
          format('%s cambió después de cerrarse: %s%s', initcap(left(fn_cierre_nombre(r.periodo), 1)) || substr(fn_cierre_nombre(r.periodo), 2),
                 case when v_h <> r.hash_mayor then format('el hash del mayor era %s… y hoy da %s…', left(r.hash_mayor, 12), left(v_h, 12)) else 'el hash del mayor sigue igual' end,
                 case when v_dif is not null then '; la balanza difiere en ' || left(v_dif, 600) else '' end),
          'Alguien escribió en un período cerrado por debajo de las guardas (c2 no lo permite por ningún camino normal): no toques nada; restaura del respaldo de Postgres y avisa (OPERACION.md).',
          'cierre');
      end if;
    exception when others then
      v_rows := v_rows || fn_cierre_fila(200, 'cierre guardado: ' || r.periodo, 'detiene', false,
        format('No se pudo recalcular %s: %s %s.', r.periodo, sqlstate, sqlerrm), 'Avisa.', 'cierre');
    end;
  end loop;

  -- 1590 hoy.
  begin
    select coalesce(-sum(l.monto), 0) into v_s
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where l.cuenta = '1590' and a.fecha_contable <= v_hoy;
    select count(*) into v_n from activos_fijos;
    select coalesce(sum(case when af.fecha_servicio <= v_hoy then af.dep_acumulada_inicial else 0 end
                        + coalesce((select sum(ad.monto) from activos_depreciaciones ad
                                      join asientos a on a.id = ad.asiento_id
                                     where ad.activo_id = af.id
                                       and not exists (select 1 from asientos x where x.reversa_a = a.id and x.camino = 'reverso')), 0)), 0)
      into v_esp
      from activos_fijos af
     where af.estado = 'activo' or af.baja_asiento_id is null;
    v_rows := v_rows || fn_cierre_fila(210, 'activos: 1590 = la depreciación acumulada de los activos', 'detiene', v_n = 0 or v_s = v_esp,
      case when v_n = 0 then format('No hay activos fijos dados de alta todavía (f12); 1590 tiene %s.', fn_cierre_usd(v_s))
           when v_s = v_esp then format('1590 hoy: %s en el libro = %s según los %s activo(s).', fn_cierre_usd(v_s), fn_cierre_usd(v_esp), v_n)
           else format('1590 hoy no cuadra: %s en el libro y %s según los %s activo(s) (diferencia %s).', fn_cierre_usd(v_s), fn_cierre_usd(v_esp), v_n, fn_cierre_usd(v_s - v_esp)) end,
      case when v_n > 0 and v_s <> v_esp then 'Mira qué activo falta o sobra (v_activos_fijos) y corrígelo con un alta, una baja o un asiento.' end, 'cierre');
  exception when others then
    v_rows := v_rows || fn_cierre_fila(210, 'activos: 1590', 'detiene', false, format('No se pudo revisar 1590: %s %s.', sqlstate, sqlerrm), 'Avisa.', 'cierre');
  end;

  -- La reserva y el próximo estimado.
  begin
    select * into v_res from v_reserva_impuestos;
    v_rows := v_rows || fn_cierre_fila(220, 'reserva: 1030', 'aviso', v_res.reserva_pct is null or coalesce(v_res.diferencia, 0) <= 0,
      v_res.mensaje,
      case when v_res.reserva_pct is null then 'Pregunta al CPA el % y guárdalo en Cierre → ajustes.'
           when coalesce(v_res.diferencia, 0) > 0 then 'Transfiere a la reserva desde la operativa (1010 → 1030) y clasifícalo en la Bandeja como transferencia.' end,
      'cierre');
    v_rows := v_rows || fn_cierre_fila(222, 'reserva: próximo estimado', 'aviso', not v_res.estimado_en_15_dias,
      case when v_res.estimado_en_15_dias
           then format('El impuesto estimado vence el %s (en %s días)%s.', v_res.proximo_estimado, v_res.dias_para_estimado,
                       case when v_res.monto_sugerido is null then ': el monto lo fija el CPA (falta el % de la reserva)'
                            else format(': orientativo %s (lo acumulado y no pagado al %s %%; el monto lo fija el CPA)', fn_cierre_usd(v_res.monto_sugerido), v_res.reserva_pct) end)
           else format('El próximo impuesto estimado vence el %s (en %s días).', v_res.proximo_estimado, v_res.dias_para_estimado) end,
      case when v_res.estimado_en_15_dias then 'Paga el estimado desde la reserva (1030) y marca el asiento del pago como estimado (fn_reserva_estimado_marcar).' end,
      'cierre');
  exception when others then
    v_rows := v_rows || fn_cierre_fila(220, 'reserva: 1030', 'aviso', false, format('No se pudo revisar la reserva: %s %s.', sqlstate, sqlerrm), 'Avisa.', 'cierre');
  end;
  return v_rows;
end $$;
revoke execute on function public.fn_ronda_globales() from public, anon, authenticated, service_role;
comment on function public.fn_ronda_globales() is 'c9: los controles globales de la ronda: cada cierre guardado (balanza y hash recalculados), 1590 hoy, la reserva 1030 y el próximo estimado.';

create or replace function public.fn_ronda() returns int
language plpgsql
set search_path = public, pg_temp
as $$
declare
  cfg       cierre_config;
  v_t0      timestamptz := clock_timestamp();
  v_hoy     date := fn_fecha_miami(clock_timestamp());
  v_per     text;
  v_rows    jsonb := '[]'::jsonb;
  v_prev    timestamptz;
  v_rojos   int := 0;
  v_avisos  int := 0;
  v_dueno   uuid;
  r         record;
  v_push    boolean;
begin
  perform fn_cierre_sin_api();
  select * into cfg from cierre_config where id = 1;
  if not coalesce(cfg.ronda_activa, true) then
    return 0;
  end if;
  -- Una ronda a la vez.
  perform pg_advisory_xact_lock(820261108, hashtext('ronda'));

  -- El período que toca: el abierto más viejo que ya terminó; si ninguno
  -- terminó, el mes en curso (si existe); si no hay ninguno, nada.
  select p.periodo into v_per from periodos p
   where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.hasta < v_hoy
   order by p.desde limit 1;
  if v_per is null then
    select p.periodo into v_per from periodos p
     where p.tipo = 'mes' and p.estado = 'abierto' and v_hoy between p.desde and p.hasta;
  end if;
  if v_per is not null then
    begin
      -- (En el mes en curso no se avisa de lo que solo se cumple al terminar:
      -- el calendario, la conciliación al último día y la depreciación del
      -- mes; lo demás sí: un cargo sin clasificar, un control del libro en
      -- rojo, se ven la misma noche.)
      select coalesce(jsonb_agg(to_jsonb(x) || jsonb_build_object('periodo', v_per) order by x.orden), '[]'::jsonb)
        into v_rows
        from fn_cierre_revisar(v_per) x
       where not (x.orden in (15, 50, 92)
                  and exists (select 1 from periodos q where q.periodo = v_per and q.hasta >= v_hoy));
    exception when others then
      v_rows := jsonb_build_array(fn_cierre_fila(1, 'revisión: ' || v_per, 'detiene', false,
                  format('La revisión de %s falló: %s %s.', v_per, sqlstate, sqlerrm), 'Avisa.', 'cierre') || jsonb_build_object('periodo', v_per));
    end;
  end if;
  v_rows := v_rows || fn_ronda_globales();

  -- La corrida anterior (para saber qué rojo es nuevo).
  select max(corrida_el) into v_prev from ronda_resultados;

  -- Se escribe todo; cada rojo nuevo, al teléfono (uno por control).
  v_dueno := fn_cierre_dueno();
  v_push  := coalesce(cfg.aviso_push, true)
             and to_regprocedure('public.fn_cartero(jsonb)') is not null
             and coalesce(current_setting('mxp.cierre_sin_push', true), '') <> '1';
  perform set_config('mx_cierre.escribe', 'ronda_resultados', true);
  for r in select x->>'periodo' as periodo, (x->>'orden')::int as orden, x->>'control' as control, x->>'nivel' as nivel,
                  (x->>'ok')::boolean as ok, x->>'detalle' as detalle, x->>'que_hacer' as que_hacer, x->>'ir_a' as ir_a
             from jsonb_array_elements(v_rows) x
            order by (x->>'periodo') nulls last, (x->>'orden')::int loop
    declare
      v_nuevo   boolean := false;
      v_avisado boolean := false;
      v_fallo   boolean := false;
    begin
      if r.ok is distinct from true then
        v_rojos := v_rojos + 1;
        -- Nuevo: no estaba rojo en la corrida anterior, o lo estaba pero su
        -- aviso al teléfono falló (se reintenta hasta que salga).
        v_nuevo := v_prev is null
                   or not exists (select 1 from ronda_resultados q
                                   where q.corrida_el = v_prev and q.control = r.control
                                     and coalesce(q.periodo, '') = coalesce(r.periodo, '') and q.ok is distinct from true
                                     and not q.aviso_fallo);
        if v_nuevo and v_push then
          begin
            perform fn_cartero(jsonb_build_object(
              'titulo', 'Contabilidad: ' || left(r.control, 60),
              'cuerpo', left(concat_ws(' → ', r.detalle, r.que_hacer), 600),
              'para',   v_dueno));
            v_avisado := true;
            v_avisos  := v_avisos + 1;
          exception when others then
            v_fallo := true;
            raise warning 'fn_ronda: el aviso al teléfono no salió (%): %; la corrida siguiente lo reintenta', sqlstate, sqlerrm;
          end;
        end if;
      end if;
      insert into ronda_resultados (fecha, corrida_el, periodo, orden, control, nivel, ok, detalle, que_hacer, ir_a, avisado, aviso_fallo)
      values (v_hoy, v_t0, r.periodo, r.orden, r.control, r.nivel, r.ok, r.detalle, r.que_hacer, r.ir_a, v_avisado, v_fallo);
    end;
  end loop;
  perform set_config('mx_cierre.escribe', '', true);

  -- Se guardan 90 días.
  perform set_config('mx_cierre.escribe', 'ronda_resultados:limpieza', true);
  delete from ronda_resultados where fecha < v_hoy - 90;
  perform set_config('mx_cierre.escribe', '', true);

  return v_rojos;
end $$;
revoke execute on function public.fn_ronda() from public, anon, authenticated, service_role;
comment on function public.fn_ronda() is 'c9: la ronda nocturna (pg_cron, 11:45 UTC = 6:45 Miami en invierno, 7:45 en verano): revisa el período abierto más viejo que terminó (o el mes en curso) y los controles globales, escribe ronda_resultados (90 días), y manda al teléfono del dueño (fn_cartero) un aviso por cada rojo nuevo respecto de la corrida anterior. Sin API, sin IA. Devuelve cuántos controles salieron en rojo.';

-- La tarea de pg_cron, solo donde existe el esquema cron (producción). Se
-- vuelve a programar en cada pegado. 11:45 UTC: después de Plaid (11:00) y
-- del contador de la mañana (11:25); en Miami, 6:45 en invierno y 7:45 en
-- verano.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule(j.jobid) from cron.job j where j.jobname = 'mxp-ronda-contable';
    perform cron.schedule('mxp-ronda-contable', '45 11 * * *', 'select public.fn_ronda()');
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 11. Las vistas de la pantalla (security_invoker; leen solo tablas y
--     funciones de aquí): v_cierres, v_cierre_estado, v_ronda_ultima.
--     De periodos leen «estado» y «cadena_al_cerrar» de la fila entera
--     (to_jsonb) y no por su nombre, como c4 y c6: así una vista de c9 no
--     le cierra el paso al ALTER TABLE … TYPE que las pruebas de c2 hacen
--     sobre esas columnas (su prueba 24), y el tipo queda sin fijar.
-- ---------------------------------------------------------------------
drop view if exists public.v_cierre_estado;
drop view if exists public.v_cierres;
drop view if exists public.v_ronda_ultima;

create view public.v_cierres with (security_invoker = true) as
select c.periodo, p.tipo, p.anio, p.desde, p.hasta,
       c.cerrado_el, c.cerrado_por, pf.nombre as cerrado_por_nombre, c.cerrado_rol,
       (jsonb_path_query_first(to_jsonb(p), 'strict $.cadena_al_cerrar') #>> '{}') as cadena_al_cerrar,   -- (sin fijarle el tipo: ver 11)
       c.hash_mayor, c.asientos, c.lineas,
       (select count(*) from jsonb_array_elements(c.revision) x where x->>'nivel' = 'aviso' and (x->>'ok')::boolean is distinct from true) as avisos,
       c.revision,
       c.export_ruta, c.export_archivos, c.exportado_el, c.exportado_por, pe.nombre as exportado_por_nombre,
       (c.export_archivos is not null) as exportado,
       jsonb_array_length(c.export_historial) as exports_anteriores
  from public.cierres c
  join public.periodos p on p.periodo = c.periodo
  left join public.perfiles pf on pf.id = c.cerrado_por
  left join public.perfiles pe on pe.id = c.exportado_por;
revoke all on public.v_cierres from public, anon, authenticated, service_role;
grant select on public.v_cierres to authenticated;
comment on view public.v_cierres is 'c9: el historial de cierres: período, quién y cuándo (con el nombre), la foto de la cadena (c2), el hash del mayor, asientos y líneas, cuántos avisos quedaron, la revisión, y el export (carpeta, archivos con su sha256, cuándo, quién, cuántas veces antes).';

create view public.v_cierre_estado with (security_invoker = true) as
with hoy as (select public.fn_fecha_miami(now()) as d),
     sig as (select public.fn_cierre_siguiente() as periodo)
select p.periodo, p.tipo, p.anio, p.desde, p.hasta, pe.estado, p.paralelo,
       (p.hasta < hoy.d)                                        as terminado,
       (p.periodo = sig.periodo)                                as siguiente,
       case when pe.estado = 'cerrado' then 0 else rv.detienen end as detienen,
       case when pe.estado = 'cerrado'
            then (select count(*)::int from jsonb_array_elements(c.revision) x
                   where x->>'nivel' = 'aviso' and (x->>'ok')::boolean is distinct from true)
            else rv.avisos end                                  as avisos,
       case when pe.estado = 'cerrado' then c.cerrado_el else rv.revisado_el end as revisado_el,
       c.cerrado_el, c.cerrado_por, pf.nombre                   as cerrado_por_nombre,
       c.hash_mayor,
       c.export_ruta, (c.export_archivos is not null)           as exportado, c.exportado_el,
       public.fn_cierre_confirmacion(p.periodo)                 as confirmacion,
       public.fn_cierre_nombre(p.periodo)                       as nombre,
       p.periodo || '/'                                         as export_carpeta
  from public.periodos p
  cross join lateral (select (jsonb_path_query_first(to_jsonb(p), 'strict $.estado') #>> '{}') as estado) pe   -- (sin fijarle el tipo: ver 11)
  cross join hoy
  cross join sig
  left join public.cierres c on c.periodo = p.periodo
  left join public.cierre_revisiones rv on rv.periodo = p.periodo
  left join public.perfiles pf on pf.id = c.cerrado_por
 where p.tipo in ('apertura', 'mes');
revoke all on public.v_cierre_estado from public, anon, authenticated, service_role;
grant select on public.v_cierre_estado to authenticated;
comment on view public.v_cierre_estado is 'c9: una fila por período de tipo apertura o mes: estado, si ya terminó (hora de Miami), si es el siguiente que toca cerrar, cuántos controles que detienen y cuántos avisos están en rojo según la ÚLTIMA revisión guardada (revisado_el; la pantalla la refresca con fn_cierre_revisar), quién y cuándo lo cerró, su hash, su export, la confirmación exacta que pide fn_cierre_cerrar y la carpeta del bucket.';

create view public.v_ronda_ultima with (security_invoker = true) as
with u as (select max(r.corrida_el) as corrida_el from public.ronda_resultados r),
     t as (select r.corrida_el, r.fecha,
                  count(*) filter (where r.ok is distinct from true) as rojos,
                  count(*) filter (where r.ok is distinct from true and r.nivel = 'detiene') as detienen,
                  count(*) filter (where r.ok is distinct from true and r.nivel = 'aviso') as avisos,
                  count(*) filter (where r.avisado) as avisados,
                  count(*) as filas
             from public.ronda_resultados r join u on u.corrida_el = r.corrida_el
            group by r.corrida_el, r.fecha)
select t.fecha, t.corrida_el, t.rojos, t.detienen, t.avisos, t.avisados, t.filas,
       r.id, r.periodo, r.orden, r.control, r.nivel, r.ok, r.detalle, r.que_hacer, r.ir_a, r.avisado
  from t
  join public.ronda_resultados r on r.corrida_el = t.corrida_el
 order by r.periodo nulls last, r.orden;
revoke all on public.v_ronda_ultima from public, anon, authenticated, service_role;
grant select on public.v_ronda_ultima to authenticated;
comment on view public.v_ronda_ultima is 'c9: la última corrida de la ronda: en cada fila la fecha (Miami), la hora, cuántos rojos (detienen y avisos), cuántos se avisaron al teléfono y cuántas filas; y la fila misma (período, orden, control, nivel, ok, detalle, qué hacer, ir_a, avisado). Sin filas = la ronda no ha corrido.';


-- ---------------------------------------------------------------------
-- 12. Lo que debe verse al pegar: fn_cierre_pegado().
-- ---------------------------------------------------------------------
create or replace function public.fn_cierre_pegado() returns table (que text, detalle text)
language plpgsql
set search_path = public, pg_temp
as $$
declare
  c     cierre_config;
  v_sig text;
  v_det text;
  v_n   int;
  v_a   int;
  v_r   record;
begin
  if not fn_desde_editor() then
    raise exception using errcode = '42501', message = 'Esto se mira desde el SQL Editor.';
  end if;
  select * into c from cierre_config where id = 1;
  return query select 'cierre_config'::text,
                      format('ronda %s · reserva_pct %s · depreciación %s · aviso al teléfono %s',
                             case when c.ronda_activa then 'activa' else 'APAGADA' end,
                             coalesce(c.reserva_pct::text || ' %', 'sin fijar (lo dice el CPA)'), c.metodo_depreciacion,
                             case when c.aviso_push then 'sí' else 'no' end);
  return query select 'tablas'::text,
                      format('cierre_config, cierres (%s), cierre_revisiones (%s), ronda_resultados (%s filas, %s corridas), activos_fijos (%s), activos_depreciaciones (%s), reserva_estimados (%s)',
                             (select count(*) from cierres), (select count(*) from cierre_revisiones),
                             (select count(*) from ronda_resultados), (select count(distinct corrida_el) from ronda_resultados),
                             (select count(*) from activos_fijos), (select count(*) from activos_depreciaciones),
                             (select count(*) from reserva_estimados where anulado_el is null));
  return query select 'vistas'::text, 'v_cierre_estado, v_cierres, v_ronda_ultima, v_activos_fijos, v_reserva_impuestos, v_dr15_mes'::text;
  if to_regclass('storage.buckets') is not null then
    return query execute $q$
      select 'bucket cierres'::text,
             case when exists (select 1 from storage.buckets b where b.id = 'cierres') then 'existe (privado)' else 'NO se pudo crear: créalo en Storage' end
             || format(' · policies: %s de 4', (select count(*) from pg_policies pl where pl.schemaname = 'storage' and pl.tablename = 'objects' and pl.policyname like 'cierres: %')) $q$;
  else
    return query select 'bucket cierres'::text, 'sin Storage en esta base (en Supabase el bucket privado «cierres» se crea al pegar)'::text;
  end if;
  return query select 'períodos'::text,
                      (select string_agg(format('%s %s%s', e.periodo, e.estado,
                                                case when e.estado = 'abierto' and e.terminado then ' (terminó)'
                                                     when e.estado = 'cerrado' then ' (' || to_char(e.cerrado_el at time zone 'America/New_York', 'DD/MM') || ')'
                                                     else '' end), ' · ' order by e.desde)
                         from v_cierre_estado e where e.estado = 'cerrado' or e.terminado or e.siguiente);
  v_sig := fn_cierre_siguiente();
  if v_sig is null then
    return query select 'siguiente cierre'::text, 'nada abierto: todo cerrado'::text;
  else
    return query select 'siguiente cierre'::text, format('%s · confirmación: «%s»', fn_cierre_nombre(v_sig), fn_cierre_confirmacion(v_sig));
    begin
      select count(*) filter (where x.nivel = 'detiene' and x.ok is distinct from true),
             count(*) filter (where x.nivel = 'aviso' and x.ok is distinct from true),
             string_agg(x.control, '; ' order by x.orden) filter (where x.nivel = 'detiene' and x.ok is distinct from true)
        into v_n, v_a, v_det
        from fn_cierre_revisar(v_sig) x;
      return query select 'qué lo detiene hoy'::text,
                          case when v_n = 0 then format('nada: %s se puede cerrar (%s aviso(s))', fn_cierre_nombre(v_sig), v_a)
                               else format('%s control(es): %s (%s aviso(s)); la lista: select * from fn_cierre_revisar(%L);', v_n, v_det, v_a, v_sig) end;
    exception when others then
      return query select 'qué lo detiene hoy'::text, format('la revisión falló: %s %s', sqlstate, sqlerrm);
    end;
  end if;
  return query select 'activos fijos'::text,
                      case when not exists (select 1 from activos_fijos) then 'ninguno todavía (se cargan en f12 con la cédula del CPA: fn_activo_alta)'
                           else (select format('%s activo(s), %s vivos; depreciación posteada %s en %s mes(es)', count(*), count(*) filter (where v.estado = 'activo'),
                                               fn_cierre_usd(coalesce(sum(v.depreciado_libro), 0)), coalesce(max(v.meses_posteados), 0))
                                   from v_activos_fijos v) end;
  select * into v_r from v_reserva_impuestos;
  return query select 'reserva 1030'::text, left(v_r.mensaje, 400) || format(' · próximo estimado: %s (%s días)', v_r.proximo_estimado, v_r.dias_para_estimado);
  return query select 'ronda'::text,
                      format('%s · a las 11:45 UTC (hoy en Miami: %s de la mañana, tras Plaid y el contador) · última corrida: %s',
                             case when c.ronda_activa then 'activa' else 'APAGADA (fn_cierre_config)' end,
                             to_char((current_date + time '11:45') at time zone 'UTC' at time zone 'America/New_York', 'FMHH24:MI'),
                             coalesce((select to_char(max(r.corrida_el) at time zone 'America/New_York', 'DD/MM/YYYY HH24:MI') || ' (hora de Miami), '
                                              || (select count(*) from v_ronda_ultima where ok is distinct from true) || ' en rojo'
                                         from ronda_resultados r), 'nunca todavía'));
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    return query execute $q$ select 'ronda pg_cron'::text,
                                    coalesce((select j.jobname || ' (' || j.schedule || ')' from cron.job j where j.jobname = 'mxp-ronda-contable'), 'sin programar') $q$;
  else
    return query select 'ronda pg_cron'::text, 'sin pg_cron en esta base (en Supabase: Database → Extensions → pg_cron; la tarea se programa al pegar)'::text;
  end if;
  return query select 'siguiente paso'::text,
                      'pega docs/conta/c9-pruebas.sql; en la app, Contabilidad → Cierre: resuelve lo que detiene (la Bandeja, Conciliar al último día del mes, lo que diga «libro: permisos»), cierra la apertura («CERRAR LA APERTURA») y después octubre («CERRAR OCTUBRE 2026»), y «Exportar». La ronda corre sola cada mañana; lo que encuentre se ve al abrir.'::text;
end $$;
revoke execute on function public.fn_cierre_pegado() from public, anon, authenticated, service_role;
comment on function public.fn_cierre_pegado() is 'c9: lo que enseña el final del pegado: la configuración, las tablas y vistas, el bucket, el estado de cada período, el siguiente cierre y qué lo detiene hoy, los activos, la reserva, la ronda (pg_cron sí o no) y el paso siguiente.';

select * from public.fn_cierre_pegado();
