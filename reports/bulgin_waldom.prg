LOCAL cLief := Pad("BULGIN",8)
LOCAL cAlt  := Pad("WALDOM",8)
LOCAL nWeeks := 4

Head("Vergleich aktuelle Bestellungen mit einem alternativen Lieferanten")

@ 01,00 SAY "Lieferant  " GET cLief
@ 02,00 SAY "Alternative" GET cAlt
@ 03,00 SAY "Wochen     " GET nWeeks PICTURE "99"
READ

NetUse("engbes","bes")
NetUse("buyprice","bpr")
NetUse("artikel","art")
NetUse("liefstock","lsto")

bes->(dbSetOrder( 2 )) //liefma+str(bestat)
bes->(dbSeek( cLief+Str(0,1) ))

art->(dbSetOrder( 2 ))

CLS
? Pad("Best.",6),Pad("Artikel",25),Pad(cLief,8),Pad(cAlt,8),PadL("Menge",6),PadL("Bestand",6),PadL("USA",6)
nSave := 0

DO WHILE bes->Liefma == cLief .AND. bes->bestat < 3
   IF bes->besda >= Date()-nWeeks*7 .AND. bes->GelQty == 0
      nPrice := 0; nPe := 1
      GetBuyPrice( cAlt, bes->Artikelnr, bes->BeQty, @nPrice, @nPE )
      nEkPr := bes->EkPr/bes->Pe*Currate(bes->Money,"E")
      IF nPrice > 0 .AND. nPrice/nPe <= nEkPr
         art->(dbSeek( Str(bes->Artikelnr,6) ))
         ? bes->Besnr,bes->Matchcode,Str(nEkPr,8,4),Str(nPrice/nPe,8,4),PadL(Transform(bes->BeQty,Me(art->Me)),6)
         nSave += (nEkPr-nPrice/nPe)*bes->BeQty
         IF lsto->(dbSeek( Pad(cAlt,8)+Str(art->Artikelnr,6) ))
            ?? "",PadL(Transform(lsto->Stock,Me(art->Me)),6),PadL(Transform(lsto->DelQty,Me(art->Me)),6)
         ENDIF
      ENDIF
   ENDIF
   bes->(dbSkip())
ENDDO

? "Search completed"
? "To be saved: ",Str(nSave,7,2)
SInkey(0,128)