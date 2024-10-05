DEF STATE_GRASS_CAVE_AREAS EQU 0
DEF STATE_WATER_AREAS EQU 1
DEF STATE_OLD_ROD_AREAS EQU 2
DEF STATE_GOOD_ROD_AREAS EQU 3
DEF STATE_SUPER_ROD_AREAS EQU 4

; moved from town_map.asm

;ZeroOutDuplicatesInList: ; PureRGBnote: CHANGED: won't have duplicates anymore by default
; replace duplicate bytes in the list of wild pokemon locations with 0
; PureRGBnote: CHANGED: now replaces them with $fe because 0 is pallet town and that's a valid map for super rod encounters
;	ld de, wTownMapCoords
;.loop
;	ld a, [de]
;	inc de
;	cp $ff
;	ret z
;	ld c, a
;	ld l, e
;	ld h, d
;.zeroDuplicatesLoop
;	ld a, [hl]
;	cp $ff
;	jr z, .loop
;	cp c
;	jr nz, .skipZeroing
;	ld [hl], $fe
;.skipZeroing
;	inc hl
;	jr .zeroDuplicatesLoop


GetAreaDisplayTypes:
	callfar CheckHasGrassCaveWater
	ld hl, wTownMapAreaTypeFlags
	ld a, [wPokedexNum]
	cp PIKACHU
	call z, .turnOffSurfLocationsIfNotChampYet
	CheckEvent FLAG_VOLCANO_AREA_TURNED_OFF
	jr z, .doneChecks
	ld a, [wPokedexNum]
	push hl
	ld hl, DisableVolcanoSurfingMons
	ld de, 1
	call IsInArray
	pop hl
	call c, .forceNoWaterLocations
.doneChecks
	CheckBothEventsSet EVENT_GOT_FUCHSIA_FISHING_GURU_ITEM, EVENT_GOT_ROUTE12_FISHING_GURU_ITEM
	ret nz
	ld hl, wTownMapAreaTypeFlags
	ld a, [wPokedexNum]
	cp MAGIKARP
	jr z, .hasOldRod
	cp GOLDEEN
	res BIT_HAS_OLD_ROD_LOCATIONS, [hl]
	jr nz, .skipOldRod
.hasOldRod
	set BIT_HAS_OLD_ROD_LOCATIONS, [hl]
.skipOldRod
	callfar CheckHasGoodRod
	callfar CheckHasSuperRod
	ret
.turnOffSurfLocationsIfNotChampYet
	; hide pikachu's secret surf encounter in bills garden if not champ yet
	CheckEvent EVENT_BECAME_CHAMP
	ret nz
.forceNoWaterLocations
	res BIT_HAS_WATER_LOCATIONS, [hl]
	ret

DisableVolcanoSurfingMons:
	db MAGMAR
	db GRAVELER
	db RHYDON
	db GOLEM
	db ONIX
	db -1

DrawMonAreaButtonPrompt:
	ld a, [wTownMapAreaState]
	cp STATE_GRASS_CAVE_AREAS 
	jr z, .grassCaveState
	cp STATE_WATER_AREAS
	jr z, .waterState
	cp STATE_OLD_ROD_AREAS 
	jr z, .oldRodState
	cp STATE_GOOD_ROD_AREAS 
	jr z, .goodRodState
	cp STATE_SUPER_ROD_AREAS
	jr z, .superRodState
.grassCaveState
	hlcoord 13, 17
	ld a, $C0
	ld b, 6
	call DrawPrompt
	jr .drawArrows
.waterState
	hlcoord 15, 17
	ld a, $D2
	ld b, 4
	call DrawPrompt
	hlcoord 14, 17
	jr .drawArrows
.oldRodState
	hlcoord 15, 17
	ld a, $CC
	ld b, 4
	call DrawPrompt
	hlcoord 14, 17
	jr .drawArrows
.goodRodState
	hlcoord 14, 17
	ld a, $C9
	ld b, 3
	call DrawPrompt
	hlcoord 17, 17
	ld a, $CE
	ld b, 2
	call DrawPrompt
	hlcoord 13, 17
	jr .drawArrows
.superRodState
	hlcoord 14, 17
	ld a, $C6
	ld b, 3
	call DrawPrompt
	hlcoord 17, 17
	ld a, $CE
	ld b, 2
	call DrawPrompt
	hlcoord 13, 17
.drawArrows ; assumes hl will be pointing to the location the left arrow should be at (if there needs to be one)
	call FindPrevMonAreaState
	jr z, .nextArrow
	ld [hl], $D0
.nextArrow
	call FindNextMonAreaState
	ret z
	hlcoord 19, 17
	ld [hl], $D1 ; right prompt
	ret

; draw prompt of tile length b starting at tile a at coord hl 
DrawPrompt:
.loop
	ld [hli], a
	inc a
	dec b
	jr nz, .loop
	ret

; moved from town_map.asm

DisplayWildLocations:
	xor a
	ld [wTownMapAreaTypeFlags], a

	call GetMonName
	hlcoord 1, 0
	call PlaceString
	ld h, b
	ld l, c
	ld de, MonsNestText
	call PlaceString

	call SaveScreenTilesToBuffer1

	ld de, MapAreasUI
	ld hl, vChars1 tile $40
	lb bc, BANK(MapAreasUI), (MapAreasUIEnd - MapAreasUI) / $10
	call CopyVideoData

	ld de, FishingWaterIcons
	ld hl, vSprites tile $05
	lb bc, BANK(FishingWaterIcons), 2
	call CopyVideoDataDouble
	
	call GetAreaDisplayTypes
	ld a, [wTownMapAreaTypeFlags]
	and a
	jr z, .unknown ; if it doesn't appear anywhere, don't even look
	ld a, -1
	ld [wTownMapAreaState], a ; before the first state, so we will get the first available one
	call FindNextMonAreaState
	ld a, b
	ld [wTownMapAreaState], a ; first state
	jr .doFirstState
.goToNextState
	call LoadScreenTilesFromBuffer1
.doFirstState
	call DrawMonAreaButtonPrompt
.decideState
	ld a, [wTownMapAreaState]
	cp STATE_GRASS_CAVE_AREAS 
	jr z, .displayGrassCaveState
	cp STATE_WATER_AREAS 
	jr z, .displayWaterState
	cp STATE_OLD_ROD_AREAS 
	jr z, .displayOldRodState
	cp STATE_GOOD_ROD_AREAS 
	jr z, .displayGoodRodState
	cp STATE_SUPER_ROD_AREAS
	jr z, .displaySuperRodState
.displayGrassCaveState
	call DisplayGrassCaveLocations
	ld a, l
	and a ; were any OAM entries written?
	jr nz, .drawPlayerSprite
; if no OAM entries were written, print area unknown text
	jr .unknown
.displayWaterState
	call DisplayWaterLocations
	ld a, l
	and a ; were any OAM entries written?
	jr nz, .drawPlayerSprite
; if no OAM entries were written, print area unknown text
	jr .unknown
.displayOldRodState
	call DisplayOldRodLocation
	jr .done
.displayGoodRodState
	call DisplayGoodRodLocation
	jr .done
.displaySuperRodState
	call DisplaySuperRodLocations
	ld a, l
	and a ; were any OAM entries written?
	jr nz, .drawPlayerSprite
; if no OAM entries were written, print area unknown text
.unknown
	hlcoord 1, 7
	lb bc, 2, 15
	call TextBoxBorder
	hlcoord 2, 9
	ld de, AreaUnknownText
	call PlaceString
	jr .done
.drawPlayerSprite
	callfar FarDrawPlayerOrBirdSprite
.done

	ld hl, wShadowOAM
	ld de, wTownMapSavedOAM
	ld bc, $a0
	rst _CopyData

	call GetMonAreaInputButtons
	push af
	call WaitForTextScrollSpecificButtonsPress
	xor a
	ld hl, wShadowOAM
	ld bc, $a0
	call FillMemory
	pop af
	ldh a, [hJoy5]
	bit BIT_A_BUTTON, a
	jr nz, .exit
	bit BIT_B_BUTTON, a
	jr nz, .exit
	bit BIT_D_LEFT, a
	jr nz, .getPrevState
	bit BIT_D_RIGHT, a
	jr nz, .getNextState
.exit
	xor a
	ld [wMenuWatchedKeys], a
	ret
.getPrevState
	; guaranteed to have one, but this function will get it into register b
	call FindPrevMonAreaState
	jr .loadState
.getNextState
	; guaranteed to have one, but this function will get it into register b
	call FindNextMonAreaState
.loadState
	ld a, b
	ld [wTownMapAreaState], a
	ld a, SFX_LEDGE
	rst _PlaySound
	jp .goToNextState

GetMonAreaInputButtons:
	ld a, B_BUTTON
	ld [wMenuWatchedKeys], a
	call FindNextMonAreaState
	call nz, .hasRight
	call FindPrevMonAreaState
	call nz, .hasLeft
	ret
.hasRight
	ld a, [wMenuWatchedKeys]
	or D_RIGHT
	ld [wMenuWatchedKeys], a
	ret
.hasLeft
	ld a, [wMenuWatchedKeys]
	or D_LEFT
	ld [wMenuWatchedKeys], a
	ret

; output b = previous state, z flag indicates if there is one available or not
FindPrevMonAreaState:
	ld a, [wTownMapAreaState]
	ld b, a
.loopPrev
	dec b
	ld a, b
	cp -1
	ret z
	call HasAreaState
	ret nz
	jr .loopPrev

; output b = next state, z flag indicates if there is one available or not
FindNextMonAreaState:
	ld a, [wTownMapAreaState]
	ld b, a
.loopNext
	inc b
	ld a, b
	cp STATE_SUPER_ROD_AREAS + 1
	ret z
	call HasAreaState
	ret nz
	jr .loopNext

; b = which state to check if is available
HasAreaState:
	ld a, b
	cp STATE_GRASS_CAVE_AREAS
	jr z, .grassWaterState
	cp STATE_WATER_AREAS
	jr z, .waterState
	cp STATE_OLD_ROD_AREAS
	jr z, .oldRodState
	cp STATE_GOOD_ROD_AREAS
	jr z, .goodRodState
	cp STATE_SUPER_ROD_AREAS
	jr z, .superRodState
.grassWaterState
	ld a, [wTownMapAreaTypeFlags]
	bit BIT_HAS_GRASS_CAVE_LOCATIONS, a
	ret
.waterState
	ld a, [wTownMapAreaTypeFlags]
	bit BIT_HAS_WATER_LOCATIONS, a
	ret
.oldRodState
	ld a, [wTownMapAreaTypeFlags]
	bit BIT_HAS_OLD_ROD_LOCATIONS, a
	ret
.goodRodState
	ld a, [wTownMapAreaTypeFlags]
	and %110
	ret
.superRodState
	ld a, [wTownMapAreaTypeFlags]
	bit BIT_HAS_SUPER_ROD_LOCATIONS, a
	ret

DisplayWaterLocations:
	ld a, 1
	ld [wTownMapSpriteBlinkingEnabled], a
	farcall FindWaterLocations
	ld a, 6 ; water icon
	jp LoadMapIcons	

DisplayGrassCaveLocations:
	ld a, 1
	ld [wTownMapSpriteBlinkingEnabled], a
	farcall FindGrassCaveLocations
	ld a, 4 ; nest icon
	jp LoadMapIcons

DisplayOldRodLocation:
	xor a
	ld [wTownMapSpriteBlinkingEnabled], a
	hlcoord 1, 7
	lb bc, 3, 16
	call TextBoxBorder
	hlcoord 2, 9
	ld de, AnyWaterText
	jp PlaceString

DisplayGoodRodLocation:
	xor a
	ld [wTownMapSpriteBlinkingEnabled], a
	hlcoord 1, 7
	lb bc, 3, 16
	call TextBoxBorder
	ld a, [wTownMapAreaTypeFlags]
	and %110
	cp %110
	jr z, .anyWater
	bit 1, a
	jr nz, .freshWater
	bit 2, a
	jr nz, .saltWater
.anyWater
	hlcoord 2, 9
	ld de, AnyWaterText
	jp PlaceString
.freshWater
	hlcoord 2, 9
	ld de, FreshWaterText
	jp PlaceString
.saltWater
	hlcoord 2, 9
	ld de, SaltWaterText
	jp PlaceString

DisplaySuperRodLocations:
	ld a, 1
	ld [wTownMapSpriteBlinkingEnabled], a
	farcall FindSuperRodLocations
	ld a, $5 ; fishing hook icon tile no.
	; fall through

LoadMapIcons:
	push af
	; call ZeroOutDuplicatesInList ; PureRGBnote: CHANGED: won't have duplicates anymore by default
	ld hl, wShadowOAM
	ld de, wTownMapCoords
.loop
	ld a, [de]
	cp $ff ; indicates end of list
	jr z, .exitLoop
	;cp 0 ; indicates a duplicate entry ; PureRGBnote: CHANGED: won't have duplicates anymore by default
	;jr z, .nextEntry
	ld b, a
	cp CINNABAR_VOLCANO
	jr z, .checkHideCinnabarVolcano
	cp CINNABAR_VOLCANO_WEST
	jr z, .checkHideCinnabarVolcano
	cp CERULEAN_CAVE_2F
	jr c, .dontSkip
	cp CERULEAN_CAVE_1F + 1
	jr c, .checkShouldSkipCeruleanCave
.dontSkip
	push hl
	predef FarLoadTownMapEntry
	pop hl
	ld a, [de]
	call TownMapCoordsToOAMCoords2
	pop af ; get icon tile to display
	push af
	ld [hli], a
	xor a
	ld [hli], a
.nextEntry
	inc de
	jr .loop
.exitLoop
	pop af
	ret
.checkShouldSkipCeruleanCave
	CheckEvent EVENT_BECAME_CHAMP ; show cerulean cave pokemon locations only after becoming champ
	jr z, .nextEntry
	jr .dontSkip
.checkHideCinnabarVolcano
	CheckEvent FLAG_VOLCANO_AREA_TURNED_OFF
	jr nz, .nextEntry
	jr .dontSkip




TownMapCoordsToOAMCoords2:
; in: lower nybble of a = x, upper nybble of a = y
; out: b and [hl] = (y * 8) + 24, c and [hl+1] = (x * 8) + 24
	push af
	and $f0
	srl a
	add 24
	ld b, a
	ld [hli], a
	pop af
	and $f
	swap a
	srl a
	add 24
	ld c, a
	ld [hli], a
	ret


MonsNestText:
	db "'s NEST@"

AreaUnknownText:
	db " AREA UNKNOWN@"

AnyWaterText:
	db "Any Water@"

FreshWaterText:
	db "Any Fresh Water@"

SaltWaterText:
	db "Any Salt Water@"

