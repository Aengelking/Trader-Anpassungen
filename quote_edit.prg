#include 'inkey.ch'

PROC RUN_QUOTE_EDIT
   LOCAL cLief := Pad("SELT",8) //Space(8)
   LOCAL cAngnr := Pad("SELT-PRT020920_revA",50) //Space(50)
   LOCAL getlist := {}
   LOCAL oTabs,oBrowse,oBrowse2

   NetUse("engkund","ku")
   NetUse( "buyprice", "bpr" )
   NetUse("artikel","art")
   NetUse("artlief","ali")
   

   Head("Einkaufsangebot")
   @ 01,00 SAY "Lieferant" GET cLief PICTURE "@!" VALID Findad( cLief, "L", 01, 67 )
   @ 02,00 SAY "Angebot  " GET cAngnr VALID {||
      bpr->(dbSetOrder(4))
      RETURN bpr->(dbSeek( cLief+Pad("QUOTE",10)+cAngnr ))
   }
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   oTabs := GetTabs():New(11,00,MaxRow(),MaxCol())

   oBrowse := bpr->(TBrowseTr():New(13,01,MaxRow()-2,89))
   oBrowse:ColorSpec := c_one
   oBrowse:lBox := .F.
   oBrowse:MultipleRows := .T.

   oBrowse:NewColumn(Pad("Artikel",25)+" "+Pad("Menge",12)+" "+Pad("Preis",12),{|| 
      art->(dbSetOrder( 2 ))
      art->(dbSeek( Str(bpr->Artikelnr,6) ))
      RETURN Pad(art->Matchcode+Pad(Transform(bpr->Qty,Me(art->Me)),12)+Str(bpr->Price,12,2),88)
   },{|| {2,5} })

   oBrowse:WhileBlock := {|| bpr->Liefma == cLief .AND. Trim(bpr->Type) == "QUOTE" .AND. bpr->Number == cAngnr }
   oBrowse:AddKey(K_ESC,{|| .F. })
   oBrowse:AddKey(K_ENTER,{|| 
      ali->(dbSetOrder( 1 ))
      ali->(dbSeek( cLief+Str(bpr->Artikelnr,6) ))
      RETURN EditPrice(.F.,cLief,"ali",cAngnr) 
   })
   oBrowse:AddKey(K_INS,{|| 
      ali->(dbSetOrder( 1 ))
      ali->(dbSeek( cLief+Str(bpr->Artikelnr,6) ))
      RETURN EditPrice(.T.,cLief,"ali",cAngnr) 
   })

   oTabs:AddTab(t("Positionen"),oBrowse)

   oBrowse2 := ArchBrowse():New(13,01,MaxRow()-1,MaxCol()-2,{}) //"QUOTE"=>0
   oBrowse2:lBox := .F.
   oBrowse2:Display()
   oBrowse2:deHilite()

   oTabs:AddTab("Dokumente",oBrowse2)


   oTabs:Modal()