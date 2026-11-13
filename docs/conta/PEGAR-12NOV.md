# Lo que hay que pegar (12-nov · v302)

> **Ya no uses esta lista: usa `PEGAR-13NOV.md`**, que trae lo mismo y
> además la nómina (c15). Lo que ya hayas pegado de aquí se puede pegar otra
> vez sin daño.

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
| 4 | `docs/conta/c9-cierre.sql` (otra vez: trae las filas 160, 178 y 179) | 12 |

En la de c14, la fila «qué falta» dirá que hay que confirmar el umbral del
1099 con el CPA y dar de alta las fichas. Es lo esperado.

## B. Las pruebas (no dejan nada: lo que hacen, lo deshacen)

| # | Archivo | Filas que salen |
|---|---|---|
| 5 | `docs/conta/c11-pruebas.sql` | 57 |
| 6 | `docs/conta/c13-pruebas.sql` | 41 |
| 7 | `docs/conta/c14-pruebas.sql` | 48 |
| 8 | `docs/conta/c9-pruebas.sql` | 36 (con datos de verdad, hasta 4 pueden decir «omitida») |

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

El 1099 de 2026 sale de QuickBooks: la hoja de la app es parcial (el libro
de la app empieza el 30-sep) y sirve para cruzar.

## D. Para decidir con el CPA

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
