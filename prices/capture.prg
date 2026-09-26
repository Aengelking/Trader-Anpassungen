// Konkurrenzpreise im Browser erfassen ("Trader-Knopf")
//
// Oeffnet die Produktseiten der Konkurrenten im Standardbrowser, jeweils mit
// "#ek=<Artikelnr>&mpn=<Herstellernummer>". Die Browser-Erweiterung "Engelking
// Konkurrenzpreise" (Repo engelking-website, browser-extension/) erkennt dort die
// Staffelpreise und speichert sie nach Bestaetigung (oder mit "automatisch senden")
// in der Website-Datenbank. Danach holt Trader sie ab (prices\updcompet) und die
// Preistabelle wird beim naechsten Aufruf neu berechnet.
//
// Aufruf, z.B. aus der Artikelmaske:
//    MBaseRun(Trim(Tr_getini(1))+"\run\prices\capture")            aktueller Artikel (art)
//    MBaseRun(Trim(Tr_getini(1))+"\run\prices\capture",{nArtnr})   bestimmter Artikel
//
// Direkt auf die Produktseite geht es, wenn in artlief die Bestellnummer des Shops steht,
// sonst auf die Suche nach der Herstellernummer. Landet die Erweiterung (ab 0.3.0) auf einer
// Suchergebnisseite, springt sie selbst zum passenden Produkt; dafuer bekommt sie die
// Bestellnummer als "&nr=" mit.

FUNCTION RUN_PRICES_CAPTURE( nArtnr )
LOCAL aShops := _CaptureShops()
LOCAL aOpen := {}, aWith := {}
LOCAL cMpn, cArtlief, cUrl, cMsg, cHash
LOCAL nX, nChoice, nOrd, nRecno
LOCAL aWeb, nNew

IF Select("art") == 0
   NetUse("artikel","art")
ENDIF
NetUse("artlief","ali")

IF ValType(nArtnr) == "N" .AND. nArtnr > 0
   nRecno := art->(Recno())
   nOrd := art->(dbSetOrder( 2 ))
   IF ! art->(dbSeek( Str(nArtnr,6) ))
      art->(dbSetOrder( nOrd ))
      art->(dbGoto( nRecno ))
      Alert("Artikel "+LTrim(Str(nArtnr))+" nicht gefunden")
      RETURN .F.
   ENDIF
   art->(dbSetOrder( nOrd ))
ENDIF
IF art->(EOF()) .OR. art->Artikelnr == 0
   Alert("Kein Artikel ausgewaehlt")
   RETURN .F.
ENDIF
nArtnr := art->Artikelnr
cMpn := StrTran(Trim(art->Matchcode),"#MT","")

FOR nX := 1 TO Len(aShops)
   ali->(dbSeek( Pad(aShops[nX][1],8)+Str(nArtnr,6) ))
   cArtlief := IF(ali->(Found()), StrTran(Trim(ali->Artlief)," ",""), "")
   IF ! Empty(cArtlief)
      cUrl := StrTran(aShops[nX][3],"%artlief%",_CaptureUrlEncode(cArtlief))
      Aadd(aWith, {aShops[nX][2], cUrl, cArtlief})
   ELSE
      cUrl := StrTran(aShops[nX][4],"%mpn%",_CaptureUrlEncode(cMpn))
   ENDIF
   Aadd(aOpen, {aShops[nX][2], cUrl, cArtlief})
NEXT

cMsg := "Konkurrenzpreise fuer "+cMpn+" im Browser erfassen.;;"
IF Len(aWith) > 0
   cMsg += "Mit Bestellnummer: "+_CaptureNames(aWith)+";"
   cMsg += "Ohne (Suche): "+_CaptureNames(aOpen,aWith)
   nChoice := Tr_msgbox(cMsg,,{"Nur mit Bestellnr.","Alle Shops","Abbrechen"})
ELSE
   cMsg += "Keine Bestellnummern hinterlegt - es wird nach der Herstellernummer gesucht."
   nChoice := Tr_msgbox(cMsg,,{"Alle Shops","Abbrechen"})
   nChoice := IF(nChoice == 1, 2, 3)
ENDIF
IF nChoice == 1
   aOpen := aWith
ELSEIF nChoice != 2
   RETURN .F.
ENDIF

//Kennung fuer die Erweiterung: Sie oeffnet dann das Panel von selbst und traegt die Artikelnummer ein
cHash := "#ek="+LTrim(Str(nArtnr))+"&mpn="+_CaptureUrlEncode(cMpn)
FOR nX := 1 TO Len(aOpen)
   WAPI_ShellExecute(,"open",aOpen[nX][2]+cHash+IF(Empty(aOpen[nX][3]),"","&nr="+_CaptureUrlEncode(aOpen[nX][3])))
   Inkey(0.4)  //Tabs in Reihenfolge oeffnen lassen
NEXT

IF Tr_msgbox("Die Seiten sind im Browser geoeffnet.;Dort die Preise pruefen und uebernehmen.;;Danach 'Fertig' waehlen - Trader holt die Preise ab.",,{"Fertig","Abbrechen"}) != 1
   RETURN .F.
ENDIF

TxtBox("Preise werden abgeholt...")
aWeb := WebCompetPriceLists(nArtnr, cMpn, 90)
TxtClear()
IF aWeb == NIL
   Alert("Website nicht erreichbar - Preise konnten nicht abgeholt werden")
   RETURN .F.
ENDIF

nNew := 0
cMsg := ""
FOR nX := 1 TO Len(aWeb)
   IF aWeb[nX][3] >= Date()
      nNew++
   ENDIF
   cMsg += ";"+Pad(aWeb[nX][1],10)+DtoC(aWeb[nX][3])+"  ab "+LTrim(Str(HGetKeyAt(aWeb[nX][2],1)))+" St.: "+LTrim(Transform(HGetValueAt(aWeb[nX][2],1),"@E 99999.99999"))+" EUR"
NEXT
IF Len(aWeb) == 0
   Alert("Keine erfassten Preise fuer "+cMpn+" gefunden")
   RETURN .F.
ENDIF

//Preistabelle neu berechnen lassen: Cache verwerfen, Konkurrenzpreise neu zusammenstellen
NetUse("ptcache","ptc")
IF ptc->(dbSeek( Str(nArtnr,6) ))
   ptc->(Rec_Lock(0))
   ptc->LastDate := StoD("")
   ptc->(dbUnLock())
ENDIF
MBaseRun(Trim(Tr_getini(1))+"\run\prices\updcompet",{.T.,.F.})

Alert("Erfasste Preise "+cMpn+" (heute neu: "+LTrim(Str(nNew))+"):"+cMsg)
RETURN .T.

// {Trader-Kuerzel, Anzeigename, URL mit Bestellnummer, URL mit Herstellernummer (Suche)}
// Die Seiten muessen zu den Shops der Browser-Erweiterung passen (manifest.json).
STATIC FUNCTION _CaptureShops()
RETURN {;
   {"RS",       "RS",       "https://de.rs-online.com/web/c/?searchTerm=%artlief%", "https://de.rs-online.com/web/c/?searchTerm=%mpn%"},;
   {"BUERKLIN", "Buerklin", "https://www.buerklin.com/de/suche/?search=%artlief%",  "https://www.buerklin.com/de/suche/?search=%mpn%"},;
   {"FARNELL",  "Farnell",  "https://de.farnell.com/x/x/x/dp/%artlief%",            "https://de.farnell.com/search?st=%mpn%"},;
   {"MOUSER",   "Mouser",   "https://www.mouser.de/ProductDetail/%artlief%",        "https://www.mouser.de/c/?q=%mpn%"},;
   {"TME",      "TME",      "https://www.tme.eu/de/details/%artlief%/",             "https://www.tme.eu/de/katalog/?search=%mpn%"},;
   {"DIGIKEY",  "DigiKey",  "https://www.digikey.de/de/products/result?keywords=%artlief%", "https://www.digikey.de/de/products/result?keywords=%mpn%"},;
   {"CONRAD",   "Conrad",   "https://www.conrad.de/de/search.html?search=%artlief%", "https://www.conrad.de/de/search.html?search=%mpn%"},;
   {"REICHELT", "Reichelt", "https://www.reichelt.de/de/de/shop/suche/%artlief%",   "https://www.reichelt.de/de/de/shop/suche/%mpn%"};
}

// Namen der Shops in aList, die nicht in aSkip stehen
STATIC FUNCTION _CaptureNames(aList, aSkip)
   LOCAL cNames := "", nX
   FOR nX := 1 TO Len(aList)
      IF aSkip == NIL .OR. AScan(aSkip,{|a| a[1] == aList[nX][1]}) == 0
         cNames += IF(Empty(cNames),"",", ")+aList[nX][1]
      ENDIF
   NEXT
RETURN IF(Empty(cNames),"-",cNames)

STATIC FUNCTION _CaptureUrlEncode(cString)
   LOCAL cResult := "", nX, cChar, nCode
   LOCAL cHex := "0123456789ABCDEF"
   cString := hb_StrToUTF8(cString)
   FOR nX := 1 TO Len(cString)
      cChar := SubStr(cString,nX,1)
      nCode := Asc(cChar)
      IF (nCode >= 48 .AND. nCode <= 57) .OR. (nCode >= 65 .AND. nCode <= 90) .OR. ;
         (nCode >= 97 .AND. nCode <= 122) .OR. cChar $ "-_.~"
         cResult += cChar
      ELSE
         cResult += "%" + SubStr(cHex,Int(nCode/16)+1,1) + SubStr(cHex,(nCode % 16)+1,1)
      ENDIF
   NEXT
RETURN cResult

#include 'x:\run\prices\websiteoffers.prg'
