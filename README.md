# Desktop Pet (Godot)

Proyecto de mascota virtual de escritorio construido en Godot, con soporte para sprites 2D y pruebas con Live2D (Cubism), inventario, estados de mascota, UI y guardado.

## Objetivo

Este repositorio reúne una base escalable para una mascota virtual con:
- comportamiento autónomo
- necesidades/estadísticas
- inventario e ítems
- UI contextual
- persistencia de datos

## Estructura principal

- `main.tscn`, `main.gd`: escena y entrada principal.
- `systems/`: lógica de comportamiento (IA, estados, movimiento, partículas, objetos).
- `resources/`: recursos de datos (estadísticas, inventario, guardado).
- `ui/`: paneles y componentes de interfaz.
- `autoloads/`: singletons globales (`audio_manager`, `save_manager`).
- `assets/`: modelos/sprites usados por el juego.
- `addons/gd_cubism/`: integración de Live2D Cubism para Godot.
- `dinoCharactersVersion1.1/`: pack de recursos de dinosaurio.
- `konosuba/`: recursos de referencia para Live2D.
- `Catppuccino-master/`: proyecto adicional independiente incluido como referencia.

## Scripts útiles

- `sync_git.bat`: script de sincronización Git.
- `sincronizar_ramas.bat`: script para sincronizar ramas.

## Flujo recomendado de Git

1. Revisar cambios con `git status`.
2. Agregar cambios con `git add .`.
3. Crear commit semántico: `git commit -m "docs: actualizar estructura del proyecto"`.
4. Subir rama actual: `git push -u origin <rama>` (primera vez) o `git push`.

## Notas de versionado

- Se ignoran artefactos de Godot (`.godot/`, `*.import`) y temporales.
- Si agregas assets grandes frecuentemente, considera Git LFS para no inflar el historial.

## Documentación extendida

Consulta el inventario en `docs/INVENTARIO_PROYECTO.md`.
