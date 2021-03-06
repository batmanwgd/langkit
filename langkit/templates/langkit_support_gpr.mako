## vim: ft=makoada

with "gnatcoll";
with "gnatcoll_iconv";

library project Langkit_Support is

   type Build_Mode_Type is ("dev", "prod");
   Build_Mode : Build_Mode_Type := external ("BUILD_MODE", "dev");

   type Library_Kind_Type is ("static", "relocatable", "static-pic");
   Library_Kind_Param : Library_Kind_Type := external
     ("LIBRARY_TYPE", external ("LANGKIT_SUPPORT_LIBRARY_TYPE", "static"));

   for Languages use ("Ada");
   for Library_Name use "langkit_support";
   for Library_Kind use Library_Kind_Param;
   for Library_Interface use
     ("Langkit_Support",
      "Langkit_Support.Adalog",
      "Langkit_Support.Adalog.Abstract_Relation",
      "Langkit_Support.Adalog.Debug",
      "Langkit_Support.Adalog.Eq_Same",
      "Langkit_Support.Adalog.Logic_Ref",
      "Langkit_Support.Adalog.Logic_Var",
      "Langkit_Support.Adalog.Main_Support",
      "Langkit_Support.Adalog.Operations",
      "Langkit_Support.Adalog.Predicates",
      "Langkit_Support.Adalog.Pure_Relations",
      "Langkit_Support.Adalog.Relations",
      "Langkit_Support.Adalog.Unify",
      "Langkit_Support.Adalog.Unify_Lr",
      "Langkit_Support.Adalog.Unify_One_Side",
      "Langkit_Support.Array_Utils",
      "Langkit_Support.Boxes",
      "Langkit_Support.Bump_Ptr",
      "Langkit_Support.Bump_Ptr.Vectors",
      "Langkit_Support.Cheap_Sets",
      "Langkit_Support.Diagnostics",
      "Langkit_Support.Hashes",
      "Langkit_Support.Images",
      "Langkit_Support.Iterators",
      "Langkit_Support.Lexical_Env",
      "Langkit_Support.Packrat",
      "Langkit_Support.Relative_Get",
      "Langkit_Support.Slocs",
      "Langkit_Support.Symbols",
      "Langkit_Support.Text",
      "Langkit_Support.Token_Data_Handlers",
      "Langkit_Support.Types",
      "Langkit_Support.Tree_Traversal_Iterator",
      "Langkit_Support.Vectors");

   for Source_Dirs use (${string_repr(source_dir)});
   for Library_Dir use
      "../langkit_support/" & Library_Kind_Param & "/" & Build_Mode;
   for Object_Dir use "../../obj/langkit_support/" & Build_Mode;

   Common_Ada_Cargs := ("-gnatwa", "-gnatyg", "-fPIC");

   package Compiler is
      case Build_Mode is
         when "dev" =>
            for Default_Switches ("Ada") use
               Common_Ada_Cargs & ("-g", "-O0", "-gnatwe", "-gnata");

         when "prod" =>
            --  Debug information is useful even with optimization for
            --  profiling, for instance.
            for Default_Switches ("Ada") use
               Common_Ada_Cargs & ("-g", "-Ofast");
      end case;
   end Compiler;

end Langkit_Support;
