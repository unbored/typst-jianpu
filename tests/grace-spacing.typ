#import "../jianpu.typ": jianpu

#set text(font: "Noto Serif CJK KR")

= 倚音小节垂直间距测试

// 两行主音的时值线、上点和下点应保持相同的垂直间距。
#jianpu(first-indent: 0pt, ```melody
1'/ 2'// 3,/ 4,// |
```)

#jianpu(first-indent: 0pt, ```melody
g[6, 7,] 1'/ 2'// 3,/ 4,// |
```)

= 不同时值主音的倚音距离

// 主音盒宽不同，但倚音数字组到主音字形的可见间距应一致。
#jianpu(first-indent: 0pt, ```melody
g[6 7] 1 | g[6 7] 2/ | g[6 7] 3// |
1 g<[2 3] | 1/ g<[2 3] | 1// g<[2 3] |
```)
