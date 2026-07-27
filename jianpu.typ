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

#let octave-dots-height(count, dot-radius: 0.7pt, dot-gap: 0.6pt) = {
  if count <= 0 { 0pt } else { count * dot-radius * 2 + (count - 1) * dot-gap }
}

#let octave-dots(count, dot-radius: 0.7pt, dot-gap: 0.6pt) = {
  let dot-diameter = dot-radius * 2
  box(width: dot-diameter, height: octave-dots-height(count, dot-radius: dot-radius, dot-gap: dot-gap))[
    #for index in range(0, count) {
      place(top, dy: index * (dot-diameter + dot-gap))[
        #circle(radius: dot-radius, fill: black)
      ]
    }
  ]
}

#let grace-member-width(note-head-width) = {
  note-head-width / 0.7 * 0.75 * 0.72
}

#let grace-member-gap(note-head-width) = {
  note-head-width / 0.7 * 0.12
}

#let grace-group-width(note, note-head-width) = {
  note.members.len() * grace-member-width(note-head-width) + calc.max(note.members.len() - 1, 0) * grace-member-gap(note-head-width)
}

#let grace-head(note, note-head-width) = {
  // Curves are deliberately deferred. This first pass only establishes the
  // compact note group and its independent default duration.
  let scale = 0.75
  let beams = if note.members.len() > 0 { note.members.at(0).beams } else { 0 }
  let dot-radius = 0.075em * scale
  let dot-gap = 0.12em * scale
  let member-width = grace-member-width(note-head-width)
  let member-gap = grace-member-gap(note-head-width)
  let max-up = note.members.fold(0, (count, member) => calc.max(count, member.octave-up))
  let max-down = note.members.fold(0, (count, member) => calc.max(count, member.octave-down))
  // Like ordinary beams, grace beams follow the note heads rather than their
  // duration boxes. The reduced head size determines both end padding and
  // total beam length.
  let group-width = grace-group-width(note, note-head-width)
  // Keep the familiar two-note end inset, but apply it only once instead of
  // accidentally subtracting every internal member gap from a long beam.
  let beam-width = if note.members.len() <= 1 { member-width } else { group-width - member-gap }
  stack(dir: ttb, spacing: 0.08em,
    stack(dir: ltr, spacing: member-gap,
      ..note.members.map(member => box(width: member-width, height: octave-dots-height(max-up, dot-radius: dot-radius, dot-gap: dot-gap))[
        #align(center + bottom)[#octave-dots(member.octave-up, dot-radius: dot-radius, dot-gap: dot-gap)]
      ]),
    ),
    align(center)[
      #stack(dir: ltr, spacing: member-gap,
        ..note.members.map(member => box(width: member-width, align(center)[#text(size: scale * 1em)[#note-text(member)]])),
      )
    ],
    ..range(0, beams).map(_ => align(center)[
      #box(width: beam-width)[
        #line(length: 100%, stroke: 0.04em)
      ]
    ]),
    stack(dir: ltr, spacing: member-gap,
      ..note.members.map(member => box(width: member-width, height: octave-dots-height(max-down, dot-radius: dot-radius, dot-gap: dot-gap))[
        #align(center + top)[#octave-dots(member.octave-down, dot-radius: dot-radius, dot-gap: dot-gap)]
      ]),
    ),
  )
}

#let note-head(note, note-head-width: 12pt) = {
  box(width: note-head-width, align(center)[
    #if note.kind == "grace" {
      grace-head(note, note-head-width)
    } else if note.kind == "chord" {
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

#let event-link-items(note) = {
  if note.kind != "grace" {
    ((note: note, grace: false),)
  } else {
    note.members.enumerate().map(((index, member)) => (
      note: member + (
        slur-start: member.slur-start + if index == 0 { note.slur-start } else { 0 },
        slur-end: member.slur-end + if index == note.members.len() - 1 { note.slur-end } else { 0 },
        tie-start: member.tie-start + if index == note.members.len() - 1 { note.tie-start } else { 0 },
      ),
      grace: true,
      grace-parent: note,
      grace-index: index,
    ))
  }
}

#let row-link-anchor-count(row) = {
  let count = 0
  for measure in row {
    for note in measure.notes { count += event-link-items(note).len() }
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

#let grace-target-index(measure, index, direction) = {
  let step = if direction == "previous" { -1 } else { 1 }
  let target = index + step
  while target >= 0 and target < measure.notes.len() {
    if measure.notes.at(target).kind != "grace" { return target }
    target += step
  }
  none
}

#let grace-target-shift(note-head-width) = {
  note-head-width * 0.14
}

#let note-center-distance(measure, note-gaps, from, to) = {
  let direction = if to > from { 1 } else { -1 }
  let distance = measure.notes.at(from).min-width / 2
  let index = from
  while index != to {
    let gap-index = if direction > 0 { index } else { index - 1 }
    distance += note-gap-at(note-gaps, gap-index)
    index += direction
    distance += if index == to { measure.notes.at(index).min-width / 2 } else { measure.notes.at(index).min-width }
  }
  distance
}

#let row-link-positions(row, extra-gap, min-measure-gap, bar-width, bar-gap, note-head-width) = {
  let positions = ()
  let row-offset = 0pt

  for (measure-index, measure) in row.enumerate() {
    let leading-gap = if measure-index == 0 { 0pt } else { min-measure-gap + extra-gap }
    let side-gaps = measure-side-gaps(leading-gap, bar-gap, measure.bar)
    let note-gaps = note-gaps-from-extra(measure, extra-gap)
    let note-offset = row-offset + side-gaps.leading

    for (note-index, note) in measure.notes.enumerate() {
      let event-center = note-offset + note.min-width / 2
      if note.kind == "grace" {
        let target = grace-target-index(measure, note-index, note.direction)
        let target-shift = if target == none { 0pt } else { grace-target-shift(note-head-width) }
        let signed-shift = if note.direction == "previous" { -target-shift } else { target-shift }
        let member-width = grace-member-width(note-head-width)
        let member-gap = grace-member-gap(note-head-width)
        let group-width = grace-group-width(note, note-head-width)
        for item in event-link-items(note) {
          let member-x = event-center + signed-shift - group-width / 2 + member-width / 2 + item.grace-index * (member-width + member-gap)
          positions.push(item + (x: member-x))
        }
      } else {
        positions.push((note: note, grace: false, x: event-center))
      }
      note-offset += note.min-width
      if note-index < measure.notes.len() - 1 {
        note-offset += note-gap-at(note-gaps, note-index)
      }
    }

    let measure-width = measure-min-width(measure, bar-width: bar-width, bar-gap: bar-gap) + extra-gap * calc.max(measure.notes.len() - 1, 0)
    row-offset += leading-gap + measure-width
  }
  positions
}

#let notation-links-from-items(items) = {
  let links = ()
  let open-slurs = ()

  for (index, item) in items.enumerate() {
    for _ in range(0, item.note.slur-start) {
      open-slurs.push(index)
    }
    for _ in range(0, item.note.slur-end) {
      if open-slurs.len() > 0 {
        let start = open-slurs.pop()
        if start < index { links.push((kind: "slur", start: start, end: index)) }
      }
    }
    if item.note.tie-start > 0 {
      let target = index + 1
      while target < items.len() and items.at(target).note.kind == "grace" {
        target += 1
      }
      if target < items.len() {
        links.push((kind: "tie", start: index, end: target))
      }
    }
  }
  links
}

#let row-link-fragments(links, row-start, row-count) = {
  let fragments = ()
  let row-end = row-start + row-count - 1
  for link in links {
    if link.start <= row-end and link.end >= row-start {
      fragments.push((
        kind: link.kind,
        start: if link.start < row-start { none } else { link.start - row-start },
        end: if link.end > row-end { none } else { link.end - row-start },
      ))
    }
  }
  fragments
}

#let grace-lift(note-head-width) = {
  note-head-width * 1.15
}

#let grace-link-min-rise(note-head-width) = {
  note-head-width * 0.28
}

#let grace-octave-extra(note, note-head-width) = {
  let scale = 0.75
  let dot-radius = note-head-width * 0.075 * scale
  let dot-gap = note-head-width * 0.12 * scale
  let max-up = note.members.fold(0, (count, member) => calc.max(count, member.octave-up))
  let max-down = note.members.fold(0, (count, member) => calc.max(count, member.octave-down))
  let upper-height = octave-dots-height(max-up, dot-radius: dot-radius, dot-gap: dot-gap)
  let lower-height = octave-dots-height(max-down, dot-radius: dot-radius, dot-gap: dot-gap)
  upper-height + lower-height
}

#let notation-link-upper-height(note, note-head-width, dot-radius, dot-gap) = {
  calc.max(
    octave-dots-height(note.octave-up, dot-radius: dot-radius, dot-gap: dot-gap),
    chord-upper-height(note, note-head-width),
  )
}

#let notation-link-item-upper-height(item, note-head-width, dot-radius, dot-gap) = {
  if item.grace {
    grace-lift(note-head-width) + grace-octave-extra(item.grace-parent, note-head-width)
  } else {
    notation-link-upper-height(item.note, note-head-width, dot-radius, dot-gap)
  }
}

#let notation-arc(width, start-y, end-y, height, thickness: 0.08em) = {
  let top-y = calc.min(start-y, end-y) - height
  let outer-y = top-y - thickness / 2
  let inner-y = top-y + thickness / 2
  let end-radius = thickness * 0.275
  let cap-control = end-radius * 4 / 3
  curve(
    fill: black,
    curve.move((0pt, start-y - end-radius)),
    curve.cubic((width * 0.28, outer-y), (width * 0.72, outer-y), (width, end-y - end-radius)),
    curve.cubic((width + cap-control, end-y - end-radius), (width + cap-control, end-y + end-radius), (width, end-y + end-radius)),
    // The return boundary stays lower, while semicircular end caps preserve a
    // small initial width instead of tapering all the way to a sharp point.
    curve.cubic((width * 0.72, inner-y), (width * 0.28, inner-y), (0pt, start-y + end-radius)),
    curve.cubic((-cap-control, start-y + end-radius), (-cap-control, start-y - end-radius), (0pt, start-y - end-radius)),
    curve.close(mode: "straight"),
  )
}

#let notation-open-arc(width, endpoint-y, height, direction, thickness: 0.08em) = {
  let peak-y = endpoint-y - height
  let outer-y = peak-y - thickness / 2
  let inner-y = peak-y + thickness / 2
  let end-radius = thickness * 0.275
  let cap-control = end-radius * 4 / 3
  if direction == "outgoing" {
    curve(
      fill: black,
      curve.move((0pt, endpoint-y - end-radius)),
      curve.cubic((width * 0.28, outer-y), (width * 0.72, outer-y), (width, outer-y)),
      // A system boundary is a cut through a continuing ribbon, not a musical
      // endpoint, so retain full thickness and close it with a flat edge.
      curve.line((width, inner-y)),
      curve.cubic((width * 0.72, inner-y), (width * 0.28, inner-y), (0pt, endpoint-y + end-radius)),
      curve.cubic((-cap-control, endpoint-y + end-radius), (-cap-control, endpoint-y - end-radius), (0pt, endpoint-y - end-radius)),
      curve.close(mode: "straight"),
    )
  } else {
    curve(
      fill: black,
      curve.move((0pt, outer-y)),
      curve.cubic((width * 0.28, outer-y), (width * 0.72, outer-y), (width, endpoint-y - end-radius)),
      curve.cubic((width + cap-control, endpoint-y - end-radius), (width + cap-control, endpoint-y + end-radius), (width, endpoint-y + end-radius)),
      curve.cubic((width * 0.72, inner-y), (width * 0.28, inner-y), (0pt, inner-y)),
      curve.line((0pt, outer-y)),
      curve.close(mode: "straight"),
    )
  }
}

#let notation-through-arc(width, baseline-y, height, thickness: 0.08em) = {
  let top-y = baseline-y - height
  let outer-y = top-y - thickness / 2
  let inner-y = top-y + thickness / 2
  curve(
    fill: black,
    curve.move((0pt, baseline-y - thickness / 2)),
    curve.cubic((width * 0.28, outer-y), (width * 0.72, outer-y), (width, baseline-y - thickness / 2)),
    curve.line((width, baseline-y + thickness / 2)),
    curve.cubic((width * 0.72, inner-y), (width * 0.28, inner-y), (0pt, baseline-y + thickness / 2)),
    curve.line((0pt, baseline-y - thickness / 2)),
    curve.close(mode: "straight"),
  )
}

#let notation-link-mode(link) = {
  if link.start != none and link.end != none { "complete" }
  else if link.start != none { "outgoing" }
  else if link.end != none { "incoming" }
  else { "through" }
}

#let notation-link-base-height(link, positions, note-head-width) = {
  let touches-grace = (link.start != none and positions.at(link.start).grace) or (link.end != none and positions.at(link.end).grace)
  if link.kind == "tie" { note-head-width * 0.42 }
  else if touches-grace { note-head-width * 0.30 }
  else { note-head-width * 0.68 }
}

#let notation-required-height(mode, t, start-y, end-y, obstacle-y) = {
  let one-minus = 1 - t
  let base-y = 0pt
  let coefficient = 0.0
  if mode == "complete" {
    let control-y = calc.min(start-y, end-y)
    base-y = one-minus * one-minus * one-minus * start-y + 3 * one-minus * one-minus * t * control-y + 3 * one-minus * t * t * control-y + t * t * t * end-y
    coefficient = 3 * t * one-minus
  } else if mode == "outgoing" {
    base-y = start-y
    coefficient = 1 - one-minus * one-minus * one-minus
  } else if mode == "incoming" {
    base-y = end-y
    coefficient = 1 - t * t * t
  }
  if coefficient <= 0.001 { 0pt } else { calc.max((base-y - obstacle-y) / coefficient, 0pt) }
}

#let notation-link-arc-height(
  link,
  positions,
  line-width,
  base-height,
  note-head-width,
  dot-radius,
  dot-gap,
  beam-gap,
  clearance,
) = {
  let mode = notation-link-mode(link)
  if mode == "through" { return base-height }
  let inset = if link.kind == "tie" { note-head-width * 0.24 } else { note-head-width * 0.10 }
  let boundary-inset = note-head-width * 0.12
  let start-item = if link.start == none { none } else { positions.at(link.start) }
  let end-item = if link.end == none { none } else { positions.at(link.end) }
  let start-x = if start-item == none { boundary-inset } else { start-item.x + inset }
  let end-x = if end-item == none { line-width - boundary-inset } else { end-item.x - inset }
  let width = calc.max(end-x - start-x, note-head-width * 0.2)
  let start-upper = if start-item == none { 0pt } else { notation-link-item-upper-height(start-item, note-head-width, dot-radius, dot-gap) }
  let end-upper = if end-item == none { 0pt } else { notation-link-item-upper-height(end-item, note-head-width, dot-radius, dot-gap) }
  let start-y = -start-upper - clearance
  let end-y = -end-upper - clearance
  let first = if link.start == none { 0 } else { link.start + 1 }
  let last = if link.end == none { positions.len() - 1 } else { link.end - 1 }
  let height = base-height

  if first <= last {
    for index in range(first, last + 1) {
      let item = positions.at(index)
      let t = calc.clamp((item.x - start-x) / width, 0.0, 1.0)
      let upper = notation-link-item-upper-height(item, note-head-width, dot-radius, dot-gap)
      let obstacle-top = if upper > 0pt { -upper } else { beam-gap }
      let required = notation-required-height(mode, t, start-y, end-y, obstacle-top - clearance)
      height = calc.max(height, required)
    }
  }
  height
}

#let grace-link(distance, direction, rise, thickness: 0.045em) = {
  let end-x = if direction == "previous" { -distance } else { distance }
  let corner = (0pt, rise)
  curve(
    stroke: thickness,
    curve.move((0pt, 0pt)),
    // Both controls sit at the theoretical right-angle corner. This keeps the
    // grace tangent vertical and the main-note tangent horizontal while making
    // the bend visibly stronger.
    curve.cubic(corner, corner, (end-x, rise)),
  )
}

#let row-grace-lift(row, note-head-width) = {
  let lift = 0pt
  for measure in row {
    for note in measure.notes {
      if note.kind == "grace" {
        lift = calc.max(
          lift,
          grace-lift(note-head-width)
            + grace-octave-extra(note, note-head-width)
            + grace-link-min-rise(note-head-width),
        )
      }
    }
  }
  lift
}

#let render-note-row(
  measure-data,
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
    note-gaps-from-extra(measure-data, extra-note-gap)
  } else {
    note-gaps
  }

  if leading-gap > 0pt {
    columns.push(leading-gap)
    cells.push([])
  }

  for (index, note) in measure-data.notes.enumerate() {
    columns.push(note.min-width)
    if note.kind == "grace" {
      let target = grace-target-index(measure-data, index, note.direction)
      let distance = if target == none { 0pt } else { note-center-distance(measure-data, actual-note-gaps, index, target) }
      // Compensate for every octave-dot row. This first pins the complete
      // grace box's bottom edge instead of letting added dots push it down.
      let nominal-grace-lift = grace-lift(note-head-width) + grace-octave-extra(note, note-head-width)
      let target-shift = if target == none { 0pt } else { grace-target-shift(note-head-width) }
      let signed-shift = if note.direction == "previous" { -target-shift } else { target-shift }
      cells.push(context {
        let grace-body = note-head(note, note-head-width: note-head-width)
        let grace-size = measure(grace-body)
        let target-size = if target == none {
          (width: 0pt, height: 0pt)
        } else {
          measure(note-head(measure-data.notes.at(target), note-head-width: note-head-width))
        }
        let main-center = target-size.height / 2
        let nominal-grace-bottom = grace-size.height - nominal-grace-lift
        // Keep a visible vertical head even when many lower dots would place
        // the measured bottom almost level with the main note's center.
        let grace-bottom = if target == none {
          nominal-grace-bottom
        } else {
          calc.min(nominal-grace-bottom, main-center - grace-link-min-rise(note-head-width))
        }
        let actual-grace-lift = grace-size.height - grace-bottom
        // Move the independent grace group slightly toward its target. The arc
        // starts at the shifted box center, so its horizontal span shrinks too.
        let endpoint-distance = calc.max(distance - target-size.width / 2 - target-shift, 0pt)
        box(width: note.min-width)[
          #align(center)[#move(dx: signed-shift, dy: -actual-grace-lift)[#grace-body]]
          #if target != none {
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
