#import "src/parser.typ": *
#import "src/geometry.typ": metrics

#let note-text(note) = {
  // The rendered head is currently the first character. Suffixes are parsed
  // as attributes and intentionally not shown yet.
  note.raw.at(0)
}

#let is-extension-note(note) = {
  note.raw.at(0) == "-"
}

#let extension-line(length: 0.72em, thickness: 0.08em) = {
  // Do not use the font's hyphen/minus glyph for extension notes: it is too
  // short and sits on the text baseline. Keep the drawn rule out of layout:
  // otherwise a measure containing `-` gets a different vertical baseline.
  box(width: length, height: 0pt)[
    #place(horizon, dy: 0.42em)[
      #line(length: 100%, stroke: thickness)
    ]
  ]
}

#let chord-note-step(note-head-width) = {
  note-head-width * 1.45
}

#let chord-dot-radius(note-head-width) = {
  note-head-width * 0.11
}

#let chord-dot-gap(note-head-width) = {
  note-head-width * 0.17
}

#let chord-dot-offset(note-head-width) = {
  // Match the ordinary note-to-octave-dot clearance, which is set by the
  // vertical gap between the note row and the upper-dot row.
  note-head-width * 0.23
}

#let chord-octave-dots(count, note-head-width) = {
  let radius = chord-dot-radius(note-head-width)
  let gap = chord-dot-gap(note-head-width)
  let diameter = radius * 2
  let height = if count <= 0 { 0pt } else { count * diameter + (count - 1) * gap }

  box(width: diameter, height: height)[
    #for index in range(0, count) {
      place(top, dy: index * (diameter + gap))[
        #circle(radius: radius, fill: black)
      ]
    }
  ]
}

#let chord-octave-dots-height(count, note-head-width) = {
  let radius = chord-dot-radius(note-head-width)
  let gap = chord-dot-gap(note-head-width)
  if count <= 0 { 0pt } else { count * radius * 2 + (count - 1) * gap }
}

#let chord-lower-clearance(member, note-head-width) = {
  if member.octave-down > 0 {
    chord-octave-dots-height(member.octave-down, note-head-width) + chord-dot-offset(note-head-width)
  } else {
    0pt
  }
}

#let chord-upper-clearance(member, note-head-width) = {
  if member.octave-up > 0 {
    chord-octave-dots-height(member.octave-up, note-head-width) + chord-dot-offset(note-head-width)
  } else {
    0pt
  }
}

#let chord-member-offset(note, index, note-head-width) = {
  let offset = 0pt
  // A member's lower dots occupy the space toward the member below it.
  // Its upper dots occupy the space toward the member above it. Include both
  // sides of every layer boundary while walking upward through the chord.
  for member-index in range(1, index + 1) {
    let below-member = note.members.at(member-index - 1)
    let member = note.members.at(member-index)
    offset += chord-note-step(note-head-width) + chord-upper-clearance(below-member, note-head-width) + chord-lower-clearance(member, note-head-width)
  }
  offset
}

#let chord-upper-height(note, note-head-width) = {
  if note.kind == "chord" {
    let height = 0pt
    for (index, member) in note.members.enumerate() {
      if index > 0 {
        let dot-height = chord-octave-dots-height(member.octave-up, note-head-width)
        height = calc.max(
          height,
          chord-member-offset(note, index, note-head-width) + dot-height + if dot-height > 0pt { chord-dot-offset(note-head-width) } else { 0pt },
        )
      }
    }
    height
  } else {
    0pt
  }
}

#let chord-member-head(member, note-head-width) = {
  box(width: note-head-width)[
    #align(center)[#note-text(member)]
    #if member.octave-up > 0 {
      place(top, dy: -chord-octave-dots-height(member.octave-up, note-head-width) - chord-dot-offset(note-head-width))[
        #box(width: note-head-width, align(center)[
          #chord-octave-dots(member.octave-up, note-head-width)
        ])
      ]
    }
    #if member.octave-down > 0 {
      place(bottom, dy: chord-lower-clearance(member, note-head-width))[
        #box(width: note-head-width, align(center)[
          #chord-octave-dots(member.octave-down, note-head-width)
        ])
      ]
    }
  ]
}

#let chord-head(note, note-head-width: 12pt) = {
  let root = note.members.at(0)
  box(width: note-head-width)[
    #align(center)[#note-text(root)]
    #for index in range(1, note.members.len()) {
      place(top, dy: -chord-member-offset(note, index, note-head-width))[
        #chord-member-head(note.members.at(index), note-head-width)
      ]
    }
  ]
}

#let note-head(note, note-head-width: 12pt) = {
  box(width: note-head-width, align(center)[
    #if note.kind == "chord" {
      chord-head(note, note-head-width: note-head-width)
    } else if is-extension-note(note) {
      extension-line()
    } else {
      note-text(note)
    }
  ])
}

#let beam-line(length: 0.7em, thickness: 0.8pt) = {
  line(length: length, stroke: thickness)
}

#let octave-dots(count, dot-radius: 0.7pt, dot-gap: 0.6pt) = {
  let dot-diameter = dot-radius * 2
  let height = if count <= 0 {
    0pt
  } else {
    count * dot-diameter + (count - 1) * dot-gap
  }

  // Lower octave dots are painted in a zero-height overlay. `stack` may
  // stretch there according to its surrounding measure, so place every dot
  // at an explicit offset to keep their vertical spacing invariant.
  box(width: dot-diameter, height: height)[
    #for index in range(0, count) {
      place(top, dy: index * (dot-diameter + dot-gap))[
        #circle(radius: dot-radius, fill: black)
      ]
    }
  ]
}

#let octave-dots-height(count, dot-radius: 0.7pt, dot-gap: 0.6pt) = {
  if count <= 0 {
    0pt
  } else {
    count * dot-radius * 2 + (count - 1) * dot-gap
  }
}

#let max-octave-up(measure) = {
  let count = 0
  for note in measure.notes {
    count = calc.max(count, note.octave-up)
  }
  count
}

#let row-max-octave-up(row) = {
  let count = 0
  for measure in row {
    count = calc.max(count, max-octave-up(measure))
  }
  count
}

#let row-max-chord-upper-height(row, note-head-width) = {
  let height = 0pt
  for measure in row {
    for note in measure.notes {
      height = calc.max(height, chord-upper-height(note, note-head-width))
    }
  }
  height
}

#let chord-digit-height(note, note-head-width) = {
  if note.kind == "chord" {
    chord-member-offset(note, note.members.len() - 1, note-head-width)
  } else {
    0pt
  }
}

#let row-max-chord-digit-height(row, note-head-width) = {
  let height = 0pt
  for measure in row {
    for note in measure.notes {
      height = calc.max(height, chord-digit-height(note, note-head-width))
    }
  }
  height
}

#let has-beam-level(measure, level) = {
  for note in measure.notes {
    if note.beams >= level {
      return true
    }
  }
  false
}

#let has-lower-dots(measure, beams) = {
  for note in measure.notes {
    if note.beams == beams and note.octave-down > 0 {
      return true
    }
  }
  false
}

#let max-octave-down(measure) = {
  let count = 0
  for note in measure.notes {
    count = calc.max(count, note.octave-down)
  }
  count
}

#let octave-dot-slot(count, width, height: auto, valign: top, dot-radius: 0.7pt, dot-gap: 0.6pt) = {
  let body = align(center)[#octave-dots(count, dot-radius: dot-radius, dot-gap: dot-gap)]
  let actual-height = if height == auto {
    octave-dots-height(count, dot-radius: dot-radius, dot-gap: dot-gap)
  } else {
    height
  }

  box(width: width, height: actual-height, align(center + if valign == bottom { bottom } else { top })[#body])
}

#let measure-min-width(measure, bar-width: 5pt, bar-gap: 6pt) = {
  let width = 0pt

  for note in measure.notes {
    width += note.min-width
  }

  if measure.bar {
    width += bar-gap + bar-width
  }

  width
}

#let row-min-width(row, min-measure-gap: 14pt, bar-width: 5pt, bar-gap: 6pt) = {
  let width = 0pt

  for (index, measure) in row.enumerate() {
    width += measure-min-width(measure, bar-width: bar-width, bar-gap: bar-gap)
    if index < row.len() - 1 {
      width += min-measure-gap
    }
  }

  width
}

#let wrap-measures(
  measures,
  line-width,
  first-line-width: none,
  min-measure-gap: 14pt,
  bar-width: 5pt,
  bar-gap: 6pt,
) = {
  let rows = ()
  let current = ()
  let actual-first-line-width = if first-line-width == none {
    line-width
  } else {
    first-line-width
  }

  for measure in measures {
    let available-width = if rows.len() == 0 {
      actual-first-line-width
    } else {
      line-width
    }
    let candidate = current + (measure,)
    let candidate-width = row-min-width(
      candidate,
      min-measure-gap: min-measure-gap,
      bar-width: bar-width,
      bar-gap: bar-gap,
    )

    // Only break between measures. If the candidate row would exceed the
    // available line width, commit the previous row first.
    if current.len() > 0 and candidate-width > available-width {
      rows.push(current)
      current = (measure,)
    } else {
      current = candidate
    }
  }

  if current.len() > 0 {
    rows.push(current)
  }

  rows
}

#let row-note-count(row) = {
  let count = 0
  for measure in row {
    count += measure.notes.len()
  }
  count
}

#let note-gaps-from-extra(measure, extra-note-gap) = {
  let gaps = ()
  for _ in range(0, calc.max(measure.notes.len() - 1, 0)) {
    gaps.push(extra-note-gap)
  }
  gaps
}

#let zero-note-gaps(measure) = {
  note-gaps-from-extra(measure, 0pt)
}

#let note-gap-at(note-gaps, index) = {
  if index < note-gaps.len() {
    note-gaps.at(index)
  } else {
    0pt
  }
}

#let measure-side-gaps(leading-gap, bar-gap, has-bar) = {
  if has-bar {
    let side-gap = (leading-gap + bar-gap) / 2
    (leading: side-gap, trailing: side-gap)
  } else {
    (leading: leading-gap, trailing: 0pt)
  }
}

#let measure-bar-line(width, height, top-offset, stroke) = {
  // The bar line reaches the row's highest chord note-head, while its lower
  // end stays at the ordinary note-head height. Octave dots and beam lines do
  // not lengthen it. It is an overlay so it cannot alter layout.
  box(width: width, height: 0pt)[
    #place(top, dy: -top-offset)[
      #box(width: width, align(center)[
        #line(length: height, angle: 90deg, stroke: stroke)
      ])
    ]
  ]
}

#let render-note-row(
  measure,
  extra-note-gap: 0pt,
  note-gaps: none,
  leading-gap: 0pt,
  trailing-bar-gap: 6pt,
  bar-width: 5pt,
  bar-gap: 6pt,
  note-head-width: 12pt,
  bar-height: 16pt,
  bar-top-offset: 0pt,
) = {
  let columns = ()
  let cells = ()
  let actual-note-gaps = if note-gaps == none {
    note-gaps-from-extra(measure, extra-note-gap)
  } else {
    note-gaps
  }

  if leading-gap > 0pt {
    columns.push(leading-gap)
    cells.push([])
  }

  for (index, note) in measure.notes.enumerate() {
    columns.push(note.min-width)
    cells.push(box(width: note.min-width)[
      #align(center)[#note-head(note, note-head-width: note-head-width)]
    ])

    if index < measure.notes.len() - 1 {
      columns.push(note-gap-at(actual-note-gaps, index))
      cells.push([])
    }
  }

  if measure.bar {
    columns.push(trailing-bar-gap)
    cells.push([])
    columns.push(bar-width)
    cells.push(measure-bar-line(
      bar-width,
      bar-height,
      bar-top-offset,
      bar-width * 0.22,
    ))
  }

  box[
    #grid(columns: columns, gutter: 0pt, ..cells)
  ]
}

#let render-upper-dot-row(
  measure,
  extra-note-gap: 0pt,
  note-gaps: none,
  leading-gap: 0pt,
  trailing-bar-gap: 6pt,
  bar-width: 5pt,
  bar-gap: 6pt,
  note-head-width: 12pt,
  dot-radius: 0.7pt,
  dot-gap: 0.6pt,
  slot-height: auto,
) = {
  let columns = ()
  let cells = ()
  let actual-slot-height = if slot-height == auto {
    octave-dots-height(max-octave-up(measure), dot-radius: dot-radius, dot-gap: dot-gap)
  } else {
    slot-height
  }
  let actual-note-gaps = if note-gaps == none {
    note-gaps-from-extra(measure, extra-note-gap)
  } else {
    note-gaps
  }

  if leading-gap > 0pt {
    columns.push(leading-gap)
    cells.push([])
  }

  for (index, note) in measure.notes.enumerate() {
    columns.push(note.min-width)
    cells.push(box(width: note.min-width)[
      #align(center)[
        #octave-dot-slot(
          note.octave-up,
          note-head-width,
          height: actual-slot-height,
          valign: bottom,
          dot-radius: dot-radius,
          dot-gap: dot-gap,
        )
      ]
    ])

    if index < measure.notes.len() - 1 {
      columns.push(note-gap-at(actual-note-gaps, index))
      cells.push([])
    }
  }

  if measure.bar {
    columns.push(trailing-bar-gap + bar-width)
    cells.push([])
  }

  box[
    #grid(columns: columns, gutter: 0pt, ..cells)
  ]
}

#let beam-group-width(measure, start, end, extra-note-gap: 0pt, note-gaps: none) = {
  let width = 0pt
  let actual-note-gaps = if note-gaps == none {
    note-gaps-from-extra(measure, extra-note-gap)
  } else {
    note-gaps
  }

  for index in range(start, end + 1) {
    width += measure.notes.at(index).min-width
    if index < end {
      width += note-gap-at(actual-note-gaps, index)
    }
  }
  width
}

#let render-beam-row(
  measure,
  level,
  extra-note-gap: 0pt,
  note-gaps: none,
  leading-gap: 0pt,
  trailing-bar-gap: 6pt,
  bar-width: 5pt,
  bar-gap: 6pt,
  beam-note-width: 12pt,
  beam-thickness: 0.8pt,
) = {
  let index = 0
  let count = measure.notes.len()
  let columns = ()
  let cells = ()
  let actual-note-gaps = if note-gaps == none {
    note-gaps-from-extra(measure, extra-note-gap)
  } else {
    note-gaps
  }

  if leading-gap > 0pt {
    columns.push(leading-gap)
    cells.push([])
  }

  while index < count {
    let note = measure.notes.at(index)

    if note.beams >= level {
      let start = index
      let end = index
      while end + 1 < count and measure.notes.at(end + 1).beams >= level {
        end += 1
      }

      // Draw one whole beam per continuous group at this beam level. Do not
      // split it per note/gap cell: that creates visible seams and y-offsets.
      let full-width = beam-group-width(measure, start, end, extra-note-gap: extra-note-gap, note-gaps: actual-note-gaps)
      // Note heads are centered in their duration boxes, so beams are clipped
      // to the centered note-head slots instead of the full duration boxes.
      let first-inset = calc.max((measure.notes.at(start).min-width - beam-note-width) / 2, 0pt)
      let last-inset = calc.max((measure.notes.at(end).min-width - beam-note-width) / 2, 0pt)
      let line-width = calc.max(full-width - first-inset - last-inset, beam-note-width)

      columns.push(first-inset)
      cells.push([])
      columns.push(line-width)
      cells.push(beam-line(length: 100%, thickness: beam-thickness))
      columns.push(last-inset)
      cells.push([])

      index = end + 1
    } else {
      columns.push(note.min-width)
      cells.push([])
      index += 1
    }

    if index < count {
      columns.push(note-gap-at(actual-note-gaps, index - 1))
      cells.push([])
    }
  }

  if measure.bar {
    columns.push(trailing-bar-gap + bar-width)
    cells.push([])
  }

  box[
    #grid(columns: columns, gutter: 0pt, ..cells)
  ]
}

#let render-lower-dot-row(
  measure,
  for-beams,
  extra-note-gap: 0pt,
  note-gaps: none,
  leading-gap: 0pt,
  trailing-bar-gap: 6pt,
  bar-width: 5pt,
  bar-gap: 6pt,
  note-head-width: 12pt,
  dot-radius: 0.7pt,
  dot-gap: 0.6pt,
) = {
  let columns = ()
  let cells = ()
  let actual-note-gaps = if note-gaps == none {
    note-gaps-from-extra(measure, extra-note-gap)
  } else {
    note-gaps
  }

  if leading-gap > 0pt {
    columns.push(leading-gap)
    cells.push([])
  }

  for (index, note) in measure.notes.enumerate() {
    columns.push(note.min-width)
    cells.push(box(width: note.min-width)[
      #align(center)[
        #octave-dot-slot(
          if note.beams == for-beams { note.octave-down } else { 0 },
          note-head-width,
          valign: top,
          dot-radius: dot-radius,
          dot-gap: dot-gap,
        )
      ]
    ])

    if index < measure.notes.len() - 1 {
      columns.push(note-gap-at(actual-note-gaps, index))
      cells.push([])
    }
  }

  if measure.bar {
    columns.push(trailing-bar-gap + bar-width)
    cells.push([])
  }

  // Lower octave dots belong to the note's own duration depth. They must not
  // reserve a full row that pushes deeper beam lines away from the digits.
  // The surrounding stack spacing determines the fixed distance from the
  // current digit/beam line; this zero-height box only paints the dots there.
  box(height: 0pt)[
    #grid(columns: columns, gutter: 0pt, ..cells)
  ]
}

#let render-layer-with-lower-dots(main, lower-dots: none, lower-offset: 2pt) = {
  if lower-dots == none {
    main
  } else {
    // Lower dots are visually tied to the digit/beam layer immediately above.
    // Keep them out of the outer vertical stack, otherwise even zero-height
    // boxes still introduce stack spacing and push deeper beam lines away.
    stack(dir: ttb, spacing: 0pt,
      main,
      box(height: 0pt)[#move(dy: lower-offset)[#lower-dots]],
    )
  }
}

#let render-measure(
  measure,
  extra-note-gap: 0pt,
  note-gaps: none,
  leading-gap: 0pt,
  bar-width: 5pt,
  bar-gap: 6pt,
  beam-gap: 2pt,
  beam-note-width: 12pt,
  beam-thickness: 0.8pt,
  dot-radius: 0.7pt,
  dot-gap: 0.6pt,
  upper-dot-height: 0pt,
  bar-height: 16pt,
  bar-top-offset: 0pt,
) = {
  let parts = ()
  let actual-note-gaps = if note-gaps == none {
    note-gaps-from-extra(measure, extra-note-gap)
  } else {
    note-gaps
  }
  let side-gaps = measure-side-gaps(leading-gap, bar-gap, measure.bar)
  let lower-dot-reserve = if max-octave-down(measure) > 0 {
    beam-gap + octave-dots-height(max-octave-down(measure), dot-radius: dot-radius, dot-gap: dot-gap)
  } else {
    0pt
  }

  if upper-dot-height > 0pt {
    parts.push(render-upper-dot-row(
      measure,
      extra-note-gap: extra-note-gap,
      note-gaps: actual-note-gaps,
      leading-gap: side-gaps.leading,
      trailing-bar-gap: side-gaps.trailing,
      bar-width: bar-width,
      bar-gap: bar-gap,
      note-head-width: beam-note-width,
      dot-radius: dot-radius,
      dot-gap: dot-gap,
      slot-height: upper-dot-height,
    ))
  }

  parts.push(render-layer-with-lower-dots(
    render-note-row(measure, extra-note-gap: extra-note-gap, note-gaps: actual-note-gaps, leading-gap: side-gaps.leading, trailing-bar-gap: side-gaps.trailing, bar-width: bar-width, bar-gap: bar-gap, note-head-width: beam-note-width, bar-height: bar-height, bar-top-offset: bar-top-offset),
    lower-dots: if has-lower-dots(measure, 0) {
      render-lower-dot-row(measure, 0, extra-note-gap: extra-note-gap, note-gaps: actual-note-gaps, leading-gap: side-gaps.leading, trailing-bar-gap: side-gaps.trailing, bar-width: bar-width, bar-gap: bar-gap, note-head-width: beam-note-width, dot-radius: dot-radius, dot-gap: dot-gap)
    } else {
      none
    },
    lower-offset: beam-gap,
  ))

  for level in range(1, 4) {
    if has-beam-level(measure, level) {
      parts.push(render-layer-with-lower-dots(
        render-beam-row(measure, level, extra-note-gap: extra-note-gap, note-gaps: actual-note-gaps, leading-gap: side-gaps.leading, trailing-bar-gap: side-gaps.trailing, bar-width: bar-width, bar-gap: bar-gap, beam-note-width: beam-note-width, beam-thickness: beam-thickness),
        lower-dots: if has-lower-dots(measure, level) {
          render-lower-dot-row(measure, level, extra-note-gap: extra-note-gap, note-gaps: actual-note-gaps, leading-gap: side-gaps.leading, trailing-bar-gap: side-gaps.trailing, bar-width: bar-width, bar-gap: bar-gap, note-head-width: beam-note-width, dot-radius: dot-radius, dot-gap: dot-gap)
        } else {
          none
        },
        lower-offset: beam-gap,
      ))
    }
  }

  box[
    #pad(bottom: lower-dot-reserve)[
      #stack(dir: ttb, spacing: beam-gap,
        ..parts,
      )
    ]
  ]
}

#let render-row(
  row,
  line-width,
  min-measure-gap: 14pt,
  bar-width: 5pt,
  bar-gap: 6pt,
  beam-gap: 2pt,
  beam-note-width: 12pt,
  beam-thickness: 0.8pt,
  dot-radius: 0.7pt,
  dot-gap: 0.6pt,
  justify: true,
) = {
  let min-width = row-min-width(row, min-measure-gap: min-measure-gap, bar-width: bar-width, bar-gap: bar-gap)
  let inner-gap-count = calc.max(row-note-count(row) - row.len(), 0)
  let measure-gap-count = calc.max(row.len() - 1, 0)
  let gap-count = inner-gap-count + measure-gap-count
  // Row justification first allocates extra width to each measure and to each
  // measure boundary. Each measure then converts its allocated width into
  // variable note gaps so note heads are evenly spaced inside that measure.
  let extra-gap = if justify and gap-count > 0 {
    (line-width - min-width) / gap-count
  } else {
    0pt
  }
  let columns = ()
  let cells = ()
  let upper-dot-height = calc.max(
    octave-dots-height(row-max-octave-up(row), dot-radius: dot-radius, dot-gap: dot-gap),
    row-max-chord-upper-height(row, beam-note-width),
  )
  let bar-lower-extension = beam-note-width * 0.30
  let bar-upper-extension = bar-lower-extension * 1.5
  let bar-top-offset = row-max-chord-digit-height(row, beam-note-width) + bar-upper-extension
  let bar-note-height = beam-note-width
  let bar-height = bar-top-offset + bar-note-height + bar-lower-extension

  for (index, measure) in row.enumerate() {
    let leading-gap = if index == 0 {
      0pt
    } else {
      min-measure-gap + extra-gap
    }
    let measure-width = measure-min-width(measure, bar-width: bar-width, bar-gap: bar-gap) + extra-gap * calc.max(measure.notes.len() - 1, 0)
    let note-gaps = note-gaps-from-extra(measure, extra-gap)

    columns.push(leading-gap + measure-width)
    cells.push(render-measure(
      measure,
      extra-note-gap: extra-gap,
      note-gaps: note-gaps,
      leading-gap: leading-gap,
      bar-width: bar-width,
      bar-gap: bar-gap,
      beam-gap: beam-gap,
      beam-note-width: beam-note-width,
      beam-thickness: beam-thickness,
      dot-radius: dot-radius,
      dot-gap: dot-gap,
      upper-dot-height: upper-dot-height,
      bar-height: bar-height,
      bar-top-offset: bar-top-offset,
    ))
  }

  block(width: 100%)[
    #grid(columns: columns, gutter: 0pt, ..cells)
  ]
}

#let render-track(
  track,
  line-width,
  min-measure-gap,
  bar-width,
  bar-gap,
  beam-gap,
  beam-note-width,
  beam-thickness,
  dot-radius,
  dot-gap,
  row-gap,
  justify: true,
  justify-last: false,
  first-indent: 0pt,
) = {
  let first-line-width = calc.max(line-width - first-indent, beam-note-width)

  // Current limitation: every melody track wraps independently. Future
  // multi-voice support should lift wrapping to score/system level so all
  // tracks share the same measure ranges per system.
  let rows = wrap-measures(
    track.measures,
    line-width,
    first-line-width: first-line-width,
    min-measure-gap: min-measure-gap,
    bar-width: bar-width,
    bar-gap: bar-gap,
  )

  stack(dir: ttb, spacing: row-gap,
    ..rows.enumerate().map(((index, row)) => {
      let row-line-width = if index == 0 {
        first-line-width
      } else {
        line-width
      }
      let row-content = render-row(
        row,
        row-line-width,
        min-measure-gap: min-measure-gap,
        bar-width: bar-width,
        bar-gap: bar-gap,
        beam-gap: beam-gap,
        beam-note-width: beam-note-width,
        beam-thickness: beam-thickness,
        dot-radius: dot-radius,
        dot-gap: dot-gap,
        justify: justify and (justify-last or index < rows.len() - 1),
      )

      if index == 0 and first-indent > 0pt {
        grid(columns: (first-indent, row-line-width), gutter: 0pt, [], row-content)
      } else {
        row-content
      }
    }),
  )
}

#let jianpu(
  ..groups,
  font: "Arial",
  size: 12pt,
  sort-chords: true,
  justify: true,
  justify-last: false,
  first-indent: 24pt,
) = {
  set text(font: font, size: size, weight: "bold")

  // Internal geometry stays private even though its calculation now lives in
  // a dedicated module.
  let geometry = metrics(size)
  let score = parse-score(
    groups.pos(),
    geometry.quarter-width,
    geometry.eighth-width,
    geometry.short-width,
    sort-chords,
  )
  let melody-tracks = score.tracks.filter(track => track.kind == "melody")

  layout(available => {
    // For now, multiple melody tracks are rendered one after another. This is
    // deliberate: the parser already has score/tracks, but system-level
    // alignment across tracks is not implemented yet.
    stack(dir: ttb, spacing: geometry.group-gap,
      ..melody-tracks.map(track => {
        render-track(
          track,
          available.width,
          geometry.min-measure-gap,
          geometry.bar-width,
          geometry.bar-gap,
          geometry.beam-gap,
          geometry.beam-note-width,
          geometry.beam-thickness,
          geometry.dot-radius,
          geometry.dot-gap,
          geometry.row-gap,
          justify: justify,
          justify-last: justify-last,
          first-indent: first-indent,
        )
      }),
    )
  })
}
