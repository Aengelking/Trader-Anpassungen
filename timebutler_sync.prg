
//#include 'inkey.ch'
#include "y:\harbour\trader\source\include\david.ch"

#define UPDATE_DAVID

PROC Run_TimeButler(lDavid,lAutoReply,lFrepple,lOrga)
   LOCAL oAPI := TimeButlerAPI():New()
   LOCAL aAbsences,hAbsence
   LOCAL aUsers
   //LOCAL aList := {}
   LOCAL hAbsenceTypes := oAPI:GetAbsenceTypes()
   LOCAL aAbsenceAway := {"Vacation","Parental leave","Sickness","Child ill","Child ill w/o payment"}
   LOCAL aAbsenceLimit := {"Training school","Further training","Fair","Business trip"}
   LOCAL aAbsenceAvail := {"Home office"}

   LOCAL dFrom := Date()      
   //LOCAL dTo := dFrom   
   LOCAL cDate,nR
   LOCAL oItem,aItems

   LOCAL oAccount := DV_GetMailAccount()
   //LOCAL oArchive1  := oAccount:GetSpecialArchive(DvArchivePersonalCalendar)
   LOCAL oArchive
   LOCAL oCalItem,tStart

   LOCAL dAwayUntil,dAwayFrom,lHoliday,nVertreter,lForward
   LOCAL lTodayIsHoliday := IsFeiertag(Date(),GetConfigValue("STATE"))
   LOCAL lTomorrowIsHoliday := IsFeiertag(Date()+1,GetConfigValue("STATE"))

   LOCAL oAutoReply,nRecno
   LOCAL nX
   LOCAL oFrepple,aResult
   LOCAL cStartTime,cEndTime
   LOCAL hData,nYear,aData
   LOCAL aDays,nDay,dPrev,dStart
   LOCAL oUser
  
   Default(@lDavid,GetConfigValue("BATCHMODE"))
   Default(@lAutoReply,.T.)
   IF ValType(lFrepple) != "L"
      IF ! GetConfigValue("BATCHMODE")
         lFrepple := Tr_msgBox("Frepple synchronisieren?",,{"Ja","Nein"}) == 1
      ELSE
         lFrepple := .T.
      ENDIF
   ENDIF
   Default(@lOrga,.T.)

   NetUse("buyer","buy")
   NetUSe("resource","res")

   CLS

   ? "Benutzer werdern heruntergeladen..."
   aUsers := oAPI:Execute("users")
   ?? " abgeschlossen"

   ? "Abwesenheiten werden heruntergeladen..."
   aAbsences := {}
   FOR nYear := Year(Date()) TO Year(Date())+1
      aData := oAPI:Execute("absences?year="+Ltrim(Str(nYear)))
      FOR nX := 1 To Len(aData)
         Aadd(aAbsences,aData[nX])
      NEXT
   NEXT      
   ?? " abgeschlossen"
   //? ValtoPrg(aAbsences)
   IF ValType(aAbsences) != "A"
      ? "Fehler bei der Verbindung zu timebutler"         
      //Sinkey(0)
      RETURN
   ENDIF

   //Abwesenheit und Vertreter beim Benutzer hinterlegen
   FOR EACH hAbsence IN aAbsences
      IF Len(hAbsence) > 1 .AND. hAbsence["From"] >= Date() .AND.;
         hAbsence["To"] >= Date() .AND.;
         HHasKey(hAbsence,"Employee number") .AND. ValType(hAbsence["Employee number"]) == "N" .AND.;
         hAbsence["Substitute state"] == "Approved"
         
         oUser := User():New()
         IF oUser:Load(hAbsence["Employee number"])               
            oUser:oSettings:AwayUntil := hAbsence["To"]
            oUser:oSettings:AwayFrom := hAbsence["From"]

            nR := AScan(aUsers,{|x| x["User ID"] == hAbsence["User ID of the substitute"]})
            IF nR != 0 .AND. ! Empty(aUsers[nR]["Employee number"]) 
               oUser:oSettings:AwaySubst := aUsers[nR]["Employee number"]
            ELSE
               oUser:oSettings:AwaySubst := 0
            ENDIF
         ENDIF
         
         lForward := hAbsence["Forward emails"] == "yes"
      ENDIF
   NEXT

   //Create Orga Chart
   IF lOrga
      Timbutler_orga(aUsers)
   ENDIF

   //Update Frepple
   IF lFrepple
      

      

      //Sync Frepple
      LoadModule("frepple")
      oFrepple := GetFreppleApi()
   
      ? "Frepple Buckets werden heruntergeladen..."
      aResult := oFrepple:getCalendarBuckets() //this returns all buckets for all resources
      

      IF ValType(aResult) != "A"
         ?? "Fehler bei der Verbindung zu Frepple"
      ELSE
         ?? " abgeschlossen"
         ? "Timebutler Buckets werden in Frepple gel”scht..."
         FOR nX := 1 TO Len(aResult)
            IF aResult[nX]["source"] $ {"Timebutler","Trader"}
               ? "Delete bucket "+LTrim(Str(aResult[nX]["id"]))
               oFrepple:deleteCalendarBucket(aResult[nX]["id"])
            ENDIF
         NEXT
         ?? " abgeschlossen"
      
         
         res->(dbSetOrder( 3 ))
         FOR EACH hAbsence IN aAbsences            
            IF Len(hAbsence) > 1 .AND. hAbsence["To"] >= Date()-15 .AND.;
               HHasKey(hAbsence,"Employee number") .AND. ValType(hAbsence["Employee number"]) == "N" .AND. res->(dbSeek( Str(hAbsence["Employee number"],2)))
               ? "Add bucket for "+res->Name+" "+hAbsence["Type"]+" from "+DtoC(hAbsence["From"])+" to "+DtoC(hAbsence["To"])
               hData := {=>}
               hData["calendar"] := Trim(res->Name)
               hData["source"] := "Timebutler"

               cStartTime := "06:00"
               cEndTime := "18:00"
               IF hAbsence["Half a day"]
                  IF hAbsence["Morning"]                  
                     cEndTime := "12:00"
                  ELSE
                     cStartTime := "12:00"
                     
                  ENDIF            
               ENDIF

               hData["startdate"] := oFrepple:DtoC(hAbsence["From"],cStartTime)
               hData["enddate"] := oFrepple:DtoC(hAbsence["To"],cEndTime)
               hData["value"] := 0
               hData["priority"] := 0
               hData["monday"] := hData["tuesday"] := hData["wednesday"] := hData["thursday"] := hData["friday"] := hData["saturday"] := hData["sunday"] := .T.
               hData["starttime"]  := cStartTime
               hData["endtime"] := cEndTime

               oFrepple:Execute(oFrepple:cScenarioUrl+"api/input/calendarbucket/","POST",hData,.T.)
            ENDIF
         NEXT 

         //Add holidays
         FOR nYear := Year(Date()) TO Year(Date())+1         
            aDays := FeierTage(nYear,GetConfigValue("STATE"),.F.)
            dPrev := StoD("")
            dStart := StoD("")
            FOR nX := 1 TO Len(aDays)
               IF dPrev+1 == aDays[nX]
                  dPrev := aDays[nX]
               ELSE
                  IF ! Empty(dStart)
                     ? "Feiertage "+DtoC(dStart)+" bis "+DtoC(dPrev)+" werden in Frepple eingetragen"
                     hData := {=>}
                     hData["calendar"] := "Schliesstage"
                     hData["source"] := "Trader"

                     cStartTime := "00:00"
                     cEndTime := "23:59"

                     hData["startdate"] := oFrepple:DtoC(dStart,cStartTime)
                     hData["enddate"] := oFrepple:DtoC(dPrev,cEndTime)
                     hData["value"] := 0
                     hData["priority"] := 0
                     hData["monday"] := hData["tuesday"] := hData["wednesday"] := hData["thursday"] := hData["friday"] := hData["saturday"] := hData["sunday"] := .T.
                     hData["starttime"]  := cStartTime
                     hData["endtime"] := cEndTime
                     oFrepple:Execute(oFrepple:cScenarioUrl+"api/input/calendarbucket/","POST",hData,.T.)
                  ENDIF
                  dStart := aDays[nX]
                  dPrev := aDays[nX]
               ENDIF
            NEXT
         NEXT
      ENDIF
   ENDIF

   IF lDavid
      buy->(dbSetOrder(0)) 
      buy->(dbGoTop())
      DO WHILE ! buy->(EOF())
         IF buy->Aktive             
            IF ! Empty(buy->David_Id)  //David Calender and AutoReply sync
               oArchive := oAccount:ArchiveFromID(oAccount:DavidRoot+"\archive\user\"+buy->David_Id+"\cal")
               IF ! Empty(oArchive:DisplayName)
                  ? buy->(Recno()),buy->Buyer,oArchive:ID //,oArchive:DisplayName,oArchive:Status
                  //Sinkey(0)
                  aItems := oArchive:AllItems()
                  FOR EACH oItem IN aItems
                     IF HB_HScan(hAbsenceTypes,oItem:Subject) > 0 .AND. (oItem:SendTime >= dFrom .OR. oItem:StopTime >= dFrom)
                        ? oItem:Subject, oItem:StatusTime, "bis", oItem:StopTime,"gel”scht"
                        #ifdef UPDATE_DAVID
                           oItem:Delete()
                        #endif
                     ENDIF                    
                  NEXT
                  dAwayUntil := Date()               
                  IF lTodayIsHoliday .OR. lTomorrowIsHoliday
                     dAwayFrom := IF(lTodayIsHoliday,Date(),Date()+1)
                     dAwayUntil := Date()+IF(!lTodayIsHoliday,1,0)
                     IF DoW(dAwayUntil) == 6 //Friday, then add the weekend
                        dAwayUntil := dAwayUntil+2
                     ENDIF                     
                     lHoliday := .T.
                  ELSE
                     dAwayFrom := StoD("")
                     lHoliday := .F.
                  ENDIF
                  nVertreter := 0
                  lForward := .F.
                  FOR EACH hAbsence IN aAbsences            
                     IF Len(hAbsence) > 1 .AND. hAbsence["To"] >= dFrom
                        //hAbsence["From"] <= dFrom  .AND. hAbsence["To"] >= dFrom                     
                        IF HHasKey(hAbsence,"Employee number") .AND. ValType(hAbsence["Employee number"]) == "N" .AND. hAbsence["Employee number"] == buy->(Recno()) 
                           IF HHasKey(hAbsenceTypes,hAbsence["Type"])
                              ? hAbsenceTypes[hAbsence["Type"]]+" vom "+DtoC(hAbsence["From"])+" bis "+DtoC(hAbsence["To"])
                              IF hAbsence["Half a day"]
                                 IF hAbsence["Morning"]
                                    ?? "Vormittag"
                                 ELSE
                                    ?? "Nachmittag"
                                 ENDIF                           
                              ENDIF
                              #ifdef UPDATE_DAVID
                              oCalItem := oArchive:CreateArchiveEntry(DvCalendarItem)
                              
                              oCalItem:Subject := hAbsenceTypes[hAbsence["Type"]]
                              IF ! hAbsence["Half a day"]
                                 oCalItem:AllDayEvent := .T.
                              ENDIF
                              oCalItem:ShowAs := IF(hAbsence["Type"]$aAbsenceAvail,1,3)  //3=Out of Office, 1=Free, 2=Busy
                              tStart := StoT(DtoS(hAbsence["From"])+IF(hAbsence["Half a day"].AND.!hAbsence["Morning"],"120000","000000"))
                              oCalItem:StatusTime := tStart
                              oCalItem:SendTime := tStart
                              oCalItem:StopTime := StoT(DtoS(hAbsence["To"])+IF(hAbsence["Half a day"].AND.hAbsence["Morning"],"120000","235959"))                        
                              oCalItem:Save()
                              #endif
                              ?? "",hAbsence["From"],"<=",AddWorkingDays(dAwayUntil,1,"BW"),"?"
                              IF AScan(aAbsenceAway,hAbsence["Type"]) > 0 .AND. !hAbsence["Half a day"] .AND.;
                                 hAbsence["From"] <= AddWorkingDays(dAwayUntil,1,GetConfigValue("STATE")) .AND. hAbsence["To"] >= Date() //we are currently away
                                 lHoliday := .T.
                                 IF Empty(dAwayFrom)
                                    dAwayFrom := hAbsence["From"]
                                 ENDIF
                                 dAwayUntil := Max(dAwayUntil,hAbsence["To"])
                                 IF DoW(dAwayUntil) == 6 //Friday, then add the weekend
                                    dAwayUntil := dAwayUntil+2
                                 ENDIF                              
   
                                 ?? hAbsence["Substitute state"],hAbsence["User ID of the substitute"]
                                 //?? hAbsence["Forward emails"]
                                 IF hAbsence["Substitute state"] == "Approved" .AND. nVertreter == 0 //we have a substitute and no substitute has been set yet. This allows the substitute to change during the absence but it will use the first one it finds
                                    nVertreter := AScan(aUsers,{|x| x["User ID"] == hAbsence["User ID of the substitute"]})
                                    IF nVertreter != 0
                                       nVertreter := aUsers[nVertreter]["Employee number"]
                                    ENDIF
                                    lForward := hAbsence["Forward emails"] == "yes"
                                 ENDIF
                              ENDIF
                           ELSE
                              ? hAbsence["Type"]+" vom "+DtoC(hAbsence["From"])+" bis "+DtoC(hAbsence["To"])
                           ENDIF 
                        ENDIF                    
                     ENDIF
                  NEXT
                  IF lHoliday .AND. buy->(Recno()) != 2
                     IF Dow(dAwayUntil) == 7
                        dAwayUntil -= 1
                     ELSEIF DoW(dAwayUntil) == 1
                        dAwayUntil -= 2
                     ENDIF

                     ? "Abwesend von "+DtoC(dAwayFrom)+" bis "+DtoC(dAwayUntil),Dow(dAwayUntil)
                     IF nVertreter != 0
                        ?? " Vertreter: ",nVertreter
                        ?? " Emails weiterleiten: ",lForward
                     ENDIF
                     nRecno := buy->(Recno())
                     
                     
                     oAutoReply := DavidAutoReply():New(nRecno)
                     IF dAwayUntil != oAutoReply:dUntil .OR. oAutoReply:nVertreter != nVertreter .OR. oAutoReply:dFrom != dAwayFrom .OR. oAutoReply:lForward != lForward
                        oAutoReply:dFrom  := dAwayFrom
                        oAutoReply:dUntil := dAwayUntil
                        oAutoReply:nVertreter := nVertreter
                        oAutoReply:lForward := lForward

                        BEGIN SEQUENCE
                           oAutoReply:Set()
                           ? "AutoReply gesetzt"
                        RECOVER //USING oError
                           ? "Fehler beim Setzen des AutoReply" //+oError:Message
                        END

                        IF buy->(Recno()) == 9
                           SetValue("HOLIDAY-AMOS-START",Date())
                           SetValue("HOLIDAY-AMOS-END",dAwayUntil)
                           //Sinkey(0)
                        ENDIF
                        
                        //Sinkey(0)
                     ELSE
                        ? "AutoReply bereits gesetzt"
                     ENDIF
                     buy->(dbSetOrder(0))
                     buy->(dbGoto(nRecno))
                     
                     

                     
                     
                     //Sinkey(0)
                     
                  ENDIF
                  IF buy->(Recno()) == 34 //.AND. ! GetConfigValue("BATCHMODE")   
                     //Sinkey(0)
                  ENDIF
                  //SInkey(0)
               ELSE
                  ? "Kein Kalender fr "+buy->Buyer
               ENDIF
            ENDIF            
         ENDIF
         buy->(dbSkip())
      ENDDO
   ENDIF
      
      IF ! GetConfigValue("BATCHMODE")
         //Sinkey(0)
      ENDIF

      

      

      
   
RETURN

#include "x:\run\timebutlerapi.prg"
#include "x:\run\timebutler_orga.prg"
#include "x:\run\autoreply_david.prg"
