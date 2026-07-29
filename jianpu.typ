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
          justify-last: justify-last,
          first-indent: first-indent,
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
