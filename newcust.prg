#define CRLF Chr(13)+Chr(10)

dSeit := Date()-7

NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder( 2 ))
ku->(dbSeek( "K" ))

cEmail := HB_AnsiToOem("<table width='100%'><tr><td>Matchcode</td><td>Name</td><td>PLZ + Ort</td><td>Umsatz</td><td>Aufträge</td><td>Angebote</td></tr>")

Do While ku->Group == "K" .AND. ! ku->(Eof())
	If ku->K_SEIT >= Date()-5
		hTurnover := GetCustomerTurnover(ku->kunde)
		aAngebot := GetCustomerOpenEnquiries(ku->Kunde)

		cEmail += "<tr><td>"+ku->Kunde+"</td><td>"+Trim(Trim(ku->Name1)+" "+ku->Name2)+"</td><td>"+Trim(ku->PLZ)+" "+ku->Town+"</td>"
		cEmail += "<td>"+LTrim(Str(hTurnover["total"],12,2))+"</td>"
		cEmail += "<td>"+LTrim(Str(GetCustomerOpenOrders(ku->kunde),12,2))+"</tr>"+CRLF
		cEmail += "<td>"+LTrim(Str(aAngebot[2],12,2))+"</td>"
	Endif
	ku->(dbSkip())
Enddo

cEmail += "</table>"

SendMail({{"amos.engelking@engelking.de","Amos"}},"Neukunden seit "+DToC(dSeit),cEmail,,,,.T.)