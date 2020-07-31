LOCAL cUrl
   NetUse("artikel","art")

   art->(dbSetFilter({|| art->Manufactur == 1 .OR. art->Manufactur == 3},"manufactur==1 .OR. manufactur == 3"))
   art->(dbSeek( "PX0587" ))
   //DO WHILE ! art->(Eof())
      ? art->Matchcode
      cMatch := "PX0587"
      cUrl := "http://components.arrow.com/part/search/"+cMatch+"?region=arrowce"
           Alert(cUrl)

      oHttp := TIpClientHttp():new( cUrl )
//      oHttp:SetProxy( "213.136.79.124", 80 )
      oHttp:nConnTimeout := 10000
      IF oHttp:open()
        cData := oHttp:ReadAll()
         If ValType(cData) != "C"
            IF lDbg
               Alert("No Data")
            ENDIF
            RETURN NIL
         Endif

         aMatch := HB_Regex('<a href="\/part\/detail\/([0-9]*)_([0-9]*)">'+StrTran(cMatch,"/","\/")+'<\/a>',cData)
         IF Len(aMatch) > 0
            IF Val(aMatch[2]) != 323
               ? "NOT 323"
            ENDIF
            ? art->Matchcode,LTrim(Str(Val(aMatch[3])))
         ELSE
            ?? "NO MATCH"
            MemoEdit(cData)
         ENDIF
      ELSE
         ? "Open failed" //,oHttp:InetErrorCode( oHttp:SocketCon )
      ENDIF
      IF Inkey() == 27
         //EXIT
      ENDIF
      art->(dbSkip())
   //ENDDO
   art->(dbClearFilter())
   Inkey(0,128)
