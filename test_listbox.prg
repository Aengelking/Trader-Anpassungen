PROC TEST_LISTBOX
   LOCAL getlist := {}
   LOCAL nNum := 1
   LOCAL cText := "Hello"

   CLS
   @ 01,00,10,25 GET nNum LISTBOX {"Hello","World"} DROPDOWN WHEN {|| Alert("here"),.F.}
   @ 02,00 GET cText 
   READ

   