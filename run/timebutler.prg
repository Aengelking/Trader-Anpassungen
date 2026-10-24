
#include 'inkey.ch'

STATIC aList := {}
STATIC tUpd  

PROC Run_TimeButler(oWidget)
   LOCAL oAPI := TimeButlerAPI():New()
   LOCAL aAbsences,hAbsence
   //LOCAL aList := {}
   LOCAL hAbsenceTypes := oAPI:GetAbsenceTypes()
   LOCAL dFrom := Date()      
   LOCAL dTo := dFrom   
   LOCAL cDate,nR
   LOCAL lFullDisplay := .F.
   LOCAL cScr

   NetUse("buyer","buy")

   IF oWidget == NIL
      lFullDisplay := .T.
   ENDIF

   IF Empty(tUpd) .OR. tUpd+30/24/60 <= DateTime()  //only update every 30min
      aList := {}
      aAbsences := oAPI:Execute("absences")


      IF ValType(aAbsences) != "A"
         IF lFullDisplay
            Tr_MsgBox("Fehler bei der Verbindung zu timebutler")
            
         ELSE            
            oWidget:WriteAt(00,00,"Fehler bei der Verbindung zu timebutler")
            oWidget:WriteAt(01,00,aAbsences)
         ENDIF
         RETURN
      ENDIF
      FOR EACH hAbsence IN aAbsences            
         IF Len(hAbsence) > 1 .AND.;
            ((dFrom <= hAbsence["From"] .AND. hAbsence["From"] <= dTo) .OR. ;  //begins before and does not end before
            (dFrom >= hAbsence["From"] .AND. dFrom <= hAbsence["To"])) //begins within         
            //hAbsence["From"] <= dFrom  .AND. hAbsence["To"] >= dFrom
            IF ! HHasKey(hAbsence,"Employee number") .OR. ValType(hAbsence["Employee number"]) != "N"
               hAbsence["name"] := "Benutzer "+LTrim(Str(hAbsence["User ID"]))                           
            ELSE
               buy->(dbGoTo( hAbsence["Employee number"] ))            
               IF ! buy->Aktive
                  LOOP  //ignore this entry
               ENDIF
               hAbsence["name"] := Left(buy->Buyer,AT(" ",buy->Buyer)-1)               
            ENDIF
            Aadd(aList,hAbsence)
         ENDIF
      NEXT
      tUpd := DateTime()
   ENDIF

  
   IF Len(aList) == 0
      IF lFullDisplay      
         RETURN
      ENDIF
      oWidget:WriteAt(01,01,"Keine")      
   ELSE
      IF ! lFullDisplay            
         oWidget:WriteAt(00,00,"Mitarbeiter")
         oWidget:WriteAt(00,21,"Datum")
         oWidget:WriteAt(00,41,"Abwesenheit")
      ELSE       
         cScr := SaveScreen()
         SetColor(c_one)
         @ 03,00 CLEAR TO MaxRow(),61  
         @ 03,00 TO MaxRow(),00  
         @ 03,61 TO MaxRow(),61  
         //ascii box bottom cornerers and text within line                  
         @ MaxRow(),00 SAY Chr(192)+PadC(" Mit >ESC< schlieáen ",60,Chr(196))+Chr(217)    
        
      ENDIF

      FOR nR := 1 TO Min(Len(aList),IF(lFullDisplay,MaxRow()-3,oWidget:nBottom))
         IF lFullDisplay
            @ nR+2,01 SAY aList[nR]["name"]
         ELSE
            oWidget:WriteAt(nR,00, Pad(aList[nR]["name"],20) )
         ENDIF
         
         cDate := DtoC(aList[nR]["From"])         
         IF aList[nR]["From"] != aList[nR]["To"]
            cDate += "-"+DtoC(aList[nR]["To"])
         ELSEIF aList[nR]["Half a day"]
            IF aList[nR]["Morning"]
               cDate += " Vormittag"
            ELSE
               cDate += " Nachmittag"
            ENDIF      
         ENDIF
         IF lFullDisplay
            @ nR+2,22 SAY cDate
         ELSE
            oWidget:WriteAt(nR,21, Pad(cDate,19) )  
         ENDIF
         
         IF HHasKey(hAbsenceTypes,aList[nR]["Type"])
            IF lFullDisplay
               @ nR+2,42 SAY hAbsenceTypes[aList[nR]["Type"]]
            ELSE
               oWidget:WriteAt(nR,41, Pad(hAbsenceTypes[aList[nR]["Type"]],20) )
            ENDIF
         ELSEIF Tr_Getini(28) == 9
            IF lFullDisplay
               @ nR+2,42 SAY aList[nR]["Type"]
            ELSE
               oWidget:WriteAt(nR,41, Pad(aList[nR]["Type"],20) )
            ENDIF
         ENDIF
      NEXT
      IF lFullDisplay
         Sinkey(0)
         RestScreen(,,,,cScr)
      ENDIF
   ENDIF   
   
RETURN

#include "x:\run\timebutlerapi.prg"
