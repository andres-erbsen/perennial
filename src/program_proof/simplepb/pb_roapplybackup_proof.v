From Perennial.program_proof Require Import grove_prelude.
From Goose.github_com.mit_pdos.gokv.simplepb Require Export pb.
From Perennial.program_proof.simplepb Require Import pb_ghost.
From Perennial.goose_lang.lib Require Import waitgroup.
From iris.base_logic Require Export lib.ghost_var mono_nat.
From iris.algebra Require Import dfrac_agree mono_list.
From Perennial.program_proof.simplepb Require Import pb_definitions pb_marshal_proof pb_applybackup_proof.
From Perennial.program_proof Require Import marshal_stateless_proof.
From Perennial.program_proof.reconnectclient Require Import proof.
From RecordUpdate Require Import RecordSet.
Import RecordSetNotations.

Section pb_roapplybackup_proof.

Context `{!heapGS Σ}.
Context {pb_record:Sm.t}.

Notation OpType := (Sm.OpType pb_record).
Notation has_op_encoding := (Sm.has_op_encoding pb_record).
Notation compute_reply := (Sm.compute_reply pb_record).
Notation pbG := (pbG (pb_record:=pb_record)).
Notation get_rwops := (get_rwops (pb_record:=pb_record)).

Context `{!waitgroupG Σ}.
Context `{!pbG Σ}.

(* Clerk specs *)
Lemma wp_Clerk__RoApplyAsBackup γ γsrv ck args_ptr (epoch nextIndex:u64) opsfull :
  {{{
        "#Hck" ∷ is_Clerk ck γ γsrv ∗
        "#HepochLb" ∷ is_epoch_lb γsrv epoch ∗
        "#Hprop_lb" ∷ is_proposal_lb γ epoch opsfull ∗
        "#Hprop_facts" ∷ is_proposal_facts γ epoch opsfull ∗
        "%HnextIndex" ∷ ⌜length (get_rwops opsfull) = int.nat nextIndex⌝ ∗

        "#HargEpoch" ∷ readonly (args_ptr ↦[pb.RoApplyAsBackupArgs :: "epoch"] #epoch) ∗
        "#HargIndex" ∷ readonly (args_ptr ↦[pb.RoApplyAsBackupArgs :: "nextIndex"] #nextIndex)
  }}}
    Clerk__RoApplyAsBackup #ck #args_ptr
  {{{
        (err:u64), RET #err; □ if (decide (err = 0)) then
                               is_accepted_lb γsrv epoch opsfull
                             else True
  }}}.
Proof.
  iIntros (Φ) "Hpre HΦ".
  iNamed "Hpre".
  wp_call.
  wp_apply (wp_ref_of_zero).
  { done. }
  iIntros (rep) "Hrep".
  wp_pures.
  iNamed "Hck".
  wp_apply (RoApplyAsBackupArgs.wp_Encode with "[]").
  {
    instantiate (1:=(RoApplyAsBackupArgs.mkC _ _)).
    iFrame "#".
  }
  iIntros (enc_args enc_args_sl) "(%Henc_args & Henc_args_sl)".
  wp_loadField.
  iDestruct (is_slice_to_small with "Henc_args_sl") as "Henc_args_sl".
  wp_apply (wp_frame_wand with "HΦ").
  rewrite is_pb_host_unfold.
  iNamed "Hsrv".
  wp_apply (wp_ReconnectingClient__Call2 with "Hcl_rpc [] Henc_args_sl Hrep").
  {
    iDestruct "Hsrv" as "(_ & _ & _ & _ & _ & $ & _)".
  }
  { (* Successful RPC *)
    iModIntro.
    iNext.
    unfold RoApplyAsBackup_spec.
    iExists _, _.
    iSplitR; first done.
    iFrame "#%".
    iSplit.
    { (* No error from RPC, Apply was accepted *)
      iIntros "#Hacc_lb".
      iIntros (?) "%Henc_rep Hargs_sl".
      iIntros (?) "Hrep Hrep_sl".
      wp_pures.
      wp_load.

      (* FIXME: separate lemma *)
      wp_call.
      rewrite Henc_rep.
      wp_apply (wp_ReadInt with "Hrep_sl").
      iIntros (?) "_".
      wp_pures.
      iModIntro.
      iIntros "HΦ".
      iApply "HΦ".
      iModIntro.
      iFrame "#".
    }
    { (* Apply was rejected by the server (e.g. stale epoch number) *)
      iIntros (err) "%Herr_nz".
      iIntros.
      wp_pures.
      wp_load.
      wp_call.
      rewrite H.
      wp_apply (wp_ReadInt with "[$]").
      iIntros.
      wp_pures.
      iModIntro.
      iIntros "HΦ".
      iApply "HΦ".
      iFrame.
      iModIntro.
      destruct (decide _).
      {
        exfalso. done.
      }
      {
        done.
      }
    }
  }
  { (* RPC error *)
    iIntros.
    wp_pures.
    wp_if_destruct.
    {
      iModIntro.
      iIntros "HΦ".
      iApply "HΦ".
      destruct (decide (_)).
      { exfalso. done. }
      { done. }
    }
    { exfalso. done. }
  }
Qed.

Lemma roapplybackup_step γ γsrv γeph st ops_full' sm own_StateMachine :
  int.nat st.(server.durableNextIndex) >= length (get_rwops ops_full') →
  st.(server.sealed) = false →
  is_proposal_lb γ st.(server.epoch) ops_full' -∗
  is_proposal_facts γ st.(server.epoch) ops_full' -∗
  is_StateMachine sm own_StateMachine (own_Server_ghost_f γ γsrv γeph) -∗
  own_StateMachine st.(server.epoch) (get_rwops st.(server.ops_full_eph)) false
               (own_Server_ghost_f γ γsrv γeph) -∗
  own_Server_ghost_eph_f st γ γsrv γeph -∗
  |NC={⊤,⊤}=> wpc_nval ⊤ (
    ∃ new_ops_full,
    ⌜get_rwops new_ops_full = get_rwops st.(server.ops_full_eph)⌝ ∗
    own_StateMachine st.(server.epoch) (get_rwops new_ops_full) false
                 (own_Server_ghost_f γ γsrv γeph) ∗
    own_Server_ghost_eph_f (st <| server.ops_full_eph := new_ops_full |> )γ γsrv γeph ∗
    is_accepted_lb γsrv st.(server.epoch) ops_full'
  )
.
Proof.
Admitted.

Lemma wp_Server__RoApplyAsBackup (s:loc) (args_ptr:loc) γ γsrv args opsfull Φ Ψ :
  is_Server s γ γsrv -∗
  RoApplyAsBackupArgs.own args_ptr args -∗
  (∀ (err:u64), Ψ err -∗ Φ #err) -∗
  RoApplyAsBackup_core_spec γ γsrv args opsfull Ψ -∗
  WP pb.Server__RoApplyAsBackup #s #args_ptr {{ Φ }}
.
Proof.
  iIntros "#HisSrv Hpre HΦ HΨ".
  iNamed "Hpre".
  iNamed "HisSrv".
  wp_call.
  wp_loadField.
  wp_apply (acquire_spec with "HmuInv").
  iIntros "[Hlocked Hown]".
  wp_pures.

  (* for loop to wait for previous op to be applied *)
  wp_bind (For _ _ _).
  wp_forBreak.
  wp_pures.

  iNamed "Hown".
  iNamed "Hvol".

  wp_bind ((_ > _) && _ && _)%E.
  wp_apply (wp_and2 with "[Hargs_index Hsealed HdurableNextIndex HnextIndex Hargs_epoch Hepoch]"); first iNamedAccu; iNamed 1.
  { do 2 wp_loadField. wp_pures. iModIntro. iFrame. done. }
  { do 2 wp_loadField. wp_pures. iModIntro. iFrame. done. }
  { wp_loadField. wp_pures. iModIntro. iFrame. done. }

  wp_if_destruct.
  { (* loop again *)
    wp_pures.
    wp_loadField.
    wp_apply (wp_condWait with "[-HΦ HΨ Hargs_epoch Hargs_index]").
    {
      iFrame "#".
      iFrame "Hlocked".
      repeat (iExists _).
      iSplitR "HghostEph"; last iFrame.
      repeat (iExists _).
      (* time iFrame "∗#%". *)
      time (iFrame "∗"; iFrame "#"; iFrame "%").
    }
    iIntros "[Hlocked Hown]".
    wp_pures.
    iLeft.
    iModIntro.
    iSplitR; first done.
    iFrame.
  }
  (* done looping *)
  wp_pures.
  iModIntro.
  iRight.
  iSplitR; first done.
  wp_pures.

  iNamed "HΨ".
  wp_loadField.
  wp_loadField.
  wp_if_destruct.
  { (* return error: epoch changed *)
    wp_loadField.
    wp_apply (release_spec with "[-HΦ HΨ]").
    {
      iFrame "HmuInv Hlocked".
      repeat (iExists _).
      iSplitR "HghostEph"; last iFrame.
      repeat (iExists _).
      time (iFrame "∗"; iFrame "#"; iFrame "%").
    }
    wp_pures.
    iModIntro.
    iApply "HΦ".
    iApply "HΨ".
    done.
  }

  wp_loadField.
  wp_if_destruct.
  { (* return error: sealed *)
    wp_loadField.
    wp_apply (release_spec with "[-HΦ HΨ]").
    {
      iFrame "HmuInv Hlocked".
      repeat (iExists _).
      iSplitR "HghostEph"; last iFrame.
      iNext.
      repeat (iExists _).
      rewrite Heqb0 Heqb1.
      time (iFrame "∗"; iFrame "#"; iFrame "%").
    }
    wp_pures.
    iModIntro.
    iApply "HΦ".
    iApply "HΨ".
    done.
  }

  wp_loadField.
  wp_loadField.
  wp_pure1_credit "Hlc".
  wp_if_destruct.
  {
    exfalso.
    repeat rewrite not_and_r in Heqb.
    destruct Heqb as [|[|]].
    { word. }
    { rewrite Heqb0 in H. done. }
    { done. }
  }

  rewrite -Heqb0.
  iMod (roapplybackup_step with "Hprop_lb Hprop_facts HisSm Hstate HghostEph") as "HH".
  { word. }
  { done. }

  wp_pures.
  wp_bind (struct.loadF _ _ _).
  wp_apply (wpc_nval_elim_wp with "HH").
  { done. }
  { done. }
  wp_loadField.
  wp_pures.
  iIntros "HH".
  iDestruct "HH" as (?) "(%Hnewops & Hstate & HghostEph & #Hacc_lb)".

  wp_apply (release_spec with "[-HΨ HΦ Hargs_epoch]").
  {
    iFrame "Hlocked HmuInv".
    iNext.
    repeat (iExists _).
    iSplitR "HghostEph"; last iFrame.
    repeat (iExists _).
    rewrite Heqb1.
    rewrite Hnewops.
    iFrame "∗#".
    iFrame "%".
  }
  wp_pures.
  iModIntro.
  iApply "HΦ".
  iLeft in "HΨ".
  iApply "HΨ".
  iFrame "#".
Qed.

End pb_roapplybackup_proof.
