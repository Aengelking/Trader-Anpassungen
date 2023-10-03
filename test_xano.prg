
FUNCTION TEST_XANO()
   LOCAL oXano := RestApi():New(),hAuth
oXano:cBaseUrl := "https://x8ki-letl-twmt.n7.xano.io/api:SU4hTojI"
cToken := "SCHLUESSEL_ENTFERNT"

CLS
hAuth := HB_JsonDecode( oXano:Execute("/auth/me",,,{"Authorization: Bearer "+cToken}) )
? ValToPrg( hAuth )
IF HHasKey(hAuth,"code") .AND. hAuth["code"] == "ERROR_CODE_UNAUTHORIZED"
   ? "FAILED"
ENDIF
Sinkey(0)