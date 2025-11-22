PROCEDURE RUN_STOCKLIST(cTo)

LOCAL hParts := {=>}
LOCAL aExcludeRegex := {}
LOCAL cType,aTypes
LOCAL lAvail := .F.,nAvail
LOCAL nCurWeek := Cweek(Date())
LOCAL cData,nX,hManu,aEmail,cFileName,aManu,lExclude,nStock,nArtikelnr,nBestand,nRec,aReq
LOCAL aBes,cMatch,aList,cManuf,aMatch,cKey,aKeys,hPart,cFile,nF
LOCAL cShopUrl

NetUse("me","me",.F.,0)
NetUse("artikel","art",.F.,0)
art->(dbGoTop())
NetUse("group","grp",.F.,0)
NetUse("manufact","man",.F.,0)
NetUse("artlief","ali",.F.,0)
ali->(dbSetOrder( 2 ))
NetUse("engkund","ku",.F.,0)
NetUse("FOLGEART","FOL",.F.,0)
NetUse("liefstock","lsto")
NetUSe("waldom","wald")
NetUse("engauf","auf")
NetUse("engbes","bes")
NetUse("shopware","shop")

ali->(dbSetOrder( 1 ))
ku->(dbSetOrder( 8 ))
auf->(dbSetOrder( 3 ))
bes->(dbSetOrder( 3 ))
art->(dbSetOrder(2))
art->(dbGoTop())
cData := ""

IF cTo == "ELEKTRON"
   hManu     := {1=>"BUL",10=>"ARCO"}
   aEmail    := {{"amos.engelking@engelking.de","Amos"}}
   aExcludeRegex := {"^KS.*","^ARS.*","^ATS.*","^PX09[1-3]0.*"}
   lAvail := .F.
   cFileName := "elektron_stock.csv"
ELSEIF cTo == "ITW"
   hManu     := {3=>"ITW"}
   aEmail    := {{"amos.engelking@engelking.de","Amos"}}
   aExcludeRegex := {} //"KS14696.*"}
   cFileName := "itw_stock.csv"
ELSEIF cTo == "OCTOPART"
   hManu     := {1=>"Bulgin"}
   cFileName := "octopart_stocklist.csv"
   aEmail := {}
   cData += "manufacturer,mpn,sku,distributor-url,quantity" //,price-break-1,price-usd-1,price-eur-1,price-break-2,price-usd-2,price-eur-2,description,datasheet-url,image-url,attributes,category,moq,order-multiple,on-order-quantity,on-order-eta,packaging,factory-lead-days,factory-pack-quantity,datecode"
ELSE //netcomponents
   hManu     := {1=>"ELEK",10=>"ELEK",2=>"EDAC",3=>"ITW","5"=>""}
   aExcludeRegex := {"^KS(?!14696\/59-[0-9]*$).*$","^ARS.*","^ATS.*","^PX09[1-3]0.*"}   
   aEmail    := {{"datamaster@netcomponents.com","Netcomponents"}}
//   aEmail    := {{"amos.engelking@engelking.de","Netcomponents"}}
   cFileName := "stocklist.txt"
ENDIF
//hManu := {4=>"LAMB"}

//aManu := HGetKeys(hManu)
aManu := {}
FOR nX := 1 TO Len(hManu)
    Aadd(aManu,HGetKeyAt(hManu,nX))
NEXT

Do While ! art->(Eof())
//art->Bezug < 5  .AND.
   If Ascan(aManu,art->Manufactur) != 0
      lExclude := .F.
      FOR nX := 1 TO Len(aExcludeRegex)
         IF HB_RegexMatch(aExcludeRegex[nX],art->Matchcode)
            lExclude := .T.
            EXIT
         ENDIF
      NEXT
      IF ! lExclude
         nStock := art->Bestand
         IF ! art->lagerart
            nArtikelnr := art->Artikelnr
            nBestand := NIL
            IF fol->(dbSeek(STR(nArtikelnr,6)))
               nRec := art->(Recno())

               While fol->artikelnr == nArtikelnr
                  art->(dbSeek(Str(fol->folgeart,6)))
                  If nBestand == NIL
                     nBestand := art->bestand*fol->faktor
                  Else
                     nBestand := Min(art->bestand*fol->faktor,nBestand)
                  Endif
                  fol->(dbSkip())
               Enddo
               art->(dbGoTo(nRec))
            Endif
            If nBestand != NIL
               //?? nBestand
               nStock := nBestand
            Endif
         ENDIF


         IF art->Manufactur == 1 /*.AND. cTo != "ELEKTRON"*/ .AND. lsto->(dbSeek( Pad("WALDOM",8)+Str(art->Artikelnr,6) ))
            nStock += lsto->Stock
         ENDIF

         IF Trim(art->Me) == "PACK" .AND. art->Manufactur == 1 .AND. cTo != "ELEKTRON" //we would really need to save this on the product
            nStock *= 10
         ENDIF
         
         nAvail := 0
         IF lAvail
            aReq := auf->(LETO_SUM( "vkqty,gelqty", "dterm < "+Str(AddWeeks(nCurWeek,12),4)+" .AND. bestat <= 2",art->Matchcode+"0",art->Matchcode+"2"))  //add up all what is needed in the delivery time and before this SO is confrimed, we cannot do the calcualtion on the fly as this produces unpredictable results
            nAvail := nStock-(aReq[1]-aReq[2])
            aBes := bes->(LETO_SUM( "beqty,gelqty", "beqty-gelqty > 0 .AND. lterm < "+Str(AddWeeks(nCurWeek,12),4)+" .AND. bestat <= 2",art->Matchcode,art->Matchcode))  //add up all what is needed in the delivery time and before this SO is confrimed, we cannot do the calcualtion on the fly as this produces unpredictable results
            nAvail := Max(0,Min(nStock,nAvail+aBes[1]-aBes[2]))
         ENDIF


         If nStock != 0  .OR. (cTo == "OCTOPART" .AND. (nStock != 0 .OR. ! art-> Obsolete)) .OR. (lAvail .AND. nAvail != 0)
            man->(dbSeek( Str(art->Manufactur,5) ))
            cMatch := Pad(art->Matchcode,35)

            If man->Address != 0
               ku->(dbSeek( Str(man->Address,6) ))
               ali->(dbSetOrder( 2 ))
               If ali->(dbSeek( ku->Kunde+art->Matchcode )) .AND. ! Empty(ali->Artlief)
                  cMatch := ali->Artlief
               Endif
            Endif
   
            cManuf := hManu[art->Manufactur] //"LAMB"

            aList := {cMatch}

            cMatch := StrTran(art->Matchcode,"KS14696/","")

            IF AT("/BULK",cMatch) != 0
               cMatch := Pad(StrTran(cMatch,"/BULK",""),35)
               Aadd(aList,cMatch)
            ENDIF

         

            aMatch := HB_Regex("(PX041[0-1]\/([0-9]{2})[PS]\/)([0-9]{4})",cMatch)
            aTypes := {"3035","3540","4045","4550","5055","5560","6065","6570"}
            IF Len(aMatch) > 0  //on 400-Series we also list the stock for the other cable types
               FOR EACH cType IN aTypes
                  IF cType != aMatch[4]
                     Aadd(aList,Pad(aMatch[2]+cType,35))
                  ENDIF
               NEXT
            ENDIF

            IF shop->(dbSeek( Str(art->Artikelnr,6) ))      
               cShopUrl := "https://engelking.de/detail/"+Trim(shop->UUID)
            ELSE
               cShopUrl := ""
            ENDIF


            FOR EACH cMatch IN aList
               cKey := cMatch+StrZero(art->manufactur,3)
               IF ! HHasKey(hParts,cKey)
                  hParts[cKey] := {"MATCH"=>cMatch,"ME"=>art->Me,"TR"=>Me(art->Me),"STOCK"=>0,"AVAIL"=>0,"MANUF"=>cManuf,"DESCR"=>art->Artikel,"SHOPURL"=>cShopUrl}
               ENDIF
               hParts[cKey]["STOCK"] += nStock
               hParts[cKey]["AVAIL"] += nAvail

            NEXT            
         Endif
      ENDIF
   Endif
   art->(dbSkip())
Enddo

//add the waldom stock of parts we do not have on the system
IF HHasKey(hManu,1)
   wald->(dbSetFilter({|| wald->Stock != 0 .AND. Trim(wald->prc) $ {'BUL','ARC'} },"stock != 0 .AND. Trim(prc) $ {'BUL','ARC'}"))
   wald->(dbGoTop())
   DO WHILE ! wald->(EOF())
      cKey := wald->Part+StrZero(1,3)
      IF ! HHasKey(hParts,cKey)
         hParts[cKey] := {"MATCH"=>wald->Part,"ME"=>"STCK","TR"=>"999999","STOCK"=>0,"AVAIL"=>0,"MANUF"=>hManu[1],"DESCR"=>"","SHOPURL"=>""}
      ENDIF      
      hParts[cKey]["STOCK"] += wald->Stock
      hParts[cKey]["AVAIL"] += wald->Stock      
      wald->(dbSkip())
   ENDDO
   wald->(dbClearFilter())
ENDIF

IF cTo == "ITW" .OR. cTo == "ELEKTRON"
   cData += "PART NO"+Chr(59)+/*"DESCRIPTION"+Chr(59)+*/"QTY"+IF(lAvail,Chr(59)+"FREE QTY","")+Chr(13)+Chr(10)
ENDIF

aKeys := HGetKeys(hParts)

ASort(aKeys)

hPart := NIL
FOR nX := 1 TO Len(aKeys)
   hPart := hParts[aKeys[nX]]
   IF cTo == "OCTOPART"
      cData += hPart["MANUF"]+","+Trim(hPart["MATCH"])+","+Trim(hPart["MATCH"])+","+hPart["SHOPURL"]+","+Ltrim(Transform(hPart["STOCK"],hPart["TR"]))+Chr(13)+Chr(10)
               //,price-break-1,price-usd-1,price-eur-1,price-break-2,price-usd-2,price-eur-2,description,datasheet-url,image-url,attributes,category,moq,order-multiple,on-order-quantity,on-order-eta,packaging,factory-lead-days,factory-pack-quantity,datecode"
   ELSEIF cTo == "ITW" .OR. cTo == "ELEKTRON"
      cData += Trim(hPart["MATCH"])+Chr(59)+/*HB_OemToAnsi(Trim(hPart["DESCR"]))+Chr(59)+*/Ltrim(Transform(hPart["STOCK"],hPart["TR"]))+IF(lAvail,Chr(59)+Transform(hPart["AVAIL"],hPart["TR"]),"")+Chr(13)+Chr(10)
   ELSE
      cData += Trim(hPart["MATCH"])+Chr(59)+Ltrim(Transform(hPart["STOCK"],hPart["TR"]))+Chr(59)+hPart["MANUF"]
      cData += Chr(59)+hPart["SHOPURL"]+Chr(59)
      cData += Chr(13)+Chr(10)
   ENDIF
NEXT

          //Trim(Tr_getini(1)+
cFile := Trim(Tr_getini(1))+"\export\"+cFileName
nF:= FCreate(cFile)
FWrite(nF,cData)
FClose(nF)

IF Len(aEmail) > 0
   IF Len(aKeys) < 1800 .AND. ! cTo $ {"ELEKTRON","ITW","OCTOPART"} //monitor netcomponents upload we had one file which was too small
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Stocklist TOO SMALL","Please find our current stocklist attached",{cFile})
   ELSE
      SendMail(aEmail,"Stocklist","Please find our current stocklist attached",{cFile})
   ENDIF
ENDIF

//datamaster@netcomponents.com.
