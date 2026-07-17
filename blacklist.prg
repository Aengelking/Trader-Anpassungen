//----------------------------------------------------------------------------
// Shared mailing / newsletter blacklist core.
//
// Backed by mailblack.dbf:
//    ENTRY   C(80)  normalized value (email lowercased, or domain without '@')
//    TYPE    C(1)   "E" = single email address, "D" = whole domain
//    REASON  C(60)  free text
//    ADDEDAT D(8)   date added
//    ADDEDBY N(6)   user id
//    BREVO   L(1)   entry blocks the Brevo product mailing  (channel "B")
//    CLEVER  L(1)   entry blocks the CleverReach export      (channel "C")
//
// The BREVO / CLEVER flag columns are OPTIONAL. If a flag column is missing
// the entry is treated as blocking that channel (so an old table without the
// columns blocks both channels - fully backward compatible).
//
// This file is meant to be #included at the BOTTOM of a runnable script
// (mailing.prg, export_contacts_cleverreach.prg, ...). The including module
// must declare the two module-wide caches near its top:
//    STATIC s_hBlackEmail
//    STATIC s_hBlackDomain
//----------------------------------------------------------------------------

STATIC FUNCTION BlacklistDataPath()
RETURN IF(GetConfigValue("FIRMPATH") != ".",GetConfigValue("FIRMPATH")+"\","")

STATIC FUNCTION OpenBlacklist()
   // Make the mblack workarea available, opening the table on demand.
   IF Select("mblack") == 0
      IF ! Leto_File(BlacklistDataPath()+"mailblack.dbf")
         RETURN .F.
      ENDIF
      NetUse("mailblack","mblack",.F.,0)
   ENDIF
RETURN Select("mblack") != 0

// Scope ("B" and/or "C") of the record currently under the cursor.
// A missing flag column counts as "channel active" for backward compat.
STATIC FUNCTION BlacklistRecScope()
   LOCAL cScope := ""
   IF mblack->(FieldPos("BREVO")) == 0 .OR. mblack->Brevo
      cScope += "B"
   ENDIF
   IF mblack->(FieldPos("CLEVER")) == 0 .OR. mblack->Clever
      cScope += "C"
   ENDIF
RETURN cScope

STATIC FUNCTION BlacklistUnion(cA,cB)
   LOCAL cR := ""
   IF "B" $ cA .OR. "B" $ cB
      cR += "B"
   ENDIF
   IF "C" $ cA .OR. "C" $ cB
      cR += "C"
   ENDIF
RETURN cR

STATIC FUNCTION BlacklistWriteScope(cScope)
   IF mblack->(FieldPos("BREVO")) > 0
      mblack->Brevo := "B" $ cScope
   ENDIF
   IF mblack->(FieldPos("CLEVER")) > 0
      mblack->Clever := "C" $ cScope
   ENDIF
RETURN NIL

STATIC FUNCTION LoadBlacklist()
   LOCAL cVal, cScope
   s_hBlackEmail  := {=>}
   s_hBlackDomain := {=>}
   IF OpenBlacklist()
      mblack->(dbGoTop())
      DO WHILE ! mblack->(Eof())
         IF ! mblack->(Deleted())
            cVal := Lower(Trim(mblack->Entry))
            IF ! Empty(cVal)
               cScope := BlacklistRecScope()
               IF mblack->Type == "D"
                  s_hBlackDomain[cVal] := BlacklistUnion(IF(HHasKey(s_hBlackDomain,cVal),s_hBlackDomain[cVal],""),cScope)
               ELSE
                  s_hBlackEmail[cVal] := BlacklistUnion(IF(HHasKey(s_hBlackEmail,cVal),s_hBlackEmail[cVal],""),cScope)
               ENDIF
            ENDIF
         ENDIF
         mblack->(dbSkip())
      ENDDO
   ENDIF
RETURN NIL

// Is cEmail blacklisted for channel cChannel ("B"=mailing, "C"=CleverReach)?
STATIC FUNCTION IsBlacklisted(cEmail,cChannel)
   LOCAL nAt, cDomain
   IF s_hBlackEmail == NIL
      LoadBlacklist()
   ENDIF
   IF Empty(cChannel)
      cChannel := "B"
   ENDIF
   cEmail := Lower(Trim(cEmail))
   IF Empty(cEmail)
      RETURN .F.
   ENDIF
   IF HHasKey(s_hBlackEmail,cEmail) .AND. cChannel $ s_hBlackEmail[cEmail]
      RETURN .T.
   ENDIF
   nAt := AT("@",cEmail)
   IF nAt > 0
      cDomain := SubStr(cEmail,nAt+1)
      IF ! Empty(cDomain) .AND. HHasKey(s_hBlackDomain,cDomain) .AND. cChannel $ s_hBlackDomain[cDomain]
         RETURN .T.
      ENDIF
   ENDIF
RETURN .F.

// Add (or extend the scope of) a blacklist entry. cScope defaults to both.
STATIC FUNCTION AddToBlacklist(cValue,cType,cReason,cScope)
   LOCAL lFound := .F.
   cValue := Lower(Trim(cValue))
   cType  := IF(cType == "D","D","E")
   IF Empty(cScope)
      cScope := "BC"
   ENDIF
   IF Empty(cValue)
      RETURN .F.
   ENDIF
   IF ! OpenBlacklist()
      Tr_MsgBox("Blacklist-Tabelle (mailblack) nicht gefunden")
      RETURN .F.
   ENDIF
   // Same value+type already there -> merge (widen) the scope instead of
   // duplicating. Seek via the lower(entry) index (order 1), then walk the
   // (few) records sharing that entry to match the type.
   mblack->(dbSetOrder(1))
   IF mblack->(dbSeek(cValue))
      DO WHILE ! mblack->(Eof()) .AND. Lower(Trim(mblack->Entry)) == cValue
         IF ! mblack->(Deleted()) .AND. mblack->Type == cType
            mblack->(Rec_Lock(0))
            BlacklistWriteScope(BlacklistUnion(BlacklistRecScope(),cScope))
            mblack->(dbUnLock())
            lFound := .T.
            EXIT
         ENDIF
         mblack->(dbSkip())
      ENDDO
   ENDIF
   IF ! lFound
      mblack->(Add_Rec(0))
      mblack->Entry   := cValue
      mblack->Type    := cType
      mblack->Reason  := cReason
      mblack->AddedAt := Date()
      mblack->AddedBy := SystemUser():Id
      BlacklistWriteScope(cScope)
      mblack->(dbUnLock())
   ENDIF
   s_hBlackEmail := NIL   // force a reload (picks up fresh scopes)
RETURN .T.

STATIC FUNCTION DeleteFromBlacklist(cValue,cType)
   cValue := Lower(Trim(cValue))
   cType  := Trim(cType)
   IF ! OpenBlacklist()
      RETURN .F.
   ENDIF
   mblack->(dbSetOrder(1))
   IF mblack->(dbSeek(cValue))
      DO WHILE ! mblack->(Eof()) .AND. Lower(Trim(mblack->Entry)) == cValue
         IF ! mblack->(Deleted()) .AND. Trim(mblack->Type) == cType
            mblack->(Rec_Lock(0))
            mblack->(dbDelete())
            mblack->(dbUnLock())
         ENDIF
         mblack->(dbSkip())
      ENDDO
   ENDIF
   s_hBlackEmail := NIL   // force a reload on next lookup
RETURN .T.

// Ask the user which channel(s) an entry should block. Returns "B", "C",
// "BC" or "" when cancelled.
STATIC FUNCTION AskBlacklistScope(cInfo)
   LOCAL nS := Tr_MsgBox("Blacklist gilt fuer:",cInfo,{"Abbrechen","Mailing","CleverReach","Beide"})
   DO CASE
   CASE nS == 2
      RETURN "B"
   CASE nS == 3
      RETURN "C"
   CASE nS == 4
      RETURN "BC"
   ENDCASE
RETURN ""

STATIC FUNCTION BlacklistScopeText(cScope)
   DO CASE
   CASE "B" $ cScope .AND. "C" $ cScope
      RETURN "Beide"
   CASE "B" $ cScope
      RETURN "Mailing"
   CASE "C" $ cScope
      RETURN "CleverReach"
   ENDCASE
RETURN "-"
