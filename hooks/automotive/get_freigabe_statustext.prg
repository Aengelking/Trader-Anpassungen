FUNC HOOK_GET_FREIGABE_STATUSTEXT(cState,lFrei,lSonder,nMenge,dDatum,nVerbraucht)
LOCAL hText,cText

hText := {;
   "BAGK"=>"Abstimmung mit Kunden",;
   "BAGL"=>"Abstimmung mit Lieferant",;   
   "PRUE"=>"PrÅfplan",;
   "MUS"=>"Muster intern",;
   "KU"=>"Artikel vom Kunden",;
   "EMPB"=>"EMPB Lieferant";
}

If cState=="DONE"
	If ValType(lFrei) == "L"
		If lFrei
         /*If ValType(lSonder) == "L" .AND. lSonder
            cText := "Sonderfreigabe"
            IF nVerbraucht >= nMenge  .OR. (! Empty(dDatum) .AND. dDatum < Date())
               RETURN cText+" "+"aufgebraucht"
            ELSE
               Return Upper(cText) //+" ("+IF(nMenge>0,LTrim(Str(nMenge,12,0)),"")+IF(!Empty(dDatum)," bis "+DToc(dDatum),"")+")"
            ENDIF
			Else*/
				Return "FREIGEGEBEN"
			//Endif
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
		cText := cText+" "
      IF Left(cState,2) == "BA"
         IF lFrei
            cText += "abgesprochen"
         ELSE
            cText += "abgelehnt"
         ENDIF
      ELSE
         IF lFrei
            cText += "freigegeben"
         ELSE
            cText += "abgelehnt"
         ENDIF         
      ENDIF
	Endif
	Return cText
Endif
Return ""