# Fase 1 · El plan de cuentas
**21–27 sep 2026 · 🔵 AZUL la estructura · 🟢 VERDE el SQL · ▶ reaccionas al borrador y decides los cost codes**

> Es el cimiento. Todo lo demás se apoya aquí, y cambiarlo en noviembre
> significa rehacer las fases 3, 4 y 9. Por eso va en azul y por eso va
> primero.

## Lo que tienes que hacer tú

**No lo dictes en blanco.** Abajo hay un borrador para un contratista
eléctrico de Florida. Léelo y dime tres cosas:

1. **Qué sobra** (cuentas que no vas a usar nunca).
2. **Qué falta** (algo que tú miras y aquí no está).
3. **La decisión de los cost codes** — abajo, es la importante.
4. **Pedir a la sesión de App Operativa, esta misma semana**, un `cost_code`
   opcional (null o `'mixto'` cuando el ticket mezcla) en `recibos`, `horas` y
   `materiales`, su selector en el teléfono y la columna en las vistas
   `*_equipo` — parche chico según `PUBLICAR.md`. **Sin eso la Fase 9 no tiene
   datos por código hasta 2027.**
5. **Confirmar con el CPA** si Max Power contrata como mejora a bien inmueble
   (decide el sales tax en los libros, §1 del plan), y si Gustavo cobra por
   W-2 o por 1099.

Reaccionar a un borrador toma veinte minutos. Dictarlo en blanco toma dos
horas. Por eso está escrito.

## LA decisión: los cost codes

Tus `01-DEMO … 20-MISC` ya viajan en el takeoff y viven en
`catalogo_items.codigo` y `alias_takeoff.codigo`. Hay dos formas de meterlos
en la contabilidad:

| | Cómo | Consecuencia |
|---|---|---|
| **A · subcuentas** | `5100-08-ROUGH`, `5100-06-FEED`… | 20 códigos × 9 cuentas de costo = **180 cuentas**. Es lo que hace QuickBooks y por eso los contratistas terminan con planes de cuentas ilegibles. |
| **B · dimensión** | El código es una **columna** en `asiento_lineas`, junto a `proyecto_id` | El plan queda en ~60 cuentas. Cortas por código, por obra, por los dos, o por ninguno. |

**Recomiendo B, con claridad.** Es lo que hacen los sistemas de construcción
de verdad, y es lo único que hace viable la Fase 9: comparar el costo real de
una receta contra lo que tu estimador dijo, sin un plan de cuentas de 180
renglones. Con A, la Fase 9 se vuelve impracticable.

**Tú decides.** Pero decídelo mañana, no en noviembre.

## Borrador del plan de cuentas

### 1000 · Activo
```
1010  Banco operativo                    ← Chase, la única cuenta (24-sep)
      (1020 nómina y 1030 reserva: no existen; salen de c1 y se añaden
       el día que se abran)
1110  Cuentas por cobrar
1120  Retención por cobrar               ← retainage; en QuickBooks es un parche
1130  Cuenta por cobrar al accionista    ← nota firmada e interés
1190  Provisión de incobrables
1200  Costo y utilidad en exceso de facturación   ← WIP sub-facturado (Fase 10)
1300  Material en bodega
1410  Seguros pagados por adelantado
1420  Fianzas
1510  Vehículos                          (por placa como etiqueta, no subcuentas)
1520  Herramienta y equipo
1530  Cómputo
1540  Mejoras al local
1590  Depreciación acumulada             (contra-activo)
1600  Depósitos
```

### 2000 · Pasivo
```
2010  Cuentas por pagar
2020  Retención por pagar a subcontratistas
2100  Tarjetas de crédito                (una subcuenta por tarjeta: Amex Gold y Amex Blue)
2210  Sueldos acumulados
2220  Impuestos de nómina retenidos      (941)
2230  Reempleo de Florida por pagar      (RT-6)
2240  Deducciones a empleados
2215  Vacaciones devengadas              (si se devenga PTO)
2300  Use tax por pagar                  ← compras sin impuesto de Florida y ventas al detalle; NUNCA desde un recibo que ya trae impuesto
2410  Provisión por pérdida en contratos
2400  Facturación en exceso de costo     ← WIP sobre-facturado (Fase 10)
2510  Línea de crédito
2520  Préstamos de vehículo — corriente
2530  Préstamos de vehículo — largo plazo
2900  Préstamo del accionista
```

### 3000 · Capital
```
3000  Capital social
3100  Aportaciones
3200  Distribuciones al accionista       ← S-corp
3900  Utilidades retenidas
```

### 4000 · Ingreso
```
4010  Contrato — residencial
4020  Contrato — comercial
4030  Servicio y T&M
4040  Órdenes de cambio
4900  Otros ingresos
```

### 5000 · Costo directo  *(aquí pega la decisión de cost codes)*
```
5000  Mano de obra directa
5010  Burden de mano de obra             ← impuestos patronales del journal + prima de WC amortizada desde 1410
5011  Burden aplicado a obra             (crédito)
5019  Variación de burden                (real contra aplicado, se cierra en f08)
5100  Material
5200  Subcontratos
5300  Equipo y renta
5400  Permisos e inspecciones
5500  Consumibles
5600  Flete
5900  Garantía y retrabajo
5950  Pérdida en contrato                ← contra 2410, provisión completa el mes que se detecta
```

### 6000 · Gasto general
```
6000  Sueldo administrativo
6010  Burden administrativo
6100  Renta
6110  Servicios
6120  Teléfono y datos
6200  Seguros — GL, auto, sombrilla      ← el GL nunca va también en el burden
6300  Vehículos — combustible y mantenimiento
6400  Herramienta menor y uniformes
6500  Oficina y software
6600  Profesionales — CPA y legal
6350  Comidas (50 %)
6360  Viajes y alojamiento
6610  Qualifier y licencia               ▶ W-2 o 1099
6700  Publicidad
6800  Licencias y cuotas
6900  Formación
6950  Depreciación                       ← desde activos_fijos (f08)
6980  Incobrables                        ← contra 1190
```

### 7000 · Otros
```
7100  Intereses
7200  Cargos bancarios y comisiones de tarjeta
7900  Otros gastos
9000  Impuestos y tasas de la EMPRESA    ← propiedad tangible (DR-405), annual report de Sunbiz.
      El impuesto sobre la renta de Edgar NO es gasto: va a 3200
```

## Lo que se construye

**🔵 Azul (`/effort max`):** la estructura final, la numeración y la jerarquía. La **DDL de
`cuentas`** (código inmutable, tipo, padre, saldo normal, activa, `nombre_en`
para el CPA, `etiqueta_fiscal` text — p. ej. `'M&E 50%'`, `'1099'`,
`'vehiculo'`). La tabla `cost_codes` con FK desde `asiento_lineas.cost_code`, y
las dimensiones (`proyecto_id`, `cost_code`, `co` text, `fase` opcional) si
eliges B.

Y el **bloque 0 de solo lectura** al principio de `c1`, que hay que correr
antes de decidir nada:

```sql
select table_name, column_name, data_type, numeric_precision, numeric_scale
  from information_schema.columns
 where table_schema='public'
   and table_name in ('facturas','recibos','horas','costos_equipo',
       'trabajos_externos','externos_equipo','hitos','finanzas_proyecto',
       'materiales','alcances')
 order by 1,2;
```
más `pg_policies` y las vistas que dependen de esas tablas
(`information_schema.view_column_usage`). **Las tablas fuente NO se alteran a
`numeric(14,2)`**: el repo guarda precios de 4 decimales; el redondeo a
centavos vive solo en `asiento_lineas.monto`.

**🟢 Verde (`/effort auto`):** solo los INSERT del plan y la carga de los 20 códigos desde
`catalogo_items.codigo`, en el mismo `docs/conta/c1-plan-de-cuentas.sql`.

## Se sabe que terminó cuando
- El SQL corrió en Supabase sin error.
- `select * from cuentas order by codigo` te enseña un plan que reconoces.
- La decisión de cost codes está escrita en `docs/CONTA-PLAN.md`.

## Desbloquea
Fase 2 (el libro) y, sobre todo, Fase 9 (estimado contra real).
