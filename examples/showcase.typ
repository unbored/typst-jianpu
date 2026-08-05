#import "../jianpu.typ": jianpu, jianpu-title

#set page(
  paper: "a4",
  margin: (x: 18mm, y: 14mm),
)
#set text(
  font: ("Libertinus Serif", "Noto Serif CJK SC", "SimSun"),
  size: 10.5pt,
)
#set par(leading: 0.7em)

#jianpu-title(
  [简谱排版样张],
  subtitle: [常用记谱特性综合示例],
  key: "1=G",
  meter: "4/4",
  authors: (
    (name: [示例], role: [旋律]),
    (name: [Jianpu], role: [排版]),
  ),
)

#align(right)[#emph[中速 · 明朗地]]
#v(0.5em)

#jianpu(
  size: 13pt,
  first-indent: 18pt,
  ```melody
  g[5 6]/ 1^"轻快地"( 2/ 3/ 5 | 3. 2/ 1 0 |
  5, 1/ 2/ 3~ | 3 2/ 1/ 2 - |
  t3[3 4 #4]/ 5' 6'/ 5'/ | 3' 2'/ 1'/ 6 - |
  c[1 3 5] 5/ 6/ 1' sym.harmonic | 7( 6/ 5/ 3) - |
  ```,
  ```lyrics
  晨 风 轻 轻 吹 _ 过 山 岗 _
  歌 声 随 云 飘 _ 向 远 方 _
  ```,
)

#v(0.8em)
#text(weight: "bold", size: 11pt)[反复、不同结尾与连续短音]
#v(0.25em)

#jianpu(
  size: 12.5pt,
  first-indent: 0pt,
  ```melody
  r3{
    1/ 2/ 3/ 5/ | 6// 5// 3// 2// 1. 2/ |
    a1,2{ g[#4 5]/ 6 5 | 3 2 1 - | }
    a3{ 5'/. 6'// 5'/ 3'/ | 2' 1' 1' - | }
  }
  ```,
  ```lyrics
  听 林 间 清 响 _ _ _ _ _
  让 心 中 回 声 久久 荡 漾 _
  ```,
)

#v(0.8em)
#text(weight: "bold", size: 11pt)[常用组合]
#v(0.25em)

#jianpu(
  size: 12pt,
  first-indent: 0pt,
  ```melody
  1, 2 3' 4'' | #5 b6 n7 1' |
  g[6 7]// 1' 2' g<[3' 2'] | c[1 3 5'] c[2 4 6']/ |
  1/. 2// 3/ 4// 5// | 6( 5 3) 2~ 2 |
  harmonic{ 1 2 3 4 } | 0 X - 1_"渐弱" |
  ```,
)

#v(0.7em)
#align(center)[
  #text(size: 8.5pt, fill: luma(90))[
    八度点 · 时值线 · 附点 · 变音记号 · 倚音 · 和弦 · 连奏线 · 延音线 · 泛音 · 反复记号
  ]
]
