//#include 'y:\harbour\trader\source\include\trader.ch'
#define LAG_STOCK_USABLE 2
#include 'inkey.ch'

FUNCTION RUN_SHOW_QS_PARTS
   LOCAL hItems := {=>}
   LOCAL aKwQty,nQSQty,nStock,nX,nArtnr
   LOCAL nThisWeek := CWeek(Date())
   LOCAL nNextWeek := AddWeeks(nThisWeek,1)
   LOCAL nAfterWeek := AddWeeks(nNextWeek,1)
   LOCAL nQSJob,cQSJob,nQSUsed   
   LOCAL hColors := {"OVER"=>"N/R*","NOW"=>"N+/GR*","NEXT"=>"N+/G*"}
   LOCAL aList := {}
   LOCAL oBrowse

   MEMVAR c_one

   
   
   Head("Artikel im QS Lager")
   
   NetUse("artikel","art")
   NetUse("lager","lag")
   NetUse("jobs","job")
   NetUse("partjobs","pjob")
   NetUse("werkauf","wer")
   NetUse("muster","mus")

   job->(dbSetOrder( 2 ))
   cQSJob := Trim(GetValue("FREPPLE_QS_JOB","QS","Job name for QS tasks"))  //we use the job set in Frepple, as this is used for planning
   IF job->(dbSeek( cQSJob ))
      nQSJob := job->Nummer
   ENDIF

   pjob->(dbSetOrder( 1 ))

   lag->(dbSetOrder( 2 ))
   lag->(dbSeek( "095", .T. ))
   
   DO WHILE At("095",lag->Lagerort) == 1
      IF ! lag->Artikelnr $ hItems
         hItems[lag->Artikelnr] := 0
      ENDIF
      hItems[lag->Artikelnr] += lag->Lagermenge
      lag->(dbSkip())
   ENDDO

   
   @ 02,69 TO 06,85
   @ 02,70 SAY "[ Legende ]"
   @ 03,70 SAY "šberf„llig" COLOR hColors["OVER"]
   @ 04,70 SAY "F„llig" COLOR hColors["NOW"]
   @ 05,70 SAY "N„chste Woche" COLOR hColors["NEXT"]

   TxtBox("Artikel werden geladen")
   
   mus->(dbSetFilter( {|| mus->Status == 0},"Status == 0"))   
   mus->(dbSetOrder( 2 ))
   //SetPos(01,00)
   //?? Pad("Artikel",25),PadL("QS Menge",12),Pad("Dauer(h)",8),"N„chste F„lligkeit" //,PadL("Lagerbestand",12)
   FOR EACH nQSQty IN hItems
      nQSUsed := 0
      nArtnr := nQSQty:__eNumKey()
      aKwQty := GetKWQty(nArtnr)  
      nStock := LagGetStock(nArtnr,LAG_STOCK_USABLE)
      art->(dbSetOrder( 2 ))
      art->(dbSeek( Str(nArtnr,6) ))
      
      //? ""
      
      Aadd(aList,{"MATCH"=>art->Matchcode,"TEXT"=>art->Matchcode+" "+PadL(Transform(nQSQty,Me(art->Me)),12),"STATUS"=>0,"NEXT"=>""})
      IF pjob->(dbSeek( Str(art->Artikelnr,6)+Str(nQSJob,6) ))                  
         ATail(aList)["TEXT"] += " "+StrZero(Int(pjob->Seconds*nQSQty/60/60),2)+":"+StrZero(Int(Mod(pjob->Seconds*nQSQty/60,60)),2)+":"+StrZero(Mod(pjob->Seconds*nQSQty,60),2)
      ELSE
         ATail(aList)["TEXT"] += Space(9)         
      ENDIF 

      FOR nX := 1 TO Len(aKwQty)
         IF aKwQty[nX,2]+aKwQty[nX,4] > nStock
            IF aKWQty[nX,1] <= nThisWeek
               ATail(aList)["STATUS"] := 3
            ELSEIF mus->(dbSeek( nArtnr ))
               aKwQty[nX,1] := -1
               ATail(aList)["STATUS"] := 2
            ELSEIF aKWQty[nX,1] <= nNextWeek 
               ATail(aList)["STATUS"] := 2
            ELSEIF aKWQty[nX,1] <= nAfterWeek 
               ATail(aList)["STATUS"] := 1
            ENDIF
            ATail(aList)["NEXT"] := Pad(IF(aKwQty[nX,1]==0,"versp„tet",IF(aKwQty[nX,1]==-1,"Muster",NiceWeek(aKwQty[nX,1]))),9)+" "+Trim(Transform(aKwQty[nX,2]+aKwQty[nX,4]-nStock,Me(art->Me)))

            nQSUsed += aKwQty[nX,2]+aKwQty[nX,4]-nStock
            EXIT
         ENDIF         
         nStock -= aKwQty[nX,2]+aKwQty[nX,4]         
         IF nQSQty-nQSUsed <= 0
            EXIT
         ENDIF
      NEXT

      SetPos(Row(),00)      
      //?? art->Matchcode,PadL(Transform(nQSQty,Me(art->Me)),12)//,PadL(Transform(nStock,Me(art->Me)),12)
      IF pjob->(dbSeek( Str(art->Artikelnr,6)+Str(nQSJob,6) ))         
         //?? "",Str(Int(pjob->Seconds*nQSQty/60/60),2)+":"+Str(Int(Mod(pjob->Seconds*nQSQty/60,60)),2)+":"+Str(Mod(pjob->Seconds*nQSQty,60),2)         
      ELSE         
         //?? "",Space(8)
      ENDIF    


   NEXT

   wer->(dbSetOrder(9))   
   Select("wer")
   SET FILTER TO wer->Status == 3 .AND. Empty(wer->Liefma)  
   wer->(dbGoTop())
   IF ! wer->(EOF()) //wer->(dbSeek( Str(3,1) ))
      art->(dbSetOrder( 2 ))     
      SetColor(c_one)
      //?      
      //? "-------- IM ZULAUF AUS DER FERTIGUNG --------"      
      Aadd(aList,{"MATCH"=>"","TEXT"=>"","STATUS"=>0,"NEXT"=>""})
      Aadd(aList,{"MATCH"=>"","TEXT"=>"-------- IM ZULAUF AUS DER FERTIGUNG --------","STATUS"=>0,"NEXT"=>""})
      DO WHILE wer->Status == 3 .AND. ! wer->(EOF())
         art->(dbSeek( Str(wer->Artno,6) ))
         nQSQty := 0
         DO WHILE wer->Artno == art->Artikelnr .AND. ! wer->(EOF())
            nQSQty += wer->Qty-wer->GelQty
            wer->(dbSkip())
         ENDDO
         IF art->QS
            Aadd(aList,{"MATCH"=>art->Matchcode,"TEXT"=>art->Matchcode+" "+PadL(Transform(nQSQty,Me(art->Me)),12),"STATUS"=>0,"NEXT"=>""})
            //? art->Matchcode,PadL(Transform(nQSQty,Me(art->Me)),12)         
         ENDIF
      ENDDO
   ENDIF
   wer->(dbClearFilter())
   mus->(dbClearFilter())

   TxtClear()

   ASort(aList,,,{|x,y| x["STATUS"] > y["STATUS"] })

   oBrowse := TABrowse():New(01,00,MaxRow(),67)

   oBrowse:ColorSpec := "N/W,N+/W,W/N, W/N*,N+/G*,G+/N,N+/GR*,GR+/N,N/R*,R+/N"
   //"OVER"=>"N/R*","NOW"=>"N+/GR*","NEXT"=>""
   oBrowse:AddKey(K_ESC,{|| .F.})
   oBrowse:AddKey(K_F8,{|| 
      IF ! Empty(oBrowse:CurrentDataRow()["MATCH"])
         art->(dbSetOrder( 1 ))
         art->(dbSeek(oBrowse:CurrentDataRow()["MATCH"]))
      ENDIF
      BrowseArtikel()
      RETURN .T.
   })
   oBrowse:lbox := .F.

   oBrowse:NewColumn(Pad("Artikel",25)+" "+PadL("QS Menge",12)+" "+Pad("Dauer(h)",8)+" N„chste F„lligkeit",{|| Pad(oBrowse:CurrentDataRow()["TEXT"]+" "+oBrowse:CurrentDataRow()["NEXT"],67) },{|| 
      IF oBrowse:CurrentDataRow()["STATUS"] == 0
         IF Mod(oBrowse:CurrentRow(),2) == 0
            RETURN {4,3}
         ENDIF
         RETURN {2,3}
      ENDIF
      RETURN {3+oBrowse:CurrentDataRow()["STATUS"]*2,4+oBrowse:CurrentDataRow()["STATUS"]*2}
   })

   oBrowse:aData := aList
   oBrowse:EventLoop()

   //Sinkey(0)
RETUR NIL
