# Lo que hay que pegar (21-nov)

## La Bandeja nueva («Dímelo con tus palabras») y las cuentas en inglés

Lo pediste el 16-nov («era mucho más fácil en QuickBooks»; «la contabilidad y
la parte operativa no trabajan como una sola») y el 21-nov decidiste que las
cuentas y los reportes vayan en inglés. Son **dos capas nuevas**. No cambia
ninguna de las que ya pegaste (ni c6, ni c8, ni c10): no hay que volver a
pegar nada de antes.

Hazlo en este orden. Cada archivo se pega entero en el SQL Editor de Supabase
y se le da a «Run». Se pueden pegar dos veces: no cambian ningún dato.

| # | Qué | Filas que salen |
|---|---|---|
| 1 | `docs/conta/c17-bandeja.sql` | **8**, todas empiezan por «ok:» |
| 2 | `docs/conta/c17-pruebas.sql` | **30**, todas en `true` (u «omitida» con su porqué) |
| 3 | `docs/conta/c18-fiscal.sql` | **6**, todas empiezan por «ok:» |
| 4 | `docs/conta/c18-pruebas.sql` | **10**, todas en `true` |
| 5 | Volver a desplegar la función `contador` | `?paso=salud` dice `"dimelo": true` |
| 6 | Publicar la app (v308) | |

### 1. `c17-bandeja.sql`: lo que tiene que decir

- **`version`:** «ok: 2026112101».
- **`tablas`:** «ok: bandeja_config, bandeja_memoria, bandeja_dimelo y
  bandeja_hechos, con RLS».
- **`funciones`:** «ok: 40 funciones fn_bandeja_*, ninguna SECURITY DEFINER».
- **`configuracion`:** «ok: lo de «entra solo» encendido (tope $500.00);
  «Dímelo» encendido (esfuerzo medium)». Encendido no quiere decir que algo
  entre solo: no entra nada hasta que tú marques «que lo siguiente entre solo»
  en un comercio.
- **`categorias`:** «ok: 8 grupos, 36 categorías».
- **`tareas`:** «ok: mxp-bandeja-solo-manana («18 11 * * *»),
  mxp-bandeja-solo-tarde («54 20 * * *»)». Son las 6:18 de la mañana y las
  3:54 de la tarde de Miami (una hora más en verano). Si esa fila no empezara
  por «ok:» (dice «FALTA alguna de las dos tareas»), pega el archivo otra vez;
  si sigue igual, avísame: no frena nada (lo que tiene que entrar solo entra
  al abrir la Bandeja).
- **`control`:** «ok: los cuadres de la Bandeja están en verde».
- **`siguiente`:** te recuerda los pasos 5 y 6.

**Si sale un error que empieza por «c17-bandeja NO se aplicó, no se tocó
nada»**, dice qué falta. Cópiamelo tal cual: no pasó nada en la base.

### 2. `c17-pruebas.sql`

Tarda unos segundos (en el banco de pruebas, tres). Salen 30 filas; la última columna tiene que
ser `true` en todas. Las pruebas montan sus propios movimientos («BDIECISIETE
…») y los deshacen: al terminar no queda nada (la fila 30 lo comprueba).

Si el SQL Editor deja de esperar, la corrida sigue. Se lee después con:

```sql
select * from pruebas.c17_resultado order by n;
```

### 3. `c18-fiscal.sql`: lo que tiene que decir

- **`version`:** «ok: 2026112101».
- **`forma`:** «ok: Form 1120 (C-corp), PENDIENTE de confirmar con el CPA (el
  paquete lo avisa)». Es lo esperado: mira «Lo que tienes que hacer tú», abajo.
- **`lineas`:** «ok: 1120: 36, 1120-S: 36, 1125-A: 5».
- **`cuentas`:** «ok: 90 cuentas con su nombre en inglés y su línea; 0
  imputables sin línea propia». Si has dado de alta alguna cuenta después del
  plan original, dirá cuántas van «sin línea propia»: salen en el paquete con
  la línea de su tipo y marcadas, hasta que se les dé la suya.
- **`control`:** «ok: los cuadres del mapeo fiscal están en verde».
- **`siguiente`:** te recuerda publicar.

### 4. `c18-pruebas.sql`

Salen 10 filas, todas en `true`. También queda en
`pruebas.c18_resultado`.

### 5. Volver a desplegar la función `contador`

Supabase → Edge Functions → `contador` → pega el `index.ts` nuevo
(`supabase/functions/contador/index.ts`) y despliega, con «Verify JWT»
apagado, como las otras veces. No hay ninguna llave nueva que poner.

Para comprobarlo, abre `…/functions/v1/contador?paso=salud`: tiene que decir
`"dimelo": true`. Mientras no la despliegues, la caja «Dímelo» contesta «la
función que está desplegada es anterior al «Dímelo»»; lo demás funciona.

### 6. Publicar

Dime «publica» y sale la v308.

## Lo que vas a ver

- **En la Bandeja, cada movimiento dice UNA cosa** («Es un gasto de «Material»
  de la obra …: $245.37») con un botón grande, «Así es».
- **Debajo, una caja: «¿Qué es? Dímelo con tus palabras».** Escribes lo que
  es, como se lo dirías a alguien, y te contesta una sola propuesta con «Así
  es» y «No, es otra cosa». Si no lo encuentra, te dice qué le falta. Nada se
  registra hasta que tocas «Así es».
- **«Más opciones»** guarda la lista larga: las categorías ordenadas en dos
  niveles (Costo de obra, Gastos generales, Otros gastos, Personal; Cobro de
  obra, Otros ingresos, Préstamo o aporte, Entre tus cuentas) y los botones de
  antes.
- **Arriba, «Decide por grupo»:** los comercios con varios movimientos. Una
  respuesta vale para todos los suyos. Si marcas «Y que lo siguiente de … entre
  solo», lo que llegue después de ese comercio entra solo.
- **«Registrado solo»:** lo que entró así, con «Deshacer». Lo deshecho vuelve
  a la Bandeja y ya no entra solo.
- **En Estados**, los nombres van en inglés (un enlace los pone en español) y
  hay un apartado nuevo, «Para el contador»: el paquete del año, para
  descargar o imprimir.

## Lo que entra solo y lo que no

Entra solo **únicamente** el cargo de un comercio para el que tú marcaste «que
lo siguiente entre solo», hasta $500 cada uno, si nada lo frena.

**Nunca** entra solo, lo marques o no: un depósito, un cobro, un Zelle (a una
persona o de una persona), un cheque, el cajero, la nómina, un traspaso, un
préstamo, lo que parece duplicado y lo que ya deshiciste una vez. Eso siempre
te lo pregunta.

Los pagos a la cuadrilla siguen como desde el 15-nov: eso no se tocó.

## Lo que tienes que hacer tú

1. **Preguntarle al contador** si la empresa presenta el **Form 1120**
   (C-corp) o el **Form 1120-S** (S-corp). El paquete sale con el 1120 y lo
   avisa en su primera línea. Cuando te conteste: Estados → «Para el contador»
   → elige el formulario y marca «El contador ya confirmó este formulario».
   Los números no cambian; cambia en qué línea va cada cuenta.
2. **La primera vez, usa «Decide por grupo».** Con los comercios que se
   repiten (la ferretería, la gasolina, lo personal) se va casi toda la
   Bandeja en unos minutos.
3. **Un préstamo nuevo** (el dinero que te deposita un prestamista): la
   Bandeja lo registra como deuda con un toque. Dar de alta el préstamo con
   su contrato, para que sus cuotas se repartan entre capital e intereses,
   sigue siendo conmigo: avísame cuando llegue uno.

## Si algo sale mal

- **Un rojo en `control`** de cualquiera de los dos archivos: cópiamelo. No
  toques nada más.
- **Para apagar lo de «entra solo»** sin esperar a nadie: Bandeja → «Lo que
  recuerdo» → quita la marca de «Dejar que entre solo lo que yo marque aquí».
  Ese es el camino: queda escrito quién lo apagó. (Si la app no abriera, el
  apagado de urgencia desde el SQL Editor está en `docs/conta/OPERACION.md`,
  apartado 7.)
- **Para quitar las dos capas** no hace falta borrar nada: sin publicar la
  v308, la app no las usa.
