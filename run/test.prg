ku->(E:=ExtraData():New(Nummer))
IF(E:PrintManu.AND.art->Manufactur!=8,Eval({||NetUse("manufact","man"),man->(dbSeek(Str(art->Manufactur,5))),Trim(frm->Text2),StrTran(Trim(man->Short),"CHINA")}),"")