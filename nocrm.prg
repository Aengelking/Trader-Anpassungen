#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'
#include 'hbclass.ch'
#include 'inkey.ch'
#include 'set.ch'

#define CRLF Chr(13)+Chr(10)

FUNCTION NOCRM_Edit()
   LOCAL nAngNr := 0
   LOCAL getlist := {}

   NetUse("angebot","ang")
   NetUse("engkund","ku")
   NetUse("buyer","buy")

   Head("Wiedervorlage Angebot bearbeiten")

   @ 01,00 SAY "Angebot" GET nAngnr VALID ang->(dbSeek( Str(nAngnr,6) )) PICTURE "999999"
   READ

   IF LastKey() == 27
      RETURN .F.
   ENDIF

   noCRM_Interface(.F.)
RETURN NIL

FUNCTION noCRM_Interface(lComment)
   LOCAL nLeadId
   LOCAL oRec
   LOCAL hLead,aValues
   LOCAL oNoCrm := NoCrmApi():New() //RestApi():New("https://engelking.nocrm.io/api/v2/","ff10f687005e643fc6a53f01cd06a646a5440986af412916")
   LOCAL nX,lAdded
   LOCAL nActivity
   LOCAL nPipeline,aPipelines
   LOCAL nStep
   LOCAL cContent,aContact
   LOCAL bExit
   LOCAL dRemindDate := Date(),cYear,dHJ
   LOCAL hLeadData := {=>}
   LOCAL getList := {}
   LOCAL cDescription
   LOCAL cUsrEmail
   LOCAL nRemindDays := 0
   LOCAL nMinValue := GetValue("NOCRM_MINVALUE",500,"Wert ab dem eine Wiedervorlage Pflicht ist (0=aus)")
   LOCAL oExtra,nWeekDay := 1,bCheckWeekday

   Default(@lComment,.T.)

   Head("Wiedervorlage Angebot")

   NetUse("nocrm","nocrm")

   buy->(dbGoto( ang->Buyer ))
   cUsrEmail := buy->Email
   //cUsrEmail := "amos.engelking@engelking.de"

   //Check if connection is working
   IF ! oNoCrm:Connect()
      TR_MsgBox("Connection to nocrm.io failed")
      RETURN NIL
   ENDIF
   
   //Basic Setup

   //get activity Id
   nActivity := oNoCrm:GetActivityId( GetValue("NOCRM_ACTIVITY","Angebot","Name der AktivitÑt fÅr Angebote") )

   //get pipeline id
   nPipeLine := oNoCrm:GetPipeLineId( oNoCrm:GetStdPipeLineName(), @aPipelines)

   aValues := EnquiryAddUp(ang->Angnr,.T.)  
   
   IF nocrm->(dbSeek( Str(ang->Angnr,6) ))
      oRec := nocrm->(Record():New())
   ELSE
      oRec := nocrm->(Record():New(.T.))
      oRec:Angebot := ang->Angnr
   ENDIF   
 
   bExit := {||     
      IF nMinValue != 0 .AND. (aValues[2] >= nMinValue .OR. Tr_MsgBox("Erstellen der Wiedervorlage abbrechen",,{"Nein","Ja"}) != 2)
         RETURN .F.
      ENDIF
      RETURN .T.
   } 

   bCheckWeekday := {||
      LOCAL lAdded := .F.
      DO WHILE DoW(dReminddate) == 1 .OR. DoW(dRemindDate) == 7 .OR. IsFeiertag(dRemindDate,GetConfigValue("STATE"),.T.)  //Feiertag oder Wochenende
         dRemindDate++
         lAdded := .T.
      ENDDO
      IF lAdded
         nWeekDay    := DoW(dRemindDate)-1
      ENDIF
      RETURN lAdded
   }

   DO WHILE .T.

      @ 01,00 SAY "Angebotswert: "+LTrim(Transform(aValues[2],"9999999.99"))+IF(aValues[2]<nMinValue," (Wiedervorlage nicht verpflichtend)","")

      @ 22,00 SAY "Wiedervorlage in Werktagen" GET nRemindDays PICTURE "999" VALID {||
         IF nRemindDays <= 0
            RETURN .F.
         ENDIF
         dRemindDate := AddWorkingDays(Date(),nRemindDays,GetConfigValue("STATE"),.T.)
         nWeekDay    := DoW(dRemindDate)-1
         getlist[2]:Control:Display()
         getlist[3]:Display()
         RETURN .T.
      }
      @ 23,00 SAY "Wochentag" 
      @ 23,27,30,55 GET nWeekDay LISTBOX {"Montag","Dienstag","Mittwoch","Donnerstag","Freitag"} DROPDOWN VALID {||
         IF nWeekDay != DoW(dRemindDate)-1            
            dRemindDate += nWeekDay-DoW(dRemindDate)+1
            IF Eval(bCheckWeekday)
               getlist[2]:Control:Display()   
            ENDIF
            nRemindDays := CountWorkingDays(Date(),dRemindDate,GetConfigValue("STATE"),.T.)-1
            getlist[1]:Display()
            getlist[3]:Display()
         ENDIF
         RETURN .T.
      }

      @ 24,00 SAY "Wiedervorlage Datum       " GET dRemindDate VALID {||         
         IF dRemindDate > Date()
            lAdded := Eval(bCheckWeekday)
            getlist[3]:Display()
            nRemindDays := CountWorkingDays(Date(),dRemindDate,GetConfigValue("STATE"),.T.)-1
            getlist[1]:Display()
            nWeekDay    := DoW(dRemindDate)-1
            getlist[2]:Control:Display()
            IF ! LastKey() $ {K_UP,K_SH_TAB}
               IF nRemindDays > GetValue("NOCRM_REM_WARN",5,"Warnung wenn WV diesen Wert in Werktagen Åberschreitet") .AND.  Tr_MsgBox("Bist Du sicher, dass die Wiedervorlage erst so spÑt erfolgen soll?",,{"Nein","Ja"}) != 2
                  RETURN .F.
               ENDIF
            ENDIF
            RETURN ! lAdded
         ENDIF
         RETURN .F.
      }      


      //Choose a lead        
      nLeadId := onocrm:ChooseLead(03,00,20,60,oRec:Lead,.T.)   
      IF LastKey() == 27 .OR. nLeadId == 0
         IF ! Eval(bExit)
            getlist := {}
            LOOP
         ENDIF
         EXIT         
      ENDIF
      
      //go to the customer
      ku->(dbSeek( ang->Kundma+"K" ))      

      //get the extradata
      oExtra := ku->(ExtraData():New(ku->Nummer))

      IF nLeadId == -1         
         IF oExtra:noCRMWV == "ST"
            nRemindDays := GetValue("NOCRM_REM_DAYS",2,"Vorschlag Wiedervorlage in Werktagen")
            dRemindDate := AddWorkingDays(Date(),nRemindDays,GetConfigValue("STATE"),.T.)
         ELSE
            cYear := Str(Year(Date()),4)
            IF oExtra:noCRMWV == "VJ"
               dRemindDate := EoQ(Date())
            ELSE // "HJ"
               dHJ := StoD(cYear+"0630")
               IF Date() <= dHJ
                  dRemindDate := dHJ
               ELSE
                  dReminddate := EoY(Date())
               ENDIF
            ENDIF
            //if it is not a working day look for last working day in quarter or half year
            DO WHILE DoW(dReminddate) == 1 .OR. DoW(dRemindDate) == 7 .OR. IsFeiertag(dRemindDate,GetConfigValue("STATE"),.T.)  //Feiertag oder Wochenende
               dRemindDate++
               lAdded := .T.
            ENDDO
            nRemindDays := CountWorkingDays(Date(),dRemindDate,GetConfigValue("STATE"),.T.)-1
            nWeekDay    := DoW(dRemindDate)-1
         ENDIF
      ELSE
         hLead := oNoCRM:Execute("leads/"+Ltrim(Str(nLeadId)),"GET")      
         IF HHasKey(hLead,"remind_date") .AND. hLead["remind_date"] != NIL
            dRemindDate := noCRM_DateConv(hLead["remind_date"])
         ELSE
            dRemindDate := Date()
         ENDIF
         IF dRemindDate > Date()
            nRemindDays := CountWorkingDays(Date(),dRemindDate,GetConfigValue("STATE"),.T.)-1
         ELSE
            nRemindDays := 0
         ENDIF
         nWeekDay    := DoW(dRemindDate)-1
         IF ! Empty(hLead["pipeline"]) //if this lead has already been assigned to a pipeline we use this one and not the default one
            nX := AScan(aPipelines,{|x| x["name"] == hLead["pipeline"] })
            IF nX != 0
               nPipeline := aPipelines[nX]["id"]
            ENDIF
         ENDIF
      ENDIF

      getlist[2]:Control:Display()
      getlist[3]:Display()

      READ
      IF LastKey() == 27
         IF ! Eval(bExit)
            LOOP
         ENDIF
         EXIT         
      ENDIF

      IF nLeadId != -1 .AND. hLead["user_id"] == NIL //lead needs to be assigned
         oNoCRM:Execute("leads/"+Ltrim(Str(nLeadId))+"/assign","POST",{"user_id"=>cUsrEmail})         
      ENDIF

      //now get the step id in the pipeline
      nStep := oNoCRM:GetStepId( GetValue("NOCRM_STEP","Angebot","Phase in der Pipeline") ,nPipeLine)


      IF nLeadId == -1 .OR. hLead["remind_date"] == NIL .OR. dRemindDate != noCRM_DateConv(hLead["remind_date"]) .OR. hLead["status"] != "standby"
         hLeadData["remind_date"] := noCRM_DateConv(dRemindDate)
         hLeadData["status"] := "standby"         
      ENDIF
      IF nStep != 0  //if nStep is 0 we will leave it as it is, or on a new one not set it at all
         hLeadData["step"] := nStep //this is the step in the defined pipeline
      ENDIF

      IF nLeadId == -1 .OR. hLead["amount"] == NIL
         hLeadData["amount"] := aValues[2]      
      ENDIF

      
      

      aContact := GetContact(ang->Person)

      //create lead and/or save lead id
      IF nLeadId == -1                           
         cDescription := "Kunde (Matchcode): "+hb_strtoutf8(ku->Kunde)+CRLF
         cDescription += "Ansprechpartner: "+hb_strtoutf8(aContact["name"])+CRLF
         cDescription += "Telefon: "+hb_strtoutf8(aContact["fullphone"])+CRLF
         cDescription += "E-Mail: "+hb_strtoutf8(aContact["email"])+CRLF

         hLead := oNoCRM:Execute("leads","POST",{"title"=>"NewLead","description"=>cDescription,"user_id"=>cUsrEmail})         //
         IF hLead == NIL
            Alert(oNoCRM:cErrorText)
         ELSE            
            oRec:Lead := hLead["id"]
            oRec:Save()
            hLeadData["title"] := hb_strToUtf8(Trim(Trim(ku->Name1)+" "+ku->Name2))+" - Angebot "+LTrim(Str(ang->Angnr))+" #"+LTrim(Str(hLead["id"]))
         ENDIF
      ELSE
         oRec:Lead := nLeadId
         oRec:Save()
      ENDIF     

      //save any data which has been set to the lead
      IF Len(hLeadData) > 0                   
         oNoCRM:Execute("leads/"+Ltrim(Str(oRec:Lead)),"PUT",hLeadData)
      ENDIF

      IF lComment
         //Save quote as a comment on an existing lead
         cContent := 'Angebot Nr. '+LTrim(Str(ang->Angnr))+' gedruckt'+CRLF      
         cContent += "Ansprechpartner: "+hb_strtoutf8(aContact["name"])+CRLF
         cContent += "Wert: "+LTrim(Str(aValues[2],12,2))

         oNoCrm:Execute("leads/"+LTrim(Str(oRec:Lead))+"/comments","POST",{"lead_id"=>oRec:Lead,"content"=>cContent,"activity_id"=>nActivity,"user_id"=>SystemUser():Email})
      ENDIF

      IF oExtra:noCRMClien != 0//Save it to the client folder if this has been set
         oNoCRM:Execute("leads/"+Ltrim(Str(oRec:Lead))+"/add_to_client","POST",{"lead_id"=>oRec:Lead,"client_id"=>oExtra:noCRMClien})
      ENDIF

      EXIT
   ENDDO
   
RETURN NIL

CLASS NoCrmAPi FROM RestApi
   METHOD Execute
   METHOD New

   METHOD ChooseLead
   METHOD Connect
   METHOD GetActivityId
   METHOD GetPipeLineId
   METHOD GetStdPipeLineName
   METHOD GetStepId

   DATA cApiKey
   DATA cUsrToken
   DATA cBaseUrl

   DATA cErrorText
   DATA cErrorType
   DATA nError
ENDCLASS

METHOD New
   ::cKeyName := "NOCRMAPI"
   ::cBaseUrl := GetValue("NOCRM_URL","https://engelking.nocrm.io/api/v2/","URL of the noCRM instance")
RETURN ::Super:New()

METHOD ChooseLead(nTop,nLeft,nBottom,nRight,nLeadId,lNew)
   LOCAL oBrowse
   LOCAL aData := {},aGetData,aList := {},hJson,cSearch,nOff
   LOCAL nX,nY
   Default(@lNew,.F.)
   Default(@nLeadId,0)
   TxtBox("Leadnamen werden eingelesen")
   nOff := 1
   DO WHILE .T.
      aGetData := ::Execute("leads","GET",{"status"=>"todo,standby","include_unassigned"=>"true","limit"=>"100","offset"=>LTrim(Str(nOff))})
      AEval(aGetData,{|x| Aadd(aData,x) })
      nOff := Len(aData)
      IF Len(aGetData) < 100
         EXIT
      ENDIF
   ENDDO
   TxtClear()
   IF aData == NIL
      Tr_MsgBox("Fehler: "+::cErrorText)
   ELSE      
      FOR EACH hJson IN aData
         Aadd(aList,hb_utf8tostr(hJson["title"]))
      NEXT
      aList := ASort(aList,,,{|x,y| Upper(x) < Upper(y) })
      IF lNew
         HB_AIns(aList,1,"- Neuen Lead erzeugen -",.T.)
      ENDIF
      cSearch := ""
      @ nTop,nLeft TO nBottom,nRight
      @ nTop,nLeft+1 SAY " Lead: "

      oBrowse := TABrowse():New(nTop+1,nLeft+1,nBottom-1,nRight-1)
      oBrowse:lBox := .F.
      oBrowse:aData := aList
      oBrowse:NewColumn(NIL,{|| 
         IF Len(oBrowse:aData) == 0 .OR. ! Eval(oBrowse:ForBlock)
            RETURN Pad("Keine EintrÑge ",oBrowse:nRight-oBrowse:nLeft+1)
         ENDIF
         RETURN Pad(oBrowse:CurrentDataRow(),oBrowse:nRight-oBrowse:nLeft+1)
      })
      oBrowse:AddKey(K_ESC,{|| .F. })
      oBrowse:AddKey(K_ENTER,{||
         LOCAL nX
         IF Len(oBrowse:aData) != 0 .AND. Eval(oBrowse:ForBlock)
            IF lNew .AND. oBrowse:CurrentRow() == 1
               nLeadId := -1
               RETURN .F.
            ELSE
               nX := AScan(aData,{|x| hb_utf8tostr(x["title"]) == oBrowse:CurrentDataRow() })
               IF nX != 0
                  nLeadId := aData[nX]["id"]
                  RETURN .F.
               ENDIF
            ENDIF
         ENDIF
         RETURN .T.
      })
      oBrowse:ForBlock := {|| 
         IF Empty(cSearch)
            RETURN .T.
         ENDIF
         IF oBrowse:CurrentDataRow() == NIL
            RETURN .F.
         ENDIF
         RETURN cSearch $ Upper(oBrowse:CurrentDataRow())
      }
      oBrowse:bRestFun := {|| 
         LOCAL nKey := LastKey()
         LOCAL lUpdate := .F.
         IF nKey >= 32 .AND. nKey <= 255
            cSearch += Upper(Chr(nKey))
            lUpdate := .T.
         ELSEIF nKey == K_BS
            cSearch := Left(cSearch,Len(cSearch)-1)           
            lUpdate := .T.
         ENDIF         
         IF lUpdate
            oBrowse:goTop()
            oBrowse:forceStable()
            @ oBrowse:nBottom+1,obrowse:nLeft+1 TO oBrowse:nBottom+1,oBrowse:nRight   
            IF ! Empty(cSearch)
               @ oBrowse:nBottom+1,obrowse:nLeft+1 SAY Left(cSearch,MaxCol()-4) COLOR HB_ColorIndex(SetColor(),1)         
            ENDIF

         ENDIF
         RETURN .T.
      }
      IF nLeadId != 0
         nX := AScan(aData,{|x| x["id"] == nLeadId })
         //Alert( aData[nX]["title"] )
         IF nX != 0
            nY := AScan(oBrowse:aData,{|x| x == aData[nX]["title"] })
            //Alert(Str(nY)+oBrowse:aData[nY])            
            oBrowse:GoTo(nY)
         ENDIF
      ENDIF
      oBrowse:EventLoop()
      oBrowse:Display()
   ENDIF
RETURN nLeadId

METHOD Connect
   LOCAL hUserKey
   LOCAL hData

   hData := ::Execute("ping",,,.T.) 
   IF hData == NIL .OR. ! HHasKey(hData,"status") .OR. hData["status"] != 200
      RETURN .F.
   ENDIF     

   NetUse("buyer","buy")

   //Set the user
   hUserKey := ::Execute("auth/log_as","GET",{"user_id"=>Trim(SystemUser():Email)},.T.)

   IF hUserKey != NIL
      ::cUsrToken := hUserKey["token"]
   ENDIF
   
RETURN .T.

METHOD GetActivityId(cActivity)
   LOCAL aActivities,nActivity
   LOCAL nX
   LOCAL oErr

   aActivities := ::Execute("activities","GET")
   FOR nX := 1 TO Len(aActivities)
      IF aActivities[nX]["name"] == cActivity
         nActivity := aActivities[nX]["id"]
         EXIT
      ENDIF
   NEXT
   IF nActivity == NIL
      oErr := ErrorNew()
      oErr:SubSystem   := "noCRM-Connector"
      oErr:Description := "Activity not found: "+cActivity
      oErr:severity := 2 //error
      Throw(oErr) 
   ENDIF

RETURN nActivity

METHOD GetPipeLineId(cPipeline,aPipelines)
   LOCAL nPipeLine
   LOCAL nX,oErr
   IF aPipelines == NIL
      aPipelines := ::Execute("pipelines","GET")   
   ENDIF
   nX := AScan(aPipelines,{|x| x["name"] == cPipeline })
   IF nX != 0
      nPipeline := aPipelines[nX]["id"]
   ELSE
      oErr := ErrorNew()
      oErr:SubSystem   := "noCRM-Connector"
      oErr:Description := "Pipeline not found: "+cPipeline
      oErr:severity := 2 //error
      Throw(oErr) 
   ENDIF 

RETURN nPipeLine

METHOD GetStdPipeLineName()
RETURN GetValue("NOCRM_PIPELINE","Angebote","Name der Pipeline fÅr neue Leads")

METHOD GetStepId(cStep,nPipeline)
   LOCAL aSteps := ::Execute("steps","GET")   
   LOCAL nX,nStep := 0
   nX := AScan(aSteps,{|x| x["name"] == cStep .AND. x["pipeline_id"] == nPipeline })
   IF nX != 0
      nStep := aSteps[nX]["id"]
   ELSE
      //Alert("Step not found in pipeline")
   ENDIF
RETURN nStep

METHOD Execute(cUrl,cMethod,hData,lJson,lAsUsr)
   LOCAL cData //,cItem
   LOCAL aReturn
   //LOCAL cPostData
   LOCAL oErr
   //LOCAL pCurl
   LOCAL aHeader
   LOCAL nResponse,cResponse

   Default(@cMethod,"GET")
   Default(@lJson,.T.)
   Default(@lAsUsr,.F.)

   aHeader := {"X-API-KEY: "+IF(lAsUsr .AND. ! Empty(::cUsrToken),::cUsrToken,"$PASSWORD$")} 
   Aadd( aHeader, "Content-Type: application/json" ) 

   /*pCurl := Curl_Easy_Init()

   curl_easy_setopt(pCurl, HB_CURLOPT_SSL_VERIFYPEER,0)
   
   IF cMethod == "POST" 
      curl_easy_setopt(pCurl, HB_CURLOPT_POST, 1)
   ELSEIF cMethod != "GET"
      curl_easy_setopt(pCurl, HB_CURLOPT_CUSTOMREQUEST, cMethod)  
                  
   ENDIF
   
   curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )
    
   curl_easy_setopt(pCurl, HB_CURLOPT_HTTPHEADER, aHeader )          

   IF ! Empty(hData)
      IF cMethod == "GET"         
         FOR EACH cItem IN hData  
            IF cItem:__eNumIndex() == 1
               cUrl += "?"
            ELSE
               cUrl += "&"
            ENDIF
            cUrl += tip_URLEncode(cItem:__eNumKey())+"="+tip_URLEncode(cItem)
         NEXT     
      ELSE
         cPostData := HB_JsonEncode(hData)                       
         curl_easy_setopt(pCurl, HB_CURLOPT_POSTFIELDS, cPostData)         
      ENDIF
   ENDIF

   //Alert( ::cBaseUrl+cUrl )

   curl_easy_setopt(pCurl, HB_CURLOPT_URL, ::cBaseUrl+cUrl )
   Curl_Easy_Perform(pCurl)   
   curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )   
   Curl_Easy_CleanUp(pCurl)*/
   cData := ::Super:Execute(cUrl,cMethod,hData,aHeader,.T.,@nResponse,@cResponse)

   IF ! lJson
      RETURN cData
   ENDIF

   aReturn := HB_JSonDecode(cData)      
   
   IF ! Valtype(aReturn) $ "AH" // .OR. Len(aReturn) == 0  //the length can be zero if there are no entries
      oErr := ErrorNew()
      oErr:SubSystem   := "NOCRM-API"
      oErr:Description := "Error executing command. "+cData+"("+LTrim(Str(nResponse))+" "+cResponse+")"
      oErr:Args        := {cUrl,cData}
      Throw(oErr)   
   ELSEIF ValType(aReturn) == "H" .AND. HHasKey(aReturn,"error")
      ::cErrorText := aReturn["message"]
      ::nError := aReturn["error"]
      ::cErrorType := aReturn["type"]
      RETURN NIL
   ENDIF
RETURN aReturn

FUNCTION noCRM_DateConv(xDate)
   LOCAL cDateFmt := Set( _SET_DATEFORMAT,"YYYY-MM-DD" )
   IF ValType(xDate) == "C"
      xDate := CtoD(xDate)
   ELSE
      xDate := DToC(xDate)
   ENDIF   
   Set( _SET_DATEFORMAT,cDateFmt )
RETURN xDate
