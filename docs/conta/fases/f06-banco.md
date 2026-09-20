# Fase 6 · Banco y tarjetas
**26 oct – 1 nov · 🔵 AZUL idempotencia · 🟢 VERDE los lectores · ▶ manda los archivos**

## Tú
Bajar un CSV u OFX de **cada cuenta y cada tarjeta** y mandarlos. Sin eso no
se puede escribir el lector — cada banco exporta distinto.

## 🔵 Fable
**Idempotencia y conciliación.** El movimiento pendiente que se vuelve
confirmado cambiando de identificador es donde los libros se corrompen
callados. Llave estable, detección de duplicado, y el amarre obligatorio
contra el saldo del estado de cuenta.

## 🟢 Opus
Un lector por banco. El importador de archivo **se queda para siempre**, aunque
después entre Plaid: los conectores se caen y el archivo nunca falla.

## Entregable
`docs/conta/c6-banco.sql` · el importador en `js/conta.js`

## Terminó cuando
Importas el mismo archivo dos veces y no entra nada la segunda vez.
