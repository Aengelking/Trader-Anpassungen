PROC RUN_TOTAL_WORKED_HOURS
   LOCAL cBoy,cEOY,nYear := Year(Date())-1
   LOCAL getlist := {}
   LOCAL cFilter
   LOCAL nTot := 0,nTotEur := 0,nGaps
   LOCAL hPeople := {=>}
   LOCAL nHours,nX,hHours
   LOCAL oTimeButler,hAbsence,aWorkDays,dDate
   LOCAL aFeierTage,nFeierTage
   LOCAL hProMonat := {47=>2450.87,55=>2970.12,56=>1631.66}

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

   ? cFilter

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
            hPeople[wat->Person] := {"TOTAL"=>0,"AWAY"=>0,"MONTHS"=>AFill(Array(12),0),"TIMES"=>{}}
         ENDIF
         hPeople[wat->Person]:Total += nHours
         hPeople[wat->Person]:Months[Month(StoT(wat->End))] += nHours
         Aadd(hPeople[wat->Person]:Times,{"START"=>StoT(wat->Start),"END"=>StoT(wat->End),"FA"=>wat->WaNr})
      ENDIF
      wat->(dbSkip())
   ENDDO

   LoadPrg(Path("run\timebutler.prg"))
   oTimeButler := TimeButlerAPI():New()
   aWorkDays := oTimeButler:Execute("workdays")
   aAbsences := oTimeButler:Execute("absences",,{"year"=>Str(nYear,4)})

   //? ValToPrg(aWorkDays)
   /*FOR EACH hWorkdays IN aWorkDays
      ? ValToPrg(hWorkdays)
   NEXT
   Sinkey(0)*/

   FOR EACH hAbsence IN aAbsences            
      IF Len(hAbsence) > 1
         IF hAbsence["From"] <= Date() .AND. HHasKey(hAbsence,"Employee number") .AND. ValType(hAbsence["Employee number"]) == "N" .AND. hAbsence["Employee number"] $ hPeople            
            IF (nX := AScan(aWorkDays,{|x| x["User ID"] == hAbsence["User ID"]})) != 0
               IF ! hAbsence["Type"] $ {"Vacation","Sickness","Child ill"}                  
                  //? hAbsence["Type"]
               ELSE
                  FOR dDate := hAbsence["From"] TO hAbsence["To"]                     
                     nHours := aWorkDays[nX][CDoW(dDate)+" working time in minutes"]/60*IF(hAbsence["Half a day"],0.5,1)
                     //? Day(dDate),cDoW(dDate),nHours
                     hPeople[hAbsence["Employee number"]]:Months[Month(dDate)] += nHours
                     hPeople[hAbsence["Employee number"]]:Away += nHours
                  NEXT
               ENDIF               
            ENDIF
         ENDIF
      ENDIF
   NEXT

   aFeierTage := FeierTage(nYear,GetConfigValue("STATE"),.F.)  
   ASort(aFeierTage) 

   nWorkHours := 174*12/365*(Date()-StoD(Str(nYear,4)+"0101"))
   ? nWorkHours

   ? Space(2+1+35),Pad("Verrechnet",8+1+8),Pad("Lcken",8),Pad("Abwesend",8),"Verrechnungssatz"
   ? Pad("Mitarbeiter",2+1+35),Pad("Stunden",8),Pad("EUR",8),Pad("Stunden",8),Pad("Stunden",8),"Neu","Bisher"
   FOR EACH hHours IN hPeople
      buy->(dbGoTo( hHours:__eNumKey() ))
      ASort(hHours:Times,,,{|x,y| x:start < y:start})
      IF (nX := AScan(aWorkDays,{|x| HHasKey(x,"Employee number") .AND. x["Employee number"] == buy->(Recno()) })) != 0
         FOR nFeierTage := 1 TO Len(aFeierTage)
            IF aFeierTage[nFeierTage] > Date()         
               EXIT
            ENDIF
            hHours:Away += aWorkDays[nX][CDoW(aFeierTage[nFeierTage])+" working time in minutes"]/60
         NEXT
      ENDIF

      nGaps := 0
      FOR nX := 2 TO Len(hHours:Times)
         IF hHours:Times[nX]:Start < hHours:Times[nX-1]:End
            ? "Overlap",hHours:Times[nX]:FA,hHours:Times[nX]:Start,hHours:Times[nX-1]:FA,hHours:Times[nX-1]:End
         ELSEIF Day(hHours:Times[nX-1]:End) == Day(hHours:Times[nX]:Start) .AND. hHours:Times[nX]:Start > hHours:Times[nX-1]:End
            IF hHours:Times[nX]:Start > hHours:Times[nX-1]:End+5/60/24
               //? "Gap",hHours:Times[nX-1]:FA,hHours:Times[nX-1]:End,hHours:Times[nX]:FA,hHours:Times[nX]:Start
            ENDIF
            nGaps += hHours:Times[nX]:Start-hHours:Times[nX-1]:End
            hPeople[hHours:__eNumKey()]:Months[Month(hHours:Times[nX]:Start)] += hHours:Times[nX]:Start-hHours:Times[nX-1]:End
         //ELSEIF Day(hHours:Times[nX-1]:End) == Day(hHours:Times[nX]:Start)

         ENDIF
      NEXT
      ? Str(hHours:__eNumKey(),2),buy->Buyer,Str(hHours:Total,8,2),Str(hHours:Total*buy->VerrSatz,8,2),Str(nGaps,8,2),Str(hHours:Away,8,2)
      IF buy->(REcno()) $ hProMonat
         ?? "",Str(hProMonat[buy->(Recno())]/174*nWorkHours/hHours:Total,5,2),Str(buy->VerrSatz,5,2)
      ENDIF
      /*? " "
      FOR nX := 1 TO 12
         ?? strZero(nX,2)+": "+LTrim(Str(hHours:Months[nX],7,2)),""
      NEXT*/
      nTotEur += hHours:Total*buy->VerrSatz
   NEXT
   ? "  ",Str(nTot,8,2),Str(nTotEUR,10,2)
   //? ValToPrg(LETO_SUM("StoT(end)-StoT(start)",cFilter))
   Sinkey(0)

   HB_LangSelect("DE")
RETURN 

FUNCTION TimeButlerAPI
RETURN NIL
   //#include "x:\run\timebutler.prg"
//   #inlcude "x:\run\shopware.prg"