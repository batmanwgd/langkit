from __future__ import absolute_import, division, print_function

import libfoolang


ctx = libfoolang.AnalysisContext()

text = b'1 2'
u = ctx.get_from_buffer('main.txt', text)
if u.diagnostics:
    for d in u.diagnostics:
        print(d)
