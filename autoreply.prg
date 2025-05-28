
#ifndef __XHARBOUR__
	#xtranslate ThreadSleep( <x> )              => hb_idleSleep( <x> / 1000 )
#endif



PROCEDURE HRBMAIN

   LOCAL getlist := {}   
   LOCAL oItem,nVertret,oCond
   LOCAL dFrom,hBuyer,oGet,cPerson   
   LOCAL nX
   LOCAL oAutoReply := DavidAutoReply():new()

   MEMVAR c_four_list,c_one_list

   Head("Out of Office Autoreply")

   NETUSE( "buyer","buy",.F.,0 )

   nVertret  := 1

   If oAutoReply:lIsActive .AND. Tr_MsgBox(t("Autoreply bereits aktiv"),,{t("deaktivieren"),t("ändern")}) != 2
      If LastKey() == 27
         Return
      Endif
      
      oAutoReply:Disable()
      Return
   Endif

   hBuyer := {0=>t("Keinen")}

   buy->(dbGoTop())
   Do While ! buy->(Eof())
      If buy->Aktive .AND. ! Empty(buy->Email) .AND. buy->(Recno()) != Tr_Getini(28)
         hBuyer[buy->(Recno())] := buy->Buyer
         If ! Empty(oAutoReply:oForward:ForwardTo) .AND. Trim(oAutoReply:oForward:ForwardTo) == Trim(buy->Email)
            nVertret := Len(hBuyer)
         Endif
      Endif
      buy->(dbSkip())
   Enddo

   @ 02,00 SAY "Ab"
   @ 02,24 GET oAutoReply:dFrom 

   @ 03,00 SAY "Bis"
   @ 03,24 GET oAutoReply:dUntil VALID oAutoReply:dUntil >= oAutoReply:dFrom

   @ 04,00 SAY "Verteter"
   @ 04,24,15,49 GET nVertret LISTBOX HGetValues(hBuyer) DROPDOWN VALID nVertret >= 1 .AND. nVertret <= Len(hBuyer) COLOR c_four_list
   /*oGet := Get():new(04,24,{|xValue| IIf( xValue==NIL, nVertret, nVertret := xValue ) },"nVertret")
   oGet:colorSpec := c_four_list   
   AAdd(GetList,oGet)
   ATail(GetList):Control := _ListBox_(ATail(Getlist):row,ATail(Getlist):col,15,49,nVertret,HGetValues(hBuyer),,,,,,.T.,.F. )
   ATail(GetList):Control:colorSpec := c_one_list
   ATail(GetList):reader := { | a,b,c,d | GuiReader(a,b,c,d ) }
   ATail(GetList):Control:Display()*/

   @ 05,00 SAY "Emails weiterleiten?"
   @ 05,21 GET oAutoReply:lForward WHEN nVertret != 1

   READ

   If LastKey() == 27
      Return
   Endif

   If nVertret > 1
      oAutoReply:Vertreter := HGetKeyAt(hBuyer,nVertret)      
   Else
      oAutoReply:Vertreter := 0
   Endif


   IF ! oAutoReply:Set()
      Tr_MsgBox("Autoreply konnte NICHT eingerichtet werden")
   ELSE
      Tr_MsgBox(t("Autoreply wurde eingerichtet und aktiviert"))
   ENDIF

RETURN

#include 'autoreply_david.prg'

