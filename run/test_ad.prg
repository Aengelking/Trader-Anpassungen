//ns := GetActiveObject("LDAP://DC=engelking,DC=local")
CLS

IF Empty(GetEnv("USERDNSDOMAIN"))
   TR_MsgBox("Not in a domain")
ENDIF

aDC := HB_ATokey(GetEnv("USERDNSDOMAIN"),".")

oConn := CreateObject("ADODB.Connection")
oCommand1 := CreateObject("ADODB.Command")

//Open the connection.
oConn:Provider := "ADsDSOObject"  //This is the ADSI OLE-DB provider name
oConn:Open("Active Directory Provider")
//Create a command object for this connection.
oCommand1:ActiveConnection := oConn

//Compose a search string.
oCommand1:CommandText := "select name,telephoneNumber "+;
"from 'LDAP://DC=engelking,DC=local'" +;
"WHERE objectCategory='Person'" +;
"AND objectClass='user'" /*+;
"AND title='Program Manager'" +;
"AND department=101"*/

//Execute the query.
rs := oCommand1:Execute

//Navigate the record set

DO WHILE ! rs:EOF()
    ? rs:Fields("Name"):Value
    // + " , " + rs:Fields("telephoneNumber")
    rs:MoveNext()
ENDDO

Inkey(0,128)