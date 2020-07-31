PARAMETERS nArtnr,cArtlief
	    cSearch := "Liefermenge"
       RETURN -1
		//oHttp := TIpClientHttp():new( "http:/"+"/de.farnell.com/bulgin/dp/"+Trim(alil->artlief) )
		//cUrl := "http:/"+"/www.ettinger.de/War_Main.cfm?ODT_ARTNUM="+StrTran(Trim(alil->artlief),".","")+"&ODT_BESMENGE=1000000"
		cUrl := "http://ettinger.de/de/product/"+cArtLief

		oHttp := TIpClientHttp():new( cUrl )
	    If oHttp:open()
//	        oHttp:Post({"ODT_ARTNUM"=>StrTran(Trim(alil->artlief),".",""),"ODT_BESMENGE"=>LTrim(Str(100000)) })
	    	cData := oHttp:readAll()
		    nAT := AT(cSearch,cData)
		    If nAT == 0
		    	Alert("Liefermenge nicht gefunden!")
		    	Return 0
		    Endif
		  	cData := SubStr(cData,nAt+Len(cSearch))
		  	nSt := AT("<b",cData)+3
		  	Return Val(Substr(cData,nSt,At("/b",cData)-1-nSt))
		Else
			Return -1 //@ 06,22 SAY "fehlgeschlagen"
	    Endif
