// Source tokenization and score-model construction.

#let duration-width(token, quarter-width, eighth-width, short-width, compact: false) = {
  // Compact inline notation keeps rhythmic marks, but does not widen the
  // event box merely because its written duration is longer.
  if compact { short-width }
  else if token.contains("///") or token.contains("//") { short-width }
  else if token.contains("/") { eighth-width }
  else { quarter-width }
}

#let slash-count(token) = { token.split("/").len() - 1 }
#let augmentation-dot-count(token) = { token.split(".").len() - 1 }
#let octave-up-count(token) = { token.split("'").len() - 1 }
#let octave-down-count(token) = { token.split(",").len() - 1 }
#let slur-start-count(token) = { token.split("(").len() - 1 }
#let slur-end-count(token) = { token.split(")").len() - 1 }
#let tie-start-count(token) = { token.split("~").len() - 1 }
#let strip-link-marks(token) = { token.replace("(", "").replace(")", "").replace("~", "") }

#let notation-symbol-data(source, source-index) = {
  assert(source == "sym.harmonic", message: "unknown notation symbol: " + source)
  (
    name: source.slice(4),
    category: "technique",
    placement: "above",
    priority: 300,
    source-index: source-index,
  )
}

#let event-token-data(token) = {
  let parts = token.split("@")
  (
    core: parts.at(0),
    marks: parts.slice(1).enumerate().map(((index, source)) => notation-symbol-data(source, index)),
  )
}

#let append-event-suffix(token, suffix) = {
  let parts = token.split("@")
  let core = parts.at(0) + suffix
  if parts.len() == 1 { core } else { core + "@" + parts.slice(1).join("@") }
}

// Logical time uses reduced integer fractions instead of floating-point
// values. This keeps future cross-track onset comparisons exact.
#let time-value(numerator, denominator) = {
  assert(denominator != 0, message: "time-value denominator cannot be zero")
  let numerator = if denominator < 0 { -numerator } else { numerator }
  let denominator = calc.abs(denominator)
  let left = calc.abs(numerator)
  let right = denominator
  while right != 0 {
    let remainder = calc.rem(left, right)
    left = right
    right = remainder
  }
  let divisor = calc.max(left, 1)
  (num: numerator / divisor, den: denominator / divisor)
}

#let add-time(left, right) = time-value(
  left.num * right.den + right.num * left.den,
  left.den * right.den,
)

#let scale-time(value, numerator, denominator) = time-value(
  value.num * numerator,
  value.den * denominator,
)

#let power-of-two(exponent) = {
  let result = 1
  for _ in range(0, exponent) { result *= 2 }
  result
}

#let written-time(beams, dots) = {
  let dot-power = power-of-two(dots)
  // One dot contributes 1/2, the next 1/4, and so on.
  let dot-numerator = power-of-two(dots + 1) - 1
  time-value(dot-numerator, 4 * power-of-two(beams) * dot-power)
}

#let tuplet-time-scale(number) = {
  // In the abbreviated tN form, N notes occupy the duration of the greatest
  // power of two below N: 3:2, 5–7:4, 9–15:8, and so forth.
  let normal-count = 1
  while normal-count * 2 < number { normal-count *= 2 }
  time-value(normal-count, number)
}

#let accidental-prefix(token) = {
  // Match two-character prefixes first so `bb` and `##` stay atomic.
  if token.starts-with("bb") { (kind: "double-flat", length: 2) }
  else if token.starts-with("##") { (kind: "double-sharp", length: 2) }
  else if token.starts-with("#") { (kind: "sharp", length: 1) }
  else if token.starts-with("b") { (kind: "flat", length: 1) }
  else if token.starts-with("n") { (kind: "natural", length: 1) }
  else if token.starts-with("x") { (kind: "double-sharp", length: 1) }
  else { (kind: none, length: 0) }
}

#let accidental-leading-width(accidental, short-width) = {
  if accidental == none { 0pt }
  else if accidental == "double-flat" or accidental == "double-sharp" { short-width * 0.66 }
  else { short-width * 0.50 }
}

#let attach-standalone-link-marks(tokens) = {
  let attached = ()
  for token in tokens {
    let standalone-link = token == "(" or token == ")" or token == "~"
    let standalone-symbol = token.starts-with("sym.")
    let has-preceding-event = attached.len() > 0 and attached.at(attached.len() - 1) != "|"
    if (standalone-link or standalone-symbol) and has-preceding-event {
      let last = attached.at(attached.len() - 1)
      let attachment = if standalone-symbol {
        let symbol-source = strip-link-marks(token)
        let trailing-links = token.replace(symbol-source, "")
        trailing-links + "@" + symbol-source
      } else {
        token
      }
      attached = attached.slice(0, attached.len() - 1) + (last + attachment,)
    } else {
      attached.push(token)
    }
  }
  attached
}

#let square-group-start(token) = {
  let note-group = token.starts-with("c[") or token.starts-with("g[") or token.starts-with("g<[")
  note-group or (token.starts-with("t") and token.contains("["))
}

#let square-bracket-balance(token) = {
  token.split("[").len() - token.split("]").len()
}

#let merge-square-groups(raw-tokens) = {
  let tokens = ()
  let compound = none
  let depth = 0
  for token in raw-tokens {
    if compound != none {
      compound += " " + token
      depth += square-bracket-balance(token)
      if depth == 0 {
        tokens.push(compound)
        compound = none
      }
    } else if square-group-start(token) and square-bracket-balance(token) > 0 {
      compound = token
      depth = square-bracket-balance(token)
    } else {
      tokens.push(token)
    }
  }
  if compound != none { tokens.push(compound) }
  tokens
}

#let note-group-tokens(source) = {
  let raw-tokens = source.split(" ").filter(token => token != "")
  attach-standalone-link-marks(merge-square-groups(raw-tokens))
}

#let first-octave-direction(token) = {
  for character in token {
    if character == "'" { return "up" }
    if character == "," { return "down" }
  }
  none
}

#let pitch-index(token) = {
  let head = token.at(0)
  if head == "X" { 8 }
  else if head == "0" { 0 }
  else if head == "1" { 1 }
  else if head == "2" { 2 }
  else if head == "3" { 3 }
  else if head == "4" { 4 }
  else if head == "5" { 5 }
  else if head == "6" { 6 }
  else if head == "7" { 7 }
  else { 0 }
}

#let parse-note(token, quarter-width, eighth-width, short-width, compact: false) = {
  let token-data = event-token-data(token)
  let token = token-data.core
  let core = strip-link-marks(token)
  let accidental-data = accidental-prefix(core)
  let note-core = core.slice(accidental-data.length)
  let direction = first-octave-direction(note-core)
  let octave-up = if direction == "up" { octave-up-count(note-core) } else { 0 }
  let octave-down = if direction == "down" { octave-down-count(note-core) } else { 0 }
  let octave = octave-up - octave-down
  let pitch = pitch-index(note-core)
  let dots = augmentation-dot-count(note-core)
  let duration = written-time(slash-count(note-core), dots)
  let base-width = duration-width(note-core, quarter-width, eighth-width, short-width, compact: compact)
  (
    raw: note-core, kind: "note", members: (), beams: slash-count(note-core),
    dots: dots,
    written-duration: duration, duration: duration,
    marks: token-data.marks,
    pitch: pitch, octave: octave, relative-pitch: pitch + octave * 7,
    octave-up: octave-up, octave-down: octave-down,
    accidental: accidental-data.kind,
    // Keep augmentation-dot space separate from the note box. Layout layers
    // can append it after the head, while accidentals occupy an analogous
    // leading column. Neither side changes the main head's own coordinates.
    leading-width: accidental-leading-width(accidental-data.kind, short-width),
    min-width: base-width, trailing-width: base-width * dots * 0.5,
    tuplet: none,
    slur-start: slur-start-count(token), slur-end: slur-end-count(token), tie-start: tie-start-count(token),
  )
}

#let parse-chord(token, quarter-width, eighth-width, short-width, sort-chords: true, compact: false) = {
  let token-data = event-token-data(token)
  let token = token-data.core
  let parts = token.split("]")
  let member-tokens = parts.at(0).slice(2).split(" ").filter(member => member != "")
  let members = attach-standalone-link-marks(member-tokens)
    .map(member => parse-note(member, quarter-width, eighth-width, short-width, compact: compact))
  let ordered = if sort-chords { members.sorted(key: member => member.relative-pitch) } else { members }
  let root = ordered.at(0)
  let suffix = if parts.len() > 1 { parts.at(1) } else { "" }
  let duration = parse-note("1" + suffix, quarter-width, eighth-width, short-width, compact: compact)
  (
    raw: root.raw, kind: "chord", members: ordered, beams: duration.beams,
    dots: duration.dots,
    written-duration: duration.written-duration, duration: duration.duration,
    marks: token-data.marks,
    pitch: root.pitch, octave: root.octave, relative-pitch: root.relative-pitch,
    octave-up: root.octave-up, octave-down: root.octave-down,
    accidental: root.accidental,
    leading-width: members.fold(0pt, (width, member) => calc.max(width, member.leading-width)),
    min-width: duration.min-width, trailing-width: duration.trailing-width,
    tuplet: none,
    slur-start: duration.slur-start, slur-end: duration.slur-end, tie-start: duration.tie-start,
  )
}

#let parse-grace(token, quarter-width, eighth-width, short-width, compact: false) = {
  let token-data = event-token-data(token)
  let token = token-data.core
  let direction = if token.starts-with("g<[") { "previous" } else { "next" }
  let prefix-length = if direction == "previous" { 3 } else { 2 }
  let parts = token.split("]")
  let outer-suffix = if parts.len() > 1 { parts.at(1) } else { "" }
  let stripped-suffix = strip-link-marks(outer-suffix)
  let duration-suffix = if stripped-suffix.contains("/") { stripped-suffix } else { "//" + stripped-suffix }
  let member-tokens = parts.at(0).slice(prefix-length).split(" ").filter(member => member != "")
  let members = attach-standalone-link-marks(member-tokens)
    .map(member => parse-note(append-event-suffix(member, duration-suffix), quarter-width, eighth-width, short-width, compact: compact))
  assert(token-data.marks.len() == 0, message: "symbols on grace groups are not supported yet")
  let visible-group-width = members.fold(0pt, (width, member) => width + short-width * 0.54 + member.leading-width * 0.75)
  visible-group-width += calc.max(members.len() - 1, 0) * short-width * 0.12
  (
    raw: token, kind: "grace", members: members, direction: direction,
    beams: 0, dots: if members.len() > 0 { members.at(0).dots } else { 0 }, pitch: 0, octave: 0, relative-pitch: 0,
    // Grace members retain their written durations for drawing, while the
    // grace event itself occupies no position on the main musical timeline.
    written-duration: time-value(0, 1), duration: time-value(0, 1),
    marks: token-data.marks,
    octave-up: 0, octave-down: 0, accidental: none, leading-width: 0pt, trailing-width: 0pt,
    tuplet: none,
    slur-start: slur-start-count(outer-suffix), slur-end: slur-end-count(outer-suffix), tie-start: tie-start-count(outer-suffix),
    // The rendered group uses 0.54em member boxes and 0.12em internal gaps.
    // Duration boxes may be wider, but the event must never be narrower than
    // its actual glyph group or long grace sequences will overflow both sides.
    min-width: calc.max(
      members.fold(0pt, (width, member) => width + (member.leading-width + member.min-width + member.trailing-width) * 0.45),
      visible-group-width,
    ),
  )
}

#let parse-event(token, quarter-width, eighth-width, short-width, sort-chords: true, compact: false) = {
  if token.starts-with("c[") and token.contains("]") {
    parse-chord(token, quarter-width, eighth-width, short-width, sort-chords: sort-chords, compact: compact)
  } else if (token.starts-with("g[") or token.starts-with("g<[")) and token.contains("]") {
    parse-grace(token, quarter-width, eighth-width, short-width, compact: compact)
  } else { parse-note(token, quarter-width, eighth-width, short-width, compact: compact) }
}

#let parse-tuplet(token, id, quarter-width, eighth-width, short-width, sort-chords: true, compact: false) = {
  let opening = token.split("[")
  assert(opening.len() >= 2, message: "tuplet must use tN[...] format")
  let number-source = opening.at(0).slice(1)
  assert(number-source != "", message: "tuplet number is required")
  let number = int(number-source)
  assert(number >= 2, message: "tuplet number must be at least 2")

  // The last closing bracket belongs to the tuplet itself; earlier brackets
  // may belong to chord or grace members nested inside the group.
  let after-opening = opening.slice(1).join("[")
  let closing = after-opening.split("]")
  assert(closing.len() >= 2, message: "unclosed tuplet group")
  let suffix = closing.at(closing.len() - 1)
  let body = closing.slice(0, closing.len() - 1).join("]")
  assert(not body.contains("|"), message: "tuplets cannot cross a barline yet")
  assert(suffix.replace("/", "") == "", message: "a tuplet group suffix may contain duration slashes only")

  let member-tokens = note-group-tokens(body)
  assert(member-tokens.len() >= 2, message: "a tuplet must contain at least two events")
  assert(not member-tokens.any(member => member.starts-with("t") and member.contains("[")), message: "nested tuplets are not supported yet")
  if suffix != "" {
    assert(not member-tokens.any(member => strip-link-marks(member).contains("/")), message: "do not mix member durations with a tuplet group suffix")
  }

  let time-scale = tuplet-time-scale(number)
  member-tokens.enumerate().map(((index, member)) => {
    let event = parse-event(append-event-suffix(member, suffix), quarter-width, eighth-width, short-width, sort-chords: sort-chords, compact: compact)
    event + (
      duration: scale-time(event.duration, time-scale.num, time-scale.den),
      tuplet: (
        id: id,
        number: number,
        index: index,
        count: member-tokens.len(),
        time-scale: time-scale,
      ),
    )
  })
}

#let plain-measure(notes, bar) = {
  let onset = time-value(0, 1)
  let timed-notes = ()
  for note in notes {
    timed-notes.push(note + (onset: onset,))
    onset = add-time(onset, note.duration)
  }
  (notes: timed-notes, duration: onset, bar: bar, final-bar: false)
}

#let parse-measures(tokens, quarter-width, eighth-width, short-width, sort-chords: true, final-bar: true, compact: false) = {
  let measures = ()
  let current = ()
  let repeats = ()
  let repeat = none
  let alternative = none
  let tuplet-id = 0

  for token in tokens {
    let repeat-open = token.starts-with("r") and token.ends-with("{")
    let alternative-open = token.starts-with("a") and token.ends-with("{")

    if token == "|" {
      if current.len() > 0 {
        measures.push(plain-measure(current, true))
        current = ()
      }
      // `r{...}` and `aN{...}` already create barline-aligned boundaries.
      // A neighboring explicit `|` is therefore accepted as redundant syntax
      // instead of producing an empty measure after a closing brace.
    } else if repeat-open {
      assert(repeat == none, message: "nested repeat blocks are not supported yet")
      if current.len() > 0 {
        measures.push(plain-measure(current, false))
        current = ()
      } else if measures.len() > 0 and measures.at(measures.len() - 1).bar {
        // `rN{` supplies the boundary itself. Remove a preceding ordinary bar
        // so a mid-track repeat does not render two adjacent barlines.
        let preceding = measures.pop()
        measures.push(preceding + (bar: false))
      }
      let count-source = token.slice(1, token.len() - 1)
      let count = if count-source == "" { 2 } else { int(count-source) }
      assert(count >= 2, message: "repeat count must be at least 2")
      repeat = (count: count, start: measures.len(), alternatives: ())
    } else if alternative-open {
      assert(repeat != none and alternative == none, message: "an alternative ending must be inside a repeat block")
      if current.len() > 0 {
        measures.push(plain-measure(current, true))
        current = ()
      }
      alternative = (label: token.slice(1, token.len() - 1), start: measures.len())
    } else if token == "}" {
      if alternative != none {
        if current.len() > 0 {
          measures.push(plain-measure(current, true))
          current = ()
        }
        assert(measures.len() > alternative.start, message: "an alternative ending cannot be empty")
        let finished = alternative + (end: measures.len() - 1)
        repeat = repeat + (alternatives: repeat.alternatives + (finished,))
        alternative = none
      } else {
        assert(repeat != none, message: "unexpected structural closing brace")
        if current.len() > 0 {
          measures.push(plain-measure(current, true))
          current = ()
        }
        assert(measures.len() > repeat.start, message: "a repeat block cannot be empty")
        repeats.push(repeat + (end: measures.len() - 1))
        repeat = none
      }
    } else if token.starts-with("t") and token.contains("[") {
      let members = parse-tuplet(token, tuplet-id, quarter-width, eighth-width, short-width, sort-chords: sort-chords, compact: compact)
      for member in members { current.push(member) }
      tuplet-id += 1
    } else {
      current.push(parse-event(token, quarter-width, eighth-width, short-width, sort-chords: sort-chords, compact: compact))
    }
  }
  assert(repeat == none and alternative == none, message: "unclosed repeat or alternative block")
  if current.len() > 0 { measures.push(plain-measure(current, false)) }

  let enriched = ()
  for (index, measure) in measures.enumerate() {
    let repeat-start = false
    let repeat-end = false
    let repeat-count = 2
    let volta = none
    let volta-start = false
    let volta-end = false
    let volta-last = false

    for repetition in repeats {
      if index == repetition.start { repeat-start = true }
      if repetition.alternatives.len() == 0 {
        if index == repetition.end {
          repeat-end = true
          repeat-count = repetition.count
        }
      } else {
        for (alternative-index, ending) in repetition.alternatives.enumerate() {
          if index >= ending.start and index <= ending.end {
            volta = ending.label
            volta-start = index == ending.start
            volta-end = index == ending.end
            volta-last = alternative-index == repetition.alternatives.len() - 1
            if volta-end and not volta-last {
              repeat-end = true
              repeat-count = repetition.count
            }
          }
        }
      }
    }

    let is-last = index == measures.len() - 1
    // An end-repeat bar replaces the automatic terminal bar. The final
    // alternative instead receives the normal terminal bar when it ends the
    // track, which also lets its volta bracket close naturally.
    let actual-final = final-bar and is-last and not repeat-end
    enriched.push(measure + (
      bar: measure.bar or repeat-end or actual-final,
      final-bar: actual-final,
      repeat-start: repeat-start,
      repeat-end: repeat-end,
      repeat-count: repeat-count,
      volta: volta,
      volta-start: volta-start,
      volta-end: volta-end,
      volta-last: volta-last,
    ))
  }
  let combined = ()
  for (index, measure) in enriched.enumerate() {
    let repeat-both = measure.repeat-end and index + 1 < enriched.len() and enriched.at(index + 1).repeat-start
    // A repeat beginning with the whole track needs no opening sign: the end
    // repeat naturally sends playback back to the beginning. Later starts
    // remain visible unless they share a combined boundary with a prior end.
    let start-visible = measure.repeat-start and index > 0 and not enriched.at(index - 1).repeat-end
    combined.push(measure + (
      repeat-both: repeat-both,
      repeat-start-visible: start-visible,
    ))
  }
  combined
}

#let group-text(group) = {
  if type(group) == str { group }
  else if type(group) == content { group.text }
  else { str(group) }
}

#let group-kind(group) = {
  if type(group) == content and "lang" in group.fields() and group.lang != none {
    if group.lang == "jianpu" { "melody" } else { group.lang }
  } else { "melody" }
}

#let score-tokens(score) = {
  let raw-tokens = group-text(score)
    .replace(regex("\\r?\\n"), " ")
    .replace("|", " | ")
    // Opening braces remain attached to `rN`/`aN`; closing braces are
    // structural tokens. Square-bracket note groups are left untouched.
    .replace("{", "{ ")
    .replace("}", " } ")
    .split(" ")
    .filter(token => token != "")
  let tokens = merge-square-groups(raw-tokens)

  // Standalone LilyPond-style marks belong to the preceding event, so
  // `1 ( 2 )` and `1( 2)` produce the same parser input.
  attach-standalone-link-marks(tokens)
}

#let parse-track(group, quarter-width, eighth-width, short-width, sort-chords, final-bar: true, compact: false) = (
  kind: group-kind(group), source: group-text(group),
  measures: parse-measures(score-tokens(group), quarter-width, eighth-width, short-width, sort-chords: sort-chords, final-bar: final-bar, compact: compact),
)

#let parse-score(groups, quarter-width, eighth-width, short-width, sort-chords, final-bar: true, compact: false) = (
  tracks: groups.map(group => parse-track(group, quarter-width, eighth-width, short-width, sort-chords, final-bar: final-bar, compact: compact)),
)
