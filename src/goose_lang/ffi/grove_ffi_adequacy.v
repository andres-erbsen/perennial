From Perennial.algebra Require Import gen_heap_names.
From Perennial.goose_lang Require Import lang notation typing lifting.
From Perennial.goose_lang.lib Require Import map.impl list.impl list_slice.
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.grove_prelude.

From Perennial.goose_lang Require Import adequacy recovery_adequacy dist_adequacy.
From Perennial.program_proof Require Import grove_prelude.

Set Default Proof Using "Type".

Section grove_ffi_adeq.

Theorem grove_ffi_dist_adequacy_failstop Σ `{hPre: !gooseGpreS Σ} (ebσs : list (expr * state)) g φinv :
  chan_msg_bounds g.(global_world).(grove_net) →
  Forall (λ σ, file_content_bounds σ.(world).(grove_node_files)) ebσs.*2 →
  (∀ HG : gooseGlobalGS Σ,
      ⊢@{iPropI Σ}
        ([∗ map] e↦ms ∈ g.(global_world).(grove_net), e c↦ ms) ={⊤}=∗
          (([∗ list] '(e, σ) ∈ ebσs,
                (* We reason about node running e with an arbitrary generation *)
                ∀ HL : gooseLocalGS Σ,
                  ([∗ map] f ↦ c ∈ σ.(world).(grove_node_files), f f↦ c)
                    ={⊤}=∗ ∃ Φ, wp NotStuck ⊤ e Φ) ∗
          (∀ g', ffi_global_ctx goose_ffiGlobalGS g'.(global_world) ={⊤,∅}=∗ ⌜ φinv g' ⌝) )) →
  dist_adequate_failstop (ffi_sem:=grove_semantics) ebσs g (λ g, φinv g).
Proof.
  intros HINITG HINIT H. eapply goose_dist_adequacy_failstop; eauto.
  { simpl.  intros σ Hσ. eapply Forall_forall in HINIT; last done. eauto. }
  intros. iIntros "Hchan". iMod (H HG with "Hchan") as "(H1&H2)".
  iModIntro. iSplitL "H1".
  { iApply (big_sepL_mono with "H1").
    iIntros (? [e σ] Hlookup) "H". iIntros. iApply "H". done. }
  { eauto. }
Qed.
End grove_ffi_adeq.

