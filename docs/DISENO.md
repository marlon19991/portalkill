# PORTALKILL — Documento de diseño (Tower Defense)

> Torre vertical de pisos · las hordas bajan en zigzag de portal en portal · tú colocas **trampas elementales** que se combinan · gore opcional (+18) · pensado para **celular**.

---

## 1. Visión (basada en tu boceto)

```
  START (portal verde) ───────────────────────►  entran por la derecha
  Piso 1   ◄──── X ──── X ──── X ────  (los enemigos caminan a la izquierda)
           portal ▼
  Piso 2   ──── X ──── X ──── X ────►
                                    ▼ portal
  Piso 3   ◄──── X ──── X ──── X ────
           portal ▼
  Piso 4   ──── X ──── X ──── X ────►  FINISH (si llegan, pierdes vidas)
```

- Los enemigos **solo caminan** siguiendo la ruta en zigzag y bajan de piso por los portales.
- Cada piso tiene **casillas de construcción** (X). Tocas una casilla, eliges una trampa y la pagas con oro.
- Ganas **oro** por cada baja y por empezar la oleada antes de tiempo.
- Si un enemigo llega al FINISH, pierdes vidas. Ganas al sobrevivir todas las oleadas del nivel.

**La gracia son los combos entre trampas de pisos distintos:**

| Combo | Resultado |
|---|---|
| Aspersor (moja) → Bobina Tesla | La electricidad salta en cadena y aturde el doble |
| Derrame de aceite → Lanzallamas | ¡NAPALM!: explosión y gran incendio |
| Aspersor → Lanzallamas | Anti-combo: el agua apaga el fuego (hay que planificar el orden) |
| Sierra (corte) | Sangrado y desmembramiento: sin piernas se arrastran (más lentos) |
| Pisón | Golpe que **empuja hacia atrás** en la ruta (más tiempo bajo tus trampas) |

Referencias: **Dungeon Warfare 2** (trampas en pasillos, gore, pixel art), **Orcs Must Die!** (combos de trampas), **Kingdom Rush** (oleadas y mejoras).

## 2. Plataforma y tecnología

**Motor: Godot 4.7.2 (GDScript)**, renderer `Compatibility` (WebGL2). Funciona en Safari de iPhone, Android y PC.

- **Pruebas en tu iPhone:** build Web publicado en **GitHub Pages** (link fijo). En Safari: *Compartir → Agregar a inicio* y se abre a pantalla completa como una app (PWA).
- **App nativa más adelante:** Godot exporta a iOS (proyecto de Xcode). Para TestFlight o App Store se necesita la cuenta de Apple Developer (USD 99 al año). Para Android basta con generar un APK o publicar en Google Play (USD 25, pago único).
- Usa la versión **estándar** de Godot (`~/Applications/Godot.app`), no Godot_mono: la versión .NET pide `dotnet`, que no está instalado, y no exporta a Web.

### Distribución
1. **GitHub Pages / itch.io** (gratis): pruebas y feedback.
2. **Google Play** (USD 25) y **App Store** (USD 99 al año). Para la App Store revisa sus reglas sobre violencia gráfica: el interruptor de gore y la clasificación +17 ayudan.
3. **Steam** (USD 100): versión de PC con mouse.

## 3. Cómo lograr el look pixel art (recomendaciones)

**Configuración del proyecto (ya aplicada):**
- Resolución interna **360×640 vertical** (para celular). El alto crece según la pantalla (`aspect = keep_width`), así aprovecha toda la altura del iPhone.
- `stretch/mode = viewport`: el juego se dibuja a resolución baja y se escala con filtro *nearest*, así los píxeles se ven nítidos.
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
  core/    events.gd (bus) · game.gd (estado: oro, vidas, oleada, ajustes) · pixel.gd · glow_layer.gd
  data/    trap_data.gd · enemy_data.gd · catalog.gd (trampas y enemigos)
  combat/  damage_info.gd · elements.gd (estados + reacciones) · projectile_system.gd
  world/   tower.gd (pisos, ruta en zigzag, casillas, colisión analítica) · portal.gd · wave_director.gd
  actors/  enemy.gd (seguidor de ruta, sin física) · enemy_visual.gd · trap.gd (comportamientos)
  fx/      blood_system.gd · gib_system.gd · fx_system.gd
  ui/      hud.gd (barra superior + panel táctil de construcción) · overlay.gd
  main.gd
```

### Decisiones de rendimiento
| Sistema | Técnica |
|---|---|
| Enemigos | **Sin física:** cada uno es una posición 1D sobre la ruta (piso + x). Cientos de enemigos cuestan muy poco |
| Colisión de sangre, gibs y balas | **Analítica:** el suelo de cada piso es un rectángulo y se revisan 4 pisos, sin grid ni raycasts |
| Trampas | Buscan objetivos solo entre los enemigos de **su piso** (listas por piso) |
| Sangre y gibs | Partículas en PackedArrays + lienzo persistente (las manchas no tienen costo acumulado) |
| Balas y efectos | Arrays + un único `_draw` + capa aditiva para brillos |
| Datos | Trampas y enemigos como `Resource`: el balance se edita sin tocar código |

### Trampas del prototipo
| Trampa | Elemento | Ubicación | Efecto |
|---|---|---|---|
| Sierra | Corte | suelo | Daño continuo, sangrado, desmembramiento |
| Lanzallamas | Fuego | suelo | Ráfagas que incendian |
| Bobina Tesla | Eléctrico | techo | Arco en cadena; mojados: x2 |
| Aspersor | Agua | techo | Moja y ralentiza; apaga fuego |
| Derrame de aceite | Aceite | techo | Charcos pegajosos (ralentizan) e inflamables |
| Torreta | Impacto | pared | Dispara al más cercano del piso |
| Pisón | Impacto | techo | Aplasta y empuja hacia atrás |

Cada trampa tiene **3 niveles** de mejora (más daño y cadencia, y cambia su aspecto) y se puede **vender** por el 60 % de lo invertido.

### Enemigos del prototipo
| Enemigo | Rasgo |
|---|---|
| Carroñero | Básico |
| Corredor | Rápido y frágil, en grupos |
| Bruto | Mucha vida, resiste el corte, **quita 3 vidas** |
| Hinchado | Al morir deja aceite (combo con fuego) |

## 5. Gore y contenido +18
- Ajuste **Gore: Apagado / Normal / Extremo** (botón en el HUD).
- El desmembramiento tiene efecto en el juego: sin piernas el enemigo se arrastra más lento, y sin cabeza muere.
- La sangre y los restos quedan pintados en la torre durante todo el nivel.

## 6. Hoja de ruta

### Fase 0 — Prototipo TD ✅ (esta entrega)
Torre de 4 pisos, 20 casillas, 7 trampas con mejoras y venta, 4 enemigos, 12 oleadas, combos, gore y controles táctiles. Build Web para iPhone.

### Fase 1 — Sensación y arte
Sonido y música, sprites reales (tileset de la torre, enemigos, trampas), animaciones de construcción e interfaz pulida.

### Fase 2 — Profundidad
- **Fusión de trampas** adyacentes (Sierra + Tesla = sierra eléctrica; Aceite + Lanzallamas = lanzanapalm).
- **Habilidades activas** con recarga: tormenta eléctrica, inundar un piso, lluvia de molotovs.
- Enemigos especiales: con armadura, voladores que se saltan un piso, uno que cura, uno que desactiva trampas, jefes.
- Torres con distintos números de pisos, portales trampa que reordenan la ruta y pisos con agua o gas.

### Fase 3 — Meta-progresión
Mapa de niveles (torres), estrellas por nivel, desbloqueo de trampas y modo infinito con ranking.

### Fase 4 — Distribución
PWA → Google Play / App Store → Steam.

## 7. Controles (táctil)
- **Tocar una casilla vacía** abre el panel de trampas; tocar una trampa construye.
- **Tocar una trampa construida** permite mejorarla o venderla.
- **Botones:** ▶ iniciar oleada (antes de tiempo da oro extra) · velocidad x1/x2 · gore · pausa.
- En PC funciona igual con el mouse.
