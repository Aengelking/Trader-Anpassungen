FUNC Test_External_Func
   LoadPrg("x:\www\api\beta\approval")
   Alert(Type("API_GET_Approval_Info()"))
   UnLoadPrg("x:\www\api\beta\approval")
   Alert(Type("API_GET_Approval_Info()"))
   