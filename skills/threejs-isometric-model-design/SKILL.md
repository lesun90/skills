---
name: threejs-isometric-model-design
description: Generate standalone Three.js 3D assets in a clean stylized isometric low-poly/vector-like art style. Use for buildings, vehicles, furniture, vegetation, machines, props, environment pieces, and other general-purpose scene assets. Focus only on asset geometry/materials; do not create renderer, camera, lights, controls, scene bootstrapping, UI, or app setup unless explicitly requested.
---

# Three.js Model Design

Create **standalone Three.js asset models** matching this visual language:

- stylized isometric / miniature-diorama look
- low-poly, clean, readable silhouettes
- simple geometric construction
- flat or lightly rough materials
- muted but distinct colors
- crisp edges; little or no texture detail
- small exaggerated details for readability
- soft, toy-like proportions rather than photorealism
- no heavy realism, PBR complexity, grunge, or dense meshes

The reference style resembles vector/isometric illustration translated into simple 3D geometry.

## Scope

Generate only the asset itself.

Allowed:
- `THREE.Group` asset root
- geometry
- materials
- local transforms
- reusable geometry helpers
- optional asset parameters
- optional lightweight animation hooks when the asset inherently needs them

Do **not** add unless explicitly requested:
- renderer
- camera
- lights
- scene creation
- controls
- post-processing
- loaders unrelated to the asset
- GUI/editor code
- application state
- physics setup
- HTML/CSS

The returned asset should be easy to insert into an existing scene:

```ts
const asset = createAsset(options);
scene.add(asset);
```

## Core Art Direction

### 1. Shape language

Prefer primitive and low-complexity forms:

- boxes
- wedges/prisms
- cylinders with low radial segments
- cones with low radial segments
- simple extrusions
- simple custom `BufferGeometry` only when primitives cannot express the form cleanly

Build complex objects from readable sub-parts instead of one dense mesh.

Good:

```text
vehicle = body + cabin + wheels + lights + bumpers
bench   = seat + backrest + legs
robot   = torso + head + limbs + joints
lamp    = pole + arm + shade + bulb housing
```

Avoid:
- sculpted organic surfaces unless necessary
- high subdivision counts
- photogrammetry-like detail
- micro-bevels everywhere
- invisible geometry detail

### 2. Silhouette first

The model must remain recognizable from a medium-distance isometric view.

Prioritize, in order:
1. outer silhouette
2. major color blocks
3. large secondary forms
4. a few iconic details
5. tiny details only if they materially improve recognition

If a detail will occupy only a few screen pixels, simplify or omit it.

### 3. Proportions

Use slightly stylized proportions:

- major forms can be chunkier than real life
- windows, lights, handles, wheels, leaves, knobs, etc. may be slightly oversized
- thin structural parts should be thickened enough to remain visible
- avoid extremely thin planes that disappear at distance

Do not distort so much that the asset loses its category or function.

### 4. Edge treatment

Default to crisp hard-surface geometry.

Use bevels sparingly when they noticeably improve the toy-like look. Keep them broad and low-segment.

Prefer:
- hard corners
- simple chamfers
- low-segment beveled boxes

Avoid:
- dense rounded edges
- subdivision-surface aesthetics
- excessively smooth silhouettes

### 5. Curves

Curved parts should still look stylized.

Typical segment counts:
- tiny cylinder: 6–8
- normal visible cylinder: 8–12
- large focal circular object: 12–16

Use more only when the silhouette clearly requires it.

## Material Rules

Prefer `MeshStandardMaterial` or `MeshLambertMaterial` with simple solid colors.

Default `MeshStandardMaterial` guidance:

```ts
new THREE.MeshStandardMaterial({
  color,
  roughness: 0.75,
  metalness: 0.0,
});
```

Use metalness only for parts that visually need to read as metal.

### Palette

Use a compact palette per asset:
- 1 primary color
- 1 secondary color
- 1 dark structural color
- 1 light/accent color
- optional vegetation/natural colors

Typical style families:
- warm cream / beige
- muted orange / terracotta
- brick red
- mustard yellow
- charcoal / blue-black
- desaturated gray
- medium grass green
- dark evergreen
- off-white

Colors should be distinct enough to separate forms without looking neon.

### Material reuse

Reuse material instances when parts share the same visual material.

Good:

```ts
const wallMat = new THREE.MeshStandardMaterial(...);
const trimMat = new THREE.MeshStandardMaterial(...);
```

Avoid creating one material instance per mesh unless the colors/properties differ.

### Textures

Default: **no textures**.

Represent detail with geometry and color blocking.

Use textures only if the user explicitly requests them or geometry would be substantially worse.

Avoid:
- photo textures
- normal-map noise
- dirt/grunge overlays
- high-frequency patterns

For repeated patterns such as roof tiles, vents, panels, bricks, or windows, prefer a few modeled cues rather than covering every surface.

## Surface Detail

Use simple depth layering rather than flat decals when practical.

Examples:
- windows: shallow inset or thin pane + frame
- doors: thin box slightly proud of wall
- lights: small emissive/non-emissive block
- vents: 2–4 slats, not 30
- roof ridges: one strip
- buttons: small cylinders or boxes
- panel seams: shallow geometry only if visible

Keep detail depth subtle and consistent.

## General Asset Construction

Every asset should have a clear hierarchy:

```text
AssetRoot
├─ MainMass
├─ SecondaryMasses
├─ FunctionalParts
├─ AccentDetails
└─ OptionalMovingParts
```

Prefer multiple named `THREE.Group`s for meaningful subassemblies.

Example:

```ts
const root = new THREE.Group();
root.name = 'Forklift';

const body = new THREE.Group();
body.name = 'Body';
root.add(body);

const mast = new THREE.Group();
mast.name = 'Mast';
root.add(mast);
```

Do not create excessive hierarchy for trivial pieces.

## Origin, Scale, and Orientation

Unless the project specifies otherwise:

- Y is up
- asset faces +Z or a clearly documented forward axis
- place the root at the logical ground/contact center
- bottom of a ground-standing asset should sit at `y = 0`
- use a consistent human-readable scale

Recommended convention:

```text
1 Three.js unit = 1 meter
```

Approximate real dimensions are useful, but visual readability takes priority over exact CAD accuracy.

For wall-mounted, hanging, handheld, or airborne assets, use the most useful logical pivot and document it briefly.

## Style Translation by Asset Type

### Buildings
- blocky wall masses
- simple pitched/hip/flat roofs
- roof slightly oversized relative to walls
- windows as repeated simplified modules
- doors and trim slightly protruding/inset
- chimneys, awnings, dormers, balconies represented with chunky primitives
- avoid modeling every architectural seam

### Vehicles
- simplify body into 2–5 major volumes
- chunky cabin/body proportions
- wheels slightly oversized
- low-segment cylinders
- lights and windows as strong color blocks
- minimal underbody detail

### Furniture / Props
- thicken thin surfaces
- exaggerate characteristic handles/legs/knobs
- use clear material/color separation
- avoid manufacturing-level detail

### Vegetation
- stylized trunks from low-segment cylinders
- foliage from cones, low-poly spheres, clustered polyhedra, or simple tapered forms
- use 1–3 foliage shapes/colors
- avoid individual leaves unless the asset is a close-up focal object

### Machines / Industrial Assets
- identify major functional masses first
- simplify pipes, cylinders, tanks, panels, guards, and supports
- keep a few recognizable mechanical cues
- do not reproduce every bolt, hose, or fastener

### Characters / Creatures
When explicitly requested:
- use simplified low-poly body masses
- readable pose and silhouette over anatomy detail
- simplified hands/feet/facial features
- avoid realistic skin/hair shaders unless requested

## Geometry Reuse

Create small helpers for repeated visual motifs.

Useful helpers may include:
- `createBoxPart(...)`
- `createBeveledBox(...)`
- `createWindow(...)`
- `createWheel(...)`
- `createLowPolyCylinder(...)`
- `createPanel(...)`
- `createTree(...)`

Do not build a framework when one or two helpers are enough.

Prefer parameterized helpers over copy-pasted mesh construction.

## Performance

Assets should be lightweight by default.

Rules:
- keep primitive segment counts low
- share geometries/materials when sensible
- use `InstancedMesh` for many repeated identical parts only when the repetition count justifies it
- avoid unnecessary transparency
- avoid expensive shaders
- avoid per-frame work in static assets
- do not allocate objects in animation loops

For a normal scene prop, target dozens of meshes or fewer when possible, not hundreds.

## Shadows / AO Compatibility

The reference look benefits from soft contact shading, but **lighting is outside this skill's scope**.

Prepare the meshes to work well with the host scene:

```ts
mesh.castShadow = true;
mesh.receiveShadow = true;
```

Use judgment:
- opaque solid parts usually cast/receive
- tiny accents may skip shadows
- transparent panes generally should not cast heavy shadows

Do not create lights or shadow configuration.

## Windows, Glass, and Transparent Parts

The target style generally reads better with opaque or nearly opaque colored panes than realistic glass.

Prefer:
- dark blue-gray
- desaturated teal
- charcoal
- warm light cream for lit windows

Only use transparency when it clearly improves the asset.

If used, keep it simple and avoid multilayer glass.

## Optional Emissive Accents

For screens, lamps, indicators, or windows, subtle emissive color is allowed:

```ts
new THREE.MeshStandardMaterial({
  color: 0xffd98a,
  emissive: 0xffb84d,
  emissiveIntensity: 0.2,
  roughness: 0.8,
});
```

Keep emissive intensity restrained. The asset should still read under ordinary scene lighting.

## Code Design

Default to TypeScript.

Use a small public API:

```ts
export interface AssetOptions {
  scale?: number;
  // only meaningful visual/model parameters
}

export function createAsset(options: AssetOptions = {}): THREE.Group {
  const root = new THREE.Group();
  // build model
  return root;
}
```

Rules:
- keep implementation modular
- separate repeated geometry helpers
- name significant groups/meshes
- avoid global mutable state
- avoid dependencies beyond `three` unless necessary
- expose only meaningful customization parameters
- do not expose dozens of low-level dimensions unless requested

## Parameterization

Good parameters affect the identity or intended variation of the asset:

```ts
createTree({
  height: 4,
  canopyStyle: 'conical',
  trunkColor: 0x6b4a2d,
  foliageColor: 0x3f7d3c,
});
```

Bad parameters expose every internal measurement:

```text
windowInsetDepth
roofEdgeOffsetLeft
boltRadius03
trimPiece7Height
```

Keep the default asset visually complete without requiring configuration.

## Avoid Generic Placeholder Assets

Do not stop at a primitive stand-in such as:

```ts
new THREE.BoxGeometry(1, 1, 1)
```

when the user asks for a recognizable asset.

Even simple assets should include the few forms that communicate their identity.

Examples:
- mailbox → post + box + curved/angled top + flag
- hydrant → body + side caps + top cap
- forklift → body + cabin + wheels + mast + forks
- vending machine → cabinet + display + product area + payment panel + lower slot

## Modeling Workflow

Follow this order:

1. identify the asset's unmistakable silhouette
2. choose 3–8 major forms
3. establish proportions and ground contact
4. assign compact palette
5. add characteristic secondary forms
6. add only a few high-value details
7. check hierarchy, pivot, scale, and forward axis
8. remove unnecessary geometry/materials
9. return a clean standalone asset factory

## Quality Checklist

Before finalizing, verify:

- recognizable at a glance
- matches stylized low-poly/isometric visual language
- silhouette is stronger than surface detail
- no photorealistic texture dependence
- limited coherent palette
- low geometry complexity
- repeated parts reuse helpers/materials where appropriate
- root pivot/orientation are sensible
- ground-standing asset sits at `y = 0`
- no renderer/camera/light/scene setup was added
- output can be imported directly into an existing Three.js project

## Response Behavior

When asked to generate an asset:

1. infer the most characteristic forms from the requested object
2. implement the model directly
3. do not add app boilerplate
4. briefly document model dimensions, forward axis, and important movable groups when relevant
5. if the object has ambiguous appearance, choose a clean representative design consistent with this style instead of blocking on minor clarification

When a reference image is provided, preserve its **visual language**, not necessarily its exact subject matter.
