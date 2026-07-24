#!/usr/bin/env python3
"""Deterministically synthesize the original iT-BATTLE soundtrack and SFX.

The score deliberately uses a small, restrained palette (sine/triangle/pulse,
filtered deterministic noise and sparse drums).  This keeps the survivor-like
combat energetic without occupying the same bright frequency range as warning
cues.  No third-party samples are used.
"""

from __future__ import annotations

import argparse
import math
import random
import shutil
import subprocess
import tempfile
import wave
from array import array
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BGM_DIR = ROOT / "assets" / "audio" / "bgm"
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
TAU = math.tau


def midi(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def triangle(phase: float) -> float:
    return 2.0 * abs(2.0 * (phase - math.floor(phase + 0.5))) - 1.0


def pulse(phase: float, width: float = 0.34) -> float:
    return 1.0 if phase % 1.0 < width else -1.0


def event_env(t: float, start: float, attack: float, decay: float) -> float:
    local = t - start
    if local < 0.0:
        return 0.0
    return min(1.0, local / max(0.0001, attack)) * math.exp(-local / max(0.0001, decay))


def chirp(t: float, start: float, duration: float, start_hz: float, end_hz: float) -> float:
    local = t - start
    if local < 0.0 or local > duration:
        return 0.0
    sweep = (end_hz - start_hz) / max(0.001, duration)
    phase = TAU * (start_hz * local + 0.5 * sweep * local * local)
    return math.sin(phase)


def soft_limit(value: float, drive: float = 1.12) -> float:
    return math.tanh(value * drive) / math.tanh(drive)


MODES = {
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "major": [0, 2, 4, 5, 7, 9, 11],
}


BGM_SPECS = {
    "bgm_noc_afterhours": {
        "bpm": 94.0, "bars": 16, "root": 50, "mode": "dorian",
        "progression": [0, 3, 5, 4], "energy": 0.62, "motif": [0, 2, 4, 2], "seed": 1201,
    },
    "bgm_packet_flow": {
        "bpm": 112.0, "bars": 16, "root": 52, "mode": "dorian",
        "progression": [0, 5, 3, 4], "energy": 0.78, "motif": [0, 4, 2, 5], "seed": 1202,
    },
    "bgm_pager_escalation": {
        "bpm": 120.0, "bars": 16, "root": 47, "mode": "phrygian",
        "progression": [0, 1, 5, 0], "energy": 0.91, "motif": [0, 1, 4, 2], "seed": 1203,
    },
    "bgm_incident_core": {
        "bpm": 126.0, "bars": 16, "root": 50, "mode": "phrygian",
        "progression": [0, 1, 0, 4], "energy": 1.00, "motif": [0, 4, 1, 0], "seed": 1204,
    },
    "bgm_recovery_window": {
        "bpm": 92.0, "bars": 16, "root": 55, "mode": "major",
        "progression": [0, 3, 4, 0], "energy": 0.54, "motif": [0, 2, 4, 6], "seed": 1205,
    },
}

# A more kinetic alternate score.  These tracks deliberately increase pulse,
# bass motion and downbeat clarity, rather than adding a wall of hats or a
# louder master.  They are intended for active play over long survivor runs.
PULSE_BGM_SPECS = {
    "bgm_noc_afterhours_pulse": {
        "bpm": 108.0, "bars": 16, "root": 50, "mode": "dorian",
        "progression": [0, 3, 5, 4], "energy": 0.72, "motif": [0, 2, 4, 5], "seed": 2201, "drive": 0.54,
    },
    "bgm_packet_flow_pulse": {
        "bpm": 124.0, "bars": 16, "root": 52, "mode": "dorian",
        "progression": [0, 5, 3, 4], "energy": 0.82, "motif": [0, 4, 5, 2], "seed": 2202, "drive": 0.68,
    },
    "bgm_pager_escalation_pulse": {
        "bpm": 128.0, "bars": 16, "root": 47, "mode": "phrygian",
        "progression": [0, 1, 5, 0], "energy": 0.88, "motif": [0, 1, 4, 5], "seed": 2203, "drive": 0.76,
    },
    "bgm_incident_core_pulse": {
        "bpm": 132.0, "bars": 16, "root": 50, "mode": "phrygian",
        "progression": [0, 1, 0, 4], "energy": 0.94, "motif": [0, 4, 1, 5], "seed": 2204, "drive": 0.82,
    },
    "bgm_recovery_window_pulse": {
        "bpm": 106.0, "bars": 16, "root": 55, "mode": "major",
        "progression": [0, 3, 4, 0], "energy": 0.64, "motif": [0, 2, 4, 6], "seed": 2205, "drive": 0.46,
    },
}


def _phase_since(beat_in_bar: float, point: float) -> float:
    return (beat_in_bar - point) % 4.0


def synthesize_bgm(spec: dict, output_wav: Path, sample_rate: int = 32000) -> float:
    bpm = float(spec["bpm"])
    bars = int(spec["bars"])
    root = int(spec["root"])
    mode = MODES[str(spec["mode"])]
    progression = list(spec["progression"])
    energy = float(spec["energy"])
    motif = list(spec["motif"])
    drive = float(spec.get("drive", 0.0))
    active_pulse = drive > 0.0
    seconds_per_beat = 60.0 / bpm
    duration = bars * 4.0 * seconds_per_beat
    frame_count = int(round(duration * sample_rate))
    pcm = array("h")
    noise_rng = random.Random(int(spec["seed"]))
    noise_low_l = 0.0
    noise_low_r = 0.0

    for frame in range(frame_count):
        t = frame / sample_rate
        beat = t / seconds_per_beat
        bar = int(beat // 4.0)
        beat_in_bar = beat % 4.0
        eighth = int(beat * 2.0) % 8
        eighth_phase = (beat * 2.0) % 1.0
        degree = progression[bar % len(progression)]
        chord_root = root + mode[degree % 7]
        chord = [chord_root, chord_root + mode[2], chord_root + mode[4]]

        # Pads breathe at bar boundaries, leaving room for warnings and impacts.
        pad_envelope = math.sin(math.pi * beat_in_bar / 4.0) ** 0.42
        pad_l = 0.0
        pad_r = 0.0
        for tone_index, note in enumerate(chord):
            frequency = midi(note)
            phase = t * frequency
            detune = t * frequency * (1.003 + tone_index * 0.0007)
            pad_l += math.sin(TAU * phase) * (0.72 - tone_index * 0.13)
            pad_r += math.sin(TAU * detune + tone_index * 0.71) * (0.72 - tone_index * 0.13)
        pad_gain = 0.075 * pad_envelope

        # Rounded eighth-note bass with intentional rests.
        bass_pattern = [True, True, False, True, True, False, True, True] if active_pulse else [True, False, True, True, False, True, False, True]
        bass_env = math.exp(-eighth_phase * 4.8) * min(1.0, eighth_phase / 0.035)
        bass_note = chord_root - 24 + (7 if eighth in (3, 7) else 0)
        bass = 0.0
        if bass_pattern[eighth]:
            bass_phase = t * midi(bass_note)
            bass = (0.78 * math.sin(TAU * bass_phase) + 0.22 * triangle(bass_phase)) * bass_env * (0.16 + drive * 0.025)

        # Sparse kick and muted industrial snare. No constant bright hi-hat.
        kick = 0.0
        kick_points = [0.0, 1.5, 2.0, 3.25] if active_pulse else ([0.0, 2.0] if energy < 0.86 else [0.0, 1.5, 2.0, 3.25])
        for point in kick_points:
            phase_beats = _phase_since(beat_in_bar, point)
            local = phase_beats * seconds_per_beat
            if local < 0.24:
                env = math.exp(-local * 17.0)
                kick += math.sin(TAU * (48.0 * local + 5.6 * (1.0 - math.exp(-local * 28.0)))) * env * (0.31 + drive * 0.04)

        white_l = noise_rng.uniform(-1.0, 1.0)
        white_r = noise_rng.uniform(-1.0, 1.0)
        noise_low_l += 0.08 * (white_l - noise_low_l)
        noise_low_r += 0.08 * (white_r - noise_low_r)
        band_l = white_l - noise_low_l
        band_r = white_r - noise_low_r
        snare_env = 0.0
        for point in (1.0, 3.0):
            local = _phase_since(beat_in_bar, point) * seconds_per_beat
            if local < 0.16:
                snare_env += math.exp(-local * 24.0)
        snare_l = (0.65 * band_l + 0.35 * noise_low_l) * snare_env * 0.085 * energy
        snare_r = (0.65 * band_r + 0.35 * noise_low_r) * snare_env * 0.085 * energy

        # The active set uses a low, brief off-beat tick.  It creates forward
        # motion without filling the warning band with a bright 16th-note hat.
        hat_steps = (1, 3, 5, 7) if active_pulse else (1, 5)
        hat_env = math.exp(-eighth_phase * (17.0 if active_pulse else 15.0)) if eighth in hat_steps else 0.0
        hat_l = band_l * hat_env * (0.012 + drive * 0.004) * energy
        hat_r = band_r * hat_env * (0.012 + drive * 0.004) * energy

        # Muted terminal stabs live below the lead and make the beat legible
        # even at a restrained Music-bus volume.
        stab_l = 0.0
        stab_r = 0.0
        if active_pulse and eighth in (1, 4, 6):
            stab_note = chord_root + (7 if eighth == 6 else 12)
            stab_env = math.exp(-eighth_phase * 9.0) * min(1.0, eighth_phase / 0.02)
            stab_phase = t * midi(stab_note)
            stab = (0.62 * triangle(stab_phase) + 0.38 * math.sin(TAU * stab_phase)) * stab_env * (0.030 + drive * 0.012)
            stab_l = stab * (0.78 if eighth in (1, 6) else 0.54)
            stab_r = stab * (0.54 if eighth in (1, 6) else 0.78)

        # A short terminal motif appears only every other bar.
        lead_l = 0.0
        lead_r = 0.0
        motif_bars = (0, 1, 2, 3) if active_pulse else (1, 3)
        if bar % 4 in motif_bars and eighth in (0, 3, 5, 7):
            motif_note = root + 12 + mode[motif[(eighth // 2) % len(motif)] % 7]
            if str(spec["mode"]) == "phrygian" and eighth == 5:
                motif_note = root + 18  # restrained FATAL tritone signature
            lead_env = math.exp(-eighth_phase * 7.0) * min(1.0, eighth_phase / 0.025)
            lead_phase = t * midi(motif_note)
            lead = (0.72 * math.sin(TAU * lead_phase) + 0.28 * pulse(lead_phase, 0.28)) * lead_env * (0.045 + drive * 0.010)
            lead_l = lead * (0.82 if eighth in (0, 5) else 0.48)
            lead_r = lead * (0.48 if eighth in (0, 5) else 0.82)

        movement = 0.94 + 0.06 * math.sin(TAU * t / (seconds_per_beat * 8.0))
        left = (pad_l * pad_gain + bass + kick + snare_l + hat_l + stab_l + lead_l) * movement
        right = (pad_r * pad_gain + bass + kick + snare_r + hat_r + stab_r + lead_r) * movement
        master = 0.76 + energy * 0.06
        left = soft_limit(left * master)
        right = soft_limit(right * master)
        pcm.append(max(-32768, min(32767, round(left * 32767.0))))
        pcm.append(max(-32768, min(32767, round(right * 32767.0))))

    with wave.open(str(output_wav), "wb") as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(sample_rate)
        stream.writeframes(pcm.tobytes())
    return duration


SFX_SPECS = {
    # Automatic tools and career signatures.
    "attack_bash": (0.25, "melee", False),
    "attack_ping": (0.22, "ping", False),
    "attack_firewall": (0.46, "shield", False),
    "attack_log": (0.36, "data", False),
    "attack_wrench": (0.24, "metal", False),
    "attack_rule_chain": (0.22, "electric", False),
    "attack_lock_zone": (0.44, "lock", False),
    "attack_worker": (0.28, "laser", False),
    "attack_database": (0.46, "database", False),
    "attack_ticket": (0.30, "ticket", False),
    "attack_script": (0.36, "script", False),
    "attack_sre": (0.54, "pulse", False),
    "attack_delivery": (0.52, "package", False),
    # Active skills.
    "skill_dash": (0.38, "dash", False),
    "skill_scan": (0.68, "scan", False),
    "skill_shield": (0.58, "shield", False),
    "skill_heal": (0.62, "heal", False),
    "skill_deploy": (0.52, "deploy", False),
    # Ultimate signatures (stereo and deliberately distinct).
    "ultimate_ops": (1.15, "ult_alarm", True),
    "ultimate_dba": (1.34, "ult_commit", True),
    "ultimate_network": (1.48, "ult_storm", True),
    "ultimate_security": (1.28, "ult_lockdown", True),
    "ultimate_infrastructure": (1.58, "ult_racks", True),
    "ultimate_support": (1.18, "ult_success", True),
    "ultimate_deploy": (1.42, "ult_deploy", True),
    "ultimate_ai": (1.54, "ult_scale", True),
    "ultimate_sre": (1.46, "ult_freeze", True),
    "ultimate_delivery": (1.48, "ult_release", True),
    # Elite telegraphs and one-shot impacts.
    "elite_fire_warning": (0.88, "warn_fire", False),
    "elite_frost_warning": (0.92, "warn_frost", False),
    "elite_teleport_warning": (0.72, "warn_teleport", False),
    "elite_storm_warning": (0.82, "warn_storm", False),
    "elite_volatile_warning": (1.06, "warn_volatile", False),
    "elite_shield": (0.60, "shield", False),
    "hazard_fire_hit": (0.58, "hit_fire", False),
    "hazard_frost_hit": (0.52, "hit_frost", False),
    "hazard_teleport_hit": (0.42, "hit_teleport", False),
    "hazard_storm_hit": (0.50, "hit_storm", False),
    "hazard_explosion_hit": (0.78, "hit_explosion", False),
    # Boss and player feedback.
    "boss_entrance": (2.62, "boss_entrance", True),
    "boss_expose": (1.48, "boss_expose", True),
    "boss_phase": (1.18, "boss_phase", True),
    "boss_defeat": (2.82, "boss_defeat", True),
    "player_hit": (0.30, "player_hit", False),
}


def _tone(t: float, start: float, frequency: float, attack: float, decay: float, gain: float = 1.0) -> float:
    return math.sin(TAU * frequency * max(0.0, t - start)) * event_env(t, start, attack, decay) * gain


def _impact(t: float, start: float, noise: float, strength: float = 1.0) -> float:
    local = t - start
    if local < 0.0 or local > 0.55:
        return 0.0
    env = math.exp(-local * 10.5)
    drop = math.sin(TAU * (72.0 * local - 24.0 * local * local))
    return (drop * 0.84 + noise * 0.16) * env * strength


def _metal(t: float, start: float, strength: float = 1.0) -> float:
    local = t - start
    if local < 0.0:
        return 0.0
    env = math.exp(-local * 13.0)
    return sum(math.sin(TAU * frequency * local) * weight for frequency, weight in ((620, .48), (947, .30), (1417, .17), (2191, .09))) * env * strength


def sfx_value(mode: str, t: float, duration: float, noise: float, low_noise: float) -> float:
    end_fade = min(1.0, max(0.0, (duration - t) / 0.035))
    value = 0.0

    if mode in ("melee", "metal"):
        value += _impact(t, 0.045, low_noise, 0.78 if mode == "melee" else 0.62)
        value += _metal(t, 0.035, 0.34 if mode == "melee" else 0.58)
        value += noise * event_env(t, 0.0, 0.008, 0.055) * 0.16
    elif mode == "ping":
        value += chirp(t, 0.0, 0.105, 720.0, 1460.0) * event_env(t, 0.0, .004, .075) * .58
        value += _tone(t, .095, 1110.0, .003, .055, .26)
    elif mode in ("shield", "warn_frost"):
        value += chirp(t, 0.0, duration * .70, 180.0, 760.0 if mode == "shield" else 1320.0) * event_env(t, 0.0, .025, duration * .54) * .36
        for offset, note in enumerate((520.0, 690.0, 920.0)):
            value += _tone(t, .10 + offset * .08, note, .006, .12, .16)
        value += low_noise * event_env(t, 0.0, .03, .22) * .12
    elif mode in ("data", "database"):
        for index, note in enumerate((330.0, 494.0, 392.0)):
            start = index * .105
            value += _tone(t, start, note, .004, .075, .32)
            value += noise * event_env(t, start, .002, .018) * .08
        if mode == "database":
            value += _impact(t, .29, low_noise, .34)
    elif mode in ("electric", "hit_storm"):
        value += noise * event_env(t, 0.0, .002, .10) * .34
        value += chirp(t, 0.0, duration * .72, 1750.0, 340.0) * event_env(t, 0.0, .004, .13) * .25
        value += _impact(t, .035, low_noise, .34 if mode == "electric" else .78)
    elif mode == "lock":
        for index, start in enumerate((.02, .15, .29)):
            value += _metal(t, start, .16 + index * .05)
            value += _tone(t, start, 210.0 - index * 24.0, .002, .075, .23)
    elif mode == "laser":
        value += chirp(t, 0.0, .18, 1320.0, 310.0) * event_env(t, 0.0, .002, .11) * .47
        value += math.sin(TAU * 43.0 * t) * math.sin(TAU * 840.0 * t) * event_env(t, .0, .003, .12) * .17
    elif mode == "ticket":
        value += noise * event_env(t, .0, .002, .025) * .11
        value += _tone(t, .035, 660.0, .003, .07, .30)
        value += _tone(t, .13, 880.0, .003, .09, .34)
        value += _metal(t, .215, .10)
    elif mode == "script":
        for start in (.0, .065, .13):
            value += noise * event_env(t, start, .001, .018) * .13
            value += _tone(t, start, 260.0, .001, .025, .12)
        value += _tone(t, .20, 930.0, .004, .09, .31)
    elif mode == "pulse":
        value += chirp(t, .0, .40, 150.0, 510.0) * event_env(t, .0, .018, .26) * .43
        value += _tone(t, .10, 760.0, .012, .22, .17)
    elif mode == "package":
        value += chirp(t, .0, .24, 920.0, 180.0) * event_env(t, .0, .012, .16) * .23
        value += noise * event_env(t, .0, .008, .11) * .10
        value += _impact(t, .27, low_noise, .66) + _metal(t, .27, .15)
    elif mode == "dash":
        value += chirp(t, .0, .30, 860.0, 120.0) * event_env(t, .0, .005, .19) * .26
        value += low_noise * event_env(t, .0, .008, .17) * .30
    elif mode == "scan":
        value += chirp(t, .0, .52, 270.0, 1480.0) * event_env(t, .0, .025, .36) * .28
        for start in (.12, .29, .47):
            value += _tone(t, start, 980.0 + start * 420.0, .003, .065, .20)
    elif mode == "heal":
        for index, frequency in enumerate((440.0, 554.37, 659.25)):
            value += _tone(t, .06 + index * .10, frequency, .012, .22, .23)
        value += math.sin(TAU * 220.0 * t) * event_env(t, .0, .05, .34) * .10
    elif mode == "deploy":
        value += _impact(t, .02, low_noise, .54) + _metal(t, .02, .24)
        value += _tone(t, .24, 520.0, .004, .11, .19) + _tone(t, .34, 780.0, .004, .10, .21)
    elif mode.startswith("ult_"):
        # Shared low launch body, with per-role melodic/mechanical identity.
        value += _impact(t, .05, low_noise, .52)
        if mode == "ult_alarm":
            value += _tone(t, .10, 440.0, .01, .34, .28) + _tone(t, .48, 622.25, .01, .34, .31)
        elif mode == "ult_commit":
            for index, start in enumerate((.10, .32, .54, .78)):
                value += _metal(t, start, .16 + index * .04)
            value += _impact(t, .91, low_noise, .58)
        elif mode == "ult_storm":
            for index in range(6):
                start = .08 + index * .18
                value += chirp(t, start, .14, 520.0 + index * 80.0, 1280.0) * event_env(t, start, .003, .11) * .16
            value += noise * event_env(t, .18, .08, .70) * .11
        elif mode == "ult_lockdown":
            for index in range(6):
                start = .09 + index * .13
                value += _metal(t, start, .12) + _tone(t, start, 250.0 + index * 34.0, .003, .09, .12)
            value += _impact(t, .92, low_noise, .56)
        elif mode == "ult_racks":
            for start in (.10, .38, .66, .94):
                value += _impact(t, start, low_noise, .38) + _metal(t, start, .14)
            value += chirp(t, .80, .65, 120.0, 540.0) * event_env(t, .80, .05, .48) * .17
        elif mode == "ult_success":
            for index, frequency in enumerate((440.0, 554.37, 659.25, 880.0)):
                value += _tone(t, .08 + index * .16, frequency, .006, .18, .22)
            value += _metal(t, .80, .18)
        elif mode == "ult_deploy":
            for index, frequency in enumerate((280.0, 420.0, 630.0)):
                start = .10 + index * .34
                value += _impact(t, start, low_noise, .28 + index * .08)
                value += _tone(t, start, frequency, .006, .24, .17)
        elif mode == "ult_scale":
            for index in range(6):
                start = .08 + index * .16
                value += _tone(t, start, 340.0 * (2.0 ** (index / 12.0)), .004, .13, .17)
            value += chirp(t, .45, .90, 140.0, 920.0) * event_env(t, .45, .04, .60) * .18
        elif mode == "ult_freeze":
            value += chirp(t, .04, 1.12, 1180.0, 92.0) * event_env(t, .04, .01, .78) * .28
            for start, frequency in ((.22, 1318.5), (.40, 987.8), (.58, 740.0)):
                value += _tone(t, start, frequency, .002, .24, .15)
            value += _tone(t, .92, 92.0, .006, .34, .32) + _tone(t, 1.18, 92.0, .006, .25, .24)
        elif mode == "ult_release":
            for index, start in enumerate((.08, .48, .90)):
                value += _impact(t, start, low_noise, .30 + index * .13)
                value += _tone(t, start, 330.0 * (1.0 + index * .34), .005, .26, .19 + index * .025)
                value += chirp(t, start, .30, 170.0 + index * 80.0, 690.0 + index * 180.0) * event_env(t, start, .008, .23) * .11
    elif mode == "warn_fire":
        value += low_noise * event_env(t, .0, .06, .52) * (.20 + .18 * t / duration)
        value += chirp(t, .10, .66, 95.0, 240.0) * event_env(t, .10, .04, .48) * .28
    elif mode == "warn_teleport":
        value += chirp(t, .0, .58, 1260.0, 120.0) * event_env(t, .0, .008, .34) * .38
        value += _tone(t, .42, 920.0, .003, .10, .22)
    elif mode == "warn_storm":
        for start in (.05, .27, .49):
            value += _tone(t, start, 1160.0, .002, .08, .18)
        value += noise * event_env(t, .18, .03, .42) * .12
    elif mode == "warn_volatile":
        for index, start in enumerate((.05, .35, .59, .78)):
            value += _tone(t, start, 310.0 + index * 95.0, .002, .09, .24)
        value += chirp(t, .18, .78, 120.0, 560.0) * event_env(t, .18, .03, .52) * .17
    elif mode == "hit_fire":
        value += _impact(t, .0, low_noise, .66)
        value += low_noise * event_env(t, .02, .005, .30) * .34
    elif mode == "hit_frost":
        value += _impact(t, .0, low_noise, .48)
        for frequency in (910.0, 1310.0, 1870.0):
            value += _tone(t, .02, frequency, .001, .17, .13)
    elif mode == "hit_teleport":
        value += chirp(t, .0, .30, 160.0, 1420.0) * event_env(t, .0, .004, .18) * .36
        value += _impact(t, .18, low_noise, .30)
    elif mode == "hit_explosion":
        value += _impact(t, .0, low_noise, .92)
        value += noise * event_env(t, .0, .002, .26) * .28
        value += _metal(t, .06, .15)
    elif mode.startswith("boss_"):
        value += low_noise * event_env(t, .0, .04, duration * .62) * .13
        if mode == "boss_entrance":
            value += chirp(t, .0, 1.55, 48.0, 132.0) * event_env(t, .0, .12, 1.30) * .34
            value += _impact(t, .72, low_noise, .56) + _impact(t, 1.66, low_noise, .90)
            value += _tone(t, .34, 146.83, .02, .58, .24) + _tone(t, .92, 207.65, .02, .62, .24)
        elif mode == "boss_expose":
            value += chirp(t, .0, 1.12, 120.0, 780.0) * event_env(t, .0, .04, .82) * .32
            value += _impact(t, .62, low_noise, .50)
            value += _tone(t, .72, 587.33, .01, .40, .25)
        elif mode == "boss_phase":
            value += _impact(t, .05, low_noise, .64) + _impact(t, .48, low_noise, .72)
            value += _tone(t, .16, 138.59, .01, .48, .28) + _tone(t, .50, 196.0, .01, .44, .24)
        elif mode == "boss_defeat":
            for index, start in enumerate((.08, .42, .80, 1.18)):
                value += _impact(t, start, low_noise, .46 - index * .06)
                value += _metal(t, start, .16)
            value += chirp(t, .72, 1.42, 520.0, 46.0) * event_env(t, .72, .05, 1.0) * .23
            value += _tone(t, 1.92, 392.0, .02, .55, .18) + _tone(t, 2.18, 523.25, .02, .48, .20)
    elif mode == "player_hit":
        value += _impact(t, .0, low_noise, .42)
        value += noise * event_env(t, .0, .001, .055) * .20

    return soft_limit(value * end_fade * 0.86)


def synthesize_sfx(mode: str, duration: float, output_wav: Path, stereo: bool, seed: int, sample_rate: int = 32000) -> None:
    frame_count = int(round(duration * sample_rate))
    pcm = array("h")
    rng = random.Random(seed)
    low_l = 0.0
    low_r = 0.0
    for frame in range(frame_count):
        t = frame / sample_rate
        white_l = rng.uniform(-1.0, 1.0)
        white_r = rng.uniform(-1.0, 1.0)
        low_l += .11 * (white_l - low_l)
        low_r += .11 * (white_r - low_r)
        left = sfx_value(mode, t, duration, white_l - low_l * .35, low_l)
        pcm.append(max(-32768, min(32767, round(left * 32767.0))))
        if stereo:
            right = sfx_value(mode, t, duration, white_r - low_r * .35, low_r)
            # Tiny phase-independent width without delaying the transient.
            right = right * .94 + math.sin(TAU * 1.7 * t) * event_env(t, .0, .02, duration * .55) * .025
            pcm.append(max(-32768, min(32767, round(right * 32767.0))))
    with wave.open(str(output_wav), "wb") as stream:
        stream.setnchannels(2 if stereo else 1)
        stream.setsampwidth(2)
        stream.setframerate(sample_rate)
        stream.writeframes(pcm.tobytes())


def convert_bgm(wav_path: Path, ogg_path: Path) -> None:
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise RuntimeError("ffmpeg is required to encode the loopable OGG assets")
    subprocess.run(
        [
            ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav_path),
            "-af", "highpass=f=32,lowpass=f=10800,alimiter=limit=0.90",
            "-c:a", "vorbis", "-strict", "-2", "-q:a", "5", str(ogg_path),
        ],
        check=True,
    )


def generate_music(specs: dict[str, dict]) -> None:
    BGM_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="itbattle-audio-") as temp_dir:
        temp = Path(temp_dir)
        for name, spec in specs.items():
            wav_path = temp / f"{name}.wav"
            duration = synthesize_bgm(spec, wav_path)
            convert_bgm(wav_path, BGM_DIR / f"{name}.ogg")
            print(f"BGM  {name:28s} {duration:5.2f}s")


def generate_all() -> None:
    generate_music(BGM_SPECS)
    for index, (name, (duration, mode, stereo)) in enumerate(SFX_SPECS.items()):
        SFX_DIR.mkdir(parents=True, exist_ok=True)
        synthesize_sfx(mode, duration, SFX_DIR / f"{name}.wav", stereo, seed=3400 + index)
        print(f"SFX  {name:28s} {duration:5.2f}s")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--all", action="store_true", help="regenerate the original score and complete SFX library")
    parser.add_argument("--pulse-bgm", action="store_true", help="generate only the more kinetic alternate BGM suite")
    args = parser.parse_args()
    if args.all:
        generate_all()
    elif args.pulse_bgm:
        generate_music(PULSE_BGM_SPECS)
    else:
        parser.error("pass --all or --pulse-bgm to generate checked-in audio assets")


if __name__ == "__main__":
    main()
