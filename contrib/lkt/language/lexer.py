from __future__ import absolute_import, division, print_function

from langkit.lexer import (
    Ignore, Lexer, LexerToken, Literal, Pattern, WithSymbol, WithText
)


class Token(LexerToken):
    Identifier = WithSymbol()
    String = WithText()

    # Operators
    ExclMark = WithText()
    Colon = WithText()
    IntMark = WithText()
    Div = WithText()
    Comma = WithText()
    Times = WithText()
    Plus = WithText()
    Pipe = WithText()
    LeftArrow = WithText()
    Dot = WithText()
    Comb = WithText()
    At = WithText()
    LPar = WithText()
    RPar = WithText()
    LBrace = WithText()
    RBrace = WithText()
    LBrack = WithText()
    RBrack = WithText()
    ListPlus = WithText()
    ListStar = WithText()
    Equal = WithText()

    # Keywords
    GrammarKw = WithText()
    OrKw = WithText()
    ClassKw = WithText()
    FunKw = WithText()
    PublicKw = WithText()
    PrivateKw = WithText()
    NullKw = WithText()


lkt_lexer = Lexer(Token)

lkt_lexer.add_patterns(
    ("STRING_DBQ", r'\"(\\\"|[^\n\"])*\"'),
    ("STRING_SQ",  r"'(\\'|[^\n'])*'"),
)


lkt_lexer.add_rules(
    # Whitespace & EOF
    (Pattern(r"[ \t\r\n\f]+"), Ignore()),

    # Operators
    (Literal('!'),         Token.ExclMark),
    (Literal(':'),         Token.Colon),
    (Literal('?'),         Token.IntMark),
    (Literal('/'),         Token.Div),
    (Literal('*'),         Token.Times),
    (Literal('+'),         Token.Plus),
    (Literal('|'),         Token.Pipe),
    (Literal('<-'),        Token.LeftArrow),
    (Literal('.'),         Token.Dot),
    (Literal('('),         Token.LPar),
    (Literal(')'),         Token.RPar),
    (Literal('['),         Token.LBrack),
    (Literal(']'),         Token.RBrack),
    (Literal('{'),         Token.LBrace),
    (Literal('}'),         Token.RBrace),
    (Literal('|>'),        Token.Comb),
    (Literal(','),         Token.Comma),
    (Literal('@'),         Token.At),
    (Literal('list+'),     Token.ListPlus),
    (Literal('list*'),     Token.ListStar),
    (Literal('='),         Token.Equal),

    # Keywords
    (Literal('grammar'),   Token.GrammarKw),
    (Literal('or'),        Token.OrKw),
    (Literal('class'),     Token.ClassKw),
    (Literal('fun'),       Token.FunKw),
    (Literal('public'),    Token.PublicKw),
    (Literal('private'),   Token.PrivateKw),
    (Literal('null'),      Token.NullKw),

    # Identifiers
    (Pattern('[a-zA-Z_][a-zA-Z0-9_]*'), Token.Identifier),

    # Strings
    (Pattern('{STRING_SQ}|{STRING_DBQ}'), Token.String),
)
