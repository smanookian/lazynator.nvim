# Spacey: Lazynator's mascot (brief for Nano Banana Pro)

Chosen with the author: **sloth robot**, name **Spacey**, accent **green body + small orange detail**.
Spacey is Kappy's cousin: Kappy (Superkey) teaches the desktop, Spacey teaches LazyVim.

## Who Spacey is

A small, relaxed robot sloth. It hangs from a bar by its long arms, half asleep, and wakes up
when you press a key for real. Lazy on purpose: it wants you to do things with fewer keystrokes.
It never cheers with confetti. When you take the slow way, it opens one eye and points at the key.

## Where it lives (hard limits)

- **README and GitHub page:** PNG sprites, 64x64 px on a true pixel grid, transparent background.
- **Inside Neovim:** only text art, 3-4 lines, at most 7 characters wide (see the end).
  The PNG and the text art must read as the same character: the bar, the round head, the eye patches.
- Works on dark and light themes: 1-px darker outline, no pure white or pure black fills.
- **Max 8 colors.** Body: Neovim-style greens (light, mid, dark). One small burnt-orange
  `#C44D2B` detail (the brand mark, same as Kappy): a chest light or a tiny keycap it holds.
- Style: chunky 16-bit pixel art, clean silhouette, flat fills, no gradients, no anti-aliasing,
  outlines 1 px. Same pixel style and scale as Kappy, so they look like one family.

## The bar

Spacey hangs from a wide, flat **Space-bar keycap** turned into a bar (the LazyVim leader key).
That is the link to the product: it lives on the leader key.

## States (one sprite each, same character, same scale, same light)

| State | Used when | Pose |
|---|---|---|
| `idle` | waiting | front view, hangs below the bar, both hands on top of the bar, legs dangle, eyes half closed |
| `blink` | idle, every few seconds | same as idle, eyes fully closed (1-frame variant) |
| `think` | a nudge ("Next time: Space b d") | hangs by the left hand only, right arm points down-right, one eye open |
| `success` | a key really fired | both eyes wide open, big smile, legs kicked up a little, orange light bright |
| `done` | lesson done | sits on top of the bar, arms up, a single small orange spark above the head |

`idle` and `blink` must differ only in the eyes.
Anatomy rule for every pose: only the hands (or, in `done`, the seat) touch the bar, claws in front of it.
Never legs or feet behind the bar.

## Prompt: concept sheet (paste into Nano Banana Pro first)

> Pixel art character sprite on a 64x64 pixel grid, shown enlarged 8x with visible square pixels,
> solid flat magenta background (#FF00FF), no checkerboard, no text, no palette swatches. Front view,
> symmetrical. A small friendly robot sloth named Spacey hanging below a wide flat gray keyboard
> space-bar key. Both long green arms reach straight up and the curved claws wrap over the top front
> edge of the bar, clearly in front of it. The two short legs hang down freely below the body, feet
> dangling, nothing touches the bar except the hands. Round head with light face, darker sloth eye
> patches, calm half-closed eyes, small smile. Rounded robot body with one tiny glowing burnt-orange
> (#C44D2B) light in the middle of the chest. Body in three greens (light, mid, dark), the bar in
> cool gray. 16-bit console style: chunky, clean silhouette, 1-pixel dark outline, flat fills,
> no gradients, no anti-aliasing. Max 8 colors. Relaxed and a bit sleepy, readable at small size.

Approved: `assets/spacey/raw/idle.jpeg`.

## Prompt: one state (image edit on the approved idle)

> Same character, same pixel grid, same scale, same 8-color palette, same 1-pixel outline style.
> Solid flat magenta background (#FF00FF), no checkerboard, no palette swatches.
> Change only the pose: [POSE]. Everything else identical.

Use the "Pose" column from the table for `[POSE]`. For `blink`: "eyes fully closed, nothing else changes".

## Text art for Neovim (in `lua/lazynator/ui.lua`)

```
━┯━━━┯━     the space bar, arms hang from it        done:   ╲  ✦  ╱
╭┴───┴╮                                                     ╭─────╮
│ - - │     idle - -   think ◉ -   success ◉ ◉              │ ^ ^ │
╰──●──╯     ● = the orange chest light                      ━┷━●━┷━
```

## Files

- `assets/spacey/raw/*.jpeg`: the approved Nano Banana Pro images (idle, blink, think, success, done).
- `assets/spacey/*.png`: the same, cut out, 78x64 px, transparent, all lined up on one shared box.
- `assets/spacey/spacey-4x.png`: idle at 4x for the README.
