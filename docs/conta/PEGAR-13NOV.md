# Lo que hay que pegar (13-nov, noche · v305)

**Una sola lista con todo lo pendiente.** Sustituye a la del 12-nov y a la
primera versión de esta. Trae la cédula (c13), los subs y el 1099 (c14), la
nómina (c15), el tablero (c16) y la Fase 11b, que enseña la nómina a las
capas que ya tienes (c3, c6, c10, c12 y c13). Está probada desde lo que hoy
tiene tu base: c1 a c12.

Se pega en Supabase → SQL Editor:

- Cada archivo se copia **entero**, se pega en una consulta nueva y se le
  da a **Run**.
- Al final cada uno enseña una tabla: mira que tenga las filas que dice
  aquí.
- Todo se puede pegar dos veces sin que cambie ningún dato. Si te quedas a
  medias, sigue desde donde ibas.

Antes de empezar:

- **Cierra la app en el teléfono y en la computadora**, y hazlo a una hora
  en que la cuadrilla no esté subiendo fotos. Lo pide sobre todo
  `c3-puentes.sql`: es el único que espera si alguien tiene la app abierta,
  en vez de parar. Si se queda pensando más de un minuto, alguien la tiene
  abierta.
- Si sale un error que diga **«lock timeout» (55P03)**, no pasó nada:
  espera un minuto y pega el mismo archivo otra vez.
- **Nunca escribas un TIN en el SQL Editor.** El TIN va en la app, en la
  ficha del sub, con el código del teléfono.

## A. Las capas, en este orden

| # | Archivo | Filas que salen |
|---|---|---|
| 1 | `docs/conta/c11-emision.sql` (otra vez: el arreglo de las facturas anuladas) | 12 |
| 2 | `docs/conta/c3-puentes.sql` (otra vez: el devengo de un mes con nómina) | 23 |
| 3 | `docs/conta/c6-banco-parte1.sql` (otra vez: el banco con la nómina) | 1 |
| 4 | `docs/conta/c6-banco-parte2.sql` (justo después de la parte 1) | 7 |
| 5 | `docs/conta/c10-costo-obra.sql` (otra vez: las horas que paga una nómina) | 9 |
| 6 | `docs/conta/c12-wip.sql` (otra vez) | 8 |
| 7 | `docs/conta/c13-cedula.sql` (nuevo: la cédula de corte) | 8 |
| 8 | `docs/conta/c14-subs.sql` (nuevo: W-9, COI y 1099) | 9 |
| 9 | `docs/conta/c15-nomina.sql` (nuevo: la nómina con Gusto) | 9 |
| 10 | `docs/conta/c9-cierre.sql` (otra vez: las filas de la cédula, el 1099 y la nómina) | 12 |
| 11 | `docs/conta/c16-tablero.sql` (nuevo: el tablero de la portada; solo lee) | 6 |

Lo que tiene que decir cada uno:

- **c3:** la fila `puentes · sin_evaluar` puede salir en `false` la primera
  vez. Lo demás, en `true`.
- **c13:** la fila «control» dice «0 de 2 cuadres en rojo · 0 de 4 avisos».
- **c14:** la fila «qué falta» dirá que hay que confirmar el umbral del 1099
  con el CPA y dar de alta las fichas. Es lo esperado.
- **c15:** la fila «control» dice «0 de 5 cuadres en rojo · 0 de 14
  avisos». La fila «qué falta» dirá que falta la cuenta de las horas sin
  obra y el primer «Payroll journal» de Gusto. Es lo esperado.
- **c16:** «una pasada del tablero» dice «15 tarjetas: 15 contestan, 0 dicen
  que su capa no está, 0 fallan», y «qué falta» dice «nada».

## B. Las pruebas (no dejan nada: lo que hacen, lo deshacen)

| # | Archivo | Filas que salen |
|---|---|---|
| 12 | `docs/conta/c11-pruebas.sql` | 57 |
| 13 | `docs/conta/c3-pruebas.sql` | 126 (la 45 sale «omitida»; de la 121 a la 125 pueden decir «omitida … pasa del tope de fecha») |
| 14 | `docs/conta/c6-pruebas.sql` | 167 |
| 15 | `docs/conta/c10-pruebas.sql` | 64 |
| 16 | `docs/conta/c12-pruebas.sql` | 48 |
| 17 | `docs/conta/c13-pruebas.sql` | 48 |
| 18 | `docs/conta/c14-pruebas.sql` | 48 |
| 19 | `docs/conta/c15-pruebas.sql` | 66 |
| 20 | `docs/conta/c9-pruebas.sql` | 36 (con datos de verdad, hasta 4 pueden decir «omitida») |
| 21 | `docs/conta/c16-pruebas.sql` | 50 (hasta 3 pueden decir «omitida»: la 39, la 49 y la 50) |

Todas tienen que decir `true` u «omitida» con su porqué:

- Si una dice que la app tenía algo tomado, se pega otra vez más tarde.
- La **53 de c6** mide cuánto tarda el importador. Si sale en `false`, pega
  c6-pruebas otra vez: con el servidor cargado a veces se pasa.
- **Una fila en `false` (fuera de esa): no sigas y manda la captura.**

## C. En la app (Contabilidad), con la versión nueva

1. **Cierra y abre la app.**
2. **Bandeja:** toca **«Casar»** una vez. Hasta entonces los pendientes no
   enseñan sus botones, porque sus propuestas son de antes del banco nuevo.
   Lo de Gusto dirá que se casa desde Nómina → Cargos de Gusto.
3. **Subs y 1099 → Ajustes:** el umbral del 1099 de 2026 con lo que diga el
   CPA. De fábrica viene 2,000 «a confirmar».
4. **Subs y 1099 → Fichas:** una por cada sub y por cada ayudante por hora
   que cobra sin nómina.
   - Del W-9: nombre legal (línea 1), nombre comercial (línea 2), tipo de
     entidad (casilla 3) y dirección.
   - «Se le reporta»: sí, no o por decidir (si dudas, por decidir).
   - Enlázala con su proveedor o su perfil.
5. **El TIN:** en la ficha, con el código del teléfono. Si el navegador
   ofrece «guardar contraseña», di que no (nunca para este sitio).
6. **Los papeles:** el W-9 y el COI con su fecha de vencimiento.
7. **Pagos:** a cada pago «sin nombre», di de quién es; de lo «sin
   clasificar», di si fue servicio o no.
8. **Cédula de corte:** mira el 30-sep y el 31-oct.
   - Lo que salga «no cuadra» o «sin auxiliar» se explica ahí mismo, o se le
     escribe su renglón a mano.
   - Las cuentas de la nómina dicen «con el código» hasta que lo pongas.
     Eso no es un rojo.
9. **Facturas → Ajustes** (sigue pendiente): los datos de la empresa y el
   «How to pay».
10. **Nómina → Ajustes** (con el código del teléfono):
    - la cuenta de las horas sin obra de la gente de campo (lo que diga el
      CPA);
    - que «La semana laboral empieza el» sea el mismo día que en Gusto (de
      fábrica, lunes).
11. **Costo por obra:** **ya puedes fijar el «burden estándar»**. Las horas
    que paga una nómina cuentan a su costo real y no además a estándar. El
    porcentaje, el que diga el CPA.
12. **Resumen** (la portada nueva):
    - «Personalizar» esconde las tarjetas que no quieras ver.
    - «Privacidad» tapa todos los montos.
    - Cada tarjeta tiene «Ver los números» y su enlace.

El 1099 de 2026 sale de QuickBooks: la hoja de la app es parcial (el libro
de la app empieza el 30-sep) y sirve para cruzar.

## D. En Gusto, antes del 4-ene

1. Cada empleado con su nombre **igual que en la app**: así la app propone
   sola quién es quién. Los de campo, por horas; el oficial, con sueldo
   fijo.
2. Baja un **«Payroll journal» en CSV** (Reports → Payroll journal), aunque
   salga vacío. Si deja elegir, en **resumen** y con las columnas de **lo
   que paga el patrón**: sin ellas la nómina no cuadra. Baja también la
   plantilla de **«Import payroll data»** y pásame las dos: con ellas se
   fijan los nombres de las columnas antes de la primera nómina.
3. Dime qué día empieza la semana laboral que pusiste en Gusto.
4. Pregúntale a Gusto cómo cobra o devuelve una **corrección**: un depósito
   aparte, o descontado del siguiente cargo.
5. La primera nómina (día de pago viernes 8-ene) se corre a más tardar el
   **lunes 4-ene a las 7 pm**. Las horas de diciembre que ya se pagan por
   Zelle **no van** en ella.
6. **No subas a la app los archivos de muestra** de `pruebas/conta/nomina/`
   (todo «ZZ…»): dejan personas de mentira y las pruebas se saltan.

## E. Para decidir con el CPA

- **El 1099:**
  - el umbral de cada año;
  - a qué entidades no se les reporta (de fábrica, las corporaciones) y sus
    excepciones;
  - si el material que factura un sub cuenta;
  - si cuenta lo pagado a un sub de tu bolsillo;
  - si un pago cuenta con la fecha del libro o con la del banco;
  - si los ayudantes por hora de 2026 son de 1099 o empleados;
  - en la LLC de un socio, si el W-9 lleva el nombre y el TIN del dueño.
- **La cédula:**
  - el patrimonio, por el libro o por papel;
  - el use tax contra cada DR-15;
  - el reparto del préstamo, cada mes o al año;
  - los pasivos con saldo al revés (una tarjeta pagada de más, un proveedor
    con saldo a favor).
- **La nómina:**
  - la cuenta de las horas sin obra;
  - la regla del oficial (su sueldo cubre 80 h por período: lo de obra a
    5001, lo demás a 6005) y su sueldo razonable;
  - si lo que el patrón paga por la oficina y el oficial va a 6010;
  - lo trabajado y no pagado al cierre del año;
  - cómo y cada cuánto se reparten a las obras la bolsa del burden y la
    prima de WC;
  - el porcentaje del burden estándar;
  - sección 125 y 401(k) en el 940 y el RT-6;
  - horas extra y la regla de Florida de 10 horas al día (448.01);
  - 2553 / S-corp y el seguro médico del accionista;
  - los reembolsos por nómina;
  - quién pasa de 1099 a W-2 en 2027;
  - las horas pagadas por Zelle dentro de un mes devengado a estándar;
  - a qué fecha cuenta «pagada por una nómina» en meses ya cerrados.
