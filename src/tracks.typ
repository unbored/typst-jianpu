// Extension output is measured once before wrapping. Layout sees only boxes
// and asymmetric anchors, never the extension's syntax or member structure.
#let prepare-attached-track(track, descriptor, body-font, note-size) = {
  let parsed = (descriptor.parse)(track.source)
  assert(type(parsed) == array, message: "track parse must return an array")
  // Resolve em against the score size explicitly: context text.size still
  // refers to surrounding prose even after a local set text rule.
  let target-height = descriptor.at("height", default: 1em)
  let target-gap = descriptor.at("gap", default: 0.2em)
  let height = target-height.abs + target-height.em * note-size
  let gap = target-gap.abs + target-gap.em * note-size
  assert(height > 0pt, message: "track height must be positive")
  assert(gap >= 0pt, message: "track gap must not be negative")
  let items = parsed.map(data => {
    if data == none {
      (text: none, hyphen-after: false, line-height: height)
    } else {
      let result = (descriptor.render-item)(data)
      assert(type(result) == dictionary and "body" in result and "anchor-x" in result,
        message: "render-item must return (body: content, anchor-x: length)")
      assert(type(result.body) == content and type(result.anchor-x) == length,
        message: "invalid track body or anchor-x")
      let body = text(font: body-font, size: note-size, weight: "regular")[#result.body]
      let bounds = measure(body)
      let anchor = result.anchor-x.abs + result.anchor-x.em * note-size
      assert(bounds.height > 0pt and bounds.width > 0pt,
        message: "track body must have positive width and height")
      assert(anchor >= 0pt and anchor <= bounds.width,
        message: "track anchor-x must lie inside the body")
      let factor = height / bounds.height
      let width = bounds.width * factor
      let scaled = box(width: width, height: height, baseline: 0pt,
        scale(factor * 100%, origin: top + left, reflow: true, body))
      (
        text: "", hyphen-after: false, line-height: height,
        rendered: (
          content: scaled, size: (width: width, height: height),
          anchor-x: anchor * factor, gap: gap,
        ),
      )
    }
  })
  track + (syllables: items,)
}

#let validate-track-descriptors(tracks) = {
  assert(type(tracks) == dictionary, message: "tracks must be a dictionary")
  for (kind, descriptor) in tracks {
    assert(not (kind in ("melody", "jianpu", "lyrics")),
      message: "built-in track types cannot be overridden")
    assert(type(descriptor) == dictionary and "parse" in descriptor and "render-item" in descriptor,
      message: "a track descriptor requires parse and render-item")
    assert(type(descriptor.parse) == function and type(descriptor.render-item) == function,
      message: "track parse and render-item must be functions")
    assert(type(descriptor.at("height", default: 1em)) == length and
      type(descriptor.at("gap", default: 0.2em)) == length,
      message: "track height and gap must be lengths")
  }
}
