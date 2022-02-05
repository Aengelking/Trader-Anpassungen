//LOCAL aList := {41266}
//LOCAL aList := {40877,40881,40886,40998,40999,41029,41058,41069,41073,41106,41150,41186,41209,41246,41247,41248,41249,41250,41264,41308,41326,41361,41364,41365,41376}

LOCAL nX

NetUse("englsre","re")
NetUse("skontoa","sk")
netUse("engkund","ku")

re->(dbSetOrder( 12 ))

FOR nX := 1 TO Len(aList)
   re->(dbSeek( Str(aList[nX],6) ))
   IF re->Skonto == 8
      RechnungUpdateTotal()
      re->(Rec_Lock())
      re->Transfer := .F.
      re->(dbUnLock())
   ENDIF
NEXT