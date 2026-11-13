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
`docs/conta/c15-nomina.sql` + `docs/conta/c15-pruebas.sql` (el nombre
`c11` ya lo usaba la facturación) · la página «Nómina» de Contabilidad · el
cierre (c9) con las filas 180 a 183 · `pruebas/conta/c15-concurrencia.sh` y
los archivos de muestra de `pruebas/conta/nomina/` (todo «ZZ…», de mentira).

## Terminó cuando
Una corrida de prueba entra sola al libro desde el diario, repartida sobre las
obras correctas con su burden real, y **el journal, el 941 y el RT-6 amarran
contra 5000/5010/2220/2230**.

## Decisión del 26-oct
Gusto contratado (plan Simple, cada dos semanas, primera nómina el viernes
8-ene-2027). Gusto no da su API a una app privada de un solo cliente: el
puente de esta fase es **por archivo** (el «Payroll journal» en CSV que Edgar
descarga después de cada nómina y sube a la app), con las horas por obra que
ya lleva la app para repartir el costo y Plaid para casar el cargo de Gusto en
Chase. En primavera de 2027, con la nómina estable, se pide a Gusto el acceso
de socio para que el asiento entre solo; correr la nómina dentro de la app
(Check u otro proveedor embebido) queda descartado para el arranque.

## Lo que cambió al construirla (manda sobre lo de arriba)
- **Las cuentas del asiento.** Cr 2210 (el neto), 2220 (lo retenido y lo del
  patrón para el 941), 2225 (el FUTA, 940), 2230 (el reempleo de Florida,
  RT-6) y 2240 (las deducciones); 2250 los reembolsos. **No hay «Cr 1010» el
  día de pago**: Gusto saca el dinero antes y en varios cargos (NET, TAX, REM,
  CSD; la cuota mensual, FEE, aparte), y cada cargo se casa después con lo que
  su nómina dejó por pagar.
- **5010 nunca directo del journal ni de 1410** (lo manda c1/c3): los
  impuestos patronales y la prima de WC van a la bolsa 5015, y la bolsa se
  reparte a las obras (5010 por obra) por las horas que la nómina pagó. La
  prima de WC sigue entrando por los prepagados del banco (c6), no a mano.
- **El amarre** con 941, 940 y RT-6 es por los créditos a 2220, 2225 y 2230,
  por día de pago, con tolerancia de centavos: esas declaraciones cuentan a
  todos los empleados (5000, 5001, 6000, 6005), no solo a la obra.
- **El formato del CSV de Gusto no está comprobado con un archivo real.** El
  lector va por nombre de columna con un mapeo que Edgar amplía desde la
  pantalla; una columna con cifras que no conoce frena la nómina en vez de
  perderse. Se confirma con el primer archivo (enero de 2027).
- La frase de arriba sobre los W-2 y el 941 del Q4 de 2026 no aplica (lo dice
  CONTA-PLAN): en 2026 no hubo nómina con proveedor.

## Lo construido (13-nov)
- **c15-nomina.sql** (15 tablas, 7 vistas, 63 funciones `fn_nomina_*`; se
  pega dos veces sin daño; sale una tabla de 9 filas):
  - **El archivo.** La pantalla lee el CSV en el teléfono y manda solo las
    celdas como texto; lo delicado (SSN, banco, dirección, teléfono, correo,
    nacimiento) se quita antes de salir y la base lo vuelve a quitar. El
    archivo no se guarda: solo su nombre, su sha256 y su tamaño. Antes de
    guardar hay un ensayo que dice qué entendió.
  - **Cuadra al centavo o no se postea**: por persona (bruto − retenido −
    deducciones = neto; neto + reembolsos = cheque) y contra la fila de
    totales, que es control y nunca se suma.
  - **No entra dos veces**: por su llave de Gusto o, sin ella, por sus
    personas y sus cifras (la misma nómina bajada de otra forma, sin fechas
    o con otro día). Dos nóminas iguales de verdad entran solo con su porqué
    escrito.
  - **El asiento** en el día de pago (la fecha fiscal), el sueldo de cada
    persona repartido por obra según sus horas aprobadas del período (campo
    5000, oficial 5001 en obra y 6005 lo demás, oficina 6000); un bono o una
    corrección no se quedan con las horas.
  - **Los cargos de Gusto** del banco se casan con lo que la nómina dejó por
    pagar (también lo que quedó a favor tras una corrección, y lo pagado por
    fuera de Gusto con su nota). Des-casar en la Bandeja se refleja aquí.
  - **La bolsa del burden** se reparte al terminar el mes a las obras, por las
    horas que la nómina pagó ese mes.
  - **El amarre** 941 / 940 / RT-6 por trimestre, con lo que Edgar teclea de
    lo que presentó Gusto.
  - **Las horas para Gusto**: el lote aprobado en CSV, con las extra por
    semana laboral (más de 40, cada semana sola).
  - **Seguridad**: solo el dueño; lo de cada persona (corridas, pagos,
    personas) solo con el código del teléfono. Sin el código la página dice
    «entra con tu código», no «no hay nóminas». El cierre y su ronda al
    teléfono no llevan nombres ni sueldos.
- **c15-pruebas.sql**: 52 pruebas (la 35 sale «omitida» si c9 no trae el
  bloque). No dejan nada. Con una nómina de muestra «ZZ…» viva, casi todas
  salen «omitida» y lo dicen: no se suben los archivos de muestra a
  producción.
- **El cierre (c9)**: filas 180 (cada cargo de Gusto del mes casado; detiene),
  181 (cada nómina con día de pago en el mes, posteada; detiene), 182 (sus
  cuadres; detiene) y 183 (sus avisos; avisa).
- **La página «Nómina»**: Nóminas, Cargos de Gusto, Personas, Horas para
  Gusto, 941 · 940 · RT-6 y Ajustes (el mapeo de columnas, la cuenta de las
  horas sin obra, la semana laboral y la bolsa del burden).
- **Cómo se probó** (en el banco de pruebas, nunca en producción): Fable en la
  base, en la revisión contra el dinero y la seguridad, sus arreglos y la
  revisión final; Opus 5.5 en la pantalla y en la verificación desde cero.
  Encontraron y quedó arreglado, entre otras cosas: un archivo con el resumen
  y el detalle con la misma cabecera que se sumaba dos veces; el mismo
  archivo sin fechas subido con otro día que entraba como otra nómina; un
  cargo des-casado en la Bandeja que dejaba su pago «aplicado»; lo de cada
  persona visible sin el código; nombres y sueldos en la ronda del cierre;
  la prima de WC que se quedaba en la bolsa. Todas las suites (c2 a c15) en
  verde desde cero y sobre la plantilla, dos veces; la concurrencia (10
  escenas) en verde; con una nómina de verdad dentro, c15 52 de 52.

## Lo que queda (Fase 11b, antes de la primera nómina del 8-ene)
Lo que la nómina necesita de capas ya selladas. Ninguno mueve dinero hoy (no
hay nóminas); cada uno se abre con su revisión:
- **c10 · Costo por obra**: cuenta «a estándar» las horas que ya pagó una
  nómina. Mientras, **no fijar el burden estándar** en Costo por obra (con
  nómina contaría la mano de obra dos veces). Lo mismo el control 170 de c12.
- **c4 / c6 · los papeles**: la vista de los papeles no conoce la nómina; con
  una nómina en el libro la prueba 25 de c4 falla (los controles de verdad no
  se ponen en rojo). La página de Estados ya lee el papel de la nómina.
- **c13 · la cédula**: 2210 a 2240 no leen todavía el auxiliar de la nómina
  (`fn_nomina_auxiliar`): saldrán «no cuadra» o «sin auxiliar».
- **c3 · el devengo**: un mes con nómina no se devenga; el corte ya existe
  (`fn_nomina_cola`).
- **c6 · textos** que todavía dicen «espera el journal (f11)»: el cargo de
  Gusto se casa desde Nómina → Cargos de Gusto.

## ▶ Pendientes
- **Edgar, antes del 4-ene**: bajar de Gusto un «Payroll journal» en CSV
  (aunque salga vacío) y la plantilla de «Import payroll data», para fijar
  las columnas; decir qué día empieza la semana laboral en Gusto; cada
  empleado con el mismo nombre que en la app; la cuenta de las horas sin
  obra (Nómina → Ajustes). La primera nómina se corre a más tardar el lunes
  4-ene a las 7 pm.
- **Gusto (soporte)**: si el plan Simple deja elegir columnas del journal;
  cuándo se retira el journal viejo; cómo sale el reempleo de Florida; cómo
  cobra una corrección (descuenta del siguiente cargo o devuelve).
- **CPA**: la cuenta de las horas sin obra; la regla del oficial (80 h por
  período; 5001 en obra, 6005 lo demás) y su sueldo razonable; si lo del
  patrón por oficina y oficial va a 6010; lo trabajado y no pagado al cierre
  del año; la clave y la frecuencia del reparto de la bolsa y si se cierra la
  variación a 5019; sección 125 y 401(k) en el 940 y el RT-6; horas extra y
  Fla. Stat. 448.01; 2553 / S-corp y el seguro médico del accionista (6006);
  reembolsos por nómina (plan con rendición de cuentas); quien pasa de 1099 a
  W-2 en 2027.

