# finalseg

Chinese Words Segment Library in Nim based on HMM Model

porting from [jieba's finalseg module ](https://github.com/fxsjy/jieba/tree/master/jieba/finalseg)

## Usage

```nim
    import finalseg
    import strutils

    let sentence_list = @[
    "姚晨和老凌离婚了",
    "他说的确实在理",
    "长春市长春节讲话"
    ]

    for sentence in sentence_list:
    	for x in cut(sentence)
    	    echo x

    # or
    for sentence in sentence_list:
    	seg_list = lcut(sentence)
    	echo seg_list.join("/ ")
```

# Algorithm

- Hidden Markov Models, Viterbi
