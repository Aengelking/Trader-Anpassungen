#include 'inkey.ch'

LOCAL nVorg := mus->Nummer,nKey,tLAstChange := StoT(""),lWaitApproval,nRec,nOldRec
LOCAL oButton,aButtons := {}
NetUse("lagerne","lne",.F.,0)

SetColor(c_five)

ShadowBox(01, 04, 10, 60 )//, "ÉÍ»º¼ÍÈº ")
//DispBox( 04, 41, 23, 41, 1 )

@ 02,05 SAY art->Matchcode
@ 03,05 SAY art->Artikel
@ 04,05 SAY "Datum..........: "+DToC(mus->Datum)
@ 05,05 SAY "Kontaktperson..: "+GetContact(mus->Person)["name"]
@ 06,05 SAY "Ausgeliefert am: "
If mus->Status >= 3
	lne->(dbSetOrder(1))
	lne->(dbSeek(mus->Nummer))

	@ 06,22 SAY DtoC(lne->Datum)
   oButton := HBPushButton():New(09,29,t("&Entnahme öffnen"))
   oButton:sBlock := {|| Lagerne(mus->Nummer) }
   Aadd(aButtons,oButton)

Else
    @ 06,22	 SAY "-"
Endif
@ 07,05 SAY "Mitarbeiter....: "+Buy(mus->Buyer,.T.)
@ 08,05 SAY "Genehmigung....:"

nOldRec := mus->(Recno())
mus->(dbSetOrder( 1 ))
mus->(dbSeek(nVORG))
DO WHILE mus->Nummer == nVorg .AND. ! mus->(EOF())
   tLastChange := Max(tLastChange,StoT(mus->LastChange))
   mus->(dbSkip())
ENDDO
mus->(dbGoTo(nOldRec))
oAuftrag := Auftrag():New()
oAuftrag:Load(auf->Abnr)
lWaitApproval := .F.
lApproved :=  IsApproved("MUS",nVorg,tLastChange,@lWaitApproval,@nRec)
IF ! lApproved
   @ 08,22 SAY If(!lWaitApproval,"nicht ","")+"angefordert"
ELSE
   apr->(dbGoTo(nRec))
   @ 08,22 SAY Trim(Buy(apr->ApprovedBy,.T.))+" "+Left(TtoC(StoT(apr->ApprovedDa)),17)
   
   oButton := HBPushButton():New(09,05,"&Genehmigung anzeigen")
   oButton:sBlock := {||
      IF nRec != 0
         apr->(dbGoTo(nRec))
         cScreen := SaveScreen()
         @ 14,21 CLEAR TO 24,50
         @ 14,21 TO 24,50
         cReason := ""
         DO WHILE apr->Type == "MUS" .AND. apr->No == nVorg
            cReason := Trim(Buy(apr->ApprovedBy,.T.))+" "+Left(TtoC(StoT(apr->ApprovedDa)),17)+Chr(13)+Chr(10)+apr->Reason+Chr(13)+Chr(10)+cReason
            apr->(dbSkip(-1))
         ENDDO
         MemoEdit(cReason,15,22,23,49,.F.)
         RestScreen(,,,,cScreen)
      ENDIF
   }
   Aadd(aButtons,oButton)

ENDIF


AEval(aButtons,{|x| x:ColorSpec := cButtonCol := "N/W,N/W,GR+/RB,R+/W", x:Display() })

DO WHILE .T.
   nKey := inkey(0,2 + 128)
   IF (nKey == K_LBUTTONDOWN .AND. (nB := AScan(aButtons,{|oButton|oButton:HitTest(MRow(),MCol()) != 0})) != 0) .OR.;
      (! Empty(Chr(nKey)) .AND. (nB := AScan(aButtons,{|oButton| aRegex:= HB_Regex("\&([A-Za-zÖÜÄöüä])",oButton:Caption), Len(aRegex) > 0 .AND. Upper(aRegex[2]) == Upper(Chr(nKey))} )) != 0)
      oButton := aButtons[nB]
      oButton:setFocus()
      oButton:select()
      oButton:killFocus()
   ELSEIF SetKey(nKEY) != NIL
      Eval(SetKey(nKEY),PROCNAME(2),PROCLINE(2),"","")
   ELSE
      EXIT
   ENDIF
ENDDO