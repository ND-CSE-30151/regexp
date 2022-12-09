#!/bin/bash

ROOT="$(cd "$(dirname $0)" && pwd)"/..
BIN=$ROOT/bin.$(uname | tr A-Z a-z)
SUBMIT=$ROOT/cp4
EXAMPLES=$ROOT/examples
TMPDIR=${TMPDIR:-/tmp}/test-cp4.$$
mkdir -p $TMPDIR
trap "rm -rf $TMPDIR" EXIT
trap "pkill -9 -g0; exit 130" INT

assert_equal () {
  if [ "$1" = "$2" ]; then
    echo "PASSED"
  else
    echo "FAILED ($1 != $2)"
  fi
}

if [ -x "$SUBMIT/parse_re" ]; then
  for REGEXP in "(ab|a)*" "(a|b)*aba" "" "a" "a*" "ab" "abc" "abcd" "a|b" "a|b|c" "a|b|c|d" "a*b*" "(ab)*" "ab|cd" "(ab)|(cd)" "a*|b*" "(a|b)*" "(a)" "((a))" "a(b)" "(a)b" "()" "|" "(|)" "(a|)" "(|a)" "a||b" "()\1" "()()()()()()()()()()\10" "()()()()()()()()()()\10*" "()()()()()()()()()()\g<10>" "()()()()()()()()()()\g<1>0"; do
    echo -n 'parse_re "'"$REGEXP"'": '
    assert_equal "$("$BIN/parse_re" "$REGEXP")" "$("$SUBMIT/parse_re" "$REGEXP" | "$BIN/normalize_tree")"
  done
else
  echo "parse_re: SKIPPED"
fi

if [ -x "$SUBMIT/bgrep" ]; then
    for REGEXP in "((a|b)*)\1" "(a|b)*\1"; do
	for W in "" abb aba baabaa aabbaa; do
	    echo -n "bgrep \"$REGEXP\" \"$W\": "
	    assert_equal $(echo "$W" | "$BIN/bgrep" "$REGEXP") $(echo "$W" | "$SUBMIT/bgrep" "$REGEXP")
	done
    done

    for REGEXP in "(aaa*)\1\1*" "()*"; do
	for W in "" a aa aaa aaaa aaaaa; do
	    echo -n "bgrep \"$REGEXP\" \"$W\": "
	    assert_equal $(echo "$W" | "$BIN/bgrep" "$REGEXP") $(echo "$W" | "$SUBMIT/bgrep" "$REGEXP")
	done
    done
    
    for REGEXP in "(a*)(a*)#\1#\1"; do
	for W in "aa##" "aa#a#a" "aa#aa#aa" "aa#a#aa" "aa#aa#a"; do
	    echo -n "bgrep \"$REGEXP\" \"$W\": "
	    assert_equal $(echo "$W" | "$BIN/bgrep" "$REGEXP") $(echo "$W" | "$SUBMIT/bgrep" "$REGEXP")
	done
    done
else
    echo "bgrep: SKIPPED"
fi

if [ -x "$SUBMIT/cnf_to_re" ]; then
    for PHI in "(x)" "(!x)" "(x)&(x)" "(x)&(!x)" "(x|x)" "(x|!x)" "(x|x|x)" "(x|x|x)&(!x|!x|!x)" "(x1|x1|x2)&(!x1|!x2|!x2)&(!x1|x2|x2)" "(x2|!x1|!x1)&(!x1|!x2|!x2)&(x1|!x2|!x2)&(x1|x2|x1)"; do
	echo -n "cnf_to_re \"$PHI\": "
	"$SUBMIT/cnf_to_re" "$PHI" > $TMPDIR/cnf_to_re.out
	RE=$(perl -ne 'if (/^regexp:(.*)$/) { print "$1\n"; }' < $TMPDIR/cnf_to_re.out)
	W=$(perl -ne 'if (/^string:(.*)$/) { print "$1\n"; }' < $TMPDIR/cnf_to_re.out)
	if [ -z $(echo $W | "$BIN/bgrep" $RE) ]; then
	    ANS="unsatisfiable"
	else
	    ANS="satisfiable"
	fi
	assert_equal $("$BIN/sat" "$PHI") $ANS
    done

    echo "time cnf_to_re (log-log scale; this should look linear, after a certain point):"
    PHI="(x|x|x)"
    N=1
    for I in $(seq 1 12); do
	printf "n=%6d" "$N"
	/usr/bin/time -p "$SUBMIT/cnf_to_re" "$PHI" >/dev/null 2>$TMPDIR/n$I.time &
	wait $!
	awk '/^(user|sys)/ { t += $2; } END { printf " t=%6.2f %*s\n", t, int(log(t*100)*10), "*"; }' $TMPDIR/n$I.time
	PHI="${PHI}&${PHI}"
	N=$(($N+$N))
    done

else
    echo "cnf_to_re: SKIPPED"
fi
