LOCAL cLiefma := Space(8)
LOCAL nYear := Year(Date())-1
LOCAL nYearTo := Year(Date())
LOCAL cFile,nHandle

Head("Export von einem Lieferanten gelieferten Produkte")

NetUse("engkund","ku",.F.,0)
NetUse("engabg","abg",.F.,0)
NetUSe("artikel","art",.F.,0)
NetUse( "artlief","alil",.F.,0 )
NetUse("manufact","man",.F.,0)

cLiefma := Space(8)
cYear := Str(Year(Date()),4)
//@ 01,00 SAY "Lieferant " GET cLiefma PICTURE "@!" //VALID Eval({|| ku->(dbSetOrder(1)), ku->(dbSeek(cLiefma+"L")) })
//@ 02,00 SAY "Jahr      " GET cYear PICTURE "9999" VALID Val(cYear) >= 1990
//READ
@ 01,00 SAY "Lieferant"  GET cLiefma PICTURE "@!" VALID {|| ku->(dbSetOrder(1)), ku->(dbSeek(cLiefma+"L")) }
@ 02,00 SAY "Von Jahr " GET nYear PICTURE "9999" VALID nYear >= 1990 .AND. nYear <= Year(Date())
@ 03,00 SAY "Bis Jahr " GET nYearTo PICTURE "9999" VALID nYearTo >= 1990 .AND. nYearTo <= Year(Date()) .AND. nYearTo >= nYear
READ
IF LastKey() == 27
	Return
ENDIF

cFile := Trim(Tr_Getini(1))+"\export\"+Trim(cLiefma)+"_products_"+Str(nYear,4)+"_"+Str(nYearTo,4)+".csv"

DO WHILE LastKey() != 27 .AND. (nHandle := FCreate(cFile)) == -1 .AND. TR_MsgBox("Could not open file ("+cFile+") "+LTrim(Str(Ferror())),,{"Retry","Cancel"}) == 1
ENDDO
IF nHandle == -1
   RETURN
ENDIF

abg->(dbSetOrder(4))
If ! abg->(dbSeek( cLiefma+"L" , .T.))
	TR_MsgBox("Keine Eintraege gefunden "+cLiefma)
Endif

aProducts := {}
art->(dbSetOrder(1))
abg->(dbSetFilter( {|| Year(abg->Datum) >= nYear .AND. Year(abg->Datum) <= nYearTo .AND. Trim(abg->Buart) == "WE" },;
                   'Year(Datum) >= '+Str(nYear,4)+' .AND. Year(Datum) <= '+Str(nYearTo,4)+' .AND. Trim(Buart) == "WE"'))
DO WHILE abg->Liefma == cLiefma .AND. abg->Group == "L" .AND. ! abg->(Eof())
	If /*Year(abg->Datum) >= nYear .AND. Year(abg->Datum) <= nYearTo .AND. Trim(abg->Buart) == "WE" .AND.*/ AScan(aProducts,{|x| x[1] == abg->Matchcode}) == 0
		@ MaxRow(),00 SAY abg->Matchcode
      art->(dbSeek( abg->Matchcode ))
		man->(dbSeek( Str(art->Manufactur,5) ))
		Aadd(aProducts,{abg->Matchcode,abg->Matchcode,art->Artikel,man->Short,art->KnCode})
		If alil->(dbSeek(Pad(cLiefma,8)+Str(art->Artikelnr,6))) .AND. ! Empty(alil->Artlief)
			aProducts[-1,2] := alil->Artlief
		Endif
	Endif

	abg->(dbSkip())
ENDDO

abg->(dbClearFilter())

//replace suppliers part nos
/*nX := 1
art->(dbSetOrder( 1 ))
Do While nX <= Len(aProducts)
	nX++
Endif*/

nX := 1
ASort(aProducts,,,{|x,y| x[2] < y[2]} )
HB_AIns(aProducts,1,{"Part no.","Supplier Part No.","Description","Brand","TARIC code"},.T.)
//MemoEdit(ValToPrg(aProducts))
FClose(nHandle)
SaveAsCSV(cFile,aProducts)
/*SET PRINTER ON
SET CONSOLE OFF
SET PRINTER TO (cFile)
?? "Part no.,Description,Brand,TARIC code"
Do While nX <= Len(aProducts)
	? Trim(aProducts[nX,2])+","+Trim(StrTran(HB_OemToAnsi(aProducts[nX,3]),",",Chr(59)))+","+Trim(aProducts[nX,4])+","+Trim(aProducts[nX,5])
	nX++
ENDDO
SET PRINTER OFF
SET CONSOLE ON
SET PRINTER TO*/

Wapi_ShellExecute(,"open",cFile)
? "done"
SInkey(0)