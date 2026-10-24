PARAMETERS cMsgId

LOCAL aAutoBeleg := {}

Alert("HERE")

Aadd(aAutoBeleg,{;
   "EMAIL"=>"@continental-corporation.com$",;
   "FILE"=>"Lieferplan.*.pdf",;
   "BLOCK"=>{|oMsg,cFile|
      TxtBox("Daten werden eingelesen...")
      aData := GetDataFromPDF(cFile,{"-a 512,0.0,840,550 -c 19,80,250 -p 1"},{=>},{"ORDER"=>"Nummer\s*([0-9]{10})","ENDDATE"=>"Materialfreigabe\s*bis\s*:\s*([0-9]{2}.[0-9]{2}.[0-9]{4})"},@hResults,,{"DATE"=>2,"QTY"=>3,"CHANGEQTY"=>4})
      TxtClear()
      ? ValToPrg(aData)
      ? ValToPrg(hResults)
      //SInkey(0)
      NetUse("artikel","art")
      art->(dbSetOrder( 2 ))
      NetUse("engauf","auf")
      auf->(dbSetORder( 12 ))
      cKunde :=  Pad("CONTIAUT",8)
      hResults["ORDER"] := Pad(hResults["ORDER"],20)
      hResults["ENDDATE"] := CtoD(hResults["ENDDATE"])
      auf->(dbSetFilter({|| auf->GelQty == 0 .AND. auf->BeStat <= 3 .AND. Right(Str(auf->Dterm,4),2) != "99"},"BeStat <= 3 .AND. GelQty == 0 .AND. Right(Str(auf->Dterm,4),2) != '99'")) //all (auch erledigte) ungenutzte positionen
      auf->(dbSeek( cKunde+hResults["ORDER"] ))
      art->(dbSeek( Str(auf->Artikelnr,6) ))
      cMe := Me(art->Me)
      FOR nX := 1 TO Len(aData)
         aData[nX]["QTY"] := Val(StrTran(aData[nX]["QTY"],".",""))
         aData[nX]["DATE"] := CtoD(aData[nX]["DATE"])
         IF aData[nX]["QTY"] == 0 .OR. Empty(aData[nX]["DATE"])
            HB_ADel(aData,nX,.T.)
            nX--
         ENDIF
      NEXT
      nX= 0
      DO WHILE auf->Kundma == cKunde .AND. auf->Aufnr == hResults["ORDER"]
         nX++
         oPos := AuftragPos():New(.F.)
         IF nX > Len(aData) .OR. aData[nX]["DATE"] > hResults["ENDDATE"]
            IF auf->BeStat < 3
               ? "Loesche ",Transform(auf->VkQty,cMe),art->me,auf->WDatum
               /*
               oPos:BeStat := 3
               oPos:Save()
               */
            ENDIF
         ELSE
            ? "Setze ",Transform(aData[nX]["QTY"],cME),art->Me,aData[nX]["DATE"],"bisher: ",auf->WDatum
            
            /*oPos:WDatum := aData[nX]["DATE"]
            oPos:DTerm := ???
            oPos:BeStat := 0
            */
         ENDIF
         auf->(dbSkip())
      ENDDO
      //übrige positionen jetzt hinzufügen
      DO WHILE nX < Len(aData)
         nX++
         IF aData[nX]["DATE"] <= hResults["ENDDATE"]
            ? "Neu ",Transform(aData[nX]["QTY"],cME),art->Me,aData[nX]["DATE"]
         ENDIF
      ENDDO
      auf->(dbClearFilter())
      Sinkey(0)
   };
})

IF ! AutoBeleg(aAutoBeleg,cMsgId)
   Engauft()
ENDIF

#include 'X:\run\auto_beleg.prg'
