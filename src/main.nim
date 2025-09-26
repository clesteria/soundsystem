import raylib
import wave/core
import wave/naylib

const
  TargetFPS = 60

proc main () =
  initWindow(800, 450, "Sound System")
  defer:
    closeWindow()
  setTargetFPS(TargetFPS)

  initAudioDevice()
  defer:
    closeAudioDevice()

  ## AudioStream 作成 (モノラル 16bit)
  var stream: AudioStream
  setupRaylibAudio(stream)

  ## チャンネル初期化
  initChannels()

  ## MML
  var sequence: array[MaxChannel, seq[NoteEvent]]
  sequence[0] = parseMML("T120 O3 L4  C R C R  G R G R") # Ch3 (Pulse25, ベース)
  sequence[1] = parseMML("T120 O4 L16 C R C R") # Ch4 (Pulse50, リズム刻み)
  sequence[2] = parseMML("T120 O4 L8  G R G G  A R G G  F R F F") # Ch2 (Triangle, ハーモニー)
  sequence[3] = parseMML("T120 O5 L8  C D E G  >C4      R G E C") # Ch1 (Saw, リード)
  sequence[4] = parseMML("T120    L8  N4N4N8N8N4N4") # Ch5 (Noise, ドラム)

  ## 演奏データとして取り込み
  for i in 0..<MaxChannel:
    channels[i].events = sequence[i]

  while not windowShouldClose():
    # イベントが空になったらMMLを再設定
    for i in 0..<MaxChannel:
      if channels[i].events.len == 0:
        channels[i].events = sequence[i]

    beginDrawing()
    clearBackground(RAYWHITE)
    endDrawing()

when isMainModule:
  main()
