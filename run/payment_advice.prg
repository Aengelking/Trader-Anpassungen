
#command @ <row>,<col> GET <var> CONTACTLIST;
      [VALID <valid>];
      [WHEN <when>];
      [COLOR <color>];
      [<noblank:NOBLANK>];
;
=> GET_Contact(getlist,<row>,<col>,{|v| If(v==NIL,<var>,<var>:=v)},<.noblank.>,<{valid}>, <{when}>,<color>)

PROCEDURE RUN_payment_advice
LOCAL nKonto := 0
LOCAL cLiefma := Space(8)
//LOCAL hAccounts
LOCAL aBookings
LOCAL nTotal
LOCAL getlist := {}
LOCAL hPA := {=>} ,hPos
LOCAL cLang

IF ! LX_Start()
   Alert("Kein Lexware")
   RETURN
ENDIF
NetUSe("engkund","ku")
NetUse("fibu","fibu")


Head("Zahlungsavis drucken")

hPA["NPERSON"] := 0
hPA["DDATUM"] := Date()

@ 01,00 SAY "Lieferant" GET cLiefma  PICTURE "@!K" VALID {||
   LOCAL lR 
   IF Empty(cLiefma)
      //RETURN .T.
   ENDIF
   lR := ku->(Check(cLiefma+"L","ku->Name1",1,20))
   nKonto := 0
   //getlist[2]:Display()   
   RETURN lR
}
//@ 02,00 SAY "Kreditor " GET nKonto PICTURE "999999" WHEN Empty(cLiefma) VALID nKonto $ hAccounts
@ 02,00 SAY "Datum    " GET hPA:dDatum
ATail(getlist):postBlock := {||
   @ 10,00 CLEAR
   aBookings := __GetBookings(nKonto,hPa:dDatum,@nTotal)
   FOR EACH hPos IN aBookings
      @ 09+hPos:__enumIndex(),00 SAY hPos:cInvnr
      @ 09+hPos:__enumIndex(),50 SAY hPos:nBetrag
   NEXT
   RETURN .T.
}

@ 03,00 SAY t("Person")
@ 03,10 GET hPA:nPerson CONTACTLIST

@ 09,00 SAY "Rechnung"
@ 09,50 SAY "Summe"
READ

IF LastKey() == 27
   RETURN
ENDIF

//cLang := IF(nKonto!=0,ku->Language,"E")
cLang := "E"

IF ! Select("frm") == 0
  frm->(dbCloseArea())
ENDIF
NetUse("paform","frm")
LOCATE FOR frm->language == cLang
IF Select("tr") != 0
   tr->(dbCloseArea())
ENDIF
NetUse("patrans","tr")


frm->(PrintHead(,,,,,"Avis_"+DtoS(hPA:dDatum)+"_"+IF(nKonto!=0,LTrim(Str(nKonto)),ku->Kunde),hPA:nPerson,"remadv",cLang,{=>},hPA ))

//oPrinter := getCurrentPrinterObject()
//oPdf := oPrinter:Data

/*fibu->(dbSeek( Str(ku->Nummer,6) ))

hPA["NTOTAL"] := 0
hPA["POS"] := {=>}
DO WHILE fibu->Adresse == ku->Nummer
   aBookings := LX_GetBookingsOnDate(fibu->Konto,1591,hPA:dDatum)
   nTotal := 0
   FOR EACH hBooking IN aBookings
      hPA:Pos["CINVNR"] := StrTran(hBooking:Text,"Rechnung","")
      IF AT("#",hPA:Pos:cInvNr)  != 0
         hPA:Pos:cInvNr := Trim(SubStr(hPA:Pos:cInvNr,1,AT("#",hPA:Pos:cInvNr)-1))
      ENDIF
      hPA:Pos["NBETRAG"] := hBooking:Netto+hBooking:Ust
      frm->(PrintBody())
      oPrinter:oObject:nTotal += hBooking:Netto+hBooking:Ust
   NEXT
   fibu->(dbSkip())
ENDDO*/

hPA["NTOTAL"] := nTotal
FOR EACH hPos IN aBookings
   hPA["POS"] := hPos
   frm->(PrintBody())
NEXT


frm->(PrintFoot())

CopyPrint()

tr->(dbCloseArea())
frm->(dbCloseArea())

STATIC FUNCTION __GetBookings(nKonto,dDatum,nTotal)
   LOCAL aPos := {},hData
   LOCAL hBooking,aKonten := {}
   LOCAL aBookings,nX
   nTotal := 0
   IF nKonto != 0
      aKonten := {nKonto}
   ELSE
      fibu->(dbSeek( Str(ku->Nummer,6) ))
      DO WHILE fibu->Adresse == ku->Nummer
         Aadd(aKonten,fibu->Konto)
         fibu->(dbSkip())
      ENDDO
   ENDIF
   FOR EACH nKonto IN aKonten
      FOR nX := 1 TO 2
         aBookings := LX_GetBookingsOnDate(IF(nX==1,nKonto,1591),IF(nX==1,1591,nKonto),dDatum)
         FOR EACH hBooking IN aBookings
            hData := {=>}
            hData["CINVNR"] := StrTran(StrTran(hBooking:Text,"Rechnung",""),"Gutschrift","")
            IF AT("#",hData:cInvNr)  != 0
               hData:cInvNr := Trim(SubStr(hData:cInvNr,1,AT("#",hData:cInvNr)-1))
            ENDIF
            hData["NBETRAG"] := IF(nX==2,-1,1)*(hBooking:Netto+hBooking:Ust)
            Aadd(aPos,hData)
            nTotal += hData["NBETRAG"]
         NEXT 
      NEXT    
   NEXT
RETURN aPos

