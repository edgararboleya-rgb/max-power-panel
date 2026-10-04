\pset format aligned
\pset pager off
select m.id_externo, m.fecha, m.monto, m.estado, m.casado_regla, bc.motivo, bc.automatico
  from movimientos_banco m left join banco_casados bc on bc.id = m.casado_id order by m.fecha;
-- el QFX de la reserva trae el MISMO movimiento con su nombre entero: viene de la cuenta PERSONAL de Edgar (····7781)
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-oct-m10.csv", "filas": [
  {"id": "Q10", "fecha": "2026-10-15", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...7781 TRANSACTION#: 5", "tipo": "XFER"}],
  "saldo": "2000.00", "saldo_al": "2026-10-31"}') -> 'duplicados_posibles' as dup;
select fn_banco_casar_todo() -> 'por_motivo' as casar3;
select * from pg_temp.atq_bandeja();
-- «Es el mismo» sin motivo
select fn_banco_duplicado((select id from movimientos_banco where id_externo = 'Q10'), true) ->> 'estado' as es_el_mismo;
select 'REF' as k, * from fn_banco_criterio_casados();
select orden, vista, filas, ok, left(detalle, 300) from fn_banco_control('2026-10', array['cuadre: el otro lado de cada casado']);
select m.id_externo, fn_banco_criterio_casado(m.casado_id) - 'libro' as criterio from movimientos_banco m where m.id_externo = 'PL-M10';
