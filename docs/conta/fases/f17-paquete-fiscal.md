# Fase 17 · El paquete fiscal
**marzo 2027 · 🟢 VERDE** — la maquinaria; **la primera entrega real es a principios de 2028**, para el ejercicio 2027

## Qué entrega

- Balanza y mayor completo con saldo corrido, procedencia y sello de IA, más
  **los doce hashes de cierre**
- Estados financieros del ejercicio, con la vista «con ajustes posteriores»
- Cédula de activos fijos y depreciación desde `activos_fijos` (MACRS/179 como
  columna del CPA)
- 1099-NEC de subcontratistas del ejercicio *(el de 2026 salió de QuickBooks en
  enero de 2027)*
- Conciliaciones bancarias de los doce meses desde `conciliaciones`, con sus
  partidas
- Pagos a subs con y sin certificado de seguro, y el reporte del proveedor de
  nómina **por código de clase** (para la auditoría de WC y GL)
- Lista de reversos y de asientos de origen IA del año, con motivo
- Comidas al 50 %, viajes, y las partidas que siempre pregunta, por
  `etiqueta_fiscal`
- Una página **«READ ME» en inglés**: qué archivo es qué y cómo se llega del
  estado al asiento y del asiento al recibo; más `docs/conta/MAPA-DATOS.md`
  generado desde `pg_description` (cada `c*.sql` comenta sus tablas y columnas)
- Todo en inglés o bilingüe (`cuentas.nombre_en`)

## Lo que NO hace
No calcula la declaración. Dos razones: el retorno lo firma un CPA, y
Florida tiene su propio nido de avispas con el sales/use tax de contratistas
—si eres mejora a bien inmueble pagas el impuesto al comprar el material, y
eso depende del tipo de contrato—. La decisión de mejora a bien inmueble está
en el plan, §1.

Tampoco produce el **DR-15**: eso es mensual o trimestral y sale de la vista
de la Fase 8.

## Más el pulido
Lo que salga del primer cierre real de enero.

## Terminó cuando
Tu CPA recibe el paquete y no te pide nada más.
