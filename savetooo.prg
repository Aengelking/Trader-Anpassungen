FUNCTION RUN_TestSaveOO()
   SaveToOO("Y:\Dokumente und Einstellungen\amos\Documents\amos.xlsx",{;
      "FIRST"=>{{"TEXT","NUMERIC","DATE","TIME","BOOLEAN"},{"DATA ONE",1,Date()-1,DateTime(),.T.},{"DATA TWO",2,Date(),DateTime(),.F.},{"DATA THREE","=SUM(B2:B3)","=C3-C2"}},;
      "SECOND"=>{};
   })
   
RETURN NIL
