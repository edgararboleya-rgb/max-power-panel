# Fase 11 · El puente de nómina
**30 nov – 6 dic · 🔵 AZUL el burden · 🟢 VERDE la plomería · ▶ CONTRATADO YA**

> ⚠️ **Este trámite empieza a primeros de noviembre, no esta semana.** Dar de
> alta una nómina con el estado toma semanas, y cambiar de proveedor a mitad
> de trimestre parte los 941 en dos. La primera nómina en el proveedor nuevo
> debe caer el **1 de enero**, junto con el corte de los libros.

## Tú
1. **Contratar Gusto o Check** y sacar las llaves de API.
2. Decidir si la nómina entra como resumen o empleado por empleado.

## Lo que la app NO hace, y no se discute
No calcula retenciones, no deposita en EFTPS, no presenta 941, 940, W-2 ni
RT-6. Eso lo hace el proveedor. Si retienes y no depositas a tiempo existe la
Trust Fund Recovery Penalty, que atraviesa la corporación y te la cobran a ti
personalmente. Ningún ahorro de software vale eso.

## 🔵 Fable
**El reparto del burden a la obra.** Cómo aterriza cada parte de tu
`benefits_detalle` —FICA, FUTA, reempleo de Florida, workers comp, GL,
vacaciones, seguro médico— sobre las horas de un proyecto. Es sutil y es lo
que hace real el costo de la Fase 9.

## 🟢 Opus
La plomería contra la API del proveedor: `horas` → nómina, nómina → asientos
y repartida por obra.

## Entregable
`docs/conta/c11-nomina.sql` · el cliente del proveedor

## Terminó cuando
Una corrida de nómina de prueba entra sola al libro y aparece repartida sobre
las obras correctas, con su burden.
