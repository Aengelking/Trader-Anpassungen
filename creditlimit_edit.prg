#include 'y:\hb32\include\inkey.ch'
PROC RUN_CREDITLIMIT_EDIT
   LOCAL oBrowse
   

   IF ! SystemUser():CheckPermission("U","ADR_CUSTOMER_CREDITLIMIT") //getini(28) != 9 .AND. TR_getini(28) != 34
      //Tr_MsgBox("Zugang verweigert!")
      Return
   Endif

   NetUse("wkv","wkv",.F.,0)
   NetUse("engkund","ku",.F.,0)

   //update customer names for seaching
   ku->(dbSetOrder(8))
   wkv->(dbGoTop())
   DO WHILE ! wkv->(EOF())
      wkv->(Rec_Lock(0))
      IF ku->(dbSeek(Str(wkv->KuNr,6)))
         wkv->Kunde := ku->Kunde
      ELSE
         wkv->Kunde := ""
      ENDIF
      wkv->(dbUnLock())
      wkv->(dbSkip())
   ENDDO

   Head("Limitliste der Warenkreditversicherung")
   wkv->(dbGoTop())
   oBrowse := wkv->(TBrowseTr():New(02,00,MaxRow(),MaxCol()))
   oBrowse:lBox := .F.

   //cHead := Pad( Pad("Kdn.Nr.",6)+" "+Pad("Kunde",8)+" "+Pad("Risko-Nummer",20)+" "+Pad("Limit",6)+" "+Pad("Bis",8) ,MaxCol())
   oBrowse:OneColumn := .T.
   oBrowse:NewColumn("Kdn.Nr.",{|| Str(wkv->KuNr,6) },,1,"999999",0,{|x| Str(x,6) })
   oBrowse:NewColumn("Kunde",{|| ku->(dbSeek(Str(wkv->KuNr,6))),ku->Kunde},,3,"@K!",Space(8))
   oBrowse:NewColumn("Risko-Nummer",{|| wkv->Nummer},,2,"@K",Space(len(wkv->Nummer)))
   oBrowse:NewColumn("Limit",{|| Str(wkv->CredLimit,6)})
   oBrowse:NewColumn("Bis",{|| DToC(wkv->Until) })


   oBrowse:AddKey(K_ESC,{|| .F. })
   oBrowse:AddKey(K_ENTER,{|| _WkvEdit(.F.),.T. })
   oBrowse:AddKey(K_INS,{|| _WkvEdit(.T.),.T. })
   oBrowse:AddKey(K_DEL,{||
      IF Tr_MsgBox(t("Löschen?"),,{"Nein","Ja"}) == 2
         wkv->(Rec_Lock())
         wkv->(dbDelete())
         wkv->(dbUnLock())
         wkv->(dbSkip())
      ENDIF
      RETURN .T.
   })
   oBrowse:AddKey(K_CTRL_DEL,{||
      LOCAL nRec := wkv->(Recno())
      IF Tr_MsgBox(t("Alle abgelaufenen löschen?"),,{"Nein","Ja"}) == 2
         wkv->(dbGoTop())
         DO WHILE ! wkv->(Eof())
            IF ! Empty(wkv->Until) .AND. wkv->Until <= Date()-30
               wkv->(Rec_Lock())
               wkv->(dbDelete())
               wkv->(dbUnLock())
            ENDIF
            wkv->(dbSkip())
         ENDDO
      ENDIF
      wkv->(dbGoTo(nRec))
      RETURN .T.
   })
   oBrowse:AddKey(K_F9,{||  ku->(dbSeek(Str(wkv->KuNr,6))), enaddr() })

   oBrowse:EventLoop()

//wkv->(Browse())


STATIC FUNCTION _WKVEdit(lNew)
   LOCAL cGroup,cKunde,cWKVNr,dVon,dBis,nLimit,lSperr,nKuNr
   LOCAL getlist := {}
   LOCAL nRec := wkv->(Recno())
   LOCAL oRec

   MEMVAR c_four

   If ValType(lNew) != "L"
      lNew := .F.      
   Endif
   
   oRec := wkv->(Record():New(lNew))

   ku->(dbSetOrder( 8 ))
   If ! lNew
      ku->(dbSeek(Str(wkv->KuNr,6)))
   Endif

   cKunde := If(lNew,Space(8),ku->Kunde)
   cGroup := If(lNew,"K",ku->Group)
/*cWKVNr := If(lNew,Space(20),wkv->Nummer)
dVon   := If(lNew,Date(),wkv->Date)
dBis   := If(lNew,Date()+364,wkv->Until)
nLimit := If(lNew,0,wkv->CredLimit)
lSperr := If(lNew,.F.,wkv->Blocked)*/
nKuNr  := 0

SetColor(c_four)

@ 10,10 CLEAR TO 20,82
@ 10,10 TO 20,82

@ 11,11 SAY "Gruppe"
@ 11,26 GET cGroup PICTURE "!" VALID cGroup $ {"K","L"}
@ 12,11 SAY "Matchcode"
@ 12,26 GET cKunde PICTURE "@!" WHEN lNew VALID {|| lRet := Findad(cKunde,cGroup,12,47),nKuNr := ku->Nummer,lRet .AND. ! wkv->(dbSeek( Str(nKuNr,6) )) }
If ! lNew
	Eval(Atail(getlist):postBlock)
Endif

@ 13,11 SAY "Risiko-Nr. WKV"
@ 13,26 GET oRec:Nummer VALID ! Empty(oRec:Nummer)

@ 14,11 SAY "Ab"
@ 14,26 GET oRec:Date VALID ! Empty(oRec:Date)

@ 15,11 SAY "Bis"
@ 15,26 GET oRec:Until

@ 16,11 SAY "Limit"
@ 16,26 GET oRec:CredLimit

@ 17,11 SAY "Sperren"
@ 17,26 GET oRec:Blocked PICTURE "Y"

READ

If Updated() .AND. (LastKey() != 27 .OR. Tr_MsgBox("Speichern?",,{"Nein","Ja"}) == 2)
	If lNew
		//wkv->(Add_Rec(0))
      oRec:KuNr := nKuNr      
   Endif
   oRec:Kunde := cKunde
   oRec:Save()
	/*wkv->Kunde      := cKunde
	wkv->Date      := dVon
	wkv->Until     := dBis
	wkv->Nummer    := cWKVNr
	wkv->CredLimit := nLimit
	wkv->Blocked   := lSperr
	wkv->(dbUnLock())*/
Else
	wkv->(dbGoto(nRec))
Endif
