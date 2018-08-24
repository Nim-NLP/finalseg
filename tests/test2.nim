import os
import streams
import times
import finalseg/prob_start
import finalseg/prob_trans
import finalseg/prob_emit
import finalseg
import strutils
import tables
import regex

import unicode
# import nimprof 
# wget https://raw.githubusercontent.com/yanyiwu/practice/master/nodejs/nodejieba/performance/weicheng.utf8 -O tests/weicheng.utf8
proc main =
    var lines:seq[string] = newSeq[string]()

    let appDir = getCurrentDir()

    let weicheng = appDir / "tests" / "weicheng.utf8"

    var 
        fs = newFileStream(weicheng, fmRead)
        line = ""
    if not isNil(fs):
        while fs.readLine(line):
            lines.add(line)
        fs.close()

    # var result:seq[string] = @[]
    # var content = readFile(weicheng)
    var 
        starttime = epochTime()
    # for i in 0..49:
    # splitLines(content):

    for line in lines:
        # for x in split(line,re_skip):
        #     discard
        discard lcut(line).join("/")
        # for blk in splitHan(line):
        #     # for k in BMES:
        #     # discard containsHan(blk)
        #     for x in internal_cut( blk):
        #         discard
            # discard viterbi( blk, BMES, PROB_START_DATA, PROB_TRANS_DATA, PROB_EMIT_DATA)
                # for rune in blk.toRunes():
                #     s = $rune
                #     x = if PROB_EMIT_DATA[k].hasKey(s) : PROB_EMIT_DATA[k].getOrDefault(s) else: MIN_FLOAT
    var endtime =  epochTime()
    echo (endtime - starttime)

when isMainModule:
    main()