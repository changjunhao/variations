---
name: enamel-pin-travel-poster
description: Use when a travel photograph must become a quiet-luxury travel-magazine poster in a strict portrait template — the lower part keeps the original photo with its people, scenery, composition and color grading untouched, while the upper panel is a matte mid-tone blue-violet or grey-blue field carrying one small irregularly shaped enamel fridge-magnet pin that distills the destination's iconic scenery (optionally blending in the person from the photo), captioned only by the city and country name in a refined hairline serif with wide letter-spacing, a thin rule and a small diamond ornament between them.
---

# Enamel Pin Travel Poster

Turn one travel photograph into a fixed-template luxury travel poster: a matte muted panel on top holding a collectible enamel pin of the destination and a minimal serif caption, the untouched original photo below — quiet luxury, editorial restraint, identical geometry on every output.

## Contract

- **Invariants:** strict portrait canvas; the upper panel occupies about 45% of the height, the original photo fills the remainder with its people, scenery, composition and color grading unchanged; the panel is a matte, mid-tone blue-violet or grey-blue (never too dark, never too bright, never saturated); centered on the panel sits one small irregularly shaped fridge-magnet pin with exquisite cloisonné enamel texture and only a subtle thin metal rim; the pin distills one to three iconic elements of the photographed place and, when fitting, weaves in the person from the original photo; below the pin the only text is the city name over the country name, set in a high-end hairline serif, all caps, wide letter-spacing, with a thin horizontal rule interrupted by a small diamond ornament between the two lines; every output shares identical aspect ratio, pin size, text position and spacing.
- **Defaults:** destination, city and country names are recognized from the photograph; the panel hue is drawn from the photo's own palette shifted toward muted blue-violet or grey-blue; the pin auto-integrates the photo's person as a small enamel figure when the composition benefits; the pin shape is an organic irregular silhouette echoing the scene's contour.
- **Overrides:** accept city name, country name and pin-figure on/off from the instruction. Reject cartoon or sticker looks, shiny chrome or heavy metallic renders, extra slogans, dates, logos or watermarks added by the generator, cluttered badge collections, and any cropping or restyling of the original photo.

## Workflow

1. Analyze the supplied photograph: identify the destination (city and country), its one to three most iconic elements (landmarks, terrain, coastline, local transit or vegetation), the dominant natural colors, and whether the person in the photo has a readable pose and outfit worth miniaturizing.
2. Choose the panel color: a matte mid-tone blue-violet or grey-blue derived from the photo's palette, calm and expensive, light enough that the pin and serif type read clearly.
3. Design the pin: one irregularly shaped enamel fridge magnet, small relative to the panel, containing the destination's iconic scenery in fine cloisonné enamel; if the instruction keeps figures on and the photo's person is readable, integrate that person as a small enamel figure inside the pin scene, faithful to their pose and outfit; keep only a subtle thin metal rim — never glossy, never chunky.
4. Set the caption: city name on the first line, country name on the second, high-end hairline serif, all caps, wide letter-spacing; between the lines one thin horizontal rule broken at center by one small diamond ornament; no other text anywhere on the panel.
5. Compile the final image-generation prompt as one precise description of the finished poster, following [references/enamel-pin-style-system.md](references/enamel-pin-style-system.md):
   - strict portrait canvas, upper matte panel about 45% of height, original photo below at full width;
   - the original photo region reproduced faithfully — same people, scenery, composition and color grading;
   - the pin centered on the panel, small, enamel texture, subtle metal rim, destination scenery inside;
   - caption exactly as specified in step 4;
   - whole-image mood: quiet luxury, premium travel-magazine editorial, matte finish, soft even light.
6. End the prompt with an exclusion list: no extra words, numbers, dates, logos or watermarks beyond the city and country caption; no cartoon, sticker or flat vector look; no glossy chrome or heavy metal; no oversized or off-center pin; no recropping, retouching or restyling of the original photo; no saturated or near-black panel; no additional badges, stamps or ornaments.

## Common mistakes

- Panel too dark, too bright or too saturated — it must stay a matte mid-tone blue-violet or grey-blue.
- Pin rendered as shiny metal, chrome or a flat sticker — it is cloisonné enamel with only a subtle thin rim.
- Pin too large or off-center — it stays small and centered, with generous breathing room on the panel.
- Extra text creeping in (slogans, dates, coordinates, watermarks) — the only text is city name over country name.
- The original photo getting cropped, recolored or recomposed — the lower region must remain the untouched source.
- Inconsistent geometry between outputs — aspect ratio, pin scale, caption position and spacing are fixed by the template.
