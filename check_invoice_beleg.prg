#define LX_CAT_KREDITOR         256
#include 'inkey.ch'
PROCEDURE RUN_Check_Invoice_Beleg
LOCAL aCreditors,nCreditor,aBookings,aBooking
LOCAL aRegex,lError
LOCAL dUntil := Date()
LOCAL oBrowse,nLast,aStorno := {},aIDS :={}
LOCAL getlist := {}
LOCAL oPDF
LOCAL nX,aSplits
LOCAL aEditList := {},nY
//Alte Dauerbelege (ohne Index)
LOCAL aAltDauer := {;  
   {"KONTO"=>70002,"NETTO"=>2600},; //Steve im Vertragsordner
   {"KONTO"=>70002,"NETTO"=>4165},; //Steve im Vertragsordner
   {"KONTO"=>71995,"NETTO"=>340.80},; //Auto Samuel
   {"KONTO"=>70402,"NETTO"=>121.49},; //Leasing Prfmaschine
   {"KONTO"=>74021,"NETTO"=>448.70},;
   {"KONTO"=>70309,"NETTO"=>419.33},; //EWS - Stom Abschlag
   {"KONTO"=>70842,"NETTO"=>432.90},;
   {"KONTO"=>70842,"NETTO"=>856.73},;
   {"KONTO"=>70842,"NETTO"=>751.86};
}
LOCAL hErrors := {"B"=>"Kein Index","M"=>"Buchung fehlt","F"=>"Datei fehlt","K"=>"Falsches Kto.","N"=>"Index nicht gefunden","S"=>"Beleg storniert","I"=>"Index fehlt"}

MEMVAR c_three

Head(t("Belege auf Vollständigkeit prüfen"))

NetUSe("reb","reb")
NetUse("rebprot","rebp")
NetUse("fibu","fibu")


@ 01,00 SAY "Bis Belegdatum" GET dUntil VALID dUntil <= Date()
READ

If LastKey() == 27
   RETURN
ENDIF

TxtBox("Fehler werden gesucht...")

LX_Start()
aCreditors := LX_GetAccountsInCat(LX_CAT_KREDITOR,.F.)

reb->(dbSetOrder( 1 ))

/*StartPrint(,,"PDF")
oPdf := GetCurrentPrinterObject():Data

oPdf:SetFont("COURIER")
oPdf:NewPage("A4","L")
oPdf:AtSay("Belegprüfung bis "+DToC(dUntil))
oPdf:NewLine()
oPdf:AtSay(Pad("Fehler",20)+" "+"Belegd. "+" "+"Soll  "+" "+"Haben "+" "+Pad("Netto",9)+" "+"Buchungstext")
*/

reb->(dbGoTop())
nLast := reb->ID
reb->(dbSkip())
DO WHILE ! reb->(EOF()) .AND. reb->ID <= Val(Right(Str(Year(dUntil),4),2)+Replicate("9",7))
   IF Left(LTrim(Str(nLast)),3) == Left(LTrim(Str(reb->ID)),3) //if it is not a change of year or type      
      IF reb->ID != nLast+1
        /* oPdf:NewLine()
         oPdf:Atsay(Pad("ID fehlt",20)+" "+LTrim(Str(nLast+1)))  */ 
         Aadd(aEditList,{"ERROR" => "I", "ID"=>reb->ID})      
      ENDIF
   ENDIF
   IF ! File("Y:\Archive\Eingangsrechnungen\20"+Left(LTrim(Str(reb->ID)),2)+"\\ER"+LTrim(Str(reb->ID))+"*.*" ) .AND. ! File("Y:\Archive\Eingangsrechnungen\20"+Str(Val(Left(LTrim(Str(reb->ID)),2))+1,2)+"\\ER"+LTrim(Str(reb->ID))+"*.*" )
      //oPdf:NewLine()
      //oPdf:Atsay(Pad("Datei fehlt",20)+" "+LTrim(Str(reb->ID)))
      Aadd(aEditList,{"ERROR" => "F", "ID"=>reb->ID})
   ENDIF      
   nLast := reb->ID
   reb->(dbSkip())
ENDDO


FOR EACH nCreditor IN aCreditors
   IF nCreditor < 80000 //ab 80000 sind Krankenkassen
      //aDel := {}
      aBookings := LX_GetBookingsOnAccount(nCreditor,Year(dUntil),.F.,.T.) //alle Haben Bchungen
      //zuerst alle stornieren Buchungen l”schen
      /*FOR nB := 1 TO Len( aBookings )
         IF ! nB $ aDel .AND. (nX := AScan(aBookings,{|x| x["NETTO"]*-1 == aBookings[nB]["NETTO"]*-1 } )) != 0
            Aadd(aDel,nB)
            Aadd(aDel,nX)
         ENDIF
      NEXT
      FOR nX := 1 TO Len(aDel)
         HB_ADel(aBookings,aDel[nX]-nX*2+2,.T.)
         HB_ADel(aBookings,aDel[nX]-nX*2+1,.T.)
      NEXT*/

      rebp->(dbSetOrder( 2 ))
      FOR EACH aBooking IN aBookings
         IF AT("<STORNO>",Upper(aBooking["TEXT"])) == 1 .OR. aBooking["NETTO"] < 0
            aRegex := HB_Regex("#ER([0-9]{9})(?![0-9])",aBooking["TEXT"],.F.)
            IF Len(aRegex) > 0   
               //aRegex[2]
               Aadd(aStorno,{StrTran(Upper(aBooking["TEXT"]),"<STORNO>",""),aBooking["NETTO"]*1})               
            ENDIF
         ENDIF
      NEXT
      FOR EACH aBooking IN aBookings
         lError := .F.
         IF aBooking["DATUM"] <= dUntil .AND. aBooking["SOLL"] < 9000 .AND. aBooking["SOLL"] != 1591 .AND. (aBooking["SOLL"] > 1299 .OR. aBooking["SOLL"] < 1200)
            IF aBooking["SOLL"] == 0 //Splitbuchung
               aSplits := LX_GetSplitBooking(aBooking["NR"],aBooking["JAHR"],"S")
               IF AScan(aSplits,{|x| x["KONTO"] >= 9000 .OR. (x["KONTO"] > 1200 .AND. x["KONTO"] < 1299) .OR. x["KONTO"] == 1591 }) != 0
                  LOOP
               ENDIF
            ENDIF
            aRegex := HB_Regex("#ER([0-9]{9})(?![0-9])",aBooking["TEXT"],.F.)
            IF AT("<STORNO>",Upper(aBooking["TEXT"])) == 1 .OR. aBooking["NETTO"] < 0 .OR. aBooking["STATUS"] == 9  //Status 9 = storniert
            ELSEIF AT("UMBUCHUNG WŽHRUNGSDIFFERENZ",StrTran(Upper(aBooking["TEXT"]),"„","Ž")) != 0
            ELSEIF Len(aRegex) > 0 //Belegnummer enthalten    
               Aadd(aIDs,aRegex[2])           
               IF (nX := AScan(aStorno,{|x| /*x[1]== aRegex[2]*/ AllTrim(x[1]) == Alltrim(aBooking["TEXT"]) .AND. Abs(x[2]) == Abs(aBooking["NETTO"]) })) != 0                  
                  HB_ADel(aStorno,nX,.T.)
                  LOOP
               ENDIF
               IF ! reb->(dbSeek( aRegex[2] )) //beleg in der DB nicht gefunden
                  //cErr := "Beleg nicht gefunden"
                  Aadd(aEditList,aBooking)
                  ATail(aEditList)["ERROR"] := "N"                  
                  lError := .T.
               ELSEIF rebp->(dbSeek( aRegex[2]+"STORN" ))  //wurde der Beleg storniert?
                  //cErr := "Beleg storniert"
                  Aadd(aEditList,aBooking)
                  ATail(aEditList)["ERROR"] := "S"
                  lError := .T.
               ELSEIF reb->Konto != 0 
                  IF reb->Konto != nCreditor
                     //cErr := "Falsches Kto.("+LTrim(Str(reb->Konto))+")"
                     Aadd(aEditList,aBooking)
                     ATail(aEditList)["ERROR"] := "K"
                     ATail(aEditList)["KONTO_REB"] := reb->Konto
                     lError := .T.                  
                  ENDIF
               ELSE
                  lError := .T.
                  //cErr := "Falsches Konto"
                  fibu->(dbSeek( Str(reb->Liefnr,6) ))
                  DO WHILE lError .AND. fibu->Adresse == reb->Liefnr .AND. ! fibu->(EOF())
                     IF fibu->Konto == nCreditor .OR. fibu->Curkonto == nCreditor
                        lError := .F.
                     ENDIF
                     fibu->(dbSkip())
                  ENDDO
                  IF lError
                     Aadd(aEditList,aBooking)
                     ATail(aEditList)["ERROR"] := "K"
                  ENDIF
               ENDIF         
            ELSEIF AScan(aAltDauer,{|x| x["KONTO"] == nCreditor .AND. x["NETTO"] == aBooking["NETTO"] }) != 0 //Alter Dauerbeleg ohne Index
               
            ELSEIF nCreditor >= 80000 .AND. HB_RegexMatch("BNW\s*(0?[1-"+IF(Month(dUntil)>9,"9",LTrim(Str(Month(dUntil))))+IF(Month(dUntil)>9,"|1[0-"+Right(LTrim(Str(Month(dUntil))),1),"")+"])\s*\/\s*(20)?"+Right(Str(Year(dUntil),4),2),aBooking["TEXT"]) //Beitragsnachweis Krankenkasse
            ELSEIF aBooking["NETTO"] > 0 .AND. aBooking["NETTO"] < 1 //Buchungen unter 1? ignorieren
            ELSE //enth„lt kein beleg
               //cErr := "Keine Belegnummer"
               Aadd(aEditList,aBooking)
               ATail(aEditList)["ERROR"] := "B"
               lError := .T.
            ENDIF
         ENDIF
         IF lError
            //oPdf:NewLine()
            //oPdf:Atsay(Pad(cErr,20)+" "+DtoC(aBooking["DATUM"])+" "+Str(aBooking["SOLL"],6)+" "+Str(aBooking["HABEN"],6)+" "+Str(aBooking["NETTO"],9,2)+" "+Pad(HB_OemToAnsi(aBooking["TEXT"]),100))
         ENDIF
      NEXT
   ENDIF
NEXT

reb->(dbSetFilter({|| reb->Status == 9},"status == 9"))
rebp->(dbSetFilter({|| Trim(rebp->Type) == "STORN" },'Trim(Type) == "STORN"'))
      
reb->(dbSeek( Right(Str(Year(dUntil),4),2)+Replicate("0",7) ,.T. ))
DO WHILE ! reb->(EOF()) .AND. reb->ID < Val(Right(Str(Year(dUntil),4),2)+Replicate("9",7))
   IF AScan(aIDs,Str(reb->ID,9)) == 0 .AND. ! rebp->(dbSeek( Str(reb->ID,9), .T. )) .AND. Len(LX_GetBookingsForID("ER"+Str(reb->ID,9))) == 0
      //oPdf:NewLine()
      //oPdf:Atsay(Pad("Buchung fehlt",20)+" "+LTrim(Str(reb->ID)))        
      Aadd(aEditList,{"ERROR" => "M", "ID"=>reb->ID})
   ENDIF
   reb->(dbSkip())
ENDDO
reb->(dbClearFilter())
rebp->(dbClearFilter())

TxtClear()

@ MaxRow(),00 SAY Pad(">ENTER< Index bearbeiten - >ENTF< - Eintrag aus Liste l”schen - >STRG+P< Drucken",MaxCol()) COLOR c_three //
@ MaxRow()-1,00 SAY Replicate(Chr(196),MaxCol())
@ MaxRow()-4,00 SAY Replicate(Chr(196),MaxCol())
@ MaxRow()-3,00 SAY "Soll  "+" "+"Haben "+" "+Pad("Netto",9)
oBrowse := TaBrowse():New(02,00,MaxRow()-5,MaxCol())
oBrowse:lBox := .F.
oBrowse:NewColumn(Pad(Pad("Fehler",20)+" "+Pad("Datum",8),MaxCol()-2),{|| 
   LOCAL hD := oBrowse:CurrentDataRow()
   LOCAL cRow
   IF hD != NIL
      IF ! HHasKey(hErrors,hD["ERROR"])      
         Alert(hD["ERROR"])
      ENDIF
      cRow := Pad(hErrors[hD["ERROR"]]+IF(hD["ERROR"]=="K".AND.HHasKey(hD,"KONTO_REB"),"("+LTrim(Str(hD["KONTO_REB"]))+")",""),20)+" "
      IF HHasKey(hD,"STATUS") 
         //cRow += "("+LTrim(Str(hD["STATUS"]))+")"
      ENDIF
      IF hD["ERROR"] $ "NSBK"         
         cRow += DtoC(hD["DATUM"])+" "+Pad(hD["TEXT"],MaxCol()-20-1-8-1-2)
      ELSEIF HHasKey(hD,"ID")         
         cRow += LTrim(Str(hD["ID"]))
      ENDIF     
      
   ELSE
      cRow := ""
   ENDIF
   RETURN Pad(cRow,MaxCol()-2)
})

oBrowse:bAnyFun := {||
   LOCAL aBooking := oBrowse:CurrentDataRow()
   IF aBooking["ERROR"] $ "NSBK"
      @ MaxRow()-2,00 SAY Str(aBooking["SOLL"],6)+" "+Str(aBooking["HABEN"],6)+" "+Str(aBooking["NETTO"],9,2)
   ELSE
      @ MaxRow()-2,00 CLEAR TO MaxRow()-2,MaxCol()
   ENDIF
   RETURN .T.
}

oBrowse:AddKey(27,{|| .F. })
oBrowse:AddKey(13,{|| 
   LOCAL nID := 0
   LOCAL aBooking := oBrowse:CurrentDataRow()
   LOCAL cText
   IF aBooking["ERROR"] $ "BS"
      nY := Val(Right(Str(Year(aBooking["DATUM"]),4),2))
      aRegex := HB_Regex("#((ER)?)([0-9]{9})",aBooking["TEXT"],.F.)
      IF Len(aRegex) >= 2
         nID := Val(aRegex[2])
      ENDIF   
      nID := GetBox(nId,"Index","999999999",,,,{|nID| HB_RegexMatch("("+Str(nY-1,2)+"|"+Str(nY)+"|"+Str(nY+1,2)+")[01][0-9]{6}",Str(nId,9)) .AND. Val(Right(Str(nId,9),6)) > 0 })

      //cText := Trim(HB_RegexReplace("#[1-9]{2}[0,1][0-9]{5}[1-9]{1}",aBooking["TEXT"],"")) //replace any old ID
      cText := Trim(HB_RegexReplace("#(ER)?[0-9]{1,9}",aBooking["TEXT"],"")) //replace any old ID
      cText := cText+" #ER"+LTrim(Str(nId,9))  
      IF ! LastKey() == 27 .AND. Tr_MsgBox({"Folgenden Text setzen?",cText},,{"Nein","Ja"}) == 2
         LX_UpdateText(aBooking["NR"],Year(dUntil),aBooking["STAPEL"],cText)
         HB_ADel(aEditList,oBrowse:CurrentRow(),.T.)
      ENDIF
   ENDIF
   RETURN .T.
})
oBrowse:AddKey(K_DEL,{|| HB_ADel(aEditList,oBrowse:CurrentRow(),.T.) })
oBrowse:AddKey(K_CTRL_P,{||
   LOCAL aEnv := SaveEnv()
   LOCAL aBooking
   StartPrint(,,"PDF")
   oPdf := GetCurrentPrinterObject():Data

   oPdf:SetFont("COURIER")
   oPdf:NewPage("A4","L")
   oPdf:AtSay("Belegprüfung bis "+DToC(dUntil))
   oPdf:NewLine()
   oPdf:AtSay(Pad("Fehler",20)+" "+"Belegd. "+" "+"Soll  "+" "+"Haben "+" "+Pad("Netto",9)+" "+"Buchungstext")

   FOR EACH aBooking IN aEditList
      oPdf:NewLine()
      oPdf:Atsay(Pad(hErrors[aBooking["ERROR"]]+IF(aBooking["ERROR"]=="K".AND.HHasKey(aBooking,"KONTO_REB"),"("+LTrim(Str(aBooking["KONTO_REB"]))+")",""),20)+" ")
      IF aBooking["ERROR"] $ "NSB"
         oPdf:Atsay(DtoC(aBooking["DATUM"])+" "+Str(aBooking["SOLL"],6)+" "+Str(aBooking["HABEN"],6)+" "+Str(aBooking["NETTO"],9,2)+" "+Pad(HB_OemToAnsi(aBooking["TEXT"]),100))         
      ELSE
         oPdf:AtSay(Str(aBooking["ID"]))
      ENDIF
   NEXT
   CopyPrint()            

   RestEnv(aEnv,.T.)
   RETURN .T.
})

oBrowse:aData := aEditList
oBrowse:EventLoop()

/*cText := Trim(HB_RegexReplace("#[1-9]{2}[0,1][0-9]{5}[1-9]{1}",aBookings[nX]["TEXT"],"")) //replace any old ID
cText := cText+" #ER"+LTrim(Str(nId,9))
//? cText
#ifndef TEST
LX_UpdateText(aBookings[nX]["NR"],nYear,aBookings[nX]["STAPEL"],cText)*/

