PARAMETERS nRechnr

LOCAL oBrowse

MEMVAR c_five

NetUse("englsre","re")
NetUse("batchnos","bat")

re->(dbSetOrder(4))
re->(dbSeek( Str(nRechnr,6) ))
DO WHILE (re->reposnr == 0 .OR. re->AoQty == 0) .AND. ! re->(EOF()) //skip header and empty positions at top
   re->(dbSkip())
ENDDO

oBrowse := re->(TBrowseTr():New(15,00,MaxRow(),79))
oBrowse:lBox := .T.
oBrowse:ColorSpec := c_five
oBrowse:MultipleRows := .T.
oBrowse:NewColumn("Pos "+Pad("Artikel",25)+Pad(" Menge",13),{||
   RETURN Transform(re->reposnr,"999")+" "+re->Matchcode+" "+Pad(Transform(re->aoqty,me(re->me)),12)
})

oBrowse:bCountBlock := {||
   LOCAL cKey := Str(re->RePosnr,3]+Str(re->Reposnr,3)+Str(re->AbNr,6)
   IF HHasKey(hBatchNos,cKey)
      RETURN bat->(LETO_Count(cKey,cKey))
      //RETURN Len(hBatchNos[cKey])+1
   ENDIF
   RETURN 1
}



oBrowse:WhileBlock := {|| re->rechnr = nRechnr .AND. ! re->reposnr == 0 }
oBrowse:cFor       := "aoqty != 0"
oBrowse:ForBlock   := {|| re->(&(oBrowse:cFor)) }
oBrowse:AddKey(27,{|| .F. })
//oBrowse:AddKey(13,{|| ReEdit(oRechnung,@re_print) })

oBrowse:EventLoop()

