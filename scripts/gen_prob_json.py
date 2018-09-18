from os import path, unlink
import subprocess
import pkg_resources
import pickle
import json
from jieba.finalseg import load_model
import re

start_P, trans_P, emit_P = load_model()
par = path.dirname(path.dirname(path.abspath(__file__)))

TEMPLATE = "import tables\nlet %s_DATA* = %s"

def dump2json():
    with open(path.join(par, "src/prob_start.json"), "w") as f:
        json.dump(start_P, f, ensure_ascii=False)
    with open(path.join(par, "src/prob_trans.json"), "w") as f:
        json.dump(trans_P, f, ensure_ascii=False)
    with open(path.join(par, "src/prob_emit.json"), "w") as f:
        json.dump(emit_P, f, ensure_ascii=False, indent=2)


def trans2nim():
    with open( path.join(par,"src/prob_start.json")) as prob_start,\
        open(path.join(par,"src/prob_trans.json")) as  prob_trans,\
        open(path.join(par,"src/prob_emit.json")) as prob_emit,\
        open( path.join(par,"src/finalseg/prob_start.nim"),"w") as prob_start_nim,\
        open(path.join(par,"src/finalseg/prob_trans.nim"),"w") as  prob_trans_nim,\
        open(path.join(par,"src/finalseg/prob_emit.nim"),"w") as prob_emit_nim:
        prob_start_nim_source = \
        TEMPLATE % (
            "PROB_START", prob_start.read()

            .replace("}", "}.newTable")
            .replace('"', "'")
            )
        prob_trans_nim_source = \
        TEMPLATE % (
            "PROB_TRANS", prob_trans.read()

            .replace("}", "}.newTable")
            .replace('"', "'")
            )
        prob_emit_nim_source = \
        TEMPLATE % ("PROB_EMIT", re.sub(r'"([BMES])"',r"'\1'",prob_emit.read())
                    .replace("}", "}.newTable")

                    )
        # re.sub(r'"([^\"])"',r'"\1".toRune',
        prob_start_nim.write(prob_start_nim_source)
        prob_trans_nim.write(prob_trans_nim_source)
        prob_emit_nim.write(prob_emit_nim_source)


if __name__ == "__main__":
    dump2json()
    trans2nim()
    unlink(path.join(par, "src/prob_start.json"))
    unlink(path.join(par, "src/prob_trans.json"))
    unlink(path.join(par, "src/prob_emit.json"))
