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

const
    MIN_FLOAT = -3.14e100
    PrevStatus = {
        "B": "ES",
        "M": "MB",
        "S": "SE",
        "E": "BM"
    }.toTable

type

    # PrevStatus = enum
    #     B = "ES", M = "MB", S = "SE", E = "BM"
    BMES = object
        B,M,E,S : float
    ProbState = tuple[prob: float, state: string]
    ProbState2 = tuple[prob: float, state: seq[string]]

template filename: string = instantiationInfo().filename

let appDir = parentDir(filename())
# var starttime =  epochTime()

let prob_start = to(parseFile(appDir / "prob_start.json"),BMES)
let prob_trans = parseFile(appDir / "prob_trans.json")
let prob_emit = parseFile(appDir  / "prob_emit.json")
# echo "load json costs:",(epochTime() - starttime)


proc `[]`(x: BMES,index:string): float =
  result = MIN_FLOAT
  for name, value in x.fieldPairs:
    if name == index:
      return value
  return result 

var Force_Split_Words = newSeq[string]()

proc viterbi(obs:string, states:string, start_p:BMES, trans_p:JsonNode, emit_p:JsonNode):ProbState2 = 
    let runeLen = obs.runeLen()
    var 
        first = initTable[string, float]()
        V:seq[Table[string, float]] = @[]  # tabular
        path = initTable[string, seq[string]]()
    V.add(first)
    for k in states:  # init
        let 
            y = $k
        let 
            y2 = runeStrAtPos(obs,0)
            sp = start_p[y]
            ep =  if emit_p[y].hasKey(y2) : emit_p[y][y2].getFloat(MIN_FLOAT) else:MIN_FLOAT
        V[0][y] =  (sp + ep)
        path[y] =  @[y]
    var 
        newpath = initTable[string, seq[string]]()
        prob_list = newSeq[ProbState]()
    for t in 1..runeLen - 1:
        var n = initTable[string, float]()
        V.add(n)
        newpath.clear()
        for k in states:
            let
                y = $k
                y2 = runeStrAtPos(obs,t)
                em_p = if emit_p[y].hasKey(y2) : emit_p[y][y2].getFloat( MIN_FLOAT) else:MIN_FLOAT

            prob_list = @[]
            for y0 in PrevStatus[y]:
                let 
                    y2 = $y0 
                    ty = trans_p[y2]
                    vPre = V[t - 1]
                    p1 = if vPre.hasKey(y2) :vPre[y2] else: MIN_FLOAT
                    p2 = if ty.hasKey(y):ty[y].getFloat( MIN_FLOAT) else:MIN_FLOAT
                    prob = p1 + p2 + em_p
                    ps:ProbState = (prob:prob,state:y2)
                prob_list.add(ps)
            let fps = max(prob_list)
            V[t][y] = fps.prob
            var
                r = lc[y | (y <- path[fps.state]),string ]
            r.add(y)
            newpath[y] =  r
        path = newpath
    let 
        ps:ProbState = max( lc[(prob:if V[runeLen - 1].hasKey($y) :V[runeLen - 1][$y] else: MIN_FLOAT, state: $y) | (y <- "ES" ),ProbState])
        r:ProbState2 = (prob: ps.prob,state:lc[y | (y <- path[ps.state]),string ] )
    return r


proc internal_cut(sentence:string):seq[string] {.noInit.}  =
    # let start = cpuTime()
    result = newSeq[string]()
    let mp = viterbi(sentence, "BMES", prob_start, prob_trans, prob_emit)
    # echo "viterbi cost:",cpuTime()-start
    var
        begin = 0
        nexti =  0

    for i in 0..< sentence.runeLen()  :
        let pos = mp.state[i]
        if pos == "B":
            begin = i
        elif pos == "E":
            let ed = i + 1
            result.add( runeSubStr(sentence,begin,ed-begin) )
            nexti = i + 1
        elif pos == "S":
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
    if sentence.runeLen() == 0:
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
                if sentence.len == 0 and x.runeLen()>0:
                    result.add( x)
    return result