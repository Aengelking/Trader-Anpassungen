#ifndef __XHARBOUR__
PROC MASK_TRD_03_BESTELLUNG
Local oBrowse
LOCAL oBes := BestellungPos():New(.F.)
LOCAL cMe,lWaitApproval,lApproved
LOCAL nRec,cReason
LOCAL cScreen,bDisplayApr,oBrowse2,oBrowse3
LOCAL bShowAbg,aMenu,lWait,nChoice
LOCAL aEnv,nKey,lBr,lBr2,nRest
LOCAL cBaseText
LOCAL nX
LOCAL cText
LOCAL nDash
LOCAL nLastRow
LOCAL nMindest,nLevel
LOCAL nTotVerp
LOCAL nTot
LOCAL nPrice,nNK

#endif
MEMVAR c_five

SetColor( c_five )
art->( dbSeek( STR( bes->artikelnr, 6 ) ) )
cMe := Me(art->me)
NetUse("werkauf","wer",.F.,0)
NetUse("lagerne","lne",.F.,0)
NetUse("artlief","ali",.F.,0)
NetUse("lspos","lsp",.F.,0)
NetUse("engabg","abg")
lsp->(dbSetOrder( 3 ))
NetUse("rechpos","rpos",.F.,0)
rpos->(dbSetOrder( 2 ))
NetUse("besdel","bdel")
NetUse("besref","besref")
NetUse("projcost","pjcst")

NetUse("ls","ls",.F.,0)
bes->(dbPush())
@ 03,01 CLEAR TO 34,78
@ 03,01 TO 34,78

@ 34,02 SAY "[ >B< Genehmigung | >A< Audit Trail | >N< Notizen ]"

DevPos( 03, 01 )
DevOut( "ÚÄ[        ]ÄÄ[                         ]ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ[Status:   ]ÄÄ¿" )
@ 03, 45 SAY "["+If(!bes->Printed,"nicht ","")+"gedruckt]"

@ 05, 03 SAY "Best-Nr..: [      /   ]    Bestellt.:                  Auftragsbest„tigung"

DevPos( 06, 01 )
DevOut( "³ Auftr-Nr.: [      /   ]    Geliefert:                    [ ] [          ]  ³" )
DevPos( 07, 01 )
DevOut( "³"+space(76)+"³" )
DevPos( 08, 01 )
DevOut( "³ Bestelldatum...: [        ]                  Einkaufspreis..:" )
DevPos( 09, 01 )
DevOut( "³ Liefertermin...: [    ]" )


@ 10,03 SAY "Wunschtermin...: [    ]"

@ 10,21 SAY StrZero(bes->wterm)
@ 10,27 SAY "("+DtoC(CalWD(bes->Wterm)+5)+")"


@ 11,48 SAY "Rabatt.........:      [     ]"

//@ 11,03 SAY "Soll-Lieferung.: [        ]"
//@ 11,21 SAY bes->ldatum

DevPos( 12, 01 )
DevOut( "³ Letzte Žnderung: [        ]" )
DevPos( 13, 01 )
DevOut( "³"+space(76)+"³" )
DevPos( 14, 01 )
DevOut( "³ Zahlungsart....: [ ]" )
DevPos( 15, 01 )
DevOut( "³ Kontaktperson..: [                         ]")

DevPos( 16, 01 )
DevOut( "³ Besteller......: [  ]"+space(36)+"[               ] ³" )
/*DevPos( 17, 01 )
DevOut( "³"+space(76)+"³" )
DevPos( 18, 01 )
DevOut( "³"+space(76)+"³" )
DevPos( 19, 01 )
DevOut( "³"+space(76)+"³" )
DevPos( 20, 01 )
DevOut( "³"+space(76)+"³" )
DevPos( 21, 01 )
DevOut( "³"+space(76)+"³" )
DevPos( 22, 01 )
DevOut( "³"+space(76)+"³" )
DevPos( 23, 01 )
DevOut( "ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ" )*/
DevPos( 03, 04 )
DevOut( bes->liefma )
DevPos( 03, 16 )
DevOut( bes->matchcode )
DevPos( 03, 73 )
DevOut( bes->bestat )


@ 04, 03 SAY art->artikel
ali->(dbSetORder(2))
If ali->(dbSeek( bes->liefma+art->Matchcode ))
	@ 04,40 SAY ali->ArtLief
Endif

DevPos( 05, 15 )
DevOut( bes->besnr )
DevPos( 05, 22 )
DevOut( bes->posnr )

IF bes->Rahmen
   @ 05, 30 SAY "Rahmenme.: ["+Transform(bes->ContrQty,Me(art->Me))+"]"
ELSE
   @ 05, 30 SAY "Bestellt.: ["+Transform(bes->beqty,Me(art->Me))+"]"
ENDIF

DevPos( 06, 15 )
DevOut( bes->aufabnr )
DevPos( 06, 22 )
DevOut( bes->aufitmnr )
IF bes->Rahmen
   @ 06, 30 SAY "Abgerufen: ["+Transform(bes->ContrQty-bes->BeQty,Me(art->Me))+"]"
ELSE
   @ 06, 30 SAY "Geliefert: ["+Transform(bes->GelQty,Me(art->Me))+"]"
ENDIF

DevPos( 06, 61 )
DevOut( bes->confirmed )
DevPos( 06, 65 )
DevOut( bes->abnr )
DevPos( 08, 21 )
DevOut( bes->besda )

nPrice := bes->ekpr/bes->Pe
nNK := Len(Ltrim(Str(bes->Pe)))+1
@ 08,64 SAY Str(nPrice,12-nNK,nNK)+" "+Currate(bes->money,"X") 
IF bes->Money != "E"
   @ 09,64 SAY Str(nPrice*bes->rate,12-nNK,nNK)+" EUR"
ENDIF
besref->(dbSetOrder(2))
art->(dbSetOrder( 2 ))
IF ! art->( dbSeek( STR( bes->artikelnr, 6 ) ) )
   @ 10,48 SAY "Artikel nicht gefunden"
ELSE
@ 10,48 SAY art->Matchcode
ENDIF
IF art->Lagerart// .AND. besref->(dbSeek(Str(bes->Besnr,6)+Str(bes->Posnr,3)))
   @ 10,48 SAY "Gesamt EK/"+Trim(art->Me)+".:"+Str(BesGetEkPrice(),12-nNK,nNK)+" EUR"
ENDIF


IF bdel->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
   @ 09,21 SAY "mehrere Lieferungen]"
ELSE   
   @ 09, 21 SAY StrZero(bes->lterm)
   @ 09,27 SAY "("+DtoC(CalWD(bes->lterm)+5)+")"
ENDIF

DevPos( 11, 71 )
DevOut( bes->rabatt )

DevPos( 12, 21 )
DevOut( bes->lastrem )

DevPos( 14, 21 )
DevOut( bes->pay )

IF ! art->Lagerart
   @ 13,48 SAY "Kst.Tr„ger:"
   besref->(dbSetOrder(1))
   IF besref->(dbSeek(Str(bes->Besnr,6)+Str(bes->Posnr,3)))
      @ 13, 61 SAY "Best. "+Str(besref->RefBes,6)+"/"+Ltrim(Str(besref->RefPos,3))
   ELSEIF pjcst->(dbSeek( "BE"+Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
      @ 13, 61 SAY "Projekt "+pjcst->Project
   ELSE
      @ 13, 61 SAY "keiner"
   ENDIF
ENDIF


@ 15,48 SAY "Zugang ohne RG.: "+LTrim(Transform(bes->zoqty,cMe))

DevPos( 16, 21 )
DevOut( bes->buyer )
DevPos( 16, 61 )
DevOut( bes->grund )
SetColor( c_five )
If bes->person != 0
	ku->( dbSetOrder( 1 ) )
	ku->( dbSeek( bes->liefma + "L" ) )
	@ 15,21 SAY Pad(GetContact(bes->person)["name"],25)
Endif
//if(bes->person <> 0,EVAL({|| , QQOUT(ALLTRIM( MACRO("ku->person"+if( bes->person=1,"",LTRIM( STR( bes->person,1 ) ) ) ) )) }),"")
DevPos( 16, 24 )
Buy( bes->buyer, .F. )


@ 17,03 SAY "Genehmigung....:"

lWaitApproval := .F.
nRec := NIL
lApproved :=  IsApproved("BES",bes->Besnr,SToT(bes->LastChange),@lWaitApproval,@nRec)
bDisplayApr := {|| .T. }
IF ! lApproved
   @ 17,20 SAY If(!lWaitApproval,"nicht ","")+"angefordert"
ENDIF
IF ! Empty(nRec)
   apr->(dbGoTo(nRec))
   cReason := ""
   DO WHILE apr->Type == "BES" .AND. apr->No == bes->Besnr
      cReason := Trim(Buy(apr->ApprovedBy,.T.))+" "+Left(TtoC(StoT(apr->ApprovedDa)),17)+Chr(13)+Chr(10)+apr->Reason+Chr(13)+Chr(10)+cReason
      apr->(dbSkip(-1))
   ENDDO
   apr->(dbGoTo(nRec))

   //IF bes->Buyer != apr->ApprovedBy .AND. Empty(apr->Reason)
   IF ! Empty(cReason)
      IF lApproved
         @ 17,20 SAY Trim(Buy(apr->ApprovedBy,.T.))+" "+Left(TtoC(StoT(apr->ApprovedDa)),17)
      ENDIF      
      bDisplayApr := {||
         apr->(dbGoTo(nRec))
         cScreen := SaveScreen()
         @ 14,21 CLEAR TO 34,80
         @ 14,21 TO 34,80         
         MemoEdit(cReason,15,22,33,79,.F.)
         RestScreen(,,,,cScreen)
         RETURN .T.
      }
   ELSE
      @ 17,20 SAY t("nicht benötigt")
   ENDIF
ENDIF




oBrowse := oBrowse2 := NIL
IF bes->Rahmen
   bes->(dbSetOrder( 7 ))
   IF bes->(dbSeek( Str(oBes:Besnr,6)+Str(oBes:Posnr,3) ))
   	oBrowse := bes->(TBrowseTr():New(20,02,30,38))
   	oBrowse:lBox := .F.
   	oBrowse:WhileBlock := {|| bes->ContrNo == oBes:Besnr .AND. bes->ContrPos == oBes:Posnr }
   	oBrowse:NewColumn(Pad("Bes.nr.",6)+" "+PadL("Menge",12)+" "+PadL("Geliefert",12)+Space(2),{|| Str( bes->Besnr, 6)+" "+PadL(Transform(bes->BeQty,cMe),12)+" "+PadL(Transform(bes->GelQty,cMe),12)+Space(2)})
   	oBrowse:AddKey(27,{|| .F. })
      oBrowse:AddKey(Asc("B"),bDisplayApr)
      oBrowse:AddKey(Asc("b"),bDisplayApr)
   
   	oBrowse:Display()
   	oBrowse:deHilite()
   ENDIF
   @ 19,02 SAY t("Abrufe")
   oBes:gotoRec()
ELSEIF bes->BeQty < 0 //Belastungsanzeige
   NetUse("lagerne","lne")
   lne->(dbSetORder(7))
   IF bes->GelQty != 0 .AND. lne->(dbSeek( "BE"+Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
   	oBrowse := lne->(TBrowseTr():New(20,02,30,38))
   	oBrowse:lBox := .F.
   	oBrowse:WhileBlock := {|| lne->RefTyp == "BE" .AND. lne->RefBeleg == bes->Besnr .AND. lne->Refpos == bes->Posnr }
   	oBrowse:NewColumn(Pad("Datum",8)+" "+Pad("Beleg",6)+" "+PadL("Menge",12)+Space(9),{|| DToC(lne->Datum)+" "+Str( lne->Nummer, 6)+" "+PadL(Transform(lne->Menge,cMe),12)+Space(9)})
   	oBrowse:AddKey(27,{|| .F. })
      oBrowse:AddKey(Asc("B"),bDisplayApr)
      oBrowse:AddKey(Asc("b"),bDisplayApr)

   	oBrowse:Display()
   	oBrowse:deHilite()
      @ 19,02 SAY t("Rücklieferungen")
   ENDIF
ELSE
   bShowAbg := {||
      oBrowse := abg->(TBrowseTr():New(20,02,30,38))
   	oBrowse:lBox := .F.
      oBrowse:WhileBlock := {|| abg->Matchcode == bes->Matchcode }
      
      oBrowse:cFor := 'Besnr == '+LTrim(Str(bes->Besnr))+' .AND. Bespos == '+LTrim(Str(bes->Posnr))+' .AND. Trim(BuArt) == "WE"'
      oBrowse:ForBlock   := {|| abg->(&(oBrowse:cFor)) }
      //oBrowse:cFor       := "besnr == "+LTrim(Str(bes->Besnr))+" .AND. Trim(buart) == 'WE'"
      oBrowse:NewColumn(Pad("Datum",8)+" "+Pad("Beleg",15)+" "+PadL("Menge",12),{||
         IF abg->Matchcode != bes->Matchcode
            RETURN Pad("Keine Lieferung vorhanden",46)
         ENDIF
         RETURN DToC(abg->Datum)+" "+abg->Beleg+" "+PadL(Transform(abg->Menge,cMe),12)
      })
   	oBrowse:AddKey(27,{|| .F. })
      oBrowse:AddKey(Asc("B"),bDisplayApr)
      oBrowse:AddKey(Asc("b"),bDisplayApr)

      abg->(dbSetOrder( 3 ))
      abg->(dbSetFilter(oBrowse:ForBlock,oBrowse:cFor))
      abg->(dbSeek( bes->Matchcode ))
      abg->(dbClearFilter())

   	oBrowse:Display()
      //oBrowse:deHilite()
      RETURN .T.
   }
   IF lsp->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
   	oBrowse := lsp->(TBrowseTr():New(20,02,30,38))
   	oBrowse:lBox := .F.
   	oBrowse:WhileBlock := {|| lsp->Besnr == bes->Besnr .AND. lsp->Bespos == bes->Posnr }
   	oBrowse:NewColumn(Pad("Datum",8)+" "+Pad("Beleg",15)+" "+PadL("Menge",12),{|| ls->(dbSeek( lsp->Liefma+lsp->Beleg )),DToC(ls->Datum)+" "+lsp->Beleg+" "+PadL(Transform(lsp->Menge,cMe),12)})
   	oBrowse:AddKey(27,{|| .F. })
      oBrowse:AddKey(Asc("B"),bDisplayApr)
      oBrowse:AddKey(Asc("b"),bDisplayApr)
      oBrowse:Display()
      oBrowse:deHilite()
   ENDIF
   @ 19,02 SAY "Lieferungen"
   IF bdel->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
      //oBrowse:nBottom := 25
      @ 31,01 CLEAR TO 41,78
      @ 03,01 TO 41,78

      @ 31,02 SAY "Geplante Lieferungen"
      oBrowse3 := bdel->(TBrowseTr():New(32,02,39,77))
      oBrowse3:lBox := .F.
      oBrowse3:WhileBlock := {|| bdel->Besnr == bes->Besnr .AND. bdel->Posnr == bes->Posnr }
      oBrowse3:NewColumn(Pad("KW",8)+" "+PadL("Menge",12)+" Versandt "+Pad("Trackingnr",50),{|| Pad(NiceWeek(bdel->Lterm)+" "+PadL(Transform(bdel->Qty,cMe),12)+" "+DtoC(bdel->Shipped)+" "+bdel->Tracking,36+10+50)})
      oBrowse3:AddKey(27,{|| .F. })
      oBrowse3:Display()
      oBrowse3:deHilite()

      nRest := bes->BeQty
      bdel->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
      DO WHILE Eval(oBrowse3:WhileBlock) .AND. ! bdel->(EOF())
         nRest -= bdel->Qty
         bdel->(dbSkip())
      ENDDO
      IF nRest > 0
         @ 40,02 SAY NiceWeek(bes->LTerm)+" "+PadL(Transform(nRest,cMe),12)
      ENDIF
      bdel->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
   ELSEIF ! Empty(bes->Shipped) .OR. ! Empty(bes->Tracking)
      @ 31,02 SAY "Versandinformationen"
      @ 32,02 SAY "Trackingnr: "+bes->Tracking
      @ 33,02 SAY "Versanddatum: "+DtoC(bes->Shipped)
   ENDIF

ENDIF



If /*(bes->GelQty != 0 .OR. ! art->Lagerart) .AND.*/ rpos->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
	oBrowse2 := rpos->(TBrowseTr():New(20,39,30,77))
	oBrowse2:lBox := .F.
	oBrowse2:WhileBlock := {|| rpos->Besnr == bes->Besnr .AND. rpos->Posnr == bes->Posnr }
	oBrowse2:NewColumn(Pad("Datum",8)+" "+Pad("Beleg",15)+" "+PadL("Menge",12),{|| DToC(rpos->Date)+" "+rpos->Beleg+" "+PadL(Transform(rpos->Menge,cMe),12)})
	oBrowse2:AddKey(27,{|| .F. })
   oBrowse2:AddKey(Asc("B"),bDisplayApr)
   oBrowse2:AddKey(Asc("b"),bDisplayApr)

   oBrowse2:Display()

	@ 19,40 SAY IF(bes->BeQty*bes->EkPr<0,"Gutschriften","Rechnungen")
Endif


wer->(dbSetOrder(6)) //Besnr
if wer->(dbSeek( Str(bes->besnr,6)+Str(bes->Posnr,3) ))
   @ 31,01 CLEAR TO 36,78
   @ 31,01 TO 36,78
   @ 31,01 SAY Chr(195)
   @ 31,78 SAY Chr(180)

	@ 32,03 SAY "Werksattsauftr.: "+LTrim(Str(wer->aufno))
	art->(dbSetOrder( 2 ))
   art->(dbSeek( Str(wer->Artno,6) ))
	@ 33,03 SAY "Fertigteil: "+LTrim(Str(wer->Artno))
	@ 34,03 SAY art->Matchcode
	@ 35,03 SAY Pad(art->Artikel,30)
	aMenu := {"Werkstattsauftrag bearbeiten"}

	lne->(dbSetOrder(1))
	If wer->Status < 3 .OR. ! lne->(dbSeek(wer->LagNum))
		@ 33,21 SAY "Ware nicht versandt"
	Else
		If lne->Packed
//			@ 18,52 SAY "Ware versandt"			
			//@ 33,21 SAY "Sendung verfolgen" COLOR c_two
			Aadd(aMenu,"Sendung verfolgen")
         /*Do While SInkey(0) != 27
				If LastKey() == 13
					Einfug(0,wer->Lagnum,.F.,.F.)
				Endif
			Enddo*/			
		Else
			@ 33,21 SAY "Ware im Versand"
		Endif
	Endif
	nChoice := 1
	DO WHILE nChoice != 0
     nChoice := AChoice(32,48,33,77,aMenu)
     IF nChoice == 1
        aEnv := SaveEnv()
        __KeyBoard(Str(wer->Aufno)+Chr(13))
        WerkAuf()
        RestEnv(aEnv,.T.)
     ELSEIF nChoice == 2
          Einfug(0,wer->Lagnum,.F.,.F.)
     ENDIF
   ENDDO
Endif

lBr := ValType(oBrowse) == "O"
lBr2 := ValType(oBrowse2) == "O"
nKey := 0
//If  lBr .OR. lBr2
	lWait := .F.
	@ 18,52 SAY Space(25)
	IF lBr
	   IF bes->Rahmen
	     bes->(dbSetOrder( 7 ))
        bes->(dbSeek( Str(oBes:Besnr,6)+Str(oBes:Posnr,3) ))
      ENDIF
      oBrowse:Display()
   ENDIF
   IF lBr2
      oBrowse2:Display()
   ENDIF
   IF ValType(oBrowse3) == "O"
      oBrowse3:Display()
   ENDIF
	while (!lBr .OR. ! oBrowse:lExit)  .AND. (!lBr2 .OR. ! oBrowse2:lExit)
		if (!lBr .OR. oBrowse:stable) .AND. (! lBr2 .OR. oBrowse2:stable)
			Do While nKey == 0 .AND. (!lBr .OR. ! oBrowse:lExit)  .AND. (!lBr2 .OR. ! oBrowse2:lExit)
				nKey := Inkey(0) //A_INKEY(0.1)
			Enddo
         IF Upper(Chr(nKey)) == "B"
            Eval(bDisplayApr)
            nKey := 0
         ELSEIF Upper(Chr(nKey)) == "L" .AND. bShowAbg != NIL
            //Alert("Changing browse")
            Eval(bShowAbg)
            nKey := 0
         ELSEIF Upper(Chr(nKey)) == "A"
            ShowAuditOverlay("BES",Str(bes->Besnr,12),bes->Posnr)
            nKey := 0
         ELSEIF Upper(Chr(nKey)) == "N"
            ShowNotesOverlay("BES",bes->Besnr)
            nKey := 0
         ELSEIF Upper(Chr(nKey)) == "E" .AND. Tr_Getini(28) == 9 .AND. bes->Bestat <= 5 .AND. Tr_MsgBox("Position "+IF(bes->Bestat >= 3,"”ffnen","schlieáen")+"?",,{"Nein","Ja"}) == 2
            bes->(Rec_Lock(0))
            bes->Bestat := IIF(bes->Bestat >= 3,1,3)
            bes->(dbUnlock())            
            nKey := 0
         ELSEIF nKey == 27
            EXIT
         ELSE

			IF lBr
			   oBrowse:Event({nKey})
			ENDIF
			IF lBr2
            oBrowse2:Event({nKey})
			ENDIF
			nKey := 0
			ENDIF
		else
      	IF lBr
            oBrowse:Display()
         ENDIF
         IF lBr2
            oBrowse2:Display()
         ENDIF
		endif
	enddo
//	oBrowse:EventLoop()
//Endif

If lWait
	DO WHILE .T. 
      nKey := Sinkey(0)
      IF Upper(Chr(nKey)) == "B"
         Eval(bDisplayApr)
      ELSEIF Upper(Chr(nKey)) == "L"
         //Alert("Changing browse")
         Eval(bShowAbg)         
      ELSEIF Upper(Chr(nKey)) == "N"
         ShowNotesOverlay("BES",bes->Besnr)
      ELSE
         EXIT
      ENDIF
   ENDDO
Endif

STATIC FUNCTION ShowAuditOverlay(cAlias,cId,nPos)
   LOCAL cScreen := SaveScreen()
   LOCAL nTop := 03
   LOCAL nLeft := 02
   LOCAL nBottom := MaxRow()-2
   LOCAL nRight := MaxCol()-2
   LOCAL oBrowse
   LOCAL nKey := 0

   @ nTop,nLeft CLEAR TO nBottom,nRight
   @ nTop,nLeft TO nBottom,nRight
   @ nTop,nLeft+2 SAY "Audit Trail"

   oBrowse := BuildAuditBrowse(nTop+1,nLeft+1,nBottom-1,nRight-1,cAlias,cId,nPos)
   oBrowse:lBox := .F.
   oBrowse:Display()

   DO WHILE nKey != 27 .AND. Upper(Chr(nKey)) != "A"
      IF oBrowse:Stable
         nKey := Inkey(0)
         oBrowse:Event({nKey})
      ELSE
         oBrowse:Display()
      ENDIF
   ENDDO

   RestScreen(,,,,cScreen)
RETURN NIL

STATIC FUNCTION ShowNotesOverlay(cType,nNr)
   LOCAL cScreen := SaveScreen()
   LOCAL nTop := 03
   LOCAL nLeft := 02
   LOCAL nBottom := MaxRow()-2
   LOCAL nRight := MaxCol()-2
   LOCAL oBrowse
   LOCAL nKey := 0

   @ nTop,nLeft CLEAR TO nBottom,nRight
   @ nTop,nLeft TO nBottom,nRight
   @ nTop,nLeft+2 SAY "Notizen"

   oBrowse := TalkBrowse(nTop+1,nLeft+1,nBottom-1,nRight-1,.T.,cType,nNr)
   oBrowse:lBox := .F.
   oBrowse:Display()

   DO WHILE nKey != 27 .AND. Upper(Chr(nKey)) != "N"
      IF oBrowse:Stable
         nKey := Inkey(0)
         oBrowse:Event({nKey})
      ELSE
         oBrowse:Display()
      ENDIF
   ENDDO

   RestScreen(,,,,cScreen)
RETURN NIL

STATIC FUNCTION BuildAuditBrowse(nTop,nLeft,nBottom,nRight,cAlias,cId,nPos)
   LOCAL oBrowse
   LOCAL cWhen
   LOCAL cUser
   LOCAL hData
   LOCAL aLogEntries := {},aFields
   LOCAL nX,nY
   LOCAL aRaw := {}
   LOCAL hSnapshot := {"DATA"=>{=>},"MLDATA"=>{=>},"BESTELLPOS"=>{=>}}

   NetUse("dblog","dblog")
   dblog->(dbSetOrder(1))
   dblog->(dbSeek(Pad(cAlias,5)+cId,.T.))

   DO WHILE Trim(dblog->Alias) == Trim(cAlias) .AND. dblog->ID == cId
      hData := NIL
      BEGIN SEQUENCE
         hData := HB_DeSerialize(dblog->Data)
      RECOVER
      END SEQUENCE
      Aadd(aRaw,{dblog->DateTime,dblog->User,hData})
      dblog->(dbSkip())
   ENDDO

   FOR nX := Len(aRaw) TO 1 STEP -1
      cWhen := Left(TtoC(StoT(aRaw[nX,1])),17)
      cUser := Left(Buy(aRaw[nX,2],.T.),10)
      aFields := FormatAuditFields(aRaw[nX,3],nPos,hSnapshot)
      IF Len(aFields) == 0
         Aadd(aFields,"-")
      ENDIF
      FOR nY := 1 TO Len(aFields)
         IF nY == 1
            Aadd(aLogEntries,cWhen+" "+cUser+" "+aFields[nY])
         ELSE
            Aadd(aLogEntries,Space(29)+aFields[nY])
         ENDIF
      NEXT
   NEXT

   oBrowse := dblog->(TABrowse():New(nTop,nLeft,nBottom,nRight))
   oBrowse:lBox := .F.
   oBrowse:OneColumn := .T.
   oBrowse:MultipleRows := .T.
   oBrowse:NoRefreshBug := .T.
   oBrowse:aData := aLogEntries
   oBrowse:ColorSpec := c_five
   oBrowse:WhileBlock := {|| Trim(dblog->Alias) == Trim(cAlias) .AND. dblog->ID == cId }

   oBrowse:NewColumn(Pad("Datum/Zeit       Benutzer   Žnderung",nRight-nLeft+1),{||
      IF oBrowse:CurrentDataRow() == NIL
         RETURN Pad("Keine Eintr„ge",nRight-nLeft+1)
      ENDIF

      RETURN Pad(oBrowse:CurrentDataRow(),oBrowse:nRight-oBrowse:nLeft+1)
   })

RETURN oBrowse

STATIC FUNCTION FormatAuditFields(hData,nPos,hSnapshot)
   LOCAL aFields := {}
   LOCAL cField,nX,nY
   LOCAL cCur,cPrev
   LOCAL cPosKey := LTrim(Str(nPos))
   LOCAL hField

   IF ValType(hData) != "H"
      RETURN {}
   ENDIF

   IF HB_HHasKey(hData,"DATA")
      FOR nX := 1 TO Len(hData["DATA"])
         cField := HGetKeyAt(hData["DATA"],nX)
         IF cField $ {"LASTCHANGE","CHANGED"}
            LOOP
         ENDIF
         cPrev := hData["DATA"][cField]
         IF HB_HHasKey(hSnapshot["DATA"],cField)
            cCur := hSnapshot["DATA"][cField]
         ELSE
            cCur := __BesFieldValue(cField)
         ENDIF
         IF HB_ValToStr(cCur) != HB_ValToStr(cPrev)
            Aadd(aFields,cField+": "+AllTrim(HB_ValToStr(cPrev))+" -> "+AllTrim(HB_ValToStr(cCur)))
         ENDIF
         hSnapshot["DATA"][cField] := cPrev
      NEXT
   ENDIF

   IF HB_HHasKey(hData,"MLDATA") .AND. Len(hData["MLDATA"]) > 0
      FOR nX := 1 TO Len(hData["MLDATA"])
         cField := HGetKeyAt(hData["MLDATA"],nX)
         hField := HGetValueAt(hData["MLDATA"],nX)
         IF ! HB_HHasKey(hSnapshot["MLDATA"],cField)
            hSnapshot["MLDATA"][cField] := {=>}
         ENDIF
         FOR nY := 1 TO Len(hField)
            cPrev := HGetValueAt(hField,nY)
            IF HB_HHasKey(hSnapshot["MLDATA"][cField],HGetKeyAt(hField,nY))
               cCur := hSnapshot["MLDATA"][cField][HGetKeyAt(hField,nY)]
            ELSE
               cCur := ""
            ENDIF
            IF HB_ValToStr(cCur) != HB_ValToStr(cPrev)
               Aadd(aFields,cField+"["+HGetKeyAt(hField,nY)+"]: "+AllTrim(HB_ValToStr(cPrev))+" -> "+AllTrim(HB_ValToStr(cCur)))
            ENDIF
            hSnapshot["MLDATA"][cField][HGetKeyAt(hField,nY)] := cPrev
         NEXT
      NEXT
   ENDIF

   IF HB_HHasKey(hData,"BESTELLPOS") .AND. HHAsKey(hData["BESTELLPOS"],cPosKey)
      IF ! HB_HHasKey(hSnapshot["BESTELLPOS"],cPosKey)
         hSnapshot["BESTELLPOS"][cPosKey] := {=>}
      ENDIF
      FOR nX := 1 TO Len(hData["BESTELLPOS"][cPosKey]["DATA"])
         cField := HGetKeyAt(hData["BESTELLPOS"][cPosKey]["DATA"],nX)
         cPrev := HGetValueAt(hData["BESTELLPOS"][cPosKey]["DATA"],nX)
         IF HB_HHasKey(hSnapshot["BESTELLPOS"][cPosKey],cField)
            cCur := hSnapshot["BESTELLPOS"][cPosKey][cField]
         ELSE
            cCur := __BesFieldValue(cField)
         ENDIF
         IF HB_ValToStr(cCur) != HB_ValToStr(cPrev)
            Aadd(aFields,cField+": "+AllTrim(HB_ValToStr(cPrev))+" -> "+AllTrim(HB_ValToStr(cCur)))
         ENDIF
         hSnapshot["BESTELLPOS"][cPosKey][cField] := cPrev
      NEXT
   ENDIF

RETURN aFields

STATIC FUNCTION __BesFieldValue(cField)
   LOCAL nPos := bes->(FieldPos(cField))
   IF nPos == 0
      RETURN NIL
   ENDIF
RETURN bes->(FieldGet(nPos))