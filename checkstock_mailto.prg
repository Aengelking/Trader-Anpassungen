* checkstock_mailto.prg
*
* Recipient policy hook for the checkstock mails.
* checkstock.prg routes every recipient list through Hook("checkstock_mailto", {aTo}, aTo).
*
* Current rule: a recipient who is currently absent (oSettings AwayFrom..AwayUntil covers
* today) is redirected to the substitute stored in oSettings AwaySubst (a buyer number).
* The substitute chain is followed (if the substitute is also absent) with loop protection.
* If no valid substitute exists the original recipient is kept.
*
* Tokens "COMMON" / "USER" and unknown addresses are left untouched.
* Further recipient exceptions can be added in RedirectAbsentRcv().

FUNCTION HOOK_checkstock_mailto(aTo)
   LOCAL nX

   IF ValType(aTo) != "A"
      RETURN aTo
   ENDIF

   FOR nX := 1 TO Len(aTo)
      IF aTo[nx,1] $ {"soraya.hennig@engelking.de","michelle.pomp@engelking.de"}
         aTo[nX] := {"mara.henzler@engelking.de","Mara Henzler"}
      ENDIF
      IF ValType(aTo[nX]) == "A" .AND. Len(aTo[nX]) >= 1 .AND. ValType(aTo[nX, 1]) == "C"
         aTo[nX] := RedirectAbsentRcv(aTo[nX])
      ENDIF
   NEXT

RETURN aTo


STATIC FUNCTION RedirectAbsentRcv(aRcv)
   LOCAL cEmail   := Upper(AllTrim(aRcv[1]))
   LOCAL cType    := IF(Len(aRcv) >= 3, aRcv[3], NIL)
   LOCAL aVisited := {}
   LOCAL nUser, oUser, nSubst, oSubst

   IF Empty(cEmail) .OR. cEmail == "COMMON" .OR. cEmail == "USER"
      RETURN aRcv
   ENDIF

   DO WHILE .T.
      nUser := UserByEmail(cEmail)
      IF nUser == 0 .OR. AScan(aVisited, nUser) > 0   //unknown address or loop
         EXIT
      ENDIF
      AAdd(aVisited, nUser)

      oUser := User():New()
      IF ! oUser:Load(nUser)
         EXIT
      ENDIF

      //make sure the settings exist (idempotent) before reading them
      oUser:oSettings:Create("AwayFrom",  "Abwesend von",         "D", Stod(""))
      oUser:oSettings:Create("AwayUntil", "Abwesend bis",         "D", Stod(""))
      oUser:oSettings:Create("AwaySubst", "Vertreter (Buyer-Nr)", "N", 0)

      IF Empty(oUser:oSettings:AwayFrom) .OR. ;
         ! (oUser:oSettings:AwayFrom <= Date() .AND. oUser:oSettings:AwayUntil >= Date())
         EXIT   //not absent today
      ENDIF

      nSubst := oUser:oSettings:AwaySubst
      IF nSubst == 0
         EXIT   //absent but no substitute stored -> keep original
      ENDIF

      oSubst := User():New()
      IF ! oSubst:Load(nSubst) .OR. ! oSubst:Aktive .OR. Empty(AllTrim(oSubst:Email))
         EXIT   //invalid substitute -> keep last valid recipient
      ENDIF

      IF ValType(cType) == "C"
         aRcv := {AllTrim(oSubst:Email), Trim(oSubst:Name), cType}
      ELSE
         aRcv := {AllTrim(oSubst:Email), Trim(oSubst:Name)}
      ENDIF

      cEmail := Upper(AllTrim(oSubst:Email))   //chain: is the substitute absent too?
   ENDDO

RETURN aRcv


STATIC FUNCTION UserByEmail(cEmail)
   LOCAL nRec := 0

   NetUse("buyer", "buy")
   buy->(dbGoTop())
   DO WHILE ! buy->(Eof())
      IF Upper(AllTrim(buy->Email)) == cEmail
         nRec := buy->(Recno())
         EXIT
      ENDIF
      buy->(dbSkip())
   ENDDO

RETURN nRec
