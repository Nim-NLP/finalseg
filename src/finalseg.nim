# finalseg
# Copyright zhoupeng
# jieba's finalseg port to nim

import tables
import unicode
import finalseg/prob_start
import finalseg/prob_trans
import finalseg/prob_emit
import sequtils
import unicodedb/scripts

const
  MIN_FLOAT = -3.14e100
  BMES = "BMES"

type
  ProbState = tuple[prob: float, state: char]
  ProbState2 = tuple[prob: float, state: seq[char], strings: seq[Natural]]

var Force_Split_Words = newSeq[string]()

proc isHan(r: Rune): bool {.inline.} =
  # fast ascii check followed by unicode check
  result = r.int > 127 and r.unicodeScript() == sptHan

proc containsHan(s:sink string): bool =
  for r in s.runes:
    if r.isHan:
      result = true
      break

iterator splitHan(s: sink string): string =
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

proc `<=`(a,b:ProbState):bool {.inline.} =
  a.prob <= b.prob

template cmpTrans(a, b, k: char, ep: float, probRef: TableRef[char,
    float]): ProbState =
  var
    ap = PROB_TRANS_DATA[a][k] + probRef[a] + ep
    bp = PROB_TRANS_DATA[b][k] + probRef[b] + ep
    at:ProbState = (prob: ap, state: a)
    bt:ProbState = (prob: bp, state: b)
  max(at, bt)

proc cmpTrans(ap, bp: float, a, b: char): ProbState {.inline.} =
  var
    at:ProbState = (prob: ap, state: a)
    bt:ProbState = (prob: bp, state: b)
  result = max(at, bt)

var
  prob_list = newSeq[ProbState]()
  pos_list = newSeq[char]()
  ps: ProbState
  probRef: TableRef[char, float]
  pos_list_list: seq[seq[char]]
  
proc viterbi(content: sink string, states = BMES, start_p = PROB_START_DATA,
    trans_p = PROB_TRANS_DATA, emit_p = PROB_EMIT_DATA): ProbState2 =
  let
    runeLen = content.runeLen()
  var
    strings = newSeqOfCap[Natural](runeLen)
    curRune: Rune
    runeOffset = 0
    prob_table_list = newSeqWith(runeLen, newTable[char, float]())
    path = initTable[char, seq[char]]()
  fastRuneAt(content, runeOffset, curRune)
  var
    ep: float
    emit_key = $curRune

  strings.add runeOffset

  for k in states: # init
    prob_table_list[0][k] = start_p[k] + emit_p[k].getOrDefault(emit_key, MIN_FLOAT)
    path[k] = @[k]
  prob_list.setLen(runeLen)
  pos_list.setLen(runeLen)
  # var
  #   prob_list = newSeqOfCap[ProbState](runeLen)
  #   pos_list = newSeqOfCap[char](runeLen)
  #   ps: ProbState
  #   probRef: TableRef[char, float]
  #   pos_list_list: seq[seq[char]]

  for t in 1..<runeLen:
    fastRuneAt(content, runeOffset, curRune)
    emit_key = $curRune
    strings.add runeOffset
    pos_list_list.setLen(0)
    probRef = prob_table_list[t-1]
    for k in states:
      ep = emit_p[k].getOrDefault(emit_key, MIN_FLOAT)
      prob_list.setLen(0)

      case k:
      of 'B':
        ps = cmpTrans('E', 'S', k, ep, probRef)
      of 'M':
        ps = cmpTrans('M', 'B', k, ep, probRef)
      of 'S':
        ps = cmpTrans('S', 'E', k, ep, probRef)
      of 'E':
        ps = cmpTrans('B', 'M', k, ep, probRef)
      else:
        discard
      prob_table_list[t][k] = ps.prob
      pos_list = path[ps.state]
      pos_list.add(k)
      pos_list_list.add pos_list

    for i, c in BMES.pairs:
      path[c] = pos_list_list[i]
  let last = prob_table_list[runeLen - 1]
  ps = cmpTrans(last['E'], last['S'], 'E', 'S')
  result = (prob: ps.prob, state: path[ps.state], strings: strings)

iterator internal_cut(sentence: sink string): string =
  var
    mp = viterbi(sentence)
  var
    entry: string
    pos: char
    cur: string
    left: Natural
  for index, offset in mp.strings.mpairs:
    pos = mp.state[index]
    left = if index > 0: mp.strings[index - 1] else: 0
    cur = sentence[left..<offset]
    case pos:
    of 'S', 'E':
      entry.add(cur)
      yield entry
      entry.setLen(0)
    else:
      entry.add(cur)
      continue

proc add_force_split*(word: sink string) =
  Force_Split_Words.add(word)

iterator cut*(sentence:sink string): string =
  for blk in splitHan(sentence):
    if blk.len == 0:
      continue
    if containsHan(blk) == true:
      for wordStr in internal_cut(blk):
        if wordStr notin Force_Split_Words:
          yield wordStr
        else:
          for c in wordStr:
            yield $c
    else:
      yield blk

proc lcut*(sentence: sink string): seq[string] =
  if len(sentence) == 0 or sentence.runeLen == 0:
    result = @[]
  else:
    result = toSeq(cut(sentence))
