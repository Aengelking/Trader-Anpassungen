#define CRLF Chr(13)+Chr(10)
FUNC HOOK_AFTER_MOVE_STOCK(nArtnr,cVonLager,cNachLager,nMenge,cCharge)   
   LOCAL oArt
   //LOCAL lToQS := .F.
   LOCAL lFromQS := .F.
   LOCAL lFromSperr := .F.
   LOCAL lToSperr := .F.
   LOCAL cGrund,aTo
   LOCAL aQSMonitor := {;
      "KS27732/802165",;  //3 batches
      "KS27732/724549",;
      "KS27732/725894",;
      "KS27732/725895",;
      "KS27732/725896",;
      "KS27732/725897",;
      "KS27732/725898",;
      "KS27732/725950",;
      "KS27732/802166";   //of these products
   }
   

   NetUse("lagerort","lago")
   lago->(dbSeek(cVonLager))
   IF lago->SperrLager       
      IF lago->TempSperr .AND. Left(cVonLager,3) != "093"
         //lFromQS := .T.
      ELSE
         lFromSperr := .T.
      ENDIF
   ENDIF
   lago->(dbSeek(cNachLager))
   IF lago->SperrLager      
      IF lago->TempSperr .AND. Left(cNachLager,3) != "093"
         //lToQS := .T.
      ELSE
         lToSperr := .T.
      ENDIF
   ENDIF

   IF lFromQS .AND.  lToSperr //QS šberwachen
      Netuse("artikel","art")
      art->(dbSetOrder( 2 ))
      art->(dbSeek( Str(nArtnr,6) ))

      IF Trim(art->matchode) $ aQSMonitor
         aTo := {{"amos.engelking@engelking.de","Amos"}}
         SendMail(aTo,Trim(art->Matchcode)+" wurde von der QS freigegeben")   
      ENDIF
   ENDIF

   IF (!lFromSperr .AND. lToSperr) .OR. (lFromSperr .AND. ! lToSperr)
      Netuse("artikel","art")
      art->(dbSetOrder( 2 ))
      art->(dbSeek( Str(nArtnr,6) ))

      IF MaxCol() < 50
         cGrund := "šber Scanner"
      ELSEIF ! lFromSperr  //wird gesperrt und nicht auf dem Scanner
         cGrund := MBaseRun(Path("run\print_sperrvermerk"),{.T.})
      ELSE
         cGrund := ""
      ENDIF
      
      //NetUse("parts","part")

      aTo := {{"marcel.moessner@engelking.de","Marcel"}}      
      SendMail(aTo,Trim(art->Matchcode)+" wurde "+IF(lFromSperr,"ent","ge")+"sperrt","Von Lager: "+cVonLager+CRLF+"Nach Lager:"+cNachLager+CRLF+"Menge: "+Transform(nMenge,Me(art->Me))+CRLF+cGrund)   
      
      //SendMessage("Qualitaet | Artikel gesperrt","Artikel "+Trim(art->Matchcode)+" wurde "+IF(lFromSperr,"ent","ge")+"sperrt","Von Lager: "+cVonLager+CRLF+"Nach Lager:"+cNachLager+CRLF+"Menge: "+Transform(nMenge,Me(art->Me))+CRLF+cGrund)
   ENDIF

   IF ! lFromSperr .AND. lToSperr
      MBAseRun(Path("run\inform_sales_stock_block"),{nArtnr,nMenge})
   ENDIF
         
RETURN NIL