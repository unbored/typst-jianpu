#import "../jianpu.typ": jianpu, jianpu-inline

#set page(width: 18cm, height: 12cm, margin: 1.2cm)
#set text(font: "Noto Serif CJK SC", size: 14pt)

#text(size: 1.3em, weight: "bold")[升降号布局测试]

#jianpu(
  ```melody
  #1 b2 n3 x4 bb5 | #1'/ b2,//. n3''// #4,,// | #5( b6 7) #1'~ | #1' |
  c[#1, b3 5'] c[bb2 n4 #6]/ | g[#1, b2 n3']/// 4 |
  ```,
)

行内：#jianpu-inline("#1 b2/ n3//. #4'", compact: true) 对照文字。

#v(0.8em)

倚音八度点：

#jianpu(```melody
g[#1' b2'' n3''']/// 4 | g[#1, b2,, n3,,,]/// 4 |
g[1' #2'' 3''']/// 4 | g[1, #2,, 3,,,]/// 4 |
```)
