---
name: photo-relic-editorial
description: "Create distinctive Photo Relic editorial artworks from user-provided photographs: a two-part artwork whose layout follows the source orientation — stacked for landscape or near-square sources, side-by-side for portrait sources — the photographic region keeps the supplied photograph pixel-truthful and full-bleed, and the adjoining paper panel carries a recognizable, artful abstract relic shaped like memory, modern printmaking, quiet Eastern restraint, and source-derived light. Use when the user asks to turn a photo into minimal art, photographic relic posters, abstract editorial photography, gallery-like photo posters, art series covers, graphic photo abstraction, afterimage compositions, or similar visual treatments while keeping the original photograph truthful."
---

# Photo Relic Editorial

## Overview

Use this skill to transform a user-provided photograph into a two-part editorial artwork with a consistent signature: one region is the supplied photograph kept pixel-truthful and full-bleed; the adjoining region is a "Photo Relic" panel on warm paper. The layout follows the source orientation — for a landscape or near-square photo, photograph on top and relic panel below; for a portrait photo, photograph on the left and relic panel on the right. The two regions are equal in size: the canvas is exactly the photograph doubled along the joining axis. The relic is not a literal illustration, decorative poster, or vague haze. It is a compressed visual memory of the photograph: a few precise marks that preserve the subject's identity, light, weight, and emotional temperature.

The aesthetic should feel like real photography meeting a modern paper print: quiet, restrained, source-derived, recognizable, and artful enough to become a repeatable visual series.

This is a creative image-generation skill. When producing the final image, use the image generation/editing tool with the user's photo as the reference image.

## Workflow

1. Inspect the supplied photograph before writing the generation prompt.
2. Identify 3-5 source cues from the real image:
   - the main subject identity and the full relationship that makes it recognizable
   - the photo's emotional core, reduced to a short concept such as "held dusk", "falling sky", "quiet order", "wet neon", or "alone in the plaza"
   - dominant colors plus one possible signature accent: vermilion, small gold, dusk orange, or a source-specific warm light
   - strongest light or shadow direction, including large cold/warm areas
   - key structural cues: roof layers, towers, arches, windows, paths, stairs, horizon, ground, water, people scale, or silhouettes
3. Fix the layout from the source orientation — landscape or near-square source: photographic region on top, relic panel below; portrait source: photographic region on the left, relic panel on the right. Never choose the other arrangement for the given orientation. Then choose a compact Photo Relic recipe before prompting:
   - relic placement
   - relic grammar
   - mark weight
   - title mode
   - motion seed when useful for social-video follow-up
4. Read `references/afterimage-editorial-prompt.md` before composing the final image prompt.
5. Ask for the missing photo only if no usable source image is available.
6. Generate one finished artwork unless the user asks for variants.
7. Use the Quality Gate before finalizing. If the result clearly fails one major gate, regenerate once with tighter constraints.

## Signature Aesthetic

Make the result feel like this:

Real photograph on one side. Memory print on the other. The relic should look as if time pressed the photo into a few ink marks on warm paper.

Use these signature traits consistently:

- Preserve the photographic region as truth — pixel-faithful, full-bleed, uncropped, with no border, frame, margin, or photo-print-on-paper look. The user's photography is the root of the work.
- Use a warm ivory, off-white, or very quiet source-light panel for the relic area.
- Build the relic from deep blue, ink black, gray-green, stone gray, muted teal, and one small warm accent when the source supports it.
- Use one primary form plus a few support marks. Do not fill the panel.
- Make the relic recognizable at thumbnail size, but not literal enough to become a normal illustration.
- Let marks feel like modern printmaking: flat ink blocks, softened edges, small breaks, negative-space cuts, and measured irregularity.
- Keep titles small, poetic, and label-like. The image should not read as an advertisement.
- Favor a stable series identity over one-off novelty.

## Creative Rules

- Preserve the photograph's content and truth. Do not redraw, beautify, repaint, expand, hallucinate, or stylize the original photographic area.
- Let the relic come from the photo. Use its real colors, light logic, negative space, edges, subject placement, and spatial tension.
- Always create one clear primary relic shape. The viewer should sense the whole subject relationship through the simplified form.
- Keep the relic complete enough to preserve the photo's main identity. For architecture, include roof/mass, base, entrance or path, ground/horizon, and scale marks when they matter.
- Translate details into marks, not decorations: roof layers become stacked arcs; windows become sparse cuts or tiny dots; people become short vertical ticks; water becomes one or two horizontal residues; dusk becomes one small warm signal.
- Use atmosphere only as support. Light may hold the relic, but it must not replace the form.
- Prefer quiet precision over ornament. Use breathing room, one primary motif, a few supporting marks, and restrained title treatment.
- Keep the family resemblance to minimal editorial photo art, but avoid copying any specific external skill's text, layout formula, examples, or named style.
- Avoid loud gradients, commercial-poster hierarchy, heavy watercolor, fake vintage texture, stickers, collage clutter, UI overlays, platform watermarks, and decorative geometry unrelated to the photo.

## Composition Patterns

Choose one pattern based on the photograph. Do not output a panel made only of fields, lines, or swatches; the relic must have a central motif and enough surrounding structure to carry the whole photograph.

- **Paper Relic**: Use a clean ivory/off-white paper panel. Place a small-to-medium source-derived relic in the panel's center, with generous blank space and one title.
- **Light-Pressed Relic**: Use a very restrained cold/warm light field sampled from the photo, then press a clear ink-like subject shape into it.
- **Architectural Seal**: Reduce a building or skyline into blocks, arcs, voids, base lines, and a small warm accent. Keep identity strong and ornament low.
- **Horizon Memory**: For cities, water, roads, or open landscapes, anchor the relic with one calm horizon/base mark so the form does not float.
- **Human Scale Echo**: If people matter, reduce them to small irregular vertical marks that show scale and atmosphere. Do not draw faces, limbs, or clothing detail.
- **Motion Cover Seed**: When the user wants Douyin or social-video potential, compose the still image so it can animate: photo holds, subject outline descends, relic marks assemble, title appears last.

## Recipe Selection

Pick one option from each axis before writing the image prompt. Vary the recipe when recent outputs look too similar, but keep the series identity stable.

Relic placement (inside the paper panel):

- **centered-field**: relic centered with generous blank space around it; default.
- **deep-space**: smaller relic, larger quiet field; use when the relic needs air.
- **axis-aligned**: relic aligned to the photograph's central axis; use for symmetrical architecture.
- **horizon-anchored**: relic anchored by a calm horizon/base mark near the panel's outer edge; use for cities, water, plazas, roads, and skylines.

Relic grammar:

- **ink-seal architecture**: deep block shapes, negative-space cuts, and one accent.
- **stacked-order**: arcs, bands, steps, or floors reduced into calm layers.
- **skyline-memory**: landmark plus supporting bars, horizon, sparse light marks.
- **light-relic**: subject silhouette pressed into a subdued light field.
- **edge-remnant**: a few decisive edges cluster into one recognizable motif.

Mark weight:

- **quiet ink**: medium-dark marks with softened edges; default.
- **graphic ink**: bolder flat blocks when the subject needs stronger recognition.
- **thin trace**: fine lines for cranes, railings, paths, water, or delicate edges.
- **single accent**: one warm point or short bar only, used like a signature.

Title mode:

- **small English title**: safe default for an editorial series.
- **small Chinese title**: use when the user asks for Chinese feeling or social-video resonance.
- **textless**: use when the relic is strong enough.
- **micro bilingual**: use only when explicitly requested.

Motion seed:

- **outline descent**: subject outline separates from the photo and settles into the relic panel.
- **ink assembly**: relic marks appear one by one from largest form to smallest accent.
- **light fade**: photo light fades into the lower paper field before the relic appears.
- **still only**: default unless the user asks about Douyin/video.

## Output Prompting

When invoking the image tool, include:

- the photographic region reproduces the supplied photograph exactly — pixel-truthful, full-bleed, uncropped, no border, frame, margin, or photo-print-on-paper look
- the layout follows the source orientation — stacked (photo on top, relic panel below) for landscape or near-square sources; side-by-side (photo on the left, relic panel on the right) for portrait sources; the two regions are equal in size
- one recognizable primary Photo Relic derived only from the source photo
- a warm paper or restrained source-light panel that supports the relic without competing with it
- modern printmaking language: flat ink blocks, soft edges, negative-space cuts, sparse lines, and one small source-derived accent when useful
- restrained typography, usually one very small title only
- exact prohibitions against rewriting, replacing, beautifying, or inventing content in the photo

End the prompt with orientation-specific exclusions: for a portrait source, no vertical stacking of the photo above the relic on a tall canvas; for a landscape or near-square source, no side-by-side arrangement. In every orientation, forbid any border, frame, or white margin around the photographic region.

Do not mention internal analysis in the final prompt. Translate the visual decision into concise production language.

## Quality Gate

Before finalizing, check the generated result:

- The photographic region matches the supplied photograph exactly — full-bleed, uncropped, unredrawn, no border, frame, or margin.
- The layout matches the source orientation: stacked for landscape or near-square, side-by-side for portrait.
- The relic is recognizable at thumbnail size.
- The relic preserves the full subject relationship, not only a decorative fragment.
- The relic panel feels like a memory print, not a normal illustration, infographic, or generic poster.
- The marks are few, deliberate, and source-derived.
- There is a stable series signature: warm paper, deep ink, one possible accent, generous blank space, quiet title.
- The result has enough artistic strangeness to feel memorable, but enough clarity to be shared quickly on mobile.
- Typography is absent or very small; it does not become the main visual.
- The palette clearly comes from the source photo.
- There are no UI overlays, watermarks, social media artifacts, fake film borders, stickers, or unrelated decorations.

If one major item fails, regenerate once with a shorter, stricter prompt focused on that failure.
