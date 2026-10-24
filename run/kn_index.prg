

Net_Use("kn","kn",.T.,0)
INDEX ON Pad(StrTran(code," ",""),10) TO (Trim(Tr_getini(1))+"\ntx\kn.001")
kn->(dbCloseArea())