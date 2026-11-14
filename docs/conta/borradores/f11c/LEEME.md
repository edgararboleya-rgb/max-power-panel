# Fase 11c, a medias (14-nov) — NO PEGAR NADA DE AQUÍ

Esta carpeta guarda una vuelta de trabajo que se paró sin terminar. Nada de
aquí está revisado ni va a producción. Lo que Edgar pega es lo de
`docs/conta/PEGAR-13NOV.md` (v305).

## Por qué se paró

El cupo semanal de Fable se acabó a media obra. Se reinicia el
**20-nov-2026 a las 5:00 UTC**. Edgar pidió no pasar a Opus el trabajo que
pide Fable: todo lo que toca dinero o la seguridad de la nómina se queda
esperando.

## Lo que hay

- `f11c-sin-revisar.patch` es el trabajo de Fable sobre la v305 (`0029f03`).
  Se aplica limpio con `git apply`. Trae dos cosas:
  - **c3: el corte de los jornales.** El devengo de un mes aparta las horas
    que pagó un jornal (Zelle) dentro del mes. Cuando se postea o se reversa
    un jornal de un mes ya devengado, el devengo se pone al día solo.
    También toca c10 v4 (dos textos), el guion nuevo `c3-jornal.sh` y
    c6-en-uso.sh.
  - **c6/c15: «GUSTO» como palabra entera en los débitos.** Usa
    `fn_banco_dice_nomina` de c6, que c15 también llama. El patrón de
    fábrica pasa a `(GUSTO|ZENPAYROLL|PAYROLL|\mADP\M|PAYCHEX)`, con su
    rastro en `banco_historial`. Trae el guion nuevo `c6-gusto.sh` y el CSV
    de muestra `zz-cargos-de-gusto-en-el-banco.csv`.

  Están las marcas: puente 2026111401 y banco 2026111401. Las pruebas son
  c3 135, c6 169, c10 64 y c15 68. La verificación desde cero (Opus) las
  encontró completas y en verde en los tres órdenes y en la lista entera.
  Su informe está en `informe-verificacion.json`.

  **Les falta:** el informe de sus propios autores, los arreglos y la
  revisión final, todo en Fable.
- **El tablero aprende la nómina (c16)** no llegó a hacerse en Fable. Lo que
  hay es un **prototipo de Opus**, armado solo para poder construir la
  pantalla:
  - `c16-tablero-prototipo-opus.sql` (marca 2026111401);
  - `f16-semilla-nomina-prototipo-opus.sql`;
  - la pantalla (la tarjeta de Nómina, la acción rápida, «Qué atender» y
    la proyección), que sí va en el parche: `js/conta.js`, `css/conta.css`,
    `pruebas/conta/pantalla.js` y `f16-capturar.js`. Las bases simuladas
    (`pantalla-f12/f15/f16.json`) no van en el parche: se vuelven a
    capturar. Su informe está en `informe-pantalla.json`.

  La base de c16 toca la seguridad de la nómina, así que la tiene que
  hacer o revisar Fable antes de nada.

## Lo que encontró la verificación (para la vuelta con Fable)

- c16 no cambió: falta toda la parte de la nómina en la base, y sus
  pruebas.
- c15 no mira el memo del banco (c6 sí) al decidir si un débito es de
  Gusto. Un débito con «Gusto» solo en el memo no sale en Cargos de Gusto
  hasta el primer «Casar».
- En c3-pruebas, las 121 a 125, la 132 y la 135 rehacen
  `fn_nomina_horas_con_pago`. Si algo depende de ella, fallan con 2BP01 en
  vez de salir «omitida».
- La 133 y la 131 de c3-pruebas y la 55 de c10-pruebas toman candados
  fuertes un instante.
- Algunos identificadores de prueba parecían de verdad. En este parche ya
  están cambiados a «ZZ…»; hay que cambiarlos también en el árbol.
- Los documentos, al día: las filas de las pruebas (c3 135, c6 169, c15
  68), la lista de pegado con los dos caminos (encima de la v305, o la lista
  única) y el orden: c15 ahora pide el c6 del 14-nov.
- La decisión de seguridad de la tarjeta: sin el código, el costo de la
  nómina por mes sale del libro. Con una sola persona, eso es lo que cobró.
  Ya pasa hoy con la cuenta 6005 en Gastos. Hay que decidirlo con el
  criterio de c15 y escribirlo.
