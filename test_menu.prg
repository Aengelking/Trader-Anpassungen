#include 'y:\hb32\include\hbthread.ch'
#include "hbgtwvg.ch"
#include "wvtwin.ch"
FUNCTION BuildMainMenu()

   LOCAL oMenu
   LOCAL g_oMenuBar := WvgSetAppWindow():menuBar()

   MEMVAR hWin
    

   LOCAL bStart := {|cKey|   
      LOCAL pGT
      
      IF hWin[cKey]:Win != NIL
         IF Len(hWin[cKey]:Exec) > 1
            pGt := HB_GTSELECT( hWin[cKey]:Win:pGT )
            __KeyBoard(hWin[cKey]:Exec[2])
            HB_GTSELECT( pGT )
         ENDIF      
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
               CLS
               
               hWin[cKey]:Win := oWin   
               
               hb_ExecFromArray(aExec)

               RECOVER USING error
                  //we need this so the thread does not crash
               END

               oWin:destroy()
               hWin[cKey]:Win := NIL
               RETURN NIL
         },cKey,hWin[cKey]:Exec)
      ENDIF
   RETURN NIL
   }

   PUBLIC hWin

   hWin := {;
         "Artikel"=>{"EXEC"=>{"BrowseArtikel"},"WIN"=>NIl},;
         "Adressen"=>{"EXEC"=>{"EnAddr"},"WIN"=>NIl};
   }

   g_oMenuBar:delAllItems()

   oMenu := WvgMenu():new( g_oMenuBar, , .T. ):create()
   oMenu:Caption := "Stammdaten"
   oMenu:AddItem( "Adressem"       , {|| Eval(bStart,"Adressen") } )
   oMenu:AddItem( "Artikel", {|| Eval(bStart,"Artikel") } )
   /*oMenu:AddItem( "-" )
   oMenu:AddItem( "Dialog Two"                  , {|| Alert("test")      } )
   oMenu:AddItem( "-" )
   oMenu:AddItem( "Exit"                        , {|| __Keyboard( K_ESC ) } )*/
   g_oMenuBar:addItem( { oMenu, "Stammdaten" } )

RETURN NIL    
   
      
   

