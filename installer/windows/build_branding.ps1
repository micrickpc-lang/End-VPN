$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$logoPath = Join-Path $root 'assets\images\logo.png'
$outputDir = Join-Path $PSScriptRoot 'branding'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

function New-BrandBitmap {
  param(
    [Parameter(Mandatory=$true)][int]$Width,
    [Parameter(Mandatory=$true)][int]$Height,
    [Parameter(Mandatory=$true)][string]$Output,
    [Parameter(Mandatory=$true)][double]$LogoScale
  )

  $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

  $rect = New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)
  $gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(255, 5, 8, 13),
    [System.Drawing.Color]::FromArgb(255, 16, 18, 26),
    90
  )
  $graphics.FillRectangle($gradient, $rect)

  $blueGlow = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, 18, 126, 226), [Math]::Max(2, $Width * 0.018))
  $redGlow = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(130, 206, 30, 59), [Math]::Max(2, $Width * 0.018))
  $blueCore = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 34, 159, 255), [Math]::Max(1, $Width * 0.005))
  $redCore = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 239, 51, 79), [Math]::Max(1, $Width * 0.005))

  $graphics.DrawLine($blueGlow, -$Width * 0.15, $Height * 0.60, $Width * 1.15, $Height * 0.18)
  $graphics.DrawLine($blueCore, -$Width * 0.15, $Height * 0.60, $Width * 1.15, $Height * 0.18)
  $graphics.DrawLine($redGlow, -$Width * 0.15, $Height * 0.83, $Width * 1.15, $Height * 0.40)
  $graphics.DrawLine($redCore, -$Width * 0.15, $Height * 0.83, $Width * 1.15, $Height * 0.40)

  $logo = [System.Drawing.Image]::FromFile($logoPath)
  $logoSize = [int]([Math]::Min($Width, $Height) * $LogoScale)
  $logoX = [int](($Width - $logoSize) / 2)
  $logoY = [int](($Height - $logoSize) / 2)
  $graphics.DrawImage($logo, $logoX, $logoY, $logoSize, $logoSize)

  $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80, 255, 255, 255), 1)
  $graphics.DrawRectangle($borderPen, 0, 0, $Width - 1, $Height - 1)

  $bitmap.Save($Output, [System.Drawing.Imaging.ImageFormat]::Bmp)

  $borderPen.Dispose()
  $redCore.Dispose()
  $blueCore.Dispose()
  $redGlow.Dispose()
  $blueGlow.Dispose()
  $logo.Dispose()
  $gradient.Dispose()
  $graphics.Dispose()
  $bitmap.Dispose()
}

New-BrandBitmap -Width 493 -Height 784 -Output (Join-Path $outputDir 'wizard-large.bmp') -LogoScale 0.76
New-BrandBitmap -Width 164 -Height 164 -Output (Join-Path $outputDir 'wizard-small.bmp') -LogoScale 0.92

Write-Host "Built installer branding in $outputDir"
