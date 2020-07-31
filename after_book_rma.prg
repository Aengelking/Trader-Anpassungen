PARAMETERS oRmaPos,nMenge,cLagerort
LOCAL cText 

cText := "Artikel : "+oRmaPos:Matchcode+"<br />"
cText += "Anzahl  : "+Transform(nMenge,oRmaPos:oRechPos:oArtikel:cPicture)+"<br />"
cText += "Lagerort: "+cLagerort+"<br />"
cText += "AB      : "+LTrim(Str(oRmaPos:Abnr))+" Pos.: "+LTrim(Str(oRmaPos:RePos))+"<br />"
cText += "Rechnung: "+LTrim(Str(oRmaPos:Rechnung))

SendMail({{"amos.engelking@engelking.de","Amos"}},"RMA "+LTrim(Str(oRmaPos:oRma:Nummer))+" eingelagert",cText,,,,.T.)