// Minimal Jianpu renderer.
//
// Current notation:
//   1      quarter note, minimum width 2em
//   1/     eighth note, minimum width 1.5em
//   1//    sixteenth note, minimum width 1em
//   1///   thirty-second note, minimum width 1em
//   |      measure boundary, the only allowed line-break position

#let duration-width(token, quarter-width: 36pt, eighth-width: 27pt, short-width: 18pt) = {
  // For the first prototype, "/" count determines duration. Other suffixes
  // can later be parsed into octave, dots, ties, ornaments, etc.
  if token.contains("///") {
    short-width
  } else if token.contains("//") {
    short-width
  } else if token.contains("/") {
    eighth-width
  } else {
    quarter-width
  }
}

#let slash-count(token) = {
  token.split("/").len() - 1
}

#let parse-note(token, quarter-width: 36pt, eighth-width: 27pt, short-width: 18pt) = {
  (
    raw: token,
    beams: slash-count(token),
    min-width: duration-width(
      token,
      quarter-width: quarter-width,
      eighth-width: eighth-width,
      short-width: short-width,
    ),
  )
}

#let parse-measures(tokens, quarter-width: 36pt, eighth-width: 27pt, short-width: 18pt) = {
  let measures = ()
  let current = ()

  for token in tokens {
    if token == "|" {
      measures.push((notes: current, bar: true))
      current = ()
    } else {
      current.push(parse-note(
        token,
        quarter-width: quarter-width,
        eighth-width: eighth-width,
        short-width: short-width,
      ))
    }
  }

  if current.len() > 0 {
    measures.push((notes: current, bar: false))
  }

  measures
}

#let note-text(note) = {
  // The rendered head is currently the first character. Suffixes are parsed
  // as attributes and intentionally not shown yet.
  note.raw.at(0)
}

#let beam-line(length: 0.7em, thickness: 0.8pt) = {
  line(length: length, stroke: thickness)
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

#let wrap-measures(measures, line-width, min-measure-gap: 14pt, bar-width: 5pt, bar-gap: 6pt) = {
  let rows = ()
  let current = ()

  for measure in measures {
    let candidate = current + (measure,)
    let candidate-width = row-min-width(
      candidate,
      min-measure-gap: min-measure-gap,
      bar-width: bar-width,
      bar-gap: bar-gap,
    )

    // Only break between measures. If the candidate row would exceed the
    // available line width, commit the previous row first.
    if current.len() > 0 and candidate-width > line-width {
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

#let render-note-row(
  measure,
  extra-note-gap: 0pt,
  bar-width: 5pt,
  bar-gap: 6pt,
  note-head-width: 12pt,
) = {
  let columns = ()
  let cells = ()

  for (index, note) in measure.notes.enumerate() {
    columns.push(note.min-width)
    cells.push(box(width: note.min-width)[
      #box(width: note-head-width, align(center)[#note-text(note)])
    ])

    if index < measure.notes.len() - 1 {
      columns.push(extra-note-gap)
      cells.push([])
    }
  }

  if measure.bar {
    columns.push(bar-gap)
    cells.push([])
    columns.push(bar-width)
    cells.push(align(center)[|])
  }

  box[
    #grid(columns: columns, gutter: 0pt, ..cells)
  ]
}

#let beam-group-width(measure, start, end, extra-note-gap: 0pt) = {
  let width = 0pt
  for index in range(start, end + 1) {
    width += measure.notes.at(index).min-width
    if index < end {
      width += extra-note-gap
    }
  }
  width
}

#let render-beam-row(
  measure,
  level,
  extra-note-gap: 0pt,
  bar-width: 5pt,
  bar-gap: 6pt,
  beam-note-width: 12pt,
  beam-thickness: 0.8pt,
) = {
  let index = 0
  let count = measure.notes.len()
  let columns = ()
  let cells = ()

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
      let full-width = beam-group-width(measure, start, end, extra-note-gap: extra-note-gap)
      // A note's digit marks the beginning of its duration box. Therefore
      // beams start at the first note-head box and end at the last note-head
      // box, not at the visual center of the duration slot.
      let first-inset = 0pt
      let last-inset = calc.max(measure.notes.at(end).min-width - beam-note-width, 0pt)
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
      columns.push(extra-note-gap)
      cells.push([])
    }
  }

  if measure.bar {
    columns.push(bar-gap + bar-width)
    cells.push([])
  }

  box[
    #grid(columns: columns, gutter: 0pt, ..cells)
  ]
}

#let render-measure(
  measure,
  extra-note-gap: 0pt,
  bar-width: 5pt,
  bar-gap: 6pt,
  beam-gap: 2pt,
  beam-note-width: 12pt,
  beam-thickness: 0.8pt,
) = {
  box[
    #stack(dir: ttb, spacing: beam-gap,
      render-note-row(measure, extra-note-gap: extra-note-gap, bar-width: bar-width, bar-gap: bar-gap, note-head-width: beam-note-width),
      render-beam-row(measure, 1, extra-note-gap: extra-note-gap, bar-width: bar-width, bar-gap: bar-gap, beam-note-width: beam-note-width, beam-thickness: beam-thickness),
      render-beam-row(measure, 2, extra-note-gap: extra-note-gap, bar-width: bar-width, bar-gap: bar-gap, beam-note-width: beam-note-width, beam-thickness: beam-thickness),
      render-beam-row(measure, 3, extra-note-gap: extra-note-gap, bar-width: bar-width, bar-gap: bar-gap, beam-note-width: beam-note-width, beam-thickness: beam-thickness),
    )
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
  justify: true,
) = {
  let min-width = row-min-width(row, min-measure-gap: min-measure-gap, bar-width: bar-width, bar-gap: bar-gap)
  let inner-gap-count = calc.max(row-note-count(row) - row.len(), 0)
  let measure-gap-count = calc.max(row.len() - 1, 0)
  let gap-count = inner-gap-count + measure-gap-count
  // This is the current justification model: remaining row width is spread
  // evenly over note-to-note gaps and measure-to-measure gaps. Note boxes keep
  // their duration-derived minimum widths.
  let extra-gap = if justify and gap-count > 0 {
    (line-width - min-width) / gap-count
  } else {
    0pt
  }
  let columns = ()
  let cells = ()

  for (index, measure) in row.enumerate() {
    columns.push(measure-min-width(measure, bar-width: bar-width, bar-gap: bar-gap) + extra-gap * calc.max(measure.notes.len() - 1, 0))
    cells.push(render-measure(
      measure,
      extra-note-gap: extra-gap,
      bar-width: bar-width,
      bar-gap: bar-gap,
      beam-gap: beam-gap,
      beam-note-width: beam-note-width,
      beam-thickness: beam-thickness,
    ))

    if index < row.len() - 1 {
      columns.push(min-measure-gap + extra-gap)
      cells.push([])
    }
  }

  block(width: 100%)[
    #grid(columns: columns, gutter: 0pt, ..cells)
  ]
}

#let group-text(group) = {
  if type(group) == str {
    group
  } else if type(group) == content {
    group.text
  } else {
    str(group)
  }
}

#let group-kind(group) = {
  if type(group) == content and "lang" in group.fields() and group.lang != none {
    if group.lang == "jianpu" {
      "melody"
    } else {
      group.lang
    }
  } else {
    "melody"
  }
}

#let score-tokens(score) = {
  group-text(score)
    .replace(regex("\r?\n"), " ")
    .replace("|", " | ")
    .split(" ")
    .filter(token => token != "")
}

#let parse-track(
  group,
  quarter-width,
  eighth-width,
  short-width,
) = {
  // A raw block is treated as a track. Its language tag is the track kind:
  // ```melody is rendered today; ```lyrics and future kinds are parsed and
  // kept in the score model but not laid out yet.
  (
    kind: group-kind(group),
    source: group-text(group),
    measures: parse-measures(
      score-tokens(group),
      quarter-width: quarter-width,
      eighth-width: eighth-width,
      short-width: short-width,
    ),
  )
}

#let parse-score(
  groups,
  quarter-width,
  eighth-width,
  short-width,
) = {
  // This boundary is intentionally small but important: later multi-voice
  // layout should operate on score.tracks instead of raw blocks directly.
  (
    tracks: groups.map(group => parse-track(
      group,
      quarter-width,
      eighth-width,
      short-width,
    )),
  )
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
  row-gap,
  justify: true,
  justify-last: false,
) = {
  // Current limitation: every melody track wraps independently. Future
  // multi-voice support should lift wrapping to score/system level so all
  // tracks share the same measure ranges per system.
  let rows = wrap-measures(
    track.measures,
    line-width,
    min-measure-gap: min-measure-gap,
    bar-width: bar-width,
    bar-gap: bar-gap,
  )

  stack(dir: ttb, spacing: row-gap,
    ..rows.enumerate().map(((index, row)) => {
      render-row(
        row,
        line-width,
        min-measure-gap: min-measure-gap,
        bar-width: bar-width,
        bar-gap: bar-gap,
        beam-gap: beam-gap,
        beam-note-width: beam-note-width,
        beam-thickness: beam-thickness,
        justify: justify and (justify-last or index < rows.len() - 1),
      )
    }),
  )
}

#let jianpu(
  ..groups,
  font: "Arial",
  size: 12pt,
  justify: true,
  justify-last: false,
) = {
  set text(font: font, size: size, weight: "bold")

  // Internal geometry is derived from the font size. Keep these out of the
  // public API until the core notation model stabilizes.
  let actual-quarter-width = size * 2
  let actual-eighth-width = size * 1.5
  let actual-short-width = size
  let actual-min-measure-gap = size * 0.8
  let actual-bar-width = size * 0.3
  let actual-bar-gap = size * 0.35
  let actual-beam-gap = size * 0.16
  let actual-beam-note-width = size * 0.7
  let actual-beam-thickness = size * 0.04
  let actual-row-gap = size * 0.9
  let actual-group-gap = size * 1.2
  let score = parse-score(
    groups.pos(),
    actual-quarter-width,
    actual-eighth-width,
    actual-short-width,
  )
  let melody-tracks = score.tracks.filter(track => track.kind == "melody")

  layout(available => {
    // For now, multiple melody tracks are rendered one after another. This is
    // deliberate: the parser already has score/tracks, but system-level
    // alignment across tracks is not implemented yet.
    stack(dir: ttb, spacing: actual-group-gap,
      ..melody-tracks.map(track => {
        render-track(
          track,
          available.width,
          actual-min-measure-gap,
          actual-bar-width,
          actual-bar-gap,
          actual-beam-gap,
          actual-beam-note-width,
          actual-beam-thickness,
          actual-row-gap,
          justify: justify,
          justify-last: justify-last,
        )
      }),
    )
  })
}
