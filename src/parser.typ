// Source tokenization and score-model construction.

#let duration-width(token, quarter-width, eighth-width, short-width) = {
  if token.contains("///") or token.contains("//") { short-width }
  else if token.contains("/") { eighth-width }
  else { quarter-width }
}

#let slash-count(token) = { token.split("/").len() - 1 }
#let octave-up-count(token) = { token.split("'").len() - 1 }
#let octave-down-count(token) = { token.split(",").len() - 1 }

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

#let parse-note(token, quarter-width, eighth-width, short-width) = {
  let direction = first-octave-direction(token)
  let octave-up = if direction == "up" { octave-up-count(token) } else { 0 }
  let octave-down = if direction == "down" { octave-down-count(token) } else { 0 }
  let octave = octave-up - octave-down
  let pitch = pitch-index(token)
  (
    raw: token, kind: "note", members: (), beams: slash-count(token),
    pitch: pitch, octave: octave, relative-pitch: pitch + octave * 7,
    octave-up: octave-up, octave-down: octave-down,
    min-width: duration-width(token, quarter-width, eighth-width, short-width),
  )
}

#let parse-chord(token, quarter-width, eighth-width, short-width, sort-chords: true) = {
  let parts = token.split("]")
  let members = parts.at(0).slice(2).split(" ")
    .filter(member => member != "")
    .map(member => parse-note(member, quarter-width, eighth-width, short-width))
  let ordered = if sort-chords { members.sorted(key: member => member.relative-pitch) } else { members }
  let root = ordered.at(0)
  let suffix = if parts.len() > 1 { parts.at(1) } else { "" }
  let duration = parse-note("1" + suffix, quarter-width, eighth-width, short-width)
  (
    raw: root.raw, kind: "chord", members: ordered, beams: duration.beams,
    pitch: root.pitch, octave: root.octave, relative-pitch: root.relative-pitch,
    octave-up: root.octave-up, octave-down: root.octave-down, min-width: duration.min-width,
  )
}

#let parse-grace(token, quarter-width, eighth-width, short-width) = {
  let direction = if token.starts-with("g<[") { "previous" } else { "next" }
  let prefix-length = if direction == "previous" { 3 } else { 2 }
  let parts = token.split("]")
  let suffix = if parts.len() > 1 and parts.at(1) != "" { parts.at(1) } else { "//" }
  let members = parts.at(0).slice(prefix-length).split(" ")
    .filter(member => member != "")
    .map(member => parse-note(member + suffix, quarter-width, eighth-width, short-width))
  (
    raw: token, kind: "grace", members: members, direction: direction,
    beams: 0, pitch: 0, octave: 0, relative-pitch: 0,
    octave-up: 0, octave-down: 0,
    // Grace-note duration boxes and their side padding scale with the reduced
    // glyphs instead of retaining the full-size note width.
    min-width: members.fold(0pt, (width, member) => width + member.min-width * 0.45),
  )
}

#let parse-event(token, quarter-width, eighth-width, short-width, sort-chords: true) = {
  let slur-start = token.split("(").len() - 1
  let slur-end = token.split(")").len() - 1
  let tie-start = token.split("~").len() - 1
  let core = token.replace("(", "").replace(")", "").replace("~", "")
  let event = if core.starts-with("c[") and core.contains("]") {
    parse-chord(core, quarter-width, eighth-width, short-width, sort-chords: sort-chords)
  } else if (core.starts-with("g[") or core.starts-with("g<[")) and core.contains("]") {
    parse-grace(core, quarter-width, eighth-width, short-width)
  } else { parse-note(core, quarter-width, eighth-width, short-width) }
  event + (slur-start: slur-start, slur-end: slur-end, tie-start: tie-start)
}

#let parse-measures(tokens, quarter-width, eighth-width, short-width, sort-chords: true) = {
  let measures = ()
  let current = ()
  for token in tokens {
    if token == "|" { measures.push((notes: current, bar: true)); current = () }
    else { current.push(parse-event(token, quarter-width, eighth-width, short-width, sort-chords: sort-chords)) }
  }
  if current.len() > 0 { measures.push((notes: current, bar: false)) }
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

  let attached = ()
  for token in tokens {
    // Standalone LilyPond-style marks belong to the preceding event, so
    // `1 ( 2 )` and `1( 2)` produce the same parser input.
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

#let parse-track(group, quarter-width, eighth-width, short-width, sort-chords) = (
  kind: group-kind(group), source: group-text(group),
  measures: parse-measures(score-tokens(group), quarter-width, eighth-width, short-width, sort-chords: sort-chords),
)

#let parse-score(groups, quarter-width, eighth-width, short-width, sort-chords) = (
  tracks: groups.map(group => parse-track(group, quarter-width, eighth-width, short-width, sort-chords)),
)
