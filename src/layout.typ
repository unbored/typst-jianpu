// Measure, row, and track rendering.

#import "glyphs.typ": *
#import "links.typ": *
#import "geometry.typ": minimum-line-thickness, minimum-mark-text-factor, notation-size-from-head-width

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

  if measure-data.repeat-start-visible {
    let repeat-width = repeat-bar-slot-width(bar-width)
    columns.push(repeat-width)
    cells.push(measure-bar-line(
      repeat-width,
      bar-height,
      bar-top-offset,
      bar-width * 0.22,
      repeat-start: true,
    ))
    columns.push(bar-gap)
    cells.push([])
  }

  if leading-gap > 0pt {
    columns.push(leading-gap)
    cells.push([])
  }

  for (index, note) in measure-data.notes.enumerate() {
    if note.leading-width > 0pt {
      // The accidental is painted from the head cell into this empty prefix;
      // keeping it separate preserves the head center on every layer.
      columns.push(note.leading-width)
      cells.push([])
    }
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
        // Keep the ornamental curve anchored at `grace-bottom`, but lift the
        // glyph farther so lower octave dots cannot merge with the curve head.
        let actual-grace-lift = grace-size.height - grace-bottom + grace-link-clearance(note-head-width)
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

    if note.trailing-width > 0pt {
      // This empty column belongs after the head. Keeping it independent is
      // what prevents an augmentation dot from changing the preceding gap.
      columns.push(note.trailing-width)
      cells.push([])
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
      repeat-end: measure-data.repeat-end,
      repeat-both: measure-data.repeat-both,
      repeat-count: if measure-data.volta == none { measure-data.repeat-count } else { 2 },
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

  if measure.repeat-start-visible {
    columns.push(measure-start-prefix-width(measure, bar-width, bar-gap))
    cells.push([])
  }

  if leading-gap > 0pt {
    columns.push(leading-gap)
    cells.push([])
  }

  for (index, note) in measure.notes.enumerate() {
    if note.leading-width > 0pt {
      columns.push(note.leading-width)
      cells.push([])
    }
    columns.push(note.min-width)
    let intrinsic-height = calc.max(
      octave-dots-height(note.octave-up, dot-radius: dot-radius, dot-gap: dot-gap),
      chord-upper-height(note, note-head-width),
    )
    cells.push(box(width: note.min-width, height: actual-slot-height)[
      #place(top + center)[
        #octave-dot-slot(
          note.octave-up,
          note-head-width,
          height: actual-slot-height,
          valign: bottom,
          dot-radius: dot-radius,
          dot-gap: dot-gap,
        )
      ]
      #if note.marks.len() > 0 {
        place(
          bottom + center,
          dy: -intrinsic-height - notation-mark-gap(note-head-width),
        )[
          #notation-mark-stack(note, note-head-width)
        ]
      }
    ])

    if note.trailing-width > 0pt {
      columns.push(note.trailing-width)
      cells.push([])
    }

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
    width += event-width(measure.notes.at(index))
    if index < end {
      width += note-gap-at(actual-note-gaps, index)
    }
  }
  width
}

#let note-quarter-duration(note) = {
  // The parser owns logical time. Convert its exact whole-note fraction to
  // quarter-note units only at this legacy visual grouping boundary.
  note.duration.num * 4.0 / note.duration.den
}

#let same-tuplet(left, right) = {
  left.tuplet != none and right.tuplet != none and left.tuplet.id == right.tuplet.id
}

#let beam-quarter-groups(measure) = {
  let groups = ()
  let start = none
  let duration = 0.0

  for (index, note) in measure.notes.enumerate() {
    let tuplet-start = note.tuplet != none and note.tuplet.index == 0
    let tuplet-end = note.tuplet != none and note.tuplet.index == note.tuplet.count - 1
    let joins-previous-tuplet = index > 0 and same-tuplet(measure.notes.at(index - 1), note)

    // A tuplet is one visual beam group. Flush any preceding short notes, then
    // suppress ordinary quarter-duration cuts until the tuplet itself ends.
    if tuplet-start and start != none {
      groups.push((start: start, end: index - 1))
      start = none
      duration = 0.0
    }

    if note.beams <= 0 {
      if start != none { groups.push((start: start, end: index - 1)) }
      start = none
      duration = 0.0
    } else {
      let note-duration = note-quarter-duration(note)
      if start == none {
        start = index
        duration = note-duration
      } else if duration + note-duration > 1.0 and not joins-previous-tuplet {
        groups.push((start: start, end: index - 1))
        start = index
        duration = note-duration
      } else {
        duration += note-duration
      }

      if tuplet-end or (duration >= 1.0 and note.tuplet == none) {
        groups.push((start: start, end: index))
        start = none
        duration = 0.0
      }
    }
  }

  if start != none { groups.push((start: start, end: measure.notes.len() - 1)) }
  groups
}

#let beam-quarter-group-end(groups, index) = {
  for group in groups {
    if index >= group.start and index <= group.end { return group.end }
  }
  index
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
  beam-thickness: minimum-line-thickness,
) = {
  let index = 0
  let count = measure.notes.len()
  let columns = ()
  let cells = ()
  let actual-note-gaps = resolve-note-gaps(measure, note-gaps, extra-note-gap)
  let quarter-groups = beam-quarter-groups(measure)

  if measure.repeat-start-visible {
    columns.push(measure-start-prefix-width(measure, bar-width, bar-gap))
    cells.push([])
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
      let quarter-group-end = beam-quarter-group-end(quarter-groups, index)
      // All beam levels obey the same quarter-note boundary. A deeper level
      // may stop earlier, but it can never reconnect across that boundary.
      while end + 1 <= quarter-group-end and measure.notes.at(end + 1).beams >= level {
        end += 1
      }

      // Draw one whole beam per continuous group at this beam level. Do not
      // split it per note/gap cell: that creates visible seams and y-offsets.
      let full-width = beam-group-width(measure, start, end, extra-note-gap: extra-note-gap, note-gaps: actual-note-gaps)
      // The last event's post-dot spacer remains outside the beam endpoint.
      let first-note = measure.notes.at(start)
      let last-note = measure.notes.at(end)
      let first-inset = calc.max(event-head-offset(first-note) - beam-note-width / 2, 0pt)
      let last-inset = calc.max(
        event-width(last-note) - event-head-offset(last-note) - beam-note-width / 2,
        0pt,
      )
      let line-width = calc.max(full-width - first-inset - last-inset, beam-note-width)

      columns.push(first-inset)
      cells.push([])
      columns.push(line-width)
      cells.push(beam-line(length: 100%, thickness: beam-thickness))
      columns.push(last-inset)
      cells.push([])

      index = end + 1
    } else {
      columns.push(event-width(note))
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

  if measure.repeat-start-visible {
    columns.push(measure-start-prefix-width(measure, bar-width, bar-gap))
    cells.push([])
  }

  if leading-gap > 0pt {
    columns.push(leading-gap)
    cells.push([])
  }

  for (index, note) in measure.notes.enumerate() {
    if note.leading-width > 0pt {
      columns.push(note.leading-width)
      cells.push([])
    }
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

    if note.trailing-width > 0pt {
      columns.push(note.trailing-width)
      cells.push([])
    }

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
  beam-thickness: minimum-line-thickness,
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

#let row-volta-fragments(row, spans, bar-width, bar-stroke) = {
  let fragments = ()
  let index = 0
  while index < row.len() {
    let measure = row.at(index)
    if measure.volta == none {
      index += 1
    } else {
      let start = index
      let end = index
      while end + 1 < row.len() and row.at(end + 1).volta == measure.volta {
        end += 1
      }
      let last = row.at(end)
      let starts = measure.volta-start
      let ends = last.volta-end
      let previous = if start > 0 { row.at(start - 1) } else { none }
      let previous-end = if start > 0 { spans.at(start - 1).end } else { 0pt }
      let shared-next-ending = ends and end + 1 < row.len() and row.at(end + 1).volta-start
      let start-x = if starts {
        volta-start-boundary-x(previous, previous-end, spans.at(start).start, bar-width, bar-stroke)
      } else {
        spans.at(start).start
      }
      let end-x = if ends {
        volta-end-boundary-x(
          last,
          spans.at(end).end,
          bar-width,
          bar-stroke,
          shared-next-ending: shared-next-ending,
        )
      } else {
        spans.at(end).end
      }
      fragments.push((
        x: start-x,
        width: calc.max(end-x - start-x, bar-width),
        start-index: start,
        end-index: end,
        label: measure.volta,
        starts: starts,
        ends: ends,
        // Earlier endings close at their repeat bar. The final ending remains
        // open unless it also reaches the track's terminal bar.
        close: last.volta-end and (not last.volta-last or last.final-bar),
      ))
      index = end + 1
    }
  }
  fragments
}

#let format-volta-label(source) = {
  let numbers = ()
  for part in source.replace("–", "-").split(",") {
    let bounds = part.split("-")
    if bounds.len() == 2 {
      let first = int(bounds.at(0))
      let last = int(bounds.at(1))
      assert(first <= last, message: "alternative ending ranges must be ascending")
      numbers += range(first, last + 1)
    } else {
      numbers.push(int(part))
    }
  }

  let pieces = ()
  let start = 0
  while start < numbers.len() {
    let end = start
    while end + 1 < numbers.len() and numbers.at(end + 1) == numbers.at(end) + 1 {
      end += 1
    }
    // Two adjacent passes remain explicit (`1, 2`); only runs of three or
    // more are compacted into a typographic range (`4–6`).
    if end - start + 1 >= 3 {
      pieces.push(str(numbers.at(start)) + ".–" + str(numbers.at(end)) + ".")
    } else {
      for index in range(start, end + 1) { pieces.push(str(numbers.at(index)) + ".") }
    }
    start = end + 1
  }
  pieces.join(" ")
}

#let render-volta-fragment(fragment, note-head-width, thickness) = context {
  let label = format-volta-label(fragment.label)
  let label-offset-y = note-head-width * 0.12
  let minimum-label-size = notation-size-from-head-width(note-head-width) * minimum-mark-text-factor
  let label-body = text(font: "Libertinus Serif", size: calc.max(note-head-width * 1.05, minimum-label-size), weight: "regular")[#label]
  // Derive the hook from the actual label box instead of estimating it from
  // the note size. This also covers wider labels such as `1, 2.` consistently.
  let hook = label-offset-y + measure(label-body).height
  box(width: fragment.width, height: 0pt)[
    #line(length: 100%, stroke: thickness)
    #if fragment.starts {
      place(top + left)[#line(length: hook, angle: 90deg, stroke: thickness)]
      place(top + left, dx: note-head-width * 0.18, dy: label-offset-y)[
        #label-body
      ]
    }
    #if fragment.close {
      place(top + right)[#line(length: hook, angle: 90deg, stroke: thickness)]
    }
  ]
}

#let tuplet-endpoint-x(event-positions, index) = {
  let item = event-positions.at(index)
  if item.note.kind != "grace" {
    item.x
  } else {
    // A boundary grace group ornaments a main note rather than becoming the
    // visual endpoint itself, so reuse the same target search as grace links.
    let target = grace-target-position(event-positions, index, item.note.direction)
    if target == none { item.x } else { event-positions.at(target).x }
  }
}

#let row-tuplet-fragments(event-positions, note-head-width) = {
  let fragments = ()
  for (index, item) in event-positions.enumerate() {
    let tuplet = item.note.tuplet
    if tuplet != none and tuplet.index == 0 {
      let end-index = index + tuplet.count - 1
      assert(end-index < event-positions.len(), message: "tuplet range exceeds the current row")
      // Tuplet endpoints point vertically at the centers of the first and
      // last main numerals. Boundary grace groups resolve to their targets.
      let start-x = tuplet-endpoint-x(event-positions, index)
      let end-x = tuplet-endpoint-x(event-positions, end-index)
      fragments.push((
        number: tuplet.number,
        start-index: index,
        end-index: end-index,
        x: start-x,
        width: calc.max(end-x - start-x, note-head-width * 0.2),
      ))
    }
  }
  fragments
}

#let tuplet-event-upper-height(item, note-head-width, dot-radius, dot-gap) = {
  if item.note.kind == "grace" {
    grace-lift(note-head-width) + grace-octave-extra(item.note, note-head-width) + grace-link-clearance(note-head-width)
  } else {
    notation-link-upper-height(item.note, note-head-width, dot-radius, dot-gap)
  }
}

#let row-link-span(link, note-positions, line-width, note-head-width) = {
  let start = if link.start == none { none } else { note-positions.at(link.start) }
  let end = if link.end == none { none } else { note-positions.at(link.end) }
  let inset = if link.kind == "tie" { note-head-width * 0.24 } else { note-head-width * 0.10 }
  let boundary-inset = note-head-width * 0.12
  let left = if start == none { boundary-inset } else { start.x + inset }
  let right = if end == none { line-width - boundary-inset } else { end.x - inset }
  (
    start: start,
    end: end,
    left: left,
    right: right,
    width: calc.max(right - left, note-head-width * 0.2),
  )
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
  beam-thickness: minimum-line-thickness,
  dot-radius: 0.7pt,
  dot-gap: 0.6pt,
  link-fragments: none,
  justify: true,
) = {
  let min-width = row-min-width(row, min-measure-gap: min-measure-gap, bar-width: bar-width, bar-gap: bar-gap)
  let inner-gap-count = calc.max(row-note-count(row) - row.len(), 0)
  let measure-gap-count = 0
  for (index, measure) in row.enumerate() {
    if index > 0 and not measure.repeat-start { measure-gap-count += 1 }
  }
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
  let event-positions = row-event-positions(row, extra-gap, min-measure-gap, bar-width, bar-gap)
  let note-positions = row-link-positions(row, extra-gap, min-measure-gap, bar-width, bar-gap, beam-note-width)
  let notation-links = if link-fragments == none { notation-links-from-items(note-positions) } else { link-fragments }
  let tuplet-fragments = row-tuplet-fragments(event-positions, beam-note-width)
  let measure-spans = row-measure-spans(row, extra-gap, min-measure-gap, bar-width, bar-gap)
  let volta-fragments = row-volta-fragments(row, measure-spans, bar-width, bar-width * 0.22)
  let columns = ()
  let cells = ()
  let notation-upper-height = calc.max(
    octave-dots-height(row-max-octave-up(row), dot-radius: dot-radius, dot-gap: dot-gap),
    row-max-chord-upper-height(row, beam-note-width),
  )
  for measure in row {
    for note in measure.notes {
      notation-upper-height = calc.max(
        notation-upper-height,
        notation-link-upper-height(note, beam-note-width, dot-radius, dot-gap),
      )
    }
  }
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
    let base-height = notation-link-base-height(link, note-positions, line-width, beam-note-width)
    let shape = notation-link-shape(link, note-positions, line-width, base-height, beam-note-width, dot-radius, dot-gap, endpoint-clearance)
    max-link-arc-height = calc.max(
      max-link-arc-height,
      shape.height + shape.shift,
    )
  }
  let link-upper-reserve = if notation-links.len() > 0 { max-link-obstacle-height + max-link-arc-height + endpoint-clearance + beam-note-width * 0.14 } else { 0pt }
  let tuplet-arc-height = beam-note-width * 0.48
  let tuplet-extra-reserve = if tuplet-fragments.len() > 0 {
    tuplet-arc-height + beam-note-width * 0.86 + endpoint-clearance
  } else {
    0pt
  }
  let has-repeat-count = false
  for measure in row {
    if measure.repeat-end and measure.volta == none and measure.repeat-count > 2 {
      has-repeat-count = true
    }
  }
  let structure-upper-reserve = if volta-fragments.len() > 0 or has-repeat-count { beam-note-width * 1.18 } else { 0pt }
  let upper-dot-height = calc.max(notation-upper-height, link-upper-reserve, grace-upper-reserve) + tuplet-extra-reserve + structure-upper-reserve
  let bar-upper-extension = beam-note-width * 0.45
  let bar-lower-extension = bar-upper-extension
  // Barlines describe the main-note row only. Chord members, octave dots,
  // grace notes, and beam layers must not make individual barlines taller.
  let bar-top-offset = bar-upper-extension
  let bar-note-height = beam-note-width
  let bar-height = bar-top-offset + bar-note-height + bar-lower-extension

  let event-offset = 0
  for (index, measure) in row.enumerate() {
    let leading-gap = if index == 0 or measure.repeat-start {
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
      let span = row-link-span(link, note-positions, line-width, beam-note-width)
      let base-arc-height = notation-link-base-height(link, note-positions, line-width, beam-note-width)
      let shape = notation-link-shape(link, note-positions, line-width, base-arc-height, beam-note-width, dot-radius, dot-gap, endpoint-clearance)
      // Use the same clearance above a digit or its upper-dot stack. This
      // keeps unmarked endpoints from appearing noticeably tighter.
      let digit-endpoint = upper-dot-height - endpoint-clearance
      let start-upper-height = if span.start == none { 0pt } else { notation-link-item-upper-height(span.start, beam-note-width, dot-radius, dot-gap) }
      let end-upper-height = if span.end == none { 0pt } else { notation-link-item-upper-height(span.end, beam-note-width, dot-radius, dot-gap) }
      let start-y = (if start-upper-height > 0pt { upper-dot-height - start-upper-height - endpoint-clearance } else { digit-endpoint }) - shape.start-lift - shape.shift
      let end-y = (if end-upper-height > 0pt { upper-dot-height - end-upper-height - endpoint-clearance } else { digit-endpoint }) - shape.end-lift - shape.shift
      place(top + left, dx: span.left)[
        #if span.start != none and span.end != none {
          notation-arc(span.width, start-y, end-y, shape.height)
        } else if span.start != none {
          notation-open-arc(span.width, start-y, shape.height, "outgoing")
        } else if span.end != none {
          notation-open-arc(span.width, end-y, shape.height, "incoming")
        } else {
          notation-through-arc(span.width, beam-note-width * 0.16, beam-note-width * 0.08)
        }
      ]
    }
    #for fragment in tuplet-fragments {
      let local-obstacle = 0pt
      for (local-index, item) in event-positions.slice(fragment.start-index, fragment.end-index + 1).enumerate() {
        let first = local-index == 0
        let last = local-index == fragment.end-index - fragment.start-index
        let outside-boundary-grace = item.note.kind == "grace" and (
          // A leading pre-grace lies left of its target; a trailing post-grace
          // lies right of its target. The opposite combinations remain under
          // the tuplet arc and therefore still participate in avoidance.
          (first and item.note.direction != "previous") or
          (last and item.note.direction == "previous")
        )
        if not outside-boundary-grace {
          local-obstacle = calc.max(
            local-obstacle,
            tuplet-event-upper-height(item, beam-note-width, dot-radius, dot-gap),
          )
        }
      }
      // Only links crossing this tuplet's horizontal span can push it upward;
      // an unrelated slur elsewhere in the row must not affect its height.
      let link-clearance = 0pt
      for link in notation-links {
        let span = row-link-span(link, note-positions, line-width, beam-note-width)
        let fragment-right = fragment.x + fragment.width
        if span.left <= fragment-right and span.right >= fragment.x {
          let base-height = notation-link-base-height(link, note-positions, line-width, beam-note-width)
          let shape = notation-link-shape(link, note-positions, line-width, base-height, beam-note-width, dot-radius, dot-gap, endpoint-clearance)
          link-clearance = calc.max(link-clearance, shape.height + shape.shift + endpoint-clearance)
        }
      }
      let endpoint-y = upper-dot-height - local-obstacle - endpoint-clearance - link-clearance
      place(top + left, dx: fragment.x)[
        #tuplet-mark(
          fragment.width,
          endpoint-y,
          tuplet-arc-height,
          fragment.number,
          beam-note-width,
          // Tuplet curves use the same relative stroke as duration beams.
          thickness: beam-thickness,
        )
      ]
    }
    #for fragment in volta-fragments {
      let covered = row.slice(fragment.start-index, fragment.end-index + 1)
      let local-upper-obstacle = calc.max(
        octave-dots-height(row-max-octave-up(covered), dot-radius: dot-radius, dot-gap: dot-gap),
        row-max-chord-upper-height(covered, beam-note-width),
        row-grace-lift(covered, beam-note-width),
      )
      // Keep the row baseline shared, but lower each volta independently when
      // its own measures contain no upper obstacle. The fixed reserve covers
      // the measured label hook and leaves a gap above the barline.
      let volta-y = upper-dot-height - local-upper-obstacle - beam-note-width * 1.50
      place(top + left, dx: fragment.x, dy: volta-y)[
        #render-volta-fragment(fragment, beam-note-width, beam-thickness)
      ]
    }
  ]
}

// Inline notation is a single intrinsic-width row: it neither wraps nor
// distributes spare paragraph width, but otherwise reuses the full renderer.
#let render-inline-track(
  track,
  min-measure-gap,
  bar-width,
  bar-gap,
  beam-gap,
  beam-note-width,
  beam-thickness,
  dot-radius,
  dot-gap,
) = {
  if track.measures.len() == 0 {
    []
  } else {
    let row = track.measures
    let width = row-min-width(row, min-measure-gap: min-measure-gap, bar-width: bar-width, bar-gap: bar-gap)
    let baseline-shift = 0pt
    for measure in row {
      let measure-depth = 0pt
      for level in range(1, 4) {
        if has-beam-level(measure, level) {
          // A horizontal Typst line measures 0pt high; only the stack gap
          // advances layout below the main-note baseline.
          measure-depth += beam-gap
        }
      }
      if max-octave-down(measure) > 0 {
        measure-depth += beam-gap + octave-dots-height(max-octave-down(measure), dot-radius: dot-radius, dot-gap: dot-gap)
      }
      baseline-shift = calc.max(baseline-shift, measure-depth)
    }

    // The row box normally aligns its bottom edge with surrounding text. Move
    // that baseline upward by every layer below the main digit baseline.
    box(width: width, baseline: baseline-shift)[
      #render-row(
        row,
        width,
        min-measure-gap: min-measure-gap,
        bar-width: bar-width,
        bar-gap: bar-gap,
        beam-gap: beam-gap,
        beam-note-width: beam-note-width,
        beam-thickness: beam-thickness,
        dot-radius: dot-radius,
        dot-gap: dot-gap,
        justify: false,
      )
    ]
  }
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
