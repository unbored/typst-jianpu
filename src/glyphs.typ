// Local notation glyphs and their intrinsic geometry.

#let note-text(note) = {
  // The rendered head is currently the first character. Suffixes are parsed
  // as attributes and intentionally not shown yet.
  note.raw.at(0)
}

#let accidental-text(accidental) = {
  if accidental == "flat" { "\u{e260}" }
  else if accidental == "natural" { "\u{e261}" }
  else if accidental == "sharp" { "\u{e262}" }
  else if accidental == "double-sharp" { "\u{e263}" }
  else if accidental == "double-flat" { "\u{e264}" }
  else { "" }
}

#let accidental-head(note, body, visible-body, slot-width, scale: 1.0) = context {
  let visible-size = measure(visible-body)
  let symbol = text(
    font: "Bravura Text",
    fallback: false,
    size: 1.4em * scale,
  )[#accidental-text(note.accidental)]
  let symbol-size = measure(symbol)
  let gap = 0.08em * scale

  // The accidental overflows into its separately allocated leading column.
  // The returned box keeps the original head dimensions, so octave dots,
  // beams, chords, and links continue to use the numeral's center.
  box(width: slot-width, height: visible-size.height)[
    #align(center)[#body]
    #if note.accidental != none {
      place(
        top + left,
        dx: slot-width / 2 - visible-size.width / 2 - gap - symbol-size.width,
        dy: (visible-size.height - symbol-size.height) / 2,
      )[#symbol]
    }
  ]
}

#let augmented-head(note, body, visible-body, slot-width, scale: 1.0) = context {
  let visible-size = measure(visible-body)
  let radius = 0.09em * scale
  let head-gap = 0.20em * scale
  let dot-gap = 0.10em * scale
  let dot-top = visible-size.height * 0.60 - radius

  // The duration box grows with the dot, but the main digit remains centered
  // in its original head slot. Dot-to-digit spacing therefore never depends
  // on whether the note is a quarter, eighth, or shorter duration.
  box(width: slot-width, height: visible-size.height)[
    #align(center)[
      #if note.kind == "chord" { body } else {
        accidental-head(note, body, visible-body, slot-width, scale: scale)
      }
    ]
    #for index in range(0, note.dots) {
      place(
        top + left,
        dx: slot-width / 2 + visible-size.width / 2 + head-gap + index * (radius * 2 + dot-gap),
        dy: dot-top,
      )[
        #circle(radius: radius, fill: black)
      ]
    }
  ]
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

// Chord geometry is intrinsic to the stacked head. Layout code only needs the
// resulting upper extent and must not reconstruct member offsets itself.
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
    #align(center)[
      #accidental-head(member, note-text(member), note-text(member), note-head-width)
    ]
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
    #align(center)[
      #accidental-head(root, note-text(root), note-text(root), note-head-width)
    ]
    #for index in range(1, note.members.len()) {
      place(top, dy: -chord-member-offset(note, index, note-head-width))[
        #chord-member-head(note.members.at(index), note-head-width)
      ]
    }
  ]
}

// Ordinary notes, chords, and grace groups share these dot primitives so dot
// size and vertical accumulation remain consistent across renderers.
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

// These functions are the canonical horizontal model for grace groups.
// Occupancy, link anchors, and beam width must derive from them or long groups
// will accumulate visible drift.
#let grace-member-width(note-head-width) = {
  note-head-width / 0.7 * 0.75 * 0.72
}

#let grace-member-gap(note-head-width) = {
  note-head-width / 0.7 * 0.12
}

#let grace-member-leading-width(member) = {
  member.leading-width * 0.75
}

#let grace-member-slot-width(member, note-head-width) = {
  grace-member-leading-width(member) + grace-member-width(note-head-width)
}

#let grace-member-slot(member, note-head-width, body, height: auto, alignment: center) = {
  let leading-width = grace-member-leading-width(member)
  let member-width = grace-member-width(note-head-width)
  let body-cell = if height == auto {
    box(width: member-width, align(alignment)[#body])
  } else {
    box(width: member-width, height: height, align(alignment)[#body])
  }
  // Every grace layer uses these exact two columns. In particular, octave
  // dots must not reproduce the accidental offset with an independent place.
  if height == auto {
    grid(columns: (leading-width, member-width), gutter: 0pt, [], body-cell)
  } else {
    grid(columns: (leading-width, member-width), rows: (height,), gutter: 0pt, [], body-cell)
  }
}

#let grace-group-width(note, note-head-width) = {
  let width = note.members.fold(0pt, (width, member) => width + grace-member-slot-width(member, note-head-width))
  width += calc.max(note.members.len() - 1, 0) * grace-member-gap(note-head-width)
  width
}

#let grace-member-center-offset(note, index, note-head-width) = {
  let offset = 0pt
  for preceding in note.members.slice(0, index) {
    offset += grace-member-slot-width(preceding, note-head-width) + grace-member-gap(note-head-width)
  }
  let member = note.members.at(index)
  offset + grace-member-leading-width(member) + grace-member-width(note-head-width) / 2
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
  let first-center = if note.members.len() > 0 { grace-member-center-offset(note, 0, note-head-width) } else { 0pt }
  let last-center = if note.members.len() > 0 { grace-member-center-offset(note, note.members.len() - 1, note-head-width) } else { 0pt }
  let beam-left = first-center - member-width / 2
  let beam-width = if note.members.len() <= 1 { member-width } else { last-center - first-center + member-width }
  stack(dir: ttb, spacing: 0.08em,
    stack(dir: ltr, spacing: member-gap,
      ..note.members.map(member => grace-member-slot(
        member,
        note-head-width,
        octave-dots(member.octave-up, dot-radius: dot-radius, dot-gap: dot-gap),
        height: octave-dots-height(max-up, dot-radius: dot-radius, dot-gap: dot-gap),
        alignment: center + bottom,
      )),
    ),
    align(center)[
      #stack(dir: ltr, spacing: member-gap,
        ..note.members.map(member => {
          let body = text(size: scale * 1em)[#note-text(member)]
          grace-member-slot(
            member,
            note-head-width,
            augmented-head(member, body, body, member-width, scale: scale),
          )
        }),
      )
    ],
    ..range(0, beams).map(_ => align(center)[
      #box(width: group-width)[
        #place(left, dx: beam-left)[
          #line(length: beam-width, stroke: 0.04em)
        ]
      ]
    ]),
    stack(dir: ltr, spacing: member-gap,
      ..note.members.map(member => grace-member-slot(
        member,
        note-head-width,
        octave-dots(member.octave-down, dot-radius: dot-radius, dot-gap: dot-gap),
        height: octave-dots-height(max-down, dot-radius: dot-radius, dot-gap: dot-gap),
        alignment: center + top,
      )),
    ),
  )
}

// Single dispatch point for every event head painted by the layout module.
#let note-head(note, note-head-width: 12pt) = {
  if note.kind == "grace" {
    box(width: note-head-width, align(center)[#grace-head(note, note-head-width)])
  } else {
    let body = if note.kind == "chord" {
      chord-head(note, note-head-width: note-head-width)
    } else if is-extension-note(note) {
      extension-line()
    } else {
      note-text(note)
    }
    let visible-body = if note.kind == "chord" and note.members.len() > 0 {
      note-text(note.members.at(0))
    } else {
      note-text(note)
    }
    augmented-head(note, body, visible-body, note-head-width)
  }
}

#let beam-line(length: 0.7em, thickness: 0.8pt) = {
  line(length: length, stroke: thickness)
}

#let tuplet-mark(width, endpoint-y, arc-height, number, note-head-width, thickness: 0.6pt) = context {
  let label = text(
    font: "New Computer Modern",
    size: note-head-width * 0.82,
    style: "italic",
    weight: "bold",
  )[#number]
  let label-size = measure(label)
  let label-gap = note-head-width * 0.16
  let gap-width = label-size.width + label-gap * 2
  let left-end = calc.max(width / 2 - gap-width / 2, width * 0.2)
  let right-start = calc.min(width / 2 + gap-width / 2, width * 0.8)
  let peak-y = endpoint-y - arc-height

  // Tuplet arcs are deliberately thinner and shallower than slurs. Two
  // separate cubic segments leave a real central gap for the number.
  box(width: width, height: 0pt)[
    #place(top + left)[
      #curve(
        stroke: thickness,
        fill: none,
        curve.move((0pt, endpoint-y)),
        curve.cubic((left-end * 0.28, peak-y), (left-end * 0.72, peak-y), (left-end, peak-y)),
      )
    ]
    #place(top + left)[
      #curve(
        stroke: thickness,
        fill: none,
        curve.move((right-start, peak-y)),
        curve.cubic(
          (right-start + (width - right-start) * 0.28, peak-y),
          (right-start + (width - right-start) * 0.72, peak-y),
          (width, endpoint-y),
        ),
      )
    ]
    #place(
      top + left,
      dx: width / 2 - label-size.width / 2,
      dy: peak-y - label-size.height * 0.62,
    )[#label]
  ]
}
