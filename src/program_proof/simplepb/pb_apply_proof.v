From Perennial.base_logic Require Import lib.saved_prop.
From Perennial.program_proof Require Import grove_prelude.
From Goose.github_com.mit_pdos.gokv.simplepb Require Export pb.
From Perennial.program_proof.simplepb Require Import pb_ghost.
From Perennial.goose_lang.lib Require Import waitgroup.
From iris.base_logic Require Export lib.ghost_var mono_nat.
From iris.algebra Require Import dfrac_agree mono_list.
From Perennial.goose_lang Require Import crash_borrow.
From Perennial.program_proof.simplepb Require Import pb_definitions pb_marshal_proof pb_applybackup_proof.
From Perennial.program_proof.reconnectclient Require Import proof.
From RecordUpdate Require Import RecordSet.
Import RecordSetNotations.

Section pb_apply_proof.

Context `{!heapGS Σ}.
Context {pb_record:Sm.t}.

Notation OpType := (Sm.OpType pb_record).
Notation has_op_encoding := (Sm.has_op_encoding pb_record).
Notation compute_reply := (Sm.compute_reply pb_record).
Notation pbG := (pbG (pb_record:=pb_record)).

Context `{!pbG Σ}.

Lemma wp_Clerk__Apply γ γsys γsrv ck op_sl q op (op_bytes:list u8) (Φ:val → iProp Σ) :
has_op_encoding op_bytes op →
is_Clerk ck γsys γsrv -∗
is_inv γ γsys -∗
is_slice_small op_sl byteT q op_bytes -∗
□((|={⊤∖↑pbN,∅}=> ∃ ops, own_log γ ops ∗
  (own_log γ (ops ++ [op]) ={∅,⊤∖↑pbN}=∗
     (∀ reply_sl, is_slice_small reply_sl byteT 1 (compute_reply ops op) -∗
            is_slice_small op_sl byteT q op_bytes -∗
                Φ (#(U64 0), slice_val reply_sl)%V)))
∗
(∀ (err:u64) unused_sl, ⌜err ≠ 0⌝ -∗ is_slice_small op_sl byteT q op_bytes -∗
                                     Φ (#err, (slice_val unused_sl))%V )) -∗
WP Clerk__Apply #ck (slice_val op_sl) {{ Φ }}.
Proof.
  intros Henc.
  iIntros "#Hck #Hinv Hop_sl".
  iIntros "#HΦ".
  wp_call.
  wp_apply (wp_ref_of_zero).
  { done. }
  iIntros (rep) "Hrep".
  wp_pures.
  iNamed "Hck".
  wp_loadField.
  rewrite is_pb_host_unfold.
  iNamed "Hsrv".
  wp_apply (wp_ReconnectingClient__Call2 with "Hcl_rpc [] Hop_sl Hrep").
  {
    iDestruct "Hsrv" as "[_ [_ [_ [_ [$ _]]]]]".
  }
  { (* Successful RPC *)
    iModIntro.
    iNext.
    unfold Apply_spec.
    iExists _, _.
    iSplitR; first done.
    iSplitR; first done.
    simpl.
    iSplit.
    {
      iModIntro.
      iLeft in "HΦ".
      iMod "HΦ".
      iModIntro.
      iDestruct "HΦ" as (?) "[Hlog HΦ]".
      iExists _.
      iFrame.
      iIntros "Hlog".
      iMod ("HΦ" with "Hlog") as "HΦ".
      iModIntro.
      iIntros (? Hreply_enc) "Hop".
      iIntros (?) "Hrep Hrep_sl".
      wp_pures.
      wp_load.
      rewrite Hreply_enc.
      wp_apply (ApplyReply.wp_Decode with "[Hrep_sl]").
      { iFrame. iPureIntro. done. }
      iIntros (reply_ptr) "Hreply".
      wp_pures.
      iNamed "Hreply".
      wp_loadField.
      wp_loadField.
      wp_pures.
      iModIntro.
      iApply ("HΦ" with "Hrepy_ret_sl Hop").
    }
    { (* Apply failed for some reason, e.g. node is not primary *)
      iIntros (??).
      iModIntro.
      iIntros (Herr_nz ? Hreply_enc) "Hop".
      iIntros (?) "Hrep Hrep_sl".
      wp_pures.
      iIntros.
      wp_pures.
      wp_load.
      wp_apply (ApplyReply.wp_Decode with "[$Hrep_sl]").
      { done. }
      iIntros (reply_ptr) "Hreply".
      iNamed "Hreply".
      wp_pures.
      wp_loadField.
      wp_loadField.
      iRight in "HΦ".
      wp_pures.
      iApply ("HΦ" with "[] Hop").
      done.
    }
  }
  { (* RPC error *)
    iIntros.
    wp_pures.
    wp_if_destruct.
    {
      wp_load.
      exfalso. done.
    }
    iRight in "HΦ".
    replace (slice.nil) with (slice_val Slice.nil) by done.
    wp_pures.
    iApply ("HΦ" with "[] [$]").
    done.
  }
Qed.

(* TODO: move me *)
Lemma wp_random :
{{{ True }}}
  prelude.Data.randomUint64 #()
{{{ (n:u64), RET #n; True }}}.
Proof.
#[local]
Transparent prelude.Data.randomUint64.
  rewrite /prelude.Data.randomUint64.
  iIntros (?) "_ HΦ". wp_pures. iModIntro. by iApply "HΦ".
Opaque prelude.Data.randomUint64.
Qed.

(*
Definition entry_pred_conv (σ : list (OpType * (list OpType → iProp Σ)))
  (σgnames : list (OpType * gname)) : iProp Σ :=
    ⌜ σ.*1 = σgnames.*1 ⌝ ∗
    [∗ list] k↦Φ;γ ∈ snd <$> σ; snd <$> σgnames, saved_pred_own γ DfracDiscarded Φ.

Definition is_ghost_lb' γ σ : iProp Σ :=
  ∃ σgnames, is_ghost_lb γ σgnames ∗ entry_pred_conv σ σgnames. *)

Lemma apply_eph_primary_step γp γpsrv γ γsrv ops canBecomePrimary epoch committedNextIndex op Q :
  (|={⊤∖↑ghostN,∅}=> ∃ σ, own_ghost γ σ ∗ (own_ghost γ (σ ++ [(op, Q)]) ={∅,⊤∖↑ghostN}=∗ True)) -∗
  own_Primary_ghost_f γp γpsrv γ γsrv canBecomePrimary true epoch committedNextIndex ops
  ={↑pbN}=∗
  own_Primary_ghost_f γp γpsrv γ γsrv canBecomePrimary true epoch committedNextIndex (ops ++ [(op, Q)]) ∗
  is_proposal_lb γ epoch (ops ++ [(op, Q)]) ∗
  is_proposal_facts γ epoch (ops ++ [(op, Q)]) ∗
  is_proposal_facts_prim γp epoch (ops ++ [(op, Q)])
.
Proof.
Admitted.

Lemma apply_eph_step γp γpsrv γ γsrv st op Q :
  st.(server.isPrimary) = true →
  st.(server.sealed) = false →
  (|={⊤∖↑ghostN,∅}=> ∃ σ, own_ghost γ σ ∗ (own_ghost γ (σ ++ [(op, Q)]) ={∅,⊤∖↑ghostN}=∗ True)) -∗
  own_Server_ghost_eph_f st γp γpsrv γ γsrv
  ={↑pbN}=∗
  own_Server_ghost_eph_f (st <| server.ops_full_eph := st.(server.ops_full_eph) ++ [(op, Q)] |>)
                              γp γpsrv γ γsrv ∗
  is_proposal_lb γ st.(server.epoch) (st.(server.ops_full_eph) ++ [(op, Q)]) ∗
  is_proposal_facts γ st.(server.epoch) (st.(server.ops_full_eph) ++ [(op, Q)]) ∗
  is_proposal_facts_prim γp st.(server.epoch) (st.(server.ops_full_eph) ++ [(op, Q)])
.
Proof.
  intros Hprim Hunsealed.
  iIntros "Hupd Hghost".
  iNamed "Hghost".
  rewrite /own_Server_ghost_eph_f /tc_opaque /=.
  iNamed "Hghost".
  rewrite Hprim.
  iMod (apply_eph_primary_step with "Hupd Hprimary") as "(Hprimary & #? & #?)".
  by iFrame "∗#".
Qed.

Lemma apply_commit_step γp γpsrv γ γsrv st opsfull op Q :
  is_ghost_lb γ (opsfull ++ [(op, Q)]) -∗
  is_proposal_lb γ st.(server.epoch) (opsfull ++ [(op, Q)]) -∗
  own_Server_ghost_eph_f st γp γpsrv γ γsrv
  ={↑pbN}=∗
  own_Server_ghost_eph_f (st <| server.committedNextIndex := length (opsfull) + 1 |> ) γp γpsrv γ γsrv
.
Proof.
  iIntros "#Hghost_lb #Hprop_lb".
  rewrite /own_Server_ghost_eph_f /tc_opaque /=.
  iNamed 1.
  rewrite /own_Primary_ghost_f /tc_opaque /=.
  iNamed "Hprimary".
  destruct st.(server.isPrimary) as [] eqn:Hprim.
  {
    iNamed "Hprim".
    (* iDestruct (ghost_propose_lb_valid with "Hprim Hprop_lb") as %Hprefix. *)
    iFrame "∗#".
    iExists _; iFrame "Hghost_lb #".
    iPureIntro.
    rewrite /get_rwops fmap_app app_length fmap_length /=.
    admit. (* FIXME: list length overflow *)
  }
  { by iFrame "∗#". }
Admitted.

Lemma wp_Server__Apply_internal (s:loc) γp γpsrv γ γsrv op_sl op_bytes op Q :
  {{{
        is_Server s γp γpsrv γ γsrv ∗
        readonly (is_slice_small op_sl byteT 1 op_bytes) ∗
        ⌜has_op_encoding op_bytes op⌝ ∗
        (|={⊤∖↑ghostN,∅}=> ∃ σ, own_ghost γ σ ∗ (own_ghost γ (σ ++ [(op, Q)]) ={∅,⊤∖↑ghostN}=∗ True))
  }}}
    pb.Server__Apply #s (slice_val op_sl)
  {{{
        reply_ptr reply, RET #reply_ptr; £ 1 ∗ £ 1 ∗ £ 1 ∗ ApplyReply.own_q reply_ptr reply ∗
        if (decide (reply.(ApplyReply.err) = 0%Z)) then
          ∃ opsfull,
            let ops := (get_rwops opsfull) in
            ⌜reply.(ApplyReply.ret) = compute_reply ops op⌝ ∗
            is_ghost_lb γ (opsfull ++ [(op, Q)])
        else
          True
  }}}
.
Proof.
  iIntros (Φ) "[#His Hpre] HΦ".
  iDestruct "Hpre" as "(#Hsl & %Hghostop_op & Hupd)".
  iNamed "His".
  rewrite /Server__Apply.
  wp_pure1_credit "Hcred3".
  wp_apply (wp_allocStruct).
  { eauto. }
  iIntros (reply_ptr) "Hreply".
  iDestruct (struct_fields_split with "Hreply") as "HH".
  iNamed "HH".
  wp_pure1_credit "Hlc1".
  wp_pure1_credit "Hlc2".
  simpl.
  replace (slice.nil) with (slice_val (Slice.nil)) by done.
  wp_storeField.

  wp_loadField.
  wp_apply (acquire_spec with "HmuInv").
  iIntros "[Hlocked Hown]".
  iNamed "Hown".
  iNamed "Hvol".
  wp_pure1_credit "Hcred1".
  wp_pure1_credit "Hcred2".
  wp_pures.
  wp_loadField.
  wp_if_destruct.
  { (* return error "not primary" *)
    wp_loadField.
    wp_apply (release_spec with "[-HΦ Err Reply Hcred1 Hcred2 Hcred3]").
    {
      iFrame "HmuInv Hlocked".
      iNext.
      repeat (iExists _).
      iSplitR "HghostEph"; last iFrame.
      repeat (iExists _).
      iFrame "Hstate ∗#"; iFrame "%".
    }
    wp_pures.
    wp_storeField.
    iApply "HΦ".
    iFrame.
    iSplitL "Err Reply".
    {
      instantiate (1:=(ApplyReply.mkC _ _)).
      iExists _.
      iFrame.
      iExists 1%Qp.
      iApply is_slice_small_nil.
      done.
    }
    done.
  }
  wp_loadField.

  wp_if_destruct.
  { (* return ESealed *)
    wp_loadField.
    wp_apply (release_spec with "[-HΦ Err Reply Hcred1 Hcred2 Hcred3]").
    {
      iFrame "HmuInv Hlocked".
      iNext.
      repeat (iExists _).
      iSplitR "HghostEph"; last iFrame.
      repeat (iExists _).
      rewrite Heqb0 Heqb.
      iFrame "∗#"; iFrame "%".
    }
    wp_pures.
    wp_storeField.
    iApply ("HΦ" $! _ (ApplyReply.mkC 1 [])).
    iFrame.
    iExists _, 1%Qp; iFrame.
    iApply is_slice_small_nil.
    done.
  }

  (* make ephemeral proposal *)
  iApply fupd_wp.
  iMod (fupd_mask_subseteq (↑pbN)) as "Hmask".
  { set_solver. }
  iMod (apply_eph_step with "Hupd HghostEph") as "(HghostEph & #Hprop_lb & #Hprop_facts & #Hprim_facts)".
  { done. }
  { done. }
  iMod "Hmask" as "_".
  iModIntro.

  iDestruct (is_StateMachine_acc_apply with "HisSm") as "HH".
  iNamed "HH".
  wp_loadField.
  wp_loadField.

  wp_apply ("HapplySpec" with "[HisSm $Hstate $Hsl]").
  {
    iSplitL ""; first done.
    iIntros "Hghost".
    iMod (applybackup_step with "Hprop_lb Hprop_facts Hprim_facts Hghost") as "Hghost".
    { by rewrite last_snoc. }
    { unfold get_rwops. rewrite fmap_app. rewrite app_length. done. }
    iModIntro.
    rewrite /get_rwops fmap_app /=.
    iExact "Hghost".
  }
  iIntros (reply_sl q waitFn) "(Hreply & Hstate & HwaitSpec)".

  wp_pures.
  wp_storeField.
  wp_loadField.
  wp_pures.
  wp_loadField.
  wp_apply (std_proof.wp_SumAssumeNoOverflow).
  iIntros "%Hno_overflow".
  wp_storeField.
  wp_loadField.
  wp_pures.
  wp_loadField.
  wp_pures.
  wp_loadField.
  wp_pures.
  wp_loadField.

  wp_apply (release_spec with "[-HΦ Hreply Err Reply Hlc1 Hlc2 HwaitSpec]").
  {
    iFrame "HmuInv Hlocked".
    iNext.
    repeat (iExists _).
    iSplitR "HghostEph"; last iFrame.
    repeat (iExists _).
    rewrite /= Heqb Heqb0 /=.
    replace (get_rwops (st.(server.ops_full_eph) ++ [(op, Q)])) with (get_rwops st.(server.ops_full_eph) ++ [op]); last first.
    {
      unfold get_rwops. rewrite fmap_app. done.
    }
    iFrame "∗#".
    rewrite app_length /=.
    admit. (* FIXME: overflow reasoning *)
  }

  wp_pures.

  wp_apply (wp_NewWaitGroup_free).
  iIntros (wg) "Hwg".
  wp_pures.

  wp_apply (wp_allocStruct).
  { econstructor; eauto. }
  iIntros (Hargs) "Hargs".
  iDestruct (struct_fields_split with "Hargs") as "HH".
  iNamed "HH".
  iMod (readonly_alloc_1 with "epoch") as "#Hargs_epoch".
  iMod (readonly_alloc_1 with "index") as "#Hargs_index".
  iMod (readonly_alloc_1 with "op") as "#Hargs_op".
  wp_pures.
  rewrite Heqb.
  iDestruct "Hprimary" as "[%Hbad|Hprimary]"; first by exfalso.
  iNamed "Hprimary".
  iMod (readonly_load with "Hclerkss_sl") as (?) "Hclerkss_sl2".

  iDestruct (is_slice_small_sz with "Hclerkss_sl2") as %Hclerkss_sz.

  wp_apply (wp_random).
  iIntros (randint) "_".
  wp_apply (wp_slice_len).
  wp_pures.
  set (clerkIdx:=(word.modu randint clerks_sl.(Slice.sz))).

  assert (int.nat clerkIdx < length clerkss) as Hlookup_clerks.
  { (* FIXME: better lemmas about mod? *)
    rewrite Hclerkss_sz.
    unfold clerkIdx.
    rewrite Hclerkss_len in Hclerkss_sz.
    replace (clerks_sl.(Slice.sz)) with (U64 (32)); last first.
    {
      unfold numClerks in Hclerkss_sz.
      word.
    }
    enough (int.Z randint `mod` 32 < int.Z 32)%Z.
    { word. }
    apply Z.mod_pos_bound.
    word.
  }

  assert (∃ clerks_sl_inner, clerkss !! int.nat clerkIdx%Z = Some clerks_sl_inner) as [clerks_sl_inner Hclerkss_lookup].
  {
    apply list_lookup_lt.
    rewrite Hclerkss_len.
    word.
  }

  wp_apply (wp_SliceGet with "[$Hclerkss_sl2]").
  { done. }
  iIntros "Hclerkss_sl2".
  wp_pures.

  wp_apply (wp_slice_len).
  wp_apply (wp_new_slice).
  { done. }
  iIntros (errs_sl) "Herrs_sl".
  wp_pures.
  iApply fupd_wp.
  iMod (fupd_mask_subseteq (↑pbN)) as "Hmask".
  { set_solver. }
  iMod (free_WaitGroup_alloc pbN _
          (λ i,
            ∃ (err:u64) γsrv',
            ⌜backups !! int.nat i = Some γsrv'⌝ ∗
            readonly ((errs_sl.(Slice.ptr) +ₗ[uint64T] int.Z i)↦[uint64T] #err) ∗
            □ if (decide (err = U64 0)) then
              is_accepted_lb γsrv' st.(server.epoch) (st.(server.ops_full_eph) ++ [_])
            else
              True
          )%I
         with "Hwg") as (γwg) "Hwg".
  iMod "Hmask".
  iModIntro.

  iDestruct (big_sepL_lookup_acc with "Hclerkss_rpc") as "[Hclerks_rpc _]".
  { done. }
  iNamed "Hclerks_rpc".

  iMod (readonly_load with "Hclerks_sl") as (?) "Hclerks_sl2".
  wp_apply (wp_forSlice (λ j, (own_WaitGroup pbN wg γwg j _) ∗
                              (errs_sl.(Slice.ptr) +ₗ[uint64T] int.Z j)↦∗[uint64T] (replicate (int.nat clerks_sl_inner.(Slice.sz) - int.nat j) #0)
                        )%I with "[] [Hwg Herrs_sl $Hclerks_sl2]").
  2: {
    iFrame "Hwg".
    (* FIXME: slice unfolding; want a subslice library or something *)
    unfold slice.is_slice. unfold slice.is_slice_small.
    iDestruct "Herrs_sl" as "[[Herrs_sl %Hlen] _]".
    destruct Hlen as [Hlen _].
    rewrite replicate_length in Hlen.
    rewrite Hlen.
    iExactEq "Herrs_sl".
    simpl.
    replace (1 * int.Z _)%Z with (0%Z) by word.
    rewrite loc_add_0.
    replace (int.nat _ - int.nat 0) with (int.nat errs_sl.(Slice.sz)) by word.
    done.
  }
  {
    iIntros (i ck).
    clear Φ.
    iIntros (Φ) "!# ([Hwg Herr_ptrs]& %Hi_ineq & %Hlookup) HΦ".
    wp_pures.
    wp_apply (wp_WaitGroup__Add with "[$Hwg]").
    { word. }
    iIntros "[Hwg Hwg_tok]".
    wp_pures.
    replace (int.nat clerks_sl_inner.(Slice.sz) - int.nat i) with (S (int.nat clerks_sl_inner.(Slice.sz) - (int.nat (word.add i 1)))); last first.
    { word. }
    rewrite replicate_S.
    iDestruct (array_cons with "Herr_ptrs") as "[Herr_ptr Herr_ptrs]".
    (* use wgTok to set errs_sl *)
    iDestruct (own_WaitGroup_to_is_WaitGroup with "[$Hwg]") as "#His_wg".
    wp_apply (wp_fork with "[Hwg_tok Herr_ptr]").
    {
      iNext.
      iDestruct (big_sepL2_lookup_1_some with "Hclerks_rpc") as %[γsrv' Hlookupγ].
      { done. }
      iDestruct (big_sepL2_lookup_acc with "Hclerks_rpc") as "Hclerk_rpc".
      { done. }
      { done. }
      iDestruct "Hclerk_rpc" as "[[Hclerk_rpc Hepoch_lb] _]".

      wp_pures.
      wp_forBreak_cond.
      wp_pures.

      wp_apply (wp_Clerk__ApplyAsBackup with "[$Hclerk_rpc $Hepoch_lb]").
      {
        iFrame "Hprop_lb Hprop_facts #".
        iPureIntro.
        rewrite last_app.
        simpl.
        split; eauto.
        split; eauto.
        rewrite /no_overflow in Hno_overflow HnextIndexNoOverflow.
        split.
        { rewrite /get_rwops fmap_app app_length. simpl.
          rewrite HnextIndexNoOverflow /get_rwops.
          word.
        }
        word.
      }
      iIntros (err) "#Hpost".

      wp_pures.
      wp_bind (#(bool_decide _) || _)%E.
      wp_apply (wp_or with "[]"); first iAccu.
      { wp_pures. by iModIntro. }
      { iIntros (_) "_". wp_pures. by iModIntro. }
      iIntros "_".
      wp_if_destruct.
      {
        wp_pures.
        iLeft.
        iFrame "∗".
        by iPureIntro.
      }

      (* FIXME: slice unfolding *)
      unfold SliceSet.
      wp_pures.
      unfold slice.ptr.
      wp_pures.
      wp_store.
      iRight.
      iModIntro.
      iSplitR; first by iPureIntro.

      iMod (readonly_alloc_1 with "Herr_ptr") as "#Herr_ptr".
      wp_apply (wp_WaitGroup__Done with "[$Hwg_tok $His_wg Herr_ptr Hpost]").
      {
        iModIntro.
        iExists _, _.
        iSplitL ""; first done.
        iFrame "#".
      }
      done.
    }
    iApply "HΦ".
    iFrame "Hwg".
    iExactEq "Herr_ptrs".
    f_equal.
    rewrite /ty_size //=.
    rewrite loc_add_assoc.
    f_equal.
    word.
  }
  iIntros "[[Hwg _] _]".
  wp_pures.

  wp_apply (wp_WaitGroup__Wait with "Hwg").
  iIntros "#Hwg_post".
  wp_pures.

  wp_apply "HwaitSpec".
  iIntros "Hprimary_acc_lb".
  iDestruct "Hprimary_acc_lb" as "(_ & _ & #Hprimary_acc_lb)".

  wp_apply (wp_ref_to).
  { repeat econstructor. }
  iIntros (err_ptr) "Herr".
  wp_pures.

  wp_apply (wp_ref_to).
  { do 2 econstructor. }
  iIntros (j_ptr) "Hi".
  wp_pures.

  set (conf:=(γsrv::backups)).
  iAssert (∃ (j err:u64),
              "Hj" ∷ j_ptr ↦[uint64T] #j ∗
              "%Hj_ub" ∷ ⌜int.nat j ≤ length clerks⌝ ∗
              "Herr" ∷ err_ptr ↦[uint64T] #err ∗
              "#Hrest" ∷ □ if (decide (err = (U64 0)%Z)) then
                (∀ (k:u64) γsrv', ⌜int.nat k ≤ int.nat j⌝ -∗ ⌜conf !! (int.nat k) = Some γsrv'⌝ -∗
                  is_accepted_lb γsrv' st.(server.epoch) (st.(server.ops_full_eph) ++ [_]))
              else
                True
          )%I with "[Hi Herr]" as "Hloop".
  {
    iExists _, _.
    iFrame.
    destruct (decide (_)).
    {
      iIntros.
      iSplitL "".
      { iPureIntro. word. }
      iModIntro.
      iIntros.
      replace (int.nat 0%Z) with (0) in H by word.
      replace (int.nat k) with (0) in H0 by word.
      unfold conf in H0.
      simpl in H0.
      injection H0 as <-.
      iFrame "Hprimary_acc_lb".
    }
    {
      done.
    }
  }
  wp_forBreak_cond.
  wp_pures.
  iNamed "Hloop".
  wp_load.
  wp_apply wp_slice_len.

  iMod (readonly_load with "Hclerks_sl") as (?) "Htemp".
  iDestruct (is_slice_small_sz with "Htemp") as %Hclerk_sz.
  iClear "Htemp".

  wp_pures.
  wp_if_destruct.
  {
    wp_pures.
    wp_load.
    unfold SliceGet.
    wp_call.
    iDestruct (big_sepS_elem_of_acc _ _ j with "Hwg_post") as "[HH _]".
    { set_solver. }
    iDestruct "HH" as "[%Hbad|HH]".
    { exfalso. word. }
    iDestruct "HH" as (??) "(%HbackupLookup & Herr2 & Hpost)".
    wp_apply (wp_slice_ptr).
    wp_pure1.
    iEval (simpl) in "Herr2".
    iMod (readonly_load with "Herr2") as (?) "Herr3".
    wp_load.
    wp_pures.
    destruct (bool_decide (_)) as [] eqn:Herr; wp_pures.
    {
      rewrite bool_decide_eq_true in Herr.
      replace (err0) with (U64 0%Z) by naive_solver.
      wp_pures.
      wp_load; wp_store.
      iLeft.
      iModIntro.
      iSplitL ""; first done.
      iFrame "∗".
      iExists _, _.
      iFrame "Hj Herr".
      iSplitL "".
      { iPureIntro. word. }
      iModIntro.
      destruct (decide (err = 0%Z)).
      {
        iIntros.
        assert (int.nat k ≤ int.nat j ∨ int.nat k = int.nat (word.add j 1%Z)) as [|].
        {
          replace (int.nat (word.add j 1%Z)) with (int.nat j + 1) in * by word.
          word.
        }
        {
          by iApply "Hrest".
        }
        {
          destruct (decide (_)); last by exfalso.
          replace (γsrv'0) with (γsrv'); last first.
          {
            rewrite H1 in H0.
            replace (int.nat (word.add j 1%Z)) with (S (int.nat j)) in H0 by word.
            unfold conf in H0.
            rewrite lookup_cons in H0.
            naive_solver.
          }
          iDestruct "Hpost" as "#$".
        }
      }
      {
        done.
      }
    }
    {
      wp_store.
      wp_pures.
      wp_load; wp_store.
      iLeft.
      iModIntro.
      iSplitL ""; first done.
      iFrame "∗".
      iExists _, _.
      iFrame "Hj Herr".
      destruct (decide (err0 = _)).
      { exfalso. naive_solver. }
      iPureIntro.
      word.
    }
  }
  iRight.
  iModIntro.
  iSplitL ""; first done.
  wp_pure1_credit "Hlc3".
  wp_load.
  wp_pures.

  wp_storeField.
  wp_load.

  destruct (decide (err = 0%Z)); last first.
  {
    wp_pures.
    rewrite bool_decide_false; last naive_solver.
    wp_pures.
    iApply ("HΦ" $! reply_ptr (ApplyReply.mkC _ _)).
    iFrame.
    simpl.
    rewrite decide_False; last naive_solver.
    iModIntro.
    iSplitL; last done.
    iExists _, _; iFrame.
  }
  (* otherwise, no error *)
  iMod (ghost_commit with "Hsys_inv [Hrest] Hprop_lb Hprop_facts") as "#Hcommit".
  {
    iExists _; iFrame "#".
    iIntros.
    apply elem_of_list_lookup_1 in H as [k Hlookup_conf].
    replace (int.nat j) with (length clerks); last first.
    { word. }
    epose proof (lookup_lt_Some _ _ _ Hlookup_conf) as HH.
    replace (k) with (int.nat k) in *; last first.
    {
      rewrite cons_length in HH.
      word.
    }
    iApply ("Hrest" $! k).
    { iPureIntro.
      unfold conf in HH.
      rewrite cons_length in HH.
      lia. }
    { done. }
  }

  wp_pures.
  rewrite bool_decide_true; last naive_solver.
  wp_pures.
  wp_loadField.
  wp_apply (acquire_spec with "HmuInv").
  iIntros "[Hlocked Hown]".
  wp_pures.
  iClear "HopAppliedConds_conds HisSm".
  iNamed "Hown".
  iNamed "Hvol".
  wp_loadField.
  wp_pures.
  wp_apply (wp_and with "HcommittedNextIndex").
  { wp_pures. iModIntro. iPureIntro. done. }
  { iIntros. wp_loadField. wp_pures. iModIntro. iFrame.
    done.
  }
  iIntros "HcommittedNextIndex".
  wp_if_destruct.
  {
    destruct Heqb2 as [HepochEq HcommittedIneq].
    injection HepochEq as HepochEq.
    subst.
    wp_storeField.
    wp_loadField.
    wp_apply (wp_condBroadcast with "[]").
    { admit. (* iFrame "#". *) }
    wp_pures.
    wp_loadField.

    iApply fupd_wp.
    iClear "Hmask".
    iMod (fupd_mask_subseteq (↑pbN)) as "Hmask".
    { set_solver. }
    rewrite -HepochEq.
    iMod (apply_commit_step with "Hcommit Hprop_lb HghostEph") as "HghostEph".
    iMod "Hmask" as "_". iModIntro.
    wp_apply (release_spec with "[-HΦ Hlc1 Hlc2 Hlc3 Hreply Err Reply]").
    {
      iFrame "Hlocked HmuInv".
      iNext.

      repeat iExists _.
      iSplitR "HghostEph"; last iFrame.
      repeat iExists _.
      iFrame "∗ #".
      simpl.
      iApply to_named.
      iExactEq "HcommittedNextIndex".
      repeat f_equal.
      unfold no_overflow in HnextIndexNoOverflow.
      admit. (* FIXME: list length overflow *)
    }
    wp_pures.
    iModIntro.
    iApply ("HΦ" $! reply_ptr (ApplyReply.mkC _ _)).
    iFrame "Hlc1 Hlc2 Hlc3".
    iSplitL.
    { iExists _, _. iFrame. }
    simpl.
    destruct (decide _); last first.
    { exfalso. done. }
    iExists _; iFrame "Hcommit".
    done.
  }

  wp_loadField.
  wp_apply (release_spec with "[-HΦ Hlc1 Hlc2 Hlc3 Hreply Err Reply]").
  {
    iFrame "Hlocked HmuInv".
    iNext.
    repeat iExists _.
    iSplitR "HghostEph"; last iFrame.
    repeat iExists _.
    iFrame "∗#"; iFrame "%".
  }
  wp_pures.
  iModIntro.
  iApply ("HΦ" $! reply_ptr (ApplyReply.mkC _ _)).
  simpl.
  iFrame "Hlc1 Hlc2 Hlc3".
  iSplitL.
  {
    iExists _, _; iFrame.
  }
  destruct (decide _); last first.
  { exfalso. done. }
  iExists _.
  iFrame "Hcommit".
  done.
Admitted.

Lemma wp_Server__Apply (s:loc) γlog γp γpsrv γ γsrv op_sl op (enc_op:list u8) Ψ (Φ: val → iProp Σ) :
  is_Server s γp γpsrv γ γsrv -∗
  readonly (is_slice_small op_sl byteT 1 enc_op) -∗
  (∀ reply, Ψ reply -∗ ∀ reply_ptr, ApplyReply.own_q reply_ptr reply -∗ Φ #reply_ptr) -∗
  Apply_core_spec γ γlog op enc_op Ψ -∗
  WP (pb.Server__Apply #s (slice_val op_sl)) {{ Φ }}
.
Proof using Type*.
  iIntros "#Hsrv #Hop_sl".
  iIntros "HΨ HΦ".
  iApply (wp_frame_wand with "HΨ").
  iDestruct "HΦ" as "(%Hop_enc & #Hinv & #Hupd & Hfail_Φ)".
  iMod (ghost_var_alloc (())) as (γtok) "Htok".
  set (OpPred := 
(λ ops, inv escrowN (
        Ψ (ApplyReply.mkC 0 (compute_reply ops op)) ∨
          ghost_var γtok 1 ()
        ))).

  iMod (saved_pred_alloc OpPred DfracDiscarded) as (γghost_op) "#Hsaved"; first done.
  iApply wp_fupd.
  wp_apply (wp_Server__Apply_internal _ _ _ _ _
      _ _ op γghost_op
             with "[$Hsrv $Hop_sl Hupd]").
  {
    iSplitL ""; first done.
    iInv "Hinv" as "HH" "Hclose".
    iDestruct "HH" as (?) "(Hghost & >Hlog & #HQs)".
    iDestruct "Hghost" as (σgnames) "(>Hghost&>%Hfst_eq&#Hsaved')".
    iMod (fupd_mask_subseteq (⊤∖↑pbN)) as "Hmask".
    {
      assert ((↑ghostN:coPset) ⊆ (↑pbN:coPset)).
      { apply nclose_subseteq. }
      assert ((↑appN:coPset) ⊆ (↑pbN:coPset)).
      { apply nclose_subseteq. }
      set_solver.
    }
    iMod "Hupd".
    iModIntro.
    iDestruct "Hupd" as (σ0) "[Hlog2 Hupd]".
    iDestruct (own_valid_2 with "Hlog Hlog2") as %Hvalid.
    apply mono_list_auth_dfrac_op_valid_L in Hvalid.
    destruct Hvalid as [_ <-].
    iExists _; iFrame.
    iIntros "Hghost".
    iMod (own_update_2 with "Hlog Hlog2") as "Hlog".
    {
      rewrite -mono_list_auth_dfrac_op.
      rewrite dfrac_op_own.
      rewrite Qp.half_half.
      apply mono_list_update.
      instantiate (1:=_ ++ [op]).
      by apply prefix_app_r.
    }
    iEval (rewrite -Qp.half_half -dfrac_op_own mono_list_auth_dfrac_op) in "Hlog".
    iDestruct "Hlog" as "[Hlog Hlog2]".
    iMod ("Hupd" with "Hlog2") as "Hupd".

    iAssert (|={↑escrowN}=> inv escrowN ((Ψ (ApplyReply.mkC 0 (compute_reply (get_rwops opsfullQ) op)))
                                  ∨ ghost_var γtok 1 ()))%I
            with "[Hupd]" as "Hinv2".
    {
      iMod (inv_alloc with "[-]") as "$"; last done.
      iNext.
      iIntros.
      iLeft.
      iIntros.
      iApply "Hupd".
    }
    iMod "Hmask" as "_".
    iMod (fupd_mask_subseteq (↑escrowN)) as "Hmask".
    {
      assert ((↑escrowN:coPset) ## (↑ghostN:coPset)).
      { by apply ndot_ne_disjoint. }
      assert ((↑escrowN:coPset) ## (↑appN:coPset)).
      { by apply ndot_ne_disjoint. }
      set_solver.
    }
    iMod "Hinv2" as "#HΦ_inv".
    iMod "Hmask".

    iMod ("Hclose" with "[HQs Hghost Hlog]").
    {
      iNext.
      iExists (opsfullQ ++ [(op, OpPred)]); iFrame.
      iSplitL "Hghost".
      { iExists _. iFrame.
        iSplitL.
        { iPureIntro. rewrite ?fmap_app /=. congruence. }
        rewrite ?fmap_app. iApply big_sepL2_app.
        { iFrame "Hsaved'". }
        iApply big_sepL2_singleton. iFrame "Hsaved".
      }
      rewrite /get_rwops fmap_app.
      iFrame.

      iModIntro.
      iIntros.
      apply prefix_app_cases in H as [Hprefix_of_old|Hnew].
      {
        iApply "HQs".
        { done. }
        { done. }
      }
      {
        rewrite Hnew in H0.
        assert (opsfullQ = opsPrePre) as ->.
        { (* TODO: list_solver. *)
          apply (f_equal reverse) in H0.
          rewrite reverse_snoc in H0.
          rewrite reverse_snoc in H0.
          inversion H0.
          apply (f_equal reverse) in H2.
          rewrite reverse_involutive in H2.
          rewrite reverse_involutive in H2.
          done.
        }
        eassert (_ = lastEnt) as <-.
        { eapply (suffix_snoc_inv_1 _ _ _ opsPrePre). rewrite -H0.
          done. }
        simpl.
        unfold OpPred.
        iFrame "#".
      }
    }
    done.
  }
  iIntros (err reply).
  iIntros "(Hcred & Hcred2 & Hcred3 & Hreply & Hpost)".
  destruct (decide (reply.(ApplyReply.err) = U64 0)).
  { (* no error *)
    iNamed "Hreply".
    rewrite e.
    iDestruct "Hpost" as (?) "[%Hrep #Hghost_lb]".
    rewrite Hrep.
    iInv "Hinv" as "HH" "Hclose".
    {
      iDestruct "HH" as (?) "(Hghost & >Hlog & #HQs)".
      iDestruct "Hghost" as (σgnames) "(>Hghost&>%Hfst_eq&#Hsaved')".
      iApply (lc_fupd_add_later with "Hcred").
      iNext.
      iDestruct (own_valid_2 with "Hghost Hghost_lb") as %Hvalid.
      rewrite mono_list_both_dfrac_valid_L in Hvalid.
      destruct Hvalid as [_ Hvalid].

      destruct Hvalid as (σtail&Hvalid').
      subst.
      iDestruct (big_sepL2_length with "Hsaved'") as %Hlen.
      rewrite ?fmap_length in Hlen.
      assert (∃ σ0a op' Q' σ0b,
                 opsfullQ = σ0a ++ [(op', Q')] ++ σ0b ∧
                 length σ0a = length opsfull ∧
                 length σ0b = length σtail) as (σ0a&op'&Q'&σ0b&Heq0&Hlena&Hlenb).
      {
        destruct (nth_error opsfullQ (length opsfull)) as [(op', Q')|] eqn:Hnth; last first.
        { apply nth_error_None in Hnth. rewrite ?app_length /= in Hlen. lia. }
        edestruct (nth_error_split opsfullQ (length opsfull)) as (l1&l2&Heq&Hlen'); eauto.
        eexists l1, _, _, l2. rewrite Heq /=; split_and!; eauto.
        rewrite Heq ?app_length /= in Hlen. rewrite Hlen' in Hlen. clear -Hlen.
        (* weird, lia fails directly but if you replace lengths with a nat then it works... *)
        remember (length l2) as k.
        remember (length σtail) as k'. rewrite Heqk in Hlen. rewrite -Heqk' in Hlen. lia.
      }

      iDestruct ("HQs" $! (σ0a ++ [(op', Q')]) _ (_, _) with "[] []") as "#HQ".
      { rewrite Heq0. iPureIntro; eexists; eauto. rewrite app_assoc.  done. }
      { done. } 
      simpl.
      iMod ("Hclose" with "[Hghost Hlog]") as "_".
      {
        iNext.
        iExists _; iFrame "∗#".
        iExists _. iFrame.
        iSplit.
        { iPureIntro. auto. }
        iApply "Hsaved'".
      }

      rewrite Heq0. rewrite ?fmap_app -app_assoc. iDestruct (big_sepL2_app_inv with "Hsaved'") as "(H1&H2)".
      { left. rewrite ?fmap_length //. }

      iEval (simpl) in "H2". iDestruct "H2" as "(HsavedQ'&?)".
      iDestruct (saved_pred_agree _ _ _ _  _ (get_rwops σ0a) with "Hsaved [$]") as "HQequiv".
      iApply (lc_fupd_add_later with "[$]"). iNext.
      iRewrite -"HQequiv" in "HQ".

      iInv "HQ" as "Hescrow" "Hclose".
      iDestruct "Hescrow" as "[HΦ|>Hbad]"; last first.
      {
        iDestruct (ghost_var_valid_2 with "Htok Hbad") as %Hbad.
        exfalso. naive_solver.
      }
      iMod ("Hclose" with "[$Htok]").
      iMod (lc_fupd_elim_later with "Hcred2 HΦ") as "HΦ".
      iModIntro.
      iIntros "HΨ".
      iApply ("HΨ" with "HΦ").
      iExists _, _.
      iFrame.
      simpl.
      rewrite /named.
      iExactEq "Hrepy_ret_sl".
      { repeat f_equal.
        rewrite Heq0 in Hfst_eq. rewrite ?fmap_app -app_assoc in Hfst_eq.
        apply app_inj_1 in Hfst_eq; last (rewrite ?fmap_length //).
        destruct Hfst_eq as (Hfst_eq&_).
        done.
      }
    }
  }
  {
    iIntros.
    iNamed "Hreply".
    iModIntro.
    iIntros "HΨ".
    iApply ("HΨ" with "[Hfail_Φ]").
    {
      iApply "Hfail_Φ".
      done.
    }
    iExists _, _.
    iFrame.
  }
Qed.

End pb_apply_proof.
