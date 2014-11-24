


Require Import LibHypsNaming.
Require Import Errors.
(* Require Import language. *)
Require Import Cminor.
Require Ctypes.
(* Require Cshmgen. *)
(* Require Cminorgen. *)
Require Import BinPosDef.
Require Import Maps.
Require Import symboltable.
Require Import semantics.

Notation " [ ] " := nil : list_scope.
Notation " [ x ] " := (cons x nil) : list_scope.
Notation " [ x ; .. ; y ] " := (cons x .. (cons y nil) ..) : list_scope.
Notation "X ++ Y" := (String.append X Y) : spark_scope.

(** * A symbol table with concrete types only *)

(** We suppose the existence of a completely expansed symbol table.
    This table contains a mapping from variable names to basic types,
    i.e. types with no reference to any derived or subtype, only to
    the concrete type used to represent it. It is not the so called
    "base type" of Ada jargon, since for instance the base type of a
    derived type is its (immedaite) parent type. The building of this
    expanded table from the AST should be a recursive function. This
    function is not trivially structurally recursive. Krebbers seems
    to have a working trick (remove the type definition once
    traversed). *)

Import Symbol_Table_Module.
Open Scope error_monad_scope.

Open Scope Z_scope.


Lemma wordsize_ok : wordsize = Integers.Int.wordsize.
Proof.
  reflexivity.
Qed.

Lemma modulus_ok: modulus = Integers.Int.modulus.
Proof.
  reflexivity.
Qed.

Lemma half_modulus_ok: half_modulus = Integers.Int.half_modulus.
Proof.
  reflexivity.
Qed.

Lemma max_unsigned_ok: max_unsigned = Integers.Int.max_unsigned.
Proof.
  reflexivity.
Qed.

Lemma max_signed_ok: max_signed = Integers.Int.max_signed.
Proof.
  reflexivity.
Qed.

Lemma min_signed_ok: min_signed = Integers.Int.min_signed.
Proof.
  reflexivity.
Qed.


(** The [base_type] of a type is the corresponding concrete type. *)
Inductive base_type: Type :=
| BBoolean
| BInteger (rg:range)
| BArray_Type (t: base_type) (rg:range)
| BRecord_Type (t: base_type). (* + record info *)




(*
(** symbol table for unflagged program, with expanded type defs. *)
Module Symbol_Table_Elements <: SymTable_Element.
  Definition Procedure_Decl := procedure_body.
  Definition Type_Decl := base_type.
  Definition Source_Location := source_location.
End Symbol_Table_Elements.
(* TODO: have a set of function returning res type instead of option type. *)

Module Symbol_Table_Module := SymbolTableM (Symbol_Table_Elements).
Definition symboltable := Symbol_Table_Module.symboltable.
Definition mkSymbolTable := Symbol_Table_Module.mkSymbolTable.
Definition proc_decl := Symbol_Table_Module.proc_decl.
Definition type_decl := Symbol_Table_Module.type_decl.
Definition reside_symtable_vars := Symbol_Table_Module.reside_symtable_vars.
Definition reside_symtable_procs := Symbol_Table_Module.reside_symtable_procs.
Definition reside_symtable_types := Symbol_Table_Module.reside_symtable_types.
Definition reside_symtable_exps := Symbol_Table_Module.reside_symtable_exps.
Definition reside_symtable_sloc := Symbol_Table_Module.reside_symtable_sloc.
(* useless, vars are not filled in stbl. *)
Definition fetch_var := Symbol_Table_Module.fetch_var.
Definition fetch_proc := Symbol_Table_Module.fetch_proc.
Definition fetch_type := Symbol_Table_Module.fetch_type.
Definition fetch_exp_type := Symbol_Table_Module.fetch_exp_type.
Definition fetch_sloc := Symbol_Table_Module.fetch_sloc.
Definition update_vars := Symbol_Table_Module.update_vars.
Definition update_procs := Symbol_Table_Module.update_procs.
Definition update_types := Symbol_Table_Module.update_types.
Definition update_exps := Symbol_Table_Module.update_exps.
Definition update_sloc := Symbol_Table_Module.update_sloc.
*)




Definition range_of (tpnum:type): res range :=
  OK (Range 0 10) (* FIXME *).

(* We add 80 to free names for Compcert *)
Definition transl_num x := (Pos.of_nat (x+80)).

(** [reduce_type stbl ty n] returns the basic type (which is not a
    base type à la Ada) of a type. Currently this function iters on a
    arbitrary n but in fine we should remove this n.
 Idea from Krebber: remove the type defiition from stbl after fetching
 it. That way we have a decreasing argument. *)
Fixpoint reduce_type (stbl:symboltable.symboltable) (ty:type) (n:nat): res base_type :=
  match n with
    | O => Error (msg "transl_basetype: exhausted recursivity")
    | S n' =>
      match ty with
        (* currently our formalization only defines one scalar type:
       INTEGER, that we match to compcert 32 bits ints. *)
        | Integer => OK (BInteger (Range 0 Integers.Int.max_unsigned))

        (* Let us say that booleans are int32, which is probably stupid. *)
        | Boolean => OK BBoolean

        | Array_Type typnum =>
          match symboltable.fetch_type typnum stbl with
            | None => Error [ MSG "transl_basetype: no such type num :" ; CTX (transl_num typnum)]
            | Some (Array_Type_Declaration _ _ tpidx tpcell) =>
              do typofcells <- reduce_type stbl tpcell n' ;
                do rge <- range_of tpidx ;
                OK (BArray_Type typofcells rge)
            | _ => Error [ MSG "transl_basetype: not an array type :" ; CTX (transl_num typnum)]
          end
        (* TODO: array and record types *)
        | Integer_Type _ => Error (msg "transl_basetype: Integer_Type Not yet implemented!!.")
        | Subtype _ => Error (msg "transl_basetype: Subtype Not yet implemented!!.")
        | Derived_Type _ => Error (msg "transl_basetype: Derived Not yet implemented!!.")
        | Record_Type _ => Error (msg "transl_basetype: Record Not yet implemented!!.")
      end
  end.

Definition type_of_decl (typdecl:type_declaration): res type :=
  match typdecl with
    | Integer_Type_Declaration _ typnum range => OK (Integer_Type typnum)
    | Array_Type_Declaration _ typnum typidx typcell => OK (Array_Type typnum)
    | Record_Type_Declaration x x0 x1 => Error (msg "type_of_decl: Record Not yet implemented!!.")
    | Subtype_Declaration x x0 x1 x2 => Error (msg "type_of_decl: Subtype Not yet implemented!!.")
    | Derived_Type_Declaration x x0 x1 x2 => Error (msg "type_of_decl: Derived Not yet implemented!!.")
  end.


Definition max_recursivity:nat := 30%nat.

Definition fetch_var_type id st :=
  match (Symbol_Table_Module.fetch_var id st) with
    | None => Error
                [MSG "fetch_var_type: not found :"; CTX (transl_num id)]
    | Some (_,t) => OK t (* reduce_type st t max_recursivity *)
  end.

(** A stack-like compile environment. *)

Module OffsetEntry <: environment.ENTRY.
  Definition T := Z.
End OffsetEntry.

Module CompilEnv := environment.STORE OffsetEntry.
Definition compilenv := CompilEnv.stack.
Notation localframe := CompilEnv.store.
Definition frame := CompilEnv.frame.


Fixpoint transl_basetype (stbl:symboltable) (ty:base_type): res Ctypes.type :=
  match ty with
    (* currently our formalization only defines one scalar type:
       INTEGER, that we match to compcert 32 bits ints. *)
    | BInteger rge => OK (Ctypes.Tint Ctypes.I32 Ctypes.Signed Ctypes.noattr)

    (* Let us say that booleans are int32, which is probably stupid. *)
    | BBoolean => OK (Ctypes.Tint Ctypes.I32 Ctypes.Signed Ctypes.noattr)

    | BArray_Type tpcell (Range min max) =>
      do typofcells <- transl_basetype stbl tpcell ;
        OK (Ctypes.Tarray typofcells (max - min)%Z Ctypes.noattr) (* replace 0 by size of the array *)

    | _ => Error (msg "transl_basetype: Not yet implemented!!.")
  end.


Definition transl_typenum (stbl:symboltable) (id:typenum): res Ctypes.type :=
  match fetch_type id stbl with
    | None => Error (msg "transl_typenum: no such type")
    | Some t =>
      do tdecl <- type_of_decl t;
      do rt <- reduce_type stbl tdecl max_recursivity;
        transl_basetype stbl rt
  end.

Definition transl_type (stbl:symboltable) (t:type): res Ctypes.type :=
  match t with
    | Boolean => transl_basetype stbl BBoolean
    | Integer => transl_basetype stbl (BInteger (Range min_signed max_signed))
    | Subtype t' => transl_typenum stbl t'
    | Derived_Type t' => transl_typenum stbl t'
    | Integer_Type t' => transl_typenum stbl t'
    | Array_Type t' => transl_typenum stbl t'
    | Record_Type t => Error (msg "transl_type: no such type")
  end.

(** We book one identifier for the chaining argument of all functions.
    Hopefully we can reuse it everywhere. *)

Definition chaining_param := 80%positive.


Definition transl_literal (l:literal): Cminor.constant :=
  match l with
    | Integer_Literal x => Ointconst (Integers.Int.repr x)
    (** In spark, boolean are a real type, we translate it to int (0
        for false, and anything else for true). *)
    | Boolean_Literal true => Ointconst Integers.Int.one
    | Boolean_Literal false => Ointconst Integers.Int.zero
  end.

Definition make_load (addr : Cminor.expr) (ty_res : Ctypes.type) :=
match Ctypes.access_mode ty_res with
| Ctypes.By_value chunk => OK (Eload chunk addr)
| Ctypes.By_reference => OK addr
| Ctypes.By_copy => OK addr
| Ctypes.By_nothing => Error (msg "spark2compcert.make_load")
end.

Definition default_attr: Ctypes.attr := {| Ctypes.attr_volatile := false;
                                           Ctypes.attr_alignas := None |}.
Definition void_star := (Ctypes.Tpointer Ctypes.Tvoid default_attr).


(** [build_loads_ m] returns the expression denoting the mth
    indirection of the variable of offset Zero (i.e. the pointer to
    enclosing procedure). This is the way we access to enclosing
    procedure frame. The type of all Load is ( void * ). *)
Fixpoint build_loads_ (m:nat) {struct m} : res Cminor.expr :=
  match m with
    | O => OK (Econst (Oaddrstack (Integers.Int.zero)))
    | S m' =>
      do subloads <- build_loads_ m' ;
        make_load subloads void_star
  end.

(** [build_loads m n] is the expression denoting the address
    of the variable at offset [n] in the enclosing frame [m] levels
    above the current frame. This is done by following pointers from
    frames to frames. (Load (Load ...)). *)
Definition build_loads (m:nat) (n:Z) :=
  do indirections <- build_loads_ m ;
  OK (Ebinop Oadd indirections (Econst (Ointconst (Integers.Int.repr n)))).



Definition error_msg_with_loc stbl astnum (nme:nat) :=
  match fetch_sloc astnum stbl with
      Some loc => [CTX (Pos.of_nat nme) ; MSG " at line: " ;
                   CTX (Pos.of_nat (loc.(line))) ;
                   MSG " and column: " ; CTX (Pos.of_nat (loc.(col)))]
    | None => [CTX (Pos.of_nat nme) ; MSG "no location found" ]
  end.

(** [transl_variable stbl CE astnum nme] returns the expression that would
    evaluate to the *address* of variable [nme]. The compiler
    environment [CE] allows to 1) know the nesting level of the
    current procedure, 2) the nesting level of the procedure defining
    [nme]. From these two numbers we generate the right number of
    Loads to access the frame of [nme]. [astnum] is there for error
    message only.*)
Definition transl_variable (stbl:symboltable) (CE:compilenv) astnum (nme:idnum) : res Cminor.expr :=
  match (CompilEnv.fetchG nme CE) with
    | None =>  Error (MSG "transl_variable: no such idnum." :: error_msg_with_loc stbl astnum nme)
    | Some n =>
      match (CompilEnv.frameG nme CE) with
        | None =>  Error (msg "assert false.")
        | Some (m,_) =>
          match CompilEnv.level_of_top CE with
            | None =>  Error (msg "no frame on compile env. assert false.")
            | Some m' =>
              build_loads (m' - m) n (* get the adress of the variable *)
          end
      end
  end.


Definition transl_binop (op:binary_operator): binary_operation :=
  match op with
    | And => Cminor.Oand
    | Or => Cminor.Oor
    | Plus => Cminor.Oadd
    | Minus => Cminor.Osub
    | Multiply => Cminor.Omul
    | Divide => Cminor.Odiv (* divu? *)
    | Equal => Cminor.Ocmp Integers.Ceq
    | Not_Equal => Cminor.Ocmp Integers.Cne
    | Less_Than => Cminor.Ocmp Integers.Clt
    | Less_Than_Or_Equal => Cminor.Ocmp Integers.Cle
    | Greater_Than => Cminor.Ocmp Integers.Cgt
    | Greater_Than_Or_Equal => Cminor.Ocmp Integers.Cge
  end.

Definition transl_unop (op:unary_operator) : res Cminor.unary_operation :=
  match op with
    | Unary_Plus => Error (msg "unary plus should be removed")
    | Unary_Minus => OK Cminor.Onegint
    | Not => OK Cminor.Onotint
  end.

(** [value_at_addr stbl typ addr] returns the expression corresponding
    to the content of the address denoted by the expression [addr].
    [typ] should be the (none translated) expected type of the content. *)
Definition value_at_addr stbl typ addr  :=
  do ttyp <- transl_type stbl typ ;
  make_load addr ttyp.

(* This Fixpoint can be replaced by a Function if:
 1) in trunk (v8.5 when ready)
 2) we replace the notation for "do" expanding the def of bind.
Notation "'do' X <- A ; B" :=
 (match A with | OK x => ((fun X => B) x) | Error msg => Error msg end)
 (at level 200, X ident, A at level 100, B at level 200) : error_monad_scope. *)


(** [transl_expr stbl CE e] returns the code that evaluates to the
    value of expression [e]. *)
Fixpoint transl_expr (stbl:symboltable) (CE:compilenv) (e:expression): res Cminor.expr :=
  match e with
    | E_Literal _ lit => OK (Econst (transl_literal lit))
    | E_Name astnum (E_Identifier _ id) =>
      do addrid <- transl_variable stbl CE astnum id ; (* get the address of the variable *)
        (* get type from stbl or from actual value? *)
        do typ <- fetch_var_type id stbl ;
        value_at_addr stbl typ addrid
(*        match fetch_exp_type astnum stbl with (* get type from stbl or from actual value? *)
          | None => Error ([MSG "transl_expr: no such variable " ; CTX (Pos.of_nat id)])
          | Some (typ) => value_at_addr stbl typ addrid
        end *)

    | E_Name _ (E_Selected_Component _ _ _) => Error (msg "transl_expr: record not yet implemented")
    | E_Binary_Operation _ op e1 e2 =>
      do te1 <- transl_expr stbl CE e1;
        do te2 <- transl_expr stbl CE e2;
        OK (Ebinop (transl_binop op) te1 te2)
    | E_Unary_Operation _ op e =>
      do te <- transl_expr stbl CE e;
        do top <- transl_unop op;
        OK (Eunop top te)
    | E_Name astnum (E_Indexed_Component _ id e) => (* deref? *)
      Error (msg "transl_expr: Array not yet implemented")
(*      do tid <- (transl_variable stbl CE astnum id);
(*         match fetch_var id stbl with *)
        match fetch_exp_type astnum stbl with
          (* typid = type of the array (in spark) *)
          | Some (language_basics.Array_Type typid) =>
            match fetch_type typid stbl with
              | None => Error (msg "transl_expr: no such type")
              | Some (BArray_Type ty (Range min max)) =>
                (** [id[e]] becomes  [Eload (<id>+(<e>-rangemin(id))*sizeof(<ty>))] *)
                do tty <- transl_basetype stbl ty ;
                  do cellsize <- OK (Econst (Ointconst (Integers.Int.repr (Ctypes.sizeof tty))));
                  do te <- transl_expr stbl CE e ;
                  do offs <- OK(Ebinop Cminor.Osub te (Econst (Ointconst (Integers.Int.repr min)))) ;
                  make_load
                    (Ebinop Cminor.Oadd tid (Ebinop Cminor.Omul offs cellsize)) tty
              | _ => Error (msg "transl_expr: is this really an array type?")
            end
          | _ => Error (msg "transl_expr: ")
        end*)
  end.

(** [transl_name stbl CE nme] returns the code that evaluates to the
    *address* where the value of name [nme] is stored. *)
Fixpoint transl_name (stbl:symboltable) (CE:compilenv) (nme:name): res Cminor.expr :=
  match nme with
    | E_Identifier astnum id => (transl_variable stbl CE astnum id) (* address of the variable *)
    | E_Indexed_Component  astnum id e =>
      Error (msg "transl_name: array not yet implemented")
    (*      do tid <- transl_variable stbl CE astnum id; (* address of the variable *)
(*         match fetch_var id stbl with *)
        match fetch_exp_type astnum stbl with
          (* typid = type of the array (in spark) *)
          | Some (language_basics.Array_Type typid) =>
            match fetch_type typid stbl with
              | None => Error (msg "transl_name: no such type")
              | Some (BArray_Type ty (Range min max)) =>
                (** [id[e]] becomes  [Eload (<id>+(<e>-rangemin(id))*sizeof(<ty>))] *)
                do tty <- transl_basetype stbl ty ;
                  do cellsize <- OK (Econst (Ointconst (Integers.Int.repr (Ctypes.sizeof tty))));
                  do te <- transl_expr stbl CE e ;
                  do offs <- OK(Ebinop Cminor.Osub te (Econst (Ointconst (Integers.Int.repr min)))) ;
                  OK (Ebinop Cminor.Oadd tid (Ebinop Cminor.Omul offs cellsize))
            | _ => Error (msg "transl_name: is this really an array type?")
          end
        | _ => Error (msg "transl_name: ")
      end*)
    | E_Selected_Component  _ _ _ =>  Error (msg "transl_name:Not yet implemented")
  end.

Fixpoint transl_exprlist (stbl: symboltable) (CE: compilenv) (el: list expression)
                     {struct el}: res (list Cminor.expr) :=
  match el with
  | nil => OK nil
  | e1 :: e2 =>
      do te1 <- transl_expr stbl CE e1;
      do te2 <- transl_exprlist stbl CE e2;
      OK (te1 :: te2)
  end.


(* ********************************************** *)


(* 
Definition concrete_type_of_basic_value (v:basic_value): type :=
  match v with
    | Int n => Integer
    | Bool b => Boolean
  end.
 *)

Definition concrete_type_of_value (v:value): res base_type :=
  match v with
    | Int v => OK (BInteger (Range min_signed max_signed))
    | Bool b => OK BBoolean
    | ArrayV v =>  Error (msg "concrete_type_of_value: Arrays types not yet implemented!!.")
    | RecordV v =>  Error (msg "concrete_type_of_value: Records types not yet implemented!!.")
    | Undefined => Error (msg "concrete_type_of_value: Undefined type not yet implemented!!.")
  end.


Function transl_value (v:value): res Values.val :=
  match v with
    | Int v => OK (Values.Vint (Integers.Int.repr v))
    | Bool true => OK (Values.Vint (Integers.Int.repr 1))
    | Bool false => OK (Values.Vint (Integers.Int.repr 0))
    | ArrayV v =>  Error (msg "concrete_type_of_value: Arrays types not yet implemented!!.")
    | RecordV v =>  Error (msg "concrete_type_of_value: Records types not yet implemented!!.")
    | Undefined => Error (msg "concrete_type_of_value: Undefined type not yet implemented!!.")
  end.

(* See CminorgenProof.v@205. *)
Record match_env (st:symboltable) (s: semantics.STACK.stack) (CE:compilenv) (sp:Values.val)
       (locenv: Cminor.env): Prop :=
  mk_match_env {
      (* We will need more than that probably. But for now let us use
         a simple notion of matching: the value of a variable is equal
         to the value of its translation. Its translation is currently
         (an expression of the form ELoad((Eload(Eload ...(Eload(0))))
         + n)). We could define a specialization of eval_expr for this
           kind of expression but at some point the form of the
           expression will complexify (some variables may stay
           temporary instead of going in the stack, etc).

         We also put well-typing constraints on the stack wrt symbol
         table.
       *)
      me_vars:
        forall id st astnum v typeofv,
            STACK.fetchG id s = Some v ->
            fetch_var_type id st = OK typeofv ->
            exists e' v' rtypeofv typeofv' ld,
              reduce_type st typeofv max_recursivity = OK rtypeofv /\
              concrete_type_of_value v = OK rtypeofv /\ (* stack is well typed wrt st *)
              transl_value v = OK v' /\
              transl_type st typeofv = OK typeofv' /\
              transl_variable st CE astnum id = OK e' /\
              make_load e' typeofv' = OK ld /\
              forall (g:genv)(m:Memory.Mem.mem),
                Cminor.eval_expr g sp locenv m ld v';
      
      me_overflow:
        forall id n,
          STACK.fetchG id s = Some (Int n) ->
          do_overflow_check n (Normal (Int n))

(*       me_vars:
        forall id st astnum typeofv,
          fetch_var_type id st = OK typeofv ->
          exists (v:STACK.V) e' v' typeofv' ld,
            STACK.fetchG id s = Some v ->
            transl_variable st CE astnum id = OK e' ->
            transl_type st typeofv = OK typeofv' /\
            transl_value v = OK v' /\
            make_load e' typeofv' = OK ld /\
            forall (g:genv)(m:Memory.Mem.mem),
              Cminor.eval_expr g sp locenv m ld v'
 *)
    }.

(** Hypothesis renaming stuff *)
Ltac rename_hyp1 th :=
  match th with
    | eval_expr _ _ _ (Normal _) => fresh "h_eval_expr"
    | eval_expr _ _ _ (Run_Time_Error _) => fresh "h_eval_expr_RE"
    | eval_name _ _ _ (Normal _) => fresh "h_eval_name"
    | eval_name _ _ _ (Run_Time_Error _) => fresh "h_eval_name_RE"
    | eval_name _ _ _ _ => fresh "h_eval_name"
    | do_overflow_check _ (Run_Time_Error _) => fresh "h_overf_check_RE"
    | do_overflow_check _ _ => fresh "h_overf_check"
    | do_range_check _ _ _ (Run_Time_Error _) => fresh "h_do_range_check_RE"
    | do_range_check _ _ _ _ => fresh "h_do_range_check"
    | do_run_time_check_on_binop _ _ _ (Run_Time_Error _) => fresh "h_do_rtc_binop_RTE"
    | do_run_time_check_on_binop _ _ _ _ => fresh "h_do_rtc_binop"
    | Cminor.eval_constant _ _ _ = (Some _)  => fresh "h_eval_constant"
    | Cminor.eval_constant _ _ _ = None  => fresh "h_eval_constant_None"
    | eval_literal _ (Normal _)  => fresh "h_eval_literal"
    | eval_literal _ (Run_Time_Error _)  => fresh "h_eval_literal_RE"
    | eval_literal _ _  => fresh "h_eval_literal"
    | Cminor.eval_expr _ _ _ _ _ _ => fresh "h_CM_eval_expr"
    | match_env _ _ _ _ _ => fresh "h_match_env"
    | transl_value _ = OK _ => fresh "heq_transl_value"
    | transl_value _ = Run_Time_Error _ => fresh "heq_transl_value_RE"
    | transl_variable _ _ _ _ = OK _ => fresh "heq_transl_variable"
    | transl_variable _ _ _ _ = Run_Time_Error _ => fresh "heq_transl_variable_RE"
    | fetch_exp_type _ _ = Some _ => fresh "heq_fetch_exp_type"
    | fetch_exp_type _ _ = None => fresh "heq_fetch_exp_type_none"
    | transl_type _ _ = OK _ => fresh "heq_transl_type"
    | transl_type _ _ = Run_Time_Error _ => fresh "heq_transl_type_RE"
    | make_load _ _ = OK _ => fresh "heq_make_load"
    | make_load _ _ = Run_Time_Error _ => fresh "heq_make_load_RE"
    | STACK.fetchG _ _ = Some _ => fresh "heq_SfetchG"
    | STACK.fetchG _ _ = None => fresh "heq_SfetchG_none"
    | do_run_time_check_on_binop _ _ _ (Run_Time_Error _) =>  fresh "h_do_rtc_binop_RE"
    | do_run_time_check_on_binop _ _ _ _ =>  fresh "h_do_rtc_binop"
    | do_run_time_check_on_unop _ _ (Run_Time_Error _) =>  fresh "h_do_rtc_unop_RE"
    | do_run_time_check_on_unop _ _ _ =>  fresh "h_do_rtc_unop"
    | reduce_type _ _ _ = OK _  => fresh "heq_reduce_type"
    | reduce_type _ _ _ = Run_Time_Error _ => fresh "heq_reduce_type_RE"
    | reduce_type _ _ _ = _  => fresh "heq_reduce_type"
    | concrete_type_of_value _ = Run_Time_Error _ => fresh "concrete_type_of_value_RE"
    | concrete_type_of_value _ = OK _ => fresh "concrete_type_of_value"
    | in_bound _ _ _ => fresh "h_inbound"
    | do_division_check _ _ _ => fresh "h_do_division_check"
    | do_division_check _ _ (Run_Time_Error _) => fresh "h_do_division_check_RTE"
  end.

Ltac rename_hyp ::= rename_hyp1.

Lemma transl_literal_ok :
  forall g (l:literal) v,
    eval_literal l (Normal v) ->
    forall sp,
    exists v',
      transl_value v = OK v'
      /\ eval_constant g sp (transl_literal l) = Some v'.
Proof.
  !intros.
  !destruct l;simpl in *.
  - !inversion h_eval_literal.
    !inversion h_overf_check.
    simpl.
    eauto.
  - destruct b.
    + !inversion h_eval_literal.
      simpl.
      eauto.
    + !inversion h_eval_literal.
      simpl.
      eauto.
Qed.


Ltac eq_same e :=
  match goal with
    | H: e = OK ?t1 , H': e = OK ?t2 |- _ => rewrite H in H'; !inversion H'
  end;
  match goal with
      | H: ?e = ?e |- _ => clear H
  end.

(* Transform hypothesis of the form do_range_check into disequalities. *)
Ltac inv_rtc :=
  repeat
    progress
    try match goal with
          | H:do_range_check _ _ _ (Normal (Int _)) |- _ => !invclear H
          | H: in_bound _ _ true |- _ => !invclear H
          | H:(_ >=? _) && (_ >=? _) = true |- _ =>
            rewrite andb_true_iff in H;
              try rewrite Z.geb_le in H;
              try rewrite Z.geb_le in H;
              let h1 := fresh "h_le"in
              let h2 := fresh "h_le"in
              destruct H as [h1 h2 ]
          | H:(_ <=? _) && (_ <=? _) = true |- _ =>
            rewrite andb_true_iff in H;
              try rewrite Z.leb_le in H;
              try rewrite Z.leb_le in H;
              let h1 := fresh "h_le"in
              let h2 := fresh "h_le"in
              destruct H as [h1 h2 ]
        end.


(** In this section we prove that basic operators of SPARK behave,
    when they don't raise a runtime error, like Compcert ones. *)

(* TODO: maybe we should use do_overflow_check here, we will see. *)
Lemma add_ok :
  forall n n0 v v1 v2,
    do_range_check v1 min_signed max_signed (Normal (Int v1)) ->
    do_range_check v2 min_signed max_signed (Normal (Int v2)) ->
    do_run_time_check_on_binop Plus (Int v1) (Int v2) (Normal (Int v)) ->
    transl_value (Int v1) = OK (Values.Vint n) ->
    transl_value (Int v2) = OK (Values.Vint n0) ->
    Math.binary_operation Plus (Int v1) (Int v2) = Some (Int v) ->
    Values.Val.add (Values.Vint n) (Values.Vint n0) = Values.Vint (Integers.Int.repr v).
Proof.
  !intros.
  simpl in *.
  !invclear heq_transl_value.
  !invclear heq_transl_value0.
  !invclear heq.
  apply f_equal.
  !invclear h_do_rtc_binop;simpl in *; try match goal with H: Plus <> Plus |- _ => elim H;auto end.
  clear H heq.
  inv_rtc.
  rewrite min_signed_ok, max_signed_ok in *.
  rewrite Integers.Int.add_signed.
  rewrite !Integers.Int.signed_repr;auto 2.
Qed.

Lemma sub_ok :
  forall n n0 v v1 v2,
    do_range_check v1 min_signed max_signed (Normal (Int v1)) ->
    do_range_check v2 min_signed max_signed (Normal (Int v2)) ->
    do_run_time_check_on_binop Minus (Int v1) (Int v2) (Normal (Int v)) ->
    transl_value (Int v1) = OK (Values.Vint n) ->
    transl_value (Int v2) = OK (Values.Vint n0) ->
    Math.binary_operation Minus (Int v1) (Int v2) = Some (Int v) ->
    Values.Val.sub (Values.Vint n) (Values.Vint n0) = Values.Vint (Integers.Int.repr v).
Proof.
  !intros.
  simpl in *.
  !invclear heq_transl_value.
  !invclear heq_transl_value0.
  !invclear heq.
  apply f_equal.
  !invclear h_do_rtc_binop;simpl in *; try match goal with H: ?A <> ?A |- _ => elim H;auto end.
  clear H heq.
  inv_rtc.
  rewrite min_signed_ok, max_signed_ok in *.
  rewrite Integers.Int.sub_signed.
  rewrite !Integers.Int.signed_repr;auto 2.
Qed.

Lemma mult_ok :
  forall n n0 v v1 v2,
    do_range_check v1 min_signed max_signed (Normal (Int v1)) ->
    do_range_check v2 min_signed max_signed (Normal (Int v2)) ->
    do_run_time_check_on_binop Multiply (Int v1) (Int v2) (Normal (Int v)) ->
    transl_value (Int v1) = OK (Values.Vint n) ->
    transl_value (Int v2) = OK (Values.Vint n0) ->
    Math.binary_operation Multiply (Int v1) (Int v2) = Some (Int v) ->
    Values.Val.mul (Values.Vint n) (Values.Vint n0) = Values.Vint (Integers.Int.repr v).
Proof.
  !intros.
  simpl in *.
  !invclear heq_transl_value.
  !invclear heq_transl_value0.
  !invclear heq.
  apply f_equal.
  !invclear h_do_rtc_binop;simpl in *; try match goal with H: ?A <> ?A |- _ => elim H;auto end.
  clear H heq.
  inv_rtc.
  rewrite min_signed_ok, max_signed_ok in *.
  rewrite Integers.Int.mul_signed.
  rewrite !Integers.Int.signed_repr;auto 2.
Qed.

Set Printing Width 80.

(** Compcert division return None if dividend is min_int and divisor
    in -1, because the result would be max_int +1. In Spark's
    semantics the division is performed but then it fails overflow
    checks. *)
(*  How to compile this? probably by performing a check before. *)
Lemma div_ok :
  forall n n0 v v1 v2,
    do_range_check v1 min_signed max_signed (Normal (Int v1)) ->
    do_range_check v2 min_signed max_signed (Normal (Int v2)) ->
    do_run_time_check_on_binop Divide (Int v1) (Int v2) (Normal (Int v)) ->
    transl_value (Int v1) = OK (Values.Vint n) ->
    transl_value (Int v2) = OK (Values.Vint n0) ->
    Math.binary_operation Divide (Int v1) (Int v2) = Some (Int v) ->
    Values.Val.divs (Values.Vint n) (Values.Vint n0) = Some (Values.Vint (Integers.Int.repr v)).
Proof.
  !intros.
  simpl in *.
  !invclear heq_transl_value.
  !invclear heq_transl_value0.
  !invclear heq.
  !invclear h_do_rtc_binop;simpl in *; try match goal with H: ?A <> ?A |- _ => elim H;auto end.
  { decompose [or] H;discriminate. }
  inv_rtc.
  rewrite min_signed_ok, max_signed_ok in *.
  !inversion h_do_division_check.
  apply Zeq_bool_neq in heq_Z_false.
  rewrite Integers.Int.eq_false;auto.
  - simpl.
    (* the case where division overflows is dealt with by the overflow
       check in spark semantic. Ths division is performed on Z and
       then overflow is checked and may fails. *)
    destruct (Integers.Int.eq (Integers.Int.repr v1)
                              (Integers.Int.repr Integers.Int.min_signed) &&
                              Integers.Int.eq (Integers.Int.repr v2) Integers.Int.mone)
             eqn:h_divoverf.
    + apply andb_true_iff in h_divoverf.
      destruct h_divoverf as [h_divoverf1 h_divoverf2].
      exfalso.
      assert (v1_is_min_int: v1 = Integers.Int.min_signed).
      { 
        rewrite Integers.Int.eq_signed in h_divoverf1.
        unfold Coqlib.zeq in h_divoverf1;auto.
        rewrite !Integers.Int.signed_repr in h_divoverf1;try (split;omega).
        destruct (Z.eq_dec v1 Integers.Int.min_signed);try discriminate.
        assumption. }
      assert (v2_is_min_int: v2 = -1).
      { rewrite Integers.Int.eq_signed in h_divoverf2.
        unfold Coqlib.zeq in h_divoverf2;auto.
        rewrite !Integers.Int.signed_repr in h_divoverf2;try (split;omega).
        destruct (Z.eq_dec v2 (Integers.Int.signed Integers.Int.mone));try discriminate.
        assumption. }
      subst.
      change (Zneg xH) with  (Z.opp (Zpos xH)) in h_overf_check.
      rewrite Zquot.Zquot_opp_r in h_overf_check.
      rewrite Z.quot_1_r in h_overf_check.
      !inversion h_overf_check.
      inv_rtc.
      cbv in h_le4.
      auto.
    + unfold Integers.Int.divs.
      rewrite !Integers.Int.signed_repr;auto 2.

  - unfold Integers.Int.zero.
    intro abs.
    apply heq_Z_false.
    rewrite <- (Integers.Int.signed_repr v2).
    + rewrite abs.
      rewrite (Integers.Int.signed_repr 0);auto.
      split; intro;discriminate.      
    + split;auto.
Qed.




(* *** Hack to workaround a current limitation of Functional Scheme wrt to Function. *)
(*
This should work, but Funcitonal SCheme does not generate the
inversion stuff currently. So we defined by hand the expanded versions
binopexp and unopexp with Function.

Definition binopexp :=
  Eval unfold
       Math.binary_operation
  , Math.and
  , Math.or
  , Math.eq
  , Math.ne
  , Math.lt
  , Math.le
  , Math.gt
  , Math.ge
  , Math.add
  , Math.sub
  , Math.mul
  , Math.div
  in Math.binary_operation.

Definition unopexp :=
  Eval unfold
       Math.unary_operation, Math.unary_plus, Math.unary_minus, Math.unary_not in Math.unary_operation.

Functional Scheme binopnind := Induction for binopexp Sort Prop.
Functional Scheme unopnind := Induction for unopexp Sort Prop.
*)

Function unopexp (op : unary_operator) (v : value) :=
  match op with
    | Unary_Plus =>
      match v with
        | Undefined => None
        | Int _ => Some v
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Unary_Minus =>
      match v with
        | Undefined => None
        | Int v' => Some (Int (- v'))
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Not =>
      match v with
        | Undefined => None
        | Int _ => None
        | Bool v' => Some (Bool (negb v'))
        | ArrayV _ => None
        | RecordV _ => None
      end
  end.

Function binopexp (op : binary_operator) (v1 v2 : value) :=
  match op with
    | And =>
      match v1 with
        | Undefined => None
        | Int _ => None
        | Bool v1' =>
          match v2 with
            | Undefined => None
            | Int _ => None
            | Bool v2' => Some (Bool (v1' && v2'))
            | ArrayV _ => None
            | RecordV _ => None
          end
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Or =>
      match v1 with
        | Undefined => None
        | Int _ => None
        | Bool v1' =>
          match v2 with
            | Undefined => None
            | Int _ => None
            | Bool v2' => Some (Bool (v1' || v2'))
            | ArrayV _ => None
            | RecordV _ => None
          end
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Equal =>
      match v1 with
        | Undefined => None
        | Int v1' =>
          match v2 with
            | Undefined => None
            | Int v2' => Some (Bool (Zeq_bool v1' v2'))
            | Bool _ => None
            | ArrayV _ => None
            | RecordV _ => None
          end
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Not_Equal =>
      match v1 with
        | Undefined => None
        | Int v1' =>
          match v2 with
            | Undefined => None
            | Int v2' => Some (Bool (Zneq_bool v1' v2'))
            | Bool _ => None
            | ArrayV _ => None
            | RecordV _ => None
          end
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Less_Than =>
      match v1 with
        | Undefined => None
        | Int v1' =>
          match v2 with
            | Undefined => None
            | Int v2' => Some (Bool (v1' <? v2'))
            | Bool _ => None
            | ArrayV _ => None
            | RecordV _ => None
          end
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Less_Than_Or_Equal =>
      match v1 with
        | Undefined => None
        | Int v1' =>
          match v2 with
            | Undefined => None
            | Int v2' => Some (Bool (v1' <=? v2'))
            | Bool _ => None
            | ArrayV _ => None
            | RecordV _ => None
          end
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Greater_Than =>
      match v1 with
        | Undefined => None
        | Int v1' =>
          match v2 with
            | Undefined => None
            | Int v2' => Some (Bool (v1' >? v2'))
            | Bool _ => None
            | ArrayV _ => None
            | RecordV _ => None
          end
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Greater_Than_Or_Equal =>
      match v1 with
        | Undefined => None
        | Int v1' =>
          match v2 with
            | Undefined => None
            | Int v2' => Some (Bool (v1' >=? v2'))
            | Bool _ => None
            | ArrayV _ => None
            | RecordV _ => None
          end
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Plus =>
      match v1 with
        | Undefined => None
        | Int v1' =>
          match v2 with
            | Undefined => None
            | Int v2' => Some (Int (v1' + v2'))
            | Bool _ => None
            | ArrayV _ => None
            | RecordV _ => None
          end
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Minus =>
      match v1 with
        | Undefined => None
        | Int v1' =>
          match v2 with
            | Undefined => None
            | Int v2' => Some (Int (v1' - v2'))
            | Bool _ => None
            | ArrayV _ => None
            | RecordV _ => None
          end
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Multiply =>
      match v1 with
        | Undefined => None
        | Int v1' =>
          match v2 with
            | Undefined => None
            | Int v2' => Some (Int (v1' * v2'))
            | Bool _ => None
            | ArrayV _ => None
            | RecordV _ => None
          end
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
    | Divide =>
      match v1 with
        | Undefined => None
        | Int v1' =>
          match v2 with
            | Undefined => None
            | Int v2' => Some (Int (v1' ÷ v2'))
            | Bool _ => None
            | ArrayV _ => None
            | RecordV _ => None
          end
        | Bool _ => None
        | ArrayV _ => None
        | RecordV _ => None
      end
  end.

Lemma binopexp_ok: forall x y z, Math.binary_operation x y z = binopexp x y z .
Proof.
  reflexivity.
Qed.

Lemma unopexp_ok: forall x y, Math.unary_operation x y = unopexp x y.
Proof.
  reflexivity.
Qed.

(* *** And of the hack *)

(** [safe_stack s] means that every value in s correct wrt to
    overflows.
TODO: extend with other values than Int: floats, arrays, records. *)
Definition safe_stack s :=
  forall id n,
    STACK.fetchG id s = Some (Int n)
    -> do_overflow_check n (Normal (Int n)).

(** Since unary_plus is a nop, it is an exception to the otherwise
    general property that the spark semantics always returns a checked
    value (or a runtime error). *)
Definition is_not_unaryplus e :=
  match e with
    | E_Unary_Operation x x0 x1 =>
      match x0 with
        | Unary_Plus => False
        | _ => True
      end
    | _ => True
  end.

(** Hypothesis renaming stuff *)
Ltac rename_hyp2 th :=
  match th with
    | is_not_unaryplus _ => fresh "h_isnotunplus"
    | safe_stack _ => fresh "h_safe_stack"
    | _ => rename_hyp1 th
  end.

Ltac rename_hyp ::= rename_hyp2.

Lemma eval_literal_overf :
  forall (l:literal) n, 
    eval_literal l (Normal (Int n)) ->
    do_overflow_check n (Normal (Int n)).
Proof.
  !intros.
  !inversion h_eval_literal.
  !inversion h_overf_check.
  assumption.
Qed.


Lemma eval_name_overf : forall s st nme n,
                          safe_stack s
                          -> eval_name st s nme (Normal (Int n))
                          -> do_overflow_check n (Normal (Int n)).
Proof.
  !intros.
  !inversion h_eval_name. (* l'environnement retourne toujours des valeur rangées. *)
  - unfold safe_stack in *.
    eapply h_safe_stack;eauto.
  - admit. (* Arrays *)
  - admit. (* records *)
Qed.

(** on a safe stack, any expression that evaluates into a value,
    evaluates to a not overflowing value, except if it is a unary_plus
    (in which case no check is made). *)
Lemma eval_expr_overf :
  forall st s, safe_stack s ->
            forall (e:expression) n, 
              is_not_unaryplus e -> 
              eval_expr st s e (Normal (Int n)) ->
              do_overflow_check n (Normal (Int n)).
Proof.
  !intros.
  !inversion h_eval_expr;subst.
  - eapply eval_literal_overf;eauto.
  - eapply eval_name_overf;eauto.
  - !invclear h_do_rtc_binop.
    + inversion h_overf_check;subst;auto.
    + inversion h_overf_check;subst;auto.
    + rewrite binopexp_ok in *.
      functional inversion heq;subst;try match goal with H: ?A <> ?A |- _ => elim H;auto end.
  - !invclear h_do_rtc_unop.
    + inversion h_overf_check;subst;auto.
    + rewrite unopexp_ok in *.
      !functional inversion heq;subst;try match goal with H: ?A <> ?A |- _ => elim H;auto end.
      simpl in h_isnotunplus.
      elim h_isnotunplus.
Qed.




Lemma transl_expr_ok :
  forall stbl CE locenv g m (s:STACK.stack) (e:expression) (v:value) (e':Cminor.expr)
         (sp: Values.val),
    eval_expr stbl s e (Normal v) ->
    transl_expr stbl CE e = OK e' ->
    match_env stbl s CE sp locenv ->
    exists v',
      transl_value v = OK v'
      /\ Cminor.eval_expr g sp locenv m e' v'
      /\ match v with
           | (Int n) => do_overflow_check n (Normal (Int n))
           | _ => True
         end.
Proof.
  intros until sp.
  intro h_eval_expr.
  remember (Normal v) as Nv.
  revert HeqNv.
  revert v e' sp.
  !induction h_eval_expr;simpl;!intros; subst.
  - !invclear heq.
    !destruct h_match_env.
    destruct (transl_literal_ok g l v0 h_eval_literal sp) as [v' h_and].
    !destruct h_and.
    exists v'.
    repeat split.
    + assumption.
    + constructor.
      assumption.
    + destruct v0;auto.
      eapply eval_literal_overf;eauto.
  - !destruct n; try now inversion heq.
     destruct (transl_variable st CE ast_num i) eqn:heq_trv;simpl in *
     ; (try now inversion heq); rename e into trv_i.
     destruct (fetch_var_type i st) eqn:heq_fetch_type; (try now inversion heq);simpl in heq.
    unfold value_at_addr in heq.
    destruct (transl_type st t) eqn:heq_typ;simpl in *;try now inversion heq.
    !invclear h_eval_name.
    destruct h_match_env.
    specialize (me_vars0 i st ast_num v0 t heq_SfetchG heq_fetch_type).
    decomp me_vars0.
    rename x into e''. rename x0 into v1'. rename x1 into bastyp.
    rename x2 into t'. rename x3 into e'''. rename H6 into h_eval_expr. clear me_vars0.
    unfold make_load in heq.
    destruct (Ctypes.access_mode t0) eqn:heq_acctyp; !invclear heq.
    + exists v1'.
      repeat split.
      * assumption.
      * unfold make_load in heq_make_load.
        eq_same (transl_type st t).
        eq_same( transl_variable st CE ast_num i).
        rewrite heq_acctyp in heq_make_load.
        !invclear heq_make_load.
        apply h_eval_expr.
      * destruct v0;auto.
        eapply me_overflow0.
        eauto.
    + exists v1'.
      repeat split.
      * assumption.
      * unfold make_load in heq_make_load.
        eq_same (transl_type st t).
        eq_same( transl_variable st CE ast_num i).
        rewrite heq_acctyp in heq_make_load.
        !invclear heq_make_load.
        apply h_eval_expr.
      * destruct v0;auto.
        eapply me_overflow0.
        eauto.
    + exists v1'.
      repeat split.
      * assumption.
      * unfold make_load in heq_make_load.
        eq_same (transl_type st t).
        eq_same( transl_variable st CE ast_num i).
        rewrite heq_acctyp in heq_make_load.
        !invclear heq_make_load.
        apply h_eval_expr.
      * destruct v0;auto.
        eapply me_overflow0.
        eauto.
  - discriminate heq0.
  - discriminate heq0.
  - destruct (transl_expr st CE e1) eqn:heq_transl_expr1;(try now inversion heq);simpl in heq.
    destruct (transl_expr st CE e2) eqn:heq_transl_expr2;(try now inversion heq);simpl in heq.
    !invclear heq.
    specialize (IHh_eval_expr1 v1 e sp (refl_equal (Normal v1)) (refl_equal (OK e)) h_match_env).
    specialize (IHh_eval_expr2 v2 e0 sp (refl_equal (Normal v2)) (refl_equal (OK e0)) h_match_env).
    decomp IHh_eval_expr1. clear IHh_eval_expr1. rename H2 into hmatch1.
    decomp IHh_eval_expr2. clear IHh_eval_expr2. rename H2 into hmatch2.
    !inversion h_do_rtc_binop; try !invclear h_overf_check. rename H into h_or_op.
    + destruct h_or_op as [ | h_or_op]; [subst|destruct h_or_op;subst].
      * simpl in heq.
        (* shoul dbe a functional inversion *)
        !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in heq.
        inversion heq;subst.
        exists (Values.Vint (Integers.Int.repr (n+n0))).
        { (repeat split);simpl;auto.
          - econstructor.
            { apply h_CM_eval_expr. }
            { apply h_CM_eval_expr0. }
            simpl.
            !invclear heq_transl_value.
            !invclear heq_transl_value0.
            rewrite (add_ok _ _ (n + n0) n n0);auto.
            + constructor.
              inversion hmatch1.
              assumption.
            + constructor.
              inversion hmatch2.
              assumption.
          - constructor.
            assumption. }
      * simpl in heq.
        destruct v1;try discriminate; destruct v2;try discriminate;simpl in heq.
        inversion heq. subst.
        exists (Values.Vint (Integers.Int.repr (n-n0))).
        { (repeat split);auto.
          - econstructor.
            { apply h_CM_eval_expr. }
            { apply h_CM_eval_expr0. }
            simpl.
            !invclear heq_transl_value.
            !invclear heq_transl_value0.
            rewrite (sub_ok _ _ (n - n0) n n0);auto.
            + constructor.
              inversion hmatch1.
              assumption.
            + constructor.
              inversion hmatch2.
              assumption.
          - constructor.
            assumption. }
      * simpl in heq.
        destruct v1;try discriminate; destruct v2;try discriminate;simpl in heq.
        inversion heq. subst.
        exists (Values.Vint (Integers.Int.repr (n*n0))).
        { (repeat split);auto.
          - econstructor.
            { apply h_CM_eval_expr. }
            { apply h_CM_eval_expr0. }
            simpl.
            !invclear heq_transl_value.
            !invclear heq_transl_value0.
            rewrite (mult_ok _ _ (n * n0) n n0);auto.
            + constructor.
              inversion hmatch1.
              assumption.
            + constructor.
              inversion hmatch2.
              assumption.
          - constructor.
            assumption. }

        
    + exists (Values.Vint (Integers.Int.repr (Z.quot v3 v4))).
      { (repeat split);auto.
        - !invclear heq_transl_value.
          !invclear heq_transl_value0.
          simpl.
          apply f_equal.
          apply f_equal.
          apply f_equal.
          !inversion h_do_division_check.
          simpl in heq.
          !inversion heq.
          reflexivity.
        - econstructor.
          { apply h_CM_eval_expr. }
          { apply h_CM_eval_expr0. }
          simpl.
          !invclear heq_transl_value.
          !invclear heq_transl_value0.
          rewrite (div_ok _ _ (Z.quot v3 v4) v3 v4);auto.
          + constructor.
            inversion hmatch1.
            assumption.
          + constructor.
            inversion hmatch2.
            assumption.
          +  eapply Do_Check_On_Divide;eauto.
             !inversion h_do_division_check.
             simpl in heq.
             !invclear heq.
             apply Do_Overflow_Check_OK.
             assumption.
        - !inversion h_do_division_check.
          simpl in heq.
          !invclear heq.
          apply Do_Overflow_Check_OK.
          assumption. }
    + destruct op;simpl in *; try match goal with H: ?A <> ?A |- _ => elim H;auto end.
      * clear hmatch1 hmatch2.
        repeat match goal with | H:?X <> ?Y |-_ => clear H end.
        exists (Values.Val.and x x0).
        { repeat split.
          - !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
            !invclear heq.
            destruct n;destruct n0;simpl
            ;inversion heq_transl_value
            ;inversion heq_transl_value0
            ; reflexivity.
          - econstructor;eauto.
          - !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
            !invclear heq.
            trivial. }
      * clear hmatch1 hmatch2.
        repeat match goal with | H:?X <> ?Y |-_ => clear H end.
        exists (Values.Val.or x x0).
        { repeat split.
          - !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
            !invclear heq.
            destruct n;destruct n0;simpl
            ;inversion heq_transl_value
            ;inversion heq_transl_value0
            ; reflexivity.
          - econstructor;eauto.
          - !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
            !invclear heq.
            trivial. }

(*         XXXX etc. TRansformer tout ça en lemmes. *)
      * 



            !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
            !invclear heq.
            destruct n;destruct n0;simpl
            ;!invclear heq_transl_value
            ;!invclear heq_transl_value0
            ;subst.
            simpl.
            assumption.
            ; reflexivity.
          - 
        }
        

      !inversion h_do_rtc_binop.
       * decompose [or] H;subst; try match goal with H: ?A <> ?A |- _ => elim H;auto end.
       * match goal with H: ?A <> ?A |- _ => elim H;auto end.
       * 
      destruct (eval_binop (transl_binop op) x x0 m) eqn:heq_eval.
      Focus 2.
      * destruct op;simpl in heq_eval;inversion heq_eval.
        try match goal with H: ?A <> ?A |- _ => elim H;auto end.
      * !inversion h_do_rtc_binop.



        destruct op;simpl in heq_eval;!invclear heq_eval;subst;try match goal with H: ?A <> ?A |- _ => elim H;auto end.

        !inversion h_do_rtc_binop.
        exists (Values.Val.and x x0).
        



      * destruct v1. ;try discriminate; destruct v2;try discriminate;simpl in *.
        { exists (Values.Val.and x x0);repeat split;simpl;auto.
          - destruct n;destruct n0;simpl in *
            ; !invclear heq_transl_value; !invclear heq_transl_value0;simpl.
inversion heq.
            
            reflexivity.
        }
        
        
      { (repeat split);auto.
        - econstructor.
          { apply h_CM_eval_expr. }
          { apply h_CM_eval_expr0. }
          simpl.
          !invclear heq_transl_value.
            !invclear heq_transl_value0.
            rewrite (mult_ok _ _ (n * n0) n n0);auto.
            + constructor.
              inversion hmatch1.
              assumption.
            + constructor.
              inversion hmatch2.
              assumption.
          - constructor.
            assumption. }

      exists (Int n).
      
      





  - constructor.
          assumption. }

      inversion H.
      inversion H2.
      subst v0.
      rewrite add_ok in 
      



      inversion h_overf_check;subst;simpl.
      exists (Values.Vint (Integers.Int.repr v)).
      split;auto.
      econstructor.
      apply h_CM_eval_expr.
      apply h_CM_eval_expr0.
      decomp H0;subst;simpl.
      rewrite add_ok.

      * .
      simpl.


    XXX (* gérer les différents cas de do_run_time_check_on_binop ... (Normal v). *)
    

              exists v.
    + inversion heq.
      simpl in *.
      unfold id in *.
      apply IHh_eval_expr;auto.
      
    simpl in heq.
    (try now inversion heq). ;simpl in heq.



    destruct (transl_variable rstbl CE a i) eqn:heq_trv;simpl in *; (try now inversion heq); rename e into trv_i.
    destruct (fetch_exp_type a rstbl) eqn:heq_fetch; try now inversion heq.
    unfold value_at_addr in heq.
    destruct (transl_type rstbl t) eqn:heq_typ;simpl in *;try now inversion heq.
    !invclear h_eval_name.
    unfold make_load in heq.
    destruct (Ctypes.access_mode t0) eqn:heq_acctyp; !invclear heq.
    + destruct h_match_env.

      destruct (me_vars0 i rstbl a trv_i v t heq_SfetchG) as [v' me_vars1].
      * admit. (* propriété de cohérence de la pile, c'est du typage. *)
      * assumption.
      * clear me_vars0.
        decomp me_vars1.
        exists v'.
        { split.
          - assumption.
          - unfold make_load in heq_make_load. rewrite heq_acctyp in heq_make_load.
        reflexivity.
    + destruct h_match_env.
      eapply (me_vars0 i rstbl a );try now eassumption.
      * admit. (* propriété de cohérence de la pile, c'est du typage. *)
      * unfold make_load. rewrite heq_acctyp.
        reflexivity.
    + destruct h_match_env.
      eapply (me_vars0 i rstbl a );try now eassumption.
      * admit. (* propriété de cohérence de la pile, c'est du typage. *)
      * unfold make_load. rewrite heq_acctyp.
        reflexivity.
        
  - destruct (transl_expr rstbl CE e1) eqn:heq_tr_e1;try now inversion heq.
    destruct (transl_expr rstbl CE e2) eqn:heq_tr_e2;try now inversion heq.
    simpl in heq.
    !invclear heq.
    !invclear h_eval_expr.
    !destruct (transl_value v1).
    
    !inversion h_do_rtc_binop.
    + !invclear heq.
      !invclear heq.





(*

    Lemma transl_name_ok :
      forall a a0 i e e' t t' v v' s sp,
        transl_variable rstbl CE a i = OK e ->
        fetch_exp_type a rstbl = Some t ->
        transl_type rstbl t = OK t' ->
        make_load e t' = OK e' ->
        match_env s CE sp locenv ->
        transl_value v = OK v' ->
        eval_name stbl s (E_Identifier a0 i) (Normal v) ->
        Cminor.eval_expr g sp locenv m e' v'.
    Proof.
      !intros.
    Qed.


 *)
(* ********************************************** *)



(* FIXME *)
Definition compute_chnk (stbl:symboltable) (nme:name): res AST.memory_chunk :=
  OK AST.Mint32.


Fixpoint transl_lparameter_specification_to_ltype
         (stbl:symboltable) (lpspec:list parameter_specification): res (list AST.typ) :=
  match lpspec with
    | nil => OK nil
    | cons pspec lpspec' =>
      do ttyp <- transl_type stbl (pspec.(parameter_subtype_mark)) ;
      do tltyp <- transl_lparameter_specification_to_ltype stbl lpspec' ;
      OK (Ctypes.typ_of_type ttyp :: tltyp)
  end.

Definition transl_paramid := transl_num.

Fixpoint transl_lparameter_specification_to_lident
         (stbl:symboltable) (lpspec:list parameter_specification): (list AST.ident) :=
  match lpspec with
    | nil => nil
    | cons pspec lpspec' =>
      let tid := transl_paramid (pspec.(parameter_name)) in
      let tlid := transl_lparameter_specification_to_lident stbl lpspec' in
      tid :: tlid
  end.


Fixpoint transl_decl_to_lident (stbl:symboltable) (decl:declaration): list AST.ident :=
  match decl with
    | D_Null_Declaration => nil
    | D_Seq_Declaration _ decl1 decl2 =>
      let lident1 := transl_decl_to_lident stbl decl1 in
      let lident2 := transl_decl_to_lident stbl decl2 in
      List.app lident1 lident2
    | D_Object_Declaration _ objdecl => [transl_paramid objdecl.(object_name)]
    | D_Type_Declaration x x0 => nil
    | D_Procedure_Body x x0 => nil
  end.


Definition default_calling_convention := {| AST.cc_vararg := true;
                                            AST.cc_structret := true |}.

Definition transl_lparameter_specification_to_procsig
           (stbl:symboltable) (lvl:Symbol_Table_Module.level)
           (lparams:list parameter_specification) : res (AST.signature * Symbol_Table_Module.level) :=
  do tparams <- transl_lparameter_specification_to_ltype stbl lparams ;
  OK ({|
         (* add a void* to the list of parameters, for frame chaining *)
         AST.sig_args:= match lvl with
                          | 0 => tparams
                          | _ => AST.Tint :: tparams
                        end ;
         AST.sig_res := None ; (* procedure: no return type *)
         AST.sig_cc := default_calling_convention
       |}, lvl).


Fixpoint transl_paramexprlist (stbl: symboltable) (CE: compilenv) (el: list expression)
         (lparams:list parameter_specification)
         {struct el}: res (list Cminor.expr) :=
  match (el,lparams) with
  | (nil,nil) => OK nil
  | ((e1 :: e2) , (p1::p2)) =>
    match parameter_mode p1 with
      | In =>
          do te1 <- transl_expr stbl CE e1;
          do te2 <- transl_paramexprlist stbl CE e2 p2;
          OK (te1 :: te2)
      | _ =>
        match e1 with
          | E_Name _ nme =>
              do te1 <- transl_name stbl CE nme;
              do te2 <- transl_paramexprlist stbl CE e2 p2;
              OK (te1 :: te2)
          | _ =>  Error (msg "Out or In Out parameters should be names")
        end
    end

  | (_ , _) => Error (msg "Bad number of arguments")
  end.

Definition transl_params (stbl:symboltable) (pnum:procnum) (CE: compilenv)
           (el: list expression): res (list Cminor.expr) :=
  match fetch_proc pnum stbl with
    | None => Error (msg "Unkonwn procedure")
    | Some (lvl , pdecl) => transl_paramexprlist stbl CE el (procedure_parameter_profile pdecl)
  end.


Definition transl_procsig (stbl:symboltable) (pnum:procnum)
  : res (AST.signature * Symbol_Table_Module.level) :=
  match fetch_proc pnum stbl with
      | None => Error (msg "Unkonwn procedure")
      | Some (lvl , pdecl) => transl_lparameter_specification_to_procsig
                                stbl lvl (procedure_parameter_profile pdecl)
  end.

(* We don't want to change procedure names so we probably need to
   avoid zero as a procedure name in spark. *)
Definition transl_procid := transl_num.

(** Compilation of statements *)
Fixpoint transl_stmt (stbl:symboltable) (CE:compilenv) (e:statement) {struct e}: res stmt :=
  match e with
    | S_Null => OK Sskip
    | S_Sequence _ s1 s2 =>
      do ts1 <- transl_stmt stbl CE s1;
        do ts2 <- transl_stmt stbl CE s2;
        OK (Sseq ts1 ts2)
    | S_Assignment _ nme e =>
      do te <- transl_expr stbl CE e;
        do tnme <- transl_name stbl CE nme ;
        do chnk <- compute_chnk stbl nme ;
        OK (Sstore chnk tnme te)
    | S_If _ e s1 s2 =>
      do te1 <- transl_expr stbl CE e ;
        do te <- OK (Ebinop (Ocmp Integers.Cne)
                            te1 (Econst (Ointconst Integers.Int.zero)));
        do ts1 <- transl_stmt stbl CE s1;
        do ts2 <- transl_stmt stbl CE s2;
        OK (Sifthenelse te ts1 ts2)

    (* Procedure call. Ada RM tells that scalar parameters are always
       taken by value and if they are out or inout the copy is done
       *at the end* of the procedure. For composite types (arrays and
       record) the choice is left to the compiler (it is done by copy
       in the reference semantics), and for complex types (tasks,
       protected types) they are always taken by reference.

       Question: Since no aliasing is allowed in spark, it should not
       be possible to exploit one or the other strategy for arrays and
       records? *)
    | S_Procedure_Call _ _ pnum lexp =>
      do tle <- transl_params stbl pnum CE lexp ;
        do (procsig,lvl) <- transl_procsig stbl pnum ;
        (* The height of CE is exactly the nesting level of the current procedure + 1 *)
        let current_lvl := (List.length CE - 1) in
        (* compute the expression denoting the address of the frame of
           the enclosing procedure. Note that it is not the current
           procedure. We have to get down to the depth of the called
           procedure. *)
        do addr_enclosing_frame <- build_loads_ (current_lvl - lvl) ;
        (* Add it as one more argument to the procedure called. *)
        do tle' <- OK (addr_enclosing_frame :: tle) ;
        (* Call the procedure; procedure name does not change (except it is a positive) ? *)
        (* Question: what should be the name of a procedure in Cminor? *)
        OK (Scall None procsig (Econst (Oaddrsymbol (transl_procid pnum) (Integers.Int.repr 0%Z))) tle')

    (* No loops yet. Cminor loops (and in Cshminor already) are
       infinite loops, and a failing test (the test is a statement,
       not an expression) does a "exit n" where is nb of level to go
       out of the loop (if the test contains a block...). See
       Cshmgen.transl_statement, we need to have the number of
       necessary breaks to get out. *)
    | S_While_Loop x x0 x1 => Error (msg "transl_stmt:Not yet implemented")
  end.

(** * Functions for manipulating the [compilenv]

[compilenv] is the type of the static frame stack we maintain during
compilation. It stores the offset of each visible variable (in its own
frame) and the level of nesting of each one. The nestng level is
actually represented by the structure of the compilenv: Concretely a
compilenv is a stack ([CompilEnv.stack]) of frames
([frame] = [scope*localframe]'s). A part of the compilation process to Cminor
consists in using the information of this stack to maintain a pseudo
stack in memory, that is isomorphic to this environment (chaining
frames thanks to an implicit argument added to each procedure). *)

(* [compute_size stbl typ] return the size needed to store values of
   typpe subtyp_mrk *)
Definition compute_size (stbl:symboltable) (typ:type) := 4%Z.

(** Add an element to a frame. *)
Definition add_to_frame stbl (cenv_sz:localframe*Z) nme subtyp_mrk: localframe*Z  :=
  let (cenv,sz) := cenv_sz in
  let size := compute_size stbl subtyp_mrk in
  let new_size := (sz+size)%Z in
  let new_cenv := (nme,sz) :: cenv in
  (new_cenv,new_size).

(* [build_frame_lparams stbl (fram,sz) lparam] uses fram as an
   accumulator to build a frame env for lparam. It also compute
   the overall size of the store. *)
Fixpoint build_frame_lparams (stbl:symboltable) (fram_sz:localframe * Z)
         (lparam:list parameter_specification): localframe*Z :=
  match lparam with
    | nil => fram_sz
    | mkparameter_specification _ nme subtyp_mrk mde :: lparam' =>
      let new_fram_sz := add_to_frame stbl fram_sz nme subtyp_mrk in
      build_frame_lparams stbl new_fram_sz lparam'
  end.

(* [build_frame_decl stbl (fram,sz) decl] uses fram as an
   accumulator to build a frame for decl. It also compute
   the overall size of the store. *)
Fixpoint build_frame_decl (stbl:symboltable) (fram_sz:localframe * Z)
         (decl:declaration): localframe*Z :=
  let (fram,sz) := fram_sz in
  match decl with
    | D_Null_Declaration => fram_sz
    | D_Seq_Declaration _ decl1 decl2 =>
      let fram2_sz1 := build_frame_decl stbl fram_sz decl1 in
      build_frame_decl stbl fram2_sz1 decl2
    | D_Object_Declaration _ objdecl =>
      let size := compute_size stbl (objdecl.(object_nominal_subtype)) in
      let new_size := (sz+size)%Z in
      (((objdecl.(object_name),sz)::fram) ,new_size)
    | _ => fram_sz
  end.



(* [build_compilenv stbl enclosingCE pbdy] returns the new compilation
   environment built from the one of the enclosing procedure
   [enclosingCE] and the list of parameters [lparams] and local
   variables [decl]. It attributes an offset to each of these
   variable names. One of the things to note here is that it adds a
   variable at offset 0 which contains the address of the frame of the
   enclosing procedure, for chaining. Procedures are ignored. *)
Fixpoint build_compilenv (stbl:symboltable) (enclosingCE:compilenv) (lvl:Symbol_Table_Module.level)
         (lparams:list parameter_specification) (decl:declaration) : res (compilenv*Z) :=
  let '(init,sz) := match lvl with
                | 0 => (nil,0%Z) (* no chaining for global procedures *)
                | _ => (((0,0%Z) :: nil),4%Z)
              end in
  let stosz := build_frame_lparams stbl (init, sz) lparams in
  let (sto2,sz2) := build_frame_decl stbl stosz decl in
  let scope_lvl := List.length enclosingCE in
  OK (((scope_lvl,sto2)::enclosingCE),sz2).


(** * Translating a procedure declaration

Such a declaration contains other declaration, possibly declarations
of nested procedures. *)

(** [store_params lparams statm] adds a prelude to statement [statm]
    which effect is to store all parameters values listed in [lparams]
    into local (non temporary) variables. This is needed by nested
    procedure who need a way to read and write the parameters.

    Possible optimizations: 1) Do this only if there are nested procedures
    2) Do this only for variables that are indeed accessed (read or
       write) by nested procedures.

    Remark 1 about optimizations: during compilation we would need to
    remember which parameter is a temporary variable and which is not.
    Maybe in a new preliminary pass spark -> (spark with temporaries)?

    Remark2 about optimizations: Compcert do that in
    cfrontend/SimplLocals.v. In Clight parameters are all put into
    temporary variables and the one that cannot really be "lifted" to
    temporary (because their address is needed) are copied in the
    stack by the generated prelude of the procedure. *)
Fixpoint store_params stbl (CE:compilenv) (lparams:list parameter_specification) (statm:stmt)
         {struct lparams} : res stmt :=
  match lparams with
    | nil => OK statm
    | cons prm lparams' =>
      let id := transl_paramid prm.(parameter_name) in
      do chnk <- compute_chnk stbl (E_Identifier 0 (prm.(parameter_name))) ;
      do recres <- store_params stbl CE lparams' statm ;
      do lexp <- transl_name stbl CE (E_Identifier 0 (prm.(parameter_name))) ;
      let rexp := (* Should I do nothing for in (except in_out) params? *)
          match prm.(parameter_mode) with
            | In => Evar id
            | _ => (Eload chnk (Evar id))
          end in
      OK (Sseq (Sstore chnk lexp rexp) recres)
  end.


Fixpoint copy_out_params stbl (CE:compilenv)
         (lparams:list parameter_specification) (statm:stmt)
         {struct lparams} : res stmt :=
  match lparams with
    | nil => OK statm
    | cons prm lparams' =>
      let id := transl_paramid prm.(parameter_name) in
      do chnk <- compute_chnk stbl (E_Identifier 0 (prm.(parameter_name))) ;
        do recres <- copy_out_params stbl CE lparams' statm ;
        do rexp <- transl_name stbl CE (E_Identifier 0 (prm.(parameter_name))) ;
        match prm.(parameter_mode) with
          | In => OK recres
          | _ =>
            (* rexp is the *address* of the frame variable so we need
               a Eload to get the value. In contrast variable (Evar
               id) contains the address where this value should be
               copied and as it is in lvalue position we don't put a
               Eload. *)
            OK (Sseq recres (Sstore chnk (Evar id) (Eload chnk rexp)))
        end
  end.


(* [init_locals stbl CE decl statm] adds a prelude to statement
   [statm] which effect is to initialize variables according to
   intialzation expressions in [decl]. Variables declared in decl are
   supposed to already be added to compilenv [CE] (by
   [build_compilenv] above).*)
Fixpoint init_locals (stbl:symboltable) (CE:compilenv) (decl:declaration) (statm:stmt)
  : res stmt :=
  match decl with
    | D_Null_Declaration => OK statm
    | D_Seq_Declaration _ decl1 decl2 =>
      do stmt1 <- init_locals stbl CE decl2 statm ;
      init_locals stbl CE decl1 stmt1
    | D_Object_Declaration _ objdecl =>
      match objdecl.(initialization_expression) with
        | None => OK statm
        | Some e =>
          do chnk <- compute_chnk stbl (E_Identifier 0 objdecl.(object_name)) ;
          do exprinit <- transl_expr stbl CE e;
          do lexp <- transl_name stbl CE (E_Identifier 0 objdecl.(object_name)) ;
          OK (Sseq (Sstore chnk lexp exprinit) statm)
      end
    | _ => OK statm
  end.

Definition CMfundecls: Type := (list (AST.ident * AST.globdef fundef unit)).


(** Translating a procedure definition. First computes the compilenv
    from previous enclosing compilenv and local parameters and
    variables and then add a prelude (and a postlude) to the statement
    of the procedure. The prelude copies parameter to the local stack
    (including the chaining parameter) and execute intialization of
    local vars. *)
Fixpoint transl_procedure_body (stbl:symboltable) (enclosingCE:compilenv)
         (lvl:Symbol_Table_Module.level) (pbdy:procedure_body) (lfundef:CMfundecls)
  : res CMfundecls  :=
  match pbdy with
    | mkprocedure_body _ pnum lparams decl statm =>
        (* setup frame chain *)
        do (CE,stcksize) <- build_compilenv stbl enclosingCE lvl lparams decl ;
        if Coqlib.zle stcksize Integers.Int.max_unsigned
        then
          (* generate nested procedures inside [decl] with CE compile
             environment with one more lvl. *)
          do newlfundef <- transl_declaration stbl CE (S lvl) decl lfundef;
          (* translate the statement of the procedure *)
          do bdy <- transl_stmt stbl CE statm ;
          (* Adding prelude: initialization of variables *)
          do bdy_with_init <- init_locals stbl CE decl bdy ;
          (* Adding prelude: copying parameters into frame *)
          do bdy_with_init_params <- store_params stbl CE lparams bdy_with_init ;
          (* Adding prelude: copying chaining parameter into frame *)
          do bdy_with_init_params_chain <-
             match lvl with
               | 0 => OK bdy_with_init_params (* no chain fof global procedures *)
               | _ => OK (Sseq (Sstore AST.Mint32 ((Econst (Oaddrstack (Integers.Int.zero))))
                                       (Evar chaining_param))
                               bdy_with_init_params)
             end ;
          (* Adding postlude: copying back out params *)
          do bdy_with_init_params_chain_copyout <-
             copy_out_params stbl CE lparams bdy_with_init_params_chain ;
          do (procsig,_) <- transl_lparameter_specification_to_procsig stbl lvl lparams ;
          (** For a given "out" (or inout) argument x of type T of a procedure P:
             - transform T into T*, and change conequently the calls to P and signature of P.
             - add code to copy *x into the local stack at the
               beginning of the procedure, lets call x' this new
               variable
             - replace all operations on x by operations on x' (of type T unchanged)
             - add code at the end of the procedure to copy the value
               of x' into *x (this achieves the copyout operation). *)
          let tlparams := transl_lparameter_specification_to_lident stbl lparams in
          let newGfun :=
              (transl_paramid pnum,
              AST.Gfun (AST.Internal {|
                            fn_sig:= procsig;
                            (** list of idents of parameters (including the chaining one) *)
                            fn_params :=
                              match lvl with
                                | 0 => tlparams (* no chaining for global procedures *)
                                | _ => chaining_param :: tlparams
                              end;
                            (* list ident of local vars, including copy of parameters and chaining parameter *)
                            fn_vars:=
                              transl_decl_to_lident stbl decl
                              ;
                            fn_stackspace:= stcksize%Z;
                            fn_body:= bdy_with_init_params_chain_copyout
                          |})) in
          OK (newGfun :: newlfundef)
        else Error(msg "spark2Cminor: too many local variables, stack size exceeded")
  end

(* FIXME: check the size needed for the declarations *)
with transl_declaration
       (stbl:symboltable) (enclosingCE:compilenv)
       (lvl:Symbol_Table_Module.level) (decl:declaration) (lfundef:CMfundecls)
     : res CMfundecls :=
  match decl with
      | D_Procedure_Body _ pbdy =>
        transl_procedure_body stbl enclosingCE lvl pbdy lfundef
      | D_Seq_Declaration _ decl1 decl2 =>
        do p1 <- transl_declaration stbl enclosingCE lvl decl1 lfundef;
        do p2 <- transl_declaration stbl enclosingCE lvl decl2 p1;
        OK p2
      | D_Object_Declaration astnum objdecl =>
        do tobjdecl <- OK (transl_paramid objdecl.(object_name),
                           AST.Gvar {| AST.gvar_info := tt;
                                       AST.gvar_init := nil; (* TODO list AST.init_data*)
                                       AST.gvar_readonly := false; (* FIXME? *)
                                       AST.gvar_volatile := false |} (* FIXME? *)
                          ) ; (*transl_objdecl stbl 0  ;*)
        OK (tobjdecl :: lfundef)

      | D_Type_Declaration _ _ =>
        Error (msg "transl_declaration: D_Type_Declaration not yet implemented")
      | D_Null_Declaration => OK lfundef
  end.

(** In Ada the main procedure is generally a procedure at toplevel
    (not inside a package or a procedure). This function returns the
    first procedure id found in a declaration. *)
Fixpoint get_main_procedure (decl:declaration) : option procnum :=
  match decl with
    | D_Null_Declaration => None
    | D_Type_Declaration _ x0 => None
    | D_Object_Declaration _ x0 => None
    | D_Seq_Declaration _ x0 x1 =>
      match get_main_procedure x0 with
        | None => get_main_procedure x1
        | Some r => Some r
      end
    | D_Procedure_Body _  (mkprocedure_body _ pnum _ _ _) => Some pnum
  end.

(** Intitial program (with no procedure definition yet, onyl
    referencing the main procedure name. *)
Definition build_empty_program_with_main procnum (lfundef:CMfundecls) :=
  {| AST.prog_defs := lfundef;
     AST.prog_main := transl_num procnum |}.

Definition transl_program (stbl:symboltable) (decl:declaration) : res (Cminor.program) :=
  match get_main_procedure decl with
    | None => Error (msg "No main procedure detected")
    | Some mainprocnum =>
      (* Check size returned by build_compilenv *)
      do (cenv,_) <- build_compilenv stbl nil 0(*nesting lvl*) nil(*params*) decl ;
      do lfdecl <- transl_declaration stbl cenv 0(*nesting lvl*) decl nil(*empty accumlator*) ;
      OK (build_empty_program_with_main mainprocnum lfdecl)
  end.

(*
Definition from_sireum x y :=
  do stbl <- reduce_stbl x ;
  transl_program stbl y.


(* These notation are complex BUT re-parsable. *)
Notation "$ n" := (Evar n) (at level 80) : spark_scope.
Notation "& n" := (Econst (Oaddrstack n))(at level 80) : spark_scope.
Notation "'&_' n" := (Oaddrstack (Integers.Int.repr n))(at level 80) : spark_scope.
Notation "'&__' n" := (Econst (Oaddrstack (Integers.Int.repr n)))(at level 80) : spark_scope.
(* Notation "'⟨' n '⟩'" := (Integers.Int.repr n) : spark_scope. *)
Open Scope spark_scope.
Notation "'<_' n '_>'" := (Econst (Ointconst (Integers.Int.repr n))) (at level 9) : spark_scope.
Notation "e1 <*> e2" := (Ebinop Omul e1 e2) (left associativity,at level 40) : spark_scope.
Notation "e1 <+> e2" := (Ebinop Oadd e1 e2) (left associativity,at level 50) : spark_scope.
Notation "e1 <-b> e2" := (Ebinop Osub e1 e2) (left associativity,at level 50) : spark_scope.
Notation " <-u> e" := (Eunop Onegint e) (at level 35) : spark_scope.

Notation "X ++ Y" := (String.append X Y) : spark_scope.

(* Notation "'[<<' n + m '>>]'" :=  (Econst (Oaddrstack n) <<+>> [<<m>>])(at level 9) : spark_scope.  *)
Notation "'Int32[' x ']'" := (Eload AST.Mint32 x) (at level 0) : spark_scope.
Notation "'Int32[' e1 ']' <- e2" := (Sstore AST.Mint32 e1 e2)(at level 60) : spark_scope.
(* Notation "'Int32[' e1 <+> e2 ']' <- e3" := (Sstore AST.Mint32 (Econst e1 <+> e2) e3)(at level 60) : spark_scope. *)
Notation "s1 ;; s2" := (Sseq s1 s2) (at level 80,right associativity) : spark_scope.

Import symboltable.

(* copy the content or prcoi.v here *)
Open Scope nat_scope.

Load "sparktests/proc2".

(* Set Printing All. *)
Set Printing Width 120.

Eval compute in from_sireum Symbol_Table Coq_AST_Tree.



*)


(* * Generation of a symbol table for a procedure.

No need to add the chaining parameter here, the symbol table is never
searched for it. *)
(*
Definition empty_stbl:symboltable :=
  {|
    Symbol_Table_Module.vars  := nil; (*list (idnum * (mode * type)) *)
    Symbol_Table_Module.procs := nil; (*list (procnum * (Symbol_Table_Module.level * Symbol_Table_Module.proc_decl))*)
    Symbol_Table_Module.types := nil; (*list (typenum * Symbol_Table_Module.type_decl)*)
    Symbol_Table_Module.exps  := nil; (*list (astnum * type) *)
    Symbol_Table_Module.sloc  := nil (* list (astnum * Symbol_Table_Module.source_location) *)
  |}.


Fixpoint transl_lparameter_specification_to_stbl
         (stbl:symboltable) (lpspec:list parameter_specification)
  : symboltable :=
  match lpspec with
    | nil => stbl
    | cons pspec lpspec' =>
      let stblrec := transl_lparameter_specification_to_stbl stbl lpspec' in
      (update_vars stblrec pspec.(parameter_name) (pspec.(parameter_mode),pspec.(parameter_subtype_mark)))
  end.


Fixpoint transl_decl_to_stbl (stbl:symboltable) (decl:declaration): symboltable :=
  match decl with
    | D_Null_Declaration => stbl
    | D_Seq_Declaration _ decl1 decl2 =>
      let stbl1 := transl_decl_to_stbl stbl decl1 in
      let stbl2 := transl_decl_to_stbl stbl1 decl2 in
      stbl2
    | D_Object_Declaration _ objdecl =>
      update_vars stbl objdecl.(object_name) (In_Out,objdecl.(object_nominal_subtype))
    | D_Type_Declaration x x0 => stbl (* not implemented yet *)
    | D_Procedure_Body _ pbdy =>
      (* FIXME: we should look for blocks inside the body of the procedure. *)
      let stbl1 := transl_lparameter_specification_to_stbl stbl (procedure_parameter_profile pbdy) in
      let stbl2 := transl_decl_to_stbl stbl1 (procedure_declarative_part pbdy) in
      stbl2
  (* TODO: go recursively there *)
  end.

Definition stbl_of_proc (pbdy:procedure_body) :=
  let stbl1 := transl_lparameter_specification_to_stbl empty_stbl (procedure_parameter_profile pbdy) in
  let stbl2 := transl_decl_to_stbl stbl1 (procedure_declarative_part pbdy) in
  stbl2.

Definition empty_CE: compilenv := nil.
*)
