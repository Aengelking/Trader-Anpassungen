
NetUse("rechpos","rpos")
rpos->(dbSetOrder( 2 ))

NetUse("engbes","bes")
CLS

DO WHILE ! bes->(EOF())
    IF rpos->(dbSeek( Str(bes->besnr,6)+Str(bes->posnr,3) ))
        nQty := 0
        DO WHILE rpos->besnr == bes->besnr .AND. rpos->posnr == bes->posnr
            nQty += rpos->Menge
            rpos->(dbSkip())
        ENDDO
        IF bes->gelqty-nQty != bes->zoQty
            ? bes->besnr,bes->posnr,bes->gelqty,nQty,bes->zoQty
/*            bes->(Rec_Lock())
            bes->ZoQty := bes->gelqty-nQty
            bes->(dbUnLock())*/
        ENDIF
    ENDIF
    bes->(dbSkip())
ENDDO

Inkey(0)
