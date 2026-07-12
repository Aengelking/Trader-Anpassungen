NetUse("engkund","ku",.F.,0)
//NetUse("artkund","aku",.F.,0)
NetUse("engauf","auf",.F.,0)
SetColor( c_five )
DISPBEGIN()
DispBox( 24, 00, 42, 79, "ÃÄ´³ÙÄÀ³ " )
DispBox( 25, 34, 41, 34, 1 )  // Strich in der Mitte
DispBox( 25, 57, 26, 57, 1)

notiz := .T.
*dbSELECTAREA("ART")

@ 24,02 SAY IF(art->Sperren .OR. art->Inventur,"GESPERRT","") COLOR "W+*"

*@ 08,07 SAY "Wareneingang : "+Transform(art->Weqty,Me(art->Me))+"  "+art->me
*@ 09,07 SAY "Gesperrt     : "+Transform(art->Gesperrt,Me(art->me))+"  "+art->me

@ 25,02 SAY msb[26] + STR( ART->ekqty,6,0 )
@ 26,02 SAY msb[27] + STR( ART->vkqty,6,0 )
@ 27,02 SAY msb[28] + STR( ART->letzte_ek,8,2 ) + " "+Currate(art->Money,"X")+" / "+LTrim(Str(art->pe))
@ 28,02 SAY Space(15)+Str(art->letzte_ek*Currate(art->Money,"E")/Currate("E","E"),8,2)+" "+Currate("E","X")+" / "+LTrim(Str(art->pe))
@ 29,02 SAY msb[29] + STR( ART->letzte_vk/Currate("E","V"),8,2 )+" "+Currate("E","X") + " / " + LTrim(STR( ART->vkpe ))
@ 30,02 SAY Space(15) + STR( ART->letzte_vk/Currate("D","V"),8,2 )+" "+Currate("D","X") + " / " + LTrim(STR( ART->vkpe ))

@ 31,02 SAY If(art->Gruppe=="DIBL","Preisbasis   :",msb[30]) + STR( ART->vkpreis2 )+If(art->Gruppe=="DIBL"," "+Currate(art->Money,"X"),"")  + " / " + STR( ART->vkpe )
@ 32,02 SAY "Zuschlag     : "+Str(Zuschlag(1,Bas_Zuschlag()),8,2)+" / "+art->Me
@ 33,02 SAY msb[31] + STR( ART->avpreis )
@ 34,02 SAY msb[32] + "  " + STR( ART->mindest,6,0 )
@ 35,02 SAY msb[34] + "   " + STR( ART->gemko )
@ 36,02 SAY msb[36] + STR( ART->bedarf )
@ 37,02 SAY msb[37] + "      " + STR( ART->lz )
@ 38,02 SAY msb[38] + SPACE( 1 ) + STR( ART->basis )
*@ 08,44 SAY msb[39] + ART->zeichnung
@ 39,02 SAY Pad("Gewicht",13)+":" + Str(ART->gewicht)
@ 40,02 SAY msb[41] + SPACE( 1 ) + STR( ART->vpe )
@ 41,02 SAY Pad("Gruppe",13)+":" + " " + ART->gruppe

@ 25,36 SAY msb[43] + SPACE( 3 ) + STR( ART->rabatt )
@ 26,36 SAY msb[44] + SPACE( 7 ) + STR( ART->bezug )

@ 25,59 SAY msb[40] + Space( 1 ) + STR( ART->textkey )
@ 26,59 SAY msb[42] + STR( ART->netprice )


nLetzte := if(! EMPTY( art->table ),art->(Prices(27,35)),0)
KuData(35,35,41,nLetzte)

DISPEND()
*SET KEY 32 TO OPTFILE
*SKeyKey(0)
*SET KEY 32 TO
