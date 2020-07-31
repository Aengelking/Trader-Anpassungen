LOCAL cFile := Trim(Tr_Getini(1))+"\export\mindest.csv"

Head(HB_AnsiToOem("Mindestbestände"))

NetUse("artikel","art",.F.,0)
NetUse("manufact","manu")

SET PRINTER TO (cFile)
SET PRINTER ON

?? "Matchcode;Hersteller;Anzahl Kunden;Mindestbestand;Empfohlener Mindestbestand;Lieferzeit"

hLZ := {;
   1=>11,; //bulgin
   11=>4,; //techno
   9=>2; //scolmore
}

Do While ! art->(Eof())
   If art->Lagerart
      hReqInc := GetProductRequirementAndIncoming(art->artikelnr)
      If hReqInc["cust_count"] >= 5
         nPerWeek := hReqInc["avgrequirement"]/30*IF(art->LZ==0,12,art->LZ)
         IF art->LZ == 0
            IF HHasKey(hLZ,art->Manufactur)
               nLZ := hLZ[art->Manufactur]
            ELSE
               nLZ := 12
            ENDIF
         ELSE
            nLZ := art->LZ
         ENDIF
         nMindest := nPerWeek*nLZ
         If (nMindest > 0 .AND. nMindest*.9 > art->Mindest) .OR. (art->Mindest > 0 .AND. art->Mindest > nMindest*1.2)
            cMe := Me(art->me)
            manu->(dbSeek( Str(art->Manufactur,5) ))
            ? Trim(art->Matchcode)+";"+Trim(manu->Short)+";"+LTrim(Str(hReqInc["cust_count"]))+";"+Transform(art->Mindest,cMe)+";"+Transform(nMindest,cMe)+";"+Ltrim(Str(nLz))
         Endif
      Endif
   Endif
   art->(dbSkip())
Enddo

WAPI_ShellExecute(,"open",cFile)

SET PRINTER TO
SET PRINTER OFF
