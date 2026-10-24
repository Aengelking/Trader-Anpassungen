//ANGEBOT
#include 'inkey.ch'
PROC MASK_ANGEBOT
LOCAL nRec,aButtons := {},oButton
LOCAL nKey
LOCAL cReason
LOCAL lWaitApproval,lApproved,bDisplayApr
LOCAL oAddress,oBrowse
LOCAL cMatchcode,nArtnr,nMinQty,nAngnr,nQty,nAB,aRegex
LOCAL bWhile,bFind
LOCAL nT,nX,nB
LOCAL lBig := MaxCol() > 100
LOCAL hLead,oNoCRM

MEMVAR c_five,c_six

NetUse("engauf","auf",.F.,0)
auf->(dbSetOrder( 6 )) //kundma+matchcode

NetUse("notes","note",.F.,0)
NetUse("nocrm","nocrm")

SetColor( c_five )
dbPush()
art->(dbSetOrder( 2 ))
art->( dbSeek( STR( ang->artikelnr, 6 ) ) )
ku->( dbSetOrder( 1 ) )
ku->( dbSeek( ang->kundma + "K" ) )

@ 04,01 CLEAR TO MaxRow(),IF(lBig,120,63)
@ 04,01 TO MaxRow(),IF(lBig,120,63)
IF lBig
   @ 05,63 TO MaxRow()-1,63
ENDIF
@ 04,02 SAY "[ Angebot "+lTrim(Str(ang->angnr))+" Pos "+Ltrim(Str(ang->itmnr))+" ]"
@ 04,63-14 SAY "[ Status: "+Str(ang->BeStat,1)+" ]"


@ 05,03 SAY "Kunde..........: "+ku->Name1
@ 06,20 SAY ku->Town
@ 07,03 SAY "Artikel........: "+ang->matchcode
@ 08,20 SAY ang->artikel

@ 09,03 SAY "Datum..........: "+DToC(ang->besda)

@ 10,03 SAY "Bearbeiter.....:"
Buy( ang->buyer, .F. )
@ 11,03 SAY "Genehmigung....:"

lWaitApproval := .F.
nRec := NIL
lApproved :=  IsApproved("ANG",ang->Angnr,StoT(ang->LastChange),@lWaitApproval,@nRec)
bDisplayApr := {|| .T. }
IF ! lApproved
   @ 11,20 SAY If(!lWaitApproval,"nicht ","")+"angefordert"
ENDIF
IF ! Empty(nRec)
   apr->(dbGoTo(nRec))
   cReason := ""
   DO WHILE apr->Type == "ANG" .AND. apr->No == ang->Angnr
      IF ! Empty(apr->Reason)
         cReason := Trim(Buy(apr->ApprovedBy,.T.))+" "+Left(TtoC(StoT(apr->ApprovedDa)),17)+Chr(13)+Chr(10)+apr->Reason+Chr(13)+Chr(10)+cReason
      ENDIF
      apr->(dbSkip(-1))
   ENDDO
   apr->(dbGoTo(nRec))

   IF ! Empty(cReason)
      IF lApproved
         @ 11,20 SAY Trim(Buy(apr->ApprovedBy,.T.))+" "+Left(TtoC(StoT(apr->ApprovedDa)),17)
      ENDIF
      bDisplayApr := {||         
         LOCAL cScreen := SaveScreen()
         @ 14,21 CLEAR TO 34,80
         @ 14,21 TO 34,80         
         MemoEdit(cReason,15,22,33,79,.F.)
         RestScreen(,,,,cScreen)
         RETURN NIL
      }
   ELSE
      @ 11,20 SAY t("nicht benötigt")
   ENDIF
ENDIF

@ 12,03 SAY "Kontaktperson..: "+GetContact(ang->person)["name"]

cMatchcode := ang->Matchcode
nArtnr := ang->Artikelnr
nAngnr := ang->angnr
nMinQty := ang->VkQty
nRec := ang->(Recno())
//ang->(dbSkip())
art->( dbSeek( STR( ang->artikelnr, 6 ) ) )

nX := 1
nT := 15

@ nT,03 SAY "Menge"
@ nT,20 SAY "Preis "+Currate(ang->money,"X")
@ nT,30 SAY "PE"
@ nT,34 SAY "Staffel"
@ nT,42 SAY "Lieferzeit"
Do While ang->Matchcode == cMatchcode .AND. ang->Angnr == nAngnr
   ang->(dbSkip(-1))
ENDDO
ang->(dbSkip())
Do While ang->Matchcode == cMatchcode .AND. ang->Angnr == nAngnr  .AND. nX <= MaxRow()-6-17
//
	art->( dbSeek( STR( nArtnr, 6 ) ) )
	@ nT+nX,02 CLEAR TO nT+nX,62
	@ nT+nX,03 SAY Transform(ang->VkQty,Me(art->me))
	@ nT+nX,Col()+1 SAY art->me
	@ nT+nX,21 SAY Str(ang->vkpr*(100- ang->rabatt)/100,8,2)
	@ nT+nX,30 SAY LTrim(Str(ang->PE))
	@ nT+nX,34 SAY LTrim(Str(ang->Staffel))
    @ nT+nX,42 SAY If(ang->dterm == 0,"ab Lager",LTrim(Str(ang->dterm))+" Wochen")
    nMinQty := Min(nMinQty,ang->VkQty)
	ang->(dbSkip())
	art->( dbSeek( STR( ang->artikelnr, 6 ) ) )
	nX++
Enddo


ang->(dbGoto(nRec))
art->( dbSeek( STR( nArtnr, 6 ) ) )
@ 13,03 SAY "Bestellt am....: "
@ 13,20 SAY "x" COLOR "N/R*"
bWhile := {|| ! auf->(Eof()) .AND. auf->Kundma == ang->Kundma .AND. auf->Matchcode == ang->Matchcode }
bFind := {|| auf->Besda >= ang->Besda  }
If auf->(dbSeek( ang->Kundma+ang->Matchcode ))
	nQty := 0
	nAb := 0
	Do While Eval(bWhile) .AND. ! Eval(bFind)
		If Eval(bFind)
			If nAB == auf->AbNr
				nQty += auf->VkQty
			Else
				nAb := auf->Abnr
				nQty := auf->VkQty
			Endif
		Endif
		If nQty >= ang->VKQty //*0.8
			Exit
		Endif
		auf->(dbSkip())
	Enddo
    If Eval(bWhile) .AND. Eval(bFind) /*.AND. nQty >= ang->VKQty*0.8*/
//    	@ 06,40 SAY "Bestellt am "
		@ 13,20 SAY DToC( auf->Besda ) COLOR If(nQty >= ang->VKQty*0.8,"N/G*",SetColor())
      @ 13,29 SAY "("+LTrim(Transform(auf->VkQty,Me(art->me)))+" "+art->me+")"
      oButton := HBPushButton():New(13,Col()+1,"&AB "+LTrim(Str(auf->Abnr,6)))
      oButton:sBlock := {|| Engauft(auf->Abnr) }
      Aadd(aButtons,oButton)

    Endif
Endif

@ nT+nX+1,02 TO nT+nX+1,62
@ nT+nX+1,03 SAY "[ Notizen ]"
oAddress := Adresse():New()
oAddress:LoadMatchcode(ang->Kundma,"K")
oBrowse := TalkBrowse(nT+nX+2,02,MaxRow()-1,62,.F.,"ANG",ang->Angnr)

nts->(dbSetOrder( 1 ))
oBrowse:lBox := .F.
oBrowse:AddKey(Asc("B"),bDisplayApr)
oBrowse:AddKey(Asc("b"),bDisplayApr)
oBrowse:Display()

IF MaxCol() > 100   
   IF nocrm->(dbSeek( Str(nAngnr,6) ))
      @ 05,64 SAY "Lead: "+Ltrim(Str(nocrm->Lead))
      oNoCRM := NoCrmAPI():New()
      IF oNoCRM:Connect()
         hLead := oNoCRM:Execute("leads/"+Ltrim(Str(nocrm->Lead)),"GET")
         IF hLead == NIL
            @ 06,64 SAY "Lead nicht vorhanden"
         ELSE
            @ 06,64 SAY "Status: "+hLead["status"]
            IF hLead["status"] == "standby"
               @ 07,72 SAY "bis "+DtoC(noCRM_DateConv(hLead["reminder_at"]))              
               //+" "+hLead["reminder_note"]               
            ENDIF            
            oButton := HBPushButton():New(05,80,"&Lead ”ffnen")
            oButton:sBlock := {|| WAPI_ShellExecute(,"open",hLead["extended_info"]["permalink"]) }
            Aadd(aButtons,oButton)
      
         ENDIF         
         IF Tr_Getini(28) == 9
            //? ValToPrg(hLead)
         ENDIF
      ENDIF
   ENDIF
ENDIF

AEval(aButtons,{|x| x:ColorSpec := "N/W,N/W,GR+/RB,R+/W", x:Display() })

  nKey := 0
DO WHILE nKey != 27
   IF oBrowse:Stable
      nKey := Inkey(0) 
   
      IF (nKey == K_LBUTTONDOWN .AND. (nB := AScan(aButtons,{|oButton|oButton:HitTest(MRow(),MCol()) != 0})) != 0) .OR.;
         (! Empty(Chr(nKey)) .AND. (nB := AScan(aButtons,{|oButton| aRegex:= HB_Regex("\&([A-Za-zÖÜÄöüä])",oButton:Caption), Len(aRegex) > 0 .AND. Upper(aRegex[2]) == Upper(Chr(nKey))} )) != 0)
         oButton := aButtons[nB]
         oButton:setFocus()
         oButton:select()
         oButton:killFocus()   
      ELSE
         oBrowse:Event({nKey})
         //IF SetKey(nKEY) != NIL
         //Eval(SetKey(nKEY),PROCNAME(2),PROCLINE(2),"","")
      ENDIF
   ELSE
      oBrowse:Display()
   ENDIF
ENDDO

SetColor(c_Six)

#include 'x:\run\nocrm.prg'
