PROC RUN_REPORT_ZOLLPARTS
   LOCAL aManus := GetManuFacturerArray()
   LOCAL nX
   LOCAL getlist := {}
   LOCAL aCheck := Array(Len(aManus[1]))
   LOCAL cFilter := ""
   LOCAL aList,aRec
   LOCAL cFile

   MEMVAR C_one_list

   Head(t("Artikelliste für Zoll"))

   AFill(aCheck,.F.)

   NetUse("artikel","art")
   NetUse("group","grup",.F.,0)
   NetUse("artlief","ali")
   NetUse("manufact","manu")
   NetUse("engkund","ku")
   NetUSe("kn","kn")

   FOR nX := 1 TO Len(aManus[2])
      @ nX,00 GET aCheck[nX] CHECKBOX CAPTION aManus[2,nX] //COLOR c_one_list
   NEXT
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   cFilter := ""

   FOR nX := 1 TO Len(aCheck)
      IF aCheck[nX]
         IF ! Empty(cFilter)
            cFilter += ","
         ENDIF
         cFilter += LTrim(Str(aManus[1,nX]))
      ENDIF
   NEXT

   IF Empty(cFilter)
      RETURN
   ENDIF

   aList := {{"Unsere Artikelnummer","Artikelnummer Lieferant","Beschreibung","Zolltarifnummer","Zoll-Beschreibung","Ursprungsland"}}

   cFilter := "art->Manufactur $ {"+cFilter+"} .AND. ! art->Obsolete"

   art->(dbSetFilter( {|| &(cFilter) },cFilter))
   art->(dbGoTop())
   DO WHILE ! art->(EOF())
      grup->(dbSeek( art->Gruppe ))
      aRec := {Trim(art->Matchcode),"",Trim(grup->Name),Trim(art->KnCode),,art->Ursprung}

      IF manu->(dbSeek( Str( art->Manufactur,5) )) .AND. manu->Address != 0 
         ku->(dbSetOrder( 8 ))
         ku->(dbSeek( Str(manu->Address,6) ))
         IF ali->(dbSeek( ku->Kunde+Str(art->Artikelnr,6) ))
            aRec[2] := Trim(ali->Artlief)
         ENDIF
      ENDIF      
      IF kn->(dbSeek( Pad(StrTran(art->KnCode," ",""),8)) )
         aRec[5] := Trim(kn->Self_Expla)
      ENDIF

      Aadd(aList,aRec)
   
      art->(dbSkip())
   ENDDO
   
   IF Len(aList) == 1 //header only
      Tr_MsgBox("Keine Einträge gefunden")
      RETURN 
   ENDIF


   DO WHILE .T.
      
      cFile := Wvt_GetSaveFileName( 0,cFile , "XLSX Datei", { {"Excel Spreadsheet (*.xlsx)","*.xlsx"},{"Alle Dateien (*.*)","*.*"} }, , Trim(Tr_getini(1))+"\export\" )
      IF Empty(cFile)
         EXIT
      ENDIF
      IF AT(".",cFile) == 0
         cFile := Trim(cFile)+".xlsx"
      ENDIF
      SaveToOO(cFile,{"Artikel"=>aList},,,.T.)
   ENDDO  

   IF File(cFile)
      //Wapi_ShellExecute(,"open",cFile)
   ENDIF
   
RETURN

#include 'x:\run\savetooo.prg'