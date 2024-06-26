	object_const_def
	const_export SILPHCO1F_FIREFIGHTER1
	const_export SILPHCO1F_SOLDIER1
	const_export SILPHCO1F_SOLDIER2
	const_export SILPHCO1F_FIREFIGHTER2
	const_export SILPHCO1F_LINK_RECEPTIONIST

SilphCo1F_Object:
	db $2e ; border block

	def_warp_events
	warp_event 10, 17, LAST_MAP, 6
	warp_event 11, 17, LAST_MAP, 6
	warp_event 26,  0, SILPH_CO_2F, 1
	warp_event 20,  0, SILPH_CO_ELEVATOR, 1
	warp_event 16, 10, SILPH_CO_3F, 7

	def_bg_events

	def_object_events
	object_event  11, 13, SPRITE_GUARD, STAY, UP, TEXT_SILPHCO1F_FIREFIGHTER1, OPP_FIREFIGHTER, 3
	object_event  10, 14, SPRITE_SAILOR, STAY, UP, TEXT_SILPHCO1F_SOLDIER1, OPP_SOLDIER, 3
	object_event  12, 14, SPRITE_SAILOR, STAY, UP, TEXT_SILPHCO1F_SOLDIER2, OPP_SOLDIER, 4
	object_event  11, 14, SPRITE_GUARD, STAY, UP, TEXT_SILPHCO1F_FIREFIGHTER2, OPP_FIREFIGHTER, 4
	object_event  4,  2, SPRITE_LINK_RECEPTIONIST, STAY, DOWN, TEXT_SILPHCO1F_LINK_RECEPTIONIST

	def_warps_to SILPH_CO_1F
