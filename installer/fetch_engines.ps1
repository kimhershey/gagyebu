# llama.cpp의 llama-server(MIT)를 받아 Windows 빌드 폴더의 engines\ 아래에 푼다.
# 앱이 켜질 때 이 실행 파일을 스스로 띄운다(app\lib\ai\llm\llama_server.dart).
# 판과 해시는 여기 한 곳에만 둔다. 판을 올릴 때는 해시를 직접 계산해 고친다.
#
#   pwsh installer\fetch_engines.ps1                 (저장소 루트에서)
param(
  [string]$Target = "app\build\windows\x64\runner\Release\engines"
)
$ErrorActionPreference = "Stop"

$tag = "b12774"
$packs = @(
  @{ Folder = "vulkan"; File = "llama-$tag-bin-win-vulkan-x64.zip"; Sha256 = "d29a16265d26ef7598209caaf1a544cbfa6abe2858c24b0ce4ae6bff87a76f22" },
  @{ Folder = "cpu";    File = "llama-$tag-bin-win-cpu-x64.zip";    Sha256 = "44b70b20f3374eec3d16a002beceefef33cc3565678caeb3eea5f6cacba61836" }
)

foreach ($pack in $packs) {
  $url = "https://github.com/ggml-org/llama.cpp/releases/download/$tag/$($pack.File)"
  $zip = Join-Path $env:TEMP $pack.File
  Invoke-WebRequest -Uri $url -OutFile $zip
  $actual = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $pack.Sha256) {
    throw "$($pack.File)의 해시가 다르다. 기대 $($pack.Sha256), 받은 것 $actual"
  }
  $folder = Join-Path $Target $pack.Folder
  if (Test-Path $folder) { Remove-Item -Recurse -Force $folder }
  New-Item -ItemType Directory -Force -Path $folder | Out-Null
  Expand-Archive -Path $zip -DestinationPath $folder
  if (-not (Test-Path (Join-Path $folder "llama-server.exe"))) {
    throw "$($pack.File) 안에 llama-server.exe가 없다."
  }
  Write-Host "$($pack.Folder): $tag"
}
