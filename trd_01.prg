#include 'y:\hb32\include\inkey.ch'

PROC MASK_ARTIKEL_TRD01

LOCAL bTimeBlock
LOCAL oArtikel := Artikel():New(.F.)
LOCAL oButton,aButtons := {},nButtonRow
LOCAL hReqInc
LOCAL cMeTr,cDrawingFile,cAwFile
LOCAL nC1,nC2,nC3,nQty,nX,nKey,nY
LOCAL aPrices,nYear,aYears,nRight,hMonthdata,cText,cEK,cDev,cCur
LOCAL nLeft,bAfterKey,cButtonCol,cImageFile,nB,aRegex
LOCAL cKunde := IF(Select("ku") != 0 .AND. ku->Group=="K",ku->Kunde,Space(8))
LOCAL aCustomers,cKNText
LOCAL bGetPrices
LOCAL oExtra,aFiles
LOCAL lBig := MaxCol() > 180
LOCAL nActiveBrowse := 1,aBrowse := {},oBrowse,bChangeBrowse
LOCAL hStatus
LOCAL hPtCache                                       //Speicher-Cache Staffel 60 (Zuruecksetzen)
LOCAL nWebView                                        //embedded browser used to display drawings

MEMVAR MSB,c_five,nR

oArtikel:Load(art->Artikelnr)

NetUse("option","op",.F.,0)
//nOrder := art->(IndexOrd())
hReqInc := GetProductRequirementAndIncoming(art->artikelnr)
NetUse("engkund","ku",.F.,0)
NetUse("engtext2","tx",.F.,0)
NetUse("artkund","aku",.F.,0)
NetUse("artlief","ali",.F.,0)
NetUse("engauf","auf",.F.,0)
NetUse("cat","cat",.F.,0)
NetUse("manufact","man",.F.,0)
NetUse("kn","kn")
NetUse("shopware","shop")
NetUse("projart","pjart")
NetUse("projekte","proj")
NetUse("qs","qs")

SetColor( c_five )
//DISPBEGIN()
//a := 1/0
nLeft  := 00
nRight := IF(lBig,MaxCol(),89)
nC1 := nLeft+2
nC2 := 51
nC3 := 91

Box( 00, nLeft, MaxRow(), nRight,,.T.,2) 
DispBox( 02, nC2-2, 33, nC2-2, 1 )
DispBox( 33, nC2-2, 33, nC3-2, 1 )
IF lBig
   DispBox( 02, nC3-2, 35, nC3-2, 1 )
   @ 33,nC3-2 SAY Chr(180)
ENDIF

@ 33,nC2-2 SAY Chr(192)

cDev := Replicate(Chr(196),nC2-nC1-2)

#define HB_GTI_DISPIMAGE        71

bAfterKey := {|| .T. }
If cat->(dbSeek(art->Artikelnr))
	If ! Empty(cat->Image)
		cImageFile := Trim(Tr_Getini(1))+"\images\catalog\"+Trim(cat->Image)
		If File( cImageFile )
 	 		//bAfterKey := {|| Wvt_DrawImage( 02,nRight-9,0,nRight-1, cImageFile ) }
 	 		IF Tr_Getini(28) == 9
// 	 		    HB_GTINFO(HB_GTI_DISPIMAGE,cImageFile)
 	 		ENDIF
 	 	Endif
  	Endif
Endif


   
IF shop->(dbSeek( Str(art->Artikelnr,6) ))      
   //BEGIN SEQUENCE
      oSW := ShopwareApi():New(.T.)
      IF oSW:Auth()
         //["seoUrls"]
         //Alert( ValToPRg( oSw:Execute("product/"+Trim(shop->UUID)+"/seo-urls","GET")["data"][1]["attributes"]["pathInfo"] ) )         //["self"]      
         oButton := HBPushButton():New(00,nC1+40,"&Website ”ffnen")
         oButton:sBlock := {|| WAPI_ShellExecute(,"open","https://engelking.com/de-de/produkte/detail/"+Trim(shop->UUID)) }
         Aadd(aButtons,oButton)
      ENDIF
   /*RECOVER
   END*/
ENDIF

oExtra := art->(ExtraData():New(art->Artikelnr))

@ 00,nC1-1 SAY "["
Bold(00, nC1,t("Artikel: ")+Trim(ART->matchcode))
DevOut("]")
bold( 01,nC1,Trim(ART->artikel),0 )

cText := t("Artikelnr.:") + " " + LTrim(STR( ART->artikelnr ))
@ 00,nRight-Len(cText)-2 SAY "["
bold( 00,nRight-Len(cText)-1,cText,0 )
DevOUt("]")

IF art->Obsolete
   @ 00,nC1+30 SAY t(" A B G E K š N D I G T ") COLOR "N/GR*"
ENDIF

@ 00, nC1+20 SAY IF(art->Sperren .OR. art->Inventur,"GESPERRT","") COLOR "W+*" 

cMeTr := Me(art->me)
cCur := Currate(art->Money,"X")


@ 03,nC1 SAY cDev
@ 03,nC1+1 SAY "[Best„nde]"

@ 04,nC1 SAY Pad("Bestand",13)+":" + art->(GetFormatedBestand()) //Transform( ART->bestand,cMeTr) + " " + ART->me

IF art->Manufactur == 1 .OR. art->Manufactur == 10
   NetUse("liefstock","lsto")
   IF lsto->(dbSeek( Pad("WALDOM",8)+Str(art->Artikelnr,6) ))
      @ 05,nC1 SAY Pad(" 7 Tage",13)+": "+PadL(Transform(lsto->Stock,cMeTr),11)+" "+art->Me
      @ 06,nC1 SAY Pad("14 Tage",13)+": "+PadL(Transform(lsto->DelQty,cMeTr),11)+" "+art->Me
   ENDIF
ELSEIF art->Manufactur == 9
   ali->(dbSetOrder(1))
   IF ali->(dbSeek( Pad("SCOLMORE",8)+Str(art->Artikelnr,6) )) .AND. ! Empty(ali->Artlief)
      //Alert("Found Scolmore: "+ali->Artlief)
      oApi := RestApi():New()
      oApi:cBaseUrl := "https://scolmoreonline.com/api/v1/"
      oApi:cApiKeyName := "SCOLMORE"
      
      cData := oApi:Execute("stock","GET",{"product"=>Trim(ali->Artlief)},{"Authorization: Bearer $APIKEY$"})
      hData := HB_JsonDecode(cData)
      IF Tr_Getini(28) == 9
         Alert(ValToPrg(hData))
      ENDIF
      IF HHasKey(hData,"stock")
         @ 05,nC1 SAY Pad("Werk",13)+": "+PadL(Transform(hData["stock"],cMeTr),11)+" "+art->Me
      ENDIF
      //example:
      //{"code":"EL182S","description":"EU Right Angle Schuko to C13 IEC Lock Connector 3C 1.00mm\u00fd H05VV-F Black Cable - 2 Metre","stock":15131,"product_image":"https:\/\/ordering-portal-product-images.s3.eu-west-2.amazonaws.com\/EL182S.png","expected_stock":[{"product":"EL182S","quantity":4300,"due_date":"2025-09-26"},{"product":"EL182S","quantity":3100,"due_date":"2025-10-03"},{"product":"EL182S","quantity":500,"due_date":"2025-10-17"},{"product":"EL182S","quantity":100,"due_date":"2025-10-24"}]}
      IF HHasKey(hData,"expected_stock") .AND. Len(hData["expected_stock"]) > 0
         FOR nX := 1 TO Min(5,Len(hData["expected_stock"]))
            @ 05+nX,nC1 SAY Pad("",13)+"  "+PadL(Transform(hData["expected_stock"][nX]["quantity"],cMeTr),11)+" "+art->Me+" ("+DtoC(StoD(StrTran(hData["expected_stock"][nX]["due_date"],"-","")))+")"
         NEXT
      ENDIF
   ENDIF
ENDIF
NetUse("engbes","bes")
bes->(dbSetOrder( 3 ))
@ 11,nC1 SAY cDev

@ 12,nC1 SAY msb[26]+LTrim(Str(hReqInc["income"],6,0)) //+" ("+LTrim(Str(art->EkQty,6,0))+")"+" ("+LTrim(Str(bes->(LETO_SUM('beqty','bestat<3',art->Matchcode,art->Matchcode)),6,0))+")"
@ 13,nC1 SAY msb[27]+LTrim(Str(hReqInc["requirement"],6,0)) //+" ("+LTrim(Str(art->VkQty,6,0))+")"

@ 15,nC1 SAY "Meldebestand : "+ LTrim(Transform( ART->mindest, cMeTr ))

cEK := IF(art->Bezug>=5,"HK","EK")

@ 16,nC1 SAY  Pad(t("Netto "+cEk),13)+": " + LTrim(STR( ART->netprice ))
IF art->Rabatt != 0
   @ 16,Col()+1  SAY "("+t("abzgl.")+" "+ Ltrim(STR( ART->rabatt ))+"%)"
ENDIF
@ 17,nC1 SAY Pad(t("Letzte "+cEk),13)+": " + LTrim(STR( ART->letzte_ek,8,2 )) +" "+cCur
If art->Money != "E"
	@ 17,Col()+1 SAY "("+LTrim(Str(art->letzte_ek*Currate(art->Money,"E")/Currate("E","E"),8,2))+" "+Currate("E","X")+")"
Endif
 @ 17,Col()+1 SAY "/ "+LTrim(Str(art->pe))

 @ 18,nC1 SAY Pad(t("D/S "+cEk),13)+": "+LTrim(STR( oArtikel:GetAvgBuyPrice(Date()/*,Tr_Getini(28)==9*/) ))+" EUR" //+cCur

@ 20,nC1 SAY Pad(t("Besch.zeit"),13) + ": " + LTrim(STR( IF(art->LZ==0,12,ART->lz) ))+" Wochen  (Ist:"+LTrim(Str(CalcLZ(oArtikel)))+")" //IF(art->Bezug >= 5,""," (Ist:"+LTrim(Str(CalcLZ()))+")")

@ 22,nC1 SAY "Bedarf/Monat : "+LTrim(Str(hReqInc["avgrequirement"]))
@ 22,nC1+(nC2-nC1)/2 SAY HB_AnsiToOem("Vorhersage   : ")+LTrim(Str(hReqInc["forecast"]))
@ 23,nC1 SAY "Kunden (12 M): "+LTrim(Str(hReqInc["cust_count"]))
aCustomers := {}
HEvaL(hReqInc["customers"],{|cKunde,nMenge| Aadd(aCustomers,cKunde+Transform(nMenge,cMeTr)+" "+art->Me) })
oButton := HBPushButton():New(23,nC1+20,"&Kunden anzeigen")
oButton:sBlock := {|| Tr_MsgBox(aCustomers) }
Aadd(aButtons,oButton)
@ 24,nC1 SAY HB_AnsiToOem("Auftragspos. : ")+LTrim(Transform(hReqInc["order_count"],cMeTr))
@ 25,nC1 SAY HB_AnsiToOem("Gr”áte Pos.  : ")+LTrim(Transform(hReqInc["maxorder"],cMeTr))

@ 27,nC1+15 SAY "Gesamt"
@ 27,nC1+22 SAY Str(Year(Date()),4)
@ 27,nC1+29 SAY Str(Year(Date())-1,4)
@ 27,nC1+36 SAY Str(Year(Date())-2,4)
hMonthData := NIL
aYears := {{"bought"=>0,"sold"=>0},{"bought"=>0,"sold"=>0},{"bought"=>0,"sold"=>0}}

FOR EACH hMonthData IN hReqInc["months"]
   nYear := Val(LTrim(Left(hMonthData:__enumKey(),5)))
   IF nYear <= Year(Date()) .AND. Year(Date())-nYear < 3
//      ? nYear,Year(Date())-nYear+1,ValToPrg(hMonthData),ValToPrg(aYears[Year(Date())-nYear+1])
      aYears[Year(Date())-nYear+1]["sold"] += hMonthData["sold"]
      aYears[Year(Date())-nYear+1]["bought"] += hMonthData["bought"]
   ENDIF
NEXT

nR := 27
IF art->Bezug < 5
   @ ++nR,nC1 SAY "EK Menge     : "+LTrim(Transform(art->gelqty,cMeTr))
ENDIF
If HHasKey(hReqInc,"total_bought")
	@ nR+1,nC1 SAY "VK Menge     : "+LTrim(Transform(hReqInc["total_bought"],cMeTr))
Endif
FOR nX := 1 TO 3
   IF art->Bezug < 5
      @ nR,nC1+15+7*nX SAY +LTrim(Transform(aYears[nX]["bought"],cMeTr))
   ENDIF
   @ nR+1,nC1+15+7*nX SAY +LTrim(Transform(aYears[nX]["sold"],cMeTr))
NEXT
nR++

@ 02,nC2 SAY "Gewicht : " + Ltrim(Str(ART->gewicht))+"g"
@ 03,nC2 SAY "VPE     : "+LTrim(Transform(art->vpe,cMeTr))
@ 04,nC2 SAY "Bezug   : "+Ltrim(STR( ART->bezug ))
@ 06,nC2-1 SAY Replicate(Chr(196),nC3-1-nC2)
aPrices := {}
IF ! Empty(art->Table) .AND. SystemUser():HasPermission("READ","ART_VK")
   bGetPrices := {||
      DisplayPrices(06,nC2-1,art->Artikelnr,,,,Date(),,Chr(196)+"[ PREISSTAFFEL ]",@aPrices)
      IF art->Table == 44
         @ 06,nC2+15 SAY t("GP") COLOR "B/G*"
         @ 06,nC2+17 SAY " ]"
      ENDIF
      IF ! Empty(cKunde) //Select("ku") != 0 .AND. ku->Group == "K"
         ku->(dbSetOrder( 1 ))
         ku->(dbSeek( cKunde+"K" ))            
         DisplayPrices(06,nC2+20,art->Artikelnr,0,1,ku->Money,Date(),ku->Kunde,"[ "+ku->Kunde+" ]")            
      ENDIF
      RETURN .T.
   }

   IF art->Table $ {44,15,60}
      NetUse("ptcache","ptc")
      //use cache if it is not older than a week
      IF ptc->(dbSeek( Str(art->Artikelnr,6) )) .AND. ptc->LastDate >= Date()-7 .AND. ptc->Prices != "{}"
        // RETURN HB_JsonDecode(ptc->Prices)
        Eval(bGetPrices)
      ELSE
         oButton := HBPushButton():New(06,nC2+19,"&Staffel anzeigen")
         oButton:sBlock := bGetPrices
         Aadd(aButtons,oButton)
      ENDIF
   ELSE
      Eval(bGetPrices)
   ENDIF
ENDIF

@ 19,nC2-1 SAY Replicate(Chr(196),nC3-1-nC2)
IF art->Bezug != 5
   @ 20,nC2 SAY "Preise abfragen mit >P<"
   oButton := HBPushButton():New(19,nC2,"&Preise abfragen")
   oButton:sBlock := {|| GetCompPrices(nR,nC2,aPrices,cMeTr)  }
   Aadd(aButtons,oButton)
ELSE
   NetUse("werkauf","wer")
   NetUse("watime","wat")
   NetUse("jobs","job")
   bTimeBlock := {|lDisp|
      LOCAL cList,cScr,cAusList
      LOCAL nTime
      LOCAL nTotTime := 0
      LOCAL nTotQty  := 0
      LOCAL nTotGel := 0
      LOCAL nTotBad  := 0
      LOCAL hTotJobs := {=>}
      LOCAL nT,aJob,hJobs,nJob

      IF lDisp
         cList := Pad("FA",6)+" "+Pad("T„tigkeit",20)+" "+Pad("Start",14)+" "+Pad("Ende",14)+" "+PadL("min",6)+Chr(13)+Chr(10)
         cAusList := ""
      ENDIF
      
      //oArtikel:GetDefQuotaAndAvgManTime()

      hJobs := {=>}

      wer->(dbSetOrder( 2 )) // Str(artno)
      wer->(dbSeek( Str(art->Artikelnr,6) ))      
      DO WHILE wer->Artno == art->Artikelnr .AND. ! wer->(EOF())
         IF wer->Status >= 4 .AND. wer->Qty > 0
            IF wer->Date >= StoD("20150601") //we first started booking badqty here
               IF lDisp 
                  cAusList += Str(wer->Aufno,6)+" Ausschuss "+Ltrim(Transform(wer->BadQty,Me(art->Me)))+"/"+LTrim(Transform(wer->Qty-wer->GelQty,Me(art->Me)))+" "+IF(wer->GelQty>0,Ltrim(str(wer->BadQty/wer->GelQty*100,5,2))+"%","")+Chr(13)+Chr(10)
               ENDIF
               nTotQty += wer->Qty
               nTotBad += wer->BadQty //+(wer->Qty-wer->GelQty)
            ENDIF
            wat->(dbSeek( Str(wer->Aufno,6) ))
            nTime := 0
            //hJobs := {=>}
            DO WHILE wat->Wanr == wer->Aufno .AND. ! wat->(EOF())
               IF lDisp
                  job->(dbSeek( Str(wat->Job,6) ))
                  cList += Str(wer->Aufno,6)+" "+job->Name+" "+Left(TtoC(SToT(wat->Start)),14)+" "+Left(TtoC(SToT(wat->End)),14)+" "+Str((StoT(wat->End)-StoT(wat->Start))*24*60,6,0)+Chr(13)+Chr(10)
               ENDIF
               nT := (StoT(wat->End)-StoT(wat->Start))*24*60
               nTime += nT
               IF ! HHasKey(hJobs,wat->Job)
                  hJobs[wat->Job] := 0
               ENDIF
               hJobs[wat->Job] += nT
               wat->(dbSkip())
            ENDDO
            IF lDisp .AND. nTime != 0 .AND. wer->GelQty != 0
               cList += Space(52)+"pro "+art->Me+":"+Str(nTime/wer->gelqty,6,2)+Chr(13)+Chr(10)
            ENDIF
            IF nTime > 0
               nTotTime += nTime
               nTotGel  += wer->GelQty
               /*FOR EACH nT IN hJobs
                  nJob := nT:__eNumKey()
                  IF ! HHasKey(hTotJobs,nJob)
                     hTotJobs[nJob] := {0,0}
                  ENDIF
                  hTotJobs[nJob][1] += nT
                  hTotJobs[nJob][2] += wer->Qty
               NEXT*/
            ENDIF
         ENDIF
         wer->(dbSkip())
      ENDDO
      IF lDisp
         cScr := SaveScreen()
         MemoEdit(cList+Chr(13)+Chr(10)+cAusList,,,,,.F.)
         RestScreen(,,,,cScr)
      ENDIF
      @ 20,nC2 SAY t("Ausschussrate")
      IF nTotQty > 0
         @ 20,nC2+21 SAY Str(nTotBad/nTotQty*100,5,2)+"%"
         FOR nX := 1 TO Len(hJobs)
            nT := HGetValueAt(hJobs,nX)
            nJob := HGetKeyAt(hJobs,nX)
            job->(dbSeek( Str(nJob,6) ))
            @ 22+nX,nC2 SAY job->Name
            //IF aJob[2] > 0
            IF nTotGel > 0
               @ 22+nX,nC2+21 SAY __DispTime(nT/nTotGel)
            ENDIF
            //ENDIF
         NEXT
      ENDIF 
      @ 21,nC2 SAY t("Durschn. Fertigungszeiten")
      @ 22,nC2 SAY t("ges. Baustufe")
      IF nTotGel > 0
         @ 22,nC2+21 SAY __DispTime(nTotTime/nTotGel)
      ENDIF
      
      RETURN NIL
   }
   Eval(bTimeBlock,.F.)
ENDIF



man->(dbSeek( Str(art->Manufactur,5) ))
@ ++nR,nC1 SAY "Hersteller   : "+man->Short

@ ++nR,nC1 SAY "Zolltarifnr. : "+art->KnCode
kn->(dbSeek( Pad(StrTran(art->KnCode," ",""),8)))
cKNText := Pad(kn->Self_Expla,nC2-nC1-14-Len(Trim(art->KnCode))-6)
IF Len(Trim(kn->Self_Expla)) > Len(Trim(cKnText))
   cKNText := Left(cKnText,Len(cKnText)-3)+"..."
ENDIF
@ nR,nC1+14+Len(Trim(art->KnCode))+2 SAY "("+Trim(cKnText)+")"
@ ++nR,nC1 SAY "Ursprungsland: "+Trim(GetCountryName(art->Ursprung))
@ ++nR,nC1+15 SAY "("+If(ArtHasValidLE(art->Artikelnr),"","nicht ")+"pr„ferenzbegnstigt)"



//art->(dbSetOrder(nOrder))
@ ++nR,nC1 SAY "Zeichnungsnr.: "+Trim(art->Zeichnung)+If(!Empty(art->ZeichIndex)," Ind. "+Trim(art->ZeichIndex),"")
IF ! Empty(art->Zeichnung)
	cDrawingFile := MBaseRun(Trim(Tr_Getini(1))+"\run\getdrawing")
	IF ! Empty(cDrawingFile)
		@ Row(),Col()+1 SAY t("(™ffnen mit >Z<)")
	ENDIF
ENDIF

IF oExtra:SDS 
   cDir := "Y:\Technik\Sicherheitsdatenbl„tter\"
   aFiles := Directory(cDir+LTrim(Str(art->Artikelnr))+"_*")
   IF Len(aFiles) > 0
      cAWFile := cDir+aFiles[1,1]
      @ ++nR,nC1 SAY "Sicherheitsdatenblatt mit >S< ”ffnen "
   ENDIF
ELSE
   @ ++nR,nC1 SAY IF(art->Bezug != 5,"Prod.zeichn. : ","Arbeitsanw.  : ")+Trim(art->Anweisung)+IF(art->Bezug!= 5.AND. !Empty(art->AWIndex)," Ind. "+Trim(art->AwIndex),"")
   IF ! Empty(art->Anweisung) 
      IF art->Bezug == 5   
         cAWFile := Hook("get_drawingfile",{.T.}) // MBaseRun(Trim(Tr_Getini(1))+"\run\getdrawing",{.T.})
         IF ! Empty(cAWFile)
            @ Row(),Col()+1 SAY t("(™ffnen mit >A<)")
         ENDIF
      ELSE
         cAWFile := Hook("get_drawingfile",{.F.,Trim(art->Anweisung),Trim(art->AWIndex),.F.}) // MBaseRun(Trim(Tr_Getini(1))+"\run\getdrawing",{.T.})
         IF ! Empty(cAWFile)
            @ Row(),Col()+1 SAY t("(™ffnen mit >P<)")
         ENDIF
      ENDIF 
   ENDIF
ENDIF

@ ++nR,nC1 SAY msb[33] + "("+ART->gruppe+")"
ArtGrup(ART->gruppe,nR,nC1+22)

@ 36,nC1 SAY Replicate(Chr(196),nRight-nC1-1)
nY := tx->(DispText(art->textnr,37,nC1,78,MaxRow()-37-1,.F.))
OptDisp(nY,nC1,MaxRow()-nY,c_five)

IF art->Bezug != 5 .AND. art->Manufactur != 9
   nR := 07
   ali->(dbSetOrder( 1 ))
   If ali->(dbSeek(Pad("RS",8)+Str(art->Artikelnr,6))) .AND. ! Empty(ali->artlief)
   	@ nR,nC1 SAY "RS"
   	@ nR,nC1+13 SAY ": abfragen mit >LEER<"
   	nR++
   Endif
   If ali->(dbSeek(Pad("FARNELL",8)+Str(art->Artikelnr,6))) .AND. ! Empty(ali->artlief)
         	@ nR,nC1 SAY "Farnell"
   	@ nR,nC1+13 SAY ": abfragen mit >LEER<"
   	nR++
   Endif
   /*If ali->(dbSeek(Pad("ETTINGER",8)+Str(art->Artikelnr,6))) .AND. ! Empty(ali->artlief)
         	@ nR,nC1 SAY "Ettinger"
   	@ nR,nC1+13 SAY ": abfragen mit >LEER<"
   	nR++
   Endif*/
   If ali->(dbSeek(Pad("ELIMEC",8)+Str(art->Artikelnr,6)))
         	@ nR,nC1 SAY "Elimec"
         	@ nR,nC1+13 SAY ": abfragen mit >LEER<"
         	nR++
   Endif
   If ali->(dbSeek(Pad("MOUSER",8)+Str(art->Artikelnr,6)))
         	@ nR,nC1 SAY "Mouser"
         	@ nR,nC1+13 SAY ": abfragen mit >LEER<"
         	nR++
   Endif
   If ali->(dbSeek(Pad("DISTRELE",8)+Str(art->Artikelnr,6)))
         	@ nR,nC1 SAY "Distrelec"
         	@ nR,nC1+13 SAY ": abfragen mit >LEER<"
   Endif

ENDIF

IF lBig
   qs->(dbSetOrder( 2 ))
   IF qs->(dbSeek( Str(art->Artikelnr,6) ))
      @ 02,nC3 SAY Pad(Chr(196)+"[Fehler]",nRight-nC3,Chr(196))
      nR := 03
      
      oBrowse := qs->(TBrowseTr():New(03,nC3,07,nRight))
      oBrowse:lBox := .F.
      oBrowse:OneColumn := .T.
      oBrowse:HeadSep := ""
      oBrowse:NewColumn("Nummer",{|| Str(qs->Nummer,6) })
      oBrowse:NewColumn("Beschreibung",{|| Pad(qs->Beschreibu,60) })
      oBrowse:WhileBlock := {|| qs->Matchcode == art->Matchcode }
      oBrowse:AddKey(K_ENTER,{|| EditQS(qs->Nummer) })
      oBrowse:Display()
      oBrowse:deHilite()
      Aadd(aBrowse,{oBrowse,SaveEnv()})
   ENDIF

   pjart->(dbSetORder( 2 ))
   IF pjart->(dbSeek( Str(art->Artikelnr,6) ))
      @ 08,nC3 SAY Pad(Chr(196)+"[Projekte]",nRight-nC3,Chr(196))
      hStatus := GetProjectStatusNames()
      /*nR := 16
      DO WHILE 
         
         oButton := HBPushButton():New(nR++,nC3,+" "+)
         oButton:sBlock := {|o| Alert(valType(GetActive():Buffer)),  }
         oButton:Style := ""
         Aadd(aButtons,oButton)   
      
         pjart->(dbSkip())
      ENDDO*/

      oBrowse := pjart->(TBrowseTr():New(09,nC3,14,nRight-1))
      oBrowse:lBox := .F.
      oBrowse:OneColumn := .T.
      oBrowse:HeadSep := ""
      oBrowse:NewColumn("Nummer",{|| Str(pjart->Nummer) })
      oBrowse:NewColumn(Pad("Status",13)+" "+Pad("Beschreibung",60),{|| 
         proj->(dbSeek( Str(pjart->Nummer,6) ))
         RETURN Pad(hStatus[proj->Status],13)+" "+Pad(proj->Beschreibu,60)
      })

      oBrowse:WhileBlock := {|| pjart->Artikelnr == art->Artikelnr }
      oBrowse:AddKey(K_ENTER,{|| Project_edit(pjart->Nummer)  })
      oBrowse:Display()
      oBrowse:deHilite()
      Aadd(aBrowse,{oBrowse,SaveEnv()})

   ENDIF
ENDIF

bChangeBrowse := {|nNew|
   oBrowse:deHilite()
   aBrowse[nActiveBrowse,2] := SaveEnv()
   nActiveBrowse := nNew
   oBrowse := aBrowse[nActiveBrowse,1]
   RestEnv(aBrowse[nActiveBrowse,2],.F.)
   oBrowse:Display()
   RETURN NIL
}

IF Len(aBrowse) > 0 .AND. nActiveBrowse <= Len(aBrowse)
   oBrowse := aBrowse[nActiveBrowse,1]
   RestEnv(aBrowse[nActiveBrowse,2],.F.)
   oBrowse:Display()
ELSE
   oBrowse := NIL
ENDIF

//Add the buttons depending on permissions
nButtonRow := 36
IF (SystemUser():hasRole(14).OR.SystemUser():HasRole(15) .AND. art->Type == "WARE") .OR. art->Table == 60 //Einkauf oder Projektmanagemtn, Staffel 60 (Kalkulation) immer            
   oButton := HBPushButton():New(++nButtonRow,nC3,"Preisstaffel zu&rcksetzen")
   oButton:sBlock := {|| 
      TxtBox("Preiscache wird zurckgesetzt...")
      NetUse("ptcache","ptc")
      IF ptc->(dbSeek( Str(art->Artikelnr,6) ))               
         ptc->(Rec_Lock())
         ptc->LastDate := Stod("")
         ptc->(dbUnLock())
         ptc->(dbSkip())
      ENDIF      
      //Speicher-Cache der Staffel-60-Kalkulation (Hook on_get_prices) fuer diesen Artikel leeren
      IF __mvExist("PRICETAB60_CACHE") .AND. ValType(__mvGet("PRICETAB60_CACHE")) == "H"
         hPtCache := __mvGet("PRICETAB60_CACHE")
         FOR nX := Len(hPtCache) TO 1 STEP -1
            IF Left(HB_HKeyAt(hPtCache,nX),6) == Str(art->Artikelnr,6)
               HB_HDelAt(hPtCache,nX)
            ENDIF
         NEXT
      ENDIF
      IF ValType(bGetPrices) == "B"
         Eval(bGetPrices)
      ENDIF
      TxtClear()      
      RETURN .T.
   }
   Aadd(aButtons,oButton)
ENDIF


IF ValType(bTimeBlock) == "B"
   oButton := HBPushButton():New(++nButtonRow,nC3,"Zei&taufwand")
   oButton:sBlock := {|| Eval(bTimeBlock,.T.) }
   Aadd(aButtons,oButton)
ENDIF

//display all buttons
AEval(aButtons,{|x| x:ColorSpec := cButtonCol := "N/W,N/W,GR+/RB,R+/W", x:Display() })


nKey := 0
DO WHILE nKey != 27
   Eval(bAfterKey)
   IF oBrowse == NIL .OR. oBrowse:Stable
      nKey := Inkey(0) //,bAfterKey)

      If art->Bezug != 5 .AND. LastKey() == 32
         FOR nX := 07 TO 10
            @ nX,nC1+14 SAY Space(33)
         NEXT
         nR := 07
         IF art->Manufactur != 9            
            If ali->(dbSeek(Pad("RS",8)+Str(art->Artikelnr,6))) .AND. ! Empty(ali->artlief)
               @ nR,nC1+13 SAY ": lade..."
               nQty := GetLiefStock("RS",art->Artikelnr)

               @ nR,nC1+15 SAY Space(8)
               If nQty >= 0
                  @ nR,nC1+15 SAY Transform(nQty,cMeTr)
               Elseif nQty == -2
                  @ nR,nC1+15 SAY "Nicht im Sortiment"
               Else
                  @ nR,nC1+15 SAY "Fehler!"
               Endif
               nR++
            Endif
            If ali->(dbSeek(Pad("FARNELL",8)+Str(art->Artikelnr,6))) .AND. ! Empty(ali->artlief)
               @ nR,nC1+13 SAY ": lade..."
               nQty := GetLiefStock("FARNELL",art->Artikelnr)
               @ nR,nC1+15 SAY Space(10)
               If nQty >= 0
                  @ nR,nC1+15 SAY Transform(nQty,cMeTr)
               Elseif nQty == -2
                  @ nR,nC1+15 SAY "Nicht im Sortiment"
               Else
                  @ nR,nC1+15 SAY "Fehler!"
               Endif
               nR++
            Endif
            If ali->(dbSeek(Pad("ELIMEC",8)+Str(art->Artikelnr,6)))
               @ nR,nC1+13 SAY ": lade..."
               nQty := GetLiefStock("ELIMEC",art->Artikelnr)
               @ nR,nC1+15 SAY Space(10)
               If nQty >= 0
                  @ nR,nC1+15 SAY Transform(nQty,cMeTr)
               Else
                  @ nR,nC1+15 SAY "Fehler!"
               Endif
               nR++
            Endif
            If ali->(dbSeek(Pad("MOUSER",8)+Str(art->Artikelnr,6)))
               @ nR,nC1+13 SAY ": lade..."
               nQty := GetLiefStock(Pad("MOUSER",8),art->Artikelnr)
               @ nR,nC1+15 SAY Space(10)
               If nQty >= 0
                  @ nR,nC1+15 SAY Transform(nQty,cMeTr)
               Else
                  @ nR,nC1+15 SAY "Fehler!"
               Endif
               nR++
            Endif
            If ali->(dbSeek(Pad("DISTRELE",8)+Str(art->Artikelnr,6)))
               @ nR,nC1+13 SAY ": lade..."
               nQty := GetLiefStock(Pad("DISTRELE",8),art->Artikelnr)
               @ nR,nC1+15 SAY Space(10)
               If nQty >= 0
                  @ nR,nC1+15 SAY Transform(nQty,cMeTr)
               Else
                  @ nR,nC1+15 SAY "Fehler!"
               Endif
            Endif
         ENDIF

         //Eval(bAfterKey)
         //SInkey(0,bAfterKey)
      ELSEIF Upper(Chr(nKey)) == "Z" .AND. ! Empty(art->Zeichnung) .AND. ! Empty(cDrawingFile)
         //nWebView := ShowDrawing(nWebView,cDrawingFile,t("Zeichnung")+" "+Trim(art->Zeichnung)+IF(!Empty(art->ZeichIndex)," Ind. "+Trim(art->ZeichIndex),""))
         Wapi_ShellExecute(,"open",cDrawingFile)
      ELSEIF Upper(Chr(nKey)) == "A" .AND. art->Bezug == 5 .AND. ! Empty(art->Anweisung) .AND. ! Empty(cAWFile)
         NetUse("aw","aw")
         IF (aw->(dbSeek( Str(Val(art->Anweisung),6) )) .AND. aw->Genehmig) .OR. Tr_MsgBox(t("Diese Anweisung ist NICHT freigegeben. Die Fertigung sollte nur nach Rcksprache erfolgen."),"!!! ACHTUNG !!!",{"abbrechen",t("trotzdem ”ffnen")}) == 2
            IF ".json" $ cAWFILE
               //open new AW File Viewer
               WAPI_ShellExecute(,"open","https://db.engelking.de/trader/AAWEditor/viewer.html?file="+LTrim(Str(aw->Nummer)))
            ELSE
               WAPI_ShellExecute(,"open",cAWFile)
            ENDIF
         ENDIF
      ELSEIF Upper(Chr(nKey)) == "P" .AND. art->Bezug != 5  .AND. ! Empty(art->Anweisung) .AND. ! Empty(cAWFile)
         //nWebView := ShowDrawing(nWebView,cAWFile,t("Produktionszeichnung")+" "+Trim(art->Anweisung)+IF(!Empty(art->AWIndex)," Ind. "+Trim(art->AWIndex),""))
         Wapi_ShellExecute(,"open",cAWFile)
      ELSEIF Upper(Chr(nKey)) == "S" .AND. oExtra:SDS .AND. ! Empty(cAwFile)
         WAPI_ShellExecute(,"open",cAWFile)
      ELSEIF Upper(Chr(nKey)) == "U"
         TxtBox("D/S Preis wird neu berechnet...")
         @ 18,nC1 SAY Pad(t("D/S "+cEk),13)+": "+LTrim(STR( oArtikel:GetAvgBuyPrice(Date(),.T.) ))+" EUR"
         TxtClear()
      ELSEIF Upper(Chr(nKey)) == "C"
         IF .F. //Tr_MsgBox("Wettbewerber aktualisieren?",,{t("Nein"),t("Ja")}) == 2
            TxtBox("Wettbewerber werden gesucht und aktualisiert...")
            manu->(dbGoto( art->Manufactur ))

            UnLoadPrg(Path("run\perplexity")) //in case it was already loaded
            LoadPrg(Path("run\perplexity"))
            oPerplexity := &("Perplexity():New()")
            //cPrompt := "Suche nach Lieferanten von "+Trim(manu->Short)+" "+Trim(art->Matchcode)+". "
            //cPrompt += "Gib mir das Resultat als ***striktes JSON** mit den folgenden Feldern: Lieferant, Artikelnummer zurck."
            //cPrompt += "Verwende folgende Lieferanten: RS Components, Farnell, Mouser, Digikey, Conrad, Reichelt, TME, Schukat, Distrelec, Arrow."
            cPrompt := "Suche nach Lieferanten fr den Artikel "+Trim(manu->Short)+" "+Trim(art->Matchcode)+". "
            cPrompt += "Prfe die Verfgbarkeit bei folgenden Distributoren:"
            cPrompt += "- RS Components"
            cPrompt += "- Farnell"
            cPrompt += "- Mouser"
            cPrompt += "- Digikey"
            cPrompt += "- Conrad"
            cPrompt += "- Reichelt"
            cPrompt += "- TME"
            cPrompt += "- Schukat"
            cPrompt += "- Distrelec"
            cPrompt += "- Arrow"

            cPrompt += "Gib die Ergebnisse als **striktes JSON** ohne irgendwelche Erl„uterungen im folgenden Format zurck:"

            cPrompt += "```json"
            cPrompt += "{"
            cPrompt += '"suchergebnisse": ['
            cPrompt += '   {'
            cPrompt += '      "lieferant": "Name des Lieferanten",'
            cPrompt += '      "artikelnummer": "Lieferanten-spezifische Artikelnummer"'
            cPrompt += '      "gefunden": true/false //falls gefunden'            
            cPrompt += '   }'
            cPrompt += '],"quellen":["Liste der Webseiten, die ich besucht habe"]'
            cPrompt += '}'
            gtSetClipboard(cPrompt)
            cJson := oPerplexity:Ask(cPrompt,,{"web_search_options"=>{"search_context_size"=>"high"}})
            Alert(cJson)
            
            
            TxtClear()
         ENDIF
         MBaseRun(Trim(Tr_getini(1))+"\run\prices\updcompet",{,.T.})
         NetUSe("ptcache","ptc")
         nArtnr := art->Artikelnr
         IF ptc->(dbSeek( Str(nArtnr,6) ))
            DO WHILE ptc->Artnr == nArtnr .AND. ! ptc->(EOF())
               ptc->(Rec_Lock())
               ptc->LastDate := Stod("")
               ptc->(dbUnLock())
               ptc->(dbSkip())
            ENDDO
         ENDIF
         Eval(bGetPrices)
      ELSEIF Upper(Chr(nKey)) == "L"
         CalcLZ(oArtikel,.T.)
      ELSEIF (nKey == K_LBUTTONDOWN .AND. (nB := AScan(aButtons,{|oButton|oButton:HitTest(MRow(),MCol()) != 0})) != 0) .OR.;
         (! Empty(Chr(nKey)) .AND. (nB := AScan(aButtons,{|oButton| aRegex:= HB_Regex("\&([A-Za-zŽ™š„”])",oButton:Caption), Len(aRegex) > 0 .AND. Upper(aRegex[2]) == Upper(Chr(nKey))} )) != 0)
         oButton := aButtons[nB]
         oButton:setFocus()
         oButton:select()
         oButton:killFocus()   
      ELSEIF oBrowse != NIL
         IF nKey == K_TAB
            IF nActiveBrowse < Len(aBrowse)
               Eval(bChangeBrowse,nActiveBrowse+1)
            ELSE
               Eval(bChangeBrowse,1)
            ENDIF
         ELSEIF nKey == K_SH_TAB .AND. nActiveBrowse > 1
            Eval(bChangeBrowse,nActiveBrowse-1)
         ELSEIF nKey == K_LBUTTONDOWN .AND. ((oBrowse:ClassName == "TBROWSETR" .AND. ! oBrowse:HitTest()) .OR. (oBrowse:ClassName == "TABROWSE" .AND. oBrowse:HitTest(mRow()+1,mcol()) == 0))
            FOR nX := 1 TO Len(aBrowse)
               IF nX != nActiveBrowse .AND. ((aBrowse[nX,1]:ClassName == "TBROWSETR" .AND. aBrowse[nX,1]:HitTest()) .OR. (aBrowse[nX,1]:ClassName == "TABROWSE" .AND. aBrowse[nX,1]:HitTest(mrow()+1,mcol()) != 0))
//                     aBrowse[nX]:HitTest()
                  Eval(bChangeBrowse,nX)
               ENDIF
            NEXT
            LOOP
         ENDIF
         
         oBrowse:Event({nKey})
      ELSEIF SetKey(nKEY) != NIL
         Eval(SetKey(nKEY),PROCNAME(2),PROCLINE(2),"","")

      ENDIF
   ELSE
      oBrowse:Display()
   ENDIF
ENDDO

//the mask is left - close the drawing window (if it is still open)
IF nWebView != NIL
   hb_webview_destroy(nWebView)
   nWebView := NIL
ENDIF

RETURN

STATIC Function GetCompPrices(nR,nC2,aPrices,cMeTr)
   LOCAL aCompet,nT
   LOCAL aBrakes,nY,nP,nLen,nMaxLen,nX,hPrices,hPriceList
   LOCAL aEnv := SaveEnv()
   LOCAL lDebug := .F. //Tr_Getini(28) == 9

   MEMVAR c_five

   NetUse("comprice2","cmp2")

   IF lDebug
      aCompet := {"ARROW"}
   ELSE
      aCompet := {"RS","Farnell","Ettinger","Schukat","Arrow",HB_AnsiToOem("BUERKLIN"),"TME","CONRAD"} //,"Reichelt","Conrad","TME","Mouser"
   ENDIF

   nR := 1
   nT :=  20
   @ nT,nC2 CLEAR TO nT+12,nC2+36
   @ nT,nC2 SAY "Preise werden geladen..."

   aBrakes := {}
   hPriceList := {=>}

   FOR nX := 1 TO Len(aCompet)

      ku->(dbSetOrder( 1 ))
      ku->(dbSeek( Pad(Upper(aCompet[nX]),8)+"L" ))
      ali->(dbSeek(Pad(Upper(aCompet[nX]),8)+Str(art->Artikelnr,6)))
      IF aCompet[nX] $ "TME Schukat" .OR. (ali->(Found()) .AND. ! Empty(ali->artlief))
         @ nT+nR,nC2 SAY aCompet[nX]
         /*IF lDebug .OR. (! cmp2->(dbSeek( Str(art->Artikelnr,6)+Str(ku->Nummer,6) )) .AND. cmp2->Datum < Date())
            hPrices := MBaseRun(Trim(Tr_Getini(1))+"\run\prices\"+HB_OemToAnsi(aCompet[nX]),{art->Artikelnr,ali->Artlief,art->Matchcode})
            IF ValType(hPrices) == "H" .AND. Len(hPrices) != 0
               IF ! cmp2->(dbSeek( Str(art->Artikelnr,6)+Str(ku->Nummer,6) ))
                  cmp2->(Add_Rec(0))
                  cmp2->Artikelnr := art->Artikelnr
                  cmp2->Lieferant := ku->Nummer
               ELSE
                  cmp2->(Rec_Lock())
               ENDIF
               cmp2->Datum := Date()
               cmp2->Daten := HB_Serialize(hPrices)
               cmp2->(dbUnLock())
            ENDIF
         ELSE
            hPrices := HB_DeSerialize(cmp2->Daten)
         ENDIF*/
         hPrices := GetPricesCompet(aCompet[nX],lDebug)
         @ nT+nR,nC2+9 SAY Space(24)
         IF ValType(hPrices) != "H" .OR. Len(hPrices) == 0
            @ nT+nR,nC2+9 SAY "FEHLER!"
         ELSE
            @ nT+nR,nC2+9 SAY LTrim(Transform(HGetKeyAt(hPrices,1),cMeTr))+" - "+LTrim(Str(HGetValueAt(hPrices,1),12,2))+" | "+LTrim(Transform(HGetKeyAt(hPrices,Len(hPrices)),cMeTr))+" - "+LTrim(Str(HGetValueAt(hPrices,Len(hPrices)),12,2))
            FOR nY := 1 TO Len(hPrices)
               IF AScan(aBrakes,HGetKeyAt(hPrices,nY)) == 0
                  Aadd(aBrakes,HGetKeyAt(hPrices,nY))
               ENDIF
            NEXT
            hPriceList[aCompet[nX]] := hPrices
         ENDIF
         nR++
      ENDIF
   NEXT
   ASort(aBrakes)
    //Inkey(0,128)
   /*IF HHasKey(hPriceList,"Ettinger")
      nKey := HGetKeyAt(hPriceList["Ettinger"],Len(hPriceList["Ettinger"]))
      IF nKey != ATail(aBrakes)
         hPriceList["Ettinger"][Atail(aBrakes)] := hPriceList["Ettinger"][nKey]
         HDel(hPriceList["Ettinger"],nKey,.T.)
      ENDIF
   ENDIF*/

   @ nT,nC2 CLEAR TO nT+12,nC2+36

   nLen := Int(36/(Len(hPriceList)+1))

   nMaxLen := 1
   FOR nY := 1 TO Len(aBrakes)
      nMaxLen := Max(nMaxLen,Len(LTrim(Transform(aBrakes[nY],cMeTr))))
      FOR EACH hPrices IN hPriceList
         IF HHasKey(hPrices,aBrakes[nY])
//               Alert( hPrices:__enumKey()+ Str(aBrakes[nY])+" "+Str(Len(LTrim(Str(hPrices[aBrakes[nY]],12,2)))) )
            nMaxLen := Max(nMaxLen,Len(LTrim(Str(hPrices[aBrakes[nY]],12,2))))
         ENDIF
      NEXT
   NEXT

   IF nLen < nMaxLen+1
      nLen := nMaxLen+1
      nC2 := nC2+36-nLen*(Len(hPriceList)+1)
      @ nT-1,nC2-1 TO nT+13,maxCol()-1 //Chr(179)
      @ nT-1,MaxCol()-1 CLEAR TO nT+13,MaxCol()-1
      @ nT,nC2 CLEAR TO nT+12,maxCol()-2 //Chr(179)

   ENDIF

   FOR nY := 0 TO Len(aBrakes)
      IF nY != 0
         @ nT+nY,nC2 SAY LTrim(Transform(aBrakes[nY],cMeTr))
      ENDIF
      FOR EACH hPrices IN hPriceList // nX := 1 TO Len(aCompet)
         IF nY == 0
            @ nT+nY,nC2+(hPrices:__enumIndex())*nLen SAY Pad(hPrices:__enumKey(),nLen-1)
         ELSEIF HHasKey(hPrices,aBrakes[nY])
            nP := RAScan(aPrices,{|x| x[1] <= aBrakes[nY] })
            IF nP == 0
               nP := 1
            ENDIF
//            @ MaxRow(),00 SAY Str(aPrices[nP,2]/art->VkPe)+" "+Str(hPrices[aBrakes[nY]])
            @ nT+nY,nC2+(hPrices:__enumIndex())*nLen SAY LTrim(Str(hPrices[aBrakes[nY]],12,2)) COLOR IF(Len(aPrices) > 0 .AND. nP > 0 .AND. aPrices[nP,2]/art->VkPe > hPrices[aBrakes[nY]],"R+/R",c_five)
//               @ nT+nY,nC2+(hPrices:__enumIndex())*nLen-3 SAY "("+Str(nP,1)+")"
         ENDIF
      NEXT
   NEXT

   
   RestEnv(aEnv,.F.)
//   hb_threadWait(pThread,0.01)
//   pThread := NIL
RETURN NIL

STATIC Function CalcLZ(oArtikel,lShow)

LOCAL cDisp := ""
LOCAL nTotTime := 0,nTotQty := 0,nBesKW
LOCAL nTime,nWeek

NetUse("manufact","manu")
NetUse("artlief","ali")
NetUse("engkund","ku")
NetUse("engbes","bes")
NetUse("lspos","lsp")
NetUse("ls","ls")
NetUse("parts","part")

IF ! art->Lagerart
   RETURN 0
ENDIF

IF art->Bezug >= 5 //Fertigungsartikel
/*   nArtnr := art->Artikelnr
   ? nArtnr,art->Matchcode
   nOrd := art->(dbSetOrder( 2 ))
   part->(dbPush())
   part->(dbSeek( Str(art->Artikelnr,6) ))
   DO WHILE part->ListArt == nArtnr .AND. ! part->(EOF())
      ? part->ListArt,part->PartArt
      IF part->Pos > 0 .AND. part->Qty > 0
         art->(dbSeek( Str(part->Partart,6) ))
         nLZ := CalcLZ(lShow)
         ?? "",art->Artikelnr,art->Matchcode,art->Lagerart,art->Bezug,nLZ
         nTotTime := Max(nTotTime,nLZ)
      ENDIF
      part->(dbSkip())
   ENDDO
   nTotQty := 1
   art->(dbSeek( Str(nArtnr,6) ))
   art->(dbSetOrder( nOrd ))
   part->(dbPop())
IF Inkey(0,128) == 27
   RETURN 0
ENDIF   */
ELSE

   manu->(dbGoto( art->Manufactur ))

   ku->(dbSetOrder( 8 ))
   IF art->Manufactur == 5 //Engelking China
      ku->(dbSeek( Str(22065,6) ))
   ELSE
      ku->(dbSeek( Str(manu->Address,6) ))
   ENDIF

   bes->(dbSetOrder( 8 ))
   lsp->(dbSetOrder( 3 ))
   bes->(dbSetFilter( {|| bes->Besda >= Date()-365 .AND. bes->BeQty > 0 },"besda >= Date()-365 .AND. BeQty > 0"))

   bes->(dbSeek( ku->Kunde+oArtikel:Matchcode ))

   DO WHILE ! bes->(EOF()) .AND. bes->Liefma == ku->Kunde .AND. bes->Matchcode == oArtikel:Matchcode
      nBesKW := Val(CalWeek(bes->Besda))
      nTime := 0
      IF bes->LTerm > bes->Wterm
         nTime := WeeksBetween(nBesKW,bes->Lterm+bes->ShipTime)
         nTotQty += bes->BeQty-bes->GelQty
         nTotTime += nTime*(bes->BeQty-bes->GelQty)
      ENDIF
      cDisp += Str(bes->Besnr,6)+" "+Str(bes->Posnr,3)+" Anzahl:"+Ltrim(Str(bes->BeQty,12,2))+" WT:"+StrZero(bes->WTerm,4)+" LT:"+StrZero(bes->LTerm,4)+" Offen: "+LTrim(Str(bes->BeQty-bes->GelQty))+" Wochen:"+LTrim(Str(nTime))+Chr(13)+Chr(10)

      IF bes->LTerm > bes->Wterm .OR. (bes->WTerm == nBesKW .AND. bes->Lterm == bes->WTerm) //either delivery time (if lterm>wterm) or laufzeit if immediate
         lsp->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
         DO WHILE ! lsp->(EOF()) .AND. lsp->Besnr == bes->Besnr .AND. lsp->BesPos == bes->Posnr
   
            ls->(dbSeek( lsp->Liefma+lsp->Beleg ))
   
            nTime := (ls->Datum-bes->Besda)/7
   
            nTotQty += lsp->Geliefert
            nTotTime += nTime*lsp->Geliefert
            nWeek := Val(CalWeek(ls->Datum))
   //         nLate := WeeksBetween(bes->Lterm+bes->ShipTime,nWeek)
   //+" Verspaetet:"+Str(nLate,2)+
            cDisp += Space(10)+DToc(ls->Datum)+" Angekommen:"+StrZero(nWeek,4)+" Beleg:"+Trim(lsp->Beleg)+" Anzahl:"+Ltrim(Str(lsp->Geliefert,12,2))+" Lieferdauer in Wochen:"+Str(nTime,2)+Chr(13)+Chr(10)
   
            lsp->(dbSkip())
         ENDDO
      ENDIF
      bes->(dbSkip())
   ENDDO
   bes->(dbClearFilter())
ENDIF

IF lShow == .T.
   memoEdit(cDisp)
ENDIF

IF nTotQty > 0
   RETURN Round(nTotTime/nTotQty,0)
ENDIF
RETURN 0

STATIC FUNCTION __DispTime(nMin)
/*   LOCAL nH := Int(nMin/60),nM:= Int(nMin-nH*60),nS := Int((nMin-nH*60-nM)*60)
   LOCAL cTime := ""
   IF nH > 0
      cTime += Ltrim(Str(nH))+":"
   ENDIF
   IF nM > 0
      cTime += Ltrim(Str(nM))+":"+StrZero(nS,2)
   ENDIF
   IF nH > 0
      cTime += " h"
   ELSE
      cTime += " min"
   ENDIF
RETURN Trim(cTime)*/
IF nMin > 60
   RETURN Str(nMin/60,5,2)+" h"
ENDIF
RETURN Str(nMin,5,2)+" min"

//Display a drawing in an embedded webview window instead of handing it over to the
//shell. Everything the browser cannot render (ZIP, DWG, ...) still goes to the
//associated application. The window is reused as long as the user keeps it open,
//so the handle is returned to the caller.
STATIC FUNCTION ShowDrawing(nWebView,cFile,cTitle)
LOCAL cExt

IF Empty(cFile)
   RETURN nWebView
ENDIF

cExt := "|"+Upper(SubStr(cFile,RAt(".",cFile)))+"|"
IF ! (cExt $ "|.PDF|.PNG|.JPG|.JPEG|.GIF|.BMP|.SVG|.WEBP|.TXT|.HTM|.HTML|")
   WAPI_ShellExecute(,"open",cFile)
   RETURN nWebView
ENDIF

IF nWebView == NIL .OR. ! WAPI_ISWINDOW( hb_webview_get_window(nWebView) )
   //there is no window yet or the user has closed it
   nWebView := hb_webview_create( .T. )
ENDIF

hb_webview_navigate(nWebView,"about:blank")   //drop the drawing shown before
hb_webview_navigate(nWebView,DrawingUrl(cFile))
hb_webview_set_title(nWebView,cTitle)

RETURN nWebView

//Build a file:// URL the webview understands - UNC paths included
STATIC FUNCTION DrawingUrl(cFile)
LOCAL cUrl := StrTran(hb_strToUtf8(cFile),"\","/")

cUrl := StrTran(cUrl,"%","%25")
cUrl := StrTran(cUrl,"#","%23")
cUrl := StrTran(cUrl,"?","%3F")
cUrl := StrTran(cUrl," ","%20")

IF Left(cUrl,2) == "//"    //UNC: \\server\share\... -> file://server/share/...
   RETURN "file:"+cUrl
ENDIF

RETURN "file:///"+cUrl



#include 'x:\run\prices\getprices.prg'
#include 'x:\run\shopware.prg'
