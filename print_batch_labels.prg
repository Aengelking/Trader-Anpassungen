PROC RUN_PRINT_BATCH_LABELS(cCharge)

   LOCAL cEtiPath := "\\EK-SERVER4\DATA\Dokumente und Einstellungen\All Users\Dokumente\Aufkleber\"
   LOCAL cFile,hFieldMap
   LOCAL cWeek

   LOCAL nWeek,nYear

   hFieldMap := {"charge"=>"","charge_barcode"=>""}
   IF ! Empty(cCharge)
      //StickPrint("Charge")
      //PARAMETERS cFile,nCount,hFieldMap,cPrinter
      cFile := cEtiPath+"Allgemein\Charge.lbex"  //wir rufen labestar.prg direkt auf anstatt ber Stickprint zu gehen, damit wir die Daten ber hFieldMap hinzufgen k”nnen
      hFieldMap := {"charge"=>Trim(cCharge),"charge_barcode"=>Trim(cCharge)}

      MBaseRun(Trim(Tr_getini(1))+"\run\labelstar",{cFile,GetBox(1,"Anzahl Chargenaufkleber"),hFieldMap})  
   ENDIF
   cFile := cEtiPath+"Wareneingang\"+LTrim(Str(art->Artikelnr))+".lbex"
   IF File(cFile)
      IF art->Artikelnr $ {18331,999998}
         cWeek := Space(5) //"  /  "
         DO WHILE Empty(cWeek)         
            cWeek := GetBox(cWeek,"Produktionswoche MM/JJ","99/99",,,,{|cWeek| 
               nWeek := Val(Left(cWeek,2))
               nYear := Val(Right(cWeek,2))
               RETURN nWeek <= 51 .AND. nWeek >= 1 .AND. 2000+nYear >= Year(Date())-1 .AND. 2000+nYear <= Year(Date())
            })
         ENDDO
         hFieldMap["WEEK"] := cWeek
         hFieldMap["WEEK_ENCODED"] := Chr(Val(Right(cWeek,2))-14+65)+Left(cWeek,2)
      ENDIF         
      MBaseRun(Trim(Tr_getini(1))+"\run\labelstar",{cFile,GetBox(1,"Anzahl Wareneingangskleber"),hFieldMap})
   ENDIF
RETURN