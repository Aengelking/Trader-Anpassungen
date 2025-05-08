PARAMETERS nWaNr,nArtNr
   NetUse("engkund","ku")

   wer->(dbSetOrder(1))
   wer->(dbSeek( str(nWaNr,6) ))

   IF Empty(wer->Liefma)
      IF ! GetConfigValue("BATCHMODE")
         aOptions := {"abbrechen"}
         IF Tr_Getini(28) == 9 .OR. (Date() >= StoD("20250407") .AND. Date() <= StoD("20250417"))
            Aadd(aOptions,"manuell ausl”sen")
         ENDIF
         IF TR_MsgBox("Fertigungsauftr„ge nicht manuell ausl”sen!",,aOptions) != 2
            RETURN .F.
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