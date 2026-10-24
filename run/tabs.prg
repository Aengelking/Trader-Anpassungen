

getlist := {}

SetColor(c_four)
@ 03,03 CLEAR TO 20,70
TR_Box(03,03,20,70)

//@ 04,04 SAY "Adresse" COLOR ColorSelect(1)
//@ 04,12 SAY "Adresse" COLOR ColorSelect(1)

oMenu := TopBarMenu():new( 04, 04, 69 )
oMenu:colorSpec := c_four
oItem := MenuItem():new("|Adresse|",{|| .T.  })
oMenu:addItem(oItem)

oItem2 := MenuItem():new("|Kontaktpersonen|",{|| .T. })
oMenu:addItem(oItem2)


oMenu:select(1)
oMenu:Display()

DispBox(05,05,19,69,1)
@ 05,05 SAY Chr(179)
@ 05,06 SAY Space(7)
@ 05,13 SAY Chr(192)

oGet := Get():New(06,06,{|| "Hello World" })

Aadd(getlist,oGet)

ReadModal(getlist,,oMenu)

Inkey(0,128)
