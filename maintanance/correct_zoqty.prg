NetUSe("engbes","bes")
//bes->(dbSetOrder( ))
bes->(dbSetFilter({|| bes->ZoQty < 0 .AND. bes->BeQty > 0 }))

NetUse("rechpos","rpos")
rpos->(dbSetOrder( 2 ))

DO WHILE ! bes->(EOF())
   rpos->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
   nMenge := 0
   DO WHILE rpos->Besnr == bes->Besnr .AND. rpos->Posnr == bes->Posnr
      nMenge += rpos->Menge
      rpos->(dbSkip())
   ENDDO
   IF bes->ZoQty != bes->GelQty-nMenge
      ? bes->Besnr,bes->Posnr,bes->Matchcode,bes->BeQty,bes->ZoQty,bes->GelQty-nMenge
      bes->(Rec_Lock())
      bes->ZoQty := bes->GelQty-nMenge
      bes->(dbUnLock())
   ENDIF
   bes->(dbSkip())
ENDDO

bes->(dbClearFilter())

Inkey(0,128)