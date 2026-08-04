// Internal dimensions derived from the requested notation size.

// Every independently visible rule uses at least this relative stroke. Filled
// shapes may still use a thinner auxiliary outline because their body already
// supplies the visible weight.
#let minimum-line-thickness = 0.04em
#let minimum-line-thickness-factor = 0.04

// The repeat-count label (`×3`, etc.) establishes the smallest readable size
// for textual marks above the notation. Note digits and musical symbols are
// not annotations and therefore do not use this floor.
#let minimum-mark-text-size = 0.72em
#let minimum-mark-text-factor = 0.72

#let note-layer-metrics(
  size,
  dot-scale: 1.0,
  beam-scale: 1.0,
  layer-gap-factor: 0.16,
) = (
  dot-radius: size * 0.075 * dot-scale,
  dot-gap: size * 0.12 * dot-scale,
  beam-thickness: calc.max(size * 0.04 * beam-scale, size * minimum-line-thickness-factor),
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
