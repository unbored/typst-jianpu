#import "../jianpu.typ": jianpu

#set page(width: 150mm, height: auto, margin: 14mm)
#set text(font: "Noto Serif CJK SC", size: 11pt)

= 反复记号测试

== 默认二次反复

#jianpu(```melody
r{
  1 2 3 4 | 5 6 7 1 |
}
```)

== 三次反复与次数标记

#jianpu(```melody
r3{
  1 2 3 4 | 5/ 6/ 7/ 1/ |
}
```)

== 结构边界可省略小节线

显式写出结构旁的小节线：

#jianpu(
  ```melody
  1 2 3 4 |
  r2{
    5 6 7 1 |
    a1{ 2 3 4 5 | } |
    a2{ 6 7 1' 2' | } |
  } |
  3 4 5 6 |
  ```,
  size: 10pt,
  first-indent: 0pt,
)

省略结构旁的小节线：

#jianpu(
  ```melody
  1 2 3 4
  r2{
    5 6 7 1
    a1{ 2 3 4 5 }
    a2{ 6 7 1' 2' }
  }
  3 4 5 6
  ```,
  size: 10pt,
  first-indent: 0pt,
)

== 第一、第二结尾

#jianpu(```melody
r2{
  1 2 3 4 |
  a1{ 5 6 7 1 | }
  a2{ 5 6 7 2 | }
}
```)

== 同一小节线上的结尾切换

#jianpu(
  ```melody
  r2{
    1 2 |
    a1{ 3 4 | }
    a2{ 5 6 | }
  }
  ```,
  size: 10pt,
  first-indent: 0pt,
)

== 三个结尾与共用结尾

#jianpu(```melody
r3{
  1 2 3 4 |
  a1,2{ 5 6 7 1 | }
  a3{ 5 6 7 3 | }
}
```)

== 多次共用结尾的标签写法

#jianpu(```melody
r4{
  1 2 3 4 |
  a1,2,3{ 5 6 7 1 | }
  a4{ 5 6 7 4 | }
}
r4{
  1 2 3 4 |
  a1-3{ 5 6 7 1 | }
  a4{ 5 6 7 4 | }
}
r6{
  1 2 3 4 |
  a1,2,4,5,6{ 5 6 7 1 | }
  a3{ 5 6 7 3 | }
}
```)

== 最后结尾后继续演奏

#jianpu(```melody
r2{
  1 2 3 4 |
  a1{ 5 6 7 1 | }
  a2{ 5 6 7 2 | }
}
3 4 5 6 |
```)

== 结尾内的和弦与倚音

#jianpu(```melody
r2{
  1 c[1 3 5]/ 3 4 |
  a1{ g[6 7] 1' 7, 6 | }
  a2{ 5 c[1 3 5] 2 1 | }
}
```)

== 普通段落后的反复与连续反复

#jianpu(
  ```melody
  1 2 3 4 |
  r2{ 5 6 7 1 | }
  r3{ 1' 7 6 5 | }
  ```,
  size: 10pt,
  first-indent: 0pt,
)

== 连续反复恰逢换行

#block(width: 58mm)[
  #jianpu(
    ```melody
    1 2 |
    r2{ 3 4 5 6 | }
    r3{ 1' 7 6 5 | }
    ```,
    size: 10pt,
    first-indent: 0pt,
  )
]

== 开始反复恰逢换行

#block(width: 40mm)[
  #jianpu(
    ```melody
    1 2 3 4 |
    r2{ 5 6 7 1 | }
    ```,
    size: 10pt,
    first-indent: 0pt,
  )
]

== 跨行结尾范围

#block(width: 88mm)[
  #jianpu(```melody
  r2{
    1 2 3 4 | 5 6 7 1 |
    a1{
      1/ 2/ 3/ 4/ | 5/ 6/ 7/ 1/ |
      2 3 4 5 | 6 7 1' 2' |
    }
    a2{ 5 4 3 2 | 1 - - - | }
  }
  ```)
]
