#include 'y:\hb32\include\inkey.ch'

PROC RUN_IMPORT_SPECCL
   LOCAL hSpecial := {=>}
   LOCAL cKunde, hLimit, nImported := 0, nSkipped := 0, nErrors := 0
   LOCAL oRec, nKuNr
   
   IF ! SystemUser():CheckPermission("U","ADR_CUSTOMER_SPECCREDITLIMIT")
      Return
   Endif

   IF Tr_MsgBox({"Import existing special credit limits into SPECCL database?","This will create new records for all special limits found in get_customercreditlimit.prg"},,{"Cancel","Import"}) != 2
      RETURN
   ENDIF

   // Initialize the special limits hash from get_customercreditlimit.prg
   _InitSpecialLimits(@hSpecial)
   
   NetUse("speccl","spcl",.F.,0)
   NetUse("engkund","ku",.F.,0)
   
   ku->(dbSetOrder(1)) // by customer code
   
   CLS
   @ 5,5 SAY "Importing Special Credit Limits..."
   @ 7,5 SAY "Progress:"
   
   FOR EACH hLimit IN hSpecial
      cKunde := hLimit:__eNumKey
      @ 9,5 SAY "Processing: " + PadR(cKunde, 15) + " (" + AllTrim(Str(hLimit:__EnumIndex)) + "/" + AllTrim(Str(Len(hSpecial))) + ")"
      
      //hLimit := hSpecial[cKunde]
      
      // Find customer number
      IF ku->(dbSeek(Pad(cKunde,8) + "K"))
         nKuNr := ku->Nummer
         
         // Check if record already exists
         IF ! spcl->(dbSeek(Str(nKuNr,6)))
            // Create new record
            oRec := spcl->(Record():New(.T.))
            oRec:KuNr := nKuNr
            oRec:Kunde := cKunde
            oRec:SpecLimit := hLimit["LIMIT"]
            oRec:ValidFrom := Date()
            oRec:ValidUntil := hLimit["DATE"]
            oRec:Active := .T.
            
            // Add import comment with historical information
            oRec:Comments := DToC(Date()) + " " + Time() + " [" + SystemUser():Name + "] " + ;
                           "IMPORTED: Limit=" + Transform(hLimit["LIMIT"],"999,999.99") + ;
                           " Valid until=" + DToC(hLimit["DATE"]) + ;
                           " - Imported from get_customercreditlimit.prg" + Chr(13) + Chr(10)
            
            // Add historical comments if available
            IF HHasKey(hLimit, "COMMENT") .AND. ! Empty(hLimit["COMMENT"])
               oRec:Comments += Chr(13) + Chr(10) + "HISTORICAL INFORMATION:" + Chr(13) + Chr(10)
               oRec:Comments += _FormatHistoricalComments(hLimit["COMMENT"]) + Chr(13) + Chr(10)
            ENDIF
            
            oRec:Save()
               nImported++
               @ 11,5 SAY "Imported: " + AllTrim(Str(nImported))
            /*ELSE
               nErrors++
               @ 13,5 SAY "Errors: " + AllTrim(Str(nErrors))
            ENDIF*/
         ELSE
            nSkipped++
            @ 12,5 SAY "Skipped (exists): " + AllTrim(Str(nSkipped))
         ENDIF
      ELSE
         nErrors++
         @ 13,5 SAY "Errors (customer not found): " + AllTrim(Str(nErrors))
         @ 14,5 SAY "Last error: Customer " + cKunde + " not found"
      ENDIF
   NEXT
   
   @ 16,5 SAY "Import completed!"
   @ 17,5 SAY "Records imported: " + AllTrim(Str(nImported))
   @ 18,5 SAY "Records skipped:  " + AllTrim(Str(nSkipped))
   @ 19,5 SAY "Errors:          " + AllTrim(Str(nErrors))
   @ 21,5 SAY "Press any key to continue..."
   
   Inkey(0)

RETURN

STATIC FUNCTION _InitSpecialLimits(hSpecial)
   // Initialize all special limits from get_customercreditlimit.prg
   // This contains the current active special limits as of October 2025
   
   hSpecial["IRTSYSTE"] := {"DATE"=>StoD("20251230"), "LIMIT"=>2100, "COMMENT"=>"26.06.25 Steht auf Automahnung, altes Limit 1780 //12.04.21 War gar kein Rahmen, daher Limit angehoben //21.01.21 Rating liegt inzwischen bei 4,3, zahlt nach 1 Mahnung, seit 17 aber nicht n”tig, daher Auftragslimit fr Rahmen und geringer Betrag fr Rechnungen //29.03.17 seitdem keine Rechnung, Rahmen ausgelaufen und wir haben nicht alles da //18.07.16 Rating 3.6, zahlt aber bisher pnktlich"}
   
   hSpecial["FETTEMET"] := {"DATE"=>StoD("20251230"), "LIMIT"=>1150, "COMMENT"=>"30.01.25 Verl„ngerung, letzte Rechnungen pktl. bezahlt //16.08.24 Erneute erh”hung - stehen bereits auf Automahn //30.11.21 Erh”hung von 750"}
   
   hSpecial["IMMEL"] := {"DATE"=>StoD("20250828"), "LIMIT"=>4700, "COMMENT"=>"14.03.25 erneut eingetragen und von 3000? erh”ht //04.02.22 Eine Lieferung bereits per Vorkasse, nur 14 Tage und mit Automahnung"}
   
   hSpecial["GEHO"] := {"DATE"=>StoD("20251008"), "LIMIT"=>1500, "COMMENT"=>"08.09.25 Verl„ngert und von 950 angehoben //06.06.25 ZV gerade ok. erh”ht auf 950 //18.03.25 verl„ngert Zahlungsverhalten schwankend //28.11.23 Hat letzte Rechnung pnktlich bezahlt //19.09.23 Zahlt erst nach 2. Mahnung - Tina droht die Umstellung auf Vorkasse an //04.05.22 Zahlt weiterhin erst nach Mahnung. Verl„ngert //07.04.22 Wg. Urlaub verl„ngert //28.03.22 Rating 3.1, zahlt nach 1 od. 2 Mahnung. Steht bereits auf Automahn."}
   
   hSpecial["IHTB"] := {"DATE"=>SToD("20250830"),"LIMIT"=>6200, "COMMENT"=>"11.03.25 Zahlt immer mit 30 T, war aber auf 14T eingestellt. ZB umgestellt in der Hoffnung, dass er sich daran h„lt //07.02.23 Verl„ngert //27.09.22 Hat letztes Rechnung sofort nach 1. Mahnung bezahlt. Wurde bereits auf Automahn umgestellt. von 1999 erh”ht //29.08.22 Sonderlimit war seit 2020 nicht mehr notwendig, zahlt meistens pnktlich auf automahnung gesetzt //25.06.20 verl„ngert, hatte bersehen de Rechnung zu bezahlen (anscheinend aufgrund von Corona) //20.02.20 Einzelfirma daher keine Auskunft"}
   
   hSpecial["ROMBERG"] := {"DATE"=>SToD("20250830"),"LIMIT"=>140, "COMMENT"=>"08.04.25 Rating weiter verschlechtert auf 4.6 Zahlt nach erster Mahnung //05.09.22 Rating verschlechtert von 4.1 auf 4.2 zahlte bisher aber mit Skonto/Pktl."}
   
   hSpecial["WANTEC"] := {"DATE"=>SToD("20251231"),"LIMIT"=>6000, "COMMENT"=>"26.06.25 Limit von 760 erh”ht //14.01.24 Hat 2023 kein Limit gebraucht, wieder eingesetzt //20.12.22 Hat l„nger nichts abgerufen. Limit wieder auf 760 gesetzt //12.10.20 Limit von 760 auf 1999 erh”ht //15.05.20 brauch jetzt auch zur Auslieferung eine h”heres Limit. //13.05.20 Neuer Rahmen, daher verl„ngert aber auf 3000 reduziert //16.04.19 brauchen das Limit fr einen Rahmen, der ist sehr schlampig beim bezahlen der Rechnungen"}
   
   hSpecial["ADAC"] := {"DATE"=>SToD("20281231"),"LIMIT"=>800, "COMMENT"=>"Long term special arrangement"}
   
   hSpecial["WALDOM"] := {"DATE"=>SToD("20251231"),"LIMIT"=>7000, "COMMENT"=>"18.03.24 tempor„r fr Stock return"}
   
   hSpecial["ENGELKIA"] := {"DATE"=>StoD("20991230"), "LIMIT"=>20000, "COMMENT"=>"Konzernintern"}
   
   hSpecial["HANSEYAC"] := {"DATE"=>StoD("20250830"), "LIMIT"=>2500, "COMMENT"=>"30.06.25 Auf Automahn //05.03.25 Ware auf Lager (Rahmen) kunde zahlt aber verz”gert. K”nnen niemanden erreichen //16.04.19 Nach Rcksprache mit Sigi das KL auf 13000? angehoben, der Kunde zahlt immer wenn sie Herrn Elmenhorst kontaktier //08.11.18 Auftragslimit auf 25k erh”ht //27.07.18 Zahlt erst nach merhfacher Mahnung. Factoring keine L”sung, da fas Limit haupts„chlich fr Auftr„ge und nicht fr die Rechnungen selbst ben”tigt wird"}
   
   hSpecial["SANMINUS"] := {"DATE"=>StoD("20250830"), "LIMIT"=>60000, "COMMENT"=>"02.07.25 Automahn hilft nicht - Sabid geht nochmals auf die zu //23.03.25 Hat letzte Rechnung sehr sp„t bezahlt (26T / 2 Mahnung). Auf Automahn gestellt, ist der Fertiger fr Kaco"}
   
   hSpecial["KMCELEC"] := {"DATE"=>StoD("20250830"), "LIMIT"=>2000, "COMMENT"=>"12.04.25 Schlechtes Rating (3.0)"}
   
   hSpecial["CARSTECH"] := {"DATE"=>SToD("20250930"),"LIMIT"=>10000, "COMMENT"=>"15.04.25 Eine Rechnung wurde sehr sp„t bezahlt, ging an die falsche Adresse und wurde dann lange nicht durch uns bearbeitet."}
   
   hSpecial["STOLZE"] := {"DATE"=>SToD("20250830"),"LIMIT"=>1650, "COMMENT"=>"10.05.25 schlechtes Rating"}
   
   hSpecial["CHIPGERM"] := {"DATE"=>SToD("20250830"),"LIMIT"=>1190, "COMMENT"=>"12.05.25 Probleme mit dem Buchhaltungskontakt"}
   
   hSpecial["VITRONIW"] := {"DATE"=>StoD("20250831"), "LIMIT"=>400, "COMMENT"=>"06.06.25 Direkt nach erster Mahnung bezahlt. Steht auf Automahn //12.06.19 Zahlt immer nach der 1. Mahnung, diese sollten wir schneller versenden"}
   
   hSpecial["NANOTEC"] := {"DATE"=>StoD("20250831"), "LIMIT"=>450, "COMMENT"=>"11.06.25 Keine Bewertung bei CS (ungengend Informationen)"}
   
   hSpecial["ROTTMANN"] := {"DATE"=>StoD("20250930"), "LIMIT"=>2700, "COMMENT"=>"29.07.25 Wurde letztes Jahr von einer Einzelfirma in eine GmbH umgewandelt - daher kein Rating bei CS//17.01.17 zahlte in der Vergangenheit immer pnktlich und durch eine Preiserh”hung kommt er jetzt ber 300?"}
   
   hSpecial["CLEVERCI"] := {"DATE"=>StoD("20250930"), "LIMIT"=>32000, "COMMENT"=>"12.08.25 Letzte Rechnung erst nach dritter Mahnung bezahlt"}
   
   hSpecial["FFG"] := {"DATE"=>StoD("20251030"), "LIMIT"=>2600, "COMMENT"=>"16.09.25 Von 850 erh”ht //27.08.25 Automahn aktiviert"}
   
   hSpecial["MOLITOR"] := {"DATE"=>SToD("20251230"),"LIMIT"=>650, "COMMENT"=>"15.09.25 Kunde ist nun GmbH - daher kein Rating, KL verl„ngert //26.04.24 Letzte Rechnung wurde erst auf die 3. Mahnung hin bezahlt. Anscheinend ist die 'durchgerutscht'. Auf auto-mahnung gesetzt"}
   
   hSpecial["LORENTZ"] := {"DATE"=>StoD("20251031"), "LIMIT"=>3500, "COMMENT"=>"18.09.25 erneuert //14.03.22 Keine Bewertung durch CS, Umsatz in letzten 12 Monaten < 2000?, bisher aber mit Skonto bezahlt"}
   
   hSpecial["VARTAR"] := {"DATE"=>STOD("20241230"),"LIMIT"=>7000, "COMMENT"=>"15.11.24 fr die Auslieferung bestehender Auftr„ge fr neue wurde das Limit seitens der WKV gestrichen"}

   RETURN NIL

STATIC FUNCTION _FormatHistoricalComments(cComments)
   LOCAL cFormatted := ""
   LOCAL aSegments, cSegment, cDate, cText
   LOCAL i, nPos
   
   IF Empty(cComments)
      RETURN ""
   ENDIF
   
   // Split by "//" which separates different date entries
   aSegments := HB_ATokens(cComments, "//")
   
   FOR i := 1 TO Len(aSegments)
      cSegment := AllTrim(aSegments[i])
      
      IF ! Empty(cSegment)
         // Look for date pattern at the beginning (DD.MM.YY or DD.MM.YYYY)
         nPos := At(" ", cSegment)
         IF nPos > 0 .AND. nPos <= 12  // Date should be within first 12 characters
            cDate := AllTrim(Left(cSegment, nPos - 1))
            cText := AllTrim(SubStr(cSegment, nPos + 1))
            
            // Check if it looks like a date (contains dots and numbers)
            IF "." $ cDate .AND. Len(cDate) >= 6 .AND. Len(cDate) <= 10
               cFormatted += cDate + ": " + cText + Chr(13) + Chr(10)
            ELSE
               // Not a date pattern, add as continuation of previous line
               IF ! Empty(cFormatted)
                  cFormatted := Left(cFormatted, Len(cFormatted) - 2) + " " + cSegment + Chr(13) + Chr(10)
               ELSE
                  cFormatted += cSegment + Chr(13) + Chr(10)
               ENDIF
            ENDIF
         ELSE
            // No space found or space too far, treat as continuation
            IF ! Empty(cFormatted)
               cFormatted := Left(cFormatted, Len(cFormatted) - 2) + " " + cSegment + Chr(13) + Chr(10)
            ELSE
               cFormatted += cSegment + Chr(13) + Chr(10)
            ENDIF
         ENDIF
      ENDIF
   NEXT
   
   RETURN cFormatted

STATIC FUNCTION _ShowImportSummary(nImported, nSkipped, nErrors)
   LOCAL cMsg := "Import Summary:" + Chr(13) + Chr(10) + Chr(13) + Chr(10)
   
   cMsg += "Records imported: " + AllTrim(Str(nImported)) + Chr(13) + Chr(10)
   cMsg += "Records skipped:  " + AllTrim(Str(nSkipped)) + Chr(13) + Chr(10)
   cMsg += "Errors:          " + AllTrim(Str(nErrors)) + Chr(13) + Chr(10)
   
   IF nImported > 0
      cMsg += Chr(13) + Chr(10) + "All imported records are set to Active=Yes" + Chr(13) + Chr(10)
      cMsg += "Valid From date is set to today's date" + Chr(13) + Chr(10)
      cMsg += "Valid Until date is taken from the original limit definition"
   ENDIF
   
   Tr_MsgBox("Import Complete", cMsg)
   
RETURN NIL
