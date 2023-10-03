#define CRLF Chr(13)+Chr(10)
FUNC RUN_PRINT_SPERRVERMERK(lInHook,cLief,cDelnote)
   LOCAL getlist := {}
   LOCAL cGrund := ""
   LOCAL cEtiPath := "\\EK-SERVER4\DATA\Dokumente und Einstellungen\All Users\Dokumente\Aufkleber\Allgemein\"
   LOCAL lDummy,lPrint := .T.
   LOCAL lLiefSet := .F.,lDelNoteSet := .F.
   
   Default(@lInHook,.F.)
   IF cLief == NIL
      cLief := Space(8)
   ELSE
      lLiefSet := .T.
   ENDIF
   IF cDelNote == NIL
      cDelNote := Space(35)
   ELSE
      lDelNoteSet := .T.
   ENDIF

   NetUse("engkund","ku")

   SetColor(c_four)
   DO WHILE .T.
      @ 10,10 CLEAR TO 22,95
      @ 10,10 TO 22,95
      @ 10,12 SAY "[ Sperrvermerk ]"
      @ 11,11 SAY "Lieferant   " GET cLief PICTURE "@!" VALID Findad( cLief, "L", 11, 60 ) WHEN ! lLiefSet
      IF lLiefSet
         Findad( cLief, "L", 11, 60 )
      ENDIF
      @ 12,11 SAY "Lieferschein" GET cDelNote VALID ! Empty(cDelNote) WHEN ! lDelNoteSet
      
      @ 13,11 SAY "Sperrgrund"
      AADD(GetList, _GET_( cGrund,"cGrund" , NIL ))
      ATAIL(GetList):Control := TextGet():New(13,24,19,58,ATail(GetList))
      ATAIL(GetList):reader := {|g| MemoReader(g) }
      ATAIL(GetList):Control:Display()
      @ 21,24 GET lDummy PUSHBUTTON CAPTION IF(lInHook,"speichern + ","")+"drucken" STATE ReadKill(.T.)   
      @ 21,IF(lInHook,47,34) GET lDummy PUSHBUTTON CAPTION IF(lInHook,"speichern","abbrechen") STATE {|| lPrint := .F.,ReadKill(.T.) }
      
      READ  
      
      IF LastKey() == 27 
         IF (Empty(cLief) .OR. ! Findad( cLief, "L", 11, 60 ) .OR. Empty(cDelNote))
            IF lInHook
               LOOP
            ELSE
               EXIT
            ENDIF
         ENDIF

         IF Tr_MsgBox("drucken?",,{"Ja","Nein"}) == 2
            lPrint := .F.
         ENDIF
      ENDIF    

      IF lPrint
         cGrund := StrTran(cGrund,Chr(141),"")      
         MBaseRun(Trim(Tr_getini(1))+"\run\labelstar2",{cEtiPath+"sperrvermerk.lbex",GetBox(1,"Anzahl Etiketten","99"),{"batch"=>StrZero(ku->Nummer,6)+"-"+Trim(cDelNote),"grund"=>cGrund}})
      ENDIF

      cGrund := "Lieferant:"+cLief+CRLF+"Lieferschein:"+cDelNote+CRLF+CRLF+cGrund
      
      EXIT      
   ENDDO

RETURN cGrund