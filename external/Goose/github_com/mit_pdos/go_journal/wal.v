(* autogenerated from github.com/mit-pdos/go-journal/wal *)
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.disk_prelude.

From Goose Require github_com.mit_pdos.go_journal.common.
From Goose Require github_com.mit_pdos.go_journal.util.
From Goose Require github_com.tchajed.marshal.

(* 00walconst.go *)

(*  wal implements write-ahead logging

    The layout of log:
    [ installed writes | logged writes | in-memory/logged | unstable in-memory ]
     ^                   ^               ^                  ^
     0                   memStart        diskEnd            nextDiskEnd

    Blocks in the range [diskEnd, nextDiskEnd) are in the process of
    being logged.  Blocks in unstable are unstably committed (i.e.,
    written by NFS Write with the unstable flag and they can be lost
    on crash). Later transactions may absorb them (e.g., a later NFS
    write may update the same inode or indirect block).  The code
    implements a policy of postponing writing unstable blocks to disk
    as long as possible to maximize the chance of absorption (i.e.,
    commitWait or log is full).  It may better to start logging
    earlier. *)

(* space for the end position *)
Definition HDRMETA : expr := #8.

Definition HDRADDRS : expr := (disk.BlockSize - HDRMETA) `quot` #8.

Definition LOGSZ : expr := HDRADDRS.

(* 2 for log header *)
Definition LOGDISKBLOCKS : expr := HDRADDRS + #2.

Definition LOGHDR : expr := #0.

Definition LOGHDR2 : expr := #1.

Definition LOGSTART : expr := #2.

(* 0circular.go *)

Definition LogPosition: ty := uint64T.

Definition Update := struct.decl [
  "Addr" :: uint64T;
  "Block" :: disk.blockT
].

Definition MkBlockData: val :=
  rec: "MkBlockData" "bn" "blk" :=
    let: "b" := struct.mk Update [
      "Addr" ::= "bn";
      "Block" ::= "blk"
    ] in
    "b".

Definition circularAppender := struct.decl [
  "diskAddrs" :: slice.T uint64T
].

(* initCircular takes ownership of the circular log, which is the first
   LOGDISKBLOCKS of the disk. *)
Definition initCircular: val :=
  rec: "initCircular" "d" :=
    let: "b0" := NewSlice byteT disk.BlockSize in
    disk.Write LOGHDR "b0";;
    disk.Write LOGHDR2 "b0";;
    let: "addrs" := NewSlice uint64T HDRADDRS in
    struct.new circularAppender [
      "diskAddrs" ::= "addrs"
    ].

(* decodeHdr1 decodes (end, start) from hdr1 *)
Definition decodeHdr1: val :=
  rec: "decodeHdr1" "hdr1" :=
    let: "dec1" := marshal.NewDec "hdr1" in
    let: "end" := marshal.Dec__GetInt "dec1" in
    let: "addrs" := marshal.Dec__GetInts "dec1" HDRADDRS in
    ("end", "addrs").

(* decodeHdr2 reads start from hdr2 *)
Definition decodeHdr2: val :=
  rec: "decodeHdr2" "hdr2" :=
    let: "dec2" := marshal.NewDec "hdr2" in
    let: "start" := marshal.Dec__GetInt "dec2" in
    "start".

Definition recoverCircular: val :=
  rec: "recoverCircular" "d" :=
    let: "hdr1" := disk.Read LOGHDR in
    let: "hdr2" := disk.Read LOGHDR2 in
    let: ("end", "addrs") := decodeHdr1 "hdr1" in
    let: "start" := decodeHdr2 "hdr2" in
    let: "bufs" := ref (zero_val (slice.T (struct.t Update))) in
    let: "pos" := ref_to uint64T "start" in
    (for: (λ: <>, ![uint64T] "pos" < "end"); (λ: <>, "pos" <-[uint64T] ![uint64T] "pos" + #1) := λ: <>,
      let: "addr" := SliceGet uint64T "addrs" ((![uint64T] "pos") `rem` LOGSZ) in
      let: "b" := disk.Read (LOGSTART + (![uint64T] "pos") `rem` LOGSZ) in
      "bufs" <-[slice.T (struct.t Update)] SliceAppend (struct.t Update) (![slice.T (struct.t Update)] "bufs") (struct.mk Update [
        "Addr" ::= "addr";
        "Block" ::= "b"
      ]);;
      Continue);;
    (struct.new circularAppender [
       "diskAddrs" ::= "addrs"
     ], "start", "end", ![slice.T (struct.t Update)] "bufs").

Definition circularAppender__hdr1: val :=
  rec: "circularAppender__hdr1" "c" "end" :=
    let: "enc" := marshal.NewEnc disk.BlockSize in
    marshal.Enc__PutInt "enc" "end";;
    marshal.Enc__PutInts "enc" (struct.loadF circularAppender "diskAddrs" "c");;
    marshal.Enc__Finish "enc".

Definition hdr2: val :=
  rec: "hdr2" "start" :=
    let: "enc" := marshal.NewEnc disk.BlockSize in
    marshal.Enc__PutInt "enc" "start";;
    marshal.Enc__Finish "enc".

Definition circularAppender__logBlocks: val :=
  rec: "circularAppender__logBlocks" "c" "d" "end" "bufs" :=
    ForSlice (struct.t Update) "i" "buf" "bufs"
      (let: "pos" := "end" + "i" in
      let: "blk" := struct.get Update "Block" "buf" in
      let: "blkno" := struct.get Update "Addr" "buf" in
      util.DPrintf #5 (#(str"logBlocks: %d to log block %d
      ")) #();;
      disk.Write (LOGSTART + "pos" `rem` LOGSZ) "blk";;
      SliceSet uint64T (struct.loadF circularAppender "diskAddrs" "c") ("pos" `rem` LOGSZ) "blkno");;
    #().

Definition circularAppender__Append: val :=
  rec: "circularAppender__Append" "c" "d" "end" "bufs" :=
    circularAppender__logBlocks "c" "d" "end" "bufs";;
    disk.Barrier #();;
    let: "newEnd" := "end" + slice.len "bufs" in
    let: "b" := circularAppender__hdr1 "c" "newEnd" in
    disk.Write LOGHDR "b";;
    disk.Barrier #();;
    #().

Definition Advance: val :=
  rec: "Advance" "d" "newStart" :=
    let: "b" := hdr2 "newStart" in
    disk.Write LOGHDR2 "b";;
    disk.Barrier #();;
    #().

(* 0sliding.go *)

Definition sliding := struct.decl [
  "log" :: slice.T (struct.t Update);
  "start" :: LogPosition;
  "mutable" :: LogPosition;
  "needFlush" :: boolT;
  "addrPos" :: mapT LogPosition
].

Definition mkSliding: val :=
  rec: "mkSliding" "log" "start" :=
    let: "addrPos" := NewMap LogPosition #() in
    ForSlice (struct.t Update) "i" "buf" "log"
      (MapInsert "addrPos" (struct.get Update "Addr" "buf") ("start" + "i"));;
    struct.new sliding [
      "log" ::= "log";
      "start" ::= "start";
      "mutable" ::= "start" + slice.len "log";
      "addrPos" ::= "addrPos"
    ].

Definition sliding__end: val :=
  rec: "sliding__end" "s" :=
    struct.loadF sliding "start" "s" + slice.len (struct.loadF sliding "log" "s").

Definition sliding__get: val :=
  rec: "sliding__get" "s" "pos" :=
    SliceGet (struct.t Update) (struct.loadF sliding "log" "s") ("pos" - struct.loadF sliding "start" "s").

Definition sliding__posForAddr: val :=
  rec: "sliding__posForAddr" "s" "a" :=
    let: ("pos", "ok") := MapGet (struct.loadF sliding "addrPos" "s") "a" in
    ("pos", "ok").

(* update does an in-place absorb of an update to u

   internal to sliding *)
Definition sliding__update: val :=
  rec: "sliding__update" "s" "pos" "u" :=
    SliceSet (struct.t Update) (SliceSkip (struct.t Update) (struct.loadF sliding "log" "s") (struct.loadF sliding "mutable" "s" - struct.loadF sliding "start" "s")) ("pos" - struct.loadF sliding "mutable" "s") "u";;
    #().

(* append writes an update that cannot be absorbed

   internal to sliding *)
Definition sliding__append: val :=
  rec: "sliding__append" "s" "u" :=
    let: "pos" := struct.loadF sliding "start" "s" + slice.len (struct.loadF sliding "log" "s") in
    struct.storeF sliding "log" "s" (SliceAppend (struct.t Update) (struct.loadF sliding "log" "s") "u");;
    MapInsert (struct.loadF sliding "addrPos" "s") (struct.get Update "Addr" "u") "pos";;
    #().

(* Absorbs writes in in-memory transactions (avoiding those that might be in
   the process of being logged or installed).

   Assumes caller holds memLock *)
Definition sliding__memWrite: val :=
  rec: "sliding__memWrite" "s" "bufs" :=
    let: "pos" := ref_to LogPosition (sliding__end "s") in
    ForSlice (struct.t Update) <> "buf" "bufs"
      (let: ("oldpos", "ok") := sliding__posForAddr "s" (struct.get Update "Addr" "buf") in
      (if: "ok" && ("oldpos" ≥ struct.loadF sliding "mutable" "s")
      then
        util.DPrintf #5 (#(str"memWrite: absorb %d pos %d old %d
        ")) #();;
        sliding__update "s" "oldpos" "buf"
      else
        (if: "ok"
        then
          util.DPrintf #5 (#(str"memLogMap: replace %d pos %d old %d
          ")) #()
        else
          util.DPrintf #5 (#(str"memLogMap: add %d pos %d
          ")) #());;
        sliding__append "s" "buf";;
        "pos" <-[LogPosition] ![LogPosition] "pos" + #1));;
    #().

(* takeFrom takes the read-only updates from a logical start position to the
   current mutable boundary *)
Definition sliding__takeFrom: val :=
  rec: "sliding__takeFrom" "s" "start" :=
    SliceSkip (struct.t Update) (SliceTake (struct.loadF sliding "log" "s") (struct.loadF sliding "mutable" "s" - struct.loadF sliding "start" "s")) ("start" - struct.loadF sliding "start" "s").

(* takeTill takes the read-only updates till a logical start position (which
   should be within the read-only region; that is, end <= s.mutable) *)
Definition sliding__takeTill: val :=
  rec: "sliding__takeTill" "s" "end" :=
    SliceTake (SliceTake (struct.loadF sliding "log" "s") (struct.loadF sliding "mutable" "s" - struct.loadF sliding "start" "s")) ("end" - struct.loadF sliding "start" "s").

Definition sliding__intoMutable: val :=
  rec: "sliding__intoMutable" "s" :=
    SliceSkip (struct.t Update) (struct.loadF sliding "log" "s") (struct.loadF sliding "mutable" "s" - struct.loadF sliding "start" "s").

(* deleteFrom deletes read-only updates up to newStart,
   correctly updating the start position *)
Definition sliding__deleteFrom: val :=
  rec: "sliding__deleteFrom" "s" "newStart" :=
    let: "start" := struct.loadF sliding "start" "s" in
    ForSlice (struct.t Update) "i" "u" (SliceTake (SliceTake (struct.loadF sliding "log" "s") (struct.loadF sliding "mutable" "s" - "start")) ("newStart" - "start"))
      (let: "pos" := "start" + "i" in
      let: "blkno" := struct.get Update "Addr" "u" in
      let: ("oldPos", "ok") := MapGet (struct.loadF sliding "addrPos" "s") "blkno" in
      (if: "ok" && ("oldPos" ≤ "pos")
      then
        util.DPrintf #5 (#(str"memLogMap: del %d %d
        ")) #();;
        MapDelete (struct.loadF sliding "addrPos" "s") "blkno"
      else #()));;
    struct.storeF sliding "log" "s" (SliceSkip (struct.t Update) (struct.loadF sliding "log" "s") ("newStart" - "start"));;
    struct.storeF sliding "start" "s" "newStart";;
    #().

Definition sliding__clearMutable: val :=
  rec: "sliding__clearMutable" "s" :=
    struct.storeF sliding "mutable" "s" (sliding__end "s");;
    #().

(* 0waldefs.go *)

Definition WalogState := struct.decl [
  "memLog" :: struct.ptrT sliding;
  "diskEnd" :: LogPosition;
  "shutdown" :: boolT;
  "nthread" :: uint64T
].

Definition WalogState__memEnd: val :=
  rec: "WalogState__memEnd" "st" :=
    sliding__end (struct.loadF WalogState "memLog" "st").

Definition Walog := struct.decl [
  "memLock" :: lockRefT;
  "d" :: disk.Disk;
  "circ" :: struct.ptrT circularAppender;
  "st" :: struct.ptrT WalogState;
  "condLogger" :: condvarRefT;
  "condInstall" :: condvarRefT;
  "condShut" :: condvarRefT
].

Definition Walog__LogSz: val :=
  rec: "Walog__LogSz" "l" :=
    common.HDRADDRS.

(* installer.go *)

(* cutMemLog deletes from the memLog through installEnd, after these blocks have
   been installed. This transitions from a state where the on-disk install point
   is already at installEnd, but memStart < installEnd.

   Assumes caller holds memLock *)
Definition WalogState__cutMemLog: val :=
  rec: "WalogState__cutMemLog" "st" "installEnd" :=
    sliding__deleteFrom (struct.loadF WalogState "memLog" "st") "installEnd";;
    #().

(* absorbBufs returns bufs' such that applyUpds(d, bufs') = applyUpds(d,
   bufs) and bufs' has unique addresses *)
Definition absorbBufs: val :=
  rec: "absorbBufs" "bufs" :=
    let: "s" := mkSliding slice.nil #0 in
    sliding__memWrite "s" "bufs";;
    sliding__intoMutable "s".

(* installBlocks installs the updates in bufs to the data region

   Does not hold the memLock. De-duplicates writes in bufs such that:
   (1) after installBlocks,
   the equivalent of applying bufs in order is accomplished
   (2) at all intermediate points,
   the data region either has the value from the old transaction or the new
   transaction (with all of bufs applied). *)
Definition installBlocks: val :=
  rec: "installBlocks" "d" "bufs" :=
    let: "absorbed" := absorbBufs "bufs" in
    ForSlice (struct.t Update) "i" "buf" "absorbed"
      (let: "blkno" := struct.get Update "Addr" "buf" in
      let: "blk" := struct.get Update "Block" "buf" in
      util.DPrintf #5 (#(str"installBlocks: write log block %d to %d
      ")) #();;
      disk.Write "blkno" "blk");;
    #().

(* logInstall installs one on-disk transaction from the disk log to the data
   region.

   Returns (blkCount, installEnd)

   blkCount is the number of blocks installed (only used for liveness)

   installEnd is the new last position installed to the data region (only used
   for debugging)

   Installer holds memLock *)
Definition Walog__logInstall: val :=
  rec: "Walog__logInstall" "l" :=
    let: "installEnd" := struct.loadF WalogState "diskEnd" (struct.loadF Walog "st" "l") in
    let: "bufs" := sliding__takeTill (struct.loadF WalogState "memLog" (struct.loadF Walog "st" "l")) "installEnd" in
    let: "numBufs" := slice.len "bufs" in
    (if: ("numBufs" = #0)
    then (#0, "installEnd")
    else
      lock.release (struct.loadF Walog "memLock" "l");;
      util.DPrintf #5 (#(str"logInstall up to %d
      ")) #();;
      installBlocks (struct.loadF Walog "d" "l") "bufs";;
      disk.Barrier #();;
      Advance (struct.loadF Walog "d" "l") "installEnd";;
      lock.acquire (struct.loadF Walog "memLock" "l");;
      WalogState__cutMemLog (struct.loadF Walog "st" "l") "installEnd";;
      lock.condBroadcast (struct.loadF Walog "condInstall" "l");;
      ("numBufs", "installEnd")).

(* installer installs blocks from the on-disk log to their home location. *)
Definition Walog__installer: val :=
  rec: "Walog__installer" "l" :=
    lock.acquire (struct.loadF Walog "memLock" "l");;
    struct.storeF WalogState "nthread" (struct.loadF Walog "st" "l") (struct.loadF WalogState "nthread" (struct.loadF Walog "st" "l") + #1);;
    Skip;;
    (for: (λ: <>, ~ (struct.loadF WalogState "shutdown" (struct.loadF Walog "st" "l"))); (λ: <>, Skip) := λ: <>,
      let: ("blkcount", "txn") := Walog__logInstall "l" in
      (if: "blkcount" > #0
      then
        util.DPrintf #5 (#(str"Installed till txn %d
        ")) #();;
        Continue
      else
        lock.condWait (struct.loadF Walog "condInstall" "l");;
        Continue));;
    util.DPrintf #1 (#(str"installer: shutdown
    ")) #();;
    struct.storeF WalogState "nthread" (struct.loadF Walog "st" "l") (struct.loadF WalogState "nthread" (struct.loadF Walog "st" "l") - #1);;
    lock.condSignal (struct.loadF Walog "condShut" "l");;
    lock.release (struct.loadF Walog "memLock" "l");;
    #().

(* logger.go *)

(* Waits on the installer thread to free space in the log so everything
   logged fits on disk.

   establishes uint64(len(l.memLog)) <= LOGSZ *)
Definition Walog__waitForSpace: val :=
  rec: "Walog__waitForSpace" "l" :=
    Skip;;
    (for: (λ: <>, slice.len (struct.loadF sliding "log" (struct.loadF WalogState "memLog" (struct.loadF Walog "st" "l"))) > LOGSZ); (λ: <>, Skip) := λ: <>,
      lock.condWait (struct.loadF Walog "condInstall" "l");;
      Continue);;
    #().

Definition Walog__flushIfNeeded: val :=
  rec: "Walog__flushIfNeeded" "l" :=
    (if: struct.loadF sliding "needFlush" (struct.loadF WalogState "memLog" (struct.loadF Walog "st" "l"))
    then
      sliding__clearMutable (struct.loadF WalogState "memLog" (struct.loadF Walog "st" "l"));;
      struct.storeF sliding "needFlush" (struct.loadF WalogState "memLog" (struct.loadF Walog "st" "l")) #false;;
      #()
    else #()).

(* logAppend appends to the log, if it can find transactions to append.

   It grabs the new writes in memory and not on disk through l.nextDiskEnd; if
   there are any such writes, it commits them atomically.

   assumes caller holds memLock

   Returns true if it made progress (for liveness, not important for
   correctness). *)
Definition Walog__logAppend: val :=
  rec: "Walog__logAppend" "l" "circ" :=
    Walog__waitForSpace "l";;
    Walog__flushIfNeeded "l";;
    let: "diskEnd" := struct.loadF WalogState "diskEnd" (struct.loadF Walog "st" "l") in
    let: "newbufs" := sliding__takeFrom (struct.loadF WalogState "memLog" (struct.loadF Walog "st" "l")) "diskEnd" in
    (if: (slice.len "newbufs" = #0)
    then #false
    else
      lock.release (struct.loadF Walog "memLock" "l");;
      circularAppender__Append "circ" (struct.loadF Walog "d" "l") "diskEnd" "newbufs";;
      lock.acquire (struct.loadF Walog "memLock" "l");;
      Linearize;;
      struct.storeF WalogState "diskEnd" (struct.loadF Walog "st" "l") ("diskEnd" + slice.len "newbufs");;
      lock.condBroadcast (struct.loadF Walog "condLogger" "l");;
      lock.condBroadcast (struct.loadF Walog "condInstall" "l");;
      #true).

(* logger writes blocks from the in-memory log to the on-disk log

   Operates by continuously polling for in-memory transactions, driven by
   condLogger for scheduling *)
Definition Walog__logger: val :=
  rec: "Walog__logger" "l" "circ" :=
    lock.acquire (struct.loadF Walog "memLock" "l");;
    struct.storeF WalogState "nthread" (struct.loadF Walog "st" "l") (struct.loadF WalogState "nthread" (struct.loadF Walog "st" "l") + #1);;
    Skip;;
    (for: (λ: <>, ~ (struct.loadF WalogState "shutdown" (struct.loadF Walog "st" "l"))); (λ: <>, Skip) := λ: <>,
      let: "progress" := Walog__logAppend "l" "circ" in
      (if: ~ "progress"
      then
        lock.condWait (struct.loadF Walog "condLogger" "l");;
        Continue
      else Continue));;
    util.DPrintf #1 (#(str"logger: shutdown
    ")) #();;
    struct.storeF WalogState "nthread" (struct.loadF Walog "st" "l") (struct.loadF WalogState "nthread" (struct.loadF Walog "st" "l") - #1);;
    lock.condSignal (struct.loadF Walog "condShut" "l");;
    lock.release (struct.loadF Walog "memLock" "l");;
    #().

(* wal.go *)

Definition mkLog: val :=
  rec: "mkLog" "disk" :=
    let: ((("circ", "start"), "end"), "memLog") := recoverCircular "disk" in
    let: "ml" := lock.new #() in
    let: "st" := struct.new WalogState [
      "memLog" ::= mkSliding "memLog" "start";
      "diskEnd" ::= "end";
      "shutdown" ::= #false;
      "nthread" ::= #0
    ] in
    let: "l" := struct.new Walog [
      "d" ::= "disk";
      "circ" ::= "circ";
      "memLock" ::= "ml";
      "st" ::= "st";
      "condLogger" ::= lock.newCond "ml";
      "condInstall" ::= lock.newCond "ml";
      "condShut" ::= lock.newCond "ml"
    ] in
    util.DPrintf #1 (#(str"mkLog: size %d
    ")) #();;
    "l".

Definition Walog__startBackgroundThreads: val :=
  rec: "Walog__startBackgroundThreads" "l" :=
    Fork (Walog__logger "l" (struct.loadF Walog "circ" "l"));;
    Fork (Walog__installer "l");;
    #().

Definition MkLog: val :=
  rec: "MkLog" "disk" :=
    let: "l" := mkLog "disk" in
    Walog__startBackgroundThreads "l";;
    "l".

(* Assumes caller holds memLock *)
Definition doMemAppend: val :=
  rec: "doMemAppend" "memLog" "bufs" :=
    sliding__memWrite "memLog" "bufs";;
    let: "txn" := sliding__end "memLog" in
    "txn".

(* Grab all of the current transactions and record them for the next group commit (when the logger gets around to it).

   This is a separate function purely for verification purposes; the code isn't complicated but we have to manipulate
   some ghost state and justify this value of nextDiskEnd.

   Assumes caller holds memLock. *)
Definition WalogState__endGroupTxn: val :=
  rec: "WalogState__endGroupTxn" "st" :=
    struct.storeF sliding "needFlush" (struct.loadF WalogState "memLog" "st") #true;;
    #().

Definition copyUpdateBlock: val :=
  rec: "copyUpdateBlock" "u" :=
    util.CloneByteSlice (struct.get Update "Block" "u").

(* readMem implements ReadMem, assuming memLock is held *)
Definition WalogState__readMem: val :=
  rec: "WalogState__readMem" "st" "blkno" :=
    let: ("pos", "ok") := sliding__posForAddr (struct.loadF WalogState "memLog" "st") "blkno" in
    (if: "ok"
    then
      util.DPrintf #5 (#(str"read memLogMap: read %d pos %d
      ")) #();;
      let: "u" := sliding__get (struct.loadF WalogState "memLog" "st") "pos" in
      let: "blk" := copyUpdateBlock "u" in
      ("blk", #true)
    else (slice.nil, #false)).

(* Read from only the in-memory cached state (the unstable and logged parts of
   the wal). *)
Definition Walog__ReadMem: val :=
  rec: "Walog__ReadMem" "l" "blkno" :=
    lock.acquire (struct.loadF Walog "memLock" "l");;
    let: ("blk", "ok") := WalogState__readMem (struct.loadF Walog "st" "l") "blkno" in
    Linearize;;
    lock.release (struct.loadF Walog "memLock" "l");;
    ("blk", "ok").

(* Read from only the installed state (a subset of durable state). *)
Definition Walog__ReadInstalled: val :=
  rec: "Walog__ReadInstalled" "l" "blkno" :=
    disk.Read "blkno".

(* Read reads from the latest memory state, but does so in a
   difficult-to-linearize way (specifically, it is future-dependent when to
   linearize between the l.memLog.Unlock() and the eventual disk read, due to
   potential concurrent cache or disk writes). *)
Definition Walog__Read: val :=
  rec: "Walog__Read" "l" "blkno" :=
    let: ("blk", "ok") := Walog__ReadMem "l" "blkno" in
    (if: "ok"
    then "blk"
    else Walog__ReadInstalled "l" "blkno").

Definition WalogState__updatesOverflowU64: val :=
  rec: "WalogState__updatesOverflowU64" "st" "newUpdates" :=
    util.SumOverflows (WalogState__memEnd "st") "newUpdates".

(* TODO: relate this calculation to the circular log free space *)
Definition WalogState__memLogHasSpace: val :=
  rec: "WalogState__memLogHasSpace" "st" "newUpdates" :=
    let: "memSize" := WalogState__memEnd "st" - struct.loadF WalogState "diskEnd" "st" in
    (if: "memSize" + "newUpdates" > LOGSZ
    then #false
    else #true).

(* Append to in-memory log.

   On success returns the pos for this append.

   On failure guaranteed to be idempotent (failure can only occur in principle,
   due overflowing 2^64 writes) *)
Definition Walog__MemAppend: val :=
  rec: "Walog__MemAppend" "l" "bufs" :=
    (if: slice.len "bufs" > LOGSZ
    then (#0, #false)
    else
      let: "txn" := ref_to LogPosition #0 in
      let: "ok" := ref_to boolT #true in
      lock.acquire (struct.loadF Walog "memLock" "l");;
      let: "st" := struct.loadF Walog "st" "l" in
      Skip;;
      (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
        (if: WalogState__updatesOverflowU64 "st" (slice.len "bufs")
        then
          "ok" <-[boolT] #false;;
          Break
        else
          (if: WalogState__memLogHasSpace "st" (slice.len "bufs")
          then
            "txn" <-[LogPosition] doMemAppend (struct.loadF WalogState "memLog" "st") "bufs";;
            Linearize;;
            Break
          else
            util.DPrintf #5 (#(str"memAppend: log is full; try again")) #();;
            WalogState__endGroupTxn "st";;
            lock.condBroadcast (struct.loadF Walog "condLogger" "l");;
            lock.condWait (struct.loadF Walog "condLogger" "l");;
            Continue)));;
      lock.release (struct.loadF Walog "memLock" "l");;
      (![LogPosition] "txn", ![boolT] "ok")).

(* Flush flushes a transaction pos (and all preceding transactions)

   The implementation waits until the logger has appended in-memory log up to
   txn to on-disk log. *)
Definition Walog__Flush: val :=
  rec: "Walog__Flush" "l" "pos" :=
    util.DPrintf #2 (#(str"Flush: commit till txn %d
    ")) #();;
    lock.acquire (struct.loadF Walog "memLock" "l");;
    lock.condBroadcast (struct.loadF Walog "condLogger" "l");;
    (if: "pos" > struct.loadF sliding "mutable" (struct.loadF WalogState "memLog" (struct.loadF Walog "st" "l"))
    then WalogState__endGroupTxn (struct.loadF Walog "st" "l")
    else #());;
    Skip;;
    (for: (λ: <>, ~ ("pos" ≤ struct.loadF WalogState "diskEnd" (struct.loadF Walog "st" "l"))); (λ: <>, Skip) := λ: <>,
      lock.condWait (struct.loadF Walog "condLogger" "l");;
      Continue);;
    Linearize;;
    lock.release (struct.loadF Walog "memLock" "l");;
    #().

(* Shutdown logger and installer *)
Definition Walog__Shutdown: val :=
  rec: "Walog__Shutdown" "l" :=
    util.DPrintf #1 (#(str"shutdown wal
    ")) #();;
    lock.acquire (struct.loadF Walog "memLock" "l");;
    struct.storeF WalogState "shutdown" (struct.loadF Walog "st" "l") #true;;
    lock.condBroadcast (struct.loadF Walog "condLogger" "l");;
    lock.condBroadcast (struct.loadF Walog "condInstall" "l");;
    Skip;;
    (for: (λ: <>, struct.loadF WalogState "nthread" (struct.loadF Walog "st" "l") > #0); (λ: <>, Skip) := λ: <>,
      util.DPrintf #1 (#(str"wait for logger/installer")) #();;
      lock.condWait (struct.loadF Walog "condShut" "l");;
      Continue);;
    lock.release (struct.loadF Walog "memLock" "l");;
    util.DPrintf #1 (#(str"wal done
    ")) #();;
    #().
