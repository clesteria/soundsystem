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

  let
    ch0 = parseMML("T120 O3 L4  C R C R  G R G R") # Ch3 (Pulse25, ベース)
    ch1 = parseMML("T120 O4 L16 C R C R") # Ch4 (Pulse50, リズム刻み)
    ch2 = parseMML("T120 O4 L8  G R G G  A R G G  F R F F") # Ch2 (Triangle, ハーモニー)
    ch3 = parseMML("T120 O5 L8  C D E G  >C4      R G E C") # Ch1 (Saw, リード)

  channels[0].events = ch0
  channels[1].events = ch1
  channels[2].events = ch2
  channels[3].events = ch3

  while not windowShouldClose():
    # イベントが空になったらMMLを再設定
    if channels[0].events.len == 0: channels[0].events = ch0
    if channels[1].events.len == 0: channels[1].events = ch1
    if channels[2].events.len == 0: channels[2].events = ch2
    if channels[3].events.len == 0: channels[3].events = ch3

    beginDrawing()
    clearBackground(RAYWHITE)
    endDrawing()

when isMainModule:
  main()
