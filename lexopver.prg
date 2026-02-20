#define LX_CAT_DEBITOR          128
#define LX_CAT_KREDITOR         256
#include "y:\hb32\include\inkey.ch"

PROC RUN_LEXOPVER

LOCAL nKonto := 0
LOCAL lDebitor
LOCAL getlist := {}
LOCAL oBrowse
LOCAL lAbgeschlossen
LOCAL nJahr
LOCAL aOptions,aMsg
LOCAL aOps

LX_Start()

DO WHILE .T.
   Head("Offene Posten verrechnen")

   @ 01,00 SAY "Konto" GET nKonto PICTURE "999999"
   ATail(getlist):postBlock := {||
      LOCAL nCat := LX_GetAccountCat(nKonto)
      @ 01,14 CLEAR TO 01,MaxCol()
      IF  nCat == LX_CAT_DEBITOR .OR. nCat == LX_CAT_KREDITOR
         @ 01,14 SAY LX_GetAccountName(nKonto)
         lDebitor := nCat == LX_CAT_DEBITOR
      ELSE
         @ 01,14 SAY "Kein Debitor oder Kreditor"
         RETURN .F.
      ENDIF
      RETURN .T.
   }
   READ
   If LastKey() == 27
      RETURN
   ENDIF

   IF Tr_Getini(28) == 9 .AND. Tr_MsgBox("Auch abgeschlossene?",,{"Nein","Ja"}) == 2
      lAbgeschlossen := .T.
      nJahr := GetBox(Year(Date()),"Jahr","9999",,,,{|nJahr|nJahr>2005.AND.nJahr<=Year(Date())})
      IF LastKey() == 27
         LOOP
      ENDIF
   ELSE 
      lAbgeschlossen := .F.
   ENDIF
   aOps := LX_GetOffenePosten(nKonto,lDebitor,nJahr,lAbgeschlossen)

   IF Len(aOPs) == 0
      Tr_MsgBox("Keine Offenenposten vorhanden")
      LOOP
   ENDIF
   
   @ MaxRow(),00 SAY t(">ENTER< - Aus-/Abwählen | >STRG-ENTER< Verteilpositionen w„hlen | >ALT-V< - Verrechnen")

   aOps := ASort(aOps,,,{|x,y| x:Datum < y:Datum })
   AEval(aOps,{|x| x["SELECTED"] := .F.,x["SELECTED2"] := .F. })
   oBrowse := TABrowse():New(02,00,MaxRow()-1,MaxCol())
   oBrowse:OneColumn := .T.
   oBrowse:ColorSpec := "N/W,G/B,R/W,R/B,GR+/W,GR+/B"
   oBrowse:aData := aOps
   oBrowse:AddKey(K_ESC,{|| .F. })
   oBrowse:AddKey(K_ENTER,{|| oBrowse:CurrentDataRow():Selected2 := .F., oBrowse:CurrentDataRow():Selected := ! oBrowse:CurrentDataRow():Selected, .T. })
   oBrowse:AddKey(K_CTRL_ENTER,{|| oBrowse:CurrentDataRow():Selected := .F., oBrowse:CurrentDataRow():Selected2 := ! oBrowse:CurrentDataRow():Selected2, .T. })
   oBrowse:AddKey(K_ALT_V,{||
      LOCAL x
      LOCAL nTotal := 0,nDistribute := 0,nLastNeg := 0,nLastPos := 0,nCount := 0      

      FOR EACH x IN aOps
         nCount++
         IF x:Selected
            nTotal += x:Rest
            IF x:Rest >= 0
               nLastPos := nCount
            ELSE
               nLastNeg := nCount
            ENDIF
         ELSEIF x:Selected2
            nDistribute += x:Rest
         ENDIF
      NEXT
      IF nCount > 0
         IF nDistribute == 0 .AND. ((nLastNeg != 0 .AND. nTotal < 0 .AND. nTotal < aOps[nLastNeg]:Rest) .OR. (nLastPos != 0 .AND.nTotal >= 0 .AND. nTotal > aOps[nLastPos]:Rest))
            Tr_MsgBox(t("Restbetrag ("+LTrim(Str(nTotal))+") "+IF(nTotal<0,"kleiner","größer")+" als der letzte Betrag ("+LTrim(Str(IF(nTotal<0,aOps[nLastNeg]:Rest,aOps[nLastPos]:Rest)))+"). Verrechnung kann nicht durchgeführt werden"))
            RETURN .T.
         ENDIF         
         aOptions := {"abbrechen"}
         aMsg := {"Summe: "+LTrim(Str(nTotal))}
         IF nDistribute != 0 .AND. nDistribute != nTotal
            Aadd(aOptions,"prozentual verrechnen")
            Aadd(aMsg,"Zu verrechnen: "+LTrim(Str(nDistribute)))
            Aadd(aMsg,"Neue Summe: "+LTrim(Str(nDistribute+nTotal)))
         ELSE
            Aadd(aOptions,"verrechnen")
         ENDIF
         IF Tr_MsgBox(aMsg,,aOptions) == 2
            nCount := 0
            FOR EACH x IN aOps
               nCount++
               IF x:Selected .OR. x:Selected2
                  IF nDistribute == 0
                     IF (nTotal >= 0 .AND. nCount != nLastPos) .OR. (nTotal < 0 .AND. nCount != nLastNeg)
                        x:Rest := 0
                     ELSE
                        x:Rest := nTotal
                     ENDIF
                  ELSE
                     IF x:Selected2 
                        x:Rest := 0
                     ELSE
                        x:Rest := x:Rest+nDistribute*x:Rest/nTotal
                     ENDIF
                  ENDIF
                  LX_SetOffenerPostenRest(x:Nr,x:Rest)
                  x:Selected := .F.
                  x:Selected2 := .F.
               ENDIF
            NEXT            
            __DispTotal(aOps)
         ENDIF
      ENDIF
      RETURN .T.
   })
   IF Tr_Getini(28) == 9
      oBrowse:AddKey(K_ALT_E,{||
         LOCAL nValue
         LOCAL x := oBrowse:CurrentDataRow()
         nValue := GetBox(x:Rest,"Neuer Wert","@E 999,999.99")
         IF LastKey() != 27
            x:Rest := nValue
            LX_SetOffenerPostenRest(x:Nr,x:Rest)
         ENDIF
         RETURN .T.
      })
      oBrowse:AddKey(K_SPACE,{||
         LOCAL aEnv := SaveEnv()
         LOCAL hZahlung
         LOCAL cMemo,nRest
         //MemoEdit( ValToPrg(oBrowse:CurrentDataRow()) )
         //Alert( ValType(LX_GetOffenerPosten(25778,63426) ) )
         @ 10,10 CLEAR TO 30,82
         @ 10,10 TO 30,82                    
         @ 11,11 SAY Pad("Datum",8)+" "+Pad("Betrag",10)+" "+Pad("Rest",10)+" "+Pad("Buchungstext",30)
         nRest := oBrowse:CurrentDataRow():Betrag
         cMemo := DToC(oBrowse:CurrentDataRow():Datum)+" "+Str(oBrowse:CurrentDataRow():Betrag*-1,10,2)+" "+Str(nRest,10,2)+" "+Pad(oBrowse:CurrentDataRow():Text,30)+Chr(13)+Chr(10)
         FOR EACH hZahlung IN LX_GetOffenerPostenZahlungen(oBrowse:CurrentDataRow():Nr )            
            nRest -= hZahlung:nBetrag
            cMemo += DtoC(hZahlung:dDatum)+" "+Str(hZahlung:nBetrag,10,2)+" "+Str(nRest,10,2)+" "+Pad(hZahlung:Text,30)+Chr(13)+Chr(10)
         NEXT
         MemoEdit(cMemo,12,11,29,81)
         
         RestEnv(aEnv,.T.)
         RETURN .T.
      })
   ENDIF
   oBrowse:NewColumn("Datum",{|| DToC(oBrowse:CurrentDataRow():Datum) },{|| IF(oBrowse:CurrentDataRow():Selected2,{5,6},IF(oBrowse:CurrentDataRow():Selected,{3,4},{1,2})) } )
   oBrowse:NewColumn("Buchungstext",{|| Pad(oBrowse:CurrentDataRow():Text,MaxCol()-4-8-12) })
   oBrowse:NewColumn("Betrag",{|| Str(oBrowse:CurrentDataRow():Rest,12,2) })
   oBrowse:bAnyFun := {|| __DispTotal(aOps) }
   oBrowse:EventLoop()
ENDDO

STATIC FUNCTION __DispTotal(aOps)
   LOCAL nTotal := 0
   AEval(aOps,{|x| nTotal += x:Rest })
   @ MaxRow(),MaxCol()-13 SAY Str(nTotal,12,2)
RETURN .t.