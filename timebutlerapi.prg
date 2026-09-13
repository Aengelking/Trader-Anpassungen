#include 'hbclass.ch'
CLASS TimeButlerAPI FROM RestAPI
   METHOD Execute
   METHOD GetAbsenceTypes

   DATA cApiKey INIT ""
   DATA cBaseUrl INIT "https://timebutler.de/api/v1/"  
   DATA cKeyName INIT "TIMEBUTLER"
   

ENDCLASS

METHOD Execute(cUrl,cMethod,hData)
   LOCAL cData,aData,aHeader
   LOCAL aRowData,hRowData,aMatches

   Default(@cMethod,"POST") //would need to be configured
   Default(@hData,{=>})

   hData["auth"] := "$PASSWORD$"

   cData := ::Super:Execute(cUrl,cMethod,hData)

   IF cData != NIL
      aData := HB_ATokens(StrTran(cData,Chr(13)),Chr(10)) //split into rows

      DO WHILE Empty(aData[1]) //remove blank lines
         HB_ADel(aData,1,.T.)
      ENDDO

      //split rows into fields
      AEval(aData,{|xRow,nX| 
         aRowData := HB_ATokens(xRow,";",.T.,.T.)
         IF nX == 1         
            aData[1] := aRowData //save the header for later use
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

METHOD GetAbsenceTypes()
RETURN {"Vacation"=>"Urlaub","Sickness"=>"Krank","Training school"=>"Berufsschule",;
   "Child ill"=>"Kind krank","Child ill w/o payment"=>"Kind krank","Home office"=>"Homeoffice",;
   "Warehouse"=>"Lager","Further training"=>"Weiterbildung","Fair"=>"Messe",;
   "Business trip"=>"Dienstreise","Parental leave"=>"Elternzeit"}
