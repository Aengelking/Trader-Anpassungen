#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

PROC StartVerguss
   LOCAL pCurl,cContent,nErr,hData,lSuccess,cText

   NetUse("restime","rst")
   NetUse("werkauf","wer")
   rst->(dbSetOrder( 3 ))
   rst->(dbSetFilter({|| rst->Resource==16 .AND. ! rst->Complete },"resource==16 .AND. ! complete"))
   
   rst->(dbSeek( "WA "+DtoS(Date()), .T. ))
   IF ! rst->(EOF()) .AND. rst->Start >= DtoS(Date())+"0000000"  .AND. rst->Start <= Dtos(Date())+"2359599" .AND. wer->(dbSeek( Str(rst->No,6) ))
      CLS
      ? "Vergussmaschine wird heute um "+SubStr(rst->start,9,2)+":"+SubStr(rst->Start,12,2)+" Uhr ben”tigt fr Auftrag "+LTrim(Str(rst->No))
      ? rst->Start,rst->ID,rst->Resource

      pCurl := Curl_Easy_init()
      Curl_Easy_SetOpt(pCurl,HB_CURLOPT_URL,"http://192.168.5.216/cm?cmnd=Power%20ON")
      Curl_Easy_SetOpt(pCurl, HB_CURLOPT_SSL_VERIFYPEER, .F. )
      curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )      
      nErr := Curl_Easy_Perform(pCurl)
      curl_easy_setopt( pCurl, HB_CURLOPT_DL_BUFF_GET, @cContent )
      Curl_Easy_CleanUp(pCurl)
      
      ? nErr
      ? cContent
      hData := HB_JsonDecode(cContent)
      lSuccess := .F.
      IF ValType(hData) != "H" .OR. ! HHasKey(hData,"POWER")
         cText := "Fehler beim Lesen des Status der Vergussmaschine"
      ELSE
         IF hData["POWER"] == "ON"
            cText := "Vergussmaschine eingeschaltet"
            lSuccess := .T.
         ELSE
            cText := "Fehler beim Einschalten der Vergussmaschine"
         ENDIF
      ENDIF
      ? cText
      
      IF ! lSuccess
         SendMail({{"amos.engelking@engelking.de","Amos"}},cText,"Fr Auftrag "+LTrim(Str(rst->No))+" um "+SubStr(rst->Start,9,2)+":"+SubStr(rst->Start,12,2)+" Uhr")
      ENDIF

      //Sinkey(0)
   ENDIF
   rst->(dbClearFilter())
   