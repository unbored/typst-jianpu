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

#let attach-standalone-link-marks(tokens) = {
  let attached = ()
  for token in tokens {
    let standalone-link = token == "(" or token == ")" or token == "~"
    let has-preceding-event = attached.len() > 0 and attached.at(attached.len() - 1) != "|"
    if standalone-link and has-preceding-event {
      let last = attached.at(attached.len() - 1)
      attached = attached.slice(0, attached.len() - 1) + (last + token,)
    } else {
      attached.push(token)
    }
  }
  attached
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
  let core = strip-link-marks(token)
  let direction = first-octave-direction(core)
  let octave-up = if direction == "up" { octave-up-count(core) } else { 0 }
  let octave-down = if direction == "down" { octave-down-count(core) } else { 0 }
  let octave = octave-up - octave-down
  let pitch = pitch-index(core)
  let dots = augmentation-dot-count(core)
  let base-width = duration-width(core, quarter-width, eighth-width, short-width, compact: compact)
  (
    raw: core, kind: "note", members: (), beams: slash-count(core),
    dots: dots,
    pitch: pitch, octave: octave, relative-pitch: pitch + octave * 7,
    octave-up: octave-up, octave-down: octave-down,
    // Keep augmentation-dot space separate from the note box. Layout layers
    // can then append it after the head without shifting digits or beams.
    min-width: base-width, trailing-width: base-width * dots * 0.5,
    slur-start: slur-start-count(token), slur-end: slur-end-count(token), tie-start: tie-start-count(token),
  )
}

#let parse-chord(token, quarter-width, eighth-width, short-width, sort-chords: true, compact: false) = {
  let parts = token.split("]")
  let members = parts.at(0).slice(2).split(" ")
    .filter(member => member != "")
    .map(member => parse-note(member, quarter-width, eighth-width, short-width, compact: compact))
  let ordered = if sort-chords { members.sorted(key: member => member.relative-pitch) } else { members }
  let root = ordered.at(0)
  let suffix = if parts.len() > 1 { parts.at(1) } else { "" }
  let duration = parse-note("1" + suffix, quarter-width, eighth-width, short-width, compact: compact)
  (
    raw: root.raw, kind: "chord", members: ordered, beams: duration.beams,
    dots: duration.dots,
    pitch: root.pitch, octave: root.octave, relative-pitch: root.relative-pitch,
    octave-up: root.octave-up, octave-down: root.octave-down,
    min-width: duration.min-width, trailing-width: duration.trailing-width,
    slur-start: duration.slur-start, slur-end: duration.slur-end, tie-start: duration.tie-start,
  )
}

#let parse-grace(token, quarter-width, eighth-width, short-width, compact: false) = {
  let direction = if token.starts-with("g<[") { "previous" } else { "next" }
  let prefix-length = if direction == "previous" { 3 } else { 2 }
  let parts = token.split("]")
  let outer-suffix = if parts.len() > 1 { parts.at(1) } else { "" }
  let stripped-suffix = strip-link-marks(outer-suffix)
  let duration-suffix = if stripped-suffix.contains("/") { stripped-suffix } else { "//" + stripped-suffix }
  let member-tokens = parts.at(0).slice(prefix-length).split(" ").filter(member => member != "")
  let members = attach-standalone-link-marks(member-tokens)
    .map(member => parse-note(member + duration-suffix, quarter-width, eighth-width, short-width, compact: compact))
  (
    raw: token, kind: "grace", members: members, direction: direction,
    beams: 0, dots: if members.len() > 0 { members.at(0).dots } else { 0 }, pitch: 0, octave: 0, relative-pitch: 0,
    octave-up: 0, octave-down: 0, trailing-width: 0pt,
    slur-start: slur-start-count(outer-suffix), slur-end: slur-end-count(outer-suffix), tie-start: tie-start-count(outer-suffix),
    // The rendered group uses 0.54em member boxes and 0.12em internal gaps.
    // Duration boxes may be wider, but the event must never be narrower than
    // its actual glyph group or long grace sequences will overflow both sides.
    min-width: calc.max(
      members.fold(0pt, (width, member) => width + (member.min-width + member.trailing-width) * 0.45),
      members.len() * short-width * 0.54 + calc.max(members.len() - 1, 0) * short-width * 0.12,
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

#let parse-measures(tokens, quarter-width, eighth-width, short-width, sort-chords: true, final-bar: true, compact: false) = {
  let measures = ()
  let current = ()
  for token in tokens {
    if token == "|" { measures.push((notes: current, bar: true, final-bar: false)); current = () }
    else { current.push(parse-event(token, quarter-width, eighth-width, short-width, sort-chords: sort-chords, compact: compact)) }
  }
  if current.len() > 0 { measures.push((notes: current, bar: false, final-bar: false)) }

  if final-bar and measures.len() > 0 {
    // The end bar belongs to the track rather than to the source's final `|`:
    // both terminated and unterminated raw blocks therefore render identically.
    let last = measures.pop()
    measures.push(last + (bar: true, final-bar: true))
  }
  measures
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
  let raw-tokens = group-text(score).replace(regex("\\r?\\n"), " ").replace("|", " | ").split(" ").filter(token => token != "")
  let tokens = ()
  let compound = none
  for token in raw-tokens {
    if compound != none {
      compound += " " + token
      if token.contains("]") { tokens.push(compound); compound = none }
    } else if (token.starts-with("c[") or token.starts-with("g[") or token.starts-with("g<[") ) and not token.contains("]") { compound = token }
    else { tokens.push(token) }
  }
  if compound != none { tokens.push(compound) }

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
