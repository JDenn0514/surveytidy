# =============================================================================
# surveyverse hex stickers
# Packages needed: hexSticker, cowplot, showtext, ggplot2
#
# install.packages(c("hexSticker", "cowplot", "showtext", "ggplot2"))
#
# Each sticker assumes you have a PNG icon file in your working directory.
# Suggested free icon sources:
#   - https://www.flaticon.com
#   - https://thenounproject.com
#   - https://icons8.com
# Export icons as PNG with a transparent background at ~512x512px.
# =============================================================================

library(hexSticker)
library(cowplot)
library(showtext)
library(ggplot2)

# =============================================================================
# surveytidy
#    Icon suggestion: broom, magic wand, or sparkle/clean symbol
#    Search terms: "broom sweep", "cleaning broom", "magic wand sparkle"
# =============================================================================

icon_tidy <- ggdraw() + draw_image("man/figures/logo.png", scale = 1.25)

sticker(
  subplot = icon_tidy,
  package = "surveytidy",

  # ── Icon position & size ──────────────────────────────────────────────────
  s_x = 1,
  s_y = 0.72,
  s_width = 0.65,
  s_height = 0.65,

  # ── Package name ──────────────────────────────────────────────────────────
  p_color = "white",
  p_family = "Inter",
  p_size = 18,
  p_y = 1.43,

  # ── Hex background & border ───────────────────────────────────────────────
  h_fill = "#3399AA", # teal primary
  h_color = "#226677", # darker teal border

  # ── Optional URL at bottom ────────────────────────────────────────────────
  url = "github.com/you/surveytidy",
  u_color = "white",
  u_size = 3.5,

  # ── Output file ───────────────────────────────────────────────────────────
  filename = "surveytidy.png",
  dpi = 300
)
