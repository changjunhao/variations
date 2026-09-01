---
name: photo-ink-poster
description: Transform one user-provided photograph into a quiet, spacious contemporary ink-wash editorial poster on a fixed vertical 4:5 canvas — the photo's subject stays recognizable as an integrated image field (about 35%–65% of the canvas) whose edges dissolve through ink blooms, diluted washes and dry-brush loss into a deliberate low-chroma paper tone with a generous quiet-paper counterfield, plus restrained microtype only when it improves the composition and a strict text allowlist with no invented dates or titles. Use for ink-wash photo reinterpretation posters, editorial covers and cultural visuals with tactile paper texture and restrained typography; a Traditional Ink Mode is available only on explicit request.
---

# Photo Ink Poster

Compile one final image-generation prompt that turns the user-provided photograph into a quiet, spacious ink-wash editorial poster on a fixed vertical 4:5 canvas. The photograph is the primary content source: by default its subject stays recognizable inside an integrated image field whose edges dissolve into open paper; shrink to a micro editorial cluster only when the instruction asks for a freer, mood-only interpretation.

## Contract

- **Canvas:** a fixed vertical 4:5 poster canvas, flat and front-facing, never a framed mockup. All composition ratios below are anchored to this fixed canvas.
- **Photo treatment:** the supplied photograph is the content source. State what stays recognizable — identity, pose, shape, horizon, spatial geometry, or only the mood — and dissolve the peripheral edges into paper through irregular ink blooms, diluted washes, dry-brush loss, broken contours and paper-colored gaps. Keep some photographic detail crisp near the focal area while less important regions dissolve progressively. Never reduce the photo to a small pasted rectangle, and never apply a uniform gray watercolor filter over the whole photograph.
- **Style mode default:** Contemporary Editorial Mode. Use Traditional Ink Mode only when explicitly requested (see below).
- **Text:** every word on the poster must pass the Text Intent Gate and appear on the explicit allowlist; the theme of the photo is never automatically rendered as a title.
- **Defaults:** integrated-photo-field scale for a recognizable subject (roughly 35%–65% of the canvas) with a meaningful quiet-paper counterfield; a deliberate paper tone derived from the subject, mood and source palette; restrained serif, monospaced, typewriter or clean humanist microtype instead of brush calligraphy; textless is equally valid when aesthetically stronger.
- **Overrides:** accept the instruction axes 风格模式 (传统水墨 → switch to Traditional Ink Mode), 画面文字 (无字 → force a completely textless composition, taking precedence over any other wording), and 文字内容 (user-supplied exact wording → place it verbatim on the allowed in-image text list, kept small). Reject any other added text, invented dates, four-digit years, translated or transliterated theme words, oversized brush titles, large decorative seals, glossy 3D mockups, cinematic lighting and generic stock-photo polish.

## Style Mode

Use **Contemporary Editorial Mode** by default.

- Treat ink, water, absorption, and paper as visual materials, not automatically as a traditional Chinese cultural theme.
- For a supplied photo whose subject should remain recognizable, use the integrated image field while preserving a substantial quiet-paper region. For a mood-only brief, favor a micro image cluster with roughly 76%-92% quiet paper.
- Use no display title by default. Decide whether small editorial microtype improves the composition; a textless image is equally valid when it is aesthetically stronger.
- Prefer restrained serif, monospaced, typewriter, or clean humanist typography over brush calligraphy.
- Use photo fragments, abstract washes, isolated objects, geometric panels, or contemporary image-text relationships.
- Traditional architecture, seals, or classical scenery may appear when they support the idea, but keep them inside the compact visual cluster selected for the composition. Treat them as small fragments or accents, not as a full-page traditional scene.

Use **Traditional Ink Mode** only when the instruction asks for the overall poster language to feel like traditional Chinese painting, 国风, 古风, 山水, 书法, or a historically traditional composition. A small roof fragment, seal, or classical image anchor alone does not require Traditional Ink Mode. Even in Traditional Ink Mode, preserve generous negative space unless the user requests a fuller scene.

## Ink-Wash Prompt Compiler

Before writing the final prompt, identify:

- the core subject of the photograph;
- the intended mood;
- one imageable motif or visual metaphor drawn from the photo;
- the visual scale: an integrated image field (default) or a micro editorial cluster;
- one dominant attention channel and at most one or two quiet supporting channels;
- a deliberate paper tone chosen from the subject, mood, source-image palette, ink contrast, and intended use;
- exact short text explicitly requested for the image; otherwise decide whether the poster benefits from non-factual poetic/editorial microcopy and write that copy exactly before generation;
- what the photo must preserve: identity, pose, shape, horizon, spatial geometry, or only the mood.

Extract one central image from the photograph instead of illustrating every part of the scene.

### Text Intent Gate

Classify every user-supplied word as either **subject matter** or **approved in-image copy** before designing the poster.

- A quoted or trailing word is still subject matter when it completes phrases such as "about X", "以 X 为主题", "关于 X", or "融合成 X 的海报". For example, the final `“山”` in a photo-fusion request means the visual subject is mountain; it is not permission to print `山`, `MOUNTAIN`, or `SHAN`.
- Treat text as approved in-image copy only when the user explicitly asks to display, write, typeset, title, caption, or preserve those exact words.
- Build an `allowed in-image text` list. If typography is selected without user copy, write the exact non-factual microcopy yourself and place only that wording on the list. If a textless composition is selected, the list is empty.
- Build a separate factual-metadata list from user-supplied dates, years, times, places, issue numbers, prices, URLs, schedules, and calls to action. Never infer entries from the theme, visual era, or reference-image mood.
- The final prompt must say `Render only this allowed in-image text: [...]` and `Do not render any other words, letters, Chinese characters, numerals, years, dates, labels, captions, signs, or seal inscriptions.` When the list is empty, state `Completely textless; no typography or legible symbols of any kind.`

### Visual Rules

Use these as flexible defaults, not rigid requirements:

1. **Canvas and paper**
   - The canvas is a fixed vertical 4:5 poster; use a flat, front-facing poster rather than a framed mockup.
   - Choose the paper color for this specific brief. Do not use the same warm off-white or beige paper as an automatic signature across unrelated outputs.
   - Derive the paper tone from the emotional temperature, subject, season or time of day, source-image colors, ink value, accent color, and intended use. State the selected hue and material explicitly in the prompt.
   - Keep most paper colors quiet and low-chroma so they support ink rather than behave like a flat colored backdrop. Suitable directions include clear white, cool porcelain white, warm rice, pale ivory, mist gray, blue-gray, muted celadon, pale mineral green, moonlit pale indigo, dusty rose-gray, light ochre, and unbleached fiber. Use charcoal, deep indigo, or another dark paper only when the concept benefits from reversed light ink or mineral pigment.
   - Preserve tactile paper behavior through fibers, pulp variation, deckled absorption, faint stains, or subtle printing wear. Do not simulate variety with a digital gradient or a uniform color fill.
   - Reserve strongly aged, yellowed, antique xuan-paper styling for Traditional Ink Mode, historical material, archival memory, or an explicit request; do not equate all ink-wash work with aged cream paper.

2. **Composition and space**
   - Build around one clear focal subject, gesture, or relation.
   - Default to an integrated image field occupying roughly 35%-65% of the canvas, keeping a meaningful quiet-paper field and dissolving the image into it rather than shrinking the source into a thumbnail.
   - Use a micro editorial cluster occupying about 8%-24% of the canvas, with roughly 76%-92% quiet paper, only when the photo is treated as mood or texture rather than a subject to preserve.
   - Treat these ranges as starting points, not quotas. Judge whether the composition breathes at full size and thumbnail size.
   - Consider upper-left, upper-right, lower-left, lower-right, true center, lower-center, left-center, and right-center as available anchor positions.
   - Choose the position that best supports the subject shape, text relationship, negative-space balance, and overall beauty; do not rotate positions mechanically.
   - State the chosen position in the prompt and keep the cluster comfortably inset from the edges.
   - Let the subject float, crop, dissolve, descend, or sit off-center when it supports the mood.
   - Establish one dominant attention channel: image, typography, or geometric mark. Allow at most one or two quieter supporting channels. A detailed scene, display title, caption block, and seal must not all compete at once.

3. **Subject treatment**
   - Translate the photo into a preserved subject absorbed into wash, a partial landscape, a silhouette, a brush gesture, a photographic fragment, an ink bloom, or an abstract relation.
   - Prefer suggestion over literal scene-building. If the scene is naturally detailed, simplify its perimeter, background, props, and secondary signage before reducing the subject itself. Preserve the emotional evidence, not every object.
   - When the source subject is important, preserve it at a readable scale and merge it into the paper with irregular ink blooms, diluted washes, dry-brush loss, broken contours, and paper-colored gaps. Avoid a small rectangular photo pasted onto the page.

4. **Ink and material**
   - In Contemporary Editorial Mode, choose a specific material behavior: dry-brush fracture, wet wash bloom, diluted layers, pooled pigment edge, rubbed transfer, soft photocopy grain, or an ink-absorbed photo fragment.
   - Use fine xieyi contour or controlled calligraphic strokes mainly in Traditional Ink Mode or when the concept calls for them.
   - Make paper fibers, absorption, broken edges, and tonal dilution visible enough to feel physical rather than like a gray digital filter.

5. **Typography**
   - Treat the photo's theme as subject matter rather than mandatory in-image text.
   - Decide between textless, one small editorial phrase, or a few microtext details according to visual balance. Do not mechanically add or remove text.
   - Choose a deliberate text-density mode: textless; sparse with one short phrase; lightly annotated with two or three tiny labels; or type-led only when typography is the main concept. Do not combine every mode.
   - When the user supplies no copy and typography improves the composition, invent only non-factual microcopy that supports the theme, such as a short poetic phrase or neutral thematic label. Do not simply typeset the theme as a headline.
   - Treat dates, times, locations, venues, weather records, issue numbers, prices, URLs, schedules, and calls to action as factual metadata. Use them only when the user supplies them.
   - Treat every four-digit number and date-like numeric string as factual metadata. Never use a current year, decorative year, pseudo-archive date, or arbitrary number merely to make the layout feel editorial.
   - When used, keep the primary small phrase around 1.5%-3% of canvas height and secondary microtext around 0.8%-1.5%, using restrained serif, monospaced, typewriter, or clean humanist type.
   - Place text near the image cluster or in a distant area as a quiet counterpoint when that improves balance. Quote the exact wording in the image prompt so the model has something concrete to render.
   - Add a title only when the user supplies or requests one, and keep it small unless the user explicitly asks for display type. Reserve large brush lettering and vertical poetry for explicit requests.
   - Keep exact in-image text short because image models may distort long copy.
   - Treat typography as part of the composition rather than a headline. It should not compete with the image cluster unless the user asks for type-led work.
   - Count visible signs, labels inside the scene, seals, captions, and editorial copy as one shared text budget. If the scene already contains meaningful signage, reduce or remove external typography.
   - Never translate, transliterate, or repeat a theme word as extra typography unless that exact additional wording is on the allowed in-image text list. `山` does not implicitly authorize `山`, `MOUNTAIN`, and `SHAN` as three separate text elements.

6. **Color and mood**
   - Let ink value, the selected paper tone, and one optional accent form a coherent palette.
   - Adjust the ink family to the paper: neutral black or graphite on warm paper; blue-black, charcoal, or smoky indigo on cool paper; warmer carbon ink on green or ochre paper; light mineral or chalk-like pigment on dark paper.
   - Add one restrained modern accent such as yellow, cobalt, tomato red, indigo, mineral green, ochre, or a user-specified color when it helps the subject.
   - Keep the mood quiet, contemplative, tender, austere, distant, alert, nostalgic, or lightly surreal according to the brief.

### Prompt Shape

Write the final image prompt as four compact paragraphs:

1. canvas, paper, composition, and negative space;
2. subject or metaphor, placement, visual scale, attention hierarchy, and ink treatment;
3. typography density, palette, surface texture, and the photo's preservation or fusion role;
4. style mode, mood, flat scanned-paper finish, and a short avoid-list.

In Contemporary Editorial Mode, explicitly say `contemporary minimal ink-wash editorial composition, not a full-page traditional painting scene; small traditional fragments are allowed when relevant`. Prefer concrete visual instructions over a long style essay. State the exact paper hue and material, why its temperature suits the subject, the chosen anchor position, whether the composition uses a micro cluster or integrated image field, what receives first attention, how the ink behaves, the complete allowed in-image text list, that no display title should appear unless requested, and what remains empty. Describe what of the photo stays recognizable and how its edges dissolve into paper. End the avoid-list with explicit bans on any theme-word title, extra translation or transliteration, four-digit year, date-like string, and text outside the allowlist.

## Variation Engine

Use these axes as a design vocabulary. Choose only what improves the composition; do not fill them mechanically.

### Anchor Position

- **upper-left:** compact cluster in the upper-left quadrant, open field below and right
- **upper-right:** compact cluster in the upper-right quadrant, open field below and left
- **lower-left:** compact cluster in the lower-left quadrant, expansive quiet top
- **lower-right:** compact cluster in the lower-right quadrant, expansive quiet top
- **true-center:** centered cluster with balanced paper on all sides
- **lower-center:** centered horizontally in the lower third, open upper field
- **left-center:** cluster at mid-height on the left, open right field
- **right-center:** cluster at mid-height on the right; use sparingly and avoid repeating it across consecutive outputs

### Layout

- **integrated-photo-field:** a recognizable supplied subject occupies a substantial area, with irregular ink-wash edges dissolving into open paper — the default for photo reinterpretation
- **micro-cluster:** a very small image-and-type cluster surrounded by 80% or more quiet paper
- **breathing-center:** a small central or lower-center subject surrounded by paper
- **low-horizon:** a low wash or landscape fragment with open space above
- **offset-specimen:** an isolated object in one quadrant with balanced type
- **quiet-corner:** tiny supporting text in one corner with a distant image fragment
- **split-fragment:** two small adjacent image panels, one neutral and one accented
- **cropped-threshold:** a subject entering from one edge with a stable quiet field
- **asymmetrical-pair:** two related fragments separated by deliberate space
- **type-led:** typography leads and ink acts as the counter-mark

### Ink Gesture

- dry-brush fracture
- wet wash bloom
- diluted transparent layers
- rubbed transfer
- soft photocopy or scan grain
- ink-absorbed photographic fragment
- near-erased ghost mark

### Subject Form

- photographic fragment absorbed into wash (default for a supplied photo)
- isolated object
- partial landscape
- ink silhouette
- abstract texture window
- one symbolic relation between two forms
- almost image-less, led by a single brush gesture

### Visual Scale

- **integrated field:** larger recognizable subject with a substantial quiet-paper counterfield — the default for photo reinterpretation
- **micro editorial:** small image or image-and-type cluster, for mood-only or conceptual briefs

### Reference Treatment

- **preserve and absorb:** retain the subject, pose, horizon, or identity while dissolving peripheral edges into ink and paper — the default for a supplied photo
- **fragment and reframe:** crop the source into one or two designed fragments when collage or editorial comparison supports the idea
- **mood only:** borrow palette, light, rhythm, or texture without preserving source geometry

### Paper Tone

- **clear or cool white:** clean, airy, snowy, precise, quiet, or high-key subjects
- **warm rice or pale ivory:** humane warmth, wood, books, memory, dusk, or intimate subjects
- **mist gray or blue-gray:** rain, lake, fog, distance, urban quiet, or reflective subjects
- **muted celadon or mineral green:** spring, plants, renewal, tea, moss, or organic calm
- **pale indigo or moonlit blue:** night, moon, winter, solitude, or cold luminous space
- **dusty rose-gray or muted clay:** tenderness, body, flowers, fading warmth, or restrained emotional work
- **light ochre or unbleached fiber:** earth, autumn, craft, history, dry landscape, or archival material
- **charcoal or deep indigo:** rare dark-paper mode for night, grief, drama, or luminous mineral marks

These are associations, not fixed mappings. Choose by overall harmony and legibility; do not rotate paper colors mechanically.

### Type Mode

- textless when visually stronger for the concept
- small poetic/editorial phrase with exact wording
- tiny theme label used as metadata, not a headline
- small supplied title, only when requested
- non-factual archive-like microtext
- fragmented floating letters
- tiny editorial caption
- loose type near the ink edge
- user-supplied date, location, or index only

## Workflow

1. Parse the photograph and the instruction.
   - Inventory the photo: subject, mood, palette, spatial geometry, and what deserves preservation.
   - Identify useful text, supplied factual metadata, and the photo's preservation priorities.
   - If no copy is supplied, decide whether textless or restrained invented microcopy produces the stronger composition.
   - Never infer a date, time, location, venue, issue number, schedule, URL, or CTA from the theme alone.
   - Run the Text Intent Gate. Do not treat quotation marks alone as permission to place a theme word in the image.

2. Choose a visual recipe.
   - Select Contemporary Editorial Mode by default; use Traditional Ink Mode only from explicit cues.
   - Choose integrated-field scale by default so the supplied photo stays legible and present; choose micro editorial scale only for a mood-only brief.
   - Choose the most aesthetically balanced anchor position, layout, ink gesture, subject form, reference treatment, type mode, paper hue and material, and optional accent.
   - Select the paper tone from the brief and source palette, then check that the ink and accent remain legible. Do not fall back to warm ivory merely because the work is ink-wash.
   - Set one dominant attention channel and reduce all supporting elements. Decide the text-density mode from the final hierarchy rather than from a fixed quota.
   - Keep the choices coherent with the content rather than filling a checklist.

3. Write the final prompt.
   - Use the four-paragraph Prompt Shape.
   - Make the composition and material behavior explicit.
   - Name the chosen anchor position. When text is used, quote the exact small text to render; when textless, say so explicitly.
   - State the visual scale, first-read element, supporting elements, and what has been intentionally omitted. State both the photo's preservation priorities and the ink-to-paper edge transition.
   - Name the exact paper hue, temperature, fiber or surface character, and its relationship to the ink palette. Avoid vague wording such as only `textured paper`.
   - If the user did not supply factual metadata, explicitly exclude invented dates, times, locations, venues, schedules, issue numbers, URLs, and CTAs.
   - Include the complete allowed in-image text list and require the image model to render no text outside it. Explicitly ban numerals and four-digit years when none were supplied.

4. Self-check the compiled prompt against the Final Self-Check list before returning it.

## Common mistakes

- The photo shrinks to a small pasted rectangle or thumbnail on the page — the integrated field must stay at a readable scale and dissolve into the paper.
- A uniform gray watercolor filter over the whole photograph — detail stays crisp near the focal area and only the peripheral edges dissolve.
- The same warm off-white paper reused by habit, or a saturated digital fill or gradient faking paper texture.
- A quoted theme word rendered, translated, or transliterated as a title without explicit approval.
- Invented dates, four-digit years, decorative numbers, pseudo-archive metadata, or any text outside the allowlist.
- Oversized brush lettering, a full-page traditional scene, or large decorative seals competing with the subject in Contemporary Editorial Mode.
- Multiple competing attention channels — detailed scene plus title plus caption block plus seal all at once.
- Mechanical right-center anchoring or checklist-filling instead of a composition chosen for this subject.

## Default Avoids

Avoid by default: invented dates, four-digit years, times, locations, venues, schedules, issue numbers, URLs, CTAs, pseudo-archive numbers, or other factual-looking metadata; any unrequested title; automatic translation or transliteration of the theme; text outside the explicit allowlist; oversized brush lettering; a full-page traditional scene; oversized architecture; large decorative seals; or multiple classical motifs competing for attention. Small traditional buildings, seals, lanterns, umbrellas, classical street fragments, or antique scenery are allowed when relevant, but subordinate them to the chosen hierarchy and retain a meaningful quiet-paper field. Also avoid using the same aged cream or warm beige paper for every subject; arbitrary paper-color rotation unrelated to the brief; saturated digital background fills; gradients used as fake paper variation; a detailed scene competing with a title, signboard, caption block, and seal; reducing an important reference photo to a tiny pasted rectangle; uniform watercolor-filter treatment; glossy 3D mockups; cinematic lighting; neon effects; crowded collages; generic stock-photo polish; too many competing objects; and long dense text.

## Final Self-Check

Before returning the compiled prompt, verify:

- Is the canvas stated as the fixed vertical 4:5 poster, flat and front-facing?
- Did an underspecified request use Contemporary Editorial Mode rather than defaulting to traditional imagery?
- Did the photo become one clear image or relation, at integrated-field scale with a substantial quiet-paper counterfield?
- Is there one clear first-read element, with no more than one or two quiet supporting channels?
- Does the choice between textless and microtype feel aesthetically deliberate?
- If typography is present, is it clearly subordinate rather than behaving like a large title?
- Is every date, time, location, venue, schedule, issue number, URL, or CTA supplied by the user rather than invented?
- Does every word, character, numeral, sign, and legible seal in the prompt appear on the allowed in-image text or factual-metadata list?
- Was a quoted theme correctly treated as subject matter rather than automatically rendered, translated, or transliterated as a title?
- If the user supplied no year or numeric metadata, does the prompt explicitly ban four-digit years, dates, and decorative numbers?
- Do ink and paper read as material rather than digitally filtered, with the exact paper hue named?
- Does the paper hue support this subject, mood, source palette, and ink contrast rather than repeating the same warm off-white by habit?
- Does the prompt state what of the photo stays recognizable and how its edges dissolve into paper, instead of a pasted thumbnail?
- Does the anchor position feel deliberately chosen for this composition rather than mechanically defaulted to right-center?
- Will the poster still read at thumbnail size?

## Privacy

Do not expose full legal names, personal email addresses, phone numbers, student IDs, residential addresses, credentials, API keys, tokens, passwords, private computer paths, private file names, or EXIF GPS information.

Do not place personal information in titles, metadata, file names, prompts, documentation, or examples unless the user explicitly requests it.
