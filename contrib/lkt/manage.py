#! /usr/bin/env python

from __future__ import absolute_import, division, print_function

from langkit.libmanage import ManageScript


class Manage(ManageScript):
    def create_context(self, args):
        from langkit.compile_context import CompileCtx

        from language.lexer import lkt_lexer
        from language.parser import lkt_grammar

        return CompileCtx(lang_name='lkt',
                          lexer=lkt_lexer,
                          grammar=lkt_grammar)

if __name__ == '__main__':
    Manage().run()
