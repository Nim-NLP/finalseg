# finalseg
# Copyright zhoupeng
# jieba's finalseg port to nim

import tables
import sugar
import regex
import unicode
import finalseg/prob_start
import finalseg/prob_trans
import finalseg/prob_emit
import sequtils
import strutils except split
import times
import unicode
import unicodedb/scripts
# import critbits

const
    MIN_FLOAT = -3.14e100
    BMES = "BMES"

type
    ProbStart = OrderedTableRef[char, float]
    ProbTrans = OrderedTableRef[char, OrderedTableRef[char, float]]
    ProbEmit = OrderedTableRef[char, OrderedTableRef[string, float]]
    # ProbEmit = CritBitTree[float] 
    ProbState =  tuple[prob: float, state: char]
    ProbState2 = tuple[prob: float, state: seq[char]]

var Force_Split_Words = newSeq[string]()

# proc getOrDefault[T](c: CritBitTree[T]; key: string,def:T):T =
#     if c.hasKey(key):
#         result = c[key]
#     else:
#         result = def

proc isHan(r: Rune): bool =
  # fast ascii check followed by unicode check
  result = r.int > 127 and r.unicodeScript() == sptHan

proc containsHan(s: string): bool =
  for r in s.runes:
    if r.isHan:
        result = true
        break

iterator splitHan(s: string): string =
  var
    i = 0
    j = 0
    k = 0
    r: Rune
    isHan = false
    isHanCurr = false
  fastRuneAt(s, i, r, false)
  isHanCurr = r.isHan()
  isHan = isHanCurr
  while i < s.len:
    while isHan == isHanCurr:
      k = i
      if i == s.len:
        break
      fastRuneAt(s, i, r, true)
      isHanCurr = r.isHan()
    yield s[j ..< k]
    j = k
    isHan = isHanCurr

proc cmpTrans(ap,bp:float,a,b:char):ProbState =
    var 
        at = (prob:ap,state:a)
        bt = (prob:bp,state:b)
    result = max(at,bt)

proc viterbi(content:string, states:string, start_p:ProbStart, trans_p:ProbTrans,emit_p:ProbEmit):ProbState2 = 
    let 
        runeLen = content.runeLen()
    var 
        firstRune:Rune
        runeOffset = 0
        prob_table_list = newSeqWith(runeLen, newOrderedTable[char, float]() )
        path = initTable[char, seq[char]]()
    fastRuneAt(content,runeOffset,firstRune)
    var 
        ep:float
        emit_key = $firstRune

    for k in states:  # init
        prob_table_list[0][k] = start_p[k] + emit_p[k].getOrDefault(emit_key,MIN_FLOAT)
        path[k] =  @[k]

    var 
        newpath = initTable[char, seq[char]]()
        prob_list = newSeq[ProbState]()
        pos_list = newSeq[char]()
        ps:ProbState
        ap:float
        bp:float
        a:char
        b:char
        probRef:OrderedTableRef[char, float]
        curRune:Rune

    for t in 1..<runeLen:
        fastRuneAt(content,runeOffset,curRune)
        emit_key = $curRune
        newpath.clear()
        probRef = prob_table_list[t-1]
        for k in states:
            ep = emit_p[k].getOrDefault(emit_key,MIN_FLOAT)
            prob_list.setLen(0)
            
            case k:
            of 'B':
                a = 'E'
                b = 'S'
            of 'M':
                a = 'M'
                b = 'B'
            of 'S':
                a = 'S'
                b = 'E'
            of 'E':
                a = 'B'
                b = 'M'
            else:
                discard
            ap = trans_p[a].getOrDefault(k,MIN_FLOAT) + probRef.getOrDefault(a,MIN_FLOAT) + ep
            bp = trans_p[b].getOrDefault(k,MIN_FLOAT) + probRef.getOrDefault(b,MIN_FLOAT) + ep
            ps = cmpTrans(ap,bp,a,b)
            prob_table_list[t][k] = ps.prob
            pos_list = path[ps.state]
            pos_list.add(k)
            newpath[k] = pos_list
        path = newpath
    let last = prob_table_list[runeLen - 1]
    ap = last.getOrDefault('E',MIN_FLOAT)
    bp = last.getOrDefault('S',MIN_FLOAT)
    ps = cmpTrans(ap,bp,'E','S')
    result = (prob: ps.prob,state:path[ps.state] )

iterator internal_cut(sentence:string):seq[Rune]  =
    let 
        mp = viterbi(sentence, BMES, PROB_START_DATA, PROB_TRANS_DATA,PROB_EMIT_DATA)
    var
        runeOffset =  0
        entry:seq[Rune]
        pos:char

    for rune in sentence.runes:
        pos = mp.state[runeOffset]
        runeOffset += 1
        if pos == 'S':
            entry.add(rune)
            yield entry
            entry.setLen(0)
        elif pos == 'E':
            entry.add(rune)
            yield entry
            entry.setLen(0)
        else:
            entry.add(rune)
            continue

# proc internal_cut2(sentence:string,cuted:var seq[string]) =
#     let 
#         mp = viterbi(sentence, BMES, PROB_START_DATA, PROB_TRANS_DATA,PROB_EMIT_DATA)
#     var
#         runeOffset =  0
#         skipedRuneOffset = 0
#         pos:char
#         arrLen = mp.state.count('S') + mp.state.count('E')
#         runes = sentence.toRunes()

#     cuted = newSeqOfCap[string](arrLen)
#     for index,rune in runes:
#         if cuted.len == arrLen:
#             break
#         pos = mp.state[index]
#         if pos == 'S':
#             skipedRuneOffset = 0
#             cuted.add($rune)
#         elif pos == 'E':
#             cuted.add($runes[index-skipedRuneOffset..index])
#             skipedRuneOffset = 0
#         else:
#             skipedRuneOffset+=1
#             continue

let
    # re_han = re(r"(*UTF)([\x{4E00}-\x{9FD5}]+)")
    # re_han = re(r"(*UTF)([\p{Han}]+)")
    re_skip = re(r"([a-zA-Z0-9]+(?:\.\d+)?%?)")
    # re_skip = re(r"(*UTF)([\p{Latin}]+)")

proc add_force_split*(word:string) = 
    Force_Split_Words.add(word)

iterator cut*(sentence:string):string  =  
    # if sentence.len > 0 and sentence.runeLen > 0:
    var 
        wordStr:string
        # cuted:seq[string]
    for blk in splitHan(sentence):
        if blk.len == 0:
            continue
        if likely(containsHan(blk) == true):
            # internal_cut2(blk,cuted)
            for word in internal_cut(blk):
                wordStr = $word
                if likely(wordStr notin Force_Split_Words):
                    yield wordStr
                else:
                    for c in wordStr:
                        yield $c
        else:
            for x in split(blk,re_skip):
                if x.len > 0 and x.runeLen > 0:
                    yield x

proc lcut*(sentence:string):seq[string] {.noInit.} =
    if len(sentence) == 0 or sentence.runeLen == 0:
        result = @[]
    else:
        result = lc[y | (y <- cut(sentence)),string ]