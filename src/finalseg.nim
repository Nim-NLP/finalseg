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
    PrevStatus = {
        'B': "ES",
        'M': "MB",
        'S': "SE",
        'E': "BM"
    }.toTable
    BMES = "BMES"

type
    ProbStart = Table[char, float]
    ProbTrans = Table[char, Table[char, float]]
    ProbEmit = Table[char, Table[Rune, float]]
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

proc viterbi(content:string, states:string, start_p:ProbStart, trans_p:ProbTrans,emit_p:ProbEmit):ProbState2 = 
    let 
        runeLen = content.runeLen()
    var 
        firstRune:Rune
        runeOffset = 0
        prob_table_list = newSeqWith(runeLen, initTable[char, float]() )
        path = initTable[char, seq[char]]()
    fastRuneAt(content,runeOffset,firstRune)
    # let
    #     y2 = $firstRune
    var 
        ep:float
        # emit_key:string

    for k in states:  # init
        prob_table_list[0][k] = start_p[k] + emit_p[k].getOrDefault(firstRune,MIN_FLOAT)
        path[k] =  @[k]

    var 
        newpath = initTable[char, seq[char]]()
        prob_list = newSeq[ProbState]()
        pos_list = newSeq[char]()
        fps:ProbState
        ps:ProbState
        p1:float
        p2:float
        prob:float
        transRef:Table[char, float]
        probRef:Table[char, float]
        curRune:Rune
        # BMES2=newTable[char, float]()
    for t in 1..<runeLen:
        fastRuneAt(content,runeOffset,curRune)
        # emit_key = $curRune

        # restOne.clear()
        # prob_table_list.add(restOne)
        newpath.clear()
        pos_list.setLen(0)

        for k in states:
            ep = emit_p[k].getOrDefault(curRune,MIN_FLOAT)
            prob_list.setLen(0)
            for vChar in PrevStatus[k]: 
                transRef = trans_p[vChar]
                probRef = prob_table_list[t-1]
                p1 = probRef.getOrDefault(vChar,MIN_FLOAT)
                p2 = transRef.getOrDefault(k,MIN_FLOAT)
                prob = p1 + p2 + ep
                ps = (prob:prob,state:vChar)
                prob_list.add(ps)
            fps = max(prob_list)
            prob_table_list[t][k] = fps.prob
            pos_list = lc[y | (y <- path[fps.state]),char ]
            pos_list.add(k)
            newpath[k] =  pos_list
        path = newpath
    let last = prob_table_list[runeLen - 1]
    fps = max( lc[(prob:last.getOrDefault(y,MIN_FLOAT), state: y) | (y <- "ES" ),ProbState])
    result = (prob: ps.prob,state:lc[y | (y <- path[fps.state]),char ] )

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