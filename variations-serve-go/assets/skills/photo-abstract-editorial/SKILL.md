---
name: photo-abstract-editorial
description: Use when one photograph must become a photo-plus-abstraction editorial poster whose layout follows the source orientation — stacked for landscape sources, side-by-side for portrait sources — the photographic region rendered faithful to the source, joined to a flat warm-ivory panel carrying one sparse abstract motif derived from the photo and one short English serif title.
---

# Photo Abstract Editorial

Turn one photograph into a single editorial composition whose layout follows the source orientation: for a landscape or near-square photo, the photo rendered faithful to the source on top with a flat warm-ivory panel below; for a portrait photo, the photo on the left with the panel to its right. The panel carries one sparse abstract motif distilled from the photo and one short English serif title.

This is a prompt-only adaptation of a deterministic-compositing workflow: describe the complete composition precisely enough that the image model renders the photo region, panel, motif, and title in one pass.

## Contract

- **Invariants:** one readable photograph faithful to the source; full source retained by default; one abstract motif traceable to visible source facts; one English title; flat uniform panel.
- **Defaults:** shortened warm-ivory panel (#E8E1D5), lower-left motif placement, muted ink palette drawn from the source, one English title of two to five words, no subtitle, high-contrast serif typography.
- **Overrides:** accept panel, motif, text, alignment, and font choices from the instruction. Reject redrawing the photo into a different scene or inventing unrelated content.

## Workflow

1. Analyze the supplied photograph as the sole factual source, working through DECONSTRUCT → SELECTIVE PRESERVATION → ABSTRACT / DISTILL → RECONSTRUCT. Identify three to six decisive facts from [references/art-direction.md](references/art-direction.md): relative scale and position, horizontal/vertical axes, movement and pauses, intervals and asymmetry, light/dark hierarchy, color roles, negative space.
2. Choose one primary mark family and at most two supporting families for the motif, mapped conservatively from those facts (landscapes as bands plus one dark structural line; landmark architecture as one to three identity cues; people as single short vertical marks; etc., per the art direction).
3. Create one original English title of two to five words grounded in visible subject, light, time, motion, or spatial relationships, using one naming direction from the art direction (light entering a space, a dialogue between two subjects, a brief appearing or pausing, a metaphor from color or axis, an original compound word). Avoid travel advertising, literal place descriptions, photography jargon, and generic words like Memory, Dream, or Moment. Decide one final title internally; never render candidate lists.
4. Compile the final image-generation prompt as one precise description of the finished composition:
   - choose the arrangement by source orientation — landscape or near-square source: the full photograph on top with the panel stacked below; portrait source (aspect at most 0.8): the full photograph on the left with the panel to its right. The panel always matches the rendered photograph in size, so the canvas is exactly the photograph doubled along the joining axis. In both arrangements the photograph is rendered faithful to the source — same subject, framing, colors, and atmosphere, no redrawn scene, no crop, no filter, no outpainting;
   - joined directly to the photograph — beneath it for stacked layouts, to its right for side-by-side layouts — one flat uniform warm-ivory panel (#E8E1D5) with no gradient, shadow, grain, paper texture, vignette, seam, or any artifact;
   - on the panel, the sparse flat abstract motif: one dominant mark family, two to four marks total, matte flat color, no gradient or volume, sized per the art direction (about 30%–42% of panel width, generous clean whitespace); colors extracted from the photograph and reduced in saturation — one dominant role, one dark structural role, one light/neutral role, at most one or two small accents;
   - the exact title text in a high-contrast editorial serif face (Bodoni preferred, Baskerville or Garamond acceptable), dark photo-derived color, natural whole-word kerning, lower-left or bottom-center placement with optical margins; optionally one short connector word smaller in the matching italic;
   - negative space dominates: the panel keeps generous empty area; motif low on the panel; title never touches the motif or the canvas edge.
5. End the prompt with an exclusion list: no extra words, letters inside the motif, numbers, dates, place labels, color swatches, legends, signatures, logos, watermarks, frames, tape, torn edges, mockup or collage effects, dense decoration, or non-uniform panel texture. For a portrait source, no vertical stacking of the photo above the panel on a tall canvas; for a landscape source, no side-by-side arrangement.

## Common mistakes

- Turning the photo into an illustration or redrawing its content — the photographic region must stay faithful to the source.
- A miniature trace is not abstraction; the motif should read first as a sparse composition and only later recall the photograph.
- Uniform per-character tracking and mathematically equal margins look rigid; use native whole-word shaping and optical offsets.
- Equal-height vertical marks look diagrammatic; use one primary and one subordinate anchor only when the source supports it.
- Adding texture, grain, or lighting to the panel — it must stay flat and uniform.
- More than one title line, or invented subtitles that add no new idea.
- Stacking a portrait source into a tall skinny poster — portrait photographs belong on the left of a wide side-by-side composition.
