#include 'hbgtinfo.ch'
#include 'inkey.ch'
LOCAL nRows := MaxRow()+1
LOCAL nCols := MaxCol()+1
LOCAL nWidth := 20
LOCAL nHeight := 10
LOCAL aPos :=  HB_GTINFO(HB_GTI_SETPOS_XY)
LOCAL bClose
NetUse("engkund","ku")
SetMode(nHeight,nWidth)
SetColor(c_five)
CLS
HB_GTINFO(HB_GTI_SETPOS_ROWCOL,HB_GTINFO(HB_GTI_DESKTOPROWS)-nHeight-4,HB_GTINFO(HB_GTI_DESKTOPCOLS)-nWidth)
HB_GTINFO(HB_GTI_RESIZABLE,.F.)

oWnd := GetMainWindow()
bClose := oWnd:bClose

oWnd:bClose := {|| Alert("close") }
oWnd:Show()

? Str(HB_GTINFO(HB_GTI_DESKTOPROWS),3)
? Str(HB_GTINFO(HB_GTI_DESKTOPCOLS),3),Str(HB_GTINFO(HB_GTI_SCREENWIDTH),3),Str(HB_GTINFO(HB_GTI_DESKTOPWIDTH),4)
//   HB_GTI_DESKTOPWIDTH
aPos :=  HB_GTINFO(HB_GTI_SETPOS_XY)
nL := aPos[1]
nT := aPos[2]
DO WHILE (nKey := Inkey(0)) != K_ESC
   IF nKey == K_LEFT
      nL -= 10
      HB_GTINFO(HB_GTI_SETPOS_XY,nL,nT)
   ELSEIF nKey == K_RIGHT
      nL += 10
      HB_GTINFO(HB_GTI_SETPOS_XY,nL,nT)
   ENDIF
   IF nKey == K_LBUTTONDOWN
      ku->(dbseek(Pad("FP")+"K"))
      DispInfo("trd_02")
   ENDIF
ENDDO

HB_GTINFO(HB_GTI_RESIZABLE,.T.)
oWnd:bClose := bClose
//oWnd:Hide()
SetMode(nRows,nCols)