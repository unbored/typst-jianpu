#import "../jianpu.typ": jianpu-title

#set page(width: 14cm, height: 12cm, margin: 1.2cm)
#set text(font: "Noto Serif CJK SC", size: 14pt)

// Prefix spelling is canonical; postfix spelling remains an input convenience
// and must render identically.
#jianpu-title([前置升号], key: "1=#F", meter: "2/4")
#v(1em)
#jianpu-title([后置升号兼容], key: "1=F#", meter: "2/4")
#v(1em)
#jianpu-title([前置降号], key: "1=bB", meter: "3/4")
#v(1em)
#jianpu-title([后置降号兼容], key: "1=Bb", meter: "3/4")
