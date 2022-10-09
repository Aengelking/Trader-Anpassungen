#include 'y:\hb32\include\inkey.ch'

#define LX_CAT_DEBITOR          128
#define LX_CAT_KREDITOR         256

#command @ <top>,<left>,<bottom>,<right> GET <var> LISTBOX <hash> ASSOCIATIVE ;
	[VALID <valid>];
	[WHEN <when>];
	[COLOR <color>];
;
=> GET_AssociativeListBox(getlist,<top>,<left>,<bottom>,<right>,{|v| If(v==NIL,<var>,<var>:=v)},<hash>,<{valid}>, <{when}>,<color>)

STATIC oFilter

PROCEDURE REB
LOCAL oBrowse,oBrowse2
LOCAL oBooked,oGenehm,bEditNotes,bRebuild,oYears,oPerson,nYear := 1,aYears,hPeople2
LOCAL cCol    := Replicate("N/W,",3)+"B+/W"
LOCAL cKonto,nLiefnr,cLiefma,hAccounts,cScreen,lOK,nKonto := 0
LOCAL bSkip
LOCAL getlist := {},aChoice
LOCAL oGet,oRec
LOCAL nPerson := Tr_Getini(28),nPersSel,nPersNoBooked
LOCAL cFor,bSetFilter,lShowNotes := .F.

MEMVAR c_five

/*** SETTINGS ***/
LOCAL lCanApprove := Tr_Getini(28) $ GetValue("REB_APPROVER",{9,57},"Genehmiger (Benutzernummer)")
LOCAL hApprKto    := /*GetValue("REB_APRACC",*/ {51=>{70887,74186,70062,70302,70141,70814,70911,70866,70995,76056,76236,76254,76239,76269},34=>{76126,76168,76019,74245,76218,74930,76157}} /*,"Konten fÅr Genehmiger")*/ //Value Editing programm needs working on
LOCAL hPeople := {9=>"Amos",34=>"Sigrid",50=>"Daniela",57=>"Daniel",51=>"Celina"}
LOCAL nPersOnApprove := 34 //automatically assign to this person on approval
LOCAL aAdmin      := {9}
LOCAL nTolPaydate := GetValue("REB_TOLDATE",2,"Toleranz fÅr Zahldatum") //deduct from due date to compensate for Postal time etc.
/***************/
LOCAL lIsAdmin    := AScan(aAdmin,Tr_Getini(28)) != 0

IF Date() <= StoD("20200830") .AND. Tr_Getini(28) == 34 //Urlaub Daniel 
   lCanApprove := .T.
   //hPeople[45] := "Joel"
ENDIF

IF ! Tr_Getini(28) $ hPeople
   RETURN
ENDIF

NetUse("reb","reb")
NetUse("rebprot","rebp")
NetUse("rebnotes","rebn")
NetUSe("engkund","ku")
NetUSe("skontob","skb")


LX_Start()

Head("Rechnungseingangsbuch")

/*ku->(dbSetOrder( 8 ))
reb->(dbSetOrder( 0 ))
reb->(dbGoTop())
SetCursor(0)
@ 01,10 SAY "/"+LTrim(Str(reb->(LastRec())))
DO WHILE ! reb->(EOF())
   @ 01,00 SAY reb->(Recno())   
   IF ! Empty(reb->Liefnr)
      ku->(dbSeek( Str(reb->Liefnr,6) ))
      cName := Pad(Trim(ku->Name1)+" "+ku->Name2,50)
   ELSE
      cName   := Pad(LX_GetAccountName(reb->Konto),50)
   ENDIF
   IF reb->Name != cName
      reb->(Rec_Lock())
      reb->Name := cName
      reb->(dbUnLock())      
   ENDIF
   reb->(dbSkip())
ENDDO
reb->(dbSetOrder( 1 ))
SetCursor(1)*/

oBooked := HBCheckBox():New(01,00)
oBooked:Caption := t("&Verbuchte Eintr‰ge")
oBooked:colorSpec := cCol
oBooked:sBlock := {||
   cFor := "ID != 0" //.AND. ((! Empty(Beleg_Kurz) .AND. Len(Trim(Beleg_Kurz))>10).OR.(Empty(Beleg_Kurz) .AND. Len(Trim(Beleg))>10))"
   IF ! oBooked:Buffer
      cFor += " .AND. Status != 9"      
      IF ValType(nPersNoBooked) == "N"
         nPersSel := HGetPos(hPeople2,nPersNoBooked)
         nPerson := nPersNoBooked
         nPersNoBooked := NIL
         oPerson:Control:Select(nPersSel)
         oPerson:Control:Display()         
      ENDIF   
   //ELSEIF oMine:Buffer
     // oMine:Select()
   //ELSEIF nPerson == Tr_Getini(28)
     // nPersSel := HGetPos(hPeople2,0)
      //oPerson:Control:Display()
   ELSE
      nPersSel := Len(hPeople2)
      nPersNoBooked := nPerson
      nPerson := 0
      oPerson:Control:Select(nPersSel)
      oPerson:Control:Display()
   ENDIF
   IF ! oGenehm:Buffer
         cFor += " .AND. (Status >= 8 .OR. Liefnr != 0)"
   ENDIF
   IF nPerson != 0
      cFor += " .AND. Person == "+LTrim(Str(nPerson)) //Str(Tr_getini(28)))
   ENDIF
   IF nYear != 1
      cFor += " .AND. Left(Str(ID,9),2) == '"+Right(aYears[nYear],2)+"'"      
   ENDIF
   Eval(bSetFilter)
   RETURN NIL
}
oBooked:Display()
oGenehm := HBCheckBox():New(01,23)
oGenehm:Caption := t("Nicht &genehmigte Eintr‰ge")
oGenehm:sBlock := oBooked:sBlock
oGenehm:colorSpec := cCol

oGenehm:Display()

/*oMine := HBCheckBox():New(01,53)
oMine:Caption := t("Nur mir &zugeordnete")
oMine:sBlock := oBooked:sBlock
oMine:colorSpec := cCol
oMine:Display()*/

hPeople2 := HB_HClone(hPeople)
hPeople2[0] := "alle"
nPersSel := HGetPos(hPeople2,nPerson)
@ 01,54 SAY "Person:"
@ 01,61,10,72 GET nPersSel LISTBOX HGetValues(hPeople2) DROPDOWN WHEN ! oBooked:Buffer
oPerson := Atail(getlist); getlist := {}
oPerson:Control:sBlock := {||   
   ReadKill(.T.)   
   nPerson := HGetKeyAt(hPeople2,oPerson:Control:Buffer)
   IF ! oBooked:Buffer //this means it has been called throuhg oBook:sBlock
      Eval(oBooked:sBlock)   
   ENDIF
   RETURN .T.
}

aYears := {"alle"}
FOR nYear := 2017 TO Year(Date())
   Aadd(aYears,Str(nYear,4))
NEXT
@ 01,78 SAY "Jahr:"
nYear := 1
@ 01,83,10,88 GET nYear LISTBOX aYears DROPDOWN
oYears := Atail(getlist); getlist := {}
oYears:Control:sBlock := {||
   ReadKill(.T.)
   nYear := oYears:Control:Buffer      
   Eval(oBooked:sBlock)
   
   RETURN .T.
}
//oYears:Display()

oBrowse := reb->(TBrowseTr():New(03,00,MaxRow()-11,MaxCol()))
oBrowse:OneColumn := .T.
oBrowse:lBox := .F.
oBrowse:NewColumn("G",{|| IF(reb->Status < 8,IF(reb->Liefnr == 0,"!","-")," ") })
oBrowse:NewColumn("Index",{|| Str(reb->ID,9) },,1,Replicate("9",9),0,{|x|Str(x,9)})
oBrowse:NewColumn("Beleg",{|| reb->Beleg },,5,"@!",Space(35),{|x| X })
oBrowse:NewColumn("Lieferant/Konto",{||
   LOCAL cName
   IF reb->Liefnr == 0
      cName := Pad(LX_GetAccountName(reb->Konto),50)
   ELSE
      ku->(dbSetOrder( 8 ))
      ku->(dbSeek( Str(reb->Liefnr,6) ))
      cName := Pad(Trim(ku->Name1)+" "+ku->Name2,50)
   ENDIF
   IF reb->Name != cName
      /*reb->(Rec_Lock())  //this is not a good place to do this as it can change to order and get things mixed up
      reb->Name := cName
      reb->(dbUnLock())*/
      //cName := "FALSCH"      
   ENDIF
   RETURN cName
},,8,"@S35",Space(50),{|x| Upper(Trim(x)) })

IF Tr_Getini(28) == 9
   oBrowse:NewColumn("BN",{|| Str(reb->Person,2) })   
ENDIF

oBrowse:NewColumn(,{||
   IF rebn->(dbSeek( Str(reb->id,9) ))
      RETURN "N"
   ENDIF
   RETURN " "
})
oBrowse:NewColumn("Termin",{||
   LOCAL dDate,aSkonto
   
   rebp->(dbSetOrder( 1 ))
   rebp->(dbSeek( Str(reb->ID,9), .T. ))
   IF reb->Status < 8 .AND. reb->Liefnr != 0
      IF ! IsPrePay(ku->Skonto)
         aSkonto := skb->(GetSkonto(ku->Skonto,StoD(rebp->DateTime)))
         dDate := AddWorkingDays(StoD(rebp->DateTime)+IF(aSkonto[1,2]==0.AND.Len(aSkonto)>1,aSkonto[2,2],aSkonto[1,2]),nTolPaydate*-1,GetConfigValue("STATE"),.T.)
      ELSE
         dDate := StoD(rebp->DateTime)+13 //nach 15 Tagen kommt die Meldung, dass die Rechnung fehlt
      ENDIF
      RETURN DtoC(dDate)
   ENDIF
   RETURN DtoC(StoD(rebp->DateTime)+5) //standard ist 5 Tage nach erhalt, das sollte auch fÅr Skonto reichen
})

oBrowse:NewColumn("Kontonr.",{||
   IF reb->Liefnr == 0
      RETURN Str(reb->Konto,6)
   ENDIF
   RETURN Space(6)   
},,7,"999999",0,{|nKonto| Str(nKonto,6) })


oBrowse:bAnyFun := {||
   LOCAL nX,aBookings,nR := 0
   LOCAL nW := MaxCol()-41   
   LOCAL nL := 42
   LOCAL lStorno
   LOCAL nTop := MaxRow()-09

   rebp->(dbSetOrder( 1 ))
   rebp->(dbSeek( Str(reb->ID,9), .T. ))
   oBrowse2:Rebuild := .T.
   oBrowse2:Display()
   oBrowse2:deHilite()
   @ nTop,nL CLEAR TO MaxRow(),MaxCol()
   @ MaxRow()-08,42 SAY Replicate(Chr(196),nW)
   DispBox(MaxRow()-09,41,MaxRow(),41)
   IF reb->Status == 9
      rebp->(dbSetFilter({|| Trim(rebp->Type) == "STORN" },'Trim(Type) == "STORN"'))
      lStorno := rebp->(dbSeek( Str(reb->ID,9), .T. ))
      rebp->(dbClearFilter())
      IF lStorno
         @ nTop,nL SAY Pad("GRUND",nW)
         @ nTop+2,nL SAY rebp->Grund
      ELSE
         @ nTop,nL SAY Pad("BUCHUNGEN",nW)
         aBookings := LX_GetBookingsForID("ER"+Str(reb->ID,9))
         FOR nX := 1 TO Len(aBookings)
            IF aBookings[nX,"HABEN"] != 0 //ignore split bookings
               @ nTop+nR+2,nL SAY DtoC(aBookings[nX,"BUCHDATUM"])+" "+Str(aBookings[nX,"HABEN"],6)+" "+Pad(aBookings[nX,"TEXT"],MaxCol()-41-8-1-6-1)
               nR++
               IF aBookings[nX,"SOLL"] != 0
                  @ nTop+nR+2,nL SAY Space(8)+" "+Str(aBookings[nX,"SOLL"],6)+" "+Str(aBookings[nX,"NETTO"],12,2)
                  nR++
               ENDIF
            ENDIF
         NEXT
      ENDIF
      rebp->(dbSeek( Str(reb->ID,9), .T. ))
   ENDIF
   IF reb->Status < 8  .OR. (rebn->(dbSeek( Str(reb->ID,9) )) .AND. ! Empty(rebn->Notes))
      IF reb->Status > 8
         @ nTop,nL+10 SAY "|"
         IF ! lShowNotes
            @ nTop,nL+12 SAY "N" COLOR "B+/W"
         ELSE
            @ nTop,nL+12 SAY "N"
         ENDIF
         @ nTop,nL+13 SAY "OTIZEN"
      ELSE      
         @ nTop,nL SAY "N" COLOR "B+/W"
         @ nTop,nL+1 SAY "OTIZEN"         
      ENDIF
      IF reb->Status <= 8 .OR. lShowNotes
         IF rebn->(dbSeek( Str(reb->ID,9) )) .AND. !Empty(rebn->Notes)
            cCol := SetColor("N/GR*")
            FOR nX := 1 TO 9
               @ nTop+nX+1,nL SAY Pad(MemoLine(rebn->Notes,nW,nX),nW)
            NEXT
            SetColor(cCol)
         ENDIF
      ENDIF
      
   ENDIF

   RETURN .T.
}

/*oBrowse:bRestFun := {|oBrowse,aKey|
   IF reb->(IndexOrd()) ==
*/

oBrowse:AddKey(K_ESC,{|| .F. })

bRebuild := {||
   oBrowse:Rebuild := .T.
   //oBrowse:Display()
   Eval(bSkip)
   RETURN NIL
}
bSkip := {||
   LOCAL nRow := oBrowse:rowPos
   IF Eval(oBrowse:ForBlock)
      reb->(dbSetFilter(oBrowse:ForBlock,oBrowse:cFor))
      reb->(dbSkip())
      IF reb->(EOF())
         reb->(dbSkip(-1))
      ENDIF
      reb->(dbClearFilter())
   ENDIF
   IF nRow == 1
      oBrowse:goTop()
   ENDIF
   RETURN NIL
}

oBrowse:AddKey(K_ALT_G,{|| oGenehm:Select(), Eval(bRebuild) })
oBrowse:AddKey(K_ALT_V,{|| oBooked:Select(), Eval(bRebuild) })
//oBrowse:AddKey(K_ALT_Z,{|| oMine:Select(), Eval(bRebuild) })


bEditNotes := {||
   LOCAL cText
   LOCAL cCol := SetColor("N/GR*")
   LOCAL lNew := .T.
   IF reb->Status > 8
      lShowNotes := ! lShowNotes
      RETURN NIL
   ENDIF
   IF rebn->(dbSeek( Str(reb->Id,9) ))
      cText := rebn->Notes
      lNew := .F.
   ENDIF

   cText := MemoEdit(cText,MaxRow()-7,42,MAxRow(),MAxCol())
   SetColor(cCol)

   IF ! lNew
      rebn->(dbSeek( Str(reb->Id,9) ))
   ENDIF
   IF ((! lNew .AND. cText != rebn->Notes) .OR. (lNew .AND. ! Empty(cText))) .AND. (LastKey() == K_CTRL_W .OR. Tr_MsgBox("Speichern?",,{"Ja","Nein"}) != 2)
      IF rebn->(dbSeek( Str(reb->Id,9) ))
         rebn->(Rec_Lock(0))
      ELSE
         rebn->(Add_Rec())
         rebn->ID := reb->ID
      ENDIF
      rebn->Notes := cText
      rebn->(dbUnLock())
   ENDIF
   RETURN NIL
}

oBrowse:AddKey(K_ALT_N,bEditNotes)


oBrowse:AddKey(K_LBUTTONDOWN,{||
   IF oBooked:HitTest(MRow(),MCol()) != 0
      oBooked:Select()
      Eval(bRebuild)
   ELSEIF oGenehm:HitTest(MRow(),MCol()) != 0
      oGenehm:Select()
      Eval(bRebuild)
   ELSEIF ! oBooked:Buffer .AND. oPerson:HitTest(MRow(),MCol()) != 0
      oPerson:Control:Open()
      getlist := {oPerson}
      READ
      //oMine:Select()
      Eval(bRebuild)
   ELSEIF oYears:HitTest(MRow(),MCol()) != 0
      oYears:Control:Open()
      getlist := {oYears}
      READ
      Eval(bRebuild)
   ELSEIF reb->Status < 8 .AND. MRow() >= MaxRow()-9 .AND. MCol() >= 41
      Eval(bEditNotes)
   ENDIF
   RETURN .T.
})

oBrowse:AddKey(K_DEL,{||
   LOCAL cGrund := Space(20)
   IF Tr_MsgBox("Beleg stornieren?",,{"Nein","Ja"}) == 2
      DO WHILE Len(Trim(cGrund)) < 10
         cGrund := GetBox(cGrund,"Grund")
         IF LastKey() == 27
            RETURN .T.
         ENDIF
      ENDDO
      LETO_BEGINTRANSACTION()
      BEGIN SEQUENCE
         reb->(Rec_Lock())
         reb->Status := 9
         rebp->(Add_Rec())
         rebp->ID := reb->ID
         rebp->DateTime := TtoS(DateTime())
         rebp->Type     := "STORN"
         rebp->Person   := Tr_Getini(28)
         rebp->Rev      := reb->Rev
         rebp->Grund    := cGrund
         LETO_COMMITTRANSACTION()
         IF oBooked:Buffer
            rebp->(dbSkip())
         ENDIF
         Eval(bRebuild)
      RECOVER
         LETO_ROLLBACK()
      END
   ENDIF
   RETURN NIL
})

oBrowse:AddKey(K_ENTER,{||
   LOCAL aFiles := GetArchiveFiles({"ER"=>reb->ID})
   LOCAL cZuText := "anderer Person zuordnen"
   LOCAL cFirmText := t("Lieferant ‰ndern")
   LOCAL lChangePers := .F.,lChangeFirm := .F.
   LOCAL bOpen := {|cFile|
      Wapi_ShellExecute(,"open",cFile)
      RETURN NIL
   }
   LOCAL nChoice,nTop   
   MEMVAR c_five,c_one
   ASort(aFiles,,,{|x,y| x[6] < y[6] }) //sort according to file name and not date
   /*IF Tr_Getini(28) == 9
      FOR nX := 1 To LEN(aFiles)
      ? aFiles[nX,6]
      NEXT
      Sinkey(0)
   ENDIF*/
   IF reb->Status <= 8
      IF reb->Liefnr != 0 .OR. reb->Status == 8
         nChoice := Tr_MsgBox("Buchen?",,{"Ja","abrechen","anzeigen",cZuText,cFirmText})
         IF nChoice == 1
            Eval(bOpen,ATail(aFiles)[6])
            IF reb->Liefnr != 0 //Trader
               ku->(dbSetORder( 8 ))
               ku->(dbSeek( Str(reb->Liefnr,6) ))
               engre(ku->Kunde,Pad(IF(Empty(reb->Beleg_Kurz),reb->Beleg,reb->Beleg_Kurz),14))
            ELSE //Lexware
               Tr_MsgBox(t("Bitte ¸ber Lexware buchen"))
               IF Len(LX_GetBookingsForID("ER"+Str(reb->Id,9),.T.)) > 0
	              reb->(Rec_Lock(0))
	              reb->Status := 9    //mark as booked
	              reb->(dbUnLock())
	            ENDIF
	         ENDIF
	         IF reb->Status == 9 .AND. ! oBooked:Buffer
	           Eval(bSkip)
	         ENDIF
         ELSEIF nChoice == 3
            Eval(bOpen,ATail(aFiles)[6])
         ELSEIF nChoice == 4
            lChangePers := .T.
         ELSEIF nChoice == 5
            lChangeFirm := .T.
         ENDIF
      ELSEIF (lCanApprove .OR. (Tr_Getini(28) $ hApprKto .AND. reb->Konto $ hApprKto[Tr_Getini(28)]) ) .AND. reb->Person == Tr_Getini(28)
         Eval(bOpen,ATail(aFiles)[6])
         nChoice := Tr_MsgBox("Freigeben?",,{"Nein","Ja",cZuText,cFirmText})
         IF nChoice == 2
            LETO_BEGINTRANSACTION()
            BEGIN SEQUENCE
               reb->(Rec_Lock())
               reb->Status := 8
               reb->Person := nPersOnApprove
               rebp->(Add_Rec())
               rebp->ID := reb->ID
               rebp->DateTime := TtoS(DateTime())
               rebp->Type     := "APR"
               rebp->Person   := Tr_Getini(28)
               rebp->Rev      := reb->Rev
               LETO_COMMITTRANSACTION()
               IF nPersOnApprove != Tr_Getini(28)
                  //reb->(dbSkip())
                  Eval(bSkip)
               ENDIF
            RECOVER
               LETO_ROLLBACK()
            END
         ELSEIF nChoice == 3
            lChangePers := .T.
         ELSEIF nChoice == 4
            lChangeFirm := .T.
         ENDIF
      ELSE
         nChoice := Tr_MsgBox("Beleg ist noch nicht zur Buchung freigegeben",,{"OK","anzeigen",cZuText,cFirmText})
         IF nChoice == 2
            Eval(bOpen,ATail(aFiles)[6])
         ELSEIF nChoice == 3
            lChangePers := .T.
         ELSEIF nChoice == 4
            lChangeFirm := .T.
         ENDIF
      ENDIF
      IF lChangePers
         nTop := (MaxRow()-7)/2
         cScreen := SaveScreen()
         SetColor(c_five)
         @ nTop,35 CLEAR TO nTop+7,55
         Tr_Box(nTop,35,nTop+7,55,.T.)
         @ nTop+1,37 SAY t("Person ausw‰hlen")
         @ nTop+2,35 SAY Chr(199)+Replicate(Chr(196),19)+Chr(182)
         oRec := reb->(Record():New())
         @ nTop+4,36,nTop+15,54 GET oRec:Person LISTBOX hPeople ASSOCIATIVE
         READ
         IF LastKey() != 27
/*            rebp->(Add_Rec())
            rebp->Type := "PERS"
            rebp->DateTime := DateTime()
            rebp->Person   := Tr_getini(28)
            rebp->Rev      := reb->Rev
            rebp->(dbUnLock())*/
            oRec:Save()
            //reb->(dbSkip())
            Eval(bSkip)
         ENDIF
         RestScreen(,,,,cScreen)
         SetColor(c_one)
      ENDIF
   ELSE
      nChoice := 1
      IF reb->Liefnr != 0          
         aChoice := {"Beleg anzeigen","Buchung îffnen"}
         IF lIsAdmin
            Aadd(aChoice,cFirmText)
         ENDIF
         nChoice := Tr_MsgBox("Auswahl",,aChoice)         
      ELSEIF lIsAdmin
         aChoice := {"Beleg anzeigen",cFirmText}
         nChoice := Tr_MsgBox("Auswahl",,aChoice)
         IF nChoice == 2
            nChoice := 3
         ENDIF
      ENDIF
      IF nChoice == 1            
         Eval(bOpen,ATail(aFiles)[6])
      ELSEIF nChoice == 2         
         ku->(dbSetORder( 8 ))
         ku->(dbSeek( Str(reb->Liefnr,6) ))            
         engre(ku->Kunde,Pad(IF(Empty(reb->Beleg_Kurz),reb->Beleg,reb->Beleg_Kurz),14))
      ELSEIF nChoice == 3
         lChangeFirm := .T.
      ENDIF
   ENDIF
   IF lChangeFirm
      cKonto := Space(100)
      nLiefnr := 0
      cLiefma := Space(8)
      hAccounts := LX_GetAccountsInCat(LX_CAT_KREDITOR,.T.)
      cScreen := SaveScreen()
      lOk := .F.
      SetColor(c_five)
      @ 10,07 CLEAR TO 17,84
      @ 10,07 TO 17,84
      @ 11,08 SAY Pad("Lieferant",9) GET cLiefma PICTURE "@!" VALID Empty(cLiefma) .OR. FindAd( cLiefma, "L",11,49 ) WHEN Empty(cKonto)
      @ 12,08 SAY Pad("Konto",9)
      oGet := GetSuggestions():New(12,18,{|v| IF(v==NIL,cKonto,cKonto:=v) })
      oGet:aValues := HGetValues(hAccounts)
      oGet:Picture := "@S30"
      oGet:Display()
      oGet:preBlock := {|| Empty(cLiefma) }
      oGet:postBlock := {||
         nKonto := Val(cKonto)
         IF ! HHasKey(hAccounts,nKonto)
            IF LX_HasAccountInCat(nKonto,LX_CAT_DEBITOR) == 1 .AND. Tr_MsgBox("Rechnung einem Debitor zuweisen?",,{"Nein","Ja"}) == 2
               cKonto := LTrim(Str(nKonto))+" "+LX_GetAccountName(nKonto)
            ELSE
               IF LastKey() == K_UP .OR. LastKey() == K_SH_TAB
                  cKonto := Space(100)
                  oGet:Display()
                  RETURN .T.
               ENDIF
               RETURN .F.
            ENDIF
         ELSE
             cKonto := Pad(hAccounts[nKonto],100)
             oGet:Display()
         ENDIF
         RETURN .T.
      }
      Aadd(getlist,oGet)
      @ 13,08 SAY Pad("Ok?",9) GET lOk PICTURE "Y" VALID lOk
      READ
      IF LastKey() != 27
         reb->(Rec_Lock())
         IF ! Empty(cLiefma)
            reb->Liefnr := ku->Nummer
            reb->Konto  := 0
         ELSE
            reb->Konto  := nKonto
            reb->Liefnr := 0
         ENDIF
      ENDIF
      RestScreen(,,,,cScreen)
      SetColor(c_one)
   ENDIF
   RETURN .T.
})


oBrowse:AddKey(K_F11,{||
      SetColor(c_five)
      IF oFilter == NIL
         oFilter := InteractiveFilter():New(00,02,10,,"REB")
         oFilter:AddValue("Lieferant",'Upper(name)',Space(25))
      ENDIF
      oFilter:Dialog()
      Eval(bSetFilter)
      RETURN .T.
   },"Filter")
   bSetFilter := {||  oBrowse:SetFilter(oFilter,cFor ) }

IF lIsAdmin
   oBrowse:AddKey(K_CTRL_ENTER,{||
      LOCAL cBeleg := Trim(reb->Beleg_Kurz)
      IF Empty(cBeleg)
         cBeleg := Trim(reb->Beleg)
      ENDIF
      IF Len(reb->Beleg) <= 10
         Alert("Belegnummer ist kurz genug")
         RETURN .T.
      ENDIF
      cBeleg := GetBox(Pad(Right(cBeleg,10),10),"Belegnummer kurz")
      reb->(Rec_Lock())
      reb->Beleg_Kurz := cBeleg
      reb->(dbUnlock())
      RETURN .T.
   })

   oBrowse:AddKey(K_ALT_B,{||      
      LOCAL cBeleg,cBelegKurz := ""
      LOCAL nMaxLen := 10
      Alert("ACHTUNG: Belegnummer wird nicht auf Doppel geprÅft!")
      cBeleg := GetBox(reb->Beleg,"Belegnummer","@!")
      IF Empty(cBeleg) .OR. LastKey() == 27
         RETURN .T.
      ENDIF      
      IF Len(Trim(cBeleg)) > nMaxLen
         cBelegKurz := GetBox(Right(Trim(cBeleg),nMaxLen),"Belegnummer zu lang","@!",,,,{|cBelegKurz| ! Empty(cBelegKurz) })
         IF LastKey() == 27
            RETURN .T.
         ENDIF
      ENDIF
      reb->(Rec_Lock())
      reb->Beleg := cBeleg
      reb->Beleg_Kurz := cBelegKurz
      reb->(dbUnLock())
      RETURN .T.      
   })
ENDIF

oBrowse:ForBlock := {|| reb->(&(cFor))}
//oBrowse:cFor := "Status <= 3"





oBrowse2 := rebp->(TBrowseTr():New(MaxRow()-9,00,MaxRow(),40))
oBrowse2:OneColumn := .T.
oBrowse2:lBox := .F.
oBrowse2:NewColumn("Zeitpunkt",{|| Pad(Left(TtoC(StoT(rebp->DateTime)),IF(Trim(rebp->Type)=="RECV",9,14)),14) })
oBrowse2:NewColumn("Event",{|| Pad(RebTypeText(rebp->Type),11) })
oBrowse2:NewColumn("Person",{|| 
   LOCAL cName := Buy(rebp->Person,.T.)
   RETURN Pad(Left(cName,AT(" ",cName)),10)
})
oBrowse2:WhileBlock := {|| rebp->Id == reb->ID }
//oBrowse2:Display()


//oMine:Select(.T.)
oGenehm:Select(.T.)

IF lCanApprove

ELSE
   Eval(oBooked:sBlock)
ENDIF

reb->(dbSetFilter(oBrowse:ForBlock,oBrowse:cFor))
reb->(dbGoTop())
reb->(dbClearFilter())

@ MaxRow()-10,00 SAY Replicate(Chr(196),MaxCol()+1)

oBrowse:EventLoop()
//oPdf:Close()


FUNCTION RebTypeText(cType)
   SWITCH Trim(cType)
      CASE "RECV"
         RETURN "eingegangen"
      CASE "SCAN"
         RETURN "gescant"
      CASE "ARCHIV"
         RETURN "archiviert"
      CASE "APR"
         RETURN "genehmigt"
      CASE "STORN"
         RETURN "storniert"
      CASE "NEW"
         RETURN "ersetzt"
   END
RETURN ""