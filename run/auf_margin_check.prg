LOCAL nTotal,nCount,nVal


LOCAL nNeed  := 0

NetUse("auftrag","ab")
ab->(dbGoBottom())
CLS
DO WHILE ! ab->(BOF()) .AND. ab->Besda >= StoD("20140101")  .AND. Inkey() != 27
   oAuftrag := Auftrag():New()
   oAuftrag:Load(ab->Abnr)

   nVal := oAuftrag:Total
   
   IF nVal > 0

      nTotal := 0
      nCount := 0
   
      oAuftrag:Positions:Each({|oPos|
         IF oPos:FolgeTo == 0
            IF oPos:IsRahmen
               nQty := oPos:ContrQty-IF(oPos:Bestat==3,oPos:VkQty,0)
            ELSE
               nQty := IF(oPos:Bestat==3,oPos:GelQty,oPos:VkQty)
            ENDIF
            nTotal += oPos:GetMargin()*nQty
            nCount += nQty
         ENDIF
      })
      IF nCount != 0
         nMarg := nTotal/nCount
         IF nMarg < 0.2
            ? oAuftrag:kundma,oAuftrag:AbNr,nMarg*100,oAuftrag:Total
         ENDIF
      ENDIF
   
   ENDIF
   ab->(dbSkip(-1))
ENDDO
Inkey(0,128)