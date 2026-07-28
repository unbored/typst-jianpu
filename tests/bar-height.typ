#import "../jianpu.typ": jianpu

#set text(font: "Noto Serif CJK KR")

= 小节线高度测试

// 和弦堆叠高度不应改变普通小节线或终止线的高度。
#jianpu(first-indent: 0pt, ```melody
1 2 3 4 | c[1 3 5' 7''] c[2 4 6' 1'''] | 5 6 7 1' |
```)
