# pruebas/conta/nomina — archivos de nómina DE MENTIRA (c15)

Nada de aquí es de nadie: los nombres son inventados («ZZ…»), los montos
también (cuadran al centavo entre sí) y no hay ningún Seguro Social, cuenta
de banco, dirección, correo ni teléfono. Sirven para probar a mano la
pantalla de Contabilidad → Nómina y los usa `pruebas/conta/c15-concurrencia.sh`.

| archivo | qué es |
|---|---|
| `zz-payroll-journal.csv` | Un «Payroll journal» como se supone que lo baja Gusto: preámbulo, una fila por persona, una fila de totales. Tres personas (dos de campo y un oficial), una nómina regular: período 3 al 16 de enero de 2027, día de pago 22 de enero. Bruto 5,808.00 · retenido 947.32 · deducciones 50.00 · neto 4,810.68 · reembolsos 64.25 · patronal 635.99. Es el mismo journal de `docs/conta/c15-pruebas.sql` (allí con las fechas del mes de las pruebas). |
| `zz-payroll-journal-secciones.csv` | La misma idea en la otra forma posible: el resumen por empleado y, en otra sección con su cabecera, el detalle de lo patronal; nombres como «Apellido, Nombre»; importes con `$` y comas. Dos personas. |
| `zz-payroll-journal-bono.csv` | Un bono fuera de ciclo del mismo día de pago, de una persona. |
| `zz-payroll-journal-correccion.csv` | Una corrección de Gusto que DEVUELVE: una nómina fuera de ciclo del mismo día de pago con los importes en negativo (a una persona se le había pagado 100.00 de más: bruto −100.00, retenido −17.65, neto −82.35, patronal −10.95), con su columna de horas en cero. Entra como el mismo asiento al revés y lo que deja queda «a favor» en cada cuenta. Lo usa `c15-concurrencia.sh` (escena 9). |
| `zz-payroll-journal-total-en-el-nombre.csv` | Otra forma del archivo: las columnas de lo patronal van delante, hay títulos sueltos de una o dos celdas entre las filas, y la fila de totales lleva su rótulo («Totals») en la columna del nombre. Dos personas, bruto 3,408.00; la fila de totales es un control, no una persona. |
| `zz-horas-para-gusto.csv` | Cómo sale el CSV de «las horas para Gusto» (lo arma la base; aquí, de muestra). |

Los rótulos de las columnas son los del motor de informes de Gusto tal como
se averiguaron sin tener todavía un archivo real: se confirman con el primer
«Payroll journal» de verdad (enero de 2027). Si Gusto usa otros, se le dice
a la pantalla qué es cada columna (queda en el mapeo) y no hay que tocar nada
más.
