/*
 * qm_we_retry.prg  -  arbeitet die Nachlauf-Queue der QM-Wareneingangs-
 * meldungen ab. Menue-/Scheduler-Aufruf.
 * -------------------------------------------------------------------------
 * Die Reihenfolge (SEQ) wird eingehalten, damit ein confirm nie vor seinem
 * reserve laeuft. Scheitert ein reserve erneut, wird das zugehoerige confirm
 * in diesem Lauf uebersprungen - sonst entstuende ein zweiter Datensatz mit
 * einer anderen Nummer als der bereits gedruckten.
 */

#define CRLF Chr(13)+Chr(10)

PROC RUN_QM_WE_RETRY()
   LOCAL hPayload, hRet
   LOCAL nStatus := 0, cResponse := ""
   LOCAL cText := "", cRef
   LOCAL nOk := 0, nFail := 0
   LOCAL aBlocked := {}

   QmQueueOpen()
   qmq->(dbSetOrder(1))
   qmq->(dbGoTop())

   DO WHILE ! qmq->(Eof())
      IF qmq->Status != "O"
         qmq->(dbSkip())
         LOOP
      ENDIF

      cRef := Trim(qmq->TraderRef)

      IF AScan(aBlocked, cRef) != 0
         // Das reserve dieses Wareneingangs haengt noch - das confirm muss warten.
         qmq->(dbSkip())
         LOOP
      ENDIF

      hPayload := NIL
      BEGIN SEQUENCE WITH {|e| Break(e)}
         hPayload := HB_JsonDecode(qmq->Payload)
      RECOVER
         hPayload := NIL
      END SEQUENCE

      IF ValType(hPayload) != "H"
         QmQueueMark(.F., "Payload nicht lesbar")
         qmq->(Rec_Lock(0))
         qmq->Status := "F"
         qmq->(dbUnLock())
         nFail++
         qmq->(dbSkip())
         LOOP
      ENDIF

      hRet := QmPost(hPayload, @nStatus, @cResponse)

      IF ValType(hRet) == "H"
         QmQueueMark(.T., cResponse)
         nOk++
         IF "inspection_number" $ hRet
            cText += Trim(hRet["inspection_number"]) + "  " + cRef
            IF "decision" $ hRet
               cText += "  (" + Trim(hRet["decision"]) + ")"
            ENDIF
            cText += CRLF
         ENDIF
      ELSE
         QmQueueMark(.F., IF(nStatus == 0, "Keine Verbindung", "HTTP " + LTrim(Str(nStatus)) + ": " + Left(cResponse, 200)))
         nFail++
         Aadd(aBlocked, cRef)
      ENDIF

      qmq->(dbSkip())
   ENDDO

   IF nOk > 0
      SendMessage("Qualitaet | WE-Pruefung nachgetragen", ;
                  LTrim(Str(nOk)) + " Wareneingaenge nachgemeldet", ;
                  cText)
   ENDIF
   IF nFail > 0 .AND. ! GetConfigValue("BATCHMODE")
      Tr_MsgBox(LTrim(Str(nFail)) + " Meldungen konnten nicht zugestellt werden.")
   ENDIF
RETURN

#include 'x:\run\qm_api.prg'
#include 'x:\run\qm_we_queue.prg'
