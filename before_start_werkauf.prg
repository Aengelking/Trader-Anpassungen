PROC HOOK_BEFORE_START_WERKAUF
PARAMETERS nWaNr,nArtNr
LOCAL cMissing
   NetUse("engkund","ku")


   wer->(dbSetOrder(1))
   wer->(dbSeek( str(nWaNr,6) ))

   IF Empty(wer->Liefma)
      IF ! GetConfigValue("BATCHMODE")
         IF ! WAStatus(,@cMissing)
            IF Tr_MsgBox("Auftrag kann nicht ausgel”st werden",,{"Ok","Grnde anzeigen"}) == 2
               MemoEdit(cMissing)
            ENDIF
            RETURN .F.
         ELSE
            aOptions := {"abbrechen"}
            IF Tr_Getini(28) == 9 .OR. (Tr_Getini(28) == 67 .AND. Date() >= StoD("20250609") .AND. Date() <= StoD("20250620"))
               Aadd(aOptions,"manuell ausl”sen")
            ENDIF
            IF TR_MsgBox("Fertigungsauftr„ge nicht manuell ausl”sen!",,aOptions) != 2
               RETURN .F.
            ENDIF
         ENDIF
      ENDIF
   ELSE
      ku->(dbSeek( wer->Liefma+"L" ))
      oExtra := ku->(ExtraData():New(ku->Nummer))

      IF oExtra:WaDay != 0 .AND. WADue() .AND. WAStatus() .AND. (Dow(Date()) != oExtra:WaDay .OR. Time() > "15:00:00")
         IF Tr_MsgBox("Versandtag WHTECH ist "+CDow(Date()+oExtra:WaDay-Dow(Date()))+" bis 15:00",,{"trotzdem richten","abbrechen"}) != 1
            RETURN .F.
         ENDIF
      ENDIF
   ENDIF

RETURN .T.