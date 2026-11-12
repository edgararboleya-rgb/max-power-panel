# Fase 12 · Cédula de corte, W-9, COI y 1099
**12a · 23 – 29 nov (semana corta) · 12b · 7 – 13 dic**
**🔵 AZUL la cédula y el criterio del 1099 · 🟢 VERDE campos, reporte y cuadre · ▶ W-9 y COI; balanza al 30-nov**

> La apertura única ya está cargada al 30-sep (f04). Aquí se comprueba que cada
> saldo del balance **tiene su auxiliar debajo**, y se deja el 1099 apuntando a
> donde toca.

## Tú

1. **Semana 10:** juntar el **W-9 (TIN, dirección, tipo de entidad) y el
   certificado de seguro (COI) de cada sub.** Siempre falta alguno — por eso en
   noviembre y no en enero, cuando ya no contestan el teléfono.
2. **Semana 10:** decidir con el CPA el método libro de depreciación, si
   Gustavo cobra por W-2 o 1099, y qué ayudante por hora es empleado y no sub
   (F.S. 440.10). Los ayudantes por hora van por Gusto desde el 1-ene.
3. **Semana 12:** la **balanza de QuickBooks al 30-nov** y los statements de
   noviembre. Aporta o valida el desglose por obra abierta (QuickBooks no lo
   trae): retención y costo acumulado.
4. **Decisión:** el **1099 de 2026 sale de QuickBooks** —es el libro de ese
   año—, cruzado contra `trabajos_externos`, y se presenta antes del
   **1-feb-2027**. La app produce el de 2027 en enero de 2028.

## 🔵 Azul — se crea (`/effort max`) *(chico)*

- **La cédula de corte:** qué auxiliar sostiene cada saldo de balance y de
  dónde sale — CxC por factura con retención por obra; tickets abiertos por
  proveedor (statement de cada supply); saldo de cada tarjeta por statement;
  cada préstamo por carta, partido corriente/largo plazo; seguros prepagados
  (póliza, meses que faltan); nómina devengada del último período **partida en
  dos años**; WIP por obra (`wip_schedule`); activos fijos con costo y
  depreciación acumulada de la cédula del CPA 2025 + altas 2026. **Cada
  auxiliar cuadra contra su cuenta o se explica.**
- **El criterio del pago reportable:** base caja; umbral en
  `conta_config('umbral_1099', 2000)` confirmado cada diciembre con el CPA; se
  excluye lo pagado con tarjeta (lo reporta el procesador) y a corporaciones;
  cuentan los asientos pagados desde 1010/1020.

## 🟢 Verde — se trabaja encima (`/effort auto`)

- Campos en `proveedores` / `externos_equipo` —**nunca en `contratistas`, que
  son los GC clientes**—: `tin` (solo dueño por RLS), `direccion`,
  `tipo_entidad`, `w9_ruta`, `w9_recibido_el`, `coi_vence`, `coi_ruta`,
  `wc_exento`. Chip «vence en N días» como el de `documentos_empresa`.
- Reporte 1099 diseñado y probado con datos parciales; e-file por IRIS o
  Track1099 en enero de 2028.
- Carga de `activos_fijos`.
- **Semana 12:** cuadre del app contra la balanza de QuickBooks al 30-nov con
  la vista de comparación de f04, y la cédula de corte cargada y cuadrada,
  saldo por saldo.

## Entregable
`docs/conta/c13-cedula.sql` (la cédula de corte) y `docs/conta/c14-subs.sql`
(W-9, COI y 1099) · las páginas «Cédula de corte» y «Subs y 1099» de
Contabilidad · las filas 160, 178 y 179 del cierre en `c9-cierre.sql`.
(El nombre `c12` lo tomó el WIP de la Fase 10: `c12-wip.sql`.)

## Terminó cuando
Cada saldo del balance al 30-nov tiene su auxiliar debajo y cuadra; el app
amarra contra QuickBooks al 30-nov salvo diferencias de criterio escritas; el
reporte te dice a quién le falta el W-9 o el COI; y está escrito que **el 1099
de 2026 sale de QuickBooks**.

## Lo construido (12-nov) · la parte 12a

Adelantada al 12-nov (Edgar pidió aprovechar el día). La 12b (el cuadre
contra la balanza de QuickBooks al 30-nov) sigue en su semana: necesita esa
balanza.

### La cédula de corte (c13, `fn_cedula_*`)
- **Una fila por cuenta de balance a una fecha**: saldo en el libro, qué
  auxiliar lo sostiene y de dónde sale, lo que suma, la diferencia y el
  estado. **Solo mira**: no postea ni corrige nada; escribe solo su
  configuración, los renglones a mano y las explicaciones.
- **Cinco estados**: *cuadra* (el auxiliar suma lo mismo y vale para ese
  día), *del libro* (el «auxiliar» es el propio libro ordenado —patrimonio,
  use tax— o un papel de otro día llevado con el libro: no puede no sumar,
  así que no se pinta en verde ni pide nada), *explicada* (Edgar escribió
  por qué, con fecha; se queda vieja si el saldo cambia), *no cuadra* y
  *sin auxiliar* (dice por qué: «llega con la nómina», «se escribe a mano»).
  Cada fila dice con qué se sostiene: un papel, las partidas del libro, el
  propio libro, o un papel de otro día.
- **Lo que no deja pasar** (de la revisión contra el dinero): un banco solo
  cuadra con la conciliación **de ese mismo día**; saldos sueltos de signo
  contrario en dos obras no se compensan; a las pólizas solo se les lleva
  hacia atrás lo que es de la póliza.
- **El resumen amarra**: Activo = Pasivo + Patrimonio + **Resultado sin
  cerrar**; el reparto de un préstamo entre corriente y largo plazo va
  aparte y una sola vez.
- **Fila 178 del cierre** (aviso, no detiene): avisa desde noviembre de 2026
  (`cedula_config.avisar_desde`).

### W-9, COI y 1099 (c14, `fn_subs_*`)
- **Una ficha por sub y por ayudante que cobra sin nómina**, enlazada a su
  proveedor (o a su perfil): nombre legal, comercial, tipo de entidad,
  dirección, «se le reporta» (sí, no, por decidir) y sus papeles (W-9, COI
  con su vencimiento, exención de workers' comp) en el bucket privado «subs».
- **El TIN** vive aparte (`subs_tin`): solo el dueño **con el código del
  teléfono**; la pantalla y las vistas solo enseñan los 4 últimos. Entero
  solo sale en la hoja del 1099 que se baja por la app con el código. Desde
  el SQL Editor no se guarda ni se lee (así no cae en el registro del
  servidor), y ningún mensaje repite lo tecleado.
- **El criterio del pago reportable**, en base caja: lo pagado por el banco
  a cada uno, con su parte de servicio. Lo pagado con tarjeta, aparte (lo
  reporta el procesador); a corporaciones no (salvo la excepción escrita en
  su ficha); el umbral (2,000 de fábrica, **sin confirmar**) se confirma
  cada año. Lo que pasa de una cuenta por pagar a otra (la retención) lleva
  su servicio consigo; lo que no se puede seguir sale **sin clasificar**,
  nunca «no servicio». Lo pagado de un bolsillo sale «por otro camino» y se
  marca «pagado» pago por pago si el CPA dice que cuenta.
- **«Se le reporta» y el tipo de entidad llevan fecha** (tramos): quien se
  hace S-corp o entra a la nómina a mitad de año no reescribe lo ya pagado.
- **Nadie se queda fuera callado**: la hoja dice qué no entra y por qué
  (pagos sin nombre, sin clasificar, por otro camino) y si salió completa;
  18 controles.
- **2026 es parcial** (el libro de la app empieza el 30-sep): el 1099 de
  2026 sale de QuickBooks y la hoja de la app sirve para cruzar.
- **Filas del cierre** (avisos, no detienen): la **160** (COI vigente de cada
  sub con trabajo en el mes, que antes era un marcador) y la **179** (W-9 y
  TIN de cada uno con un pago de servicio en el mes).

### c11, lo que producción tenía y el banco no
Al pegar c11 en producción, 7 pruebas dieron falso por dos cosas de la base
de la app: el índice único `ux_facturas_hito` (una sola fila de `facturas`
por hito, contando las anuladas) y el candado de Storage que no deja borrar
por SQL. El arreglo: al emitir la factura nueva de un hito, la anulada lo
suelta (queda apuntado en `emision_soltados`); las pruebas no borran de
Storage ni crean índices y no se quedan esperando a la app (500 ms). El
banco ya trae esa réplica (`pruebas/conta/06-produccion-facturas.sql`).

### Cómo se probó
Fable en las dos bases, la revisión contra el dinero y la seguridad, sus
arreglos y la revisión final; Opus 5.5 en la pantalla y la verificación desde
cero. Desde cero (con y sin la réplica de producción) y por el camino exacto
de producción (v301 + c11 + c13 + c14 + c9): todas las suites en verde
(c13 41, c14 48, c11 57), concurrencia, volumen (3,600 asientos), el TIN
buscado en toda la base y en el registro del servidor, y la pantalla
(`pantalla.js`).

### ▶ Lo que queda para Edgar y el CPA
Todo configurable, nada afirmado de memoria: el umbral del 1099 de cada año;
a qué entidades no se reporta; si el material que factura un sub cuenta; lo
pagado de un bolsillo; la fecha que cuenta (libro o banco); los ayudantes
por hora de 2026 (1099 o empleados); si al exento de workers' comp le basta
su exención; la LLC de un socio (línea 1 del W-9); y de la cédula, el
patrimonio por libro o por papel, el use tax contra cada DR-15 y el reparto
del préstamo cada mes o al año.

