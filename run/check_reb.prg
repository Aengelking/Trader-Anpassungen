PROC RUN_CHECK_REB
LOCAL hUsers := {=>},nCount
LOCAL dDate,hData,aSkonto
LOCAL cUser,nUser

NetUse("reb","reb")
NetUse("rebprot","rebp")
NetUse("engkund","ku")
ku->(dbSetOrder( 8 ))
NetUse("skontob","skb")

Head("Rechnungseingangsbuch ÅberprÅfen")

reb->(dbSetFilter( {|| reb->Status != 9 },"status != 9" ))
reb->(dbGotop())
DO WHILE ! reb->(EOF())
   IF ! HHasKey(hUsers,reb->Person)
      hUsers[reb->Person] := {"count"=>1,"over"=>0,"list"=>"<b>"+Pad("Index",9)+" "+Pad("Beleg",30)+" "+Pad("Lieferant/Konto",50)+" "+"Datum</b>"}
   ELSE
      hUsers[reb->Person]["count"]++
   ENDIF

   rebp->(dbSeek( Str(reb->ID,9), .T. ))
   IF reb->Liefnr != 0       
      ku->(dbSeek( Str(reb->Liefnr,6) ))        
      IF ! IsPrePay(ku->Skonto)
         aSkonto := skb->(GetSkonto(ku->Skonto,StoD(rebp->DateTime)))
         dDate := AddWorkingDays(StoD(rebp->DateTime)+IF(aSkonto[1,2]==0.AND.Len(aSkonto)>1,aSkonto[2,2],aSkonto[1,2]),2*-1,GetConfigValue("STATE"),.T.)         
      ELSE
         dDate := StoD(rebp->DateTime)+13 //nach 15 Tagen kommt die Meldung, dass die Rechnung fehlt         
      ENDIF      
   ELSE
      dDate := StoD(rebp->DateTime)+5 //standard ist 5 Tage nach erhalt, das sollte auch fÅr Skonto reichen
   ENDIF
   IF dDate <= Date()
      hUsers[reb->Person]["over"]++
   ENDIF      
   hUsers[reb->Person]["list"] += Chr(13)+Chr(10)
   IF dDate <= Date()
      hUsers[reb->Person]["list"] += '<font color="red">'
   ENDIF
   hUsers[reb->Person]["list"] += Str(reb->ID,9)+" "+reb->Beleg+" "
   IF reb->Liefnr == 0
      hUsers[reb->Person]["list"] += Pad(Trim(reb->Name)+" ("+LTrim(Str(reb->Konto))+")",50) // Pad("Kreditor "+LTrim(Str(reb->Konto)),50)
   ELSE
      ku->(dbSetOrder( 8 ))
      ku->(dbSeek( Str(reb->Liefnr,6) ))
      hUsers[reb->Person]["list"] += Pad(Trim(ku->Name1)+" "+ku->Name2,50)
   ENDIF
   hUsers[reb->Person]["list"] += " "+DtoC(dDate)
   IF dDate <= Date()
      hUsers[reb->Person]["list"] += '</font>'
   ENDIF

   reb->(dbSkip())
ENDDO

FOR EACH hData IN hUsers
   nCount := hData["count"]
   nUser := hData:__enumkey()
   cUser := Buy(nUser,.T.)
   ? cUser,GetUserEmail(nUser),nCount,hData["over"]
   IF ! EMPTY(cUser)
      Sendmail({{GetUserEmail(nUser),cUser}},LTrim(Str(nCount))+IF(hData["over"] > 0," ("+LTrim(Str(hData["over"]))+" fÑllige)","")+" Rechnung"+IF(nCount>1,"en","")+" im Eingangsbuch",hData["list"])
   ENDIF
   IF hData["over"] > 0 .AND. nUser != 9
      //Sendmail({{GetUserEmail(9),Buy(9,.T.)}},LTrim(Str(hData["over"]))+" fÑllige Rechnung"+IF(nCount>1,"en","")+" in "+Left(cUser,AT(" ",cUser)-1)+IF(Right(Left(cUser,AT(" ",cUser)-1),1)=="s","'","s")+" Eingangsbuch",hData["list"])      
      IF nUser == 50
         SendSMS({"+4915779388510"},"Bitte dringend Rechnungen verbuchen! Du hast "+LTrim(Str(hData["over"]))+" fÑllige Rechnung"+IF(nCount>1,"en","")+" in Deinem Eingangsbuch")
      ENDIF
   ENDIF   
NEXT


