cKunde := Pad("BULGIN",8)

   NETUSE( "engbes","bes",.F.,5 )
   bes->(dbSetOrder(2)) //kunde+str(bestat)+...
   bes->(dbSeek( cKunde ))
   
   nMilli := hb_milliseconds()
   nRecs  := 0
   Do WHILE ! bes->(EOF()) .AND. bes->liefma == cKunde
         IF Empty(bes->Rate)
            bes->(Rec_Lock())
            bes->Rate := Currate(bes->Money,"V",bes->Besda)
         ENDIF
         nPrice :=  bes->ekpr/bes->pe*If(!Empty(bes->money),bes->Rate,1)
         If bes->bestat < 3
            nOpen := ( bes->beqty - bes->gelqty )*nPrice
            nOrder := bes->beqty*nPrice
            hData["open"] += nOpen
         Else
            nOrder := bes->gelqty * nPrice
         Endif
         nValue := bes->zoqty*nPrice
            hData["unbilled_total"] += nValue
         If Year(bes->besda) == Year(Date())
            hData["unbilled_current"] += nValue
            hData["order_current"] += nOrder
         Elseif Year(bes->besda) == Year(Date())-1
            hData["unbilled_last"] += nValue
            hData["order_last"] += nOrder
         Endif
         If Year(bes->besda) >= Year(Date())-3
            hData["unbilled_last3"] += nValue
         Endif
         If ! HHasKey(hData["months"],Year(bes->besda))
            hData["months"][Year(bes->besda)] := Array(12)
            AEval(hData["months"][Year(bes->besda)],{|x,n|hData["months"][Year(bes->besda)][n] := {"bookings"=>0,"billings"=>0}} )
         Endif
         If Month(bes->Besda) == 0
    Alert( "Month:"+HB_NTos(Month(bes->besda))+" "+DToC(bes->besda)+" "+HB_Ntos(bes->besnr) )
         Endif
         hData["months"][Year(bes->besda)][Month(bes->besda)]["bookings"] += nOrder 
         nRecs++
         bes->(dbSkip( 1 ))
   Enddo
   Alert("POs: "+Str(nRecs,6)+" Records in "+Str((hb_milliseconds()-nMilli)/1000,5,2))
