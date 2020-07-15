From iris.proofmode Require Import base tactics classes.
From iris.bi Require Export derived_laws derived_connectives.
From iris.algebra Require Import monoid cmra.
From iris.base_logic Require Import upred bi.
Import interface.bi.
Import derived_laws.bi.
Import derived_laws_later.bi.

Definition bi_atleast {PROP : bi} (k : nat) (P : PROP) : PROP := (▷^k False ∨ P)%I.
Arguments bi_atleast {_} _ _%I : simpl never.
Notation "◇_ n P" := (bi_atleast n P) (at level 20, n at level 9, P at level 20,
   format "◇_ n  P").
Instance: Params (@bi_atleast) 2 := {}.
Typeclasses Opaque bi_atleast.

Class AbsolutelyTimeless {PROP : bi} (P : PROP) := abs_timeless : ∀ k, ▷^k P ⊢ ◇_k P.
Arguments AbsolutelyTimeless {_} _%I : simpl never.
Arguments abs_timeless {_} _%I {_}.
Hint Mode AbsolutelyTimeless + ! : typeclass_instances.
Instance: Params (@AbsolutelyTimeless) 1 := {}.

Section PROP_laws.
Context {PROP : bi}.
Context {H: BiLöb PROP}.
Implicit Types φ : Prop.
Implicit Types P Q R : PROP.
Implicit Types Ps : list PROP.
Implicit Types A : Type.

Local Hint Resolve or_elim or_intro_l' or_intro_r' True_intro False_elim : core.
Local Hint Resolve and_elim_l' and_elim_r' and_intro forall_intro : core.

(* Force implicit argument PROP *)
Notation "P ⊢ Q" := (P ⊢@{PROP} Q).
Notation "P ⊣⊢ Q" := (P ⊣⊢@{PROP} Q).

Global Instance atleast_ne k : NonExpansive (@bi_atleast PROP k).
Proof. solve_proper. Qed.
Global Instance atleast_proper k : Proper ((⊣⊢) ==> (⊣⊢)) (@bi_atleast PROP k).
Proof. solve_proper. Qed.
Global Instance atleast_mono' k : Proper ((⊢) ==> (⊢)) (@bi_atleast PROP k).
Proof. solve_proper. Qed.
Global Instance atleast_flip_mono' k :
  Proper (flip (⊢) ==> flip (⊢)) (@bi_atleast PROP k).
Proof. solve_proper. Qed.

Section laws.
Context (k: nat).
Lemma atleast_intro P : P ⊢ ◇_k P.
Proof. rewrite /bi_atleast; auto. Qed.
Lemma atleast_mono P Q : (P ⊢ Q) → ◇_k P ⊢ ◇_k Q.
Proof. by intros ->. Qed.
Lemma atleast_idemp P : ◇_k ◇_k P ⊣⊢ ◇_k P.
Proof.
  apply (anti_symm _); rewrite /bi_atleast; auto.
Qed.

Lemma atleast_True : ◇_k True ⊣⊢ True.
Proof. rewrite /bi_atleast. apply (anti_symm _); auto. Qed.
Lemma atleast_emp `{!BiAffine PROP} : ◇_k emp ⊣⊢ emp.
Proof. by rewrite -True_emp atleast_True. Qed.
Lemma atleast_or P Q : ◇_k (P ∨ Q) ⊣⊢ ◇_k P ∨ ◇_k Q.
Proof.
  rewrite /bi_atleast. apply (anti_symm _); auto.
Qed.
Lemma atleast_and P Q : ◇_k (P ∧ Q) ⊣⊢ ◇_k P ∧ ◇_k Q.
Proof. by rewrite /bi_atleast or_and_l. Qed.
Lemma atleast_sep P Q : ◇_k (P ∗ Q) ⊣⊢ ◇_k P ∗ ◇_k Q.
Proof.
  rewrite /bi_atleast. apply (anti_symm _).
  - apply or_elim; last by auto using sep_mono.
    by rewrite -!or_intro_l -persistently_pure -laterN_sep -persistently_sep_dup.
  - rewrite sep_or_r !sep_or_l {1}(later_intro P) {1}(later_intro Q).
    rewrite -!laterN_sep !left_absorb.
    iIntros "[[?|(?&?)]|[(?&?)|?]]"; eauto.
Qed.
Lemma atleast_exist_2 {A} (Φ : A → PROP) : (∃ a, ◇_k Φ a) ⊢ ◇_k ∃ a, Φ a.
Proof. apply exist_elim=> a. by rewrite (exist_intro a). Qed.
Lemma atleast_exist `{Inhabited A} (Φ : A → PROP) :
  ◇_k (∃ a, Φ a) ⊣⊢ (∃ a, ◇_k Φ a).
Proof.
  apply (anti_symm _); [|by apply atleast_exist_2]. apply or_elim.
  - rewrite -(exist_intro inhabitant). by apply or_intro_l.
  - apply exist_mono=> a. apply atleast_intro.
Qed.
Lemma atleast_laterN_le P j (Hle: j ≤ k) : ◇_k ▷^j P ⊢ ▷^k P.
Proof. by rewrite /bi_atleast (laterN_le j k) // -laterN_or False_or. Qed.
Lemma atleast_laterN P : ◇_k ▷^k P ⊢ ▷^k P.
Proof. by apply atleast_laterN_le. Qed.
Lemma atleast_later P (Hle: 1 <= k): ◇_k ▷ P ⊢ ▷^k P.
Proof. rewrite (atleast_laterN_le _ 1) //=. Qed.
(*
Lemma atleast_laterN n P (Hle: 1 ≤ k) : ◇_k ▷^n P ⊢ ▷^n ◇_k P.
Proof. destruct n as [|n]; rewrite //= ?atleast_later //=. -atleast_intro. Qed.
*)
Lemma atleast_into_later P : ◇_k P ⊢ ▷^k P.
Proof. by rewrite -atleast_laterN -laterN_intro. Qed.
Lemma atleast_persistently P : ◇_k <pers> P ⊣⊢ <pers> ◇_k P.
Proof.
  by rewrite /bi_atleast persistently_or -laterN_persistently persistently_pure.
Qed.
Lemma atleast_affinely_2 P : <affine> ◇_k P ⊢ ◇_k <affine> P.
Proof. rewrite /bi_affinely atleast_and. auto using atleast_intro. Qed.
Lemma atleast_intuitionistically_2 P : □ ◇_k P ⊢ ◇_k □ P.
Proof. by rewrite /bi_intuitionistically -atleast_persistently atleast_affinely_2. Qed.
Lemma atleast_intuitionistically_if_2 p P : □?p ◇_k P ⊢ ◇_k □?p P.
Proof. destruct p; simpl; auto using atleast_intuitionistically_2. Qed.
Lemma atleast_absorbingly P : ◇_k <absorb> P ⊣⊢ <absorb> ◇_k P.
Proof. by rewrite /bi_absorbingly atleast_sep atleast_True. Qed.

Lemma atleast_frame_l P Q : P ∗ ◇_k Q ⊢ ◇_k (P ∗ Q).
Proof. by rewrite {1}(atleast_intro P) atleast_sep. Qed.
Lemma atleast_frame_r P Q : ◇_k P ∗ Q ⊢ ◇_k (P ∗ Q).
Proof. by rewrite {1}(atleast_intro Q) atleast_sep. Qed.

Lemma later_affinely_1 `{!AbsolutelyTimeless (PROP:=PROP) emp} P : ▷^k <affine> P ⊢ ◇_k <affine> ▷^k P.
Proof.
  rewrite /bi_affinely laterN_and (abs_timeless emp%I) atleast_and.
  by apply and_mono, atleast_intro.
Qed.

Global Instance atleast_persistent P : Persistent P → Persistent (◇_k P).
Proof. rewrite /bi_atleast; apply _. Qed.
Global Instance atleast_absorbing P : Absorbing P → Absorbing (◇_k P).
Proof. rewrite /bi_atleast; apply _. Qed.
(* AbsolutelyTimeless instances *)
Global Instance AbsolutelyTimeless_proper : Proper ((≡) ==> iff) (@AbsolutelyTimeless PROP).
Proof.
  rewrite /AbsolutelyTimeless.
  intros ?? Heq. split; intros ? k0.
  * rewrite -Heq; eauto.
  * rewrite Heq; eauto.
Qed.

End laws.

Global Instance and_abs_timeless P Q : AbsolutelyTimeless P → AbsolutelyTimeless Q → AbsolutelyTimeless (P ∧ Q).
Proof. intros ???; rewrite /AbsolutelyTimeless atleast_and laterN_and; auto. Qed.
Global Instance or_abs_timeless P Q : AbsolutelyTimeless P → AbsolutelyTimeless Q → AbsolutelyTimeless (P ∨ Q).
Proof. intros ???; rewrite /AbsolutelyTimeless atleast_or laterN_or; auto. Qed.

(*
Global Instance impl_abs_timeless `{!BiLöb PROP} P Q : AbsolutelyTimeless Q → AbsolutelyTimeless (P → Q).
Proof.
  rewrite /AbsolutelyTimeless=> HQ k. rewrite later_false_em.
  apply or_mono, impl_intro_l; first done.
  rewrite -{2}(löb Q). apply impl_intro_l.
  rewrite HQ /bi_except_0 !and_or_r. apply or_elim; last auto.
  by rewrite assoc (comm _ _ P) -assoc !impl_elim_r.
Qed.
*)
Global Instance sep_abs_timeless P Q: AbsolutelyTimeless P → AbsolutelyTimeless Q → AbsolutelyTimeless (P ∗ Q).
Proof.
  intros ???; rewrite /AbsolutelyTimeless atleast_sep laterN_sep; auto using sep_mono.
Qed.

(*
Global Instance wand_abs_timeless `{!BiLöb PROP} P Q : AbsolutelyTimeless Q → AbsolutelyTimeless (P -∗ Q).
Proof.
  rewrite /AbsolutelyTimeless=> HQ. rewrite later_false_em.
  apply or_mono, wand_intro_l; first done.
  rewrite -{2}(löb Q); apply impl_intro_l.
  rewrite HQ /bi_except_0 !and_or_r. apply or_elim; last auto.
  by rewrite (comm _ P) persistent_and_sep_assoc impl_elim_r wand_elim_l.
Qed.
*)
Global Instance persistently_abs_timeless P : AbsolutelyTimeless P → AbsolutelyTimeless (<pers> P).
Proof.
  intros ??. rewrite /AbsolutelyTimeless /bi_atleast laterN_persistently.
  by rewrite (abs_timeless P) /bi_except_0 persistently_or {1}persistently_elim.
Qed.

Global Instance affinely_abs_timeless P :
  AbsolutelyTimeless (PROP:=PROP) emp → AbsolutelyTimeless P → AbsolutelyTimeless (<affine> P).
Proof. rewrite /bi_affinely; apply _. Qed.
(*
Global Instance absorbingly_abs_timeless P : AbsolutelyTimeless P → AbsolutelyTimeless (<absorb> P).
Proof. rewrite /bi_absorbingly; apply _. Qed.
*)

Global Instance intuitionistically_abs_timeless P :
  AbsolutelyTimeless (PROP:=PROP) emp → AbsolutelyTimeless P → AbsolutelyTimeless (□ P).
Proof. rewrite /bi_intuitionistically; apply _. Qed.

Global Instance from_option_abs_timeless {A} P (Ψ : A → PROP) (mx : option A) :
  (∀ x, AbsolutelyTimeless (Ψ x)) → AbsolutelyTimeless P → AbsolutelyTimeless (from_option Ψ P mx).
Proof. destruct mx; apply _. Qed.
End PROP_laws.

Section uPred_laws.
Context {M: ucmraT}.
Implicit Types φ : Prop.
Implicit Types P Q R : (uPred M).
Implicit Types Ps : list (uPred M).
Implicit Types A : Type.


Notation "P ⊢ Q" := (P ⊢@{uPredI M} Q).
Notation "P ⊣⊢ Q" := (P ⊣⊢@{uPredI M} Q).

Lemma laterN_big n a x φ: ✓{n} x →  a ≤ n → (▷^a ⌜φ⌝ : uPred M)%I n x → φ.
Proof.
  induction 2 as [| ?? IHle].
  - induction a; repeat (rewrite //= || uPred.unseal).
    intros Hlater. apply IHa; auto using cmra_validN_S.
    move:Hlater; repeat (rewrite //= || uPred.unseal).
  - intros. apply IHle; auto using cmra_validN_S.
    eapply uPred_mono; eauto using cmra_validN_S.
Qed.

Lemma laterN_small n a x P: ✓{n} x →  n < a → (▷^a P : uPred M)%I n x.
Proof.
  induction 2.
  - induction n as [| n IHn]; [| move: IHn];
      repeat (rewrite //= || uPred.unseal).
    naive_solver eauto using cmra_validN_S.
  - induction n as [| n IHn]; [| move: IHle];
      repeat (rewrite //= || uPred.unseal).
    red; rewrite //=. intros.
    eapply (uPred_mono _ _ (S n)); eauto using cmra_validN_S.
Qed.

Lemma laterN_exist_big_inhabited A (Φ: A → uPred M) k n x:
  ✓{n} x →  k ≤ n → (▷^k uPred_exist_def (λ a : A, Φ a))%I n x →
  ∃ a : A, True.
Proof.
  induction 2 as [| ?? IHle].
  - induction k; repeat (rewrite //= || uPred.unseal).
    { destruct 1; eauto. }
    intros Hlater. apply IHk; auto using cmra_validN_S.
  - intros. apply IHle; auto using cmra_validN_S.
    eapply uPred_mono; eauto using cmra_validN_S.
Qed.

Local Hint Resolve or_elim or_intro_l' or_intro_r' True_intro False_elim : core.
Local Hint Resolve and_elim_l' and_elim_r' and_intro forall_intro : core.

Lemma laterN_exist_false A (Φ : A → uPred M) k:
  ▷^k (∃ a : A, Φ a) -∗ ▷^k False ∨ (∃ a : A, ▷^k Φ a).
Proof.
  split => n x Hval Hall.
  destruct (decide (n < k)).
  - rewrite /bi_atleast/bi_or//=. uPred.unseal. left. apply laterN_small; eauto.
  - move: Hall. rewrite /bi_atleast/bi_or//=. uPred.unseal. right.
    edestruct (laterN_exist_big_inhabited A Φ k) as (a&_); eauto.
    { lia. }
    assert (Inhabited A).
    { by econstructor. }
    specialize (laterN_exist k Φ).
    uPred.unseal. intros Hequiv. eapply Hequiv; eauto.
Qed.

(* TODO: Is there a syntactic proof of this for all BI?
   The generalization of the syntactic proof for except_0 did not seem to work out. *)
Lemma atleast_forall {A} k (Φ : A → uPred M) : ◇_k (∀ a, Φ a) ⊣⊢ ∀ a, ◇_k Φ a.
Proof.
  apply (anti_symm _).
  { apply forall_intro=> a. by rewrite (forall_elim a). }
  split => n x Hval Hall.
  destruct (decide (n < k)).
  - rewrite /bi_atleast/bi_or//=. uPred.unseal. left. apply laterN_small; eauto.
  - move: Hall. rewrite /bi_atleast/bi_or//=. uPred.unseal. right.
    intros a. specialize (Hall a) as [Hleft|Hright].
    * exfalso. eapply laterN_big; last (by uPred.unseal); eauto. lia.
    * eauto.
Qed.

Global Instance pure_abs_timeless φ : AbsolutelyTimeless (PROP:=uPredI M) ⌜φ⌝.
Proof.
  intros k'. rewrite /bi_atleast pure_alt laterN_exist_false.
  apply or_mono; first auto.
  apply exist_elim. intros. eauto.
Qed.
Global Instance emp_abs_timeless `{BiAffine PROP} : AbsolutelyTimeless (PROP:=uPredI M) emp.
Proof. rewrite -True_emp. apply _. Qed.
Global Instance forall_abs_timeless {A} (Ψ : A → uPred M) :
  (∀ x, AbsolutelyTimeless (Ψ x)) → AbsolutelyTimeless (∀ x, Ψ x).
Proof.
  rewrite /AbsolutelyTimeless=> HQ k. rewrite atleast_forall laterN_forall.
  apply forall_mono; auto.
Qed.
Global Instance exist_abs_timeless {A} (Ψ : A → uPred M) :
  (∀ x, AbsolutelyTimeless (Ψ x)) → AbsolutelyTimeless (∃ x, Ψ x).
Proof.
  rewrite /AbsolutelyTimeless=> ??. rewrite laterN_exist_false. apply or_elim.
  - rewrite /bi_atleast; auto.
  - apply exist_elim=> x. rewrite -(exist_intro x); auto.
Qed.

Global Instance eq_abs_timeless {A : ofeT} (a b : A) :
  Discrete a → AbsolutelyTimeless (PROP:=uPredI M) (a ≡ b).
Proof. intros. rewrite /Discrete !discrete_eq => k. apply (abs_timeless _). Qed.

(** Absolutely Timeless instances *)
Import bi.bi base_logic.bi.uPred.
Global Instance valid_abs_timeless {A : cmraT} `{!CmraDiscrete A} (a : A) :
  AbsolutelyTimeless (✓ a : uPred M)%I.
Proof. rewrite /AbsolutelyTimeless => k. rewrite !discrete_valid. apply (abs_timeless _). Qed.
Global Instance ownM_abs_timeless (a : M) : Discrete a → AbsolutelyTimeless (uPred_ownM a).
Proof.
  intros ? k.
  trans (∃ b, uPred_ownM b ∧ ▷^k (a ≡ b))%I.
  { admit. }
  apply exist_elim=> b.
  rewrite (abs_timeless (a≡b)) (atleast_intro k (uPred_ownM b)) -atleast_and.
  apply atleast_mono. rewrite internal_eq_sym.
  apply (internal_eq_rewrite' b a (uPred_ownM) _);
    auto using and_elim_l, and_elim_r.
Abort.
End uPred_laws.