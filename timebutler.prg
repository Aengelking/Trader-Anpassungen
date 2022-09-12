#include 'hbclass.ch'
#include 'inkey.ch'

PROC Run_TimeButler(oWidget)
   LOCAL oAPI := TimeButlerAPI():New()
   LOCAL aAbsences,hAbsence
   LOCAL aList := {}
   LOCAL hTypes := {=>}
   LOCAL oBrowse
   LOCAL hAbsenceTypes := {"Vacation"=>"Urlaub","Sickness"=>"Krank","Training school"=>"Berufsschule","Child ill"=>"Kind krank","Child ill w/o payment"=>"Kind krank","Home office"=>"Homeoffice",;
                           "Warehouse"=>"Lager","Further training"=>"Weiterbildung","Fair"=>"Messe","Business trip"=>"Dienstreise"}
   LOCAL dFrom := Date()      
   LOCAL dTo := dFrom   
   LOCAL cDate,nR

   NetUse("buyer","buy")

   aAbsences := oAPI:Execute("absences")

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
            IF hAbsence["User ID"] == 374365
               hAbsence["name"] := "Bob v. Knobloch"               
            ELSE
               hAbsence["name"] := "Benutzer "+LTrim(Str(hAbsence["User ID"]))               
            ENDIF
         ELSE
            buy->(dbGoTo( hAbsence["Employee number"] ))            
            hAbsence["name"] := buy->Buyer            
         ENDIF
         Aadd(aList,hAbsence)
      ENDIF
   NEXT
   
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

CLASS TimeButlerAPI FROM RestAPI
   METHOD Execute

   DATA cApiKey INIT ""
   DATA cBaseUrl INIT "https://timebutler.de/api/v1/"  
   DATA cKeyName INIT "TIMEBUTLER"
   

ENDCLASS

METHOD Execute(cUrl,cMethod,hData)
   LOCAL cData,aData
   LOCAL aRowData,hRowData,aMatches

   Default(@cMethod,"POST") //would need to be configured
   Default(@hData,{=>})

   //aHeader := {"X-API-KEY: "+IF(lAsUsr .AND. ! Empty(::cUsrToken),::cUsrToken,::cApiKey)}
   hData["auth"] := "$PASSWORD$" //::cApiKey   

   cData := ::Super:Execute(cUrl,cMethod,hData)

   IF cData != NIL
      aData := HB_ATokens(StrTran(cData,Chr(13)),Chr(10)) //split into rows

      DO WHILE Empty(aData[1]) //remove blank lines
         HB_ADel(aData,1,.T.)
      ENDDO

      //split rows into fields
      AEval(aData,{|xRow,nX| 
         aRowData := HB_ATokens(xRow,";")
         IF nX == 1         
            aData[nX] := aRowData //save the header for later use
         ELSE  //convert row data into hash with field names from row one
            hRowData := {=>}
            AEval(aData[1],{|cField,nF| 
               IF nF <= Len(aRowData)
                  IF aRowData[nF] == "false"
                     hRowData[cField] := .F.
                  ELSEIF aRowData[nF] == "true"
                     hRowData[cField] := .T.
                  ELSEIF HB_RegexMatch("^[0-9\.]+$",aRowData[nF]) //number
                     hRowData[cField] := Val(aRowData[nF])
                  ELSEIF Len(aMatches := HB_Regex("^([0-9]{2})/([0-9]{2})/([0-9]{4})",aRowData[nF])) > 0 //date
                     hRowData[cField] := StoD(aMatches[4]+aMatches[3]+aMatches[1])
                  ELSE
                     hRowData[cField] := aRowData[nF] 
                  ENDIF
               ENDIF
               RETURN .T.
            })
            aData[nX] := hRowData
         ENDIF
         RETURN .T.
      }) 

      HB_ADel(aData,1,.T.) //remove the header
   ENDIF
RETURN aData
