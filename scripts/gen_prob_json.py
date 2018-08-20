from os import path
import pkg_resources
import pickle
import json
from jieba.finalseg import load_model

start_P, trans_P, emit_P = load_model()
par = path.dirname(path.dirname(path.abspath(__file__)))

json.dump(start_P,open( path.join(par,"src/prob_start.json"),"w"),ensure_ascii=False)
json.dump(trans_P,open(path.join(par,"src/prob_trans.json"),"w"),ensure_ascii=False)
json.dump(emit_P,open(path.join(par,"src/prob_emit.json"),"w"),ensure_ascii=False)