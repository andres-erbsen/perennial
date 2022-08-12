From Perennial.program_proof Require Export proof_prelude.
From Perennial.goose_lang Require Export ffi.grove_prelude.

(* Make sure Z_scope is open. *)
Local Lemma Z.scope_test : (0%Z) + (0%Z) = 0%Z.
Proof. done. Qed.
