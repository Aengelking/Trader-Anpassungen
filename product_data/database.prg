/**
 * Database Management Module for Product Data Export
 */

#include "x:\run\product_data\config.prg"

FUNCTION InitializeDatabases()
   NetUse("artikel","art")
   NetUse("artlief","ali")
   NetUse("liefstock","lsto")
   NetUse("buyprice","bpr")
   NetUse("waldom","wald")
   NetUse("manufact","manu")
   NetUse("engkund","ku")
   NetUse("shopware","shop")
   NetUse("ptcache","ptc")
   NetUse("stafprei","stpr")
   NetUse("comprice2","cmp2")
   
   IF Select("bte") != 0
      bte->(dbCloseArea())
   ENDIF
RETURN .T.

FUNCTION GetHolidayData()
   LOCAL hManuHoliday := {=>}
   LOCAL aWaldHoliday := {Date()+1, Date()-1, 0}
   LOCAL oExtra
   
   // Collect Waldom Holiday information
   ku->(dbSeek(Pad("WALDOM",8)+"L"))
   oExtra := ku->(ExtraData():New(ku->Nummer))
   IF ku->En_Holiday >= Date()
      aWaldHoliday[1] := ku->St_Holiday
      aWaldHoliday[2] := ku->En_Holiday
      aWaldHoliday[3] := oExtra:RecvTime
   ENDIF
   
   // Collect Manufacturer Holiday information
   manu->(dbGoTop())
   ku->(dbSetOrder(8))
   DO WHILE ! manu->(EOF())
      IF manu->Principal
         ku->(dbSeek(Str(manu->Address,6)))
         oExtra := ku->(ExtraData():New(ku->Nummer))
         IF ku->En_Holiday >= Date()
            hManuHoliday[manu->ID] := {ku->St_Holiday, ku->En_Holiday, oExtra:RecvTime}
         ENDIF
      ENDIF
      manu->(dbSkip())
   ENDDO
   
RETURN {hManuHoliday, aWaldHoliday}

FUNCTION GetKwStock(nArtikelnr, nWeek, aAvail)
   LOCAL nStock := art->Bestand
   LOCAL nX
   
   For nX := 1 To Len(aAvail)
      If aAvail[nX,1] <= nWeek
         nStock := Min(nStock, aAvail[nX,6])
      Endif
   Next
   
RETURN nStock
