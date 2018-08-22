import os
import streams
import times
import finalseg
import strutils
# import nimprof 
# wget https://raw.githubusercontent.com/yanyiwu/practice/master/nodejs/nodejieba/performance/weicheng.utf8 -O tests/weicheng.utf8
proc main =
    # var lines:seq[string] = newSeq[string]()

    let appDir = getCurrentDir()

    let weicheng = appDir / "tests" / "weicheng.utf8"

    # var 
    #     fs = newFileStream(weicheng, fmRead)
    #     line = ""
    # if not isNil(fs):
    #     while fs.readLine(line):
    #         lines.add(line)
    #     fs.close()

    # var result:seq[string] = @[]

    var starttime = epochTime()

    # for i in 0..49:
    for line in splitLines(readFile(weicheng)):

        # let cuted = cut(line)

        discard lcut(line).join("/")
        # result[random.randint(0, 9)] = r
        #result[random.randint(0, 9)] = jieba.cut(line)
    var endtime =  epochTime()
    echo (endtime - starttime)

when isMainModule:
    main()