//Sicherheitsbestände Gessmann
//Abrufaufträge werden von Gessmann vollständig eingeteilt, jedoch sollen wir bis zum letzten Abruf den Mindestbestand als Sicherheitsbestand führen
LOCAL nX,nAbNr,hMindest,hMind
LOCAL nCurWeek := Val(CalWeek(Date()))
LOCAL cText := ""
LOCAL aTo := {{"gf","Amos"}}
LOCAl nStock,nMindest

NetUse("engauf","auf")
NetUse("artikel","art")

auf->(dbSetOrder( 11 )) //kundma+Str(abnr,6)
auf->(dbSeek( "GESSMANN" ))

DO WHILE auf->Kundma == "GESSMANN" .AND. ! auf->(EOF())
   nAbNr := auf->AbNr
   hMindest := {=>}
   art->(dbSetOrder( 1 ))
   DO WHILE auf->AbNr == nAbNr
      lCallOff := Right(Str(auf->dterm,4),2)=="99"
      nOpen := IF(auf->bestat>=3,0,auf->vkqty-auf->gelqty)
      art->(dbSeek(auf->matchcode))

      IF ! HHasKey(hMindest,art->Artikelnr)
         hMindest[art->Artikelnr] := {"MINSTOCK"=>0,"OPEN"=>0,"CALLOFFS"=>{}}
      ENDIF

      IF lCallOff  //Rahmen
         hMindest[art->Artikelnr]["MINSTOCK"] += auf->MeldStock
         hMindest[art->Artikelnr]["OPEN"]     += nOpen
      ELSEIF ! Empty(auf->ContrPos) //Abrufposition
         IF auf->Bestat < 3 .AND. nOpen > 0
            //hMindest[art->Artikelnr]["LASTCALL"] := Max(auf->DTerm,hMindest[art->Artikelnr]["LASTCALL"])
            Aadd(hMindest[art->Artikelnr]:CallOffs,{"TERM"=>auf->DTerm,"QTY"=>nOpen})
         ENDIF
      ENDIF
      auf->(dbSkip())
   ENDDO
   ASort(hMindest[art->Artikelnr]:CallOffs,,,{|x,y| x:Term < y:Term })
   art->(dbSetOrder( 2 ))
   FOR EACH hMind IN hMindest
      IF hMind:MINSTOCK != 0 .AND. hMind:Open < hMind:MinStock .AND. Len(hMind:CallOffs) > 0 //IF open is bigger or equal to minstock then the standard prog will warn
         art->(dbSeek( Str(hMind:__enumKey(),6)))
         nLZ := If(art->lz==0,12,art->lz)
         nLZTerm := AddWeeks(nCurWeek,nLZ)
         IF nLZTerm < ATail(hMind:CallOffs):Term  //if last call off is within del-time no warning
            nStock := GetKWStock(art->artikelnr,AddWeeks(nCurWeek,nLz))
            //calculate minmum stock, either the value set or the total of all call ofs legt
            nMindest := 0
            AEval(hMind:CallOffs,{|x| IF(x:Term > nLZTerm,nMindest += x:Qty,"") })
            nMindest := Min(hMind:MinStock,nMindest)

            IF nStock < nMindest
               cText += "<br />"+art->Matchcode+" Mindestbestand: "+LTrim(Transform(nMindest,Me(art->Me)))+" "+art->Me+". Bestand in "+LTrim(Str(nLz))+ " Wochen: "+LTrim(Transform(nStock,Me(art->me)))
            ENDIF
         ENDIF
      ENDIF
   NEXT
ENDDO
IF ! Empty(cText)
   SendMail(aTo,HB_AnsiToOem("GESSMANN Mindestbestände unterschritten"),"<pre>"+cText+"</pre>",,,,.T.)
ENDIF
