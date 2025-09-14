import raylib

const
  SampleRate = 44100
  Channels = 5
  WaveSize = 32
  TargetFPS = 60
  NoteChangeFrames = TargetFPS div 2 # 音の切り替えフレーム数 (0.5秒 * TargetFPS)

type
  Channel = object
    freq: float # 周波数(Hz)
    vol: float # 音量(0.0～1.0)
    phase: float # 波形位置
    wave: array[WaveSize, int8] # 波形テーブル

var
  channels: array[Channels, Channel]
  stream: AudioStream

# 矩形波
proc makeSquareWave(duty: int): array[WaveSize, int8] =
  for i in 0..<WaveSize:
    if i < WaveSize * duty div 100:
      result[i] = 127
    else:
      result[i] = -128

# ノコギリ波
proc makeTriangleWave(): array[WaveSize, int8] =
  let halfWaveSize = WaveSize div 2
  for i in 0..<halfWaveSize:
    result[i] = int8(-128 + (i * (256 div 16))) # -128 → +127
  for i in halfWaveSize..<WaveSize:
    result[i] = int8(127 - ((i-16) * (256 div 16))) # +127 → -128

# オーディオコールバック
proc audioCallback(buffer: pointer, frames: uint32) {.cdecl.} =
  var output = cast[ptr UncheckedArray[int16]](buffer)
  for i in 0..<frames.int:
    var mix = 0.0
    for c in 0..<Channels:
      let ch = addr channels[c]
      if ch.vol > 0 and ch.freq > 0:
        let pos = int(ch.phase) mod WaveSize
        mix += (float(ch.wave[pos]) / 128.0) * ch.vol
        # 位相を進める
        ch.phase += ch.freq * WaveSize / SampleRate
    # クリッピング
    if mix > 1.0: mix = 1.0
    if mix < -1.0: mix = -1.0
    output[i] = int16(mix * 32767)

proc main () =
  initWindow(800, 450, "Sound System")
  initAudioDevice()
  defer: closeWindow()
  defer: closeAudioDevice()

  setTargetFPS(TargetFPS)

  # AudioStream 作成 (モノラル 16bit)
  stream = loadAudioStream(SampleRate, 16, 1)
  setAudioStreamCallback(stream, audioCallback)
  playAudioStream(stream)

  # チャンネル初期化
  for i in 0..<Channels:
    channels[i].wave = makeSquareWave(50) # デューティ50%矩形波
    channels[i].vol = 0.2

  # 簡単にドレミを鳴らす
  let notes = [261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 493.88, 523.25] # C4～C5
  var idx = 0
  var frameCount = 0
  var lastChangeTime = getTime()

  while not windowShouldClose():
    frameCount.inc
    let currentTime = getTime()
    if frameCount mod NoteChangeFrames == 0:
      # 秒数表示(想定した時間との誤差を計測するデバッグ用途)
      let elapsedTime = currentTime - lastChangeTime
      echo "音変更: 経過時間 = ", elapsedTime, "秒"
      lastChangeTime = getTime()

      # 音を変える
      channels[0].freq = notes[idx mod notes.len]
      idx.inc

    beginDrawing()
    clearBackground(RAYWHITE)
    endDrawing()

when isMainModule:
  main()
