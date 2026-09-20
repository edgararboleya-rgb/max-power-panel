# Fase 1 · El plan de cuentas
**21–27 sep 2026 · 🔵 AZUL (Fable 5.1) · ▶ la dictas tú**

> Es el cimiento. Todo lo demás se apoya aquí, y cambiarlo en noviembre
> significa rehacer las fases 3, 4 y 9. Por eso va en azul y por eso va
> primero.

## Lo que tienes que hacer tú

**No lo dictes en blanco.** Abajo hay un borrador para un contratista
eléctrico de Florida. Léelo y dime tres cosas:

1. **Qué sobra** (cuentas que no vas a usar nunca).
2. **Qué falta** (algo que tú miras y aquí no está).
3. **La decisión de los cost codes** — abajo, es la importante.

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
1010  Banco operativo
1020  Banco de nómina                    (si quieres separarlo)
1030  Reserva de impuestos
1110  Cuentas por cobrar
1120  Retención por cobrar               ← retainage; en QuickBooks es un parche
1190  Provisión de incobrables
1200  Costo y utilidad en exceso de facturación   ← WIP sub-facturado (Fase 10)
1300  Material en bodega
1410  Seguros pagados por adelantado
1420  Fianzas
1510  Vehículos
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
2100  Tarjetas de crédito                (una subcuenta por tarjeta)
2210  Sueldos acumulados
2220  Impuestos de nómina retenidos      (941)
2230  Reempleo de Florida por pagar      (RT-6)
2240  Deducciones a empleados
2300  Sales / use tax por pagar
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
5010  Burden de mano de obra             ← sale de tu benefits_detalle
5100  Material
5200  Subcontratos
5300  Equipo y renta
5400  Permisos e inspecciones
5500  Consumibles
5600  Flete
5900  Garantía y retrabajo
```

### 6000 · Gasto general
```
6000  Sueldo administrativo
6010  Burden administrativo
6100  Renta
6110  Servicios
6200  Seguros — GL, auto, sombrilla
6300  Vehículos — combustible y mantenimiento
6400  Herramienta menor y uniformes
6500  Oficina y software
6600  Profesionales — CPA y legal
6700  Publicidad
6800  Licencias y cuotas
6900  Formación
6950  Depreciación
```

### 7000 · Otros
```
7100  Intereses
7200  Cargos bancarios y comisiones de tarjeta
7900  Otros gastos
9000  Impuestos
```

## Lo que se construye
- 🔵 **Fable:** la estructura final, la numeración, la jerarquía, y las tres
  columnas de dimensión en `asiento_lineas` (`proyecto_id`, `cost_code`,
  `fase`) si eliges B.
- 🟢 **Opus:** `docs/conta/c1-plan-de-cuentas.sql`, numerado, comentado y
  idempotente, listo para pegar.

## Se sabe que terminó cuando
- El SQL corrió en Supabase sin error.
- `select * from cuentas order by codigo` te enseña un plan que reconoces.
- La decisión de cost codes está escrita en `docs/CONTA-PLAN.md`.

## Desbloquea
Fase 2 (el libro) y, sobre todo, Fase 9 (estimado contra real).
