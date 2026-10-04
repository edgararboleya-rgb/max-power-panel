-- harness.sql: pulsa cada botón SIN pide_motivo de la bandeja, tal cual, en una subtransacción deshecha, y mira
--   (a) si falla (un botón que no declara pide_motivo y su función lo rechaza),
--   (b) si deja una línea al patrimonio del accionista sin motivo y sin cuenta personal dada de alta,
--   (c) si pone en rojo un cuadre de fn_banco_control(mes del movimiento) que no estaba en rojo antes.
create or replace function pg_temp.atq_pulsar(o jsonb, p_periodo text, p_base text[]) returns jsonb
language plpgsql set search_path = public, pg_temp as $$
declare
  a jsonb := coalesce(o->'args', '{}'::jsonb);
  v_est text; v_pat text; v_rojo text; v_antes uuid[];
begin
  select coalesce(array_agg(id), '{}') into v_antes from asientos;
  begin
    case o->>'llamar'
      when 'fn_banco_clasificar' then perform fn_banco_clasificar((a->>'p_movimiento')::uuid, a->'p_lineas', a->>'p_motivo');
      when 'fn_banco_casar_con' then perform fn_banco_casar_con((a->>'p_movimiento')::uuid, a->'p_con', a->>'p_motivo');
      when 'fn_banco_cobrar' then perform fn_banco_cobrar((a->>'p_movimiento')::uuid, a->'p_aplicaciones', a->>'p_notas');
      when 'fn_banco_transferencia' then perform fn_banco_transferencia((a->>'p_movimiento')::uuid, a->>'p_cuenta', a->>'p_motivo');
      when 'fn_banco_devolver' then perform fn_banco_devolver((a->>'p_movimiento')::uuid, (a->>'p_cobro')::uuid, a->>'p_motivo');
      when 'fn_banco_pagar_proveedor' then perform fn_banco_pagar_proveedor((a->>'p_movimiento')::uuid, (a->>'p_proveedor')::uuid, a->'p_partidas');
      when 'fn_banco_duplicado' then perform fn_banco_duplicado((a->>'p_movimiento')::uuid, (a->>'p_es_el_mismo')::boolean, a->>'p_motivo');
      when 'fn_banco_ignorar' then perform fn_banco_ignorar((a->>'p_movimiento')::uuid, a->>'p_motivo');
      when 'fn_banco_descasar' then perform fn_banco_descasar((a->>'p_movimiento')::uuid, a->>'p_motivo');
      when 'fn_prestamo_cuota' then perform fn_prestamo_cuota((a->>'p_prestamo')::uuid, (a->>'p_movimiento')::uuid, (a->>'p_fecha')::date,
                                                               a->>'p_monto', a->>'p_capital', a->>'p_interes', a->>'p_motivo');
      else v_est := 'sin_llamar:' || coalesce(o->>'llamar', '-');
    end case;
    select string_agg(format('%s %s (%s)', l.cuenta, l.monto, coalesce(x.procedencia->>'cuenta_personal', 'sin personal')), ', ')
      into v_pat
      from asientos x join asiento_lineas l on l.asiento_id = x.id
     where not (x.id = any (v_antes)) and fn_banco_es_accionista(l.cuenta)
       and coalesce(btrim(x.procedencia->>'motivo_edgar'), '') = '';
    select string_agg(c.orden || ' ' || c.vista || ': ' || left(coalesce(c.detalle, ''), 220), ' | ' order by c.orden)
      into v_rojo
      from fn_banco_control(p_periodo) c
     where not c.ok and not (c.vista = any (p_base));
    raise exception using errcode = 'MXT02';
  exception
    when sqlstate 'MXT02' then v_est := coalesce(v_est, 'ok');
    when others then v_est := sqlstate || ': ' || left(sqlerrm, 250);
  end;
  return jsonb_strip_nulls(jsonb_build_object('estado', v_est, 'patrimonio_sin_motivo', v_pat, 'rojo_nuevo', v_rojo));
end $$;

create or replace function pg_temp.atq_barrer() returns table (fecha date, cuenta text, monto numeric, descripcion text, motivo text,
                                                               n int, boton text, resultado jsonb)
language plpgsql set search_path = public, pg_temp as $$
declare
  b record; o record; v_base text[]; v_per text;
begin
  for b in select * from v_banco_bandeja order by fecha, cuenta, monto loop
    v_per := to_char(b.fecha, 'YYYY-MM');
    select coalesce(array_agg(c.vista), '{}') into v_base from fn_banco_control(v_per) c where not c.ok;
    for o in select x.o, x.n from jsonb_array_elements(coalesce(b.opciones, '[]'::jsonb)) with ordinality as x(o, n)
              where not coalesce((x.o->>'pide_motivo')::boolean, false) loop
      fecha := b.fecha; cuenta := b.cuenta; monto := b.monto; descripcion := b.descripcion; motivo := b.motivo;
      n := o.n; boton := o.o->>'texto';
      resultado := pg_temp.atq_pulsar(o.o, v_per, v_base);
      return next;
    end loop;
  end loop;
end $$;

-- lo que la bandeja ofrece, entero (los que piden motivo con «(pm)»)
create or replace function pg_temp.atq_bandeja() returns table (fecha date, cuenta text, monto numeric, descripcion text, motivo text, botones text)
language sql set search_path = public, pg_temp as $$
  select b.fecha, b.cuenta, b.monto, b.descripcion, b.motivo,
         (select string_agg(x.n || '. ' || (x.o->>'texto') || case when coalesce((x.o->>'pide_motivo')::boolean, false) then ' (pm)' else '' end
                            || ' [' || (x.o->>'llamar') || ']', E'\n' order by x.n)
            from jsonb_array_elements(coalesce(b.opciones, '[]'::jsonb)) with ordinality as x(o, n))
    from v_banco_bandeja b order by b.fecha, b.cuenta, b.monto
$$;
