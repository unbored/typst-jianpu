#import "../jianpu.typ": jianpu

#set text(font: "Noto Serif CJK KR")

= 倚音极端八度点测试

// This unrealistic count guards the curve's minimum vertical head: octave
// dots may enlarge the grace box, but must never consume the curve entirely.
#jianpu(```melody
g[6,,,,,, 7,,,,,] 1 | 2 g<[3,,,,,, 4,,,,,] |
```)
