import finalseg
import strutils
# var r:seq[string] = cut("我来到北京清华大学")
# AllChars = {'\x4E00'..'\x9FD5'}
# for x in cut("我来到北京清华大学"):
#     for y in x:
#         echo ord(',')

echo lcut("我来到北京清华大学").join("/")
