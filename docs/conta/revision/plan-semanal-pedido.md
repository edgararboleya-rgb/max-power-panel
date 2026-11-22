# Pedido de Edgar (22-nov): plan semanal de mejora y PENDIENTES.md — guardado, sin empezar

Edgar pidió pausar todo para no gastar más uso. Esto queda guardado para cuando él lo diga.

## Lo que pidió

1. **Crear PENDIENTES.md en el repo**, en 4 grupos. Cada punto lleva qué es, por qué importa, su prioridad (alta, media o baja) y su tamaño (chico, mediano o grande).
   - a. Fallas: lo que está roto.
   - b. Fases sin terminar.
   - c. Diseño: opinión libre, aunque implique cambiar colores o estilo. Cada propuesta lleva una frase de qué mejora para quien la usa.
   - d. Herramientas nuevas que use el mercado y que sirvan a un contratista eléctrico.
2. **Trabajo semanal:**
   - Su uso de Claude se reinicia el viernes.
   - Para mejorar la app se usa como máximo el 60 % del uso semanal; el 40 % queda para la operación (estimados, clientes, urgencias).
   - Cada viernes se le propone qué hacer esa semana, empezando por las fallas y lo de prioridad alta, dentro de ese presupuesto.
   - El jueves, si sobra uso, se le proponen puntos chicos.
   - Nada se cambia sin que él apruebe el plan de la semana.
3. **Al terminar cada punto:** marcarlo como hecho con la fecha en PENDIENTES.md y explicarle en español sencillo qué cambió.
4. **Primera respuesta:** la lista resumida, para pasársela a Claude Duet.

## Lo que ya se encontró (asesor de seguridad de Supabase, 22-nov)

| Prioridad | Qué |
|---|---|
| Alta | La tabla `public.horas_estimadas_fase` no tiene RLS encendido: tiene su política, pero no se aplica. Cualquier usuario con sesión puede leer las horas estimadas de todas las obras. Arreglo chico: encender RLS en esa tabla. |
| Media | 7 vistas con SECURITY DEFINER: v_ia_medida, recibos_equipo, materiales_equipo, alcances_equipo, proyectos_equipo, documentos_equipo y v_costos_revision. Hay que revisar que sea a propósito. |
| Media | `fn_mfa_exigir()` se puede llamar sin sesión (anon). |
| Baja | La protección contra contraseñas filtradas está apagada en Auth. |
| Baja | La extensión pg_net está en el esquema public. |
| Baja | 2 funciones no tienen search_path fijo: fn_plaid_vault_nombre y fn_puente_recibo_doc. |
| Baja (rendimiento) | 138 llaves foráneas sin índice, 42 políticas que vuelven a evaluar auth.* en cada fila, 14 tablas con políticas permisivas duplicadas y 13 índices sin uso. |

## Otros pendientes ya conocidos

- **Bandeja nueva (c17 y c18):** faltan 10 hallazgos «importa» de la ronda 3 (ver `f19-ronda3.json`). La ronda 4 espera a Fable. No publicar ni pegar nada hasta entonces.
- **c10-pruebas:** 3 rojos falsos que dependen del día (las pruebas 31, 49 y 53).
