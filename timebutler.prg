
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

   NetUse("buyer","buy")

   IF Empty(tUpd) .OR. tUpd+30/24/60 <= DateTime()  //only update every 30min
      aList := {}
      aAbsences := oAPI:Execute("absences")

      IF oWidget == NIL
         Alert(ValToPrg(aAbsences))
      ENDIF

      IF ValType(aAbsences) != "A"
         oWidget:WriteAt(00,00,"Fehler bei der Verbindung zu timebutler")
         oWidget:WriteAt(01,00,aAbsences)
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
      oWidget:WriteAt(01,01,"Keine")      
   ELSE
      oWidget:WriteAt(00,00,"Mitarbeiter")
      oWidget:WriteAt(00,21,"Datum")
      oWidget:WriteAt(00,41,"Abwesenheit")

      FOR nR := 1 TO Min(Len(aList),oWidget:nBottom)
         oWidget:WriteAt(nR,00, Pad(aList[nR]["name"],20) )
         
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
         oWidget:WriteAt(nR,21, Pad(cDate,19) )  
         
         IF HHasKey(hAbsenceTypes,aList[nR]["Type"])
            oWidget:WriteAt(nR,41, Pad(hAbsenceTypes[aList[nR]["Type"]],20) )
         ELSEIF Tr_Getini(28) == 9
            oWidget:WriteAt(nR,41, Pad(aList[nR]["Type"],20) )
         ENDIF
      NEXT
   ENDIF
   
RETURN

#include "x:\run\timebutlerapi.prg"
