# Pruebas del panel

Se corren con el Chromium que ya está instalado, sin tocar la nube ni pedir
sesión: la lógica que se prueba es **pura** (entra un dato, sale un dato) y se
alcanza por `window.MXP_PRUEBA`.

```
NODE_PATH=/opt/node22/lib/node_modules node pruebas/e0.js
```

| Archivo | Qué comprueba |
|---|---|
| `e0.js` | E0 · «quién pone el material» y los estimados de MXP MEP: los ocho estados del $0, que la cotización por sección apague la sección entera, que al cliente solo llegue lo confirmado, que la propuesta sin exclusiones salga idéntica a la de antes, el aviso de salida, el interruptor, que el dinero no se mueva, y que el resumen de MXP MEP no lleve nunca el membrete ni la licencia de Max Power. |

| `e13.js` | E13a · las cotizaciones del proveedor no pagan misceláneas, E13e · MXP MEP con sus propias tarifas, overhead y sales tax, y E13d · la escalación de las obras largas. Lo primero que comprueba siempre es que ningún estimado existente se mueva. Lo primero que comprueba es que **ningún estimado que ya existe se mueva ni un centavo**: una línea sin marcar da el bid idéntico al de la fórmula vieja. |

| `e11.js` | E11 · Historial y benchmarks: que la FOTO del número (bid_final) mande sobre el recálculo de hoy —si no, el historial miente con los precios de hoy—, que ninguna media salga sin decir de cuántos, que la tasa de acierto no cuente los que siguen sin contestar, que MXP MEP no se mezcle, y que mirar el historial no mueva un centavo de ningún estimado. |

| `e12.js` | E12 · Importar precios: que NADA se escriba sin aprobarlo fila a fila, que lo que no casa seguro salga aparte en vez de colarse, que un `1/2" EMT` sin entrecomillar no se trague el archivo, que `$1,234.00` se lea bien y que «vacío» no sea cero, que una base comprada acabe en `precio_ref` y jamás en `precio`, y que un $0 puesto a propósito (E0) avise antes de pisarse. |

| `e14.js` | E14 · El takeoff pegado, pies contra MLF: el catálogo vende el THHN por MIL pies y una fila casada por nombre entraba con factor 1 (500 ft de 4/0 → 500 MLF, medio millón de pies). Comprueba que lo que vino de Length o con Unit FT se divide por 1000 solo si el ítem es MLF, que piezas y LF no se tocan, que el alias sigue mandando con su factor, y que un `2-1/2" EMT` sin entrecomillar no se trague la fila. |

| `e9.js` | E9 · Las recetas por dentro y el escalado por pies medidos. Dos fugas encontradas el 16/09: el conductor se **sustituía** por `pies/1000`, así que una receta de 3 hilos (0,075 MLF para 25 ft de corrida) con 25 ft medidos dejaba 0,025 — un tercio del cable; y el **tubo no se tocaba**, 50 ft medidos seguían comprando 25 LF de EMT. Ahora hay un solo factor (pies medidos ÷ pies de corrida) que multiplica cable, tubo y lo que va cada tantos pies (grapas, straps, acoples), y no toca lo que es por salida (conectores, caja, dispositivo). Comprueba además que las recetas Romex de hoy dan **exactamente lo mismo que antes**. |

Regla: una prueba nueva por cada función que toque dinero o que escriba algo
que el cliente vaya a firmar.

| `e34.js` | E34 · el signo del dinero en la hoja de alcance: que un deduct «-$12,500», «− $12,500» o «($12,500)» se lea como descuento, y que un guion SEPARADOR («ADD - extra - $3,400») no convierta un añadido en descuento. Corre en Node, sin navegador. |

| `e35.js` | E35 · tanda 1 de Mariners: una línea de LOGÍSTICA / ALLOWANCE / SUBCONTRATO no paga tax, misceláneas, markup ni escalación y no infla la hora cargada (sí overhead y profit); que una línea sin marcar dé el bid de siempre; que el takeoff cuadre de arriba abajo; que el allowance salga en la propuesta y la logística no; la validez por estimado; el flete de la cuota; el aviso del importe único; el permiso sin marcar con contratista o MXP MEP; ICRA en modo planos. |

| `e36.js` | E36 · tanda 2 de Mariners: la merma automática solo en modo planos (un congelado no se mueve), el papel de MXP MEP para el cliente en lump sum y en inglés sin overhead, profit, horas ni membrete de Max Power, el resumen interno con su margen, y el resultado de un estimado de MXP MEP sin mezclarse con el historial de Max Power. |

| `e37.js` | E37 · tanda 3 de Mariners: los hitos con la retención aparte y al cierre (suman el contrato al centavo); la propuesta con obra, dueño y retención (y sin ellos, igual que siempre); el papel de MXP MEP con owner, obra y retainage; la tarjeta de datos del trabajo; los adjuntos del estimado; y las líneas a mano repartidas entre las opciones A/B/C de la propuesta. |
