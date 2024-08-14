; PureRGBnote: CHANGED: the code for animating these tiles was moved to another bank for space.
AnimateTiles::
	ld a, [wCurMapTileset]
	cp CAVERN
	jr z, .cavern
	cp VOLCANO
	jr nz, .normal
	CheckEvent EVENT_LAVA_FLOOD_ACTIVE
	ldh a, [hMovingBGTilesCounter1]
	jr z, .normalLava
	inc a
	ldh [hMovingBGTilesCounter1], a
	cp 5
	ret c
	cp 6
	jp z, AnimateLavaBubbles1
	cp 10
	jp z, AnimateLavaTiles
	cp 11
	ret c
	xor a
	ldh [hMovingBGTilesCounter1], a
	ret
.normalLava
	inc a
	ldh [hMovingBGTilesCounter1], a
	cp 20
	ret c
	cp 21
	jp z, AnimateLavaBubbles1
	cp 40
	jr z, AnimateLavaTiles
	cp 41
	ret c
	jp AnimateLavaBubbles2
.cavern
	ld a, [wCurMap]
	cp SEAFOAM_ISLANDS_B3F
	jr z, .seafoamCurrents
	cp SEAFOAM_ISLANDS_B4F
	jr z, .seafoamCurrents
	; fall through
.normal
	ldh a, [hMovingBGTilesCounter1]
	inc a
	ldh [hMovingBGTilesCounter1], a
	cp 20
	ret c
	cp 21
	jr nz, AnimateWaterTile
	jp AnimateFlowerTile
.seafoamCurrents
	ldh a, [hMovingBGTilesCounter1]
	inc a
	ldh [hMovingBGTilesCounter1], a
	; for whatever reason if we have fast currents on map load it gets visually glitched out
	; so we'll set it once the map loads in the script file
	ld hl, wCurrentMapScriptFlags
	bit 5, [hl]
	jr nz, .skipQuickCurrent
	rrca ; every other frame update currents
	call nc, AnimateSeafoamCurrents 
	ldh a, [hMovingBGTilesCounter1]
.skipQuickCurrent
	cp 20
	ret c
	; fall through		
; moves water tile sometimes left and and sometimes right to look like waves
AnimateWaterTile::
	ld hl, vTileset tile $14
	ld a, [wMovingBGTilesCounter2]
	inc a
	and 7
	ld [wMovingBGTilesCounter2], a
AnimateArbitraryWaterTile:
	and 4
	jr nz, .left
	call ScrollTileRight
	jr .done
.left
	call ScrollTileLeft
.done
	; if nc, we also need to animate flowers, and the counter needs to keep counting up
	; so return and don't reset counter
	ldh a, [hTileAnimations]
	rrca
	ret nc

	; reset the counter if we only need to animate water
	xor a
	ldh [hMovingBGTilesCounter1], a
	ret

AnimateFlowerTile::
	; reset the counter to loop back to the start of tile animation timer
	xor a
	ldh [hMovingBGTilesCounter1], a

	ld de, vTileset tile $03

	ld a, [wMovingBGTilesCounter2]
	and 3
	cp 2
	ld hl, FlowerTile1
	jr c, AnimateCopyTile
	ld hl, FlowerTile2
	jr z, AnimateCopyTile
	ld hl, FlowerTile3
AnimateCopyTile:
	ld c, 16
.loop
	ld a, [hli]
	ld [de], a
	inc de
	dec c
	jr nz, .loop
	ret

AnimateLavaTiles::
	ld hl, vTileset tile $23 ; right flowing lava
	call ScrollTileRight
	ld hl, vTileset tile $24 ; down flowing lava
	call ScrollTileDown
	ld hl, vTileset tile $25 ; left flowing lava
	call ScrollTileLeft
	ld hl, vTileset tile $26 ; up flowing lava
	call ScrollTileUp
	call AnimateWaterTile ; stationary lava uses default water tile
	CheckEvent EVENT_LAVA_FLOOD_ACTIVE
	ret z
	ld hl, vTileset tile $2A ; flood lava tile
	ld a, [wMovingBGTilesCounter2]
	jp AnimateArbitraryWaterTile

AnimateLavaBubbles1::
	CheckEvent EVENT_LAVA_FLOOD_ACTIVE
	ld de, vTileset tile $21 ; bubble tile 1
	jr z, .copyTile
	; in the case of the lava flood make all tiles bubble
	call .copyTile
	ld de, vTileset tile $27 ; flood bubble tile
	call .copyTile
	ld de, vTileset tile $06 ; bubble tile 2
.copyTile
	push de
	ld hl, LavaBubbleJumpTable
	ld a, [wMovingBGTilesCounter2]
	and 3
	call GetAddressFromPointerArray
	pop de
	jp AnimateCopyTile

AnimateLavaBubbles2::
	xor a
	ldh [hMovingBGTilesCounter1], a
	ld hl, LavaBubbleJumpTable
	ld a, [wMovingBGTilesCounter2]
	and 3
	inc a
	cp 4
	jr nz, .noReset
	xor a
.noReset
	call GetAddressFromPointerArray
	ld de, vTileset tile $06 ; bubble tile 2
	jp AnimateCopyTile

LavaBubbleJumpTable:
	dw LavaBubble1
	dw LavaBubble2
	dw LavaBubble3
	dw LavaBubble4

AnimateSeafoamCurrents:
	ld hl, vTileset tile $3B ; right flowing water
	call ScrollTileRight
	ld hl, vTileset tile $42 ; down flowing water
	call ScrollTileDown
	ld hl, vTileset tile $30 ; up flowing water
	jp ScrollTileUp


ScrollTileRight:
	ld c, 16
.right
	ld a, [hl]
	rrca
	ld [hli], a
	dec c
	jr nz, .right
	ret

ScrollTileLeft:
	ld c, 16
.left
	ld a, [hl]
	rlca
	ld [hli], a
	dec c
	jr nz, .left
	ret

; PureRGBnote: ADDED: scrolls the tile in hl down, copied from pokecrystal
ScrollTileDown:
	ld de, 16 - 2 ; 16 bytes per tile, first two bytes are read right away
	push hl
	add hl, de
	ld d, [hl]
	inc hl
	ld e, [hl]
	pop hl
	ld a, 16 / 4 ; 16 bytes per tile, loop does 4 bytes per go
.loop
	ld b, [hl]
	ld [hl], d
	inc hl
	ld c, [hl]
	ld [hl], e
	inc hl
	ld d, [hl]
	ld [hl], b
	inc hl
	ld e, [hl]
	ld [hl], c
	inc hl
	dec a
	jr nz, .loop
	ret

; PureRGBnote: ADDED: scrolls the tile in hl down, copied from pokecrystal
ScrollTileUp:
	ld d, [hl]
	inc hl
	ld e, [hl]
	ld bc, 16 - 2
	add hl, bc
	ld a, 16 / 4
.loop
	ld c, [hl]
	ld [hl], e
	dec hl
	ld b, [hl]
	ld [hl], d
	dec hl
	ld e, [hl]
	ld [hl], c
	dec hl
	ld d, [hl]
	ld [hl], b
	dec hl
	dec a
	jr nz, .loop
	ret

;	ld hl, LavaBubble1
;	jr z, .copy
;	; add 16 bytes up to 3 times to navigate to the next tile according to the counter
;	ld de, 16
;.loop1
;	add hl, de
;	dec a
;	jr nz ,.loop1

FlowerTile1: INCBIN "gfx/tilesets/flower/flower1.2bpp"
FlowerTile2: INCBIN "gfx/tilesets/flower/flower2.2bpp"
FlowerTile3: INCBIN "gfx/tilesets/flower/flower3.2bpp"

LavaBubble1: INCBIN "gfx/tilesets/lava/lava1.2bpp"
LavaBubble2: INCBIN "gfx/tilesets/lava/lava2.2bpp"
LavaBubble3: INCBIN "gfx/tilesets/lava/lava3.2bpp"
LavaBubble4: INCBIN "gfx/tilesets/lava/lava4.2bpp"
