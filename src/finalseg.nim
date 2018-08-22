# finalseg
# Copyright zhoupeng
# jieba's finalseg port to nim

import tables
import sugar
import nre
import unicode
import prob_start
import prob_trans
import prob_emit
import sequtils
import strutils

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
    ProbStart = TableRef[char, float]
    ProbTrans = TableRef[char, TableRef[char, float]]
    ProbEmit = TableRef[char, TableRef[string, float]]
    ProbState =  tuple[prob: float, state: char]
    ProbState2 = tuple[prob: float, state: seq[char]]

var Force_Split_Words = newSeq[string]()

proc viterbi(content:string, states:string, start_p:ProbStart, trans_p:ProbTrans, emit_p:ProbEmit):ProbState2 = 
    var 
        firstRune:Rune
        runeOffset = 0
        prob_table_list:seq[Table[char, float]] = @[]  # tabular
        path = initTable[char, seq[char]]()
    fastRuneAt(content,runeOffset,firstRune)

    let 
        runeLen = content.runeLen()
        y2 = $firstRune
        restStr = content[runeOffset..^1]
        first = initTable[char, float]()
        
    prob_table_list.add( first)

    var 
        ep:float
        sp:float
        emit_key:string
    for k in states:  # init
        sp = start_p[k]
        ep =  if emit_p[k].hasKey(y2) : emit_p[k].getOrDefault(y2)  else: MIN_FLOAT
        prob_table_list[0][k] =  (sp + ep)
        path[k] =  @[k]

    var 
        newpath = initTable[char, seq[char]]()
        prob_list = newSeq[ProbState]()
        pos_list = newSeq[char]()
        restOne = initTable[char, float]()
        fps:ProbState
        ps:ProbState
        p1:float
        p2:float
        prob:float
        transRef:TableRef[char, float]
        probRef:Table[char, float]
        curRune:Rune

    for t in 1..<runeLen:
        fastRuneAt(content,runeOffset,curRune)
        emit_key = $curRune
        restOne.clear()
        prob_table_list.add(restOne)
        newpath.clear()
        pos_list.setLen(0)

        for k in states:
            ep = if emit_p[k].hasKey(emit_key) : emit_p[k].getOrDefault(emit_key) else: MIN_FLOAT
            prob_list.setLen(0)
            for vChar in PrevStatus[k]: 
                transRef = trans_p[vChar]
                probRef = prob_table_list[t-1]
                p1 = if probRef.hasKey(vChar) : probRef.getOrDefault(vChar) else: MIN_FLOAT
                p2 = if transRef.hasKey(k) : transRef.getOrDefault(k) else: MIN_FLOAT
                prob = p1 + p2 + ep
                ps = (prob:prob,state:vChar)
                prob_list.add(ps)
            fps = max(prob_list)
            prob_table_list[t][k] = fps.prob
            pos_list = lc[y | (y <- path[fps.state]),char ]
            pos_list.add(k)
            newpath[k] =  pos_list
        path = newpath

    fps = max( lc[(prob:if prob_table_list[runeLen - 1].hasKey(y) :prob_table_list[runeLen - 1][y] else: MIN_FLOAT, state: y) | (y <- "ES" ),ProbState])
    result = (prob: ps.prob,state:lc[y | (y <- path[fps.state]),char ] )


iterator internal_cut(sentence:string):seq[Rune]  =
    let 
        runes = sentence.toRunes()
        slen = runes.len
        mp = viterbi( sentence, BMES, PROB_START_DATA, PROB_TRANS_DATA, PROB_EMIT_DATA)
    var
        begin = 0
        nexti =  0
        pos:char

    for i,rune in runes:
        pos = mp.state[i]
        if pos == 'B':
            begin = i
        elif pos == 'E':
            yield runes[begin..i]
            nexti = i + 1
        elif pos == 'S':
            yield @[rune] 
            nexti = i + 1
    if nexti < slen:
        yield runes[nexti..<slen-nexti]

let
    # re_han = re(r"(*UTF)([\x{4E00}-\x{9FD5}]+)")
    re_han = re(r"(*UTF)([\p{Han}]+)")
    re_skip = re(r"([a-zA-Z0-9]+(?:\.\d+)?%?)")

proc add_force_split*(word:string) = 
    Force_Split_Words.add(word)

iterator cut*(sentence:string):string  = 
    # if sentence.len == 0 or sentence.runeLen() == 0:
    #     return 
   
    var 
        wordStr:string 
    for blk in nre.split(sentence,re_han):
        if blk.len == 0:
            continue
        if isSome(blk.match(re_han)) == true:
            for word in internal_cut(blk):
                wordStr = $word
                if wordStr notin Force_Split_Words:
                    yield wordStr
                else:
                    for c in wordStr:
                        yield $c
        else:
            for x in split(blk,re_skip):
                if x.len > 0 or x.runeLen > 0:
                    yield x

proc lcut*(sentence:string):seq[string] =
    result = lc[y | (y <- cut(sentence)),string ]