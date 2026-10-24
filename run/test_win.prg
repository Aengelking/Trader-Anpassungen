#include 'y:\hb32\include\hbthread.ch'
#include "hbgtinfo.ch"
#include "hbgtwvg.ch"
#include "wvtwin.ch"

PROC RUN_TEST_WIN   
   LOCAL nChoice,cKey
   LOCAL pGT
   MEMVAR  hWin
   PUBLIC hWin  
   IF ValType(hWin)  != "H"
      HWin := {;
         "Artikel"=>{"EXEC"=>{"BrowseArtikel"},"WIN"=>NIl},;
         "Adressen"=>{"EXEC"=>{"EnAddr"},"WIN"=>NIl},;
         "Auftrag 56696"=>{"EXEC"=>{"EngAuft",56696},"WIN"=>NIL},;
         "Artikel PX0587"=>{"EXEC"=>{"BrowseArtikel","PX0587"},"WIN"=>NIl};
      }
   ENDIF

/*aPP := Array(HB_GTI_PP_SIZE)
	aPP[HB_GTI_PP_STYLE] := (WS_CLIPCHILDREN + WS_CAPTION + WS_SYSMENU + WS_SIZEBOX + WS_MINIMIZEBOX + WS_MAXIMIZEBOX)
//	aPP[HB_GTI_PP_WNDTYPE] := HB_WNDTYPE_DIALOG
   HB_GTINFO(HB_GTI_PRESPARAMS,aPP)
   HB_GTInfo( HB_GTI_CLOSABLE, .T. )*/
   DO WHILE .T.
      SetColor(c_five)
      nChoice := AMenu(HGetKeys(hWin))
      IF nChoice == 0
         RETURN
      ENDIF
      //Alert(Str(Len(aWin)))
      cKey := HGetKeyAt(hWin,nChoice)
      IF hWin[cKey]:Win != NIL
         IF Len(hWin[cKey]:Exec) > 1
            pGt := HB_GTSELECT( hWin[cKey]:Win:pGT )
            __KeyBoard(hWin[cKey]:Exec[2])
            HB_GTSELECT( pGT )
         ENDIF
         //aWin[1]:Show()
         WVG_ShowWindow( hWin[cKey]:Win:nWnd, SW_NORMAL )
         WVG_SetForegroundWindow(hWin[cKey]:Win:nWnd)        
      ELSE
         
      

         hb_threadStart(HB_THREAD_INHERIT_MEMVARS, {|cKey,aExec|
            LOCAL oWin := TrWindow():New()
            
            ErrorBlock({|e| ErrorHandler(e) })
            BEGIN SEQUENCE
            SetMode(48,80)
            oWin:OptimiseSize()
            oWin:setTitle("Trader - "+cKey)

            hWin[cKey]:Win := oWin   

            
            /*oErr := ErrorNew()
            oErr:SubSystem   := "TEST"
            oErr:Description := "Testting error catching"
            //oErr:Args        := {cUrl,cData}
            Throw(oErr)*/

            //BrowseArtikel()
            hb_ExecFromArray(aExec)

            RECOVER USING error
               //Alert("Here")
            END

            oWin:destroy()
            hWin[cKey]:Win := NIL
            RETURN NIL
         },cKey,hWin[cKey]:Exec)
      ENDIF
   ENDDO



