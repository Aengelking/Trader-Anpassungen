LOCAL oIE := CreateObject("InternetExplorer.Application")
LOCAL cViewState,cViewStateGenerator,aRegex
oIE:Navigate ("about:blank")


oLogin1 := TIpClientHttp():new("http://www.waldomemea.com/loginpopup.aspx")

IF oLogin1:open()
       /*SMLoginPopup:UPLoginPopup|PopupLoginForm$PopupLoginButton
__LASTFOCUS:
__EVENTTARGET:PopupLoginForm$PopupLoginButton
__EVENTARGUMENT:
__VIEWSTATE:/wEPaA8FDzhkM2IxNmY5MDQ5MjQ3ZWQA/Dd6OxLMGfZLewNjFZYx8xwnkw==
__VIEWSTATEGENERATOR:67DAE5C8
poploggedin:0
hdnUrl:
PopupLoginForm$UserName:Engelking1
PopupLoginForm$Password:6wTKm3
__ASYNCPOST:true   */
   cData := oLogin1:ReadAll()

   aRegex := HB_regex('__VIEWSTATE.*value="([^"]*)',cData)
   IF Len(aRegex) != 0
      cViewState := aRegex[2]
   ELSE
      Alert("No ViewState found")
      RETURN
   ENDIF
   aRegex := HB_regex('__VIEWSTATEGENERATOR.*value="([^"]*)',cData)
   IF Len(aRegex) != 0
      cViewStateGenerator := aRegex[2]
   ELSE
      Alert("No ViewStateGenerator found")
      RETURN
   ENDIF

   //Alert(cViewState+";"+cViewStateGenerator)
   oLogin := TIpClientHttp():new("http://www.waldomemea.com/loginpopup.aspx")
   oLogin:open()
   
   hCookies := HGetValueAt(HGetValueAt(oLogin1:hCookies,1),1)
   Alert(ValToPrg(oLogin1:hCookies))
   cValue := ""
   FOR EACH cValue IN hCookies
      Alert(cValue:__enumKey()+"="+cValue)
      oLogin:setCookie(cValue:__enumKey()+"="+cValue)
   NEXT

   oLogin:Post({;
      "SMLoginPopup"=>"UPLoginPopup|PopupLoginForm$PopupLoginButton",;
      "__LASTFOCUS"=>"",;
      "_EVENTTARGET"=>"PopupLoginForm$PopupLoginButton",;
      "__EVENTARGUMENT"=>"",;
      "__VIEWSTATE"=>cViewState,; //"/wEPaA8FDzhkNGNkMjMzMjMyMjJkZGQzpn/w3jCTFJmBfPdeyyu304ve0Q==",;
      "__VIEWSTATEGENERATOR"=>cViewStateGenerator,; //"67DAE5C8",;
      "poploggedin"=>0,;
      "hdnUrl"=>"",;
      "PopupLoginForm$UserName"=>"Engelking1",;
      "PopupLoginForm$Password"=>"6wTKm3",;
      "__ASYNCPOST"=>.T.})
   cData := oLogin:readAll()

	/*oIE:Document:open()
   oIE:Document:writeln(cData)
   oIE:Document:close()
   oIE:Visible := .T.
   Alert("Response from Login")
   oIE:Visible := .F. */
   MemoEdit(cData)

   Alert(SubStr(cData,AT("poploggedin",cData),100))

   IF AT("niet",cData) != 0
      Alert("FAILED")
   ENDIF

   oHttp := TIPClientHttp():new(TUrl():New("http://www.waldomemea.com")) ///OrderConfirmationEmail.aspx?OrderID=0&PoNumber=35494"))
   hCookies := HGetValueAt(HGetValueAt(oLogin:hCookies,1),1)
   FOR EACH cValue IN hCookies
      Alert(cValue:__enumKey()+"="+cValue)
      oHttp:setCookie(cValue:__enumKey()+"="+cValue)
   NEXT

   oHttp:open()
   cData := oHttp:readAll()
   IF AT("Engelking1",cData) != 0
      Alert("Logged in")
   ELSE
      Alert("Not logged in")
   ENDIF

   oHttp := TIPClientHttp():new("http://www.waldomemea.com/CheckExportFormat.aspx?OrderIDz=35494")
//Alert(ValToPrg(oLogin:hCookies))
   hCookies := HGetValueAt(HGetValueAt(oLogin:hCookies,1),1)
   Alert(ValToPrg(oLogin:hCookies))
   cValue := ""
   FOR EACH cValue IN hCookies
      Alert(cValue:__enumKey()+"="+cValue)
      oHttp:setCookie(cValue:__enumKey()+"="+cValue)
   NEXT
   IF oHttp:open()

      oHttp:post({;
         "__EVENTTARGET"=>"lbtnExportCSV",;
         "__EVENTARGUMENT"=>"",;
         "__VIEWSTATE"=>cViewState,; //"/wEPDwUKMTQ5MDIwODMzNw8WAh4IT3JkZXJJRHoFBTMxODgxFgICAw9kFgICAw8WAh4HVmlzaWJsZWhkZIddeW0mdUJvaVtbSyuXoYk+i4r6",;
         "__VIEWSTATEGENERATOR"=>cViewStateGenerator}) //"E5EF4C56"})
      Alert(oHttp:readAll())
   ENDIF
   oLogin:close()
ENDIF