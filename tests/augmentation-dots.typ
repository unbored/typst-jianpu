#import "../jianpu.typ": jianpu

#set text(font: "Noto Serif CJK KR")

= 附点测试

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
