$ErrorActionPreference = "SilentlyContinue"

function Search-InProject {
  param(
    [string]$Pattern,
    [string[]]$Include = @("*.rb","*.erb","*.haml","*.slim","*.js","*.jsx","*.ts","*.tsx","*.css","*.scss","*.yml")
  )

  $files = Get-ChildItem -Recurse -File -Include $Include |
    Where-Object {
      $_.FullName -notmatch "\\.git\\" -and
      $_.FullName -notmatch "\\node_modules\\" -and
      $_.FullName -notmatch "\\vendor\\" -and
      $_.FullName -notmatch "\\tmp\\" -and
      $_.FullName -notmatch "\\log\\"
    }

  foreach ($f in $files) {
    $m = Select-String -Path $f.FullName -Pattern $Pattern -SimpleMatch
    if ($m) { return $true }
  }
  return $false
}

$candidates = @()

Write-Host "=== helpers チェック ==="
$helperFiles = Get-ChildItem "app\helpers" -Recurse -File -Filter "*.rb"
foreach ($f in $helperFiles) {
  if ($f.Name -eq "application_helper.rb") { continue }

  $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  $mod  = ($base -replace "(^|_)([a-z])", { param($m) $m.Groups[2].Value.ToUpper() }) -replace "_",""
  if ($mod -notmatch "Helper$") { $mod = $mod + "Helper" }

  $used = Search-InProject $mod
  if (-not $used) {
    $candidates += [pscustomobject]@{
      Type = "helper"
      File = $f.FullName
      Reason = "$mod の参照が見つからない"
    }
  }
}

Write-Host "=== images チェック ==="
$imageFiles = Get-ChildItem "app\assets\images" -Recurse -File |
  Where-Object { $_.Name -ne ".keep" }

foreach ($f in $imageFiles) {
  $name = $f.Name
  $stem = [System.IO.Path]::GetFileNameWithoutExtension($name)

  $used1 = Search-InProject $name
  $used2 = Search-InProject $stem

  if (-not ($used1 -or $used2)) {
    $candidates += [pscustomobject]@{
      Type = "image"
      File = $f.FullName
      Reason = "$name / $stem の参照が見つからない"
    }
  }
}

Write-Host "=== views/pages の部分テンプレート チェック ==="
$partialFiles = Get-ChildItem "app\views" -Recurse -File -Include "_*.erb","_*.haml","_*.slim"
foreach ($f in $partialFiles) {
  $dir = Split-Path $f.DirectoryName -Leaf
  $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  $partial = $base.Substring(1)

  $pattern1 = "render `"$partial`""
  $pattern2 = "render '$partial'"
  $pattern3 = "render :$partial"
  $pattern4 = "render `"$dir/$partial`""
  $pattern5 = "render '$dir/$partial'"

  $used = (Search-InProject $pattern1) -or
          (Search-InProject $pattern2) -or
          (Search-InProject $pattern3) -or
          (Search-InProject $pattern4) -or
          (Search-InProject $pattern5)

  if (-not $used) {
    $candidates += [pscustomobject]@{
      Type = "partial"
      File = $f.FullName
      Reason = "render参照が見つからない"
    }
  }
}

Write-Host "=== mailers チェック ==="
if (Test-Path "app\mailers") {
  $mailerFiles = Get-ChildItem "app\mailers" -Recurse -File -Filter "*.rb"
  foreach ($f in $mailerFiles) {
    if ($f.Name -eq "application_mailer.rb") { continue }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $klass = ($base -replace "(^|_)([a-z])", { param($m) $m.Groups[2].Value.ToUpper() }) -replace "_",""
    if ($klass -notmatch "Mailer$") { $klass = $klass + "Mailer" }

    $used = Search-InProject $klass
    if (-not $used) {
      $candidates += [pscustomobject]@{
        Type = "mailer"
        File = $f.FullName
        Reason = "$klass の参照が見つからない"
      }
    }
  }
}

Write-Host "=== jobs チェック ==="
if (Test-Path "app\jobs") {
  $jobFiles = Get-ChildItem "app\jobs" -Recurse -File -Filter "*.rb"
  foreach ($f in $jobFiles) {
    if ($f.Name -eq "application_job.rb") { continue }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $klass = ($base -replace "(^|_)([a-z])", { param($m) $m.Groups[2].Value.ToUpper() }) -replace "_",""
    if ($klass -notmatch "Job$") { $klass = $klass + "Job" }

    $used = Search-InProject $klass
    if (-not $used) {
      $candidates += [pscustomobject]@{
        Type = "job"
        File = $f.FullName
        Reason = "$klass の参照が見つからない"
      }
    }
  }
}

Write-Host "=== admin フォルダ チェック ==="
if (Test-Path "app\controllers\admin") {
  $adminUsed = (Search-InProject "/admin") -or (Search-InProject "namespace :admin") -or (Search-InProject "module Admin")
  if (-not $adminUsed) {
    $candidates += [pscustomobject]@{
      Type = "admin"
      File = (Resolve-Path "app\controllers\admin").Path
      Reason = "admin関連の参照が見つからない"
    }
  }
}

Write-Host "=== pwa チェック ==="
if (Test-Path "app\views\pwa") {
  $pwaUsed = (Search-InProject "manifest") -or (Search-InProject "service-worker") -or (Search-InProject "pwa")
  if (-not $pwaUsed) {
    $candidates += [pscustomobject]@{
      Type = "pwa"
      File = (Resolve-Path "app\views\pwa").Path
      Reason = "PWA関連の参照が見つからない"
    }
  }
}

$candidates | Sort-Object Type, File | Tee-Object -FilePath ".\unused_candidates.txt" | Format-Table -AutoSize
Write-Host ""
Write-Host "結果を unused_candidates.txt に保存しました"
