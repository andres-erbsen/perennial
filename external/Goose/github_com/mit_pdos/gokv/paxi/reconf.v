(* autogenerated from github.com/mit-pdos/gokv/paxi/reconf *)
From Perennial.goose_lang Require Import prelude.
From Goose Require github_com.mit_pdos.gokv.connman.
From Goose Require github_com.mit_pdos.gokv.urpc.
From Goose Require github_com.tchajed.marshal.

From Perennial.goose_lang Require Import ffi.grove_prelude.

(* 0_quorums.go *)

Definition Config := struct.decl [
  "Members" :: slice.T uint64T;
  "NextMembers" :: slice.T uint64T
].

(* Returns some integer i with the property that
   there exists W such that W contains a majority of members and of nextMembers,
   and every node n in W has indices[n] >= i.
   Even more precisely, it returns the largest such i. *)
Definition GetHighestIndexOfQuorum: val :=
  rec: "GetHighestIndexOfQuorum" "config" "indices" :=
    let: "orderedIndices" := ref_to (slice.T uint64T) (NewSlice uint64T (((slice.len (struct.loadF Config "Members" "config")) + #1) `quot` #2)) in
    ForSlice uint64T <> "m" (struct.loadF Config "Members" "config")
      (let: "indexToInsert" := Fst (MapGet "indices" "m") in
      ForSlice uint64T "i" <> (![slice.T uint64T] "orderedIndices")
        ((if: (SliceGet uint64T (![slice.T uint64T] "orderedIndices") "i") > "indexToInsert"
        then
          let: "j" := ref_to uint64T "i" in
          (for: (λ: <>, (![uint64T] "j") < ((slice.len (![slice.T uint64T] "orderedIndices")) - #1)); (λ: <>, "j" <-[uint64T] ((![uint64T] "j") + #1)) := λ: <>,
            SliceSet uint64T (![slice.T uint64T] "orderedIndices") ("i" + #1) (SliceGet uint64T (![slice.T uint64T] "orderedIndices") "i");;
            Continue)
        else #())));;
    let: "ret" := SliceGet uint64T (![slice.T uint64T] "orderedIndices") ((slice.len (struct.loadF Config "Members" "config")) - #1) in
    (if: (slice.len (struct.loadF Config "NextMembers" "config")) = #0
    then "ret"
    else #0).

(* Returns true iff w is a (write) quorum for the config `config`. *)
Definition IsQuorum: val :=
  rec: "IsQuorum" "config" "w" :=
    let: "num" := ref (zero_val uint64T) in
    ForSlice uint64T <> "member" (struct.loadF Config "Members" "config")
      ((if: Fst (MapGet "w" "member")
      then "num" <-[uint64T] ((![uint64T] "num") + #1)
      else #()));;
    (if: (#2 * (![uint64T] "num")) ≤ (slice.len (struct.loadF Config "Members" "config"))
    then #false
    else
      (if: (slice.len (struct.loadF Config "NextMembers" "config")) = #0
      then #true
      else
        "num" <-[uint64T] #0;;
        ForSlice uint64T <> "member" (struct.loadF Config "NextMembers" "config")
          ((if: Fst (MapGet "w" "member")
          then "num" <-[uint64T] ((![uint64T] "num") + #1)
          else #()));;
        (if: (#2 * (![uint64T] "num")) ≤ (slice.len (struct.loadF Config "NextMembers" "config"))
        then #false
        else #true))).

Definition Config__ForEachMember: val :=
  rec: "Config__ForEachMember" "c" "f" :=
    ForSlice uint64T <> "member" (struct.loadF Config "Members" "c")
      ("f" "member");;
    ForSlice uint64T <> "member" (struct.loadF Config "NextMembers" "c")
      ("f" "member");;
    #().

Definition Config__Contains: val :=
  rec: "Config__Contains" "c" "m" :=
    let: "ret" := ref_to boolT #false in
    ForSlice uint64T <> "member" (struct.loadF Config "Members" "c")
      ((if: "member" = "m"
      then "ret" <-[boolT] #true
      else #()));;
    ForSlice uint64T <> "member" (struct.loadF Config "NextMembers" "c")
      ((if: "member" = "m"
      then "ret" <-[boolT] #true
      else #()));;
    ![boolT] "ret".

(* 1_marshal.go *)

Definition EncConfig: val :=
  rec: "EncConfig" "pre" "conf" :=
    let: "enc" := ref_to (slice.T byteT) "pre" in
    "enc" <-[slice.T byteT] (marshal.WriteInt (![slice.T byteT] "enc") (slice.len (struct.loadF Config "Members" "conf")));;
    "enc" <-[slice.T byteT] (marshal.WriteInt (![slice.T byteT] "enc") (slice.len (struct.loadF Config "NextMembers" "conf")));;
    ForSlice uint64T <> "member" (struct.loadF Config "Members" "conf")
      ("enc" <-[slice.T byteT] (marshal.WriteInt (![slice.T byteT] "enc") "member"));;
    ForSlice uint64T <> "member" (struct.loadF Config "NextMembers" "conf")
      ("enc" <-[slice.T byteT] (marshal.WriteInt (![slice.T byteT] "enc") "member"));;
    ![slice.T byteT] "enc".

Definition DecConfig: val :=
  rec: "DecConfig" "encoded" :=
    let: "dec" := ref_to (slice.T byteT) "encoded" in
    let: "conf" := struct.alloc Config (zero_val (struct.t Config)) in
    let: ("numMembers", "dec") := marshal.ReadInt (![slice.T byteT] "dec") in
    let: ("numNextMembers", "dec") := marshal.ReadInt (![slice.T byteT] "dec") in
    struct.storeF Config "Members" "conf" (NewSlice uint64T "numMembers");;
    struct.storeF Config "NextMembers" "conf" (NewSlice uint64T "numNextMembers");;
    ForSlice uint64T "i" <> (struct.loadF Config "Members" "conf")
      (let: ("0_ret", "1_ret") := marshal.ReadInt (![slice.T byteT] "dec") in
      SliceSet uint64T (struct.loadF Config "Members" "conf") "i" "0_ret";;
      "dec" <-[slice.T byteT] "1_ret");;
    ForSlice uint64T "i" <> (struct.loadF Config "NextMembers" "conf")
      (let: ("0_ret", "1_ret") := marshal.ReadInt (![slice.T byteT] "dec") in
      SliceSet uint64T (struct.loadF Config "Members" "conf") "i" "0_ret";;
      "dec" <-[slice.T byteT] "1_ret");;
    ("conf", ![slice.T byteT] "dec").

Definition MonotonicValue := struct.decl [
  "version" :: uint64T;
  "val" :: slice.T byteT;
  "conf" :: ptrT
].

Definition EncMonotonicValue: val :=
  rec: "EncMonotonicValue" "pre" "mval" :=
    let: "enc" := ref_to (slice.T byteT) "pre" in
    "enc" <-[slice.T byteT] (marshal.WriteInt (![slice.T byteT] "enc") (struct.loadF MonotonicValue "version" "mval"));;
    "enc" <-[slice.T byteT] (marshal.WriteInt (![slice.T byteT] "enc") (slice.len (struct.loadF MonotonicValue "val" "mval")));;
    "enc" <-[slice.T byteT] (marshal.WriteBytes (![slice.T byteT] "enc") (struct.loadF MonotonicValue "val" "mval"));;
    "enc" <-[slice.T byteT] (EncConfig (![slice.T byteT] "enc") (struct.loadF MonotonicValue "conf" "mval"));;
    ![slice.T byteT] "enc".

Definition DecMonotonicValue: val :=
  rec: "DecMonotonicValue" "encoded" :=
    let: "mval" := struct.alloc MonotonicValue (zero_val (struct.t MonotonicValue)) in
    let: "dec" := ref_to (slice.T byteT) "encoded" in
    let: ("0_ret", "1_ret") := marshal.ReadInt (![slice.T byteT] "dec") in
    struct.storeF MonotonicValue "version" "mval" "0_ret";;
    "dec" <-[slice.T byteT] "1_ret";;
    let: ("valLen", "dec") := marshal.ReadInt (![slice.T byteT] "dec") in
    struct.storeF MonotonicValue "val" "mval" (SliceTake (![slice.T byteT] "dec") "valLen");;
    "dec" <-[slice.T byteT] (SliceSkip byteT (![slice.T byteT] "dec") "valLen");;
    let: ("0_ret", "1_ret") := DecConfig (![slice.T byteT] "dec") in
    struct.storeF MonotonicValue "conf" "mval" "0_ret";;
    "dec" <-[slice.T byteT] "1_ret";;
    ("mval", ![slice.T byteT] "dec").

Definition PrepareReply := struct.decl [
  "Err" :: uint64T;
  "Term" :: uint64T;
  "Val" :: ptrT
].

Definition EncPrepareReply: val :=
  rec: "EncPrepareReply" "pre" "reply" :=
    let: "enc" := ref_to (slice.T byteT) "pre" in
    "enc" <-[slice.T byteT] (marshal.WriteInt (![slice.T byteT] "enc") (struct.loadF PrepareReply "Err" "reply"));;
    "enc" <-[slice.T byteT] (marshal.WriteInt (![slice.T byteT] "enc") (struct.loadF PrepareReply "Term" "reply"));;
    "enc" <-[slice.T byteT] (EncMonotonicValue (![slice.T byteT] "enc") (struct.loadF PrepareReply "Val" "reply"));;
    ![slice.T byteT] "enc".

Definition DecPrepareReply: val :=
  rec: "DecPrepareReply" "encoded" :=
    let: "dec" := ref_to (slice.T byteT) "encoded" in
    let: "reply" := struct.alloc PrepareReply (zero_val (struct.t PrepareReply)) in
    let: ("0_ret", "1_ret") := marshal.ReadInt (![slice.T byteT] "dec") in
    struct.storeF PrepareReply "Err" "reply" "0_ret";;
    "dec" <-[slice.T byteT] "1_ret";;
    let: ("0_ret", "1_ret") := marshal.ReadInt (![slice.T byteT] "dec") in
    struct.storeF PrepareReply "Term" "reply" "0_ret";;
    "dec" <-[slice.T byteT] "1_ret";;
    let: ("0_ret", "1_ret") := DecMonotonicValue (![slice.T byteT] "dec") in
    struct.storeF PrepareReply "Val" "reply" "0_ret";;
    "dec" <-[slice.T byteT] "1_ret";;
    "reply".

Definition ProposeArgs := struct.decl [
  "Term" :: uint64T;
  "Val" :: ptrT
].

Definition EncProposeArgs: val :=
  rec: "EncProposeArgs" "args" :=
    let: "enc" := ref_to (slice.T byteT) (NewSlice byteT #0) in
    "enc" <-[slice.T byteT] (marshal.WriteInt (![slice.T byteT] "enc") (struct.loadF ProposeArgs "Term" "args"));;
    "enc" <-[slice.T byteT] (EncMonotonicValue (![slice.T byteT] "enc") (struct.loadF ProposeArgs "Val" "args"));;
    ![slice.T byteT] "enc".

Definition DecProposeArgs: val :=
  rec: "DecProposeArgs" "encoded" :=
    let: "dec" := ref_to (slice.T byteT) "encoded" in
    let: "args" := struct.alloc ProposeArgs (zero_val (struct.t ProposeArgs)) in
    let: ("0_ret", "1_ret") := marshal.ReadInt (![slice.T byteT] "dec") in
    struct.storeF ProposeArgs "Term" "args" "0_ret";;
    "dec" <-[slice.T byteT] "1_ret";;
    let: ("0_ret", "1_ret") := DecMonotonicValue (![slice.T byteT] "dec") in
    struct.storeF ProposeArgs "Val" "args" "0_ret";;
    "dec" <-[slice.T byteT] "1_ret";;
    ("args", ![slice.T byteT] "dec").

Definition TryCommitReply := struct.decl [
  "err" :: uint64T;
  "version" :: uint64T
].

Definition EncMembers: val :=
  rec: "EncMembers" "members" :=
    let: "enc" := ref_to (slice.T byteT) (NewSlice byteT #0) in
    "enc" <-[slice.T byteT] (marshal.WriteInt (![slice.T byteT] "enc") (slice.len "members"));;
    ForSlice uint64T <> "member" "members"
      ("enc" <-[slice.T byteT] (marshal.WriteInt (![slice.T byteT] "enc") "member"));;
    ![slice.T byteT] "enc".

Definition DecMembers: val :=
  rec: "DecMembers" "encoded" :=
    let: "dec" := ref_to (slice.T byteT) "encoded" in
    let: ("numMembers", "dec") := marshal.ReadInt (![slice.T byteT] "dec") in
    let: "members" := NewSlice uint64T "numMembers" in
    ForSlice uint64T "i" <> "members"
      (let: ("0_ret", "1_ret") := marshal.ReadInt (![slice.T byteT] "dec") in
      SliceSet uint64T "members" "i" "0_ret";;
      "dec" <-[slice.T byteT] "1_ret");;
    ("members", ![slice.T byteT] "dec").

(* client.go *)

Definition ClerkPool := struct.decl [
  "cl" :: ptrT
].

Definition RPC_PREPARE : expr := #0.

Definition RPC_PROPOSE : expr := #1.

Definition RPC_TRY_COMMIT_VAL : expr := #2.

Definition RPC_TRY_CONFIG_CHANGE : expr := #3.

Definition MakeClerkPool: val :=
  rec: "MakeClerkPool" <> :=
    struct.new ClerkPool [
      "cl" ::= connman.MakeConnMan #()
    ].

Definition ClerkPool__PrepareRPC: val :=
  rec: "ClerkPool__PrepareRPC" "ck" "srv" "newTerm" "reply_ptr" :=
    let: "raw_reply" := ref (zero_val (slice.T byteT)) in
    connman.ConnMan__CallAtLeastOnce (struct.loadF ClerkPool "cl" "ck") "srv" RPC_PREPARE (marshal.WriteInt (NewSlice byteT #0) "newTerm") "raw_reply" #10;;
    struct.store PrepareReply "reply_ptr" (struct.load PrepareReply (DecPrepareReply (![slice.T byteT] "raw_reply")));;
    #().

Definition ClerkPool__ProposeRPC: val :=
  rec: "ClerkPool__ProposeRPC" "ck" "srv" "term" "val" :=
    let: "args" := struct.new ProposeArgs [
      "Term" ::= "term";
      "Val" ::= "val"
    ] in
    let: "raw_reply" := ref (zero_val (slice.T byteT)) in
    connman.ConnMan__CallAtLeastOnce (struct.loadF ClerkPool "cl" "ck") "srv" RPC_PROPOSE (EncProposeArgs "args") "raw_reply" #10;;
    let: ("err", <>) := marshal.ReadInt (![slice.T byteT] "raw_reply") in
    "err" = #0.

Definition ClerkPool__TryCommitVal: val :=
  rec: "ClerkPool__TryCommitVal" "ck" "srv" "v" :=
    let: "raw_reply" := ref (zero_val (slice.T byteT)) in
    connman.ConnMan__CallAtLeastOnce (struct.loadF ClerkPool "cl" "ck") "srv" RPC_TRY_COMMIT_VAL "v" "raw_reply" #1000;;
    let: ("err", <>) := marshal.ReadInt (![slice.T byteT] "raw_reply") in
    "err" = #0.

Definition ClerkPool__TryConfigChange: val :=
  rec: "ClerkPool__TryConfigChange" "ck" "srv" "newMembers" :=
    let: "raw_args" := EncMembers "newMembers" in
    let: "raw_reply" := ref (zero_val (slice.T byteT)) in
    connman.ConnMan__CallAtLeastOnce (struct.loadF ClerkPool "cl" "ck") "srv" RPC_TRY_CONFIG_CHANGE "raw_args" "raw_reply" #50;;
    let: ("err", <>) := marshal.ReadInt (![slice.T byteT] "raw_reply") in
    "err" = #0.

(* server.go *)

Definition MonotonicValue__GreaterThan: val :=
  rec: "MonotonicValue__GreaterThan" "lhs" "rhs" :=
    (struct.loadF MonotonicValue "version" "lhs") > (struct.loadF MonotonicValue "version" "rhs").

Definition Replica := struct.decl [
  "mu" :: ptrT;
  "promisedTerm" :: uint64T;
  "acceptedTerm" :: uint64T;
  "acceptedMVal" :: ptrT;
  "clerkPool" :: ptrT;
  "isLeader" :: boolT
].

Definition ENone : expr := #0.

Definition ETermStale : expr := #1.

Definition ENotLeader : expr := #2.

Definition EQuorumFailed : expr := #3.

Definition Replica__PrepareRPC: val :=
  rec: "Replica__PrepareRPC" "r" "term" "reply" :=
    lock.acquire (struct.loadF Replica "mu" "r");;
    (if: "term" > (struct.loadF Replica "promisedTerm" "r")
    then
      struct.storeF Replica "promisedTerm" "r" "term";;
      struct.storeF PrepareReply "Term" "reply" (struct.loadF Replica "acceptedTerm" "r");;
      struct.storeF PrepareReply "Val" "reply" (struct.loadF Replica "acceptedMVal" "r");;
      struct.storeF PrepareReply "Err" "reply" ENone
    else
      struct.storeF PrepareReply "Err" "reply" ETermStale;;
      struct.storeF PrepareReply "Val" "reply" (struct.alloc MonotonicValue (zero_val (struct.t MonotonicValue)));;
      struct.storeF MonotonicValue "conf" (struct.loadF PrepareReply "Val" "reply") (struct.alloc Config (zero_val (struct.t Config)));;
      struct.storeF PrepareReply "Term" "reply" (struct.loadF Replica "promisedTerm" "r"));;
    lock.release (struct.loadF Replica "mu" "r");;
    #().

Definition Replica__ProposeRPC: val :=
  rec: "Replica__ProposeRPC" "r" "term" "v" :=
    lock.acquire (struct.loadF Replica "mu" "r");;
    (if: "term" ≥ (struct.loadF Replica "promisedTerm" "r")
    then
      struct.storeF Replica "promisedTerm" "r" "term";;
      struct.storeF Replica "acceptedTerm" "r" "term";;
      (if: MonotonicValue__GreaterThan "v" (struct.loadF Replica "acceptedMVal" "r")
      then struct.storeF Replica "acceptedMVal" "r" "v"
      else #());;
      lock.release (struct.loadF Replica "mu" "r");;
      ENone
    else
      lock.release (struct.loadF Replica "mu" "r");;
      ETermStale).

Definition Replica__TryBecomeLeader: val :=
  rec: "Replica__TryBecomeLeader" "r" :=
    lock.acquire (struct.loadF Replica "mu" "r");;
    let: "newTerm" := (struct.loadF Replica "promisedTerm" "r") + #1 in
    struct.storeF Replica "promisedTerm" "r" "newTerm";;
    let: "highestTerm" := ref (zero_val uint64T) in
    "highestTerm" <-[uint64T] #0;;
    let: "highestVal" := ref (zero_val ptrT) in
    "highestVal" <-[ptrT] (struct.loadF Replica "acceptedMVal" "r");;
    let: "conf" := struct.loadF MonotonicValue "conf" (struct.loadF Replica "acceptedMVal" "r") in
    lock.release (struct.loadF Replica "mu" "r");;
    let: "mu" := lock.new #() in
    let: "prepared" := NewMap uint64T boolT #() in
    Config__ForEachMember "conf" (λ: "addr",
      Fork (let: "reply_ptr" := struct.alloc PrepareReply (zero_val (struct.t PrepareReply)) in
            ClerkPool__PrepareRPC (struct.loadF Replica "clerkPool" "r") "addr" "newTerm" "reply_ptr";;
            (if: (struct.loadF PrepareReply "Err" "reply_ptr") = ENone
            then
              lock.acquire "mu";;
              MapInsert "prepared" "addr" #true;;
              (if: (struct.loadF PrepareReply "Term" "reply_ptr") > (![uint64T] "highestTerm")
              then "highestVal" <-[ptrT] (struct.loadF PrepareReply "Val" "reply_ptr")
              else
                (if: (struct.loadF PrepareReply "Term" "reply_ptr") = (![uint64T] "highestTerm")
                then
                  (if: MonotonicValue__GreaterThan (![ptrT] "highestVal") (struct.loadF PrepareReply "Val" "reply_ptr")
                  then "highestVal" <-[ptrT] (struct.loadF PrepareReply "Val" "reply_ptr")
                  else #())
                else #()));;
              lock.release "mu"
            else #()));;
      #()
      );;
    time.Sleep (#50 * #1000000);;
    lock.acquire "mu";;
    (if: IsQuorum (struct.loadF MonotonicValue "conf" (![ptrT] "highestVal")) "prepared"
    then
      lock.acquire (struct.loadF Replica "mu" "r");;
      (if: (struct.loadF Replica "promisedTerm" "r") = "newTerm"
      then
        struct.storeF Replica "acceptedMVal" "r" (![ptrT] "highestVal");;
        struct.storeF Replica "isLeader" "r" #true
      else #());;
      lock.release (struct.loadF Replica "mu" "r");;
      lock.release "mu";;
      #true
    else
      lock.release "mu";;
      #false).

(* Returns true iff there was an error;
   The error is either that r is not currently a primary, or that r was unable
   to commit the value within one round of commits.

   mvalModifier is not allowed to modify the version number in the given mval. *)
Definition Replica__tryCommit: val :=
  rec: "Replica__tryCommit" "r" "mvalModifier" "reply" :=
    lock.acquire (struct.loadF Replica "mu" "r");;
    (if: (~ (struct.loadF Replica "isLeader" "r"))
    then
      lock.release (struct.loadF Replica "mu" "r");;
      struct.storeF TryCommitReply "err" "reply" ENotLeader;;
      #()
    else
      "mvalModifier" (struct.loadF Replica "acceptedMVal" "r");;
      (* log.Printf("Trying to commit value; node state: %+v\n", r) *)
      struct.storeF MonotonicValue "version" (struct.loadF Replica "acceptedMVal" "r") ((struct.loadF MonotonicValue "version" (struct.loadF Replica "acceptedMVal" "r")) + #1);;
      let: "term" := struct.loadF Replica "promisedTerm" "r" in
      let: "mval" := struct.loadF Replica "acceptedMVal" "r" in
      lock.release (struct.loadF Replica "mu" "r");;
      let: "mu" := lock.new #() in
      let: "accepted" := NewMap uint64T boolT #() in
      Config__ForEachMember (struct.loadF MonotonicValue "conf" "mval") (λ: "addr",
        Fork ((if: ClerkPool__ProposeRPC (struct.loadF Replica "clerkPool" "r") "addr" "term" "mval"
              then
                lock.acquire "mu";;
                MapInsert "accepted" "addr" #true;;
                lock.release "mu"
              else #()));;
        #()
        );;
      time.Sleep (#100 * #1000000);;
      lock.acquire "mu";;
      (if: IsQuorum (struct.loadF MonotonicValue "conf" "mval") "accepted"
      then
        struct.storeF TryCommitReply "err" "reply" ENone;;
        struct.storeF TryCommitReply "version" "reply" (struct.loadF MonotonicValue "version" "mval")
      else struct.storeF TryCommitReply "err" "reply" EQuorumFailed);;
      (* log.Printf("Result of trying to commit: %+v\n", reply) *)
      #()).

Definition Replica__TryCommitVal: val :=
  rec: "Replica__TryCommitVal" "r" "v" "reply" :=
    lock.acquire (struct.loadF Replica "mu" "r");;
    (if: (~ (struct.loadF Replica "isLeader" "r"))
    then
      lock.release (struct.loadF Replica "mu" "r");;
      Replica__TryBecomeLeader "r"
    else lock.release (struct.loadF Replica "mu" "r"));;
    Replica__tryCommit "r" (λ: "mval",
      struct.storeF MonotonicValue "val" "mval" "v";;
      #()
      ) "reply";;
    #().

(* requires that newConfig has overlapping quorums with r.config *)
Definition Replica__TryEnterNewConfig: val :=
  rec: "Replica__TryEnterNewConfig" "r" "newMembers" :=
    let: "reply" := struct.alloc TryCommitReply (zero_val (struct.t TryCommitReply)) in
    Replica__tryCommit "r" (λ: "mval",
      (if: (slice.len (struct.loadF Config "NextMembers" (struct.loadF MonotonicValue "conf" "mval"))) = #0
      then
        struct.storeF Config "NextMembers" (struct.loadF MonotonicValue "conf" "mval") "newMembers";;
        #()
      else #())
      ) "reply";;
    Replica__tryCommit "r" (λ: "mval",
      (if: (slice.len (struct.loadF Config "NextMembers" (struct.loadF MonotonicValue "conf" "mval"))) ≠ #0
      then
        struct.storeF Config "Members" (struct.loadF MonotonicValue "conf" "mval") (struct.loadF Config "NextMembers" (struct.loadF MonotonicValue "conf" "mval"));;
        struct.storeF Config "NextMembers" (struct.loadF MonotonicValue "conf" "mval") (NewSlice uint64T #0);;
        #()
      else #())
      ) "reply";;
    #().

Definition StartReplicaServer: val :=
  rec: "StartReplicaServer" "me" "initConfig" :=
    let: "s" := struct.alloc Replica (zero_val (struct.t Replica)) in
    struct.storeF Replica "mu" "s" (lock.new #());;
    struct.storeF Replica "promisedTerm" "s" #0;;
    struct.storeF Replica "acceptedTerm" "s" #0;;
    struct.storeF Replica "acceptedMVal" "s" (struct.alloc MonotonicValue (zero_val (struct.t MonotonicValue)));;
    struct.storeF MonotonicValue "conf" (struct.loadF Replica "acceptedMVal" "s") "initConfig";;
    struct.storeF Replica "clerkPool" "s" (MakeClerkPool #());;
    struct.storeF Replica "isLeader" "s" #false;;
    let: "handlers" := NewMap uint64T ((slice.T byteT) -> ptrT -> unitT)%ht #() in
    MapInsert "handlers" RPC_PREPARE (λ: "args" "raw_reply",
      let: ("term", <>) := marshal.ReadInt "args" in
      let: "reply" := struct.alloc PrepareReply (zero_val (struct.t PrepareReply)) in
      Replica__PrepareRPC "s" "term" "reply";;
      "raw_reply" <-[slice.T byteT] (EncPrepareReply (NewSlice byteT #0) "reply");;
      DecPrepareReply (![slice.T byteT] "raw_reply");;
      #()
      );;
    MapInsert "handlers" RPC_PROPOSE (λ: "raw_args" "raw_reply",
      let: ("args", <>) := DecProposeArgs "raw_args" in
      let: "reply" := Replica__ProposeRPC "s" (struct.loadF ProposeArgs "Term" "args") (struct.loadF ProposeArgs "Val" "args") in
      "raw_reply" <-[slice.T byteT] (marshal.WriteInt (NewSliceWithCap byteT #0 #8) "reply");;
      #()
      );;
    MapInsert "handlers" RPC_TRY_COMMIT_VAL (λ: "raw_args" "raw_reply",
      (* log.Println("RPC_TRY_COMMIT_VAL") *)
      let: "val" := "raw_args" in
      let: "reply" := struct.alloc TryCommitReply (zero_val (struct.t TryCommitReply)) in
      Replica__TryCommitVal "s" "val" "reply";;
      "raw_reply" <-[slice.T byteT] (marshal.WriteInt (NewSliceWithCap byteT #0 #8) (struct.loadF TryCommitReply "err" "reply"));;
      #()
      );;
    MapInsert "handlers" RPC_TRY_CONFIG_CHANGE (λ: "raw_args" "raw_reply",
      let: ("args", <>) := DecMembers "raw_args" in
      Replica__TryEnterNewConfig "s" "args";;
      "raw_reply" <-[slice.T byteT] (NewSlice byteT #0);;
      #()
      );;
    let: "r" := urpc.MakeServer "handlers" in
    urpc.Server__Serve "r" "me";;
    #().
