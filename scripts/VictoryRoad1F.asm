VictoryRoad1F_Script:
	call VictoryRoad1FMapLoadScript
	call EnableAutoTextBoxDrawing
	ld hl, VictoryRoad1TrainerHeaders
	ld de, VictoryRoad1F_ScriptPointers
	ld a, [wVictoryRoad1FCurScript]
	call ExecuteCurMapScriptInTable
	ld [wVictoryRoad1FCurScript], a
	ret

VictoryRoad1FMapLoadScript::
	ld hl, wCurrentMapScriptFlags
	bit BIT_CUR_MAP_LOADED_1, [hl]
	res BIT_CUR_MAP_LOADED_1, [hl]
	ret z
	CheckEvent EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH
	ret z
	ld a, $1d
	ld [wNewTileBlockID], a
	lb bc, 6, 4
	predef_jump ReplaceTileBlock

VictoryRoad1F_ScriptPointers:
	def_script_pointers
	dw_const VictoryRoad1FDefaultScript,            SCRIPT_VICTORYROAD1F_DEFAULT
	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_VICTORYROAD1F_START_BATTLE
	dw_const EndTrainerBattle,                      SCRIPT_VICTORYROAD1F_END_BATTLE

VictoryRoad1FDefaultScript:
	ld a, [wMiscFlags]
	bit BIT_BOULDER_DUST, a
	ret nz ; PureRGBnote: ADDED: if a boulder animation is playing forget doing this, helps reduce lag
	CheckEvent EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH
	jp nz, CheckFightingMapTrainers
	ld hl, Boulder1FSwitchCoords
	call CheckBoulderCoords
	jp nc, CheckFightingMapTrainers
	ld hl, wCurrentMapScriptFlags
	set BIT_CUR_MAP_LOADED_1, [hl]
	SetEvent EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH
;;;;;;;;;; PureRGBnote: ADDED: sound effect + animation when boulder presses switch
	ld de, wSprite05StateData1YPixels
	; fall through
BoulderOnButtonAnim:
	push de
	ld a, SFX_TELEPORT_ENTER_2
	rst _PlaySound
	pop hl
	; make the boulder move up and down so it looks like it pressed the switch
	dec [hl]
	call Delay3
	inc [hl]
	ld c, 20
	rst _DelayFrames
	lb de, SFX_GO_INSIDE, 20
	jpfar FarShakeScreen
;;;;;;;;;;


Boulder1FSwitchCoords:
	dbmapcoord 17, 13
	db -1 ; end


VictoryRoad1F_TextPointers:
	def_text_pointers
	dw_const VictoryRoad1FCooltrainerFText, TEXT_VICTORYROAD1F_COOLTRAINER_F
	dw_const VictoryRoad1FCooltrainerMText, TEXT_VICTORYROAD1F_COOLTRAINER_M
	dw_const PickUpItemText,                TEXT_VICTORYROAD1F_ITEM1
	dw_const PickUpItemText,                TEXT_VICTORYROAD1F_ITEM2
	dw_const BoulderText,                   TEXT_VICTORYROAD1F_BOULDER1
	dw_const BoulderText,                   TEXT_VICTORYROAD1F_BOULDER2
	dw_const BoulderText,                   TEXT_VICTORYROAD1F_BOULDER3

VictoryRoad1TrainerHeaders:
	def_trainers
VictoryRoad1TrainerHeader0:
	trainer EVENT_BEAT_VICTORY_ROAD_1_TRAINER_0, 2, VictoryRoad1FCooltrainerFBattleText, VictoryRoad1FCooltrainerFEndBattleText, VictoryRoad1FCooltrainerFAfterBattleText
VictoryRoad1TrainerHeader1:
	trainer EVENT_BEAT_VICTORY_ROAD_1_TRAINER_1, 2, VictoryRoad1FCooltrainerMBattleText, VictoryRoad1FCooltrainerMEndBattleText, VictoryRoad1FCooltrainerMAfterBattleText
	db -1 ; end

VictoryRoad1FCooltrainerFText:
	text_asm
	ld hl, VictoryRoad1TrainerHeader0
	call TalkToTrainer
	rst TextScriptEnd

VictoryRoad1FCooltrainerMText:
	text_asm
	ld hl, VictoryRoad1TrainerHeader1
	call TalkToTrainer
	rst TextScriptEnd

VictoryRoad1FCooltrainerFBattleText:
	text_far _VictoryRoad1FCooltrainerFBattleText
	text_end

VictoryRoad1FCooltrainerFEndBattleText:
	text_far _VictoryRoad1FCooltrainerFEndBattleText
	text_end

VictoryRoad1FCooltrainerFAfterBattleText:
	text_far _VictoryRoad1FCooltrainerFAfterBattleText
	text_end

VictoryRoad1FCooltrainerMBattleText:
	text_far _VictoryRoad1FCooltrainerMBattleText
	text_end

VictoryRoad1FCooltrainerMEndBattleText:
	text_far _VictoryRoad1FCooltrainerMEndBattleText
	text_end

VictoryRoad1FCooltrainerMAfterBattleText:
	text_far _VictoryRoad1FCooltrainerMAfterBattleText
	text_end
