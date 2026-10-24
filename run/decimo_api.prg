PROCEDURE RUN_DECIMO_API
   LOCAL oRest
   oRest := RestApi():New("https://development.rechnung.de/api/v2/","")
   ? ValTOPrg(oRest:GetPrincipals())
   IF oRest:lError
      ? oRest:cErrorText
   ENDIF
   Sinkey(0)
RETURN
   