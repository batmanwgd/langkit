from __future__ import absolute_import, division, print_function

import os.path

import libfoolang


print('main.py: Running...')

ctx = libfoolang.AnalysisContext()
u = ctx.get_from_buffer('foo.txt', 'example')
print('Unit filename: {}'.format(os.path.basename(u.filename)))
print('main.py: Done.')