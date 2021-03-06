from __future__ import absolute_import, division, print_function

import langkit.compiled_types as ct
from langkit.compiled_types import T
from langkit.language_api import AbstractAPISettings
from langkit.utils import dispatch_on_type


class OCamlAPISettings(AbstractAPISettings):
    """Container for OCaml API generation settings."""

    name = 'ocaml'

    class AnalysisContextType(object):
        """
        Placeholder to represent the analysis context type in our depedency
        tracking system (see the type_graph and add_dep methods below).
        """
        pass

    def add_dep(self, typ, dep):
        """
        Adds the dependency dep to the type typ in the type_graph.
        """
        if typ not in self.type_graph:
            self.type_graph[typ] = []

        if dep not in self.type_graph:
            self.type_graph[dep] = []

        self.type_graph[typ].append(dep)

    def __init__(self, ctx, c_api_settings):
        self.context = ctx
        self.c_api_settings = c_api_settings

        self.AnalysisContext = self.AnalysisContextType()

        # Dependency graph for types
        self.type_graph = {}

        self.add_dep(T.AnalysisUnit, T.root_node.entity)
        self.add_dep(T.Symbol, self.AnalysisContext)
        self.add_dep(self.AnalysisContext, T.AnalysisUnit)

    def is_empty_type(self, type):
        """
        Test if the given type is an empty type. An empty type is a structure
        that does not contain any field, or the fields are also
        empty structs. An empty type can also be an ASTNodeType that does not
        contain any concrete subclasses. We Want to check this because we
        cannot write empty sum types or empty structures in OCaml.

        :param ct.CompiledType: The type we want to check if it is empty.
        :rtype: bool
        """
        return dispatch_on_type(type, [
            (ct.ASTNodeType, lambda t:
                len(t.concrete_subclasses) == 0),
            (ct.EntityType, lambda t: self.is_empty_type(t.astnode)),
            (ct.ArrayType, lambda t: self.is_empty_type(t.element_type)),
            (ct.StructType, lambda t:
                all(self.is_empty_type(field.type)
                    for field in t.get_fields())),
            (ct.CompiledType, lambda _: False)
        ])

    def polymorphic_variant_name(self, type):
        """
        Return a string representing the polymorphic variant for the given
        concrete type.

        :param ct.ASTNodeType type: The type for which we want the
            polymorphic variant name.
        :rtype: list[ct.CompiledType]
        """
        return "`{}".format(type.entity.api_name.camel)

    def fields_name(self, for_module, from_module=None):
        """
        Return a string representing the name of the OCaml type for the
        fields of a node.

        :param ct.ASTNodeType for_module: The field comes from this module.
        :param ct.ASTNodeType from_module: The field is accessed inside this
            module.
        :rtype: list[ct.CompiledType]
        """
        if for_module == from_module:
            return 'fields'
        else:
            return "{}.{}".format(self.module_name(for_module), 'fields')

    def get_field_type(self, field):
        """
        Return a precice type for the given Field instance. The list contains
        the possible concrete types of the given field. If there is only
        one element, the only element can be abstract, this means that the
        type is precise enough.

        :param ct.Field field: The field for which we want a precice type.
        :rtype: list[ct.CompiledType]
        """

        precise_types = field.precise_types
        concrete_precise_types = list(frozenset(
            typ
            for precise_type in precise_types.matched_types
            for typ in precise_type.concrete_subclasses
        ))

        # If the list of concrete precise types has the same length as the list
        # of concrete subclasses of the minimal common ancestor type, we can
        # replace the list of concrete precise types by a singleton list
        # containing the common ancestor type.
        super_type = precise_types.minimal_common_type
        if len(super_type.concrete_subclasses) == len(concrete_precise_types):
            concrete_precise_types = [super_type]

        return concrete_precise_types

    def get_parse_fields(self, node):
        """
        Return all the parse fields to be exposed as a field in record of node.

        :param ct.ASTNodeType node: The node type of which we want to get the
            parse fields.
        :rtype: list[ct.Field]
        """
        return node.get_parse_fields(
            lambda x: not x.is_overriding and not x.abstract and not x.null
        )

    def get_properties(self, node):
        """
        Return the list of all properties that should be exposed to the user.

        :param ct.ASTNodeType node: The node for which we want to get the
            properties.
        :rtype: list[ct.BaseField]
        """

        return [
            field for field in node.fields_with_accessors()
            if field.is_property
        ]

    def array_wrapper(self, array_type):
        return (ct.T.entity.array
                if array_type.element_type.is_entity_type
                else array_type).api_name.camel

    def struct_name(self, type):
        """
        Returns the OCaml module containing the low-level structure for the
        given type.

        :param ct.CompiledType type: Type we want to get the module name.
        :rtype: str
        """

        return dispatch_on_type(type, [
            (ct.EnumType, lambda t: self.module_name(t)),
            (T.Token, lambda t: self.module_name(t)),
            (T.Symbol, lambda t: self.module_name(t)),
            (ct.ASTNodeType, lambda t: self.module_name(t.entity)),
            (ct.EntityType, lambda _: 'EntityStruct'),
            (T.AnalysisUnit, lambda t: '{}Struct'.format(self.module_name(t))),
            (ct.ArrayType, lambda t: '{}Struct'.format(self.array_wrapper(t))),
            (ct.StructType, lambda t: '{}Struct'.format(self.module_name(t))),
            (T.BigInt, lambda t: self.module_name(t)),
        ])

    def node_name(self, type):
        """
        Returns the OCaml name for an ASTNodeType or an EntityType.

        :param ct.EntityType | ct.ASTNodeType type: Type we want to get the
            name.
        :rtype: str
        """
        return dispatch_on_type(type, [
            (ct.ASTNodeType, lambda t: self.node_name(t.entity)),
            (ct.EntityType, lambda t: t.astnode.kwless_raw_name.camel),
        ])

    def module_name(self, type):
        """
        Returns the OCaml module containing the definition for the given type.

        :param ct.CompiledType type: Type we want to get the module name.
        :rtype: str
        """

        return dispatch_on_type(type, [
            (ct.EnumType, lambda enum: enum.api_name.camel),
            (T.Token, lambda _: 'Token'),
            (T.Symbol, lambda _: 'Symbol'),
            (T.Character, lambda _: 'Character'),
            (ct.ASTNodeType, lambda t: self.module_name(t.entity)),
            (ct.EntityType, lambda t: '{}Type'.format(self.node_name(t))),
            (T.AnalysisUnit, lambda t: t.api_name.camel),
            (ct.ArrayType, lambda t: t.api_name.camel),
            (ct.StructType, lambda t: t.api_name.camel),
            (T.BigInt, lambda t: 'BigInteger'),
        ])

    def wrap_requires_context(self, type):
        """
        Returns true if the given type need the context to be wrapped in an
        OCaml value.

        :param ct.CompiledType type: Type for which we want to know if the
            context is needed.
        :rtype: bool
        """

        return dispatch_on_type(type, [
            (T.AnalysisUnit, lambda _: True),
            (ct.EnumType, lambda _: False),
            (ct.ASTNodeType, lambda _: False),
            (ct.EntityType, lambda _: True),
            (T.Token, lambda _: False),
            (T.Symbol, lambda t: False),
            (T.Bool, lambda _: False),
            (T.Int, lambda _: False),
            (T.Character, lambda _: False),
            (ct.ArrayType, lambda t:
                self.wrap_requires_context(t.element_type)),
            (ct.StructType, lambda t:
                any(self.wrap_requires_context(field.type)
                    for field in t.get_fields())),
            (T.BigInt, lambda _: False),
            (T.EnvRebindings, lambda _: False),
        ], exception=TypeError(
            'Unhandled field type in the OCaml binding'
            ' (wrapping): {}'.format(type)
        ))

    def has_ctype_view(self, type):
        """
        Given a type, return true if it has a ctype view. Having a ctype view
        means that wrap and unwrap operations are not needed explicitely.

        :param ct.CompiledType type: The type to check.
        :rtype: bool
        """

        return dispatch_on_type(type, [
            (T.AnalysisUnit, lambda _: False),
            (ct.EnumType, lambda _: True),
            (ct.ASTNodeType, lambda _: True),
            (ct.EntityType, lambda _: False),
            (T.Token, lambda _: True),
            (T.Symbol, lambda _: False),
            (T.Bool, lambda _: True),
            (T.Int, lambda _: True),
            (T.Character, lambda _: True),
            (ct.ArrayType, lambda _: False),
            (ct.StructType, lambda _: False),
            (T.BigInt, lambda _: False),
            (T.EnvRebindings, lambda _: True),
        ], exception=TypeError(
            'Unhandled field type in the OCaml binding'
            ' (has_ctype_view): {}'.format(type)
        ))

    def wrap_value(self, value, type, context, check_for_null=False):
        """
        Given an expression for a low-level value and the associated type,
        return an other expression that yields the corresponding high-level
        value.

        :param str value: Expression yielding a low-level value.
        :param ct.CompiledType type: Type corresponding to the "value"
            expression.
        :param bool check_for_null: If true, return an OCaml expression that
            first checks if the underlying node value is null. If it is the
            case, the expression is evaluated to None. We check null only for
            entity types.
        :rtype: str
        """

        def from_module(typ, value):
            context_arg = (
                '{} '.format(context)
                if self.wrap_requires_context(typ) else ''
            )

            return "{}.wrap {}({})".format(
                self.module_name(typ),
                context_arg,
                value
            )

        wrapped_result = (
            value
            if self.has_ctype_view(type)
            else from_module(type, value)
        )

        if check_for_null and type.is_entity_type:
            return ("if is_null (getf {} EntityStruct.node) then None "
                    + "else Some ({})").format(value, wrapped_result)
        else:
            return wrapped_result

    def unwrap_value(self, value, type, context, check_for_none=False):
        """
        Given an expression for a low-level value and the associated type,
        return an other expression that yields the corresponding high-level
        value.

        :param str value: Expression yielding a low-level value.
        :param ct.CompiledType type: Type corresponding to the "value"
            expression.
        :param bool check_for_none: If true, check if the value is None before
            returning a C API value. If it is the case, the expression is
            evaluated to an empty struct. We check for None only for entity
            types.
        :rtype: str
        """
        def from_module(typ, value):
            context_arg = (
                '{} '.format(context) if type.conversion_requires_context
                else ''
            )

            return "{}.unwrap {}({})".format(
                self.module_name(typ),
                context_arg,
                value
            )

        if type.is_entity_type:
            # For entity type, the unwrap function is inside the root node
            if check_for_none:
                return ('match {} with'
                        ' Some n -> {}'
                        ' | None -> make EntityStruct.c_type'
                        .format(value, from_module(T.root_node, 'n')))
            else:
                return from_module(T.root_node, value)
        elif self.has_ctype_view(type):
            return value
        else:
            return from_module(type, value)

    def is_struct(self, type, from_module=None):
        """
        Return true if the given type is defined as a ctypes structure without
        a view.

        :param CompiledType type: Type we want to test.
        :param ct.ASTNodeType from_module: The field is assumed to be accessed
            within this module.
        :rtype: str
        """
        if not type.is_entity_type and from_module == type:
            return "c_type"

        return dispatch_on_type(type, [
            (T.Bool, lambda _: False),
            (T.Int, lambda _: False),
            (T.Character, lambda _: False),
            (T.Token, lambda _: True),
            (T.Symbol, lambda _: False),
            (ct.EnumType, lambda _: False),
            (ct.ASTNodeType, lambda _: False),
            (ct.EntityType, lambda _: True),
            (T.AnalysisUnit, lambda _: True),
            (ct.ArrayType, lambda _: True),
            (ct.StructType, lambda _: True),
            (T.BigInt, lambda _: False),
            (T.EnvRebindings, lambda _: False),
        ])

    def finalize_function(self, type):
        """
        Return the name of the finalization function if a value of the given
        type must be finalized. A value needs a finalization if it is
        completly converted to an OCaml value. This function is used
        when calling a C API function, where, we allocated a C value when
        unwrapping an OCaml value. Thus, we need to finalize it after the call
        to the C API function.

        :param CompiledType type: The type for which we want to get the
            finalization function name.
        :rtype: str
        """

        def dec_ref(type):
            if type.is_refcounted:
                return '{}.dec_ref'.format(self.struct_name(type))
            else:
                return None

        return dispatch_on_type(type, [
            (T.BigInt, lambda t: '{}.decref'.format(self.struct_name(t))),
            (ct.ASTNodeType, lambda _: None),
            (ct.EntityType, lambda _: None),
            (T.AnalysisUnit, lambda _: None),
            (ct.CompiledType, lambda t: dec_ref(t))
        ])

    def c_type(self, type, from_module=None):
        """
        Return the name of the OCaml ctypes value defining the type to use in
        the C API for ``type``. For ctypes, types passed to the foreign
        function that import a c function are values. This returns the
        associated value for the given type.

        :param CompiledType type: The type for which we want to get the C type
            name.
        :param CompiledType from_module: Module from which we want to access
            the name.
        :rtype: str
        """
        if not type.is_entity_type and from_module == type:
            return "c_type"

        return dispatch_on_type(type, [
            (T.Bool, lambda _: 'bool'),
            (T.Int, lambda _: 'int'),
            (T.Character, lambda t: '{}.c_type'.format(self.module_name(t))),
            (T.Token, lambda t: '{}.c_type'.format(self.module_name(t))),
            (T.Symbol, lambda t: '{}.c_type'.format(self.module_name(t))),
            (ct.EnumType, lambda t: '{}.c_type'.format(self.module_name(t))),
            (ct.ASTNodeType, lambda _: '(ptr void)'),
            (ct.EntityType, lambda t: '{}.c_type'.format(self.struct_name(t))),
            (T.AnalysisUnit, lambda t:
                '{}.c_type'.format(self.struct_name(t))),
            (ct.ArrayType, lambda t: '{}.c_type'.format(self.struct_name(t))),
            (ct.StructType, lambda t: "{}.c_type".format(self.struct_name(t))),
            (T.BigInt, lambda t: '{}.c_type'.format(self.module_name(t))),
            (T.EnvRebindings, lambda _: '(ptr void)'),
        ])

    def c_value_type(self, type, from_module=None):
        """
        Return the name of the type to use in the C API for ``type``. This
        is the type of a c value.

        :param CompiledType type: The type for which we want to get the C type
            name.
        :param CompiledType from_module: Module from which we want to access
            the name.
        :rtype: str
        """
        if not type.is_entity_type and from_module == type:
            return "c_type"

        return dispatch_on_type(type, [
            (T.Bool, lambda _: 'bool'),
            (T.Int, lambda _: 'int'),
            (T.Character, lambda _: 'string'),
            (T.Token, lambda t:
                '{}.token structure'.format(self.module_name(t))),
            (T.Symbol, lambda t:
                '{}.t structure'.format(self.module_name(t))),
            (ct.EnumType, lambda t: self.type_public_name(t)),
            (ct.ASTNodeType, lambda _: 'BareNode.t'),
            (ct.EntityType, lambda t:
                '{}.t structure'.format(self.struct_name(t))),
            (T.AnalysisUnit, lambda t:
                '{}.t'.format(self.struct_name(t))),
            (ct.ArrayType, lambda t:
                '{}.t structure ptr'.format(self.struct_name(t))),
            (ct.StructType, lambda t:
                '{}.t structure'.format(self.struct_name(t))),
            (T.BigInt, lambda _: 'unit ptr'),
            (T.EnvRebindings, lambda t: self.type_public_name(t)),
        ])

    def type_public_name(self, type, from_module=None):
        """
        Return the public API name for a given CompiledType instance.

        :param CompiledType type: The type for which we want to get the name.
        :param CompiledType from_module: Module from which we want to access
            the name.
        :rtype: str
        """
        if from_module == type:
            return "t"

        return dispatch_on_type(type, [
            (T.Bool, lambda _: 'bool'),
            (T.Int, lambda _: 'int'),
            (T.Character, lambda _: 'string'),
            (T.Token, lambda t: '{}.t'.format(self.module_name(t))),
            (T.Symbol, lambda _: 'string'),
            (ct.EnumType, lambda t: '{}.t'.format(self.module_name(t))),
            (ct.ASTNodeType, lambda t: self.type_public_name(t.entity)),
            (ct.EntityType, lambda t: "{}.t".format(self.module_name(t))),
            (T.AnalysisUnit, lambda t: "{}.t".format(t.api_name)),
            (ct.ArrayType, lambda t:
                'string' if t.is_string_type else
                '{} list'.format(self.type_public_name(type.element_type))),
            (ct.StructType, lambda _: "{}.t".format(type.api_name.camel)),
            (T.BigInt, lambda t: '{}.t'.format(self.module_name(t))),
            (T.EnvRebindings, lambda _: 'Rebindings.t'),
        ])

    def register_struct_type(self, typ):
        """
        Register a struct type together with all the types it depends on, to
        the graph of type dependencies "type_graph".

        :param CompiledType typ: The type we want to register in the graph.
        """
        for f in typ.get_fields(lambda t: not self.is_empty_type(t.type)):
            if f.type.is_entity_type:
                # For an entity type, we append the root entity since it is
                # the only struct generated.
                field_type = T.root_node.entity
            else:
                field_type = f.type

            self.add_dep(typ, field_type)

    def register_array_type(self, typ):
        """
        Register an array type in the graph of dependency, adding a dependency
        between the array type and the element type.

        :param CompiledType typ: The type we want to register in the graph.
        """
        if typ.element_type.is_entity_type:
            self.add_dep(typ, T.root_node.entity)
        else:
            self.add_dep(typ, typ.element_type)

    def ordered_types(self):
        """
        Return all the types sorted so that if type T1 depends on type T2, T2
        appears before T1. Returns the topological order of the types.

        :rtype: list[ct.CompiledType]
        """
        marks = {typ: 'white' for typ in self.type_graph}

        def dfs(vertex, topo):
            if marks[vertex] == 'black':
                # Already visited
                return
            else:
                # TODO: cycle detected, this is not yet implemented
                assert marks[vertex] == 'white', 'cycle detected'

                marks[vertex] = 'gray'

                for succ in self.type_graph[vertex]:
                    dfs(succ, topo)

                topo.append(vertex)

                marks[vertex] = 'black'

        topo = []

        for vertex in self.type_graph:
            dfs(vertex, topo)

        return topo

    def escape_ocaml_keyword(self, str):
        """
        Return a replacement for the given string if the string is an OCaml
        keyword that cannot appear as an identifier.

        :param string str: The string we want to replace if necessary.
        :rtype: str
        """
        replacement = {
            "val": "value",
            "constraint": "constr"
        }

        return replacement.get(str, str)

    def field_name(self, field):
        """
        Given a Field instance, return the name of the field to be used for an
        OCaml identifier.

        :param ct.Field field: The field for which we want it's name.
        :rtype: str
        """
        return self.escape_ocaml_keyword(field.api_name.lower)
