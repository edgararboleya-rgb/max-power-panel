# Fase 8 · El cierre mensual y las alarmas
**2 – 8 nov · 🔵 AZUL el cierre, la ronda, los activos y la regla de ajustes · 🟢 VERDE export, DR-15 y avisos · ▶ pg_cron, plan de Supabase, cierras octubre**

## Tú

1. **Una semana antes:** habilitar `pg_cron` en Supabase; confirmar el plan del
   proyecto (respaldos diarios / PITR; si es gratuito, `pg_dump` semanal
   automatizado a Storage); subir la acción nueva de la función `correo` con
   adjuntos (su código no está en este repo).
2. **Cerrar octubre en la app**, de principio a fin. Compararlo contra
   QuickBooks en cuanto el contador cierre octubre (a más tardar la semana 9),
   con las diferencias explicadas por categoría en la tabla de f04: base,
   nómina bruta contra neta, depreciación, WIP, retención.
3. Decidir con el CPA el método libro de depreciación (espejo fiscal o línea
   recta) — ▶ antes de f12.

## 🔵 Azul — se crea (`/effort max`)

- **El cierre y la ronda nocturna.** `select cron.schedule('ronda_contable',
  '0 11 * * *', $$select fn_ronda()$$)` — 11:00 UTC = 6 am de Miami en
  invierno. `fn_ronda()` en **SQL puro** deja su resultado en
  `ronda_resultados(fecha, control, ok, detalle jsonb)`. **La IA no se dispara
  de noche**: `conta.js` lee los resultados al abrir y, si hay rojo, ofrece
  «que el contador lo explique» (f16).
- **Qué se vigila, en qué orden, y qué detiene el cierre:** cuadre ·
  conciliación bancaria (detiene solo la diferencia no explicada; partida > 30
  días = alarma con nota) · cada 10x0, 2100-x y 25xx contra su statement ·
  2010 por proveedor = statement del supply, con antigüedad de CxP · auxiliar
  por obra = mayor · recibos con impuesto desconocido = 0 · 1590 = suma de
  `activos_fijos` · triggers y policies habilitados (`select tgenabled from
  pg_trigger where tgrelid='asiento_lineas'::regclass`) ·
  `fn_verificar_cadena` sobre los meses cerrados y balanza de cada mes cerrado
  contra la exportada · cuántos reversos y asientos de origen IA hubo y cuánto
  suman · pagos a subs con COI vencido o ausente.
- **`activos_fijos`** (descripción, placa/serie, cuenta 15xx, fecha en
  servicio, costo, residual, vida en meses, método libro, depreciación
  acumulada de arranque, `asiento_alta_id`, baja/venta) y el puente mensual
  Dr 6950 / Cr 1590 generado por SQL como un molde más. Se carga en f12 desde
  la cédula del CPA de 2025 + altas de 2026.
- **Regla A de ajustes post-cierre: nunca se reabre.** Los ajustes del CPA
  entran fechados en el mes abierto en que los entrega, con
  `tipo='ajuste_cpa'`, `afecta_periodo='2026-12'`, `motivo` y la declaración
  como documento; los estados de diciembre y de enero–marzo tienen vista «con
  ajustes posteriores». Un error descubierto en mes cerrado se corrige con
  reverso en el período abierto, con referencia al original.
- El criterio para `docs/conta/OPERACION.md` (qué se toca y qué no cuando algo
  falla; la restauración: respaldo de Postgres primero, CSV solo como camino
  legible de último recurso).

- **Reserva de impuestos (1030) al cierre.** La app calcula lo que debería
  haber: utilidad del año a la fecha × % que fija el CPA − pagos estimados ya
  hechos (3200 marcados como impuesto de Edgar) = saldo objetivo de 1030.
  Muestra «transfiere $X» o «sobra $Y». La ronda avisa si 1030 queda corta, y
  15 días antes de cada estimado (15-abr, 15-jun, 15-sep, 15-ene) recuerda el
  monto. Cada pago estimado queda listado para el paquete del CPA (f17).

## 🟢 Verde — se trabaja encima (`/effort auto`)

- **Export v1:** CSV desde las vistas (mayor con saldo corrido, procedencia y
  sello de IA) y PDF por el camino de imprimir que la app ya usa, guardados en
  el bucket privado `cierres/AAAA-MM/`; botón «Descargar cierre» con URL
  firmada (como `firmarFotos`); correo automático con adjuntos por `correo`.
  El export lleva el **hash del mayor del mes** y el sha256 y ruta de las fotos
  y PDFs contabilizados ese mes. *Drive por OAuth es un proyecto de Google
  Cloud aparte: Fase 18, opcional.*
- Vista mensual «base de use tax y sales tax cobrado» para el **DR-15**.
- Avisos al teléfono: pg_net → push (la app ya tiene `push_suscripciones` y VAPID).
- Historial de cierres: período, quién, cuándo, ruta del archivo, hash.

## Entregable
`docs/conta/c8-cierre.sql` · el export · el criterio de `OPERACION.md`

## Terminó cuando
Octubre está cerrado, bloqueado, exportado a Storage y en tu correo; al
intentar escribir en octubre la base te lo impide (desde `fn_postear` **y desde
el SQL Editor**); la ronda corrió sola esta noche y el rojo se ve al abrir la
app; y octubre da **la misma utilidad que QuickBooks** salvo diferencias
explicadas por categoría.

> Este export es la defensa que vale por todas: si mañana desaparecen Supabase
> y la app, tus libros siguen siendo tuyos y legibles. **Restaurables** lo
> prueba la Fase 15.

## Lo construido (7-nov)

El entregable se llama `docs/conta/c9-cierre.sql` (c8 ya era el contador de la
Fase 7), con `c9-pruebas.sql` (36 pruebas) y `docs/conta/OPERACION.md`.

- **La página «Cierre del mes»** en Contabilidad. Dice, para el período que
  toca (la apertura primero, después octubre), qué lo detiene en una lista en
  llano con números y a qué página ir. El botón de cerrar se enciende solo
  cuando no queda nada en rojo, pide el código del teléfono y la frase exacta
  («CERRAR LA APERTURA», «CERRAR OCTUBRE 2026»). La base vuelve a revisar en el
  momento de cerrar; si algo entró en medio, no cierra (MX010) y lo dice.
- **Qué detiene y qué avisa.** Detienen: el orden, el calendario, el asiento de
  apertura vivo, el cuadre, el banco sin clasificar, la conciliación de cada
  cuenta al último día, las obras, 1590 contra los activos, la depreciación
  del mes y los controles del libro, del banco, de los estados y de los
  puentes. Avisan: las propuestas de la IA sin decidir, el tránsito de más de
  30 días, 2010 por proveedor, los tickets sin foto o sin impuesto conocido,
  los cobros en línea, los cambios del mes y el COI (llega con f12a). La
  apertura avisa además si a una cuenta del banco le falta su conciliación de
  apertura, que c6 exige antes de confirmar la de octubre.
- **El cierre** usa el candado de c2 tal cual (`fn_cerrar_periodo`): después
  nadie escribe en el mes, ni desde la app ni desde el SQL Editor. Se guarda
  la revisión, la balanza y el hash del mayor, recalculable fuera de la base
  desde el CSV.
- **El export** sube el CSV del mayor, el CSV de la balanza, los estados
  (para imprimir en PDF) y un LÉEME con la huella de cada archivo al bucket
  privado «cierres». La base comprueba que cada archivo está
  ahí y mide lo que se declara. Se puede repetir; lo anterior queda en el
  historial.
- **La ronda** corre sola a las 11:45 UTC (6:45 en Miami en invierno), después
  del banco y del contador. Revisa el período que toca y los cierres ya hechos
  (si la balanza o el hash de un mes cerrado cambian, rojo y al respaldo).
  Cada rojo nuevo va una vez al teléfono; si el aviso falla, se reintenta al
  día siguiente.
- **Activos fijos y depreciación** en línea recta: el alta, la baja, el plan y
  el asiento del mes (Dr 6950, Cr 1590). La cédula del CPA entra con f12.
- **La reserva 1030** y el **DR-15**: la reserva espera el % que fije el CPA y
  el próximo estimado; el DR-15 da lo cargado a use tax (2300) en el mes.
- **Seguridad:** nada de c9 es SECURITY DEFINER; lo que llama la pantalla es
  SECURITY INVOKER con `es_dueno()`, y la ronda no tiene API. El control
  «permisos» de c2 sigue en verde.

Probado desde cero por el camino de producción: c2 83, c3 120, c4 113, c6
163, c7 21, s1 8, p1 46, c8 38 y c9 36, todas en verde, y c9 dos veces
seguidas sin rastro. Con un libro de prueba sin conciliación de apertura en la 1010,
c9 da 32 en verde y 4 «omitida», con el mensaje de c6 que dice qué falta. En
producción las tres conciliaciones de apertura (1010 y las dos Amex) ya están
confirmadas.

**Lo que falta para cerrar octubre de verdad:** la Bandeja limpia (los
movimientos de octubre clasificados), la conciliación de cada cuenta al
31-oct confirmada, y comparar la utilidad con QuickBooks.
