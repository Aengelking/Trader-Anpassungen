#include 'inkey.ch'

FUNC RUN_Test_TBrowse
   LOCAL cKSMatch := "KS17535"
   LOCAL lBox := .F.
   LOCAL cHeadSep := "" //"ÄÂÄ"
   LOCAL lHead := .T.
   LOCAL oArtBrowse

   NetUse("artikel","art")

   art->(dbSetOrder( 1 ))
   art->(dbSeek( cKSMatch ,.T. ))

   CLS

   @ 00,00 SAY "OneColumn"
   oArtBrowse := art->(TBrowseTr():New(01,00,10,40))
   oArtBrowse:OneColumn := .T.
   oArtBrowse:lBox := lBox  
   oArtBrowse:HeadSep := cHeadSep

   oArtBrowse:cFor := "! obsolete"
   oArtBrowse:WhileBlock := {|| AT(Trim(cKSMatch),art->Matchcode) == 1 }

   oArtBrowse:NewColumn("Matchcode",{|| art->Matchcode })
   oArtBrowse:NewColumn("Freigabe",{|| Str(art->Bestand)} )

   oArtBrowse:AddKey(K_ESC,{||.F.})

   oArtBrowse:Display()

   

   @ 00,41 SAY "MultipleRows"
   oArtBrowse2 := art->(TBrowseTr():New(01,41,10,81))
   oArtBrowse2:MultipleRows := .T.
   oArtBrowse2:lBox := lBox  
   oArtBrowse2:HeadSep := cHeadSep

   oArtBrowse2:cFor := "! obsolete"
   oArtBrowse2:WhileBlock := {|| AT(Trim(cKSMatch),art->Matchcode) == 1 }

   oArtBrowse2:NewColumn( IF(lHead,"Matchcode",NIL) ,{|| art->Matchcode })
   oArtBrowse2:NewColumn( IF(lHead,"Freigabe",NIL) ,{|| Str(art->Bestand)} )

   oArtBrowse2:AddKey(K_ESC,{||.F.})

   oArtBrowse2:Display()


   @ 00,41 SAY "SingleColumn"
   oArtBrowse3 := art->(TBrowseTr():New(12,00,22,40))
   oArtBrowse3:lBox := lBox  
   oArtBrowse3:HeadSep := cHeadSep

   oArtBrowse3:cFor := "! obsolete"
   oArtBrowse3:WhileBlock := {|| AT(Trim(cKSMatch),art->Matchcode) == 1 }

   oArtBrowse3:NewColumn( IF(lHead,"Matchcode",NIL) ,{|| art->Matchcode })

   oArtBrowse3:AddKey(K_ESC,{||.F.})

   oArtBrowse3:Display()


   @ 00,41 SAY "TABrowse"
   oBrowse := TABrowse():New(12,41,22,81)
   oBrowse:lBox := lBox  
   oBrowse:HeadSep := cHeadSep

   oBrowse:aData := {"Hello","World","Does","THis","Work"}
   oBrowse:NewColumn( "Head" ,{|| oBrowse:CurrentDataRow() })

   oBrowse:AddKey(K_ESC,{||.F.})

   oBrowse:Display()

   @ 23,41 SAY "TABrowse"
   oBrowse2 := TABrowse():New(24,00,33,41)
   oBrowse2:lBox := lBox  
   oBrowse2:HeadSep := cHeadSep

   oBrowse2:addColumn(TBColumn():New("Test",{|| oBrowse2:CurrentDataRow() }))
   oBrowse2:AddKey(K_ESC,{||.F.})
   oBrowse2:Display()

   oArtBrowse:EventLoop()
   oArtBrowse2:EventLoop()
   oArtBrowse3:EventLoop()
   oBrowse:EventLoop()
   oBrowse2:EventLoop()
