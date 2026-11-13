# Operación de los libros — qué se toca y qué no cuando algo falla

Para Edgar, en llano. Es el criterio de la Fase 8 (`docs/conta/fases/f08-cierre.md`):
qué se toca y qué no cuando algo falla, cómo se restaura, qué hacer si la ronda
sale en rojo, y cómo se corrige un mes cerrado. Lo técnico está en las cabeceras
de `c2-libro.sql` (el libro) y `c9-cierre.sql` (el cierre y la ronda).

## 1. Las tres reglas que no se negocian

1. **El libro no se edita ni se borra.** Nunca un `update` ni un `delete` sobre
   `asientos` o `asiento_lineas`, ni desde el SQL Editor. La base lo impide
   (MX003), y si alguien lo lograra por debajo de las guardas, la ronda lo
   delata (`fn_verificar_cadena`). Un asiento equivocado se **reversa**
   (`fn_reversar`, con su motivo) y se postea el bueno.
2. **Un período cerrado no se reabre.** Nunca. Ni octubre, ni la apertura, ni
   un año. Lo que faltó o estaba mal entra en el mes abierto (abajo, §5).
3. **No se corrige a mano lo que un control pinta en rojo.** Un rojo dice qué
   pasó y qué hacer; si no se entiende, se para y se avisa. Corregir «para que
   se ponga verde» sin saber por qué estaba en rojo es cómo se pierde un libro.

## 2. Qué se toca y qué no

| Si pasa esto… | Se toca | NO se toca |
|---|---|---|
| Un cargo del banco quedó mal clasificado | La Bandeja: des-casar con su motivo y clasificar bien (c6 pone el reverso y el asiento nuevo) | El asiento, a mano |
| Un ticket entró con la cuenta equivocada | El recibo (✎ en la app) o la regla de su categoría; el puente lo rehace | El asiento, a mano |
| Un asiento a mano estaba mal | `fn_reversar(id, 'motivo')` y el asiento bueno | `update asientos` |
| La depreciación del mes salió mal | Reversar ese asiento (`fn_reversar`) y volver a tocar «Postear depreciación» | `activos_depreciaciones` a mano |
| Un activo se vendió o se perdió | `fn_activo_baja` con su fecha y motivo, y el asiento de la baja a mano (Dr 1590, Cr 15xx, 4920) | Borrar el activo |
| Un control de otra capa está en rojo | Lo que dice su detalle (cada uno lo trae) | El control |
| La ronda dice «cierre guardado: 2026-10 cambió» | NADA. Restaurar (§3) y avisar | Cualquier cosa del libro |
| Un pegado (c*.sql) dio MX000 | Lo que el mensaje pide (pegar antes la capa que falta) | Nada quedó: no hay que deshacer |
| Supabase cayó o la app no abre | Esperar; los libros están en Postgres y en el export | Nada |

## 3. La restauración: el respaldo de Postgres primero

El orden es siempre el mismo:

1. **Respaldo de Postgres.** Supabase guarda respaldos diarios (o PITR, según
   el plan del proyecto; si el plan es gratuito, la Fase 8 pide un `pg_dump`
   semanal automatizado a Storage: eso lo arma Edgar en Supabase, no está en
   este repo). Restaurar es volver a un momento anterior de TODA la base: el
   libro, el banco, las conciliaciones, los cierres, todo coherente. Después
   de restaurar, lo primero: `select * from fn_verificar_cadena();` → los 10
   en `true`, y `select * from fn_cierre_pegado();` para ver en qué quedó el
   cierre. Si algo sale en rojo, no se toca: se avisa (la Fase 15 ensaya la
   restauración de verdad).
2. **El export del cierre es el ancla, no la copia para restaurar.** Cada
   cierre deja en el bucket `cierres/AAAA-MM/` el mayor en CSV y el PDF, con
   su sha256 y el **hash del mayor**. Con eso se comprueba que lo restaurado
   es lo que había: `select fn_cierre_hash_mayor('2026-10');` tiene que dar lo
   que dice `v_cierres` para ese mes (y lo que salió por correo). Si da otra
   cosa, el respaldo restaurado no es el bueno: otro más viejo, o avisar.
3. **El CSV solo como último recurso legible.** Si mañana desaparecen Supabase
   y la app, los CSV del bucket (y los del correo) siguen siendo los libros,
   legibles en cualquier hoja de cálculo. Un CSV **no se vuelve a cargar** en
   la base como si fuera el libro: no trae los sellos ni la cadena. Sirve
   para leer, para el CPA, para el banco. Lo restaurable es el respaldo de
   Postgres (la Fase 15 lo prueba).

Lo que nunca se hace al restaurar: «arreglar» a mano los asientos que faltan
después de volver a un respaldo viejo. Lo que entró después del respaldo se
vuelve a importar del banco (Plaid lo trae otra vez; un QFX se vuelve a subir)
y los tickets se vuelven a leer. El libro se rehace por sus caminos, no a mano.

## 4. Si la ronda sale en rojo

La ronda corre sola cada mañana (6:45 en invierno, 7:45 en verano, hora de
Miami) y lo que encuentra se ve al abrir Contabilidad → Cierre; cada rojo
nuevo llega también al teléfono. Hay dos clases:

- **Avisos** (nivel «aviso»): no frenan nada. Las propuestas de la IA que
  esperan, un ticket sin foto, una partida en tránsito de más de 30 días, la
  reserva de impuestos corta, el estimado que vence en 15 días. Se atienden
  cuando se pueda; el detalle dice dónde (la Bandeja, Conciliar…).
- **Lo que detiene** (nivel «detiene»): el mes no se cierra hasta arreglarlo.
  Por orden de gravedad:
  1. **«libro: …» o «cierre guardado: …»** (la cadena, las guardas, los
     permisos, un mes cerrado que cambió). Esto no es del día a día: alguien
     o algo tocó el libro por debajo. No se corrige nada; se mira §3 y se
     avisa. La excepción es **«libro: permisos»** cuando dice que una función
     ajena es SECURITY DEFINER y la API la ejecuta (hoy pasa con una de otra
     sesión): eso lo arregla quien la escribió (o es SECURITY INVOKER, o se le
     quita la API con el `revoke` que trae el detalle). Hasta entonces no se
     cierra, a propósito.
  2. **«banco: …»** (cargos sin clasificar, cuentas sin conciliar al fin de
     mes, archivos que no llegan al último día, un casado que se contradice).
     Es trabajo normal: la Bandeja y Conciliar. Una tarjeta que corta su
     statement a mitad de mes se concilia igual al último día del mes con su
     actividad reciente importada hasta ese día.
  3. **«estados: …», «puentes: …», «obras: …», «activos: …»**: el detalle
     dice la cifra y dónde bajar a ella; casi siempre es un papel que falta o
     una regla que corregir.

Cuando todo lo que detiene está en verde, «Cerrar» pide la confirmación
escrita (`CERRAR OCTUBRE 2026`) y cierra. Si algo entró entre la revisión y el
toque, lo vuelve a revisar dentro del mismo cierre: nadie postea mientras.

## 5. Cómo se corrige un mes cerrado (la regla A)

Un mes cerrado **no se reabre**. Hay tres casos, y los tres entran en el mes
abierto:

1. **Un error en un asiento del mes cerrado** (la cuenta equivocada, un monto
   mal). `fn_reversar(id, 'motivo')`: el reverso cae en el primer mes abierto,
   enlazado al original, y después el asiento bueno. El mes cerrado no cambia
   (su hash y su balanza siguen iguales: por eso la ronda puede vigilarlos).
2. **Un documento que llegó tarde** (el ticket de octubre que apareció en
   noviembre). Su puente lo postea el primer día del mes abierto con la nota
   de documento tardío en la procedencia. Nada que hacer a mano.
3. **Los ajustes del CPA** (lo que el contador cambia al revisar el año, o la
   apertura). Entran fechados en el mes abierto en que los entrega, con
   `tipo = 'ajuste_cpa'`, `afecta_periodo` = el período cerrado que corrigen
   (`'2026-10'`, `'2026'`, `'2026-09-APERTURA'`) y su motivo; los estados de
   ese período los enseñan en la vista «con ajustes posteriores». Un ajuste a
   la apertura va solo con cuentas de balance, contra 3900. En la app: un
   asiento a mano con tipo «ajuste del CPA» y el período que corrige.

Lo que no existe: «reabrir octubre un momento», «borrar y volver a postear»,
«editar la fecha». Si alguien lo pide, la respuesta es uno de los tres casos de
arriba.

## 6. Lo que se hace cada mes, en orden

1. Importar el banco hasta el último día del mes (Plaid lo hace solo; una
   tarjeta que corta antes, su actividad reciente en QFX).
2. Bandeja: cada cargo casado o clasificado («Así es» a la propuesta de la IA).
   Los pagos a quien cobra por horas salen como «Mano de obra · {persona}»:
   se reparten por sus horas con «Así es» (no se clasifican a mano: el costo
   de la obra los contaría dos veces, y la lista del cierre lo avisa).
3. Conciliar: cada cuenta al último día del mes, y «Confirmar».
4. WIP (con c12): en cada obra de precio fijo, el **costo total estimado** a
   hoy (no puede ser menos que lo gastado); una obra que no toca este mes, «Dejarla
   fuera este mes» con su nota. Después «Postear el ajuste»: un asiento el
   último día del mes que se deshace solo el día 1. Si se mueve algo de la obra
   después de postear, se vuelve a postear (la lista del cierre lo pide).
5. Facturas (con c11, desde el corte): las que el aviso 64 dice cobradas en el
   libro se marcan pagadas en la ficha de la obra (todavía nada lo marca solo).
6. Subs y 1099 (con c14): a cada pago «sin nombre» decirle de quién es, de lo
   «sin clasificar» decir si fue servicio o no, y tener al día el COI de quien
   trabajó en el mes (filas 160 y 179 del cierre: avisan, no detienen).
   **Nunca se teclea un TIN en el SQL Editor**: va en la ficha, con el código
   del teléfono.
7. Nómina (con c15, desde enero de 2027): cada nómina subida, posteada y
   con sus cargos de Gusto casados (Nómina → Cargos de Gusto; la cuota
   mensual, «a su gasto»). Al terminar el mes, Nómina → Ajustes → «Repartir a
   las obras» la bolsa del burden. Cada trimestre, «941 · 940 · RT-6» con lo
   que presentó Gusto. Filas 180 a 183 del cierre: las tres primeras detienen.
   La nómina pide el código del teléfono.
8. Cédula de corte (con c13): al último día del mes, lo que salga «no cuadra»
   o «sin auxiliar» se explica ahí mismo o se le escribe su renglón a mano
   (fila 178 del cierre: avisa desde noviembre de 2026).
9. Cierre: la lista en verde → «CERRAR OCTUBRE 2026» → «Exportar» (el mayor y el
   PDF al bucket `cierres`, y por correo). El bucket pide el código del
   teléfono.
10. Si hay activos: «Postear depreciación» antes de cerrar (la lista lo pide).
11. Comparar con QuickBooks mientras dure el paralelo (Estados → QuickBooks).

## 7. Lo que apagar y encender, si hace falta

- La ronda: `select fn_cierre_config('{"ronda_activa": false}');` (y `true`).
- Los avisos al teléfono: `select fn_cierre_config('{"aviso_push": false}');`.
- El % de la reserva de impuestos (cuando lo diga el CPA):
  `select fn_cierre_config('{"reserva_pct": 25}');`.
- El código del teléfono en la entrada, de urgencia (nadie entra):
  `alter role authenticator reset pgrst.db_pre_request; notify pgrst, 'reload config';`
  (s1-mfa.sql).
- La IA contable: `update contador_config set activa = false where id = 1;`
  (c8); la Bandeja sigue como siempre.
