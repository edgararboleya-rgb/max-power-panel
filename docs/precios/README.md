# Precios de mercado — 15/09/2026

Archivos para **Importar precios (E12)** en la app operativa: se pegan, la app
propone fila a fila y **nada se escribe sin aprobarlo**. Cobre COMEX el 14/09:
**$6,28–6,47/lb** (35 % más que hace un año).

| Archivo | Destino sugerido | Qué es |
|---|---|---|
| `2026-09-15-cobre-mcm-corregir.csv` | **tus precios** | 400, 500 y 600 MCM THW CU. Hoy están **por debajo del cobre pelado que llevan** (400 MCM = 1235 lb × $6,40 = $7.900 de cobre; tu precio $7.426). Se llevan al mismo nivel que tu 250/300/350 (1,83 × el cobre), que sí está al día. |
| `2026-09-15-aluminio-referencia.csv` | **precio_ref** primero | Los 10 XHHW aluminio compacto. Los tuyos están a ~40 % del mercado (4/0: tuyo $0,65/ft, Platt $1,68; 500: tuyo $1,43, mercado $3,85–4,96). Cifras ≈ $9/lb de aluminio conductor; compáralas en «tuyo vs referencia» y pásalas a tus precios si te cuadran con tu supply. |
| `2026-09-15-cobre-thhn-referencia-platt.csv` | **precio_ref** | Lista pública de Platt para todo el THHN. Tus precios van 5–20 % por debajo de lista: **están bien**, es precio de contratista. Sirve de vara. |

Fuentes: Platt Electric Supply (fichas por tamaño, Sept 2026), Pro Wire & Cable
(250 MCM AL), Wire & Cable Your Way / Nassau (500 MCM AL), Trading Economics /
Southwire (COMEX). Las páginas de fábrica (Southwire) no se pudieron abrir desde
aquí. Pesos del conductor: NEC Cap. 9 Tabla 8.
