; width of east/west connections
; height of north/south connections
DEF MAP_BORDER EQU 3
DEF DEFER_SHOWING_MAP EQU %10000
DEF EXTRA_MUSIC_MAP   EQU %100000
DEF SPECIAL_ANIMATION_MAP   EQU %1000000

; connection directions
	const_def
	const EAST_F ; 0
	const WEST_F ; 1
	const SOUTH_F ; 2
	const NORTH_F ; 3

; additional map header bit data
	const BIT_DEFER_SHOWING_MAP ; 4
	const BIT_EXTRA_MUSIC_MAP ; 5
	const BIT_SPECIAL_ANIMATION_MAP ; 6

; wCurMapConnections
	const_def
	shift_const EAST   ; 1 %1
	shift_const WEST   ; 2 %10
	shift_const SOUTH  ; 4 %100
	shift_const NORTH  ; 8 %1000

; flower and water tile animations
	const_def
	const TILEANIM_NONE          ; 0
	const TILEANIM_WATER         ; 1
	const TILEANIM_WATER_FLOWER  ; 2
