# Los escenarios de ataque al banco (rondas 4b, 4c y 4d de c6)

Cada escenario es `<esc>-montaje.sql` (por pestañas, `-- [Pestaña n]`, cada
una en su transacción como el SQL Editor) y, casi siempre, `<esc>-mirar.sql`
(lo que se mira o se pulsa al final). `harness.sql` pulsa tal cual, en una
subtransacción, cada botón de la bandeja que no pide motivo; `auditor.sql`
mira lo guardado con EL CRITERIO del otro lado (cabecera de c6, rondas 4c y
4d). `base-m.sql` es la base de los escenarios M (la apertura de QuickBooks,
su conciliación confirmada, la débito, la reserva y la cuenta personal dadas
de alta).

    ./tpl.sh 5433                 # la plantilla atq_t17n (16: 5432 → atq_t16n)
    ./atq.sh 5433 L03             # un escenario; la salida en out/L03_17.out
    ./repro-m.sh 5433 M02 M05     # los M, de cero, con base-m.sql

Al final de cada salida: lo que el auditor encuentra, el control del banco
en rojo, los casados que contradicen EL CRITERIO (`REF`), el cuadre 59 («el
otro lado de cada casado», `C59`) y `fn_banco_verificar` (`VER`).

- A a I: la prueba final de la 4b (el dinero del banco al patrimonio).
- K1 a K7: el corrector de la 4c (un escenario por camino que tocó).
- L01 a L17 y L02b: la prueba final de la 4c (EL CRITERIO).
- M01 a M10: la prueba final de la 4d (EL CONTROL). Con la 4d (marca
  2026100303) siguen abiertos los que el README general cuenta en §0, «Lo
  que encontró la prueba final de la 4d»: M01 y M01b (el cheque devuelto),
  M02 y M03 (la cuota registrada antes que el banco), M05 (R1 de la débito
  con un pase por número), M10 (el motivo automático de rehacer una
  transferencia), y los menores M04, M06 y M08.
