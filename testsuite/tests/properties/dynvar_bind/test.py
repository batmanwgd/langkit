from __future__ import absolute_import, division, print_function

from langkit.dsl import ASTNode, Field, LexicalEnv
from langkit.envs import EnvSpec, add_env, add_to_env_kv
from langkit.expressions import DynamicVariable, Self, langkit_property
from langkit.parsers import Grammar, List

from lexer_example import Token
from utils import build_and_run


Env = DynamicVariable('env', LexicalEnv)


class FooNode(ASTNode):
    pass


class Name(FooNode):
    token_node = True


class Decl(FooNode):
    name = Field()
    refs = Field()

    env_spec = EnvSpec(
        add_to_env_kv(
            key=Self.name.symbol, val=Self
        ),
        add_env()
    )


class Ref(FooNode):
    name = Field()

    env_spec = EnvSpec(
        add_to_env_kv(
            key=Self.name.symbol, val=Self
        )
    )

    @langkit_property(public=True)
    def resolve():
        return Env.bind(Self.parent.parent.node_env,
                        Env.get(Self.name.symbol).at(0))


foo_grammar = Grammar('main_rule')
foo_grammar.add_rules(
    main_rule=List(foo_grammar.decl),
    decl=Decl(
        Name(Token.Identifier),
        '(', List(foo_grammar.ref, empty_valid=True), ')',
    ),
    ref=Ref(Name(Token.Identifier)),
)
build_and_run(foo_grammar, 'main.py')
print('Done')
