\pset format aligned
\pset pager off
-- ¿la partida en tránsito de la apertura (un cheque de un cliente) casó SOLA con el dinero que llega de la cuenta personal de Edgar?
select m.id_externo, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla, m.casado_auto from movimientos_banco m where m.fecha >= '2026-10-01' order by m.fecha;
select * from pg_temp.atq_bandeja();
