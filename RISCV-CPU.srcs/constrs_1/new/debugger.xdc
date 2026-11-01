set dbg_sync_first [get_cells -quiet -hierarchical -regexp {.*(Sync|AckSync|RequestSync)_reg\[0\]}]
set_false_path -to [get_pins -quiet -of_objects $dbg_sync_first -filter {REF_PIN_NAME == D}]
