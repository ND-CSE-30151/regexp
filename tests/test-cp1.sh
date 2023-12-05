#!/bin/bash

ROOT="$(cd "$(dirname $0)" && pwd)"/..
BIN=$ROOT/bin.$(uname | tr A-Z a-z)
SUBMIT=$ROOT/cp1
EXAMPLES=$ROOT/examples
TMPDIR=${TMPDIR:-/tmp}/test-cp1.$$
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

if [ -x "$SUBMIT/nfa_path" ]; then
    for W in 010110 111; do
	echo -n "nfa_path sipser-n1.nfa \"$W\": "
	assert_equal "$("$BIN/nfa_path" "$EXAMPLES/sipser-n1.nfa" "$W" | head -1)" "$("$SUBMIT/nfa_path" "$EXAMPLES/sipser-n1.nfa" "$W" | head -1 || err)"
    done

    for W in "" 0 1 00 01 10 11 000 001 010 011 100 101 110; do
	echo -n "nfa_path sipser-n1.nfa \"$W\": "
	assert_nodiff <("$BIN/nfa_path" "$EXAMPLES/sipser-n1.nfa" "$W") <("$SUBMIT/nfa_path" "$EXAMPLES/sipser-n1.nfa" "$W" || err)
    done

    for W in "" 000000; do
	echo -n "nfa_path sipser-n3.nfa \"$W\": "
	assert_equal "$("$BIN/nfa_path" "$EXAMPLES/sipser-n3.nfa" "$W" | head -1)" "$("$SUBMIT/nfa_path" "$EXAMPLES/sipser-n3.nfa" "$W" | head -1 || err)"
    done

    for W in 0 00 000 0000 00000; do
	echo -n "nfa_path sipser-n3.nfa \"$W\": "
	assert_nodiff <("$BIN/nfa_path" "$EXAMPLES/sipser-n3.nfa" "$W") <("$SUBMIT/nfa_path" "$EXAMPLES/sipser-n3.nfa" "$W" || err)
    done

    for W in "" a baba baa b bb babba; do
	echo -n "nfa_path sipser-n4.nfa \"$W\": "
	assert_nodiff <("$BIN/nfa_path" "$EXAMPLES/sipser-n4.nfa" "$W") <("$SUBMIT/nfa_path" "$EXAMPLES/sipser-n4.nfa" "$W" || err)
    done

    for W in "" a aa aaa; do
	echo -n "nfa_path epsilons.nfa \"$W\": "
	assert_equal "$("$BIN/nfa_path" "$EXAMPLES/epsilons.nfa" "$W" | head -1)" "$("$SUBMIT/nfa_path" "$EXAMPLES/epsilons.nfa" "$W" | head -1 || err)"
    done

    for W in "" a; do
	echo -n "nfa_path cycle.nfa \"$W\": "
	assert_equal "$("$BIN/nfa_path" "$EXAMPLES/cycle.nfa" "$W" | head -1)" "$("$SUBMIT/nfa_path" "$EXAMPLES/cycle.nfa" "$W" | head -1 || err)"
    done

    for W in "" b a ab aa aab aaa aaab; do
	echo -n "nfa_path slow1.nfa \"$W\": "
	assert_equal "$("$BIN/nfa_path" "$EXAMPLES/slow1.nfa" "$W" | head -1)" "$("$SUBMIT/nfa_path" "$EXAMPLES/slow1.nfa" "$W" | head -1 || err)"
    done

    for W in "" b a ab aa aab aaa aaab; do
	echo -n "nfa_path slow2.nfa \"$W\": "
	assert_equal "$("$BIN/nfa_path" "$EXAMPLES/slow2.nfa" "$W" | head -1)" "$("$SUBMIT/nfa_path" "$EXAMPLES/slow2.nfa" "$W" | head -1 || err)"
    done

    for W in "" b a ab aa aab aaa aaab; do
	echo -n "nfa_path slow3.nfa \"$W\": "
	assert_equal "$("$BIN/nfa_path" "$EXAMPLES/slow3.nfa" "$W" | head -1)" "$("$SUBMIT/nfa_path" "$EXAMPLES/slow3.nfa" "$W" | head -1 || err)"
    done

    echo "time nfa_path (if it is Θ(n^2), this should look linear):"
    RE=""
    W="b"
    for I in $(seq 1 400); do
	RE="(|a)${RE}"
	W="a${W}"
	if [ $(($I**2/10000)) -gt $((($I-1)**2/10000)) ]; then
	    printf "n=%3d: " "$I"
	    "$BIN/re_to_nfa" "$RE" > $TMPDIR/n$I.nfa
	    /usr/bin/time -p "$SUBMIT/nfa_path" $TMPDIR/n$I.nfa "$W" >$TMPDIR/n$I.out 2>$TMPDIR/n$I.time &
	    wait $!
            diff <("$BIN/nfa_path" $TMPDIR/n$I.nfa "$W") $TMPDIR/n$I.out || echo "FAILED"
	    awk '/^(user|sys)/ { t += $2; } !/^(real|user|sys)/ { print "WARNING:", $0; } END { printf "%*s\n", t*50, "*"; }' $TMPDIR/n$I.time
	fi
    done

else
  echo "nfa_path: SKIPPED"
fi
