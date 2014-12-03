
Require Import LibHypsNaming.
Require Import Errors.
Require Import spark2Cminor.
Require Import Cminor.
Require Ctypes.
Require Import symboltable.
Require Import semantics.
Require Import function_utils.

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

Import Symbol_Table_Module.
Open Scope error_monad_scope.

Open Scope Z_scope.

(* Auxiliary lemmas, should go in Compcert? *)
Lemma repr_inj:
  forall v1 v2,
    Integers.Int.min_signed <= v1 <= Integers.Int.max_signed ->
    Integers.Int.min_signed <= v2 <= Integers.Int.max_signed ->
    Integers.Int.repr v1 = Integers.Int.repr v2 ->
    v1 = v2.
Proof.
  intros v1 v2 hinbound1 hinboun2.
  !intros.
  assert (h: Integers.Int.signed(Integers.Int.repr v1)
             = Integers.Int.signed(Integers.Int.repr v2)).
  { rewrite heq. reflexivity. }
  rewrite Integers.Int.signed_repr in h;auto.
  rewrite Integers.Int.signed_repr in h;auto.
Qed.

Lemma repr_inj_neq:
  forall v1 v2,
    Integers.Int.min_signed <= v1 <= Integers.Int.max_signed ->
    Integers.Int.min_signed <= v2 <= Integers.Int.max_signed ->
    v1 <> v2 -> 
    Integers.Int.repr v1 <> Integers.Int.repr v2.
Proof.
  intros v1 v2 hinbound1 hinboun2 hneq.
  intro abs.
  apply repr_inj in abs;auto.
Qed.

(* These should be part of std lib maybe.  *)

Lemma Zneq_bool_false: forall x y : Z, x = y -> Zneq_bool x y = false.
Proof.
  !intros.
  subst.
  unfold Zneq_bool.
  rewrite Fcore_Zaux.Zcompare_Eq;auto.
Qed.
  
Lemma Zneq_bool_true: forall x y : Z, x <> y -> Zneq_bool x y = true.
Proof.
  intros x y hneq.
  apply Z.lt_gt_cases in hneq.
  !destruct hneq.
  - unfold Zneq_bool.
    rewrite Fcore_Zaux.Zcompare_Lt;auto.
  - unfold Zneq_bool.
    rewrite Fcore_Zaux.Zcompare_Gt;auto.
Qed.

(* TODO: replace this y the real typing function *)
Definition type_of_name (stbl:symboltable) (nme:name): res type :=
  match nme with
    | E_Identifier astnum id => fetch_var_type id stbl
    | E_Indexed_Component astnum x0 x1 => Error (msg "type_of_name: arrays not treated yet")
    | E_Selected_Component astnum x0 x1 => Error (msg "transl_basetype: records not treated yet")
  end.




(** Hypothesis renaming stuff *)
Ltac rename_hyp1 th :=
  match th with
    | fetch_var_type _ _ = Error _ => fresh "heq_fetch_var_type_ERR"
    | fetch_var_type _ _ = _ => fresh "heq_fetch_var_type"
    | fetch_exp_type _ _ = Error _ => fresh "heq_fetch_exp_type_ERR"
    | symboltable.fetch_exp_type _ _ = _ => fresh "heq_fetch_exp_type"
    | symboltable.fetch_exp_type _ _ = Error _ => fresh "heq_fetch_exp_type_ERR"
    | fetch_exp_type _ _ = _ => fresh "heq_fetch_exp_type" (* symboltable.fetch_exp_type *)
    | eval_expr _ _ _ (Run_Time_Error _) => fresh "h_eval_expr_RE"
    | eval_expr _ _ _ _ => fresh "h_eval_expr"
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
    | eval_literal _ (Run_Time_Error _)  => fresh "h_eval_literal_RE"
    | eval_literal _ _  => fresh "h_eval_literal"
    | eval_stmt _ _ _ (Run_Time_Error _) => fresh "h_eval_stmt_RE"
    | eval_stmt _ _ _ _ => fresh "h_eval_stmt"
    | transl_stmt _ _ _ = Error _ => fresh "heq_transl_stmt_ERR"
    | transl_stmt _ _ _ = _ => fresh "heq_transl_stmt"
    | Cminor.eval_expr _ _ _ _ _ _ => fresh "h_CM_eval_expr"
    | transl_value _ = Error _ => fresh "heq_transl_value_RE"
    | transl_value _ = _ => fresh "heq_transl_value"
    | transl_variable _ _ _ _ = Error _ => fresh "heq_transl_variable_RE"
    | transl_variable _ _ _ _ = _ => fresh "heq_transl_variable"
    | fetch_exp_type _ _ = Some _ => fresh "heq_fetch_exp_type"
    | fetch_exp_type _ _ = None => fresh "heq_fetch_exp_type_none"
    | transl_type _ _ = Error _ => fresh "heq_transl_type_RE"
    | transl_type _ _ = _ => fresh "heq_transl_type"
    | transl_basetype _ _ = Error _ => fresh "heq_transl_basetype_RE"
    | transl_basetype _ _ = _ => fresh "heq_transl_basetype"
    | make_load _ _ = Error _ => fresh "heq_make_load_RE"
    | make_load _ _ = _ => fresh "heq_make_load"
    | STACK.fetchG _ _ = Some _ => fresh "heq_SfetchG"
    | STACK.fetchG _ _ = None => fresh "heq_SfetchG_none"
    | storeUpdate _ _ _ _ (Run_Time_Error _) => fresh "h_storeupdate_RTE"
    | storeUpdate _ _ _ _ _ => fresh "h_storeupdate"
    | do_run_time_check_on_binop _ _ _ (Run_Time_Error _) =>  fresh "h_do_rtc_binop_RE"
    | do_run_time_check_on_binop _ _ _ _ =>  fresh "h_do_rtc_binop"
    | do_run_time_check_on_unop _ _ (Run_Time_Error _) =>  fresh "h_do_rtc_unop_RE"
    | do_run_time_check_on_unop _ _ _ =>  fresh "h_do_rtc_unop"
    | reduce_type _ _ _ = Error _ => fresh "heq_reduce_type_RE"
    | reduce_type _ _ _ = _  => fresh "heq_reduce_type"
    | concrete_type_of_value _ = Error _ => fresh "concrete_type_of_value_RE"
    | concrete_type_of_value _ = _ => fresh "concrete_type_of_value"
    | in_bound _ _ _ => fresh "h_inbound"
    | do_division_check _ _ (Run_Time_Error _) => fresh "h_do_division_check_RTE"
    | do_division_check _ _ _ => fresh "h_do_division_check"
    (* TODO: remove when we remove type_of_name by the real one. *)
    | type_of_name _ _ = Error _ => fresh "heq_type_of_name_ERR"
    | type_of_name _ _ = _ => fresh "heq_type_of_name"
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

Ltac remove_refl :=
  repeat
    match goal with
      | H: ?e = ?e |- _ => clear H
    end.

Ltac eq_same e :=
  match goal with
    | H: e = OK ?t1 , H': e = OK ?t2 |- _ => rewrite H in H'; !inversion H'
  end;
  match goal with
      | H: ?e = ?e |- _ => clear H
  end.


Ltac eq_same_clear :=
  repeat progress
    (repeat remove_refl;
     repeat match goal with
              | H: ?A = _ , H': ?A = _ |- _ => rewrite H in H'; !inversion H'
              | H: OK ?A = OK ?B |- _ => !inversion H
              | H: Some ?A = Some ?B |- _ => !inversion H
              | H: ?A <> ?A |- _ => elim H;reflexivity
            end).



(* Transform hypothesis of the form do_range_check into disequalities. *)
Ltac inv_rtc :=
  repeat
    progress
    (try match goal with
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
           let h1 := fresh "h_le"in
           let h2 := fresh "h_le"in
           destruct H as [h1 h2 ]
         end; auto 2).


(** In this section we prove that basic operators of SPARK behave,
    when they don't raise a runtime error, like Compcert ones. *)

Lemma not_ok: forall v1 v0 x,
                     transl_value v1 = OK x ->
                     Math.unary_not v1 = Some v0 ->
                     transl_value v0 = OK (Values.Val.notbool x).
Proof.
  !intros.
  !destruct v1;try discriminate;simpl in *.
  !invclear heq.
  destruct n;simpl
  ;inversion heq_transl_value
  ; subst.
  simpl.
  fold Integers.Int.mone.
  repeat apply f_equal.
  - rewrite Integers.Int.eq_false.
    + reflexivity.
    + apply Integers.Int.one_not_zero.
  - simpl.
    rewrite Integers.Int.eq_true.
    reflexivity.
Qed.


Lemma and_ok: forall v1 v2 v0 x x0,
                     transl_value v1 = OK x ->
                     transl_value v2 = OK x0 ->
                     Math.and v1 v2 = Some v0 ->
                     transl_value v0 = OK (Values.Val.and x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
  !invclear heq.
  destruct n;destruct n0;simpl
  ;inversion heq_transl_value
  ;inversion heq_transl_value0
  ; reflexivity.
Qed.

Lemma or_ok: forall v1 v2 v0 x x0,
                     transl_value v1 = OK x ->
                     transl_value v2 = OK x0 ->
                     Math.or v1 v2 = Some v0 ->
                     transl_value v0 = OK (Values.Val.or x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
  !invclear heq.
  destruct n;destruct n0;simpl
  ;inversion heq_transl_value
  ;inversion heq_transl_value0
  ; reflexivity.
Qed.


Definition check_overflow_value (v:value) :=
  match v with
    | Undefined => True
    | Int n => do_overflow_check n (Normal (Int n))
    | Bool n => True
    | ArrayV a => True(* FIXME *)
    | RecordV r => True (* FIXME *)
  end.

Ltac rename_hyp2 th :=
  match th with
    | check_overflow_value _ => fresh "h_check_overf"
    | _ => rename_hyp1 th
  end.

Ltac rename_hyp ::= rename_hyp2.


Lemma eq_ok: forall v1 v2 v0 x x0,
               check_overflow_value v1 -> 
               check_overflow_value v2 -> 
               transl_value v1 = OK x ->
               transl_value v2 = OK x0 ->
               Math.eq v1 v2 = Some v0 ->
               transl_value v0 = OK (Values.Val.cmp Integers.Ceq x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
  !invclear heq.
  eq_same_clear.
  !destruct (Z.eq_dec n n0).
  - subst.
    rewrite Fcore_Zaux.Zeq_bool_true;auto.
    unfold Values.Val.cmp.
    simpl.
    rewrite Integers.Int.eq_true.
    reflexivity.
  - rewrite Fcore_Zaux.Zeq_bool_false;auto.
    unfold Values.Val.cmp.
    simpl.
    rewrite Integers.Int.eq_false.
    + reflexivity.
    + apply repr_inj_neq.
      * inv_rtc.
      * inv_rtc.
      * assumption.
Qed.


Lemma neq_ok: forall v1 v2 v0 x x0,
               check_overflow_value v1 -> 
               check_overflow_value v2 -> 
               transl_value v1 = OK x ->
               transl_value v2 = OK x0 ->
               Math.ne v1 v2 = Some v0 ->
               transl_value v0 = OK (Values.Val.cmp Integers.Cne x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
  !invclear heq.
  eq_same_clear.
  !destruct (Z.eq_dec n n0).
  - subst.
    rewrite Zneq_bool_false;auto.
    unfold Values.Val.cmp.
    simpl.
    rewrite Integers.Int.eq_true.
    reflexivity.
  - rewrite Zneq_bool_true;auto.
    unfold Values.Val.cmp.
    simpl.
    rewrite Integers.Int.eq_false.
    + reflexivity.
    + apply repr_inj_neq.
      * inv_rtc.
      * inv_rtc.
      * assumption.
Qed.

Lemma le_ok: forall v1 v2 v0 x x0,
               check_overflow_value v1 -> 
               check_overflow_value v2 -> 
               transl_value v1 = OK x ->
               transl_value v2 = OK x0 ->
               Math.le v1 v2 = Some v0 ->
               transl_value v0 = OK (Values.Val.cmp Integers.Cle x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
  !invclear heq.
  eq_same_clear.
  !destruct (Z.le_decidable n n0).
  - rewrite Fcore_Zaux.Zle_bool_true;auto.
    unfold Values.Val.cmp.
    simpl.
    unfold Integers.Int.lt.
    rewrite Coqlib.zlt_false.
    + reflexivity.
    + rewrite Integers.Int.signed_repr;inv_rtc.
      rewrite Integers.Int.signed_repr;inv_rtc.
      auto with zarith.
  - { rewrite Fcore_Zaux.Zle_bool_false.
      - unfold Values.Val.cmp.
        simpl.
        unfold Integers.Int.lt.
        rewrite Coqlib.zlt_true.
        + reflexivity.
        + rewrite Integers.Int.signed_repr;inv_rtc.
          rewrite Integers.Int.signed_repr;inv_rtc.
          auto with zarith.
      - apply Z.nle_gt.
        assumption. }
Qed.


Lemma ge_ok: forall v1 v2 v0 x x0,
               check_overflow_value v1 -> 
               check_overflow_value v2 -> 
               transl_value v1 = OK x ->
               transl_value v2 = OK x0 ->
               Math.ge v1 v2 = Some v0 ->
               transl_value v0 = OK (Values.Val.cmp Integers.Cge x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
  !invclear heq.
  eq_same_clear.
  rewrite Z.geb_leb.
  !destruct (Z.le_decidable n0 n).
  - rewrite Fcore_Zaux.Zle_bool_true;auto.
    unfold Values.Val.cmp.
    simpl.
    unfold Integers.Int.lt.
    rewrite Coqlib.zlt_false.
    + reflexivity.
    + rewrite Integers.Int.signed_repr;inv_rtc.
      rewrite Integers.Int.signed_repr;inv_rtc.
      auto with zarith.
  - { rewrite Fcore_Zaux.Zle_bool_false.
      - unfold Values.Val.cmp.
        simpl.
        unfold Integers.Int.lt.
        rewrite Coqlib.zlt_true.
        + reflexivity.
        + rewrite Integers.Int.signed_repr;inv_rtc.
          rewrite Integers.Int.signed_repr;inv_rtc.
          auto with zarith.
      - apply Z.nle_gt.
        assumption. }
Qed.

Lemma lt_ok: forall v1 v2 v0 x x0,
               check_overflow_value v1 -> 
               check_overflow_value v2 -> 
               transl_value v1 = OK x ->
               transl_value v2 = OK x0 ->
               Math.lt v1 v2 = Some v0 ->
               transl_value v0 = OK (Values.Val.cmp Integers.Clt x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
  !invclear heq.
  eq_same_clear.
  simpl.
  !destruct (Z.lt_decidable n n0).
  - rewrite Fcore_Zaux.Zlt_bool_true;auto.
    unfold Values.Val.cmp.
    simpl.
    unfold Integers.Int.lt.
    rewrite Coqlib.zlt_true.
    + reflexivity.
    + rewrite Integers.Int.signed_repr;inv_rtc.
      rewrite Integers.Int.signed_repr;inv_rtc.
  - { rewrite Fcore_Zaux.Zlt_bool_false.
      - unfold Values.Val.cmp.
        simpl.
        unfold Integers.Int.lt.
        rewrite Coqlib.zlt_false.
        + reflexivity.
        + rewrite Integers.Int.signed_repr;inv_rtc.
          rewrite Integers.Int.signed_repr;inv_rtc.
      - auto with zarith. }
Qed.


Lemma gt_ok: forall v1 v2 v0 x x0,
               check_overflow_value v1 -> 
               check_overflow_value v2 -> 
               transl_value v1 = OK x ->
               transl_value v2 = OK x0 ->
               Math.gt v1 v2 = Some v0 ->
               transl_value v0 = OK (Values.Val.cmp Integers.Cgt x x0).
Proof.
  !intros.
  !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in *.
  !invclear heq.
  eq_same_clear.
  rewrite Z.gtb_ltb.
  !destruct (Z.lt_decidable n0 n).
  - rewrite Fcore_Zaux.Zlt_bool_true;auto.
    unfold Values.Val.cmp.
    simpl.
    unfold Integers.Int.lt.
    rewrite Coqlib.zlt_true.
    + reflexivity.
    + rewrite Integers.Int.signed_repr;inv_rtc.
      rewrite Integers.Int.signed_repr;inv_rtc.
  - { rewrite Fcore_Zaux.Zlt_bool_false.
      - unfold Values.Val.cmp.
        simpl.
        unfold Integers.Int.lt.
        rewrite Coqlib.zlt_false.
        + reflexivity.
        + rewrite Integers.Int.signed_repr;inv_rtc.
          rewrite Integers.Int.signed_repr;inv_rtc.
      - auto with zarith. }
Qed.


(* strangely this one does not need overflow preconditions *)
Lemma unaryneg_ok :
  forall n v1 v,
    transl_value v1 = OK n ->
    Math.unary_operation Unary_Minus v1 = Some v ->
    transl_value v = OK (Values.Val.negint n).
Proof.
  !intros.
  simpl in *.
  destruct v1;simpl in *;try discriminate.
  eq_same_clear.
  simpl.
  rewrite Integers.Int.neg_repr.
  reflexivity.
Qed.

Lemma add_ok :
  forall v v1 v2 n1 n2,
    check_overflow_value v1 -> 
    check_overflow_value v2 -> 
    do_run_time_check_on_binop Plus v1 v2 (Normal v) ->
    transl_value v1 = OK n1 ->
    transl_value v2 = OK n2 ->
    Math.binary_operation Plus v1 v2 = Some v ->
    transl_value v = OK (Values.Val.add n1 n2).
Proof.
  !intros.
  simpl in *.
  !destruct v1;simpl in *;try discriminate.
  destruct v2;simpl in *; try discriminate.
  repeat progress (eq_same_clear;simpl in * ).
  apply f_equal.
  !invclear h_do_rtc_binop;simpl in *; eq_same_clear. 
  clear H.
  inv_rtc.
  rewrite min_signed_ok, max_signed_ok in *.
  rewrite Integers.Int.add_signed.
  rewrite !Integers.Int.signed_repr;auto 2.
Qed.

Lemma sub_ok :
  forall v v1 v2 n1 n2,
    check_overflow_value v1 -> 
    check_overflow_value v2 -> 
    do_run_time_check_on_binop Minus v1 v2 (Normal v) ->
    transl_value v1 = OK n1 ->
    transl_value v2 = OK n2 ->
    Math.binary_operation Minus v1 v2 = Some v ->
    transl_value v = OK (Values.Val.sub n1 n2).
Proof.
  !intros.
  simpl in *.
  !destruct v1;simpl in *;try discriminate.
  destruct v2;simpl in *; try discriminate.
  repeat progress (eq_same_clear;simpl in * ).
  apply f_equal.
  !invclear h_do_rtc_binop;simpl in *; eq_same_clear.
  clear H.
  inv_rtc.
  rewrite min_signed_ok, max_signed_ok in *.
  rewrite Integers.Int.sub_signed.
  rewrite !Integers.Int.signed_repr;auto 2.
Qed.

Lemma mult_ok :
  forall v v1 v2 n1 n2,
    check_overflow_value v1 -> 
    check_overflow_value v2 -> 
    do_run_time_check_on_binop Multiply v1 v2 (Normal v) ->
    transl_value v1 = OK n1 ->
    transl_value v2 = OK n2 ->
    Math.binary_operation Multiply v1 v2 = Some v ->
    transl_value v = OK (Values.Val.mul n1 n2).
Proof.
  !intros.
  simpl in *.
  !destruct v1;simpl in *;try discriminate.
  destruct v2;simpl in *; try discriminate.
  repeat progress (eq_same_clear;simpl in * ).
  apply f_equal.
  !invclear h_do_rtc_binop;simpl in *; eq_same_clear.
  clear H.
  inv_rtc.
  rewrite min_signed_ok, max_signed_ok in *.
  rewrite Integers.Int.mul_signed.
  rewrite !Integers.Int.signed_repr;auto 2.
Qed.

(** Compcert division return None if dividend is min_int and divisor
    in -1, because the result would be max_int +1. In Spark's
    semantics the division is performed but then it fails overflow
    checks. *)
(*  How to compile this? probably by performing a check before. *)
Lemma div_ok :
  forall v v1 v2 n n1 n2,
    check_overflow_value v1 -> 
    check_overflow_value v2 -> 
    do_run_time_check_on_binop Divide v1 v2 (Normal v) ->
    transl_value v1 = OK n1 ->
    transl_value v2 = OK n2 ->
    transl_value v = OK n ->
    Math.binary_operation Divide v1 v2 = Some v ->
    Values.Val.divs n1 n2 = Some n.
Proof.
  !intros.
  simpl in *.
  !destruct v1;simpl in *;try discriminate.
  !destruct v2;simpl in *; try discriminate.
  rename n0 into v1.
  rename n3 into v2.
  repeat progress (eq_same_clear;simpl in * ).
  !invclear h_do_rtc_binop;simpl in *; eq_same_clear.
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
      vm_compute in h_le0.
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



Lemma binary_operator_ok:
  forall op (n n1 n2 : Values.val) (v v1 v2 : value),
    check_overflow_value v1 ->
    check_overflow_value v2 ->
    do_run_time_check_on_binop op v1 v2 (Normal v) ->
    transl_value v1 = OK n1 ->
    transl_value v2 = OK n2 ->
    transl_value v = OK n ->
    Math.binary_operation op v1 v2 = Some v ->
    forall m, Cminor.eval_binop (transl_binop op) n1 n2 m = Some n.
Proof.
  !intros.
  destruct op.
  - erewrite (and_ok v1 v2 v n1 n2) in heq_transl_value;eq_same_clear;eauto.
  - erewrite (or_ok v1 v2 v n1 n2) in heq_transl_value;eq_same_clear;eauto.
  - erewrite (eq_ok v1 v2 v n1 n2) in heq_transl_value;eq_same_clear;eauto.
  - erewrite (neq_ok v1 v2 v n1 n2) in heq_transl_value;eq_same_clear;eauto.
  - erewrite (lt_ok v1 v2 v n1 n2) in heq_transl_value;eq_same_clear;eauto.
  - erewrite (le_ok v1 v2 v n1 n2) in heq_transl_value;eq_same_clear;eauto.
  - erewrite (gt_ok v1 v2 v n1 n2) in heq_transl_value;eq_same_clear;eauto.
  - erewrite (ge_ok v1 v2 v n1 n2) in heq_transl_value;eq_same_clear;eauto.
  - erewrite (add_ok v v1 v2 n1 n2) in heq_transl_value;eq_same_clear;eauto.
  - erewrite (sub_ok v v1 v2 n1 n2) in heq_transl_value;eq_same_clear;eauto.
  - erewrite (mult_ok v v1 v2 n1 n2) in heq_transl_value;eq_same_clear;eauto.
  - simpl in *.
    erewrite (div_ok v v1 v2 n n1 n2);eauto.
Qed.


(** [safe_stack s] means that every value in s is correct wrt to
    overflows.
    TODO: extend with other values than Int: floats, arrays, records. *)
Definition safe_stack s :=
  forall id n,
    STACK.fetchG id s = Some (Int n)
    -> do_overflow_check n (Normal (Int n)).


(** Hypothesis renaming stuff *)
Ltac rename_hyp2' th :=
  match th with
    | safe_stack _ => fresh "h_safe_stack"
    | _ => rename_hyp2 th
  end.

Ltac rename_hyp ::= rename_hyp2'.

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
              eval_expr st s e (Normal (Int n)) ->
              do_overflow_check n (Normal (Int n)).
Proof.
  !intros.
  revert h_safe_stack.
  remember (Normal (Int n)) as hN.
  revert HeqhN.
  !induction h_eval_expr;!intros;subst;try discriminate.
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
      !invclear heq3.
      apply IHh_eval_expr;auto.
Qed.


(* See CminorgenProof.v@205. *)
(* We will need more than that probably. But for now let us use
   a simple notion of matching: the value of a variable is equal to
   the value of its translation. Its translation is currently (an
   expression of the form ELoad((Eload(Eload ...(Eload(0)))) + n)). We
   could define a specialization of eval_expr for this kind of
   expression but at some point the form of the expression will
   complexify (some variables may stay temporary instead of going in
   the stack, etc).

   We also put well-typing constraints on the stack wrt symbol
   table. *)
Record match_env (st:symboltable) (s: semantics.STACK.stack) (CE:compilenv) (sp:Values.val)
       (locenv: Cminor.env): Prop :=
  mk_match_env {
      me_vars:
        forall id astnum v typeofv,
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

      me_transl:
        forall (g:genv)(m:Memory.Mem.mem)
               nme v addrof_nme load_addrof_nme typ_nme cm_typ_nme v',
          eval_name st s nme (Normal v) ->
          type_of_name st nme = OK typ_nme ->
          transl_name st CE nme = OK addrof_nme ->
          transl_type st typ_nme = OK cm_typ_nme ->
          make_load addrof_nme cm_typ_nme = OK load_addrof_nme ->
          transl_value v = OK v' ->
          Cminor.eval_expr g sp locenv m load_addrof_nme v';

      me_overflow: safe_stack s
    }.




(** Hypothesis renaming stuff *)
Ltac rename_hyp3 th :=
  match th with
    | match_env _ _ _ _ _ => fresh "h_match_env"
    | _ => rename_hyp2 th
  end.

Ltac rename_hyp ::= rename_hyp3.



Lemma transl_name_ok :
  forall stbl CE locenv g m (s:STACK.stack) (nme:name) (v:value) (e' e'':Cminor.expr)
         typeof_nme typeof_nme' (sp: Values.val) v',
    eval_name stbl s nme (Normal v) ->
    type_of_name stbl nme = OK typeof_nme ->
    transl_type stbl typeof_nme = OK typeof_nme' ->
    transl_name stbl CE nme = OK e' ->
    match_env stbl s CE sp locenv ->
    make_load e' typeof_nme' = OK e'' ->
    transl_value v = OK v' ->
    Cminor.eval_expr g sp locenv m e'' v'.
Proof.
  intros until v'.
  intro h_eval_name.
  remember (Normal v) as Nv.
  revert HeqNv.
  revert v e' sp v'.
  !induction h_eval_name;simpl;!intros; subst;try discriminate.
  !invclear heq.
  !destruct h_match_env.
  rename x into i.
  specialize (me_transl0 g m (E_Identifier ast_num i) v0 e' e'' typeof_nme typeof_nme' v').
  (* TODO: automate this or make it disappear. *)
  !! (fun _ => assert (eval_name st s (E_Identifier ast_num i) (Normal v0))) g.
  { constructor.
    assumption. }
  simpl in me_transl0.
  specialize (me_transl0 h_eval_name heq_fetch_var_type heq_transl_variable heq_transl_type heq_make_load heq_transl_value).
  repeat split;auto.
Qed.


Lemma transl_expr_ok :
  forall stbl CE locenv g m (s:STACK.stack) (e:expression) (v:value) (e':Cminor.expr)
         (sp: Values.val) v',
    eval_expr stbl s e (Normal v) ->
    transl_expr stbl CE e = OK e' ->
    match_env stbl s CE sp locenv ->
    transl_value v = OK v' ->
    Cminor.eval_expr g sp locenv m e' v'.
Proof.
  intros until v'.
  intro h_eval_expr.
  remember (Normal v) as Nv.
  revert HeqNv.
  revert v e' sp v'.
  !induction h_eval_expr;simpl;!intros; subst;eq_same_clear;try now discriminate.
  - destruct (transl_literal_ok g l v0 h_eval_literal sp) as [vv h_and].
    !destruct h_and;eq_same_clear.
    constructor.
    assumption.
  - !destruct n; try now inversion heq.
    !inversion h_eval_name;subst.
    destruct (transl_variable st CE a i) eqn:heq_trv;try discriminate;simpl in *.
    destruct (fetch_var_type i st) eqn:heq_fetch_type; (try now inversion heq).
    simpl in heq.
    unfold value_at_addr in heq.
    destruct (transl_type st t) eqn:heq_transl_type;simpl in *.
    + eapply transl_name_ok in h_eval_name;simpl; eauto.
    + discriminate.
(*  *)
  - destruct (transl_expr st CE e1) eqn:heq_transl_expr1;(try now inversion heq);simpl in heq.
    destruct (transl_expr st CE e2) eqn:heq_transl_expr2;(try now inversion heq);simpl in heq.
    eq_same_clear.

    destruct (transl_value v1) eqn:heq_transl_value_v1.
    destruct (transl_value v2) eqn:heq_transl_value_v2.
    + apply eval_Ebinop with v v3.
      * eapply IHh_eval_expr1;eauto.
      * eapply IHh_eval_expr2;eauto.
      * { eapply binary_operator_ok;eauto.
          - destruct v1;simpl;auto.
            eapply eval_expr_overf;eauto.
            eapply h_match_env.(me_overflow st s CE sp locenv).
          - destruct v2;simpl;auto.
            eapply eval_expr_overf;eauto.
            eapply h_match_env.(me_overflow st s CE sp locenv).
          - !inversion h_do_rtc_binop. rename H into h_or_op.
            + !inversion h_overf_check;subst.
              assumption.
            + !inversion h_overf_check;subst.
              !inversion h_do_division_check;subst.
              simpl in *.
              assumption.
            + assumption. }
          
    + functional inversion heq_transl_value_v2;subst.
      * admit. (* Arrays *)
      * admit. (* Records *)
      * admit. (* Undefined *)
    + functional inversion heq_transl_value_v1;subst.
      * admit. (* Arrays *)
      * admit. (* Records *)
      * admit. (* Undefined *)
  -XXX
    +
        !inversion h_eval_expr.
        clear IHh_eval_expr1 IHh_eval_expr2.
        rename v into v1'. rename v3 into v2'.
        { !inversion h_do_rtc_binop. rename H into h_or_op.
          - decomp h_or_op; clear h_or_op;subst;simpl.
            
            rewrite binopexp_ok in heq.
            functional inversion heq;subst.
            rewrite <- binopexp_ok in heq.
            simpl in heq_transl_value_v2, heq_transl_value_v1.
            eq_same_clear.
            simpl.
            simpl in *.
            inversion h_overf_check;subst;simpl in *;eq_same_clear.
            
            simpl in *.
            
            rewrite (add_ok   _ _ _ _ _ _ _ _ _ heq).
            eapply add_ok in heq;eauto.
            simpl in *.
        
    + 
      specialize
        (IHh_eval_expr1 v1 e sp v
                        (refl_equal (Normal v1))
                        (refl_equal (OK e))
                        h_match_env
                        heq_transl_value_v1).
    
    !inversion h_do_rtc_binop. rename H into h_or_op.
    destruct op;try discriminate.

    apply eval_expr_overf in h_eval_expr0.
        
    

    simpl in *.
    eq_same_clear.

    
    specialize (IHh_eval_expr1 v1 e sp v' (refl_equal (Normal v1)) (refl_equal (OK e)) h_match_env).
    specialize (IHh_eval_expr2 v2 e0 sp v' (refl_equal (Normal v2)) (refl_equal (OK e0)) h_match_env).
    decomp IHh_eval_expr1. clear IHh_eval_expr1. rename H2 into hmatch1.
    decomp IHh_eval_expr2. clear IHh_eval_expr2. rename H2 into hmatch2.
    !inversion h_do_rtc_binop; try !invclear h_overf_check. rename H into h_or_op.



xxxx

    destruct h_match_env.
    specialize (me_vars0 i ast_num v0 t heq_SfetchG heq_fetch_type).
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

        
    + !inversion h_do_division_check.
      simpl in heq.
      !invclear heq.
      exists (Values.Vint (Integers.Int.repr (Z.quot v3 v4))).
      { (repeat split);auto.
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
        - apply Do_Overflow_Check_OK.
          assumption. }
    + destruct op;simpl in *; try match goal with H: ?A <> ?A |- _ => elim H;auto end.
      * clear hmatch1 hmatch2.
        repeat match goal with | H:?X <> ?Y |-_ => clear H end.
        exists (Values.Val.and x x0).
        { repeat split;auto.
          - eapply and_ok;eauto.
          - econstructor;eauto.
          - (* functional inversion *)
            !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in heq.
            inversion heq.
            auto. }
      * clear hmatch1 hmatch2.
        repeat match goal with | H:?X <> ?Y |-_ => clear H end.
        exists (Values.Val.or x x0).
        { repeat split;auto.
          - eapply or_ok;eauto.
          - econstructor;eauto.
          - (* functional inversion *)
            !destruct v1;try discriminate; !destruct v2;try discriminate;simpl in heq.
            inversion heq.
            auto. }

      * repeat match goal with | H:?X <> ?Y |-_ => clear H end.
        destruct v1;try discriminate; destruct v2;try discriminate;simpl in heq.
        !invclear heq.
        exists (Values.Val.cmp Integers.Ceq (Values.Vint (Integers.Int.repr n))
                               (Values.Vint (Integers.Int.repr n0))).
        { repeat split;auto.
          - eapply eq_ok with n n0;auto.
          - econstructor.
            { apply h_CM_eval_expr. }
            { apply h_CM_eval_expr0. }
            simpl in *.
            simpl in heq_transl_value0.
            !invclear heq_transl_value.
            !invclear heq_transl_value0.
            reflexivity. }
      * repeat match goal with | H:?X <> ?Y |-_ => clear H end.
        destruct v1;try discriminate; destruct v2;try discriminate;simpl in heq.
        !invclear heq.
        exists (Values.Val.cmp Integers.Cne (Values.Vint (Integers.Int.repr n))
                               (Values.Vint (Integers.Int.repr n0))).
        { repeat split;auto.
          - eapply neq_ok with n n0;auto.
          - econstructor.
            { apply h_CM_eval_expr. }
            { apply h_CM_eval_expr0. }
            simpl in *.
            !invclear heq_transl_value.
            !invclear heq_transl_value0.
            reflexivity. }
      * repeat match goal with | H:?X <> ?Y |-_ => clear H end.
        destruct v1;try discriminate; destruct v2;try discriminate;simpl in heq.
        !invclear heq.
        exists (Values.Val.cmp Integers.Clt (Values.Vint (Integers.Int.repr n))
                               (Values.Vint (Integers.Int.repr n0))).
        { repeat split;auto.
          - eapply lt_ok with n n0;auto.
          - econstructor.
            { apply h_CM_eval_expr. }
            { apply h_CM_eval_expr0. }
            simpl in *.
            !invclear heq_transl_value.
            !invclear heq_transl_value0.
            reflexivity. }

      * repeat match goal with | H:?X <> ?Y |-_ => clear H end.
        destruct v1;try discriminate; destruct v2;try discriminate;simpl in heq.
        !invclear heq.
        exists (Values.Val.cmp Integers.Cle (Values.Vint (Integers.Int.repr n))
                               (Values.Vint (Integers.Int.repr n0))).
        { repeat split;auto.
          - eapply le_ok with n n0;auto.
          - econstructor.
            { apply h_CM_eval_expr. }
            { apply h_CM_eval_expr0. }
            simpl in *.
            !invclear heq_transl_value.
            !invclear heq_transl_value0.
            reflexivity. }

      * repeat match goal with | H:?X <> ?Y |-_ => clear H end.
        destruct v1;try discriminate; destruct v2;try discriminate;simpl in heq.
        !invclear heq.
        exists (Values.Val.cmp Integers.Cgt (Values.Vint (Integers.Int.repr n))
                               (Values.Vint (Integers.Int.repr n0))).
        { repeat split;auto.
          - eapply gt_ok with n n0;auto.
          - econstructor.
            { apply h_CM_eval_expr. }
            { apply h_CM_eval_expr0. }
            simpl in *.
            !invclear heq_transl_value.
            !invclear heq_transl_value0.
            reflexivity. }

      * repeat match goal with | H:?X <> ?Y |-_ => clear H end.
        destruct v1;try discriminate; destruct v2;try discriminate;simpl in heq.
        !invclear heq.
        exists (Values.Val.cmp Integers.Cge (Values.Vint (Integers.Int.repr n))
                               (Values.Vint (Integers.Int.repr n0))).
        { repeat split;auto.
          - eapply ge_ok with n n0;auto.
          - econstructor.
            { apply h_CM_eval_expr. }
            { apply h_CM_eval_expr0. }
            simpl in *.
            !invclear heq_transl_value.
            !invclear heq_transl_value0.
            reflexivity. }

  - inversion heq0.
  - destruct (transl_expr st CE e) eqn:heq_transl_expr1;simpl in heq;(try now inversion heq).
    2: destruct op;discriminate.
    specialize (IHh_eval_expr v e0 sp (refl_equal (Normal v)) (refl_equal (OK e0)) h_match_env).
    decomp IHh_eval_expr. clear IHh_eval_expr. rename H2 into hmatch.
    !invclear h_do_rtc_unop;simpl in *; !invclear heq.
    + try !invclear h_overf_check.
      exists (Values.Vint (Integers.Int.repr v')).
      repeat (split;auto).
      * apply eval_Eunop with x;auto.
        simpl.
        destruct v;try discriminate.
        simpl in heq_transl_value.
        apply f_equal.
        !invclear heq_transl_value.
        eapply unaryneg_ok with n;auto.
      * constructor.
        assumption.
    + destruct op;try discriminate.
      * elim hneq;reflexivity.
      * clear hneq.
        simpl in *.
        !invclear heq.
        exists (Values.Val.notbool x).
        { repeat split.
          - eapply not_ok;eauto.
          - econstructor; eauto.
            econstructor; eauto.
            econstructor; eauto.
            simpl.
            destruct v;simpl in *;try discriminate.
            clear heq0 hmatch.
            destruct n;simpl in *.
            + !invclear heq_transl_value.
              vm_compute.
              reflexivity.
            + !invclear heq_transl_value.
              vm_compute.
              reflexivity.
          - destruct v;simpl in *;try discriminate.
            !invclear heq0.
            trivial. }
Qed.




Lemma transl_stmt_ok :
  forall stbl CE locenv g m (s:STACK.stack) (stm:statement)
         (stm':Cminor.stmt) (s':STACK.stack) sp f,
    eval_stmt stbl s stm (Normal s') ->
    match_env stbl s CE sp locenv ->
    transl_stmt stbl CE stm = (OK stm') ->
    exists tr g' m' o,
    Cminor.exec_stmt g f sp locenv m stm' tr g' m' o.
Proof.
  intros until f.
  intro h_eval_stmt.
  remember (Normal s') as hN.
  revert HeqhN.
  !induction h_eval_stmt;simpl; intros HeqhN h_match_env heq_transl_stmt;try discriminate;try !invclear heq_transl_stmt; try !invclear HeqhN.
  - repeat econstructor.
  - destruct (transl_expr st CE e) eqn:heq_tr_expr;simpl in heq.
    +
      { eapply transl_expr_ok in heq_tr_expr.
        (* bug of renaming tactic *)
        - idall.
          (*actuall heq_tr_expr is not changed into (id ...) so unid heq_tr_expr fails *)
          (* unid heq_tr_expr. *)
          decompose [ex and] heq_tr_expr.
          rename_norm.
          unidall.
          clear heq_tr_expr.
          rename H2 into hmatch.
          destruct (transl_name st CE x) eqn:heq_tr_name;simpl in heq.
          + !invclear heq.
            repeat econstructor.
            2: eapply h_CM_eval_expr.
            !destruct h_match_env.
            
            Focus 2.
            
            * admit.
          apply h_CM_eval_expr0.
          destruct h_match_env.

        apply 
  - repeat econstructor.
  - repeat econstructor.
  - repeat econstructor.
  -
Qed.


