# Fase 2 · El libro
**28 sep – 4 oct · 🔵 AZUL crea · 🟢 VERDE prueba · ▶ pegar el SQL**

> Los invariantes. Si esto queda bien, ningún libro se corrompe después; si
> queda mal, no hay pantalla que lo salve.

## Tú
Pegar el SQL y confirmar que corrió. Nada más.

## 🔵 Fable crea
- `cuentas`, `asientos`, `asiento_lineas`, `periodos`.
- `asiento_lineas` con las dimensiones de la Fase 1 (`proyecto_id`,
  `cost_code`, `fase`) y el monto en `numeric`, nunca `float`.
- **Función de posteo** (`fn_postear`): una transacción, recibe el lote
  completo, rechaza si debe ≠ haber. El navegador nunca inserta líneas sueltas.
- **Inmutabilidad:** `asiento_lineas` sin `update` ni `delete` (regla de RLS
  + trigger). La corrección es un asiento de reverso.
- **Bloqueo de período:** nadie escribe en un mes cerrado — ni Edgar, ni un
  puente, ni la IA.
- **Procedencia:** cada asiento guarda quién, cuándo, desde qué documento y
  por qué camino (mano / puente / IA aprobada), con el sello del punto 3.
- La fecha contable como `date` en hora de Miami, nunca derivada de un
  timestamp de pantalla.

## 🟢 Opus prueba
Pruebas que lo atacan, en `pruebas/conta-libro.js`:
asiento descuadrado por un centavo · escritura en mes cerrado · intento de
`update` · intento de `delete` · fecha del 31-dic a las 7pm.

## Entregable
`docs/conta/c2-libro.sql` · `pruebas/conta-libro.js`

## Terminó cuando
Las cinco pruebas pasan en rojo primero y en verde después. Un asiento
descuadrado **no entra**, y lo demuestras.

## Desbloquea
Todo lo demás.
