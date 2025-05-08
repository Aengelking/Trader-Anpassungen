FUNCTION Hook_Automotive_Before_Pack_From_List( nNr,lRech,lInUse )   
RETURN MBAseRun(Path("hooks\before_pack_from_list"),{nNr,lRech,lInUse})