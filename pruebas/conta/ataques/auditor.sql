-- auditor.sql (final-4c): EL CRITERIO mirado DESPUÉS, sobre lo que quedó guardado.
--   pg_temp.atq_auditar(p_antes): cada casado vivo de clase transferencia (y los que no están en p_antes, si se dice), con
--   sus dos lados y lo que dice fn_banco_lados de ellos (o fn_banco_lados_linea si el otro lado todavía no llegó):
--   MAL si es automático y no «solas», o si no es automático, se contradicen y nadie escribió motivo.
create or replace function pg_temp.atq_auditar(p_antes uuid[] default null)
returns table (cuenta text, fecha date, monto numeric, descripcion text, regla text, auto boolean, motivo text, otro text,
               contradice text, solas boolean, veredicto text)
language plpgsql set search_path = public, pg_temp as $$
declare
  r record; m movimientos_banco; m2 movimientos_banco; l jsonb; v_mot text;
begin
  for r in select bc.* , a.procedencia from banco_casados bc join asientos a on a.id = bc.asiento_id
            where bc.deshecho_el is null and bc.clase = 'transferencia' and (p_antes is null or not (bc.id = any (p_antes)))
            order by bc.casado_el, bc.id loop
    select * into m from movimientos_banco where id = r.movimiento_id;
    m2 := null;
    select x.* into m2
      from banco_casado_lineas cl join banco_casados b2 on b2.id = cl.casado_id and b2.deshecho_el is null
      join movimientos_banco x on x.id = b2.movimiento_id
     where cl.vigente and cl.asiento_id = r.asiento_id and cl.cuenta <> m.cuenta and b2.movimiento_id <> m.id
     limit 1;
    if m2.id is not null then
      l := fn_banco_lados(fn_banco_otro_lado(m), m.cuenta, fn_banco_otro_lado(m2), m2.cuenta);
      otro := format('%s %s %s «%s»', m2.cuenta, m2.fecha, m2.monto, coalesce(m2.descripcion, ''));
    else
      l := fn_banco_lados_linea(m, r.asiento_id);
      otro := 'en tránsito: ' || coalesce((select string_agg(x.cuenta, ',') from asiento_lineas x where x.asiento_id = r.asiento_id and x.cuenta <> m.cuenta), '?');
    end if;
    v_mot := coalesce(nullif(btrim(r.motivo), ''), nullif(btrim(r.procedencia->>'motivo_edgar'), ''));
    cuenta := m.cuenta; fecha := m.fecha; monto := m.monto; descripcion := m.descripcion; regla := r.regla; auto := r.automatico;
    motivo := v_mot; contradice := l->>'contradice'; solas := (l->>'solas')::boolean;
    veredicto := case when r.automatico and not coalesce(solas, false) then 'MAL: automático sin «solas»'
                      when not r.automatico and contradice is not null and v_mot is null then 'MAL: se contradicen y sin motivo'
                      else 'bien' end;
    return next;
  end loop;
end $$;
-- el patrimonio del accionista sin motivo y sin una personal dada de alta, en TODO lo del banco
create or replace function pg_temp.atq_patrimonio()
returns table (numero text, fecha date, cuenta text, monto numeric, descripcion text, procedencia jsonb)
language sql set search_path = public, pg_temp as $$
  select a.numero::text, a.fecha_contable, l.cuenta, l.monto, a.descripcion, a.procedencia
    from asientos a join asiento_lineas l on l.asiento_id = a.id
   where a.origen_tabla = 'movimientos_banco' and fn_banco_es_accionista(l.cuenta)
     and coalesce(btrim(a.procedencia->>'motivo_edgar'), '') = '' and a.procedencia->>'cuenta_personal' is null
     and not exists (select 1 from asientos r where r.reversa_a = a.id)
   order by a.fecha_contable, a.numero
$$;
