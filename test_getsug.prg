LOCAL cTest := Space(50)
LOCAL cTest2 := Space(50)

SetColor(c_four)
Head("Testing new get field")

oGet := GetSuggestions():New( 01, 01, {|v| IF(v!=NIL,cTest:=v,cTest) }) //,,"@S20" )
oGet:aValues := {"Hello World","Hello Banana","Hello Sam","Hello Opa"}
oGet:Display()
Aadd(getlist,oGet)

oGet := GetSuggestions():New( 02, 01, {|v| IF(v!=NIL,cTest2:=v,cTest2)},,"@S20" )
oGet:aValues := {"Hello World","Hello Banana","Hello Sam","Hello Opa"}
oGet:Display()
Aadd(getlist,oGet)

//@ 02,01 GET cTest PICTURE "@S20"

READ