---
layout: post
title: Visual accessibility in source-code editors
blurb: How the choice of colorscheme in programming affects productivity and perception.
license: true
tags: [productivity, accessibility, colorscheme]
---

The theme of perceptual readability in software development environments has
been dear to my heart for over a decade. Accessibility topics around visual
presentation are commonly associated with UI design, particularly in web
development. It may at first feel like an odd idea to be willing to explore
visual accessibility practices in the context of source code editing, but are
these two disciplines truly divergent?

My interest in this topic started with [Solarized][1], a precision colorscheme
with selective contrast relationships between its colors. Its design decisions
made me realize how most developers pick a colorscheme based on criteria solely
related to aesthetics: bright and abundant colors, hard contrasts between the
text and background, theming of the text based on UI elements instead of
semantics, etc. It is hard to blame them, the colorschemes that come bundled
with modern IDEs were designed to look immediately appealing and make the tool
marketable.

As programmers, we should instead give priority to visual features that promote
the legibility of the source code through the lens of our text editor. In this
post, I will share my views on the visual components which contribute to
productivity and accessibility in editing and navigating source code. Some of
them are backed by research, while others remain rather empirical.

<figure>
  <!-- © Ahmad Awais — https://github.com/ahmadawais/shades-of-purple-vscode -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/vscode-shadesofpurple.png" | relative_url }}" alt="VSCode Shades of Purple theme">
  <figcaption>The Visual Studio Code Marketplace doesn't come short of bright and colorful editor themes.</figcaption>
</figure>

## Contrasts

In the context of this post, contrast refers to the difference in color on a
self-illuminated display of characters against either a background of a
different color, or against other characters of a different color.

Thanks to the World Wide Web Consortium (W3C), there exist well specified
requirements for making digital content visually accessible, especially to
people with disabilities such as color vision deficiencies: the [W3C
Accessibility Guidelines][2] (WCAG). The WCAG 2.x [contrast specification][3]
in particular mandates that text should have a certain contrast ratio to
achieve the highest standard of accessibility (AAA).

Some colorschemes were designed specifically to conform to the WCAG 2.x
contrast guidelines. Possibly the most prominent one is [Modus][4], but if you
navigate source code on GitHub through a web browser, you will also be looking
at some syntax highlighting that meets the [most common WCAG 2.x standards][5]
(AA).

<figure>
  <!-- © Protesilaos Stavrou — https://protesilaos.com/emacs/modus-themes -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/emacs-modus.png" | relative_url }}" alt="Modus Operandi theme in Emacs">
  <figcaption>Colorscheme conforming to the highest WCAG 2.x standard for color contrast.</figcaption>
</figure>

However, the WCAG contrast specification is not without flaws. Since WCAG 2.x
came about in 2005, before modern technologies like smartphones, it doesn't
account for the different needs between light and dark modes. More
specifically, some contrasts which aren't perceptually uniform to humans pass
WCAG 2.x conformance tests in dark color ranges improperly, making the standard
unreliable for determining whether text is readable on a dark background. This
aspect is particularly relevant in the context of text editors, which are often
set up with dark backgrounds for programming to reduce visual fatigue. The
issues of the WCAG 2.x contrast success criterion are [well known][6], and
currently being addressed by the [APCA Readability Criterion][7] (ARC)[^1].

While a high contrast between the characters printed on the screen and their
background can certainly make the text more legible to people with visual
disabilities, it also has a high potential for causing eye strain over extended
periods of time. Resources on accessible contrast sometimes refer to the
experience of reading on paper to illustrate the phenomenon: in normal lighting
conditions, dark text on a page of paper has a contrast ratio that is much
lower than pure black on white on a computer monitor, which is why reading a
book isn't as strenuous[^2].

Conversely, even the most colorful of syntax highlights can work without
causing fatigue if foreground and background colors complement each other in a
soft contrast.

<figure>
  <!-- © Sainnhe Park — https://github.com/sainnhe/everforest -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/vim-everforest.png" | relative_url }}" alt="Everforest Dark Medium theme in Vim">
  <figcaption>A reduced brightness contrast can prevent eye strain over extended periods of time.</figcaption>
</figure>

<figure>
  <!-- © Blaž Hrastnik — https://github.com/helix-editor/helix -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/helix-colibri.png" | relative_url }}" alt="Colibri theme in Helix">
  <figcaption>Subtle contrasts between syntax elements can turn a colorful background into a valid proposition.</figcaption>
</figure>

## Color Space

A [color space][12] is an organisation of colors represented by numeric
coordinates, such as `red,green,blue` in the sRGB color space,
`cyan,magenta,yellow,key` in the CMYK color space, or `L*a*b*` in the CIELAB
color space just to name a few.

Perceptually uniform colors are important for accessibility in the same way
that perceptually uniform contrasts are: they match the way humans perceive
colors. A color space achieves uniformity when numerical differences in
coordinates represent equivalent visual differences, regardless of the location
within the color space[^3]. While there exists no color space that is perfectly
uniform, there are models which provide a satisfying level of perceptual
uniformity overall.

Color theory is a complex body of knowledge, however the notion of perceptual
uniformity should be easy to grasp by comparing the following color gradients of the
[HSV][14] representation of sRGB to the [Oklab][15] perceptual color space:

<figure>
  <!-- © Björn Ottosson — https://bottosson.github.io/posts/oklab -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/hue_hsv.png" | relative_url }}" alt="HSV hue">
  <figcaption>HSV color gradient with varying hue and constant value and saturation.</figcaption>
</figure>
<figure>
  <!-- © Björn Ottosson — https://bottosson.github.io/posts/oklab/ -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/hue_oklab.png" | relative_url }}" alt="Oklab hue">
  <figcaption>Oklab color gradient with varying hue and constant lightness and chroma.</figcaption>
</figure>

The are clear differences in lightness for different hues in the HSV color
gradient above, which cause yellow, magenta, and cyan to appear much lighter
than red and blue. On the other hand, all colors in the Oklab gradient appear
with even lightness to the human eye.

This property, when applied to syntax highlighting in a text editor, is what
makes certain keywords appear with the same relative importance to the person
sitting behind the screen in spite of being highlighted in different colors.

<figure>
  <!-- © Ethan Schoonover — https://ethanschoonover.com/solarized/ -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/vim-solarized.png" | relative_url }}" alt="Solarized Dark theme in Vim">
  <figcaption>Accent colors have a uniform perceived lightness.</figcaption>
</figure>

## Highlight Semantics

I touched on the topic of visual _uniformity_ in previous sections of this
post. There are multiple cases in source code editing where productivity and
accessibility can in fact be increased by leveraging _non-uniform_ visual cues.

Parts of the syntax in a body of source code are more critical than others to
the overall structure of a computer program. Although this topic is highly
subjective, I would argue that even an unfamiliar code base can be made more
legible by simply emphasizing three categories of syntax elements: control
flow, declarations and constants. Such emphasis can be conveyed through
variations in brightness and hue contrasts[^4], in reference to the practices
described throughout previous sections of this post, and according to personal
visual sensitivities.

The key takeaway here is that semantics trumps syntax when it comes to making
the structure of source code easy to identify through a text editor. By using
contrast variations, it is possible to create a visual hierarchy of syntax
elements that reduces cognitive load when reading and writing code.

<figure>
  <!-- © Ramojus Lapinskas — https://github.com/ramojus/mellifluous.nvim -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/vim-mellifluous.png" | relative_url }}" alt="Mellifluous theme in Vim">
  <figcaption>Control flow keywords have a strong highlight whereas punctuation is toned down.</figcaption>
</figure>

<figure>
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/vim-zenbones.png" | relative_url }}" alt="Zenbones theme in Vim">
  <figcaption>Emphasis on certain keywords can be conveyed through variations in contrast and font face instead of colors.</figcaption>
</figure>

## Font

So far I have been focusing on attributes related to colors. The last section
of this post alludes to typography and its influence on accessibility in
programming. Incidentally, the last picture from the previous section is the
perfect segue into my next point.

When it comes to contrast, larger and thicker characters are perceived with a
higher contrast than smaller and thinner ones due to their spacial attributes.
This is demonstrated below through side by side text comparisons at different
sizes and weights:

<figure>
  <!-- © Myndex Research — https://medium.com/@colleengratzer/how-apca-changes-accessible-contrast-with-andrew-somers-3d47627a5e16 -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/font-boldness.png" | relative_url }}" alt="Comparison of perceived contrast">
  <figcaption>The spacial (line thickness) influences the perceived contrast as the outline increases.</figcaption>
</figure>
<figure>
  <!-- © Myndex Research — https://medium.com/@colleengratzer/how-apca-changes-accessible-contrast-with-andrew-somers-3d47627a5e16 -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/font-contrast.png" | relative_url }}" alt="Comparison of font weight versus contrast">
  <figcaption>The lighter font face on the right side is compensated by a higher lightness contrast.</figcaption>
</figure>

To compensate for this perceived difference in contrast, both APCA and WCAG 2.x
recommend using a lower contrast ratio for large and bold elements like
headlines[^5]. One immediate consequence of these spacial characteristics is
that the perceived contrast for the same text may vary from one typeface to
another, for example due to varying character widths. To guarantee that
typefaces conform to standards for accessible contrasts, APCA/WCAG 3 makes
provision for comparing contrast calculations against these of reference
fonts[^5].

Furthermore, the choice of the typeface itself can affect the legibility of the
source code significantly beyond contrast considerations. A good typeface
should ensure that all characters are distinct and easy to identify in order to
facilitate the reading flow and avoid ambiguity. These general truths about
typography naturally apply to programming fonts.

<figure>
  <!-- © FaceType Foundry — https://www.monolisa.dev/ -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/monolisa.png" | relative_url }}" alt="Features of the MonoLisa typeface">
  <figcaption>A typeface with strong emphasis on character distinction and reading flow.</figcaption>
</figure>

## Closing Words

Despite thorough research in certain areas such as perceptual contrast, we have
very few tools for quantifying what makes source code syntax visually
accessible and productive. Objective improvements in perceptual readability are
difficult to measure and correlate with hierarchical syntax highlighting. We,
programmers, often base our judgement on empirical analysis for lack of better
approaches.

My conclusion, after experimenting extensively with different patterns of
syntax highlights, is that syntax should be highlighted sporadically and
subtly, but emphasize important keywords generously. This statement is very
subjective; what works for my own perception can in no way be conflated with
any kind of accessibility standard.

Don't shy away from trying new things in your text editor for extended periods
of times (days, weeks) with regards to syntax highlighting techniques and
typography. You might surprise yourself finding out that your eyes flow over
set ups which seemed unappealing at first: low colors, unusual color
combinations, usage of boldness, a font with certain geometries, etc.

And remember, a syntax highlighting scheme driven by surrounding UI elements
may be good for marketing, but it certainly isn't for your eyes.

<figure>
  <!-- © Zed Industries — https://zed.dev/ -->
  <img src="{{ "assets/img/content/2024-06-06-accessibility-source-editor/zed-atelierdune.png" | relative_url }}" alt="Atelier Dune Light theme in Zed">
  <figcaption>UI elements can remain distraction-free by deriving colors from syntax highlights.</figcaption>
</figure>

[^1]: APCA is the [Accessible Perceptual Contrast Algorithm][8]. It is the
    [candidate contrast method][9] for the future WCAG 3. The interview
    [How APCA Changes Accessible Contrast][10] with Andrew Somers is packed
    with captivating details on the topic of perceptually uniform contrast.

[^2]: On the idea of not using pure black or pure white in design:
    [Never Use Black][11].

[^3]: Source for the definition: [Color difference][13] (Wikipedia).

[^4]: For an illustrated explanation of hue contrasts, I recommend checking
    [Color Theory - Contrast of Hue][16].

[^5]: See [Visual Readability Contrast - Testing Criterion][17] (ARC). The
    reference fonts are mentioned under the _Font Lookup Tables_ title.

[1]: https://ethanschoonover.com/solarized/
[2]: https://www.w3.org/WAI/standards-guidelines/wcag/
[3]: https://www.w3.org/WAI/WCAG22/Understanding/contrast-enhanced.html
[4]: https://protesilaos.com/emacs/modus-themes
[5]: https://primer.style/foundations/color/accessibility
[6]: https://github.com/w3c/wcag/issues/695
[7]: https://readtech.org/ARC/
[8]: https://git.apcacontrast.com/
[9]: https://www.w3.org/WAI/GL/WCAG3/2021/how-tos/visual-contrast-of-text/
[10]: https://medium.com/@colleengratzer/how-apca-changes-accessible-contrast-with-andrew-somers-3d47627a5e16
[11]: https://ianstormtaylor.com/design-tip-never-use-black/
[12]: https://www.cambridgeincolour.com/tutorials/color-spaces.htm
[13]: https://en.wikipedia.org/wiki/Color_difference#Uniform_color_spaces
[14]: https://en.wikipedia.org/wiki/HSL_and_HSV
[15]:  https://bottosson.github.io/posts/oklab/
[16]: https://watercoloracademy.com/watercolor-lessons/color-theory-contrast-of-hue
[17]: https://readtech.org/ARC/tests/visual-readability-contrast/?tn=criterion#silver-level-conformance
