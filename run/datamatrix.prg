PROC Datematrix_Display()
   LOCAL lAI,cAI,cData,nKey,nLen
   LOCAL hData := {=>}
   LOCAL nRow := MaxRow(),nCol := MaxCol()

   //SetMode(10,50)
   //HB_GTInfo( 1000, 5, 4 )
   Head("GS1 Datamatrix Display")
   DO WHILE .T.      
      
      @ 01,00 SAY "Barcode scannen"


      lAI := .T.
      cAI := ""
      cData := ""
      DO WHILE .T.
         nKey := Inkey(0)
         @ 03,00 CLEAR

         IF nKey == 27 
            SetMode(nRow+1,nCol+1)
            RETURN
         ELSEIF nKey < 1000
            IF lAI
               cAI += Chr(nKey)
            ELSE
               IF ! nKey $ {-7,13}                   
                  cData += Chr(nKey)
               ENDIF
               IF nKey == -7 .OR. nKey == 13 .OR. (nLen != NIL .AND. Len(cData) == nLen) //end of string
                  lAI := .T.
                  hData[cAI] := cData
                  cAI := ""
                  cData := ""
               ENDIF
            ENDIF
            IF nKey == 13
               EXIT
            ENDIF

            IF cAI == "241"
               lAI := .F.
               nLen := NIL
            ELSEIF cAI == "10"
               lAI := .F.
               nLen := NIL
            ELSEIF cAI == "11"
               lAI := .F.
               nLen := 6
            ENDIF               

         ENDIF
      ENDDO

      
      @ 03,00 SAY "Los:"
      IF HHasKey(hData,"10")
         @ 03,09 SAY hData["10"]
      
         SayAsciiArt(10,10,hData["10"])
      ENDIF
      @ 04,00 SAY "Datum:"
      IF HHasKey(hData,"11")
         @ 04,09 SAY DtoC(StoD("20"+hData["11"]))
      ENDIF
      @ 05,00 SAY "Artikel:"
      IF HHasKey(hData,"241")
         @ 05,09 SAY hData["241"]
      ENDIF
      
      //? ValToPrg(hData)
   ENDDO

RETURN

PROC SayAsciiArt(nR,nC,cText)
   LOCAL cAlphabet
   LOCAL cChar,nPos,nX,nY
   LOCAL nFont,aFont := {},cLine
   LOCAL nWidth := 0,nCharWidth
   
   LOCAL cFont := "colossal"
   LOCAL nFontHeight := 11
   LOCAL nFontSpace  := 2
   
   

   cAlphabet := MemoRead(Path("run\"+cFont+"FontAlphabet.txt"))
   nFont := Fopen(Path("run\"+cFont+"FontSymbols.txt"),0)
   
   DO WHILE HB_FReadLine(nFont , @cLine) == 0
      Aadd(aFont,cLine)
   ENDDO
   FClose(nFont)
   IF Len(aFont) == 0
      ? "Error reading font file"
      RETURN
   ENDIF
   
   FOR nX := 1 TO Len(cText)
      
      cChar := SubStr(cText,nX,1)      
      nPos := AT(cChar,cAlphabet)
      IF nPos > 0
         IF nWidth > 0
            nWidth += nFontSpace
         ENDIF
         nCharWidth := 0
         FOR nY := 1 TO nFontHeight
            IF (nPos-1)*nFontHeight+nY < Len(aFont)
               @ nR+nY-1,nC+nWidth SAY aFont[(nPos-1)*nFontHeight+nY]
               nCharWidth := Max(nCharWidth,Len(Trim(aFont[(nPos-1)*nFontHeight+nY])))
            ENDIF
         NEXT
         nWidth += nCharWidth
      ENDIF
   NEXT
   
RETURN

   /*00 Identifikation einer Transporteinheit (SSCC):

   "01"=>{"name"=>"Identifikation einer Handelseinheit (GTIN)","FNC1"=>.F.},;
   "02"=>{"name"=>"Identifikation von gleichen Handelseinheiten enthalten in einer TransporteinheitN2+N14 CONTENT
   "10"=>{"name"=>"Chargen- oder Losnummer: AI (10) N2+X..20 (FNC1) BATCH/LOT
11 (2) Produktionsdatum: AI (11) N2+N6 PROD DATE
12 (2) FÑlligkeitsdatum: AI (12) N2+N6 DUE DATE
13 (2) Packdatum: AI (13) N2+N6 PACK DATE
15 (2) Mindesthaltbarkeitsdatum: AI (15) N2+N6 BEST BEFORE
16 (2) ?Zu verkaufen bis?-Datum: AI (16) N2+N6 SELL BY
17 (2) Verfallsdatum: AI (17) N2+N6 USE BY oder
EXPIRY
20 Interne Produktvariante: AI (20) N2+N2 VARIANT
21 Seriennummer: AI (21) N2+X..20 (FNC1) SERIAL
22 Verbraucherproduktvariante: AI (22) N2+X..20 (FNC1) CPV
235 Durch Dritte kontrollierte Seriennummer zu
einer Global Trade Item Number (GTIN)
(TPX): AI (235)
N3+X..28 (FNC1) TPX
240 ZusÑtzliche Produktidentifikation des
Herstellers: AI (240)
N3+X..30 (FNC1) ADDITIONAL ID
241 Kundenteilenummer: AI (241) N3+X..30 (FNC1) CUST.PART. No.
242 Auftragsspezifische Variationsnummer: AI
(242)
N3+N?6 (FNC1) MTO VARIANT
243 Verpackungskomponentennummer: AI (243) N3+X..20 (FNC1) PCN
250 SekundÑre Seriennummer: AI (250) N3+X..30 (FNC1) SECONDARY
SERIAL
251 Bezug auf die Ursprungseinheit: AI (251) N3+X..30 (FNC1) REF.TO SOURCE
253 Global Document Type Identifier (GDTI): AI
(253)
N3+N13[+X..17] (FNC1) GDTI
254 Global Location Number (GLN)
Erweiterungskomponente: AI (254)
N3+X..20 (FNC1) GLN EXTENSION
COMPONENT
255 Global Coupon Number (GCN): AI (255) N3+N13[+N..12] (FNC1) GCN
30 Variable Menge in StÅck: AI (30) N2+N..8 (FNC1) VAR.COUNT
310n (3) Nettogewicht, Kilogramm (Mengenvariable
Einheiten)
N4+N6 NET WEIGHT
(kg)
311n (3) LÑnge oder 1. Dimension, Meter
Handelsinformation (Mengenvariable
Einheiten)
N4+N6 LENGTH (m)
312n (3) Breite, Durchmesser oder 2. Dimension,
Meter Handelsinformation (Mengenvariable
Einheiten)
N4+N6 WIDTH (m)
Allgemeine GS1 Spezifikationen
Version 23, Januar 2023 ? 2023 GS1 Austria | GS1 Germany | GS1 Switzerland Seite 157 of 594
AI Dateninhalt Format (1) FNC1
erforderlich (4) Kurztitel
313n (3) Dicke, Tiefe, Hîhe oder 3. Dimension, Meter
Handelsinformation (Mengenvariable
Einheiten)
N4+N6 HEIGHT (m)
314n (3) FlÑche, Handelsinformation, Quadratmeter
(Mengenvariable Einheiten)
N4+N6 AREA (m˝)
315n (3) Nettovolumen, Liter (Mengenvariable
Einheiten)
N4+N6 NET VOLUME (l)
316n (3) Nettovolumen, Kubikmeter (Mengenvariable
Einheiten)
N4+N6 NET VOLUME
(m?)
320n (3) Nettogewicht, Pfund (Mengenvariable
Einheiten)
N4+N6 NET WEIGHT (lb)
321n (3) LÑnge oder 1. Dimension, Inch,
Handelsinformation (Mengenvariable
Einheiten)
N4+N6 LENGTH (i)
322n (3) LÑnge oder 1. Dimension, Feet,
Handelsinformation (Mengenvariable
Einheiten)
N4+N6 LENGTH (f)
323n (3) LÑnge oder 1. Dimension, Yard,
Handelsinformation (Mengenvariable
Einheiten)
N4+N6 LENGTH (y)
324n (3) Breite, Durchmesser oder 2. Dimension, Inch,
Handelsinformation (Mengenvariable
Einheiten)
N4+N6 WIDTH (i)
325n (3) Breite, Durchmesser oder 2. Dimension, Feet,
Handelsinformation (Mengenvariable
Einheiten)
N4+N6 WIDTH (f)
326n (3) Breite, Durchmesser oder 2. Dimension,
Yard, Handelsinformation (Mengenvariable
Einheiten)
N4+N6 WIDTH (y)
327n (3) Tiefe, Dicke, Hîhe oder 3. Dimension, Inch,
Handelsinformation (Mengenvariable
Einheiten)
N4+N6 HEIGHT (i)
328n (3) Tiefe, Dicke, Hîhe oder 3. Dimension, Feet,
Handelsinformation (Mengenvariable
Einheiten)
N4+N6 HEIGHT (f)
329n (3) Tiefe, Dicke, Hîhe oder 3. Dimension, Yard,
Handelsinformation (Mengenvariable
Einheiten)
N4+N6 HEIGHT (y)
330n (3) Bruttogewicht, Kilogramm N4+N6 GROSS WEIGHT
(kg)
331n (3) LÑnge oder 1. Dimension, Meter,
Logistikinformation
N4+N6 LENGTH (m), log
332n (3) Breite, Durchmesser oder 2. Dimension,
Meter, Logistikinformation
N4+N6 WIDTH (m), log
333n (3) Dicke, Tiefe, Hîhe oder 3. Dimension, Meter,
Logistikinformation
N4+N6 HEIGHT (m), log
334n (3) FlÑche, Logistikinformation, Quadratmeter N4+N6 AREA (m˝), log
335n (3) Bruttovolumen, Liter N4+N6 VOLUME (l), log
336n (3) Bruttovolumen, Kubikmeter N4+N6 VOLUME (m?),
log
337n (3) Kilogramm pro Quadratmeter N4+N6 KG PER m˝
340n (3) Bruttogewicht, Pfund N4+N6 GROSS WEIGHT
(lb)
341n (3) LÑnge oder 1. Dimension, Inch,
Logistikinformation
N4+N6 LENGTH (i), log
342n (3) LÑnge oder 1. Dimension, Feet,
Logistikinformation
N4+N6 LENGTH (f), log
343n (3) LÑnge oder 1. Dimension, Yard,
Logistikinformation
N4+N6 LENGTH (y), log
344n (3) Breite, Durchmesser oder 2. Dimension, Inch,
Logistikinformation
N4+N6 WIDTH (i), log
345n (3) Breite, Durchmesser oder 2. Dimension, Feet,
Logistikinformation
N4+N6 WIDTH (f), log
346n (3) Breite, Durchmesser oder 2. Dimension,
Yard, Logistikinformation
N4+N6 WIDTH (y), log
347n (3) Dicke, Tiefe, Hîhe oder 3. Dimension, Inch,
Logistikinformation
N4+N6 HEIGHT (i), log
348n (3) Dicke, Tiefe, Hîhe oder 3. Dimension, Feet,
Logistikinformation
N4+N6 HEIGHT (f), log
349n (3) Dicke, Tiefe, Hîhe oder 3. Dimension, Yard,
Logistikinformation
N4+N6 HEIGHT (y), log
350n (3) FlÑche, Square Inches (Mengenvariable
Handelseinheiten)
N4+N6 AREA (i˝)
351n (3) FlÑche, Square Feet (Mengenvariable
Handelseinheiten)
N4+N6 AREA (f˝)
352n (3) FlÑche, Square Yards (Mengenvariable
Handelseinheiten)
N4+N6 AREA (y˝)
353n (3) FlÑche, Square Inches N4+N6 AREA (i˝), log
354n (3) FlÑche, Square Feet N4+N6 AREA (f˝), log
355n (3) FlÑche, Square Yards N4+N6 AREA (y˝), log
356n (3) Nettogewicht, Troy Ounces (Mengenvariable
Handelseinheiten)
N4+N6 NET WEIGHT (t)
357n (3) Nettogewicht (oder Volumen), Ounces
(Mengenvariable Handelseinheiten)
N4+N6 NET VOLUME
(oz)
360n (3) Nettovolumen, Quarts (Mengenvariable
Handelseinheiten)
N4+N6 NET VOLUME (q)
361n (3) Nettovolumen, Gallons U.S. (Mengenvariable
Handelseinheiten)
N4+N6 NET VOLUME (g)
362n (3) Bruttovolumen, Quarts N4+N6 VOLUME (q), log
363n (3) Bruttovolumen, Gallons U.S. N4+N6 VOLUME (q), log
364n (3) Bruttovolumen, Cubic Inches
(Mengenvariable Handelseinheiten)
N4+N6 VOLUME (i?), log
365n (3) Nettovolumen, Cubic Feet (Mengenvariable
Handelseinheiten)
N4+N6 VOLUME (f?), log
366n (3) Nettovolumen, Cubic Yards (Mengenvariable
Handelseinheiten)
N4+N6 VOLUME (y?),
log
367n (3) Bruttovolumen, Cubic Inches N4+N6 VOLUME (q), log
368n (3) Bruttovolumen, Cubic Feet N4+N6 VOLUME (g), log
369n (3) Bruttovolumen, Cubic Yards N4+N6 VOLUME (i?), log
Allgemeine GS1 Spezifikationen
Version 23, Januar 2023 ? 2023 GS1 Austria | GS1 Germany | GS1 Switzerland Seite 159 of 594
AI Dateninhalt Format (1) FNC1
erforderlich (4) Kurztitel
37 Anzahl in der Transporteinheit enthaltenen
Handelseinheiten oder Teile einer
Handelseinheit: AI (37)
N2+N..8 (FNC1) COUNT
390n (3) FÑlliger Betrag oder Couponwert ? gegebener
WÑhrungsbereich: AI (390n)
N4+N..15 (FNC1) AMOUNT
391n (3) FÑlliger Betrag mit ISO WÑhrungscode: AI
(391n)
N4+N3+N..15 (FNC1) AMOUNT
392n (3) Zu zahlender Betrag ? gegebener
WÑhrungsbereich: AI (392n)
N4+N..15 (FNC1) PRICE
393n (3) Zu zahlender Betrag mit ISO WÑhrungscode:
AI (393n)
N4+N3+N..15 (FNC1) PRICE
394n (3) Prozentrabatt eines Coupons: AI (394n) N4+N4 (FNC1) PRCNT OFF
395n (3) Zu zahlender Betrag pro Ma·einheit ?
gegebener WÑhrungsbereich
(mengenvariable Einheiten): AI (395n)
N4+N6 (FNC1) PRICE/UoM
400 Bestell-/Auftragsnummer des Kunden: AI
(400)
N3+X..30 (FNC1) ORDER NUMBER
401 Global Identification Number for Consignment
(GINC): AI (401)
N3+X..30 (FNC1) GINC
402 Global Shipment Identification Number
(GSIN): AI (402)
N3+N17 (FNC1) GSIN
403 Leitcode, Routing Code: AI (403) N3+X..30 (FNC1) ROUTE
410 Global Location Number des
WarenempfÑngers (GLN): AI (410)
N3+N13 SHIP TO LOC
411 Global Location Number des
RechnungsempfÑngers (GLN): AI (411)
N3+N13 BILL TO
412 Global Location Number des Lieferanten
(GLN): AI (412)
N3+N13 PURCHASE
FROM
413 Global Location Number des EndempfÑngers
(bei gebrochenem Transport) (GLN): AI (413)
N3+N13 SHIP FOR LOC
414 Identifikation eines Standortes, GS1 Global
Location Number (GLN): AI (414)
N3+N13 LOC No.
415 Global Location Number (GLN) des
fakturierenden Teilnehmers: AI (415)
N3+N13 PAY TO
416 Global Location Number (GLN) des
Produktions- oder Servicestandortes: AI
(416)
N3+N13 PROD/SERV LOC
417 Global Location Number (GLN) eines
Unternehmens: AI (417)
N3+N13 PARTY
420 Postleitzahl des EmpfÑngers (ohne
LÑndercode): AI (420)
N3+X..20 (FNC1) SHIP TO POST
421 Postleitzahl des EmpfÑngers (mit
vorangestelltem 3-stelligem ISOLÑndercode): AI (421)
N3+N3+X..12 (FNC1) SHIP TO POST
422 Ursprungsland der Ware: AI (422) N3+N3 (FNC1) COUNTRY ?
INITIAL
PROCESS
423 LÑnder der ersten Verarbeitungsstufe: AI
(423)
N3+N3+N..12 (FNC1) COUNTRY ?
PROCESS
424 Land der Verarbeitung: AI (424) N3+N3 (FNC1) COUNTRY ?
PROCESS
425 Land der Zerlegung: AI (425) N3+N3+N..12 (FNC1) COUNTRY ?
DISASSEMBLY
426 Land aller Verarbeitungsstufen: AI (426) N3+N3 (FNC1) COUNTRY ? FULL
PROCESS
427 Region des Ursprungslandes der
Handelseinheit: AI (427)
N3+X..3 (FNC1) COUNTRY
SUBDIVISION
4300 EmpfÑnger-Unternehmen: AI (4300) N4+X..35 (FNC1) SHIP TO COMP
4301 EmpfÑnger-Kontakt: AI (4301) N4+X..35 (FNC1) SHIP TO NAME
4302 EmpfÑnger-Adresszeile-1: AI (4302) N4+X..70 (FNC1) SHIP TO ADD1
4303 EmpfÑnger-Adresszeile-2: AI (4303) N4+X..70 (FNC1) SHIP TO ADD2
4304 EmpfÑnger-Ortsteil: AI (4304) N4+X..70 (FNC1) SHIP TO SUB
4305 EmpfÑnger-Ort: AI (4305) N4+X..70 (FNC1) SHIP TO LOC
4306 EmpfÑnger-Region: AI (4306) N4+X..70 (FNC1) SHIP TO REG
4307 EmpfÑnger-LÑndercode: AI (4307) N4+X2 (FNC1) SHIP TO
COUNTRY
4308 EmpfÑnger-Telefonnummer: AI (4308) N4+X..30 (FNC1) SHIP TO PHONE
4309 EmpfÑnger-GEO-Lokation: AI (4309) N4+N20 (FNC1) SHIP TO GEO
4310 Retoure-an-Unternehmen: AI (4310) N4+X..35 (FNC1) RTN TO COMP
4311 Retoure-an-Kontakt: AI (4311) N4+X..35 (FNC1) RTN TO NAME
4312 Retoure-an-Adresszeile-1: AI (4312) N4+X..70 (FNC1) RTN TO ADD1
4313 Retoure-an-Adresszeile-2: AI (4313) N4+X..70 (FNC1) RTN TO ADD2
4314 Retoure-an-Ortsteil: AI (4314) N4+X..70 (FNC1) RTN TO SUB
4315 Retoure-an-Ort: AI (4315) N4+X..70 (FNC1) RTN TO LOC
4316 Retoure-an-Region: AI (4316) N4+X..70 (FNC1) RTN TO REG
4317 Retoure-an-LÑndercode: AI (4317) N4+X2 (FNC1) RTN TO
COUNTRY
4318 Retoure-an-Postleitzahl: AI (4318) N4+X..20 (FNC1) RTN TO POST
4319 Retoure-an-Telefonnummer: AI (4319) N4+X..30 (FNC1) RTN TO PHONE
4320 ErlÑuterung des Liefercodes: AI (4320) N4+X..35 (FNC1) SRV
DESCRIPTION
4321 Kennzeichen fÅr Gefahrgut: AI (4321) N4+N1 (FNC1) DANGEROUS
GOODS
4322 Zustellung ohne persînliche Entgegennahme:
AI (4322)
N4+N1 (FNC1) AUTH LEAV
4323 Kennzeichen fÅr - Unterschrift erforderlich: AI
(4323)
N4+N1 (FNC1) SIG REQUIRED
4324 Keine Zustellung vor Datum/Zeit: AI (4324) N4+N10 (FNC1) NBEF DEL DT
4325 Keine Zustellung nach Datum/Zeit: AI (4325) N4+N10 (FNC1) NAFT DEL DT
4326 Freigabedatum fÅr Auslieferung: AI (4326) N4+N6 (FNC1) REL DATE
7001 NATO Stock Number (NSN): AI (7001) N4+N13 (FNC1) NSN
7002 UN/ECE Fleischkarkassen und
Schnittklassifizierung: AI (7002)
N4+X..30 (FNC1) MEAT CUT
7003 Verfallsdatum und ?zeit: AI (7003) N4+N10 (FNC1) EXPIRY TIME
7004 Aktive Potenz: AI (7004) N4+N..4 (FNC1) ACTIVE
POTENCY
7005 Fanggebiet: AI (7005) N4+X..12 (FNC1) CATCH AREA
7006 Erstes Einfrierdatum: AI (7006) N4+N6 (FNC1) FIRST FREEZE
DATE
7007 Erntedatum: AI (7007) N4+N6[+N6] (FNC1) HARVEST DATE
7008 Fischspezies: AI (7008) N4+X..3 (FNC1) AQUATIC
SPECIES
7009 FanggerÑtekategorie: AI (7009) N4+X..10 (FNC1) FISHING GEAR
TYPE
7010 Produktionsmethode: AI (7010) N4+X..2 (FNC1) PROD METHOD
7011 PrÅfdatum: AI (7011) N4+N6+[N4] (FNC1) TEST BY DATE
7020 Losnummer der Wiederaufbereitung: AI
(7020)
N4+X..20 (FNC1) REFURB LOT
7021 Funktionaler Status: AI (7021) N4+X..20 (FNC1) FUNC STAT
7022 Revisionstatus: AI (7022) N4+X..20 (FNC1) REV STAT
7023 Global Individual Asset Identifier einer
Baugruppe: AI (7023)
N4+X..30 (FNC1) GIAI ?
ASSEMBLY
703s (6) Nummer des Verarbeitungsbetriebes mit ISO
LÑndercode: AI (703s)
N4+N3+X..27 (FNC1) PROCESSOR # s
7040 GS1 UIC mit Erweiterung 1 und Kennziffer
des Importeurs: AI (7040)
N4+N1+X3 (FNC1) UIC+EXT
710 National Healthcare Reimbursement Number
? Deutschland PZN: AI (710)
N3+X..20 (FNC1) NHRN PZN
711 National Healthcare Reimbursement Number
? Frankreich CIP PZN: AI (711)
N3+X..20 (FNC1) NHRN CIP
712 National Healthcare Reimbursement Number
? Spanien CN: AI (712)
N3+X..20 (FNC1) NHRN CN
713 National Healthcare Reimbursement Number
? Brasilien DRN: AI (713)
N3+X..20 (FNC1) NHRN DRN
714 National Healthcare Reimbursement Number
? Portugal AIM: AI (714)
N3+X..20 (FNC1) NHRN AIM
715 National Healthcare Reimbursement Number
? USA NDC: AI (715)
N3+X..20 (FNC1) NHRN NDC
?
(5) National Healthcare Reimbursement Number
? Land ?A?
N3+X..20 (FNC1) NHRN XXX
723s (6) Zertifizierungsnummer: AI (723s) N4+X2+X..28 (FNC1) CERT # s
7240 Protokoll ID: AI (7240) N4+X..20 (FNC1) PROTOCOL
8001 Rollenprodukte ? Breite, LÑnge,
Durchmesser, Richtung, Splei·ungen: AI
(8001)
N4+N14 (FNC1) DIMENSIONS
8002 Cellular Mobile Telephone Identifier: AI
(8002)
N4+X..20 (FNC1) CMT No.
8003 Global Returnable Asset Identifier (GRAI): AI
(8003)
N4+N14[+X..16] (FNC1) GRAI
8004 Global Individual Asset Identifier (GIAI): AI
(8004)
N4+X..30 (FNC1) GIAI
8005 Preis pro Ma·einheit: AI (8005) N4+N6 (FNC1) PRICE PER UNIT
Allgemei
8006 Identifikation eines einzelnen Teils einer
Handelseinheit (ITIP): AI (8006)
N4+N14+N2+N2 (FNC1) ITIP
8007 Internationale Bankenverrechnungsnummer
(IBAN): AI (8007)
N4+X..34 (FNC1) IBAN
8008 Produktionsdatum und -zeit: AI (8008) N4+N8[+N..4] (FNC1) PROD TIME
8009 Indikator fÅr einen optisch interpretierbaren
Sensor: AI (8009)
N4+X..50 (FNC1) OPTSEN
8010 Component/Part Identifier (CPID): AI (8010) N4+Y..30 (FNC1) CPID
8011 Component/Part Identifier Serial Number: AI
(8011)
N4+N..12 (FNC1) CPID SERIAL
8012 Software Version: AI (8012) N4+X..20 (FNC1) VERSION
8013 Global Model Number (GMN): AI (8013) N4+X..30 (FNC1) GMN
8017 Global Service Relation Number (GSRN) zur
Identifizierung der Beziehung zwischen
Anbieter des Services und dem Erbringer: AI
(8017)
N4+N18 (FNC1) GSRN ?
PROVIDER
8018 Global Service Relation Number (GSRN) zur
Identifizierung der Beziehung zwischen
Anbieter des Services und dem EmpfÑnger:
AI (8018)
N4+N18 (FNC1) GSRN ?
RECIPIENT
8019 Service Relation Instance Number (SRIN): AI
(8019)
N4+N..10 (FNC1) SRIN
8020 Zahlscheinbezugsnummer: AI (8020) N4+X..25 (FNC1) REF No.
8026 Identifikation von Teilen einer Handelseinheit
(ITIP) enthalten in einer Transporteinheit: AI
(8026)
N4+N14+N2+N2 (FNC1) ITIP CONTENT
8110 Couponidentifikation in Nordamerika: AI
(8110)
N4+X..30 (FNC1) -
8111 Treuepunkte eines Coupons: AI (8111) N4+N4 (FNC1) POINTS
8112 ?Positive Offer File? Couponidentifikation in
Nordamerika (AI 8112)
N4+X..70 (FNC1) -
8200 Extended Packaging URL: AI (8200) N4+X..70 (FNC1) PRODUCT URL
90 Information fÅr bilateral abgestimmte
Anwendung: AI (90)
N2+X..30 (FNC1) INTERNAL
91 - 99 Unternehmensinterne Anwendung: AIs (91 -
99)
N2+X..90 (FNC1) INTERNA*/
