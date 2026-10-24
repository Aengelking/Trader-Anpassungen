LOCAL aParts := {},cKunde,aList

   NetUse("englsre","re")
   NetUse("artikel","art")
   re->(dbSetOrder( 12 ))
   nNr := 22496


   re->(dbSeek( Str(nNr,6)+Str(0,3) ))
   IF Trim(re->Kunde) $  {"SCHNEIDG"}
      cKunde := re->Kunde
      dDate  := re->Rechdat
      aList := {Pad("Matchcode",25)+Chr(179)+Pad("Etikett",20),Replicate(Chr(196),25)+Chr(197)+Replicate(Chr(196),20)}
      re->(dbSetFilter({|| re->AoQty != 0 },"aoqty != 0"))
      re->(dbSkip(1))
      DO WHILE re->Rechnr == nNr .AND. ! re->(EOF())
         IF ! re->Artikelnr $ aParts
            Aadd(aParts,re->Artikelnr)
         ENDIF
         re->(dbSkip())
      ENDDO
      art->(dbSetOrder( 2 ))
      FOR nX := 1 TO Len(aParts)
         art->(dbSeek( Str(aParts[nX],6) ))
         aInv := {}
         re->(dbSetOrder( 15 ))
         re->(dbSeek( cKunde+art->Matchcode ))
         DO WHILE re->Kunde == cKunde .AND. re->Matchcode == art->Matchcode .AND. Len(aInv) < 3
            IF re->Rechnr != nNr .AND. ! re->Rechnr $ aInv .AND. re->Packed .AND. re->Rechdat < dDate
               Aadd(aInv,re->Rechnr)
            ENDIF
            re->(dbSkip())
         ENDDO
         IF Len(aInv) != 3
            Aadd(aList,art->Matchcode+Chr(179)+Pad("Serienanlauf",20))
         ENDIF
      NEXT
      re->(dbClearFilter())
      re->(dbSetOrder( 12 ))
      IF Len(aList) > 2
         DO WHILE Tr_MsgBox(aList,"ETIKETTEN AUFBRINGEN",{"abbrechen","OK"}) != 2
         ENDDO
      ENDIF
   ENDIF

