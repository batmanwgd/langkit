"""
Test that doing If(...).then(...) compiles properly. It used not to.
"""

from __future__ import absolute_import, division, print_function

from langkit.dsl import ASTNode
from langkit.expressions import If, Self, langkit_property
from langkit.parsers import Grammar

from utils import build_and_run


class FooNode(ASTNode):
    pass


class Example(FooNode):
    @langkit_property(public=True)
    def foo():
        return If(True, Self, Self).then(lambda s: s).as_bare_entity


foo_grammar = Grammar('main_rule')
foo_grammar.add_rules(main_rule=Example('example'))
build_and_run(foo_grammar, 'main.py')
print('Done')
