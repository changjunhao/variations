---
name: scenic-postcard-editorial
description: Use when a city or scenery travel photograph must become a minimal editorial postcard poster whose layout follows the source orientation — stacked for landscape sources, side-by-side for portrait sources — the photographic region keeps the original photograph with a quiet cinematic grade, the illustrated region distills its most recognizable elements into a soft gouache illustration with generous ivory negative space and a restrained English serif title.
---

# Scenic Postcard Editorial

Turn one city or scenery photograph into a quiet two-part art poster whose layout follows the source orientation: for a landscape or near-square photo, the real photograph on top with an artistic distillation below; for a portrait photo, the photograph on the left with the distillation on the right — like a page from an independent art magazine, a city travel photobook, a contemporary art book cover, or a museum shop poster.

## Contract

- **Invariants:** the photographic region retains the original photograph and its composition (sky, buildings, main subjects unchanged); the illustrated region is an illustration distilled from the photo, never a pixel replica; layout follows source orientation — stacked for landscape or near-square sources, side-by-side for portrait sources; overall soft, restrained, quiet; generous ivory negative space.
- **Defaults:** warm ivory / muted navy / blue-grey palette; soft gouache dry-brush texture; one auto-generated English title plus short subtitle in editorial serif; left-aligned typography with breathing room.
- **Overrides:** accept palette, texture, title, and layout adjustments from the instruction. Reject cartoon, cyberpunk, 3D, vector-icon looks, heavy HDR, strong sharpening, or an AI-repaint feel on the photographic region.

## Workflow

1. Analyze the supplied photograph: identify the most recognizable elements (skyline, landmark silhouettes, horizon layers, foreground subjects) and the dominant natural colors.
2. Decide the distillation: which elements become geometric color blocks in the illustrated region, how distance compresses into thin rectangular silhouettes, what stays as ivory negative space.
3. Create one original English title (two to five words) and one short subtitle (three to seven words) grounded in the place's light, mood, or spatial character. Avoid generic travel-advertising words and literal place-name labels unless the instruction asks for them.
4. Compile the final image-generation prompt as one precise description of the finished poster, following [references/style-system.md](references/style-system.md):
   - choose the arrangement by source orientation — landscape or near-square source: two-part composition divided top and bottom; portrait source (aspect at most 0.8): two-part composition divided left and right. The two regions are equal in size — the canvas is exactly the photograph doubled along the joining axis;
   - photographic region: the original photograph kept intact — same composition, sky, buildings and main subjects, only a slight cinematic color grade: lowered saturation, soft restrained quiet tone of blue-grey, warm yellow, and ivory, real photographic texture preserved; no HDR, no strong sharpening, no AI-repaint look;
   - illustrated region: a minimal editorial illustration distilled from the photo — buildings simplified into geometric color blocks, distant views compressed into thin rectangular silhouettes; soft gouache, dry-brush texture, watercolor-like opacity, subtle paper grain, matte printed finish; no visible outlines, flat matte color; generous warm-ivory negative space, sparse balanced poetic layout;
   - typography in the illustrated region: the exact English title in an elegant classic serif, dark blue-grey, left-aligned; the subtitle in fine editorial italic serif, clearly smaller; restrained sizes with breathing room, kept away from the motif and canvas edges;
   - whole-image style: minimal editorial poster, poetic city illustration, contemporary art book aesthetic, Scandinavian minimalism, Japanese editorial design, quiet luxury poster, refined print design, low saturation.
5. End the prompt with an exclusion list: no cartoon, no cyberpunk, no 3D, no vector-icon look, no obvious outlines, no heavy HDR, no strong sharpening, no AI-repaint feel in the photographic region, no extra words, numbers, logos, or watermarks, no dense decoration, no redrawing of the photograph's subjects in the photographic region. For a portrait source, no vertical stacking of the photo above the illustration on a tall canvas; for a landscape source, no side-by-side arrangement.

## Common mistakes

- Redrawing the photograph in the photographic region — keep it photographic, only graded.
- Pixel-replicating the photo in the illustrated region — it is a distillation, geometric and sparse.
- Filling the illustrated region — ivory negative space must dominate.
- Outlined, cartoonish, or glossy illustration — it must read as matte gouache on paper.
- Titles that sound like travel advertising or that simply repeat the place name.
- Stacking a portrait source into a tall skinny poster — portrait photographs belong on the left of a wide side-by-side composition.
