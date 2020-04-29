From iris.algebra Require Import auth frac agree gmap list excl.
From iris.base_logic.lib Require Import invariants.
From iris.proofmode Require Import tactics.
From iris.program_logic Require Export language.
From iris.program_logic Require Import lifting.
From Perennial.algebra Require Export frac_count.
From Perennial.Helpers Require Export Transitions.
From Perennial.program_logic Require Export spec_assert.
From Perennial.goose_lang Require Export lang.
From Perennial.goose_lang Require Import tactics notation lifting.

(* Wrapper around ffi_models and so on to avoid clashes between the ffi for
   the spec and the concrete *)

Class spec_ffi_model := { spec_ffi_model_field : ffi_model }.
Class spec_ext_op := { spec_ext_op_field : ext_op }.
Class spec_ext_semantics (H1: spec_ext_op) (H2: spec_ffi_model) :=
  { spec_ext_semantics_field : ext_semantics (spec_ext_op_field) (spec_ffi_model_field) }.
Class spec_ffi_interp (spec_ffi: spec_ffi_model) :=
  { spec_ffi_interp_field : ffi_interp (spec_ffi_model_field) }.

Section go_refinement.
Context {spec_ext: spec_ext_op}.
Context {spec_ffi: spec_ffi_model}.
Context {spec_ffi_semantics: spec_ext_semantics spec_ext spec_ffi}.
Context `{!spec_ffi_interp spec_ffi}.

Canonical Structure spec_lang : language :=
  @heap_lang (spec_ext_op_field) (spec_ffi_model_field) (spec_ext_semantics_field).
Canonical Structure spec_crash_lang : crash_semantics spec_lang :=
  @heap_crash_lang (spec_ext_op_field) (spec_ffi_model_field) (spec_ext_semantics_field).

Existing Instance spec_ffi_interp_field.
Existing Instance spec_ext_semantics_field.
Existing Instance spec_ext_op_field.
Existing Instance spec_ffi_model_field.


Class refinement_heapG Σ := refinement_HeapG {
  refinement_spec_ffiG : ffiG Σ;
  refinement_traceG :> traceG Σ;
  refinement_cfgG :> @cfgG spec_lang Σ;
  refinement_na_heapG :> na_heapG loc (@val spec_ext_op_field) Σ;
  refinement_frac_countG :> frac_countG Σ;
  (* TODO: do we need prophecies at the spec level? *)
  (*
  refinement_proph_mapG :> proph_mapG proph_id (val * val) Σ;
   *)
}.

Section go_spec_definitions.
Context {Σ: gFunctors}.
Context {hR: refinement_heapG Σ}.
Context `{invG Σ}.

Definition spec_interp σ : iProp Σ :=
    (na_heap_ctx tls σ.(heap) ∗ (* proph_map_ctx κs σ.(used_proph_id) ∗ *) ffi_ctx refinement_spec_ffiG σ.(world)
      ∗ trace_auth σ.(trace) ∗ oracle_auth σ.(oracle) ∗ ⌜ null_non_alloc σ.(heap) ⌝)%I.

Definition spec_stateN := nroot .@ "source".@  "state".

(* TODO: these names are terrible *)
Definition spec_ctx : iProp Σ :=
  source_ctx (CS := spec_crash_lang) ∗ inv spec_stateN (∃ σ, source_state σ ∗ spec_interp σ)%I.
Definition spec_ctx' r ρ : iProp Σ :=
  source_ctx' (CS := spec_crash_lang) r ρ ∗ inv spec_stateN (∃ σ, source_state σ ∗ spec_interp σ)%I.

Global Instance spec_ctx_persistent : Persistent (spec_ctx).
Proof. apply _. Qed.

(** Override the notations so that scopes and coercions work out *)
Notation "l s↦{ q } v" := (heap_mapsto (hG := refinement_na_heapG) l q v%V)
  (at level 20, q at level 50, format "l  s↦{ q }  v") : bi_scope.
Notation "l s↦ v" :=
  (heap_mapsto (hG := refinement_na_heapG) l 1 v%V) (at level 20) : bi_scope.
Notation "l s↦{ q } -" := (∃ v, l ↦{q} v)%I
  (at level 20, q at level 50, format "l  s↦{ q }  -") : bi_scope.
Notation "l ↦ -" := (l ↦{1} -)%I (at level 20) : bi_scope.

Section go_ghost_step.

Lemma sN_inv_sub_minus_state E:
  nclose sN ⊆ E →
  nclose sN_inv ⊆ E ∖ ↑spec_stateN.
Proof.
  rewrite /sN_inv/sN/spec_stateN. intros Hsub.
  assert (nclose (nroot.@"source".@"base") ##
                 ↑nroot.@"source".@"state").
  { solve_ndisj. }
  assert (nclose (nroot.@"source".@"base") ⊆ E).
  { etransitivity; last eassumption. apply nclose_subseteq. }
  set_solver.
Qed.

Hint Resolve sN_inv_sub_minus_state.

Lemma ghost_load_block_oob_stuck j K `{LanguageCtx _ K} E l n
  (Hoff: (addr_offset l < 0 ∨ n <= addr_offset l)%Z):
  nclose sN ⊆ E →
  spec_ctx -∗
  na_block_size (addr_base l) n →
  j ⤇ K (Load (Val $ LitV $ LitLoc l)) ={E}=∗ False.
Proof.
  iIntros (?) "(#Hctx&#Hstate) Hl Hj".
  iInv "Hstate" as (?) "(>H&Hinterp)" "Hclo".
  iDestruct "Hinterp" as "(>Hσ&Hrest)".
  iDestruct (@na_block_size_oob_lookup with "Hσ Hl") as %Hnone; auto.
  iMod (ghost_step_stuck with "Hj Hctx H") as %[].
  {
  split; first done.
  apply prim_head_irreducible; auto.
  * inversion 1; repeat (monad_inv; simpl in * ).
    match goal with
      [ H: context [ heap _ !! _] |- _ ] => setoid_rewrite Hnone in H
    end.
    simpl in *. monad_inv; eauto.
  * intros Hval. apply ectxi_language_sub_redexes_are_values => Ki e' Heq.
    assert (of_val #l = e').
    { move: Heq. destruct Ki => //=; congruence. }
    subst. eauto.
  }
  solve_ndisj.
Qed.

Lemma ghost_load_write_stuck j K `{LanguageCtx _ K} E l q (v: val):
  nclose sN ⊆ E →
  spec_ctx -∗
  na_heap_mapsto_st (WSt) l q v -∗
  j ⤇ K (Load (Val $ LitV $ LitLoc l)) ={E}=∗ False.
Proof.
  iIntros (?) "(#Hctx&#Hstate) Hl Hj".
  iInv "Hstate" as (?) "(>H&Hinterp)" "Hclo".
  iDestruct "Hinterp" as "(>Hσ&Hrest)".
  iDestruct (@na_heap_write_lookup with "Hσ Hl") as %([]&?&Hlock); try inversion Hlock; subst.
  iMod (ghost_step_stuck with "Hj Hctx H") as %[].
  {
  split; first done.
  apply prim_head_irreducible; auto.
  * inversion 1; repeat (monad_inv; simpl in * ).
  * intros Hval. apply ectxi_language_sub_redexes_are_values => Ki e' Heq.
    assert (of_val #l = e').
    { move: Heq. destruct Ki => //=; congruence. }
    subst. eauto.
  }
  solve_ndisj.
Qed.

Lemma spec_interp_null σ l:
  addr_base l = null →
  ▷ spec_interp σ -∗
  ▷ ⌜ heap σ !! l = None ⌝.
Proof.
  iIntros (Hl) "Hinterp !>".
  iDestruct "Hinterp" as "(_&_&?&?&H)".
  iDestruct "H" as %Hnonnull. iPureIntro.
  rewrite (addr_plus_off_decode l) Hl. eapply Hnonnull.
Qed.

Lemma ghost_load_null_stuck j K `{LanguageCtx _ K} E l:
  addr_base l = null →
  nclose sN ⊆ E →
  spec_ctx -∗
  j ⤇ K (Load (Val $ LitV $ LitLoc l)) ={E}=∗ False.
Proof.
  iIntros (Hnull ?) "(#Hctx&#Hstate) Hj".
  iInv "Hstate" as (?) "(>H&Hinterp)" "Hclo".
  iDestruct (spec_interp_null _ l with "Hinterp") as ">Hnone"; eauto.
  iDestruct "Hnone" as %Hnone.
  iMod (ghost_step_stuck with "Hj Hctx H") as %[].
  {
  split; first done.
  apply prim_head_irreducible; auto.
  * inversion 1; repeat (monad_inv; simpl in * ).
    match goal with
      [ H: context [ heap _ !! _] |- _ ] => setoid_rewrite Hnone in H
    end.
    simpl in *. monad_inv; eauto.
  * intros Hval. apply ectxi_language_sub_redexes_are_values => Ki e' Heq.
    assert (of_val #l = e').
    { move: Heq. destruct Ki => //=; congruence. }
    subst. eauto.
  }
  solve_ndisj.
Qed.

Lemma ghost_load_rd j K `{LanguageCtx _ K} E n l q (v: val):
  nclose sN ⊆ E →
  spec_ctx -∗
  na_heap_mapsto_st (RSt n) l q v -∗
  j ⤇ K (Load (Val $ LitV $ LitLoc l)) ={E}=∗
  na_heap_mapsto_st (RSt n) l q v ∗ j ⤇ K v.
Proof.
  iIntros (?) "(#Hctx&#Hstate) Hl Hj".
  iInv "Hstate" as (?) "(>H&Hinterp)" "Hclo".
  iDestruct "Hinterp" as "(>Hσ&Hrest)".
  iDestruct (@na_heap_read' with "Hσ Hl") as %([]&?&?&Hlock); try inversion Hlock; subst.
  iMod (ghost_step_lifting with "Hj Hctx H") as "(Hj&H&_)".
  { eapply head_prim_step.
    rewrite /= /head_step /=.
    repeat (monad_simpl; simpl).
  }
  { eauto. }
  iMod ("Hclo" with "[Hσ H Hrest]").
  { iNext. iExists _. iFrame. }
  iFrame. eauto.
Qed.

Lemma ghost_load j K `{LanguageCtx _ K} E l q v:
  nclose sN ⊆ E →
  spec_ctx -∗
  l s↦{q} v -∗
  j ⤇ K (Load (Val $ LitV $ LitLoc l)) ={E}=∗
  l s↦{q} v ∗ j ⤇ K v.
Proof.
  iIntros (?) "Hspec Hl0 Hj".
  iDestruct (heap_mapsto_na_acc with "Hl0") as "(Hl&Hclo_l)".
  rewrite na_heap_mapsto_eq.
  iMod (ghost_load_rd with "Hspec [$] [$]") as "(?&$)"; eauto.
  iModIntro. iApply "Hclo_l". iFrame.
Qed.

Definition spec_mapsto_vals_toks l q vs : iProp Σ :=
  ([∗ list] j↦vj ∈ vs, (l +ₗ j) s↦{q} vj ∗ meta_token (hG := refinement_na_heapG) (l +ₗ j) ⊤)%I.

Lemma ghost_allocN_seq_sized_meta j K `{LanguageCtx _ K} E v (n: u64) :
  (0 < length (flatten_struct v))%nat →
  (0 < int.val n)%Z →
  nclose sN ⊆ E →
  spec_ctx -∗
  j ⤇ K (AllocN (Val $ LitV $ LitInt $ n) (Val v)) ={E}=∗
  ∃ l : loc, j ⤇ K (#l) ∗
             ⌜ l ≠ null ∧ addr_offset l = 0%Z ⌝ ∗
             na_block_size (hG := refinement_na_heapG) l (int.nat n * length (flatten_struct v))%nat ∗
             [∗ list] i ∈ seq 0 (int.nat n),
             (spec_mapsto_vals_toks (l +ₗ (length (flatten_struct v) * Z.of_nat i)) 1
                               (flatten_struct v)).
Proof.
  iIntros (Hlen Hn Φ) "(#Hctx&Hstate) Hj".
  iInv "Hstate" as (σ) "(>H&Hinterp)" "Hclo".
  iDestruct "Hinterp" as "(>Hσ&(Hrest1&Hrest2&Hrest3&Hrest4))".
  iMod (ghost_step_lifting with "Hj Hctx H") as "(Hj&H&_)".
  { apply head_prim_step. simpl.
    econstructor; last (repeat econstructor).
    econstructor. { monad_simpl. }
    eexists _ (fresh_locs (dom (gset loc) _.(heap))); repeat econstructor.
      ** apply fresh_locs_non_null; lia.
      ** hnf; intros. apply (not_elem_of_dom (D := gset loc)). by apply fresh_locs_fresh.
  }
  { solve_ndisj. }
  set (l := fresh_locs (dom (gset loc) (heap _))).
  assert (isFresh σ l) as Hfresh.
  { apply fresh_locs_isFresh. }
  iMod (na_heap_alloc_list tls (heap _) l
                           (concat_replicate (int.nat n) (flatten_struct v))
                           (Reading O) with "Hσ")
    as "(Hσ & Hblock & Hl)".
  { rewrite concat_replicate_length. cut (0 < int.nat n)%nat; first by lia.
    eauto with *. }
  { destruct Hfresh as (?&?). rewrite //=. }
  { destruct Hfresh as (H'&?); eauto. eapply H'. }
  { destruct Hfresh as (H'&?); eauto. destruct (H' 0) as (?&Hfresh).
    by rewrite (loc_add_0) in Hfresh.
  }
  { eauto. }
  iMod ("Hclo" with "[Hσ H Hrest1 Hrest2 Hrest3 Hrest4]").
  { iNext. iExists _. iFrame "H". iFrame.
    iDestruct "Hrest4" as %Hnon_null.
    iPureIntro. intros off.
    cut (∀ off x, heap (state_init_heap l x v σ) !! addr_plus_off null off =
                heap σ !! addr_plus_off null off).
    { intros ->. eauto. }
    intros.  rewrite /state_init_heap/ state_insert_list.
    rewrite lookup_union_r //.
    eapply heap_array_lookup_base_ne. erewrite isFresh_base; eauto.
    eapply isFresh_not_null; eauto.
  }
  iModIntro.
  iExists _. iFrame.
  unfold mapsto_vals.
  rewrite concat_replicate_length. iFrame.
  iDestruct (heap_seq_replicate_to_nested_mapsto l (flatten_struct v) (int.nat n)
                                                 (λ l v, l s↦ v ∗ meta_token l ⊤)%I
               with "[Hl]") as "Hl".
  {
    iApply (big_sepL_mono with "Hl").
    iIntros (l0 x Heq) "(Hli&$)".
    iApply (na_mapsto_to_heap with "Hli").
    destruct Hfresh as (H'&?). eapply H'.
  }
  iSplitL "".
  { iPureIntro; split; eauto using isFresh_not_null, isFresh_offset0. }
  iApply (big_sepL_mono with "Hl").
  iIntros (k0 ? _) "H".
  setoid_rewrite Z.mul_comm at 1.
  setoid_rewrite Z.mul_comm at 2.
  rewrite /spec_mapsto_vals_toks. eauto.
Qed.

End go_ghost_step.
End go_spec_definitions.

End go_refinement.

Notation "l s↦{ q } v" := (heap_mapsto (hG := refinement_na_heapG) l q v%V)
  (at level 20, q at level 50, format "l  s↦{ q }  v") : bi_scope.
Notation "l s↦ v" :=
  (heap_mapsto (hG := refinement_na_heapG) l 1 v%V) (at level 20) : bi_scope.
Notation "l s↦{ q } -" := (∃ v, l ↦{q} v)%I
  (at level 20, q at level 50, format "l  s↦{ q }  -") : bi_scope.
Notation "l ↦ -" := (l ↦{1} -)%I (at level 20) : bi_scope.

Section trace_inv.
Context {ext: ext_op}.
Context {ffi: ffi_model}.
Context {ffi_semantics: ext_semantics ext ffi}.
Context `{!ffi_interp ffi}.
Context {spec_ext: spec_ext_op}.
Context {spec_ffi: spec_ffi_model}.
Context {spec_ffi_semantics: spec_ext_semantics spec_ext spec_ffi}.
Context `{!spec_ffi_interp spec_ffi}.
Context {Σ: gFunctors}.
Context {hG: heapG Σ}.
Context {hR: refinement_heapG Σ}.

Definition trace_inv : iProp Σ :=
  (∃ tr trs or ors, ⌜ tr = trs ⌝ ∗
                    ⌜ or = ors ⌝ ∗
                    trace_frag (hT := heapG_traceG) tr ∗
                    trace_frag (hT := refinement_traceG) trs ∗
                    oracle_frag (hT := heapG_traceG) or ∗
                    oracle_frag (hT := refinement_traceG) ors).

Definition spec_traceN := sN .@ "trace".

Definition trace_ctx : iProp Σ :=
  inv spec_traceN trace_inv.

End trace_inv.

Section resolution_test.
Context {ext: ext_op}.
Context {ffi: ffi_model}.
Context {ffi_semantics: ext_semantics ext ffi}.
Context `{!ffi_interp ffi}.
Context {spec_ext: spec_ext_op}.
Context {spec_ffi: spec_ffi_model}.
Context {spec_ffi_semantics: spec_ext_semantics spec_ext spec_ffi}.
Context `{!spec_ffi_interp spec_ffi}.
Context {Σ: gFunctors}.
Context {hG: heapG Σ}.
Context {hR: refinement_heapG Σ}.
Set Printing Implicit.

Lemma test_resolution1 l v :
  l ↦ v -∗ (heap_mapsto (hG := heapG_na_heapG) l 1 (v)).
Proof using Type.
  iIntros "H". eauto.
Qed.

Lemma test_resolution2 l v :
  l s↦ v -∗ (heap_mapsto (hG := refinement_na_heapG) l 1 (v)).
Proof using Type.
  iIntros "H". eauto.
Qed.

Lemma test_resolution3 l v :
  l ↦ v -∗ (heap_mapsto l 1 (v)).
Proof using Type.
  iIntros "H". eauto.
Qed.

Lemma test_resolution4 l v :
  l s↦ v -∗ (heap_mapsto l 1 (v)).
Proof using Type.
  iIntros "H". eauto.
Qed.

End resolution_test.

Arguments refinement_spec_ffiG {spec_ext spec_ffi spec_ffi_semantics spec_ffi_interp0 Σ hRG} : rename.
