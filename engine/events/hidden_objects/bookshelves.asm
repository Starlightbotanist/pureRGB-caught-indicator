; prints text for bookshelves in buildings without sign events
PrintBookshelfText::
	ld a, [wSpritePlayerStateData1FacingDirection]
	cp SPRITE_FACING_UP
	jr nz, .noMatch
	; player is facing up
;;;;;;;;;; PureRGBnote: ADDED: some houses have unique text for bookcases instead of "crammed full of books!"
	ld a, [wCurMap]
	cp TYPE_GUYS_HOUSE
	jr z, .noMatch
	cp VERMILION_GYM
	jr z, .noMatch
	cp SS_ANNE_CAPTAINS_ROOM
	jr z, .noMatch
	cp CELADON_MANSION_2F
	jr nz, .notCeladonHouses
	callfar CeladonHouse2FBookCaseCheck
	jr nc, .noMatch
.notCeladonHouses
;;;;;;;;;;
	ld a, [wCurMapTileset]
	ld b, a
	lda_coord 8, 7
	ld c, a
	ld hl, BookshelfTileIDs
.loop
	ld a, [hli]
	cp $ff
	jr z, .noMatch
	cp b
	jr nz, .nextBookshelfEntry1
	ld a, [hli]
	cp c
	jr nz, .nextBookshelfEntry2
	ld a, [hl]
	push af
	call EnableAutoTextBoxDrawing
	pop af
	call PrintPredefTextID
	xor a
	ldh [hInteractedWithBookshelf], a
	ret
.nextBookshelfEntry1
	inc hl
.nextBookshelfEntry2
	inc hl
	jr .loop
.noMatch
	ld a, $ff
	ldh [hInteractedWithBookshelf], a
	farjp PrintCardKeyText

INCLUDE "data/tilesets/bookshelf_tile_ids.asm"
