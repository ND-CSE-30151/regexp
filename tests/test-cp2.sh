#!/bin/bash

ROOT="$(cd "$(dirname $0)" && pwd)"/..
BIN=$ROOT/bin.$(uname | tr A-Z a-z)
SUBMIT=$ROOT/cp2
EXAMPLES=$ROOT/examples
TMPDIR=${TMPDIR:-/tmp}/test-cp2.$$
mkdir -p $TMPDIR
trap "rm -rf $TMPDIR" EXIT
trap "pkill -9 -g0; exit 130" INT
set -o pipefail

assert_true () {
  if [ $? -eq 0 ]; then
    echo PASSED
  else
    echo FAILED
  fi
}

assert_equal () {
  if [ "$1" = "$2" ]; then
    echo "PASSED"
  else
    echo "FAILED"
    echo "  correct output: $1"
    echo "     your output: $2"
  fi
}

err () {
  echo "(error)"
}

if [ -x "$SUBMIT/parse_re" ]; then
  for REGEXP in "(ab|a)*" "(a|b)*aba" "" "a" "a*" "ab" "abc" "abcd" "a|b" "a|b|c" "a|b|c|d" "a*b*" "(ab)*" "ab|cd" "(ab)|(cd)" "a*|b*" "(a|b)*" "(a)" "((a))" "a(b)" "(a)b" "()" "|" "(|)" "(a|)" "(|a)" "a||b"; do
    echo -n 'parse_re "'"$REGEXP"'": '
    assert_equal "$("$BIN/parse_re" "$REGEXP")" "$("$SUBMIT/parse_re" "$REGEXP" || err)"
  done
else
  echo "parse_re: SKIPPED"
fi

if [ -x "$SUBMIT/string_nfa" ]; then
  for W in "" "a" "ab"; do
    echo -n "string_nfa \"$W\": "
    "$BIN/compare_nfa" <("$BIN/string_nfa" "$W") <("$SUBMIT/string_nfa" "$W") >/dev/null
    assert_true
  done
else
  echo "string_nfa: SKIPPED"
fi

for OP in union concat; do
  if [ -x "$SUBMIT/${OP}_nfa" ]; then
    for NFA1 in "$EXAMPLES"/sipser-n{1,2,3,4}.nfa; do
      for NFA2 in "$EXAMPLES"/sipser-n{1,2,3,4}.nfa; do

        echo -n "${OP}_nfa $(basename "$NFA1") $(basename "$NFA2"): "
        "$BIN/compare_nfa" <("$BIN/${OP}_nfa" "$NFA1" "$NFA2") <("$SUBMIT/${OP}_nfa" "$NFA1" "$NFA2") >/dev/null
        assert_true
      done
    done
  else
    echo "${OP}_nfa: SKIPPED"
  fi
done

if [ -x "$SUBMIT/star_nfa" ]; then
  for NFA in "$EXAMPLES"/sipser-n{1,2,3,4}.nfa; do
    echo -n "star_nfa $(basename "$NFA"): "
    "$BIN/compare_nfa" <("$BIN/star_nfa" "$NFA") <("$SUBMIT/star_nfa" "$NFA") >/dev/null
    assert_true
  done
else
  echo "star_nfa: SKIPPED"
fi

if [ -x "$SUBMIT/re_to_nfa" ]; then
  for REGEXP in "(ab|a)*" "(a|b)*aba" "" "a" "a*" "ab" "abc" "abcd" "a|b" "a|b|c" "a|b|c|d" "a*b*" "(ab)*" "ab|cd" "(ab)|(cd)" "a*|b*" "(a|b)*" "(a)" "((a))" "a(b)" "(a)b" "()" "|" "(|)" "(a|)" "(|a)" "a||b"; do
      echo -n 're_to_nfa "'"$REGEXP"'": '
      "$BIN/compare_nfa" <("$BIN/re_to_nfa" "$REGEXP") <("$SUBMIT/re_to_nfa" "$REGEXP") > /dev/null
      assert_true
  done
else
  echo "re_to_nfa: SKIPPED"
fi
    

if [ -x "$SUBMIT/agrep" ]; then
    for W in "" a b aa ab ba bb aaa aab aba abb baa bab bba bbb; do
	echo -n "agrep \"(ab|a)*\" \"$W\": "
	assert_equal "$(echo "$W" | "$BIN/agrep" "(ab|a)*")" "$(echo "$W" | "$SUBMIT/agrep" "(ab|a)*" || err)"
    done

    for W in "" a b aa ab ba bb aba abaa abab aaba baba aaaba ababa baaba bbaba; do
	echo -n "agrep \"(a|b)*aba\" \"$W\": "
	assert_equal "$(echo "$W" | "$BIN/agrep" "(a|b)*aba")" "$(echo "$W" | "$SUBMIT/agrep" "(a|b)*aba" || err)"
    done

    for W in "" a; do
	echo -n "agrep \"\" \"$W\": "
	assert_equal "$(echo "$W" | "$BIN/agrep" "")" "$(echo "$W" | "$SUBMIT/agrep" "" || err)"
    done

    for W in "" a; do
	echo -n "agrep \"()*\" \"$W\": "
	assert_equal "$(echo "$W" | "$BIN/agrep" "()*")" "$(echo "$W" | "$SUBMIT/agrep" "()*" || err)"
    done

    for RE in "(|a)" "(|a)(|a)" "(|a)(|a)(|a)"; do
        for W in "" b a ab aa aab aaa aaab; do
  	    echo -n "agrep \"$RE\" \"$W\": "
	    assert_equal "$(echo "$W" | "$BIN/agrep" "$RE")" "$(echo "$W" | "$SUBMIT/agrep" "$RE" || err)"
        done
    done
    
    echo "time agrep (if it is Θ(n^2), this should look linear):"
    RE=""
    W="b"
    for I in $(seq 1 400); do
	RE="(|a)${RE}"
	W="a${W}"
	if [ $(($I**2/10000)) -gt $((($I-1)**2/10000)) ]; then
	    printf "n=%3d: " "$I"
	    echo $W | /usr/bin/time -p "$SUBMIT/agrep" $RE >$TMPDIR/n$I.out 2>$TMPDIR/n$I.time &
	    wait $!
            diff <(echo $W | "$BIN/agrep" $RE) $TMPDIR/n$I.out || echo "FAILED"
	    awk '/^(user|sys)/ { t += $2; } !/(^(real|user|sys))/ { print "WARNING:", $0; } END { printf "%*s\n", t*10, "*"; }' $TMPDIR/n$I.time
	fi
    done

else
  echo "agrep: SKIPPED"
fi
