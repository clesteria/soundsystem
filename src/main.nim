import raylib
import wave/core
import wave/naylib

const
  TargetFPS = 60
  NoteChangeFrames = TargetFPS div 2 # 音の切り替えフレーム数 (0.5秒 * TargetFPS)

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
    mml1 = "t120 o4 l8 c e g c5 r g e c"
    mml2 = "t120 o3 l8 c g c4 g r c g c"

  channels[2].events = parseMML(mml1)
  channels[3].events = parseMML(mml2)

  while not windowShouldClose():
    # イベントが空になったらMMLを再設定
    if channels[2].events.len == 0:
      channels[2].events = parseMML(mml1)
    if channels[3].events.len == 0:
      channels[3].events = parseMML(mml2)

    beginDrawing()
    clearBackground(RAYWHITE)
    endDrawing()

when isMainModule:
  main()
