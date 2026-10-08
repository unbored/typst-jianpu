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
  leading-note-gap: none,
  trailing-bar-gap: none,
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
  let side-gaps = if leading-note-gap != none and trailing-bar-gap != none {
    (leading: leading-note-gap, trailing: trailing-bar-gap)
  } else {
    measure-side-gaps(leading-gap, bar-gap, measure.bar)
  }
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

#let lyric-event(note) = note.kind != "grace" and not is-extension-note(note)

#let row-lyric-slot-count(row) = {
  let count = 0
  for measure in row {
    for note in measure.notes {
      if lyric-event(note) { count += 1 }
    }
  }
  count
}

#let row-extra-gap-for-width(row, line-width, min-measure-gap, bar-width, bar-gap, justify) = {
  let min-width = row-min-width(row, min-measure-gap: min-measure-gap, bar-width: bar-width, bar-gap: bar-gap)
  let inner-gap-count = calc.max(row-note-count(row) - row.len(), 0)
  let measure-gap-count = 0
  for (index, measure-data) in row.enumerate() {
    if index > 0 and not measure-data.repeat-start { measure-gap-count += 1 }
  }
  // On ordinary justified rows, the final note-to-bar distance is another
  // flexible visual gap. Otherwise the last extension stroke hugs the final
  // bar while all preceding event centers spread across the line.
  let terminal-gap-count = if (
    simple-row-boundaries(row) and row.len() > 0 and row.at(row.len() - 1).bar
  ) { 1 } else { 0 }
  let gap-count = inner-gap-count + measure-gap-count + terminal-gap-count
  if justify and gap-count > 0 { (line-width - min-width) / gap-count } else { 0pt }
}

#let annotation-line-split(source, width, annotation-font, annotation-size) = {
  let body-width(value) = measure(text(font: annotation-font, size: annotation-size, weight: "regular")[#value]).width
  if source == "" or body-width(source) <= width {
    (line: source, rest: "")
  } else {
    let words = source.split(" ").filter(word => word != "")
    let line = ""
    for (index, word) in words.enumerate() {
      let candidate = if line == "" { word } else { line + " " + word }
      if body-width(candidate) <= width {
        line = candidate
      } else if line != "" {
        return (line: line, rest: words.slice(index).join(" "))
      } else {
        // A single unspaced item (commonly Chinese) may still exceed the
        // available width. Split it by characters, but always consume one.
        let prefix = ""
        let consumed = 0
        for character in word {
          let candidate = prefix + character
          if prefix == "" or body-width(candidate) <= width {
            prefix = candidate
            consumed += 1
          } else {
            break
          }
        }
        let remainder = word.slice(consumed)
        let rest = (if remainder == "" { () } else { (remainder,) }) + words.slice(index + 1)
        return (line: prefix, rest: rest.join(" "))
      }
    }
    (line: line, rest: "")
  }
}

#let annotation-content(annotation, annotation-font, annotation-size) = {
  let body = if annotation.markup {
    eval(annotation.text, mode: "markup")
  } else {
    annotation.text
  }
  text(font: annotation-font, size: annotation-size, weight: "regular")[#body]
}

#let row-annotation-fragments(
  rows,
  line-width,
  first-line-width,
  min-measure-gap,
  bar-width,
  bar-gap,
  note-head-width,
  annotation-font,
  justify-last,
) = {
  let fragments = rows.map(_ => ())
  let annotation-size = notation-size-from-head-width(note-head-width) * 0.90
  for (row-index, row) in rows.enumerate() {
    let actual-width = if row-index == 0 { first-line-width } else { line-width }
    let justify = justify-last or row-index < rows.len() - 1
    let extra-gap = row-extra-gap-for-width(row, actual-width, min-measure-gap, bar-width, bar-gap, justify)
    let positions = row-event-positions(row, extra-gap, min-measure-gap, bar-width, bar-gap)
    for item in positions {
      for annotation in item.note.annotations {
        let origin-left = calc.max(item.x - note-head-width / 2, 0pt)
        if annotation.markup {
          // Arbitrary markup cannot be split without losing its content tree
          // and style scopes, so rich annotations retain local Typst wrapping.
          fragments.at(row-index).push(annotation + (left: origin-left,))
        } else {
          let remaining = annotation.text
          let target-row = row-index
          let first-fragment = true
          while remaining != "" {
            let target-width = if target-row == 0 { first-line-width } else { line-width }
            let left = if first-fragment { origin-left } else { 0pt }
            let available = calc.max(target-width - left, note-head-width * 0.5)
            if target-row < rows.len() - 1 {
              let split = annotation-line-split(remaining, available, annotation-font, annotation-size)
              if split.line != "" {
                fragments.at(target-row).push((
                  text: split.line,
                  placement: annotation.placement,
                  markup: false,
                  left: left,
                ))
              }
              remaining = split.rest
              target-row += 1
              first-fragment = false
            } else {
              // With no following notation row, retain the existing local
              // paragraph wrap instead of manufacturing an empty score row.
              fragments.at(target-row).push((
                text: remaining,
                placement: annotation.placement,
                markup: false,
                left: left,
              ))
              remaining = ""
            }
          }
        }
      }
    }
  }
  fragments
}

#let annotation-boxes(event-positions, line-width, note-head-width, annotation-font, annotation-fragments: none) = {
  let boxes = ()
  let annotation-size = notation-size-from-head-width(note-head-width) * 0.90
  let sources = if annotation-fragments == none {
    let items = ()
    for item in event-positions {
      for annotation in item.note.annotations {
        items.push((
          text: annotation.text,
          placement: annotation.placement,
          markup: annotation.markup,
          left: calc.max(item.x - note-head-width / 2, 0pt),
        ))
      }
    }
    items
  } else {
    annotation-fragments
  }
  for annotation in sources {
      let left = annotation.left
      let available = calc.max(line-width - left, note-head-width * 0.5)
      let body = annotation-content(annotation, annotation-font, annotation-size)
      let intrinsic = measure(body)
      let width = calc.min(intrinsic.width, available)
      let wrapped = block(width: width)[#body]
      boxes.push((
        placement: annotation.placement,
        left: left,
        right: left + width,
        width: width,
        height: measure(wrapped).height,
        body: wrapped,
      ))
  }
  boxes
}

#let annotation-local-upper-height(box-data, event-positions, note-head-width, dot-radius, dot-gap) = {
  let height = 0pt
  for item in event-positions {
    let item-left = item.x - note-head-width / 2
    let item-right = item.x + note-head-width / 2
    if item-left <= box-data.right and item-right >= box-data.left {
      height = calc.max(height, notation-link-upper-height(item.note, note-head-width, dot-radius, dot-gap))
    }
  }
  height
}

#let event-bottom-height(note, note-head-width, beam-gap, dot-radius, dot-gap) = {
  // Start at the measured event-head bottom rather than the canonical
  // 0.7em head width; Arial digits are visibly taller than that estimate.
  let height = measure(note-head(note, note-head-width: note-head-width)).height + note.beams * beam-gap
  if note.octave-down > 0 {
    height += beam-gap + octave-dots-height(note.octave-down, dot-radius: dot-radius, dot-gap: dot-gap)
  }
  height
}

#let annotation-local-lower-height(box-data, event-positions, note-head-width, beam-gap, dot-radius, dot-gap) = {
  let height = 0pt
  for item in event-positions {
    let item-left = item.x - note-head-width / 2
    let item-right = item.x + note-head-width / 2
    if item-left <= box-data.right and item-right >= box-data.left {
      height = calc.max(height, event-bottom-height(item.note, note-head-width, beam-gap, dot-radius, dot-gap))
    }
  }
  height
}

// Lyrics use the exact event centers already shared by note heads, dots,
// beams, and links. Long Chinese strings remain one centered item; English
// hyphens are overlays at the midpoint between adjacent consumed slots.
#let attached-item-body(item, lyric-size, lyric-font) = {
  if item.text == none {
    none
  } else if "rendered" in item {
    item.rendered
  } else {
    let body = text(font: lyric-font, size: lyric-size, weight: "regular")[#item.text]
    let bounds = measure(body)
    (content: body, size: bounds, anchor-x: bounds.width / 2)
  }
}

#let render-lyric-line(items, event-positions, line-width, note-head-width, lyric-font) = context {
  let positions = event-positions.filter(item => lyric-event(item.note))
  let lyric-size = notation-size-from-head-width(note-head-width) * 0.92
  let bodies = items.map(item => attached-item-body(item, lyric-size, lyric-font))
  let minimum-height = items.fold(lyric-size * 1.25,
    (height, item) => calc.max(height, item.at("line-height", default: 0pt)))
  let line-height = bodies.filter(body => body != none).fold(minimum-height,
    (height, body) => calc.max(height, body.size.height))
  box(width: line-width, height: line-height)[
    #for (index, item) in items.enumerate() {
      if index < positions.len() and bodies.at(index) != none {
        let body = bodies.at(index)
        let offset-y = if "rendered" in item { line-height - body.size.height } else { 0pt }
        place(top + left, dx: positions.at(index).x - body.anchor-x, dy: offset-y)[#body.content]
      }
      if index < positions.len() and item.hyphen-after {
        let gap-center = if (
          index + 1 < positions.len() and
          index + 1 < bodies.len() and
          bodies.at(index) != none and
          bodies.at(index + 1) != none
        ) {
          // Center the hyphen in the visible gap between the two lyric boxes,
          // not halfway between note centers; unequal syllable widths matter.
          let left-edge = positions.at(index).x + bodies.at(index).size.width / 2
          let right-edge = positions.at(index + 1).x - bodies.at(index + 1).size.width / 2
          (left-edge + right-edge) / 2
        } else {
          let next-x = if index + 1 < positions.len() { positions.at(index + 1).x } else { line-width }
          (positions.at(index).x + next-x) / 2
        }
        let hyphen = text(font: lyric-font, size: lyric-size, weight: "regular")[-]
        let hyphen-size = measure(hyphen)
        place(top + left, dx: gap-center - hyphen-size.width / 2)[#hyphen]
      }
    }
  ]
}

// Expand only the gaps required by visible lyric pairs. A skipped slot keeps
// its ordinary musical width, letting surrounding words use that empty region
// before the melody itself has to grow.
#let apply-lyric-spacing(
  track,
  lyric-tracks,
  lyric-font,
  note-head-width,
  min-measure-gap,
  bar-width,
  bar-gap,
) = {
  if lyric-tracks.len() == 0 {
    track
  } else {
    let lyric-size = notation-size-from-head-width(note-head-width) * 0.92
    let probe-spaced = text(font: lyric-font, size: lyric-size, weight: "regular")[x x]
    let probe-joined = text(font: lyric-font, size: lyric-size, weight: "regular")[xx]
    let word-gap = calc.max(measure(probe-spaced).width - measure(probe-joined).width, lyric-size * 0.20)
    let hyphen-body = text(font: lyric-font, size: lyric-size, weight: "regular")[-]
    let hyphen-gap = measure(hyphen-body).width + lyric-size * 0.20

    // Obtain minimum event coordinates before wrapping. Width additions then
    // pass through the existing measure-width and line-breaking machinery.
    let positions = row-event-positions(track.measures, 0pt, min-measure-gap, bar-width, bar-gap)
    let lyric-slots = ()
    for (event-index, item) in positions.enumerate() {
      if lyric-event(item.note) {
        lyric-slots.push((event-index: event-index, x: item.x))
      }
    }
    let additions = positions.map(_ => 0pt)

    for lyric-track in lyric-tracks {
      let previous = none
      for (slot-index, item) in lyric-track.syllables.enumerate() {
        if item.text != none {
          let body = attached-item-body(item, lyric-size, lyric-font)
          let current = (
            event-index: lyric-slots.at(slot-index).event-index,
            x: lyric-slots.at(slot-index).x,
            width: body.size.width,
            anchor-x: body.anchor-x,
            gap: body.at("gap", default: word-gap),
            hyphen-after: item.hyphen-after,
          )
          if previous != none {
            let added-distance = 0pt
            for boundary in range(previous.event-index, current.event-index) {
              added-distance += additions.at(boundary)
            }
            let current-distance = current.x - previous.x + added-distance
            let separator = if previous.hyphen-after { hyphen-gap } else { previous.gap }
            let required-distance = previous.width - previous.anchor-x + separator + current.anchor-x
            let deficit = required-distance - current-distance
            let boundary-count = current.event-index - previous.event-index
            if deficit > 0pt and boundary-count > 0 {
              let share = deficit / boundary-count
              for boundary in range(previous.event-index, current.event-index) {
                additions.at(boundary) = additions.at(boundary) + share
              }
            }
          }
          previous = current
        }
      }
    }

    let adjusted-measures = ()
    let event-index = 0
    for measure-data in track.measures {
      let notes = ()
      for note in measure-data.notes {
        notes.push(note + (trailing-width: note.trailing-width + additions.at(event-index),))
        event-index += 1
      }
      adjusted-measures.push(measure-data + (notes: notes,))
    }
    track + (measures: adjusted-measures,)
  }
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
  lyric-lines: (),
  lyric-font: none,
  annotation-font: none,
  annotation-fragments: none,
  justify: true,
) = context {
  // Row justification first allocates extra width to each measure and to each
  // measure boundary. Each measure then converts its allocated width into
  // variable note gaps so note heads are evenly spaced inside that measure.
  let extra-gap = row-extra-gap-for-width(row, line-width, min-measure-gap, bar-width, bar-gap, justify)
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
  let annotation-upper-gap = beam-note-width * 0.64
  let annotation-lower-gap = beam-note-width * 0.72
  let annotations = annotation-boxes(
    event-positions,
    line-width,
    beam-note-width,
    annotation-font,
    annotation-fragments: annotation-fragments,
  )
  let annotation-upper-reserve = 0pt
  let row-lower-height = 0pt
  for item in event-positions {
    row-lower-height = calc.max(row-lower-height, event-bottom-height(item.note, beam-note-width, beam-gap, dot-radius, dot-gap))
  }
  let annotation-bottom-extra = 0pt
  let positioned-annotations = ()
  for annotation in annotations {
    if annotation.placement == "above" {
      let obstacle = annotation-local-upper-height(annotation, event-positions, beam-note-width, dot-radius, dot-gap)
      for link in notation-links {
        let span = row-link-span(link, note-positions, line-width, beam-note-width)
        if span.left <= annotation.right and span.right >= annotation.left {
          let base-height = notation-link-base-height(link, note-positions, line-width, beam-note-width)
          let shape = notation-link-shape(link, note-positions, line-width, base-height, beam-note-width, dot-radius, dot-gap, endpoint-clearance)
          obstacle = calc.max(obstacle, max-link-obstacle-height + shape.height + shape.shift + endpoint-clearance)
        }
      }
      for fragment in tuplet-fragments {
        if fragment.x <= annotation.right and fragment.x + fragment.width >= annotation.left {
          obstacle = calc.max(obstacle, notation-upper-height + tuplet-arc-height + beam-note-width * 0.45)
        }
      }
      // Only obstacles whose horizontal extent intersects this text box push
      // it upward; unrelated tall notes elsewhere in the row are ignored.
      annotation-upper-reserve = calc.max(annotation-upper-reserve, obstacle + annotation-upper-gap + annotation.height)
      positioned-annotations.push(annotation + (obstacle: obstacle,))
    } else {
      let obstacle = annotation-local-lower-height(annotation, event-positions, beam-note-width, beam-gap, dot-radius, dot-gap)
      annotation-bottom-extra = calc.max(
        annotation-bottom-extra,
        obstacle + annotation-lower-gap + annotation.height - row-lower-height,
      )
      positioned-annotations.push(annotation + (obstacle: obstacle,))
    }
  }
  let upper-dot-height = calc.max(
    notation-upper-height,
    link-upper-reserve,
    grace-upper-reserve,
    annotation-upper-reserve,
  ) + tuplet-extra-reserve + structure-upper-reserve
  let bar-upper-extension = beam-note-width * 0.45
  let bar-lower-extension = bar-upper-extension
  // Barlines describe the main-note row only. Chord members, octave dots,
  // grace notes, and beam layers must not make individual barlines taller.
  let bar-top-offset = bar-upper-extension
  let bar-note-height = beam-note-width
  let bar-height = bar-top-offset + bar-note-height + bar-lower-extension

  let event-offset = 0
  for (index, measure) in row.enumerate() {
    let side-gaps = row-measure-side-gaps(row, index, extra-gap, min-measure-gap, bar-gap)
    let measure-width = row-allocated-measure-width(row, index, extra-gap, min-measure-gap, bar-width, bar-gap)
    let note-gaps = note-gaps-from-extra(measure, extra-gap)
    let measure-grace-targets = grace-targets.slice(event-offset, event-offset + measure.notes.len())
    event-offset += measure.notes.len()

    columns.push(measure-width)
    cells.push(render-measure(
      measure,
      extra-note-gap: extra-gap,
      note-gaps: note-gaps,
      grace-targets: measure-grace-targets,
      leading-note-gap: side-gaps.leading,
      trailing-bar-gap: side-gaps.trailing,
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

  // A notation row and all of its attached text form one pagination unit;
  // otherwise a lower annotation may be orphaned at the next page top.
  block(width: 100%, breakable: false)[
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
    #for annotation in positioned-annotations {
      let y = if annotation.placement == "above" {
        upper-dot-height - annotation.obstacle - annotation-upper-gap - annotation.height
      } else {
        upper-dot-height + annotation.obstacle + annotation-lower-gap
      }
      place(top + left, dx: annotation.left, dy: y)[#annotation.body]
    }
    #if annotation-bottom-extra > 0pt {
      v(annotation-bottom-extra)
    }
    #if lyric-lines.len() > 0 {
      v(beam-note-width * 0.42)
      stack(dir: ttb, spacing: notation-size-from-head-width(beam-note-width) * 0.4,
        ..lyric-lines.map(items => render-lyric-line(
          items,
          event-positions,
          line-width,
          beam-note-width,
          lyric-font,
        )),
      )
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
  annotation-font: none,
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
        annotation-font: annotation-font,
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
  lyric-tracks: (),
  lyric-font: none,
  annotation-font: none,
) = context {
  let lyric-capacity = row-lyric-slot-count(track.measures)
  for lyric-track in lyric-tracks {
    assert(
      lyric-track.syllables.len() <= lyric-capacity,
      message: lyric-track.kind + " contains more items than the melody has main-note slots",
    )
  }
  let spaced-track = apply-lyric-spacing(
    track,
    lyric-tracks,
    lyric-font,
    beam-note-width,
    min-measure-gap,
    bar-width,
    bar-gap,
  )
  let first-line-width = calc.max(line-width - first-indent, beam-note-width)

  // Current limitation: every melody track wraps independently. Future
  // multi-voice support should lift wrapping to score/system level so all
  // tracks share the same measure ranges per system.
  let rows = wrap-measures(
    spaced-track.measures,
    line-width,
    first-line-width: first-line-width,
    min-measure-gap: min-measure-gap,
    bar-width: bar-width,
    bar-gap: bar-gap,
  )

  let track-items = ()
  for measure in spaced-track.measures {
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

  let lyric-offsets = lyric-tracks.map(_ => 0)
  let row-lyric-lines = ()
  for row in rows {
    let lyric-count = row-lyric-slot-count(row)
    let lines = ()
    for (lyric-index, lyric-track) in lyric-tracks.enumerate() {
      let start = calc.min(lyric-offsets.at(lyric-index), lyric-track.syllables.len())
      let end = calc.min(start + lyric-count, lyric-track.syllables.len())
      lyric-offsets.at(lyric-index) = lyric-offsets.at(lyric-index) + lyric-count
      lines.push(lyric-track.syllables.slice(start, end))
    }
    row-lyric-lines.push(lines)
  }
  let row-annotations = row-annotation-fragments(
    rows,
    line-width,
    first-line-width,
    min-measure-gap,
    bar-width,
    bar-gap,
    beam-note-width,
    annotation-font,
    justify-last,
  )

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
        lyric-lines: row-lyric-lines.at(index),
        lyric-font: lyric-font,
        annotation-font: annotation-font,
        annotation-fragments: row-annotations.at(index),
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
