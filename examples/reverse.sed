s/((a|b)*)/^\g<1>/
:loop
s/((a|b)*)^(a|b)((a|b)*)/\g<3>\g<1>^\g<4>/
/(a|b)*^(a|b)(a|b)*/bloop
s/((a|b)*)^/\g<1>/
