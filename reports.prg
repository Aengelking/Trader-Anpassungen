#include 'inkey.ch'
LOCAL cDir := Trim(Tr_getini(1))+"\run\reports\"
LOCAL aDir
LOCAL nWidth,cData,aRegex,nX
LOCAL cSearch := ""
LOCAL oBrowse

MEMVAR c_six

aDir := Directory(cDir+"*.prg")

oBrowse := TABrowse():New(10,10,MaxRow()-10,MaxCol()-10)
nWidth := oBrowse:nRight-oBrowse:nLeft+1
oBrowse:aData := {}

FOR nX := 1 TO Len(aDir)
   cData := MemoRead(cDir+aDir[nX,1])
   aRegex := HB_Regex("(?i)HEAD\(.*(["+'"'+"'])(.*)\g1\)",cData)
   IF Len(aRegex) >= 3
      Aadd(oBrowse:aData,{aDir[nX,1],Pad(HB_AnsiToOem(aRegex[3]),nWidth)})
   ELSE
      Aadd(oBrowse:aData,{aDir[nX,1],Pad(aDir[nX,1],nWidth)})
   ENDIF
NEXT

ASort(oBrowse:aData,,,{|x,y| Upper(x[2])<Upper(y[2])} )

oBrowse:colorSpec := c_six

oBrowse:addColumn(TBColumn():New("Name",{||
   LOCAL cData := oBrowse:CurrentDataRow()[2]
   IF cData == NIL
      RETURN Pad("Keine Berichte gefunden",nWidth)
   ENDIF
   RETURN cData
}))

oBrowse:addColumn(TBColumn():New("Datei",{||
   LOCAL cData := oBrowse:CurrentDataRow()[1]
   IF cData == NIL
      RETURN Pad("Keine Berichte gefunden",nWidth)
   ENDIF
   RETURN Pad(cData,nWidth)
}))


oBrowse:AddKey(K_ENTER,{|oBr|
   LOCAL aEnv
   IF oBr:CurrentRow() > 0
      IF oBrowse:colPos == 1
         aEnv := SaveEnv()
         MBaseRun(cDir+oBrowse:CurrentDataRow()[1])
         RestEnv(aEnv,.T.)
      ELSE
         WAPI_ShellExecute(,"open",cDir+oBrowse:CurrentDataRow()[1])
      ENDIF
   ENDIF
   RETURN .T.
})

oBrowse:AddKey(K_ESC,{|| .F. })

/*oBrowse:bRestFun := {|x,aKeys|
   LOCAL nKey,cKey

   FOR EACH nKey IN aKeys
      IF nKey == K_BS .AND. Len(cSearch) >= 1
         cSearch := Left(cSearch,Len(cSearch)-1)
         @ oBrowse:nBottom+1,oBrowse:nLeft+1+Len(cSearch) SAY Chr(205) COLOR oBrowse:colorspec
      ELSEIF Len(cSearch) < nWidth .AND. (cKey := hb_keyChar(nKey)) != "" // >= 32 .AND. nKey <= 126
         cSearch += Upper(cKey)
      ENDIF
   NEXT
   IF Empty(cSearch)
      oBrowse:forBlock := {|| .T. }
   ELSE
      oBrowse:forBlock := {|| 
//          @ MaxRow(),00 SAY oBrowse:CurrentRow()
//          ? oBrowse:CurrentRow()
         IF oBrowse:CurrentDataRow() == NIL
            RETURN .F.
         ENDIF
         RETURN oBrowse:CurrentRow() != 0 .AND. AT(cSearch,Upper(oBrowse:CurrentDataRow()[1])) != 0
      }
      oBrowse:forceStable()
      @ oBrowse:nBottom+1,oBrowse:nLeft+1 SAY cSearch COLOR ColorSelect(1)

   ENDIF
   RETURN .T.
} */

oBrowse:EventLoop()
