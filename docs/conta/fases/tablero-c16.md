# El tablero de la portada (c16)

**No es una fase del plan.** La Fase 16 del plan es el contador de guardia
(`f16-contador-de-guardia.md`). Esto es un pedido de Edgar del 13-nov: que
Contabilidad → Resumen se vea como el «Business at a glance» de QuickBooks,
«con gráficas, datos, números y enlaces de interés». La capa se llama c16
porque es la capa 16 de la base. Por eso sus archivos de prueba llevan «f16».

## Lo construido (13-nov)

- **`docs/conta/c16-tablero.sql`** (marca 2026111303): son 59 funciones
  `fn_tablero_*`.
  - Todas solo leen: son STABLE y SECURITY INVOKER.
  - Las usa solo el dueño. El equipo recibe 42501, y anon y service_role no
    ejecutan nada.
  - No crea tablas, vistas, triggers ni índices, y no guarda nada.
  - La pantalla hace una sola llamada, `fn_tablero(p jsonb)`. Cada tarjeta
    corre en su propio bloque: si una falla, sale sola con su motivo y las
    demás siguen. Por la API tiene un tope por reloj de 4 s, y lo que no
    alcanza sale en «sigue».
  - Las capas que pueden faltar se leen por `to_regprocedure` y `execute`.
    Por eso da igual el orden en que se pegan, también antes o después de
    c15.
- **`docs/conta/c16-pruebas.sql`** (50 filas): cada tarjeta se compara al
  centavo contra una consulta independiente: el libro crudo y las vistas de
  c4, c6, c7, p1, c8, c9, c10 y c12. Prueba también:
  - los bordes;
  - la capa que falta;
  - la tarjeta que falla;
  - el tope por reloj;
  - lo mal pedido;
  - que solo lee;
  - que nada queda.
- **`pruebas/conta/c16-volumen.sh`**: corre con 3,647 asientos. La mediana
  da 860 ms y el peor caso 1,178 ms. La meta es 1 s de mediana y 2 s el
  peor caso.
- **La pantalla** (`js/conta.js`, `css/conta.css`): arriba van
  «Personalizar» (esconder tarjetas) y «Privacidad» (tapa todos los montos).
  Las dos se guardan en el navegador de quien mira. Debajo:
  - Las acciones rápidas con su contador: Crear una factura, Revisar la
    Bandeja, Conciliar, Pedir un pago en línea, Cerrar el mes y Estados
    financieros.
  - «Qué atender».
  - 14 tarjetas, cada una con su gráfica en SVG, su tabla «Ver los números»
    y su enlace a la página de donde sale:
    - Embudo de cobro (no pagado → cobrado → depositado).
    - Bancos y tarjetas.
    - Resultados (con su período).
    - Gastos por categoría.
    - Flujo de caja (con la caja de hoy y la proyección marcada como tal).
    - Facturas.
    - Ventas.
    - Por cobrar y Por pagar, por antigüedad.
    - Conexiones.
    - Cobros en línea.
    - Use tax (DR-15).
    - Préstamos.
    - Obras.

  Si la app nueva llega antes de pegar c16, sale la portada de siempre con
  una línea que dice qué pegar.
- **Las pruebas de la pantalla:** en `pruebas/conta/pantalla.js` hay 118
  comprobaciones del tablero. Corren contra una base simulada sacada del
  banco: `f16-capturar.js` y `f16-semilla.sql`, todo «ZZ…», guardado en
  `pantalla-f16.json`.

La pantalla no suma dinero: cada cifra es la de la base. Resultados, gastos
y ventas salen del libro con el mapeo de c4, y las pruebas los atan a
`v_resultados` al centavo. Por cobrar y por pagar salen de las partidas de
la antigüedad de c4, así que dicen lo mismo que Estados. La caja sale de
`v_flujo_real_por_mes`, igual que Estados → Flujo de caja. Antes del
30-sep-2026 no se pinta nada: eso vive en QuickBooks.

Quién lo hizo: Opus 5.5 en la base, la pantalla, la verificación, la
revisión de cada número y los arreglos (el tablero solo lee el libro). Fable
en la revisión final. Esa revisión encontró y arregló siete cosas, cada una
con su prueba de antes y después:

- la caja «hasta hoy» que era el mes entero;
- un total «según el banco» que sumaba saldos de días distintos;
- lo cobrado contado el día que Stripe cambió de estado;
- lo devuelto de cobros de antes, restado de lo cobrado;
- las tablas que se salían de la pantalla del teléfono;
- montos sin «$» a la vista con Privacidad puesta;
- la deuda de la nómina en negativo entre el cargo de Gusto y el día de
  pago.

## La nómina en el tablero (14-nov, Fase 11c)

Lo que el 13-nov quedó abierto. `c16-tablero.sql` pasa a la marca
2026111403: 66 funciones (ninguna SECURITY DEFINER, sin tablas ni vistas) y
65 pruebas.

- **La tarjeta «Nómina»** (la 16): la última nómina y la próxima, lo que se
  debe de ella según el libro y cuándo sale de la caja, los cargos de Gusto
  que esperan, las nóminas por postear, lo que costó cada mes y la bolsa del
  burden. **La acción rápida «Nómina»**, con su número. Lo suyo en «Qué
  atender».
- **La proyección de la caja** resta lo que el libro dice que se debe de la
  nómina: lo de una nómina ya posteada, su día de pago; lo demás, hoy.
- **El código del teléfono.** Lo de cada nómina (sus totales, cuántas
  personas, las por postear) solo llega con el código; sin él la tarjeta
  dice «con el código del teléfono», nunca un cero. Qué más se ve sin el
  código lo decide un solo sitio, `fn_tablero_nomina_criterio()`: «libro»
  (de fábrica) o «codigo».
- **Sin c15**, todo como antes: la tarjeta dice que la nómina no está
  pegada y su acción sale apagada. Con la app nueva y el c16 de antes, la
  tarjeta dice qué pegar.
- **Lo que arregló la verificación** (cada cosa con su prueba de antes y
  después):
  - Cuándo sale lo que se debe: lo que Gusto ya cobró se le quita a la
    nómina que pagó, no a lo más viejo de la cuenta. Con un cheque de papel
    sin cobrar de una nómina anterior, la portada mandaba esa deuda al día
    de pago de la siguiente.
  - Las vacaciones devengadas (2215) y lo demás del renglón «nómina por
    pagar» que ninguna nómina paga no cuentan en lo que se debe de la
    nómina ni salen de la caja hoy: van aparte, dichas.
  - La portada ya no arma la propuesta de cada cargo de Gusto para
    contarlos: lee dos lecturas ligeras de c15.
  - Gastos, con el criterio «codigo», dice una sola vez que las cuentas de
    la nómina van tapadas, y que van enteras.
  - La prueba 10 daba un rojo falso el último día de un mes de 30 que sigue
    a uno de 31.
- **La pantalla** (`js/conta.js`): la tarjeta, la acción, «Qué atender», la
  columna «Nómina» de la proyección y lo que va aparte, con las palabras de
  la base. Las bases simuladas (`pantalla-f16.json`, `-f12.json` y
  `-f15.json`) se sacaron otra vez del banco con las capas de hoy.

## ▶ Lo que queda

- **La nómina sin el código del teléfono: «libro» o «codigo».** Lo decide
  Edgar. Con «codigo», la tarjeta de gastos esconde enteras las cuentas de
  la nómina (también lo que tengan que no sea de Gusto).
- **Para decidir** (están en la cabecera de c16, y ninguna frena nada):
  - Los términos de las facturas de QuickBooks: se toman de Facturas →
    Ajustes.
  - La regla del WIP en ventas y resultados (con el CPA).
  - Cómo proyectar lo vencido.
- **El tema oscuro.** La app entera no tiene tema oscuro: con el teléfono
  en oscuro se ve igual que en claro. Sería trabajo de `css/styles.css`,
  que es compartido.
- **El rendimiento.** Cumple la meta de 1 s, pero con poco margen en el
  banco de pruebas. La tarjeta más lenta es la caja (260 a 300 ms).
