-- =====================================================================
-- 02b-restricciones-produccion.sql — lo que producción tiene y el banco no
-- tenía. Leído de producción el 24-sep (pg_constraint e
-- information_schema.columns, solo lectura), después de que c3-pruebas.sql
-- fallara allá por esto mismo:
--   · las id de 13 tablas son GENERATED ALWAYS (el banco las tenía BY
--     DEFAULT): un insert con id escrito da 428C9 sin OVERRIDING SYSTEM
--     VALUE;
--   · los CHECK de valores: recibos solo admite 7 categorías y 5 formas de
--     pago; horas entre 0 y 16; estados, fases y tipos con su lista;
--   · el UNIQUE (proyecto_id, num) de facturas y las llaves foráneas.
-- No trae lo que pone c3 (facturas_estado_valido, facturas_retencion_valida,
-- horas_aprobacion_completa, contabilizado_en, proveedor_id): eso lo crea
-- c3-puentes.sql. Se carga después de 02-semilla.sql (correr.sh lo hace
-- solo): los datos de la semilla tienen que cumplirlo, como en producción.
-- =====================================================================

-- Identidades: GENERATED ALWAYS, como en producción.
alter table public.alcances alter column id set generated always;
alter table public.asistente_uso alter column id set generated always;
alter table public.catalogo_items alter column id set generated always;
alter table public.estimados alter column id set generated always;
alter table public.externos_equipo alter column id set generated always;
alter table public.facturas alter column id set generated always;
alter table public.gastos_generales alter column id set generated always;
alter table public.hitos alter column id set generated always;
alter table public.horas alter column id set generated always;
alter table public.materiales alter column id set generated always;
alter table public.pendientes alter column id set generated always;
alter table public.recibos alter column id set generated always;
alter table public.trabajos_externos alter column id set generated always;

-- CHECK de valores.
alter table public.catalogo_items add constraint catalogo_items_cero_motivo_chk CHECK (((cero_motivo IS NULL) OR (cero_motivo = ANY (ARRAY['suministro'::text, 'by_owner'::text, 'solo_labor'::text, 'falta_precio'::text, 'tarifa'::text]))));
alter table public.estimados add constraint estimados_cable_check CHECK ((cable = ANY (ARRAY['romex'::text, 'mc'::text, 'mixto'::text])));
alter table public.estimados add constraint estimados_contratista_modo_check CHECK (((contratista_modo IS NULL) OR (contratista_modo = ANY (ARRAY['referido'::text, 'contrato'::text]))));
alter table public.estimados add constraint estimados_empresa_chk CHECK (((empresa IS NULL) OR (empresa = 'mep'::text)));
alter table public.estimados add constraint estimados_estado_check CHECK ((estado = ANY (ARRAY['borrador'::text, 'congelado'::text, 'convertido'::text])));
alter table public.estimados add constraint estimados_modo_check CHECK ((modo = ANY (ARRAY['planos'::text, 'rapido'::text, 'remodelacion'::text, 'servicio'::text])));
alter table public.estimados add constraint estimados_res_motivo_chk CHECK (((resultado_motivo IS NULL) OR (resultado_motivo = ANY (ARRAY['precio'::text, 'plazo'::text, 'alcance'::text, 'relacion'::text, 'no_califico'::text, 'otro'::text]))));
alter table public.estimados add constraint estimados_resultado_chk CHECK (((resultado IS NULL) OR (resultado = ANY (ARRAY['ganado'::text, 'perdido'::text, 'sin_respuesta'::text, 'descartado'::text]))));
alter table public.estimados add constraint estimados_retencion_pct_check CHECK (((retencion_pct IS NULL) OR ((retencion_pct >= (0)::numeric) AND (retencion_pct <= 0.2))));
alter table public.estimados add constraint estimados_valida_dias_check CHECK (((valida_dias IS NULL) OR ((valida_dias >= 1) AND (valida_dias <= 365))));
alter table public.hitos add constraint hitos_estado_check CHECK ((estado = ANY (ARRAY['cobrado'::text, 'facturado'::text, 'pendiente'::text])));
alter table public.horas add constraint horas_correccion_estado_check CHECK ((correccion_estado = ANY (ARRAY['pedida'::text, 'aprobada'::text])));
alter table public.horas add constraint horas_horas_check CHECK (((horas > (0)::numeric) AND (horas <= (16)::numeric)));
alter table public.materiales add constraint materiales_estado_check CHECK ((estado = ANY (ARRAY['falta'::text, 'comprado'::text])));
alter table public.pendientes add constraint pendientes_prioridad_check CHECK ((prioridad = ANY (ARRAY['urgente'::text, 'normal'::text, 'espera'::text])));
alter table public.perfiles add constraint perfiles_rol_check CHECK ((rol = ANY (ARRAY['dueno'::text, 'campo'::text, 'license'::text])));
alter table public.proyectos add constraint proyectos_contratista_modo_ck CHECK (((contratista_modo IS NULL) OR (contratista_modo = ANY (ARRAY['contrato'::text, 'referido'::text]))));
alter table public.proyectos add constraint proyectos_contratista_par_ck CHECK (((contratista_id IS NULL) OR (contratista_modo IS NOT NULL)));
alter table public.proyectos add constraint proyectos_estado_check CHECK ((estado = ANY (ARRAY['estimando'::text, 'enviado'::text, 'aprobado'::text, 'ejecucion'::text, 'pausa'::text, 'completado'::text, 'no_aprobado'::text])));
alter table public.proyectos add constraint proyectos_fase_check CHECK ((fase = ANY (ARRAY['mobilizacion'::text, 'rough'::text, 'insp-rough'::text, 'trim'::text, 'insp-final'::text])));
alter table public.proyectos add constraint proyectos_tipo_check CHECK ((tipo = ANY (ARRAY['comercial'::text, 'residencial'::text, 'servicio'::text])));
alter table public.proyectos add constraint proyectos_work_subtype_chk CHECK (((work_subtype IS NULL) OR (work_subtype = ANY (ARRAY['new_construction'::text, 'remodel'::text, 'service_call'::text]))));
alter table public.recibos add constraint recibos_categoria_check CHECK (((categoria IS NULL) OR (categoria = ANY (ARRAY['material'::text, 'labor_externo'::text, 'permiso'::text, 'herramienta'::text, 'combustible'::text, 'renta_equipo'::text, 'otro'::text]))));
alter table public.recibos add constraint recibos_estado_check CHECK ((estado = ANY (ARRAY['por_leer'::text, 'leido'::text, 'conciliado'::text, 'sin_foto'::text, 'anulado'::text])));
alter table public.recibos add constraint recibos_metodo_pago_check CHECK (((metodo_pago IS NULL) OR (metodo_pago = ANY (ARRAY['debito'::text, 'credito'::text, 'cuenta_proveedor'::text, 'efectivo'::text, 'zelle'::text]))));
alter table public.trabajos_externos add constraint trabajos_externos_tipo_check CHECK ((tipo = ANY (ARRAY['horas'::text, 'ajuste'::text])));

-- UNIQUE.
alter table public.facturas add constraint facturas_proyecto_id_num_key UNIQUE (proyecto_id, num);

-- Llaves foráneas.
alter table public.alcances add constraint alcances_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE;
alter table public.asistente_uso add constraint asistente_uso_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES perfiles(id);
alter table public.costos_equipo add constraint costos_equipo_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES perfiles(id) ON DELETE CASCADE;
alter table public.estimados add constraint estimados_contratista_id_fkey FOREIGN KEY (contratista_id) REFERENCES contratistas(id);
alter table public.estimados add constraint estimados_escenario_fkey FOREIGN KEY (escenario) REFERENCES escenarios(id);
alter table public.estimados add constraint estimados_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE SET NULL;
alter table public.facturas add constraint facturas_hito_id_fkey FOREIGN KEY (hito_id) REFERENCES hitos(id) ON DELETE SET NULL;
alter table public.facturas add constraint facturas_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE;
alter table public.finanzas_proyecto add constraint finanzas_proyecto_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE;
alter table public.hitos add constraint hitos_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE;
alter table public.horas add constraint horas_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE;
alter table public.horas add constraint horas_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES perfiles(id);
alter table public.materiales add constraint materiales_autor_id_fkey FOREIGN KEY (autor_id) REFERENCES perfiles(id);
alter table public.materiales add constraint materiales_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE;
alter table public.materiales add constraint materiales_recibo_id_fkey FOREIGN KEY (recibo_id) REFERENCES recibos(id) ON DELETE SET NULL;
alter table public.pendientes add constraint pendientes_autor_id_fkey FOREIGN KEY (autor_id) REFERENCES perfiles(id);
alter table public.pendientes add constraint pendientes_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE;
alter table public.pendientes add constraint pendientes_resuelto_por_fkey FOREIGN KEY (resuelto_por) REFERENCES perfiles(id);
alter table public.perfiles add constraint perfiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.proyectos add constraint proyectos_contratista_id_fkey FOREIGN KEY (contratista_id) REFERENCES contratistas(id) ON DELETE SET NULL;
alter table public.recibos add constraint recibos_autor_id_fkey FOREIGN KEY (autor_id) REFERENCES perfiles(id);
alter table public.recibos add constraint recibos_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE;
alter table public.trabajos_externos add constraint trabajos_externos_externo_id_fkey FOREIGN KEY (externo_id) REFERENCES externos_equipo(id);
alter table public.trabajos_externos add constraint trabajos_externos_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE;
