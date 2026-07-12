#include 'y:\hb32\include\inkey.ch'

PROC MASK_QS

   LOCAL nKey,oButton
   LOCAL aButtons := {},aRegex
   LOCAL cDir

   MEMVAR c_five

   SetColor(c_five)

   Box( 10,05,MaxRow()-1,93,,.T.,1)

   @ 10,06 SAY "[Fehler "+LTrim(Str(qs->Nummer))+"]"

   cDir := "Y:\Dokumente und Einstellungen\All Users\Dokumente\QS\Fehler\"+StrZero(qs->Nummer,4)

   IF IsDir(cDir)
      oButton := HBPushButton():New(11,06,"&Ordner ”ffnen")
      oButton:sBlock := {|| WAPI_ShellExecute(,"open",cDir) }
      Aadd(aButtons,oButton)
   ELSE
      @ 11,06 SAY "Kein Ordner vorhanden "
   ENDIF
   AEval(aButtons,{|x| x:ColorSpec := "N/W,N/W,GR+/RB,R+/W", x:Display() })
   
   nKey := 0
   DO WHILE nKey != 27
      
      nKey := Inkey(0)
      
      IF nKey == 27
         EXIT
      ELSEIF (nKey == K_LBUTTONDOWN .AND. (nB := AScan(aButtons,{|oButton|oButton:HitTest(MRow(),MCol()) != 0})) != 0) .OR.;
         (! Empty(Chr(nKey)) .AND. (nB := AScan(aButtons,{|oButton| aRegex:= HB_Regex("\&([A-Za-zÖÜÄöüä])",oButton:Caption), Len(aRegex) > 0 .AND. Upper(aRegex[2]) == Upper(Chr(nKey))} )) != 0)
         oButton := aButtons[nB]
         oButton:setFocus()
         oButton:select()
         oButton:killFocus()   
      ELSEIF SetKey(nKEY) != NIL
         Eval(SetKey(nKEY),PROCNAME(2),PROCLINE(2),"","")
      ENDIF
   ENDDO
