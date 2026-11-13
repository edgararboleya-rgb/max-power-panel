# Lo que hay que pegar (13-nov · v304)

Esta lista **sustituye a la del 12-nov** (`PEGAR-12NOV.md`): trae lo mismo
y además la nómina (c15) y el tablero de la portada (c16). Si ya pegaste algo
de la del 12-nov, no pasa nada: todo se puede pegar dos veces.

En Supabase → SQL Editor. Cada archivo se copia **entero**, se pega en una
consulta nueva y se le da a **Run**. Al final cada uno enseña una tabla:
mira que tenga las filas que dice aquí.

Antes de empezar:
- Cierra la pestaña de Contabilidad de la app.
- Si puedes, hazlo a una hora en que la cuadrilla no esté subiendo fotos.
- Si sale un error que diga **«lock timeout» (55P03)**, no pasó nada: espera
  un minuto y pega el mismo archivo otra vez.
- **Nunca escribas un TIN en el SQL Editor.** El TIN va en la app, en la
  ficha del sub, con el código del teléfono.

## A. Las capas, en este orden

| # | Archivo | Filas que salen |
|---|---|---|
| 1 | `docs/conta/c11-emision.sql` (otra vez: trae el arreglo de las facturas anuladas) | 12 |
| 2 | `docs/conta/c13-cedula.sql` (nuevo: la cédula de corte) | 8 |
| 3 | `docs/conta/c14-subs.sql` (nuevo: W-9, COI y 1099) | 9 |
| 4 | `docs/conta/c15-nomina.sql` (nuevo: la nómina con Gusto) | 9 |
| 5 | `docs/conta/c9-cierre.sql` (otra vez: trae las filas 160, 178, 179 y 180 a 183) | 12 |
| 6 | `docs/conta/c16-tablero.sql` (nuevo: el tablero de la portada; solo lee, no guarda nada) | 6 |

- En la de c14, la fila «qué falta» dirá que hay que confirmar el umbral del
  1099 con el CPA y dar de alta las fichas. Es lo esperado.
- En la de c15, la fila «control» tiene que decir «0 de 5 cuadres en rojo ·
  0 de 14 avisos». La fila «qué falta» dirá que falta la cuenta de las horas
  sin obra y el primer «Payroll journal» de Gusto. Es lo esperado.
- En la de c16, «una pasada del tablero» tiene que decir «15 tarjetas: 15
  contestan, 0 dicen que su capa no está, 0 fallan» y «qué falta», «nada».

## B. Las pruebas (no dejan nada: lo que hacen, lo deshacen)

| # | Archivo | Filas que salen |
|---|---|---|
| 7 | `docs/conta/c11-pruebas.sql` | 57 |
| 8 | `docs/conta/c13-pruebas.sql` | 41 |
| 9 | `docs/conta/c14-pruebas.sql` | 48 |
| 10 | `docs/conta/c15-pruebas.sql` | 52 |
| 11 | `docs/conta/c9-pruebas.sql` | 36 (con datos de verdad, hasta 4 pueden decir «omitida») |
| 12 | `docs/conta/c16-pruebas.sql` | 50 (hasta 3 pueden decir «omitida»: la 39, la 49 y la 50) |

Todas tienen que decir `true` u «omitida» con su porqué. Si una dice que la
app tenía algo tomado, se pega otra vez más tarde. **Una fila en `false`: no
sigas y manda la captura.**

## C. En la app (Contabilidad)

1. **Subs y 1099 → Ajustes:** el umbral del 1099 de 2026 con lo que diga el
   CPA (de fábrica viene 2,000 «a confirmar»).
2. **Subs y 1099 → Fichas:** una por cada sub y por cada ayudante por hora que
   cobra sin nómina. Del W-9: nombre legal (línea 1), nombre comercial (línea
   2), tipo de entidad (casilla 3) y dirección. «Se le reporta»: sí, no o por
   decidir (si dudas, por decidir). Enlázala con su proveedor o su perfil.
3. **El TIN:** en la ficha, con el código del teléfono. Si el navegador
   ofrece «guardar contraseña», di que no (nunca para este sitio).
4. **Los papeles:** el W-9 y el COI con su fecha de vencimiento.
5. **Pagos:** a cada pago «sin nombre», di de quién es; de lo «sin
   clasificar», di si fue servicio o no.
6. **Cédula de corte:** mira el 30-sep y el 31-oct. Lo que salga «no cuadra»
   o «sin auxiliar» se explica ahí mismo o se le escribe su renglón a mano.
7. **Facturas → Ajustes** (sigue pendiente): los datos de la empresa y el
   «How to pay».
8. **Nómina → Ajustes** (con el código del teléfono): la cuenta de las horas
   sin obra de la gente de campo (lo que diga el CPA) y que «La semana
   laboral empieza el» sea el mismo día que en Gusto (de fábrica, lunes).
9. **Costo por obra:** todavía **no fijes el «burden estándar»**. Con la
   nómina dentro contaría la mano de obra dos veces; se arregla antes del
   8-ene.
10. **Resumen** (la portada nueva): arriba, «Personalizar» esconde las
   tarjetas que no quieras ver y «Privacidad» tapa todos los montos (para
   enseñar la pantalla a alguien). Se acuerda en ese navegador. Cada tarjeta
   tiene «Ver los números» y su enlace a la página de donde sale.

El 1099 de 2026 sale de QuickBooks: la hoja de la app es parcial (el libro
de la app empieza el 30-sep) y sirve para cruzar.

## D. En Gusto, antes del 4-ene

1. Cada empleado con su nombre **igual que en la app** (así la app propone
   sola quién es quién). Los de campo por horas; el oficial con sueldo fijo.
2. Bajar un **«Payroll journal» en CSV** (Reports → Payroll journal; aunque
   salga vacío) y la plantilla de **«Import payroll data»**, y pasármelos:
   con ellos se fijan los nombres de las columnas antes de la primera nómina.
3. Decirme qué día empieza la semana laboral que pusiste en Gusto.
4. La primera nómina (día de pago viernes 8-ene) se corre a más tardar el
   **lunes 4-ene a las 7 pm**. Las horas de diciembre que ya se pagan por
   Zelle **no van** en ella.
5. **No subas a la app los archivos de muestra** de `pruebas/conta/nomina/`
   (todo «ZZ…»): dejan personas de mentira y las pruebas se saltan.

## E. Para decidir con el CPA

- El umbral del 1099 de cada año.
- A qué entidades no se les reporta (de fábrica, las corporaciones) y sus
  excepciones.
- Si el material que factura un sub cuenta para el 1099.
- Lo pagado a un sub de tu bolsillo: si cuenta.
- La fecha con que cuenta un pago: la del libro o la del banco.
- Los ayudantes por hora de 2026: 1099 o empleados.
- La LLC de un socio: si el W-9 lleva el nombre y el TIN del dueño.
- De la cédula: el patrimonio por el libro o por papel, el use tax contra
  cada DR-15, y el reparto del préstamo cada mes o al año.
- De la nómina: la cuenta de las horas sin obra; la regla del oficial (su
  sueldo cubre 80 h por período: lo de obra a 5001, lo demás a 6005) y su
  sueldo razonable; si lo que el patrón paga por la oficina y el oficial va
  a 6010; lo trabajado y no pagado al cierre del año; cómo y cada cuánto se
  reparte la prima de WC a las obras; sección 125 y 401(k) en el 940 y el
  RT-6; horas extra y la regla de Florida de 10 horas al día (448.01); 2553
  / S-corp y el seguro médico del accionista; los reembolsos por nómina;
  quien pasa de 1099 a W-2 en 2027.
