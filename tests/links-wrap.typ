#import "../jianpu.typ": jianpu

#set text(font: "Noto Serif CJK KR")

= 跨行连线测试

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
