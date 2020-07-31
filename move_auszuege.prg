cDir := HB_AnsiToOem("Y:\Dokumente und Einstellungen\Sigrid\Eigene Dateien\Kontoauszüge\Voba")
cTo  := HB_AnsiToOem("Y:\Dokumente und Einstellungen\All Users\Dokumente\Kontoauszüge\Volksbank")

aDir := Directory(cDir+"\*.html")

Alert(Str(Len(aDir)))

FOR nX := 1 TO Len(aDir)
   cDate := Left(aDir[nX,1],10)
   IF RAT(".",cDate) == 6
     dDate := CToD(cDate)
     ? aDir[nX,1],dDate
     IF ! Empty(dDate)
         ? SubStr(DToS(dDate),3)+SubStr(aDir[nX,1],11)
        RENAME (cDir+"\"+aDir[nX,1]) TO (cTo+"\"+SubStr(DToS(dDate),3)+SubStr(aDir[nX,1],11))
        ? Ferror()
     ENDIF
   ENDIF
NEXT

Inkey(0,128)