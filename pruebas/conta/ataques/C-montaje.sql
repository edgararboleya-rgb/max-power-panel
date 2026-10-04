-- [Pestaña 1] la apertura mínima, el número de la reserva dado de alta antes (lote vacío con confirmo_cuenta, el remedio del README)
-- y el de Chase reconocido por su QFX de octubre (sin movimientos que importen aquí)
select fn_postear('{"tipo": "apertura", "fecha": "2026-09-30", "descripcion": "Apertura (ataque C)", "lineas": [
  {"cuenta": "1010", "monto": "50000.00"}, {"cuenta": "3900", "monto": "-50000.00"}]}') ->> 'numero' as apertura;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "1097", "confirmo_cuenta": true, "nombre": "1030: su número ····1097", "filas": []}') -> 'avisos' as reserva;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1010", "ultimos4": "4392", "confirmo_cuenta": true, "nombre": "1010: su número ····4392", "filas": []}') -> 'avisos' as chase;

-- [Pestaña 2] 30-oct: Edgar se pasa 2,000.00 a su cuenta personal (····7781, SIN dar de alta). Chase de octubre.
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-oct-final.csv", "filas": [
  {"id": "C01", "fecha": "2026-10-30", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO CHK ...7781 TRANSACTION#: 301", "tipo": "XFER"}],
  "saldo": "48000.00", "saldo_al": "2026-10-31"}') ->> 'filas_nuevas' as chase_oct;
select fn_banco_casar_todo() -> 'por_motivo' as casar1;

-- [Pestaña 3] 1-nov: el pase de Chase a la reserva (2,000.00). Llega PRIMERO el estado de cuenta de la reserva (Chase de noviembre, después)
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "1097", "nombre": "reserva-nov.csv", "filas": [
  {"id": "R01", "fecha": "2026-11-01", "monto": "2000.00", "descripcion": "ONLINE TRANSFER FROM CHK ...4392 TRANSACTION#: 302", "tipo": "XFER"}],
  "saldo": "2000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as reserva_nov;
select fn_banco_casar_todo() -> 'por_regla' ->> 'transferencias' as r3_transferencias;
select m.cuenta, m.fecha, m.monto, m.descripcion, m.estado, m.casado_clase, m.casado_regla from movimientos_banco m order by m.fecha, m.cuenta;
select l.cuenta, l.monto, a.numero from asientos a join asiento_lineas l on l.asiento_id = a.id where a.origen_tabla = 'movimientos_banco' order by a.numero, l.orden;

-- [Pestaña 4] llega Chase de noviembre con el pase de verdad a la reserva (····1097)
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "chase-nov.csv", "filas": [
  {"id": "C02", "fecha": "2026-11-01", "monto": "-2000.00", "descripcion": "ONLINE TRANSFER TO SAV ...1097 TRANSACTION#: 302", "tipo": "XFER"}],
  "saldo": "46000.00", "saldo_al": "2026-11-30"}') ->> 'filas_nuevas' as chase_nov;
select fn_banco_casar_todo() -> 'por_motivo' as casar3;
