from __future__ import absolute_import, division, print_function

from langkit.dsl import ASTNode, T, abstract
from langkit.expressions import AbstractProperty
from langkit.parsers import Grammar, List, Or

from lexer_example import Token
from utils import emit_and_print_errors


def run(name, runtime_check=False, abstract_root_prop=False):
    print('== {} =='.format(name))

    if abstract_root_prop:
        class FooNode(ASTNode):
            root_prop = AbstractProperty(T.Bool, public=True)

        @abstract
        class BaseNode(FooNode):
            root_prop = AbstractProperty(T.Bool, runtime_check=True)

        class Number(BaseNode):
            pass

        class Identifier(BaseNode):
            pass

    else:
        class FooNode(ASTNode):
            pass

        @abstract
        class BaseNode(FooNode):
            prop = AbstractProperty(T.Bool, public=True)

        class Number(BaseNode):
            prop = AbstractProperty(T.Bool, runtime_check=runtime_check)

        class Identifier(BaseNode):
            prop = AbstractProperty(T.Bool, runtime_check=runtime_check)

    grammar = Grammar('main_rule')
    grammar.add_rules(main_rule=List(Or(
        Number(Token.Number),
        Identifier(Token.Identifier),
    )))
    emit_and_print_errors(grammar)
    print('')


run('Abstract overrides without runtime check', runtime_check=False)
run('Abstract overrides with runtime check', runtime_check=True)
run('Abstract in root not overriden in list', abstract_root_prop=True)
print('Done')
