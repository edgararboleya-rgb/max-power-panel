-- =====================================================================
-- C6 · EL BANCO — c6-banco.sql, PARTE 2 DE 2 (marca 2026100901).
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
set local lock_timeout = '500ms';

-- LA GUARDA de la parte 2: la parte 1 de ESTA versión tiene que estar
-- pegada (su fn_banco_version() dice 2026100901). Si no, para aquí y no toca
-- nada (MX000).
do $$
declare
  v_ver bigint;
begin
  if to_regprocedure('public.fn_banco_version()') is not null then
    execute 'select public.fn_banco_version()' into v_ver;
  end if;
  if v_ver is distinct from 2026100901 then
    raise exception using
      errcode = 'MX000',
      message = format('c6-banco (parte 2 de 2) NO se aplicó, no se tocó nada: antes va la parte 1 de esta misma versión '
                       '(marca 2026100901), y la base tiene %s. Pega c6-banco-parte1.sql y después esta; o el archivo '
                       'entero, c6-banco.sql.',
                       case when v_ver is null then 'el banco sin pegar' else 'el banco de la marca ' || v_ver end);
  end if;
end $$;

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
-- gasto queda una vez. Dentro de una conciliación confirmada, solo si la
-- deja diciendo lo mismo (ronda 4: el ticket que llega con el mes ya
-- cerrado); si la cambiaría, se reabre antes.
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
  -- (Ronda 4: dentro de una conciliación confirmada ya no se pide reabrirla
  -- de entrada: se mira al final, ver abajo.)
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
  -- (Ronda 4) DENTRO DE UNA CONCILIACIÓN CONFIRMADA: hecho el cambio, cada
  -- confirmada de la cuenta que lo tiene (su corte, el día del cargo o
  -- después) tiene que seguir diciendo lo mismo: sus partidas y su saldo en
  -- libros, como la revisión (fn_banco_verificar). Con el mes del corte
  -- cerrado (el ticket que llega en noviembre del cargo del 30-oct), la
  -- clasificación se reversa el 1-nov y el ticket entra el 1-nov: al corte
  -- el cargo casaba con la clasificación (fn_conciliacion_items, el casado
  -- que valía al corte) y octubre no cambia. Antes se pedía reabrirla
  -- siempre, y rehecha salía la clasificación como «cargo en circulación».
  -- Si la cambiaría, no se hace nada (la excepción lo deshace todo) y se
  -- pide reabrirla, como antes.
  for v_conc in select * from conciliaciones cc
                 where cc.cuenta = m.cuenta and cc.estado = 'confirmada' and cc.tipo = 'normal' and cc.fecha_corte >= m.fecha
                 order by cc.fecha_corte loop
    if fn_banco_saldo_libros(v_conc.cuenta, v_conc.fecha_corte) <> v_conc.saldo_libros
       or exists (with hoy as (select i.lado, i.asiento_id, i.orden, i.movimiento_id, i.apertura_partida_id, i.monto
                                 from fn_conciliacion_items(v_conc.cuenta, v_conc.fecha_corte, false) i),
                       antes as (select p.lado, p.asiento_id, p.orden, p.movimiento_id, p.apertura_partida_id, p.monto
                                   from conciliacion_partidas p where p.conciliacion_id = v_conc.id)
                  (select * from hoy except all select * from antes)
                  union all
                  (select * from antes except all select * from hoy)) then
      raise exception using errcode = 'MX008',
        message = format('La conciliación de %s al %s está confirmada con este cargo y el cambio la cambiaría: reábrela antes '
                         '(fn_conciliacion_reabrir, con su motivo), cambia la clasificación por el ticket y vuelve a conciliar.',
                         v_conc.cuenta, v_conc.fecha_corte);
    end if;
  end loop;
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
  v_bc    banco_casados;
begin
  perform fn_banco_exigir_dueno();
  if p_con is null or jsonb_typeof(p_con) <> 'object' then
    raise exception using errcode = '22023', message = 'Con qué casa, como objeto JSON (lineas, asiento, recibo, cobro, partida_apertura o movimiento).';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(p_con) k
   where k not in ('lineas', 'asiento', 'recibo', 'cobro', 'partida_apertura', 'movimiento', 'movimientos', 'comision', 'corrige',
                   'cuota', 'diferencia', 'casado');
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
                'capital o interes). O, en un movimiento ya casado, {"casado": …} con su motivo: por qué ese casado es correcto.';
  end if;
  -- (Ronda 4d) «ES CORRECTO, POR ESTO»: el motivo de un casado vivo que no lo
  -- tenía, escrito UNA vez (con su rastro en banco_historial). Es lo que pide
  -- EL CONTROL cuando lo que dice el banco del otro lado y lo que dice el
  -- libro se contradicen y de verdad es así (el cliente que le pagó a Edgar y
  -- él lo pasó a la empresa; el pase escrito a mano que el banco nombra de
  -- otra forma). Si no es correcto, se des-casa (fn_banco_descasar, con su
  -- motivo). No cambia ninguna cifra ni el casado: solo dice por qué.
  if p_con ? 'casado' then
    perform pg_advisory_xact_lock(820261001, hashtext('casar'));
    select * into m from movimientos_banco where id = p_movimiento for update;
    select * into v_bc from banco_casados bc
     where bc.id = (case when p_con->>'casado' ~ '^[0-9a-fA-F-]{36}$' then (p_con->>'casado')::uuid end)
       and bc.movimiento_id = p_movimiento and bc.deshecho_el is null
     for update;
    if not found then
      raise exception using errcode = 'MX008',
        message = 'Ese no es el casado vivo de este movimiento (su id está en v_banco_movimientos, o en el detalle del control).';
    end if;
    if fn_banco_limpio(p_motivo) is null then
      raise exception using errcode = '22023',
        message = 'Di por qué ese casado es correcto (el motivo): queda escrito con él. Si no lo es, des-cásalo (fn_banco_descasar).';
    end if;
    if fn_banco_limpio(v_bc.motivo) is not null then
      raise exception using errcode = 'MX008', message = format('Ese casado ya tiene su motivo: «%s».', v_bc.motivo);
    end if;
    perform fn_banco_marca('motivo:' || v_bc.id);
    update banco_casados set motivo = fn_banco_limpio(p_motivo) where id = v_bc.id;
    perform fn_banco_marca(null);
    return fn_banco_resumen(p_movimiento) || jsonb_build_object('casado', v_bc.id, 'motivo', fn_banco_limpio(p_motivo));
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
    -- (ronda 4d: EL CRITERIO, como abajo)
    if fn_banco_limpio(p_motivo) is null then
      v_x := fn_banco_criterio_libro(m, null, 'apertura')->>'contradice';
      if v_x is not null then
        raise exception using errcode = 'MX008',
          message = format('No se casa con la partida de la apertura sin su motivo: %s. Si de verdad es ella, dilo en el motivo.', v_x);
      end if;
    end if;
    perform fn_banco_casar_lineas(m.id, 'apertura', v_pa.id::text, null, '[]'::jsonb,
                                  'Apertura: Edgar casó la partida en tránsito del 30-sep con el movimiento que el banco trajo antes '
                                  'del corte (estaba ignorado)', false, false, p_motivo);
    return fn_banco_resumen(p_movimiento);
  end if;
  m := fn_banco_tomar(p_movimiento);
  -- (Ronda 4d) EL COBRO QUE LA APP REGISTRÓ CON ESTE MOVIMIENTO (y que no
  -- casó solo): su asiento ya tiene este dinero. Solo se casa con ESE cobro
  -- (con su motivo, si EL CRITERIO lo pide); con otra cosa lo metería dos
  -- veces: se anula antes (fn_cobro_anular, con su motivo).
  v_x := fn_banco_cobro_reclama(m.id);
  if v_x is not null
     and not (p_con ? 'cobro' and not p_con ? 'corrige'
              and exists (select 1 from cobros c
                           where c.id = (case when p_con->>'cobro' ~ '^[0-9a-fA-F-]{36}$' then (p_con->>'cobro')::uuid end)
                             and c.movimiento_id = m.id::text and c.estado = 'vigente')) then
    raise exception using errcode = 'MX008',
      message = format('La app registró %s con este movimiento: su asiento ya tiene este dinero. Si es ese cobro, cásalo con él '
                       '({"cobro": …}); si no, anúlalo antes (fn_cobro_anular, con su motivo) y casa este movimiento con lo que es.',
                       v_x);
  end if;

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
    -- (ronda 4d: el otro lado que la app registró como un cobro, tampoco)
    v_x := fn_banco_cobro_reclama(m2.id);
    if v_x is not null then
      raise exception using errcode = 'MX008',
        message = format('La app registró %s con el otro lado (%s del %s): su asiento ya tiene ese dinero. Si no es su cobro, anúlalo '
                         'antes (fn_cobro_anular, con su motivo) y los dos casan solos.', v_x, m2.cuenta, m2.fecha);
    end if;
    if m.monto > 0 then   -- el asiento sale del lado que sale
      v_ases := m.id; m := m2; m2 := (select x from movimientos_banco x where x.id = v_ases);
    end if;
    -- (Ronda 4b) Si el banco dice que el dinero fue a (o vino de) OTRA
    -- cuenta —una cuenta personal de Edgar dada de alta, u otra cuenta de la
    -- empresa que no es esta—, juntarlos como una transferencia pide su
    -- motivo escrito: la de Edgar es patrimonio del accionista, no dinero
    -- entre cuentas propias.
    -- (Ronda 4c) Con EL CRITERIO de los dos lados (fn_banco_lados): también
    -- un número que no se conoce y alguien que el banco nombra sin número.
    -- Antes el número que no se conocía pasaba sin motivo: el pase de Chase
    -- a ····7781 se juntaba a mano con el depósito de la reserva «FROM EDGAR
    -- M MARTINEZ» como un pase 1010 → 1030, y la bandeja lo ofrecía así.
    if fn_banco_limpio(p_motivo) is null then
      v_ref := fn_banco_lados(fn_banco_otro_lado(m), m.cuenta, fn_banco_otro_lado(m2), m2.cuenta)->>'contradice';
      if v_ref is not null then
        raise exception using errcode = 'MX008',
          message = format('No se juntan como una transferencia sin su motivo: %s. Si de verdad son el mismo dinero, dilo en el motivo.',
                           v_ref);
      end if;
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
    -- (Ronda 4d) EL CRITERIO: si el banco dice que este dinero viene de (o
    -- va a) una cuenta de la empresa o la personal de Edgar, no es la partida
    -- de QuickBooks (el cheque de un cliente, el cheque a un proveedor): solo
    -- con su motivo. La regla automática de la apertura tampoco lo casa
    -- solo, y la bandeja lo pide.
    if fn_banco_limpio(p_motivo) is null then
      v_x := fn_banco_criterio_libro(m, null, 'apertura')->>'contradice';
      if v_x is not null then
        raise exception using errcode = 'MX008',
          message = format('No se casa con la partida de la apertura sin su motivo: %s. Si de verdad es ella, dilo en el motivo.', v_x);
      end if;
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
    -- (Ronda 4c) EL CRITERIO: un depósito que nombra una cuenta de la
    -- empresa por su número no es el cobro de un cliente: solo con su motivo
    -- (y la bandeja lo pide).
    if fn_banco_limpio(p_motivo) is null and not p_con ? 'corrige' then
      perform fn_banco_cobro_propia(m, 'el motivo (p_motivo)');
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
                 || jsonb_build_object('anexo', 'comision', 'cobro', v_cobro.id)
                 -- (ronda 4: su porcentaje y su tope, como en fn_banco_cobrar)
                 || jsonb_build_object('comision', v_com, 'bruto', v_cobro.monto, 'tope', round(0.035 * v_cobro.monto + 0.30, 2),
                                       'pct', round(100 * v_com / v_cobro.monto, 2)));
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
  -- (Ronda 4c) EL CRITERIO: un cobro, con un depósito que nombra una cuenta
  -- de la empresa por su número, pide su motivo (como arriba).
  if v_clase = 'cobro' and fn_banco_limpio(p_motivo) is null then
    perform fn_banco_cobro_propia(m, 'el motivo (p_motivo)');
  end if;
  -- (Ronda 4d) EL CRITERIO CONTRA EL LIBRO, con lo que ya estaba en él: un
  -- asiento escrito a mano, una cuota, un cobro, lo que sea (la línea de
  -- una transferencia del banco, abajo, con los dos movimientos). Si lo que
  -- dice el banco del otro lado y lo que dice el asiento se contradicen
  -- —el pase a mano 1010 → 1030 y el banco que dice que el dinero vino de la
  -- cuenta personal de Edgar; la aportación a mano y el pase desde la
  -- reserva—, «Confirmar cruce» pide su motivo (y la bandeja lo marca).
  if v_clase not in ('transferencia', 'recibo', 'devolucion') and fn_banco_limpio(p_motivo) is null then
    v_x := fn_banco_criterio_libro(m, v_ases, v_clase)->>'contradice';
    if v_x is not null then
      raise exception using errcode = 'MX008',
        message = format('No se casa con %s sin su motivo: %s. Si de verdad es esto, dilo en el motivo; si no, cásalo o clasifícalo '
                         'por lo que es.', (select a.numero from asientos a where a.id = v_ases), v_x);
    end if;
  end if;
  if v_clase = 'transferencia' then
    -- El otro lado de una transferencia ya posteada: con ESE asiento.
    if jsonb_array_length(v_lin) <> 1 then
      raise exception using errcode = 'MX008',
        message = 'El otro lado de una transferencia casa con UNA línea: la de esta cuenta en ese asiento.';
    end if;
    -- (Ronda 4c) EL CRITERIO: si este movimiento y el que posteó la
    -- transferencia se contradicen (fn_banco_lados_linea: uno nombra una
    -- personal, un número que no se conoce, otra cuenta, o a alguien sin
    -- número), se casa solo con su motivo, y la bandeja lo pide.
    if fn_banco_limpio(p_motivo) is null then
      v_ref := fn_banco_lados_linea(m, (v_lin->0->>'asiento_id')::uuid)->>'contradice';
      if v_ref is not null then
        raise exception using errcode = 'MX008',
          message = format('No se casa como el otro lado de esa transferencia sin su motivo: %s. Si de verdad es el mismo dinero, dilo '
                           'en el motivo.', v_ref);
      end if;
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
  v_proc  boolean := true;
  v_expl  text;
begin
  perform fn_banco_exigir_dueno();
  m := fn_banco_tomar(p_movimiento);
  if not fn_puente_es_banco(m.cuenta) or m.monto <= 0 then
    raise exception using errcode = 'MX008', message = 'Un cobro es un depósito: un movimiento que ENTRA a un banco.';
  end if;
  -- (Ronda 4c) EL CRITERIO: un depósito que nombra una cuenta de la empresa
  -- por su número no es el cobro de un cliente (fn_banco_cobro_propia): solo
  -- con su porqué en las notas.
  if fn_banco_limpio(p_notas) is null then
    perform fn_banco_cobro_propia(m, 'las notas (p_notas)');
  end if;
  if jsonb_typeof(v_apps) is distinct from 'array' or jsonb_array_length(v_apps) = 0 then
    raise exception using errcode = '22023',
      message = 'Di a qué va el depósito: a una o varias facturas ({"factura_id": …}), o de anticipo de una obra ({"proyecto_id": …}).';
  end if;
  -- (Ronda 4: el depósito de los primeros 30 días con la apertura posteada
  -- y su conciliación sin confirmar puede ser el depósito en tránsito del
  -- 30-sep, que QuickBooks ya cobró: solo con su motivo, en las notas. Y,
  -- con la conciliación de apertura confirmada, el que es una de sus
  -- partidas en tránsito, igual: fn_banco_apertura_freno. Antes este
  -- camino no la miraba y el mismo dinero se cobraba dos veces.)
  perform fn_banco_apertura_freno(m, p_notas, 'registrarle un cobro', 'las notas (p_notas)');
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
  -- (Ronda 4) EL TOPE DE LA COMISIÓN: lo que se queda un procesador de
  -- tarjetas es una PARTE del cobro (menos que el depósito: MX005), y como
  -- mucho un 3.5 % más 0.30 de cada factura (lo que miran la propuesta y
  -- fn_banco_casar_con); por encima, solo con su motivo en las notas, y
  -- queda escrito en el asiento de la comisión (su porcentaje y su tope).
  -- Antes no tenía tope: un depósito de 100.00 cobraba entera una factura
  -- de 1,000.00 y mandaba 900.00 a 6130, sin motivo y en verde.
  if v_com > 0 then
    if v_com >= m.monto then
      raise exception using errcode = 'MX005',
        message = format('La comisión (%s) es lo que el procesador de tarjetas se quedó del cobro: tiene que ser menos que el depósito '
                         '(%s). Si el cliente pagó menos, es un pago parcial: di cuánto va a cada factura, sin comisión.', v_com,
                         m.monto);
    end if;
    select sum(round(0.035 * fn_puente_monto(x->>'monto', 'Una aplicación: el monto') + 0.30, 2)) into v_tope
      from jsonb_array_elements(v_apps) x
     where jsonb_typeof(x) = 'object' and x ? 'monto';
    if v_com > coalesce(v_tope, 0) and fn_banco_limpio(p_notas) is null then
      raise exception using errcode = 'MX008',
        message = format('La comisión (%s, el %s %% del cobro de %s) es más de lo que se queda un procesador de tarjetas (como mucho '
                         'un 3.5 %% más 0.30 de cada factura: %s). ¿El cliente pagó menos (un pago parcial)? Entonces di cuánto va a '
                         'cada factura, sin comisión. Si de verdad es la comisión, dilo en las notas (p_notas).', v_com,
                         round(100 * v_com / (m.monto + v_com), 2), m.monto + v_com, coalesce(v_tope, 0));
    end if;
    -- (y si el banco no nombra a ningún procesador —QuickBooks Payments,
    -- Stripe, Square…: fn_banco_procesador—, lo que falta puede ser un pago
    -- parcial: también con su motivo. Un Zelle de 970.70 no trae comisión.)
    v_proc := fn_banco_procesador(case when m.memo is null then m.desc_norm else btrim(m.desc_norm || ' ' || fn_banco_norm(m.memo)) end);
    if not v_proc and fn_banco_limpio(p_notas) is null then
      raise exception using errcode = 'MX008',
        message = format('El depósito (%s «%s») no nombra a ningún procesador de tarjetas (QuickBooks Payments, Stripe, Square…): lo que '
                         'falta para %s puede ser un pago parcial (el cliente pagó menos), no una comisión. Si es un pago parcial, di '
                         'cuánto va a cada factura, sin comisión. Si de verdad es la comisión, dilo en las notas (p_notas).', m.monto,
                         coalesce(m.descripcion, ''), m.monto + v_com);
    end if;
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
  -- (Ronda 4b) UN ANTICIPO DE OBRA cuando unas facturas abiertas explican
  -- el depósito entero: un cobro anotado o una factura por ese monto (la
  -- regla del cuadre 52, fn_banco_deposito_explicado), o, si el banco nombra
  -- a un procesador de tarjetas, el lote de una, dos o tres facturas por su
  -- bruto cuya diferencia cabe en sus comisiones (lo que propone la
  -- bandeja). Solo con su porqué en las notas: las facturas seguirían
  -- abiertas y el cliente, con un saldo a favor que no es. Antes entraba sin
  -- motivo aunque la bandeja propusiera las dos facturas del lote.
  if v_com = 0 and fn_banco_limpio(p_notas) is null
     and not exists (select 1 from jsonb_array_elements(v_apps) x where jsonb_typeof(x) <> 'object' or x ? 'factura_id') then
    v_expl := fn_banco_deposito_explicado(m);
    if v_expl is null
       and fn_banco_procesador(case when m.memo is null then m.desc_norm else btrim(m.desc_norm || ' ' || fn_banco_norm(m.memo)) end) then
      with f as materialized (
             select (x->>'id')::bigint as id, x->>'num' as num, (x->>'s1')::numeric as s1
               from jsonb_array_elements(fn_banco_contexto_facturas()) x
              where coalesce((x->>'fecha')::date, m.fecha) <= m.fecha and (x->>'s1')::numeric > 0
                and (x->>'s1')::numeric <= m.monto * 1.04 + 1)
      select coalesce(
               (select format('la factura #%s cobrada con tarjeta (%s, neta de su comisión)', a.num, a.s1)
                  from f a
                 where a.s1 > m.monto and a.s1 - m.monto <= round(0.035 * a.s1 + 0.30, 2)
                 order by a.id limit 1),
               (select format('las facturas #%s y #%s cobradas con tarjeta (%s, netas de sus comisiones)', a.num, b.num, a.s1 + b.s1)
                  from f a join f b on b.id > a.id
                 where a.s1 + b.s1 > m.monto
                   and a.s1 + b.s1 - m.monto <= round(0.035 * a.s1 + 0.30, 2) + round(0.035 * b.s1 + 0.30, 2)
                 order by a.id, b.id limit 1),
               (select format('las facturas #%s, #%s y #%s cobradas con tarjeta (%s, netas de sus comisiones)', a.num, b.num, c.num,
                              a.s1 + b.s1 + c.s1)
                  from f a join f b on b.id > a.id join f c on c.id > b.id
                 where a.s1 + b.s1 + c.s1 > m.monto
                   and a.s1 + b.s1 + c.s1 - m.monto
                       <= round(0.035 * a.s1 + 0.30, 2) + round(0.035 * b.s1 + 0.30, 2) + round(0.035 * c.s1 + 0.30, 2)
                 order by a.id, b.id, c.id limit 1))
        into v_expl;
    end if;
    if v_expl is not null then
      -- (el verbo y el pronombre con lo que lo explica: un cobro, una
      -- factura o las facturas de un lote)
      raise exception using errcode = 'MX008',
        message = format('Este depósito lo %s %s: regístralo con %s (lo que propone la bandeja: fn_banco_cobrar con sus '
                         'facturas, o fn_banco_casar_con con su cobro, y la comisión aparte si la hay). Un anticipo de la obra '
                         'dejaría las facturas abiertas y al cliente con un saldo a favor que no es. Si de verdad es un anticipo, '
                         'dilo en las notas (p_notas).',
                         case when v_expl like 'las %' then 'explican' else 'explica' end, v_expl,
                         case when v_expl like 'las %' then 'ellas' when v_expl like 'la %' then 'ella' else 'él' end);
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
                 || jsonb_build_object('anexo', 'comision', 'cobro', v_c.id)
                 -- (ronda 4: su porcentaje y su tope, y el motivo si pasa del
                 -- tope: el cuadre 52 los mira)
                 || jsonb_strip_nulls(jsonb_build_object('comision', v_com, 'bruto', m.monto + v_com, 'tope', v_tope,
                                                         'pct', round(100 * v_com / (m.monto + v_com), 2), 'procesador', v_proc,
                                                         'motivo_edgar', case when v_com > coalesce(v_tope, 0) or not v_proc
                                                                              then fn_banco_limpio(p_notas) end)));
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
  v_motivo text;
  v_sobra  text;
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
  -- (Ronda 4) p_partidas también como objeto, con el MOTIVO que pide un
  -- pago que puede ser una partida en tránsito de la apertura:
  --   {"motivo": "…", "partidas": [ … ]}   ("partidas" nulo o sin poner: FIFO)
  -- (La firma no cambia: c2 la tiene en su reparto.)
  if jsonb_typeof(p_partidas) = 'object' then
    select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(p_partidas) k where k not in ('motivo', 'partidas');
    if v_sobra is not null or (p_partidas ? 'partidas' and jsonb_typeof(p_partidas->'partidas') not in ('array', 'null')) then
      raise exception using errcode = '22023',
        message = format('p_partidas como objeto lleva "motivo" y "partidas" (la lista, o nulo: FIFO)%s.',
                         coalesce('; sobra: ' || v_sobra, ''));
    end if;
    v_motivo := fn_banco_limpio(p_partidas->>'motivo');
    p_partidas := case when jsonb_typeof(p_partidas->'partidas') = 'array' then p_partidas->'partidas' end;
  end if;
  m := fn_banco_tomar(p_movimiento);
  select * into v_prov from proveedores where id = p_proveedor;
  if not found then
    raise exception using errcode = '22023', message = 'No existe ese proveedor.';
  end if;
  -- (Ronda 4: el cheque a un proveedor que QuickBooks ya pagó en septiembre
  -- —en circulación al 30-sep— no se paga otra vez contra 2010)
  perform fn_banco_apertura_freno(m, v_motivo,
                                  case when m.monto > 0 then 'aplicarlo como reembolso del proveedor'
                                       else 'aplicarlo a lo que se le debe al proveedor' end,
                                  'el motivo (p_partidas como {"motivo": "…", "partidas": …})');
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
                              || jsonb_strip_nulls(jsonb_build_object('proveedor', jsonb_build_object('id', v_prov.id, 'nombre', v_prov.nombre),
                                                                      'motivo_edgar', v_motivo)));
    perform fn_banco_casar_lineas(m.id, 'pago_proveedor', p_proveedor::text, (v_res->>'id')::uuid,
                                  jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 1)),
                                  'R4 reembolso de un proveedor: contra lo que tenía a favor en ' || v_cxp, false, true, v_motivo);
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
                            || jsonb_strip_nulls(jsonb_build_object('proveedor', jsonb_build_object('id', v_prov.id, 'nombre', v_prov.nombre),
                                                                    'motivo_edgar', v_motivo)));
  perform fn_banco_casar_lineas(m.id, 'pago_proveedor', p_proveedor::text, (v_res->>'id')::uuid,
                                jsonb_build_array(jsonb_build_object('asiento_id', (v_res->>'id')::uuid, 'orden', 1)),
                                'R4 pago a proveedor: a lo que se le debe en ' || v_cxp || case when p_partidas is null then ' (FIFO)'
                                                                                           else ' (lo que eligió Edgar)' end,
                                false, true, v_motivo);
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
  v_ol    jsonb;
  v_mot   jsonb;
begin
  perform fn_banco_exigir_dueno();
  -- (la cuenta como la dice Edgar: la del plan o su código corto, '2013')
  p_cuenta := fn_banco_cuenta_resolver(p_cuenta);
  m := fn_banco_tomar(p_movimiento);
  -- (Ronda 4d: el cobro que la app registró con este movimiento ya lo tiene
  -- en el libro: se anula antes, o se casa con él)
  v_otro := fn_banco_cobro_reclama(m.id);
  if v_otro is not null then
    raise exception using errcode = 'MX008',
      message = format('La app registró %s con este movimiento: su asiento ya tiene este dinero. Si no es su cobro (es este pase), '
                       'anúlalo antes (fn_cobro_anular, con su motivo) y confírmalo después; si de verdad es el cobro, cásalo con él '
                       '(fn_banco_casar_con con {"cobro": …}, con su motivo).', v_otro);
  end if;
  -- (Ronda 4: la partida en tránsito de la apertura —el pago de la tarjeta
  -- del 29-sep que Chase cobró el 1-oct— no se postea otra vez)
  perform fn_banco_apertura_freno(m, p_motivo, 'postearlo como transferencia', 'el motivo (p_motivo)');
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
  -- (Ronda 4) La otra cuenta que nombra el banco no es esta, o esta es un
  -- banco que nunca trajo su estado de cuenta: solo con su motivo. (Ronda
  -- 4b: también si nombra una cuenta personal de Edgar dada de alta, o un
  -- número que no se conoce: se dice cómo darlo de alta.)
  -- (Ronda 4c) Las dos cosas, y lo pendiente de p_cuenta que dice que el
  -- dinero fue a otro sitio, con EL CRITERIO y en UNA función que la bandeja
  -- usa igual para marcar su botón (fn_banco_transferencia_motivo): ningún
  -- «A …» o «Desde …» sin «pide_motivo» se frena aquí.
  v_tipo := fn_banco_tipo_cuenta(m.cuenta);
  v_tipo2 := fn_banco_tipo_cuenta(p_cuenta);
  v_ol := fn_banco_otro_lado(m);
  v_mot := fn_banco_transferencia_motivo(m, p_cuenta, v_ol);
  if v_mot is not null and fn_banco_limpio(p_motivo) is null then
    raise exception using errcode = 'MX008',
      message = case when v_mot->>'que' = 'senal' and v_tipo = 'tarjeta' and m.monto > 0
                     then format('Un abono en la tarjeta que no dice que es un pago («%s») es casi siempre la devolución de una compra: '
                                 'clasifícala contra la cuenta y la obra de su gasto (fn_banco_clasificar), y el costo baja una vez. '
                                 'Como transferencia, %s quedaría con un cargo en circulación que el banco no va a traer nunca. Si de '
                                 'verdad fue un pago a la tarjeta, dilo en el motivo.', coalesce(m.descripcion, ''), p_cuenta)
                     when v_mot->>'que' = 'senal' and v_tipo = 'tarjeta'
                     then 'Una tarjeta que manda dinero a un banco (un adelanto de efectivo) no se supone: si de verdad lo es, dilo en '
                          'el motivo.'
                     when v_mot->>'que' = 'senal'
                     then format('«%s» no dice que sea dinero entre cuentas propias (ni transferencia, ni el emisor o los 4 últimos '
                                 'de la tarjeta): una domiciliación (la luz, el seguro) es un gasto y se clasifica. Si de verdad es '
                                 'una transferencia a %s, dilo en el motivo.', coalesce(m.descripcion, ''), p_cuenta)
                     when v_mot->>'que' = 'contrapartida'
                     then format('No se postea como transferencia con %s sin su motivo: %s. Si este dinero de verdad salió de (o llegó '
                                 'a) %s por otro movimiento que todavía no llega, dilo en el motivo.', p_cuenta, v_mot->>'texto',
                                 p_cuenta)
                     else format('No se postea como transferencia a %s sin su motivo: %s. Si es la cuenta personal de Edgar, es una '
                                 'distribución (3200) o un préstamo (al accionista, 1130; del accionista, 2900), o una aportación '
                                 '(3100): fn_banco_clasificar (dala de alta con fn_banco_cuenta_personal y entra sin motivo). Si es una '
                                 'cuenta de la empresa que todavía no trajo su estado de cuenta (la reserva recién abierta, una tarjeta '
                                 'nueva, la línea de crédito), da de alta su número (un lote vacío con "confirmo_cuenta": true, o '
                                 'fn_tarjeta_alta). Si de verdad es %s, dilo en el motivo.', p_cuenta, v_mot->>'texto', p_cuenta) end;
  end if;
  -- (Ronda 4b) SU OTRO LADO YA SE CLASIFICÓ: en p_cuenta, el movimiento por
  -- el mismo dinero con el signo contrario (a 10 días o menos), que dice
  -- transferencia o pago, se casó como clasificado (una distribución, un
  -- gasto). Otra transferencia dejaría a p_cuenta con una línea que su
  -- banco no va a traer nunca: se des-casa aquel (fn_banco_descasar, con su
  -- motivo) y los dos casan solos. Solo con su motivo.
  -- (Ronda 4d: también casado como el cobro de un cliente —el que la app
  -- registró con su movimiento—: des-cásalo y anula su cobro)
  select string_agg(format('%s del %s por %s («%s», %s, %s)', x.id, x.fecha, x.monto, coalesce(x.descripcion, ''),
                           case when x.casado_clase = 'cobro' then 'casado como el cobro de un cliente: después anula su cobro'
                                else 'clasificado a ' || (select string_agg(distinct l.cuenta, ', ') from asiento_lineas l
                                                           where l.asiento_id = x.asiento_id and l.cuenta <> x.cuenta) end,
                           a.numero), '; '
                    order by abs(x.fecha - m.fecha), x.fecha)
    into v_otro
    from movimientos_banco x
    join asientos a on a.id = x.asiento_id
   where x.cuenta = p_cuenta and x.estado = 'casado' and x.casado_clase in ('clasificado', 'cobro') and x.monto = -m.monto
     and x.fecha between m.fecha - 10 and m.fecha + 10
     and (coalesce(x.tipo_banco, '') = 'XFER' or fn_banco_dice('transferencia', x.desc_norm) or fn_banco_dice('pago_tarjeta', x.desc_norm)
          or fn_banco_dice('pago_recibido', x.desc_norm))
     -- (ronda 4c: solo si los dos lados no se contradicen: EL CRITERIO)
     and fn_banco_lados(v_ol, m.cuenta, fn_banco_otro_lado(x), x.cuenta)->>'contradice' is null;
  if v_otro is not null and fn_banco_limpio(p_motivo) is null then
    raise exception using errcode = 'MX008',
      message = format('En %s, su otro lado ya se casó como otra cosa: el movimiento %s. Si es este mismo dinero, des-casa aquel '
                       '(fn_banco_descasar, con su motivo: su asiento se reversa) y los dos casan solos como una transferencia. Otra '
                       'transferencia dejaría a %s con una línea que su banco no va a traer nunca. Si de verdad es otro dinero, dilo '
                       'en el motivo.', p_cuenta, v_otro, p_cuenta);
  end if;
  -- (Ronda 4d) Y SU OTRO LADO, PENDIENTE, LO REGISTRÓ LA APP COMO EL COBRO
  -- DE UN CLIENTE (c3 con su movimiento; EL CRITERIO no lo dejó casar solo):
  -- se anula ese cobro y los dos casan solos. Antes «A 1030» entraba sin
  -- motivo y 1030 tenía el mismo dinero dos veces (el cobro y el pase).
  v_otro := null;
  select string_agg(format('%s del %s por %s («%s»), que la app registró como el cobro del %s por %s (%s)', x.id, x.fecha, x.monto,
                           coalesce(x.descripcion, ''), c.fecha, c.monto, c.id), '; ' order by abs(x.fecha - m.fecha), x.fecha)
    into v_otro
    from movimientos_banco x
    join cobros c on c.movimiento_id = x.id::text and c.estado = 'vigente'
   where x.cuenta = p_cuenta and x.estado = 'pendiente' and x.monto = -m.monto
     and x.fecha between m.fecha - 10 and m.fecha + 10
     and (coalesce(x.tipo_banco, '') = 'XFER' or fn_banco_dice('transferencia', x.desc_norm) or fn_banco_dice('pago_tarjeta', x.desc_norm)
          or fn_banco_dice('pago_recibido', x.desc_norm))
     and fn_banco_lados(v_ol, m.cuenta, fn_banco_otro_lado(x), x.cuenta)->>'contradice' is null;
  if v_otro is not null and fn_banco_limpio(p_motivo) is null then
    raise exception using errcode = 'MX008',
      message = format('En %s, su otro lado lo registró la app como el cobro de un cliente: el movimiento %s. Si es este mismo dinero, '
                       'anula ese cobro (fn_cobro_anular, con su motivo) y los dos casan solos como una transferencia. Otra '
                       'transferencia dejaría a %s con el mismo dinero dos veces (el cobro y el pase). Si de verdad es otro dinero, '
                       'dilo en el motivo.', p_cuenta, v_otro, p_cuenta);
  end if;
  v_otro := null;
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
  v_bdj    text;
  v_ol     jsonb;
  v_personal boolean := false;
  v_acc    text;
  v_noacc  int;
  v_expl   text;
  v_contr  text;
begin
  perform fn_banco_exigir_dueno();
  m := fn_banco_tomar(p_movimiento);
  if jsonb_typeof(p_lineas) is distinct from 'array' or jsonb_array_length(p_lineas) = 0 then
    raise exception using errcode = '22023', message = 'Di de qué es: una lista de líneas ({"cuenta": "…", …}).';
  end if;
  -- (Ronda 4d: el cobro que la app registró con este movimiento ya lo tiene
  -- en el libro: se anula antes, o se casa con él)
  v_otro := fn_banco_cobro_reclama(m.id);
  if v_otro is not null then
    raise exception using errcode = 'MX008',
      message = format('La app registró %s con este movimiento: su asiento ya tiene este dinero, y clasificarlo lo metería dos veces. '
                       'Si no es su cobro, anúlalo antes (fn_cobro_anular, con su motivo); si lo es, cásalo con él (fn_banco_casar_con '
                       'con {"cobro": …}, con su motivo si el banco dice otra cosa).', v_otro);
  end if;
  v_tipo := fn_banco_tipo_cuenta(m.cuenta);
  -- (Ronda 4) LA PROPUESTA DE HOY: los frenos de abajo que leen la
  -- propuesta del movimiento (el cobro o la factura que explica un
  -- depósito, el pago a un proveedor con partidas, el cheque devuelto, la
  -- nómina, la cuota) son los de «sin su motivo escrito». Sin motivo, la
  -- guardada tiene que ser la de hoy: si no está (nunca pasó por «Casar», o
  -- su vuelta se cortó por tiempo) o cambió lo que mira (su firma_g: lo que
  -- se cobra y las facturas, los proveedores y lo que se les debe, los
  -- préstamos, los descriptores; la factura o el proveedor que llegó
  -- después), se rehace aquí, como «Casar» este movimiento
  -- (fn_banco_casar). Antes se confiaba en la guardada, y sin ella el
  -- depósito de una factura abierta entraba al costo de la obra, el pago a
  -- CED otra vez al costo, el cheque devuelto a 6130 y la nómina a 6500, sin
  -- motivo y en verde. Si al mirarlo casa solo, no se clasifica: entraría
  -- dos veces. (Al día no se rehace: rehacerla mira todo lo pendiente de su
  -- cuenta, y con la bandeja de un año eran 0,2 s más en cada clic. Lo que
  -- casaría con él, su ticket de otro total, la cuota y la apertura se
  -- miran abajo de todos modos, en el momento.)
  if v_motivo is null
     and (m.propuesta is null or not (m.propuesta ? 'motivo')
          or (m.propuesta->>'firma_g') is distinct from
             fn_banco_firma_mov(fn_banco_firma(), v_tipo, m.monto,
                                coalesce(m.desc_norm ~* (select d.patron from banco_descriptores d where d.clave = 'cheque_devuelto'),
                                         false),
                                null, null, null, null, null, m.propuesta->'mira', null)) then
    perform fn_banco_casar_interno(null, null, m.id, true);
    select * into m from movimientos_banco where id = m.id;
    if m.estado <> 'pendiente' then
      raise exception using errcode = 'MX008',
        message = format('Este movimiento casa solo (%s): no se clasifica, entraría dos veces. Corre «Casar» (fn_banco_casar_todo) y '
                         'míralo en la bandeja.', coalesce(m.casado_regla, m.estado));
    end if;
    if m.propuesta is null or not (m.propuesta ? 'motivo') then
      raise exception using errcode = 'MX008',
        message = 'Este movimiento todavía no tiene su propuesta (se acabó el tiempo de mirarlo): corre «Casar» (fn_banco_casar_todo) '
                  'y vuelve a clasificarlo.';
    end if;
  end if;
  -- Primero casar: lo que ya está en el libro no se clasifica otra vez (en
  -- la ventana del cruce, fn_banco_ventana: la fecha de la compra, un
  -- cheque que tarda, el otro lado de una transferencia).
  select string_agg(x.que, ', ') filter (where x.v = 'fuerte'), string_agg(x.que, ', ') filter (where x.v = 'debil'),
         string_agg(x.c, '; ') filter (where x.v = 'fuerte')
    into v_cand, v_debil, v_contr
    from (select format('%s (%s, del %s)', coalesce(case when l.tr then 'la transferencia ' || l.numero end,
                                                    case when l.origen_tabla = 'recibos' then 'el recibo ' || l.origen_id end,
                                                    case when l.origen_tabla = 'cobros' then 'un cobro' end, 'el asiento ' || l.numero),
                        l.numero, l.fdoc) as que,
                 -- (ronda 4d: el número del cheque como lo lee el motor —el de
                 -- CHECKNUM o el de su descripción—: un cheque nunca es el otro
                 -- lado de una transferencia, fn_banco_ventana)
                 fn_banco_ventana(m.fecha, m.fecha_transaccion, fn_banco_cheque_num(m.cheque, m.descripcion), l.fdoc, l.monto, l.tr,
                                  v_tipo, fn_banco_tipo_cuenta(l.tr_otra), l.texto) as v,
                 -- (ronda 4c: si es la línea de una transferencia, ¿se contradicen
                 -- este y el que la puso? EL CRITERIO)
                 case when l.tr then fn_banco_lados_linea(m, l.asiento_id)->>'contradice' end as c
            from fn_banco_lineas_libres(array[m.cuenta], least(m.fecha, coalesce(m.fecha_transaccion, m.fecha)) - 60) l
           where l.monto = m.monto) x
   where x.v is not null;
  if v_cand is not null then
    raise exception using errcode = 'MX008',
      message = format('Esto ya está en el libro: casa con %s. Cásalo (fn_banco_casar_con): clasificarlo lo metería dos veces.%s',
                       v_cand,
                       -- (ronda 4c: y si la transferencia que lo espera dice otra cosa;
                       -- ronda 4d: solo entonces —format con un argumento nulo da '' y
                       -- no nulo, y el «Ojo: .» salía siempre—)
                       case when v_contr is not null
                            then format(' Ojo: %s. Si no es este dinero, des-casa el movimiento que puso esa transferencia '
                                        '(fn_banco_descasar, con su motivo: su asiento se reversa) y clasifica cada uno por lo que '
                                        'es; si sí lo es, cásalo con su motivo.', v_contr)
                            else '' end);
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
  -- (Ronda 4) SU TICKET YA SUBIDO, que espera en la BANDEJA DE LOS PUENTES
  -- (c3: sin obra, su regla en borrador, sin los 4 últimos…): el de su monto,
  -- o uno del mismo comercio que se le parece (a 12 % o menos), en la
  -- ventana de la compra, de su tarjeta (o sin los 4 últimos de una tarjeta
  -- de otra cuenta), sin asiento todavía. (Solo el monto parecido, o solo el
  -- comercio, no: la bandeja de c3 es de TODAS las cuentas, y un ticket de
  -- 60.00 de Shell no es el cargo de 64.20 de la ferretería.)
  -- Se resuelve allí y el cargo casa solo; clasificarlo metería el gasto dos
  -- veces en cuanto el ticket entre. Solo con su motivo escrito (y si
  -- después entra, «llegó su ticket» lo vuelve a preguntar). Mirado en el
  -- momento, como el de otro total: la propuesta guardada puede ser de
  -- antes de subirlo. Antes se clasificaba sin motivo, con la bandeja
  -- diciendo «súbela».
  if m.monto < 0 and v_motivo is null then
    select string_agg(format('el recibo %s del %s por %s (%s)', r.id, coalesce(r.fecha, fn_fecha_miami(r.creado)), round(r.total, 2),
                             coalesce(d.codigo, d.estado)), '; ' order by coalesce(r.fecha, fn_fecha_miami(r.creado)), r.id)
      into v_bdj
      from puente_documentos d
      join recibos r on r.id = (case when d.documento_id ~ '^-?[0-9]{1,18}$' then d.documento_id::bigint end)
     where d.tabla = 'recibos' and d.estado in ('pendiente', 'espera', 'error')
       and r.contabilizado_en is null and r.estado is distinct from 'anulado'
       and r.total is not null and round(r.total, 2) > 0
       and coalesce(r.metodo_pago, '') not in ('efectivo', 'cuenta_proveedor')
       and coalesce(r.fecha, fn_fecha_miami(r.creado))
           between (case when m.fecha_transaccion is not null then least(m.fecha_transaccion, m.fecha) - 3 else m.fecha - 7 end)
               and m.fecha + 3
       and (-round(r.total, 2) = m.monto
            or (abs(-round(r.total, 2) - m.monto) <= 0.12 * greatest(round(r.total, 2), abs(m.monto))
                and fn_banco_comercio(r.proveedor, m.desc_norm)))
       and not (nullif(btrim(r.ultimos4), '') is not null
                and exists (select 1 from tarjetas t where t.ultimos4 = btrim(r.ultimos4) and t.cuenta <> m.cuenta)
                and not exists (select 1 from tarjetas t where t.ultimos4 = btrim(r.ultimos4) and t.cuenta = m.cuenta));
    if v_bdj is not null then
      raise exception using errcode = 'MX008',
        message = format('Su ticket ya está subido y espera en la bandeja de los puentes: %s. Resuélvelo allí (lo que dice su motivo: '
                         'select * from puentes_bandeja;) y este cargo casa solo con él: clasificarlo metería el gasto dos '
                         'veces en cuanto el ticket entre. Si de verdad es otra compra, dilo en el motivo.', v_bdj);
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
                      -- (ronda 4c: la que la bandeja propone sin motivo; la que
                      -- lo pide —el cobro de un depósito que nombra una cuenta
                      -- propia— no lo explica)
                      where not coalesce((o->>'pide_motivo')::boolean, false)
                        and (o->>'llamar' = 'fn_banco_cobrar'
                             or (o->>'llamar' = 'fn_banco_casar_con' and coalesce(o->'args'->'p_con' ? 'cobro', false)))))
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
  -- (Ronda 4c) EL CRITERIO. Si el banco nombra una cuenta de la empresa por
  -- su número (fn_banco_otro_lado), esto es dinero entre cuentas propias:
  -- con una cuenta que trae estado de cuenta (la de Chase, la reserva, una
  -- tarjeta) es una transferencia —se casa con su otro lado o se confirma
  -- con fn_banco_transferencia— y clasificarlo pide su motivo; con una deuda
  -- dada de alta por su número (la línea de crédito, un préstamo) va a su
  -- cuenta, y lo que no vaya a ella ni a un gasto (sus intereses, un
  -- cargo), también con su motivo. Antes el pase a la reserva por su número
  -- se clasificaba a un gasto sin decir nada, y la reserva lo traía después
  -- sin su otro lado.
  v_ol := fn_banco_otro_lado(m);
  if v_motivo is null and v_ol->>'clase' = 'propia' then
    if v_ol->>'tipo' = 'deuda' then
      -- (Ronda 4d: sus intereses o un cargo, a su gasto, solo en lo que se le
      -- PAGA —un retiro—; lo que llega de ella —un depósito— es su
      -- desembolso, entero a su cuenta. Antes el desembolso de la línea de
      -- crédito se clasificaba a un gasto sin motivo: la deuda no subía y el
      -- gasto sí, L12.)
      if exists (select 1 from jsonb_array_elements(p_lineas) x join cuentas c on c.codigo = x->>'cuenta'
                  where c.codigo <> v_ol->>'cuenta' and (m.monto > 0 or c.tipo not in ('gasto', 'otro_gasto'))) then
        raise exception using errcode = 'MX008',
          message = case when m.monto > 0
                         then format('El banco dice que este dinero viene de ····%s, %s (%s): una deuda de la empresa, dada de alta '
                                     'por su número. Es su desembolso: va entero a %s. Si de verdad es otra cosa, dilo en el motivo.',
                                     v_ol->>'ultimos4', v_ol->>'cuenta',
                                     coalesce((select c.nombre from cuentas c where c.codigo = v_ol->>'cuenta'), 'sin nombre'),
                                     v_ol->>'cuenta')
                         else format('El banco dice que el otro lado es ····%s, %s (%s): una deuda de la empresa, dada de alta por su '
                                     'número. Va a %s (y sus intereses o un cargo, a su gasto). Si de verdad es otra cosa, dilo en el '
                                     'motivo.', v_ol->>'ultimos4', v_ol->>'cuenta',
                                     coalesce((select c.nombre from cuentas c where c.codigo = v_ol->>'cuenta'), 'sin nombre'),
                                     v_ol->>'cuenta') end;
      end if;
    else
      raise exception using errcode = 'MX008',
        message = format('El banco dice que el otro lado es tu cuenta %s (····%s): es dinero entre cuentas propias, una transferencia. '
                         'Cásalo con su otro lado (fn_banco_casar_con) o confírmalo (fn_banco_transferencia): clasificarlo lo dejaría '
                         'como otra cosa, y a %s con un movimiento sin su otro lado. Si de verdad es otra cosa, dilo en el motivo.',
                         v_ol->>'cuenta', v_ol->>'ultimos4', v_ol->>'cuenta');
    end if;
  end if;
  -- (Ronda 4b) EL PRINCIPIO. El dinero del banco que va al PATRIMONIO DEL
  -- ACCIONISTA (1130, 2900, 3000, 3100, 3200, 3900: fn_banco_es_accionista)
  -- va con su motivo escrito, salvo que el banco nombre una cuenta personal
  -- de Edgar dada de alta a propósito (fn_banco_cuenta_personal, o su
  -- tarjeta personal en 2900): en una S-corp cuenta para su base y sus
  -- distribuciones. Un número que no se conoce no es personal por defecto.
  -- Y un depósito que HOY explica un cobro anotado o una factura abierta
  -- por ese monto (la regla del cuadre 52: fn_banco_deposito_explicado) no
  -- se clasifica sin su motivo, salvo que vaya entero al patrimonio desde
  -- esa cuenta personal dada de alta. Antes el botón de la propia bandeja
  -- («De Edgar…: préstamo del accionista · 2900») pasaba sin motivo y el
  -- control salía en rojo; y con el número de la reserva recién abierta,
  -- «distribución · 3200» entraba en verde.
  select string_agg(format('%s (%s)', c.codigo, c.nombre), ', ' order by x.n) filter (where fn_banco_es_accionista(c.codigo)),
         count(*) filter (where not fn_banco_es_accionista(c.codigo))
    into v_acc, v_noacc
    from jsonb_array_elements(p_lineas) with ordinality as x(l, n)
    join cuentas c on c.codigo = x.l->>'cuenta';
  v_personal := coalesce(v_ol->>'clase' = 'personal', false);
  if v_motivo is null and m.monto > 0 and not (v_personal and v_acc is not null and v_noacc = 0) then
    v_expl := fn_banco_deposito_explicado(m);
  end if;
  if v_motivo is null and v_acc is not null and not v_personal then
    raise exception using errcode = 'MX008',
      message = format('%s es del patrimonio del accionista (lo que Edgar pone en la empresa o saca de ella: su préstamo, su '
                       'aportación, su distribución; un cargo personal en la tarjeta de la empresa): desde el banco va solo con su '
                       'motivo escrito, o sin él cuando el banco nombra una cuenta personal tuya dada de alta. %s%sDilo en el '
                       'motivo.', v_acc,
                       case when v_ol->>'clase' = 'desconocida'
                            then format('El banco dice que el otro lado es la cuenta ····%s, que no conozco: si es de la empresa (la '
                                        'reserva recién abierta, una tarjeta nueva, la línea de crédito…), da de alta su número (su '
                                        'estado de cuenta, o un lote vacío con "confirmo_cuenta": true) y es una transferencia '
                                        '(fn_banco_transferencia); si es tu cuenta personal, dala de alta desde el SQL Editor (select '
                                        'fn_banco_cuenta_personal(''%s'', ''el nombre de la cuenta'');) y entra sin motivo. ',
                                        v_ol->>'ultimos4', v_ol->>'ultimos4')
                            else '' end,
                       case when v_expl is not null
                            then format('Además, este depósito lo explica %s: si es su cobro, regístralo con él (fn_banco_casar_con o '
                                        'fn_banco_cobrar). ', v_expl)
                            else '' end);
  end if;
  if v_expl is not null then
    raise exception using errcode = 'MX008',
      message = format('Este depósito lo explica %s: clasificarlo sin motivo metería el dinero del cliente dos veces (el control lo '
                       'pondría en rojo, cuadre 52). Regístralo con su cobro (fn_banco_casar_con con {"cobro": …}, o fn_banco_cobrar '
                       'con su factura). Si de verdad es otra cosa, dilo en el motivo.', v_expl);
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
             || jsonb_strip_nulls(jsonb_build_object('motivo_edgar', v_motivo, 'propuesta', m.propuesta->>'motivo',
                                                     -- (ronda 4b: la cuenta personal de Edgar dada de alta que
                                                     -- nombra el banco: el cuadre 52 la conoce)
                                                     'cuenta_personal', case when v_personal then v_ol->>'ultimos4' end,
                                                     'cuenta_personal_nombre', case when v_personal then v_ol->>'nombre' end)));
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
  v_cr jsonb;
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
  select * into o from movimientos_banco where id = m.posible_duplicado_de for update;
  perform fn_banco_marca('movimiento:' || m.id);
  if p_es_el_mismo then
    update movimientos_banco
       set estado = 'ignorado', duplicado = 'es_el_mismo', propuesta = null,
           estado_motivo = format('Es el mismo movimiento que el del %s por %s (entró por %s, %s): no entra dos veces.%s', o.fecha,
                                  o.monto, o.origen, o.id, coalesce(' ' || fn_banco_limpio(p_motivo), ''))
     where id = m.id;
    perform fn_banco_marca(null);
    -- (Ronda 4d) LO QUE DICE EL DUPLICADO VALE PARA EL ORIGINAL: EL CRITERIO
    -- lee el número que trae el QFX con el nombre entero de lo que Plaid
    -- trajo cortado («por_duplicado»). Si el original ya está casado y eso
    -- contradice su casado (el pase a ····7781, que es 1030, casado como el
    -- cheque de un proveedor), no se dice «es el mismo» sin su motivo: se
    -- des-casa aquel antes, o el motivo dice por qué su casado es correcto y
    -- queda escrito también en él. Si el original espera en la bandeja, se
    -- vuelve a mirar con lo que ahora se sabe. Antes el número quedaba en el
    -- ignorado y el original seguía casado como si nada (L10).
    if o.estado in ('casado', 'en_transito') and o.casado_id is not null then
      v_cr := fn_banco_criterio_casado(o.casado_id);
      if v_cr->>'contradice' is not null and v_cr->>'motivo' is null then
        if fn_banco_limpio(p_motivo) is null then
          raise exception using errcode = 'MX008',
            message = format('Si es el mismo movimiento, lo que dice de su otro lado vale para el del %s por %s (%s), que está casado '
                             '(%s): %s. Des-casa aquel antes (fn_banco_descasar, con su motivo) y dilo otra vez; o, si su casado es '
                             'correcto, dilo con su motivo (queda escrito también en su casado).', o.fecha, o.monto, o.id,
                             o.casado_clase, v_cr->>'contradice');
        end if;
        perform fn_banco_marca('motivo:' || o.casado_id);
        update banco_casados set motivo = fn_banco_limpio(p_motivo) where id = o.casado_id;
        perform fn_banco_marca(null);
      end if;
    elsif o.estado = 'pendiente' then
      perform fn_banco_casar_interno(null, null, o.id, true);
    end if;
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
    -- (Ronda 4b: ni el patrimonio del accionista sin su motivo escrito)
    if fn_banco_es_accionista(v_c.codigo) and fn_banco_limpio(p_motivo) is null then
      raise exception using errcode = 'MX008',
        message = format('Línea %s: %s (%s) es del patrimonio del accionista: en un journal de nómina, solo con su motivo escrito.', v_i,
                         v_c.codigo, v_c.nombre);
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
--     des-casó no vuelve a casar solo (lo elige él). (Ronda 4: salvo lo
--     que el banco borró o Plaid quitó, que no fue: queda ignorado, y de
--     ignorado no vuelve.)
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
  v_quit   text;
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
  -- (Ronda 4) Lo que el banco borró o Plaid quitó (fn_banco_quitada) no
  -- fue: ignorado no vuelve a pendiente (nada lo casaría con razón), y
  -- casado, al des-casarlo queda ignorado con ese motivo. Si de verdad fue,
  -- el banco lo trae otra vez con su nuevo id y entra como nuevo.
  v_quit := fn_banco_quitada(m.id);
  if m.estado = 'ignorado' and v_quit is not null then
    raise exception using errcode = 'MX008',
      message = format('Ese movimiento no fue: %s. No vuelve a pendiente; si de verdad fue, el banco lo traerá otra vez (con su nuevo '
                       'id) y entrará como nuevo.', v_quit);
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
  if v_quit is not null then
    perform fn_banco_marca('movimiento:' || m.id);
    update movimientos_banco
       set estado = 'ignorado', propuesta = null,
           estado_motivo = format('No fue: %s. Des-casado (%s): no entra.', v_quit, v_motivo)
     where id = m.id and estado = 'pendiente';
    perform fn_banco_marca(null);
    return fn_banco_resumen(p_movimiento)
           || jsonb_strip_nulls(jsonb_build_object('deshecho', v_res->>'deshecho', 'motivo_deshecho', v_motivo,
                                                   'reverso', v_res->>'reverso', 'quitado', v_quit));
  end if;
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
  -- (Ronda 4b: una regla fija casa sola —R7—, y el dinero del banco que va
  -- al patrimonio del accionista nunca casa solo: pide su motivo escrito)
  if p_cuenta is not null and fn_banco_es_accionista(p_cuenta) then
    raise exception using errcode = 'MX004',
      message = format('%s es del patrimonio del accionista (préstamo, aportación, distribución): un descriptor no lleva el dinero '
                       'del banco ahí solo. Ese dinero va con su motivo escrito (fn_banco_clasificar), o sin él solo desde una cuenta '
                       'personal tuya dada de alta (fn_banco_cuenta_personal).', p_cuenta);
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

-- ---------------------------------------------------------------------
-- (Ronda 4b) fn_banco_cuenta_personal(ultimos4, nombre, activa, motivo) —
-- el SQL Editor da de alta una cuenta PERSONAL de Edgar por sus 4 últimos
-- (1.2b), o la da de baja con su motivo. Es lo único que hace de un número
-- «la cuenta personal de Edgar»: el dinero que va y viene de ella se
-- propone como lo que es —préstamo del accionista (2900), aportación
-- (3100), distribución (3200), préstamo al accionista (1130)— y sus
-- botones entran sin motivo. Un número que es de la empresa (el de un
-- estado de cuenta, una tarjeta dada de alta, el nombre de QuickBooks) no
-- se da de alta como personal. No es de la API. (Ronda 4c: las propuestas
-- de lo pendiente que lo nombra se rehacen aquí mismo, sin esperar al
-- siguiente «Casar».)
--   select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar');
--   select fn_banco_cuenta_personal('7781', null, false, 'La cerró en noviembre');
-- ---------------------------------------------------------------------
create or replace function public.fn_banco_cuenta_personal(p_ultimos4 text, p_nombre text default null,
                                                           p_activa boolean default true, p_motivo text default null)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_u4  text := right(regexp_replace(coalesce(p_ultimos4, ''), '[^0-9]', '', 'g'), 4);
  v_old banco_cuentas_personales;
  v_new banco_cuentas_personales;
  v_cta text;
  v_id  uuid;
  v_n   int := 0;
begin
  perform fn_banco_exigir_dueno();
  if v_u4 !~ '^[0-9]{4}$' then
    raise exception using errcode = '22023',
      message = format('Los 4 últimos de la cuenta personal (como los dice el banco: «CHK ...7781» es ''7781''); llegó «%s».',
                       coalesce(p_ultimos4, 'nulo'));
  end if;
  select * into v_old from banco_cuentas_personales where ultimos4 = v_u4 for update;
  if coalesce(p_activa, true) then
    -- (un número de la empresa no es personal: el de un estado de cuenta, una
    -- tarjeta dada de alta —también la personal en 2900, que ya lo es por c3—
    -- o el nombre con que QuickBooks trae una cuenta)
    v_cta := coalesce(fn_banco_numero_de(v_u4),
                      (select t.cuenta from tarjetas t where t.ultimos4 = v_u4 and t.activa order by t.cuenta limit 1));
    if v_cta is not null then
      raise exception using errcode = 'MX004',
        message = format('····%s es de %s (%s): una cuenta de la empresa, o una tarjeta dada de alta en c3, no es tu cuenta personal. '
                         'Si de verdad es tuya (el número cambió de dueño), retira antes lo que la hace de la empresa.', v_u4, v_cta,
                         coalesce((select c.nombre from cuentas c where c.codigo = v_cta), 'sin nombre'));
    end if;
    if fn_banco_limpio(p_nombre) is null and v_old.ultimos4 is null then
      raise exception using errcode = '22023',
        message = 'Di de qué cuenta es (su nombre: «Chase personal de Edgar»), para que la bandeja la nombre.';
    end if;
    v_new := v_old;
    v_new.ultimos4 := v_u4;
    v_new.nombre := coalesce(fn_banco_limpio(p_nombre), v_old.nombre);
    v_new.activa := true;
    v_new.motivo := coalesce(fn_banco_limpio(p_motivo), case when v_old.activa then v_old.motivo end);
  else
    if v_old.ultimos4 is null then
      raise exception using errcode = '22023', message = format('····%s no está dada de alta como cuenta personal.', v_u4);
    end if;
    if fn_banco_limpio(p_motivo) is null then
      raise exception using errcode = 'MX008',
        message = 'Una cuenta personal se da de baja con su motivo escrito (la cerró, no era suya…): queda en el rastro.';
    end if;
    v_new := v_old;
    v_new.nombre := coalesce(fn_banco_limpio(p_nombre), v_old.nombre);
    v_new.activa := false;
    v_new.motivo := fn_banco_limpio(p_motivo);
  end if;
  perform fn_banco_marca('personal:' || v_u4);
  if v_old.ultimos4 is null then
    insert into banco_cuentas_personales (ultimos4, nombre, activa, motivo)
    values (v_new.ultimos4, v_new.nombre, v_new.activa, v_new.motivo)
    returning * into v_new;
  elsif (v_new.nombre, v_new.activa, v_new.motivo) is distinct from (v_old.nombre, v_old.activa, v_old.motivo) then
    update banco_cuentas_personales set nombre = v_new.nombre, activa = v_new.activa, motivo = v_new.motivo
     where ultimos4 = v_u4
    returning * into v_new;
  else
    v_new := v_old;
  end if;
  perform fn_banco_marca(null);
  -- (Ronda 4c) Y LAS PROPUESTAS QUE LA NOMBRAN SE REHACEN YA, sin esperar al
  -- siguiente «Casar»: lo pendiente desde el corte cuya descripción o nota
  -- nombra esos 4 últimos. Antes, dada de baja, la bandeja seguía
  -- enseñando sus botones viejos al patrimonio sin motivo (pulsados daban
  -- MX008: el principio se mira en vivo) hasta el siguiente «Casar».
  if v_new is distinct from v_old then
    for v_id in select x.id from movimientos_banco x
                 where x.estado = 'pendiente' and x.fecha >= fn_puente_corte()
                   and (x.desc_norm ~ ('(^| )X*' || v_u4 || '( |$)')
                        or fn_banco_norm(x.memo) ~ ('(^| )X*' || v_u4 || '( |$)'))
                 order by x.fecha, x.id loop
      perform fn_banco_casar_interno(null, null, v_id, true);
      v_n := v_n + 1;
    end loop;
  end if;
  return to_jsonb(v_new) - 'creado_por' - 'cambiado_por'
         || jsonb_build_object('rehechas', v_n,
                               'aviso', case when v_n > 0
                                             then format('Rehecha la propuesta de %s movimiento(s) pendiente(s) que la nombran.', v_n)
                                             else 'Ningún movimiento pendiente la nombra: las propuestas de lo que llegue ya la verán.' end);
end $$;
revoke execute on function public.fn_banco_cuenta_personal(text, text, boolean, text) from public, anon, authenticated, service_role;
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
-- Y (ronda 4) vale EL CASADO DE ESA FECHA: si el de hoy entró después del
-- corte (todas sus líneas) y sustituye a uno cuyo asiento seguía vivo al
-- corte (su reverso es de después: el mes ya estaba cerrado), al corte
-- casaba con ese. Es la clasificación de octubre cambiada por su ticket
-- con octubre cerrado: no es un cargo en circulación ni algo «en libros
-- después», y octubre no cambia (no hay que reabrirlo).
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
  -- (Ronda 4) EL CASADO QUE VALÍA AL CORTE: el vivo, salvo que ninguna de
  -- sus líneas esté en el libro a esa fecha y uno deshecho del mismo
  -- movimiento tenga su asiento vivo al corte (de C o antes, con su reverso
  -- DESPUÉS): el cargo clasificado en octubre cuyo ticket llegó con octubre
  -- cerrado (la clasificación se reversa el 1-nov y el ticket entra el
  -- 1-nov, tardío). Al corte el cargo casaba con la clasificación y el
  -- cambio es de noviembre. Antes, la conciliación de octubre, rehecha,
  -- sacaba la clasificación como «cargo en circulación» (que nunca circuló)
  -- y el cargo como «en libros después», y para cambiarlo había que
  -- reabrirla.
  ant as materialized (
    select distinct on (m.id) m.id as mov, bc0.id as casado
      from movimientos_banco m
      cross join k
      join banco_casados bc0 on bc0.movimiento_id = m.id and bc0.deshecho_el is not null and bc0.reverso_id is not null
      join asientos a0 on a0.id = bc0.asiento_id
      join asientos r0 on r0.id = bc0.reverso_id
     where m.cuenta = p_cuenta and m.fecha between k.corte0 and p_corte and m.estado in ('casado', 'en_transito')
       and m.casado_clase is distinct from 'apertura'
       and a0.fecha_contable between k.corte0 and p_corte and r0.fecha_contable > p_corte
       -- (el vivo tiene sus líneas, y todas son de después del corte)
       and exists (select 1 from banco_casado_lineas bl where bl.casado_id = m.casado_id and bl.vigente)
       and not exists (select 1 from banco_casado_lineas bl join asientos a on a.id = bl.asiento_id
                        where bl.casado_id = m.casado_id and bl.vigente and a.fecha_contable <= p_corte)
     order by m.id, bc0.deshecho_el desc),
  -- Lo casado a esa fecha: las claves de las líneas de cada casado vivo de
  -- un movimiento de la cuenta de C o antes (o del que valía al corte).
  mc as (
    select m.id as mov, m.fecha, fn_banco_clave(a.origen_tabla, a.origen_id, a.id, bl.orden, bl.cuenta, bl.monto) as clave
      from movimientos_banco m
      join banco_casados bc on bc.id = m.casado_id and bc.deshecho_el is null
      join banco_casado_lineas bl on bl.casado_id = bc.id and bl.vigente
      join asientos a on a.id = bl.asiento_id
      cross join k
     where m.cuenta = p_cuenta and m.fecha between k.corte0 and p_corte
       and not exists (select 1 from ant where ant.mov = m.id)
    union all
    select m.id, m.fecha, fn_banco_clave(a.origen_tabla, a.origen_id, a.id, bl.orden, bl.cuenta, bl.monto)
      from ant
      join movimientos_banco m on m.id = ant.mov
      join banco_casado_lineas bl on bl.casado_id = ant.casado
      join asientos a on a.id = bl.asiento_id),
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
                  substring(regexp_replace(sb.desc_norm, '(^| )(TO|FROM) (CHK|CK) ', ' ', 'g') from '(?:^| )(?:CHECK|CHK|CHEQUE|CK)(?: NO)? ?#? ?0*([1-9][0-9]{0,9})(?: |$)')),
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

-- (Ronda 4) LO QUE LA APERTURA PUSO EN UNA CUENTA, fila por fila de su
-- balanza de QuickBooks: cada cuenta de QuickBooks mapeada a ella
-- (apertura_mapeo_qb, tipo 'cuenta') en la balanza con que fn_apertura
-- posteó la apertura viva, con su saldo (debe − haber, el signo del
-- libro). En un banco casi siempre es una sola, su registro («Chase Chk
-- 4392»); pero c4 manda mapear al banco también los Undeposited Funds (los
-- cobros que QuickBooks tenía recibidos y sin depositar al 30-sep: un
-- depósito en tránsito), y la conciliación de QuickBooks del banco no los
-- trae, porque allí son otra cuenta. La conciliación de apertura no
-- cuadraba por ellos y decía «un archivo que falta, un saldo mal escrito,
-- un ignorado»: ninguna de las tres. uf: el nombre dice que lo son
-- (Undeposited Funds; en QuickBooks Online, «Payments to deposit»). Lo lee
-- fn_conciliacion_recalcular para decir qué falta.
create or replace function public.fn_banco_apertura_filas(p_cuenta text)
returns table (cuenta_qb text, saldo numeric, uf boolean)
language sql
stable
set search_path = public, pg_temp
as $$
  with ap as (
    select a.documento_ruta as doc
      from asientos a
     where a.tipo = 'apertura' and a.origen_tabla = 'apertura_balanza_qb'
       and coalesce(a.procedencia->>'funcion', '') = 'fn_apertura'
       and a.camino not in ('reverso', 'reverso_automatico')
       and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
     order by a.cadena_pos desc
     limit 1)
  select min(b.cuenta_qb), sum(coalesce(b.debe, 0) - coalesce(b.haber, 0))::numeric(14,2),
         bool_or(b.clave ~ '(undeposited|payments to deposit|pagos por depositar|fondos sin depositar|sin depositar)')
    from ap
    join apertura_balanza_qb b on b.documento = ap.doc and b.control is null
    join apertura_mapeo_qb m on m.tipo = 'cuenta' and m.clave = b.clave and m.cuenta = p_cuenta
   group by b.clave
  having sum(coalesce(b.debe, 0) - coalesce(b.haber, 0)) <> 0
$$;
revoke execute on function public.fn_banco_apertura_filas(text) from public, anon, authenticated, service_role;

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
  v_nsal   int := 0;
  v_saltxt text;
  v_contra boolean := false;
  v_lotes  text;
  v_apdif  text;
  v_nbdj   int := 0;
  v_bdjtxt text;
  v_apest  text;
  v_apfal  text;
  v_apsin  text;
  v_ncri   int := 0;
  v_critxt text;
begin
  select * into c from conciliaciones where id = p_conciliacion for update;
  v_tipo := fn_banco_tipo_cuenta(c.cuenta);
  v_libros := fn_banco_saldo_libros(c.cuenta, c.fecha_corte);
  -- El archivo con el saldo a esa misma fecha. (Ronda 4) El del estado de
  -- cuenta del BANCO (un OFX, su LEDGERBAL) si lo hay, el último que entró;
  -- si no, el último lote (Plaid, CSV o a mano). Un lote lo arma conta.js o
  -- lo escribe Edgar: frente a un OFX del mismo día no es «lo que dice el
  -- banco». Antes valía el último archivo, fuera el que fuera: un «lote a
  -- mano» de cero filas con el saldo tecleado se volvía «el archivo del
  -- banco» y la conciliación se confirmaba contra un saldo que el QFX
  -- desmentía, sin motivo ni documento.
  select * into v_arch from archivos_banco a
   where a.cuenta = c.cuenta and a.saldo_al = c.fecha_corte and a.saldo is not null and a.retirado_el is null
   order by (a.formato in ('ofx_sgml', 'ofx_xml')) desc, a.importado_el desc limit 1;
  -- Los de su mismo nivel ese día (los OFX si hay; si no, los lotes), como
  -- los dice el statement (en una tarjeta, lo que se debe): ¿dicen lo mismo
  -- entre sí, y lo mismo que el saldo escrito? (Un QFX retocado a mano,
  -- subido junto al de verdad, sale aquí.)
  select count(distinct a.saldo),
         string_agg(format('«%s» dice %s', coalesce(a.nombre, a.id::text), case when v_tipo = 'tarjeta' then -a.saldo else a.saldo end),
                    '; ' order by a.importado_el),
         coalesce(bool_or(c.saldo_statement is not null
                          and c.saldo_statement <> (case when v_tipo = 'tarjeta' then -a.saldo else a.saldo end)), false)
    into v_nsal, v_saltxt, v_contra
    from archivos_banco a
   where a.cuenta = c.cuenta and a.saldo_al = c.fecha_corte and a.saldo is not null and a.retirado_el is null
     and (a.formato in ('ofx_sgml', 'ofx_xml')) = (v_arch.formato in ('ofx_sgml', 'ofx_xml'));
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
  -- y los controles seguían en verde. (Ronda 4: contra TODOS los archivos
  -- de su nivel ese día, no solo el último; y si esos archivos no dicen lo
  -- mismo entre sí, también pide su motivo y su documento, haya o no saldo
  -- escrito.)
  if v_arch.id is not null and (v_contra or v_nsal > 1) then
    v_sdif := nullif(btrim(coalesce(c.saldo_motivo, '')), '') is null or nullif(btrim(coalesce(c.saldo_documento, '')), '') is null;
    v_avisos := v_avisos || to_jsonb(
      case when v_nsal > 1
           then format('Los archivos del banco al %s no dicen lo mismo: %s. %s', c.fecha_corte, v_saltxt,
                       case when v_sdif
                            then 'Retira el que no es (fn_banco_archivo_retirar, desde el SQL Editor), o escribe el saldo del statement '
                                 '(fn_conciliar) y di por qué vale y con qué documento (fn_conciliacion_saldo): sin eso no se confirma.'
                            else format('Vale el que escribiste, %s: %s (%s).', c.saldo_statement, c.saldo_motivo, c.saldo_documento) end)
           else format('El statement dice %s y el archivo del banco al mismo día dice otra cosa (%s): no dicen lo mismo. %s',
                       c.saldo_statement, v_saltxt,
                       case when v_sdif
                            then 'Si te equivocaste al escribirlo, escríbelo otra vez; si vale el del statement, dile por qué y con qué '
                                 'documento (fn_conciliacion_saldo, desde el SQL Editor): sin eso no se confirma.'
                            else format('Vale el que escribiste: %s (%s).', c.saldo_motivo, c.saldo_documento) end) end);
  end if;
  -- (y el lote que, frente al OFX de ese día, dice otro saldo: no cuenta
  -- para el cruce —vale el del banco—, pero se dice)
  if v_arch.formato in ('ofx_sgml', 'ofx_xml') then
    select string_agg(format('«%s» (%s) dice %s', coalesce(a.nombre, a.id::text), a.formato,
                             case when v_tipo = 'tarjeta' then -a.saldo else a.saldo end), '; ' order by a.importado_el)
      into v_lotes
      from archivos_banco a
     where a.cuenta = c.cuenta and a.saldo_al = c.fecha_corte and a.saldo is not null and a.retirado_el is null
       and a.formato not in ('ofx_sgml', 'ofx_xml') and a.saldo <> v_arch.saldo;
    if v_lotes is not null then
      v_avisos := v_avisos || to_jsonb(format('Al %s, %s; vale el del estado de cuenta del banco (%s, %s): un lote no es lo que dice el '
                                              'banco.', c.fecha_corte, v_lotes, coalesce(v_arch.nombre, 'el OFX'),
                                              case when v_tipo = 'tarjeta' then -v_arch.saldo else v_arch.saldo end));
    end if;
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
    -- (ronda 4d: en un orden fijo —el texto—, como el de las del mes: antes
    -- salían en el orden en que las leía la consulta y «falta» cambiaba de
    -- una vez a otra sin que nada cambiara)
    select count(*), string_agg(x.texto, '; ' order by x.texto, x.partida, x.movimiento) into v_ndap, v_aptxt
      from fn_banco_apertura_casadas(c.cuenta, c.id) x;
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
  -- (Ronda 4d) EL CONTROL: lo casado de su tramo (desde el corte de la
  -- última confirmada de la cuenta, o desde el corte de la apertura) cuyo
  -- lado del banco y cuyo lado del libro se contradicen sin su motivo
  -- escrito (fn_banco_criterio_casados; fn_banco_control lo pone en rojo):
  -- no se confirma con eso dentro. Se des-casa (con su motivo) o, si es
  -- correcto, se escribe su motivo (fn_banco_casar_con con {"casado": …}).
  if c.tipo = 'normal' then
    select count(*),
           string_agg(format('el del %s por %s «%s» (movimiento %s, casado %s): %s', x.fecha, x.monto, coalesce(x.descripcion, ''),
                             x.movimiento_id, x.casado_id, x.contradice), '; ' order by x.fecha, x.movimiento_id)
      into v_ncri, v_critxt
      from fn_banco_criterio_casados(c.cuenta,
                                     coalesce((select max(cc.fecha_corte) + 1 from conciliaciones cc
                                                where cc.cuenta = c.cuenta and cc.tipo = 'normal' and cc.estado = 'confirmada'
                                                  and cc.fecha_corte < c.fecha_corte), fn_puente_corte()),
                                     c.fecha_corte) x;
  end if;
  v_npm := (case when v_sdif then 1 else 0 end) + v_npa + v_npt + v_ncri;
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
  -- (Ronda 4: y lo pendiente cuyo ticket YA está subido y espera en la
  -- bandeja de los puentes de c3 —sin obra, con su regla en borrador, sin
  -- los 4 últimos…—: no se clasifica, se resuelve allí y casa solo. Antes
  -- decía «cásalos o clasifícalos», y clasificarlo metía el gasto dos veces
  -- en cuanto el ticket entraba.)
  select count(*),
         string_agg(format('el cargo del %s por %s (%s)', mm.fecha, mm.monto,
                           (select string_agg(format('el recibo %s, %s', t->>'recibo', coalesce(t->>'codigo', t->>'estado')), '; '
                                              order by t->>'recibo')
                              from jsonb_array_elements(case when jsonb_typeof(mm.propuesta->'tickets_bandeja') = 'array'
                                                             then mm.propuesta->'tickets_bandeja' else '[]'::jsonb end) t)),
                    '; ' order by mm.fecha, mm.id)
    into v_nbdj, v_bdjtxt
    from conciliacion_partidas p
    join movimientos_banco mm on mm.id = p.movimiento_id and mm.estado = 'pendiente'
                             and mm.propuesta->>'motivo' = 'ticket_en_bandeja'
   where p.conciliacion_id = c.id and p.lado = 'banco' and p.clase = 'sin_casar';
  v_sarch := case when v_arch.id is null then null when v_tipo = 'tarjeta' then -v_arch.saldo else v_arch.saldo end;
  -- (Ronda 4) LA DIFERENCIA DE LA CONCILIACIÓN DE APERTURA, en palabras de
  -- la apertura (aquí no hay archivos del banco ni ignorados que la
  -- expliquen). Si la apertura puso en esta cuenta más de una cuenta de
  -- QuickBooks (fn_banco_apertura_filas) y una de ellas es el registro que
  -- concilió QuickBooks (su saldo es el del statement más lo que está en
  -- tránsito), las otras son justo la diferencia: se nombran, y si son los
  -- Undeposited Funds, se dice que son depósitos en tránsito, uno por
  -- depósito, que casan solos con su depósito de octubre. Antes decía «algo
  -- del banco no está (un archivo que falta, un saldo mal escrito, un
  -- ignorado que mueve dinero)» y Edgar se quedaba parado en el primer
  -- paso del banco sin una pista.
  if c.tipo = 'apertura' and coalesce(v_dif, 0) <> 0 then
    with f as (select * from fn_banco_apertura_filas(c.cuenta)),
         reg as (select f.* from f where f.saldo = v_libros - v_dif order by f.uf, f.cuenta_qb limit 1),
         otras as (select f.* from f where not exists (select 1 from reg where reg.cuenta_qb = f.cuenta_qb))
    select case
             when (select count(*) from reg) = 1 and exists (select 1 from otras)
             then format('la diferencia es %s, y es justo lo que la apertura puso en %s además del registro del banco en QuickBooks '
                         '(«%s», %s): %s. %s', v_dif, c.cuenta, (select reg.cuenta_qb from reg), (select reg.saldo from reg),
                         (select string_agg(format('«%s» por %s', o.cuenta_qb, o.saldo), ', ' order by o.cuenta_qb) from otras o),
                         case when (select bool_or(o.uf) from otras o)
                              then 'Los Undeposited Funds son cobros que QuickBooks tenía recibidos y sin depositar al 30-sep: la '
                                   'conciliación de QuickBooks del banco no los trae (allí son otra cuenta). Son depósitos en tránsito: '
                                   'añádelos a las partidas de fn_conciliacion_apertura, uno por depósito, con su fecha y su monto (su '
                                   'lista en QuickBooks al 30-sep), y en octubre casan solos con su depósito. Si alguno no se va a '
                                   'depositar nunca (un saldo viejo de QuickBooks), es un error de la apertura: su partida va con '
                                   'clase «error» y su motivo, y se corrige con un ajuste a la apertura'
                              else 'Esa cuenta de QuickBooks no es el registro del banco: si es dinero en camino a este banco, son '
                                   'partidas en tránsito (una por movimiento, con su fecha y su monto); si no es de este banco, su '
                                   'mapeo está mal (fn_apertura_mapeo_qb, y fn_apertura con su motivo, c4)' end)
             when exists (select 1 from f where f.uf)
             then format('la diferencia es %s. La apertura puso en %s también %s: los cobros que QuickBooks tenía recibidos y sin '
                         'depositar al 30-sep, que su conciliación del banco no trae. Si no están en las partidas, añádelos como '
                         'depósitos en tránsito, uno por depósito con su fecha y su monto; y revisa el saldo del statement y las '
                         'demás partidas', v_dif, c.cuenta,
                         (select string_agg(format('«%s» por %s', x.cuenta_qb, x.saldo), ', ' order by x.cuenta_qb) from f x where x.uf))
             else format('la diferencia es %s: el saldo del statement, las partidas en tránsito y lo que la apertura trae en %s (%s%s) '
                         'no dicen lo mismo. Revisa el saldo del statement al 30-sep o antes (en una tarjeta, el de su último corte), '
                         'que estén todas las partidas de la conciliación de QuickBooks de esa fecha (cheques y cargos sin cobrar, en '
                         'negativo; depósitos sin acreditar, en positivo) y lo que QuickBooks tenía en esa cuenta', v_dif, c.cuenta,
                         v_libros,
                         coalesce(': ' || (select string_agg(format('«%s» por %s', x.cuenta_qb, x.saldo), ', ' order by x.cuenta_qb)
                                             from f x), '')) end
      into v_apdif;
  end if;
  -- (Ronda 4b) LA DIFERENCIA DE UN MES SIN LA CONCILIACIÓN DE APERTURA
  -- CONFIRMADA: lo que QuickBooks tenía en tránsito al 30-sep (los cheques
  -- sin cobrar, los depósitos sin acreditar) entra en las del mes solo desde
  -- la de apertura confirmada; sin ella, es justo la diferencia. Se dice eso
  -- —cuál falta y qué le falta— antes que «algo del banco no está». Antes
  -- octubre decía «la diferencia es 1950.00: algo del banco no está (un
  -- archivo que falta…)» y Edgar buscaba en el banco lo que era de la
  -- apertura.
  if c.tipo = 'normal' and coalesce(v_dif, 0) <> 0 then
    v_apest := fn_banco_apertura_estado(c.cuenta);
    if v_apest = 'sin_conciliar' then
      select nullif(btrim(coalesce(a.falta, '')), '') into v_apfal
        from conciliaciones a
       where a.cuenta = c.cuenta and a.tipo = 'apertura' and a.estado = 'abierta'
       order by a.calculada_el desc nulls last
       limit 1;
      v_apsin := case when found
                      then format('la diferencia es %s, y la conciliación de apertura de %s (lo que QuickBooks tenía en tránsito al 30-sep) '
                                  'no está confirmada: sin ella, sus cheques y depósitos en tránsito no entran en esta. Confírmala '
                                  'antes (fn_conciliacion_confirmar)%s; después, si sigue la diferencia, algo del banco no está (un '
                                  'archivo que falta, un saldo mal escrito, un ignorado que mueve dinero)', v_dif, c.cuenta,
                                  coalesce('; le falta: ' || v_apfal, ''))
                      else format('la diferencia es %s, y falta la conciliación de apertura de %s (lo que QuickBooks tenía en tránsito '
                                  'al 30-sep: los cheques sin cobrar y los depósitos sin acreditar): sin ella, no entran en esta. Hazla '
                                  '(fn_conciliacion_apertura, con el saldo del statement al 30-sep y sus partidas en tránsito) y '
                                  'confírmala; después, si sigue la diferencia, algo del banco no está (un archivo que falta, un saldo '
                                  'mal escrito, un ignorado que mueve dinero)', v_dif, c.cuenta) end;
    elsif v_apest = 'sin_apertura' then
      v_apsin := format('la diferencia es %s, y falta la apertura (el saldo de QuickBooks al 30-sep: fn_apertura, c4) y la conciliación '
                        'de apertura de %s: sin ellas, el libro no tiene el saldo con que empezó la cuenta. Postéala y concíliala '
                        '(fn_conciliacion_apertura) antes; después, si sigue la diferencia, algo del banco no está (un archivo que '
                        'falta, un saldo mal escrito, un ignorado que mueve dinero)', v_dif, c.cuenta);
    end if;
  end if;
  -- LO QUE FALTA para confirmarla, en palabras (y guardado: v_conciliacion
  -- lo enseña, ronda 4).
  v_falta := case when v_banco is null then 'el saldo del statement (fn_conciliar con p_saldo_statement)'
                  when v_nsb > 0 and v_nnom = v_nsb
                  then format('%s débito(s) de nómina sin su journal: espera el journal de nómina (f11) o, si es del proveedor '
                              'anterior, regístralo desde el SQL Editor con fn_banco_nomina (no se clasifica a mano)', v_nsb)
                  when v_nsb > 0
                  then concat_ws('; ',
                         case when v_nsb - v_ncas > 0
                              then format('%s movimiento(s) del banco sin su línea en el libro: cásalos o clasifícalos%s%s%s',
                                          v_nsb - v_ncas,
                                          case when v_nnom > 0
                                               then format(' (%s de nómina: su journal, f11 o fn_banco_nomina)', v_nnom)
                                               else '' end,
                                          case when v_nblq > 0
                                               then format(' (%s espera que reabras otra conciliación antes: lo dice su propuesta)',
                                                           v_nblq)
                                               else '' end,
                                          -- (ronda 4: el ticket ya subido que espera en la
                                          -- bandeja de los puentes)
                                          case when v_nbdj > 0
                                               then format(' (%s con su ticket YA subido, que espera en la bandeja de los puentes: %s. '
                                                           'Resuélvelo allí —lo que dice su motivo— y casa solo; clasificarlo metería el '
                                                           'gasto dos veces)', v_nbdj, v_bdjtxt)
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
                  -- (ronda 4: la de apertura, en palabras de la apertura; ver arriba)
                  when v_dif <> 0 and c.tipo = 'apertura' and v_apdif is not null then v_apdif
                  -- (ronda 4b: la de un mes sin la de apertura confirmada; ver arriba)
                  when v_dif <> 0 and v_apsin is not null then v_apsin
                  when v_dif <> 0 then format('la diferencia es %s: algo del banco no está (un archivo que falta, un saldo '
                                              'mal escrito, un ignorado que mueve dinero)', v_dif)
                  when coalesce(v_npm, 0) > 0
                  then concat_ws('; ',
                         case when v_sdif and v_nsal > 1
                              then format('los archivos del banco al %s no dicen lo mismo (%s): retira el que no es '
                                          '(fn_banco_archivo_retirar, desde el SQL Editor), o escribe el saldo del statement y di por qué '
                                          'vale y con qué documento (fn_conciliacion_saldo, desde el SQL Editor)', c.fecha_corte, v_saltxt)
                              when v_sdif then format('el saldo escrito (%s) no es el del archivo del banco a esa fecha (%s): '
                                                      'escríbelo otra vez, o di por qué vale y con qué documento '
                                                      '(fn_conciliacion_saldo, desde el SQL Editor)', c.saldo_statement,
                                                      v_saltxt) end,
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
                                          v_npt) end,
                         -- (ronda 4d: EL CONTROL)
                         case when v_ncri > 0
                              then format('%s movimiento(s) casado(s) donde lo que dice el banco del otro lado y lo que dice el libro '
                                          'se contradicen, sin su motivo escrito: %s. Si está mal casado, des-cásalo '
                                          '(fn_banco_descasar, con su motivo) y cásalo con lo que es; si es correcto, escribe su '
                                          'motivo: select fn_banco_casar_con(''<movimiento>'', ''{"casado": "<su casado>"}'', '
                                          '''<por qué es correcto>'')', v_ncri, v_critxt) end) end;
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
    -- (ronda 4: si los archivos del banco de ese día no dicen lo mismo, el
    -- motivo va con el saldo que vale, escrito)
    raise exception using errcode = 'MX008',
      message = 'Esa conciliación no tiene un saldo escrito: vale el del archivo del banco, y no hace falta motivo. Si los archivos del '
                'banco de ese día no dicen lo mismo, escribe primero el saldo del statement (fn_conciliar con p_saldo_statement) y '
                'después su motivo y su documento.';
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
    -- (ronda 4c: «Lo que falta: …», que se lee con cualquier «falta» —«la
    -- diferencia es 1950.00…», «2 movimiento(s)…»—; antes «falta la
    -- diferencia es…»)
    raise exception using errcode = 'MX008',
      message = format('La conciliación de %s al %s no se confirma todavía. Lo que falta: %s.', c.cuenta, c.fecha_corte,
                       v_res->>'falta');
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
-- LOS UNDEPOSITED FUNDS (ronda 4): c4 manda mapearlos al banco donde se
-- depositan (1010), y la apertura los suma al saldo de 1010; la conciliación
-- de QuickBooks del banco no los trae (allí son otra cuenta). Van también
-- como depósitos en tránsito, uno por depósito con su fecha y su monto (la
-- lista de QuickBooks al 30-sep), y en octubre casan solos con su
-- depósito. Si faltan, la diferencia es justo su saldo y «falta» lo dice,
-- con su nombre (fn_banco_apertura_filas): ya no manda a buscar un archivo
-- que falta o un saldo mal escrito.
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

-- (Ronda 5) EL PERÍODO de un préstamo, en palabras, por sus cuotas al año:
-- p_forma 'nombre' («mes», «semana», «quincena»…), 'otro' («otro mes», «otra
-- semana»…) o 'del' («del mes», «de la semana»…). Para los textos de la
-- fórmula y de la bandeja.
create or replace function public.fn_prestamo_periodo(p_cuotas int, p_forma text default 'nombre')
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case p_forma
           when 'otro' then case p_cuotas when 52 then 'otra semana' when 26 then 'otra quincena' when 24 then 'otro medio mes'
                                          when 6 then 'otro bimestre' when 4 then 'otro trimestre' when 2 then 'otro semestre'
                                          when 1 then 'otro año' else 'otro mes' end
           when 'del'  then case p_cuotas when 52 then 'de la semana' when 26 then 'de la quincena' when 24 then 'del medio mes'
                                          when 6 then 'del bimestre' when 4 then 'del trimestre' when 2 then 'del semestre'
                                          when 1 then 'del año' else 'del mes' end
           else case p_cuotas when 52 then 'semana' when 26 then 'quincena' when 24 then 'medio mes' when 6 then 'bimestre'
                              when 4 then 'trimestre' when 2 then 'semestre' when 1 then 'año' else 'mes' end
         end
$$;
revoke execute on function public.fn_prestamo_periodo(int, text) from public, anon, authenticated, service_role;

-- La partición que da la FÓRMULA para un pago de p_monto en p_fecha: el
-- interés del PERÍODO sobre lo que se debe (round(saldo × tasa / 100 /
-- cuotas_al_anio, 2): por mes en una mensual, por semana en una semanal;
-- ronda 5) y el resto a capital. Si el pago no alcanza el interés, todo es
-- interés (y se dice); si el capital pasa de lo que se debe, no cuadra:
-- manda el statement. La fórmula es la de LA CUOTA DEL PERÍODO: un pago que
-- no es la cuota (otro monto, o a menos de un período de la cuota anterior
-- —25 días en una mensual, 5 en una semanal—: un abono extra a capital, dos
-- cuotas juntas) no se parte por ella, que le cobraría otro período entero
-- de interés (154.51 sobre un abono de 5,000 cinco días después de la cuota
-- mensual): pide_statement, y manda el statement del prestamista
-- (p_capital y p_interes; un abono solo a capital, todo a capital).
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
  v_dias  int;
begin
  select * into p from prestamos where id = p_prestamo;
  if not found then
    return null;
  end if;
  v_saldo := fn_prestamo_saldo(p.id, p_fecha);
  v_int := round(v_saldo * p.tasa_anual / 100 / p.cuotas_al_anio, 2);
  v_cap := p_monto - v_int;
  select max(q.fecha) into v_ult from prestamo_cuotas q where q.prestamo_id = p.id and q.anulada_el is null and q.fecha <= p_fecha;
  -- (Ronda 4) Lo que la fórmula no sabe repartir: un pago a menos de un
  -- período de la cuota anterior (un abono aparte: la fórmula le cobraría
  -- otro período de interés), o MENOR que la cuota (cómo lo repartió el
  -- prestamista lo dice su statement). La cuota del período con un EXTRA en
  -- el mismo cargo (1,529.33 = 1,029.33 + 500.00), a un período o más de la
  -- anterior, sí va por la fórmula: el interés del período y el resto a
  -- capital, que es lo que hace el prestamista. Antes todo pago distinto
  -- de la cuota pedía el statement «porque le cobraría otro mes de
  -- interés», y la primera opción lo mandaba todo a capital, sin el
  -- interés del mes. (Ronda 5: el período son 25 días en una mensual y
  -- 25 × 12 / cuotas_al_anio en las demás: 5 en una semanal, 11 en una
  -- quincenal; antes la cuota semanal siguiente, a 7 días, pedía el
  -- statement.)
  v_dias := greatest(3, 25 * 12 / p.cuotas_al_anio);
  v_otro := case when v_ult is not null and p_fecha - v_ult < v_dias
                 then format('a %s días de la cuota del %s: la fórmula le cobraría %s de interés', p_fecha - v_ult, v_ult,
                             fn_prestamo_periodo(p.cuotas_al_anio, 'otro'))
                 when p_monto < p.cuota
                 then format('%s, menos que la cuota (%s): cómo lo repartió el prestamista lo dice su statement', p_monto, p.cuota) end;
  return jsonb_strip_nulls(jsonb_build_object(
    'saldo_antes', v_saldo, 'tasa_anual', p.tasa_anual, 'cuotas_al_anio', p.cuotas_al_anio,
    'interes', least(v_int, p_monto), 'capital', greatest(v_cap, 0),
    'saldo_despues', v_saldo - greatest(v_cap, 0),
    'formula', format('interés = round(%s × %s %% / %s, 2) = %s; capital = %s − %s = %s', v_saldo, p.tasa_anual, p.cuotas_al_anio,
                      v_int, p_monto, least(v_int, p_monto), greatest(v_cap, 0)),
    'extra', case when v_otro is null and p_monto > p.cuota then p_monto - p.cuota end,
    'aviso', case when v_otro is not null then v_otro
                  when v_cap < 0 then format('El pago no alcanza el interés %s: todo va a interés. Mira el statement.',
                                             fn_prestamo_periodo(p.cuotas_al_anio, 'del'))
                  when v_cap > v_saldo then format('El capital (%s) pasa de lo que se debe (%s): no cuadra; usa el statement.',
                                                   v_cap, v_saldo)
                  when p_monto > p.cuota
                  then format('la cuota %s (%s) más %s a capital', fn_prestamo_periodo(p.cuotas_al_anio, 'del'), p.cuota,
                              p_monto - p.cuota) end,
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
-- (1010) tienen esos valores si no se dicen. (Ronda 5) «frecuencia»: cada
-- cuánto se paga la cuota —mensual (lo de siempre, si no se dice), semanal,
-- quincenal (o «cada dos semanas»), dos al mes, bimestral, trimestral,
-- semestral, anual—, o cuotas_al_anio en número (12, 52, 26, 24, 6, 4, 2,
-- 1); un préstamo de negocio que se paga cada semana va con "frecuencia":
-- "semanal" y sus cuentas 2540/2550. saldo_inicial: lo que se
-- debía al empezar el libro (el statement al 30-sep, que la apertura ya
-- trae en 2520/2530); en un préstamo nuevo, el principal (y el depósito
-- del préstamo se clasifica a 2520/2530). (Ronda 4) Si la apertura
-- (QuickBooks) no trae en esas cuentas lo mismo que suman los préstamos de
-- antes del corte, lo dice en «aviso», con los caminos: faltan préstamos
-- por registrar, o QuickBooks no tenía el saldo del prestamista y se
-- corrige la apertura (no el saldo_inicial). Con cuotas ya registradas, lo
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
  v_si    numeric;
  v_apl   numeric;
  v_ctas  text;
  v_aviso text;
begin
  perform fn_banco_exigir_dueno();
  if p_prestamo is null or jsonb_typeof(p_prestamo) <> 'object' then
    raise exception using errcode = '22023', message = 'El préstamo va como objeto JSON.';
  end if;
  select string_agg(k, ', ' order by k) into v_sobra from jsonb_object_keys(p_prestamo) k
   where k not in ('id', 'prestamista', 'descripcion', 'principal', 'tasa_anual', 'cuota', 'primer_pago', 'dia_pago',
                   'plazo_meses', 'cuenta', 'cuenta_largo', 'cuenta_interes', 'cuenta_banco', 'saldo_inicial',
                   'saldo_inicial_al', 'descriptor', 'estado', 'notas', 'frecuencia', 'cuotas_al_anio');
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
    v_new.cuotas_al_anio := 12;
  end if;
  -- (Ronda 5) Cuántas cuotas tiene el año: «frecuencia» en palabras o
  -- cuotas_al_anio en número; las de antes y lo que no lo diga, 12. Se
  -- puede cambiar con cuotas registradas (no mueve el saldo: solo las
  -- cuotas que vengan y la porción corriente).
  v_t := lower(fn_banco_limpio(p_prestamo->>'frecuencia'));
  if v_t is not null then
    v_new.cuotas_al_anio := case v_t when 'mensual' then 12 when 'semanal' then 52 when 'quincenal' then 26
                                     when 'cada dos semanas' then 26 when 'dos al mes' then 24 when 'bimestral' then 6
                                     when 'trimestral' then 4 when 'semestral' then 2 when 'anual' then 1 end;
    if v_new.cuotas_al_anio is null then
      raise exception using errcode = '22023',
        message = format('frecuencia es cada cuánto se paga la cuota: mensual, semanal, quincenal (o «cada dos semanas»), dos al mes, '
                         'bimestral, trimestral, semestral o anual; llegó «%s». (O cuotas_al_anio en número: 12, 52, 26, 24, 6, 4, 2 '
                         'o 1.)', p_prestamo->>'frecuencia');
    end if;
  end if;
  v_t := fn_banco_limpio(p_prestamo->>'cuotas_al_anio');
  if v_t is not null then
    if v_t !~ '^[0-9]{1,2}$' or v_t::int not in (1, 2, 4, 6, 12, 24, 26, 52) then
      raise exception using errcode = '22023',
        message = format('cuotas_al_anio es cuántas cuotas tiene el año: 12 (mensual), 52 (semanal), 26 (quincenal), 24 (dos al mes), '
                         '6, 4, 2 o 1; llegó «%s».', v_t);
    end if;
    if fn_banco_limpio(p_prestamo->>'frecuencia') is not null and v_new.cuotas_al_anio <> v_t::int then
      raise exception using errcode = '22023',
        message = format('frecuencia («%s») y cuotas_al_anio (%s) no dicen lo mismo: di una de las dos.', p_prestamo->>'frecuencia', v_t);
    end if;
    v_new.cuotas_al_anio := v_t::int;
  end if;
  v_new.cuotas_al_anio := coalesce(v_new.cuotas_al_anio, 12);
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
  -- (Ronda 4b: no el préstamo del accionista, 2900. Su cuota se propone y se
  -- registra con un botón; el dinero del banco que va al patrimonio del
  -- accionista no entra sin su motivo escrito, salvo a una cuenta personal
  -- de Edgar dada de alta: lo que la empresa le devuelve es eso.)
  if fn_banco_es_accionista(v_new.cuenta) or (v_new.cuenta_largo is not null and fn_banco_es_accionista(v_new.cuenta_largo)) then
    raise exception using errcode = 'MX004',
      message = 'El préstamo del accionista (2900) no es un préstamo de un prestamista: lo que la empresa le devuelve a Edgar sale a su '
                'cuenta personal (dada de alta con fn_banco_cuenta_personal) o se clasifica con su motivo escrito.';
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
                           cuenta_largo, cuenta_interes, cuenta_banco, saldo_inicial, saldo_inicial_al, descriptor, estado, notas,
                           cuotas_al_anio)
    values (v_new.id, v_new.prestamista, v_new.descripcion, v_new.principal, v_new.tasa_anual, v_new.cuota, v_new.primer_pago,
            v_new.dia_pago, v_new.plazo_meses, v_new.cuenta, v_new.cuenta_largo, v_new.cuenta_interes, v_new.cuenta_banco,
            v_new.saldo_inicial, v_new.saldo_inicial_al, v_new.descriptor, v_new.estado, v_new.notas, v_new.cuotas_al_anio)
    returning * into v_new;
  else
    update prestamos
       set prestamista = v_new.prestamista, descripcion = v_new.descripcion, principal = v_new.principal,
           tasa_anual = v_new.tasa_anual, cuota = v_new.cuota, primer_pago = v_new.primer_pago, dia_pago = v_new.dia_pago,
           plazo_meses = v_new.plazo_meses, cuenta = v_new.cuenta, cuenta_largo = v_new.cuenta_largo,
           cuenta_interes = v_new.cuenta_interes, cuenta_banco = v_new.cuenta_banco, saldo_inicial = v_new.saldo_inicial,
           saldo_inicial_al = v_new.saldo_inicial_al, descriptor = v_new.descriptor, estado = v_new.estado, notas = v_new.notas,
           cuotas_al_anio = v_new.cuotas_al_anio
     where id = v_new.id
    returning * into v_new;
  end if;
  perform fn_banco_marca(null);
  -- (Ronda 4) UN PRÉSTAMO DE ANTES DEL CORTE: su saldo_inicial es el del
  -- statement del prestamista al 30-sep, y la apertura (QuickBooks) trae lo
  -- suyo en las mismas cuentas. Si no dicen lo mismo se avisa ya, con los
  -- caminos (el cuadre de préstamos lo dirá en rojo): faltan préstamos por
  -- registrar, o QuickBooks no tenía el saldo del prestamista (parte las
  -- cuotas con su propia tabla) y se corrige la apertura. Antes nada lo
  -- decía y el control mandaba a «registrar un préstamo, su desembolso o una
  -- cuota»; lo fácil era poner aquí el número de QuickBooks, y el préstamo
  -- del libro ya no era el del prestamista.
  if v_new.saldo_inicial_al < fn_puente_corte() and v_new.estado <> 'cancelado' then
    select coalesce(sum(p.saldo_inicial), 0) into v_si
      from prestamos p where p.estado <> 'cancelado' and p.saldo_inicial_al < fn_puente_corte();
    select string_agg(distinct x.c, ', ') into v_ctas
      from prestamos p cross join lateral (values (p.cuenta), (p.cuenta_largo)) as x(c)
     where p.estado <> 'cancelado' and x.c is not null;
    if not exists (select 1 from asientos a
                    where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                      and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
      v_aviso := format('La apertura todavía no está en el libro: los préstamos de antes del corte (%s al %s) entran con ella (fn_apertura, '
                        'c4), y hasta entonces el cuadre de préstamos sale en rojo. Lo que la apertura traiga en %s tiene que ser esa '
                        'suma (el statement de cada prestamista).', v_si, fn_puente_corte() - 1, v_ctas);
    else
      select coalesce(-sum(l.monto), 0) into v_apl
        from asiento_lineas l join asientos a on a.id = l.asiento_id
       where l.cuenta in (select p.cuenta from prestamos p where p.estado <> 'cancelado'
                          union select p.cuenta_largo from prestamos p where p.estado <> 'cancelado' and p.cuenta_largo is not null)
         and ((a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
               and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso'))
              or (a.tipo = 'ajuste_cpa'
                  and a.afecta_periodo = (select pa.periodo from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1)));
      if v_apl <> v_si then
        v_aviso := format('Con este, los préstamos de antes del corte suman %s al %s y la apertura (QuickBooks) trae %s en sus cuentas (%s): '
                          '%s %s en la apertura. Si faltan préstamos por registrar, regístralos; si ya están todos, es QuickBooks el que '
                          'no tenía el saldo del prestamista: corrige la apertura (abierta, con la balanza corregida y fn_apertura con su '
                          'motivo; cerrada, con un ajuste a la apertura: fn_postear con tipo ajuste_cpa, afecta_periodo «%s», contra '
                          '3900). El saldo_inicial es el del statement, no el de QuickBooks.', v_si, fn_puente_corte() - 1, v_apl, v_ctas,
                          abs(v_apl - v_si), case when v_apl > v_si then 'de más' else 'de menos' end,
                          (select pa.periodo from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1));
      end if;
    end if;
  end if;
  return to_jsonb(v_new) || case when v_aviso is not null then jsonb_build_object('aviso', v_aviso) else '{}'::jsonb end;
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
    -- (Ronda 4: la cuota de septiembre en tránsito al 30-sep, que el banco
    -- cobra en octubre, ya está en la apertura: no se registra otra vez)
    perform fn_banco_apertura_freno(m, p_motivo, 'registrarlo como la cuota del préstamo', 'el motivo (p_motivo)');
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
    select string_agg(format('del %s por %s (%s)', q.fecha, q.monto, a.numero), ', ' order by q.fecha),
           -- (ronda 5: la más cercana en fecha, no una cualquiera: una semanal
           -- puede tener varias registradas por el mismo monto)
           (array_agg(q.asiento_id::text order by abs(q.fecha - v_fecha), q.fecha))[1]
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
    select string_agg(format('del %s por %s', q.fecha, q.monto), ', ' order by q.fecha),
           (array_agg(q.id::text order by abs(q.fecha - v_fecha), q.fecha))[1]
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
-- «llego_su_ticket»: el gasto está dos veces hasta que Edgar diga). Y
-- (ronda 4) lo casado que el banco borró o Plaid quitó (motivo «quitada»:
-- no fue; su botón lo des-casa y queda ignorado).
-- (Ronda 4d) Una propuesta de OTRA versión del banco (la hizo el «Casar» de
-- antes del último pegado: su «version» no es la marca de fn_banco_version,
-- leída de su texto) no enseña sus botones: lo que valía entonces puede
-- pedir hoy su motivo, y pulsado tal cual fallaría (MX008). Su texto dice
-- que se corra «Casar», que la rehace. Antes, hasta el primer «Casar»
-- después de pegar, la bandeja enseñaba los botones de antes.
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
       coalesce(case when q.quien is not null and m.estado <> 'pendiente' then 'quitada' end,
                case when m.posible_duplicado_de is not null and m.duplicado is null then 'posible_duplicado' end,
                m.propuesta->>'motivo', 'sin_propuesta') as motivo,
       case when q.quien is not null and m.estado <> 'pendiente'
            then format('%s: no fue, y está %s (%s). Des-cásalo (con su motivo): el asiento que puso se reversa y el movimiento queda '
                        'ignorado.%s', q.quien, m.estado, coalesce(m.casado_regla, m.casado_clase, ''),
                        case when exists (select 1 from public.conciliaciones cc
                                           where cc.cuenta = m.cuenta and cc.estado = 'confirmada' and cc.fecha_corte >= m.fecha)
                             then ' Está dentro de una conciliación confirmada: reábrela antes (fn_conciliacion_reabrir, con su motivo).'
                             else '' end)
            when m.propuesta ? 'motivo' and (m.propuesta->>'version') is distinct from vv.marca
            then 'Esta propuesta es de antes del último pegado del banco (c6-banco.sql): corre «Casar» (fn_banco_casar_todo) y se rehace '
                 'con lo de hoy; sus botones de antes ya no valen.'
            else coalesce(m.propuesta->>'texto',
                          'Sin propuesta todavía: corre «Casar» (fn_banco_casar_todo) para que el banco lo mire.') end as texto,
       case when q.quien is not null and m.estado <> 'pendiente'
            then jsonb_build_array(jsonb_build_object('texto', 'Des-casarlo: no fue (queda ignorado)', 'llamar', 'fn_banco_descasar',
                                                      'pide_motivo', true, 'pide', jsonb_build_array('p_motivo'),
                                                      'args', jsonb_build_object('p_movimiento', m.id)))
            when m.propuesta ? 'motivo' and (m.propuesta->>'version') is distinct from vv.marca then null
            else m.propuesta->'opciones' end as opciones,
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
  -- (ronda 4d: la marca de esta versión, leída del texto de fn_banco_version —la app no la ejecuta—)
  left join lateral (select substring(p.prosrc from '([0-9]{10})') as marca
                       from pg_catalog.pg_proc p where p.oid = to_regprocedure('public.fn_banco_version()')) vv on true
  -- (ronda 4: lo que el banco borró o Plaid quitó, con quién lo dijo: fn_banco_quitada, escrita aquí)
  left join lateral (select format('%s lo quitó (%s «%s» del %s)', case when a.formato = 'plaid' then 'Plaid' else 'El banco' end,
                                   case when a.formato = 'plaid' then 'su lote' else 'su archivo' end, coalesce(a.nombre, a.id::text),
                                   to_char(a.importado_el at time zone 'America/New_York', 'YYYY-MM-DD')) as quien
                       from public.movimientos_banco_ids i
                       join public.archivos_banco a on a.id = i.archivo_id
                      where i.movimiento_id = m.id and i.id_externo like 'quitada:%'
                      order by i.visto_el
                      limit 1) q on true
 where m.estado = 'pendiente' or m.propuesta->>'motivo' = 'llego_su_ticket'
    -- (ronda 4: lo casado que el banco borró o Plaid quitó, hasta que se des-case)
    or (m.estado in ('casado', 'en_transito')
        and m.id in (select i.movimiento_id from public.movimientos_banco_ids i where i.id_externo like 'quitada:%'));

-- ---------------------------------------------------------------------
-- 9.4 · v_banco_saldos — una por cuenta propia con estado de cuenta (los
-- bancos 10xx menos la caja chica, y las tarjetas de la tabla tarjetas):
-- el saldo en libros hoy; el último saldo que dijo el banco (el del último
-- archivo que lo trae, LEDGERBAL) y el de libros a esa misma fecha; lo
-- pendiente de casar; y su última conciliación. En el signo del libro (un
-- banco, lo que hay; una tarjeta, lo que se debe en negativo) y como lo
-- dice el estado de cuenta (saldo_*_como_banco: la tarjeta, lo que se
-- debe en positivo). alarma: algo pendiente de más de 30 días, o la última
-- conciliación confirmada tiene más de 45 (un mes y medio sin cuadrar), o
-- (ronda 4) un mes terminado y sin cerrar al que sus archivos no llegan
-- (cubierto_hasta: hasta dónde llegan; mes_sin_cubrir: el primero así).
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
       (coalesce(k.hoy - pe.mas_viejo > 30, false) or k.hoy - coalesce(ucc.fecha_corte, k.corte - 1) > 45
        or ms.periodo is not null)                                 as alarma,
       concat_ws('; ',
                 case when k.hoy - pe.mas_viejo > 30
                      then format('hay movimientos pendientes desde el %s (más de 30 días)', pe.mas_viejo) end,
                 case when k.hoy - coalesce(ucc.fecha_corte, k.corte - 1) > 45
                      then format('sin conciliación confirmada desde el %s', coalesce(ucc.fecha_corte, k.corte - 1)) end,
                 -- (ronda 4: el mes terminado y sin cerrar al que le faltan los
                 -- movimientos del final)
                 case when ms.periodo is not null
                      then format('sus archivos llegan al %s y %s terminó el %s sin cerrarse: antes de cerrarlo importa lo de esta '
                                  'cuenta hasta el %s%s', cb.hasta, ms.periodo, ms.hasta, ms.hasta,
                                  case when cu.tipo = 'tarjeta'
                                       then ' (la actividad reciente de la tarjeta en QFX: su statement siguiente trae lo mismo y no '
                                            'se duplica)'
                                       else '' end) end) as alarma_texto,
       -- (Ronda 4) HASTA DÓNDE LLEGAN SUS ARCHIVOS (el «hasta» del último, sin
       -- los retirados) y el primer mes terminado y sin cerrar que no
       -- alcanzan (desde que la cuenta trae archivos). Una tarjeta corta su
       -- statement a mitad de mes (la Blue el 7, la Gold el 22): lo de
       -- después, hasta el 31, llega con el statement siguiente, y si el mes
       -- se cierra antes entra el mes siguiente como tardío. Antes nada lo
       -- decía y octubre se cerraba sin las compras del 23 al 31 de la Gold.
       cb.hasta                                                    as cubierto_hasta,
       ms.periodo                                                  as mes_sin_cubrir
  from cu
  cross join k
  cross join lateral (select coalesce(sum(l.monto), 0)::numeric(14,2) as saldo from public.asiento_lineas l
                       where l.cuenta = cu.cuenta) sl
  -- (el último saldo que dijo el banco: el día más reciente, y ese día el
  -- del estado de cuenta del banco —un OFX— antes que un lote; ronda 4)
  left join lateral (select a.* from public.archivos_banco a
                      where a.cuenta = cu.cuenta and a.saldo is not null and a.saldo_al is not null and a.retirado_el is null
                      order by a.saldo_al desc, (a.formato in ('ofx_sgml', 'ofx_xml')) desc, a.importado_el desc limit 1) ua on true
  cross join lateral (select count(*) as n, coalesce(sum(m.monto), 0) as monto, min(m.fecha) as mas_viejo
                        from public.movimientos_banco m where m.cuenta = cu.cuenta and m.estado = 'pendiente') pe
  left join lateral (select c.* from public.conciliaciones c where c.cuenta = cu.cuenta
                      order by c.fecha_corte desc limit 1) uc on true
  left join lateral (select c.* from public.conciliaciones c where c.cuenta = cu.cuenta and c.estado = 'confirmada'
                      order by c.fecha_corte desc limit 1) ucc on true
  -- (hasta dónde llegan: el «hasta» de cada archivo vivo, o su saldo_al si
  -- es después —el saldo de ese día ya cuenta todo lo de antes—)
  left join lateral (select max(greatest(a.hasta, a.saldo_al)) as hasta, min(coalesce(a.desde, a.hasta, a.saldo_al)) as desde
                       from public.archivos_banco a
                      where a.cuenta = cu.cuenta and a.retirado_el is null) cb on true
  -- (el estado del mes, leído de la fila entera y no por su nombre, como
  -- activa arriba: la prueba 38 de c6 lo pide, por las de c2)
  left join lateral (select p.periodo, p.hasta from public.periodos p
                      where p.tipo = 'mes' and (jsonb_path_query_first(to_jsonb(p), 'strict $.estado') #>> '{}') = 'abierto'
                        and p.desde >= k.corte and p.hasta < k.hoy
                        and cb.hasta is not null and p.hasta > cb.hasta and p.hasta >= coalesce(cb.desde, p.hasta)
                      order by p.desde limit 1) ms on cu.activa;

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
              case when m.casado_auto then ' (automático)' else ' (Edgar)' end)
       -- (ronda 4: el casado que valía al corte, si el de hoy entró después)
       || case when ac.numero is not null
               then format(' Al corte casaba con el asiento %s del %s (%s), que se reversó el %s: el cambio es de después del corte.',
                           ac.numero, ac.fecha, ac.clase, ac.reverso_fecha)
               else '' end,
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
  -- (ronda 4) El casado que valía al corte (fn_conciliacion_items): uno
  -- deshecho con su asiento vivo al corte y su reverso después, si todas las
  -- líneas del de hoy son de después del corte (la clasificación cambiada
  -- por su ticket con el mes cerrado).
  left join lateral (select a0.numero, a0.fecha_contable as fecha, bc0.clase, r0.fecha_contable as reverso_fecha
                       from public.banco_casados bc0
                       join public.asientos a0 on a0.id = bc0.asiento_id
                       join public.asientos r0 on r0.id = bc0.reverso_id
                      where bc0.movimiento_id = m.id and bc0.deshecho_el is not null and m.casado_clase is distinct from 'apertura'
                        and a0.fecha_contable <= c.fecha_corte and r0.fecha_contable > c.fecha_corte
                        and exists (select 1 from public.banco_casado_lineas bl where bl.casado_id = m.casado_id and bl.vigente)
                        and not exists (select 1 from public.banco_casado_lineas bl
                                          join public.asientos a1 on a1.id = bl.asiento_id
                                         where bl.casado_id = m.casado_id and bl.vigente and a1.fecha_contable <= c.fecha_corte)
                      order by bc0.deshecho_el desc
                      limit 1) ac on true
 where c.tipo = 'normal';

-- ---------------------------------------------------------------------
-- 9.7 · v_prestamos — uno por préstamo: lo pagado (capital e interés), lo
-- que se debe, la porción corriente (el capital de las próximas
-- cuotas_al_anio cuotas —un año— por la fórmula: lo que va en 2520 o 2540;
-- el resto, a largo plazo en 2530 o 2550, lo reclasifica el cierre, f08) y
-- cada cuota con su asiento. (Ronda 5: cuotas_al_anio, al final; antes
-- siempre 12 cuotas mensuales.)
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
       p.notas,
       p.cuotas_al_anio
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
    -- el capital de las próximas cuotas_al_anio cuotas (un año), período a
    -- período (interés sobre el saldo que queda, como la fórmula; ronda 5:
    -- antes 12 cuotas mensuales para todo préstamo)
    with recursive s(n, saldo, cap) as (
      select 0, (p.saldo_inicial - coalesce(q.capital, 0))::numeric, 0::numeric
      union all
      select s.n + 1,
             s.saldo - least(s.saldo, greatest(p.cuota - round(s.saldo * p.tasa_anual / 100 / p.cuotas_al_anio, 2), 0)),
             least(s.saldo, greatest(p.cuota - round(s.saldo * p.tasa_anual / 100 / p.cuotas_al_anio, 2), 0))
        from s where s.n < p.cuotas_al_anio and s.saldo > 0)
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
                       'prestamo_cuotas', 'prepagados', 'prepagados_amortizaciones', 'banco_cuentas_personales')
  union all
  select 'regla'::text, c.relname || '.' || r.rulename, md5(pg_get_ruledef(r.oid))
    from pg_rewrite r
    join pg_class c on c.oid = r.ev_class
   where c.relnamespace = 'public'::regnamespace and r.rulename <> '_RETURN'
     and c.relname in ('banco_historial', 'banco_descriptores', 'archivos_banco', 'movimientos_banco', 'movimientos_banco_ids',
                       'banco_casados', 'banco_casado_lineas', 'conciliaciones', 'conciliacion_partidas', 'prestamos',
                       'prestamo_cuotas', 'prepagados', 'prepagados_amortizaciones', 'banco_cuentas_personales')
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
                       'prestamo_cuotas', 'prepagados', 'prepagados_amortizaciones', 'banco_cuentas_personales')
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
--   cada cuenta hasta el fin del mes  (ronda 4) cada mes del período ya
--                              terminado y sin cerrar tiene lo de cada
--                              cuenta hasta su último día (una tarjeta
--                              corta su statement a mitad de mes). Solo
--                              con todo (p_vistas nulo) o por su nombre:
--                              ninguna pantalla lo pide y no frena nada;
--                              es lo de ANTES de cerrar el mes
--   el otro lado de cada casado  (ronda 4d, EL CONTROL) ningún casado vivo
--                              cuyo lado del banco (EL CRITERIO) y cuyo
--                              lado del libro se contradicen sin su motivo
--                              escrito, lo casara quien lo casara; filas =
--                              cuántos, esperadas = 0 (con
--                              v_banco_movimientos o v_banco_bandeja; la
--                              conciliación de su mes no se confirma y lo
--                              dice en «falta»)
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
                            'cuadre: préstamos', 'cuadre: prepagados', 'cuadre: cada cuenta hasta el fin del mes',
                            'cuadre: el otro lado de cada casado'];
  v_solos   text[] := '{}';
  v_conoce  text[] := array['v_banco_movimientos', 'v_banco_bandeja', 'v_banco_saldos', 'v_conciliacion',
                            'v_conciliacion_partidas', 'v_prestamos', 'v_prepagados'];
  v_tablas  text[] := array['banco_historial', 'banco_descriptores', 'archivos_banco', 'movimientos_banco', 'movimientos_banco_ids',
                            'banco_casados', 'banco_casado_lineas', 'conciliaciones', 'conciliacion_partidas', 'prestamos',
                            'prestamo_cuotas', 'prepagados', 'prepagados_amortizaciones', 'banco_cuentas_personales'];
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
  v_si      numeric;
  v_apl     numeric;
  v_apcta   text;
  v_hay_ap  boolean;
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
                                    where (m.estado = 'pendiente' or m.propuesta->>'motivo' = 'llego_su_ticket'
                                           -- (ronda 4: lo casado que el banco quitó)
                                           or (m.estado in ('casado', 'en_transito')
                                               and m.id in (select i.movimiento_id from movimientos_banco_ids i
                                                             where i.id_externo like 'quitada:%')))
                                      and m.fecha <= v_hasta)
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
            -- (ronda 4) lo casado que el banco borró (CORRECTACTION DELETE) o
            -- Plaid quitó: no fue, y lo que casó sigue en el libro hasta que
            -- Edgar lo des-case (la bandeja lo dice, con su botón)
            select format('el movimiento %s (%s %s %s «%s») está %s y %s lo quitó (%s «%s»): no fue. Des-cásalo (fn_banco_descasar, con '
                          'su motivo): queda ignorado', m.id, m.cuenta, m.fecha, m.monto, coalesce(m.descripcion, ''), m.estado,
                          case when a.formato = 'plaid' then 'Plaid' else 'el banco' end,
                          case when a.formato = 'plaid' then 'su lote' else 'su archivo' end, coalesce(a.nombre, a.id::text))
              from movimientos_banco_ids i
              join movimientos_banco m on m.id = i.movimiento_id
              join archivos_banco a on a.id = i.archivo_id
             where i.id_externo like 'quitada:%' and m.estado in ('casado', 'en_transito')
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
                        and coalesce(btrim(a.procedencia->>'motivo_edgar'), '') = '' and l.cuenta <> m.cuenta
                        -- (ronda 4b: salvo el dinero que el banco dice que llega de
                        -- una cuenta personal de Edgar dada de alta, entero al
                        -- patrimonio del accionista: fn_banco_clasificar lo deja así)
                        and not (a.procedencia ? 'cuenta_personal'
                                 and not exists (select 1 from asiento_lineas l2 join cuentas c2 on c2.codigo = l2.cuenta
                                                  where l2.asiento_id = a.id and l2.cuenta <> m.cuenta
                                                    and not (c2.tipo = 'capital'
                                                             or coalesce(c2.etiqueta_fiscal, '') in ('accionista', 'distribucion'))))))
            union all
            -- (ronda 4) el depósito clasificado sin su motivo escrito que HOY
            -- explica un cobro anotado sin su depósito, o una factura abierta
            -- por ese monto en su ventana (la regla de la propuesta, escrita
            -- aquí: la app no ejecuta las funciones internas). Antes solo se
            -- miraba lo que decía la propuesta guardada, y el que nunca pasó
            -- por «Casar» salía en verde
            select format('el asiento %s (movimiento %s, un depósito de %s del %s) lo lleva a %s sin su motivo escrito, y lo explica %s: '
                          'el dinero del cliente entra dos veces. Des-cásalo y regístralo con su cobro (fn_banco_casar_con o '
                          'fn_banco_cobrar)', a.numero, m.id, m.monto, m.fecha,
                          (select string_agg(distinct l.cuenta, ', ') from asiento_lineas l where l.asiento_id = a.id and l.cuenta <> m.cuenta),
                          x.que)
              from asientos a
              join movimientos_banco m on a.origen_tabla = 'movimientos_banco' and m.id::text = a.origen_id
              cross join lateral (
                select coalesce(
                         (select format('el cobro del %s por %s (anotado, sin su depósito)', cb.fecha, cb.monto)
                            from cobros cb
                           where cb.estado = 'vigente' and cb.movimiento_id is null and cb.cuenta = m.cuenta and cb.monto = m.monto
                             and cb.fecha between m.fecha - 30 and m.fecha + 3
                           limit 1),
                         (select format('la factura #%s (%s), abierta por %s', f.num, f.proyecto_id, ab.s1 + ab.s2)
                            from facturas f
                            cross join lateral (
                              select coalesce(sum(lf.monto) filter (where lf.cuenta = (select pc.cuenta from puente_cuentas pc
                                                                                         where pc.rol = 'cxc')), 0) as s1,
                                     coalesce(sum(lf.monto) filter (where lf.cuenta = (select pc.cuenta from puente_cuentas pc
                                                                                         where pc.rol = 'retencion_cxc')), 0) as s2
                                from asiento_lineas lf
                               where lf.partida_tabla = 'facturas' and lf.partida_id = f.id::text) ab
                           where f.fecha <= m.fecha + 3 and f.monto >= m.monto and coalesce(f.estado, '') <> 'anulada'
                             and m.monto in (ab.s1, ab.s2, ab.s1 + ab.s2)
                           limit 1)) as que) x
             where m.monto > 0 and a.camino not in ('reverso', 'reverso_automatico')
               and a.procedencia->>'funcion' = 'fn_banco_clasificar'
               and coalesce(btrim(a.procedencia->>'motivo_edgar'), '') = ''
               and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino in ('reverso', 'reverso_automatico'))
               and x.que is not null
               -- (ronda 4b: en un banco —un abono en una tarjeta no es el cobro de
               -- un cliente—, y salvo el dinero de una cuenta personal de Edgar
               -- dada de alta, entero al patrimonio del accionista; la misma
               -- regla que fn_banco_deposito_explicado y fn_banco_clasificar)
               and left(m.cuenta, 2) = '10'
               and not (a.procedencia ? 'cuenta_personal'
                        and not exists (select 1 from asiento_lineas l2 join cuentas c2 on c2.codigo = l2.cuenta
                                         where l2.asiento_id = a.id and l2.cuenta <> m.cuenta
                                           and not (c2.tipo = 'capital' or coalesce(c2.etiqueta_fiscal, '') in ('accionista', 'distribucion'))))
            union all
            -- (ronda 4) la COMISIÓN de un cobro con tarjeta (el asiento que va
            -- junto a su cobro: Dr la cuenta de los cargos del banco / Cr el
            -- banco) por encima de lo que se queda un procesador (3.5 % más
            -- 0.30 de cada factura del cobro), o en un depósito que no nombra
            -- a ningún procesador, sin su motivo escrito: el cliente pagó
            -- menos y la factura quedó cobrada entera
            select format('el asiento %s (movimiento %s, un depósito de %s) lleva %s de comisión del cobro con tarjeta, %s, sin su motivo '
                          'escrito: ¿un pago parcial? Des-cásalo y regístralo por lo que pagó el cliente', a.numero, m.id, m.monto, k.com,
                          case when k.com > coalesce(k.tope, 0)
                               then format('más que lo que se queda un procesador (%s)', coalesce(k.tope, 0))
                               else 'y el banco no nombra a ningún procesador de tarjetas' end)
              from asientos a
              join movimientos_banco m on a.origen_tabla = 'movimientos_banco' and m.id::text = a.origen_id
              cross join lateral (
                select coalesce((select sum(l.monto) from asiento_lineas l where l.asiento_id = a.id and l.monto > 0), 0) as com,
                       coalesce((a.procedencia->>'tope')::numeric,
                                (select sum(round(0.035 * x.monto + 0.30, 2)) from aplicaciones_cobro x
                                  where x.cobro_id::text = a.procedencia->>'cobro')) as tope) k
             where a.procedencia->>'anexo' = 'comision' and a.camino not in ('reverso', 'reverso_automatico')
               and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino in ('reverso', 'reverso_automatico'))
               and coalesce(btrim(a.procedencia->>'motivo_edgar'), '') = ''
               and (k.com > coalesce(k.tope, 0) or a.procedencia->>'procesador' = 'false')
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
                               when x.n <> a.filas_nuevas
                               then format('dice %s movimientos nuevos y tiene %s', a.filas_nuevas, x.n)
                               -- (ronda 4: y cuántos entraron marcados «posible
                               -- duplicado»: una marca borrada por fuera dejaba que
                               -- una regla fija casara dos veces el mismo cargo)
                               else format('dice %s posibles duplicados y tiene %s marcados (una marca se borró por fuera, con las '
                                           'guardas apagadas)', a.duplicados_posibles, x.d) end) as x
              from archivos_banco a
              cross join lateral (select count(*) as n, count(m.posible_duplicado_de) as d
                                    from movimientos_banco m where m.archivo_id = a.id) x
             where encode(sha256(convert_to(a.texto, 'UTF8')), 'hex') <> a.sha256 or x.n <> a.filas_nuevas
                or x.d <> a.duplicados_posibles
            union all
            -- (ronda 4) la descripción NORMALIZADA de cada movimiento del
            -- período (la que leen R3, R7, la llave y los duplicados) es la de
            -- su descripción (fn_banco_norm, escrita aquí: la app no ejecuta
            -- las funciones internas). Fuera del sello: cambiada con las
            -- guardas apagadas, R3 casaba solo un pago a un proveedor como el
            -- de la tarjeta, sin rastro y en verde
            select format('el movimiento %s (%s %s %s «%s») tiene la descripción normalizada «%s», que no es la de su descripción (se '
                          'cambió por fuera de las funciones del banco, con las guardas apagadas: lo leen las reglas automáticas)',
                          m.id, m.cuenta, m.fecha, m.monto, coalesce(m.descripcion, ''), m.desc_norm)
              from movimientos_banco m
             where m.fecha between v_desde and v_hasta
               and m.desc_norm is distinct from coalesce(btrim(regexp_replace(upper(coalesce(coalesce(m.descripcion, m.memo), '')),
                                                                              '[^[:alnum:]#&]+', ' ', 'g')), '')
            union all
            -- (ronda 4) cada descriptor (lo que reconocen las reglas
            -- automáticas) es el de su último cambio en banco_historial: uno
            -- cambiado con las guardas apagadas no deja historial
            select format('el descriptor «%s» (%s → %s) no es el de su último cambio en banco_historial (%s): se cambió por fuera de '
                          'fn_banco_descriptor, con las guardas apagadas. Vuelve a ponerlo con fn_banco_descriptor (queda el rastro)',
                          d.clave, d.patron, coalesce(d.cuenta, 'sin cuenta'),
                          coalesce(format('«%s» → %s', h.despues->>'patron', coalesce(h.despues->>'cuenta', 'sin cuenta')), 'no tiene'))
              from banco_descriptores d
              left join lateral (select x.despues from banco_historial x
                                  where x.tabla = 'banco_descriptores' and x.clave = d.clave
                                  order by x.cambiado_el desc limit 1) h on true
             where h.despues is null or (h.despues->>'patron') is distinct from d.patron
                or (h.despues->>'cuenta') is distinct from d.cuenta
            union all
            -- (ronda 4b) y cada cuenta personal de Edgar dada de alta (lo que
            -- deja entrar dinero al patrimonio del accionista sin motivo) es
            -- la de su último cambio en banco_historial; y la que el
            -- historial tiene y ya no está, se borró por fuera
            select format('la cuenta personal ····%s («%s», %s) no es la de su último cambio en banco_historial (%s): se cambió por '
                          'fuera de fn_banco_cuenta_personal, con las guardas apagadas. Vuelve a ponerla con fn_banco_cuenta_personal '
                          '(queda el rastro)', p.ultimos4, p.nombre, case when p.activa then 'activa' else 'de baja' end,
                          coalesce(format('«%s», %s', h.despues->>'nombre',
                                          case when (h.despues->>'activa')::boolean then 'activa' else 'de baja' end), 'no tiene'))
              from banco_cuentas_personales p
              left join lateral (select x.despues from banco_historial x
                                  where x.tabla = 'banco_cuentas_personales' and x.clave = p.ultimos4
                                  order by x.cambiado_el desc limit 1) h on true
             where h.despues is null or (h.despues->>'nombre') is distinct from p.nombre
                or (h.despues->>'activa')::boolean is distinct from p.activa
            union all
            select format('la cuenta personal ····%s está en banco_historial y ya no está en banco_cuentas_personales: se borró por '
                          'fuera de las funciones del banco, con las guardas apagadas', h.clave)
              from (select distinct on (x.clave) x.clave, x.despues
                      from banco_historial x
                     where x.tabla = 'banco_cuentas_personales'
                     order by x.clave, x.cambiado_el desc) h
             where not exists (select 1 from banco_cuentas_personales p where p.ultimos4 = h.clave)
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

  -- (Ronda 4d) EL CONTROL: EL OTRO LADO DE CADA CASADO. Ningún casado vivo,
  -- lo case quien lo case («Casar» con cualquiera de sus reglas, un botón de
  -- la bandeja —también uno de antes del último pegado—, fn_banco_casar_con,
  -- un asiento escrito a mano, el cobro que c3 registró con su movimiento,
  -- una partida de la apertura), cuyo lado del banco (EL CRITERIO: la cuenta
  -- que nombra, la personal de Edgar, a quién nombra, el emisor de la
  -- tarjeta que paga, el cheque, lo que dice su duplicado) y cuyo lado del
  -- libro (lo que hay enfrente en su asiento: otra cuenta propia, una deuda,
  -- el patrimonio del accionista, el cobro de un cliente, una partida de
  -- QuickBooks, otra cosa) se contradicen sin su motivo escrito: la regla
  -- de fn_banco_criterio, con lo coherente fuera (la personal dada de alta
  -- contra 2900, 3100, 3200 o 1130; un tercero contra su cobro; el
  -- prestamista contra su deuda). Antes cada camino frenaba lo suyo, y lo
  -- que se colaba por otro quedaba casado y en verde. Es una COPIA escrita
  -- de las funciones internas (la app no las ejecuta; ver arriba):
  -- fn_banco_verificar comprueba que cuenta lo mismo que la referencia
  -- (fn_banco_criterio_casados), y la conciliación de su mes no se confirma
  -- con uno así. filas: cuántos hay; esperadas: 0. (Solo pasa por la regla
  -- entera lo que PUEDE contradecirse —lo mismo que la referencia—, y las
  -- expresiones regulares van escritas tal cual —las de
  -- fn_banco_otra_cuenta, fn_banco_otra_tarjeta y las palabras de
  -- fn_banco_nombrado—: una consulta sin parámetros guarda su plan en la
  -- sesión. Con un año de banco, mirarlo todo y planearla en cada llamada
  -- costaba 0,2 s en cada pantalla; así, unos 80 ms. Cada paso, MATERIALIZED:
  -- planeada entera, como un solo árbol de joins, se llevaba 65 ms en
  -- planearse; así, 12.)
  if v_pedidas && array['v_banco_movimientos', 'v_banco_bandeja'] or 'cuadre: el otro lado de cada casado' = any (v_solos) then
    select count(*), coalesce((array_agg(z.x order by z.cuenta, z.fecha, z.id))[1:20], '{}')
      into v_cnt, v_malos
      from (
        with k as (
               select (select d.patron from banco_descriptores d where d.clave = 'transferencia') as p_tr,
                      (select d.patron from banco_descriptores d where d.clave = 'pago_tarjeta') as p_pt,
                      (select d.patron from banco_descriptores d where d.clave = 'pago_recibido') as p_pr,
                      coalesce((select mp.cuenta from mapeo_metodo_pago mp where mp.forma = 'efectivo' and mp.cuenta is not null
                                 order by mp.confirmado_el desc nulls last limit 1), '1050') as caja,
                      (select pc.cuenta from puente_cuentas pc where pc.rol = 'cxc') as cxc,
                      (select pc.cuenta from puente_cuentas pc where pc.rol = 'retencion_cxc') as ret,
                      -- (los 4 últimos de cualquier tarjeta activa, en una sola
                      -- expresión: el filtro de abajo, sin una consulta por fila)
                      (select '(^| )(' || string_agg(t.ultimos4, '|') || ')( |$)' from tarjetas t
                        where t.activa and t.ultimos4 ~ '^[0-9]{4}$') as rx_t),
             -- (las cuentas propias con estado de cuenta, y su tipo:
             -- fn_banco_es_propia y fn_banco_tipo_cuenta)
             pro as materialized (
               select c.codigo,
                      case when left(c.codigo, 2) = '10' and c.tipo = 'activo' and c.saldo_normal = 'debe' and c.regla_obra = 'prohibida'
                           then 'banco' else 'tarjeta' end as tipo
                 from cuentas c cross join k
                where (left(c.codigo, 2) = '10' and c.tipo = 'activo' and c.saldo_normal = 'debe' and c.regla_obra = 'prohibida'
                       and c.codigo <> k.caja)
                   or (left(c.codigo, 5) = '2100-' and c.tipo = 'pasivo' and c.saldo_normal = 'haber'
                       and exists (select 1 from tarjetas t where t.cuenta = c.codigo))),
             -- (y con las del patrimonio del accionista, las que hacen que un
             -- asiento PUEDA contradecir al banco: ver abajo)
             esp as materialized (
               select array(select p.codigo from pro p
                            union
                            select c.codigo from cuentas c
                             where c.tipo = 'capital' or c.etiqueta_fiscal in ('accionista', 'distribucion')) as e),
             -- (las tarjetas de crédito cuyos 4 últimos sueltos lee el pago
             -- desde el banco: las de la empresa y la personal en 2900)
             tcr as materialized (
               select t.ultimos4 from tarjetas t join cuentas c on c.codigo = t.cuenta
                where t.activa and t.ultimos4 ~ '^[0-9]{4}$'
                  and (left(t.cuenta, 5) = '2100-' or (c.tipo = 'pasivo' and c.etiqueta_fiscal = 'accionista'))),
             -- (las palabras del banco y de una transferencia entre cuentas, de
             -- fn_banco_nombrado: lo que queda es a quién nombra)
             pal(rx) as (
               values ('^(' || 'CHECK|CHK|CHEQUE|ACH|DEBIT|DEBITO|CREDIT|PAYMENT|PAYMENTS|PMT|PYMT|PMNT|ONLINE|BILL|BILLPAY|PAY|WEB|'
                       || 'PPD|CCD|TEL|IND|INDN|DES|ENTRY|DESCR|DESC|SEC|FROM|FOR|THE|DIRECT|DEP|DEPOSIT|EPAY|EPAYMENT|WIRE|'
                       || 'TRANSFER|XFER|OUTGOING|INCOMING|OUT|WITHDRAWAL|WITHDRAW|POS|PURCHASE|CARD|RECURRING|AUTOPAY|AUTO|'
                       || 'ELECTRONIC|ORIG|TRN|REF|CONF|CONFIRMATION|TRACE|EFT|ZELLE|NAME|DATE|EED|NUM|NUMBER|TRANSACTION|ITEM|'
                       || 'FEE|SERVICE|BANK|ORDER|MOBILE|EXTERNAL|INTERNAL|SENT|ACCOUNT|ACCT|SAVINGS|CHECKING|PAID|BUSINESS|'
                       || 'COMPANY|AND|TO|ID|CO|NO|NR|OF|ON|IN|AT|BY|DR|CR|AM|PM|XX|SAV|SAVING|MMA|MMK|DDA|BOOK|MONEY|MARKET|'
                       || 'SHARE|DRAFT|REALTIME|SCHEDULED|DOMESTIC|VIA|BANKING|REFERENCE|SAME|DAY' || ')$')),
             -- (los emisores que se conocen, en el orden de fn_banco_emisor;
             -- y los de las tarjetas de la empresa: fn_banco_emisores_propios)
             emi(e, rx, o) as (
               values ('AMERICAN EXPRESS', '(^| )(AMEX|AMERICAN EXPRESS)( |$)', 1),
                      ('BANK OF AMERICA', '(^| )(BANK OF AMERICA|BK OF AMER|BK OF AMERICA|BOFA)( |$)', 2),
                      ('CAPITAL ONE', '(^| )(CAPITAL ONE|CAPITALONE|CAP ONE)( |$)', 3),
                      ('CITI', '(^| )(CITI|CITIBANK|CITICARD|CITICARDS|CITI CARD)( |$)', 4),
                      ('DISCOVER', '(^| )DISCOVER( |$)', 5),
                      ('WELLS FARGO', '(^| )WELLS FARGO( |$)', 6),
                      ('BARCLAYS', '(^| )(BARCLAYS|BARCLAYCARD|BARCLAY)( |$)', 7),
                      ('US BANK', '(^| )(US BANK|U S BANK|USBANK)( |$)', 8),
                      ('SYNCHRONY', '(^| )(SYNCHRONY|SYNCB)( |$)', 9),
                      ('APPLE CARD', '(^| )(APPLE CARD|APPLECARD|GOLDMAN SACHS|GS BANK)( |$)', 10),
                      ('NAVY FEDERAL', '(^| )(NAVY FEDERAL|NAVY FCU|NAVY FED)( |$)', 11),
                      ('CHASE', '(^| )(CHASE|JPMORGAN CHASE)( |$)', 12)),
             emp as materialized (
               select coalesce(array_agg(distinct x.e), '{}'::text[]) as e
                 from tarjetas t
                 join cuentas c on c.codigo = t.cuenta
                 cross join lateral (select e.e from emi e
                                      where coalesce(btrim(regexp_replace(upper(concat_ws(' ', c.nombre, c.nombre_en, t.titular, t.notas)),
                                                                          '[^[:alnum:]#&]+', ' ', 'g')), '') ~ e.rx
                                      order by e.o limit 1) x
                where t.activa and left(t.cuenta, 5) = '2100-' and c.tipo = 'pasivo' and c.saldo_normal = 'haber'),
             -- LOS CASADOS VIVOS sin su motivo escrito (el del casado, o el que
             -- Edgar escribió en el asiento que puso ESTE movimiento); un
             -- ticket, la devolución de un cobro o una regla fija no se miran
             cas as materialized (
               select bc.id as cid, bc.clase, bc.otro_lado as ol0, bc.asiento_id, m.id, m.cuenta, m.fecha, m.monto, m.descripcion,
                      m.cheque, m.memo, coalesce(m.desc_norm, '') as dn, coalesce(p.tipo, '') as tipo,
                      a.origen_tabla, a.origen_id, a.procedencia,
                      coalesce(m.tipo_banco, '') = 'XFER' or coalesce(coalesce(m.desc_norm, '') ~* k.p_tr, false) as tr,
                      coalesce(p.tipo, '') = 'banco' and m.monto < 0
                        and (coalesce(coalesce(m.desc_norm, '') ~* k.p_pt, false)
                             or exists (select 1 from tcr where coalesce(m.desc_norm, '') ~ ('(^| )' || tcr.ultimos4 || '( |$)'))) as pt,
                      coalesce(p.tipo, '') = 'tarjeta' and m.monto > 0 and coalesce(coalesce(m.desc_norm, '') ~* k.p_pr, false) as pr
                 from banco_casados bc
                 join movimientos_banco m on m.id = bc.movimiento_id
                 cross join k
                 left join pro p on p.codigo = m.cuenta
                 left join asientos a on a.id = bc.asiento_id
                where bc.deshecho_el is null and bc.clase not in ('recibo', 'devolucion', 'regla')
                  and m.estado in ('casado', 'en_transito')
                  and nullif(btrim(bc.motivo, E' \t\r\n\f' || chr(11)), '') is null
                  and not (a.origen_tabla = 'movimientos_banco' and a.origen_id = m.id::text
                           and nullif(btrim(a.procedencia->>'motivo_edgar', E' \t\r\n\f' || chr(11)), '') is not null)
                  -- (solo lo que PUEDE contradecirse, como la referencia: lo
                  -- que el banco da por transferencia o por el pago de una
                  -- tarjeta, lo casado con la personal de Edgar, o un asiento
                  -- con otra cuenta propia o el patrimonio enfrente. Lo demás
                  -- —el cobro de un cliente, un gasto— no: con un año de
                  -- banco, mirarlo todo costaba 0,2 s en cada pantalla)
                  and (coalesce(m.tipo_banco, '') = 'XFER'
                       or coalesce(coalesce(m.desc_norm, '') ~* k.p_tr, false)
                       or (m.monto < 0 and coalesce(p.tipo, '') = 'banco'
                           and (coalesce(coalesce(m.desc_norm, '') ~* k.p_pt, false)
                                or coalesce(coalesce(m.desc_norm, '') ~ k.rx_t, false)))
                       or bc.otro_lado->>'clase' = 'personal'
                       or (a.origen_tabla = 'movimientos_banco' and a.origen_id = m.id::text and a.procedencia ? 'cuenta_personal')
                       or exists (select 1 from asiento_lineas l
                                   where l.asiento_id = bc.asiento_id and l.cuenta <> m.cuenta
                                     and l.cuenta = any ((select esp.e from esp)::text[])))),
             -- LO QUE DICE EL LIBRO enfrente (fn_banco_libro_lado): las otras
             -- cuentas del asiento
             lib as materialized (
               select c.cid,
                      array_agg(distinct l.cuenta order by l.cuenta) as ctas,
                      min(l.cuenta) filter (where p.codigo is not null) as pro,
                      min(l.cuenta) filter (where left(l.cuenta, 2) = '25' and cu.tipo = 'pasivo' and cu.imputable
                                              and coalesce(cu.etiqueta_fiscal, '') not in ('accionista', 'distribucion')) as deu,
                      min(l.cuenta) filter (where cu.tipo = 'capital' or cu.etiqueta_fiscal in ('accionista', 'distribucion')) as acc,
                      coalesce(bool_or(l.cuenta in (k.cxc, k.ret)), false) as cxc,
                      coalesce(bool_and(cu.tipo in ('gasto', 'otro_gasto')), false) as gas
                 from cas c
                 cross join k
                 join asiento_lineas l on l.asiento_id = c.asiento_id and l.cuenta is distinct from c.cuenta
                 left join cuentas cu on cu.codigo = l.cuenta
                 left join pro p on p.codigo = l.cuenta
                where c.clase <> 'apertura' and c.clase <> 'cobro' and c.origen_tabla is distinct from 'cobros'
                group by c.cid),
             cl as materialized (
               select c.*, lb.ctas,
                      case when c.clase = 'apertura' then 'apertura'
                           when c.clase = 'cobro' or c.origen_tabla = 'cobros' then 'cobro'
                           when lb.pro is not null then 'propia'
                           when lb.deu is not null then 'deuda'
                           when lb.acc is not null then 'patrimonio'
                           when lb.cxc then 'cobro'
                           else 'otro' end as l,
                      coalesce(lb.pro, lb.deu, lb.acc) as lcta,
                      coalesce(lb.gas, false) and cardinality(lb.ctas) > 0 as solo_gasto
                 from cas c left join lib lb on lb.cid = c.cid),
             -- EL NÚMERO que nombra (fn_banco_otro_lado): el de una cuenta en
             -- una transferencia; si no, en el pago de una tarjeta desde el
             -- banco, el de la tarjeta (o sus 4 últimos sueltos); en NAME o en
             -- la nota. Sin número, el que trae su duplicado «es el mismo».
             nu as materialized (
               select c.*, coalesce(n1.u4, n2.u4) as u4, n1.u4 is null and n2.u4 is not null as dup
                 from cl c
                 cross join lateral (
                   select case when c.tr or c.pt then coalesce(btrim(regexp_replace(upper(coalesce(c.memo, '')), '[^[:alnum:]#&]+', ' ', 'g')), '')
                               else '' end as mn) mm
                 cross join lateral (
                   select coalesce(
                            case when c.tr
                                 then coalesce(right(substring(c.dn from '(?:^| )(?:CHK|CHECKING|SAV|SAVINGS|ACCT|ACCOUNT|DDA|MMA) X*([0-9]{4,})(?: |$)'), 4), right(substring(mm.mn from '(?:^| )(?:CHK|CHECKING|SAV|SAVINGS|ACCT|ACCOUNT|DDA|MMA) X*([0-9]{4,})(?: |$)'), 4)) end,
                            case when c.tipo = 'banco' and c.monto < 0 and (c.tr or c.pt)
                                 then coalesce(right(coalesce(substring(c.dn from '(?:^| )(?:CARD|CRD)(?: ENDING(?: IN)?| NO| #)? X*([0-9]{4,})(?: |$)'), substring(c.dn from '(?:^| )ENDING(?: IN)? X*([0-9]{4})(?: |$)')), 4),
                                               right(coalesce(substring(mm.mn from '(?:^| )(?:CARD|CRD)(?: ENDING(?: IN)?| NO| #)? X*([0-9]{4,})(?: |$)'), substring(mm.mn from '(?:^| )ENDING(?: IN)? X*([0-9]{4})(?: |$)')), 4),
                                               (select t.ultimos4 from tcr t where c.dn ~ ('(^| )' || t.ultimos4 || '( |$)')
                                                 order by t.ultimos4 limit 1)) end) as u4) n1
                 left join lateral (
                   select y.u4
                     from movimientos_banco x
                     cross join lateral (
                       select coalesce(btrim(regexp_replace(upper(coalesce(x.memo, '')), '[^[:alnum:]#&]+', ' ', 'g')), '') as xm,
                              coalesce(x.desc_norm, '') as xd) w
                     cross join lateral (
                       select coalesce(right(substring(w.xd from '(?:^| )(?:CHK|CHECKING|SAV|SAVINGS|ACCT|ACCOUNT|DDA|MMA) X*([0-9]{4,})(?: |$)'), 4), right(substring(w.xm from '(?:^| )(?:CHK|CHECKING|SAV|SAVINGS|ACCT|ACCOUNT|DDA|MMA) X*([0-9]{4,})(?: |$)'), 4),
                                       case when c.tipo = 'banco' and c.monto < 0
                                            then coalesce(right(coalesce(substring(w.xd from '(?:^| )(?:CARD|CRD)(?: ENDING(?: IN)?| NO| #)? X*([0-9]{4,})(?: |$)'), substring(w.xd from '(?:^| )ENDING(?: IN)? X*([0-9]{4})(?: |$)')), 4),
                                                          right(coalesce(substring(w.xm from '(?:^| )(?:CARD|CRD)(?: ENDING(?: IN)?| NO| #)? X*([0-9]{4,})(?: |$)'), substring(w.xm from '(?:^| )ENDING(?: IN)? X*([0-9]{4})(?: |$)')), 4))
                                       end) as u4) y
                    where (c.tr or c.pt) and n1.u4 is null
                      and x.posible_duplicado_de = c.id and x.duplicado = 'es_el_mismo' and x.cuenta = c.cuenta
                      and y.u4 is not null
                    order by x.importado_el, x.id
                    limit 1) n2 on true),
             -- DE QUIÉN ES ESE NÚMERO: de la empresa (fn_banco_numero_de), una
             -- cuenta personal de Edgar dada de alta (fn_banco_personal_de), o
             -- uno que no se conoce
             ol as materialized (
               select n.*, q.cta, q.per,
                      coalesce((select p.tipo from pro p where p.codigo = q.cta),
                               case when exists (select 1 from cuentas cu
                                                  where cu.codigo = q.cta and left(cu.codigo, 2) = '25' and cu.tipo = 'pasivo' and cu.imputable
                                                    and coalesce(cu.etiqueta_fiscal, '') not in ('accionista', 'distribucion'))
                                    then 'deuda' end) as btipo,
                      -- (a quién nombra sin número: fn_banco_nombrado, solo donde
                      -- cuenta —una transferencia, o el libro a una cuenta propia—)
                      case when n.u4 is null and not n.pt and (n.tr or (not n.pr and n.l = 'propia'))
                           then (select string_agg(w.p, ' ' order by w.i)
                                   from (select u.p, u.i, lag(u.p) over (order by u.i) as prev
                                           from unnest(regexp_split_to_array(regexp_replace(n.dn, '[&#]', '', 'g'), ' '))
                                                with ordinality as u(p, i)) w
                                  cross join pal
                                  where w.p ~ '^[[:alpha:]]{2,}$'
                                    and (w.p !~ pal.rx
                                         or (w.p in ('BANK', 'MOBILE') and w.i > 1 and w.prev ~ '^[[:alpha:]]+$' and w.prev !~ pal.rx)))
                      end as nom,
                      -- (el emisor de la tarjeta que paga: fn_banco_emisor)
                      case when n.u4 is null and n.pt
                           then (select e.e from emi e
                                  where coalesce(btrim(regexp_replace(upper(n.dn), '[^[:alnum:]#&]+', ' ', 'g')), '') ~ e.rx
                                  order by e.o limit 1) end as em,
                      -- (el número de un cheque: fn_banco_cheque_num)
                      case when n.u4 is null and not n.tr and not n.pt and not n.pr and n.l = 'propia'
                           then coalesce(nullif(ltrim(nullif(btrim(n.cheque, E' \t\r\n\f' || chr(11)), ''), '0'), ''),
                                         substring(regexp_replace(coalesce(btrim(regexp_replace(upper(coalesce(n.descripcion, '')),
                                                                                                 '[^[:alnum:]#&]+', ' ', 'g')), ''),
                                                                  '(^| )(TO|FROM) (CHK|CK) ', ' ', 'g')
                                                   from '(?:^| )(?:CHECK|CHK|CHEQUE|CK)(?: NO)? ?#? ?0*([1-9][0-9]{0,9})(?: |$)')) end as chq
                 from nu n
                 cross join lateral (
                   select case when n.u4 ~ '^[0-9]{4}$'
                               then coalesce((select t.cuenta from tarjetas t join pro p on p.codigo = t.cuenta
                                               where t.ultimos4 = n.u4 and t.activa order by t.cuenta limit 1),
                                             (select a.cuenta from archivos_banco a
                                               where a.ultimos4 = n.u4 and a.retirado_el is null
                                                 and (a.formato in ('ofx_sgml', 'ofx_xml') or a.cuenta_confirmada)
                                               order by a.importado_el desc limit 1),
                                             (select qb.cuenta from apertura_mapeo_qb qb join pro p on p.codigo = qb.cuenta
                                               where qb.tipo = 'cuenta' and qb.nombre_qb ~ ('(^|[^0-9])' || n.u4 || '([^0-9]|$)')
                                                 and qb.nombre_qb !~ '^[[:space:][:punct:]]*[0-9]+[[:space:][:punct:]]*$'
                                               order by qb.cuenta limit 1)) end as cta) q0
                 cross join lateral (
                   select q0.cta,
                          case when n.u4 ~ '^[0-9]{4}$' and q0.cta is null
                               then coalesce((select bp.nombre from banco_cuentas_personales bp where bp.ultimos4 = n.u4 and bp.activa),
                                             (select format('%s (su tarjeta personal, dada de alta en %s)', t.titular, t.cuenta)
                                                from tarjetas t join cuentas cu on cu.codigo = t.cuenta
                                               where t.ultimos4 = n.u4 and t.activa and cu.tipo = 'pasivo' and cu.etiqueta_fiscal = 'accionista'
                                               order by t.cuenta limit 1)) end as per) q),
             -- LO QUE DICE EL BANCO (la clase de EL CRITERIO)
             b0 as materialized (
               select o.*,
                      case when o.u4 is not null
                           then case when o.cta is not null then 'propia' when o.per is not null then 'personal' else 'desconocida' end
                           when o.tr and not o.pt and o.nom is not null then 'tercero_tr'
                           when o.pt and o.em is not null and cardinality(emp.e) > 0 and not (o.em = any (emp.e)) then 'tercero_emisor'
                           when o.tr or o.pt or o.pr then 'propia_sin_numero'
                           else 'tercero' end as b0
                 from ol o cross join emp),
             -- (con la cuenta personal que lo era al casarlo: darla de baja
             -- después —la cerró— no pone en rojo lo que entonces era suyo)
             bl as materialized (
               select x.*,
                      case when x.b0 <> 'personal'
                                and (x.ol0->>'clase' = 'personal'
                                     or (x.origen_tabla = 'movimientos_banco' and x.origen_id = x.id::text
                                         and x.procedencia ? 'cuenta_personal'))
                           then 'personal_al_casarlo' else x.b0 end as b
                 from b0 x)
        select b.cuenta, b.fecha, b.id,
               format('%s %s %s «%s» (movimiento %s, casado %s, %s): el banco dice %s, y el libro dice %s', b.cuenta, b.fecha, b.monto,
                      coalesce(b.descripcion, ''), b.id, b.cid, b.clase,
                      case b.b when 'propia' then format('la cuenta ····%s, que es %s', b.u4, b.cta)
                               when 'personal' then format('la cuenta ····%s, tu cuenta personal (%s)', b.u4, b.per)
                               when 'personal_al_casarlo'
                               then format('tu cuenta personal ····%s (lo era al casarlo)',
                                           coalesce(b.ol0->>'ultimos4', b.procedencia->>'cuenta_personal'))
                               when 'desconocida' then format('la cuenta ····%s, que no conozco', b.u4)
                               when 'tercero_tr' then format('«%s», sin número de cuenta', b.nom)
                               when 'tercero_emisor' then format('el pago de una tarjeta de %s (ninguna de la empresa lo es)', b.em)
                               when 'propia_sin_numero' then 'dinero entre cuentas propias'
                               else case when b.chq is not null then format('el cheque %s, el pago a un tercero', b.chq)
                                         when b.nom is not null then format('«%s», un tercero', b.nom)
                                         else 'un tercero' end end
                      || case when b.dup then ' (lo dice su duplicado)' else '' end,
                      case b.l when 'propia' then format('una transferencia o el pago de una tarjeta con %s', b.lcta)
                               when 'deuda' then format('dinero de o a la deuda %s', b.lcta)
                               when 'patrimonio' then format('el patrimonio del accionista (%s)', b.lcta)
                               when 'cobro' then 'el cobro de un cliente'
                               when 'apertura' then 'una partida en tránsito de QuickBooks (la conciliación de apertura)'
                               else format('otra cosa (%s)', coalesce(array_to_string(b.ctas, ', '), 'sin cuenta')) end) as x
          from bl b
         where case when b.l in ('propia', 'deuda')
                    then (b.b = 'propia' and not coalesce(b.cta = any (b.ctas), false))
                         or b.b in ('personal', 'personal_al_casarlo', 'desconocida', 'tercero_tr', 'tercero_emisor')
                         or (b.b = 'tercero' and b.l = 'propia' and (b.chq is not null or b.nom is not null))
                    when b.l in ('cobro', 'apertura') then b.b in ('propia', 'personal', 'personal_al_casarlo')
                    when b.l = 'patrimonio' then b.b not in ('personal', 'personal_al_casarlo')
                    else b.b = 'propia' and not (coalesce(b.btipo, '') = 'deuda' and b.monto < 0 and b.solo_gasto) end
      ) z;
    orden := 59; vista := 'cuadre: el otro lado de cada casado'; filas := v_cnt; esperadas := 0;
    ok := v_cnt = 0;
    detalle := case when not ok
                    then format('Esperaba 0 casados cuyo lado del banco y cuyo lado del libro se contradicen sin su motivo escrito, y hay '
                                '%s%s: %s. Cada uno: si está mal casado, des-cásalo (fn_banco_descasar, con su motivo) y cásalo con lo '
                                'que es; si es correcto así, escribe su motivo: select fn_banco_casar_con(''<movimiento>'', '
                                '''{"casado": "<su casado>"}'', ''<por qué es correcto>''). La conciliación de su mes no se confirma '
                                'hasta entonces.', v_cnt, case when v_cnt > 20 then ' (los 20 primeros)' else '' end,
                                array_to_string(v_malos, '; ')) end;
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
               -- (ronda 4) salvo el cargo clasificado que se cambió por su
               -- ticket sin reabrirla (el ticket llegó con el mes cerrado):
               -- fn_banco_cambiar_por_ticket solo lo deja si la conciliación
               -- sigue diciendo lo mismo (sus partidas y su saldo en libros),
               -- y la clasificación que sustituyó estaba al confirmarla
               and not (m.estado = 'casado'
                        and exists (select 1 from banco_casados bv
                                     where bv.id = m.casado_id and bv.deshecho_el is null and bv.clase = 'recibo'
                                       and bv.regla like 'R1 llegó su ticket%')
                        and exists (select 1 from banco_casados b0
                                     where b0.movimiento_id = m.id and b0.clase = 'clasificado' and b0.deshecho_el is not null
                                       and b0.casado_el <= c.confirmada_el and b0.deshecho_el >= c.confirmada_el))
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
                                      'del banco y sin su motivo (fn_conciliacion_partida)' end,
                            -- (ronda 4) el saldo con que se confirmó, otra vez
                            -- contra los ARCHIVOS de ese día que ya estaban al
                            -- confirmarla, no contra el saldo_archivo guardado
                            -- con ella: la regla de fn_conciliacion_recalcular
                            -- (los del banco —OFX— si hay; si no, los lotes)
                            case when xa.n > 0 and (xa.n > 1 or xa.contra or (c.saldo_statement is null and c.saldo_banco <> xa.ref))
                                      and (nullif(btrim(coalesce(c.saldo_motivo, '')), '') is null
                                           or nullif(btrim(coalesce(c.saldo_documento, '')), '') is null)
                                 then format('se confirmó con el saldo %s y los archivos del banco de ese día dicen %s, sin su motivo y '
                                             'su documento (fn_conciliacion_saldo)',
                                             coalesce(c.saldo_statement, case when left(c.cuenta, 1) = '2' then -c.saldo_banco
                                                                              else c.saldo_banco end), xa.txt) end))
              from conciliaciones c
              -- (los archivos con saldo a su fecha que ya estaban al
              -- confirmarla, del nivel que vale: los OFX si hay, si no los
              -- lotes; el saldo como lo dice el statement —en una tarjeta,
              -- lo que se debe—)
              cross join lateral (
                select count(distinct a.saldo) as n,
                       string_agg(format('%s («%s»)', case when left(c.cuenta, 1) = '2' then -a.saldo else a.saldo end,
                                         coalesce(a.nombre, a.id::text)), '; ' order by a.importado_el) as txt,
                       coalesce(bool_or(c.saldo_statement is not null
                                        and c.saldo_statement <> (case when left(c.cuenta, 1) = '2' then -a.saldo else a.saldo end)),
                                false) as contra,
                       (array_agg(a.saldo order by a.importado_el desc))[1] as ref
                  from archivos_banco a
                 where a.cuenta = c.cuenta and a.saldo_al = c.fecha_corte and a.saldo is not null and a.retirado_el is null
                   and a.importado_el <= c.confirmada_el
                   and (a.formato in ('ofx_sgml', 'ofx_xml'))
                       = exists (select 1 from archivos_banco o
                                  where o.cuenta = c.cuenta and o.saldo_al = c.fecha_corte and o.saldo is not null
                                    and o.retirado_el is null and o.importado_el <= c.confirmada_el
                                    and o.formato in ('ofx_sgml', 'ofx_xml'))) xa
             where c.estado = 'confirmada' and c.tipo = 'normal'
               and ((c.saldo_statement is not null and c.saldo_archivo is not null and c.saldo_statement <> c.saldo_archivo
                     and (nullif(btrim(coalesce(c.saldo_motivo, '')), '') is null
                          or nullif(btrim(coalesce(c.saldo_documento, '')), '') is null))
                    or (xa.n > 0 and (xa.n > 1 or xa.contra or (c.saldo_statement is null and c.saldo_banco <> xa.ref))
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
    -- (Ronda 4) La diferencia que ya trae la APERTURA: lo que QuickBooks
    -- tenía en las cuentas de los préstamos al 30-sep (la apertura viva y sus
    -- ajustes) contra lo que dicen los statements de los prestamistas (el
    -- saldo_inicial de los préstamos de antes del corte). QuickBooks parte
    -- las cuotas con su propia tabla y casi nunca da el saldo del prestamista
    -- al centavo: antes el detalle mandaba a «registrar un préstamo, su
    -- desembolso o una cuota» y no era ninguna de las tres. Y sin la apertura
    -- en el libro todavía, lo dice.
    select coalesce(sum(p.saldo_inicial) filter (where p.saldo_inicial_al < v_corte), 0),
           (select string_agg(distinct x.c, ', ')
              from prestamos q cross join lateral (values (q.cuenta), (q.cuenta_largo)) as x(c)
             where q.estado <> 'cancelado' and x.c is not null)
      into v_si, v_apcta
      from prestamos p
     where p.estado <> 'cancelado';
    select exists (select 1 from asientos a
                    where a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                      and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')),
           coalesce((select -sum(l.monto)
                       from asiento_lineas l join asientos a on a.id = l.asiento_id
                      where l.cuenta in (select p.cuenta from prestamos p where p.estado <> 'cancelado'
                                         union select p.cuenta_largo from prestamos p where p.estado <> 'cancelado' and p.cuenta_largo is not null)
                        and ((a.tipo = 'apertura' and a.camino not in ('reverso', 'reverso_automatico')
                              and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso'))
                             or (a.tipo = 'ajuste_cpa'
                                 and a.afecta_periodo = (select pa.periodo from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1)))),
                    0)
      into v_hay_ap, v_apl;
    orden := 55; vista := 'cuadre: préstamos'; filas := null; esperadas := null;
    ok := v_cnt = 0 or (v_a = v_b and cardinality(v_malos) = 0);
    detalle := case when v_cnt = 0 then 'Sin préstamos registrados (fn_prestamo_guardar, en el SQL Editor).'
                    when not ok then concat_ws('; ',
                      case when v_a <> v_b and not v_hay_ap and v_si > 0
                           then format('el libro dice %s en las cuentas de los préstamos y sus saldos suman %s: la apertura todavía no '
                                       'está en el libro, y los préstamos de antes del corte (%s al %s) entran con ella (fn_apertura, '
                                       'c4)', v_b, v_a, v_si, v_corte - 1)
                           when v_a <> v_b and v_hay_ap and v_apl <> v_si and v_b - v_a = v_apl - v_si
                           then format('la apertura (QuickBooks) trae %s en las cuentas de los préstamos (%s) y los statements de los '
                                       'préstamos registrados de antes del corte suman %s al %s (su saldo_inicial): %s %s en la apertura. '
                                       'Si es QuickBooks el que no tenía el saldo del prestamista, corrige la apertura: abierta, con la '
                                       'balanza corregida y fn_apertura con su motivo (la sustituye); cerrada, con un ajuste a la '
                                       'apertura (fn_postear con tipo ajuste_cpa, afecta_periodo «%s», la diferencia en la cuenta del '
                                       'préstamo contra 3900). Si falta registrar un préstamo que la apertura trae, regístralo '
                                       '(fn_prestamo_guardar); si un saldo_inicial está mal escrito, corrígelo (fn_prestamo_guardar con '
                                       'su id)', v_apl, v_apcta, v_si, v_corte - 1, abs(v_apl - v_si),
                                       case when v_apl > v_si then 'de más' else 'de menos' end,
                                       (select pa.periodo from periodos pa where pa.tipo = 'apertura' order by pa.desde limit 1))
                           when v_a <> v_b then format('el libro dice %s en las cuentas de los préstamos y sus saldos suman %s: '
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

  -- (Ronda 4) CADA CUENTA HASTA EL FIN DEL MES: solo con todo (p_vistas
  -- nulo: lo de antes de cerrar el mes, paso 5 del README) o pedido por su
  -- nombre; ninguna pantalla lo pide, así que no deja ninguna sin pintar,
  -- y cerrar el mes no lo mira (no frena nada: lo dice ANTES). Los meses
  -- del período ya terminados y sin cerrar (con 'hoy', todos los
  -- terminados desde el corte): de cada cuenta activa con archivos (sin los
  -- retirados) desde antes de su fin, que el último llegue a su último día
  -- (su «hasta», o su saldo_al si es después). Una tarjeta corta su
  -- statement a mitad de mes (la Blue el 7, la Gold el 22): lo de después
  -- llega con el siguiente y, si el mes se cierra antes, entra al mes
  -- siguiente como tardío. Antes nada lo decía.
  if p_vistas is null or 'cuadre: cada cuenta hasta el fin del mes' = any (v_solos) then
    select coalesce(array_agg(s.x order by s.d, s.cuenta), '{}'), count(*)
      into v_malos, v_cnt
      from (select format('%s (%s): sus archivos llegan al %s y %s terminó el %s%s', c.nombre, a.cuenta, a.hasta, p.periodo, p.hasta,
                          case when exists (select 1 from tarjetas t where t.cuenta = a.cuenta)
                               then ' (la tarjeta corta su statement antes: importa su actividad reciente en QFX hasta el fin de mes; '
                                    'el statement siguiente trae lo mismo y no se duplica)'
                               else '' end) as x,
                   p.desde as d, a.cuenta
              from periodos p
              join (select ab.cuenta, max(greatest(ab.hasta, ab.saldo_al)) as hasta,
                           min(coalesce(ab.desde, ab.hasta, ab.saldo_al)) as desde
                      from archivos_banco ab
                     where ab.retirado_el is null
                     group by ab.cuenta) a on a.hasta < p.hasta and a.desde <= p.hasta
              join cuentas c on c.codigo = a.cuenta and c.activa
             where p.tipo = 'mes' and p.estado = 'abierto' and p.desde >= v_corte and p.hasta < fn_fecha_miami(now())
               and (v_hoy or (p.desde >= v_desde and p.hasta <= v_hasta))
             limit 30) s;
    orden := 58; vista := 'cuadre: cada cuenta hasta el fin del mes'; filas := null; esperadas := null;
    ok := v_cnt = 0;
    detalle := case when not ok
                    then format('Antes de cerrar el mes, importa lo de cada cuenta hasta su último día: %s. Lo que falte entraría al mes '
                                'siguiente como tardío y el mes cerrado no lo tendría (v_banco_saldos: cubierto_hasta, '
                                'mes_sin_cubrir). No frena nada: cerrar el mes no lo mira.', array_to_string(v_malos, '; ')) end;
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
  -- (El nombre va partido —«fn_estados_huellas» || '()'—, y en las marcas de
  -- abajo igual: escrito con su paréntesis, la búsqueda de lo ajeno de c4
  -- tomaba esta función por una que llama a c4 y daba cuatro vueltas en
  -- cada pantalla de c4. Ronda 4.)
  select p.prosrc into v_c4sel from pg_proc p where p.oid = to_regprocedure('public.fn_estados_huellas' || '()');
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
  -- (Ronda 4b, lo mismo más barato —el control corre antes de pintar cada
  -- pantalla del banco—: el esquema se mira ANTES que el texto, en la misma
  -- fila de pg_proc —la unión con pg_namespace llegaba después y el texto
  -- de las 3.000 funciones del sistema pasaba por lower() y la expresión
  -- regular en cada vuelta—, y «está en la lista» se busca en una tabla
  -- hash —«not in (select unnest(…))», con las mismas respuestas que
  -- «= any (…)», nulos incluidos— en vez de recorrer la lista entera por
  -- cada función y cada dependencia. Con un año de banco, de 54 a 32 ms
  -- por llamada.)
  loop
    v_vuelta := v_vuelta + 1;
    select coalesce(array_agg(x.oid), '{}') into v_nuevas
      from (select f.oid, regexp_replace(regexp_replace(f.prosrc, '/\*.*?\*/', ' ', 'g'), '--[^\n]*', ' ', 'g') as src
              from pg_proc f
              join pg_namespace n on n.oid = f.pronamespace
             where n.nspname !~ '^pg_' and n.nspname <> 'information_schema'
               and f.prokind in ('f', 'p')
               and f.pronamespace in (select n2.oid from pg_namespace n2
                                       where n2.nspname !~ '^pg_' and n2.nspname <> 'information_schema')
               and f.oid not in (select unnest(v_lee)) and f.oid not in (select unnest(v_c2ok))
               and not exists (select 1 from pg_depend e
                                where e.classid = 'pg_proc'::regclass and e.objid = f.oid and e.deptype = 'e')
               and ((v_rx_pre is not null and lower(f.prosrc) ~ v_rx_pre)
                    or exists (select 1 from pg_depend d
                                where d.classid = 'pg_proc'::regclass and d.objid = f.oid
                                  and ((d.refclassid = 'pg_class'::regclass and d.refobjid in (select unnest(v_rel)))
                                       or (d.refclassid = 'pg_proc'::regclass and d.refobjid in (select unnest(v_lee))))))) x
     where (v_vuelta = 1 and v_rx_c is not null and x.src ~* v_rx_c)
        or (v_vuelta = 1 and v_rx_k is not null and x.src ~* v_rx_k)
        or (v_vuelta = 1 and v_rx_s is not null and regexp_replace(x.src, '''([^'']|'''')*''', ' ', 'g') ~* v_rx_s)
        or (v_rx_f is not null and x.src ~* v_rx_f)
        or exists (select 1 from pg_depend d
                    where d.classid = 'pg_proc'::regclass and d.objid = x.oid
                      and ((d.refclassid = 'pg_class'::regclass and d.refobjid in (select unnest(v_rel)))
                           or (d.refclassid = 'pg_proc'::regclass and d.refobjid in (select unnest(v_lee)))));
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
    from (select q0.fn || '()' as fn, q0.minimo, q0.archivo,
                 (select substring(pp.prosrc from '([0-9]{10})')::bigint
                    from pg_proc pp where pp.oid = to_regprocedure('public.' || q0.fn || '()')) as v
            from (values ('fn_libro_version', 2026100201::bigint, 'c2-libro.sql'),
                         ('fn_puente_version', 2026092601::bigint, 'c3-puentes.sql'),
                         ('fn_estados_version', 2026100201::bigint, 'c4-estados.sql')) as q0(fn, minimo, archivo)) q
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
-- Editor (no es de la API): los cuadres del control con todo (sin cuentas
-- pedidas: ronda 4d), y lo que el control no puede hacer sin las funciones
-- internas:
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
  v_lsal   numeric;
  v_lsal_al date;
  v_ndup   int;
  v_qmal   text;
  v_n59    bigint;
  v_ncri   bigint;
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
  -- (ronda 4d: el cuadre 59, «el otro lado de cada casado», en la revisión
  -- entera, con su referencia abajo. Y los cuadres del control, solo en la
  -- revisión entera: miran todo el banco, y con cuentas pedidas —«de una
  -- cuenta»— no decían nada de ellas y costaban lo mismo, un cuarto de
  -- segundo con un año de banco en cada llamada; c6-pruebas la llama nueve
  -- veces. Los mismos cuadres, cuando se quiera, en fn_banco_control.)
  if p_cuentas is null then
    for c in select x.vista, x.ok, x.filas, x.detalle
               from fn_banco_control('hoy', array['cuadre: un movimiento, un casado', 'cuadre: depósitos nunca a ingreso',
                                                  'cuadre: archivos intactos', 'cuadre: ningún ticket después de clasificar',
                                                  'cuadre: conciliaciones confirmadas', 'cuadre: préstamos', 'cuadre: prepagados',
                                                  'cuadre: el otro lado de cada casado']) x
              where x.vista like 'cuadre:%' loop
      if c.vista = 'cuadre: el otro lado de cada casado' then
        v_n59 := c.filas;
      end if;
      control := 'control · ' || c.vista; ok := c.ok; detalle := to_jsonb(coalesce(c.detalle, 'bien'));
      return next;
    end loop;
  end if;

  -- (Ronda 4d) EL CONTROL, con su referencia (fn_banco_criterio_casados: las
  -- funciones internas de EL CRITERIO): los casados vivos cuyo lado del
  -- banco y cuyo lado del libro se contradicen sin su motivo escrito (de las
  -- cuentas pedidas, o de todas); y, en la revisión entera, que la copia
  -- escrita en fn_banco_control (el cuadre de arriba) cuente lo mismo que
  -- ella: si un día no dicen lo mismo, una de las dos se quedó atrás y sale
  -- aquí. (Con cuentas pedidas, la referencia es solo de ellas: la de todo
  -- el banco tarda; c6-pruebas compara la copia en su prueba 154.)
  select coalesce(jsonb_agg(jsonb_build_object('movimiento', x.movimiento_id, 'casado', x.casado_id, 'cuenta', x.cuenta,
                                               'fecha', x.fecha, 'monto', x.monto, 'descripcion', x.descripcion, 'clase', x.clase,
                                               'regla', x.regla, 'contradice', x.contradice)
                            order by x.cuenta, x.fecha, x.movimiento_id), '[]'::jsonb),
         count(*)
    into v_malos, v_ncri
    from (select y.* from fn_banco_criterio_casados() y where p_cuentas is null
          union all
          select y.* from unnest(p_cuentas) as pc(cuenta) cross join lateral fn_banco_criterio_casados(pc.cuenta) y
           where p_cuentas is not null) x;
  if p_cuentas is not null then
    v_ncri := null;
  end if;
  control := 'el otro lado de cada casado';
  ok := jsonb_array_length(v_malos) = 0 and (p_cuentas is not null or v_ncri = coalesce(v_n59, -1));
  detalle := jsonb_build_object('casados', v_malos,
                                'nota', case when jsonb_array_length(v_malos) > 0
                                             then 'Lo que dice el banco del otro lado y lo que dice el libro se contradicen, sin su motivo: '
                                                  'si está mal casado, des-cásalo (fn_banco_descasar, con su motivo) y cásalo con lo '
                                                  'que es; si es correcto, escribe su motivo (fn_banco_casar_con con {"casado": …} y '
                                                  'el motivo). La conciliación de su mes no se confirma hasta entonces.' end,
                                'copia_del_control', case when p_cuentas is null and v_ncri is distinct from v_n59
                                                          then format('el cuadre 59 de fn_banco_control cuenta %s y la referencia %s: '
                                                                      'la copia escrita del control y las funciones de EL CRITERIO '
                                                                      'ya no dicen lo mismo (una se quedó atrás)',
                                                                      coalesce(v_n59::text, 'nada'), v_ncri) end);
  return next;
  v_malos := '[]'::jsonb;

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
  for c in select a.id, a.cuenta, a.nombre, a.formato, a.texto, a.sha256, a.filas_leidas, a.filas_fuera, a.saldo, a.saldo_al,
                  a.duplicados_posibles,
                  case when a.formato in ('ofx_sgml', 'ofx_xml') then 'archivo' else a.formato end as origen
             from archivos_banco a
            where p_cuentas is null or a.cuenta = any (p_cuentas)
            order by a.importado_el loop
    v_narch := v_narch + 1;
    begin
      v_leido := case when c.formato in ('ofx_sgml', 'ofx_xml') then fn_banco_ofx_leer(c.texto)
                      else fn_banco_lote_filas(c.texto::jsonb, c.formato) end;
      v_n := jsonb_array_length(coalesce(v_leido->'filas', '[]'::jsonb));
      -- (Ronda 4) EL SALDO que dice el archivo (el LEDGERBAL de un OFX: BALAMT
      -- y DTASOF; el de un lote, con su signo) contra el que se guardó: el que
      -- usan la conciliación y v_banco_saldos. Antes no se releía, y un saldo
      -- cambiado por fuera (con las guardas apagadas) no lo veía nadie.
      if c.formato in ('ofx_sgml', 'ofx_xml') then
        v_lsal := nullif(v_leido->>'saldo', '')::numeric;
        v_lsal_al := nullif(v_leido->>'saldo_al', '')::date;
      else
        v_lsal := case when c.formato = 'plaid'
                       then case when fn_banco_limpio(c.texto::jsonb->>'plaid_saldo') is not null
                                 then (case when fn_banco_tipo_cuenta(c.cuenta) = 'tarjeta' then -1 else 1 end)
                                      * fn_banco_saldo_texto(c.texto::jsonb->>'plaid_saldo', 'plaid_saldo') end
                       else fn_banco_saldo_texto(c.texto::jsonb->>'saldo', 'saldo') end;
        v_lsal_al := case when fn_banco_limpio(c.texto::jsonb->>'saldo_al') is not null
                          then fn_puente_fecha_texto(c.texto::jsonb->>'saldo_al', 'saldo_al') end;
      end if;
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
        -- (ronda 4: también su descripción normalizada, la que leen las
        -- reglas automáticas, la llave y los duplicados: cambiada por fuera,
        -- R3 casaba solo un pago a un proveedor como el de la tarjeta)
        select jsonb_build_object('fila', mv.fila, 'movimiento', mv.id,
                                  'que', case when f.n is null then 'su fila no está en el archivo'
                                              when (mv.fecha, mv.fecha_transaccion, mv.monto, mv.tipo_banco, mv.cheque, mv.descripcion,
                                                    mv.memo, mv.id_externo)
                                                   is distinct from (f.fecha, f.fu, f.monto, f.tipo, f.cheque, f.descripcion, f.memo, f.ext)
                                              then format('no es lo que dice el archivo: el movimiento dice %s %s «%s»; el archivo, %s %s «%s»',
                                                          mv.fecha, mv.monto, coalesce(mv.descripcion, ''), f.fecha, f.monto,
                                                          coalesce(f.descripcion, ''))
                                              when mv.desc_norm is distinct from f.dn
                                              then format('su descripción normalizada (la que leen las reglas) es «%s» y la del archivo, '
                                                          '«%s»: se cambió por fuera', mv.desc_norm, f.dn)
                                              else 'no da su sello' end) as x
          from mv left join f on f.n = mv.fila
         where f.n is null
            or (mv.fecha, mv.fecha_transaccion, mv.monto, mv.tipo_banco, mv.cheque, mv.descripcion, mv.memo, mv.id_externo, mv.desc_norm)
               is distinct from (f.fecha, f.fu, f.monto, f.tipo, f.cheque, f.descripcion, f.memo, f.ext, f.dn)
            or mv.sello is distinct from fn_banco_sello(mv.cuenta, mv.ultimos4, mv.fecha, mv.fecha_transaccion, mv.monto, mv.tipo_banco,
                                                        mv.cheque, mv.descripcion, mv.memo, mv.origen, mv.id_externo, mv.llave,
                                                        mv.archivo_id, mv.fila, c.sha256)
        union all
        -- Una fila sin movimiento suyo tuvo que ser REPETIDA, con las reglas
        -- del importador (ronda 4): por su id DE ESTE CAMINO, el movimiento
        -- con la misma fecha y descripción (en Plaid, su id manda) o el
        -- mismo cheque; sin id, la misma fecha y descripción, o el mismo
        -- cheque. Antes bastaba que su FITID apuntara a un movimiento del
        -- mismo monto: la otra compra que se perdía (otra descripción, el
        -- cheque cobrado otra vez) salía en verde.
        select jsonb_build_object('fila', f.n, 'que', 'la fila del archivo no está en ningún movimiento (¿se borró, o se dio por '
                                  'repetida sin serlo?)', 'fecha', f.fecha, 'monto', f.monto, 'descripcion', f.descripcion)
          from f
         where not exists (select 1 from mv where mv.fila = f.n)
           and not exists (select 1 from movimientos_banco m
                            where m.cuenta = c.cuenta and m.monto = f.monto
                              and ((f.ext is not null
                                    and exists (select 1 from movimientos_banco_ids i
                                                 where i.cuenta = c.cuenta and i.origen = c.origen and i.id_externo = f.ext
                                                   and i.movimiento_id = m.id)
                                    and ((m.fecha = f.fecha and (c.origen = 'plaid' or m.desc_norm = f.dn))
                                         or (f.cheque is not null and m.cheque is not null
                                             and ltrim(m.cheque, '0') = ltrim(f.cheque, '0') and abs(m.fecha - f.fecha) <= 5)))
                                   -- (el id que el banco reutilizó: el movimiento que ya entró con él, igual)
                                   or (f.ext is not null and m.origen = c.origen and m.id_externo = f.ext and m.fecha = f.fecha
                                       and (c.origen = 'plaid' or m.desc_norm = f.dn))
                                   or (f.ext is null and m.fecha = f.fecha and m.desc_norm = f.dn)
                                   -- (el mismo cheque sin id: no en una fila escrita a
                                   -- mano, que nunca se da por repetida por su cheque)
                                   or (f.ext is null and c.origen <> 'mano' and f.cheque is not null and m.cheque is not null
                                       and ltrim(m.cheque, '0') = ltrim(f.cheque, '0') and abs(m.fecha - f.fecha) <= 5))))
      select jsonb_agg(x.x) into v_dif from (select malos.x from malos limit 10) x;
      -- (Ronda 4) Cuántos entraron marcados «posible duplicado»: los que el
      -- archivo dice. Una marca borrada por fuera dejaba que una regla fija
      -- casara dos veces el mismo cargo, en verde.
      select count(*) into v_ndup from movimientos_banco m where m.archivo_id = c.id and m.posible_duplicado_de is not null;
      -- (Ronda 4) Y cada marca «quitada:<id>» que dejó este archivo la dice el
      -- archivo: su CORRECTACTION DELETE, o las «quitadas» del lote de Plaid.
      select string_agg(substr(i.id_externo, 9), ', ' order by i.id_externo) into v_qmal
        from movimientos_banco_ids i
       where i.archivo_id = c.id and i.id_externo like 'quitada:%'
         and not exists (select 1 from jsonb_array_elements(coalesce(v_leido->'borradas', '[]'::jsonb)) b
                          where b->>'corrige' = substr(i.id_externo, 9))
         and not exists (select 1
                           from jsonb_array_elements(case when c.formato not in ('ofx_sgml', 'ofx_xml')
                                                               and jsonb_typeof(c.texto::jsonb->'quitadas') = 'array'
                                                          then c.texto::jsonb->'quitadas' else '[]'::jsonb end) q
                          where fn_banco_limpio(q #>> '{}') = substr(i.id_externo, 9));
      if v_dif is not null or v_n <> c.filas_leidas - c.filas_fuera or v_ndup <> c.duplicados_posibles
         or v_lsal is distinct from c.saldo or v_lsal_al is distinct from c.saldo_al or v_qmal is not null then
        v_malos := v_malos || jsonb_strip_nulls(jsonb_build_object('archivo', coalesce(c.nombre, c.id::text), 'cuenta', c.cuenta,
                                                                   'dice', c.filas_leidas - c.filas_fuera, 'lee_hoy', v_n,
                                                                   'filas', v_dif,
                                                                   'quitadas', case when v_qmal is not null
                                                                                    then format('marca como quitados %s, y el archivo no '
                                                                                                'los quita: la marca se puso por fuera',
                                                                                                v_qmal) end,
                                                                   'posibles_duplicados',
                                                                   case when v_ndup <> c.duplicados_posibles
                                                                        then format('dice %s y hay %s marcados', c.duplicados_posibles,
                                                                                    v_ndup) end,
                                                                   'saldo', case when v_lsal is distinct from c.saldo
                                                                                      or v_lsal_al is distinct from c.saldo_al
                                                                                 then format('el archivo dice %s al %s y se guardó %s al %s',
                                                                                             coalesce(v_lsal::text, '(nada)'),
                                                                                             coalesce(v_lsal_al::text, '(sin fecha)'),
                                                                                             coalesce(c.saldo::text, '(nada)'),
                                                                                             coalesce(c.saldo_al::text, '(sin fecha)')) end));
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

  -- Los descriptores: expresiones regulares válidas y con su cuenta activa;
  -- y (ronda 4) cada uno es el de su último cambio en banco_historial (el
  -- que dejó fn_banco_descriptor, con quién y cuándo). Lo que leen las
  -- reglas automáticas (R3, R7) cambiado por fuera, con las guardas
  -- apagadas, no deja historial: antes nada lo veía y R3 casaba solo un
  -- pago a un proveedor como el de la tarjeta.
  v_malos := '[]'::jsonb;
  for c in select d.*, h.despues as ultimo
             from banco_descriptores d
             left join lateral (select x.despues from banco_historial x
                                 where x.tabla = 'banco_descriptores' and x.clave = d.clave
                                 order by x.cambiado_el desc limit 1) h on true loop
    begin
      perform '' ~* c.patron;
      if c.cuenta is not null and fn_puente_cuenta_mal(c.cuenta) is not null then
        v_malos := v_malos || jsonb_build_object('clave', c.clave, 'cuenta', fn_puente_cuenta_mal(c.cuenta));
      end if;
      if c.ultimo is null or (c.ultimo->>'patron') is distinct from c.patron or (c.ultimo->>'cuenta') is distinct from c.cuenta then
        v_malos := v_malos || jsonb_build_object('clave', c.clave, 'patron', c.patron, 'cuenta', c.cuenta,
                                                 'error', case when c.ultimo is null then 'no tiene su alta en banco_historial'
                                                               else format('su último cambio en banco_historial dice «%s» → %s: se cambió '
                                                                           'por fuera de fn_banco_descriptor (con las guardas apagadas). '
                                                                           'Vuelve a ponerlo con fn_banco_descriptor (queda el rastro)',
                                                                           c.ultimo->>'patron', coalesce(c.ultimo->>'cuenta', '(sin cuenta)'))
                                                          end);
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
comment on table public.banco_cuentas_personales   is 'c6: las cuentas PERSONALES de Edgar que él dio de alta a propósito (sus 4 últimos): el dinero que va y viene de ellas es patrimonio del accionista y sus botones entran sin motivo. Un número que no se conoce no es personal. Se da de alta y de baja (con su motivo) con fn_banco_cuenta_personal.';

comment on view public.v_papel_fases               is 'c6: el papel de los asientos del banco (movimiento, nómina del proveedor anterior, cuota, mes de prepagados), para v_asiento_papel de c4.';
comment on view public.v_banco_movimientos         is 'c6: cada movimiento con su estado, su regla, su asiento y su papel.';
comment on view public.v_banco_bandeja             is 'c6: lo pendiente, con su motivo, su propuesta en palabras y sus opciones (qué función llamar); y lo clasificado cuyo ticket llegó después (llego_su_ticket).';
comment on view public.v_banco_saldos              is 'c6: cada banco y tarjeta: saldo en libros, el último del banco, lo pendiente, su última conciliación y hasta dónde llegan sus archivos (el mes terminado y sin cerrar al que no llegan).';
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
comment on function public.fn_banco_cuenta_personal(text, text, boolean, text) is 'c6: da de alta una cuenta personal de Edgar por sus 4 últimos, o la da de baja con su motivo (SQL Editor). Solo con ella el dinero de o a esa cuenta va al patrimonio del accionista sin motivo.';
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
    ('tablas', (select count(*) = 14 from pg_class c
                 where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity
                   and c.relname in ('banco_historial', 'banco_descriptores', 'archivos_banco', 'movimientos_banco',
                                     'movimientos_banco_ids', 'banco_casados', 'banco_casado_lineas', 'conciliaciones',
                                     'conciliacion_partidas', 'prestamos', 'prestamo_cuotas', 'prepagados',
                                     'prepagados_amortizaciones', 'banco_cuentas_personales')
                   and (select count(*) from pg_policy po where po.polrelid = c.oid) = 1),
     '14 tablas, con la RLS encendida y solo su policy de lectura del dueño'),
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
