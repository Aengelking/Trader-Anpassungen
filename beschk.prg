FUNCTION HRBMAIN(cMsgId)

LOCAL cAbnr
LOCAL aData
LOCAL cFile
LOCAL hResults
LOCAL aAutoOC := {}
LOCAL nX

Aadd(aAutoOC,{;
   "EMAIL"=>".*@wh-tech.pl",;
   "FILE"=>"[0-9]{8}\.pdf",;
   "BLOCK"=>{|oMsg,cFile|
      HB_SYMBOL_UNUSED(oMsg)
      TxtBox("Daten werden eingelesen... ")
      //348
      aData := GetDataFromPDF(cFile,{"-a 330,26,731,567 -c 40,120,280,335,385,415,490,540"},{},{"PO"=>"Order\s*No\.\s*:\s*([0-9]*)","AB"=>"No\.\s*:\s*([0-9]{8})"},@hResults,,{"PART"=>2,"DATE"=>4,"QTY"=>5,"PE"=>6,"PRICE"=>7})      
      TxtClear()
      //MemoEdit(ValToPrg(aData))
      IF HHasKey(hResults,"AB") .AND. HHasKey(hResults,"PO")
         FOR nX := 1 TO Len(aData)
            IF HB_RegexMatch("(58|52)\.",aData[nX]:Part) 
               IF AT("KS17535/",aData[nX]:Part) == 0
                  aData[nX]:Part := "KS17535/"+aData[nX]:Part
               ENDIF
               IF Right(Trim(aData[nX]:Part),3) != ".00"
                  aData[nX]:Part := aData[nX]:Part+".00"
               ENDIF
            ENDIF
            IF AT("P",aData[nX]:Part) == 1
               aData[nX]:Part := "p"+SubStr(aData[nX]:Part,2)
            ENDIF
            aData[nX]:Pe := "100"
         NEXT
         //SInkey(0)
         //Alert(ValToPrg(aData))
         RETURN ProcessOCData(aData,Pad("WHTECH",8),hResults["AB"],Val(hResults["PO"]),,{"dd.mm.yyyy"},,.T.,,{|cPart| cPart } )
         //RETURN .T.
      ENDIF
      RETURN .F.
   };
})


Aadd(aAutoOC,{;
   "EMAIL"=>"((onpow@vip\.163\.com)|(.*@onpow\.com))$",;
   "FILE"=>"\.doc$",;
   "BLOCK"=>{|oMsg,cFile|
      HB_SYMBOL_UNUSED(oMsg)
      cAbnr := StrTran(Upper(SubStr(cFile,RAT("\",cFile)+1)),".DOC")

      aData := GetDataFromDoc(cFile,{"PO"=>"PO","PART"=>"PART","QTY"=>"QTY","PRICE"=>"PRICE","DATE"=>"DATE"})
      RETURN ProcessOCData(aData,Pad("ONPOW",8),cAbNr,0,,{"dd/mm/yy","yyyy-mm-dd"},"FREIGHT",,,{|cPart| StrTran(cPart,"-ONPOW","")} )
   };
})
Aadd(aAutoOC,{;
   "EMAIL"=>"bulgin.com$",;
   "FILE"=>"\.pdf$",; //"^(Confirm.*|E|)[0-9]{1,}.*.pdf",;
   "BLOCK"=>{|oMsg,cFile|
      HB_SYMBOL_UNUSED(oMsg)
      TxtBox("Daten werden eingelesen... ")
//      aData := GetDataFromPDF(cFile,{"-a 326,16.0,746.22,585 -p 1","-a 232,16.0,704.3312,585 -p 2"},{"PART"=>"PART\s*NO","QTY"=>"QTY","PRICE"=>"PRICE","DATE"=>"ESTIMATED"},{"PO"=>"Customer Order No:s*([0-9]*)","AB"=>"Order No:\s*(E[0-9]{1,})"},@hResults)
      aData := GetDataFromPDF(cFile,{"-a 333,18.0,695,585 -a 333,695,746,585 -p 1 -t","-a 232,16.0,704.3312,585 -p 2"},{"PART"=>"PART\s*NO","QTY"=>"QTY/UOM","PRICE"=>"UNIT PRICE","DATE"=>"ESTIMATED"},{"PO"=>"Customer Order No:\s*([0-9]*)","AB"=>"Order No:\s*(E[0-9]{1,})"},@hResults)
      //aData := GetDataFromPDF(cFile,{},{"PART"=>"PART\s*NO","QTY"=>"QTY/UOM","PRICE"=>"UNIT PRICE","DATE"=>"ESTIMATED"},{"PO"=>"Customer Order No:\s*([0-9]*)","AB"=>"Order No:\s*(E[0-9]{1,})"},@hResults)
      TxtClear()
      IF HHasKey(hResults,"AB") .AND. HHasKey(hResults,"PO")
         //Alert(ValToPrg(hResults))
         //Alert(ValToPrg(aData))
         RETURN ProcessOCData(aData,Pad("BULGIN",8),hResults["AB"],Val(hResults["PO"]),,"dd/mm/yy","(Customer\s*Part\sNo|Part No)",,,{|cPart| HB_RegexReplace("\/SP$",cPart,"") })
      ENDIF
      RETURN .F.
   };
})

//open order report
/*Aadd(aAutoOC,{;
   "EMAIL"=>"bulgin.com$",;
   "FILE"=>".*Open.*Order.*\.xlsx",;
   "BLOCK"=>{|oMsg,cFile|
      LOCAL dDate
      HB_SYMBOL_UNUSED(oMsg)
      TxtBox("Daten werden eingelesen...")
      aData := GetDataFromDoc(cFile,{"PART"=>"Sales\s*Part","QTY"=>"Quantity","DATE"=>"Comment","PO"=>"Customer\s*Po\s*No","AB"=>"Order\s*No"},{=>},@hResults)
      TxtClear()
      FOR nX := 1 TO Len(aData)
         dDate := StoD("19000101")-2+Val(aData[nX]["DATE"])
         IF dDate < Date()-30
            IF ! Empty(aData[nX]["PO"]) //.AND. AT("=",aData[nX]["DATE"]) != 1
               Tr_MsgBox({"Bestellung: "+aData[nX]["PO"],"Artikel: "+aData[nX]["PART"],"Menge: "+aData[nX]["QTY"],"AB: "+aData[nX]["AB"],"Termin: "+IF(dDate<StoD("20000101"),aData[nX]["DATE"],DtoC(dDate))},"Termin unklar")
            ENDIF
            HB_ADel(aData,nX,.T.)
            nX--
         ELSE
            aData[nX]["DATE"] := DtoC(dDate)
         ENDIF
      NEXT
      RETURN ProcessOCData(aData,Pad("BULGIN",8),"",,,"dd.mm.yy","(Customer\s*Part\sNo|Part No)",,,{|cPart| HB_RegexReplace("\/SP$",cPart,"") })
   };
})*/



/*
EDAC schickt die PDF dateien nur als Bild, daher müssten wir diese zuerst durch eine OCR jagen
Aadd(aAutoOC,{;
   "EMAIL"=>"edac.net$",;
   "FILE"=>"[0-9]{1,}.*\.pdf",;
   "BLOCK"=>{|oMsg,cFile|
      TxtBox("Daten werden eingelesen...")
      aData := GetDataFromPDF(cFile,{"-a 250,33,633,570 -p all"},{"PART"=>"STOCK CODE","QTY"=>"Quantity","PRICE"=>"PRICE","DATE"=>"Del Date"},{"PO"=>"Your Ref\s*:\s*([0-9]*)","AB"=>"Sales Order No\s*:\s*([0-9]{1,})"},@hResults)
      TxtClear()
      IF HHasKey(hResults,"AB") .AND. HHasKey(hResults,"PO")
         RETURN ProcessOCData(aData,Pad("BULGIN",8),hResults["AB"],Val(hResults["PO"]),,"dd/mm/yy","(Customer\s*Part\sNo|Part No)")
      ENDIF
      RETURN .F.
   };
}) */
   //salessupportemea@waldom.com
   //
Aadd(aAutoOC,{;   
   "EMAIL"=>"waldom(?:emea|\.zendesk)?.com$",;
   "BLOCK"=>{|oMsg,cFile|

      LOCAL oHTML,cHTML
      LOCAL aRegex,nX,nPO,cAB
      LOCAL oTable,nMonth

      HB_SYMBOL_UNUSED(cFile)

      cHtml := oMsg:Fields("HTML"):Value

      IF AT("<html",cHtml) == 0
         cHtml := "<html><body>"+cHtml+"</body></html>"
      ENDIF

      oHTML := THtmlDocument():New(cHtml)

      IF HB_RegexMatch("Due date change.*",oMsg:Subject)
         Alert(t("Terminänderung"))
         aRegex := HB_Regex('<a[^>]*([">]*zendesk[^"]*)',oMsg:Fields("HTML"):Value)
         IF Len(aRegex) == 2
            Alert("URL: "+aRegex[2])
         ENDIF
      ENDIF

      aRegex := HB_Regex("[^0-9]*([0-9]{5,})\s*[^#]*#\s*([0-9]{1,})",oMsg:SubJect)
      aTables := oHTML:getNodes("table")
      IF Len(aRegex) >= 3 .OR. Len(aTables) >= 9
         nPO := Val(aRegex[2])
         cAB := aRegex[3]

         oTable := aTables[9]

         aData := GetDataFromHTMLTable(oTable,{"PART"=>"(Artikelnummer|Part\s*Number)","QTY"=>"(Bestellmenge|Order\s*Quantity)","PRICE"=>"(St.ckpreis|Unit\s*Cost)","DATE"=>"Expected\s*Ship\s*Date"},2)

         FOR nX := 1 TO Len(aData)            
            
            FOR nMonth := 1 TO 12
               aData[nX]["DATE"] := StrTran(aData[nX]["DATE"] ,{"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}[nMonth],StrZero(nMonth,2))
            NEXT
            aData[nX]["DATE"] := SubStr(aData[nX]["DATE"],0,8)
            
            aData[nX]["PRICE"] := StrTran(LTrim(StrTran(StrTran(aData[nX]["PRICE"],"?",""),"&euro;","")),Chr(9),"")
            aData[nX]["PART"] := StrTran(aData[nX]["PART"],Chr(9),"")
            aData[nX]["QTY"]  := StrTran(aData[nX]["QTY"],Chr(9),"")
         NEXT
         RETURN ProcessOCData(aData,Pad("WALDOM",8),cAB,nPO,,"dd mm yy")
      ELSE
         Tr_MsgBox("Format der Email nicht korrekt.")
      ENDIF
      RETURN .F.
   };
})


Aadd(aAutoOC,{;
   "EMAIL"=>"@techno.it$",;
   "FILE"=>"\.pdf$",;
   "BLOCK"=>{|oMsg,cFile|
      HB_SYMBOL_UNUSED(oMsg)
      TxtBox("Daten werden eingelesen...")
      aData := GetDataFromPDF(cFile,{"-a 389,27,795,570 -p %p-1%"},{"PART"=>"Part\s*number","QTY"=>"Quantity","PRICE"=>"Unit\s*Price","DIS"=>"Sc\.","DATE"=>"Ready on"},{"PO"=>"Your order[^0-9]*([0-9]{4,})","AB"=>"(OCE.*\/[^0-9\.]*[0-9\.]{1,})"},@hResults,"-a 306.80,31.39,388.61,572.84 -r -p 1")
      TxtClear()
//      ? ValToPrg(aData)
//      ? ValToPrg(hResults)
//      SInkey(0)
      IF HHasKey(hResults,"AB") .AND. HHasKey(hResults,"PO")
         hResults["AB"] := StrTran(hResults["AB"],Chr(13),"")
         hResults["PO"] := StrTran(hResults["PO"],Chr(13),"")
         RETURN ProcessOCData(aData,Pad("TECHNO",8),hResults["AB"],Val(hResults["PO"]),,"dd/mm/yy","(Customer\s*Part\sNo|Part No)",.T.,{"MINDERMENGENZUSCHLAG"})
      ENDIF
      RETURN .F.
   };
})

Aadd(aAutoOC,{;
   "EMAIL"=>"@itw.*\.com$",;
   "FILE"=>"\.pdf$",;
   "BLOCK"=>{|oMsg,cFile|
      HB_SYMBOL_UNUSED(oMsg)
      TxtBox("Daten werden eingelesen...")
      aData := GetDataFromPDF(cFile,{"-a 380,0,790,575 -c 38,86,260,365,453,527 -p all"},{=>},{"PO"=>"Customer Ref\s*([0-9]{5,})","AB"=>"Order No\.\s*SO([0-9]{1,})"},@hResults,,{"PART"=>4,"QTY"=>6,"PRICE"=>5,"DATE"=>7})
      TxtClear()
      //? ValToPrg(aData)
      //? ValToPrg(hResults)
      //SInkey(0)
      IF HHasKey(hResults,"AB") .AND. HHasKey(hResults,"PO")
         RETURN ProcessOCData(aData,Pad("ITWAPPLI",8),hResults["AB"],Val(hResults["PO"]),,"dd.mm.yyyy","",.T.)
      ENDIF
      RETURN .F.
   };
})

Aadd(aAutoOC,{;
   "EMAIL"=>"@scolmore.com$",;
   "FILE"=>"\.pdf$",;
   "BLOCK"=>{|oMsg,cFile|
      HB_SYMBOL_UNUSED(oMsg)

      TxtBox("Daten werden eingelesen...")                                             
      // {"PART"=>"Product Code","QTY"=>"Qty","PRICE"=>"Unit Price"}
      aData := GetDataFromPDF(cFile,{"-a 319,23,792,570 -c 23,125,435,470,530 -p all"},{=>},{"PO"=>"Customer\s*Order\s*No\s*:\s*([0-9]{5,})","AB"=>"^Order\s*No\:\s*([0-9]{1,})","DATE"=>"Received\s*Date\s*:\s*([0-9\/]*)"},@hResults,"-a 96,23,304,570 -p 1",{"PART"=>2,"QTY"=>4,"PRICE"=>5})
      //? ValToPrg(aData),Len(aData)
//     ? ValToPrg(hResults)
//      SinKey(0)
      TxtClear()
      IF Len(aData) == 0
         Tr_MsgBox("Keine Bestellpositionen gefunden")
      ELSEIF HHasKey(hResults,"AB") .AND. HHasKey(hResults,"PO") .AND. HHasKey(hResults,"DATE")
         RETURN ProcessOCData(aData,Pad("SCOLMORE",8),hResults["AB"],Val(hResults["PO"]),hResults["DATE"],"dd/mm/yy","",.F.)
      ELSE
         Tr_MsgBox("Keine Bestelldaten gefunden!")

      ENDIF
      RETURN .F.
   };
})


IF ! AutoBeleg(aAutoOC,cMsgId,cFile)
   bestchk()
ENDIF

RETURN NIL


#include "auto_beleg.prg"