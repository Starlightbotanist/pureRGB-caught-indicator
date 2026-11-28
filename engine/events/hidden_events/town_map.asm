TownMapText::
	text_far _TownMapText
	text_promptbutton
	text_asm
	ld a, $1
	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
	call DisableTextDelay
	call GBPalWhiteOutWithDelay3
	xor a
	ldh [hWY], a
	inc a
	ldh [hAutoBGTransferEnabled], a
	call LoadFontTilePatterns
	farcall DisplayTownMap
	call EnableTextDelay
	ld de, TextScriptEndNoPop
	push de
	ldh a, [hLoadedROMBank]
	push af
	jp CloseTextDisplay
