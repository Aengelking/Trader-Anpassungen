LOCAL cFile
Head("Inventur")

NetUse("artikel","art",.F.,0)
NetUse("werkauf","wer",.F.,0)
NetUse("engabg","abg",.F.,0)

art->(dbGoTop())

nWaren := 0
nRHB := 0
nUnfertig := 0


//nType := TR_MsgBox("Preisbasis",,{"Letzte EK","D/S Preis"})
nType := 2 //D/S Preise
dDate := GetBox(Date()-3,"Vergleichsdatum","99.99.99")
cFile := Trim(Tr_Getini(1))+"\export\inventur_comp_"+DToS(dDate)+"-"+DToS(Date())+".csv"

abg->(dbSetOrder(3)) //matchcode+DTos(Transdate)+TransTime

cList := Pad("Matchcode",25)+" "+Pad("Bestand",12)+" "+Pad("Vergleich",12)+" "+PadL("Differenz",6)+PadL("Gesamt",12)+Chr(13)+Chr(10)
aList := {{"Matchcode","Bestand","Vergleich","Differenz","Gesamtwert"}}
cUnfert := ""
nTotal := 0

abg->(dbSetFilter({|| /*! abg->BuArt $ "STD" .AND.*/ abg->Bestand >= 0},/*"! BuArt $ 'STD' .AND.*/"Bestand >= 0"))

Do While ! art->(Eof())
   @ 01,00 SAY art->Matchcode

   abg->(dbSeek(art->Matchcode,.T.))

   nBestand := 0
   nBestandNew := art->Bestand

   Do While   abg->Matchcode == art->Matchcode .AND. ! abg->(Eof()) //.AND. abg->TransDate <= dDate//! lFound
      IF abg->TransDate <= dDate
         nBestand := abg->Bestand
         nBestandNew := abg->Bestand
      ELSEIF abg->Buart $ "ABG-ZUG-INV"  //only take inventur changes into account
         nBestandNew := abg->Bestand
      ENDIF
      abg->(dbSkip(1))
   Enddo

   If nBestandNew != nBestand
      IF nType == 2
        oArt := Artikel():New(.F.)
        oArt:Load(art->Artikelnr)
        nPreis := oArt:GetAvgBuyPrice(date())
      ELSE
       nPreis := art->letzte_ek/art->pe*Currate(art->money,"E")
      ENDIF
      If art->Bezug >= 5
         nPreis := StCalc(art->artikelnr,If(nType==2,5,1),99,.T.)
      Endif
      nValue := (art->Bestand-nBestand)*nPreis
      //IF ABS(nValue) > 50
         nTotal += nValue
         cList += art->Matchcode+" "+PadL(Str(art->Bestand),12)+" "+PadL(Str(nBestand),12)+" "+Str(art->Bestand-nBestand,6)+" "+PadL(Str(nValue),12)+Chr(13)+Chr(10)
         Aadd(aList,{art->Matchcode,art->Bestand,nBestand,art->Bestand-nBestand,nValue})
      //ENDIF
   Endif

   art->(dbSkip())
Enddo
cList += Space(25)+" "+Space(12)+" "+Space(12)+" "+Space(6)+" "+PadL(Str(nTotal),12)
abg->(dbClearFilter())


SaveAsCSV(cFile,aList)
WAPI_ShellExecute(,"open",cFile)


SetCursor(.T.)
MemoEdit(cList)
