#import "../jianpu.typ": jianpu

#set text(font: "Noto Serif CJK KR")

= 终止小节线测试

// 源码末尾没有 `|` 时仍应自动绘制终止小节线。
#jianpu(first-indent: 0pt, ```melody
1 2 3 4 | 5 6 7 1'
```)

// 显式的末尾 `|` 不应额外生成一个空小节。
#jianpu(first-indent: 0pt, ```melody
1 2 3 4 | 5 6 7 1' |
```)
