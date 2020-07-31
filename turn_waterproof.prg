LOCAL nYear := 2014
LOCAL hSplitPrice := {=>}

NetUse("ENGLSRE","RE")
NetUse("artikel","art")

art->(dbSetOrder( 2 ))
re->(dbSetOrder(9))
re->(dbSeek( Str(nYear,4)+"0101",.T. ))

hPoles := {=>}
hProducts := {;
   "PX0839"=>"RJ45",;
   "PX0960"=>"CAP",;
   "PX0443"=>"USB",;
   "PX048"=>"CAP",;
   "PX0980"=>"CAP",;
   "PX099"=>"CAP",;
   "PX0960"=>"CAP",;
   "PX0970"=>"CAP",;
   "PX0842"=>"RJ45",;
   "PX0733"=>"CAP",;
   "140"=>"TOOL",;
   "PX0833"=>"RJ45",;
   "SA3147"=>"CONT",;
   "SA3148"=>"CONT",;
   "SA3149"=>"CONT",;
   "SA3179"=>"CONT",;
   "SA3180"=>"CONT",;
   "SA3347"=>"CONT",;
   "SA3348"=>"CONT",;
   "SA3349"=>"CONT",;
   "SA3350"=>"CONT",;
   "PX040"=>"SMB",;
   "PX0735"=>"2",;
   "PX0736"=>"2",;
   "PX0731"=>"3",;
   "PX0732"=>"3",;
   "PX0745"=>"7",;
   "PX0746"=>"7",;
   "PX0747"=>"4",;
   "PX0748"=>"4",;
   "PX0749"=>"4",;
   "PX0760"=>"7",;
   "PX0820"=>"25",;
   "PX0799"=>"PART",;
   "QX2139"=>"PART",;
   "PX0930"=>"PART",;
   "PX0800"=>"PART",;
   "PX0801"=>"PART",;
   "PX0804"=>"PART",;
   "PX0805"=>"PART",;
   "12735"=>"8",;
   "12734"=>"8",;
   "SA3319"=>"2",;
   "SA3320"=>"2",;
   "SA3229"=>"3",;
   "SA3230"=>"3",;
   "13027"=>"TOOL",;
   "PX044"=>"USB",;
   "PX0950"=>"CAP",;
   "EXP-0990"=>"CAP",;
   "PX0734"=>"CAP",;
   "SA3385"=>"PART",;
   "PX0707/P/03"=>"3",;
   "PX0777"=>"TUBE";
}

while ! re->(EOF()) .AND. Year(re->RechDat) == nYear .AND. ! (nKey := Inkey()) == 27
   @ 09,0 SAY STR(re->(Recno()),10)
   IF RE->REPOSNR != 0
      IF art->(dbSeek(Str(re->ArtikelNr,6)))
/*         IF art->Bezug >= 5
            hSplitPrice[art->Artikelnr] := {=>}
               hAvgPrice[art->Artikelnr] := StCalc(art->Artikelnr,6,999,.T.,dDate,hSplitPrice[art->Artikelnr])
         ELSE
               hSplitPrice[art->Artikelnr] := {"X"=>{"percent"=>1,"group"=>art->Gruppe,"manufacturer"=>art->manufactur}} //100% to the Manufacturer of this product
         ENDIF*/
      Else
//            hAvgPrice[art->Artikelnr] := 0
      Endif

      IF art->Manufactur == 1 .AND. art->Gruppe == "STWP"


         nPrice := RE->PREIS*currate(re->money,"V")/If(re->Pe==0,1,re->pe)
         IF nPrice != 0
            aRegex := HB_RegEx("(PX|EXP)[\-A0-9]*/?([0-9]*)",art->Matchcode)
            ? ValToPrg(aRegex)
            nPoles := 0
            IF Len(aRegex) >= 3 .AND. ! Empty(aRegex[3])
               nPoles := Val(aRegex[3])
            ENDIF
            cKey := Ltrim(Str(nPoles))
            IF nPoles < 1 .OR. nPoles > 12
               cType := ""
               FOR EACH cType IN hProducts
                  IF AT(cType:__eNumKey(),art->Matchcode) == 1
                     cKey := cType
                  ENDIF
               NEXT
            ENDIF
            IF cKey == "0" //.AND. (nPoles < 1 .OR. nPoles > 12)
               ? art->Matchcode
               SInkey(0,128)
            ENDIF
            IF ! HHasKey(hPoles,cKey)
               hPoles[cKey] := 0
            ENDIF
            hPoles[cKey]  += (nPrice*re->aoqty)
         ENDIF
/*          For nX := 1 To Len(hSplitPrice[art->Artikelnr])
            cKey := HGetKeyAt(hSplitPrice[art->Artikelnr],nX)

            cFind := Str(S_MANUFACTURER,5)+S_GRUPPE+Str(Year(re->RechDat),4)+Str(Month(re->RechDat),2)
             IF ! um->(dbSeek(cFind))
               um->(Add_Rec(0))
               um->Manufactur := S_MANUFACTURER
               um->Group  := S_GRUPPE
               um->Month   := STR(MONTH(RE->RECHDAT),2)
               um->Year    := STR(YEAR(RE->RECHDAT),4)
             ELSE
               um->(Rec_Lock(0))
             ENDIF

             um->Umsatz := UM->UMSATZ+(nPrice*re->aoqty)*S_PERCENT

            If Year(re->RECHDAT) == 2010
//                   LOG "Manufacturer",S_MANUFACTURER," Gesamt DB",(nPrice-hAvgPrice[art->Artikelnr])*re->AoQty*S_PERCENT
          Endif
         IF ! re->Folge .OR. nPrice != 0
//                um->UmsatzDB += (nPrice-hAvgPrice[art->Artikelnr])*re->AoQty*S_PERCENT
         ENDIF
      //        um->ek := um->ek+(art->letzte_ek*currate(art->money,"E")*re->aoqty/If(art->pe==0,1,art->pe))
             IF re->status >= 2
               um->pay := um->pay+(re->preis*currate(re->money,"V")*re->aoqty/If(re->pe==0,1,re->pe))
             ENDIF
             um->(dbUnlock())

         Next */
      ENDIF
   ENDIF
   re->(dbSkip(1))
ENDDO
   re->(dbCloseArea())

aPoles := {}
CLS
nPoleVal := 0
FOR EACH nPoleVal IN hPoles
   Aadd(aPoles,{"x"=>nPoleVal:__eNumKey(),"val"=>nPoleVal})
NEXT
ASort(aPoles,,,{|x,y| x["val"] > y["val"] })
FOR nX := 1 TO Len(aPoles)
   ? Pad(aPoles[nX]["x"],5),Str(aPoles[nX]["val"],10,2)
NEXT
Sinkey(0,128)

