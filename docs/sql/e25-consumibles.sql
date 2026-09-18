-- ============================================================================
-- E25 · CONSUMIBLES AUTOMÁTICOS: lo que falta para que las reglas corran
-- ============================================================================
-- Edgar (17/09): «en 100 pies de tubería tú necesitas 10 couplings, tantos
-- conectores, tantas cajas… eso es un conteo que yo no tengo que hacer. Y
-- ahora mismo automático nada más me salían como tres renglones».
--
-- El panel v189 trae el motor de reglas. Este SQL pone lo que le falta a la
-- base: dos columnas en `estimados` (cómo va sujeto el tubo y qué parte va en
-- trapecio) y los ítems de fijación que NO estaban en el catálogo.
--
-- ⚠ PRECIOS DE REFERENCIA, NO COTIZADOS. Los de abajo son precios de calle de
-- distribución en Florida, puestos para que el renglón no salga en $0 y se
-- vuelva invisible en el bid. NO son de CED ni de CES. Pídeselos al supply y
-- corrígelos — cada uno lleva su `cero_motivo` en blanco a propósito para que
-- el chip del estimador no diga que están revisados.
-- ============================================================================

-- ── 1. El estimado sabe cómo va sujeto el tubo ──────────────────────────────
alter table estimados add column if not exists soporte  text;
alter table estimados add column if not exists pct_rack numeric;
comment on column estimados.soporte is
  'E25 · Como va sujeto el tubo: pared | power | metal | unistrut | tile. Decide que fijacion automatica entra. NULL = pared (one-hole + tapcon), que es como se venia calculando.';
comment on column estimados.pct_rack is
  'E25 · Parte del tubo que va en trapecio, 0 a 1. Solo cuenta con soporte = unistrut.';

-- ── 2. Los ítems de fijación que faltaban ───────────────────────────────────
-- Se dan de alta solo si no existen; lo que ya tengas NO se toca (ni el precio).
insert into catalogo_items (item, seccion, unidad, precio, horas_unidad, codigo)
select v.item, v.seccion, v.unidad, v.precio, v.horas, v.codigo
  from (values
    ('1/2"  EMT POWER STRAP (2 HOLE)',   'CONDUIT & FITTINGS', 'E',  0.30,  0.025, '09-COND'),
    ('3/4"  EMT POWER STRAP (2 HOLE)',   'CONDUIT & FITTINGS', 'E',  0.38,  0.025, '09-COND'),
    ('1"    EMT POWER STRAP (2 HOLE)',   'CONDUIT & FITTINGS', 'E',  0.52,  0.030, '09-COND'),
    ('1/2"  EMT UNISTRUT STRAP',         'CONDUIT & FITTINGS', 'E',  0.60,  0.030, '09-COND'),
    ('3/4"  EMT UNISTRUT STRAP',         'CONDUIT & FITTINGS', 'E',  0.72,  0.030, '09-COND'),
    ('1"    EMT UNISTRUT STRAP',         'CONDUIT & FITTINGS', 'E',  0.95,  0.035, '09-COND'),
    ('UNISTRUT 1-5/8" P1000',            'CONDUIT & FITTINGS', 'LF', 4.50,  0.050, '09-COND'),
    ('ALL-THREAD ROD 1/4"',              'CONDUIT & FITTINGS', 'LF', 0.85,  0.030, '09-COND'),
    ('1/4" HEX NUT',                     'CONDUIT & FITTINGS', 'E',  0.06,  0.010, '09-COND'),
    ('1/4" FLAT WASHER',                 'CONDUIT & FITTINGS', 'E',  0.05,  0.010, '09-COND'),
    ('1/4" CONCRETE ANCHOR (DROP-IN)',   'CONDUIT & FITTINGS', 'E',  0.55,  0.080, '09-COND'),
    ('SELF-DRILLING SCREW #10 x 1"',     'CONDUIT & FITTINGS', 'E',  0.09,  0.010, '09-COND'),
    ('ELECTRICAL TAPE 3/4" x 66FT',      'MISCELLANEOUS',      'E',  1.50,  0.000, '20-MISC'),
    ('WIRE PULLING LUBRICANT 1 QT',      'MISCELLANEOUS',      'E',  9.00,  0.000, '20-MISC'),
    ('WIRE MARKER BOOK',                 'MISCELLANEOUS',      'E', 12.00,  0.000, '20-MISC')
  ) as v(item, seccion, unidad, precio, horas, codigo)
 where not exists (select 1 from catalogo_items c
        where upper(btrim(regexp_replace(c.item,'\s+',' ','g'))) = upper(btrim(v.item)));

-- ── 3. Comprobar ────────────────────────────────────────────────────────────
-- Los 15 ítems nuevos, con su precio de referencia:
select item, unidad, precio, horas_unidad, codigo
  from catalogo_items
 where item in ('1/2"  EMT POWER STRAP (2 HOLE)','3/4"  EMT POWER STRAP (2 HOLE)','1"    EMT POWER STRAP (2 HOLE)',
                '1/2"  EMT UNISTRUT STRAP','3/4"  EMT UNISTRUT STRAP','1"    EMT UNISTRUT STRAP',
                'UNISTRUT 1-5/8" P1000','ALL-THREAD ROD 1/4"','1/4" HEX NUT','1/4" FLAT WASHER',
                '1/4" CONCRETE ANCHOR (DROP-IN)','SELF-DRILLING SCREW #10 x 1"',
                'ELECTRICAL TAPE 3/4" x 66FT','WIRE PULLING LUBRICANT 1 QT','WIRE MARKER BOOK')
 order by codigo, item;

-- ── 4. Si quieres cambiar los NÚMEROS de las reglas (opcional) ──────────────
-- La app trae una tabla de arranque. Para corregirla sin tocar código, se
-- guarda un JSON con {id de la regla: cantidad}. Ejemplo — 12 acoples por
-- 100 ft en vez de 10, y 3 conectores por caja en vez de 2:
--
--   insert into config_estimador (clave, valor)
--   values ('consumibles', '{"coupling":12,"conector":3}')
--   on conflict (clave) do update set valor = excluded.valor;
--
-- Los ids son: coupling · conector · cajapaso · tapaciega · strap1h · power ·
-- tornillo · ustrap · tbar · tapcon · strut · varilla · tuerca · arandela ·
-- ancla · tape · grasa · libreta
