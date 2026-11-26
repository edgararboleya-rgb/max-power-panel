# Pendientes de max-power-panel

Última revisión: 26-nov-2026. Este archivo es la lista de trabajo de la app y se mantiene al día aquí.

**Reglas:** el uso se reinicia el viernes, y para mejorar las apps se usa como máximo el 60 %. Cada viernes se propone el plan de la semana, empezando por fallas y prioridad alta. El jueves se proponen puntos chicos si sobra uso. Nada se cambia sin que Edgar apruebe. Al terminar cada punto, se marca hecho con la fecha y se explica en español sencillo. Los puntos se hacen en Opus cuando da el mismo resultado; Fable solo en el punto que lo necesite para salir bien, y antes de empezar se dice por qué. Nunca se baja la calidad ni la seguridad por ahorrar uso.

**Códigos:** C- es contabilidad y O- es operaciones. F = falla, P = fase sin terminar, D = diseño, N = herramienta nueva.

## a. Fallas

- **C-F1**, alta, chico: pegar y confirmar lo de la línea de crédito; hasta entonces la app confunde sus pagos y retiros con las cuotas del préstamo, y sus tarjetas no se contestan.
- **C-F2**, alta, chico: si escribes un monto con un espacio, como «6 50», la app lo toma como 650 en vez de avisarte.
- **C-F3**, alta, mediano: si la Bandeja nueva no carga bien, vuelve el botón viejo de la IA, que puede anotar la cuota de un préstamo como si fuera un gasto.
- **C-F4**, media, chico: cuando le cuentas con tus palabras un pago de la línea de crédito, la IA dice que hay que darla de alta, y ya lo está.
- **C-F5**, media, mediano: la IA de antes no sabe de la nómina; si apruebas lo que propone para un cargo de Gusto, se salta la página de Nómina.
- **C-F6**, media, mediano: la IA gasta de más: propone en cargos que la Bandeja ya sabe qué son, y lo de una consulta que se corta no se suma al tope del mes.
- **C-F7**, media, mediano: si devengas las horas de un ayudante cuyo Zelle clasificaste a mano, el costo queda dos veces en el mes.
- **C-F8**, media, chico: si un ayudante tiene un solo nombre en la app, un pago a otra persona que se llame parecido puede entrar solo como pago de sus horas.
- **C-F9**, media, mediano: algunos totales los suma el teléfono y no la base, y pueden no cuadrar con el libro por un centavo.
- **C-F10**, media, mediano: las horas de diciembre que se pagan en enero caen en el año siguiente; hay que preguntarle al CPA cómo lo quiere.
- **C-F11**, media, mediano: lo que le retienes a un subcontratista no queda como dinero que le debes; entra al costo el día que le pagas.
- **C-F12**, media, mediano: si rebota el cheque de un cliente, los libros quedan bien, pero en Proyectos la factura sigue como cobrada.
- **C-F13**, media, mediano: otros cargos de un prestamista, como un seguro o una comisión, salen cada mes como si fueran la cuota.
- **C-F14**, media, chico: si deshaces una corrección de monto en la Bandeja, la corrección se queda puesta y la app no te lo dice.
- **C-F15**, media, chico: si un préstamo nuevo del mismo prestamista llega con el nombre de la línea de crédito, la app lo toma por la línea y no deja corregirlo (depende de tu respuesta).
- **C-F16**, baja, chico: varios textos de la Bandeja confunden: avisos que se contradicen, una pregunta que manda a la caja equivocada y mensajes técnicos.
- **C-F17**, baja, chico: una compra cuya descripción diga «Gusto» o «payroll» sale como cargo de nómina hasta que la clasificas a mano.
- **C-F18**, baja, mediano: si anulas la factura de un hito antes del 1 de enero, no hay forma de volver a facturarlo.
- **C-F19**, baja, chico: en el teléfono, una fila de la balanza del paquete del contador sale descolocada.
- **C-F20**, baja, chico: algunas pruebas de la contabilidad salen en rojo ciertos días del mes sin que haya nada roto.
- **C-F21**, baja, chico: uno de los archivos del banco que se pegan está casi en su tamaño máximo, y el próximo cambio podría partirlo mal.
- **C-F22**, baja, mediano: la portada de Contabilidad carga a tiempo, pero justo; con más datos podría tardar.
- **O-F1**, alta, chico: la tabla de horas estimadas de las obras quedó sin candado; cualquiera con una cuenta en la app, aunque esté dado de baja, las puede ver.
- **O-F2**, alta, mediano: el repositorio público trae nombres de obras y clientes, montos de estimados y tus precios, y cualquiera en internet los puede leer (decides tú cómo sacarlos).
- **O-F3**, alta, chico: la clave que manda los avisos al teléfono del equipo estuvo a la vista y no se ha cambiado; con ella alguien podría mandar avisos falsos.
- **O-F4**, media, chico: la función del código del teléfono se puede llamar sin haber entrado; hay que cerrarla con cuidado para no romper la entrada.
- **O-F5**, media, chico: revisar dos piezas de la base que se saltan el candado: una vista que no usa nada y la lista de qué horas pagó cada nómina.
- **O-F6**, media, chico: confirmar que el portal no le enseña al cliente una factura que anulaste.
- **O-F7**, baja, chico: el portal del cliente y el del contratista cargan una versión vieja del diseño.
- **O-F8**, baja, chico: si el servidor falla, el portal reintenta con la llave del cliente en la dirección, donde puede quedar guardada.
- **O-F9**, baja, chico: ajustes chicos de seguridad que pide Supabase: dos funciones sin su ruta fija y una extensión en el lugar público.
- **O-F10**, baja, mediano: a la base le faltan índices y algunas reglas se revisan de más; hoy no se nota, pero irá más lenta con más datos.

## b. Fases sin terminar

- **C-P1**, alta, mediano: cerrar octubre de verdad: Bandeja limpia, cada cuenta cuadrada con su estado de cuenta al 31-oct y la utilidad comparada con QuickBooks.
- **C-P2**, alta, grande: cuadrar la app con QuickBooks al 30 de noviembre y llevar diciembre en los dos a la vez (del 14 al 27).
- **C-P3**, alta, chico: dejar lista la facturación desde la app para el 2 de enero.
- **C-P4**, alta, chico: dejar lista la nómina para la primera corrida en Gusto, el 8 de enero.
- **C-P5**, alta, mediano: apagar QuickBooks a fin de año y probar de verdad que el respaldo de la base se puede recuperar.
- **C-P6**, media, mediano: en enero, cerrar diciembre en la app y sacar los 1099 de 2026 antes del 1 de febrero.
- **C-P7**, media, chico: poner el costo y lo facturado de las obras que ya iban antes del 30 de septiembre; sin eso, el cierre se detiene.
- **C-P8**, media, chico: terminar el costo por obra: faltan dos datos tuyos y validar una obra que conozcas.
- **C-P9**, media, chico: que la lista del cierre del mes revise también la Bandeja nueva y las cuentas en inglés.
- **C-P10**, media, mediano: dar de alta préstamos y líneas de crédito desde la app, sin la consola técnica.
- **C-P11**, media, mediano: poder cobrar desde la Bandeja una factura vieja de antes del cambio a la app.
- **C-P12**, media, mediano: que el paquete de cada cierre salga en inglés para el contador y te llegue por correo.
- **C-P13**, media, mediano: terminar el paquete de fin de año para el contador (balanza, mayor, activos y 1099).
- **C-P14**, media, grande: recordatorios de factura vencida, estado de cuenta mensual y aviso de pago recibido, como QuickBooks.
- **C-P15**, media, mediano: que el cliente pueda pagar con tarjeta, y con un botón «Pay now» dentro de su portal.
- **C-P16**, media, chico: que no se pueda pagar a un subcontratista sin W-9 o con el seguro vencido.
- **C-P17**, media, grande: facturar al contratista general por renglones (AIA), con la retención y los papeles, y amarrar cada orden de cambio a su factura.
- **C-P18**, media, grande: ver cuánto dinero vas a tener en las próximas semanas con lo que te deben y lo que debes.
- **C-P19**, media, grande: que cada obra terminada le proponga al estimador corregir precios y horas con lo que de verdad costó.
- **C-P20**, baja, grande: el contador de guardia: una IA que te explica por qué algo no cuadra y te avisa de lo raro, sin anotar sola.
- **C-P21**, baja, grande: preparar en la app los pagos a subs y proveedores, y mandarlos al banco en un solo lote.
- **C-P22**, baja, chico: un acceso de solo lectura para tu contador.
- **C-P23**, baja, mediano: detalles de los estados: ver un trimestre, el porcentaje de cada gasto y cargar la balanza de QuickBooks desde la app.
- **C-P24**, baja, mediano: partir un Zelle que trae horas y reembolso, y corregir parte de una factura con una nota de crédito.
- **C-P25**, baja, chico: opciones que faltan en el banco: elegir qué facturas de un proveedor pagas y cambiar el tipo de una partida.
- **C-P26**, baja, chico: que los gastos fijos de cada mes se registren solos, y que la app lleve sola el impuesto de uso en vez de solo preguntarlo.
- **C-P27**, baja, chico: completar la guía de qué hacer si algo falla, y las decisiones pendientes de la portada.
- **O-P1**, media, mediano: guardar en el repositorio una copia del código del portal, el asistente y el correo, que hoy no tiene respaldo aquí.
- **O-P2**, media, grande: que la IA lea la cotización del proveedor renglón por renglón y te proponga antes de tocar el estimado.
- **O-P3**, baja, mediano: que un estimado congelado no recalcule sus renglones con los precios de hoy.
- **O-P4**, baja, mediano: ligar cada levantamiento a su obra.
- **O-P5**, baja, mediano: comparar un estimado grande de la app con uno hecho aparte, para calibrar la fórmula.
- **O-P6**, baja, chico: un margen propio para las cotizaciones del proveedor en un estimado concreto.
- **O-P7**, baja, grande: separar del todo las dos empresas dentro de la app (lo aplazaste tú).

## c. Diseño

- **C-D1**, media, mediano: letra y botones más grandes en Contabilidad, como en el resto de la app.
- **C-D2**, media, mediano: juntar las 15 pestañas de Contabilidad en 4 o 5 grupos con nombres sencillos.
- **C-D3**, media, mediano: revisar la Bandeja de uno en uno en el teléfono, con botones grandes y cuántos faltan.
- **C-D4**, media, mediano: menos texto en cada tarjeta, con lo demás detrás de «ver detalle».
- **C-D5**, media, mediano: el cierre del mes como un circuito que se enciende paso a paso.
- **C-D6**, media, grande: pasar la Bandeja vieja de «Más opciones» al lenguaje sencillo de la nueva, sin códigos de cuenta.
- **C-D7**, baja, chico: una marca siempre visible de que el libro está sano y revisado hoy.
- **C-D8**, baja, chico: en la portada, cuántas semanas de gastos cubre el dinero que tienes.
- **C-D9**, baja, chico: poder decir con tus palabras qué es un grupo de cargos repetidos.
- **C-D10**, baja, mediano: que el anticipo de un cliente se vea en su obra.
- **O-D1**, media, mediano: un botón «Aa» para agrandar la letra y subir el contraste, para leer al sol en la obra.
- **O-D2**, media, mediano: que el estimador te avise si el impuesto puesto no es el del condado de la obra.
- **O-D3**, baja, grande: modo oscuro en toda la app.
- **O-D4**, baja, mediano: iconos dibujados en vez de emojis en los botones.
- **O-D5**, baja, chico: que el portal del cliente se abra en su idioma.
- **O-D6**, baja, chico: si el cliente abre un enlace roto, un botón para llamarte o escribirte.
- **O-D7**, baja, chico: «Olvidé mi contraseña», para que el equipo no tenga que pedírtela.

## d. Herramientas nuevas

- **O-N1**, media, mediano: calculadoras eléctricas en el teléfono: carga del servicio, caída de tensión y llenado de tubería.
- **O-N2**, media, mediano: que la cuadrilla marque entrada y salida en la obra con la ubicación.
- **O-N3**, media, chico: recordarle solo al cliente la propuesta que no ha firmado.
- **O-N4**, media, mediano: fotos de obra con flechas, notas y antes y después.
- **O-N5**, media, mediano: financiamiento para que el cliente pague un panel o un generador a plazos.
- **O-N6**, media, grande: planes de mantenimiento anual que se cobran solos y agendan la visita.
- **O-N7**, baja, mediano: mensajes de texto al cliente: vamos en camino, la cita de mañana, la inspección.
- **O-N8**, baja, mediano: un formulario en tu página web para pedir servicio, que llegue directo a la app.
- **O-N9**, baja, mediano: hoja de trabajo extra que el cliente o el GC firma en tu teléfono ese mismo día.
- **C-N1**, media, mediano: cobrar el depósito en línea en el momento en que el cliente firma.
- **C-N2**, media, mediano: sacar sola la renuncia de gravamen (lien waiver) cada vez que pagas a un sub.
- **C-N3**, media, grande: ver por obra lo ya comprometido en órdenes de compra y subcontratos, contra lo presupuestado.
- **C-N4**, baja, mediano: reenviar a un correo los recibos de proveedores y que entren solos.
- **C-N5**, baja, chico: llevar las millas de la camioneta para los impuestos.
- **C-N6**, baja, chico: cobrar en la obra con un código QR en tu pantalla.
- **C-N7**, baja, mediano: guardar solos los cierres y reportes en tu Google Drive.
- **C-N8**, baja, mediano: mandar a la IA los cargos del mes de una vez, que sale más barato.

## Lo tuyo, sin gastar uso

- Pegar en Supabase, en orden, los 3 archivos de la línea de crédito (c17-bandeja.sql, c17-pruebas.sql y el SQL de tu base que te pasé por el chat), y después contestar sus tarjetas.
- Buscar en el estado de cuenta del prestamista cuánto del pago de la línea del 18-nov fueron intereses.
- Contestar dos preguntas: con qué nombre llegó al banco el dinero del préstamo a plazo, y si la línea debía algo antes del 1 de octubre.
- Darme los estados de cuenta al 31 de octubre y la balanza de QuickBooks al 30 de noviembre.
- Preguntarle al CPA tres cosas: si el formulario es el 1120 o el 1120-S, cómo quiere que factures el avance de obra y dónde van las horas de diciembre que se pagan en enero.
- Darme el porcentaje de carga de la mano de obra, a qué cuenta van las horas sin obra y una obra terminada que conozcas bien.
- En Gusto: bajar el Payroll journal en CSV y la plantilla de importación, y dar de alta a los ayudantes antes del 11 de diciembre.
- En Facturas → Ajustes: poner los datos de la empresa, el «How to pay», los términos y la retención de cada obra.
- Encender en Supabase el freno a contraseñas filtradas (Authentication).
- Decidir qué hacer con el repositorio público: hacerlo privado (GitHub Pages lo pide de pago) o sacar los archivos con datos del negocio.
- Confirmar si las 3 cláusulas que te protegen (retención, circuitos existentes y edición del contrato) se quedan fijas en los contratos.
- Confirmar qué plan de Supabase tienes, para saber cómo se respalda la base.
- Quitar del entorno de Claude el secreto viejo de api.supabase.com, que ya no sirve.

## Hecho

- 26-nov-2026: comprobado que el arreglo de permisos de la pestaña «Costos» ya estaba pegado; el cierre del mes ya no se frena por eso.
- 22-nov-2026: la línea de crédito aparte del préstamo a plazo, publicada en la app (v309). La pregunta con dos botones iguales ya dice qué hace cada uno, y las pruebas de la Bandeja ya no dependen de los préstamos que tengas. Falta que lo pegues (C-F1).
- 21/22-nov-2026: la Bandeja nueva, con una recomendación por tarjeta y «Dímelo con tus palabras», y las cuentas y reportes en inglés para el contador, pegadas y en uso.
- 17-nov-2026: cuando falta el código del teléfono, la app ya lo dice claro en vez de dar un error confuso.
- 15-nov-2026: los pagos por Zelle a la cuadrilla entran solos al libro, repartidos por sus horas.

---

## Detalle para quien lo haga

Notas técnicas de cada punto y de dónde sale. Nada de datos reales aquí: el repositorio es público.

### Fallas

- **C-F1**: c17 marca 2026112203 (`fn_bandeja_linea`, `bandeja_config.lineas`) y el SQL de datos privado (fuera del repo, estrecha el descriptor del préstamo a plazo y da de alta la línea). Guía: `docs/conta/PEGAR-23NOV.md`. Al 26-nov producción seguía en 2026112202.
- **C-F2**: `fn_bandeja_monto_escrito` (c17) y `montoEscrito` (js/conta.js) quitan todo espacio antes de validar. Además, `abrirOpcion` valida con `montoEscrito` pero manda el texto sin limpiar a la puerta de c6. Hay que rechazar un espacio entre dígitos en las dos capas, con pruebas en c17-pruebas y pantalla.js. Fuente: revisión 6b, 22-nov.
- **C-F3**: el freno a «Según la IA · ✓ Así es» en la cuota de un prestamista vive solo en la pantalla y depende de `sabe`. Si falla `fn_bandeja_leer`, vuelve a aparecer y registra por c8 sin el freno de c17. El candado de verdad va en la función contador o en c8. Fuente: `docs/conta/fases/f19-bandeja.md` (revisión de la quinta vuelta).
- **C-F4**: la regla 7 de las instrucciones de «Dímelo» en `supabase/functions/contador`: con `prestamista.linea` debe contestar «prestamo». Pide volver a desplegar la función y comprobar `prompt_version`.
- **C-F5**: c8 no conoce c15. Habría que excluir de la ráfaga de la IA los débitos de nómina, o mandarlos a Nómina. Fuente: `f11-nomina.md` (lo abierto de la 11b).
- **C-F6**: la IA vieja (c8) sigue proponiendo en cargos que c17 ya conoce. El gasto de una llamada cortada por tiempo no entra en `asistente_uso`, y los precios por token están escritos en dos sitios. Fuente: `f19-bandeja.md`, «Lo que queda pendiente».
- **C-F7**: c3 no ve como pagadas las horas de un Zelle clasificado fuera del reparto de c10, y el control «devengo» pide `fn_horas_devengar`. En el mismo bloque, el aviso 80 de c15 contradice a c3. Fuente: `f11-nomina.md` (11c).
- **C-F8**: el reconocimiento por nombre como palabra entera. Habría que exigir nombre y apellido, o el patrón en Costo por obra → Personas, antes de que entre solo. Fuente: `f09-costo-por-obra.md`.
- **C-F9**: hay `reduce` sobre montos en js/conta.js (Costo por obra, «Registrado solo», pagos a la cuadrilla). Esos totales deben salir de vistas de Postgres. Fuente: `CONTA-PLAN.md` §1 y `f11-nomina.md`.
- **C-F10**: c10 y c12 dan por pagadas las horas al postear la nómina; c15 sí corta a fin de mes. Se decide con el CPA antes del cierre de diciembre. Fuente: `f09` y `f11`.
- **C-F11**: la cuenta 2020 necesita un campo en la app y otra versión del puente de gastos de c3. Fuente: `f10-facturacion-wip.md`.
- **C-F12**: falta diseñar cómo se deshace el «Cobrado» de Proyectos cuando el cheque devuelto entra por la Bandeja. Fuente: `f19-bandeja.md` (quinta vuelta).
- **C-F13**: hay que distinguir por descriptor la cuota de los otros cargos del mismo prestamista; hoy pierden «Según yo» y «clasificar». Fuente: `f19-bandeja.md`.
- **C-F14**: deshacer «anotado por otro monto: corrígelo» deja la corrección. Fuente: `f19-bandeja.md`.
- **C-F15**: pregunta abierta a Edgar en `PEGAR-23NOV.md`. Si el dinero del préstamo a plazo llegó con el mismo texto que los desembolsos de la línea, hay que permitir elegir el préstamo en la lista con un porqué.
- **C-F16**: viene de la revisión 6b y de vueltas anteriores:
  - en la tarjeta de «otra forma», las frases fijas de `bnTextoBanco` y `bnSinIAHTML` contradicen el aviso, y `tiene` cuenta préstamos cancelados;
  - los desembolsos de una línea salen en «Decide por grupo» con la frase de facturas;
  - la pregunta de «Con lo que dice su estado de cuenta» empieza por «Dime cuánto…»;
  - una propuesta vieja de la IA se queda colgada;
  - el pago de tarjeta ofrece la cuenta de Stripe;
  - sale un mensaje técnico tras un cobro parcial;
  - el conteo de «rechazadas» sale inflado.
- **C-F17**: `fn_banco_dice_nomina` mira la palabra entera, salvo en los Zelle. Una salida es dejar fuera las cuentas de tarjeta, lo que cambia c6 y c15 a la vez. Fuente: `f11-nomina.md`.
- **C-F18**: el candado de `qb` no mira las anuladas. Hay que adelantar el corte o que Operaciones cambie `qb`. Fuente: `f10-facturacion-wip.md`.
- **C-F19**: la balanza del paquete del contador a 390 px. Fuente: revisión de c18.
- **C-F20**: en c10-pruebas fallan las pruebas 31, 49 y 53, que dependen del día del mes. Fuente: `pruebas/conta/README.md`.
- **C-F21**: a `c6-banco-parte1.sql` le quedan unos 2 KB hasta el tope del partidor. Fuente: `f11-nomina.md`.
- **C-F22**: la portada de Contabilidad cumple su tiempo con poco margen. Fuente: `tablero-c16.md`.
- **O-F1**: `public.horas_estimadas_fase` tiene la política «leer horas_estimadas_fase» (`es_activo()`), pero RLS está apagado. `authenticated` tiene SELECT. Arreglo: `alter table … enable row level security`. Fuente: asesor de Supabase, 22 y 26-nov.
- **O-F2**: el README dice que no hay datos de clientes, pero `docs/ESTIMADOR-ESTADO-2026-09.md`, `docs/MARINERS-PLAN.md`, `docs/sql/` (carga de un estimado real) y `docs/precios/*.csv` traen nombres, montos y precios. `docs/sql/` es de la sesión de Operaciones.
- **O-F3**: E37 movió el secreto del cartero a Vault, pero su cambio por uno nuevo (E37b, desplegar `notificar`, E37c y la rutina de las 6 AM) no se hizo: al 26-nov solo existe `mxp_secreto_cartero`. `notificar` no verifica sesión. Fuente: `docs/sql/e37*.sql`.
- **O-F4**: `fn_mfa_exigir()` es la función que se corre antes de cada petición de PostgREST (pre-request), y anon puede ejecutarla. Si se le quita el permiso a anon, pueden caer las llamadas sin sesión: hay que probarlo antes en el banco. Fuente: asesor de Supabase y `docs/SECURITY-POLICY.md`.
- **O-F5**: de las 7 vistas SECURITY DEFINER, las 5 `*_equipo` lo son a propósito (E37) y `v_costos_revision` ya filtra por `es_dueno()`. Quedan dos por revisar:
  - `v_ia_medida`, que no la usa nada del repo;
  - `fn_nomina_horas_con_pago()`, que es SECURITY DEFINER, sin freno de dueño y la puede llamar cualquier usuario con sesión: devuelve qué horas pagó cada corrida y su día de pago, sin montos.

  De las 59 funciones SECURITY DEFINER que puede llamar un usuario con sesión, 57 sí frenan con `es_dueno` o con `fn_*_exigir_dueno` (comprobado el 26-nov). Las dos que no son `fn_nomina_horas_con_pago` y `fn_mfa_exigir`, que es la de O-F4.
- **O-F6**: hay que confirmar que la función `portal` filtra las facturas anuladas antes de la primera anulación real. Fuente: `f10-facturacion-wip.md`.
- **O-F7**: `cliente.html` pide `css/styles.css?v=238` y `gc.html` pide `?v=242`. Hay que subirlos con la app y añadirlo a la regla 3 de `docs/PUBLICAR.md`.
- **O-F8**: ante un 4xx, el portal repite por GET con `?t=` o `?g=&p=` (`cliente.html:294-310`, `gc.html:322-327`). Si `portal` ya acepta POST siempre, hay que quitar ese reintento.
- **O-F9**: falta el `search_path` en `fn_plaid_vault_nombre` y `fn_puente_recibo_doc`. `pg_net` está en `public`: se acepta el aviso.
- **O-F10**: según el asesor de rendimiento, hay 138 llaves foráneas sin índice, 42 políticas que reevalúan `auth.*` por fila, 14 tablas con políticas permisivas duplicadas y 13 índices sin uso.

### Fases sin terminar

- **C-P1**: la página de cierre (c9) ya está pegada. Para cerrar faltan la Bandeja de octubre, la conciliación al 31-oct y la comparación con QuickBooks. Fuente: `f08-cierre.md`.
- **C-P2**: f12b es el cuadre contra la balanza de QuickBooks al 30-nov, con la cédula de corte (c13); f13-14 es el paralelo de diciembre. Fuente: `CONTA-PLAN.md` §6 y §9.
- **C-P3**: desplegar la función `facturas`, llenar los ajustes y probar con una obra de prueba. Fuente: `f10-facturacion-wip.md` («Tú»).
- **C-P4**: fijar las columnas de c15 con el CSV real de Gusto y hacer escenas en pantalla.js. Fuente: `f11-nomina.md`.
- **C-P5**: f15 consiste en:
  - apagar `qb` y sus rutinas de pg_cron;
  - retirar la casilla «pagada»;
  - restaurar con pg_restore en un proyecto vacío;
  - poner al día `OPERACION.md`.

  Fuente: `CONTA-PLAN.md` §5.6 y §6.
- **C-P6**: el 1099 de 2026 sale de QuickBooks, que queda solo para consulta hasta abril. Fuente: `CONTA-PLAN.md`.
- **C-P7**: c12 exige desde `wip_config.exigir_desde`. Una apertura con saldo en 1200/2400 la decide el CPA. Fuente: `f10-facturacion-wip.md`.
- **C-P8**: faltan `burden_estandar_pct` y la cuenta de las horas sin obra. Fuente: `f09-costo-por-obra.md`.
- **C-P9**: `fn_verificar_cadena` y el cierre (c9) todavía no miran los controles de c17 ni de c18.
- **C-P10**: `fn_prestamo_guardar` y `fn_bandeja_linea` solo se usan desde el SQL Editor, y los avisos 70 y 75 son fijos. Fuente: `f19-bandeja.md`.
- **C-P11**: c17 no tiene camino para cobrar una factura fuera del libro. Fuente: `f19-bandeja.md`.
- **C-P12**: el paquete del cierre en inglés y por correo, con los adjuntos. Fuente: `f08-cierre.md`.
- **C-P13**: c18 es la primera pieza. El formulario (1120 o 1120-S) está pendiente del CPA. Fuente: `f17-paquete-fiscal.md`.
- **C-P14**: fuente: `QUICKBOOKS-BRECHA.md`.
- **C-P15**: p1 (Stripe) registraría el recargo como anticipo. Hace falta otra versión de p1 y confirmar las reglas de Florida. El «Pay now» del portal es de Operaciones. Fuente: `f10-facturacion-wip.md` y `QUICKBOOKS-BRECHA.md` §2.3.
- **C-P16**: c14 tiene las fichas y las filas 160 y 179 del cierre solo avisan. Fuente: `QUICKBOOKS-BRECHA.md` §3.4 y §4.3.
- **C-P17**: fuente: `CONTA-PLAN.md` y `f18-obra-flujo-caja.md`.
- **C-P18**: sin fechas inventadas. Fuente: `f18-obra-flujo-caja.md`.
- **C-P19**: cada cambio lo aprueba Edgar. Fuente: `f18-obra-flujo-caja.md`.
- **C-P20**: fuente: `f16-contador-de-guardia.md`.
- **C-P21**: un archivo de pagos en lote para el banco. Fuente: `QUICKBOOKS-BRECHA.md`.
- **C-P22**: un rol de solo lectura. Fuente: `QUICKBOOKS-BRECHA.md`.
- **C-P23**: fuente: `f04-estados.md`.
- **C-P24**: fuente: `f09-costo-por-obra.md` y `f10-facturacion-wip.md`.
- **C-P25**: fuente: `f06-banco.md`.
- **C-P26**: fuente: `QUICKBOOKS-BRECHA.md` y `f07-categorizacion.md`.
- **C-P27**: falta `OPERACION.md` (el calendario del mes y los problemas típicos). Las decisiones pendientes de la portada son:
  - `fn_tablero_nomina_criterio()`;
  - los términos de las facturas;
  - la regla del WIP en ventas.

  Fuente: `tablero-c16.md`.
- **O-P1**: la app llama a `portal`, `cerebro`, `correo`, `reparto` y `qb`, que no están en `supabase/functions/`, y tampoco están los SQL de etapa6. Hay que traer una copia sin secretos o dejar escrito dónde vive cada una.
- **O-P2 a O-P7**: fuente: `docs/ESTIMADOR-ESTADO-2026-09.md` y `js/alcance.js` (las cláusulas, en las líneas 6229-6233).

### Diseño y herramientas nuevas

- Los puntos de diseño salen de mirar la app a 390 px en Chromium, de la escena f19 de pantalla.js y de las notas de las fases (`f19-bandeja.md`, `tablero-c16.md`).
- Las herramientas nuevas salen de comparar con lo que traen hoy ServiceTitan, Jobber, Housecall Pro, Procore, Buildertrend, Knowify y QuickBooks, y de buscar que no exista ya en `js/` y `docs/`.
- Antes de empezar cualquiera, se confirma con Edgar el alcance.
