\pset format aligned
\pset pager off
\echo '== M: fn_banco_cuenta_personal con números de la empresa'
select fn_banco_cuenta_personal('4392', 'no es mía') as alta_4392;
select fn_banco_cuenta_personal('2013', 'no es mía') as alta_2013;
select fn_banco_cuenta_personal('1234') as alta_sin_nombre;
select fn_banco_cuenta_personal('77', 'corto') as alta_corta;
select fn_banco_cuenta_personal('...7781', 'Chase personal de Edgar') - 'creado_el' as alta_7781;
select fn_banco_cuenta_personal('7781', null, false) as baja_sin_motivo;
\echo '== N: el estado de cuenta de la personal no entra (OFX, lote y confirmo_cuenta)'
select fn_banco_importar_filas('{"origen": "plaid", "ultimos4": "7781", "nombre": "plaid personal", "filas": [{"id": "p1", "fecha": "2026-11-02", "plaid_monto": "10.00", "descripcion": "X"}]}') ->> 'cuenta' as plaid_personal;
select fn_banco_importar_filas('{"origen": "mano", "cuenta": "1030", "ultimos4": "7781", "confirmo_cuenta": true, "nombre": "1030 con la personal", "filas": []}') ->> 'cuenta' as confirmar_personal_como_1030;
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1030", "ultimos4": "7781", "nombre": "1030 csv con la personal", "filas": [{"fecha": "2026-11-02", "monto": "10.00", "descripcion": "X"}]}') ->> 'cuenta' as csv_1030_personal;
select fn_banco_importar_ofx($ofx$OFXHEADER:100
DATA:OFXSGML
VERSION:102

<OFX><BANKMSGSRSV1><STMTTRNRS><TRNUID>1<STATUS><CODE>0<SEVERITY>INFO</STATUS><STMTRS><CURDEF>USD<BANKACCTFROM><BANKID>267084131<ACCTID>000000748917781<ACCTTYPE>CHECKING</BANKACCTFROM><BANKTRANLIST><DTSTART>20261101<DTEND>20261103
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20261102<TRNAMT>-8.10<FITID>X1<NAME>PUBLIX</STMTTRN>
</BANKTRANLIST><LEDGERBAL><BALAMT>100.00<DTASOF>20261103</LEDGERBAL></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>
$ofx$, '1030', 'personal.qfx') ->> 'cuenta' as ofx_personal_a_1030;
\echo '== J: fn_banco_nomina con una línea al patrimonio, sin motivo'
select fn_banco_importar_filas('{"origen": "csv", "cuenta": "1010", "nombre": "nomina.csv", "filas": [{"id": "N1", "fecha": "2026-11-06", "monto": "-1000.00", "descripcion": "ADP PAYROLL"}]}') ->> 'filas_nuevas' as nomina;
select fn_banco_nomina((select id from movimientos_banco where id_externo = 'N1'), '[{"cuenta": "5000", "monto": "800.00", "proyecto_id": "casa-perez-k3m9"}, {"cuenta": "3200", "monto": "200.00"}]') ->> 'estado' as nomina_3200_sin_motivo;
\echo '== K: un préstamo en el patrimonio'
select fn_prestamo_guardar('{"prestamista": "Edgar", "descripcion": "x", "principal": "1000.00", "tasa_anual": "0", "cuota": "100.00", "primer_pago": "2026-11-15", "dia_pago": 15, "plazo_meses": 10, "cuenta": "1130"}') ->> 'prestamista' as prestamo_1130;
select fn_prestamo_guardar('{"prestamista": "Edgar", "descripcion": "x", "principal": "1000.00", "tasa_anual": "0", "cuota": "100.00", "primer_pago": "2026-11-15", "dia_pago": 15, "plazo_meses": 10, "cuenta": "3100"}') ->> 'prestamista' as prestamo_3100;
\echo '== L: un descriptor al patrimonio'
select fn_banco_descriptor('cargo_banco', null, '3200') as descriptor_3200;
select fn_banco_descriptor('interes', null, '3100') as descriptor_3100;
\echo '== P: la tabla nueva, por fuera de su función'
insert into banco_cuentas_personales (ultimos4, nombre, activa) values ('5512', 'por fuera', true);
update banco_cuentas_personales set activa = false;
delete from banco_cuentas_personales;
select ultimos4, nombre, activa from banco_cuentas_personales;
\echo '== O: permisos'
select p.proname, p.prosecdef, has_function_privilege('authenticated', p.oid, 'execute') as auth, has_function_privilege('anon', p.oid, 'execute') as anon,
       has_function_privilege('service_role', p.oid, 'execute') as srv, p.proconfig
  from pg_proc p where p.proname in ('fn_banco_cuenta_personal', 'fn_banco_otro_lado', 'fn_banco_otra_tarjeta', 'fn_banco_personal_de',
                                     'fn_banco_dudosa', 'fn_banco_es_accionista', 'fn_banco_deposito_explicado', 'fn_banco_opciones_principio')
 order by 1;
select c.relname, c.relrowsecurity, c.relforcerowsecurity, has_table_privilege('anon', c.oid, 'select') as anon_sel,
       has_table_privilege('authenticated', c.oid, 'select') as auth_sel, has_table_privilege('authenticated', c.oid, 'insert') as auth_ins,
       (select string_agg(pol.polname || ':' || pol.polcmd || ':' || pg_get_expr(pol.polqual, pol.polrelid), '; ') from pg_policy pol where pol.polrelid = c.oid) as policies
  from pg_class c where c.relname = 'banco_cuentas_personales';
select tgname from pg_trigger where tgrelid = 'banco_cuentas_personales'::regclass and not tgisinternal;
select tabla, clave, accion, left(coalesce(despues::text, ''), 120) from banco_historial where tabla = 'banco_cuentas_personales';
