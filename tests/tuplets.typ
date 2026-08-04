#import "../jianpu.typ": jianpu, jianpu-inline

#set page(width: 18cm, height: 13cm, margin: 1.2cm)
#set text(font: "Noto Serif CJK SC", size: 14pt)

#text(size: 1.3em, weight: "bold")[连音符布局测试]

等时值简写：

#jianpu(```melody
t3[1 1 1]/ 4 | t3[5 6 7]// 1' | t5[1 2 3 4 5]/// 6 |
```)

混合时值：

#jianpu(```melody
t3[1/ 2// 3// 4/] 5 | t3[1 2/] 3 4 |
```)

其他标记与连线：

#jianpu(```melody
t3[#1' b2 3,,]/ 4 | t3[5( 6 7)]/ 1' | t3[1. 2 3]/ 4 |
t3[c[1 3 5] 2 g[3 4]]/ 5 | t3[g<[6 7] 1 2]/ 3 |
t3[g[6 7] 1 2]/ 3 | t3[4 5 g<[6 7]]/ 1 |
t3[1 g[2 3] 4]/ 5 | t3[1 g[2' 3''] 4]/ 5 |
```)

行内：#jianpu-inline("t3[1 2 3]/ 4", compact: true) 对照文字。
