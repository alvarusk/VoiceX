# Recuperar las traducciones elegidas

La exportación lee la base local y no modifica Supabase. Las elecciones y las
ediciones confirmadas se guardan en `subtitle_lines.selected_text`, y se suben
al sincronizar. `cand_gpt`, `cand_claude`, etc. son propuestas; no representan
necesariamente la elección final. Los ASS originales de Storage tampoco son la
traducción final editada.

Antes de forzar una sincronización, conserva una copia de los datos locales y
exporta las filas remotas para poder comparar ambas versiones. Una subida puede
reemplazar el estado remoto. No borres ni vuelvas a importar el proyecto para
intentar recuperar las ediciones.

## 1. Localizar el proyecto

Ejecuta en el SQL Editor del proyecto Supabase:

```sql
select p.project_id, p.owner_user_id, p.title,
       count(s.line_id) as segmentos,
       count(*) filter (where nullif(btrim(s.selected_text), '') is not null)
         as con_traduccion_elegida,
       to_timestamp(max(s.updated_at_ms) / 1000.0) as ultima_modificacion
from public.projects p
left join public.subtitle_lines s on s.project_id = p.project_id
group by p.project_id, p.owner_user_id, p.title
order by max(s.updated_at_ms) desc nulls last;
```

Comprueba el título y propietario para escoger el proyecto francés correcto.

## 2. Guardar una copia completa en CSV

Sustituye `ID_DEL_PROYECTO` y exporta el resultado como CSV:

```sql
select * from public.subtitle_lines
where project_id = 'ID_DEL_PROYECTO'
order by dialogue_index;
```

Incluye todas las filas, también las no revisadas y archivadas si existen. La
consulta usa la tabla, no la vista `subtitle_lines_active`. Conserva este CSV:
contiene las selecciones y también los candidatos editados que hayan llegado
a sincronizarse. Comprueba algunas frases que recuerdes en `selected_text`.

## 3. Crear un ASS recuperado sin modificar la nube

Desde `C:\VoiceX`, con Python instalado:

```powershell
python scripts/recover_supabase_translations.py traducciones.csv recuperado.ass
```

Si el CSV contiene varios proyectos, añade `--project-id ID_DEL_PROYECTO`.
El archivo de destino debe ser nuevo. El script usa exclusivamente
`selected_text`, conserva tiempos, nombres y marcas de duda como comentarios,
y omite selecciones vacías y dibujos vectoriales. Usa un estilo estándar:
no recupera los estilos, carteles ni la maquetación del ASS original. Las líneas
sin selección permanecen en el CSV para revisarlas por separado.

## Si falta una edición

El código actual registra cada elección y edición en `selection_events` local,
pero no sincroniza ese historial. La tabla homónima de Supabase puede estar
vacía. Si tiene datos de otra versión, puedes consultarlos sin modificar nada:

```sql
select line_id, chosen_source, chosen_text, method,
       to_timestamp(at_ms / 1000.0) as fecha
from public.selection_events
where project_id = 'ID_DEL_PROYECTO'
order by at_ms desc, event_id desc;
```

Si `selected_text` no contiene tus ediciones, comprueba el dispositivo donde las
hiciste: pueden seguir en su base local aunque nunca se hayan sincronizado.
Si el estado remoto fue sobrescrito y no hay historial, este CSV solo permite
recuperar el estado remoto actual; para un estado anterior necesitarás una copia
de seguridad existente. No se ha comprobado aquí el contenido de tu servidor.
