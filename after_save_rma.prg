FUNCTION HOOK_AFTER_SAVE_RMA(oRma,lNew)
   IF (lNew .OR. oRma:FieldUpdatedLastSave("GRUND") .OR. oRma:FieldUpdated("GRUND")) .AND. Trim(oRMA:Grund) == "DEF" //new rma
      //SendMail({{"amos.engelking@engelking.de","Amos"}},"Neue RMA "+LTrim(Str(oRma:Nummer)))
   ENDIF
RETURN NIL