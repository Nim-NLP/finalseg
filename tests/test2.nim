import os
import streams
import times
import finalseg
import strutils

# wget https://raw.githubusercontent.com/yanyiwu/practice/master/nodejs/nodejieba/performance/weicheng.utf8 -O tests/weicheng.utf8
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

var starttime = epochTime()

# for i in 0..49:
for line in lines:

    let cuted = cut(line)
    discard cuted.join("/")
    # result[random.randint(0, 9)] = r
    #result[random.randint(0, 9)] = jieba.cut(line)
var endtime =  epochTime()
echo (endtime - starttime)