// Score heading shared by full-page Jianpu examples.

#let render-key(source) = {
  assert(type(source) == str, message: "key must use a string such as \"1=C\"")
  let parts = source.split("=")
  assert(parts.len() == 2, message: "key must use degree=tonic format")
  let degree = parts.at(0)
  let tonic = parts.at(1)
  assert(degree.len() > 0 and tonic.len() > 0, message: "key fields must not be empty")
  // Keep the scale degree visually consistent with Jianpu numerals while the
  // equation sign and tonic retain a conventional bold serif appearance.
  box[#text(font: "Arial", weight: "bold")[#degree]#text(font: "New Computer Modern", weight: "bold")[=#tonic]]
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
  let author-lines = ()
  for author in authors {
    author-lines.push([#author.name #h(0.35em) #author.role])
  }

  if signature-items.len() > 0 or author-lines.len() > 0 {
    // Semantic metadata stays internally mapped to the conventional layout:
    // key/meter on the left, contributor names and roles on the right.
    parts.push(grid(
      columns: (1fr, 1fr),
      gutter: 1em,
      align: (top + start, top + end),
      if signature-items.len() == 0 {
        []
      } else {
        // A one-row grid can center cells vertically, making the meter's
        // fraction bar align with the optical middle of the key signature.
        grid(
          columns: signature-items.len(),
          column-gutter: 0.7em,
          align: horizon,
          ..signature-items,
        )
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
