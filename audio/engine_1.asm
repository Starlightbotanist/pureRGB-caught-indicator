; The first of three duplicated sound engines.
; shinpokerednote: audionote: This file was heavily modified to be closer to pokeyellow's audio engine

Audio1_UpdateMusic::
	ld c, CHAN1
.loop
	ld b, 0
	ld hl, wChannelSoundIDs
	add hl, bc
	ld a, [hl]
	and a
	jr z, .nextChannel
	ld a, c
	cp CHAN5
	jr nc, .applyAffects ; if sfx channel
	ld a, [wMuteAudioAndPauseMusic]
	and a
	jr z, .applyAffects
	bit BIT_MUTE_AUDIO, a
	jr nz, .nextChannel
	set BIT_MUTE_AUDIO, a
	ld [wMuteAudioAndPauseMusic], a
	xor a ; disable all channels' output
	ldh [rNR51], a
	ldh [rNR30], a
	ld a, $80
	ldh [rNR30], a
	jr .nextChannel
.applyAffects
	call Audio1_ApplyMusicAffects
.nextChannel
	ld a, c
	inc c ; inc channel number
	cp CHAN8
	jr nz, .loop
	ret

; this routine checks flags for music effects currently applied
; to the channel and calls certain functions based on flags.
Audio1_ApplyMusicAffects:
	ld b, $0
	ld hl, wChannelNoteDelayCounters ; delay until next note
	add hl, bc
	ld a, [hl]
	cp 1 ; if the delay is 1, play next note
	jp z, Audio1_PlayNextNote
	dec a ; otherwise, decrease the delay timer
	ld [hl], a
	ld a, c
	cp CHAN5
	jr nc, .startChecks ; if a sfx channel
	ld hl, wChannelSoundIDs + CHAN5
	add hl, bc
	ld a, [hl]
	and a
	ret nz
.startChecks
	ld hl, wChannelFlags1
	add hl, bc
	bit BIT_ROTATE_DUTY_CYCLE, [hl]
	call nz, Audio1_ApplyDutyCyclePattern
	ld b, 0
	ld hl, wChannelFlags2
	add hl, bc
	bit BIT_EXECUTE_MUSIC, [hl]
	jr nz, .checkForPitchSlide
	ld hl, wChannelFlags1
	add hl, bc
	bit BIT_NOISE_OR_SFX, [hl]
	ret nz
.checkForPitchSlide
	ld hl, wChannelFlags1
	add hl, bc
	bit BIT_PITCH_SLIDE_ON, [hl]
	jp nz, Audio1_ApplyPitchSlide
	ld hl, wChannelVibratoDelayCounters
	add hl, bc
	ld a, [hl]
	and a ; check if delay is over
	jr z, .checkForVibrato
	dec [hl] ; otherwise, dec delay
	ret
.checkForVibrato
	ld hl, wChannelVibratoExtents
	add hl, bc
	ld a, [hl]
	and a
	ret z; no vibrato
	ld d, a
	ld hl, wChannelVibratoRates
	add hl, bc
	ld a, [hl]
	and $f
	jr z, .applyVibrato
	dec [hl] ; decrement counter
	ret
.applyVibrato
	ld a, [hl]
	swap [hl]
	or [hl]
	ld [hl], a ; reload the counter
	ld hl, wChannelFrequencyLowBytes
	add hl, bc
	ld e, [hl] ; get note pitch
	ld hl, wChannelFlags1
	add hl, bc
; This is the only code that sets/resets the vibrato direction bit, so it
; continuously alternates which path it takes.
	bit BIT_VIBRATO_DIRECTION, [hl]
	jr z, .unset
	res BIT_VIBRATO_DIRECTION, [hl]
	ld a, d
	and $f
	ld d, a
	ld a, e
	sub d
	jr nc, .done
	xor a
	jr .done
.unset
	set BIT_VIBRATO_DIRECTION, [hl]
	ld a, d
	and $f0
	swap a
	add e
	jr nc, .done
	ld a, $ff
.done
	ld d, a
	ld b, REG_FREQUENCY_LO
	call Audio1_GetRegisterPointer
	ld [hl], d
	ret

; this routine executes all music commands that take up no time,
; like tempo changes, duty cycle changes etc. and doesn't return
; until the first note is reached
Audio1_PlayNextNote:
; reload the vibrato delay counter
	ld hl, wChannelVibratoDelayCounterReloadValues
	add hl, bc
	ld a, [hl]
	ld hl, wChannelVibratoDelayCounters
	add hl, bc
	ld [hl], a

	ld hl, wChannelFlags1
	add hl, bc
	res BIT_PITCH_SLIDE_ON, [hl]
	res BIT_PITCH_SLIDE_DECREASING, [hl]
	ld a, c
	cp CHAN5
	jr nz, Audio1_sound_ret
	ld a, [wLowHealthAlarm]
	bit 7, a
	jr z, Audio1_sound_ret

;;;;;;;;;; shinpokerednote: FIXED: treat non-active wLowHealthTonePairs the same as a disabled wLowHealthAlarm
;;;;;;;;;; needed for limiting the hp alarm or else some sfx get cut off
	ld a, [wLowHealthTonePairs]
	bit 7, a
;;;;;;;;;;
	jp nz, Audio1_EnableChannelOutput
; fall through

Audio1_sound_ret:
	call Audio1_GetNextMusicByte
	ld d, a
	cp sound_ret_cmd
	jp nz, Audio1_sound_call
	ld b, 0
	ld hl, wChannelFlags1
	add hl, bc
	bit BIT_SOUND_CALL, [hl]
	jr nz, .returnFromCall
	ld a, c
	cp CHAN4
	jr c, .disableChannelOutput
	res BIT_NOISE_OR_SFX, [hl]
	ld hl, wChannelFlags2
	add hl, bc
	res BIT_EXECUTE_MUSIC, [hl]
	cp CHAN7
	jr nz, .skipSfxChannel3
; restart hardware channel 3 (wave channel) output
	xor a
	ldh [rNR30], a
	ld a, $80
	ldh [rNR30], a
.skipSfxChannel3
	jr nz, .afterDisable
	ld a, [wDisableChannelOutputWhenSfxEnds]
	and a
	jr z, .afterDisable
	xor a
	ld [wDisableChannelOutputWhenSfxEnds], a
	jr .disableChannelOutput
.returnFromCall
	res BIT_SOUND_CALL, [hl]
	ld d, $0
	ld a, c
	add a
	ld e, a
	ld hl, wChannelCommandPointers
	add hl, de
	push hl ; store current channel address
	ld hl, wChannelReturnAddresses
	add hl, de
	ld e, l
	ld d, h
	pop hl
	ld a, [de]
	ld [hli], a
	inc de
	ld a, [de]
	ld [hl], a ; loads channel address to return to
	jp Audio1_sound_ret
.disableChannelOutput
	ld hl, Audio1_HWChannelDisableMasks
	add hl, bc
	ldh a, [rNR51]
	and [hl]
	ldh [rNR51], a
.afterDisable
	ld a, [wChannelSoundIDs + CHAN5]
	cp CRY_SFX_START
	jr c, .skipCry
	ld a, [wChannelSoundIDs + CHAN5]
	cp CRY_SFX_END
	jr z, .skipCry
	jr nc, .skipCry
	ld a, c
	cp CHAN5
	jr z, .skipRewind
	call Audio1_GoBackOneCommandIfCry
	ret c
.skipRewind
	ld a, [wSavedVolume]
	ldh [rNR50], a
	xor a
	ld [wSavedVolume], a
.skipCry
	ld hl, wChannelSoundIDs
	add hl, bc
	ld [hl], b
	ret

Audio1_sound_call:
	cp sound_call_cmd
	jp nz, Audio1_sound_loop
	call Audio1_GetNextMusicByte
	push af
	call Audio1_GetNextMusicByte
	ld d, a
	pop af
	ld e, a
	push de ; store pointer
	ld d, $0
	ld a, c
	add a
	ld e, a
	ld hl, wChannelCommandPointers
	add hl, de
	push hl
	ld hl, wChannelReturnAddresses
	add hl, de
	ld e, l
	ld d, h
	pop hl
	ld a, [hli]
	ld [de], a
	inc de
	ld a, [hld]
	ld [de], a ; copy current channel address
	pop de
	ld a, e
	ld [hli], a
	ld [hl], d ; overwrite current address with pointer
	ld b, $0
	ld hl, wChannelFlags1
	add hl, bc
	set BIT_SOUND_CALL, [hl] ; set the call flag
	jp Audio1_sound_ret

Audio1_sound_loop:
	cp sound_loop_cmd
	jp nz, Audio1_note_type
	call Audio1_GetNextMusicByte
	ld e, a
	and a
	jr z, .infiniteLoop
	ld b, 0
	ld hl, wChannelLoopCounters
	add hl, bc
	ld a, [hl]
	cp e
	jr nz, .loopAgain
	ld [hl], 1 ; if no more loops to make,
	call Audio1_GetNextMusicByte ; skip pointer
	call Audio1_GetNextMusicByte
	jp Audio1_sound_ret
.loopAgain ; inc loop count
	inc a
	ld [hl], a
	; fall through
.infiniteLoop ; overwrite current address with pointer
	call Audio1_GetNextMusicByte
	push af
	call Audio1_GetNextMusicByte
	ld b, a
	ld d, $0
	ld a, c
	add a
	ld e, a
	ld hl, wChannelCommandPointers
	add hl, de
	pop af
	ld [hli], a
	ld [hl], b
	jp Audio1_sound_ret

Audio1_note_type:
	and $f0
	cp note_type_cmd
	jp nz, VolumeEnvelope
	ld a, d
	and $f
	ld b, $0
	ld hl, wChannelNoteSpeeds
	add hl, bc
	ld [hl], a ; store low nibble as speed
	ld a, c
	cp CHAN4
	jr z, .noiseChannel ; noise channel has 0 params
	call Audio1_GetNextMusicByte
	ld d, a
	ld a, c
	cp CHAN3
	jr z, .musicChannel3
	cp CHAN7
	jr nz, .skipChannel3
	ld hl, wSfxWaveInstrument
	jr .channel3
.musicChannel3
	ld hl, wMusicWaveInstrument
.channel3
	ld a, d
	and $f
	ld [hl], a ; store low nibble of param as wave instrument
	ld a, d
	and $30
	add a
	ld d, a
	; fall through

	; if channel 3, store high nibble as volume
	; else, store volume (high nibble) and fade (low nibble)
.skipChannel3
	ld b, 0
	ld hl, wChannelVolumes
	add hl, bc
	ld [hl], d
.noiseChannel
	jp Audio1_sound_ret

Audio1_toggle_perfect_pitch:
	ld a, d
	cp toggle_perfect_pitch_cmd
	jr nz, Audio1_vibrato
	ld b, 0
	ld hl, wChannelFlags1
	add hl, bc
	ld a, [hl]
	xor 1 << BIT_PERFECT_PITCH
	ld [hl], a
	jp Audio1_sound_ret

Audio1_vibrato:
	cp vibrato_cmd
	jr nz, Audio1_pitch_slide
	call Audio1_GetNextMusicByte
	ld b, 0
	ld hl, wChannelVibratoDelayCounters
	add hl, bc
	ld [hl], a ; store delay
	ld hl, wChannelVibratoDelayCounterReloadValues
	add hl, bc
	ld [hl], a ; store delay
	call Audio1_GetNextMusicByte
	ld d, a

; The high nybble of the command byte is the extent of the vibrato.
; Let n be the extent.
; The upper nybble of the channel's byte in the wChannelVibratoExtents
; array will store the extent above the note: (n / 2) + (n % 2).
; The lower nybble will store the extent below the note: (n / 2).
; These two values add to the total extent, n.
	and $f0
	swap a
	ld b, 0
	ld hl, wChannelVibratoExtents
	add hl, bc
	srl a
	ld e, a
	adc b
	swap a
	or e
	ld [hl], a

; The low nybble of the command byte is the rate of the vibrato.
; The high and low nybbles of the channel's byte in the wChannelVibratoRates
; array are both initialised to this value because the high nybble is the
; counter reload value and the low nybble is the counter itself, which should
; start at its value upon reload.
	ld a, d
	and $f
	ld d, a
	ld hl, wChannelVibratoRates
	add hl, bc
	swap a
	or d
	ld [hl], a

	jp Audio1_sound_ret

Audio1_pitch_slide:
	cp pitch_slide_cmd
	jr nz, Audio1_duty_cycle
	call Audio1_GetNextMusicByte
	ld b, 0
	ld hl, wChannelPitchSlideLengthModifiers
	add hl, bc
	ld [hl], a
	call Audio1_GetNextMusicByte
	ld d, a
	and $f0
	swap a
	ld b, a
	ld a, d
	and $f
	call Audio1_CalculateFrequency
	ld b, 0
	ld hl, wChannelPitchSlideTargetFrequencyHighBytes
	add hl, bc
	ld [hl], d
	ld hl, wChannelPitchSlideTargetFrequencyLowBytes
	add hl, bc
	ld [hl], e
	ld b, 0
	ld hl, wChannelFlags1
	add hl, bc
	set BIT_PITCH_SLIDE_ON, [hl]
	call Audio1_GetNextMusicByte
	ld d, a
	jp Audio1_note_length

Audio1_duty_cycle:
	cp duty_cycle_cmd
	jr nz, Audio1_tempo
	call Audio1_GetNextMusicByte
	rrca
	rrca
	and $c0
	ld b, 0
	ld hl, wChannelDutyCycles
	add hl, bc
	ld [hl], a ; store duty cycle
	jp Audio1_sound_ret

Audio1_tempo:
	cp tempo_cmd
	jr nz, Audio1_stereo_panning
	ld a, c
	cp CHAN5
	jr nc, .sfxChannel
	call Audio1_GetNextMusicByte
	ld [wMusicTempo], a ; store first param
	call Audio1_GetNextMusicByte
	ld [wMusicTempo + 1], a ; store second param
	xor a
	ld [wChannelNoteDelayCountersFractionalPart], a ; clear RAM
	ld [wChannelNoteDelayCountersFractionalPart + 1], a
	ld [wChannelNoteDelayCountersFractionalPart + 2], a
	ld [wChannelNoteDelayCountersFractionalPart + 3], a
	jr .musicChannelDone
.sfxChannel
	call Audio1_GetNextMusicByte
	ld [wSfxTempo], a ; store first param
	call Audio1_GetNextMusicByte
	ld [wSfxTempo + 1], a ; store second param
	xor a
	ld [wChannelNoteDelayCountersFractionalPart + 4], a ; clear RAM
	ld [wChannelNoteDelayCountersFractionalPart + 5], a
	ld [wChannelNoteDelayCountersFractionalPart + 6], a
	ld [wChannelNoteDelayCountersFractionalPart + 7], a
.musicChannelDone
	jp Audio1_sound_ret

Audio1_stereo_panning:
	cp stereo_panning_cmd
	jr nz, Audio1_unknownmusic0xef
	call Audio1_GetNextMusicByte
	ld [wStereoPanning], a ; store panning
	jp Audio1_sound_ret

; this appears to never be used
Audio1_unknownmusic0xef:
	cp unknownmusic0xef_cmd
	jr nz, Audio1_duty_cycle_pattern
	call Audio1_GetNextMusicByte
	push bc
	ld b, a
	call DetermineAudioFunction
	pop bc
	ld a, [wDisableChannelOutputWhenSfxEnds]
	and a
	jr nz, .skip
	ld a, [wChannelSoundIDs + CHAN8]
	ld [wDisableChannelOutputWhenSfxEnds], a
	xor a
	ld [wChannelSoundIDs + CHAN8], a
.skip
	jp Audio1_sound_ret

Audio1_duty_cycle_pattern:
	cp duty_cycle_pattern_cmd
	jr nz, Audio1_volume
	call Audio1_GetNextMusicByte
	ld b, 0
	ld hl, wChannelDutyCyclePatterns
	add hl, bc
	ld [hl], a ; store full pattern
	and %11000000
	ld hl, wChannelDutyCycles
	add hl, bc
	ld [hl], a ; store first duty cycle
	ld hl, wChannelFlags1
	add hl, bc
	set BIT_ROTATE_DUTY_CYCLE, [hl]
	jp Audio1_sound_ret

Audio1_volume:
	cp volume_cmd
	jr nz, Audio1_execute_music
	call Audio1_GetNextMusicByte
	ldh [rNR50], a ; store volume
	jp Audio1_sound_ret

Audio1_execute_music:
	cp execute_music_cmd
	jr nz, Audio1_octave
	ld b, $0
	ld hl, wChannelFlags2
	add hl, bc
	set BIT_EXECUTE_MUSIC, [hl]
	jp Audio1_sound_ret

Audio1_octave:
	and $f0
	cp octave_cmd
	jr nz, Audio1_sfx_note
	ld hl, wChannelOctaves
	ld b, 0
	add hl, bc
	ld a, d
	and $f
	ld [hl], a ; store low nibble as octave
	jp Audio1_sound_ret

; sfx_note is either square_note or noise_note depending on the channel
Audio1_sfx_note:
	cp sfx_note_cmd
	jr nz, Audio1_pitch_sweep
	ld a, c
	cp CHAN4 ; is this a noise or sfx channel?
	jr c, Audio1_pitch_sweep ; no
	ld b, 0
	ld hl, wChannelFlags2
	add hl, bc
	bit BIT_EXECUTE_MUSIC, [hl] ; is execute_music being used?
	jr nz, Audio1_pitch_sweep ; yes
	call Audio1_note_length

; This code seems to do the same thing as what Audio1_ApplyDutyCycleAndSoundLength
; does below.
	ld d, a
	ld b, 0
	ld hl, wChannelDutyCycles
	add hl, bc
	ld a, [hl]
	or d
	ld d, a
	ld b, REG_DUTY_SOUND_LEN
	call Audio1_GetRegisterPointer
	ld [hl], d

	call Audio1_GetNextMusicByte
	ld d, a
	ld b, REG_VOLUME_ENVELOPE
	call Audio1_GetRegisterPointer
	ld [hl], d
	call Audio1_GetNextMusicByte
	ld e, a
	ld a, c
	cp CHAN8
	ld a, 0
	jr z, .skip
; Channels 1 through 3 have 2 registers that control frequency, but the noise
; channel a single register (the polynomial counter) that controls frequency,
; so this command has one less byte on the noise channel.
	push de
	call Audio1_GetNextMusicByte
	pop de
.skip
	ld d, a
	push de
	call Audio1_ApplyDutyCycleAndSoundLength
	call Audio1_EnableChannelOutput
	pop de
	jp Audio1_ApplyWavePatternAndFrequency

Audio1_pitch_sweep:
	ld a, c
	cp CHAN5
	jp c, Audio1_note ; if not a sfx
	ld a, d
	cp pitch_sweep_cmd
	jp nz, Audio1_note
	ld b, $0
	ld hl, wChannelFlags2
	add hl, bc
	bit BIT_EXECUTE_MUSIC, [hl]
	jp nz, Audio1_note ; no
	call Audio1_GetNextMusicByte
	ldh [rNR10], a
	jp Audio1_sound_ret

;;;;;;;;;; PureRGBnote: ADDED: new audio commands that can be used in songs, needed for tcg/tcg2/pinball songs to work properly
VolumeEnvelope:
	ld a, d
;volume_envelope
	cp volume_envelope_cmd
	jr nz, IncOctave
	call Audio1_GetNextMusicByte
	ld hl, wChannelVolumes
	ld b, 0
	add hl, bc
	ld [hl], a
	jp Audio1_sound_ret

IncOctave:
;inc_octave
	cp inc_octave_cmd
	jr nz, DecOctave
	ld hl, wChannelOctaves
	ld b, 0
	add hl, bc
	ld a, [hl]
	dec a
	and 7
	ld [hl], a
	jp Audio1_sound_ret

DecOctave:
;dec_octave
	cp dec_octave_cmd
	jr nz, MusicSpeed
	ld hl, wChannelOctaves
	ld b, 0
	add hl, bc
	ld a, [hl]
	inc a
	and 7
	ld [hl], a
	jp Audio1_sound_ret

MusicSpeed:
;speed
	cp speed_cmd
	jr nz, ChannelVolumeCmd
	call Audio1_GetNextMusicByte
	ld hl, wChannelNoteSpeeds
	ld b, 0
	add hl, bc
	ld [hl], a
	jp Audio1_sound_ret

ChannelVolumeCmd:
;channel_volume
	cp channel_volume_cmd
	jr nz, FadeWave
	call Audio1_GetNextMusicByte
	ld hl, wChannelVolumes
	ld b, 0
	add hl, bc
	rla
	rla
	rla
	rla
	and $f0
	push bc
	ld b, a
	ld a, [hl]
	and $f
	add b
	pop bc
	ld [hl], a
	jp Audio1_sound_ret

FadeWave:
;fade_wave
	cp fade_wave_cmd
	jr nz, DrumKit
	call Audio1_GetNextMusicByte
	ld hl, wMusicWaveInstrument
	ld [hl], a
	jp Audio1_sound_ret

DrumKit:
;drum_kit
	cp drum_kit_cmd
	jr nz, Transpose
	call Audio1_GetNextMusicByte
	ld hl, wMusicDrumKit
	ld [hl], a
	jp Audio1_sound_ret

Transpose:
	cp transpose_cmd
	;jr nz, Cutoff
	jp nz, Audio1_toggle_perfect_pitch
	call Audio1_GetNextMusicByte
	ld hl, wChannelTranspositions
	ld b, 0
	add hl, bc
	ld [hl], a
	jp Audio1_sound_ret
;;;;;;;;;;

;Cutoff:
;; cutoff
;	cp cutoff_cmd
;	jp nz, Audio1_toggle_perfect_pitch
;	call Audio1_GetNextMusicByte
;	ld hl, wChannelCutoffs
;	ld b, 0
;	add hl, bc
;	ld [hl], a
;	jp Audio1_sound_ret

Audio1_note:
	ld a, c
	cp CHAN4
	jr nz, Audio1_note_length ; if not noise channel
	ld a, d
	and $f0
	cp drum_note_cmd
	jr z, .drum_note
	jr nc, Audio1_note_length

	; this executes when on the noise channel and
	; the command id is less than drum_note_cmd ($b0)
	; in this case, the upper nybble is used as the noise instrument ($1-$a)
	; and the lower nybble is the length minus 1 (0-15)
	; however, this doesn't work for instrument #2 because the command id
	; is captured by the noise_note command (command id $2x)
	; this essentially acts like a drum_note command that is only 1 byte
	; instead of 2 and can only be used with instruments 1 and 3 through 10
	; this is unused by the game
	swap a
	ld b, a
	ld a, d
	and $f
	ld d, a
	ld a, b
	push de
	push bc
	jr .playDnote

.drum_note
	ld a, d
	and $f
	push af
	push bc
	call Audio1_GetNextMusicByte ; get drum_note instrument
.playDnote
	ld d, a
	ld a, [wDisableChannelOutputWhenSfxEnds]
	and a
	jr nz, .skipDnote
	ld b, d
	call DetermineAudioFunction
.skipDnote
	pop bc
	pop de

Audio1_note_length:
	ld a, d
	push af
	and $f
	inc a
	ld b, 0
	ld e, a  ; store note length (in 16ths)
	ld d, b
	ld hl, wChannelNoteSpeeds
	add hl, bc
	ld a, [hl]
	ld l, b
	call Audio1_MultiplyAdd
	ld a, c
	cp CHAN5
	jr nc, .sfxChannel
	ld a, [wMusicTempo]
	ld d, a
	ld a, [wMusicTempo + 1]
	ld e, a
	jr .skip
.sfxChannel
	lb de, 1, 0
	cp CHAN8
	jr z, .skip ; if noise channel
	call Audio1_SetSfxTempo
	ld a, [wSfxTempo]
	ld d, a
	ld a, [wSfxTempo + 1]
	ld e, a
.skip
	ld a, l ; a = note_length * note_speed
	ld b, 0
	ld hl, wChannelNoteDelayCountersFractionalPart
	add hl, bc
	ld l, [hl]
	call Audio1_MultiplyAdd
	ld e, l
	ld d, h ; de = note_delay_frac_part + (note_length * note_speed * tempo)
	ld hl, wChannelNoteDelayCountersFractionalPart
	add hl, bc
	ld [hl], e
	ld a, d
	ld hl, wChannelNoteDelayCounters
	add hl, bc
	ld [hl], a
	ld hl, wChannelFlags2
	add hl, bc
	bit BIT_EXECUTE_MUSIC, [hl]
	jr nz, Audio1_note_pitch
	ld hl, wChannelFlags1
	add hl, bc
	bit BIT_NOISE_OR_SFX, [hl]
	jr z, Audio1_note_pitch
	pop hl
	ret

Audio1_note_pitch:
	pop af
	and $f0
	cp rest_cmd
	jr nz, .notRest
	ld a, c
	cp CHAN5
	jr nc, .next
; If this isn't an SFX channel, try the corresponding SFX channel.
	ld hl, wChannelSoundIDs + CHAN5
	add hl, bc
	ld a, [hl]
	and a
	ret nz
	; fall through
.next
	ld a, c
	cp CHAN3
	jr z, .channel3
	cp CHAN7
	jr nz, .notChannel3
.channel3
	ld b, 0
	ld hl, Audio1_HWChannelDisableMasks
	add hl, bc
	ldh a, [rNR51]
	and [hl]
	ldh [rNR51], a ; disable hardware channel 3's output
	ret
.notChannel3
	ld b, REG_VOLUME_ENVELOPE
	call Audio1_GetRegisterPointer
	ld a, $8 ; fade in sound
	ld [hli], a
	inc hl
	ld [hl], $80 ; restart sound
	ret
.notRest
	swap a
	ld b, 0
	ld hl, wChannelOctaves
	add hl, bc
	ld b, [hl]
	call Audio1_CalculateFrequency
	ld b, 0
	ld hl, wChannelFlags1
	add hl, bc
	bit BIT_PITCH_SLIDE_ON, [hl]
	call nz, Audio1_InitPitchSlideVars
	push de
	ld a, c
	cp CHAN5
	jr nc, .sfxChannel ; if sfx channel
; If this isn't an SFX channel, try the corresponding SFX channel.
	ld hl, wChannelSoundIDs + CHAN5
	ld d, 0
	ld e, a
	add hl, de
	ld a, [hl]
	and a
	jr z, .sfxChannel
	pop de
	ret
.sfxChannel
	ld b, 0
	ld hl, wChannelVolumes
	add hl, bc
	ld d, [hl]
	ld b, REG_VOLUME_ENVELOPE
	call Audio1_GetRegisterPointer
	ld [hl], d
	call Audio1_ApplyDutyCycleAndSoundLength
	call Audio1_EnableChannelOutput
	pop de
	ld b, $0
	ld hl, wChannelFlags1
	add hl, bc
	bit BIT_PERFECT_PITCH, [hl] ; has toggle_perfect_pitch been used?
	jr z, .skipFrequencyInc
	inc e                       ; if yes, increment the frequency by 1
	jr nc, .skipFrequencyInc    ; Likely a mistake, because `inc` does not set flag C.
	                            ; Fortunately this does not seem to affect any notes that actually occur.
	inc d
.skipFrequencyInc
	ld hl, wChannelFrequencyLowBytes
	add hl, bc
	ld [hl], e
	jp Audio1_ApplyWavePatternAndFrequency

Audio1_EnableChannelOutput:
	ld b, 0
	call Audio1_9972
	add hl, bc
	ldh a, [rNR51]
	or [hl] ; set this channel's bits
	ld d, a
	ld a, c
	cp CHAN8
	jr z, .noiseChannelOrNoSfx
	cp CHAN5
	jr nc, .skip ; if sfx channel
; If this isn't an SFX channel, try the corresponding SFX channel.
	ld hl, wChannelSoundIDs + CHAN5
	add hl, bc
	ld a, [hl]
	and a
	jr nz, .skip
.noiseChannelOrNoSfx
; If this is the SFX noise channel or a music channel whose corresponding
; SFX channel is off, apply stereo panning.
	ld a, [wStereoPanning]
	call Audio1_9972
	add hl, bc
	and [hl]
	ld d, a
	ldh a, [rNR51]
	ld hl, Audio1_HWChannelDisableMasks
	add hl, bc
	and [hl] ; reset this channel's output bits
	or d ; set this channel's output bits that enabled in [wStereoPanning]
	ld d, a
.skip
	ld a, d
	ldh [rNR51], a
	ret

Audio1_ApplyDutyCycleAndSoundLength:
	ld b, 0
	ld hl, wChannelNoteDelayCounters ; use the note delay as sound length
	add hl, bc
	ld d, [hl]
	ld a, c
	cp CHAN3
	jr z, .skipDuty ; if music channel 3
	cp CHAN7
	jr z, .skipDuty ; if sfx channel 3
; include duty cycle (except on channel 3 which doesn't have it)
	ld a, d
	and $3f
	ld d, a
	ld hl, wChannelDutyCycles
	add hl, bc
	ld a, [hl]
	or d
	ld d, a
.skipDuty
	ld b, REG_DUTY_SOUND_LEN
	call Audio1_GetRegisterPointer
	ld [hl], d
	ret

Audio1_ApplyWavePatternAndFrequency:
	ld a, c
	cp CHAN3
	jr z, .channel3
	cp CHAN7
	jr nz, .notChannel3
	; fall through
.channel3
	push de
	ld de, wMusicWaveInstrument
	cp CHAN3
	jr z, .next
	ld de, wSfxWaveInstrument
.next
	ld a, [de]
	add a
	ld d, 0
	ld e, a
	ld hl, Audio1_WavePointers
	add hl, de
	ld a, [hli]
	ld e, a
	ld d, [hl]
	ld hl, rWave_0
	ld b, $f
	xor a ; stop hardware channel 3
	ldh [rNR30], a
.loop
	ld a, [de]
	inc de
	ld [hli], a
	ld a, b
	dec b
	and a
	jr nz, .loop
	ld a, $80 ; start hardware channel 3
	ldh [rNR30], a
	pop de
.notChannel3
	ld a, d
	or $80 ; use counter mode (i.e. disable output when the counter reaches 0)
	and $c7 ; zero the unused bits in the register
	ld d, a
	ld b, REG_FREQUENCY_LO
	call Audio1_GetRegisterPointer
	ld a, e
	ld [hli], a ; store frequency low byte
	ld [hl], d ; store frequency high byte
	ld a, c
	cp CHAN5
	ret c
	jp Audio1_ApplyFrequencyModifier

Audio1_SetSfxTempo:
	call Audio1_IsCry
	jr c, .isCry
	call Audio1_IsBattleSFX
	jr nc, .notCry
.isCry
	ld d, 0
	ld a, [wTempoModifier]
	add $80
	jr nc, .next
	inc d
.next
	ld [wSfxTempo + 1], a
	ld a, d
	ld [wSfxTempo], a
	ret
.notCry
	xor a
	ld [wSfxTempo + 1], a
	inc a
	ld [wSfxTempo], a
	ret

Audio1_ApplyFrequencyModifier:
	call Audio1_IsCry
	jr c, .isCry
	call Audio1_IsBattleSFX
	ret nc
.isCry
; if playing a cry, add the cry's frequency modifier
	ld a, [wFrequencyModifier]
	add e
	jr nc, .noCarry
	inc d
.noCarry
	dec hl
	ld e, a
	ld [hli], a
	ld [hl], d
	ret

Audio1_GoBackOneCommandIfCry:
	call Audio1_IsCry
	jr nc, .done
	ld hl, wChannelCommandPointers
	ld e, c
	ld d, 0
	sla e
	rl d
	add hl, de
	ld a, [hl]
	sub 1
	ld [hli], a
	ld a, [hl]
	sbc 0
	ld [hl], a
	scf
	ret
.done
	scf
	ccf
	ret

Audio1_IsCry:
; Returns whether the currently playing audio is a cry in carry.
	ld a, [wChannelSoundIDs + CHAN5]
	cp CRY_SFX_START
	jr c, .no
	cp CRY_SFX_END
	jr z, .no
	jr c, .yes
.no
	scf
	ccf
	ret
.yes
	scf
	ret

Audio1_IsBattleSFX:
; Returns whether the currently playing audio is battle sfx in carry.
	ld a, [wAudioROMBank]
	cp BANK("Audio Engine 2")
	jr nz, .no
	ld a, [wChannelSoundIDs + CHAN8]
	ld b, a
	ld a, [wChannelSoundIDs + CHAN5]
	or b
	cp BATTLE_SFX_START
	jr c, .no
	cp BATTLE_SFX_END
	jr z, .yes
	jr c, .yes
.no
	and a
	ret
.yes
	scf
	ret


Audio1_ApplyPitchSlide:
	ld hl, wChannelFlags1
	add hl, bc
	bit BIT_PITCH_SLIDE_DECREASING, [hl]
	jp nz, .frequencyDecreasing
; frequency increasing
	ld hl, wChannelPitchSlideCurrentFrequencyLowBytes
	add hl, bc
	ld e, [hl]
	ld hl, wChannelPitchSlideCurrentFrequencyHighBytes
	add hl, bc
	ld d, [hl]
	ld hl, wChannelPitchSlideFrequencySteps
	add hl, bc
	ld l, [hl]
	ld h, b
	add hl, de
	ld d, h
	ld e, l
	ld hl, wChannelPitchSlideCurrentFrequencyFractionalPart
	add hl, bc
	push hl
	ld hl, wChannelPitchSlideFrequencyStepsFractionalPart
	add hl, bc
	ld a, [hl]
	pop hl
	add [hl]
	ld [hl], a
	ld a, 0
	adc e
	ld e, a
	ld a, 0
	adc d
	ld d, a
	ld hl, wChannelPitchSlideTargetFrequencyHighBytes
	add hl, bc
	ld a, [hl]
	cp d
	jp c, .reachedTargetFrequency
	jr nz, .applyUpdatedFrequency
	ld hl, wChannelPitchSlideTargetFrequencyLowBytes
	add hl, bc
	ld a, [hl]
	cp e
	jp c, .reachedTargetFrequency
	jr .applyUpdatedFrequency
.frequencyDecreasing
	ld hl, wChannelPitchSlideCurrentFrequencyLowBytes
	add hl, bc
	ld a, [hl]
	ld hl, wChannelPitchSlideCurrentFrequencyHighBytes
	add hl, bc
	ld d, [hl]
	ld hl, wChannelPitchSlideFrequencySteps
	add hl, bc
	ld e, [hl]
	sub e
	ld e, a
	ld a, d
	sbc b
	ld d, a
	ld hl, wChannelPitchSlideFrequencyStepsFractionalPart
	add hl, bc
	ld a, [hl]
	add a
	ld [hl], a
	ld a, e
	sbc b
	ld e, a
	ld a, d
	sbc b
	ld d, a
	ld hl, wChannelPitchSlideTargetFrequencyHighBytes
	add hl, bc
	ld a, d
	cp [hl]
	jr c, .reachedTargetFrequency
	jr nz, .applyUpdatedFrequency
	ld hl, wChannelPitchSlideTargetFrequencyLowBytes
	add hl, bc
	ld a, e
	cp [hl]
	jr c, .reachedTargetFrequency
.applyUpdatedFrequency
	ld hl, wChannelPitchSlideCurrentFrequencyLowBytes
	add hl, bc
	ld [hl], e
	ld hl, wChannelPitchSlideCurrentFrequencyHighBytes
	add hl, bc
	ld [hl], d
	ld b, REG_FREQUENCY_LO
	call Audio1_GetRegisterPointer
	ld a, e
	ld [hli], a
	ld [hl], d
	ret
.reachedTargetFrequency
; Turn off pitch slide when the target frequency has been reached.
	ld hl, wChannelFlags1
	add hl, bc
	res BIT_PITCH_SLIDE_ON, [hl]
	res BIT_PITCH_SLIDE_DECREASING, [hl]
	ret

Audio1_InitPitchSlideVars:
	ld hl, wChannelPitchSlideCurrentFrequencyHighBytes
	add hl, bc
	ld [hl], d
	ld hl, wChannelPitchSlideCurrentFrequencyLowBytes
	add hl, bc
	ld [hl], e
	ld hl, wChannelNoteDelayCounters
	add hl, bc
	ld a, [hl]
	ld hl, wChannelPitchSlideLengthModifiers
	add hl, bc
	sub [hl]
	jr nc, .next
	ld a, 1
.next
	ld [hl], a
	ld hl, wChannelPitchSlideTargetFrequencyLowBytes
	add hl, bc
	ld a, e
	sub [hl]
	ld e, a
	ld a, d
	sbc b
	ld hl, wChannelPitchSlideTargetFrequencyHighBytes
	add hl, bc
	sub [hl]
	jr c, .targetFrequencyGreater
	ld d, a
	ld b, 0
	ld hl, wChannelFlags1
	add hl, bc
	set BIT_PITCH_SLIDE_DECREASING, [hl]
	jr .next2
.targetFrequencyGreater
; If the target frequency is greater, subtract the current frequency from
; the target frequency to get the absolute difference.
	ld hl, wChannelPitchSlideCurrentFrequencyHighBytes
	add hl, bc
	ld d, [hl]
	ld hl, wChannelPitchSlideCurrentFrequencyLowBytes
	add hl, bc
	ld e, [hl]
	ld hl, wChannelPitchSlideTargetFrequencyLowBytes
	add hl, bc
	ld a, [hl]
	sub e
	ld e, a

; Bug. Instead of borrowing from the high byte of the target frequency as it
; should, it borrows from the high byte of the current frequency instead.
; This means that the result will be 0x200 greater than it should be if the
; low byte of the current frequency is greater than the low byte of the
; target frequency.
	ld a, d
	sbc b
	ld d, a

	ld hl, wChannelPitchSlideTargetFrequencyHighBytes
	add hl, bc
	ld a, [hl]
	sub d
	ld d, a
	ld b, 0
	ld hl, wChannelFlags1
	add hl, bc
	res BIT_PITCH_SLIDE_DECREASING, [hl]

.next2
	ld hl, wChannelPitchSlideLengthModifiers
	add hl, bc
.divideLoop
	inc b
	ld a, e
	sub [hl]
	ld e, a
	jr nc, .divideLoop
	ld a, d
	and a
	jr z, .doneDividing
	dec a
	ld d, a
	jr .divideLoop
.doneDividing
	ld a, e ; a = remainder - dividend
	add [hl]
	ld d, b ; d = quotient + 1
	ld b, 0
	ld hl, wChannelPitchSlideFrequencySteps
	add hl, bc
	ld [hl], d ; store quotient + 1
	ld hl, wChannelPitchSlideFrequencyStepsFractionalPart
	add hl, bc
	ld [hl], a ; store remainder - dividend
	ld hl, wChannelPitchSlideCurrentFrequencyFractionalPart
	add hl, bc
	ld [hl], a ; store remainder - dividend
	ret

Audio1_ApplyDutyCyclePattern:
	ld b, 0
	ld hl, wChannelDutyCyclePatterns
	add hl, bc
	ld a, [hl]
	rlca
	rlca
	ld [hl], a
	and $c0
	ld d, a
	ld b, REG_DUTY_SOUND_LEN
	call Audio1_GetRegisterPointer
	ld a, [hl]
	and $3f
	or d
	ld [hl], a
	ret

Audio1_GetNextMusicByte:
	jp GetNextMusicByte

Audio1_GetRegisterPointer:
; hl = address of hardware sound register b for software channel c
	ld a, c
	ld hl, Audio1_HWChannelBaseAddresses
	add l
	jr nc, .noCarry
	inc h
.noCarry
	ld l, a
	ld a, [hl]
	add b
	ld l, a
	ld h, $ff
	ret

Audio1_MultiplyAdd:
; hl = l + (a * de)
	ld h, 0
.loop
	srl a
	jr nc, .skipAdd
	add hl, de
.skipAdd
	sla e
	rl d
	and a
	ret z
	jr .loop

; PureRGBnote: CHANGED: adjusted to be able to transpose notes based on wChannelTranspositions to allow for a higher range of notes
Audio1_CalculateFrequency:
; return the frequency for note a, octave b in de
; do transposition first of note and octave
	ld d, b
	ld e, a
	ld b, 0
	; get starting octave
	ld hl, wChannelTranspositions
	add hl, bc
	ld a, [hl]
	swap a ; hi nybble
	and $f
	; add current octave
	add d
	push af ; we'll use this later
	; get starting frequency
	ld hl, wChannelTranspositions
	add hl, bc
	ld a, [hl]
	and $f ; lo nybble
	ld l, a ; ok
	ld d, 0
	ld h, d
	add hl, de ; add current pitch
	add hl, hl ; skip 2 bytes for each
	ld de, Audio1_Pitches
	add hl, de
	ld a, [hli]
	ld e, a
	ld d, [hl]
	; get our octave
	pop af
	; shift right by [7 - octave] bits
.loop
	; [7 - octave] loops
	cp $7
	jr nc, .ok
	; sra de
	sra d
	rr e
	inc a
	jr .loop

.ok
	ld a, d
	and $7 ; top 3 bits for frequency (11 total)
	ld d, a
	ret

Audio1_PlaySound::
	ld [wSoundID], a
	cp SFX_STOP_ALL_MUSIC
	jp z, StopAllAudio
	cp MAX_SFX_ID_1
	jp z, .playSfx
	jp c, .playSfx
	cp $fe
	jr z, .playMusic
	jp nc, .playSfx

.playMusic
	call InitMusicVariables
	jp .playSoundCommon

.playSfx
	ld l, a
	ld e, a
	ld h, 0
	ld d, h
	add hl, hl
	add hl, de
	ld de, SFX_Headers_1
	add hl, de
	ld a, h
	ld [wSfxHeaderPointer], a
	ld a, l
	ld [wSfxHeaderPointer + 1], a
	ld a, [hl]
	and $c0
	rlca
	rlca
	ld c, a
.sfxChannelLoop
	ld d, c
	ld a, c
	add a
	add c
	ld c, a
	ld b, 0
	hl_deref_reverse wSfxHeaderPointer
	add hl, bc
	ld c, d
	ld a, [hl]
	and $f
	ld e, a ; software channel ID
	ld d, 0
	ld hl, wChannelSoundIDs
	add hl, de
	ld a, [hl]
	and a
	jr z, .playChannel
	ld a, e
	cp CHAN8
	jr nz, .notNoiseChannel
	ld a, [wSoundID]
	cp NOISE_INSTRUMENTS_END
	ret c
	ld a, [hl]
	cp NOISE_INSTRUMENTS_END
	jr z, .playChannel
	jr c, .playChannel
.notNoiseChannel
	ld a, [wSoundID]
	cp [hl]
	jr z, .playChannel
	ret nc
.playChannel
	call InitSFXVariables
.skipSweepDisable
	ld a, c
	and a
	jp z, .playSoundCommon
	dec c
	jp .sfxChannelLoop
; fills d bytes at hl with a
.FillMem
	ld b, d
.loop
	ld [hli], a
	dec b
	jr nz, .loop
	ret

.playSoundCommon
	ld a, [wSoundID]
	ld l, a
	ld e, a
	ld h, 0
	ld d, h
	add hl, hl
	add hl, de
	ld de, SFX_Headers_1
	add hl, de
	ld e, l
	ld d, h
	ld hl, wChannelCommandPointers
	ld a, [de] ; get channel number
	ld b, a
	rlca
	rlca
	and $3
	ld c, a
	ld a, b
	and $f
	ld b, c
	inc b
	inc de
	ld c, 0
.commandPointerLoop
	cp c
	jr z, .next
	inc c
	inc hl
	inc hl
	jr .commandPointerLoop
.next
	push af
	push hl
	push bc
	ld b, 0
	ld c, a
	cp CHAN4
	jr c, .skipSettingFlag
	ld hl, wChannelFlags1
	add hl, bc
	set BIT_NOISE_OR_SFX, [hl]
.skipSettingFlag
	pop bc
	pop hl
	ld a, [de] ; get channel pointer
	ld [hli], a
	inc de
	ld a, [de]
	ld [hli], a
	inc de
	pop af
	push hl
	push bc
	ld b, 0
	ld c, a
	ld hl, wChannelSoundIDs
	add hl, bc
	ld a, [wSoundID]
	ld [hl], a
	pop bc
	pop hl
	inc c
	dec b
	ld a, b
	and a
	ld a, [de]
	inc de
	jr nz, .commandPointerLoop
	ld a, [wSoundID]
	cp CRY_SFX_START
	ret c
	ld a, [wSoundID]
	cp CRY_SFX_END
	ret z
	ret nc
	ld hl, wChannelSoundIDs + CHAN5
	ld [hli], a
	ld [hli], a
	ld [hli], a
	ld [hl], a
	ld hl, wChannelCommandPointers + CHAN7 * 2 ; sfx wave channel pointer
	ld de, Audio1_CryRet
	ld a, e
	ld [hli], a
	ld [hl], d ; overwrite pointer to point to sound_ret
	ld a, [wSavedVolume]
	and a
	ret nz
	ldh a, [rNR50]
	ld [wSavedVolume], a
	ld a, $77
	ldh [rNR50], a ; full volume
	ret

Audio1_CryRet:
	sound_ret

Audio1_HWChannelBaseAddresses:
; the low bytes of each HW channel's base address
	db HW_CH1_BASE, HW_CH2_BASE, HW_CH3_BASE, HW_CH4_BASE ; channels 0-3
	db HW_CH1_BASE, HW_CH2_BASE, HW_CH3_BASE, HW_CH4_BASE ; channels 4-7

Audio1_HWChannelDisableMasks:
	db HW_CH1_DISABLE_MASK, HW_CH2_DISABLE_MASK, HW_CH3_DISABLE_MASK, HW_CH4_DISABLE_MASK ; channels 0-3
	db HW_CH1_DISABLE_MASK, HW_CH2_DISABLE_MASK, HW_CH3_DISABLE_MASK, HW_CH4_DISABLE_MASK ; channels 4-7

Audio1_9972:
	push af
	push bc
	ld a, [wOptions2]
	bit BIT_AUDIO_PAN, a
	ld a, 0
	jr z, .panDisabled
	ld a, %1000
.panDisabled
	ld c, a
	ld b, 0
	ld hl, Audio1_HWChannelEnableMasks
	add hl, bc
	pop bc
	pop af
	ret

Audio1_HWChannelEnableMasks:
	db HW_CH1_ENABLE_MASK, HW_CH2_ENABLE_MASK, HW_CH3_ENABLE_MASK, HW_CH4_ENABLE_MASK ; channels 0-3
	db HW_CH1_ENABLE_MASK, HW_CH2_ENABLE_MASK, HW_CH3_ENABLE_MASK, HW_CH4_ENABLE_MASK ; channels 4-7
	db $01,$20,$44,$88
	db $11,$22,$44,$88
	db $01,$20,$04,$80
	db $01,$20,$04,$80
	db $01,$02,$40,$80
	db $01,$02,$40,$80

Audio1_Pitches:
INCLUDE "audio/notes.asm"
