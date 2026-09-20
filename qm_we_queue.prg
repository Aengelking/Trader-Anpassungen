/*
 * qm_we_queue.prg  -  Nachlauf-Warteschlange fuer die QM-Wareneingangsmeldung.
 * ---------------------------------------------------------------------------
 * Wird per #include am DATEIENDE von qm_we_register.prg und qm_we_retry.prg
 * eingebunden; alles STATIC. Wenn das Portal beim Buchen nicht erreichbar ist,
 * darf der Wareneingang trotzdem durchlaufen - der Aufruf landet hier und wird
 * spaeter von RUN_QM_WE_RETRY nachgefahren.
 *
 * STATUS: "O" = offen, "D" = erledigt, "F" = endgueltig fehlgeschlagen
 * PHASE : "reserve" | "confirm"
 * SEQ   : Reihenfolge, damit ein confirm nie vor seinem reserve laeuft.
 */

#define QM_QUEUE_MAXTRIES 8

STATIC FUNCTION QmQueuePath()
RETURN IF(GetConfigValue("FIRMPATH") != ".", GetConfigValue("FIRMPATH") + "\", "")

// Oeffnet die Queue und legt sie beim ersten Aufruf an.
STATIC FUNCTION QmQueueOpen()
   LOCAL cPath := QmQueuePath()
   LOCAL aStruct

   IF ! Leto_File(cPath + "qmwequeue.dbf")
      aStruct := {}
      Aadd(aStruct, {"SEQ",       "N",  8, 0})   // Reihenfolge der Meldungen
      Aadd(aStruct, {"TRADERREF", "C", 40, 0})   // Besnr/Posnr/Beleg/Artikelnr
      Aadd(aStruct, {"PHASE",     "C",  8, 0})   // reserve | confirm
      Aadd(aStruct, {"PAYLOAD",   "M", 10, 0})   // JSON, so wie es raus soll
      Aadd(aStruct, {"TRIES",     "N",  3, 0})
      Aadd(aStruct, {"LASTTRY",   "D",  8, 0})
      Aadd(aStruct, {"STATUS",    "C",  1, 0})   // O | D | F
      Aadd(aStruct, {"RESULT",    "M", 10, 0})   // Antwort bzw. Fehlertext
      dbCreate(cPath + "qmwequeue.dbf", aStruct, "LETO")
      NetUse("qmwequeue", "qmq")
      INDEX ON qmq->Seq TAG SEQ TO (cPath + "qmwequeue")
      INDEX ON qmq->TraderRef TAG TRADERREF TO (cPath + "qmwequeue")
   ELSE
      NetUse("qmwequeue", "qmq")
   ENDIF
RETURN .T.

// Naechste freie Reihenfolgenummer.
STATIC FUNCTION QmQueueNextSeq()
   LOCAL nSeq := 0
   qmq->(dbSetOrder(1))
   qmq->(dbGoBottom())
   IF ! qmq->(Bof())
      nSeq := qmq->Seq
   ENDIF
RETURN nSeq + 1

// Haengt eine nicht zugestellte Meldung an. hPayload ist der Hash, der ans
// Portal gehen sollte; er wird als JSON abgelegt und spaeter unveraendert
// erneut gesendet.
STATIC FUNCTION QmQueueAdd(hPayload, cError, cStatus)
   LOCAL cRef   := ""
   LOCAL cPhase := ""

   IF ValType(hPayload) != "H"
      RETURN .F.
   ENDIF
   Default(@cStatus, "O")
   IF "trader_ref" $ hPayload
      cRef := hPayload["trader_ref"]
   ENDIF
   IF "phase" $ hPayload
      cPhase := hPayload["phase"]
   ENDIF

   QmQueueOpen()
   qmq->(Add_Rec(0))
   qmq->Seq       := QmQueueNextSeq()
   qmq->TraderRef := Pad(cRef, 40)
   qmq->Phase     := Pad(cPhase, 8)
   qmq->Payload   := HB_JsonEncode(hPayload)
   qmq->Tries     := 0
   qmq->LastTry   := CToD("")
   qmq->Status    := cStatus
   qmq->Result    := IF(ValType(cError) == "C", cError, "")
   qmq->(dbUnLock())
RETURN .T.

// Ergebnis eines Nachlaufversuchs festhalten.
STATIC FUNCTION QmQueueMark(lOk, cText)
   qmq->(Rec_Lock(0))
   qmq->Tries   := qmq->Tries + 1
   qmq->LastTry := Date()
   qmq->Result  := IF(ValType(cText) == "C", cText, "")
   IF lOk
      qmq->Status := "D"
   ELSEIF qmq->Tries >= QM_QUEUE_MAXTRIES
      qmq->Status := "F"
   ENDIF
   qmq->(dbUnLock())
RETURN .T.
