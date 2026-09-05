---
name: flat-vector-city-poster
description: Use when a travel photograph must become a premium minimalist flat-vector city travel poster in Japanese stationery-goods aesthetics on a fixed portrait 3:4 canvas — the city's identity distilled into one focal landmark plus two to four local elements (mobility, everyday scene, native plant, understated signage), three to six tiny figures in real local life, a misty-blue palette balanced with warm ivory and sage neutrals, and quiet upper-left typography carrying only the city name and one short English tagline. Every city gets its own composition; never a reusable template, never a landmark collage.
---

# Flat Vector City Poster

Turn one travel photograph into a premium minimalist flat-vector city travel poster: the photograph is the city's visual evidence, recomposed as clean geometric vector shapes on a fixed portrait canvas — Japanese stationery-goods calm, misty-blue air, generous breathing room, and typography that whispers.

## Contract

- **Canvas:** fixed portrait 3:4 (server pixel size authoritative, e.g. 960*1280); identical aspect on every output regardless of source orientation; a landscape source is recomposed into the portrait canvas, never letterboxed.
- **Source role:** the photo is the composition backbone and the city's visual evidence. Preserve its viewpoint, horizon height and the placement of its main masses (skyline side, water band, bridge, street, foliage); transform what is actually visible into flat vector, including the hues of its characteristic foreground band (flower field, crop rows, market stalls) — inherit the source's own flower and crop colors rather than defaulting to pink. Never replace the user's scene with a generic postcard view of the city.
- **City determination:** the instruction's 【城市名】 is authoritative — render it exactly as supplied (Chinese glyphs or letterspaced Latin uppercase). Otherwise recognize the city from the photo's landmarks. If neither yields a confident city, keep the layout and the tagline but drop the city-name line.
- **Text:** every visible character must pass the Text Rendering Safety allowlist; nothing else may appear.
- **Full-bleed & paper trim:** the illustration fills its inner field edge to edge — open sky touches the inner top edge, scene elements are cut by the inner side edges, foreground ground touches the inner bottom edge; one single thin uniform warm-ivory paper trim (about 2–3% of the canvas width) surrounds the inner field on all four sides like a trimmed stationery print, identical in width on every output; the trim's warm-ivory tone reaches the outermost canvas edge on all four sides — exactly one paper band, no second outer band, table color, or background tone outside it; the trim is one single flat tone from its inner edge to the outermost canvas edge, with no outline, keyline, or dark contour where the scene meets it — scene colors touch the trim directly with a clean cut; the trim is flat matte paper with no inner rule line, no shadow, no deckle edge, and it is the only margin anywhere; the print scans perfectly flat — no lifted-edge shadow, curl, or vignette at the canvas borders; negative space lives inside the composition as open sky, not as extra framing; never a poster floating on a gray studio background, never paper grain, drop shadows, frames, or 3D mockups.
- **Output:** a single final prompt for one image; no mockups, no frames, no borders.

## City Identity

Before writing the prompt, inventory the source and commit to five elements:

1. one recognizable landmark, architectural feature or skyline element;
2. one local mobility mode (tram, ferry, bicycle, cable car, river boat);
3. one small everyday street scene (market stall, riverside garden, rooftop terrace, old-quarter lane);
4. one native plant, natural feature or terrain (plane trees, bougainvillea, sea, river, hills);
5. one viewpoint and framing that matches the city's temperament, chosen from what the photo actually shows — harbor view, tram avenue, old-town lane, riverside promenade, hillside overlook, market arcade, ferry pier, skyline terrace.

The overall composition must change from city to city: never reuse the same object placement, visual structure or framing formula, and never default to a café-terrace composition or a generic travel-poster template.

## Composition & Hierarchy

- One representative landmark or building as the single visual focus; only 2–4 further carefully chosen local elements as support. Every added detail must strengthen "this is that city"; avoid stacking landmarks or a postcard collage of sights.
- Quiet, restrained, deliberate visual organization with generous breathing space; the poster must still read at thumbnail size.
- Keep the upper-left sky region free of foliage, trunks, towers and landmarks so the typography always sits on clean open sky; framing trees and masses belong to the right side, the lower band, or the middle distance.
- People: only 3–6 small-scale figures — count them, never seven or more — each in a real local activity — strolling a lane, cycling, waiting for transit, sketching, boarding a ferry, reading outdoors, photographing quietly. No crowds, no protagonist figure; every figure blends into the urban environment.
- Local character only when true to the city: local transit, architectural style, street furniture, vegetation, small signage or wayfinding, local food, leisure activity, understated ground markers. Keep transit and signage restrained — a small bus-stop plate, station clock, ferry information board, bicycle symbol, road markings, beach flag, quiet metro icon — never large signboards.

## Typography

- Place the city name in the upper-left corner region — its left edge inset from the inner trim edge by about 8–10% of the canvas width, its top edge about 6–8% below the inner top edge, never drifting toward the horizontal center — on ample clean negative space, with one short, refined English tagline inspired by the city's atmosphere and temperament set beside or below it.
- Typesetting stays restrained and editorial: controlled, generous, refined, premium, with wide letter-spacing on the city name; text never becomes the dominant element of the image.

## Art Direction

- Japanese stationery-goods aesthetics, premium paper-feel illustration (matte paper feel without literal grain), refined commercial vector illustration, modern editorial travel-brand visual.
- Clean fine contours with uniform line weight; simple geometric shapes; pure flat matte color fills; soft shapes; balanced visual rhythm; premium minimal postcard design.
- Forbidden renders: photorealism, watercolor, painterly brushstrokes, gradients, heavy shadows, dramatic cinematic light; sky and water are single flat tones with no vertical gradient and no horizon glow.

## Color System

- Dominant atmosphere in light misty blues: pale powder blue, soft sky blue, thin mist blue and other light, cool blue tones — the blue family must occupy the largest color fields (sky and, when present, water); the neutrals below balance it and must never outweigh it.
- Balanced with warm ivory, cream, soft beige, low-saturation sage green, grey-green and understated architectural neutrals.
- Grey-pink or low-saturation blush only as rare tiny accents on objects: flowers, clothing details, small signage, parasols, ornaments; ground, pavement, sky and water planes never take blush; a foreground flower or crop band takes the source's own hues (yellow, red, white, purple…), never default blush.
- All colors soft, refined, slightly desaturated, holding one unified harmonious palette.

## Mood

Fresh, light, quiet, refined, contemporary, elegant — like a premium travel brand's postcard or a high-end lifestyle brand's commercial illustration, with ample breathing space and a relaxed, natural local atmosphere.

## Text Rendering Safety

- Build the allowed in-image text list with exactly these slots, verbatim: city name (as supplied: Chinese ≤4 glyphs, or letterspaced Latin uppercase ≤12 letters) and one English tagline (≤5 words, title case). Omit the name slot when the city is undetermined.
- The tagline is taken verbatim from the instruction's 【英文标语】 when supplied; otherwise write one original city-specific line tied to the city's light, water or temperament — never generic phrases like "Beautiful City" or "Welcome to".
- The final prompt must say `Render only this allowed in-image text, verbatim: [...]` and `no other words, letters, Chinese characters, numerals, signs, logos, or watermarks`.
- Image models garble long or dense text: keep each line short, quoted exactly, and separated by line breaks in the prompt.
- Script binding: render the city name in exactly the script supplied — Chinese input must appear as Chinese glyphs, never Latinized; Latin input must appear as letterspaced uppercase, never translated into Chinese. Binding examples: 【城市名】：太原 → in-image “太原”; 【城市名】：Paris → in-image “PARIS”.
- Signage freeze: building facades, bridges and street furniture carry no banners, logos, sign patches or lettering of any kind — the typography block is the only in-image text; where the source photo shows facade signage, render that facade area as plain flat glass or wall.

## Prompt Skeleton

> Create one fixed portrait 3:4 premium flat-vector city travel poster ([measured pixels if supplied]) in Japanese stationery-goods aesthetics. Theme: [city]. Preserve the source photo's actual viewpoint and composition — horizon height, the side and placement of skyline/water/street, and its visible landmarks [name what is visible] — recomposed into the portrait canvas as flat vector shapes rather than inventing a different view of the city. City identity: [focal landmark] as the single visual focus, supported by only 2–4 local elements [mobility mode, everyday scene, native plant, understated signage]; viewpoint [chosen framing]. 3–6 tiny faceless figures in real local activities (count them: never seven or more), blended into the environment; no crowds, no protagonist. Style: clean fine contours of uniform weight, simple geometric shapes, pure flat matte fills, soft shapes, balanced visual rhythm, premium minimal postcard design; matte paper feel with no literal grain; sky and water as single flat tones with no vertical gradient or horizon glow; building facades carry no signs, banners, logos, or lettering — source facade signage becomes plain flat glass or wall. Color: dominant pale powder blue, soft sky blue and thin mist blue atmosphere holding the largest color fields (sky and water), balanced with warm ivory, cream, soft beige and low-saturation sage / grey-green neutrals that never outweigh the blue family; grey-pink only as rare tiny accents on objects, with pavement and ground planes staying warm ivory / cream / beige, and the foreground flower or crop band inheriting the source's own hues; all slightly desaturated in one harmonious palette. Typography anchored in the upper-left corner region (left inset about 8–10% of canvas width from the trim, top about 6–8% below the inner top edge, never centered) on clean open sky kept free of foliage and landmarks: city name "[城市名]" rendered in exactly the supplied script (Chinese input as Chinese glyphs, never Latinized) and one English tagline "[Tagline]", restrained editorial letterspacing, text never dominant. Mood: fresh, light, quiet, refined, contemporary, elegant; generous breathing space and a relaxed local atmosphere. Template frame: one thin uniform warm-ivory paper trim (about 2–3% of canvas width) surrounds the illustration on all four sides like a trimmed stationery print, and the trim color reaches the outermost canvas edge — exactly one paper band, one flat tone, nothing outside it; scene colors meet the trim directly with a clean cut, no outline, keyline, or thin contour framing the inner scene field; inside the trim the scene runs off all four inner edges — sky color at the top, scene elements at the sides, foreground pavement at the bottom; no second margin, no rule line, no shadow between trim and scene; the print scans perfectly flat with no edge shadow, curl, or vignette at the canvas borders. Avoid: photorealism, realism, watercolor, painterly brushstrokes, gradients, heavy shadows, dramatic cinematic light, paper grain texture, excessive detail, cluttered background, landmark collage, crowded street, oversized people, single heroic figure, repeated café-terrace composition, fixed signboard placement, identical foreground treatment across cities, generic travel-poster template, copying another city's layout, unnecessary decorative elements, uneven margins, double margins, a second outer band or background tone outside the paper trim, two-tone trim bands, keylines or outlines between trim and scene, rule lines, or shadows around the paper trim, edge shadows, curls, or vignettes at the canvas borders, blush-tinted ground or sky planes, recoloring the source's flower or crop band to default pink, signs, banners, logos, or lettering on building facades, Latinizing a Chinese city name, translating a Latin city name into Chinese, any text outside the allowlist, garbled or extra characters, gray studio background, visible paper edges, drop shadows, frames, and poster mockups.

## Final Self-Check

- Is the canvas stated as fixed portrait 3:4 with the server pixel size when present, identical on every output?
- Does the poster follow the source photo's actual scene — viewpoint, horizon height, mass placement, visible landmarks, and the hues of its characteristic foreground band — instead of a generic stock view of the city?
- Are the five city-identity elements inventoried and the framing chosen for this city, not a reused template?
- Is there exactly one focal landmark with at most 2–4 supporting local elements, quietly organized?
- Are there exactly 3–6 small figures (counted, never seven or more) in real local activities, with no crowd and no protagonist?
- Does the palette give the misty blues the largest color fields (sky and water), with ivory / cream / sage neutrals only balancing, blush only as tiny accents on objects (never on ground or sky planes), all flat fills without gradients?
- Is the typography anchored in the upper-left corner region (not centered) on clean open sky, restrained and never dominant?
- Does the allowed in-image text list contain only the city-name and tagline slots, each within its limit and quoted verbatim, with no signage, banners, logos, or garbled patches on facades, bridges, or street furniture?
- Does the city name appear in exactly the supplied script — Chinese input as Chinese glyphs, Latin input as letterspaced uppercase — with no Latinization or translation?
- Is the single warm-ivory paper trim thin, uniform, one flat tone from inner edge to the outermost canvas edge with no second outer band, no keyline where the scene meets it, and identical across outputs, with the scene running off all four inner edges and no second margin, rule line, shadow (including edge shadow at the canvas borders), grain, gray background, or mockup?
- Will the poster still read at thumbnail size?
