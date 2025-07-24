FUNCTION HOOK_BEFORE_SAVE_AUFPOS(oAufPos)

LOCAL cBez
LOCAL hFreigabe,nMaxQty,lBes,oLief,hReq
LOCAL lExtern := .F.,lSampleFound
LOCAL aFreigabeList
LOCAL nStock
LOCAL aRegexMatch
LOCAL bGetFreigabe := { |nLief,oLief|
   LOCAL cText
   
   oAufPos:Artikel:gotoRec()   
   hFreigabe := GetFreigabeBesState(nLief)   
   IF nLief == 0
      cText := "INTERN "  
   ELSE
      cText := Trim(oLief:Kunde)+" "
   ENDIF
   IF hFreigabe:lBes       
      IF ! lBes .AND. hFreigabe:nMaxQty != 0 //noch nicht durch anderen Lieferanten freiggebn um Menge beschr„nkt
         nMaxQty += hFreigabe:nMaxQty
         cText += "Freigabe fr "+LTrim(Str(nMaxQty))+" erteilt. " 
         Aadd(aFreigabeList,cText)
      ELSEIF lBes .AND. nMaxQty != 0 .AND. hFreigabe:nMaxQty == 0 //andere Freigabe aeber Beschr„nkt, diese ist unbeschr„nkt, dann Beschr„nkung aufheben
         nMaxQty := 0
      ENDIF            
      lBes := .T. 
      
   ELSE      
      cText += "nicht bestellbar. "
      IF hFreigabe["PPF"] == 0
         cText += "Freigabe nicht begonnen."
      ELSE
         cText += "Freigabe "+GetFreigabeStatusText({GetNextFreigabeLevel(art->Artikelnr,nLief,hFreigabe["ASTATUS"][1]),NIL})+" erforderlich"
      ENDIF
      Aadd(aFreigabeList,cText)
   ENDIF
   
}

MEMVAR c_five

NetUse("engkund","ku")
NetUse("artlief","ali")
NetUse("parts","part")
NetUse("ppf","ppf")

aRegexMatch := HB_Regex("KS([0-9]{5,6}).*",Trim(oAufPos:Artikel:Matchcode))
IF Len(aRegexMatch) == 0
   Tr_MsgBox("Es k”nnen nur KS Artikel an Kunden verkauft werden.")
   RETURN .F.
ELSEIF Val(aRegexMatch[2]) != oAufPos:Auftrag:Kunde:Nummer
   Tr_MsgBox("Artikel "+Trim(oAufPos:Artikel:Matchcode)+" kann nur an Kunde Nr. "+Trim(aRegexMatch[2])+" geliefert werden.")
   RETURN .F.
ENDIF

//Freigabe prfen
hReq := GetProductRequirementAndIncoming(oAufPos:Artikel:Artikelnr)
lBes := .F.
nMaxQty := 0
aFreigabeList := {}
IF ! oAufpos:Artikel:Lagerart
   Eval(bGetFreigabe,0)
ELSE
   ali->(dbSetOrder( 4))
   IF ! ali->(dbSeek( Str(oAufPos:Artikel:Artikelnr,6) )) 
      Alert("Kein Lieferant")
   ELSE
      Alert("Lieferant: "+ali->Kunde)
   ENDIF
   
   DO WHILE ali->Artikelnr == oAufPos:Artikel:Artikelnr 
      oLief := Adresse():New()
      oLief:LoadMatchcode(ali->Kunde,"L")      
      
      Eval(bGetFreigabe,oLief:Nummer,oLief)
      
      ali->(dbSkip())
   ENDDO
   
ENDIF
IF art->Lagerart
   nStock := oAufPos:Artikel:Bestand-hReq["requirement"]  //not planned stock
ELSE
   nStock := 0
ENDIF
IF HHasKey(hReq["months"],Str(0,5)+Str(0,3)) //week > 52, e.g. 97, then this is available too
   nStock += hReq["months"][Str(0,5)+Str(0,3)]["requirement"]
ENDIF
IF ! oAufpos:lNew .AND. Right(Str(oAufPos:GetField("DTERM",.T.),4),2) != "97"  //if it was 97 it has already been added
   nStock += IF(oAufpos:Bestat<3,oAufPos:GetField("VkQty",.T.),0)
ENDIF
IF (! lBes .AND. nStock < oAufPos:VkQty) .OR. (nMaxQty > 0 .AND. nMaxQty+nStock < oAufPos:VkQty);  //other orders should already be on 097 - so only this is important
   .AND. oAufPos:ContrPos == 0

   auf->(dbSetOrder( 13 ))
   auf->(dbSeek( Str(oAufpos:Artikel:Artikelnr,6) ))
   lSampleFound := .F.
   DO WHILE auf->Artikelnr == oAufpos:Artikel:Artikelnr .AND. (auf->Bestat <= 3 .OR. (auf->Bestat >= 4 .AND. auf->Bestat < 6))
      IF (auf->Bestat != 3 .AND. auf->VkQty <= nMaxQty) .OR. (auf->Bestat == 3 .AND. auf->GelQty <= nMaxQty)
         lSampleFound := .T.
      ENDIF         
      auf->(dbSkip())
   ENDDO
   IF ! lSampleFound .AND. oAufPos:lNew
      IF nMaxQty == 0
         HB_AIns(aFreigabeList,1,"Keine Freigabe vorhanden",.T.)   
      ELSE
         HB_AIns(aFreigabeList,1,"Zuerst Position mit Erstmuster anlegen. Maximal: "+LTrim(Transform(nMaxQty,oAufpos:Artikel:cPicture)),.T.)
      ENDIF
      Tr_MsgBox(aFreigabeList)
      RETURN .F.
   ELSEIF Right(Str(oAufPos:DTerm,4),2) != "97"
      HB_AIns(aFreigabeList,1,"Freigabe nicht ausreichend - Liefertermin auf 'folgt' (KWxx97) setzen. Maximal: "+LTrim(Transform(nMaxQty+nStock,oAufpos:Artikel:cPicture)),.T.)   
      Tr_MsgBox(aFreigabeList)
      RETURN .F.
   ENDIF
ENDIF 


//Kundenbezeichnung Pflicht
IF ! Trim(oAufPos:Artikel:Matchcode) $ {"@","TEXT"} 
   aku->( dbSetOrder( 1 ) )
   IF ! aku->( dbSeek( oAufPos:Auftrag:KundMa + Str( oAufPos:Artikelnr, 6 ) ) ) .OR. Empty(aku->Artlief)
      cBez := GetBox(Space(35),"Bitte Kundenbezeichnung hinterlegen")
      IF ! Empty(cBez) .AND. LastKey() != 27
         IF ! aku->( dbSeek( oAufPos:Auftrag:KundMa + Str( oAufPos:Artikelnr, 6 ) ) )
            aku->(Add_Rec())
         ELSE
            aku->(Rec_Lock())
         ENDIF
         aku->Kunde     := oAufPos:Auftrag:KundMa
         aku->Artikelnr := oAufPos:Artikelnr
         aku->Matchcode := oAufPos:Artikel:Matchcode
         aku->Artlief   := cBez
         aku->(dbUnLock())
      ELSE
         RETURN .F.
      ENDIF
   ENDIF
ENDIF
