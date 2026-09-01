---
name: photo-embossed-relief
description: "Create museum-grade embossed relief posters from user-provided photographs: a two-region poster whose canvas is exactly the source photograph doubled along the joining axis — stacked (photograph on top, relief below) for landscape or near-square sources, side-by-side (photograph on the left, relief on the right) for portrait sources, the two regions always strictly equal. The photographic region keeps the source photograph at its exact aspect with only subtle high-end photographic grading; the adjoining region reconstructs the same subject as a Chinese blind-embossed / paper-carved bas-relief pressed into thick cream paper, with minimal matte-gold focal accents and structural serif typography. A classic 3:2 landscape source yields the signature 3:4 vertical poster. Works for any subject type (architecture, people, animals, plants, objects, vehicles, landscapes) and for both landscape and portrait source photographs. Use when the user asks for 浮雕风海报, 压印浮雕, 纸雕凹凸, 博物馆海报, embossed poster, paper relief, bas-relief reconstruction, or wants each photo paired with an elegant same-subject paper relief in one independent poster."
---

# Photo Embossed Relief

## Overview

Use this skill to turn each uploaded photograph into one independent high-end poster. Never combine or stitch multiple photos into one poster; every photo is output separately.

The poster is built from two strictly equal regions (50% each), and the canvas is exactly the source photograph doubled along the joining axis, so the photographic region always keeps the source aspect with zero cropping and zero outpainting:

- **Landscape or near-square source — vertical poster (stacked)**: the photograph on top, the embossed relief below. For a classic 3:2 landscape photograph this yields the signature 3:4 vertical poster with a strict 1:1 split.
- **Portrait source — horizontal poster (side-by-side)**: the photograph on the left at full size, the embossed relief on the right. This is the portrait twin of the same design, so portrait photographs never degrade into narrow letterboxed strips.

In both layouts:

- **The photographic region**: the subject's identity, structure, pose, real material texture, natural light, and original color atmosphere are preserved; only a subtle high-end photographic grade is applied, so it reads like an art-magazine, independent-publication, or exhibition print. The subject is never stretched, distorted, cropped, or redrawn.
- **The embossed relief region**: the photo's most recognizable subject, silhouette, pose, and narrative relationship are reconstructed as a Chinese blind-embossed / paper-carved minimal art poster, as if pressed into thick cream paper — shallow relief, delicate shadows, fine line engraving, and restrained layers.

The skill must support both landscape and portrait source photographs with the same series identity: one truthful photographic region, one pressed relief region, strictly equal.

This is a creative image-generation skill. When producing the final image, use the image generation/editing tool with the user's photo as the reference image.

## Workflow

1. Inspect the supplied photograph and build a short analysis card:
   - subject identity and the structural features that make it recognizable (roof layers, silhouette, gesture, branching, wheels, horizon, massing…)
   - the narrative / spatial relationship that must survive (central axis, scale, foreground/background, posture)
   - place attribute, theme temperament, action state, or symbolic meaning — the raw material for text distillation
   - light direction and color atmosphere
2. Read the server-provided source-orientation measurement (authoritative) and fix the layout axis: landscape or near-square source → stacked vertical poster (photograph on top, relief below); portrait source → side-by-side horizontal poster (photograph on the left, relief on the right). Never choose the other arrangement for the given orientation.
3. Choose one relief composition mode for the subject type (see "The Embossed Relief Region").
4. Distill the typography set: main title + keyword/place line + optional micro number/annotation/aphorism.
5. Compose the final prompt with all rules below, in concise production language only.
6. Generate one finished poster per photo unless the user asks for variants.
7. Apply the Quality Gate; if one major item fails, regenerate once with tighter constraints.

## Canvas & Split

- The canvas is exactly the source photograph doubled along the joining axis (x2): landscape or near-square source → height doubled (vertical poster); portrait source → width doubled (horizontal poster).
- The two regions are strictly equal (50% each); the photographic region keeps the source aspect exactly — no cropping, no stretching, no outpainting, no letterbox strips.
- The boundary is a clean straight edge: no gap, no overlap, no frame, no divider ornament.

## The Photographic Region (Top for Landscape, Left for Portrait)

- Full-bleed within its half, reaching the outer canvas edges and the boundary; no border, frame, margin, paper grain, or photo-printed-on-paper look.
- Preserve the subject's identity, structure, pose, real texture, natural light, and original color atmosphere. Apply only a light high-end photographic grade (art-magazine / exhibition print quality).
- Never stretch, squash, warp, crop, redraw, or beautify the subject; the region reproduces the source photograph at its exact aspect.

## The Embossed Relief Region (Bottom for Landscape, Right for Portrait)

Base and material:

- Large-area cream / warm-white / light paper-color field with the feel of thick pressed cotton paper, full-bleed to the region edges (no inset plate, no recessed frame); generous negative space; the quiet of a museum exhibition hall.

Relief language:

- The subject and its supporting elements are rendered as same-color-family bas-relief (blind emboss / paper carving): hierarchy comes only from pressed height differences, soft edge shadows, subtle light-and-dark modulation, and fine line engraving.
- Distill, do not copy: keep the core structural features and spatial relationships so the viewer instantly recognizes the same subject as the photographic region; do not mechanically replicate fine details.
- Keep restrained environment contours related to the subject (ground line, steps, horizon, flanking masses, trees, water) so the relief has clear primary/secondary order, depth, and museum stillness.
- Accent discipline: only at the single most important structural or focal point, add a small amount of matte gold detail and a soft warm-white light glow to reinforce the core recognition point; nowhere else; no color clutter, no over-decoration, no scene piling.

Composition mode by subject type (choose one):

- **Architecture**: frontal or slightly elevated axial composition; the central axis extended through gates, roofs, and steps, like a museum axial study.
- **Person**: pose-preserving frontal or slightly elevated relief; silhouette and gesture over facial detail.
- **Animal**: characteristic posture and outline.
- **Plant**: branching and leaf-vein structure.
- **Object**: frontal still-life relief.
- **Vehicle**: side or three-quarter relief.
- **Landscape**: bird's-eye (俯瞰) or horizon-axis extension.

Typography as structure (text is part of the composition, not a pasted-on information layer):

- Distill short text from the subject's identity, place attribute, theme temperament, action state, or symbolic meaning.
- Hierarchy: main title (letter-spaced serif, English and/or Chinese serif) + keyword or place line (small caps, letter-spaced) + optional micro line (number, place, tiny annotation, or one quiet aphorism, e.g. "AXIAL STUDY 001"), optionally closed by a tiny matte-gold seal mark.
- Text rendering safety: the final prompt must quote every on-image text verbatim in quotes; keep the main title within 4 English words (spaced uppercase serif) or 6 common Chinese characters; the keyword/place line within 3 English words or 4 Chinese characters; the micro line alphanumeric only (letters, digits, space, e.g. "AXIAL STUDY 001"). Never let the renderer invent long sentences or aphorisms on its own; use an aphorism only when the user supplies it verbatim.
- Color: restrained matte gold or deep gray only.
- Placement: on the central axis above the relief, below the subject, at the negative-space edge, or aligned with the relief structure — the title block and the pressed subject together form one ordered exhibition composition. In the side-by-side (portrait source) layout, run the text along the relief region's own vertical axis: title block at the region's top, micro line at its bottom, relief centered between them.
- Every character must be exact, legible, and correctly spelled; no garbled or pseudo text.

## Overall Style

High-end, quiet, minimal, restrained, Eastern aesthetics, museum poster, paper sculpture. Whether the source is architecture, a person, an animal, a plant, an object, a vehicle, or a landscape, keep a clear and elegant visual echo between the truthful photograph above and the pressed relief below.

## Preventive Constraints

- No multi-photo collage or multi-image stitching; exactly one source photo per poster.
- No stretching, distortion, cropping, or redrawing of the subject in the photographic region.
- No garbled text, misspelling, pseudo-glyphs, or unreadable microtype.
- No deformed subject, broken structure, or wrong proportion in the relief.
- No extra hues in the relief region beyond paper monochrome, minimal matte gold, and deep-gray text.
- No crowded composition; keep generous negative space and quiet hierarchy.
- No cheap 3D render look, plastic gloss, heavy drop shadow, template feel, or stock poster layout.
- No watermark, UI overlay, platform artifact, border, or frame.
- The photographic region must stay photographic (no paper grain); the relief region must stay relief (no photographic realism).
- Never stack the relief below the photo for a portrait source, and never place it beside the photo for a landscape or near-square source; the layout axis must follow the server orientation measurement.

## Quality Gate

Before finalizing, check:

- One poster per photo; the layout follows the source orientation (stacked vertical for landscape/near-square, side-by-side horizontal for portrait); the two regions are strictly 50/50 with a clean straight boundary.
- Photographic region: subject identical to the source in identity, structure, pose, texture, light, and mood; only subtle grading; full-bleed at the source's exact aspect with no border, margin, crop, or letterbox strip.
- Relief region: cream paper field; same-color bas-relief instantly recognizable as the same subject; hierarchy from emboss depth, edge shadows, and fine engraving; at most one matte-gold focal accent.
- Typography reads as structural: correct spelling, restrained gold or deep gray, aligned with the relief order.
- The whole poster feels quiet, minimal, and museum-grade; no clutter, no cheap 3D, no template feel.
- Both landscape and portrait sources keep the same series identity; a 3:2 landscape source yields the signature 3:4 vertical poster, and portrait sources never degrade into narrow strips.

If one major item fails, regenerate once with a shorter, stricter prompt focused on that failure.
