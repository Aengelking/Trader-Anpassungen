#include 'y:\hb32\include\inkey.ch'
FUNCTION Auftrag_Beleg(cMsgId)

LOCAL aAutoBeleg := {}
LOCAL hResults
LOCAL bFilter
LOCAL dWDatum

LOCAL nX,nY,nSt
MEMVAR cFilter
PRIVATE cFilter

IF .F. //Tr_Getini(28) == 9   //testing heidelberger   
   RUN_CollectAndProcess_LE({;
         "KUNDE"=>15958,;
         "PRODFREIGABE"=>3,;  //Anzahl Monate Produktionsfreigabe
         "MATFREIGABE"=>6;  //Anzahl Monate Produktionsfreigabe      
      }) 
      /*hSettings := {;
         "KUNDE"=>15958,;
         "PRODFREIGABE"=>3,;  //Anzahl Monate Produktionsfreigabe
         "MATFREIGABE"=>6;  //Anzahl Monate Produktionsfreigabe      
      }
      hHead := {=>}
      aData := {}
      hHead["FRAME"] := Pad("99356571",20) 
      hHead["LASTWE"] := 57490
      dDate := StoD("20201001")  
      hHead["MATDATE"] := AddMonth(dDate,hSettings["MATFREIGABE"])
      hHead["PRODDATE"] := AddMonth(dDate,hSettings["PRODFREIGABE"])
      hHead["ORDER"] := Pad(Str(5701235980,10),20)      
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20201006")})
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20201007")})
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20201013")})
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20201016")})      
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20201023")})   
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20201030")})      
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20201111")})      
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20201118")})
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20201125")})      
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20201202")})
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20201209")})
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20210108")})
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20210109")})
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20210112")})
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20210119")})
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20210126")})

      Aadd(aData,{"QTY"=>4000,"DATE"=>SToD("20210201")})
      Aadd(aData,{"QTY"=>4000,"DATE"=>SToD("20210301")})
      Aadd(aData,{"QTY"=>5000,"DATE"=>SToD("20210401")})
      Aadd(aData,{"QTY"=>5000,"DATE"=>SToD("20210501")})
      Aadd(aData,{"QTY"=>3000,"DATE"=>SToD("20210601")})
      Aadd(aData,{"QTY"=>3000,"DATE"=>SToD("20210701")})
      Aadd(aData,{"QTY"=>1000,"DATE"=>SToD("20210801")})
      Aadd(aData,{"QTY"=>4000,"DATE"=>SToD("20210901")})
      Aadd(aData,{"QTY"=>2000,"DATE"=>SToD("20211001")})
      Aadd(aData,{"QTY"=>3000,"DATE"=>SToD("20211101")})
      Aadd(aData,{"QTY"=>3000,"DATE"=>SToD("20211201")})



   
      ProcessSalesOrder(hSettings["KUNDE"],hHead,aData)
      RETURN*/
ENDIF

Aadd(aAutoBeleg,{;
   "EMAIL"=>"@veratron.com$",;
   "FILE"=>".*.pdf",;
   "BLOCK"=>{|oMsg,cFile|
      LOCAL aData
      LOCAL oAuftrag

      HB_SYMBOL_UNUSED(oMsg)

      Head("Automatische Auftragsverarbeitung")

      IF Tr_MsgBox("Ist "+cFile+" eine Liefereinteilung?",,{"Ja","Nein"}) == 1

         TxtBox("Daten werden eingelesen...")
         aData := GetDataFromPDF(cFile,{"-a 512,0.0,840,550 -c 19,80,250 -p 1"},{=>},{"ORDER"=>"Number\s*([0-9]{10})","MATDATE"=>"go-ahead\s*for\s*procurement\s*until\s*:\s*([0-9]{2}.[0-9]{2}.[0-9]{4})"},@hResults,,{"DATE"=>2,"QTY"=>3,"CHANGEQTY"=>4})
         TxtClear()
         SetPos(1,0)
         //? ValToPrg(aData)
         //? ValToPrg(hResults)
         //SInkey(0)
      

         hResults["ORDER"] := Pad(hResults["ORDER"],20)
         hResults["MATDATE"] := CtoD(hResults["MATDATE"])  
         hResults["PRODDATE"] := hResults["MATDATE"] 
         hResults["FRAME"] := hResults["ORDER"] 
         hResults["LASTWE"] := 0

         IF ! ProcessSalesOrder(30002,hResults,aData,@oAuftrag)
            RETURN .F.
         ENDIF

         RETURN .T.
      ENDIF
      RETURN .F.
   };
})
//   "FILE"=>"Lieferplan.*.pdf",;
Aadd(aAutoBeleg,{;
   "EMAIL"=>"\+49\s*\(?6222\)?\s*8\s*2\s*9\s*9.*|[^@\s]*@heidelberg.com|0622192699",;
   "BLOCK"=>{|oMsg,cFile|
      HB_SYMBOL_UNUSED(oMsg)
      HB_SYMBOL_UNUSED(cFile)
      IF Tr_MsgBox("Ist dies eine Liefereinteilung?",,{"Ja","Nein"}) != 1
         RETURN .F.
      ENDIF
      RETURN RUN_CollectAndProcess_LE({;
         "KUNDE"=>15958,;
         "PRODFREIGABE"=>3,;  //Anzahl Monate Produktionsfreigabe
         "MATFREIGABE"=>6;  //Anzahl Monate Materialfreigabe      
      })      
   };
})

/* FOR this we need the part number, as we have multiple parts on one frame contract
Aadd(aAutoBeleg,{;
   "EMAIL"=>".*@schneiderfertigung\.com$",;
   "BLOCK"=>{|oMsg,cFile|
      HB_SYMBOL_UNUSED(oMsg)
      HB_SYMBOL_UNUSED(cFile)
      IF Tr_MsgBox("Ist dies eine Liefereinteilung?",,{"Ja","Nein"}) != 1
         RETURN .F.
      ENDIF
      RETURN RUN_CollectAndProcess_LE({;
      "KUNDE"=>29691,;
      "PRODFREIGABE"=>999,;  //Anzahl Monate Produktionsfreigabe
      "MATFREIGABE"=>999;  //Anzahl Monate Produktionsfreigabe      
   })      
   };   
})*/


IF ! AutoBeleg(aAutoBeleg,cMsgId)
   Engauft()
ENDIF


#include 'X:\run\auto_beleg.prg'


FUNCTION ProcessSalesOrder(nKunde,hResults,aData,oAuftrag)
   LOCAL cFilter,cFilter2
   LOCAL cKunde
   LOCAL oPos,oContract
   LOCAL dWDatum,nContract
   LOCAL nX,cME
   LOCAL cFileName := GetConfigValue("attachfile")
   LOCAL nOpenQty := 0
   LOCAL nNotWeQty := 0

      NetUse("engkund","ku")
      ku->(dbSetOrder( 8 ))
      ku->(dbSeek( Str(nKunde,6) ))
      cKunde :=  ku->Kunde
   
      NetUse("artikel","art")
      art->(dbSetOrder( 2 ))
      NetUse("engauf","auf")      
      NetUse("auftrag","ab")
      NetUse("englsre","re")


      cFilter := "Right(Str(auf->Dterm,4),2) == '99'"  //Rahmenposition suchen
      auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter))
      auf->(dbSetORder( 12 ))
      IF ! auf->(dbSeek( cKunde+Trim(hResults["FRAME"]) ))
         Tr_MsgBox("Auftrag "+hResults["FRAME"]+" nicht gefunden!")
         RETURN .F.
      ENDIF
      auf->(dbClearFilter())
      IF ! LockEntity("AUF",auf->Abnr)
         RETURN .F.
      ENDIF
      art->(dbSeek( Str(auf->Artikelnr,6) ))

      oAuftrag := Auftrag():New(.F.)
      oAuftrag:Load(auf->Abnr)

      cFilter := "BeStat <= 7 .AND. GelQty == 0 .AND. Right(Str(auf->Dterm,4),2) != '99'"  

      //auf->(dbSetFilter({|| auf->(&cFilter) },cFilter)) //all (auch erledigte) ungenutzte positionen
      
      
      cMe := Me(art->Me)
      FOR nX := 1 TO Len(aData)
         IF ValType(aData[nX]["QTY"]) == "C"             
            aData[nX]["QTY"] := Val(StrTran(aData[nX]["QTY"],".",""))
         ENDIF
         IF ValType(aData[nX]["DATE"]) == "C"
            aData[nX]["DATE"] := CtoD(aData[nX]["DATE"])
         ENDIF
         IF aData[nX]["QTY"] == 0 .OR. Empty(aData[nX]["DATE"])
            HB_ADel(aData,nX,.T.)
            nX--
         ENDIF
      NEXT
      nX= 0
      
      CLS

      //auf->(dbClearFilter()) //we need to check all old positions if they have been shipped but not received by customer yet, therefor we remove the filter
      IF hResults["LASTWE"] == 0  //if lastwe is not set we just delete all "old" matching pos which have already been shipped
         oAuftrag:Positions:Each({|oPos|
            LOCAL nR
            dWdatum := oPos:WDatum
            IF auf->GelQty != 0 .AND. Right(Str(auf->Dterm,4),2) != '99' .AND. (nR := AScan(aData,{|aD| aD["DATE"] == dWDatum})) != 0 //delete all positions from aData if they have already been shipped
               HB_ADel(aData,nR,.T.)
            ENDIF            
            RETURN NIL
         })
      ELSE
         re->(dbSetOrder( 10 ))   
         ? "Suche letzte Lieferung...."
         cFilter2 := "RePosnr != 0 .AND. Rechnr > "+LTrim(Str(hResults["LASTWE"]))+" .AND. artikelnr == "+LTrim(str(art->Artikelnr))
         re->(dbSetFilter({|| re->(&(cFilter2)) },cFilter2))
         re->(dbSeek( Str(oAuftrag:AbNr,6) ))
         DO WHILE re->Abnr == oAuftrag:AbNr
            nNotWeQty += re->AoQty
            re->(dbSkip())
         ENDDO
         ?? "Menge ohne WE ",Transform(nNotWeQty,cMe)
         re->(dbClearFilter())
         DO WHILE nNotWeQty > 0
            IF aData[1]["QTY"] > nNotWeQty
               aData[1]["QTY"] -= nNotWeQty
               nNotWeQty := 0
            ELSE
               nNotWeQty -= aData[1]["QTY"]
               HB_ADel(aData,1,.T.)
            ENDIF
         ENDDO         
      ENDIF

      
      ? "Setze alles auf erledigt..."
      //alle Positionen auf erledigt setzten, damit die neuen Liefertermin richtig gesetzt werden
      oAuftrag:Positions:Each({|oPos|
         IF ! oPos:IsRahmen 
            //oContract:ContrQty -= oPos:VkQty
            IF oPos:GelQty != 0  //diese Position wird zukÅnftig nicht mehr verwendet. Daher reduzieren wir die Rahmenmenge
               oPos:ContractPosition:ContrQty -= oPos:VkQty-oPos:GelQty
               oPos:VkQty := oPos:GelQty
            ENDIF
               
            oPos:BeStat := 3
            oPos:Auftrag:Save(.T.)                       
         ENDIF            
         RETURN NIL
      })
      //?? " Tastendruck"; Sinkey(0)

      IF Tr_Getini(28) == 9
         //Alert("All open positions have been reset")
      ENDIF
         

      auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter)) //Filter wieder aktivieren
      auf->(dbSetORder( 1 ))
      auf->(dbSeek( Str(oAuftrag:Abnr,6) , .T. ))
      //auf->(dbSeek( cKunde+Trim(hResults["ORDER"]) ))
      DO WHILE auf->Abnr == oAuftrag:Abnr //auf->Kundma == cKunde .AND. auf->Aufnr == hResults["ORDER"]
         nX++
         ? auf->Abnr,auf->Itmnr,auf->Dterm

         auf->(dbClearFilter()) //need to clear the filter, otherwise the position cannot acces the contractposition
         oPos := oAuftrag:Positions:GetRecord(auf->Itmnr)
         oContract := oPos:ContractPosition
         //extend the contract if necessary
         //oContract:WTerm := Max(Max(oPos:Wterm,oPos:DTerm),oContract:Wterm)
         oContract:WTerm := Max(CWeek(aData[nX]["DATE"]),oContract:Wterm)

         oContract:Save()

         IF nX > Len(aData) .OR. aData[nX]["DATE"] > hResults["MATDATE"] .OR. aData[nX]["DATE"] < oAuftrag:Besda
            IF /*oPos:BeStat < 3 .OR.*/ oPos:VkQty != 0
               ? t("Lˆsche "),Transform(oPos:VkQty,cMe),art->me,auf->WDatum                            
               oContract:ContrQty -= oPos:VkQty
               oPos:BeStat := 3               
               oPos:VkQty := 0
               oPos:Save()
            ELSE
               ? t("Belasse "),Transform(auf->VkQty,cMe),art->me,auf->WDatum
               oPos:Aufnr    := hResults["ORDER"] 
               oPos:Save()
               IF nX <= Len(aData)
                  ?? "",aData[nX]["DATE"],hResults["MATDATE"],aData[nX]["QTY"]
               ENDIF
            ENDIF
         ELSE
            ? "Setze ",Transform(aData[nX]["QTY"],cME),art->Me,aData[nX]["DATE"],"bisher: ",auf->WDatum
            oContract:ContrQty += aData[nX]["QTY"]-oPos:VkQty

            oPos:Aufnr    := hResults["ORDER"] 
            oPos:VkQty := aData[nX]["QTY"]
            oPos:WDatum := aData[nX]["DATE"]  //wterm is set automatically when wdatum is set
            IF hResults["PRODDATE"] >= aData[nX]["DATE"]
               oPos:BeStat := 0               
            ELSE //falls nicht zur produktion freigegeben pos auf erl setzten
               oPos:BeStat := 3
               ?? " (nicht freigegeben)"
               nOpenQty += oPos:VkQty
            ENDIF

            IF Tr_getini(28) == 9
               //AltD()
            ENDIF
            //oPos:UpdateDTerm()
            IF oPos:HasValidationErrors()
               Tr_MsgBox("Fehler in Position: "+ValToPrg(oPos:GetValidationResult()))
            ENDIF
            ?? " Liefertermin:",oPos:Dterm,oPos:BDatum
            oPos:Save()            
         ENDIF
         //IF ! oPos:lErledigt
            //oContract:ContrQty -= oContract:VkQty-nOpenQty
            //oContract:VkQty := nOpenQty
         //ENDIF
         

         auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter)) //now we reset the filter
         auf->(dbSkip())
         //?? " Tastendruck";Sinkey(0)
      ENDDO
      auf->(dbClearFilter())

      //öbrige positionen jetzt hinzufÅgen
      IF nX < Len(aData)
         //look for contract pos
         nContract := 0
         cFilter := "Right(Str(auf->Dterm,4),2) == '99'"
         auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter)) //alle rahmenposition
         auf->(dbSetORder( 12 ))
         auf->(dbSeek( cKunde+hResults["FRAME"] ))
         DO WHILE auf->Kundma == cKunde .AND. auf->Aufnr == hResults["FRAME"] .AND. ! auf->(EOF())
            nContract := auf->Itmnr
            auf->(dbSkip())
         ENDDO
         auf->(dbClearFilter())
         oContract := oAuftrag:Positions:GetRecord(nContract)
      ENDIF

      DO WHILE nX < Len(aData)
         nX++
         IF aData[nX]["DATE"] <= hResults["MATDATE"] .AND. aData[nX]["DATE"] >= oAuftrag:Besda
            ? "Neu ",Transform(aData[nX]["QTY"],cME),art->Me,aData[nX]["DATE"]
            oPos := oAuftrag:Positions:NewRecord()
            oPos:Matchcode := oContract:Matchcode
            oPos:ContrPos := nContract

            oContract:ContrQty += aData[nX]["QTY"]

            oPos:VkQty     := aData[nX]["QTY"]
            oPos:VkPr      := oContract:VkPr
            oPos:Pe        := oContract:Pe

            oPos:Aufnr    := hResults["ORDER"] 
            oPos:WDatum   := aData[nX]["DATE"]

//            oPos:UpdateDterm()
            IF hResults["PRODDATE"] >= aData[nX]["DATE"]
               oPos:BeStat := 0
            ELSE //falls nicht zur produktion freigegeben pos auf erl setzten
               oPos:BeStat := 3
               nOpenQty += oPos:VkQty
            ENDIF

            oPos:Save()

            //oContract:ContrQty += oContract:VkQty+nOpenQty
            //oContract:VkQty := nOpenQty
            oContract:WTerm := Max(Max(oPos:Wterm,oPos:DTerm),oContract:Wterm)
            oContract:Save()

            //set lastchange - this will cause the order to be rechecked
            oAuftrag:LastChange := TtoS(DateTime())
            oAuftrag:Save()
            //?? " Tastendruck..."; Sinkey(0)
         ENDIF         
      ENDDO

      IF ! Hook("has_archive_file",{"AUF",oAuftrag:AbNr,cFileName,FileDate(cFileName),FileTime(cFileName)}) //attach the file if the file has not already been attached
         IF Tr_Getini(28) != 9
            AddAttachedFileToArchive("AUF",oAuftrag:AbNr,.T.,.F.)
         ENDIF
      ELSE 
         DeleteAttachedFile() //delete attached file so it does not get attached later on
      ENDIF
      IF Tr_Getini(28) == 9
         ? "Finished"
         Sinkey()
      ENDIF

      Tr_MsgBox("Automatische Verarbeitung abgeschlossen.")
      __KeyBoard(Chr(13)+Chr(K_PGDN)) //direkt in die positionen gehen
      Engauft(oAuftrag:AbNr)
      UnLockEntity("AUF",oAuftrag:AbNr)

RETURN .T.

FUNCTION RUN_CollectAndProcess_LE(hSettings)
   LOCAL aData := {}
   LOCAL hHead := {=>}
   LOCAL getlist := {}
   LOCAL nSt := 6
   LOCAL nR := nSt
   LOCAL nNr := 0
   //LOCAL nAbruf := 0
   LOCAL oAuftrag   
   LOCAL cFile,aDir
   LOCAL cPath := Path("import\auftrag\")
   LOCAL aSaved
  
   LOCAL dDate := CToD("")


   Head("Eingabe Bestelldaten")

   NetUse("rechnung","reh")   

   hHead["FRAME"] := Space(20)    
   hHead["LASTWE"] := 0

   IF Tr_Getini(28) == 9 .AND. Tr_MsgBox("Letzter Stand einlesen?",,{"Ja","Nein"}) == 1
      aDir := Directory(cPath+StrZero(hSettings["KUNDE"],6)+"*.db")
      IF Len(aDir) >= 1
         cFile := Atail(aDir)[1]     
      
         aSaved := HB_DeSerialize(MemoRead(cPath+cFile))
         //Alert(ValToPrg(aSaved))
         hHead := aSaved[1]
         aData := aSaved[2]
         IF Len(aSaved) >= 3
            dDate := aSaved[3]
         ENDIF
         nNr := VaL(hHead["ORDER"])
      ENDIF
   ENDIF


   @ 01,00 SAY "Datum                " GET dDate VALID dDate <= Date()
   @ 02,00 SAY "Rahmenbestellung     " GET hHead["FRAME"] PICTURE "99999999" VALID ! Empty(hHead["FRAME"])
   @ 03,00 SAY "Liefereinteilung Nr. " GET nNr PICTURE "9999999999" VALID nNr != 0
   @ 04,00 SAY "Letzter Wareneingang " GET hHead["LASTWE"] PICTURE "99999" VALID {|| hHead["LASTWE"] == 0 .OR. (reh->(dbSeek(Str(hHead["LASTWE"],6))) .AND. reh->KuNummer == hSettings["KUNDE"])}
   @ 04,30 SAY ("Lieferscheinnummer")
   //@ 04,00 SAY "Abruf Nr.            " GET nAbruf PICTURE "999" VALID nAbruf != 0
   //@ 05,00 SAY "Kundenartikelnummer  " GET cPart 
   @ 05,00 SAY "Liefereinteilung:"
   READ SAVE
   IF LastKey() == 27
      RETURN .F.
   ENDIF


   DO WHILE LastKey() != 27
      IF nR-nSt+1 > Len(aData)
         Aadd(aData,{"QTY"=>0,"DATE"=>CToD("")})
      ENDIF
      @ nR,00 SAY "Datum" GET aData[nR-nSt+1]["DATE"]
      @ nR,15 SAY "Menge" GET aData[nR-nSt+1]["QTY"]
      ReadModal(getlist,(nR-nSt)*2+nSt-1)   
      
      IF Empty(aData[nR-nSt+1]["DATE"])
         EXIT
      ENDIF
      nR++
   ENDDO

   IF LastKey() == 27 .AND. (Len(aData) > 1 .OR. ! Empty(aData[1]["DATE"])) .AND. Tr_MsgBox("Verarbeiten?",,{"Ja","Nein"}) != 1
      RETURN .F.
   ENDIF

   hHead["MATDATE"] := AddMonth(dDate,hSettings["MATFREIGABE"])
   hHead["PRODDATE"] := AddMonth(dDate,hSettings["PRODFREIGABE"])
   hHead["ORDER"] := Pad(Str(nNr,10),20)

   MemoWrit(cPath+StrZero(hSettings["KUNDE"],6)+"_"+TtoS(DateTime())+".db",HB_Serialize({hHead,aData,dDate}))
   
   ProcessSalesOrder(hSettings["KUNDE"],hHead,aData,@oAuftrag)

   RETURN .T.
