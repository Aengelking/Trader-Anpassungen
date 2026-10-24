PROC RUN_Letter()
   LOCAL nStdErr,nStdOut,nChild,nBytes,cData,cOut,lError
   LOCAL cCmd,cOpt,cFile,nNr,cError
   LOCAL oPrinter,nType

#ifndef __XHARBOUR__
	#xtranslate ShellExecute([<x,...>])        => Wapi_ShellExecute(<x>)
#endif
NetUse("countrie","ctr",.F.,0)
NetUse("post","post")

oPrinter := getCurrentPrinterObject()

nType := 0

Do While nType < 2
	SET DEVICE TO SCREEN
	SET CONSOLE ON
	SET PRINTER OFF	
	
	If ! IsInHook("after_pack_from_list") .AND. ! GetConfigValue("batchmode")
		nType := Tr_MsgBox("Brief versenden?",,{"Vorschau","Nein","Ja","Einschreiben"})
	Else
		nType := 3
	Endif
	If nType == 3 .OR. (nType == 4 .AND. (GetConfigValue("batchmode") .OR. Tr_MsgBox(HB_AnsiToOem("Durch den Versand als Einschreiben entstehen zusätzliche Kosten"),,{"abbrechen","versenden"}) == 2) )
      	cCmd := '"C:\Program Files (x86)\WinSCP\WinSCP.com"'
      	cOpt := ""
         cOpt := '/command "option batch on" "option confirm off"'
      	cOpt += ' "open sftp://amos.engelking@engelking.de:loving16@api.onlinebrief24.de '         
//         cOpt += '-hostkey=""ssh-rsa 3072 cno3q2GVL0HdDTA1sbvlcIv4TKvJGPIafyTlVQk76S0=""'  
         cOpt += '-hostkey=""ssh-rsa 4096 XIRy+GtxhMl1u0eKejbR10GBTJxEqZYvjvZDvYqLhXk""'
         cOpt += '"'         
      	cOpt += ' "put ""'+oPrinter:Data:Filename+'"" ""/upload/api/1000'+If(nType==4,"1","0")+'00000000-'+hb_strToUtf8(SubStr(oPrinter:Data:Filename,RAT("\",oPrinter:Data:Filename)+1))+'"" -nopermissions -nopreservetime" "exit"'

         lError := .T.

         HB_OpenProcess( cCmd+" "+cOpt,,@nStdOut,@nStdErr,.T.,@nChild )

         IF nChild > 0

            nBytes := 1
            cOut := ""
            DO WHILE nBytes > 0
               cData := Space( 1000 )
               nBytes := Fread( nStdOUT, @cData, Len(cData) )
               cOut += cData
            ENDDO
            IF AT("100%",cOut) != 0 //File has been uploaded to 100%
               lError := .F.
            ELSE
               nBytes := 1
               cError := ""
               DO WHILE nBytes > 0
                  cData := Space( 1000 )
                  nBytes := Fread( nStdOUT, @cData, Len(cData) )
                  cError += cData
               ENDDO
            ENDIF

            HB_ProcessValue( nChild ) //wait for end
//         
         ENDIF

         IF lError
            IF ! GetConfigValue("batchmode")
               Tr_MsgBox(t("Fehler beim Versenden des Briefs!"))
            ENDIF
            SendMail({{"amos.engelking@engelking.de","Amos"}},"Fehler beim Briefversand",cCmd+"<br>"+cOpt+"<br>"+cOut+"<br>"+cError)
            
         ELSE
            cFile := NIL
            HB_FNameSplit(oPrinter:Data:Filename,NIL,@cFile)

            IF Left(cFile,2) == "RE" //Rechnung
               nNr := Val(SubStr(cFile,3,9))
               IF nNr != 0
                  post->(Add_Rec(0))
                  post->Typ := "RE"
                  post->Via := "POST"
                  post->Nummer := nNr
                  post->DateTime := TtoS(DateTime())
                  post->(dbUnLock())
               ENDIF
            ENDIF
//            Tr_MsgBox(t("Brief erfolgreich hochgeladen"))
         ENDIF
	Elseif nType == 1
		ShellExecute(NIL,"open",oPrinter:Data:Filename,"","",0)
	Endif
Enddo