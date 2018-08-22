import finalseg
import strutils
# var r:seq[string] = cut("我来到北京清华大学")

for x in cut("我来到北京清华大学"):

    echo x

echo lcut("我来到北京清华大学").join("/")