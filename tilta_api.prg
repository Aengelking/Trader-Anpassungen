/*****************************************************************************
 *  tilta_api.prg  -  gemeinsame Helfer der Tilta-Anbindung
 *
 *  Wird von den Tilta-Run-Scripts am Dateiende eingebunden:
 *
 *      #include "x:\run\tilta_api.prg"
 *
 *  Hier steht auch der Umschalter Sandbox/Produktion - an genau einer Stelle
 *  fuer alle Scripts.
 *****************************************************************************/

/*  .T. = Sandbox (https://api.tilta-sandbox.io, Schluesselbund TILTA_SB)
 *  .F. = Produktion (https://api.tilta.io, Schluesselbund TILTA)          */
STATIC FUNCTION __TiltaIsSandbox()
RETURN .F.

STATIC FUNCTION __TiltaBase()
RETURN IF(__TiltaIsSandbox(),"https://api.tilta-sandbox.io/v1/","https://api.tilta.io/v1/")

STATIC FUNCTION __TiltaKey()
RETURN IF(__TiltaIsSandbox(),"TILTA_SB","TILTA")

/*  Unix-Timestamp aus einem Datum (Tilta erwartet Sekunden seit 1970)  */
STATIC FUNCTION __TiltaTs(dDate)
RETURN (dDate - SToD("19700101")) * 86400

/*  Wie __TiltaTs, aber auf das Ende des Tages (23:00). Fuer Faelligkeiten:
 *  Tilta verlangt "minimum in two days" und rechnet ab dem Aufrufzeitpunkt -
 *  mit Mitternacht wuerde die Grenze je nach Tageszeit knapp verfehlt.      */
STATIC FUNCTION __TiltaTsEnd(dDate)
RETURN __TiltaTs(dDate) + 82800

/*  JSON-Aufruf ueber RestApi (Schluesselbund + Bearer wie beim Facility-Abruf).
 *  Liefert den Body, HTTP-Code und -Text per Referenz. Fehler auf
 *  Transportebene werden abgefangen, nResponse ist dann 0.
 *
 *  content-type muss explizit mitgegeben werden - RestApi setzt keinen, curl
 *  wuerde sonst form-urlencoded schicken. Aber nur wenn es auch einen Body
 *  gibt: bei einem POST ohne Body (z.B. facility beantragen) antwortet Tilta
 *  sonst mit 400 "Body cannot be empty when content-type is set to
 *  application/json". Ein Header ohne Wert ("content-type:") sagt curl, den
 *  Header ganz weglassen - sonst wuerde curl bei POST von sich aus
 *  form-urlencoded setzen.                                                  */
STATIC FUNCTION __TiltaCall(cUrl,cMethod,hData,nResponse,cResponse)
   LOCAL oApi
   LOCAL cBody := ""
   LOCAL aHeader := {"authorization: Bearer $APIKEY$"}

   nResponse := 0
   cResponse := ""

   Aadd(aHeader,"content-type:"+IF(Empty(hData),""," application/json"))

   BEGIN SEQUENCE WITH {|e| Break(e)}
      oApi := RestApi():New()
      oApi:cBaseUrl    := __TiltaBase()
      oApi:cApiKeyName := __TiltaKey()
      cBody := oApi:Execute(cUrl,cMethod,hData,aHeader,.T.,@nResponse,@cResponse)
   RECOVER
      nResponse := 0
      cResponse := "Verbindungsfehler"
   END SEQUENCE

RETURN cBody

/*  Datei-Upload als multipart/form-data ueber RestApi:UploadForm.
 *  aDocs = {{cDatei,cTyp},...}; cTyp: INVOICE, CREDIT_NOTE, PERFORMANCE_PROOF,
 *  CONTRACT, OTHER. Rueckgabe ist der HTTP-Code.
 *
 *  Der Bearer-Token wird bewusst NICHT hier geholt: Keychain_GetPassword()
 *  gibt ihn nur an freigegebene Funktionen heraus, und er soll die RestApi
 *  nicht verlassen. Kein content-type-Header - den setzt curl mit der
 *  multipart-Grenze selbst.                                                */
STATIC FUNCTION __TiltaUpload(cExtId,aDocs,cResponse)
   LOCAL oApi
   LOCAL aForm := {}
   LOCAL nResponse := 0
   LOCAL nX

   FOR nX := 1 TO Len(aDocs)
      Aadd(aForm,{"files",aDocs[nX][1],.T.,"application/pdf"})
      Aadd(aForm,{"types",aDocs[nX][2],.F.})
   NEXT

   BEGIN SEQUENCE WITH {|e| Break(e)}
      oApi := RestApi():New()
      oApi:cBaseUrl    := __TiltaBase()
      oApi:cApiKeyName := __TiltaKey()
      oApi:UploadForm("invoices/"+cExtId+"/files",aForm, ;
                      {"authorization: Bearer $APIKEY$"},@nResponse,@cResponse)
   RECOVER
      nResponse := 0
      cResponse := "Verbindungsfehler"
   END SEQUENCE

RETURN nResponse
