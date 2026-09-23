# Fase 4 · Los estados financieros y la apertura
**12 – 18 oct · 🔵 AZUL el mapeo, la comparación y el esqueleto de `conta.js` · 🟢 VERDE vistas y apertura · ▶ TÚ AUDITAS LA APERTURA**

> La primera prueba de verdad del proyecto — y ahora es cruzable.

## Tú

1. **Para el viernes 9-oct:** que el contador tenga **septiembre cerrado en
   QuickBooks**; la balanza al 30-sep en PDF y CSV; los statements de
   septiembre de cada supply, tarjeta y préstamo; la lista de facturas
   abiertas con su retención por obra (la app la tiene).
2. **Auditar la apertura contra la balanza de QuickBooks, cuenta por cuenta.**
   Si no amarra, no se pasa a la Fase 5. Esto no se negocia. Las diferencias de
   criterio (retención partida a 1120, lo que QuickBooks no modela) quedan
   escritas en la tabla de diferencias.

## 🔵 Azul — se crea (`/effort max`)

El mapeo del mayor a los estados (signos, contra-activos, arrastre: 3900 = 3900
de apertura + resultados de ejercicios cerrados; 3200 de ejercicios cerrados se
pliega a 3900 o se muestra aparte, según el CPA), con etiquetas ES/EN.

**La vista de comparación contra QuickBooks** (balanza importada contra balanza
del app, por cuenta y, si Edgar lleva Customer:Job, por obra) y **la tabla de
diferencias** con clasificación puente/mapeo/criterio y campo de explicación:
las reusan f08, f12, f13-14 y el cierre de enero. Más la vista «auxiliar por
obra = mayor» (5xxx).

Y **el esqueleto de `js/conta.js`** con el patrón de falla ruidosa:
`fn_estado(periodo)` como fila de control; si `cuadra = false` o `filas = 0`
donde el período tiene asientos, la pantalla se niega a pintar y dice cuál.

## 🟢 Verde — se trabaja encima (`/effort auto`)

`c4-estados.sql` como vistas; balanza, comparativos mes contra mes, el clic de
cualquier cifra hasta el asiento.

**La carga del asiento de apertura al 30-sep**: balance únicamente (los
resultados enero–septiembre de 2026 son de QuickBooks), documento = la balanza
en PDF, con dimensión donde hay cédula; 15xx y 1590 como totales hasta que
exista `activos_fijos` (f08); las partidas en tránsito al 30-sep como
conciliación de apertura (f06).

## Entregable
`docs/conta/c4-estados.sql` — todo como vistas. Postgres hace la matemática.

## Terminó cuando

1. Con asientos sintéticos: balanza en cero, activo = pasivo + capital +
   resultado del ejercicio, y un descuadre no entra.
2. El asiento de apertura **cuadra contra la balanza de QuickBooks al 30-sep**
   cuenta por cuenta, con las diferencias de criterio escritas.
3. Las cuentas que alimentan los puentes (4xxx desde `facturas`, 5100 desde
   `recibos`, 5200 desde `trabajos_externos`) del 1 al 15 de octubre suman lo
   mismo en el libro que en las tablas origen, SQL contra SQL.
4. El clic de cualquier cifra llega al asiento.

> La «misma utilidad que QuickBooks» se prueba en la **Fase 8** con octubre
> completo; la auditoría entera, en las Fases 13–14. En la semana 4 todavía no
> hay banco, ni nómina, ni categorización: pedirla aquí era una puerta que
> nadie podía cruzar.
