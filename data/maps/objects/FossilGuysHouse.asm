	object_const_def
	const_export FOSSILGUYSHOUSE_FOSSIL_GUY
	const_export FOSSILGUYSHOUSE_MEOWTH
	const_export FOSSILGUYSHOUSE_PAPER
	const_export FOSSILGUYSHOUSE_ROCK
	const_export MOVE_MYSTIC
	const_export MOVE_MYSTIC_CRYSTAL_BALL

FossilGuysHouse_Object:
	db $d ; border block

	def_warp_events
	warp_event  6,  7, LAST_MAP, 9
	warp_event  7,  7, LAST_MAP, 9
	warp_event 18,  7, LAST_MAP, 10
	warp_event 19,  7, LAST_MAP, 10

	def_bg_events
	bg_event 2,  1, TEXT_FOSSILGUYSHOUSE_TELEPORTER1 
	bg_event 3,  1, TEXT_FOSSILGUYSHOUSE_TELEPORTER2 
	bg_event 8,  0, TEXT_FOSSILGUYSHOUSE_POSTER 
	bg_event 1,  4, TEXT_FOSSILGUYSHOUSE_DESK

	def_object_events
	object_event  1,  5, SPRITE_SUPER_NERD, STAY, UP, TEXT_FOSSILGUYSHOUSE_FOSSIL_GUY
	object_event  4,  3, SPRITE_CAT, WALK, ANY_DIR, TEXT_FOSSILGUYSHOUSE_MEOWTH
	object_event  7,  4, SPRITE_PAPER, STAY, NONE, TEXT_FOSSILGUYSHOUSE_PAPER 
	object_event  8,  4, SPRITE_OLD_AMBER, STAY, NONE, TEXT_FOSSILGUYSHOUSE_ROCK
	object_event 18,  3, SPRITE_GRANNY, STAY, DOWN, TEXT_MOVE_MYSTIC
	object_event 18,  4, SPRITE_OLD_AMBER, STAY, NONE, TEXT_MOVE_MYSTIC_CRYSTAL_BALL

	def_warps_to FOSSIL_GUYS_HOUSE
