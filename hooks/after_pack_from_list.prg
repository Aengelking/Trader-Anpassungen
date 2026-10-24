PROCEDURE Hook_After_Pack_From_List(nNr,lRech,lInUse)
   LOCAL oExtra

   HB_SYMBOL_UNUSED(lInUse)

	If lRech
		NetUse("engkund","ku",.F.,0)

		re->(dbSetOrder( 4 ))
		re->(dbSeek( Str(nNr,6) ))

      GotoRechAddress()
      oExtra := ku->(ExtraData():New( ku->Nummer ))
      
      IF ! oExtra:Factoring
         UpdateInvoiceDate(nNr,Date())
      ENDIF
		
	Else	//lagerentnahme

	Endif
	SetPrinterMethodType(0)
	/*If Tr_MsgBox("Lagermengen korrigieren?",,{"Nein","Ja"}) == 2
		EINFUG(If(lRech,nNr,NIL),If(!lRech,nNr,NIL),.T.,.F.)
	Endif*/
RETURN