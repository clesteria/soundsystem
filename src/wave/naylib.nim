import wave/core
import raylib

# Public Procedures
# ******************************************************************************

proc setupRaylibAudio*(stream: var AudioStream) =
  stream = loadAudioStream(SampleRate, 16, 1)
  setAudioStreamCallback(stream, proc(buffer: pointer, frames: uint32) {.cdecl.} =
    processAudioBuffer(buffer, frames)
  )
  playAudioStream(stream)
