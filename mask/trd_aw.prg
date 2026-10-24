#include 'y:\hb32\include\inkey.ch'

PROC MASK_AW

   LOCAL nKey,oButton
   LOCAL aButtons := {},aRegex
   LOCAL cDir,aDir
   LOCAL cFile

   MEMVAR c_five

   SetColor(c_five)

   Box( 10,05,MaxRow()-1,93,,.T.,1)

   @ 10,06 SAY "[Arbeitsanweisung "+LTrim(Str(aw->Nummer))+"]"

   //cDir := "Y:\Dokumente und Einstellungen\All Users\Dokumente\Projekte\"
   cFile := Hook("get_drawingfile",{.T.,LTrim(Str(aw->Nummer))},"")

   IF ! Empty(cFile) .AND. File(cFile) //Len(aDir) > 0 
      oButton := HBPushButton():New(11,06,"&Arbeitsanweisung ”ffnen")
      oButton:sBlock := {|| 
         IF AT(".json",cFile) > 0
            WAPI_ShellExecute(,"open","https://db.engelking.de/trader/AAWEditor/viewer.html?file="+LTrim(Str(aw->Nummer)))
         ELSE
            //open the file in the default application                        
            WAPI_ShellExecute(,"open",cFile)
         ENDIF
      }
      Aadd(aButtons,oButton)
   ELSE
      @ 11,06 SAY "Keine Arbeitsanweisung vorhanden"//+cDir+StrZero(aw->Nummer,4)+"*"
   ENDIF
   
   oButton := HBPushButton():New(12,06,"&Arbeitsanweisung "+IF(AT(".json",cFile) > 0,"bearbeiten","erstellen"))
   oButton:sBlock := {|| MBaseRun(PAth("run\aaweditor"),{aw->Nummer}) }
   Aadd(aButtons,oButton)

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
