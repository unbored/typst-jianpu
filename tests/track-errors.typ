#import "../jianpu.typ": jianpu
#let case = sys.inputs.at("case")
#let adapter = (
  parse: source => source.split(" "),
  render-item: data => (body: box(width: 10pt, height: 10pt), anchor-x: 5pt),
  height: 2em,
)
#if case == "unknown" {
  jianpu(raw("one", lang: "sample"))
} else if case == "before-melody" {
  jianpu(tracks: (sample: adapter), raw("one", lang: "sample"))
} else if case == "too-many" {
  jianpu(tracks: (sample: adapter), raw("1", lang: "melody"), raw("one two", lang: "sample"))
} else if case == "height" {
  jianpu(tracks: (sample: adapter + (height: 0em)), raw("1", lang: "melody"), raw("one", lang: "sample"))
} else if case == "anchor" {
  let invalid = adapter + (render-item: data => (body: box(width: 10pt, height: 10pt), anchor-x: 20pt))
  jianpu(tracks: (sample: invalid), raw("1", lang: "melody"), raw("one", lang: "sample"))
} else if case == "reserved" {
  jianpu(tracks: (lyrics: adapter), raw("1", lang: "melody"))
} else {
  panic("unknown track test case")
}
