#define SW_PAGE_SIZE   50

PROC Shopware_Update_Pictures
   LOCAL oSW := ShopWareAPI():New()
   LOCAL cBasis := Space(24)
   LOCAL getlist := {}
   LOCAL cPNStarts := Space(25),oPNGet
   LOCAL lMissingOnly := .T.
   LOCAL lBasis := .T.
   LOCAL oBase,nTab := 0, oTable, aTabs := {},nLength
   LOCAL cExample,nTabEx
   LOCAL bReplace,bShowExample,nTabChanged
   LOCAL nPage,nDone,nLimit := 5000
   LOCAL hProdData,aProdData := {}
   LOCAL hSendData,nX
   LOCAL cFileName,lError,hPicData
   LOCAL hPics := {=>}
   LOCAL hSearchMaps := { ;
      "Material"=>{ "V2/"=>{"V4/","V5/"},;                    
                    "V4/"=>{"V2/","V5/"},;
                    "V5/"=>{"V2/","V4/"}},;
      "Anschlussart"=>{"L1"=>{"Lx"},"L2"=>{"Lx"},"L3"=>{"Lx"},"L4"=>{"Lx"},"L5"=>{"Lx"}};
   }
   LOCAL cNewKey,cKey,aFileNames,nLen
   LOCAL bSetPic

   /*,hParentData,aIncluded := {}
   LOCAL oBase,nFirsttab,cPN,oKey
   
   LOCAL hProductOptions,nY,cID
   LOCAL cFunktion,aFunktion,nLength,lFound,cOptType,cDescription   
   ,lError
   ,nUpdated := 0,cTitle,cCatTitle,hProductOptionsNames,nSt,nEnd
   LOCAL aOptions,cTemp
   LOCAL hResponse
   LOCAL cErrorLog := ""
   LOCAL cSep*/

   MEMVAR c_one
   
   IF ! oSW:Auth()
      Alert("Login failed")
      RETURN
   ENDIF

   NetUse("artikel","art")

   Head("Bilder in Shopware setzen")   
   @ 01,00 SAY "Variantenbasis           " GET cBasis 
   ATail( getlist ):Reader := {| oGet, oGetlist, oMenu, oGetMsg| SwapReader( oGet, oGetList, oMenu, oGetMsg ) }
   ATail( getlist ):postBlock := {||
      IF ! art->(dbSeek( cBasis, .F. ))
         Tr_MsgBox(t("Grundversion nicht im Artikelstamm"))
         RETURN .F.
      ELSEIF art->Variant != "B"
         Tr_MsgBox(t("Artikel ist keine Variantenbasis"))
         RETURN .F.
      ENDIF
      oBase := OptionBase():New()
      IF ! oBase:Load(cBasis)
         Tr_MsgBox(t("Variantentabelle nicht angelgt"))
         RETURN .F.
      ENDIF      
      IF AT(Trim(cBasis),cPNStarts) != 1
         cPNStarts := Pad(cPNStarts,25-Len(Trim(cBasis)))
         oPNGet:Col := 26+Len(Trim(cBasis))
         oPNGet:Display()
         //@ 02,26 SAY Trim(cBasis)
      ENDIF
      RETURN .T.
   }
   @ 02,00 SAY "Produktnummer beginnt mit" GET cPNStarts
   ATail( getlist ):postBlock := {|| 
      ColorSelect(4)
      @ 02,26 SAY Trim(cBasis)
      ColorSelect(0)
      RETURN .T. 
   }
   ATail( getlist ):preBlock := {|| 
      ColorSelect(1)
      @ 02,26 SAY Trim(cBasis)
      ColorSelect(0)
      RETURN  .T. 
   }
   oPNGet := AtaiL(getlist)
   @ 03,00 SAY "Nur mit fehlendem Bild   " GET lMissingOnly CHECKBOX
   @ 04,00 SAY "Bild auf Basis setzen    " GET lBasis CHECKBOX
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   SetColor(c_one)
   @ 05,00 SAY "Tabellen:"   
   oBase:oTables:Each({|oTable| 
      nTab++
      Aadd(aTabs,IF(Trim(oTable:Funktion)=="Vorwiderstand",.F.,.T.))
      @ 05+nTab,00 SAY oTable:Funktion GET aTabs[nTab] CHECKBOX STATE Eval(bShowExample) 
      Atail(getlist):Cargo := nTab
      RETURN .T.
   })

   @ 07+nTab,00 SAY "Beispiel:"

   bReplace := {|cText|
      RETURN StrTran(cText,"/","-")
   }
   
   bShowExample := {||
      cExample := Eval(bReplace,Trim(cBasis))
      nTabEx := 0      

      oBase:oTables:Each({|oTable|
         LOCAL oKey := oTable:oKeys:getFirstRecord()    
         nTabEx++         
         IF ((GetActive() == NIL .OR. nTabEx != GetActive():Cargo) .AND. aTabs[nTabEx]) .OR. (GetActive() != NIL .AND. nTabEx == GetActive():Cargo .AND. GetActive():Control:Buffer)
            cExample += Eval(bReplace,oKey:TabKey)                        
         ENDIF

         RETURN .T.
      })      
      @ 08+nTab,00 SAY Pad(cExample+".jpg",25+4)
      RETURN .T.
   }

   EVAL(bShowExample)

   READ 

   IF LastKey() == 27
      RETURN
   ENDIF     

   nPage := 1
   nDone := 0
   hSendData := {;
      "filter"=>{;
         {;		   
            "type"=>"multi",;
            "operator"=>"and",;
            "queries"=>{;                  
               {;
                  "type"=>"prefix",;
                  "field"=>"productNumber",;
                  "value"=>Trim(cBasis)+Trim(cPNStarts); 
               };
            };    
         };     
      },;
      "associations"=>{; 
         "properties"=>{},; //get all used properties			   		   
         "options"=>{}; //get all options, these are the ones set by the variantions
      },;	
      "includes"=>{;
         "product"=>{; //only the fields we really need
            "id",;
            "name",;		               
            "productNumber",;
            "parentId";
         };
      },;
      "limit"=>Min(nLimit-nDone,SW_PAGE_SIZE),;
      "page"=>nPage; 
   }      

   IF ! lBasis
      Aadd(hSendData["filter"][1]["queries"],{"type"=>"not","queries"=>{{"type"=>"equals","field"=>"parentId","value"=>NIL}}}) //only children
   ENDIF

   IF lMissingOnly
      Aadd(hSendData["filter"][1]["queries"],{"type"=>"equals","field"=>"cover.id","value"=>NIL})
   ENDIF

   DO WHILE nDone < nLimit
      ? "Downloading product list... " 

      hSendData["limit"] := Min(nLimit-nDone,SW_PAGE_SIZE)     
      hSendData["page"] := nPage

      hProdData := oSw:Execute("search/product","POST",hSendData)
      IF ! HHasKey(hProdData,"data")
         ?? "Fehler beim Herunterladen der Daten."
         ? ValToPrg(hProdData)
         EXIT
      ENDIF      
      nDone += Len(hProdData["data"])
      ?? " done. ("+LTrim(Str(Len(hProdData["data"])))+";"+LTrim(Str(nDone))+")"
      AEval(hProdData["data"],{|x| Aadd(aProdData,x) })
      IF Len(hProdData["data"]) < SW_PAGE_SIZE //we received less than one page, all data has been downloaded         
         EXIT
      ENDIF   
      nPage++   
   ENDDO

   bSetPic := {||
      oSw:Execute("product/"+aProdData[nX]["id"],"PATCH",{;
                  "cover"=>{;
                     "id"=>HB_MD5(aProdData[nX]["id"]+"01"),; //create a new product_media ID based on the product ID
                     "media"=>{;
                        "id"=>hPics[cFileName]; //the ID of the file
                     };
                  };
               })
   }

   FOR nX := 1 TO Len(aProdData) //hProdData["data"])   
      ? aProdData[nX]["attributes"]["productNumber"]

      //build picture file name
      nLength := Len(Trim(cBasis))
      nTabEx := 0
      lError := .F.
      aFileNames := {}
      cFileName := Eval(bReplace,Trim(cBasis))
      
      IF aProdData[nX]["attributes"]["parentId"] != NIL
         Aadd(aFileNames,cFileName)
         oBase:oTables:Each({|oTable|
            LOCAL oKey 
            
            nTabEx++         
            IF aTabs[nTabEx]            
               oKey := oTable:oKeys:GetRecord(Pad(SubStr(aProdData[nX]["attributes"]["productNumber"],nLength+1,oTable:Length),oTable:Length))               
               IF oKey == NIL
                  ? "Key not found: ",SubStr(aProdData[nX]["attributes"]["productNumber"],nLength+1,oTable:Length)
                  lError := .T.
                  RETURN .F.
               ELSE               
                  nLen := Len(aFileNames)
                  cKey := Trim(oKey:TabKey)               
                  
                  IF Trim(oTable:Funktion) $ hSearchMaps .AND. cKey $ hSearchMaps[Trim(oTable:Funktion)]
                     FOR EACH cNewKey IN hSearchMaps[Trim(oTable:Funktion)][cKey]                     
                        AEval(aFileNames,{|cD| Aadd(aFileNames,cD+Eval(bReplace,cNewKey))},,nLen)                                       
                     NEXT
                  ENDIF
                  
                  AEval(aFileNames,{|cD,nX|  aFileNames[nX] += Eval(bReplace,cKey) },,nLen)
               ENDIF
            ENDIF
            nLength += oTable:Length

            RETURN .T.
         }) 
         IF ! lError
            FOR EACH cFileName IN aFileNames
               ?? " =>",cFileName
                  
               IF ! cFileName $ hPics //we have not looked for this file before
                  //Search if there is a picture with this file name
                  hPicData := oSw:Execute("search/media","POST",{;
                     "limit"=>1,; //we only get the first record
                     "page"=>1,;
                     "filter"=>{;
                        {;
                           "type"=>"equals",;
                           "field"=>"fileName",;
                           "value"=>cFileName; //with an exact match on the filename
                        },;
                        {"type"=>"prefix","field"=>"mimeType","value"=>"image"}; //only images
                     },;
                     "includes"=> {"media"=>{"id"}}; //only get the ID
                  })         
                  IF Len(hPicData["data"]) == 0 //No picture in the database
                     hPics[cFileName] := NIL //save this information to avoid further searches
                  ELSE
                     hPics[cFileName] := hPicData["data"][1]["id"]
                  ENDIF
               ENDIF 
               IF hPics[cFileName] == NIL
                  ?? " KEIN BILD ("+cFileName+") GEFUNDEN."            
               ELSE
                  //Set the cover picture
                  Eval(bSetPic,cFileName)                  
                  EXIT                  
               ENDIF
            NEXT 
         ENDIF
      ELSE        
         hPicData := oSw:Execute("search/media","POST",{;
                  "limit"=>1,; //we only get the first record
                  "page"=>1,;
                  "filter"=>{;
                     {;
                        "type"=>"prefix",;
                        "field"=>"fileName",;
                        "value"=>Trim(cBasis)+Trim(cPNStarts); //look for the first pciture with this part no
                     },;
                     {"type"=>"prefix","field"=>"mimeType","value"=>"image"}; //only images
                  },;
                  "includes"=> {"media"=>{"id","fileName"}}; //only get the ID
               })
            IF Len(hPicData["data"]) != 0 //found a picture               
               cFileName := hPicData["data"][1]["attributes"]["fileName"]
               hPics[cFileName] := hPicData["data"][1]["id"]
               Eval(bSetPic)
            ENDIF
      ENDIF
   NEXT

   ? "ABGESCHLOSSEN"
   Sinkey(0)
RETURN

#include 'x:\run\shopware.prg'