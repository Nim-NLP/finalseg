# finalseg
# Copyright zhoupeng
# jieba's finalseg port to nim
import os
import json
import tables
import future
import nre
import unicode
import times
import prob_start
import prob_trans
import prob_emit

const
    MIN_FLOAT = -3.14e100
    PrevStatus = {
        'B': "ES",
        'M': "MB",
        'S': "SE",
        'E': "BM"
    }

type
    ProbStart = TableRef[char, float]
    ProbTrans = TableRef[char, TableRef[char, float]]
    ProbEmit = TableRef[string, TableRef[string, float]]
    ProbState = tuple[prob: float, state: char]
    ProbState2 = tuple[prob: float, state: seq[char]]

var Force_Split_Words = newSeq[string]()

proc viterbi(obs:string, states:string, start_p:ProbStart, trans_p:ProbTrans, emit_p:ProbEmit):ProbState2 = 
    let 
        runeLen = obs.runeLen()
        y2 = runeStrAtPos(obs,0)
    var 
        first = initTable[char, float]()
        prob_table_list:seq[Table[char, float]] = @[]  # tabular
        path = initTable[char, seq[char]]()
    prob_table_list.add(first)
    for k in states:  # init
        let 
            y = $k
            sp = start_p[k]
            ep =  if emit_p[y].hasKey(y2) : emit_p[y].getOrDefault(y2)  else: MIN_FLOAT
        prob_table_list[0][k] =  (sp + ep)
        path[k] =  @[k]
    var 
        newpath = initTable[char, seq[char]]()
        prob_list = newSeq[ProbState]()
        pos_list = newSeq[char]()
    for t in 1..runeLen - 1:
        var n = initTable[char, float]()
        prob_table_list.add(n)
        newpath.clear()
        pos_list.setLen(0)
        for k in states:
            let
                y = $k
                y2 = runeStrAtPos(obs,t)
                em_p = if emit_p[y].hasKey(y2) : emit_p[y].getOrDefault(y2) else: MIN_FLOAT

            prob_list.setLen(0)
            for value in PrevStatus:
                let 
                    vChar = value[0]
                    ty = trans_p[vChar]
                    vPre = prob_table_list[t - 1]
                    p1 = if vPre.hasKey(vChar) : vPre[vChar] else: MIN_FLOAT
                    p2 = if ty.hasKey(k) : ty.getOrDefault(k) else: MIN_FLOAT
                    prob = p1 + p2 + em_p
                    ps:ProbState = (prob:prob,state:vChar)
                prob_list.add(ps)
            let fps = max(prob_list)
            prob_table_list[t][k] = fps.prob
            pos_list = lc[y | (y <- path[fps.state]),char ]
            pos_list.add(y)
            newpath[k] =  pos_list
        path = newpath
    let 
        ps:ProbState = max( lc[(prob:if prob_table_list[runeLen - 1].hasKey(y) :prob_table_list[runeLen - 1][y] else: MIN_FLOAT, state: y) | (y <- "ES" ),ProbState])
    result = (prob: ps.prob,state:lc[y | (y <- path[ps.state]),char ] )


proc internal_cut(sentence:string):seq[string] {.noInit.}  =
    # let start = cpuTime()
    result = newSeq[string]()
    let mp = viterbi(sentence, "BMES", PROB_START_DATA, PROB_TRANS_DATA, PROB_EMIT_DATA)
    # echo "viterbi cost:",cpuTime()-start
    var
        begin = 0
        nexti =  0
        pos:char

    for i in 0..< sentence.runeLen()  :
        pos = mp.state[i]
        if pos == 'B':
            begin = i
        elif pos == 'E':
            let ed = i + 1
            result.add( runeSubStr(sentence,begin,ed-begin) )
            nexti = i + 1
        elif pos == 'S':
            result.add(runeStrAtPos(sentence,i))
            nexti = i + 1
    if nexti < sentence.runeLen():
        result.add( runeSubStr(sentence,nexti,sentence.runeLen()-nexti))

let
    # re_han = re(r"(*UTF)([\x{4E00}-\x{9FD5}]+)")
    re_han = re(r"(*UTF)([\p{Han}]+)")
    re_skip = re(r"([a-zA-Z0-9]+(?:\.\d+)?%?)")

proc add_force_split*(word:string) = 
    Force_Split_Words.add(word)

proc cut*(sentence:string):seq[string] {.discardable,noInit.} = 
    result = newSeq[string]()
    if sentence.len == 0 or sentence.runeLen() == 0:
        return result
    let blocks:seq[string] = nre.split(sentence,re_han)
    var 
        sl = newSeq[string]()
        tmp = newSeq[string]()
        wordStr = ""
    for blk in blocks:
        if isSome(blk.match(re_han)) == true:
            sl = internal_cut(blk)
            for word in sl:
                wordStr = $word
                if (wordStr in Force_Split_Words == false):
                    result.add( wordStr)
                else:
                    for c in wordStr:
                        result.add( $c )
        else:
            tmp = split(blk,re_skip)
            for x in tmp:
                if sentence.len == 0 or x.runeLen()>0:
                    result.add( x)
    return result