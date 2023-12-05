#!/bin/bash

ROOT="$(cd "$(dirname $0)" && pwd)"/..
BIN=$ROOT/bin.$(uname | tr A-Z a-z)
SUBMIT=$ROOT/cp4
EXAMPLES=$ROOT/examples
TMPDIR=${TMPDIR:-/tmp}/test-cp4.$$
mkdir -p $TMPDIR
trap "rm -rf $TMPDIR" EXIT
trap "pkill -9 -g0; exit 130" INT
set -o pipefail

assert_equal () {
  if [ "$?" -ne 0 ]; then
    echo "FAILED (error)"
  elif [ "$1" = "$2" ]; then
    echo "PASSED"
  else
    echo "FAILED"
    echo "  correct output: $1"
    echo "     your output: $2"
  fi
}

fail () {
  echo "FAILED"
}

err () {
  echo "(error)"
}

if [ -x "$SUBMIT/parse_re" ]; then
  for REGEXP in "(ab|a)*" "(a|b)*aba" "" "a" "a*" "ab" "abc" "abcd" "a|b" "a|b|c" "a|b|c|d" "a*b*" "(ab)*" "ab|cd" "(ab)|(cd)" "a*|b*" "(a|b)*" "(a)" "((a))" "a(b)" "(a)b" "()" "|" "(|)" "(a|)" "(|a)" "a||b" "()\1" "()()()()()()()()()()\10" "()()()()()()()()()()\10*" "()()()()()()()()()()\g<10>" "()()()()()()()()()()\g<1>0"; do
    echo -n 'parse_re "'"$REGEXP"'": '
    assert_equal "$("$BIN/parse_re" -g -b "$REGEXP")" "$("$SUBMIT/parse_re" "$REGEXP" || err)"
  done
else
  echo "parse_re: SKIPPED"
fi

if [ -x "$SUBMIT/bgrep" ]; then
    for REGEXP in "((a|b)*)\1" "(a|b)*\1"; do
	for W in "" abb aba baabaa aabbaa; do
	    echo -n "echo \"$W\" | bgrep \"$REGEXP\": "
            assert_equal "$(echo "$W" | "$BIN/bgrep" "$REGEXP")" "$(echo "$W" | "$SUBMIT/bgrep" "$REGEXP" || err)"
	done
    done

    for REGEXP in "(aaa*)\1\1*" "()*"; do
	for W in "" a aa aaa aaaa aaaaa aaaaaaaaaaaaaaaaaaaaaaaaa; do
	    echo -n "echo \"$W\" | bgrep \"$REGEXP\": "
	    assert_equal "$(echo "$W" | "$BIN/bgrep" "$REGEXP")" "$(echo "$W" | "$SUBMIT/bgrep" "$REGEXP" || err)"
	done
    done
    
    for REGEXP in "(a*)(a*)#\1#\1"; do
	for W in "aa##" "aa#a#a" "aa#aa#aa" "aa#a#aa" "aa#aa#a"; do
	    echo -n "echo \"$W\" | bgrep \"$REGEXP\": "
	    assert_equal "$(echo "$W" | "$BIN/bgrep" "$REGEXP")" "$(echo "$W" | "$SUBMIT/bgrep" "$REGEXP" || err)"
	done
    done
else
    echo "bgrep: SKIPPED"
fi

if [ -x "$SUBMIT/sat_to_re" ]; then
    for PHI in examples/{sipser-phi.cnf,unsat-2.cnf,random-{1,2,3,4,5,6,7,8,9,10}.cnf}; do
	echo -n "sat_to_re \"$PHI\": "
	"$SUBMIT/sat_to_re" "$PHI" "$TMPDIR/regexp" "$TMPDIR/string"
        if [ $? -ne 0 ]; then fail; continue; fi
	if [ -z $("$BIN/bgrep" -f "$TMPDIR/regexp" "$TMPDIR/string") ]; then
	    ANS="unsatisfiable"
	else
	    ANS="satisfiable"
	fi
	assert_equal "$("$BIN/solve_sat" "$PHI")" $ANS
    done

    echo "time sat_to_re (log-log scale; if it is polynomial-time, this should look linear):"
    N=1
    PRINT=0
    for I in $(seq 1 100); do
        "$BIN/gen_sat" $N > "$TMPDIR/gen_sat.out"
	/usr/bin/time -p "$SUBMIT/sat_to_re" "$TMPDIR/gen_sat.out" "$TMPDIR/regexp" "$TMPDIR/string" 2>$TMPDIR/n$I.time &
	wait $!
        # Start printing when time is >= 50ms, quit when >= 3000ms
        T=$(awk '/^(user|sys)/ { t += $2; } END { printf "%d\n", t*1000; }' $TMPDIR/n$I.time)
        if [ $T -ge 50 ]; then PRINT=1; fi
        if [ $PRINT -eq 1 ]; then
	  printf "n=%7d" "$N"
          awk '/^(user|sys)/ { t += $2; } END { printf " t=%6.2f %*s\n", t, int(log(t*1000)), "*"; }' $TMPDIR/n$I.time
        fi
        if [ $T -ge 3000 ]; then break; fi
	N=$(($N+$N))
    done

else
    echo "sat_to_re: SKIPPED"
fi
