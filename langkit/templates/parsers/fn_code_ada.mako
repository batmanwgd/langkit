## vim: filetype=makoada

<% ret_type = _self.get_type().storage_type_name() %>

${_self.gen_fn_name}_Memo : ${ret_type}_Memos.Memo_Type;

function ${_self.gen_fn_name} (Parser : in out Parser_Type;
                               Pos    : Token_Index)
                               return ${ret_type}
is
   % for name, typ in parser_context.var_defs:
      ${name} : ${typ.storage_type_name()}
         ${":= " + typ.storage_nullexpr() if typ.storage_nullexpr() else ""};
   % endfor

   % if _self.is_left_recursive():
      Mem_Pos : Token_Index := Pos;
      Mem_Res : ${ret_type} := ${_self.get_type().storage_nullexpr()};
   % endif

   M : ${ret_type}_Memos.Memo_Entry := Get (${_self.gen_fn_name}_Memo, Pos);

begin

   if M.State = Success then
      Parser.Current_Pos := M.Final_Pos;
      ${parser_context.res_var_name} := M.Instance;
      return ${parser_context.res_var_name};
   elsif M.State = Failure then
      Parser.Current_Pos := -1;
      return ${parser_context.res_var_name};
   end if;

   % if _self.is_left_recursive():
       Set (${_self.gen_fn_name}_Memo,
            False,
            ${parser_context.res_var_name},
            Pos,
            Mem_Pos);

       <<Try_Again>>
   % endif

   ---------------------------
   -- MAIN COMBINATORS CODE --
   ---------------------------

   ${parser_context.code}

   -------------------------------
   -- END MAIN COMBINATORS CODE --
   -------------------------------

   % if _self.is_left_recursive():
      if ${parser_context.pos_var_name} > Mem_Pos then
         Mem_Pos := ${parser_context.pos_var_name};
         Mem_Res := ${parser_context.res_var_name};
         Set (${_self.gen_fn_name}_Memo,
              ${parser_context.pos_var_name} /= -1,
              ${parser_context.res_var_name},
              Pos,
              ${parser_context.pos_var_name});
         goto Try_Again;

      elsif Mem_Pos > Pos then
         ${parser_context.res_var_name} := Mem_Res;
         ${parser_context.pos_var_name} := Mem_Pos;
         goto No_Memo;
      end if;
   % endif

   Set (${_self.gen_fn_name}_Memo,
        ${parser_context.pos_var_name} /= -1,
        ${parser_context.res_var_name},
        Pos,
        ${parser_context.pos_var_name});

   % if _self.is_left_recursive():
       <<No_Memo>>
   % endif

   Parser.Current_Pos := ${parser_context.pos_var_name};

   return ${parser_context.res_var_name};
end ${_self.gen_fn_name};
