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

const
    MIN_FLOAT = -3.14e100
    BMES = "BMES"

type
    ProbStart = TableRef[char, float]
    ProbTrans = TableRef[char, TableRef[char, float]]
    ProbEmit = TableRef[char, TableRef[string, float]]
    # ProbEmit = CritBitTree[float] 
    ProbState =  tuple[prob: float, state: char]
    ProbState2 = tuple[prob: float, state: seq[char],strings:seq[Natural]]

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

template cmpTrans(a,b,k:char,ep:float,probRef:TableRef[char, float]):ProbState =
    var 
        ap = PROB_TRANS_DATA[a][k] + probRef[a] + ep
        bp = PROB_TRANS_DATA[b][k] + probRef[b] + ep
        at = (prob:ap,state:a)
        bt = (prob:bp,state:b)
    max(at,bt)

proc cmpTrans(ap,bp:float,a,b:char):ProbState=
    var 
        at = (prob:ap,state:a)
        bt = (prob:bp,state:b)
    result = max(at,bt)

# var 
#     B = PROB_EMIT_DATA['B']
#     M = PROB_EMIT_DATA['M']
#     E = PROB_EMIT_DATA['E']
#     S = PROB_EMIT_DATA['S']

proc viterbi(content:string, states = BMES, start_p = PROB_START_DATA, trans_p = PROB_TRANS_DATA,emit_p = PROB_EMIT_DATA):ProbState2 = 
    let 
        runeLen = content.runeLen()
    var 
        strings = newSeqOfCap[Natural](runeLen)
        curRune:Rune
        runeOffset = 0
        prob_table_list = newSeqWith(runeLen, newTable[char, float]() )
        path = initTable[char, seq[char]]()
    fastRuneAt(content,runeOffset,curRune)
    var 
        ep:float
        emit_key = $curRune

    strings.add runeOffset
    
    for k in states:  # init
        prob_table_list[0][k] = start_p[k] + emit_p[k].getOrDefault(emit_key,MIN_FLOAT)
        # case k:
        # of 'B':
        #     prob_table_list[0][k] = start_p[k] + B.getOrDefault(emit_key,MIN_FLOAT)
        # of 'M':
        #     prob_table_list[0][k] = start_p[k] + M.getOrDefault(emit_key,MIN_FLOAT)
        # of 'E':
        #     prob_table_list[0][k] = start_p[k] + E.getOrDefault(emit_key,MIN_FLOAT)
        # of 'S':
        #     prob_table_list[0][k] = start_p[k] + S.getOrDefault(emit_key,MIN_FLOAT)
        # else:
        #     discard
        path[k] =  @[k]

    var 
        # newpath = newTable[char, seq[char]]()
        prob_list = newSeqOfCap[ProbState](runeLen)
        pos_list = newSeqOfCap[char](runeLen)
        ps:ProbState
        probRef:TableRef[char, float]
        pos_list_list:seq[seq[char]]

    for t in 1..<runeLen:
        fastRuneAt(content,runeOffset,curRune)
        emit_key = $curRune
        strings.add runeOffset
        # newpath.clear()
        pos_list_list.setLen(0)
        probRef = prob_table_list[t-1]
        for k in states:
            ep = emit_p[k].getOrDefault(emit_key,MIN_FLOAT)
            prob_list.setLen(0)
            
            case k:
            of 'B':
                # ep = B.getOrDefault(emit_key,MIN_FLOAT)
                ps = cmpTrans('E','S',k,ep,probRef)
            of 'M':
                # ep = M.getOrDefault(emit_key,MIN_FLOAT)
                ps = cmpTrans('M','B',k,ep,probRef)
            of 'S':
                # ep = S.getOrDefault(emit_key,MIN_FLOAT)
                ps = cmpTrans('S','E',k,ep,probRef)
            of 'E':
                # ep = E.getOrDefault(emit_key,MIN_FLOAT)
                ps = cmpTrans('B','M',k,ep,probRef)
            else:
                discard
            prob_table_list[t][k] = ps.prob
            pos_list = path[ps.state]
            pos_list.add(k)
            pos_list_list.add pos_list
        # for x,y in newpath.pairs:
        #     path[x] = y
        for i,c in BMES.pairs:
            path[c] = pos_list_list[i]
        # path = newpath
    let last = prob_table_list[runeLen - 1]
    ps = cmpTrans(last['E'],last['S'],'E','S')
    result = (prob: ps.prob,state:path[ps.state] ,strings:strings)

iterator internal_cut(sentence:string):string  =
    let 
        mp = viterbi(sentence)
    var
        # runeOffset =  0
        entry:string
        pos:char
        cur:string
        left:Natural
    # echo mp.strings
    for index,offset in mp.strings:
        pos = mp.state[index]
        left = if index > 0 : mp.strings[index - 1] else : 0
        cur = sentence[left..<offset]
        # inc runeOffset
        case pos:
        of 'S','E':
            entry.add(cur)
            yield entry
            entry.setLen(0)
        else:
            entry.add(cur)
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

iterator cut*(sentence: string):string  = 
    # if sentence.len > 0 and sentence.runeLen > 0:
    # var 
    #     wordStr:string
        # cuted:seq[string]
    for blk in splitHan(sentence):
        if blk.len == 0:
            continue
        if likely(containsHan(blk) == true):
            # internal_cut2(blk,cuted)
            for wordStr in internal_cut(blk):
                # wordStr = $word
                if likely(wordStr notin Force_Split_Words):
                    yield wordStr
                else:
                    for c in wordStr:
                        yield $c
        else:
            yield blk
            # for x in split(blk,re_skip):
            #     if x.len > 0 and x.runeLen > 0:
            #         yield x

proc lcut*(sentence:string):seq[string] {.noInit.} =
    if len(sentence) == 0 or sentence.runeLen == 0:
        result = @[]
    else:
        result = lc[y | (y <- cut(sentence)),string ]