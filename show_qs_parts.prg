//#include 'y:\harbour\trader\source\include\trader.ch'
#define LAG_STOCK_USABLE 2
#include 'inkey.ch'

FUNCTION RUN_SHOW_QS_PARTS
   LOCAL hItems 
   LOCAL aKwQty,nQSQty,nStock,nX,nArtnr
   LOCAL nThisWeek := CWeek(Date())
   LOCAL nNextWeek := AddWeeks(nThisWeek,1)
   LOCAL nAfterWeek := AddWeeks(nNextWeek,1)
   LOCAL nLastWeek := AddWeeks(nThisWeek,-1)
   LOCAL nBeforeLastWeek := AddWeeks(nLastWeek,-1)
   LOCAL nQSJob,cQSJob,nQSUsed   
   LOCAL hColors := {"OVER"=>"N/R*","NOW"=>"N+/GR*","NEXT"=>"N+/G*"}
   LOCAL aList := {}
   LOCAL oBrowse,oBrowseQS

   LOCAL aFirms := {},aFirm

   MEMVAR c_one

   
   
   Head("Artikel im QS Lager")


   NetUse("firms","fm")
   NetUse("firmperm","fmp")
   fm->(dbGoTop())
   DO WHILE ! fm->(EOF())
      IF fmp->(dbSeek(Str(fm->ID,3)+Str(SystemUser():ID,4)))
         Aadd(aFirms,{"ID"=>fm->ID,"NAME"=>Trim(fm->Firm),"PATH"=>Trim(fm->Pfad)+"\","LAGER"=>IF(fm->ID==2,"085","095")})
         IF Trim(fm->Pfad) == GetConfigValue("FIRMPATH")
            ATaiL(aFirms)["ID"] := 0
         ENDIF
      ENDIF
      fm->(dbSkip())
   ENDDO

   dbCloseArea()

   FOR EACH aFirm IN aFirms
      hItems := {=>}

      TxtBox({"Artikel werden geladen",aFirm:Name})

      NetUse(aFirm:Path+"artikel","art")
      NetUse(aFirm:Path+"lager","lag")
      NetUse(aFirm:Path+"jobs","job")
      NetUse(aFirm:Path+"partjobs","pjob")
      NetUse(aFirm:Path+"werkauf","wer")
      NetUse(aFirm:Path+"muster","mus")
      NetUse(aFirm:Path+"ppf","ppf")
      NetUse(aFirm:Path+"engabg","abg")

      abg->(dbSetOrder( 1 ))

      job->(dbSetOrder( 2 ))
      cQSJob := Trim(GetValue("FREPPLE_QS_JOB","QS","Job name for QS tasks"))  //we use the job set in Frepple, as this is used for planning
      IF job->(dbSeek( cQSJob ))
         nQSJob := job->Nummer
      ENDIF

      pjob->(dbSetOrder( 1 ))

      lag->(dbSetOrder( 2 ))
      lag->(dbSeek( aFirm:Lager, .T. ))
      
      DO WHILE At(aFirm:Lager,lag->Lagerort) == 1
         IF ! lag->Artikelnr $ hItems
            hItems[lag->Artikelnr] := 0
         ENDIF
         hItems[lag->Artikelnr] += lag->Lagermenge
         lag->(dbSkip())
      ENDDO
      
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
         IF ! art->(dbSeek( Str(nArtnr,6) ))
            art->(dbGoTop())
            ? "Artikel nichg gefunden:",nArtnr
         ENDIF
         
         //? ""
         
         Aadd(aList,{"MATCH"=>art->Matchcode,"ARTNR"=>art->Artikelnr,"TEXT"=>art->Matchcode+" "+PadL(Transform(nQSQty,Me(art->Me)),12),"STATUS"=>0,"NEXT"=>"ÿ","WE"=>StoD(""),"FIRM"=>aFirm:ID})
         /*IF pjob->(dbSeek( Str(art->Artikelnr,6)+Str(nQSJob,6) ))                  
            ATail(aList)["TEXT"] += " "+StrZero(Int(pjob->Seconds*nQSQty/60/60),2)+":"+StrZero(Int(Mod(pjob->Seconds*nQSQty/60,60)),2)+":"+StrZero(Mod(pjob->Seconds*nQSQty,60),2)
         ELSE*/
            ATail(aList)["TEXT"] += Space(9)         
         //ENDIF 


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
               //
               ATail(aList)["NEXT"] := Pad(IF(aKwQty[nX,1]==0,"versp„tet",IF(aKwQty[nX,1]==-1,"0 Muster",NiceWeek(aKwQty[nX,1]))),9)+" "+Trim(Transform(aKwQty[nX,2]+aKwQty[nX,4]-nStock,Me(art->Me)))

               nQSUsed += aKwQty[nX,2]+aKwQty[nX,4]-nStock
               EXIT
            ENDIF         
            nStock -= aKwQty[nX,2]+aKwQty[nX,4]         
            IF nQSQty-nQSUsed <= 0
               EXIT
            ENDIF
         NEXT

         //abg->(dbSetFilter({|| Trim(abg->Buart) == "WE" },'buart == "WE"'))
         IF abg->(dbSeek( Descend(art->Matchcode) , .T. ))
            nMenge := 0
            lExt := .F.
            DO WHILE abg->Matchcode == art->Matchcode
               //? abg->Matchcode,abg->Datum,abg->Buart
               IF Trim(abg->Buart) $ {"WE","WA"} .OR. (Trim(abg->Buart) == "UMB" .AND. AT(">"+aFirm:Lager,abg->Info) != 0)
                  ATail(aList)["WE"] := abg->Datum
                  IF ! lExt .AND. ! Empty(abg->Liefma)
                     lExt := .T.
                  ENDIF
                  nMenge += abg->Menge
                  IF nMenge >= nQSQty
                     EXIT
                  ENDIF
               ENDIF
               abg->(dbSkip())
            ENDDO
            abg->(dbSkip(-1))
            IF lExt
               IF CWeek(ATail(aList)["WE"]+10) < nThisWeek .AND. ATail(aList)["STATUS"] < 3
                  ATail(aList)["STATUS"] := 3
               ELSEIF CWeek(ATail(aList)["WE"]+10) == nThisWeek .AND. ATail(aList)["STATUS"] < 2
                  ATail(aList)["STATUS"] := 2
               ELSEIF CWeek(ATail(aList)["WE"]+10) == nNextWeek .AND. ATail(aList)["STATUS"] < 1
                  ATail(aList)["STATUS"] := 1
               ENDIF
            ENDIF

         ENDIF

         abg->(dbClearFilter())


         SetPos(Row(),00)      
         //?? art->Matchcode,PadL(Transform(nQSQty,Me(art->Me)),12)//,PadL(Transform(nStock,Me(art->Me)),12)
         /*IF pjob->(dbSeek( Str(art->Artikelnr,6)+Str(nQSJob,6) ))         
            //?? "",Str(Int(pjob->Seconds*nQSQty/60/60),2)+":"+Str(Int(Mod(pjob->Seconds*nQSQty/60,60)),2)+":"+Str(Mod(pjob->Seconds*nQSQty,60),2)         
         ELSE         
            //?? "",Space(8)
         ENDIF    */


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
         Aadd(aList,{"MATCH"=>"","TEXT"=>"","STATUS"=>-1,"NEXT"=>"","FIRM"=>aFirm:ID})
         Aadd(aList,{"MATCH"=>"","TEXT"=>"-------- IM ZULAUF AUS DER FERTIGUNG --------","STATUS"=>-1,"NEXT"=>"","FIRM"=>aFirm:ID})
         DO WHILE wer->Status == 3 .AND. ! wer->(EOF())
            art->(dbSeek( Str(wer->Artno,6) ))
            nQSQty := 0
            DO WHILE wer->Artno == art->Artikelnr .AND. ! wer->(EOF())
               nQSQty += wer->Qty-wer->GelQty
               wer->(dbSkip())
            ENDDO
            IF art->QS
               Aadd(aList,{"MATCH"=>art->Matchcode,"TEXT"=>art->Matchcode+" "+PadL(Transform(nQSQty,Me(art->Me)),12),"STATUS"=>-1,"NEXT"=>"","FIRM"=>aFirm:ID})
               //? art->Matchcode,PadL(Transform(nQSQty,Me(art->Me)),12)         
            ENDIF
         ENDDO
      ENDIF
      wer->(dbClearFilter())
      mus->(dbClearFilter())

      dbCloseAll()

      TxtClear()

   NEXT

   IF Len(aList) == 0
      Tr_MsgBox("Keine Artikel gefunden")
      RETURN .F.
   ENDIF

   NetUse("artikel","art")

   @ 02,69 TO 06,94
   @ 02,80 SAY "[ Legende ]"
   @ 03,80 SAY "šberf„llig" COLOR hColors["OVER"]
   @ 04,80 SAY "F„llig" COLOR hColors["NOW"]
   @ 05,80 SAY "N„chste Woche" COLOR hColors["NEXT"]



   ASort(aList,,,{|x,y| x["STATUS"] > y["STATUS"] .OR. (x["STATUS"] == y["STATUS"] .AND. x["NEXT"] < y["NEXT"]) })

   oBrowse := TABrowse():New(01,00,MaxRow(),76)

   oBrowse:ColorSpec := "N/W,N+/W,W/N, W/N*,N+/G*,G+/N,N+/GR*,GR+/N,N/R*,R+/N"
   //"OVER"=>"N/R*","NOW"=>"N+/GR*","NEXT"=>""
   oBrowse:AddKey(K_ESC,{|| .F.})
   oBrowse:AddKey(K_F8,{||
      IF oBrowse:CurrentDataRow()["FIRM"] == 0
         IF ! Empty(oBrowse:CurrentDataRow()["MATCH"])
            art->(dbSetOrder( 1 ))
            art->(dbSeek(oBrowse:CurrentDataRow()["MATCH"]))
         ENDIF
         BrowseArtikel()
      ELSE
         wapi_ShellExecute(,"open",HB_CmdArgArgV(),'-C '+Ltrim(Str(oBrowse:CurrentDataRow()["FIRM"]))+" -F BrowseArtikel('"+Trim(oBrowse:CurrentDataRow()["MATCH"])+"')" )
      ENDIF
      
      RETURN .T.
   })
   oBrowse:lbox := .F.

   oBrowse:NewColumn(Pad("Artikel",25)+" "+PadL("QS Menge",12)+" "+Pad("Dauer(h)",8)+" N„chste F„lligkeit  WE",{|| Pad(oBrowse:CurrentDataRow()["TEXT"]+" "+oBrowse:CurrentDataRow()["NEXT"],67)+" "+IF(HHasKey(oBrowse:CurrentDataRow(),"WE"),DtoC(oBrowse:CurrentDataRow()["WE"]),"") },{|| 
      IF ValType(oBrowse:CurrentDataRow()) != "H"
         RETURN {1,1}
      ENDIF
      IF oBrowse:CurrentDataRow()["STATUS"] == 0
         IF Mod(oBrowse:CurrentRow(),2) == 0
            RETURN {4,3}
         ENDIF
         RETURN {2,3}
      ENDIF
      RETURN {3+oBrowse:CurrentDataRow()["STATUS"]*2,4+oBrowse:CurrentDataRow()["STATUS"]*2}
   })

   oBrowse:aData := aList


   @ 20,77 SAY PadC(" Bekannte Fehler ",MaxCol()-77,Chr(196))

   NetUse("qs","qs")
   qs->(dbSetOrder( 2 ))
   qs->(dbSeek( Str(art->Artikelnr,6) ))
   oBrowseQS := qs->(TBrowseTr():New(21,77,MaxRow(),MaxCol()))
   oBrowseQS:lBox := .F.
   oBrowseQS:OneColumn := .T.
   oBrowseQS:HeadSep := ""
   oBrowseQS:NewColumn("Nummer",{|| Str(qs->Nummer,6) })
   oBrowseQS:NewColumn("Beschreibung",{|| Pad(qs->Beschreibu,60) })
   oBrowseQS:WhileBlock := {|| ValType(oBrowse:CurrentDataRow()) == "H" .AND. qs->Artnr == oBrowse:CurrentDataRow()["ARTNR"] }
   oBrowseQS:ForBlock := {|| qs->Status != 8 }  //abgelehnt ausblenden
   //oBrowseQS:AddKey(K_ENTER,{|| EditQS(qs->Nummer) })
   oBrowseQS:Display()
   oBrowseQS:deHilite()
      //Aadd(aBrowse,{oBrowse,SaveEnv()})

   oBrowse:bAnyFun := {||
      IF ValType(oBrowse:CurrentDataRow()) == "H" .AND. hHasKey(oBrowse:CurrentDataRow(),"ARTNR")         
         qs->(dbCloseArea())
         IF oBrowse:CurrentDataRow()["FIRM"] == 0
            NetUse("qs","qs")         
         ELSE
            nFirm := AScan(aFirms,{|x| x["ID"] == oBrowse:CurrentDataRow()["FIRM"]})
            NetUse(aFirms[nFirm]:Path+"qs","qs")         
         ENDIF
         qs->(dbSetOrder( 2 ))
         qs->(dbSeek( Str(oBrowse:CurrentDataRow()["ARTNR"],6) ))
         oBrowseQS:RefreshAll()
         oBrowseQS:Display()
         oBrowseQS:deHilite()
      ELSE
         SetColor(c_one)
         @ 21,77 CLEAR TO MaxRow(),MaxCol()
      ENDIF
      RETURN .T.
   }

   oBrowse:EventLoop()

   //Sinkey(0)
RETUR NIL
