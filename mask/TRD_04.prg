#include 'y:\hb32\include\inkey.ch'

PROC Mask_Auftrag
LOCAL lRahmen := Right(Str(auf->DTerm,4),2) == "99"
LOCAL cMe,nOrder
LOCAL nAbnr := auf->Abnr,nItmnr := auf->Itmnr
LOCAL oBrowse,nAprRec,nRec,dFirst,dLast
LOCAL nFrQty,lCallOff,oAufPos,oAuftrag
LOCAL lWaitApproval,cReason,cScreen
LOCAL lApproved,bDisplayApr
LOCAL hStatus,bState,nKey
LOCAL oArt,nX,bEditEnd
LOCAL lBig := MaxCol() >= 150
LOCAL aBrowse := {},nActiveBrowse := 1,bChangeBrowse,cFor
LOCAL bShowBrowseTitle
LOCAL nBrowseTop := 16
LOCAL nBrowseLeft := 21
LOCAL nBrowseBottom := 24
LOCAL nBrowseRight
LOCAL oAuditBrowse
LOCAL lDummy,getlist
LOCAL oTabs
LOCAL aReasonLines,oApprovalBrowse,nLineIdx
LOCAL oAddress

MEMVAR c_five,trVer

NetUse("englsre","re",.F.,0)
re->(dbSetOrder(10))

NetUse("engkund","ku",.F.,0)
ku->(dbSeek(auf->Kundma+"K"))

NetUse("me","me",.F.,0)

NetUse("ups","ups",.F.,0)
ups->(dbSetOrder(3))

NetUse("fremdab","frab")
NetUse("auftrag","ab")

SetColor( c_five )

oArt := Artikel():New()
oArt:Load(auf->Artikelnr)

oAddress := Adresse():New()
oAddress:LoadMatchcode(auf->Kundma,"K")

art->( dbSeek( STR( auf->artikelnr, 6 ) ) )
cMe := me->(Me(art->me))

nOrder := wer->(dbSetOrder(3))
wer->( dbSeek( Str( auf->Abnr,6 )+ Str(auf->Itmnr,3) ))
wer->(dbSetOrder(nOrder))



@ 03,01 CLEAR TO 32,IF(lBig,MaxCol(),81)
@ 03,01 TO 32,IF(lBig,MaxCol(),81)
oTabs := GetTabs():New(04,81,32,MaxCol())

@ 03,03 SAY "["+auf->kundma+"]"
@ 03,15 SAY "["+auf->Matchcode+"]"
@ 03,64 SAY "[Status:   ]"

DevPos( 05, 01 )
DevOut( "³ AB-Nr....: [      /   ]                              Kundenauftragsnummer" )
DevPos( 06, 01 )
DevOut( "³ Best.-Nr.: [      /   ]                              [                       ]" )

IF lRahmen
   IF frab->(dbSeek( Str(auf->AbNr,6)+Str(auf->Itmnr,3) ))
      nFrQty := frab->Qty      
   ELSE
      nFRQty := 0
   ENDIF
ENDIF

@ 05,29 SAY "Bestellt.: ["+Transform(If(lRahmen,auf->ContrQty+nFrQty,auf->VkQty),cMe)+"]"
@ 06,29 SAY IF(lRahmen,"Abgerufen","Geliefert")+": ["+Transform(IF(lRahmen,auf->ContrQty-auf->VkQty+nFrQty,auf->Gelqty),cMe)+"]"


@ 08,03 SAY "Auftragsdatum...: "+DToC(auf->besda)+If(!ku->JustInTime," (KW "+CalWeek(auf->Besda)+")","")
lCallOff := Right(Str(auf->dterm,4),2) == "99"
If ! lCallOff
	@ 09,03 SAY "Liefertermin....: "+If(ku->JustInTime,DToC(auf->BDatum),NiceWeek( auf->dterm ))
   @ 10,03 SAY "Ursprngl. Term.: "+IF(ku->JustInTime,DToC(auf->UBDatum),NiceWeek(auf->UBTerm)) //+IF(!ku->JustInTime,"("+DToC(auf->UBDatum)+")","")
	@ 11,03 SAY "Wunschtermin....: "+If(ku->JustInTime,DToC(auf->WDatum),NiceWeek(auf->wterm,4))+If(!ku->JustInTime,"("+DTOC(auf->WDatum)+")","")
	If ku->JustInTime
		@ 12,03 SAY "Versandtag......: "+DToC(GetJITLiefertag(auf->BDatum,ku->JIT_LZ))
	Endif
Else
	@ 09,03 SAY "Rahmenlaufzeit..: "+DtoC(auf->SDatum)+" - "+DToC(CalWD(auf->WTerm)+4)
   IF CalWD(auf->WTerm)+4 > auf->WDatum 
      @ 10,03 SAY "Geplantes Ende..: "+"("+NiceWeek(CWeek(auf->WDatum))+") "+DtoC(auf->WDatum) //NiceWeek(auf->wterm,4)
   ENDIF
	@ 11,03 SAY "Meldebestand....: "+LTrim(Transform(auf->MeldStock,cMe))+" "+art->Me
Endif

@ 12,03 SAY "Bearbeiter......:"; Buy( auf->buyer, .F. )
@ 13,03 SAY "Genehmigung.....:"

oAuftrag := Auftrag():New()
oAuftrag:Load(auf->Abnr)
oAufPos := oAuftrag:Positions:GetRecord(auf->Itmnr)
lWaitApproval := .F.
nAprRec := NIL
lApproved :=  IsApproved("AUF",auf->Abnr,StoT(oAuftrag:LastChange),@lWaitApproval,@nAprRec)
IF ! lApproved
   @ 13,21 SAY If(!lWaitApproval,"nicht ","")+"angefordert"
//   bDisplayApr := {|| .T. }
ELSE
   apr->(dbGoTo(nAprRec))
   //IF auf->Buyer != apr->ApprovedBy
      @ 13,21 SAY Trim(Buy(apr->ApprovedBy,.T.))+" "+Left(TtoC(StoT(apr->ApprovedDa)),17)
   /*ELSE
      @ 13,21 SAY t("nicht benötigt")
   ENDIF*/
ENDIF
   

If auf->Person > 0
	@ 14,03 SAY "Kontaktperson...: "+GetContact(auf->person)["name"]
Endif

@ 15,03 SAY    "Gedruckt........: "+Left(TtoC(SToT(oAuftrag:LastPrint)),17)



DevPos( 03, 73 )
DevOut( auf->bestat )
DevPos( 04, 03 )
DevOut( art->artikel )
DevPos( 05, 15 )
DevOut( auf->abnr )
DevPos( 05, 22 )
DevOut( auf->itmnr )
DevPos( 06, 15 )
DevOut( auf->besbesnr )
DevPos( 06, 22 )
DevOut( auf->besposnr )


DevPos( 06, 57 )
DevOut( auf->aufnr )

@ 08,47 SAY "Verkaufspreis...: "+Ltrim(Str( auf->vkpr,8,2 ))+ " "+Currate(auf->money,"X")
@ 09,47 SAY "Preiseinheit....: "+Ltrim(Str( auf->pe ))
@ 10,47 SAY "Rabatt..........: "+Ltrim(Str(auf->rabatt,8,2))+"%"

//nVk := oAufPos:Artikel:VkPr * Currate( oAuftrag:Money, "V" )
//nEk := oAufPos:Artikel:getBuyPriceForMargin(hProd:Qty,hProd:Add,oAuftrag:Besda,hProd:KW,@cSupplier)

//@ 11,47 SAY "Margin..........: "+LTrim(Str(oAufPos:GetMargin()))+"%"
If Select("wer")>0.AND.wer->Aufno != 0
	@ 12,47 SAY "Werkstattsautrag: "+Ltrim(Str(wer->Aufno))
Endif

IF Tr_Getini(28) == 9
   @ 32,02 SAY Trim(auf->RemindStat)+" ("+LTrim(Str(auf->RemindCoun))+") "+DToc(auf->RemindDate)
ENDIF
//@ 12,47 SAY "Gedruckt am....: "+DToC(auf->LastPrint)

tx->( DispText( auf->Text, 26,02, 79, 5 ) )

SetColor( c_five )

hStatus := {"    "=>"unbearbeitet","PRIN"=>"in Bearbeitung","ZOLL"=>"Zoll angemeldet","COLL"=>"Abholung angemeldet","PICK"=>"in Bearbeitung","FINA"=>"Anmeldung Factoring"}

bState := {|nInvoice| 
   LOCAL aEnv := SaveEnv()
   LOCAL cState
   re->(dbSetOrder(12))
   re->(dbseek(Str(nInvoice,6)+Str(0,3)))
   cState := re->state
   RestEnv(aEnv)
   IF ! HHasKey(hStatus,cState)
      //ALERT(Str(re->Rechnr))
      RETURN "?? "+cState
   ENDIF
   RETURN If(!re->packed,hStatus[cState],"")
}

@ 25,02 SAY Replicate(Chr(196),79)


If ! lCallOff
   re->(dbSeek( Str(auf->Abnr,6)+Str(auf->itmnr,3) ))
   Do While re->abnr == auf->abnr .AND. re->reposnr == auf->itmnr .AND. re->aoqty == 0
   	re->(dbSkip())
   Enddo
   If re->abnr == auf->abnr .AND. auf->itmnr == re->reposnr
	
   oBrowse := re->(TBrowseTr():New(06,83,30,MaxCol()-1))
   
   	oBrowse:NewColumn( "Rechn. Datum    "+Pad("Menge",11)+" "+Pad("Versand",19), {||	;
   		Str(re->Rechnr,6)+" "+DtoC(re->Rechdat)+" "+Transform(re->aoqty,cMe)+" "+art->me+" "+;
   		Pad(If(ups->(dbSeek( Str(re->Rechnr,10) )),DToC(ups->datum),Eval(bState,re->Rechnr)),19) })

     	oBrowse:WhileBlock := {|| re->abnr == auf->abnr .AND. re->reposnr == auf->itmnr}
     	oBrowse:ForBlock := {|| re->aoqty != 0 }
     	oBrowse:bRestFun := {|| .F. }
      oBrowse:lBox := .F.
     	oBrowse:AddKey(13,{|| __KeyBoard(Chr(13)),If(ups->(dbSeek( Str(re->Rechnr,10) )),Einfug(re->Rechnr),Eval({||__KeyBoard(Chr(13)+Chr(13)),RechCha(re->Rechnr)})),.T. })
      oTabs:AddTab("Rechnungen",oBrowse)
   ENDIF
ELSE

   auf->(dbSetOrder( 1 ))
   nRec := auf->(Recno())
   dFirst := auf->SDatum //Date()
   IF auf->VkQty < auf->ContrQty .AND. auf->Bestat < 3
      dLast := Date()
   ELSE
      dLast := CtoD("")
   ENDIF
      
   DO WHILE auf->Abnr ==nAbnr .AND. ! auf->(EOF())
      IF auf->ContrPos == nItmnr
         dFirst := Min(dFirst,auf->WDatum)
         dLast := Max(dLAst,auf->WDatum)
      ENDIF
      auf->(dbSkip())
   ENDDO
   IF nFrQty != 0
      auf->(dbSetOrder( 3 )) //matchcode+Str(bestat)
      auf->(dbSeek( oArt:Matchcode, .T. ))      
      DO WHILE auf->Matchcode == oArt:Matchcode         
         IF auf->BesRef == Str(nAbNr,6)+Str(nItmnr,2)            
            dFirst := Min(dFirst,auf->WDatum)
            dLast := Max(dLAst,auf->WDatum)
         ENDIF
         auf->(dbSkip())
      ENDDO
      auf->(dbSetOrder( 1 ))
   ENDIF   
   auf->(dbGoTo(nRec))

   @ 17,04 SAY "Monate:   "+LTrim(Str((dLast-dFirst)/30))
   IF dLast-dFirst > 0
      @ 18,04 SAY "D/S p.m.: "+LTrim(Transform( (auf->ContrQty-auf->VkQty+nFrQty)/((dLast-dFirst)/30),  Me(art->Me) ))
      IF auf->ContrQty-auf->VkQty+nFrQty > 0
         @ 19,04 SAY "Prognose: "         
         @ 20,08 SAY LTrim(Str(auf->ContrQty/((auf->ContrQty-auf->VkQty+nFrQty)/((dLast-dFirst)/30))))+" Monate"
         @ 21,08 SAY "bis "+DtoC(dFirst+auf->ContrQty/((auf->ContrQty-auf->VkQty+nFrQty)/(dLast-dFirst)))
         
      ENDIF
      IF Tr_getini(28) == 9
         //Alert("First: "+DtoC(dFirst)+" Last: "+DtoC(dLast))
      ENDIF
      
   ENDIF

   auf->(dbSkip())

   nBrowseRight := nBrowseLeft + 44 + Len(cMe) * 2
   oBrowse := auf->(TBrowseTr():new(06,83,30,MaxCol()-1))
   oBrowse:NewColumn( "Pos "+Pad("Auftragsnr.",20)+" Wunscht. Termin   "+Pad("Menge",Len(cMe))+" "+Pad("Geliefert",Len(cMe)),{||
      IF auf->AbNr == nAbnr .OR. auf->BesRef == Str(nAbNr,6)+Str(nItmnr,2)
         RETURN Str(auf->Itmnr,3)+" "+auf->Aufnr+" "+DTOC(auf->WDatum)+" "+If(ku->JustInTime,DToC(auf->BDatum),Pad(NiceWeek(auf->DTerm),8))+" "+Transform(auf->VkQty,cMe)+" "+Transform(auf->GelQty,cMe)
      ENDIF
      RETURN Pad("Keine Abrufe vorhanden",oBrowse:nRight-oBrowse:nLeft+1)      
   })
   IF nFrQty == 0
      oBrowse:WhileBlock := {|| auf->Abnr ==nAbnr }
      oBrowse:cFor := "Contrpos == "+LTrim(Str(nItmnr))      
   ELSE
      oBrowse:cFor := "((Abnr == "+LTrim(Str(nAbnr))+" .AND. Contrpos == "+LTrim(Str(nItmnr))+") .OR. (BesRef == '"+Str(nAbNr,6)+Str(nItmnr,2)+"'))"
   ENDIF
   oBrowse:cFor += " .AND. (Bestat < 3 .OR. GelQty != 0)"   
   cFor := oBrowse:cFor
   oBrowse:ForBlock := {|| auf->(&(cFor)) }
   oBrowse:bRestFun := {|| .F. }
   oBrowse:lBox := .F.

   oTabs:AddTab("Abrufe",oBrowse)
ENDIF
   

   oBrowse := TalkBrowse(06,83,30,MaxCol()-1,.T.,"AUF",auf->AbNr,oAddress)
   oBrowse:lBox := .F.
   oBrowse:ColorSpec := GetClrPair(C_five,1)+","+GetClrPair(c_five,5)+",,,"+GetClrPair(c_five,2)
   //oBrowse:Display()
   oTabs:AddTab("Notizen",oBrowse)
   
   IF nAprRec != 0
      aReasonLines := {}
      apr->(dbGoTo(nAprRec))
      
      cReason := ""
      DO WHILE apr->Type == "AUF" .AND. apr->No == oAuftrag:AbNr
         cReason := Trim(Buy(apr->RequestBy,.T.))+"("+Trim(Buy(apr->ApprovedBy,.T.))+") "+Left(TtoC(StoT(apr->ApprovedDa)),17)+Chr(13)+Chr(10)+apr->Reason+Chr(13)+Chr(10)+cReason
         apr->(dbSkip(-1))
      ENDDO
      
      // Split text into lines for scrollable display
      FOR nX := 1 TO MLCount(cReason,MaxCol()-85)
         AAdd(aReasonLines, MemoLine(cReason,MaxCol()-85,nX))
      NEXT
      
      // Create scrollable browse for approval reasons
      nLineIdx := 1
      oApprovalBrowse := TBrowseTr():New(06,83,30,MaxCol()-1)
      oApprovalBrowse:NewColumn("", {|| If(nLineIdx <= Len(aReasonLines), aReasonLines[nLineIdx], "")})
      oApprovalBrowse:SkipBlock := {|nSkip| nSkip := If(nSkip > 0, Min(nSkip, Len(aReasonLines) - nLineIdx), Max(nSkip, 1 - nLineIdx)), nLineIdx += nSkip, nSkip}
      oApprovalBrowse:GoTopBlock := {|| nLineIdx := 1}
      oApprovalBrowse:GoBottomBlock := {|| nLineIdx := Max(1, Len(aReasonLines))}
      oApprovalBrowse:lBox := .F.
      oApprovalBrowse:bRestFun := {|| .F.}
      
      oTabs:AddTab("Genehmigung",oApprovalBrowse)
   ENDIF
   
   
        
   oAuditBrowse := BuildAuditBrowse(06,83,30,MaxCol()-1,"AB",Str(oAuftrag:AbNr,12),oAuftrag,oAufPos)
   oAuditBrowse:bRestFun := {|| .F. }
      
   oTabs:AddTab("Audit Trail",oAuditBrowse)


oArt:gotoRec()

bChangeBrowse := {|nNew|
   oBrowse:deHilite()
   aBrowse[nActiveBrowse,2] := SaveEnv()
   nActiveBrowse := nNew
   oBrowse := aBrowse[nActiveBrowse,1]
   RestEnv(aBrowse[nActiveBrowse,2],.F.)
   Eval(aBrowse[nActiveBrowse,3])
   oBrowse:Display()
   RETURN NIL
}

IF Len(aBrowse) > 0
   FOR nX := 1 TO Len(aBrowse)
      aBrowse[nX,1]:lBox := .F.
      oBrowse:lArrow := .F.
      aBrowse[nX,1]:Display()
      aBrowse[nX,1]:deHilite()
   NEXT
   oBrowse := aBrowse[nActiveBrowse,1]
   RestEnv(aBrowse[nActiveBrowse,2],.F.)
   Eval(aBrowse[nActiveBrowse,3])
   oBrowse:Display()
ENDIF


oTabs:Modal()

/*DO WHILE nKey != 27
   IF oBrowse == NIL .OR. oBrowse:Stable
      nKey := Inkey(0)
      IF Chr(nKey) $ "Bb"
         Eval(bDisplayApr)
      ELSEIF Chr(nKey) $ "Ee"
         oAufPos:WDatum := CalWD(GetBox(CWeek(oAufPos:WDatum),"End-KW","9999"))+4
         IF LastKey() != 27
            oAufPos:Save()
         ENDIF
      ELSEIF Tr_Getini(28) == 9 .AND. Chr(nKey) $ "Rr"
         auf->(Rec_Lock(0))
         auf->RemindDate := StoD("")
         auf->(dbUnlock())
         @ 32,02 SAY Trim(auf->RemindStat)+Space(9)
      ELSEIF Len(aBrowse) > 0
         IF nKey == K_TAB
            IF nActiveBrowse < Len(aBrowse)
               Eval(bChangeBrowse,nActiveBrowse+1)
            ELSE
               Eval(bChangeBrowse,1)
            ENDIF
         ELSEIF nKey == K_SH_TAB .AND. nActiveBrowse > 1
            Eval(bChangeBrowse,nActiveBrowse-1)
         ELSEIF nKey == K_LBUTTONDOWN .AND. ((oBrowse:ClassName == "TBROWSETR" .AND. ! oBrowse:HitTest()) .OR. (oBrowse:ClassName == "TABROWSE" .AND. oBrowse:HitTest(mRow()+1,mcol()) == 0))
            FOR nX := 1 TO Len(aBrowse)
               IF nX != nActiveBrowse .AND. ((aBrowse[nX,1]:ClassName == "TBROWSETR" .AND. aBrowse[nX,1]:HitTest()) .OR. (aBrowse[nX,1]:ClassName == "TABROWSE" .AND. aBrowse[nX,1]:HitTest(mrow()+1,mcol()) != 0))
      //                     aBrowse[nX]:HitTest()
                  Eval(bChangeBrowse,nX)
               ENDIF
            NEXT
            LOOP
         ENDIF
   
         oBrowse:Event({nKey})
      ENDIF

      
   ELSE
      oBrowse:Display()
   ENDIF
ENDDO*/

STATIC FUNCTION BuildAuditBrowse(nTop,nLeft,nBottom,nRight,cAlias,cId,oAuftrag,oAufPos)   
   LOCAL oBrowse
   LOCAL cWhen
   LOCAL cUser
   LOCAL hData
   LOCAL aLogEntries := {},aFields
   LOCAL nX,nY
   LOCAL aRaw := {}
   LOCAL hSnapshot := {"DATA"=>{=>},"MLDATA"=>{=>},"AUFTRAGPOS"=>{=>}}

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
      aFields := FormatAuditFields(aRaw[nX,3],oAuftrag,oAufPos,hSnapshot)
      IF Len(aFields) != 0
         FOR nY := 1 TO Len(aFields)
            IF nY == 1
               Aadd(aLogEntries,cWhen+" "+cUser+" "+aFields[nY])
            ELSE
               Aadd(aLogEntries,Space(29)+aFields[nY])
            ENDIF
         NEXT
      ENDIF
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

STATIC FUNCTION FormatAuditFields(hData,oAuftrag,oAufPos,hSnapshot)
   LOCAL aFields := {}
   LOCAL cField,nX,nY
   LOCAL cCur,cPrev
   LOCAL cPosKey := LTrim(Str(oAufPos:Itmnr))
   LOCAL hField

   IF ValType(hData) != "H"
      RETURN ""
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
            cCur := oAuftrag:GetField(cField)
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
               cCur := oAuftrag:GetMLField(cField,HGetKeyAt(hField,nY),.T.)
            ENDIF
            IF HB_ValToStr(cCur) != HB_ValToStr(cPrev)
               Aadd(aFields,cField+"["+HGetKeyAt(hField,nY)+"]: "+AllTrim(HB_ValToStr(cPrev))+" -> "+AllTrim(HB_ValToStr(cCur)))
            ENDIF
            hSnapshot["MLDATA"][cField][HGetKeyAt(hField,nY)] := cPrev
         NEXT
      NEXT
   ENDIF

   IF HB_HHasKey(hData,"AUFTRAGPOS") .AND. HHAsKey(hData["AUFTRAGPOS"],cPosKey)
      IF ! HB_HHasKey(hSnapshot["AUFTRAGPOS"],cPosKey)
         hSnapshot["AUFTRAGPOS"][cPosKey] := {=>}
      ENDIF
      FOR nX := 1 TO Len(hData["AUFTRAGPOS"][cPosKey]["DATA"])
         cField := HGetKeyAt(hData["AUFTRAGPOS"][cPosKey]["DATA"],nX)
         cPrev := HGetValueAt(hData["AUFTRAGPOS"][cPosKey]["DATA"],nX)
         IF HB_HHasKey(hSnapshot["AUFTRAGPOS"][cPosKey],cField)
            cCur := hSnapshot["AUFTRAGPOS"][cPosKey][cField]
         ELSE
            cCur := oAufPos:GetField(cField)
         ENDIF
         IF HB_ValToStr(cCur) != HB_ValToStr(cPrev)
            Aadd(aFields,cField+": "+AllTrim(HB_ValToStr(cPrev))+" -> "+AllTrim(HB_ValToStr(cCur)))
         ENDIF
         hSnapshot["AUFTRAGPOS"][cPosKey][cField] := cPrev
      NEXT
   ENDIF

RETURN aFields

