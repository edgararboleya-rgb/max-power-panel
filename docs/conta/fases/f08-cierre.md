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

## 🔵 Fable

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

## 🟢 Opus

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
