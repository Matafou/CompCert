Require Import
 ZArith function_utils LibHypsNaming Errors spark2Cminor Cminor
 symboltable semantics semantics_properties Sorted Relations
 compcert.lib.Integers compcert_utils more_stdlib.

Require Ctypes.
Import Symbol_Table_Module Memory.

Open Scope error_monad_scope.
Open Scope Z_scope.

(* stdlib unicode binders are not boxed correctly imho. *)
Notation "∀ x .. y , P" := (forall x, .. (forall y, P) ..)
  (at level 200, x binder, y binder, right associativity,
  format "'[' ∀  x  ..  y , '/' P ']'") : type_scope.
Notation "∃ x .. y , P" := (exists x, .. (exists y, P) ..)
  (at level 200, x binder, y binder, right associativity,
   format "'[' ∃  '[ ' x  '/' ..  '/' y , ']' '/' P ']'") : type_scope.
Notation "'λ' x .. y , P" := (fun x => .. (fun y => P) ..)
  (at level 200, x binder, y binder, right associativity,
   format "'[' λ  '[ ' x  '/' ..  '/' y , ']' '/' P ']'") : type_scope.
Notation "x ∨ y" := (x \/ y)
  (at level 85, right associativity,
   format "'[ ' x  ∨ '/' y ']'") : type_scope.
Notation "x ∧ y" := (x /\ y)
  (at level 80, right associativity,y at level 80,
   format "'[ ' x  '/' ∧  y ']'") : type_scope.
Notation "x → y" := (x -> y)
 (at level 99, y at level 200, right associativity,
   format "'[ ' x  '/' →  y ']'"): type_scope.
Notation "x ↔ y" := (x <-> y)
  (at level 95, no associativity,
     format "'[ ' x  '/' ↔  y ']'"): type_scope.
Notation "¬ x" := (~x) (at level 75, right associativity) : type_scope.
Notation "x ≠ y" := (x <> y) (at level 70) : type_scope.
Notation "x ≤ y" := (le x y) (at level 70, no associativity).
Notation "x ≥ y" := (ge x y) (at level 70, no associativity).


(* A tactic which moves up a hypothesis if it sort is Type or Set. *)
Ltac move_up_types H := match type of H with
                        | ?T => match type of T with
                                | Prop => idtac
                                | Set => move H at top
                                | Type => move H at top
                                end
                        end.

(* Iterating the tactic on all hypothesis. Moves up all Set/Type
   variables to the top. Really useful with [Set Compact Context]
   which is no yet commited in coq-trunk. *)
Ltac up_type := map_all_hyps_rev move_up_types.


(** Hypothesis renaming stuff from other files *)
Ltac rename_hyp_prev h th :=
  match th with
  | _ => (semantics_properties.rename_hyp1 h th)
  | _ => (spark2Cminor.rename_hyp1 h th)
  | _ => (compcert_utils.rename_hyp1 h th)
  end.

Ltac rename_hyp ::= rename_hyp_prev.

(* Removal of uninformative equalities *)
Ltac remove_refl :=
  repeat
    match goal with
    | H: ?e = ?e |- _ => clear H
    end.

(* + exploiting equalities. *)
Ltac eq_same_clear :=
  repeat progress
         (repeat remove_refl;
           repeat match goal with
                  | H: ?A = _ , H': ?A = _ |- _ => rewrite H in H'; !inversion H'
                  | H: OK ?A = OK ?B |- _ => !inversion H
                  | H: Some ?A = Some ?B |- _ => !inversion H
                  | H: Normal ?A = Normal ?B |- _ => !inversion H
                  | H: Normal ?A = Run_Time_Error ?B |- _ => discriminate H
                  | H: Run_Time_Error ?B= Normal ?A |- _ => discriminate H
                  | H: ?A <> ?A |- _ => elim H;reflexivity
                  end).


(* basic notions coincides between compcert and spark *)
Lemma wordsize_ok : wordsize = Integers.Int.wordsize.
Proof. reflexivity. Qed.

Lemma modulus_ok: modulus = Integers.Int.modulus.
Proof. reflexivity. Qed.

Lemma half_modulus_ok: half_modulus = Integers.Int.half_modulus.
Proof. reflexivity. Qed.

Lemma max_unsigned_ok: max_unsigned = Integers.Int.max_unsigned.
Proof. reflexivity. Qed.

Lemma max_signed_ok: max_signed = Integers.Int.max_signed.
Proof. reflexivity. Qed.

Lemma min_signed_ok: min_signed = Integers.Int.min_signed.
Proof. reflexivity. Qed.

(* TODO: replace this y the real typing function *)
Definition type_of_name (stbl:symboltable) (nme:name): res type :=
  match nme with
  | E_Identifier astnum id =>
    match symboltable.fetch_exp_type astnum stbl with
      Some x => OK x
    | None =>  Error (msg "type_of_name: unknown type for astnum")
    end
  | E_Indexed_Component astnum x0 x1 =>
    match symboltable.fetch_exp_type astnum stbl with
      Some x => OK x
    | None =>  Error (msg "type_of_name: unknown type for astnum (indexed_component")
    end
  | E_Selected_Component astnum x0 x1 =>
    match symboltable.fetch_exp_type astnum stbl with
      Some x => OK x
    | None =>  Error (msg "type_of_name: unknown type for astnum (selected_component")
    end
  end.


(** Hypothesis renaming stuff *)
Ltac rename_hyp1 h th :=
  match th with
  (* TODO: remove when we remove type_of_name by the real one. *)
  | type_of_name _ _ = Error _ => fresh "heq_type_of_name_ERR"
  | type_of_name _ _ = _ => fresh "heq_type_of_name"
  | Values.Val.bool_of_val ?v ?b => fresh "heq_bofv_" v "_" b
  | Values.Val.bool_of_val ?v ?b => fresh "heq_bofv_" v
  | Values.Val.bool_of_val ?v ?b => fresh "heq_bofv_" b
  | Values.Val.bool_of_val ?v ?b => fresh "heq_bofv"
  | expression => fresh "e"
  | statement => fresh "stmt"
  | Cminor.expr => match goal with
                   | H: transl_expr ?stbl ?CE ?x = OK h |- _ => fresh x "_t"
                   | H: transl_name ?stbl ?CE ?x = OK h |- _ => fresh x "_t"
                   end
  | AST.memory_chunk => match goal with
                   | H: compute_chnk ?stbl ?x = OK h |- _ => fresh x "_chk"
                   end
  | SymTable_Exps.V =>
    match goal with
    | H: symboltable.fetch_exp_type (name_astnum ?x) _ = Some h |- _ => fresh x "_type"
    | H: symboltable.fetch_exp_type ?x _ = Some h |- _ => fresh x "_type"
    end
  | Values.val =>
    match goal with
    | H:  Cminor.eval_expr _ _ _ _ ?e h |- _ => fresh e "_v"
    end
  | value =>
    match goal with
    | H:  eval_expr _ _ ?e (Normal h) |- _ => fresh e "_v"
    | H:  eval_expr _ _ ?e h |- _ => fresh e "_v"
    end
  | _ => (rename_hyp_prev h th)
  end.

Ltac rename_hyp ::= rename_hyp1.

Lemma transl_value_det: forall v tv1 tv2,
    transl_value v tv1 -> transl_value v tv2 -> tv1 = tv2.
Proof.
  !intros.
  inversion heq_transl_value_v_tv1; inversion heq_transl_value_v_tv2;subst;auto;inversion H1;auto.
Qed.

(* clear may fail if h is not a hypname *)
(* Tactic Notation "decomp" constr(h) := *)
(*        !! (decompose [and ex or] h). *)

Lemma transl_value_tot: forall v,
    (forall y:nat,(exists b, v = Bool b \/ exists n, v = Int n))
    -> exists tv, transl_value v tv.
Proof.
  !intros.
  decomp (H 0%nat);subst.
  - destruct x;eexists;econstructor.
  - eexists;econstructor.
Qed.


Lemma transl_literal_ok1 : forall g (l:literal) v,
    eval_literal l (Normal v) ->
    forall sp t_v,
      eval_constant g sp (transl_literal l) = Some t_v ->
      transl_value v t_v.
Proof.
  !intros.
  !destruct l;simpl in *;eq_same_clear.
  - !inversion h_eval_literal.
    !inversion h_overf_check.
    constructor.
  - destruct b;simpl in *;eq_same_clear.
    + !inversion h_eval_literal;constructor.
    + !inversion h_eval_literal;constructor.
Qed.

Lemma transl_literal_ok2 : forall g (l:literal) v,
    eval_literal l (Normal v) ->
    forall sp t_v,
      transl_value v t_v ->
      eval_constant g sp (transl_literal l) = Some t_v.
Proof.
  !intros.
  !destruct l;simpl in *;eq_same_clear.
  - !inversion h_eval_literal.
    !inversion h_overf_check.
    !inversion heq_transl_value_v_t_v.
    reflexivity.
  - destruct b;simpl in *;eq_same_clear.
    + !inversion h_eval_literal.
      !inversion heq_transl_value_v_t_v.
      reflexivity.
    + !inversion h_eval_literal.
      !inversion heq_transl_value_v_t_v.
      reflexivity.
Qed.

Lemma transl_literal_ok : forall g (l:literal) v,
    eval_literal l (Normal v) ->
    forall sp t_v,
      eval_constant g sp (transl_literal l) = Some t_v <->
      transl_value v t_v.
Proof.
  intros g l v H sp t_v.
  split.
  - apply transl_literal_ok1.
    assumption.
  - apply transl_literal_ok2.
    assumption.
Qed.


Ltac inv_if_intop op h :=
  match op with
  | Plus => !invclear h
  | Minus => !invclear h
  | Multiply => !invclear h
  | Divide => !invclear h
  end.

(* Transform hypothesis of the form do_range_check into disequalities. *)
(* shortening the name to shorten the tactic below *)
Notation rtc_binop := do_run_time_check_on_binop (only parsing).
Ltac inv_rtc :=
  repeat
    progress
    (try match goal with
         | H: rtc_binop ?op Undefined _ (Normal _) |- _ => now inversion H
         | H: rtc_binop ?op _ Undefined (Normal _) |- _ => now inversion H
         | H: rtc_binop ?op _ (ArrayV _) (Normal _) |- _ => now inv_if_intop op H
         | H: rtc_binop ?op (ArrayV _) _ (Normal _) |- _ => now inv_if_intop op H
         | H: rtc_binop ?op _ (RecordV _) (Normal _) |- _ => now inv_if_intop op H
         | H: rtc_binop ?op (RecordV _) _ (Normal _) |- _ => now inv_if_intop op H
         | H: rtc_binop ?op _ (Bool _) (Normal _) |- _ => inv_if_intop op H
         | H: Math.binary_operation ?op _ (Bool _) = (Some _) |- _ => inv_if_intop op H
         | H: rtc_binop ?op (Bool _) _ (Normal _) |- _ => inv_if_intop op H
         | H: Math.binary_operation ?op (Bool _) _ = (Some _) |- _ => inv_if_intop op H
         | H: do_overflow_check _ (Normal (Int _)) |- _ => !invclear H
         | H: do_range_check _ _ _ (Normal (Int _)) |- _ => !invclear H
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
             let h1 := fresh "h_le" in
             let h2 := fresh "h_le" in
             destruct H as [h1 h2 ]
         end; auto 2).


(** In this section we prove that basic operators of SPARK behave,
    when they don't raise a runtime error, like Compcert ones. *)

Lemma not_ok: forall v1 v0 x,
    transl_value v1 x ->
    Math.unary_not v1 = Some v0 ->
    transl_value v0 (Values.Val.notbool x).
Proof.
  !intros.
  !destruct v1;try discriminate;simpl in *;eq_same_clear.
  !destruct n;simpl in *;
  inversion heq_transl_value_v1_x;
  constructor.
Qed.


Lemma and_ok: forall v1 v2 v0 x x0,
    transl_value v1 x ->
    transl_value v2 x0 ->
    Math.and v1 v2 = Some v0 ->
    transl_value v0 (Values.Val.and x x0).
Proof.
  !intros.
  !destruct v1;simpl in *;try discriminate; !destruct v2;simpl in *;try discriminate
  ;eq_same_clear.
  destruct n;destruct n0;simpl
  ;inversion heq_transl_value_v1_x
  ;inversion heq_transl_value_v2_x0
  ; constructor.
Qed.

Lemma or_ok: forall v1 v2 v0 x x0,
    transl_value v1 x ->
    transl_value v2 x0 ->
    Math.or v1 v2 = Some v0 ->
    transl_value v0 (Values.Val.or x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *;eq_same_clear.
  destruct n;destruct n0;simpl
  ;inversion heq_transl_value_v1_x
  ;inversion heq_transl_value_v2_x0
  ; constructor.
Qed.


Definition check_overflow_value (v:value) :=
  match v with
  | Undefined => True
  | Int n => do_overflow_check n (Normal (Int n))
  | Bool n => True
  | ArrayV a => True(* FIXME *)
  | RecordV r => True (* FIXME *)
  end.

Ltac rename_hyp2 h th :=
  match th with
  | check_overflow_value _ => fresh "h_check_overf"
  | _ => rename_hyp1 h th
  end.

Ltac rename_hyp ::= rename_hyp2.


Lemma eq_ok: forall v1 v2 v0 x x0,
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    transl_value v1 x ->
    transl_value v2 x0 ->
    Math.eq v1 v2 = Some v0 ->
    transl_value v0 (Values.Val.cmp Integers.Ceq x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *;eq_same_clear.
  !destruct (Z.eq_dec n n0).
  - subst n0.
    inversion heq_transl_value_v1_x;subst;simpl.
    inversion heq_transl_value_v2_x0;subst;simpl.
    rewrite Fcore_Zaux.Zeq_bool_true;auto.
    unfold Values.Val.cmp.
    simpl.
    rewrite Integers.Int.eq_true.
    constructor.
  - rewrite Fcore_Zaux.Zeq_bool_false;auto.
    unfold Values.Val.cmp.
    inversion heq_transl_value_v2_x0;subst;simpl.
    inversion heq_transl_value_v1_x;subst;simpl.
    rewrite Integers.Int.eq_false.
    + constructor.
    + apply repr_inj_neq.
      * inv_rtc.
      * inv_rtc.
      * assumption.
Qed.


Lemma neq_ok: forall v1 v2 v0 x x0,
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    transl_value v1 x ->
    transl_value v2 x0 ->
    Math.ne v1 v2 = Some v0 ->
    transl_value v0 (Values.Val.cmp Integers.Cne x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *;eq_same_clear.
  !destruct (Z.eq_dec n n0).
  - subst.
    replace (Zneq_bool n0 n0) with false. all:swap 1 2. {
      symmetry.
      apply Zneq_bool_false_iff.
      reflexivity. }
    unfold Values.Val.cmp.
    inversion heq_transl_value_v1_x;subst;simpl.
    inversion heq_transl_value_v2_x0;subst;simpl.
    rewrite Integers.Int.eq_true.
    simpl.
    constructor.
  - rewrite Zneq_bool_true;auto.
    unfold Values.Val.cmp.
    inversion heq_transl_value_v2_x0;subst;simpl.
    inversion heq_transl_value_v1_x;subst;simpl.
    rewrite Integers.Int.eq_false.
    simpl.
    + constructor.
    + apply repr_inj_neq.
      * inv_rtc.
      * inv_rtc.
      * assumption.
Qed.

Lemma le_ok: forall v1 v2 v0 x x0,
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    transl_value v1 x ->
    transl_value v2 x0 ->
    Math.le v1 v2 = Some v0 ->
    transl_value v0 (Values.Val.cmp Integers.Cle x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *;eq_same_clear.
  inversion heq_transl_value_v1_x;subst;simpl.
  inversion heq_transl_value_v2_x0;subst;simpl.
  !destruct (Z.le_decidable n n0).
  - rewrite Fcore_Zaux.Zle_bool_true;auto.
    unfold Values.Val.cmp.
    simpl.
    unfold Integers.Int.lt.
    rewrite Coqlib.zlt_false.
    + constructor.
    + rewrite Integers.Int.signed_repr;inv_rtc.
      rewrite Integers.Int.signed_repr;inv_rtc.
      auto with zarith.
  - { rewrite Fcore_Zaux.Zle_bool_false.
      - unfold Values.Val.cmp.
        simpl.
        unfold Integers.Int.lt.
        rewrite Coqlib.zlt_true.
        + constructor.
        + rewrite Integers.Int.signed_repr;inv_rtc.
          rewrite Integers.Int.signed_repr;inv_rtc.
          auto with zarith.
      - apply Z.nle_gt.
        assumption. }
Qed.


Lemma ge_ok: forall v1 v2 v0 x x0,
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    transl_value v1 x ->
    transl_value v2 x0 ->
    Math.ge v1 v2 = Some v0 ->
    transl_value v0 (Values.Val.cmp Integers.Cge x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
  eq_same_clear.
  inversion heq_transl_value_v1_x;subst;simpl.
  inversion heq_transl_value_v2_x0;subst;simpl.
  rewrite Z.geb_leb.
  !destruct (Z.le_decidable n0 n).
  - rewrite Fcore_Zaux.Zle_bool_true;auto.
    unfold Values.Val.cmp.
    simpl.
    unfold Integers.Int.lt.
    rewrite Coqlib.zlt_false.
    + constructor.
    + rewrite Integers.Int.signed_repr;inv_rtc.
      rewrite Integers.Int.signed_repr;inv_rtc.
      auto with zarith.
  - { rewrite Fcore_Zaux.Zle_bool_false.
      - unfold Values.Val.cmp.
        simpl.
        unfold Integers.Int.lt.
        rewrite Coqlib.zlt_true.
        + constructor.
        + rewrite Integers.Int.signed_repr;inv_rtc.
          rewrite Integers.Int.signed_repr;inv_rtc.
          auto with zarith.
      - apply Z.nle_gt.
        assumption. }
Qed.

Lemma lt_ok: forall v1 v2 v0 x x0,
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    transl_value v1 x ->
    transl_value v2 x0 ->
    Math.lt v1 v2 = Some v0 ->
    transl_value v0 (Values.Val.cmp Integers.Clt x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
  eq_same_clear.
  inversion heq_transl_value_v1_x;subst;simpl.
  inversion heq_transl_value_v2_x0;subst;simpl.
  simpl.
  !destruct (Z.lt_decidable n n0).
  - rewrite Fcore_Zaux.Zlt_bool_true;auto.
    unfold Values.Val.cmp.
    subst.
    simpl.
    unfold Integers.Int.lt.
    rewrite Coqlib.zlt_true.
    + constructor.
    + rewrite Integers.Int.signed_repr;inv_rtc.
      rewrite Integers.Int.signed_repr;inv_rtc.
  - { rewrite Fcore_Zaux.Zlt_bool_false.
      - unfold Values.Val.cmp.
        subst.
        simpl.
        unfold Integers.Int.lt.
        rewrite Coqlib.zlt_false.
        + constructor.
        + rewrite Integers.Int.signed_repr;inv_rtc.
          rewrite Integers.Int.signed_repr;inv_rtc.
      - auto with zarith. }
Qed.


Lemma gt_ok: forall v1 v2 v0 x x0,
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    transl_value v1 x ->
    transl_value v2 x0 ->
    Math.gt v1 v2 = Some v0 ->
    transl_value v0 (Values.Val.cmp Integers.Cgt x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
  eq_same_clear.
  inversion heq_transl_value_v1_x;subst;simpl.
  inversion heq_transl_value_v2_x0;subst;simpl.
  rewrite Z.gtb_ltb.
  !destruct (Z.lt_decidable n0 n).
  - rewrite Fcore_Zaux.Zlt_bool_true;auto.
    unfold Values.Val.cmp.
    subst.
    simpl.
    unfold Integers.Int.lt.
    rewrite Coqlib.zlt_true.
    + constructor.
    + rewrite Integers.Int.signed_repr;inv_rtc.
      rewrite Integers.Int.signed_repr;inv_rtc.
  - { rewrite Fcore_Zaux.Zlt_bool_false.
      - unfold Values.Val.cmp.
        subst.
        simpl.
        unfold Integers.Int.lt.
        rewrite Coqlib.zlt_false.
        + constructor.
        + rewrite Integers.Int.signed_repr;inv_rtc.
          rewrite Integers.Int.signed_repr;inv_rtc.
      - auto with zarith. }
Qed.


(* strangely this one does not need overflow preconditions *)
Lemma unaryneg_ok : forall n v1 v,
    transl_value v1 n ->
    Math.unary_operation Unary_Minus v1 = Some v ->
    transl_value v (Values.Val.negint n).
Proof.
  !intros.
  simpl in *.
  destruct v1;simpl in *;try discriminate.
  eq_same_clear.
  inversion heq_transl_value_v1_n.
  simpl.
  rewrite Integers.Int.neg_repr.
  constructor.
Qed.

Lemma do_run_time_check_on_binop_ok: forall v1 v2 v op,
    do_run_time_check_on_binop op v1 v2 (Normal v) ->
    Math.binary_operation op v1 v2 = Some v.
Proof.
  intros v1 v2 v op hdo_rtc.
  !invclear hdo_rtc.
  - !invclear h_overf_check.
    assumption.
  - !invclear h_do_division_check;simpl in *.
    !invclear h_overf_check.
    assumption.
  - assumption.
Qed.

Ltac int_simpl :=
  progress
    (try rewrite min_signed_ok;
      try rewrite max_signed_ok;
      try rewrite Integers.Int.add_signed;
      try rewrite Integers.Int.sub_signed;
      try rewrite Integers.Int.mul_signed;
      try rewrite Integers.Int.add_signed;
      rewrite !Integers.Int.signed_repr).

Lemma add_ok : forall v v1 v2 n1 n2,
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    do_run_time_check_on_binop Plus v1 v2 (Normal v) ->
    transl_value v1 n1 ->
    transl_value v2 n2 ->
    transl_value v (Values.Val.add n1 n2).
Proof.
  !intros.
  !destruct v1;simpl in *;try discriminate;eq_same_clear;subst;try now inv_rtc.
  !destruct v2;simpl in *; try discriminate;eq_same_clear;subst; try now inv_rtc.
  inversion heq_transl_value_v1_n1;subst;simpl.
  inversion heq_transl_value_v2_n2;subst;simpl.
  !invclear h_do_rtc_binop;simpl in *; eq_same_clear.
  !invclear h_overf_check.
  int_simpl;auto;inv_rtc.
  constructor.
Qed.

Lemma sub_ok : forall v v1 v2 n1 n2,
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    do_run_time_check_on_binop Minus v1 v2 (Normal v) ->
    transl_value v1 n1 ->
    transl_value v2 n2 ->
    transl_value v (Values.Val.sub n1 n2).
Proof.
  !intros.
  !destruct v1;simpl in *;try discriminate;eq_same_clear;subst; try now inv_rtc.
  !destruct v2;simpl in *; try discriminate;eq_same_clear;subst; try now inv_rtc.
  inversion heq_transl_value_v1_n1;subst;simpl.
  inversion heq_transl_value_v2_n2;subst;simpl.
  !invclear h_do_rtc_binop;simpl in *; eq_same_clear.
  !invclear h_overf_check.
  int_simpl;auto;inv_rtc.
  constructor.
Qed.

Lemma mult_ok : forall v v1 v2 n1 n2,
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    do_run_time_check_on_binop Multiply v1 v2 (Normal v) ->
    transl_value v1 n1 ->
    transl_value v2 n2 ->
    transl_value v (Values.Val.mul n1 n2).
Proof.
  !intros.
  simpl in *.
  !destruct v1;simpl in *;try discriminate;eq_same_clear;subst; try now inv_rtc.
  !destruct v2;simpl in *; try discriminate;eq_same_clear;subst; try now inv_rtc.
  inversion heq_transl_value_v1_n1;subst;simpl.
  inversion heq_transl_value_v2_n2;subst;simpl.
  !invclear h_do_rtc_binop;simpl in *; eq_same_clear.
  !invclear h_overf_check.
  int_simpl;auto;inv_rtc.
  constructor.
Qed.

(** Compcert division return None if dividend is min_int and divisor
    in -1, because the result would be max_int +1. In Spark's
    semantics the division is performed but then it fails overflow
    checks. *)
(*  How to compile this? probably by performing a check before. *)
Lemma div_ok : forall v v1 v2 n n1 n2,
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    do_run_time_check_on_binop Divide v1 v2 (Normal v) ->
    transl_value v1 n1 ->
    transl_value v2 n2 ->
    transl_value v n ->
    Values.Val.divs n1 n2 = Some n.
Proof.
  !intros.
  simpl in *.
  !destruct v1;subst;simpl in *;try discriminate;try now inv_rtc.
  !destruct v2;subst;simpl in *; try discriminate;try now inv_rtc.
  inversion heq_transl_value_v2_n2;subst;simpl.
  inversion heq_transl_value_v1_n1;subst;simpl.
  rename n0 into v1.
  rename n3 into v2.
  !invclear h_do_rtc_binop;simpl in *; eq_same_clear.
  { decompose [or] h_or;discriminate. }
  inv_rtc.
  rewrite min_signed_ok, max_signed_ok in *.
  !inversion h_do_division_check.
  apply Zeq_bool_neq in heq_Z_false.
  rewrite Integers.Int.eq_false;auto.
  - simpl.
    (* the case where division overflows is dealt with by the overflow
       check in spark semantic. Ths division is performed on Z and
       then overflow is checked and may fails. *)
    destruct (Int.eq (Int.repr v1)
                     (Int.repr Int.min_signed) &&
                     Int.eq (Int.repr v2) Int.mone)
             eqn:h_divoverf.
    + apply andb_true_iff in h_divoverf.
      destruct h_divoverf as [h_divoverf1 h_divoverf2].
      exfalso.
      assert (v1_is_min_int: v1 = Integers.Int.min_signed).
      { rewrite Integers.Int.eq_signed in h_divoverf1.
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
      vm_compute in heq.
      inversion heq.
      subst.
      inversion h_overf_check;subst.
      inv_rtc.
    + unfold Integers.Int.divs.
      rewrite !Integers.Int.signed_repr;auto 2.
      simpl in *.
      !invclear heq;subst.
      inversion h_overf_check;subst.
      inversion heq_transl_value_v_n;subst;simpl.
      reflexivity.
  - unfold Integers.Int.zero.
    intro abs.
    apply heq_Z_false.
    rewrite <- (Integers.Int.signed_repr v2).
    + rewrite abs.
      rewrite (Integers.Int.signed_repr 0);auto.
      split; intro;discriminate.
    + split;auto.
Qed.


Lemma binary_operator_ok: forall op (n n1 n2 : Values.val) (v v1 v2 : value),
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    do_run_time_check_on_binop op v1 v2 (Normal v) ->
    transl_value v1 n1 ->
    transl_value v2 n2 ->
    transl_value v n ->
    forall m, Cminor.eval_binop (transl_binop op) n1 n2 m = Some n.
Proof.
  !intros.
  assert (h_rtc:=do_run_time_check_on_binop_ok _ _ _ _ h_do_rtc_binop).
  destruct op;simpl in *.
  - eapply (and_ok v1 v2 v n1 n2) in h_rtc;auto.
    rewrite (transl_value_det _ _ _ heq_transl_value_v_n h_rtc);reflexivity.
  - eapply (or_ok v1 v2 v n1 n2) in h_rtc;eq_same_clear;subst;eauto.
    rewrite (transl_value_det _ _ _ heq_transl_value_v_n h_rtc);reflexivity.

  - eapply (eq_ok v1 v2 v n1 n2) in h_rtc;eq_same_clear;subst;eauto.
    rewrite (transl_value_det _ _ _ heq_transl_value_v_n h_rtc);reflexivity.
  - eapply (neq_ok v1 v2 v n1 n2) in h_rtc;eq_same_clear;subst;eauto.
    rewrite (transl_value_det _ _ _ heq_transl_value_v_n h_rtc);reflexivity.
  - eapply (lt_ok v1 v2 v n1 n2) in h_rtc;eq_same_clear;subst;eauto.
    rewrite (transl_value_det _ _ _ heq_transl_value_v_n h_rtc);reflexivity.
  - eapply (le_ok v1 v2 v n1 n2) in h_rtc;eq_same_clear;subst;eauto.
    rewrite (transl_value_det _ _ _ heq_transl_value_v_n h_rtc);reflexivity.
  - eapply (gt_ok v1 v2 v n1 n2) in h_rtc;eq_same_clear;subst;eauto.
    rewrite (transl_value_det _ _ _ heq_transl_value_v_n h_rtc);reflexivity.
  - eapply (ge_ok v1 v2 v n1 n2) in h_rtc;eq_same_clear;subst;eauto.
    rewrite (transl_value_det _ _ _ heq_transl_value_v_n h_rtc);reflexivity.
  - generalize (add_ok _ _ _ _ _ h_check_overf h_check_overf0 h_do_rtc_binop
                       heq_transl_value_v1_n1 heq_transl_value_v2_n2).
    intro h.
    rewrite (transl_value_det _ _ _ heq_transl_value_v_n h);reflexivity.
  - generalize (sub_ok _ _ _ _ _ h_check_overf h_check_overf0 h_do_rtc_binop
                       heq_transl_value_v1_n1 heq_transl_value_v2_n2).
    intro h.
    rewrite (transl_value_det _ _ _ heq_transl_value_v_n h);reflexivity.
  - generalize (mult_ok _ _ _ _ _ h_check_overf h_check_overf0 h_do_rtc_binop
                        heq_transl_value_v1_n1 heq_transl_value_v2_n2).
    intro h.
    rewrite (transl_value_det _ _ _ heq_transl_value_v_n h);reflexivity.
  - generalize (div_ok _ _ _ _ _ _ h_check_overf h_check_overf0 h_do_rtc_binop
                       heq_transl_value_v1_n1 heq_transl_value_v2_n2 heq_transl_value_v_n).
    intro h.
    assumption.
Qed.


(** * Memory invariant and bisimilarity *)


Lemma eval_literal_overf : forall (l:literal) n,
    eval_literal l (Normal (Int n)) ->
    do_overflow_check n (Normal (Int n)).
Proof.
  !intros.
  !inversion h_eval_literal.
  !inversion h_overf_check.
  assumption.
Qed.


(** [safe_stack s] means that every value in the spark stack [s] is
    correct wrt to overflows.
    TODO: extend with other values than Int: floats, arrays, records. *)
Definition safe_stack s := forall id n,
    STACK.fetchG id s = Some (Int n) ->
    do_overflow_check n (Normal (Int n)).

(** Hypothesis renaming stuff *)
Ltac rename_hyp2' h th :=
  match th with
  | safe_stack ?s => fresh "h_safe_stack_" s
  | safe_stack _ => fresh "h_safe_stack"
  | _ => rename_hyp2 h th
  end.

Ltac rename_hyp ::= rename_hyp2'.

Lemma eval_name_overf: forall s st nme n,
    safe_stack s
    -> eval_name st s nme (Normal (Int n))
    -> do_overflow_check n (Normal (Int n)).
Proof using.
  !intros.
  !inversion h_eval_name_nme. (* l'environnement retourne toujours des valeur rangées. *)
  - unfold safe_stack in *.
    eapply h_safe_stack_s;eauto.
  - simpl in *.
    constructor.
    admit. (* Arrays *)
  - admit. (* records *)
Admitted.

(** on a safe stack, any expression that evaluates into a value,
    evaluates to a not overflowing value, except if it is a unary_plus
    (in which case no check is made). *)
Lemma eval_expr_overf : forall st s,
    safe_stack s ->
    forall e n,
      eval_expr st s e (Normal (Int n)) ->
      do_overflow_check n (Normal (Int n)).
Proof.
  !intros.
  revert h_safe_stack_s.
  remember (Normal (Int n)) as hN.
  revert HeqhN.
  !induction h_eval_expr_e;!intros;subst;try discriminate.
  - eapply eval_literal_overf;eauto.
  - eapply eval_name_overf;eauto.
  - !invclear h_do_rtc_binop.
    + inversion h_overf_check;subst;auto.
    + inversion h_overf_check;subst;auto.
    + rewrite binopexp_ok in *.
      functional inversion heq;subst
      ;try match goal with H: ?A <> ?A |- _ => elim H;auto end.
  - !invclear h_do_rtc_unop.
    + inversion h_overf_check;subst;auto.
    + rewrite unopexp_ok in *.
      !functional inversion heq;subst
      ;try match goal with H: ?A <> ?A |- _ => elim H;auto end.
      !invclear heq.
      apply IHh_eval_expr_e;auto.
Qed.

Lemma eval_expr_overf2 : forall st s,
    safe_stack s ->
    forall (e:expression) e_v,
      eval_expr st s e (Normal e_v) -> check_overflow_value e_v.
Proof.
  !intros.
  destruct e_v;simpl in *;auto.
  eapply eval_expr_overf;eauto.
Qed.

Hint Resolve eval_expr_overf2.

Definition stack_complete stbl s CE := forall a nme addr_nme,
    transl_variable stbl CE a nme = OK addr_nme
    -> exists v, eval_name stbl s (E_Identifier a nme) (Normal v).

Definition stack_no_null_offset stbl CE := forall a nme δ_lvl δ_id,
    transl_variable stbl CE a nme = OK (build_loads δ_lvl δ_id) ->
    4 <= Int.unsigned (Int.repr δ_id).

Definition stack_localstack_aligned locenv g m := forall b δ_lvl v,
    Cminor.eval_expr g b locenv m (build_loads_ δ_lvl) v
    -> exists b', v = Values.Vptr b' Int.zero.

Definition stack_match st s CE sp locenv g m :=
  forall nme v addr_nme load_addr_nme typ_nme cm_typ_nme,
    eval_name st s nme (Normal v) ->
    type_of_name st nme = OK typ_nme ->
    transl_name st CE nme = OK addr_nme ->
    transl_type st typ_nme = OK cm_typ_nme ->
    make_load addr_nme cm_typ_nme = OK load_addr_nme ->
    exists v_t,
      (transl_value v v_t /\
       Cminor.eval_expr g sp locenv m load_addr_nme v_t).

(* Variable addresses are all disjoint *)
Definition stack_separate st CE sp locenv g m :=
  forall nme nme' addr_nme addr_nme'
         typ_nme typ_nme'  cm_typ_nme cm_typ_nme'
         k₁ δ₁ k₂ δ₂ chnk₁ chnk₂ ,
    type_of_name st nme = OK typ_nme ->
    type_of_name st nme' = OK typ_nme' ->
    transl_name st CE nme = OK addr_nme ->
    transl_name st CE nme' = OK addr_nme' ->
    transl_type st typ_nme = OK cm_typ_nme ->
    transl_type st typ_nme' = OK cm_typ_nme' ->
    Cminor.eval_expr g sp locenv m addr_nme (Values.Vptr k₁ δ₁) ->
    Cminor.eval_expr g sp locenv m addr_nme' (Values.Vptr k₂ δ₂) ->
    Ctypes.access_mode cm_typ_nme  = Ctypes.By_value chnk₁ ->
    Ctypes.access_mode cm_typ_nme' = Ctypes.By_value chnk₂ ->
    nme <> nme' ->
    (k₂ <> k₁
     \/ Int.unsigned δ₂ + Memdata.size_chunk chnk₂ <= Int.unsigned δ₁
     \/ Int.unsigned δ₁ + Memdata.size_chunk chnk₁ <= Int.unsigned δ₂).

Definition stack_freeable st CE sp g locenv m :=
  forall a chk id id_t b ofs,
    (* translating the variabe to a Cminor load address *)
    transl_variable st CE a id = OK id_t ->
    (* Evaluating var address in Cminor *)
    Cminor.eval_expr g sp locenv m id_t (Values.Vptr b ofs) ->
    (* Size of variable in Cminor memorry *)
    compute_chnk st (E_Identifier a id) = OK chk ->
    Mem.valid_access m chk b (Int.unsigned ofs) Freeable.


(* TODO: swap arguments *)
Definition ord_snd (x y:(idnum * CompilEnv.V)) := snd y < snd x.
Definition ord_fst (x y:(CompilEnv.scope_level * localframe)) := (fst y < fst x)%nat.

Definition increasing_order: localframe -> Prop :=
  StronglySorted ord_snd.

Definition increasing_order_fr (f:CompilEnv.frame) :=
  increasing_order(CompilEnv.store_of f).

Definition increasing_orderG (stk: CompilEnv.stack): Prop :=
  StronglySorted ord_fst stk.

Definition all_frm_increasing CE := Forall increasing_order_fr CE.

Definition all_addr_no_overflow CE := forall id δ,
    CompilEnv.fetchG id CE = Some δ -> 0 <= δ < Integers.Int.modulus.

Definition stbl_var_types_ok st :=
  ∀ nme t, type_of_name st nme = OK t ->
           ∃ nme_type_t, transl_type st t = OK nme_type_t.

(* See CminorgenProof.v@205. *)

(** The Memory bisimilarity/invariant property states that

 -[me_overflow] Spark stack [s] is ok wrt overflows 
 - Compilation environment [CE] contains exactly variables of spark
   stack [s]
 - All variable of [CE] are non overlapping (spark property)
 - The structure of the chaines stack in Cminor is maintained:
 -- Load (Load...(Load 0)) yields to some frame f and a null offset
    ([localstack_aligned])
 -- and no variable overlap with it ([no_null_offset]).
 - the value of a variable is equal to the value of its translation.
   Its translation is currently (an expression of the form
   ELoad((Eload(Eload ...(Eload(0)))) + n)).
 - spark variables and there translated address yield the same
   (translated) value. i.e. the two memories commute. *)
Record match_env st s CE sp locenv g m: Prop :=
  mk_match_env {
      me_stack_match: stack_match st s CE sp locenv g m;
      me_stack_complete: stack_complete st s CE;
      me_stack_separate: stack_separate st CE sp locenv g m;
      me_stack_localstack_aligned: stack_localstack_aligned locenv g m;
      me_stack_no_null_offset: stack_no_null_offset st CE;
      me_stack_freeable: stack_freeable st CE sp g locenv m;
      me_overflow: safe_stack s (* Put this somewhere else, concerns only s *)
    }.

Arguments me_stack_match : default implicits.
Arguments me_overflow : default implicits.
Arguments me_stack_no_null_offset : default implicits.
Arguments me_stack_localstack_aligned : default implicits.
Arguments me_stack_separate : default implicits.
Arguments me_stack_freeable : default implicits.
Arguments me_stack_complete : default implicits.

(** The compilation environment has some intrinsic properties:
 - Frame are numbered in increasing order in the global store
 - In each frame variables are numbered in increasing order
 - variable addresses do not overflow. *)
Record invariant_compile CE stbl :=
  { ci_increasing_lvls: increasing_orderG CE ;
    ci_increasing_ids: all_frm_increasing CE ;
    ci_no_overflow: all_addr_no_overflow CE ;
    ci_stbl_var_types_ok: stbl_var_types_ok stbl }.

Arguments ci_increasing_ids : default implicits.
Arguments ci_no_overflow : default implicits.
Arguments ci_stbl_var_types_ok : default implicits.

Hint Resolve ci_increasing_lvls ci_increasing_ids ci_no_overflow ci_stbl_var_types_ok.
Hint Resolve me_stack_match me_stack_complete me_stack_separate me_stack_localstack_aligned me_stack_no_null_offset me_overflow.


(** Hypothesis renaming stuff *)
Ltac rename_hyp3 h th :=
  match th with
  | match_env _ _ _ _ _ _ _ => fresh "h_match_env"
  | stack_match _ ?s _ _ _ _ ?m => fresh "h_stk_mtch_" s "_" m
  | stack_match _ _ _ _ _ _ _ => fresh "h_stk_mtch"
  | stack_complete _ ?s ?CE => fresh "h_stk_cmpl_" s "_" CE
  | stack_complete _ ?s _ => fresh "h_stk_cmpl_" s
  | stack_complete _ _ _ => fresh "h_stk_cmpl"
  | stack_localstack_aligned _ ?g ?m => fresh "h_aligned_" g "_" m
  | stack_localstack_aligned _ _ ?m => fresh "h_aligned_" m
  | stack_localstack_aligned _ ?g _ => fresh "h_aligned_" g
  | stack_no_null_offset _ _ => fresh "h_nonul_ofs"
  | stack_no_null_offset _ ?CE => fresh "h_nonul_ofs_" CE
  | stack_no_null_offset ?s _ => fresh "h_nonul_ofs_" s
  | stack_no_null_offset _ _ => fresh "h_nonul_ofs"
  | stack_separate _ ?CE _ _ _ ?m => fresh "h_separate_" CE "_" m
  | stack_separate _ _ _ _ _ ?m => fresh "h_separate_" m
  | stack_separate _ ?CE _ _ _ _ => fresh "h_separate_" CE
  | stack_separate _ _ _ _ _ _ => fresh "h_separate"
  | stack_freeable _ ?CE _ _ _ ?m => fresh "h_freeable_" CE "_" m
  | stack_freeable _ _ _ _ _ ?m => fresh "h_freeable_" m
  | stack_freeable _ ?CE _ _ _ _ => fresh "h_freeable_" CE
  | stack_freeable _ _ _ _ _ _ => fresh "h_freeable"
  | invariant_compile ?CE ?stbl => fresh "h_inv_comp_" CE "_" stbl
  | invariant_compile ?CE _ => fresh "h_inv_comp_" CE
  | invariant_compile _ ?stbl => fresh "h_inv_comp_" stbl
  | invariant_compile _ _ => fresh "h_inv_comp"
  | _ => rename_hyp2' h th
  end.

Ltac rename_hyp ::= rename_hyp3.

Ltac rename_hyp4 h th :=
  match reverse goal with
  | H: fetch_var_type ?X _ = OK h |- _  => (fresh "type_" X)
  | H: id (fetch_var_type ?X _ = OK h) |- _ => (fresh "type_" X)
  | H: (value_at_addr _ _ ?X = OK h) |- _ => fresh "val_at_" X
  | H: id (value_at_addr _ _ ?X = OK h) |- _ => fresh "val_at_" X
  | H: transl_variable _ _ _ ?X = OK h |- _ => fresh X "_t"
  | H: id (transl_variable _ _ _ ?X = OK h) |- _ => fresh X "_t"
  | H: transl_value ?X = OK h |- _ => fresh X "_t"
  | H: id (transl_value ?X = OK h) |- _ => fresh X "_t"
  | H: id (CompilEnv.frameG ?X _ = Some (h, _)) |- _ => fresh "lvl_" X
  | H: CompilEnv.frameG ?X _ = Some (h, _) |- _ => fresh "lvl_" X
  | H: id (CompilEnv.frameG ?X _ = Some (_, h)) |- _ => fresh "fr_" X
  | H: CompilEnv.frameG ?X _ = Some (_, h) |- _ => fresh "fr_" X
  | H: id (CompilEnv.fetchG ?X _ = Some h) |- _ => fresh "δ_" X
  | H: CompilEnv.fetchG ?X _ = Some h |- _ => fresh "δ_" X
  | H: id (CompilEnv.fetchG ?X _ = h) |- _ => fresh "δ_" X
  | H: CompilEnv.fetchG ?X _ = h |- _ => fresh "δ_" X
  | _ => rename_hyp3 h th
  end.
Ltac rename_hyp ::= rename_hyp4.

(** Property of the translation: Since chain variables have always zero
   offset, the offset of a variable in CE is the same as its offset in
   CMinor memory. *)
Lemma eval_build_loads_offset: forall g stkptr locenv m δ_lvl δ_id b ofs,
    stack_localstack_aligned locenv g m ->
    Cminor.eval_expr g stkptr locenv m (build_loads δ_lvl δ_id) (Values.Vptr b ofs) ->
    ofs = Int.repr δ_id.
Proof.
  !intros.
  unfold build_loads in *.
  !inversion h_CM_eval_expr.
  !inversion h_CM_eval_expr_v2.
  simpl in *.
  edestruct h_aligned_g_m;eauto.
  subst.
  destruct v2;try discriminate.
  simpl in *.
  !invclear heq;subst.
  inversion h_eval_constant.
  rewrite Int.add_zero_l.
  reflexivity.
Qed.


(** Property of the translation: Since chain variables have always
    zero offset, the offset of a variable in CE must be more than 3. *)
Lemma eval_build_loads_offset_non_null_var:
  forall stbl CE g stkptr locenv m nme a bld_lds b ofs,
    stack_no_null_offset stbl CE ->
    stack_localstack_aligned locenv g m ->
    transl_variable stbl CE a nme = OK bld_lds ->
    Cminor.eval_expr g stkptr locenv m bld_lds (Values.Vptr b ofs) ->
    4 <= Int.unsigned ofs.
Proof.
  !intros.
  functional inversion heq_transl_variable;subst.
  assert (ofs=(Int.repr n)). {
    eapply (eval_build_loads_offset _ _ _ _ _ _ _ ofs);eauto. }
  subst.
  eapply h_nonul_ofs;eauto.
Qed.

Lemma transl_expr_ok : forall stbl CE e e',
    transl_expr stbl CE e = OK e' ->
    forall locenv g m (s:STACK.stack)  (v:value) stkptr,
      eval_expr stbl s e (Normal v) ->
      match_env stbl s CE stkptr locenv g m ->
      exists v_t,
        (transl_value v v_t /\ Cminor.eval_expr g stkptr locenv m e' v_t).
Proof.
  intros until e.
  !functional induction (transl_expr stbl CE e) ;try discriminate;simpl; !intros;
  !invclear h_eval_expr_v;eq_same_clear.
  - inversion h_eval_literal;subst.
    + !destruct v0.
      * eexists;split;!intros;econstructor;eauto.
      * eexists;split;!intros;econstructor;eauto.
    + eexists;split;!intros.
      * eapply (transl_literal_ok g _ _ h_eval_literal stkptr).
        econstructor.
      * constructor.
        reflexivity.
  - unfold value_at_addr in heq.
    destruct (transl_type stbl astnum_type) eqn:heq_transl_type;simpl in *.
    + !destruct h_match_env.
      eapply h_stk_mtch_s_m;eauto.
      simpl.
      rewrite heq_fetch_exp_type.
      reflexivity.
    + discriminate.
  - decomp (IHr _ heq_tr_expr_e _ _ _ _ _ _ h_eval_expr_e_e_v h_match_env).
    decomp (IHr0 _ heq_tr_expr_e0 _ _ _ _ _ _ h_eval_expr_e0_e0_v h_match_env).
    assert (hex:or (exists b, v = Bool b) (exists n, v = Int n)). {
      apply do_run_time_check_on_binop_ok in h_do_rtc_binop.
      rewrite binopexp_ok in h_do_rtc_binop.
      functional inversion h_do_rtc_binop;subst;eq_same_clear
      ;try contradiction;eauto. }
    decomp hex;subst.
    + destruct x; eexists;(split;[econstructor;eauto|]).
      * eapply eval_Ebinop;try econstructor;eauto.
        eapply binary_operator_ok with (v1:=e_v) (v2:=e0_v);eauto.
        econstructor;eauto.
      * eapply eval_Ebinop;try econstructor;eauto.
        eapply binary_operator_ok with (v1:=e_v) (v2:=e0_v);eauto.
        econstructor;eauto.
    + eexists;(split;[econstructor;eauto|]).
      eapply eval_Ebinop;try econstructor;eauto.
        eapply binary_operator_ok with (v1:=e_v) (v2:=e0_v);eauto.
        econstructor;eauto.
  - (* Unary minus *)
    simpl in heq.
    eq_same_clear.
    specialize (IHr e_t heq_tr_expr_e locenv g m s e_v stkptr
                    h_eval_expr_e_e_v h_match_env).
    decomp IHr.
    !invclear h_do_rtc_unop;eq_same_clear.
    !invclear h_overf_check.
    eexists.
    split.
    * econstructor.
    * assert (h:=unaryneg_ok _ _ _ heq_transl_value_e_v_e_t_v heq).
      econstructor;eauto.
      simpl.
      inversion h.
      reflexivity.
  (* Not *)
  - !invclear h_do_rtc_unop;simpl in *;try eq_same_clear.
    specialize (IHr _ heq_tr_expr_e _ _ _ _ _ _ h_eval_expr_e_e_v h_match_env).
    decomp IHr.
    generalize (not_ok _ _ _ heq_transl_value_e_v_e_t_v heq).
    !intro.
    exists (Values.Val.notbool e_t_v).
    split;auto.
    econstructor;simpl in *;eauto.
    + econstructor;eauto.
      reflexivity.
    + destruct e_t_v;simpl in *; try (inversion heq_transl_value_e_v_e_t_v;fail).
      unfold  Values.Val.cmp.
      simpl.
      unfold Values.Val.of_bool.
      reflexivity.
Qed.

  

  



(** Hypothesis renaming stuff *)
Ltac rename_hyp5 th :=
  match th with
  | Cminor.exec_stmt _ _ _ _ _ _ _ _ _ None  => fresh "h_exec_stmt_None"
  | Cminor.exec_stmt _ _ _ _ _ _ _ _ _ _  => fresh "h_exec_stmt"
  | _ => rename_hyp4 th
  end.

Ltac rename_hyp ::= rename_hyp5.

Scheme Equality for binary_operator.
Scheme Equality for unary_operator.
Scheme Equality for literal.

Ltac finish_eqdec := try subst;try (left;reflexivity);(try now right;intro abs;inversion abs;contradiction).

Lemma expression_dec: forall e1 e2:expression, ({e1=e2} + {e1<>e2})
with name_dec: forall n1 n2:name, ({n1=n2} + {n1<>n2}).
Proof.
  { intros e1 e2.
    case e1;case e2;intros;try now((left+right)).
    - destruct (Nat.eq_dec a0 a);finish_eqdec.
      destruct (literal_eq_dec l0 l);finish_eqdec.
    - destruct (Nat.eq_dec a0 a);finish_eqdec.
      destruct (name_dec n0 n);finish_eqdec.
    - destruct (Nat.eq_dec a0 a);finish_eqdec.
      destruct (binary_operator_eq_dec b0 b);finish_eqdec.
      destruct (expression_dec e3 e);finish_eqdec.
      destruct (expression_dec e4 e0);finish_eqdec.
    - destruct (Nat.eq_dec a0 a);finish_eqdec.
      destruct (unary_operator_eq_dec u0 u);finish_eqdec.
      destruct (expression_dec e0 e);finish_eqdec. }
  { !intros.
    case n1;case n2;intros;finish_eqdec.
    - destruct (Nat.eq_dec a0 a);finish_eqdec.
      destruct (Nat.eq_dec i0 i);finish_eqdec.
    - destruct (Nat.eq_dec a0 a);finish_eqdec.
      destruct (name_dec n0 n);finish_eqdec.
      destruct (expression_dec e0 e);finish_eqdec.
    - destruct (Nat.eq_dec a0 a);finish_eqdec.
      destruct (name_dec n0 n);finish_eqdec.
      destruct (Nat.eq_dec i0 i);finish_eqdec. }
Defined.


Import STACK.
(* Is this true? *)
Axiom det_eval_expr: forall g stkptr locenv m e v v',
    Cminor.eval_expr g stkptr locenv m e v
    -> Cminor.eval_expr g stkptr locenv m e v'
    -> v = v'.

Inductive le_loads (lds: Cminor.expr): Cminor.expr -> Prop :=
  le_loads_n: le_loads lds lds
| le_loads_L: ∀ lds', le_loads lds lds' -> le_loads lds (Eload AST.Mint32 lds').

Definition lt_loads := λ l₁ l₂ , le_loads(Eload AST.Mint32 l₁) l₂.

Lemma le_loads_ese_L : forall lds₁ lds₂: Cminor.expr,
    le_loads lds₁ lds₂ -> le_loads (Eload AST.Mint32 lds₁) (Eload AST.Mint32 lds₂).
Proof.
  !intros.
  induction H.
  - constructor 1.
  - constructor 2.
    assumption.
Qed.

Lemma le_load_L_e : ∀ l₁ l₂,
    le_loads (Eload AST.Mint32 l₁) (Eload AST.Mint32 l₂) ->
    le_loads l₁ l₂.
Proof.
  intros l₁ l₂.
  revert l₁.
  induction l₂;intros;try discriminate.
  - inversion H;try now constructor.
    inversion H1.
  - inversion H;try now constructor.
    inversion H1.
  - inversion H;try now constructor.
    inversion H1.
  - inversion H;try now constructor.
    inversion H1.
  - inversion H;try now constructor.
    inversion H1;subst.
    + constructor 2.
      auto.
    + constructor 2.
      auto.
Qed.

Lemma lt_load_L_L : ∀ l₁ l₂,
    lt_loads (Eload AST.Mint32 l₁) (Eload AST.Mint32 l₂) ->
    lt_loads l₁ l₂.
Proof.
  unfold lt_loads.
  intros l₁ l₂ H.
  apply le_load_L_e;auto.
Qed.

Lemma lt_load_irrefl : ∀ l₁, ¬ lt_loads l₁ l₁.
Proof.
  intros l₁.
  unfold lt_loads.
  induction l₁;try (intro abs; inversion abs).
  - subst m.
    apply IHl₁.
    rewrite <- H1 at 2.
    constructor 1.
  - subst.
    apply le_load_L_e in abs.
    apply IHl₁.
    assumption.
Qed.

Lemma lt_load_neq : ∀ l₁ l₂, lt_loads l₁ l₂ -> l₁ ≠ l₂.
Proof.
  unfold lt_loads.
  intros l₁ l₂.
  remember (Eload AST.Mint32 l₁) as h'.
  revert h' l₁ Heqh'.
  induction l₂;intros; subst ; try now inversion H.
  intro abs.
  subst.
  assert (m=AST.Mint32). {
    inversion H;auto. }
  subst.
  apply le_load_L_e in H.
  specialize (IHl₂ (Eload AST.Mint32 l₂) l₂ eq_refl H).
  apply IHl₂;auto.
Qed.


Lemma build_loads__inj : forall i₁ i₂,
    (* translating the variabe to a Cminor load address *)
    build_loads_ i₁ = build_loads_ i₂ ->
    i₁ = i₂.
Proof.
  intros i₁.
  !induction i₁;simpl;!intros.
  - destruct i₂;auto.
    simpl in heq.
    inversion heq.
  - destruct  i₂;simpl in *;auto.
    + inversion heq.
    + inversion heq.
      rewrite (IHi₁ i₂);auto.
Qed.

Lemma build_loads__inj_lt : forall i₁ i₂,
    (i₁ < i₂)%nat ->
    forall e₁ e₂ ,
      (* translating the variabe to a Cminor load address *)
      build_loads_ i₁ = e₁ ->
      (* translating the variabe to a Cminor load address *)
      build_loads_ i₂ = e₂ ->
      lt_loads e₁ e₂.
Proof.
  intros i₁ i₂.
  unfold lt_loads.
  !intro.
  induction h_lt_i₁_i₂;simpl;!intros;subst.
  - constructor 1.
  - constructor 2.
    apply IHh_lt_i₁_i₂;auto.
Qed.

Lemma build_loads__inj_neq : forall i₁ i₂,
    i₁ ≠ i₂ ->
    forall e₁ e₂ ,
      (* translating the variabe to a Cminor load address *)
      build_loads_ i₁ = e₁ ->
      (* translating the variabe to a Cminor load address *)
      build_loads_ i₂ = e₂ ->
      e₁ ≠ e₂.
Proof.
  !intros.
  intro abs.
  subst.
  apply build_loads__inj in abs.
  contradiction.
Qed.

Lemma build_loads_inj : forall i₁ i₂ k k' ,
    (* translating the variabe to a Cminor load address *)
    build_loads k i₁ = build_loads k' i₂ ->
    k = k' ∧ Integers.Int.Z_mod_modulus i₁ = Integers.Int.Z_mod_modulus i₂.
Proof.
  unfold build_loads.
  !intros.
  inversion heq.
  split;auto.
  apply build_loads__inj;auto.
Qed.

Lemma build_loads_inj_neq1 : forall i₁ i₂ k k' e₁ e₂,
    k ≠ k' ->
    build_loads k i₁ = e₁ ->
    build_loads k' i₂ = e₂ ->
    e₁ ≠ e₂.
Proof.
  !intros.
  intro abs.
  subst.
  apply build_loads_inj in abs.
  destruct abs;contradiction.
Qed.

Lemma build_loads_inj_neq2 : forall i₁ i₂ k k' e₁ e₂,
    Integers.Int.Z_mod_modulus i₁ ≠ Integers.Int.Z_mod_modulus i₂ ->
    build_loads k i₁ = e₁ ->
    build_loads k' i₂ = e₂ ->
    e₁ ≠ e₂.
Proof.
  !intros.
  intro abs.
  subst.
  apply build_loads_inj in abs.
  destruct abs;contradiction.
Qed.


Lemma CEfetch_reside_true : forall id a x,
    CompilEnv.fetch id a = Some x -> CompilEnv.reside id a = true.
Proof.
  intros until a.
  unfold CompilEnv.fetch, CompilEnv.reside.
  induction (CompilEnv.store_of a);simpl;!intros;try discriminate.
  destruct a0.
  destruct (beq_nat id i).
  - reflexivity.
  - eapply IHs;eauto.
Qed.

Lemma CEfetch_reside_false : forall id a,
    CompilEnv.fetch id a = None -> CompilEnv.reside id a = false.
Proof.
  intros until a.
  unfold CompilEnv.fetch, CompilEnv.reside.
  induction (CompilEnv.store_of a);simpl;!intros;try reflexivity.
  destruct a0.
  destruct (beq_nat id i).
  - discriminate.
  - eapply IHs;eauto.
Qed.



Lemma frameG_In : forall a id st,
    CompilEnv.frameG id a = Some st ->
    List.In st a.
Proof.
  intro a.
  !induction a;simpl;intros;try discriminate.
  !destruct (CompilEnv.reside id a).
  - inversion H.
    left.
    reflexivity.
  - right.
    eapply IHa;eauto.
Qed.

Lemma fetches_In : forall a id st,
    CompilEnv.fetches id a = Some st ->
    List.In (id,st) a.
Proof.
  intro a.
  !induction a;simpl;!intros;try discriminate.
  !destruct a;simpl in *.
  !destruct (eq_nat_dec id i);subst;simpl in *.
  - rewrite <- beq_nat_refl in heq.
    inversion heq.
    left.
    reflexivity.
  - right.
    rewrite <- beq_nat_false_iff in hneq.
    rewrite hneq in heq.
    eapply IHa;eauto.
Qed.

Lemma fetch_In : forall a id st,
    CompilEnv.fetch id a = Some st ->
    List.In (id,st) (CompilEnv.store_of a).
Proof.
  !intros.
  unfold CompilEnv.fetch in heq_CEfetch_id_a.
  apply fetches_In.
  assumption.
Qed.


Ltac rename_hyp_incro h th :=
  match th with
  | increasing_order_fr ?x => fresh "h_incr_order_fr_" x
  | increasing_order_fr _ => fresh "h_incr_order_fr"
  | increasing_order ?x => fresh "h_incr_order_" x
  | increasing_order _ => fresh "h_incr_order"
  | increasing_orderG ?x => fresh "h_incr_orderG_" x
  | increasing_orderG _ => fresh "h_incr_orderG"
  | Forall ?P ?x => fresh "h_forall_" P "_" x
  | Forall _ ?x => fresh "h_forall_" x
  | Forall ?P _ => fresh "h_forall_" P
  | Forall _ _ => fresh "h_forall"
  | all_frm_increasing ?x => fresh "h_allincr_" x
  | all_frm_increasing _ => fresh "h_allincr"
  | all_addr_no_overflow ?x => fresh "h_bound_addr_" x
  | all_addr_no_overflow _ => fresh "h_bound_addr"
  | _ => rename_hyp5 h th
  end.
Ltac rename_hyp ::= rename_hyp_incro.


Lemma increase_order_level_of_top_ge: forall CE id s s0 s3,
    increasing_orderG CE ->
    CompilEnv.frameG id CE = Some (s, s0) ->
    CompilEnv.level_of_top CE = Some s3 ->
    (s3 >= s)%nat.
Proof.
  !intros.
  unfold increasing_orderG in *.
  !destruct CE;!intros.
  - simpl in *;try discriminate.
  - specialize (increasing_order_In _ _ _ _ h_incr_orderG_CE).
    !intro.
    rewrite Forall_forall in h_forall.
    apply Nat.lt_eq_cases.
    unfold CompilEnv.level_of in *.
    apply frameG_In in heq_CEframeG_id_CE.
    specialize (h_forall _ heq_CEframeG_id_CE).
    !destruct f.
    unfold CompilEnv.level_of_top in heq_lvloftop_CE_s3.
    simpl in *.
    !invclear heq_lvloftop_CE_s3.
    !destruct h_forall;auto.
    inject heq;auto.
Qed.


Lemma CEfetches_inj : forall id₁ id₂ (lf:localframe) δ₁ δ₂,
    increasing_order lf ->
    CompilEnv.fetches id₁ lf = Some δ₁ ->
    CompilEnv.fetches id₂ lf = Some δ₂ ->
    id₁ ≠ id₂ ->
    δ₁ ≠ δ₂.
Proof.
  intros until lf.
  !induction lf;simpl in *;!intros.
  - discriminate.
  - destruct a.
    destruct (Nat.eq_dec id₁ i);subst.
    + rewrite Nat.eqb_refl in heq.
      !invclear heq.
      assert (h:id₂ ≠ i) by auto.
      rewrite <- (Nat.eqb_neq id₂ i) in h.
      rewrite h in heq0.
      inversion h_incr_order;subst;simpl in *.
      assert (δ₂ < δ₁). {
        rewrite Forall_forall in H2.
        eapply (H2 (id₂,δ₂));eauto.
        apply fetches_In.
        assumption. }
      symmetry.
      apply Z.lt_neq.
      assumption.
    + destruct (Nat.eq_dec id₂ i).
      * subst.
        rewrite Nat.eqb_refl in heq0.
        !invclear heq0.
        assert (h:id₁ ≠ i) by auto.
        rewrite <- (Nat.eqb_neq id₁ i) in h.
        rewrite h in heq.
        inversion h_incr_order;subst;simpl in *.
        assert (δ₁ < δ₂). {
          rewrite Forall_forall in H2.
          eapply (H2 (id₁,δ₁));eauto.
          apply fetches_In.
          assumption. }
        apply Z.lt_neq.
        assumption.
      * rewrite <- (Nat.eqb_neq id₁ i) in n.
        rewrite <- (Nat.eqb_neq id₂ i) in n0.
        rewrite n,n0 in *.
        apply IHlf;auto.
        inversion h_incr_order.
        assumption.
Qed.


Lemma CEfetch_inj : forall id₁ id₂ (a:CompilEnv.frame) δ₁ δ₂,
    increasing_order_fr a ->
    CompilEnv.fetch id₁ a = Some δ₁ ->
    CompilEnv.fetch id₂ a = Some δ₂ ->
    id₁ ≠ id₂ ->
    δ₁ ≠ δ₂.
Proof.
  intros until a.
  unfold CompilEnv.fetch.
  !destruct a;simpl.
  unfold increasing_order_fr.
  simpl.
  apply CEfetches_inj.
Qed.

Lemma increasing_order_frameG: forall lvla lvlb fra frb l id ,
    Forall (ord_fst (lvlb,frb)) l ->
    CompilEnv.frameG id l = Some (lvla,fra) ->
    (lvla < lvlb)%nat.
Proof.
  !intros.
  apply frameG_In in heq_CEframeG_id_l.
  rewrite Forall_forall in h_forall_l.
  apply (h_forall_l (lvl_id, fr_id)).
  assumption.
Qed.

Lemma CEfetchG_inj : forall CE id₁ id₂,
    increasing_orderG CE ->
    all_frm_increasing CE ->
    forall  δ₁ δ₂ k₁ k₂ frm₁ frm₂,
      CompilEnv.fetchG id₁ CE = Some δ₁ ->
      CompilEnv.fetchG id₂ CE = Some δ₂ ->
      CompilEnv.frameG id₁ CE = Some (k₁, frm₁) ->
      CompilEnv.frameG id₂ CE = Some (k₂, frm₂) ->
      id₁ ≠ id₂ ->
      (k₁ <> k₂ \/ δ₁ <> δ₂).
Proof.
  intros until 0.
  !intro.
  !induction h_incr_orderG_CE;!intros;simpl in *;try discriminate.
  unfold CompilEnv.level_of in *.
  destruct (CompilEnv.fetch id₁ a) eqn:heq_fetch_id₁;
    destruct (CompilEnv.fetch id₂ a) eqn:heq_fetch_id₂;
    eq_same_clear;subst;simpl in *;try discriminate.
  - right.
    eapply CEfetch_inj;eauto.
    red in h_allincr; simpl in h_allincr.
    inversion h_allincr.
    assumption.
  - left.
    symmetry.
    apply Nat.lt_neq.
    apply CEfetch_reside_false in heq_fetch_id₂.
    apply CEfetch_reside_true in heq_fetch_id₁.
    rewrite heq_fetch_id₂,heq_fetch_id₁ in *;simpl in *.
    !invclear heq_CEframeG_id₁;simpl in *.
    eapply increasing_order_frameG;eauto.
  - left.
    apply Nat.lt_neq.
    apply CEfetch_reside_true in heq_fetch_id₂.
    apply CEfetch_reside_false in heq_fetch_id₁.
    rewrite heq_fetch_id₂,heq_fetch_id₁ in *;simpl in *.
    !invclear heq_CEframeG_id₂;simpl in *.
    eapply increasing_order_frameG;eauto.
  - apply CEfetch_reside_false in heq_fetch_id₁.
    apply CEfetch_reside_false in heq_fetch_id₂.
    rewrite heq_fetch_id₁,heq_fetch_id₂ in *.
    eapply IHh_incr_orderG_CE ;eauto.
    inversion h_allincr.
    assumption.
Qed.


Lemma minus_same_eq : forall s3 s s1,
    s ≤ s3 ->
    s1 ≤ s3 ->
    (s3 - s1)%nat = (s3 - s)%nat ->
    s = s1.
Proof.
  induction s3;intros.
  - inversion H0;inversion H;auto.
  - inversion H;inversion H0;subst.
    + reflexivity.
    + rewrite minus_diag in H1.
      apply Nat.sub_0_le in H1.
      assert (s3 < s3)%nat. {
        eapply lt_le_trans with s1;auto. }
      destruct (lt_irrefl s3);auto.
    + rewrite minus_diag in H1.
      symmetry in H1.
      apply Nat.sub_0_le in H1.
      assert (s3 < s3)%nat. {
        eapply lt_le_trans with s;auto. }
      destruct (lt_irrefl s3);auto.
    + eapply IHs3;eauto.
      setoid_rewrite <- minus_Sn_m in H1;auto.
Qed.

Lemma minus_same_neq : forall s3 s s1,
    s ≤ s3 ->
    s1 ≤ s3 ->
    s <> s1 ->
    (s3 - s1)%nat <> (s3 - s)%nat.
Proof.
  !intros.
  intro abs.
  apply minus_same_eq in abs;auto.
Qed.



Lemma transl_variable_inj : forall CE stbl a₁ a₂ id₁ id₂ k₁ k₂ δ₁ δ₂,
    (* Frame are numbered with different (increasing) numers *)
    increasing_orderG CE ->
    (* In each frame, stacks are also numbered with (increasing) numbers *)
    all_frm_increasing CE ->
    all_addr_no_overflow CE ->
    (* translating the variabe to a Cminor load address *)
    transl_variable stbl CE a₁ id₁ = OK (build_loads k₁ δ₁) ->
    (* translating the variabe to a Cminor load address *)
    transl_variable stbl CE a₂ id₂ = OK   (build_loads k₂ δ₂) ->
    id₁ <> id₂ ->
    (k₁ <> k₂ \/ δ₁<> δ₂).
Proof.
  !intros.
  unfold transl_variable in *.
  destruct (CompilEnv.fetchG id₁ CE) eqn:h₁;simpl in *;try discriminate.
  destruct (CompilEnv.fetchG id₂ CE) eqn:h₂;simpl in *;try discriminate.
  destruct (CompilEnv.frameG id₁ CE) eqn:h₁';simpl in *;try discriminate.
  destruct (CompilEnv.frameG id₂ CE) eqn:h₂';simpl in *;try discriminate.
  destruct f.
  destruct f0.
  assert (hh:=CEfetchG_inj _ _ _ h_incr_orderG_CE h_allincr_CE _ _ _ _ _ _  h₁ h₂ h₁' h₂' hneq).
  destruct (CompilEnv.level_of_top CE) eqn:hlvlofCE.
  - (* remember here refrain inversion to bizarrely unfold too much. *)
    remember (build_loads (s3 - s1) t0) as fooo.
    remember (build_loads (s3 - s) t) as fooo'.
    inversion heq_transl_variable as [heqfoo].
    inversion heq_transl_variable0 as [heqfoo'].
    clear heq_transl_variable heq_transl_variable0.
    subst.
    apply build_loads_inj in heqfoo.
    apply build_loads_inj in heqfoo'.
    !destruct heqfoo.
    !destruct heqfoo'.
    subst.
    !destruct hh.
    + left.
      eapply minus_same_neq;eauto.
      eapply increase_order_level_of_top_ge;eauto.
      eapply increase_order_level_of_top_ge;eauto.
    + repeat rewrite Integers.Int.Z_mod_modulus_eq in *.
      rewrite Coqlib.Zmod_small in *;eauto.
      subst.
      right.
      intro abs.
      subst.
      apply hneq0;reflexivity.
  - discriminate.
Qed.

Lemma transl_variable_astnum: forall stbl CE astnum id' addrof_nme,
    transl_variable stbl CE astnum id' = OK addrof_nme
    -> forall a,transl_variable stbl CE a id' = transl_variable stbl CE astnum id'.
Proof.
  !intros.
  unfold transl_variable.
  !functional inversion heq_transl_variable.
  rewrite  heq_CEfetchG_id'_CE, heq_CEframeG_id'_CE, heq_lvloftop_CE_m'.
  reflexivity.
Qed.



Lemma compute_chk_32 : forall stbl t,
    compute_chnk_of_type stbl t = OK AST.Mint32
    -> transl_type stbl t = OK (Ctypes.Tint Ctypes.I32 Ctypes.Signed Ctypes.noattr).
Proof.
  !intros.
  functional inversion heq;subst;simpl.
  - functional inversion H;simpl.
    reflexivity.
  - functional inversion H;simpl.
    reflexivity.
Qed.


Notation " x =: y" := (x = OK y) (at level 90).
Notation " x =! y" := (x = Error y) (at level 120).

Ltac simplify_do :=
  repeat progress
         (match goal with
          | H: context [do _ <- ?e ; _] , H': ?e = _ |- _ =>
            rewrite H' in H;simpl in H
          | H': ?e = _ |- context [do _ <- ?e ; _]  =>
            rewrite H';simpl
          end).


(* Well-formedness of the chained stack: store never modify the
     address of a variable. Reason: since variable addresses are
     expressions of the form ((Load(Load(...(Load 0))))+δ) with δ >= 4
     and that stores never touch the addresses 0, variables addresses
     never change. *)
Lemma wf_chain_load'2:forall g locenv stkptr chk m m' b ofs e_t_v vaddr,
    Mem.storev chk m (Values.Vptr b ofs) e_t_v = Some m'
    -> (stack_localstack_aligned locenv g m)
    -> (4 <= (Int.unsigned ofs))(*forall n, Integers.Int.repr n = ofs -> 4 <= n*)
    -> forall lvl,
        let load_id := build_loads_ lvl in
        Cminor.eval_expr g stkptr locenv m' load_id vaddr
        -> Cminor.eval_expr g stkptr locenv m load_id vaddr.
Proof.
  !intros.
  rename H1 into h_ofs_non_zero.
  simpl in *.
  subst load_id.
  generalize dependent load_id_v.
  induction lvl;!intros;simpl in *.
  - !inversion h_CM_eval_expr_load_id_v;econstructor;eauto.
  - !invclear h_CM_eval_expr_load_id_v.
    assert (h_CM_eval_expr_on_m:
              Cminor.eval_expr g stkptr locenv m (build_loads_ lvl) vaddr).
    { eapply IHlvl; eauto. }
    econstructor.
    + eassumption.
    + destruct vaddr;simpl in *;try discriminate.
      rewrite <- heq.
      symmetry.
      eapply Mem.load_store_other;eauto.
      right.
      left.
      simpl.
      transitivity 4.
      * !destruct (h_aligned_g_m _ _ _ h_CM_eval_expr_on_m).
        !invclear heq.
        !invclear heq0.
        vm_compute.
        intro abs;discriminate.
      * apply h_ofs_non_zero.
Qed.

(* Well-formedness of the chained stack: store never modify the
     address of a variable. Reason: since variable addresses are
     expressions of the form ((Load(Load(...(Load 0))))+δ) with δ >= 4
     and that stores never touch the addresses 0, variables addresses
     never change. *)
Lemma wf_chain_load'3:forall g locenv stkptr chk m m' b ofs e_t_v vaddr,
    Mem.storev chk m (Values.Vptr b ofs) e_t_v = Some m'
    -> stack_localstack_aligned locenv g m'
    -> (4 <= (Int.unsigned ofs))(*forall n, Integers.Int.repr n = ofs -> 4 <= n*)
    -> forall lvl,
        let load_id := build_loads_ lvl in
        Cminor.eval_expr g stkptr locenv m load_id vaddr
        -> Cminor.eval_expr g stkptr locenv m' load_id vaddr.
Proof.
  !intros.
  rename H1 into h_ofs_non_zero.
  simpl in *.
  subst load_id.
  generalize dependent load_id_v.
  induction lvl;!intros;simpl in *.
  - !inversion h_CM_eval_expr_load_id_v;econstructor;eauto.
  - !invclear h_CM_eval_expr_load_id_v.
    assert (h_CM_eval_expr_on_m':
              Cminor.eval_expr g stkptr locenv m' (build_loads_ lvl) vaddr).
    { eapply IHlvl; eauto. }
    econstructor.
    + eassumption.
    + destruct vaddr;simpl in *;try discriminate.
      rewrite <- heq.
      eapply Mem.load_store_other;eauto.
      simpl.
      right. left.
      transitivity 4.
      * !destruct (h_aligned_g_m' _ _ _ h_CM_eval_expr_on_m').
        !invclear heq.
        !invclear heq0.
        vm_compute.
        intro abs;discriminate.
      * apply h_ofs_non_zero.
Qed.


Lemma wf_chain_load'':forall g locenv stkptr chk m m' b ofs e_t_v vaddr,
    Mem.storev chk m (Values.Vptr b ofs) e_t_v = Some m'
    -> (stack_localstack_aligned locenv g m)
    -> (stack_localstack_aligned locenv g m')
    -> (4 <= (Int.unsigned ofs))(*forall n, Integers.Int.repr n = ofs -> 4 <= n*)
    -> forall lvl,
        let load_id := build_loads_ lvl in
        Cminor.eval_expr g stkptr locenv m' load_id vaddr
        <-> Cminor.eval_expr g stkptr locenv m load_id vaddr.
Proof.
  intros g locenv stkptr chk m m' b ofs e_t_v vaddr H H0 H1 H2 lvl load_id.
  split;intro .
  - eapply wf_chain_load'2 ;eauto.
  - eapply wf_chain_load'3 ;eauto.
Qed.

(* Well-formedness of the chained stack: store never modify the
     address of a variable. Reason: since variable addresses are
     expressions of the form ((Load(Load(...(Load 0))))+δ) with δ >= 4
     and that stores never touch the addresses 0, variables addresses
     never change. *)
Lemma wf_chain_load':forall g locenv stkptr chk m m' b ofs e_t_v vaddr,
    Mem.storev chk m (Values.Vptr b ofs) e_t_v = Some m'
    -> (stack_localstack_aligned locenv g m')
    -> (4 <= (Int.unsigned ofs))(*forall n, Integers.Int.repr n = ofs -> 4 <= n*)
    -> forall lvl δ_lvl,
        let load_id := build_loads lvl δ_lvl in
        Cminor.eval_expr g stkptr locenv m load_id vaddr
        -> Cminor.eval_expr g stkptr locenv m' load_id vaddr.
Proof.
  !intros.
  rename H1 into h_ofs_non_zero.
  simpl in *.
  unfold build_loads in *.
  !invclear h_CM_eval_expr_load_id_load_id_v.
  econstructor;eauto.
  Focus 2.
  { inversion h_CM_eval_expr_v2;econstructor;eauto. }
  Unfocus.
  eapply wf_chain_load'3;eauto.
Qed.

(* Well-formedness of the chained stack: store never modify the
     address of a variable. Reason: since variable addresses are
     expressions of the form ((Load(Load(...(Load 0))))+δ) with δ >= 4
     and that stores never touch the addresses 0, variables addresses
     never change. *)
Lemma wf_chain_load'_2:forall g locenv stkptr chk m m' b ofs e_t_v vaddr,
    Mem.storev chk m (Values.Vptr b ofs) e_t_v = Some m'
    -> (stack_localstack_aligned locenv g m)
    -> (4 <= (Int.unsigned ofs))(*forall n, Integers.Int.repr n = ofs -> 4 <= n*)
    -> forall lvl δ_lvl,
        let load_id := build_loads lvl δ_lvl in
        Cminor.eval_expr g stkptr locenv m' load_id vaddr
        -> Cminor.eval_expr g stkptr locenv m load_id vaddr.
Proof.
  !intros.
  rename H1 into h_ofs_non_zero.
  simpl in *.
  unfold build_loads in *.
  !invclear h_CM_eval_expr_load_id_load_id_v.
  econstructor;eauto.
  Focus 2.
  { inversion h_CM_eval_expr_v2;econstructor;eauto. }
  Unfocus.
  eapply wf_chain_load'2;eauto.
Qed.

(* Well-formedness of the chained stack: store never modify the
     address of a variable. Reason: since variable addresses are
     expressions of the form ((Load(Load(...(Load 0))))+δ) with δ >= 4
     and that stores never touch the addresses 0, variables addresses
     never change. *)
Lemma wf_chain_load_var:
  forall stbl CE g locenv stkptr astnum chk m m' b ofs e_t_v id load_id vaddr,
    Mem.storev chk m (Values.Vptr b ofs) e_t_v = Some m'
    -> (stack_localstack_aligned locenv g m')
    -> (4 <= (Int.unsigned ofs))(*forall n, Integers.Int.repr n = ofs -> 4 <= n*)
    -> transl_variable stbl CE astnum id =: load_id
    -> Cminor.eval_expr g stkptr locenv m load_id vaddr
    -> Cminor.eval_expr g stkptr locenv m' load_id vaddr.
Proof.
  !intros.
  rename H1 into h_ofs_non_zero.
  simpl in *.
  !functional inversion heq_transl_variable;subst;clear heq_transl_variable.
  rename m'0 into max_lvl.
  set (δ_lvl:=(max_lvl - lvl_id)%nat) in *.
  eapply wf_chain_load';eauto.
Qed.

(* Well-formedness of the chained stack: store never modify the
     address of a variable. Reason: since variable addresses are
     expressions of the form ((Load(Load(...(Load 0))))+δ) with δ >= 4
     and that stores never touch the addresses 0, variables addresses
     never change. *)
Lemma wf_chain_load_var':
  forall stbl CE g locenv stkptr astnum chk m m' b ofs e_t_v id load_id vaddr,
    Mem.storev chk m (Values.Vptr b ofs) e_t_v = Some m'
    -> (stack_localstack_aligned locenv g m)
    -> (4 <= (Int.unsigned ofs))(*forall n, Integers.Int.repr n = ofs -> 4 <= n*)
    -> transl_variable stbl CE astnum id =: load_id
    -> Cminor.eval_expr g stkptr locenv m' load_id vaddr
    -> Cminor.eval_expr g stkptr locenv m load_id vaddr.
Proof.
  !intros.
  rename H1 into h_ofs_non_zero.
  simpl in *.
  !functional inversion heq_transl_variable;subst;clear heq_transl_variable.
  rename m'0 into max_lvl.
  set (δ_lvl:=(max_lvl - lvl_id)%nat) in *.
  eapply wf_chain_load'_2;eauto.
Qed.


(* INVARIANT OF STORE/STOREV: if we do not touch on addresses zero
     of blocks, chaining variables all poitn to zero ofsets. *)
Lemma wf_chain_load_aligned:forall g locenv chk m m' b ofs e_t_v,
    Mem.storev chk m (Values.Vptr b ofs) e_t_v = Some m'
    -> (4 <= (Int.unsigned ofs))
    -> stack_localstack_aligned locenv g m
    -> stack_localstack_aligned locenv g m'.
Proof.
  unfold stack_localstack_aligned at 2.
  !intros.
  revert g locenv chk m m' b ofs e_t_v heq_storev_e_t_v_m' H0 h_aligned_g_m b0 v h_CM_eval_expr_v.
  destruct δ_lvl;simpl;!intros.
  - edestruct (h_aligned_g_m b0 O v).
    + simpl.
      constructor.
      !inversion h_CM_eval_expr_v.
      assumption.
    + eauto.
  - !inversion h_CM_eval_expr_v.
    generalize h_CM_eval_expr_vaddr.
    !intro.
    eapply wf_chain_load'2 in h_CM_eval_expr_vaddr;eauto.
    generalize h_CM_eval_expr_vaddr.
    !intro.
    eapply h_aligned_g_m in h_CM_eval_expr_vaddr1.
    destruct h_CM_eval_expr_vaddr1.
    subst.
    assert (heq_ld_m:Mem.loadv AST.Mint32 m (Values.Vptr x Int.zero) = Some v). {
      simpl.
      erewrite <- (Mem.load_store_other);eauto. }
    red in h_aligned_g_m.
    eapply (h_aligned_g_m _ (S δ_lvl)).
    simpl.
    econstructor;eauto.
Qed.




Lemma assignment_preserve_stack_match :
  forall stbl CE g locenv stkptr s m a chk id id_t e_v e_t_v idaddr s' m' ,
    increasing_orderG CE ->
    all_frm_increasing CE ->
    (* translating the variabe to a Cminor load address *)
    transl_variable stbl CE a id = OK id_t ->
    (* translating the value, we may need a overflow hypothesis on e_v/e_t_v *)
    transl_value e_v e_t_v ->
    (* Evaluating var address in Cminor *)
    Cminor.eval_expr g stkptr locenv m id_t idaddr ->
    (* Size of variable in Cminor memorry *)
    compute_chnk stbl (E_Identifier a id) = OK chk ->
    (* the two storing operation maintain match_env *)
    storeUpdate stbl s (E_Identifier a id) e_v (Normal s') ->
    Mem.storev chk m idaddr e_t_v = Some m' ->
    match_env stbl s CE stkptr locenv g m ->
    stack_match stbl s' CE stkptr locenv g m'.
Proof.
  intros until m'. (* if !intros. then id-t get renamed int id_t0? *)
  !intros.
  !inversion h_match_env.
  (* Getting rid of erronous cases *)
  !functional inversion heq_transl_variable.
  rename m'0 into lvl_max.
  (* done *)
  (* getting rid of erroneous storev parameter *)
  rewrite <- cm_storev_ok in heq_storev_e_t_v_m'.
  !functional inversion heq_storev_e_t_v_m';subst.
  set (loads_id:=(build_loads (lvl_max - lvl_id) δ_id)) in *.
  rewrite cm_storev_ok in *.
  (* done *)
  assert (h_ofs_nonzero:4 <= Int.unsigned ofs). {
    eapply eval_build_loads_offset_non_null_var;eauto. }

  unfold stack_match.
  !intros other_nme other_v addr_other load_addr_other type_other cm_typ_other.

  (* id can already be evaluated in s *)
  destruct (h_stk_cmpl_s_CE _ _ _ heq_transl_variable)
    as [v_id_prev h_eval_name_id_val_prev].
  set (nme:=(E_Identifier a id)) in *.
  (* done *)
  (* Getting rid of erronous cases *)
(* xxx *)




(* xxxxx *)
  !functional inversion heq_transl_name.
  subst.
  rename id0 into other_id.
  set (other_nme:=(E_Identifier astnum other_id)) in *.
  (* done *)
  (* other_nme can already be evaluated in s *)
  destruct (h_stk_cmpl_s_CE _ _ _ heq_transl_variable0)
    as [v_other_id_prev h_eval_name_other_id_val_prev].
  (* done *)
  destruct (h_stk_mtch_s_m
              _ _ _ _ _ _ h_eval_name_other_id_val_prev
              heq_type_of_name heq_transl_name heq_transl_type heq_make_load)
    as [ cm_v [tr_val_v_other cm_eval_m_v_other]].
  assert (heq_ftch_astnum:symboltable.fetch_exp_type astnum stbl = Some type_other). {
    simpl in heq_type_of_name.
    destruct (symboltable.fetch_exp_type astnum stbl);try discriminate.
    !inversion heq_type_of_name.
    reflexivity. }
  assert (h_tr_exp_other:
            transl_expr stbl CE (E_Name 1%nat (E_Identifier astnum other_id))
                        =: load_addr_other). {
    simpl.
    simpl in heq_type_of_name.
    rewrite heq_ftch_astnum.
    rewrite heq_transl_variable0.
    !invclear heq_type_of_name.
    unfold value_at_addr.
    rewrite heq_transl_type;simpl.
    assumption. }
  !destruct (Nat.eq_dec id other_id).
  - subst nme. (* same variable ==> result is the value just stored *)
    subst other_nme.
    subst other_id.
    simpl in heq_type_of_name.
    assert (chk = AST.Mint32). {
      rewrite compute_chnk_ok in heq_compute_chnk.
      !functional inversion heq_compute_chnk;subst;auto. }
    simpl in heq_compute_chnk.
    unfold compute_chnk_astnum in heq_compute_chnk.
(*     unfold compute_chnk_id in heq_compute_chnk. *)
    rewrite heq_ftch_astnum in heq_type_of_name.
(*     rewrite heq_type_of_name in heq_compute_chnk. *)
    lazy beta iota delta [bind] in heq_compute_chnk.
    rewrite (transl_variable_astnum _ _ _ _ _ heq_transl_variable0 a) in *.
    rewrite heq_transl_variable0 in heq_transl_variable.
    !invclear heq_transl_variable.
    !assert (e_v = other_v). { eapply storeUpdate_id_ok_same_eval_name ;eauto. }
                               subst other_v.
    exists e_t_v;split;auto.
    !functional inversion heq_make_load;subst.
    eapply eval_Eload with (Values.Vptr b ofs).
    * { eapply wf_chain_load_var with (1:= heq_storev_e_t_v_m');eauto.
        - eapply wf_chain_load_aligned;eauto. }
    * simpl.
      (* Should be ok by well typedness of the chained stack wrt
           stbl (see hyp on compute_chk). *)
      (* assert (chunk = AST.chunk_of_type t). {
           rewrite cmtype_chk with (1:=heq_transl_type) (2:=heq_opttype) (3:=heq0).
           reflexivity. } *)
      assert (chunk = AST.Mint32). {
        !functional inversion heq_transl_type;subst;simpl in h_access_mode_cm_typ_other.
        - inversion h_access_mode_cm_typ_other;auto.
        - inversion h_access_mode_cm_typ_other;auto. }
      subst.
      erewrite (Mem.load_store_same _ _ _ _ _ _ heq_store_e_t_v_m') .
      { destruct e_t_v;auto;destruct e_v;simpl in *;try discriminate;
        now inversion heq_transl_value_e_v_e_t_v. }

  - (* loading a different variable id' than the one stored id.
         2 steps: first prove that the addresses of id' and id did
         not change (the translated expressions did not change + the
         chained stack did not change either), and thus remain
         different, then conclude that the value stored in id' did
         not change. *)
    !assert (chk = AST.Mint32). {
      rewrite function_utils.compute_chnk_ok in heq_compute_chnk.
      functional inversion heq_compute_chnk; reflexivity. }

    assert (v_other_id_prev = other_v). {
      eapply storeUpdate_id_ok_others_eval_name ;eauto. }
    subst.
    exists cm_v.
    split;auto.
    assert (h_aligned_m' : stack_localstack_aligned locenv g m'). {
      eapply wf_chain_load_aligned;eauto. }
    !functional inversion heq_make_load;subst.
    !inversion cm_eval_m_v_other.
    generalize (wf_chain_load_var _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
                                  heq_storev_e_t_v_m' h_aligned_m'
                                  h_ofs_nonzero heq_transl_variable0
                                  h_CM_eval_expr_addr_other_addr_other_v).
    !intro.
    econstructor.
    + eassumption.
    + destruct addr_other_v; try discriminate;simpl in *.
      clear h_tr_exp_other.
      erewrite Mem.load_store_other;[now eassumption| now eassumption | ].
      subst nme other_nme.
      unfold compute_chnk_astnum in heq_compute_chnk.
      destruct (symboltable.fetch_exp_type a stbl) eqn:heq_fetchvartyp;try discriminate.
      assert (heq_tr_type_id:transl_type stbl t
                             = OK (Ctypes.Tint Ctypes.I32 Ctypes.Signed Ctypes.noattr)). {
        apply compute_chk_32.
        unfold compute_chnk_astnum in heq_compute_chnk.
        assumption. }
      unfold stack_separate in h_separate_CE_m.
      { eapply h_separate_CE_m with (nme:=(E_Identifier a id))
                                      (nme':=(E_Identifier astnum other_id))
                                      (k₂ := b0) (k₁:=b);
        clear h_separate_CE_m;simpl;try eassumption;auto.
        - rewrite heq_fetchvartyp.
          reflexivity.
        - intro abs.
          inversion abs;subst;try discriminate.
          elim hneq;reflexivity. }
Qed.


Lemma storev_inv : forall nme_chk m nme_t_addr e_t_v m',
    Mem.storev nme_chk m nme_t_addr e_t_v = Some m'
    -> exists b ofs, nme_t_addr = Values.Vptr b ofs.
Proof.
  !intros.
  destruct nme_t_addr; try discriminate.
  eauto.
Qed.

Lemma transl_name_OK_inv : forall stbl CE nme nme_t,
    transl_name stbl CE nme = OK nme_t
    -> exists astnum id, (transl_variable stbl CE astnum id =  OK nme_t
                          /\ nme = E_Identifier astnum id).
Proof.
  !intros stbl CE nme nme_t H.
  functional inversion H.
  eauto.
Qed.

Lemma assignment_preserve_stack_complete :
  forall stbl CE g locenv stkptr s m a chk id id_t e_v e_t_v idaddr s' m' ,
    (* translating the variabe to a Cminor load address *)
    transl_variable stbl CE a id = OK id_t ->
    (* translating the value, we may need a overflow hypothesis on e_v/e_t_v *)
    transl_value e_v e_t_v ->
    (* Evaluating var address in Cminor *)
    Cminor.eval_expr g stkptr locenv m id_t idaddr ->
    (* Size of variable in Cminor memorry *)
    compute_chnk stbl (E_Identifier a id) = OK chk ->
    (* the two storing operation maintain match_env *)
    storeUpdate stbl s (E_Identifier a id) e_v (Normal s') ->
    Mem.storev chk m idaddr e_t_v = Some m' ->
    stack_complete stbl s CE ->
    stack_complete stbl s' CE.
Proof.
  !intros.
  red.
  !intros.
  !destruct (Nat.eq_dec nme id).
  - subst.
    exists e_v.
    constructor.
    eapply storeUpdate_id_ok_same;eauto.
  - red in h_stk_cmpl_s_CE.
    destruct h_stk_cmpl_s_CE with (1:=heq_transl_variable0).
    exists x.
    constructor.
    !invclear H.
    erewrite <- storeUpdate_id_ok_others.
    + eassumption.
    + eassumption.
    + apply not_eq_sym;assumption.
Qed.

Lemma assignment_preserve_stack_separate :
  forall stbl CE g locenv stkptr s m a chk id id_t e_v e_t_v idaddr s' m' ,
    (* translating the variabe to a Cminor load address *)
    transl_variable stbl CE a id = OK id_t ->
    (* translating the value, we may need a overflow hypothesis on e_v/e_t_v *)
    transl_value e_v e_t_v ->
    (* Evaluating var address in Cminor *)
    Cminor.eval_expr g stkptr locenv m id_t idaddr ->
    (* Size of variable in Cminor memorry *)
    compute_chnk stbl (E_Identifier a id) = OK chk ->
    (* the two storing operation maintain match_env *)
    storeUpdate stbl s (E_Identifier a id) e_v (Normal s') ->
    Mem.storev chk m idaddr e_t_v = Some m' ->
    match_env stbl s CE stkptr locenv g m ->
    stack_separate stbl CE stkptr locenv g m'.
Proof.
  !intros.
  red.
  !intros.
  !destruct h_match_env.
  decompose [ex] (storev_inv _ _ _ _ _ heq_storev_e_t_v_m');subst.
  !functional inversion heq_transl_name0;subst.
  generalize heq_transl_name.
  intro h_transl_name_remember.
  functional inversion h_transl_name_remember.
  eapply wf_chain_load_var' with (m:=m) in h_CM_eval_expr_nme_t.
  - eapply wf_chain_load_var' with (m:=m) in h_CM_eval_expr_nme'_t.
    + eapply h_separate_CE_m with (1:=heq_type_of_name);eauto.
    + eassumption.
    + assumption.
    + eapply eval_build_loads_offset_non_null_var with (4:=h_CM_eval_expr_id_t_id_t_v)
      ;eauto.
    + simpl in heq_transl_name0.
      eauto.
  - eassumption.
  - assumption.
  - eapply eval_build_loads_offset_non_null_var with (4:=h_CM_eval_expr_id_t_id_t_v)
    ;eauto.
  - eauto.
Qed.

Lemma assignment_preserve_stack_no_null_offset :
  forall stbl CE g locenv stkptr s m a chk id id_t e_v e_t_v idaddr s' m' ,
    (* translating the variabe to a Cminor load address *)
    transl_variable stbl CE a id = OK id_t ->
    (* translating the value, we may need a overflow hypothesis on e_v/e_t_v *)
    transl_value e_v e_t_v ->
    (* Evaluating var address in Cminor *)
    Cminor.eval_expr g stkptr locenv m id_t idaddr ->
    (* Size of variable in Cminor memorry *)
    compute_chnk stbl (E_Identifier a id) = OK chk ->
    (* the two storing operation maintain match_env *)
    storeUpdate stbl s (E_Identifier a id) e_v (Normal s') ->
    Mem.storev chk m idaddr e_t_v = Some m' ->
    match_env stbl s CE stkptr locenv g m ->
    stack_no_null_offset stbl CE.
Proof.
  !intros.
  destruct h_match_env.
  assumption.
Qed.

Lemma assignment_preserve_stack_safe :
  forall stbl CE g locenv stkptr s m a chk id id_t e_v e_t_v idaddr s' m' ,
    (* translating the variabe to a Cminor load address *)
    transl_variable stbl CE a id = OK id_t ->
    (* translating the value, we may need a overflow hypothesis on e_v/e_t_v *)
    transl_value e_v e_t_v ->
    (* if e_v is an int, then it is not overflowing (we are not trying
       to add an overflowing value to the environment). *)
    (forall n, e_v = Int n -> do_overflow_check n (Normal (Int n))) ->
    (* Evaluating var address in Cminor *)
    Cminor.eval_expr g stkptr locenv m id_t idaddr ->
    (* Size of variable in Cminor memorry *)
    compute_chnk stbl (E_Identifier a id) = OK chk ->
    (* the two storing operation maintain match_env *)
    storeUpdate stbl s (E_Identifier a id) e_v (Normal s') ->
    Mem.storev chk m idaddr e_t_v = Some m' ->
    match_env stbl s CE stkptr locenv g m ->
    safe_stack s'.
Proof.
  !intros.
  match goal with H: context C [do_overflow_check] |- _ => rename H into h_overf_e_v end.
  !destruct h_match_env.
  !intros.
  red.
  !intros.
  !destruct (Nat.eq_dec id0 id).
  - subst.
    apply h_overf_e_v.
    erewrite storeUpdate_id_ok_same in heq_SfetchG_id0_s';eauto.
    inversion heq_SfetchG_id0_s'.
    reflexivity.
  - red in h_safe_stack_s.
    apply h_safe_stack_s with (id:=id0);eauto.
    erewrite storeUpdate_id_ok_others;eauto.
Qed.


Lemma assignment_preserve_loads_offset_non_null:
  forall stbl s CE spb ofs locenv' g m x x0 nme_t nme_chk nme_t_addr e_t_v m',
    match_env stbl s CE (Values.Vptr spb ofs) locenv' g m ->
    transl_name stbl CE (E_Identifier x x0) =: nme_t ->
    Cminor.eval_expr g (Values.Vptr spb ofs) locenv' m nme_t nme_t_addr ->
    Mem.storev nme_chk m nme_t_addr e_t_v = Some m' ->
    stack_localstack_aligned locenv' g m'.
Proof.
  !intros.
  decomp (storev_inv _ _ _ _ _ heq_storev_e_t_v_m') ;subst.
  functional inversion heq_transl_name.
  eapply wf_chain_load_aligned;eauto.
  eapply eval_build_loads_offset_non_null_var;eauto.
Qed.

Lemma assignment_preserve_stack_freeable:
  forall stbl s CE spb ofs locenv' g m x x0 nme_t nme_chk nme_t_addr e_t_v m',
    match_env stbl s CE (Values.Vptr spb ofs) locenv' g m ->
    transl_name stbl CE (E_Identifier x x0) =: nme_t ->
    Cminor.eval_expr g (Values.Vptr spb ofs) locenv' m nme_t nme_t_addr ->
    Mem.storev nme_chk m nme_t_addr e_t_v = Some m' ->
    stack_freeable stbl CE (Values.Vptr spb ofs) g locenv' m'.
Proof.
  !intros.
  red.
  !intros.
  destruct nme_t_v;simpl in * ; try discriminate.
  eapply Mem.store_valid_access_1.
  - eassumption.
  - eapply (me_stack_freeable h_match_env);eauto.
    eapply wf_chain_load_var';eauto.
    eapply eval_build_loads_offset_non_null_var
      with (4:=h_CM_eval_expr_nme_t_nme_t_v);eauto.
Qed.


Hint Resolve
     assignment_preserve_stack_match assignment_preserve_stack_complete
     assignment_preserve_stack_separate assignment_preserve_loads_offset_non_null
     assignment_preserve_stack_no_null_offset assignment_preserve_stack_safe
     assignment_preserve_stack_freeable.

(* [make_load] does not fail on transl_type a translated variable coming
   from stbl *)
Lemma make_load_no_fail: forall stbl t nme_t x2,
    transl_type stbl t =: x2 ->
    exists load_addr_nme, make_load nme_t x2 =: load_addr_nme.
Proof.
  !intros.
  unfold make_load.
  destruct t;simpl in * ; simpl; try discriminate;eauto.
  - inversion heq_transl_type. subst.
    simpl.
    unfold make_load.
    simpl.
    eauto.
  - inversion heq_transl_type. subst.
    simpl.
    unfold make_load.
    simpl.
    eauto.
Qed.

(** Consequence of chained structure: build_load returns always a pointeur *)
Lemma build_loads_Vptr : forall lvl_nme g spb ofs locenv m δ_nme nme_t nme_t_v,
    stack_localstack_aligned locenv g m ->
    build_loads lvl_nme δ_nme = nme_t ->
    Cminor.eval_expr g (Values.Vptr spb ofs) locenv m nme_t nme_t_v ->
    ∃ nme_block nme_ofst, nme_t_v = (Values.Vptr nme_block nme_ofst).
Proof.
  intro.
  !destruct lvl_nme;!intros.
  - unfold build_loads in *.
    simpl in *.
    subst.
    !invclear h_CM_eval_expr_nme_t_nme_t_v.
    !invclear h_CM_eval_expr_v1;simpl in *.
    !invclear h_eval_constant.
    !invclear h_CM_eval_expr_v2;simpl in *.
    !invclear h_eval_constant.
    inversion heq.
    eauto.
  - subst.
    !invclear h_CM_eval_expr_nme_t_nme_t_v.
    destruct (h_aligned_g_m (Values.Vptr spb ofs) (S lvl_nme) v1);auto.
    subst.
    simpl in *.
    !invclear h_CM_eval_expr_v2.
    simpl in *.
    !invclear h_eval_constant.
    !invclear heq.
    eauto.
Qed.

(** Consequence of chained structure: a variable is always translated into a pointer. *)
Lemma transl_variable_Vptr : forall g spb ofs locenv m stbl CE astnm nme nme_t nme_t_v,
    stack_localstack_aligned locenv g m ->
    transl_variable stbl CE astnm nme =: nme_t ->
    Cminor.eval_expr g (Values.Vptr spb ofs) locenv m nme_t nme_t_v ->
    ∃ nme_block nme_ofst, nme_t_v = (Values.Vptr nme_block nme_ofst).
Proof.
  !intros.
  !functional inversion heq_transl_variable.
  eapply build_loads_Vptr;eauto.
Qed.


Ltac rename_transl_exprlist h th :=
  match th with
  | transl_exprlist _ _ ?x = Error _ => fresh "h_trans_exprl_Err_" x
  | transl_exprlist _ _ _ = Error _ => fresh "h_trans_exprl_Err"
  | transl_exprlist _ _ ?x = Some ?y => fresh "h_trans_exprl_" x "_" y
  | transl_exprlist _ _ ?x = Some _ => fresh "h_trans_exprl_" x
  | transl_exprlist _ _ _ = _ => fresh "h_trans_exprl"

  | transl_paramexprlist _ _ ?x _ = Error _ => fresh "h_trans_prmexprl_Err_" x
  | transl_paramexprlist _ _ _ _ = Error _ => fresh "h_trans_prmexprl_Err"
  | transl_paramexprlist _ _ ?x _ = Some ?y => fresh "h_trans_prmexprl_" x "_" y
  | transl_paramexprlist _ _ ?x _ = Some _ => fresh "h_trans_prmexprl_" x
  | transl_paramexprlist _ _ _ _ = _ => fresh "h_trans_prmexprl"

  | eval_exprlist _ _ _ _ ?x Error _ => fresh "h_eval_exprlist_Err_" x
  | eval_exprlist _ _ _ _ _ Error _ => fresh "h_eval_exprlist_Err"
  | eval_exprlist _ _ _ _ ?x (Some ?y) => fresh "h_eval_exprlist_" x "_" y
  | eval_exprlist _ _ _ _ ?x (Some _) => fresh "h_eval_exprlist_" x
  | eval_exprlist _ _ _ _ _ _ => fresh "h_eval_exprlist"
  | _ => rename_hyp_incro h th
  end.
Ltac rename_hyp ::= rename_transl_exprlist.


(* Property linking spark args expr list , spark args value
           list , Cminor args expr list and Cminor args value list. We
           need to talk a bout expressions because Out and InOut
           parameters are translated into names (and not expressions)
           in order to be able to have there cminor address. Once the
           prelude of the function is executed, all variables are in
           the stack as standard variables. *)
(*
Section is_copy.
  Variables (stbl : symboltable) (CE : compilenv)   (g : genv) (sp : Values.val) (locenv : env) (m : mem) (s : stack).

  (* FIXME: copy_in ne doit pas prendre une liste de value, mais les calculer à
     la volée, car on ne peut pas faire autrement pour spécifier le Out. *)
  (** [is_copy_in le lprms lv_t] means that in the current environment, lev_t
      correspond to the values that should be stored in the local variables
      of a function having lprm as parameter list. That is: the value of the
      argument when In, its address otherwise (with the correct value at the
      address when In_Out).  *)

  Inductive is_copy_in: list expression -> list parameter_specification -> store -> list Values.val -> Prop :=
  | Is_copy_in_nil: forall sto, is_copy_in nil nil sto nil
  | Is_copy_in_In: ∀ e le prm lprm v sto sto' v_t lv_t,
      parameter_mode prm = In ->
      eval_expr stbl s e (Normal v) ->
      transl_value v v_t ->
      is_copy_in le lprm (store_of sto) lv_t ->
      push sto (parameter_name prm) v = sto' ->
      is_copy_in (e::le) (prm::lprm) (store_of sto') (v_t::lv_t)
  | Is_copy_in_In_Out: ∀ ast_num nme le prm lprm v nme_t addr sto v_t lv_t,
      parameter_mode prm = In_Out ->
      eval_name stbl s nme (Normal v) ->
      transl_value v v_t ->
      transl_name stbl CE nme = OK nme_t ->
      Cminor.eval_expr g sp locenv m nme_t addr -> (* v_t is the value at address addr *)
      Mem.loadv AST.Mint32 m addr = Some v_t ->
      is_copy_in le lprm sto lv_t ->
      is_copy_in (E_Name ast_num nme ::le) (prm::lprm) ((parameter_name prm , v)::sto) (addr::lv_t).
(* TODO: Out parameters *)

End is_copy.
*)

Lemma transl_stmt_normal_OK : forall stbl (stm:statement) s s',
    eval_stmt stbl s stm (Normal s') ->
    forall CE (stm':Cminor.stmt),
      invariant_compile CE stbl ->
      transl_stmt stbl CE stm = (OK stm') ->
      forall spb ofs f locenv g m,
        match_env stbl s CE (Values.Vptr spb ofs) locenv g m ->
        exists tr locenv' m',
          Cminor.exec_stmt g f (Values.Vptr spb ofs) locenv m stm' tr locenv' m' Out_normal
          /\  match_env stbl s' CE (Values.Vptr spb ofs) locenv' g m'.
(*with transl_fcall_normal_OK : forall ge m fd vargs t m' vres,
    ...
    eval_funcall ge m fd vargs t m' vres.*)
Proof.
  intros until 1.
  remember (Normal s') as norms'.
  revert dependent s'.
  rename_all_hyps.
  Opaque transl_stmt.
  induction h_eval_stmt;simpl in *;intros ; rename_all_hyps ; eq_same_clear;
  try (rewrite <- transl_stmt_ok in heq_transl_stmt_stm';
        !functional inversion heq_transl_stmt_stm';
        subst;
        try rewrite -> transl_stmt_ok in *); eq_same_clear.
  - eexists. eexists. eexists.
    split.
    + try now constructor.
    + assumption.
  (* assignment no range constraint *)
  - rename x into nme.
    rename st into stbl.
    rename_all_hyps.
    exists Events.E0.
    exists locenv.
    decomp (transl_name_OK_inv _ _ _ _ heq_transl_name);subst.
    !! (edestruct (me_stack_complete h_match_env);eauto).
    decomp (transl_expr_ok _ _ _ _ heq_tr_expr_e _ _ _ _ _ _
                           h_eval_expr_e_e_v h_match_env).
    (* transl_type never fails *)
    assert (hex:exists nme_type_t, transl_type stbl nme_type =: nme_type_t).
    { simpl in *.
      assert (type_of_name stbl (E_Identifier x x0) = OK nme_type).
      { simpl.
        rewrite heq_fetch_exp_type.
        reflexivity. }
      rename_all_hyps.
      eapply (ci_stbl_var_types_ok h_inv_comp_CE_stbl);eauto. }
    !destruct hex.
    (* make_load does not fail on a translated variable coming from CE *)
    !destruct (make_load_no_fail _ _ nme_t _ heq_transl_type).
    (* Cminor.eval_expr does not fail on a translated variable (invariant?) *)
    assert (hex: exists vaddr,
               Cminor.eval_expr g (Values.Vptr spb ofs) locenv m nme_t vaddr).
    { !destruct h_match_env.
      unfold stack_match in h_stk_mtch_s_m.
      generalize (h_stk_mtch_s_m (E_Identifier x x0) x1 nme_t x3 nme_type x2).
      intro h.
      !destruct h;auto.
      (* correction of type_of_name wrt to stbl_exp_type *)
      - simpl in heq_fetch_exp_type.
        simpl.
        rewrite heq_fetch_exp_type.
        reflexivity.
      - decomp h_and.
        unfold make_load in heq_make_load.
        destruct (Ctypes.access_mode x2) eqn:h;simpl in *;try discriminate.
        !invclear heq_make_load.
        !inversion h_CM_eval_expr_x3_x4.
        exists nme_t_v.
        assumption. }
    (* A translated variable always results in a Vptr. *)
    !destruct hex.
    specialize transl_variable_Vptr with
    (1:=(me_stack_localstack_aligned h_match_env))
      (2:=heq_transl_variable)
      (3:= h_CM_eval_expr_nme_t_nme_t_v).
    intro hex.
    decomp hex.
    (* Adresses of translated variables are always writable (invariant?) *)
    !assert (Mem.valid_access m nme_chk x4 (Int.unsigned x5) Writable). {
      apply Mem.valid_access_implies with (p1:=Freeable).
      - !destruct h_match_env.
        eapply h_freeable_CE_m;eauto.
        subst.
        assumption.
      - constructor 2. }
    eapply Mem.valid_access_store in h_valid_access_x4.
    destruct h_valid_access_x4.
    exists x6.
    !assert (exec_stmt g f (Values.Vptr spb ofs) locenv m (Sstore nme_chk nme_t e_t)
                      Events.E0 locenv x6 Out_normal). {
      econstructor;eauto.
      subst.
      simpl.
      eassumption. }
    split.
    * assumption.
    * !invclear h_exec_stmt.
      assert (e_t_v0 = e_t_v).
      { eapply det_eval_expr;eauto. }
      subst e_t_v0.
      constructor;eauto 7.
      eapply assignment_preserve_stack_safe;eauto.
      !intros.
      subst.
      eapply eval_expr_overf;eauto.
  (* Assignment with satisifed range constraint (Range l u) *)
  - rename x into nme.
    rename st into stbl.
    rename_all_hyps.
    exists Events.E0.
    exists locenv.
    decomp (transl_name_OK_inv _ _ _ _ heq_transl_name);subst.
    !! (edestruct (me_stack_complete h_match_env);eauto).
    decomp (transl_expr_ok _ _ _ _ heq_tr_expr_e _ _ _ _ _ _ h_eval_expr_e h_match_env).
      (* transl_type never fails *)
      assert (hex:exists nme_type_t, transl_type stbl nme_type =: nme_type_t).
      { simpl in *.
        assert (type_of_name stbl (E_Identifier x x0) = OK nme_type).
        { simpl.
          rewrite heq_fetch_exp_type.
          reflexivity. }
        eapply (ci_stbl_var_types_ok h_inv_comp_CE_stbl);eauto. }
      !destruct hex.
      (* make_load does not fail on a translated variable coming from CE *)
      !destruct (make_load_no_fail stbl nme_type nme_t x2 heq_transl_type).
      (* Cminor.eval_expr does not fail on a translated variable (invariant?) *)
      assert (hex: exists vaddr,
                 Cminor.eval_expr g (Values.Vptr spb ofs) locenv m nme_t vaddr).
      { !destruct h_match_env.
        unfold stack_match in h_stk_mtch_s_m.
        generalize (h_stk_mtch_s_m (E_Identifier x x0) x1 nme_t x3 nme_type x2).
        intro h.
        !destruct h;auto.
        - simpl in *.
          rewrite heq_fetch_exp_type.
          reflexivity.
        - decomp h_and.
          unfold make_load in heq_make_load.
          destruct (Ctypes.access_mode x2) eqn:h;simpl in *;try discriminate.
          !invclear heq_make_load.
          !inversion h_CM_eval_expr_x3_x4.
          exists nme_t_v.
          assumption. }
      (* A translated variable always results in a Vptr. *)
      !destruct hex.
      specialize transl_variable_Vptr with
        (1:=(me_stack_localstack_aligned h_match_env))
          (2:=heq_transl_variable)
          (3:= h_CM_eval_expr_nme_t_nme_t_v).
      intro hex.
      decomp hex.
      (* Adresses of translated variables are always writable (invariant?) *)
      !assert (Mem.valid_access m nme_chk x4 (Int.unsigned x5) Writable). {
        apply Mem.valid_access_implies with (p1:=Freeable).
        - !destruct h_match_env.
          eapply h_freeable_CE_m;eauto.
          subst.
          assumption.
        - constructor 2. }
      eapply Mem.valid_access_store in h_valid_access_x4.
      destruct h_valid_access_x4.
      exists x6.
      !assert (exec_stmt g f (Values.Vptr spb ofs) locenv m (Sstore nme_chk nme_t e_t)
                         Events.E0 locenv x6 Out_normal). {
        econstructor;eauto.
        subst.
        simpl.
        eassumption. }
      split.
      * assumption.
      * !invclear h_exec_stmt.
        assert (e_t_v0 = e_t_v). {
          eapply det_eval_expr;eauto. }
        subst e_t_v0.
        constructor;eauto 7.
        eapply assignment_preserve_stack_safe;eauto.
        !intros.
        !invclear heq.
        eapply eval_expr_overf;eauto.
  (* If statement --> true *)
  - rename x1 into b_then.
    rename x2 into b_else.
    rename_all_hyps.
    + decomp (transl_expr_ok _ _ _ e_t heq_tr_expr_e locenv g m _ _
                             (Values.Vptr spb ofs) h_eval_expr_e h_match_env).
      decomp (IHh_eval_stmt s' eq_refl CE b_then h_inv_comp_CE_st heq_transl_stmt_stmt_b_then spb ofs f
                            locenv g m h_match_env).
      exists x.
      exists x0.
      exists x1.
      decomp (transl_expr_ok _ _ _ _ heq_tr_expr_e locenv g m s _ (Values.Vptr spb ofs) h_eval_expr_e h_match_env).
      assert (exec_stmt g f (Values.Vptr spb ofs) locenv m
                        (Sifthenelse (Ebinop (Ocmp Cne) e_t (Econst (Ointconst Int.zero)))
                                     b_then b_else) x x0 x1 Out_normal).
      { econstructor;eauto.
        * { econstructor;eauto.
            - econstructor;eauto.
              simpl.
              reflexivity.
            - simpl.
              reflexivity. }
        * inversion  heq_transl_value_e_t_v0.
          subst.
          econstructor.
        * rewrite  Int.eq_false;eauto.
          apply Int.one_not_zero. }
      split.
      * assumption.
      * assumption.
  (* If statement --> false *)
  - rename x1 into b_then.
    rename x2 into b_else.
    rename_all_hyps.
    + decomp (transl_expr_ok _ _ _ e_t heq_tr_expr_e locenv g m _ _
                             (Values.Vptr spb ofs) h_eval_expr_e h_match_env).
      decomp (IHh_eval_stmt s' eq_refl CE b_else h_inv_comp_CE_st heq_transl_stmt_stmt_b_else spb ofs f
                            locenv g m h_match_env).
      exists x.
      exists x0.
      exists x1.
      decomp (transl_expr_ok _ _ _ _ heq_tr_expr_e locenv g m s _ (Values.Vptr spb ofs) h_eval_expr_e h_match_env).
      assert (exec_stmt g f (Values.Vptr spb ofs) locenv m
                        (Sifthenelse (Ebinop (Ocmp Cne) e_t (Econst (Ointconst Int.zero)))
                                     b_then b_else) x x0 x1 Out_normal).
      { econstructor;eauto.
        * { econstructor;eauto.
            - econstructor;eauto.
              simpl.
              reflexivity.
            - simpl.
              reflexivity. }
        * inversion  heq_transl_value_e_t_v0.
          subst.
          econstructor.
        * rewrite Int.eq_true.
          simpl.
          assumption. }
      split.
      * assumption.
      * assumption.
  (* Procedure call *)
  - subst x1.
    subst current_lvl.
    rename f0 into func.
    rename locals_section into f1'_l.
    rename params_section into f1'_p.
    specialize (IHh_eval_stmt ((n, f1'_l ++ f1'_p) :: s3) eq_refl).
    rename H1 into h_cut_until.
    rewrite <- transl_stmt_ok in heq_transl_stmt_stm'.
    !functional inversion heq_transl_stmt_stm';subst;eq_same_clear; clear heq_transl_stmt_stm'.
    rename s1 into suffix_s .
    rename s3 into suffix_s'.
    rename y0 into lvl_p.
    rename x1 into args_t.
    rename x0 into p_sign.
    subst x3.
    subst current_lvl.
    rename n into pb_lvl.
    eq_same_clear.
    up_type.

    Notation "'PROC' pb ~~[ st , CE ]~~> stm" :=
      (transl_stmt st CE (procedure_statements pb) =: stm) (at level 90).

    Notation "[ g , f , spb , ofs ] < m , locenv , stm > ===> < m' , locenv' , tr > " :=
      (exec_stmt g f (Values.Vptr spb ofs) locenv m stm tr locenv' m' Out_normal)
        (at level 90,
         format  "[ g , f , spb , ofs ] '/ ' < m , locenv , stm > '/ '  ===>  '/ ' < m' , locenv' , tr > ").


    (* IDEA: prove a similar lemma simultaneaously on funcall, with a different invariant. *)

    (* On Cminor side, the function to be called is an expression that
       evaluates correctly to something. Consequence of Well-typedness+invariant? *)
    assert (h_ex_paddr:exists paddr,
               Cminor.eval_expr g (Values.Vptr spb ofs) locenv m
                                (Econst (Oaddrsymbol (transl_procid p) (Int.repr 0))) paddr).
    { admit. }
    destruct h_ex_paddr as [paddr hpaddr].
    (* The value obtained for the function to call is indeed the
    address of a function. Well-typedness+invariant? *)
    assert (h:exists fction , Globalenvs.Genv.find_funct g paddr = Some fction).
    { admit. }
    destruct h as [fction hfction].
    (* translate_procedure should not fail on pb since compilation of the
       whole should not have fail (we have to state that, how?). Moreover
       the currently proved property holds for the translation of pb. *)
    assert ((do p_t <- transl_procedure st CE lvl_p pb ;
              match List.hd_error p_t with
                Some (_,@AST.Gfun _ _ f) => OK f
              | _ => Error (msg "procedure not translated (??)")
              end) = OK fction).
    { admit. }
    destruct (transl_procedure st CE lvl_p pb) eqn:h;try discriminate.
    autorename h.
    simpl in H.
    destruct (hd_error c) as [ [v [ ft | vn ]] |] eqn:h;simpl in H; autorename h; autorename H;try discriminate.

    inversion heq0;subst ft;clear heq0.
    (* Core of the proof, link the different phase of execution with
       the pieces of code built by transl_procedure (in h_tr_proc). *)
    (* ideally functional inversion here would be great but it fails, bug(s) reported *)
    (* rewrite transl_procedure_ok in h_tr_proc. *)
    (* !functional inversion h_tr_proc. ;subst;eq_same_clear; clear heq_transl_stmt_stm'. *)

    destruct pb eqn:heq_pb;eq_same_clear.
    rewrite <- ?heq_pb in h_fetch_proc_p. (* to re-fold pb where it didn't reduce. *)
    simpl in *.
    rename heq_transl_proc_pb_c into h_tr_proc.
    Tactic Notation "!destruct" constr(h) "!eqn:?" := (!!(destruct h eqn:?)).
    Tactic Notation "!destruct" constr(h) "!eqn:" ident(id) :=
      (!!(destruct h eqn:id; revert id));intro id.
    repeat match type of h_tr_proc with
           | (bind2 ?x _) = _  => destruct x as  [ [CE' stcksize]|] eqn:heq_bldCE; simpl in h_tr_proc; try discriminate
           | context [ ?x <=? ?y ]  => let heqq := fresh "heq" in destruct (Z.leb x y) eqn:heqq; try discriminate
           | (bind ?y ?x) = _ =>
             let heqq := fresh "heq" in !destruct y !eqn:heqq; [ 
                 match type of heqq with
                 | transl_stmt _ _ _ = OK ?x => rename x into s_pbdy                   
                 | init_locals _ _ _ = OK ?x => rename x into s_locvarinit
                 | store_params _ _ _ = OK ?x => rename x into s_parms
                 | copy_out_params _ _ _ = OK ?x => rename x into s_copyout
                 | transl_lparameter_specification_to_procsig _ _ _ = OK ?x => rename x into p_sig
                 | _ => idtac
                 end
                 ; autorename heqq; simpl in h_tr_proc
               | discriminate]
           end.
    up_type.
    inversion h_tr_proc;clear h_tr_proc.
    subst c.
    simpl in heq.
    !invclear heq.
    match type of hfction with
    | (_ = Some (AST.Internal ?f)) => set (the_proc := f) in *
    end.
    up_type.
    unfold build_compilenv in heq_bldCE.
    pose (CE1 := match lvl_p with
                            | 0%nat => (nil, 0)
                            | S _ => ((0%nat, 0)::nil , 4)
                            end ).
    fold CE1 in heq_bldCE.
     pose (CE2 :=  ).


    (* more or less what functional inversion would have produced in one step *)
    (* CE' is the new CE built from CE and the called procedure parameters and local variables *)
    specialize (IHh_eval_stmt CE').
    rewrite heq_transl_stmt_procedure_statements_s_pbdy in IHh_eval_stmt.
    specialize (IHh_eval_stmt s_pbdy).
    assert (h_inv_CE':invariant_compile CE' st).
    { admit. (* TODO as a lemma. *) }
    specialize (IHh_eval_stmt h_inv_CE' eq_refl).

    destruct (Mem.alloc m 0 stcksize) as [m_alloc_p spb_alloc_p] eqn:h_alloc .
    specialize (IHh_eval_stmt spb_alloc_p Int.zero the_proc).
    
    eexists.
    eexists.
    eexists.
    split.
    + eapply exec_Scall;try now (try eassumption;simpl;reflexivity).
      * admit. (* property of eval_exprlist *)
      * simpl.
        unfold transl_procsig in heq_transl_procsig_p.
        unfold symboltable.fetch_proc in h_fetch_proc_p.
        rewrite h_fetch_proc_p in heq_transl_procsig_p.
        destruct (transl_lparameter_specification_to_procsig st pb_lvl (language.procedure_parameter_profile pb)) eqn:h;try discriminate.
        simpl in heq_transl_procsig_p.
        inversion heq_transl_procsig_p. subst s0 pb_lvl.
        rewrite heq_pb in h.
        simpl in h.
        rewrite h in heq2.
        inversion heq2;auto.
      * 
        
        eapply eval_funcall_internal;cbn.
        -- eassumption.
        -- shelve.
        -- econstructor. (* Sseq init_part (rest) *)
           ++ admit. (* lemma over intialization *)
           ++ econstructor. (* rest ) Sseq bdy copyout *)
              ** destruct (IHh_eval_stmt ?e1 g ?m1) as [tr' [locenv'' [m'' [IHh_eval_stmt_1 IHh_eval_stmt_2]]]].
                 --- admit. (* lemma on match_env on pushing a new function env. *)
                 --- admit. (* should be "eapply IHh_eval_stmt_1." when eexists are done after destruct (IHh_eval_stmt...) *)
                eapply 
           ++ admit.
        -- admit.
        -- admit.
    + admit.



    assert (h_match_env_f1: ∃  (spb : Values.block) (ofs : int)(locenv : env) (g : genv) (m : mem),
                               ).
    { admit. (* Property of eval_decl, to prove simultanously with the current leamm? *) }


    assert (h_match_env_f1: ∃  (spb : Values.block) (ofs : int)(locenv : env) (g : genv) (m : mem),
                               match_env st (f1 :: suffix_s) CE' (Values.Vptr spb ofs) locenv g m).
    { admit. (* Property of eval_decl, to prove simultanously with the current leamm? *) }
    destruct h_match_env_f1 as [spb' [ofs' [locenv' [g' [m' h_match_env_f1]]]]].
    specialize (IHh_eval_stmt _ _ func _ _ _ h_match_env_f1). (* func really? *)
    destruct IHh_eval_stmt as [tr' [locenv'' [m'' [IHh_eval_stmt_1 IHh_eval_stmt_2]]]].
    up_type.
    assert (h_copy_out: ∃ (spb : Values.block) (ofs : int)(locenv : env) (g : genv) (m : mem),).
    (* FAUX: on n'a pas encore exécuté copy_out. *)
    exists tr'.
    exists locenv''.
    exists m''.
    split.
    + constructor.

    (* TODO: deal with lvl_p = 0. *)

(* *************************** SCRATCH  ************************** *)


(* *************************** END SCRATCH ************************ *)

    admit.
  (* Sequence *)
  - simpl in *.
    decomp (IHh_eval_stmt1 s1 eq_refl CE _ h_inv_comp_CE_st
                           heq1 spb ofs f  locenv g m h_match_env).
    decomp (IHh_eval_stmt2 s' eq_refl CE _ h_inv_comp_CE_st
                           heq0 spb ofs f _ _ _ h_match_env0).
    exists (Events.Eapp x1 x4).
    exists x5.
    exists x6.
    split.
    + econstructor;eauto.
    + assumption.
  
  unshelve.
Admitted.
