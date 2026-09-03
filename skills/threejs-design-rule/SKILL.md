# threejs-design-rule

## Purpose

Use this skill when designing, implementing, refactoring, or reviewing a production Three.js web visualization.

The goal is to keep Three.js applications:

* modular
* maintainable
* performant
* testable
* resource-safe
* easy to extend
* understandable by engineers who did not originally build the visualization

This skill applies especially to:

* interactive marketing websites
* product visualizations
* 3D landing pages
* immersive web experiences
* data visualizations
* WebGL/WebGPU visual applications
* scroll-driven Three.js experiences
* interactive 3D scenes

The preferred architecture is:

**composition + modular visual components + explicit lifecycle + centralized systems**

Do not enforce classical OOP or inheritance for its own sake.

---

# Core Architecture Principles

## 1. Prefer Composition Over Inheritance

Use OOP for encapsulation and ownership, but prefer composition over deep inheritance hierarchies.

Preferred:

```ts
class CarVisualization {
  readonly root = new THREE.Group();

  constructor(
    private assets: AssetManager,
    private interaction: InteractionSystem
  ) {}
}
```

Avoid:

```ts
class CarVisualization extends THREE.Group {
}
```

Strongly avoid application inheritance trees such as:

```text
Object3D
└── VisualObject
    └── InteractiveObject
        └── AnimatedInteractiveObject
            └── Car
```

Prefer composing capabilities:

```text
CarVisualization
├── root
├── animator
├── interaction
├── materials
└── state
```

Three.js already has its own object hierarchy. Do not create an unnecessary second framework hierarchy on top of it.

---

# 2. Every Visual Feature Must Be Modular

Every significant visual feature must be implemented as an isolated component/module.

Examples:

```text
HeroScene
Globe
ParticleField
Vehicle
Terrain
Ocean
Background
ProductModel
ScrollSequence
```

A visual component should own its internal Three.js objects and expose only a small public interface.

Preferred interface:

```ts
interface VisualComponent {
  readonly root: THREE.Object3D;

  init(): Promise<void>;
  update(dt: number, elapsed: number): void;
  resize(viewport: Viewport): void;
  dispose(): void;
}
```

Not every component must literally implement this TypeScript interface, but all significant visual modules should follow this lifecycle concept.

---

# 3. One Root Object Per Visual Component

Each visual feature should expose one root `Object3D`, usually a `THREE.Group`.

Example:

```ts
class Globe {
  readonly root = new THREE.Group();
}
```

The parent system adds only the root:

```ts
world.add(globe.root);
```

Internal meshes should remain implementation details.

Prefer:

```text
Scene
└── World
    ├── Globe.root
    │   ├── Surface
    │   ├── Atmosphere
    │   └── Markers
    │
    └── Vehicle.root
        ├── Body
        ├── Wheels
        └── Lights
```

Avoid having a feature directly add many unrelated objects to the global scene.

---

# 4. Enforce Explicit Lifecycle

Visual components should have predictable initialization and destruction.

Recommended lifecycle:

```text
construct
   ↓
init
   ↓
update
   ↓
resize
   ↓
dispose
```

Example:

```ts
class HeroScene implements VisualComponent {
  readonly root = new THREE.Group();

  async init() {
    // Load/create resources.
  }

  update(dt: number, elapsed: number) {
    // Update animation.
  }

  resize(viewport: Viewport) {
    // Respond to viewport changes if necessary.
  }

  dispose() {
    // Remove event handlers and release owned resources.
  }
}
```

Do not create resources that have no clear destruction path.

---

# 5. There Must Be Exactly One Application Render Loop

Only the engine/runtime owns `requestAnimationFrame` or `renderer.setAnimationLoop`.

Feature modules must never create independent render loops.

Forbidden:

```ts
// Feature A
requestAnimationFrame(loop);

// Feature B
requestAnimationFrame(loop);
```

Preferred:

```ts
class RenderLoop {
  update(dt: number, elapsed: number) {
    for (const component of components) {
      component.update(dt, elapsed);
    }

    renderer.render(scene, camera);
  }
}
```

Conceptually:

```text
Browser RAF
    │
    ▼
RenderLoop
    │
    ├── AnimationSystem
    ├── InteractionSystem
    ├── Feature A
    ├── Feature B
    └── Feature C
    │
    ▼
Renderer
```

Frame scheduling is infrastructure, not feature behavior.

---

# 6. Separate Engine Infrastructure From Product Features

Organize the project so generic Three.js infrastructure does not depend on specific visual features.

Recommended structure:

```text
src/
├── app/
│   ├── App.ts
│   └── config.ts
│
├── engine/
│   ├── Renderer.ts
│   ├── Camera.ts
│   ├── RenderLoop.ts
│   ├── Viewport.ts
│   ├── AssetManager.ts
│   ├── ResourceManager.ts
│   ├── InputManager.ts
│   └── InteractionSystem.ts
│
├── features/
│   ├── hero/
│   │   ├── HeroScene.ts
│   │   ├── HeroAnimation.ts
│   │   └── hero.config.ts
│   │
│   ├── globe/
│   │   ├── Globe.ts
│   │   ├── GlobeMaterial.ts
│   │   ├── GlobeInteraction.ts
│   │   └── shaders/
│   │
│   └── particles/
│       ├── ParticleField.ts
│       └── shaders/
│
├── assets/
│   └── manifest.ts
│
├── state/
├── ui/
├── shaders/
└── utils/
```

Dependency direction should generally be:

```text
app
 ↓
features
 ↓
engine
 ↓
three
```

The engine must not know that a `Globe`, `Car`, `Hero`, or other product-specific feature exists.

---

# 7. Avoid Global Mutable Three.js Objects

Do not expose mutable global instances such as:

```ts
import { scene } from "@/globals";
import { camera } from "@/globals";
import { renderer } from "@/globals";
```

This creates hidden dependencies and allows arbitrary modules to mutate global state.

Use explicit dependencies instead.

Example:

```ts
interface EngineContext {
  renderer: THREE.WebGLRenderer;
  camera: THREE.Camera;
  assets: AssetManager;
  interaction: InteractionSystem;
  viewport: Viewport;
}
```

Prefer injecting only what a component actually needs:

```ts
new Globe({
  assets,
  interaction,
});
```

Dependencies should be visible from the constructor or initialization API.

---

# 8. Centralize Asset Loading

Feature code must not create arbitrary loaders throughout the application.

Avoid:

```ts
new GLTFLoader().load(...);
new TextureLoader().load(...);
```

inside arbitrary feature classes.

Use an `AssetManager`.

Example:

```ts
const model = await assets.getGLTF("vehicle");
const normal = await assets.getTexture("vehicleNormal");
```

Define assets centrally:

```ts
export const ASSETS = {
  vehicle: "/models/vehicle.glb",
  vehicleNormal: "/textures/vehicle-normal.ktx2",
  studioEnvironment: "/environment/studio.hdr",
};
```

Asset infrastructure should handle where appropriate:

```text
AssetManager
├── caching
├── deduplication
├── preload
├── loading progress
├── errors
├── GLTF
├── textures
├── HDR/environment maps
├── compressed textures
└── shared resource lifetime
```

Do not download or decode the same asset repeatedly.

---

# 9. GPU Resource Ownership Must Be Explicit

Every GPU resource must have an identifiable owner.

Relevant resources include:

* Geometry
* Material
* Texture
* RenderTarget
* CubeRenderTarget
* ShaderMaterial
* DataTexture
* PMREM-generated resources
* GPUComputation resources
* post-processing buffers

Three.js resources are not automatically released simply because their JavaScript objects become unreachable.

Distinguish between:

```text
SHARED RESOURCE
AssetManager owns lifetime

LOCAL RESOURCE
Feature owns lifetime
```

Example:

```ts
class ParticleField {
  private geometry: THREE.BufferGeometry;
  private material: THREE.ShaderMaterial;

  dispose() {
    this.geometry.dispose();
    this.material.dispose();
  }
}
```

Do not dispose shared resources from individual features unless ownership has explicitly been transferred.

---

# 10. Application State Must Be Separate From Scene State

Do not use Three.js objects as the application's state database.

Avoid:

```ts
mesh.userData.selected = true;
scene.getObjectByName("CAR")!.userData.mode = "editing";
```

Preferred:

```ts
state.vehicle.selected = true;
state.vehicle.mode = "editing";
```

Then update the visual representation:

```text
Application State
       │
       ▼
Visual Component
       │
       ▼
Three.js Scene Graph
```

`userData` is acceptable for lightweight rendering or interaction metadata, but should not contain core business/application state.

---

# 11. Never Use Scene Lookup as Component Communication

Avoid:

```ts
scene.getObjectByName("car");
scene.getObjectByName("hero");
```

for dependencies between features.

This creates hidden coupling.

Prefer explicit references:

```ts
class App {
  constructor(
    private car: CarVisualization,
    private hero: HeroScene
  ) {}
}
```

or state/event communication:

```text
Feature A
   │
   ▼
State / Event
   │
   ▼
Feature B
```

Features should not reach into unrelated feature internals.

---

# 12. Define Scene Graph Conventions

The global scene graph should have predictable top-level organization.

Example:

```text
Scene
├── Environment
├── World
│   ├── Product
│   ├── EnvironmentGeometry
│   └── Effects
├── Overlay3D
└── Debug
```

Avoid an unstructured scene such as:

```text
Scene
├── Mesh
├── Mesh
├── Light
├── Group
├── Sprite
├── Mesh
├── Group
├── Mesh
└── ...
```

Top-level scene ownership should be deliberate.

---

# 13. Centralize Input and Interaction

Do not let every feature independently attach browser events.

Avoid:

```ts
window.addEventListener("pointermove", ...);
window.addEventListener("click", ...);
window.addEventListener("touchstart", ...);
```

inside arbitrary components.

Prefer:

```text
Browser Events
     │
     ▼
InputManager
     │
     ▼
InteractionSystem
     │
     ▼
Raycaster
     │
     ▼
Registered Interactive Objects
```

Example:

```ts
interaction.register(mesh, {
  onHover,
  onLeave,
  onClick,
});
```

The interaction system should manage:

* pointer coordinates
* touch normalization
* raycasting
* hover state
* cursor state
* input priority
* DOM vs WebGL interactions
* listener cleanup

---

# 14. Centralize Viewport and Resize Handling

Features should not independently attach `window.resize` handlers.

Use one viewport system.

Example:

```ts
interface Viewport {
  width: number;
  height: number;
  aspect: number;
  pixelRatio: number;
}
```

The viewport system updates:

```text
Renderer
Camera
Postprocessing
Visual Components
```

through controlled notifications.

---

# 15. Define a Device Pixel Ratio Policy

Never blindly assume maximum device pixel ratio is appropriate.

Avoid:

```ts
renderer.setPixelRatio(window.devicePixelRatio);
```

Prefer:

```ts
const pixelRatio = Math.min(
  window.devicePixelRatio,
  MAX_PIXEL_RATIO
);

renderer.setPixelRatio(pixelRatio);
```

A common starting point is:

```ts
MAX_PIXEL_RATIO = 1.5;
```

or:

```ts
MAX_PIXEL_RATIO = 2;
```

The exact value should be determined by the application's visual and performance requirements.

Consider dynamic resolution scaling for GPU-heavy experiences.

---

# 16. Avoid Allocations in Hot Update Paths

Code executed every frame should avoid unnecessary allocations.

Avoid:

```ts
update() {
  const position = new THREE.Vector3();
  const matrix = new THREE.Matrix4();
}
```

Prefer:

```ts
class Feature {
  private readonly tempPosition = new THREE.Vector3();
  private readonly tempMatrix = new THREE.Matrix4();

  update() {
    this.tempPosition.set(...);
  }
}
```

Be cautious with per-frame use of:

```ts
new Vector3()
new Matrix4()
new Quaternion()
new Color()

array.map()
array.filter()
array.reduce()
Array.from()

scene.traverse()
object.clone()
```

Allocations in hot paths should be deliberate and justified.

---

# 17. Avoid Full Scene Traversal Per Frame

Do not repeatedly search or traverse the entire scene graph in update loops.

Avoid:

```ts
update() {
  scene.traverse((object) => {
    ...
  });
}
```

Maintain direct references or collections to objects that require updates.

Preferred:

```ts
for (const animatedObject of animatedObjects) {
  animatedObject.update(dt);
}
```

---

# 18. Optimize Repeated Geometry

When many objects share geometry/material characteristics, evaluate:

* `THREE.InstancedMesh`
* merged geometry
* batching
* texture atlases
* shared materials
* shared geometries

Avoid thousands of individual meshes when instancing can represent the same visual result.

Do not optimize blindly; measure first.

---

# 19. Treat Shaders as First-Class Modules

Do not bury large shader programs inside unrelated TypeScript classes.

Avoid:

```ts
const material = new THREE.ShaderMaterial({
  vertexShader: `
    // hundreds of lines
  `,
});
```

Prefer:

```text
features/ocean/
├── Ocean.ts
├── OceanMaterial.ts
└── shaders/
    ├── ocean.vert.glsl
    ├── ocean.frag.glsl
    ├── noise.glsl
    └── lighting.glsl
```

Define shader uniform contracts where practical.

Example:

```ts
interface OceanUniforms {
  uTime: THREE.Uniform<number>;
  uWind: THREE.Uniform<THREE.Vector2>;
  uColor: THREE.Uniform<THREE.Color>;
}
```

Shader code should be modular, named, reviewable, and version-controlled like application code.

---

# 20. Use TypeScript Strict Mode

Production Three.js applications should use TypeScript with strict checks unless there is a strong project-specific reason not to.

Recommended baseline:

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "noUncheckedIndexedAccess": true
  }
}
```

Avoid `any` around:

* Three.js objects
* GLTF structures
* shaders
* uniforms
* application state
* component interfaces

Create explicit types where the base Three.js API cannot express application-specific constraints.

---

# 21. Pin the Three.js Version

Do not use a loose Three.js dependency range for production visualization projects.

Avoid:

```json
{
  "three": "^0.185.0"
}
```

Prefer:

```json
{
  "three": "0.185.0"
}
```

Three.js changes relatively quickly and examples/addons often evolve alongside the core library.

Upgrade Three.js deliberately and test the visual application after upgrades.

Keep `three` and related Three.js ecosystem packages compatible.

---

# 22. Define Performance Budgets

Performance must be measurable.

Do not accept requirements such as:

> Keep the scene performant.

Instead define budgets appropriate to the project.

Example starting point:

```yaml
performance:
  targetFPS:
    desktop: 60
    mobile: 30

  maxPixelRatio: 2

  drawCalls:
    desktop: 300
    mobile: 150

  triangles:
    desktop: 1500000
    mobile: 500000

  maxTextureSize:
    desktop: 4096
    mobile: 2048
```

These numbers are examples, not universal limits.

The project should define its own budgets based on target devices and visual requirements.

---

# 23. Instrument Performance in Development

Development/debug builds should make important rendering metrics visible.

At minimum monitor:

```text
FPS
frame time
draw calls
triangles
points
lines
geometry count
texture count
shader programs
pixel ratio
viewport resolution
```

Use:

```ts
renderer.info
```

where appropriate.

Prefer detecting performance regressions during development rather than after deployment.

---

# 24. Keep DOM/UI and Three.js Responsibilities Separate

Three.js should not become the entire application architecture.

Prefer:

```text
Application UI / DOM
        │
        ▼
Application State
        │
        ▼
Three.js Visualization
```

DOM UI owns things such as:

* forms
* navigation
* accessibility
* textual content
* standard buttons
* page layout

Three.js owns things such as:

* scene rendering
* 3D animation
* camera behavior
* materials
* visual effects
* 3D interaction

Do not render ordinary web UI in WebGL unless there is a visual reason to do so.

---

# 25. Make Feature Dependencies One-Directional

Avoid circular dependencies.

Preferred:

```text
App
 ↓
Feature
 ↓
Engine service
 ↓
Three.js
```

Avoid:

```text
Feature A
 ↕
Feature B
 ↕
Feature C
 ↕
App
```

Cross-feature communication should preferably go through:

* application state
* explicit events
* commands
* application orchestration

rather than direct mutation.

---

# 26. Do Not Over-Engineer

Do not introduce architectural abstractions without a concrete need.

Avoid building:

* custom ECS for a simple landing page
* giant dependency injection frameworks
* deep abstract base classes
* generic scene-graph wrappers around every Three.js API
* excessive factories
* excessive event buses
* unnecessary repositories/services/managers

The architecture should make Three.js easier to understand, not hide Three.js.

Prefer the simplest architecture satisfying:

```text
modularity
ownership
lifecycle
performance
explicit dependencies
```

---

# Recommended Architecture

A typical production architecture should resemble:

```text
                         App
                          │
                ┌─────────┴─────────┐
                │                   │
              State               Engine
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
               AssetManager    RenderLoop    InteractionSystem
                    │               │               │
                    └───────────┬───┴─────┬─────────┘
                                │         │
                           Feature A   Feature B
                                │         │
                              Group     Group
                                └────┬────┘
                                     │
                                   Scene
                                     │
                                  Renderer
```

The architecture does not need to match this diagram exactly.

The important properties are:

1. one application runtime
2. explicit dependencies
3. isolated visual features
4. centralized infrastructure
5. explicit resource ownership
6. predictable lifecycle

---

# Standard Visual Component Pattern

Use this as the default pattern for significant visual features:

```ts
export interface VisualComponent {
  readonly root: THREE.Object3D;

  init(): Promise<void>;

  update(
    dt: number,
    elapsed: number
  ): void;

  resize(
    viewport: Viewport
  ): void;

  dispose(): void;
}
```

Example:

```ts
export class ProductModel implements VisualComponent {
  readonly root = new THREE.Group();

  constructor(
    private readonly assets: AssetManager,
    private readonly interaction: InteractionSystem
  ) {}

  async init(): Promise<void> {
    const gltf = await this.assets.getGLTF("product");

    this.root.add(gltf.scene);
  }

  update(dt: number, elapsed: number): void {
    // Animation logic.
  }

  resize(viewport: Viewport): void {
    // Only if feature-specific resize behavior exists.
  }

  dispose(): void {
    // Release resources owned specifically by this feature.
  }
}
```

Do not force trivial static objects into full lifecycle classes when a simple function/module would be clearer.

---

# Code Review Rules

When reviewing Three.js code, actively flag the following.

## Architecture

Flag:

```text
global mutable renderer/scene/camera
cross-feature internal mutation
deep inheritance
circular feature dependencies
scene.getObjectByName used for dependency resolution
feature-created requestAnimationFrame loops
```

## Resources

Flag:

```text
materials without clear ownership
geometry without clear ownership
render targets without disposal
temporary GPU resources that accumulate
duplicate asset loads
shared resources disposed by individual features
```

## Performance

Flag:

```text
per-frame allocations
scene traversal every frame
excessive draw calls
large uncompressed textures
unbounded device pixel ratio
large numbers of independent meshes
expensive operations inside pointermove
unnecessary material instances
```

## Input

Flag:

```text
many feature-specific window event listeners
duplicate raycasters
duplicate pointer normalization
listeners not removed during disposal
```

## Maintainability

Flag:

```text
giant scene classes
giant update() methods
embedded multi-hundred-line shaders
magic asset URLs
magic scene object names
business state stored in userData
implicit component dependencies
```

---

# Anti-Patterns

## God Scene

Avoid:

```ts
class Experience {
  // renderer
  // camera
  // loading
  // particles
  // car
  // globe
  // animation
  // scroll
  // interaction
  // shaders
  // state
  // postprocessing
  // audio
  // everything
}
```

Split infrastructure and visual features.

---

## Global Scene Mutation

Avoid:

```ts
import { scene } from "./app";

scene.add(mesh);
```

from arbitrary modules.

The owning feature or scene orchestrator should control scene attachment.

---

## Hidden Asset Loading

Avoid:

```ts
class Button3D {
  constructor() {
    new TextureLoader().load("/button.png");
  }
}
```

Loading should be explicit and centralized.

---

## Object Name Dependency Injection

Avoid:

```ts
const vehicle =
  scene.getObjectByName("vehicle") as THREE.Group;
```

Use explicit references.

---

## Permanent Event Handlers

Avoid:

```ts
window.addEventListener("mousemove", this.onMove);
```

without a matching cleanup path.

Every registration must have an owner and removal strategy.

---

## Update Method as Application Controller

Avoid giant methods:

```ts
update() {
  updateCar();
  updateOcean();
  updateCamera();
  updateUI();
  updateScroll();
  updateParticles();
  updateLoading();
  updateState();
  ...
}
```

Delegate updates to appropriate systems/components.

---

# Testing Strategy

Do not expect traditional unit tests to fully validate rendering correctness.

Use multiple layers.

## Unit Tests

Suitable for:

* math
* state transitions
* utility functions
* animation calculations
* asset manifest logic
* component state
* camera calculations

## Integration Tests

Suitable for:

* lifecycle behavior
* asset loading
* feature initialization
* resize propagation
* dispose behavior

## Visual Regression Tests

Use screenshots or rendered-frame comparisons for important visual states when appropriate.

## Performance Tests

Track representative scenes and detect major regressions in:

* frame time
* draw calls
* triangles
* memory/resource counts

---

# When ECS Is Appropriate

Do not adopt ECS automatically.

Consider ECS when the project contains:

* thousands of dynamic entities
* many entities sharing behavior
* simulation-heavy logic
* game-like worlds
* complex entity composition
* high-frequency entity creation/destruction

For typical interactive websites, product experiences, landing pages, and high-end visual storytelling, prefer:

```text
components
+
central systems
+
application state
```

over ECS.

---

# Decision Priorities

When choosing between architectural approaches, prioritize in this order:

```text
Composition             ★★★★★
Modular components      ★★★★★
Explicit lifecycle      ★★★★★
Resource ownership      ★★★★★
Central systems         ★★★★★
Type safety             ★★★★☆
Dependency injection    ★★★★☆
OOD encapsulation       ★★★★☆
Inheritance             ★☆☆☆☆
ECS                     ★★☆☆☆
```

---

# Mandatory Engineering Rules

Unless a project has a documented reason to deviate, enforce:

1. TypeScript strict mode.
2. Significant visual features are modular.
3. Each visual feature exposes one root `Object3D`.
4. Visual features have explicit lifecycle and cleanup.
5. Only the runtime owns the render loop.
6. `requestAnimationFrame` is forbidden inside feature modules.
7. Renderer, camera, and scene are not mutable globals.
8. Dependencies are explicit.
9. Prefer composition over inheritance.
10. Application state is separate from Three.js scene state.
11. Assets go through centralized asset infrastructure.
12. GPU resource ownership is explicit.
13. Owned GPU resources are disposed.
14. Avoid allocations in frame-critical code.
15. Avoid full scene traversal inside frame-critical code.
16. Shared resources are cached and reused.
17. Evaluate instancing/batching for repeated objects.
18. Shader code is modular.
19. Input and raycasting are centralized.
20. Resize and DPR handling are centralized.
21. Performance budgets are defined and measurable.
22. Features cannot mutate unrelated feature internals.
23. Do not use scene-name lookup as cross-feature communication.
24. Pin the exact Three.js version.
25. Development tooling exposes rendering/performance metrics.

---

# Rule of Thumb

When evaluating a Three.js design, ask:

> Can this visual feature be understood, initialized, updated, resized, removed, and disposed without understanding the internals of unrelated features?

If the answer is no, the feature is probably too tightly coupled.

Then ask:

> Is it obvious who owns every Three.js object and GPU resource?

If the answer is no, ownership needs to be clarified.

Finally ask:

> Is frame-critical work bounded, measurable, and centralized?

If the answer is no, review the performance architecture.

---

# Final Design Principle

Do not attempt to hide Three.js behind a large custom framework.

Build a thin application architecture around Three.js that provides:

```text
lifecycle
ownership
modularity
dependency boundaries
resource management
performance discipline
```

while allowing engineers to use Three.js APIs directly where appropriate.

The target is not maximum abstraction.

The target is a Three.js codebase that remains understandable and performant as the visual experience grows.
