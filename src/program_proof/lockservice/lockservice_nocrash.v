(* autogenerated from github.com/mit-pdos/lockservice/lockservice *)
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.grove_prelude.

From Goose Require github_com.mit_pdos.lockservice.grove_common.
From Goose Require github_com.tchajed.marshal.

(* 0_common.go *)

Definition nondet: val :=
  rec: "nondet" <> :=
    #true.

(* Call this before doing an increment that has risk of overflowing.
   If it's going to overflow, this'll loop forever, so the bad addition can never happen *)
Definition overflow_guard_incr: val :=
  rec: "overflow_guard_incr" "v" :=
    Skip;;
    (for: (λ: <>, "v" + #1 < "v"); (λ: <>, Skip) := λ: <>,
      Continue).

(* 0_rpc.go *)

Definition RpcCoreHandler: ty := (struct.t grove_common.RPCVals.S -> uint64T)%ht.

Definition CheckReplyTable: val :=
  rec: "CheckReplyTable" "lastSeq" "lastReply" "CID" "Seq" "reply" :=
    let: ("last", "ok") := MapGet "lastSeq" "CID" in
    struct.storeF grove_common.RPCReply.S "Stale" "reply" #false;;
    (if: "ok" && ("Seq" ≤ "last")
    then
      (if: "Seq" < "last"
      then
        struct.storeF grove_common.RPCReply.S "Stale" "reply" #true;;
        #true
      else
        struct.storeF grove_common.RPCReply.S "Ret" "reply" (Fst (MapGet "lastReply" "CID"));;
        #true)
    else
      MapInsert "lastSeq" "CID" "Seq";;
      #false).

Definition rpcReqEncode: val :=
  rec: "rpcReqEncode" "req" :=
    let: "e" := marshal.NewEnc (#4 * #8) in
    marshal.Enc__PutInt "e" (struct.loadF grove_common.RPCRequest.S "CID" "req");;
    marshal.Enc__PutInt "e" (struct.loadF grove_common.RPCRequest.S "Seq" "req");;
    marshal.Enc__PutInt "e" (struct.get grove_common.RPCVals.S "U64_1" (struct.loadF grove_common.RPCRequest.S "Args" "req"));;
    marshal.Enc__PutInt "e" (struct.get grove_common.RPCVals.S "U64_2" (struct.loadF grove_common.RPCRequest.S "Args" "req"));;
    let: "res" := marshal.Enc__Finish "e" in
    Linearize;;
    "res".

Definition rpcReqDecode: val :=
  rec: "rpcReqDecode" "data" "req" :=
    let: "d" := marshal.NewDec "data" in
    struct.storeF grove_common.RPCRequest.S "CID" "req" (marshal.Dec__GetInt "d");;
    struct.storeF grove_common.RPCRequest.S "Seq" "req" (marshal.Dec__GetInt "d");;
    struct.storeF grove_common.RPCVals.S "U64_1" (struct.fieldRef grove_common.RPCRequest.S "Args" "req") (marshal.Dec__GetInt "d");;
    struct.storeF grove_common.RPCVals.S "U64_2" (struct.fieldRef grove_common.RPCRequest.S "Args" "req") (marshal.Dec__GetInt "d");;
    Linearize.

Definition rpcReplyEncode: val :=
  rec: "rpcReplyEncode" "reply" :=
    let: "e" := marshal.NewEnc (#2 * #8) in
    marshal.Enc__PutBool "e" (struct.loadF grove_common.RPCReply.S "Stale" "reply");;
    marshal.Enc__PutInt "e" (struct.loadF grove_common.RPCReply.S "Ret" "reply");;
    let: "res" := marshal.Enc__Finish "e" in
    Linearize;;
    "res".

Definition rpcReplyDecode: val :=
  rec: "rpcReplyDecode" "data" "reply" :=
    let: "d" := marshal.NewDec "data" in
    struct.storeF grove_common.RPCReply.S "Stale" "reply" (marshal.Dec__GetBool "d");;
    struct.storeF grove_common.RPCReply.S "Ret" "reply" (marshal.Dec__GetInt "d");;
    Linearize.

(* Emulate an RPC call over a lossy network.
   Returns true iff server reported error or request "timed out".
   For the "real thing", this should instead submit a request via the network. *)
Definition RemoteProcedureCall: val :=
  rec: "RemoteProcedureCall" "host" "rpcid" "req" "reply" :=
    let: "reqdata" := rpcReqEncode "req" in
    Fork (let: "dummy_reply" := struct.alloc grove_common.RPCReply.S (zero_val (struct.t grove_common.RPCReply.S)) in
          Skip;;
          (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
            let: "rpc" := grove_ffi.GetServer "host" "rpcid" in
            let: "decodedReq" := struct.alloc grove_common.RPCRequest.S (zero_val (struct.t grove_common.RPCRequest.S)) in
            rpcReqDecode "reqdata" "decodedReq";;
            "rpc" "decodedReq" "dummy_reply";;
            Continue));;
    (if: nondet #()
    then
      let: "rpc" := grove_ffi.GetServer "host" "rpcid" in
      let: "decodedReq" := struct.alloc grove_common.RPCRequest.S (zero_val (struct.t grove_common.RPCRequest.S)) in
      rpcReqDecode "reqdata" "decodedReq";;
      let: "serverReply" := struct.alloc grove_common.RPCReply.S (zero_val (struct.t grove_common.RPCReply.S)) in
      let: "ok" := "rpc" "req" "serverReply" in
      let: "replydata" := rpcReplyEncode "serverReply" in
      rpcReplyDecode "replydata" "reply";;
      "ok"
    else #true).

(* Common code for RPC clients: tracking of CID and next sequence number. *)
Module RPCClient.
  Definition S := struct.decl [
    "cid" :: uint64T;
    "seq" :: uint64T
  ].
End RPCClient.

Definition MakeRPCClient: val :=
  rec: "MakeRPCClient" "cid" :=
    struct.new RPCClient.S [
      "cid" ::= "cid";
      "seq" ::= #1
    ].

Definition RPCClient__MakeRequest: val :=
  rec: "RPCClient__MakeRequest" "cl" "host" "rpcid" "args" :=
    overflow_guard_incr (struct.loadF RPCClient.S "seq" "cl");;
    let: "req" := struct.new grove_common.RPCRequest.S [
      "Args" ::= "args";
      "CID" ::= struct.loadF RPCClient.S "cid" "cl";
      "Seq" ::= struct.loadF RPCClient.S "seq" "cl"
    ] in
    struct.storeF RPCClient.S "seq" "cl" (struct.loadF RPCClient.S "seq" "cl" + #1);;
    let: "errb" := ref_to boolT #false in
    let: "reply" := struct.alloc grove_common.RPCReply.S (zero_val (struct.t grove_common.RPCReply.S)) in
    Skip;;
    (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
      "errb" <-[boolT] RemoteProcedureCall "host" "rpcid" "req" "reply";;
      (if: (![boolT] "errb" = #false)
      then Break
      else Continue));;
    struct.loadF grove_common.RPCReply.S "Ret" "reply".

(* Common code for RPC servers: locking and handling of stale and redundant requests through
   the reply table. *)
Module RPCServer.
  Definition S := struct.decl [
    "mu" :: lockRefT;
    "lastSeq" :: mapT uint64T;
    "lastReply" :: mapT uint64T
  ].
End RPCServer.

Definition MakeRPCServer: val :=
  rec: "MakeRPCServer" <> :=
    let: "sv" := struct.alloc RPCServer.S (zero_val (struct.t RPCServer.S)) in
    struct.storeF RPCServer.S "lastSeq" "sv" (NewMap uint64T);;
    struct.storeF RPCServer.S "lastReply" "sv" (NewMap uint64T);;
    struct.storeF RPCServer.S "mu" "sv" (lock.new #());;
    "sv".

Definition RPCServer__HandleRequest: val :=
  rec: "RPCServer__HandleRequest" "sv" "core" "req" "reply" :=
    lock.acquire (struct.loadF RPCServer.S "mu" "sv");;
    (if: CheckReplyTable (struct.loadF RPCServer.S "lastSeq" "sv") (struct.loadF RPCServer.S "lastReply" "sv") (struct.loadF grove_common.RPCRequest.S "CID" "req") (struct.loadF grove_common.RPCRequest.S "Seq" "req") "reply"
    then
      lock.release (struct.loadF RPCServer.S "mu" "sv");;
      #false
    else
      struct.storeF grove_common.RPCReply.S "Ret" "reply" ("core" (struct.loadF grove_common.RPCRequest.S "Args" "req"));;
      MapInsert (struct.loadF RPCServer.S "lastReply" "sv") (struct.loadF grove_common.RPCRequest.S "CID" "req") (struct.loadF grove_common.RPCReply.S "Ret" "reply");;
      lock.release (struct.loadF RPCServer.S "mu" "sv");;
      #false).

(* 1_kvserver.go *)

Definition KV_PUT : expr := #1.

Definition KV_GET : expr := #2.

Module KVServer.
  Definition S := struct.decl [
    "sv" :: struct.ptrT RPCServer.S;
    "kvs" :: mapT uint64T
  ].
End KVServer.

Definition KVServer__put_core: val :=
  rec: "KVServer__put_core" "ks" "args" :=
    MapInsert (struct.loadF KVServer.S "kvs" "ks") (struct.get grove_common.RPCVals.S "U64_1" "args") (struct.get grove_common.RPCVals.S "U64_2" "args");;
    #0.

Definition KVServer__get_core: val :=
  rec: "KVServer__get_core" "ks" "args" :=
    Fst (MapGet (struct.loadF KVServer.S "kvs" "ks") (struct.get grove_common.RPCVals.S "U64_1" "args")).

Definition KVServer__Put: val :=
  rec: "KVServer__Put" "ks" "req" "reply" :=
    RPCServer__HandleRequest (struct.loadF KVServer.S "sv" "ks") (λ: "args",
      KVServer__put_core "ks" "args"
      ) "req" "reply".

Definition KVServer__Get: val :=
  rec: "KVServer__Get" "ks" "req" "reply" :=
    RPCServer__HandleRequest (struct.loadF KVServer.S "sv" "ks") (λ: "args",
      KVServer__get_core "ks" "args"
      ) "req" "reply".

Definition MakeKVServer: val :=
  rec: "MakeKVServer" <> :=
    let: "ks" := struct.alloc KVServer.S (zero_val (struct.t KVServer.S)) in
    struct.storeF KVServer.S "kvs" "ks" (NewMap uint64T);;
    struct.storeF KVServer.S "sv" "ks" (MakeRPCServer #());;
    "ks".

Definition KVServer__AllocServer: val :=
  rec: "KVServer__AllocServer" "ks" :=
    let: "handlers" := NewMap grove_common.RpcFunc in
    MapInsert "handlers" KV_PUT (KVServer__Put "ks");;
    MapInsert "handlers" KV_GET (KVServer__Get "ks");;
    let: "host" := grove_ffi.AllocServer "handlers" in
    "host".

(* 1_lockserver.go *)

Module LockServer.
  Definition S := struct.decl [
    "sv" :: struct.ptrT RPCServer.S;
    "locks" :: mapT boolT
  ].
End LockServer.

Definition LockServer__tryLock_core: val :=
  rec: "LockServer__tryLock_core" "ls" "args" :=
    let: "lockname" := struct.get grove_common.RPCVals.S "U64_1" "args" in
    let: ("locked", <>) := MapGet (struct.loadF LockServer.S "locks" "ls") "lockname" in
    (if: "locked"
    then #0
    else
      MapInsert (struct.loadF LockServer.S "locks" "ls") "lockname" #true;;
      #1).

Definition LockServer__unlock_core: val :=
  rec: "LockServer__unlock_core" "ls" "args" :=
    let: "lockname" := struct.get grove_common.RPCVals.S "U64_1" "args" in
    let: ("locked", <>) := MapGet (struct.loadF LockServer.S "locks" "ls") "lockname" in
    (if: "locked"
    then
      MapInsert (struct.loadF LockServer.S "locks" "ls") "lockname" #false;;
      #1
    else #0).

(* server Lock RPC handler.
   returns true iff error *)
Definition LockServer__TryLock: val :=
  rec: "LockServer__TryLock" "ls" "req" "reply" :=
    RPCServer__HandleRequest (struct.loadF LockServer.S "sv" "ls") (λ: "args",
      LockServer__tryLock_core "ls" "args"
      ) "req" "reply".

(* server Unlock RPC handler.
   returns true iff error *)
Definition LockServer__Unlock: val :=
  rec: "LockServer__Unlock" "ls" "req" "reply" :=
    RPCServer__HandleRequest (struct.loadF LockServer.S "sv" "ls") (λ: "args",
      LockServer__unlock_core "ls" "args"
      ) "req" "reply".

Definition MakeLockServer: val :=
  rec: "MakeLockServer" <> :=
    let: "ls" := struct.alloc LockServer.S (zero_val (struct.t LockServer.S)) in
    struct.storeF LockServer.S "locks" "ls" (NewMap boolT);;
    struct.storeF LockServer.S "sv" "ls" (MakeRPCServer #());;
    "ls".

(* 3_kvclient.go *)

(* the lockservice Clerk lives in the client
   and maintains a little state. *)
Module KVClerk.
  Definition S := struct.decl [
    "primary" :: uint64T;
    "client" :: struct.ptrT RPCClient.S;
    "cid" :: uint64T;
    "seq" :: uint64T
  ].
End KVClerk.

Definition MakeKVClerk: val :=
  rec: "MakeKVClerk" "primary" "cid" :=
    let: "ck" := struct.alloc KVClerk.S (zero_val (struct.t KVClerk.S)) in
    struct.storeF KVClerk.S "primary" "ck" "primary";;
    struct.storeF KVClerk.S "client" "ck" (MakeRPCClient "cid");;
    "ck".

Definition KVClerk__Put: val :=
  rec: "KVClerk__Put" "ck" "key" "val" :=
    RPCClient__MakeRequest (struct.loadF KVClerk.S "client" "ck") (struct.loadF KVClerk.S "primary" "ck") KV_PUT (struct.mk grove_common.RPCVals.S [
      "U64_1" ::= "key";
      "U64_2" ::= "val"
    ]);;
    #().

Definition KVClerk__Get: val :=
  rec: "KVClerk__Get" "ck" "key" :=
    RPCClient__MakeRequest (struct.loadF KVClerk.S "client" "ck") (struct.loadF KVClerk.S "primary" "ck") KV_GET (struct.mk grove_common.RPCVals.S [
      "U64_1" ::= "key"
    ]).

(* 3_lockclient.go *)

(* the lockservice Clerk lives in the client
   and maintains a little state. *)
Module Clerk.
  Definition S := struct.decl [
    "primary" :: uint64T;
    "client" :: struct.ptrT RPCClient.S
  ].
End Clerk.

Definition LOCK_TRYLOCK : expr := #1.

Definition LOCK_UNLOCK : expr := #2.

Definition MakeClerk: val :=
  rec: "MakeClerk" "primary" "cid" :=
    let: "ck" := struct.alloc Clerk.S (zero_val (struct.t Clerk.S)) in
    struct.storeF Clerk.S "primary" "ck" "primary";;
    struct.storeF Clerk.S "client" "ck" (MakeRPCClient "cid");;
    "ck".

Definition Clerk__TryLock: val :=
  rec: "Clerk__TryLock" "ck" "lockname" :=
    RPCClient__MakeRequest (struct.loadF Clerk.S "client" "ck") (struct.loadF Clerk.S "primary" "ck") LOCK_TRYLOCK (struct.mk grove_common.RPCVals.S [
      "U64_1" ::= "lockname"
    ]) ≠ #0.

(* ask the lock service to unlock a lock.
   returns true if the lock was previously held,
   false otherwise. *)
Definition Clerk__Unlock: val :=
  rec: "Clerk__Unlock" "ck" "lockname" :=
    RPCClient__MakeRequest (struct.loadF Clerk.S "client" "ck") (struct.loadF Clerk.S "primary" "ck") LOCK_UNLOCK (struct.mk grove_common.RPCVals.S [
      "U64_1" ::= "lockname"
    ]) ≠ #0.

(* Spins until we have the lock *)
Definition Clerk__Lock: val :=
  rec: "Clerk__Lock" "ck" "lockname" :=
    Skip;;
    (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
      (if: Clerk__TryLock "ck" "lockname"
      then Break
      else Continue));;
    #true.

(* 4_bank.go *)

Module Bank.
  Definition S := struct.decl [
    "ls" :: uint64T;
    "ks" :: uint64T
  ].
End Bank.

Module BankClerk.
  Definition S := struct.decl [
    "lck" :: struct.ptrT Clerk.S;
    "kvck" :: struct.ptrT KVClerk.S;
    "acc1" :: uint64T;
    "acc2" :: uint64T
  ].
End BankClerk.

Definition acquire_two: val :=
  rec: "acquire_two" "lck" "l1" "l2" :=
    (if: "l1" < "l2"
    then
      Clerk__Lock "lck" "l1";;
      Clerk__Lock "lck" "l2"
    else
      Clerk__Lock "lck" "l2";;
      Clerk__Lock "lck" "l1");;
    #().

Definition release_two: val :=
  rec: "release_two" "lck" "l1" "l2" :=
    (if: "l1" < "l2"
    then
      Clerk__Unlock "lck" "l2";;
      Clerk__Unlock "lck" "l1"
    else
      Clerk__Unlock "lck" "l1";;
      Clerk__Unlock "lck" "l2");;
    #().

(* Requires that the account numbers are smaller than num_accounts
   If account balance in acc_from is at least amount, transfer amount to acc_to *)
Definition BankClerk__transfer_internal: val :=
  rec: "BankClerk__transfer_internal" "bck" "acc_from" "acc_to" "amount" :=
    acquire_two (struct.loadF BankClerk.S "lck" "bck") "acc_from" "acc_to";;
    let: "old_amount" := KVClerk__Get (struct.loadF BankClerk.S "kvck" "bck") "acc_from" in
    (if: "old_amount" ≥ "amount"
    then
      KVClerk__Put (struct.loadF BankClerk.S "kvck" "bck") "acc_from" ("old_amount" - "amount");;
      KVClerk__Put (struct.loadF BankClerk.S "kvck" "bck") "acc_to" (KVClerk__Get (struct.loadF BankClerk.S "kvck" "bck") "acc_to" + "amount");;
      #()
    else #());;
    release_two (struct.loadF BankClerk.S "lck" "bck") "acc_from" "acc_to".

Definition BankClerk__SimpleTransfer: val :=
  rec: "BankClerk__SimpleTransfer" "bck" "amount" :=
    BankClerk__transfer_internal "bck" (struct.loadF BankClerk.S "acc1" "bck") (struct.loadF BankClerk.S "acc2" "bck") "amount".

(* If account balance in acc_from is at least amount, transfer amount to acc_to *)
Definition BankClerk__SimpleAudit: val :=
  rec: "BankClerk__SimpleAudit" "bck" :=
    acquire_two (struct.loadF BankClerk.S "lck" "bck") (struct.loadF BankClerk.S "acc1" "bck") (struct.loadF BankClerk.S "acc2" "bck");;
    let: "sum" := KVClerk__Get (struct.loadF BankClerk.S "kvck" "bck") (struct.loadF BankClerk.S "acc1" "bck") + KVClerk__Get (struct.loadF BankClerk.S "kvck" "bck") (struct.loadF BankClerk.S "acc2" "bck") in
    release_two (struct.loadF BankClerk.S "lck" "bck") (struct.loadF BankClerk.S "acc1" "bck") (struct.loadF BankClerk.S "acc2" "bck");;
    "sum".

Definition MakeBank: val :=
  rec: "MakeBank" "acc" "balance" :=
    let: "ls" := MakeLockServer #() in
    let: "ks" := MakeKVServer #() in
    MapInsert (struct.loadF KVServer.S "kvs" "ks") "acc" "balance";;
    let: "ls_handlers" := NewMap grove_common.RpcFunc in
    MapInsert "ls_handlers" LOCK_TRYLOCK (LockServer__TryLock "ls");;
    MapInsert "ls_handlers" LOCK_UNLOCK (LockServer__Unlock "ls");;
    let: "lsid" := grove_ffi.AllocServer "ls_handlers" in
    let: "ks_handlers" := NewMap grove_common.RpcFunc in
    MapInsert "ks_handlers" KV_PUT (KVServer__Put "ks");;
    MapInsert "ks_handlers" KV_GET (KVServer__Get "ks");;
    let: "ksid" := grove_ffi.AllocServer "ks_handlers" in
    struct.mk Bank.S [
      "ls" ::= "lsid";
      "ks" ::= "ksid"
    ].

Definition MakeBankClerk: val :=
  rec: "MakeBankClerk" "b" "acc1" "acc2" "cid" :=
    let: "bck" := struct.alloc BankClerk.S (zero_val (struct.t BankClerk.S)) in
    struct.storeF BankClerk.S "lck" "bck" (MakeClerk (struct.get Bank.S "ls" "b") "cid");;
    struct.storeF BankClerk.S "kvck" "bck" (MakeKVClerk (struct.get Bank.S "ks" "b") "cid");;
    struct.storeF BankClerk.S "acc1" "bck" "acc1";;
    struct.storeF BankClerk.S "acc2" "bck" "acc2";;
    "bck".
