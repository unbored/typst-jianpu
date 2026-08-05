// Public package entry point.

#import "src/parser.typ": parse-score
#import "src/geometry.typ": metrics
#import "src/layout.typ": render-inline-track, render-track
#import "src/title.typ": render-title

#let jianpu-title = render-title

#let jianpu(
  ..groups,
  font: "Arial",
  size: 12pt,
  sort-chords: true,
  justify-last: false,
  first-indent: 24pt,
  lyrics-font: none,
) = context {
  // Capture the surrounding document font before the notation switches to
  // its dedicated numeral font. Lyrics should follow body typography.
  let body-font = text.font
  let actual-lyrics-font = if lyrics-font == none { body-font } else { lyrics-font }
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
  let systems = ()
  let current = none
  for track in score.tracks {
    if track.kind == "melody" {
      if current != none { systems.push(current) }
      current = (melody: track, lyrics: ())
    } else if track.kind == "lyrics" {
      assert(current != none, message: "a lyrics track must follow a melody track")
      current = current + (lyrics: current.lyrics + (track,),)
    }
  }
  if current != none { systems.push(current) }

  layout(available => {
    // A lyrics track belongs to the nearest preceding melody track. Multiple
    // melody systems still wrap independently until multi-voice alignment is
    // implemented above this layer.
    stack(dir: ttb, spacing: geometry.group-gap,
      ..systems.map(system => {
        render-track(
          system.melody,
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
          justify-last: justify-last,
          first-indent: first-indent,
          lyric-tracks: system.lyrics,
          lyric-font: actual-lyrics-font,
        )
      }),
    )
  })
}

#let jianpu-inline(source, font: "Arial", sort-chords: true, compact: false) = context {
  let size = text.size
  set text(font: font, size: size, weight: "bold")

  let geometry = metrics(size)
  let score = parse-score(
    (source,),
    geometry.quarter-width,
    geometry.eighth-width,
    geometry.short-width,
    sort-chords,
    final-bar: false,
    compact: compact,
  )
  let melody-tracks = score.tracks.filter(track => track.kind == "melody")

  if melody-tracks.len() > 0 {
    render-inline-track(
      melody-tracks.at(0),
      geometry.min-measure-gap,
      geometry.bar-width,
      geometry.bar-gap,
      geometry.beam-gap,
      geometry.beam-note-width,
      geometry.beam-thickness,
      geometry.dot-radius,
      geometry.dot-gap,
    )
  }
}
