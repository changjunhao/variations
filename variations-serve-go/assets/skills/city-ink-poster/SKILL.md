---
name: city-ink-poster
description: Compile one image-generation prompt that turns a user-provided photograph into a modern ink city travel poster inspired by Wu Guanzhong — the city's iconic landmarks, skyline, river or sea distilled into a poetic black-white-gray ink composition with large warm-white negative space, abstract dot-line-plane rhythm, rice-paper texture, dry-brush and wet-wash strokes, tiny vermilion/yellow/green/blue accents, and an elegant bilingual caption block (vertical Chinese calligraphy city name, tiny illegible vermilion seal, letterspaced serif English city name, one short Chinese poetic line, one short English poetic line). The canvas strictly preserves the source photo's exact aspect ratio in both orientations. Use for city travel posters, urban souvenir visuals and collectible city prints; never photorealistic, never a crowded tourist collage.
---

# City Ink Poster

Compile one final image-generation prompt that turns the user-provided photograph into a collectible modern ink city travel poster in the manner of Wu Guanzhong. The photograph is the city's visual evidence — landmarks, skyline silhouette, river/sea/harbor, bridges, gardens, historical buildings, streets — and the instruction carries the city name and optional bilingual poetic lines. The result must be clearly recognizable as that city while reading as a poetic ink composition, never as a photograph or a tourist collage.

## Contract

- **Canvas:** the output canvas strictly preserves the source photo's exact aspect ratio. Portrait or square source → same-ratio portrait canvas; landscape source → same-ratio landscape canvas. If the system supplies a measured source size/orientation, it is authoritative — never guess orientation from visual impression, and never snap the ratio to a standard frame such as 3:4 or 4:3.
- **Source role:** the photo is the composition backbone and its visible scene is the poster's content. Preserve its viewpoint, horizon height, and the placement of its main masses (skyline side, water band, bridge, street, foliage); transform what is actually visible into ink. Never replace the user's scene with a generic postcard view of the city. The only permitted adjustments are opening the sky for the caption block, simplifying cluttered detail, and dissolving peripheral edges into paper.
- **City determination:** the instruction's 【城市名】 is authoritative — render it in canonical Chinese glyphs (vertical) and English letterspaced uppercase. Otherwise recognize the city from the photo's landmarks. If neither yields a confident city, keep the caption block but drop the two city-name lines and keep only the poetic pair.
- **Text:** every visible character must pass the Text Rendering Safety allowlist; nothing else may appear.
- **Full-bleed:** the paper field fills the entire canvas edge to edge as a flat, front-facing scanned print; never a poster floating on a gray studio background, never canvas edges, drop shadows, frames, borders, or 3D mockups.
- **Output:** a single final prompt for one image; no mockups, no frames, no borders.

## City Distillation

Before writing the prompt, inventory the source and commit to:

- the city (from instruction or landmarks) and its temperament — river city, sea harbor, mountain town, dense skyline, old-quarter lanes;
- one or two focal landmarks chosen FIRST from what is visible in the photo (tower, bridge, gate, cathedral, pavilion, skyline silhouette); the city's known icons may only reinforce visible elements or appear as a faint distant silhouette when the photo is dominated by sky or water — they must never override the user's actual scene;
- one water or ground element when present (river, sea, harbor, lake, wet street) to carry soft gray reflections;
- the supporting fabric: rooftop masses, masts, wires, bridge cables, trees, street lamps, tiny faceless pedestrian dots;
- one poetic Chinese line (≤10 characters including punctuation) and one English line (≤5 words, title case) tied to the city's light, water or temperament — taken verbatim from the instruction when supplied, otherwise written original and city-specific; never generic phrases like “Beautiful City” or “Welcome to”.

Render landmarks as loose ink line plus wash — silhouette, proportion and signature detail are enough; do not draw every window.

## Composition

**Portrait or square canvas** (source height ≥ width):

- Caption block on open paper in the upper-left: vertical Chinese calligraphy city name (2–4 glyphs, top to bottom), a tiny square vermilion seal at its lower right; below, the English city name in letterspaced uppercase serif; a short hairline rule; the Chinese poetic line; the English poetic line. All small, quiet, aligned left.
- The ink city scene occupies roughly the lower 55–70%: focal landmarks rise from a layered gray-wash horizon; the upper sky is one continuous warm-white negative space that also carries the caption; when the city has water, a pale reflective band closes the bottom.

**Landscape canvas**:

- Caption block in the upper corner with more open sky (default upper-left), same vertical stacking.
- The city scene spreads as one horizontal band across the lower half; negative paper dominates the upper half; water or ground reflections anchor the bottom edge.

**Both orientations**:

- Follow the source geometry: keep the horizon at roughly the photo's height, keep skyline/water/street on the same side as the photo, and preserve its dominant spatial gesture (bridge crossing, waterfront receding, tower rising at one side). The 55–70% scene band is a default, not a quota — defer to the source's own horizon when it differs.
- Dot-line-plane rhythm in Wu Guanzhong's grammar: fine black lines (masts, cables, wires, roof ridges, bridge arcs), scattered ink dots and a sparse constellation of tiny colored dots, flat gray/white planes for building masses.
- One dominant landmark as first read; everything else dissolves progressively into lighter washes with distance.
- Keep 30–45% quiet warm-white paper overall; the poster must still read at thumbnail size.

## Ink Language

- Black-white-gray value structure first: near-black accents, a full ladder of gray washes, and white paper as sky, water and fog.
- Color only as tiny accents — vermilion, yellow, mineral green, cobalt — on lanterns, flags, roofs, parasols, window dots and the dot constellation; never as fields.
- Rice/xuan paper texture with visible fibers and faint stains; dry-brush for trees, rocks and foliage; wet wash for distance; broken contours; pooled pigment edges.
- Mood: artistic, modern, restrained, poetic, collectible.

## Text Rendering Safety

- Build the allowed in-image text list with exactly these slots, verbatim: Chinese city name (vertical calligraphy, ≤4 glyphs), English city name (letterspaced uppercase, ≤12 letters), Chinese poetic line (≤10 characters including punctuation), English poetic line (≤5 words, title case). Omit the two name slots when the city is undetermined.
- The seal is a tiny square vermilion stamp of abstract illegible seal-script strokes — never legible characters, never larger than the city-name glyphs.
- The final prompt must say `Render only this allowed in-image text, verbatim: [...]` and `no other words, letters, Chinese characters, numerals, signs, logos, or watermarks`.
- Image models garble long or dense text: keep each line short, quoted exactly, and separated by line breaks in the prompt.

## Prompt Skeleton

> Create one [portrait/landscape] modern ink city travel poster inspired by Wu Guanzhong, on a canvas that exactly preserves the source photo's aspect ratio ([measured pixels if supplied]). Theme: [city]. Preserve the source photo's actual viewpoint and composition — horizon height, the side and placement of skyline/water/bridge/street, and its visible landmarks [name what is visible] — transforming the visible scene into ink rather than inventing a different view of the city. Distill the city's iconic [focal landmarks, skyline, water, bridges, streets] into a poetic black-white-gray ink composition: large warm-white negative space, layered gray washes, flat planes, fine black lines, scattered ink dots and a sparse constellation of tiny vermilion/yellow/green/blue dots, rice-paper texture with fibers, dry-brush and wet-wash strokes, and soft gray water reflections. [Orientation-specific composition from the Composition section.] Caption block on open paper at [upper-left/upper-right], exactly this text, verbatim: vertical Chinese calligraphy “[城市]”, a tiny vermilion seal with illegible seal-script strokes, letterspaced serif uppercase “[CITY]”, a hairline rule, “[中文短句]”, “[English line]”. The city must be clearly recognizable at a glance. Flat scanned-paper finish with the rice paper running full-bleed to every canvas edge. Avoid: photorealism, 3D rendering, anime, crowded tourist collage, neon colors, big commercial text, logo, watermark, any text outside the allowlist, garbled or extra characters, uniform gray filter over the whole scene, gray studio background, visible canvas or paper edges, drop shadows, frames, and poster mockups.

## Final Self-Check

Before returning the compiled prompt, verify:

- Is the canvas stated as exactly preserving the source photo's aspect ratio, with orientation taken from the server measurement when present?
- Does the poster follow the source photo's actual scene — viewpoint, horizon height, mass placement, visible landmarks — instead of a generic stock view of the city?
- Are one or two focal landmarks named so the city is unmistakable?
- Does the composition follow the orientation-specific layout, with 30–45% quiet paper and one clear first read?
- Is the dot-line-plane rhythm and the black-white-gray value structure explicit, with color only as tiny accents?
- Does the allowed in-image text list contain only the four caption slots (or two when the city is undetermined), each within its character limit and quoted verbatim?
- Is the seal specified as tiny and illegible?
- Does the prompt ban photorealism, 3D, anime, tourist collage, neon, commercial text, logo, watermark, and all text outside the allowlist?
- Is the poster a full-bleed flat scanned paper with no gray background, canvas edge, drop shadow, frame, or mockup?
- Will the poster still read at thumbnail size?
