PROCEDURE RUN_CHECK_MUSTER_BESTELLUNGEN
   LOCAL cFilter,hUser,aBes
   LOCAL hUsers :=  {=>}
   LOCAL oArt,oUsr,cText
   NetUse("engbes","bes")
   NetUse("artikel","art")
   NetUse("buyer","buy")
   art->(dbSetOrder( 2 ))
   cFilter := "bestat < 3 .AND. beqty-gelqty > 0 .AND. ekpr == 0 .AND. folgeto == 0 .AND. ! mahnen .AND. lterm < "+CalWeek(Date())
   bes->(dbSetFilter({|| bes->(&(cFilter))},cFilter))
   bes->(dbGoTop())
   DO WHILE ! bes->(EOF())
      IF ! HHasKey(hUsers,bes->Buyer)
         hUsers[bes->Buyer] := {}
      ENDIF
      oArt := Artikel():New()
      oArt:Load(bes->Artikelnr)
      IF oArt:Lagerart
         Aadd(hUsers[bes->Buyer],{"BESNR"=>bes->Besnr,"ARTIKEL"=>oArt,"QTY"=>bes->BeQty-bes->Gelqty})
      ENDIF
      bes->(dbSkip())
   ENDDO
   FOR EACH hUser IN hUsers
      ASort(hUser,{|x,y| x:Besnr < y:Besnr })
      oUsr := User():New()
      oUsr:Load(hUser:__eNumKey())
      cText := "Hallo "+Trim(SubStr(oUsr:Buyer,1,AT(" ",oUsr:Buyer)))+",<br><br>"
      cText += "bei folgenden Bestellungen fÅr Muster sind noch nicht alle Teile eingetroffen:<br><pre>"
      cText += Pad("Besnr.",6)+" "+Pad("Artikel",25)+" "+"Menge"
      FOR EACH aBes IN hUser
         cText += "<br>"+Str(aBes:Besnr,6)+" "+aBes:Artikel:Matchcode+" "+Transform(aBes:Qty,oArt:cPicture)
      NEXT
      cText += "</pre>"
      SendMail({{oUsr:Email,Trim(oUsr:Buyer)}},"Fehlende Musterlieferung",cText)
   NEXT
   
   bes->(dbClearFilter())
RETURN
