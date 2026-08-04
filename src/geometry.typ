// Internal dimensions derived from the requested notation size.

#let note-layer-metrics(
  size,
  dot-scale: 1.0,
  beam-scale: 1.0,
  layer-gap-factor: 0.16,
) = (
  dot-radius: size * 0.075 * dot-scale,
  dot-gap: size * 0.12 * dot-scale,
  beam-thickness: size * 0.04 * beam-scale,
  layer-gap: size * layer-gap-factor,
)

#let notation-size-from-head-width(note-head-width) = note-head-width / 0.7

#let metrics(size) = {
  let layers = note-layer-metrics(size)
  (
  quarter-width: size * 2,
  eighth-width: size * 1.5,
  short-width: size,
  min-measure-gap: size * 0.8,
  bar-width: size * 0.3,
  bar-gap: size * 0.35,
  beam-gap: layers.layer-gap,
  beam-note-width: size * 0.7,
  beam-thickness: layers.beam-thickness,
  dot-radius: layers.dot-radius,
  dot-gap: layers.dot-gap,
  // Keep separate notation systems visibly distinct even when neither row
  // contains octave dots, beams, grace notes, or other height-extending marks.
  row-gap: size * 2,
  group-gap: size * 1.2,
  )
}
