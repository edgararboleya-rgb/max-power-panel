# Fase 11 · El puente de nómina
**30 nov – 6 dic · 🔵 AZUL el asiento real de la corrida · 🟢 VERDE la plomería · ▶ CONTRATADO YA (trámite desde la semana 5)**

> ⚠️ **El trámite arrancó en la semana 5** (ver f06). Última nómina en el
> proveedor viejo con **fecha de pago ≤ 31-dic**; primera en Gusto con **fecha
> de pago ≥ 4-ene** (el 1 de enero es viernes festivo y no corre ACH). Los W-2
> y el 941 del Q4 de 2026 los emite quien llevó la nómina en 2026: **no cortar
> ese acceso hasta tenerlos.**

## Tú
1. **Gusto contratado**, llaves y el **export del diario de nómina (CSV)**.
2. Resumen o empleado por empleado.
3. Aprobar las horas del período desde la app: **el lote aprobado es el que va
   a Gusto y al libro**.

## Lo que la app NO hace, y no se discute
No calcula retenciones, no deposita en EFTPS, no presenta 941, 940, W-2 ni
RT-6. Eso lo hace el proveedor. Si retienes y no depositas a tiempo existe la
Trust Fund Recovery Penalty, que atraviesa la corporación y te la cobran a ti
personalmente. Ningún ahorro de software vale eso.

## 🔵 Azul — se crea (`/effort max`)
El modelo de la corrida —`nomina_corridas`, `nomina_reparto`— y **el asiento
real**: Dr 5000 bruto por obra según horas aprobadas del período (el reparto se
diseñó en f09), Dr 5010 impuestos patronales **reales del journal**
prorrateados por horas, Cr 2220/2230/1010 (y 2215 si se devenga PTO). La prima
de WC: Dr 1410 al pagar, amortización mensual Dr 5010 / Cr 1410, ajuste de
auditoría anual a 5010. **GL solo en 6200.** Nunca una lectura de `escenarios`.

**Este journal es la ÚNICA fuente de dólares de 5000/5010**; el devengo de
horas de f03, si existe, ya se reversó el día 1.

## 🟢 Verde — se trabaja encima (`/effort auto`)
La plomería: lector del export del diario del proveedor, igual que el
importador de banco (**la API es opcional: el archivo nunca falla**); el
reparto por horas aprobadas; el cierre de la variación de burden a 5019 en f08;
corrida de prueba con las llaves demo.

## Entregable
`docs/conta/c11-nomina.sql` · el lector del diario

## Terminó cuando
Una corrida de prueba entra sola al libro desde el diario, repartida sobre las
obras correctas con su burden real, y **el journal, el 941 y el RT-6 amarran
contra 5000/5010/2220/2230**.
