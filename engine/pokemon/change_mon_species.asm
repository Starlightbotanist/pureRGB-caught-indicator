; PureRGBnote: ADDED: function that changed a pokemon in the party to a different pokemon. 
; Used with Armored Mewtwo, "Cursed" Haunter, and "Hardened" Onix
; input: 
; [wCurPartySpecies] = target pokemon species
; [wWhichPokemon] = which party pokemon to change

ChangePartyPokemonSpecies::
	ld a, [wCurPartySpecies]
	ld [wCurSpecies], a
	call GetMonHeader
	ld hl, wPartySpecies
	ld a, [wWhichPokemon]
	ld d, 0
	ld e, a
	add hl, de
	ld a, [wCurPartySpecies]
	ld [hl], a
	ld a, [wWhichPokemon]
	ld hl, wPartyMon1Species
	ld bc, wPartyMon2 - wPartyMon1
	call AddNTimes
	push hl
	ld a, [wCurPartySpecies]
	ld [hl], a ; set the pokemon's species to the desired one
	ld bc, wPartyMon1Level - wPartyMon1
	add hl, bc
	ld a, [hli]
	ld [wCurEnemyLevel], a ; value needed for stat calculation
	ld d, h
	ld e, l ; de now points to stats
	ld bc, (wPartyMon1Exp + 2) - wPartyMon1Stats
	add hl, bc ; hl now points to LSB of experience
	ld b, 1
	call CalcStats ; recalculate stats
	pop hl
	push hl
	ld bc, wPartyMon1MaxHP - wPartyMon1
	add hl, bc ; hl now points to MSB of recalculated max HP
	ld a, [hli]
	ld b, a
	ld a, [hld]
	ld c, a
	; set current hp to new max hp
	ld de, wPartyMon1HP - wPartyMon1MaxHP
	add hl, de ; hl now points to MSB of current HP
	ld a, b
	ld [hli], a
	ld a, c
	ld [hld], a
	pop hl
	; reassign types
	ld bc, wPartyMon1Type - wPartyMon1
	add hl, bc ; hl now points to 1st type of mon
	ld a, [wMonHType1]
	ld [hli], a
	ld a, [wMonHType2]
	ld [hl], a
	ret

; PureRGBnote: ADDED: function that renames a pokemon if it has its default name only. Used for changing Gengar to "Cursed" Haunter and back again.
; [wCurPartySpecies] = target pokemon to change default name to
; [wWhichPokemon] = which pokemon in party will potentially be changed
CheckMonNickNameDefault::
	ld a, [wCurPartySpecies]
	cp POWERED_HAUNTER
	ld d, GENGAR
	jr z, .checkRename
	cp GENGAR
	ld d, POWERED_HAUNTER
	jr z, .checkRename
	cp CUBONE
	ret nz
	; always rename ghost marowak -> cubone change
	call .getNick
	push hl
	jr .rename
.checkRename
	ld a, d
	ld [wNamedObjectIndex], a
	call GetMonName
	ld de, wNameBuffer
	call .getNick
	push hl
.loop
	ld a, [hli]
	ld b, a
	ld a, [de]
	inc de
	cp b
	jr nz, .noMatch
	cp "@"
	jr nz, .loop
	; they're the same, so rename
.rename
	ld a, [wCurPartySpecies]
	ld [wNamedObjectIndex], a
	call GetMonName
	ld de, wNameBuffer
	pop hl
.loop2
	ld a, [de]
	ld [hli], a
	cp "@"
	ret z
	inc de
	jr .loop2
.noMatch
	pop hl
	ret
.getNick
	ld a, [wWhichPokemon]
	ld hl, wPartyMonNicks
	lb bc, 0, NAME_LENGTH
	jp AddNTimes
