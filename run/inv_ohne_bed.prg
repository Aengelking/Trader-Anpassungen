NetUse("artikel","art")
NetUse("me","me")
NetUse("manufact","man")
NetUse("folgeart","fol")
fol->(dbSetOrder( 2 ))
cFile := Trim(Tr_Getini(1))+"\export\inv_ohne_bed.csv"
nH := FCreate(cFile)
IF Ferror() != 0
   Alert("Error creating file")
   RETURN
ENDIF
CLS
FWrite(nH,"Matchcode"+";"+"Artikel"+";"+HB_AnsiToOem("Überbestand")+";"+"Bedarf"+";"+"4 Monate Meldebestand"+";"+"6 mon. D/S Bedarf"+";"+"Wert"+";"+"Hersteller"+Chr(13)+Chr(10))

art->(dbGoTop())
DO WHILE ! art->(EOF()) .AND. Inkey() != 27
   IF art->Bestand > 1
      nReq := GetproductrequireMent(art->Artikelnr)
      nAvgreq := GetProductAvgRequirement(art->Artikelnr)
      fol->(dbSeek( Str(art->Artikelnr,6) ))
      DO WHILE ! fol->(EOF()) .AND. fol->Folgeart == art->Artikelnr
         IF fol->Artikelnr != 0
            nReq += GetProductRequirement(fol->Artikelnr)  //this only works if the main article is "nicht lagerfähig", so this needs extending to work correctly
         ENDIF
         fol->(dbSkip())
      ENDDO

      IF art->Bestand > Max(0,nReq) .AND. art->Bestand-nReq > art->Mindest*4 //art->Bestand-nReq > nAvgReq*6
      oArt := Artikel():New(.F.)
      oArt:Load(art->Artikelnr)

         nVal := (art->Bestand-nReq)*oArt:GetAvgBuyPrice(Date())
         IF nVal > 1
            man->(dbSeek( Str(art->Manufactur,5) ))

            FWrite(nH,Trim(art->Matchcode)+";"+Trim(art->Artikel)+";"+StrTran(LTrim(Transform(art->Bestand-nReq,Me(art->Me)))+";"+LTrim(Transform(nReq,Me(art->Me)))+";"+LTrim(Transform(art->Mindest*4,Me(art->Me)))+";"+LTrim(Transform(nAvgReq*6,Me(art->Me)))+";"+LTrim(Str(nVal,9,2)),".",",")+";"+man->Short+Chr(13)+Chr(10))
         ENDIF
      ENDIF
      @ 24,00 SAY art->Artikelnr
/*      IF art->Artikelnr == 5156
         ? "Bestand:",art->Bestand
         ? "Requirement:",nreq
         ? "Avg. Req.:",nAvgReq
         Inkey(0,128)
      ENDIF*/
   ENDIF
   art->(dbSkip())
ENDDo
FClose(nH)

WAPI_ShellExecute(,"open",cFile)