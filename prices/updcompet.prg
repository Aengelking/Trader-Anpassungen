FUNCTION RUN_PRICES_UPDCOMPET( lDisp,lForce )
LOCAL aCompet
LOCAL hPrices
LOCAL aPriceList
LOCAL nMenge,nPrice,lUpd,nError
LOCAL nRecno := art->(Recno())
LOCAL nOrd
LOCAL nArtnr := art->Artikelnr
LOCAL nPole,aMatch,cInlet
LOCAL cMatch,nPe := 1
LOCAL nY,nX
LOCAL lDbg := .F. //Tr_Getini(28) == 9
LOCAL lBuerklin := .F.
//LOCAL aEnv := SaveEnv()

MEMVAR c_five

MEMVAR cPriceError 
PUBLIC cPriceError

Default(@lDisp,.T.)
Default(@lForce,.F.)

IF .F. //Tr_Getini(28) == 9
   aCompet := {"BšRKLIN"}
ELSE
   aCompet := {"BšRKLIN","RS","ARROW","FARNELL" } //"Schukat","Conrad", "Reichelt","Mouser" does not work
ENDIF

IF lDisp
   TxtBox("Preise werden aktualisiert...")
ENDIF

NetUse("artlief","ali")
NetUse("compprice","cmpr")
NetUse("comprice2","cmp2")
NetUse("engkund","ku")

IF art->Manufactur == 14
   Aadd(aCompet,"TME")
ENDIF
aPriceList := Array(Len(aCompet))

//test to see of it is a 400er series cable type, if yes we compare the prices to the more common cable inlet versions.
aMatch := HB_Regex("PX041[0-1]\/([0-9]{2})[PS]\/([0-9]{4})",art->Matchcode)
IF Len(aMatch) > 0
   nPole := Val(aMatch[2])
   IF nPole <= 3
      cInlet := "5560"
   ELSEIF nPole <= 6
      cInlet := "4550"
   ELSE
      cInlet := "6065"
   ENDIF
   IF cInlet != aMatch[3]
      cMatch := StrTran(art->Matchcode,aMatch[3],cInlet)
//      Alert(cMatch)
      nOrd := art->(dbSetOrder( 1 ))
      IF ! art->(dbSeek( cMatch ))
         art->(dbGoto( nRecno ))
      ENDIF
      art->(dbSetOrder( nOrd ))
   ENDIF
ENDIF

//400er Series Bulk contacts
IF AT("/BULK",art->Matchcode) > 0
   cMatch := StrTran(art->Matchcode,"/BULK",Space(5))
   nPE := 10  //non bulk products are packed in packs of 10
   nOrd := art->(dbSetOrder( 1 ))
   IF ! art->(dbSeek( cMatch ))
      art->(dbGoto( nRecno ))
   ENDIF
   art->(dbSetOrder( nOrd ))
ENDIF

//test to see of it is a 6000er series cable type, if yes we compare the prices to the more common cable inlet versions.
aMatch := HB_Regex("PX[PM]601[0-1]\/([0-9]{2})[PS]\/(ST|CR)\/([0-9]{4})",art->Matchcode)
IF Len(aMatch) > 0
   nPole := Val(aMatch[2])
   IF nPole <= 3
      cInlet := "0507"
   ELSEIF nPole == 8
      cInlet := "0709"
   ELSE
      cInlet := "0910"
   ENDIF
   IF cInlet != aMatch[4]
      cMatch := StrTran(art->Matchcode,aMatch[4],cInlet)
//      Alert(cMatch)
      nOrd := art->(dbSetOrder( 1 ))
      IF ! art->(dbSeek( cMatch ))
         art->(dbGoto( nRecno ))
      ENDIF
      art->(dbSetOrder( nOrd ))
   ENDIF
ENDIF

//test to see of it is a 7000er series cable type, if yes we compare the prices to the more common cable inlet versions.
aMatch := HB_Regex("PX[PM]701[0-1]\/([0-9]{2})[PS]\/(ST|CR)\/([0-9]{4})",art->Matchcode)
IF Len(aMatch) > 0
   nPole := Val(aMatch[2])
   IF nPole == 2
      cInlet := "1113"
   ELSEIF nPole == 3
      cInlet := "1315"
   ELSEIF nPole == 6
      cInlet := "0709"
   ELSE
      cInlet := "0911"
   ENDIF
   IF cInlet != aMatch[4]
      cMatch := StrTran(art->Matchcode,aMatch[4],cInlet)
//      Alert(cMatch)
      nOrd := art->(dbSetOrder( 1 ))
      IF ! art->(dbSeek( cMatch ))
         art->(dbGoto( nRecno ))
      ENDIF
      art->(dbSetOrder( nOrd ))
   ENDIF
ENDIF

FOR nX := 1 TO Len(aCompet)
   ku->(dbSetOrder( 1 ))   
   ku->(dbSeek( Pad(Upper(aCompet[nX]),8)+"L" ))

   IF aCompet[nX] == "FARNELL" .AND. lBuerklin  //we only get prices from Farnell (for speed reasons) if there are no Brklin prices
   ELSEIF (ali->(dbSeek(Pad(Upper(aCompet[nX]),8)+Str(art->Artikelnr,6))) .AND. ! Empty(ali->artlief)) .OR. aCompet[nX] $ "Schukat TME"
      
      IF lDisp
         @ MaxRow()/2-2,MaxCol()/2-15 SAY PadC("["+aCompet[nX]+"]",30,Chr(196)) COLOR c_five
      ENDIF
      
      hPrices := GetPricesCompet(aCompet[nX],lForce,@nError)
      

      IF Inkey() == 27  //cancel update
         RETURN .F.
      ENDIF
      IF ValType(hPrices) != "H" .OR. Len(hPrices) == 0 .OR. HGetValueAt(hPrices,1) == 0
         IF ! aCompet[nX] $ "Schukat TME" .AND. (aCompet[nX] != "Mouser" .OR. ValType(hPrices) != "H" .OR. Len(hPrices) != 2)
            IF lDisp
               IF  ValType(hPrices) == "H" //NIL is used for connection errors
                  SendMail({{"amos.engelking@engelking.de","Amos"}},"Preise von "+aCompet[nX]+" konnten fuer "+Trim(art->Matchcode)+" nicht geladen werden")
               ENDIF
               TxtBox("Preise von "+aCompet[nX]+" konnten nicht geladen werden!","FEHLER")
               Inkey(5,128)
               TxtClear()
               TxtClear()
            ENDIF
            RETURN .F.
         ENDIF
      ELSE
         IF aCompet[nX] == "BšRKLIN"
            lBuerklin := .T.
         ENDIF
         aPriceList[nX] := hPrices
      ENDIF
   ENDIF
NEXT

IF lDbg
   SAVE SCREEN
   CLS
ENDIF

IF lForce //reset the date, as the date could be the current one
   cmpr->(dbSeek( Str(nArtnr,6) ))
   DO WHILE cmpr->Artikelnr == nArtnr
      cmpr->(Rec_Lock(0))
      cmpr->Datum := StoD("")
      cmpr->(dbUnLock())
      cmpr->(dbSkip())
   ENDDO
ENDIF

FOR nX := 1 TO Len(aCompet)
   hPrices := aPriceList[nX]
   IF ValType(hPrices) == "H"
      FOR nY := 1 TO Len(hPrices)
         nMenge := HGetKeyAt(hPrices,nY)*nPE
         nPrice := HGetValueAt(hPrices,nY)/nPE
         lUpd := .F.
         IF ! cmpr->(dbSeek( Str(nArtnr,6)+Str(nMenge,12,4) ))
            IF lDbg
               ? "New",nMenge,nPrice,aCompet[nX]
            ENDIF
            cmpr->(Add_Rec(0))
            cmpr->Artikelnr := nArtnr
            cmpr->Menge := nMenge
            lUpd := .T.
         ELSEIF cmpr->Preis > nPrice .OR. cmpr->Datum < Date()
            IF lDbg
               ? "Update",nMenge,nPrice,aCompet[nX]
            ENDIF
            cmpr->(Rec_Lock(0))
            lUpd := .T.
         ELSEIF lDbg
            ? "No new price",nMenge,nPrice,aCompet[nX]
         ENDIF
         IF lUpd
            cmpr->Datum := Date()
            cmpr->Preis := nPrice
            cmpr->(dbUnLock())
         ENDIF
      NEXT
   ELSEIF lDbg
      ? "No prices",aCompet[nX]
   ENDIF
NEXT

cmpr->(dbSeek( Str(nArtnr,6) ))
DO WHILE cmpr->Artikelnr == nArtnr
   IF cmpr->Datum < Date()
      cmpr->(Rec_Lock(0))
      cmpr->(dbDelete())
      cmpr->(dbUnLock())
   ENDIF
   cmpr->(dbSkip())
ENDDO

IF ! cmpr->(dbSeek( Str(nArtnr,6) )) //no prices available, just remember that we checked
   cmpr->(Add_Rec(0))
   cmpr->Artikelnr := nArtnr
   cmpr->Menge := 99999999

   cmpr->Datum := Date()
   cmpr->(dbUnLock())
ENDIF

IF lDbg
   ? "Done"
   Sinkey(0)
   RESTORE SCREEN
ENDIF

art->(dbGoto(nRecno))
IF lDisp
   TxtClear()
ELSE
//   TxtBox("Preise wurden aktualisiert, bitte Anzeige aktualisieren")
//   Inkey(5,128)
//   TxtClear()
ENDIF

#include 'x:\run\prices\getprices.prg'