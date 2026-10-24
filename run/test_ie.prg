oIE = CreateObject("InternetExplorer.application")
oIE:Navigate ("about:blank")
oIE:attachEvent("OnVisible",{|| Alert("Visible") })
oIE:Visible = .T.
