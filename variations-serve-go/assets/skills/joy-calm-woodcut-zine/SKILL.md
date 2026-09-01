---
name: joy-calm-woodcut-zine
description: Transform one user-provided photograph into a calm contemporary Japanese/Korean indie-zine woodcut poster on a fixed portrait 3:5 canvas — the whole scene is reinterpreted as an integrated relief print on luminous fibrous paper: one dominant structural silhouette in firm saturated chromatic dark (deep green, mineral blue, never dominant black), two to four flat colored inks, selective directional carving in three density zones, 35%-55% genuinely untouched paper, edges dissolving into the paper, tiny subordinate typewriter microtype, and an unhurried calm tempo. Use for poetic editorial posters, photo-to-print transformations, emotional travel imagery, or requests for bright, misty, distant, nostalgic, or semi-abstract woodcut visuals.
---

# Calm Integrated Woodcut Zine Poster

Compile one final image-generation prompt that turns the user-provided photograph into a calm integrated woodcut zine poster on a fixed portrait 3:5 canvas. The photograph is a CONTENT source only: it supplies subject identity, essential gesture, and three to five recognizable cues; it does not supply camera framing, perspective, scale, depth, or object count. The whole scene must read as a contemporary editorial relief print built directly on luminous paper — not as a photograph, not as a sticker, not as a traditional woodblock print.

## Contract

- **Canvas:** a fixed portrait 3:5 poster (server size string `960*1600`), flat and front-facing, for every source orientation. The paper IS the canvas: the fibrous paper field fills the entire 3:5 frame edge-to-edge; never a photograph of a physical paper sheet, no deckled sheet edges, no drop shadow, no gray background surface, no paper-within-paper inset rectangle. The source orientation (server-provided, authoritative) controls only how the scene is compressed into the tall format, never the canvas.
- **Full reinterpretation:** no region of the poster preserves the original photograph. Preserve three to five identity anchors; rebuild everything else as carved planes, ink blocks, rhythmic marks, and exposed paper.
- **Style lock:** the Canonical Style Lock below is authoritative for paper, print construction, hierarchy, negative space, palette behavior, edge dissolution, typography scale, and emotional tempo. The content source is authoritative only for what must remain recognizable. Never import objects, words, or layout from the style lock's example scene.
- **Output:** one compiled prompt describing one raster poster. No multi-pass editing, no alternate variants.
- **Text:** every word on the poster must appear on the explicit allowlist; when the user supplies no copy, invent one short poetic phrase or choose textless.
- **Overrides:** accept the instruction axes 氛围偏好 (an explicit atmosphere route) and 海报文案 (exact short wording, placed verbatim on the allowlist). Reject added text, logos, and calls to action.

## Canonical Style Lock

Translate this anchor grammar to the new subject; never copy the anchor's bridge, bus, boats, buildings, words, or layout:

- Luminous fibrous paper: soft white, rice paper, pale oat, or cool ivory with carved fibers and faint block-print grain; never brown kraft, parchment, leather, or scorched edges; never a flat digital pale fill without visible fibers.
- One dominant structural silhouette (ridge, valley wall, shore curve, arch, roofline, facade band, or grouped gesture) occupying roughly 18%-35% of the page, printed in a firm saturated chromatic dark — deep green, mineral blue, blue-gray, or violet-blue; near-black only as tiny accents; never dominant black.
- One small saturated warm or contrasting accent, only as a recognizable object that exists in the source scene (a figure in colored clothing, a vehicle, a lantern, a buoy, a roof); never as an abstract colored rectangle, signboard, banner, or blob. When the source offers no suitable object, omit the accent entirely.
- Pale but still legible atmospheric distance: a clearly visible secondary colored ink for the middle layer; sparse broken marks and exposed paper for the far layer.
- Slow horizontal or form-following rhythmic marks for water, terrain, and foliage; dense short carving only at focal ridges, shadow turns, and structural joints.
- Edges dissolve: contours stop early, taper, or continue as independent marks; no sticker boundary, no white contour, no carved frame, no dark corner foliage. The scene cluster must not terminate in straight vertical left/right edges like a pasted rectangular print; its side edges taper into paper (trees thinning out, contours stopping early, field marks breaking off), and no white halo or outline may surround the dominant form.
- Tiny subordinate typewriter or serif microtype, clearly smaller than the principal structure.
- Calm tempo: stable spacing, gentle asymmetry, unhurried hierarchy; brightness expressed as serene joy, clarity, or spacious optimism — never excitement, speed, or impact.

## Orientation Branching (server-authoritative)

The canvas is always the fixed portrait 3:5. Use the server-provided orientation note (【服务端测定】) only to choose the compression strategy:

- **Portrait or square source:** keep the natural verticality; choose one dominant vertical structure (ridge, tower, street band, figure group) and stack at most three depth layers.
- **Landscape source:** do not letterbox the wide view. Select one vertical slice or one dominant vertical structure from the scene; compress the horizontal expanse into at most three stacked depth bands (air, dominant structure, water or ground rhythm); translate left-right sequences into rhythmic marks instead of a panoramic tracing.
- Both cases: compress depth to at most three visibly different layers, flatten perspective, and delete most intermediate objects.

## Calm Tempo Invariant

This overrides scene, color, and composition choices: no urgent diagonals, aggressive convergence, rapid zigzags, motion streaks, impact bursts, frantic scatter, or harsh contrast jumps. Depict traffic, wind, waves, crowds, and urban density through restrained rhythm and selective cues. Dense short carving may deepen tone but must stay slow, interrupted, and locally grouped.

## Scene and Emotion Router

Choose one primary atmosphere — the instruction's 氛围偏好 when supplied — and its palette:

- **Bright day:** luminous cyan, sky blue, lemon yellow, fresh green, tangerine, or warm pink; two to four vivid inks; crisp relief boundaries and buoyant spacing.
- **Mountain / high:** glacial cyan, cobalt, mineral blue, ice white, silver gray, with one clean warm counterpoint; ridges as cut-paper planes, contour bands, and geometric altitude marks.
- **Sunset / evening:** persimmon, apricot, dusty coral, plum, twilight blue, or amber; overlapping transparent inks; long shadows as flat shapes; memory fragments or fading silhouettes.
- **Fog / mist / rain:** cool white, pale cyan, blue gray, muted violet, with one isolated saturated accent; forms dissolving into incomplete contours; sparse or partially obscured typography.
- **Seaside / water:** water as carved wave lines, cyan print fields, repeated bands, or abstract current shapes; boats, rods, and figures as rhythmic marks, not documentary detail.
- **City / architecture:** buildings as carved silhouettes, window grids, clocks, signs reduced to a few cues, street ribbons, or stacked print blocks; retain breathing room.
- **People / intimate:** preserve pose, gesture, distance, and relationship before facial detail; paired silhouettes and simplified clothing color fields; no beautification or synthetic facial reconstruction.

## Abstraction Discipline (default A2.5)

- Identify three to five non-negotiable anchors (silhouette, arch, roof color, horizon, boat profile, gesture). Preserve those; simplify the rest.
- Rebuild at least one substantial region (30%-50% of the main visual cluster) as non-photographic structure: contour bands, exposed-paper voids, repeated structural marks, or compressed depth bands. A small detached fragment does not satisfy abstraction.
- Merge or remove secondary trees, windows, vehicles, rocks, branches, clouds, signs, and street furniture. Reduce logos, hotel names, and shop signs to a few anonymous cues unless exact text is requested.
- Keep abstraction quiet and spatial: no cubist shattering, random geometry, frantic collage, or surreal object substitution.

## Selective Relief Hierarchy

- The main subject must contain clearly legible relief-cut lines at normal viewing size: contour cuts, directional hatching, parallel gouges, broken cross-cuts, or short pressure-varied strokes. Paper grain, halftone dots, duotone, distressed ink, and photographic noise do not count as carved linework.
- Keep three visible texture zones: open paper or quiet ink; medium directional hatching that explains form; dense short cuts and compact crosshatching at focal ridges, shadow turns, structural joints, and dark accents. All three must remain visible at thumbnail scale.
- Line direction follows form: cuts wrap mountain planes, run horizontally with calm water, climb architectural edges, branch through foliage, compress around shadow. Assign each depth layer a different mark density.
- Give cuts physical weight: irregular pressure, tapered or broken ends, compact clusters, small unprinted gaps. Avoid both hairline-only etching and blunt stamp-like photo filtering.

## Composition and Space

- Keep roughly 35%-55% of the page as genuinely untouched paper, including one coherent quiet area. Keep dense dark ink below roughly 15%-25% of the page — an area limit, not an opacity limit: localized ink prints at firm saturation.
- Keep the dominant printed structure around 18%-35% of the page and total printed information around 45%-65%.
- Choose one functional layout and name it in the prompt:
  - **dominant arch or ridge:** one structural curve organizes smaller scene rhythms beneath or around it;
  - **open relief field:** the scene prints directly on paper and dissolves at the outer edges;
  - **high horizon:** small subject low on the page with expansive upper air;
  - **vertical ascent:** stacked ridge, tower, tree, or figure shapes emphasizing height;
  - **two depth bands:** two compressed horizontal bands with transparent ink overlap (flat printed bands, not torn paper strips, not stickers);
  - **dissolving field:** the subject transitions into carved lines, mist, dots, or incomplete contours.
- No enclosing border, carved frame, dark perimeter, or filled corners. Keep elements away from extreme edges unless a structural contour needs to enter or leave the page.
- Keep the printed cluster inset: untouched paper must remain visible along at least the left and right sides of the scene cluster (ideally three sides). Stacked full-width bands running edge-to-edge read as a full-bleed landscape print and are rejected; compress the scene into one inset cluster with a single dominant silhouette instead.

## Color System

- Require a usable value ladder: paper white; one clearly visible light or middle colored ink; one firm chromatic dark; and, when the scene supports it, one small saturated accent.
- Separate coverage from strength: lightness comes from untouched paper, never from lowering the opacity of every ink. A pale beige-gray or low-opacity monochrome is a failure even when the spacing is calm.
- Favor flat printed color, transparent overprint, and paper showing through. Avoid photographic gradients, generic pastel washes, neon glow, and rainbow palettes.
- At thumbnail scale the dominant form must separate immediately from the paper; if subject, middle layer, and paper merge into one pale value, increase ink saturation and local contrast without increasing dark coverage.

## Typography and Text Rendering Safety

- Build an allowed in-image text list. User-supplied exact copy (海报文案) enters verbatim. Otherwise invent one non-factual poetic phrase of at most four English words (or at most six common Chinese characters), or choose textless. A second microtext line is allowed only when the user supplies it verbatim; never invent dates, numbers, or coordinates.
- The final prompt must quote every in-image text verbatim inside quotation marks and state: render only this allowed text; no other words, letters, numerals, signs, logos, or watermarks. When the list is empty, state completely textless.
- All typography stays subordinate: the main phrase fits within roughly 8%-20% of the visual cluster's width and remains clearly smaller than the principal structural form. Use restrained typewriter, serif, rounded grotesk, or monospaced type.
- Never invent dates, four-digit years, locations, venues, or brand names.

## Prompt Compiler

Write the final prompt as four compact paragraphs:

1. Style lock and canvas: a fixed portrait 3:5 contemporary editorial zine poster whose fibrous paper fills the entire canvas edge-to-edge (no photographed paper sheet, no deckled edges, no drop shadow, no background surface, no inset rectangle); the source photo is the CONTENT REFERENCE and supplies only subject identity, essential gesture, and three to five recognizable cues — it does not control camera framing, perspective, scale, depth, object count, or photographic composition; the Canonical Style Lock is authoritative for rendering. Explicitly: no large sticker, no white contour enclosing the scene, no floating photo-shaped container, no full-scene photographic tracing, no black-and-cream linocut, no carved border, no full-page dense engraving, no brown kraft paper, no rectangular scene block with straight left/right edges, no uniform paper frame around a rectangular print, no white halo or outline around the dominant form.
2. Anchors and rebuild: name the three to five recognizable anchors; one simplified dominant silhouette; depth compressed to at most three graphic layers; which secondary details must disappear; which substantial region becomes exposed-paper voids, contour bands, or sparse carved marks; the orientation compression strategy per the server note; the scene cluster inset with untouched paper margins on the left and right sides, never stacked full-width edge-to-edge bands.
3. Palette, carving, typography: the exact inks of the chosen atmosphere route; the chromatic dark printed at firm saturation (the 15%-25% figure controls area, not ink strength); the three-zone relief hierarchy with form-following line directions; the complete allowed in-image text quoted verbatim, or completely textless; tiny subordinate type.
4. Mood, flat scanned-paper finish, calm tempo, and the rejection list: no antique engraving, no vintage-book illustration, no uniformly etched scenery, no halftone or duotone or photographic grain substituting for carving, no washed-out pale monochrome, no kinetic effects, no logos or calls to action.

Make every instruction renderable pixels; no checklist meta-language, no file paths, no design-analysis prose.

## Common Mistakes

- The photo survives as an untreated rectangle, a large closed sticker, a white-bordered blob, or a kiss-cut silhouette — the scene must print directly on paper and dissolve at the edges.
- A rectangular scene block with hard straight left/right edges framed by a uniform paper margin, like a pasted print — the cluster's side edges must taper and dissolve into paper.
- A photographed physical paper sheet with deckled edges, drop shadow, or a gray background surface — the fibrous paper must be the canvas itself, full-bleed to the frame.
- A white halo, glow, or kiss-cut outline separating the dominant form from the background.
- A traditional black-and-cream full-page linocut or souvenir woodblock with carved border, dense dark perimeter, and filled corners.
- One uniform engraved, halftone, duotone, or posterized filter over the photo instead of selective directional carving.
- Every ink layer pale, gray, beige-shifted, or translucent — calm means spatially restrained, not washed out.
- The apparent negative space is actually pale etched scenery rather than untouched paper.
- The dominant form fills more than about 40% of the page with continuous photographic detail.
- A perspective-faithful panoramic tracing of a landscape source squeezed onto the tall canvas.
- Stacked full-width bands (mountain band + tree band + field band) running edge-to-edge and filling most of the page — the cluster must stay inset with side paper margins and one dominant silhouette.
- An unexplained colored rectangle, signboard, banner, or blob standing in for the accent — the accent must be a recognizable scene object, or omitted.
- Headline-scale typography, invented years or dates, exhaustive sign transcription.
- Kinetic effects: speed lines, starbursts, urgent diagonals, motion streaks, impact graphics.

## Final Self-Check

Before returning the compiled prompt, verify:

- Is the canvas stated as the fixed portrait 3:5 (960*1600), flat and front-facing, with the compression strategy matching the server-reported orientation?
- Are three to five identity anchors named, and is one substantial region explicitly rebuilt as non-photographic structure?
- Is the chromatic dark named (deep green, mineral blue, blue-gray, or violet-blue), firm and saturated, with black not dominant?
- Are untouched paper 35%-55% and dense dark ink 15%-25% both stated as area figures with the ink-strength caveat?
- Are the three carving density zones and form-following line directions specified, with different mark density per depth layer?
- Do edges dissolve with no sticker boundary, carved frame, or dark perimeter?
- Is all in-image text on the allowlist, quoted verbatim, at most four English words for the main phrase, and subordinate in scale — or explicitly textless?
- Does the atmosphere route match the source's weather, light, and activity, or the instruction's 氛围偏好?
- Is the calm tempo preserved: no kinetic effects, no urgent diagonals, no competing focal points?
- Would the woodcut character remain obvious if paper grain, halftone dots, and photographic noise were removed?
- Will the poster read at thumbnail scale: dominant form separated from paper, three texture zones visible?

## Privacy

Do not expose full legal names, personal email addresses, phone numbers, student IDs, residential addresses, credentials, API keys, tokens, passwords, private computer paths, private file names, or EXIF GPS information.

Do not place personal information in titles, metadata, file names, prompts, documentation, or examples unless the user explicitly requests it.
