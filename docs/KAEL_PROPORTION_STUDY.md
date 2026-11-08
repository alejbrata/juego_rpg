# Último estudio local de Kael — 8 de noviembre de 2026

Petición: intentar acercar la presentación del personaje a la referencia de Final Fantasy VIII después de investigar generación 3D mediante IA. Se interpreta como un experimento local separado, sin autorizar servicios externos ni compras.

## Resultado artístico

**No alcanza el objetivo y no se activa en el juego.** La silueta pierde parte del aspecto infantil, pero siguen presentes el rostro plano, los mechones rígidos, las piezas de ropa poco naturales y la falta de detalle pictórico. Cambiar proporciones no resuelve la calidad de la malla y las texturas de origen. No se presenta como un personaje comercial ni como una renovación terminada.

[Comparación real en Godot](previews/kael-study-comparison.png): izquierda, Kael 0.9; derecha, estudio. Ambas capturas usan la misma cámara, luz y transformación del actor. La altura y proporciones internas sí cambian: son el objeto del estudio. Los primeros planos mantienen el mismo encuadre, no igualan artificialmente el tamaño de la cabeza.

## Trabajo realizado

- Blender **5.2.1 LTS ejecutado realmente** en proceso local `--background --factory-startup --python-exit-code 1`.
- `tools/blender/refine_kael_proportions.py` abre la fuente existente. `reshape()` modifica las coordenadas de sus vértices y del esqueleto de reposo: piernas más largas, torso más estrecho y cabeza menor. La espada se reduce uniformemente respecto a su anclaje.
- No se generan primitivas ni se reconstruye otro personaje desde cero. Se mantienen topología, UV, atlas y claves originales de animación; por eso persisten sus defectos artísticos.
- Fuente, GLB y manifiesto separados en `assets/characters/kael/proportion_study/`. El original conserva su SHA256 `114e07c21a797cd92def8c6af65fbefebff6c8020492a50b812a993521afd1db`.
- 6.618 triángulos, 17 huesos; Idle, Walk, Attack, Hurt, Defend y KO. La importación conserva la textura embebida. No son medidas de rendimiento móvil.
- `tools/capture_kael_study.gd` carga ambos GLB mediante `KaelModel.load_asset()` dentro de una batalla real y captura cuerpo, rostro, batalla y poses. El cambio de actor solo existe en ese proceso, sin guardar ajustes del juego.

## Verificación y límites

La importación y las capturas se ejecutaron con Godot **4.7.2**, render Compatibility sobre Intel Arc. Se inspeccionaron la comparación, Attack, Walk, Hurt, Defend y KO. Son muestras de poses, no una certificación de continuidad de movimiento, contactos o ausencia de clipping durante todos los fotogramas. Las animaciones anteriores se conservan como provisionales y no se han reelaborado para las nuevas proporciones. No se integró el candidato en exploración.

Suite existente: **576 comprobaciones, cero fallos antes y después**, en headless; también **576/576 con render real** al finalizar. La captura carga y exige las seis animaciones del candidato mediante el adaptador existente. Las pruebas generales verifican el proyecto vigente, no certifican la calidad artística del estudio.

No se modifican combate, estado, narrativa, otros personajes, entorno ni selección predeterminada. No se instala ni utiliza un generador externo; ningún modelo o imagen del proyecto se envía a un servicio de generación. La siguiente mejora sustancial requiere una malla y texturas de otra calidad, mediante el flujo de generación investigado y autorizado, no repetir deformaciones de esta base.

## Reproducción

Desde la raíz, usando las rutas de los ejecutables instalados:

```powershell
blender --background --factory-startup --python-exit-code 1 --python tools/blender/refine_kael_proportions.py
godot --headless --path . --editor --import
godot --path . --script res://tools/capture_kael_study.gd
godot --headless --path . --script res://tests/test_battle.gd
```

El primer comando reemplaza exclusivamente el estudio, nunca la fuente Kael 0.9. Las capturas necesitan render real, no `--headless`.
