with Ada.Containers; use Ada.Containers;
with Ada.Containers.Hashed_Maps;
with Ada.Unchecked_Deallocation;

with System;

with GNATCOLL.Traces;

with Langkit_Support.Hashes; use Langkit_Support.Hashes;
with Langkit_Support.Symbols; use Langkit_Support.Symbols;
with Langkit_Support.Text;    use Langkit_Support.Text;
with Langkit_Support.Vectors;

--  This package implements a scoped lexical environment data structure that
--  will then be used in AST nodes. Particularities:
--
--  - This data structure implements simple nesting via a Parent_Env link in
--    each env. If the parent is null you are at the topmost env.
--
--  - You can reference other envs, which are virtually treated like parent
--    envs too.
--
--  - You can annotate both whole environments and env elements with metadata,
--    giving more information about the elements. The consequence is that
--    metadata needs to be combinable, eg. you need to be able to create a
--    single metadata record from two metadata records.
--
--  TODO??? For the moment, everything is public, because it is not yet clear
--  what the interaction interface will be with the generated library. We might
--  want to make the type private at some point (or not).

generic
   type Element_T is private;
   type Element_Metadata is private;
   No_Element     : Element_T;
   Empty_Metadata : Element_Metadata;

   with function Element_Hash (Element : Element_T) return Hash_Type;
   with function Metadata_Hash (Metadata : Element_Metadata) return Hash_Type;

   with procedure Raise_Property_Error (Message : String := "");

   with function Combine (L, R : Element_Metadata) return Element_Metadata;

   with function Parent (El : Element_T) return Element_T is <>;

   with function Can_Reach (El, From : Element_T) return Boolean is <>;
   --  Function that will allow filtering nodes depending on the origin node of
   --  the request. In practice, this is used to implement sequential semantics
   --  for lexical envs, as-in, an element declared after another is not yet
   --  visible.

   with function Is_Rebindable (Element : Element_T) return Boolean is <>;
   --  Return whether a lexical environment whose node is Element can be
   --  rebound.

   with function Element_Image (El    : Element_T;
                                Short : Boolean := True) return Text_Type;

   with procedure Register_Rebinding
     (Element : Element_T; Rebinding : System.Address);
   --  Register a rebinding to be destroyed when Element is destroyed

package Langkit_Support.Lexical_Env is

   use GNATCOLL;

   Debug_Mode : constant Boolean := False;

   Me : constant Traces.Trace_Handle :=
     Traces.Create ("Lexical_Env", Traces.Off, Stream => "&2");
   --  Trace to debug lexical envs. This trace is meant to be activated on
   --  demand, when the client of lexical env wants more information about
   --  this specific lookup.

   function Has_Trace return Boolean
   is (Debug_Mode and then Traces.Active (Me));

   type Env_Rebindings_Type;
   type Env_Rebindings is access all Env_Rebindings_Type;
   --  Set of mappings from one lexical environment to another. This is used to
   --  temporarily substitute lexical environment during symbol lookup.

   --------------
   -- Entities --
   --------------

   type Entity_Info is record
      MD         : Element_Metadata;
      Rebindings : Env_Rebindings := null;
   end record
      with Convention => C;

   No_Entity_Info : constant Entity_Info := (Empty_Metadata, null);

   type Entity is record
      El   : Element_T;
      Info : Entity_Info;
   end record;
   --  Wrapper structure to contain both the 'real' env element that the user
   --  wanted to store, and its associated metadata.

   function Create (El : Element_T; MD : Element_Metadata) return Entity;
   --  Constructor that returns an Entity from an Element_T and an
   --  Element_Metadata instances.

   function Equivalent (L, R : Entity) return Boolean;
   --  Return whether we can consider that L and R are equivalent entities

   ----------------------
   -- Lexical_Env Type --
   ----------------------

   type Lexical_Env_Type;
   --  Value type for lexical envs

   type Lexical_Env_Access is access all Lexical_Env_Type;

   type Lexical_Env is record
      Env : Lexical_Env_Access;
      --  Referenced lexical environment

      Hash : Hash_Type;
      --  Env's hash. We need to pre-compute it so that the value is available
      --  even after Env is deallocated. This makes it possible to destroy a
      --  hash table that contains references to deallocated environments.

      Is_Refcounted : Boolean;
      --  Whether Env is ref-counted. When it's not, we can avoid calling
      --  Dec_Ref at destruction time: This is useful because at analysis unit
      --  destruction time, this may be a dangling access to an environment
      --  from another unit.
   end record;
   --  Reference to a lexical environments. This is the type that shall be
   --  used.

   Null_Lexical_Env : constant Lexical_Env := (null, 0, False);

   type Lexical_Env_Resolver is access
     function (Ref : Entity) return Lexical_Env;
   --  Callback type for the lazy referenced env resolution mechanism

   ----------------
   -- Env_Getter --
   ----------------

   type Env_Getter (Dynamic : Boolean := False) is record
      case Dynamic is
         when True =>
            Node     : Element_T;
            Resolver : Lexical_Env_Resolver;
         when False =>
            Env : Lexical_Env;
      end case;
   end record;
   --  Link to an environment. It can be either a simple link (just a pointer)
   --  or a dynamic link (a function that recomputes the link when needed). See
   --  tho two constructors below.

   No_Env_Getter : constant Env_Getter := (False, Null_Lexical_Env);

   function Simple_Env_Getter (E : Lexical_Env) return Env_Getter;
   --  Create a static Env_Getter (i.e. pointer to environment)

   function Dyn_Env_Getter
     (Resolver : Lexical_Env_Resolver; Node : Element_T) return Env_Getter;
   --  Create a dynamic Env_Getter (i.e. function and closure to compute an
   --  environment).

   function Get_Env (Self : Env_Getter) return Lexical_Env;
   --  Return the environment associated to the Self env getter

   function Equivalent (L, R : Env_Getter) return Boolean;
   --  If at least one of L and R is a dynamic env getter, raise a
   --  Constraint_Error. Otherwise, return whether the pointed environments are
   --  equal.

   procedure Inc_Ref (Self : Env_Getter);
   --  Shortcut to run Inc_Ref of the potentially embedded lexical environment

   procedure Dec_Ref (Self : in out Env_Getter);
   --  Shortcut to run Dec_Ref of the potentially embedded lexical environment

   --------------------
   -- Env_Rebindings --
   --------------------

   package Env_Rebindings_Vectors is new Langkit_Support.Vectors
     (Env_Rebindings);

   type Env_Rebindings_Type is record
      Parent           : Env_Rebindings;
      Old_Env, New_Env : Lexical_Env;
      Children         : Env_Rebindings_Vectors.Vector;
   end record;
   --  Tree of remappings from one lexical environment (Old_Env) to another
   --  (New_Env). Note that both referenced environments must be primary and
   --  env rebindings are supposed to be destroyed when one of their
   --  dependencies (Parent, Old_Env or New_Env) is destroyed, so there is no
   --  need for ref-counting primitives.

   function Combine (L, R : Env_Rebindings) return Env_Rebindings;
   --  Return a new Env_Rebindings that combines rebindings from both L and R

   function Append
     (Self             : Env_Rebindings;
      Old_Env, New_Env : Lexical_Env) return Env_Rebindings
      with Pre => Is_Primary (Old_Env) and then Is_Primary (New_Env);
   --  Create a new rebindings and register it to Self and to
   --  Old_Env/New_Env's analysis units.

   function Append_Rebinding
     (Self    : Env_Rebindings;
      Old_Env : Lexical_Env;
      New_Env : Lexical_Env) return Env_Rebindings
      with Pre => Is_Primary (Old_Env) and then Is_Primary (New_Env);

   function Hash is new Hashes.Hash_Access
     (Env_Rebindings_Type, Env_Rebindings);

   -------------------------------------
   -- Arrays of elements and entities --
   -------------------------------------

   package Entity_Vectors is new Langkit_Support.Vectors
     (Entity, Small_Vector_Capacity => 2);
   --  Vectors used to store collections of environment elements, as values of
   --  a lexical environment map. We want to use vectors internally.

   type Element_Array is array (Positive range <>) of Element_T;

   subtype Entity_Array is Entity_Vectors.Elements_Array;
   --  Arrays of wrapped elements stored in the environment maps

   -----------------------------
   -- Referenced environments --
   -----------------------------

   type Referenced_Env is record
      Is_Transitive : Boolean := False;
      --  Whether this reference is transitive. This changes the behavior of
      --  the Get lookup operation.

      Getter : Env_Getter;
      --  Closure to fetch the environment that is referenced

      Creator : Element_T;
      --  Node that triggered the creation of this environment reference
      --  (optional, can be null).
   end record;
   --  Represents a referenced env

   package Referenced_Envs_Vectors is new Langkit_Support.Vectors
     (Referenced_Env);
   --  Vectors of referenced envs, used to store referenced environments

   ----------------------------------------
   -- Lexical environment representation --
   ----------------------------------------

   type Entity_Resolver is access function (Ref : Entity) return Entity;
   --  Callback type for the lazy entity resolution mechanism. Such functions
   --  must take a "reference" entity (e.g. a name) and return the referenced
   --  entity.

   package Lexical_Env_Vectors is new Langkit_Support.Vectors (Lexical_Env);

   type Internal_Map_Element is record
      Element : Element_T;
      --  If Resolver is null, this is the element that lexical env lookup must
      --  return. Otherwise, it is the argument to pass to Resolver in order to
      --  get the result.

      MD : Element_Metadata;
      --  Metadata associated to Element

      Resolver : Entity_Resolver;
   end record;

   package Internal_Map_Element_Vectors is new Langkit_Support.Vectors
     (Internal_Map_Element);

   subtype Internal_Map_Element_Array is
      Internal_Map_Element_Vectors.Elements_Array;

   package Internal_Envs is new Ada.Containers.Hashed_Maps
     (Key_Type        => Symbol_Type,
      Element_Type    => Internal_Map_Element_Vectors.Vector,
      Hash            => Hash,
      Equivalent_Keys => "=",
      "="             => Internal_Map_Element_Vectors."=");

   type Internal_Map is access all Internal_Envs.Map;
   --  Internal maps of Symbols to vectors of elements

   procedure Destroy is new Ada.Unchecked_Deallocation
     (Internal_Envs.Map, Internal_Map);

   function Equivalent (L, R : Lexical_Env) return Boolean;
   --  Return whether L and R are equivalent lexical environments: same
   --  envs topology, same internal map, etc.

   function Hash (Env : Lexical_Env_Access) return Hash_Type;
   function Hash (Env : Lexical_Env) return Hash_Type is (Env.Hash);

   package Env_Rebindings_Pools is new Ada.Containers.Hashed_Maps
     (Key_Type        => Lexical_Env,
      Element_Type    => Env_Rebindings,
      Hash            => Hash,
      Equivalent_Keys => "=",
      "="             => "=");

   type Env_Rebindings_Pool is access all Env_Rebindings_Pools.Map;
   --  Pool of env rebindings to be stored in a Lexical_Env

   procedure Destroy is new Ada.Unchecked_Deallocation
     (Env_Rebindings_Pools.Map, Env_Rebindings_Pool);

   No_Refcount : constant Integer := -1;
   --  Special constant for the Ref_Count field below that means: this lexical
   --  environment is not ref-counted.

   type Lexical_Env_Type is record
      Parent : Env_Getter := No_Env_Getter;
      --  Parent environment for this env. Null by default.

      Node : Element_T;
      --  Node for which this environment was created

      Referenced_Envs : Referenced_Envs_Vectors.Vector;
      --  A list of environments referenced by this environment

      Map : Internal_Map := null;
      --  Map containing mappings from symbols to elements for this env
      --  instance. In the generated library, Elements will be AST nodes. If
      --  the lexical env is refcounted, then it does not own this env.

      Default_MD : Element_Metadata := Empty_Metadata;
      --  Default metadata for this env instance

      Rebindings : Env_Rebindings := null;

      Rebindings_Pool : Env_Rebindings_Pool := null;
      --  Cache for all parent-less env rebindings whose Old_Env is the lexical
      --  environment that owns this pool. As a consequence, this is allocated
      --  only for primary lexical environments that are rebindable.

      Ref_Count : Integer := 1;
      --  For ref-counted lexical environments, this contains the number of
      --  owners. It is initially set to 1. When it drops to 0, the env can be
      --  destroyed.
      --
      --  For envs owned by analysis units, it is always No_Refcount.
   end record;

   Empty_Env : constant Lexical_Env;
   --  Empty_Env is a magical lexical environment that will always be empty. We
   --  allow users to call Add on it anyway as a convenience, but this is a
   --  no-op. This makes sense as Empty_Env's purpose is to be used to
   --  represent missing scopes from erroneous trees.

   function Create
     (Parent        : Env_Getter;
      Node          : Element_T;
      Is_Refcounted : Boolean;
      Default_MD    : Element_Metadata := Empty_Metadata) return Lexical_Env;
   --  Constructor. Creates a new lexical env, given a parent, an internal data
   --  env, and a default metadata. If Is_Refcounted is true, the caller is the
   --  only owner of the result (ref-count is 1).

   procedure Add
     (Self     : Lexical_Env;
      Key      : Symbol_Type;
      Value    : Element_T;
      MD       : Element_Metadata := Empty_Metadata;
      Resolver : Entity_Resolver := null);
   --  Add Value to the list of values for the key Key, with the metadata MD

   procedure Remove
     (Self  : Lexical_Env;
      Key   : Symbol_Type;
      Value : Element_T);
   --  Remove Value from the list of values for the key Key

   procedure Reference
     (Self            : Lexical_Env;
      Referenced_From : Element_T;
      Resolver        : Lexical_Env_Resolver;
      Creator         : Element_T;
      Transitive      : Boolean := False);
   --  Add a dynamic reference from Self to the lexical environment computed
   --  calling Resolver on Referenced_From. This makes the content of this
   --  dynamic environment accessible when performing lookups on Self (see the
   --  Get function).
   --
   --  Unless the reference is transitive, requests with an origin point (From
   --  parameter), the content will only be visible if:
   --
   --    * Can_Reach (Referenced_From, From) is True. Practically this means
   --      that the origin point of the request needs to be *after*
   --      Referenced_From in the file.
   --    * Creator is null or is not a parent of From.
   --
   --  If Transitive, Creator must be No_Element.

   procedure Reference
     (Self         : Lexical_Env;
      To_Reference : Lexical_Env;
      Creator      : Element_T;
      Transitive   : Boolean := False);
   --  Add a static reference from Self to To_Reference. See above for the
   --  meaning of arguments.

   function Get
     (Self       : Lexical_Env;
      Key        : Symbol_Type;
      From       : Element_T := No_Element;
      Recursive  : Boolean := True;
      Rebindings : Env_Rebindings := null;
      Filter     : access
         function (Ent : Entity; Env : Lexical_Env) return Boolean := null)
      return Entity_Array;
   --  Get the array of entities for this Key. If From is given, then
   --  elements will be filtered according to the Can_Reach primitive given
   --  as parameter for the generic package.
   --
   --  If Recursive, look for Key in all Self's parents as well, and in
   --  referenced envs. Otherwise, limit the search to Self.
   --
   --  If Filter is not null, use it as a filter to disable lookup on envs for
   --  which Filter.all (From, Env) returns False.

   function Get_First
     (Self       : Lexical_Env;
      Key        : Symbol_Type;
      From       : Element_T := No_Element;
      Recursive  : Boolean := True;
      Rebindings : Env_Rebindings := null;
      Filter     : access
         function (Ent : Entity; Env : Lexical_Env) return Boolean := null)
      return Entity;
   --  Like Get, but return only the first matching entity. Return a null
   --  entity if no entity is found.

   function Orphan (Self : Lexical_Env) return Lexical_Env;
   --  Return a dynamically allocated copy of Self that has no parent

   function Get_Parent_Env (Self : Lexical_Env) return Lexical_Env;
   --  Return the parent lexical env for env Self, Empty_Env otherwise

   generic
      type Index_Type is range <>;
      type Lexical_Env_Array is array (Index_Type range <>) of Lexical_Env;
   function Group (Envs : Lexical_Env_Array) return Lexical_Env;
   --  Return a lexical environment that logically groups together multiple
   --  lexical environments. Note that this does not modify the input
   --  environments, however it returns a new owning reference.
   --
   --  If this array is empty, Empty_Env is returned. Note that if Envs'Length
   --  is greater than 1, the result is dynamically allocated.

   function Rebind_Env
      (Base_Env : Lexical_Env;
       E_Info   : Entity_Info) return Lexical_Env;
   function Rebind_Env
      (Base_Env   : Lexical_Env;
       Rebindings : Env_Rebindings) return Lexical_Env;
   --  Returns a new env based on Base_Env to include the given Rebindings

   function Image (Self : Env_Rebindings) return Text_Type;

   procedure Destroy (Self : in out Lexical_Env);
   --  Deallocate the resources allocated to the Self lexical environment. Must
   --  not be used directly for ref-counted envs.

   procedure Inc_Ref (Self : Lexical_Env);
   --  If Self is a ref-counted lexical env, increment this reference count. Do
   --  nothing otherwise.

   procedure Dec_Ref (Self : in out Lexical_Env);
   --  If Self is a ref-counted lexical env, decrement this reference count and
   --  set it to null. Also destroy it if the count drops to 0. Do nothing
   --  otherwise.

   function Shed_Rebindings
     (E_Info : Entity_Info; Env : Lexical_Env) return Entity_Info;
   --  Return a new entity info from E_Info, shedding env rebindings that are
   --  not in the parent chain for the env From_Env.

   function Is_Primary (Self : Lexical_Env) return Boolean is
     (not Self.Is_Refcounted and then Self.Env.Node /= No_Element);
   --  Return whether Self is a lexical environment that was created in an
   --  environment specification.

   function Lexical_Env_Image
     (Self           : Lexical_Env;
      Env_Id         : String := "";
      Parent_Env_Id  : String := "";
      Dump_Addresses : Boolean := False;
      Dump_Content   : Boolean := True) return String;

   function Lexical_Env_Parent_Chain (Env : Lexical_Env) return String;

   procedure Dump_One_Lexical_Env
     (Self           : Lexical_Env;
      Env_Id         : String := "";
      Parent_Env_Id  : String := "";
      Dump_Addresses : Boolean := False;
      Dump_Content   : Boolean := True);

   procedure Dump_Lexical_Env_Parent_Chain (Env : Lexical_Env);

   function Wrap (Env : Lexical_Env_Access) return Lexical_Env;

private

   Empty_Env_Map    : aliased Internal_Envs.Map := Internal_Envs.Empty_Map;
   Empty_Env_Record : aliased Lexical_Env_Type :=
     (Parent                     => No_Env_Getter,
      Node                       => No_Element,
      Referenced_Envs            => <>,
      Map                        => Empty_Env_Map'Access,
      Default_MD                 => Empty_Metadata,
      Rebindings                 => null,
      Rebindings_Pool            => null,
      Ref_Count                  => No_Refcount);

   --  Because of circular elaboration issues, we cannot call Hash here to
   --  compute the real hash. Using a dummy precomputed one is probably enough.
   Empty_Env : constant Lexical_Env := (Env  => Empty_Env_Record'Access,
                                        Hash => 0,
                                        Is_Refcounted => False);

end Langkit_Support.Lexical_Env;
