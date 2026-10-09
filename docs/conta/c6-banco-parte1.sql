-- =====================================================================
-- C6 · EL BANCO — c6-banco.sql, PARTE 1 DE 2 (marca 2026100901).
-- GENERADA por pruebas/conta/partir-c6.py desde docs/conta/c6-banco.sql:
-- no se edita a mano. Es lo mismo que el archivo entero, en dos pegados,
-- para cuando el SQL Editor de Supabase no deja pegarlo de una vez. La
-- historia y el porqué de cada cosa están en c6-banco.sql.
--   1. Pega c6-banco-parte1.sql y ejecuta (dice «ahora la parte 2»).
--   2. Pega c6-banco-parte2.sql y ejecuta: termina con el resumen corto de
--      siempre, todo en true.
-- La parte 2 sin la parte 1 de esta misma marca para con MX000 y no toca
-- nada. Cada una se puede pegar otra vez. Entre las dos el banco queda a
-- medias (sus huellas sin sellar: el control lo dice en rojo): no uses la
-- app del banco hasta pegar la 2.
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
--     ESTE ARCHIVO NECESITA: sus marcas (fn_libro_version y
--     fn_estados_version al menos 2026100201, las de la ronda 4;
--     fn_puente_version al menos 2026092601). Con uno anterior faltan cosas
--     de verdad (el reparto de c2 que conoce las funciones de aquí y su
--     sellador que no bendice un candado cambiado, la guarda de c3 que deja
--     des-casar un cobro, el papel de los asientos del banco en c4, y los
--     controles de c2 y c4 que no releen en cada llamada lo que este
--     archivo selló, y el de c4 que para por reloj antes del tope de la
--     API): se dice qué volver a pegar.
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
             from (values ('fn_libro_version()', 2026100201::bigint, 'c2-libro.sql'),
                          ('fn_puente_version()', 2026092601::bigint, 'c3-puentes.sql'),
                          ('fn_estados_version()', 2026100201::bigint, 'c4-estados.sql')) as q(fn, minimo, archivo) loop
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
                                 ('banco_historial', 'despues'), ('banco_cuentas_personales', 'nombre')) as v(tabla, columna)
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
as $$ select 2026100901::bigint $$;
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
-- 1.2b · banco_cuentas_personales — (ronda 4b) las cuentas PERSONALES de
-- Edgar (el accionista) que él da de alta A PROPÓSITO, por sus 4 últimos:
-- su cuenta de Chase ····7781, una de ahorro en otro banco. Es lo único
-- que hace de un número «la cuenta personal de Edgar». El dinero que va y
-- viene de una de ellas es patrimonio del accionista (2900 préstamo del
-- accionista, 3100 aportación, 3200 distribución, 1130 préstamo al
-- accionista): en una S-corp cuenta para su base y sus distribuciones, y
-- solo cuando el banco nombra una cuenta dada de alta aquí sus botones
-- entran sin motivo. Un número que el banco todavía no conoce (la reserva
-- 1030 recién abierta antes de su primer estado de cuenta, una tarjeta
-- nueva, la línea de crédito, un préstamo, una cuenta de ahorro en otro
-- banco) NO es personal por defecto: se reconoce como cuenta propia (su
-- estado de cuenta, el lote que lo confirma, fn_tarjeta_alta o el mapeo
-- de QuickBooks) o se pregunta, con su motivo. Antes todo número que no
-- era de la empresa se daba por personal: el primer pase a la reserva
-- salía «distribución · 3200» sin motivo, y el depósito desde la personal
-- del mismo monto que una factura dejaba el control en rojo al pulsar su
-- botón. Se da de alta (y de baja, con su motivo) con
-- fn_banco_cuenta_personal, desde el SQL Editor; queda en banco_historial,
-- y el control la mira (cuadre 53) como a los descriptores.
-- ---------------------------------------------------------------------
create table if not exists public.banco_cuentas_personales (
  ultimos4     text        primary key,
  nombre       text        not null,
  activa       boolean     not null default true,
  motivo       text,
  creado_por   uuid,
  creado_rol   text,
  creado_el    timestamptz not null default now(),
  cambiado_por uuid,
  cambiado_rol text,
  cambiado_el  timestamptz,
  constraint banco_cuentas_personales_ultimos4 check (ultimos4 ~ '^[0-9]{4}$'),
  constraint banco_cuentas_personales_nombre   check (btrim(nombre) <> ''),
  constraint banco_cuentas_personales_baja     check (activa or coalesce(btrim(motivo), '') <> '')
);

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
-- se edita ni se borra. (Ronda 4: también «quitada:<id>», la marca de que
-- el archivo o el lote de su archivo_id dijo que ese movimiento se quita:
-- CORRECTACTION DELETE, o las «quitadas» de Plaid.)
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
-- (Ronda 4: la marca de lo que el banco borró o Plaid quitó, «quitada:<id>»,
-- con el archivo que lo dijo. Son pocas: la bandeja y el control las buscan
-- por aquí.)
create index if not exists movimientos_banco_ids_quitada_idx on public.movimientos_banco_ids (movimiento_id)
  where id_externo like 'quitada:%';

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
  otro_lado       jsonb,
  constraint banco_casados_clase    check (clase in ('recibo', 'cobro', 'devolucion', 'transferencia', 'pago_proveedor',
                                                     'cuota_prestamo', 'regla', 'clasificado', 'asiento', 'apertura')),
  constraint banco_casados_asiento  check ((clase = 'apertura') = (asiento_id is null)),
  constraint banco_casados_deshecho check ((deshecho_el is null) = (deshecho_motivo is null)
                                           and (deshecho_motivo is null or btrim(deshecho_motivo) <> ''))
);
-- (Ronda 4d) otro_lado: lo que decía el banco del otro lado AL CASARLO (EL
-- CRITERIO, fn_banco_otro_lado: una cuenta de la empresa, la personal de
-- Edgar dada de alta, un número que no se conocía…), para el rastro y para
-- EL CONTROL: lo casado con la cuenta personal de Edgar cuando lo era no
-- se pone en rojo si después la da de baja (la cerró). Y su motivo (el de
-- arriba) se puede escribir UNA vez después, en un casado vivo que no lo
-- tenía (fn_banco_casar_con con {"casado": …}: «es correcto, por esto»),
-- con su rastro. Encima de una versión anterior, la columna se añade al
-- final (vacía en lo ya casado: vale lo que dice el banco hoy).
do $$
begin
  if not exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = 'banco_casados' and c.column_name = 'otro_lado') then
    alter table public.banco_casados add column otro_lado jsonb;
  end if;
end $$;
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
--   cuotas_al_anio  (ronda 5) cuántas cuotas tiene el año: 12 mensual, 52
--                semanal, 26 cada dos semanas, 24 quincenal (dos al mes), 6,
--                4, 2, 1. La fórmula parte el interés por período (tasa /
--                cuotas_al_anio), la porción corriente es el capital de las
--                próximas cuotas_al_anio cuotas y «a días de la cuota
--                anterior» se mide con el período. Las de antes: 12.
--   plazo_meses  el número de cuotas del préstamo (el nombre viene de los
--                mensuales: 84 en uno de siete años; en uno semanal, sus
--                semanas). dia_pago, el día del mes de la cuota en uno
--                mensual; en los demás, el del primer pago, y solo se
--                guarda. Ninguno de los dos entra en una cifra.
-- Cada cuota es un papel (prestamo_cuotas): su fecha, lo pagado, la
-- partición capital/interés y de dónde salió (la fórmula, o el statement
-- del prestamista, que manda), el saldo antes y después, su asiento y su
-- movimiento del banco (movimiento_id: la registrada antes que el banco lo
-- toma al casarla y lo suelta al des-casarla; ronda 5). Una cuota no se
-- edita: se anula (des-casando su movimiento; sin él, con
-- fn_prestamo_cuota_anular, de la última hacia atrás) y se registra la
-- buena.
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
  cuotas_al_anio   int           not null default 12,
  constraint prestamos_cuotas_al_anio check (cuotas_al_anio in (1, 2, 4, 6, 12, 24, 26, 52)),
  constraint prestamos_prestamista check (btrim(prestamista) <> ''),
  constraint prestamos_montos      check (principal > 0 and cuota > 0 and saldo_inicial >= 0 and saldo_inicial <= principal
                                          and tasa_anual >= 0 and tasa_anual < 100),
  constraint prestamos_dia         check (dia_pago between 1 and 31),
  constraint prestamos_plazo       check (plazo_meses is null or plazo_meses > 0),
  constraint prestamos_estado      check (estado in ('vigente', 'pagado', 'cancelado'))
);

-- (Ronda 5) La columna nueva en una base que ya tenía la tabla: las de
-- antes quedan en 12 (mensuales, como se calculaban).
do $$
begin
  if not exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = 'prestamos' and c.column_name = 'cuotas_al_anio') then
    alter table public.prestamos add column cuotas_al_anio int not null default 12;
  end if;
  if not exists (select 1 from pg_constraint k where k.conname = 'prestamos_cuotas_al_anio' and k.conrelid = 'public.prestamos'::regclass) then
    alter table public.prestamos add constraint prestamos_cuotas_al_anio check (cuotas_al_anio in (1, 2, 4, 6, 12, 24, 26, 52));
  end if;
end $$;

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
                         when 'banco_cuentas_personales' then 'una cuenta personal de Edgar se da de baja con su motivo '
                                                              '(fn_banco_cuenta_personal) y queda.'
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
    -- (Ronda 4d) Su motivo, UNA vez, en un casado vivo que no lo tenía
    -- (fn_banco_casar_con con {"casado": …}: EL CONTROL lo pedía); lo
    -- demás, igual. Queda en banco_historial.
    if v_marca = 'motivo:' || old.id and old.deshecho_el is null and fn_banco_limpio(old.motivo) is null
       and fn_banco_limpio(new.motivo) is not null and (to_jsonb(new) - 'motivo') = (to_jsonb(old) - 'motivo') then
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
    -- (Ronda 5) La cuota registrada antes que el banco toma su cargo al
    -- casarla (fn_banco_casar_lineas) y lo suelta al des-casarla
    -- (fn_banco_descasar_interno): solo movimiento_id, con la marca y la
    -- cuota viva. Antes se quedaba sin él, y v_prestamos la decía «sin
    -- cargo» con el cargo casado.
    if v_marca = 'cuota:' || old.id and old.anulada_el is null and new.anulada_el is null
       and new.movimiento_id is distinct from old.movimiento_id
       and (to_jsonb(new) - 'movimiento_id') = (to_jsonb(old) - 'movimiento_id') then
      return new;
    end if;
    raise exception using errcode = 'MX003',
      message = 'Una cuota no se edita: se anula des-casando su movimiento (fn_banco_descasar) o, sin él, con '
                'fn_prestamo_cuota_anular (SQL Editor), y se registra la buena.';

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

  -- (Ronda 4b) Las cuentas personales de Edgar: solo fn_banco_cuenta_personal
  -- (la marca de su número), con quién y cuándo; el número no cambia.
  when 'banco_cuentas_personales' then
    if v_marca = 'personal:' || new.ultimos4 then
      if tg_op = 'INSERT' then
        new.creado_por := auth.uid();
        new.creado_rol := fn_rol_llamante();
        new.creado_el  := clock_timestamp();
        new.cambiado_por := null;
        new.cambiado_rol := null;
        new.cambiado_el  := null;
      else
        if new.ultimos4 <> old.ultimos4 or new.creado_el is distinct from old.creado_el
           or new.creado_por is distinct from old.creado_por or new.creado_rol is distinct from old.creado_rol then
          raise exception using errcode = 'MX003', message = 'Una cuenta personal no cambia de número ni de alta.';
        end if;
        new.cambiado_por := auth.uid();
        new.cambiado_rol := fn_rol_llamante();
        new.cambiado_el  := clock_timestamp();
      end if;
      return new;
    end if;
    raise exception using errcode = 'MX003',
      message = 'Una cuenta personal de Edgar se da de alta y de baja con fn_banco_cuenta_personal, desde el SQL Editor (con rastro).';

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
             ('banco_cuentas_personales',  'ultimos4'),
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
                           'prestamo_cuotas', 'prepagados', 'prepagados_amortizaciones', 'banco_cuentas_personales'] loop
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
-- (Ronda 4) TRES COSAS DEL FORMATO que antes se dejaban pasar calladas:
--   · los comentarios (<!-- … -->) se quitan, y un texto en CDATA (OFX 2.x:
--     <NAME><![CDATA[ONLINE TRANSFER … & SAV]]></NAME>) se lee entero, con
--     su «&» y su «<» (antes la descripción quedaba vacía y la MEMO, cortada:
--     el descriptor, la llave y los duplicados se quedaban sin el nombre);
--   · un movimiento en OTRA moneda (<CURRENCY> con CURSYM distinto del de
--     la cuenta) para con MX009, como CURDEF (antes 136.00 CAD entraban como
--     dólares). <ORIGCURRENCY> no: ese monto ya viene convertido;
--   · la CORRECCIÓN del banco (CORRECTFITID y CORRECTACTION): REPLACE va en
--     la fila («corrige»: el importador la mete marcada «posible duplicado»
--     del corregido, nunca como otro cargo callado); DELETE no es un
--     movimiento: va aparte («borradas»: el importador quita el corregido,
--     ver 3), y su fila no entra (cuenta como fuera). Antes la corrección
--     entraba como un cargo más y el borrado seguía vivo.
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
  v_cdata   text[];
  v_cur     text;
  v_corr    text;
  v_cfit    text;
  v_borra   jsonb[] := '{}';
  v_nf      int := 0;
begin
  if fn_banco_limpio(v_txt) is null then
    raise exception using errcode = 'MX009', message = 'El archivo está vacío.';
  end if;
  -- (Ronda 4) Los comentarios fuera, y cada CDATA con su texto entero (sus
  -- «&», «<» y «>» como entidades, que se resuelven al leer el valor). Solo
  -- si los hay: un QFX de Chase o de Amex no los trae.
  if position('<!--' in v_txt) > 0 then
    v_txt := regexp_replace(v_txt, '<!--.*?-->', '', 'g');
  end if;
  if position('<![CDATA[' in v_txt) > 0 then
    for v_cdata in select regexp_matches(v_txt, '<!\[CDATA\[(.*?)\]\]>', 'g') loop
      v_txt := replace(v_txt, '<![CDATA[' || v_cdata[1] || ']]>',
                       replace(replace(replace(v_cdata[1], '&', '&amp;'), '<', '&lt;'), '>', '&gt;'));
    end loop;
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
    -- (Ronda 4) Un movimiento en OTRA moneda (<CURRENCY>, no <ORIGCURRENCY>,
    -- que ya viene convertido): el libro va en dólares, y su monto no lo es.
    if v_pieza ~* '<CURRENCY>' then
      v_cur := upper(fn_banco_ofx_valor(substring(v_pieza from '(?i)<CURRENCY>(.*?)(?:</CURRENCY>|$)'), 'CURSYM'));
      if v_cur is not null and v_cur <> coalesce(v_moneda, 'USD') then
        raise exception using errcode = 'MX009',
          message = format('El archivo no se puede leer: el movimiento %s («%s», %s) está en %s (CURRENCY, al cambio %s), no en %s: el '
                           'libro va en dólares. Descarga el estado de cuenta con los montos en dólares, o pide al banco el '
                           'movimiento convertido.', v_n, coalesce(v_el->>'NAME', v_el->>'MEMO', 'sin nombre'), v_m, v_cur,
                           coalesce(fn_banco_ofx_valor(substring(v_pieza from '(?i)<CURRENCY>(.*?)(?:</CURRENCY>|$)'), 'CURRATE'), '¿?'),
                           coalesce(v_moneda, 'USD'));
      end if;
    end if;
    -- (Ronda 4) La CORRECCIÓN del banco: CORRECTFITID dice cuál corrige, y
    -- CORRECTACTION cómo (REPLACE: esta fila lo sustituye; DELETE: lo borra).
    v_corr := upper(v_el->>'CORRECTACTION');
    v_cfit := v_el->>'CORRECTFITID';
    if v_corr is not null or v_cfit is not null then
      if v_cfit is null or v_corr is null or v_corr not in ('REPLACE', 'DELETE') then
        raise exception using errcode = 'MX009',
          message = format('El archivo no se puede leer: el movimiento %s corrige otro, pero no dice cuál o cómo (CORRECTFITID «%s», '
                           'CORRECTACTION «%s»: el banco corrige con REPLACE o DELETE).', v_n, coalesce(v_cfit, ''), coalesce(v_corr, ''));
      end if;
    end if;
    if v_corr = 'DELETE' then
      -- (no es un movimiento: dice que el corregido no fue; va aparte)
      v_borra := v_borra || jsonb_strip_nulls(jsonb_build_object(
        'n', v_n, 'id', v_el->>'FITID', 'corrige', v_cfit, 'fecha', v_fp, 'monto', v_m::text, 'descripcion', v_el->>'NAME'));
      continue;
    end if;
    -- (Los signos: un cargo sale en negativo y un abono en positivo. Si
    -- casi todos vienen al revés de su tipo, se avisa.)
    if v_tt in ('DEBIT', 'CHECK', 'FEE', 'SRVCHG', 'ATM', 'POS', 'DIRECTDEBIT', 'CREDIT', 'DEP', 'DIRECTDEP', 'INT', 'DIV') then
      v_tipados := v_tipados + 1;
      if (v_tt in ('DEBIT', 'CHECK', 'FEE', 'SRVCHG', 'ATM', 'POS', 'DIRECTDEBIT') and v_m > 0)
         or (v_tt in ('CREDIT', 'DEP', 'DIRECTDEP', 'INT', 'DIV') and v_m < 0) then
        v_raros := v_raros + 1;
      end if;
    end if;
    v_nf := v_nf + 1;
    v_filas[v_nf] := jsonb_strip_nulls(jsonb_build_object(
      'n', v_n, 'tipo', v_tt, 'fecha', v_fp, 'fecha_transaccion', v_fu, 'monto', v_m::text,
      'id', v_el->>'FITID', 'cheque', v_el->>'CHECKNUM', 'descripcion', v_el->>'NAME', 'memo', v_el->>'MEMO',
      'corrige', case when v_corr = 'REPLACE' then v_cfit end));
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
    'avisos', v_avisos, 'filas', to_jsonb(v_filas),
    'borradas', case when cardinality(v_borra) > 0 then to_jsonb(v_borra) end));
end $$;
revoke execute on function public.fn_banco_ofx_leer(text) from public, anon, authenticated, service_role;

-- La caja chica (el efectivo en la mano, sin estado de cuenta): la cuenta
-- de la forma de pago «efectivo» de c3 (1050).
-- (Ronda 4b: en plpgsql, como fn_banco_es_propia y fn_banco_tipo_cuenta
-- de abajo, con la misma respuesta. Una función «language sql» que no se
-- mete dentro de la consulta —ninguna de este archivo: todas llevan su
-- search_path— se vuelve a leer y a planear en CADA consulta que la llama;
-- estas tres se llaman miles de veces (el tipo de cada cuenta propia, en
-- cada «Casar» y en cada contexto de las propuestas). En plpgsql el plan
-- queda guardado.)
create or replace function public.fn_banco_caja()
returns text
language plpgsql
stable
set search_path = public, pg_temp
as $$
begin
  return coalesce((select m.cuenta from mapeo_metodo_pago m where m.forma = 'efectivo' and m.cuenta is not null
                    order by m.confirmado_el desc nulls last limit 1), '1050');
end $$;
revoke execute on function public.fn_banco_caja() from public, anon, authenticated, service_role;

-- ¿Es una cuenta PROPIA con estado de cuenta? Un banco (10xx, de activo,
-- sin obra: 1010, 1030…), salvo la caja chica; o una tarjeta de la empresa
-- (una subcuenta de 2100, Tarjetas de crédito, de la tabla tarjetas:
-- 2100-2013, 2100-2009). Entre dos de estas, el mismo dinero es una
-- transferencia. (Ronda 4b: solo las subcuentas de 2100, como el
-- importador, fn_banco_cuenta_de. Antes una tarjeta dada de alta en otro
-- pasivo —la personal de Edgar en 2900, para sus tickets— hacía de 2900 una
-- «tarjeta propia»: la bandeja ofrecía «A 2900» como transferencia, sin
-- motivo, y su lado quedaba «en tránsito» para siempre.)
-- (Ronda 4b: en plpgsql —ver fn_banco_caja—. Las dos preguntas, en el
-- mismo orden y con la misma respuesta: ninguna da nulo, así que el
-- coalesce de antes no hacía nada. El banco se pregunta en una expresión
-- simple: así la función de c3 se lee una vez por transacción y no una
-- por cuenta.)
create or replace function public.fn_banco_es_propia(p_cuenta text)
returns boolean
language plpgsql
stable
set search_path = public, pg_temp
as $$
begin
  if fn_puente_es_banco(p_cuenta) and p_cuenta is distinct from fn_banco_caja() then
    return true;
  end if;
  return exists (select 1 from tarjetas t join cuentas c on c.codigo = t.cuenta
                  where t.cuenta = p_cuenta and left(t.cuenta, 5) = '2100-' and c.tipo = 'pasivo'
                    and c.saldo_normal = 'haber');
end $$;
revoke execute on function public.fn_banco_es_propia(text) from public, anon, authenticated, service_role;

-- ¿Una cuenta del banco (activo) o de tarjeta (pasivo)? 'banco', 'tarjeta'
-- o nulo si no es propia (la caja chica no tiene estado de cuenta: su
-- «conciliación» es contar el efectivo).
-- (Ronda 4b: en plpgsql, la misma expresión —ver fn_banco_caja—.)
create or replace function public.fn_banco_tipo_cuenta(p_cuenta text)
returns text
language plpgsql
stable
set search_path = public, pg_temp
as $$
begin
  return case when fn_puente_es_banco(p_cuenta) and p_cuenta is distinct from fn_banco_caja() then 'banco'
              when fn_banco_es_propia(p_cuenta) then 'tarjeta' end;
end $$;
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
-- XXXX1234»), o nulo.
create or replace function public.fn_banco_otra_cuenta(p_dn text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select right(substring(coalesce(p_dn, '') from '(?:^| )(?:CHK|CHECKING|SAV|SAVINGS|ACCT|ACCOUNT|DDA|MMA) X*([0-9]{4,})(?: |$)'), 4)
$$;
revoke execute on function public.fn_banco_otra_cuenta(text) from public, anon, authenticated, service_role;

-- (Ronda 4b) LOS 4 ÚLTIMOS DE LA TARJETA que nombra el PAGO de una tarjeta
-- visto en el banco («PAYMENT TO CHASE CARD ENDING IN 5555», «CARD
-- XXXX5555», «CRD 5555»), o nulo. Solo del lado que paga: en la tarjeta,
-- «ENDING IN …» puede ser su propio número. Una tarjeta nueva antes de su
-- primer statement también es un número que se reconoce o se pregunta:
-- antes su pago salía «A 2100-2013» o a cualquier tarjeta, sin motivo.
create or replace function public.fn_banco_otra_tarjeta(p_dn text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select right(coalesce(substring(coalesce(p_dn, '') from '(?:^| )(?:CARD|CRD)(?: ENDING(?: IN)?| NO| #)? X*([0-9]{4,})(?: |$)'),
                        substring(coalesce(p_dn, '') from '(?:^| )ENDING(?: IN)? X*([0-9]{4})(?: |$)')), 4)
$$;
revoke execute on function public.fn_banco_otra_tarjeta(text) from public, anon, authenticated, service_role;

-- DE QUÉ CUENTA DE LA EMPRESA ES UN NÚMERO (sus 4 últimos), o nulo: solo
-- de una cuenta PROPIA con estado de cuenta (fn_banco_es_propia), por lo
-- que la reconoce: una tarjeta activa de la empresa dada de alta (o la
-- débito de un banco); un banco cuyos estados de cuenta de verdad lo traen
-- (un OFX, o el lote con que Edgar lo confirmó: «confirmo_cuenta», que sirve
-- también para dar de alta el número de la reserva ANTES de su primer
-- estado de cuenta); o (ronda 4b) el nombre con que la trae QuickBooks en el
-- mapeo de la apertura («Chase Chk 4392» es 1010). No un código del plan que
-- se le parezca. Una tarjeta dada de alta en otro pasivo (la personal de
-- Edgar en 2900) no es de la empresa: ver fn_banco_personal_de.
-- (Ronda 4d) Del nombre de QuickBooks, solo el número que va CON el nombre
-- de la cuenta («Chase Chk 4392», «Amex Gold (1007)»): un nombre que es
-- solo cifras («1007», así trae QuickBooks la Gold de Edgar) es el número
-- con que QuickBooks numera esa cuenta en su plan, no el de su banco. Antes
-- hacía de ····1007 un número de la Gold: un pase a una cuenta ····1007 de
-- otro salía como dinero a la tarjeta de la empresa, y una cuenta personal
-- ····1007 no se podía dar de alta (MX004).
create or replace function public.fn_banco_numero_de(p_u4 text)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce((select t.cuenta from tarjetas t
                    where t.ultimos4 = p_u4 and t.activa and fn_banco_es_propia(t.cuenta) order by t.cuenta limit 1),
                  (select a.cuenta from archivos_banco a
                    where a.ultimos4 = p_u4 and a.retirado_el is null and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada)
                    order by a.importado_el desc limit 1),
                  (select m.cuenta from apertura_mapeo_qb m
                    where m.tipo = 'cuenta' and m.cuenta is not null and fn_banco_es_propia(m.cuenta)
                      and m.nombre_qb ~ ('(^|[^0-9])' || p_u4 || '([^0-9]|$)')
                      and m.nombre_qb !~ '^[[:space:][:punct:]]*[0-9]+[[:space:][:punct:]]*$'
                    order by m.cuenta limit 1))
   where p_u4 ~ '^[0-9]{4}$'
$$;
revoke execute on function public.fn_banco_numero_de(text) from public, anon, authenticated, service_role;

-- (Ronda 4b) ¿ES UNA CUENTA PERSONAL DE EDGAR que él dio de alta A
-- PROPÓSITO? Su nombre, o nulo. La de banco_cuentas_personales (activa), o
-- su tarjeta personal dada de alta en c3 en la cuenta del accionista (2900,
-- para que sus tickets de la empresa vayan a «préstamo del accionista").
-- Nada más: un número que no se conoce no es personal por defecto.
create or replace function public.fn_banco_personal_de(p_u4 text)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce((select p.nombre from banco_cuentas_personales p where p.ultimos4 = p_u4 and p.activa),
                  (select format('%s (su tarjeta personal, dada de alta en %s)', t.titular, t.cuenta)
                     from tarjetas t join cuentas c on c.codigo = t.cuenta
                    where t.ultimos4 = p_u4 and t.activa and c.tipo = 'pasivo' and c.etiqueta_fiscal = 'accionista'
                    order by t.cuenta limit 1))
   where p_u4 ~ '^[0-9]{4}$'
$$;
revoke execute on function public.fn_banco_personal_de(text) from public, anon, authenticated, service_role;

-- (Ronda 4c) ¿UNA DEUDA DE LA EMPRESA CON UN BANCO? La línea de crédito
-- (2510) y los préstamos (2520, 2530): las cuentas 25xx de pasivo del plan
-- de c1, imputables y que no son del accionista. No traen estado de cuenta
-- a esta app (su saldo lo llevan sus cuotas y sus desembolsos), pero el
-- banco nombra su número cuando el dinero va o viene de ellas («ONLINE
-- TRANSFER FROM ACCT ...8899»). Ese número se da de alta como de la
-- empresa con un lote vacío a su cuenta (fn_banco_importar_filas con
-- "confirmo_cuenta": true y "filas": []), como la reserva antes de su
-- primer estado de cuenta, y EL CRITERIO (fn_banco_otro_lado) lo reconoce:
-- «propia», de tipo «deuda». Antes la bandeja lo aconsejaba y el lote daba
-- MX004 («no es una cuenta de banco ni una tarjeta»): la línea de crédito
-- no se reconocía nunca.
create or replace function public.fn_banco_es_deuda(p_cuenta text)
returns boolean
language plpgsql
stable
set search_path = public, pg_temp
as $$
begin
  return exists (select 1 from cuentas c
                  where c.codigo = p_cuenta and left(c.codigo, 2) = '25' and c.tipo = 'pasivo' and c.imputable
                    and coalesce(c.etiqueta_fiscal, '') not in ('accionista', 'distribucion'));
end $$;
revoke execute on function public.fn_banco_es_deuda(text) from public, anon, authenticated, service_role;

-- (Ronda 4c) ¿A QUIÉN NOMBRA la descripción del banco (NAME, normalizada)?
-- Las palabras que quedan, en una línea, quitadas las del banco (las de
-- fn_banco_nombra_alguien) y las de una transferencia entre cuentas (SAV,
-- MMA, BOOK, MONEY MARKET, REALTIME, BANKING…); nulo si no queda ninguna.
-- «ONLINE TRANSFER TO SAVINGS» no nombra a nadie; «ONLINE TRANSFER TO EDGAR
-- M PERSONAL» nombra a «EDGAR PERSONAL»; «HOME DEPOT 6345», a «HOME
-- DEPOT». La usa EL CRITERIO: una transferencia SIN número que nombra a
-- alguien no se supone entre cuentas propias (se pregunta), y un lado que
-- nombra a alguien no casa solo con el otro lado de una transferencia.
-- (Su lista es la de fn_banco_nombra_alguien más las de una transferencia:
-- aquella decide si un pago es «sin nombre» y no cambia. Escrita palabra
-- por palabra en plpgsql, con la lista en una expresión regular: con la
-- consulta de aquella costaba un tercio de cada llamada a EL CRITERIO.)
create or replace function public.fn_banco_nombrado(p_dn text)
returns text
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  -- (las palabras del banco —las de fn_banco_nombra_alguien— y las de una
  -- transferencia entre cuentas: «TO SAV», «MONEY MARKET», «ONLINE BANKING
  -- TRANSFER», «REALTIME»…)
  v_banco constant text := '^(' || 'CHECK|CHK|CHEQUE|ACH|DEBIT|DEBITO|CREDIT|PAYMENT|PAYMENTS|PMT|PYMT|PMNT|ONLINE|BILL|BILLPAY|PAY|WEB|PPD|'
                             || 'CCD|TEL|IND|INDN|DES|ENTRY|DESCR|DESC|SEC|FROM|FOR|THE|DIRECT|DEP|DEPOSIT|EPAY|EPAYMENT|WIRE|TRANSFER|'
                             || 'XFER|OUTGOING|INCOMING|OUT|WITHDRAWAL|WITHDRAW|POS|PURCHASE|CARD|RECURRING|AUTOPAY|AUTO|ELECTRONIC|ORIG|'
                             || 'TRN|REF|CONF|CONFIRMATION|TRACE|EFT|ZELLE|NAME|DATE|EED|NUM|NUMBER|TRANSACTION|ITEM|FEE|SERVICE|BANK|'
                             || 'ORDER|MOBILE|EXTERNAL|INTERNAL|SENT|ACCOUNT|ACCT|SAVINGS|CHECKING|PAID|BUSINESS|COMPANY|AND|TO|ID|CO|NO|'
                             || 'NR|OF|ON|IN|AT|BY|DR|CR|AM|PM|XX|SAV|SAVING|MMA|MMK|DDA|BOOK|MONEY|MARKET|SHARE|DRAFT|REALTIME|SCHEDULED|'
                             || 'DOMESTIC|VIA|BANKING|REFERENCE|SAME|DAY' || ')$';
  v_pal   text[];
  v_out   text[] := '{}';
  i       int;
begin
  if coalesce(p_dn, '') = '' then
    return null;
  end if;
  -- (cada palabra, sin «&» ni «#» —AT&T es ATT, TRACE# es TRACE—)
  v_pal := regexp_split_to_array(regexp_replace(p_dn, '[&#]', '', 'g'), ' ');
  for i in 1 .. coalesce(array_length(v_pal, 1), 0) loop
    if v_pal[i] ~ '^[[:alpha:]]{2,}$'
       and (v_pal[i] !~ v_banco
            -- (BANK o MOBILE detrás de un nombre: US BANK, T MOBILE)
            or (v_pal[i] in ('BANK', 'MOBILE') and i > 1 and v_pal[i - 1] ~ '^[[:alpha:]]+$' and v_pal[i - 1] !~ v_banco)) then
      v_out := v_out || v_pal[i];
    end if;
  end loop;
  return nullif(array_to_string(v_out, ' '), '');
end $$;
revoke execute on function public.fn_banco_nombrado(text) from public, anon, authenticated, service_role;

-- (Ronda 4d) EL EMISOR DE UNA TARJETA que nombra un texto (el pago de una
-- tarjeta visto en el banco: «AMEX EPAYMENT», «CHASE CREDIT CRD AUTOPAY»,
-- «BANK OF AMERICA CREDIT CARD BILL PAYMENT»; o el nombre de una tarjeta de
-- la empresa: «Amex Business Gold»), en una palabra fija, o nulo si no
-- nombra ninguno de los que se conocen. Chase va el último: es también el
-- banco de Edgar, y su nombre sale en sus propias descripciones.
create or replace function public.fn_banco_emisor(p_txt text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
           when x.p ~ '(^| )(AMEX|AMERICAN EXPRESS)( |$)' then 'AMERICAN EXPRESS'
           when x.p ~ '(^| )(BANK OF AMERICA|BK OF AMER|BK OF AMERICA|BOFA)( |$)' then 'BANK OF AMERICA'
           when x.p ~ '(^| )(CAPITAL ONE|CAPITALONE|CAP ONE)( |$)' then 'CAPITAL ONE'
           when x.p ~ '(^| )(CITI|CITIBANK|CITICARD|CITICARDS|CITI CARD)( |$)' then 'CITI'
           when x.p ~ '(^| )DISCOVER( |$)' then 'DISCOVER'
           when x.p ~ '(^| )WELLS FARGO( |$)' then 'WELLS FARGO'
           when x.p ~ '(^| )(BARCLAYS|BARCLAYCARD|BARCLAY)( |$)' then 'BARCLAYS'
           when x.p ~ '(^| )(US BANK|U S BANK|USBANK)( |$)' then 'US BANK'
           when x.p ~ '(^| )(SYNCHRONY|SYNCB)( |$)' then 'SYNCHRONY'
           when x.p ~ '(^| )(APPLE CARD|APPLECARD|GOLDMAN SACHS|GS BANK)( |$)' then 'APPLE CARD'
           when x.p ~ '(^| )(NAVY FEDERAL|NAVY FCU|NAVY FED)( |$)' then 'NAVY FEDERAL'
           when x.p ~ '(^| )(CHASE|JPMORGAN CHASE)( |$)' then 'CHASE'
         end
    from (select fn_banco_norm(p_txt) as p) x
$$;
revoke execute on function public.fn_banco_emisor(text) from public, anon, authenticated, service_role;

-- (Ronda 4d) LOS EMISORES DE LAS TARJETAS DE LA EMPRESA, por lo que dicen
-- su cuenta del plan y su alta (las de Edgar: «Amex Business Gold» y «Amex
-- Business Blue», American Express). Vacío si no se sabe el de ninguna: EL
-- CRITERIO no supone nada entonces.
create or replace function public.fn_banco_emisores_propios()
returns text[]
language plpgsql
stable
set search_path = public, pg_temp
as $$
begin
  return coalesce((select array_agg(distinct e.e order by e.e)
                     from (select fn_banco_emisor(concat_ws(' ', c.nombre, c.nombre_en, t.titular, t.notas)) as e
                             from tarjetas t join cuentas c on c.codigo = t.cuenta
                            where t.activa and left(t.cuenta, 5) = '2100-' and c.tipo = 'pasivo' and c.saldo_normal = 'haber') e
                    where e.e is not null), '{}'::text[]);
end $$;
revoke execute on function public.fn_banco_emisores_propios() from public, anon, authenticated, service_role;

-- =====================================================================
-- (Ronda 4c) EL CRITERIO: ¿QUIÉN ES EL OTRO LADO DE ESTE MOVIMIENTO?
-- Una sola respuesta, con lo que dice el banco (el número de cuenta o de
-- tarjeta que nombra, en NAME o en la nota si cortó el nombre; a quién
-- nombra; si lo da por transferencia o por el pago de una tarjeta) y lo
-- que sabe la empresa (sus cuentas y tarjetas con su número; las que
-- todavía no trajeron estado de cuenta y se dieron de alta por su número
-- con un lote vacío —la reserva recién abierta, la línea de crédito, un
-- préstamo—; el nombre con que las trae QuickBooks; y las cuentas
-- personales de Edgar dadas de alta). Devuelve SIEMPRE un objeto con su
-- «clase»:
--   propia             nombra el número de una cuenta de la empresa
--                      (fn_banco_numero_de): «cuenta», «ultimos4» y su
--                      «tipo»: banco, tarjeta, o deuda (la línea de crédito
--                      o un préstamo, fn_banco_es_deuda);
--   propia_sin_numero  dice que es dinero entre cuentas propias y no nombra
--                      ningún número ni a nadie («ONLINE TRANSFER TO
--                      SAVINGS»; el pago de la Amex visto en Chase, que
--                      nombra a su emisor; «PAYMENT RECEIVED» en la tarjeta):
--                      el otro lado puede ser cualquier cuenta propia de su
--                      tipo («por»: transferencia, pago_tarjeta,
--                      pago_recibido);
--   personal           nombra una cuenta personal de Edgar dada de alta a
--                      propósito (fn_banco_personal_de): «nombre», «ultimos4»;
--   desconocida        nombra un número que no es de la empresa ni personal:
--                      no se supone ni lo uno ni lo otro, se pregunta (y se
--                      dice cómo darlo de alta), «ultimos4»;
--   tercero            todo lo demás: el cobro de un cliente, el pago a un
--                      proveedor, una compra; o una transferencia SIN número
--                      que nombra a alguien («ONLINE TRANSFER TO EDGAR M
--                      PERSONAL»: no es una cuenta propia ni por su número ni
--                      por su nombre). «nombra»: las palabras con que nombra
--                      a alguien, si las hay (fn_banco_nombrado);
--                      «transferencia»: true si el banco la da por una.
-- La usan TODOS los caminos que juntan dos lados o mandan el dinero a otra
-- cuenta, y igual: R3 (las dos mitades pendientes) y R1 (la mitad que
-- espera su línea en el libro), los dos con fn_banco_lados; «A …» y «Desde
-- …» de la bandeja y fn_banco_transferencia (fn_banco_transferencia_motivo);
-- fn_banco_casar_con ({movimiento}, y la línea de una transferencia o de un
-- cobro); «otro_lado_clasificado» (paso d de la bandeja); las propuestas de
-- depósitos y retiros (un depósito que nombra una cuenta propia no es el
-- cobro de un cliente; el de una deuda propia es su desembolso); el orden
-- de los botones; fn_banco_cobrar y fn_banco_clasificar.
-- (Antes cada camino miraba un trozo: R3 juntaba el pase a un número que
-- no se conoce con el depósito de la reserva desde Chase; «Desde 1010»
-- dejaba que el pase a la cuenta personal casara solo con su línea; el
-- depósito que nombraba la cuenta de Chase salía como el cobro de una
-- factura; y la línea de crédito no se podía dar de alta.)
-- (En plpgsql: sus consultas guardan su plan entre llamadas.)
-- (Ronda 4d) Cuatro cosas que dice el banco y EL CRITERIO no leía:
--   · los 4 últimos SUELTOS de la tarjeta PERSONAL de Edgar dada de alta en
--     2900 («AMEX EPAYMENT ACH PMT 1006»): solo se leían los de las tarjetas
--     de la empresa, y el pago a su Platinum salía «propia_sin_numero»: R3 lo
--     juntaba solo con el pago recibido en la Gold;
--   · el EMISOR de la tarjeta que se paga («CHASE CREDIT CRD AUTOPAY», «BANK
--     OF AMERICA CREDIT CARD BILL PAYMENT»): si no es el de ninguna tarjeta
--     de la empresa (las de Edgar son Amex: fn_banco_emisores_propios), no es
--     dinero entre cuentas propias por defecto; es un tercero que el banco
--     nombra («emisor»), y R3 no lo junta con el pago recibido en la Gold;
--   · un CHEQUE (su número, fn_banco_cheque_num): un pago a un tercero
--     («cheque»), que nunca es la otra mitad de una transferencia;
--   · el número que trae su DUPLICADO: el mismo movimiento por Plaid con el
--     nombre corto («Online Transfer to CHK») y por el QFX con el entero
--     («ONLINE TRANSFER TO CHK ...7781»), dicho «es el mismo»: lo que dice
--     el QFX vale para el que entró («por_duplicado»).
create or replace function public.fn_banco_otro_lado(m public.movimientos_banco)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_tipo text;
  v_tr   boolean;
  v_pt   boolean := false;
  v_pr   boolean := false;
  v_memo text;
  v_u4   text;
  v_cta  text;
  v_nom  text;
  v_em   text;
  v_emp  text[];
  v_chq  text;
  v_dup  boolean := false;
  d      record;
begin
  v_tipo := fn_banco_tipo_cuenta(m.cuenta);
  v_tr := coalesce(m.tipo_banco, '') = 'XFER' or fn_banco_dice('transferencia', m.desc_norm);
  if v_tipo = 'banco' and m.monto < 0 then
    -- (el pago de una tarjeta, del lado del banco que paga: el nombre del
    -- emisor, o los 4 últimos de una tarjeta de crédito de la empresa o de
    -- la personal de Edgar dada de alta en 2900 —ronda 4d—; nunca los de una
    -- débito, que es la del propio banco)
    v_pt := fn_banco_dice('pago_tarjeta', m.desc_norm)
            or exists (select 1 from tarjetas t join cuentas c on c.codigo = t.cuenta
                        where t.activa and t.ultimos4 ~ '^[0-9]{4}$'
                          and (left(t.cuenta, 5) = '2100-' or (c.tipo = 'pasivo' and c.etiqueta_fiscal = 'accionista'))
                          and m.desc_norm ~ ('(^| )' || t.ultimos4 || '( |$)'));
  elsif v_tipo = 'tarjeta' and m.monto > 0 then
    v_pr := fn_banco_dice('pago_recibido', m.desc_norm);
  end if;
  if v_tr or v_pt then
    v_memo := fn_banco_norm(m.memo);
  end if;
  -- EL NÚMERO que nombra: el de una cuenta, en una transferencia («TO CHK
  -- ...7781», «FROM ACCT ...8899»); si no, en el pago de una tarjeta desde
  -- el banco, el de la tarjeta («CARD ENDING IN 5555», o sus 4 últimos
  -- sueltos). En NAME, o en la nota si el banco cortó el nombre.
  if v_tr then
    v_u4 := coalesce(fn_banco_otra_cuenta(m.desc_norm), fn_banco_otra_cuenta(v_memo));
  end if;
  if v_u4 is null and v_tipo = 'banco' and m.monto < 0 and (v_tr or v_pt) then
    v_u4 := coalesce(fn_banco_otra_tarjeta(m.desc_norm), fn_banco_otra_tarjeta(v_memo),
                     (select t.ultimos4 from tarjetas t join cuentas c on c.codigo = t.cuenta
                       where t.activa and t.ultimos4 ~ '^[0-9]{4}$'
                         and (left(t.cuenta, 5) = '2100-' or (c.tipo = 'pasivo' and c.etiqueta_fiscal = 'accionista'))
                         and m.desc_norm ~ ('(^| )' || t.ultimos4 || '( |$)')
                       order by t.ultimos4 limit 1));
  end if;
  -- (Ronda 4d) Sin número, el que trae su duplicado dicho «es el mismo» (el
  -- QFX con el nombre entero de lo que Plaid trajo cortado), con las mismas
  -- reglas. Por su índice: casi nunca hay.
  if v_u4 is null and (v_tr or v_pt) then
    for d in select x.desc_norm, x.memo from movimientos_banco x
              where x.posible_duplicado_de = m.id and x.duplicado = 'es_el_mismo' and x.cuenta = m.cuenta
              order by x.importado_el, x.id loop
      v_u4 := coalesce(fn_banco_otra_cuenta(d.desc_norm), fn_banco_otra_cuenta(fn_banco_norm(d.memo)),
                       case when v_tipo = 'banco' and m.monto < 0
                            then coalesce(fn_banco_otra_tarjeta(d.desc_norm), fn_banco_otra_tarjeta(fn_banco_norm(d.memo))) end);
      if v_u4 is not null then
        v_dup := true;
        exit;
      end if;
    end loop;
  end if;
  if v_u4 is not null then
    v_cta := fn_banco_numero_de(v_u4);
    if v_cta is not null then
      return jsonb_strip_nulls(jsonb_build_object(
               'clase', 'propia', 'ultimos4', v_u4, 'cuenta', v_cta,
               'tipo', coalesce(fn_banco_tipo_cuenta(v_cta), case when fn_banco_es_deuda(v_cta) then 'deuda' end),
               'por_duplicado', case when v_dup then true end));
    end if;
    v_nom := fn_banco_personal_de(v_u4);
    if v_nom is not null then
      return jsonb_strip_nulls(jsonb_build_object('clase', 'personal', 'ultimos4', v_u4, 'nombre', v_nom,
                                                  'por_duplicado', case when v_dup then true end));
    end if;
    return jsonb_strip_nulls(jsonb_build_object('clase', 'desconocida', 'ultimos4', v_u4,
                                                'por_duplicado', case when v_dup then true end));
  end if;
  -- SIN NÚMERO: una transferencia que nombra a alguien no es entre cuentas
  -- propias por defecto (el pago de una tarjeta nombra a su emisor: ese sí).
  v_nom := fn_banco_nombrado(m.desc_norm);
  if v_tr and not v_pt and v_nom is not null then
    return jsonb_build_object('clase', 'tercero', 'nombra', v_nom, 'transferencia', true);
  end if;
  -- (Ronda 4d) EL PAGO DE LA TARJETA DE OTRO EMISOR: el banco nombra un
  -- emisor (fn_banco_emisor) y ninguna tarjeta de la empresa es suya. Si no
  -- se sabe el de ninguna, como antes.
  if v_pt then
    v_em := fn_banco_emisor(m.desc_norm);
    if v_em is not null then
      v_emp := fn_banco_emisores_propios();
      if cardinality(v_emp) > 0 and not (v_em = any (v_emp)) then
        return jsonb_build_object('clase', 'tercero', 'nombra', v_em, 'transferencia', true, 'emisor', v_em,
                                  'emisores_propios', to_jsonb(v_emp));
      end if;
    end if;
  end if;
  if v_tr or v_pt or v_pr then
    return jsonb_build_object('clase', 'propia_sin_numero',
                              'por', case when v_pr then 'pago_recibido' when v_pt then 'pago_tarjeta' else 'transferencia' end);
  end if;
  -- (Ronda 4d) UN CHEQUE: el pago a un tercero por su número.
  v_chq := fn_banco_cheque_num(m.cheque, m.descripcion);
  return jsonb_strip_nulls(jsonb_build_object('clase', 'tercero', 'nombra', v_nom, 'cheque', v_chq));
end $$;
revoke execute on function public.fn_banco_otro_lado(public.movimientos_banco) from public, anon, authenticated, service_role;

-- (Ronda 4c) ¿SON LAS DOS MITADES DEL MISMO DINERO? Con EL CRITERIO de cada
-- una (fn_banco_otro_lado) y su cuenta. {"contradice": <por qué, o nulo>,
-- "solas": true|false}:
--   contradice  una de las dos dice que el dinero fue a (o vino de) OTRO
--               sitio: una cuenta personal de Edgar dada de alta, un número
--               que no se conoce, el número de otra cuenta de la empresa (no
--               la de la otra mitad), o alguien que nombra sin número. Se
--               juntan solo con su motivo escrito (y la bandeja lo pide);
--   solas       sin contradicción, y cada una lo confirma: nombra la cuenta
--               de la otra, o dice que es dinero entre cuentas propias sin
--               nombrar ninguna; o, sin decirlo y sin nombrar a nadie (un
--               «DEPOSIT» a secas), la otra la nombra a ella por su número.
--               Solo así casan solas (R3, y R1 con la línea que espera).
-- Dos mitades que nombran el mismo número se contradicen solas: ese número
-- no es de las dos cuentas. Sin criterio (nulo) cuenta como un tercero que
-- no nombra a nadie.
-- (Ronda 4d) Un CHEQUE (el tercero con «cheque») tampoco es la mitad de una
-- transferencia: es el pago a un tercero. Antes contaba como un «DEPOSIT» a
-- secas y, con «Desde 1010» pulsado en la reserva, el cheque 1234 de Chase
-- por lo mismo, tres días antes, casaba solo como «la otra mitad».
create or replace function public.fn_banco_lados(p_a jsonb, p_cta_a text, p_b jsonb, p_cta_b text)
returns jsonb
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_por text[] := '{}';
  v_ok  boolean := true;
  x     record;
begin
  for x in select * from (values (coalesce(p_a, '{"clase": "tercero"}'::jsonb), p_cta_a, coalesce(p_b, '{"clase": "tercero"}'::jsonb), p_cta_b),
                                 (coalesce(p_b, '{"clase": "tercero"}'::jsonb), p_cta_b, coalesce(p_a, '{"clase": "tercero"}'::jsonb), p_cta_a))
                           as t(ol, cta, ol2, cta2) loop
    if x.ol->>'clase' = 'personal' then
      v_por := v_por || format('el de %s dice que es la cuenta ····%s, tu cuenta personal (%s, dada de alta)', x.cta,
                               x.ol->>'ultimos4', x.ol->>'nombre');
    elsif x.ol->>'clase' = 'desconocida' then
      v_por := v_por || format('el de %s dice que es la cuenta ····%s, que no conozco', x.cta, x.ol->>'ultimos4');
    elsif x.ol->>'clase' = 'propia' and (x.ol->>'cuenta') is distinct from x.cta2 then
      v_por := v_por || format('el de %s dice que es la cuenta ····%s, que es %s', x.cta, x.ol->>'ultimos4', x.ol->>'cuenta');
    elsif x.ol->>'clase' = 'tercero' and x.ol ? 'emisor' then
      v_por := v_por || format('el de %s paga una tarjeta de %s, y ninguna tarjeta de la empresa es de %s', x.cta, x.ol->>'emisor',
                               x.ol->>'emisor');
    elsif x.ol->>'clase' = 'tercero' and x.ol ? 'nombra' then
      v_por := v_por || format('el de %s nombra a «%s», no a una cuenta propia', x.cta, x.ol->>'nombra');
    elsif x.ol->>'clase' = 'tercero' and x.ol ? 'cheque' then
      v_por := v_por || format('el de %s es el cheque %s: el pago a un tercero, no dinero entre cuentas propias', x.cta,
                               x.ol->>'cheque');
    end if;
    v_ok := v_ok and (x.ol->>'clase' = 'propia_sin_numero'
                      or (x.ol->>'clase' = 'propia' and x.ol->>'cuenta' = x.cta2)
                      or (x.ol->>'clase' = 'tercero' and not (x.ol ? 'nombra') and not (x.ol ? 'cheque')
                          and x.ol2->>'clase' = 'propia' and x.ol2->>'cuenta' = x.cta));
  end loop;
  return jsonb_build_object('contradice', case when cardinality(v_por) > 0 then array_to_string(v_por, '; ') end,
                            'solas', v_ok and cardinality(v_por) = 0);
end $$;
revoke execute on function public.fn_banco_lados(jsonb, text, jsonb, text) from public, anon, authenticated, service_role;

-- (Ronda 4c) Las dos mitades cuando una ya está en el libro: el movimiento
-- y la LÍNEA de una transferencia que espera su otro lado (la que posteó
-- otro movimiento con fn_banco_transferencia: «Desde 1010» en la reserva).
-- Con el movimiento que la posteó (el origen de su asiento); sin él, con
-- la otra cuenta del asiento, como si dijera «entre cuentas propias».
create or replace function public.fn_banco_lados_linea(m public.movimientos_banco, p_asiento uuid)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  m0     movimientos_banco;
  v_otra text;
begin
  select x.* into m0
    from asientos a
    join movimientos_banco x on x.id = (case when a.origen_id ~ '^[0-9a-fA-F-]{36}$' then a.origen_id::uuid end)
   where a.id = p_asiento and a.origen_tabla = 'movimientos_banco' and x.id <> m.id;
  if found then
    return fn_banco_lados(fn_banco_otro_lado(m), m.cuenta, fn_banco_otro_lado(m0), m0.cuenta);
  end if;
  select l.cuenta into v_otra
    from asiento_lineas l where l.asiento_id = p_asiento and l.cuenta <> m.cuenta order by l.orden limit 1;
  return fn_banco_lados(fn_banco_otro_lado(m), m.cuenta, '{"clase": "propia_sin_numero"}'::jsonb, v_otra);
end $$;
revoke execute on function public.fn_banco_lados_linea(public.movimientos_banco, uuid) from public, anon, authenticated, service_role;

-- (Ronda 4) ¿Por qué una transferencia de este movimiento a (o desde)
-- p_cuenta necesita su motivo? Nulo si no: el banco nombra OTRA cuenta
-- (····7781, que no es la de p_cuenta), o, entre dos bancos, p_cuenta
-- nunca trajo su estado de cuenta (la reserva por abrir: no se sabe que el
-- dinero llegó, y quedaría «en tránsito» para siempre sin que nada lo
-- dijera). (Ronda 4b: con lo que es ese número —de otra cuenta de la
-- empresa, una cuenta personal de Edgar dada de alta, o uno que no se
-- conoce—, y también la tarjeta que nombra el pago de una tarjeta. La
-- regla va en fn_banco_dudosa, con el otro lado ya leído: la bandeja la
-- pide por cada cuenta propia que ofrece.) (Ronda 4c: con EL CRITERIO;
-- también la transferencia sin número que nombra a alguien —«TO EDGAR M
-- PERSONAL»—: no dice que sea una cuenta propia. La deuda propia, la
-- línea de crédito, es «otra cuenta» como cualquiera.)
create or replace function public.fn_banco_dudosa(p_ol jsonb, p_cuenta_mov text, p_cuenta text)
returns text
language plpgsql
stable
set search_path = public, pg_temp
as $$
begin
  if p_ol->>'clase' = 'propia' and (p_ol->>'cuenta') is distinct from p_cuenta then
    return format('el banco dice que es la cuenta ····%s, que es %s', p_ol->>'ultimos4', p_ol->>'cuenta');
  elsif p_ol->>'clase' = 'personal' then
    return format('el banco dice que es la cuenta ····%s, tu cuenta personal (%s, dada de alta)', p_ol->>'ultimos4', p_ol->>'nombre');
  elsif p_ol->>'clase' = 'desconocida' then
    return format('el banco dice que es la cuenta ····%s, que no conozco: no es de ningún estado de cuenta ni tarjeta de la empresa, '
                  'ni la diste de alta como tuya', p_ol->>'ultimos4');
  elsif p_ol->>'clase' = 'tercero' and p_ol ? 'nombra' then
    return format('el banco nombra a «%s», sin número de cuenta: no dice que sea una cuenta propia', p_ol->>'nombra');
  -- (entre dos bancos: el pago de una tarjeta desde el banco operativo,
  -- cuyo estado de cuenta llega cada mes, no)
  elsif fn_banco_tipo_cuenta(p_cuenta) = 'banco' and fn_banco_tipo_cuenta(p_cuenta_mov) = 'banco'
        and not exists (select 1 from archivos_banco a where a.cuenta = p_cuenta and a.retirado_el is null) then
    return format('%s nunca trajo su estado de cuenta: no se sabe que el dinero llegó allí', p_cuenta);
  end if;
  return null;
end $$;
revoke execute on function public.fn_banco_dudosa(jsonb, text, text) from public, anon, authenticated, service_role;
create or replace function public.fn_banco_transferencia_dudosa(m public.movimientos_banco, p_cuenta text)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select fn_banco_dudosa(fn_banco_otro_lado(m), m.cuenta, p_cuenta)
$$;
revoke execute on function public.fn_banco_transferencia_dudosa(public.movimientos_banco, text)
  from public, anon, authenticated, service_role;

-- (Ronda 4c) ¿POR QUÉ ESTE MOVIMIENTO NO SE POSTEA COMO TRANSFERENCIA A (O
-- DESDE) p_cuenta SIN SU MOTIVO? Lo miran, con la misma función,
-- fn_banco_transferencia (que lo frena) y la bandeja (que marca su «A …» o
-- «Desde …» con «pide_motivo»): así ningún botón, pulsado tal cual, falla.
-- {"que", "texto"}, o nulo si entra sin motivo:
--   senal          su descripción no dice que sea dinero entre cuentas
--                  propias: ni transferencia, ni (a una tarjeta) el emisor o
--                  sus 4 últimos; en la tarjeta, que es un pago;
--   dudosa         EL CRITERIO dice otra cosa (fn_banco_dudosa: otra cuenta
--                  de la empresa, una personal, un número que no se conoce,
--                  alguien sin número), o es un banco que nunca trajo su
--                  estado de cuenta;
--   contrapartida  en p_cuenta, lo pendiente por ese mismo dinero en esos
--                  días (a 10 días o menos, el signo contrario) dice que fue
--                  a (o vino de) otro sitio, y no hay otro que no lo diga (el
--                  pase a la cuenta personal de Edgar no es el otro lado del
--                  pago a la Gold). Antes «Desde 1010» entraba sin motivo y,
--                  en la misma llamada, el pase a la personal casaba solo con
--                  su línea: el pago de la tarjeta personal quedaba como el de
--                  la Gold.
-- (Lo que ya está en el libro —su otro lado clasificado, la línea de la
-- transferencia que lo espera— lo mira aparte fn_banco_transferencia; la
-- bandeja ya lo propone antes.)
create or replace function public.fn_banco_transferencia_motivo(m public.movimientos_banco, p_cuenta text, p_ol jsonb)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_tipo  text := fn_banco_tipo_cuenta(m.cuenta);
  v_tipo2 text := fn_banco_tipo_cuenta(p_cuenta);
  v_senal boolean;
  v_dud   text;
  v_c     text;
begin
  v_senal := case
               when v_tipo = 'tarjeta' and m.monto > 0 then fn_banco_dice('pago_recibido', m.desc_norm)
               when v_tipo = 'tarjeta' then false
               when v_tipo2 = 'tarjeta' and m.monto > 0 then false
               -- (el pago de una TARJETA, solo con su señal —el emisor o sus 4
               -- últimos—: «ONLINE TRANSFER TO CHK ...7781» no lo es)
               when v_tipo2 = 'tarjeta'
                 then fn_banco_dice('pago_tarjeta', m.desc_norm)
                      or exists (select 1 from tarjetas t where t.cuenta = p_cuenta and t.ultimos4 ~ '^[0-9]{4}$'
                                    and m.desc_norm ~ ('(^| )' || t.ultimos4 || '( |$)'))
               when coalesce(m.tipo_banco, '') = 'XFER' or fn_banco_dice('transferencia', m.desc_norm) then true
               else false end;
  if not v_senal then
    return jsonb_build_object('que', 'senal');
  end if;
  v_dud := fn_banco_dudosa(p_ol, m.cuenta, p_cuenta);
  if v_dud is not null then
    return jsonb_build_object('que', 'dudosa', 'texto', v_dud);
  end if;
  select string_agg(format('el del %s por %s («%s»): %s', y.fecha, y.monto, coalesce(y.descripcion, ''), y.c), '; '
                    order by abs(y.fecha - m.fecha), y.fecha)
    into v_c
    from (select x.fecha, x.monto, x.descripcion,
                 fn_banco_lados(p_ol, m.cuenta, fn_banco_otro_lado(x), x.cuenta)->>'contradice' as c
            from movimientos_banco x
           where x.cuenta = p_cuenta and x.estado = 'pendiente' and x.monto = -m.monto
             and x.fecha between m.fecha - 10 and m.fecha + 10 and x.fecha >= fn_puente_corte()
             and (x.posible_duplicado_de is null or x.duplicado = 'no_es_el_mismo')) y
  having count(*) > 0 and bool_and(y.c is not null);
  if v_c is not null then
    return jsonb_build_object('que', 'contrapartida',
                              'texto', format('en %s, lo pendiente por ese mismo dinero en esos días dice que fue a (o vino de) otro sitio: '
                                              '%s', p_cuenta, v_c));
  end if;
  return null;
end $$;
revoke execute on function public.fn_banco_transferencia_motivo(public.movimientos_banco, text, jsonb)
  from public, anon, authenticated, service_role;

-- (Ronda 4c) EL CRITERIO EN UN COBRO: un depósito que nombra una cuenta de
-- la empresa por su número (la de Chase, ····4392; la línea de crédito) no
-- es el cobro de un cliente. Registrarlo o casarlo como cobro pide su
-- porqué (p_donde: dónde se escribe): para con MX008 y dice qué es. Lo
-- llaman fn_banco_cobrar y fn_banco_casar_con (un cobro, o sus líneas).
-- Antes el pase de Chase que llegaba primero a la reserva se cobraba a
-- una factura con su botón, sin motivo.
-- (Ronda 4d) Y la cuenta PERSONAL de Edgar dada de alta: su dinero no es el
-- de un cliente (EL CONTROL lo pondría en rojo); si de verdad un cliente le
-- pagó a él y él lo pasó a la empresa, se dice en el motivo.
create or replace function public.fn_banco_cobro_propia(m public.movimientos_banco, p_donde text)
returns void
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_ol jsonb;
begin
  if m.monto <= 0 then
    return;
  end if;
  v_ol := fn_banco_otro_lado(m);
  if v_ol->>'clase' = 'personal' then
    raise exception using errcode = 'MX008',
      message = format('El banco dice que este depósito viene de tu cuenta personal ····%s (%s, dada de alta): es tu dinero (un préstamo '
                       'a la empresa, 2900; una aportación, 3100; lo que devuelves, 1130), no el cobro de un cliente. Si de verdad es '
                       'el cobro de una factura (un cliente que te pagó a ti y lo pasaste a la empresa), dilo en %s.',
                       v_ol->>'ultimos4', v_ol->>'nombre', p_donde);
  end if;
  if v_ol->>'clase' = 'propia' then
    raise exception using errcode = 'MX008',
      message = format('El banco dice que este depósito viene de ····%s, %s (%s): %s, no el cobro de un cliente. %s Si de verdad es el '
                       'cobro de una factura, dilo en %s.', v_ol->>'ultimos4', v_ol->>'cuenta',
                       coalesce((select c.nombre from cuentas c where c.codigo = v_ol->>'cuenta'), 'sin nombre'),
                       case when v_ol->>'tipo' = 'deuda' then 'es su desembolso' else 'es dinero entre cuentas propias' end,
                       case when v_ol->>'tipo' = 'deuda'
                            then format('Va a %s (fn_banco_clasificar con {"cuenta": "%s"}).', v_ol->>'cuenta', v_ol->>'cuenta')
                            else format('Es una transferencia: cásalo con su otro lado, o confírmalo desde %s (fn_banco_transferencia).',
                                        v_ol->>'cuenta') end,
                       p_donde);
  end if;
end $$;
revoke execute on function public.fn_banco_cobro_propia(public.movimientos_banco, text) from public, anon, authenticated, service_role;

-- (Ronda 4d) EL COBRO QUE YA NOMBRA ESTE MOVIMIENTO: la app (c3,
-- fn_cobro_registrar con "movimiento_id") registró un cobro con él y no casó
-- solo (EL CRITERIO lo frenó: el banco dice que el dinero viene de una
-- cuenta de la empresa o de la personal de Edgar). Mientras ese cobro siga
-- vigente, su asiento ya tiene este dinero en el libro: postearlo otra vez
-- (como transferencia, o clasificado) lo metería dos veces, con o sin
-- motivo. Se anula el cobro (fn_cobro_anular, con su motivo) o se casa con
-- él (fn_banco_casar_con, con su motivo). En palabras, o nulo.
create or replace function public.fn_banco_cobro_reclama(p_mov uuid)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select string_agg(format('el cobro del %s por %s%s (%s)', c.fecha, c.monto, coalesce(' (ref ' || c.referencia || ')', ''), c.id), '; '
                    order by c.fecha, c.id)
    from cobros c
   where c.movimiento_id = p_mov::text and c.estado = 'vigente'
     and not exists (select 1 from banco_casados bc where bc.movimiento_id = p_mov and bc.deshecho_el is null)
$$;
revoke execute on function public.fn_banco_cobro_reclama(uuid) from public, anon, authenticated, service_role;

-- =====================================================================
-- (Ronda 4d) EL CRITERIO CONTRA EL LIBRO. Lo de arriba responde «¿quién es
-- el otro lado según el banco?» y junta dos mitades del banco
-- (fn_banco_lados). Esto responde «¿lo que dice el banco y lo que dice el
-- libro con que casa (o casaría) se contradicen?», para CUALQUIER casado:
-- un asiento escrito a mano (fn_postear desde el SQL Editor), el cobro que
-- c3 registró con su movimiento, una partida de la apertura, una cuota, lo
-- clasificado, una transferencia. Lo usan R1, R- y la regla de la apertura
-- (no casan solo lo que se contradice), la bandeja y fn_banco_casar_con
-- (piden el motivo), y EL CONTROL (fn_banco_criterio_casados, y su copia en
-- fn_banco_control: lo que un camino deje pasar sale en rojo).
-- =====================================================================

-- LO QUE DICE EL LIBRO DEL OTRO LADO: frente a la línea de la cuenta del
-- movimiento, lo que hay en el asiento (o lo que es el casado):
--   propia      otra cuenta propia con estado de cuenta (un banco, una
--               tarjeta de la empresa: fn_banco_es_propia), con su «tipo»:
--               una transferencia o el pago de una tarjeta;
--   deuda       la línea de crédito o un préstamo (fn_banco_es_deuda): su
--               pago (con sus intereses) o su desembolso;
--   patrimonio  el del accionista (fn_banco_es_accionista: 1130, 2900,
--               3xxx): su préstamo, su aportación, su distribución;
--   cobro       el cobro de un cliente (un cobro de c3, o su cuenta por
--               cobrar o su retención);
--   apertura    una partida en tránsito de la conciliación de apertura (lo
--               que QuickBooks tenía al 30-sep: el cheque a un tercero, el
--               depósito de un cliente);
--   otro        lo demás: un gasto, un costo, un proveedor («solo_gasto»:
--               todo gasto, como los intereses de una deuda).
-- «cuenta»: la que manda; «cuentas»: todas las de enfrente.
create or replace function public.fn_banco_libro_lado(p_asiento uuid, p_cuenta text, p_clase text default null)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_ctas text[];
  v_ori  text;
  v_pro  text;
  v_deu  text;
  v_acc  text;
  v_cxc  boolean;
  v_gas  boolean;
begin
  if p_clase = 'apertura' then
    return '{"clase": "apertura"}'::jsonb;
  end if;
  select a.origen_tabla into v_ori from asientos a where a.id = p_asiento;
  if p_clase = 'cobro' or v_ori = 'cobros' then
    return '{"clase": "cobro"}'::jsonb;
  end if;
  select array_agg(distinct l.cuenta order by l.cuenta) into v_ctas
    from asiento_lineas l where l.asiento_id = p_asiento and l.cuenta is distinct from p_cuenta;
  v_ctas := coalesce(v_ctas, '{}'::text[]);
  select min(x.c) filter (where fn_banco_es_propia(x.c)), min(x.c) filter (where fn_banco_es_deuda(x.c)),
         min(x.c) filter (where fn_banco_es_accionista(x.c)),
         coalesce(bool_or(x.c in (fn_puente_cuenta_de('cxc'), fn_puente_cuenta_de('retencion_cxc'))), false),
         coalesce(bool_and(c.tipo in ('gasto', 'otro_gasto')), false)
    into v_pro, v_deu, v_acc, v_cxc, v_gas
    from unnest(v_ctas) as x(c) left join cuentas c on c.codigo = x.c;
  return case when v_pro is not null
              then jsonb_build_object('clase', 'propia', 'cuenta', v_pro, 'tipo', fn_banco_tipo_cuenta(v_pro), 'cuentas', to_jsonb(v_ctas))
              when v_deu is not null then jsonb_build_object('clase', 'deuda', 'cuenta', v_deu, 'cuentas', to_jsonb(v_ctas))
              when v_acc is not null then jsonb_build_object('clase', 'patrimonio', 'cuenta', v_acc, 'cuentas', to_jsonb(v_ctas))
              when v_cxc then jsonb_build_object('clase', 'cobro', 'cuentas', to_jsonb(v_ctas))
              else jsonb_build_object('clase', 'otro', 'cuentas', to_jsonb(v_ctas), 'solo_gasto', v_gas and cardinality(v_ctas) > 0) end;
end $$;
revoke execute on function public.fn_banco_libro_lado(uuid, text, text) from public, anon, authenticated, service_role;

-- ¿SE CONTRADICEN? Con lo que dice el banco del otro lado (p_ol:
-- fn_banco_otro_lado) y lo que dice el libro (p_libro: fn_banco_libro_lado),
-- y el monto del movimiento. {"contradice": <por qué, o nulo>, "solas":
-- true|false}. Se contradicen:
--   · el libro dice otra cuenta propia o una deuda, y el banco nombra otra
--     cuenta de la empresa, una cuenta personal de Edgar, un número que no
--     se conoce, alguien sin número, la tarjeta de otro emisor, un cheque
--     (el pago a un tercero) o, sin decir transferencia, nombra a alguien;
--   · el libro dice el cobro de un cliente o una partida de QuickBooks, y
--     el banco nombra una cuenta de la empresa o una personal de Edgar;
--   · el libro dice el patrimonio del accionista, y el banco no nombra una
--     cuenta personal de Edgar dada de alta (EL PRINCIPIO de la 4b);
--   · el libro dice otra cosa (un gasto, un proveedor…), y el banco nombra
--     una cuenta de la empresa por su número (salvo los intereses de una
--     deuda que se paga desde el banco: un retiro a su número que va entero
--     a un gasto).
-- Lo coherente no: la personal contra el patrimonio, un tercero (un número
-- que no se conoce, alguien que se nombra, un cheque) contra su cobro, el
-- prestamista contra su deuda. «solas» (casa sin que nadie lo confirme):
-- sin contradicción, y con el libro a una cuenta propia, solo si el banco
-- la confirma (nombra esa cuenta, o dice dinero entre cuentas propias de
-- su clase sin nombrar ninguna); un «DEPOSIT» a secas contra el pase a la
-- reserva escrito a mano espera a Edgar. (La copia escrita en SQL de esta
-- regla está en fn_banco_control, cuadre 59: la app no ejecuta funciones
-- internas; fn_banco_verificar comprueba que dicen lo mismo.)
create or replace function public.fn_banco_criterio(p_monto numeric, p_ol jsonb, p_libro jsonb)
returns jsonb
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  b   text := coalesce(p_ol->>'clase', 'tercero');
  l   text := coalesce(p_libro->>'clase', 'otro');
  v_l text;
  v_b text;
  v_c text;
  v_s boolean := true;
begin
  -- (lo que dice el libro, en palabras)
  v_l := case l when 'propia' then case when p_libro->>'tipo' = 'tarjeta' then format('el pago de la tarjeta %s', p_libro->>'cuenta')
                                        else format('una transferencia con %s', p_libro->>'cuenta') end
                when 'deuda' then format('dinero de o a la deuda %s', p_libro->>'cuenta')
                when 'patrimonio' then format('el patrimonio del accionista (%s)', p_libro->>'cuenta')
                when 'cobro' then 'el cobro de un cliente'
                when 'apertura' then 'una partida en tránsito de QuickBooks (la conciliación de apertura)'
                else format('otra cosa (%s)', coalesce((select string_agg(x, ', ') from jsonb_array_elements_text(p_libro->'cuentas') x),
                                                       'sin cuenta')) end;
  -- (lo que dice el banco, en palabras)
  v_b := case b when 'propia' then format('la cuenta ····%s, que es %s', p_ol->>'ultimos4', p_ol->>'cuenta')
                when 'personal' then format('la cuenta ····%s, tu cuenta personal (%s, dada de alta)', p_ol->>'ultimos4', p_ol->>'nombre')
                when 'desconocida' then format('la cuenta ····%s, que no conozco', p_ol->>'ultimos4')
                when 'propia_sin_numero' then 'dinero entre cuentas propias, sin número'
                else case when p_ol ? 'emisor' then format('el pago de una tarjeta de %s (ninguna de la empresa lo es)', p_ol->>'emisor')
                          when p_ol ? 'cheque' then format('el cheque %s, el pago a un tercero', p_ol->>'cheque')
                          when coalesce((p_ol->>'transferencia')::boolean, false)
                          then format('«%s», a quien nombra sin número de cuenta', p_ol->>'nombra')
                          when p_ol ? 'nombra' then format('a «%s», un tercero', p_ol->>'nombra')
                          else 'un tercero' end end
         || case when coalesce((p_ol->>'por_duplicado')::boolean, false) then ' (lo dice su duplicado)' else '' end;
  if l in ('propia', 'deuda') then
    if b = 'propia' then
      if not coalesce(p_libro->'cuentas' ? (p_ol->>'cuenta'), false) and (p_libro->>'cuenta') is distinct from (p_ol->>'cuenta') then
        v_c := 'contradice';
      end if;
    elsif b in ('personal', 'desconocida') then
      v_c := 'contradice';
    elsif b = 'tercero' and (p_ol ? 'emisor' or coalesce((p_ol->>'transferencia')::boolean, false)) then
      v_c := 'contradice';
    elsif b = 'tercero' and l = 'propia' and (p_ol ? 'cheque' or p_ol ? 'nombra') then
      v_c := 'contradice';
    end if;
    v_s := v_c is null
           and case when b = 'propia' then true
                    when b = 'propia_sin_numero'
                    then case p_ol->>'por' when 'pago_tarjeta' then l = 'propia' and p_libro->>'tipo' = 'tarjeta'
                                           when 'pago_recibido' then l = 'propia' and p_libro->>'tipo' = 'banco'
                                           else l = 'deuda' or p_libro->>'tipo' = 'banco' end
                    -- (el prestamista que cobra su cuota, un «LOAN PMT» sin número)
                    else l = 'deuda' end;
  elsif l in ('cobro', 'apertura') then
    if b in ('propia', 'personal') then
      v_c := 'contradice';
    end if;
    v_s := v_c is null;
  elsif l = 'patrimonio' then
    if b <> 'personal' then
      v_c := 'contradice';
    end if;
    v_s := v_c is null;
  else
    if b = 'propia' and not (coalesce(p_ol->>'tipo', '') = 'deuda' and p_monto < 0 and coalesce((p_libro->>'solo_gasto')::boolean, false)) then
      v_c := 'contradice';
    end if;
    v_s := v_c is null;
  end if;
  if v_c is not null then
    v_c := format('el banco dice que es %s, y el libro dice %s', v_b, v_l)
           || case when l = 'patrimonio' and b <> 'personal'
                   then ': el dinero del banco al patrimonio del accionista va solo desde una cuenta personal tuya dada de alta, o con '
                        'su motivo escrito'
                   when l in ('cobro', 'apertura') then ': ese dinero no es de un tercero'
                   else '' end;
  end if;
  return jsonb_build_object('contradice', v_c, 'solas', v_s);
end $$;
revoke execute on function public.fn_banco_criterio(numeric, jsonb, jsonb) from public, anon, authenticated, service_role;

-- EL CRITERIO de un movimiento contra un asiento (o la clase de un casado:
-- 'apertura', sin asiento), con lo que dice el banco hoy. Lo de arriba, con
-- «libro» y «banco» para decirlo.
create or replace function public.fn_banco_criterio_libro(m public.movimientos_banco, p_asiento uuid, p_clase text default null)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_libro jsonb := fn_banco_libro_lado(p_asiento, m.cuenta, p_clase);
  v_ol    jsonb := fn_banco_otro_lado(m);
begin
  return fn_banco_criterio(m.monto, v_ol, v_libro) || jsonb_build_object('libro', v_libro, 'banco', v_ol);
end $$;
revoke execute on function public.fn_banco_criterio_libro(public.movimientos_banco, uuid, text) from public, anon, authenticated, service_role;

-- EL CRITERIO DE UN CASADO VIVO: lo de arriba con su asiento (o su partida
-- de la apertura), y su motivo escrito (el del casado, o el que Edgar
-- escribió en el asiento que puso ESTE movimiento: «Desde 1010» con su
-- motivo). La cuenta personal vale también si lo era al casarlo
-- (banco_casados.otro_lado, o la procedencia del asiento): darla de baja
-- después —la cerró— no pone en rojo lo que entonces era suyo. Lo que
-- nunca se contradice no se mira: un ticket (recibo), la devolución de un
-- cobro, una regla fija.
create or replace function public.fn_banco_criterio_casado(p_casado uuid)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  bc   banco_casados;
  m    movimientos_banco;
  a    asientos;
  v_ol jsonb;
  v_li jsonb;
  v_mo text;
  v_r  jsonb;
begin
  select * into bc from banco_casados where id = p_casado;
  if not found or bc.deshecho_el is not null or bc.clase in ('recibo', 'devolucion', 'regla') then
    return null;
  end if;
  select * into m from movimientos_banco where id = bc.movimiento_id;
  select * into a from asientos where id = bc.asiento_id;
  v_ol := fn_banco_otro_lado(m);
  if v_ol->>'clase' <> 'personal'
     and (bc.otro_lado->>'clase' = 'personal'
          or (a.origen_tabla = 'movimientos_banco' and a.origen_id = m.id::text and a.procedencia ? 'cuenta_personal')) then
    v_ol := coalesce(case when bc.otro_lado->>'clase' = 'personal' then bc.otro_lado end,
                     jsonb_build_object('clase', 'personal', 'ultimos4', a.procedencia->>'cuenta_personal',
                                        'nombre', coalesce(a.procedencia->>'cuenta_personal_nombre', 'al casarlo')))
            || '{"al_casarlo": true}'::jsonb;
  end if;
  v_li := fn_banco_libro_lado(bc.asiento_id, m.cuenta, bc.clase);
  v_mo := coalesce(fn_banco_limpio(bc.motivo),
                   case when a.origen_tabla = 'movimientos_banco' and a.origen_id = m.id::text
                        then fn_banco_limpio(a.procedencia->>'motivo_edgar') end);
  v_r := fn_banco_criterio(m.monto, v_ol, v_li);
  return v_r || jsonb_strip_nulls(jsonb_build_object('libro', v_li, 'banco', v_ol, 'motivo', v_mo));
end $$;
revoke execute on function public.fn_banco_criterio_casado(uuid) from public, anon, authenticated, service_role;

-- EL CONTROL, la referencia: los casados vivos (de una cuenta, de un tramo
-- de fechas) cuyo lado del banco y cuyo lado del libro se contradicen y no
-- llevan su motivo escrito. Lo usan la conciliación (no se confirma con
-- uno en su tramo), fn_banco_verificar (y comprueba que el cuadre 59 de
-- fn_banco_control cuenta lo mismo) y las pruebas. Por el índice del
-- casado vivo; un ticket, una devolución o una regla fija no se miran.
-- (Solo pasa por EL CRITERIO entero lo que PUEDE contradecirse, sin su
-- motivo: lo que el banco da por transferencia o por el pago de una
-- tarjeta —solo ahí nombra un número, a alguien sin número o un emisor—,
-- lo casado con la cuenta personal de Edgar cuando lo era, o un asiento
-- que tiene enfrente otra cuenta propia o el patrimonio del accionista
-- —ahí también cuenta el cheque, o un tercero—. Lo demás —el cobro de un
-- cliente, un gasto, un proveedor, sin nada de eso— nunca se contradice.
-- Así, con un año de banco, la revisión entera no tarda 4 s más.)
create or replace function public.fn_banco_criterio_casados(p_cuenta text default null, p_desde date default null,
                                                            p_hasta date default null)
returns table (movimiento_id uuid, casado_id uuid, cuenta text, fecha date, monto numeric, descripcion text, clase text,
               regla text, contradice text)
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  r     record;
  v_c   jsonb;
  v_ptr text := (select d.patron from banco_descriptores d where d.clave = 'transferencia');
  v_ppt text := (select d.patron from banco_descriptores d where d.clave = 'pago_tarjeta');
  -- (los bancos, y las cuentas propias y las del patrimonio, una vez y
  -- escritas en una consulta —las de fn_banco_tipo_cuenta, fn_banco_es_propia
  -- y fn_banco_es_accionista—: preguntarlo fila por fila eran 0,35 s con un
  -- año de banco, y cuenta por cuenta, con sus funciones, 7 ms por llamada,
  -- y la conciliación la llama en cada cálculo)
  v_caja text := fn_banco_caja();
  v_ban text[] := array(select c.codigo from cuentas c
                         where left(c.codigo, 2) = '10' and c.tipo = 'activo' and c.saldo_normal = 'debe'
                           and c.regla_obra = 'prohibida' and c.codigo <> v_caja);
  v_esp text[] := v_ban || array(select c.codigo from cuentas c
                                  where (left(c.codigo, 5) = '2100-' and c.tipo = 'pasivo' and c.saldo_normal = 'haber'
                                         and exists (select 1 from tarjetas t where t.cuenta = c.codigo))
                                     or c.tipo = 'capital' or c.etiqueta_fiscal in ('accionista', 'distribucion'));
  v_rxt text := (select '(^| )(' || string_agg(t.ultimos4, '|') || ')( |$)' from tarjetas t
                  where t.activa and t.ultimos4 ~ '^[0-9]{4}$');
begin
  for r in select m.id, m.cuenta, m.fecha, m.monto, m.descripcion, bc.id as cid, bc.clase, bc.regla
             from banco_casados bc
             join movimientos_banco m on m.id = bc.movimiento_id
             left join asientos a on a.id = bc.asiento_id
            where bc.deshecho_el is null and bc.clase not in ('recibo', 'devolucion', 'regla')
              and m.estado in ('casado', 'en_transito')
              and (p_cuenta is null or m.cuenta = p_cuenta)
              and (p_desde is null or m.fecha >= p_desde) and (p_hasta is null or m.fecha <= p_hasta)
              and nullif(btrim(bc.motivo, E' \t\r\n\f' || chr(11)), '') is null
              and not (a.origen_tabla = 'movimientos_banco' and a.origen_id = m.id::text
                       and nullif(btrim(a.procedencia->>'motivo_edgar', E' \t\r\n\f' || chr(11)), '') is not null)
              and (coalesce(m.tipo_banco, '') = 'XFER'
                   or coalesce(coalesce(m.desc_norm, '') ~* v_ptr, false)
                   or (m.monto < 0 and m.cuenta = any (v_ban)
                       and (coalesce(coalesce(m.desc_norm, '') ~* v_ppt, false)
                            or coalesce(coalesce(m.desc_norm, '') ~ v_rxt, false)))
                   or bc.otro_lado->>'clase' = 'personal'
                   or (a.origen_tabla = 'movimientos_banco' and a.origen_id = m.id::text and a.procedencia ? 'cuenta_personal')
                   or exists (select 1 from asiento_lineas l
                               where l.asiento_id = bc.asiento_id and l.cuenta <> m.cuenta and l.cuenta = any (v_esp)))
            order by m.cuenta, m.fecha, m.id loop
    v_c := fn_banco_criterio_casado(r.cid);
    if v_c->>'contradice' is not null and v_c->>'motivo' is null then
      movimiento_id := r.id; casado_id := r.cid; cuenta := r.cuenta; fecha := r.fecha; monto := r.monto;
      descripcion := r.descripcion; clase := r.clase; regla := r.regla; contradice := v_c->>'contradice';
      return next;
    end if;
  end loop;
end $$;
revoke execute on function public.fn_banco_criterio_casados(text, date, date) from public, anon, authenticated, service_role;

-- (Ronda 4b) ¿UNA CUENTA DEL PATRIMONIO DEL ACCIONISTA? El capital (3xxx:
-- 3000, 3100 aportaciones, 3200 distribuciones, 3900) y las del accionista
-- por su etiqueta de c1 (1130 la cuenta por cobrar al accionista, 2900 el
-- préstamo del accionista). El dinero del banco que va a una de ellas pide
-- su motivo escrito (en una S-corp cuenta para la base de Edgar y sus
-- distribuciones), salvo que el banco nombre una cuenta personal de Edgar
-- dada de alta (fn_banco_personal_de).
create or replace function public.fn_banco_es_accionista(p_cuenta text)
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select exists (select 1 from cuentas c
                  where c.codigo = p_cuenta and (c.tipo = 'capital' or c.etiqueta_fiscal in ('accionista', 'distribucion')))
$$;
revoke execute on function public.fn_banco_es_accionista(text) from public, anon, authenticated, service_role;

-- (Ronda 4b) ¿QUÉ EXPLICA HOY ESTE DEPÓSITO? La regla del cuadre 52
-- (fn_banco_control: «depósitos nunca a ingreso»), escrita aquí para que la
-- bandeja y fn_banco_clasificar la apliquen ANTES de postear: un cobro
-- anotado, sin su depósito, por el mismo monto y en su ventana (de 30 días
-- antes a 3 después), o una factura (de hasta 3 días después, no anulada)
-- abierta por ese monto: su cuenta por cobrar, su retención o las dos. En
-- palabras, o nulo. Solo en un banco: un abono en una tarjeta no es el
-- cobro de un cliente. p_facturas: las facturas abiertas del contexto
-- (fn_banco_contexto_facturas), si ya se leyeron. Antes la bandeja ofrecía
-- botones que lo clasificaban sin motivo (el préstamo del accionista, una
-- devolución) y el control se ponía en rojo con solo pulsarlos.
create or replace function public.fn_banco_deposito_explicado(m public.movimientos_banco, p_facturas jsonb default null)
returns text
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v text;
begin
  if not (m.monto > 0 and left(m.cuenta, 2) = '10') then
    return null;
  end if;
  select format('el cobro del %s por %s (anotado, sin su depósito)', cb.fecha, cb.monto) into v
    from cobros cb
   where cb.estado = 'vigente' and cb.movimiento_id is null and cb.cuenta = m.cuenta and cb.monto = m.monto
     and cb.fecha between m.fecha - 30 and m.fecha + 3
   order by cb.fecha, cb.id
   limit 1;
  if v is not null then
    return v;
  end if;
  if jsonb_typeof(p_facturas) = 'array' then
    select format('la factura #%s (%s), abierta por %s', x->>'num', x->>'proyecto_id', (x->>'s1')::numeric + (x->>'s2')::numeric)
      into v
      from jsonb_array_elements(p_facturas) x
     where (x->>'fecha')::date <= m.fecha + 3
       and m.monto in ((x->>'s1')::numeric, (x->>'s2')::numeric, (x->>'s1')::numeric + (x->>'s2')::numeric)
     order by (x->>'id')::bigint
     limit 1;
  else
    select format('la factura #%s (%s), abierta por %s', f.num, f.proyecto_id, ab.s1 + ab.s2) into v
      from facturas f
      cross join lateral (
        select coalesce(sum(lf.monto) filter (where lf.cuenta = (select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc')), 0) as s1,
               coalesce(sum(lf.monto) filter (where lf.cuenta = (select pc.cuenta from puente_cuentas pc
                                                                  where pc.rol = 'retencion_cxc')), 0) as s2
          from asiento_lineas lf
         where lf.partida_tabla = 'facturas' and lf.partida_id = f.id::text) ab
     where f.fecha <= m.fecha + 3 and f.monto >= m.monto and coalesce(f.estado, '') <> 'anulada'
       and m.monto in (ab.s1, ab.s2, ab.s1 + ab.s2)
     order by f.id
     limit 1;
  end if;
  return v;
end $$;
revoke execute on function public.fn_banco_deposito_explicado(public.movimientos_banco, jsonb)
  from public, anon, authenticated, service_role;

-- EL NÚMERO DE UN CHEQUE: el que dice el banco (CHECKNUM), o, si no lo
-- dice, el que trae la descripción («CHECK 1043», «CHK #1043»). Algunos
-- bancos no mandan CHECKNUM y el número solo va en NAME: antes ese cheque
-- no casaba con su partida de la apertura (por su número) ni tenía la
-- ventana de un cheque. Sin ceros a la izquierda. (La misma expresión
-- regular, escrita, en fn_banco_pool: allí va fila por fila.)
-- (Ronda 4c) «TO CHK ...7781» o «FROM CHK ...4392» no es un cheque: es la
-- cuenta de cheques («checking») que nombra una transferencia. Antes se
-- leía como el cheque 7781, y en los primeros 30 días, con la apertura sin
-- conciliar, esa transferencia llevaba el aviso de la apertura como un
-- cheque. CHK o CK detrás de TO o FROM se quitan antes de buscar el
-- número; un cheque de verdad («CHECK 1042», «CHK 1042», «CHECK # 1042»)
-- se lee igual que antes.
create or replace function public.fn_banco_cheque_num(p_cheque text, p_desc text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select coalesce(nullif(ltrim(fn_banco_limpio(p_cheque), '0'), ''),
                  substring(regexp_replace(fn_banco_norm(p_desc), '(^| )(TO|FROM) (CHK|CK) ', ' ', 'g')
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

-- ¿LO DEPOSITA UN PROCESADOR DE TARJETAS? (QuickBooks Payments, Stripe,
-- Square…: lo dice su descripción o su nota, normalizadas.) Solo entonces
-- lo que le falta al depósito para cubrir sus facturas puede ser una
-- comisión sin más; si no, puede ser un pago parcial (fn_banco_proponer,
-- 11, y fn_banco_cobrar: con su motivo). Ronda 4.
create or replace function public.fn_banco_procesador(p_txt text)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  select coalesce(p_txt ~ '(^| )(INTUIT|QBPAYMENTS|QUICKBOOKS|STRIPE|SQUARE|SQ|PAYPAL|CLOVER|BANKCARD|MERCHANT|WORLDPAY)( |$)'
                  or p_txt ~ 'QB PAYMENTS', false)
$$;
revoke execute on function public.fn_banco_procesador(text) from public, anon, authenticated, service_role;

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
--   · (ronda 4) el de una tarjeta que no es de esa cuenta (ni dada de alta
--     en ella ni llegada antes en un OFX o en un lote confirmado): MX004,
--     y dice que lo que no es de la empresa no se sube. Y el estado de
--     cuenta de una tarjeta llega solo a una subcuenta de 2100;
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
  -- (Ronda 4b) El número de una cuenta PERSONAL de Edgar dada de alta
  -- (fn_banco_cuenta_personal) no es de la empresa: su estado de cuenta no
  -- se sube, ni se confirma como de una cuenta del plan.
  if v_u4 is not null and exists (select 1 from banco_cuentas_personales p where p.ultimos4 = v_u4 and p.activa) then
    raise exception using errcode = 'MX004',
      message = format('El archivo es de la cuenta ····%s, que diste de alta como tu cuenta personal (%s): no es de la empresa, y sus '
                       'movimientos no son del libro. Si de verdad es de la empresa, dala de baja como personal antes (select '
                       'fn_banco_cuenta_personal(''%s'', null, false, ''el motivo'');).', v_u4,
                       (select p.nombre from banco_cuentas_personales p where p.ultimos4 = v_u4), v_u4);
  end if;
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
    -- (Ronda 4) Una TARJETA: el número del archivo es el de una tarjeta
    -- activa de ESA cuenta (tarjetas), o ya llegó a ella antes en un estado
    -- de cuenta de verdad (un OFX, o un lote que Edgar confirmó), o es el
    -- con que QuickBooks la nombra en la apertura («Amex Gold (1007)» es la
    -- 2100-2013). Antes solo se miraba en un banco: la Platinum PERSONAL de
    -- Edgar (····1005, en el mismo login de Amex) subida con p_cuenta
    -- '2100-2013' entraba entera a la Gold —sus vuelos y sus compras, a la
    -- bandeja de la empresa y para siempre— y su saldo pasaba a ser «el del
    -- banco» de la Gold.
    if v_u4 is not null and v_de_u4 is null and not coalesce(p_confirmo, false)
       and fn_banco_tipo_cuenta(v_cta) = 'tarjeta'
       and not exists (select 1 from archivos_banco a
                        where a.cuenta = v_cta and a.ultimos4 = v_u4 and a.retirado_el is null
                          and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada))
       and not exists (select 1 from apertura_mapeo_qb m
                        where m.tipo = 'cuenta' and m.cuenta = v_cta and m.nombre_qb ~ ('(^|[^0-9])' || v_u4 || '([^0-9]|$)')) then
      raise exception using errcode = 'MX004',
        message = format('El archivo es de la tarjeta que acaba en %s, y esa no es una tarjeta de %s (%s; sus tarjetas: %s). Si no es '
                         'de la empresa (una tarjeta personal), no se sube: sus movimientos no son del libro y lo que dijo el banco no '
                         'se borra. Si es de la empresa (la reposición de una perdida, una adicional), dala de alta en su cuenta (select '
                         'fn_tarjeta_alta(''%s'', ''%s'', ''el titular'');) y vuelve a subir el archivo.',
                         v_u4, v_cta, coalesce((select c.nombre from cuentas c where c.codigo = v_cta), 'sin nombre'),
                         coalesce((select string_agg('····' || t.ultimos4, ', ' order by t.ultimos4) from tarjetas t
                                    where t.cuenta = v_cta and t.activa), 'ninguna activa'), v_u4, v_cta);
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
      -- (Ronda 4: y si no es de la empresa, que no se suba: antes el mensaje
      -- solo pedía la cuenta, y la tarjeta personal entraba a la que se dijo)
      raise exception using errcode = 'MX004',
        message = format('No sé de qué cuenta es el archivo (la cuenta %s no está dada de alta). Si no es de la empresa (una cuenta o '
                         'una tarjeta personal), no se sube: sus movimientos no son del libro y lo que dijo el banco no se borra. Si es '
                         'de la empresa: una tarjeta se da de alta en su cuenta (fn_tarjeta_alta) y el archivo va solo; el primer '
                         'estado de cuenta de un banco dice su cuenta del plan con p_cuenta (''1010'' para Chase, ''1030'' para la '
                         'reserva), y las siguientes veces ya lo sabré.', coalesce('····' || v_u4, 'que trae'));
    end if;
  end if;
  if fn_puente_cuenta_mal(v_cta) is not null then
    raise exception using errcode = 'MX004', message = format('La cuenta del archivo: %s.', fn_puente_cuenta_mal(v_cta));
  end if;
  v_tipo := fn_banco_tipo_cuenta(v_cta);
  -- (Ronda 4) Un estado de cuenta de tarjeta llega solo a una tarjeta de
  -- crédito de la empresa: una subcuenta de 2100 (Tarjetas de crédito). Una
  -- tarjeta dada de alta en otro pasivo —la personal de Edgar en 2900, para
  -- que sus tickets de la empresa vayan a «préstamo del accionista»— no
  -- recibe su estado de cuenta: sus compras personales entrarían al libro.
  -- (Ronda 4b: esa cuenta ya no es «propia» —fn_banco_es_propia—, y se
  -- dice esto antes que «no es un banco ni una tarjeta».)
  if (v_tipo = 'tarjeta' or (v_tipo is null and exists (select 1 from tarjetas t where t.cuenta = v_cta)))
     and left(v_cta, 5) <> '2100-' then
    raise exception using errcode = 'MX004',
      message = format('%s (%s) no es una tarjeta de crédito de la empresa (una subcuenta de 2100, Tarjetas de crédito): ahí no llega '
                       'un estado de cuenta. Si es una tarjeta personal, su estado de cuenta no se sube: sus tickets de la empresa ya '
                       'entran por la app.', v_cta, coalesce((select c.nombre from cuentas c where c.codigo = v_cta), 'sin nombre'));
  end if;
  if v_tipo is null then
    raise exception using errcode = 'MX004',
      message = format('%s no es una cuenta de banco (10xx) ni una tarjeta de la empresa (tarjetas): ahí no llega un estado de '
                       'cuenta.%s', v_cta,
                       -- (ronda 4c: la línea de crédito o un préstamo: su número se da
                       -- de alta con un lote vacío)
                       case when fn_banco_es_deuda(v_cta)
                            then format(' Si quieres que la bandeja reconozca su número (el dinero que va o viene de %s), dalo de alta con '
                                        'un lote vacío, sin saldo: select fn_banco_importar_filas(''{"origen": "mano", "cuenta": "%s", '
                                        '"ultimos4": "…", "confirmo_cuenta": true, "nombre": "su número", "filas": []}'');', v_cta, v_cta)
                            else '' end);
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
-- y espera: nunca dos veces en silencio, y nunca se pierde en silencio.
-- Por cada fila, en este orden:
--   0. su id ya salió antes EN ESTE MISMO archivo: con los mismos datos es
--      la misma fila repetida (una); con otros, el banco repitió el id para
--      otro movimiento (entra como nuevo, ver 1);
--   1. su id (el FITID del archivo, el de Plaid) ya está en esa cuenta y ese
--      origen, con la misma fecha, el mismo monto y la misma descripción
--      (la de Plaid puede cambiar: su id manda), y esta importación no lo
--      usó ya: es el mismo movimiento (el archivo importado otra vez, o dos
--      que se solapan) → repetida. Si no, ese id ya es de otro movimiento y
--      esta fila entra como nueva, con el id solo de referencia:
--        · MARCADA «posible duplicado» de aquel (y espera a Edgar) si puede
--          ser el mismo corregido: en Plaid SIEMPRE (su transaction_id es
--          de una sola transacción: la que vuelve con otra fecha u otro
--          monto es la misma, «modified»); en un archivo, con el mismo monto
--          a 3 días o menos (el banco la fechó otro día), o el mismo día con
--          otro monto o con OTRA descripción (el banco que numera sus FITID
--          por archivo: el 3 de hoy no es el 3 de ayer). (Ronda 4: antes,
--          con la fecha o el monto corregidos entraba como otro movimiento
--          sin marca —el gasto dos veces—, y con la misma fecha y monto y
--          otra descripción se daba por repetida —la otra compra se
--          perdía—.)
--        · sin marca (y con su aviso) si no se le parece: otra fecha y otro
--          monto (el emisor que numera por archivo);
--      (y la CORRECCIÓN del banco, CORRECTACTION REPLACE: entra marcada
--      «posible duplicado» del movimiento que corrige, su CORRECTFITID;
--      ronda 4);
--   2. hay un movimiento de esa cuenta con la misma fecha, el mismo monto y
--      la misma descripción normalizada que no tiene todavía un id de este
--      origen (entró por el otro camino: por Plaid si esta es del archivo,
--      o por archivo si esta es de Plaid; o sin id), y que esta misma
--      importación no usó ya → es él: repetida, y se le apunta este id. Y
--      el MISMO CHEQUE (su número y su monto, a 5 días o menos) que entró
--      por el otro camino es el mismo movimiento → repetida. (Ronda 4: el
--      mismo cheque con OTRO id de este mismo camino, o en una fila escrita
--      a mano, no se da por repetido: entra «posible duplicado» y espera.
--      El cheque que rebota y se presenta otra vez son dos cargos de
--      verdad, y antes el segundo se perdía sin aviso;)
--   3. si no, entra marcado «posible duplicado de …» y NO se casa hasta que
--      Edgar diga si es el mismo (fn_banco_duplicado) cuando hay uno de esa
--      cuenta que esta importación no usó ya y que: (a) tiene el mismo
--      monto, a 3 días o menos, y entró por el otro camino (Plaid y el
--      archivo no lo fechan ni lo escriben igual: con otra descripción o con
--      la misma y otro día); (b) tiene la misma fecha, el mismo monto y la
--      misma descripción y entró por este camino con OTRO id (el banco
--      cambió el FITID entre dos descargas que se solapan); o (c) tiene el
--      mismo número de cheque con otro monto. (Ronda 4: también uno de
--      antes del corte, ignorado: el cargo del 30-sep que la descarga
--      siguiente trae fechado el 1-oct;)
--   4. si no, es nuevo.
-- Dos cafés iguales el mismo día en el mismo archivo son dos: nada casa
-- con lo que entra en la misma importación, y el paso 2 y el 3 no usan dos
-- veces el mismo movimiento.
-- Lo de antes del corte (el 30-sep y antes) entra ignorado: está en
-- QuickBooks y en el saldo de apertura (si seguía en tránsito al 30-sep, lo
-- dice la conciliación de apertura). Un movimiento en 0, ignorado también.
-- LO QUE SE QUITA (ronda 4): el movimiento que el banco borra
-- (CORRECTACTION DELETE en un OFX) o que Plaid quita («quitadas» en su
-- lote). Queda escrito en sus ids («quitada:<id>», con el archivo que lo
-- dijo); pendiente, se ignora con ese motivo; casado, sigue casado y lo
-- dicen la bandeja y el control (des-casarlo lo deja ignorado). Antes el
-- borrado seguía vivo, y Plaid no tenía cómo decirlo.
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
-- (Ronda 4) DE QUIÉN ES LO QUITADO: el archivo o el lote que dijo que un
-- movimiento se quita (su marca «quitada:<id>» en movimientos_banco_ids),
-- en palabras; nulo si nadie lo quitó. La usa des-casar; la bandeja y el
-- control la escriben en línea (la app no ejecuta las funciones internas).
create or replace function public.fn_banco_quitada(p_mov uuid)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select format('%s lo quitó (%s «%s» del %s)', case when a.formato = 'plaid' then 'Plaid' else 'el banco' end,
                case when a.formato = 'plaid' then 'su lote' else 'su archivo' end, coalesce(a.nombre, a.id::text),
                to_char(a.importado_el at time zone 'America/New_York', 'YYYY-MM-DD'))
    from movimientos_banco_ids i
    join archivos_banco a on a.id = i.archivo_id
   where i.movimiento_id = p_mov and i.id_externo like 'quitada:%'
   order by i.visto_el
   limit 1
$$;
revoke execute on function public.fn_banco_quitada(uuid) from public, anon, authenticated, service_role;

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
  v_porid   text;
  v_gasta   boolean;
  v_estado  text;
  v_motivo  text;
  v_nuevo   int := 0;
  v_rep     int := 0;
  v_posib   int := 0;
  v_antes   int := 0;
  v_cero    int := 0;
  v_reus    int := 0;
  v_reus_tx text[] := '{}';
  v_rdup    int := 0;
  v_rdup_tx text[] := '{}';
  v_ncor    int := 0;
  v_cor_tx  text[] := '{}';
  v_nquit   int := 0;
  v_quit_tx text[] := '{}';
  v_leidas  int := 0;
  v_avisos  jsonb := coalesce(p_leido->'avisos', '[]'::jsonb);
  v_iguales jsonb;
  v_ult     date;
  v_q       jsonb;
  v_qm      movimientos_banco;
  v_qtx     text;
  v_quitar  jsonb := '[]'::jsonb;
  v_saldo   numeric := nullif(p_leido->>'saldo', '')::numeric;
  v_salal   date := nullif(p_leido->>'saldo_al', '')::date;
  v_otros   text;
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
             fn_banco_limpio(t.x->>'id') as ext, fn_banco_limpio(t.x->>'corrige') as corrige
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
    v_porid := null;
    v_gasta := true;
    -- 0. su id ya salió antes en este mismo archivo
    if r.primera is not null and r.primera < r.ord then
      if r.p_fecha = r.fecha and r.p_monto = r.monto and r.p_dn = r.dn then
        v_rep := v_rep + 1;
        continue;
      end if;
      v_reusa := true;
    end if;
    -- 1. su id ya está (en la base). (Por su llave, primero el id y después
    -- el movimiento: con un join, y la tabla con las estadísticas de vacía,
    -- el planificador recorría todos los ids de la cuenta en cada fila. Por
    -- lo mismo, abajo, las ventanas de fecha van como rangos y el monto
    -- fuera del «o»: cada búsqueda, por índice.)
    if r.ext is not null and not v_reusa then
      select m.* into v_mm
        from movimientos_banco m
       where m.id = (select i.movimiento_id from movimientos_banco_ids i
                      where i.cuenta = p_cuenta and i.origen = p_origen and i.id_externo = r.ext);
      if found then
        if v_mm.fecha = r.fecha and v_mm.monto = r.monto and (p_origen = 'plaid' or v_mm.desc_norm = r.dn) then
          v_m := v_mm.id;
        else
          -- ¿el que ya entró antes con ese mismo id reutilizado?
          select m.id into v_m
            from movimientos_banco m
           where m.cuenta = p_cuenta and m.origen = p_origen and m.id_externo = r.ext and m.fecha = r.fecha and m.monto = r.monto
             and (p_origen = 'plaid' or m.desc_norm = r.dn)
             and not (m.id = any (v_usados))
           order by m.importado_el, m.fila
           limit 1;
          if v_m is null then
            -- (el id ya es de otro: esta fila no lo toma; ¿puede ser el mismo
            -- movimiento, corregido? Se marca y espera, sin gastarlo.)
            v_reusa := true;
            if p_origen = 'plaid' or (v_mm.monto = r.monto and r.fecha between v_mm.fecha - 3 and v_mm.fecha + 3)
               or v_mm.fecha = r.fecha then
              v_dup := v_mm.id;
              v_gasta := false;
              v_porid := format('%s: %s %s «%s» (ya estaba el %s por %s%s)', r.ext, r.fecha, r.monto, coalesce(r.descripcion, ''),
                                v_mm.fecha, v_mm.monto,
                                case when v_mm.desc_norm <> r.dn then format(' «%s»', coalesce(v_mm.descripcion, '')) else '' end);
            end if;
          end if;
        end if;
      end if;
    end if;
    -- (Ronda 4) LA CORRECCIÓN DEL BANCO (CORRECTACTION REPLACE): esta fila
    -- sustituye al movimiento de su CORRECTFITID. Entra marcada «posible
    -- duplicado» de él y Edgar decide (si vale la corrección, el corregido
    -- se ignora): nunca como otro cargo callado.
    if v_m is null and v_dup is null and r.corrige is not null then
      select m.* into v_qm
        from movimientos_banco m
       where m.id = (select i.movimiento_id from movimientos_banco_ids i
                      where i.cuenta = p_cuenta and i.origen = p_origen and i.id_externo = r.corrige);
      v_ncor := v_ncor + 1;
      if found then
        v_dup := v_qm.id;
        v_gasta := false;
      end if;
      if cardinality(v_cor_tx) < 5 then
        v_cor_tx := v_cor_tx || format('%s corrige a %s%s', coalesce(r.ext, 'una fila'), r.corrige,
                                       case when v_qm.id is not null then format(' (del %s por %s)', v_qm.fecha, v_qm.monto)
                                            else ', que no entró: entra como nuevo' end);
      end if;
      v_qm := null;
    end if;
    -- 2. el mismo movimiento por el otro camino (o sin id)
    if v_m is null and v_dup is null then
      select m.id into v_m
        from movimientos_banco m
       where m.cuenta = p_cuenta and m.fecha = r.fecha and m.monto = r.monto and m.desc_norm = r.dn
         and not (m.id = any (v_usados))
         and (r.ext is null
              or not exists (select 1 from movimientos_banco_ids i where i.movimiento_id = m.id and i.origen = p_origen))
       order by m.importado_el, m.archivo_id, m.fila
       limit 1;
    end if;
    -- 2. el mismo cheque (su número y su monto), que entró por el otro
    -- camino: repetida. (Ronda 4) Con OTRO id de este mismo camino, o en una
    -- fila escrita a mano, puede ser otro cargo (el cheque que rebotó y se
    -- cobró otra vez): «posible duplicado», nunca descartada en silencio.
    if v_m is null and v_dup is null and r.cheque is not null and ltrim(r.cheque, '0') <> '' then
      select m.* into v_qm
        from movimientos_banco m
       where m.cuenta = p_cuenta and m.cheque is not null and ltrim(m.cheque, '0') = ltrim(r.cheque, '0')
         and m.monto = r.monto and m.fecha between r.fecha - 5 and r.fecha + 5
         and not (m.id = any (v_usados))
       order by abs(m.fecha - r.fecha), m.importado_el, m.fila
       limit 1;
      if v_qm.id is not null then
        if p_origen <> 'mano'
           and not exists (select 1 from movimientos_banco_ids i where i.movimiento_id = v_qm.id and i.origen = p_origen) then
          v_m := v_qm.id;
        elsif r.monto <> 0 and r.fecha >= v_corte then
          v_dup := v_qm.id;
        end if;
      end if;
      v_qm := null;
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
    if v_dup is null and r.monto <> 0 and r.fecha >= v_corte then
      -- (El monto y la ventana, fuera del «o»: los dos casos los piden, y
      -- así la búsqueda va siempre por el índice de monto y fecha. Lo de
      -- antes del corte, ignorado, también cuenta: ronda 4.)
      select m.id into v_dup
        from movimientos_banco m
       where m.cuenta = p_cuenta and m.monto = r.monto and m.fecha between r.fecha - 3 and r.fecha + 3
         and (m.estado <> 'ignorado' or m.fecha < v_corte) and not (m.id = any (v_usados))
         and ((r.ext is null
               or not exists (select 1 from movimientos_banco_ids i where i.movimiento_id = m.id and i.origen = p_origen))
              or (m.fecha = r.fecha and m.desc_norm = r.dn))
       order by abs(m.fecha - r.fecha), m.importado_el, m.fila
       limit 1;
      if v_dup is null and r.cheque is not null and ltrim(r.cheque, '0') <> '' then
        select m.id into v_dup
          from movimientos_banco m
         where m.cuenta = p_cuenta and m.cheque is not null and ltrim(m.cheque, '0') = ltrim(r.cheque, '0')
           and (m.estado <> 'ignorado' or m.fecha < v_corte) and m.fecha between r.fecha - 60 and r.fecha + 60
           and not (m.id = any (v_usados))
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
      v_dup := null;
    elsif r.monto = 0 then
      v_estado := 'ignorado';
      v_motivo := 'El banco lo trae en 0: no mueve dinero.';
      v_cero := v_cero + 1;
      v_dup := null;
    elsif v_dup is not null then
      v_motivo := 'posible_duplicado';
      v_posib := v_posib + 1;
      if v_gasta then
        v_usados := v_usados || v_dup;
      end if;
    end if;
    if v_reusa then
      if v_dup is not null then
        v_rdup := v_rdup + 1;
        if cardinality(v_rdup_tx) < 5 then
          v_rdup_tx := v_rdup_tx || coalesce(v_porid, format('%s: %s %s «%s»', r.ext, r.fecha, r.monto, coalesce(r.descripcion, '')));
        end if;
      else
        v_reus := v_reus + 1;
        if cardinality(v_reus_tx) < 5 then
          v_reus_tx := v_reus_tx || format('%s: %s %s', r.ext, r.fecha, r.monto);
        end if;
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
                                            'el mismo (otra fecha y otro monto), así que entraron como movimientos nuevos, con ese id '
                                            'solo de referencia.', v_reus, array_to_string(v_reus_tx, '; '),
                                            case when v_reus > 5 then '; …' else '' end));
  end if;
  if v_rdup > 0 then
    v_avisos := v_avisos || to_jsonb(case when p_origen = 'plaid'
      then format('Plaid volvió a mandar %s transacción(es) que ya entraron, con otra fecha u otro monto (%s%s): es la misma '
                  'transacción, corregida («modified»). Entraron marcadas «posible duplicado» de la que ya estaba: si no cambió nada '
                  'que importe, di que es la misma (fn_banco_duplicado, true: no entra otra vez); si vale la nueva (el monto '
                  'corregido), di que no es la misma (false) e ignora la vieja (fn_banco_ignorar; si ya está casada, des-cásala '
                  'antes).', v_rdup, array_to_string(v_rdup_tx, '; '), case when v_rdup > 5 then '; …' else '' end)
      else format('El banco repitió el identificador (FITID) de %s movimiento(s) que ya entraron, con otra fecha, otro monto u otra '
                  'descripción (%s%s): puede ser el mismo, corregido, u otro (un banco que numera sus FITID por archivo). Entraron '
                  'marcados «posible duplicado» (del que ya tenía ese id, o de uno igual): di si es el mismo (fn_banco_duplicado). '
                  'Si es el mismo con el monto corregido, vale el nuevo: di que no es el mismo e ignora el viejo.', v_rdup,
                  array_to_string(v_rdup_tx, '; '), case when v_rdup > 5 then '; …' else '' end) end);
  end if;
  if v_ncor > 0 then
    v_avisos := v_avisos || to_jsonb(format('El banco corrige %s movimiento(s) con este archivo (CORRECTACTION REPLACE: %s%s). Cada '
                                            'corrección entró marcada «posible duplicado» del que corrige: si vale la corrección (lo '
                                            'normal), di que no es el mismo (fn_banco_duplicado, false) e ignora el corregido '
                                            '(fn_banco_ignorar; si ya está casado, des-cásalo antes).', v_ncor,
                                            array_to_string(v_cor_tx, '; '), case when v_ncor > 5 then '; …' else '' end));
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
  -- (Ronda 4) LO QUE SE QUITA: lo que el banco borra (CORRECTACTION DELETE)
  -- y lo que Plaid quita («quitadas»). Se decide aquí (lo dice el archivo,
  -- en sus avisos) y se hace al final: su marca queda en sus ids; pendiente,
  -- se ignora con su motivo (no fue: ignorarlo no toca el libro, tampoco en
  -- un mes conciliado); casado, sigue casado y lo dicen la bandeja y el
  -- control hasta que Edgar lo des-case (y entonces queda ignorado).
  select coalesce(max(c.fecha_corte), v_corte - 1) into v_ult
    from conciliaciones c where c.cuenta = p_cuenta and c.estado = 'confirmada' and c.tipo = 'normal';
  for v_q in select x from jsonb_array_elements(coalesce(p_leido->'borradas', '[]'::jsonb)) x loop
    select m.* into v_qm
      from movimientos_banco m
     where m.id = (select i.movimiento_id from movimientos_banco_ids i
                    where i.cuenta = p_cuenta and i.origen = p_origen and i.id_externo = v_q->>'corrige');
    v_nquit := v_nquit + 1;
    if v_qm.id is null then
      v_qtx := format('%s, que no había entrado: no entra nada', v_q->>'corrige');
    else
      v_quitar := v_quitar || jsonb_build_object('mov', v_qm.id, 'id', v_q->>'corrige', 'ignorar', v_qm.estado = 'pendiente');
      v_qtx := case when v_qm.estado = 'pendiente'
                    then format('%s (%s %s «%s») queda ignorado', v_q->>'corrige', v_qm.fecha, v_qm.monto, coalesce(v_qm.descripcion, ''))
                    when v_qm.estado = 'ignorado'
                    then format('%s (%s %s) ya estaba ignorado', v_q->>'corrige', v_qm.fecha, v_qm.monto)
                    else format('%s (%s %s «%s») está %s%s: des-cásalo (fn_banco_descasar, con su motivo) y queda ignorado',
                                v_q->>'corrige', v_qm.fecha, v_qm.monto, coalesce(v_qm.descripcion, ''), v_qm.estado,
                                case when v_qm.fecha <= v_ult then ' dentro de una conciliación confirmada (reábrela antes)' else '' end) end;
    end if;
    if cardinality(v_quit_tx) < 5 then
      v_quit_tx := v_quit_tx || v_qtx;
    end if;
    v_qm := null;
  end loop;
  if v_nquit > 0 then
    v_avisos := v_avisos || to_jsonb(format('%s quita %s movimiento(s): %s%s.',
                                            case when p_origen = 'plaid' then 'Plaid («removed»)'
                                                 else 'El banco (CORRECTACTION DELETE)' end,
                                            v_nquit, array_to_string(v_quit_tx, '; '), case when v_nquit > 5 then '; …' else '' end));
  end if;
  -- (Ronda 4) EL SALDO QUE NO DICE LO MISMO que otro archivo vivo de esa
  -- cuenta al mismo día: para conciliar vale el del estado de cuenta del
  -- banco (el OFX), y dos del banco que no coinciden piden su motivo y su
  -- documento al conciliar ese día. Se dice ya, al subirlo.
  if v_saldo is not null and v_salal is not null then
    select string_agg(format('%s (%s, «%s»)', a.saldo, case when a.formato in ('ofx_sgml', 'ofx_xml') then 'del banco' else a.formato end,
                             coalesce(a.nombre, a.id::text)), '; ' order by a.importado_el)
      into v_otros
      from archivos_banco a
     where a.cuenta = p_cuenta and a.saldo_al = v_salal and a.saldo is not null and a.retirado_el is null and a.saldo <> v_saldo;
    if v_otros is not null then
      v_avisos := v_avisos || to_jsonb(format(
        'El saldo de este %s (%s al %s) no es el que dice %s ese mismo día: %s. Para conciliar vale el del estado de cuenta del banco '
        '(el OFX); si dos del banco no coinciden, la conciliación de ese día pide su motivo y su documento.',
        case when p_formato in ('ofx_sgml', 'ofx_xml') then 'archivo' else 'lote' end, v_saldo, v_salal,
        case when (select count(*) from archivos_banco a
                    where a.cuenta = p_cuenta and a.saldo_al = v_salal and a.saldo is not null and a.retirado_el is null
                      and a.saldo <> v_saldo) = 1 then 'otro archivo' else 'otros archivos' end, v_otros));
    end if;
  end if;

  -- El archivo, entero y de una vez.
  perform fn_banco_marca('archivo:' || v_arch);
  insert into archivos_banco (id, cuenta, ultimos4, nombre, formato, sha256, texto, desde, hasta, saldo, saldo_al, moneda,
                              filas_leidas, filas_nuevas, filas_repetidas, filas_fuera, duplicados_posibles, avisos, cuenta_confirmada)
  values (v_arch, p_cuenta, v_u4, fn_banco_limpio(p_nombre), p_formato, p_sha, p_texto,
          nullif(p_leido->>'desde', '')::date, nullif(p_leido->>'hasta', '')::date, v_saldo, v_salal, coalesce(p_leido->>'moneda', 'USD'),
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

  -- (lo que se quita, como se decidió arriba)
  for v_q in select x from jsonb_array_elements(v_quitar) x loop
    insert into movimientos_banco_ids (cuenta, origen, id_externo, movimiento_id, archivo_id)
    values (p_cuenta, p_origen, 'quitada:' || (v_q->>'id'), (v_q->>'mov')::uuid, v_arch)
    on conflict do nothing;
    if (v_q->>'ignorar')::boolean then
      perform fn_banco_marca('movimiento:' || (v_q->>'mov'));
      update movimientos_banco
         set estado = 'ignorado', propuesta = null,
             estado_motivo = format('%s «%s» del %s): no fue. No entra.',
                                    case when p_origen = 'plaid' then 'Plaid lo quitó (su lote'
                                         else 'El banco lo borró (CORRECTACTION DELETE de su archivo' end,
                                    coalesce(fn_banco_limpio(p_nombre), v_arch::text), fn_fecha_miami(now()))
       where id = (v_q->>'mov')::uuid and estado = 'pendiente';
      perform fn_banco_marca('archivo:' || v_arch);
    end if;
  end loop;
  perform fn_banco_marca(null);

  return jsonb_strip_nulls(jsonb_build_object(
    'archivo', v_arch, 'ya_estaba', false, 'cuenta', p_cuenta, 'ultimos4', v_u4, 'formato', p_formato,
    'desde', p_leido->>'desde', 'hasta', p_leido->>'hasta', 'saldo', p_leido->>'saldo', 'saldo_al', p_leido->>'saldo_al',
    'filas_leidas', v_leidas + p_fuera, 'filas_nuevas', v_nuevo, 'filas_repetidas', v_rep, 'filas_fuera', p_fuera,
    'duplicados_posibles', v_posib, 'fitid_reusados', case when v_reus + v_rdup > 0 then v_reus + v_rdup end,
    'correcciones', case when v_ncor > 0 then v_ncor end, 'quitados', case when v_nquit > 0 then v_nquit end,
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
  -- (las filas con las que el banco BORRA otra —CORRECTACTION DELETE— no son
  -- movimientos: cuentan como fuera, y el importador quita el corregido)
  return fn_banco_importar_interno(v_cta, 'archivo', v_leido->>'formato', p_nombre, p_texto, v_sha, v_leido,
                                   coalesce(jsonb_array_length(v_leido->'borradas'), 0));
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
     where k not in ('id', 'fecha', 'fecha_transaccion', 'monto', 'plaid_monto', 'descripcion', 'memo', 'tipo', 'cheque', 'pendiente',
                     'moneda');
    if v_sobra is not null then
      raise exception using errcode = '22023', message = format('Fila %s: clave desconocida: %s.', v_i, v_sobra);
    end if;
    -- (Ronda 4: la moneda de la fila, si se dice —Plaid la da en
    -- iso_currency_code—: el libro va en dólares, como el CURDEF de un QFX)
    if upper(fn_banco_limpio(v_f->>'moneda')) is distinct from 'USD' and fn_banco_limpio(v_f->>'moneda') is not null then
      raise exception using errcode = 'MX009',
        message = format('Fila %s: está en %s, y el libro va en dólares (USD). Manda el monto en dólares.', v_i,
                         upper(fn_banco_limpio(v_f->>'moneda')));
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
-- (Ronda 4) LO QUE PLAID QUITA: "quitadas": ["id de Plaid", …] (lo que su
-- /transactions/sync devuelve en «removed»). El movimiento con ese id, si
-- está pendiente, queda ignorado con el motivo «Plaid lo quitó» (con
-- rastro); si ya está casado, sigue casado y la bandeja y el control lo
-- dicen (des-casarlo lo deja ignorado). Y la misma transacción que Plaid
-- vuelve a mandar con otra fecha u otro monto («modified», el mismo id)
-- entra marcada «posible duplicado» de la que ya estaba (ver 3). Antes el
-- lote no podía decirlo: la quitada se quedaba viva y su reemplazo entraba
-- como otra.
-- (Ronda 4) EL SALDO VA CON SU FECHA: "saldo" o "plaid_saldo" sin
-- "saldo_al" no entra (22023), como el LEDGERBAL sin DTASOF de un QFX
-- (antes se guardaba sin fecha y nada lo usaba nunca). Y "moneda" (del
-- lote o de una fila), si se dice, es USD: otra moneda no entra (MX009).
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
  v_registro boolean := false;
  v_res    jsonb;
  v_mid    uuid;
  v_nreh   int := 0;
begin
  perform fn_banco_exigir_dueno();
  if p_lote is null or jsonb_typeof(p_lote) <> 'object' then
    raise exception using errcode = '22023', message = 'El lote llega como un objeto JSON con sus filas.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra
    from jsonb_object_keys(p_lote) k
   where k not in ('origen', 'cuenta', 'ultimos4', 'nombre', 'saldo', 'plaid_saldo', 'saldo_al', 'desde', 'hasta', 'filas',
                   'confirmo_cuenta', 'quitadas', 'moneda');
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
  -- (Ronda 4) La moneda del lote, si se dice: dólares.
  if fn_banco_limpio(p_lote->>'moneda') is not null and upper(fn_banco_limpio(p_lote->>'moneda')) <> 'USD' then
    raise exception using errcode = 'MX009',
      message = format('El lote está en %s, y el libro va en dólares (USD).', upper(fn_banco_limpio(p_lote->>'moneda')));
  end if;
  -- (Ronda 4) Lo que Plaid quitó: una lista de sus ids (solo de Plaid).
  if p_lote ? 'quitadas' then
    if v_origen <> 'plaid' then
      raise exception using errcode = '22023',
        message = '"quitadas" es de Plaid (lo que su sincronización devuelve en «removed»): un lote de csv o a mano no quita nada '
                  '(lo que no es de la empresa se ignora con su motivo, fn_banco_ignorar).';
    end if;
    if jsonb_typeof(p_lote->'quitadas') is distinct from 'array'
       or exists (select 1 from jsonb_array_elements(p_lote->'quitadas') x
                   where jsonb_typeof(x) <> 'string' or fn_banco_limpio(x #>> '{}') is null) then
      raise exception using errcode = '22023', message = '"quitadas" es una lista de ids de Plaid (transaction_id), cada uno un texto.';
    end if;
  end if;
  -- (Ronda 4) El saldo, con su fecha: sin ella no sirve para conciliar.
  if (fn_banco_limpio(p_lote->>'saldo') is not null or fn_banco_limpio(p_lote->>'plaid_saldo') is not null)
     and fn_banco_limpio(p_lote->>'saldo_al') is null then
    raise exception using errcode = '22023',
      message = 'El saldo del lote va con su fecha ("saldo_al": "AAAA-MM-DD", el día de ese saldo): sin ella no se puede conciliar con '
                'él (un QFX sin la fecha de su saldo tampoco entra).';
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
  -- (Ronda 4c) EL NÚMERO DE UNA DEUDA DE LA EMPRESA (la línea de crédito
  -- 2510, un préstamo 25xx: fn_banco_es_deuda). No trae estado de cuenta a
  -- esta app, pero el banco lo nombra cuando el dinero va o viene de ella
  -- («ONLINE TRANSFER FROM ACCT ...8899»). Se da de alta con un lote VACÍO
  -- a su cuenta, confirmado (sin filas y sin saldo), como el de la reserva
  -- antes de su primer estado de cuenta, y EL CRITERIO lo reconoce como de
  -- la empresa (fn_banco_otro_lado: «propia», de tipo deuda). Un número que
  -- ya es de otra cuenta, de una tarjeta o de una cuenta personal dada de
  -- alta, no (MX004). Antes la bandeja lo aconsejaba y el lote daba MX004
  -- («no es una cuenta de banco ni una tarjeta»): la línea de crédito no se
  -- reconocía nunca.
  if v_conf and jsonb_array_length(p_lote->'filas') = 0 and fn_banco_limpio(p_lote->>'saldo') is null
     and fn_banco_limpio(p_lote->>'plaid_saldo') is null and not (p_lote ? 'quitadas')
     and fn_banco_es_deuda(fn_banco_limpio(p_lote->>'cuenta')) then
    v_cta := fn_banco_limpio(p_lote->>'cuenta');
    if v_u4 !~ '^[0-9]{4}$' then
      raise exception using errcode = '22023',
        message = format('Los 4 últimos del número de %s, como los dice el banco («ACCT ...8899» es "8899"); llegó «%s».', v_cta, v_u4);
    end if;
    if fn_banco_personal_de(v_u4) is not null then
      raise exception using errcode = 'MX004',
        message = format('····%s es tu cuenta personal (%s, dada de alta): no es de la empresa. Si de verdad es de %s, dala de baja como '
                         'personal antes (fn_banco_cuenta_personal(''%s'', null, false, ''el motivo'')).', v_u4,
                         fn_banco_personal_de(v_u4), v_cta, v_u4);
    end if;
    if coalesce(fn_banco_numero_de(v_u4), v_cta) <> v_cta
       or exists (select 1 from tarjetas t where t.ultimos4 = v_u4 and t.activa) then
      raise exception using errcode = 'MX004',
        message = format('····%s ya es de %s: un número es de una sola cuenta.', v_u4,
                         coalesce(fn_banco_numero_de(v_u4),
                                  (select t.cuenta from tarjetas t where t.ultimos4 = v_u4 and t.activa order by t.cuenta limit 1)));
    end if;
    v_registro := true;
  else
    v_cta := fn_banco_cuenta_de(p_lote->>'cuenta', v_u4, null, v_conf);
  end if;
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
    -- (ronda 4d: abajo se rehacen las propuestas que nombran ese número, con
    -- el candado del casado, que va antes que el de la cuenta: el mismo
    -- orden que fn_banco_archivo_retirar)
    perform pg_advisory_xact_lock(820261001, hashtext('casar'));
  end if;
  perform pg_advisory_xact_lock(820261001, hashtext('cuenta:' || v_cta));
  v_res := fn_banco_importar_interno(v_cta, v_origen, v_origen, p_lote->>'nombre', v_texto, v_sha,
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
      -- (lo que Plaid quitó: el importador lo quita, ver 3)
      'borradas', (select jsonb_agg(jsonb_build_object('corrige', fn_banco_limpio(x #>> '{}')) order by o)
                     from jsonb_array_elements(case when jsonb_typeof(p_lote->'quitadas') = 'array' then p_lote->'quitadas'
                                                    else '[]'::jsonb end) with ordinality as q(x, o)),
      'avisos', case when jsonb_array_length(v_avisos) > 0 then v_avisos end)),
    v_fuera, v_conf);
  -- (ronda 4c: el número de una deuda no se «casa» por su cuenta: lo que lo
  -- nombra está en los bancos, y su propuesta se rehace en el «Casar» de
  -- todo)
  if v_registro then
    v_res := v_res || jsonb_build_object('deuda', v_cta, 'siguiente', 'select fn_banco_casar_todo();');
  end if;
  -- (Ronda 4d) EL NÚMERO RECIÉN DADO DE ALTA: las propuestas de lo pendiente
  -- de OTRAS cuentas que lo nombra (en su descripción o su nota) se rehacen
  -- ya, como al dar de alta una cuenta personal (fn_banco_cuenta_personal):
  -- antes la bandeja seguía enseñando hasta el siguiente «Casar» los botones
  -- de cuando ese número no se conocía (y pulsados fallaban, o lo dejaban
  -- como otra cosa) (L01). Lo de esta cuenta lo casa su «Casar», como
  -- siempre.
  if v_conf and v_u4 ~ '^[0-9]{4}$' then
    for v_mid in select x.id from movimientos_banco x
                  where x.estado = 'pendiente' and x.fecha >= fn_puente_corte() and x.cuenta <> v_cta
                    and (x.desc_norm ~ ('(^| )X*' || v_u4 || '( |$)')
                         or fn_banco_norm(x.memo) ~ ('(^| )X*' || v_u4 || '( |$)'))
                  order by x.fecha, x.id loop
      perform fn_banco_casar_interno(null, null, v_mid, true);
      v_nreh := v_nreh + 1;
    end loop;
    if v_nreh > 0 then
      v_res := v_res || jsonb_build_object('rehechas', v_nreh,
                                           'aviso_rehechas', format('Rehecha la propuesta de %s movimiento(s) pendiente(s) de otras '
                                                                    'cuentas que nombran ····%s.', v_nreh, v_u4));
    end if;
  end if;
  return v_res;
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
  -- (ronda 4d: con lo que decía el banco del otro lado al casarlo, salvo en
  -- lo que nunca lo nombra: un ticket, una regla fija, una devolución)
  insert into banco_casados (id, movimiento_id, clase, referencia, asiento_id, posteado, regla, automatico, motivo, otro_lado)
  values (v_id, p_mov, p_clase, p_ref, p_asiento, p_posteado, p_regla, p_auto, fn_banco_limpio(p_motivo),
          case when p_clase not in ('recibo', 'regla', 'devolucion') then fn_banco_otro_lado(m) end)
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
  elsif p_clase = 'cuota_prestamo' then
    -- (Ronda 5) La cuota registrada antes que el banco (con el statement)
    -- toma su cargo; la que entró con él (fn_prestamo_cuota) ya lo tiene.
    perform fn_banco_marca('cuota:' || p_ref);
    update prestamo_cuotas set movimiento_id = p_mov
     where id = (case when p_ref ~ '^[0-9a-fA-F-]{36}$' then p_ref::uuid end) and movimiento_id is null and anulada_el is null;
    perform fn_banco_marca(null);
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
-- (Ronda 4b: en plpgsql, la misma consulta —ver fn_banco_caja—: el motor la
-- llama varias veces por ronda en cada «Casar», y en «language sql» se
-- volvía a leer y a planear cada vez. El corte se lee una vez por llamada,
-- en una expresión simple, en vez de en una subconsulta.)
drop function if exists public.fn_banco_pool(text[]);
create or replace function public.fn_banco_pool(p_cuentas text[])
returns table (id uuid, cuenta text, fecha date, ftx date, monto numeric, tipo_banco text, cheque text, dn text, dtxt text)
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_corte date := fn_puente_corte();
begin
  return query
  select m.id, m.cuenta, m.fecha, m.fecha_transaccion, m.monto, m.tipo_banco,
         coalesce(nullif(ltrim(m.cheque, '0'), ''),
                  substring(regexp_replace(m.desc_norm, '(^| )(TO|FROM) (CHK|CK) ', ' ', 'g') from '(?:^| )(?:CHECK|CHK|CHEQUE|CK)(?: NO)? ?#? ?0*([1-9][0-9]{0,9})(?: |$)')),
         m.desc_norm,
         case when m.memo is null then m.desc_norm else btrim(m.desc_norm || ' ' || fn_banco_norm(m.memo)) end
    from movimientos_banco m
   where m.estado = 'pendiente' and m.fecha >= v_corte and m.cuenta = any (p_cuentas)
     and (m.posible_duplicado_de is null or m.duplicado = 'no_es_el_mismo');
end $$;
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
--     (Ronda 4d) Un CHEQUE (con su número) nunca es el otro lado de una
--     transferencia: es el pago a un tercero. Antes el cheque 1234 de Chase
--     por lo mismo que el pase que esperaba en la reserva casaba solo como
--     «la otra mitad», y clasificarlo como lo que era no se podía.
create or replace function public.fn_banco_ventana(p_fecha date, p_ftx date, p_cheque text, p_fdoc date, p_monto numeric,
                                                   p_tr boolean, p_tipo text, p_tr_otra_tipo text, p_texto text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
           when p_tr and p_cheque ~ '^[0-9]+$' and ltrim(p_cheque, '0') <> '' then null
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
-- (Ronda 4b: en plpgsql, la misma consulta: en «language sql» se volvía a
-- leer y a planear en cada llamada —ver fn_banco_caja—.)
create or replace function public.fn_banco_contexto_facturas()
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
begin
  return (
  -- (k, materializada: las dos cuentas se leen UNA vez. Sin «materialized»,
  -- Postgres metía la consulta de k dentro de la de abajo y llamaba a
  -- fn_puente_cuenta_de cuatro veces por cada línea de las facturas: con
  -- un año de banco, de 35 a 40 ms por «Casar» en vez de 15. Ronda 4,
  -- grupo 4.)
  with k as materialized (select fn_puente_cuenta_de('cxc') as cxc, fn_puente_cuenta_de('retencion_cxc') as ret)
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
  );
end $$;
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
-- (Ronda 4b: en plpgsql, la misma consulta: en «language sql» se volvía a
-- leer y a planear en cada «Casar» —ver fn_banco_caja—.)
create or replace function public.fn_banco_contexto(p_facturas boolean default true)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
begin
  return (
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
  -- (ronda 4b: sin las partidas ya saldadas —saldo cero—, que ni se deben
  -- ni están a favor: abajo solo cuentan las de saldo mayor o menor que
  -- cero. Con un año de libro son casi todas —1.960 de 2.131 en
  -- c6-volumen.sh—, y se arrastraban por el resto de la consulta en cada
  -- «Casar»)
  deu1 as materialized (select l.tercero_id, l.partida_tabla, l.partida_id, -sum(l.monto) as saldo
            from asiento_lineas l
            cross join k
           where l.cuenta = k.cxp and l.tercero_tipo = 'proveedor'
           group by l.tercero_id, l.partida_tabla, l.partida_id
          having sum(l.monto) <> 0),
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
    -- (ronda 4c: todos los vigentes, con sus cuentas: el préstamo cuyo
    -- número se dio de alta —EL CRITERIO, una deuda propia— también se
    -- reconoce por él, aunque no tenga descriptor)
    'prestamos', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                    'id', p.id, 'cuenta_banco', p.cuenta_banco, 'descriptor', p.descriptor, 'cuenta', p.cuenta,
                                    'cuenta_largo', p.cuenta_largo))), '[]'::jsonb)
                    from prestamos p where p.estado = 'vigente'))
    -- (las facturas abiertas, solo si se piden: las lee un depósito del
    -- banco, y el motor las pide al primero que las necesita; un «Casar»
    -- de la tarjeta no las lee)
    || case when p_facturas then jsonb_build_object('facturas', fn_banco_contexto_facturas()) else '{}'::jsonb end
    from k
  );
end $$;
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
-- (Ronda 4b: en plpgsql, la misma consulta: en «language sql» se volvía a
-- leer y a planear en cada «Casar» —ver fn_banco_caja—.)
create or replace function public.fn_banco_firma()
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
begin
  return (
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
              -- (ronda 4c: la marca de esta versión del banco. Un pegado nuevo
              -- cambia lo que se propone —en la 4c, EL CRITERIO del otro
              -- lado—, y la bandeja no puede quedarse con los botones de
              -- antes: con la marca en la firma, el primer «Casar» después
              -- del pegado rehace todo lo pendiente, y clasificar sin motivo
              -- rehace su propuesta antes de mirarla. Antes eso dependía de
              -- que el pegado cambiara la forma de la firma, y la 4c no la
              -- cambiaba: encima de la 4b se quedaban sus botones —«Desde
              -- 1010» sin motivo en un depósito «FROM EDGAR M MARTINEZ»—, que
              -- pulsados ya fallan, MX008.)
              fn_banco_version()::text,
              (select coalesce(max(d.cambiado_el)::text, '') || ':' || count(*) from banco_descriptores d),
              (select count(*) || ':' || coalesce(max(t.ultimos4), '') || ':' || count(*) filter (where t.activa) from tarjetas t),
              (select count(*) filter (where c.activa) from cuentas c),
              -- (ronda 4: la apertura posteada y sus conciliaciones
              -- confirmadas: el aviso de los primeros días cambia con ellas.
              -- El asiento de apertura solo vive en el período de la
              -- apertura —c2 no lo deja en otro—: buscado por él, el índice
              -- de períodos lo encuentra sin recorrer el libro entero, que
              -- con un año de banco eran 5 ms de cada «Casar». Grupo 4.)
              (select count(*) from asientos a
                where a.tipo = 'apertura' and a.periodo in (select p.periodo from periodos p where p.tipo = 'apertura')),
              (select count(*) from conciliaciones c where c.tipo = 'apertura' and c.estado = 'confirmada'),
              -- (ronda 4b: las cuentas personales de Edgar dadas de alta y los
              -- números que la empresa reconoce —los que traen sus estados de
              -- cuenta, el mapeo de QuickBooks—: con ellos cambia lo que se
              -- propone para el dinero que nombra otra cuenta. Dar de alta el
              -- número de la reserva, o la personal, rehace esas propuestas)
              (select count(*) || ':' || count(*) filter (where p.activa) || ':'
                      || coalesce(max(coalesce(p.cambiado_el, p.creado_el))::text, '')
                 from banco_cuentas_personales p),
              (select md5(coalesce(string_agg(distinct a.ultimos4 || '=' || a.cuenta, ',' order by a.ultimos4 || '=' || a.cuenta), ''))
                 from archivos_banco a
                where a.ultimos4 is not null and a.retirado_el is null and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada)),
              (select count(*) || ':' || md5(coalesce(string_agg(m.nombre_qb || '=' || coalesce(m.cuenta, ''), ',' order by m.clave), ''))
                 from apertura_mapeo_qb m where m.tipo = 'cuenta'))),
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
  );
end $$;
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
  v_crit  text;
  r       record;
  s       record;
begin
  if m.estado <> 'pendiente' or m.fecha < v_corte or m.fecha > v_corte + 180 or m.monto = 0 then
    return null;
  end if;
  -- (Ronda 4d) EL CRITERIO: si el banco dice que este dinero viene de (o va
  -- a) una cuenta de la empresa o la personal de Edgar, no es la partida de
  -- QuickBooks (el cheque de un cliente, el cheque a un proveedor): sus
  -- opciones piden su motivo y no cuentan como «fuertes» (no frenan lo
  -- demás: lo que es, su préstamo o su pase, va delante).
  if coalesce(m.tipo_banco, '') = 'XFER' or fn_banco_dice('transferencia', m.desc_norm)
     or (m.monto < 0 and fn_banco_dice('pago_tarjeta', m.desc_norm)) then
    v_crit := fn_banco_criterio_libro(m, null, 'apertura')->>'contradice';
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
  if v_crit is not null and jsonb_array_length(v_ops) > 0 then
    select jsonb_agg(o || jsonb_build_object('pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                                             'texto', (o->>'texto') || case when o->>'texto' like '%(con su motivo)' then ''
                                                                            else ' (con su motivo)' end) order by n)
      into v_ops
      from jsonb_array_elements(v_ops) with ordinality as x(o, n);
    return jsonb_build_object('opciones', v_ops, 'fuertes', 0, 'contradice', v_crit);
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
           -- (El asiento de apertura, por el período de la apertura, el único
           -- donde c2 lo deja vivir: lo encuentra el índice de períodos, sin
           -- recorrer el libro entero en cada «Casar». Grupo 4.)
           when not exists (select 1 from asientos a
                             where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                               and a.periodo in (select p.periodo from periodos p where p.tipo = 'apertura')
                               and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso'))
           then 'sin_apertura'
           when exists (select 1 from asientos a join asiento_lineas l on l.asiento_id = a.id
                         where a.tipo = 'apertura' and l.cuenta = p_cuenta and a.camino not in ('reverso', 'reverso_automatico')
                           and a.periodo in (select p.periodo from periodos p where p.tipo = 'apertura')
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

-- (Ronda 4) EL FRENO DE LA APERTURA, el mismo en cada camino que postea un
-- movimiento: uno que puede ser una partida en tránsito de la conciliación
-- de apertura (fn_banco_apertura_opciones: lo que falta de ella por el
-- mismo monto, su cheque, o la suma con otros pendientes; o, con la
-- apertura posteada y sin conciliar, un cheque o un depósito de los
-- primeros 30 días: fn_banco_apertura_aviso) ya está en el saldo de la
-- apertura: cobrarlo, pagarlo a un proveedor, postearlo como transferencia
-- o como la cuota de un préstamo lo mete dos veces. Solo con su motivo
-- escrito (p_hacer: lo que se iba a hacer; p_donde: dónde va el motivo).
-- Antes solo lo miraba fn_banco_clasificar: el depósito del 30-sep se
-- cobraba otra vez a la factura que QuickBooks ya había cobrado, el
-- cheque a CED se pagaba otra vez contra 2010, y octubre se confirmaba con
-- el dinero dos veces.
create or replace function public.fn_banco_apertura_freno(m public.movimientos_banco, p_motivo text, p_hacer text, p_donde text)
returns void
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_ap jsonb;
begin
  if fn_banco_limpio(p_motivo) is not null then
    return;
  end if;
  v_ap := fn_banco_apertura_opciones(m);
  if coalesce((v_ap->>'fuertes')::int, 0) > 0 then
    raise exception using errcode = 'MX008',
      message = format('Puede ser una partida en tránsito de la conciliación de apertura (%s): ya está en el saldo de la apertura y %s '
                       'la metería dos veces. Cásalo con ella (fn_banco_casar_con con {"partida_apertura": "%s"}, lo que propone la '
                       'bandeja). Si de verdad es otra cosa, dilo en %s.', v_ap->'opciones'->0->>'texto', p_hacer,
                       v_ap->'opciones'->0->'args'->'p_con'->>'partida_apertura', p_donde);
  end if;
  if fn_banco_apertura_estado(m.cuenta) = 'sin_conciliar' and fn_banco_apertura_aviso(m) is not null then
    raise exception using errcode = 'MX008', message = replace(fn_banco_apertura_aviso(m), 'dilo en el motivo', 'dilo en ' || p_donde);
  end if;
end $$;
revoke execute on function public.fn_banco_apertura_freno(public.movimientos_banco, text, text, text)
  from public, anon, authenticated, service_role;

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
  v_post   boolean;
  v_extra  numeric;
  v_chico  boolean;
  v_o_cap  jsonb;
  v_o_rec  jsonb;
  v_o_st   jsonb;
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
  v_bdj    jsonb;
  v_ol     jsonb;
  v_desconocida boolean := false;
  v_quien  text;
  v_pm     text := '';
  v_t2900  boolean := false;
  v_es_tj  boolean := false;
  v_alta   text;
  v_clasif jsonb;
  v_clasif_txt text;
  v_clasif_recl text[];
  v_nombrado boolean := false;
  v_deuda  jsonb;
  v_deuda_cta text;
  v_prov_nombrado boolean := false;
  v_contr  text;
  v_contr_l text;
  v_mio    jsonb;
  v_mio_txt text;
  v_mot    text;
  v_txt_fin text;
begin
  v_tipo := coalesce(k->'tipos'->>m.cuenta, fn_banco_tipo_cuenta(m.cuenta));
  -- (Ronda 4c) EL CRITERIO, una vez y antes de todo: ¿quién es el otro lado
  -- (fn_banco_otro_lado)? Solo en lo que puede ser dinero entre cuentas: una
  -- transferencia (XFER o su descriptor, en NAME), el pago de una tarjeta
  -- visto en el banco (el emisor o los 4 últimos de una tarjeta de la
  -- empresa) o el pago recibido en la tarjeta. Lo demás es un tercero. Los
  -- descriptores, en la descripción del banco (NAME): el MEMO lo escribe
  -- quien manda el dinero.
  v_es_tr := coalesce(m.tipo_banco, '') = 'XFER' or coalesce(v_dn ~* (k->'pat'->>'transferencia'), false);
  v_es_pt := v_tipo = 'banco' and m.monto < 0
             and (coalesce(v_dn ~* (k->'pat'->>'pago_tarjeta'), false)
                  or exists (select 1 from jsonb_array_elements(k->'propias') x
                              cross join jsonb_array_elements_text(coalesce(x->'u4', '[]'::jsonb)) as u(u4)
                              where x->>'tipo' = 'tarjeta' and v_dn ~ ('(^| )' || u.u4 || '( |$)')));
  v_es_pr := v_tipo = 'tarjeta' and m.monto > 0 and coalesce(v_dn ~* (k->'pat'->>'pago_recibido'), false);
  v_ol := case when v_es_tr or v_es_pt or v_es_pr then fn_banco_otro_lado(m) else '{"clase": "tercero"}'::jsonb end;
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
  -- (Ronda 4d) Si el que ya entró está CASADO y lo que dice este del otro
  -- lado contradice su casado (Plaid trajo «Online Transfer to CHK», sin
  -- número, y se confirmó «A 1030»; el QFX dice «TO CHK ...7781», la cuenta
  -- personal de Edgar dada de alta), se dice, «Es el mismo» pide su motivo y
  -- va primero des-casar aquel. Antes «Es el mismo (no entra)» lo descartaba
  -- sin decir nada y el pase quedaba en 1030, en tránsito para siempre.
  if m.posible_duplicado_de is not null and m.duplicado is null then
    select * into v_dup from movimientos_banco where id = m.posible_duplicado_de;
    if v_dup.estado in ('casado', 'en_transito') and v_dup.asiento_id is not null then
      v_contr := fn_banco_criterio(v_dup.monto, fn_banco_otro_lado(m),
                                   fn_banco_libro_lado(v_dup.asiento_id, v_dup.cuenta, v_dup.casado_clase))->>'contradice';
    end if;
    return jsonb_strip_nulls(jsonb_build_object(
      'motivo', 'posible_duplicado', 'regla', 'importación',
      'texto', format('¿Es el mismo movimiento que el del %s por %s «%s» (entró por %s)? El mismo dinero no entra dos veces: '
                      'dilo y sigue.', v_dup.fecha, v_dup.monto, coalesce(v_dup.descripcion, ''), v_dup.origen)
               -- (format con un argumento nulo da '' y no nulo: el «Ojo», solo
               -- si de verdad se contradicen)
               || case when v_contr is not null
                       then format(' Ojo: si es el mismo, aquel está mal casado: %s. Des-cásalo antes (con su motivo) y di después '
                                   'que este es el mismo: aquel se propondrá por lo que es.', v_contr)
                       else '' end,
      'duplicado_de', v_dup.id,
      'opciones', case when v_contr is not null
                       then jsonb_build_array(
                              jsonb_build_object('texto', format('Des-casar el del %s por %s («%s»): está casado con algo que este '
                                                                 'contradice (con su motivo)', v_dup.fecha, v_dup.monto,
                                                                 coalesce(v_dup.descripcion, '')),
                                                 'llamar', 'fn_banco_descasar', 'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                                                 'args', jsonb_build_object('p_movimiento', v_dup.id)),
                              jsonb_build_object('texto', 'Es el mismo (no entra), y aquel queda como está (con su motivo)',
                                                 'llamar', 'fn_banco_duplicado', 'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                                                 'args', jsonb_build_object('p_movimiento', m.id, 'p_es_el_mismo', true)))
                       else jsonb_build_array(
                              jsonb_build_object('texto', 'Es el mismo (no entra)', 'llamar', 'fn_banco_duplicado',
                                                 'args', jsonb_build_object('p_movimiento', m.id, 'p_es_el_mismo', true))) end
                  || jsonb_build_array(
                       jsonb_build_object('texto', 'Es otro movimiento', 'llamar', 'fn_banco_duplicado',
                                          'args', jsonb_build_object('p_movimiento', m.id, 'p_es_el_mismo', false))),
      'contradice', v_contr));
  end if;

  -- (Ronda 4d) EL COBRO QUE LA APP REGISTRÓ CON ESTE DEPÓSITO (c3,
  -- fn_cobro_registrar con "movimiento_id") y que no casó solo: EL CRITERIO
  -- lo frenó (el banco dice que el dinero viene de una cuenta de la empresa
  -- o de la personal de Edgar). Su asiento ya tiene este dinero: o es su
  -- cobro (se casa con él, con su motivo), o no lo es (se anula, con su
  -- motivo, y el depósito se propone por lo que es: el pase, el préstamo de
  -- Edgar). Nada más mientras tanto: lo metería dos veces. Antes casaba solo
  -- («R2 el cobro dice este movimiento») y la factura quedaba cobrada con
  -- el dinero de Chase.
  v_mio_txt := fn_banco_cobro_reclama(m.id);
  if v_mio_txt is not null then
    select jsonb_agg(x.o order by x.f, x.id) into v_mio
      from (select c.fecha as f, c.id, o.o
              from cobros c
              cross join lateral (select fn_banco_criterio_libro(m, c.contabilizado_en, 'cobro')->>'contradice' as pm) k
              cross join lateral (
                select jsonb_strip_nulls(jsonb_build_object(
                         'texto', format('Es el cobro del %s por %s%s que la app registró con este depósito%s', c.fecha, c.monto,
                                         coalesce(' (ref ' || c.referencia || ')', ''),
                                         case when k.pm is not null then ' (con su motivo)' else '' end),
                         'llamar', 'fn_banco_casar_con', 'pide_motivo', case when k.pm is not null then true end,
                         'pide', case when k.pm is not null then jsonb_build_array('p_motivo') end,
                         'args', jsonb_build_object('p_movimiento', m.id, 'p_con', jsonb_build_object('cobro', c.id)))) as o
                 -- (solo si su línea da el depósito: si no, casarlo fallaría)
                 where (select coalesce(sum(l.monto), 0) from asiento_lineas l
                         where l.asiento_id = c.contabilizado_en and l.cuenta = m.cuenta) = m.monto
                union all
                select jsonb_build_object(
                         'texto', format('No es su cobro: anula el cobro del %s por %s (con su motivo), y este depósito se propone por '
                                         'lo que es', c.fecha, c.monto),
                         'llamar', 'fn_cobro_anular', 'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                         'args', jsonb_build_object('p_cobro', c.id))) o
             where c.movimiento_id = m.id::text and c.estado = 'vigente') x;
    return jsonb_strip_nulls(jsonb_build_object(
      'motivo', 'cobro_que_lo_nombra', 'regla', 'R2', 'otro_lado', v_ol,
      'texto', format('La app registró %s con este depósito, y no casó solo: %s. Si de verdad es ese cobro, cásalo con él (con su '
                      'motivo escrito). Si no (es un pase de una cuenta tuya, o tu dinero), anula ese cobro (con su motivo) y este '
                      'depósito se propone por lo que es. Mientras ese cobro siga vigente, su asiento ya tiene este dinero: otra cosa '
                      'lo metería dos veces.', v_mio_txt,
                      coalesce((select fn_banco_criterio_libro(m, c.contabilizado_en, 'cobro')->>'contradice'
                                  from cobros c where c.movimiento_id = m.id::text and c.estado = 'vigente'
                                 order by c.fecha, c.id limit 1), 'su línea en el libro no da este depósito')),
      'opciones', v_mio));
  end if;
  -- 1. Lo del libro que casaría, pero no solo: se elige. (El otro lado de
  -- una transferencia que ya está en el libro, en su ventana, también sale
  -- aquí: se casa con ESE asiento, nunca otra transferencia.)
  v_n := coalesce(jsonb_array_length(p_cands), 0);
  -- (Ronda 4c) Un depósito que nombra una cuenta de la empresa por su número
  -- (EL CRITERIO) no es el cobro de un cliente: si lo que casaría con él son
  -- cobros (y no la línea de una transferencia), no se propone aquí; abajo
  -- (11) va primero la transferencia, y el cobro con su motivo. (Ronda 4d:
  -- y uno de la cuenta personal de Edgar dada de alta: primero su préstamo
  -- o su aportación, y el cobro con su motivo.)
  if v_n > 0 and m.monto > 0 and v_ol->>'clase' in ('propia', 'personal')
     and not exists (select 1 from jsonb_array_elements(p_cands) c
                      where coalesce((c->>'tr')::boolean, false) or c->>'origen_tabla' is distinct from 'cobros') then
    v_n := 0;
  end if;
  -- (Ronda 5) Lo que casaría son solo CUOTAS de un préstamo registradas
  -- antes que el banco (una semanal: varias por el mismo monto): no es
  -- «elige cuál» por fecha, es R8 «la cuota ya registrada» (8, abajo), con
  -- la de su fecha primero. Antes salía R1 con la más vieja primero. (Lo
  -- que Edgar des-casó sigue aquí, con su «lo des-casaste».)
  if v_n > 0 and v_tipo = 'banco' and m.monto < 0
     and not exists (select 1 from jsonb_array_elements(p_cands) c
                      where coalesce((c->>'tr')::boolean, false) or c->>'origen_tabla' is distinct from 'prestamo_cuotas'
                         or c->>'descasado' is not null)
     and exists (select 1 from prestamo_cuotas q join prestamos p on p.id = q.prestamo_id
                  where q.anulada_el is null and q.movimiento_id is null and q.monto = -m.monto and p.cuenta_banco = m.cuenta
                    and q.fecha between m.fecha - 60 and m.fecha + 3) then
    v_n := 0;
  end if;
  if v_n > 0 then
    v_es_tr := not exists (select 1 from jsonb_array_elements(p_cands) c where not coalesce((c->>'tr')::boolean, false));
    -- (Ronda 4c) Lo que pide su motivo: la línea de una transferencia cuyo
    -- movimiento contradice a este (EL CRITERIO, fn_banco_lados_linea: el
    -- pase a la cuenta personal de Edgar no es el otro lado del depósito de
    -- la reserva), y un cobro, si el banco dice que el dinero viene de una
    -- cuenta propia. Antes esos casaban solos, o su botón entraba sin motivo.
    select jsonb_agg(case when x.pm is not null
                          then fn_banco_opcion_motivo(x.o) || jsonb_build_object('texto', (x.o->>'texto') || ' (con su motivo)')
                          else x.o end order by x.n),
           string_agg(distinct x.pm, '; ') filter (where x.tr),
           string_agg(distinct x.pm, '; ') filter (where not x.tr)
      into v_lista, v_contr, v_contr_l
      from (select c.n, coalesce((c.c->>'tr')::boolean, false) as tr,
                   jsonb_build_object('texto', case when coalesce((c.c->>'tr')::boolean, false)
                                                    then 'Es el otro lado de la ' || coalesce(c.c->>'papel', c.c->>'numero')
                                                    else 'Confirmar cruce con ' || coalesce(c.c->>'papel', c.c->>'numero') end,
                                      'llamar', 'fn_banco_casar_con',
                                      'args', jsonb_build_object('p_movimiento', m.id,
                                                                 'p_con', jsonb_build_object('lineas', c.c->'lineas'))) as o,
                   case when coalesce((c.c->>'tr')::boolean, false)
                        then fn_banco_lados_linea(m, (c.c->>'asiento_id')::uuid)->>'contradice'
                        -- (ronda 4d: lo demás —un asiento escrito a mano, un cobro,
                        -- una cuota—, con EL CRITERIO contra lo que dice ese asiento;
                        -- un ticket o una devolución no se miran)
                        when c.c->>'origen_tabla' in ('recibos', 'cobros_devoluciones') then null
                        else fn_banco_criterio_libro(m, (c.c->>'asiento_id')::uuid,
                                                     case when c.c->>'origen_tabla' = 'cobros' then 'cobro' end)->>'contradice' end as pm
              from jsonb_array_elements(p_cands) with ordinality as c(c, n)) x;
    -- (y, si se contradicen, des-casar el movimiento que puso esa
    -- transferencia, con su motivo: su asiento se reversa y cada uno se
    -- clasifica por lo que es. Clasificar este no se puede mientras esa
    -- línea lo espere: fn_banco_clasificar lo frena y dice esto mismo.)
    if v_contr is not null then
      select v_lista || coalesce(jsonb_agg(jsonb_build_object(
               'texto', format('Des-casar %s de %s del %s por %s («%s»): no es el otro lado de este (con su motivo)',
                               case when x.monto < 0 then 'el retiro' else 'el depósito' end, x.cuenta, x.fecha, x.monto,
                               coalesce(x.descripcion, '')),
               'llamar', 'fn_banco_descasar', 'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
               'args', jsonb_build_object('p_movimiento', x.id)) order by x.fecha, x.id), '[]'::jsonb)
        into v_lista
        from movimientos_banco x
       where x.estado in ('casado', 'en_transito') and x.id <> m.id
         and x.id in (select (case when a.origen_id ~ '^[0-9a-fA-F-]{36}$' then a.origen_id::uuid end)
                        from asientos a
                       where a.origen_tabla = 'movimientos_banco'
                         and a.id in (select (c->>'asiento_id')::uuid from jsonb_array_elements(p_cands) c
                                       where coalesce((c->>'tr')::boolean, false)));
    end if;
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
                    else format('Casa con %s cosas del libro por el mismo monto y fecha cercana: elige cuál.', v_n) end
               || coalesce(' Ojo: ' || v_contr || ': júntalos solo con su motivo escrito. Si no es el mismo dinero, des-casa el '
                           'otro (con su motivo: su transferencia se reversa) y cada uno se clasifica por lo que es.', '')
               -- (ronda 4d: lo que ya estaba en el libro —un asiento escrito a
               -- mano, un cobro, una cuota— y EL CRITERIO dice otra cosa)
               || coalesce(' Ojo: ' || v_contr_l || '. Si de verdad es esto, confírmalo con su motivo escrito. Si no, ese asiento no es '
                           'este dinero: si se escribió mal, revérsalo (fn_reversar, con su motivo; un cobro, fn_cobro_anular) y este '
                           'movimiento se propone por lo que es.', ''),
      'candidatos', p_cands,
      'otro_lado', case when v_contr is not null or v_contr_l is not null then v_ol end,
      'opciones', v_lista
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

  -- 6. Retiro de cajero: pregunta, nunca automático. (Ronda 4b: «para mí»
  -- es una distribución, patrimonio del accionista: pide su motivo escrito,
  -- como todo lo que va del banco al patrimonio sin una cuenta personal
  -- dada de alta que lo diga. Antes entraba a 3200 con solo pulsarlo.)
  if v_tipo = 'banco' and m.monto < 0 and (m.tipo_banco = 'ATM' or coalesce(v_txt ~* (k->'pat'->>'cajero'), false)) then
    return jsonb_build_object(
      'motivo', 'cajero', 'regla', 'R5',
      'texto', '¿Caja chica o para ti? Un retiro de cajero no es gasto: entra a la caja chica (1050) y cada compra en efectivo sale '
               'de ahí con su ticket; o es para Edgar (3200, distribución: con su motivo escrito).',
      'opciones', jsonb_build_array(
        jsonb_build_object('texto', 'Caja chica · ' || (k->>'caja'), 'llamar', 'fn_banco_clasificar',
                           'args', jsonb_build_object('p_movimiento', m.id,
                                                      'p_lineas', jsonb_build_array(jsonb_build_object('cuenta', k->>'caja')))),
        jsonb_build_object('texto', 'Para mí · 3200 (con su motivo)', 'llamar', 'fn_banco_clasificar',
                           'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                           'args', jsonb_build_object('p_movimiento', m.id,
                                                      'p_lineas', jsonb_build_array(jsonb_build_object('cuenta', '3200'))))));
  end if;

  -- 7. Un Zelle de Edgar: aporte o préstamo del accionista, nunca ingreso.
  -- (Ronda 4b: con su motivo escrito: un Zelle no trae el número de una
  -- cuenta personal dada de alta.)
  if v_tipo = 'banco' and m.monto > 0 and coalesce(v_txt ~* (k->'pat'->>'zelle_edgar'), false) then
    return jsonb_build_object(
      'motivo', 'aporte_edgar', 'regla', 'R2',
      'texto', 'Dinero de Edgar a la empresa: una aportación (3100) o un préstamo del accionista (2900), con su motivo escrito. '
               'Nunca ingreso.',
      'opciones', jsonb_build_array(
        jsonb_build_object('texto', 'Préstamo del accionista · 2900 (con su motivo)', 'llamar', 'fn_banco_clasificar',
                           'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                           'args', jsonb_build_object('p_movimiento', m.id,
                                                      'p_lineas', jsonb_build_array(jsonb_build_object('cuenta', '2900')))),
        jsonb_build_object('texto', 'Aportación · 3100 (con su motivo)', 'llamar', 'fn_banco_clasificar',
                           'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
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
     where x->>'cuenta_banco' = m.cuenta
       and (((x->>'descriptor') is not null and v_txt ~* (x->>'descriptor'))
            -- (ronda 4c: o el banco nombra el número de su cuenta, dado de
            -- alta como de la empresa: EL CRITERIO, una deuda propia)
            or (v_ol->>'tipo' = 'deuda' and v_ol->>'cuenta' in (x->>'cuenta', x->>'cuenta_largo')));
    if v_cuota is not null then
      return jsonb_build_object(
        'motivo', 'cuota_prestamo', 'regla', 'R8',
        'texto', 'La cuota de este préstamo ya está registrada (con el statement del prestamista) y espera su cargo del banco: '
                 'cásalo con ella. Registrar otra la pondría dos veces (capital e interés).'
                 || case when jsonb_array_length(v_cuota) > 1
                         then ' Hay varias por ese monto esperando su cargo: la de su fecha va primero.' else '' end,
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
    select jsonb_agg(x.o order by x.d, x.fecha, x.n), bool_or(x.post) into v_cuota, v_post
      from (select abs(q.fecha - m.fecha) as d, q.fecha, n.n,
                   exists (select 1 from prestamo_cuotas q2
                            where q2.prestamo_id = q.prestamo_id and q2.anulada_el is null and q2.fecha > q.fecha) as post,
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
               -- (ronda 5: a capital solo sin cuotas posteriores —su saldo las
               -- movería—; a interés, siempre)
               and (n.n = 2 or not exists (select 1 from prestamo_cuotas q2
                                            where q2.prestamo_id = q.prestamo_id and q2.anulada_el is null and q2.fecha > q.fecha))
               and exists (select 1 from asiento_lineas l
                            where l.asiento_id = q.asiento_id and l.cuenta = m.cuenta
                              and not exists (select 1 from banco_casado_lineas cl
                                               where cl.asiento_id = l.asiento_id and cl.orden = l.orden and cl.vigente))) x;
    if v_cuota is not null then
      return jsonb_build_object(
        'motivo', 'cuota_prestamo', 'regla', 'R8',
        'texto', 'La cuota de este préstamo ya está registrada, por otro monto, y espera su cargo del banco: es ella (la cuota '
                 'redondeada, o con un recargo). Cásalo con ella: la diferencia va a capital o a interés, según el statement '
                 'del prestamista. Registrar otra la pondría dos veces.'
                 || case when coalesce(v_post, false)
                         then ' Con una cuota posterior ya registrada, la diferencia solo puede ir a interés (a capital movería el '
                              'saldo de las que siguen): si va a capital, anula antes la posterior desde el SQL Editor '
                              '(fn_prestamo_cuota_anular, con su motivo; de la última hacia atrás), pulsa, y vuelve a registrarla.'
                         else '' end,
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
        -- (Ronda 5) Un extra CHICO (menos del 10 % de la cuota: 36.68 sobre
        -- 733.56, 25.00 sobre 300.00) es casi siempre un recargo por pagar
        -- tarde, no un abono a capital: va primero como recargo (a interés,
        -- un gasto) y los dos botones piden su motivo; a capital sin motivo,
        -- solo un extra grande (y el recargo, tercero). Antes 25.00 de más
        -- bajaban el capital con un botón sin motivo y ningún cuadre lo veía.
        v_extra := (v_part->>'extra')::numeric;
        v_chico := v_extra < round(v_p.cuota * 0.10, 2);
        v_o_cap := jsonb_build_object('texto', format('Cuota de %s más %s a capital (un abono extra)', v_p.prestamista, v_part->>'extra'),
                                      'llamar', 'fn_prestamo_cuota',
                                      'args', jsonb_build_object('p_prestamo', v_p.id, 'p_movimiento', m.id));
        v_o_st  := jsonb_build_object('texto', format('Con el capital y el interés del statement de %s', v_p.prestamista),
                                      'llamar', 'fn_prestamo_cuota', 'pide', jsonb_build_array('p_capital', 'p_interes'),
                                      'args', jsonb_build_object('p_prestamo', v_p.id, 'p_movimiento', m.id));
        v_o_rec := case when v_p.cuota - (v_part->>'interes')::numeric >= 0
                        then jsonb_build_object('texto', format('Cuota de %s con un recargo de %s (a interés, un gasto; con su motivo)',
                                                                v_p.prestamista, v_part->>'extra'),
                                                'llamar', 'fn_prestamo_cuota', 'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                                                'args', jsonb_build_object('p_prestamo', v_p.id, 'p_movimiento', m.id,
                                                                           'p_capital', (v_p.cuota - (v_part->>'interes')::numeric)::text,
                                                                           'p_interes', ((v_part->>'interes')::numeric + v_extra)::text)) end;
        v_chico := v_chico and v_o_rec is not null;
        return jsonb_build_object(
          'motivo', 'cuota_prestamo', 'regla', 'R8',
          'texto', format('Cuota del préstamo de %s con %s de más (%s): %s. Si tienes el statement del prestamista, manda él.',
                          v_p.prestamista, v_part->>'extra', v_part->>'aviso',
                          case when v_chico
                               then 'tan poco es casi siempre un recargo por pagar tarde (a interés, un gasto), no un abono a capital: '
                                    'di cuál es, con su motivo'
                               else format('la fórmula pone el interés %s y lo demás a capital',
                                           fn_prestamo_periodo(v_p.cuotas_al_anio, 'del')) end),
          'particion', v_part,
          'opciones', case when v_chico then jsonb_build_array(v_o_rec, fn_banco_opcion_motivo(v_o_cap), v_o_st)
                           else jsonb_build_array(v_o_cap, v_o_st)
                                || case when v_o_rec is not null then jsonb_build_array(v_o_rec) else '[]'::jsonb end end);
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
  -- es la devolución de una compra (12, abajo). (Ronda 4c: la señal y EL
  -- CRITERIO se leen arriba, una vez.)
  -- (Ronda 4) LA OTRA CUENTA que nombra la transferencia («TO CHK ...7781»),
  -- en NAME (si el banco lo cortó —«...778»—, en la nota que trae entera).
  -- (Ronda 4b) Y QUÉ ES ESE NÚMERO (fn_banco_otro_lado; también la tarjeta
  -- que nombra el pago de una tarjeta): de una cuenta de la empresa (su
  -- estado de cuenta, su tarjeta, su nombre en QuickBooks); una cuenta
  -- personal de Edgar que él dio de alta (fn_banco_cuenta_personal, o su
  -- tarjeta personal dada de alta en 2900); o un número que no se conoce.
  -- Solo la personal dada de alta se propone como patrimonio del
  -- accionista sin motivo. Un número que no se conoce NO es personal por
  -- defecto —la reserva recién abierta antes de su primer estado de
  -- cuenta, una tarjeta nueva, la línea de crédito, un préstamo, una cuenta
  -- de ahorro en otro banco—: «cuenta_desconocida», cada opción pide su
  -- motivo y el texto dice cómo darlo de alta (como de la empresa o como
  -- personal). Antes todo número que no era de la empresa se daba por la
  -- cuenta personal de Edgar: el primer pase a la reserva salía
  -- «distribución · 3200» sin motivo (5,000.00 a 3200, y nada lo decía
  -- cuando llegaba el estado de cuenta de la reserva), y el depósito desde
  -- la personal por el mismo monto que una factura abierta dejaba el
  -- control en rojo (cuadre 52) con solo pulsar su botón.
  -- (Ronda 4c) Y CON EL CRITERIO ENTERO: la transferencia SIN número que
  -- nombra a alguien («TO EDGAR M PERSONAL», «FROM EDGAR M MARTINEZ») no se
  -- supone entre cuentas propias: «otro_lado_nombrado» en un retiro, y en
  -- un depósito sus cuentas propias y el patrimonio, todo con su motivo; la
  -- DEUDA PROPIA dada de alta por su número (la línea de crédito, un
  -- préstamo) es su pago o su desembolso, contra su cuenta y sin motivo
  -- («deuda_propia»); y un retiro que así nombra a un proveedor es su pago
  -- (10, abajo).
  -- (lo personal, lo desconocido y lo nombrado, en un banco)
  v_otra := case when v_tipo = 'banco' then v_ol->>'ultimos4' end;
  v_otra_cta := case when v_tipo = 'banco' and v_ol->>'clase' = 'propia' then v_ol->>'cuenta' end;
  v_personal := v_tipo = 'banco' and coalesce(v_ol->>'clase' = 'personal', false);
  v_desconocida := v_tipo = 'banco' and coalesce(v_ol->>'clase' = 'desconocida', false);
  v_nombrado := v_tipo = 'banco' and v_ol->>'clase' = 'tercero' and coalesce((v_ol->>'transferencia')::boolean, false);
  v_deuda_cta := case when v_tipo = 'banco' and v_ol->>'clase' = 'propia' and v_ol->>'tipo' = 'deuda' then v_ol->>'cuenta' end;
  v_prov_nombrado := v_nombrado and m.monto < 0
                     and exists (select 1 from jsonb_array_elements(k->'proveedores') p
                                  where jsonb_typeof(p->'pats') = 'array'
                                    and exists (select 1 from jsonb_array_elements_text(p->'pats') t(pat)
                                                 where position(t.pat in ' ' || v_txt || ' ') > 0));
  if v_personal or v_desconocida or v_nombrado then
    v_pm := case when v_desconocida or v_nombrado then ' (con su motivo)' else '' end;
    -- (¿el número es de una tarjeta, no de una cuenta? el pago de una tarjeta)
    v_es_tj := v_otra is not null and coalesce(fn_banco_otra_cuenta(v_dn), fn_banco_otra_cuenta(fn_banco_norm(m.memo))) is null;
    -- (la tarjeta personal de Edgar dada de alta en 2900, para sus tickets:
    -- pagarla baja lo que la empresa le debe)
    v_t2900 := v_personal and exists (select 1 from tarjetas t join cuentas c on c.codigo = t.cuenta
                                       where t.ultimos4 = v_otra and t.activa and c.tipo = 'pasivo'
                                         and c.etiqueta_fiscal = 'accionista');
    v_quien := case when v_personal then format('su cuenta ····%s, %s', v_otra, v_ol->>'nombre')
                    when v_nombrado then format('«%s», que el banco nombra sin número de cuenta', v_ol->>'nombra')
                    else format('¿su cuenta personal? ····%s, sin dar de alta', v_otra) end;
    -- (cómo dar de alta el número: lo que dice el texto de la desconocida)
    if v_desconocida then
      v_alta := format('Si es de la empresa (la reserva recién abierta, una cuenta nueva, una tarjeta nueva, la línea de crédito, un '
                       'préstamo, una cuenta de ahorro en otro banco), da de alta su número: %s; y vuelve a «Casar»: se propone como '
                       'lo que es (dinero entre cuentas propias; de la línea de crédito o de un préstamo, su pago o su desembolso), '
                       'sin motivo. Si es tu cuenta personal, dala de alta desde el SQL Editor (select fn_banco_cuenta_personal(''%s'', '
                       '''el nombre de la cuenta'');) y se propone como lo que es (préstamo, aportación o distribución), sin motivo. '
                       'Mientras tanto, cada opción pide su motivo escrito: nada va al patrimonio del accionista ni a otra cuenta '
                       'propia sin decir por qué.',
                       case when v_es_tj
                            then format('si es una tarjeta de la empresa, dala de alta en su cuenta (select fn_tarjeta_alta(''%s'', '
                                        '''2100-…'', ''el titular'');) o sube su estado de cuenta', v_otra)
                            else format('sube su estado de cuenta (su número queda), o confírmalo antes con un lote vacío a su cuenta '
                                        'del plan desde el SQL Editor (select fn_banco_importar_filas(''{"origen": "mano", "cuenta": '
                                        '"1030", "ultimos4": "%s", "confirmo_cuenta": true, "nombre": "su número ····%s", "filas": '
                                        '[]}''); con la cuenta que sea: 1030 es la reserva, 2510 la línea de crédito, 2520 o 2530 un '
                                        'préstamo de vehículo)', v_otra, v_otra) end,
                       v_otra);
    end if;
    v_pers := (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                         'texto', x.texto || v_pm, 'llamar', 'fn_banco_clasificar',
                         'pide_motivo', case when v_desconocida or v_nombrado then true end,
                         'pide', case when v_desconocida or v_nombrado then jsonb_build_array('p_motivo') end,
                         'args', jsonb_build_object('p_movimiento', m.id, 'p_lineas',
                                   jsonb_build_array(jsonb_build_object('cuenta', x.cuenta,
                                     'memo', left(case when v_otra is not null
                                                       then case when m.monto < 0 then 'A la cuenta ····' else 'Desde la cuenta ····' end
                                                            || v_otra
                                                       else case when m.monto < 0 then 'A «' else 'Desde «' end
                                                            || (v_ol->>'nombra') || '»' end
                                                  || ' · ' || coalesce(m.descripcion, ''), 200))))))
                       order by x.n)
                 from (values (case when v_t2900 then 3 else 1 end, '3200',
                               format('Para Edgar (%s): distribución · 3200', v_quien), m.monto < 0),
                              (2, '1130', 'Préstamo al accionista · 1130 (se lo devuelve)', m.monto < 0),
                              (case when v_t2900 then 1 else 3 end, '2900',
                               case when v_t2900
                                    then format('Pago de su tarjeta personal ····%s (sus tickets de la empresa van a 2900): baja lo '
                                                'que la empresa le debe · 2900', v_otra)
                                    else 'La empresa le devuelve lo que le prestó · 2900' end, m.monto < 0),
                              (1, '2900', format('De Edgar (%s): préstamo del accionista · 2900', v_quien), m.monto > 0),
                              (2, '3100', 'Aportación · 3100', m.monto > 0),
                              (3, '1130', 'Devuelve lo que la empresa le prestó · 1130', m.monto > 0)) as x(n, cuenta, texto, va)
                where x.va);
  end if;
  -- (Ronda 4c) LA DEUDA PROPIA (EL CRITERIO: la línea de crédito o un
  -- préstamo, dados de alta por su número con un lote vacío): un retiro es
  -- su pago y un depósito su desembolso, contra su cuenta, sin motivo (la
  -- cuota de un préstamo registrado ya salió arriba, en 8). No es un gasto,
  -- ni un ingreso, ni dinero entre cuentas propias con estado de cuenta.
  if v_deuda_cta is not null then
    v_deuda := jsonb_build_array(jsonb_build_object(
                 'texto', format('%s %s (····%s) · %s', case when m.monto < 0 then 'Pago a' else 'Desembolso de' end,
                                 coalesce((select c.nombre from cuentas c where c.codigo = v_deuda_cta), v_deuda_cta), v_otra,
                                 v_deuda_cta),
                 'llamar', 'fn_banco_clasificar',
                 'args', jsonb_build_object('p_movimiento', m.id, 'p_lineas', jsonb_build_array(jsonb_build_object(
                           'cuenta', v_deuda_cta,
                           'memo', left(case when m.monto < 0 then 'A ' else 'De ' end || v_deuda_cta || ' ····' || v_otra || ' · '
                                        || coalesce(m.descripcion, ''), 200))))));
  end if;
  if (v_es_tr or v_es_pt or v_es_pr) and not v_prov_nombrado then
    -- (El otro lado de una transferencia que YA está en el libro, en su
    -- ventana, es un candidato: sale arriba, en 1.)
    -- a. el otro lado que YA está en el libro FUERA de esa ventana (la
    -- transferencia que puso el otro estado de cuenta, a 10 días o menos,
    -- en cualquier dirección: la Amex abona el viernes y Chase cobra el
    -- martes): se ofrece casar con ella, y otra transferencia solo con su
    -- motivo. Antes la bandeja decía «el otro lado todavía no llegó» y su
    -- único botón posteaba otra: el mismo pago dos veces. (Ronda 4c: si el
    -- movimiento que la posteó contradice a este —EL CRITERIO—, con su
    -- motivo.)
    select jsonb_agg(case when x.c is not null
                          then fn_banco_opcion_motivo(x.o) || jsonb_build_object('texto', (x.o->>'texto') || ' (con su motivo)')
                          else x.o end order by x.d, x.numero)
      into v_ya_tr
      from (select abs(l.fdoc - m.fecha) as d, l.numero,
                   jsonb_build_object(
                     'texto', format('Es el otro lado de la transferencia %s del %s (ya está en el libro)', l.numero, l.fdoc),
                     'llamar', 'fn_banco_casar_con',
                     'args', jsonb_build_object('p_movimiento', m.id,
                                                'p_con', jsonb_build_object('lineas', jsonb_build_array(
                                                  jsonb_build_object('asiento_id', l.asiento_id, 'orden', l.orden))))) as o,
                   fn_banco_lados_linea(m, l.asiento_id)->>'contradice' as c
              from fn_banco_lineas_libres(array[m.cuenta], m.fecha - 12) l
             where l.tr and l.monto = m.monto and l.fdoc between m.fecha - 10 and m.fecha + 10) x;
    -- b. el otro lado todavía pendiente, en otra cuenta propia
    select jsonb_agg(x.o order by x.d, x.fecha)
      into v_contra
      from (select abs(x.fecha - m.fecha) as d, x.fecha,
                   jsonb_strip_nulls(jsonb_build_object(
                                      'texto', format('Es la transferencia con %s del %s por %s (%s)', x.cuenta, x.fecha, x.monto,
                                                      coalesce(x.descripcion, ''))
                                               || case when x.dudoso then ' (con su motivo)' else '' end,
                                      'llamar', 'fn_banco_casar_con',
                                      -- (ronda 4b: si uno de los dos lados nombra una cuenta
                                      -- personal de Edgar dada de alta, u otra cuenta de la
                                      -- empresa, juntarlos pide su motivo: fn_banco_casar_con.
                                      -- Ronda 4c: con EL CRITERIO de los dos —fn_banco_lados—:
                                      -- también un número que no se conoce, o alguien que el
                                      -- banco nombra sin número)
                                      'pide_motivo', case when x.dudoso then true end,
                                      'pide', case when x.dudoso then jsonb_build_array('p_motivo') end,
                                      'args', jsonb_build_object('p_movimiento', m.id,
                                                                 'p_con', jsonb_build_object('movimiento', x.id)),
                                      -- (si su fecha dejaría partida una conciliación: qué reabrir antes)
                                      'bloqueo', fn_banco_tr_fecha(m.fecha, m.cuenta, x.fecha, x.cuenta, m.monto)->>'bloqueo')) as o
              from (select x.*,
                           fn_banco_lados(v_ol, m.cuenta, xo.ol, x.cuenta)->>'contradice' is not null as dudoso
                      from movimientos_banco x
                      cross join lateral (select fn_banco_otro_lado(x) as ol) xo
                     where x.estado = 'pendiente' and x.monto = -m.monto and x.fecha between m.fecha - 10 and m.fecha + 10
                       and x.cuenta <> m.cuenta) x
             where x.estado = 'pendiente' and x.monto = -m.monto and x.fecha between m.fecha - 10 and m.fecha + 10
               and x.cuenta = any (array(select jsonb_object_keys(k->'tipos'))) and x.cuenta <> m.cuenta
               and (x.posible_duplicado_de is null or x.duplicado = 'no_es_el_mismo')
               -- (ronda 4d: no el que la app registró como un cobro: abajo, d)
               and not exists (select 1 from cobros c where c.movimiento_id = x.id::text and c.estado = 'vigente')
               -- (ronda 4d: en su DIRECCIÓN, como R3: el lado que entra, del día
               -- en que sale a 10 días después; en una tarjeta, desde 7 días
               -- antes. Antes, ±10 días: a un depósito de la reserva del 3-nov
               -- se le ofrecía «la transferencia con 1010 del 9-nov», un retiro
               -- posterior)
               and case when m.monto < 0
                        then x.fecha between m.fecha - (case when k->'tipos'->>x.cuenta = 'tarjeta' then 7 else 0 end) and m.fecha + 10
                        else x.fecha between m.fecha - 10 and m.fecha + (case when v_tipo = 'tarjeta' then 7 else 0 end) end
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
    -- (Ronda 4c: lo que pide el motivo, con la MISMA función que lo frena en
    -- fn_banco_transferencia —fn_banco_transferencia_motivo: su señal, EL
    -- CRITERIO, y lo pendiente de esa cuenta que dice que fue a otro sitio—;
    -- y una tarjeta solo si el retiro dice que es el pago de una tarjeta, o es
    -- la que nombra el banco. Antes «A 2100-2009» salía sin motivo en un pase
    -- «ONLINE TRANSFER TO EDGAR M PERSONAL» y, pulsado tal cual, fallaba.)
    select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                       'texto', format('%s %s (%s)', case when m.monto < 0 then 'A' else 'Desde' end, x->>'codigo', x->>'nombre')
                                || case when dd.dud is not null then ' (con su motivo)' else '' end,
                       'llamar', 'fn_banco_transferencia',
                       -- (ronda 4: la que no es de la cuenta que nombra el banco,
                       -- o un banco que nunca trajo su estado de cuenta: con su
                       -- motivo, que fn_banco_transferencia exige. Ronda 4b:
                       -- con el otro lado ya leído, una vez por cuenta)
                       'pide_motivo', case when dd.dud is not null then true end,
                       'pide', case when dd.dud is not null then jsonb_build_array('p_motivo') end,
                       'args', jsonb_build_object('p_movimiento', m.id, 'p_cuenta', x->>'codigo'),
                       'bloqueo', fn_banco_tr_fecha(m.fecha, m.cuenta,
                                                    (select y.fecha from movimientos_banco y
                                                      where y.cuenta = x->>'codigo' and y.estado = 'pendiente' and y.monto = -m.monto
                                                        and y.fecha between m.fecha - 10 and m.fecha + 10
                                                        and (y.posible_duplicado_de is null or y.duplicado = 'no_es_el_mismo')
                                                      order by abs(y.fecha - m.fecha), y.fecha limit 1),
                                                    x->>'codigo', m.monto)->>'bloqueo'))
                     -- (ronda 4b: primero la cuenta que nombra el banco, si es
                     -- de la empresa: la que no pide motivo; ronda 4c: y las
                     -- que no piden motivo antes que las que sí)
                     order by (x->>'codigo') is distinct from v_otra_cta, dd.dud is not null, x->>'codigo')
      into v_dest
      from jsonb_array_elements(k->'propias') x
      cross join lateral (select fn_banco_transferencia_motivo(m, x->>'codigo', v_ol) as dud) dd
     where x->>'codigo' <> m.cuenta
       and case when v_tipo = 'banco' and m.monto < 0
                then (v_es_pt and x->>'tipo' = 'tarjeta') or (v_es_tr and x->>'tipo' = 'banco') or x->>'codigo' = v_otra_cta
                when v_tipo = 'banco' then (v_es_tr and x->>'tipo' = 'banco') or x->>'codigo' = v_otra_cta
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
                                                                         'texto', (o->>'texto')
                                                                                  || case when o->>'texto' like '%(con su motivo)' then ''
                                                                                          else ' (otra transferencia, con su motivo)' end))
                                   from jsonb_array_elements(coalesce(v_dest, '[]'::jsonb)) o), '[]'::jsonb));
    end if;
    -- d. (Ronda 4b) SU OTRO LADO YA SE CLASIFICÓ: el movimiento de la otra
    -- cuenta propia por el mismo dinero, que también dice transferencia o
    -- pago (el pase de 1010 que el banco nombra), se casó como CLASIFICADO
    -- —una distribución, un gasto—, no como transferencia. Es el primer
    -- pase a la reserva que se tomó por otra cosa antes de que llegara su
    -- estado de cuenta: se des-casa aquel (con su motivo: su asiento se
    -- reversa) y los dos casan solos. Otra transferencia dejaría a la otra
    -- cuenta con un cargo en circulación que su banco no va a traer nunca:
    -- solo con su motivo. Antes la bandeja ofrecía «Desde 1010» sin motivo y
    -- nada decía que el pase se había tomado por una distribución.
    -- (Ronda 4c: solo si los dos lados no se contradicen —EL CRITERIO,
    -- fn_banco_lados—. El pase a la cuenta personal de Edgar dada de alta no
    -- es el otro lado de la aportación que llegó a la reserva desde «EDGAR M
    -- MARTINEZ» y se clasificó a 3100: es «transferencia_personal», con sus
    -- botones al patrimonio. Antes este paso iba antes que lo personal y no
    -- miraba el otro lado: decía que des-casaras la aportación.)
    -- (Ronda 4d) Y SU OTRO LADO CASADO COMO EL COBRO DE UN CLIENTE: el
    -- depósito de la reserva que la app registró como el cobro de la #1103
    -- (fn_cobro_registrar con su movimiento) es el mismo dinero que este pase
    -- de Chase: se des-casa aquel y se anula su cobro. Antes solo se miraba
    -- lo clasificado: «A 1030» salía sin motivo y 1030 quedaba con el mismo
    -- dinero dos veces.
    -- (y el que todavía está PENDIENTE porque la app lo registró como el
    -- cobro de un cliente y EL CRITERIO no lo casó: se anula ese cobro, y los
    -- dos casan solos)
    select jsonb_agg(case when x.cobro is not null
                          then jsonb_build_object(
                                 'texto', format('Anular el cobro del %s por %s que la app registró con %s de %s del %s («%s»): es el otro '
                                                 'lado de esta transferencia (con su motivo)', x.cfecha, x.cmonto,
                                                 case when x.monto < 0 then 'el retiro' else 'el depósito' end, x.cuenta, x.fecha,
                                                 coalesce(x.descripcion, '')),
                                 'llamar', 'fn_cobro_anular', 'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                                 'args', jsonb_build_object('p_cobro', x.cobro))
                          else jsonb_build_object(
                                 'texto', format('Des-casar %s de %s del %s por %s («%s», %s): es el otro lado de esta transferencia%s',
                                                 case when x.monto < 0 then 'el retiro' else 'el depósito' end, x.cuenta,
                                                 x.fecha, x.monto, coalesce(x.descripcion, ''),
                                                 case when x.casado_clase = 'cobro' then 'casado como el cobro de un cliente'
                                                      else 'clasificado a ' || x.ctas end,
                                                 case when x.casado_clase = 'cobro' then ' (después anula su cobro: fn_cobro_anular)'
                                                      else '' end),
                                 'llamar', 'fn_banco_descasar', 'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                                 'args', jsonb_build_object('p_movimiento', x.id)) end
                     order by abs(x.fecha - m.fecha), x.fecha),
           string_agg(format('%s de %s del %s por %s («%s») %s%s',
                             case when x.monto < 0 then 'el retiro' else 'el depósito' end, x.cuenta, x.fecha, x.monto,
                             coalesce(x.descripcion, ''),
                             case when x.cobro is not null then format('la registró la app como el cobro del %s por %s', x.cfecha, x.cmonto)
                                  when x.casado_clase = 'cobro' then 'se casó como el cobro de un cliente'
                                  else 'se clasificó a ' || x.ctas end,
                             coalesce(' (' || x.numero || ')', '')), '; ' order by abs(x.fecha - m.fecha), x.fecha),
           array_agg(x.cuenta) filter (where x.cobro is not null)
      into v_clasif, v_clasif_txt, v_clasif_recl
      from (select y.* from (
              select x.id, x.cuenta, x.fecha, x.monto, x.descripcion, a.numero, x.casado_clase,
                     (select string_agg(distinct l.cuenta, ', ') from asiento_lineas l
                       where l.asiento_id = x.asiento_id and l.cuenta <> x.cuenta) as ctas,
                     null::uuid as cobro, null::date as cfecha, null::numeric as cmonto, x.tipo_banco, x.desc_norm, x.estado
                from movimientos_banco x
                join asientos a on a.id = x.asiento_id
               where x.estado = 'casado' and x.casado_clase in ('clasificado', 'cobro') and x.monto = -m.monto
                 and x.fecha between m.fecha - 10 and m.fecha + 10 and x.cuenta <> m.cuenta
              union all
              select x.id, x.cuenta, x.fecha, x.monto, x.descripcion, null, null, null, c.id, c.fecha, c.monto, x.tipo_banco,
                     x.desc_norm, x.estado
                from movimientos_banco x
                join cobros c on c.movimiento_id = x.id::text and c.estado = 'vigente'
               where x.estado = 'pendiente' and x.monto = -m.monto
                 and x.fecha between m.fecha - 10 and m.fecha + 10 and x.cuenta <> m.cuenta) y
             where y.cuenta = any (array(select jsonb_object_keys(k->'tipos')))
               and (v_otra_cta is null or y.cuenta = v_otra_cta)
               and (coalesce(y.tipo_banco, '') = 'XFER' or coalesce(y.desc_norm ~* (k->'pat'->>'transferencia'), false)
                    or coalesce(y.desc_norm ~* (k->'pat'->>'pago_tarjeta'), false)
                    or coalesce(y.desc_norm ~* (k->'pat'->>'pago_recibido'), false))
               and fn_banco_lados(v_ol, m.cuenta, fn_banco_otro_lado((select z from movimientos_banco z where z.id = y.id)), y.cuenta)
                   ->>'contradice' is null
             order by abs(y.fecha - m.fecha), y.fecha
             limit 3) x;
    if v_clasif is not null then
      return jsonb_build_object(
        'motivo', 'otro_lado_clasificado', 'regla', 'R3',
        'texto', format('Parece dinero entre cuentas propias, y su otro lado ya se casó como otra cosa: %s. Si es este mismo dinero (el '
                        'pase que se tomó por una distribución o un gasto antes de que llegara este estado de cuenta), des-casa aquel '
                        '(con su motivo: su asiento se reversa) y los dos casan solos como una transferencia. Otra transferencia, o '
                        'clasificar este, dejaría el mismo dinero dos veces o un cargo en circulación que el banco no va a traer '
                        'nunca: solo con su motivo. Si de verdad es otro dinero (el cobro de un cliente), dilo con su motivo.',
                        v_clasif_txt),
        -- (ronda 4d: sin la transferencia a la cuenta cuyo depósito o retiro
        -- reclama un cobro de la app: fn_banco_transferencia la frena hasta
        -- que se anule ese cobro, con o sin motivo; sería un botón que falla
        -- siempre)
        'opciones', v_clasif
                    || coalesce((select jsonb_agg(fn_banco_opcion_motivo(o) || jsonb_build_object(
                                                    'texto', (o->>'texto') || case when o->>'texto' like '%(con su motivo)' then ''
                                                                                   else ' (con su motivo)' end) order by n)
                                   from jsonb_array_elements(coalesce(v_dest, '[]'::jsonb)) with ordinality as x(o, n)
                                  where not coalesce(o->'args'->>'p_cuenta' = any (v_clasif_recl), false)), '[]'::jsonb));
    end if;
    v_tr := case when v_contra is not null or v_dest is not null then coalesce(v_contra, '[]'::jsonb) || coalesce(v_dest, '[]'::jsonb) end;
    -- (Ronda 4c) EL PAGO DE UNA DEUDA PROPIA (la línea de crédito, un
    -- préstamo sin su cuota registrada): a su cuenta, sin motivo; otra
    -- cuenta propia, con su motivo (fn_banco_dudosa: el banco nombra otra).
    if v_deuda is not null and m.monto < 0 then
      return jsonb_strip_nulls(jsonb_build_object(
        'motivo', 'deuda_propia', 'regla', 'R3', 'otro_lado', v_ol,
        'texto', format('Dinero a ····%s, %s (%s): una deuda de la empresa, dada de alta por su número. Es su pago: a %s, sin motivo (si '
                        'trae intereses o un cargo, sepáralos a su gasto: fn_banco_clasificar con las dos líneas). No es un gasto ni '
                        'dinero entre cuentas propias.', v_otra, v_deuda_cta,
                        coalesce((select c.nombre from cuentas c where c.codigo = v_deuda_cta), 'sin nombre'), v_deuda_cta),
        'opciones', v_deuda || coalesce(v_tr, '[]'::jsonb)));
    end if;
    -- (Ronda 4: el retiro a una cuenta que no es de la empresa: primero lo
    -- que es —una distribución o un préstamo al accionista—, y las cuentas
    -- propias, con su motivo. Ronda 4b: solo si es una cuenta personal de
    -- Edgar dada de alta; el número que no se conoce pregunta, y primero las
    -- cuentas propias: todo con su motivo.)
    if v_personal and m.monto < 0 then
      return jsonb_strip_nulls(jsonb_build_object(
        'motivo', 'transferencia_personal', 'regla', 'R3', 'otro_lado', v_ol,
        'texto', format('Dinero a una cuenta personal de Edgar (····%s, %s: la diste de alta como tuya): %s, nunca un gasto ni dinero '
                        'entre cuentas propias. Si de verdad es otra cosa, abajo, con su motivo.', v_otra, v_ol->>'nombre',
                        case when v_t2900
                             then 'el pago de su tarjeta personal (sus tickets de la empresa van a 2900, préstamo del accionista: '
                                  'pagarla baja lo que la empresa le debe), una distribución (3200) o un préstamo al accionista (1130)'
                             else 'una distribución (3200), un préstamo al accionista (1130) o lo que la empresa le devuelve de lo '
                                  'que le prestó (2900)' end),
        'opciones', v_pers || coalesce(v_tr, '[]'::jsonb)));
    end if;
    if v_desconocida and m.monto < 0 then
      return jsonb_strip_nulls(jsonb_build_object(
        'motivo', 'cuenta_desconocida', 'regla', 'R3', 'otro_lado', v_ol,
        'texto', format('Dinero a %s ····%s, que no conozco: no es de ningún estado de cuenta ni tarjeta de la empresa, ni la diste de '
                        'alta como tuya. No se supone personal. %s', case when v_es_tj then 'la tarjeta' else 'la cuenta' end, v_otra,
                        v_alta),
        'opciones', coalesce(v_tr, '[]'::jsonb) || v_pers));
    end if;
    -- (Ronda 4c) LA TRANSFERENCIA SIN NÚMERO QUE NOMBRA A ALGUIEN («ONLINE
    -- TRANSFER TO EDGAR M PERSONAL»): no se supone ni una cuenta propia ni
    -- la personal de Edgar. Todo con su motivo, y el pago a alguien se
    -- clasifica. Antes salía «transferencia_un_lado» con «A 1030» sin motivo
    -- (la reserva nunca lo iba a traer) y las tarjetas sin pide_motivo (su
    -- botón, pulsado tal cual, fallaba).
    if v_nombrado and m.monto < 0 then
      return jsonb_strip_nulls(jsonb_build_object(
        'motivo', 'otro_lado_nombrado', 'regla', 'R3', 'otro_lado', v_ol,
        'texto', format('Dinero a «%s», que el banco nombra sin número de cuenta: no se supone ni una cuenta propia ni tu cuenta '
                        'personal. Si es tu cuenta personal: una distribución (3200), un préstamo al accionista (1130) o lo que la '
                        'empresa le devuelve de lo que le prestó (2900); si es una cuenta de la empresa, la transferencia a ella: las '
                        'dos, con su motivo escrito. Si es el pago a alguien (un subcontratista, un proveedor), clasifícalo con su '
                        'cuenta y su obra (fn_banco_clasificar).', v_ol->>'nombra'),
        'opciones', coalesce(v_tr, '[]'::jsonb) || coalesce(v_pers, '[]'::jsonb)));
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
    v_proc := fn_banco_procesador(v_txt);
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
      -- (Ronda 4: si el banco NO nombra a un procesador, lo que falta puede
      -- ser un pago parcial: va después de «parte de la factura» y pide su
      -- motivo, como fn_banco_cobrar. Antes era la primera opción de un Zelle
      -- de 970.70 contra una factura de 1,000.00.)
      select case when v_proc then 1 else 4 end, f.fecha,
             format('Factura #%s (%s) cobrada con tarjeta: el procesador se quedó %s de comisión (→ %s)%s', f.num, f.proyecto_id,
                    f.s1 - m.monto, coalesce(k->'dest'->>'cargo_banco', '6130'),
                    case when v_proc then ''
                         else '. El banco no nombra a ningún procesador de tarjetas: ¿no es un pago parcial? (con su motivo)' end),
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
    select jsonb_agg(case when o.p
                          then fn_banco_opcion_motivo(jsonb_build_object('texto', o.texto, 'llamar', 'fn_banco_cobrar',
                                                                         'args', jsonb_build_object('p_movimiento', m.id,
                                                                                                    'p_aplicaciones', o.apps)))
                          else jsonb_build_object('texto', o.texto, 'llamar', 'fn_banco_cobrar',
                                                  'args', jsonb_build_object('p_movimiento', m.id, 'p_aplicaciones', o.apps)) end
                     order by o.n, o.orden desc, o.p),
           bool_or(o.n <= 2)
      into v_fact, v_exacta
      -- (p: una comisión sin procesador que la diga, que pide su motivo)
      from (select op.*, (not v_proc and jsonb_path_exists(op.apps, '$[*].comision')) as p
              from op
             order by op.n, op.orden desc, (not v_proc and jsonb_path_exists(op.apps, '$[*].comision'))
             limit 6) o;
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
    -- (Ronda 4c) EL CRITERIO EN UN DEPÓSITO. Si el banco dice que viene de
    -- una cuenta de la empresa por su número (la de Chase, ····4392; la línea
    -- de crédito, ····8899), no es el cobro de un cliente: primero la
    -- transferencia (o el desembolso de la deuda), sin motivo; lo demás —un
    -- cobro, una factura, una devolución, un reembolso— con su motivo. Antes
    -- era al revés: el pase de Chase que llegaba primero a la reserva salía
    -- «deposito_parcial», con «Parte de la factura #1103» primero y sin
    -- motivo y «Desde 1010» el último; pulsado el primero, la factura quedaba
    -- cobrada con dinero de Chase, y el pase de Chase, al llegar, en
    -- tránsito.
    if v_ol->>'clase' = 'propia' then
      v_lista := coalesce(v_deuda, '[]'::jsonb) || coalesce(v_tr, '[]'::jsonb)
                 || coalesce((select jsonb_agg(fn_banco_opcion_motivo(o)
                                               || jsonb_build_object('texto', (o->>'texto')
                                                                              || case when o->>'texto' like '%(con su motivo)' then ''
                                                                                      else ' (con su motivo)' end) order by n)
                                from jsonb_array_elements(coalesce(v_cobros, '[]'::jsonb) || coalesce(v_grupos, '[]'::jsonb)
                                                          || coalesce(v_otro_cobro, '[]'::jsonb) || coalesce(v_devol, '[]'::jsonb)
                                                          || coalesce(v_reemb, '[]'::jsonb) || coalesce(v_fact, '[]'::jsonb))
                                     with ordinality as x(o, n)), '[]'::jsonb);
      return jsonb_strip_nulls(jsonb_build_object(
        'motivo', case when v_deuda is not null then 'deuda_propia' else 'transferencia_un_lado' end, 'regla', 'R3', 'otro_lado', v_ol,
        -- (ronda 4d: si un cobro anotado o una factura abierta lo explican
        -- por su monto —la regla del cuadre 52—, su botón pide el motivo y el
        -- texto lo dice; antes decía «sin motivo» y el botón lo pedía)
        'texto', case when v_deuda is not null
                      then format('Dinero que llega de ····%s, %s (%s): una deuda de la empresa, dada de alta por su número. Es su '
                                  'desembolso: a %s%s. No es el cobro de un cliente ni un ingreso: un cobro o una factura, '
                                  'solo con su motivo.', v_otra, v_deuda_cta,
                                  coalesce((select c.nombre from cuentas c where c.codigo = v_deuda_cta), 'sin nombre'), v_deuda_cta,
                                  case when fn_banco_deposito_explicado(m, k->'facturas') is not null
                                       then ', con su motivo escrito (el mismo monto lo tiene abierto un cliente: ver abajo)'
                                       else ', sin motivo' end)
                      else format('El banco dice que este dinero viene de tu cuenta %s (····%s): es dinero entre cuentas propias (un '
                                  'pase), no el cobro de un cliente. %s Un cobro o una factura, solo con su motivo.',
                                  v_ol->>'cuenta', v_ol->>'ultimos4',
                                  case when v_contra is not null then 'Su otro lado ya llegó: cásalos (un asiento, sin gasto).'
                                       else format('Confírmalo («Desde %s»): se postea la transferencia y su otro lado casará solo '
                                                   'con ella cuando llegue.', v_ol->>'cuenta') end) end
                 || coalesce(' Pero no se casa todavía: ' || (select o->>'bloqueo' from jsonb_array_elements(coalesce(v_tr, '[]'::jsonb)) o
                                                               where o ? 'bloqueo' limit 1) || '.', ''),
        'opciones', nullif(v_lista, '[]'::jsonb)));
    end if;
    v_lista := case when v_cobros is not null or v_grupos is not null or v_otro_cobro is not null or v_devol is not null
                         or v_reemb is not null or v_fact is not null or v_tr is not null or v_pers is not null
                    then case
                           -- (ronda 4c: de un número que no se conoce, como en un
                           -- retiro: primero las cuentas propias y después el
                           -- patrimonio, todo con su motivo; las facturas, detrás.
                           -- Antes iba el patrimonio primero, y la cabecera decía
                           -- otra cosa)
                           when v_desconocida
                           then coalesce(v_cobros, '[]'::jsonb) || coalesce(v_grupos, '[]'::jsonb) || coalesce(v_tr, '[]'::jsonb)
                                || coalesce(v_pers, '[]'::jsonb) || coalesce(v_otro_cobro, '[]'::jsonb)
                                || coalesce(v_devol, '[]'::jsonb) || coalesce(v_reemb, '[]'::jsonb) || coalesce(v_fact, '[]'::jsonb)
                           -- (ronda 4c: de alguien que el banco nombra sin número
                           -- —«FROM EDGAR M MARTINEZ»—: lo de siempre, y detrás el
                           -- patrimonio y las cuentas propias, con su motivo)
                           when v_nombrado
                           then coalesce(v_cobros, '[]'::jsonb) || coalesce(v_grupos, '[]'::jsonb) || coalesce(v_otro_cobro, '[]'::jsonb)
                                || coalesce(v_devol, '[]'::jsonb) || coalesce(v_reemb, '[]'::jsonb) || coalesce(v_fact, '[]'::jsonb)
                                || coalesce(v_pers, '[]'::jsonb) || coalesce(v_tr, '[]'::jsonb)
                           -- (ronda 4d: de la cuenta personal de Edgar dada de alta,
                           -- primero lo suyo —su préstamo, su aportación—, sin motivo;
                           -- el cobro de un cliente, con su motivo: EL CONTROL lo
                           -- pondría en rojo, y fn_banco_cobrar lo pide)
                           when v_personal
                           then coalesce(v_pers, '[]'::jsonb)
                                || coalesce((select jsonb_agg(fn_banco_opcion_motivo(o)
                                                              || jsonb_build_object('texto', (o->>'texto')
                                                                                             || case when o->>'texto' like '%(con su motivo)'
                                                                                                     then '' else ' (con su motivo)' end)
                                                              order by n)
                                               from jsonb_array_elements(coalesce(v_cobros, '[]'::jsonb) || coalesce(v_grupos, '[]'::jsonb)
                                                                         || coalesce(v_otro_cobro, '[]'::jsonb)
                                                                         || coalesce(v_fact, '[]'::jsonb)) with ordinality as x(o, n)),
                                            '[]'::jsonb)
                                || coalesce(v_devol, '[]'::jsonb) || coalesce(v_reemb, '[]'::jsonb) || coalesce(v_tr, '[]'::jsonb)
                           else coalesce(v_cobros, '[]'::jsonb) || coalesce(v_grupos, '[]'::jsonb)
                                -- (ronda 4: el dinero que llega de la cuenta personal de
                                -- Edgar, antes que las facturas de los clientes. Ronda 4b:
                                -- de una dada de alta, sin motivo)
                                || coalesce(v_pers, '[]'::jsonb) || coalesce(v_otro_cobro, '[]'::jsonb)
                                || coalesce(v_devol, '[]'::jsonb) || coalesce(v_reemb, '[]'::jsonb) || coalesce(v_fact, '[]'::jsonb)
                                || coalesce(v_tr, '[]'::jsonb) end end;
    return jsonb_strip_nulls(jsonb_build_object(
      'motivo', case when v_personal then 'transferencia_personal'
                     when v_cobros is not null then 'deposito_cobro' when v_grupos is not null then 'deposito_cobros'
                     when v_desconocida then 'cuenta_desconocida'
                     when v_otro_cobro is not null then 'deposito_otro_cobro'
                     when v_devol is not null then 'devolucion_compra'
                     when v_reemb is not null then 'reembolso_proveedor'
                     when v_fact is not null and v_exacta then 'deposito_sin_cobro'
                     when v_fact is not null then 'deposito_parcial'
                     when v_nombrado then 'otro_lado_nombrado'
                     when v_tr is not null then 'transferencia_un_lado'
                     else 'deposito_sin_factura' end,
      'otro_lado', case when v_nombrado then v_ol end,
      'regla', case when v_tr is not null and v_cobros is null and v_grupos is null and v_fact is null and v_reemb is null then 'R3'
                    when v_reemb is not null and v_cobros is null and v_grupos is null then 'R4' else 'R2' end,
      'texto', (case when v_cobros is not null
                    then 'Hay un cobro registrado por ese monto, pero con otra fecha: si es este depósito, cásalo.'
                    when v_grupos is not null
                    then 'Estos cobros ya registrados suman el depósito (varios cheques depositados juntos): cásalo con ellos. '
                         'Registrar otro cobro o un anticipo metería el mismo dinero dos veces.'
                    when v_personal
                    then format('Dinero que llega de una cuenta personal de Edgar (····%s, %s: la diste de alta como tuya): un '
                                'préstamo del accionista (2900), una aportación (3100) o lo que devuelve de lo que la empresa le '
                                'prestó (1130); nunca un ingreso. Si de verdad es el cobro de una factura (un cliente que le pagó a '
                                'él), está abajo.', v_otra, v_ol->>'nombre')
                    when v_desconocida
                    then format('Dinero que llega de la cuenta ····%s, que no conozco: no es de ningún estado de cuenta ni tarjeta de '
                                'la empresa, ni la diste de alta como tuya. No se supone personal: puede ser tu cuenta personal, el '
                                'pase desde una cuenta propia que todavía no trajo su estado de cuenta, o el cobro de un cliente (sus '
                                'facturas, abajo). %s', v_otra, v_alta)
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
                    -- (ronda 4c: de alguien que el banco nombra sin número)
                    when v_nombrado
                    then format('Dinero que llega de «%s», que el banco nombra sin número de cuenta: no se supone ni una cuenta propia '
                                'ni tu cuenta personal. Si es tu cuenta personal: un préstamo del accionista (2900), una aportación '
                                '(3100) o lo que devuelve de lo que la empresa le prestó (1130); si es una cuenta de la empresa, la '
                                'transferencia desde ella: las dos, con su motivo escrito. Si es el cobro de un cliente, regístralo '
                                'con su factura (fn_banco_cobrar). Nunca a ingreso.', v_ol->>'nombra')
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
                                 else '' end end)
               -- (ronda 4c: y si el banco nombra a alguien sin número, se dice)
               || case when v_nombrado and (v_cobros is not null or v_grupos is not null or v_otro_cobro is not null
                                            or v_devol is not null or v_reemb is not null or v_fact is not null)
                       then format(' Ojo: el banco dice que viene de «%s», sin número de cuenta: si es tu cuenta personal o una de la '
                                   'empresa, está abajo, con su motivo.', v_ol->>'nombra')
                       else '' end,
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
                                        -- (ronda 4c: y dónde va el motivo, como las demás)
                                        'pide', jsonb_build_array('p_motivo'),
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

  -- 12a. (Ronda 4) SU TICKET YA ESTÁ SUBIDO y espera en la BANDEJA DE LOS
  -- PUENTES (c3): leído, pero sin asiento todavía (sin obra, su regla en
  -- borrador, sin los 4 últimos de la tarjeta, una duda de su fecha…). El
  -- motor los busca (los del monto del cargo, o uno que se le parece, en la
  -- ventana de la compra, de su tarjeta o sin decir de cuál) y los manda en
  -- p_otros con «bandeja». Se resuelve allí —lo que dice el motivo de c3— y
  -- el cargo casa solo con su ticket. Antes el banco no los veía: el cargo
  -- salía «sin ticket… si tienes la foto, súbela» (la foto ya estaba),
  -- clasificarlo no pedía motivo, y en cuanto el ticket entraba al libro el
  -- gasto quedaba dos veces dentro de una conciliación ya confirmada.
  if m.monto < 0 and jsonb_typeof(p_otros) = 'array'
     and exists (select 1 from jsonb_array_elements(p_otros) t where t ? 'bandeja') then
    v_bdj := (select jsonb_agg(t order by o) from jsonb_array_elements(p_otros) with ordinality as x(t, o) where t ? 'bandeja');
    return jsonb_strip_nulls(jsonb_build_object(
      'motivo', 'ticket_en_bandeja', 'regla', 'R1 ticket en la bandeja de los puentes',
      'texto', format('Su ticket ya está subido y espera en la bandeja de los puentes (puentes_bandeja: todavía no está en el '
                      'libro): %s. Resuélvelo allí —lo que dice su motivo— y este cargo casa solo con él. Clasificarlo metería '
                      'el gasto dos veces en cuanto el ticket entre: solo con su motivo, si de verdad es otra compra.',
                      (select string_agg(format('el recibo %s del %s por %s%s (%s: %s)', t->>'recibo', t->>'fecha',
                                                -(t->>'monto')::numeric, coalesce(' de ' || (t->>'proveedor'), ''),
                                                coalesce(t->>'codigo', t->>'estado'), coalesce(t->>'motivo', 'sin motivo escrito')),
                                         '; ' order by o)
                         from jsonb_array_elements(v_bdj) with ordinality as x(t, o)))
               || case when exists (select 1 from jsonb_array_elements(v_bdj) t where (t->>'monto')::numeric <> m.monto)
                       then format(' (El banco dice %s: si el ticket se leyó con otro total, corrígelo también.)', -m.monto)
                       else '' end
               || case when v_obra is not null then format(' Obra propuesta: %s (%s).', v_obra->>'nombre', v_obra->>'por')
                       else coalesce(v_varias, '') end
               || case when v_pagos is not null then ' Si fue el pago de la cuenta de un proveedor, está abajo.' else '' end,
      'tickets_bandeja', v_bdj, 'obra', v_obra, 'opciones', v_pagos));
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
-- las demás que lo tienen; en fn_banco_pagar_proveedor, «p_partidas.motivo»:
-- p_partidas va como {"motivo": "…", "partidas": <las de la opción, o
-- nulo>}). La de una función sin motivo, tal cual.
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
                                    'fn_prestamo_cuota', 'fn_banco_duplicado', 'fn_banco_pagar_proveedor')
              then o || jsonb_build_object('pide_motivo', true,
                                           'pide', (select coalesce(jsonb_agg(distinct x.v), '[]'::jsonb)
                                                      from (select jsonb_array_elements_text(case when jsonb_typeof(o->'pide') = 'array'
                                                                                                  then o->'pide' else '[]'::jsonb end) as v
                                                            union all
                                                            select case o->>'llamar' when 'fn_banco_cobrar' then 'p_notas'
                                                                                     when 'fn_banco_pagar_proveedor' then 'p_partidas.motivo'
                                                                                     else 'p_motivo' end) x))
              else o end
$$;
revoke execute on function public.fn_banco_opcion_motivo(jsonb) from public, anon, authenticated, service_role;

-- (Ronda 4b) EL PRINCIPIO, en las opciones de la bandeja: ningún botón
-- pulsado tal cual deja el control en rojo, y nada va del banco al
-- patrimonio del accionista sin su motivo escrito. Cada opción de
-- fn_banco_clasificar sin motivo:
--   · con una línea al patrimonio del accionista (fn_banco_es_accionista:
--     1130, 2900, 3000, 3100, 3200, 3900), si el banco no nombra una cuenta
--     personal de Edgar dada de alta: pide su motivo;
--   · en un depósito que HOY explica un cobro anotado o una factura abierta
--     por ese monto (fn_banco_deposito_explicado: la regla del cuadre 52):
--     pide su motivo, salvo la que va entera al patrimonio desde una cuenta
--     personal dada de alta (el cuadre 52 la conoce por su procedencia,
--     «cuenta_personal»).
-- fn_banco_clasificar los frena igual, con su mensaje. Antes «De Edgar…:
-- préstamo del accionista · 2900» por el mismo monto que una factura
-- abierta entraba tal cual y el control salía en rojo; y «Para Edgar…:
-- distribución · 3200», con el número de la reserva recién abierta, entraba
-- en verde.
create or replace function public.fn_banco_opciones_principio(m public.movimientos_banco, p_prop jsonb, p_ctx jsonb default null)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_personal boolean;
  v_expl     text;
  v_ops      jsonb;
  v_n        int;
begin
  if p_prop is null or jsonb_typeof(p_prop->'opciones') is distinct from 'array'
     or not exists (select 1 from jsonb_array_elements(p_prop->'opciones') o
                     where o->>'llamar' = 'fn_banco_clasificar' and not coalesce((o->>'pide_motivo')::boolean, false)
                       and fn_banco_limpio(o->'args'->>'p_motivo') is null) then
    return p_prop;
  end if;
  v_personal := coalesce(fn_banco_otro_lado(m)->>'clase' = 'personal', false);
  v_expl := case when m.monto > 0 then fn_banco_deposito_explicado(m, case when p_ctx ? 'facturas' then p_ctx->'facturas' end) end;
  select jsonb_agg(case when x.marca
                        then fn_banco_opcion_motivo(x.o)
                             || jsonb_build_object('texto', (x.o->>'texto')
                                                            || case when x.o->>'texto' like '%(con su motivo)' then '' else ' (con su motivo)' end)
                        else x.o end order by x.n),
         count(*) filter (where x.marca)
    into v_ops, v_n
    from (select o, n,
                 o->>'llamar' = 'fn_banco_clasificar' and not coalesce((o->>'pide_motivo')::boolean, false)
                 and fn_banco_limpio(o->'args'->>'p_motivo') is null
                 and ((not v_personal and exists (select 1 from jsonb_array_elements(case when jsonb_typeof(o->'args'->'p_lineas') = 'array'
                                                                                          then o->'args'->'p_lineas' else '[]'::jsonb end) l
                                                   where fn_banco_es_accionista(l->>'cuenta')))
                      or (v_expl is not null
                          and not (v_personal
                                   and not exists (select 1 from jsonb_array_elements(case when jsonb_typeof(o->'args'->'p_lineas') = 'array'
                                                                                           then o->'args'->'p_lineas' else '[]'::jsonb end) l
                                                    where not fn_banco_es_accionista(l->>'cuenta'))))) as marca
            from jsonb_array_elements(p_prop->'opciones') with ordinality as x(o, n)) x;
  if coalesce(v_n, 0) = 0 then
    return p_prop;
  end if;
  return p_prop || jsonb_build_object('opciones', v_ops)
         || case when v_expl is not null
                 then jsonb_build_object('explicado', v_expl,
                                         'texto', coalesce(p_prop->>'texto' || ' ', '')
                                                  || format('Ojo: lo explica %s. Clasificarlo pide su motivo escrito: sin él, el '
                                                            'dinero del cliente entraría dos veces (el control lo pondría en rojo).',
                                                            v_expl))
                 else '{}'::jsonb end;
end $$;
revoke execute on function public.fn_banco_opciones_principio(public.movimientos_banco, jsonb, jsonb)
  from public, anon, authenticated, service_role;


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
  -- (ronda 4b: y, al salir, EL PRINCIPIO en sus opciones —el patrimonio del
  -- accionista y el depósito que explica una factura piden su motivo—:
  -- fn_banco_opciones_principio)
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
        -- (ronda 4: también pagar a un proveedor y la cuota de un préstamo,
        -- que ahora lo frenan igual: fn_banco_apertura_freno)
        'opciones', (select jsonb_agg(case when o->>'llamar' in ('fn_banco_clasificar', 'fn_banco_cobrar', 'fn_banco_transferencia',
                                                                 'fn_banco_pagar_proveedor', 'fn_prestamo_cuota')
                                           then fn_banco_opcion_motivo(o) else o end order by n)
                       from jsonb_array_elements(coalesce(v_base->'opciones', '[]'::jsonb)) with ordinality as x(o, n)));
      v_base := jsonb_strip_nulls(v_base);
    end if;
  end if;
  if v_base->>'motivo' in ('posible_duplicado', 'transferencia_otro_lado', 'varios_candidatos')
     or (p_ctx is not null and not coalesce(p_ctx->'aper_cuentas' ? m.cuenta, false)) then
    return fn_banco_opciones_principio(m, v_base, p_ctx);
  end if;
  v_ap := fn_banco_apertura_opciones(m);
  if v_ap is null then
    return fn_banco_opciones_principio(m, v_base, p_ctx);
  end if;
  if coalesce((v_ap->>'fuertes')::int, 0) = 0 then
    return fn_banco_opciones_principio(m, v_base || jsonb_build_object(
      'texto', coalesce(v_base->>'texto', '')
               || case when v_ap ? 'contradice'
                       -- (ronda 4d: lo que el banco dice que es de una cuenta de la
                       -- empresa o de la personal de Edgar)
                       then format(' O la partida en tránsito de la conciliación de apertura del mismo monto, aunque %s: si de verdad '
                                   'es ella, cásalo con ella con su motivo.', v_ap->>'contradice')
                       else ' O una parte de una partida en tránsito de la conciliación de apertura (el banco la trajo en partes): si '
                            'lo es, cásalo con ella con su motivo.' end,
      'opciones', coalesce(v_base->'opciones', '[]'::jsonb) || (v_ap->'opciones')), p_ctx);
  end if;
  return fn_banco_opciones_principio(m, jsonb_strip_nulls(v_base || jsonb_build_object(
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
                            '[]'::jsonb))), p_ctx);
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
    -- (Ronda 4d) Lo pendiente que un papel de c3 ya nombra (el cobro o la
    -- devolución que la app registró con su movimiento): solo R- lo casa,
    -- con su papel, y si EL CRITERIO lo frena, se propone. Ninguna otra
    -- regla lo junta con otra cosa: el asiento de ese papel ya tiene su
    -- dinero en el libro (casarlo con un pase lo pondría dos veces). Se
    -- pregunta en cada regla, movimiento por movimiento, por los índices de
    -- movimiento_id de cobros y devoluciones (sacarlo antes de todo lo
    -- pendiente costaba de 2 a 3 ms en cada «Casar» con un año de banco).
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
        -- (Ronda 4d) EL CRITERIO, también aquí: el cobro que la app (c3,
        -- fn_cobro_registrar con su movimiento) dice que es este depósito no
        -- casa solo si el banco dice que viene de una cuenta de la empresa o
        -- de la personal de Edgar (solo un depósito que dice transferencia
        -- puede nombrarlas): se propone, con su motivo. Antes casaba solo
        -- («R2 el cobro dice este movimiento») y el pase de Chase quedaba
        -- como el cobro de la factura #1103.
        if r.clase = 'cobro' then
          select * into m from movimientos_banco where id = r.mov;
          if coalesce(m.tipo_banco, '') = 'XFER' or coalesce(m.desc_norm ~* v_pat_tr, false) then
            continue when fn_banco_criterio_libro(m, r.asiento, 'cobro')->>'contradice' is not null;
          end if;
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
             cand as (select p.id as mov, p.fecha, p.al, l.asiento_id, l.orden, l.origen_tabla, l.origen_id, l.tr, l.fdoc,
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
             -- (Ronda 5) Las CUOTAS DE UN MISMO PRÉSTAMO registradas antes
             -- que el banco (una semanal: varias por el mismo monto a 7
             -- días, y la ventana fuerte de cada cargo, de 7 días antes a 3
             -- después, abarca dos): de cada movimiento, su cuota más
             -- cercana en fecha; de cada cuota, su cargo más cercano. Así el
             -- cargo del 19 casa solo con la cuota del 19. Antes ninguno
             -- casaba (dos candidatas cada uno: nm, nl ≠ 1) y la bandeja
             -- ofrecía primero la del 12.
             cvq as (select c.*,
                            case when c.origen_tabla = 'prestamo_cuotas'
                                 then (select q.prestamo_id from prestamo_cuotas q
                                        where q.id = (case when c.origen_id ~ '^[0-9a-fA-F-]{36}$' then c.origen_id::uuid end)) end
                              as prestamo
                       from cand c where c.v is not null),
             cv as (select x.* from (select c.*,
                                            row_number() over (partition by c.mov, c.prestamo
                                                               order by abs(c.fdoc - c.fecha), c.fdoc, c.asiento_id, c.orden) as rq_m,
                                            row_number() over (partition by c.asiento_id, c.orden
                                                               order by abs(c.fdoc - c.fecha), c.fecha, c.mov) as rq_l
                                       from cvq c) x
                     where x.prestamo is null or (x.rq_m = 1 and x.rq_l = 1)),
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
        -- (ronda 4d: lo que un cobro o una devolución de c3 ya nombra, solo
        -- con su papel: ver arriba)
        continue when v_clase not in ('cobro', 'devolucion')
                      and (exists (select 1 from cobros c where c.movimiento_id = r.mov::text and c.estado = 'vigente')
                           or exists (select 1 from cobros_devoluciones d where d.movimiento_id = r.mov::text));
        -- (Ronda 4c) EL CRITERIO: la línea de una transferencia ya posteada
        -- casa sola solo si este movimiento y el que la posteó no se
        -- contradicen y los dos lo confirman (fn_banco_lados_linea); y un
        -- depósito que nombra una cuenta de la empresa por su número no casa
        -- solo con un cobro (no es el cobro de un cliente). Los dos se
        -- proponen. Antes, con «Desde 1010» pulsado en la reserva, el pase de
        -- Chase a la cuenta personal de Edgar casaba solo con esa línea, y la
        -- distribución quedaba como un pase 1010 → 1030.
        if v_clase = 'transferencia' then
          select * into m from movimientos_banco where id = r.mov;
          continue when not coalesce((fn_banco_lados_linea(m, r.asiento_id)->>'solas')::boolean, false);
        elsif v_clase = 'cobro' then
          -- (solo un depósito que dice transferencia puede nombrar una cuenta:
          -- los demás no se miran; ronda 4d: con EL CRITERIO contra el libro,
          -- también la cuenta personal de Edgar)
          select * into m from movimientos_banco where id = r.mov;
          if coalesce(m.tipo_banco, '') = 'XFER' or coalesce(m.desc_norm ~* v_pat_tr, false) then
            continue when fn_banco_criterio_libro(m, r.asiento_id, 'cobro')->>'contradice' is not null;
          end if;
        elsif v_clase not in ('recibo', 'devolucion') then
          -- (Ronda 4d) UN ASIENTO ESCRITO A MANO (fn_postear desde el SQL
          -- Editor), la cuota ya registrada, lo que sea que ya estaba en el
          -- libro: casa solo solo si lo que dice el banco del otro lado y lo
          -- que dice el asiento no se contradicen y el banco lo confirma
          -- (fn_banco_criterio_libro). Lo coherente sigue igual: la cuenta
          -- personal de Edgar contra un asiento a 2900/3100/3200/1130, un
          -- tercero contra su cobro, el prestamista contra su deuda. Antes R1
          -- casaba solo cualquier asiento por el cruce exacto: el pase a mano
          -- 1010 → 1030 con el dinero que el banco decía venir de la cuenta
          -- personal de Edgar, el pago a mano de la Gold con el pago a una
          -- tarjeta ····5555 que nadie conocía, y las aportaciones a mano con
          -- el cheque de un cliente y con el pase desde la reserva.
          select * into m from movimientos_banco where id = r.mov;
          continue when not coalesce((fn_banco_criterio_libro(m, r.asiento_id, v_clase)->>'solas')::boolean, false);
        end if;
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
                                    substring(regexp_replace(mo.desc_norm, '(^| )(TO|FROM) (CHK|CK) ', ' ', 'g') from '(?:^| )(?:CHECK|CHK|CHEQUE|CK)(?: NO)? ?#? ?0*([1-9][0-9]{0,9})(?: |$)')),
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
                       and not exists (select 1 from cobros c where c.movimiento_id = p.id::text and c.estado = 'vigente')
                       and not exists (select 1 from cobros_devoluciones d where d.movimiento_id = p.id::text)
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
        -- (ronda 4c: un depósito que nombra una cuenta de la empresa por su
        -- número no es el cobro de unos clientes: se propone)
        select * into m from movimientos_banco where id = r.mov;
        if coalesce(m.tipo_banco, '') = 'XFER' or coalesce(m.desc_norm ~* v_pat_tr, false) then
          continue when fn_banco_otro_lado(m)->>'clase' = 'propia';
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
                          and not exists (select 1 from cobros c where c.movimiento_id = p.id::text and c.estado = 'vigente')
                          and not exists (select 1 from cobros_devoluciones d where d.movimiento_id = p.id::text)
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
          -- (Ronda 4d) EL CRITERIO: la partida en tránsito de QuickBooks (el
          -- cheque de un cliente, el cheque a un proveedor) no es el dinero
          -- que el banco dice que viene de (o va a) una cuenta de la empresa o
          -- la personal de Edgar: no casa sola, se propone con su motivo.
          -- Antes, por su monto en la primera semana, el +3,200.00 «FROM CHK
          -- ...7781» de Edgar casaba solo con el depósito del 30-sep, y el
          -- cheque de verdad, al llegar, salía como un depósito nuevo.
          select * into m from movimientos_banco where id = r.mov;
          if coalesce(m.tipo_banco, '') = 'XFER' or coalesce(m.desc_norm ~* v_pat_tr, false)
             or (m.monto < 0 and coalesce(m.desc_norm ~* v_pat_pt, false)) then
            continue when fn_banco_criterio_libro(m, null, 'apertura')->>'contradice' is not null;
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
                  and not exists (select 1 from uno where uno.id = mb.id)
                  and not exists (select 1 from cobros c where c.movimiento_id = mb.id::text and c.estado = 'vigente')
                  and not exists (select 1 from cobros_devoluciones d where d.movimiento_id = mb.id::text)),
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
                       -- no son la misma transferencia. Ronda 4b: ni si es una
                       -- cuenta personal de Edgar dada de alta; y el pago de una
                       -- tarjeta que nombra OTRA tarjeta, tampoco.)
                       -- (Ronda 4c) EL CRITERIO de los dos lados (fn_banco_lados):
                       -- casan solos solo si ninguno contradice al otro —un
                       -- número que no se conoce, una personal, otra cuenta de la
                       -- empresa, alguien sin número— y los dos lo confirman (si
                       -- uno nombra un número, es el de la otra cuenta). Antes un
                       -- número que no se conocía pasaba: el pase de Chase a
                       -- ····7781 casaba solo con el depósito de la reserva que
                       -- decía venir de ····4392, y el pago de Chase a la tarjeta
                       -- personal ····5555 con el pago recibido en la Gold.
                       and coalesce((fn_banco_lados(fn_banco_otro_lado((select x from movimientos_banco x where x.id = a.id)), a.cuenta,
                                                    fn_banco_otro_lado((select x from movimientos_banco x where x.id = b.id)), b.cuenta)
                                     ->>'solas')::boolean, false)),
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
                      and fn_puente_cuenta_mal(d.cuenta) is null
                      -- (ronda 4b: nunca solo al patrimonio del accionista)
                      and not fn_banco_es_accionista(d.cuenta))
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
         -- (ronda 5: de las cuotas de un mismo préstamo, solo la más cercana
         -- de cada movimiento y el movimiento más cercano de cada cuota,
         -- como en el casado solo de arriba)
         cvq as (select cand.*, p.al, p.fecha,
                        case when cand.origen_tabla = 'prestamo_cuotas'
                             then (select q.prestamo_id from prestamo_cuotas q
                                    where q.id = (case when cand.origen_id ~ '^[0-9a-fA-F-]{36}$' then cand.origen_id::uuid end)) end
                          as prestamo
                   from cand join pool p on p.id = cand.mov
                  where cand.v is not null),
         cv as (select x.mov, x.asiento_id, x.orden, x.numero, x.origen_tabla, x.origen_id, x.fdoc, x.tr, x.v, x.num, x.al,
                       count(*) over (partition by x.asiento_id, x.orden) - 1 as otros
                  from (select c.*,
                               row_number() over (partition by c.mov, c.prestamo
                                                  order by abs(c.fdoc - c.fecha), c.fdoc, c.asiento_id, c.orden) as rq_m,
                               row_number() over (partition by c.asiento_id, c.orden
                                                  order by abs(c.fdoc - c.fecha), c.fecha, c.mov) as rq_l
                          from cvq c) x
                 where x.prestamo is null or (x.rq_m = 1 and x.rq_l = 1)),
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
                  where o.n <= 3),
         -- (Ronda 4) LOS TICKETS QUE ESPERAN EN LA BANDEJA DE LOS PUENTES (c3):
         -- subidos y leídos, sin asiento todavía (puente_documentos pendiente,
         -- espera o error: sin obra, su regla en borrador, sin los 4 últimos
         -- de la tarjeta…). Son pocos (la bandeja de c3, por su índice de
         -- estado). Los de cada cargo sin nada que case: en la ventana de la
         -- compra, por su monto, o uno del mismo comercio que se le parece (a
         -- 12 % o menos: el de otro total; no solo el comercio o solo el
         -- monto, como con las líneas de su cuenta, porque esta bandeja es
         -- de todas las cuentas), de su tarjeta o sin los 4 últimos de una
         -- tarjeta de OTRA cuenta, y no pagados en efectivo ni a la cuenta
         -- del proveedor (esos no pasan por el banco). Los tres que más se le
         -- parecen van a su propuesta y a su firma, con «bandeja»: un ticket
         -- que entra o sale de esa bandeja la rehace.
         rb as materialized
               (select rx.id, round(rx.total, 2) as total, coalesce(rx.fecha, fn_fecha_miami(rx.creado)) as f, rx.proveedor,
                       nullif(btrim(rx.ultimos4), '') as u4, pd.estado, pd.codigo, left(pd.motivo, 300) as motivo,
                       coalesce((select array_agg(w.w) from regexp_split_to_table(fn_banco_norm(rx.proveedor), ' ') as w(w)
                                  where length(w.w) >= 4
                                    and w.w not in ('THE', 'INC', 'LLC', 'CORP', 'STORE', 'SUPPLY', 'COMPANY', 'SERVICES')),
                                '{}'::text[]) as pal
                  from puente_documentos pd
                  join recibos rx on rx.id = (case when pd.documento_id ~ '^-?[0-9]{1,18}$' then pd.documento_id::bigint end)
                 where exists (select 1 from pc)
                   and pd.tabla = 'recibos' and pd.estado in ('pendiente', 'espera', 'error')
                   and rx.contabilizado_en is null and rx.estado is distinct from 'anulado'
                   and rx.total is not null and round(rx.total, 2) > 0
                   and coalesce(rx.metodo_pago, '') not in ('efectivo', 'cuenta_proveedor')),
         obd as (select o.mov, o.id, o.total, o.f, o.proveedor, o.estado, o.codigo, o.motivo
                   from (select p.id as mov, b.*,
                                row_number() over (partition by p.id order by abs(-b.total - p.monto), b.f, b.id) as n
                           from pc p
                           join rb b on b.f between p.desde and p.fecha + 3
                          where (-b.total = p.monto
                                 or (abs(-b.total - p.monto) <= 0.12 * greatest(b.total, abs(p.monto)) and b.pal && p.pal))
                            and not (b.u4 is not null
                                     and exists (select 1 from tarjetas t where t.ultimos4 = b.u4 and t.cuenta <> p.cuenta)
                                     and not exists (select 1 from tarjetas t where t.ultimos4 = b.u4 and t.cuenta = p.cuenta))) o
                  where o.n <= 3)
    select (select coalesce(jsonb_object_agg(y.mov, y.c), '{}'::jsonb)
              from (select z.mov, jsonb_agg(z.j order by z.o0, z.o1, z.o2, z.o3) as c
                      from (select o.mov, jsonb_build_object('asiento_id', o.asiento_id, 'orden', o.orden, 'recibo', o.origen_id,
                                                             'numero', o.numero, 'fecha', o.fdoc, 'monto', o.monto) as j,
                                   1 as o0, abs(o.monto - p.monto) as o1, o.fdoc as o2, o.numero as o3
                              from otr o join pool p on p.id = o.mov
                            union all
                            -- (ronda 4: los de la bandeja de los puentes, primero)
                            select b.mov, jsonb_strip_nulls(jsonb_build_object('bandeja', true, 'recibo', b.id::text, 'fecha', b.f,
                                                                               'monto', -b.total, 'proveedor', b.proveedor,
                                                                               'estado', b.estado, 'codigo', b.codigo,
                                                                               'motivo', b.motivo)),
                                   0, abs(-b.total - p.monto), b.f, b.id::text
                              from obd b join pool p on p.id = b.mov) z
                     group by z.mov) y),
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
                -- (ronda 4d: la marca de la versión que la hizo: v_banco_bandeja
                -- no enseña los botones de una propuesta de otra versión —los
                -- de antes del último pegado, que ya no valen— hasta «Casar»)
                || jsonb_build_object('version', fn_banco_version())
                || jsonb_build_object('firma', v_fmov,
                                      -- (ronda 4: la parte de su firma que no es del movimiento —lo que
                                      -- se cobra, los proveedores y lo que se les debe, los préstamos, los
                                      -- descriptores—: con ella fn_banco_clasificar sabe, sin rehacerla, si
                                      -- la guardada sigue siendo la de hoy)
                                      'firma_g', fn_banco_firma_mov(v_firma, v_tipos->>m.cuenta, m.monto,
                                                                    coalesce(m.desc_norm ~* v_pat_cd, false),
                                                                    null, null, null, null, null, v_mira, null))
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
    -- (Los de la lista, por su id; y los que ya decían «llegó su ticket»,
    -- por su cuenta y su fecha, sin repetir los de la lista. Con un «or»
    -- entre los dos, Postgres leía cada movimiento del banco y su propuesta
    -- en cada «Casar»: con un año de banco, de 3 a 4 ms por llamada; así,
    -- con la cuenta pedida, va por su índice. Los mismos movimientos.
    -- Ronda 4, grupo 4.)
    for m in select * from movimientos_banco x
              where x.id in (select k::uuid from jsonb_object_keys(v_llego) k)
             union all
             select * from movimientos_banco x
              where x.fecha >= v_corte
                and (p_mov is null or x.id = p_mov) and (p_cuenta is null or x.cuenta = p_cuenta)
                and (p_desde is null or x.fecha >= p_desde)
                and x.propuesta->>'motivo' = 'llego_su_ticket'
                and not (x.id in (select k::uuid from jsonb_object_keys(v_llego) k)) loop
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
          'motivo', 'llego_su_ticket', 'regla', 'R1', 'version', fn_banco_version(),
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


-- (Fin de la parte 1 de 2.)
select 'c6 · parte 1 de 2' as control, public.fn_banco_version() = 2026100901 as ok,
       to_jsonb('Pegada la parte 1 de c6-banco.sql (marca 2026100901). Ahora pega c6-banco-parte2.sql: hasta entonces el banco '
                'está a medias y su control lo dice en rojo.'::text) as detalle;
