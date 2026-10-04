\pset pager off
-- lo casado solo con un asiento escrito a mano (clase «asiento») cuyo banco dice otra cosa (EL CRITERIO con la otra cuenta del asiento)
select m.fecha, m.cuenta, m.monto, left(m.descripcion, 40) as descripcion, m.casado_regla,
       fn_banco_lados_linea(m, m.asiento_id)->>'contradice' as por_que
  from movimientos_banco m
 where m.estado in ('casado', 'en_transito') and m.casado_auto and m.casado_clase = 'asiento'
   and fn_banco_lados_linea(m, m.asiento_id)->>'contradice' is not null
 order by m.fecha;
-- todo lo casado solo con clase asiento, con su otro lado
select m.fecha, m.cuenta, m.monto, left(m.descripcion, 40) as descripcion, fn_banco_otro_lado(m)->>'clase' as otro_lado,
       fn_banco_lados_linea(m, m.asiento_id) as lados
  from movimientos_banco m where m.casado_clase = 'asiento' order by m.fecha;
