#encoding=utf-8
import sys
import os
import random
import datetime

#wget https://raw.githubusercontent.com/yanyiwu/practice/master/nodejs/nodejieba/performance/weicheng.utf8 -O performace_test/weicheng.utf8

if __name__ == "__main__":

    # if sys.argv[1] == "cppjieba_py":  # 0:00:03.861202
    #     import cppjieba_py as jieba
    #     import cppjieba_py.posseg as pseg  # 0:00:11.860994
    # elif sys.argv[1] == "jieba":  # 0:01:24.703040
    # import jieba
    from jieba.finalseg import cut
    # import jieba.posseg as pseg  # 0:00:00.048153
    # elif sys.argv[1] == "jieba_fast":
    #     import jieba_fast as jieba
    #     import jieba_fast.posseg as pseg

    # if len(sys.argv) == 4 and sys.argv[3] == "pseg":
    #     method = pseg.lcut
    # else:
    method = cut
    HMM = False
    if len(sys.argv) >= 3 and sys.argv[2] == "hmm":
        HMM = True
    lines = []
    weicheng = os.path.join(os.path.dirname(__file__), "weicheng.utf8")
    for line in open(weicheng):
        lines.append(line.strip())
    # result = [""] * 10
    # result[random.randint(0, 9)] = '/'.join(str(method("南京长江大桥", HMM=HMM)))
    starttime = datetime.datetime.now()

    # for i in range(50):
    for line in lines:
        r = '/'.join(str(list(method(line))))
        # print(r)
        # result[random.randint(0, 9)] = r
        #result[random.randint(0, 9)] = jieba.cut(line)
    endtime = datetime.datetime.now()
    print(endtime - starttime)
