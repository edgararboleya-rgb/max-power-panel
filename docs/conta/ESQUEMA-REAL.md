# El esquema real de la base — lo que las fases de contabilidad tienen que respetar

**Leído el 23-sep-2026** directo de Supabase (proyecto `zeogjvwcmstmkwxjvykz`,
Postgres **17.6**), **solo metadatos, en modo lectura**: ni una fila de datos, y
nada escrito. Sustituye al «bloque 0» que la Fase 1 le pedía pegar a Edgar.

Si una sesión futura necesita el detalle de otra tabla, se vuelve a leer por
`information_schema` — nunca se adivina.

---

## Lo que esto corrige del plan

| El plan decía | La base real dice | Qué cambia |
|---|---|---|
| Crear una tabla `cost_codes` | **Ya existe `codigos_partida`** (`codigo`, `nombre`, `nombre_en`, `categoria`). El dueño la maneja; el equipo la lee (`using true`). | Se **reutiliza**. `asiento_lineas.cost_code` hace FK a `codigos_partida.codigo`. No se duplica. |
| `proyecto_id` como uuid | **`proyectos.id` es `text`** (y todas las `proyecto_id` que cuelgan de él) | Toda dimensión de obra en el libro es `text`. |
| Añadir `recibos.forma_pago` | **Ya existen** `metodo_pago`, `subtotal`, `tax`, `num_recibo`, `ultimos4`, `po_job`, `fecha`, `co`, `categoria`, `estado` | Se construye sobre `metodo_pago`. **Ojo:** esos campos **no los escribe `app.js`** — los llena la lectura del recibo en `cerebro`, que no vive en este repo. El puente tiene que aguantar ese ciclo sin verlo. |
| Añadir `recibos.llave_cliente` | `horas.llave_cliente` **ya existe**; en `recibos` no | Solo falta en `recibos`. |
| `impuesto_pagado` sí/no/desconocido | `recibos.tax` ya existe | Se deriva de `tax` (`null` = desconocido). |
| Retención solo en la factura | `estimados.retencion_pct` ya existe | El % pactado ya se captura al cotizar. |
| El tope de la IA en `asistente_costo_mes` | Es una **vista** sobre la tabla **`asistente_uso`** | La función `contador` escribe en `asistente_uso` con `accion = 'contador_*'`. |
| Habilitar `pg_cron` | **Disponible, no instalado** | ▶ Edgar lo habilita en la Fase 8 (Database → Extensions). |
| `sha256` con pgcrypto | `pgcrypto` está en el esquema **`extensions`**; `sha256(bytea)` es nativo desde PG 11 | Usar el nativo `sha256()`; no depende de extensiones. |
| — | `pg_net` está instalado en `public` | Los avisos al teléfono ya salen por aquí (`fn_cartero`). |

---

## Las dos funciones de permiso que se reutilizan

```sql
-- es_dueno(): STABLE, SECURITY DEFINER, search_path public, pg_temp
select exists (select 1 from perfiles
  where id = auth.uid() and rol = 'dueno' and coalesce(activo, true));

-- es_activo(): STABLE, SECURITY DEFINER, search_path public, pg_temp
select coalesce((select coalesce(activo, true) from perfiles where id = auth.uid()), false);
```

`perfiles`: `id uuid`, `nombre`, `rol text` (`'dueno'` o del equipo), `activo`,
`en_grupo`, `ultima_vista`.

---

## Regla nueva, obligatoria en todo `docs/conta/c*.sql`

En Supabase, **toda función nueva nace ejecutable por `anon` y `authenticated`**
a través de `/rest/v1/rpc/…`. El asesor de seguridad de este mismo proyecto ya
marca funciones así. Por eso cada función del libro lleva, justo después de
crearla:

```sql
revoke execute on function public.fn_x(...) from public, anon;
-- y también de authenticated, salvo las que la app llama a propósito:
revoke execute on function public.fn_x(...) from authenticated;
grant  execute on function public.fn_x(...) to authenticated;  -- solo si se llama desde conta.js
```

Y toda vista contable lleva `with (security_invoker = true)`. Las vistas
`*_equipo` que ya existen son SECURITY DEFINER (así las marca el asesor): **no
se copian como modelo**.

---

## Tablas que tocan los libros

## perfiles
- id: uuid NOT NULL
- nombre: text NOT NULL
- rol: text NOT NULL
- creado: timestamptz  default now()
- activo: bool  default true
- en_grupo: bool  default true
- ultima_vista: timestamptz
## proyectos
- id: text NOT NULL
- tipo: text NOT NULL
- nombre: text NOT NULL
- direccion: text
- cliente: text
- via: text
- estado: text NOT NULL
- fase: text
- estado_detalle: text
- proxima_accion: text
- ref: text
- horas_estimadas: numeric  default 0
- actualizado: timestamptz  default now()
- horas_reales_base: numeric  default 0
- portal_dinero: bool  default false
- portal_completo: bool  default false
- work_subtype: text
- estimado_ref: text
- qb_customer_id: text
- origen: text
- cliente_email: text
- cliente_tel: text
- puede_cancelar_hasta: date
- cierre_directo: bool
- portal_invitado_el: timestamptz
- contratista_id: text
- contratista_modo: text
- nto_enviado_el: timestamptz
- nto_nota: text
- contratista_contacto: text
- portal_resumen: text
- portal_resumen_en: text
## facturas
- id: int8 NOT NULL
- proyecto_id: text
- num: text NOT NULL
- fecha: date
- monto: numeric
- pagada: bool  default false
- hito_id: int8
- qb_id: text
- link_pago: text
- cobrada_el: timestamptz
- metodo_cobro: text
- cobrado: numeric(12,2)
- a_contratista: bool
## recibos
- id: int8 NOT NULL
- proyecto_id: text
- ruta: text
- total: numeric
- proveedor: text
- notas: text
- estado: text  default 'por_leer'::text
- autor_id: uuid
- creado: timestamptz  default now()
- co: text
- fecha: date
- categoria: text  default 'material'::text
- subtotal: numeric
- tax: numeric
- num_recibo: text
- metodo_pago: text
- ultimos4: text
- po_job: text
## horas
- id: int8 NOT NULL
- fecha: date NOT NULL
- usuario_id: uuid NOT NULL
- proyecto_id: text
- fase: text
- horas: numeric NOT NULL
- notas: text
- creado: timestamptz  default now()
- correccion_estado: text
- co: text
- llave_cliente: text
## materiales
- id: int8 NOT NULL
- proyecto_id: text
- descripcion: text NOT NULL
- cantidad: text
- estado: text  default 'falta'::text
- origen_pendiente: int8
- autor_id: uuid
- creado: timestamptz  default now()
- precio: numeric
- recibo_id: int8
## trabajos_externos
- id: int8 NOT NULL
- proyecto_id: text
- descripcion: text NOT NULL
- fecha: date
- tipo: text  default 'ajuste'::text
- horas: numeric
- costo: numeric NOT NULL
- creado: timestamptz  default now()
- externo_id: int8
## externos_equipo
- id: int8 NOT NULL
- nombre: text NOT NULL
- costo_hora: numeric NOT NULL  default 0
- activo: bool  default true
## costos_equipo
- usuario_id: uuid NOT NULL
- costo_hora: numeric NOT NULL
- actualizado: timestamptz  default now()
## hitos
- id: int8 NOT NULL
- proyecto_id: text
- titulo: text NOT NULL
- condicion: text
- monto: numeric
- estado: text
- orden: int4  default 0
- es_deposito: bool NOT NULL  default false
## finanzas_proyecto
- proyecto_id: text NOT NULL
- contrato: numeric
- cobrado: numeric  default 0
- presupuesto_materiales: numeric
## alcances
- id: int8 NOT NULL
- proyecto_id: text
- tipo: text
- titulo: text NOT NULL
- ref: text
- monto: numeric
- cobrado: numeric
- estado: text
- orden: int4  default 0
## codigos_partida
- codigo: text NOT NULL
- nombre: text NOT NULL
- nombre_en: text NOT NULL
- categoria: text NOT NULL
## contratistas
- id: text NOT NULL
- nombre: text NOT NULL
- contacto: text
- email: text
- telefono: text
- ve_dinero: bool NOT NULL  default true
- avisos: bool NOT NULL  default true
- activo: bool NOT NULL  default true
- notas: text
- invitado_el: timestamptz
- visto_el: timestamptz
- creado: timestamptz NOT NULL  default now()
## gastos_generales
- id: int8 NOT NULL
- concepto: text NOT NULL
- monto_mensual: numeric NOT NULL
## catalogo_items
- id: int8 NOT NULL
- seccion: text
- item: text NOT NULL
- unidad: text
- precio: numeric  default 0
- horas_unidad: numeric  default 0
- orden: int4  default 0
- codigo: text
- cero_motivo: text
- cero_revisado: date
- cero_nota: text
- precio_ref: numeric
- horas_ref: numeric
- fuente_ref: text
- ref_fecha: date
- precio_fecha: date
- precio_fuente: text
## escenarios
- id: text NOT NULL
- nombre: text
- foreman: numeric
- journeyman: numeric
- helper: numeric
- pct_foreman: numeric
- pct_journeyman: numeric
- pct_helper: numeric
- benefits: numeric
- tax_material: numeric
- overhead_hh: numeric
- profit: numeric
- mezcla: jsonb
- overhead_pct: numeric
- benefits_detalle: jsonb
## estimados
- id: int8 NOT NULL
- nombre: text NOT NULL
- cliente: text
- direccion: text
- tipo: text  default 'Residential'::text
- sqft: numeric
- factor: numeric  default 1
- escenario: text  default 'B'::text
- estado: text  default 'borrador'::text
- creado: timestamptz  default now()
- modo: text  default 'planos'::text
- cable: text  default 'romex'::text
- misc_pct: numeric
- tax_pct: numeric
- overhead_hh: numeric
- profit_pct: numeric
- markup_pct: numeric
- horas_directas: numeric
- lineas_material: jsonb
- benefits_pct: numeric
- mezcla: jsonb
- proyecto_id: text
- via: text
- contratista_id: text
- contratista_modo: text
- cliente_email: text
- cliente_tel: text
- contratista_contacto: text
- cero_notas: jsonb NOT NULL  default '{}'::jsonb
- no_incluye_extra: text
- empresa: text
- markup_cot_pct: numeric
- overhead_pct: numeric
- meses_obra: int4
- escalacion_pct: numeric
- resultado: text
- resultado_fecha: date
- resultado_motivo: text
- resultado_nota: text
- competencia: numeric
- bid_final: numeric
- horas_final: numeric
- material_final: numeric
- cerrado_en: timestamptz
- notas: text
- soporte: text
- pct_rack: numeric
- usa_luz_ref: bool  default false
- valida_dias: int4
- dueno: text
- retencion_pct: numeric
- adjuntos: jsonb
## asistente_uso
- id: int8 NOT NULL
- usuario_id: uuid
- rol: text
- modelo: text
- entrada: int4  default 0
- salida: int4  default 0
- vueltas: int4  default 1
- creado: timestamptz  default now()
- accion: text
- cache_lectura: int4  default 0
- cache_escritura: int4  default 0
- ms: int4
- resultado: text
- costo_centavos: int4
- letras: int4
- proyecto_id: text
## asistente_ajustes
- clave: text NOT NULL
- valor: text
## documentos_empresa
- id: int8 NOT NULL
- titulo: text NOT NULL
- titulo_en: text NOT NULL
- ruta: text
- url: text
- vence: date
- orden: int4 NOT NULL  default 0
## cobros_pendientes
- id: int8 NOT NULL  default nextval('cobros_pendientes_id_seq'::regclass)
- proyecto_id: text
- hito_id: int8
- motivo: text NOT NULL
- detalle: text
- resuelto: bool NOT NULL  default false
- resuelto_el: timestamptz
- creado: timestamptz NOT NULL  default now()
## qb_config
- id: int4 NOT NULL  default 1
- realm_id: text
- refresh_token: text
- actualizado: timestamptz  default now()
- oauth_state: text
- payments_activo: bool
## qb_llamadas
- id: int8 NOT NULL  default nextval('qb_llamadas_id_seq'::regclass)
- origen: text NOT NULL
- accion: text NOT NULL
- proyecto_id: text
- hito_id: int8
- documento_id: int8
- resultado: text
- detalle: text
- creado: timestamptz NOT NULL  default now()
## push_suscripciones
- id: int8 NOT NULL
- usuario_id: uuid
- endpoint: text NOT NULL
- p256dh: text NOT NULL
- auth: text NOT NULL
- creado: timestamptz  default now()
---

## Quién puede qué, hoy (RLS)

Todas las tablas de `public` tienen RLS activo.

| Tabla | Dueño | Equipo |
|---|---|---|
| `facturas`, `finanzas_proyecto`, `hitos`, `alcances`, `costos_equipo`, `externos_equipo`, `trabajos_externos`, `contratistas`, `gastos_generales`, `catalogo_items`, `escenarios`, `estimados` | todo | nada |
| `proyectos` | todo | nada directo; lee `proyectos_equipo` (sin montos) |
| `recibos` | leer, editar, borrar | **insertar** los suyos (`autor_id = auth.uid() and es_activo()`); lee `recibos_equipo` (sin montos) |
| `horas` | todo | insertar las suyas, leer (`es_activo()`), **editar las suyas** (vigilado por `fn_guarda_correccion`) |
| `materiales` | todo | insertar; lee `materiales_equipo` |
| `codigos_partida` | todo | **leer** |
| `perfiles` | insertar, editar | leer |
| Storage `fotos/recibos/%`, `docs/%`, `firmas/%` | todo | solo lo propio (`owner = auth.uid()`); **borrar: solo el dueño** |

---

## Triggers que ya existen y con los que el libro convive

### `facturas` — `trg_factura_cobrada` (BEFORE INSERT OR UPDATE)
```sql
-- fn_factura_cobrada(): sin search_path fijo
if new.pagada = true and (old.pagada is distinct from true)
   and coalesce(new.cobrado, 0) < new.monto then
  new.cobrado := new.monto;
end if;
if new.cobrado is null then
  new.cobrado := case when new.pagada then new.monto else 0 end;
end if;
```
Es el cobro de hoy: una casilla. **El puente de cobros de la Fase 3 no puede
pelearse con él**: o lo alimenta, o lo sustituye con fecha de corte.

### `recibos` — `trg_recibo_marca_material` (AFTER INSERT OR UPDATE)
Si el recibo tiene obra y notas y no está `anulado`, marca como `comprado` los
`materiales` en `falta` cuya descripción aparece en las notas. Si el recibo
pasa a `anulado`, los devuelve a `falta`.
**`anulado` es un estado que ya existe** y la app lo usa: contabilizar un recibo
tiene que decir qué pasa cuando después se anula (un reverso, no un borrado).

### `horas`
- `trg_guarda_correccion` (BEFORE UPDATE): el dueño edita libre; el equipo solo
  con permiso de un uso (`correccion_estado = 'aprobada'`).
- `trg_avisa_correccion`, `trg_avisar_horas` (AFTER): avisos al teléfono por
  `fn_cartero` → `net.http_post`.
- `trg_nto_horas` (AFTER INSERT): recordatorio del Notice to Owner.

### Otros
`proyectos` (llave de portal, NTO), `perfiles` (`trg_perfil_inactivo`),
`documentos` (`trg_co_firmado`: un Change Order firmado crea un pendiente
urgente de facturar el depósito).

---

## Hora de Miami

La base ya usa `(now() at time zone 'America/New_York')::date` en varios sitios.
`fn_fecha_miami()` de la Fase 2 sigue ese mismo patrón.
