# Fase 12 · Cédula de corte, W-9, COI y 1099
**12a · 23 – 29 nov (semana corta) · 12b · 7 – 13 dic**
**🔵 AZUL la cédula y el criterio del 1099 · 🟢 VERDE campos, reporte y cuadre · ▶ W-9 y COI; balanza al 30-nov**

> La apertura única ya está cargada al 30-sep (f04). Aquí se comprueba que cada
> saldo del balance **tiene su auxiliar debajo**, y se deja el 1099 apuntando a
> donde toca.

## Tú

1. **Semana 10:** juntar el **W-9 (TIN, dirección, tipo de entidad) y el
   certificado de seguro (COI) de cada sub.** Siempre falta alguno — por eso en
   noviembre y no en enero, cuando ya no contestan el teléfono.
2. **Semana 10:** decidir con el CPA el método libro de depreciación, si
   Gustavo cobra por W-2 o 1099, y qué ayudante por hora es empleado y no sub
   (F.S. 440.10). Los ayudantes por hora van por Gusto desde el 1-ene.
3. **Semana 12:** la **balanza de QuickBooks al 30-nov** y los statements de
   noviembre. Aporta o valida el desglose por obra abierta (QuickBooks no lo
   trae): retención y costo acumulado.
4. **Decisión:** el **1099 de 2026 sale de QuickBooks** —es el libro de ese
   año—, cruzado contra `trabajos_externos`, y se presenta antes del
   **1-feb-2027**. La app produce el de 2027 en enero de 2028.

## 🔵 Azul — se crea (`/effort max`) *(chico)*

- **La cédula de corte:** qué auxiliar sostiene cada saldo de balance y de
  dónde sale — CxC por factura con retención por obra; tickets abiertos por
  proveedor (statement de cada supply); saldo de cada tarjeta por statement;
  cada préstamo por carta, partido corriente/largo plazo; seguros prepagados
  (póliza, meses que faltan); nómina devengada del último período **partida en
  dos años**; WIP por obra (`wip_schedule`); activos fijos con costo y
  depreciación acumulada de la cédula del CPA 2025 + altas 2026. **Cada
  auxiliar cuadra contra su cuenta o se explica.**
- **El criterio del pago reportable:** base caja; umbral en
  `conta_config('umbral_1099', 2000)` confirmado cada diciembre con el CPA; se
  excluye lo pagado con tarjeta (lo reporta el procesador) y a corporaciones;
  cuentan los asientos pagados desde 1010/1020.

## 🟢 Verde — se trabaja encima (`/effort auto`)

- Campos en `proveedores` / `externos_equipo` —**nunca en `contratistas`, que
  son los GC clientes**—: `tin` (solo dueño por RLS), `direccion`,
  `tipo_entidad`, `w9_ruta`, `w9_recibido_el`, `coi_vence`, `coi_ruta`,
  `wc_exento`. Chip «vence en N días» como el de `documentos_empresa`.
- Reporte 1099 diseñado y probado con datos parciales; e-file por IRIS o
  Track1099 en enero de 2028.
- Carga de `activos_fijos`.
- **Semana 12:** cuadre del app contra la balanza de QuickBooks al 30-nov con
  la vista de comparación de f04, y la cédula de corte cargada y cuadrada,
  saldo por saldo.

## Entregable
`docs/conta/c12-cedula.sql` · reporte de 1099

## Terminó cuando
Cada saldo del balance al 30-nov tiene su auxiliar debajo y cuadra; el app
amarra contra QuickBooks al 30-nov salvo diferencias de criterio escritas; el
reporte te dice a quién le falta el W-9 o el COI; y está escrito que **el 1099
de 2026 sale de QuickBooks**.
