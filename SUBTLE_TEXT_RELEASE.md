# Subtle text presentation

User request: research AAA text presentation, apply a less obstructive design, push and deploy. The continuing no-testing/no-verification instruction remains in effect.

## Research and direction

- Naughty Dog's official [The Last of Us Part II accessibility breakdown](https://blog.playstation.com/2020/06/09/the-last-of-us-part-ii-accessibility-features-detailed/) documents configurable subtitle size, backgrounds and speaker identification. Apply readable subtitles and optional contrast without mandatory heavy chrome.
- Sucker Punch's [Crafting the world of Tsushima](https://blog.playstation.com/2020/07/09/crafting-the-world-of-tsushima/) describes guiding players through the world itself. The design inference for Ashen Oath is to leave more of that world visible and keep routine text peripheral.
- Ubisoft's [Assassin's Creed Shadows accessibility spotlight](https://news.ubisoft.com/pl-pl/article/1Y0Q8goho9gJzCV2UBjyUJ/assassins-creed-shadows-accessibility-spotlight) documents HUD/text resizing and configurable backgrounds. Retain Ashen Oath's text scaling and high-contrast controls.

This is original presentation informed by those principles; no proprietary UI assets are copied.

## Implementation

- Replace the ordinary dialogue rectangle, borders and decorative rule with a soft, cached radial shade. High Contrast retains its solid reading surface.
- Reduce dialogue reading width from 1120 to 860 display units and size its reading region to the current sentence's estimated wrapped length (two to four lines), instead of reserving a 140-unit text block for every line. Long text remains scrollable; important decision context and choices keep their own reading areas.
- Center subtitle text, add dark text shadows/outlines, reduce speaker headings to caption size, and remove the visible page counter.
- Present dialogue choices and History/Close controls as quiet text with a slim focus/selection marker. Preserve full input targets, wrapping, controller focus and decision semantics.
- Fade complete subtitle sentences in over 150 ms, without delaying voice, input or reading. Reduced Motion and Flash Reduction make the appearance immediate.
- Fade queued notices in/out without moving them; remove ordinary rectangular backings behind notices and interaction prompts. High Contrast retains those backings.
- Offer Subtitle Shade from 0% through 100%, defaulting to 55% for new settings. Existing saved opacity values are preserved.

Only production import/export and deployment are authorized here. No tests, visual previews, gameplay launches, verification or post-deployment requests will be run. Publication receipt follows the deployment command's result.
