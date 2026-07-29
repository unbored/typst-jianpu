// Horizontal system geometry, notation-link anchors, and curve drawing.

#import "glyphs.typ": *

#let event-head-offset(note) = {
  note.leading-width + note.min-width / 2
}

#let event-width(note) = {
  // Accidentals and augmentation dots are outer spacers. The middle box alone
  // defines the digit, octave dots, beams, and notation-link anchors.
  note.leading-width + note.min-width + note.trailing-width
}

// Minimum-width wrapping remains measure-based: rows may break only between
// measures, never between events inside a measure.
#let terminal-bar-style(unit) = (
  thin-stroke: unit * 0.14,
  thick-stroke: unit * 0.828,
  clear-gap: unit * 0.504,
)

#let repeat-bar-slot-width(bar-width) = bar-width * 3.2
#let double-repeat-bar-slot-width(bar-width) = bar-width * 4.6
#let measure-start-prefix-width(measure, bar-width, bar-gap) = if measure.repeat-start-visible {
  repeat-bar-slot-width(bar-width) + bar-gap
} else {
  0pt
}
#let measure-bar-slot-width(measure, bar-width) = {
  if measure.repeat-both { double-repeat-bar-slot-width(bar-width) }
  else if measure.repeat-end { repeat-bar-slot-width(bar-width) }
  else if measure.final-bar { bar-width * 1.75 }
  else { bar-width }
}

#let repeat-end-anchor-offset(width, bar-width, stroke, combined: false) = {
  if combined {
    let unit = width / 4.6
    let style = terminal-bar-style(unit)
    // A shared repeat boundary has two heavy strokes. The ending on the left
    // closes on the center of the left stroke.
    width / 2 - style.clear-gap / 2 - style.thick-stroke / 2
  } else {
    let unit = width / 3.2
    let style = terminal-bar-style(unit)
    let ordinary-edge-inset = unit / 2 - stroke / 2
    let thick-center = width - ordinary-edge-inset - style.thick-stroke / 2
    thick-center - style.thick-stroke / 2 - style.clear-gap - style.thin-stroke / 2
  }
}

#let repeat-next-start-anchor-offset(width, bar-width, stroke, combined: false) = {
  if combined {
    let unit = width / 4.6
    let style = terminal-bar-style(unit)
    // The following ending starts outside the right heavy stroke.
    width / 2 + style.clear-gap / 2 + style.thick-stroke
  } else {
    let unit = width / 3.2
    let thick-stroke = terminal-bar-style(unit).thick-stroke
    let ordinary-edge-inset = unit / 2 - stroke / 2
    width - ordinary-edge-inset
  }
}

#let volta-end-boundary-x(measure, span-end, bar-width, stroke, shared-next-ending: false) = {
  let slot-width = measure-bar-slot-width(measure, bar-width)
  let slot-start = span-end - slot-width
  if measure.repeat-end {
    if shared-next-ending {
      // Only an ending that starts beside this one needs the inner anchor.
      slot-start + repeat-end-anchor-offset(slot-width, bar-width, stroke, combined: measure.repeat-both)
    } else {
      // At a system break the following ending is elsewhere, so close at the
      // visible right edge of the heavy repeat stroke.
      slot-start + repeat-next-start-anchor-offset(slot-width, bar-width, stroke, combined: measure.repeat-both)
    }
  } else if measure.final-bar {
    let unit = slot-width / 1.75
    let ordinary-edge-inset = unit / 2 - stroke / 2
    // A terminal volta closes outside the heavy final stroke, not at the
    // widened final-bar slot center or on its preceding thin stroke.
    slot-start + slot-width - ordinary-edge-inset
  } else {
    slot-start + slot-width / 2
  }
}

#let volta-start-boundary-x(previous, previous-span-end, fallback, bar-width, stroke) = {
  if previous == none {
    fallback
  } else {
    let slot-width = measure-bar-slot-width(previous, bar-width)
    let slot-start = previous-span-end - slot-width
    if previous.repeat-end {
      slot-start + repeat-next-start-anchor-offset(slot-width, bar-width, stroke, combined: previous.repeat-both)
    } else {
      slot-start + slot-width / 2
    }
  }
}

#let measure-min-width(measure, bar-width: 5pt, bar-gap: 6pt) = {
  let width = 0pt
  width += measure-start-prefix-width(measure, bar-width, bar-gap)

  for note in measure.notes {
    width += event-width(note)
  }

  if measure.bar {
    width += bar-gap + measure-bar-slot-width(measure, bar-width)
  }

  width
}

#let row-min-width(row, min-measure-gap: 14pt, bar-width: 5pt, bar-gap: 6pt) = {
  let width = 0pt

  for (index, measure) in row.enumerate() {
    width += measure-min-width(measure, bar-width: bar-width, bar-gap: bar-gap)
    if index < row.len() - 1 {
      width += if row.at(index + 1).repeat-start { 0pt } else { min-measure-gap }
    }
  }

  width
}

#let row-measure-spans(row, extra-gap, min-measure-gap, bar-width, bar-gap) = {
  let spans = ()
  let offset = 0pt
  for (index, measure) in row.enumerate() {
    let leading-gap = if index == 0 or measure.repeat-start { 0pt } else { min-measure-gap + extra-gap }
    let measure-width = measure-min-width(measure, bar-width: bar-width, bar-gap: bar-gap) + extra-gap * calc.max(measure.notes.len() - 1, 0)
    let start = offset + leading-gap
    spans.push((start: start, end: start + measure-width))
    offset += leading-gap + measure-width
  }
  spans
}

#let protected-measure-boundary(left, right) = {
  let left-connects = left.notes.len() > 0 and left.notes.at(left.notes.len() - 1).kind == "grace" and left.notes.at(left.notes.len() - 1).direction == "next"
  let right-connects = right.notes.len() > 0 and right.notes.at(0).kind == "grace" and right.notes.at(0).direction == "previous"
  // Grace groups may cross a barline and must remain together. Repeat starts,
  // however, are valid system breaks and are split into end/start signs below.
  left-connects or right-connects
}

#let split-row-repeat-boundary(left, right) = {
  if left.len() == 0 or right.len() == 0 {
    return (left: left, right: right)
  }
  let last = left.at(left.len() - 1)
  let first = right.at(0)
  if last.repeat-both and first.repeat-start {
    // A same-line `:‖‖:` becomes a complete backward repeat at the previous
    // system end and a complete forward repeat at the next system start.
    left = left.slice(0, left.len() - 1) + (last + (repeat-both: false),)
    right = (first + (repeat-start-visible: true),) + right.slice(1)
  } else if first.repeat-start {
    // Mid-line parsing lets the forward-repeat sign replace the preceding
    // ordinary bar. Once a system break separates them, restore that bar at
    // the previous system end and keep the forward repeat on the next system.
    left = left.slice(0, left.len() - 1) + (last + (bar: true),)
    right = (first + (repeat-start-visible: true),) + right.slice(1)
  }
  (left: left, right: right)
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
      let protected-boundary = protected-measure-boundary(current.at(current.len() - 1), measure)
      if protected-boundary and current.len() > 1 {
        // Carry the whole grace-connected chain instead of splitting a grace
        // group from the main note in the adjacent measure.
        let carry-start = current.len() - 1
        while carry-start > 0 and protected-measure-boundary(current.at(carry-start - 1), current.at(carry-start)) {
          carry-start -= 1
        }
        if carry-start > 0 {
          let split = split-row-repeat-boundary(
            current.slice(0, carry-start),
            current.slice(carry-start) + (measure,),
          )
          rows.push(split.left)
          current = split.right
        } else {
          current = candidate
        }
      } else if protected-boundary {
        current = candidate
      } else {
        let split = split-row-repeat-boundary(current, (measure,))
        rows.push(split.left)
        current = split.right
      }
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

// A grace group occupies one layout event but contributes one link anchor per
// member. Group-level marks are folded onto its first/last member here.
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

// All painted measure layers consume the same resolved gap array. Keeping the
// fallback here prevents note, beam, and dot layers from drifting apart.
#let note-gaps-from-extra(measure, extra-note-gap) = {
  let gaps = ()
  for _ in range(0, calc.max(measure.notes.len() - 1, 0)) {
    gaps.push(extra-note-gap)
  }
  gaps
}

#let resolve-note-gaps(measure, note-gaps, extra-note-gap) = {
  if note-gaps == none { note-gaps-from-extra(measure, extra-note-gap) } else { note-gaps }
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

#let repeat-bar-dots(x, height, radius) = {
  for y in (height / 2 - radius * 2.3, height / 2 + radius * 2.3) {
    place(top + left, dx: x - radius, dy: y - radius)[
      #circle(radius: radius, fill: black)
    ]
  }
}

#let repeat-count-label(count, unit) = context {
  let body = text(font: "Libertinus Serif", size: unit * 2.4, weight: "regular")[×#count]
  // Pin the label's measured bottom above the bar instead of stacking two
  // unrelated top offsets, which previously left the small label too remote.
  move(dy: -measure(body).height - unit * 0.45, body)
}

#let measure-bar-line(
  width,
  height,
  top-offset,
  stroke,
  final: false,
  repeat-start: false,
  repeat-end: false,
  repeat-both: false,
  repeat-count: 2,
) = {
  // The bar line covers only the main-note row plus fixed upper/lower
  // extensions. Chord members, octave dots, grace notes, and beams do not
  // lengthen it. It is an overlay so it cannot alter layout.
  box(width: width, height: 0pt)[
    #place(top, dy: -top-offset)[
      #if repeat-both {
        let unit = width / 4.6
        let style = terminal-bar-style(unit)
        let dot-gap = unit * 0.38
        // `bar-width` is 0.3em, so 0.30 unit matches the 0.09em
        // augmentation-dot radius used by ordinary note heads.
        let dot-radius = unit * 0.30
        let left-thick = width / 2 - style.clear-gap / 2 - style.thick-stroke / 2
        let right-thick = width / 2 + style.clear-gap / 2 + style.thick-stroke / 2
        let dot-offset = style.thick-stroke / 2 + dot-gap + dot-radius
        box(width: width)[
          #place(top + left, dx: left-thick)[#line(length: height, angle: 90deg, stroke: style.thick-stroke)]
          #place(top + left, dx: right-thick)[#line(length: height, angle: 90deg, stroke: style.thick-stroke)]
          #repeat-bar-dots(left-thick - dot-offset, height, dot-radius)
          #repeat-bar-dots(right-thick + dot-offset, height, dot-radius)
          #if repeat-count > 2 {
            place(top + center)[
              #repeat-count-label(repeat-count, unit)
            ]
          }
        ]
      } else if repeat-start or repeat-end {
        let unit = width / 3.2
        let style = terminal-bar-style(unit)
        let dot-gap = unit * 0.38
        let dot-radius = unit * 0.30
        let ordinary-edge-inset = unit / 2 - stroke / 2
        let thick-center = if repeat-end {
          width - ordinary-edge-inset - style.thick-stroke / 2
        } else {
          ordinary-edge-inset + style.thick-stroke / 2
        }
        let thin-center = if repeat-end {
          thick-center - style.thick-stroke / 2 - style.clear-gap - style.thin-stroke / 2
        } else {
          thick-center + style.thick-stroke / 2 + style.clear-gap + style.thin-stroke / 2
        }
        let dot-center = if repeat-end {
          thin-center - style.thin-stroke / 2 - dot-gap - dot-radius
        } else {
          thin-center + style.thin-stroke / 2 + dot-gap + dot-radius
        }

        box(width: width)[
          #place(top + left, dx: thick-center)[
            #line(length: height, angle: 90deg, stroke: style.thick-stroke)
          ]
          #place(top + left, dx: thin-center)[
            #line(length: height, angle: 90deg, stroke: style.thin-stroke)
          ]
          #repeat-bar-dots(dot-center, height, dot-radius)
          #if repeat-end and repeat-count > 2 {
            place(top + center)[
              #repeat-count-label(repeat-count, unit)
            ]
          }
        ]
      } else if final {
        let unit = width / 1.75
        let style = terminal-bar-style(unit)
        let ordinary-bar-right-inset = unit / 2 - stroke / 2
        // Both the clear gap and the heavy stroke are 1.8 times the
        // initial terminal bar. Match visible right edges, including half of
        // the ordinary barline's own stroke width; all extra width extends left.
        box(width: width)[
          #place(top + right, dx: -(ordinary-bar-right-inset + style.thick-stroke + style.clear-gap))[
            #box(width: style.thin-stroke, align(center)[
              #line(length: height, angle: 90deg, stroke: style.thin-stroke)
            ])
          ]
          #place(top + right, dx: -ordinary-bar-right-inset)[
            #box(width: style.thick-stroke, align(center)[
              #line(length: height, angle: 90deg, stroke: style.thick-stroke)
            ])
          ]
        ]
      } else {
        box(width: width, align(center)[
          #line(length: height, angle: 90deg, stroke: stroke)
        ])
      }
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

#let grace-target-shift(note, center-distance, note-head-width, same-measure: true) = {
  if not same-measure {
    // A cross-measure grace group must stay on its own side of the barline.
    note-head-width * 0.14
  } else {
    let visible-gap = note-head-width * 0.18
    calc.max(center-distance - grace-group-width(note, note-head-width) / 2 - note-head-width / 2 - visible-gap, 0pt)
  }
}

#let note-center-distance(measure, note-gaps, from, to) = {
  let positions = ()
  let offset = 0pt
  for (index, note) in measure.notes.enumerate() {
    positions.push(offset + event-head-offset(note))
    offset += event-width(note)
    if index < measure.notes.len() - 1 {
      offset += note-gap-at(note-gaps, index)
    }
  }
  calc.abs(positions.at(to) - positions.at(from))
}

#let row-event-positions(row, extra-gap, min-measure-gap, bar-width, bar-gap) = {
  let positions = ()
  let row-offset = 0pt
  for (measure-index, measure) in row.enumerate() {
    let leading-gap = if measure-index == 0 or measure.repeat-start { 0pt } else { min-measure-gap + extra-gap }
    let side-gaps = measure-side-gaps(leading-gap, bar-gap, measure.bar)
    let note-gaps = note-gaps-from-extra(measure, extra-gap)
    let note-offset = row-offset + measure-start-prefix-width(measure, bar-width, bar-gap) + side-gaps.leading
    for (note-index, note) in measure.notes.enumerate() {
      positions.push((note: note, x: note-offset + event-head-offset(note), measure-index: measure-index, note-index: note-index))
      note-offset += event-width(note)
      if note-index < measure.notes.len() - 1 { note-offset += note-gap-at(note-gaps, note-index) }
    }
    let measure-width = measure-min-width(measure, bar-width: bar-width, bar-gap: bar-gap) + extra-gap * calc.max(measure.notes.len() - 1, 0)
    row-offset += leading-gap + measure-width
  }
  positions
}

#let grace-target-position(positions, index, direction) = {
  let step = if direction == "previous" { -1 } else { 1 }
  let target = index + step
  while target >= 0 and target < positions.len() {
    if positions.at(target).note.kind != "grace" { return target }
    target += step
  }
  none
}

#let row-grace-targets(row, extra-gap, min-measure-gap, bar-width, bar-gap) = {
  let positions = row-event-positions(row, extra-gap, min-measure-gap, bar-width, bar-gap)
  positions.enumerate().map(((index, item)) => {
    if item.note.kind != "grace" { none } else {
      let target = grace-target-position(positions, index, item.note.direction)
      if target == none { none } else {
        let target-item = positions.at(target)
        (distance: calc.abs(target-item.x - item.x), note: target-item.note, same-measure: target-item.measure-index == item.measure-index)
      }
    }
  })
}

// Link coordinates mirror the glyph module's grace widths and the renderer's
// target-facing shift. Do not duplicate those constants here.
#let row-link-positions(row, extra-gap, min-measure-gap, bar-width, bar-gap, note-head-width) = {
  let positions = ()
  let event-positions = row-event-positions(row, extra-gap, min-measure-gap, bar-width, bar-gap)
  for (event-index, event) in event-positions.enumerate() {
      let note = event.note
      if note.kind == "grace" {
        let target = grace-target-position(event-positions, event-index, note.direction)
        let target-shift = if target == none {
          0pt
        } else {
          let target-event = event-positions.at(target)
          let center-distance = calc.abs(target-event.x - event.x)
          grace-target-shift(note, center-distance, note-head-width, same-measure: target-event.measure-index == event.measure-index)
        }
        let signed-shift = if note.direction == "previous" { -target-shift } else { target-shift }
        let group-width = grace-group-width(note, note-head-width)
        for item in event-link-items(note) {
          let member-x = event.x + signed-shift - group-width / 2 + grace-member-center-offset(note, item.grace-index, note-head-width)
          positions.push(item + (x: member-x))
        }
      } else {
        positions.push((note: note, grace: false, x: event.x))
      }
  }
  positions
}

// Pair marks globally before mapping them back to row fragments. This lets
// slurs and ties survive wrapping without changing the score model.
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

#let grace-link-clearance(note-head-width) = {
  note-head-width * 0.14
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
    grace-lift(note-head-width) + grace-octave-extra(item.grace-parent, note-head-width) + grace-link-clearance(note-head-width)
  } else {
    notation-link-upper-height(item.note, note-head-width, dot-radius, dot-gap)
  }
}

// Filled ribbons provide rounded musical endpoints and full-width flat system
// cuts. Collision calculations below operate on their center curves.
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

// Find the smallest arch that clears every covered obstacle. Raising the whole
// curve preserves a smooth shape and avoids feature-specific detours.
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

// Grace-to-main ornamental curves remain independent of slur/tie ribbons even
// though both use measured anchors.
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
            + grace-link-clearance(note-head-width)
            + grace-link-min-rise(note-head-width),
        )
      }
    }
  }
  lift
}
