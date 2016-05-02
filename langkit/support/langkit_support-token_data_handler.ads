with Interfaces; use Interfaces;

with Langkit_Support.Slocs;   use Langkit_Support.Slocs;
with Langkit_Support.Symbols; use Langkit_Support.Symbols;
with Langkit_Support.Text;    use Langkit_Support.Text;
with Langkit_Support.Vectors;

package Langkit_Support.Token_Data_Handler is

   type Token_Raw_Data_Type is record
      Id         : Unsigned_16;

      Text       : Text_Access;
      --  Text as found in original source file or null depending on the token
      --  kind (as decided in the lexer specification). For instance: null for
      --  keywords but actual text for identifiers.

      Sloc_Range : Source_Location_Range;
   end record;

   --  Trivias are tokens that are not to be taken into account during parsing,
   --  and are marked as so in the lexer definition. Conceptually, we want
   --  to keep a (potentially empty) list of trivias for each token, which
   --  is every trivia that is between the current token and the next token.

   type Trivia_Node is record
      T        : Token_Raw_Data_Type;
      Has_Next : Boolean;
   end record;
   --  This defines a node in a trivia linked list

   package Token_Vectors is new Langkit_Support.Vectors
     (Element_Type => Token_Raw_Data_Type);
   package Text_Vectors is new Langkit_Support.Vectors
     (Element_Type => Text_Access);
   package Trivia_Vectors is new Langkit_Support.Vectors
     (Element_Type => Trivia_Node);
   package Integer_Vectors is new Langkit_Support.Vectors
     (Element_Type => Integer);

   use Token_Vectors, Text_Vectors, Trivia_Vectors, Integer_Vectors;

   type Token_Index is new Integer range -1 .. Integer'Last;
   --  Although we cannot use anything else than Natural as Token_Vectors
   --  indexes, this type will be used outside this package so that typing
   --  helps us fining index misuses.

   No_Token_Index : constant Token_Index := -1;

   type Token_Data_Handler is record
      Tokens            : Token_Vectors.Vector;
      --  Sequence of tokens in the same order as found in the source file

      Trivias           : Trivia_Vectors.Vector;
      --  Sequence of trivia in the same order as found in the source file.
      --  Trivia are stored in a way that is related to the neighbor tokens:
      --
      --  * If a token T0 at index I0 is followed by trivias T1, T2, ..., TN,
      --    then the (I0+1)'th entry in Tokens_To_Trivia will contain an index
      --    I1. T1 is then to be found in Trivia at index I1.
      --
      --    If it's the only trivia before the next token, then Has_Next is
      --    False for it, otherwise it is true and T2 is present at index I1+1.
      --    The same goes on for T2, ..., until TN, the last trivia before the
      --    next token, for which Has_Next is False.
      --
      --  * If T0 is not followed by any trivia before the next token, then
      --    the (I0+1)'th entry in Tokens_To_Trivia is No_Token_Index.

      Tokens_To_Trivias : Integer_Vectors.Vector;
      --  This is the correspondence map between regular tokens and trivias:
      --  see documentation for the Trivias field. Note that the entry at index
      --  0 stands for the leading trivia, i.e. trivia that come before the
      --  first token.

      Symbols           : Symbol_Table;
      String_Literals   : Text_Vectors.Vector;
   end record;

   type Token_Data_Handler_Access is access all Token_Data_Handler;

   procedure Initialize (TDH     : out Token_Data_Handler;
                         Symbols : Symbol_Table);

   procedure Reset (TDH : in out Token_Data_Handler);
   --  Remove all tokens and string literals from TDH. As the ownership for
   --  symbols is shared, symbols are preserved.

   function Add_String
     (TDH : in out Token_Data_Handler;
      S   : Text_Type) return Text_Access;

   function Get_Token
     (TDH   : Token_Data_Handler;
      Index : Token_Index) return Token_Raw_Data_Type
   is
     (Token_Vectors.Get (TDH.Tokens, Natural (Index)));

   function Last_Token (TDH : Token_Data_Handler) return Token_Index
   is
     (Token_Index (Token_Vectors.Last_Index (TDH.Tokens)));

   procedure Free (TDH : in out Token_Data_Handler);

   function Get_Trivias
     (TDH   : Token_Data_Handler;
      Index : Token_Index) return Token_Vectors.Elements_Array;

   function Get_Leading_Trivias
     (TDH : Token_Data_Handler) return Token_Vectors.Elements_Array;

   function Image (T : Token_Raw_Data_Type) return String is
     (if T.Text = null
      then ""
      else Image (T.Text.all));

end Langkit_Support.Token_Data_Handler;
