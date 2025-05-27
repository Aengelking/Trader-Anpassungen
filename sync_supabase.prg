PROC RUN_SYNC_Supabase
   LOCAL oSupa := Supabase():New()
   LOCAL oTimebutler := TimeButlerAPI():New()
   LOCAL nM
   LOCAL aCurrent,nX,aKPIs
   LOCAL nTurnover
   LOCAL aUsers,bAddKPIS
   LOCAL hValues,aData,hValue,nBookings
   LOCAL aLinked,cId
   LOCAL nLastMonth,nFirstMonth,nR,nTotal
   LOCAL hSisterTurn := {=>},cKunde,nValue
   LOCAL hSisterBook := {=>}
   LOCAL aBu,hBu,hBuTemplate,nBuValue
   CLS

   IF ! oSupa:Login()
      Tr_MsgBox("Login failed")
      RETURN
   ENDIF

   hValues := {;
      "UMSATZ"=>{"name"=>"Umsatz","link_id"=>"turnover"},;
      "SALES"=>{"name"=>hb_strtoutf8("Auftr„ge"),"link_id"=>"bookings"},;      
      "MA"=>{"name"=>"Anzahl Mitarbeiter","link_id"=>"employees","avg"=>.T.},;
      "UMMA"=>{"name"=>"Umsatz pro Mitarbeiter","link_id"=>"turnover_employee"};
   }

   //update linked values
   aLinked := HB_JsonDecode(oSupa:Execute("rest/v1/linked_values","GET",{"select"=>"link_id"},,.T.))
   //? ValToPrg(aLinked)

   //get business units with the link_id
   aBu := HB_JsonDecode(oSupa:Execute("rest/v1/business_units","GET",{"select"=>"id,link_id","link_id"=>"neq.''"},,.T.))
//   ? ValToPrg(aBu)

   //create template for business unit values
   hBu := {"wireharness"=>"","ieclock"=>"","vehicle"=>"","rugged"=>""}
   hBuTemplate := {=>}
   FOR EACH cId IN HGetKeys(hBu)  
      hBuTemplate[cId] := 0
      nX := AScan(aBu,{|x2| x2["link_id"] == cId})

      IF nX != 0
         hBu[cId] := aBu[nX]["id"]
      ENDIF
   NEXT

   
   HEval(hValues,{|k,x| 
      hValues[k]["months"] := AFill(Array(12),0)
      hValues[k]["bu_months"] := AFill(Array(12),HB_HClone(hBuTemplate))
      hValues[k]["bu_yearly"] := HB_HClone(hBuTemplate)
      hValues[k]["tertial"] := AFill(Array(3),0)
      hValues[k]["yearly"] := 0
      //HB_SymbolUnused(k) 
      cId := x["link_id"]
      IF AScan(aLinked,{|y| y["link_id"] == cId}) > 0 //update existing
         ? "Update Link ID:",cId
         ?? oSupa:Execute("rest/v1/linked_values?link_id=eq."+cID,"PATCH",{"name"=>x["name"]},,.T.)
      ELSE//insert new
         ? "Insert Link ID:",cId
         ?? oSupa:Execute("rest/v1/linked_values","POST",{"name"=>x["name"],"link_id"=>x["link_id"]},,.T.)
      ENDIF
      
      RETURN .T.
   })
    
   //hValues["MA"] := {"months"=>AFill(Array(12),0),"yearly"=>0}
   aUsers := oTimebutler:Execute("users")
   IF ! HHasKey(aUsers[Len(aUsers)],"First name") //we seem to get an empty user at the end of the list which we ignore      
      HB_Adel(aUsers,Len(aUsers),.T.)
   ENDIF
   AEval(aUsers,{|x| 
      IF ! x["User account locked"]
         nLastMonth := 12
         nFirstMonth := 1
         IF ! Empty(x["Date of entry (dd/mm/yyyy)"]) .AND. Val(Right(x["Date of entry (dd/mm/yyyy)"],4)) == Year(Date())
            nFirstMonth := Val(SubStr(x["Date of entry (dd/mm/yyyy)"],3,2))
         ENDIF
         IF ! Empty(x["Date of separation from company (dd/mm/yyyy)"]) .AND. Val(Right(x["Date of separation from company (dd/mm/yyyy)"],4)) == Year(Date())
            nLastMonth := Val(SubStr(x["Date of separation from company (dd/mm/yyyy)"],3,2))
         ENDIF
         nLastMonth := Min(nLastMonth,Month(Date()))
         FOR nM := Max(1,nFirstMonth) TO Min(nLastMonth,12)
            ? nM
            hValues["MA"]["months"][nM]++
         NEXT
      ENDIF
      RETURN .T.
   })
   nTotal := 0
   AEval(hValues["MA"]["months"],{|x| nTotal += x})
   hValues["MA"]["yearly"] := nTotal/12

   //Get the turnover of sister company
   NETUSE( "englsre","re",.F.,5 )
   re->(dbSetOrder(2))
   cKunde := Pad("ENGELKIA",8)
   re->(dbSeek("  0"+cKunde))
   hSisterTurn["current"] := 0
   hSisterTurn["months"] := AFill(Array(12),0)
   Do WHILE ! re->(EOF()) .AND. re->kunde == cKunde .AND. re->reposnr = 0
      nValue := ( re->poswt - re->preis ) * If(re->rate!=0,re->rate,If(!Empty(re->money),Currate(re->Money,"V"),1))     // NET VALUE
      IF YEAR( re->rechdat ) == YEAR( DATE() )
         hSisterTurn["current"] += nValue
         hSisterTurn["months"][MONTH( re->rechdat )] += nValue
      ENDIF
      re->(dbSkip( 1 ))
   Enddo

   //Get Bookings of sister company
   NETUSE( "engauf","auf",.F.,5 )
   auf->(dbSetOrder(2)) //kunde+str(bestat)+...
   auf->(dbSeek(cKunde))  
   hSisterBook["current"] := 0 
   hSisterBook["months"] := AFill(Array(12),0)      
   Do WHILE ! auf->(EOF()) .AND. auf->kundma == cKunde .AND. auf->bestat < 3
      nValue := IF(auf->Bestat!=3,auf->vkqty,auf->gelqty ) * auf->vkpr/auf->pe*If(!Empty(auf->money),Currate(auf->Money,"V"),1)
      IF YEAR( auf->besda ) == YEAR( DATE() )
         hSisterBook["current"] += nValue
         hSisterBook["months"][MONTH( auf->besda )] += nValue
      ENDIF
      auf->(dbSkip( 1 ))
   Enddo
   
   NetUse("stats","stats")
   NetUse("automotive/stats","auto_stats")
   NetUse("umsatz","um")   

   FOR nM := 1 TO 12
      IF stats->(dbSeek( Str(Year(Date()),4)+" "+Str(nM,2)))
         nTurnover := Round(stats->Billings,0)
         nBookings := Round(stats->Sales,0)
      ELSE
         nTurnover := 0
         nBookings := 0
      ENDIF
      IF auto_stats->(dbSeek( Str(Year(Date()),4)+" "+Str(nM,2)))
         nTurnover += Round(auto_stats->Billings,0)
         nBookings += Round(auto_stats->Sales,0)
         hValues["UMSATZ"]["bu_months"][nM]["vehicle"] := auto_stats->Billings
         hValues["SALES"]["bu_months"][nM]["vehicle"] := auto_stats->Sales   
      ENDIF
      nTurnover -= hSisterTurn["months"][nM]
      nBookings -= hSisterBook["months"][nM]
      hValues["UMSATZ"]["months"][nM] := nTurnover
      hValues["SALES"]["months"][nM] := nBookings
      IF hValues["MA"]["months"][nM] != 0
         hValues["UMMA"]["months"][nM] := nTurnover/hValues["MA"]["months"][nM]                  
      ENDIF
      
      //turnover and bookings for the business units
      um->(dbSetOrder(2))
      um->(dbSeek( Str(Year(Date()),4)+Str(nM,2)+Str(9,5) ))
      DO WHILE um->Manufactur == 9 .AND. Val(um->Year) == Year(Date()) .AND. Val(um->Month) == nM
         hValues["UMSATZ"]["bu_months"][nM]["ieclock"] += Round(um->Umsatz,0)
         hValues["SALES"]["bu_months"][nM]["ieclock"] += Round(um->Bookings,0)
         hValues["UMSATZ"]["bu_yearly"]["ieclock"] += Round(um->Umsatz,0)
         hValues["SALES"]["bu_yearly"]["ieclock"] += Round(um->Bookings,0)

         um->(dbSkip(1))
      ENDDO
      um->(dbSetOrder(2))
      um->(dbSetFilter({|| Left(um->Group,2) == "KO"},"Left(Group,2) == 'KO'"))
      IF ! um->(dbSeek( Str(Year(Date()),4)+Str(nM,2) )) //+"KOSO" ))
         ? "No KO found for:",Str(Year(Date()),4)+Str(nM,2) //+"KOSO"
      ENDIF
      DO WHILE Val(um->Year) == Year(Date()) .AND. Val(um->Month) == nM  // .AND. um->Group == "KOSO"
         hValues["UMSATZ"]["bu_months"][nM]["wireharness"] += Round(um->Umsatz,0)
         hValues["SALES"]["bu_months"][nM]["wireharness"] += Round(um->Bookings,0)
         hValues["UMSATZ"]["bu_yearly"]["wireharness"] += Round(um->Umsatz,0)
         hValues["SALES"]["bu_yearly"]["wireharness"] += Round(um->Bookings,0)
   
         um->(dbSkip(1))
      ENDDO
      um->(dbClearFilter())

      //this is not quite correct as all turnover of the Vehicle Components is deducted from the Rugged Components
      hValues["UMSATZ"]["bu_months"][nM]["rugged"] := hValues["UMSATZ"]["months"][nM]-hValues["UMSATZ"]["bu_months"][nM]["wireharness"]-hValues["UMSATZ"]["bu_months"][nM]["ieclock"]-hValues["UMSATZ"]["bu_months"][nM]["vehicle"]
      hValues["SALES"]["bu_months"][nM]["rugged"] := hValues["SALES"]["months"][nM]-hValues["SALES"]["bu_months"][nM]["wireharness"]-hValues["SALES"]["bu_months"][nM]["ieclock"]-hValues["SALES"]["bu_months"][nM]["vehicle"]
   NEXT
   
   //turnover per year (for elektronik) //still need to add automotive and split kabelkonfektion and IECLock out
   IF stats->(dbSeek( Str(Year(Date()),4)+"***"))
      nTurnover := Round(stats->Billings,0)
      nBookings := Round(stats->Sales,0)
   ELSE
      nTurnover := 0
      nBookings := 0
   ENDIF
   IF auto_stats->(dbSeek( Str(Year(Date()),4)+"***"))
      nTurnover += Round(auto_stats->Billings,0)
      nBookings += Round(auto_stats->Sales,0)
      hValues["UMSATZ"]["bu_yearly"]["vehicle"] := auto_stats->Billings
      hValues["SALES"]["bu_yearly"]["vehicle"] := auto_stats->Sales   
   ENDIF
   nTurnover -= hSisterTurn["current"]
   nBookings -= hSisterBook["current"]
   hValues["UMSATZ"]["yearly"] := nTurnover
   hValues["SALES"]["yearly"] := nBookings

   hValues["UMSATZ"]["bu_yearly"]["rugged"] := hValues["UMSATZ"]["yearly"]-hValues["UMSATZ"]["bu_yearly"]["wireharness"]-hValues["UMSATZ"]["bu_yearly"]["ieclock"]-hValues["UMSATZ"]["bu_yearly"]["vehicle"]
   hValues["SALES"]["bu_yearly"]["rugged"] := hValues["SALES"]["yearly"]-hValues["SALES"]["bu_yearly"]["wireharness"]-hValues["SALES"]["bu_yearly"]["ieclock"]-hValues["SALES"]["bu_yearly"]["vehicle"]



   //calculate tertial values
   FOR EACH hValue IN hValues
      FOR nX := 1 TO 12
         hValue["tertial"][Int((nX-1)/4)+1] +=hValue["months"][nX]
      NEXT
      IF HHAsKey(hValue,"avg")
         hValue["tertial"][1] := hValue["tertial"][1]/(4-IF(Month(Date()) < 4,4-Month(Date()),0))
         IF Month(Date()) >= 5
            hValue["tertial"][2] := hValue["tertial"][2]/(4-IF(Month(Date()) < 8,8-Month(Date()),0))
         ENDIF
         IF Month(Date()) >= 9
            hValue["tertial"][3] := hValue["tertial"][3]/(4-IF(Month(Date()) < 12,12-Month(Date()),0))
         ENDIF
      ENDIF
   NEXT
   //? ValToPrg(hValues)

   bAddKPIS := {|nValue,hBuValues|
      aCurrent := HB_JsonDecode(oSupa:Execute("rest/v1/kpi_values","GET",{"select"=>"target_value","kpi_id" => "eq."+aKPIs[nX]["id"], "month" => "eq."+Ltrim(Str(nM,2)), "year" => "eq."+Str(Year(Date()),4)}))
      //? ValToPrg(aCurrent)
      ? "Updating KPI:",aKPIs[nX]["id"],"Month:",nM,"Value:",nValue
      IF Len(aCurrent) >= 1 .AND. "target_value" $ aCurrent[1]         
         ? oSupa:Execute("rest/v1/kpi_values?kpi_id=eq."+aKPIs[nX]["id"]+"&"+"month=eq."+Ltrim(Str(nM,2))+"&year=eq."+Str(Year(Date()),4),"PATCH",{"current_value" => nValue,"target_value"=>aCurrent[1]["target_value"]})
      ELSE
         ? oSupa:Execute("rest/v1/kpi_values","POST",{"current_value" => nValue,"target_value"=>0,"kpi_id"=>aKPIs[nX]["id"],"month"=>nM,+"year"=>Year(Date())})
      ENDIF
      IF aKPIs[nX]["business_unit_breakdown"]
         //? nM,ValToPrg(hBuValues)
            FOR EACH nBuValue IN hBuValues
               //? nBuValue:__eNumKey(),hBu[nBuValue:__eNumKey()]           
               IF nBuValue:__eNumKey() $ hBu .AND. ! Empty(hBu[nBuValue:__eNumKey()])
                  aCurrent := HB_JsonDecode(oSupa:Execute("rest/v1/kpi_bu_values","GET",{"select"=>"current_value, target_value","kpi_id" => "eq."+aKPIs[nX]["id"], "month" => "eq."+Ltrim(Str(nM,2)), "year" => "eq."+Str(Year(Date()),4),"business_unit_id"=>"eq."+hBu[nBuValue:__eNumKey()]}))
                  //? ValToPrg(aCurrent)
                  IF Len(aCurrent) >= 1 .AND. "target_value" $ aCurrent[1]
                  oSupa:Execute("rest/v1/kpi_bu_values?kpi_id=eq."+aKPIs[nX]["id"]+"&"+"month=eq."+Ltrim(Str(nM,2))+"&year=eq."+Str(Year(Date()),4)+"&business_unit_id=eq."+hBu[nBuValue:__eNumKey()],"PATCH",{"current_value" => nBuValue,"target_value"=>aCurrent[1]["target_value"]})
                  ELSE
                  oSupa:Execute("rest/v1/kpi_bu_values","POST",{"current_value" => nBuValue,"target_value"=>0,"kpi_id"=>aKPIs[nX]["id"],"month"=>nM,+"year"=>Year(Date()),"business_unit_id"=>hBu[nBuValue:__eNumKey()]})
                  ENDIF
               ENDIF
            NEXT
        ENDIF
      RETURN NIL
   }

   FOR EACH hValue IN hValues
      ? "Updating KPIs for:",hValue["name"]
      //get all KPIs
      aKPIs := HB_JsonDecode(oSupa:Execute("rest/v1/kpis","GET",{"select"=>"id,frequency,business_unit_breakdown","link_id"=>"eq."+hValue["link_id"]}))
      ?? " Count:",Len(aKPIs)

      FOR nX := 1 TO Len(aKPIs)     
         //? aKPIs[nX]["business_unit_breakdown"]    
         IF aKPIs[nX]["frequency"] == "yearly"
            FOR nM := 1 TO 11
               Eval(bAddKPIS,0,hBuTemplate)
            NEXT 
            nM := 12
            
            Eval(bAddKPIS,hValue["yearly"],hValue["bu_yearly"])
         ELSE
            FOR nM := 1 TO 12                    
               IF  hValue["months"][nM] != 0 .AND. (aKPIS[nX]["frequency"]=="monthly" .OR. nM % 4 == 0)
                  
                  Eval(bAddKPIS,hValue["months"][nM],hValue["bu_months"][nM])
               ELSE
                  Eval(bAddKPIS,0)
               ENDIF
            NEXT
         ENDIF
      NEXT
   NEXT



   
   //-H "Authorization: Bearer SERVICE_ROLE_KEY" \
   //oSupa:cKeyName := "LOV-INT-SR"

  // ? oSupa:Execute("auth/v1/invite","POST",{"email"=>"johannes.engelking@engelking.de"})
   
   //Sinkey(0)
RETURN

#include "x:\run\supabase_api.prg"
#include "x:\run\timebutlerapi.prg"