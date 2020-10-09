(* autogenerated from github.com/mit-pdos/goose-nfsd/buftxn_replication *)
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.disk_prelude.

From Goose Require github_com.mit_pdos.goose_nfsd.addr.
From Goose Require github_com.mit_pdos.goose_nfsd.buftxn.
From Goose Require github_com.mit_pdos.goose_nfsd.common.
From Goose Require github_com.mit_pdos.goose_nfsd.txn.
From Goose Require github_com.mit_pdos.goose_nfsd.util.

Module RepBlock.
  Definition S := struct.decl [
    "txn" :: struct.ptrT txn.Txn.S;
    "m" :: lockRefT;
    "a0" :: struct.t addr.Addr.S;
    "a1" :: struct.t addr.Addr.S
  ].
End RepBlock.

Definition Open: val :=
  rec: "Open" "txn" "a" :=
    struct.new RepBlock.S [
      "txn" ::= "txn";
      "m" ::= lock.new #();
      "a0" ::= addr.MkAddr "a" #0;
      "a1" ::= addr.MkAddr ("a" + #1) #0
    ].

(* can fail in principle if CommitWait fails,
   but that's really impossible since it's an empty transaction *)
Definition RepBlock__Read: val :=
  rec: "RepBlock__Read" "rb" :=
    lock.acquire (struct.loadF RepBlock.S "m" "rb");;
    let: "tx" := buftxn.Begin (struct.loadF RepBlock.S "txn" "rb") in
    let: "buf" := buftxn.BufTxn__ReadBuf "tx" (struct.loadF RepBlock.S "a0" "rb") (#8 * disk.BlockSize) in
    let: "b" := util.CloneByteSlice (struct.loadF buf.Buf.S "Data" "buf") in
    let: "ok" := buftxn.BufTxn__CommitWait "tx" #true in
    lock.release (struct.loadF RepBlock.S "m" "rb");;
    ("b", "ok").

Definition RepBlock__Write: val :=
  rec: "RepBlock__Write" "rb" "b" :=
    lock.acquire (struct.loadF RepBlock.S "m" "rb");;
    let: "tx" := buftxn.Begin (struct.loadF RepBlock.S "txn" "rb") in
    buftxn.BufTxn__OverWrite "tx" (struct.loadF RepBlock.S "a0" "rb") (#8 * disk.BlockSize) "b";;
    buftxn.BufTxn__OverWrite "tx" (struct.loadF RepBlock.S "a1" "rb") (#8 * disk.BlockSize) "b";;
    let: "ok" := buftxn.BufTxn__CommitWait "tx" #true in
    lock.release (struct.loadF RepBlock.S "m" "rb");;
    "ok".