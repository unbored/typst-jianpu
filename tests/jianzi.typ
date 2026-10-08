#import "../jianpu.typ": jianpu
#import "../../typst-jianzi/jianzi.typ": init-track

#set page(width: 150mm, height: auto, margin: 12mm)
#set text(font: "STKaiti", size: 12pt)
#let adapter = init-track()
#let qin-score = jianpu.with(tracks: (jianzi: adapter))

= 普通减字与混合注释

#qin-score(
  ```melody
  1 2 3 4 | 5 6 7 1 | 2 3 4 5 |
  ```,
  ```jianzi
  大九挑七 a{琴} a{大九,琴} a{大九,琴,九} |
  a{大九,琴,九,甲} g{大九,琴} g1{大九,a{琴,九}} _ |
  g1{琴,大九,琴} 大九 a{琴} 大九 |
  ```,
  ```lyrics
  一 二 三 四 五 六 七 八 九 十 十一 十二
  ```,
)

= 宽组合、占位与换行

#block(width: 75mm)[
  #qin-score(
    first-indent: 0pt,
    justify-last: true,
    ```melody
    1 2 | 3 4 | 5 6 | 7 1 |
    ```,
    ```jianzi
    g{大九,琴,大九,琴} _ g2{琴,大九,琴,大九} _
    g1{琴,大九,a{琴,九}} 大九 a{大九,琴,九,甲} 大九
    ```,
  )
]

= 简谱字号缩放

#qin-score(
  size: 18pt,
  ```melody
  1 2 3 4 |
  ```,
  ```jianzi
  大九 a{琴} a{大九,琴} g1{大九,a{琴,九}}
  ```,
)
