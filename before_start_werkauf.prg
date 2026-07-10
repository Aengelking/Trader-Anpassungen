FUNC HOOK_BEFORE_START_WERKAUF
PARAMETERS nWaNr,nArtNr
LOCAL cMissing
LOCAL oArtExtra
   NetUse("engkund","ku")


   wer->(dbSetOrder(1))
   wer->(dbSeek( str(nWaNr,6) ))

   NetUse("artikel","art")
   art->(dbSetOrder(2))
   art->(dbSeek( Str(wer->Artno,6) ))

   IF Empty(wer->Liefma)
      IF ! GetConfigValue("BATCHMODE")
         IF ! WAStatus(,@cMissing)
            IF Tr_MsgBox("Auftrag kann nicht ausgel”st werden",,{"Ok","Grnde anzeigen"}) == 2
               MemoEdit(cMissing)
            ENDIF
            RETURN .F.
         ELSE
            aOptions := {"abbrechen"}
            IF Tr_Getini(28) $ {9,37} 
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

      oArtExtra := art->(ExtraData():New(wer->Artno))      

      IF ! oArtExtra:WaManual .AND. oExtra:WaDay != 0 .AND. WADue() .AND. WAStatus() .AND. (Dow(Date()) != oExtra:WaDay .OR. Time() > "15:00:00")
         IF GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Versandtag WHTECH ist "+CDow(Date()+oExtra:WaDay-Dow(Date()))+" bis 15:00",,{"trotzdem richten","abbrechen"}) != 1
            RETURN .F.
         ENDIF
      ENDIF
   ENDIF

RETURN .T.