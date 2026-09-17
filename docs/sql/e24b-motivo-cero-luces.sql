-- E24b · Los items de solo mano y las luces que pone otro: por qué van en $0 (17/09)
-- Sin esto el estimador los marca «¿QUIÉN LO PONE? ?» y «FALTA PRECIO» en cada estimado.
alter table catalogo_items add column if not exists cero_motivo text;
alter table catalogo_items add column if not exists cero_revisado date;
update catalogo_items set cero_motivo = 'solo_labor', cero_revisado = current_date
 where precio = 0 and item in (
   'INSTALACIÓN LUMINARIA 2X2 (LUZ POR OTROS)', 'INSTALACIÓN DOWNLIGHT (LUZ POR OTROS)', 'INSTALACIÓN EXIT SIGN (LUZ POR OTROS)');
-- el troffer «de solo instalación» de las recetas 2x2/2x4: la luz la pone otro
update catalogo_items set precio = 0, cero_motivo = 'by_owner', cero_revisado = current_date
 where upper(btrim(regexp_replace(item,'\s+',' ','g'))) in ('2''X2'' RECE. FLUORESCENT', '2''X4'' RECE. FLUORESCENT')
   and coalesce(precio, 0) = 0;
select item, precio, horas_unidad, cero_motivo from catalogo_items
 where item like 'INSTALACIÓN%' or item like '2''X%RECE. FLUORESCENT' order by item;
