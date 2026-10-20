# PORTALKILL — Documento de diseño y plan técnico

> Plataformas de una pantalla por piso · hordas que salen de un portal · armas elementales que se combinan · gore opcional (+18).

---

## 1. Visión

Cada **piso** es una arena de una sola pantalla con plataformas. Del **portal de entrada** salen oleadas de enemigos. Al limpiar todas las oleadas se abre el **portal de salida**; al cruzarlo eliges **1 de 3 recompensas** (arma nueva, mejora o *infusión elemental*) y pasas al siguiente piso, más difícil y con otra ambientación.

El atractivo central: **los elementos interactúan entre sí** y el jugador descubre combos.

| Combo | Resultado |
|---|---|
| Mojado + ⚡ | La electricidad salta a más enemigos y aturde más tiempo |
| Aceite + 🔥 | Explosión + incendio grande |
| Mojado + 🔥 | Apaga el fuego (vapor) |
| 🗡️ Corte | Sangrado + desmembramiento (sin pierna → se arrastra) |
| 🔥 Ardiendo | Daño continuo, pánico, contagia a enemigos cercanos |

## 2. Plataforma y tecnología

**Motor: Godot 4.7 (GDScript)**: gratis, sin regalías y excelente en 2D. Exporta a Windows, macOS, Linux, Web, Android e iOS.

- **Renderer: `Compatibility` (OpenGL/WebGL2).** Corre en PCs modestas y en navegador, y es el único que exporta a Web. El brillo se simula con sprites aditivos (barato, funciona en todos lados).
- **GDScript con tipado estático** en todo el código: en Godot 4 el tipado hace el código bastante más rápido y detecta errores antes.
- ⚠️ Usa la versión **estándar** de Godot (`~/Applications/Godot.app`, 4.7.2), no **Godot_mono**: la versión .NET pide `dotnet`, que no tienes instalado, y además **no exporta a Web**.

### Distribución (de gratis a pago)
1. **itch.io** (gratis): build Web jugable en el navegador más descargas para PC. Ideal para prueba pública, feedback y comunidad. Permite marcar contenido +18. Se sube con `butler`, su CLI.
2. **Steam** (USD 100 por juego, recuperables): Early Access, logros, cuestionario de contenido maduro (violencia y gore se marcan ahí).
3. Consolas: más adelante, a través de un publisher o porting (requiere clasificación IARC/PEGI/ESRB).

## 3. Cómo lograr el look pixel art (recomendaciones)

**Configuración del proyecto (ya aplicada):**
- Resolución interna **640×360** (16:9). Escala perfecta ×2 = 720p, ×3 = 1080p, ×4 = 1440p.
- `stretch/mode = viewport` y `scale_mode = integer`: el juego se dibuja a 640×360 y luego se escala en enteros, así los píxeles nunca se deforman.
- `default_texture_filter = Nearest`: sin suavizado, píxeles nítidos.
- `snap_2d_transforms_to_pixel` y `snap_2d_vertices_to_pixel` para evitar el "temblor" de subpíxeles.

**Arte (cuando lleguen los assets):**
- **Tiles de 16×16**. Personajes de unos 16×24 a 24×32 px. Jefes de 48–96 px.
- **Una paleta limitada** (32–64 colores; por ejemplo *Endesga 32*, *Resurrect 64* o *Apollo*) para que todo se vea coherente aunque los assets vengan de packs distintos. Si compras packs, recoloréalos a la paleta.
- **Aseprite** (de pago, o compilarlo gratis) o **LibreSprite/Pixelorama** (gratis). Con el plugin *Aseprite Wizard* de Godot las animaciones se importan directo.
- La sangre y los efectos se ven mejor como **partículas de 1–2 px** y manchas persistentes (ya implementado) que como sprites animados.
- Animaciones cortas y expresivas: 4–6 frames para correr, 2–3 para golpe. El *squash & stretch* por código añade mucha vida sin frames extra.
- **Packs recomendados para empezar:** itch.io → "pixel art platformer", "dark fantasy pixel", "gore pixel". Revisa que la licencia permita uso comercial.
- **Luz:** un `CanvasModulate` oscuro con luces aditivas (portales, fuego, disparos) da mucha atmósfera a bajo costo.

**Cómo se conectan los assets:** cada actor tiene un nodo visual separado de su lógica. Hoy es un *placeholder* dibujado por código, organizado por partes (cabeza, torso, brazos, piernas) igual que lo estaría un sprite desmembrable. Mañana lo reemplazas por `AnimatedSprite2D` / sprites por parte sin tocar la IA, el daño ni la física.

## 4. Arquitectura

```
src/
  core/        events.gd (bus de señales) · game.gd (estado de partida, ajustes) · pixel.gd (utilidades de dibujo)
  data/        weapon_data.gd · enemy_data.gd · catalog.gd (catálogo de armas/enemigos/recompensas)
  combat/      damage_info.gd · elements.gd (estados + reacciones) · weapons.gd (comportamientos)
               projectile_system.gd (balas sin nodos)
  world/       level.gd (grid lógico + colisión fusionada + dibujo) · layouts.gd · portal.gd · wave_director.gd
  actors/      player.gd · enemy.gd · enemy_visual.gd
  fx/          blood_system.gd (partículas + manchas persistentes) · gib_system.gd · fx_system.gd
  ui/          hud.gd · reward_screen.gd · overlay screens
  main.gd      orquesta pisos, recompensas, game over, modo autotest
```

### Decisiones clave de rendimiento
| Sistema | Técnica | Por qué |
|---|---|---|
| Balas | **Arrays + un único `_draw`**, sin un nodo por bala | Cientos de balas cuestan casi nada |
| Colisión de partículas/balas con el mundo | **Grid lógico O(1)** (`level.is_solid(pos)`) | Sin raycasts ni física para miles de gotas |
| Sangre | Partículas en `PackedArray` + **lienzo persistente** (`SubViewport` sin limpiar) | Manchas infinitas sin costo acumulado: cada gota que aterriza se "pinta" una vez y desaparece de la simulación |
| Gibs (pedazos) | Física propia simplificada sobre el grid, con límite y reciclaje | Sin `RigidBody2D` |
| Colisión del nivel | Tiles fusionados en rectángulos grandes | Pocos shapes → física barata |
| Enemigos | `CharacterBody2D` que **no colisionan entre sí** | Hordas densas sin explosión de pares de física |
| Desacople | Bus de eventos (`Events`) para shake, hitstop, sonido y UI | Los sistemas no se conocen entre sí, así es fácil agregar o quitar |
| Datos | Armas y enemigos como `Resource` | Balance sin tocar código; listo para editar en el inspector |

Presupuesto objetivo: **60 FPS** con ~80 enemigos, ~2000 gotas de sangre y ~400 balas en una PC modesta. `F3` muestra el overlay de rendimiento.

### Sistema de daño y elementos
- Todo golpe es un `DamageInfo`: cantidad, **elementos** (bitmask: FIRE, ELECTRIC, CUT, BLUNT, WATER, OIL), dirección, empuje y probabilidad de desmembrar.
- `Elements.apply_hit(enemy, info)` aplica resistencias y estados, y resuelve **reacciones** con una tabla central. Para agregar un combo nuevo se agrega una regla, sin tocar las armas.
- Las **infusiones** (recompensa) agregan un elemento a un arma existente: la pistola + fuego dispara balas incendiarias. Así las combinaciones crecen de forma multiplicativa con poco contenido.

### Armas del prototipo
| Arma | Tipo | Elemento | Rol |
|---|---|---|---|
| Pistola | proyectil | contundente | Inicial, confiable |
| Machete | cuerpo a cuerpo | corte | Desmembra, sangrado |
| Molotov | lanzable en arco | fuego | Control de zona, incendios |
| Taser de arco | cadena | eléctrico | Salta entre enemigos, aturde |
| Hidrocañón | chorro | agua | Moja (combo con eléctrico), apaga |
| Escopeta | proyectil múltiple | contundente | Gore a corta distancia |

### Enemigos del prototipo
| Enemigo | Rasgo |
|---|---|
| Carroñero | Básico, persigue y salta plataformas |
| Corredor | Rápido y frágil, aparece en grupos |
| Bruto | Lento, mucha vida, resiste el corte |
| Hinchado | Al morir revienta y deja **aceite** (combo con fuego) |

### Director de oleadas
Cada oleada tiene un **presupuesto de puntos** que crece con el piso y la oleada; cada enemigo tiene un costo. El director "compra" enemigos y los suelta por el portal en ráfagas. Es fácil de balancear y escala sin límite.

## 5. Gore y contenido +18
- Ajuste **Gore: Apagado / Normal / Extremo** (tecla `G` en pausa).
  - Apagado: los enemigos se desintegran en píxeles oscuros, sin sangre.
  - Extremo: más sangre, más gibs, salpicaduras en las paredes.
- Desmembramiento con efecto en el juego: sin piernas el enemigo se arrastra, y sin cabeza muere.
- Para tiendas: Steam pide el cuestionario de contenido maduro; itch.io pide marcar "contenido adulto". El interruptor ayuda en mercados restrictivos (Alemania, Australia) y para streamers.

## 6. Hoja de ruta

### Fase 0 — Prototipo mínimo ✅ (esta entrega)
Un loop completo: pisos → oleadas → portal de salida → recompensa → siguiente piso, con 6 armas, 4 enemigos, reacciones elementales, sangre persistente, gibs, desmembramiento, screen shake, hitstop y HUD.

### Fase 1 — Sentir el juego (game feel)
- Sonido: pool de efectos con variación de tono; música dinámica por intensidad.
- Arte real: tileset 16×16, sprites de jugador y enemigos, paleta fija.
- Pulir el control: dash, wall-jump, recarga.

### Fase 2 — Profundidad
- **Fusión de armas**: dos armas en el banco de fusión forman una nueva (motosierra + taser = *sierra de arcos*; lanzallamas + aceite = *napalm*).
- Más elementos: **hielo** (congelado + contundente = se hace añicos), **ácido** (charcos que derriten la armadura), **veneno**.
- Enemigos con contrapartida: voladores, escudos, invocadores, enemigos que **absorben** un elemento.
- **Jefe cada 5 pisos**, que sale del portal de forma especial.
- **Eventos de piso**: piso inundado (todo mojado → paraíso eléctrico), piso con tuberías de gas, piso oscuro.

### Fase 3 — Meta-progresión (roguelite)
- Moneda que se conserva entre partidas para desbloquear armas en el pool.
- Personajes con pasivas distintas.
- Desafíos diarios con semilla compartida.

### Fase 4 — Distribución
- Build Web en itch.io para feedback → página de Steam (lista de deseados) → Early Access.
- Coop local 2 jugadores (la arquitectura ya admite múltiples `Player`).
- Steam Deck / gamepad completo (el input ya está mapeado para mando).

## 7. Controles
| Acción | Teclado/ratón | Mando |
|---|---|---|
| Moverse | A/D | Stick izquierdo |
| Saltar | W / Espacio | A |
| Bajar plataforma | S + Saltar | Abajo + A |
| Apuntar | Ratón | Stick derecho |
| Disparar | Clic izquierdo | RT |
| Cambiar arma | 1–6 / Q E / rueda | LB / RB |
| Pausa / Gore | Esc / G | Start |
| Overlay rendimiento | F3 | — |
