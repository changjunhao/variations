---
name: photo-visual-anatomy
description: "Create visual anatomy study boards from user-provided photographs in the style of an architecture studio's analysis sheet: a fixed portrait 4:5 warm-ivory paper poster with a serif VISUAL ANATOMY masthead at the top left, the source photograph centered as a photographic field whose rectangular edges dissolve into watercolor washes, dry-brush strokes and splatter of its own colors, one large flat accent shape and one diagonal brush stroke behind it, and 5-7 floating abstract study fragments (watercolor washes, color swatch bars, fine line-drawing sketches, organic silhouette blobs, material patches, halftone geometry, light discs) each paired with a tiny uppercase hairline-leader annotation label, plus a left-edge palette dot column and sparse drafting marks. Extracts the soul of the image — shapes, colors, textures, materials, emotions, spatial relationships, symbolic characteristics — not literal object cutouts. Use when the user asks for 视觉解剖, 视觉元素拆解, 分析板海报, 建筑事务所分析图, visual anatomy, design study board, architectural analysis poster, or wants a photo decomposed into floating abstract studies with annotation labels on cream paper."
---

# Visual Anatomy

## Overview

Use this skill to turn each uploaded photograph into one independent visual anatomy study board. Never combine multiple photos into one poster; every photo is output separately.

The poster reads like an architecture studio's analysis sheet printed on warm ivory paper: the photograph sits centered as the specimen, and around it float abstract artistic interpretations of its visual DNA — shapes, colors, textures, materials, emotions, spatial relationships, symbolic characteristics — each pinned down by a tiny annotation label with a hairline leader line.

The canvas is a fixed portrait 4:5 board (server size string `1024*1280`) for every source orientation. The source orientation (server-provided, authoritative) only controls the geometry of the central photographic field.

This is a creative image-generation skill. When producing the final image, use the image generation/editing tool with the user's photo as the reference image.

## Workflow

1. Inspect the supplied photograph and build a short analysis card:
   - subject identity and what makes it recognizable (silhouette, gesture, structure, horizon)
   - visual DNA: dominant shapes, color families, textures, materials, emotional tone, spatial rhythm, symbolic reading — the raw material for the floating fragments
   - palette extraction: exactly 5 colors ordered dark to light (one dominant accent + four support colors)
   - light direction and atmosphere
2. Read the server-provided source-orientation measurement (authoritative) and fix the central field geometry (see "The Central Photographic Field"). Never guess orientation.
3. Distill the typography set: masthead title (default "VISUAL ANATOMY"), subtitle nouns (three), and 6-8 annotation pairs (title + sub) derived from the visual DNA, e.g. "DYNAMIC ARC / FLOW & DIRECTION", "COLOR HARMONY / MEDITERRANEAN VIBES", "MATERIAL MEMORY / TIME & STONE".
4. Compose the final prompt with all rules below, quoting every on-image text verbatim.
5. Generate one finished board per photo unless the user asks for variants.
6. Apply the Quality Gate; if one major item fails, regenerate once with tighter constraints.

## Canvas & Paper

- Fixed portrait 4:5 canvas, full-bleed warm ivory / cream paper field (near #EDE8DD) with a fine paper grain; no border, no inset plate, no recessed frame, no margin rule, no white edge.
- Overall mood: quiet, editorial, hand-crafted, museum analysis board; never a stock infographic, never a product showcase.

## Masthead (Top Left)

- Two-line large high-contrast serif display capitals in deep ink (near-black or deep navy), e.g. "VISUAL / ANATOMY"; left margin about 7% of canvas width, top about 6% of canvas height.
- Below the title: one short hairline rule, then a small letter-spaced sans-serif uppercase subtitle in the form "A DESIGN STUDY OF X, Y AND Z" where X, Y, Z are three distilled nouns from the analysis card (e.g. "MOTION, STRENGTH AND BALANCE", "SPACE, COLOR AND ATMOSPHERE"); the subtitle wraps to at most three short lines.
- If the user supplies a masthead title, use it verbatim (uppercase serif, at most 4 words, split over two lines); otherwise use "VISUAL ANATOMY".

## The Central Photographic Field

- The source photograph is placed centered as the dominant element. Inside the field the image stays fully photographic: subject identity, pose, structure, real textures, natural light and original color atmosphere preserved, with at most a subtle high-end grade. Never stretch, squash, warp or redraw the subject. The interior keeps true photographic realism — natural camera texture; no oil-paint filter, no painterly or illustrated redraw.
- The field has NO hard rectangle: each edge dissolves in a different hand-crafted way — one edge melts into a soft watercolor wash of the photo's own colors, one edge breaks into dry-brush strokes, one edge scatters into small splatter dots, one edge fades softly into the paper. The dissolution belongs to the photo's palette, not to arbitrary colors.
- All FOUR edges (top, bottom, left, right) must dissolve; a straight cut edge on any single side is a failure. The top edge needs special care: bright sky or background areas must fade into the paper or continue upward as a watercolor wash of their own colors — the top must never end in a straight horizontal cut. The left and right edges must never run as uninterrupted straight vertical lines; break them with washes, dry-brush and splatter at several heights. The field casts no drop shadow, has no visible paper edge or card outline, and must never read as a printed photograph laid or pasted on the paper.
- Behind the field, two supporting gestures:
  - one large flat accent shape (a circle, half-circle, or rectangle) in the dominant accent color, offset so it peeks out from behind one side of the field;
  - one bold diagonal expressive brush-stroke band (deep ink or accent color, dry-brush texture with splatter) running corner-to-corner behind the field.
- Geometry by source orientation (server measurement is authoritative):
  - Landscape or near-square source: a wide mass about 80% of canvas width and about 40% of canvas height, vertically centered near 46%; center-weighted cover crop that keeps the subject complete.
  - Portrait source: a tall mass about 60% of canvas width and about 62% of canvas height, centered; center-weighted cover crop that keeps the subject complete.
- The subject must stay instantly recognizable; partial edge dissolution must never eat the subject.

## Floating Study Fragments

Place 5-7 fragments in the paper margins around the central field (top-right, middle-left, middle-right, and the bottom band), balanced but not symmetrical. Each fragment is an abstract interpretation of ONE aspect of the visual DNA — never a literal copy of an object from the photo.

Fragment vocabulary (choose a varied mix; render every fragment in the extracted palette):

1. Watercolor wash cloud — sky, atmosphere, emotion (soft bleed edges, granulation).
2. Color swatch bars — 3-4 vertical flat rectangles of the palette colors, slightly uneven hand-painted edges (color harmony study).
3. Fine line-drawing sketch — thin ink elevation lines abstracting the subject's geometry (roof lines, arches, masts, skyline rhythm), optionally with one flat color disc behind it (structural study).
4. Organic silhouette blobs — 2-3 layered translucent masses suggesting foliage or natural texture (texture study).
5. Material patch — a rough grainy area with splatter and cracked edges suggesting stone, plaster or fabric (material memory).
6. Halftone geometry — overlapping flat rectangles plus a small dot-grid / halftone patch (rhythm and structure study).
7. Light disc — one flat color circle crossed by thin horizontal streak lines (warm light / sun study).
8. Silhouette brush sketch — a tiny dark brush skyline or tree-line (spatial rhythm study).

Rendering rules for every fragment:

- Flat printed study on the paper, like ink and gouache on cream stock; artistic edges (watercolor bleed, dry-brush, torn paper); subtle transparency where two fragments overlap; at most a very delicate soft shadow.
- NOT a literal cutout of any object from the photo, NOT an isolated PNG-style sticker, NOT a cropped piece of the photograph, NOT a die-cut shape with a white border, NOT a glossy drop-shadowed sticker, NOT a product shot.
- Each fragment must be traceable to the analysis card (name which DNA aspect it interprets).

## Palette Dot Column

- Left edge, vertically centered around 30-45% of canvas height: 4-5 small filled circles stacked vertically, each one extracted palette color ordered dark to light, joined by a single hairline vertical connector; the lowest circle may fade to an outline-only circle. No labels on the dots.

## Drafting Marks

- At most six hairline construction marks in total, scattered sparsely: one crosshair, one thin arc, one small circle with center tick, a few extension lines or corner ticks. Ink gray or the single accent color only; hairline weight; never a full grid, never thick lines, never measurement numbers.

## Annotation Labels

- Every floating fragment gets exactly one label nearby: a title line (uppercase, letter-spaced sans-serif, deep ink, at most 3 words) and directly below it a sub line (smaller uppercase, gray, at most 4 words). One hairline leader connects label and fragment: a short straight line or a single right-angle elbow, optionally ending in a tiny dot at the fragment side. No arrowheads, no boxes, no bullets, no underlines.
- Bottom band: three labels evenly spaced at about 92% of canvas height, each with a hairline vertical tick rising toward the composition above.
- Total labels on the board: 6-8 including the bottom three.
- All on-image text is uppercase English only (A-Z, digits, spaces and "&"); no Chinese, no lowercase letters, no other punctuation. If the user chooses 无字, omit the subtitle and all annotation labels (keep masthead title and drafting marks).

## Text Rendering Safety

- The final prompt must quote every on-image string verbatim in quotes.
- Masthead title at most 4 words; subtitle at most 9 words; label title at most 3 words; label sub at most 4 words.
- The renderer must never invent extra words, sentences, numbers, signatures, or watermarks; no text anywhere except the masthead, subtitle, and the 6-8 labels.
- Every character must be exact, legible, and correctly spelled; no garbled or pseudo text.

## Preventive Constraints

- No multi-photo collage; exactly one source photo per board.
- No hard rectangular photo border, white frame, photo-printed-on-paper look, or Polaroid edge; the central field dissolves, never frames. All four sides of the field must dissolve; no straight cut edge on any side, no drop shadow beneath or around the field, no pasted-print look.
- No literal object cutouts, duplicated photo crops, or isolated PNG-style stickers in the margins.
- No arrows, speech bubbles, info boxes, bullet icons, infographic glyphs, or measurement numbers.
- No Chinese characters, no lowercase text, no garbled or pseudo text on the image.
- No hues outside the extracted 5-color palette plus ivory paper and deep ink.
- No neon saturation, no plastic gloss, no cheap 3D render look, no template or stock poster feel.
- No watermark, UI overlay, platform artifact, border, or frame.
- The canvas stays fixed portrait 4:5 for both landscape and portrait sources; only the central field geometry changes.

## Quality Gate

Before finalizing, check:

- One board per photo on a fixed portrait 4:5 ivory paper field, full-bleed, no border or inset plate.
- Masthead at top left: serif capitals + hairline rule + uppercase subtitle, correctly spelled.
- Central field photographic and recognizable, all four edges dissolved in different hand-crafted ways (no straight cut edge on any side, no drop shadow, no pasted-print look), one flat accent shape and one diagonal brush stroke behind it; geometry matches the server orientation measurement.
- 5-7 floating fragments, each an abstract DNA interpretation in the extracted palette, with artistic edges and no sticker borders; each paired with one uppercase label and a hairline leader; three labels aligned in the bottom band; 6-8 labels total, all correctly spelled.
- Palette dot column at the left edge; at most six hairline drafting marks.
- The whole board feels like a hand-crafted architecture studio analysis sheet: quiet, ordered, editorial; no clutter, no infographic feel.

If one major item fails, regenerate once with a shorter, stricter prompt focused on that failure.
