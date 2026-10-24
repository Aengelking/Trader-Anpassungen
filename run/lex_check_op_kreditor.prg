#define LX_CAT_KREDITOR         256

IF ! LX_Start()
   Alert("Keine Lexwware-Verbindung")
ENDIF


aKred := LX_GetAccountsInCat(LX_CAT_KREDITOR)
hOPS  := LX_GetOffenePostenSummen(.F.)
CLS
? "Konto",Space(30),PadL("Saldo",9),PadL("OP",9)
FOR nX := 1 TO Len(aKred)
   nSaldo := LX_GetSaldo(aKred[nX],Date())
   nOp := IF(HHasKey(hOPs,aKred[nX]),hOPs[aKred[nX]],0)
   IF nSaldo != nOP
      ? Pad(aKred[nX],5),'"'+Pad(LX_GetAccountName(aKred[nX]),30)+'"',Str(nSaldo,9,2),Str(nOP,9,2)
   ENDIF

NEXT

SInkey(0,128)