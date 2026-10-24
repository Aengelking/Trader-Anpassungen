PROC __TOTAL_WORKED_HOURS
   LOCAL cBoy,cEOY,nYear := Year(Date())-1
   LOCAL getlist := {}
   LOCAL cFilter
   LOCAL nTot := 0,nTotEur := 0,nGaps
   LOCAL hPeople := {=>}
   LOCAL nHours,nX,hHours
   LOCAL oTimeButler,hAbsence,aWorkDays,dDate
   LOCAL aFeierTage,nFeierTage
   LOCAL hProMonat := {47=>2432.04,55=>3829.37,56=>1638.63}
   LOCAL aUsers,hUser
   LOCAL nProMonTot := 0,nProMonEur := 0

   NetUse( "watime", "wat" )
   NetUse( "buyer","buy" )
   
   CLS

   HB_LangSelect("EN")

   @ 01,00 SAY "Jahr" GET nYear PICTURE "9999" VALID nYear >= 1997 .AND. nYear <= Year(Date())
   READ
   IF LastKey() == 27
      RETURN
   ENDIF
   
   cBOY := Str(nYear,4)+"0101000000000"
   cEOY := Str(nYear,4)+"1231235959999"
   
   ? StoT(cBoy),StoT(cEOY)

   cFilter := "StoT(start) >= StoT('"+cBOY+"') .AND. StoT(end) <= StoT('"+cEOY+"') .AND. ! Empty(end)"

   //? cFilter

   wat->(dbSetFilter({|| wat->(&(cFilter)) },cFilter))
   wat->(dbGoTop())
   DO WHILE ! wat->(EOF()) .AND. Inkey(,128) != 27 .AND. LastKey() != 27
      IF StoT(wat->start) > StoT(wat->End)
         ? "Error: ",wat->WaNr,StoT(wat->start),StoT(wat->end),wat->(&(cFilter))
      ELSE
         nHours := (StoT(wat->end)-StoT(wat->start))*24
         //? TtoC(StoT(wat->start)),TtoC(StoT(wat->end)),(StoT(wat->end)-StoT(wat->start))*24
         nTot += nHours
         IF ! HHasKey(hPeople,wat->Person)
            hPeople[wat->Person] := {"TIMEBUTLERID"=>0,"TOTAL"=>0,"AWAY"=>0,"AWAYDAYS"=>0,"MONTHS"=>AFill(Array(12),0),"TIMES"=>{},"DAYS"=>{}}
         ENDIF
         hPeople[wat->Person]:Total += nHours
         hPeople[wat->Person]:Months[Month(StoT(wat->End))] += nHours
         Aadd(hPeople[wat->Person]:Times,{"START"=>StoT(wat->Start),"END"=>StoT(wat->End),"FA"=>wat->WaNr})
         IF ! StoD(wat->Start) $ hPeople[wat->Person]:Days
            Aadd(hPeople[wat->Person]:Days,StoD(wat->Start))
         ENDIF
      ENDIF
      wat->(dbSkip())
   ENDDO

   //LoadPrg(Path("run\timebutler.prg"))
   oTimeButler := TimeButlerAPI():New()
   aWorkDays := oTimeButler:Execute("workdays")
   aAbsences := oTimeButler:Execute("absences",,{"year"=>Str(nYear,4)})
   aUsers := oTimeButler:Execute("users")

   hUser := NIL
   FOR EACH hUser IN aUsers
      //? ValToPrg(hUser)
      IF HHaskEy(hUser,"Employee number") .AND. ! Empty(hUser["Employee number"]) .AND. hUser["Employee number"] $ hPeople
         hPeople[hUser["Employee number"]]:TimeButlerID := hUser["User ID"]
      ENDIF
   NEXT

   //? ValToPrg(aUsers)
   hWorkdays := NIL   
   FOR EACH hWorkdays IN aWorkDays      
      IF ValType(hWorkdays["User ID"])  != "N"
         HB_Adel(aWorkDays,hWorkdays:__enUMIndex(),.T.) //remove junk entry
      ELSE
         //? hWorkdays["Valid from (dd/mm/yyyy)"]
      ENDIF
   NEXT
   //Sinkey(0)

   FOR EACH hAbsence IN aAbsences            
      IF Len(hAbsence) > 1
         IF hAbsence["From"] <= Date() .AND. HHasKey(hAbsence,"Employee number") .AND. ValType(hAbsence["Employee number"]) == "N" .AND. hAbsence["Employee number"] $ hPeople            
            IF (nX := RAScan(aWorkDays,{|x| x["User ID"] == hAbsence["User ID"] ;
                        .AND. (ValType(x["Valid from (dd/mm/yyyy)"]) == "C" .OR. x["Valid from (dd/mm/yyyy)"] <= hAbsence["From"])  })) != 0
               IF ! hAbsence["Type"] $ {"Vacation","Sickness","Child ill"}                  
                  //? hAbsence["Type"]
               ELSE
                  FOR dDate := hAbsence["From"] TO hAbsence["To"]                     
                     nHours := aWorkDays[nX][CDoW(dDate)+" working time in minutes"]/60*IF(hAbsence["Half a day"],0.5,1)
                     //? Day(dDate),cDoW(dDate),nHours
                     hPeople[hAbsence["Employee number"]]:Months[Month(dDate)] += nHours
                     hPeople[hAbsence["Employee number"]]:Away += nHours
                     hPeople[hAbsence["Employee number"]]:AwayDays += IF(hAbsence["Half a day"],0.5,1)
                     Aadd(hPeople[hAbsence["Employee number"]]:Days,dDate)
                  NEXT
               ENDIF               
            ENDIF
         ENDIF
      ENDIF
   NEXT

   aFeierTage := FeierTage(nYear,GetConfigValue("STATE"),.F.)  
   ASort(aFeierTage) 

   nWorkHours := 174*12/365*(Min(Date(),StoD(cEOY))-StoD(cBOY))
   ? nWorkHours

   ? Space(2+1+35),Pad("Verrechnet",8+1+8),Pad("Lcken",8),Pad("Abwesend",8),Pad("Fehl",8),Space(5),"Verrechnungssatz"
   ? Pad("Mitarbeiter",2+1+35),Pad("Stunden",8),Pad("EUR",8),Pad("Stunden",8),Pad("Stunden",8),Pad("Stunden",8),Space(5),Pad("Neu",5),"Bisher"
   FOR EACH hHours IN hPeople
      buy->(dbGoTo( hHours:__eNumKey() ))
      ASort(hHours:Times,,,{|x,y| x:start < y:start})
      
       
      FOR nFeierTage := 1 TO Len(aFeierTage)
         IF aFeierTage[nFeierTage] > Date()         
            EXIT
         ENDIF
         IF (nX := RAScan(aWorkDays,{|x| x["User ID"] == hHours:TimeButlerID ;
            .AND. (ValType(x["Valid from (dd/mm/yyyy)"]) == "C" .OR. x["Valid from (dd/mm/yyyy)"] <= aFeierTage[nFeierTage]) }) ) != 0
            hHours:Away += aWorkDays[nX][CDoW(aFeierTage[nFeierTage])+" working time in minutes"]/60
            hHours:AwayDays ++
            IF ! aFeierTage[nFeierTage] $ hHours:Days
               
               Aadd(hHours:Days,aFeierTage[nFeierTage])
            ENDIF
         ENDIF
      NEXT
      

      nGaps := 0
      FOR nX := 2 TO Len(hHours:Times)
         IF hHours:Times[nX]:Start < hHours:Times[nX-1]:End
            ? "Overlap",hHours:Times[nX]:FA,hHours:Times[nX]:Start,hHours:Times[nX-1]:FA,hHours:Times[nX-1]:End
         ELSEIF Day(hHours:Times[nX-1]:End) == Day(hHours:Times[nX]:Start) .AND. hHours:Times[nX]:Start > hHours:Times[nX-1]:End
            IF hHours:Times[nX]:Start > hHours:Times[nX-1]:End+5/60/24
               //? "Gap",hHours:Times[nX-1]:FA,hHours:Times[nX-1]:End,hHours:Times[nX]:FA,hHours:Times[nX]:Start,(hHours:Times[nX]:Start-hHours:Times[nX-1]:End)*24
            ENDIF
            nGaps += (hHours:Times[nX]:Start-hHours:Times[nX-1]:End)*24
            hPeople[hHours:__eNumKey()]:Months[Month(hHours:Times[nX]:Start)] += (hHours:Times[nX]:Start-hHours:Times[nX-1]:End)*24
         //ELSEIF Day(hHours:Times[nX-1]:End) == Day(hHours:Times[nX]:Start)
         ELSE

         ENDIF
      NEXT
      ? Str(hHours:__eNumKey(),2),buy->Buyer,Str(hHours:Total,8,2),Str(hHours:Total*buy->VerrSatz,8,2),Str(nGaps,8,2),Str(hHours:Away,8,2)
      IF buy->(REcno()) $ hProMonat
         nSoll := 0
         //? VAlToPrg(hHours:Days)
         FOR dDate := StoD(Str(nYear,4)+"0101") TO Min(Date(),StoD(Str(nYear,4)+"1231"))
            IF DoW(dDate) != 1 .AND. DoW(dDate) != 7 //not saturday or sunday
               IF (nX := RAScan(aWorkDays,{|x| ValType(x["User ID"]) == "N" .AND. x["User ID"] == hHours:TimeButlerID ;
                  .AND. (ValType(x["Valid from (dd/mm/yyyy)"]) == "C" .OR. x["Valid from (dd/mm/yyyy)"] <= dDate)  }) ) != 0 
                  nSoll += aWorkDays[nX][CDoW(dDate)+" working time in minutes"]/60
               ENDIF
            ENDIF
         NEXT
         //? hHours:AwayDays
         
         ?? Str(nSoll-hHours:Away-hHours:Total,8,2),Str(hHours:Total/nSoll*100,5,2)+"%",Str((hProMonat[buy->(Recno())]/174*nWorkHours)/hHours:Total,5,2),Str(buy->VerrSatz,5,2)
         

         //Sinkey(0)
      //? ValToPrg(aFeierTage)
         nProMonTot += hHours:Total
      ENDIF
      nTotEur += hHours:Total*buy->VerrSatz
   NEXT
   

   HEval(hProMonat,{|x,nVal| nProMonEur += nVal })

   ? "  ",Space(36),Str(nTot,8,2),Str(nTotEUR,8,2),Space(8+1+8+1+5),nProMonEur/30.42*(StoD(cEOY)-StOd(cBoy)+1)/nProMonTot
   //? ValToPrg(LETO_SUM("StoT(end)-StoT(start)",cFilter))
   Sinkey(0)

   HB_LangSelect("DE")
RETURN 

/*FUNCTION TimeButlerAPI
RETURN NIL*/
   #include "x:\run\timebutlerapi.prg"
//   #inlcude "x:\run\shopware.prg"