PROC HOOK_AFTER_EXPORT_ADDRESS(oBrowse)
   NetUse("exportlog","expl")
   expl->(Add_Rec(0))
   expl->Alias := "KU"
   expl->User  := SystemUser():nRecno
   expl->Data  := ValToPrg({"FILTER"=>oBrowse:cFor,"SCOPETOP"=>oBrowse:xScopeTop,"SCOPEBOTTOM"=>oBrowse:xScopeBottom})
   expl->TimeStamp := TtoS(DateTime())
   expl->(dbUnLock())
   
   //SendMail({{"amos.engelking@engelking.de","Amos"}},"Adressen wurden exportiert",)

RETURN