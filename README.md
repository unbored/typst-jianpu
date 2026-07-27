# jianpu

一个正在开发中的 Typst 简谱排版插件。

内部实现按职责拆分：`src/parser.typ` 负责 raw 简谱解析与 score 模型，`src/geometry.typ` 负责由字号推导的私有尺寸；`jianpu.typ` 仍是唯一需要导入的公开入口。

## 使用方式

```typst
#import "jianpu.typ": jianpu

#jianpu(```melody
1 2 3 4 | 5/ 6/ 7/ 1/ |
```)
```

当前公开接口：

- `..groups`：一组或多组 raw 简谱代码。
- `font`：字体，默认 `Arial`。
- `size`：字号，默认 `12pt`。
- `sort-chords`：和弦是否按相对音高由低到高排列，默认开启。
- `justify`：是否对齐每一行，默认开启。
- `justify-last`：是否对齐最后一行，默认关闭。
- `first-indent`：首行缩进，默认 `24pt`。

raw 的语言标记用于声明 track 类型。当前实现会渲染 `melody`，其他类型先保留为后续扩展入口。

```typst
#jianpu(
  ```melody
  1 2 3 4 | 5 6 7 1 |
  ```,
  ```lyrics
  春 眠 不 觉 晓 | 处 处 闻 啼 鸟 |
  ```,
)
```

## 当前记谱规则

- `1` 表示四分音符宽度的音符。
- `1/` 表示八分音符，并绘制一条时值线。
- `1//` 表示十六分音符，并绘制两条时值线。
- `1///` 表示三十二分音符，并绘制三条时值线。
- `c[1 3 5]/` 表示和弦；括号内音符从下往上堆叠，括号后的时值属性作用于整个和弦。
- `1( 2 3 4)` 表示连奏线（圆滑线），从 `1` 连到 `4`。
- `1~ 1` 表示延音线，连接当前音符与后一个音符。
- 连线符号可以紧贴音符，也可以独立留空格，例如 `1 ( 2 3 4 )` 和 `1 ~ 1`。
- `-` 表示延音占位，显示为居中的自绘横线。
- `|` 表示小节线，也是唯一允许自动换行的位置。

连奏线和延音线可以跨小节与换行；行末、行首会自动绘制为相接的开放弧线片段。

当前支持的 raw 类型：

- ```melody：旋律。
- ```jianpu：兼容旧写法，按旋律处理。
- ```lyrics：歌词，占位保留，当前暂不渲染。

## 开发

编译视觉测试：

```powershell
D:\tools\typst\typst.exe compile --root . tests\visual.typ tests\visual.pdf
```

编译示例：

```powershell
D:\tools\typst\typst.exe compile --root . examples\basic.typ examples\basic.pdf
D:\tools\typst\typst.exe compile --root . examples\beams.typ examples\beams.pdf
```
