---
name: threejs-stylized-lowpoly-model-design
description: Generate standalone Three.js 3D assets in a stylized low-poly game-art style inspired by cozy isometric/diorama assets. Use for vehicles, props, buildings, furniture, vegetation, environment pieces, tools, machines, and other general-purpose scene assets. Focus only on the asset model itself. Ignore scene lighting, red/pink environment tint, post-processing, and world setup unless explicitly requested.
---

# Three.js Stylized Low-Poly Model Design

Create **standalone Three.js asset models** that match this visual language:

- stylized low-poly game-art look
- clean, readable silhouettes
- chunky forms with slightly exaggerated proportions
- simple geometry assembled from clear sub-parts
- soft toy-like or handcrafted feel
- mostly solid-color materials with little or no texture dependence
- subtle bevels / edge softening where helpful
- medium-simple detail density: richer than ultra-minimal low poly, but still lightweight and readable
- suitable for cozy diorama, stylized game, or isometric environment assets

## Important style note

The reference image includes a **strong red/pink environment tint and scene lighting**.
Do **not** copy that lighting treatment as part of the asset style.

Focus on the **modeling language only**:

- the shapes
- the part breakdown
- the silhouette readability
- the chunky stylization
- the material simplicity
- the prop / vehicle / environment asset construction style

Unless explicitly requested, generate the asset with **neutral presentation-ready colors/materials**, not with red scene lighting, bloom-heavy glow, or environment color cast.

## Scope

Generate only the asset itself.

Allowed:
- `THREE.Group` asset root
- geometry
- materials
- local transforms
- reusable geometry helpers
- optional asset parameters
- optional small built-in animation hooks only when the asset naturally benefits from them

Do **not** add unless explicitly requested:
- renderer
- camera
- lights
- scene creation
- controls
- post-processing
- terrain/world setup
- particle systems
- shaders unrelated to the asset itself
- physics setup
- HTML/CSS
- UI/editor/app scaffolding

The result should be easy to insert into an existing project:

```ts
const asset = createAsset(options);
scene.add(asset);
```

## Core Art Direction

### 1) Shape language

Build assets from readable low-complexity forms:

- rounded or beveled boxes
- cylinders with low-to-medium radial segments
- simple prisms / wedges
- extruded shapes
- simple custom `BufferGeometry` only when primitives are not enough

Prefer **assembled parts** over one dense sculpted mesh.

Good examples:

```text
jeep      = body + cabin + fenders + roof rack + wheels + lights
outhouse  = wall panels + door + roof + trim + handle + props
lantern   = frame + glass body + top cap + base
tree      = trunk + clustered foliage volumes
bench     = seat + legs + supports
machine   = core body + panels + knobs + vents + supports
```

Avoid:
- high-poly sculpting
- dense smoothing everywhere
- micro-detail that only shows in close-up
- realistic wear/grunge as a requirement
- fragile thin pieces that disappear at gameplay distance

### 2) Readability first

Assume the asset will often be viewed from a slight elevated angle, isometric angle, or mid-distance game camera.

Prioritize, in order:
1. strong silhouette
2. clear main color blocks
3. large secondary forms
4. a few iconic features
5. tiny details only when they materially improve recognition

If a detail will only add noise, simplify it.

### 3) Proportions

Use **stylized, slightly exaggerated proportions**:

- primary masses can be chunkier than real life
- wheels, handles, lights, foliage clumps, hinges, knobs, and trim can be slightly oversized
- structural supports should be thick enough to read clearly
- proportions should feel game-friendly and pleasing, not mechanically precise

Do not distort so much that the object becomes ambiguous.

### 4) Edge treatment

Use clean hard-surface modeling with **selective softness**.

Preferred:
- crisp overall form
- subtle bevels/chamfers on hero edges
- slightly softened corners on larger parts
- enough edge treatment to avoid an overly harsh CAD look

Avoid:
- extremely sharp, razor-thin edges everywhere
- excessive bevel segments
- heavy smoothing that makes forms mushy

### 5) Surface detail density

Target **moderate simplicity**.

Compared with ultra-flat icon-like low poly, this style can contain:
- panel breaks
- trim pieces
- bumpers
- window frames
- wheel arches
- simple roof racks
- door handles
- hinges
- basic vents
- layered foliage clusters
- small supporting props

But keep them simplified and geometric.

### 6) Materials and color usage

Prefer lightweight materials such as:
- `MeshStandardMaterial`
- `MeshLambertMaterial`
- `MeshPhongMaterial`

Material guidance:
- mostly solid colors
- subtle roughness variation is okay
- low dependence on image textures
- little or no realistic weathering by default
- keep materials readable and stylized

Color guidance:
- use clean, harmonious local colors
- allow contrast between primary body color and accent details
- neutral output is preferred unless a color palette is explicitly requested
- avoid inheriting the red/pink environment wash from the reference image

If helpful, use tonal variation between adjacent parts to improve readability.

### 7) Foliage / organic assets

When modeling trees, bushes, grass, or crops:
- keep forms stylized and graphic
- use clustered volumes rather than botanical realism
- use leaf masses, spikes, tufts, or chunky blobs depending on the asset
- ensure the silhouette is interesting but simple
- keep trunk and stem thickness readable

Grass can be represented by repeated low-poly blades or tuft clusters, but should remain efficient.

### 8) Vehicles and mechanical assets

For vehicles and machines:
- favor playful ruggedness over exact realism
- simplify undercarriage and mechanical detail
- emphasize body silhouette, wheel stance, and major accessories
- use bold wheel arches, chunky tires, simplified lights, and readable trim
- keep cabins and body panels simplified but distinct

### 9) Small props and environmental pieces

For props (lanterns, stools, crates, signposts, tools, kiosks, terminals, etc.):
- aim for instant recognition
- use a compact part hierarchy
- slightly oversize secondary features for readability
- avoid overengineering hidden structure

## Technical Modeling Rules

### Geometry budget

Keep geometry efficient.

General guidance:
- small prop: low polycount
- medium prop / furniture / machine: modest polycount
- hero stylized vehicle / building chunk: moderate polycount

Prefer efficiency over realism.
Only add geometry where it improves silhouette or major readability.

### Reuse and composition

Prefer reusable helpers for repeated motifs:

- wheel creator
- window creator
- trim creator
- foliage cluster creator
- leg/support creator
- panel creator

Use symmetry and part reuse where sensible.

### Transform structure

Organize into sensible named groups/meshes:

```ts
asset
├─ body
├─ cabin
├─ wheelFL
├─ wheelFR
├─ wheelRL
├─ wheelRR
├─ accessories
└─ props
```

Name parts clearly when practical.

### Origin and orientation

Default conventions:
- Y-up
- asset rests on ground plane at `y = 0` when reasonable
- centered origin or sensible local origin for placement
- consistent scale across assets

## Implementation Expectations

Preferred output pattern:

```ts
export function createAsset(options = {}): THREE.Group {
  const root = new THREE.Group();
  // build parts
  return root;
}
```

Implementation style:
- modular
- readable
- reusable
- easy to tweak
- minimal external dependencies

Prefer direct Three.js construction over unnecessary abstraction.

## What to avoid

Do not default to:
- photorealism
- realistic high-frequency textures
- scene lighting baked into materials
- red/pink color cast from the reference environment
- cinematic fog or bloom as part of the asset definition
- hyper-detailed interiors unless requested
- dense mesh smoothing
- procedural noise overload
- very thin fragile geometry

## Asset quality checklist

Before finalizing, verify:

- silhouette is clear and appealing
- object reads well from a mid-distance game view
- part breakdown is clean and logical
- detail density is moderate, not noisy
- colors/materials remain stylized and simple
- asset feels consistent with stylized cozy low-poly game art
- no accidental dependency on the reference image's red environment lighting
- output is asset-only, with no scene/app boilerplate

## Examples of suitable asset categories

This skill is intended for general asset creation, including:
- vehicles
- houses and outbuildings
- kiosks and booths
- crates and containers
- lanterns and lights
- tools and equipment
- benches, tables, stools, chairs
- trees, bushes, grass clumps
- fences, signs, gates
- machines and utility props
- stylized environment set dressing

## Response behavior

When using this skill:
- produce the **asset model code only**
- keep style faithful to the chunky stylized low-poly modeling language
- ignore the reference scene's lighting mood unless explicitly requested
- if the user asks for a specific asset, adapt the same style to that asset category
- if the user does not specify colors, choose clear neutral stylized colors
