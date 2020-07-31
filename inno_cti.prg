#include 'y:\hb32\include\inkey.ch'
#include 'y:\hb32\include\hbgtwvg.ch'
#include "y:\hb32\include\wvtwin.ch"
#include "y:\hb32\include\hbgtinfo.ch"
#include 'y:\hb32\include\inkey.ch'
#include 'y:\hb32\include\hbthread.ch'
STATIC lD := .F.
STATIC saHistory := {}
STATIC nR,nR2
STATIC aDebug :=  {}

PROCEDURE MonitorCalls
   _MonitorCalls()
RETURN 

PROCEDURE _MonitorCalls   
   LOCAL oInno
   LOCAL hUser
   LOCAL lUsersPolled := .F.
   LOCAL hData
   LOCAL nKey
   
   LOCAL nHandle := 0
   LOCAL nX,cNumber,nState
   LOCAL oWindow := GetMainWindow()
   LOCAL hNumber
   LOCAL bErr,bErrOld
   LOCAL nRows := maxRow()+1,nCols := MaxCol()+1  
   LOCAL lQuit := .F.
   MEMVAR hmtx_busy
   

   LOCAL hUserList := {;
      9=>"Engelking Amos",;
      45=>"Engelking Joel",;
      54=>"Mantel Tina",;
      33=>"Hamma Thimo",;
      41=>"Pehlic Sabid",;
      28=>"Engelking Johannes",;
      37=>"Engelking Samuel";
   }

   PUBLIC hmtx_busy := HB_mutexCreate()
   IF Tr_Getini(28) == 9
      lD := .T.      
   ENDIF

   CLS   
   nR := 0
   nR2 := MaxRow()/2+1

   hb_gtInfo( HB_GTI_NOTIFIERBLOCK   , {| nEvent, ... | 
      IF nEvent == HB_GTE_SETFOCUS
         //Debug("setfocus")
      ELSEIF nEvent == HB_GTE_KILLFOCUS
         //_HideMonitor()
      ELSEIF nEvent == HB_GTE_CLOSE
         _HideMonitor()
      ELSEIF nEvent == HB_GTE_MOUSE
         //Debug("Mouse event")
      ELSEIF nEvent == HB_GTE_MENU
         //Debug("Menu")
      ELSEIF nEvent == HB_GTE_COMMAND
         //Debug("Command")
      ENDIF
      /* IF nEvent != HB_GTE_PAINT .AND. nEvent != HB_GTE_GUIPARTS .AND. nEvent != HB_GTE_CTLCOLOR
         Debug("Event",nEvent) 
      ENDIF */
      RETURN NIL
   } )

   /* hb_gtInfo( HB_GTI_NOTIFIERBLOCKGUI, {|nEvent| 
      IF nEvent != HB_GTE_PAINT .AND. nEvent != HB_GTE_GUIPARTS .AND. nEvent != HB_GTE_CTLCOLOR
         Debug("GUI Event",nEvent) 
      ENDIF
   }) */
   
   NetUse("phonebook","pbk")

   
   IF ! HHasKey(hUserList,Tr_Getini(28))
      Alert("Benutzer nicht angelegt")
      RETURN
   ENDIF
   DO WHILE ! lQuit
      oInno := InnovaPhone():New("http://192.168.2.20/PBX0/user.soap","SOAP","vvjRJtTKXJ")
      IF ! oInno:LoggedIn()
         Alert("Login failed")
         RETURN
      ENDIF
      bErr := {|oErr|    
            SetMode(nRows,nCols)      
            oWindow:show()         
            hb_gtInfo( HB_GTI_SPEC, HB_GTS_WNDSTATE, HB_GTS_WS_SETASNORMAL )
            RETURN Eval(bErrOld,oErr)
      }
      ErrorBlock(bErr)
      _HideMonitor()
      DO WHILE .T.  //Polling loop
         ErrorBlock({|oErr|          
            Debug("Polling error")  //in this case we might have lost the connection to the server, so we exit the polling loop and try to re-connect
            Debug2(oErr:args)
            RETURN Break()            
         })
         BEGIN SEQUENCE
            hData := oInno:Poll()
         RECOVER
            EXIT //Exit the polling loop, this will cause a re-connect
         END
         ErrorBlock(bErr)
         IF hData != NIL //if it has not timed out
            hData := hData["RETURN"]
            IF HHasKey(hData,"USER") .AND. hData["USER"] != NIL
               IF ValType(hData["USER"]) !="A"               
                  Debug("User is not array",ValToPrg(hData["USER"]))
               ENDIF
               FOR EACH hUser IN hData["USER"]
                  //? ValToPrg(hUser)
                  IF hUser["CN"] != NIL
                     Debug("User:",hUser["CN"])
                     IF hUser["PRESENCE"] != NIL
                        Debug("Presence:",hUser["PRESENCE"][1])
                     ENDIF
                  ELSE
                     Debug("User list completed")
                     lUsersPolled := .T. //initial poll completed
                  ENDIF
               NEXT
            ENDIF
            IF hData["CALL"] != NIL 
               //Debug2(hData["CALL"])
               IF HB_BitAnd(Val(hData["CALL"][1]["STATE"]),128) != 0 //when this is true we have been called
                  Debug("Outbound")
                  nX := AScan(hData["CALL"][1]["NO"],{|x|x["TYPE"]=="peer"})
                  IF nX != 0                        
                     cNumber := hData["CALL"][1]["NO"][nX]["E164"]
                     IF Left(cNumber,1) == "#" //Hash is used for the alternative line e.g. SIP
                        cNumber := SubStr(cNumber,2)
                     ENDIF
                     Debug("No.:",cNumber)
                     IF Left(cNumber,1) == "0" //externer anruf
                        cNumber := SubStr(cNumber,2)
                        nState := HB_BitAnd(Val(hData["CALL"][1]["STATE"]),15)
                        Debug("State:",nState)
                        HB_mutexLock(hmtx_busy)
                        IF nState == 1 //setup, when the call is first registered, e.g. somebody is calling us                     
                           //Wvg_SetWindowPosToTop( hb_gtInfo( HB_GTI_SPEC, HB_GTS_WINDOWHANDLE ) )                                         
                           
                           IF ! lD
                              SetMode(3,30)                           
                              Wvg_SetWindowPosition( hb_gtInfo( HB_GTI_SPEC, HB_GTS_WINDOWHANDLE ), HB_GTINFO(HB_GTI_DESKTOPWIDTH)-650, HB_GTINFO(HB_GTI_DESKTOPHEIGHT)-350, .F. )
                           ELSE
                              //Wvg_SetWindowPosition( hb_gtInfo( HB_GTI_SPEC, HB_GTS_WINDOWHANDLE ), 0, 0, .F. )
                              //hb_gtInfo( HB_GTI_SPEC, HB_GTS_WNDSTATE, HB_GTS_WS_MAXIMIZED )
                              //hb_gtInfo( HB_GTI_SPEC, HB_GTS_WNDSTATE, HB_GTS_WS_SETASNORMAL )                                                     
                           ENDIF
                           SetColor("W+/B")
                           @ 00,00 CLEAR TO 03,30
                           oWindow:Show()              
                           hb_gtInfo( HB_GTI_SPEC, HB_GTS_WNDSTATE, HB_GTS_WS_SETONTOP )       
                           @ 01,00 SAY cNumber
                           @ 02,00 SAY "ruft an"
                           @ 00,00 SAY "suche..."     
                           IF Len(saHistory) >= 30
                              HB_ADel(saHistory,1,.T.)                                           
                           ENDIF
                           Aadd(saHistory,{"TIME"=>Time()})
                           IF Empty(cNumber)
                              ATail(saHistory)["NO"] := "Unbekannte Nummer"
                              Debug("unknown")
                              Debug2a("Unbekannte Nummer")
                              @ 00,00 SAY Pad("unbekannt",30)
                           ELSE                           
                              hNumber := FindNumber(cNumber)                     
                              Debug(hNumber["FIRM"])
                              Debug2a(cNumber+" "+hNumber["FIRM"])
                              ATail(saHistory)["NO"] := cNumber
                              ATail(saHistory)["FIRM"] := hNumber["FIRM"]
                              ATail(saHistory)["PERSON"] := hNumber["PERSON"]
                              @ 00,00 SAY Pad(hNumber["FIRM"],30)
                              IF ! Empty(hNumber["PERSON"])
                                 Debug(hNumber["PERSON"])
                                 @ 01,00 SAY Pad(hNumber["PERSON"],30)
                              ENDIF
                           ENDIF
                        ELSEIF nState == 5 //connected
                           IF ValType(hNumber) == "H" .AND. ! Empty(hNumber["FIRM"])
                              hb_gtInfo( HB_GTI_SPEC, HB_GTS_WNDSTATE, HB_GTS_WS_SETASNORMAL )
                              _ShowInfo(hNumber["ID"])   
                              //hb_threadStart(HB_THREAD_INHERIT_MEMVARS, {|| _ShowInfo(hNumber["ID"])} ) // @ProcessConnection() )
                           ENDIF
                           @ 02,00 SAY  "im Gespr„ch"
                        ELSEIF nState == 6 .OR. nState == 7 //hangup
                           @ 00,00 CLEAR TO 3,20
                           /*IF ! lD
                              oWindow:hide()                           
                           ELSE
                              hb_gtInfo( HB_GTI_SPEC, HB_GTS_WNDSTATE, HB_GTS_WS_MINIMIZED )
                           ENDIF*/
                           _HideMonitor()
                        ENDIF
                        HB_mutexUnLock(hmtx_busy)
                     ELSE
                        Debug("intern")
                     ENDIF
                  ENDIF
                  //MBaseRun(Path("run\phone"),{})
               ELSE
                  Debug("Inbound")
               ENDIF    
            ELSE
               Debug("timeout")        
            ENDIF
         ELSE
            //IF lD; ?? "."; ENDIF
         ENDIF
         IF  lUsersPolled .AND. nHandle == 0 //Upper(Chr(SInkey(.5))) == "U"         
            //? ValToPrg(
            nHandle := Val(oInno:UserInitialize(hUserList[Tr_Getini(28)])["RETURN"])
            Debug("Handle:",nHandle)
         ENDIF
         nKey := inkey(0.1,128)
         //Debug2a(Str(Seconds()))
         IF Upper(Chr(nKey)) == "T"
            hNumber := FindNumber("038775674541")  
            _ShowInfo(hNumber["ID"])      
            // @ProcessConnection() )
         ELSEIF Upper(Chr(nKey)) == "Q"
            lQuit := .T.
            EXIT
         ELSEIF Upper(Chr(nKey)) == "L"
            Debug2a("test")
         ENDIF
      ENDDO
   ENDDO
   SetMode(nRows,nCols)
   hb_gtInfo( HB_GTI_SPEC, HB_GTS_WNDSTATE, HB_GTS_WS_SETASNORMAL )
   hb_gtInfo( HB_GTI_NOTIFIERBLOCK   , NIL )
   ErrorBlock(bErrOld)
RETURN

FUNCTION _ShowInfo(nContact)
   LOCAL cDir := SubStr(Exename(),0,Rat(HB_OSPATHSEPARATOR(),Exename()))
   WAPI_ShellExecute(NIL,"open",cDir+"start.exe","-F MBaseRun(Path('run\ShowAdrInfo'),{"+LTrim(Str(ku->Nummer))+","+Ltrim(Str(nContact))+"},.F.)")
   _HideMonitor()

   /*SetMode(48,90)
   CLS
   MBaseRun(Path("trd_02","MASK"),{nContact})*/ 
   
   /*hb_threadStart(HB_THREAD_INHERIT_MEMVARS, {|nNr,nContact| 
            LOCAL oWin := TrWindow():New()
               NetUse("engkund","ku")
               ku->(dbSetOrder( 8 ))
               ku->(dbSeek( Str(nNr,6) ))
               SetMode(48,90)
               CLS
               oWin:optimiseSize()
               MBaseRun(Path("trd_02","MASK"),{nContact,oWin}) 
               oWin:Destroy()
               RETURN NIL           
            },ku->Nummer,nContact ) */
RETURN NIL

STATIC FUNCTION _HideMonitor
   LOCAL nX,nR
   MEMVAR c_one
   GetMainWindow():Hide()
   IF ! lD
      SetColor(c_one)
      SetMode(30,30)
      @ 00,00 CLEAR
      nR := 00
      FOR nX := Len(saHistory) TO 1 STEP -1
         @ nR++,00 SAY saHistory[nX]["TIME"]+" "+saHistory[nX]["NO"]
         IF ! Empty(saHistory[nX]["FIRM"]) 
            @ nR++,09 SAY saHistory[nX]["FIRM"]
         ELSE
            @ nR++,09 SAY "nicht gefunden"
         ENDIF
         IF ! Empty(saHistory[nX]["PERSON"])
            @ nR++,09 SAY saHistory[nX]["PERSON"]
         ENDIF         
      NEXT      
   ENDIF
   HB_GTINFO(HB_GTI_SPEC,HB_GTS_SYSTRAYICON,{0,HB_GTS_NIT_FILE,"y:\harbour\trader\source\engelking_systray.ico","Trader CTI"})
   hb_gtInfo( HB_GTI_SPEC, HB_GTS_WNDSTATE, HB_GTS_WS_SETASNORMAL )
RETURN NIL

STATIC FUNCTION FindNumber(cPhone)
   LOCAL aRet := {"FIRM"=>"","PERSON"=>"","ID"=>0}
   LOCAL lFound := .F.,nX,hContact

   pbk->(dbSetOrder(1))
   cPhone := NormalizeTelno(cPhone)
   Debug(cPhone)
   IF pbk->(dbSeek( cPhone ))      
      Debug("found")
      lFound := .T.
   ELSE //number not found, we will attempt finding the main number
      Debug("searching for number without extensions")
      FOR nX := 1 TO 4 //max 4 digit extension
         cPhone := SubStr(cPhone,1,Len(cPhone)-IF(nX==1,1,2))+"0"
         Debug(cPhone)
         IF pbk->(dbSeek( cPhone ))
            lFound := .T.
            EXIT
         ENDIF
      NEXT
   ENDIF
   IF lFound
      NetUse("engkund","ku")
      ku->(dbSetOrder(8))
      ku->(dbSeek(str(pbk->Address,6)))         
      aRet["FIRM"] := ku->Name1
      IF pbk->Contact != 0
         hContact := GetContact(pbk->contact)
         aRet["PERSON"] := hContact["name"]
         aRet["ID"] := pbk->contact
      ENDIF
   ENDIF
RETURN aRet 

/*STATIC FUNCTION FindNumber(cNumber)
   LOCAL cPhone,cPhoneShort,cFilter
   LOCAL hContact
   IF AT("0",cNumber) != 1 //using this for testing         
      cPhoneShort := "074649865"
      cPhone := cPhoneShort+cNumber
   ELSE
      cPhone := SubStr(cNumber,2) //strip first zero 
      cPhoneShort := SubStr(cPhone,1,Len(cPhone)-2) //leave last two digits off
   ENDIF
   NetUse("engkund","ku")
   NetUse("contacts","conts")
   cFilter := 'StrTran(StrTran(StrTran(StrTran(telephone,"+","00"),"-",""),"/","")," ","")=="'+cPhone+'" .AND. active==0'
   conts->(dbSetFilter({|| conts->(&(cFilter)) },cFilter))
   conts->(dbGoTop())
   IF ! conts->(EOF())
      ku->(dbSetOrder(8))
      ku->(dbSeek(Str(conts->Address,6)))
      RETURN  {"FIRM"=>ku->Name1,"PERSON"=>hContact["name"]}
   ENDIF
   conts->(dbClearFilter())
   ku->(dbSetOrder(2))
   cFilter := 'At("'+cPhoneShort+'",StrTran(StrTran(StrTran(StrTran(Telefon,"+","00"),"-",""),"/","")," ","")) != 0'
   ku->(dbSetFilter({|| ku->(&(cFilter)) },cFilter))
   ku->(dbGoTop())
   DO WHILE ! ku->(EOF())
      IF Trim(_NormNumber(ku->Telefon)) == cPhone //main phone number of customer
         //_ShowInfo()    
         RETURN {"FIRM"=>ku->Name1,"PERSON"=>"","ID"=>0}
      ELSE //we need to go through the contacts
         FOR EACH hContact IN GetAddressContacts(,.T.)               
            IF _NormNumber(hContact["fullphone"]) == cPhone                  
               //_ShowInfo(hContact:__eNumKey())
               RETURN  {"FIRM"=>ku->Name1,"PERSON"=>hContact["name"],"ID"=>hContact["id"]}
            ENDIF
         NEXT
      ENDIF
      ku->(dbSkip())
   ENDDO 
   //still not found, now search the contacts directly
RETURN {"FIRM"=>"","PERSON"=>"","ID"=>0}*/

//STATIC Function _NormNumber(cNumber)
//RETURN StrTran(StrTran(StrTran(StrTran(StrTran(cNumber,"+","00"),"-",""),"/","")," ",""),"0049","0")

STATIC Function Debug(...)
   LOCAL nCol := MaxCol()/2
   LOCAL nMaxRow := MaxRow()/2
   LOCAL xData
   MEMVAR hmtx_busy

   /*FOR EACH xData IN HB_AParams()
      IF xData:__eNumIndex() > 1
         ?? " "
      ENDIF
      ?? xData
   NEXT

   DO WHILE Len(aDebug) >= nMaxRow
      HB_Adel(aDebug,1,.T.)
   ENDDO*/

   IF lD
      HB_mutexLock(hmtx_busy)
      IF nR > nMaxRow
         Scroll(00,nCol,nMaxRow,MaxCol(),1)
         nR := nMaxRow
      ENDIF
      SetPos(nR,MaxCol()/2)
      FOR EACH xData IN HB_AParams()
         IF xData:__eNumIndex() > 1
            ?? " "
         ENDIF
         ?? xData
      NEXT
      nR++ 
      HB_mutexUnLock(hmtx_busy)     
   ENDIF
RETURN NIL

STATIC Function Debug2(aData,nCol)
   LOCAL nMaxRow := MaxRow()
   LOCAL xData
   LOCAL lArray := ValType(aData) == "A"
   MEMVAR hmtx_busy
   Default(@nCol,00)
   IF lD
      HB_mutexLock(hmtx_busy)
      IF nR2 > nMaxRow
         Scroll(MaxRow()/2+1,00,nMaxRow,MaxCol(),1)
         nR := nMaxRow
      ENDIF
      SetPos(nR2,nCol)
      FOR EACH xData IN aData
         IF xData:__eNumIndex() > 1
            ?? ","
         ENDIF
         ?? IF(lArray,Ltrim(Str(xData:__eNumIndex())),xData:__eNumKey())+": "
         IF ValType(xData) $ "AH"         
            nR2 := Row()+1
            Debug2(xData,nCol+2)
            SetPos(nR2,nCol) //set position to front of row
         ELSE
            ?? xData
         ENDIF      
      NEXT
      nR2 := Row()+1 
      HB_mutexUnLock(hmtx_busy)     
   ENDIF
RETURN NIL

STATIC Function Debug2a(cData,nCol)
   LOCAL nMaxRow := MaxRow()
   MEMVAR hmtx_busy
   Default(@nCol,00)
   IF lD
      HB_mutexLock(hmtx_busy)
      IF nR2 > nMaxRow
         Scroll(MaxRow()/2+1,00,nMaxRow,MaxCol(),1)
         nR := nMaxRow
      ENDIF
      SetPos(nR2,nCol)
      ?? cData
      nR2 := Row()+1 
      HB_mutexUnLock(hmtx_busy)     
   ENDIF
RETURN NIL