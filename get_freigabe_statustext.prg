FUNC HOOK_GET_FREIGABE_STATUSTEXT(cState,lFrei,lSonder,nMenge,dDatum,nVerbraucht)
LOCAL hText,cText

hText := {"VMU"=>"Vorserienmuster","UNT"=>"Fertigungsunt.","UNTK"=>"Unt. v. Kunden","MUS"=>"Muster","KU"=>"Vom Kunden","ZNG"=>"Zeichnung"}
If cState=="DONE"
	If ValType(lFrei) == "L"
		If lFrei
         If ValType(lSonder) == "L" .AND. lSonder
            cText := "Sonderfreigabe"
            IF nVerbraucht >= nMenge  .OR. (! Empty(dDatum) .AND. dDatum < Date())
               RETURN cText+" "+"aufgebraucht"
            ELSE
               Return Upper(cText) //+" ("+IF(nMenge>0,LTrim(Str(nMenge,12,0)),"")+IF(!Empty(dDatum)," bis "+DToc(dDatum),"")+")"
            ENDIF
			Else
				Return "FREIGEGEBEN"
			Endif
		Else
			Return "abgebrochen"
		Endif
   Endif
Elseif cState == "DEL"
   RETURN "zurÅckgesetzt"
Elseif cState == ""
	Return "nicht begonnen"
Elseif HHasKey(hText,cState)
	cText := hText[cState]
	If ValType(lFrei) == "L"
		cText := cText+" "+If(lFrei,IF(cState${"VMU","MUS"},"geprÅft","freigegeben"),"abgelehnt")
	Endif
	Return cText
Endif
Return ""