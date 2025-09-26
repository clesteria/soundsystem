import strutils
import tables
import math

# ==============================================================================
# Constants
# ==============================================================================

const
  SampleRate* = 44100
  MaxChannel* = 5
  WaveSize = 32
  Notes = {
    'C': 261.63,
    'D': 293.66,
    'E': 329.63,
    'F': 349.23,
    'G': 392.0,
    'A': 440.0,
    'B': 493.88
  }.toTable

# ******************************************************************************
# Type
# ******************************************************************************

type
  NoteEvent* = object
    freq*: float # 周波数(Hz)
    length*: int

  # 基底チャンネル
  Channel* = ref object
    events*: seq[NoteEvent]
    playPos: int
    phase: float # 波形位置
    vol*: float # 音量(0.0～1.0)
    wave: array[WaveSize, int8] # 波形テーブル
    lfsr: uint32 # LFSRレジスタ
    lastOut: float # 直前の出力値

  Channels* = array[MaxChannel, Channel]

# ------------------------------------------------------------------------------
# Variable
# ------------------------------------------------------------------------------

var
  channels*: Channels

# Private Procedures
# ------------------------------------------------------------------------------

## 矩形波
proc makeSquareWave(duty: int): array[WaveSize, int8] =
  for i in 0..<WaveSize:
    if i < WaveSize * duty div 100:
      result[i] = 127
    else:
      result[i] = -128

## 三角波
proc makeTriangleWave(): array[WaveSize, int8] =
  let halfWaveSize = WaveSize div 2
  for i in 0..<halfWaveSize:
    result[i] = int8(-128 + (i * (256 div 16))) # -128 → +127
  for i in halfWaveSize..<WaveSize:
    result[i] = int8(127 - ((i-16) * (256 div 16))) # +127 → -128

## ノコギリ波
proc makeSawWave(): array[WaveSize, int8] =
  for i in 0..<WaveSize:
    result[i] = int8(-128 + (i * (256 div WaveSize)))

# Public Procedures
# ******************************************************************************

proc stepLFSR(self: Channel): float =
  let bit = (self.lfsr xor (self.lfsr shr 1)) and 1
  self.lfsr = (self.lfsr shr 1) or (bit shl 14)
  if (self.lfsr and 1) == 1: 1.0 else: -1.0

proc getSample(self: Channel, sampleRate: float, mix: var float) =
  if self.events.len <= 0: return
  let ev = self.events[0]
  if self.wave.len == 0:
    self.phase += ev.freq / sampleRate
    if self.phase >= 1.0:
      self.phase -= 1.0
      self.lastOut = self.stepLFSR()
      self.events[0].length.dec
      if self.events[0].length <= 0:
        self.events.delete(0)
    mix += self.lastOut * self.vol
  else:
    if ev.freq > 0:
      let pos = int(self.phase) mod WaveSize
      mix += (float(self.wave[pos]) / 128.0) * self.vol
      self.phase += ev.freq * WaveSize / sampleRate
    # 音符の再生位置を更新し、終了した音符を削除
    self.playPos.inc
    if self.playPos >= ev.length:
      self.playPos = 0
      self.phase = 0
      self.events.delete(0)

## オーディオコールバック
proc processAudioBuffer*(buffer: pointer, frames: uint32) =
  # bufferをint16型の配列として扱うための型キャスト
  var output = cast[ptr UncheckedArray[int16]](buffer)

  # 指定されたフレーム数だけオーディオサンプルを生成
  for i in 0..<frames.int:
    var mix = 0.0

    # 各チャンネルのオーディオデータをミキシング
    for ch in mitems(channels):
      ch.getSample(SampleRate, mix)

    # クリッピング（音量が-1.0から1.0の範囲に収まるように制限）
    if mix > 1.0: mix = 1.0
    if mix < -1.0: mix = -1.0

    # 最終的なオーディオサンプルをint16型に変換し、バッファに書き込む
    # 32767は16ビット符号付き整数の最大値で、音量をスケーリングするために使用
    output[i] = int16(mix * 32767)

## チャンネル初期化
proc initChannels*() =
  channels[0] = Channel(events: @[], vol: 0.1, wave: makeSquareWave(25)) # デューティ25%矩形波
  channels[1] = Channel(events: @[], vol: 0.1, wave: makeSquareWave(50)) # デューティ50%矩形波
  channels[2] = Channel(events: @[], vol: 0.3, wave: makeTriangleWave()) # 三角波
  channels[3] = Channel(events: @[], vol: 0.3, wave: makeSawWave()) # ノコギリ波
  channels[4] = Channel(events: @[], vol: 0.2, lfsr: 1, lastOut: 0.0) # ノイズ

## 音符の長さを取得
proc getNoteLength(mml: string, idx: var int, defaultLen: int): int =
  result = defaultLen
  if idx + 1 < mml.len and mml[idx+1].isDigit:
    let numStr = $mml[idx+1]
    try:
      result = parseInt(numStr)
      inc idx
    except ValueError:
      # パース失敗時はdefaultLenのまま
      discard

## 音符のデュレーションを計算
proc getDuration(bpm, len: int): int =
  (SampleRate * 60 div bpm) * 4 div len

## MMLのパース
proc parseMML*(mml: string): seq[NoteEvent] =
  var
    i = 0
    octave = 4
    defaultLen = 4
    bpm = 120

  while i < mml.len:
    let c = mml[i]
    case c:
    of 'A', 'B', 'C', 'D', 'E', 'F', 'G': # 音符
      let len = getNoteLength(mml, i, defaultLen)
      let freq = Notes[c] * pow(2.0, (octave - 4).float)
      let dur = getDuration(bpm, len)
      result.add NoteEvent(freq: freq, length: dur)
    of 'R': # 休符
      let len = getNoteLength(mml, i, defaultLen)
      let dur = getDuration(bpm, len)
      result.add NoteEvent(freq: 0, length: dur)
    of 'O': # オクターブ指定
      if i+1 < mml.len and mml[i+1].isDigit:
        try:
          octave = parseInt($mml[i+1])
          inc i
        except ValueError:
          discard
    of 'L': # デフォ長
      if i+1 < mml.len and mml[i+1].isDigit:
        try:
          defaultLen = parseInt($mml[i+1])
          inc i
        except ValueError:
          discard
    of 'T': # テンポ
      var num = ""
      var j = i+1
      while j < mml.len and mml[j].isDigit:
        num.add mml[j]
        inc j
      if num.len > 0:
        try:
          bpm = parseInt(num)
        except ValueError:
          discard
      i = j-1
    of 'N': # ノイズ命令
      var len = defaultLen
      if i+1 < mml.len and mml[i+1].isDigit:
        len = parseInt($mml[i+1])
        inc i
      for ch in channels:
        ch.events.add NoteEvent(freq: 440.0, length: len)  # freq は LFSR 更新速度として扱う
        break
    of '<':
      dec octave
    of '>':
      inc octave
    else:
      discard
    inc i
