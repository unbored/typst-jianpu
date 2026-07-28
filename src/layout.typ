// Measure, row, and track rendering.

#import "glyphs.typ": *
#import "links.typ": *

// Complete row-level vertical analysis before painting any measure so every
// measure shares one digit baseline and one upper reservation.
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


// A measure is painted as transparent aligned layers. Note, beam, and dot rows
// must all consume the exact same horizontal columns.
#let render-note-row(
  measure-data,
  extra-note-gap: 0pt,
  note-gaps: none,
  grace-targets: none,
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
  let actual-note-gaps = resolve-note-gaps(measure-data, note-gaps, extra-note-gap)

  if leading-gap > 0pt {
    columns.push(leading-gap)
    cells.push([])
  }

  for (index, note) in measure-data.notes.enumerate() {
    columns.push(note.min-width)
    if note.kind == "grace" {
      let row-target = if grace-targets != none and index < grace-targets.len() { grace-targets.at(index) } else { none }
      let local-target = if row-target == none { grace-target-index(measure-data, index, note.direction) } else { none }
      let target-note = if row-target != none {
        row-target.note
      } else if local-target != none {
        measure-data.notes.at(local-target)
      } else {
        none
      }
      let distance = if row-target != none {
        row-target.distance
      } else if local-target != none {
        note-center-distance(measure-data, actual-note-gaps, index, local-target)
      } else {
        0pt
      }
      // Compensate for every octave-dot row. This first pins the complete
      // grace box's bottom edge instead of letting added dots push it down.
      let nominal-grace-lift = grace-lift(note-head-width) + grace-octave-extra(note, note-head-width)
      let same-measure-target = if row-target != none { row-target.same-measure } else { local-target != none }
      let target-shift = if target-note == none { 0pt } else { grace-target-shift(note, distance, note-head-width, same-measure: same-measure-target) }
      let signed-shift = if note.direction == "previous" { -target-shift } else { target-shift }
      cells.push(context {
        let grace-body = note-head(note, note-head-width: note-head-width)
        let grace-size = measure(grace-body)
        let target-size = if target-note == none {
          (width: 0pt, height: 0pt)
        } else {
          measure(note-head(target-note, note-head-width: note-head-width))
        }
        let row-height = if target-note != none {
          target-size.height
        } else if note.members.len() > 0 {
          measure(note-head(note.members.at(0), note-head-width: note-head-width)).height
        } else {
          note-head-width
        }
        let main-center = target-size.height / 2
        let nominal-grace-bottom = grace-size.height - nominal-grace-lift
        // Keep a visible vertical head even when many lower dots would place
        // the measured bottom almost level with the main note's center.
        let grace-bottom = if target-note == none {
          nominal-grace-bottom
        } else {
          calc.min(nominal-grace-bottom, main-center - grace-link-min-rise(note-head-width))
        }
        let actual-grace-lift = grace-size.height - grace-bottom
        // Move the independent grace group slightly toward its target. The arc
        // starts at the shifted box center, so its horizontal span shrinks too.
        let endpoint-distance = calc.max(distance - target-size.width / 2 - target-shift, 0pt)
        // The lifted grace group is an overlay on the ordinary digit row. If
        // its measured height participates here, every following beam and
        // lower-dot layer in the measure is pushed too far downward.
        box(width: note.min-width, height: row-height)[
          #place(top + center, dx: signed-shift, dy: -actual-grace-lift)[#grace-body]
          #if target-note != none {
            place(top + left, dx: note.min-width / 2 + signed-shift, dy: grace-bottom)[
              #grace-link(endpoint-distance, note.direction, main-center - grace-bottom)
            ]
          }
        ]
      })
    } else {
      cells.push(box(width: note.min-width)[
        #align(center)[#note-head(note, note-head-width: note-head-width)]
      ])
    }

    if index < measure-data.notes.len() - 1 {
      columns.push(note-gap-at(actual-note-gaps, index))
      cells.push([])
    }
  }

  if measure-data.bar {
    let actual-bar-width = measure-bar-slot-width(measure-data, bar-width)
    columns.push(trailing-bar-gap)
    cells.push([])
    columns.push(actual-bar-width)
    cells.push(measure-bar-line(
      actual-bar-width,
      bar-height,
      bar-top-offset,
      bar-width * 0.22,
      final: measure-data.final-bar,
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
  let actual-note-gaps = resolve-note-gaps(measure, note-gaps, extra-note-gap)

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
    columns.push(trailing-bar-gap + measure-bar-slot-width(measure, bar-width))
    cells.push([])
  }

  box[
    #grid(columns: columns, gutter: 0pt, ..cells)
  ]
}

#let beam-group-width(measure, start, end, extra-note-gap: 0pt, note-gaps: none) = {
  let width = 0pt
  let actual-note-gaps = resolve-note-gaps(measure, note-gaps, extra-note-gap)

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
  let actual-note-gaps = resolve-note-gaps(measure, note-gaps, extra-note-gap)

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
    columns.push(trailing-bar-gap + measure-bar-slot-width(measure, bar-width))
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
  let actual-note-gaps = resolve-note-gaps(measure, note-gaps, extra-note-gap)

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
    columns.push(trailing-bar-gap + measure-bar-slot-width(measure, bar-width))
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

// Assemble one measure's vertical layers without changing its allocated width.
#let render-measure(
  measure,
  extra-note-gap: 0pt,
  note-gaps: none,
  grace-targets: none,
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
  let actual-note-gaps = resolve-note-gaps(measure, note-gaps, extra-note-gap)
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
    render-note-row(measure, extra-note-gap: extra-note-gap, note-gaps: actual-note-gaps, grace-targets: grace-targets, leading-gap: side-gaps.leading, trailing-bar-gap: side-gaps.trailing, bar-width: bar-width, bar-gap: bar-gap, note-head-width: beam-note-width, bar-height: bar-height, bar-top-offset: bar-top-offset),
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

// Distribute remaining width, reserve shared vertical extents, then overlay
// row-level slur/tie fragments above independently rendered measures.
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
  link-fragments: none,
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
  // Grace-to-main-note curves use row coordinates so their target may live in
  // the adjacent measure and the curve may pass through the intervening bar.
  let grace-targets = row-grace-targets(row, extra-gap, min-measure-gap, bar-width, bar-gap)
  let note-positions = row-link-positions(row, extra-gap, min-measure-gap, bar-width, bar-gap, beam-note-width)
  let notation-links = if link-fragments == none { notation-links-from-items(note-positions) } else { link-fragments }
  let columns = ()
  let cells = ()
  let notation-upper-height = calc.max(
    octave-dots-height(row-max-octave-up(row), dot-radius: dot-radius, dot-gap: dot-gap),
    row-max-chord-upper-height(row, beam-note-width),
  )
  // `move` does not affect layout bounds, so reserve the same distance that
  // grace groups are lifted above the ordinary note row.
  let grace-upper-reserve = row-grace-lift(row, beam-note-width)
  let endpoint-clearance = beam-note-width * 0.16
  let max-link-arc-height = 0pt
  let max-link-obstacle-height = 0pt
  for item in note-positions {
    max-link-obstacle-height = calc.max(
      max-link-obstacle-height,
      notation-link-item-upper-height(item, beam-note-width, dot-radius, dot-gap),
    )
  }
  for link in notation-links {
    let base-height = notation-link-base-height(link, note-positions, beam-note-width)
    max-link-arc-height = calc.max(
      max-link-arc-height,
      notation-link-arc-height(link, note-positions, line-width, base-height, beam-note-width, dot-radius, dot-gap, beam-gap, endpoint-clearance),
    )
  }
  let link-upper-reserve = if notation-links.len() > 0 { max-link-obstacle-height + max-link-arc-height + endpoint-clearance + beam-note-width * 0.14 } else { 0pt }
  let upper-dot-height = calc.max(notation-upper-height, link-upper-reserve, grace-upper-reserve)
  let bar-lower-extension = beam-note-width * 0.30
  let bar-upper-extension = bar-lower-extension * 1.5
  let bar-top-offset = row-max-chord-digit-height(row, beam-note-width) + bar-upper-extension
  let bar-note-height = beam-note-width
  let bar-height = bar-top-offset + bar-note-height + bar-lower-extension

  let event-offset = 0
  for (index, measure) in row.enumerate() {
    let leading-gap = if index == 0 {
      0pt
    } else {
      min-measure-gap + extra-gap
    }
    let measure-width = measure-min-width(measure, bar-width: bar-width, bar-gap: bar-gap) + extra-gap * calc.max(measure.notes.len() - 1, 0)
    let note-gaps = note-gaps-from-extra(measure, extra-gap)
    let measure-grace-targets = grace-targets.slice(event-offset, event-offset + measure.notes.len())
    event-offset += measure.notes.len()

    columns.push(leading-gap + measure-width)
    cells.push(render-measure(
      measure,
      extra-note-gap: extra-gap,
      note-gaps: note-gaps,
      grace-targets: measure-grace-targets,
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
    // Links are row-level overlays, so a span may cross a bar line without
    // changing measure widths or the note/beam alignment underneath.
    #for link in notation-links {
      let start = if link.start == none { none } else { note-positions.at(link.start) }
      let end = if link.end == none { none } else { note-positions.at(link.end) }
      let inset = if link.kind == "tie" { beam-note-width * 0.24 } else { beam-note-width * 0.10 }
      let boundary-inset = beam-note-width * 0.12
      let start-x = if start == none { boundary-inset } else { start.x + inset }
      let end-x = if end == none { line-width - boundary-inset } else { end.x - inset }
      let width = calc.max(end-x - start-x, beam-note-width * 0.2)
      let base-arc-height = notation-link-base-height(link, note-positions, beam-note-width)
      let arc-height = notation-link-arc-height(link, note-positions, line-width, base-arc-height, beam-note-width, dot-radius, dot-gap, beam-gap, endpoint-clearance)
      // Use the same clearance above a digit or its upper-dot stack. This
      // keeps unmarked endpoints from appearing noticeably tighter.
      let digit-endpoint = upper-dot-height - endpoint-clearance
      let start-upper-height = if start == none { 0pt } else { notation-link-item-upper-height(start, beam-note-width, dot-radius, dot-gap) }
      let end-upper-height = if end == none { 0pt } else { notation-link-item-upper-height(end, beam-note-width, dot-radius, dot-gap) }
      let start-y = if start-upper-height > 0pt { upper-dot-height - start-upper-height - endpoint-clearance } else { digit-endpoint }
      let end-y = if end-upper-height > 0pt { upper-dot-height - end-upper-height - endpoint-clearance } else { digit-endpoint }
      place(top + left, dx: start-x)[
        #if start != none and end != none {
          notation-arc(width, start-y, end-y, arc-height)
        } else if start != none {
          notation-open-arc(width, start-y, arc-height, "outgoing")
        } else if end != none {
          notation-open-arc(width, end-y, arc-height, "incoming")
        } else {
          notation-through-arc(width, beam-note-width * 0.16, beam-note-width * 0.08)
        }
      ]
    }
  ]
}

// Wrapping is track-local for now. Future multi-voice work should move system
// construction above individual tracks rather than modifying measures.
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

  let track-items = ()
  for measure in track.measures {
    for note in measure.notes {
      for item in event-link-items(note) { track-items.push(item) }
    }
  }
  let track-links = notation-links-from-items(track-items)
  let row-starts = ()
  let note-offset = 0
  for row in rows {
    row-starts.push(note-offset)
    note-offset += row-link-anchor-count(row)
  }

  stack(dir: ttb, spacing: row-gap,
    ..rows.enumerate().map(((index, row)) => {
      let row-line-width = if index == 0 {
        first-line-width
      } else {
        line-width
      }
      let fragments = row-link-fragments(track-links, row-starts.at(index), row-link-anchor-count(row))
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
        link-fragments: fragments,
        justify: justify-last or index < rows.len() - 1,
      )

      if index == 0 and first-indent > 0pt {
        grid(columns: (first-indent, row-line-width), gutter: 0pt, [], row-content)
      } else {
        row-content
      }
    }),
  )
}
