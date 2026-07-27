#import "../jianpu.typ": jianpu

#set text(font: "Noto Serif CJK KR")

= 倚音内连奏线测试

#jianpu(first-indent: 0pt, ```melody
g[6,( 7,] 1) 2 | 3( g<[4, 5,)] 6 |
g[1 2 ( 3] 4) 5 | 6( g<[7 1' ) 2'] 3' |
g[1 2 3 ( 4 5 6 7]/ 1) | 2( g<[3 4 5 6 7 1' 2']/) |
```)

= 跨小节倚音测试

#jianpu(first-indent: 0pt, ```melody
1 2 g[6, 7,]/ | 1 2 |
3 4 | g<[5 6]/ 7 1' |
```)

// 窄行用于确认关联的两个小节会被一起移到下一行，而不是拆开倚音与主音。
#block(width: 24em)[
  #jianpu(first-indent: 0pt, ```melody
  1 2 3 4 | 5 6 g[7 1']/ | 2' 3' 4' 5' |
  ```)
]
