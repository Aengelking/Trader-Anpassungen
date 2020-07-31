PARAMETERS nArtnr,cArtlief

//http://www.elimec.co.il/eng/stock/ITW%20SWITCHES/59-111

aEnv := SaveEnv()

NetUse("artikel","art",.F.,0)
art->(dbSetOrder(2))
art->(dbSeek( Str(nArtnr,6) ))

cSearch := "In Stock:"

oHttp := TIpClientHttp():new( "http:/"+"/www.elimec.co.il/eng/stock/ITW%20SWITCHES/"+Trim(art->Matchcode) )
If oHttp:open()
	//oHttp:Post({"ODT_ARTNUM"=>StrTran(Trim(alil->artlief),".",""),"ODT_BESMENGE"=>LTrim(Str(100000)) })
	cData := oHttp:readAll()
	nAT := AT(cSearch,cData)
	If nAT == 0
		Alert("Liefermenge nicht gefunden!")
		RestEnv(aEnv,.F.)
		Return 0
	Endif
		cData := SubStr(cData,nAt+Len(cSearch))
		nSt := AT("b>",cData)+3
		RestEnv(aEnv,.F.)
		Return Val(Substr(cData,nSt,At("/div",cData)-1-nSt))
Else
	RestEnv(aEnv,.F.)
	Return -1 //@ 06,22 SAY "fehlgeschlagen"
Endif

