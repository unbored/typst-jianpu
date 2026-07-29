#set page(width: 16cm, height: 10cm, margin: 1.5cm)
#set text(font: "Noto Serif CJK SC", size: 14pt)

#let music-symbol(glyph, size: 1em) = text(
  font: "Bravura Text",
  fallback: false,
  size: size,
)[#glyph]
#let numeral(value) = text(font: "Arial", weight: "bold")[#value]

// SMuFL code points remain explicit here so missing or substituted glyphs are
// immediately visible when the music font changes.
#let flat = "\u{e260}"
#let natural = "\u{e261}"
#let sharp = "\u{e262}"
#let double-sharp = "\u{e263}"
#let double-flat = "\u{e264}"
#let fermata-above = "\u{e4c0}"

#text(size: 1.4em, weight: "bold")[Bravura Text 符号测试]

与简谱数字混排：

#music-symbol(sharp)#h(0.08em)#numeral(1)
#h(0.8em)
#music-symbol(flat)#h(0.08em)#numeral(2)
#h(0.8em)
#music-symbol(natural)#h(0.08em)#numeral(3)
#h(0.8em)
#music-symbol(double-sharp)#h(0.08em)#numeral(4)
#h(0.8em)
#music-symbol(double-flat)#h(0.08em)#numeral(5)

#v(0.7em)

不同字号：

#music-symbol(sharp, size: 0.7em)#h(0.08em)#numeral(1)
#h(0.8em)
#music-symbol(sharp)#h(0.08em)#numeral(1)
#h(0.8em)
#music-symbol(sharp, size: 1.3em)#h(0.08em)#numeral(1)

#v(0.7em)

独立符号：#music-symbol(fermata-above, size: 1.4em)
