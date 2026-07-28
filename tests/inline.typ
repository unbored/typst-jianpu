#import "../jianpu.typ": jianpu-inline

#set text(font: "Noto Serif CJK KR", size: 12pt)

= 行内简谱测试

#text(font: "Arial", weight: "bold")[Before 123ABC #jianpu-inline("1 2/ 3//. 4'") 456After.]

#text(font: "Arial", weight: "bold", size: 18pt)[Before123 #jianpu-inline("1, 2/ 3//. 4'") 456After.]

#text(font: "Arial", weight: "bold")[普通：#jianpu-inline("1 2/ 3//. 4'")]

#text(font: "Arial", weight: "bold")[紧凑：#jianpu-inline("1 2/ 3,//. 4'", compact: true)]

#text(font: "Arial", weight: "bold")[紧凑附点方向：#jianpu-inline("1 2. 3 4/. 5 6//. 7", compact: true)]

无自动小节线：#jianpu-inline("1 2 3 4")。

仅绘制显式小节线：#jianpu-inline("1 2 | 3 4 |")。
