#include "inkey.ch"

//PROCEDURE Main

  LOCAL oCom, cUrl := Pad( "www.github.com", 95 ), GetList := {} 

  SetMode(40,100) 
  CLS

    oCom := WvgActiveXControl():New( wvgSetAppWindow(), , { 300, 0 }, { 800, 600 }, , .T. )
    oCom:CLSID := "Shell.Explorer.2"
    oCom:create()

  DO WHILE .T.
    //@ 0, 0 GET cUrl PICTURE "@KX"
    //READ
    ? Inkey(0)
    IF LastKey() == K_ESC
     EXIT
    ELSEIF Upper(Chr(LastKey())) == "L" .AND. HB_ISOBJECT( oCom )
     oCom:Navigate( Trim( cUrl ) )
    ENDIF

//    oCom:setPosAndSize( { 300, 0 }, { 800, 600 }, .T. )

  ENDDO
  oCom:Destroy()
  RETURN