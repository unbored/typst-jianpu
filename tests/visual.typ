#import "../jianpu.typ": jianpu, jianpu-inline, jianpu-title
#import "../src/parser.typ": parse-measures
#import "../src/tracks.typ": prepare-attached-track
#import "../src/layout.typ": apply-lyric-spacing
#import "../src/links.typ": row-event-positions

// Generic extension checks use no external package. An off-center anchor
// must scale with the box, and _ must retain its empty main-note slot.
#let sample-track = (
  parse: source => source.split(" ").map(token => if token == "_" { none } else { token }),
  render-item: data => (body: box(width: 30pt, height: 10pt)[#data], anchor-x: 5pt),
  height: 2em,
)
#context {
  set text(size: 12pt)
  let prepared = prepare-attached-track(
    (kind: "sample", source: "one _ two", syllables: (), measures: ()),
    sample-track,
    "Arial",
    12pt,
  )
  let item = prepared.syllables.first().rendered
  assert.eq(item.size.height, 24pt)
  assert(calc.abs(item.size.width - 72pt) < 0.001pt)
  assert(calc.abs(item.anchor-x - 12pt) < 0.001pt)
  assert.eq(prepared.syllables.at(1).text, none)
  assert(calc.abs(measure(item.content).width - 72pt) < 0.001pt)
  assert.eq(measure(item.content).height, 24pt)
  let melody = (measures: parse-measures(("1", "2", "3"), 24pt, 18pt, 12pt),)
  let spaced = apply-lyric-spacing(melody, (prepared,), "Arial", 8.4pt, 14pt, 5pt, 6pt)
  let positions = row-event-positions(spaced.measures, 0pt, 14pt, 5pt, 6pt)
  let distance = positions.at(2).x - positions.at(0).x
  assert(distance + 0.001pt >= item.size.width + item.gap)
}

// Model-only checks: these emit no content, but keep exact onset/duration
// semantics covered by the regular visual compilation command.
#let duration-model = parse-measures(
  ("1", "2/.", "t3[3 4 5]/"),
  24pt,
  18pt,
  12pt,
)
#let duration-notes = duration-model.at(0).notes
#assert(duration-notes.at(0).duration == (num: 1, den: 4))
#assert(duration-notes.at(1).duration == (num: 3, den: 16))
#assert(duration-notes.at(2).onset == (num: 7, den: 16))
#assert(duration-notes.at(2).duration == (num: 1, den: 12))
#assert(duration-model.at(0).duration == (num: 11, den: 16))

#set text(font: (
  "Libertinus Serif",
  "Noto Serif CJK KR",
))

#jianpu-title(
  [曲目标题],
  subtitle: [曲目副标题],
  key: "1=#F",
  meter: "4/4",
  authors: (
    (name: [张三], role: [作词]),
    (name: [李四], role: [作曲]),
  ),
)

= 核心功能测试

== 换行测试

#jianpu(
  ```melody
  1 2 3 4 | 5/ 6/ 7/ 1'/ | 1// 7// 6// 5// | 4 3 2 1 |
  1/// 3/// 5/// 1'/// | 7 6 5 4 | 3 2 1 0
  ```,
)

== 时值线测试

#jianpu(
  ```melody
  1/ 2// 3 4// | 5// 6/ 7// 1'/ | 1/// 2// 3/// 4/ |
  5/ 6/// 7/// 1'/ | 1// 2// 3/ 4 | 5 6/ 7// 1'///
  ```,
)

== 高低八度测试

#jianpu(
  ```melody
  1, 2 3' 4'' | 5,,/ 6,/ 7'/ 1''/ | 1,// 2''// 3 4 | 5', 6,' |
  ```,
)

== 升降号测试

#jianpu(
  ```melody
  #1 b2 n3 x4 bb5 | #1'/ b2,//. n3''// #4,,// | #5( b6 7) #1'~ | #1' |
  c[#1, b3 5'] c[bb2 n4 #6]/ | g[#1, b2 n3']/// 4 |
  ```,
)

== 附着符号测试

#jianpu(
  ```melody
  1 sym.harmonic 2' sym.harmonic 3''' sym.harmonic 4 sym.harmonic sym.harmonic |
  c[1 3 5' sym.harmonic]  6( sym.harmonic 7 1' sym.harmonic) |
  t3[1 sym.harmonic 2 3 sym.harmonic]/ 4 |
  c[1 sym.harmonic 3' sym.harmonic 5] c[2 4 sym.harmonic 6' sym.harmonic]/ |
  g[5, sym.harmonic 6 sym.harmonic 7' sym.harmonic]// 1 |
  ```,
)

== 泛音作用域测试

#jianpu(
  ```melody
  harmonic{
    1 2' 3/ 4// | c[1 3' 5] g[6, 7 1']/// 0 X - |
  }
  1 harmonic{ 2 c[3 5 7] g[1 2]/ } 4 |
  ```,
)

== 指令全称测试

#jianpu(
  ```melody
  h{ chord[1 3 5] grace[6 7] 1 | 2 grace<[3 4] | }
  tuplet3[1 2 3]/ 4 |
  repeat3{
    1 2 |
    alter1{ 3 4 | }
    alter2{ 5 6 | }
  }
  ```,
)

== 和弦测试

#jianpu(
  ```melody
  c[1,, 3, 5] c[5, 1, 3']/ | c[1, 3 5'] c[7 2 4] |
  ```,
)

#jianpu(sort-chords: false, ```melody
c[5' 1 3] c[1 3, 5] |
```)

== 倚音测试

#jianpu(```melody
g[6,,,( 7,, 6, 7, ]/// 1,/) | 2''( g<[3, 4)] | g[5' 6,,]/ 7 | 5,/ 5, 5
g[1 2 3] | 4 | 5,/
```)

== 连奏线与延音线测试

#jianpu(```melody
1( 2''' 3, 4,,) | 5~ 5 6'' ~ 6 7 |
1 2 3 3 ( | 6 3 4' ) | 5 6 7 1' |
1 ( 3 4 5 | 2'' ) 5~ | 5 6 |
```)

== 时值线分组测试
#jianpu(```melody
6/// 5/// 3/// 2/// 1/// 2/// 3/// 5/// 6/// 5/// 3/// 2/// 1/// 2/// 3/// 5/// | 6/// 5/// 3/// 2/// 1// 2// 3/ 5/ | 6 - |
```)

== 连音符测试

#jianpu(```melody
t3[1 1 1]/ 4 | t3[5 6 7]// 1' | t3[1/ 2// 3// 4/] 5 | t5[#1' b2 3 4 5,]/// 6 |
t3[g[6 7] 1 2]/ 3 | t3[4 5 g<[6 7]]/ 1 |
```)

== 简谱测试
=== 第一段
#jianpu(
  ```melody
  5,, | 5,, 5,, - | 6,, 1,/ 6,,/ 5,, | 5,, - 5,, |
  6,, - 1,/ 1, 2,/ | 5, - | 1,. 2,/ | 3,/ 5,/ 3, 2, | 2, - | 1,/ 2,/ 3,. 5,/ | 5, 3, 2,//. 3,/// 2,// 1,// | 6,, 1,/ 6,,/ 5,, | 1 2 | 1 1 - | X - |
  ```,
  justify-last: true,
)

== 多组 raw 输入测试

#jianpu(
  ```melody
  1 2 3 4 | 5 6 7 1 |
  ```,
  ```melody
  1/ 2/ 3/ 4/ | 5// 6// 7// 1// |
  ```,
)

== 歌词对齐测试

#jianpu(
  ```melody
  1 2 3 4 5 | 4 5 6 7 1' |
  ```,
  ```lyrics
  春眠 不 觉 晓 _  处 处 闻 啼 鸟
  ```,
  ```lyrics
  Twin-kle twin-kle lit-tle _ star how I |
  ```,
)

=== 长英文与空占位

#jianpu(
  first-indent: 0pt,
  ```melody
  1 2 3 4 | 5 6 7 1' |
  ```,
  ```lyrics
  extraordinary _ constellation sings softly
  ```,
  ```lyrics
  Inter-na-tion-al mu-sic
  ```,
)

== 音符上下文字

#jianpu(
  first-indent: 0pt,
  ```melody
  1 ^"dolce cantabile" 2' 3( 4) | 5// _"轻声进入" 6,// 7,,// 1'// |
  2 3 4 5 ^"天生我才必有用，千金散尽还复来，烹牛宰羊且为乐，会须一饮三百杯" |
  ```,
  ```melody
  1 ^"dolce cantabile" 2' 3( 4) | 5// _"轻声进入" 6,// 7,,// 1'// |
  2 3 4 5 ^"This annotation begins at the note head and wraps at the page edge when necessary" | 1 2 3 4 | 5 6 7 1 | 2 3 4 5 | 6 7 1 2
  ```,
)

=== Typst 富文本标注

#jianpu(
  first-indent: 0pt,
  ```melody
  1^[*dolce* #text(fill: red)[cantabile]] 2 3 4 |
  5_[#text(fill: blue, style: "italic")[轻声进入]] 6 7 1' |
  ```,
)

=== 跨现有乐谱行续排

#block(width: 34em)[
  #jianpu(
    first-indent: 0pt,
    ```melody
    1 2 3 4 | 5 6 7 1' ^"Continue this annotation on the next existing notation row instead of changing the musical wrapping" |
    1 2 3 4 | 5 6 7 1' |
    ```,
  )
]

=== 末行原地折行

#block(width: 34em)[
  #jianpu(
    first-indent: 0pt,
    ```melody
    1 2 3 4 | 5 6 7 1' ^"No following notation row exists, so this final annotation wraps locally" |
    ```,
  )
]

= 专项回归测试

== 标题调式兼容

// 前置写法是规范形式，后置写法作为兼容输入，二者应得到相同调式。
#jianpu-title([前置升号], key: "1=#F", meter: "2/4")
#v(1em)
#jianpu-title([后置升号兼容], key: "1=F#", meter: "2/4")
#v(1em)
#jianpu-title([前置降号], key: "1=bB", meter: "3/4")
#v(1em)
#jianpu-title([后置降号兼容], key: "1=Bb", meter: "3/4")

== 行内简谱

#text(font: "Arial", weight: "bold")[Before 123ABC #jianpu-inline("1 2/ 3//. 4'") 456After.]

#text(font: "Arial", weight: "bold", size: 18pt)[Before123 #jianpu-inline("1, 2/ 3//. 4'") 456After.]

#text(font: "Arial", weight: "bold")[普通：#jianpu-inline("1 2/ 3//. 4'")]

#text(font: "Arial", weight: "bold")[紧凑：#jianpu-inline("1 2/ 3,//. 4'", compact: true)]

#text(font: "Arial", weight: "bold")[紧凑附点方向：#jianpu-inline("1 2. 3 4/. 5 6//. 7", compact: true)]

无自动小节线：#jianpu-inline("1 2 3 4")。

仅绘制显式小节线：#jianpu-inline("1 2 | 3 4 |")。

行内连音：#jianpu-inline("t3[1 2 3]/ 4", compact: true)。

== 附点专项

// 附点与数字的距离不随时值盒宽变化。
#jianpu(first-indent: 0pt, ```melody
1. 2/. 3//. 4///. | 1 2/ 3// 4/// |
```)

// 附点应与上下八度点、时值线同时存在且互不干扰。
#jianpu(first-indent: 0pt, ```melody
1'. 2,/. 3''//. 4,,///. |
```)

// 和弦附点属于整个和弦；倚音组后缀作用于每个成员。
#jianpu(first-indent: 0pt, ```melody
c[1 3 5]/. g[6 7]//. 1. |
```)

== 升降号与倚音八度点

行内：#jianpu-inline("#1 b2/ n3//. #4'", compact: true) 对照文字。

#jianpu(```melody
g[#1' b2'' n3''']/// 4 | g[#1, b2,, n3,,,]/// 4 |
g[1' #2'' 3''']/// 4 | g[1, #2,, 3,,,]/// 4 |
```)

== 时值线四分组

#jianpu(first-indent: 0pt, ```melody
1/ 2/ 3/ 4/ 5/ 6/ 7/ 1'/ |
1// 2// 3// 4// 5// 6// 7// 1'// |
1/// 2/// 3/// 4/// 5/// 6/// 7/// 1'/// 1'/// 7/// 6/// 5/// 4/// 3/// 2/// 1/// |
6/// 5/// 3/// 2/// 1// 2// 3/ 5/ | 1/. 2// 3/. 4// |
```)

== 小节线与终止线

// 和弦堆叠高度不应改变普通小节线或终止线的高度。
#jianpu(first-indent: 0pt, ```melody
1 2 3 4 | c[1 3 5' 7''] c[2 4 6' 1'''] | 5 6 7 1' |
```)

// 无论源码末尾是否显式写 `|`，都只产生一个终止小节线。
#jianpu(first-indent: 0pt, ```melody
1 2 3 4 | 5 6 7 1'
```)

#jianpu(first-indent: 0pt, ```melody
1 2 3 4 | 5 6 7 1' |
```)

== Bravura Text 字形探针

#let probe-music-symbol(glyph, size: 1em) = text(
  font: "Bravura Text",
  fallback: false,
  size: size,
)[#glyph]
#let probe-numeral(value) = text(font: "Arial", weight: "bold")[#value]

#probe-music-symbol("\u{e262}")#h(0.08em)#probe-numeral(1)
#h(0.8em)
#probe-music-symbol("\u{e260}")#h(0.08em)#probe-numeral(2)
#h(0.8em)
#probe-music-symbol("\u{e261}")#h(0.08em)#probe-numeral(3)
#h(0.8em)
#probe-music-symbol("\u{e263}")#h(0.08em)#probe-numeral(4)
#h(0.8em)
#probe-music-symbol("\u{e264}")#h(0.08em)#probe-numeral(5)

#v(0.7em)

#probe-music-symbol("\u{e262}", size: 0.7em)
#h(0.8em)
#probe-music-symbol("\u{e262}")
#h(0.8em)
#probe-music-symbol("\u{e262}", size: 1.3em)
#h(0.8em)
#probe-music-symbol("\u{e4c0}", size: 1.4em)

== 倚音垂直间距

// 加入倚音前后，主音时值线与上下点的垂直间距应保持一致。
#jianpu(first-indent: 0pt, ```melody
1'/ 2'// 3,/ 4,// |
```)

#jianpu(first-indent: 0pt, ```melody
g[6, 7,] 1'/ 2'// 3,/ 4,// |
```)

// 主音盒宽不同，倚音组到主音字形的可见距离仍应一致。
#jianpu(first-indent: 0pt, ```melody
g[6 7] 1 | g[6 7] 2/ | g[6 7] 3// |
1 g<[2 3] | 1/ g<[2 3] | 1// g<[2 3] |
```)

== 倚音极端八度点

// 非现实的层数用于保护曲线端部、上方空间和成员对齐。
#jianpu(```melody
g[6,,,,,, 7,,,,,] 1 | 2 g<[3,,,,,, 4,,,,,] |
g[6'''''' 7''''''] 1 | 2 g<[3''''' 4''''''] |
```)

#jianpu(```melody
g[6 7] 1 | g[6' 7''] 1 | g[6''' 7''''] 1 | g[6''''' 7''''''] 1 |
```)

== 倚音内连奏与跨小节关联

#jianpu(first-indent: 0pt, ```melody
g[6,( 7,] 1) 2 | 3( g<[4, 5,)] 6 |
g[1 2 ( 3] 4) 5 | 6( g<[7 1' ) 2'] 3' |
g[1 2 3 ( 4 5 6 7]/ 1) | 2( g<[3 4 5 6 7 1' 2']/) |
```)

#jianpu(first-indent: 0pt, ```melody
1 2 g[6, 7,]/ | 1 2 |
3 4 | g<[5 6]/ 7 1' |
```)

// 关联的两个小节应一起移动，不能拆开倚音与目标主音。
#block(width: 24em)[
  #jianpu(first-indent: 0pt, ```melody
  1 2 3 4 | 5 6 g[7 1']/ | 2' 3' 4' 5' |
  ```)
]

== 跨行连线

#block(width: 22em)[
  #jianpu(first-indent: 0pt, ```melody
  1( 2 3 4 | 5 6 7 1' | 2 3 4 5 | 6 7 1' 2' | 3 4) 5 6 |
  ```)
]

#block(width: 22em)[
  #jianpu(first-indent: 0pt, ```melody
  1 2 3 4 | 5 6 7 1'~ | 1' 2' 3' 4' |
  ```)
]

== 连音符组合成员

#jianpu(```melody
t3[1 1 1]/ 4 | t3[5 6 7]// 1' | t5[1 2 3 4 5]/// 6 |
t3[1/ 2// 3// 4/] 5 | t3[1 2/] 3 4 |
t3[#1' b2 3,,]/ 4 | t3[5( 6 7)]/ 1' | t3[1. 2 3]/ 4 |
t3[c[1 3 5] 2 g[3 4]]/ 5 | t3[g<[6 7] 1 2]/ 3 |
t3[g[6 7] 1 2]/ 3 | t3[4 5 g<[6 7]]/ 1 |
t3[1 g[2 3] 4]/ 5 | t3[1 g[2' 3''] 4]/ 5 |
```)

== 反复结构

=== 默认与多次反复

#jianpu(```melody
r{ 1 2 3 4 | 5 6 7 1 | }
r3{ 1 2 3 4 | 5/ 6/ 7/ 1/ | }
```)

=== 结构边界可省略小节线

#jianpu(
  ```melody
  1 2 3 4 |
  r2{
    5 6 7 1 |
    a1{ 2 3 4 5 | } |
    a2{ 6 7 1' 2' | } |
  } |
  3 4 5 6 |
  ```,
  size: 10pt,
  first-indent: 0pt,
)

#jianpu(
  ```melody
  1 2 3 4
  r2{
    5 6 7 1
    a1{ 2 3 4 5 }
    a2{ 6 7 1' 2' }
  }
  3 4 5 6
  ```,
  size: 10pt,
  first-indent: 0pt,
)

=== 不同结尾与共享边界

#jianpu(```melody
r2{
  1 2 3 4 |
  a1{ 5 6 7 1 | }
  a2{ 5 6 7 2 | }
}
```)

#jianpu(
  ```melody
  r2{
    1 2 |
    a1{ 3 4 | }
    a2{ 5 6 | }
  }
  ```,
  size: 10pt,
  first-indent: 0pt,
)

#jianpu(```melody
r3{
  1 2 3 4 |
  a1,2{ 5 6 7 1 | }
  a3{ 5 6 7 3 | }
}
```)

=== 结尾标签归并

#jianpu(```melody
r4{
  1 2 3 4 |
  a1,2,3{ 5 6 7 1 | }
  a4{ 5 6 7 4 | }
}
r4{
  1 2 3 4 |
  a1-3{ 5 6 7 1 | }
  a4{ 5 6 7 4 | }
}
r6{
  1 2 3 4 |
  a1,2,4,5,6{ 5 6 7 1 | }
  a3{ 5 6 7 3 | }
}
```)

=== 结尾后续与组合事件

#jianpu(```melody
r2{
  1 2 3 4 |
  a1{ 5 6 7 1 | }
  a2{ 5 6 7 2 | }
}
3 4 5 6 |
```)

#jianpu(```melody
r2{
  1 c[1 3 5]/ 3 4 |
  a1{ g[6 7] 1' 7, 6 | }
  a2{ 5 c[1 3 5] 2 1 | }
}
```)

=== 连续反复与换行

#jianpu(
  ```melody
  1 2 3 4 |
  r2{ 5 6 7 1 | }
  r3{ 1' 7 6 5 | }
  ```,
  size: 10pt,
  first-indent: 0pt,
)

#block(width: 58mm)[
  #jianpu(
    ```melody
    1 2 |
    r2{ 3 4 5 6 | }
    r3{ 1' 7 6 5 | }
    ```,
    size: 10pt,
    first-indent: 0pt,
  )
]

#block(width: 40mm)[
  #jianpu(
    ```melody
    1 2 3 4 |
    r2{ 5 6 7 1 | }
    ```,
    size: 10pt,
    first-indent: 0pt,
  )
]

=== 跨行结尾范围

#block(width: 88mm)[
  #jianpu(```melody
  r2{
    1 2 3 4 | 5 6 7 1 |
    a1{
      1/ 2/ 3/ 4/ | 5/ 6/ 7/ 1/ |
      2 3 4 5 | 6 7 1' 2' |
    }
    a2{ 5 4 3 2 | 1 - - - | }
  }
  ```)
]

== 完整曲谱压力测试

#jianpu-title(
  [完整曲谱示例],
  subtitle: [综合布局压力测试],
  key: "1=C",
  meter: "2/4",
  authors: ((name: [测试作者], role: [整理]),),
)

#jianpu(
  ```melody
  1,,/ 1,. | g[5,, 5,,] 5,, 1'/// 6/// 5// 3,/ | 5,. 6/// 5/// 3// | 1,/( 6,,.) | 6,,/( 1,/) 5,,/( 6,,/) | 3,,. 3// 2// | 6/ 5/ 3 | g[1 2 3 5 6 1']/// 2' - |
  1, 2,/( 5,/) | 3,.( 5,/) | 2,.( 3,/) | 1, - | 6,,. 1,/( | 2,.) 3/ | 5,. 1,/ | 5,, - | g[6 5 3 2]/// 1/ 5,,// 6,,// 1,( | 1,) 2,/( 3,/) | 5,. 1/ | 6,/( 1) 3/ | 2 - | g[5, 5,] 5, 5,/( 6,/) | 1/( 2/) 2' | 6,/( 1) 2//( 6,//) | c[1,, 1]. c[2,, 2]/ | c[5,, 5]. 6,,// 2,,// | c[5,, 5] g[2 1 6, 5, 3,]/// 2,/ g[1, 2, 3, 5, 6, 1]/// 2/ | c[2,, 2] - | - -
  r11{6/// 5/// 3/// 2/// 1/// 2/// 3/// 5/// 6/// 5/// 3/// 2/// 1/// 2/// 3/// 5///}
  6/// 5/// 3/// 2/// 1// 2// 3/ 5/ | 6 -
  ```,
  justify-last: true,
)

== 段落测试

天地玄黃宇宙洪荒日月盈昃辰宿列張寒來暑往秋收冬藏閏餘成歲律召調陽雲騰致雨露結爲霜金生麗水玉出崐崗劍號巨闕珠稱夜光菓珎李柰菜重芥薑海鹹河淡鱗潛羽翔龍師火帝鳥官人皇始制文字乃服衣裳推位讓國有虞陶唐弔民伐罪周發殷湯坐朝問道垂拱平章愛育黎首臣伏戎羌遐迩壹體率賓歸王鳴鳳在樹白駒食場化被草木賴及萬方盖此身髮四大五常恭惟鞠養豈敢毀傷女慕貞絜男效才良知過必改得能莫忘罔談彼短靡恃己長信使可覆器欲難量墨悲絲淬詩讚羔羊景行維賢剋念作聖德建名立形端表正空谷傳聲虛堂習聽禍因惡積福緣善慶尺璧非寶寸陰是竸資父事君曰嚴與敬孝當竭力忠則盡命臨深履薄夙興溫清似蘭斯馨如松之盛川流不息淵澄取暎容止若思言辭安定篤初誠美慎終宜令榮業所基籍甚無竟學優登仕攝職從政存以甘棠去而益詠樂殊貴賤禮別尊卑上和下睦夫唱婦随外受傅訓入奉母儀諸姑伯叔猶子比兒孔懷兄弟同氣連枝交友投分切磨箴規仁慈隱惻造次弗離節義廉退顛沛匪虧性靜情逸心動神疲守眞志滿逐物意移堅持雅撡好爵自縻都邑華夏東西二京背芒面洛浮渭據涇宮殿盤鬱樓觀飛驚圖寫禽獸畫綵仙靈丙舍傍啟甲帳對楹肆筵設席鼓瑟吹笙升階納陛弁轉疑星右通廣內左達承明既集墳典亦聚羣英杜稾鍾隸漆書壁經府羅將相路俠槐卿戶封八縣家給千兵高冠陪輦驅轂振纓世祿侈富車駕肥輕策功茂實勒碑刻銘磻溪伊尹佐時阿衡奄宅曲阜微旦孰營桓公匡合濟弱扶傾綺廻漢惠說感武丁俊乂密勿多士寔寧晉楚更霸趙魏困橫假途滅虢踐土會盟何遵約法韓弊煩刑起翦頗牧用軍最精宣威沙漠馳譽丹青九州禹跡百郡秦并嶽宗恆岱禪主云亭雁門紫塞雞田赤城昆池碣石鉅野洞庭曠遠緜邈巖岫杳冥治本於農務茲稼穡俶載南畝我藝黍稷稅熟貢新勸賞黜陟孟軻敦素史魚秉直庶幾中庸勞謙謹勑聆音察理鑑貌辯色貽厥嘉猷勉其祗植省躬譏誡寵增抗極殆辱近恥林睾幸即兩䟽見機解組誰逼索居閑處沈默寂寥求古尋論散慮逍遙欣奏累遣慼謝歡招渠荷的歷園莽抽條枇杷晚翠梧桐早雕陳根委翳落葉飄颻游鵾獨運凌摩絳霄耽讀翫市寓目囊箱易輶攸畏屬耳垣𡓜具膳飡飯適口充腸飽飫享宰飢厭糟糠親戚故舊老少異粮妾御績紡侍巾帷房紈扇員潔銀燭瑋煌晝眠夕寐籃笋象床絃歌酒讌接杯舉觴矯手頓足悅豫且康嫡後嗣續祭祀烝嘗稽顙再拜悚懼恐惶牋牒簡要顧答審詳骸垢想浴執熱願涼驢騾犢特駭躍超驤誅斬賊盜捕獲叛亡布射遼丸嵇琴阮嘯恬筆倫紙鈞巧任釣釋紛利俗並皆佳妙毛施淑姿工嚬研笑年矢每催羲暉朗曜璇璣懸斡晦魄環照指薪脩祜永綏吉劭矩步引領俯仰廊廟束帶矜莊徘徊瞻眺孤陋寡聞愚蒙等誚謂語助者焉哉乎也
