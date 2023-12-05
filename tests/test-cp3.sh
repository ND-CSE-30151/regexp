#!/bin/bash

ROOT="$(cd "$(dirname $0)" && pwd)"/..
BIN=$ROOT/bin.$(uname | tr A-Z a-z)
SUBMIT=$ROOT/cp3
EXAMPLES=$ROOT/examples
TMPDIR=${TMPDIR:-/tmp}/test-cp3.$$
mkdir -p $TMPDIR
trap "rm -rf $TMPDIR" EXIT
trap "pkill -9 -g0; exit 130" INT
set -o pipefail

assert_equal () {
  if [ "$1" = "$2" ]; then
    echo "PASSED"
  else
    echo "FAILED"
    echo "  correct output: $1"
    echo "     your output: $2"
  fi
}

assert_nodiff () {
  diff -y -W 80 "$1" "$2" > "$TMPDIR/diff.out"
  if [ $? -eq 0 ]; then
    echo "PASSED"
  else
    echo "FAILED"
    echo "correct output                          your output                          "
    echo "-----------------------------------------------------------------------------"
    cat "$TMPDIR/diff.out"
  fi
}

err () {
  echo "(error)"
}

if [ -x "$SUBMIT/parse_re" ]; then
  for REGEXP in "(ab|a)*" "(a|b)*aba" "" "a" "a*" "ab" "abc" "abcd" "a|b" "a|b|c" "a|b|c|d" "a*b*" "(ab)*" "ab|cd" "(ab)|(cd)" "a*|b*" "(a|b)*" "(a)" "((a))" "a(b)" "(a)b" "()" "|" "(|)" "(a|)" "(|a)" "a||b" "(a|(b|c))(d|e)*"; do
    echo -n 'parse_re "'"$REGEXP"'": '
    assert_equal "$("$BIN/parse_re" -g "$REGEXP")" "$("$SUBMIT/parse_re" "$REGEXP" || err)"
  done
else
  echo "parse_re: SKIPPED"
fi

if [ -x "$SUBMIT/re_groups" ]; then
    RE="(a|(b|c))(d|e)*"
    for W in "" ade; do
	echo -n "re_groups \"$RE\" \"$W\": "
	assert_nodiff <("$BIN/re_groups" "$RE" "$W") <("$SUBMIT/re_groups" "$RE" "$W" || err)
    done
else
  echo "re_groups: SKIPPED"
fi

if [ -x "$SUBMIT/msed" ]; then

    CMD="s/(a*)(b*)/\2\1/"
    for W in "" "aaa" "bbb" "aaabbb" "bbbaaa"; do
	echo -n "msed -e \"$CMD\" \"$W\": "
	assert_equal "$(echo $W | "$BIN/msed" -e "$CMD")" "$(echo $W | "$SUBMIT/msed" -e "$CMD" || err)"
    done

    for CMD in "s/((a|b)*)/\1,\1,\1/" "s/((a|b)*)/\2,\2,\2/"; do
	for W in "" "baa"; do
	    echo -n "msed -e \"$CMD\" \"$W\": "
	    assert_equal "$(echo $W | "$BIN/msed" -e "$CMD")" "$(echo $W | "$SUBMIT/msed" -e "$CMD" || err)"
	done
    done

    CMD="s/()*//"
    for W in "" "a"; do
	echo -n "msed -e \"$CMD\" \"$W\": "
	assert_equal "$(echo $W | "$BIN/msed" -e "$CMD")" "$(echo $W | "$SUBMIT/msed" -e "$CMD" || err)"
    done

    RE="(a|b)(c|d)(e|f)(g|h)(i|j)(k|l)(m|n)(o|p)(q|r)(s|t)"
    for CMD in "s/$RE/\10/" "s/$RE/\g<1>0/" "s/$RE/\g<10>/"; do
	for W in "acegikmoqs"; do
	    echo -n "msed -e \"$CMD\" \"$W\": "
	    assert_equal "$(echo $W | "$BIN/msed" -e "$CMD")" "$(echo $W | "$SUBMIT/msed" -e "$CMD" || err)"
	done
    done

    for W in "" "aaabbb"; do
	CMDS="-e s/((a|b)*)/^\1/ -e :loop -e s/((a|b)*)^(a|b)((a|b)*)/\3\1^\4/ -e /(a|b)*^(a|b)(a|b)*/bloop -e s/((a|b)*)^/\1/"
	echo -n "reverse \"$W\": "
	assert_equal "$(echo $W | "$BIN/msed" $CMDS)" "$(echo $W | "$SUBMIT/msed" $CMDS || err)"
    done

    CMD="s/(|a)(|a)(|a)//"
    for W in "" b a ab aa aab aaa aaab; do
	echo -n "msed -e \"$CMD\" \"$W\": "
	assert_equal "$(echo $W | "$BIN/msed" -e "$CMD")" "$(echo $W | "$SUBMIT/msed" -e "$CMD" || err)"
    done

else
  echo "msed: SKIPPED"
fi

if [ -x "$SUBMIT/tm_to_sed" ]; then

    test_tm () {
	echo -n "echo \"$2\" | msed -f <(tm_to_sed $(basename $1)): "
	assert_equal "$(echo "$2" | "$BIN/run_tm" $1 | sed -e 's/_*$//')" \
		     "$(echo "$2" | "$BIN/msed" -f <("$SUBMIT/tm_to_sed" $1) | sed -e 's/_*$//' || err)"
    }
    
    for W in "" "a" "b"; do
        test_tm "$EXAMPLES/basic.tm" $W
    done
    
    for W in "" "a" "b" "c"; do
        test_tm "$EXAMPLES/moveleft.tm" $W
    done
    
    for W in "" "a"; do
        test_tm "$EXAMPLES/moveright.tm" $W
    done
    
    for W in "#" "0011#0011" "0011#1100"; do
        test_tm "$EXAMPLES/sipser-m1.tm" $W
    done

    for W in "" 0 00 000 0000 00000; do
        test_tm "$EXAMPLES/sipser-m2.tm" $W
    done
else
    echo "tm_to_sed: SKIPPED"
fi
