LOCAL aTables := {4,5,6,8,10}
LOCAL hPos    := {4=>{9,1},5=>{10,2},6=>{12,1},8=>{14,1},10=>{16,3}}
LOCAL nT
LOCAL cFile := Trim(Tr_Getini(1))+"\export\arcolectric_parts.csv"

Head("Arcolectric Artikel")

NetUse("artikel","art")
art->(dbSetOrder( 1 ))
art->(dbSeek( "ARS" ))
art->(dbSkip())

NetUse("artlief","ali")
ali->(dbSetOrder( 1 ))

CLS
SET PRINTER TO (cFile)
SET PRINTER ON


oOptBase := OptionBase():New()
oOptBase:Load("ARS")

?? "Our part no;Your part no"

FOR EACH nT IN aTables
   oTable := oOptBase:oTables:GetRecord(nT)
   ?? ";"+Trim(oTable:Funktion("EN"))
NEXT


DO WHILE At("ARS",art->Matchcode) == 1
   cStart := SubStr(art->Matchcode,15,1)+SubStr(art->Matchcode,4,4)+SubStr(art->Matchcode,8,1)+SubStr(art->Matchcode,13,1)

   IF ali->(dbSeek( Pad("BULGIN",8)+Str(art->Artikelnr,6) )) .AND. ! Empty(ali->Artlief)
      ? Trim(art->Matchcode)+";"+Trim(ali->Artlief)
      FOR EACH nT IN aTables
         cOpt := SubStr(art->Matchcode,hPos[nT,1],hPos[nT,2])
         oTable := oOptBase:oTables:GetRecord(nT)
         oOpt   := oTable:oKeys:GetRecord(cOpt)
         ?? ";"+Trim(oOpt:Descript("EN"))
      NEXT
   ENDIF
   art->(dbSkip())
ENDDO

SET PRINTER OFF
SET PRINTER TO

Wapi_ShellExecute(,"open",cFile)