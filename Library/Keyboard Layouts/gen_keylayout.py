#!/usr/bin/env python3
"""Generate a macOS .keylayout implementing Buckwalter Arabic transliteration."""
from xml.sax.saxutils import quoteattr

# ---- US ANSI virtual key code -> (unshifted, shifted) ASCII -------------------
ASCII = {
    0:('a','A'), 1:('s','S'), 2:('d','D'), 3:('f','F'), 4:('h','H'), 5:('g','G'),
    6:('z','Z'), 7:('x','X'), 8:('c','C'), 9:('v','V'), 10:('§','±'),
    11:('b','B'), 12:('q','Q'), 13:('w','W'), 14:('e','E'), 15:('r','R'),
    16:('y','Y'), 17:('t','T'),
    18:('1','!'), 19:('2','@'), 20:('3','#'), 21:('4','$'), 22:('6','^'),
    23:('5','%'), 24:('=','+'), 25:('9','('), 26:('7','&'), 27:('-','_'),
    28:('8','*'), 29:('0',')'),
    30:(']','}'), 31:('o','O'), 32:('u','U'), 33:('[','{'), 34:('i','I'),
    35:('p','P'), 37:('l','L'), 38:('j','J'), 39:("'",'"'), 40:('k','K'),
    41:(';',':'), 42:('\\','|'), 43:(',','<'), 44:('/','?'), 45:('n','N'),
    46:('m','M'), 47:('.','>'), 50:('`','~'),
}

# Keys that emit the same thing on every layer.
SPECIAL = {
    36:'\r', 48:'\t', 49:' ', 51:'\x08', 53:'\x1b', 71:'\x1b', 76:'\r',
    65:'.', 67:'*', 69:'+', 75:'/', 78:'-', 81:'=',
    82:'0', 83:'1', 84:'2', 85:'3', 86:'4', 87:'5', 88:'6', 89:'7', 91:'8', 92:'9',
}

# ---- Buckwalter transliteration ---------------------------------------------
BW = {
    "'":'ء', '|':'آ', '>':'أ', '&':'ؤ', '<':'إ', '}':'ئ',
    'A':'ا', 'b':'ب', 'p':'ة', 't':'ت', 'v':'ث', 'j':'ج',
    'H':'ح', 'x':'خ', 'd':'د', '*':'ذ', 'r':'ر', 'z':'ز',
    's':'س', '$':'ش', 'S':'ص', 'D':'ض', 'T':'ط', 'Z':'ظ',
    'E':'ع', 'g':'غ', '_':'ـ', 'f':'ف', 'q':'ق', 'k':'ك',
    'l':'ل', 'm':'م', 'n':'ن', 'h':'ه', 'w':'و', 'Y':'ى',
    'y':'ي', 'F':'ً', 'N':'ٌ', 'K':'ٍ', 'a':'َ', 'u':'ُ',
    'i':'ِ', '~':'ّ', 'o':'ْ', '`':'ٰ', '{':'ٱ',
    # extended Buckwalter: Persian/Urdu letters
    'P':'پ', 'J':'ژ', 'V':'ڤ', 'G':'گ',
}

def bw(ch):
    return BW.get(ch, ch)

# ---- Option layer: Arabic punctuation and Arabic-Indic digits ----------------
OPT = {}
for code,(lo,_hi) in ASCII.items():
    if lo.isdigit():
        OPT[code] = chr(0x0660 + int(lo))          # ٠١٢٣٤٥٦٧٨٩
OPT[43] = '،'   # ،  Arabic comma
OPT[41] = '؛'   # ؛  Arabic semicolon
OPT[44] = '؟'   # ؟  Arabic question mark
OPT[33] = '«'   # «
OPT[30] = '»'   # »
OPT[47] = '۔'   # ۔  Arabic full stop
OPT_SHIFT = {
    23: '٪',    # ٪  Arabic percent
    24: '٫',    # ٫  Arabic decimal separator
    26: '٬',    # ٬  Arabic thousands separator
    28: '٭',    # ٭  Arabic five-pointed star
    18: '‌',    # ZWNJ
    19: '‍',    # ZWJ
}

def esc(s):
    out = []
    for c in s:
        if c in '&<>"' or ord(c) < 0x20 or ord(c) == 0x7f:
            out.append('&#x%04X;' % ord(c))
        else:
            out.append(c)
    return ''.join(out)

def keymap(index, pick):
    """pick(code, lo, hi) -> output string"""
    lines = ['        <keyMap index="%d">' % index]
    for code in sorted(set(list(ASCII) + list(SPECIAL))):
        if code in SPECIAL:
            out = SPECIAL[code]
        else:
            lo, hi = ASCII[code]
            out = pick(code, lo, hi)
        lines.append('            <key code="%d" output="%s"/>' % (code, esc(out)))
    lines.append('        </keyMap>')
    return '\n'.join(lines)

maps = [
    keymap(0, lambda c, lo, hi: bw(lo)),                                   # plain
    keymap(1, lambda c, lo, hi: bw(hi)),                                   # shift
    keymap(2, lambda c, lo, hi: bw(hi if lo.isalpha() else lo)),           # caps lock
    keymap(3, lambda c, lo, hi: OPT.get(c, bw(lo))),                       # option
    keymap(4, lambda c, lo, hi: OPT_SHIFT.get(c, bw(hi))),                 # option+shift
    keymap(5, lambda c, lo, hi: lo),                                       # cmd/ctrl
    keymap(6, lambda c, lo, hi: hi),                                       # cmd/ctrl+shift
]

DOC = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE keyboard SYSTEM "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">
<!--
    Arabic Buckwalter
    ASCII Buckwalter transliteration -> Arabic script, one keystroke per letter.
    Generated file - edit gen_keylayout.py in the repo, not this.
-->
<keyboard group="126" id="-19341" name="Arabic Buckwalter" maxout="1">
    <layouts>
        <layout first="0" last="17" modifiers="commonModifiers" mapSet="ANSI"/>
    </layouts>
    <modifierMap id="commonModifiers" defaultIndex="0">
        <keyMapSelect mapIndex="0">
            <modifier keys=""/>
        </keyMapSelect>
        <keyMapSelect mapIndex="1">
            <modifier keys="anyShift caps?"/>
        </keyMapSelect>
        <keyMapSelect mapIndex="2">
            <modifier keys="caps"/>
        </keyMapSelect>
        <keyMapSelect mapIndex="3">
            <modifier keys="anyOption caps?"/>
        </keyMapSelect>
        <keyMapSelect mapIndex="4">
            <modifier keys="anyOption anyShift caps?"/>
        </keyMapSelect>
        <keyMapSelect mapIndex="5">
            <modifier keys="command anyControl? anyOption? caps?"/>
            <modifier keys="anyControl anyOption? caps?"/>
        </keyMapSelect>
        <keyMapSelect mapIndex="6">
            <modifier keys="command anyShift anyControl? anyOption? caps?"/>
            <modifier keys="anyControl anyShift anyOption? caps?"/>
        </keyMapSelect>
    </modifierMap>
    <keyMapSet id="ANSI">
%s
    </keyMapSet>
</keyboard>
''' % '\n'.join(maps)

import sys
sys.stdout.write(DOC)
