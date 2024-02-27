#!/usr/bin/env python

"""bgrep (backtracking grep).

This code is provided to let you compare your agrep against Python's
standard regular expression engine.

In CP4, you will implement bgrep yourself, but because this
implementation uses the standard re module, it would not be acceptable
as a solution for CP4."""

import re
import sys

r = sys.argv[1]
for w in sys.stdin:
    w = w.rstrip('\n')
    if re.fullmatch(r, w):
        print(f'{w}\n')
        
