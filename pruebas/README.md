# Pruebas del panel

Se corren con el Chromium que ya está instalado, sin tocar la nube ni pedir
sesión: la lógica que se prueba es **pura** (entra un dato, sale un dato) y se
alcanza por `window.MXP_PRUEBA`.

```
NODE_PATH=/opt/node22/lib/node_modules node pruebas/e0.js
```

| Archivo | Qué comprueba |
|---|---|
| `e0.js` | E0 · «quién pone el material»: los ocho estados del $0, que la cotización por sección apague la sección entera, que al cliente solo llegue lo confirmado, que la propuesta sin exclusiones salga idéntica a la de antes, el aviso de salida, el interruptor y que el dinero no se mueva. |

Regla: una prueba nueva por cada función que toque dinero o que escriba algo
que el cliente vaya a firmar.
