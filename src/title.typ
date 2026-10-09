// Score heading shared by full-page Jianpu examples.

#let key-accidental(source) = {
  if source.starts-with("#") or source.ends-with("#") { "sharp" }
  else if source.starts-with("b") or source.ends-with("b") { "flat" }
  else { none }
}

#let key-tonic-name(source, accidental) = {
  if accidental == none { source }
  else if source.starts-with("#") or source.starts-with("b") { source.slice(1) }
  else { source.slice(0, source.len() - 1) }
}

#let key-accidental-text(accidental) = {
  if accidental == "sharp" { "\u{e262}" }
  else if accidental == "flat" { "\u{e260}" }
  else { "" }
}

#let render-key-signature(degree, tonic-source) = {
  let accidental = key-accidental(tonic-source)
  let tonic = key-tonic-name(tonic-source, accidental)
  assert(degree.len() > 0 and tonic.len() > 0, message: "key fields must not be empty")
  assert(("A", "B", "C", "D", "E", "F", "G").contains(tonic), message: "key tonic must be an uppercase note name from A to G")
  // Keep the scale degree visually consistent with Jianpu numerals while the
  // equation sign and tonic retain a conventional bold serif appearance.
  // Jianpu convention places the accidental before the tonic (`1=♯C`); a
  // postfix ASCII input such as `1=C#` is accepted but normalized here.
  box[#text(font: "Arial", weight: "bold")[#degree]#h(0.25em)#text(font: "New Computer Modern", weight: "bold")[=]#h(0.25em)#if accidental != none { text(font: "Bravura Text", fallback: false, size: 1.4em)[#key-accidental-text(accidental)] }#text(font: "New Computer Modern", weight: "bold")[#tonic]]
}

#let render-key(source) = {
  assert(type(source) == str, message: "key must use a string such as \"1=C\"")
  let signatures = source.matches(regex("([0-9]+)\\s*=\\s*([#b][A-G]|[A-G][#b]?)"))
  let result = []
  let offset = 0
  for signature in signatures {
    result += [#source.slice(offset, signature.start)]
    result += render-key-signature(signature.captures.at(0), signature.captures.at(1))
    offset = signature.end
  }
  result + [#source.slice(offset)]
}

#let render-meter(source) = {
  assert(type(source) == str, message: "meter must use a string such as \"2/4\"")
  let parts = source.split("/")
  assert(parts.len() == 2, message: "meter must use numerator/denominator format")
  let numerator = int(parts.at(0))
  let denominator = int(parts.at(1))
  assert(numerator > 0 and denominator > 0, message: "meter values must be positive")
  let digit-count = calc.max(parts.at(0).len(), parts.at(1).len())
  let width = 1.4em + calc.max(digit-count - 1, 0) * 0.55em
  // A bounded box keeps display-style math at intrinsic metadata width rather
  // than letting the block equation consume the complete left grid column.
  box(width: width, math.equation(block: true, $bold(#numerator/#denominator)$))
}

#let render-title(
  title,
  subtitle: none,
  key: none,
  meter: none,
  authors: (),
  left: none,
  right: none,
) = {
  let headings = (
    text(size: 1.5em, weight: "bold")[#title],
  )
  if subtitle != none {
    headings.push(text(size: 1em, weight: "bold")[#subtitle])
  }

  let parts = (
    align(center)[
      #stack(dir: ttb, spacing: 0.75em, ..headings)
    ],
  )
  let signature-items = ()
  if key != none { signature-items.push(render-key(key)) }
  if meter != none { signature-items.push(render-meter(meter)) }
  let left-lines = ()
  if signature-items.len() > 0 {
    left-lines.push(grid(
      columns: signature-items.len(),
      column-gutter: 0.7em,
      align: horizon,
      ..signature-items,
    ))
  }
  if left != none { left-lines.push([#left]) }
  let author-lines = ()
  for author in authors {
    author-lines.push([#author.name #h(0.35em) #author.role])
  }

  if right != none { author-lines.push([#right]) }

  if left-lines.len() > 0 or author-lines.len() > 0 {
    // Semantic metadata stays internally mapped to the conventional layout:
    // key/meter on the left, contributor names and roles on the right.
    parts.push(grid(
      columns: (1fr, 1fr),
      gutter: 1em,
      align: (top + start, top + end),
      if left-lines.len() == 0 {
        []
      } else {
        stack(dir: ttb, spacing: 0.35em, ..left-lines)
      },
      if author-lines.len() == 0 {
        []
      } else {
        stack(dir: ttb, spacing: 0.35em, ..author-lines)
      },
    ))
  }

  block(width: 100%)[
    #stack(dir: ttb, spacing: 1em, ..parts)
  ]
}
