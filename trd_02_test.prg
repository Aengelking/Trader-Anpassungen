SqlOpen("contacts","conts")
conts->(dbSetOrder(1))

hTurnover := If(ku->Group=="K",GetCustomerTurnover(ku->kunde),{"open"=>ku->open,"current"=>ku->Turnover,"last"=>ku->turnoverol,"last3"=>0,"total"=>ku->turnoverto})
aAngebot := GetCustomerOpenEnquiries(ku->Kunde)

SetColor(c_five)

nTop := 01
nLeft := 78
nBottom := 26
nRight := 152

@ nTop,nLeft CLEAR TO nBottom,nRight
@ nTop,nLeft TO nBottom,nRight

@ nTop,nLeft+2 SAY "[" + ku->kunde + "]"

IF(ku->group == "K", bold( nTop+1,nLeft+2,msb[4],0 ),IF(ku->group == "L", bold( nTop+1,nLeft+2,msb[5],0 ),bold( nTop+1,7,msb[6]+ku->group+"    ",0 )))
ku->( yesnotes() )
notiz := .T.

//Top Left
DevPos( nTop+2, nLeft+2 )
DevOut( ku->name1 )
DevPos( nTop+3, nLeft+2 )
DevOut( ku->name2 )
DevPos( nTop+4, nLeft+2 )
DevOut( ku->Street )
DevPos( nTop+5, nLeft+2 )
DevOut( TRIM( ku->plz ) + " " + ku->town )
DevPos( nTop+6, nLeft+2 )
DevOut( ku->Country )

bold(nTop+8,nLeft+2,msb[7] + ku->telefon,0)

@ nTop+9, nLeft+2 SAY "EMAIL    " + Pad(ku->Email,27)
@ nTop+10, nLeft+2 SAY msb[9] + ku->telefax

SKONTVA(ku->Skonto,"D",nBottom-9,nLeft+2)





DevPos( nTop+1, 44 )
DevOut( if(ku->group = "L",msb[10] + ku->kundennr,msb[11] + ku->kundennr) )
//DevPos( nTop+2, 44 )
//DevOutPict( msb[12] + ku->bank, "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" )
//DevPos( nTop+3, 44 )
//DevOut( msb[13] + ku->konto )
DevPos( nTop+2, 44 )
DevOut( msb[14] + STR( ku->charge ) )

@ nTop+3,44 TO nTop+3,76
@ nTop+3,45 SAY " Umsatz "
DevPos( nTop+4, 44 )
DevOut( "Aktuell:" +" EUR "+ (STR( hTurnover["current"],12,2)) )
DevPos( nTop+5, 44 )
DevOut( "Vorjahr:" +" EUR "+(STR( hTurnover["last"],12,2 )) )
@ nTop+6,44 SAY "3-Jahre: EUR "+(Str(hTurnover["last3"],12,2))
//LTrim(STR( ku->turnoverol )) )
@ nTop+7,44 SAY "Gesamt : EUR "+(Str(hTurnover["total"],12,2))
@ nTop+8,44 TO nTop+8,76
If ku->Group == "K"
	@ nTop+09,44 SAY "Offene Auftr„ge: EUR "+(Str(GetCustomerOpenOrders(ku->kunde),12,2))
	@ nTop+10,44 SAY "Offene Angebote: EUR "+(Str(aAngebot[2],12,2))
	@ nTop+11, 44 SAY "Limit  EUR: " + LTRIM(STR(ku->credlimit,13,0))
	@ nTop+12, 44 SAY "Offen  EUR: " + LTRIM(STR(hTurnover["open"],12,2))
	@ nTop+13, 44 SAY "Kredit "+Currate(ku->Money,"X")+": " + LTRIM(STR(GetCustomerCredit(ku->Kunde),12,2))
Endif
If ku->Group == "L"
	@ nTop+9,44 SAY "Offene Best.: EUR "+(Str(GetSupplierOpenOrders(ku->kunde),12,2))
Endif

@ nBottom-7, nLeft+1 TO nBottom-7,nRight-1 //divider
DevPos( nBottom-7, nLeft+2 ); DevOut( " "+msb[17]+" " )


conts->(dbSeek( Str(ku->Nummer,6),.T. ))
If conts->address == ku->Nummer .AND. conts->Active
	oBrowse := conts->(TBrowseTr(nBottom-6,nLeft+2,nBottom-1,nLeft+30))
	oBrowse:NewColumn( Nil, {|| Pad(conts->Name,36)  } )
 	oBrowse:lBox := .F.
 	oBrowse:lArrow := .F.
  	oBrowse:WhileBlock := {|| conts->address == ku->Nummer .AND. conts->Active}
  	//oBrowse:ColorSpec := "W/B+,N+/B+,,N/W,N+/W"
//  	oBrowse:aKeys := { 27, 32 } //, K_INS, K_ENTER, K_SH_TAB, K_TAB, K_DEL }
//  	oBrowse:aFun := {{||.F.},{|| .F. }} //,{|| EditContact(.T.)},{|| If(conts->address==nNummer .AND. conts->active,EditContact(.F.),.T.) }, {|| .F. }, {|| .F. }, {|oBrowse| If(conts->address==nNummer,DelContact(),.T.), oBrowse:RefreshAll(),.T. } } //,{||.F.},{|| re->(DispInfo("trd_repos")) } }
  	oBrowse:bRestFun := {|| .F. }
  	nP := nLeft+32
	nW := nRight-nP-9

  	bBlock := {|| DevPos(nBottom-4,nP), DevOut("Fax     "+Pad(conts->Fax,nW)),DevPos(nBottom-3,nP),DevOut("Email   "+Pad(conts->Email,nW)),DevPos(nBottom-2,nP), DevOut("Abt.    "+Pad(conts->Department,nW)) }
  	oBrowse:bAnyFun := {|| DevPos(nBottom-6,nP), DevOut("Telefon "+Pad(conts->Telephone,nW)),DevPos(nBottom-5,nP), DevOut("Handy   "+Pad(conts->Mobile,nW)), Eval(bBlock),.T. }

//
//  	oBrowse:EventLoop()
	oBrowse:Display()
Else
	@ nBottom-6,38 SAY "---"
//	Sinkey(0,128)
Endif
/*
DevPos( nBottom-6, 38 )
DevOut( "1: "+TRIM(ku->person)+" "+TRIM(ku->telefon1) )
DevPos( nBottom-5, 38 )
DevOut( "2: "+TRIM(ku->person2)+" "+TRIM(ku->telefon2) )
DevPos( nBottom-4, 38 )
DevOut( "3: "+TRIM(ku->person3)+" "+TRIM(ku->telefon3) )
DevPos( nBottom-3, 38 )
DevOut( "4: "+TRIM(ku->person4)+" "+TRIM(ku->telefon4) )
DevPos( nBottom-2, 38 )
DevOut( "5: "+TRIM(ku->person5)+" "+TRIM(ku->telefon5) )
//DISPEND()
SInkey(0,128)*/