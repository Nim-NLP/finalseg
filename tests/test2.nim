import os
import streams
import times
import finalseg
import strutils
# import nimprof
# wget https://raw.githubusercontent.com/yanyiwu/practice/master/nodejs/nodejieba/performance/weicheng.utf8 -O tests/weicheng.utf8
proc main =
  var lines: seq[string] = newSeq[string]()

  let appDir = getCurrentDir()

  let weicheng = appDir / "tests" / "weicheng.utf8"

  var
    fs = newFileStream(weicheng, fmRead)
    line = ""

  if not isNil(fs):
    while fs.readLine(line):
      lines.add(line)
    fs.close()
  var
    starttime = epochTime()
  # jiba_fast 0:00:00.353178
  # jieba 0:00:03.179085
  for line in lines:
    discard lcut(line).join("/")

  var endtime = epochTime()
  echo (endtime - starttime)

when isMainModule:
  main()
