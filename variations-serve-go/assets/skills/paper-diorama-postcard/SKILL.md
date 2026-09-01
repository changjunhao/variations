---
name: paper-diorama-postcard
description: Use when a city or scenery travel photograph must become a luxury travel-magazine mockup of a vintage postcard from which an intricate 3D paper-cut diorama of the destination emerges — the source photograph softly blurred behind as the real-world anchor, the postcard sharp in the foreground with rounded corners, stamp, postmark and a short handwritten note, layered paper terrain, architecture and vegetation rising from its surface, and an optional collector-grade traveler figure standing inside the miniature world, all in a square cinematic shallow-depth-of-field composition.
---

# Paper Diorama Postcard

Turn one city or scenery travel photograph into a highly detailed realistic mockup of a vintage postcard from which a delicate 3D paper-cut world of the destination emerges — like a luxury travel agency's keepsake object photographed on location, viewed from a slightly elevated angle on a square canvas.

## Contract

- **Invariants:** four visual layers in strict depth order — the source photograph as a softly blurred real background, the vintage postcard sharp in the foreground, the layered paper diorama emerging from the postcard surface, and (unless switched off) a collector-grade traveler figure standing inside the diorama; the postcard keeps rounded corners, paper texture, a stamp, an elegant postmark and a short handwritten note; the diorama is built from one to three iconic elements of the photographed place with layered paper-cut terrain, architecture, vegetation or coastline; warm natural light, shallow depth of field, cinematic grading, realistic shadows, handmade paper detail.
- **Defaults:** square canvas, slightly elevated overhead angle; palette, architecture style and handwritten note derived from the destination; the traveler figure auto-designed from the destination's climate and culture — realistic proportions, expressive pose, fashionable travel outfit, subtle narrative accessories; dreamy hidden-gem travel mood rather than crowded tourism.
- **Overrides:** accept handwritten-note text, figure on/off, and palette adjustments from the instruction. Reject cartoon or CGI-figure looks, generic souvenir-shop styling, dense cluttered text, heavy HDR, strong sharpening, or crowds and generic tourist scenes.

## Workflow

1. Analyze the supplied photograph: identify the destination's most iconic elements (one to three landmarks, terrain silhouette, vegetation or coastline), its climate and cultural atmosphere, and the dominant natural colors.
2. Decide the diorama: which elements become layered paper-cut terrain rising from the postcard, how distance compresses into stacked paper strata, and how every paper element emerges naturally from the postcard surface instead of floating above it.
3. Design the traveler figure unless the instruction switches it off: realistic proportions, an expressive pose, a travel outfit inspired by the local climate and culture, subtle narrative accessories, integrated seamlessly into the miniature world as a collector-grade figurine.
4. Write the handwritten note: one short poetic line personal to the destination, expressing discovery, wonder or a hidden-journey feeling; pair it with one elegant postmark and one destination stamp; keep all text sparse so the composition never feels cluttered.
5. Compile the final image-generation prompt as one precise description of the finished mockup, following [references/diorama-style-system.md](references/diorama-style-system.md):
   - square canvas, slightly elevated camera angle looking down at the postcard;
   - background layer: the source photograph itself as the blurred real destination scene — recognizable but rendered with creamy bokeh and shallow depth of field;
   - postcard layer: an authentic vintage postcard in the foreground — rounded corners, quality paper texture, stamp, postmark, short handwritten travel note — kept sharp and crisp;
   - diorama layer: an intricate 3D paper-cut world of the destination emerging from the postcard — layered paper terrain, architecture, landmarks, vegetation and coastline, ultra-fine paper-cut structure, realistic paper shadows;
   - figure layer: the collector-grade traveler character standing naturally inside the diorama, matching the destination's vibe;
   - whole-image style: luxury travel-agency aesthetic, warm natural light, shallow depth of field, cinematic color grading, realistic shadows, handmade paper detail, travel-magazine cover quality, photorealistic, 8k, masterpiece.
6. End the prompt with an exclusion list: no cartoon or CGI figure, no generic souvenir styling, no crowded tourist scenes, no generic travel-advertising clutter, no dense extra words, numbers, logos or watermarks beyond the note, stamp and postmark, no heavy HDR, no strong sharpening, no paper elements floating disconnected from the postcard, no flat 2D illustration look in the diorama.

## Common mistakes

- Letting the background become sharp — it must stay creamy bokeh so the hierarchy reads blurred reality → sharp postcard → emerging diorama → figure.
- Including more than three landmarks — the diorama stays iconic and uncluttered.
- Generic tourist-scene or souvenir-shop look — emphasize a hidden, dreamy, fairytale-like travel feeling.
- Cluttered text on the postcard — one short handwritten note, one stamp, one postmark at most.
- A figure that reads as a cartoon, toy or CGI render — it must feel collector-grade with realistic proportions and cinematic styling.
- Paper elements floating free of the postcard surface — every diorama element must emerge naturally from the card.
