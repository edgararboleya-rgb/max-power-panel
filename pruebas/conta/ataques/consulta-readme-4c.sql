select m.id, m.fecha, m.cuenta, m.monto, m.descripcion, m.casado_clase, m.casado_regla,
       coalesce(fn_banco_lados_linea(m, m.asiento_id)->>'contradice',
                'el banco dice que viene de tu cuenta ' || (fn_banco_otro_lado(m)->>'cuenta')) as por_que
  from movimientos_banco m
 where m.estado = 'casado' and m.casado_auto
   and ((m.casado_clase = 'transferencia' and fn_banco_lados_linea(m, m.asiento_id)->>'contradice' is not null)
        or (m.casado_clase = 'cobro' and fn_banco_otro_lado(m)->>'clase' = 'propia'))
 order by m.fecha;
