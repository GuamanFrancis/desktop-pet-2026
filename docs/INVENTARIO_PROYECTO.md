# Inventario del Proyecto

## Núcleo Godot

- `project.godot`: configuración global del proyecto.
- `main.tscn`: escena principal.
- `main.gd`: controlador principal.
- `pet_sprite.gd`, `aqua_sprite.gd`, `pet_canvas.gd`: control y render de mascotas/sprites.

## Autoloads

- `autoloads/save_manager.gd`: persistencia de estado.
- `autoloads/audio_manager.gd`: gestión centralizada de audio.

## Sistemas (`systems/`)

- `ai_brain.gd`: decisiones/autonomía de la mascota.
- `pet_state_machine.gd`: máquina de estados.
- `pet_movement.gd`: movimiento de la mascota.
- `particle_effects.gd`: efectos visuales.
- `dropped_object.gd`: objetos interactivos en escena.

## Recursos de datos (`resources/`)

- `pet_stats.gd`: estructura de estadísticas de mascota.
- `inventory.gd`: inventario de usuario.
- `item_data.gd`: definición de ítems.
- `save_data.gd`: estructura serializable para guardado.

## UI (`ui/`)

- `context_menu.gd`: menú contextual.
- `dialogue_bubble.gd`: burbujas/diálogo.
- `inventory_panel.gd`: inventario visual.
- `stats_panel.gd`: panel de estadísticas.
- `notification_toast.gd`: notificaciones temporales.

## Assets y contenido

- `assets/aqua/`: modelo Live2D (moc3, model3, motions, textures).
- `assets/sprites/`: sprites importados.
- `dinoCharactersVersion1.1/`: paquete de recursos dino (sheets, gifs, misc).
- `konosuba/Live2d-model/`: material adicional de Live2D.

## Addons

- `addons/gd_cubism/`: extensión de Cubism para Godot (binarios, cs, ejemplos, shaders).

## Proyecto adicional incluido

- `Catppuccino-master/`: proyecto Java separado (no forma parte del runtime principal Godot).
- `Catppuccino-master.zip`: archivo comprimido de referencia.

## Scripts auxiliares

- `sync_git.bat`: automatización de sincronización Git.
- `sincronizar_ramas.bat`: utilidades para trabajo con ramas.

## Recomendaciones de mantenimiento

- Mantener la lógica de gameplay en `systems/` y evitar mezclarla con UI.
- Registrar cambios de estructura en este documento cuando agregues carpetas nuevas.
- Para assets muy pesados y frecuentes, evaluar Git LFS.
