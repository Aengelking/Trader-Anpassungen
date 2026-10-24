PARAMETERS cFrom,cTo

LOCAL oHttp,cUrl,cData,hData

cUrl := "http://www.mapquestapi.com/directions/v2/route?key=AKVgjcqBjZDVBw8E3GtA9FEudSbFYMTB"
cUrl += "&from=Tuningen,78609"  //Lancaster,PA
cUrl += "&to=Schwenningen,78054" //York,PA&callback=renderNarrative
cUrl += "&unit=k"

oHttp := TIpClientHttp():new( cUrl )
oHttp:open()

//oHttp:hFields["X-Requested-With"]:="XMLHttpRequest"

cData := oHttp:readAll()
   Alert(cData)
HB_JsonDeCode(cData,@hData)

IF HHasKey(hData,"info") .AND. HHasKey(hData["info"],"statuscode") .AND. hData["info"]["statuscode"] != 0
   IF HHasKey(hData["info"],"messages")
      cAlert := ""
      AEval(hData["info"]["messages"],{|x|
         IF !Empty(cAlert)
            cAlert += ";"
         ENDIF
         cAlert += x
      })
      Alert(cAlert)
   ENDIF
   RETURN -1
ENDIF
Alert(Str(hData["route"]["distance"]))

RETURN hData["route"]["distance"]
