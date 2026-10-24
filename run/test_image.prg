#include "y:\hb32\include\inkey.ch"
#define WVT_BLOCK_IMAGE                           1
LOCAL aPaint := {}
LOCAL nWidth := 20
LOCAL nHeight := 10
LOCAL nKey := 0
LOCAL nPxlH := 0

//CLS


/*DO WHILE nKey != 27
   IF nKey == K_UP .AND. nHeight > 8
      nHeight--
   ELSEIF nKey == K_DOWN
      nHeight++
   ELSEIF nKey == K_LEFT .AND. nWidth > 0
      nWidth--
   ELSEIF nKey == K_RIGHT
      nWidth++
   ELSEIF nKey == K_CTRL_UP
      nPxlH ++
   ENDIF
   @ 1,00 SAY nWidth
   @ 2,00 SAY nHeight
   Wvt_DrawImage( 08,00,nHeight,nWidth, "X:\images\bezahlt.jpg",{0,0,10,nPxlH} )
   nKey := SInkey(0)
ENDDO  */


   aPaint := {}
   Aadd(aPaint,{ "Image" , {||Wvt_DrawImage( 08,00,nHeight,nWidth, "X:\images\bezahlt.jpg" ) } , { WVT_BLOCK_IMAGE,  8, 00, nHeight, nWidth } })
   WvtSetPaint(aPaint)
   Wvt_Paint() 
   DO WHILE SInkey(0) != 27
   ENDDO


WvtSetPaint({})