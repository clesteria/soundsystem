import strformat, strutils

## タスク用変数・関数
let srcFile = "src/main.nim"
let binRoot = "bin"

proc buildApp(os: string, buildType: string, cpu: string = "") =
  const
    unuseModuleFlag = "-d:NaylibSupportModuleRtext=false -d:NaylibSupportModuleRmodels=false"

  var
    outDir: string
    define: string

  let
    osOption = if os == "current": "" else: fmt"--os:{os}"
    cpuOption = if cpu == "": "" else: fmt"--cpu:{cpu}"

  case buildType
  of "debug","release":
    define = fmt"-d:{buildType}"
    case os
    of "current":
      outDir = fmt"{binRoot}/{buildType}/"
    of "windows","linux","macosx":
      if cpu == "":
        outDir = fmt"{binRoot}/{buildType}/{os}/"
      else:
        outDir = fmt"{binRoot}/{buildType}/{os}/{cpu}/"
    else:
      raise newException(ValueError, fmt"Invalid OS for {buildType} build")
  else:
    raise newException(ValueError, "Invalid build type")

  echo fmt"Executing command: nim c {define} {osOption} {cpuOption} --outDir:{outDir} {srcFile}"
  exec fmt"nim c {unuseModuleFlag} {define} {osOption} {cpuOption} --outDir:{outDir} {srcFile}"

## ビルド用設定
switch("path", "src")
switch("nimcache", "nimcache")

when defined(debug):
  switch("stackTrace", "on")
  switch("hints", "off")
  switch("warnings", "on")

when defined(release):
  switch("opt", "speed")
  switch("define", "danger")

# Emscripten compiler configuration
when defined(emscripten):
  switch("cc", "clang")
  switch("clang.exe", "emcc")
  switch("clang.linkerexe", "emcc")

## ビルド用タスク
task dev, "Building debug version for current OS...":
  buildApp("current", "debug")

task prod, "Building release version for current OS...":
  buildApp("current", "release")

task win_dev, "Building debug version for Windows...":
  buildApp("windows", "debug")

task win_prod, "Building release version for Windows...":
  buildApp("windows", "release")

task linux_dev, "Building debug version for Linux...":
  buildApp("linux", "debug")

task linux_prod, "Building release version for Linux...":
  buildApp("linux", "release")

task mac_dev, "Building debug version for macOS...":
  buildApp("macosx", "debug")

task mac_prod, "Building release version for macOS...":
  buildApp("macosx", "release")

task mac_intel_dev, "Building debug version for Intel macOS...":
  buildApp("macosx", "debug", "amd64")

task mac_intel_prod, "Building release version for Intel macOS...":
  buildApp("macosx", "release", "amd64")
