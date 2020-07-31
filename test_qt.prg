#include 'y:\hb32_qt\include\hbthread.ch'
#include "y:\hb32_qt\include\hbqtgui.ch"
//#include "y:\hb32\include\hbgtinfo.ch"
STATIC aObjs := {}  //Array containing windows objects, so they stay once the program ends. We clear this array on close

LOCAL oBtn
oWnd := QWidget()
//oWnd:setWindowFlags(Qt_Popup)
oWnd:setWindowTitle( "Trader Rechner" )
oWnd:resize( 300, 200 )

oWnd:connect(QEvent_Close,{|| aBtns := {}, oWnd := NIL })
    Aadd(aObjs,oWnd)

   oBtn := QPushButton( "7", oWnd )
//   oBtn:move( 0, 0 )
   oBtn:show()
   oBtn:connect( "clicked()", {||
         Alert("Hello")
    } )
    Aadd(aObjs,oBtn)


oWnd:show()

/*DO WHILE ! lDone
   QApplication():processEvents( 0 )
ENDDO*/
